class_name SleepTaker
extends BossEncounter
## The Sleep Taker, the Dead Zone's boss (GDD §10): in the Dead Zone, a dead cyborg's Bad Dream doesn't
## dissolve; over the years they drifted together through the ruins and fused into one colossal
## nightmare haunting the silent city (SleepTakerBody, SleepTakerModel). Task E5c, in two steps: E5c-a
## (this) builds the nightmare, its arena, its entrance and its three attacks, with weapons having no
## effect; E5c-b brings hurting it (the fence generators along the route, luring it close, the EMP
## tearing a chunk away: _on_part_emp), the three phases, the defeat and its campaign slot. Until then
## the slot plays it only as a preview (BossDef.preview_scene; debug builds: --boss=dead_zone_boss).
##
## Weapons have no effect (GDD §10: immune to weapons, like every Bad Dream): its body is immune_to_weapons
## (no targeting, no damage, direct or splash: R2's rule for hosts) and its BossDef's weapon_share_cap is 0.
##
## The arena (BossDef.arena, data/bosses/dead_zone_boss.tres): the Dead Zone's rubble street with holes
## and fences, in the Dead Zone's look with nothing hung over the street where it looms
## (data/bosses/dead_zone_boss_skin.tres), darker than normal but never pitch black (the arena config's
## LevelConfig.darkness: only the scenery dims; glows, the runner and the enemies keep their light), no
## signs on its walls. Each lap carries its refuges (_plan_lap): every refuge_spacing metres a charred
## bridge across the street (the Dead Zone's ceiling look) with pads before it (the middle lane's, or
## every lane's: SleepTakerTuning.refuge_pads_every_lane), the track kept clear of holes and fences
## where the slash's warning and escape happen and where its riders land.
##
## Each phase:
## 1. Its intro. The first phase's is its entrance: it rises out of the street far ahead, materializing
##    with a swelling chorus of moans (sleep_taker_rise), and drifts in to loom over the street ahead of
##    the runner. Later phases (E5c-b: after an EMP tore a chunk away) re-form where it hovers.
## 2. Its pattern: it hovers hover_ahead in front of the runner, keeping pace, and attacks. The giant
##    slash (SleepTakerSlash) comes at every refuge, timed so its claws strike while a runner who took a
##    pad rides the ceiling: GDD §10, it can't reach the ceiling, so the pads are the refuge from the big
##    slashes (at 3 lanes a three-lane slash covers the whole street; at 5 and 6 leaving its lanes dodges
##    it too). Between refuges the phase's attack list (SleepTakerTuning.attack_patterns) runs in order,
##    the first attack that can start fairly going next: grasping hands (SleepTakerHands) and lights out
##    (SleepTakerLightsOut), one at a time, attack_gap apart, never one that would still be on when the
##    next refuge's slash is due. Lights out's darkness lasts while the next attacks come.
## Every attack has its visual and audio warning (sound() plays and logs each), none overlaps another's,
## and nothing depends on how long the fight has lasted (GDD §10: no escalation): the refuges are the
## track's and the lists the phase's, so every attempt plays the same way for the same runner. The phase's
## pace speeds up the hands and the gaps (GDD §10: hungrier each phase: faster hands, more lights out in
## the later lists); the slash and lights out keep their timings (the slash's warning is what gets a
## runner to a pad). Numbers: SleepTakerTuning (data/bosses/dead_zone_boss_tuning.tres), all DESIGN-TBD
## (docs/questions/e5c.md).

enum Step { ENTER, HOVER, REFORM }

const BODY_SCRIPT: Script = preload("res://scripts/bosses/sleep_taker/sleep_taker_body.gd")
## The attacks its pattern lists may name.
const KINDS: PackedStringArray = ["hands", "lights_out"]
## A refuge's hint shows this long before its slash's warning.
const REFUGE_HINT_LEAD: float = 4.0
## DESIGN-TBD (task E5c-b brings its defeat: the wisps, the silence, the grey dawn): beaten, it dissolves
## over this long, and the run may end.
const DEFEAT_SECONDS: float = 1.6

var body: SleepTakerBody
var tuning: SleepTakerTuning
var slash: SleepTakerSlash
var hands: SleepTakerHands
var dark: SleepTakerLightsOut
var step: Step = Step.ENTER
var step_time: float = 0.0
## Where it looms, relative to the runner: its middle's world x, its base's height, metres ahead.
var pose := Vector3.ZERO
## The phase's attacks waiting their turn, in order (refilled from its list once all have gone).
var line: PackedStringArray = PackedStringArray()

## Each distinct lap's refuges (lap index → [{pad, end}], lap-relative track distances).
var _refuge_plan: Dictionary = {}
## Refuges whose slash came (or was missed), by their pads' distance.
var _used: Dictionary = {}
var _gap_left: float = 0.0
var _was_busy: bool = false
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _seconds: float = 1.0
var _bob: float = 0.0
var _hinted: Dictionary = {}


func _build_boss() -> void:
	tuning = _tuning()
	body = add_part(BODY_SCRIPT, {"tuning": tuning}) as SleepTakerBody
	slash = SleepTakerSlash.new()
	add_child(slash)
	slash.setup(self)
	hands = SleepTakerHands.new()
	add_child(hands)
	hands.setup(self)
	dark = SleepTakerLightsOut.new()
	add_child(dark)
	dark.setup(self)
	if int(context.boss_resume.get("phase", 0)) > 0:
		# Resuming at a later phase: it's already here.
		pose = hover_pose()
		body.fade = 0.0
	else:
		pose = enter_pose()
		body.fade = 1.0
	_place()


func _tuning() -> SleepTakerTuning:
	var t := (def.tuning as SleepTakerTuning) if def != null else null
	return t if t != null else SleepTakerTuning.new()


# --- The arena -----------------------------------------------------------------------------------

## GDD §10's arena: the Dead Zone's street (BossDef.arena), no signs on its walls, and its refuges: every
## refuge_spacing metres from refuge_first, a ceiling across every lane (a charred bridge in the Dead
## Zone's look) from the arena's hull_lead_in before its pads to refuge_seconds past them, with pads in
## refuge_pad_lanes(), and the track kept clear of holes and fences in every lane from where the slash's
## warning finds the runner (and a jump before it) to past where it strikes, and where its riders land.
func _plan_lap(lap: LevelLayout, index: int, p_arena: BossArena) -> void:
	lap.signs.clear()
	var t: SleepTakerTuning = _tuning()
	var v: float = p_arena.tuning.run_speed
	var n: int = lap.lane_count
	var zones: CeilingZones = CeilingZones.make(p_arena.config, p_arena.tuning)
	var lead_in: float = p_arena.config.hull_lead_in
	var span: Vector2 = refuge_clear_span(t, p_arena.tuning, v)
	var plan: Array[Dictionary] = []
	var pad: float = t.refuge_first
	while true:
		var end: float = pad + t.refuge_seconds * v
		var landing: Vector2 = zones.landing_zone({"start": pad - lead_in, "end": end})
		if landing.y > p_arena.lap_length - 1.0:
			break
		_clear_track(lap, pad + span.x, pad + span.y)
		zones.clear_landing(lap, landing)
		for i: int in range(lap.hulls.size() - 1, -1, -1):
			if float(lap.hulls[i]["start"]) <= end + 1.0 and float(lap.hulls[i]["end"]) >= pad - lead_in - 1.0:
				lap.hulls.remove_at(i)
		lap.hulls.append(LevelLayout.make_hull(pad - lead_in, end, Vector2i(0, n - 1), n))
		for lane: int in pad_lanes(n, t):
			lap.pads.append({"lane": lane, "at": pad})
		plan.append({"pad": pad, "end": end})
		pad += t.refuge_spacing
	_refuge_plan[index] = plan


## The stretch around a refuge's pads (relative to them) that stays clear of holes and fences in every
## lane: from a jump before where the slash's warning finds the runner, to past where it strikes (the
## runner's way to a pad, or to a lane outside the slash, and the pad's run-up and rise).
static func refuge_clear_span(t: SleepTakerTuning, movement: MovementTuning, v: float) -> Vector2:
	var before: float = v * (t.slash_warning() - t.strike_after_pad) + movement.jump_distance(v)
	var after: float = v * t.strike_after_pad + t.slash_depth + t.escape_clear_after
	return Vector2(-before, after)


## The lanes a refuge's pads lie in: the middle lane (both middle lanes at an even count), or every lane.
static func pad_lanes(n: int, t: SleepTakerTuning) -> Array[int]:
	var out: Array[int] = []
	if t.refuge_pads_every_lane:
		for lane: int in n:
			out.append(lane)
	elif n % 2 == 1:
		out.append(n / 2)
	else:
		out.append(n / 2 - 1)
		out.append(n / 2)
	return out


## The refuges reaching into [from, to] (track distances), in order: {pad, end, key}.
func refuges_between(from: float, to: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if arena == null or arena.laps.is_empty():
		return out
	for k: int in range(maxi(arena.lap_at(from), 0), arena.lap_at(to) + 1):
		var offset: float = k * arena.lap_length
		for r: Dictionary in _refuge_plan.get(k % arena.laps.size(), []):
			var pad: float = float(r["pad"]) + offset
			var end: float = float(r["end"]) + offset
			if end >= from and pad <= to:
				out.append({"pad": pad, "end": end, "key": snappedf(pad, 0.01)})
	return out


## The next refuge whose slash hasn't come yet and whose moment hasn't passed: {pad, end, key, warn_at}, or
## {} for none within sight. One whose moment has passed unused is logged (refuge_missed) and skipped.
func next_refuge() -> Dictionary:
	var d: float = player_distance()
	var v: float = _speed()
	for r: Dictionary in refuges_between(d - 5.0, d + 400.0):
		if _used.has(r["key"]):
			continue
		var warn_at: float = refuge_warn_at(float(r["pad"]))
		if d <= warn_at + v * tuning.slash_late:
			r["warn_at"] = warn_at
			return r
		# Its moment passed while the runner was down or another attack still struck: it goes by.
		_used[r["key"]] = true
		log_event(&"refuge_missed", {"pad": r["pad"]})
	return {}


## Where the runner is when a refuge's slash warns: its strike lands strike_after_pad after they reach
## the pads at `pad`.
func refuge_warn_at(pad: float) -> float:
	var v: float = _speed()
	return pad + v * tuning.strike_after_pad - v * tuning.slash_warning()


## Takes holes and fences (any part of one) out of every lane between two track distances.
static func _clear_track(lap: LevelLayout, from: float, to: float) -> void:
	for i: int in range(lap.gaps.size() - 1, -1, -1):
		if float(lap.gaps[i]["start"]) <= to and float(lap.gaps[i]["end"]) >= from:
			lap.gaps.remove_at(i)
	for i: int in range(lap.fences.size() - 1, -1, -1):
		var f: float = float(lap.fences[i]["at"])
		if f >= from - 0.5 and f <= to + 0.5:
			lap.fences.remove_at(i)


# --- Where it looms --------------------------------------------------------------------------------

## Where its entrance starts: far ahead, sunk below the street.
func enter_pose() -> Vector3:
	return Vector3(0.0, -tuning.enter_depth, tuning.enter_ahead)


## Where it hovers: hover_ahead in front of the runner, its vapour on the street.
func hover_pose() -> Vector3:
	return Vector3(pose.x, 0.0, tuning.hover_ahead)


## The lane the runner is in or over (a wall runner counts as the outer lane on that side).
func player_lane() -> int:
	var p: Player = world.player
	if p.surface == Player.Surface.WALL:
		return 0 if p.wall_side < 0 else lane_count() - 1
	return clampi(p.lane, 0, lane_count() - 1)


## Plays a sound at `pos` and notes it (every warning is heard: tests read the notes).
func sound(sound_name: StringName, pos: Vector3) -> void:
	world.play_sfx_at(sound_name, pos)
	log_event(&"sound", {"name": sound_name})


## True while one of its attacks warns or strikes (the slash, a hand): its big attack, for the director.
func attack_on() -> bool:
	return (slash != null and slash.warning_on()) or (hands != null and hands.warning_on())


## True while any of its warnings plays (an attack's, or lights out's inhale).
func warning_active() -> bool:
	return attack_on() or (dark != null and dark.warning_on())


# --- Fairness helpers ------------------------------------------------------------------------------

## The nearest lane a runner in `pl` at `d0` can switch to out of an attack on `struck`: not struck, at
## most max_escape_lanes away, and it and every lane on the way free of holes and fences from `d0` to
## `until`. -1 if there is none.
func escape_lane(struck: Array[int], pl: int, d0: float, until: float) -> int:
	var n: int = lane_count()
	for dist: int in range(1, tuning.max_escape_lanes + 1):
		for s: int in [-1, 1]:
			var e: int = pl + s * dist
			if e < 0 or e >= n or struck.has(e):
				continue
			var ok: bool = true
			for l: int in range(mini(pl, e), maxi(pl, e) + 1):
				if l != pl and not floor_clear_lane(l, d0, until):
					ok = false
					break
			if ok:
				return e
	return -1


## True if `lane`'s floor has no hole and no working fence between two track distances.
func floor_clear_lane(lane: int, from: float, to: float) -> bool:
	return arena == null or arena.floor_clear(from, to, lane)


## True if a ceiling (a refuge's bridge) reaches into [from, to].
func ceiling_between(from: float, to: float) -> bool:
	return arena != null and arena.ceiling_between(from, to)


## True if a pickup waits in `lane` within `margin` of track distance `at`.
func pickup_near(lane: int, at: float, margin: float) -> bool:
	if world.pickups == null:
		return false
	for p: Pickup in world.pickups.active:
		if is_instance_valid(p) and p.lane == lane and absf(p.at - at) < margin:
			return true
	return false


# --- Phases ----------------------------------------------------------------------------------------

func _on_phase_started(index: int) -> void:
	slash.clear()
	hands.clear()
	dark.clear()
	line = _pattern(index)
	if index == 0 and carried_time <= 0.0 and body.fade > 0.0:
		# Its entrance: it rises out of the street far ahead and drifts in.
		_move(Step.ENTER, enter_pose(), hover_pose(), phase().intro_seconds)
		sound(&"sleep_taker_rise", world.lane_point(lane_count() / 2, player_distance() + tuning.enter_ahead, 4.0))
		log_event(&"enter")
	else:
		# DESIGN-TBD (task E5c-b: an EMP tore a chunk away): it re-forms where it hovers.
		_move(Step.REFORM, pose, hover_pose(), phase().intro_seconds)
		log_event(&"reform")


func _intro_tick(delta: float) -> void:
	_bob += delta
	step_time += delta
	var k: float = clampf(step_time / maxf(_seconds, 0.05), 0.0, 1.0)
	if step == Step.ENTER:
		# Up out of the street fast, then easing in; materializing as it comes.
		pose = _from.lerp(_to, 1.0 - pow(1.0 - k, 2.5))
		body.fade = 1.0 - smoothstep(0.0, 0.75, k)
		body.inhale = 0.6 * sin(PI * k)
		if step_time < delta * 1.5:
			world.effects.shake(0.2, 1.2)
	else:
		pose = _from.lerp(_to, smoothstep(0.0, 1.0, k))
	_place()


func _on_pattern_started(_index: int) -> void:
	_set_step(Step.HOVER)
	body.fade = 0.0
	body.inhale = 0.0
	pose = hover_pose()
	_gap_left = tuning.first_attack_delay
	_was_busy = false


func _pattern_tick(delta: float) -> void:
	_bob += delta
	step_time += delta
	slash.tick(delta)
	hands.tick(delta)
	dark.tick(delta)
	_schedule(delta)
	_place()


func _on_defeated() -> void:
	slash.clear()
	hands.clear()
	dark.clear()
	set_light_level(1.0, tuning.return_seconds)
	log_event(&"defeat")
	# DESIGN-TBD (task E5c-b brings the wisps, the silence and the grey dawn): it dissolves.
	sound(&"bad_dream_dissolve", body.mouth_world())


func _defeated_tick(delta: float) -> void:
	_bob += delta
	slash.tick(delta)
	body.fade = clampf(state_time / DEFEAT_SECONDS, 0.0, 1.0)
	_place()


func victory_over() -> bool:
	if world == null or world.player == null or not world.player.alive:
		return true
	return state_time >= DEFEAT_SECONDS


# --- The pattern -----------------------------------------------------------------------------------

## The phase's attack list, keeping only the kinds it knows.
func _pattern(index: int) -> PackedStringArray:
	var out := PackedStringArray()
	for kind: String in tuning.pattern_for(index):
		if KINDS.has(kind):
			out.append(kind)
		else:
			push_warning("SleepTaker: unknown attack '%s' in phase %d's list" % [kind, index + 1])
	if out.is_empty():
		out.append("hands")
	return out


## One attack at a time, attack_gap apart: a refuge's slash when its moment comes, otherwise the
## phase's next attack that can start fairly and be over before the next refuge's slash.
func _schedule(delta: float) -> void:
	var busy: bool = slash.busy() or hands.busy() or dark.warning_on()
	if _was_busy and not busy:
		_gap_left = tuning.attack_gap / pace()
	_was_busy = busy
	var d: float = player_distance()
	var v: float = _speed()
	var refuge: Dictionary = next_refuge()
	if not refuge.is_empty() and not _hinted.has("refuge") and (float(refuge["warn_at"]) - d) / v <= REFUGE_HINT_LEAD:
		_hint("refuge")
	if busy:
		return
	_gap_left = maxf(_gap_left - delta, 0.0)
	if not refuge.is_empty() and d >= float(refuge["warn_at"]):
		_used[refuge["key"]] = true
		slash.start(float(refuge["pad"]))
		_was_busy = true
		return
	if _gap_left > 0.0:
		return
	var until_refuge: float = INF if refuge.is_empty() else (float(refuge["warn_at"]) - d) / v
	for i: int in line.size():
		if _try_start(line[i], until_refuge):
			line.remove_at(i)
			if line.is_empty():
				line = _pattern(phase_index)
			_was_busy = true
			return


## Starts an attack of `kind` if it can start fairly now and be over (with the gap after it) before the
## next refuge's slash, `until_refuge` seconds away.
func _try_start(kind: String, until_refuge: float) -> bool:
	var gap: float = tuning.attack_gap / pace()
	match kind:
		"hands":
			var plan: Dictionary = hands.plan()
			if plan.is_empty():
				return false
			var over: float = hands.warning_seconds() + (tuning.hand_depth * 0.5 + SleepTakerHands.PASSED) / _speed()
			if over + gap > until_refuge:
				return false
			hands.start(plan)
			_hint("hands")
			return true
		"lights_out":
			if not dark.idle() or tuning.inhale_seconds + tuning.dim_seconds + gap > until_refuge:
				return false
			dark.start()
			_hint("lights_out")
			return true
	return false


func _hint(key: String) -> void:
	if _hinted.has(key):
		return
	_hinted[key] = true
	hint_due.emit("%s/%s" % [def.id, key])


func _speed() -> float:
	return maxf(world.player.speed, 1.0) if world != null and world.player != null else 18.0


# --- Placing it --------------------------------------------------------------------------------------

## Puts the nightmare where its pose says, bobbing slowly and leaning toward the runner's side; lunging,
## it rushes in until its claws are lunge_gap in front of the runner.
func _place() -> void:
	if body == null or not is_instance_valid(body):
		return
	var p: Player = world.player
	if step == Step.HOVER and state != State.DEFEATED:
		var target: float = p.position.x * tuning.drift_share
		pose.x = move_toward(pose.x, target, tuning.drift_speed * get_physics_process_delta_time())
	var ahead: float = lerpf(pose.z, tuning.lunge_gap + body.claw_reach(), slash.pull())
	var bob: float = 0.25 * sin(_bob * 0.8)
	var lean: float = atan2(p.position.x - pose.x, maxf(ahead, 1.0)) * 0.6
	body.set_pose(Vector3(pose.x, pose.y + bob, TrackGeometry.world_z(player_distance() + ahead)), lean)


func _move(next: Step, from: Vector3, to: Vector3, seconds: float) -> void:
	_set_step(next)
	_from = from
	_to = to
	_seconds = maxf(seconds, 0.05)


func _set_step(next: Step) -> void:
	step = next
	step_time = 0.0

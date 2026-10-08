class_name SleepTaker
extends BossEncounter
## The Sleep Taker, the Dead Zone's boss (GDD §10): in the Dead Zone, a dead cyborg's Bad Dream doesn't
## dissolve; over the years they drifted together through the ruins and fused into one colossal
## nightmare haunting the silent city (SleepTakerBody, SleepTakerModel). Task E5c: E5c-a built the
## nightmare, its arena, its entrance and its three attacks, with weapons having no effect; E5c-b hurting
## it (the generators, the lure, the EMP tearing a chunk away), the three phases, the defeat, and its place
## in the campaign (the Dead Zone's boss step; debug builds also: --boss=dead_zone_boss).
##
## Weapons have no effect (GDD §10: immune to weapons, like every Bad Dream): its body is immune_to_weapons
## (no targeting, no damage, direct or splash: R2's rule for hosts) and its BossDef's weapon_share_cap is 0.
## Only an EMP hurts it: GDD §10, "glowing fence generators stand along the route. The player lures it
## close (it lunges toward them), then destroys the generator with a stomp or the dash; the EMP rips a
## chunk of the nightmare away" (SleepTakerLure; weapons never set a generator off, GDD §9.1).
##
## The arena (BossDef.arena, data/bosses/dead_zone_boss.tres): the Dead Zone's rubble street with holes
## and fences, in the Dead Zone's look with nothing hung over the street where it looms
## (data/bosses/dead_zone_boss_skin.tres), darker than normal but never pitch black (the arena config's
## LevelConfig.darkness: only the scenery dims; glows, the runner and the enemies keep their light), no
## signs on its walls. Each lap carries its refuges (_plan_lap): every refuge_spacing metres a charred
## bridge across the street (the Dead Zone's ceiling look) with pads before it (the middle lane's, or
## every lane's: SleepTakerTuning.refuge_pads_every_lane), the track kept clear of holes and fences
## where the slash's warning and escape happen and where its riders land. Owner, October 8, 2026 (task
## H9): its side walls have many gaps (the arena opts in, LevelConfig.wall_gap_tuning:
## data/bosses/dead_zone_boss_wall_gaps.tres), kept whole over each refuge's stretch, and once the
## refuges are in, each lap gets twice the floor gaps it was first built with (_more_floor_gaps).
##
## Each phase (GDD §10: three phases, three EMP hits, hungrier each time):
## 1. Its intro. The first phase's is its entrance: it rises out of the street far ahead, materializing
##    with a swelling chorus of moans (sleep_taker_rise), and drifts in to loom over the street ahead of
##    the runner. Later ones follow an EMP that tore a chunk away (SleepTakerBody.tear: its left cluster
##    of heads, then its right): it recoils from where it was lured in, howling, and re-forms where it
##    hovers.
## 2. Its pattern: it hovers hover_ahead in front of the runner, keeping pace, and attacks. The giant
##    slash (SleepTakerSlash) comes at every refuge, timed so its claws strike while a runner who took a
##    pad rides the ceiling: GDD §10, it can't reach the ceiling, so the pads are the refuge from the big
##    slashes (at 3 lanes a three-lane slash covers the whole street; at 5 and 6 leaving its lanes dodges
##    it too). Between refuges the phase's attack list (SleepTakerTuning.attack_patterns) runs in order,
##    the first attack that can start fairly going next: grasping hands (SleepTakerHands) and lights out
##    (SleepTakerLightsOut), one at a time, attack_gap apart, never one that would still be on when the
##    next refuge's slash or the next lure is due (a round of hands takes the rows that fit). Lights
##    out's darkness lasts while the next attacks come (half as bright as first built: its light and
##    scenery floors are its own, light_floor and scenery_floor). generator_delay into the pattern a
##    generator comes into sight (_update_generator, SleepTakerLure.place), and as the runner nears it
##    the nightmare lunges in after them (the lure, attacking nothing); smashed while it's in reach, the
##    generator's EMP ends the phase (_on_part_emp); missed, another follows generator_again later.
## 3. The last EMP beats it (SleepTakerDefeat): it bursts into hundreds of wisps, the music fades to
##    silence (no victory riff: victory_riff), and the first grey dawn breaks before the results.
## Every attack has its visual and audio warning (sound() plays and logs each), none overlaps another's,
## and the hands come in rounds of rows spread along the street, each row making the runner switch
## lanes, with hands on the walls too (SleepTakerHands; owner, October 8, 2026), growing from
## hand_rows_first rows to hand_rows_max. The refuges are the track's, the lists and generators the
## phase's, so every attempt plays the same way for the same runner. The phase's pace speeds up the hands
## and the gaps (GDD §10: hungrier each phase: faster hands, more lights out in the later lists); the
## slash and lights out keep their timings (the slash's warning is what gets a runner to a pad).
## Distances that stand for a time follow the run's pace (run_pace()), so the fight keeps its seconds at
## the Dead Zone's 24.2 m/s. Numbers: SleepTakerTuning (data/bosses/dead_zone_boss_tuning.tres), all
## DESIGN-TBD (docs/questions/e5c.md, docs/questions/h9.md).

enum Step { ENTER, HOVER, REFORM }

const BODY_SCRIPT: Script = preload("res://scripts/bosses/sleep_taker/sleep_taker_body.gd")
## The attacks its pattern lists may name.
const KINDS: PackedStringArray = ["hands", "lights_out"]
## A refuge's hint shows this long before its slash's warning.
const REFUGE_HINT_LEAD: float = 4.0
## How far ahead it looks for the track's refuges (metres at 18 m/s, times run_pace()).
const SIGHT: float = 400.0
## A round of hands that can't come yet is looked for again this long after (seconds).
const HANDS_RETRY: float = 0.1

var body: SleepTakerBody
var tuning: SleepTakerTuning
var slash: SleepTakerSlash
var hands: SleepTakerHands
var dark: SleepTakerLightsOut
var lure: SleepTakerLure
var defeat: SleepTakerDefeat
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
## Seconds until the next generator may come (generator_delay into a phase's pattern, generator_again
## after a miss).
var _generator_wait: float = 0.0
var _lure_was_busy: bool = false
## How far ahead of the runner it's drawn now (its pose, the slash's lunge and the lure's pull), metres.
var _ahead: float = 0.0
## Seconds until a round of hands is looked for again (HANDS_RETRY after one couldn't be planned).
var _hands_wait: float = 0.0


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
	lure = SleepTakerLure.new()
	add_child(lure)
	lure.setup(self)
	defeat = SleepTakerDefeat.new()
	add_child(defeat)
	defeat.setup(self)
	var resume: int = int(context.boss_resume.get("phase", 0))
	if resume > 0:
		# Resuming at a later phase (a review's --phase=N): it's already here, its chunks already torn.
		pose = hover_pose()
		body.fade = 0.0
		for chunk: int in mini(resume, SleepTakerModel.CHUNK_HEADS.size()):
			body.tear(chunk, true)
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
## warning finds the runner (and a jump before it) to past where it strikes, and where its riders land;
## its walls kept whole (no wall gap: refuge_wall_span()) over that whole stretch. Then the lap's extra
## floor gaps (_more_floor_gaps).
## The generators its lures bring (SleepTakerLure), readied during the fight's load (task PERF1).
func warm_enemies() -> Array[Dictionary]:
	return [{"type": "generator", "at": 0.0, "lane": 0, "side": 0, "seed": 1, "params": {}}]


func _plan_lap(lap: LevelLayout, index: int, p_arena: BossArena) -> void:
	lap.signs.clear()
	var t: SleepTakerTuning = _tuning()
	var v: float = p_arena.tuning.run_speed
	var k: float = p_arena.tuning.pace()
	var n: int = lap.lane_count
	var zones: CeilingZones = CeilingZones.make(p_arena.config, p_arena.tuning)
	var lead_in: float = p_arena.config.hull_lead_in
	var span: Vector2 = refuge_clear_span(t, p_arena.tuning, v)
	var plan: Array[Dictionary] = []
	var pad: float = t.refuge_first * k
	while true:
		var end: float = pad + t.refuge_seconds * v
		var landing: Vector2 = zones.landing_zone({"start": pad - lead_in, "end": end})
		if landing.y > p_arena.lap_length - 1.0:
			break
		_clear_track(lap, pad + span.x, pad + span.y)
		zones.clear_landing(lap, landing)
		var walls: Vector2 = refuge_wall_span(t, p_arena, pad)
		_clear_walls(lap, walls.x, walls.y)
		for i: int in range(lap.hulls.size() - 1, -1, -1):
			if float(lap.hulls[i]["start"]) <= end + 1.0 and float(lap.hulls[i]["end"]) >= pad - lead_in - 1.0:
				lap.hulls.remove_at(i)
		lap.hulls.append(LevelLayout.make_hull(pad - lead_in, end, Vector2i(0, n - 1), n))
		for lane: int in pad_lanes(n, t):
			lap.pads.append({"lane": lane, "at": pad})
		plan.append({"pad": pad, "end": end})
		pad += t.refuge_spacing * k
	_refuge_plan[index] = plan
	_more_floor_gaps(lap, index, p_arena, t, plan)


## The stretch around a refuge whose pads are at `pad` (track distances) where both walls stay whole:
## from where the slash's warning finds the runner (refuge_warn_at) to its bridge's end, past where it
## strikes and recovers, widened either way by the arena's wall gaps' own clearance
## (WallGapTuning.clear_seconds, the room a level's wall gaps keep from a ceiling). A runner who takes to
## a wall as the slash warns (its claws never reach a wall runner) is never dropped into it by a gap, and
## the bridge never hangs over a missing wall.
static func refuge_wall_span(t: SleepTakerTuning, p_arena: BossArena, pad: float) -> Vector2:
	var v: float = p_arena.tuning.run_speed
	var warn: float = pad + v * t.strike_after_pad - v * t.slash_warning()
	var strike_over: float = pad + v * (t.strike_after_pad + t.slash_active + t.slash_recover) + t.slash_depth
	var end: float = pad + t.refuge_seconds * v
	var clear: float = WallGapPlacement.tuning_for(p_arena.config).clear_seconds * v
	return Vector2(minf(warn, pad - p_arena.config.hull_lead_in) - clear, maxf(end, strike_over) + clear)


## Owner, October 8, 2026: "double the amount of floor gaps". Once a lap's refuges are in, the
## generator's additive gap pass (GapDensity, over the lap as it stands: LevelGenerator.for_layout) adds
## floor_gap_increase as many rows of holes again as the lap has (1: twice as many as first built), each
## as wide as the lap's rows on average with an open lane left, never moving anything, floor_gap_spacing
## seconds at run speed from every other hole, fence, pad and ceiling (and its landing). Stand-in ceilings
## over each refuge's clear stretch keep the new rows off where its slash warns and its riders land
## while it runs. Its own random stream (from the lap's seed), so the arena is the same every attempt.
static func _more_floor_gaps(lap: LevelLayout, index: int, p_arena: BossArena, t: SleepTakerTuning,
		refuges: Array[Dictionary]) -> void:
	if t.floor_gap_increase <= 0.0:
		return
	var config: LevelConfig = p_arena.config.duplicate() as LevelConfig
	config.level_seed = hash([p_arena.config.level_seed, index, "sleep_taker_floor_gaps"])
	# As BossArena plans the lap: its clear start and end keep their seconds at the run's pace.
	config.start_clear_distance = p_arena.config.start_clear_distance * p_arena.tuning.pace()
	config.end_clear_distance = p_arena.config.end_clear_distance * p_arena.tuning.pace()
	config.gap_encounter_increase = t.floor_gap_increase
	config.gap_lane_increase = 0.0
	config.spacing_seconds_hard = t.floor_gap_spacing
	var span: Vector2 = refuge_clear_span(t, p_arena.tuning, p_arena.tuning.run_speed)
	var n: int = lap.lane_count
	var hulls: int = lap.hulls.size()
	for r: Dictionary in refuges:
		var pad: float = float(r["pad"])
		lap.hulls.append(LevelLayout.make_hull(pad + span.x, pad + span.y, Vector2i(0, n - 1), n))
	GapDensity.apply(LevelGenerator.for_layout(config, p_arena.tuning, lap))
	lap.hulls.resize(hulls)


## The stretch around a refuge's pads (relative to them) that stays clear of holes and fences in every
## lane: from a jump before where the slash's warning finds the runner, to past where it strikes (the
## runner's way to a pad, or to a lane outside the slash, and the pad's run-up and rise).
static func refuge_clear_span(t: SleepTakerTuning, movement: MovementTuning, v: float) -> Vector2:
	var before: float = v * (t.slash_warning() - t.strike_after_pad) + movement.jump_distance(v)
	var after: float = v * t.strike_after_pad + t.slash_depth + t.escape_clear_after * movement.pace()
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
	var v: float = speed()
	for r: Dictionary in refuges_between(d - 5.0, d + SIGHT * run_pace()):
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
	var v: float = speed()
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


## Takes the wall gaps (any part of one, on either wall) out of the stretch between two track distances.
static func _clear_walls(lap: LevelLayout, from: float, to: float) -> void:
	for i: int in range(lap.wall_gaps.size() - 1, -1, -1):
		if float(lap.wall_gaps[i]["start"]) <= to and float(lap.wall_gaps[i]["end"]) >= from:
			lap.wall_gaps.remove_at(i)


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
	lure.clear()
	line = _pattern(index)
	if index == 0 and carried_time <= 0.0 and body.fade > 0.0:
		# Its entrance: it rises out of the street far ahead and drifts in.
		_move(Step.ENTER, enter_pose(), hover_pose(), phase().intro_seconds)
		sound(&"sleep_taker_rise", world.lane_point(lane_count() / 2, player_distance() + tuning.enter_ahead, 4.0))
		log_event(&"enter")
	else:
		# An EMP tore a chunk away (the phase before ended): it recoils from where it was lured in,
		# howling, and re-forms where it hovers, hungrier (the phase's pace and list).
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
		# Torn (a phase after an EMP): it recoils to where it hovers, every maw gaping in pain.
		pose = _from.lerp(_to, smoothstep(0.0, 1.0, k))
		body.inhale = 0.7 * sin(PI * minf(k * 1.3, 1.0))
	_place()


func _on_pattern_started(_index: int) -> void:
	_set_step(Step.HOVER)
	body.fade = 0.0
	body.inhale = 0.0
	pose = hover_pose()
	_gap_left = tuning.first_attack_delay
	_hands_wait = 0.0
	_was_busy = false
	_generator_wait = tuning.generator_delay
	_lure_was_busy = false


func _pattern_tick(delta: float) -> void:
	_bob += delta
	step_time += delta
	slash.tick(delta)
	hands.tick(delta)
	dark.tick(delta)
	lure.tick(delta)
	_schedule(delta)
	_place()


## A generator's EMP went off (RunWorld.emp reaches every enemy, so every EMP calls this): within
## emp_reach of the nightmare during its pattern (SleepTakerLure.reaches), it tears a chunk of it away,
## the phase's big hit (damage(hit_damage(), &"emp"): GDD §10, three phases, three EMP hits); otherwise
## nothing happens to it.
func _on_part_emp(_part: BossPart, center: Vector3, _radius: float) -> void:
	var gap: float = absf(body.global_position.z - center.z)
	if state != State.FIGHT:
		log_event(&"emp_missed", {"why": &"not_vulnerable", "gap": gap})
		return
	if not lure.reaches(center):
		log_event(&"emp_missed", {"why": &"out_of_reach", "gap": gap})
		return
	# It recoils from where it is now (lured in close).
	pose.z = _ahead
	log_event(&"emp_hit", {"gap": gap})
	if not is_final_phase():
		body.tear(phase_index)
		sound(&"sleep_taker_torn", body.mouth_world())
		world.effects.shake(0.3, 0.6)
	damage(hit_damage(), &"emp")


## The last EMP: it bursts into its wisps, the music fades to silence and the grey dawn breaks
## (SleepTakerDefeat); every attack stops, and the light comes back first.
func _on_defeated() -> void:
	slash.clear()
	hands.clear()
	dark.clear()
	lure.clear()
	set_light_level(1.0, tuning.return_seconds)
	log_event(&"defeat")
	defeat.start()


func _defeated_tick(delta: float) -> void:
	_bob += delta
	slash.tick(delta)
	defeat.tick(delta)
	_place()


## Once its wisps have risen and the dawn has broken (or at once if the runner is gone).
func victory_over() -> bool:
	if world == null or world.player == null or not world.player.alive:
		return true
	return defeat.over()


## Its defeat ends in silence (GDD §10): no victory riff.
func victory_riff() -> bool:
	return false


## Lights out's own floors (owner, October 8, 2026: half as bright as first built; still never pitch
## black): its tuning's, below every other boss's (BossEncounter.MIN_LIGHT_LEVEL and
## ZoneSkin.MIN_SCENERY_LIGHT).
func light_floor() -> float:
	return (tuning if tuning != null else _tuning()).light_floor


func scenery_floor() -> float:
	return (tuning if tuning != null else _tuning()).scenery_floor


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
## phase's next attack that can start fairly and be over before the next refuge's slash and before a
## generator's lure; none while the nightmare is lured. A generator comes when one is due and nothing
## warns or strikes (_update_generator); its lure follows by itself (SleepTakerLure).
func _schedule(delta: float) -> void:
	var busy: bool = slash.busy() or hands.busy() or dark.warning_on()
	if _was_busy and not busy:
		_gap_left = tuning.attack_gap / pace()
	_was_busy = busy
	var d: float = player_distance()
	var v: float = speed()
	var refuge: Dictionary = next_refuge()
	if not refuge.is_empty() and not _hinted.has("refuge") and (float(refuge["warn_at"]) - d) / v <= REFUGE_HINT_LEAD:
		_hint("refuge")
	_update_generator(delta, busy)
	if busy:
		return
	_gap_left = maxf(_gap_left - delta, 0.0)
	if not refuge.is_empty() and d >= float(refuge["warn_at"]):
		_used[refuge["key"]] = true
		slash.start(float(refuge["pad"]))
		_was_busy = true
		return
	if _gap_left > 0.0 or lure.luring() or lure.stage == SleepTakerLure.Stage.RELEASE:
		return
	var until_refuge: float = INF if refuge.is_empty() else (float(refuge["warn_at"]) - d) / v
	if lure.stage == SleepTakerLure.Stage.WAITING:
		until_refuge = minf(until_refuge, (lure.lure_at(float(lure.site["at"]), v) - d) / v)
	_hands_wait = maxf(_hands_wait - delta, 0.0)
	# Each kind once a frame: a kind that can't start now can't start for a later entry either.
	var tried := PackedStringArray()
	for i: int in line.size():
		if tried.has(line[i]):
			continue
		tried.append(line[i])
		if _try_start(line[i], until_refuge):
			line.remove_at(i)
			if line.is_empty():
				line = _pattern(phase_index)
			_was_busy = true
			return


## Brings the next generator when one is due: generator_delay into the phase's pattern, or
## generator_again after the last one's lure ended without its EMP reaching the nightmare; only while
## nothing warns or strikes, and never while one is still in play.
func _update_generator(delta: float, busy: bool) -> void:
	if lure.busy():
		_lure_was_busy = true
		return
	if _lure_was_busy:
		_lure_was_busy = false
		_generator_wait = maxf(_generator_wait, tuning.generator_again)
	_generator_wait = maxf(_generator_wait - delta, 0.0)
	if _generator_wait > 0.0 or busy or world.player.surface != Player.Surface.FLOOR:
		return
	if lure.place():
		_hint("generator")


## Starts an attack of `kind` if it can start fairly now and be over (with the gap after it) before the
## next refuge's slash or the next lure, `until_refuge` seconds away (a round of hands takes the rows that
## fit: SleepTakerHands.plan).
func _try_start(kind: String, until_refuge: float) -> bool:
	var gap: float = tuning.attack_gap / pace()
	match kind:
		"hands":
			if _hands_wait > 0.0:
				return false
			var plan: Dictionary = hands.plan(until_refuge - gap)
			if plan.is_empty():
				# The planner is the fight's costliest check (each way through a round, TheHouseRoute): a
				# round that can't come now is looked for again a moment later, not every frame.
				_hands_wait = HANDS_RETRY
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


## The runner's speed now (m/s).
func speed() -> float:
	return maxf(world.player.speed, 1.0) if world != null and world.player != null else MovementTuning.REFERENCE_SPEED


## The run's speed over the reference 18 m/s (MovementTuning.pace()): the tuning's distances that stand
## for a time are written at 18 m/s and multiplied by it, so the fight keeps its seconds at any speed.
## (Not the phase's pace(): that one makes a phase hungrier.)
func run_pace() -> float:
	if world != null and world.tuning != null:
		return world.tuning.pace()
	if arena != null and arena.tuning != null:
		return arena.tuning.pace()
	return 1.0


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
	ahead = lerpf(ahead, lure.lure_ahead(), lure.pull())
	_ahead = ahead
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

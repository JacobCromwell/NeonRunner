class_name GoldenConvergence
extends BossEncounter
## The Golden Convergence, the Golden Zone's boss and the final villain (GDD §10: "a giant mechanical
## construct, a golden exoskeleton that the villain rides inside ... It floats in the distance ahead of the
## runner"; the man inside is The Magnate). Task E5d, in four steps, each merging on its own: E5d-a (this
## one) the golden suit, the Grand Court, the entrance, the Helidrone Strafe and the Flying Buttress, phase
## 1's opening strafe, the slot's preview, its tuning, sounds, showcase, bot and tests; E5d-b the Fist Slam
## and the Missile Barrage; E5d-c the Refill Ship, stage 1's three phases and the suit's damage; E5d-d stage
## 2, The Magnate, the defeat and the campaign slot. Until E5d-d it plays as a preview: debug builds start it
## with --boss=golden_boss (BossDef.preview_scene), the campaign keeps its card.
##
## The arena (GDD §10, proposed): the Grand Court, a plain causeway (_plan_lap clears every lap: no holes,
## fences, ceilings, doodads or enemies of its own; every danger is the boss's) in its own look
## (GoldenCourtSkin, data/bosses/golden_boss_skin.tres): balustrades for walls, reflecting pools far below, the
## palace's towers with their giant feed screens, the vast hall. No side walls: the court
## (GoldenConvergenceCourt) keeps both walls taken away ahead of the runner, so a move past the outer lane
## bumps them back with the clank, and opens a stretch of wall when something brings one (E5d-b's toppled
## tower: court.open_wall).
##
## The suit (GoldenConvergenceSuit, the fight's body: weapons chip it, aimed at its chest) floats
## suit_ahead in front of the runner, pacing them, swaying gently. Each phase:
## 1. Its intro. The first phase's is the entrance (GDD §10, proposed): it rises into view at the far end
##    from the depths beside the causeway, its cape unfurling into its cloud, and the cult's three-note
##    chime (the Resonator's notes, gc_chime) rings out huge and slow; the calm golden face looks down the
##    causeway at the runner. A later stage 1 phase's: it reels back from the blast and recovers (reel). Stage
##    2's (phases 4-6, The Magnate, E5d-d: the block at the end): phase 4's the transition (on a retry from the
##    checkpoint too), phases 5 and 6's his hurl clear after a stomp.
## 2. Its pattern: a beat script (GoldenConvergenceTuning.phase_beats), one beat at a time, beat_gap apart
##    (divided by the phase's pace): phase 1 the strafe on its own (3 passes), slams, a barrage, the Refill
##    Ship with a strafe, then from the slams again (loop_from); phases 2 and 3 slams, a barrage, slams, a
##    barrage and the Refill Ship with a 7-pass strafe, round and round. Each beat kind is an attack of its
##    own class (GoldenConvergenceAttack: start, tick, busy, hold, clear; register_attack): E5d-a's is the
##    Helidrone Strafe (GoldenConvergenceStrafe); a beat whose attack isn't built yet is a stub the pattern
##    skips and logs (beat_stub), except that until E5d-c builds the Refill Ship a refill beat plays its
##    strafe alone, so the preview's phases loop the strafe (and the 7-pass strafe in phases 2 and 3).
## Nothing in a pattern depends on how long the fight or the attempt has lasted (no escalation); random
## choices come from seeds of the fight (each strafe's own), time from the physics step: every attempt with
## the same inputs plays the same. Distances that stand for a time follow the run's pace (run_pace(): the
## Golden Zone's 25 m/s in the campaign). Every warning plays through sound() (logged) and shows on the floor
## (BossProps' red lines, or cross_warning's bars across a lane). Numbers: GoldenConvergenceTuning
## (data/bosses/golden_boss_tuning.tres), all DESIGN-TBD (docs/questions/e5d.md).
##
## Extension points for the later steps: register_attack() (each attack's file), place_buttress() and the
## buttress pool (GoldenConvergenceButtress: at, lane, lean, span(), smash()), court.open_wall()/close_wall(),
## the suit's handles (set_arm, pipes_open, set_pipes_broken, burst, cape_point, pipe_mouth, hand_point), the
## strafe's hold() and `hurled` (the Refill Ship's chain reaction), the skin's feed (GoldenCourtSkin.set_feed,
## set_feed_blackout), tuning groups per attack, and the stage 2 stub (_on_phase_started).

enum Step { ENTER, FLOAT, REEL, IDLE }

const SUIT_SCRIPT: Script = preload("res://scripts/bosses/golden_convergence/golden_convergence_suit.gd")
const SQUADRON_SCRIPT: Script = preload("res://scripts/bosses/golden_convergence/golden_convergence_squadron.gd")
const FIRE_SCRIPT: Script = preload("res://scripts/bosses/golden_convergence/golden_convergence_fire.gd")
## Buttresses made with the fight (the pool grows if a later step needs more at once).
const BUTTRESS_POOL: int = 4
## A buttress goes back to the pool once the runner is this far past it.
const BUTTRESS_BEHIND: float = 30.0
## Stage 2 begins at this phase (The Magnate, E5d-d).
const STAGE_2: int = 3
## A sound of something far off plays where it's heard: at most this far ahead of the runner, this far behind
## (positional sounds fade out by SfxLibrary.warning_max_distance).
const SOUND_AHEAD: float = 26.0
const SOUND_BEHIND: float = 14.0

var tuning: GoldenConvergenceTuning
var suit: GoldenConvergenceSuit
var squadron: GoldenConvergenceSquadron
var fire: GoldenConvergenceFire
var court: GoldenConvergenceCourt
var strafe: GoldenConvergenceStrafe
## The attacks by beat kind (register_attack).
var attacks: Dictionary = {}
var buttresses: Array[GoldenConvergenceButtress] = []
var step: Step = Step.FLOAT
var step_time: float = 0.0
## The phase's beat script ({kind, arg} in order), the beat under way, the attack playing it, and the wait
## before the next one.
var beats: Array[Dictionary] = []
var beat_index: int = -1
var beat_attack: GoldenConvergenceAttack = null
var beat_wait: float = 0.0
## Beats played (and stubs skipped) this fight.
var beats_played: int = 0
var stubs_skipped: int = 0

var _hinted: Dictionary = {}
var _chimed: bool = false
var _idle_logged: bool = false
var _t: float = 0.0
var _solid: ShaderMaterial
## The bars across a lane (cross_warning): {node, base, t}, pulsing (steady with Reduced flashing).
var _cross: Array[Dictionary] = []


func _tuning() -> GoldenConvergenceTuning:
	var t := (def.tuning as GoldenConvergenceTuning) if def != null else null
	return t if t != null else GoldenConvergenceTuning.new()


# --- The arena ---------------------------------------------------------------------------------------

## GDD §10's Grand Court, plain (proposed: "The track itself is plain: no holes, fences, ceilings, doodads or
## enemies of its own. Every danger is the boss's").
func _plan_lap(lap: LevelLayout, _index: int, _arena: BossArena) -> void:
	lap.gaps.clear()
	lap.fences.clear()
	lap.signs.clear()
	lap.hulls.clear()
	lap.pads.clear()
	lap.ramps.clear()
	lap.speed_pads.clear()
	lap.enemies.clear()
	lap.doodads.clear()
	lap.cuts.clear()
	lap.wall_fences.clear()
	lap.credits.clear()


func _build_boss() -> void:
	tuning = _tuning()
	suit = add_part(SUIT_SCRIPT, {"tuning": tuning}) as GoldenConvergenceSuit
	squadron = add_part(SQUADRON_SCRIPT, {"tuning": tuning}) as GoldenConvergenceSquadron
	fire = add_part(FIRE_SCRIPT, {"tuning": tuning}) as GoldenConvergenceFire
	court = GoldenConvergenceCourt.new(self)
	for i: int in BUTTRESS_POOL:
		_new_buttress()
	strafe = GoldenConvergenceStrafe.new(self)
	register_attack(strafe)
	# E5d-b: register_attack(GoldenConvergenceSlams.new(self)), register_attack(GoldenConvergenceBarrage...);
	# E5d-c: register_attack(GoldenConvergenceRefill.new(self)); E5d-d: stage 2's.
	for attack: GoldenConvergenceAttack in attacks.values():
		attack.prewarm()
	_build_stage_two()
	var skin := world.skin as GoldenCourtSkin
	if skin != null:
		skin.reset_feed()
	court.tick()
	_place_suit()


## Adds an attack the beat script can play, under its beat kind (GoldenConvergenceAttack.kind).
func register_attack(attack: GoldenConvergenceAttack) -> void:
	attacks[attack.kind] = attack


## The kit's solid material with the Golden Zone's gold (the court's own: the suit and the buttresses are
## the palace's metal and marble).
func solid_material() -> ShaderMaterial:
	if _solid == null:
		var skin := world.skin as GoldenSkin if world != null else null
		_solid = skin.solid_material() if skin != null else GoldenSkin.new().solid_material()
	return _solid


# --- Helpers ---------------------------------------------------------------------------------------

## The runner's speed now (m/s).
func speed() -> float:
	return maxf(world.player.speed, 1.0) if world != null and world.player != null else MovementTuning.REFERENCE_SPEED


## The run speed the fight plans with (its arena's: the Golden Zone's 25 m/s in the campaign).
func speed_planned() -> float:
	if world != null and world.tuning != null:
		return world.tuning.run_speed
	return arena.tuning.run_speed if arena != null and arena.tuning != null else MovementTuning.REFERENCE_SPEED


## The run's speed over the reference 18 m/s (MovementTuning.pace()): the tuning's distances that stand for a
## time are written at 18 m/s and multiplied by it. (Not the phase's pace().)
func run_pace() -> float:
	if world != null and world.tuning != null:
		return world.tuning.pace()
	if arena != null and arena.tuning != null:
		return arena.tuning.pace()
	return 1.0


## The lane the runner is in or heading for (a wall runner counts as the outer lane on that side).
func player_lane() -> int:
	var p: Player = world.player
	if p.surface == Player.Surface.WALL:
		return 0 if p.wall_side < 0 else lane_count() - 1
	return clampi(p.lane, 0, lane_count() - 1)


## Plays a sound at `pos` and notes it (every warning is heard: tests read the notes).
func sound(sound_name: StringName, pos: Vector3) -> void:
	world.play_sfx_at(sound_name, pos)
	log_event(&"sound", {"name": sound_name})


## Where a sound of something at `pos` plays so it's heard: at most SOUND_AHEAD ahead of the runner and
## SOUND_BEHIND behind them, over the track, in its direction.
func sound_point(pos: Vector3) -> Vector3:
	var d: float = player_distance()
	var at: float = clampf(-pos.z, d - SOUND_BEHIND, d + SOUND_AHEAD)
	var half: float = world.geo.wall_x() + 6.0
	return Vector3(clampf(pos.x, -half, half), clampf(pos.y, 0.5, 10.0), TrackGeometry.world_z(at))


## Asks for a first-time hint of its own (boss:golden_boss/<key>), once a fight.
func hint(key: String) -> void:
	if _hinted.has(key):
		return
	_hinted[key] = true
	hint_due.emit("%s/%s" % [def.id, key])


## True while one of its attacks warns or strikes.
func warning_active() -> bool:
	for attack: GoldenConvergenceAttack in attacks.values():
		if attack.warning_on():
			return true
	return false


## Where drone `i` comes out of the cape (world space).
func cape_point(i: int) -> Vector3:
	return suit.cape_point(i) if suit != null else Vector3(0.0, 20.0, TrackGeometry.world_z(player_distance() + 60.0))


## A red bar across `lane` from track distance `from` to `to`: a horizontal pass's warning line where it
## crosses that lane (GDD §10: "the red warning line crosses every lane except the opening"). Counted as a
## floor warning (BossProps.floor_warning: pickups keep off it, warned() finds it), freed once passed, pulsing
## like BossProps' red lines (steady with Reduced flashing).
func cross_warning(lane: int, from: float, to: float) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = GreyboxMaterials.unit_box()
	mesh.material_override = GreyboxMaterials.glow(BossProps.WARNING_COLOR, 2.6, 0.75)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var width: float = world.geo.lane_width * 0.94
	var base := Transform3D(Basis.from_scale(Vector3(width, 0.04, absf(to - from))),
		Vector3(world.geo.lane_x(lane), 0.03, -(from + to) * 0.5))
	mesh.transform = base
	props.add_child(mesh)
	props.floor_warning(mesh, lane, from, to)
	_cross.append({"node": mesh, "base": base, "t": 0.0})
	return mesh


func _process(delta: float) -> void:
	for i: int in range(_cross.size() - 1, -1, -1):
		var w: Dictionary = _cross[i]
		if not is_instance_valid(w["node"]) or (w["node"] as Node).is_queued_for_deletion():
			_cross.remove_at(i)
			continue
		w["t"] = float(w["t"]) + delta
		# Deepening as it's shown; the beat stops with Reduced flashing (BossProps' red lines do the same).
		var grow: float = 0.85 + 0.25 * clampf(float(w["t"]) / 0.8, 0.0, 1.0)
		var beat: float = 1.0 if Settings.flashing_reduced else 1.0 + 0.12 * sin(float(w["t"]) * 24.0)
		var base: Transform3D = w["base"]
		(w["node"] as Node3D).transform = Transform3D(base.basis * Basis.from_scale(Vector3(1.0, 1.0, grow * beat)), base.origin)


# --- The buttresses ---------------------------------------------------------------------------------

func _new_buttress() -> GoldenConvergenceButtress:
	var b := GoldenConvergenceButtress.new()
	add_child(b)
	b.setup(self)
	buttresses.append(b)
	return b


## Raises a Flying Buttress in `lane` (an inner lane) with its pier's middle at track distance `at`, its
## flying arch leaning to `lean` (-1 left, 1 right; 0: the nearer edge, the middle lane's by the fight's
## seed). Returns it (from the pool).
func place_buttress(lane: int, at: float, lean: int = 0) -> GoldenConvergenceButtress:
	var b: GoldenConvergenceButtress = null
	for candidate: GoldenConvergenceButtress in buttresses:
		if not candidate.in_use():
			b = candidate
			break
	if b == null:
		b = _new_buttress()
	if lean == 0:
		var mid: float = (lane_count() - 1) * 0.5
		lean = -1 if float(lane) < mid - 0.01 else (1 if float(lane) > mid + 0.01 else (-1 if rng.randf() < 0.5 else 1))
	b.place(lane, at, lean)
	return b


## The buttresses standing (or crumbling) whose piers reach into [from, to].
func buttresses_between(from: float, to: float) -> Array[GoldenConvergenceButtress]:
	var out: Array[GoldenConvergenceButtress] = []
	for b: GoldenConvergenceButtress in buttresses:
		if b.in_use() and b.span().x <= to and b.span().y >= from:
			out.append(b)
	return out


func _tick_buttresses(delta: float) -> void:
	var d: float = player_distance()
	for b: GoldenConvergenceButtress in buttresses:
		if not b.in_use():
			continue
		b.tick(delta)
		if d > b.at + BUTTRESS_BEHIND:
			b.release()


# --- Phases ----------------------------------------------------------------------------------------

func _on_phase_started(index: int) -> void:
	_clear_attacks()
	beats = tuning.beats_for(index)
	beat_index = -1
	beat_attack = null
	_idle_logged = false
	var fresh: bool = carried_time <= 0.0 and context.boss_resume.is_empty()
	var resumed_here: bool = not context.boss_resume.is_empty() and int(context.boss_resume.get("phase", -1)) == index \
		and phase_hits == 0 and weak_points_hit == 0 and fight_time() <= carried_time + 0.001
	if index == 0 and fresh:
		# The entrance: it rises at the far end from the depths beside the causeway, its cape furled.
		_set_step(Step.ENTER)
		_chimed = false
		suit.unfurl = 0.0
		sound(&"gc_rise", sound_point(suit.head_point()))
		log_event(&"entrance")
	elif index >= STAGE_2:
		# Stage 2, The Magnate (E5d-d): the transition, or the hurl after a stomp (_start_stage_two).
		_start_stage_two(index)
	elif resumed_here:
		_set_step(Step.FLOAT)
		suit.unfurl = 1.0
	else:
		# A later phase: it reels back from the blast and recovers.
		_set_step(Step.REEL)
		suit.unfurl = 1.0
		log_event(&"reel")
	_place_suit()


func _intro_tick(delta: float) -> void:
	if phase_index >= STAGE_2:
		_stage_two_tick(delta, true)
		return
	step_time += delta
	_t += delta
	court.tick()
	_tick_buttresses(delta)
	match step:
		Step.ENTER:
			var t: GoldenConvergenceTuning = tuning
			suit.unfurl = clampf((step_time - t.unfurl_at) / maxf(t.unfurl_seconds, 0.05), 0.0, 1.0)
			if not _chimed and step_time >= t.chime_at:
				_chimed = true
				sound(&"gc_chime", sound_point(suit.head_point()))
				log_event(&"chime")
		Step.REEL:
			var k: float = clampf(step_time / maxf(phase().intro_seconds, 0.05), 0.0, 1.0)
			suit.reel = sin(PI * k) * (1.0 - k * 0.3)
	_place_suit()


func _on_pattern_started(_index: int) -> void:
	if step == Step.ENTER or step == Step.REEL:
		_set_step(Step.FLOAT)
	suit.unfurl = 1.0
	suit.reel = 0.0
	beat_wait = tuning.first_beat_delay / pace()


func _pattern_tick(delta: float) -> void:
	if phase_index >= STAGE_2:
		_stage_two_tick(delta, false)
		return
	step_time += delta
	_t += delta
	court.tick()
	_tick_buttresses(delta)
	for attack: GoldenConvergenceAttack in attacks.values():
		attack.tick(delta)
	if step != Step.IDLE:
		_tick_beats(delta)
	_place_suit()


## The beat script: the next beat once the one under way is over and beat_gap has passed.
func _tick_beats(delta: float) -> void:
	if beat_attack != null:
		if beat_attack.busy():
			return
		beat_attack = null
		beat_wait = tuning.beat_gap / pace()
	if beat_wait > 0.0:
		beat_wait -= delta
		return
	_next_beat()


## Starts the phase's next beat, skipping the stubs (beats whose attack isn't built yet); with none to play
## in its whole loop it idles.
func _next_beat() -> void:
	if beats.is_empty():
		_log_idle()
		return
	for tries: int in beats.size() + 1:
		beat_index += 1
		if beat_index >= beats.size():
			beat_index = mini(tuning.loop_start(phase_index), beats.size() - 1)
		var beat: Dictionary = beats[beat_index]
		var attack: GoldenConvergenceAttack = _attack_for(beat)
		if attack == null:
			stubs_skipped += 1
			log_event(&"beat_stub", {"kind": beat["kind"], "index": beat_index})
			continue
		beats_played += 1
		beat_attack = attack
		log_event(&"beat", {"kind": beat["kind"], "arg": beat["arg"], "index": beat_index})
		attack.start(beat)
		return
	_log_idle()


func _log_idle() -> void:
	if not _idle_logged:
		_idle_logged = true
		log_event(&"beats_idle")
	beat_wait = INF


## The attack that plays `beat`, or null (a stub: its attack isn't built yet).
func _attack_for(beat: Dictionary) -> GoldenConvergenceAttack:
	var kind: StringName = beat["kind"]
	if attacks.has(kind):
		return attacks[kind]
	# E5d-a's stand-in until E5d-c builds the Refill Ship (GoldenConvergenceRefill): a refill beat plays its
	# strafe alone (the strafe sees the beat's kind: GoldenConvergenceStrafe.refill).
	if kind == &"refill" and attacks.has(&"strafe"):
		return attacks[&"strafe"]
	return null


func _on_phase_ended(_index: int) -> void:
	_clear_attacks()


func _clear_attacks() -> void:
	for attack: GoldenConvergenceAttack in attacks.values():
		attack.clear()
	beat_attack = null


## The fight is won: its attacks stop, the walls stay away, and the defeat plays (the feed dies:
## GoldenConvergenceDefeat).
func _on_defeated() -> void:
	_clear_attacks()
	log_event(&"defeat")
	if defeat != null:
		defeat.start()


func _defeated_tick(delta: float) -> void:
	_t += delta
	court.tick()
	_tick_buttresses(delta)
	_place_suit()
	if defeat != null:
		transition.tick(delta)
		defeat.tick(delta)
		chase.tick(delta)


func _set_step(next: Step) -> void:
	if step != next:
		step_time = 0.0
	step = next


# --- Where the suit floats ---------------------------------------------------------------------------

## The suit's place now: suit_ahead in front of the runner, suit_height up, swaying and bobbing (framing,
## on its own clock); during the entrance, rising from rise_depth below.
func suit_transform() -> Transform3D:
	var t: GoldenConvergenceTuning = tuning
	var x: float = t.sway * sin(_t * TAU * t.sway_hz)
	var y: float = t.suit_height + t.bob * sin(_t * TAU * t.bob_hz)
	if step == Step.ENTER:
		var k: float = clampf(step_time / maxf(t.rise_seconds, 0.05), 0.0, 1.0)
		y -= t.rise_depth * pow(1.0 - k, 2.4)
	var roll: float = 0.02 * sin(_t * TAU * t.sway_hz * 0.7)
	return Transform3D(Basis(Vector3.BACK, roll), Vector3(x, y, TrackGeometry.world_z(player_distance() + t.suit_ahead)))


func _place_suit() -> void:
	if suit != null and is_instance_valid(suit):
		suit.set_pose(suit_transform())


# --- Stage 2: The Magnate (task E5d-d) -------------------------------------------------------------------
# GDD §10, Second stage: the suit destroyed, the man inside hunts the runner from behind (the chase), pounces,
# is baited into a Flying Buttress and stomped on his spine three times, and the feed dies with him. Its parts:
# GoldenConvergenceMagnate (his body, the fight's body in stage 2), GoldenConvergenceChase (his moves between
# attacks), GoldenConvergenceTransition (phase 4's intro, the transition, and phases 5-6's hurl), the beats'
# attacks GoldenConvergenceOvertake, GoldenConvergencePounce and GoldenConvergenceLash, and
# GoldenConvergenceDefeat (the feed dies). Phases 4-6 run their beat scripts as stage 1's do (_tick_beats).

const MAGNATE_SCRIPT: Script = preload("res://scripts/bosses/golden_convergence/golden_convergence_magnate.gd")

var magnate: GoldenConvergenceMagnate
var chase: GoldenConvergenceChase
var transition: GoldenConvergenceTransition
var defeat: GoldenConvergenceDefeat
var overtake: GoldenConvergenceOvertake
var pounce: GoldenConvergencePounce
var lash: GoldenConvergenceLash


func _build_stage_two() -> void:
	magnate = add_part(MAGNATE_SCRIPT, {"tuning": tuning}) as GoldenConvergenceMagnate
	chase = GoldenConvergenceChase.new(self, magnate)
	transition = GoldenConvergenceTransition.new(self, magnate, chase)
	defeat = GoldenConvergenceDefeat.new(self, magnate, chase)
	overtake = GoldenConvergenceOvertake.new(self)
	pounce = GoldenConvergencePounce.new(self)
	lash = GoldenConvergenceLash.new(self)
	for attack: GoldenConvergenceAttack in [overtake, pounce, lash]:
		register_attack(attack)
		attack.prewarm()


## A stage 2 phase begins: phase 4 with the transition (on a retry from the checkpoint too), 5 and 6 with his
## hurl clear after the stomp.
func _start_stage_two(index: int) -> void:
	_set_step(Step.FLOAT)
	if index == STAGE_2:
		transition.start()
	else:
		transition.start_hurl()
	log_event(&"stage_2", {"phase": index})


## Every physics frame of a stage 2 phase (its intro and its pattern): the court, the buttresses, the intro's
## moves, the beat script once the intro's done, the chase.
func _stage_two_tick(delta: float, intro: bool) -> void:
	step_time += delta
	_t += delta
	court.tick()
	_tick_buttresses(delta)
	transition.tick(delta)
	if not intro:
		for attack: GoldenConvergenceAttack in attacks.values():
			attack.tick(delta)
		if not transition.busy():
			_tick_beats(delta)
	chase.tick(delta)


## A stomp on his spine (GoldenConvergencePounce's stun): the phase ends right after (BossEncounter).
func _on_weak_point_hit(part: BossPart, _hazard: Hazard) -> void:
	if part != magnate:
		return
	pounce.on_stomp()
	sound(&"magnate_stomp", sound_point(magnate.back_point()))
	world.effects.burst(magnate.back_point(), GoldenConvergenceMagnateModel.PORT_RED, 26, 0.9)
	world.effects.shake(0.35, 0.35)


## The defeat plays out on the track (GoldenConvergenceDefeat): the results wait until the runner is past him.
func victory_over() -> bool:
	return defeat == null or defeat.step == GoldenConvergenceDefeat.Step.NONE or defeat.over()


## Stage 2's defeat plays its own riff once the runner is past him, or ends in silence (its tuning's
## victory_riff_on): never LevelRun's at the moment of the defeat.
func victory_riff() -> bool:
	return phase_index < STAGE_2

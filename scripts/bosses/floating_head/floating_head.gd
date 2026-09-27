class_name FloatingHead
extends BossEncounter
## The Floating Head, the Neon City's boss (GDD §10): a giant ship whose back is a giant cybernetic
## propaganda face watching over the city and shouting its propaganda.
## Built so far (task E1a): the ship and its face (FloatingHeadBody, FloatingHeadModel), the entrance,
## the bombing run with its searchlight (FloatingHeadBombing) and the reveal. The face-off (eye lasers,
## the cyborg drop, the marked towers: E1b), the pinned stomp windows and the damage (E1c), and the
## propaganda voice and the defeat (E1d) follow; until then the face-off is a placeholder where it
## hovers in front of the runner, watching. The fight stays out of the City's boss slot until E1d
## (debug builds play it with --boss=city_boss, BossDef.preview_scene).
##
## Each phase:
## 1. Its intro. The first phase's is the entrance: the ship roars in overhead from behind the runner
##    and pulls ahead to its bombing station, its stern (still a dark screen) looming over the top of
##    the screen. Later phases (after a stomp, task E1c: it shakes free, shrieks and rises) rise back
##    to the station, or straight in front of the runner if the phase has no run.
## 2. Its pattern: a bombing run if the phase has one (GDD §10: the first about 15-20 s, and once or
##    twice later a shorter one; FloatingHeadTuning), then it drops in front of the runner. The first
##    time is GDD §10's reveal: its face screen powers on as it settles. Then the face-off.
## The ship keeps its place relative to the runner (its stern `pose.z` metres ahead of them), so the
## pattern never depends on how long the fight has lasted (GDD §10: no escalation); the phase's pace
## speeds it up. Numbers: FloatingHeadTuning (data/bosses/city_boss_tuning.tres).

enum Step { ENTER, RISE, BOMBING, DESCEND, FACE_OFF }

const BODY_SCRIPT: Script = preload("res://scripts/bosses/floating_head/floating_head_body.gd")

var body: FloatingHeadBody
var tuning: FloatingHeadTuning
var bombing: FloatingHeadBombing
var step: Step = Step.ENTER
var step_time: float = 0.0
## The face screen has powered on (GDD §10's reveal happens once, when it first drops in front).
var revealed: bool = false
## Where the ship is, relative to the runner: x sideways, y its belly's height, z how far its stern
## (the face) is ahead of them (negative: behind).
var pose := Vector3.ZERO

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _seconds: float = 1.0
var _bob: float = 0.0
var _boot: float = 0.0
var _booting: bool = false


func _build_boss() -> void:
	tuning = def.tuning as FloatingHeadTuning
	if tuning == null:
		tuning = FloatingHeadTuning.new()
	body = add_part(BODY_SCRIPT, {"tuning": tuning}) as FloatingHeadBody
	bombing = FloatingHeadBombing.new()
	bombing.name = "Bombing"
	add_child(bombing)
	bombing.setup(self)
	if int(context.boss_resume.get("phase", 0)) > 0:
		# Resuming at a later phase: it has been revealed, and waits in front of the runner.
		revealed = true
		_boot = 1.0
		pose = face_pose()
	else:
		pose = enter_pose()
	_place()


## GDD §10's arena: the City's truck roofs with gaps and fences (BossDef.arena). The ship fills the
## street from wall to wall, so its walls carry no signs (DESIGN-TBD, docs/questions/e1.md).
func _plan_lap(lap: LevelLayout, _index: int, _arena: BossArena) -> void:
	lap.signs.clear()


# --- Where it flies -------------------------------------------------------------------------

## Where the entrance starts: behind the runner, above the street.
func enter_pose() -> Vector3:
	return Vector3(0.0, tuning.enter_height, -tuning.enter_behind)


## Its station during a bombing run.
func station_pose() -> Vector3:
	return Vector3(0.0, tuning.station_height, tuning.station_ahead)


## Where it hovers in front of the runner (the reveal and the face-off).
func face_pose() -> Vector3:
	return Vector3(0.0, tuning.face_height, tuning.face_ahead)


## The bombing run a phase starts its pattern with, in seconds (0: none). GDD §10: the first lasts
## about 15-20 s; once or twice later it rises for a shorter one.
func run_seconds(index: int) -> float:
	if index == 0:
		return tuning.first_run_seconds
	if index <= tuning.later_runs:
		return tuning.later_run_seconds
	return 0.0


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


# --- Phases -----------------------------------------------------------------------------------

func _on_phase_started(index: int) -> void:
	bombing.stop()
	if index == 0 and carried_time <= 0.0 and not revealed:
		# GDD §10: the ship flies in overhead.
		_move(Step.ENTER, enter_pose(), station_pose(), phase().intro_seconds)
		world.play_sfx(&"head_flyover")
		log_event(&"sound", {"name": &"head_flyover"})
		log_event(&"enter")
	else:
		# DESIGN-TBD (task E1c): after a stomp it shakes free, shrieks and rises. For now it rises back
		# to its station, or to the front of the runner if this phase has no run.
		_move(Step.RISE, pose, station_pose() if run_seconds(index) > 0.0 else face_pose(), phase().intro_seconds)
		log_event(&"rise")


func _intro_tick(delta: float) -> void:
	_bob += delta
	step_time += delta
	var k: float = clampf(step_time / maxf(_seconds, 0.05), 0.0, 1.0)
	if step == Step.ENTER:
		# Fast at first, easing into its station: it passes low over the runner and pulls ahead. The
		# camera shakes as it thunders overhead.
		var before: float = pose.z
		pose = _from.lerp(_to, 1.0 - pow(1.0 - k, 3.0))
		if before < -world.tuning.camera_distance and pose.z >= -world.tuning.camera_distance:
			world.effects.shake(0.35, 0.8)
	else:
		pose = _from.lerp(_to, smoothstep(0.0, 1.0, k))
	_place()


func _on_pattern_started(index: int) -> void:
	var seconds: float = run_seconds(index)
	if seconds > 0.0:
		pose = station_pose()
		_set_step(Step.BOMBING)
		bombing.start(seconds)
	else:
		_descend()


func _pattern_tick(delta: float) -> void:
	_bob += delta
	step_time += delta
	match step:
		Step.BOMBING:
			pose = station_pose()
			if bombing.finished():
				_descend()
		Step.DESCEND:
			var k: float = clampf(step_time / maxf(_seconds, 0.05), 0.0, 1.0)
			pose = _from.lerp(_to, smoothstep(0.0, 1.0, k))
			_update_boot(delta)
			if k >= 1.0 and not _booting:
				_set_step(Step.FACE_OFF)
				log_event(&"face_off")
		Step.FACE_OFF:
			# DESIGN-TBD (task E1b): the face-off (eye lasers, the cyborg drop, the marked towers).
			# For now it hovers in front of the runner, watching them.
			pose = face_pose()
			_update_boot(delta)
	bombing.tick(delta)
	_place()


func _on_defeated() -> void:
	bombing.clear()


func _defeated_tick(delta: float) -> void:
	# The last blasts burn out.
	bombing.tick(delta)


# --- Internals -------------------------------------------------------------------------------

## After a run it drops in front of the runner; the first time, its face powers on as it settles.
func _descend() -> void:
	_move(Step.DESCEND, pose, face_pose(), tuning.descend_seconds / pace())
	if not revealed:
		revealed = true
		_booting = true
		_boot = 0.0
		log_event(&"reveal")


## The face screen powering on over the last boot_seconds of the descent.
func _update_boot(delta: float) -> void:
	if not _booting:
		return
	var boot: float = minf(tuning.boot_seconds, _seconds)
	if step == Step.DESCEND and step_time < _seconds - boot:
		return
	if _boot <= 0.0:
		sound(&"head_reveal", body.screen_world())
	_boot = minf(_boot + delta / maxf(boot, 0.05), 1.0)
	if _boot >= 1.0:
		_booting = false


func _move(next: Step, from: Vector3, to: Vector3, seconds: float) -> void:
	_set_step(next)
	_from = from
	_to = to
	_seconds = maxf(seconds, 0.05)


func _set_step(next: Step) -> void:
	step = next
	step_time = 0.0


## Puts the ship where its pose says, bobbing gently, its nose dipping as it swoops in and lifting as
## it settles.
func _place() -> void:
	if body == null or not is_instance_valid(body):
		return
	var bob: float = 0.22 * sin(_bob * 1.3)
	var pitch: float = 0.012 * sin(_bob * 0.9)
	var roll: float = 0.015 * sin(_bob * 0.7 + 1.0)
	if step == Step.ENTER:
		pitch -= 0.06 * (1.0 - clampf(step_time / _seconds, 0.0, 1.0))
	elif step == Step.DESCEND or step == Step.RISE:
		pitch += 0.04 * sin(PI * clampf(step_time / _seconds, 0.0, 1.0))
	body.set_pose(Vector3(pose.x, pose.y + bob, TrackGeometry.world_z(player_distance() + pose.z)), pitch, roll)
	body.screen_power = _boot

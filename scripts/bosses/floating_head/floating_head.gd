class_name FloatingHead
extends BossEncounter
## The Floating Head, the Neon City's boss (GDD §10): a giant ship whose back is a giant cybernetic
## propaganda face watching over the city and shouting its propaganda.
## Built so far (tasks E1a, E1b): the ship and its face (FloatingHeadBody, FloatingHeadModel), the
## entrance, the bombing run with its searchlight (FloatingHeadBombing), the reveal, the face-off with
## its eye lasers and cyborg drop (FloatingHeadFaceOff), and the marked towers (FloatingHeadTower): one
## baited into the laser (or clipped on its own) topples onto the ship and pins it low across the
## trucks. The pinned stomp windows and the damage (E1c), and the propaganda voice and the defeat (E1d)
## follow; until then it shakes free before the runner reaches it (DESIGN-TBD). The fight stays out of
## the City's boss slot until E1d (debug builds play it with --boss=city_boss, BossDef.preview_scene).
##
## Each phase:
## 1. Its intro. The first phase's is the entrance: the ship roars in overhead from behind the runner
##    and pulls ahead to its bombing station, its stern (still a dark screen) looming over the top of
##    the screen. Later phases (after a stomp, task E1c: it shakes free, shrieks and rises) rise back
##    to the station, or straight in front of the runner if the phase has no run.
## 2. Its pattern: a bombing run if the phase has one (GDD §10: the first about 15-20 s, and once or
##    twice later a shorter one; FloatingHeadTuning), then it drops in front of the runner. The first
##    time is GDD §10's reveal: its face screen powers on as it settles. Then the face-off, until a
##    tower pins it (the pin: the tower topples forward onto it as it brakes, and slams it down between
##    the trucks, its weak points' sockets pin_top_height up; E1c's stomp windows go there).
## The ship keeps its place relative to the runner (its stern `pose.z` metres ahead of them) except
## while it's pinned, when it lies still on the track; so the pattern never depends on how long the
## fight has lasted (GDD §10: no escalation), and the phase's pace speeds it up. Numbers:
## FloatingHeadTuning (data/bosses/city_boss_tuning.tres).
##
## The marked towers (GDD §10: "marked, cracked towers stand ahead at the roadside") are planned with
## each lap (_plan_lap: every tower_spacing metres, sides in turn, the track kept clear of holes and
## fences around each) and brought into sight as the runner nears them.

enum Step { ENTER, RISE, BOMBING, DESCEND, FACE_OFF, PIN_FALL, PINNED, RELEASE }

const BODY_SCRIPT: Script = preload("res://scripts/bosses/floating_head/floating_head_body.gd")
## Towers come into sight this far ahead, and go this far behind.
const TOWER_SIGHT: float = 340.0
const TOWER_BEHIND: float = 60.0

var body: FloatingHeadBody
var tuning: FloatingHeadTuning
var bombing: FloatingHeadBombing
var faceoff: FloatingHeadFaceOff
var step: Step = Step.ENTER
var step_time: float = 0.0
## The face screen has powered on (GDD §10's reveal happens once, when it first drops in front).
var revealed: bool = false
## Where the ship is, relative to the runner: x sideways, y its belly's height, z how far its stern
## (the face) is ahead of them (negative: behind).
var pose := Vector3.ZERO
## The tower pinning it (or falling onto it), while it's pinned.
var pinned_tower: FloatingHeadTower
## Where the pinned ship lies: its stern's track distance.
var pin_stern: float = 0.0

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _seconds: float = 1.0
var _bob: float = 0.0
var _boot: float = 0.0
var _booting: bool = false
## The pin: {s0 (stern's track distance when the tower was clipped), v0 (its speed then), fall
## (seconds the tower takes), y0 (its belly's height then), side (the tower's)}.
var _pin: Dictionary = {}
var _roll: float = 0.0
var _impact: bool = false
## Towers planned for each distinct lap: {at (within the lap), side}.
var _tower_plan: Dictionary = {}
## Towers in sight, by key.
var _tower_nodes: Dictionary = {}


func _build_boss() -> void:
	tuning = def.tuning as FloatingHeadTuning
	if tuning == null:
		tuning = FloatingHeadTuning.new()
	body = add_part(BODY_SCRIPT, {"tuning": tuning}) as FloatingHeadBody
	bombing = FloatingHeadBombing.new()
	bombing.name = "Bombing"
	add_child(bombing)
	bombing.setup(self)
	faceoff = FloatingHeadFaceOff.new()
	add_child(faceoff)
	faceoff.setup(self)
	if int(context.boss_resume.get("phase", 0)) > 0:
		# Resuming at a later phase: it has been revealed, and waits in front of the runner.
		revealed = true
		_boot = 1.0
		pose = face_pose()
	else:
		pose = enter_pose()
	_place()


## GDD §10's arena: the City's truck roofs with gaps and fences (BossDef.arena), and its marked towers.
## The ship fills the street from wall to wall, so its walls carry no signs (DESIGN-TBD,
## docs/OPEN_QUESTIONS.md §D, item 84). Each lap's towers stand every tower_spacing metres from
## tower_first on, on alternate sides, with the track clear of holes and fences around each (the pin
## and the run up to it).
func _plan_lap(lap: LevelLayout, index: int, p_arena: BossArena) -> void:
	lap.signs.clear()
	var t: FloatingHeadTuning = (def.tuning as FloatingHeadTuning) if def != null else null
	if t == null:
		t = FloatingHeadTuning.new()
	var plan: Array[Dictionary] = []
	var at: float = t.tower_first
	var k: int = 0
	while at <= p_arena.lap_length - t.tower_clear_after:
		plan.append({"at": at, "side": -1 if (k + index) % 2 == 0 else 1})
		_clear_track(lap, at - t.tower_clear_before, at + t.tower_clear_after)
		at += t.tower_spacing
		k += 1
	_tower_plan[index] = plan


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


# --- Fairness helpers (the bombing run and the face-off) -----------------------------------------

## The nearest lane a runner in `pl` at `d0` can switch to out of an attack on `lanes`: not struck,
## at most max_escape_lanes away, and it and every lane on the way free of holes and fences from `d0`
## to `until` (and, with `avoid_enemies`, of any enemy's body: a cyborg it dropped). -1 if there is
## none.
func escape_lane(lanes: Array[int], pl: int, d0: float, until: float, avoid_enemies: bool = false) -> int:
	var n: int = lane_count()
	for dist: int in range(1, tuning.max_escape_lanes + 1):
		for s: int in [-1, 1]:
			var e: int = pl + s * dist
			if e < 0 or e >= n or lanes.has(e):
				continue
			var ok: bool = true
			for l: int in range(mini(pl, e), maxi(pl, e) + 1):
				if l != pl and (not floor_clear_lane(l, d0, until) or (avoid_enemies and enemy_in_lane(l, d0 - 2.0, until))):
					ok = false
					break
			if ok:
				return e
	return -1


## True if a living enemy (not the boss) stands in `lane` between two track distances.
func enemy_in_lane(lane: int, from: float, to: float) -> bool:
	var geo: TrackGeometry = world.geo
	for e: Enemy in world.director.active:
		if not is_instance_valid(e) or not e.alive or e is BossPart:
			continue
		var d: float = e.track_distance()
		var l: int = clampi(roundi(e.global_position.x / geo.lane_width + (geo.lane_count - 1) * 0.5), 0, geo.lane_count - 1)
		if l == lane and d >= from and d <= to:
			return true
	return false


## True if `lane`'s floor has no hole and no working fence between two track distances.
func floor_clear_lane(lane: int, from: float, to: float) -> bool:
	return arena == null or arena.floor_clear(from, to, lane)


## True if every lane's floor is clear between two track distances.
func floor_clear_all(from: float, to: float) -> bool:
	return arena == null or arena.floor_clear(from, to)


## True if a pickup waits in `lane` within `margin` of track distance `at`.
func pickup_near(lane: int, at: float, margin: float) -> bool:
	if world.pickups == null:
		return false
	for p: Pickup in world.pickups.active:
		if is_instance_valid(p) and p.lane == lane and absf(p.at - at) < margin:
			return true
	return false


# --- Towers ------------------------------------------------------------------------------------------

## The marked towers whose middles lie between two track distances, in track order: {at, side, key}.
func towers_between(from: float, to: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if arena == null or arena.laps.is_empty() or _tower_plan.is_empty():
		return out
	for k: int in range(arena.lap_at(maxf(from, 0.0)), arena.lap_at(maxf(to, 0.0)) + 1):
		var plan: Array = _tower_plan.get(k % arena.laps.size(), [])
		for i: int in plan.size():
			var t: Dictionary = plan[i]
			var d: float = k * arena.lap_length + float(t["at"])
			if d >= from and d <= to:
				out.append({"at": d, "side": int(t["side"]), "key": "%d:%d" % [k, i]})
	return out


## The tower standing for `tower` (a towers_between entry), built if it isn't in sight yet; null once it
## has fallen and gone.
func tower_node(tower: Dictionary) -> FloatingHeadTower:
	var key: String = tower["key"]
	if _tower_nodes.has(key):
		var held: Variant = (_tower_nodes[key] as Dictionary)["node"]
		return held as FloatingHeadTower if is_instance_valid(held) else null
	var node := FloatingHeadTower.new()
	add_child(node)
	node.setup(world, tuning, float(tower["at"]), int(tower["side"]))
	_tower_nodes[key] = {"node": node, "at": float(tower["at"])}
	return node


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_stream_towers()


## Towers come into sight ahead and go once passed. A fallen one frees itself once it has crumbled; its
## entry stays until it's far behind, so it never stands up again.
func _stream_towers() -> void:
	if arena == null or world == null or world.player == null or tuning == null:
		return
	var d: float = player_distance()
	for t: Dictionary in towers_between(d - TOWER_BEHIND, d + TOWER_SIGHT):
		if not _tower_nodes.has(t["key"]):
			tower_node(t)
	for key: String in _tower_nodes.keys():
		var entry: Dictionary = _tower_nodes[key]
		var held: Variant = entry["node"]
		var behind: bool = float(entry["at"]) < d - TOWER_BEHIND
		if not is_instance_valid(held):
			if behind:
				_tower_nodes.erase(key)
			continue
		var node := held as FloatingHeadTower
		if behind and node != pinned_tower and node.state == FloatingHeadTower.State.STANDING:
			node.queue_free()
			_tower_nodes.erase(key)


## Takes holes and fences out of every lane between two track distances.
static func _clear_track(lap: LevelLayout, from: float, to: float) -> void:
	for i: int in range(lap.gaps.size() - 1, -1, -1):
		if float(lap.gaps[i]["start"]) <= to and float(lap.gaps[i]["end"]) >= from:
			lap.gaps.remove_at(i)
	for i: int in range(lap.fences.size() - 1, -1, -1):
		var f: float = float(lap.fences[i]["at"])
		if f >= from and f <= to:
			lap.fences.remove_at(i)


# --- Phases -----------------------------------------------------------------------------------

func _on_phase_started(index: int) -> void:
	bombing.stop()
	faceoff.stop()
	_end_pin(true)
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
				faceoff.start(phase_index)
		Step.FACE_OFF:
			_update_boot(delta)
		Step.PIN_FALL, Step.PINNED, Step.RELEASE:
			_pin_tick(delta)
	bombing.tick(delta)
	faceoff.tick(delta)
	_place()


func _on_defeated() -> void:
	bombing.clear()
	faceoff.clear()
	_end_pin(true)


func _defeated_tick(delta: float) -> void:
	# The last blasts and burns go out.
	bombing.tick(delta)
	faceoff.tick(delta)


# --- The pin ----------------------------------------------------------------------------------------

## A clipped tower topples onto the ship (FloatingHeadFaceOff calls this as the laser clips it): it
## brakes to a stop under the falling tower, which lands on its crown behind its weak points and slams
## it down between the trucks.
func begin_pin(tower: FloatingHeadTower) -> void:
	var fall: float = tuning.tower_fall_seconds / pace()
	var s0: float = player_distance() + pose.z
	var v0: float = world.player.speed
	pinned_tower = tower
	pin_stern = s0 + v0 * fall * 0.5
	_pin = {"s0": s0, "v0": v0, "fall": fall, "y0": pose.y, "side": tower.side}
	_impact = false
	_set_step(Step.PIN_FALL)
	tower.fall_onto(pin_rest_point(pose.y, 0.0), fall)
	log_event(&"pin_start", {"stern": pin_stern, "side": tower.side})


## The pinned ship's belly height, rolled by `roll`: its weak points' sockets' highest top at
## pin_top_height.
func pinned_belly(roll: float = 0.0) -> float:
	var top: float = -INF
	for p: Vector3 in body.shape.weak_points:
		top = maxf(top, p.x * sin(roll) + p.y * cos(roll))
	return tuning.pin_top_height - top


## Its roll once pinned: pressed down on the tower's side.
func pinned_roll(side: int) -> float:
	return -side * deg_to_rad(tuning.pin_roll_degrees)


## Where the tower rests on its crown (world), with its belly at `belly` and rolled by `roll`, lying at
## pin_stern.
func pin_rest_point(belly: float, roll: float) -> Vector3:
	var s: FloatingHeadModel.Shape = body.shape
	var side: int = int(_pin.get("side", 1))
	var fx: float = side * 0.12
	var z: float = -tuning.pin_rest_offset
	var local := Vector3(fx * s.width, FloatingHeadModel.crown_height(s, fx, z), z)
	var xform := Transform3D(Basis(Vector3(0, 0, 1), roll), Vector3(0.0, belly, TrackGeometry.world_z(pin_stern)))
	return xform * local


func _pin_tick(delta: float) -> void:
	var fall: float = float(_pin.get("fall", 1.0))
	var side: int = int(_pin.get("side", 1))
	var sink: float = tuning.pin_sink_seconds / pace()
	match step:
		Step.PIN_FALL:
			# Braking to a stop under the tower, then slammed down as it lands.
			var t: float = minf(step_time, fall)
			var stern: float = float(_pin["s0"]) + float(_pin["v0"]) * (t - t * t / (2.0 * fall))
			pose.z = stern - player_distance()
			var k: float = clampf((step_time - fall) / sink, 0.0, 1.0)
			var eased: float = k * k
			pose.y = lerpf(float(_pin["y0"]), pinned_belly(pinned_roll(side)), eased)
			_roll = lerpf(0.0, pinned_roll(side), eased)
			if step_time >= fall:
				if not _impact:
					_impact = true
					var at: Vector3 = pin_rest_point(pose.y, _roll)
					sound(&"tower_crash", at)
					world.effects.shake(0.7, 0.9)
					world.effects.burst(at, FloatingHeadTower.CONCRETE_LIGHT, 60, 2.0)
					world.effects.burst(at + Vector3(0.0, -2.0, 0.0), FloatingHeadFaceOff.SPARK, 40, 1.4)
					log_event(&"pinned", {"stern": pin_stern, "side": side})
				if pinned_tower != null and is_instance_valid(pinned_tower):
					pinned_tower.rest_on(pin_rest_point(pose.y, _roll))
			body.glitch = 0.4 * clampf(step_time / fall, 0.0, 1.0)
			if k >= 1.0:
				_set_step(Step.PINNED)
		Step.PINNED:
			pose.z = pin_stern - player_distance()
			pose.y = pinned_belly(pinned_roll(side))
			_roll = pinned_roll(side)
			body.glitch = 0.4
			# DESIGN-TBD (task E1c: the stomp windows): for now it shakes free before the runner gets to it.
			if pose.z <= tuning.pin_release_gap:
				_release()
		Step.RELEASE:
			var k: float = clampf(step_time / maxf(_seconds, 0.05), 0.0, 1.0)
			var e: float = smoothstep(0.0, 1.0, k)
			pose = _from.lerp(_to, e)
			_roll = lerpf(pinned_roll(side), 0.0, e)
			body.glitch = 0.4 * (1.0 - e)
			if k >= 1.0:
				_roll = 0.0
				body.glitch = 0.0
				_pin = {}
				_set_step(Step.FACE_OFF)
				log_event(&"released")
				faceoff.resume()


## It shakes free (E1b's placeholder, DESIGN-TBD): the tower breaks up and drops away, and it rises back
## in front of the runner.
func _release() -> void:
	if pinned_tower != null and is_instance_valid(pinned_tower):
		pinned_tower.crumble()
	pinned_tower = null
	sound(&"head_flyover", body.screen_world())
	world.effects.shake(0.4, 0.6)
	log_event(&"release", {"gap": pose.z})
	_move(Step.RELEASE, pose, face_pose(), tuning.release_seconds / pace())


## Ends a pin at once (a phase change, the win): the tower drops away and it rights itself.
func _end_pin(quiet: bool) -> void:
	if pinned_tower != null and is_instance_valid(pinned_tower):
		pinned_tower.crumble()
	pinned_tower = null
	_pin = {}
	_roll = 0.0
	if body != null and is_instance_valid(body):
		body.glitch = 0.0
	if not quiet:
		log_event(&"released")


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
## it settles; pinned, it lies still, rolled onto the tower's side.
func _place() -> void:
	if body == null or not is_instance_valid(body):
		return
	var pinned: bool = step == Step.PIN_FALL or step == Step.PINNED or step == Step.RELEASE
	var calm: float = 0.0 if step == Step.PINNED or (step == Step.PIN_FALL and _impact) else 1.0
	var bob: float = 0.22 * sin(_bob * 1.3) * calm
	var pitch: float = 0.012 * sin(_bob * 0.9) * calm
	var roll: float = 0.015 * sin(_bob * 0.7 + 1.0) * calm
	if step == Step.ENTER:
		pitch -= 0.06 * (1.0 - clampf(step_time / _seconds, 0.0, 1.0))
	elif step == Step.DESCEND or step == Step.RISE:
		pitch += 0.04 * sin(PI * clampf(step_time / _seconds, 0.0, 1.0))
	if pinned:
		roll += _roll
	body.set_pose(Vector3(pose.x, pose.y + bob, TrackGeometry.world_z(player_distance() + pose.z)), pitch, roll)
	body.screen_power = _boot

class_name FloatingHead
extends BossEncounter
## The Floating Head, the Neon City's boss (GDD §10): a giant ship whose back is a giant cybernetic
## propaganda face watching over the city and shouting its propaganda.
## Built so far (tasks E1a-E1c): the ship and its face (FloatingHeadBody, FloatingHeadModel), the
## entrance, the bombing run with its searchlight (FloatingHeadBombing), the reveal, the face-off with
## its eye lasers and cyborg drop (FloatingHeadFaceOff), the marked towers (FloatingHeadTower): one
## baited into the laser (or clipped on its own) topples onto the ship and pins it low across the
## trucks; and the stomp windows while it's pinned, one way onto its head per phase. The propaganda
## voice and the defeat (E1d) follow; for now a won fight ends in a burst. The fight stays out of the
## City's boss slot until E1d (debug builds play it with --boss=city_boss, BossDef.preview_scene).
##
## Each phase:
## 1. Its intro. The first phase's is the entrance: the ship roars in overhead from behind the runner
##    and pulls ahead to its bombing station, its stern (still a dark screen) looming over the top of
##    the screen. After a stomp (GDD §10: "it shakes free, shrieks and rises") it lurches free of the
##    tower (SHAKE) and rises back to its station, or straight in front of the runner if the phase has
##    no run.
## 2. Its pattern: a bombing run if the phase has one (GDD §10: the first about 15-20 s, and once or
##    twice later a shorter one; FloatingHeadTuning), then it drops in front of the runner. The first
##    time is GDD §10's reveal: its face screen powers on as it settles. Then the face-off, until a
##    tower pins it: the tower topples forward onto it as it brakes, slams it down between the trucks
##    (its weak points' sockets pin_top_height up) and breaks, and a stomp window opens.
## The ship keeps its place relative to the runner (its stern `pose.z` metres ahead of them) except
## while it's pinned, when it lies still on the track; so the pattern never depends on how long the
## fight has lasted (GDD §10: no escalation), and the phase's pace speeds it up. Numbers:
## FloatingHeadTuning (data/bosses/city_boss_tuning.tres).
##
## The stomp windows (GDD §10: "while it's pinned, the player stomps one [weak point]. Each phase uses
## a different Zone 1 skill to get on top"). Pinned, its weak points' covers swing open and the red
## domes come out, pulsing (the hover truck's weak-point language), with a sound; its crown becomes a
## floor (its deck) and its hull stops being deadly (the pinned ship is the floor of the way up). The
## phase's way up (FloatingHeadTuning.stomp_route), all of it physical:
## - "ramp" (run up the fallen tower like a ramp): as the tower crashes onto the ship, a broken slab of
##   it slams down in the weak point's lane nearest the tower's wall (FloatingHeadRamp), leaning on the
##   ship's face; run up it and off its end onto the weak point;
## - "wall" (wall-jump onto it): enter a wall in time and jump off it, inward, onto a weak point (in
##   the outer lanes at 3 lanes; one more move inward at 5 and 6);
## - "ceiling" (ride a ship's underside via an anti-grav pad and drop onto it when the hull ends): as
##   the tower falls, pads light up in every lane before the ship, and a ceiling section lowers in over
##   them once the ship is past its end (never into the ship's space); ride it, pick a weak point's
##   lane, and drop onto it when it ends.
## A stomp (FloatingHeadBody's stomp boxes, the framework's rules) takes the phase's share (a third of
## its health); weapons chip away up to the boss's cap. A missed window: if the runner is still down on
## the trucks within window_release_gap of its face, or has run past its weak points, it shakes free
## and rises back in front of them, and the face-off goes on: towers again, never harder (GDD §10: no
## time limit, no escalation).
##
## The marked towers (GDD §10: "marked, cracked towers stand ahead at the roadside") are planned with
## each lap (_plan_lap: every tower_spacing metres, sides in turn, the track kept clear of holes and
## fences around each) and brought into sight as the runner nears them. A tower whose pin would land on
## a pickup or a dropped cyborg goes by as scenery (pin_zone_blocker); pickups due while a tower is being
## lined up or the ship is pinned wait until it's back in the air (_on_armor_pickup_due).

enum Step { ENTER, RISE, BOMBING, DESCEND, FACE_OFF, PIN_FALL, PINNED, SHAKE, RELEASE }

const BODY_SCRIPT: Script = preload("res://scripts/bosses/floating_head/floating_head_body.gd")
## Towers come into sight this far ahead, and go this far behind.
const TOWER_SIGHT: float = 340.0
const TOWER_BEHIND: float = 60.0
## The weak points' covers take this long to swing open or shut.
const COVER_SECONDS: float = 0.35
## The third window's ceiling lowers in from this far above its height, once the ship's face is this
## far past where it will end.
const CEILING_DROP: float = 9.0
const CEILING_CLEAR: float = 1.0
## Its shudder while it shakes free (metres, at its start).
const SHUDDER: float = 0.2

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
## Where the pinned ship lies: its stern's track distance; and the pinning tower's side (-1 left, +1
## right).
var pin_stern: float = 0.0
var pin_side: int = 1
## The pin's way onto its head (FloatingHeadTuning.stomp_route): &"ramp", &"wall" or &"ceiling".
var route: StringName = &""
## A stomp window is open: its weak points out, its deck a floor.
var window_open: bool = false
## The first way up's ramp and its lane (-1: none).
var ramp: FloatingHeadRamp
var ramp_lane: int = -1
## The third way up's pads (their track distance, every lane) and ceiling (track distances).
var pad_at: float = 0.0
var ceiling_span := Vector2.ZERO

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
## Shaking free: where from (pose and roll), and whether the phase ended (a stomp, or weapons while it
## was pinned: then it rises for the next phase; else, a missed window, it goes back to the face-off).
var _shake_from := Vector3.ZERO
var _shake_roll: float = 0.0
var _shake_next_phase: bool = false
## The third window's pads and ceiling section (props), the ceiling lowering in: seconds since it
## appeared.
var _pads: Array[Node3D] = []
var _ceiling: Node3D
var _ceiling_t: float = 0.0
## Armor pickups due while a pin is under way, to offer once it's over.
var _armor_waiting: int = 0
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
## tower_first on, on alternate sides, with the track clear of holes and fences around each (the pin,
## the ways onto its head and the run up to it).
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


## True if a ceiling reaches into [from, to]: the arena's, or the third stomp window's own. Bombs never
## lock under one and the face-off waits until the runner is past it.
func ceiling_between(from: float, to: float) -> bool:
	if arena != null and arena.ceiling_between(from, to):
		return true
	return _ceiling != null and is_instance_valid(_ceiling) and ceiling_span.x <= to and ceiling_span.y >= from


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


## Where a pin at the marked tower at track distance `tower_at` would lie (track distances), from the
## start of its way up (the ramp's foot, or the pads and their ceiling) to the ship's bow: the face
## passes the tower as the drag clips it, then brakes to a stop under the falling tower.
func pin_zone(tower_at: float) -> Vector2:
	var stern: float = tower_at + world.player.speed * tuning.tower_fall_seconds / pace() * 0.5
	var lead: float = maxf(tuning.ramp_length, tuning.pad_before_face + _hull_lead_in())
	return Vector2(stern - lead - 2.0, stern + body.shape.length + 2.0)


## What lies where a pin at the marked tower at `tower_at` would go (&"" if nothing does): &"pickup" (a
## pickup there, or one still waiting for a spot, which might land there) or &"enemy" (a cyborg it
## dropped).
func pin_zone_blocker(tower_at: float) -> StringName:
	var zone: Vector2 = pin_zone(tower_at)
	if world.pickups != null:
		if world.pickups.waiting() > 0:
			return &"pickup"
		for p: Pickup in world.pickups.active:
			if is_instance_valid(p) and p.at >= zone.x and p.at <= zone.y:
				return &"pickup"
	for l: int in lane_count():
		if enemy_in_lane(l, zone.x, zone.y):
			return &"enemy"
	return &""


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_stream_towers()
	if body != null and is_instance_valid(body):
		body.weak_open = move_toward(body.weak_open, 1.0 if window_open else 0.0, delta / COVER_SECONDS)
	if _armor_waiting > 0 and not pin_busy() and state != State.DEFEATED:
		_armor_waiting -= 1
		offer_pickup(&"armor")


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
	var pinned: bool = step == Step.PINNED or step == Step.SHAKE
	if index == 0 and carried_time <= 0.0 and not revealed:
		# GDD §10: the ship flies in overhead.
		_move(Step.ENTER, enter_pose(), station_pose(), phase().intro_seconds)
		world.play_sfx(&"head_flyover")
		log_event(&"sound", {"name": &"head_flyover"})
		log_event(&"enter")
	elif pinned:
		# GDD §10: after a stomp it shakes free, shrieks and rises: the lurch free of the tower, then the
		# rise back to its station (_shake_tick). (Weapons that end the phase while it's pinned free it the
		# same way.)
		_start_shake(true)
	else:
		# A phase that ended while it flew (weapons), or a checkpoint's: it rises back to its station, or
		# to the front of the runner if this phase has no run.
		_end_pin(true)
		_move(Step.RISE, pose, _rise_pose(index), phase().intro_seconds)
		log_event(&"rise")


func _intro_tick(delta: float) -> void:
	_bob += delta
	step_time += delta
	var k: float = clampf(step_time / maxf(_seconds, 0.05), 0.0, 1.0)
	if step == Step.SHAKE:
		_shake_tick()
	elif step == Step.ENTER:
		# Fast at first, easing into its station: it passes low over the runner and pulls ahead. The
		# camera shakes as it thunders overhead.
		var before: float = pose.z
		pose = _from.lerp(_to, 1.0 - pow(1.0 - k, 3.0))
		if before < -world.tuning.camera_distance and pose.z >= -world.tuning.camera_distance:
			world.effects.shake(0.35, 0.8)
	else:
		pose = _from.lerp(_to, smoothstep(0.0, 1.0, k))
	bombing.tick(delta)
	faceoff.tick(delta)
	_place()


func _on_pattern_started(index: int) -> void:
	if step == Step.SHAKE:
		# The intro was over before it had shaken free (a short intro): it's free now.
		_finish_shake()
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
		Step.SHAKE:
			_shake_tick()
		Step.RISE:
			var k: float = clampf(step_time / maxf(_seconds, 0.05), 0.0, 1.0)
			pose = _from.lerp(_to, smoothstep(0.0, 1.0, k))
	_update_ceiling(delta)
	bombing.tick(delta)
	faceoff.tick(delta)
	_place()


## A stomp landed on a weak point (its damage follows at once, and ends the phase): GDD §10, it
## shrieks.
func _on_weak_point_hit(_part: BossPart, hazard: Hazard) -> void:
	window_open = false
	sound(&"head_shriek", body.screen_world())
	world.effects.burst(hazard.global_position, FloatingHeadModel.WEAK, 40, 1.2)
	world.effects.burst(hazard.global_position + Vector3(0.0, 0.4, 0.0), FloatingHeadTower.CONCRETE_LIGHT, 20, 0.8)
	world.effects.shake(0.5, 0.5)
	body.glitch = 1.0
	log_event(&"stomp", {"route": route, "lane": _lane_at(hazard.global_position.x)})


func _on_defeated() -> void:
	bombing.clear()
	faceoff.clear()
	_end_pin(true)


func _defeated_tick(delta: float) -> void:
	# The last blasts and burns go out.
	bombing.tick(delta)
	faceoff.tick(delta)


## The standard armor rule's pickups (GDD §10): on the floor ahead, as usual, except while a marked
## tower is being lined up or the ship is pinned: then it waits until the ship is back in the air, so it
## never lands where the pin and its way up go.
func _on_armor_pickup_due(reason: StringName) -> void:
	if pin_busy():
		_armor_waiting += 1
		log_event(&"armor_waits", {"reason": reason})
		return
	offer_pickup(&"armor")


## True while a pin is coming or under way: a marked tower's drag lined up, the tower falling, the ship
## pinned or shaking free.
func pin_busy() -> bool:
	if step == Step.PIN_FALL or step == Step.PINNED or step == Step.SHAKE:
		return true
	return faceoff != null and faceoff.running and faceoff.attack.get("kind", &"") == &"tower"


# --- The pin ----------------------------------------------------------------------------------------

## A clipped tower topples onto the ship (FloatingHeadFaceOff calls this as the laser clips it): it
## brakes to a stop under the falling tower, which lands on its crown behind its weak points and slams
## it down between the trucks. The phase's way onto its head starts now: the third window's pads light
## up at once (its ceiling follows once the ship is past it).
func begin_pin(tower: FloatingHeadTower) -> void:
	var fall: float = tuning.tower_fall_seconds / pace()
	var s0: float = player_distance() + pose.z
	var v0: float = world.player.speed
	pinned_tower = tower
	pin_stern = s0 + v0 * fall * 0.5
	pin_side = tower.side
	route = tuning.stomp_route(phase_index)
	_pin = {"s0": s0, "v0": v0, "fall": fall, "y0": pose.y, "side": tower.side}
	_impact = false
	ramp_lane = -1
	_set_step(Step.PIN_FALL)
	tower.fall_onto(pin_rest_point(pose.y, 0.0), fall)
	log_event(&"pin_start", {"stern": pin_stern, "side": tower.side, "route": route})
	if route == &"ceiling":
		_light_pads()


## The pinned ship's belly height, rolled by `roll`: its weak points' sockets' highest top at
## pin_top_height.
func pinned_belly(roll: float = 0.0) -> float:
	var xform: Transform3D = FloatingHeadModel.ship_transform(body.shape, 0.0, roll)
	var top: float = -INF
	for p: Vector3 in body.shape.weak_points:
		top = maxf(top, (xform * p).y)
	return tuning.pin_top_height - top


## Its roll once pinned: pressed down on the tower's side.
func pinned_roll(side: int) -> float:
	return -side * deg_to_rad(tuning.pin_roll_degrees)


## The pinned ship's space to world (where it will lie once it has sunk: at pin_stern, rolled toward
## the tower).
func pinned_transform() -> Transform3D:
	var roll: float = pinned_roll(pin_side)
	return Transform3D(Basis.IDENTITY, Vector3(pose.x, pinned_belly(roll), TrackGeometry.world_z(pin_stern))) \
		* FloatingHeadModel.ship_transform(body.shape, 0.0, roll)


## The point on the pinned ship's crown (world) over world x `x`, at `z` along the ship (ship space:
## 0 at its face, toward -z).
func pinned_crown(x: float, z: float) -> Vector3:
	var s: FloatingHeadModel.Shape = body.shape
	var xform: Transform3D = pinned_transform()
	var lx: float = x - xform.origin.x
	for i: int in 4:
		var p: Vector3 = xform * Vector3(lx, FloatingHeadModel.crown_height(s, lx / s.width, z), z)
		lx += x - p.x
	return xform * Vector3(lx, FloatingHeadModel.crown_height(s, lx / s.width, z), z)


## Where the tower rests on its crown (world), with its belly at `belly` and rolled by `roll`, lying at
## pin_stern.
func pin_rest_point(belly: float, roll: float) -> Vector3:
	var s: FloatingHeadModel.Shape = body.shape
	var fx: float = pin_side * 0.12
	var z: float = -tuning.pin_rest_offset
	var local := Vector3(fx * s.width, FloatingHeadModel.crown_height(s, fx, z), z)
	return Vector3(pose.x, belly, TrackGeometry.world_z(pin_stern)) + FloatingHeadModel.ship_transform(s, 0.0, roll) * local


## The lanes its weak points sit over, left to right.
func weak_point_lanes() -> Array[int]:
	var out: Array[int] = []
	for p: Vector3 in body.shape.weak_points:
		out.append(_lane_at(p.x))
	return out


## The first window's ramp lane for a tower on `side`: the weak point's lane nearest the tower's wall.
func ramp_lane_for(side: int) -> int:
	var lanes: Array[int] = weak_point_lanes()
	return lanes[0] if side < 0 else lanes[lanes.size() - 1]


## The track distance past which a runner has passed its weak points (the window closes).
func pass_line() -> float:
	return pin_stern - FloatingHeadModel.WEAK_Z + tuning.stomp_depth * 0.5 + tuning.window_pass_margin


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
					_on_impact(side)
				if pinned_tower != null and is_instance_valid(pinned_tower):
					pinned_tower.rest_on(pin_rest_point(pose.y, _roll))
			body.glitch = 0.4 * clampf(step_time / fall, 0.0, 1.0)
			if k >= 1.0:
				_set_step(Step.PINNED)
				_open_window()
		Step.PINNED:
			pose.z = pin_stern - player_distance()
			pose.y = pinned_belly(pinned_roll(side))
			_roll = pinned_roll(side)
			body.glitch = 0.4
			_check_window()
		Step.RELEASE:
			# Back in front of the runner after a missed window, and the face-off goes on.
			var k: float = clampf(step_time / maxf(_seconds, 0.05), 0.0, 1.0)
			pose = _from.lerp(_to, smoothstep(0.0, 1.0, k))
			if k >= 1.0:
				_pin = {}
				_set_step(Step.FACE_OFF)
				log_event(&"released")
				faceoff.resume()


## The tower lands on the ship: the crash, and it breaks behind the weak points (the part in front of
## them drops away, or makes the first window's ramp). Anything left under the ship is crushed.
func _on_impact(side: int) -> void:
	var at: Vector3 = pin_rest_point(pose.y, _roll)
	sound(&"tower_crash", at)
	world.effects.shake(0.7, 0.9)
	world.effects.burst(at, FloatingHeadTower.CONCRETE_LIGHT, 60, 2.0)
	world.effects.burst(at + Vector3(0.0, -2.0, 0.0), FloatingHeadFaceOff.SPARK, 40, 1.4)
	log_event(&"pinned", {"stern": pin_stern, "side": side, "route": route})
	if pinned_tower != null and is_instance_valid(pinned_tower):
		var along: float = -pinned_tower.axis_world().z
		if along > 0.1:
			var cut: float = pin_stern - FloatingHeadModel.WEAK_Z + tuning.stomp_depth * 0.5 + tuning.tower_break_after
			pinned_tower.break_at((cut - pinned_tower.at) / along)
	if route == &"ramp":
		_slam_ramp(side)
	_crush(pin_stern - 2.0, pin_stern + body.shape.length)


## The first way up: the tower's broken slab slams down in the weak point's lane nearest its wall, its
## foot ramp_length before the ship's face and its top end resting on the crown there, ramp_lift above
## it.
func _slam_ramp(side: int) -> void:
	ramp_lane = ramp_lane_for(side)
	var x: float = world.geo.lane_x(ramp_lane)
	var top: float = pinned_crown(x, 0.0).y + tuning.ramp_lift
	var color := Color(0.3, 1.0, 0.35)
	var skin_color: Variant = world.skin.get(&"ramp_color") if world.skin != null else null
	if skin_color is Color:
		color = skin_color
	ramp = FloatingHeadRamp.new()
	add_child(ramp)
	ramp.setup(world, ramp_lane, pin_stern - tuning.ramp_length, pin_stern, top, tuning.ramp_overhang,
		tuning.ramp_slam_seconds / pace(), color)
	_crush(pin_stern - tuning.ramp_length - 1.0, pin_stern, ramp_lane)
	sound(&"ramp_slam", ramp.end_world())
	log_event(&"ramp", {"lane": ramp_lane, "foot": ramp.foot, "top": top})


## The third way up: anti-grav pads light up in every lane pad_before_face before where the ship will
## lie; the ceiling over them follows once the ship is past its end (_update_ceiling).
func _light_pads() -> void:
	# A ceiling from an earlier window, if any is left, stays a prop until the runner is past it.
	_ceiling = null
	_pads.clear()
	pad_at = pin_stern - tuning.pad_before_face
	for l: int in lane_count():
		_pads.append(props.pad(l, pad_at))
	ceiling_span = Vector2(pad_at - _hull_lead_in(), pin_stern - tuning.ceiling_end_before_face)
	sound(&"pads_light", Vector3(0.0, 0.5, TrackGeometry.world_z(pad_at)))
	log_event(&"pads", {"at": pad_at, "ceiling": ceiling_span})


## The third window's ceiling lowers in once the ship's face is past where it ends (a ceiling never
## reaches into the ship's space), from CEILING_DROP above its height over ceiling_lower_seconds.
func _update_ceiling(delta: float) -> void:
	if ceiling_span == Vector2.ZERO:
		return
	if _ceiling == null:
		if route != &"ceiling" or (step != Step.PIN_FALL and step != Step.PINNED):
			return
		if player_distance() + pose.z < ceiling_span.y + CEILING_CLEAR:
			return
		_ceiling = props.ceiling(ceiling_span.x, ceiling_span.y)
		_ceiling.position.y = CEILING_DROP
		_ceiling_t = 0.0
		sound(&"ceiling_lower", Vector3(0.0, world.tuning.ceiling_height, TrackGeometry.world_z(ceiling_span.y)))
		log_event(&"ceiling", {"start": ceiling_span.x, "end": ceiling_span.y})
		return
	if not is_instance_valid(_ceiling):
		# The props freed it once the runner was past it.
		_ceiling = null
		ceiling_span = Vector2.ZERO
		return
	_ceiling_t += delta
	var k: float = clampf(_ceiling_t / maxf(tuning.ceiling_lower_seconds / pace(), 0.05), 0.0, 1.0)
	_ceiling.position.y = CEILING_DROP * (1.0 - smoothstep(0.0, 1.0, k))


## Opens the stomp window: the covers swing open and the weak points come out (with its sound), its
## crown's deck is a floor, and its hull stops being deadly (the pinned ship is the way's floor).
func _open_window() -> void:
	window_open = true
	set_weak_points_enabled(true)
	body.set_top_solid(true)
	body.set_hull_solid(false)
	sound(&"head_weak_open", body.weak_point_world(body.shape.weak_points.size() / 2))
	log_event(&"window_open", {"route": route, "stern": pin_stern, "lane": ramp_lane})


## A missed window (GDD §10: "if the runner passes without a stomp, it shakes free"): the runner is
## still down on the trucks close to its face, or has run past its weak points.
func _check_window() -> void:
	if not window_open:
		return
	var p: Player = world.player
	var gap: float = pin_stern - player_distance()
	if p.surface == Player.Surface.FLOOR and p.h < tuning.window_floor_height and gap < tuning.window_release_gap:
		_miss(&"floor", gap)
	elif player_distance() > pass_line():
		_miss(&"passed", gap)


func _miss(why: StringName, gap: float) -> void:
	window_open = false
	set_weak_points_enabled(false)
	log_event(&"window_missed", {"why": why, "gap": gap})
	_start_shake(false)


## It shakes free (after a stomp or a missed window): the tower and the ramp break up and drop away, and
## it lurches shake_ahead further ahead of the runner and shake_lift up (_shake_tick). `next_phase`: the
## phase ended (then it rises to the next phase's station; else back to the face-off).
func _start_shake(next_phase: bool) -> void:
	window_open = false
	_shake_next_phase = next_phase
	_shake_from = pose
	_shake_roll = _roll
	if pinned_tower != null and is_instance_valid(pinned_tower):
		pinned_tower.crumble()
	pinned_tower = null
	if ramp != null and is_instance_valid(ramp):
		ramp.crumble()
	ramp = null
	sound(&"head_shake_free", body.screen_world())
	world.effects.shake(0.45, 0.7)
	world.effects.burst(body.global_position + Vector3(0.0, 1.0, -4.0), FloatingHeadTower.CONCRETE, 40, 1.8)
	_set_step(Step.SHAKE)
	log_event(&"shake_free", {"next_phase": next_phase, "gap": pose.z})


## The lurch: its face pulls away from the runner (never toward them), shuddering, as it rights itself.
## Its deck stays under a runner still on it until its face has passed them. Then it rises: back to its
## station for the next phase after a stomp, to the front of the runner after a missed window.
func _shake_tick() -> void:
	var k: float = clampf(step_time / maxf(tuning.shake_seconds / pace(), 0.05), 0.0, 1.0)
	var e: float = smoothstep(0.0, 1.0, k)
	pose = Vector3(_shake_from.x, _shake_from.y + tuning.shake_lift * e, _shake_from.z + tuning.shake_ahead * e)
	_roll = lerpf(_shake_roll, 0.0, e)
	body.glitch = lerpf(0.8, 0.0, e)
	body.set_top_solid(pose.z < 0.0)
	if k >= 1.0:
		_finish_shake()


## Free: its deck off, and it rises.
func _finish_shake() -> void:
	body.set_top_solid(false)
	body.glitch = 0.0
	_roll = 0.0
	_pin = {}
	if _shake_next_phase:
		var left: float = maxf(phase().intro_seconds - state_time, 0.3) if state == State.INTRO else 0.3
		_move(Step.RISE, pose, _rise_pose(phase_index), left)
		log_event(&"rise")
	else:
		_move(Step.RELEASE, pose, face_pose(), tuning.release_seconds / pace())


## Ends a pin at once (a phase that ended while the tower was still falling, the win): the tower and the
## ramp drop away, the third window's pads and ceiling go (the window is gone), and it rights itself.
func _end_pin(quiet: bool) -> void:
	if pinned_tower != null and is_instance_valid(pinned_tower):
		pinned_tower.crumble()
	pinned_tower = null
	if ramp != null and is_instance_valid(ramp):
		ramp.crumble()
	ramp = null
	if ceiling_span != Vector2.ZERO:
		for pad: Node3D in _pads:
			props.remove(pad)
		if _ceiling != null:
			props.remove(_ceiling)
		_ceiling = null
		ceiling_span = Vector2.ZERO
	_pads.clear()
	window_open = false
	_pin = {}
	_roll = 0.0
	if body != null and is_instance_valid(body):
		body.glitch = 0.0
		body.set_top_solid(false)
	if not quiet:
		log_event(&"released")


## Enemies left under the ship's footprint (or the ramp's, in `lane`) as it crashes down are crushed.
## Rare: a marked tower whose pin would land on one goes by as scenery (pin_zone_blocker).
func _crush(from: float, to: float, lane: int = -1) -> void:
	for e: Enemy in world.director.active.duplicate():
		if not is_instance_valid(e) or not e.alive or e is BossPart:
			continue
		var d: float = e.track_distance()
		if d < from or d > to or (lane >= 0 and _lane_at(e.global_position.x) != lane):
			continue
		world.effects.burst(e.global_position + Vector3(0.0, 0.6, 0.0), FloatingHeadTower.CONCRETE_LIGHT, 16, 0.8)
		log_event(&"crushed", {"at": d})
		e.retire()


# --- Internals -------------------------------------------------------------------------------

## Where it rises to for phase `index`: its bombing station, or the front of the runner if the phase has
## no run.
func _rise_pose(index: int) -> Vector3:
	return station_pose() if run_seconds(index) > 0.0 else face_pose()


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


## The lane whose middle is nearest world x `x`.
func _lane_at(x: float) -> int:
	var geo: TrackGeometry = world.geo
	return clampi(roundi(x / geo.lane_width + (geo.lane_count - 1) * 0.5), 0, geo.lane_count - 1)


## The arena's ceiling lead-in: how far before its pads a ceiling section starts.
func _hull_lead_in() -> float:
	return arena.config.hull_lead_in if arena != null and arena.config != null else 3.0


func _move(next: Step, from: Vector3, to: Vector3, seconds: float) -> void:
	_set_step(next)
	_from = from
	_to = to
	_seconds = maxf(seconds, 0.05)


func _set_step(next: Step) -> void:
	step = next
	step_time = 0.0


## Puts the ship where its pose says, bobbing gently, its nose dipping as it swoops in and lifting as
## it settles; pinned, it lies still, rolled onto the tower's side; shaking free, it shudders. Its hull
## is solid except while it's pinned or shaking free (the runner may be on it then).
func _place() -> void:
	if body == null or not is_instance_valid(body):
		return
	var calm: float = 0.0 if step == Step.PINNED or step == Step.SHAKE or (step == Step.PIN_FALL and _impact) else 1.0
	var bob: float = 0.22 * sin(_bob * 1.3) * calm
	var pitch: float = 0.012 * sin(_bob * 0.9) * calm
	var roll: float = 0.015 * sin(_bob * 0.7 + 1.0) * calm + _roll
	if step == Step.ENTER:
		pitch -= 0.06 * (1.0 - clampf(step_time / _seconds, 0.0, 1.0))
	elif step == Step.DESCEND or step == Step.RISE:
		pitch += 0.04 * sin(PI * clampf(step_time / _seconds, 0.0, 1.0))
	var shudder := Vector3.ZERO
	if step == Step.SHAKE:
		var fade: float = 1.0 - clampf(step_time / maxf(tuning.shake_seconds / pace(), 0.05), 0.0, 1.0)
		shudder = Vector3(sin(_bob * 53.0), 0.6 * cos(_bob * 47.0), 0.0) * SHUDDER * fade
	body.set_pose(Vector3(pose.x, pose.y + bob, TrackGeometry.world_z(player_distance() + pose.z)) + shudder, pitch, roll)
	body.screen_power = _boot
	body.set_hull_solid(step != Step.PINNED and step != Step.SHAKE)

class_name RunCamera
extends Camera3D
## Chase camera for a run: behind and above the player, following sideways and upward in part,
## dropping below the ceiling to look up at a player running on it, and never rising into a ceiling
## (ceiling_limit). Shakes on request (RunEffects), scaled by the accessibility setting. Most numbers
## come from MovementTuning's Camera group; the speed-driven field-of-view kick and the lane-switch
## lean are SpeedFxTuning's (GDD §3, the owner's playtest, September 30, 2026: "the camera widens at
## speed... a subtle lean into lane switches").
##
## The field-of-view kick follows Player.speed above SpeedFxTuning.fov_reference_speed, so it widens
## both as the run's base speed rises zone by zone (G1) and on top of that for a ramp, a speed pad or
## the dash (Player already folds every boost into `speed`): eased in fast, out slower, so a boost's
## end reads as a settle rather than a snap. The lean banks gently into a lane switch
## (Player._switch_dir, read the way tests/helpers/run_sim.gd's trace does).
##
## Hit-stop (RunEffects.freeze): while `world.effects.freeze_left` counts down, `_process` skips
## `_update` altogether, so the camera holds its exact transform and fov (Z included: `_update`
## always snaps position.z straight to the player's, unsmoothed, so running it even with delta 0
## would still follow) while the player, the enemies and the generator behind the frozen view keep
## moving at their own, real delta. See RunEffects' class doc for why this never touches gameplay.
##
## The climbing view (RunWorld.camera_climbs, off by default: a boss's climb, GDD §10, the Beach's, whose
## runner climbs ceilings and roofs 20-30 m above the street): the usual framing is kept to the floor the
## runner is on or came from (Player.floor_y) instead of the street, so they stay in frame at any height; on
## a ceiling, the usual view from below is kept to that ceiling's own height (Player.ceiling_y); and the
## camera keeps camera_floor_clearance above any roof under or around it (floor_limit), rising in good time
## for one ahead (camera_climb_lead), so it never sits inside the higher roof a ceiling rider will drop onto.
## Every target is eased as ever, so a landing on a higher roof or a ride up to a ceiling never snaps the
## view; ceiling_limit holds as always, and wins over the roof's clearance where both can't be kept.
##
## The teleport's sweep (task U2; the owner, October 24, 2026: "when the player touches the teleporter, the camera should
## zoom in to where the teleporter's output is ... the camera catches up, showing the user what happened through its
## movement"): the runner is moved at once (Player._teleport), but the camera keeps the view it had, a lag behind where it
## follows the runner (`_sweep_from`: across and along the track), and that lag is eased away over
## TeleporterTuning.sweep_seconds of real time, fastest at first (`sweep_remaining`), with a punch of
## sweep_fov_punch degrees of field of view that eases back with it. It is the camera's alone: the lag rides on top of the
## usual follow (the runner's own position, hitboxes, speed and control are untouched), and the ceiling and doodad checks
## run where the camera really is. A second teleport mid-sweep starts from wherever the camera is.

## A ceiling within this far to either side of the camera, this far ahead of it or this far behind it
## holds it down too (ceiling_limit): one beside it (a narrow ceiling) as well as one over it, one just
## ahead before the camera gets under it, and one just passed for a moment after its far end.
const CEILING_SIDE: float = 1.0
const CEILING_AHEAD: float = 2.5
const CEILING_BEHIND: float = 3.0
## ceiling_limit looks for a ceiling from this far below the camera to this far above it.
const CEILING_BELOW: float = 2.0
const CEILING_SEARCH: float = 14.0
## floor_limit heeds a roof whose top is up to this far above the camera (one it would otherwise sit
## inside), as well as one below it within camera_floor_clearance, but never one the camera is beneath (a
## raised slab it passes under).
const FLOOR_REACH: float = 6.0
## floor_limit looks for a roof ahead this far apart along the track (metres).
const FLOOR_STEP: float = 2.5
## floor_limit's samples along the track that it always takes (behind, level with and just ahead of the
## camera: the limit right at it), and across (to either side and level with it).
const FLOOR_NEAR: Array[float] = [-CEILING_BEHIND, 0.0, CEILING_AHEAD]
const FLOOR_SIDES: Array[float] = [-CEILING_SIDE, 0.0, CEILING_SIDE]
## doodad_floor looks for a zone doodad this far to either side of the camera, and from this far behind it to this
## far ahead (metres): it starts rising over one before it gets there, and stays above it until it's past.
const DOODAD_SIDE: float = 1.2
const DOODAD_BEHIND: float = 1.0
const DOODAD_AHEAD: float = 6.0

## doodad_floor's query, made once.
static var _doodad_query: PhysicsShapeQueryParameters3D

var world: RunWorld
## SpeedFxTuning for the fov kick and the lane lean: world.effects.tuning, set by RunEffects.setup
## when RunWorld.build runs (always before follow() is called on the built world).
var speed_fx: SpeedFxTuning
var _focus: Vector3 = Vector3.ZERO
var _look_y: float = 1.0
var _fov: float = 70.0
var _lean_deg: float = 0.0
## TeleporterTuning for the teleport's sweep (the shared data/tuning/teleporters.tres; tests and tools may set their own).
var teleport_tuning: TeleporterTuning
## The sweep's start: how far the camera was from where it follows the runner at the touch, Vector2(across, along the
## track: z), and the real seconds since (INF: no sweep under way).
var _sweep_from := Vector2.ZERO
var _sweep_t: float = INF
var _shake: float = 0.0
var _shake_time: float = 0.0
var _shake_left: float = 0.0
var _noise_t: float = 0.0
## The climbing view's ray queries for floor_limits, kept so a frame allocates none.
var _floor_down := PhysicsRayQueryParameters3D.new()
var _floor_up := PhysicsRayQueryParameters3D.new()


func follow(p_world: RunWorld) -> void:
	world = p_world
	far = 600.0
	speed_fx = world.effects.tuning if world.effects.tuning != null else SpeedFxTuning.new()
	world.effects.shake_requested.connect(_on_shake)
	world.teleported.connect(_on_teleported)
	if teleport_tuning == null:
		teleport_tuning = TeleporterTuning.load_default()
	snap()


## A teleport (task Q4; RunWorld.teleported; the sweep is task U2): the runner is already at the output pad, and the
## camera stays where it was. What it follows of the runner is moved at once, across to their new lane (`_focus.x`; along
## the track it follows them in the same step), and the distance it is left behind (the input pad's view, across and
## along) becomes the sweep's start (`_sweep_from`), which `_update` eases away over TeleporterTuning.sweep_seconds. The
## camera is where it was this frame, so a second teleport mid-sweep starts from where the sweep had got to. The lean into
## a lane switch is let go; the height, the look and the field of view carry on (the runner arrives running on the floor).
## With sweep_seconds 0 it's the clean cut it was in task Q4 (the flash over it: TeleportFlash). DESIGN-TBD
## (docs/questions/u2-teleport-camera.md 1).
func _on_teleported(_from: float, _to: float, _entry: Dictionary, _output: Dictionary) -> void:
	if world == null or world.player == null:
		return
	var t: MovementTuning = world.tuning
	var here := Vector2(_focus.x + sweep_offset().x, position.z)
	_focus.x = world.player.position.x * t.camera_follow_x
	_lean_deg = 0.0
	if teleport_tuning != null and teleport_tuning.sweep_seconds > 0.0:
		_sweep_from = here - Vector2(_focus.x, world.player.position.z + t.camera_distance)
		_sweep_t = 0.0
	else:
		_sweep_t = INF
	_update(0.0, false)


## The share of the sweep's way still to go `t` seconds after the touch: 1 at the touch, 0 from sweep_seconds on, easing
## out (`(1 - t / sweep_seconds) ^ sweep_ease_power`: most of the way is covered at once, the rest settles). 0 with no sweep.
static func sweep_remaining(tt: TeleporterTuning, t: float) -> float:
	if tt.sweep_seconds <= 0.0 or t >= tt.sweep_seconds:
		return 0.0
	return pow(clampf(1.0 - maxf(t, 0.0) / tt.sweep_seconds, 0.0, 1.0), tt.sweep_ease_power)


## True while a teleport's sweep is under way.
func sweeping() -> bool:
	return not is_inf(_sweep_t)


## How far the sweep still holds the camera from where it follows the runner: Vector2(across, along the track), zero with
## no sweep. Positive along is back toward the input pad.
func sweep_offset() -> Vector2:
	if is_inf(_sweep_t) or teleport_tuning == null:
		return Vector2.ZERO
	return _sweep_from * sweep_remaining(teleport_tuning, _sweep_t)


## The sweep's punch on the field of view, degrees: sweep_fov_punch eased back with the sweep. None with Reduced flashing
## (Settings.flashing_reduced) or Screen shake off (RunEffects.shake_scale 0): no kick in the view for a player who asked
## for none.
func sweep_fov() -> float:
	if is_inf(_sweep_t) or teleport_tuning == null or Settings.flashing_reduced or world.effects.shake_scale <= 0.0:
		return 0.0
	return teleport_tuning.sweep_fov_punch * sweep_remaining(teleport_tuning, _sweep_t)


## Lets the sweep run `delta` seconds of game time on: real seconds (slow time, Engine.time_scale, doesn't stretch it).
func _advance_sweep(delta: float) -> void:
	if is_inf(_sweep_t):
		return
	_sweep_t += delta / maxf(Engine.time_scale, 0.001)
	if teleport_tuning == null or _sweep_t >= teleport_tuning.sweep_seconds:
		_sweep_t = INF


## Jumps straight to the resting position (level start, restart).
func snap() -> void:
	var t: MovementTuning = world.tuning
	_focus = Vector3(world.player.position.x * t.camera_follow_x, t.camera_height, 0.0)
	if world.camera_climbs:
		_focus.y += world.player.floor_y
	_look_y = 1.0
	_fov = t.camera_fov
	_lean_deg = 0.0
	_sweep_t = INF
	_update(1.0, true)


func _process(delta: float) -> void:
	if world == null or world.player == null:
		return
	if world.effects.freeze_left > 0.0:
		return  # Hit-stop: hold the camera's transform and fov exactly as they are.
	_advance_sweep(delta)
	_update(delta, false)


func _update(delta: float, instant: bool) -> void:
	var t: MovementTuning = world.tuning
	var p: Vector3 = world.player.position
	var climbing: bool = world.camera_climbs
	var cam_y: float
	var look_y: float
	if climbing:
		var aim: Vector2 = _climb_aim(t)
		cam_y = aim.x
		look_y = aim.y
	else:
		cam_y = t.camera_height + p.y * t.camera_follow_y
		look_y = p.y * t.camera_follow_y + 1.0
		if world.player.surface == Player.Surface.CEILING:
			# Drop below the ceiling and look up at the player hanging from it.
			cam_y = t.camera_ceiling_height
			look_y = t.ceiling_height - 1.2
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	# The teleport's sweep (zero with none) rides on top of the follow; the checks below run where the camera really is.
	var sweep: Vector2 = sweep_offset()
	var here := Vector3(_focus.x + sweep.x, _focus.y, p.z + t.camera_distance + sweep.y)
	var limit: float = ceiling_limit(space, here, t)
	# Never into a zone doodad below: the camera riding below a ceiling is lower than a doodad's top, and a treasure
	# stash's stand under one (task I4). It rises toward one ahead, and stays above one it's over. With none near,
	# `low` is (-INF, -INF) and leaves the framing below as it is.
	var low: Vector2 = doodad_floor(space, here, t)
	# Climbing: above any roof under or around the camera, risen to in good time for one ahead.
	var floor_now: float = -INF
	if climbing:
		var floors: Vector2 = floor_limits(space, here, t, maxf(world.player.speed, 0.0) * t.camera_climb_lead,
			_floor_down, _floor_up)
		cam_y = maxf(cam_y, floors.y)
		floor_now = floors.x
	var k: float = 1.0 if instant else 1.0 - exp(-t.camera_smoothing * delta)
	_focus.x = lerpf(_focus.x, p.x * t.camera_follow_x, k)
	_focus.y = maxf(minf(lerpf(_focus.y, maxf(minf(cam_y, limit), maxf(low.x, low.y)), k), limit), low.x)
	if climbing:
		_focus.y = minf(maxf(_focus.y, floor_now), limit)
	_look_y = lerpf(_look_y, look_y, k)
	fov = _fov_kick(t.camera_fov, world.player.speed, delta, instant) + sweep_fov()
	var lean_rad: float = deg_to_rad(_lane_lean(delta, instant))
	var up := Vector3(sin(lean_rad), cos(lean_rad), 0.0)
	var offset := Vector3.ZERO
	if _shake_left > 0.0:
		_shake_left -= delta
		_noise_t += delta * 40.0
		var fade: float = clampf(_shake_left / maxf(_shake_time, 0.001), 0.0, 1.0)
		offset = Vector3(sin(_noise_t * 1.3), cos(_noise_t * 1.7), 0.0) * _shake * fade
	position = Vector3(_focus.x + sweep.x, _focus.y, here.z) + offset
	look_at(Vector3(_focus.x + sweep.x, _look_y, p.z - t.camera_look_ahead + sweep.y) + offset * 0.5, up)


## The climbing view's aim (RunWorld.camera_climbs): Vector2(camera height, look height). The usual
## framing, kept to the floor the runner is on or came from (Player.floor_y: a roof, or the floor they took
## the pad from while they ride a ceiling or drop off it) instead of the street; on a ceiling, the usual view
## from below kept to that ceiling's own height (Player.ceiling_y). At the street's level and under a ceiling
## at ceiling_height, the usual view.
func _climb_aim(t: MovementTuning) -> Vector2:
	var player: Player = world.player
	if player.surface == Player.Surface.CEILING:
		return Vector2(player.ceiling_y - (t.ceiling_height - t.camera_ceiling_height), player.ceiling_y - 1.2)
	var base: float = player.floor_y
	var follow: float = (player.position.y - base) * t.camera_follow_y
	return Vector2(base + t.camera_height + follow, base + follow + 1.0)


## GDD §3: "the camera widens at speed". `speed` already folds in the zone's base (G1), a ramp, a
## speed pad and the dash (Player.speed), so the kick grows both as the base rises zone by zone and
## on top of that for a boost; SpeedFxTuning.fov_reference_speed is where it starts from `base_fov`.
## Eased in with fov_attack_rate, out with the slower fov_release_rate.
func _fov_kick(base_fov: float, speed: float, delta: float, instant: bool) -> float:
	var target: float = base_fov + clampf((speed - speed_fx.fov_reference_speed) * speed_fx.fov_kick_per_speed,
		0.0, speed_fx.fov_kick_max)
	var rate: float = speed_fx.fov_attack_rate if target > _fov else speed_fx.fov_release_rate
	var kf: float = 1.0 if instant else 1.0 - exp(-rate * delta)
	_fov = lerpf(_fov, target, kf)
	return _fov


## GDD §3: "a subtle lean into lane switches". Banks toward Player._switch_dir (-1, 0, 1: the same
## field the avatar's own sideways lean and RunSim's trace read), eased both ways at lane_lean_rate.
func _lane_lean(delta: float, instant: bool) -> float:
	var dir: int = int(world.player.call(&"_switch_dir"))
	var target: float = float(dir) * speed_fx.lane_lean_max_deg
	var kl: float = 1.0 if instant else 1.0 - exp(-speed_fx.lane_lean_rate * delta)
	_lean_deg = lerpf(_lean_deg, target, kl)
	return _lean_deg


## The highest the camera may be at `pos` (world space): camera_ceiling_clearance below the underside
## of any ceiling over it, within CEILING_SIDE to either side, CEILING_AHEAD ahead or CEILING_BEHIND
## behind (a ceiling's collision box on the hull layer: the track's, a narrow one's, a boss's); INF
## with none. So the camera never rises into a ceiling. It would, after a drop off a ceiling's far end:
## the player falls from the ceiling's height and the camera follows them up, and it climbed into the
## ceiling before it passed the end, where the end band's glow and the ceiling's insides filled the
## screen (a one-frame orange wash and a glare, task B3). It stays that low until CEILING_BEHIND past
## the end, and the skins keep every glow past a far end above the underside (MeshKit.ceiling_end).
## The review tools that copy the chase camera (tools/showcase) use it too.
static func ceiling_limit(space: PhysicsDirectSpaceState3D, pos: Vector3, t: MovementTuning) -> float:
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collision_mask = TrackBuilder.LAYER_HULL
	var limit: float = INF
	for ahead: float in [-CEILING_BEHIND, 0.0, CEILING_AHEAD]:
		for side: float in [-CEILING_SIDE, 0.0, CEILING_SIDE]:
			ray.from = Vector3(pos.x + side, pos.y - CEILING_BELOW, pos.z - ahead)
			ray.to = ray.from + Vector3(0.0, CEILING_BELOW + CEILING_SEARCH, 0.0)
			var hit: Dictionary = space.intersect_ray(ray)
			if not hit.is_empty():
				limit = minf(limit, (hit["position"] as Vector3).y - t.camera_ceiling_clearance)
	return limit


## The lowest the climbing camera may be at `pos` (world space): camera_floor_clearance above the top of any
## roof (anything on the floor layer: a boss's raised floor, the street) within CEILING_SIDE to either side
## and from CEILING_BEHIND behind to `ahead` ahead (at least CEILING_AHEAD), whose top is no more than
## FLOOR_REACH above it and which it isn't beneath (a raised slab it would pass under); -INF with none. So
## the camera never sits inside the higher roof a ceiling rider will drop onto, which stands below their
## ceiling and above the floor they came from (GDD §10, the Beach's climb). RunCamera keeps to it only when
## it climbs (RunWorld.camera_climbs).
static func floor_limit(space: PhysicsDirectSpaceState3D, pos: Vector3, t: MovementTuning,
		ahead: float = CEILING_AHEAD) -> float:
	return floor_limits(space, pos, t, ahead, PhysicsRayQueryParameters3D.new(), PhysicsRayQueryParameters3D.new()).y


## floor_limit's two answers from one pass over its samples, as the climbing camera takes them every frame:
## Vector2(the limit right at the camera, floor_limit(space, pos, t); the limit with the roofs up to `ahead`
## ahead as well, floor_limit(space, pos, t, ahead)). It casts its rays with `down` and `up` (the camera keeps
## its own, so a frame allocates none).
static func floor_limits(space: PhysicsDirectSpaceState3D, pos: Vector3, t: MovementTuning, ahead: float,
		down: PhysicsRayQueryParameters3D, up: PhysicsRayQueryParameters3D) -> Vector2:
	down.collision_mask = TrackBuilder.LAYER_FLOOR
	up.collision_mask = TrackBuilder.LAYER_FLOOR
	var near: float = -INF
	for along: float in FLOOR_NEAR:
		near = maxf(near, _floor_sample(space, pos, t, along, down, up))
	var far: float = near
	var along_far: float = CEILING_AHEAD + FLOOR_STEP
	while along_far < ahead:
		far = maxf(far, _floor_sample(space, pos, t, along_far, down, up))
		along_far += FLOOR_STEP
	if ahead > CEILING_AHEAD:
		far = maxf(far, _floor_sample(space, pos, t, ahead, down, up))
	return Vector2(near, far)


## The limit one of floor_limit's samples sets, `along` the track from the camera at `pos` (the most of its
## samples across, FLOOR_SIDES): camera_floor_clearance above the top of a roof there, no more than
## FLOOR_REACH above the camera and not one it's beneath; -INF with none.
static func _floor_sample(space: PhysicsDirectSpaceState3D, pos: Vector3, t: MovementTuning, along: float,
		down: PhysicsRayQueryParameters3D, up: PhysicsRayQueryParameters3D) -> float:
	var limit: float = -INF
	var z: float = pos.z - along
	for side: float in FLOOR_SIDES:
		var x: float = pos.x + side
		down.from = Vector3(x, pos.y + FLOOR_REACH, z)
		down.to = Vector3(x, pos.y - t.camera_floor_clearance, z)
		var hit: Dictionary = space.intersect_ray(down)
		if hit.is_empty():
			continue
		var top: float = (hit["position"] as Vector3).y
		if top > pos.y:
			# A slab overhead: from below it, a ray up meets its underside (from inside it, none).
			up.from = Vector3(x, pos.y, z)
			up.to = Vector3(x, top, z)
			var over: Dictionary = space.intersect_ray(up)
			if not over.is_empty() and over["collider"] == hit["collider"]:
				continue
		limit = maxf(limit, top + t.camera_floor_clearance)
	return limit


## The lowest the camera at `pos` (world space) may be over the zone doodads near it (TrackBuilder.LAYER_DOODAD; a
## smashed one has none): Vector2(over one it's level with, over one ahead), each camera_doodad_clearance above the
## highest such doodad's top, or -INF with none. Within DOODAD_SIDE to either side, from DOODAD_BEHIND behind it (it's
## level with a doodad until it's that far past its back) to DOODAD_AHEAD ahead. A camera above both never notices;
## only the low camera that looks up at a ceiling rider (camera_ceiling_height) ever meets one (task I4: a treasure
## stash's doodads stand under its ceiling, where the zone doodads never do).
static func doodad_floor(space: PhysicsDirectSpaceState3D, pos: Vector3, t: MovementTuning) -> Vector2:
	if _doodad_query == null:
		_doodad_query = PhysicsShapeQueryParameters3D.new()
		_doodad_query.collide_with_areas = true
		_doodad_query.collide_with_bodies = false
		_doodad_query.collision_mask = TrackBuilder.LAYER_DOODAD
		var box := BoxShape3D.new()
		box.size = Vector3(DOODAD_SIDE * 2.0, 6.0, DOODAD_BEHIND + DOODAD_AHEAD)
		_doodad_query.shape = box
	# Ahead is toward -z (TrackGeometry.world_z).
	_doodad_query.transform = Transform3D(Basis.IDENTITY, Vector3(pos.x, 3.0, pos.z - (DOODAD_AHEAD - DOODAD_BEHIND) * 0.5))
	var out := Vector2(-INF, -INF)
	for hit: Dictionary in space.intersect_shape(_doodad_query, 8):
		var body := hit["collider"] as DashBreakable
		if body == null or body.is_smashed():
			continue
		var top: float = body.global_position.y + body.size.y * 0.5 + t.camera_doodad_clearance
		# Its face toward the runner (and the camera behind them) is at +z, its far end at -z.
		var face: float = body.global_position.z + body.size.z * 0.5
		var far: float = body.global_position.z - body.size.z * 0.5
		if pos.z <= face + DOODAD_BEHIND and pos.z >= far - DOODAD_BEHIND:
			out.x = maxf(out.x, top)
		else:
			out.y = maxf(out.y, top)
	return out


func _on_shake(strength: float, duration: float) -> void:
	if strength >= _shake * clampf(_shake_left / maxf(_shake_time, 0.001), 0.0, 1.0):
		_shake = strength
		_shake_time = duration
		_shake_left = duration

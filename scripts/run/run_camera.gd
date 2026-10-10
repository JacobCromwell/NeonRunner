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

var world: RunWorld
## SpeedFxTuning for the fov kick and the lane lean: world.effects.tuning, set by RunEffects.setup
## when RunWorld.build runs (always before follow() is called on the built world).
var speed_fx: SpeedFxTuning
var _focus: Vector3 = Vector3.ZERO
var _look_y: float = 1.0
var _fov: float = 70.0
var _lean_deg: float = 0.0
var _shake: float = 0.0
var _shake_time: float = 0.0
var _shake_left: float = 0.0
var _noise_t: float = 0.0


func follow(p_world: RunWorld) -> void:
	world = p_world
	far = 600.0
	speed_fx = world.effects.tuning if world.effects.tuning != null else SpeedFxTuning.new()
	world.effects.shake_requested.connect(_on_shake)
	snap()


## Jumps straight to the resting position (level start, restart).
func snap() -> void:
	var t: MovementTuning = world.tuning
	_focus = Vector3(world.player.position.x * t.camera_follow_x, t.camera_height, 0.0)
	if world.camera_climbs:
		_focus.y += world.player.floor_y
	_look_y = 1.0
	_fov = t.camera_fov
	_lean_deg = 0.0
	_update(1.0, true)


func _process(delta: float) -> void:
	if world == null or world.player == null:
		return
	if world.effects.freeze_left > 0.0:
		return  # Hit-stop: hold the camera's transform and fov exactly as they are.
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
	var here := Vector3(_focus.x, _focus.y, p.z + t.camera_distance)
	var limit: float = ceiling_limit(space, here, t)
	# Climbing: above any roof under or around the camera, risen to in good time for one ahead.
	var floor_now: float = -INF
	if climbing:
		cam_y = maxf(cam_y, floor_limit(space, here, t, maxf(world.player.speed, 0.0) * t.camera_climb_lead))
		floor_now = floor_limit(space, here, t)
	var k: float = 1.0 if instant else 1.0 - exp(-t.camera_smoothing * delta)
	_focus.x = lerpf(_focus.x, p.x * t.camera_follow_x, k)
	_focus.y = minf(lerpf(_focus.y, minf(cam_y, limit), k), limit)
	if climbing:
		_focus.y = minf(maxf(_focus.y, floor_now), limit)
	_look_y = lerpf(_look_y, look_y, k)
	fov = _fov_kick(t.camera_fov, world.player.speed, delta, instant)
	var lean_rad: float = deg_to_rad(_lane_lean(delta, instant))
	var up := Vector3(sin(lean_rad), cos(lean_rad), 0.0)
	var offset := Vector3.ZERO
	if _shake_left > 0.0:
		_shake_left -= delta
		_noise_t += delta * 40.0
		var fade: float = clampf(_shake_left / maxf(_shake_time, 0.001), 0.0, 1.0)
		offset = Vector3(sin(_noise_t * 1.3), cos(_noise_t * 1.7), 0.0) * _shake * fade
	position = Vector3(_focus.x, _focus.y, p.z + t.camera_distance) + offset
	look_at(Vector3(_focus.x, _look_y, p.z - t.camera_look_ahead) + offset * 0.5, up)


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
	var down := PhysicsRayQueryParameters3D.new()
	down.collision_mask = TrackBuilder.LAYER_FLOOR
	var up := PhysicsRayQueryParameters3D.new()
	up.collision_mask = TrackBuilder.LAYER_FLOOR
	var alongs: Array[float] = [-CEILING_BEHIND, 0.0, CEILING_AHEAD]
	var next: float = CEILING_AHEAD + FLOOR_STEP
	while next < ahead:
		alongs.append(next)
		next += FLOOR_STEP
	if ahead > CEILING_AHEAD:
		alongs.append(ahead)
	var limit: float = -INF
	for along: float in alongs:
		for side: float in [-CEILING_SIDE, 0.0, CEILING_SIDE]:
			var x: float = pos.x + side
			var z: float = pos.z - along
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


func _on_shake(strength: float, duration: float) -> void:
	if strength >= _shake * clampf(_shake_left / maxf(_shake_time, 0.001), 0.0, 1.0):
		_shake = strength
		_shake_time = duration
		_shake_left = duration

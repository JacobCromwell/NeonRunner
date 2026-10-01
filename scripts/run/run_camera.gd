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

## A ceiling within this far to either side of the camera, this far ahead of it or this far behind it
## holds it down too (ceiling_limit): one beside it (a narrow ceiling) as well as one over it, one just
## ahead before the camera gets under it, and one just passed for a moment after its far end.
const CEILING_SIDE: float = 1.0
const CEILING_AHEAD: float = 2.5
const CEILING_BEHIND: float = 3.0
## ceiling_limit looks for a ceiling from this far below the camera to this far above it.
const CEILING_BELOW: float = 2.0
const CEILING_SEARCH: float = 14.0

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
	var cam_y: float = t.camera_height + p.y * t.camera_follow_y
	var look_y: float = p.y * t.camera_follow_y + 1.0
	if world.player.surface == Player.Surface.CEILING:
		# Drop below the ceiling and look up at the player hanging from it.
		cam_y = t.camera_ceiling_height
		look_y = t.ceiling_height - 1.2
	var limit: float = ceiling_limit(get_world_3d().direct_space_state,
		Vector3(_focus.x, _focus.y, p.z + t.camera_distance), t)
	var k: float = 1.0 if instant else 1.0 - exp(-t.camera_smoothing * delta)
	_focus.x = lerpf(_focus.x, p.x * t.camera_follow_x, k)
	_focus.y = minf(lerpf(_focus.y, minf(cam_y, limit), k), limit)
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


func _on_shake(strength: float, duration: float) -> void:
	if strength >= _shake * clampf(_shake_left / maxf(_shake_time, 0.001), 0.0, 1.0):
		_shake = strength
		_shake_time = duration
		_shake_left = duration

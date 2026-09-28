class_name RunCamera
extends Camera3D
## Chase camera for a run: behind and above the player, following sideways and upward in part,
## dropping below the ceiling to look up at a player running on it, and never rising into a ceiling
## (ceiling_limit). Shakes on request (RunEffects), scaled by the accessibility setting. All numbers
## come from MovementTuning's Camera group.

## A ceiling within this far to either side of the camera, or this far ahead of it, holds it down too
## (ceiling_limit): one beside it (a narrow ceiling) as well as one over it, and one just ahead before
## the camera gets under it.
const CEILING_SIDE: float = 1.0
const CEILING_AHEAD: float = 2.5
## ceiling_limit looks for a ceiling from this far below the camera to this far above it.
const CEILING_BELOW: float = 2.0
const CEILING_SEARCH: float = 14.0

var world: RunWorld
var _focus: Vector3 = Vector3.ZERO
var _look_y: float = 1.0
var _shake: float = 0.0
var _shake_time: float = 0.0
var _shake_left: float = 0.0
var _noise_t: float = 0.0


func follow(p_world: RunWorld) -> void:
	world = p_world
	far = 600.0
	world.effects.shake_requested.connect(_on_shake)
	snap()


## Jumps straight to the resting position (level start, restart).
func snap() -> void:
	var t: MovementTuning = world.tuning
	_focus = Vector3(world.player.position.x * t.camera_follow_x, t.camera_height, 0.0)
	_look_y = 1.0
	_update(1.0, true)


func _process(delta: float) -> void:
	if world != null and world.player != null:
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
	fov = t.camera_fov
	var offset := Vector3.ZERO
	if _shake_left > 0.0:
		_shake_left -= delta
		_noise_t += delta * 40.0
		var fade: float = clampf(_shake_left / maxf(_shake_time, 0.001), 0.0, 1.0)
		offset = Vector3(sin(_noise_t * 1.3), cos(_noise_t * 1.7), 0.0) * _shake * fade
	position = Vector3(_focus.x, _focus.y, p.z + t.camera_distance) + offset
	look_at(Vector3(_focus.x, _look_y, p.z - t.camera_look_ahead) + offset * 0.5)


## The highest the camera may be at `pos` (world space): camera_ceiling_clearance below the underside
## of any ceiling over it, within CEILING_SIDE to either side or CEILING_AHEAD ahead (a ceiling's
## collision box on the hull layer: the track's, a narrow one's, a boss's); INF with none. So the
## camera never rises into a ceiling. It would, after a drop off a ceiling's far end: the player falls
## from the ceiling's height and the camera follows them up, and it climbed into the ceiling before it
## passed the end, where the end band's glow and the ceiling's insides filled the screen (a one-frame
## orange wash and a glare, task B3). Past the end nothing holds it, and the skins keep every glow
## there above the underside (MeshKit.ceiling_end). The review tools that copy the chase camera
## (tools/showcase) use it too.
static func ceiling_limit(space: PhysicsDirectSpaceState3D, pos: Vector3, t: MovementTuning) -> float:
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collision_mask = TrackBuilder.LAYER_HULL
	var limit: float = INF
	for ahead: float in [0.0, CEILING_AHEAD]:
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

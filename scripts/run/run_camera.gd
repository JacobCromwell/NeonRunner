class_name RunCamera
extends Camera3D
## Chase camera for a run: behind and above the player, following sideways and upward in part,
## dropping below the ceiling to look up at a player running on it. Shakes on request (RunEffects),
## scaled by the accessibility setting. All numbers come from MovementTuning's Camera group.

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
	var k: float = 1.0 if instant else 1.0 - exp(-t.camera_smoothing * delta)
	_focus.x = lerpf(_focus.x, p.x * t.camera_follow_x, k)
	_focus.y = lerpf(_focus.y, cam_y, k)
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


func _on_shake(strength: float, duration: float) -> void:
	if strength >= _shake * clampf(_shake_left / maxf(_shake_time, 0.001), 0.0, 1.0):
		_shake = strength
		_shake_time = duration
		_shake_left = duration

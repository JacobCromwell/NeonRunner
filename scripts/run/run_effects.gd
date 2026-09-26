class_name RunEffects
extends Node3D
## Shared, pooled visual effects for a run: particle bursts (hits, explosions, pickups), short
## glowing lines (grapple rope, beams) and camera-shake requests. CPU particles only, so it works
## on the Compatibility renderer. Effects never affect gameplay. Screen shake respects the
## player's accessibility setting through `shake_scale` (0 = off).

signal shake_requested(strength: float, duration: float)

const BURST_POOL: int = 12
const LINE_POOL: int = 4

## Multiplies every shake request (Settings sets it; 0 turns screen shake off).
var shake_scale: float = 1.0

var _bursts: Array[CPUParticles3D] = []
var _next_burst: int = 0
var _lines: Array[MeshInstance3D] = []
var _line_life: Array[float] = []
var _mesh: SphereMesh


func _ready() -> void:
	_mesh = SphereMesh.new()
	_mesh.radius = 0.06
	_mesh.height = 0.12
	_mesh.radial_segments = 6
	_mesh.rings = 3
	for i: int in BURST_POOL:
		var p := CPUParticles3D.new()
		p.emitting = false
		p.one_shot = true
		p.explosiveness = 0.95
		p.lifetime = 0.45
		p.mesh = _mesh
		p.direction = Vector3.UP
		p.spread = 180.0
		p.gravity = Vector3(0.0, -9.0, 0.0)
		p.initial_velocity_min = 3.0
		p.initial_velocity_max = 7.0
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.4
		p.local_coords = false
		add_child(p)
		_bursts.append(p)
	for i: int in LINE_POOL:
		var line := MeshInstance3D.new()
		line.mesh = GreyboxMaterials.unit_box()
		line.visible = false
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(line)
		_lines.append(line)
		_line_life.append(0.0)


## A burst of glowing particles at `pos`. `size` scales the spread and speed (1 = explosion).
func burst(pos: Vector3, color: Color, amount: int = 16, size: float = 0.5) -> void:
	if _bursts.is_empty():
		return
	var p: CPUParticles3D = _bursts[_next_burst]
	_next_burst = (_next_burst + 1) % _bursts.size()
	p.global_position = pos
	p.amount = clampi(amount, 2, 64)
	p.initial_velocity_min = 2.0 * size + 1.0
	p.initial_velocity_max = 7.0 * size + 2.0
	p.material_override = GreyboxMaterials.glow(color, 3.0)
	p.restart()
	p.emitting = true


## A glowing straight line from `a` to `b` that fades after `duration` (the grapple rope).
func line(a: Vector3, b: Vector3, color: Color, duration: float = 0.3, thickness: float = 0.05) -> void:
	for i: int in _lines.size():
		if _line_life[i] > 0.0:
			continue
		var l: MeshInstance3D = _lines[i]
		var mid: Vector3 = (a + b) * 0.5
		var length: float = a.distance_to(b)
		l.global_position = mid
		if length > 0.001:
			var dir: Vector3 = (b - a) / length
			var up: Vector3 = Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
			l.basis = Basis.looking_at(dir, up).scaled(Vector3(thickness, thickness, length))
		l.material_override = GreyboxMaterials.glow(color, 3.0)
		l.visible = true
		_line_life[i] = duration
		return


## Asks the camera to shake (hits, explosions, trucks bursting through walls).
func shake(strength: float, duration: float = 0.25) -> void:
	if shake_scale > 0.0:
		shake_requested.emit(strength * shake_scale, duration)


func _process(delta: float) -> void:
	for i: int in _lines.size():
		if _line_life[i] > 0.0:
			_line_life[i] -= delta
			if _line_life[i] <= 0.0:
				_lines[i].visible = false

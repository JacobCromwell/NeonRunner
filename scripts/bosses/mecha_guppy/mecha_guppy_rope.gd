class_name MechaGuppyRope
extends Node3D
## The grapple's rope as it saves a falling runner in Mecha Guppy and Captain Cogs' climb (MechaGuppy._grapple_save;
## DESIGN-TBD, docs/questions/e5e.md: E5e-a's proposal, a glowing rope for a moment). It runs from the runner's chest,
## followed frame by frame as the save lifts them up (so it never hangs from where they were falling, below the
## screen), to the roof's edge it caught, for a fraction of a second, then it's gone. A warm white: no hazard colour;
## steady (nothing to calm for Reduced flashing).

## Where on the runner it starts (above their feet).
const CHEST: float = 0.9

var _player: Player
var _anchor: Vector3
var _left: float = 0.0
var _thickness: float = 0.06
var _mesh: MeshInstance3D


func setup(player: Player, anchor: Vector3, color: Color, seconds: float, thickness: float) -> void:
	_player = player
	_anchor = anchor
	_left = seconds
	_thickness = thickness
	top_level = true
	_mesh = MeshInstance3D.new()
	_mesh.mesh = GreyboxMaterials.unit_box()
	_mesh.material_override = GreyboxMaterials.glow(color, 1.6)
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.visible = false
	add_child(_mesh)


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0 or _player == null or not is_instance_valid(_player):
		queue_free()
		return
	var a: Vector3 = _player.global_position + Vector3(0.0, CHEST, 0.0)
	var length: float = a.distance_to(_anchor)
	if length < 0.05:
		_mesh.visible = false
		return
	var dir: Vector3 = (_anchor - a) / length
	var up: Vector3 = Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	_mesh.global_transform = Transform3D(Basis.looking_at(dir, up) * Basis.from_scale(Vector3(_thickness, _thickness, length)),
		(a + _anchor) * 0.5)
	_mesh.visible = true


## The rope's ends now (tests).
func ends() -> PackedVector3Array:
	if _player == null or not is_instance_valid(_player):
		return PackedVector3Array()
	return PackedVector3Array([_player.global_position + Vector3(0.0, CHEST, 0.0), _anchor])

class_name TestBossBody
extends BossPart
## The test boss's body (TestBoss): a faceted steel core with two white trim rings and a red eye facing
## the player. It is harmless to touch (only its bolts hurt), and its weak point, a glowing red plate
## on top (the hover truck's language), only shows and works while the core lies dazed in a lane.
## The encounter moves it; this only draws it.

const CORE_RADIUS: float = 0.6
## The weak point box, above the core's centre: stomped from above while dazed.
const WEAK_POINT_SIZE := Vector3(1.5, 0.5, 2.2)
const WEAK_POINT_OFFSET := Vector3(0.0, 0.45, 0.0)
const EYE_COLOR := Color(1.0, 0.12, 0.08)
const WEAK_COLOR := Color(1.0, 0.1, 0.06)
const TRIM_COLOR := Color(0.85, 0.9, 1.0)

var _pivot: Node3D
var _rings: Array[MeshInstance3D] = []
var _eye_material: StandardMaterial3D
var _shell_material: StandardMaterial3D
var _weak_look: Node3D
var _charge: float = 0.0
var _flash: float = 0.0
var _dazed: bool = false
var _spin: float = 0.0


func _build() -> void:
	max_health = 1.0
	_pivot = Node3D.new()
	_pivot.name = "Look"
	add_child(_pivot)
	_shell_material = StandardMaterial3D.new()
	_shell_material.albedo_color = Color(0.2, 0.22, 0.28)
	_shell_material.metallic = 0.8
	_shell_material.roughness = 0.35
	_shell_material.emission_enabled = true
	_shell_material.emission = Color.WHITE
	_shell_material.emission_energy_multiplier = 0.0
	var core := SphereMesh.new()
	core.radius = CORE_RADIUS
	core.height = CORE_RADIUS * 2.0
	core.radial_segments = 8
	core.rings = 4
	_mesh(core, _shell_material, Vector3.ZERO)
	for i: int in 2:
		var ring := TorusMesh.new()
		ring.inner_radius = CORE_RADIUS + 0.12
		ring.outer_radius = CORE_RADIUS + 0.26
		ring.rings = 20
		ring.ring_segments = 6
		var r: MeshInstance3D = _mesh(ring, GreyboxMaterials.glow(TRIM_COLOR, 1.8), Vector3.ZERO)
		r.rotation = Vector3(0.5 + i * 1.2, 0.0, 0.3 - i * 0.9)
		_rings.append(r)
	_eye_material = GreyboxMaterials.glow(EYE_COLOR, 1.0).duplicate() as StandardMaterial3D
	var eye := SphereMesh.new()
	eye.radius = 0.22
	eye.height = 0.44
	eye.radial_segments = 10
	eye.rings = 5
	# The eye faces the player (+z: the player runs toward -z, behind the core).
	_mesh(eye, _eye_material, Vector3(0.0, 0.05, CORE_RADIUS - 0.05))
	_build_weak_look()
	add_weak_point(WEAK_POINT_SIZE, WEAK_POINT_OFFSET)
	set_weak_points_enabled(false)


## The charge-up of a blast (0–1): the eye glows up, the attack's visual warning.
func set_charge(k: float) -> void:
	_charge = clampf(k, 0.0, 1.0)


## Lying dazed in a lane: the weak point shows and works (the encounter still has to be vulnerable).
func set_dazed(on: bool) -> void:
	_dazed = on
	_weak_look.visible = on
	set_weak_points_enabled(on)


## A white glow over the shell that fades (a hit, a phase change); softer with Reduced flashing.
func flash(strength: float = 1.0) -> void:
	_flash = maxf(_flash, strength * (0.35 if Settings.flashing_reduced else 1.0))


func aim_point() -> Vector3:
	return global_position


func hit_radius() -> float:
	return 1.1


func _tick(delta: float) -> void:
	_spin += delta * (0.6 if _dazed else 2.4)
	for i: int in _rings.size():
		_rings[i].rotation.y = _spin * (1.0 if i == 0 else -1.3)
	_eye_material.emission_energy_multiplier = 0.6 + 5.0 * _charge * _charge
	_flash = move_toward(_flash, 0.0, delta * 2.0)
	_shell_material.emission_energy_multiplier = 2.5 * _flash
	# Dazed: the core slumps and tilts in its lane.
	_pivot.rotation.z = lerpf(_pivot.rotation.z, 0.35 if _dazed else 0.0, 1.0 - exp(-6.0 * delta))


func _on_defeated(_cause: StringName) -> void:
	world.play_sfx_at(&"truck_explode", global_position)
	world.effects.burst(global_position, WEAK_COLOR, 48, 1.4)
	world.effects.burst(global_position, TRIM_COLOR, 32, 1.0)
	world.effects.shake(0.4, 0.4)
	queue_free()


func _build_weak_look() -> void:
	_weak_look = Node3D.new()
	_weak_look.name = "WeakPoint"
	_weak_look.visible = false
	_pivot.add_child(_weak_look)
	var plate := CylinderMesh.new()
	plate.top_radius = 0.5
	plate.bottom_radius = 0.58
	plate.height = 0.16
	plate.radial_segments = 12
	_mesh(plate, GreyboxMaterials.glow(WEAK_COLOR, 3.2), Vector3(0.0, CORE_RADIUS - 0.02, 0.0), _weak_look)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.6
	rim.outer_radius = 0.72
	rim.rings = 16
	rim.ring_segments = 5
	_mesh(rim, GreyboxMaterials.glow(WEAK_COLOR, 2.0), Vector3(0.0, CORE_RADIUS - 0.04, 0.0), _weak_look)


func _mesh(mesh: Mesh, material: Material, at: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = material
	m.position = at
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else _pivot).add_child(m)
	return m

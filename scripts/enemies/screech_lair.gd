class_name ScreechLair
extends Node3D
## Where a Sewer Screech hides (GDD §9.5): a manhole cover in a floor lane or a grille vent at the
## foot of a wall (GDD §3: vents exist only at the bottom of walls). Visual only: the Screech owns
## the gameplay. The screech's own prop, drawn in every zone (skins don't know about it): it sits on
## the floor at y = 0 or on the wall face, like the track's own pieces.
##
## The warning (GDD §9.5): the cover or grille rattles, its slots glow red with the eyes behind them
## and green mist puffs out; then it bursts open. A manhole cover flips up and clangs back down over
## the hole (so no open hole is left that looks like a gap); a vent grille flies off and is gone.
## Built from shared meshes and materials; placed in world space (top_level).

const EYE_GLOW := Color(1.0, 0.2, 0.08)
const MIST := Color(0.45, 1.0, 0.3)

enum Kind { MANHOLE, VENT }

static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}

var kind: Kind = Kind.MANHOLE
## 0–1: how hard it rattles (the warning).
var shaking: float = 0.0

var _lid: Node3D
var _lid_rest := Transform3D.IDENTITY
var _glow: Array[MeshInstance3D] = []
var _mist: CPUParticles3D
var _burst_t: float = -1.0
var _rng := RandomNumberGenerator.new()
var _glow_dim: Material
var _glow_bright: Material


## `side`: 0 for a manhole, -1 / +1 for a vent on the left / right wall.
func build(p_kind: Kind, variant: StringName, side: int, p_seed: int) -> void:
	kind = p_kind
	top_level = true
	_rng.seed = p_seed
	var scav: bool = variant == &"scavenger"
	var metal: Material = _metal(scav)
	var dark: Material = _dark()
	_glow_dim = GreyboxMaterials.glow(EYE_GLOW, 0.35)
	_glow_bright = GreyboxMaterials.glow(EYE_GLOW, 4.0)
	_lid = Node3D.new()
	_lid.name = "Lid"
	add_child(_lid)
	if kind == Kind.MANHOLE:
		_add_mesh(self, _disc(0.52, 0.008), Vector3(0.0, 0.004, 0.0), GreyboxMaterials.flat(Color(0.05, 0.05, 0.06)))
		_add_mesh(self, _disc(0.44, 0.004), Vector3(0.0, 0.01, 0.0), dark)
		_lid.position = Vector3(0.0, 0.035, 0.0)
		_add_mesh(_lid, _disc(0.43, 0.045), Vector3.ZERO, metal)
		# Raised cross and four slots, with red eyes glowing through them.
		GreyboxMaterials.add_box(_lid, Vector3(0.0, 0.026, 0.0), Vector3(0.72, 0.012, 0.05), metal)
		GreyboxMaterials.add_box(_lid, Vector3(0.0, 0.026, 0.0), Vector3(0.05, 0.012, 0.72), metal)
		for i: int in 4:
			var a: float = TAU * (float(i) + 0.5) / 4.0
			var slot := GreyboxMaterials.add_box(_lid, Vector3(sin(a) * 0.22, 0.024, cos(a) * 0.22),
				Vector3(0.16, 0.006, 0.045), _glow_dim)
			slot.rotation.y = a
			_glow.append(slot)
	else:
		# Built for the right wall (face at local x = 0, the track toward -x); turned for the left.
		rotation.y = 0.0 if side > 0 else PI
		GreyboxMaterials.add_box(self, Vector3(-0.03, 0.35, 0.0), Vector3(0.06, 0.68, 1.16), metal)
		GreyboxMaterials.add_box(self, Vector3(-0.064, 0.35, 0.0), Vector3(0.012, 0.54, 1.0), dark)
		for sz: float in [-0.13, 0.13]:
			_glow.append(GreyboxMaterials.add_box(self, Vector3(-0.072, 0.3, sz), Vector3(0.006, 0.05, 0.09), _glow_dim))
		_lid.position = Vector3(-0.09, 0.35, 0.0)
		for i: int in 5:
			GreyboxMaterials.add_box(_lid, Vector3(0.0, -0.2 + i * 0.1, 0.0), Vector3(0.025, 0.045, 1.0), metal)
		for sz: float in [-0.35, 0.0, 0.35]:
			GreyboxMaterials.add_box(_lid, Vector3(0.012, 0.0, sz), Vector3(0.02, 0.5, 0.035), metal)
	_lid_rest = _lid.transform
	_mist = CPUParticles3D.new()
	_mist.emitting = false
	_mist.amount = 14
	_mist.lifetime = 0.7
	_mist.mesh = _puff_mesh()
	_mist.material_override = GreyboxMaterials.glow(MIST, 1.2, 0.45)
	_mist.direction = Vector3.UP if kind == Kind.MANHOLE else Vector3(-1.0, 0.6, 0.0)
	_mist.spread = 30.0
	_mist.gravity = Vector3(0.0, 0.6, 0.0)
	_mist.initial_velocity_min = 0.6
	_mist.initial_velocity_max = 1.6
	_mist.scale_amount_min = 0.8
	_mist.scale_amount_max = 2.0
	_mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_mist.emission_sphere_radius = 0.3
	_mist.position = Vector3(0.0, 0.08, 0.0) if kind == Kind.MANHOLE else Vector3(-0.12, 0.3, 0.0)
	add_child(_mist)


## Starts or stops the rattle (the audio half of the warning is played by the Screech).
func set_shaking(on: bool) -> void:
	shaking = 1.0 if on else 0.0
	_mist.emitting = on
	for g: MeshInstance3D in _glow:
		g.material_override = _glow_bright if on else _glow_dim


## Bursts open: the lid flies.
func burst() -> void:
	set_shaking(false)
	_burst_t = 0.0
	_mist.emitting = true
	_mist.amount = 24


func _process(delta: float) -> void:
	if _burst_t >= 0.0:
		_burst_t += delta
		_animate_burst()
		if _burst_t > 0.5:
			_mist.emitting = false
		return
	if shaking > 0.0:
		var j: float = shaking
		var t := Transform3D(Basis.from_euler(Vector3(_rng.randf_range(-0.12, 0.12) * j, 0.0,
			_rng.randf_range(-0.12, 0.12) * j)), Vector3(_rng.randf_range(-0.01, 0.01), _rng.randf() * 0.05 * j,
			_rng.randf_range(-0.01, 0.01)))
		if kind == Kind.VENT:
			t.origin = Vector3(_rng.randf() * -0.04 * j, _rng.randf_range(-0.015, 0.015), _rng.randf_range(-0.02, 0.02))
		_lid.transform = _lid_rest * t
		var pulse: bool = int(Time.get_ticks_msec() / 70) % 2 == 0
		for g: MeshInstance3D in _glow:
			g.visible = pulse or kind == Kind.VENT
	elif _lid.transform != _lid_rest:
		_lid.transform = _lid_rest
		for g: MeshInstance3D in _glow:
			g.visible = true


func _animate_burst() -> void:
	var t: float = _burst_t
	if kind == Kind.MANHOLE:
		# Up in a spin, then back down over the hole, knocked askew.
		var d: float = 0.75
		var k: float = clampf(t / d, 0.0, 1.0)
		var y: float = 0.035 + 7.0 * minf(t, d) * (1.0 - k)
		var rest := Transform3D(Basis(Vector3.UP, 0.45), Vector3(0.1, 0.035, 0.08))
		var spin := Basis(Vector3.RIGHT, TAU * smoothstep(0.0, 1.0, k))
		_lid.transform = Transform3D(spin, Vector3(lerpf(0.0, rest.origin.x, k), y, lerpf(0.0, rest.origin.z, k)))
		if k >= 1.0:
			_lid.transform = rest
			_burst_t = -1.0
			_lid_rest = rest
	else:
		# The grille flies out onto the track, lands and is gone.
		var fly: float = clampf(t / 0.5, 0.0, 1.0)
		var y: float = 0.35 + 2.2 * fly * (1.0 - fly) - 0.33 * fly
		_lid.transform = Transform3D(Basis(Vector3.FORWARD, -2.5 * fly), Vector3(-0.09 - 1.6 * fly, y, 0.2 * fly))
		var fade: float = clampf((t - 0.7) / 0.3, 0.0, 1.0)
		_lid.scale = Vector3.ONE * maxf(0.001, 1.0 - fade)
		if fade >= 1.0:
			_lid.visible = false
			_burst_t = -1.0
			_lid_rest = _lid.transform


# --- Shared meshes and materials -------------------------------------------------------------

func _add_mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _disc(radius: float, height: float) -> CylinderMesh:
	var key: String = "disc_%s_%s" % [radius, height]
	if not _meshes.has(key):
		var m := CylinderMesh.new()
		m.top_radius = radius
		m.bottom_radius = radius
		m.height = height
		m.radial_segments = 16
		m.rings = 1
		_meshes[key] = m
	return _meshes[key]


static func _puff_mesh() -> SphereMesh:
	if not _meshes.has("puff"):
		var m := SphereMesh.new()
		m.radius = 0.06
		m.height = 0.12
		m.radial_segments = 6
		m.rings = 3
		_meshes["puff"] = m
	return _meshes["puff"]


## Cover and frame metal: clean steel in the city, rust in scavenger zones (weathering only).
static func _metal(scav: bool) -> StandardMaterial3D:
	var key: String = "metal_%s" % scav
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.3, 0.2, 0.13) if scav else Color(0.22, 0.25, 0.3)
		m.metallic = 0.4 if scav else 0.8
		m.roughness = 0.85 if scav else 0.4
		_materials[key] = m
	return _materials[key]


static func _dark() -> StandardMaterial3D:
	if not _materials.has("dark"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.005, 0.006, 0.004)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_materials["dark"] = m
	return _materials["dark"]

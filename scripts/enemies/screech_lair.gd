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
## Parts that light up red while it shakes (the manhole's rim, the vent's frame), and their rest look.
var _warn: Array[MeshInstance3D] = []
var _warn_rest: Array[Material] = []


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
		_warn.append(_add_mesh(self, _disc(0.52, 0.008), Vector3(0.0, 0.004, 0.0), GreyboxMaterials.flat(Color(0.05, 0.05, 0.06))))
		_add_mesh(self, _disc(0.44, 0.004), Vector3(0.0, 0.01, 0.0), dark)
		_lid.position = Vector3(0.0, 0.035, 0.0)
		# The cover with its raised cross, and four slots with red eyes glowing through them.
		_add_mesh(_lid, _manhole_cover_mesh(), Vector3.ZERO, metal)
		var slots: MeshInstance3D = _add_mesh(_lid, _manhole_slots_mesh(), Vector3.ZERO, _glow_dim)
		slots.name = "Glow"
		_glow.append(slots)
	else:
		# Built for the right wall (face at local x = 0, the track toward -x); turned for the left.
		rotation.y = 0.0 if side > 0 else PI
		_warn.append(GreyboxMaterials.add_box(self, Vector3(-0.03, 0.35, 0.0), Vector3(0.06, 0.68, 1.16), metal))
		GreyboxMaterials.add_box(self, Vector3(-0.064, 0.35, 0.0), Vector3(0.012, 0.54, 1.0), dark)
		var eyes: MeshInstance3D = _add_mesh(self, _vent_eyes_mesh(), Vector3.ZERO, _glow_dim)
		eyes.name = "Glow"
		_glow.append(eyes)
		_lid.position = Vector3(-0.09, 0.35, 0.0)
		_add_mesh(_lid, _vent_grille_mesh(), Vector3.ZERO, metal)
	_lid_rest = _lid.transform
	for w: MeshInstance3D in _warn:
		_warn_rest.append(w.material_override)
	_mist = CPUParticles3D.new()
	_mist.emitting = false
	_mist.amount = 24
	_mist.lifetime = 0.9
	_mist.mesh = _puff_mesh()
	_mist.material_override = _puff_material()
	_mist.color_ramp = _puff_ramp()
	_mist.direction = Vector3.UP if kind == Kind.MANHOLE else Vector3(-1.0, 0.6, 0.0)
	_mist.spread = 30.0
	_mist.gravity = Vector3(0.0, 0.4, 0.0)
	_mist.initial_velocity_min = 1.0
	_mist.initial_velocity_max = 2.4
	_mist.scale_amount_min = 0.9
	_mist.scale_amount_max = 2.4
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
	for i: int in _warn.size():
		_warn[i].material_override = GreyboxMaterials.glow(EYE_GLOW, 2.6) if on else _warn_rest[i]


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
		var t := Transform3D(Basis.from_euler(Vector3(_rng.randf_range(-0.16, 0.16) * j, 0.0,
			_rng.randf_range(-0.16, 0.16) * j)), Vector3(_rng.randf_range(-0.015, 0.015), _rng.randf() * 0.09 * j,
			_rng.randf_range(-0.015, 0.015)))
		if kind == Kind.VENT:
			t.origin = Vector3(_rng.randf() * -0.04 * j, _rng.randf_range(-0.015, 0.015), _rng.randf_range(-0.02, 0.02))
		_lid.transform = _lid_rest * t
		var pulse: bool = Settings.flashing_reduced or int(Time.get_ticks_msec() / 70) % 2 == 0
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


## Merges primitive parts ([mesh, transform] pairs) into one cached mesh: one draw call each.
static func _merged(key: String, parts: Array) -> ArrayMesh:
	if not _meshes.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part: Array in parts:
			st.append_from(part[0] as Mesh, 0, part[1] as Transform3D)
		_meshes[key] = st.commit()
	return _meshes[key]


static func _box(center: Vector3, size: Vector3, yaw: float = 0.0) -> Array:
	return [GreyboxMaterials.unit_box(), Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(size), center)]


static func _manhole_cover_mesh() -> ArrayMesh:
	return _merged("cover", [[_disc(0.43, 0.045), Transform3D.IDENTITY],
		_box(Vector3(0.0, 0.026, 0.0), Vector3(0.72, 0.012, 0.05)),
		_box(Vector3(0.0, 0.026, 0.0), Vector3(0.05, 0.012, 0.72))])


static func _manhole_slots_mesh() -> ArrayMesh:
	var parts: Array = []
	for i: int in 4:
		var a: float = TAU * (float(i) + 0.5) / 4.0
		parts.append(_box(Vector3(sin(a) * 0.22, 0.024, cos(a) * 0.22), Vector3(0.16, 0.006, 0.045), a))
	return _merged("slots", parts)


static func _vent_eyes_mesh() -> ArrayMesh:
	return _merged("vent_eyes", [_box(Vector3(-0.072, 0.3, -0.13), Vector3(0.006, 0.05, 0.09)),
		_box(Vector3(-0.072, 0.3, 0.13), Vector3(0.006, 0.05, 0.09))])


static func _vent_grille_mesh() -> ArrayMesh:
	var parts: Array = []
	for i: int in 5:
		parts.append(_box(Vector3(0.0, -0.2 + i * 0.1, 0.0), Vector3(0.025, 0.045, 1.0)))
	for sz: float in [-0.35, 0.0, 0.35]:
		parts.append(_box(Vector3(0.012, 0.0, sz), Vector3(0.02, 0.5, 0.035)))
	return _merged("grille", parts)


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


## Sewer mist: glowing green puffs that fade out (vertex colour from the particles' colour ramp).
static func _puff_material() -> StandardMaterial3D:
	if not _materials.has("puff"):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.vertex_color_use_as_albedo = true
		m.albedo_color = Color(1.4, 1.6, 1.3)
		_materials["puff"] = m
	return _materials["puff"]


static func _puff_ramp() -> Gradient:
	if not _materials.has("puff_ramp"):
		var g := Gradient.new()
		g.set_color(0, Color(MIST, 0.55))
		g.set_color(1, Color(MIST.darkened(0.3), 0.0))
		_materials["puff_ramp"] = g
	return _materials["puff_ramp"]


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

class_name EnforcerTruckBlast
extends Node3D
## The Enforcer Truck's explosion (the owner, October 8, 2026: "when the enforcer falls in a gap or is hit by
## buzzsaw overdrive there should be a visible explosion"): a fireball of a few swelling puffs, a white-hot core
## at its heart, dark smoke rolling up after it, and a fire-glow on the floor around it. The truck makes it where
## the chase camera sees it (EnforcerTruck's wreck: it lurches on into view first) and carries it along in the
## runner's frame, falling back slowly (EnforcerTruckTuning.blast_drift), so it stays in view while it burns;
## the shared RunEffects add its sparks, debris and shake.
## - Every part is unshaded: alpha-blended puffs (emissive for the fire) and an additive, vertex-coloured floor
##   glow, cheap on every renderer (phones and the Compatibility renderer: no light, no particles of its own).
##   Its meshes and materials are made once and shared (static caches); a blast fades copies of the materials,
##   which share their shaders, and warm_look() shows every kind while the level loads (EnforcerTruck.warm_up),
##   so no shader is built mid-run.
## - Reduced flashing (Settings.flashing_reduced): no white-hot core, a softer fire and floor glow that come up
##   over a moment instead of at once (no bright flash).
## - Its size: `radius`, the fireball's at its biggest. In the runner's lane it's small and `flat` (its puffs rise
##   less), so it stays under the camera's line of sight to them; beside them, bigger (tests/suites/
##   test_enforcer_truck.gd checks both never hide the runner, and that the camera sees them).
## Ten draw calls while it lasts (about a second), about 1,000 triangles.

## The fire's colours: the hot core, the fireball's orange, its red edge, and the smoke.
const HOT := Color(1.0, 0.92, 0.65)
const FIRE := Color(1.0, 0.48, 0.1)
const EMBER := Color(0.95, 0.22, 0.06)
const SMOKE := Color(0.13, 0.12, 0.12)
## The puffs, in units of the radius and of the blast's length: [kind, offset (x, y, z: z negative is
## forward), peak size, start, peak, end, rise]. The fire swells fast and fades; the smoke comes up behind it,
## rises and lingers. Sizes are diameters (the sphere mesh is one across). A flat blast's offsets up and rises
## are FLAT of these.
const PUFFS: Array = [
	[&"core", Vector3(0.0, 0.1, 0.0), 0.9, 0.0, 0.08, 0.35, 0.1],
	[&"fire", Vector3(0.0, 0.2, 0.0), 1.6, 0.0, 0.22, 0.6, 0.2],
	[&"fire", Vector3(-0.45, 0.1, -0.35), 1.1, 0.03, 0.26, 0.62, 0.3],
	[&"fire", Vector3(0.45, 0.15, 0.3), 1.05, 0.05, 0.3, 0.66, 0.3],
	[&"ember", Vector3(0.1, 0.35, -0.1), 0.9, 0.1, 0.35, 0.72, 0.45],
	[&"smoke", Vector3(-0.2, 0.45, 0.35), 1.0, 0.2, 0.6, 1.0, 0.6],
	[&"smoke", Vector3(0.3, 0.55, -0.2), 0.9, 0.28, 0.7, 1.0, 0.7],
]
const FLAT: float = 0.3
## The floor glow's reach (in units of the radius) and its life (a share of the blast's length).
const GLOW_REACH: float = 2.4
const GLOW_LIFE: float = 0.55

static var _sphere: SphereMesh
static var _disc: ArrayMesh
## Materials made once: by kind (&"core", &"fire", &"ember", &"smoke", &"glow").
static var _materials: Dictionary = {}

## The fireball's biggest size (metres), how long it all lasts (seconds), seconds into it.
var radius: float = 2.0
var length: float = 0.9
var t: float = 0.0
var reduced: bool = false
## Low (in the runner's lane): its puffs rise less (FLAT).
var flat: bool = false
## Each puff: {node, mat (its own copy, faded), kind, offset, size, start, peak, end, rise, alpha}.
var _puffs: Array[Dictionary] = []
var _glow: MeshInstance3D
var _glow_mat: StandardMaterial3D


## Sets it off: `p_radius` metres at its biggest, lasting `p_length` seconds, softer with `p_reduced`, low with
## `p_flat` (in the runner's lane).
func start(p_radius: float, p_length: float, p_reduced: bool, p_flat: bool = false) -> void:
	radius = maxf(p_radius, 0.1)
	length = maxf(p_length, 0.1)
	reduced = p_reduced
	flat = p_flat
	t = 0.0
	for p: Dictionary in _puffs:
		(p["node"] as Node).queue_free()
	_puffs.clear()
	for spec: Array in PUFFS:
		var kind: StringName = spec[0]
		if kind == &"core" and reduced:
			continue
		var mat := material(kind).duplicate() as StandardMaterial3D
		var node := MeshInstance3D.new()
		node.name = "Puff%d" % _puffs.size()
		node.mesh = sphere()
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		_puffs.append({"node": node, "mat": mat, "kind": kind, "offset": spec[1], "size": float(spec[2]),
			"start": float(spec[3]), "peak": float(spec[4]), "end": float(spec[5]), "rise": float(spec[6]),
			"alpha": mat.albedo_color.a})
	if _glow == null:
		_glow = MeshInstance3D.new()
		_glow.name = "FloorGlow"
		_glow.mesh = disc()
		_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_glow)
	_glow_mat = material(&"glow").duplicate() as StandardMaterial3D
	_glow.material_override = _glow_mat
	visible = true
	advance(0.0)


## Moves it on by `delta` seconds: the puffs swell, rise and fade, the floor glow fades.
func advance(delta: float) -> void:
	t += delta
	var u: float = t / length
	for p: Dictionary in _puffs:
		var node: MeshInstance3D = p["node"]
		var size: float = float(p["size"])
		var start_u: float = float(p["start"])
		var peak_u: float = float(p["peak"])
		var end_u: float = float(p["end"])
		if u < start_u or u >= end_u:
			node.visible = false
			continue
		node.visible = true
		var grow: float = clampf((u - start_u) / maxf(peak_u - start_u, 0.001), 0.0, 1.0)
		var fade: float = clampf((u - peak_u) / maxf(end_u - peak_u, 0.001), 0.0, 1.0)
		var s: float = radius * size * (0.35 + 0.65 * (1.0 - pow(1.0 - grow, 2.0))) * (1.0 + 0.15 * fade)
		node.scale = Vector3.ONE * s
		var up: float = FLAT if flat else 1.0
		var offset: Vector3 = (p["offset"] as Vector3) * radius
		node.position = Vector3(offset.x, offset.y * up + float(p["rise"]) * up * radius * (u - start_u), offset.z)
		var a: float = float(p["alpha"]) * (1.0 - fade * fade)
		if reduced and p["kind"] != &"smoke":
			# No sudden flash: the fire comes up over its swell and stays softer.
			a *= 0.6 * grow
		var mat: StandardMaterial3D = p["mat"]
		mat.albedo_color.a = a
	if _glow != null:
		var g: float = clampf(u / GLOW_LIFE, 0.0, 1.0)
		var strength: float = (1.0 - g) * (1.0 - g) * (0.5 if reduced else 1.0)
		if reduced:
			strength *= clampf(u / 0.12, 0.0, 1.0)
		_glow.visible = strength > 0.01
		_glow.scale = Vector3(radius * GLOW_REACH, 1.0, radius * GLOW_REACH) * (0.7 + 0.3 * g)
		_glow_mat.albedo_color = Color(strength, strength, strength, 1.0)


## True once it has burnt out.
func done() -> bool:
	return t >= length


## Every puff shown now as a sphere: Vector4(centre in the blast's parent's space (x, y, z), radius). What the
## camera may see of it (tests: it never hides the runner).
func spheres() -> Array[Vector4]:
	var out: Array[Vector4] = []
	for p: Dictionary in _puffs:
		var node: MeshInstance3D = p["node"]
		if node.visible:
			var c: Vector3 = transform * node.position
			out.append(Vector4(c.x, c.y, c.z, node.scale.x * 0.5))
	return out


# --- Shared look -------------------------------------------------------------------------------------

## A low-poly sphere one metre across.
static func sphere() -> SphereMesh:
	if _sphere == null:
		_sphere = SphereMesh.new()
		_sphere.radius = 0.5
		_sphere.height = 1.0
		_sphere.radial_segments = 14
		_sphere.rings = 7
	return _sphere


## The floor glow: a flat disc one metre in radius on the floor, its fire colour fading to nothing at its rim
## (vertex colours, added light).
static func disc() -> ArrayMesh:
	if _disc == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var n: int = 20
		var hot := Color(1.0, 0.55, 0.16)
		for i: int in n:
			var a0: float = TAU * i / n
			var a1: float = TAU * (i + 1) / n
			for v: Array in [[Vector3.ZERO, hot], [Vector3(cos(a1), 0.0, sin(a1)), Color.BLACK],
					[Vector3(cos(a0), 0.0, sin(a0)), Color.BLACK]]:
				st.set_color(v[1])
				st.add_vertex(v[0])
		_disc = st.commit()
	return _disc


## The material for a kind of puff (&"core", &"fire", &"ember", &"smoke") or the floor glow (&"glow"), made once.
## A blast fades its own copies.
static func material(kind: StringName) -> StandardMaterial3D:
	if _materials.has(kind):
		return _materials[kind]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_BACK
	match kind:
		&"core":
			m.albedo_color = Color(HOT, 0.95)
			m.emission_enabled = true
			m.emission = HOT
			m.emission_energy_multiplier = 4.5
		&"fire":
			m.albedo_color = Color(FIRE, 0.88)
			m.emission_enabled = true
			m.emission = FIRE
			m.emission_energy_multiplier = 3.2
		&"ember":
			m.albedo_color = Color(EMBER, 0.8)
			m.emission_enabled = true
			m.emission = EMBER
			m.emission_energy_multiplier = 2.4
		&"smoke":
			m.albedo_color = Color(SMOKE, 0.78)
		&"glow":
			m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.vertex_color_use_as_albedo = true
			m.albedo_color = Color.WHITE
			m.no_depth_test = false
			m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_materials[kind] = m
	return m


## One of every part a blast shows, each material on its mesh, for the level's warm-up (EnforcerTruck.warm_up):
## no physics object.
static func warm_look() -> Node3D:
	var root := Node3D.new()
	root.name = "BlastWarmUp"
	for kind: StringName in [&"core", &"fire", &"ember", &"smoke"]:
		var mi := MeshInstance3D.new()
		mi.mesh = sphere()
		mi.material_override = material(kind)
		root.add_child(mi)
	var glow := MeshInstance3D.new()
	glow.mesh = disc()
	glow.material_override = material(&"glow")
	root.add_child(glow)
	return root

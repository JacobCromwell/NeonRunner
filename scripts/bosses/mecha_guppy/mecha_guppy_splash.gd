class_name MechaGuppySplash
extends Node3D
## A plume of spray where Mecha Guppy breaks the sea (MechaGuppyLeap: where it bursts out of the water and where it dives
## back in; task E5e-c's review found the swim away unseen from the top). Jets of white water shoot up `height` metres
## over a ring of foam `width` across, hold a moment, then fall back and spread out on the sea. Sized for a building-sized
## shark seen 50-120 m off through the haze: big and plain, sea water low down turning to white spray up top, lit like
## the scene so it shows its shape against the pale haze (white alone vanishes into it); it never glows nor takes a
## hazard colour, and nothing flickers. Its owner places it and drives it (advance, from the boss's ticks), and keeps it
## in place.
## DESIGN-TBD (docs/questions/e5e.md): the defeat's staging.

## The plume's life (seconds): up, held, falling back and spreading.
const RISE: float = 0.35
const HOLD: float = 0.25
const FALL: float = 1.3
## How far the jets sink below the sea and how wide they spread as they fall (shares of height and width).
const SINK: float = 0.25
const SPREAD: float = 0.7
## Sea water up most of the jets (the sea's mid blue-green: it shows against the pale haze, where white would vanish),
## turning to white spray at their tops.
const WATER := Color(0.24, 0.6, 0.64)
const SPRAY := Color(0.92, 0.95, 0.94)
## The jets in the unit plume: [x, z, height, radius] (height 1 at most, the ring 1 across).
const JETS: Array[Vector4] = [Vector4(0.0, 0.0, 1.0, 0.16), Vector4(0.26, 0.08, 0.72, 0.11), Vector4(-0.2, 0.2, 0.64, 0.1),
	Vector4(-0.18, -0.22, 0.8, 0.12), Vector4(0.12, -0.27, 0.55, 0.09), Vector4(0.33, -0.12, 0.45, 0.08),
	Vector4(-0.34, -0.02, 0.5, 0.08), Vector4(0.05, 0.32, 0.42, 0.08)]

## Its size this time (metres), and how long it has played (-1: not playing).
var height: float = 20.0
var width: float = 10.0
var age: float = -1.0

static var _mesh: ArrayMesh
static var _material: StandardMaterial3D

var _body: MeshInstance3D


func _init() -> void:
	top_level = true
	_body = MeshInstance3D.new()
	_body.name = "Plume"
	_body.mesh = plume_mesh()
	_body.material_override = plume_material()
	_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.visible = false
	add_child(_body)


## Starts the plume at world point `at` (on the sea), `p_height` tall and `p_width` across.
func play(at: Vector3, p_height: float, p_width: float) -> void:
	height = p_height
	width = p_width
	age = 0.0
	global_position = at
	_shape()


## True while it plays.
func playing() -> bool:
	return age >= 0.0


## One physics step (its owner drives it).
func advance(delta: float) -> void:
	if age < 0.0:
		return
	age += delta
	if age >= RISE + HOLD + FALL:
		age = -1.0
	_shape()


## How tall it stands over the sea now (metres; tests: where it's seen).
func standing() -> float:
	if age < 0.0:
		return 0.0
	var k: Vector3 = _scales()
	return height * (k.y - k.z)


func _shape() -> void:
	_body.visible = age >= 0.0
	if age < 0.0:
		return
	var k: Vector3 = _scales()
	_body.transform = Transform3D(Basis.from_scale(Vector3(width * k.x, height * k.y, width * k.x)),
		Vector3(0.0, -height * k.z, 0.0))


## Vector3(spread, height share, sink share) at its age: shooting up (eased out), held, then falling back, spreading.
func _scales() -> Vector3:
	if age < RISE:
		var r: float = age / RISE
		return Vector3(lerpf(0.6, 1.0, r), 1.0 - (1.0 - r) * (1.0 - r), 0.0)
	if age < RISE + HOLD:
		return Vector3(1.0, 1.0, 0.0)
	var f: float = clampf((age - RISE - HOLD) / FALL, 0.0, 1.0)
	return Vector3(1.0 + SPREAD * f, lerpf(1.0, 0.25, f * f), SINK * f)


## The unit plume: tapering jets of water over a flat ring of foam (y up from the sea, 1 tall at most, 1 across).
static func plume_mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides: int = 6
	for jet: Vector4 in JETS:
		var base := Vector3(jet.x, 0.0, jet.y)
		var top := base + Vector3(jet.x * 0.35, jet.z, jet.y * 0.35)
		var mid: float = 0.6
		for i: int in sides:
			var a: float = TAU * float(i) / float(sides)
			var b: float = TAU * float(i + 1) / float(sides)
			var ra := Vector3(cos(a), 0.0, sin(a)) * jet.w
			var rb := Vector3(cos(b), 0.0, sin(b)) * jet.w
			var m: Vector3 = base.lerp(top, mid)
			# Wider low down, narrowing to a point: two bands, then the tip.
			_quad(st, base + ra, base + rb, m + rb * 0.75, m + ra * 0.75)
			_tri(st, m + ra * 0.75, m + rb * 0.75, top)
	# Coloured by height: water low down, spray up top.
	var arrays: Array = st.commit_to_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors := PackedColorArray()
	for v: Vector3 in verts:
		colors.append(WATER.lerp(SPRAY, smoothstep(0.4, 1.0, v.y)))
	st.clear()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in verts.size():
		st.set_color(colors[i])
		st.add_vertex(verts[i])
	var ring: int = 12
	for i: int in ring:
		var a: float = TAU * float(i) / float(ring)
		var b: float = TAU * float(i + 1) / float(ring)
		var o0 := Vector3(cos(a), 0.0, sin(a)) * 0.5
		var o1 := Vector3(cos(b), 0.0, sin(b)) * 0.5
		var lift := Vector3(0.0, 0.03, 0.0)
		st.set_color(SPRAY)
		_tri(st, Vector3(0.0, 0.02, 0.0), o1 + lift, o0 + lift)
	st.generate_normals()
	_mesh = st.commit()
	return _mesh


static func plume_material() -> StandardMaterial3D:
	if _material != null:
		return _material
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.roughness = 0.9
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _material


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_tri(st, a, b, c)
	_tri(st, a, c, d)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

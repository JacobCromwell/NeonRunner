class_name BuzzOverdriveModel
extends Node3D
## The Buzz Overdrive's look (GDD §9.9: "a truck-sized buzzsaw tank with a giant, vertical buzzsaw
## blade. Militaristic. A red, angry eye on each side"). Low-poly and merged (PartBatch): a tracked hull
## with skirt armour, a sloped glacis, a low angular turret with a slanted red eye slit on each side
## under a hard dark brow, exhaust stacks at the back, and in front a giant vertical saw blade on two
## braced arms. Safe parts are matte; only what hurts or warns glows in a hazard colour:
## the blade's teeth (hot orange-red, the one deadly part) and the eyes (red). The hull's paint follows
## the zone: a clean military gunmetal, or scorched and rusted where enemies weather (the Dead Zone's
## burned look, Gangland's scavengers). The shape and every hazard colour are the same everywhere.
## Model space: it faces +z (toward the player, who runs toward -z); the origin is on the floor where
## the blade bites into it (the cut's front). Six draw calls (hull: 4 materials; blade: 2) and about
## 1,700 triangles, built once per look and shared.

## The enemies' merger of primitives (one surface per material; not the track kit's MeshBatch).
const PartBatch := preload("res://scripts/enemies/mesh_batch.gd")
## The blade's centre above the floor: sunk a little into it, so it cuts.
const BLADE_SINK: float = 0.12
const TEETH: int = 24
const DISC_SEGMENTS: int = 24
const BLADE_THICKNESS: float = 0.12
const HOT := Color(1.0, 0.32, 0.06)
const EYE := Color(1.0, 0.08, 0.05)

## Meshes per look and size, built once.
static var _meshes: Dictionary = {}

var blade: Node3D
var _body: MeshInstance3D
var _blade_mesh: MeshInstance3D
var _eyes: MeshInstance3D
var _eye_rest: Material
var _eye_flare: Material
var _radius: float = 1.3


## Builds the look for a zone's enemy variant (ZoneSkin.enemy_variant) at `body_size` (width, height,
## length behind the blade) with a blade of `radius`.
func build(variant: StringName, body_size: Vector3, radius: float) -> void:
	_radius = radius
	var meshes: Dictionary = meshes_for(variant, body_size, radius)
	_body = _node(self, meshes["body"], Vector3.ZERO)
	_eyes = _node(self, meshes["eyes"], Vector3.ZERO)
	_eye_rest = meshes["eye_rest"]
	_eye_flare = meshes["eye_flare"]
	blade = Node3D.new()
	blade.name = "Blade"
	blade.position = Vector3(0.0, radius - BLADE_SINK, 0.0)
	add_child(blade)
	_blade_mesh = _node(blade, meshes["blade"], Vector3.ZERO)


## Turns the blade by `angle` radians (about its axle, across the lane), rim running down at the front
## so it bites toward the player.
func spin(angle: float) -> void:
	blade.rotation.x += angle


## The eyes at rest, or flaring (while it revs and charges).
func set_flare(on: bool) -> void:
	_eyes.material_override = _eye_flare if on else _eye_rest


func draw_call_count() -> int:
	var n: int = 0
	for m: MeshInstance3D in [_body, _eyes, _blade_mesh]:
		n += m.mesh.get_surface_count()
	return n


func triangle_count() -> int:
	var n: int = 0
	for m: MeshInstance3D in [_body, _eyes, _blade_mesh]:
		for s: int in m.mesh.get_surface_count():
			var arrays: Array = m.mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			n += idx.size() / 3 if not idx.is_empty() else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n


## Every material the model draws with, and whether it glows (tests: only hazards glow).
func materials() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m: MeshInstance3D in [_body, _eyes, _blade_mesh]:
		for s: int in m.mesh.get_surface_count():
			var mat: Material = m.mesh.surface_get_material(s)
			out.append({"part": String(m.name), "material": mat})
	out.append({"part": "eyes (flaring)", "material": _eye_flare})
	return out


func _node(parent: Node3D, mesh: Mesh, at: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.position = at
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m


## The meshes for a look: {body, eyes, eye_rest, eye_flare, blade}, cached.
static func meshes_for(variant: StringName, body_size: Vector3, radius: float) -> Dictionary:
	var weathered: bool = variant == &"burned" or variant == &"scavenger"
	var key: String = "%s|%s|%s" % [weathered, body_size, radius]
	if _meshes.has(key):
		return _meshes[key]
	var out := {
		"body": _hull(weathered, body_size, radius),
		"eyes": _eye_slits(body_size, radius),
		"eye_rest": GreyboxMaterials.glow(EYE, 2.2),
		"eye_flare": GreyboxMaterials.glow(Color(1.0, 0.22, 0.1), 5.0),
		"blade": _blade(radius),
	}
	_meshes[key] = out
	return out


## Where the hull starts behind the blade (model z), and its other key heights.
static func hull_front(radius: float) -> float:
	return -radius - 0.25


static func _hull(weathered: bool, size: Vector3, radius: float) -> ArrayMesh:
	var W: float = size.x
	var H: float = size.y
	var L: float = size.z
	var z0: float = hull_front(radius)
	var zc: float = z0 - L * 0.5
	var paint: Color = Color(0.34, 0.27, 0.2) if weathered else Color(0.28, 0.31, 0.27)
	var plate: Color = Color(0.26, 0.2, 0.16) if weathered else Color(0.36, 0.39, 0.35)
	var hull_m: Material = GreyboxMaterials.flat(paint)
	var plate_m: Material = GreyboxMaterials.flat(plate)
	var dark_m: Material = GreyboxMaterials.flat(Color(0.08, 0.08, 0.09))
	var steel_m: Material = GreyboxMaterials.flat(Color(0.5, 0.48, 0.45) if weathered else Color(0.62, 0.64, 0.66))
	var b := PartBatch.new()
	var track_w: float = W * 0.22
	var track_h: float = H * 0.36
	# Tracks and road wheels, under skirt armour.
	for sx: float in [-1.0, 1.0]:
		var tx: float = sx * (W * 0.5 - track_w * 0.5)
		b.box(dark_m, Vector3(tx, track_h * 0.5 + 0.02, zc), Vector3(track_w, track_h, L))
		for k: int in 5:
			var wz: float = z0 - 0.55 - k * (L - 1.1) / 4.0
			b.cylinder(steel_m, Vector3(tx + sx * 0.02, track_h * 0.45, wz), Vector3(track_h * 0.8, track_w + 0.04, track_h * 0.8),
				Vector3(0.0, 0.0, PI * 0.5))
		b.box(plate_m, Vector3(sx * (W * 0.5 + 0.02), track_h * 0.9, zc - 0.2), Vector3(0.05, track_h * 0.75, L - 0.6))
	# Lower and upper hull, the sloped glacis toward the blade and the rear deck.
	b.box(hull_m, Vector3(0.0, track_h * 0.75, zc), Vector3(W - track_w * 2.0 + 0.04, track_h * 0.9, L - 0.1))
	var deck_y: float = track_h + 0.02
	var upper_h: float = H * 0.32
	b.box(hull_m, Vector3(0.0, deck_y + upper_h * 0.5, zc - 0.35), Vector3(W * 0.98, upper_h, L - 0.9))
	# The glacis: a plate sloping down toward the blade.
	b.box(plate_m, Vector3(0.0, deck_y + upper_h * 0.45, z0 - 0.42), Vector3(W * 0.96, 0.1, upper_h * 1.45), Vector3(0.85, 0.0, 0.0))
	# The turret: a low, angular block with slanted cheeks, the eyes on its sides.
	var tur_y: float = deck_y + upper_h
	var tur_h: float = H - tur_y
	var tur_l: float = L * 0.42
	var tur_z: float = zc + L * 0.06
	b.box(hull_m, Vector3(0.0, tur_y + tur_h * 0.5, tur_z), Vector3(W * 0.66, tur_h, tur_l))
	b.box(plate_m, Vector3(0.0, tur_y + tur_h * 0.5, tur_z + tur_l * 0.5 + 0.14), Vector3(W * 0.64, 0.08, tur_h * 1.2),
		Vector3(0.6, 0.0, 0.0))
	b.box(plate_m, Vector3(0.0, H + 0.03, tur_z - 0.1), Vector3(W * 0.5, 0.06, tur_l * 0.7))
	# A hard dark brow over each eye (the eyes themselves: _eye_slits), slanting down to the front.
	for sx: float in [-1.0, 1.0]:
		b.box(dark_m, Vector3(sx * (W * 0.33 + 0.02), tur_y + tur_h * 0.5 + 0.14, tur_z + tur_l * 0.2 + 0.05),
			Vector3(0.05, 0.07, 0.86), Vector3(-0.42, 0.0, 0.0))
	# Exhaust stacks and a rear rack.
	for sx: float in [-1.0, 1.0]:
		b.cylinder(dark_m, Vector3(sx * W * 0.32, tur_y + 0.35, z0 - L + 0.55), Vector3(0.2, 0.75, 0.2))
	b.box(dark_m, Vector3(0.0, deck_y + upper_h + 0.12, z0 - L + 0.35), Vector3(W * 0.8, 0.24, 0.5))
	# The blade's arms, from the hub back into the glacis, and a brace from the hub up to the deck.
	var hub_y: float = radius - BLADE_SINK
	for sx: float in [-1.0, 1.0]:
		b.box(steel_m, Vector3(sx * 0.2, hub_y, (z0 + 0.2) * 0.5 - 0.1), Vector3(0.14, 0.34, absf(z0) + 0.5))
		var brace_from := Vector3(sx * 0.2, hub_y + 0.1, -0.2)
		var brace_to := Vector3(sx * 0.32, deck_y + upper_h - 0.05, z0 - 0.6)
		var mid: Vector3 = (brace_from + brace_to) * 0.5
		var dir: Vector3 = brace_to - brace_from
		b.box(dark_m, mid, Vector3(0.12, 0.14, dir.length()), Vector3(atan2(dir.y, -dir.z), 0.0, 0.0))
	b.cylinder(dark_m, Vector3(0.0, hub_y, 0.0), Vector3(0.46, 0.56, 0.46), Vector3(0.0, 0.0, PI * 0.5))
	if weathered:
		# Scorch marks and rust patches on the hull's sides (in the plates' rusty brown and the dark).
		for sx: float in [-1.0, 1.0]:
			for k: int in 3:
				b.box(plate_m if k % 2 == 0 else dark_m, Vector3(sx * (W * 0.49 + 0.01), deck_y + 0.25 + 0.1 * k,
					zc + 1.4 - k * 1.3), Vector3(0.02, 0.32, 0.7))
	return b.commit()


## The red, angry eyes: on each side of the turret, a slit slanted down toward the front like a frown,
## with a hard dark brow over it.
static func _eye_slits(size: Vector3, radius: float) -> ArrayMesh:
	var W: float = size.x
	var H: float = size.y
	var L: float = size.z
	var z0: float = hull_front(radius)
	var zc: float = z0 - L * 0.5
	var tur_y: float = size.y * 0.36 + 0.02 + H * 0.32
	var tur_z: float = zc + L * 0.06
	var tur_l: float = L * 0.42
	var b := PartBatch.new()
	var eye_m: Material = GreyboxMaterials.glow(EYE, 2.2)
	for sx: float in [-1.0, 1.0]:
		var x: float = sx * (W * 0.33 + 0.014)
		var y: float = tur_y + (H - tur_y) * 0.5
		var z: float = tur_z + tur_l * 0.2
		b.box(eye_m, Vector3(x, y, z), Vector3(0.03, 0.13, 0.78), Vector3(-0.3, 0.0, 0.0))
	return b.commit()


## The blade: a steel disc in the y-z plane (its axle along x), with a ring of teeth around its rim
## that glow hot (the deadly part), and a dark hub.
static func _blade(radius: float) -> ArrayMesh:
	var disc_m: Material = GreyboxMaterials.flat(Color(0.55, 0.57, 0.6))
	var teeth_m: Material = GreyboxMaterials.glow(HOT, 3.2)
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half: float = BLADE_THICKNESS * 0.5
	var inner: float = radius * 0.9
	for side: float in [-1.0, 1.0]:
		st.set_normal(Vector3(side, 0.0, 0.0))
		for i: int in DISC_SEGMENTS:
			var a0: float = TAU * i / DISC_SEGMENTS
			var a1: float = TAU * (i + 1) / DISC_SEGMENTS
			var p0 := Vector3(side * half, sin(a0) * inner, cos(a0) * inner)
			var p1 := Vector3(side * half, sin(a1) * inner, cos(a1) * inner)
			var c := Vector3(side * half, 0.0, 0.0)
			if side > 0.0:
				st.add_vertex(c)
				st.add_vertex(p1)
				st.add_vertex(p0)
			else:
				st.add_vertex(c)
				st.add_vertex(p0)
				st.add_vertex(p1)
	# The rim between the faces.
	for i: int in DISC_SEGMENTS:
		var a0: float = TAU * i / DISC_SEGMENTS
		var a1: float = TAU * (i + 1) / DISC_SEGMENTS
		var n := Vector3(0.0, sin((a0 + a1) * 0.5), cos((a0 + a1) * 0.5))
		st.set_normal(n)
		var q0 := Vector3(-half, sin(a0) * inner, cos(a0) * inner)
		var q1 := Vector3(-half, sin(a1) * inner, cos(a1) * inner)
		var q2 := Vector3(half, sin(a1) * inner, cos(a1) * inner)
		var q3 := Vector3(half, sin(a0) * inner, cos(a0) * inner)
		st.add_vertex(q0)
		st.add_vertex(q1)
		st.add_vertex(q2)
		st.add_vertex(q0)
		st.add_vertex(q2)
		st.add_vertex(q3)
	st.commit(mesh)
	mesh.surface_set_material(0, disc_m)
	# Teeth: hooked triangles from the disc's edge out to the full radius, raked one way.
	var tt := SurfaceTool.new()
	tt.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in TEETH:
		var a0: float = TAU * i / TEETH
		var a1: float = TAU * (i + 0.8) / TEETH
		var tip_a: float = TAU * (i + 0.15) / TEETH
		var b0 := Vector3(0.0, sin(a0) * inner * 0.98, cos(a0) * inner * 0.98)
		var b1 := Vector3(0.0, sin(a1) * inner * 0.98, cos(a1) * inner * 0.98)
		var tip := Vector3(0.0, sin(tip_a) * radius, cos(tip_a) * radius)
		for side: float in [-1.0, 1.0]:
			var off := Vector3(side * half * 0.8, 0.0, 0.0)
			tt.set_normal(Vector3(side, 0.0, 0.0))
			if side > 0.0:
				tt.add_vertex(b0 + off)
				tt.add_vertex(tip + off)
				tt.add_vertex(b1 + off)
			else:
				tt.add_vertex(b0 + off)
				tt.add_vertex(b1 + off)
				tt.add_vertex(tip + off)
		# The tooth's two edges, so it reads from the front too.
		for edge: Array in [[b0, tip], [tip, b1]]:
			var e0: Vector3 = edge[0]
			var e1: Vector3 = edge[1]
			var mid: Vector3 = (e0 + e1) * 0.5
			tt.set_normal(Vector3(0.0, mid.y, mid.z).normalized())
			tt.add_vertex(e0 + Vector3(-half * 0.8, 0.0, 0.0))
			tt.add_vertex(e1 + Vector3(-half * 0.8, 0.0, 0.0))
			tt.add_vertex(e1 + Vector3(half * 0.8, 0.0, 0.0))
			tt.add_vertex(e0 + Vector3(-half * 0.8, 0.0, 0.0))
			tt.add_vertex(e1 + Vector3(half * 0.8, 0.0, 0.0))
			tt.add_vertex(e0 + Vector3(half * 0.8, 0.0, 0.0))
	tt.commit(mesh)
	mesh.surface_set_material(1, teeth_m)
	return mesh

class_name MeshLayer
extends RefCounted
## Unindexed triangles for one material: the working unit of the mesh kit. Primitives are appended
## from cached unit templates with bulk transforms, so building a chunk stays cheap in GDScript.
##
## Vertex data convention (read by the kit shaders):
##   COLOR.rgb  albedo in sRGB (converted in the shader, so dark colours don't band)
##   COLOR.a    glow: 0 = a lit surface, above 0 = emissive at the material's glow scale times this
##   UV         pattern coordinates (metres on facades and panels, 0–1 on glow cards)
##   UV2.x      pattern or shape id (MeshKit.PAT_* / MeshKit.SHAPE_*), UV2.y a pattern parameter
## There are no normals: the kit is flat-shaded, and its shaders take each face's normal from
## screen-space derivatives (encoding normals was most of the cost of building a mesh).
## Front faces wind clockwise, Godot's convention. A mirroring transform flips the winding back.

var verts := PackedVector3Array()
var colors := PackedColorArray()
var uvs := PackedVector2Array()
var uv2s := PackedVector2Array()


func size() -> int:
	return verts.size()


func is_empty() -> bool:
	return verts.is_empty()


## An axis-aligned box. `faces` is a mask of MeshKit.FACE_* sides to keep (hidden sides cost nothing).
func box(center: Vector3, box_size: Vector3, color: Color, glow: float = 0.0, pattern: int = 0,
		faces: int = MeshKit.ALL_FACES, param: float = 0.0) -> void:
	box_xform(Transform3D(Basis.from_scale(box_size), center), color, glow, pattern, faces, param)


## A unit box (centred, 1 m) placed by `xform`, which may rotate and scale it.
func box_xform(xform: Transform3D, color: Color, glow: float = 0.0, pattern: int = 0,
		faces: int = MeshKit.ALL_FACES, param: float = 0.0) -> void:
	_append_uniform(MeshKit.unit_box(faces), xform, Color(color, glow), Vector2(pattern, param))


## A box between two opposite corners (any order).
func box_between(a: Vector3, b: Vector3, color: Color, glow: float = 0.0, pattern: int = 0,
		faces: int = MeshKit.ALL_FACES, param: float = 0.0) -> void:
	box((a + b) * 0.5, (b - a).abs(), color, glow, pattern, faces, param)


## A parallelogram with corners origin, origin + u, origin + u + v, origin + v. It faces u × v.
## UV runs from uv0 at the origin to uv1 at the far corner (UV.x along u, UV.y along v).
func rect(origin: Vector3, u: Vector3, v: Vector3, color: Color, glow: float = 0.0, pattern: int = 0,
		uv0: Vector2 = Vector2.ZERO, uv1: Vector2 = Vector2.ONE, param: float = 0.0) -> void:
	var b: Vector3 = origin + v
	var c: Vector3 = origin + u + v
	var d: Vector3 = origin + u
	verts.append_array(PackedVector3Array([origin, b, c, origin, c, d]))
	var col := Color(color, glow)
	colors.append_array(PackedColorArray([col, col, col, col, col, col]))
	var ub := Vector2(uv0.x, uv1.y)
	var ud := Vector2(uv1.x, uv0.y)
	uvs.append_array(PackedVector2Array([uv0, ub, uv1, uv0, uv1, ud]))
	var p := Vector2(pattern, param)
	uv2s.append_array(PackedVector2Array([p, p, p, p, p, p]))


## A four-cornered patch (corners in clockwise order seen from the front), for tapered shapes.
## UV is (0,0) at a, (0,1) at b, (1,1) at c and (1,0) at d.
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, glow: float = 0.0,
		pattern: int = 0, param: float = 0.0) -> void:
	verts.append_array(PackedVector3Array([a, b, c, a, c, d]))
	var col := Color(color, glow)
	colors.append_array(PackedColorArray([col, col, col, col, col, col]))
	uvs.append_array(PackedVector2Array([Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(1, 0)]))
	var p := Vector2(pattern, param)
	uv2s.append_array(PackedVector2Array([p, p, p, p, p, p]))


## A four-cornered patch like quad() with a UV for each corner, for facade pieces whose windows must
## line up with their neighbours' (UV in metres).
func quad_uv(a: Vector3, b: Vector3, c: Vector3, d: Vector3, uv_a: Vector2, uv_b: Vector2, uv_c: Vector2,
		uv_d: Vector2, color: Color, glow: float = 0.0, pattern: int = 0, param: float = 0.0) -> void:
	verts.append_array(PackedVector3Array([a, b, c, a, c, d]))
	var col := Color(color, glow)
	colors.append_array(PackedColorArray([col, col, col, col, col, col]))
	uvs.append_array(PackedVector2Array([uv_a, uv_b, uv_c, uv_a, uv_c, uv_d]))
	var p := Vector2(pattern, param)
	uv2s.append_array(PackedVector2Array([p, p, p, p, p, p]))


## An upright prism (radius to the corners, `sides` faces) standing on `base`. `caps` adds top and bottom.
func prism(base: Vector3, radius: float, height: float, sides: int, color: Color, glow: float = 0.0,
		pattern: int = 0, caps: bool = true) -> void:
	var xform := Transform3D(Basis.from_scale(Vector3(radius, height, radius)), base)
	_append_uniform(MeshKit.unit_prism(sides, caps), xform, Color(color, glow), Vector2(pattern, 0.0))


## A prism along an arbitrary axis: `xform` maps the unit prism (radius 1, y from 0 to 1).
func prism_xform(xform: Transform3D, sides: int, color: Color, glow: float = 0.0, pattern: int = 0,
		caps: bool = true) -> void:
	_append_uniform(MeshKit.unit_prism(sides, caps), xform, Color(color, glow), Vector2(pattern, 0.0))


## Appends another layer (a cached template) transformed by `xform`, keeping its colours and UVs.
func append(other: MeshLayer, xform: Transform3D = Transform3D.IDENTITY) -> void:
	if other.verts.is_empty():
		return
	if xform.basis.determinant() < 0.0:
		var v: PackedVector3Array = xform * other.verts
		var c: PackedColorArray = other.colors.duplicate()
		var t: PackedVector2Array = other.uvs.duplicate()
		var t2: PackedVector2Array = other.uv2s.duplicate()
		v.reverse()
		c.reverse()
		t.reverse()
		t2.reverse()
		verts.append_array(v)
		colors.append_array(c)
		uvs.append_array(t)
		uv2s.append_array(t2)
		return
	verts.append_array(xform * other.verts if xform != Transform3D.IDENTITY else other.verts)
	colors.append_array(other.colors)
	uvs.append_array(other.uvs)
	uv2s.append_array(other.uv2s)


## Appends a template's positions and UVs with one colour and pattern for all of it.
func _append_uniform(template: MeshLayer, xform: Transform3D, color: Color, pattern: Vector2) -> void:
	var count: int = template.verts.size()
	var v: PackedVector3Array = xform * template.verts
	if xform.basis.determinant() < 0.0:
		var t: PackedVector2Array = template.uvs.duplicate()
		v.reverse()
		t.reverse()
		uvs.append_array(t)
	else:
		uvs.append_array(template.uvs)
	verts.append_array(v)
	colors.append_array(MeshKit.filled_colors(color, count))
	uv2s.append_array(MeshKit.filled_uv2(pattern, count))

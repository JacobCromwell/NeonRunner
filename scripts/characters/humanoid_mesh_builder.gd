class_name HumanoidMeshBuilder
extends RefCounted
## Builds flat-shaded, low-poly geometry from HumanoidPiece shapes into one surface. Every triangle
## has its own face normal (the faceted low-poly look). The vertex colour is the albedo (linear; its
## alpha 1 - the piece's shine) and UV.x the glow amount, which humanoid_body.gdshader turns into emission, so plain parts and neon
## trim share one material and a whole rig segment costs a single draw call. UV.y is a tag: 0 for
## ordinary parts, k + 1 for the pieces of HumanoidRig panel k (the shader swings them).
##
## Faces are oriented from how each shape is constructed (outward normals, front faces wound the way
## Godot expects), so mirrored pieces need no special handling.

var vertices := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()
var uvs := PackedVector2Array()

var _xf := Transform3D.IDENTITY
var _color := Color.WHITE
var _glow: float = 0.0
var _tag: float = 0.0


func triangle_count() -> int:
	return int(vertices.size() / 3.0)


func is_empty() -> bool:
	return vertices.is_empty()


## Adds one piece in segment space. `mirror` reflects it across x = 0 (the left-side copy). `tag`
## goes into UV.y (0 = an ordinary part; k + 1 = a piece of panel k).
func add_piece(piece: HumanoidPiece, mirror: bool, tag: int = 0) -> void:
	_xf = Transform3D(Basis.from_euler(piece.rotation_degrees * (PI / 180.0)), piece.offset)
	if mirror:
		_xf = Transform3D(Basis.from_scale(Vector3(-1.0, 1.0, 1.0)), Vector3.ZERO) * _xf
	_color = piece.color.srgb_to_linear()
	_color.a = 1.0 - clampf(piece.shine, 0.0, 1.0)
	_glow = piece.glow
	_tag = float(tag)
	var half := Vector2(piece.size.x, piece.size.z) * 0.5
	var all_round := Vector2(-180.0, 180.0)
	var phase: float = deg_to_rad(piece.section_phase)
	match piece.shape:
		HumanoidPiece.Shape.BOX:
			_loft(chamfer_rect(half, piece.chamfer), _straight_rings(piece), true, true, all_round)
		HumanoidPiece.Shape.PRISM:
			_loft(ngon(piece.sides, half, phase), _straight_rings(piece), true, true, all_round)
		HumanoidPiece.Shape.LATHE:
			_loft(ngon(piece.sides, half, phase), piece.profile, true, true, all_round)
		HumanoidPiece.Shape.BAND:
			_loft(ngon(piece.sides, half, phase), piece.profile, false, false, piece.arc)
		HumanoidPiece.Shape.TORUS:
			_torus(piece.size.x * 0.5, piece.size.y * 0.5, piece.sides, 6)
		HumanoidPiece.Shape.SHELL:
			_shell(ngon(piece.sides, half, phase), piece.profile, piece.arc, piece.thickness)


## The surface arrays for ArrayMesh.add_surface_from_arrays().
func arrays() -> Array:
	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = vertices
	out[Mesh.ARRAY_NORMAL] = normals
	out[Mesh.ARRAY_COLOR] = colors
	out[Mesh.ARRAY_TEX_UV] = uvs
	return out


## A regular polygon section with diameters 2·half, with a flat face toward +z (the back);
## `phase` (radians) turns its corners round the outline.
static func ngon(sides: int, half: Vector2, phase_offset: float = 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	var phase: float = PI * 0.5 - PI / sides + phase_offset
	for k: int in sides:
		var a: float = phase + TAU * k / sides
		out.append(Vector2(cos(a) * half.x, sin(a) * half.y))
	return out


## A rectangle section (half-sizes `half`) with its corners cut by `chamfer` × the smaller half-size.
static func chamfer_rect(half: Vector2, chamfer: float) -> PackedVector2Array:
	var hx: float = half.x
	var hz: float = half.y
	var c: float = minf(hx, hz) * clampf(chamfer, 0.0, 0.5)
	if c <= 0.0001:
		return PackedVector2Array([Vector2(hx, -hz), Vector2(hx, hz), Vector2(-hx, hz), Vector2(-hx, -hz)])
	return PackedVector2Array([Vector2(hx, -hz + c), Vector2(hx, hz - c), Vector2(hx - c, hz), Vector2(-hx + c, hz),
		Vector2(-hx, hz - c), Vector2(-hx, -hz + c), Vector2(-hx + c, -hz), Vector2(hx - c, -hz)])


func _straight_rings(piece: HumanoidPiece) -> PackedVector4Array:
	var h: float = piece.size.y * 0.5
	return PackedVector4Array([Vector4(-h, 1.0, 1.0, 0.0),
		Vector4(h, piece.top_scale.x, piece.top_scale.y, piece.top_shift)])


## Sweeps `section` (x/z) through `rings` (height, x scale, z scale, z shift). Side faces within
## `arc` (degrees from the front) are kept; caps close the first and last ring.
func _loft(section: PackedVector2Array, rings: PackedVector4Array, cap_start: bool, cap_end: bool, arc: Vector2) -> void:
	var n: int = section.size()
	if n < 3 or rings.size() < 2:
		return
	# The construction below gives outward normals for a counter-clockwise section (angle rising
	# from +x toward +z) swept upward; flip for the other orientations.
	var flip: float = 1.0
	if _signed_area(section) < 0.0:
		flip = -flip
	var rise: float = rings[rings.size() - 1].x - rings[0].x
	if rise < 0.0:
		flip = -flip
	var ring_pts: Array[PackedVector3Array] = []
	for r: Vector4 in rings:
		var ring := PackedVector3Array()
		ring.resize(n)
		for i: int in n:
			ring[i] = Vector3(section[i].x * r.y, r.x, section[i].y * r.z + r.w)
		ring_pts.append(ring)
	var full: bool = arc.x <= -180.0 and arc.y >= 180.0
	for k: int in rings.size() - 1:
		var lo: PackedVector3Array = ring_pts[k]
		var hi: PackedVector3Array = ring_pts[k + 1]
		for i: int in n:
			var j: int = (i + 1) % n
			if not full and not _in_arc((section[i] + section[j]) * 0.5, arc):
				continue
			var up: Vector3 = (hi[i] + hi[j]) * 0.5 - (lo[i] + lo[j]) * 0.5
			var along: Vector3 = lo[j] - lo[i]
			if along.length_squared() < 1e-12:
				along = hi[j] - hi[i]
			_quad(lo[i], lo[j], hi[j], hi[i], up.cross(along) * flip)
	var up_axis := Vector3(0.0, signf(rise) if rise != 0.0 else 1.0, 0.0)
	if cap_start:
		_cap(ring_pts[0], -up_axis)
	if cap_end:
		_cap(ring_pts[ring_pts.size() - 1], up_axis)


## A sheet `thickness` thick over the faces of `section` within `arc`, swept through `rings`: the
## outside, the inside (the section pulled in by `thickness` toward its centre), rims at the first
## and last ring, and the cut edges where the arc starts and ends. Closed all round, so it reads
## from both sides.
func _shell(section: PackedVector2Array, rings: PackedVector4Array, arc: Vector2, thickness: float) -> void:
	var n: int = section.size()
	if n < 3 or rings.size() < 2:
		return
	var inner := PackedVector2Array()
	inner.resize(n)
	for i: int in n:
		var p: Vector2 = section[i]
		var length: float = p.length()
		inner[i] = p * (maxf(length - thickness, length * 0.2) / length) if length > 1e-6 else p
	# Outward normals as in _loft: counter-clockwise section swept upward, flipped otherwise.
	var flip: float = 1.0
	if _signed_area(section) < 0.0:
		flip = -flip
	var rise: float = rings[rings.size() - 1].x - rings[0].x
	if rise < 0.0:
		flip = -flip
	var outer_rings: Array[PackedVector3Array] = []
	var inner_rings: Array[PackedVector3Array] = []
	for r: Vector4 in rings:
		outer_rings.append(_ring(section, r))
		inner_rings.append(_ring(inner, r))
	var in_arc: Array[bool] = []
	for i: int in n:
		in_arc.append(_in_arc((section[i] + section[(i + 1) % n]) * 0.5, arc))
	var sweep := Vector3(0.0, signf(rise) if rise != 0.0 else 1.0, 0.0)
	var last: int = rings.size() - 1
	for i: int in n:
		if not in_arc[i]:
			continue
		var j: int = (i + 1) % n
		for k: int in last:
			var lo: PackedVector3Array = outer_rings[k]
			var hi: PackedVector3Array = outer_rings[k + 1]
			var up: Vector3 = (hi[i] + hi[j]) * 0.5 - (lo[i] + lo[j]) * 0.5
			var along: Vector3 = lo[j] - lo[i]
			if along.length_squared() < 1e-12:
				along = hi[j] - hi[i]
			var outward: Vector3 = up.cross(along) * flip
			_quad(lo[i], lo[j], hi[j], hi[i], outward)
			_quad(inner_rings[k][i], inner_rings[k][j], inner_rings[k + 1][j], inner_rings[k + 1][i], -outward)
		# Rims: the first ring faces back along the sweep, the last one along it.
		_quad(outer_rings[0][i], outer_rings[0][j], inner_rings[0][j], inner_rings[0][i], -sweep)
		_quad(outer_rings[last][i], outer_rings[last][j], inner_rings[last][j], inner_rings[last][i], sweep)
		# The cut edges, where the arc starts (before corner i) or ends (after corner j).
		var tangent := Vector3(section[j].x - section[i].x, 0.0, section[j].y - section[i].y)
		for k: int in last:
			if not in_arc[(i + n - 1) % n]:
				_quad(outer_rings[k][i], inner_rings[k][i], inner_rings[k + 1][i], outer_rings[k + 1][i], -tangent)
			if not in_arc[j]:
				_quad(outer_rings[k][j], inner_rings[k][j], inner_rings[k + 1][j], outer_rings[k + 1][j], tangent)


## One ring of a sweep: `section` scaled by (r.y, r.z), shifted by r.w in z, at height r.x.
static func _ring(section: PackedVector2Array, r: Vector4) -> PackedVector3Array:
	var ring := PackedVector3Array()
	ring.resize(section.size())
	for i: int in section.size():
		ring[i] = Vector3(section[i].x * r.y, r.x, section[i].y * r.z + r.w)
	return ring


func _torus(radius: float, tube: float, segments: int, tube_segments: int) -> void:
	var rings: Array[PackedVector3Array] = []
	for u: int in segments:
		var a: float = TAU * u / segments
		var radial := Vector3(cos(a), 0.0, sin(a))
		var ring := PackedVector3Array()
		for v: int in tube_segments:
			var b: float = TAU * v / tube_segments
			ring.append(radial * (radius + tube * cos(b)) + Vector3(0.0, tube * sin(b), 0.0))
		rings.append(ring)
	for u: int in segments:
		var u2: int = (u + 1) % segments
		var mid_a: float = TAU * (u + 0.5) / segments
		var tube_center := Vector3(cos(mid_a), 0.0, sin(mid_a)) * radius
		for v: int in tube_segments:
			var v2: int = (v + 1) % tube_segments
			var a: Vector3 = rings[u][v]
			var b: Vector3 = rings[u2][v]
			var c: Vector3 = rings[u2][v2]
			var d: Vector3 = rings[u][v2]
			_quad(a, b, c, d, (a + b + c + d) * 0.25 - tube_center)


func _cap(ring: PackedVector3Array, outward: Vector3) -> void:
	for i: int in range(1, ring.size() - 1):
		_tri(ring[0], ring[i], ring[i + 1], outward)


func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> void:
	_tri(a, b, c, outward)
	_tri(a, c, d, outward)


## Emits one triangle facing `outward` (segment space, before the piece transform). Godot treats
## clockwise triangles as front faces, so the order is fixed up here.
func _tri(a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	var pa: Vector3 = _xf * a
	var pb: Vector3 = _xf * b
	var pc: Vector3 = _xf * c
	var cross: Vector3 = (pb - pa).cross(pc - pa)
	if cross.length_squared() < 1e-14:
		return
	var normal: Vector3 = cross.normalized()
	if cross.dot(_xf.basis * outward) > 0.0:
		# (a, b, c) runs counter-clockwise seen from outside: emit it reversed.
		var tmp: Vector3 = pb
		pb = pc
		pc = tmp
	else:
		normal = -normal
	var glow := Vector2(_glow, _tag)
	for p: Vector3 in [pa, pb, pc]:
		vertices.append(p)
		normals.append(normal)
		colors.append(_color)
		uvs.append(glow)


## Whether the direction of section point `p` (0° = front, 90° = right, 180° = back) lies in
## `arc`. Arcs may wrap past the back, e.g. (100, 260).
static func _in_arc(p: Vector2, arc: Vector2) -> bool:
	var angle: float = rad_to_deg(atan2(p.x, -p.y))
	for a: float in [angle, angle + 360.0, angle - 360.0]:
		if a >= arc.x and a <= arc.y:
			return true
	return false


static func _signed_area(section: PackedVector2Array) -> float:
	var area: float = 0.0
	for i: int in section.size():
		var p: Vector2 = section[i]
		var q: Vector2 = section[(i + 1) % section.size()]
		area += p.x * q.y - q.x * p.y
	return area * 0.5

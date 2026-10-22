class_name TerminalIntroText
extends RefCounted
## Letters for the Terminal intro (TerminalIntro): the station's sign, "GRAND TERMINAL", one extruded letter at a time (so
## each can droop on its own mount, or lie broken on the ground), and the stops' names on the route board, flat lines.
## The letters are Exo 2 (OFL, assets/fonts/exo2, recorded in assets/LICENSES.md), triangulated by TextMesh at a coarse
## curve step so the shapes read as cut metal (the Casino's lettering does the same, CasinoLettering) and kept as plain
## MeshLayer vertex arrays for the kit's solid material, so they look like everything else in the scene and cost one
## surface each. Built on first use and cached (a letter is a few hundred vertices).
## A letter's frame: the top middle of its ink box is the origin (its mount), x across, y up (so it hangs below y = 0),
## its front facing +z and the back at z = 0 (the front at z = depth). A line's: x from 0 along the text, y up from the
## baseline, facing +z, flat.

const FONT_PATH: String = "res://assets/fonts/exo2/Exo2[wght].ttf"
const FONT_WEIGHT: int = 800
const FONT_SIZE: int = 64
const PIXEL_SIZE: float = 0.01
const CURVE_STEP: float = 6.0

static var _font: Font
static var _cap: float = 0.0
static var _baseline: float = 0.0
static var _cache: Dictionary = {}


static func font() -> Font:
	if _font == null:
		var base := load(FONT_PATH) as Font
		if base == null:
			return null
		var variation := FontVariation.new()
		variation.base_font = base
		variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): FONT_WEIGHT}
		_font = variation
	return _font


## TextMesh's own height of a capital (its units) and the baseline, measured on an H.
static func _measure() -> void:
	if _cap > 0.0:
		return
	var raw: Dictionary = _triangles("H", 0.0)
	var verts: PackedVector3Array = raw["verts"]
	if verts.is_empty():
		return
	var lo: float = INF
	var hi: float = -INF
	for v: Vector3 in verts:
		lo = minf(lo, v.y)
		hi = maxf(hi, v.y)
	_baseline = lo
	_cap = hi - lo


## `text` through TextMesh of `depth` (its units; 0: flat) as unindexed triangles wound clockwise seen from outside
## (the kit's front faces), with each triangle's normal.
static func _triangles(text: String, depth: float) -> Dictionary:
	var f: Font = font()
	if f == null:
		return {"verts": PackedVector3Array(), "normals": PackedVector3Array()}
	var tm := TextMesh.new()
	tm.font = f
	tm.font_size = FONT_SIZE
	tm.pixel_size = PIXEL_SIZE
	tm.depth = depth
	tm.curve_step = CURVE_STEP
	tm.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tm.text = text
	var arrays: Array = tm.get_mesh_arrays()
	if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null:
		return {"verts": PackedVector3Array(), "normals": PackedVector3Array()}
	var src: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var count: int = index.size() if not index.is_empty() else src.size()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for t: int in count / 3:
		var i0: int = index[t * 3] if not index.is_empty() else t * 3
		var i1: int = index[t * 3 + 1] if not index.is_empty() else t * 3 + 1
		var i2: int = index[t * 3 + 2] if not index.is_empty() else t * 3 + 2
		var a: Vector3 = src[i0]
		var b: Vector3 = src[i1]
		var c: Vector3 = src[i2]
		var n: Vector3 = Vector3.BACK
		if not nrm.is_empty():
			n = (nrm[i0] + nrm[i1] + nrm[i2]).normalized()
		else:
			var geometric: Vector3 = (b - a).cross(c - a)
			n = geometric.normalized() if geometric.length_squared() > 1e-12 else Vector3.BACK
		# Clockwise seen from outside: (b - a) x (c - a) points against the outward normal.
		if (b - a).cross(c - a).dot(n) > 0.0:
			var swap: Vector3 = b
			b = c
			c = swap
		verts.append_array(PackedVector3Array([a, b, c]))
		normals.append_array(PackedVector3Array([n, n, n]))
	return {"verts": verts, "normals": normals}


## A line of text, flat, as a MeshLayer `cap` metres tall in a capital's height: x from 0, y up from the baseline,
## facing +z; `glow` is the vertices' COLOR.a. Returns {"layer", "width"} (metres).
static func line(text: String, cap: float, color: Color, glow: float = 0.0, pattern: int = MeshKit.PAT_PLAIN) -> Dictionary:
	_measure()
	var out := {"layer": MeshLayer.new(), "width": 0.0}
	if _cap <= 0.0 or text.strip_edges() == "":
		return out
	var key: String = "line|" + text
	if not _cache.has(key):
		_cache[key] = _triangles(text, 0.0)
	var raw: Dictionary = _cache[key]
	var verts: PackedVector3Array = raw["verts"]
	if verts.is_empty():
		return out
	var x_min: float = INF
	var x_max: float = -INF
	for v: Vector3 in verts:
		x_min = minf(x_min, v.x)
		x_max = maxf(x_max, v.x)
	var k: float = cap / _cap
	var l: MeshLayer = out["layer"]
	l.verts.resize(verts.size())
	for i: int in verts.size():
		l.verts[i] = Vector3((verts[i].x - x_min) * k, (verts[i].y - _baseline) * k, 0.0)
	l.colors = MeshKit.filled_colors(Color(color, glow), verts.size())
	var uvs := PackedVector2Array()
	uvs.resize(verts.size())
	l.uvs = uvs
	l.uv2s = MeshKit.filled_uv2(Vector2(pattern, 0.0), verts.size())
	out["width"] = (x_max - x_min) * k
	return out


## One extruded letter `cap` metres tall, `depth` deep: its mesh in a letter's frame (above), the front face in
## `front_color` glowing at `glow_front` (COLOR.a), the rest `color` unlit. Returns {"layer", "width", "height"} (the
## ink box, metres; the height is the letter's own, a little over `cap` for a Q or a J).
static func letter(ch: String, cap: float, depth: float, color: Color, front_color: Color, glow_front: float = 0.0,
		pattern: int = MeshKit.PAT_PLAIN) -> Dictionary:
	_measure()
	var out := {"layer": MeshLayer.new(), "width": 0.0, "height": cap}
	if _cap <= 0.0:
		return out
	var k: float = cap / _cap
	var key: String = "letter|%s|%.4f" % [ch, depth / k]
	if not _cache.has(key):
		_cache[key] = _triangles(ch, depth / k)
	var raw: Dictionary = _cache[key]
	var verts: PackedVector3Array = raw["verts"]
	var normals: PackedVector3Array = raw["normals"]
	if verts.is_empty():
		return out
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for v: Vector3 in verts:
		lo = lo.min(v)
		hi = hi.max(v)
	var mid_x: float = (lo.x + hi.x) * 0.5
	var l: MeshLayer = out["layer"]
	l.verts.resize(verts.size())
	l.colors.resize(verts.size())
	for i: int in verts.size():
		var v: Vector3 = verts[i]
		# The back at z = 0, the front at z = depth; the top middle at the origin.
		l.verts[i] = Vector3((v.x - mid_x) * k, (v.y - hi.y) * k, (v.z - lo.z) * k)
		l.colors[i] = Color(front_color, glow_front) if normals[i].z > 0.9 else Color(color, 0.0)
	var uvs := PackedVector2Array()
	uvs.resize(verts.size())
	l.uvs = uvs
	l.uv2s = MeshKit.filled_uv2(Vector2(pattern, 0.0), verts.size())
	out["width"] = (hi.x - lo.x) * k
	out["height"] = (hi.y - lo.y) * k
	return out


## A letter's advance (its width plus its side bearings, metres) at `cap` metres tall.
static func advance(ch: String, cap: float) -> float:
	_measure()
	var f: Font = font()
	if f == null or _cap <= 0.0:
		return cap * 0.7
	return f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x * PIXEL_SIZE * cap / _cap

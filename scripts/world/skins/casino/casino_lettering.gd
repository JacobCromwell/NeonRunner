class_name CasinoLettering
extends RefCounted
## Real letters for the Casino's two named casinos (CasinoSkin; task K3; owner, October 9, 2026: "I love
## Gasket's House of Chance and the Brass Lotus", the names in the reference image): the big signs spell
## GASKET'S HOUSE OF CHANCE (a horizontal marquee board, and a blade sign with GASKET'S stacked down it) and
## THE BRASS LOTUS (a board, and a tall blade sign with the letters stacked, like the reference's): a board
## on a wall is seen along its face from the street, a blade face-on, so the blades are what a runner can
## read from afar. Every other sign keeps its glyph rows.
## The letters are Exo 2 (OFL, assets/fonts/exo2, recorded in assets/LICENSES.md), triangulated once by
## TextMesh into flat low-poly letter shapes (curve_step is coarse: the shapes read as cut metal) and kept as
## plain vertex arrays, so a sign costs one MeshLayer.append into the chunk's own solid layer: no
## Label3D, no SubViewport, no extra draw call or surface. They are built once per process (warm(), which
## CasinoSkin.make_environment() calls at a level's start, so no chunk build pays for them) and shared by
## every skin and mesh; the colour and glow go on per skin (layer()). Static: the lettering never changes.
## A layout is a block of letters in "cap heights" (the height of a capital is 1) centred on the origin, in
## the XY plane facing +z with Godot's clockwise front faces, ready to be scaled (fit()) and turned onto a
## wall by the builder.

## The names, in the order the code and the tests use (NAME_*).
const NAME_GASKETS: int = 0
const NAME_LOTUS: int = 1
const NAMES: Array[String] = ["GASKET'S HOUSE OF CHANCE", "THE BRASS LOTUS"]

## The layouts: Gasket's two lines on its board, its one line on a strip over a screen and GASKET'S stacked
## down its blade, the Brass Lotus's two lines on its board and its letters stacked down its blade.
enum Layout { GASKETS_BOARD, GASKETS_STRIP, GASKETS_BLADE, LOTUS_BOARD, LOTUS_BLADE }

## The font (the project's body face) and the weight and size its glyphs are made at, and the pixel size
## and curve step that decide how many triangles a curve costs.
const FONT_PATH: String = "res://assets/fonts/exo2/Exo2[wght].ttf"
const FONT_WEIGHT: int = 800
const FONT_SIZE: int = 64
const PIXEL_SIZE: float = 0.01
const CURVE_STEP: float = 6.0

## The PAT_CASINO_SIGN parameter added to a board that carries real letters: its shader draws only the dark
## panel and the tube of light, not the brand mark and the glyph rows.
const NAMED_PANEL: float = 100000.0

## Layout numbers, in the first (big) line's cap heights: the gap between lines, the small line's size.
const GASKETS_GAP: float = 0.36
const GASKETS_SMALL_MIN: float = 0.4
const GASKETS_SMALL_MAX: float = 0.62
const LOTUS_THE: float = 0.42
const LOTUS_GAP: float = 0.3
## The blade's letters: one above the next at this pitch (a capital plus the gap under it), with a wider gap
## between the words.
const BLADE_PITCH: float = 1.3
const BLADE_WORD_GAP: float = 0.55

## Built layouts: layout -> {"verts": PackedVector3Array (unindexed triangles), "size": Vector2 (cap heights)}.
static var _layouts: Dictionary = {}
## Normalised lines of text: text -> {"verts": PackedVector3Array, "size": Vector2}, x from 0 and y from the
## baseline, in cap heights.
static var _lines: Dictionary = {}
## The font's baseline and capital height, in the TextMesh's own units, measured on an H.
static var _baseline: float = 0.0
static var _cap: float = 0.0


## Which name the casino building `id` on `side` carries, by hash: the same every build.
## DESIGN-TBD (docs/questions/k3.md 1 and 2): half the casinos each, and a casino whose big sign plays the
## cult's feed carries Gasket's name on a strip over the screen and the Brass Lotus's only on its blade.
static func pick(side: int, id: int) -> int:
	return NAME_LOTUS if MeshKit.hash01(side, id, 68) < 0.5 else NAME_GASKETS


## Builds every layout (a few milliseconds, once per process).
static func warm() -> void:
	for layout: int in Layout.values():
		_layout(layout)


## The size of layout `layout` in cap heights (zero if the font couldn't be read).
static func layout_size(layout: int) -> Vector2:
	return _layout(layout)["size"]


## How many vertices layout `layout` has (unindexed triangles).
static func vertex_count(layout: int) -> int:
	return (_layout(layout)["verts"] as PackedVector3Array).size()


## The scale (metres per cap height) that fits layout `layout` into `room` metres wide and tall.
static func fit(layout: int, room: Vector2) -> float:
	var size: Vector2 = layout_size(layout)
	if size.x <= 0.0 or size.y <= 0.0:
		return 0.0
	return minf(room.x / size.x, room.y / size.y)


## The layout as a MeshLayer in `color` with `glow` (COLOR.a), plain pattern, for MeshLayer.append() with a
## transform that scales it to metres and turns it onto its sign. Empty if the font couldn't be read.
static func layer(layout: int, color: Color, glow: float) -> MeshLayer:
	var l := MeshLayer.new()
	var verts: PackedVector3Array = _layout(layout)["verts"]
	var count: int = verts.size()
	if count == 0:
		return l
	l.verts = verts
	l.colors = MeshKit.filled_colors(Color(color, glow), count)
	var uvs := PackedVector2Array()
	uvs.resize(count)
	l.uvs = uvs
	l.uv2s = MeshKit.filled_uv2(Vector2(MeshKit.PAT_PLAIN, 0.0), count)
	return l


# --- Building the layouts -----------------------------------------------------------------------

static func _layout(layout: int) -> Dictionary:
	var found: Variant = _layouts.get(layout)
	if found != null:
		return found
	var out: Dictionary = _build_layout(layout)
	_layouts[layout] = out
	return out


static func _build_layout(layout: int) -> Dictionary:
	var parts: Array[Dictionary] = []
	match layout:
		Layout.GASKETS_BOARD:
			var big: Dictionary = _line("GASKET'S")
			var small: Dictionary = _line("HOUSE OF CHANCE")
			var big_w: float = (big["size"] as Vector2).x
			var small_w: float = (small["size"] as Vector2).x
			# The second line a little wider than the first, as a marquee's is.
			var s: float = clampf(big_w * 1.15 / maxf(small_w, 0.001), GASKETS_SMALL_MIN, GASKETS_SMALL_MAX)
			parts.append({"line": big, "scale": 1.0, "y": s + GASKETS_GAP})
			parts.append({"line": small, "scale": s, "y": 0.0})
		Layout.GASKETS_STRIP:
			parts.append({"line": _line(NAMES[NAME_GASKETS]), "scale": 1.0, "y": 0.0})
		Layout.LOTUS_BOARD:
			parts.append({"line": _line("THE"), "scale": LOTUS_THE, "y": 1.0 + LOTUS_GAP})
			parts.append({"line": _line("BRASS LOTUS"), "scale": 1.0, "y": 0.0})
		Layout.GASKETS_BLADE, Layout.LOTUS_BLADE:
			# One letter after another down the blade, each centred.
			var y: float = 0.0
			var words: Array[String] = ["THE", "BRASS", "LOTUS"]
			if layout == Layout.GASKETS_BLADE:
				words = ["GASKET'S"]
			for word: String in words:
				for ch: String in word:
					parts.append({"line": _line(ch), "scale": 1.0, "y": y, "centre": true})
					y -= BLADE_PITCH
				y -= BLADE_WORD_GAP
	return _compose(parts)


## Lines laid out as `parts` ({"line", "scale", "y" (the line's baseline), "centre" (or its x start 0)}) into
## one layout, centred on the origin by its bounding box.
static func _compose(parts: Array[Dictionary]) -> Dictionary:
	var verts := PackedVector3Array()
	var widest: float = 0.0
	for p: Dictionary in parts:
		widest = maxf(widest, (p["line"]["size"] as Vector2).x * float(p["scale"]))
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p: Dictionary in parts:
		var line: Dictionary = p["line"]
		var s: float = p["scale"]
		var width: float = (line["size"] as Vector2).x * s
		# Lines are centred on each other (a letter on its own is centred over its pitch).
		var x0: float = (widest - width) * 0.5
		var offset := Vector3(x0, float(p["y"]), 0.0)
		for v: Vector3 in line["verts"]:
			var w := Vector3(v.x * s, v.y * s, 0.0) + offset
			verts.append(w)
			lo = Vector2(minf(lo.x, w.x), minf(lo.y, w.y))
			hi = Vector2(maxf(hi.x, w.x), maxf(hi.y, w.y))
	if verts.is_empty():
		return {"verts": verts, "size": Vector2.ZERO}
	var centre := Vector3((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5, 0.0)
	for i: int in verts.size():
		verts[i] -= centre
	return {"verts": verts, "size": hi - lo}


## A line of text as clockwise triangles, x from 0 and y up from the baseline, in cap heights. Cached.
static func _line(text: String) -> Dictionary:
	var found: Variant = _lines.get(text)
	if found != null:
		return found
	_measure()
	var out := {"verts": PackedVector3Array(), "size": Vector2.ZERO}
	if _cap <= 0.0:
		_lines[text] = out
		return out
	var raw: Dictionary = _triangles(text)
	var verts: PackedVector3Array = raw["verts"]
	if verts.is_empty():
		_lines[text] = out
		return out
	var x_min: float = INF
	var x_max: float = -INF
	for v: Vector3 in verts:
		x_min = minf(x_min, v.x)
		x_max = maxf(x_max, v.x)
	var norm := PackedVector3Array()
	norm.resize(verts.size())
	var inv: float = 1.0 / _cap
	for i: int in verts.size():
		norm[i] = Vector3((verts[i].x - x_min) * inv, (verts[i].y - _baseline) * inv, 0.0)
	out = {"verts": norm, "size": Vector2((x_max - x_min) * inv, 1.0)}
	_lines[text] = out
	return out


## The font's baseline and capital height, from an H.
static func _measure() -> void:
	if _cap > 0.0:
		return
	var verts: PackedVector3Array = _triangles("H")["verts"]
	if verts.is_empty():
		return
	var lo: float = INF
	var hi: float = -INF
	for v: Vector3 in verts:
		lo = minf(lo, v.y)
		hi = maxf(hi, v.y)
	_baseline = lo
	_cap = hi - lo


## `text` through TextMesh: unindexed triangles wound clockwise seen from +z (the kit's front faces), in
## the mesh's own units.
static func _triangles(text: String) -> Dictionary:
	var font := load(FONT_PATH) as Font
	if font == null:
		return {"verts": PackedVector3Array()}
	var variation := FontVariation.new()
	variation.base_font = font
	variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): FONT_WEIGHT}
	var tm := TextMesh.new()
	tm.font = variation
	tm.font_size = FONT_SIZE
	tm.pixel_size = PIXEL_SIZE
	tm.depth = 0.0
	tm.curve_step = CURVE_STEP
	tm.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tm.text = text
	var arrays: Array = tm.get_mesh_arrays()
	if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null:
		return {"verts": PackedVector3Array()}
	var src: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var verts := PackedVector3Array()
	var count: int = index.size() if not index.is_empty() else src.size()
	verts.resize(count - count % 3)
	for t: int in count / 3:
		var a: Vector3 = src[index[t * 3]] if not index.is_empty() else src[t * 3]
		var b: Vector3 = src[index[t * 3 + 1]] if not index.is_empty() else src[t * 3 + 1]
		var c: Vector3 = src[index[t * 3 + 2]] if not index.is_empty() else src[t * 3 + 2]
		# Clockwise seen from +z has a negative z in (b - a) x (c - a).
		if (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x) > 0.0:
			var swap: Vector3 = b
			b = c
			c = swap
		verts[t * 3] = Vector3(a.x, a.y, 0.0)
		verts[t * 3 + 1] = Vector3(b.x, b.y, 0.0)
		verts[t * 3 + 2] = Vector3(c.x, c.y, 0.0)
	return {"verts": verts}

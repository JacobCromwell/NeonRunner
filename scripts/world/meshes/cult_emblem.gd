class_name CultEmblem
extends RefCounted
## D7: cult emblem and colour options (GDD §5 "The cult", §9.10 Resonator).
## Four options (A-D), each hand-authored as 2D vector geometry — thick strokes (bars, rings, discs)
## and small filled convex polygons — in a unit square from (-0.5, -0.5) to (0.5, 0.5), facing +Z.
## Deterministic: no RNG, no external assets. One geometry, two builders:
##   build_mesh()     a flat ArrayMesh at any metre size, following the mesh kit's vertex
##                    convention (mesh_kit.gd, kit_solid.gdshader): COLOR.a = glow, 0 for a lit
##                    surface (paint, brushed metal, the Golden Zone's gold), > 0 for an emissive
##                    one (a neon ad).
##   build_texture()  a rasterised ImageTexture at any pixel size, for decals, ads and UI.
## default_scheme() gives each option's own neon (glowing) and metal (non-glowing) colours, kept
## clear of every hazard hue and the UI accents while glowing (checked by
## tests/suites/test_cult_emblem.gd against GreyboxSkin and UiTheme.style()). GOLD_COLOR and
## GOLD_ACCENT_COLOR are shared by every option: in the Golden Zone gold is reflective metal, never
## a glow (GDD §5, §11), so every option reads the same there and only the shape is compared.
##
## The chosen option lives in data/world/cult_emblem_choice.tres (CultEmblemChoice): the owner chose
## B, the Convergent Triad (September 26, 2026; GDD §5). The comparison sheet is
## tools/showcase/cult_emblem_sheet.tscn.

enum Option { A, B, C, D }

const OPTION_COUNT: int = 4
const OPTION_LETTERS: PackedStringArray = ["A", "B", "C", "D"]
const OPTION_TITLES: PackedStringArray = ["Broadcast Halo", "Convergent Triad", "Aperture Mark", "Signal Spire"]

## The Golden Zone's gold and its red inset gem: reflective metal, never emissive (GDD §5, §11).
## Shared by every option so the comparison sheet's gold-relief panel compares shapes, not colours.
const GOLD_COLOR := Color(0.80, 0.64, 0.30)
const GOLD_ACCENT_COLOR := Color(0.55, 0.10, 0.09)

static var _geometry_cache: Dictionary = {}
static var _mesh_cache: Dictionary = {}


static func option_letter(option: int) -> String:
	return OPTION_LETTERS[_clamp_option(option)]


static func option_title(option: int) -> String:
	return OPTION_TITLES[_clamp_option(option)]


## Each option's own look: `neon`/`neon_accent` for a glowing ad (kept clear of hazard and UI
## hues), `metal`/`metal_accent` for non-glowing paint or plating elsewhere in the zone.
static func default_scheme(option: int) -> Dictionary:
	match _clamp_option(option):
		Option.A:
			return {"neon": Color(0.86, 0.93, 0.98), "neon_accent": Color(0.97, 0.99, 1.0),
				"metal": Color(0.58, 0.61, 0.66), "metal_accent": Color(0.78, 0.80, 0.84)}
		Option.B:
			return {"neon": Color(1.0, 0.93, 0.82), "neon_accent": Color(1.0, 0.97, 0.90),
				"metal": Color(0.52, 0.40, 0.24), "metal_accent": Color(0.72, 0.58, 0.38)}
		Option.C:
			return {"neon": Color(0.145, 0.262, 0.850), "neon_accent": Color(0.52, 0.59, 0.95),
				"metal": Color(0.32, 0.34, 0.39), "metal_accent": Color(0.60, 0.63, 0.68)}
		_:
			return {"neon": Color(0.61, 0.36, 0.66), "neon_accent": Color(0.81, 0.61, 0.85),
				"metal": Color(0.34, 0.24, 0.30), "metal_accent": Color(0.60, 0.46, 0.56)}


# --- Geometry ------------------------------------------------------------------------------
# Two primitive kinds, in the -0.5..0.5 square (+X right, +Y up): a "stroke" (a thick polyline;
# one point alone is a filled disc of that width) and a "poly" (a filled polygon, its points listed
# counter-clockwise and star-shaped from the first one — every other point visible from it without
# crossing an edge — so simple fan triangulation is exact; a convex polygon always qualifies, and so
# does e.g. a notched dart whose notch stays "visible" from its tip). `accent` picks the option's
# small secondary detail.

## The option's parts (cached; never mutate the arrays this returns).
static func geometry(option: int) -> Array[Dictionary]:
	var key: int = _clamp_option(option)
	if not _geometry_cache.has(key):
		var built: Array[Dictionary]
		match key:
			Option.A: built = _geometry_a()
			Option.B: built = _geometry_b()
			Option.C: built = _geometry_c()
			_: built = _geometry_d()
		_geometry_cache[key] = built
	return _geometry_cache[key]


## A. Broadcast Halo: a core with three broken concentric rings, their gaps rotated apart, echoing
## the Resonator's own halos and its three-note chime (GDD §9.10). Reads as a generic signal/network
## mark, so it hides easily in a corporate wordmark; in the Golden Zone it becomes a gold sunburst
## medallion with a red core stone.
static func _geometry_a() -> Array[Dictionary]:
	var parts: Array[Dictionary] = []
	parts.append(_stroke(PackedVector2Array([Vector2.ZERO]), 0.15, true))
	parts.append(_stroke(_arc_points(Vector2.ZERO, 0.19, deg_to_rad(15.0), deg_to_rad(315.0)), 0.05))
	parts.append(_stroke(_arc_points(Vector2.ZERO, 0.305, deg_to_rad(55.0), deg_to_rad(355.0)), 0.045))
	parts.append(_stroke(_arc_points(Vector2.ZERO, 0.42, deg_to_rad(95.0), deg_to_rad(395.0)), 0.04))
	return parts


## B. Convergent Triad: three notched, fletched arrows (a sharp tip near the centre, a concave
## notch at the outer, feathered end) with 3-fold symmetry, converging on a shared vanishing point.
## Reads as a generic convergence/sync mark (the kind logistics and finance brands use), so three
## arrows pointing together never look out of place. The notch keeps its silhouette clearly asymmetric
## and un-diamond-like (unlike a plain kite or rhombus) and its sharp point, rather than a broad
## rounded blade around a hub, keeps it well clear of the ionizing-radiation trefoil. In the Golden
## Zone the arrows become polished gold, meeting at a small red centre stone like a pinned medallion.
static func _geometry_b() -> Array[Dictionary]:
	var parts: Array[Dictionary] = []
	var blade := PackedVector2Array([Vector2(0.0, 0.06), Vector2(0.13, 0.42), Vector2(0.0, 0.34), Vector2(-0.13, 0.42)])
	for k: int in 3:
		parts.append(_poly(_rotate_points(blade, TAU * float(k) / 3.0)))
	parts.append(_stroke(PackedVector2Array([Vector2.ZERO]), 0.075, true))
	return parts


## C. Aperture Mark: seven overlapping blade shapes around a small lens-ring opening, like a camera
## aperture or iris (never an eye; seven blades is a common real lens-aperture count, and an odd
## fold keeps this off both the hexagram's and the pentagram's symmetry). Reads as a generic
## vision/focus/broadcast-lens tech mark, fitting camouflage for a cult that is always watching and
## broadcasting. In the Golden Zone the blades become gold aperture blades around a garnet-red lens.
static func _geometry_c() -> Array[Dictionary]:
	var parts: Array[Dictionary] = []
	var blades: int = 7
	var delta: float = 0.4
	for k: int in blades:
		var theta: float = TAU * float(k) / float(blades)
		var outer: Vector2 = Vector2(cos(theta), sin(theta)) * 0.46
		var inner_plus: Vector2 = Vector2(cos(theta + delta), sin(theta + delta)) * 0.10
		var inner_minus: Vector2 = Vector2(cos(theta - delta), sin(theta - delta)) * 0.10
		parts.append(_poly(PackedVector2Array([outer, inner_plus, inner_minus])))
	parts.append(_stroke(_arc_points(Vector2.ZERO, 0.075, 0.0, TAU), 0.03, true))
	return parts


## D. Signal Spire: a slim vertical spire with a beacon tip, echoing the Resonator's own silhouette,
## beside three short bars of increasing length climbing just one side — a "signal bars" glyph, not
## a crossbar: the bars never cross the spire's centreline, so at any size it reads as a signal
## strength icon, never a multi-barred cross. The most throwaway-looking of the four, easiest to
## bury in a tiny corner of a logo. In the Golden Zone it becomes a tall gold pillar relief with a
## single red accent, fitting an archway keystone.
static func _geometry_d() -> Array[Dictionary]:
	var parts: Array[Dictionary] = []
	parts.append(_stroke(PackedVector2Array([Vector2(0.0, -0.46), Vector2(0.0, 0.40)]), 0.05))
	parts.append(_stroke(PackedVector2Array([Vector2(0.025, -0.24), Vector2(0.14, -0.24)]), 0.04))
	parts.append(_stroke(PackedVector2Array([Vector2(0.025, -0.02), Vector2(0.22, -0.02)]), 0.04))
	parts.append(_stroke(PackedVector2Array([Vector2(0.025, 0.20), Vector2(0.30, 0.20)]), 0.04))
	parts.append(_stroke(PackedVector2Array([Vector2(0.0, 0.45)]), 0.08, true))
	return parts


static func _stroke(points: PackedVector2Array, width: float, accent: bool = false) -> Dictionary:
	return {"kind": "stroke", "points": points, "width": width, "accent": accent}


static func _poly(points: PackedVector2Array, accent: bool = false) -> Dictionary:
	return {"kind": "poly", "points": points, "accent": accent}


## Points around a circle centred on `center`, radius `r`, from angle `a0` to `a1` (radians;
## a1 - a0 = TAU for a full closed loop). Enough segments that the facets never show at any size.
static func _arc_points(center: Vector2, r: float, a0: float, a1: float) -> PackedVector2Array:
	var segments: int = maxi(8, roundi(48.0 * absf(a1 - a0) / TAU))
	var pts := PackedVector2Array()
	pts.resize(segments + 1)
	for i: int in segments + 1:
		var a: float = lerpf(a0, a1, float(i) / float(segments))
		pts[i] = center + Vector2(cos(a), sin(a)) * r
	return pts


static func _rotate_points(points: PackedVector2Array, angle: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(points.size())
	var c: float = cos(angle)
	var s: float = sin(angle)
	for i: int in points.size():
		var p: Vector2 = points[i]
		out[i] = Vector2(p.x * c - p.y * s, p.x * s + p.y * c)
	return out


static func _clamp_option(option: int) -> int:
	return clampi(option, 0, OPTION_COUNT - 1)


# --- Mesh --------------------------------------------------------------------------------------

## A flat emblem mesh, `size` metres wide and tall, centred on the origin and facing +Z. Vertex
## colours follow the mesh kit convention (COLOR.a = glow): `glow_amount` 0 for a lit, non-glowing
## surface (paint, brushed metal, the Golden Zone's gold — pass GOLD_COLOR/GOLD_ACCENT_COLOR there)
## or > 0 for an emissive one (a neon ad). `accent_color` picks out the option's small secondary
## detail. Cached by its arguments, like the rest of the mesh kit (mesh_kit.gd).
static func build_mesh(option: int, size: float, color: Color, accent_color: Color, glow_amount: float,
		solid_material: Material) -> ArrayMesh:
	var key: int = _clamp_option(option)
	var id: String = "cult_%d_%s_%s_%s_%s_%d" % [key, size, color, accent_color, glow_amount,
		solid_material.get_instance_id()]
	if _mesh_cache.has(id):
		return _mesh_cache[id]
	var batch := MeshBatch.new()
	var layer: MeshLayer = batch.layer(solid_material)
	for part: Dictionary in geometry(key):
		var c: Color = Color(accent_color if part["accent"] else color, glow_amount)
		_emit_part(layer, part, size, c)
	var mesh: ArrayMesh = batch.to_mesh()
	_mesh_cache[id] = mesh
	return mesh


static func _emit_part(layer: MeshLayer, part: Dictionary, size: float, color: Color) -> void:
	var points: PackedVector2Array = _scale_points(part["points"], size)
	if part["kind"] == "poly":
		_emit_fan(layer, points, color)
		return
	var half_w: float = part["width"] * size * 0.5
	if points.size() == 1:
		_emit_disc(layer, points[0], half_w, color)
	else:
		for i: int in points.size() - 1:
			_emit_segment_quad(layer, points[i], points[i + 1], half_w, color)


static func _scale_points(points: PackedVector2Array, size: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(points.size())
	for i: int in points.size():
		out[i] = points[i] * size
	return out


## A polygon's points, listed counter-clockwise and star-shaped from the first one, fan-
## triangulated from that point (see the "poly" note above).
static func _emit_fan(layer: MeshLayer, points: PackedVector2Array, color: Color) -> void:
	for i: int in range(1, points.size() - 1):
		_emit_triangle(layer, points[0], points[i], points[i + 1], color)


static func _emit_disc(layer: MeshLayer, center: Vector2, r: float, color: Color, sides: int = 28) -> void:
	for k: int in sides:
		var a0: float = TAU * float(k) / float(sides)
		var a1: float = TAU * float(k + 1) / float(sides)
		var p0: Vector2 = center + Vector2(cos(a0), sin(a0)) * r
		var p1: Vector2 = center + Vector2(cos(a1), sin(a1)) * r
		_emit_triangle(layer, center, p0, p1, color)


## A thick segment from `a` to `b` (flat caps; consecutive segments of one stroke share endpoints,
## so a many-segment ring or arc reads solid at any practical size).
static func _emit_segment_quad(layer: MeshLayer, a: Vector2, b: Vector2, half_w: float, color: Color) -> void:
	var dir: Vector2 = b - a
	if dir.length_squared() < 1e-12:
		return
	dir = dir.normalized()
	var perp: Vector2 = Vector2(-dir.y, dir.x) * half_w
	var a1: Vector2 = a + perp
	var a2: Vector2 = a - perp
	var b1: Vector2 = b + perp
	var b2: Vector2 = b - perp
	_emit_triangle(layer, a1, a2, b2, color)
	_emit_triangle(layer, a1, b2, b1, color)


## Appends one triangle given in standard counter-clockwise 2D order (a -> b -> c turns left) at
## z = 0, flipped to the mesh kit's clockwise-front winding (mesh_layer.gd) so it faces +Z.
static func _emit_triangle(layer: MeshLayer, a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	layer.verts.append_array(PackedVector3Array([Vector3(a.x, a.y, 0.0), Vector3(c.x, c.y, 0.0), Vector3(b.x, b.y, 0.0)]))
	layer.colors.append_array(MeshKit.filled_colors(color, 3))
	layer.uvs.append_array(PackedVector2Array([Vector2.ZERO, Vector2.ONE, Vector2(1.0, 0.0)]))
	layer.uv2s.append_array(MeshKit.filled_uv2(Vector2.ZERO, 3))


# --- Texture -------------------------------------------------------------------------------------

## A rasterised emblem, `pixels` square, in the same geometry as build_mesh(): `color` (or
## `accent_color`, drawn on top) over `bg_color` (alpha 0 for a transparent decal). `glow` adds a
## soft bloom around the mark, baked into the pixels, for a neon-ad look that reads even without the
## engine's own bloom; without it, the edge is crisp, for a logo, print or UI icon. `color` and
## `accent_color` are treated as opaque paint. Deterministic: the same arguments always rasterise
## identically (tests/suites/test_cult_emblem.gd checks this at several sizes).
static func build_image(option: int, pixels: int, color: Color, accent_color: Color, bg_color: Color,
		glow: bool = false) -> Image:
	var img := Image.create(maxi(pixels, 1), maxi(pixels, 1), false, Image.FORMAT_RGBA8)
	var main_parts: Array[Dictionary] = []
	var accent_parts: Array[Dictionary] = []
	for part: Dictionary in geometry(option):
		if part["accent"]:
			accent_parts.append(part)
		else:
			main_parts.append(part)
	var px: float = 1.0 / float(maxi(pixels, 1))
	for y: int in img.get_height():
		for x: int in img.get_width():
			var p := Vector2((float(x) + 0.5) * px - 0.5, 0.5 - (float(y) + 0.5) * px)
			var col: Color = bg_color
			col = _paint(col, p, main_parts, color, px, glow)
			col = _paint(col, p, accent_parts, accent_color, px, glow)
			img.set_pixel(x, y, col)
	return img


static func build_texture(option: int, pixels: int, color: Color, accent_color: Color, bg_color: Color,
		glow: bool = false) -> ImageTexture:
	return ImageTexture.create_from_image(build_image(option, pixels, color, accent_color, bg_color, glow))


static func _paint(base: Color, p: Vector2, parts: Array[Dictionary], layer_color: Color, px: float, glow: bool) -> Color:
	if parts.is_empty():
		return base
	var d: float = INF
	for part: Dictionary in parts:
		d = minf(d, _part_distance(p, part))
	var coverage: float = clampf(0.5 - d / px, 0.0, 1.0)
	if glow:
		var halo: float = exp(-maxf(d, 0.0) / (px * 6.0)) * 0.85
		coverage = maxf(coverage, halo)
	if coverage <= 0.0:
		return base
	var out: Color = base.lerp(Color(layer_color.r, layer_color.g, layer_color.b, base.a), coverage)
	out.a = base.a + coverage * (1.0 - base.a)
	return out


static func _part_distance(p: Vector2, part: Dictionary) -> float:
	if part["kind"] == "poly":
		return _polygon_distance(p, part["points"])
	var points: PackedVector2Array = part["points"]
	var half_w: float = part["width"] * 0.5
	if points.size() == 1:
		return p.distance_to(points[0]) - half_w
	var d: float = INF
	for i: int in points.size() - 1:
		d = minf(d, _segment_distance(p, points[i], points[i + 1]) - half_w)
	return d


static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Signed distance to a polygon boundary (negative inside): the nearest edge, in or out, by the
## standard min-edge-distance-plus-parity trick, so it works whatever the winding.
static func _polygon_distance(p: Vector2, points: PackedVector2Array) -> float:
	var n: int = points.size()
	var d: float = INF
	var inside: bool = false
	var j: int = n - 1
	for i: int in n:
		var a: Vector2 = points[j]
		var b: Vector2 = points[i]
		d = minf(d, _segment_distance(p, a, b))
		if (a.y > p.y) != (b.y > p.y):
			var t: float = (p.y - a.y) / (b.y - a.y)
			if p.x < a.x + t * (b.x - a.x):
				inside = not inside
		j = i
	return -d if inside else d

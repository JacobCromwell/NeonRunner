class_name DoodadPaint
extends RefCounted
## A small CPU painter for the zone doodads' picture cards (tools/asset_gen/doodad_art_gen.gd, owner's
## request October 9, 2026: "keep them as a cube, but draw on it pictures that look like the object").
## One canvas is one picture: a face of a doodad's box (or a card inside it), sized in metres. Shapes
## are given in metres from the picture's bottom-left corner, +y up, and drawn at SS times the final
## resolution; finish() averages that down, so every edge comes out anti-aliased (a smooth alpha edge
## for the cutouts too). Nothing here uses the GPU, so the generator runs headless.
##
## Fills are opaque unless the colour's alpha is below 1 (then they blend over what's there); erase_*
## punches transparent holes (the open air of a stall, a car's empty window frames).

## Supersampling factor (each final pixel averages SS × SS painted ones).
const SS: int = 4

var width_m: float
var height_m: float
## The finished picture's size in pixels.
var out_size: Vector2i
## The supersampled canvas.
var image: Image

var _w: int
var _h: int
## Full-width one-row images of a colour, for blending translucent spans (blend_rect needs a source).
var _rows: Dictionary = {}


func _init(p_width_m: float, p_height_m: float, px_per_m: float) -> void:
	width_m = p_width_m
	height_m = p_height_m
	out_size = Vector2i(maxi(roundi(width_m * px_per_m), 4), maxi(roundi(height_m * px_per_m), 4))
	_w = out_size.x * SS
	_h = out_size.y * SS
	image = Image.create_empty(_w, _h, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))


# --- Coordinates ---------------------------------------------------------------------------------

func px(x: float) -> float:
	return x / width_m * float(_w)


func py(y: float) -> float:
	return (1.0 - y / height_m) * float(_h)


func to_px(p: Vector2) -> Vector2:
	return Vector2(px(p.x), py(p.y))


## One painted pixel's size in metres (for hairlines that must survive the downsampling).
func pixel_m() -> float:
	return width_m / float(out_size.x)


# --- Fills ----------------------------------------------------------------------------------------

func clear(c: Color = Color(0, 0, 0, 0)) -> void:
	image.fill(c)


## A rectangle from (x0, y0) to (x1, y1), in metres.
func rect(x0: float, y0: float, x1: float, y1: float, c: Color) -> void:
	var ax: int = clampi(roundi(px(minf(x0, x1))), 0, _w)
	var bx: int = clampi(roundi(px(maxf(x0, x1))), 0, _w)
	var ay: int = clampi(roundi(py(maxf(y0, y1))), 0, _h)
	var by: int = clampi(roundi(py(minf(y0, y1))), 0, _h)
	if bx <= ax or by <= ay:
		return
	if c.a >= 0.999:
		image.fill_rect(Rect2i(ax, ay, bx - ax, by - ay), c)
	else:
		var row: Image = _row(c)
		for y: int in range(ay, by):
			image.blend_rect(row, Rect2i(0, 0, bx - ax, 1), Vector2i(ax, y))


## Makes the rectangle transparent (a hole: open air).
func erase_rect(x0: float, y0: float, x1: float, y1: float) -> void:
	var ax: int = clampi(roundi(px(minf(x0, x1))), 0, _w)
	var bx: int = clampi(roundi(px(maxf(x0, x1))), 0, _w)
	var ay: int = clampi(roundi(py(maxf(y0, y1))), 0, _h)
	var by: int = clampi(roundi(py(minf(y0, y1))), 0, _h)
	if bx > ax and by > ay:
		image.fill_rect(Rect2i(ax, ay, bx - ax, by - ay), Color(0, 0, 0, 0))


## A filled polygon (any simple polygon; even-odd rule), points in metres.
func poly(points: PackedVector2Array, c: Color) -> void:
	_scan(points, c, false)


## Makes the polygon transparent.
func erase_poly(points: PackedVector2Array) -> void:
	_scan(points, Color(0, 0, 0, 0), true)


func circle(cx: float, cy: float, r: float, c: Color, segments: int = 28) -> void:
	poly(ellipse_points(cx, cy, r, r, segments), c)


func ellipse(cx: float, cy: float, rx: float, ry: float, c: Color, segments: int = 32) -> void:
	poly(ellipse_points(cx, cy, rx, ry, segments), c)


func erase_ellipse(cx: float, cy: float, rx: float, ry: float, segments: int = 32) -> void:
	erase_poly(ellipse_points(cx, cy, rx, ry, segments))


## A rectangle with rounded corners of radius `r`.
func round_rect(x0: float, y0: float, x1: float, y1: float, r: float, c: Color) -> void:
	poly(round_rect_points(x0, y0, x1, y1, r), c)


## A thick straight line from a to b (metres), square ends.
func line(a: Vector2, b: Vector2, w: float, c: Color) -> void:
	var d: Vector2 = b - a
	if d.length() < 1e-5:
		return
	var n: Vector2 = Vector2(-d.y, d.x).normalized() * (w * 0.5)
	poly(PackedVector2Array([a + n, b + n, b - n, a - n]), c)


## Thick lines through `points` (closed: back to the first), with round joints.
func polyline(points: PackedVector2Array, w: float, c: Color, closed: bool = false) -> void:
	var count: int = points.size()
	var segs: int = count if closed else count - 1
	for i: int in segs:
		line(points[i], points[(i + 1) % count], w, c)
	if w > pixel_m() * 1.5:
		for p: Vector2 in points:
			circle(p.x, p.y, w * 0.5, c, 10)


## A vertical gradient over the rectangle, `bottom` to `top`.
func vgrad(x0: float, y0: float, x1: float, y1: float, bottom: Color, top: Color) -> void:
	var ax: int = clampi(roundi(px(minf(x0, x1))), 0, _w)
	var bx: int = clampi(roundi(px(maxf(x0, x1))), 0, _w)
	var ay: int = clampi(roundi(py(maxf(y0, y1))), 0, _h)
	var by: int = clampi(roundi(py(minf(y0, y1))), 0, _h)
	if bx <= ax or by <= ay:
		return
	for y: int in range(ay, by):
		var t: float = 1.0 - (float(y - ay) + 0.5) / float(by - ay)
		var c: Color = bottom.lerp(top, t)
		if c.a >= 0.999:
			image.fill_rect(Rect2i(ax, y, bx - ax, 1), c)
		else:
			image.blend_rect(_row(c), Rect2i(0, 0, bx - ax, 1), Vector2i(ax, y))


## A horizontal gradient over the rectangle, `left` to `right`.
func hgrad(x0: float, y0: float, x1: float, y1: float, left: Color, right: Color) -> void:
	var ax: int = clampi(roundi(px(minf(x0, x1))), 0, _w)
	var bx: int = clampi(roundi(px(maxf(x0, x1))), 0, _w)
	var ay: int = clampi(roundi(py(maxf(y0, y1))), 0, _h)
	var by: int = clampi(roundi(py(minf(y0, y1))), 0, _h)
	if bx <= ax or by <= ay:
		return
	for x: int in range(ax, bx):
		var t: float = (float(x - ax) + 0.5) / float(bx - ax)
		var c: Color = left.lerp(right, t)
		if c.a >= 0.999:
			image.fill_rect(Rect2i(x, ay, 1, by - ay), c)
		else:
			for y: int in range(ay, by):
				image.blend_rect(_row(c), Rect2i(0, 0, 1, 1), Vector2i(x, y))


## Even stripes over the rectangle, alternating `colors`, each `width` metres, vertical (stripes
## side by side across x) or horizontal (stacked up y).
func stripes(x0: float, y0: float, x1: float, y1: float, colors: Array[Color], width: float, vertical: bool = true) -> void:
	var i: int = 0
	if vertical:
		var x: float = x0
		while x < x1 - 1e-5:
			rect(x, y0, minf(x + width, x1), y1, colors[i % colors.size()])
			x += width
			i += 1
	else:
		var y: float = y0
		while y < y1 - 1e-5:
			rect(x0, y, x1, minf(y + width, y1), colors[i % colors.size()])
			y += width
			i += 1


## Grime and wear: `count` small translucent blots of `c` scattered over the rectangle, from a rseed
## (the same every run). Only where the canvas already has paint (it never fills a hole).
func speckle(x0: float, y0: float, x1: float, y1: float, c: Color, count: int, r_min: float, r_max: float, rseed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	for i: int in count:
		var cx: float = rng.randf_range(x0, x1)
		var cy: float = rng.randf_range(y0, y1)
		var r: float = rng.randf_range(r_min, r_max)
		if _painted(cx, cy):
			ellipse(cx, cy, r, r * rng.randf_range(0.55, 1.0), c, 12)


## A soft, uneven tone over the rectangle: about one blot per `cell` metres square, each lighter or
## darker by up to `amount` (0–1) from a rseed, round and overlapping so it never reads as a grid of
## squares. Gives flat paint a hand-made, weathered surface. Only over paint.
func mottle(x0: float, y0: float, x1: float, y1: float, cell: float, amount: float, rseed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	var y: float = y0
	while y < y1 - 1e-5:
		var x: float = x0
		while x < x1 - 1e-5:
			var v: float = rng.randf_range(-amount, amount)
			var cx: float = x + cell * rng.randf_range(0.0, 1.0)
			var cy: float = y + cell * rng.randf_range(0.0, 1.0)
			if _painted(cx, cy):
				var tint: Color = Color(1, 1, 1, v) if v > 0.0 else Color(0, 0, 0, -v)
				var r: float = cell * rng.randf_range(0.5, 0.9)
				ellipse(cx, cy, r, r * rng.randf_range(0.6, 1.0), tint, 12)
			x += cell
		y += cell


## Blends `c` (its alpha the strength) over the rectangle only where the canvas already has paint:
## shading across a shape that never fills the air around it.
func tint_over(x0: float, y0: float, x1: float, y1: float, c: Color) -> void:
	var ax: int = clampi(roundi(px(minf(x0, x1))), 0, _w)
	var bx: int = clampi(roundi(px(maxf(x0, x1))), 0, _w)
	var ay: int = clampi(roundi(py(maxf(y0, y1))), 0, _h)
	var by: int = clampi(roundi(py(minf(y0, y1))), 0, _h)
	for y: int in range(ay, by):
		for x: int in range(ax, bx):
			var d: Color = image.get_pixel(x, y)
			if d.a > 0.5:
				image.set_pixel(x, y, Color(lerpf(d.r, c.r, c.a), lerpf(d.g, c.g, c.a), lerpf(d.b, c.b, c.a), d.a))


## True if the canvas has paint at (x, y) (metres).
func painted(x: float, y: float) -> bool:
	return _painted(x, y)


func _painted(x: float, y: float) -> bool:
	var ix: int = clampi(int(px(x)), 0, _w - 1)
	var iy: int = clampi(int(py(y)), 0, _h - 1)
	return image.get_pixel(ix, iy).a > 0.5


# --- Shapes --------------------------------------------------------------------------------------

static func ellipse_points(cx: float, cy: float, rx: float, ry: float, segments: int = 32) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in segments:
		var a: float = TAU * float(i) / float(segments)
		out.append(Vector2(cx + cos(a) * rx, cy + sin(a) * ry))
	return out


static func round_rect_points(x0: float, y0: float, x1: float, y1: float, r: float, arc: int = 5) -> PackedVector2Array:
	var rr: float = minf(r, minf((x1 - x0) * 0.5, (y1 - y0) * 0.5))
	var out := PackedVector2Array()
	var corners: Array[Vector2] = [Vector2(x1 - rr, y1 - rr), Vector2(x0 + rr, y1 - rr), Vector2(x0 + rr, y0 + rr), Vector2(x1 - rr, y0 + rr)]
	for k: int in 4:
		for i: int in arc + 1:
			var a: float = PI * 0.5 * (float(k) + float(i) / float(arc))
			out.append(corners[k] + Vector2(cos(a), sin(a)) * rr)
	return out


## An arc of a ring (a band `w` wide, centred on radius r) from angle a0 to a1 (radians).
static func arc_points(cx: float, cy: float, r: float, w: float, a0: float, a1: float, segments: int = 16) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in segments + 1:
		var a: float = lerpf(a0, a1, float(i) / float(segments))
		out.append(Vector2(cx + cos(a) * (r + w * 0.5), cy + sin(a) * (r + w * 0.5)))
	for i: int in range(segments, -1, -1):
		var a: float = lerpf(a0, a1, float(i) / float(segments))
		out.append(Vector2(cx + cos(a) * (r - w * 0.5), cy + sin(a) * (r - w * 0.5)))
	return out


# --- Finishing ------------------------------------------------------------------------------------

## The finished picture at out_size: colours bled into the transparent pixels (so mipmaps and the
## averaging never darken an edge), then SS × SS pixels averaged into one.
func finish() -> Image:
	var out: Image = image.duplicate() as Image
	out.fix_alpha_edges()
	var w: int = _w
	var h: int = _h
	while w > out_size.x:
		w /= 2
		h /= 2
		out.resize(w, h, Image.INTERPOLATE_BILINEAR)
	if out.get_size() != out_size:
		out.resize(out_size.x, out_size.y, Image.INTERPOLATE_BILINEAR)
	return out


# --- Internals ------------------------------------------------------------------------------------

func _row(c: Color) -> Image:
	var key: int = c.to_rgba32()
	if not _rows.has(key):
		var row := Image.create_empty(_w, 1, false, Image.FORMAT_RGBA8)
		row.fill(c)
		_rows[key] = row
	return _rows[key]


## Scanline fill of `points` (metres) with `c`, or a hole with `erase`.
func _scan(points: PackedVector2Array, c: Color, erase: bool) -> void:
	var n: int = points.size()
	if n < 3:
		return
	var pts := PackedVector2Array()
	pts.resize(n)
	var ymin: float = INF
	var ymax: float = -INF
	for i: int in n:
		pts[i] = to_px(points[i])
		ymin = minf(ymin, pts[i].y)
		ymax = maxf(ymax, pts[i].y)
	var row0: int = clampi(int(floor(ymin)), 0, _h)
	var row1: int = clampi(int(ceil(ymax)), 0, _h)
	var opaque: bool = erase or c.a >= 0.999
	var blend_row: Image = null if opaque else _row(c)
	var xs: Array[float] = []
	for y: int in range(row0, row1):
		var yc: float = float(y) + 0.5
		xs.clear()
		for i: int in n:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[(i + 1) % n]
			if (a.y <= yc and b.y > yc) or (b.y <= yc and a.y > yc):
				xs.append(a.x + (yc - a.y) * (b.x - a.x) / (b.y - a.y))
		if xs.size() < 2:
			continue
		xs.sort()
		var k: int = 0
		while k + 1 < xs.size():
			var x0: int = clampi(int(ceil(xs[k] - 0.5)), 0, _w)
			var x1: int = clampi(int(ceil(xs[k + 1] - 0.5)), 0, _w)
			if x1 > x0:
				if opaque:
					image.fill_rect(Rect2i(x0, y, x1 - x0, 1), c)
				else:
					image.blend_rect(blend_row, Rect2i(0, 0, x1 - x0, 1), Vector2i(x0, y))
			k += 2

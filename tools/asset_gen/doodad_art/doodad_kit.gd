class_name DoodadKit
extends RefCounted
## Shared motifs for the zones' doodad pictures (tools/asset_gen/doodad_art/*_art.gd): outlined
## shapes in the owner's concept art's comic style (flat paint, a shade and a highlight, a dark ink
## line), and the pieces several zones need: planks, corrugated sheet, wheels, scalloped awnings,
## crates, fruit, foliage, see-through window frames. Everything takes metres on a DoodadPaint.
##
## Colour rule (GDD §5, test_doodads): doodads are safe scenery, so nothing here is drawn to read as a
## hazard: no glowing look, no yellow-and-black stripes, no pink crackle, no red, orange, green or cyan
## light. Paint is matte; brightness comes from the scene's light.

## The ink line around shapes, in metres (about 3 pixels at 96 px/m).
const INK_W: float = 0.03


static func ink(base: Color) -> Color:
	return base.darkened(0.72)


## A filled polygon with an ink outline.
static func shape(p: DoodadPaint, pts: PackedVector2Array, fill: Color, line: Color = Color(0, 0, 0, 0), w: float = INK_W) -> void:
	p.poly(pts, fill)
	var l: Color = line if line.a > 0.0 else ink(fill)
	p.polyline(pts, w, l, true)


static func rect_pts(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])


## A filled rounded rectangle with an ink outline.
static func round_rect_shape(p: DoodadPaint, x0: float, y0: float, x1: float, y1: float, r: float, fill: Color) -> void:
	shape(p, DoodadPaint.round_rect_points(x0, y0, x1, y1, r), fill)


## A panel: flat `base`, a lighter band along its top and a darker one along its bottom, inked.
static func panel(p: DoodadPaint, x0: float, y0: float, x1: float, y1: float, base: Color, line: Color = Color(0, 0, 0, 0),
		w: float = INK_W) -> void:
	p.rect(x0, y0, x1, y1, base)
	var band: float = minf((y1 - y0) * 0.14, 0.06)
	p.rect(x0, y1 - band, x1, y1, base.lightened(0.18))
	p.rect(x0, y0, x1, y0 + band, base.darkened(0.25))
	p.polyline(rect_pts(x0, y0, x1, y1), w, line if line.a > 0.0 else ink(base), true)


## A post or beam: a rectangle with a light edge on its left and a shaded edge on its right.
static func post(p: DoodadPaint, x0: float, y0: float, x1: float, y1: float, base: Color) -> void:
	p.rect(x0, y0, x1, y1, base)
	var e: float = (x1 - x0) * 0.22
	p.rect(x0, y0, x0 + e, y1, base.lightened(0.16))
	p.rect(x1 - e, y0, x1, y1, base.darkened(0.25))
	p.polyline(rect_pts(x0, y0, x1, y1), INK_W * 0.8, ink(base), true)


## Horizontal planks over the rectangle, each `h` metres tall, in slightly varied tones from a rseed.
static func planks(p: DoodadPaint, x0: float, y0: float, x1: float, y1: float, base: Color, h: float, rseed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	var y: float = y0
	while y < y1 - 1e-4:
		var top: float = minf(y + h, y1)
		var tone: Color = base.lightened(rng.randf_range(-0.06, 0.08)) if rng.randf() > 0.5 else base.darkened(rng.randf_range(0.0, 0.12))
		p.rect(x0, y, x1, top, tone)
		p.rect(x0, top - 0.012, x1, top, tone.lightened(0.15))
		p.line(Vector2(x0, y), Vector2(x1, y), 0.016, ink(base).lerp(base, 0.35))
		# Nail heads at the ends.
		for nx: float in [x0 + 0.05, x1 - 0.05]:
			if x1 - x0 > 0.2:
				p.circle(nx, (y + top) * 0.5, 0.012, ink(base), 8)
		y = top
	p.polyline(rect_pts(x0, y0, x1, y1), INK_W, ink(base), true)


## Vertical boards (a fence, a door): `w` metres wide each.
static func boards(p: DoodadPaint, x0: float, y0: float, x1: float, y1: float, base: Color, w: float, rseed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	var x: float = x0
	while x < x1 - 1e-4:
		var right: float = minf(x + w, x1)
		var tone: Color = base.darkened(rng.randf_range(0.0, 0.14))
		p.rect(x, y0, right, y1, tone)
		p.rect(x, y0, x + 0.012, y1, tone.lightened(0.12))
		p.line(Vector2(right, y0), Vector2(right, y1), 0.014, ink(base).lerp(base, 0.4))
		x = right
	p.polyline(rect_pts(x0, y0, x1, y1), INK_W, ink(base), true)


## Corrugated sheet metal: ribs every `pitch` metres, vertical (or horizontal), with rust blooms.
static func corrugated(p: DoodadPaint, x0: float, y0: float, x1: float, y1: float, base: Color, pitch: float, vertical: bool,
		rust: Color, rseed: int) -> void:
	p.rect(x0, y0, x1, y1, base)
	if vertical:
		var x: float = x0
		while x < x1:
			p.rect(x, y0, minf(x + pitch * 0.35, x1), y1, base.lightened(0.12))
			p.rect(minf(x + pitch * 0.65, x1), y0, minf(x + pitch, x1), y1, base.darkened(0.18))
			x += pitch
	else:
		var y: float = y0
		while y < y1:
			p.rect(x0, minf(y + pitch * 0.65, y1), x1, minf(y + pitch, y1), base.lightened(0.12))
			p.rect(x0, y, x1, minf(y + pitch * 0.35, y1), base.darkened(0.18))
			y += pitch
	if rust.a > 0.0:
		stains(p, x0, y0, x1, y1, Color(rust, 0.32), int((x1 - x0) * (y1 - y0) * 2.5) + 1, 0.3, rseed)
	p.polyline(rect_pts(x0, y0, x1, y1), INK_W, ink(base), true)


## A wheel with its tyre, rim and hub, centred at (cx, cy).
static func wheel(p: DoodadPaint, cx: float, cy: float, r: float, tyre: Color, rim: Color) -> void:
	p.circle(cx, cy, r, tyre, 32)
	p.polyline(DoodadPaint.ellipse_points(cx, cy, r, r, 32), INK_W, ink(tyre), true)
	p.circle(cx, cy, r * 0.58, rim, 24)
	p.circle(cx, cy, r * 0.58 - 0.02, rim.lightened(0.15), 24)
	p.circle(cx, cy, r * 0.2, rim.darkened(0.35), 16)
	for k: int in 5:
		var a: float = TAU * float(k) / 5.0
		p.circle(cx + cos(a) * r * 0.38, cy + sin(a) * r * 0.38, r * 0.05, rim.darkened(0.45), 8)


## A wheel seen edge-on (from the front or back): a dark tyre block.
static func wheel_edge(p: DoodadPaint, x0: float, x1: float, y0: float, y1: float, tyre: Color) -> void:
	p.round_rect(x0, y0, x1, y1, (x1 - x0) * 0.3, tyre)
	p.rect(x0 + (x1 - x0) * 0.2, y0 + 0.03, x1 - (x1 - x0) * 0.2, y1 - 0.03, tyre.lightened(0.08))
	p.polyline(DoodadPaint.round_rect_points(x0, y0, x1, y1, (x1 - x0) * 0.3), INK_W, ink(tyre), true)


## An awning's valance from x0 to x1 hanging down from y_top by `depth`, its bottom edge scalloped
## (the dips between scallops are open air), in stripes of `colors` each `stripe` metres wide.
static func valance(p: DoodadPaint, x0: float, x1: float, y_top: float, depth: float, colors: Array[Color], stripe: float) -> void:
	var scallop_h: float = depth * 0.32
	var y_band: float = y_top - depth + scallop_h
	p.stripes(x0, y_band, x1, y_top, colors, stripe)
	# The scallops: a half-disc under each stripe pair, the gaps between them left open.
	var count: int = maxi(roundi((x1 - x0) / (stripe * 2.0)), 1)
	var sw: float = (x1 - x0) / float(count)
	for i: int in count:
		var cx: float = x0 + (float(i) + 0.5) * sw
		var c: Color = colors[(i * 2) % colors.size()]
		var pts := PackedVector2Array()
		for k: int in 13:
			var a: float = PI + PI * float(k) / 12.0
			pts.append(Vector2(cx + cos(a) * sw * 0.5, y_band + sin(a) * scallop_h))
		p.poly(pts, c)
		p.polyline(pts, INK_W * 0.8, ink(c), false)
	p.line(Vector2(x0, y_top), Vector2(x1, y_top), INK_W, ink(colors[0]))
	p.line(Vector2(x0, y_band), Vector2(x1, y_band), INK_W * 0.6, ink(colors[0]).lerp(colors[0], 0.3))


## A wooden crate from (x0, y0) to (x1, y1): slats and a dark rim.
static func crate(p: DoodadPaint, x0: float, y0: float, x1: float, y1: float, wood: Color) -> void:
	p.rect(x0, y0, x1, y1, wood)
	var slats: int = 3
	var sh: float = (y1 - y0) / float(slats)
	for i: int in slats:
		var y: float = y0 + sh * float(i)
		p.rect(x0, y + sh * 0.82, x1, y + sh, wood.darkened(0.3))
	p.rect(x0, y0, x0 + 0.03, y1, wood.darkened(0.15))
	p.rect(x1 - 0.03, y0, x1, y1, wood.darkened(0.15))
	p.polyline(rect_pts(x0, y0, x1, y1), INK_W * 0.8, ink(wood), true)


## A heap of round fruit or vegetables on top of y (between x0 and x1), `colors` mixed by a rseed.
static func produce(p: DoodadPaint, x0: float, x1: float, y: float, r: float, colors: Array[Color], rseed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	var rows: int = 2
	for row: int in rows:
		var count: int = maxi(int((x1 - x0) / (r * 2.0)) - row, 1)
		var span: float = float(count) * r * 2.0
		var start: float = (x0 + x1) * 0.5 - span * 0.5 + r
		for i: int in count:
			var c: Color = colors[rng.randi_range(0, colors.size() - 1)]
			var cx: float = start + float(i) * r * 2.0 + rng.randf_range(-r * 0.15, r * 0.15)
			var cy: float = y + r + float(row) * r * 1.5
			p.circle(cx, cy, r, c, 16)
			p.circle(cx - r * 0.3, cy + r * 0.3, r * 0.3, c.lightened(0.3), 10)
			p.polyline(DoodadPaint.ellipse_points(cx, cy, r, r, 16), INK_W * 0.55, ink(c), true)


## A see-through window: the opening is erased (open air or a view inside), with a frame `fw` wide.
static func window_hole(p: DoodadPaint, x0: float, y0: float, x1: float, y1: float, frame: Color, fw: float) -> void:
	p.erase_rect(x0 + fw, y0 + fw, x1 - fw, y1 - fw)
	for r: PackedVector2Array in [rect_pts(x0, y0, x1, y0 + fw), rect_pts(x0, y1 - fw, x1, y1),
			rect_pts(x0, y0, x0 + fw, y1), rect_pts(x1 - fw, y0, x1, y1)]:
		p.poly(r, frame)
	p.polyline(rect_pts(x0, y0, x1, y1), INK_W * 0.8, ink(frame), true)
	p.polyline(rect_pts(x0 + fw, y0 + fw, x1 - fw, y1 - fw), INK_W * 0.6, ink(frame), true)


## Tinted glass (opaque: it reads as glass from its reflections), with two diagonal sky streaks.
static func glass(p: DoodadPaint, x0: float, y0: float, x1: float, y1: float, tint: Color) -> void:
	p.vgrad(x0, y0, x1, y1, tint.darkened(0.25), tint.lightened(0.12))
	var w: float = x1 - x0
	var h: float = y1 - y0
	for k: int in 2:
		var s: float = 0.25 + 0.35 * float(k)
		var band: float = minf(w, h) * (0.12 if k == 0 else 0.06)
		var pts := PackedVector2Array([Vector2(x0 + w * s, y1), Vector2(x0 + w * s + band, y1),
			Vector2(x0 + w * s + band - h * 0.6, y0), Vector2(x0 + w * s - h * 0.6, y0)])
		var clipped := PackedVector2Array()
		for q: Vector2 in pts:
			clipped.append(Vector2(clampf(q.x, x0, x1), q.y))
		p.poly(clipped, Color(1, 1, 1, 0.13))
	p.polyline(rect_pts(x0, y0, x1, y1), INK_W * 0.7, ink(tint), true)


## A leaf: a pointed oval from `base` along `dir` (radians) `length` long and `width` wide.
static func leaf(p: DoodadPaint, base: Vector2, dir: float, length: float, width: float, c: Color) -> void:
	var d := Vector2(cos(dir), sin(dir))
	var n := Vector2(-d.y, d.x)
	var pts := PackedVector2Array()
	var steps: int = 8
	for i: int in steps + 1:
		var t: float = float(i) / float(steps)
		pts.append(base + d * length * t + n * width * 0.5 * sin(PI * t))
	for i: int in range(steps - 1, 0, -1):
		var t: float = float(i) / float(steps)
		pts.append(base + d * length * t - n * width * 0.5 * sin(PI * t))
	p.poly(pts, c)
	p.line(base, base + d * length * 0.9, width * 0.08, c.darkened(0.3))
	p.polyline(pts, INK_W * 0.5, ink(c), true)


## A rounded clump of foliage centred at (cx, cy): overlapping blobs in `colors`, lit from the top left.
static func foliage(p: DoodadPaint, cx: float, cy: float, rx: float, ry: float, colors: Array[Color], rseed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	var blobs: int = 18
	for i: int in blobs:
		var a: float = rng.randf() * TAU
		var d: float = sqrt(rng.randf()) * 0.75
		var bx: float = cx + cos(a) * rx * d
		var by: float = cy + sin(a) * ry * d
		var br: float = minf(rx, ry) * rng.randf_range(0.28, 0.42)
		var c: Color = colors[rng.randi_range(0, colors.size() - 1)]
		p.ellipse(bx, by, br, br * 0.9, ink(c).lerp(c, 0.35), 16)
		p.ellipse(bx - br * 0.08, by + br * 0.08, br * 0.88, br * 0.8, c, 16)
		p.ellipse(bx - br * 0.3, by + br * 0.3, br * 0.35, br * 0.3, c.lightened(0.18), 12)


## Weathering stains of `c` (give it a low alpha) over the rectangle, only over paint: `count`
## irregular patches about `size` across, each a cluster of soft blots that build up toward its
## middle, about half of them trailing a streak downward (rust or soot run by the rain).
static func stains(p: DoodadPaint, x0: float, y0: float, x1: float, y1: float, c: Color, count: int, size: float,
		rseed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	for i: int in count:
		var cx: float = rng.randf_range(x0, x1)
		var cy: float = rng.randf_range(y0, y1)
		var s: float = size * rng.randf_range(0.5, 1.0)
		for k: int in rng.randi_range(5, 9):
			var bx: float = cx + rng.randf_range(-0.6, 0.6) * s
			var by: float = cy + rng.randf_range(-0.35, 0.35) * s
			var r: float = s * rng.randf_range(0.12, 0.3)
			if p.painted(bx, by):
				# Soft-edged: three rings building up toward the middle.
				var squash: float = rng.randf_range(0.5, 0.9)
				for ring: int in 3:
					var rr: float = r * (1.0 - 0.3 * float(ring))
					p.ellipse(bx, by, rr, rr * squash, Color(c, c.a * 0.45), 14)
		if rng.randf() < 0.5:
			var x: float = cx + rng.randf_range(-0.3, 0.3) * s
			var w: float = s * rng.randf_range(0.06, 0.14)
			var length: float = s * rng.randf_range(1.2, 3.0)
			var y: float = cy
			var step: float = 0.04
			while y > maxf(cy - length, y0):
				var fade: float = 1.0 - (cy - y) / length
				if p.painted(x, y - step * 0.5):
					p.line(Vector2(x, y), Vector2(x, y - step), w * (0.5 + 0.5 * fade), Color(c, c.a * 0.8 * fade))
				y -= step


## Grime: a mottled surface and dark specks over the rectangle (only over paint).
static func grime(p: DoodadPaint, x0: float, y0: float, x1: float, y1: float, amount: float, rseed: int) -> void:
	p.mottle(x0, y0, x1, y1, 0.06, 0.06 * amount, rseed)
	p.speckle(x0, y0, x1, y1, Color(0.05, 0.04, 0.03, 0.18 * amount), int((x1 - x0) * (y1 - y0) * 14.0 * amount),
		0.015, 0.05, rseed + 1)

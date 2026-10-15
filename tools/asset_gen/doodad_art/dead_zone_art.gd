extends RefCounted
## The Dead Zone's doodad pictures (GDD §5: a blackened, bombed-out husk of the city; eerie, quiet,
## haunting; dark black, dark grey and ash grey, fires kept minimal; the zone's doodad brief: "wrecks,
## rubble heaps, fallen masonry"; owner's request October 9, 2026: pictures on boxes):
##   small   a broken concrete column on its square foot, its rebar sticking out of a jagged top,
##           chunks fallen round it
##   medium  a heap of rubble, lower at its edges than its middle: broken slabs, a window frame,
##           rebar, a dusting of ash
##   large   a burned-out bus: an empty shell, its window frames open on charred seats
## Every silhouette keeps near the box's full height, so nothing that pushes the runner looks low
## enough to jump.

const ASH := Color(0.46, 0.45, 0.44)
const ASH_LIGHT := Color(0.6, 0.59, 0.57)
const CONCRETE := Color(0.33, 0.32, 0.31)
const CHAR := Color(0.12, 0.115, 0.11)
const SOOT := Color(0.07, 0.07, 0.07)
const REBAR := Color(0.3, 0.22, 0.17)
const METAL := Color(0.24, 0.23, 0.23)
const EMBER := Color(0.48, 0.24, 0.14)


static func paint(s: DoodadArtSet) -> void:
	_column(s)
	_rubble(s)
	_bus(s)


## A jagged top edge from (x0, y) to (x1, y), teeth up to `amp` metres tall, from a seed.
static func _jagged(x0: float, x1: float, y: float, amp: float, teeth: int, rseed: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	var out := PackedVector2Array()
	for i: int in teeth + 1:
		var t: float = float(i) / float(teeth)
		out.append(Vector2(lerpf(x0, x1, t), y + rng.randf_range(-amp, amp * 0.4)))
	return out


# --- Small: a broken column ------------------------------------------------------------------------

## The column's square foot, and the height where its shaft broke off.
const FOOT_H: float = 0.45
const BREAK_Y: float = 2.2
const SHAFT_R: float = 0.45


## The column's square foot `w` wide: cast concrete chipped along its top edge, soot along its base.
static func _foot_face(s: DoodadArtSet, name: String, w: float, rseed: int) -> String:
	var p: DoodadPaint = s.canvas(w, FOOT_H)
	var body := PackedVector2Array([Vector2(0.0, 0.0), Vector2(w, 0.0)])
	body.append_array(_jagged(w, 0.0, FOOT_H - 0.04, 0.05, int(w / 0.15), rseed))
	DoodadKit.shape(p, body, CONCRETE.darkened(0.08))
	p.vgrad(0.0, 0.0, w, 0.3, SOOT.lerp(CONCRETE, 0.3), Color(CONCRETE, 0.0))
	DoodadKit.grime(p, 0.0, 0.0, w, FOOT_H, 1.0, rseed + 1)
	return s.add_picture(name, p)


## The shaft seen side on, on a card `w` wide (two crossed cards make it round): a cylinder of cast
## concrete lit from the left, formwork seams, a long crack, broken off in a jagged top with its
## rebar bent out of the break, and chunks fallen round its foot.
static func _shaft(s: DoodadArtSet, name: String, w: float, h: float, rseed: int) -> String:
	var p: DoodadPaint = s.canvas(w, h)
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	var cx: float = w * 0.5
	var r: float = SHAFT_R
	var top: float = BREAK_Y - FOOT_H
	for k: int in 5:
		var rx: float = lerpf(cx - r * 0.7, cx + r * 0.7, float(k) / 4.0)
		var bend: float = rng.randf_range(-0.2, 0.2)
		p.polyline(PackedVector2Array([Vector2(rx, top - 0.3), Vector2(rx + bend * 0.3, top + 0.12),
			Vector2(rx + bend, minf(top + rng.randf_range(0.18, 0.36), h - 0.03))]), 0.035, REBAR)
	var body := PackedVector2Array([Vector2(cx - r, 0.0), Vector2(cx + r, 0.0)])
	body.append_array(_jagged(cx + r, cx - r, top, 0.28, 8, rseed))
	DoodadKit.shape(p, body, CONCRETE)
	var bands: int = 9
	for i: int in bands:
		var t: float = (float(i) + 0.5) / float(bands)
		var bx0: float = lerpf(cx - r, cx + r, float(i) / float(bands))
		var bx1: float = lerpf(cx - r, cx + r, float(i + 1) / float(bands))
		if t < 0.4:
			p.tint_over(bx0, 0.0, bx1, h, Color(1, 1, 1, 0.14 * (0.4 - t) / 0.4))
		elif t > 0.5:
			p.tint_over(bx0, 0.0, bx1, h, Color(0, 0, 0, 0.5 * (t - 0.5) / 0.5))
	var y: float = 0.5
	while y < top - 0.35:
		p.line(Vector2(cx - r, y), Vector2(cx + r, y), 0.014, CONCRETE.darkened(0.35))
		y += 0.55
	p.polyline(PackedVector2Array([Vector2(cx - 0.05, top - 0.15), Vector2(cx + 0.04, top - 0.5), Vector2(cx - 0.06, top - 0.85),
		Vector2(cx + 0.02, top - 1.15)]), 0.02, SOOT)
	p.vgrad(cx - r, 0.0, cx + r, 0.9, SOOT.lerp(CONCRETE, 0.3), Color(CONCRETE, 0.0))
	p.speckle(cx - r, top - 0.4, cx + r, h, ASH_LIGHT, 18, 0.02, 0.05, rseed + 1)
	p.polyline(body, DoodadKit.INK_W, DoodadKit.ink(CONCRETE), true)
	for k: int in 4:
		var kx: float = lerpf(0.18, w - 0.18, float(k) / 3.0)
		var chunk := PackedVector2Array([Vector2(kx - 0.16, 0.0), Vector2(kx + 0.18, 0.0), Vector2(kx + 0.12, 0.2),
			Vector2(kx - 0.04, 0.26), Vector2(kx - 0.14, 0.14)])
		DoodadKit.shape(p, chunk, CONCRETE.darkened(0.1 * float(k % 3)))
	DoodadKit.grime(p, 0.0, 0.0, w, h, 1.0, rseed + 2)
	return s.add_picture(name, p)


## The break from above: a ragged disc of freshly broken concrete, lighter than the weathered shaft,
## the rebar's cut ends round it, dusted with ash.
static func _break_top(s: DoodadArtSet, name: String, w: float, l: float, rseed: int) -> String:
	var p: DoodadPaint = s.canvas(w, l)
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	var cx: float = w * 0.5
	var cy: float = l * 0.5
	var disc := PackedVector2Array()
	for k: int in 16:
		var a: float = TAU * float(k) / 16.0
		var rr: float = SHAFT_R * rng.randf_range(0.82, 1.0)
		disc.append(Vector2(cx + cos(a) * rr, cy + sin(a) * rr))
	DoodadKit.shape(p, disc, CONCRETE.lightened(0.12))
	p.speckle(cx - SHAFT_R, cy - SHAFT_R, cx + SHAFT_R, cy + SHAFT_R, CONCRETE.darkened(0.25), 24, 0.02, 0.06, rseed + 1)
	p.speckle(cx - SHAFT_R, cy - SHAFT_R, cx + SHAFT_R, cy + SHAFT_R, ASH_LIGHT, 30, 0.015, 0.04, rseed + 2)
	for k: int in 8:
		var a: float = TAU * float(k) / 8.0
		p.circle(cx + cos(a) * SHAFT_R * 0.7, cy + sin(a) * SHAFT_R * 0.7, 0.025, REBAR, 10)
	return s.add_picture(name, p)


static func _rubble_top(s: DoodadArtSet, name: String, w: float, l: float, rseed: int) -> String:
	var p: DoodadPaint = s.canvas(w, l)
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	p.rect(0.0, 0.0, w, l, CHAR.lightened(0.05))
	for i: int in int(w * l * 9.0):
		var cx: float = rng.randf_range(0.05, w - 0.05)
		var cy: float = rng.randf_range(0.05, l - 0.05)
		var r: float = rng.randf_range(0.08, 0.22)
		var pts := PackedVector2Array()
		for k: int in 5:
			var a: float = TAU * float(k) / 5.0 + rng.randf() * 0.6
			pts.append(Vector2(cx + cos(a) * r, cy + sin(a) * r * rng.randf_range(0.6, 1.0)))
		DoodadKit.shape(p, pts, CONCRETE.lerp(ASH, rng.randf()))
	p.speckle(0.0, 0.0, w, l, Color(ASH_LIGHT, 0.7), int(w * l * 40.0), 0.01, 0.03, rseed + 1)
	return s.add_picture(name, p)


static func _column(s: DoodadArtSet) -> void:
	var b: Vector3 = s.box("small")
	var fv: float = FOOT_H / b.y
	_foot_face(s, "column_foot_front", b.x, 401)
	_foot_face(s, "column_foot_side", b.z, 402)
	_rubble_top(s, "column_foot_top", b.x, b.z, 403)
	_shaft(s, "column_shaft_a", b.x, b.y - FOOT_H, 404)
	_shaft(s, "column_shaft_b", b.z, b.y - FOOT_H, 405)
	_break_top(s, "column_break", b.x, b.z, 406)
	var cards: Array[Dictionary] = [
		DoodadArtSet.front("column_foot_front", [0.0, 0.0, 1.0, fv]),
		DoodadArtSet.back("column_foot_front", [0.0, 0.0, 1.0, fv]),
		DoodadArtSet.top("column_foot_top", [0.0, 0.0, 1.0, 1.0], fv),
		DoodadArtSet.card("z", 0.5, "column_shaft_a", [0.0, fv, 1.0, 1.0]),
		DoodadArtSet.card("x", 0.5, "column_shaft_b", [0.0, fv, 1.0, 1.0]),
		DoodadArtSet.top("column_break", [0.0, 0.0, 1.0, 1.0], (BREAK_Y - 0.1) / b.y),
	]
	cards.append_array(DoodadArtSet.sides("column_foot_side", [0.0, 0.0, 1.0, fv]))
	s.add_design("small", "broken_column", [CONCRETE, ASH, REBAR], cards)


# --- Medium: a rubble heap --------------------------------------------------------------------------

## The heap's outer faces and the ridges inside it: each face's crest from its height at the ends up
## to its height at its middle (lower at the edges, so the box reads as a mound, never a cube), and
## the rubble filling it between the faces, seen from above.
const HEAP_EDGE: float = 1.5
const HEAP_PEAK: float = 2.48
const CORE_EDGE: float = 1.4
const CORE_PEAK: float = 2.58
const HEAP_FILL: float = 1.3


## A heap's crest height at `x` across a face `w` wide, from `edge` at its ends up to `peak`.
static func _crest(x: float, w: float, edge: float, peak: float) -> float:
	return edge + (peak - edge) * pow(sin(PI * clampf(x / w, 0.0, 1.0)), 0.6)


## A heap of broken slabs on a face `w` wide: a mound from `edge` at its ends up to `peak`, its
## overlapping angular chunks bigger toward the bottom, rebar and a twisted window frame caught in it.
static func _heap_face(s: DoodadArtSet, name: String, w: float, h: float, edge: float, peak: float, rseed: int) -> String:
	var p: DoodadPaint = s.canvas(w, h)
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	var teeth: int = maxi(int(w / 0.22), 4)
	var mound := PackedVector2Array([Vector2(0.0, 0.0), Vector2(w, 0.0)])
	for i: int in range(teeth, -1, -1):
		var x: float = w * float(i) / float(teeth)
		mound.append(Vector2(x, minf(_crest(x, w, edge, peak) + rng.randf_range(-0.12, 0.06), h - 0.02)))
	for k: int in maxi(int(w / 0.8), 1):
		var rx: float = rng.randf_range(0.3, w - 0.3)
		var cy: float = _crest(rx, w, edge, peak)
		p.polyline(PackedVector2Array([Vector2(rx, cy - 0.5), Vector2(rx + rng.randf_range(-0.2, 0.2), minf(cy + 0.28, h - 0.03))]),
			0.03, REBAR)
	DoodadKit.shape(p, mound, CHAR.lightened(0.08))
	var count: int = int(w * 9.0)
	for i: int in count:
		var t: float = float(i) / float(count)
		var cx: float = rng.randf_range(0.12, w - 0.12)
		var cy: float = lerpf(_crest(cx, w, edge, peak) - 0.18, 0.15, sqrt(1.0 - t))
		var r: float = lerpf(0.12, 0.32, t) * rng.randf_range(0.7, 1.1)
		var pts := PackedVector2Array()
		var corners: int = rng.randi_range(4, 6)
		var tilt: float = rng.randf() * TAU
		for k: int in corners:
			var a: float = tilt + TAU * float(k) / float(corners) + rng.randf_range(-0.3, 0.3)
			pts.append(Vector2(clampf(cx + cos(a) * r, 0.0, w), clampf(cy + sin(a) * r * 0.7, 0.0, h - 0.04)))
		var c: Color = CONCRETE.lerp(ASH, rng.randf_range(0.0, 0.6)).darkened(rng.randf_range(0.0, 0.3))
		DoodadKit.shape(p, pts, c)
		p.line(pts[0], pts[1], 0.02, c.lightened(0.2))
	if w > 2.5:
		var fx: float = w * 0.4
		p.polyline(PackedVector2Array([Vector2(fx, 0.95), Vector2(fx + 0.6, 1.05), Vector2(fx + 0.55, 1.65), Vector2(fx - 0.03, 1.55)]),
			0.05, METAL, true)
		p.line(Vector2(fx + 0.28, 1.0), Vector2(fx + 0.26, 1.6), 0.035, METAL)
	# Ash settled on the tops, a faint ember deep in one gap (dim, never a light).
	p.speckle(0.0, edge * 0.6, w, h, Color(ASH_LIGHT, 0.7), int(w * 30.0), 0.01, 0.03, rseed + 1)
	p.ellipse(w * 0.62, 0.5, 0.08, 0.05, EMBER, 12)
	DoodadKit.grime(p, 0.0, 0.0, w, h, 1.0, rseed + 2)
	return s.add_picture(name, p)


static func _rubble(s: DoodadArtSet) -> void:
	var b: Vector3 = s.box("medium")
	_heap_face(s, "heap_front", b.x, b.y, HEAP_EDGE, HEAP_PEAK, 411)
	_heap_face(s, "heap_side", b.z, b.y, HEAP_EDGE, HEAP_PEAK, 412)
	_heap_face(s, "heap_core_across", b.x * 0.8, b.y, CORE_EDGE, CORE_PEAK, 414)
	_heap_face(s, "heap_core_along", b.z * 0.85, b.y, CORE_EDGE, CORE_PEAK, 415)
	_rubble_top(s, "heap_fill", b.x, b.z, 413)
	var cards: Array[Dictionary] = [
		DoodadArtSet.front("heap_front"),
		DoodadArtSet.back("heap_front"),
		DoodadArtSet.top("heap_fill", [0.02, 0.02, 0.98, 0.98], HEAP_FILL / b.y),
		DoodadArtSet.card("z", 0.35, "heap_core_across", [0.1, 0.0, 0.9, 1.0]),
		DoodadArtSet.card("z", 0.65, "heap_core_across", [0.1, 0.0, 0.9, 1.0], true),
		DoodadArtSet.card("x", 0.5, "heap_core_along", [0.075, 0.0, 0.925, 1.0]),
	]
	cards.append_array(DoodadArtSet.sides("heap_side"))
	s.add_design("medium", "rubble_heap", [CONCRETE, ASH, CHAR], cards)


# --- Large: a burned-out bus ------------------------------------------------------------------------

const BUS_LOW: float = 0.32
const BUS_ROOF: float = 2.45


static func _bus_side(s: DoodadArtSet, name: String, l: float, h: float) -> String:
	var p: DoodadPaint = s.canvas(l, h)
	DoodadKit.round_rect_shape(p, 0.04, BUS_LOW, l - 0.04, BUS_ROOF, 0.12, METAL)
	p.rect(0.04, BUS_LOW, l - 0.04, BUS_LOW + 0.3, CHAR)
	# Paint burned away to the metal in blotches, soot streaking up from the windows.
	DoodadKit.stains(p, 0.04, BUS_LOW, l - 0.04, BUS_ROOF, Color(CHAR, 0.45), 18, 0.45, 421)
	DoodadKit.stains(p, 0.04, BUS_LOW, l - 0.04, BUS_ROOF, Color(ASH.darkened(0.2), 0.3), 10, 0.3, 422)
	# A row of empty window frames, and the door near the front.
	var wy0: float = 1.25
	var wy1: float = BUS_ROOF - 0.22
	var x: float = 1.35
	while x < l - 0.6:
		var x1: float = minf(x + 0.85, l - 0.25)
		DoodadKit.window_hole(p, x, wy0, x1, wy1, CHAR, 0.06)
		p.vgrad(x, wy1, x1, BUS_ROOF - 0.04, CHAR, SOOT)
		x = x1 + 0.12
	DoodadKit.window_hole(p, 0.3, 0.45, 1.15, wy1, CHAR, 0.06)
	p.line(Vector2(0.72, 0.45), Vector2(0.72, wy1), 0.04, CHAR)
	# Wheels on their rims, the tyres burned off.
	for wx: float in [1.1, l - 1.3]:
		p.circle(wx, 0.42, 0.45, SOOT, 24)
		DoodadKit.wheel(p, wx, 0.3, 0.28, METAL.darkened(0.3), METAL.lightened(0.1))
	DoodadKit.grime(p, 0.04, BUS_LOW, l - 0.04, BUS_ROOF, 1.0, 423)
	return s.add_picture(name, p)


static func _bus_end(s: DoodadArtSet, name: String, w: float, h: float) -> String:
	var p: DoodadPaint = s.canvas(w, h)
	DoodadKit.round_rect_shape(p, 0.02, BUS_LOW, w - 0.02, BUS_ROOF, 0.15, METAL)
	DoodadKit.wheel_edge(p, 0.12, 0.42, 0.0, 0.6, METAL.darkened(0.3))
	DoodadKit.wheel_edge(p, w - 0.42, w - 0.12, 0.0, 0.6, METAL.darkened(0.3))
	DoodadKit.panel(p, 0.0, BUS_LOW, w, BUS_LOW + 0.26, CHAR)
	# The windscreen gone (open), a blank destination box above it.
	DoodadKit.window_hole(p, 0.15, 1.05, w - 0.15, BUS_ROOF - 0.42, CHAR, 0.07)
	DoodadKit.panel(p, w * 0.2, BUS_ROOF - 0.36, w * 0.8, BUS_ROOF - 0.1, SOOT)
	for hx: float in [0.28, w - 0.28]:
		p.circle(hx, 0.78, 0.1, SOOT, 16)
	DoodadKit.stains(p, 0.02, BUS_LOW, w - 0.02, BUS_ROOF, Color(CHAR, 0.45), 6, 0.4, 431)
	DoodadKit.grime(p, 0.0, 0.0, w, h, 1.0, 432)
	return s.add_picture(name, p)


## The shell's charred inside, down its middle: rows of burned seat frames.
static func _bus_inside(s: DoodadArtSet, name: String, l: float, h: float) -> String:
	var p: DoodadPaint = s.canvas(l, h)
	p.rect(0.0, 0.0, l, h, SOOT)
	var x: float = 0.4
	while x < l - 0.4:
		p.polyline(PackedVector2Array([Vector2(x, 0.05), Vector2(x, h * 0.5), Vector2(x + 0.06, h * 0.85)]), 0.04, CHAR.lightened(0.15))
		p.line(Vector2(x - 0.3, h * 0.5), Vector2(x, h * 0.5), 0.04, CHAR.lightened(0.15))
		x += 0.6
	DoodadKit.stains(p, 0.0, 0.0, l, h, Color(ASH.darkened(0.3), 0.35), 8, 0.25, 441)
	return s.add_picture(name, p)


static func _bus_top(s: DoodadArtSet, name: String, w: float, l: float) -> String:
	var p: DoodadPaint = s.canvas(w, l)
	DoodadKit.panel(p, 0.04, 0.04, w - 0.04, l - 0.04, METAL)
	DoodadKit.stains(p, 0.0, 0.0, w, l, Color(CHAR, 0.4), 12, 0.45, 451)
	DoodadKit.stains(p, 0.0, 0.0, w, l, Color(ASH, 0.22), 8, 0.3, 452)
	# A hatch burned through, open on the dark inside.
	p.erase_rect(w * 0.3, l * 0.55, w * 0.7, l * 0.68)
	p.polyline(DoodadKit.rect_pts(w * 0.3, l * 0.55, w * 0.7, l * 0.68), 0.04, CHAR, true)
	return s.add_picture(name, p)


static func _bus(s: DoodadArtSet) -> void:
	var b: Vector3 = s.box("large")
	_bus_end(s, "bus_end", b.x, b.y)
	_bus_side(s, "bus_side", b.z, b.y)
	_bus_top(s, "bus_top", b.x, b.z)
	_bus_inside(s, "bus_inside", b.z * 0.9, 1.3)
	var cards: Array[Dictionary] = DoodadArtSet.box_cards("bus_end", "bus_side", "bus_top")
	cards.append(DoodadArtSet.card("x", 0.5, "bus_inside", [0.05, BUS_LOW / b.y + 0.05, 0.95, 2.2 / b.y]))
	s.add_design("large", "burned_bus", [METAL, CHAR, ASH], cards)

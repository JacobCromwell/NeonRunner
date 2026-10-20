extends RefCounted
## The Terminal's doodad pictures (GDD §3 and §5, Zone 8: an abandoned subway; the zone's doodad brief: debris, "a heap of broken
## concrete and rebar, a toppled ticket kiosk or vending machine, fallen ceiling slabs, a tangle of cable drums and crates",
## lower than other zones' doodads and still too tall to jump; owner's request October 9, 2026: pictures on boxes):
##   small   a stack of cable drums with the cable come off them, or a stack of crates under a rusted drum
##   medium  a toppled ticket kiosk (its window frame open on the dark), a toppled vending machine (its empty shelves open
##           on the dark), or a heap of broken concrete, tile and rebar
##   large   a pile of fallen ceiling slabs leaning on each other (the gaps between them open), or a long heap of broken concrete
##           with a bent girder in it
## Wet black stone, concrete grey, rust, old steel, a little vine: nothing glows and nothing is drawn to read as a hazard (no
## stripes, no signs with words). Every silhouette keeps near the box's full height, so nothing that stops the runner looks low
## enough to jump; the pictures are drawn to whatever box the zone's doodads have (MovementTuning.doodad_size), every size a share
## of its box's height, so `tools/godot.sh doodads --only=terminal` repaints them for the lower boxes of task O2.
## DESIGN-TBD (docs/questions/o4.md item 9): which debris, how many looks of each size and how they are drawn.

const CONC := Color(0.47, 0.45, 0.41)
const CONC_DARK := Color(0.31, 0.295, 0.27)
const WET := Color(0.17, 0.16, 0.15)
const REBAR := Color(0.36, 0.22, 0.14)
const STEEL := Color(0.22, 0.3, 0.27)
const RUST := Color(0.4, 0.23, 0.14)
const VINE := Color(0.16, 0.3, 0.11)
const WOOD := Color(0.34, 0.25, 0.17)
const TILE := Color(0.5, 0.48, 0.42)
const CABLE := Color(0.07, 0.07, 0.075)
const GLASS := Color(0.07, 0.09, 0.09)


static func paint(s: DoodadArtSet) -> void:
	_drums(s)
	_crates(s)
	_kiosk(s)
	_vending(s)
	_heap(s, "medium", "concrete_heap", 0.56, 0.93, 0.5, 0.97, 600)
	_slabs(s)
	_heap(s, "large", "long_heap", 0.5, 0.9, 0.46, 0.96, 700)


# --- Shared pieces ------------------------------------------------------------------------------

## `pts` turned by `angle` (radians, counter-clockwise) about `pivot`.
static func _turn(pts: PackedVector2Array, pivot: Vector2, angle: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q: Vector2 in pts:
		out.append(pivot + (q - pivot).rotated(angle))
	return out


## A jagged line of broken edge from (x0, y) to (x1, y), teeth up to `amp` metres tall, from a seed.
static func _jagged(x0: float, x1: float, y: float, amp: float, teeth: int, rseed: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	var out := PackedVector2Array()
	for i: int in teeth + 1:
		var t: float = float(i) / float(teeth)
		out.append(Vector2(lerpf(x0, x1, t), y + rng.randf_range(-amp, amp * 0.4)))
	return out


## A bent rod of rebar from `from` heading `angle` (radians), `length` long, with a bend a third of the way.
static func _rebar(p: DoodadPaint, from: Vector2, angle: float, length: float, rseed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	var a: Vector2 = from + Vector2(cos(angle), sin(angle)) * length * 0.4
	var b: Vector2 = a + Vector2(cos(angle + rng.randf_range(-0.7, 0.7)), sin(angle + rng.randf_range(-0.7, 0.7))) * length * 0.6
	p.polyline(PackedVector2Array([from, a, b]), 0.035, REBAR.darkened(0.2))
	p.polyline(PackedVector2Array([from, a, b]), 0.02, REBAR)


## A tangle of loose cable: loops and a trailing end, black with a pale sheen.
static func _cable_tangle(p: DoodadPaint, cx: float, cy: float, r: float, loops: int, rseed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	for i: int in loops:
		var pts := PackedVector2Array()
		var c := Vector2(cx + rng.randf_range(-r, r) * 0.5, cy + rng.randf_range(-r, r) * 0.35)
		var rx: float = r * rng.randf_range(0.4, 0.9)
		var ry: float = r * rng.randf_range(0.2, 0.5)
		var tilt: float = rng.randf_range(-0.5, 0.5)
		for k: int in 18:
			var a: float = TAU * float(k) / 18.0
			pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(tilt))
		p.polyline(pts, 0.045, CABLE, true)
		p.polyline(pts, 0.012, Color(0.3, 0.3, 0.32, 0.8), true)


## Vine: a few hanging strands and a clump of leaves along a line from `a` to `b`.
static func _vines(p: DoodadPaint, a: Vector2, b: Vector2, hang: float, rseed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	var n: int = maxi(int(a.distance_to(b) / 0.35), 2)
	for i: int in n:
		var t: float = rng.randf()
		var at: Vector2 = a.lerp(b, t)
		var l: float = hang * rng.randf_range(0.3, 1.0)
		p.line(at, at - Vector2(rng.randf_range(-0.05, 0.05), l), 0.03, VINE.darkened(0.25))
		for k: int in 3:
			var y: float = at.y - l * (0.25 + 0.3 * float(k))
			DoodadKit.leaf(p, Vector2(at.x, y), rng.randf_range(-0.6, 3.7), 0.2, 0.1, VINE.lightened(rng.randf_range(-0.05, 0.12)))


## A mound of broken concrete on a face `w` wide, its crest from `edge` at its ends up to `peak` (metres), the rest of its
## silhouette filled with overlapping angular chunks bigger toward the bottom, rebar and bits of tile caught in it, a few
## strands of vine and a dark wet patch at its foot.
static func _mound(s: DoodadArtSet, name: String, w: float, h: float, edge: float, peak: float, rseed: int) -> String:
	var p: DoodadPaint = s.canvas(w, h)
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	var teeth: int = maxi(int(w / 0.22), 4)
	var mound := PackedVector2Array([Vector2(0.0, 0.0), Vector2(w, 0.0)])
	for i: int in range(teeth, -1, -1):
		var x: float = w * float(i) / float(teeth)
		var crest: float = edge + (peak - edge) * pow(sin(PI * clampf(x / w, 0.0, 1.0)), 0.6)
		mound.append(Vector2(x, minf(crest + rng.randf_range(-0.12, 0.06), h - 0.02)))
	for k: int in maxi(int(w / 0.7), 1):
		var rx: float = rng.randf_range(0.25, w - 0.25)
		var crest: float = edge + (peak - edge) * pow(sin(PI * clampf(rx / w, 0.0, 1.0)), 0.6)
		_rebar(p, Vector2(rx, crest - 0.3), PI * 0.5 + rng.randf_range(-0.6, 0.6), rng.randf_range(0.5, 1.0), rseed + k)
	DoodadKit.shape(p, mound, WET.lightened(0.05))
	var count: int = int(w * 9.0)
	for i: int in count:
		var t: float = float(i) / float(count)
		var cx: float = rng.randf_range(0.12, w - 0.12)
		var crest: float = edge + (peak - edge) * pow(sin(PI * clampf(cx / w, 0.0, 1.0)), 0.6)
		var cy: float = lerpf(crest - 0.18, 0.15, sqrt(1.0 - t))
		var r: float = lerpf(0.12, 0.32, t) * rng.randf_range(0.7, 1.1)
		var pts := PackedVector2Array()
		var corners: int = rng.randi_range(4, 6)
		var tilt: float = rng.randf() * TAU
		for k: int in corners:
			var a: float = tilt + TAU * float(k) / float(corners) + rng.randf_range(-0.3, 0.3)
			pts.append(Vector2(clampf(cx + cos(a) * r, 0.0, w), clampf(cy + sin(a) * r * 0.7, 0.0, h - 0.04)))
		var c: Color = CONC.lerp(CONC_DARK, rng.randf_range(0.0, 0.7)).darkened(rng.randf_range(0.0, 0.25))
		if rng.randf() < 0.08:
			c = TILE.darkened(0.25)
		DoodadKit.shape(p, pts, c)
		p.line(pts[0], pts[1], 0.02, c.lightened(0.2))
	_vines(p, Vector2(w * 0.2, edge + 0.1), Vector2(w * 0.8, peak - 0.1), 0.45, rseed + 5)
	p.speckle(0.0, edge * 0.6, w, h, Color(0.5, 0.48, 0.44, 0.5), int(w * 20.0), 0.01, 0.03, rseed + 1)
	DoodadKit.grime(p, 0.0, 0.0, w, h, 1.0, rseed + 2)
	return s.add_picture(name, p)


static func _mound_top(s: DoodadArtSet, name: String, w: float, l: float, rseed: int) -> String:
	var p: DoodadPaint = s.canvas(w, l)
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	p.rect(0.0, 0.0, w, l, WET.lightened(0.04))
	for i: int in int(w * l * 9.0):
		var cx: float = rng.randf_range(0.05, w - 0.05)
		var cy: float = rng.randf_range(0.05, l - 0.05)
		var r: float = rng.randf_range(0.08, 0.22)
		var pts := PackedVector2Array()
		for k: int in 5:
			var a: float = TAU * float(k) / 5.0 + rng.randf() * 0.6
			pts.append(Vector2(cx + cos(a) * r, cy + sin(a) * r * rng.randf_range(0.6, 1.0)))
		DoodadKit.shape(p, pts, CONC.lerp(CONC_DARK, rng.randf()))
	for i: int in int(w * l * 2.0):
		p.circle(rng.randf_range(0.05, w - 0.05), rng.randf_range(0.05, l - 0.05), rng.randf_range(0.04, 0.1), VINE.darkened(rng.randf_range(0.0, 0.3)), 10)
	p.speckle(0.0, 0.0, w, l, Color(0.5, 0.48, 0.44, 0.6), int(w * l * 40.0), 0.01, 0.03, rseed + 1)
	return s.add_picture(name, p)


## A heap of broken concrete as a whole look (a face front and back, long sides, two inner ridges and the fill between).
static func _heap(s: DoodadArtSet, size_class: String, name: String, edge_k: float, peak_k: float, core_edge_k: float, core_peak_k: float,
		rseed: int) -> void:
	var b: Vector3 = s.box(size_class)
	var front: String = _mound(s, name + "_front", b.x, b.y, b.y * edge_k, b.y * peak_k, rseed + 1)
	var side: String = _mound(s, name + "_side", b.z, b.y, b.y * edge_k, b.y * peak_k, rseed + 2)
	var core_a: String = _mound(s, name + "_core_across", b.x * 0.8, b.y, b.y * core_edge_k, b.y * core_peak_k, rseed + 3)
	var core_b: String = _mound(s, name + "_core_along", b.z * 0.85, b.y, b.y * core_edge_k, b.y * core_peak_k, rseed + 4)
	var fill: String = _mound_top(s, name + "_fill", b.x, b.z, rseed + 5)
	var cards: Array[Dictionary] = [
		DoodadArtSet.front(front),
		DoodadArtSet.back(front),
		DoodadArtSet.top(fill, [0.02, 0.02, 0.98, 0.98], b.y * 0.5 / b.y),
		DoodadArtSet.card("z", 0.35, core_a, [0.1, 0.0, 0.9, 1.0]),
		DoodadArtSet.card("z", 0.65, core_a, [0.1, 0.0, 0.9, 1.0], true),
		DoodadArtSet.card("x", 0.5, core_b, [0.075, 0.0, 0.925, 1.0]),
	]
	cards.append_array(DoodadArtSet.sides(side))
	if size_class == "large":
		# A bent girder lying through the heap: a card of its own along the middle.
		var girder: String = _girder(s, name + "_girder", b.z, b.y, rseed + 6)
		cards.append(DoodadArtSet.card("x", 0.28, girder, [0.0, 0.0, 1.0, 1.0]))
	s.add_design(size_class, name, [CONC, CONC_DARK, REBAR], cards)


## A girder bent and half buried: an I-section seen from the side with a kink, rust and flaking verdigris.
static func _girder(s: DoodadArtSet, name: String, l: float, h: float, rseed: int) -> String:
	var p: DoodadPaint = s.canvas(l, h)
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	var y0: float = h * 0.32
	var x0: float = l * 0.1
	var x1: float = l * 0.9
	var kink: float = l * (0.45 + 0.1 * rng.randf())
	var top := PackedVector2Array([Vector2(x0, y0 + 0.05), Vector2(kink, y0 + 0.55), Vector2(x1, y0 + 1.15)])
	var web := PackedVector2Array()
	for q: Vector2 in top:
		web.append(q)
	for i: int in range(top.size() - 1, -1, -1):
		web.append(top[i] + Vector2(0.0, 0.32))
	DoodadKit.shape(p, web, STEEL)
	p.polyline(top, 0.09, STEEL.darkened(0.2))
	p.polyline(PackedVector2Array([top[0] + Vector2(0, 0.32), top[1] + Vector2(0, 0.32), top[2] + Vector2(0, 0.32)]), 0.09, STEEL.darkened(0.2))
	DoodadKit.stains(p, x0, y0, x1, y0 + 1.6, Color(RUST, 0.5), 8, 0.35, rseed + 1)
	return s.add_picture(name, p)


# --- Small: cable drums and crates ---------------------------------------------------------------

## A cable drum seen face-on, centred at (cx, cy) with radius r: a wooden flange of planks with its rim, the cable wound on it in
## rings, a steel hub and its bolts.
static func _drum_disc(p: DoodadPaint, cx: float, cy: float, r: float) -> void:
	p.circle(cx, cy, r, WOOD.darkened(0.45), 32)
	p.circle(cx, cy, r - 0.025, WOOD, 32)
	var k: int = 7
	for i: int in k:
		var y: float = cy - r + 2.0 * r * (float(i) + 0.5) / float(k)
		var half: float = sqrt(maxf(r * r - (y - cy) * (y - cy), 0.0))
		p.line(Vector2(cx - half + 0.02, y), Vector2(cx + half - 0.02, y), 0.012, WOOD.darkened(0.4))
	p.circle(cx, cy, r * 0.74, CABLE, 28)
	p.circle(cx, cy, r * 0.66, CABLE.lightened(0.05), 28)
	for ring: int in 3:
		var rr: float = r * (0.7 - 0.12 * float(ring))
		p.polyline(DoodadPaint.ellipse_points(cx, cy, rr, rr, 28), 0.012, Color(0.32, 0.32, 0.34, 0.5), true)
	p.circle(cx, cy, r * 0.26, STEEL.darkened(0.1), 20)
	p.circle(cx, cy, r * 0.14, WET, 14)
	for j: int in 4:
		var a: float = TAU * float(j) / 4.0 + 0.4
		p.circle(cx + cos(a) * r * 0.21, cy + sin(a) * r * 0.21, 0.018, REBAR.darkened(0.2), 8)
	p.polyline(DoodadPaint.ellipse_points(cx, cy, r, r, 32), DoodadKit.INK_W, DoodadKit.ink(WOOD), true)


## Two drums on their edges: the upper one off-centre, the cable come off them in loops.
static func _drums(s: DoodadArtSet) -> void:
	var b: Vector3 = s.box("small")
	var r1: float = minf(b.x * 0.47, b.y * 0.23)
	var r2: float = r1 * 0.92
	var front: DoodadPaint = s.canvas(b.x, b.y)
	_drum_disc(front, b.x * 0.5, r1, r1)
	_drum_disc(front, b.x * 0.5 - 0.05, r1 * 2.0 + r2 - 0.02, r2)
	_cable_tangle(front, b.x * 0.5, b.y - 0.32, b.x * 0.5, 4, 801)
	DoodadKit.grime(front, 0.0, 0.0, b.x, b.y, 0.8, 802)
	s.add_picture("drums_front", front)
	# Edge-on: each drum a core of cable between two flanges, the flanges as tall as the drum.
	var side: DoodadPaint = s.canvas(b.z, b.y)
	var width: float = b.z * 0.62
	for k: int in 2:
		var y0: float = 0.0 if k == 0 else r1 * 2.0 - 0.02
		var h: float = (r1 if k == 0 else r2) * 2.0
		var x0: float = (b.z - width) * 0.5 + (0.0 if k == 0 else 0.06)
		side.rect(x0, y0, x0 + width, y0 + h, CABLE.lightened(0.04))
		for ring: int in int(h / 0.07):
			side.line(Vector2(x0, y0 + 0.07 * float(ring) + 0.03), Vector2(x0 + width, y0 + 0.07 * float(ring) + 0.03), 0.01, Color(0.3, 0.3, 0.32, 0.45))
		for fx: float in [x0 - 0.02, x0 + width - 0.06]:
			DoodadKit.panel(side, fx, y0, fx + 0.08, y0 + h, WOOD)
		side.polyline(DoodadKit.rect_pts(x0 - 0.02, y0, x0 + width + 0.02, y0 + h), 0.02, DoodadKit.ink(WOOD), true)
	_cable_tangle(side, b.z * 0.5, b.y - 0.3, b.z * 0.45, 3, 803)
	DoodadKit.grime(side, 0.0, 0.0, b.z, b.y, 0.8, 804)
	s.add_picture("drums_side", side)
	var top: DoodadPaint = s.canvas(b.x, b.z)
	top.rect(0.0, 0.0, b.x, b.z, WET.lightened(0.05))
	_cable_tangle(top, b.x * 0.5, b.z * 0.5, b.x * 0.5, 5, 805)
	top.speckle(0.0, 0.0, b.x, b.z, Color(0.5, 0.48, 0.44, 0.5), 30, 0.01, 0.03, 806)
	s.add_picture("drums_top", top)
	s.add_design("small", "cable_drums", [WOOD, CABLE, STEEL], DoodadArtSet.box_cards("drums_front", "drums_side", "drums_top"))


## A stack of two wooden crates, the top one askew, a rusted drum on them and a length of cable over the lot.
static func _crates(s: DoodadArtSet) -> void:
	var b: Vector3 = s.box("small")
	for view: int in 2:
		var w: float = b.x if view == 0 else b.z
		var p: DoodadPaint = s.canvas(w, b.y)
		var unit: float = minf(w * 0.92, b.y * 0.36)
		DoodadKit.crate(p, (w - unit) * 0.5, 0.0, (w + unit) * 0.5, unit, WOOD.darkened(0.15))
		var tilt: float = 0.1 if view == 0 else -0.08
		var top_crate: PackedVector2Array = _turn(DoodadKit.rect_pts(w * 0.5 - unit * 0.46, unit, w * 0.5 + unit * 0.46, unit * 1.9), Vector2(w * 0.5, unit), tilt)
		DoodadKit.shape(p, top_crate, WOOD)
		for i: int in 3:
			var f: float = 1.0 + 0.3 * float(i)
			p.polyline(_turn(PackedVector2Array([Vector2(w * 0.5 - unit * 0.46, unit * f), Vector2(w * 0.5 + unit * 0.46, unit * f)]), Vector2(w * 0.5, unit), tilt), 0.018, WOOD.darkened(0.45))
		var dr: float = minf(w * 0.34, 0.34)
		var drum_y: float = unit * 1.9
		DoodadKit.shape(p, DoodadKit.rect_pts(w * 0.5 - dr, drum_y, w * 0.5 + dr, drum_y + b.y * 0.27), STEEL)
		for yy: float in [drum_y + 0.05, drum_y + b.y * 0.27 - 0.08]:
			p.rect(w * 0.5 - dr, yy, w * 0.5 + dr, yy + 0.04, STEEL.darkened(0.3))
		p.ellipse(w * 0.5, drum_y + b.y * 0.27, dr, 0.05, STEEL.lightened(0.1), 16)
		DoodadKit.stains(p, w * 0.5 - dr, drum_y, w * 0.5 + dr, drum_y + b.y * 0.27, Color(RUST, 0.5), 4, 0.25, 811 + view)
		_cable_tangle(p, w * 0.5, b.y - 0.15, w * 0.45, 3, 812 + view)
		DoodadKit.grime(p, 0.0, 0.0, w, b.y, 0.9, 814 + view)
		s.add_picture("crates_front" if view == 0 else "crates_side", p)
	var top: DoodadPaint = s.canvas(b.x, b.z)
	DoodadKit.planks(top, 0.05, 0.05, b.x - 0.05, b.z - 0.05, WOOD.darkened(0.2), 0.14, 816)
	top.speckle(0.0, 0.0, b.x, b.z, Color(0.5, 0.48, 0.44, 0.5), 20, 0.01, 0.03, 817)
	s.add_picture("crates_top", top)
	s.add_design("small", "crates_and_drum", [WOOD, STEEL, CABLE], DoodadArtSet.box_cards("crates_front", "crates_side", "crates_top"))


# --- Medium: a toppled kiosk or vending machine ------------------------------------------------------

## The heap a toppled thing leans on, along the foot of a face: low mounds at both ends with chunks of concrete, rebar and a
## little vine, drawn over `p` from x = 0 to w.
static func _foot_rubble(p: DoodadPaint, w: float, rise: float, rseed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	var pts := PackedVector2Array([Vector2(0.0, 0.0), Vector2(w, 0.0)])
	for i: int in range(10, -1, -1):
		var x: float = w * float(i) / 10.0
		pts.append(Vector2(x, rise * (0.4 + 0.6 * (1.0 - sin(PI * x / w) * 0.6)) + rng.randf_range(-0.05, 0.08)))
	DoodadKit.shape(p, pts, WET.lightened(0.04))
	for i: int in int(w * 7.0):
		var cx: float = rng.randf_range(0.1, w - 0.1)
		var cy: float = rng.randf_range(0.05, rise * 0.8)
		var r: float = rng.randf_range(0.1, 0.26)
		var q := PackedVector2Array()
		var tilt: float = rng.randf() * TAU
		for k: int in 5:
			var a: float = tilt + TAU * float(k) / 5.0 + rng.randf_range(-0.3, 0.3)
			q.append(Vector2(clampf(cx + cos(a) * r, 0.0, w), cy + sin(a) * r * 0.7))
		DoodadKit.shape(p, q, CONC.lerp(CONC_DARK, rng.randf()).darkened(rng.randf_range(0.0, 0.2)))
	for k: int in 3:
		_rebar(p, Vector2(rng.randf_range(0.2, w - 0.2), rise * 0.6), PI * 0.5 + rng.randf_range(-0.7, 0.7), rng.randf_range(0.4, 0.8), rseed + k)


## A ticket kiosk, upright in its own coordinates (x 0 to 2.1, y 0 to 2.2) and drawn tipped over by `angle` about its foot: a rusted
## body with a ticket window (an open frame with bars, dark behind), a shelf, a canopy over it and a blank sign board hanging by
## one chain.
static func _kiosk_picture(p: DoodadPaint, at: Vector2, scale: float, angle: float) -> void:
	var function_turn := func(pts: PackedVector2Array) -> PackedVector2Array:
		var out := PackedVector2Array()
		for q: Vector2 in pts:
			out.append(at + (q * scale).rotated(angle))
		return out
	var body: PackedVector2Array = function_turn.call(DoodadKit.rect_pts(0.0, 0.0, 1.9, 1.9))
	DoodadKit.shape(p, body, STEEL.darkened(0.05))
	# The window: erased (see-through), a frame round it and bars across it.
	var window: PackedVector2Array = function_turn.call(DoodadKit.rect_pts(0.35, 0.95, 1.55, 1.6))
	p.erase_poly(window)
	p.polyline(window, 0.06, STEEL.darkened(0.35), true)
	for k: int in 5:
		var bx: float = 0.35 + 1.2 * float(k + 1) / 6.0
		var bar: PackedVector2Array = function_turn.call(PackedVector2Array([Vector2(bx, 0.97), Vector2(bx, 1.58)]))
		p.line(bar[0], bar[1], 0.025, STEEL.darkened(0.45))
	var shelf: PackedVector2Array = function_turn.call(DoodadKit.rect_pts(0.2, 0.84, 1.7, 0.95))
	DoodadKit.shape(p, shelf, CONC_DARK)
	# The panels below the window, rust blooming through the paint.
	var panel: PackedVector2Array = function_turn.call(DoodadKit.rect_pts(0.15, 0.12, 1.75, 0.76))
	DoodadKit.shape(p, panel, STEEL.darkened(0.15))
	var canopy: PackedVector2Array = function_turn.call(PackedVector2Array([Vector2(-0.15, 1.9), Vector2(2.05, 1.9), Vector2(1.9, 2.15), Vector2(0.0, 2.15)]))
	DoodadKit.shape(p, canopy, RUST.darkened(0.25))
	var board: PackedVector2Array = function_turn.call(DoodadKit.rect_pts(0.4, 2.2, 1.5, 2.55))
	DoodadKit.shape(p, board, WET.lightened(0.04))
	var chain: PackedVector2Array = function_turn.call(PackedVector2Array([Vector2(0.45, 2.15), Vector2(0.45, 2.2)]))
	p.line(chain[0], chain[1], 0.03, CABLE)
	p.speckle(at.x - 0.3, at.y, at.x + 2.2, at.y + 2.2, Color(RUST, 0.5), 40, 0.02, 0.06, 821)
	DoodadKit.stains(p, at.x - 0.3, at.y, at.x + 2.2, at.y + 2.2, Color(RUST, 0.45), 6, 0.35, 822)


static func _kiosk(s: DoodadArtSet) -> void:
	var b: Vector3 = s.box("medium")
	var k: float = b.y / 2.6
	var side: DoodadPaint = s.canvas(b.z, b.y)
	_foot_rubble(side, b.z, 0.55 * k, 830)
	_kiosk_picture(side, Vector2(b.z * 0.2, 0.42 * k), 1.05 * k, -0.42)
	_cable_tangle(side, b.z * 0.8, 0.45 * k, 0.6, 3, 831)
	_vines(side, Vector2(b.z * 0.3, 0.7 * k), Vector2(b.z * 0.7, 1.0 * k), 0.4, 832)
	DoodadKit.grime(side, 0.0, 0.0, b.z, b.y, 0.9, 833)
	s.add_picture("kiosk_side", side)
	var front: String = _mound(s, "kiosk_front", b.x, b.y, b.y * 0.5, b.y * 0.93, 840)
	var top: String = _mound_top(s, "kiosk_top", b.x, b.z, 841)
	var cards: Array[Dictionary] = [
		DoodadArtSet.front(front),
		DoodadArtSet.back(front),
		DoodadArtSet.top(top, [0.02, 0.02, 0.98, 0.98], 0.5),
		DoodadArtSet.card("x", 0.5, "kiosk_side", [0.0, 0.0, 1.0, 1.0]),
	]
	cards.append_array(DoodadArtSet.sides("kiosk_side"))
	s.add_design("medium", "toppled_kiosk", [STEEL, RUST, CONC_DARK], cards)


## A vending machine lying tipped against rubble: its glass front with rows of empty shelves open on the dark, a keypad and a slot
## that never lit, tipped over by a third of a right angle.
static func _vending(s: DoodadArtSet) -> void:
	var b: Vector3 = s.box("medium")
	var k: float = b.y / 2.6
	var side: DoodadPaint = s.canvas(b.z, b.y)
	_foot_rubble(side, b.z, 0.5 * k, 850)
	var at := Vector2(b.z * 0.18, 0.35 * k)
	var tip: float = -0.36
	var f := func(pts: PackedVector2Array) -> PackedVector2Array:
		var out := PackedVector2Array()
		for q: Vector2 in pts:
			out.append(at + (q * k).rotated(tip))
		return out
	var body: PackedVector2Array = f.call(DoodadKit.rect_pts(0.0, 0.0, 1.0, 2.3))
	DoodadKit.shape(side, body, RUST.darkened(0.2))
	# The glass front: erased, with five shelves across it (the opening between them see-through) and a few cans left.
	var glass_pts: PackedVector2Array = f.call(DoodadKit.rect_pts(0.08, 0.7, 0.7, 2.2))
	side.erase_poly(glass_pts)
	side.polyline(glass_pts, 0.05, STEEL.darkened(0.3), true)
	for i: int in 5:
		var y: float = 0.9 + 0.28 * float(i)
		var sh: PackedVector2Array = f.call(PackedVector2Array([Vector2(0.08, y), Vector2(0.7, y)]))
		side.line(sh[0], sh[1], 0.035, STEEL.darkened(0.4))
		if i % 2 == 0:
			var can: PackedVector2Array = f.call(DoodadKit.rect_pts(0.2 + 0.1 * float(i % 3), y + 0.02, 0.28 + 0.1 * float(i % 3), y + 0.2))
			DoodadKit.shape(side, can, TILE.darkened(0.3))
	# The keypad column and the dispensing slot.
	var pad: PackedVector2Array = f.call(DoodadKit.rect_pts(0.76, 1.3, 0.94, 2.0))
	DoodadKit.shape(side, pad, CONC_DARK)
	var slot: PackedVector2Array = f.call(DoodadKit.rect_pts(0.12, 0.15, 0.65, 0.5))
	side.erase_poly(slot)
	side.polyline(slot, 0.04, STEEL.darkened(0.4), true)
	DoodadKit.stains(side, at.x - 0.3, at.y, at.x + 2.4, at.y + 2.4, Color(RUST, 0.5), 6, 0.35, 851)
	_cable_tangle(side, b.z * 0.78, 0.5 * k, 0.55, 3, 852)
	_vines(side, Vector2(b.z * 0.55, 0.9 * k), Vector2(b.z * 0.85, 1.2 * k), 0.4, 853)
	DoodadKit.grime(side, 0.0, 0.0, b.z, b.y, 0.9, 854)
	s.add_picture("vending_side", side)
	var front: String = _mound(s, "vending_front", b.x, b.y, b.y * 0.5, b.y * 0.92, 860)
	var top: String = _mound_top(s, "vending_top", b.x, b.z, 861)
	var cards: Array[Dictionary] = [
		DoodadArtSet.front(front),
		DoodadArtSet.back(front),
		DoodadArtSet.top(top, [0.02, 0.02, 0.98, 0.98], 0.5),
		DoodadArtSet.card("x", 0.5, "vending_side", [0.0, 0.0, 1.0, 1.0]),
	]
	cards.append_array(DoodadArtSet.sides("vending_side"))
	s.add_design("medium", "toppled_vending_machine", [RUST, STEEL, CONC_DARK], cards)


# --- Large: fallen ceiling slabs -----------------------------------------------------------------------

## Slabs of cast concrete fallen from the ceiling and leaning on each other: three big ones at different angles on a shallow heap of
## their own rubble, the triangles between them open, rebar hanging out of their broken edges, a ceiling tile or two and a loop of
## cable hanging from the break above.
static func _slab_face(s: DoodadArtSet, name: String, l: float, h: float, rseed: int) -> String:
	var p: DoodadPaint = s.canvas(l, h)
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	var slabs: Array = [
		[l * 0.05, 0.1, l * 0.42, 0.62, 0.25],
		[l * 0.33, 0.12, l * 0.42, 1.6, 0.3],
		[l * 0.56, 0.1, l * 0.38, 0.95, 0.27],
	]
	for i: int in slabs.size():
		var sl: Array = slabs[i]
		var x: float = sl[0]
		var base_y: float = sl[1]
		var length: float = sl[2]
		var rise: float = sl[3] * (h / 2.6)
		var thick: float = sl[4]
		var ang: float = atan2(rise, length)
		var u := Vector2(cos(ang), sin(ang))
		var n := Vector2(-u.y, u.x)
		var a := Vector2(x, base_y)
		var pts := PackedVector2Array([a, a + u * length, a + u * length + n * thick, a + n * thick])
		# A broken, ragged upper end.
		var tip: Vector2 = a + u * length
		pts[1] = tip + u * 0.1 * rng.randf()
		pts[2] = tip + n * thick - u * 0.15 * rng.randf()
		if i == 1:
			pts[2] = tip + n * thick * 0.4
		DoodadKit.shape(p, pts, CONC.lerp(CONC_DARK, 0.2 * float(i)))
		p.line(pts[3] - u * 0.05, pts[0], 0.02, CONC.lightened(0.15))
		DoodadKit.stains(p, minf(pts[0].x, pts[3].x), minf(pts[0].y, pts[3].y), maxf(pts[1].x, pts[2].x), maxf(pts[1].y, pts[2].y),
			Color(WET, 0.5), 3, 0.3, rseed + 10 + i)
		for r: int in 3:
			_rebar(p, tip + n * thick * rng.randf_range(0.2, 0.8), ang + rng.randf_range(-0.4, 0.6), rng.randf_range(0.35, 0.7), rseed + 20 + i * 3 + r)
	# The heap under them, over their feet.
	var mound := PackedVector2Array([Vector2(0.0, 0.0), Vector2(l, 0.0)])
	for i: int in range(12, -1, -1):
		var x: float = l * float(i) / 12.0
		mound.append(Vector2(x, 0.25 + 0.35 * sin(PI * x / l) + rng.randf_range(-0.05, 0.08)))
	DoodadKit.shape(p, mound, WET.lightened(0.05))
	for i: int in int(l * 6.0):
		var cx: float = rng.randf_range(0.1, l - 0.1)
		var cy: float = rng.randf_range(0.06, 0.4)
		var r: float = rng.randf_range(0.1, 0.24)
		var q := PackedVector2Array()
		var tilt: float = rng.randf() * TAU
		for k: int in 5:
			var a: float = tilt + TAU * float(k) / 5.0 + rng.randf_range(-0.3, 0.3)
			q.append(Vector2(clampf(cx + cos(a) * r, 0.0, l), cy + sin(a) * r * 0.7))
		DoodadKit.shape(p, q, CONC.lerp(CONC_DARK, rng.randf()).darkened(rng.randf_range(0.0, 0.2)))
	# Ceiling tiles and a hanging loop of cable.
	for k: int in 2:
		var tx: float = rng.randf_range(0.5, l - 0.8)
		DoodadKit.shape(p, _turn(DoodadKit.rect_pts(tx, 0.3, tx + 0.5, 0.36), Vector2(tx, 0.3), rng.randf_range(-0.5, 0.5)), TILE.darkened(0.25))
	_cable_tangle(p, l * 0.5, h - 0.35 * (h / 2.6), 0.5, 3, rseed + 40)
	_vines(p, Vector2(l * 0.1, 0.6), Vector2(l * 0.5, 1.2), 0.5, rseed + 41)
	DoodadKit.grime(p, 0.0, 0.0, l, h, 1.0, rseed + 42)
	return s.add_picture(name, p)


static func _slabs(s: DoodadArtSet) -> void:
	var b: Vector3 = s.box("large")
	var side: String = _slab_face(s, "slabs_side", b.z, b.y, 900)
	var core: String = _slab_face(s, "slabs_core", b.z * 0.9, b.y, 910)
	var front: String = _mound(s, "slabs_front", b.x, b.y, b.y * 0.55, b.y * 0.95, 920)
	var top: String = _mound_top(s, "slabs_top", b.x, b.z, 921)
	var cards: Array[Dictionary] = [
		DoodadArtSet.front(front),
		DoodadArtSet.back(front),
		DoodadArtSet.top(top, [0.02, 0.02, 0.98, 0.98], 0.5),
		DoodadArtSet.card("x", 0.5, core, [0.05, 0.0, 0.95, 1.0]),
	]
	cards.append_array(DoodadArtSet.sides(side))
	s.add_design("large", "fallen_ceiling_slabs", [CONC, CONC_DARK, REBAR], cards)

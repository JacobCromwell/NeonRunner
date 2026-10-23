extends RefCounted
## The Ice Lab's doodad pictures (GDD §3 and §5, Zone 9; owner, October 21, 2026: "brain jars and other lab equipment", and "some jars hold a
## curled-up Octodog"; proposed: ice crystal clusters and crates of lab supplies; owner's request October 9, 2026: pictures on boxes):
##   small   a specimen jar with a brain in it (brain_jar), THE OCTODOG JAR (octodog_jar: the same jar with the Octodog curled up asleep
##           inside, in its own palette, never glowing: task Q5 makes some of them break open), a cryo tank on its cart (cryo_tank), a stack of
##           lab supply crates (supply_crates), a small cluster of ice crystals (crystal_cluster)
##   medium  two specimen jars on one base with a control column between them (twin_jars), a bank of server racks (server_rack), a lab bench
##           with its equipment under a gantry arm (lab_bench), a big cluster of ice crystals (crystal_cluster_big), a pallet of crates
##           (supply_pallet)
##   large   a row of specimen jars on a long bench (jar_row), a console bank with its screens (console_bank), a mound of ice crystals
##           (crystal_mound), stacks of supply crates (supply_stacks), a machine frozen in ice (frozen_machine)
## Frost-crusted steel, packed snow, ice, pale plastic, the pale dim cyan of the jars' liquid (matte paint here, never a light: the card
## shader is lit scenery and never emissive), a brain's pinkish grey; nothing is drawn to read as a hazard (no stripes, no signs, no
## faces, nothing orange or red but the Octodog's shut eyes' dark brown, which are matte). Every silhouette keeps near the box's full height,
## so nothing that stops the runner looks low enough to jump; the pictures are drawn to whatever box the zone's doodads have
## (MovementTuning.doodad_size), every size a share of its box's height, so `tools/godot.sh doodads --only=ice_lab` repaints them.
## The Octodog's look comes from OctodogModel's own constants (its tentacle greens), dimmed: the colour of the live one's green glow is a
## hazard's, and a sleeping one in a jar is scenery.
## DESIGN-TBD (docs/questions/q2.md item 9): which equipment, how many looks of each size and how they are drawn.

const STEEL := Color(0.22, 0.27, 0.34)
const STEEL_D := Color(0.12, 0.15, 0.2)
const STEEL_L := Color(0.4, 0.47, 0.56)
const ICE := Color(0.4, 0.64, 0.82)
const ICE_L := Color(0.76, 0.91, 0.98)
const ICE_D := Color(0.2, 0.38, 0.58)
const SNOW := Color(0.8, 0.87, 0.93)
const LIQUID := Color(0.5, 0.74, 0.8)
const BRAIN := Color(0.6, 0.5, 0.54)
const PLASTIC := Color(0.36, 0.47, 0.57)
const CABLE := Color(0.06, 0.07, 0.09)
const LED := Color(0.72, 0.86, 0.95)
const ENAMEL := Color(0.3, 0.37, 0.45)
const WOOD := Color(0.34, 0.3, 0.26)
## Pixels a metre of every picture here.
const PX_PER_M: float = 80.0


static func paint(s: DoodadArtSet) -> void:
	# 80 pixels a metre (the other zones' 96): the zone has fifteen looks, and at 96 its pictures wanted a 4096 atlas, twice the others' memory.
	s.px_per_m = PX_PER_M
	_small(s)
	_medium(s)
	_large(s)


# --- Shared pieces ------------------------------------------------------------------------------

static func _ink(c: Color) -> Color:
	return DoodadKit.ink(c)


## A bump of snow lying along a top edge from x0 to x1 at height y: a lumpy cap `h` tall, with a faint shade under it.
static func _snow_cap(p: DoodadPaint, x0: float, x1: float, y: float, h: float, rseed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	var pts := PackedVector2Array([Vector2(x0, y - 0.02)])
	var n: int = maxi(int((x1 - x0) / 0.14), 3)
	for i: int in n + 1:
		var t: float = float(i) / float(n)
		pts.append(Vector2(lerpf(x0, x1, t), y + h * (0.35 + 0.65 * sin(PI * t)) * rng.randf_range(0.6, 1.0)))
	pts.append(Vector2(x1, y - 0.02))
	DoodadKit.shape(p, pts, SNOW)
	p.line(Vector2(x0 + 0.04, y + 0.01), Vector2(x1 - 0.04, y + 0.01), 0.02, ICE.lerp(SNOW, 0.5))


## Frost over a rectangle: `count` small pale blots, only over paint.
static func _frost(p: DoodadPaint, x0: float, y0: float, x1: float, y1: float, count: int, rseed: int) -> void:
	p.speckle(x0, y0, x1, y1, Color(0.88, 0.94, 1.0, 0.45), count, 0.012, 0.045, rseed)
	DoodadKit.stains(p, x0, y0, x1, y1, Color(0.8, 0.9, 1.0, 0.18), maxi(count / 14, 1), 0.3, rseed + 3)


## An ice crystal: a pointed prism from base centre (bx, by), `w` wide, `h` tall, its tip leaning `lean` metres, two facets and a glint.
static func _crystal(p: DoodadPaint, bx: float, by: float, w: float, h: float, lean: float, shade: float = 0.0) -> void:
	var bl := Vector2(bx - w * 0.5, by)
	var br := Vector2(bx + w * 0.5, by)
	var bm := Vector2(bx + w * 0.08, by - 0.02)
	var sl := Vector2(bx - w * 0.5 + lean * 0.3, by + h * 0.72)
	var sr := Vector2(bx + w * 0.5 + lean * 0.3, by + h * 0.72)
	var tip := Vector2(bx + lean, by + h)
	var left: Color = ICE_L.darkened(shade)
	var right: Color = ICE.darkened(shade)
	p.poly(PackedVector2Array([bl, bm, tip, sl]), left)
	p.poly(PackedVector2Array([bm, br, sr, tip]), right)
	p.poly(PackedVector2Array([sl, tip, sr, Vector2(sr.x, sr.y - h * 0.18), Vector2(sl.x, sl.y - h * 0.12)]), left.lightened(0.12))
	p.polyline(PackedVector2Array([bl, sl, tip, sr, br]), DoodadKit.INK_W * 0.8, _ink(ICE_D), false)
	p.line(bm, tip, DoodadKit.INK_W * 0.5, ICE_D.lerp(ICE, 0.4))
	p.line(Vector2(bl.x + w * 0.12, by + h * 0.1), Vector2(sl.x + w * 0.1, sl.y), 0.018, Color(1, 1, 1, 0.55))


## A cluster of `count` crystals standing on a snow mound over x0 to x1, the tallest reaching `peak` metres, from a seed.
static func _cluster(p: DoodadPaint, x0: float, x1: float, peak: float, count: int, rseed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	var w: float = x1 - x0
	# The mound of snow and ice rubble the crystals grow from.
	var mound := PackedVector2Array([Vector2(x0, 0.0), Vector2(x1, 0.0)])
	var steps: int = maxi(int(w / 0.18), 5)
	for i: int in range(steps, -1, -1):
		var t: float = float(i) / float(steps)
		mound.append(Vector2(lerpf(x0, x1, t), 0.18 * sin(PI * t) * rng.randf_range(0.6, 1.1) + 0.06))
	DoodadKit.shape(p, mound, SNOW.darkened(0.08))
	# Crystals, the tallest in the middle, back ones first.
	var order: Array[int] = []
	for i: int in count:
		order.append(i)
	for k: int in count:
		var i: int = order[k]
		var t: float = (float(i) + 0.5) / float(count)
		var cx: float = lerpf(x0 + w * 0.1, x1 - w * 0.1, t) + rng.randf_range(-0.05, 0.05)
		var mid: float = 1.0 - absf(t - 0.5) * 1.5
		var h: float = peak * clampf(mid, 0.3, 1.0) * rng.randf_range(0.75, 1.0)
		if i == count / 2:
			h = peak
		var cw: float = clampf(h * 0.2, 0.18, 0.46)
		_crystal(p, cx, 0.05, cw, h, rng.randf_range(-0.18, 0.18) * h * 0.5, 0.0 if k % 2 == 0 else 0.1)
	# Small shards at the foot and a few glints.
	for i: int in count:
		_crystal(p, lerpf(x0 + 0.1, x1 - 0.1, rng.randf()), 0.05, 0.1, rng.randf_range(0.25, 0.45), rng.randf_range(-0.1, 0.1), 0.05)
	_snow_cap(p, x0 + w * 0.05, x1 - w * 0.05, 0.02, 0.1, rseed + 9)


## A cable from `a` to `b` sagging by `sag` metres, thickness `t`.
static func _cable(p: DoodadPaint, a: Vector2, b: Vector2, sag: float, t: float) -> void:
	var pts := PackedVector2Array()
	for i: int in 13:
		var f: float = float(i) / 12.0
		pts.append(a.lerp(b, f) + Vector2(0.0, -sag * 4.0 * f * (1.0 - f)))
	p.polyline(pts, t, CABLE)
	p.polyline(pts, t * 0.3, Color(0.3, 0.38, 0.48, 0.7))


## A plastic supply crate from (x0, y0) to (x1, y1): ribs, a lip, latches, a blank label plate, frost.
static func _crate(p: DoodadPaint, x0: float, y0: float, x1: float, y1: float, base: Color, rseed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	p.rect(x0, y0, x1, y1, base)
	p.rect(x0, y1 - 0.07, x1, y1, base.lightened(0.14))
	p.rect(x0, y0, x1, y0 + 0.05, base.darkened(0.25))
	var ribs: int = maxi(int((x1 - x0) / 0.16), 2)
	for i: int in ribs:
		var rx: float = lerpf(x0 + 0.05, x1 - 0.05, (float(i) + 0.5) / float(ribs))
		p.rect(rx - 0.012, y0 + 0.08, rx + 0.012, y1 - 0.1, base.darkened(0.2))
	for lx: float in [x0 + (x1 - x0) * 0.2, x1 - (x1 - x0) * 0.2]:
		p.rect(lx - 0.03, y1 - 0.2, lx + 0.03, y1 - 0.05, STEEL_D)
		p.rect(lx - 0.02, y1 - 0.18, lx + 0.02, y1 - 0.1, STEEL_L)
	p.rect((x0 + x1) * 0.5 - 0.1, (y0 + y1) * 0.5 - 0.06, (x0 + x1) * 0.5 + 0.1, (y0 + y1) * 0.5 + 0.06, Color(0.78, 0.84, 0.9))
	p.polyline(DoodadKit.rect_pts(x0, y0, x1, y1), DoodadKit.INK_W * 0.8, _ink(base), true)
	_frost(p, x0, y0, x1, y1, 14, rseed + 2)


## A server rack's front from (x0, y0) to (x1, y1): a dark frame, rows of units (some with vent slots), pale status lights.
static func _rack(p: DoodadPaint, x0: float, y0: float, x1: float, y1: float, rseed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	p.rect(x0, y0, x1, y1, STEEL_D)
	var rows: int = int((y1 - y0) / 0.11)
	for r: int in rows:
		var ry: float = y0 + 0.06 + float(r) * 0.11
		var tone: Color = STEEL.lerp(STEEL_L, rng.randf_range(0.0, 0.5)).darkened(0.1)
		p.rect(x0 + 0.05, ry, x1 - 0.05, ry + 0.09, tone)
		if rng.randf() < 0.5:
			for k: int in 6:
				var vx: float = lerpf(x0 + 0.12, x1 - 0.3, float(k) / 6.0)
				p.rect(vx, ry + 0.02, vx + 0.03, ry + 0.07, STEEL_D)
		if rng.randf() < 0.55:
			p.circle(x1 - 0.12, ry + 0.045, 0.014, LED, 8)
	p.polyline(DoodadKit.rect_pts(x0, y0, x1, y1), DoodadKit.INK_W, _ink(STEEL_D), true)
	_frost(p, x0, y0, x1, y1, 16, rseed + 4)


## A screen on a stand or a console: a dark bezel and a pale, dim readout (matte paint): bars, a waveform, rings or rows by seed.
static func _screen(p: DoodadPaint, x0: float, y0: float, x1: float, y1: float, rseed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	p.round_rect(x0, y0, x1, y1, 0.03, STEEL_D)
	var fx0: float = x0 + 0.05
	var fy0: float = y0 + 0.05
	var fx1: float = x1 - 0.05
	var fy1: float = y1 - 0.05
	p.rect(fx0, fy0, fx1, fy1, Color(0.2, 0.3, 0.36))
	var mark := Color(0.62, 0.8, 0.88)
	match rseed % 3:
		0:
			var n: int = maxi(int((fx1 - fx0) / 0.07), 3)
			for i: int in n:
				var h: float = (fy1 - fy0) * rng.randf_range(0.2, 0.85)
				var bx: float = fx0 + (float(i) + 0.2) * (fx1 - fx0) / float(n)
				p.rect(bx, fy0 + 0.02, bx + (fx1 - fx0) / float(n) * 0.6, fy0 + 0.02 + h, mark)
		1:
			var pts := PackedVector2Array()
			for i: int in 17:
				var f: float = float(i) / 16.0
				pts.append(Vector2(lerpf(fx0 + 0.03, fx1 - 0.03, f), (fy0 + fy1) * 0.5 + (fy1 - fy0) * 0.3 * sin(f * 11.0 + float(rseed))))
			p.polyline(pts, 0.016, mark)
		_:
			var cx: float = (fx0 + fx1) * 0.5
			var cy: float = (fy0 + fy1) * 0.5
			var r: float = minf(fx1 - fx0, fy1 - fy0) * 0.4
			p.polyline(DoodadPaint.ellipse_points(cx, cy, r, r, 20), 0.016, mark, true)
			p.polyline(DoodadPaint.ellipse_points(cx, cy, r * 0.55, r * 0.55, 16), 0.014, mark, true)
			p.line(Vector2(cx - r * 1.1, cy), Vector2(cx + r * 1.1, cy), 0.01, mark)
	p.polyline(DoodadKit.rect_pts(x0, y0, x1, y1), DoodadKit.INK_W * 0.7, _ink(STEEL_D), true)


## A brain: two lobes with a fissure, folds, a sheen and a stem, centred at (cx, cy), `rx` by `ry`.
static func _brain(p: DoodadPaint, cx: float, cy: float, rx: float, ry: float) -> void:
	p.ellipse(cx, cy - ry * 0.9, rx * 0.18, ry * 0.42, BRAIN.darkened(0.3), 10)
	p.ellipse(cx, cy, rx, ry, BRAIN.darkened(0.35), 24)
	p.ellipse(cx - 0.005, cy + 0.008, rx * 0.95, ry * 0.93, BRAIN, 24)
	p.ellipse(cx + rx * 0.2, cy - ry * 0.25, rx * 0.7, ry * 0.55, BRAIN.darkened(0.08), 20)
	var dark: Color = BRAIN.darkened(0.45)
	p.polyline(PackedVector2Array([Vector2(cx, cy + ry * 0.92), Vector2(cx + rx * 0.1, cy + ry * 0.2), Vector2(cx - rx * 0.06, cy - ry * 0.4),
		Vector2(cx + rx * 0.05, cy - ry * 0.85)]), 0.02, dark)
	for i: int in 6:
		var y: float = cy + ry * (-0.62 + float(i) * 0.25)
		var span: float = rx * sqrt(maxf(1.0 - pow((y - cy) / ry, 2.0), 0.05)) * 0.85
		var pts := PackedVector2Array()
		for k: int in 11:
			var f: float = float(k) / 10.0
			pts.append(Vector2(cx - span + f * span * 2.0, y + 0.025 * sin(f * 14.0 + float(i) * 1.7)))
		p.polyline(pts, 0.016, dark)
	p.ellipse(cx - rx * 0.4, cy + ry * 0.42, rx * 0.28, ry * 0.15, Color(1, 1, 1, 0.16), 12)
	p.polyline(DoodadPaint.ellipse_points(cx, cy, rx, ry, 24), DoodadKit.INK_W * 0.7, _ink(BRAIN), true)


## A curled-up Octodog asleep (GDD §9.4): a squashed mass of dim green with tentacles spiralling round it, its robot legs folded under it
## (dim metal), its three eyes shut (dark red-brown slits, matte); in OctodogModel's own greens, dimmed.
static func _octodog(p: DoodadPaint, cx: float, cy: float, r: float, rseed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	var base: Color = OctodogModel.TENTACLE_GREEN_BASE.darkened(0.2)
	var tip: Color = OctodogModel.TENTACLE_GREEN_TIP.darkened(0.45)
	var metal := Color(0.32, 0.36, 0.42)
	# The folded legs and chassis under the mass.
	p.round_rect(cx - r * 0.62, cy - r * 0.62, cx + r * 0.62, cy - r * 0.4, 0.03, metal)
	for sx: float in [-1.0, 1.0]:
		DoodadKit.shape(p, PackedVector2Array([Vector2(cx + sx * r * 0.5, cy - r * 0.5), Vector2(cx + sx * r * 0.78, cy - r * 0.72),
			Vector2(cx + sx * r * 0.62, cy - r * 0.86), Vector2(cx + sx * r * 0.46, cy - r * 0.84), Vector2(cx + sx * r * 0.5, cy - r * 0.66)]),
			metal.darkened(0.1))
	# The tentacles: spirals out of the mass round it, thinning, tips curled in.
	for i: int in 8:
		var a0: float = TAU * float(i) / 8.0 + rng.randf_range(-0.2, 0.2)
		var dir: float = 1.0 if i % 2 == 0 else -1.0
		var pts := PackedVector2Array()
		var steps: int = 14
		for k: int in steps + 1:
			var t: float = float(k) / float(steps)
			var ang: float = a0 + dir * t * PI * 1.45
			var rad: float = r * (0.55 + 0.62 * sin(t * PI * 0.9)) * (1.0 - 0.32 * t)
			pts.append(Vector2(cx + cos(ang) * rad, cy + sin(ang) * rad * 0.9))
		var w: float = r * 0.2
		for k: int in steps:
			var t: float = float(k) / float(steps)
			p.line(pts[k], pts[k + 1], lerpf(w, w * 0.2, t), _ink(base).lerp(base, 0.2))
		for k: int in steps:
			var t: float = float(k) / float(steps)
			p.line(pts[k], pts[k + 1], lerpf(w, w * 0.2, t) * 0.72, base.lerp(tip, t * t))
	p.ellipse(cx, cy + r * 0.05, r * 0.62, r * 0.46, _ink(base), 20)
	p.ellipse(cx, cy + r * 0.07, r * 0.58, r * 0.43, base.darkened(0.05), 20)
	p.ellipse(cx - r * 0.18, cy + r * 0.22, r * 0.3, r * 0.14, base.lightened(0.14), 12)
	for e: int in 3:
		var ex: float = cx + (float(e) - 1.0) * r * 0.22
		p.line(Vector2(ex - r * 0.07, cy + r * 0.1), Vector2(ex + r * 0.07, cy + r * 0.1), r * 0.035, Color(0.27, 0.08, 0.06))


## A specimen jar standing from y0 on a pedestal: the glass `w` wide and `h` tall with the pale liquid in it, bubbles, a glint, what it holds
## (`content`: 0 a brain, 1 the Octodog, 2 nothing), the lid and two hoses up to `top`, the pedestal's panel with its pale status lights.
static func _jar(p: DoodadPaint, cx: float, y0: float, w: float, h: float, top: float, content: int, rseed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	var x0: float = cx - w * 0.5
	var x1: float = cx + w * 0.5
	var foot: float = 0.5
	# Pedestal.
	var base_y: float = y0 - foot
	DoodadKit.shape(p, PackedVector2Array([Vector2(x0 - 0.12, base_y), Vector2(x1 + 0.12, base_y), Vector2(x1 + 0.12, base_y + 0.12),
		Vector2(x1 + 0.04, y0), Vector2(x0 - 0.04, y0), Vector2(x0 - 0.12, base_y + 0.12)]), STEEL)
	p.rect(x0 - 0.04, base_y + 0.2, x1 + 0.04, y0 - 0.08, STEEL_D)
	for i: int in 3:
		p.circle(x0 + 0.1 + float(i) * 0.1, base_y + 0.26, 0.015, LED, 8)
	p.rect(x1 - 0.32, base_y + 0.23, x1 - 0.06, base_y + 0.29, STEEL_L)
	# The glass and its liquid.
	var body: PackedVector2Array = DoodadPaint.round_rect_points(x0, y0, x1, y0 + h, 0.14)
	p.poly(body, LIQUID.darkened(0.3))
	p.vgrad(x0 + 0.02, y0 + 0.02, x1 - 0.02, y0 + h - 0.06, LIQUID.darkened(0.28), LIQUID.lightened(0.06))
	p.tint_over(x0, y0, x0 + w * 0.16, y0 + h, Color(0.05, 0.12, 0.18, 0.4))
	p.tint_over(x1 - w * 0.2, y0, x1, y0 + h, Color(0.03, 0.08, 0.14, 0.5))
	for i: int in 16:
		var by: float = y0 + 0.1 + (h - 0.3) * rng.randf()
		p.circle(lerpf(x0 + w * 0.15, x1 - w * 0.2, rng.randf()), by, rng.randf_range(0.012, 0.03), Color(0.9, 0.97, 1.0, 0.5), 8)
	match content:
		0:
			_brain(p, cx, y0 + h * 0.52, w * 0.34, w * 0.26)
			for k: int in 3:
				var tx: float = cx + (float(k) - 1.0) * w * 0.1
				p.polyline(PackedVector2Array([Vector2(tx, y0 + h * 0.52 + w * 0.2), Vector2(tx + 0.03 * (float(k) - 1.0), y0 + h * 0.8),
					Vector2(tx, y0 + h)]), 0.022, CABLE)
		1:
			_octodog(p, cx, y0 + h * 0.5, minf(w * 0.42, h * 0.3), rseed + 5)
	p.rect(x0 + w * 0.12, y0 + 0.2, x0 + w * 0.17, y0 + h - 0.35, Color(1, 1, 1, 0.22))
	p.rect(x1 - w * 0.17, y0 + 0.3, x1 - w * 0.14, y0 + h - 0.5, Color(1, 1, 1, 0.14))
	p.polyline(body, DoodadKit.INK_W * 0.9, _ink(LIQUID), true)
	# The lid, a ring and a dome, with two hoses up to the top edge.
	DoodadKit.shape(p, DoodadKit.rect_pts(x0 - 0.06, y0 + h, x1 + 0.06, y0 + h + 0.1), STEEL_L)
	var dome := PackedVector2Array()
	for k: int in 11:
		var a: float = PI * float(k) / 10.0
		dome.append(Vector2(cx + cos(a) * (w * 0.5 + 0.04), y0 + h + 0.1 + sin(a) * 0.14))
	DoodadKit.shape(p, dome, STEEL)
	for sx: float in [-1.0, 1.0]:
		var hose := PackedVector2Array([Vector2(cx + sx * w * 0.18, y0 + h + 0.2), Vector2(cx + sx * w * 0.22, (y0 + h + top) * 0.5),
			Vector2(cx + sx * w * 0.1, top - 0.02)])
		p.polyline(hose, 0.07, STEEL_D)
		p.polyline(hose, 0.03, STEEL_L.darkened(0.2))
	_frost(p, x0 - 0.12, base_y, x1 + 0.12, y0, 8, rseed + 1)
	_snow_cap(p, cx - w * 0.3, cx + w * 0.3, y0 + h + 0.22, 0.05, rseed + 2)


## A jar seen from above: the lid's round dome and the pedestal's outline beyond it, on a (w x d) canvas.
static func _jar_top(s: DoodadArtSet, name: String, size_class: String, content_color: Color) -> String:
	var b: Vector3 = s.box(size_class)
	var p: DoodadPaint = s.top_canvas(size_class)
	var cx: float = b.x * 0.5
	var cy: float = b.z * 0.5
	var r: float = minf(b.x, b.z) * 0.42
	DoodadKit.shape(p, DoodadPaint.ellipse_points(cx, cy, r + 0.12, r + 0.12, 28), STEEL.darkened(0.1))
	DoodadKit.shape(p, DoodadPaint.ellipse_points(cx, cy, r, r, 28), STEEL)
	p.circle(cx, cy, r * 0.55, STEEL_L, 20)
	p.circle(cx, cy, r * 0.18, content_color, 12)
	_snow_cap(p, cx - r * 0.5, cx + r * 0.5, cy, 0.06, 5)
	return s.add_picture(name, p)


# --- Small -----------------------------------------------------------------------------------------

static func _small(s: DoodadArtSet) -> void:
	var b: Vector3 = s.box("small")
	var top_at: float = 0.93
	for variant: Array in [["brain_jar", 0, 11], ["octodog_jar", 1, 23]]:
		var name: String = variant[0]
		var content: int = variant[1]
		var rseed: int = variant[2]
		var front: DoodadPaint = s.front_canvas("small")
		_jar(front, b.x * 0.5, 0.66, minf(b.x * 0.78, 1.0), 1.5, b.y - 0.04, content, rseed)
		var side: DoodadPaint = s.side_canvas("small")
		_jar(side, b.z * 0.5, 0.66, minf(b.z * 0.74, 1.0), 1.5, b.y - 0.04, content, rseed + 1)
		var fname: String = s.add_picture(name + "_front", front)
		var sname: String = s.add_picture(name + "_side", side)
		var tname: String = _jar_top(s, name + "_top", "small", Color(0.3, 0.38, 0.46))
		var cards: Array[Dictionary] = [DoodadArtSet.front(fname), DoodadArtSet.back(fname)]
		cards.append_array(DoodadArtSet.sides(sname))
		cards.append(DoodadArtSet.top(tname, [0.0, 0.0, 1.0, 1.0], top_at))
		s.add_design("small", name, [LIQUID, STEEL, BRAIN if content == 0 else OctodogModel.TENTACLE_GREEN_BASE.darkened(0.2)], cards)
	_cryo_tank(s)
	_crates_small(s)
	_cluster_look(s, "small", "crystal_cluster", 6, 2.55, 31)


static func _cryo_tank(s: DoodadArtSet) -> void:
	var b: Vector3 = s.box("small")
	var pics: Array[String] = []
	for face: int in 2:
		var p: DoodadPaint = s.front_canvas("small") if face == 0 else s.side_canvas("small")
		var w: float = b.x if face == 0 else b.z
		var cx: float = w * 0.5
		# A dewar: a tall rounded steel flask on a trolley, a valve block and a gauge at its shoulder, a hose, frost all over.
		var tank_w: float = minf(w * 0.72, 0.95)
		var body := DoodadPaint.round_rect_points(cx - tank_w * 0.5, 0.55, cx + tank_w * 0.5, 2.15, tank_w * 0.45)
		p.poly(body, STEEL_L.darkened(0.1))
		p.tint_over(cx - tank_w * 0.5, 0.55, cx - tank_w * 0.2, 2.15, Color(1, 1, 1, 0.12))
		p.tint_over(cx + tank_w * 0.15, 0.55, cx + tank_w * 0.5, 2.15, Color(0.02, 0.04, 0.08, 0.35))
		for yb: float in [0.9, 1.5]:
			p.rect(cx - tank_w * 0.5, yb, cx + tank_w * 0.5, yb + 0.06, STEEL_D)
		p.polyline(body, DoodadKit.INK_W, _ink(STEEL_L), true)
		# The neck, the valve block, the gauge, the hose to the top.
		DoodadKit.shape(p, DoodadKit.rect_pts(cx - 0.14, 2.15, cx + 0.14, 2.38), STEEL)
		DoodadKit.shape(p, DoodadKit.rect_pts(cx - 0.3, 2.3, cx + 0.3, 2.46), STEEL_D)
		p.circle(cx - 0.18, 2.52, 0.09, Color(0.76, 0.83, 0.88), 16)
		p.polyline(DoodadPaint.ellipse_points(cx - 0.18, 2.52, 0.09, 0.09, 16), 0.02, _ink(STEEL), true)
		var hose := PackedVector2Array([Vector2(cx + 0.2, 2.4), Vector2(cx + tank_w * 0.5 + 0.08, 2.1), Vector2(cx + tank_w * 0.45, 1.5),
			Vector2(cx + tank_w * 0.55, 0.85)])
		p.polyline(hose, 0.06, CABLE)
		p.line(Vector2(cx - 0.05, 2.46), Vector2(cx - 0.05, b.y - 0.04), 0.06, STEEL_D)
		# The trolley: a frame, two wheels.
		DoodadKit.shape(p, DoodadKit.rect_pts(cx - tank_w * 0.55, 0.32, cx + tank_w * 0.55, 0.55), STEEL)
		for wx: float in [-1.0, 1.0]:
			DoodadKit.wheel(p, cx + wx * tank_w * 0.4, 0.16, 0.16, Color(0.08, 0.09, 0.11), STEEL_L)
		_frost(p, cx - tank_w * 0.5, 0.3, cx + tank_w * 0.5, 2.4, 30, 41 + face)
		_snow_cap(p, cx - tank_w * 0.3, cx + tank_w * 0.3, 2.46, 0.06, 43 + face)
		pics.append(s.add_picture("cryo_tank_%s" % ("front" if face == 0 else "side"), p))
	var tp: DoodadPaint = s.top_canvas("small")
	DoodadKit.shape(tp, DoodadPaint.ellipse_points(b.x * 0.5, b.z * 0.5, minf(b.x, b.z) * 0.36, minf(b.x, b.z) * 0.36, 24), STEEL_L)
	tp.circle(b.x * 0.5, b.z * 0.5, minf(b.x, b.z) * 0.12, STEEL_D, 12)
	var top_name: String = s.add_picture("cryo_tank_top", tp)
	var cards: Array[Dictionary] = [DoodadArtSet.front(pics[0]), DoodadArtSet.back(pics[0])]
	cards.append_array(DoodadArtSet.sides(pics[1]))
	cards.append(DoodadArtSet.top(top_name, [0.0, 0.0, 1.0, 1.0], 0.93))
	s.add_design("small", "cryo_tank", [STEEL_L, STEEL_D, SNOW], cards)


static func _crates_small(s: DoodadArtSet) -> void:
	var b: Vector3 = s.box("small")
	var pics: Array[String] = []
	for face: int in 2:
		var p: DoodadPaint = s.front_canvas("small") if face == 0 else s.side_canvas("small")
		var w: float = b.x if face == 0 else b.z
		var rng := RandomNumberGenerator.new()
		rng.seed = 51 + face
		# A stack of four crates a little crooked, a strap round the stack, a rack's pallet at the foot, snow on top.
		DoodadKit.planks(p, 0.04, 0.0, w - 0.04, 0.14, WOOD, 0.07, 52)
		var y: float = 0.14
		for i: int in 4:
			var inset: float = rng.randf_range(0.0, 0.09)
			var h: float = 0.6 if i < 3 else b.y - 0.14 - 0.6 * 3.0 - 0.18
			_crate(p, 0.06 + inset, y, w - 0.06 - rng.randf_range(0.0, 0.09), y + h, PLASTIC.lerp(ENAMEL, 0.15 * float(i % 2)), 60 + i + face * 7)
			y += h
		p.rect(0.04, 1.0, w - 0.04, 1.05, STEEL_D)
		_snow_cap(p, 0.1, w - 0.1, y, 0.1, 54 + face)
		pics.append(s.add_picture("crates_%s" % ("front" if face == 0 else "side"), p))
	var tp: DoodadPaint = s.top_canvas("small")
	tp.rect(0.06, 0.06, b.x - 0.06, b.z - 0.06, SNOW.darkened(0.05))
	tp.rect(0.12, 0.12, b.x - 0.12, b.z - 0.12, PLASTIC.lightened(0.1))
	tp.polyline(DoodadKit.rect_pts(0.06, 0.06, b.x - 0.06, b.z - 0.06), DoodadKit.INK_W, _ink(PLASTIC), true)
	var top_name: String = s.add_picture("crates_top", tp)
	var cards: Array[Dictionary] = [DoodadArtSet.front(pics[0]), DoodadArtSet.back(pics[0])]
	cards.append_array(DoodadArtSet.sides(pics[1]))
	cards.append(DoodadArtSet.top(top_name, [0.0, 0.0, 1.0, 1.0], 1.0))
	s.add_design("small", "supply_crates", [PLASTIC, WOOD, SNOW], cards)


## A look of ice crystals on a mound, in any size class: front and back, both sides, and crossing cards inside the box so it has depth.
static func _cluster_look(s: DoodadArtSet, size_class: String, name: String, count: int, peak: float, rseed: int) -> void:
	var b: Vector3 = s.box(size_class)
	var front: DoodadPaint = s.front_canvas(size_class)
	_cluster(front, 0.03, b.x - 0.03, minf(peak, b.y - 0.05), count, rseed)
	var side: DoodadPaint = s.side_canvas(size_class)
	_cluster(side, 0.03, b.z - 0.03, minf(peak, b.y - 0.05), maxi(int(b.z / 0.5) + 1, count), rseed + 1)
	var fname: String = s.add_picture(name + "_front", front)
	var sname: String = s.add_picture(name + "_side", side)
	var inner: DoodadPaint = s.front_canvas(size_class)
	_cluster(inner, 0.03, b.x - 0.03, minf(peak, b.y - 0.05) * 0.9, count, rseed + 2)
	var iname: String = s.add_picture(name + "_core", inner)
	var inner_side: DoodadPaint = s.side_canvas(size_class)
	_cluster(inner_side, 0.03, b.z - 0.03, minf(peak, b.y - 0.05) * 0.9, maxi(int(b.z / 0.5) + 1, count), rseed + 3)
	var isname: String = s.add_picture(name + "_core_side", inner_side)
	var tp: DoodadPaint = s.top_canvas(size_class)
	tp.ellipse(b.x * 0.5, b.z * 0.5, b.x * 0.46, b.z * 0.46, SNOW.darkened(0.05), 24)
	for i: int in 9:
		_top_crystal(tp, b.x * (0.25 + 0.5 * fmod(float(i) * 0.37, 1.0)), b.z * (0.2 + 0.6 * fmod(float(i) * 0.61, 1.0)), 0.1 + 0.03 * float(i % 3))
	var top_name: String = s.add_picture(name + "_top", tp)
	var cards: Array[Dictionary] = [DoodadArtSet.front(fname), DoodadArtSet.back(fname), DoodadArtSet.card("z", 0.5, iname),
		DoodadArtSet.card("x", 0.5, isname)]
	cards.append_array(DoodadArtSet.sides(sname))
	cards.append(DoodadArtSet.top(top_name, [0.0, 0.0, 1.0, 1.0], 0.5))
	s.add_design(size_class, name, [ICE, ICE_L, SNOW], cards)


## A crystal seen end-on from above: a hexagon with a lighter middle.
static func _top_crystal(p: DoodadPaint, cx: float, cy: float, r: float) -> void:
	DoodadKit.shape(p, DoodadPaint.ellipse_points(cx, cy, r, r, 6), ICE)
	p.poly(DoodadPaint.ellipse_points(cx, cy, r * 0.55, r * 0.55, 6), ICE_L)


# --- Medium ---------------------------------------------------------------------------------------

static func _medium(s: DoodadArtSet) -> void:
	_twin_jars(s)
	_server_rack(s)
	_lab_bench(s)
	_cluster_look(s, "medium", "crystal_cluster_big", 9, 2.55, 71)
	_supply_pallet(s)


static func _twin_jars(s: DoodadArtSet) -> void:
	var b: Vector3 = s.box("medium")
	var front: DoodadPaint = s.front_canvas("medium")
	# The base's end and the first jar on it (its pedestal on the base, the glass above, the lid and hoses up to the top edge).
	DoodadKit.shape(front, DoodadKit.rect_pts(0.08, 0.0, b.x - 0.08, 0.55), STEEL)
	front.rect(0.18, 0.1, b.x - 0.18, 0.44, STEEL_D)
	_jar(front, b.x * 0.5, 1.05, 1.2, 1.2, b.y - 0.04, 0, 81)
	var side: DoodadPaint = s.side_canvas("medium")
	# One long base under both jars, a control column between them with a pale screen, the pipes joining them.
	DoodadKit.shape(side, DoodadKit.rect_pts(0.08, 0.0, b.z - 0.08, 0.55), STEEL)
	side.rect(0.2, 0.12, b.z - 0.2, 0.42, STEEL_D)
	for i: int in 8:
		side.circle(0.4 + float(i) * 0.4, 0.27, 0.016, LED, 8)
	var jx: Array[float] = [0.95, b.z - 0.95]
	DoodadKit.shape(side, DoodadKit.rect_pts(b.z * 0.5 - 0.22, 0.55, b.z * 0.5 + 0.22, 2.0), STEEL_D)
	_screen(side, b.z * 0.5 - 0.17, 1.25, b.z * 0.5 + 0.17, 1.7, 3)
	side.polyline(PackedVector2Array([Vector2(jx[0] + 0.6, 1.6), Vector2(b.z * 0.5 - 0.22, 1.55)]), 0.07, STEEL_D)
	side.polyline(PackedVector2Array([Vector2(b.z * 0.5 + 0.22, 1.55), Vector2(jx[1] - 0.6, 1.6)]), 0.07, STEEL_D)
	for k: int in 2:
		_jar(side, jx[k], 1.05, 1.2, 1.2, b.y - 0.04, 0, 82 + k)
	var fname: String = s.add_picture("twin_jars_front", front)
	var sname: String = s.add_picture("twin_jars_side", side)
	var tp: DoodadPaint = s.top_canvas("medium")
	DoodadKit.shape(tp, DoodadKit.rect_pts(0.15, 0.1, b.x - 0.15, b.z - 0.1), STEEL.darkened(0.1))
	for k: int in 2:
		var cy: float = jx[k]
		tp.circle(b.x * 0.5, b.z - cy, 0.55, STEEL_L, 20)
		tp.circle(b.x * 0.5, b.z - cy, 0.22, Color(0.3, 0.38, 0.46), 12)
	tp.rect(b.x * 0.5 - 0.2, b.z * 0.5 - 0.2, b.x * 0.5 + 0.2, b.z * 0.5 + 0.2, STEEL_D)
	var tname: String = s.add_picture("twin_jars_top", tp)
	var cards: Array[Dictionary] = [DoodadArtSet.front(fname), DoodadArtSet.back(fname)]
	cards.append_array(DoodadArtSet.sides(sname))
	cards.append(DoodadArtSet.top(tname, [0.0, 0.0, 1.0, 1.0], 0.93))
	s.add_design("medium", "twin_jars", [LIQUID, STEEL, BRAIN], cards)


static func _server_rack(s: DoodadArtSet) -> void:
	var b: Vector3 = s.box("medium")
	var front: DoodadPaint = s.front_canvas("medium")
	_rack(front, 0.06, 0.0, b.x * 0.5 - 0.04, b.y - 0.1, 91)
	_rack(front, b.x * 0.5 + 0.04, 0.0, b.x - 0.06, b.y - 0.1, 92)
	_cable(front, Vector2(b.x * 0.25, b.y - 0.1), Vector2(b.x * 0.75, b.y - 0.1), 0.12, 0.06)
	_snow_cap(front, 0.1, b.x - 0.1, b.y - 0.1, 0.08, 93)
	var side: DoodadPaint = s.side_canvas("medium")
	var bays: int = 3
	var bay_w: float = (b.z - 0.12) / float(bays)
	for i: int in bays:
		var x0: float = 0.06 + float(i) * bay_w
		side.rect(x0, 0.0, x0 + bay_w - 0.04, b.y - 0.12, STEEL.darkened(0.2))
		side.rect(x0 + 0.1, 0.12, x0 + bay_w - 0.14, b.y - 0.3, STEEL)
		for k: int in 9:
			var vy: float = 0.5 + float(k) * 0.2
			side.rect(x0 + 0.3, vy, x0 + bay_w - 0.34, vy + 0.04, STEEL_D)
		side.polyline(DoodadKit.rect_pts(x0, 0.0, x0 + bay_w - 0.04, b.y - 0.12), DoodadKit.INK_W, _ink(STEEL_D), true)
	side.rect(0.04, b.y - 0.22, b.z - 0.04, b.y - 0.1, STEEL_L.darkened(0.2))
	_cable(side, Vector2(0.3, b.y - 0.1), Vector2(b.z - 0.3, b.y - 0.1), 0.14, 0.06)
	_snow_cap(side, 0.1, b.z - 0.1, b.y - 0.1, 0.08, 94)
	_frost(side, 0.0, 0.0, b.z, b.y - 0.1, 40, 95)
	var fname: String = s.add_picture("racks_front", front)
	var sname: String = s.add_picture("racks_side", side)
	var tp: DoodadPaint = s.top_canvas("medium")
	tp.rect(0.04, 0.04, b.x - 0.04, b.z - 0.04, STEEL.darkened(0.15))
	tp.rect(0.2, 0.2, b.x - 0.2, b.z - 0.2, SNOW.darkened(0.1))
	for i: int in 6:
		tp.rect(0.3, 0.3 + float(i) * 0.55, b.x - 0.3, 0.38 + float(i) * 0.55, STEEL_D)
	var tname: String = s.add_picture("racks_top", tp)
	var cards: Array[Dictionary] = [DoodadArtSet.front(fname), DoodadArtSet.back(fname)]
	cards.append_array(DoodadArtSet.sides(sname))
	cards.append(DoodadArtSet.top(tname, [0.0, 0.0, 1.0, 1.0], 0.96))
	s.add_design("medium", "server_rack", [STEEL_D, STEEL, LED], cards)


static func _lab_bench(s: DoodadArtSet) -> void:
	var b: Vector3 = s.box("medium")
	var front: DoodadPaint = s.front_canvas("medium")
	# The bench's end: a cabinet under a worktop, and over it a fume hood the full height of the box (a back panel, a glass sash, a canopy and
	# posts, with a monitor on an arm inside), so the bench reads as tall as its box: too tall to jump, as the box is.
	_hood(front, 0.0, b.x, 1.05, b.y)
	DoodadKit.shape(front, DoodadKit.rect_pts(0.08, 0.0, b.x - 0.08, 0.95), ENAMEL)
	front.rect(0.16, 0.1, b.x - 0.16, 0.82, ENAMEL.darkened(0.2))
	front.rect(b.x * 0.5 - 0.02, 0.1, b.x * 0.5 + 0.02, 0.82, STEEL_D)
	DoodadKit.shape(front, DoodadKit.rect_pts(0.0, 0.95, b.x, 1.05), STEEL_L.darkened(0.15))
	_screen(front, 0.3, 1.4, 1.3, 2.1, 101)
	front.line(Vector2(0.8, 1.05), Vector2(0.8, 1.4), 0.06, STEEL_D)
	front.polyline(PackedVector2Array([Vector2(1.55, 1.05), Vector2(1.55, 2.3), Vector2(1.05, b.y - 0.06)]), 0.06, STEEL)
	DoodadKit.shape(front, DoodadKit.rect_pts(0.78, b.y - 0.2, 1.3, b.y - 0.06), STEEL_D)
	_frost(front, 0.0, 0.0, b.x, 1.05, 14, 102)
	_snow_cap(front, 0.0, b.x, 1.05, 0.05, 103)
	var side: DoodadPaint = s.side_canvas("medium")
	DoodadKit.shape(side, DoodadKit.rect_pts(0.04, 0.0, b.z - 0.04, 0.95), ENAMEL)
	for i: int in 6:
		var x0: float = 0.12 + float(i) * (b.z - 0.24) / 6.0
		side.rect(x0 + 0.04, 0.1, x0 + (b.z - 0.24) / 6.0 - 0.04, 0.82, ENAMEL.darkened(0.2 if i % 2 == 0 else 0.1))
		side.rect(x0 + 0.1, 0.5, x0 + 0.16, 0.56, STEEL_L)
	DoodadKit.shape(side, DoodadKit.rect_pts(0.0, 0.95, b.z, 1.05), STEEL_L.darkened(0.15))
	_hood(side, 0.0, b.z, 1.05, b.y)
	# Equipment along the worktop, inside the hood: two monitors, a centrifuge drum, a rack of vials, flasks.
	_screen(side, 0.3, 1.3, 1.2, 2.0, 105)
	_screen(side, 1.35, 1.3, 2.1, 1.9, 106)
	side.line(Vector2(0.75, 1.05), Vector2(0.75, 1.3), 0.06, STEEL_D)
	side.line(Vector2(1.72, 1.05), Vector2(1.72, 1.3), 0.06, STEEL_D)
	DoodadKit.shape(side, DoodadPaint.ellipse_points(2.8, 1.45, 0.4, 0.4, 20), STEEL_L)
	side.circle(2.8, 1.45, 0.24, STEEL_D, 16)
	DoodadKit.shape(side, DoodadKit.rect_pts(2.45, 1.05, 3.15, 1.2), STEEL)
	for k: int in 6:
		var vx: float = 3.25 + float(k) * 0.07
		side.rect(vx, 1.05, vx + 0.05, 1.45, Color(0.58, 0.74, 0.8, 0.9))
	for fx: float in [0.45, 0.62]:
		side.circle(fx, 2.15, 0.07, Color(0.6, 0.78, 0.84), 12)
		side.rect(fx - 0.02, 2.2, fx + 0.02, 2.3, Color(0.6, 0.78, 0.84))
	# The gantry arm over the bench up to the top, a hanging tray and a lamp.
	side.polyline(PackedVector2Array([Vector2(0.3, 1.05), Vector2(0.3, b.y - 0.1), Vector2(b.z - 0.5, b.y - 0.1), Vector2(b.z - 0.5, 1.6)]), 0.07, STEEL)
	DoodadKit.shape(side, DoodadKit.rect_pts(b.z - 1.1, 1.9, b.z - 0.5, 2.0), STEEL_L.darkened(0.1))
	for lx: float in [b.z - 1.0, b.z - 0.6]:
		_crate(side, lx - 0.1, 2.0, lx + 0.1, 2.25, PLASTIC, int(lx * 10.0))
	_frost(side, 0.0, 0.0, b.z, 2.6, 36, 107)
	_snow_cap(side, 0.1, b.z - 0.1, 1.05, 0.05, 108)
	var fname: String = s.add_picture("bench_front", front)
	var sname: String = s.add_picture("bench_side", side)
	var tp: DoodadPaint = s.top_canvas("medium")
	tp.rect(0.06, 0.06, b.x - 0.06, b.z - 0.06, STEEL_L.darkened(0.2))
	tp.rect(0.2, 0.2, b.x - 0.2, b.z - 0.2, SNOW.darkened(0.15))
	tp.circle(b.x * 0.5, b.z * 0.3, 0.4, STEEL_D, 16)
	var tname: String = s.add_picture("bench_top", tp)
	var cards: Array[Dictionary] = [DoodadArtSet.front(fname), DoodadArtSet.back(fname)]
	cards.append_array(DoodadArtSet.sides(sname))
	cards.append(DoodadArtSet.top(tname, [0.0, 0.0, 1.0, 1.0], 0.4))
	s.add_design("medium", "lab_bench", [ENAMEL, STEEL_L, LED], cards)


## A fume hood over a bench from x0 to x1, standing from y0 up to the top of the box y1: a dark back panel, a glass sash in three panes, steel
## posts at both ends and a canopy with vents along the top (the picture fills the box up to its top, so it reads as tall as it is).
static func _hood(p: DoodadPaint, x0: float, x1: float, y0: float, y1: float) -> void:
	DoodadKit.shape(p, DoodadKit.rect_pts(x0 + 0.04, y0, x1 - 0.04, y1 - 0.04), STEEL_D.darkened(0.1))
	var panes: int = maxi(roundi((x1 - x0) / 1.2), 1)
	var pw: float = (x1 - x0 - 0.3) / float(panes)
	for i: int in panes:
		var px: float = x0 + 0.15 + float(i) * pw
		p.rect(px + 0.03, y0 + 0.12, px + pw - 0.03, y1 - 0.55, Color(0.55, 0.74, 0.82, 0.16))
		p.rect(px + 0.1, y0 + 0.18, px + 0.16, y1 - 0.7, Color(0.8, 0.92, 0.97, 0.18))
		p.polyline(DoodadKit.rect_pts(px + 0.03, y0 + 0.12, px + pw - 0.03, y1 - 0.55), DoodadKit.INK_W, _ink(STEEL_D), true)
	DoodadKit.shape(p, DoodadKit.rect_pts(x0, y0, x0 + 0.12, y1), STEEL)
	DoodadKit.shape(p, DoodadKit.rect_pts(x1 - 0.12, y0, x1, y1), STEEL)
	DoodadKit.shape(p, DoodadKit.rect_pts(x0, y1 - 0.5, x1, y1), STEEL_L.darkened(0.12))
	for i: int in maxi(roundi((x1 - x0) / 0.3), 2):
		var vx: float = x0 + 0.2 + float(i) * 0.3
		if vx + 0.18 < x1 - 0.15:
			p.rect(vx, y1 - 0.32, vx + 0.18, y1 - 0.26, STEEL_D)
	_snow_cap(p, x0 + 0.04, x1 - 0.04, y1 - 0.04, 0.06, 109)


static func _supply_pallet(s: DoodadArtSet) -> void:
	var b: Vector3 = s.box("medium")
	var front: DoodadPaint = s.front_canvas("medium")
	var side: DoodadPaint = s.side_canvas("medium")
	for face: int in 2:
		var p: DoodadPaint = front if face == 0 else side
		var w: float = b.x if face == 0 else b.z
		var cols: int = 2 if face == 0 else 4
		var cw: float = (w - 0.2) / float(cols)
		DoodadKit.planks(p, 0.05, 0.0, w - 0.05, 0.14, WOOD, 0.07, 110 + face)
		for r: int in 4:
			for c: int in cols:
				var x0: float = 0.1 + float(c) * cw
				_crate(p, x0 + 0.02, 0.14 + 0.58 * float(r), x0 + cw - 0.02, 0.14 + 0.58 * float(r) + 0.56, PLASTIC.lerp(ENAMEL, 0.12 * float((r + c) % 3)), 120 + r * 5 + c + face * 31)
		# A wrap of pale film round the stack and a layer of snow on top; a pallet jack's handle leaning on it.
		p.rect(0.08, 1.35, w - 0.08, 1.42, Color(0.86, 0.92, 0.97, 0.35))
		p.rect(0.08, 0.7, w - 0.08, 0.76, Color(0.86, 0.92, 0.97, 0.3))
		_snow_cap(p, 0.08, w - 0.08, 0.14 + 0.58 * 4.0, 0.1, 130 + face)
		if face == 1:
			p.polyline(PackedVector2Array([Vector2(w - 0.3, 0.14), Vector2(w - 0.1, 1.6), Vector2(w - 0.12, b.y - 0.08)]), 0.06, STEEL)
	var fname: String = s.add_picture("pallet_front", front)
	var sname: String = s.add_picture("pallet_side", side)
	var tp: DoodadPaint = s.top_canvas("medium")
	tp.rect(0.05, 0.05, b.x - 0.05, b.z - 0.05, SNOW.darkened(0.04))
	for i: int in 8:
		tp.rect(0.1 + float(i % 2) * (b.x * 0.5 - 0.05), 0.1 + float(i / 2) * (b.z / 4.0), b.x * 0.5 - 0.05 + float(i % 2) * (b.x * 0.5 - 0.05), 0.1 + float(i / 2) * (b.z / 4.0) + b.z / 4.0 - 0.08, PLASTIC.lightened(0.1))
	var tname: String = s.add_picture("pallet_top", tp)
	var cards: Array[Dictionary] = [DoodadArtSet.front(fname), DoodadArtSet.back(fname)]
	cards.append_array(DoodadArtSet.sides(sname))
	cards.append(DoodadArtSet.top(tname, [0.0, 0.0, 1.0, 1.0], 0.9))
	s.add_design("medium", "supply_pallet", [PLASTIC, WOOD, SNOW], cards)


# --- Large ----------------------------------------------------------------------------------------

static func _large(s: DoodadArtSet) -> void:
	_jar_row(s)
	_console_bank(s)
	_cluster_look(s, "large", "crystal_mound", 13, 2.55, 141)
	_supply_stacks(s)
	_frozen_machine(s)


static func _jar_row(s: DoodadArtSet) -> void:
	var b: Vector3 = s.box("large")
	var front: DoodadPaint = s.front_canvas("large")
	_jar(front, b.x * 0.5, 0.66, 1.3, 1.5, b.y - 0.04, 0, 151)
	var side: DoodadPaint = s.side_canvas("large")
	DoodadKit.shape(side, DoodadKit.rect_pts(0.06, 0.0, b.z - 0.06, 0.42), STEEL)
	side.rect(0.2, 0.08, b.z - 0.2, 0.3, STEEL_D)
	for i: int in 14:
		side.circle(0.5 + float(i) * 0.45, 0.19, 0.015, LED, 8)
	var count: int = 3
	for k: int in count:
		var cx: float = (float(k) + 0.5) * b.z / float(count)
		_jar(side, cx, 0.66, 1.4, 1.5, b.y - 0.04, 0, 152 + k)
	# Pipes along the row between the lids, high up.
	side.polyline(PackedVector2Array([Vector2(0.1, b.y - 0.12), Vector2(b.z - 0.1, b.y - 0.12)]), 0.07, STEEL_D)
	var fname: String = s.add_picture("jar_row_front", front)
	var sname: String = s.add_picture("jar_row_side", side)
	var tp: DoodadPaint = s.top_canvas("large")
	DoodadKit.shape(tp, DoodadKit.rect_pts(0.1, 0.06, b.x - 0.1, b.z - 0.06), STEEL.darkened(0.1))
	for k: int in count:
		tp.circle(b.x * 0.5, (float(k) + 0.5) * b.z / float(count), 0.62, STEEL_L, 20)
		tp.circle(b.x * 0.5, (float(k) + 0.5) * b.z / float(count), 0.24, Color(0.3, 0.38, 0.46), 12)
	var tname: String = s.add_picture("jar_row_top", tp)
	var cards: Array[Dictionary] = [DoodadArtSet.front(fname), DoodadArtSet.back(fname)]
	cards.append_array(DoodadArtSet.sides(sname))
	cards.append(DoodadArtSet.top(tname, [0.0, 0.0, 1.0, 1.0], 0.93))
	s.add_design("large", "jar_row", [LIQUID, STEEL, BRAIN], cards)


static func _console_bank(s: DoodadArtSet) -> void:
	var b: Vector3 = s.box("large")
	var front: DoodadPaint = s.front_canvas("large")
	# The bank's end: a cabinet under a desk, a tall back panel of screens, a cable trunk across the top.
	DoodadKit.shape(front, DoodadKit.rect_pts(0.06, 0.0, b.x - 0.06, 1.0), ENAMEL)
	front.rect(0.14, 0.1, b.x - 0.14, 0.9, ENAMEL.darkened(0.2))
	DoodadKit.shape(front, DoodadKit.rect_pts(0.0, 1.0, b.x, 1.1), STEEL_L.darkened(0.15))
	DoodadKit.shape(front, DoodadKit.rect_pts(0.1, 1.1, b.x - 0.1, b.y - 0.1), STEEL_D)
	_screen(front, 0.2, 1.3, 0.95, 1.95, 161)
	_screen(front, 1.05, 1.3, 1.8, 1.95, 162)
	_screen(front, 0.6, 2.05, 1.4, 2.45, 163)
	_snow_cap(front, 0.1, b.x - 0.1, b.y - 0.1, 0.06, 164)
	var side: DoodadPaint = s.side_canvas("large")
	DoodadKit.shape(side, DoodadKit.rect_pts(0.04, 0.0, b.z - 0.04, 1.0), ENAMEL)
	for i: int in 12:
		var x0: float = 0.12 + float(i) * (b.z - 0.24) / 12.0
		side.rect(x0 + 0.03, 0.1, x0 + (b.z - 0.24) / 12.0 - 0.03, 0.9, ENAMEL.darkened(0.15 + 0.1 * float(i % 2)))
	DoodadKit.shape(side, DoodadKit.rect_pts(0.0, 1.0, b.z, 1.1), STEEL_L.darkened(0.15))
	DoodadKit.shape(side, DoodadKit.rect_pts(0.04, 1.1, b.z - 0.04, b.y - 0.1), STEEL_D)
	for i: int in 6:
		var x0: float = 0.2 + float(i) * (b.z - 0.4) / 6.0
		_screen(side, x0, 1.25, x0 + (b.z - 0.4) / 6.0 - 0.1, 2.1, 165 + i)
	for i: int in 6:
		var x0: float = 0.2 + float(i) * (b.z - 0.4) / 6.0
		if i % 2 == 0:
			_screen(side, x0 + 0.1, 2.2, x0 + (b.z - 0.4) / 6.0 - 0.2, 2.5, 175 + i)
	side.rect(0.04, b.y - 0.2, b.z - 0.04, b.y - 0.1, STEEL_L.darkened(0.2))
	_cable(side, Vector2(0.4, b.y - 0.1), Vector2(b.z - 0.4, b.y - 0.1), 0.14, 0.07)
	_snow_cap(side, 0.1, b.z - 0.1, b.y - 0.1, 0.06, 166)
	_frost(side, 0.0, 0.0, b.z, 1.1, 40, 167)
	var fname: String = s.add_picture("console_front", front)
	var sname: String = s.add_picture("console_side", side)
	var tp: DoodadPaint = s.top_canvas("large")
	tp.rect(0.04, 0.04, b.x - 0.04, b.z - 0.04, STEEL_L.darkened(0.25))
	tp.rect(0.2, 0.2, b.x - 0.2, b.z - 0.2, SNOW.darkened(0.12))
	var tname: String = s.add_picture("console_top", tp)
	var cards: Array[Dictionary] = [DoodadArtSet.front(fname), DoodadArtSet.back(fname)]
	cards.append_array(DoodadArtSet.sides(sname))
	cards.append(DoodadArtSet.top(tname, [0.0, 0.0, 1.0, 1.0], 0.96))
	s.add_design("large", "console_bank", [ENAMEL, STEEL_D, LED], cards)


static func _supply_stacks(s: DoodadArtSet) -> void:
	var b: Vector3 = s.box("large")
	var front: DoodadPaint = s.front_canvas("large")
	var side: DoodadPaint = s.side_canvas("large")
	for face: int in 2:
		var p: DoodadPaint = front if face == 0 else side
		var w: float = b.x if face == 0 else b.z
		var rng := RandomNumberGenerator.new()
		rng.seed = 181 + face
		var cols: int = 3 if face == 0 else 11
		var cw: float = (w - 0.1) / float(cols)
		DoodadKit.planks(p, 0.04, 0.0, w - 0.04, 0.14, WOOD, 0.07, 182 + face)
		for c: int in cols:
			var rows: int = 4 if c % 3 != 1 else 3
			if face == 1 and c % 4 == 2:
				rows = 4
			var x0: float = 0.05 + float(c) * cw
			for r: int in rows:
				var h: float = 0.58
				_crate(p, x0 + 0.02, 0.14 + h * float(r), x0 + cw - 0.02, 0.14 + h * float(r) + h - 0.02, PLASTIC.lerp(ENAMEL, rng.randf_range(0.0, 0.3)), 190 + c * 7 + r + face * 50)
			_snow_cap(p, x0 + 0.04, x0 + cw - 0.04, 0.14 + h_of(rows), 0.08, 200 + c)
		for k: int in cols:
			if k % 3 == 1:
				p.rect(0.05 + float(k) * cw, 0.8, 0.05 + float(k + 1) * cw, 0.86, Color(0.86, 0.92, 0.97, 0.3))
	var fname: String = s.add_picture("stacks_front", front)
	var sname: String = s.add_picture("stacks_side", side)
	var tp: DoodadPaint = s.top_canvas("large")
	tp.rect(0.05, 0.05, b.x - 0.05, b.z - 0.05, SNOW.darkened(0.05))
	for i: int in 22:
		tp.rect(0.12 + float(i % 2) * (b.x * 0.5 - 0.05), 0.1 + float(i / 2) * (b.z / 11.0), b.x * 0.5 - 0.1 + float(i % 2) * (b.x * 0.5 - 0.05), 0.1 + float(i / 2) * (b.z / 11.0) + b.z / 11.0 - 0.08, PLASTIC.lightened(0.1))
	var tname: String = s.add_picture("stacks_top", tp)
	var cards: Array[Dictionary] = [DoodadArtSet.front(fname), DoodadArtSet.back(fname)]
	cards.append_array(DoodadArtSet.sides(sname))
	cards.append(DoodadArtSet.top(tname, [0.0, 0.0, 1.0, 1.0], 0.9))
	s.add_design("large", "supply_stacks", [PLASTIC, WOOD, SNOW], cards)


static func h_of(rows: int) -> float:
	return 0.58 * float(rows)


static func _frozen_machine(s: DoodadArtSet) -> void:
	var b: Vector3 = s.box("large")
	var front: DoodadPaint = s.front_canvas("large")
	var side: DoodadPaint = s.side_canvas("large")
	var rng := RandomNumberGenerator.new()
	rng.seed = 211
	# The machine's end: a round tank face with bolted bands, a pipe stub, caught in a crust of ice with icicles under its dome.
	_machine_tank(front, b.x * 0.5, 1.28, b.x * 0.46, 1.28, 212)
	# The side: a long boiler on legs with a dome and stack, gauges, valve wheels, pipes, the lot under ice and snow.
	DoodadKit.shape(side, DoodadKit.rect_pts(0.5, 0.0, 0.8, 0.5), STEEL_D)
	DoodadKit.shape(side, DoodadKit.rect_pts(b.z - 0.8, 0.0, b.z - 0.5, 0.5), STEEL_D)
	var boiler := DoodadPaint.round_rect_points(0.2, 0.45, b.z - 0.2, 1.95, 0.5)
	side.poly(boiler, STEEL.lerp(ICE_D, 0.25))
	side.tint_over(0.2, 1.4, b.z - 0.2, 1.95, Color(1, 1, 1, 0.1))
	side.tint_over(0.2, 0.45, b.z - 0.2, 0.9, Color(0.02, 0.05, 0.1, 0.3))
	for bx: float in [1.1, 2.5, 3.9, 5.3]:
		side.rect(bx, 0.45, bx + 0.1, 1.95, STEEL_D)
	side.polyline(boiler, DoodadKit.INK_W, _ink(STEEL_D), true)
	DoodadKit.shape(side, DoodadKit.rect_pts(1.2, 1.95, 1.9, 2.4), STEEL)
	DoodadKit.shape(side, DoodadKit.rect_pts(4.4, 1.95, 4.75, b.y - 0.04), STEEL_D)
	DoodadKit.shape(side, DoodadKit.rect_pts(4.3, b.y - 0.14, 4.85, b.y - 0.04), STEEL)
	for gx: float in [1.65, 3.25]:
		side.circle(gx, 1.6, 0.14, Color(0.76, 0.83, 0.88), 16)
		side.polyline(DoodadPaint.ellipse_points(gx, 1.6, 0.14, 0.14, 16), 0.025, _ink(STEEL), true)
	for vx: float in [2.2, 4.0]:
		side.circle(vx, 1.0, 0.2, STEEL_L, 14)
		side.circle(vx, 1.0, 0.1, STEEL_D, 10)
	side.polyline(PackedVector2Array([Vector2(0.2, 1.2), Vector2(0.05, 1.2), Vector2(0.05, 2.3), Vector2(1.5, 2.3), Vector2(1.5, 2.4)]), 0.1, STEEL_D)
	side.polyline(PackedVector2Array([Vector2(b.z - 0.2, 1.2), Vector2(b.z - 0.05, 1.2), Vector2(b.z - 0.05, 2.5)]), 0.1, STEEL_D)
	# The ice crust: blocks of ice over the machine's top and one end, icicles hanging from the dome and the pipes, snow on top.
	for i: int in 14:
		var ix: float = 0.3 + (b.z - 0.6) * float(i) / 13.0
		var ih: float = 0.2 + 0.3 * rng.randf()
		DoodadKit.shape(side, PackedVector2Array([Vector2(ix - 0.2, 1.8), Vector2(ix + 0.2, 1.8), Vector2(ix + 0.12, 1.8 + ih), Vector2(ix - 0.08, 1.8 + ih * 1.1)]),
			ICE.lerp(ICE_L, rng.randf() * 0.5))
	for i: int in 16:
		var ix: float = 0.3 + (b.z - 0.6) * (float(i) + rng.randf()) / 16.0
		var il: float = 0.12 + 0.5 * rng.randf() * rng.randf()
		DoodadKit.shape(side, PackedVector2Array([Vector2(ix - 0.04, 1.95), Vector2(ix + 0.04, 1.95), Vector2(ix, 1.95 - il)]), ICE_L.darkened(0.05))
	_cluster_partial(side, 0.2, 1.0, 2.55, rseed_of(1))
	_cluster_partial(side, b.z - 1.0, b.z - 0.2, 2.2, rseed_of(2))
	_snow_cap(side, 0.4, b.z - 0.4, 2.15, 0.1, 213)
	_frost(side, 0.0, 0.0, b.z, 2.5, 50, 214)
	var fname: String = s.add_picture("machine_front", front)
	var sname: String = s.add_picture("machine_side", side)
	var tp: DoodadPaint = s.top_canvas("large")
	tp.rect(0.1, 0.2, b.x - 0.1, b.z - 0.2, SNOW.darkened(0.08))
	tp.rect(0.3, 0.6, b.x - 0.3, b.z - 0.6, ICE.lerp(SNOW, 0.4))
	var tname: String = s.add_picture("machine_top", tp)
	var cards: Array[Dictionary] = [DoodadArtSet.front(fname), DoodadArtSet.back(fname)]
	cards.append_array(DoodadArtSet.sides(sname))
	cards.append(DoodadArtSet.top(tname, [0.0, 0.0, 1.0, 1.0], 0.82))
	s.add_design("large", "frozen_machine", [STEEL, ICE, SNOW], cards)


static func rseed_of(i: int) -> int:
	return 220 + i


## A few crystals rising from the machine's top over x0 to x1, the tallest to `peak` (no mound of their own).
static func _cluster_partial(p: DoodadPaint, x0: float, x1: float, peak: float, rseed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	var n: int = 4
	for i: int in n:
		var cx: float = lerpf(x0, x1, (float(i) + 0.5) / float(n))
		var h: float = (peak - 1.95) * rng.randf_range(0.6, 1.0)
		_crystal(p, cx, 1.9, 0.22, h + 0.1, rng.randf_range(-0.12, 0.12))


## A tank seen end-on (its round face): a disc with bolted bands, a hatch wheel, caught in ice with icicles hanging from its crown.
static func _machine_tank(p: DoodadPaint, cx: float, cy: float, rx: float, ry: float, rseed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	DoodadKit.shape(p, DoodadKit.rect_pts(cx - rx * 0.5, 0.0, cx - rx * 0.3, 0.3), STEEL_D)
	DoodadKit.shape(p, DoodadKit.rect_pts(cx + rx * 0.3, 0.0, cx + rx * 0.5, 0.3), STEEL_D)
	DoodadKit.shape(p, DoodadPaint.ellipse_points(cx, cy, rx, ry, 40), STEEL.lerp(ICE_D, 0.25))
	p.tint_over(cx - rx, cy - ry, cx - rx * 0.4, cy + ry, Color(1, 1, 1, 0.1))
	p.tint_over(cx + rx * 0.4, cy - ry, cx + rx, cy + ry, Color(0.02, 0.05, 0.1, 0.35))
	for k: int in 3:
		var f: float = 1.0 - 0.28 * float(k)
		p.polyline(DoodadPaint.ellipse_points(cx, cy, rx * f, ry * f, 36), 0.04, STEEL_D, true)
	for k: int in 16:
		var a: float = TAU * float(k) / 16.0
		p.circle(cx + cos(a) * rx * 0.86, cy + sin(a) * ry * 0.86, 0.03, STEEL_L, 8)
	p.circle(cx, cy, rx * 0.22, STEEL_L, 20)
	p.circle(cx, cy, rx * 0.14, STEEL_D, 16)
	for k: int in 3:
		var a: float = TAU * float(k) / 3.0
		p.line(Vector2(cx, cy), Vector2(cx + cos(a) * rx * 0.3, cy + sin(a) * rx * 0.3), 0.04, STEEL_L)
	for i: int in 9:
		var ix: float = cx + (float(i) - 4.0) * rx * 0.2
		var iy: float = cy + ry * sqrt(maxf(1.0 - pow((ix - cx) / rx, 2.0), 0.0))
		var il: float = 0.15 + 0.3 * rng.randf()
		DoodadKit.shape(p, PackedVector2Array([Vector2(ix - 0.05, iy - 0.02), Vector2(ix + 0.05, iy - 0.02), Vector2(ix, iy - il)]), ICE_L)
	_cluster_partial(p, cx - rx * 0.5, cx + rx * 0.5, 2.55, rseed + 1)
	_snow_cap(p, cx - rx * 0.6, cx + rx * 0.6, cy + ry - 0.04, 0.1, rseed + 2)
	_frost(p, cx - rx, cy - ry, cx + rx, cy + ry, 30, rseed + 3)

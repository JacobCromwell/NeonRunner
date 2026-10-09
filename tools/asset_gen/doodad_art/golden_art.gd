extends RefCounted
## The Golden Zone's doodad pictures, outdoors and in the Golden Palace alike (GDD §5: decadent
## opulence in white, cream, red and gold; task G6: "gilded planters, fountains, statues on plinths";
## owner's request October 9, 2026: pictures on the boxes, open air where the object is open):
##   small   a robed statue on a marble plinth, or a gilded urn with a clipped topiary on a pedestal
##           (by look seed)
##   medium  a wall fountain: a marble wall with three niches down the middle, water arcing from gold
##           spouts into a basin on each side
##   large   a colonnade: marble columns with gold capitals on a stepped base, a balustrade in every
##           bay, red drapes, and open air everywhere else
## The statue is its own figure, never the Gilded Sentinels' armoured guard with a halberd
## (GoldenStatue, task C4): faceless, draped, hands clasped, nothing held or raised. Gold is matte
## paint lit like everything else (never a glow); the water is a pale grey-blue, never cyan.

const GOLD := Color(0.78, 0.66, 0.42)
const GOLD_SHINE := Color(0.97, 0.93, 0.83)
const GOLD_DEEP := Color(0.52, 0.4, 0.22)
const RED := Color(0.44, 0.1, 0.12)
const MARBLE := Color(0.9, 0.86, 0.76)
const MARBLE_WHITE := Color(0.88, 0.87, 0.83)
const MARBLE_WARM := Color(0.85, 0.79, 0.67)
const WATER := Color(0.58, 0.68, 0.76)
const WATER_LIGHT := Color(0.88, 0.92, 0.95)
const SOIL := Color(0.26, 0.2, 0.15)
const STEM := Color(0.4, 0.3, 0.2)
const LEAVES: Array[Color] = [Color(0.2, 0.33, 0.22), Color(0.25, 0.39, 0.25), Color(0.31, 0.45, 0.29)]
const ROSE := Color(0.58, 0.13, 0.17)

## The statue's plinth, the urn's pedestal, and the urn itself to its lip, in metres.
const PLINTH_H: float = 0.7
const PEDESTAL_H: float = 0.3
const URN_H: float = 0.92
## The robe's outline as (height, half width) from the hem up to the shoulders, from the front and
## from the side.
const ROBE: Array[Vector2] = [Vector2(0.07, 0.3), Vector2(0.45, 0.26), Vector2(0.95, 0.225), Vector2(1.28, 0.235),
	Vector2(1.4, 0.17)]
const ROBE_SIDE: Array[Vector2] = [Vector2(0.07, 0.27), Vector2(0.45, 0.2), Vector2(0.95, 0.17), Vector2(1.28, 0.17),
	Vector2(1.4, 0.13)]
## The urn's outline as (height, half width) from its foot to its lip.
const URN: Array[Vector2] = [Vector2(0.0, 0.22), Vector2(0.09, 0.22), Vector2(0.13, 0.13), Vector2(0.22, 0.12),
	Vector2(0.32, 0.3), Vector2(0.52, 0.42), Vector2(0.72, 0.39), Vector2(0.8, 0.33), Vector2(0.84, 0.45),
	Vector2(URN_H, 0.45)]
## The fountain: the basin's rim, the wall down the middle (its half thickness), the wall's cornice,
## and the spouts' height.
const BASIN_H: float = 0.6
const WALL_HALF: float = 0.15
const CORNICE_Y: float = 2.3
const SPOUT_Y: float = 1.25
const NICHES: int = 3
## The colonnade: its stepped base, where the entablature starts, the columns' radius, its bays
## along the lane, and the bays whose curtains are tied back.
const STEPS_H: float = 0.3
const ENT_Y: float = 2.2
const COL_R: float = 0.12
const BAYS: int = 4
const CURTAIN_BAYS: Array[int] = [0, 3]


static func paint(s: DoodadArtSet) -> void:
	_statue(s)
	_urn(s)
	_fountain(s)
	_colonnade(s)


# --- Shared pieces --------------------------------------------------------------------------------

## Marble: `base` with a soft mottle and a few grey veins wandering across the rectangle.
static func _marble(p: DoodadPaint, x0: float, y0: float, x1: float, y1: float, base: Color, rseed: int) -> void:
	p.rect(x0, y0, x1, y1, base)
	p.mottle(x0, y0, x1, y1, 0.08, 0.035, rseed)
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	var vein := Color(base.darkened(0.3), 0.45)
	var count: int = int((x1 - x0) * (y1 - y0) * 1.2) + 1
	for i: int in count:
		var pt := Vector2(rng.randf_range(x0, x1), rng.randf_range(y0, y1))
		var a: float = rng.randf_range(-0.9, 0.9) + (PI if rng.randf() > 0.5 else 0.0)
		var pts := PackedVector2Array([pt])
		for k: int in 7:
			a += rng.randf_range(-0.5, 0.5)
			pt += Vector2(cos(a), sin(a)) * rng.randf_range(0.06, 0.16)
			pt = Vector2(clampf(pt.x, x0, x1), clampf(pt.y, y0, y1))
			pts.append(pt)
		p.polyline(pts, rng.randf_range(0.006, 0.012), vein)


## A gold moulding: a band with a light top, a shaded foot and a thin champagne shine along it.
static func _gold_band(p: DoodadPaint, x0: float, y0: float, x1: float, y1: float) -> void:
	DoodadKit.panel(p, x0, y0, x1, y1, GOLD, Color(0, 0, 0, 0), DoodadKit.INK_W * 0.6)
	var y: float = lerpf(y0, y1, 0.62)
	p.line(Vector2(x0, y), Vector2(x1, y), minf((y1 - y0) * 0.18, 0.012), Color(GOLD_SHINE, 0.8))


## A polygon between two outlines of a profile ((height, half width) pairs) about `cx`: from
## cx + half width × a up the profile, and back down at cx + half width × b.
static func _band(profile: Array[Vector2], cx: float, a: float, b: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for q: Vector2 in profile:
		pts.append(Vector2(cx + q.y * a, q.x))
	for i: int in range(profile.size() - 1, -1, -1):
		pts.append(Vector2(cx + profile[i].y * b, profile[i].x))
	return pts


## A profile's half width at height `y`.
static func _half_width(profile: Array[Vector2], y: float) -> float:
	for i: int in range(1, profile.size()):
		if y <= profile[i].x:
			return lerpf(profile[i - 1].y, profile[i].y, inverse_lerp(profile[i - 1].x, profile[i].x, y))
	return profile[profile.size() - 1].y


## A quadratic curve from `a` to `b` pulled toward `c`.
static func _curve(a: Vector2, c: Vector2, b: Vector2, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in steps + 1:
		var t: float = float(i) / float(steps)
		pts.append(a.lerp(c, t).lerp(c.lerp(b, t), t))
	return pts


## A plinth's face `w` wide and `h` tall: veined white marble between gold mouldings; a tall one
## also has a recessed panel with a blank gold plaque.
static func _plinth_face(s: DoodadArtSet, name: String, w: float, h: float, rseed: int) -> String:
	var p: DoodadPaint = s.canvas(w, h)
	_marble(p, 0.0, 0.0, w, h, MARBLE_WHITE, rseed)
	var foot: float = minf(0.1, h * 0.22)
	DoodadKit.panel(p, 0.0, 0.0, w, foot, MARBLE_WARM)
	_gold_band(p, 0.0, foot, w, foot + 0.035)
	_gold_band(p, 0.0, h - 0.09, w, h - 0.05)
	DoodadKit.panel(p, 0.0, h - 0.05, w, h, MARBLE_WHITE.lightened(0.04))
	if h >= 0.5:
		var m: float = 0.16
		var y0: float = foot + 0.1
		var y1: float = h - 0.17
		p.rect(m, y0, w - m, y1, MARBLE_WHITE.darkened(0.07))
		p.polyline(DoodadKit.rect_pts(m, y0, w - m, y1), 0.016, MARBLE_WHITE.darkened(0.4), true)
		var mid: float = (y0 + y1) * 0.5
		DoodadKit.round_rect_shape(p, w * 0.5 - 0.22, mid - 0.07, w * 0.5 + 0.22, mid + 0.07, 0.03, GOLD)
		p.line(Vector2(w * 0.5 - 0.16, mid + 0.025), Vector2(w * 0.5 + 0.16, mid + 0.025), 0.012, GOLD_SHINE)
	p.polyline(DoodadKit.rect_pts(0.0, 0.0, w, h), DoodadKit.INK_W, DoodadKit.ink(MARBLE_WHITE), true)
	return s.add_picture(name, p)


## A marble top `w` × `l` with a gold edge.
static func _marble_top(s: DoodadArtSet, name: String, w: float, l: float, rseed: int) -> String:
	var p: DoodadPaint = s.canvas(w, l)
	_marble(p, 0.0, 0.0, w, l, MARBLE_WHITE.lightened(0.03), rseed)
	p.polyline(DoodadKit.rect_pts(0.0, 0.0, w, l), 0.06, GOLD, true)
	return s.add_picture(name, p)


# --- Small: a statue on a plinth, a gilded urn ------------------------------------------------------

## A robed figure seen from the front, from its right side facing left (toward the runner), or from
## behind (`view` "front", "side" or "back"): a gold gown in long folds, a cowl over a face left in
## shadow, sleeves meeting over clasped hands, and a red sash knotted at the back. Faceless and
## empty-handed: nothing reads as the Sentinels' halberd guard.
static func _figure(s: DoodadArtSet, name: String, w: float, h: float, view: String) -> String:
	var p: DoodadPaint = s.canvas(w, h)
	var cx: float = w * 0.5
	var profile: bool = view == "side"
	var back: bool = view == "back"
	var robe: Array[Vector2] = ROBE_SIDE if profile else ROBE
	# The low gold base it stands on.
	DoodadKit.panel(p, cx - 0.36, 0.0, cx + 0.36, 0.08, GOLD_DEEP.lightened(0.15))
	var outline: PackedVector2Array = _band(robe, cx, -1.0, 1.0)
	p.poly(outline, GOLD)
	# Light from the upper left: a shaded band down the right, a sheen down the left.
	p.poly(_band(robe, cx, 0.4, 1.0), Color(GOLD_DEEP, 0.55))
	p.poly(_band(robe, cx, -0.8, -0.5), Color(GOLD_SHINE, 0.4))
	# Folds from the waist to the hem.
	for k: int in 5:
		var f: float = lerpf(-0.6, 0.6, float(k) / 4.0)
		p.line(Vector2(cx + f * 0.12, 0.85), Vector2(cx + f * 0.24, 0.1), 0.014, Color(GOLD_DEEP, 0.7))
	p.polyline(outline, DoodadKit.INK_W, DoodadKit.ink(GOLD), true)
	# The sash round the waist, and its end hanging from a knot.
	var sy0: float = 0.78
	var sy1: float = 0.87
	var hw0: float = _half_width(robe, sy0)
	var hw1: float = _half_width(robe, sy1)
	DoodadKit.shape(p, PackedVector2Array([Vector2(cx - hw0, sy0), Vector2(cx + hw0, sy0), Vector2(cx + hw1, sy1),
		Vector2(cx - hw1, sy1)]), RED)
	if back:
		for dir: float in [-1.0, 1.0]:
			DoodadKit.shape(p, PackedVector2Array([Vector2(cx, sy0 + 0.01), Vector2(cx + dir * 0.07, sy0 - 0.02),
				Vector2(cx + dir * 0.1, 0.4), Vector2(cx + dir * 0.05, 0.36), Vector2(cx + dir * 0.02, 0.42)]), RED)
		p.circle(cx, (sy0 + sy1) * 0.5, 0.05, RED.darkened(0.15))
	elif profile:
		DoodadKit.shape(p, PackedVector2Array([Vector2(cx + 0.12, sy0), Vector2(cx + 0.18, sy0), Vector2(cx + 0.24, 0.42),
			Vector2(cx + 0.19, 0.38), Vector2(cx + 0.15, 0.44)]), RED)
	# The cowl, its opening in shadow: no face.
	var hy: float = 1.6
	if back:
		DoodadKit.shape(p, DoodadPaint.ellipse_points(cx, hy, 0.16, 0.24, 24), GOLD)
		p.ellipse(cx + 0.08, hy, 0.06, 0.18, Color(GOLD_DEEP, 0.45))
		p.ellipse(cx - 0.08, hy + 0.06, 0.035, 0.12, Color(GOLD_SHINE, 0.35))
		p.line(Vector2(cx, hy + 0.2), Vector2(cx + 0.01, hy - 0.22), 0.014, GOLD_DEEP)
		# The cowl's fall over the shoulders.
		DoodadKit.shape(p, PackedVector2Array([Vector2(cx - 0.15, hy - 0.16), Vector2(cx + 0.15, hy - 0.16),
			Vector2(cx + 0.2, 1.24), Vector2(cx, 1.18), Vector2(cx - 0.2, 1.24)]), GOLD.darkened(0.04))
	elif profile:
		DoodadKit.shape(p, DoodadPaint.ellipse_points(cx + 0.02, hy, 0.15, 0.24, 24), GOLD)
		p.ellipse(cx + 0.07, hy - 0.02, 0.07, 0.17, Color(GOLD_DEEP, 0.5))
		p.ellipse(cx - 0.09, hy - 0.04, 0.05, 0.13, GOLD_DEEP.darkened(0.45))
	else:
		DoodadKit.shape(p, DoodadPaint.ellipse_points(cx, hy, 0.16, 0.24, 24), GOLD)
		p.ellipse(cx + 0.08, hy, 0.06, 0.18, Color(GOLD_DEEP, 0.45))
		p.ellipse(cx - 0.08, hy + 0.06, 0.035, 0.12, Color(GOLD_SHINE, 0.35))
		p.ellipse(cx, hy - 0.05, 0.085, 0.14, GOLD_DEEP.darkened(0.45))
	# The arms (hidden from behind): from the side, forearms folded across the chest; from the front,
	# wide sleeves meeting over the clasped hands.
	if profile:
		DoodadKit.shape(p, PackedVector2Array([Vector2(cx - 0.12, 1.26), Vector2(cx - 0.25, 1.08), Vector2(cx - 0.27, 0.95),
			Vector2(cx - 0.17, 0.9), Vector2(cx - 0.04, 0.98), Vector2(cx + 0.03, 1.22)]), GOLD.darkened(0.06))
		p.ellipse(cx - 0.27, 1.0, 0.045, 0.05, GOLD_SHINE.lerp(GOLD, 0.4))
	elif not back:
		DoodadKit.shape(p, PackedVector2Array([Vector2(cx - 0.24, 1.24), Vector2(cx - 0.27, 1.0), Vector2(cx - 0.2, 0.9),
			Vector2(cx + 0.2, 0.9), Vector2(cx + 0.27, 1.0), Vector2(cx + 0.24, 1.24), Vector2(cx + 0.13, 1.06),
			Vector2(cx - 0.13, 1.06)]), GOLD.darkened(0.05))
		p.line(Vector2(cx, 0.92), Vector2(cx, 1.03), 0.014, GOLD_DEEP)
		DoodadKit.shape(p, DoodadPaint.ellipse_points(cx, 1.05, 0.065, 0.05, 16), GOLD_SHINE.lerp(GOLD, 0.35))
	return s.add_picture(name, p)


static func _statue(s: DoodadArtSet) -> void:
	var b: Vector3 = s.box("small")
	var pv: float = PLINTH_H / b.y
	_plinth_face(s, "plinth_front", b.x, PLINTH_H, 31)
	_plinth_face(s, "plinth_side", b.z, PLINTH_H, 32)
	_marble_top(s, "plinth_top", b.x, b.z, 33)
	_figure(s, "statue_front", b.x, b.y - PLINTH_H, "front")
	_figure(s, "statue_side", b.z, b.y - PLINTH_H, "side")
	_figure(s, "statue_back", b.x, b.y - PLINTH_H, "back")
	var cards: Array[Dictionary] = [
		DoodadArtSet.front("plinth_front", [0.0, 0.0, 1.0, pv]),
		DoodadArtSet.back("plinth_front", [0.0, 0.0, 1.0, pv]),
		DoodadArtSet.top("plinth_top", [0.0, 0.0, 1.0, 1.0], pv),
		# The figure's front and back on two cards a hair apart: from each end the nearer one shows.
		DoodadArtSet.card("z", 0.51, "statue_front", [0.0, pv, 1.0, 1.0]),
		DoodadArtSet.card("z", 0.49, "statue_back", [0.0, pv, 1.0, 1.0], true),
		DoodadArtSet.card("x", 0.5, "statue_side", [0.0, pv, 1.0, 1.0]),
	]
	cards.append_array(DoodadArtSet.sides("plinth_side", [0.0, 0.0, 1.0, pv]))
	s.add_design("small", "robed_statue", [GOLD, MARBLE_WHITE, RED], cards)


## A gilded urn with a clipped topiary of three balls on a stem, `w` wide, from the urn's foot to the
## box's top: white marble with a gold foot, belly band, lip and handles; a few dark red roses.
static func _urn_picture(s: DoodadArtSet, name: String, w: float, h: float, rseed: int) -> String:
	var p: DoodadPaint = s.canvas(w, h)
	var cx: float = w * 0.5
	# The topiary first, so the urn's lip covers the stem's foot.
	p.line(Vector2(cx, URN_H - 0.05), Vector2(cx, 2.0), 0.06, STEM)
	var balls: Array[Vector2] = [Vector2(1.24, 0.33), Vector2(1.72, 0.24), Vector2(2.07, 0.15)]
	for i: int in balls.size():
		DoodadKit.foliage(p, cx, balls[i].x, balls[i].y, balls[i].y, LEAVES, rseed + i)
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	for k: int in 7:
		var a: float = rng.randf() * TAU
		var d: float = sqrt(rng.randf()) * 0.75
		var rx: float = cx + cos(a) * balls[0].y * d
		var ry: float = balls[0].x + sin(a) * balls[0].y * d
		p.circle(rx, ry, 0.04, ROSE)
		p.circle(rx - 0.012, ry + 0.012, 0.02, ROSE.lightened(0.25))
	# The urn, lit from the upper left.
	var outline: PackedVector2Array = _band(URN, cx, -1.0, 1.0)
	p.poly(outline, MARBLE_WHITE)
	p.mottle(cx - 0.45, 0.0, cx + 0.45, URN_H, 0.06, 0.035, rseed)
	p.poly(_band(URN, cx, 0.45, 1.0), Color(MARBLE_WHITE.darkened(0.3), 0.5))
	p.poly(_band(URN, cx, -0.8, -0.5), Color(1, 1, 1, 0.3))
	# The handles, then the gold foot, belly band and lip.
	for dir: float in [-1.0, 1.0]:
		var a0: float = PI * 0.5 if dir < 0.0 else -PI * 0.5
		DoodadKit.shape(p, DoodadPaint.arc_points(cx + dir * 0.39, 0.67, 0.1, 0.035, a0, a0 + PI, 12), GOLD)
	_gold_band(p, cx - 0.22, 0.0, cx + 0.22, 0.09)
	_gold_band(p, cx - _half_width(URN, 0.5), 0.5, cx + _half_width(URN, 0.5), 0.56)
	_gold_band(p, cx - 0.45, 0.84, cx + 0.45, URN_H)
	p.polyline(outline, DoodadKit.INK_W, DoodadKit.ink(MARBLE_WHITE), true)
	return s.add_picture(name, p)


## The urn's mouth from above: a gold lip round a disc of soil and the topiary's stem.
static func _urn_mouth(s: DoodadArtSet, name: String, w: float, l: float) -> String:
	var p: DoodadPaint = s.canvas(w, l)
	var cx: float = w * 0.5
	var cy: float = l * 0.5
	p.circle(cx, cy, 0.45, GOLD, 40)
	p.circle(cx, cy, 0.39, SOIL, 40)
	p.speckle(cx - 0.39, cy - 0.39, cx + 0.39, cy + 0.39, SOIL.lightened(0.25), 30, 0.015, 0.04, 9)
	p.circle(cx, cy, 0.04, STEM)
	p.polyline(DoodadPaint.ellipse_points(cx, cy, 0.45, 0.45, 40), 0.02, DoodadKit.ink(GOLD), true)
	return s.add_picture(name, p)


static func _urn(s: DoodadArtSet) -> void:
	var b: Vector3 = s.box("small")
	var pv: float = PEDESTAL_H / b.y
	_plinth_face(s, "pedestal_front", b.x, PEDESTAL_H, 41)
	_plinth_face(s, "pedestal_side", b.z, PEDESTAL_H, 42)
	_marble_top(s, "pedestal_top", b.x, b.z, 43)
	_urn_picture(s, "urn_a", b.x, b.y - PEDESTAL_H, 44)
	_urn_picture(s, "urn_b", b.z, b.y - PEDESTAL_H, 45)
	_urn_mouth(s, "urn_mouth", b.x, b.z)
	var cards: Array[Dictionary] = [
		DoodadArtSet.front("pedestal_front", [0.0, 0.0, 1.0, pv]),
		DoodadArtSet.back("pedestal_front", [0.0, 0.0, 1.0, pv]),
		DoodadArtSet.top("pedestal_top", [0.0, 0.0, 1.0, 1.0], pv),
		DoodadArtSet.card("z", 0.5, "urn_a", [0.0, pv, 1.0, 1.0]),
		DoodadArtSet.card("x", 0.5, "urn_b", [0.0, pv, 1.0, 1.0]),
		DoodadArtSet.top("urn_mouth", [0.0, 0.0, 1.0, 1.0], (PEDESTAL_H + URN_H - 0.03) / b.y),
	]
	cards.append_array(DoodadArtSet.sides("pedestal_side", [0.0, 0.0, 1.0, pv]))
	s.add_design("small", "gilded_urn", [MARBLE_WHITE, GOLD, LEAVES[1]], cards)


# --- Medium: a wall fountain ------------------------------------------------------------------------

## The basin's face from x0 to x1: marble between a plain foot and a gold rim, a gold running wave
## carved along it.
static func _basin(p: DoodadPaint, x0: float, x1: float, rseed: int) -> void:
	_marble(p, x0, 0.0, x1, BASIN_H, MARBLE, rseed)
	DoodadKit.panel(p, x0, 0.0, x1, 0.1, MARBLE_WARM)
	_gold_band(p, x0, BASIN_H - 0.09, x1, BASIN_H)
	p.line(Vector2(x0, 0.18), Vector2(x1, 0.18), 0.014, GOLD_DEEP)
	p.line(Vector2(x0, 0.42), Vector2(x1, 0.42), 0.014, GOLD_DEEP)
	var wave := PackedVector2Array()
	var steps: int = int((x1 - x0) / 0.02)
	for i: int in steps + 1:
		var x: float = lerpf(x0, x1, float(i) / float(steps))
		wave.append(Vector2(x, 0.3 + 0.06 * sin((x - x0) / 0.2 * PI)))
	p.polyline(wave, 0.035, GOLD)
	p.polyline(wave, 0.01, GOLD_SHINE)
	p.polyline(DoodadKit.rect_pts(x0, 0.0, x1, BASIN_H), DoodadKit.INK_W, DoodadKit.ink(MARBLE), true)


## The wall's cornice from x0 to x1: a gold moulding under a marble cap.
static func _cornice(p: DoodadPaint, x0: float, x1: float) -> void:
	_gold_band(p, x0, CORNICE_Y, x1, CORNICE_Y + 0.04)
	DoodadKit.panel(p, x0, CORNICE_Y + 0.04, x1, CORNICE_Y + 0.1, MARBLE_WHITE.lightened(0.05))


## A finial: a gold ball on a little marble block, from y0 up to y1.
static func _finial(p: DoodadPaint, cx: float, y0: float, y1: float) -> void:
	DoodadKit.panel(p, cx - 0.05, y0, cx + 0.05, y0 + 0.05, MARBLE_WHITE)
	var r: float = (y1 - y0 - 0.05) * 0.5
	var cy: float = y0 + 0.05 + r
	DoodadKit.shape(p, DoodadPaint.ellipse_points(cx, cy, r, r, 20), GOLD)
	p.circle(cx - r * 0.3, cy + r * 0.3, r * 0.35, GOLD_SHINE)


## The fountain's end: the basin's face across the whole width, and the wall's end standing up from
## its middle to the cornice and a finial. Open air either side.
static func _fountain_end(s: DoodadArtSet, name: String, rseed: int) -> String:
	var b: Vector3 = s.box("medium")
	var p: DoodadPaint = s.front_canvas("medium")
	var cx: float = b.x * 0.5
	_marble(p, cx - WALL_HALF, BASIN_H, cx + WALL_HALF, CORNICE_Y, MARBLE_WHITE, rseed)
	var inset: PackedVector2Array = DoodadKit.rect_pts(cx - WALL_HALF + 0.05, BASIN_H + 0.15, cx + WALL_HALF - 0.05, CORNICE_Y - 0.25)
	p.poly(inset, MARBLE_WHITE.darkened(0.06))
	p.polyline(inset, 0.012, MARBLE_WHITE.darkened(0.35), true)
	p.polyline(DoodadKit.rect_pts(cx - WALL_HALF, BASIN_H, cx + WALL_HALF, CORNICE_Y), DoodadKit.INK_W,
		DoodadKit.ink(MARBLE_WHITE), true)
	_cornice(p, cx - WALL_HALF - 0.05, cx + WALL_HALF + 0.05)
	_finial(p, cx, CORNICE_Y + 0.1, b.y - 0.02)
	_basin(p, 0.0, b.x, rseed + 1)
	return s.add_picture(name, p)


static func _basin_side(s: DoodadArtSet, name: String, rseed: int) -> String:
	var b: Vector3 = s.box("medium")
	var p: DoodadPaint = s.canvas(b.z, BASIN_H)
	_basin(p, 0.0, b.z, rseed)
	return s.add_picture(name, p)


## An arched niche centred on `nx` from `y0` up to its arch's crown `y1`, `hw` wide each side: a
## shaded recess, a gold shell in the arch, a gold spout, and the water falling from it.
static func _niche(p: DoodadPaint, nx: float, y0: float, y1: float, hw: float) -> void:
	var spring: float = y1 - hw
	var recess := PackedVector2Array([Vector2(nx - hw, y0), Vector2(nx + hw, y0), Vector2(nx + hw, spring)])
	for i: int in range(1, 16):
		var a: float = PI * float(i) / 16.0
		recess.append(Vector2(nx + cos(a) * hw, spring + sin(a) * hw))
	recess.append(Vector2(nx - hw, spring))
	DoodadKit.shape(p, recess, MARBLE_WHITE.darkened(0.22))
	p.rect(nx - hw + 0.03, y0, nx - hw + 0.08, spring, Color(MARBLE_WHITE.darkened(0.45), 0.4))
	# The shell: a gold fan with ribs.
	var sr: float = hw * 0.78
	var fan := PackedVector2Array([Vector2(nx + sr, spring)])
	for i: int in range(1, 16):
		var a: float = PI * float(i) / 16.0
		fan.append(Vector2(nx + cos(a) * sr, spring + sin(a) * sr))
	fan.append(Vector2(nx - sr, spring))
	DoodadKit.shape(p, fan, GOLD)
	for i: int in range(1, 7):
		var a: float = PI * float(i) / 7.0
		p.line(Vector2(nx, spring), Vector2(nx + cos(a) * sr * 0.95, spring + sin(a) * sr * 0.95), 0.012, GOLD_DEEP)
	# The fall of water from the spout into the basin, then the spout over it.
	var fall := PackedVector2Array([Vector2(nx - 0.035, SPOUT_Y - 0.02), Vector2(nx + 0.035, SPOUT_Y - 0.02),
		Vector2(nx + 0.065, BASIN_H - 0.02), Vector2(nx - 0.065, BASIN_H - 0.02)])
	DoodadKit.shape(p, fall, WATER, WATER.darkened(0.35), 0.012)
	p.line(Vector2(nx - 0.01, SPOUT_Y - 0.03), Vector2(nx - 0.02, BASIN_H), 0.012, WATER_LIGHT)
	var spout := PackedVector2Array()
	for i: int in 13:
		var a: float = PI + PI * float(i) / 12.0
		spout.append(Vector2(nx + cos(a) * 0.09, SPOUT_Y + 0.04 + sin(a) * 0.07))
	DoodadKit.shape(p, spout, GOLD)


## The wall down the fountain's middle, seen from either side: veined marble between pilasters, three
## arched niches each with a gold shell over a spout and its fall of water, a gold cornice, finials.
static func _fountain_wall(s: DoodadArtSet, name: String, rseed: int) -> String:
	var b: Vector3 = s.box("medium")
	var l: float = b.z
	var p: DoodadPaint = s.side_canvas("medium")
	_marble(p, 0.0, 0.0, l, CORNICE_Y, MARBLE_WHITE, rseed)
	DoodadKit.panel(p, 0.0, 0.0, l, BASIN_H + 0.1, MARBLE_WARM)
	var span: float = l / float(NICHES)
	for i: int in NICHES:
		_niche(p, span * (float(i) + 0.5), BASIN_H + 0.2, 2.05, 0.32)
	for i: int in NICHES + 1:
		var x: float = span * float(i)
		var x0: float = clampf(x - 0.1, 0.0, l)
		var x1: float = clampf(x + 0.1, 0.0, l)
		DoodadKit.panel(p, x0, BASIN_H + 0.1, x1, CORNICE_Y, MARBLE_WHITE.lightened(0.04))
		_gold_band(p, x0, CORNICE_Y - 0.12, x1, CORNICE_Y - 0.06)
		_finial(p, clampf(x, 0.1, l - 0.1), CORNICE_Y + 0.1, b.y - 0.02)
	_cornice(p, 0.0, l)
	p.polyline(DoodadKit.rect_pts(0.0, 0.0, l, CORNICE_Y + 0.1), DoodadKit.INK_W, DoodadKit.ink(MARBLE_WHITE), true)
	return s.add_picture(name, p)


## The arcs of water from the spouts on both of the wall's faces out into the basins, as seen from the
## front (the cards across the fountain at each niche).
static func _jets(s: DoodadArtSet, name: String) -> String:
	var b: Vector3 = s.box("medium")
	var p: DoodadPaint = s.front_canvas("medium")
	var cx: float = b.x * 0.5
	for dir: float in [-1.0, 1.0]:
		var x0: float = cx + dir * (WALL_HALF + 0.07)
		var x1: float = cx + dir * (b.x * 0.5 - 0.3)
		var arc := PackedVector2Array()
		var lift: float = 0.22
		for i: int in 17:
			var t: float = float(i) / 16.0
			arc.append(Vector2(lerpf(x0, x1, t), SPOUT_Y + lift * t - (lift + SPOUT_Y - BASIN_H) * t * t))
		p.polyline(arc, 0.085, WATER.darkened(0.3))
		p.polyline(arc, 0.065, WATER)
		p.polyline(arc, 0.022, WATER_LIGHT)
		# The splash where it lands.
		for j: int in 5:
			var a: float = lerpf(0.4, PI - 0.4, float(j) / 4.0)
			p.line(Vector2(x1, BASIN_H), Vector2(x1 + cos(a) * 0.11, BASIN_H + sin(a) * 0.09), 0.022, WATER_LIGHT)
		# The spout, seen end on: a gold lip out from the wall.
		var wx: float = cx + dir * WALL_HALF
		DoodadKit.shape(p, PackedVector2Array([Vector2(wx, SPOUT_Y - 0.05), Vector2(wx + dir * 0.09, SPOUT_Y - 0.01),
			Vector2(wx + dir * 0.09, SPOUT_Y + 0.03), Vector2(wx, SPOUT_Y + 0.09)]), GOLD)
	return s.add_picture(name, p)


## The basin from above: its marble rim round the edge, brim-full pale water with rings spreading where
## the jets land.
static func _fountain_water(s: DoodadArtSet, name: String) -> String:
	var b: Vector3 = s.box("medium")
	var p: DoodadPaint = s.top_canvas("medium")
	var rim: float = 0.12
	_marble(p, 0.0, 0.0, b.x, b.z, MARBLE, 51)
	p.rect(rim, rim, b.x - rim, b.z - rim, WATER)
	p.mottle(rim, rim, b.x - rim, b.z - rim, 0.12, 0.03, 52)
	for i: int in NICHES:
		var y: float = b.z * (float(i) + 0.5) / float(NICHES)
		for dir: float in [-1.0, 1.0]:
			var x: float = b.x * 0.5 + dir * (b.x * 0.5 - 0.3)
			for k: int in 3:
				var r: float = 0.06 + 0.07 * float(k)
				p.polyline(DoodadPaint.ellipse_points(x, y, r, r, 20), 0.014, Color(WATER_LIGHT, 0.8 - 0.2 * float(k)), true)
	p.polyline(DoodadKit.rect_pts(rim, rim, b.x - rim, b.z - rim), 0.02, MARBLE.darkened(0.35), true)
	return s.add_picture(name, p)


## The wall's cap from above: the cornice's marble with gold edges.
static func _fountain_cap(s: DoodadArtSet, name: String, w: float, rseed: int) -> String:
	var b: Vector3 = s.box("medium")
	var p: DoodadPaint = s.canvas(w, b.z)
	_marble(p, 0.0, 0.0, w, b.z, MARBLE_WHITE.lightened(0.05), rseed)
	p.polyline(DoodadKit.rect_pts(0.0, 0.0, w, b.z), 0.04, GOLD, true)
	return s.add_picture(name, p)


static func _fountain(s: DoodadArtSet) -> void:
	var b: Vector3 = s.box("medium")
	var bv: float = BASIN_H / b.y
	var wu: float = WALL_HALF / b.x
	var cap_w: float = (WALL_HALF + 0.05) * 2.0
	var cu: float = cap_w * 0.5 / b.x
	_fountain_end(s, "fountain_end", 61)
	_basin_side(s, "fountain_side", 62)
	_fountain_wall(s, "fountain_wall", 63)
	_jets(s, "fountain_jets")
	_fountain_water(s, "fountain_water")
	_fountain_cap(s, "fountain_cap", cap_w, 64)
	var cards: Array[Dictionary] = [
		DoodadArtSet.front("fountain_end"),
		DoodadArtSet.back("fountain_end"),
		DoodadArtSet.top("fountain_water", [0.0, 0.0, 1.0, 1.0], bv),
		DoodadArtSet.top("fountain_cap", [0.5 - cu, 0.0, 0.5 + cu, 1.0], (CORNICE_Y + 0.1) / b.y),
		DoodadArtSet.card("x", 0.5 + wu, "fountain_wall"),
		DoodadArtSet.card("x", 0.5 - wu, "fountain_wall", [0.0, 0.0, 1.0, 1.0], true),
	]
	cards.append_array(DoodadArtSet.sides("fountain_side", [0.0, 0.0, 1.0, bv]))
	for i: int in NICHES:
		cards.append(DoodadArtSet.card("z", 1.0 - (float(i) + 0.5) / float(NICHES), "fountain_jets"))
	s.add_design("medium", "wall_fountain", [MARBLE_WHITE, GOLD, WATER], cards)


# --- Large: a colonnade -----------------------------------------------------------------------------

## A column centred on `cx` from y0 to y1: a marble base, a fluted shaft lit from the left, and a gold
## capital with a scroll at each side.
static func _column(p: DoodadPaint, cx: float, y0: float, y1: float, r: float) -> void:
	var base_h: float = 0.14
	var cap_h: float = 0.2
	DoodadKit.panel(p, cx - r * 1.4, y0, cx + r * 1.4, y0 + base_h * 0.55, MARBLE_WARM)
	DoodadKit.round_rect_shape(p, cx - r * 1.2, y0 + base_h * 0.5, cx + r * 1.2, y0 + base_h, 0.03, MARBLE_WHITE)
	var flutes: int = 5
	var fw: float = r * 2.0 / float(flutes)
	for i: int in flutes:
		var t: float = (float(i) + 0.5) / float(flutes)
		var tone: Color = MARBLE_WHITE.lightened(0.12 * (1.0 - t)) if t < 0.5 else MARBLE_WHITE.darkened(0.3 * (t - 0.4))
		var fx: float = cx - r + fw * float(i)
		p.rect(fx, y0 + base_h, fx + fw, y1 - cap_h, tone)
		if i > 0:
			p.line(Vector2(fx, y0 + base_h), Vector2(fx, y1 - cap_h), 0.012, MARBLE_WHITE.darkened(0.35))
	p.polyline(DoodadKit.rect_pts(cx - r, y0 + base_h, cx + r, y1 - cap_h), DoodadKit.INK_W * 0.8,
		DoodadKit.ink(MARBLE_WHITE), true)
	DoodadKit.round_rect_shape(p, cx - r * 1.15, y1 - cap_h, cx + r * 1.15, y1 - cap_h * 0.45, 0.03, GOLD)
	DoodadKit.panel(p, cx - r * 1.55, y1 - cap_h * 0.45, cx + r * 1.55, y1, GOLD)
	for dir: float in [-1.0, 1.0]:
		var vx: float = cx + dir * r * 1.2
		var vy: float = y1 - cap_h * 0.5
		p.circle(vx, vy, cap_h * 0.26, GOLD_DEEP)
		p.circle(vx, vy, cap_h * 0.18, GOLD)
		p.circle(vx, vy, cap_h * 0.07, GOLD_DEEP)
	p.line(Vector2(cx - r * 1.4, y1 - cap_h * 0.12), Vector2(cx + r * 1.4, y1 - cap_h * 0.12), 0.012, GOLD_SHINE)


## A baluster centred on `cx` from y0 to y1, `bw` across: a vase shape in marble.
static func _baluster(p: DoodadPaint, cx: float, y0: float, y1: float, bw: float) -> void:
	var vase: Array[Vector2] = [Vector2(y0, 0.45 * bw), Vector2(lerpf(y0, y1, 0.08), 0.45 * bw),
		Vector2(lerpf(y0, y1, 0.14), 0.26 * bw), Vector2(lerpf(y0, y1, 0.38), 0.5 * bw), Vector2(lerpf(y0, y1, 0.66), 0.22 * bw),
		Vector2(lerpf(y0, y1, 0.8), 0.3 * bw), Vector2(lerpf(y0, y1, 0.88), 0.45 * bw), Vector2(y1, 0.45 * bw)]
	DoodadKit.shape(p, _band(vase, cx, -1.0, 1.0), MARBLE_WHITE, Color(0, 0, 0, 0), DoodadKit.INK_W * 0.6)
	p.poly(_band(vase, cx, 0.35, 0.9), Color(MARBLE_WHITE.darkened(0.3), 0.5))
	p.poly(_band(vase, cx, -0.75, -0.45), Color(1, 1, 1, 0.3))


## A balustrade from x0 to x1 between y0 and y1: a plinth and a handrail, with vase-shaped balusters
## and open air between them.
static func _balustrade(p: DoodadPaint, x0: float, x1: float, y0: float, y1: float) -> void:
	var rail: float = 0.1
	DoodadKit.panel(p, x0, y0, x1, y0 + 0.1, MARBLE_WARM)
	var bw: float = 0.13
	var gap: float = 0.07
	var n: int = maxi(int((x1 - x0 - gap) / (bw + gap)), 1)
	var span: float = (x1 - x0) / float(n)
	for i: int in n:
		_baluster(p, x0 + span * (float(i) + 0.5), y0 + 0.1, y1 - rail, bw)
	DoodadKit.panel(p, x0, y1 - rail, x1, y1, MARBLE_WHITE)


## The entablature from x0 to x1 between y0 and y1: a marble architrave, a gold frieze of rosettes,
## dentils, and a marble cornice.
static func _entablature(p: DoodadPaint, x0: float, x1: float, y0: float, y1: float) -> void:
	var h: float = y1 - y0
	DoodadKit.panel(p, x0, y0, x1, y0 + h * 0.32, MARBLE_WHITE)
	DoodadKit.panel(p, x0, y0 + h * 0.32, x1, y0 + h * 0.66, GOLD)
	var n: int = maxi(int((x1 - x0) / 0.32), 1)
	var span: float = (x1 - x0) / float(n)
	var fy: float = y0 + h * 0.49
	for i: int in n:
		var fx: float = x0 + span * (float(i) + 0.5)
		p.circle(fx, fy, h * 0.09, GOLD_DEEP)
		p.circle(fx - h * 0.015, fy + h * 0.015, h * 0.05, GOLD_SHINE)
		if i > 0:
			p.line(Vector2(x0 + span * float(i), y0 + h * 0.36), Vector2(x0 + span * float(i), y0 + h * 0.62), 0.014, GOLD_DEEP)
	DoodadKit.panel(p, x0, y0 + h * 0.66, x1, y1, MARBLE_WHITE.lightened(0.05))
	var dn: int = int((x1 - x0) / 0.07)
	for i: int in dn:
		var dx: float = x0 + (float(i) + 0.25) * (x1 - x0) / float(dn)
		p.rect(dx, y0 + h * 0.66, dx + 0.03, y0 + h * 0.74, MARBLE_WHITE.darkened(0.2))


## A swag of red cloth slung across a bay under the entablature from x0 to x1, `depth` deep at its
## middle, with a gold fringe.
static func _swag(p: DoodadPaint, x0: float, x1: float, y_top: float, depth: float) -> void:
	var steps: int = 20
	var hem := PackedVector2Array()
	for i: int in steps + 1:
		var t: float = 1.0 - float(i) / float(steps)
		hem.append(Vector2(lerpf(x0, x1, t), y_top - depth * (0.4 + 0.6 * sin(PI * t))))
	var cloth := PackedVector2Array([Vector2(x0, y_top), Vector2(x1, y_top)])
	cloth.append_array(hem)
	DoodadKit.shape(p, cloth, RED)
	for k: int in 2:
		var f: float = 0.45 + 0.25 * float(k)
		var fold := PackedVector2Array()
		for i: int in steps + 1:
			var t: float = float(i) / float(steps)
			fold.append(Vector2(lerpf(x0, x1, t), y_top - depth * f * (0.4 + 0.6 * sin(PI * t))))
		p.polyline(fold, 0.016, RED.darkened(0.35))
	p.polyline(hem, 0.035, GOLD)
	for i: int in range(0, hem.size(), 2):
		p.line(hem[i], hem[i] + Vector2(0.0, -0.05), 0.016, GOLD_DEEP)


## A curtain hung from `y_top` and tied back at `tie_y` against a column's edge at `x_tie`, falling to
## `y_floor`: at the top it hangs `reach` across the bay (toward +x when `dir` is 1).
static func _curtain(p: DoodadPaint, x_tie: float, reach: float, y_top: float, tie_y: float, y_floor: float, dir: float) -> void:
	var tw: float = 0.14
	var sweep: float = lerpf(tie_y, y_top, 0.6)
	var cloth := PackedVector2Array([Vector2(x_tie, y_floor), Vector2(x_tie, y_top)])
	cloth.append_array(_curve(Vector2(x_tie + dir * reach, y_top), Vector2(x_tie + dir * tw, sweep), Vector2(x_tie + dir * tw, tie_y), 12))
	cloth.append(Vector2(x_tie + dir * tw * 1.6, y_floor))
	DoodadKit.shape(p, cloth, RED)
	# Folds gathering into the tie and falling from it (each a scaled copy of the edge, so inside it).
	for k: int in 3:
		var f: float = (float(k) + 1.0) / 4.0
		p.polyline(_curve(Vector2(x_tie + dir * reach * f, y_top), Vector2(x_tie + dir * tw * f, sweep),
			Vector2(x_tie + dir * tw * f, tie_y), 10), 0.016, RED.darkened(0.35))
		p.line(Vector2(x_tie + dir * tw * f, tie_y), Vector2(x_tie + dir * tw * 1.6 * f, y_floor), 0.016, RED.darkened(0.35))
	p.polyline(_curve(Vector2(x_tie + dir * reach * 0.12, y_top), Vector2(x_tie + dir * tw * 0.12, sweep),
		Vector2(x_tie + dir * tw * 0.12, tie_y), 10), 0.02, RED.lightened(0.18))
	# The gold tie-back and its tassel.
	var tx: float = x_tie + dir * tw * 1.1
	DoodadKit.shape(p, DoodadKit.rect_pts(minf(x_tie, tx), tie_y - 0.03, maxf(x_tie, tx), tie_y + 0.03), GOLD)
	p.line(Vector2(tx, tie_y), Vector2(tx, tie_y - 0.12), 0.014, GOLD)
	DoodadKit.shape(p, PackedVector2Array([Vector2(tx - 0.03, tie_y - 0.12), Vector2(tx + 0.03, tie_y - 0.12),
		Vector2(tx + 0.045, tie_y - 0.22), Vector2(tx - 0.045, tie_y - 0.22)]), GOLD)


## A colonnade's face `l` long in `bays` bays: marble steps, a balustrade in every bay, curtains tied
## back in the bays listed in `curtains`, red swags under the entablature, columns between the bays.
static func _colonnade_face(s: DoodadArtSet, name: String, l: float, bays: int, curtains: Array[int], rseed: int) -> String:
	var b: Vector3 = s.box("large")
	var p: DoodadPaint = s.canvas(l, b.y)
	DoodadKit.panel(p, 0.0, 0.0, l, STEPS_H * 0.5, MARBLE_WARM)
	DoodadKit.panel(p, 0.0, STEPS_H * 0.5, l, STEPS_H, MARBLE)
	p.mottle(0.0, 0.0, l, STEPS_H, 0.08, 0.03, rseed)
	var c0: float = COL_R * 1.6
	var span: float = (l - 2.0 * c0) / float(bays)
	for i: int in bays:
		var bx0: float = c0 + span * float(i)
		var bx1: float = bx0 + span
		if curtains.has(i):
			_curtain(p, bx0 + COL_R, span * 0.42, ENT_Y, 1.25, STEPS_H + 0.02, 1.0)
			_curtain(p, bx1 - COL_R, span * 0.42, ENT_Y, 1.25, STEPS_H + 0.02, -1.0)
		_balustrade(p, bx0, bx1, STEPS_H, 1.0)
		_swag(p, bx0, bx1, ENT_Y, 0.38)
	for i: int in bays + 1:
		_column(p, c0 + span * float(i), STEPS_H, ENT_Y, COL_R)
	_entablature(p, 0.0, l, ENT_Y, b.y)
	return s.add_picture(name, p)


## The colonnade's floor from above: cream and white marble squares under a red carpet with gold edges
## down its length.
static func _colonnade_floor(s: DoodadArtSet, name: String) -> String:
	var b: Vector3 = s.box("large")
	var p: DoodadPaint = s.top_canvas("large")
	var tile: float = 0.5
	var nx: int = ceili(b.x / tile)
	var nz: int = ceili(b.z / tile)
	for i: int in nx:
		for j: int in nz:
			var c: Color = MARBLE_WHITE if (i + j) % 2 == 0 else MARBLE_WARM
			p.rect(tile * float(i), tile * float(j), tile * float(i + 1), tile * float(j + 1), c)
	p.mottle(0.0, 0.0, b.x, b.z, 0.08, 0.03, 81)
	var cx: float = b.x * 0.5
	p.rect(cx - 0.42, 0.0, cx + 0.42, b.z, RED)
	p.rect(cx - 0.36, 0.0, cx - 0.33, b.z, GOLD)
	p.rect(cx + 0.33, 0.0, cx + 0.36, b.z, GOLD)
	p.line(Vector2(cx - 0.42, 0.0), Vector2(cx - 0.42, b.z), 0.016, DoodadKit.ink(RED))
	p.line(Vector2(cx + 0.42, 0.0), Vector2(cx + 0.42, b.z), 0.016, DoodadKit.ink(RED))
	return s.add_picture(name, p)


## The colonnade's roof from above: the entablature's marble round the edge and a field of square
## coffers, each with a gold rosette, between gold-lined ribs.
static func _colonnade_top(s: DoodadArtSet, name: String) -> String:
	var b: Vector3 = s.box("large")
	var p: DoodadPaint = s.top_canvas("large")
	var rim: float = 0.22
	_marble(p, 0.0, 0.0, b.x, b.z, MARBLE_WHITE.lightened(0.05), 82)
	var x0: float = rim
	var x1: float = b.x - rim
	var z0: float = rim
	var z1: float = b.z - rim
	var across: int = 2
	var along: int = maxi(roundi((z1 - z0) / ((x1 - x0) / float(across))), 1)
	var cw: float = (x1 - x0) / float(across)
	var cl: float = (z1 - z0) / float(along)
	var rib: float = 0.06
	for i: int in across:
		for j: int in along:
			var cx0: float = x0 + cw * float(i) + rib
			var cz0: float = z0 + cl * float(j) + rib
			var cx1: float = x0 + cw * float(i + 1) - rib
			var cz1: float = z0 + cl * float(j + 1) - rib
			p.rect(cx0, cz0, cx1, cz1, MARBLE_WARM)
			p.rect(cx0 + 0.05, cz0 + 0.05, cx1 - 0.05, cz1 - 0.05, MARBLE_WARM.darkened(0.08))
			p.polyline(DoodadKit.rect_pts(cx0, cz0, cx1, cz1), 0.014, GOLD, true)
			var mx: float = (cx0 + cx1) * 0.5
			var mz: float = (cz0 + cz1) * 0.5
			p.circle(mx, mz, 0.09, GOLD_DEEP)
			p.circle(mx, mz, 0.065, GOLD)
			p.circle(mx - 0.015, mz + 0.015, 0.025, GOLD_SHINE)
	p.polyline(DoodadKit.rect_pts(x0 - 0.03, z0 - 0.03, x1 + 0.03, z1 + 0.03), 0.03, GOLD, true)
	p.polyline(DoodadKit.rect_pts(0.0, 0.0, b.x, b.z), DoodadKit.INK_W, DoodadKit.ink(MARBLE_WHITE), true)
	return s.add_picture(name, p)


static func _colonnade(s: DoodadArtSet) -> void:
	var b: Vector3 = s.box("large")
	var end_curtains: Array[int] = [0]
	_colonnade_face(s, "colonnade_side", b.z, BAYS, CURTAIN_BAYS, 71)
	_colonnade_face(s, "colonnade_end", b.x, 1, end_curtains, 72)
	_colonnade_floor(s, "colonnade_floor")
	_colonnade_top(s, "colonnade_top")
	var cards: Array[Dictionary] = DoodadArtSet.box_cards("colonnade_end", "colonnade_side", "colonnade_top")
	cards.append(DoodadArtSet.top("colonnade_floor", [0.0, 0.0, 1.0, 1.0], STEPS_H / b.y))
	s.add_design("large", "colonnade", [MARBLE_WHITE, GOLD, RED], cards)

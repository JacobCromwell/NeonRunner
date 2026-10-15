extends RefCounted
## The Marketplace's doodad pictures (owner, October 9, 2026: "a market vendor's stall or a cart drawn
## on top of the cube... a wooden base, supports in each of the corners, a little roof, and the middle
## where the goods are visible is just air"; GDD §5: a bustling, happy market in tan, whites and blue
## awnings with splashes of colour; GDD §3: plenty of plants and casino machines):
##   small   a potted palm in a glazed tile planter, or a flowering bush (by rseed)
##   medium  a vendor's stall: plank counter, corner posts, a striped little roof, produce on the
##           counter and a rail of fabrics inside, open air everywhere between
##   large   a bank of slot machines back to back, their reels and marquees toward both streets

const WOOD := Color(0.56, 0.39, 0.25)
const WOOD_LIGHT := Color(0.68, 0.5, 0.32)
const AWNING_BLUE := Color(0.22, 0.38, 0.63)
const AWNING_WHITE := Color(0.93, 0.91, 0.85)
const CLOTH_BLUE := Color(0.2, 0.3, 0.52)
const POT := Color(0.6, 0.43, 0.33)
const TILE_BLUE := Color(0.25, 0.4, 0.62)
const TILE_CREAM := Color(0.9, 0.86, 0.76)
const SOIL := Color(0.27, 0.2, 0.15)
const LEAVES: Array[Color] = [Color(0.33, 0.47, 0.29), Color(0.27, 0.4, 0.26), Color(0.42, 0.55, 0.33)]
const TRUNK := Color(0.45, 0.33, 0.22)
const FLOWERS: Array[Color] = [Color(0.6, 0.48, 0.74), Color(0.93, 0.9, 0.86), Color(0.45, 0.36, 0.66)]
const PRODUCE: Array[Color] = [Color(0.42, 0.25, 0.47), Color(0.85, 0.77, 0.42), Color(0.52, 0.6, 0.32),
	Color(0.62, 0.47, 0.32), Color(0.9, 0.86, 0.74)]
const FABRICS: Array[Color] = [Color(0.52, 0.42, 0.66), Color(0.9, 0.86, 0.76), Color(0.24, 0.32, 0.56),
	Color(0.72, 0.62, 0.42), Color(0.4, 0.28, 0.5)]
const CABINETS: Array[Color] = [Color(0.3, 0.2, 0.42), Color(0.17, 0.22, 0.38), Color(0.36, 0.24, 0.3)]
const GOLD := Color(0.76, 0.62, 0.32)
const CHROME := Color(0.74, 0.75, 0.78)
const REEL := Color(0.95, 0.93, 0.86)
const SCREEN_DARK := Color(0.1, 0.09, 0.14)


static func paint(s: DoodadArtSet) -> void:
	_palm(s)
	_bush(s)
	_stall(s)
	_slots(s)


# --- Small: plants in planters ---------------------------------------------------------------------

## The planter: a glazed box with a flared rim and a band of blue and cream tiles, `w` wide, 0.8 m tall.
static func _planter(s: DoodadArtSet, name: String, w: float, rseed: int) -> String:
	var h: float = 0.8
	var p: DoodadPaint = s.canvas(w, h)
	var x0: float = 0.1
	var x1: float = w - 0.1
	var body: PackedVector2Array = PackedVector2Array([Vector2(x0 + 0.06, 0.0), Vector2(x1 - 0.06, 0.0), Vector2(x1, 0.66), Vector2(x0, 0.66)])
	DoodadKit.shape(p, body, POT)
	p.rect(x0 + 0.05, 0.28, x1 - 0.05, 0.5, TILE_CREAM)
	var tiles: int = maxi(int((x1 - x0) / 0.16), 3)
	var tw: float = (x1 - x0 - 0.1) / float(tiles)
	for i: int in tiles:
		var cx: float = x0 + 0.05 + tw * (float(i) + 0.5)
		p.poly(PackedVector2Array([Vector2(cx, 0.31), Vector2(cx + tw * 0.4, 0.39), Vector2(cx, 0.47), Vector2(cx - tw * 0.4, 0.39)]), TILE_BLUE)
	p.line(Vector2(x0 + 0.05, 0.28), Vector2(x1 - 0.05, 0.28), 0.018, DoodadKit.ink(POT))
	p.line(Vector2(x0 + 0.05, 0.5), Vector2(x1 - 0.05, 0.5), 0.018, DoodadKit.ink(POT))
	DoodadKit.panel(p, x0 - 0.06, 0.64, x1 + 0.06, 0.8, POT.lightened(0.08))
	DoodadKit.grime(p, x0, 0.0, x1, 0.8, 0.6, rseed)
	return s.add_picture(name, p)


static func _soil(s: DoodadArtSet, name: String, w: float, l: float) -> String:
	var p: DoodadPaint = s.canvas(w, l)
	p.rect(0.0, 0.0, w, l, SOIL)
	p.speckle(0.0, 0.0, w, l, SOIL.lightened(0.25), 40, 0.02, 0.05, 11)
	return s.add_picture(name, p)


## A palm: a ringed trunk leaning a little, and arching fronds of leaflets filling the top.
static func _palm_picture(s: DoodadArtSet, name: String, w: float, h: float, rseed: int) -> String:
	var p: DoodadPaint = s.canvas(w, h)
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	var lean: float = rng.randf_range(-0.12, 0.12)
	var crown := Vector2(w * 0.5 + lean, h * 0.7)
	var base := Vector2(w * 0.5, 0.0)
	# The trunk: tapered, with rings.
	var trunk := PackedVector2Array([base + Vector2(-0.1, 0), base + Vector2(0.1, 0), crown + Vector2(0.06, 0), crown + Vector2(-0.06, 0)])
	DoodadKit.shape(p, trunk, TRUNK)
	var rings: int = 9
	for i: int in rings:
		var t: float = (float(i) + 0.5) / float(rings)
		var c: Vector2 = base.lerp(crown, t)
		var half: float = lerpf(0.1, 0.06, t)
		p.line(c + Vector2(-half, 0.02), c + Vector2(half, -0.02), 0.022, TRUNK.darkened(0.35))
	# Fronds: arcs of leaflets from the crown, out and drooping to both sides.
	var fronds: int = 11
	for k: int in fronds:
		var spread: float = lerpf(-1.0, 1.0, float(k) / float(fronds - 1))
		var up: float = 1.0 - absf(spread)
		var dir: float = PI * 0.5 - spread * 1.45 + rng.randf_range(-0.1, 0.1)
		var length: float = minf(w * 0.66, h * 0.5) * rng.randf_range(0.88, 1.05) * (0.85 + 0.15 * (1.0 - up))
		var color: Color = LEAVES[k % LEAVES.size()]
		var pts := PackedVector2Array()
		var steps: int = 10
		for i: int in steps + 1:
			var t: float = float(i) / float(steps)
			var a: float = dir - signf(spread) * t * t * 1.1 * absf(spread)
			if i == 0:
				pts.append(crown)
			else:
				pts.append(pts[i - 1] + Vector2(cos(a), sin(a)) * length / float(steps))
		for i: int in range(1, steps):
			var t: float = float(i) / float(steps)
			var a2: float = (pts[i + 1] - pts[i - 1]).angle()
			var ll: float = lerpf(0.36, 0.14, t) * length / 0.9
			DoodadKit.leaf(p, pts[i], a2 + 0.95, ll, ll * 0.32, color)
			DoodadKit.leaf(p, pts[i], a2 - 0.95, ll, ll * 0.32, color.darkened(0.08))
		p.polyline(pts, 0.025, color.darkened(0.4))
	p.circle(crown.x, crown.y, 0.07, TRUNK.darkened(0.2), 16)
	return s.add_picture(name, p)


static func _palm(s: DoodadArtSet) -> void:
	var b: Vector3 = s.box("small")
	var pot_v: float = 0.8 / b.y
	var plant_v0: float = 0.62 / b.y
	_planter(s, "palm_pot_front", b.x, 3)
	_planter(s, "palm_pot_side", b.z, 4)
	_soil(s, "palm_soil", b.x, b.z)
	_palm_picture(s, "palm_a", b.x, b.y - 0.62, 21)
	_palm_picture(s, "palm_b", b.z, b.y - 0.62, 22)
	var cards: Array[Dictionary] = [
		DoodadArtSet.front("palm_pot_front", [0.0, 0.0, 1.0, pot_v]),
		DoodadArtSet.back("palm_pot_front", [0.0, 0.0, 1.0, pot_v]),
		DoodadArtSet.top("palm_soil", [0.08, 0.08, 0.92, 0.92], 0.72 / b.y),
		DoodadArtSet.card("z", 0.5, "palm_a", [0.0, plant_v0, 1.0, 1.0]),
		DoodadArtSet.card("x", 0.5, "palm_b", [0.0, plant_v0, 1.0, 1.0]),
	]
	cards.append_array(DoodadArtSet.sides("palm_pot_side", [0.0, 0.0, 1.0, pot_v]))
	s.add_design("small", "potted_palm", [POT, LEAVES[0], TRUNK], cards)


## A flowering bush: a round mass of leaves dotted with violet and white flowers.
static func _bush_picture(s: DoodadArtSet, name: String, w: float, h: float, rseed: int) -> String:
	var p: DoodadPaint = s.canvas(w, h)
	DoodadKit.foliage(p, w * 0.5, h * 0.52, w * 0.5, h * 0.5, LEAVES, rseed)
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed + 5
	for i: int in 26:
		var a: float = rng.randf() * TAU
		var d: float = sqrt(rng.randf()) * 0.8
		var cx: float = w * 0.5 + cos(a) * w * 0.42 * d
		var cy: float = h * 0.52 + sin(a) * h * 0.42 * d
		var c: Color = FLOWERS[rng.randi_range(0, FLOWERS.size() - 1)]
		for k: int in 5:
			var pa: float = TAU * float(k) / 5.0
			p.circle(cx + cos(pa) * 0.035, cy + sin(pa) * 0.035, 0.03, c, 10)
		p.circle(cx, cy, 0.02, Color(0.88, 0.8, 0.5), 8)
	return s.add_picture(name, p)


static func _bush(s: DoodadArtSet) -> void:
	var b: Vector3 = s.box("small")
	var pot_v: float = 0.8 / b.y
	var plant_v0: float = 0.6 / b.y
	_planter(s, "bush_pot_front", b.x, 5)
	_planter(s, "bush_pot_side", b.z, 6)
	_bush_picture(s, "bush_a", b.x, b.y - 0.6, 31)
	_bush_picture(s, "bush_b", b.z, b.y - 0.6, 32)
	var cards: Array[Dictionary] = [
		DoodadArtSet.front("bush_pot_front", [0.0, 0.0, 1.0, pot_v]),
		DoodadArtSet.back("bush_pot_front", [0.0, 0.0, 1.0, pot_v]),
		DoodadArtSet.top("palm_soil", [0.08, 0.08, 0.92, 0.92], 0.72 / b.y),
		DoodadArtSet.card("z", 0.5, "bush_a", [0.0, plant_v0, 1.0, 1.0]),
		DoodadArtSet.card("x", 0.5, "bush_b", [0.0, plant_v0, 1.0, 1.0]),
	]
	cards.append_array(DoodadArtSet.sides("bush_pot_side", [0.0, 0.0, 1.0, pot_v]))
	s.add_design("small", "flowering_bush", [POT, LEAVES[1], FLOWERS[0]], cards)


# --- Medium: the vendor's stall --------------------------------------------------------------------

const COUNTER_TOP: float = 0.95
const ROOF_BOTTOM: float = 2.16
const POST_W: float = 0.1


## One face of the stall, `w` wide: the plank counter, posts at both ends (and in the middle of a
## long face), produce crates on the counter, things hanging from the roof beam, the striped valance;
## open air everywhere else.
static func _stall_face(s: DoodadArtSet, name: String, w: float, h: float, long_face: bool, rseed: int) -> String:
	var p: DoodadPaint = s.canvas(w, h)
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	# Posts first, so the goods and the counter overlap them.
	var posts: Array[float] = [0.02, w - 0.02 - POST_W]
	if long_face:
		posts.append(w * 0.5 - POST_W * 0.5)
	for x: float in posts:
		DoodadKit.post(p, x, COUNTER_TOP - 0.05, x + POST_W, ROOF_BOTTOM + 0.05, WOOD)
	# The counter: planks, a lighter top board, a cloth skirt along its upper half.
	DoodadKit.planks(p, 0.0, 0.0, w, COUNTER_TOP, WOOD, 0.16, rseed)
	p.stripes(0.06, COUNTER_TOP - 0.36, w - 0.06, COUNTER_TOP - 0.05, [CLOTH_BLUE, AWNING_WHITE], 0.14)
	var fringe: int = int((w - 0.12) / 0.07)
	for i: int in fringe:
		var fx: float = 0.06 + (float(i) + 0.5) * (w - 0.12) / float(fringe)
		p.poly(PackedVector2Array([Vector2(fx - 0.03, COUNTER_TOP - 0.36), Vector2(fx + 0.03, COUNTER_TOP - 0.36), Vector2(fx, COUNTER_TOP - 0.42)]), CLOTH_BLUE.darkened(0.15))
	DoodadKit.panel(p, -0.02, COUNTER_TOP - 0.05, w + 0.02, COUNTER_TOP + 0.03, WOOD_LIGHT)
	DoodadKit.grime(p, 0.0, 0.0, w, COUNTER_TOP - 0.4, 0.8, rseed + 3)
	# Goods: crates of produce along the counter, a basket here and there.
	var x: float = 0.16
	var item: int = 0
	while x < w - 0.5:
		var cw: float = rng.randf_range(0.42, 0.6)
		if x + cw > w - 0.14:
			break
		if item % 3 == 2:
			# A woven basket of round goods.
			var basket := PackedVector2Array([Vector2(x, COUNTER_TOP + 0.03), Vector2(x + cw, COUNTER_TOP + 0.03),
				Vector2(x + cw + 0.04, COUNTER_TOP + 0.22), Vector2(x - 0.04, COUNTER_TOP + 0.22)])
			DoodadKit.shape(p, basket, WOOD_LIGHT.lightened(0.1))
			for k: int in 3:
				p.line(Vector2(x - 0.02, COUNTER_TOP + 0.07 + 0.05 * float(k)), Vector2(x + cw + 0.02, COUNTER_TOP + 0.07 + 0.05 * float(k)), 0.012, WOOD.darkened(0.2))
			DoodadKit.produce(p, x - 0.02, x + cw + 0.02, COUNTER_TOP + 0.2, 0.055, PRODUCE, rseed + item)
		else:
			DoodadKit.crate(p, x, COUNTER_TOP + 0.03, x + cw, COUNTER_TOP + 0.27, WOOD_LIGHT)
			var pick: Array[Color] = [PRODUCE[(item + rseed) % PRODUCE.size()], PRODUCE[(item + rseed + 2) % PRODUCE.size()]]
			DoodadKit.produce(p, x, x + cw, COUNTER_TOP + 0.25, 0.06, pick, rseed + item * 7)
		x += cw + rng.randf_range(0.08, 0.16)
		item += 1
	# Hanging from the roof beam: paper lanterns and braids of garlic, swaying a little.
	var hangs: int = 1 if not long_face else 3
	for i: int in hangs:
		var hx: float = w * (float(i) + 1.0) / float(hangs + 1) + rng.randf_range(-0.08, 0.08)
		var drop: float = rng.randf_range(0.28, 0.42)
		p.line(Vector2(hx, ROOF_BOTTOM), Vector2(hx, ROOF_BOTTOM - drop + 0.1), 0.012, WOOD.darkened(0.4))
		if i % 2 == 0:
			p.ellipse(hx, ROOF_BOTTOM - drop, 0.11, 0.13, AWNING_WHITE.darkened(0.05), 20)
			for k: int in 3:
				p.line(Vector2(hx - 0.1, ROOF_BOTTOM - drop - 0.06 + 0.06 * float(k)), Vector2(hx + 0.1, ROOF_BOTTOM - drop - 0.06 + 0.06 * float(k)), 0.01, TILE_CREAM.darkened(0.25))
			p.rect(hx - 0.05, ROOF_BOTTOM - drop + 0.12, hx + 0.05, ROOF_BOTTOM - drop + 0.15, SCREEN_DARK)
			p.polyline(DoodadPaint.ellipse_points(hx, ROOF_BOTTOM - drop, 0.11, 0.13, 20), 0.018, DoodadKit.ink(AWNING_WHITE), true)
		else:
			for k: int in 5:
				p.circle(hx + (0.03 if k % 2 == 0 else -0.03), ROOF_BOTTOM - 0.1 - 0.065 * float(k), 0.045, Color(0.92, 0.89, 0.8), 12)
	# The roof's striped valance across the top, scalloped underneath.
	DoodadKit.valance(p, 0.0, w, h, h - ROOF_BOTTOM + 0.04, [AWNING_BLUE, AWNING_WHITE], 0.17)
	return s.add_picture(name, p)


## Inside the stall, down its middle: a rail of hanging fabrics over a shelf of jars (seen through the
## open sides and ends).
static func _stall_inside(s: DoodadArtSet, name: String, w: float, h: float, rseed: int) -> String:
	var p: DoodadPaint = s.canvas(w, h)
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	var rail: float = h - 0.12
	p.line(Vector2(0.1, rail), Vector2(w - 0.1, rail), 0.03, WOOD.darkened(0.2))
	var x: float = 0.18
	var i: int = 0
	while x < w - 0.35:
		var fw: float = rng.randf_range(0.18, 0.3)
		var fl: float = rng.randf_range(0.45, 0.75)
		var c: Color = FABRICS[(i + rseed) % FABRICS.size()]
		var cloth := PackedVector2Array([Vector2(x, rail), Vector2(x + fw, rail), Vector2(x + fw + 0.03, rail - fl),
			Vector2(x + fw * 0.5, rail - fl + 0.06), Vector2(x - 0.03, rail - fl)])
		DoodadKit.shape(p, cloth, c)
		p.line(Vector2(x + fw * 0.33, rail), Vector2(x + fw * 0.3, rail - fl + 0.05), 0.012, c.darkened(0.2))
		x += fw + rng.randf_range(0.18, 0.4)
		i += 1
	# A low shelf of jars just above the counter.
	DoodadKit.panel(p, 0.15, 0.1, w - 0.15, 0.16, WOOD_LIGHT)
	var jx: float = 0.25
	while jx < w - 0.3:
		var c: Color = PRODUCE[rng.randi_range(0, PRODUCE.size() - 1)]
		p.round_rect(jx, 0.16, jx + 0.12, 0.34, 0.03, c.lerp(AWNING_WHITE, 0.3))
		p.rect(jx + 0.02, 0.32, jx + 0.1, 0.36, WOOD.darkened(0.2))
		jx += rng.randf_range(0.16, 0.28)
	return s.add_picture(name, p)


static func _stall_top(s: DoodadArtSet, name: String, w: float, l: float) -> String:
	var p: DoodadPaint = s.canvas(w, l)
	p.stripes(0.0, 0.0, w, l, [AWNING_BLUE, AWNING_WHITE], 0.19, true)
	p.hgrad(0.0, 0.0, w * 0.5, l, Color(0, 0, 0, 0.2), Color(0, 0, 0, 0.0))
	p.line(Vector2(w * 0.5, 0.0), Vector2(w * 0.5, l), 0.03, DoodadKit.ink(AWNING_BLUE))
	p.polyline(DoodadKit.rect_pts(0.0, 0.0, w, l), DoodadKit.INK_W, DoodadKit.ink(AWNING_BLUE), true)
	DoodadKit.grime(p, 0.0, 0.0, w, l, 0.5, 41)
	return s.add_picture(name, p)


static func _stall(s: DoodadArtSet) -> void:
	var b: Vector3 = s.box("medium")
	_stall_face(s, "stall_front", b.x, b.y, false, 51)
	_stall_face(s, "stall_side", b.z, b.y, true, 52)
	_stall_top(s, "stall_top", b.x, b.z)
	var inside_v0: float = (COUNTER_TOP + 0.02) / b.y
	var inside_v1: float = ROOF_BOTTOM / b.y
	_stall_inside(s, "stall_inside", b.z, ROOF_BOTTOM - COUNTER_TOP - 0.02, 53)
	var cards: Array[Dictionary] = DoodadArtSet.box_cards("stall_front", "stall_side", "stall_top")
	cards.append(DoodadArtSet.card("x", 0.5, "stall_inside", [0.06, inside_v0, 0.94, inside_v1]))
	s.add_design("medium", "vendor_stall", [WOOD, AWNING_BLUE, AWNING_WHITE], cards)


# --- Large: a bank of slot machines ----------------------------------------------------------------

## A reel window's symbol: 0 a seven, 1 a bar, 2 a bell, 3 a pair of cherries (in plum, not red).
static func _symbol(p: DoodadPaint, kind: int, cx: float, cy: float, r: float) -> void:
	match kind:
		0:
			p.polyline(PackedVector2Array([Vector2(cx - r * 0.6, cy + r * 0.7), Vector2(cx + r * 0.6, cy + r * 0.7),
				Vector2(cx - r * 0.1, cy - r * 0.8)]), r * 0.32, TILE_BLUE)
		1:
			p.round_rect(cx - r * 0.75, cy - r * 0.3, cx + r * 0.75, cy + r * 0.3, r * 0.1, SCREEN_DARK)
			p.rect(cx - r * 0.55, cy - r * 0.08, cx + r * 0.55, cy + r * 0.08, REEL)
		2:
			var bell := PackedVector2Array([Vector2(cx - r * 0.7, cy - r * 0.55), Vector2(cx + r * 0.7, cy - r * 0.55),
				Vector2(cx + r * 0.45, cy + r * 0.3), Vector2(cx, cy + r * 0.75), Vector2(cx - r * 0.45, cy + r * 0.3)])
			DoodadKit.shape(p, bell, GOLD, Color(0, 0, 0, 0), 0.012)
			p.circle(cx, cy - r * 0.65, r * 0.16, GOLD.darkened(0.3), 8)
		_:
			for dx: float in [-0.35, 0.35]:
				p.circle(cx + r * dx, cy - r * 0.3, r * 0.33, Color(0.48, 0.18, 0.36), 12)
			p.polyline(PackedVector2Array([Vector2(cx - r * 0.35, cy), Vector2(cx, cy + r * 0.8), Vector2(cx + r * 0.35, cy)]), r * 0.1, LEAVES[0])


## One slot machine's front, `x0` to `x1`: cabinet, button deck, reel screen, top box and topper.
static func _slot_machine(p: DoodadPaint, x0: float, x1: float, h: float, cabinet: Color, rseed: int) -> void:
	var w: float = x1 - x0
	var cx: float = (x0 + x1) * 0.5
	# The arched topper with its bulbs.
	var topper := PackedVector2Array()
	topper.append(Vector2(x0 + w * 0.1, 2.12))
	for k: int in 17:
		var a: float = PI * float(k) / 16.0
		topper.append(Vector2(cx + cos(a) * w * 0.4, 2.12 + sin(a) * (h - 2.12 - 0.02)))
	topper.append(Vector2(x1 - w * 0.1, 2.12))
	DoodadKit.shape(p, topper, cabinet.lightened(0.1))
	for k: int in 11:
		var a: float = PI * (float(k) + 0.5) / 11.0
		p.circle(cx + cos(a) * w * 0.34, 2.14 + sin(a) * (h - 2.12 - 0.1), 0.03, REEL, 10)
	p.circle(cx, 2.26, 0.12, GOLD, 20)
	p.rect(cx - 0.05, 2.21, cx + 0.05, 2.31, SCREEN_DARK)
	# The cabinet body.
	DoodadKit.panel(p, x0, 0.0, x1, 2.14, cabinet)
	p.rect(x0, 0.0, x1, 0.12, cabinet.darkened(0.45))
	# Belly panel and coin tray.
	p.round_rect(x0 + w * 0.12, 0.2, x1 - w * 0.12, 0.66, 0.05, cabinet.lightened(0.2))
	p.circle(cx, 0.43, 0.13, GOLD, 22)
	p.circle(cx, 0.43, 0.09, cabinet.lightened(0.35), 18)
	DoodadKit.panel(p, x0 + w * 0.2, 0.68, x1 - w * 0.2, 0.76, CHROME)
	# The button deck, a little proud of the cabinet.
	DoodadKit.panel(p, x0 - 0.02, 0.86, x1 + 0.02, 0.98, CHROME.darkened(0.25))
	var buttons: Array[Color] = [REEL, TILE_BLUE.lightened(0.2), GOLD, Color(0.6, 0.5, 0.76)]
	for k: int in 4:
		p.round_rect(x0 + w * (0.14 + 0.19 * float(k)), 0.9, x0 + w * (0.28 + 0.19 * float(k)), 0.95, 0.015, buttons[k])
	# The reel screen: a chrome bezel, three reels showing a symbol each.
	p.round_rect(x0 + w * 0.08, 1.06, x1 - w * 0.08, 1.74, 0.06, CHROME)
	p.round_rect(x0 + w * 0.12, 1.1, x1 - w * 0.12, 1.7, 0.04, SCREEN_DARK)
	var reel_w: float = (w * 0.76 - 0.08) / 3.0
	for k: int in 3:
		var rx0: float = x0 + w * 0.12 + 0.02 + float(k) * (reel_w + 0.02)
		p.vgrad(rx0, 1.14, rx0 + reel_w, 1.66, REEL.darkened(0.25), REEL)
		_symbol(p, (rseed + k * 3) % 4, rx0 + reel_w * 0.5, 1.4, minf(reel_w * 0.4, 0.16))
	p.line(Vector2(x0 + w * 0.12, 1.4), Vector2(x1 - w * 0.12, 1.4), 0.012, Color(0.6, 0.48, 0.74, 0.7))
	# The top box: a marquee of dice.
	DoodadKit.panel(p, x0 + w * 0.05, 1.8, x1 - w * 0.05, 2.08, cabinet.darkened(0.2))
	for k: int in 2:
		var dx: float = cx + (float(k) - 0.5) * 0.3
		p.round_rect(dx - 0.09, 1.85, dx + 0.09, 2.03, 0.025, REEL)
		for pip: Vector2 in [Vector2(-0.045, 0.045), Vector2(0.045, -0.045), Vector2(0, 0)]:
			p.circle(dx + pip.x, 1.94 + pip.y, 0.016, SCREEN_DARK, 8)
	# A lever on the right.
	p.line(Vector2(x1 + 0.02, 1.2), Vector2(x1 + 0.02, 1.6), 0.03, CHROME)
	p.circle(x1 + 0.02, 1.62, 0.045, Color(0.6, 0.5, 0.76), 12)


static func _slots_side(s: DoodadArtSet, name: String, l: float, h: float) -> String:
	var p: DoodadPaint = s.canvas(l, h)
	var machines: int = 3
	var slot: float = l / float(machines)
	for i: int in machines:
		var x0: float = float(i) * slot + 0.14
		var x1: float = float(i + 1) * slot - 0.14
		_slot_machine(p, x0, x1, h, CABINETS[i % CABINETS.size()], i * 5 + 1)
	# Brass trim posts between the machines, so the bank reads as one piece of furniture.
	for i: int in machines + 1:
		var x: float = clampf(float(i) * slot, 0.05, l - 0.05)
		DoodadKit.post(p, x - 0.05, 0.0, x + 0.05, 2.0, GOLD.darkened(0.15))
	DoodadKit.grime(p, 0.0, 0.0, l, 0.4, 0.5, 61)
	return s.add_picture(name, p)


## The bank's end toward the runner: two machines back to back seen from the side, as one arched end
## cap with a big gold die, a ring of bulbs and the cabinets' profiles.
static func _slots_end(s: DoodadArtSet, name: String, w: float, h: float) -> String:
	var p: DoodadPaint = s.canvas(w, h)
	var arch := PackedVector2Array([Vector2(0.0, 0.0), Vector2(w, 0.0), Vector2(w, 2.1)])
	for k: int in 17:
		var a: float = PI * float(k) / 16.0
		arch.append(Vector2(w * 0.5 + cos(a) * w * 0.5, 2.1 + sin(a) * (h - 2.1)))
	arch.append(Vector2(0.0, 2.1))
	DoodadKit.shape(p, arch, CABINETS[0])
	p.rect(0.0, 0.0, w, 0.12, CABINETS[0].darkened(0.45))
	# Gold frame and bulbs.
	p.polyline(DoodadPaint.round_rect_points(0.12, 0.3, w - 0.12, 2.05, 0.1), 0.05, GOLD, true)
	for k: int in 9:
		var t: float = float(k) / 8.0
		p.circle(0.2 + t * (w - 0.4), 2.18, 0.03, REEL, 10)
	# The die.
	var die_r: float = minf(w * 0.32, 0.5)
	var cy: float = 1.2
	p.round_rect(w * 0.5 - die_r, cy - die_r, w * 0.5 + die_r, cy + die_r, die_r * 0.25, REEL)
	p.polyline(DoodadPaint.round_rect_points(w * 0.5 - die_r, cy - die_r, w * 0.5 + die_r, cy + die_r, die_r * 0.25), 0.03, GOLD.darkened(0.3), true)
	for pip: Vector2 in [Vector2(-0.5, 0.5), Vector2(0.5, -0.5), Vector2(0, 0), Vector2(-0.5, -0.5), Vector2(0.5, 0.5)]:
		p.circle(w * 0.5 + pip.x * die_r, cy + pip.y * die_r, die_r * 0.13, CABINETS[0], 14)
	DoodadKit.grime(p, 0.0, 0.0, w, 0.5, 0.5, 63)
	return s.add_picture(name, p)


## The bank from above: each machine's cabinet top (the two back-to-back halves split down the
## middle), vent grilles, and its marquee topper as a rail of bulbs along the outer edge.
static func _slots_top(s: DoodadArtSet, name: String, w: float, l: float) -> String:
	var p: DoodadPaint = s.canvas(w, l)
	p.rect(0.0, 0.0, w, l, CHROME.darkened(0.45))
	var machines: int = 3
	var slot: float = l / float(machines)
	for i: int in machines:
		var y0: float = float(i) * slot + 0.12
		var y1: float = float(i + 1) * slot - 0.12
		for half: int in 2:
			var cab: Color = CABINETS[(i + half) % CABINETS.size()]
			var x0: float = 0.06 if half == 0 else w * 0.5 + 0.03
			var x1: float = w * 0.5 - 0.03 if half == 0 else w - 0.06
			DoodadKit.panel(p, x0, y0, x1, y1, cab.darkened(0.12))
			# Vent grille in the middle of the cabinet top.
			var gx0: float = lerpf(x0, x1, 0.3)
			var gx1: float = lerpf(x0, x1, 0.7)
			for k: int in 6:
				var gy: float = lerpf(y0 + 0.4, y1 - 0.4, float(k) / 5.0)
				p.line(Vector2(gx0, gy), Vector2(gx1, gy), 0.025, cab.darkened(0.5))
			# The topper's rail along the outer edge, studded with bulbs.
			var rx0: float = x0 + 0.02 if half == 0 else x1 - 0.2
			var rx1: float = rx0 + 0.18
			DoodadKit.panel(p, rx0, y0 + 0.08, rx1, y1 - 0.08, cab.lightened(0.12))
			var bulbs: int = int((y1 - y0) / 0.16)
			for k: int in bulbs:
				var by: float = lerpf(y0 + 0.16, y1 - 0.16, float(k) / float(maxi(bulbs - 1, 1)))
				p.circle((rx0 + rx1) * 0.5, by, 0.035, REEL, 10)
		# Chrome trim between machines.
		if i > 0:
			p.rect(0.0, float(i) * slot - 0.04, w, float(i) * slot + 0.04, CHROME)
	p.polyline(DoodadKit.rect_pts(0.0, 0.0, w, l), DoodadKit.INK_W, DoodadKit.ink(CHROME), true)
	return s.add_picture(name, p)


static func _slots(s: DoodadArtSet) -> void:
	var b: Vector3 = s.box("large")
	_slots_end(s, "slots_end", b.x, b.y)
	_slots_side(s, "slots_side", b.z, b.y)
	_slots_top(s, "slots_top", b.x, b.z)
	s.add_design("large", "slot_bank", [CABINETS[0], GOLD, CHROME], DoodadArtSet.box_cards("slots_end", "slots_side", "slots_top"))

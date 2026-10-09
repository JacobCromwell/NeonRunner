extends RefCounted
## The Neon City's doodad pictures (GDD §3: "pillars, small buildings and tiny market stalls"; GDD §5:
## Blade Runner, a clean neon city at night; owner's request October 9, 2026: pictures on boxes):
##   small   a street vending machine, or a support pillar plastered with posters (by seed)
##   medium  a street-food stall: a corrugated tin roof, a counter with stools, a steaming pot and a
##           menu board, open air between counter and roof
##   large   a little shop building: a roll-down shutter, a door, a sign box (unlit), pipes and
##           air-conditioning units, a roof of clutter
## The City's own dark metals and roof tones (CitySkin.doodad_stall_colors' family); signs and screens
## are paint, never lit, and never in the hazard colours.

const STEEL := Color(0.3, 0.32, 0.37)
const STEEL_DARK := Color(0.17, 0.18, 0.22)
const CONCRETE := Color(0.42, 0.42, 0.44)
const RUST_WOOD := Color(0.4, 0.3, 0.22)
const ROOF := Color(0.3, 0.33, 0.4)
const CANVAS := Color(0.82, 0.8, 0.74)
const VIOLET := Color(0.48, 0.38, 0.66)
const INDIGO := Color(0.24, 0.24, 0.46)
const SKY_BLUE := Color(0.34, 0.46, 0.7)
const WHITE := Color(0.9, 0.9, 0.92)
const GLASS := Color(0.16, 0.2, 0.3)
const PRODUCTS: Array[Color] = [Color(0.48, 0.38, 0.66), Color(0.34, 0.46, 0.7), Color(0.88, 0.86, 0.8),
	Color(0.62, 0.6, 0.66), Color(0.4, 0.3, 0.5)]
const POSTERS: Array[Color] = [Color(0.48, 0.38, 0.66), Color(0.34, 0.46, 0.7), Color(0.85, 0.82, 0.74),
	Color(0.3, 0.3, 0.5), Color(0.6, 0.55, 0.7)]


static func paint(s: DoodadArtSet) -> void:
	_vending(s)
	_pillar(s)
	_food_stall(s)
	_shop(s)


# --- Small ---------------------------------------------------------------------------------------

## A vending machine's face: a steel cabinet, a window of drinks, a keypad, a pickup slot.
static func _vending_front(s: DoodadArtSet, name: String, w: float, h: float) -> String:
	var p: DoodadPaint = s.canvas(w, h)
	var x0: float = 0.06
	var x1: float = w - 0.06
	DoodadKit.panel(p, x0, 0.0, x1, h - 0.04, STEEL)
	p.rect(x0, 0.0, x1, 0.1, STEEL_DARK)
	# The brand panel on top: a tall cup in violet on white.
	p.round_rect(x0 + 0.08, h - 0.48, x1 - 0.08, h - 0.12, 0.05, WHITE)
	var cx: float = (x0 + x1) * 0.5
	p.poly(PackedVector2Array([Vector2(cx - 0.12, h - 0.42), Vector2(cx + 0.12, h - 0.42), Vector2(cx + 0.16, h - 0.2), Vector2(cx - 0.16, h - 0.2)]), VIOLET)
	p.line(Vector2(cx + 0.06, h - 0.2), Vector2(cx + 0.1, h - 0.13), 0.025, INDIGO)
	p.rect(x0 + 0.12, h - 0.46, cx - 0.2, h - 0.42, SKY_BLUE)
	# The product window: shelves of cans and bottles behind glass.
	var wx0: float = x0 + 0.08
	var wx1: float = x1 - 0.3
	var wy0: float = 0.75
	var wy1: float = h - 0.58
	p.rect(wx0, wy0, wx1, wy1, GLASS.darkened(0.3))
	var shelves: int = 5
	var sh: float = (wy1 - wy0) / float(shelves)
	for i: int in shelves:
		var y: float = wy0 + sh * float(i)
		p.rect(wx0, y, wx1, y + 0.025, STEEL.lightened(0.15))
		var count: int = int((wx1 - wx0) / 0.12)
		for k: int in count:
			var c: Color = PRODUCTS[(i * 3 + k) % PRODUCTS.size()]
			var bx: float = wx0 + 0.03 + float(k) * (wx1 - wx0 - 0.06) / float(count)
			p.round_rect(bx, y + 0.03, bx + 0.08, y + sh * 0.78, 0.02, c)
			p.rect(bx + 0.01, y + sh * 0.45, bx + 0.07, y + sh * 0.55, WHITE.darkened(0.1))
	DoodadKit.glass(p, wx0, wy0, wx1, wy1, Color(0.3, 0.38, 0.55, 0.0))
	p.polyline(DoodadKit.rect_pts(wx0, wy0, wx1, wy1), 0.04, STEEL_DARK, true)
	# The keypad column.
	var kx0: float = wx1 + 0.05
	var kx1: float = x1 - 0.06
	p.rect(kx0, wy1 - 0.5, kx1, wy1, STEEL_DARK)
	for r: int in 4:
		for c: int in 2:
			p.round_rect(kx0 + 0.02 + float(c) * (kx1 - kx0 - 0.04) * 0.5, wy1 - 0.12 - float(r) * 0.1,
				kx0 + (kx1 - kx0 - 0.04) * 0.5 * float(c + 1), wy1 - 0.05 - float(r) * 0.1, 0.01, WHITE.darkened(0.25))
	p.rect(kx0, wy0 + 0.2, kx1, wy0 + 0.32, STEEL_DARK.darkened(0.3))
	# The pickup slot.
	p.round_rect(x0 + 0.12, 0.25, x1 - 0.12, 0.55, 0.04, STEEL_DARK.darkened(0.4))
	p.rect(x0 + 0.14, 0.42, x1 - 0.14, 0.52, STEEL.darkened(0.1))
	DoodadKit.grime(p, x0, 0.0, x1, h, 0.7, 101)
	return s.add_picture(name, p)


## Its side: plain steel with vents, stickers and a tag.
static func _vending_side(s: DoodadArtSet, name: String, l: float, h: float) -> String:
	var p: DoodadPaint = s.canvas(l, h)
	DoodadKit.panel(p, 0.08, 0.0, l - 0.08, h - 0.04, STEEL.darkened(0.08))
	p.rect(0.08, 0.0, l - 0.08, 0.1, STEEL_DARK)
	for k: int in 7:
		p.line(Vector2(0.3, 0.4 + 0.06 * float(k)), Vector2(l - 0.3, 0.4 + 0.06 * float(k)), 0.02, STEEL_DARK)
	p.round_rect(0.3, 1.4, 0.62, 1.66, 0.04, VIOLET)
	p.circle(0.46, 1.53, 0.07, WHITE, 16)
	p.round_rect(0.75, 1.1, 1.1, 1.3, 0.03, WHITE.darkened(0.15))
	p.line(Vector2(0.78, 1.2), Vector2(1.05, 1.2), 0.025, SKY_BLUE)
	p.polyline(PackedVector2Array([Vector2(0.4, 0.95), Vector2(0.55, 1.05), Vector2(0.7, 0.92), Vector2(0.9, 1.04), Vector2(1.05, 0.95)]), 0.04, SKY_BLUE.darkened(0.1))
	DoodadKit.grime(p, 0.08, 0.0, l - 0.08, h, 0.8, 102)
	return s.add_picture(name, p)


static func _metal_top(s: DoodadArtSet, name: String, w: float, l: float, base: Color, rseed: int) -> String:
	var p: DoodadPaint = s.canvas(w, l)
	DoodadKit.panel(p, 0.0, 0.0, w, l, base)
	for k: int in 5:
		var y: float = l * (0.3 + 0.1 * float(k))
		p.line(Vector2(w * 0.25, y), Vector2(w * 0.75, y), 0.025, base.darkened(0.45))
	DoodadKit.grime(p, 0.0, 0.0, w, l, 0.8, rseed)
	return s.add_picture(name, p)


static func _vending(s: DoodadArtSet) -> void:
	var b: Vector3 = s.box("small")
	_vending_front(s, "vending_front", b.x, b.y)
	_vending_side(s, "vending_side", b.z, b.y)
	_metal_top(s, "vending_top", b.x, b.z, STEEL, 103)
	s.add_design("small", "vending_machine", [STEEL, VIOLET, WHITE],
		DoodadArtSet.box_cards("vending_front", "vending_side", "vending_top"))


## A square concrete support pillar on a plinth, plastered with layers of torn posters.
static func _pillar_face(s: DoodadArtSet, name: String, w: float, h: float, rseed: int) -> String:
	var p: DoodadPaint = s.canvas(w, h)
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	var x0: float = 0.12
	var x1: float = w - 0.12
	DoodadKit.panel(p, x0, 0.0, x1, h, CONCRETE)
	DoodadKit.panel(p, x0 - 0.08, 0.0, x1 + 0.08, 0.3, CONCRETE.darkened(0.2))
	DoodadKit.panel(p, x0 - 0.05, h - 0.18, x1 + 0.05, h, CONCRETE.darkened(0.1))
	# Posters, overlapping, some torn at a corner.
	var y: float = 0.45
	while y < h - 0.6:
		var ph: float = rng.randf_range(0.45, 0.7)
		var px0: float = x0 + rng.randf_range(0.02, 0.12)
		var px1: float = x1 - rng.randf_range(0.02, 0.12)
		var c: Color = POSTERS[rng.randi_range(0, POSTERS.size() - 1)]
		var poster := PackedVector2Array([Vector2(px0, y), Vector2(px1, y), Vector2(px1, y + ph), Vector2(px0 + 0.1, y + ph), Vector2(px0, y + ph - 0.1)])
		DoodadKit.shape(p, poster, c)
		p.rect(px0 + 0.06, y + ph * 0.55, px1 - 0.06, y + ph * 0.75, c.lightened(0.35))
		p.rect(px0 + 0.06, y + ph * 0.18, px1 - 0.25, y + ph * 0.26, c.darkened(0.35))
		p.circle(px1 - 0.15, y + ph * 0.3, 0.07, WHITE.darkened(0.1), 14)
		y += ph * rng.randf_range(0.75, 1.0)
	DoodadKit.grime(p, x0, 0.0, x1, h, 1.0, rseed + 1)
	return s.add_picture(name, p)


static func _pillar(s: DoodadArtSet) -> void:
	var b: Vector3 = s.box("small")
	_pillar_face(s, "pillar_front", b.x, b.y, 111)
	_pillar_face(s, "pillar_side", b.z, b.y, 112)
	_metal_top(s, "pillar_top", b.x, b.z, CONCRETE, 113)
	s.add_design("small", "poster_pillar", [CONCRETE, VIOLET, SKY_BLUE],
		DoodadArtSet.box_cards("pillar_front", "pillar_side", "pillar_top"))


# --- Medium: a street-food stall -------------------------------------------------------------------

const COUNTER: float = 1.0
const ROOF_LOW: float = 2.2


static func _food_face(s: DoodadArtSet, name: String, w: float, h: float, long_face: bool, rseed: int) -> String:
	var p: DoodadPaint = s.canvas(w, h)
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	# Posts.
	for x: float in ([0.03, w * 0.5 - 0.05, w - 0.13] if long_face else [0.03, w - 0.13]):
		DoodadKit.post(p, x, 0.0, x + 0.1, ROOF_LOW + 0.05, STEEL_DARK)
	# The counter: sheet steel with a wooden top.
	DoodadKit.corrugated(p, 0.0, 0.0, w, COUNTER - 0.05, STEEL, 0.1, true, Color(0, 0, 0, 0), rseed)
	DoodadKit.panel(p, -0.02, COUNTER - 0.07, w + 0.02, COUNTER + 0.02, RUST_WOOD)
	# Stools in front of the counter (open air between their legs).
	var stools: int = 2 if not long_face else 4
	for i: int in stools:
		var sx: float = w * (float(i) + 0.5) / float(stools)
		p.rect(sx - 0.17, 0.62, sx + 0.17, 0.7, VIOLET.darkened(0.2))
		p.line(Vector2(sx - 0.12, 0.0), Vector2(sx - 0.08, 0.62), 0.03, STEEL_DARK)
		p.line(Vector2(sx + 0.12, 0.0), Vector2(sx + 0.08, 0.62), 0.03, STEEL_DARK)
		p.line(Vector2(sx - 0.1, 0.3), Vector2(sx + 0.1, 0.3), 0.02, STEEL_DARK)
	# On the counter: a steaming pot, bowls, a bottle rack; above, a menu board and paper lanterns.
	var pot_x: float = w * (0.28 if long_face else 0.5)
	p.rect(pot_x - 0.2, COUNTER + 0.02, pot_x + 0.2, COUNTER + 0.32, STEEL.lightened(0.15))
	p.rect(pot_x - 0.23, COUNTER + 0.3, pot_x + 0.23, COUNTER + 0.35, STEEL.lightened(0.3))
	p.polyline(DoodadKit.rect_pts(pot_x - 0.2, COUNTER + 0.02, pot_x + 0.2, COUNTER + 0.32), 0.025, STEEL_DARK.darkened(0.4), true)
	for k: int in 3:
		var puff_y: float = COUNTER + 0.45 + 0.15 * float(k)
		p.ellipse(pot_x + sin(float(k) * 1.7) * 0.06, puff_y, 0.1 - 0.02 * float(k), 0.07, Color(0.86, 0.86, 0.9), 14)
	if long_face:
		for k: int in 4:
			var bx: float = w * 0.45 + float(k) * 0.32
			p.ellipse(bx, COUNTER + 0.07, 0.11, 0.06, WHITE.darkened(0.08), 14)
			p.rect(bx - 0.11, COUNTER + 0.02, bx + 0.11, COUNTER + 0.07, WHITE.darkened(0.08))
			p.line(Vector2(bx - 0.08, COUNTER + 0.16), Vector2(bx + 0.06, COUNTER + 0.05), 0.012, RUST_WOOD)
		DoodadKit.panel(p, w * 0.62, COUNTER + 0.55, w * 0.92, COUNTER + 0.98, STEEL_DARK.darkened(0.3))
		for k: int in 4:
			p.line(Vector2(w * 0.65, COUNTER + 0.88 - 0.09 * float(k)), Vector2(w * (0.85 - 0.04 * float(k % 2)), COUNTER + 0.88 - 0.09 * float(k)), 0.018, WHITE.darkened(0.15))
	for k: int in (3 if long_face else 1):
		var lx: float = w * (float(k) + 0.5) / (3.0 if long_face else 1.0) + rng.randf_range(-0.05, 0.05)
		p.line(Vector2(lx, ROOF_LOW), Vector2(lx, ROOF_LOW - 0.12), 0.012, STEEL_DARK)
		p.ellipse(lx, ROOF_LOW - 0.24, 0.1, 0.13, VIOLET.lightened(0.15) if k % 2 == 0 else CANVAS, 18)
		p.polyline(DoodadPaint.ellipse_points(lx, ROOF_LOW - 0.24, 0.1, 0.13, 18), 0.016, INDIGO, true)
	# The roof: a band of corrugated tin with a canvas flap hanging along its edge.
	DoodadKit.corrugated(p, -0.02, ROOF_LOW + 0.1, w + 0.02, h, ROOF, 0.12, true, Color(0, 0, 0, 0), rseed + 2)
	var flap := PackedVector2Array([Vector2(0.0, ROOF_LOW + 0.12), Vector2(w, ROOF_LOW + 0.12), Vector2(w, ROOF_LOW - 0.02)])
	var teeth: int = int(w / 0.25)
	for i: int in range(teeth, -1, -1):
		var tx: float = w * float(i) / float(teeth)
		flap.append(Vector2(tx, ROOF_LOW - (0.02 if i % 2 == 0 else 0.08)))
	DoodadKit.shape(p, flap, CANVAS)
	DoodadKit.grime(p, 0.0, 0.0, w, COUNTER, 0.8, rseed + 3)
	return s.add_picture(name, p)


## Down the stall's middle: the cook's back shelf of jars and a hanging rack of ladles.
static func _food_inside(s: DoodadArtSet, name: String, w: float, h: float) -> String:
	var p: DoodadPaint = s.canvas(w, h)
	DoodadKit.panel(p, 0.12, h * 0.25, w - 0.12, h * 0.3, RUST_WOOD)
	var x: float = 0.25
	var i: int = 0
	while x < w - 0.3:
		var c: Color = PRODUCTS[i % PRODUCTS.size()]
		p.round_rect(x, h * 0.3, x + 0.13, h * 0.3 + 0.22, 0.03, c)
		x += 0.22
		i += 1
	p.line(Vector2(0.2, h - 0.08), Vector2(w - 0.2, h - 0.08), 0.03, STEEL_DARK)
	var lx: float = 0.4
	while lx < w - 0.4:
		p.line(Vector2(lx, h - 0.08), Vector2(lx, h - 0.4), 0.02, STEEL.lightened(0.2))
		p.ellipse(lx, h - 0.44, 0.05, 0.04, STEEL.lightened(0.2), 10)
		lx += 0.35
	return s.add_picture(name, p)


static func _roof_top(s: DoodadArtSet, name: String, w: float, l: float, base: Color, rseed: int) -> String:
	var p: DoodadPaint = s.canvas(w, l)
	DoodadKit.corrugated(p, 0.0, 0.0, w, l, base, 0.14, true, Color(0.28, 0.2, 0.16, 0.5), rseed)
	return s.add_picture(name, p)


static func _food_stall(s: DoodadArtSet) -> void:
	var b: Vector3 = s.box("medium")
	_food_face(s, "food_front", b.x, b.y, false, 121)
	_food_face(s, "food_side", b.z, b.y, true, 122)
	_roof_top(s, "food_top", b.x, b.z, ROOF, 123)
	_food_inside(s, "food_inside", b.z, ROOF_LOW - COUNTER)
	var cards: Array[Dictionary] = DoodadArtSet.box_cards("food_front", "food_side", "food_top")
	cards.append(DoodadArtSet.card("x", 0.5, "food_inside", [0.05, COUNTER / b.y, 0.95, ROOF_LOW / b.y]))
	s.add_design("medium", "food_stall", [STEEL, ROOF, CANVAS], cards)


# --- Large: a little shop building -----------------------------------------------------------------

static func _shop_side(s: DoodadArtSet, name: String, l: float, h: float) -> String:
	var p: DoodadPaint = s.canvas(l, h)
	DoodadKit.panel(p, 0.0, 0.0, l, h, CONCRETE.darkened(0.15))
	p.rect(0.0, 0.0, l, 0.18, CONCRETE.darkened(0.4))
	# The roll-down shutter (two thirds of the front), its slats and a tag sprayed on it.
	var sx0: float = 0.3
	var sx1: float = l * 0.62
	DoodadKit.panel(p, sx0 - 0.08, 0.18, sx1 + 0.08, 2.12, STEEL_DARK)
	var y: float = 0.22
	while y < 1.98:
		p.rect(sx0, y, sx1, y + 0.08, STEEL.darkened(0.05))
		p.rect(sx0, y + 0.08, sx1, y + 0.1, STEEL_DARK)
		y += 0.1
	p.polyline(PackedVector2Array([Vector2(sx0 + 0.4, 0.9), Vector2(sx0 + 0.7, 1.25), Vector2(sx0 + 1.0, 0.85), Vector2(sx0 + 1.4, 1.3), Vector2(sx0 + 1.7, 0.95)]), 0.07, VIOLET)
	p.polyline(PackedVector2Array([Vector2(sx0 + 0.6, 0.7), Vector2(sx0 + 1.5, 0.75)]), 0.05, SKY_BLUE)
	# The sign box above it: an unlit panel with a bowl and chopsticks.
	DoodadKit.panel(p, sx0, 2.14, sx1, 2.5, INDIGO)
	var cx: float = (sx0 + sx1) * 0.5
	p.poly(PackedVector2Array([Vector2(cx - 0.25, 2.3), Vector2(cx + 0.25, 2.3), Vector2(cx + 0.15, 2.2), Vector2(cx - 0.15, 2.2)]), WHITE)
	p.line(Vector2(cx + 0.05, 2.28), Vector2(cx + 0.3, 2.46), 0.025, WHITE)
	p.line(Vector2(cx + 0.12, 2.28), Vector2(cx + 0.36, 2.44), 0.025, WHITE)
	p.rect(sx0 + 0.15, 2.25, cx - 0.45, 2.34, VIOLET.lightened(0.2))
	p.rect(cx + 0.5, 2.25, sx1 - 0.15, 2.34, VIOLET.lightened(0.2))
	# A door and a window with blinds.
	var dx0: float = l * 0.68
	DoodadKit.panel(p, dx0, 0.18, dx0 + 0.8, 2.0, RUST_WOOD.darkened(0.2))
	p.round_rect(dx0 + 0.2, 1.1, dx0 + 0.6, 1.7, 0.04, GLASS)
	p.circle(dx0 + 0.66, 1.0, 0.04, STEEL.lightened(0.3), 10)
	var wx0: float = dx0 + 1.0
	var wx1: float = l - 0.25
	if wx1 - wx0 > 0.4:
		DoodadKit.panel(p, wx0, 0.9, wx1, 1.9, STEEL_DARK)
		for k: int in 8:
			p.rect(wx0 + 0.06, 0.96 + 0.11 * float(k), wx1 - 0.06, 1.03 + 0.11 * float(k), CANVAS.darkened(0.25))
	# Pipes and an AC unit near the roof line.
	p.line(Vector2(l - 0.12, 0.18), Vector2(l - 0.12, 2.5), 0.07, STEEL.lightened(0.1))
	DoodadKit.panel(p, l * 0.66, 2.1, l * 0.66 + 0.7, 2.5, STEEL)
	p.circle(l * 0.66 + 0.35, 2.3, 0.15, STEEL_DARK, 20)
	DoodadKit.grime(p, 0.0, 0.0, l, h, 1.0, 131)
	return s.add_picture(name, p)


## The building's end toward the runner: a blank wall with a barred window, a meter box and a
## downpipe, an awning stub at the corner.
static func _shop_end(s: DoodadArtSet, name: String, w: float, h: float) -> String:
	var p: DoodadPaint = s.canvas(w, h)
	DoodadKit.panel(p, 0.0, 0.0, w, h, CONCRETE.darkened(0.1))
	p.rect(0.0, 0.0, w, 0.18, CONCRETE.darkened(0.4))
	DoodadKit.panel(p, w * 0.22, 1.1, w * 0.78, 1.95, GLASS)
	DoodadKit.glass(p, w * 0.22 + 0.04, 1.14, w * 0.78 - 0.04, 1.91, Color(0.22, 0.28, 0.42, 0.0))
	for k: int in 4:
		var x: float = lerpf(w * 0.25, w * 0.75, float(k) / 3.0)
		p.line(Vector2(x, 1.1), Vector2(x, 1.95), 0.03, STEEL_DARK)
	DoodadKit.panel(p, w * 0.12, 0.5, w * 0.32, 0.85, STEEL)
	p.line(Vector2(w * 0.86, 0.18), Vector2(w * 0.86, h), 0.07, STEEL.lightened(0.1))
	p.round_rect(w * 0.18, 2.12, w * 0.82, 2.46, 0.04, INDIGO)
	p.circle(w * 0.5, 2.29, 0.12, WHITE, 18)
	p.circle(w * 0.5, 2.29, 0.07, INDIGO, 14)
	DoodadKit.grime(p, 0.0, 0.0, w, h, 1.0, 132)
	return s.add_picture(name, p)


## The shop's roof from above: tar paper, an AC unit, a water tank, vents.
static func _shop_top(s: DoodadArtSet, name: String, w: float, l: float) -> String:
	var p: DoodadPaint = s.canvas(w, l)
	DoodadKit.panel(p, 0.0, 0.0, w, l, STEEL_DARK.lightened(0.05))
	p.mottle(0.0, 0.0, w, l, 0.12, 0.05, 133)
	DoodadKit.panel(p, 0.25, l * 0.15, w - 0.25, l * 0.15 + 0.9, STEEL)
	p.circle(w * 0.5, l * 0.15 + 0.45, 0.3, STEEL_DARK, 24)
	p.circle(w * 0.5, l * 0.6, 0.55, CONCRETE, 28)
	p.circle(w * 0.5, l * 0.6, 0.45, CONCRETE.lightened(0.1), 28)
	p.polyline(DoodadPaint.ellipse_points(w * 0.5, l * 0.6, 0.55, 0.55, 28), DoodadKit.INK_W, DoodadKit.ink(CONCRETE), true)
	for k: int in 3:
		p.circle(w * 0.3 + 0.35 * float(k), l * 0.86, 0.08, STEEL, 12)
	p.polyline(DoodadKit.rect_pts(0.0, 0.0, w, l), DoodadKit.INK_W, DoodadKit.ink(STEEL_DARK), true)
	return s.add_picture(name, p)


static func _shop(s: DoodadArtSet) -> void:
	var b: Vector3 = s.box("large")
	_shop_end(s, "shop_end", b.x, b.y)
	_shop_side(s, "shop_side", b.z, b.y)
	_shop_top(s, "shop_top", b.x, b.z)
	s.add_design("large", "little_shop", [CONCRETE, STEEL, INDIGO], DoodadArtSet.box_cards("shop_end", "shop_side", "shop_top"))

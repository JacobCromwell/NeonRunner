extends RefCounted
## Corporate's doodad pictures (GDD §5: a more oppressive Blade Runner, corporations and the military
## intertwined; steel, gunmetal and military olive, cold sterile white light, one harsh brand colour,
## generic soulless corporate art; the zone's doodad brief: "security barriers, kiosks, planters and
## sculpture plinths in steel and the brand colour"; owner's request October 9, 2026: pictures on boxes):
##   small   a steel plaza planter with a clipped topiary
##   medium  a security booth: steel frame, tinted glass all round, the company's mark, a card reader
##   large   a military supply container: ribbed olive walls, end doors with locking bars, stencils
## The brand colour (CorporateSkin.brand_color, an electric blue, never cyan) shows only as thin
## stripes and marks, unlit.

const STEEL := Color(0.42, 0.44, 0.47)
const GUNMETAL := Color(0.22, 0.24, 0.27)
const WHITE := Color(0.86, 0.88, 0.9)
const OLIVE := Color(0.33, 0.36, 0.25)
const OLIVE_DARK := Color(0.22, 0.25, 0.17)
const BRAND := Color(0.2, 0.32, 0.86)
const TOPIARY: Array[Color] = [Color(0.25, 0.31, 0.26), Color(0.2, 0.26, 0.22), Color(0.3, 0.36, 0.3)]
const GLASS := Color(0.18, 0.22, 0.28)
const STENCIL := Color(0.82, 0.82, 0.78)


static func paint(s: DoodadArtSet) -> void:
	_planter(s)
	_booth(s)
	_container(s)


# --- Small: planter --------------------------------------------------------------------------------

static func _planter_box(s: DoodadArtSet, name: String, w: float) -> String:
	var h: float = 0.95
	var p: DoodadPaint = s.canvas(w, h)
	DoodadKit.panel(p, 0.05, 0.0, w - 0.05, h - 0.04, GUNMETAL)
	p.rect(0.05, h * 0.62, w - 0.05, h * 0.68, BRAND)
	p.rect(0.12, 0.12, w - 0.12, h * 0.55, GUNMETAL.lightened(0.08))
	p.rect(0.05, 0.0, w - 0.05, 0.08, GUNMETAL.darkened(0.4))
	DoodadKit.panel(p, 0.0, h - 0.1, w, h, STEEL)
	# A small engraved plate.
	p.rect(w * 0.35, h * 0.3, w * 0.65, h * 0.42, STEEL.lightened(0.15))
	return s.add_picture(name, p)


## A clipped topiary: a tidy ball on a short stem, then a smaller ball above it.
static func _topiary(s: DoodadArtSet, name: String, w: float, h: float, rseed: int) -> String:
	var p: DoodadPaint = s.canvas(w, h)
	p.rect(w * 0.5 - 0.04, 0.0, w * 0.5 + 0.04, h * 0.6, Color(0.3, 0.24, 0.2))
	DoodadKit.foliage(p, w * 0.5, h * 0.33, w * 0.46, h * 0.3, TOPIARY, rseed)
	DoodadKit.foliage(p, w * 0.5, h * 0.78, w * 0.32, h * 0.2, TOPIARY, rseed + 1)
	return s.add_picture(name, p)


static func _soil(s: DoodadArtSet, name: String, w: float, l: float) -> String:
	var p: DoodadPaint = s.canvas(w, l)
	p.rect(0.0, 0.0, w, l, Color(0.38, 0.38, 0.4))
	p.speckle(0.0, 0.0, w, l, WHITE.darkened(0.3), 60, 0.015, 0.035, 301)
	return s.add_picture(name, p)


static func _planter(s: DoodadArtSet) -> void:
	var b: Vector3 = s.box("small")
	var pot_v: float = 0.95 / b.y
	_planter_box(s, "planter_front", b.x)
	_planter_box(s, "planter_side", b.z)
	_soil(s, "planter_gravel", b.x, b.z)
	_topiary(s, "topiary_a", b.x, b.y - 0.75, 311)
	_topiary(s, "topiary_b", b.z, b.y - 0.75, 312)
	var cards: Array[Dictionary] = [
		DoodadArtSet.front("planter_front", [0.0, 0.0, 1.0, pot_v]),
		DoodadArtSet.back("planter_front", [0.0, 0.0, 1.0, pot_v]),
		DoodadArtSet.top("planter_gravel", [0.04, 0.04, 0.96, 0.96], 0.9 / b.y),
		DoodadArtSet.card("z", 0.5, "topiary_a", [0.0, 0.75 / b.y, 1.0, 1.0]),
		DoodadArtSet.card("x", 0.5, "topiary_b", [0.0, 0.75 / b.y, 1.0, 1.0]),
	]
	cards.append_array(DoodadArtSet.sides("planter_side", [0.0, 0.0, 1.0, pot_v]))
	s.add_design("small", "steel_planter", [GUNMETAL, TOPIARY[0], BRAND], cards)


# --- Medium: security booth -----------------------------------------------------------------------

static func _booth_face(s: DoodadArtSet, name: String, w: float, h: float, long_face: bool) -> String:
	var p: DoodadPaint = s.canvas(w, h)
	# Base, steel frame, roof slab.
	DoodadKit.panel(p, 0.0, 0.0, w, 0.85, STEEL)
	p.rect(0.0, 0.0, w, 0.1, GUNMETAL)
	p.rect(0.0, 0.55, w, 0.6, BRAND)
	DoodadKit.panel(p, -0.02, h - 0.32, w + 0.02, h, GUNMETAL)
	p.rect(0.0, h - 0.32, w, h - 0.27, WHITE)
	# Glass panes between the frame's posts.
	var panes: int = 3 if long_face else 1
	var pw: float = (w - 0.1) / float(panes)
	for i: int in panes:
		var x0: float = 0.05 + pw * float(i) + 0.04
		var x1: float = 0.05 + pw * float(i + 1) - 0.04
		DoodadKit.glass(p, x0, 0.9, x1, h - 0.38, GLASS)
		# A desk lamp's shape and a monitor's back, dim, inside one pane.
		if i == panes / 2:
			p.rect(x0 + 0.15, 0.9, x1 - 0.15, 1.15, GLASS.darkened(0.4))
			p.rect((x0 + x1) * 0.5 - 0.18, 1.15, (x0 + x1) * 0.5 + 0.18, 1.42, GLASS.darkened(0.5))
	for i: int in panes + 1:
		DoodadKit.post(p, 0.05 + pw * float(i) - 0.05, 0.85, 0.05 + pw * float(i) + 0.05, h - 0.3, GUNMETAL)
	# The company's mark on the roof slab: a ring with a bar through it.
	var cx: float = w * 0.5
	p.circle(cx, h - 0.15, 0.09, BRAND, 20)
	p.circle(cx, h - 0.15, 0.055, GUNMETAL, 18)
	p.rect(cx - 0.16, h - 0.165, cx + 0.16, h - 0.135, WHITE)
	if long_face:
		# A card reader beside the door seam.
		DoodadKit.panel(p, w * 0.08, 1.05, w * 0.08 + 0.14, 1.3, GUNMETAL.darkened(0.2))
		p.rect(w * 0.08 + 0.03, 1.2, w * 0.08 + 0.11, 1.24, BRAND.lightened(0.2))
	DoodadKit.grime(p, 0.0, 0.0, w, 0.85, 0.4, 321 if long_face else 322)
	return s.add_picture(name, p)


static func _booth(s: DoodadArtSet) -> void:
	var b: Vector3 = s.box("medium")
	_booth_face(s, "booth_front", b.x, b.y, false)
	_booth_face(s, "booth_side", b.z, b.y, true)
	var p: DoodadPaint = s.top_canvas("medium")
	DoodadKit.panel(p, 0.0, 0.0, b.x, b.z, GUNMETAL)
	p.rect(b.x * 0.2, b.z * 0.2, b.x * 0.8, b.z * 0.45, STEEL.darkened(0.1))
	for k: int in 6:
		p.line(Vector2(b.x * 0.25, b.z * (0.24 + 0.035 * float(k))), Vector2(b.x * 0.75, b.z * (0.24 + 0.035 * float(k))), 0.02, GUNMETAL.darkened(0.4))
	p.rect(0.0, b.z * 0.7, b.x, b.z * 0.72, WHITE.darkened(0.2))
	s.add_picture("booth_top", p)
	s.add_design("medium", "security_booth", [STEEL, GUNMETAL, BRAND], DoodadArtSet.box_cards("booth_front", "booth_side", "booth_top"))


# --- Large: supply container -----------------------------------------------------------------------

## A block stencil glyph (a crude letter or digit of bars), `k` picks the shape.
static func _glyph(p: DoodadPaint, x: float, y: float, sz: float, k: int, c: Color) -> void:
	var t: float = sz * 0.18
	match k % 4:
		0:
			p.rect(x, y, x + t, y + sz, c)
			p.rect(x, y + sz - t, x + sz * 0.7, y + sz, c)
			p.rect(x, y + sz * 0.45, x + sz * 0.55, y + sz * 0.45 + t, c)
		1:
			p.rect(x, y, x + t, y + sz, c)
			p.rect(x + sz * 0.6, y, x + sz * 0.6 + t, y + sz, c)
			p.rect(x, y + sz * 0.45, x + sz * 0.6, y + sz * 0.45 + t, c)
		2:
			p.rect(x, y, x + sz * 0.7, y + t, c)
			p.rect(x, y + sz - t, x + sz * 0.7, y + sz, c)
			p.rect(x + sz * 0.27, y, x + sz * 0.27 + t, y + sz, c)
		_:
			p.rect(x, y, x + t, y + sz, c)
			p.rect(x, y, x + sz * 0.6, y + t, c)
			p.rect(x + sz * 0.6, y, x + sz * 0.6 + t, y + sz, c)
			p.rect(x, y + sz - t, x + sz * 0.6, y + sz, c)


static func _stencil(p: DoodadPaint, x: float, y: float, sz: float, count: int, c: Color, rseed: int) -> void:
	for i: int in count:
		_glyph(p, x + float(i) * sz * 0.9, y, sz, rseed + i * 3, c)


static func _container_side(s: DoodadArtSet, name: String, l: float, h: float) -> String:
	var p: DoodadPaint = s.canvas(l, h)
	DoodadKit.corrugated(p, 0.0, 0.08, l, h - 0.08, OLIVE, 0.2, true, Color(0, 0, 0, 0), 331)
	DoodadKit.panel(p, 0.0, 0.0, l, 0.14, OLIVE_DARK)
	DoodadKit.panel(p, 0.0, h - 0.14, l, h, OLIVE_DARK)
	for x: float in [0.0, l - 0.12]:
		p.rect(x, 0.0, x + 0.12, h, OLIVE_DARK)
		p.rect(x + 0.03, 0.03, x + 0.09, 0.12, STEEL.darkened(0.2))
		p.rect(x + 0.03, h - 0.12, x + 0.09, h - 0.03, STEEL.darkened(0.2))
	# Stencils: a unit code, a number, the brand stripe and mark.
	_stencil(p, l * 0.08, h * 0.62, 0.3, 4, STENCIL, 1)
	_stencil(p, l * 0.08, h * 0.45, 0.18, 7, STENCIL.darkened(0.15), 2)
	p.rect(l * 0.55, h * 0.4, l * 0.92, h * 0.47, BRAND)
	p.circle(l * 0.73, h * 0.66, 0.2, STENCIL, 22)
	p.circle(l * 0.73, h * 0.66, 0.13, OLIVE, 20)
	p.rect(l * 0.73 - 0.3, h * 0.66 - 0.03, l * 0.73 + 0.3, h * 0.66 + 0.03, STENCIL)
	DoodadKit.grime(p, 0.0, 0.0, l, h, 0.7, 332)
	return s.add_picture(name, p)


## The container's doors toward the runner: two leaves, four locking bars with their cams, hinges,
## a stencilled hazard-free label.
static func _container_end(s: DoodadArtSet, name: String, w: float, h: float) -> String:
	var p: DoodadPaint = s.canvas(w, h)
	DoodadKit.panel(p, 0.0, 0.0, w, h, OLIVE_DARK)
	for k: int in 2:
		var x0: float = 0.1 + float(k) * (w - 0.2) * 0.5 + 0.02
		var x1: float = 0.1 + float(k + 1) * (w - 0.2) * 0.5 - 0.02
		DoodadKit.corrugated(p, x0, 0.16, x1, h - 0.16, OLIVE.lightened(0.04), 0.16, false, Color(0, 0, 0, 0), 340 + k)
		for t: float in [0.22, 0.42]:
			var bx: float = lerpf(x0, x1, t)
			p.rect(bx - 0.025, 0.12, bx + 0.025, h - 0.12, STEEL)
			p.rect(bx - 0.06, h * 0.5 - 0.1, bx + 0.06, h * 0.5 + 0.02, STEEL.darkened(0.15))
			p.rect(bx - 0.04, 0.12, bx + 0.04, 0.2, STEEL.darkened(0.3))
			p.rect(bx - 0.04, h - 0.2, bx + 0.04, h - 0.12, STEEL.darkened(0.3))
	_stencil(p, 0.2, h * 0.72, 0.16, 3, STENCIL, 7)
	p.rect(w * 0.55, h * 0.75, w * 0.88, h * 0.79, BRAND)
	DoodadKit.grime(p, 0.0, 0.0, w, h, 0.7, 343)
	return s.add_picture(name, p)


static func _container(s: DoodadArtSet) -> void:
	var b: Vector3 = s.box("large")
	_container_end(s, "container_end", b.x, b.y)
	_container_side(s, "container_side", b.z, b.y)
	var p: DoodadPaint = s.top_canvas("large")
	DoodadKit.corrugated(p, 0.0, 0.0, b.x, b.z, OLIVE, 0.25, false, Color(0, 0, 0, 0), 351)
	p.rect(0.0, 0.0, 0.1, b.z, OLIVE_DARK)
	p.rect(b.x - 0.1, 0.0, b.x, b.z, OLIVE_DARK)
	_stencil(p, b.x * 0.2, b.z * 0.4, 0.35, 2, STENCIL.darkened(0.1), 9)
	DoodadKit.grime(p, 0.0, 0.0, b.x, b.z, 0.7, 352)
	s.add_picture("container_top", p)
	s.add_design("large", "supply_container", [OLIVE, OLIVE_DARK, STENCIL], DoodadArtSet.box_cards("container_end", "container_side", "container_top"))

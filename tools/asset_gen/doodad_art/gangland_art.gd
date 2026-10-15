extends RefCounted
## Gangland's doodad pictures (GDD §3: "burned-out cars and broken-down shops"; GDD §5: Mad Max in a
## cyberpunk setting, lived in, browns and tans, graffiti in dusty blue, steel grey, violet grey and
## cream; owner's request October 9, 2026: pictures on boxes):
##   small   a stack of rusted oil drums under a tyre and a scrap plank
##   medium  a burned-out van: shattered windscreen and empty window frames (open, a charred cab
##           inside), rust and scorch, flat tyres
##   large   a broken-down shop: a corrugated shack with a half-open shutter on a dark inside, a
##           hand-painted sign, a sagging awning, junk along its foot

const RUST := Color(0.46, 0.3, 0.2)
const RUST_DARK := Color(0.3, 0.2, 0.14)
const TAN := Color(0.62, 0.52, 0.38)
const SAND := Color(0.7, 0.6, 0.45)
const BROWN := Color(0.38, 0.28, 0.2)
const SCORCH := Color(0.12, 0.1, 0.09)
const TYRE := Color(0.13, 0.12, 0.12)
const SHEET := Color(0.5, 0.45, 0.4)
const GRAFFITI: Array[Color] = [Color(0.36, 0.5, 0.6), Color(0.5, 0.49, 0.52), Color(0.46, 0.42, 0.55), Color(0.82, 0.78, 0.66)]
const PLANK := Color(0.52, 0.4, 0.28)
const INSIDE := Color(0.09, 0.08, 0.08)


static func paint(s: DoodadArtSet) -> void:
	_drums(s)
	_van(s)
	_shack(s)


## A tag: a few looping strokes in `c` from x0 to x1 around height y.
static func _tag(p: DoodadPaint, x0: float, x1: float, y: float, c: Color, rseed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	var pts := PackedVector2Array()
	var steps: int = 9
	for i: int in steps:
		pts.append(Vector2(lerpf(x0, x1, float(i) / float(steps - 1)), y + rng.randf_range(-0.14, 0.14)))
	p.polyline(pts, 0.06, c.darkened(0.45))
	p.polyline(pts, 0.04, c)


# --- Small: drums --------------------------------------------------------------------------------

## A drum seen from the side: a ribbed rusty barrel from (x0, y0), `w` wide and `h` tall.
static func _drum(p: DoodadPaint, x0: float, y0: float, w: float, h: float, base: Color, rseed: int) -> void:
	DoodadKit.panel(p, x0, y0, x0 + w, y0 + h, base)
	p.rect(x0, y0, x0 + w * 0.18, y0 + h, base.lightened(0.12))
	p.rect(x0 + w * 0.8, y0, x0 + w, y0 + h, base.darkened(0.25))
	for t: float in [0.32, 0.68]:
		p.rect(x0, y0 + h * t - 0.025, x0 + w, y0 + h * t + 0.025, base.darkened(0.35))
	DoodadKit.stains(p, x0, y0, x0 + w, y0 + h, Color(RUST_DARK, 0.4), 3, 0.18, rseed)
	p.ellipse(x0 + w * 0.5, y0 + h * 0.5, w * 0.2, h * 0.12, SCORCH.lerp(base, 0.4), 16)
	p.polyline(DoodadKit.rect_pts(x0, y0, x0 + w, y0 + h), DoodadKit.INK_W, DoodadKit.ink(base), true)


static func _drums_face(s: DoodadArtSet, name: String, w: float, h: float, rseed: int) -> String:
	var p: DoodadPaint = s.canvas(w, h)
	var dw: float = w * 0.47
	var dh: float = 0.9
	_drum(p, 0.02, 0.0, dw, dh, RUST, rseed)
	_drum(p, w - dw - 0.02, 0.0, dw, dh, BROWN, rseed + 1)
	_drum(p, w * 0.5 - dw * 0.5, dh, dw, dh, RUST.lightened(0.05), rseed + 2)
	# A tyre lying on top, and a scrap plank leaning across the stack.
	DoodadKit.wheel_edge(p, w * 0.5 - dw * 0.55, w * 0.5 + dw * 0.55, dh * 2.0, dh * 2.0 + 0.3, TYRE)
	p.line(Vector2(0.06, 0.15), Vector2(w * 0.72, h - 0.12), 0.1, PLANK)
	p.polyline(PackedVector2Array([Vector2(0.06, 0.1), Vector2(w * 0.72, h - 0.17)]), 0.02, DoodadKit.ink(PLANK))
	p.line(Vector2(w - 0.18, dh * 2.0 + 0.3), Vector2(w - 0.08, h - 0.02), 0.04, SHEET)
	DoodadKit.grime(p, 0.0, 0.0, w, h, 0.8, rseed + 3)
	return s.add_picture(name, p)


static func _drums_top(s: DoodadArtSet, name: String, w: float, l: float) -> String:
	var p: DoodadPaint = s.canvas(w, l)
	p.circle(w * 0.5, l * 0.5, minf(w, l) * 0.42, TYRE, 28)
	p.circle(w * 0.5, l * 0.5, minf(w, l) * 0.22, RUST.darkened(0.2), 24)
	p.polyline(DoodadPaint.ellipse_points(w * 0.5, l * 0.5, minf(w, l) * 0.42, minf(w, l) * 0.42, 28), DoodadKit.INK_W, DoodadKit.ink(TYRE), true)
	p.line(Vector2(w * 0.15, l * 0.1), Vector2(w * 0.8, l * 0.9), 0.1, PLANK)
	return s.add_picture(name, p)


static func _drums(s: DoodadArtSet) -> void:
	var b: Vector3 = s.box("small")
	_drums_face(s, "drums_front", b.x, b.y, 201)
	_drums_face(s, "drums_side", b.z, b.y, 202)
	_drums_top(s, "drums_top", b.x, b.z)
	s.add_design("small", "drum_stack", [RUST, BROWN, TYRE], DoodadArtSet.box_cards("drums_front", "drums_side", "drums_top"))


# --- Medium: a burned-out van -----------------------------------------------------------------------

const BODY_LOW: float = 0.3
const ROOF_Y: float = 2.3


## The van's nose: bumper, dead headlights, a grille, the windscreen shattered out (open, the cab
## inside showing through), flat tyres at the corners, junk lashed on the roof.
static func _van_front(s: DoodadArtSet, name: String, w: float, h: float) -> String:
	var p: DoodadPaint = s.canvas(w, h)
	DoodadKit.wheel_edge(p, 0.06, 0.34, 0.0, 0.6, TYRE)
	DoodadKit.wheel_edge(p, w - 0.34, w - 0.06, 0.0, 0.6, TYRE)
	var body := PackedVector2Array([Vector2(0.0, BODY_LOW), Vector2(w, BODY_LOW), Vector2(w, 1.4), Vector2(w - 0.12, ROOF_Y),
		Vector2(0.12, ROOF_Y), Vector2(0.0, 1.4)])
	DoodadKit.shape(p, body, TAN)
	p.rect(0.0, BODY_LOW, w, BODY_LOW + 0.22, RUST_DARK)
	DoodadKit.panel(p, 0.0, BODY_LOW, w, BODY_LOW + 0.2, SHEET.darkened(0.2))
	# Grille and headlights.
	DoodadKit.panel(p, w * 0.3, 0.62, w * 0.7, 0.98, SCORCH.lightened(0.1))
	for k: int in 4:
		p.line(Vector2(w * 0.32, 0.68 + 0.08 * float(k)), Vector2(w * 0.68, 0.68 + 0.08 * float(k)), 0.025, SHEET.darkened(0.3))
	for hx: float in [w * 0.15, w * 0.85]:
		p.circle(hx, 0.82, 0.12, SCORCH, 18)
		p.circle(hx, 0.82, 0.07, SHEET.darkened(0.4), 14)
	# Rust and scorch blooms.
	DoodadKit.stains(p, 0.0, BODY_LOW, w, 1.4, Color(RUST, 0.35), 8, 0.32, 211)
	p.ellipse(w * 0.7, 1.25, 0.45, 0.25, SCORCH.lerp(TAN, 0.25), 24)
	# The windscreen: empty, with jagged teeth of glass left in its frame.
	var wx0: float = 0.2
	var wx1: float = w - 0.2
	var wy0: float = 1.48
	var wy1: float = ROOF_Y - 0.12
	DoodadKit.window_hole(p, wx0, wy0, wx1, wy1, SCORCH.lightened(0.15), 0.06)
	for k: int in 5:
		var gx: float = lerpf(wx0 + 0.1, wx1 - 0.1, float(k) / 4.0)
		p.poly(PackedVector2Array([Vector2(gx - 0.07, wy0 + 0.06), Vector2(gx + 0.07, wy0 + 0.06), Vector2(gx + 0.02, wy0 + 0.2 + 0.05 * float(k % 2))]), Color(0.55, 0.6, 0.62))
	# Junk on the roof: a lashed tarp bundle and a spare tyre.
	p.round_rect(0.25, ROOF_Y - 0.02, w * 0.62, h - 0.02, 0.08, BROWN.lightened(0.1))
	p.line(Vector2(0.3, ROOF_Y + 0.15), Vector2(w * 0.6, ROOF_Y + 0.15), 0.02, SCORCH)
	DoodadKit.wheel_edge(p, w * 0.66, w - 0.25, ROOF_Y - 0.02, h - 0.04, TYRE)
	DoodadKit.grime(p, 0.0, BODY_LOW, w, ROOF_Y, 1.0, 212)
	return s.add_picture(name, p)


## The van's side: rusted, scorched panels, a sliding door, empty window frames (open), wheel arches
## with flat tyres, a tag.
static func _van_side(s: DoodadArtSet, name: String, l: float, h: float) -> String:
	var p: DoodadPaint = s.canvas(l, h)
	var body := PackedVector2Array([Vector2(0.05, BODY_LOW), Vector2(l - 0.05, BODY_LOW), Vector2(l - 0.05, ROOF_Y - 0.05),
		Vector2(0.55, ROOF_Y - 0.05), Vector2(0.05, 1.4)])
	DoodadKit.shape(p, body, TAN)
	p.rect(0.05, BODY_LOW, l - 0.05, BODY_LOW + 0.18, RUST_DARK)
	# Wheels in their arches (the arch's dark first).
	for wx: float in [0.75, l - 0.75]:
		p.circle(wx, 0.4, 0.42, INSIDE, 24)
		DoodadKit.wheel(p, wx, 0.33, 0.33, TYRE, SHEET.darkened(0.25))
	# Door seams and handle.
	p.line(Vector2(l * 0.42, BODY_LOW + 0.2), Vector2(l * 0.42, ROOF_Y - 0.1), 0.02, DoodadKit.ink(TAN))
	p.line(Vector2(l * 0.78, BODY_LOW + 0.2), Vector2(l * 0.78, ROOF_Y - 0.1), 0.02, DoodadKit.ink(TAN))
	p.rect(l * 0.44, 1.25, l * 0.5, 1.29, SCORCH)
	# Rust, scorch, a tag.
	DoodadKit.stains(p, 0.05, BODY_LOW, l - 0.05, ROOF_Y, Color(RUST, 0.35), 16, 0.36, 221)
	p.ellipse(l * 0.65, 1.6, 0.8, 0.45, SCORCH.lerp(TAN, 0.3), 28)
	_tag(p, l * 0.5, l * 0.9, 0.9, GRAFFITI[0], 222)
	_tag(p, l * 0.12, l * 0.36, 1.0, GRAFFITI[3], 223)
	# The windows: the cab's and two in the back, all empty.
	DoodadKit.window_hole(p, 0.58, 1.45, l * 0.4, ROOF_Y - 0.17, SCORCH.lightened(0.15), 0.06)
	DoodadKit.window_hole(p, l * 0.45, 1.45, l * 0.75, ROOF_Y - 0.17, SCORCH.lightened(0.15), 0.06)
	DoodadKit.grime(p, 0.05, BODY_LOW, l - 0.05, ROOF_Y, 1.0, 224)
	# Junk on the roof, seen from the side.
	p.round_rect(0.6, ROOF_Y - 0.06, l * 0.55, h - 0.02, 0.08, BROWN.lightened(0.1))
	p.line(Vector2(0.7, ROOF_Y + 0.12), Vector2(l * 0.5, ROOF_Y + 0.12), 0.02, SCORCH)
	return s.add_picture(name, p)


## Inside the van, seen through its empty windows: charred seat backs and a sagging ceiling.
static func _van_inside(s: DoodadArtSet, name: String, w: float, h: float) -> String:
	var p: DoodadPaint = s.canvas(w, h)
	p.rect(0.0, 0.0, w, h, INSIDE)
	for k: int in 2:
		var sx: float = w * (0.25 + 0.5 * float(k))
		p.round_rect(sx - w * 0.18, 0.05, sx + w * 0.18, h * 0.75, 0.08, SCORCH.lightened(0.12))
		p.round_rect(sx - w * 0.12, h * 0.6, sx + w * 0.12, h * 0.85, 0.05, SCORCH.lightened(0.18))
	DoodadKit.stains(p, 0.0, 0.0, w, h, Color(RUST_DARK, 0.4), 5, 0.22, 231)
	return s.add_picture(name, p)


static func _van_top(s: DoodadArtSet, name: String, w: float, l: float) -> String:
	var p: DoodadPaint = s.canvas(w, l)
	DoodadKit.panel(p, 0.04, 0.04, w - 0.04, l - 0.04, TAN.darkened(0.08))
	DoodadKit.stains(p, 0.0, 0.0, w, l, Color(RUST, 0.35), 12, 0.4, 241)
	p.ellipse(w * 0.55, l * 0.45, 0.5, 0.8, SCORCH.lerp(TAN, 0.3), 24)
	# The junk bundle and the spare tyre.
	p.round_rect(0.2, l * 0.2, w - 0.2, l * 0.55, 0.1, BROWN.lightened(0.1))
	p.line(Vector2(0.2, l * 0.3), Vector2(w - 0.2, l * 0.3), 0.025, SCORCH)
	p.line(Vector2(0.2, l * 0.45), Vector2(w - 0.2, l * 0.45), 0.025, SCORCH)
	p.circle(w * 0.5, l * 0.8, 0.38, TYRE, 24)
	p.circle(w * 0.5, l * 0.8, 0.2, RUST_DARK, 20)
	p.polyline(DoodadKit.rect_pts(0.04, 0.04, w - 0.04, l - 0.04), DoodadKit.INK_W, DoodadKit.ink(TAN), true)
	return s.add_picture(name, p)


static func _van(s: DoodadArtSet) -> void:
	var b: Vector3 = s.box("medium")
	_van_front(s, "van_front", b.x, b.y)
	_van_side(s, "van_side", b.z, b.y)
	_van_top(s, "van_top", b.x, b.z)
	_van_inside(s, "van_cab", b.x, 1.0)
	_van_inside(s, "van_inside", b.z * 0.8, 1.0)
	var cards: Array[Dictionary] = DoodadArtSet.box_cards("van_front", "van_side", "van_top")
	# The cab's seats just behind the windscreen, and the charred inside down the van's middle.
	cards.append(DoodadArtSet.card("z", 0.8, "van_cab", [0.08, 1.35 / b.y, 0.92, 2.2 / b.y]))
	cards.append(DoodadArtSet.card("x", 0.5, "van_inside", [0.12, 1.35 / b.y, 0.86, 2.2 / b.y]))
	s.add_design("medium", "burned_van", [TAN, RUST, SCORCH], cards)


# --- Large: a broken-down shop ---------------------------------------------------------------------

static func _shack_side(s: DoodadArtSet, name: String, l: float, h: float) -> String:
	var p: DoodadPaint = s.canvas(l, h)
	DoodadKit.corrugated(p, 0.0, 0.0, l, h - 0.15, SHEET, 0.14, true, RUST, 251)
	# A patch of different sheet, nailed over a hole.
	DoodadKit.corrugated(p, l * 0.72, 0.6, l * 0.92, 1.5, RUST.lightened(0.1), 0.12, false, RUST_DARK, 252)
	# The shop opening: a roll-up shutter jammed half open over the dark inside (open below it).
	var ox0: float = l * 0.18
	var ox1: float = l * 0.6
	p.rect(ox0, 0.0, ox1, 2.0, INSIDE)
	var y: float = 1.05
	while y < 2.0:
		p.rect(ox0, y, ox1, y + 0.08, SHEET.darkened(0.2))
		p.rect(ox0, y, ox1, y + 0.015, SHEET.darkened(0.45))
		y += 0.09
	p.erase_rect(ox0 + 0.04, 0.08, ox1 - 0.04, 1.0)
	p.polyline(DoodadKit.rect_pts(ox0, 0.0, ox1, 2.0), 0.05, SCORCH, true)
	# A counter just inside the opening, with a crate on it.
	DoodadKit.panel(p, ox0 + 0.05, 0.0, ox1 - 0.05, 0.45, PLANK)
	DoodadKit.crate(p, ox0 + 0.3, 0.45, ox0 + 0.8, 0.78, PLANK.lightened(0.1))
	# A sagging awning of scrap sheet above it.
	var awning := PackedVector2Array([Vector2(ox0 - 0.2, 2.25), Vector2(ox1 + 0.25, 2.3), Vector2(ox1 + 0.2, 2.05), Vector2(ox0 - 0.15, 2.12)])
	DoodadKit.shape(p, awning, RUST)
	# The hand-painted sign board on the roof edge.
	DoodadKit.boards(p, l * 0.22, h - 0.42, l * 0.56, h - 0.02, PLANK, 0.18, 253)
	_tag(p, l * 0.25, l * 0.52, h - 0.22, GRAFFITI[3], 254)
	# Graffiti, a boarded window, junk at the foot of the wall.
	_tag(p, l * 0.64, l * 0.95, 1.8, GRAFFITI[0], 255)
	_tag(p, l * 0.02, l * 0.16, 1.2, GRAFFITI[2], 256)
	DoodadKit.boards(p, l * 0.65, 1.2, l * 0.85, 1.75, PLANK.darkened(0.15), 0.1, 257)
	DoodadKit.wheel_edge(p, l * 0.63, l * 0.7, 0.0, 0.55, TYRE)
	DoodadKit.crate(p, l * 0.86, 0.0, l * 0.98, 0.45, PLANK)
	DoodadKit.grime(p, 0.0, 0.0, l, h, 1.0, 258)
	return s.add_picture(name, p)


static func _shack_end(s: DoodadArtSet, name: String, w: float, h: float) -> String:
	var p: DoodadPaint = s.canvas(w, h)
	DoodadKit.corrugated(p, 0.0, 0.0, w, h - 0.15, SHEET.darkened(0.05), 0.14, true, RUST, 261)
	# A window with its glass smashed out (open), a curtain rag inside.
	DoodadKit.window_hole(p, w * 0.25, 1.15, w * 0.75, 1.85, PLANK.darkened(0.2), 0.06)
	p.poly(PackedVector2Array([Vector2(w * 0.3, 1.79), Vector2(w * 0.45, 1.79), Vector2(w * 0.38, 1.4)]), GRAFFITI[2].darkened(0.2))
	_tag(p, w * 0.1, w * 0.9, 0.7, GRAFFITI[0], 262)
	p.line(Vector2(w * 0.08, 0.0), Vector2(w * 0.08, h - 0.15), 0.06, RUST_DARK)
	p.line(Vector2(w * 0.92, 0.0), Vector2(w * 0.92, h - 0.15), 0.06, RUST_DARK)
	DoodadKit.grime(p, 0.0, 0.0, w, h, 1.0, 263)
	return s.add_picture(name, p)


static func _shack_top(s: DoodadArtSet, name: String, w: float, l: float) -> String:
	var p: DoodadPaint = s.canvas(w, l)
	DoodadKit.corrugated(p, 0.0, 0.0, w, l, SHEET.darkened(0.1), 0.16, false, RUST, 271)
	p.round_rect(w * 0.1, l * 0.55, w * 0.8, l * 0.8, 0.06, Color(0.36, 0.42, 0.46))
	p.line(Vector2(w * 0.1, l * 0.62), Vector2(w * 0.8, l * 0.7), 0.02, SCORCH)
	DoodadKit.wheel_edge(p, w * 0.2, w * 0.6, l * 0.2, l * 0.27, TYRE)
	return s.add_picture(name, p)


static func _shack_inside(s: DoodadArtSet, name: String, l: float, h: float) -> String:
	var p: DoodadPaint = s.canvas(l, h)
	p.rect(0.0, 0.0, l, h, INSIDE.lightened(0.04))
	DoodadKit.panel(p, 0.2, h * 0.45, l - 0.2, h * 0.5, PLANK.darkened(0.3))
	var x: float = 0.3
	var k: int = 0
	while x < l - 0.4:
		p.round_rect(x, h * 0.5, x + 0.18, h * 0.5 + 0.25, 0.03, GRAFFITI[k % GRAFFITI.size()].darkened(0.45))
		x += 0.3
		k += 1
	return s.add_picture(name, p)


static func _shack(s: DoodadArtSet) -> void:
	var b: Vector3 = s.box("large")
	_shack_end(s, "shack_end", b.x, b.y)
	_shack_side(s, "shack_side", b.z, b.y)
	_shack_top(s, "shack_top", b.x, b.z)
	_shack_inside(s, "shack_inside", b.z, 2.0)
	var cards: Array[Dictionary] = DoodadArtSet.box_cards("shack_end", "shack_side", "shack_top")
	cards.append(DoodadArtSet.card("x", 0.5, "shack_inside", [0.0, 0.0, 1.0, 2.0 / b.y]))
	s.add_design("large", "broken_shop", [SHEET, RUST, PLANK], cards)

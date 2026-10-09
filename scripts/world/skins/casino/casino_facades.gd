class_name CasinoFacades
extends MarketFacades
## The Casino's walls (CasinoSkin; task K1; the owner's reference image): the casino street's
## facades of dark riveted iron and aged brass, all rising to the glass roof's springing line
## (`eave_height`). It builds on the Marketplace's (MarketFacades): the same lots and buildings (a row
## of lounges, a casino or an arcade hall: Kind), the same shop windows low on the wall where the
## Marketplace citizens play (windows(), task D3: the row of lit lounges 0.85-2.8 m up, above the
## screech vents' zone), the same piers, TVs playing the cult's feed and billboards (feed_boards()). Only
## the look differs: casino_facade.gdshader draws iron plates, brass bands, arched windows and warm
## lounges (its style numbers are shopfront.gdshader's), and the dressing above the calm band is the
## reference's: thick brass pipes and risers along the faces, stacked iron balconies with ivy in
## planters, air-conditioning units, lit blade signs ("The Brass Lotus"), casino marquees of bulbs with
## big lit signs, banners of heavy cloth, all unframed (hazard signs wear the yellow/black frame), none of
## the flat ones below `decor_min_height` and none of the ones that stand out below `overhang_min_height`.
## Nothing vent-like at the foot of the walls (the screeches' lairs, GDD §5, §9.5), nothing glowing or
## sticking out through the wall-run band (`band_top`): every wall is flush from the street up past it,
## and what stands out of a face by more than a hand's width starts at `overhang_min_height`.
## All variety comes from hashing lot indices, so chunk cuts never change a building.

## How far a balcony reaches out of the face (metres).
const BALCONY_REACH: float = 0.95
## Added to the lit sign's size: its frame around the panel.
const FRAME: float = 0.16

## The names' lettering (task K3): how far the letters stand in front of their board, the room kept round them
## on a board (across, up), the padding of a strip over a feed sign and the gap above that sign, and the Brass
## Lotus's blade: how far out of the wall it reaches (under a metre with its brackets: the arrival flyover's
## camera keeps a metre inside the walls), how far the board stands from the face, how tall a capital is on it,
## the least that is still legible (a casino under a low roof gets none rather than tiny letters), the board's
## padding above and below the letters, and how far its letters stand in front of it.
const LETTER_LIFT: float = 0.03
const BOARD_MARGIN := Vector2(0.55, 0.5)
const STRIP_PAD: float = 0.25
const STRIP_GAP: float = 0.2
const BLADE_REACH: float = 0.8
const BLADE_SETBACK: float = 0.15
const BLADE_LETTER: float = 0.64
const BLADE_LETTER_MIN: float = 0.4
const BLADE_PAD: float = 0.35
const BLADE_LETTER_LIFT: float = 0.02

## Wall lamps built once per side (_lamp).
var _lamp_templates: Dictionary = {}
## The lettering in the skin's colour, built once per layout (_letters).
var _lettering: Dictionary = {}


## The skin, typed as the Casino's (the base class keeps the Marketplace's type for its own use).
var csk: CasinoSkin:
	get:
		return skin as CasinoSkin


## The building on `side` covering the lot run `span`: the Marketplace's layout (kinds, shop windows,
## upper-floor grid) at the Casino's height: every building reaches the roof's springing line.
func building(side: int, span: Vector2i) -> MarketFacades.Building:
	var b: MarketFacades.Building = super(side, span)
	b.height = csk.eave_height
	b.setback = 0.0
	b.low = false
	return b


func _building(batch: MeshBatch, b: MarketFacades.Building, face_x: float, start: float, end: float) -> void:
	var u0: float = maxf(b.b0, start)
	var u1: float = minf(b.b1, end)
	if u1 <= u0 + 0.001:
		return
	var facade: MeshLayer = batch.layer(skin.facade_material())
	var solid: MeshLayer = batch.layer(skin.solid_material())
	var glow: MeshLayer = batch.layer(skin.glow_material())
	var side: int = b.side
	var g0: float = skin.gallery_bottom
	var g1: float = skin.gallery_top
	var upper_style: int = [STYLE_UPPER, STYLE_CASINO, STYLE_HALL][b.kind]

	# Below the street the face is in the trenches' deep shade (seen only through gaps, which must read as
	# holes); above it, the plinth.
	_panel(solid, side, face_x, u0, u1, -csk.trench_depth, 0.0, skin.gap_inside_color, 0.0, MeshKit.PAT_CASINO_UNDER, 1.0)
	_face(facade, side, face_x, u0, u1, 0.0, g0, b.wall, b.lit, STYLE_LOWER, b.seed, 0.0)
	# The shop windows and the piers between them. Piers are clipped to the chunk; a window belongs
	# whole to the chunk holding its centre, so the wall stays seamless across chunk cuts.
	var cursor: float = b.b0
	for w: Vector2 in b.windows:
		if skin.wall_gap_near(side, w.x, w.y):
			continue  # Cut by a wall gap: the pier runs on past it instead.
		_pier(facade, side, face_x, cursor, w.x, u0, u1, b)
		var at: float = (w.x + w.y) * 0.5
		if at >= start and at < end:
			_shop_window(batch, b, w, face_x)
		cursor = w.y
	_pier(facade, side, face_x, cursor, b.b1, u0, u1, b)
	# The face above the windows, all the way up to the roof's springing line.
	_face(facade, side, face_x, u0, u1, g1, b.height, b.wall, b.lit, upper_style, b.seed, b.grid_start)
	# The entablature along the top: a dark iron cornice with a brass band.
	var zc: float = -(u0 + u1) * 0.5
	solid.box(Vector3(face_x - side * 0.2, b.height - 0.45, zc), Vector3(0.4, 0.9, u1 - u0), skin.iron_color, 0.0,
		MeshKit.PAT_CASINO_IRON, MeshKit.ALL_FACES & ~FACE_AGAINST[side], 2.0)
	solid.box(Vector3(face_x - side * 0.26, b.height - 0.98, zc), Vector3(0.5, 0.12, u1 - u0), csk.brass_color, 0.0,
		MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES & ~FACE_AGAINST[side], 0.5)

	_pipes(solid, b, face_x, u0, u1)
	_lamps(batch, b, face_x, u0, u1)
	match b.kind:
		Kind.CASINO:
			_casino(batch, solid, glow, b, face_x, u0, u1, start, end)
		Kind.HALL:
			_hall(solid, b, face_x, start, end)
		_:
			_lounge_extras(batch, solid, glow, b, face_x, u0, u1, start, end)
	_wall_banner(solid, b, face_x, start, end)


## Box faces to leave out against the wall on each side (the wall is at x = face_x, the building
## behind it, so the face toward the building is never seen).
const FACE_AGAINST: Dictionary = {-1: MeshKit.FACE_NX, 1: MeshKit.FACE_PX}


# --- Brass pipes ------------------------------------------------------------------------------

## Thick brass pipes along the face (the reference's pipes and ducts): one or two runs along the
## building between the first storey above the calm band and the roof, with a flange at the building's
## ends, and on some a riser up the face. Nothing lower than overhang_min_height.
func _pipes(solid: MeshLayer, b: MarketFacades.Building, face_x: float, u0: float, u1: float) -> void:
	var side: int = b.side
	if MeshKit.hash01(side, b.id, 99) >= csk.pipe_share:
		return
	var runs: int = 1 + (1 if MeshKit.hash01(side, b.id, 100) < 0.4 else 0)
	for r: int in runs:
		var y: float = lerpf(csk.overhang_min_height + 1.0, b.height - 3.0, MeshKit.hash01(side, b.id, 101 + r))
		var radius: float = 0.18 + 0.2 * MeshKit.hash01(side, b.id, 103 + r)
		var x: float = face_x - side * (radius + 0.1)
		var color: Color = csk.brass_color if r == 0 else csk.brass_dim_color
		_pipe_z(solid, x, y, u0, u1, radius, color)
		if u0 <= b.b0 + 0.01:
			_flange(solid, x, y, b.b0 + 0.05, radius)
		if u1 >= b.b1 - 0.01:
			_flange(solid, x, y, b.b1 - 0.05, radius)
	# A riser near the building's start, from the first run's height down toward the calm band's top.
	if MeshKit.hash01(side, b.id, 109) < 0.5:
		var rd: float = b.b0 + 0.9 + 1.2 * MeshKit.hash01(side, b.id, 110)
		if rd >= u0 and rd < u1:
			var y_top: float = lerpf(csk.overhang_min_height + 1.0, b.height - 3.0, MeshKit.hash01(side, b.id, 101))
			var rr: float = 0.16
			var rx: float = face_x - side * (rr + 0.1)
			var y_bottom: float = csk.overhang_min_height + 0.2
			if y_top > y_bottom + 1.0:
				solid.prism(Vector3(rx, y_bottom, -rd), rr, y_top - y_bottom, 8, csk.brass_color, 0.0, MeshKit.PAT_CASINO_BRASS, false, 0.5)
				_flange(solid, rx, y_bottom + 0.1, rd, rr)


## A brass pipe along the track from distance d0 to d1 (z = -d), centred at (x, y).
static func _pipe_z(s: MeshLayer, x: float, y: float, d0: float, d1: float, radius: float, color: Color) -> void:
	if d1 <= d0 + 0.01:
		return
	var basis := Basis(Vector3(radius, 0, 0), Vector3(0, 0, -(d1 - d0)), Vector3(0, radius, 0))
	s.prism_xform(Transform3D(basis, Vector3(x, y, -d0)), 8, color, 0.0, MeshKit.PAT_CASINO_BRASS, false, 0.5)


## A flange ring where a pipe passes into a building or a neighbour, at distance d.
func _flange(s: MeshLayer, x: float, y: float, d: float, radius: float) -> void:
	s.box(Vector3(x, y, -d), Vector3(radius * 2.0 + 0.14, radius * 2.0 + 0.14, 0.1), csk.brass_dim_color, 0.0,
		MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.4)


## Wall lamps: a brass bracket and a warm lantern every nine metres or so, above decor_min_height (a
## decorative light is never lower), standing out of the wall by under 30 cm, each with a soft halo on
## the face (the reference's lamplit haze). Warm white, no real light. One cached template per side.
func _lamps(batch: MeshBatch, b: MarketFacades.Building, face_x: float, u0: float, u1: float) -> void:
	var side: int = b.side
	var spacing: float = 9.0
	var k: int = ceili(u0 / spacing)
	while float(k) * spacing < u1:
		var d: float = (float(k) + 0.5 * MeshKit.hash01(side, k, 130)) * spacing
		var y: float = skin.decor_min_height + 0.6 + 1.6 * MeshKit.hash01(side, k, 131)
		k += 1
		if d >= u0 and d < u1:
			batch.append(_lamp(side), Transform3D(Basis.IDENTITY, Vector3(face_x, y, -d)))


## One wall lamp on the wall on `side` (the face at x = 0, the lamp's centre at the origin).
func _lamp(side: int) -> MeshBatch:
	var found: MeshBatch = _lamp_templates.get(side)
	if found != null:
		return found
	var t := MeshBatch.new()
	var solid: MeshLayer = t.layer(skin.solid_material())
	var glow: MeshLayer = t.layer(skin.glow_material())
	solid.box(Vector3(-side * 0.06, 0.12, 0.0), Vector3(0.12, 0.05, 0.05), csk.brass_dim_color, 0.0, MeshKit.PAT_CASINO_BRASS,
		MeshKit.ALL_FACES, 0.4)
	solid.box(Vector3(-side * 0.17, 0.0, 0.0), Vector3(0.2, 0.34, 0.2), skin.lamp_color, 0.8)
	solid.box(Vector3(-side * 0.17, -0.2, 0.0), Vector3(0.24, 0.05, 0.24), csk.brass_dim_color, 0.0, MeshKit.PAT_CASINO_BRASS,
		MeshKit.ALL_FACES, 0.4)
	var halo: Array = _wall_screen(side, -side * 0.1, -1.5, 3.0, -1.5, 3.0)
	glow.rect(halo[0], halo[1], halo[2], skin.lamp_color, 0.2, MeshKit.SHAPE_RADIAL)
	_lamp_templates[side] = t
	return t


# --- A row of lounges -------------------------------------------------------------------------

## The lounges' upper floors: iron balconies with ivy in planters, air-conditioning units, and lit
## blade signs over the street (all at or above overhang_min_height, itself at or above decor_min_height).
func _lounge_extras(_batch: MeshBatch, solid: MeshLayer, glow: MeshLayer, b: MarketFacades.Building, face_x: float,
		_u0: float, _u1: float, start: float, end: float) -> void:
	var side: int = b.side
	var cells: int = floori((b.b1 - b.b0) / b.cell)
	var first_storey: int = maxi(1, ceili((csk.overhang_min_height - 0.2 - skin.gallery_top) / STOREY))
	var top_storey: int = floori((b.height - 1.0 - skin.gallery_top - 0.2) / STOREY)
	var usable: int = top_storey - first_storey + 1
	if cells > 0 and usable > 0:
		# Balconies and units go to slots (a window cell and a storey) picked by hash and spread by a stride
		# coprime with the slot count, so every pick is a different slot and the cost follows the number
		# placed, not the number of slots.
		var slots: int = cells * usable
		var balconies: int = roundi(float(slots) * csk.balcony_share * 0.34)
		var units: int = roundi(float(slots) * csk.unit_share * 0.3)
		var stride: int = 7 if slots % 7 != 0 else 11
		var first: int = MeshKit.hash_i(b.seed, side, 71) % slots
		for j: int in balconies + units:
			var slot: int = (first + j * stride) % slots
			var k: int = floori(float(slot) / float(usable))
			var cx: float = b.grid_start + (float(k) + 0.5) * b.cell
			if cx < start or cx >= end:
				continue
			var storey: int = first_storey + slot % usable
			var floor_y: float = skin.gallery_top + 0.2 + storey * STOREY
			if j < balconies:
				solid.append(_balcony(side, (b.seed + k + storey) % 3), Transform3D(Basis.IDENTITY, Vector3(face_x, floor_y, -cx)))
			else:
				var shift: float = 0.4 if (slot & 1) == 0 else -0.4
				solid.append(_unit(side), Transform3D(Basis.IDENTITY, Vector3(face_x, floor_y + 0.25, -(cx + shift))))
	# Blade signs sticking out over the street, high up: lit, unframed (a hazard sign wears the frame).
	var signs: int = MeshKit.hash_i(side, b.id, 50) % 3
	for i: int in signs:
		var d: float = lerpf(b.b0 + 2.0, b.b1 - 2.0, (float(i) + 0.3 + 0.4 * MeshKit.hash01(side, b.id, 51 + i)) / signs)
		if d < start or d >= end:
			continue
		var y: float = csk.overhang_min_height + 0.6 + 4.0 * MeshKit.hash01(side, b.id, 55 + i)
		_blade_sign(solid, glow, side, face_x, d, y, MeshKit.hash_i(side, b.id, 58 + i))


## An iron balcony for the face on `side` (its floor centre on the wall at the origin): a slab, a brass
## rail on slim posts, and a planter with ivy spilling over its rail; `pots` 0 to 2 more planters. Only
## the faces the street can see are built (the camera is below it: no top for the slab, no back to the
## posts), so a balcony is about 200 vertices. Cached per side and pot count.
func _balcony(side: int, pots: int) -> MeshLayer:
	var key := Vector3i(10, side, pots)
	var found: MeshLayer = _templates.get(key)
	if found != null:
		return found
	var s := MeshLayer.new()
	var reach: float = BALCONY_REACH
	var hw: float = 1.05
	var bx: float = -side * reach * 0.5
	var iron: Color = csk.iron_color
	var toward: int = MeshKit.FACE_NX if side > 0 else MeshKit.FACE_PX
	var wallward: int = MeshKit.FACE_PX if side > 0 else MeshKit.FACE_NX
	s.box(Vector3(bx, 0.05, 0.0), Vector3(reach, 0.12, hw * 2.0), iron, 0.0, MeshKit.PAT_CASINO_IRON,
		MeshKit.ALL_FACES & ~(MeshKit.FACE_PY | wallward), 0.0)
	var rx: float = -side * (reach - 0.03)
	s.box(Vector3(rx, 1.0, 0.0), Vector3(0.06, 0.06, hw * 2.0), csk.brass_color, 0.0, MeshKit.PAT_CASINO_BRASS,
		MeshKit.FACE_PY | MeshKit.FACE_PZ | toward, 0.5)
	for i: int in 4:
		var pz: float = -hw + 0.05 + float(i) * (hw * 2.0 - 0.1) / 3.0
		s.box(Vector3(rx, 0.5, pz), Vector3(0.04, 1.0, 0.04), iron, 0.0, MeshKit.PAT_PLAIN, MeshKit.FACE_PZ | toward)
	# Ivy in planters standing on the slab, hanging over the rail.
	for i: int in 1 + pots:
		var pz: float = (float(i) - 0.5 * float(pots)) * 0.7
		s.box(Vector3(bx - side * 0.05, 0.36, pz), Vector3(0.42, 0.5, 0.6), Color(0.25, 0.19, 0.15), 0.0, MeshKit.PAT_PLAIN,
			MeshKit.FACE_PZ | MeshKit.FACE_NZ | toward | MeshKit.FACE_NY)
		s.box(Vector3(bx - side * 0.05, 0.66, pz), Vector3(0.46, 0.22, 0.64), csk.ivy_color, 0.0, MeshKit.PAT_PLAIN,
			MeshKit.FACE_PZ | MeshKit.FACE_NZ | toward | MeshKit.FACE_PY)
		s.box(Vector3(rx + side * 0.02, 0.78, pz), Vector3(0.14, 0.45, 0.4), csk.ivy_color.darkened(0.12), 0.0, MeshKit.PAT_PLAIN,
			MeshKit.FACE_PZ | MeshKit.FACE_NZ | toward)
	_templates[key] = s
	return s


## An air-conditioning unit on the wall on `side` (its bottom centre at the origin): a weathered casing
## on two brackets, a fan behind a round guard beside a bank of fins on its front (PAT_TECH), and the
## dirty streak its drip leaves on the wall below it. Cached per side.
func _unit(side: int) -> MeshLayer:
	var key := Vector3i(11, side, 0)
	var found: MeshLayer = _templates.get(key)
	if found != null:
		return found
	var s := MeshLayer.new()
	var w: float = 0.9
	var h: float = 0.6
	var d: float = 0.42
	var casing := Color(0.22, 0.22, 0.2)
	s.box(Vector3(-side * d * 0.5, h * 0.5, 0.0), Vector3(d, h, w), casing, 0.0, MeshKit.PAT_PLAIN,
		MeshKit.ALL_FACES & ~(MeshKit.FACE_PX if side > 0 else MeshKit.FACE_NX))
	var face: Array = _wall_screen(side, -side * (d + 0.002), -w * 0.5, w, 0.0, h)
	s.rect(face[0], face[1], face[2], casing, 0.0, MeshKit.PAT_TECH, Vector2.ZERO, Vector2(w, h), 1.0)
	s.box(Vector3(-side * 0.25, -0.03, 0.0), Vector3(0.5, 0.05, w * 0.7), Color(0.15, 0.15, 0.16), 0.0, MeshKit.PAT_PLAIN,
		MeshKit.FACE_NY | MeshKit.FACE_PZ | MeshKit.FACE_NZ)
	var streak: Array = _wall_screen(side, -side * 0.004, -0.06, 0.05, -1.3, 1.25)
	s.rect(streak[0], streak[1], streak[2], skin.grime_color, 0.0)
	_templates[key] = s
	return s


## A lit blade sign sticking out of the wall at distance d, bottom at y: a dark board in a slim brass
## edge with a lit face (PAT_CASINO_SIGN, its lettering running down the board like the reference's
## "The Brass Lotus"), in warm white, violet or blue, always unframed, facing the approaching player.
## It stands out of the wall by under a metre (the arrival flyover's camera keeps a metre inside the
## walls), and is too narrow for the cult's emblem, which hides on the wall signs instead.
func _blade_sign(solid: MeshLayer, glow: MeshLayer, side: int, x: float, d: float, y: float, k: int) -> void:
	var h: float = 3.0 + 1.2 * MeshKit.hash01(k, 1)
	var reach: float = 0.8
	var inner: float = x - side * (reach + 0.15)
	var outer: float = x - side * 0.15
	var x_min: float = minf(inner, outer)
	var dark: Color = csk.sign_panel_color
	# Brackets to the wall, and the board's back and edge.
	for by: float in [y + h - 0.25, y + 0.25]:
		solid.box(Vector3((x + outer) * 0.5, by, -d), Vector3(0.18, 0.06, 0.06), csk.brass_dim_color, 0.0, MeshKit.PAT_CASINO_BRASS,
			MeshKit.ALL_FACES, 0.4)
	solid.box(Vector3((inner + outer) * 0.5, y + h * 0.5, -d - 0.05), Vector3(reach, h, 0.08), dark, 0.0,
		MeshKit.PAT_PLAIN, MeshKit.ALL_FACES & ~MeshKit.FACE_PZ)
	solid.box(Vector3((inner + outer) * 0.5, y + h - 0.02, -d - 0.05), Vector3(reach + 0.08, 0.08, 0.12), csk.brass_color, 0.0,
		MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.5)
	solid.box(Vector3((inner + outer) * 0.5, y + 0.02, -d - 0.05), Vector3(reach + 0.08, 0.08, 0.12), csk.brass_color, 0.0,
		MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.5)
	var band: float = minf(reach * 0.8, 0.95)
	var top: float = y + h - 0.16
	var length: float = top - (y + 0.16)
	var param: float = float((k % 100) + 100 * roundi(band * 10.0))
	if length > 0.8 and MeshKit.hash01(k, 7) < csk.dim_sign_share:
		# A dim painted board (the reference's coloured signs, kept muted and unlit): its lettering in
		# pale paint, never glowing.
		var paint: Color = csk.dim_sign_colors[k % csk.dim_sign_colors.size()]
		solid.rect(Vector3(x_min + (reach - band) * 0.5, top, -d + 0.004), Vector3(0, -length, 0), Vector3(band, 0, 0), paint,
			0.0, MeshKit.PAT_SHOPSIGN, Vector2.ZERO, Vector2(length, band), param + float(MarketFacades.LETTERING_ONLY))
	elif length > 0.8:
		# The lettering runs down the board (UV.x along u, from the top), its rows across it.
		var color: Color = skin.neon_colors[k % skin.neon_colors.size()]
		solid.rect(Vector3(x_min + (reach - band) * 0.5, top, -d + 0.004), Vector3(0, -length, 0), Vector3(band, 0, 0), color,
			0.6, MeshKit.PAT_CASINO_SIGN, Vector2.ZERO, Vector2(length, band), param)
		glow.rect(Vector3(x_min - 0.5, top - length - 0.4, -d + 0.2), Vector3(reach + 1.0, 0, 0), Vector3(0, length + 0.8, 0), color,
			0.1, MeshKit.SHAPE_FLAT)


# --- Casinos -----------------------------------------------------------------------------------

## Casino dressing: a marquee of bulbs along a storey line and up the corners, a big lit sign (or the
## cult's feed) with a brass frame and halo, and a bulb marquee, everything flat on the face and above
## decor_min_height. Each casino with a big sign carries one of the two names, in real letters (task K3,
## CasinoLettering): on its sign (Gasket's as a strip over it if it plays the feed; the Brass Lotus's
## feed sign has none) and on a tall blade sign at one end of the building, where a runner sees it face-on
## from afar (GASKET'S, or THE BRASS LOTUS, stacked down it).
func _casino(batch: MeshBatch, solid: MeshLayer, glow: MeshLayer, b: MarketFacades.Building, face_x: float, u0: float, u1: float,
		start: float, end: float) -> void:
	var side: int = b.side
	var y0: float = skin.decor_min_height
	var mx: float = face_x - side * 0.03
	_panel(solid, side, mx, u0, u1, y0, y0 + 0.64, skin.bulb_color, 0.7, MeshKit.PAT_BULBS)
	for e: float in [b.b0 + 0.2, b.b1 - 0.55]:
		if e + 0.35 > start and e < end:
			_panel(solid, side, mx, maxf(e, u0), minf(e + 0.35, u1), y0 + 0.64, b.height - 1.2, skin.bulb_color, 0.7,
				MeshKit.PAT_BULBS)
	var mid: float = (b.b0 + b.b1) * 0.5
	var spec: Dictionary = _casino_sign(b, face_x)
	if spec.is_empty():
		return
	var names: Array[Dictionary] = _name_specs(b, face_x, spec)
	if mid >= start and mid < end:
		_big_sign(batch, solid, glow, b, face_x, spec, names)
	for piece: Dictionary in names:
		var at: float = piece["at"]
		if at >= start and at < end:
			_name_piece(solid, glow, b, face_x, piece)


## The casino's big sign: a brass-edged frame, the face (a lit sign whose panel is dark and tube-edged for
## its name's letters, or the cult's feed) and the halo; the cult's emblem in a corner if the letters leave
## room.
func _big_sign(batch: MeshBatch, solid: MeshLayer, glow: MeshLayer, b: MarketFacades.Building, face_x: float, spec: Dictionary,
		names: Array[Dictionary]) -> void:
	var side: int = b.side
	var mid: float = (b.b0 + b.b1) * 0.5
	var h: float = spec["h"]
	var sy: float = spec["y0"]
	var length: float = spec["length"]
	var sx: float = spec["x"]
	var d0: float = mid - length * 0.5
	# The sign's brass-edged frame, then its face.
	solid.box(Vector3(face_x - side * 0.04, sy + h * 0.5, -mid), Vector3(0.08, h + FRAME * 2.0, length + FRAME * 2.0),
		csk.brass_dim_color, 0.0, MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES & ~FACE_AGAINST[side], 0.4)
	var screen: Array = _wall_screen(side, sx, d0, length, sy, h)
	var color: Color = skin.neon_colors[b.seed % skin.neon_colors.size()]
	if skin.shows_feed(b.seed, 62):
		CultFeed.screen(batch.layer(skin.feed_material()), screen[0], screen[1], screen[2], skin.feed_board_brightness, b.seed)
		color = CultFeed.FEED_COLOR
	else:
		var param: float = float((b.seed % 100) + 100 * roundi(h * 10.0)) + CasinoLettering.NAMED_PANEL
		solid.rect(screen[0], screen[1], screen[2], color, 0.6, MeshKit.PAT_CASINO_SIGN, Vector2.ZERO, Vector2(length, h), param)
		# The cult's emblem only where the letters leave its corner free (it's about 28% of the sign's height).
		var room: float = length
		for piece: Dictionary in names:
			if piece["kind"] == &"board":
				room = length - (piece["box"] as Vector2).x
		if skin.carries_emblem(b.seed, 60) and room * 0.5 >= maxf(h * 0.28, skin.emblem_min_size) * 1.3:
			_corner_emblem(solid, side, sx, d0, length, sy, h)
	# The halo lies flat on the wall behind the frame and the face (under the arena's rule: nothing more than
	# 30 cm out of a face below overhang_min_height, where The House fills the street to 35 cm off the walls).
	glow.rect(Vector3(face_x - side * 0.06, sy - 1.0, -d0 + 1.0), Vector3(0, 0, -(length + 2.0)), Vector3(0, h + 2.0, 0), color, 0.1,
		MeshKit.SHAPE_FLAT)


## Where a casino's big sign goes: the screen's plane (x), bottom (y0), height (h) and length, in the
## mid-height of its face (always above decor_min_height); empty if the casino is too small for one.
func _casino_sign(b: MarketFacades.Building, face_x: float) -> Dictionary:
	var length: float = minf(b.b1 - b.b0 - 3.0, 12.0)
	var h: float = 3.6
	if length <= 5.0:
		return {}
	var y0: float = skin.decor_min_height + 2.0 + 2.5 * MeshKit.hash01(b.side, b.id, 66)
	return {"x": face_x - b.side * 0.1, "y0": y0, "h": h, "length": length}


# --- The names ----------------------------------------------------------------------------------

## DESIGN-TBD (docs/questions/k3.md 2 and 3): the strip over a feed sign, the blade of every named casino and
## the names appearing on casinos' signs alone.
## The pieces of lettering of casino `b` (the building with a big sign `spec`): each {name (CasinoLettering
## NAME_*), kind (&"board": on the big sign, &"strip": over a sign that plays the feed, &"blade": a tall blade
## sign at one end of the building), layout, at (the distance along the wall that decides which chunk builds it), x (the plane of the
## letters, or for a blade the middle of its letters across it), y (their centre), scale (metres per cap height), box (their block, in metres), y_min, and for
## a strip or a blade its board's y0, height and length}. By hash of the building: the same every build.
func _name_specs(b: MarketFacades.Building, face_x: float, spec: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var side: int = b.side
	var which: int = CasinoLettering.pick(side, b.id)
	var feed: bool = skin.shows_feed(b.seed, 62)
	var mid: float = (b.b0 + b.b1) * 0.5
	var h: float = spec["h"]
	var sy: float = spec["y0"]
	var length: float = spec["length"]
	var plane: float = float(spec["x"]) - side * LETTER_LIFT
	if not feed:
		var layout: int = CasinoLettering.Layout.LOTUS_BOARD
		if which == CasinoLettering.NAME_GASKETS:
			layout = CasinoLettering.Layout.GASKETS_BOARD
		var s: float = CasinoLettering.fit(layout, Vector2(length - 2.0 * BOARD_MARGIN.x, h - 2.0 * BOARD_MARGIN.y))
		if s > 0.0:
			var box: Vector2 = CasinoLettering.layout_size(layout) * s
			out.append({"name": which, "kind": &"board", "layout": layout, "at": mid, "x": plane, "y": sy + h * 0.5, "scale": s,
				"box": box, "y_min": sy + h * 0.5 - box.y * 0.5})
	elif which == CasinoLettering.NAME_GASKETS:
		# A strip of one line over the screen, in its own brass frame.
		var layout: int = CasinoLettering.Layout.GASKETS_STRIP
		var s: float = CasinoLettering.fit(layout, Vector2(length - 2.0 * BOARD_MARGIN.x, 99.0))
		if s > 0.0:
			var box: Vector2 = CasinoLettering.layout_size(layout) * s
			var strip_h: float = box.y + 2.0 * STRIP_PAD
			var strip_y0: float = sy + h + FRAME + STRIP_GAP
			out.append({"name": which, "kind": &"strip", "layout": layout, "at": mid, "x": plane, "y": strip_y0 + strip_h * 0.5,
				"scale": s, "box": box, "y_min": strip_y0 + strip_h * 0.5 - box.y * 0.5, "board_y0": strip_y0, "board_h": strip_h,
				"board_length": length})
	# Both names carry a blade sign (a casino's tall sign sticking out of the wall, seen face-on from afar).
	var blade: int = CasinoLettering.Layout.LOTUS_BLADE
	if which == CasinoLettering.NAME_GASKETS:
		blade = CasinoLettering.Layout.GASKETS_BLADE
	var blade_size: Vector2 = CasinoLettering.layout_size(blade)
	var blade_y0: float = csk.overhang_min_height + 0.6
	var room: float = b.height - 0.6 - blade_y0 - 2.0 * BLADE_PAD
	var blade_s: float = minf(BLADE_LETTER, room / blade_size.y) if blade_size.y > 0.0 else 0.0
	if blade_s >= BLADE_LETTER_MIN:
		var box: Vector2 = blade_size * blade_s
		var board_h: float = box.y + 2.0 * BLADE_PAD
		var at: float = b.b0 + 1.0 if MeshKit.hash01(side, b.id, 69) < 0.5 else b.b1 - 1.0
		var letters_x: float = face_x - side * (BLADE_REACH * 0.5 + BLADE_SETBACK)
		out.append({"name": which, "kind": &"blade", "layout": blade, "at": at, "x": letters_x, "y": blade_y0 + board_h * 0.5,
			"scale": blade_s, "box": box, "y_min": blade_y0 + board_h * 0.5 - box.y * 0.5, "board_y0": blade_y0,
			"board_h": board_h})
	return out


## The casinos' lettering (for reviews and tests, like MarketplaceSkin.feed_boards()): the pieces of
## _name_specs() whose `at` lies in [start, end), each with its side and the centre of its letters.
func named_signs(side: int, face_x: float, start: float, end: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lot: float = skin.lot_length
	var span: Vector2i = MeshKit.lot_run(side, floori(start / lot), 0.45, 3, 3)
	while span.x * lot < end:
		var b: MarketFacades.Building = building(side, span)
		if b.kind == MarketFacades.Kind.CASINO:
			var spec: Dictionary = _casino_sign(b, face_x)
			if not spec.is_empty():
				for piece: Dictionary in _name_specs(b, face_x, spec):
					var at: float = piece["at"]
					if at >= start and at < end:
						var entry: Dictionary = piece.duplicate()
						entry["side"] = side
						entry["center"] = Vector3(float(piece["x"]), float(piece["y"]), -at)
						out.append(entry)
		span = MeshKit.lot_run(side, span.y + 1, 0.45, 3, 3)
	return out


## Builds one piece of lettering: the board of a strip or a blade (the big sign's own is built with it), then
## the letters themselves, in the skin's lettering colour, a little in front of their board.
func _name_piece(solid: MeshLayer, glow: MeshLayer, b: MarketFacades.Building, face_x: float, piece: Dictionary) -> void:
	var side: int = b.side
	var s: float = piece["scale"]
	var letters: MeshLayer = _letters(piece["layout"])
	var kind: StringName = piece["kind"]
	if kind == &"strip":
		_strip_board(solid, glow, b, face_x, piece)
	elif kind == &"blade":
		_lotus_blade(solid, glow, b, face_x, piece)
		# The blade faces the approaching player (+z), its letters a little in front of the face.
		solid.append(letters, Transform3D(Basis.from_scale(Vector3(s, s, s)),
			Vector3(float(piece["x"]), float(piece["y"]), -float(piece["at"]) + BLADE_LETTER_LIFT)))
		return
	# On a wall: u to the viewer's right along the wall, v up, n out toward the street.
	var u := Vector3(0, 0, -1) if side < 0 else Vector3(0, 0, 1)
	var n := Vector3(-side, 0, 0)
	var centre_z: float = -(b.b0 + b.b1) * 0.5
	solid.append(letters, Transform3D(Basis(u * s, Vector3(0, s, 0), n * s), Vector3(float(piece["x"]), float(piece["y"]), centre_z)))


## The coloured lettering template of a layout (CasinoLettering.layer()), built once per skin.
func _letters(layout: int) -> MeshLayer:
	var found: MeshLayer = _lettering.get(layout)
	if found == null:
		found = CasinoLettering.layer(layout, csk.lettering_color, csk.lettering_glow)
		_lettering[layout] = found
	return found


## The dark strip over a feed sign that carries Gasket's name: a brass-edged frame and a tube-lit face.
func _strip_board(solid: MeshLayer, _glow: MeshLayer, b: MarketFacades.Building, face_x: float, piece: Dictionary) -> void:
	var side: int = b.side
	var mid: float = (b.b0 + b.b1) * 0.5
	var y0: float = piece["board_y0"]
	var h: float = piece["board_h"]
	var length: float = piece["board_length"]
	solid.box(Vector3(face_x - side * 0.04, y0 + h * 0.5, -mid), Vector3(0.08, h + FRAME * 2.0, length + FRAME * 2.0),
		csk.brass_dim_color, 0.0, MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES & ~FACE_AGAINST[side], 0.4)
	var screen: Array = _wall_screen(side, face_x - side * 0.1, mid - length * 0.5, length, y0, h)
	var color: Color = skin.neon_colors[b.seed % skin.neon_colors.size()]
	var param: float = float((b.seed % 100) + 100 * roundi(h * 10.0)) + CasinoLettering.NAMED_PANEL
	solid.rect(screen[0], screen[1], screen[2], color, 0.6, MeshKit.PAT_CASINO_SIGN, Vector2.ZERO, Vector2(length, h), param)


## The Brass Lotus's blade sign: a tall dark board standing out of the wall (like the reference's), in brass
## edges and a tube of light, facing the approaching player, under a metre out of the face (the arrival
## flyover's camera keeps a metre inside the walls) and above overhang_min_height. Its letters are placed by
## the caller.
func _lotus_blade(solid: MeshLayer, glow: MeshLayer, b: MarketFacades.Building, face_x: float, piece: Dictionary) -> void:
	var side: int = b.side
	var d: float = piece["at"]
	var y0: float = piece["board_y0"]
	var h: float = piece["board_h"]
	var inner: float = face_x - side * (BLADE_REACH + 0.15)
	var outer: float = face_x - side * 0.15
	var x_min: float = minf(inner, outer)
	var mid_x: float = (inner + outer) * 0.5
	var dark: Color = csk.sign_panel_color
	for by: float in [y0 + h - 0.3, y0 + 0.3]:
		solid.box(Vector3((face_x + outer) * 0.5, by, -d), Vector3(0.18, 0.06, 0.06), csk.brass_dim_color, 0.0, MeshKit.PAT_CASINO_BRASS,
			MeshKit.ALL_FACES, 0.4)
	solid.box(Vector3(mid_x, y0 + h * 0.5, -d - 0.05), Vector3(BLADE_REACH, h, 0.08), dark, 0.0, MeshKit.PAT_PLAIN,
		MeshKit.ALL_FACES & ~MeshKit.FACE_PZ)
	# Brass caps at both ends and rails down both edges.
	for cy: float in [y0 + h - 0.02, y0 + 0.02]:
		solid.box(Vector3(mid_x, cy, -d - 0.05), Vector3(BLADE_REACH + 0.08, 0.08, 0.12), csk.brass_color, 0.0,
			MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.5)
	for rx: float in [inner, outer]:
		solid.box(Vector3(rx, y0 + h * 0.5, -d - 0.05), Vector3(0.05, h, 0.12), csk.brass_color, 0.0, MeshKit.PAT_CASINO_BRASS,
			MeshKit.ALL_FACES, 0.5)
	var band: float = BLADE_REACH - 0.1
	var top: float = y0 + h - 0.1
	var length: float = h - 0.2
	var color: Color = skin.neon_colors[b.seed % skin.neon_colors.size()]
	var param: float = float((b.seed % 100) + 100 * roundi(band * 10.0)) + CasinoLettering.NAMED_PANEL
	solid.rect(Vector3(x_min + (BLADE_REACH - band) * 0.5, top, -d + 0.004), Vector3(0, -length, 0), Vector3(band, 0, 0), color, 0.6,
		MeshKit.PAT_CASINO_SIGN, Vector2.ZERO, Vector2(length, band), param)
	# The halo stands just behind the board (hidden by it, showing round it), so it never veils the letters.
	glow.rect(Vector3(x_min - 0.5, y0 - 0.4, -d - 0.015), Vector3(BLADE_REACH + 1.0, 0, 0), Vector3(0, h + 0.8, 0), color, 0.1,
		MeshKit.SHAPE_FLAT)


## An arcade hall: a lit name board over the middle, high up, with a brass frame.
func _hall(solid: MeshLayer, b: MarketFacades.Building, face_x: float, start: float, end: float) -> void:
	var mid: float = (b.b0 + b.b1) * 0.5
	if mid < start or mid >= end:
		return
	var length: float = minf(b.b1 - b.b0 - 4.0, 9.0)
	var h: float = 1.5
	var y: float = skin.decor_min_height + 7.0 + 2.0 * MeshKit.hash01(b.side, b.id, 67)
	if length < 3.0:
		return
	var color: Color = skin.neon_colors[(b.seed + 1) % skin.neon_colors.size()]
	solid.box(Vector3(face_x - b.side * 0.04, y + h * 0.5, -mid), Vector3(0.08, h + FRAME * 2.0, length + FRAME * 2.0),
		csk.brass_dim_color, 0.0, MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES & ~FACE_AGAINST[b.side], 0.4)
	_panel(solid, b.side, face_x - b.side * 0.085, mid - length * 0.5, mid + length * 0.5, y, y + h, color, 0.5,
		MeshKit.PAT_CASINO_SIGN, float((b.seed % 100) + 100 * roundi(h * 10.0)), true)


## A banner of heavy cloth hung flat on the face (the reference's banners), on some buildings: high up,
## never lower than decor_min_height, a flat sheet a few centimetres proud of the wall.
func _wall_banner(solid: MeshLayer, b: MarketFacades.Building, face_x: float, start: float, end: float) -> void:
	if MeshKit.hash01(b.side, b.id, 120) >= 0.45:
		return
	var d: float = lerpf(b.b0 + 2.0, b.b1 - 2.0, MeshKit.hash01(b.side, b.id, 121))
	if d < start or d >= end:
		return
	var width: float = csk.banner_width
	var length: float = 4.0 + 3.0 * MeshKit.hash01(b.side, b.id, 122)
	var top: float = b.height - 2.0 - 4.0 * MeshKit.hash01(b.side, b.id, 123)
	var bottom: float = top - length
	if bottom < skin.decor_min_height + 1.0:
		return
	var seed: int = MeshKit.hash_i(b.side, b.id, 124) % 40
	var screen: Array = _wall_screen(b.side, face_x - b.side * 0.04, d - width * 0.5, width, bottom, length)
	solid.rect(screen[0], screen[1], screen[2], csk.banner_colors[seed % csk.banner_colors.size()], 0.0, MeshKit.PAT_CASINO_BANNER,
		Vector2(0.0, length), Vector2(1.0, 0.0), float(roundi(length * 10.0) + 1000 * seed))

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
## big lit signs, banners of heavy cloth, all unframed (hazard signs wear the yellow/black frame) and
## none below `decor_min_height`.
## Nothing vent-like at the foot of the walls (the screeches' lairs, GDD §5, §9.5), nothing glowing or
## sticking out through the wall-run band (`band_top`): every wall is flush from the street up past it,
## and what stands out of a face by more than a hand's width starts at `overhang_min_height`.
## All variety comes from hashing lot indices, so chunk cuts never change a building.

## How many storeys a balcony may hang from, and its reach (metres).
const BALCONY_REACH: float = 0.95
## Added to the lit sign's size: its frame around the panel.
const FRAME: float = 0.16

## Wall lamps built once per side (_lamp).
var _lamp_templates: Dictionary = {}


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
## ends, and on some a riser up the face. Nothing lower than
## overhang_min_height.
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
## decor_min_height.
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
	if mid < start or mid >= end or spec.is_empty():
		return
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
		var param: float = float((b.seed % 100) + 100 * roundi(h * 10.0))
		solid.rect(screen[0], screen[1], screen[2], color, 0.6, MeshKit.PAT_CASINO_SIGN, Vector2.ZERO, Vector2(length, h), param)
		if skin.carries_emblem(b.seed, 60):
			_corner_emblem(solid, side, sx, d0, length, sy, h)
	glow.rect(Vector3(sx - side * 0.4, sy - 1.0, -d0 + 1.0), Vector3(0, 0, -(length + 2.0)), Vector3(0, h + 2.0, 0), color, 0.1,
		MeshKit.SHAPE_FLAT)


## Where a casino's big sign goes (DESIGN-TBD, docs/questions/k1.md 3: its lettering is rows of glyphs, as every
## skin's, so "Gasket's House of Chance" can't be spelled): the screen's plane (x), bottom (y0), height (h) and length, in the
## mid-height of its face (always above decor_min_height); empty if the casino is too small for one.
func _casino_sign(b: MarketFacades.Building, face_x: float) -> Dictionary:
	var length: float = minf(b.b1 - b.b0 - 3.0, 12.0)
	var h: float = 3.6
	if length <= 5.0:
		return {}
	var y0: float = skin.decor_min_height + 2.0 + 2.5 * MeshKit.hash01(b.side, b.id, 66)
	return {"x": face_x - b.side * 0.1, "y0": y0, "h": h, "length": length}


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

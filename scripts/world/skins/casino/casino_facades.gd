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
## How far a lounge's blade sign's board reaches out of the face, past its brackets.
const LOUNGE_BLADE_REACH: float = 0.8
## Added to the lit sign's size: its frame around the panel.
const FRAME: float = 0.16

## The names' lettering (task K3): how far the letters stand in front of their board, the room kept round them
## on a board (across, up), the padding of a strip over a feed sign and the gap above that sign, and the Brass
## Lotus's blade: how far out of the wall it reaches (under a metre with its brackets: the arrival flyover's
## camera keeps a metre inside the walls), how far the board stands from the face, how tall a capital is on it,
## the least that is still legible (a casino under a low roof gets none rather than tiny letters), the board's
## padding above and below the letters, and how far its letters stand in front of it.
const LETTER_LIFT: float = 0.01
const BOARD_MARGIN := Vector2(0.55, 0.5)
const STRIP_PAD: float = 0.25
const STRIP_GAP: float = 0.2
const BLADE_REACH: float = 0.8
const BLADE_SETBACK: float = 0.15
const BLADE_LETTER: float = 0.58
const BLADE_LETTER_MIN: float = 0.4
const BLADE_PAD: float = 0.35
const BLADE_LETTER_LIFT: float = 0.02
## The top metre of a building is its entablature (a brass band and a cornice 0.4 m out): a blade sign stops
## under it. The cult's emblem on a named board keeps its width times this much room.
const ENTABLATURE: float = 1.1
## Where the faces are kept flush (the arena) nothing stands out of a wall by more than this.
const FLUSH_DEPTH: float = 0.1
const EMBLEM_AIR: float = 1.4

## Wall lamps built once per side (_lamp).
var _lamp_templates: Dictionary = {}
## The buildings whose windows have been widened (bay_scale): building() runs again for a cached building.
var _widened: Dictionary = {}
## The lettering in the skin's colour, built once per layout (_letters).
var _lettering: Dictionary = {}
## The named casino of each period of the street ({side, id}, or {}; _landmark()).
var _landmarks: Dictionary = {}


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
	if csk.bay_scale > 1.01 and not _widened.has(b):
		if _widened.size() > 600:
			_widened.clear()
		_widened[b] = true
		_widen(b, csk.bay_scale)
	return b


## The building's shop windows at `scale` times the Marketplace's bay width: the same piers, fewer bays.
static func _widen(b: MarketFacades.Building, scale: float) -> void:
	var count: int = b.windows.size()
	var wide: int = maxi(1, roundi(float(count) / scale))
	if count < 2 or wide >= count:
		return
	var first: float = b.windows[0].x
	var pier: float = b.windows[1].x - b.windows[0].y
	var each: float = (b.windows[count - 1].y - first + pier) / float(wide)
	b.windows.clear()
	for k: int in wide:
		var w0: float = first + float(k) * each
		b.windows.append(Vector2(w0, w0 + each - pier))


## The shop windows windows() lists whose hash (side, the window's key, salt) is under `share`, in the same
## order and with the same entries: for a caller that wants a few of them (the citizens), without building
## the entry of every other window. test_casino_skin checks it against windows().
func windows_picked(side: int, face_x: float, start: float, end: float, salt: int, share: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lot: float = skin.lot_length
	var span: Vector2i = MeshKit.lot_run(side, floori(start / lot), 0.45, 3, 3)
	while span.x * lot < end:
		var b: MarketFacades.Building = building(side, span)
		for w: Vector2 in b.windows:
			var at: float = (w.x + w.y) * 0.5
			if at >= start and at < end and MeshKit.hash01(side, MeshKit.key(at), salt) < share \
					and not skin.wall_gap_near(side, w.x, w.y):
				out.append({"side": side, "at": at,
					"center": Vector3(face_x, (skin.gallery_bottom + skin.gallery_top) * 0.5, -at),
					"width": w.y - w.x, "bottom": skin.gallery_bottom, "top": skin.gallery_top, "depth": skin.shop_depth,
					"kind": [&"shop", &"casino", &"hall"][b.kind], "screen": _has_tv(b, w)})
		span = MeshKit.lot_run(side, span.y + 1, 0.45, 3, 3)
	return out


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
	var cornice: float = FLUSH_DEPTH if csk.flush_faces else 0.4
	var band: float = FLUSH_DEPTH + 0.01 if csk.flush_faces else 0.5
	solid.box(Vector3(face_x - side * cornice * 0.5, b.height - 0.45, zc), Vector3(cornice, 0.9, u1 - u0), skin.iron_color, 0.0,
		MeshKit.PAT_CASINO_IRON, MeshKit.ALL_FACES & ~FACE_AGAINST[side], 2.0)
	solid.box(Vector3(face_x - side * (band * 0.5 + (0.0 if csk.flush_faces else 0.01)), b.height - 0.98, zc), Vector3(band, 0.12, u1 - u0),
		csk.brass_color, 0.0, MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES & ~FACE_AGAINST[side], 0.5)

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
## The faces of something standing out of the wall on each side that a runner can see: all but the one toward the
## wall and the one facing away down the street (the camera follows the runner, so it only looks ahead).
const SEEN_FACES: Dictionary = {
	-1: MeshKit.ALL_FACES & ~(MeshKit.FACE_NX | MeshKit.FACE_NZ), 1: MeshKit.ALL_FACES & ~(MeshKit.FACE_PX | MeshKit.FACE_NZ)}


# --- Brass pipes ------------------------------------------------------------------------------

## Thick brass pipes along the face (the reference's pipes and ducts): one or two runs along the
## building between the first storey above the calm band and the roof, with a flange at the building's
## ends, and on some a riser up the face. Nothing lower than overhang_min_height.
func _pipes(solid: MeshLayer, b: MarketFacades.Building, face_x: float, u0: float, u1: float) -> void:
	# None on a named casino (a pipe in front of its letters crosses them from afar, whatever its length) and
	# none where the faces are kept flush.
	if csk.flush_faces or _name_of(b) >= 0:
		return
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
			_flange(solid, side, x, y, b.b0 + 0.05, radius)
		if u1 >= b.b1 - 0.01:
			_flange(solid, side, x, y, b.b1 - 0.05, radius)
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
				_flange(solid, side, rx, y_bottom + 0.1, rd, rr)


## A brass pipe along the track from distance d0 to d1 (z = -d), centred at (x, y).
static func _pipe_z(s: MeshLayer, x: float, y: float, d0: float, d1: float, radius: float, color: Color) -> void:
	if d1 <= d0 + 0.01:
		return
	var basis := Basis(Vector3(radius, 0, 0), Vector3(0, 0, -(d1 - d0)), Vector3(0, radius, 0))
	s.prism_xform(Transform3D(basis, Vector3(x, y, -d0)), 8, color, 0.0, MeshKit.PAT_CASINO_BRASS, false, 0.5)


## A flange ring where a pipe passes into a building or a neighbour, at distance d.
func _flange(s: MeshLayer, side: int, x: float, y: float, d: float, radius: float) -> void:
	s.box(Vector3(x, y, -d), Vector3(radius * 2.0 + 0.14, radius * 2.0 + 0.14, 0.1), csk.brass_dim_color, 0.0,
		MeshKit.PAT_CASINO_BRASS, SEEN_FACES[side], 0.4)


## Wall lamps: a brass bracket and a warm lantern every nine metres or so, above decor_min_height (a
## decorative light is never lower), standing out of the wall by under 30 cm, each with a soft halo on
## the face (the reference's lamplit haze). Warm white, no real light. One cached template per side. Where the
## faces are kept flush (the arena) the lamp is a flat lantern, FLUSH_DEPTH deep.
func _lamps(batch: MeshBatch, b: MarketFacades.Building, face_x: float, u0: float, u1: float) -> void:
	var side: int = b.side
	var lamp: Array[MeshLayer] = _lamp(side)
	var solid: MeshLayer = batch.layer(skin.solid_material())
	var glow: MeshLayer = batch.layer(skin.glow_material())
	var spacing: float = 9.0
	var k: int = ceili(u0 / spacing)
	while float(k) * spacing < u1:
		var d: float = (float(k) + 0.5 * MeshKit.hash01(side, k, 130)) * spacing
		var y: float = skin.decor_min_height + 0.6 + 1.6 * MeshKit.hash01(side, k, 131)
		k += 1
		if d >= u0 and d < u1:
			var at := Transform3D(Basis.IDENTITY, Vector3(face_x, y, -d))
			solid.append(lamp[0], at)
			glow.append(lamp[1], at)


## One wall lamp on the wall on `side` (the face at x = 0, the lamp's centre at the origin): [its solid parts,
## its halo], cached.
func _lamp(side: int) -> Array[MeshLayer]:
	var key: int = side + (10 if csk.flush_faces else 0)
	var found: Array = _lamp_templates.get(key, [])
	if not found.is_empty():
		var cached: Array[MeshLayer] = [found[0], found[1]]
		return cached
	var solid := MeshLayer.new()
	var glow := MeshLayer.new()
	if csk.flush_faces:
		solid.box(Vector3(-side * FLUSH_DEPTH * 0.5, 0.0, 0.0), Vector3(FLUSH_DEPTH, 0.34, 0.2), skin.lamp_color, 0.8)
		solid.box(Vector3(-side * FLUSH_DEPTH * 0.5, -0.2, 0.0), Vector3(FLUSH_DEPTH, 0.05, 0.24), csk.brass_dim_color, 0.0,
			MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.4)
	else:
		var seen: int = SEEN_FACES[side]
		solid.box(Vector3(-side * 0.06, 0.12, 0.0), Vector3(0.12, 0.05, 0.05), csk.brass_dim_color, 0.0, MeshKit.PAT_CASINO_BRASS,
			seen, 0.4)
		solid.box(Vector3(-side * 0.17, 0.0, 0.0), Vector3(0.2, 0.34, 0.2), skin.lamp_color, 0.8, 0, seen)
		solid.box(Vector3(-side * 0.17, -0.2, 0.0), Vector3(0.24, 0.05, 0.24), csk.brass_dim_color, 0.0, MeshKit.PAT_CASINO_BRASS,
			seen, 0.4)
	var halo: Array = _wall_screen(side, -side * 0.1, -1.5, 3.0, -1.5, 3.0)
	glow.rect(halo[0], halo[1], halo[2], skin.lamp_color, 0.2, MeshKit.SHAPE_RADIAL)
	_lamp_templates[key] = [solid, glow]
	var out: Array[MeshLayer] = [solid, glow]
	return out


# --- A row of lounges -------------------------------------------------------------------------

## The lounges' upper floors: iron balconies with ivy in planters, air-conditioning units, and lit
## blade signs over the street (all at or above overhang_min_height, itself at or above decor_min_height).
func _lounge_extras(_batch: MeshBatch, solid: MeshLayer, glow: MeshLayer, b: MarketFacades.Building, face_x: float,
		_u0: float, _u1: float, start: float, end: float) -> void:
	# Balconies, units and blade signs all stand out of the face: none where the faces are kept flush.
	if csk.flush_faces:
		return
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
		MeshKit.ALL_FACES & ~(MeshKit.FACE_PY | MeshKit.FACE_NZ | wallward), 0.0)
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
			MeshKit.FACE_PZ | toward)
		s.box(Vector3(bx - side * 0.05, 0.66, pz), Vector3(0.46, 0.22, 0.64), csk.ivy_color, 0.0, MeshKit.PAT_PLAIN,
			MeshKit.FACE_PZ | toward | MeshKit.FACE_PY)
		s.box(Vector3(rx + side * 0.02, 0.78, pz), Vector3(0.14, 0.45, 0.4), csk.ivy_color.darkened(0.12), 0.0, MeshKit.PAT_PLAIN,
			MeshKit.FACE_PZ | toward)
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
	s.box(Vector3(-side * d * 0.5, h * 0.5, 0.0), Vector3(d, h, w), casing, 0.0, MeshKit.PAT_PLAIN, SEEN_FACES[side])
	var face: Array = _wall_screen(side, -side * (d + 0.002), -w * 0.5, w, 0.0, h)
	s.rect(face[0], face[1], face[2], casing, 0.0, MeshKit.PAT_TECH, Vector2.ZERO, Vector2(w, h), 1.0)
	s.box(Vector3(-side * 0.25, -0.03, 0.0), Vector3(0.5, 0.05, w * 0.7), Color(0.15, 0.15, 0.16), 0.0, MeshKit.PAT_PLAIN,
		MeshKit.FACE_NY | MeshKit.FACE_PZ)
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
	# The board is 3 to 4.2 m tall in tenths of a metre, so its frame (brackets, back and brass edges) is one of
	# thirteen cached templates per side, a bulk append.
	var steps: int = roundi((3.0 + 1.2 * MeshKit.hash01(k, 1)) * 10.0)
	var h: float = float(steps) * 0.1
	var reach: float = LOUNGE_BLADE_REACH
	var inner: float = x - side * (reach + 0.15)
	var outer: float = x - side * 0.15
	var x_min: float = minf(inner, outer)
	solid.append(_blade_frame(side, steps), Transform3D(Basis.IDENTITY, Vector3(x, y, -d)))
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


## The frame of a lounge's blade sign `steps` tenths of a metre tall on the wall on `side`, its bottom at the origin
## on the wall face at x = 0: brackets to the wall, the board's dark back and its two brass edges. Cached.
func _blade_frame(side: int, steps: int) -> MeshLayer:
	var key := Vector3i(12, side, steps)
	var found: MeshLayer = _templates.get(key)
	if found != null:
		return found
	var h: float = float(steps) * 0.1
	var mid: float = -side * (LOUNGE_BLADE_REACH + 0.3) * 0.5
	var seen: int = SEEN_FACES[side]
	var s := MeshLayer.new()
	for by: float in [h - 0.25, 0.25]:
		s.box(Vector3(-side * 0.075, by, 0.0), Vector3(0.18, 0.06, 0.06), csk.brass_dim_color, 0.0, MeshKit.PAT_CASINO_BRASS, seen, 0.4)
	s.box(Vector3(mid, h * 0.5, -0.05), Vector3(LOUNGE_BLADE_REACH, h, 0.08), csk.sign_panel_color, 0.0, MeshKit.PAT_PLAIN,
		seen & ~MeshKit.FACE_PZ)
	for ey: float in [h - 0.02, 0.02]:
		s.box(Vector3(mid, ey, -0.05), Vector3(LOUNGE_BLADE_REACH + 0.08, 0.08, 0.12), csk.brass_color, 0.0, MeshKit.PAT_CASINO_BRASS,
			seen, 0.5)
	_templates[key] = s
	return s


# --- Casinos -----------------------------------------------------------------------------------

## Casino dressing: a marquee of bulbs along a storey line and up the corners, a big lit sign (or the
## cult's feed) with a brass frame and halo, and a bulb marquee, everything flat on the face and above
## decor_min_height. A few casinos are the street's two famous ones (_name_of(): one in every
## name_spacing metres, alternating Gasket's House of Chance and The Brass Lotus; task K3, CasinoLettering):
## their name in real letters on the sign (Gasket's as a strip over it if it plays the feed; the Brass
## Lotus's feed sign has none) and on a tall blade sign at the far end of the building, where a runner
## sees it face-on from afar (GASKET'S, or THE BRASS LOTUS, stacked down it). The other casinos keep the
## sign's mark and rows of glyphs.
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


## The casino's big sign: a brass-edged frame, the face (a lit sign, or the cult's feed) and the halo; the
## cult's emblem in a corner. A sign that carries its name on its board has a dark, tube-edged panel for the
## letters (NAMED_PANEL, only when the letters exist: if the font couldn't be read it keeps its glyph rows).
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
		var param: float = float((b.seed % 100) + 100 * roundi(h * 10.0))
		for piece: Dictionary in names:
			if piece["kind"] == &"board":
				param += CasinoLettering.NAMED_PANEL
		solid.rect(screen[0], screen[1], screen[2], color, 0.6, MeshKit.PAT_CASINO_SIGN, Vector2.ZERO, Vector2(length, h), param)
		# The emblem's corner is kept clear of the letters on a named board (_name_specs()).
		if skin.carries_emblem(b.seed, 60):
			_corner_emblem(solid, side, sx, d0, length, sy, h)
	# The halo lies flat on the wall behind the frame and the face (under the arena's rule: nothing more than
	# 12 cm out of a face, where The House's billboard slides past the walls).
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

## Which name casino `b` carries (CasinoLettering NAME_*), or -1 if it is not one of the street's named
## casinos. DESIGN-TBD (docs/OPEN_QUESTIONS.md §D, item 525): the street is divided into periods of `name_spacing` metres
## (both walls together); each has at most one named casino, a casino with a big sign picked by hash (from
## the middle of the period if there is one), and the names alternate from period to period, so no name
## is nearer than a period to itself: two famous casinos, not a chain. A name_spacing of 0 names every
## casino with a big sign instead, by hash. A pure function of the street's layout, so every chunk agrees.
func _name_of(b: MarketFacades.Building) -> int:
	if b.kind != MarketFacades.Kind.CASINO or _casino_sign(b, 0.0).is_empty():
		return -1
	var spacing: float = csk.name_spacing
	if spacing <= 0.0:
		return CasinoLettering.pick(b.side, b.id)
	var period: int = floori((b.b0 + b.b1) * 0.5 / spacing)
	var landmark: Dictionary = _landmark(period)
	if landmark.is_empty() or int(landmark["side"]) != b.side or int(landmark["id"]) != b.id:
		return -1
	return posmod(period, 2)


## The named casino of period `period` ({side, id}, or {} if the period has no casino with a big sign): the
## lowest hash among those whose middle is in the period's middle half, or among all of them if none is.
func _landmark(period: int) -> Dictionary:
	var key := Vector2(float(period), csk.name_spacing)
	var found: Variant = _landmarks.get(key)
	if found != null:
		return found
	if _landmarks.size() > 256:
		_landmarks.clear()
	var spacing: float = csk.name_spacing
	var lo: float = float(period) * spacing
	var hi: float = lo + spacing
	var lot: float = skin.lot_length
	var best: Dictionary = {}
	var best_score: float = INF
	var fallback: Dictionary = {}
	var fallback_score: float = INF
	for side: int in [-1, 1]:
		var span: Vector2i = MeshKit.lot_run(side, floori(lo / lot), 0.45, 3, 3)
		while span.x * lot < hi:
			var b: MarketFacades.Building = building(side, span)
			var mid: float = (b.b0 + b.b1) * 0.5
			if mid >= lo and mid < hi and b.kind == MarketFacades.Kind.CASINO and not _casino_sign(b, 0.0).is_empty():
				var score: float = MeshKit.hash01(side, b.id, 72)
				if score < fallback_score:
					fallback_score = score
					fallback = {"side": side, "id": b.id}
				if mid >= lo + spacing * 0.25 and mid < lo + spacing * 0.75 and score < best_score:
					best_score = score
					best = {"side": side, "id": b.id}
			span = MeshKit.lot_run(side, span.y + 1, 0.45, 3, 3)
	var out: Dictionary = best if not best.is_empty() else fallback
	_landmarks[key] = out
	return out


## The emblem's room on casino `b`'s big sign (`spec`): how much of the board's end the cult's emblem takes
## (about 28% of the sign's height, with air round it), or 0 if the casino carries none or the sign is too
## small for it (the same test as MarketFacades._corner_emblem()).
func _emblem_room(b: MarketFacades.Building, spec: Dictionary) -> float:
	if not skin.carries_emblem(b.seed, 60):
		return 0.0
	var h: float = spec["h"]
	var e: float = maxf(h * 0.28, skin.emblem_min_size)
	if e > h * 0.36 or float(spec["length"]) < e * 4.0:
		return 0.0
	return e * EMBLEM_AIR


## The pieces of lettering of casino `b` (the building with a big sign `spec`): each {name (CasinoLettering
## NAME_*), kind (&"board": on the big sign, &"strip": over a sign that plays the feed, &"blade": a tall blade
## sign at the far end of the building), layout, at (the distance along the wall that decides which chunk
## builds it), d (the distance of the letters' centre), x (the plane of the letters, or for a blade the middle
## of its letters across it), y (their centre), scale (metres per cap height), box (their block, in metres),
## y_min, and for a strip or a blade its board's y0, height and length}. Empty for a casino that carries no
## name. By hash and the street's layout: the same every build. DESIGN-TBD (docs/OPEN_QUESTIONS.md §D, items 526, 527):
## the strip over a feed sign, the blade of every named casino and the names appearing on casinos' signs alone.
func _name_specs(b: MarketFacades.Building, face_x: float, spec: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var which: int = _name_of(b)
	if which < 0:
		return out
	var side: int = b.side
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
		# The cult's emblem keeps its corner (the viewer's lower right): the letters take the rest of the board.
		var emblem: float = _emblem_room(b, spec)
		var s: float = CasinoLettering.fit(layout, Vector2(length - 2.0 * BOARD_MARGIN.x - emblem, h - 2.0 * BOARD_MARGIN.y))
		if s > 0.0:
			var box: Vector2 = CasinoLettering.layout_size(layout) * s
			out.append({"name": which, "kind": &"board", "layout": layout, "at": mid, "d": mid + side * emblem * 0.5,
				"x": plane, "y": sy + h * 0.5, "scale": s, "box": box, "y_min": sy + h * 0.5 - box.y * 0.5,
				"emblem": emblem > 0.0})
	elif which == CasinoLettering.NAME_GASKETS:
		# A strip of one line over the screen, in its own brass frame.
		var layout: int = CasinoLettering.Layout.GASKETS_STRIP
		var s: float = CasinoLettering.fit(layout, Vector2(length - 2.0 * BOARD_MARGIN.x, 99.0))
		if s > 0.0:
			var box: Vector2 = CasinoLettering.layout_size(layout) * s
			var strip_h: float = box.y + 2.0 * STRIP_PAD
			var strip_y0: float = sy + h + FRAME + STRIP_GAP
			out.append({"name": which, "kind": &"strip", "layout": layout, "at": mid, "d": mid, "x": plane,
				"y": strip_y0 + strip_h * 0.5, "scale": s, "box": box, "y_min": strip_y0 + strip_h * 0.5 - box.y * 0.5,
				"board_y0": strip_y0, "board_h": strip_h, "board_length": length})
	# A blade sign (a tall sign sticking out of the wall, seen face-on from afar) at the building's far end: the
	# runner comes from its near end, so it never stands between the runner and the board. Not where the faces
	# are kept flush (the arena: nothing stands out of a wall there).
	if csk.flush_faces:
		return out
	var blade: int = CasinoLettering.Layout.LOTUS_BLADE
	if which == CasinoLettering.NAME_GASKETS:
		blade = CasinoLettering.Layout.GASKETS_BLADE
	var blade_size: Vector2 = CasinoLettering.layout_size(blade)
	var blade_y0: float = csk.overhang_min_height + 0.6
	# Under the entablature (the brass band and the cornice take the building's top metre).
	var room: float = b.height - ENTABLATURE - blade_y0 - 2.0 * BLADE_PAD
	var blade_s: float = minf(BLADE_LETTER, room / blade_size.y) if blade_size.y > 0.0 else 0.0
	if blade_s >= BLADE_LETTER_MIN:
		var box: Vector2 = blade_size * blade_s
		var board_h: float = box.y + 2.0 * BLADE_PAD
		var at: float = b.b1 - 1.0
		var letters_x: float = face_x - side * (BLADE_REACH * 0.5 + BLADE_SETBACK)
		out.append({"name": which, "kind": &"blade", "layout": blade, "at": at, "d": at, "x": letters_x, "y": blade_y0 + board_h * 0.5,
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
						entry["building"] = b.id
						entry["center"] = Vector3(float(piece["x"]), float(piece["y"]), -float(piece["d"]))
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
		_strip_board(solid, b, face_x, piece)
	elif kind == &"blade":
		_blade_board(solid, glow, b, face_x, piece)
		# The blade faces the approaching player (+z), its letters a little in front of the face.
		solid.append(letters, Transform3D(Basis.from_scale(Vector3(s, s, s)),
			Vector3(float(piece["x"]), float(piece["y"]), -float(piece["at"]) + BLADE_LETTER_LIFT)))
		return
	# On a wall: u to the viewer's right along the wall, v up, n out toward the street.
	var u := Vector3(0, 0, -1) if side < 0 else Vector3(0, 0, 1)
	var n := Vector3(-side, 0, 0)
	solid.append(letters, Transform3D(Basis(u * s, Vector3(0, s, 0), n * s), Vector3(float(piece["x"]), float(piece["y"]), -float(piece["d"]))))


## The coloured lettering template of a layout (CasinoLettering.layer()), built once per skin.
func _letters(layout: int) -> MeshLayer:
	var found: MeshLayer = _lettering.get(layout)
	if found == null:
		found = CasinoLettering.layer(layout, csk.lettering_color, csk.lettering_glow)
		_lettering[layout] = found
	return found


## The dark strip over a feed sign that carries Gasket's name: a brass-edged frame and a tube-lit face.
func _strip_board(solid: MeshLayer, b: MarketFacades.Building, face_x: float, piece: Dictionary) -> void:
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


## The board of a named casino's blade sign (the stacked letters are placed by the caller): a tall dark board
## standing out of the wall, in brass edges and a tube of light, facing the approaching player, under a metre
## out of the face (the arrival flyover's camera keeps a metre inside the walls) and above
## overhang_min_height.
func _blade_board(solid: MeshLayer, glow: MeshLayer, b: MarketFacades.Building, face_x: float, piece: Dictionary) -> void:
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
	# The face almost fills the board: its tube of light is inside the letters' width.
	var band: float = BLADE_REACH - 0.02
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

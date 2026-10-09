class_name MarketFacades
extends RefCounted
## Shopfronts and casinos for the Marketplace walls (MarketplaceSkin). A wall side is split into lots
## of `lot_length` metres (MeshKit.lot_run); a building covers 1–3 lots and is a row of shops, a
## casino or a market hall. Every building face is flush with the wall face from the market floor up
## past the wall-run band: that plane is the wall-run surface. Low on it, just above a tiled plinth,
## runs a row of shop windows: real openings with a display of goods behind them under a warm lamp,
## where the Marketplace citizens play (task D3, MarketCitizens: windows() lists them). Above them the band
## stays calm (shutters closed, no signs, no lights), and nothing but a hazard sign ever sticks out
## of the wall below `decor_min_height`. Higher up the market gets busy and plainly futuristic (GDD
## §5: the same future as every zone): lit and frosted smart-glass windows, blue awnings on slim
## cassettes, glass balconies, air-conditioning units, delivery-drone racks, cable trays, painted and
## neon blade signs, casino bulbs, big ad boards and the cult's feed on screens, and dishes and
## antenna masts against the sky: all unframed, so they never read as hazard signs (which wear the
## yellow/black frame).
## Nothing vent-like sits at the foot of the walls: in the Marketplace, wall vents are sewer-screech
## lairs (GDD §5, §9.5), drawn by the Screech itself.
## Windows and plaster come from shopfront.gdshader, so a face is a handful of quads. All variety
## comes from hashing lot indices, so chunk cuts never change a building.

enum Kind { SHOPS, CASINO, HALL }

## Facade styles (shopfront.gdshader).
const STYLE_UPPER: int = 0
const STYLE_CASINO: int = 1
const STYLE_HALL: int = 2
const STYLE_LOWER: int = 3
const STYLE_PIER: int = 4
const STYLE_INTERIOR: int = 5
const STYLE_REVEAL: int = 6
## Upper-floor window cells by the building's seed (mirrors shopfront.gdshader's cell_width()).
const CELL_WIDTHS: Array[float] = [2.6, 3.0, 2.2, 3.4]
const STOREY: float = 3.2
## How far buildings reach back from the street (their near ends show above lower neighbours).
const DEPTH: float = 22.0
const SETBACKS: Array[float] = [0.0, 0.0, 0.0, 3.0, 5.0]
const LOW_SHARE: float = 0.2
## Added to a PAT_SHOPSIGN parameter: lettering only, without the shop's own mark.
const LETTERING_ONLY: int = 10000
## Shop windows come in this many looks per width (interior colour and goods), picked by hash.
const WINDOW_VARIANTS: int = 6
## Cables across the street: one slot per this many metres (some slots stay empty).
const CABLE_SPACING: float = 11.0
## A shop-window TV (MarketplaceSkin.feed_window_share): its stand's height, its gap from the
## display's back wall and its bezel.
const TV_STAND: float = 0.34
const TV_BACK: float = 0.06
const TV_BEZEL: float = 0.07
## Interior wall colours of the shop displays (lit, never glowing).
const INTERIORS: Array[Color] = [Color(0.66, 0.6, 0.5), Color(0.5, 0.56, 0.58), Color(0.64, 0.55, 0.47),
	Color(0.58, 0.55, 0.6), Color(0.7, 0.67, 0.6)]


## One building's layout, computed from its lot run alone.
class Building:
	var side: int
	var id: int
	var b0: float
	var b1: float
	var kind: int
	var low: bool
	var height: float
	var base_top: float
	var setback: float
	var wall: Color
	var seed: int
	var lit: float
	## Shop windows along the low part of the face: (start, end) track distances.
	var windows: Array[Vector2] = []
	## The upper floors' window grid: cell width and the distance where the grid starts.
	var cell: float
	var grid_start: float


## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: MarketplaceSkin:
	get:
		return _skin.get_ref() as MarketplaceSkin
var _skin: WeakRef
var _buildings: Dictionary = {}
## Shop windows built once per (kind, width in cm, variant, side) and placed with one bulk append,
## and the same for the upper floors' awnings and balconies.
var _window_templates: Dictionary = {}
var _templates: Dictionary = {}


func _init(p_skin: MarketplaceSkin) -> void:
	_skin = weakref(p_skin)


## Adds the buildings of one wall side between two track distances.
func build(batch: MeshBatch, side: int, face_x: float, start: float, end: float) -> void:
	var solid: MeshLayer = batch.layer(skin.solid_material())
	var lot: float = skin.lot_length
	var span: Vector2i = MeshKit.lot_run(side, floori(start / lot), 0.45, 3, 3)
	while span.x * lot < end:
		var b: Building = building(side, span)
		_building(batch, b, face_x, start, end)
		span = MeshKit.lot_run(side, span.y + 1, 0.45, 3, 3)
	var mark_x: float = face_x - side * 0.02
	for h: float in skin.wall_height_marks:
		solid.box(Vector3(mark_x, h, -(start + end) * 0.5), Vector3(0.03, 0.05, end - start), skin.wall_mark_color)


## The building on `side` covering the lot run `span` (cached: every chunk asks for its neighbours).
func building(side: int, span: Vector2i) -> Building:
	var key := Vector3i(side, span.x, span.y)
	var found: Building = _buildings.get(key)
	if found != null:
		return found
	if _buildings.size() > 512:
		_buildings.clear()
	var b := Building.new()
	var id: int = span.x
	var lot: float = skin.lot_length
	b.side = side
	b.id = id
	b.b0 = span.x * lot
	b.b1 = (span.y + 1) * lot
	# Whole numbers: the facade shader rounds the seed before hashing it.
	b.seed = MeshKit.hash_i(side, id, 11) % 997
	var r: float = MeshKit.hash01(side, id, 1)
	b.kind = Kind.CASINO if r < skin.casino_share else (Kind.HALL if r < skin.casino_share + skin.hall_share else Kind.SHOPS)
	b.wall = skin.stucco_colors[MeshKit.hash_i(side, id, 9) % skin.stucco_colors.size()]
	b.lit = 0.25 + 0.35 * MeshKit.hash01(side, id, 8)
	b.base_top = 7.4 + 1.2 * MeshKit.hash01(side, id, 6)
	b.low = b.kind == Kind.SHOPS and MeshKit.hash01(side, id, 20) < LOW_SHARE
	var hr: float = pow(MeshKit.hash01(side, id, 2), 1.3)
	match b.kind:
		Kind.CASINO:
			b.height = lerpf(maxf(skin.building_min_height, 18.0), skin.building_max_height + 8.0, hr)
			b.setback = 0.0
		Kind.HALL:
			b.height = lerpf(maxf(skin.building_min_height, 15.0), maxf(skin.building_min_height, 15.0) + 5.0, hr)
			b.setback = 0.0
		_:
			b.height = lerpf(skin.building_min_height, skin.building_max_height, hr)
			b.setback = 0.0 if b.low else SETBACKS[MeshKit.hash_i(side, id, 3) % SETBACKS.size()]
			if b.low:
				b.height = b.base_top + 3.2
	# The shop windows: evenly spaced bays between piers, with wider piers at the building's ends.
	var bay: float = [3.3, 3.8, 4.2][b.kind] + 0.5 * MeshKit.hash01(side, id, 30)
	var pier: float = [0.62, 0.4, 0.9][b.kind]
	var end_pier: float = 0.85
	var usable: float = b.b1 - b.b0 - end_pier * 2.0 + pier
	var n: int = maxi(1, floori(usable / bay))
	var actual: float = usable / n
	for k: int in n:
		var w0: float = b.b0 + end_pier + k * actual
		b.windows.append(Vector2(w0, w0 + actual - pier))
	b.cell = 3.0 if b.kind == Kind.CASINO else (4.2 if b.kind == Kind.HALL else CELL_WIDTHS[b.seed % 4])
	var cells: int = maxi(1, floori((b.b1 - b.b0) / b.cell))
	b.grid_start = b.b0 + ((b.b1 - b.b0) - cells * b.cell) * 0.5
	_buildings[key] = b
	return b


## The billboards playing the cult's feed (MarketplaceSkin.feed_boards()) with middles in [start, end).
func feed_boards(side: int, face_x: float, start: float, end: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lot: float = skin.lot_length
	var span: Vector2i = MeshKit.lot_run(side, floori(start / lot), 0.45, 3, 3)
	while span.x * lot < end:
		var b: Building = building(side, span)
		var mid: float = (b.b0 + b.b1) * 0.5
		if mid >= start and mid < end:
			var spec: Dictionary = {}
			var kind: StringName = &""
			if b.kind == Kind.CASINO and skin.shows_feed(b.seed, 62):
				spec = _casino_sign(b, face_x)
				kind = &"casino"
			elif b.kind == Kind.SHOPS and b.low and skin.shows_feed(b.seed, 61):
				spec = _roof_board_spec(b, face_x)
				kind = &"roof_board"
			if not spec.is_empty():
				out.append({"side": side, "at": mid, "kind": kind, "width": spec["length"], "height": spec["h"],
					"center": Vector3(spec["x"], float(spec["y0"]) + float(spec["h"]) * 0.5, -mid)})
		span = MeshKit.lot_run(side, span.y + 1, 0.45, 3, 3)
	return out


## The shop windows (MarketplaceSkin.shop_windows()) whose centres lie in [start, end).
func windows(side: int, face_x: float, start: float, end: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lot: float = skin.lot_length
	var span: Vector2i = MeshKit.lot_run(side, floori(start / lot), 0.45, 3, 3)
	while span.x * lot < end:
		var b: Building = building(side, span)
		for w: Vector2 in b.windows:
			var at: float = (w.x + w.y) * 0.5
			if at >= start and at < end and not skin.wall_gap_near(side, w.x, w.y):
				out.append({"side": side, "at": at,
					"center": Vector3(face_x, (skin.gallery_bottom + skin.gallery_top) * 0.5, -at),
					"width": w.y - w.x, "bottom": skin.gallery_bottom, "top": skin.gallery_top, "depth": skin.shop_depth,
					"kind": [&"shop", &"casino", &"hall"][b.kind], "screen": _has_tv(b, w)})
		span = MeshKit.lot_run(side, span.y + 1, 0.45, 3, 3)
	return out


func _building(batch: MeshBatch, b: Building, face_x: float, start: float, end: float) -> void:
	var u0: float = maxf(b.b0, start)
	var u1: float = minf(b.b1, end)
	if u1 <= u0 + 0.001:
		return
	var facade: MeshLayer = batch.layer(skin.facade_material())
	var solid: MeshLayer = batch.layer(skin.solid_material())
	var glow: MeshLayer = batch.layer(skin.glow_material())
	var side: int = b.side
	var bottom: float = -skin.market_depth
	var g0: float = skin.gallery_bottom
	var g1: float = skin.gallery_top
	var upper_style: int = [STYLE_UPPER, STYLE_CASINO, STYLE_HALL][b.kind]

	# Below the stall roofs the face is in their deep shade (seen only through gaps, which must read
	# as holes); above them, the plinth.
	_panel(solid, side, face_x, u0, u1, bottom, 0.0, skin.gap_inside_color, 0.0, MeshKit.PAT_UNDER, 1.0)
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
	# The face above the windows: flush up to the base, or all the way up.
	var flush_top: float = b.base_top + 0.9 if b.setback > 0.0 else b.height
	_face(facade, side, face_x, u0, u1, g1, flush_top, b.wall, b.lit, upper_style, b.seed, b.grid_start)
	var top_x: float = face_x + side * b.setback
	if b.setback > 0.0:
		_face(facade, side, top_x, u0, u1, b.base_top, b.height, b.wall, b.lit, upper_style, b.seed, b.grid_start)
	# The near end, seen above lower neighbours and across setbacks.
	if b.b0 >= start and b.b0 < end:
		var x_min: float = minf(face_x, face_x + side * DEPTH)
		facade.quad_uv(Vector3(x_min, g1, -b.b0), Vector3(x_min, b.height, -b.b0), Vector3(x_min + DEPTH, b.height, -b.b0),
			Vector3(x_min + DEPTH, g1, -b.b0), Vector2(x_min, g1), Vector2(x_min, b.height), Vector2(x_min + DEPTH, b.height),
			Vector2(x_min + DEPTH, g1), b.wall, b.lit, upper_style, float(b.seed + 3))
	# A cornice along the base and a parapet cap along the top.
	var zc: float = -(u0 + u1) * 0.5
	solid.box(Vector3(face_x - side * 0.12, b.base_top, zc), Vector3(0.24, 0.26, u1 - u0), skin.trim_color, 0.0,
		MeshKit.PAT_STUCCO, MeshKit.ALL_FACES & ~MeshKit.FACE_PY)
	solid.box(Vector3(top_x - side * 0.08, b.height, zc), Vector3(0.16, 0.2, u1 - u0), skin.trim_color, 0.0,
		MeshKit.PAT_STUCCO, MeshKit.ALL_FACES & ~MeshKit.FACE_PY)

	match b.kind:
		Kind.CASINO:
			_casino(batch, solid, glow, b, face_x, u0, u1, start, end)
		Kind.HALL:
			_hall(solid, b, face_x, start, end)
		_:
			_shop_extras(batch, solid, glow, b, top_x, u0, u1, start, end)
	if b.low:
		_far_row(facade, b, face_x, start, end)


## Plain stucco between shop windows (from p0 to p1, clipped to [u0, u1]), from the plinth to the
## lintel. Its UV starts at p0 and its width rides in COLOR.a (/ 8 m), so the shader draws the
## windows' jambs along both its edges.
func _pier(facade: MeshLayer, side: int, face_x: float, p0: float, p1: float, u0: float, u1: float, b: Building) -> void:
	var a: float = maxf(p0, u0)
	var c: float = minf(p1, u1)
	if c > a + 0.001:
		_face(facade, side, face_x, a, c, skin.gallery_bottom, skin.gallery_top, b.wall, clampf((p1 - p0) / 8.0, 0.0, 1.0),
			STYLE_PIER, b.seed, p0)


## Shop window w (start and end distances) of building b: a cached template placed on the wall, and
## in some a TV playing the cult's feed (its screen is added here, facing the street the right way
## round on either wall; the template's mirror would flip the picture).
func _shop_window(batch: MeshBatch, b: Building, w: Vector2, face_x: float) -> void:
	var variant: int = MeshKit.hash_i(b.side, MeshKit.key(w.x), 41) % WINDOW_VARIANTS
	var tv: bool = _has_tv(b, w)
	batch.append(window_template(b.kind, w.y - w.x, variant, b.side, tv), Transform3D(Basis.IDENTITY,
		Vector3(face_x, 0.0, -w.x)))
	if tv:
		var size: Vector3 = _tv_size(w.y - w.x)
		# The TV's front, inside the building (the wall face is at face_x, the display runs back from it).
		var x: float = face_x + b.side * (skin.shop_depth - TV_BACK - size.x - 0.003)
		var at: float = (w.x + w.y) * 0.5
		var screen: Array = _wall_screen(b.side, x, at - size.z * 0.5 + TV_BEZEL, size.z - TV_BEZEL * 2.0,
			skin.gallery_bottom + TV_STAND + TV_BEZEL, size.y - TV_BEZEL * 2.0)
		CultFeed.screen(batch.layer(skin.feed_material()), screen[0], screen[1], screen[2], skin.feed_window_brightness,
			MeshKit.key(w.x))


## Whether shop window w of building b has a TV playing the cult's feed (feed_window_share of them).
func _has_tv(b: Building, w: Vector2) -> bool:
	return MeshKit.hash01(b.side, MeshKit.key(w.x), 43) < skin.feed_window_share


## A shop-window TV's size (depth, height, width) for a window `width` long: a boxy old CRT set.
static func _tv_size(width: float) -> Vector3:
	var tw: float = clampf(width * 0.36, 0.72, 1.05)
	return Vector3(0.36, tw * 0.78, tw)


## A shop window `width` long on the wall on `side` (face at x = 0, the window from z = 0 to
## -width): the display behind the opening (a back wall of goods, its floor, top and sides). The
## frame around it is painted by the facade shader on the piers, sill and lintel. Built for the left
## wall and mirrored once for the right.
func window_template(kind: int, width: float, variant: int, side: int, tv: bool) -> MeshBatch:
	var key := Vector4i(kind, roundi(width * 100.0), variant * 2 + (1 if tv else 0), side)
	var found: MeshBatch = _window_templates.get(key)
	if found != null:
		return found
	if _window_templates.size() > 512:
		_window_templates.clear()
	var t := MeshBatch.new()
	if side > 0:
		t.append(window_template(kind, width, variant, -1, tv), Transform3D(Basis.from_scale(Vector3(-1.0, 1.0, 1.0)),
			Vector3.ZERO))
		_window_templates[key] = t
		return t
	var facade: MeshLayer = t.layer(skin.facade_material())
	var g0: float = skin.gallery_bottom
	var g1: float = skin.gallery_top
	var h: float = g1 - g0
	var depth: float = skin.shop_depth
	var seed: int = variant * 131 + kind * 17 + 5
	var inside: Color = INTERIORS[variant % INTERIORS.size()]
	_face(facade, -1, -depth, 0.0, width, g0, g1, inside, 0.0, STYLE_INTERIOR, seed, 0.0)
	facade.rect(Vector3(-depth, g0, 0.0), Vector3(depth, 0, 0), Vector3(0, 0, -width), inside, 0.0, STYLE_REVEAL,
		Vector2(0.0, g0), Vector2(width, g0), float(seed))
	facade.rect(Vector3(-depth, g1, -width), Vector3(depth, 0, 0), Vector3(0, 0, width), inside, 0.0, STYLE_REVEAL,
		Vector2(0.0, g1), Vector2(width, g1), float(seed))
	# The far side faces the approaching player, the near one faces away.
	facade.rect(Vector3(-depth, g0, -width), Vector3(depth, 0, 0), Vector3(0, h, 0), inside, 0.0, STYLE_REVEAL,
		Vector2(0.0, g0), Vector2(depth, g1), float(seed))
	facade.rect(Vector3(0.0, g0, 0.0), Vector3(-depth, 0, 0), Vector3(0, h, 0), inside, 0.0, STYLE_REVEAL,
		Vector2(0.0, g0), Vector2(depth, g1), float(seed))
	if tv:
		# An old CRT set on a low stand at the back of the display, facing the street (its screen is
		# added per window, see _shop_window()).
		var solid: MeshLayer = t.layer(skin.solid_material())
		var size: Vector3 = _tv_size(width)
		var zc: float = -width * 0.5
		solid.box(Vector3(-depth + 0.28, g0 + TV_STAND * 0.5, zc), Vector3(0.5, TV_STAND, size.z + 0.16),
			Color(0.24, 0.21, 0.18), 0.0, MeshKit.PAT_PLAIN, MeshKit.ALL_FACES & ~MeshKit.FACE_NY)
		solid.box(Vector3(-depth + TV_BACK + size.x * 0.5, g0 + TV_STAND + size.y * 0.5, zc), size,
			Color(0.1, 0.1, 0.11), 0.0, MeshKit.PAT_PLAIN, MeshKit.ALL_FACES & ~MeshKit.FACE_NY)
	_window_templates[key] = t
	return t


## Shops' upper floors: blue awnings over some windows, a balcony or two, painted and neon blade
## signs, and on low buildings an ad board on the roof. Everything at or above decor_min_height.
func _shop_extras(batch: MeshBatch, solid: MeshLayer, glow: MeshLayer, b: Building, x: float, u0: float, u1: float,
		start: float, end: float) -> void:
	var side: int = b.side
	var top_storey: int = floori((b.height - 1.0 - skin.gallery_top - 0.2) / STOREY)
	var cells: int = floori((b.b1 - b.b0) / b.cell)
	for k: int in cells:
		var cx: float = b.grid_start + (float(k) + 0.5) * b.cell
		if cx < start or cx >= end:
			continue
		# One hash per column of windows, three bits of it per storey: 1 in 4 windows gets an awning,
		# 1 in 8 a balcony.
		var column: int = MeshKit.hash_i(b.seed, k, 5)
		for storey: int in range(1, top_storey + 1):
			var floor_y: float = skin.gallery_top + 0.2 + storey * STOREY
			if floor_y + 0.26 * STOREY < skin.decor_min_height - 0.5:
				continue
			var bits: int = (column >> ((storey * 3) % 30)) & 7
			if bits < 2:
				solid.append(_awning(side, (b.seed + k) % skin.awning_colors.size()),
					Transform3D(Basis.IDENTITY, Vector3(x, floor_y + 0.74 * STOREY, -cx)))
			elif bits == 2 and storey < top_storey:
				solid.append(_balcony(side, (b.seed + k) % 2), Transform3D(Basis.IDENTITY, Vector3(x, floor_y, -cx)))
			elif bits >= 6 and floor_y + 0.25 >= skin.decor_min_height:
				# An air-conditioning unit under the window, beside its middle.
				solid.append(_ac_unit(side), Transform3D(Basis.IDENTITY, Vector3(x, floor_y + 0.25,
					-(cx + (0.35 if bits == 6 else -0.35)))))
	# A rack of delivery drones between two windows on some shops.
	if MeshKit.hash01(side, b.id, 70) < 0.3 and cells > 1:
		var rd: float = b.grid_start + float(1 + MeshKit.hash_i(side, b.id, 71) % (cells - 1)) * b.cell
		var ry: float = skin.decor_min_height + 0.6
		if rd >= start and rd < end and ry + 1.6 < b.height:
			_drone_rack(solid, side, x, rd, ry)
	# A cable tray under the cornice, the building's wiring.
	var tray_y: float = b.base_top - 0.32
	if b.setback == 0.0 and tray_y > skin.decor_min_height - 1.0:
		solid.box(Vector3(x - side * 0.07, tray_y, -(u0 + u1) * 0.5), Vector3(0.1, 0.07, u1 - u0), Color(0.2, 0.2, 0.21))
	# Blade signs sticking out over the street, high up.
	var signs: int = MeshKit.hash_i(side, b.id, 50) % 3
	for i: int in signs:
		var d: float = lerpf(b.b0 + 2.0, b.b1 - 2.0, (float(i) + 0.3 + 0.4 * MeshKit.hash01(side, b.id, 51 + i)) / signs)
		if d < start or d >= end:
			continue
		var y: float = skin.decor_min_height + 0.5 + 2.5 * MeshKit.hash01(side, b.id, 55 + i)
		if y + 3.4 > b.height:
			continue
		_blade_sign(solid, glow, side, x, d, y, MeshKit.hash_i(side, b.id, 58 + i))
	if b.low:
		var mid: float = (b.b0 + b.b1) * 0.5
		if mid >= start and mid < end:
			_roof_board(batch, solid, b, x)
	elif MeshKit.hash01(side, b.id, 60) < 0.6:
		# A dish and an antenna mast on the roof, silhouettes against the sky.
		var tz: float = lerpf(b.b0 + 2.0, b.b1 - 2.0, MeshKit.hash01(side, b.id, 61))
		if tz >= start and tz < end:
			var tx: float = x + side * (1.2 + 2.5 * MeshKit.hash01(side, b.id, 62))
			solid.append(_roof_tech(side, MeshKit.hash_i(side, b.id, 63) % 3), Transform3D(Basis.IDENTITY,
				Vector3(tx, b.height, -tz)))


## A blue awning over an upper window (the window's top centre at the origin, on the wall on
## `side`): its striped canvas sloping out from the wall (both faces: from mid-street its top shows,
## from close by its underside) and its valance. Cached per side and colour.
func _awning(side: int, color_index: int) -> MeshLayer:
	var key := Vector3i(0, side, color_index)
	var found: MeshLayer = _templates.get(key)
	if found != null:
		return found
	var solid := MeshLayer.new()
	var color: Color = skin.awning_colors[color_index]
	var hw: float = 0.8
	var out: float = -side * 0.75
	var hem_y: float = -0.35
	# Corners at the wall and the hem, near (toward the player) and far.
	var wall_n := Vector3(0.0, 0.3, hw)
	var wall_f := Vector3(0.0, 0.3, -hw)
	var hem_n := Vector3(out, hem_y, hw)
	var hem_f := Vector3(out, hem_y, -hw)
	var under: Color = color * Color(0.78, 0.78, 0.78)
	# The slim cassette it rolls out of.
	solid.box(Vector3(-side * 0.08, 0.36, 0.0), Vector3(0.16, 0.14, hw * 2.0 + 0.1), skin.window_metal_color * Color(0.85, 0.85, 0.85))
	if side < 0:
		solid.quad(wall_n, hem_n, hem_f, wall_f, under, 0.0, MeshKit.PAT_CANVAS, 1.0)
		solid.quad(wall_f, hem_f, hem_n, wall_n, color, 0.0, MeshKit.PAT_CANVAS, 1.0)
		solid.rect(Vector3(out, hem_y - 0.25, hw), Vector3(0, 0, -hw * 2.0), Vector3(0, 0.25, 0), color, 0.0,
			MeshKit.PAT_CANVAS, Vector2.ZERO, Vector2.ONE, 1.0)
	else:
		solid.quad(wall_f, hem_f, hem_n, wall_n, under, 0.0, MeshKit.PAT_CANVAS, 1.0)
		solid.quad(wall_n, hem_n, hem_f, wall_f, color, 0.0, MeshKit.PAT_CANVAS, 1.0)
		solid.rect(Vector3(out, hem_y - 0.25, -hw), Vector3(0, 0, hw * 2.0), Vector3(0, 0.25, 0), color, 0.0,
			MeshKit.PAT_CANVAS, Vector2.ZERO, Vector2.ONE, 1.0)
	_templates[key] = solid
	return solid


## A small balcony under an upper window (its floor's centre on the wall at the origin, on `side`):
## a slab, a glass balustrade under a slim metal rail, and one or two potted plants. Cached per side
## and pot count.
func _balcony(side: int, pots: int) -> MeshLayer:
	var key := Vector3i(1, side, pots)
	var found: MeshLayer = _templates.get(key)
	if found != null:
		return found
	var solid := MeshLayer.new()
	var reach: float = 0.8
	var hw: float = 1.0
	var bx: float = -side * reach * 0.5
	solid.box(Vector3(bx, 0.05, 0.0), Vector3(reach, 0.14, hw * 2.0), skin.trim_color, 0.0, MeshKit.PAT_STUCCO)
	var rx: float = -side * (reach - 0.03)
	solid.box(Vector3(rx, 1.0, 0.0), Vector3(0.05, 0.05, hw * 2.0), skin.window_metal_color)
	_panel(solid, side, rx, -hw, hw, 0.12, 0.97, Color(0.16, 0.19, 0.22), 0.0, MeshKit.PAT_GLASS)
	for i: int in 1 + pots:
		var pz: float = (float(i) - 0.5) * 0.9
		solid.prism(Vector3(bx, 0.12, pz), 0.16, 0.3, 6, Color(0.6, 0.38, 0.28))
		solid.prism(Vector3(bx, 0.42, pz), 0.24, 0.32, 6, Color(0.3, 0.42, 0.24))
	_templates[key] = solid
	return solid


## An air-conditioning unit on the wall on `side` (its bottom centre at the origin): a casing on two
## brackets, its front a fan behind a round guard beside a bank of fins (MeshKit.PAT_TECH), and the
## dirty streak its drip leaves on the wall below. Cached per side.
func _ac_unit(side: int) -> MeshLayer:
	var key := Vector3i(2, side, 0)
	var found: MeshLayer = _templates.get(key)
	if found != null:
		return found
	var solid := MeshLayer.new()
	var w: float = 0.9
	var h: float = 0.6
	var d: float = 0.42
	var casing := Color(0.8, 0.8, 0.78)
	solid.box(Vector3(-side * d * 0.5, h * 0.5, 0.0), Vector3(d, h, w), casing, 0.0, MeshKit.PAT_PLAIN,
		MeshKit.ALL_FACES & ~(MeshKit.FACE_PX if side > 0 else MeshKit.FACE_NX))
	var fx: float = -side * (d + 0.002)
	var face: Array = _wall_screen(side, fx, -w * 0.5, w, 0.0, h)
	solid.rect(face[0], face[1], face[2], casing, 0.0, MeshKit.PAT_TECH, Vector2.ZERO, Vector2(w, h), 1.0)
	for bz: float in [-w * 0.35, w * 0.35]:
		solid.box(Vector3(-side * 0.25, -0.03, bz), Vector3(0.5, 0.05, 0.05), Color(0.25, 0.25, 0.26))
	var streak: Array = _wall_screen(side, -side * 0.004, -0.06, 0.05, -1.3, 1.25)
	solid.rect(streak[0], streak[1], streak[2], skin.grime_color, 0.0)
	_templates[key] = solid
	return solid


## A rack of delivery drones on the wall on `side` at distance d, bottom at y: a slim frame with three
## shelves, a drone docked on each (a body, four rotors) with a steady blue light (decorative blue,
## far from every hazard hue).
func _drone_rack(solid: MeshLayer, side: int, x: float, d: float, y: float) -> void:
	solid.append(_drone_rack_template(side), Transform3D(Basis.IDENTITY, Vector3(x, y, -d)))


func _drone_rack_template(side: int) -> MeshLayer:
	var key := Vector3i(3, side, 0)
	var found: MeshLayer = _templates.get(key)
	if found != null:
		return found
	var solid := MeshLayer.new()
	var metal: Color = skin.window_metal_color * Color(0.7, 0.7, 0.7)
	var reach: float = 0.6
	solid.box(Vector3(-side * 0.03, 0.8, 0.0), Vector3(0.06, 1.6, 0.9), metal, 0.0, MeshKit.PAT_TECH, MeshKit.ALL_FACES, 2.0)
	for i: int in 3:
		var sy: float = 0.1 + 0.5 * i
		solid.box(Vector3(-side * reach * 0.5, sy, 0.0), Vector3(reach, 0.04, 0.9), metal)
		var c := Vector3(-side * reach * 0.52, sy + 0.1, 0.0)
		solid.box(c, Vector3(0.3, 0.12, 0.3), Color(0.18, 0.19, 0.21))
		for r: Vector2 in [Vector2(-0.19, -0.19), Vector2(0.19, -0.19), Vector2(-0.19, 0.19), Vector2(0.19, 0.19)]:
			solid.box(c + Vector3(r.x, 0.075, r.y), Vector3(0.2, 0.015, 0.2), Color(0.3, 0.31, 0.33))
		solid.box(c + Vector3(-side * 0.151, 0.0, 0.0), Vector3(0.01, 0.03, 0.08), skin.engine_color, 0.9)
	_templates[key] = solid
	return solid


## Rooftop machinery (the roof at the origin, the face on `side` at x = 0 below it): a dish tilted
## to the sky and the street on a post, and an antenna mast with crossbars and a steady white light
## on top; `variant` 0 both, 1 a second dish, 2 a taller mast. Cached per side and variant.
func _roof_tech(side: int, variant: int) -> MeshLayer:
	var key := Vector3i(4, side, variant)
	var found: MeshLayer = _templates.get(key)
	if found != null:
		return found
	var solid := MeshLayer.new()
	var steel := Color(0.34, 0.35, 0.37)
	var dish := Color(0.82, 0.82, 0.8)
	var dishes: Array[Vector3] = [Vector3(0.0, 1.3, 0.0)]
	if variant == 1:
		dishes.append(Vector3(side * 1.4, 1.0, 1.6))
	for at: Vector3 in dishes:
		solid.box(Vector3(at.x, at.y * 0.5, at.z), Vector3(0.1, at.y, 0.1), steel)
		var tilt := Basis(Vector3(0, 0, 1), side * 0.85)
		solid.prism_xform(Transform3D(tilt.scaled_local(Vector3(0.62, 0.07, 0.62)), at), 12, dish)
		solid.box_xform(Transform3D(tilt.scaled_local(Vector3(0.04, 0.55, 0.04)), at + tilt * Vector3(0, 0.3, 0)), steel)
	var mh: float = 3.2 if variant != 2 else 5.0
	var mz: float = -1.8
	solid.box(Vector3(side * 0.6, mh * 0.5, mz), Vector3(0.08, mh, 0.08), steel)
	for i: int in 3:
		var cy: float = mh * (0.45 + 0.18 * i)
		solid.box(Vector3(side * 0.6, cy, mz), Vector3(0.05, 0.05, 0.9 - 0.2 * i), steel)
	solid.box(Vector3(side * 0.6, mh + 0.06, mz), Vector3(0.1, 0.1, 0.1), Color(0.92, 0.94, 1.0), 0.7)
	_templates[key] = solid
	return solid


## A decorative blade sign sticking out of the wall at distance d, bottom at y: a painted board or a
## neon one (never in a hazard hue), always unframed, facing the approaching player.
func _blade_sign(solid: MeshLayer, glow: MeshLayer, side: int, x: float, d: float, y: float, k: int) -> void:
	var h: float = 2.4 + 1.0 * MeshKit.hash01(k, 1)
	var reach: float = 1.25
	var inner: float = x - side * (reach + 0.15)
	var outer: float = x - side * 0.15
	var x_min: float = minf(inner, outer)
	var dark := Color(0.12, 0.11, 0.11)
	# Brackets to the wall, and the board's edge.
	for by: float in [y + h - 0.2, y + 0.2]:
		solid.box(Vector3((x + outer) * 0.5, by, -d), Vector3(0.18, 0.06, 0.06), dark)
	solid.box(Vector3((inner + outer) * 0.5, y + h * 0.5, -d - 0.05), Vector3(reach, h, 0.08), dark, 0.0,
		MeshKit.PAT_PLAIN, MeshKit.ALL_FACES & ~MeshKit.FACE_PZ)
	var neon: bool = (k >> 3) % 3 == 0
	if neon:
		var color: Color = skin.neon_colors[k % skin.neon_colors.size()]
		solid.rect(Vector3(x_min, y, -d + 0.001), Vector3(reach, 0, 0), Vector3(0, h, 0), color, 0.6, MeshKit.PAT_GLYPHS,
			Vector2.ZERO, Vector2(reach, h), 0.0)
		glow.rect(Vector3(x_min - 0.5, y - 0.5, -d + 0.2), Vector3(reach + 1.0, 0, 0), Vector3(0, h + 1.0, 0), color, 0.12,
			MeshKit.SHAPE_FLAT)
	else:
		var color: Color = skin.painted_sign_colors[k % skin.painted_sign_colors.size()]
		# A tall board reads top to bottom: lay the shop sign's rows along its height.
		solid.quad(Vector3(x_min, y, -d + 0.001), Vector3(x_min, y + h, -d + 0.001), Vector3(x_min + reach, y + h, -d + 0.001),
			Vector3(x_min + reach, y, -d + 0.001), color, 0.0, MeshKit.PAT_PLAIN)
		# Its lettering runs down the board (UV.x along u, from the top), a mark at the top: the shop's
		# own, or on some boards the cult's emblem in unlit bronze (GDD §5: hidden in plain sight).
		var band: float = minf(reach * 0.8, 0.9)
		var top: float = y + h - 0.15
		var code: int = (k % 100) + 100 * roundi(band * 10.0)
		if skin.carries_emblem(k, 58):
			var e: float = maxf(minf(reach * 0.78, 1.0), skin.emblem_min_size)
			skin.add_cult_emblem(solid, Vector3(x_min + reach * 0.5, top + 0.03 - e * 0.5, -d + 0.012), Vector3.BACK, e,
				false)
			top -= e + 0.1
			code += MarketFacades.LETTERING_ONLY
		if top - (y + 0.15) > 0.8:
			solid.rect(Vector3(x_min + (reach - band) * 0.5, top, -d + 0.004), Vector3(0, -(top - y - 0.15), 0),
				Vector3(band, 0, 0), color, 0.0, MeshKit.PAT_SHOPSIGN, Vector2.ZERO, Vector2(top - y - 0.15, band), float(code))


## A board of ads on a low building's roof (`x` its face), turned to the street: an ad
## (MeshKit.PAT_AD), some with the cult's emblem as a corner badge, or the cult's feed.
func _roof_board(batch: MeshBatch, solid: MeshLayer, b: Building, x: float) -> void:
	var spec: Dictionary = _roof_board_spec(b, x)
	if spec.is_empty():
		return
	var side: int = b.side
	var mid: float = (b.b0 + b.b1) * 0.5
	var h: float = spec["h"]
	var y0: float = spec["y0"]
	var length: float = spec["length"]
	var px: float = spec["x"]
	var d0: float = mid - length * 0.5
	var bx: float = px + side * 0.03
	var dark := Color(0.12, 0.11, 0.11)
	solid.box(Vector3(bx + side * 0.2, y0 + h * 0.5, -mid), Vector3(0.3, h + 0.4, length + 0.4), dark)
	for leg: float in [d0 + 1.0, d0 + length - 1.0]:
		solid.box(Vector3(bx + side * 0.2, b.height + 0.65, -leg), Vector3(0.2, 1.3, 0.2), dark)
	var screen: Array = _wall_screen(side, px, d0, length, y0, h)
	if skin.shows_feed(b.seed, 61):
		CultFeed.screen(batch.layer(skin.feed_material()), screen[0], screen[1], screen[2], skin.feed_board_brightness,
			b.seed)
		return
	var color: Color = skin.ad_colors[b.seed % skin.ad_colors.size()]
	solid.rect(screen[0], screen[1], screen[2], color, 0.5, MeshKit.PAT_AD, Vector2.ZERO, Vector2(length / h, 1.0),
		float(b.seed % 97))
	if skin.carries_emblem(b.seed, 59):
		_corner_emblem(solid, side, px, d0, length, y0, h)


## Where a low building's roof board goes (`x` the building's face): the screen's plane (x), bottom
## (y0), height (h) and length; empty if the building is too short for one.
func _roof_board_spec(b: Building, x: float) -> Dictionary:
	if b.b1 - b.b0 <= 10.0:
		return {}
	return {"x": x + b.side * 1.8 - b.side * 0.03, "y0": b.height + 1.3, "h": 4.0, "length": minf(b.b1 - b.b0 - 4.0, 12.0)}


## A screen in a wall-parallel plane at x facing the street, from distance d0 over `length`, from
## height y0 over h: [origin, u, v] for MeshLayer.rect() or CultFeed.screen(), u to the viewer's right.
static func _wall_screen(side: int, x: float, d0: float, length: float, y0: float, h: float) -> Array:
	if side < 0:
		return [Vector3(x, y0, -d0), Vector3(0, 0, -length), Vector3(0, h, 0)]
	return [Vector3(x, y0, -d0 - length), Vector3(0, 0, length), Vector3(0, h, 0)]


## Casino dressing: a marquee of bulbs along the base, bulb strips up the corners and a big sign
## near the top with its brand mark, some with the cult's emblem (all above decor_min_height).
func _casino(batch: MeshBatch, solid: MeshLayer, glow: MeshLayer, b: Building, face_x: float, u0: float, u1: float,
		start: float, end: float) -> void:
	var side: int = b.side
	var y0: float = maxf(b.base_top + 0.3, skin.decor_min_height)
	var mx: float = face_x - side * 0.03
	_panel(solid, side, mx, u0, u1, y0, y0 + 0.64, skin.bulb_color, 0.8, MeshKit.PAT_BULBS)
	for e: float in [b.b0 + 0.2, b.b1 - 0.55]:
		if e + 0.35 > start and e < end:
			_panel(solid, side, mx, maxf(e, u0), minf(e + 0.35, u1), y0 + 0.64, b.height - 0.3, skin.bulb_color, 0.8,
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
	solid.box(Vector3(face_x - side * 0.03, sy + h * 0.5, -mid), Vector3(0.06, h + 0.3, length + 0.3), Color(0.08, 0.07, 0.08))
	var screen: Array = _wall_screen(side, sx, d0, length, sy, h)
	var color: Color = skin.neon_colors[b.seed % skin.neon_colors.size()]
	if skin.shows_feed(b.seed, 62):
		CultFeed.screen(batch.layer(skin.feed_material()), screen[0], screen[1], screen[2], skin.feed_board_brightness,
			b.seed)
		color = CultFeed.FEED_COLOR
	else:
		solid.rect(screen[0], screen[1], screen[2], color, 0.55, MeshKit.PAT_AD, Vector2.ZERO, Vector2(length / h, 1.0),
			float(b.seed % 97))
		if skin.carries_emblem(b.seed, 60):
			_corner_emblem(solid, side, sx, d0, length, sy, h)
	glow.rect(Vector3(sx - side * 0.4, sy - 1.0, -d0 + 1.0), Vector3(0, 0, -(length + 2.0)), Vector3(0, h + 2.0, 0),
		color, 0.1, MeshKit.SHAPE_FLAT)


## Where a casino's big sign goes: the screen's plane (x), bottom (y0), height (h) and length near
## the top of its face; empty if the casino is too small for one.
func _casino_sign(b: Building, face_x: float) -> Dictionary:
	var y0: float = maxf(b.base_top + 0.3, skin.decor_min_height)
	var length: float = minf(b.b1 - b.b0 - 3.0, 14.0)
	var h: float = minf(4.5, b.height - y0 - 4.0)
	if length <= 5.0 or h <= 2.0:
		return {}
	return {"x": face_x - b.side * 0.075, "y0": b.height - h - 1.5, "h": h, "length": length}


## The cult's emblem as a small badge in the lower corner where an ad's text ends (the far end on
## the left wall, the near end on the right, as seen from the street), in its warm-white neon. Only
## on ads tall enough that it stays small beside the ad's own mark (GDD §5: never a centrepiece).
func _corner_emblem(solid: MeshLayer, side: int, x: float, d0: float, length: float, y0: float, h: float) -> void:
	var e: float = maxf(h * 0.28, skin.emblem_min_size)
	if e > h * 0.36 or length < e * 4.0:
		return
	var d: float = d0 + length - e * 0.75 if side < 0 else d0 + e * 0.75
	skin.add_cult_emblem(solid, Vector3(x - side * 0.012, y0 + e * 0.72, -d), Vector3(-side, 0.0, 0.0), e, true)


## A market hall: a painted name board over the middle, high up.
func _hall(solid: MeshLayer, b: Building, face_x: float, start: float, end: float) -> void:
	var mid: float = (b.b0 + b.b1) * 0.5
	if mid < start or mid >= end:
		return
	var length: float = minf(b.b1 - b.b0 - 4.0, 10.0)
	var h: float = 1.4
	var y: float = b.height - h - 0.8
	if length < 3.0 or y < skin.decor_min_height:
		return
	var color: Color = skin.painted_sign_colors[b.seed % skin.painted_sign_colors.size()]
	_panel(solid, b.side, face_x - b.side * 0.04, mid - length * 0.5, mid + length * 0.5, y, y + h, color, 0.0,
		MeshKit.PAT_SHOPSIGN, float((b.seed % 100) + 100 * roundi(h * 10.0)), true)


## Behind a low building: a far row of taller buildings, so the skyline has depth.
func _far_row(facade: MeshLayer, b: Building, face_x: float, start: float, end: float) -> void:
	var side: int = b.side
	var u0: float = maxf(b.b0 - 2.0, start)
	var u1: float = minf(b.b1 + 2.0, end)
	if u1 <= u0:
		return
	var x: float = face_x + side * (20.0 + 16.0 * MeshKit.hash01(side, b.id, 22))
	var h: float = 22.0 + 20.0 * MeshKit.hash01(side, b.id, 21)
	var wall: Color = skin.stucco_colors[MeshKit.hash_i(side, b.id, 23) % skin.stucco_colors.size()].darkened(0.12)
	_face(facade, side, x, u0, u1, b.base_top, h, wall, 0.3, STYLE_UPPER, b.seed + 11, 0.0)


# --- Helpers ------------------------------------------------------------------------------

## A facade piece (shopfront.gdshader) in the wall plane at x, facing the track, from distance u0 to
## u1 and height y0 to y1. UV is (distance - u_shift, height) in metres.
func _face(layer: MeshLayer, side: int, x: float, u0: float, u1: float, y0: float, y1: float, color: Color,
		lit: float, style: int, seed: int, u_shift: float) -> void:
	if u1 <= u0 + 0.0005 or y1 <= y0 + 0.0005:
		return
	var a: float = u0 - u_shift
	var c: float = u1 - u_shift
	if side < 0:
		layer.quad_uv(Vector3(x, y0, -u0), Vector3(x, y1, -u0), Vector3(x, y1, -u1), Vector3(x, y0, -u1),
			Vector2(a, y0), Vector2(a, y1), Vector2(c, y1), Vector2(c, y0), color, lit, style, float(seed))
	else:
		layer.quad_uv(Vector3(x, y0, -u1), Vector3(x, y1, -u1), Vector3(x, y1, -u0), Vector3(x, y0, -u0),
			Vector2(c, y0), Vector2(c, y1), Vector2(a, y1), Vector2(a, y0), color, lit, style, float(seed))


## A solid-kit panel in the wall plane at x, facing the track. `metres` gives it UV in metres read
## left to right from the lanes (for patterned content); otherwise UV runs 0-1.
func _panel(layer: MeshLayer, side: int, x: float, u0: float, u1: float, y0: float, y1: float, color: Color,
		glow_amount: float = 0.0, pattern: int = MeshKit.PAT_PLAIN, param: float = 0.0, metres: bool = true) -> void:
	if u1 <= u0 + 0.0005 or y1 <= y0 + 0.0005:
		return
	var w: float = u1 - u0
	var uv1 := Vector2(w, y1 - y0) if metres else Vector2.ONE
	if side < 0:
		layer.rect(Vector3(x, y0, -u0), Vector3(0, 0, -w), Vector3(0, y1 - y0, 0), color, glow_amount, pattern,
			Vector2.ZERO, uv1, param)
	else:
		layer.rect(Vector3(x, y0, -u1), Vector3(0, 0, w), Vector3(0, y1 - y0, 0), color, glow_amount, pattern,
			Vector2.ZERO, uv1, param)


## Strings of pennants and festoon lights across the street, high above the ceilings, and higher
## still, power and data cables slung from wall to wall, some with a junction box hanging off them;
## between two track distances. Built with the left wall; anchored where both buildings are tall
## enough.
func overhead(batch: MeshBatch, half_width: float, start: float, end: float) -> void:
	var solid: MeshLayer = batch.layer(skin.solid_material())
	var glow: MeshLayer = batch.layer(skin.glow_material())
	var c: int = ceili(start / CABLE_SPACING)
	while c * CABLE_SPACING < end:
		var cd: float = (float(c) + MeshKit.hash01(c, 80)) * CABLE_SPACING
		c += 1
		if cd < start or cd >= end or MeshKit.hash01(c, 81) > 0.6:
			continue
		var cy: float = 15.5 + 3.0 * MeshKit.hash01(c, 82)
		if _height_at(-1, cd) < cy + 0.5 or _height_at(1, cd) < cy + 0.5:
			continue
		_cable(solid, half_width + 0.3, cd, cy, 0.4 + 0.7 * MeshKit.hash01(c, 83), MeshKit.hash01(c, 84) < 0.35)
	var spacing: float = skin.bunting_spacing
	var k: int = ceili(start / spacing - 0.5)
	while (float(k) + 0.5) * spacing < end + spacing:
		var d: float = (float(k) + 0.2 + 0.6 * MeshKit.hash01(k, 5, 70)) * spacing
		k += 1
		if d < start or d >= end:
			continue
		var y: float = skin.bunting_height + 1.5 * MeshKit.hash01(k, 71)
		if _height_at(-1, d) < y + 0.5 or _height_at(1, d) < y + 0.5:
			continue
		var lights: bool = MeshKit.hash01(k, 72) < 0.4
		_string(solid, glow, half_width, d, y, 1.2 + 0.8 * MeshKit.hash01(k, 73), lights, k)


## A cable slung across the street at distance d from wall to wall (half_width either side), height
## y at the walls, sagging `sag` in the middle, with a junction box hanging off it or not.
func _cable(solid: MeshLayer, half_width: float, d: float, y: float, sag: float, box: bool) -> void:
	var z: float = -d
	var n: int = 10
	var cord := Color(0.12, 0.12, 0.13)
	var prev := Vector3(-half_width, y, z)
	for i: int in range(1, n + 1):
		var t: float = float(i) / n
		var p := Vector3(lerpf(-half_width, half_width, t), y - sag * 4.0 * t * (1.0 - t), z)
		solid.quad(prev + Vector3(0, -0.018, 0), prev + Vector3(0, 0.018, 0), p + Vector3(0, 0.018, 0), p + Vector3(0, -0.018, 0),
			cord)
		prev = p
	if box:
		var t: float = 0.3 + 0.4 * MeshKit.hash01(roundi(d), 85)
		var p := Vector3(lerpf(-half_width, half_width, t), y - sag * 4.0 * t * (1.0 - t), z)
		solid.box(p + Vector3(0, -0.22, 0), Vector3(0.3, 0.36, 0.22), Color(0.24, 0.25, 0.27), 0.0, MeshKit.PAT_TECH,
			MeshKit.ALL_FACES, 2.0)


## The top of the face at distance d on `side` (the setback tower's top counts: it's still anchored).
func _height_at(side: int, d: float) -> float:
	var lot: float = skin.lot_length
	var b: Building = building(side, MeshKit.lot_run(side, floori(d / lot), 0.45, 3, 3))
	return b.height if b.setback == 0.0 else b.base_top + 0.9


## One sagging string across the street at distance d: pennants hanging off it, or bulbs.
func _string(solid: MeshLayer, glow: MeshLayer, half_width: float, d: float, y: float, sag: float, lights: bool,
		seed: int) -> void:
	var z: float = -d
	var n: int = 12
	var cord := Color(0.18, 0.16, 0.15)
	var prev := Vector3(-half_width, y, z)
	for i: int in range(1, n + 1):
		var t: float = float(i) / n
		var p := Vector3(lerpf(-half_width, half_width, t), y - sag * 4.0 * t * (1.0 - t), z)
		solid.quad(prev + Vector3(0, -0.02, 0), prev + Vector3(0, 0.02, 0), p + Vector3(0, 0.02, 0), p + Vector3(0, -0.02, 0),
			cord)
		prev = p
	var count: int = roundi(half_width * 2.0 / 0.55)
	for i: int in range(1, count):
		var t: float = float(i) / count
		var p := Vector3(lerpf(-half_width, half_width, t), y - sag * 4.0 * t * (1.0 - t), z)
		if lights:
			solid.box(p + Vector3(0, -0.08, 0), Vector3(0.09, 0.12, 0.09), skin.lamp_color, 0.9)
			if i % 3 == 0:
				glow.rect(p + Vector3(-0.45, -0.53, 0.02), Vector3(0.9, 0, 0), Vector3(0, 0.9, 0), skin.lamp_color, 0.2,
					MeshKit.SHAPE_RADIAL)
		else:
			var color: Color = skin.pennant_colors[MeshKit.hash_i(seed, i, 74) % skin.pennant_colors.size()]
			solid.quad(p + Vector3(-0.2, 0.0, 0.01), p + Vector3(-0.2, 0.0, 0.01), p + Vector3(0.2, 0.0, 0.01),
				p + Vector3(0.0, -0.42, 0.01), color)

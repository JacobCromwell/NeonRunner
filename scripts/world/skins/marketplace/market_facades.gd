class_name MarketFacades
extends RefCounted
## Shopfronts and casinos for the Marketplace walls (MarketplaceSkin). A wall side is split into lots
## of `lot_length` metres (MeshKit.lot_run); a building covers 1–3 lots and is a row of shops, a
## casino or a market hall. Every building face is flush with the wall face from the market floor up
## past the wall-run band: that plane is the wall-run surface. Low on it, just above a tiled plinth,
## runs a row of shop windows: real openings with a display of goods behind them under a warm lamp,
## where the Marketplace citizens will play (task D3: windows() lists them). Above them the band
## stays calm (shutters closed, no signs, no lights), and nothing but a hazard sign ever sticks out
## of the wall below `decor_min_height`. Higher up the market gets busy: open and lit windows, blue
## awnings and balconies, painted and neon blade signs, casino bulbs and big ad boards on the roofs:
## all unframed, so they never read as hazard signs (which wear the yellow/black frame).
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


## The shop windows (MarketplaceSkin.shop_windows()) whose centres lie in [start, end).
func windows(side: int, face_x: float, start: float, end: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lot: float = skin.lot_length
	var span: Vector2i = MeshKit.lot_run(side, floori(start / lot), 0.45, 3, 3)
	while span.x * lot < end:
		var b: Building = building(side, span)
		for w: Vector2 in b.windows:
			var at: float = (w.x + w.y) * 0.5
			if at >= start and at < end:
				out.append({"side": side, "at": at,
					"center": Vector3(face_x, (skin.gallery_bottom + skin.gallery_top) * 0.5, -at),
					"width": w.y - w.x, "bottom": skin.gallery_bottom, "top": skin.gallery_top, "depth": skin.shop_depth,
					"kind": [&"shop", &"casino", &"hall"][b.kind]})
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

	# The low part: arcades far below, plaster, the tiled plinth.
	_face(facade, side, face_x, u0, u1, bottom, g0, b.wall, b.lit, STYLE_LOWER, b.seed, 0.0)
	# The shop windows and the piers between them. Piers are clipped to the chunk; a window belongs
	# whole to the chunk holding its centre, so the wall stays seamless across chunk cuts.
	var cursor: float = b.b0
	for w: Vector2 in b.windows:
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
			_casino(solid, glow, b, face_x, u0, u1, start, end)
		Kind.HALL:
			_hall(solid, b, face_x, start, end)
		_:
			_shop_extras(solid, glow, b, top_x, u0, u1, start, end)
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


## Shop window w (start and end distances) of building b: a cached template placed on the wall.
func _shop_window(batch: MeshBatch, b: Building, w: Vector2, face_x: float) -> void:
	var variant: int = MeshKit.hash_i(b.side, MeshKit.key(w.x), 41) % WINDOW_VARIANTS
	batch.append(_window_template(b.kind, w.y - w.x, variant, b.side), Transform3D(Basis.IDENTITY,
		Vector3(face_x, 0.0, -w.x)))


## A shop window `width` long on the wall on `side` (face at x = 0, the window from z = 0 to
## -width): the display behind the opening (a back wall of goods, its floor, top and sides). The
## frame around it is painted by the facade shader on the piers, sill and lintel. Built for the left
## wall and mirrored once for the right.
func _window_template(kind: int, width: float, variant: int, side: int) -> MeshBatch:
	var key := Vector4i(kind, roundi(width * 100.0), variant, side)
	var found: MeshBatch = _window_templates.get(key)
	if found != null:
		return found
	if _window_templates.size() > 512:
		_window_templates.clear()
	var t := MeshBatch.new()
	if side > 0:
		t.append(_window_template(kind, width, variant, -1), Transform3D(Basis.from_scale(Vector3(-1.0, 1.0, 1.0)),
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
	_window_templates[key] = t
	return t


## Shops' upper floors: blue awnings over some windows, a balcony or two, painted and neon blade
## signs, and on low buildings an ad board on the roof. Everything at or above decor_min_height.
func _shop_extras(solid: MeshLayer, glow: MeshLayer, b: Building, x: float, u0: float, u1: float, start: float,
		end: float) -> void:
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
		if mid >= start and mid < end and b.b1 - b.b0 > 10.0:
			_roof_board(solid, side, x, mid, b.height, minf(b.b1 - b.b0 - 4.0, 12.0), b.seed)
	elif MeshKit.hash01(side, b.id, 60) < 0.5:
		# A water tank on the roof, a silhouette against the sky.
		var tz: float = lerpf(b.b0 + 2.0, b.b1 - 2.0, MeshKit.hash01(side, b.id, 61))
		if tz >= start and tz < end:
			var tx: float = x + side * (3.0 + 4.0 * MeshKit.hash01(side, b.id, 62))
			solid.prism(Vector3(tx, b.height + 1.4, -tz), 1.1, 2.0, 8, Color(0.5, 0.48, 0.45), 0.0, MeshKit.PAT_TIN)
			for leg: float in [-0.7, 0.7]:
				solid.box(Vector3(tx + leg, b.height + 0.7, -tz), Vector3(0.12, 1.4, 0.12), Color(0.3, 0.28, 0.26))


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
## a slab, a balustrade (one panel, its balusters the grooves of the ribbed pattern) under a rail,
## and one or two potted plants. Cached per side and pot count.
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
	solid.box(Vector3(rx, 1.0, 0.0), Vector3(0.06, 0.06, hw * 2.0), skin.trim_color.darkened(0.1))
	_panel(solid, side, rx, -hw, hw, 0.12, 0.97, skin.trim_color.darkened(0.05), 0.0, MeshKit.PAT_RIBS)
	for i: int in 1 + pots:
		var pz: float = (float(i) - 0.5) * 0.9
		solid.prism(Vector3(bx, 0.12, pz), 0.16, 0.3, 6, Color(0.6, 0.38, 0.28))
		solid.prism(Vector3(bx, 0.42, pz), 0.24, 0.32, 6, Color(0.3, 0.42, 0.24))
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


## A board of ads on a low building's roof, turned to the street (MeshKit.PAT_AD), some with the
## cult's emblem as a corner badge.
func _roof_board(solid: MeshLayer, side: int, x: float, mid: float, roof_y: float, length: float, seed: int) -> void:
	var h: float = 4.0
	var y0: float = roof_y + 1.3
	var bx: float = x + side * 1.8
	var d0: float = mid - length * 0.5
	var dark := Color(0.12, 0.11, 0.11)
	solid.box(Vector3(bx + side * 0.2, y0 + h * 0.5, -mid), Vector3(0.3, h + 0.4, length + 0.4), dark)
	for leg: float in [d0 + 1.0, d0 + length - 1.0]:
		solid.box(Vector3(bx + side * 0.2, roof_y + 0.65, -leg), Vector3(0.2, 1.3, 0.2), dark)
	var color: Color = skin.ad_colors[seed % skin.ad_colors.size()]
	var px: float = bx - side * 0.03
	if side < 0:
		solid.rect(Vector3(px, y0, -d0), Vector3(0, 0, -length), Vector3(0, h, 0), color, 0.5, MeshKit.PAT_AD,
			Vector2.ZERO, Vector2(length / h, 1.0), float(seed % 97))
	else:
		solid.rect(Vector3(px, y0, -d0 - length), Vector3(0, 0, length), Vector3(0, h, 0), color, 0.5, MeshKit.PAT_AD,
			Vector2.ZERO, Vector2(length / h, 1.0), float(seed % 97))
	if skin.carries_emblem(seed, 59):
		_corner_emblem(solid, side, px, d0, length, y0, h)


## Casino dressing: a marquee of bulbs along the base, bulb strips up the corners and a big sign
## near the top with its brand mark, some with the cult's emblem (all above decor_min_height).
func _casino(solid: MeshLayer, glow: MeshLayer, b: Building, face_x: float, u0: float, u1: float, start: float,
		end: float) -> void:
	var side: int = b.side
	var y0: float = maxf(b.base_top + 0.3, skin.decor_min_height)
	var mx: float = face_x - side * 0.03
	_panel(solid, side, mx, u0, u1, y0, y0 + 0.64, skin.bulb_color, 0.8, MeshKit.PAT_BULBS)
	for e: float in [b.b0 + 0.2, b.b1 - 0.55]:
		if e + 0.35 > start and e < end:
			_panel(solid, side, mx, maxf(e, u0), minf(e + 0.35, u1), y0 + 0.64, b.height - 0.3, skin.bulb_color, 0.8,
				MeshKit.PAT_BULBS)
	var mid: float = (b.b0 + b.b1) * 0.5
	var length: float = minf(b.b1 - b.b0 - 3.0, 14.0)
	if mid >= start and mid < end and length > 5.0:
		var h: float = minf(4.5, b.height - y0 - 4.0)
		if h > 2.0:
			var sy: float = b.height - h - 1.5
			var color: Color = skin.neon_colors[b.seed % skin.neon_colors.size()]
			var d0: float = mid - length * 0.5
			var sx: float = face_x - side * 0.075
			solid.box(Vector3(face_x - side * 0.03, sy + h * 0.5, -mid), Vector3(0.06, h + 0.3, length + 0.3), Color(0.08, 0.07, 0.08))
			if side < 0:
				solid.rect(Vector3(sx, sy, -d0), Vector3(0, 0, -length), Vector3(0, h, 0), color, 0.55, MeshKit.PAT_AD,
					Vector2.ZERO, Vector2(length / h, 1.0), float(b.seed % 97))
			else:
				solid.rect(Vector3(sx, sy, -d0 - length), Vector3(0, 0, length), Vector3(0, h, 0), color, 0.55, MeshKit.PAT_AD,
					Vector2.ZERO, Vector2(length / h, 1.0), float(b.seed % 97))
			if skin.carries_emblem(b.seed, 60):
				_corner_emblem(solid, side, sx, d0, length, sy, h)
			glow.rect(Vector3(sx - side * 0.4, sy - 1.0, -d0 + 1.0), Vector3(0, 0, -(length + 2.0)), Vector3(0, h + 2.0, 0),
				color, 0.1, MeshKit.SHAPE_FLAT)


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


## Strings of pennants and festoon lights across the street, high above the ceilings, between two
## track distances. Built with the left wall; anchored where both buildings are tall enough.
func overhead(batch: MeshBatch, half_width: float, start: float, end: float) -> void:
	var solid: MeshLayer = batch.layer(skin.solid_material())
	var glow: MeshLayer = batch.layer(skin.glow_material())
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

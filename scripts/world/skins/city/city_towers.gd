class_name CityTowers
extends RefCounted
## Building facades for the city walls (CitySkin), plus the road far below the track.
## The street side of each wall is split into lots of `lot_length` metres; a building covers 1–3
## lots (a hash of the lot index decides where buildings start, and every third lot always starts
## one, so finding a building never looks back more than two lots). Every building has a podium,
## flush with the wall face from the street far below up past the wall-run band: that plane is
## the wall-run surface. Above it most buildings raise a tower, often stepped back or behind an
## alley; some stay low with a neon billboard on the roof and a far row of towers behind, so the
## city opens up overhead. Windows come from facade.gdshader, so a facade is a handful of quads.
## The cult (GDD §5): its feed (CultFeed) plays on some roof billboards instead of an ad and on a big
## screen high on some towers, and its emblem hides as a sponsor's badge on some roof billboards and a
## brand mark at the foot of some neon banners (MeshKit.PAT_CULT_MARK, warm-white neon). All of it
## sits far above the wall-run band, and building() finds it from track positions alone.

## How far buildings reach back from the street (their end faces show across alleys).
const DEPTH: float = 28.0
const SETBACKS: Array[float] = [0.0, 0.0, 4.0, 8.0, 12.0, 16.0]
## Share of buildings that stay low (podium only).
const LOW_SHARE: float = 0.22
## The towers' tall neon banners.
const BANNER_WIDTH: float = 2.4
const BANNER_HEIGHT: float = 12.0
## The low buildings' roof billboards.
const BOARD_HEIGHT: float = 5.0
const BOARD_MAX_LENGTH: float = 12.0
## A tower's big feed screen, hung out over the street facing the oncoming traffic: the gap between
## the wall and its inner edge (its arms span it), its casing's rim and depth, how far it keeps from
## the tower's ends and banner, and from the top of the tower.
const SCREEN_GAP: float = 0.5
const SCREEN_RIM: float = 0.15
const SCREEN_CASE: float = 0.4
const SCREEN_CLEAR: float = 2.0
const SCREEN_TOP_CLEAR: float = 3.0
## An emblem's clear square around its mark, as a multiple of the mark's size.
const EMBLEM_MARGIN: float = 1.25


## One building's layout, from its lot run alone (the same whichever chunk asks).
class Building:
	var side: int
	var id: int
	var b0: float
	var b1: float
	var low: bool
	var podium_top: float
	var height: float
	var setback: float
	var alley: float
	## The tower stands back from the street or behind an alley (or the building is low).
	var split: bool
	## Where the tower's own face starts along the track.
	var t0: float
	## The tall neon banner on the tower: its near end and bottom (banner_d < 0: none).
	var banner_d: float = -1.0
	var banner_y: float = 0.0


## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: CitySkin:
	get:
		return _skin.get_ref() as CitySkin
var _skin: WeakRef


func _init(p_skin: CitySkin) -> void:
	_skin = weakref(p_skin)


## Adds the facades of one wall side between two track distances.
func build(batch: MeshBatch, side: int, face_x: float, start: float, end: float) -> void:
	var facade: MeshLayer = batch.layer(skin.facade_material())
	var solid: MeshLayer = batch.layer(skin.solid_material())
	var glow: MeshLayer = batch.layer(skin.glow_material())
	var lot: float = skin.lot_length
	var span: Vector2i = building_at(side, floori(start / lot))
	while span.x * lot < end:
		_building(batch, facade, solid, glow, building(side, span), face_x, start, end)
		span = building_at(side, span.y + 1)
	var mark_x: float = face_x - side * 0.02
	for h: float in skin.wall_height_marks:
		solid.box(Vector3(mark_x, h, -(start + end) * 0.5), Vector3(0.03, 0.05, end - start), skin.wall_mark_color, 0.22)
	if side < 0:
		var w: float = absf(face_x)
		batch.layer(skin.road_material()).rect(Vector3(-w, -skin.road_depth, -start), Vector3(w * 2.0, 0, 0),
			Vector3(0, 0, -(end - start)), skin.road_color)


## The first and last lot of the building covering `lot_index` on this side.
func building_at(side: int, lot_index: int) -> Vector2i:
	return MeshKit.lot_run(side, lot_index, 0.45)


## The layout of the building covering lots span.x to span.y on this side.
func building(side: int, span: Vector2i) -> Building:
	var lot: float = skin.lot_length
	var b := Building.new()
	b.side = side
	b.id = span.x
	b.b0 = span.x * lot
	b.b1 = (span.y + 1) * lot
	var id: int = b.id
	b.low = MeshKit.hash01(side, id, 20) < LOW_SHARE
	b.podium_top = 7.5 + 5.0 * MeshKit.hash01(side, id, 6)
	b.height = lerpf(skin.building_min_height, skin.building_max_height, pow(MeshKit.hash01(side, id, 2), 1.4))
	b.setback = SETBACKS[MeshKit.hash_i(side, id, 3) % SETBACKS.size()]
	b.alley = 0.0 if MeshKit.hash01(side, id, 4) < 0.4 else 2.0 + 5.0 * MeshKit.hash01(side, id, 5)
	b.split = b.low or b.setback > 0.0 or b.alley > 0.0
	b.t0 = b.b0 + b.alley
	if not b.low:
		var banner_d: float = b.t0 + 2.0 + 4.0 * MeshKit.hash01(side, id, 14)
		b.banner_y = b.podium_top + 2.0
		if MeshKit.hash01(side, id, 15) < 0.6 and banner_d + BANNER_WIDTH < b.b1 and b.height > b.banner_y + 14.0:
			b.banner_d = banner_d
	return b


func _building(batch: MeshBatch, facade: MeshLayer, solid: MeshLayer, glow: MeshLayer, b: Building, face_x: float,
		start: float, end: float) -> void:
	var u0: float = maxf(b.b0, start)
	var u1: float = minf(b.b1, end)
	if u1 <= u0:
		return
	var side: int = b.side
	var id: int = b.id
	var style: int = MeshKit.hash_i(side, id, 7) % 4
	var lit: float = 0.3 + 0.4 * MeshKit.hash01(side, id, 8)
	var wall: Color = _pick(skin.facade_colors, side, id, 9)
	var accent: Color = _pick(skin.neon_colors, side, id, 10)
	# Whole numbers: the facade shader rounds the seed before hashing it.
	var seed: float = float(MeshKit.hash_i(side, id, 11) % 997)
	var road_y: float = -skin.road_depth
	var height: float = b.height
	var podium_top: float = b.podium_top
	var zc: float = -(u0 + u1) * 0.5

	# Podium, flush with the wall face; shop signs glowing deep below; a neon line along its top.
	_facade(facade, side, face_x, u0, u1, road_y, podium_top if b.split else height, wall, lit, style, seed)
	if u1 - u0 > 1.5:
		solid.box(Vector3(face_x - side * 0.04, road_y + 3.2, zc), Vector3(0.05, 0.35, u1 - u0 - 1.0), accent, 0.35)
	solid.box(Vector3(face_x - side * 0.03, podium_top - 0.1, zc), Vector3(0.06, 0.12, u1 - u0), accent, 0.45)

	if b.low:
		_low_building(batch, facade, solid, glow, b, face_x, start, end, seed)
		return

	var tower_x: float = face_x + side * b.setback
	var t0: float = b.t0
	var b1: float = b.b1
	var base_y: float = podium_top if b.split else road_y
	if b.split and u1 > maxf(t0, start):
		_facade(facade, side, tower_x, maxf(t0, start), u1, podium_top, height, wall, lit, style, seed)
	# The tower's near side, seen across alleys, setbacks and lower neighbours.
	if t0 >= start and t0 < end:
		var x_min: float = minf(tower_x, tower_x + side * DEPTH)
		facade.rect(Vector3(x_min, base_y, -t0), Vector3(DEPTH, 0, 0), Vector3(0, height - base_y, 0),
			wall, lit, style, Vector2(x_min, base_y), Vector2(x_min + DEPTH, height), seed + 3.0)

	# Neon on the tower: corner strips, bands up the height, a crown.
	var c0: float = maxf(t0, start)
	var strip_y: float = podium_top if b.split else 0.0
	if MeshKit.hash01(side, id, 12) < 0.75:
		for edge: float in [t0, b1 - 0.2]:
			if edge >= start and edge < end:
				solid.box(Vector3(tower_x - side * 0.05, (strip_y + height) * 0.5, -edge - 0.1),
					Vector3(0.1, height - strip_y, 0.2), accent, 0.6)
	if u1 > c0:
		var tz: float = -(c0 + u1) * 0.5
		if MeshKit.hash01(side, id, 13) < 0.7:
			solid.box(Vector3(tower_x - side * 0.04, height - 0.25, tz), Vector3(0.08, 0.16, u1 - c0), accent, 0.55)
		if MeshKit.hash01(side, id, 18) < 0.5:
			var step: float = 14.0 + 12.0 * MeshKit.hash01(side, id, 19)
			var band: float = podium_top + step
			while band < height - 6.0:
				solid.box(Vector3(tower_x - side * 0.04, band, tz), Vector3(0.06, 0.1, u1 - c0), accent, 0.4)
				band += step

	# A tall decorative neon banner on many towers, above the play space. Flush and unframed,
	# so it never reads as a hazard sign.
	if b.banner_d >= start and b.banner_d < end:
		_banner(solid, glow, b, tower_x, accent)

	# A big screen hung out from some towers over the street, playing the cult's feed.
	var screen: Dictionary = feed_screen(b, face_x)
	if not screen.is_empty() and float(screen["at"]) >= start and float(screen["at"]) < end:
		_feed_screen(batch, solid, b, face_x, screen)

	# Antenna with a red aircraft beacon.
	var mid: float = (t0 + b1) * 0.5
	if MeshKit.hash01(side, id, 16) < 0.45 and mid >= start and mid < end:
		var ax: float = tower_x + side * 6.0
		var ah: float = 6.0 + 10.0 * MeshKit.hash01(side, id, 17)
		solid.box(Vector3(ax, height + ah * 0.5, -mid), Vector3(0.25, ah, 0.25), Color(0.08, 0.08, 0.1))
		solid.box(Vector3(ax, height + ah + 0.2, -mid), Vector3(0.4, 0.4, 0.4), skin.beacon_color, 1.0)
		glow.rect(Vector3(ax - 2.0, height + ah - 1.8, -mid), Vector3(4.0, 0, 0), Vector3(0, 4.0, 0), skin.beacon_color,
			0.45, MeshKit.SHAPE_RADIAL)


## A low building: a neon billboard on the roof (some playing the cult's feed, some ads with the
## cult's emblem as a sponsor's badge) and a far row of towers behind it.
func _low_building(batch: MeshBatch, facade: MeshLayer, solid: MeshLayer, glow: MeshLayer, b: Building,
		face_x: float, start: float, end: float, seed: float) -> void:
	var side: int = b.side
	var id: int = b.id
	var u0: float = maxf(b.b0 - 2.0, start)
	var u1: float = minf(b.b1 + 2.0, end)
	var far_x: float = face_x + side * (24.0 + 22.0 * MeshKit.hash01(side, id, 21))
	var far_h: float = lerpf(60.0, skin.building_max_height + 30.0, MeshKit.hash01(side, id, 22))
	_facade(facade, side, far_x, u0, u1, b.podium_top - 1.0, far_h, _pick(skin.facade_colors, side, id, 23), 0.45,
		MeshKit.hash_i(side, id, 24) % 4, seed + 11.0)
	var board: Dictionary = roof_board(b, face_x)
	if board.is_empty():
		return
	var len: float = board["length"]
	var d0: float = board["d0"]
	if d0 < start or d0 >= end:
		return
	var color: Color = _pick(skin.neon_colors, side, id, 25).lightened(0.15)
	var px: float = board["x"]
	var bx: float = px + side * 0.03
	var y0: float = board["y0"]
	var h: float = BOARD_HEIGHT
	var dark := Color(0.05, 0.05, 0.07)
	solid.box(Vector3(bx + side * 0.2, y0 + h * 0.5, -d0 - len * 0.5), Vector3(0.3, h + 0.4, len + 0.4), dark)
	for leg: float in [d0 + 1.0, d0 + len - 1.0]:
		solid.box(Vector3(bx + side * 0.2, b.podium_top + 0.7, -leg), Vector3(0.2, 1.4, 0.2), dark)
	if board["feed"]:
		# The cult's feed instead of an ad: the same broadcast as on every screen (CultFeed), with no
		# glow over it (it would wash the picture out).
		CultFeed.wall_screen(batch.layer(skin.feed_material()), side, px, d0, len, y0, h, skin.feed_board_brightness, id)
		return
	var e: float = board["emblem"]
	if e > 0.0:
		# The glyphs leave a clear square in the corner where they end, for the sponsor's badge.
		var m: float = e * EMBLEM_MARGIN
		_panel(solid, side, px, d0, len, y0, 0.0, len - m, 0.0, h, color, 0.65, MeshKit.PAT_GLYPHS, 1.5)
		_panel(solid, side, px, d0, len, y0, len - m, len, m, h, color, 0.65, MeshKit.PAT_GLYPHS, 1.5)
		_emblem(solid, side, px, d0, len, y0, len - m, len, 0.0, m, e)
	else:
		_panel(solid, side, px, d0, len, y0, 0.0, len, 0.0, h, color, 0.65, MeshKit.PAT_GLYPHS, 1.5)
	glow.rect(Vector3(px - side * 0.4, y0 - 1.5, -d0 + 1.5), Vector3(0, 0, -(len + 3.0)), Vector3(0, h + 3.0, 0), color,
		0.14, MeshKit.SHAPE_FLAT)


## A low building's roof billboard: its near end d0, length, the plane of its face (x), bottom (y0),
## whether it plays the cult's feed (`feed`) and, if it is an ad with the cult's emblem, the emblem's
## size (`emblem`, 0 if none). Empty if the building has none.
func roof_board(b: Building, face_x: float) -> Dictionary:
	if not b.low:
		return {}
	var len: float = minf(b.b1 - b.b0 - 4.0, BOARD_MAX_LENGTH)
	if len < 4.0:
		return {}
	var feed: bool = skin.shows_feed(b.side, b.id, skin.feed_share)
	var e: float = 0.0
	if not feed and skin.carries_emblem(b.side, b.id):
		# A badge small beside the ad's own glyphs (GDD §5: never a centrepiece).
		e = maxf(BOARD_HEIGHT * 0.28, skin.emblem_min_size)
		if e > BOARD_HEIGHT * 0.36 or len < e * EMBLEM_MARGIN * 3.0:
			e = 0.0
	return {"d0": (b.b0 + b.b1 - len) * 0.5, "length": len, "x": face_x + b.side * (1.6 - 0.03),
		"y0": b.podium_top + 1.4, "feed": feed, "emblem": e}


## The big screen hung out from a tower playing the cult's feed: flush towers only (it hangs off the
## street face), clear of the tower's ends and its banner, high above the play space and the ships,
## facing the oncoming traffic so it reads from far down the street (anything flat on the facades is
## seen almost edge-on). Its middle's distance (at), bottom (y0), width, height, and inner and outer
## edges (x_in at the wall end, x_out over the street). Empty if the tower has none.
func feed_screen(b: Building, face_x: float) -> Dictionary:
	if b.low or b.setback > 0.0 or not skin.shows_feed(b.side, b.id, skin.feed_tower_share):
		return {}
	var w: float = minf(skin.feed_screen_width, absf(face_x) * skin.feed_screen_reach)
	var h: float = w * 9.0 / 16.0
	var lo: float = b.t0 + SCREEN_CLEAR
	var hi: float = b.b1 - SCREEN_CLEAR
	var at: float = lerpf(lo, hi, MeshKit.hash01(b.side, b.id, 142))
	if b.banner_d >= 0.0 and at > b.banner_d - SCREEN_CLEAR and at < b.banner_d + BANNER_WIDTH + SCREEN_CLEAR:
		# Past the banner, where there's room.
		at = b.banner_d + BANNER_WIDTH + SCREEN_CLEAR
	if hi < lo or at > hi:
		return {}
	var y0: float = skin.feed_screen_bottom + 4.0 * MeshKit.hash01(b.side, b.id, 141)
	if y0 + h + SCREEN_TOP_CLEAR > b.height:
		return {}
	var x_in: float = face_x - b.side * SCREEN_GAP
	return {"at": at, "y0": y0, "width": w, "height": h, "x_in": x_in, "x_out": x_in - b.side * w}


## The screens playing the feed (CitySkin.feed_boards()) with middles in [start, end).
func feed_boards(side: int, face_x: float, start: float, end: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lot: float = skin.lot_length
	var span: Vector2i = building_at(side, floori(start / lot))
	while span.x * lot < end:
		var b: Building = building(side, span)
		var board: Dictionary = roof_board(b, face_x)
		if not board.is_empty() and board["feed"]:
			var at: float = float(board["d0"]) + float(board["length"]) * 0.5
			if at >= start and at < end:
				out.append({"side": side, "at": at, "kind": &"roof_board", "width": board["length"], "height": BOARD_HEIGHT,
					"center": Vector3(board["x"], float(board["y0"]) + BOARD_HEIGHT * 0.5, -at)})
		var screen: Dictionary = feed_screen(b, face_x)
		if not screen.is_empty() and float(screen["at"]) >= start and float(screen["at"]) < end:
			out.append({"side": side, "at": screen["at"], "kind": &"tower_screen", "width": screen["width"],
				"height": screen["height"], "center": Vector3((float(screen["x_in"]) + float(screen["x_out"])) * 0.5,
				float(screen["y0"]) + float(screen["height"]) * 0.5, -float(screen["at"]))})
		span = building_at(side, span.y + 1)
	return out


## The cult's emblems (CitySkin.cult_emblems()) with middles in [start, end).
func emblems(side: int, face_x: float, start: float, end: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lot: float = skin.lot_length
	var span: Vector2i = building_at(side, floori(start / lot))
	while span.x * lot < end:
		var b: Building = building(side, span)
		var board: Dictionary = roof_board(b, face_x)
		if not board.is_empty() and float(board["emblem"]) > 0.0:
			var e: float = board["emblem"]
			var m: float = e * EMBLEM_MARGIN
			var len: float = board["length"]
			# The corner where the ad's glyphs end: the far end on the left wall, the near end on the right.
			var at: float = float(board["d0"]) + (len - m * 0.5 if side < 0 else m * 0.5)
			out.append({"side": side, "at": at, "kind": &"roof_board", "size": e,
				"center": Vector3(board["x"], float(board["y0"]) + m * 0.5, -at)})
		var foot: float = banner_emblem(b)
		if foot > 0.0:
			var at: float = b.banner_d + BANNER_WIDTH * 0.5
			out.append({"side": side, "at": at, "kind": &"banner", "size": foot, "center": Vector3(
				face_x + side * (b.setback - 0.1), b.banner_y + foot * EMBLEM_MARGIN * 0.5, -at)})
		span = building_at(side, span.y + 1)
	var kept: Array[Dictionary] = []
	for e: Dictionary in out:
		if float(e["at"]) >= start and float(e["at"]) < end:
			kept.append(e)
	return kept


## The size of the cult's emblem at the foot of the tower's neon banner (0 if it has none).
func banner_emblem(b: Building) -> float:
	if b.banner_d < 0.0 or not skin.carries_emblem(b.side, b.id):
		return 0.0
	return clampf(BANNER_WIDTH * 0.6, skin.emblem_min_size, 1.6)


## A facade quad on the wall plane at x, facing the track, from distance u0 to u1 and height y0 to y1.
func _facade(facade: MeshLayer, side: int, x: float, u0: float, u1: float, y0: float, y1: float,
		wall: Color, lit: float, style: int, seed: float) -> void:
	MeshKit.facade_quad(facade, side, x, u0, u1, y0, y1, y1, wall, lit, style, seed)


## The tower's tall neon banner, some with the cult's emblem at its foot as the brand's mark.
func _banner(solid: MeshLayer, glow: MeshLayer, b: Building, x: float, color: Color) -> void:
	var side: int = b.side
	var d: float = b.banner_d
	var y: float = b.banner_y
	var w: float = BANNER_WIDTH
	var h: float = BANNER_HEIGHT
	var px: float = x - side * 0.1
	solid.box(Vector3(x - side * 0.05, y + h * 0.5, -d - w * 0.5), Vector3(0.1, h + 0.3, w + 0.3), Color(0.04, 0.04, 0.06))
	# The glyphs start above the emblem's clear square, if it has one.
	var e: float = banner_emblem(b)
	var foot: float = minf(e * EMBLEM_MARGIN, w) if e > 0.0 else 0.0
	if side < 0:
		solid.rect(Vector3(px, y + foot, -d), Vector3(0, 0, -w), Vector3(0, h - foot, 0), color, 0.6, MeshKit.PAT_GLYPHS,
			Vector2(0, foot), Vector2(w, h), 0.0)
	else:
		solid.rect(Vector3(px, y + foot, -d - w), Vector3(0, 0, w), Vector3(0, h - foot, 0), color, 0.6, MeshKit.PAT_GLYPHS,
			Vector2(w, foot), Vector2(0, h), 0.0)
	if e > 0.0:
		_emblem(solid, side, px, d, w, y, 0.0, w, 0.0, foot, e)
	glow.rect(Vector3(px - side * 0.3, y - 1.0, -d + 1.0), Vector3(0, 0, -(w + 2.0)), Vector3(0, h + 2.0, 0), color,
		0.12, MeshKit.SHAPE_FLAT)


## A tower's big screen playing the cult's feed, hung out over the street on two arms: a dark casing
## with the screen on its front, facing the oncoming traffic (+z).
func _feed_screen(batch: MeshBatch, solid: MeshLayer, b: Building, face_x: float, screen: Dictionary) -> void:
	var at: float = screen["at"]
	var w: float = screen["width"]
	var h: float = screen["height"]
	var y0: float = screen["y0"]
	var x_in: float = screen["x_in"]
	var x0: float = minf(x_in, screen["x_out"])
	solid.box(Vector3(x0 + w * 0.5, y0 + h * 0.5, -at - SCREEN_CASE * 0.5 - 0.03),
		Vector3(w + SCREEN_RIM * 2.0, h + SCREEN_RIM * 2.0, SCREEN_CASE), Color(0.03, 0.03, 0.04))
	for y: float in [y0 + 0.25, y0 + h - 0.25]:
		solid.box(Vector3((face_x + x_in) * 0.5, y, -at - SCREEN_CASE * 0.5), Vector3(SCREEN_GAP + 0.2, 0.1, 0.1),
			Color(0.06, 0.06, 0.08))
	CultFeed.screen(batch.layer(skin.feed_material()), Vector3(x0, y0, -at), Vector3(w, 0, 0), Vector3(0, h, 0),
		skin.feed_screen_brightness, b.id * 2 + (1 if b.side > 0 else 0))


## A panel on a board facing the street (its face in the plane at x, the board from distance d0
## over `length` and up from y0): the part from ua to ub along its reading direction (left to right
## as seen from the street) and from va to vb up it, with UV in metres in that frame.
func _panel(layer: MeshLayer, side: int, x: float, d0: float, length: float, y0: float, ua: float, ub: float,
		va: float, vb: float, color: Color, glow: float, pattern: int, param: float) -> void:
	_board_rect(layer, side, x, d0, length, y0, ua, ub, va, vb, color, glow, pattern, param, Vector2(ua, va),
		Vector2(ub, vb))


## The same part of a board as _panel(), with UV running from uv0 (its lower left, as seen from the
## street) to uv1.
func _board_rect(layer: MeshLayer, side: int, x: float, d0: float, length: float, y0: float, ua: float, ub: float,
		va: float, vb: float, color: Color, glow: float, pattern: int, param: float, uv0: Vector2, uv1: Vector2) -> void:
	if side < 0:
		layer.rect(Vector3(x, y0 + va, -(d0 + ua)), Vector3(0, 0, -(ub - ua)), Vector3(0, vb - va, 0), color, glow, pattern,
			uv0, uv1, param)
	else:
		layer.rect(Vector3(x, y0 + va, -(d0 + length - ua)), Vector3(0, 0, ub - ua), Vector3(0, vb - va, 0), color, glow,
			pattern, uv0, uv1, param)


## The cult's emblem `e` metres across, centred in the clear square [ua, ub] x [va, vb] of a board
## (as _panel()), in its warm-white neon on the board's dark background.
func _emblem(layer: MeshLayer, side: int, x: float, d0: float, length: float, y0: float, ua: float, ub: float,
		va: float, vb: float, e: float) -> void:
	var half: float = e * 0.5
	var uc: float = (ua + ub) * 0.5
	var vc: float = (va + vb) * 0.5
	var px: float = x - side * 0.004
	_board_rect(layer, side, px, d0, length, y0, ua, ub, va, vb, skin.emblem_color(), skin.emblem_glow,
		MeshKit.PAT_CULT_MARK, 0.0, Vector2((ua - uc) / half, (va - vc) / half), Vector2((ub - uc) / half, (vb - vc) / half))


static func _pick(values: PackedColorArray, a: int, b: int, c: int) -> Color:
	return values[MeshKit.hash_i(a, b, c) % values.size()]

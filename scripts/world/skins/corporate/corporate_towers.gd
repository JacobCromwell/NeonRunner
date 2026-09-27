class_name CorporateTowers
extends RefCounted
## Corporate towers for the walls (CorporateSkin, GDD §5), and what hangs over the street between them.
## A wall side is split into lots of `lot_length` metres (MeshKit.lot_run); a building covers 1–3 lots
## and is one of three kinds:
## - a TOWER: a flush podium of sterile cladding through the calm band (sometimes a lobby of dark
##   smoked glass), then a glass curtain wall or a tower of fins up to 44–170 m, often stepped back or
##   behind an alley, with cold light strips up its corners, a service crown, the brand's glowing sign
##   on its near face, banners on outriggers or a big screen hung out over the street (an ad, or the
##   cult's feed), and surveillance cameras on the podium's cornice;
## - a LOW building: the podium only, with an ad or the feed on a board on its roof or a steel sculpture
##   of the brand's mark, and a far row of towers behind it, so the sky opens up;
## - a military COMPOUND (the military presence, GDD §5): prefab blast walls through the band, wire on
##   top, and behind them an armoured block, a watchtower with a searchlight aimed at the sky, stacked
##   supply containers stencilled with the brand's mark, radar and masts.
## Every building face is flush with the wall face through the wall-run band (below band_top): nothing
## glows, lights up or sticks out there, so a pink wall fence (task B5) never competes with a band of
## light and a window cyborg's window sits flat on it. Floodlights on the podium's cornice wash the faces
## above in cold white light; everything decorative starts at decor_min_height, and what hangs out over
## the street (banners, screens) above OVER_STREET_MIN, higher than any ceiling reaches
## (CorporateCeilings.TOP_LIMIT). Nothing vent-like sits at the foot of a wall: here, wall vents are
## sewer-screech lairs (GDD §9.5).
## Faces come from corp_facade.gdshader (a face is a handful of quads) and everything else from cached
## templates; all variety comes from hashing lot indices, so chunk cuts never change a building.

enum Kind { TOWER, LOW, COMPOUND }

## Facade styles (corp_facade.gdshader).
const STYLE_CURTAIN: int = 0
const STYLE_FINS: int = 1
const STYLE_PODIUM: int = 2
const STYLE_BLAST: int = 3
const STYLE_SERVICE: int = 4
## How far buildings reach back from the street (their near ends show above lower neighbours).
const DEPTH: float = 28.0
const SETBACKS: Array[float] = [0.0, 0.0, 0.0, 4.0, 8.0, 12.0]
const LOW_SHARE: float = 0.16
## What hangs out over the street from the walls stays above this height, and every ceiling below it.
const OVER_STREET_MIN: float = 14.0
## Banners on outriggers, facing the oncoming runner: width, the arm's reach from the wall, height.
const BANNER_WIDTH: float = 2.1
const BANNER_GAP: float = 0.45
const BANNER_MIN_HEIGHT: float = 6.0
## A big screen hung out over the street: the gap between the wall and its inner edge (its arms span
## it), its casing's rim and depth, how far it keeps from a tower's ends, and from its top.
const SCREEN_GAP: float = 0.5
const SCREEN_RIM: float = 0.15
const SCREEN_CASE: float = 0.4
const SCREEN_CLEAR: float = 2.5
const SCREEN_TOP_CLEAR: float = 3.0
## The cult's emblem on a street screen's ad is at most this share of the screen's height.
const SCREEN_EMBLEM_MAX: float = 0.4
## A low building's roof board.
const BOARD_HEIGHT: float = 4.5
const BOARD_MAX_LENGTH: float = 13.0
## An emblem's clear square around its mark, as a multiple of the mark's size.
const EMBLEM_MARGIN: float = 1.3
## Skybridges and gunships over the street: one slot per this many metres (some stay empty).
const SKYBRIDGE_SPACING: float = 180.0
const SHIP_SPACING: float = 300.0
## The ships hover this high, above every skybridge.
const SHIP_MIN_Y: float = 40.0
const SKYBRIDGE_MAX_Y: float = 33.0


## One building's layout, from its lot run alone (the same whichever chunk asks).
class Building:
	var side: int
	var id: int
	var b0: float
	var b1: float
	var kind: int
	var height: float
	var setback: float
	var alley: float
	## The tower stands back from the street or behind an alley (or the building isn't a tower).
	var split: bool
	## Where the tower's own face starts along the track.
	var t0: float
	var style: int
	var wall: Color
	var podium: Color
	var lit: float
	var seed: int
	## A low building's roof, and what stands on it (0 a board, 1 the brand's sculpture).
	var roof_y: float = 0.0
	var roof_kind: int = 0
	## A banner on an outrigger (has_banner): its distance, top and height.
	var has_banner: bool = false
	var banner_d: float = 0.0
	var banner_top: float = 0.0
	var banner_h: float = 0.0


## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: CorporateSkin:
	get:
		return _skin.get_ref() as CorporateSkin
var _skin: WeakRef
var _buildings: Dictionary = {}
var _templates: Dictionary = {}


func _init(p_skin: CorporateSkin) -> void:
	_skin = weakref(p_skin)


## Adds the buildings of one wall side between two track distances.
func build(batch: MeshBatch, side: int, face_x: float, start: float, end: float) -> void:
	var solid: MeshLayer = batch.layer(skin.solid_material())
	var lot: float = skin.lot_length
	var span: Vector2i = building_at(side, floori(start / lot))
	while span.x * lot < end:
		_building(batch, building(side, span), face_x, start, end)
		span = building_at(side, span.y + 1)
	var mark_x: float = face_x - side * 0.02
	for h: float in skin.wall_height_marks:
		solid.box(Vector3(mark_x, h, -(start + end) * 0.5), Vector3(0.03, 0.05, end - start), skin.wall_mark_color)


## The first and last lot of the building covering `lot_index` on this side.
func building_at(side: int, lot_index: int) -> Vector2i:
	return MeshKit.lot_run(side, lot_index, 0.45, 3, 4)


## The layout of the building covering lots span.x to span.y on this side (cached: every chunk asks
## for its neighbours).
func building(side: int, span: Vector2i) -> Building:
	var key := Vector3i(side, span.x, span.y)
	var found: Building = _buildings.get(key)
	if found != null:
		return found
	if _buildings.size() > 512:
		_buildings.clear()
	var lot: float = skin.lot_length
	var b := Building.new()
	var id: int = span.x
	b.side = side
	b.id = id
	b.b0 = span.x * lot
	b.b1 = (span.y + 1) * lot
	# Whole numbers: the facade shader rounds the seed before hashing it.
	b.seed = MeshKit.hash_i(side, id, 11) % 997
	var r: float = MeshKit.hash01(side, id, 1)
	b.kind = Kind.COMPOUND if r < skin.compound_share else (Kind.LOW if r < skin.compound_share + LOW_SHARE else Kind.TOWER)
	b.wall = _pick(skin.facade_colors, side, id, 9)
	b.podium = _pick(skin.podium_colors, side, id, 10)
	b.lit = 0.2 + 0.4 * MeshKit.hash01(side, id, 8)
	b.style = STYLE_CURTAIN if MeshKit.hash01(side, id, 7) < 0.6 else STYLE_FINS
	b.height = lerpf(skin.building_min_height, skin.building_max_height, pow(MeshKit.hash01(side, id, 2), 1.4))
	b.setback = SETBACKS[MeshKit.hash_i(side, id, 3) % SETBACKS.size()]
	b.alley = 0.0 if MeshKit.hash01(side, id, 4) < 0.55 else 2.0 + 4.0 * MeshKit.hash01(side, id, 5)
	if b.kind != Kind.TOWER:
		b.setback = 0.0
		b.alley = 0.0
		b.roof_y = skin.band_top + 1.2 + 2.4 * MeshKit.hash01(side, id, 12)
		b.height = b.roof_y
		b.roof_kind = 1 if MeshKit.hash01(side, id, 13) < 0.35 else 0
	b.split = b.kind != Kind.TOWER or b.setback > 0.0 or b.alley > 0.0
	b.t0 = b.b0 + b.alley
	if b.kind == Kind.TOWER and MeshKit.hash01(side, id, 30) < skin.banner_share and b.b1 - b.t0 > 9.0:
		b.banner_d = lerpf(b.t0 + 3.0, b.b1 - 3.0 - BANNER_WIDTH, MeshKit.hash01(side, id, 31))
		b.banner_h = BANNER_MIN_HEIGHT + 3.0 * MeshKit.hash01(side, id, 32)
		b.banner_top = OVER_STREET_MIN + 1.0 + b.banner_h + 6.0 * MeshKit.hash01(side, id, 33)
		b.has_banner = b.banner_top + 4.0 <= b.height and b.setback <= 0.0
	_buildings[key] = b
	return b


func _building(batch: MeshBatch, b: Building, face_x: float, start: float, end: float) -> void:
	var u0: float = maxf(b.b0, start)
	var u1: float = minf(b.b1, end)
	if u1 <= u0 + 0.001:
		return
	var facade: MeshLayer = batch.layer(skin.facade_material())
	var solid: MeshLayer = batch.layer(skin.solid_material())
	var glow: MeshLayer = batch.layer(skin.glow_material())
	var side: int = b.side
	var band: float = skin.band_top
	var zc: float = -(u0 + u1) * 0.5

	# The calm band: sterile cladding, or the military's blast walls around a compound.
	var band_style: int = STYLE_BLAST if b.kind == Kind.COMPOUND else STYLE_PODIUM
	var band_color: Color = skin.blast_colors[0] if b.kind == Kind.COMPOUND else b.podium
	_face(facade, side, face_x, u0, u1, 0.0, band, band_color, 0.0, band_style, b.seed)
	# The cornice along its top, and the floodlights on it.
	var trim: Color = b.podium.lightened(0.12) if b.kind != Kind.COMPOUND else skin.gunmetal_color
	solid.box(Vector3(face_x - side * 0.1, band + 0.15, zc), Vector3(0.2, 0.3, u1 - u0), trim, 0.0, MeshKit.PAT_CORP_PLATE,
		MeshKit.ALL_FACES & ~MeshKit.FACE_NY, 2.0)
	_floodlights(solid, glow, side, face_x, u0, u1)

	match b.kind:
		Kind.LOW:
			_low(batch, facade, solid, glow, b, face_x, start, end)
		Kind.COMPOUND:
			_compound(facade, solid, glow, b, face_x, start, end)
		_:
			_tower(batch, facade, solid, glow, b, face_x, start, end)


## A tower above the podium: its faces, near side, light strips, crown and sign, banner, screen and
## cameras.
func _tower(batch: MeshBatch, facade: MeshLayer, solid: MeshLayer, glow: MeshLayer, b: Building, face_x: float,
		start: float, end: float) -> void:
	var side: int = b.side
	var id: int = b.id
	var band: float = skin.band_top
	var u0: float = maxf(b.b0, start)
	var u1: float = minf(b.b1, end)
	var tower_x: float = face_x + side * b.setback
	var height: float = b.height
	var t0: float = b.t0
	var crown: float = height - 4.6
	# The faces: flush from the band up, or stepped back or behind an alley.
	var f0: float = maxf(t0, start) if b.split else u0
	if u1 > f0:
		_face(facade, side, tower_x, f0, u1, band, crown, b.wall, b.lit, b.style, b.seed)
		_face(facade, side, tower_x, f0, u1, crown, height, b.wall, 0.0, STYLE_SERVICE, b.seed)
	if b.split and u1 > u0 and t0 > u0:
		# The podium's roof edge runs on past the alley.
		_face(facade, side, face_x, u0, minf(t0, u1), band, band + 0.9, b.podium, 0.0, STYLE_PODIUM, b.seed)
	# The tower's near side, seen across alleys, setbacks and lower neighbours.
	if t0 >= start and t0 < end:
		var x_min: float = minf(tower_x, tower_x + side * DEPTH)
		var base: float = band if b.split else 0.0
		facade.quad_uv(Vector3(x_min, base, -t0), Vector3(x_min, crown, -t0), Vector3(x_min + DEPTH, crown, -t0),
			Vector3(x_min + DEPTH, base, -t0), Vector2(x_min, base), Vector2(x_min, crown), Vector2(x_min + DEPTH, crown),
			Vector2(x_min + DEPTH, base), b.wall, b.lit, b.style, float(b.seed + 3))
		facade.quad_uv(Vector3(x_min, crown, -t0), Vector3(x_min, height, -t0), Vector3(x_min + DEPTH, height, -t0),
			Vector3(x_min + DEPTH, crown, -t0), Vector2(x_min, crown), Vector2(x_min, height), Vector2(x_min + DEPTH, height),
			Vector2(x_min + DEPTH, crown), b.wall, 0.0, STYLE_SERVICE, float(b.seed + 3))
		if MeshKit.hash01(side, id, 40) < skin.sign_share:
			_brand_sign(solid, glow, b, tower_x, crown)
	# Light strips up the corners (cold white, some in the brand's blue) and along the crown.
	var strip_color: Color = skin.brand_color if MeshKit.hash01(side, id, 41) < 0.3 else skin.flood_color
	var strip_y: float = band + 0.3
	if MeshKit.hash01(side, id, 42) < skin.strip_share:
		for edge: float in [t0 + 0.1, b.b1 - 0.1]:
			if edge >= start and edge < end:
				solid.box(Vector3(tower_x - side * 0.05, (strip_y + crown) * 0.5, -edge), Vector3(0.1, crown - strip_y, 0.16),
					strip_color, 0.55)
	if u1 > f0:
		solid.box(Vector3(tower_x - side * 0.04, crown - 0.1, -(f0 + u1) * 0.5), Vector3(0.08, 0.12, u1 - f0), strip_color, 0.5)
	# A banner on an outrigger, facing the oncoming runner, or a big screen hung out over the street.
	if b.has_banner and b.banner_d >= start and b.banner_d < end:
		_banner(solid, b, face_x)
	var screen: Dictionary = street_screen(b, face_x)
	if not screen.is_empty() and float(screen["at"]) >= start and float(screen["at"]) < end:
		_street_screen(batch, solid, glow, b, face_x, screen)
	# Surveillance cameras on the cornice, over the street.
	if MeshKit.hash01(side, id, 43) < skin.camera_share:
		var cd: float = lerpf(b.b0 + 1.5, b.b1 - 1.5, MeshKit.hash01(side, id, 44))
		if cd >= start and cd < end:
			solid.append(_camera(side), Transform3D(Basis.IDENTITY, Vector3(face_x, band + 0.3, -cd)))
	# An antenna on the roof with a steady white light (never a hazard's red).
	var mid: float = (t0 + b.b1) * 0.5
	if MeshKit.hash01(side, id, 45) < 0.45 and mid >= start and mid < end:
		var ax: float = tower_x + side * 7.0
		var ah: float = 8.0 + 10.0 * MeshKit.hash01(side, id, 46)
		solid.box(Vector3(ax, height + ah * 0.5, -mid), Vector3(0.3, ah, 0.3), skin.gunmetal_color)
		solid.box(Vector3(ax, height + ah + 0.2, -mid), Vector3(0.4, 0.4, 0.4), skin.flood_color, 0.9)
		glow.rect(Vector3(ax - 1.6, height + ah - 1.4, -mid), Vector3(3.2, 0, 0), Vector3(0, 3.2, 0), skin.flood_color, 0.3,
			MeshKit.SHAPE_RADIAL)


## The brand's big sign near the top of a tower's near side (facing the oncoming runner): its mark
## glowing in the brand's blue on a dark panel, or white on a glowing blue one.
func _brand_sign(solid: MeshLayer, glow: MeshLayer, b: Building, tower_x: float, crown: float) -> void:
	var size: float = clampf(b.height * 0.07, 6.0, 11.0)
	var x_in: float = tower_x + b.side * (DEPTH * 0.5 - size * 0.5)
	var y0: float = crown - size - 3.0
	if y0 < skin.decor_min_height + 20.0:
		return
	var x0: float = x_in if b.side > 0 else x_in - size
	var z: float = -b.t0 + 0.06
	var inverse: bool = MeshKit.hash01(b.side, b.id, 47) < 0.35
	var m: float = 1.25
	solid.box(Vector3(x0 + size * 0.5, y0 + size * 0.5, z - 0.03), Vector3(size + 0.6, size + 0.6, 0.06), Color(0.04, 0.045, 0.05))
	solid.rect(Vector3(x0, y0, z), Vector3(size, 0, 0), Vector3(0, size, 0), skin.brand_color, skin.brand_glow,
		MeshKit.PAT_CORP_LOGO, Vector2(-m, -m), Vector2(m, m), 1.0 if inverse else 0.0)
	glow.rect(Vector3(x0 - size * 0.3, y0 - size * 0.3, z + 0.3), Vector3(size * 1.6, 0, 0), Vector3(0, size * 1.6, 0),
		skin.brand_color, 0.1, MeshKit.SHAPE_RADIAL)


## A banner hanging from an outrigger arm over the street, facing the oncoming runner: the brand's
## colour, its mark and a slogan (PAT_CORP_BANNER), and on some the cult's emblem small at its foot in
## unlit bronze, like a sponsor's mark.
func _banner(solid: MeshLayer, b: Building, face_x: float) -> void:
	var side: int = b.side
	var z: float = -b.banner_d
	var w: float = BANNER_WIDTH
	var top: float = b.banner_top
	var h: float = b.banner_h
	var x_in: float = face_x - side * BANNER_GAP
	var x_out: float = x_in - side * w
	var x0: float = minf(x_in, x_out)
	var steel: Color = skin.gunmetal_color
	# The arm from the wall, a brace under it, and the weighted bar at the banner's foot.
	solid.box(Vector3((face_x + x_out) * 0.5, top + 0.12, z), Vector3(absf(face_x - x_out) + 0.2, 0.14, 0.14), steel)
	solid.box(Vector3((face_x + x_in) * 0.5, top - 0.6, z), Vector3(absf(face_x - x_in), 0.08, 0.08), steel)
	solid.box(Vector3(x0 + w * 0.5, top - h - 0.06, z), Vector3(w + 0.12, 0.12, 0.12), steel)
	# The cloth faces +z (u to the viewer's right, v up); UV x across from its left edge, y down.
	solid.rect(Vector3(x0, top - h, z + 0.02), Vector3(w, 0, 0), Vector3(0, h, 0), skin.brand_paint_color, 0.0,
		MeshKit.PAT_CORP_BANNER, Vector2(0.0, h), Vector2(w, 0.0), float(b.seed % 100 + 100 * roundi(w * 10.0)))
	var e: float = banner_emblem(b)
	if e > 0.0:
		var c := Vector3(x0 + w * 0.5, top - h + e * EMBLEM_MARGIN * 0.5 + 0.15, z + 0.03)
		_mark(solid, c, e, skin.emblem_metal_color(), 0.0)


## The size of the cult's emblem at the foot of a building's banner (0 if it has none).
func banner_emblem(b: Building) -> float:
	if not b.has_banner or not skin.carries_emblem(b.side, b.id + 7):
		return 0.0
	return clampf(BANNER_WIDTH * 0.5, skin.emblem_min_size, 1.4)


## The cult's emblem `e` metres across centred on `c`, facing +z, in `color` (glowing at `glow`, or
## unlit paint at 0) on its own dark square (MeshKit.PAT_CULT_MARK).
func _mark(solid: MeshLayer, c: Vector3, e: float, color: Color, glow_amount: float) -> void:
	var half: float = e * EMBLEM_MARGIN * 0.5
	var m: float = EMBLEM_MARGIN
	solid.rect(c - Vector3(half, half, 0.0), Vector3(half * 2.0, 0, 0), Vector3(0, half * 2.0, 0), color, glow_amount,
		MeshKit.PAT_CULT_MARK, Vector2(-m, -m), Vector2(m, m))


## The big screen hung out from a flush tower over the street, facing the oncoming runner: clear of the
## tower's ends and its banner, above everything a ceiling builds. Its middle's distance (at), bottom
## (y0), width, height, inner and outer edges (x_in at the wall end, x_out over the street), and
## whether it plays the cult's feed (`feed`). Empty if the tower has none.
func street_screen(b: Building, face_x: float) -> Dictionary:
	if b.kind != Kind.TOWER or b.setback > 0.0 or MeshKit.hash01(b.side, b.id, 140) >= skin.street_screen_share:
		return {}
	var w: float = minf(skin.street_screen_width, absf(face_x) * skin.street_screen_reach)
	var h: float = w * 9.0 / 16.0
	var lo: float = b.t0 + SCREEN_CLEAR
	var hi: float = b.b1 - SCREEN_CLEAR
	var at: float = lerpf(lo, hi, MeshKit.hash01(b.side, b.id, 142))
	if b.has_banner and at > b.banner_d - SCREEN_CLEAR and at < b.banner_d + SCREEN_CLEAR:
		at = b.banner_d + SCREEN_CLEAR * 1.5
	if hi < lo or at > hi:
		return {}
	var y0: float = maxf(skin.street_screen_bottom, OVER_STREET_MIN) + 4.0 * MeshKit.hash01(b.side, b.id, 141)
	if y0 + h + SCREEN_TOP_CLEAR > b.height:
		return {}
	var x_in: float = face_x - b.side * SCREEN_GAP
	return {"at": at, "y0": y0, "width": w, "height": h, "x_in": x_in, "x_out": x_in - b.side * w,
		"feed": skin.shows_feed(b.side, b.id, skin.feed_share)}


## A big screen over the street on two arms: a dark casing, the screen on its front facing +z, playing
## the cult's feed or a corporate ad (PAT_CORP_AD), some ads with the cult's emblem as a sponsor's badge
## in a lower corner.
func _street_screen(batch: MeshBatch, solid: MeshLayer, glow: MeshLayer, b: Building, face_x: float,
		screen: Dictionary) -> void:
	var at: float = screen["at"]
	var w: float = screen["width"]
	var h: float = screen["height"]
	var y0: float = screen["y0"]
	var x_in: float = screen["x_in"]
	var x0: float = minf(x_in, screen["x_out"])
	solid.box(Vector3(x0 + w * 0.5, y0 + h * 0.5, -at - SCREEN_CASE * 0.5 - 0.03),
		Vector3(w + SCREEN_RIM * 2.0, h + SCREEN_RIM * 2.0, SCREEN_CASE), Color(0.03, 0.035, 0.04))
	for y: float in [y0 + 0.3, y0 + h - 0.3]:
		solid.box(Vector3((face_x + x_in) * 0.5, y, -at - SCREEN_CASE * 0.5), Vector3(SCREEN_GAP + 0.2, 0.12, 0.12),
			skin.gunmetal_color)
	if screen["feed"]:
		CultFeed.screen(batch.layer(skin.feed_material()), Vector3(x0, y0, -at), Vector3(w, 0, 0), Vector3(0, h, 0),
			skin.feed_screen_brightness, b.id * 2 + (1 if b.side > 0 else 0))
		return
	solid.rect(Vector3(x0, y0, -at), Vector3(w, 0, 0), Vector3(0, h, 0), skin.brand_color, skin.brand_glow,
		MeshKit.PAT_CORP_AD, Vector2.ZERO, Vector2(w / h, 1.0), float(b.seed % 97))
	var e: float = screen_emblem(b, screen)
	if e > 0.0:
		# The corner where the slogan ends: the lower right as seen from the street.
		_mark(solid, Vector3(x0 + w - e * EMBLEM_MARGIN * 0.5 - 0.1, y0 + e * EMBLEM_MARGIN * 0.5 + 0.1, -at + 0.012), e,
			skin.emblem_color(), skin.emblem_glow)
	glow.rect(Vector3(x0 - 1.0, y0 - 1.0, -at + 0.3), Vector3(w + 2.0, 0, 0), Vector3(0, h + 2.0, 0), skin.brand_color, 0.08,
		MeshKit.SHAPE_FLAT)


## The size of the cult's emblem on a street screen showing an ad (0 if none): small beside the ad's
## own mark (GDD §5: never a centrepiece), at most SCREEN_EMBLEM_MAX of the screen's height, and only
## where it stays at least emblem_min_size (so the narrow street of three lanes has none).
func screen_emblem(b: Building, screen: Dictionary) -> float:
	if screen.is_empty() or screen["feed"] or not skin.carries_emblem(b.side, b.id):
		return 0.0
	var e: float = maxf(float(screen["height"]) * 0.22, skin.emblem_min_size)
	return e if e <= float(screen["height"]) * SCREEN_EMBLEM_MAX else 0.0


## A low building: its podium runs up to the roof, and on the roof a board (an ad, or the cult's feed)
## or a steel sculpture of the brand's mark; a far row of towers stands behind.
func _low(batch: MeshBatch, facade: MeshLayer, solid: MeshLayer, glow: MeshLayer, b: Building, face_x: float,
		start: float, end: float) -> void:
	var side: int = b.side
	var u0: float = maxf(b.b0, start)
	var u1: float = minf(b.b1, end)
	var band: float = skin.band_top
	_face(facade, side, face_x, u0, u1, band + 0.3, b.roof_y, b.podium, 0.0, STYLE_PODIUM, b.seed + 1)
	solid.box(Vector3(face_x - side * 0.08, b.roof_y + 0.12, -(u0 + u1) * 0.5), Vector3(0.16, 0.24, u1 - u0),
		b.podium.lightened(0.12), 0.0, MeshKit.PAT_CORP_PLATE, MeshKit.ALL_FACES & ~MeshKit.FACE_NY, 2.0)
	_far_row(facade, b, face_x, start, end)
	var mid: float = (b.b0 + b.b1) * 0.5
	if mid < start or mid >= end:
		return
	if b.roof_kind == 1:
		_sculpture(solid, glow, b, face_x)
		return
	var board: Dictionary = roof_board(b, face_x)
	if board.is_empty():
		return
	var len: float = board["length"]
	var d0: float = board["d0"]
	var px: float = board["x"]
	var y0: float = board["y0"]
	var h: float = BOARD_HEIGHT
	var dark := Color(0.04, 0.045, 0.05)
	solid.box(Vector3(px + side * 0.2, y0 + h * 0.5, -d0 - len * 0.5), Vector3(0.3, h + 0.4, len + 0.4), dark)
	for leg: float in [d0 + 1.0, d0 + len - 1.0]:
		solid.box(Vector3(px + side * 0.2, (b.roof_y + y0) * 0.5, -leg), Vector3(0.2, y0 - b.roof_y, 0.2), skin.gunmetal_color)
	if board["feed"]:
		CultFeed.wall_screen(batch.layer(skin.feed_material()), side, px, d0, len, y0, h, skin.feed_board_brightness, b.id)
		return
	var screen: Array = _wall_rect(side, px, d0, len, y0, h)
	solid.rect(screen[0], screen[1], screen[2], skin.brand_color, skin.brand_glow, MeshKit.PAT_CORP_AD, Vector2.ZERO,
		Vector2(len / h, 1.0), float((b.seed + 5) % 97))
	var e: float = board["emblem"]
	if e > 0.0:
		# The lower corner where the slogan ends: the far end on the left wall, the near end on the right.
		var ed: float = d0 + len - e * EMBLEM_MARGIN * 0.5 - 0.1 if side < 0 else d0 + e * EMBLEM_MARGIN * 0.5 + 0.1
		var half: float = e * EMBLEM_MARGIN * 0.5
		var r: Array = _wall_rect(side, px - side * 0.012, ed - half, half * 2.0, y0 + 0.1, half * 2.0)
		var m: float = EMBLEM_MARGIN
		solid.rect(r[0], r[1], r[2], skin.emblem_color(), skin.emblem_glow, MeshKit.PAT_CULT_MARK, Vector2(-m, -m), Vector2(m, m))
	glow.rect(Vector3(px - side * 0.4, y0 - 1.0, -d0 + 1.0), Vector3(0, 0, -(len + 2.0)), Vector3(0, h + 2.0, 0),
		skin.brand_color, 0.08, MeshKit.SHAPE_FLAT)


## A low building's roof board: its near end d0, length, face plane (x), bottom (y0), whether it plays
## the cult's feed (`feed`) and, if it shows an ad with the cult's emblem, the emblem's size (`emblem`,
## 0 if none). Empty if the building has none.
func roof_board(b: Building, face_x: float) -> Dictionary:
	if b.kind != Kind.LOW or b.roof_kind != 0:
		return {}
	var len: float = minf(b.b1 - b.b0 - 4.0, BOARD_MAX_LENGTH)
	if len < 5.0:
		return {}
	var feed: bool = skin.shows_feed(b.side, b.id + 3, skin.feed_share)
	var e: float = 0.0
	if not feed and skin.carries_emblem(b.side, b.id + 3):
		e = maxf(BOARD_HEIGHT * 0.24, skin.emblem_min_size)
		if e > BOARD_HEIGHT * 0.36:
			e = 0.0
	return {"d0": (b.b0 + b.b1 - len) * 0.5, "length": len, "x": face_x + b.side * (1.6 - 0.03), "y0": b.roof_y + 1.6,
		"feed": feed, "emblem": e}


## A steel sculpture of the brand's mark on a plinth on a low building's roof, floodlit: generic,
## soulless corporate art (the kind the zone's boss brings down, GDD §10).
func _sculpture(solid: MeshLayer, glow: MeshLayer, b: Building, face_x: float) -> void:
	var side: int = b.side
	var mid: float = (b.b0 + b.b1) * 0.5
	var size: float = minf(6.0, (b.b1 - b.b0) * 0.4)
	var base := Vector3(face_x + side * (size * 0.5 + 2.0), b.roof_y, -mid)
	solid.box(base + Vector3(0, 0.4, 0), Vector3(size * 0.8, 0.8, size * 1.1), b.podium.darkened(0.2), 0.0,
		MeshKit.PAT_CORP_PLATE, MeshKit.NO_BOTTOM, 3.0)
	# The mark in the zx plane standing up (its face toward the street): the block less its corner, and
	# the corner piece pushed out along the diagonal (kit_logo.gdshaderinc, corp_logo()).
	solid.append(_sculpture_template(side, size, skin.brand_paint_color.lerp(Color(0.55, 0.58, 0.62), 0.55)),
		Transform3D(Basis.IDENTITY, base + Vector3(0, 0.8, 0)))
	for s: float in [-1.0, 1.0]:
		var lamp := base + Vector3(-side * 0.5, 0.9, s * size * 0.5)
		solid.box(lamp, Vector3(0.3, 0.2, 0.3), skin.flood_color, 0.8)
		glow.rect(lamp + Vector3(0, -0.6, 0.02) - Vector3(0.6, 0, 0), Vector3(1.2, 0, 0), Vector3(0, 1.2, 0), skin.flood_color,
			0.25, MeshKit.SHAPE_RADIAL)


## The brand's mark as a sculpture `size` metres tall, standing on its base's centre at the origin,
## facing the street (toward -side on x).
func _sculpture_template(side: int, size: float, color: Color) -> MeshLayer:
	var key := Vector3i(7, side, roundi(size * 100.0))
	var found: MeshLayer = _templates.get(key)
	if found != null:
		return found
	var t := MeshLayer.new()
	var u: float = size / 1.56
	var d: float = size * 0.16
	# In mark space (-0.78..0.78, +x to the right as seen from the street, +y up): the block's L (its
	# left column and bottom row) and the corner piece up and to the right. Seen from the street, the
	# right is +z on the right wall and -z on the left one.
	var along: float = float(side)
	var parts: Array[Rect2] = [Rect2(-0.7, -0.7, 0.77, 1.4), Rect2(0.07, -0.7, 0.63, 0.77), Rect2(0.2, 0.2, 0.58, 0.58)]
	for r: Rect2 in parts:
		var c: Vector2 = r.get_center() * u
		var s: Vector2 = r.size * u
		t.box(Vector3(0, size * 0.5 + c.y, along * c.x), Vector3(d, s.y, s.x), color, 0.0, MeshKit.PAT_CORP_PLATE,
			MeshKit.ALL_FACES, 2.0)
	_templates[key] = t
	return t


## A military compound (GDD §5: the military presence): wire along the top of the blast walls, and
## behind them an armoured block with slit windows, a watchtower with its searchlight aimed at the sky,
## stacked supply containers stencilled with the brand's mark, a radar dome and a mast.
func _compound(facade: MeshLayer, solid: MeshLayer, glow: MeshLayer, b: Building, face_x: float, start: float,
		end: float) -> void:
	var side: int = b.side
	var id: int = b.id
	var band: float = skin.band_top
	var u0: float = maxf(b.b0, start)
	var u1: float = minf(b.b1, end)
	var zc: float = -(u0 + u1) * 0.5
	var olive: Color = skin.olive_color
	var gun: Color = skin.gunmetal_color
	# Concertina wire along the top of the walls: two dark coils.
	for i: int in 2:
		var wx: float = face_x + side * (0.35 + 0.4 * i)
		solid.prism_xform(Transform3D(Basis(Vector3(0.22, 0, 0), Vector3(0, 0, -(u1 - u0)), Vector3(0, 0.22, 0)),
			Vector3(wx, band + 0.55, -u0)), 6, Color(0.1, 0.1, 0.11), 0.0, MeshKit.PAT_RIBS, false)
	# The armoured block behind the walls.
	var bx: float = face_x + side * 8.0
	var top: float = band + 6.0 + 3.0 * MeshKit.hash01(side, id, 50)
	var near: float = b.b0 + 2.0
	var far: float = b.b1 - 2.0
	var c0: float = maxf(near, start)
	var c1: float = minf(far, end)
	if c1 > c0:
		_block_face(solid, side, bx, c0, c1, band - 1.0, top, olive.lerp(gun, 0.4 * MeshKit.hash01(side, id, 51)))
		solid.box(Vector3(bx + side * 7.0, top + 0.05, -(c0 + c1) * 0.5), Vector3(14.0, 0.1, c1 - c0), gun.darkened(0.3), 0.0,
			MeshKit.PAT_PLAIN, MeshKit.FACE_PY)
	if near >= start and near < end:
		var x_min: float = minf(bx, bx + side * 14.0)
		solid.rect(Vector3(x_min, band - 1.0, -near), Vector3(14.0, 0, 0), Vector3(0, top - band + 1.0, 0), olive.darkened(0.1),
			0.0, MeshKit.PAT_CORP_PLATE, Vector2.ZERO, Vector2.ONE, 1.0)
	# Supply containers stacked against the wall, stencilled with the brand's mark and codes.
	var stacks: int = 1 + MeshKit.hash_i(side, id, 52) % 2
	for i: int in stacks:
		var sd: float = lerpf(b.b0 + 4.0, b.b1 - 4.0, (float(i) + 0.5) / stacks)
		if sd >= start and sd < end:
			_containers(solid, side, face_x + side * 2.2, sd, band - 2.2, MeshKit.hash_i(side, id, 53 + i))
	# A watchtower near the compound's near end, its searchlight aimed at the sky ahead, leaning away
	# from the street: never over the lanes (a boss that flies there keeps the air to itself).
	var wd: float = b.b0 + 3.0
	if wd >= start and wd < end:
		solid.append(_watchtower(side), Transform3D(Basis.IDENTITY, Vector3(face_x + side * 3.2, band, -wd)))
		var lamp := Vector3(face_x + side * 3.2, band + 9.4, -wd)
		var aim := Vector3(side * 0.3, 1.0, -0.55).normalized()
		_beam(glow, lamp, aim, 34.0, 1.4)
	# A radar dome and a mast on the block's roof.
	var rd: float = lerpf(near + 3.0, far - 3.0, MeshKit.hash01(side, id, 55))
	if rd >= start and rd < end and far - near > 8.0:
		var rb := Vector3(bx + side * 6.0, top, -rd)
		solid.prism(rb, 1.6, 1.4, 10, gun)
		solid.prism_xform(Transform3D(Basis.from_scale(Vector3(1.9, 1.7, 1.9)), rb + Vector3(0, 1.4, 0)), 10,
			Color(0.62, 0.64, 0.66))
		solid.box(rb + Vector3(side * 4.0, 5.0, 2.0), Vector3(0.25, 10.0, 0.25), gun)
		solid.box(rb + Vector3(side * 4.0, 10.1, 2.0), Vector3(0.35, 0.35, 0.35), skin.flood_color, 0.9)
	_far_row(facade, b, face_x, start, end)


## The armoured block's face toward the street (x, facing the track), from distance c0 to c1 and
## height y0 to y1: armour plating (PAT_CORP_PLATE 1) with a row of dark slit windows, a few dimly lit.
func _block_face(solid: MeshLayer, side: int, x: float, c0: float, c1: float, y0: float, y1: float, color: Color) -> void:
	var r: Array = _wall_rect(side, x, c0, c1 - c0, y0, y1 - y0)
	solid.rect(r[0], r[1], r[2], color, 0.0, MeshKit.PAT_CORP_PLATE, Vector2.ZERO, Vector2.ONE, 1.0)
	var y: float = y1 - 2.2
	var d: float = ceilf(c0 / 3.0) * 3.0 + 1.0
	while d + 1.6 < c1:
		var lit: bool = MeshKit.hash01(side, roundi(d), 56) < 0.3
		var w: Array = _wall_rect(side, x - side * 0.02, d, 1.6, y, 0.35)
		solid.rect(w[0], w[1], w[2], skin.window_color if lit else Color(0.03, 0.035, 0.04), 0.35 if lit else 0.0)
		d += 3.0


## Stacked supply containers standing on `bottom` at distance d (their doors toward the street at x),
## olive and grey, with the brand's mark or a code stencilled on (PAT_STENCIL).
func _containers(solid: MeshLayer, side: int, x: float, d: float, bottom: float, k: int) -> void:
	var levels: int = 2 + k % 2
	for i: int in levels:
		var h: float = 2.6
		var len: float = 6.0
		var shift: float = (MeshKit.hash01(k, i, 1) - 0.5) * 0.8
		var color: Color = skin.olive_color if MeshKit.hash01(k, i, 2) < 0.65 else skin.gunmetal_color.lightened(0.25)
		var c := Vector3(x + side * 1.3, bottom + h * (float(i) + 0.5), -(d + shift))
		solid.box(c, Vector3(2.5, h, len), color.darkened(0.1), 0.0, MeshKit.PAT_RIBS, MeshKit.ALL_FACES & ~MeshKit.FACE_NY)
		var kind: int = MeshKit.STENCIL_LOGO_CORRUGATED if MeshKit.hash01(k, i, 3) < 0.6 else MeshKit.STENCIL_CODE_CORRUGATED
		var r: Array = _wall_rect(side, c.x - side * 1.26, d + shift - len * 0.5, len, c.y - h * 0.5, h)
		solid.rect(r[0], r[1], r[2], color, 0.0, MeshKit.PAT_STENCIL, Vector2(-len * 0.5, -h * 0.5), Vector2(len * 0.5, h * 0.5),
			MeshKit.stencil_param(kind, 3, MeshKit.hash_i(k, i, 4)))


## A watchtower standing on the wall's top (its foot at the origin, the street toward -side on x): four
## steel legs, a cabin with a dark glass band, a searchlight on its roof. Cached per side.
func _watchtower(side: int) -> MeshLayer:
	var key := Vector3i(8, side, 0)
	var found: MeshLayer = _templates.get(key)
	if found != null:
		return found
	var t := MeshLayer.new()
	var gun: Color = skin.gunmetal_color
	var olive: Color = skin.olive_color
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			t.box(Vector3(sx * 0.9, 3.4, sz * 0.9), Vector3(0.16, 6.8, 0.16), gun)
	t.box(Vector3(0, 3.4, 0), Vector3(1.9, 0.12, 1.9), gun)
	t.box(Vector3(0, 7.9, 0), Vector3(2.4, 2.2, 2.4), olive, 0.0, MeshKit.PAT_CORP_PLATE, MeshKit.ALL_FACES, 1.0)
	t.box(Vector3(0, 8.2, 0), Vector3(2.44, 0.6, 2.44), Color(0.04, 0.05, 0.06), 0.0, MeshKit.PAT_GLASS,
		MeshKit.ALL_FACES & ~(MeshKit.FACE_PY | MeshKit.FACE_NY))
	t.box(Vector3(0, 9.05, 0), Vector3(2.8, 0.14, 2.8), gun.darkened(0.2))
	t.box(Vector3(0, 9.4, 0), Vector3(0.6, 0.5, 0.6), skin.searchlight_color, 0.85)
	_templates[key] = t
	return t


## A steady searchlight beam from `from` along `dir`, `length` metres long and `width` wide at its
## source: two crossed additive cards, fading along the beam. Aimed at the sky, never at the lanes.
func _beam(glow: MeshLayer, from: Vector3, dir: Vector3, length: float, width: float) -> void:
	var side_a: Vector3 = dir.cross(Vector3.UP).normalized()
	if side_a.length() < 0.1:
		side_a = Vector3.RIGHT
	var side_b: Vector3 = dir.cross(side_a).normalized()
	for s: Vector3 in [side_a, side_b]:
		var w: float = width * 2.2
		glow.quad(from - s * width * 0.5, from + dir * length - s * w * 0.5, from + dir * length + s * w * 0.5,
			from + s * width * 0.5, skin.searchlight_color, 0.12, MeshKit.SHAPE_BEAM)


## Behind a low building or a compound: a far row of towers, so the skyline has depth.
func _far_row(facade: MeshLayer, b: Building, face_x: float, start: float, end: float) -> void:
	var side: int = b.side
	var u0: float = maxf(b.b0 - 2.0, start)
	var u1: float = minf(b.b1 + 2.0, end)
	if u1 <= u0:
		return
	var x: float = face_x + side * (26.0 + 22.0 * MeshKit.hash01(side, b.id, 21))
	var h: float = lerpf(70.0, skin.building_max_height + 30.0, MeshKit.hash01(side, b.id, 22))
	var style: int = STYLE_CURTAIN if MeshKit.hash01(side, b.id, 24) < 0.6 else STYLE_FINS
	_face(facade, side, x, u0, u1, skin.band_top, h, _pick(skin.facade_colors, side, b.id, 23), 0.5, style, b.seed + 11)


## Floodlights on the cornice between u0 and u1 (the facade shader's wash is centred on them): lamp
## heads glowing cold white, just above the calm band.
func _floodlights(solid: MeshLayer, glow: MeshLayer, side: int, face_x: float, u0: float, u1: float) -> void:
	var spacing: float = skin.flood_spacing
	var k: int = ceili(u0 / spacing - 0.5)
	while (float(k) + 0.5) * spacing < u1:
		var d: float = (float(k) + 0.5) * spacing
		k += 1
		if d < u0:
			continue
		var lamp := Vector3(face_x - side * 0.34, skin.band_top + 0.42, -d)
		solid.box(lamp, Vector3(0.26, 0.18, 0.46), skin.gunmetal_color)
		solid.box(lamp + Vector3(0, 0.095, 0), Vector3(0.2, 0.01, 0.38), skin.flood_color, 0.9, MeshKit.PAT_PLAIN, MeshKit.FACE_PY)
		glow.rect(lamp + Vector3(-0.55, -0.25, 0.3), Vector3(1.1, 0, 0), Vector3(0, 1.1, 0), skin.flood_color, 0.22,
			MeshKit.SHAPE_RADIAL)


## A surveillance camera on the cornice (its bracket on the wall at the origin, the street toward
## -side): an arm, a dark housing tilted down at the street. Cached per side.
func _camera(side: int) -> MeshLayer:
	var key := Vector3i(9, side, 0)
	var found: MeshLayer = _templates.get(key)
	if found != null:
		return found
	var t := MeshLayer.new()
	var gun: Color = skin.gunmetal_color
	t.box(Vector3(-side * 0.25, 0.55, 0), Vector3(0.5, 0.08, 0.08), gun)
	var tilt := Basis(Vector3(0, 0, 1), side * 0.45)
	t.box_xform(Transform3D(tilt.scaled_local(Vector3(0.5, 0.22, 0.22)), Vector3(-side * 0.55, 0.45, 0)), Color(0.1, 0.11, 0.12))
	t.box_xform(Transform3D(tilt.scaled_local(Vector3(0.04, 0.14, 0.14)), Vector3(-side * 0.8, 0.33, 0)), Color(0.02, 0.02, 0.025),
		0.0, MeshKit.PAT_GLASS)
	_templates[key] = t
	return t


## The screens on the walls playing the feed (CorporateSkin.feed_boards()) with middles in [start, end).
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
		var screen: Dictionary = street_screen(b, face_x)
		if not screen.is_empty() and screen["feed"] and float(screen["at"]) >= start and float(screen["at"]) < end:
			out.append({"side": side, "at": screen["at"], "kind": &"street_screen", "width": screen["width"],
				"height": screen["height"], "center": Vector3((float(screen["x_in"]) + float(screen["x_out"])) * 0.5,
				float(screen["y0"]) + float(screen["height"]) * 0.5, -float(screen["at"]))})
		span = building_at(side, span.y + 1)
	return out


## The cult's emblems (CorporateSkin.cult_emblems()) with middles in [start, end).
func emblems(side: int, face_x: float, start: float, end: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lot: float = skin.lot_length
	var span: Vector2i = building_at(side, floori(start / lot))
	while span.x * lot < end:
		var b: Building = building(side, span)
		var screen: Dictionary = street_screen(b, face_x)
		var e: float = screen_emblem(b, screen)
		if e > 0.0:
			var x0: float = minf(float(screen["x_in"]), float(screen["x_out"]))
			out.append({"side": side, "at": screen["at"], "kind": &"screen", "size": e, "center": Vector3(
				x0 + float(screen["width"]) - e * EMBLEM_MARGIN * 0.5 - 0.1, float(screen["y0"]) + e * EMBLEM_MARGIN * 0.5 + 0.1,
				-float(screen["at"]))})
		var board: Dictionary = roof_board(b, face_x)
		if not board.is_empty() and float(board["emblem"]) > 0.0:
			var be: float = board["emblem"]
			var len: float = board["length"]
			var d0: float = board["d0"]
			var at: float = d0 + len - be * EMBLEM_MARGIN * 0.5 - 0.1 if side < 0 else d0 + be * EMBLEM_MARGIN * 0.5 + 0.1
			out.append({"side": side, "at": at, "kind": &"roof_board", "size": be,
				"center": Vector3(board["x"], float(board["y0"]) + 0.1 + be * EMBLEM_MARGIN * 0.5, -at)})
		var foot: float = banner_emblem(b)
		if foot > 0.0:
			var x_in: float = face_x - side * BANNER_GAP
			out.append({"side": side, "at": b.banner_d, "kind": &"banner", "size": foot, "center": Vector3(
				x_in - side * BANNER_WIDTH * 0.5, b.banner_top - b.banner_h + foot * EMBLEM_MARGIN * 0.5 + 0.15, -b.banner_d)})
		span = building_at(side, span.y + 1)
	var kept: Array[Dictionary] = []
	for e: Dictionary in out:
		if float(e["at"]) >= start and float(e["at"]) < end:
			kept.append(e)
	return kept


# --- Over the street ------------------------------------------------------------------------

## Glass skybridges between the towers high over the street, and military gunships hovering higher
## still, between two track distances. Built with the left wall.
func overhead(batch: MeshBatch, half_width: float, start: float, end: float) -> void:
	var solid: MeshLayer = batch.layer(skin.solid_material())
	var glow: MeshLayer = batch.layer(skin.glow_material())
	var k: int = floori(start / SKYBRIDGE_SPACING)
	while float(k) * SKYBRIDGE_SPACING < end:
		var sb: Dictionary = skybridge(k, half_width)
		k += 1
		if sb.is_empty() or float(sb["at"]) < start or float(sb["at"]) >= end:
			continue
		_skybridge(solid, sb)
	var s: int = floori(start / SHIP_SPACING)
	while float(s) * SHIP_SPACING < end:
		var at: float = (float(s) + 0.2 + 0.6 * MeshKit.hash01(s, 90)) * SHIP_SPACING
		var slot: int = s
		s += 1
		if at < start or at >= end or MeshKit.hash01(slot, 91) >= skin.hover_ship_share:
			continue
		var y: float = SHIP_MIN_Y + 12.0 * MeshKit.hash01(slot, 92)
		var x: float = (MeshKit.hash01(slot, 93) - 0.5) * half_width
		var yaw: float = (MeshKit.hash01(slot, 94) - 0.5) * 0.5
		var ship: MeshBatch = CorporateShips.hover_ship(skin, slot % 2)
		batch.append(ship, Transform3D(Basis(Vector3.UP, yaw), Vector3(x, y, -at)))
		# Its searchlight rakes a tower's face, never the lanes below.
		var toward: float = -1.0 if MeshKit.hash01(slot, 95) < 0.5 else 1.0
		_beam(glow, Vector3(x, y - 1.6, -at + 6.0), Vector3(toward * 0.8, -0.35, 0.45).normalized(), 30.0, 1.2)


## The skybridge in slot k (one per SKYBRIDGE_SPACING metres, skybridge_share of them), where both
## towers are tall enough to hold it: its distance (at), floor height (y) and ends (x0, x1). Empty if
## the slot has none.
func skybridge(k: int, half_width: float) -> Dictionary:
	if MeshKit.hash01(k, 80) >= skin.skybridge_share:
		return {}
	var at: float = (float(k) + 0.25 + 0.5 * MeshKit.hash01(k, 81)) * SKYBRIDGE_SPACING
	var y: float = skin.skybridge_min_height + (SKYBRIDGE_MAX_Y - skin.skybridge_min_height) * MeshKit.hash01(k, 82)
	var ends: Array[float] = []
	var lot: float = skin.lot_length
	for side: int in [-1, 1]:
		var b: Building = building(side, building_at(side, floori(at / lot)))
		if b.kind != Kind.TOWER or at < b.t0 + 3.5 or at > b.b1 - 3.5 or b.height < y + 12.0:
			return {}
		ends.append(float(side) * (half_width + b.setback))
	return {"at": at, "y": y, "x0": ends[0], "x1": ends[1]}


## A glass skybridge across the street: a steel soffit and frame, its glass sides showing a corridor
## lit cold white (PAT_CORP_GLASS), the brand's mark on its fascia.
func _skybridge(solid: MeshLayer, sb: Dictionary) -> void:
	var at: float = sb["at"]
	var y: float = sb["y"]
	var x0: float = sb["x0"]
	var x1: float = sb["x1"]
	var w: float = x1 - x0
	var depth: float = 6.0
	var h: float = 4.2
	var z: float = -at
	var steel: Color = skin.gunmetal_color.lightened(0.15)
	solid.box(Vector3((x0 + x1) * 0.5, y - 0.5, z), Vector3(w, 1.0, depth), steel, 0.0, MeshKit.PAT_CORP_PLATE,
		MeshKit.ALL_FACES & ~MeshKit.FACE_PY, 0.0)
	solid.box(Vector3((x0 + x1) * 0.5, y + h + 0.3, z), Vector3(w, 0.6, depth), steel.darkened(0.2), 0.0, MeshKit.PAT_CORP_PLATE,
		MeshKit.ALL_FACES & ~MeshKit.FACE_NY, 2.0)
	# The glass toward the oncoming runner, and the far side (seen once it's passed overhead).
	solid.rect(Vector3(x0, y, z + depth * 0.5), Vector3(w, 0, 0), Vector3(0, h, 0), skin.window_color, 0.5,
		MeshKit.PAT_CORP_GLASS, Vector2(x0, 0.0), Vector2(x1, h), h * 10.0)
	solid.rect(Vector3(x1, y, z - depth * 0.5), Vector3(-w, 0, 0), Vector3(0, h, 0), skin.window_color, 0.5,
		MeshKit.PAT_CORP_GLASS, Vector2(x0, 0.0), Vector2(x1, h), h * 10.0)
	# The brand's mark on the fascia under the glass, facing the runner.
	var m: float = 0.95
	solid.rect(Vector3(-1.0, y - 0.95, z + depth * 0.5 + 0.02), Vector3(2.0, 0, 0), Vector3(0, 0.9, 0), skin.brand_color,
		skin.brand_glow, MeshKit.PAT_CORP_LOGO, Vector2(-m * 2.0 / 0.9, -m), Vector2(m * 2.0 / 0.9, m), 0.0)


# --- Helpers ------------------------------------------------------------------------------

## A facade piece (corp_facade.gdshader) in the wall plane at x, facing the track, from distance u0 to
## u1 and height y0 to y1. UV is (distance, height) in metres, so windows line up across pieces.
func _face(layer: MeshLayer, side: int, x: float, u0: float, u1: float, y0: float, y1: float, color: Color, lit: float,
		style: int, seed: int) -> void:
	if u1 <= u0 + 0.0005 or y1 <= y0 + 0.0005:
		return
	MeshKit.facade_quad(layer, side, x, u0, u1, y0, y1, y1, color, lit, style, float(seed))


## A rectangle in a wall-parallel plane at x facing the street, from distance d0 over `length`, from
## height y0 over h: [origin, u, v] for MeshLayer.rect(), u to the viewer's right as seen from the street.
static func _wall_rect(side: int, x: float, d0: float, length: float, y0: float, h: float) -> Array:
	if side < 0:
		return [Vector3(x, y0, -d0), Vector3(0, 0, -length), Vector3(0, h, 0)]
	return [Vector3(x, y0, -d0 - length), Vector3(0, 0, length), Vector3(0, h, 0)]


static func _pick(values: PackedColorArray, a: int, b: int, c: int) -> Color:
	return values[MeshKit.hash_i(a, b, c) % values.size()]

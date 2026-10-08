class_name GoldenFacades
extends RefCounted
## The Golden Zone's walls (GoldenSkin): opulent facades of the elite's city in the same future as
## every zone (GDD §5). A wall side is split into lots of `lot_length` metres (MeshKit.lot_run); a
## building covers 1–3 lots and is one of three kinds:
## - a palace: seamless white or cream cladding with tall rounded windows in gold frames, a marble
##   ledge over the entablature and base-mounted golden statues holding halberds (the statue kit,
##   GoldenStatue), balconies with gold rails high up, a marble parapet with a gold rail;
## - a gallery: a lower hall with great windows and gilded frames hung out from its face, turned toward
##   the approaching runner, showing the cult's feed or its emblem on red;
## - a tower: champagne mirror glass on gold mullions and gold fins, a setback terrace, a glazed crown;
##   red banners with the cult's emblem hung out over the street, facing the approach, a big screen
##   playing the feed on some, and the emblem in relief on the face of its setback that faces the
##   approach (seen over lower neighbours).
## Every building face is flush with the wall face from the canal up past the wall-run band: that
## plane is the wall-run surface. The band (golden_facade.gdshader's BAND) stays calm and solid, with
## only the gold inlay lines of the wall-run height marks. Decorative Sentinel meshes are mounted at
## the wall base as scenery only. Their visual recess is not a gameplay niche or hitbox; a live
## Sentinel's niche still opens only where one stands (GoldenSkin.note_wall_enemies).
## Overhead, sky bridges are slung between towers high over the street, their faces carrying the
## emblem toward the approach.
## Faces seen only from behind (turned away from the runner, who always looks down the track) are left
## out. All variety comes from hashing lot indices, so chunk cuts never change a building.

enum Kind { PALACE, GALLERY, TOWER }

## Facade styles (golden_facade.gdshader).
const STYLE_PLINTH: int = 0
const STYLE_BAND: int = 1
const STYLE_FRIEZE: int = 2
const STYLE_UPPER: int = 3
const STYLE_TOWER: int = 4
const STYLE_CROWN: int = 5
const STYLE_DEEP: int = 6
const STOREY: float = 3.6
## How far buildings reach back from the street (their near ends show above lower neighbours).
const DEPTH: float = 22.0
## The palaces' statue ledge: how far it juts out and how thick it is (its top at frieze_top + LEDGE_UP).
const LEDGE_OUT: float = 0.9
const LEDGE_UP: float = 0.2
const LEDGE_THICK: float = 0.5
## The decorative base opening is a visual recess only; it is not a gameplay niche or hitbox.
## The opening is deliberately wider than the old live-niche silhouette: turned poses and their
## halberds need enough trackwise clearance to read from the runner's approach, not just enough
## room for the body at a front-on angle.
const BASE_STATUE_NICHE_SIZE := Vector2(2.0, 3.4)
## The width of the gold frame round a statue niche's opening (GoldenStatue.recess's `f`).
const BASE_STATUE_FRAME: float = 0.12
## Where a base-mounted statue stands (its pedestal's centre, recessed behind the wall face), and how
## far it turns from the street toward the approaching runner (a three-quarter view from the lanes).
const STATUE_TURN: float = 0.35
## A balcony's floor over its storey's floor line: at the sills of the windows above it
## (golden_facade.gdshader's UPPER style).
const BALCONY_UP: float = 0.7
## Towers' gold fins: spacing, depth, width.
const FIN_SPACING: float = 4.5
const FIN_OUT: float = 0.32
## A banner's pole juts out this far past the cloth; the cloth hangs this far from the wall.
const BANNER_GAP: float = 0.3
## Gilded frames on galleries: size, angle toward the approach, gap from the wall, height of the middle.
const FRAME_SIZE := Vector2(4.2, 2.6)
const FRAME_TURN: float = 0.5
const FRAME_GAP: float = 0.35
const FRAME_Y: float = 11.4
const FRAME_RIM: float = 0.16
## Hung screens: gap from the wall to the screen's inner edge, rim, and the narrowest worth hanging.
const SCREEN_GAP: float = 0.5
const SCREEN_RIM: float = 0.18
const SCREEN_MIN_WIDTH: float = 1.8
## Sky bridges: the deck's thickness and length along the track.
const SKY_DECK: float = 1.6
const SKY_LENGTH: float = 7.0
## Clearance kept around a tower's banner, screen and relief, and between them and its ends.
const CLEAR: float = 3.5
## The lowest a banner's cloth hangs: high over the wall-run band and the ceilings.
const BANNER_BOTTOM: float = 11.0
## How far the decorative statues (with their halberds) and the gilded frames (their far corners) reach
## out from the wall face, and the lowest anything of the walls hangs over the street further out
## (hung screens, banner poles, sky bridges): bounds for clearance_profile(), which test_golden_skin
## checks against what the walls build.
const STATUE_REACH: float = 1.5
const FRAME_REACH: float = 2.8
const OVER_STREET: float = 12.5
## How far a relief stands out from the gold rim behind it, and the rim from the face it is on; how far
## an emblem or screen stands off the cloth or casing behind it: far enough apart that they never
## flicker into each other from across the city.
const RELIEF_STANDOFF: float = 0.08
const RIM_DEPTH: float = 0.12
const EMBLEM_STANDOFF: float = 0.05


## One building's layout, computed from its lot run alone.
class Building:
	var side: int
	var id: int
	var b0: float
	var b1: float
	var kind: int
	var height: float
	var seed: int
	var wall: Color
	var lit: float
	## Towers: the upper part steps back this far from the street at setback_y (0: none), and its top
	## crown_h metres are the glazed crown.
	var setback: float = 0.0
	var setback_y: float = 0.0
	var crown_h: float = 0.0
	## Palaces: the wall-base statues, as (distance, pose index).
	var statues: Array[Vector2] = []
	## Towers: the banner (its middle's distance; -1 none) and the top of its pole.
	var banner_d: float = -1.0
	var banner_top: float = 0.0
	## Towers: the hung screen playing the feed (empty if none).
	var screen: Dictionary = {}
	## Galleries: the gilded frames, each {at, feed}.
	var frames: Array[Dictionary] = []


## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: GoldenSkin:
	get:
		return _skin.get_ref() as GoldenSkin
var _skin: WeakRef
var _buildings: Dictionary = {}
## Balconies and statues built once per side (and pose), placed with one bulk append.
var _templates: Dictionary = {}


func _init(p_skin: GoldenSkin) -> void:
	_skin = weakref(p_skin)


## Adds the buildings of one wall side between two track distances.
func build(batch: MeshBatch, side: int, face_x: float, start: float, end: float) -> void:
	var lot: float = skin.lot_length
	var span: Vector2i = MeshKit.lot_run(side, floori(start / lot), 0.45, 3, 5)
	while span.x * lot < end:
		var b: Building = building(side, span)
		_building(batch, b, face_x, start, end)
		span = MeshKit.lot_run(side, span.y + 1, 0.45, 3, 5)


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
	# Whole numbers: the facade shader rounds the seed before using it.
	b.seed = MeshKit.hash_i(side, id, 11) % 997
	var r: float = MeshKit.hash01(side, id, 1)
	b.kind = Kind.PALACE if r < skin.palace_share else (Kind.GALLERY if r < skin.palace_share + skin.gallery_share
		else Kind.TOWER)
	b.wall = skin.stone_colors[MeshKit.hash_i(side, id, 9) % skin.stone_colors.size()]
	b.lit = lerpf(skin.lit_min, skin.lit_max, MeshKit.hash01(side, id, 8))
	var hr: float = MeshKit.hash01(side, id, 2)
	var length: float = b.b1 - b.b0
	match b.kind:
		Kind.PALACE:
			b.height = lerpf(skin.palace_min_height, skin.palace_max_height, hr)
			_place_statues(b)
		Kind.GALLERY:
			b.height = lerpf(maxf(skin.frieze_top + STOREY * 1.5, 14.0), maxf(skin.frieze_top + STOREY * 2.5, 19.0), hr)
			_place_frames(b)
		_:
			b.height = lerpf(skin.tower_min_height, skin.tower_max_height, pow(hr, 1.3))
			b.crown_h = 4.0 + 4.0 * MeshKit.hash01(side, id, 14)
			if MeshKit.hash01(side, id, 12) < 0.65:
				b.setback = 2.0 + 2.5 * MeshKit.hash01(side, id, 13)
				b.setback_y = skin.frieze_top + STOREY * float(2 + MeshKit.hash_i(side, id, 15) % 4)
				if b.setback_y > b.height - b.crown_h - STOREY * 2.0:
					b.setback = 0.0
			if length >= 12.0 and MeshKit.hash01(side, id, 20) < skin.banner_share:
				b.banner_d = lerpf(b.b0 + CLEAR, b.b1 - CLEAR - skin.banner_width, MeshKit.hash01(side, id, 21))
				b.banner_top = maxf(skin.decor_min_height, BANNER_BOTTOM) + skin.banner_length + 3.0 * MeshKit.hash01(side, id, 22)
				if b.banner_top > b.height - 2.0 or (b.setback > 0.0 and b.banner_top > b.setback_y - 0.5):
					b.banner_d = -1.0
			b.screen = _hung_screen(b)
	_buildings[key] = b
	return b


## The statues on a palace facade: a place every statue_spacing metres clear of its ends, statue_share
## of them filled, each in one of the decorative poses. The list is reused for the base mount and is
## independent of lane count.
func _place_statues(b: Building) -> void:
	var spacing: float = skin.statue_spacing
	var count: int = floori((b.b1 - b.b0 - 3.0) / spacing)
	if count < 1:
		return
	var first: float = (b.b0 + b.b1) * 0.5 - float(count - 1) * spacing * 0.5
	for i: int in count:
		var at: float = first + float(i) * spacing
		# Never an alcove across a chunk's end (task H1): the wall is built a chunk at a time, each cutting its
		# part of the opening but only the one with the statue's middle building the recess and the statue,
		# and a chunk that knows of a live niche beside it may leave the alcove out, which the next doesn't know.
		if chunk_straddled(at):
			continue
		if MeshKit.hash01(b.seed, i, 31) < skin.statue_share:
			var pose: int = MeshKit.hash_i(b.seed, i, 32) % GoldenStatue.DECORATIVE.size()
			b.statues.append(Vector2(at, float(pose)))


## True if a decorative alcove (its opening and its gold frame) centred at track distance `at` reaches across
## the end of a chunk (TrackBuilder.CHUNK_LENGTH), where the walls are built in pieces: _place_statues leaves
## such a statue out.
static func chunk_straddled(at: float) -> bool:
	var half: float = BASE_STATUE_NICHE_SIZE.x * 0.5 + BASE_STATUE_FRAME + 0.03
	return floorf((at - half) / TrackBuilder.CHUNK_LENGTH) != floorf((at + half) / TrackBuilder.CHUNK_LENGTH)


## A gallery's gilded frames: one or two, clear of its ends.
func _place_frames(b: Building) -> void:
	var length: float = b.b1 - b.b0
	var count: int = 1 if length < 32.0 else 2
	for i: int in count:
		var at: float = b.b0 + length * (float(i) + 0.5) / float(count)
		b.frames.append({"at": at, "feed": skin.shows_feed(b.seed, 70 + i, skin.feed_share)})


## Where a tower's big screen playing the cult's feed hangs (feed_hung_share of the towers): its
## middle's distance (at) and bottom (y0), clear of its ends and its banner, high above the play space
## and the ceilings. Empty if none. screen_spec() sizes it to the street.
func _hung_screen(b: Building) -> Dictionary:
	if not skin.shows_feed(b.side, b.id, skin.feed_hung_share):
		return {}
	var h: float = skin.feed_hung_width * 9.0 / 16.0
	var lo: float = b.b0 + CLEAR
	var hi: float = b.b1 - CLEAR
	var at: float = lerpf(lo, hi, MeshKit.hash01(b.side, b.id, 142))
	if b.banner_d >= 0.0 and absf(at - (b.banner_d + skin.banner_width * 0.5)) < skin.banner_width * 0.5 + CLEAR:
		at = b.banner_d + skin.banner_width + CLEAR if b.banner_d + skin.banner_width + CLEAR <= hi else b.banner_d - CLEAR
	if hi < lo or at > hi or at < lo:
		return {}
	var y0: float = maxf(skin.feed_hung_bottom, OVER_STREET + SCREEN_RIM) + 3.0 * MeshKit.hash01(b.side, b.id, 141)
	var top_limit: float = b.setback_y if b.setback > 0.0 else b.height - b.crown_h
	if y0 + h + 1.0 > top_limit:
		return {}
	return {"at": at, "y0": y0}


## A tower's hung screen on a street whose wall face is at face_x, facing the oncoming runner: its
## middle's distance (at), bottom (y0), width and height (16:9, as wide as feed_hung_width allows
## within feed_hung_reach of the street's half width), and inner and outer edges (x_in at the wall
## end, x_out over the street, world x). Empty if the tower has none, or the street is too narrow.
func screen_spec(b: Building, face_x: float) -> Dictionary:
	if b.screen.is_empty():
		return {}
	var w: float = minf(skin.feed_hung_width, absf(face_x) * skin.feed_hung_reach - SCREEN_GAP)
	if w < SCREEN_MIN_WIDTH:
		return {}
	return {"at": b.screen["at"], "y0": b.screen["y0"], "width": w, "height": w * 9.0 / 16.0,
		"x_in": face_x - b.side * SCREEN_GAP, "x_out": face_x - b.side * (SCREEN_GAP + w)}


# --- Listings (GoldenSkin's statue_spots, feed_boards, cult_emblems) --------------------------

## The decorative statues whose feet lie in [start, end) (GoldenSkin.statue_spots()). They are
## mesh-only scenery mounted at the wall base, not wall enemies.
func statue_spots(side: int, face_x: float, start: float, end: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lot: float = skin.lot_length
	var span: Vector2i = MeshKit.lot_run(side, floori(start / lot), 0.45, 3, 5)
	while span.x * lot < end:
		var b: Building = building(side, span)
		for s: Vector2 in b.statues:
			if s.x >= start and s.x < end:
				out.append({"side": side, "at": s.x, "center": skin.decorative_statue_mount(side, face_x, s.x),
					"facing": _statue_facing(side), "height": GoldenStatue.PEDESTAL_HEIGHT + GoldenStatue.STATURE,
					"pose": GoldenStatue.DECORATIVE[int(s.y)]})
		span = MeshKit.lot_run(side, span.y + 1, 0.45, 3, 5)
	return out


## The screens playing the feed (GoldenSkin.feed_boards()) with middles in [start, end).
func feed_boards(side: int, face_x: float, start: float, end: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lot: float = skin.lot_length
	var span: Vector2i = MeshKit.lot_run(side, floori(start / lot), 0.45, 3, 5)
	while span.x * lot < end:
		var b: Building = building(side, span)
		for f: Dictionary in b.frames:
			if f["feed"] and float(f["at"]) >= start and float(f["at"]) < end:
				var spec: Dictionary = _frame_spec(b, f, face_x)
				out.append({"side": side, "at": f["at"], "kind": &"frame", "width": spec["width"], "height": spec["height"],
					"center": spec["center"]})
		var s: Dictionary = screen_spec(b, face_x)
		if not s.is_empty() and float(s["at"]) >= start and float(s["at"]) < end:
			out.append({"side": side, "at": s["at"], "kind": &"hung", "width": s["width"], "height": s["height"],
				"center": Vector3((float(s["x_in"]) + float(s["x_out"])) * 0.5, float(s["y0"]) + float(s["height"]) * 0.5,
					-float(s["at"]))})
		span = MeshKit.lot_run(side, span.y + 1, 0.45, 3, 5)
	return out


## The cult's emblems (GoldenSkin.cult_emblems()) with middles in [start, end): banners, reliefs on
## towers' near faces, frames showing it, and (on the left side's listing, as the skin builds them
## with the left wall) the sky bridges' faces.
func emblems(side: int, face_x: float, start: float, end: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lot: float = skin.lot_length
	var span: Vector2i = MeshKit.lot_run(side, floori(start / lot), 0.45, 3, 5)
	while span.x * lot < end:
		var b: Building = building(side, span)
		if b.banner_d >= 0.0:
			var spec: Dictionary = _banner_spec(b, face_x)
			if float(spec["at"]) >= start and float(spec["at"]) < end:
				out.append({"side": side, "at": spec["at"], "kind": &"banner", "size": spec["size"], "center": spec["emblem"]})
		var relief: Dictionary = relief_spec(b, face_x)
		if not relief.is_empty() and b.b0 >= start and b.b0 < end:
			out.append({"side": side, "at": b.b0, "kind": &"relief", "size": relief["size"], "center": relief["center"]})
		for f: Dictionary in b.frames:
			if not f["feed"] and float(f["at"]) >= start and float(f["at"]) < end:
				var spec: Dictionary = _frame_spec(b, f, face_x)
				out.append({"side": side, "at": f["at"], "kind": &"frame", "size": spec["emblem"], "center": spec["center"]})
		span = MeshKit.lot_run(side, span.y + 1, 0.45, 3, 5)
	if side < 0:
		for bridge: Dictionary in sky_bridges(absf(face_x), start, end):
			out.append({"side": 0, "at": bridge["at"], "kind": &"sky_bridge", "size": bridge["emblem"],
				"center": Vector3(0.0, float(bridge["y"]) + SKY_DECK * 0.5, -float(bridge["at"]) + SKY_LENGTH * 0.5 + RIM_DEPTH
					+ RELIEF_STANDOFF)})
	return out


## The top of the palaces' architectural ledge. Decorative Sentinel models no longer use it; they are
## mounted at the wall base so they can blend with a live Sentinel's silhouette.
func ledge_top() -> float:
	return skin.frieze_top + LEDGE_UP


## What the walls hold out over the street, as [reach, floor] pairs from the wall out: within `reach`
## metres of a wall face nothing of the walls sticks out lower than `floor` (world height): the
## architectural ledge, the gilded frames and the banners; beyond the last, nothing lower than
## OVER_STREET. Base-mounted statues are mesh-only scenery at the wall face and do not change ceiling
## clearance or wall-run collision.
func clearance_profile() -> Array[Vector2]:
	return [Vector2(LEDGE_OUT + 0.05, ledge_top() - LEDGE_THICK), Vector2(STATUE_REACH, ledge_top()),
		Vector2(FRAME_REACH, FRAME_Y - FRAME_SIZE.y * 0.5 - FRAME_RIM), Vector2(BANNER_GAP + skin.banner_width + 0.1,
			BANNER_BOTTOM)]


# --- A building ---------------------------------------------------------------------------------

func _building(batch: MeshBatch, b: Building, face_x: float, start: float, end: float) -> void:
	var u0: float = maxf(b.b0, start)
	var u1: float = minf(b.b1, end)
	if u1 <= u0 + 0.001:
		return
	var facade: MeshLayer = batch.layer(skin.facade_material())
	var solid: MeshLayer = batch.layer(skin.solid_material())
	var side: int = b.side
	# Below the walkways the face is in deep shade (seen only through gaps, which must read as holes);
	# above them the plinth, the calm band and the entablature, flush with the wall face.
	_face(facade, side, face_x, u0, u1, -skin.canal_depth, 0.0, skin.gap_inside_color, 0.0, STYLE_DEEP, b.seed)
	# A Gilded Sentinel's niche opens in the plinth and the calm band (GoldenSkin.note_wall_enemies).
	var holes: Array[Rect2] = skin.niches(side)
	if b.kind == Kind.PALACE:
		for statue: Vector2 in b.statues:
			if skin.crowds_niche(side, statue.x, BASE_STATUE_NICHE_SIZE.x * 0.5):
				continue
			holes.append(Rect2(statue.x - BASE_STATUE_NICHE_SIZE.x * 0.5, skin.decorative_statue_mount_y(),
				BASE_STATUE_NICHE_SIZE.x, BASE_STATUE_NICHE_SIZE.y))
	_open_face(facade, side, face_x, u0, u1, 0.0, skin.plinth_top, b.wall, STYLE_PLINTH, b.seed, holes)
	_open_face(facade, side, face_x, u0, u1, skin.plinth_top, skin.band_top, b.wall, STYLE_BAND, b.seed, holes)
	_face(facade, side, face_x, u0, u1, skin.band_top, skin.frieze_top, b.wall, 0.0, STYLE_FRIEZE, b.seed)
	match b.kind:
		Kind.PALACE:
			_palace(batch, facade, solid, b, face_x, u0, u1, start, end)
		Kind.GALLERY:
			_gallery(batch, facade, solid, b, face_x, u0, u1, start, end)
		_:
			_tower(batch, facade, solid, b, face_x, u0, u1, start, end)


## A palace: cladding with tall windows over the entablature, an architectural ledge, wall-base
## statues in recessed visual openings, balconies high up, the parapet with its gold rail, and its near end.
func _palace(_batch: MeshBatch, facade: MeshLayer, solid: MeshLayer, b: Building, face_x: float, u0: float, u1: float,
		start: float, end: float) -> void:
	var side: int = b.side
	_face(facade, side, face_x, u0, u1, skin.frieze_top, b.height, b.wall, b.lit, STYLE_UPPER, b.seed)
	var zc: float = -(u0 + u1) * 0.5
	var ledge := Vector3(face_x - side * LEDGE_OUT * 0.5, ledge_top() - LEDGE_THICK * 0.5, zc)
	solid.box(ledge, Vector3(LEDGE_OUT, LEDGE_THICK, u1 - u0), skin.stone_colors[0], 0.0, MeshKit.PAT_MARBLE,
		_street_faces(side) | MeshKit.FACE_PY | MeshKit.FACE_NY, 1.0)
	solid.box(ledge + Vector3(-side * (LEDGE_OUT * 0.5 + 0.01), -0.12, 0.0), Vector3(0.03, 0.08, u1 - u0), skin.gold_color,
		0.0, MeshKit.PAT_GOLD, _street_faces(side), 0.9)
	for s: Vector2 in b.statues:
		if s.x >= start and s.x < end and not skin.crowds_niche(side, s.x, BASE_STATUE_NICHE_SIZE.x * 0.5):
			var niche_basis := Basis(Vector3.UP, atan2(float(-side), 0.0))
			solid.append(skin.statues().recess(BASE_STATUE_NICHE_SIZE.x, BASE_STATUE_NICHE_SIZE.y,
				skin.decorative_statue_recess_depth()),
				Transform3D(niche_basis, Vector3(face_x, skin.decorative_statue_mount_y(), -s.x)))
			solid.append(_statue(side, int(s.y)), Transform3D(Basis.IDENTITY,
				skin.decorative_statue_mount(side, face_x, s.x)))
	# Balconies under some upper windows (a column of windows every cell, as the shader lays them out).
	var cw: float = _cell_width(b.seed)
	var first_floor: float = skin.frieze_top + STOREY
	var cells: int = floori(b.b1 / cw) - ceili(b.b0 / cw)
	for c: int in range(ceili(b.b0 / cw), floori(b.b1 / cw)):
		var cx: float = (float(c) + 0.5) * cw
		if cx < start or cx >= end or cx < b.b0 + 1.0 or cx > b.b1 - 1.0 or cells < 1:
			continue
		var column: int = MeshKit.hash_i(b.seed, c, 5)
		var storey: int = 0
		while first_floor + float(storey) * STOREY + STOREY < b.height - 1.5:
			var y: float = first_floor + float(storey) * STOREY + BALCONY_UP
			if ((column >> ((storey * 3) % 27)) & 7) == 0:
				solid.append(_balcony(side), Transform3D(Basis.IDENTITY, Vector3(face_x, y, -cx)))
			storey += 1
	# The parapet: a marble cap with a gold rail on it.
	solid.box(Vector3(face_x - side * 0.18, b.height + 0.2, zc), Vector3(0.36, 0.4, u1 - u0), b.wall, 0.0, MeshKit.PAT_MARBLE,
		_street_faces(side) | MeshKit.FACE_PY | MeshKit.FACE_NY)
	solid.box(Vector3(face_x - side * 0.12, b.height + 0.9, zc), Vector3(0.08, 0.08, u1 - u0), skin.gold_color, 0.0,
		MeshKit.PAT_GOLD, MeshKit.ALL_FACES, 0.9)
	_near_end(facade, b, face_x, start, end, 0.0, skin.frieze_top, b.height, STYLE_UPPER)


## A gallery: great windows over the entablature and its gilded frames.
func _gallery(batch: MeshBatch, facade: MeshLayer, solid: MeshLayer, b: Building, face_x: float, u0: float, u1: float,
		start: float, end: float) -> void:
	var side: int = b.side
	_face(facade, side, face_x, u0, u1, skin.frieze_top, b.height, b.wall, b.lit, STYLE_UPPER, b.seed + 3)
	var zc: float = -(u0 + u1) * 0.5
	solid.box(Vector3(face_x - side * 0.25, b.height + 0.25, zc), Vector3(0.5, 0.5, u1 - u0), skin.stone_colors[0], 0.0,
		MeshKit.PAT_MARBLE, _street_faces(side) | MeshKit.FACE_PY | MeshKit.FACE_NY)
	solid.box(Vector3(face_x - side * 0.51, b.height + 0.05, zc), Vector3(0.03, 0.1, u1 - u0), skin.gold_color, 0.0,
		MeshKit.PAT_GOLD, _street_faces(side), 0.9)
	for f: Dictionary in b.frames:
		if float(f["at"]) >= start and float(f["at"]) < end:
			_frame(batch, solid, b, f, face_x)
	_near_end(facade, b, face_x, start, end, 0.0, skin.frieze_top, b.height, STYLE_UPPER)


## A tower: mirror glass with gold fins up to its setback, the set-back part above it, the glazed
## crown, its banner and hung screen, and its near end with the relief facing the approach.
func _tower(batch: MeshBatch, facade: MeshLayer, solid: MeshLayer, b: Building, face_x: float, u0: float, u1: float,
		start: float, end: float) -> void:
	var side: int = b.side
	var body_top: float = b.height - b.crown_h
	var step: float = b.setback_y if b.setback > 0.0 else body_top
	var top_x: float = face_x + side * b.setback
	_face(facade, side, face_x, u0, u1, skin.frieze_top, step, b.wall, b.lit, STYLE_TOWER, b.seed)
	if b.setback > 0.0:
		_face(facade, side, top_x, u0, u1, step, body_top, b.wall, b.lit, STYLE_TOWER, b.seed)
		# The terrace's edge: a cream slab under a gold rail.
		var zc: float = -(u0 + u1) * 0.5
		solid.box(Vector3(face_x + side * (b.setback * 0.5 - 0.1), step + 0.15, zc), Vector3(b.setback + 0.2, 0.3, u1 - u0),
			b.wall, 0.0, MeshKit.PAT_MARBLE, _street_faces(side) | MeshKit.FACE_PY | MeshKit.FACE_NY)
		solid.box(Vector3(face_x - side * 0.05, step + 1.2, zc), Vector3(0.07, 0.07, u1 - u0), skin.gold_color, 0.0,
			MeshKit.PAT_GOLD, MeshKit.ALL_FACES, 0.9)
	_face(facade, side, top_x, u0, u1, body_top, b.height, b.wall, b.lit, STYLE_CROWN, b.seed)
	# Gold fins up the glass, above the entablature.
	var k: int = ceili((b.b0 + 1.5) / FIN_SPACING)
	while float(k) * FIN_SPACING < b.b1 - 1.5:
		var d: float = float(k) * FIN_SPACING
		k += 1
		if d < start or d >= end:
			continue
		var fy0: float = skin.frieze_top + 0.3
		solid.box(Vector3(face_x - side * FIN_OUT * 0.5, (fy0 + step) * 0.5, -d), Vector3(FIN_OUT, step - fy0, 0.12),
			skin.gold_color, 0.0, MeshKit.PAT_GOLD, _street_faces(side) | MeshKit.FACE_PZ, 0.9)
		if b.setback > 0.0:
			solid.box(Vector3(top_x - side * FIN_OUT * 0.5, (step + 0.3 + body_top) * 0.5, -d),
				Vector3(FIN_OUT, body_top - step - 0.3, 0.12), skin.gold_color, 0.0, MeshKit.PAT_GOLD,
				_street_faces(side) | MeshKit.FACE_PZ, 0.9)
	if b.banner_d >= 0.0:
		var spec: Dictionary = _banner_spec(b, face_x)
		if float(spec["at"]) >= start and float(spec["at"]) < end:
			_banner(solid, b, spec)
	var screen: Dictionary = screen_spec(b, face_x)
	if not screen.is_empty() and float(screen["at"]) >= start and float(screen["at"]) < end:
		_hung(batch, solid, b, screen, face_x)
	# The near end: the base up to the setback, the set-back part above it; the relief on it.
	_near_end(facade, b, face_x, start, end, 0.0, skin.frieze_top, step, STYLE_TOWER)
	_near_end(facade, b, face_x, start, end, b.setback, step, b.height, STYLE_TOWER)
	var relief: Dictionary = relief_spec(b, face_x)
	if not relief.is_empty() and b.b0 >= start and b.b0 < end:
		var c: Vector3 = relief["center"]
		var size: float = relief["size"]
		var panel: float = relief["panel"]
		solid.box(Vector3(c.x, c.y, -b.b0 + RIM_DEPTH * 0.5), Vector3(panel + 0.3, panel + 0.3, RIM_DEPTH), skin.gold_color, 0.0,
			MeshKit.PAT_GOLD, MeshKit.FACE_PZ | MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PY | MeshKit.FACE_NY, 0.9)
		GoldenSkin.emblem_panel(solid, Vector3(c.x - panel * 0.5, c.y - panel * 0.5, c.z), Vector3(panel, 0, 0),
			Vector3(0, panel, 0), size, skin.stone_colors[0], 1)


## The relief on a tower's near end (facing the approach, seen over the lower building before it):
## its middle (center, on the panel's face), the emblem's size and the panel's; empty if the tower has
## none. Reliefs sit on relief_share of the towers whose near end rises well above the building
## before them.
func relief_spec(b: Building, face_x: float) -> Dictionary:
	if b.kind != Kind.TOWER or MeshKit.hash01(b.side, b.id, 40) >= skin.relief_share:
		return {}
	var lot: float = skin.lot_length
	var before: Building = building(b.side, MeshKit.lot_run(b.side, floori(b.b0 / lot) - 1, 0.45, 3, 5))
	var size: float = skin.emblem_size * 1.3
	var panel: float = size * 1.35
	var top_limit: float = b.height - b.crown_h - 1.0
	var y: float = maxf(before.height + panel * 0.5 + 1.5, skin.decor_min_height + panel * 0.5 + 6.0)
	if y + panel * 0.5 > top_limit:
		return {}
	# Out from the street face's corner by a little more than the setback, where it shows best.
	var x: float = face_x + b.side * (b.setback + panel * 0.5 + 1.2) if y > b.setback_y and b.setback > 0.0 \
		else face_x + b.side * (panel * 0.5 + 1.2)
	return {"center": Vector3(x, y, -b.b0 + RIM_DEPTH + RELIEF_STANDOFF), "size": size, "panel": panel}


# --- Pieces ---------------------------------------------------------------------------------

## A decorative statue for the wall on `side` in decorative pose `pose` (GoldenStatue.DECORATIVE), its
## pedestal's foot at the origin, facing the street and turned a little toward the approach.
func _statue(side: int, pose: int) -> MeshLayer:
	var key := Vector3i(10, side, pose)
	var found: MeshLayer = _templates.get(key)
	if found != null:
		return found
	var t := MeshLayer.new()
	var facing: Vector3 = _statue_facing(side)
	t.append(skin.decorative_statue_mesh(GoldenStatue.pose_named(GoldenStatue.DECORATIVE[pose])),
		Transform3D(Basis(Vector3.UP, atan2(facing.x, facing.z)), Vector3.ZERO))
	_templates[key] = t
	return t


## The way a statue on the wall on `side` faces: the street, turned toward the approaching runner.
static func _statue_facing(side: int) -> Vector3:
	return Vector3(-side * cos(STATUE_TURN), 0.0, sin(STATUE_TURN))


## A balcony under an upper window (its floor's centre on the wall at the origin, on `side`): a
## rounded marble slab, a gold rail on slim posts, a warm lamp under it. Cached per side.
func _balcony(side: int) -> MeshLayer:
	var key := Vector3i(11, side, 0)
	var found: MeshLayer = _templates.get(key)
	if found != null:
		return found
	var t := MeshLayer.new()
	var reach: float = 0.9
	var hw: float = 1.1
	var marble: Color = skin.stone_colors[0]
	t.box(Vector3(-side * reach * 0.5, 0.0, 0.0), Vector3(reach, 0.18, hw * 2.0), marble, 0.0, MeshKit.PAT_MARBLE,
		MeshKit.ALL_FACES & ~(MeshKit.FACE_PX if side > 0 else MeshKit.FACE_NX), 1.0)
	t.box(Vector3(-side * (reach - 0.05), 1.0, 0.0), Vector3(0.06, 0.06, hw * 2.0), skin.gold_color, 0.0, MeshKit.PAT_GOLD,
		MeshKit.ALL_FACES, 0.95)
	t.box(Vector3(-side * (reach - 0.05), 0.5, 0.0), Vector3(0.02, 0.8, hw * 2.0 - 0.1), skin.glass_color, 0.0,
		MeshKit.PAT_GLASS, MeshKit.FACE_PX if side < 0 else MeshKit.FACE_NX)
	for z: float in [-hw + 0.06, 0.0, hw - 0.06]:
		t.box(Vector3(-side * (reach - 0.05), 0.55, z), Vector3(0.05, 0.9, 0.05), skin.gold_color, 0.0, MeshKit.PAT_GOLD,
			MeshKit.ALL_FACES, 0.95)
	t.box(Vector3(-side * reach * 0.5, -0.1, 0.0), Vector3(0.2, 0.03, 0.2), skin.lamp_color, 0.6, MeshKit.PAT_PLAIN,
		MeshKit.FACE_NY)
	_templates[key] = t
	return t


## Where a tower's banner hangs: its pole's top (y) and the cloth's rectangle, facing the approach:
## at (its middle's distance), x0/x1 (the cloth's inner and outer edges), top, bottom; and the emblem
## on it (its size and middle).
func _banner_spec(b: Building, face_x: float) -> Dictionary:
	var w: float = skin.banner_width
	var x0: float = face_x - b.side * BANNER_GAP
	var x1: float = x0 - b.side * w
	var top: float = b.banner_top
	var bottom: float = top - skin.banner_length
	var size: float = minf(skin.emblem_size, w * 0.8)
	var ey: float = top - 0.4 - size * 0.62
	var at: float = b.banner_d + w * 0.5
	return {"at": at, "x0": x0, "x1": x1, "top": top, "bottom": bottom, "size": size,
		"emblem": Vector3((x0 + x1) * 0.5, ey, -at + EMBLEM_STANDOFF)}


## A red banner with the cult's emblem (GDD §5: shown openly), hung from a gold pole jutting out of the
## tower's face and facing the approaching runner, high above the band.
func _banner(solid: MeshLayer, b: Building, spec: Dictionary) -> void:
	var side: int = b.side
	var x0: float = spec["x0"]
	var x1: float = spec["x1"]
	var top: float = spec["top"]
	var bottom: float = spec["bottom"]
	var z: float = -float(spec["at"])
	var w: float = absf(x1 - x0)
	var left: float = minf(x0, x1)
	# The pole and its finial.
	solid.box(Vector3((x0 + x1) * 0.5 + side * BANNER_GAP * 0.5, top + 0.08, z - 0.02), Vector3(w + BANNER_GAP + 0.4, 0.1, 0.1),
		skin.gold_color, 0.0, MeshKit.PAT_GOLD, MeshKit.ALL_FACES, 0.95)
	solid.prism(Vector3(x1 - side * 0.25, top - 0.02, z - 0.02), 0.09, 0.2, 6, skin.gold_color, 0.0, MeshKit.PAT_GOLD,
		true, 0.95)
	# The cloth (its front, facing +z), the emblem over it.
	solid.rect(Vector3(left, bottom, z), Vector3(w, 0, 0), Vector3(0, top - bottom, 0), skin.red_color, 0.0,
		MeshKit.PAT_CLOTH, Vector2(0.0, 0.0), Vector2(1.0, top - bottom), roundf(w * 100.0))
	var e: Vector3 = spec["emblem"]
	var size: float = spec["size"]
	GoldenSkin.emblem_panel(solid, Vector3(e.x - size * 0.5, e.y - size * 0.5, e.z), Vector3(size, 0, 0),
		Vector3(0, size, 0), size, skin.red_color, 0)


## A tower's big screen playing the cult's feed (spec: screen_spec()), hung out over the street on
## two gold arms: a gilded casing with the screen on its front, facing the oncoming runner (+z).
func _hung(batch: MeshBatch, solid: MeshLayer, b: Building, s: Dictionary, face_x: float) -> void:
	var at: float = s["at"]
	var w: float = s["width"]
	var h: float = s["height"]
	var y0: float = s["y0"]
	var x_in: float = s["x_in"]
	var x0: float = minf(x_in, float(s["x_out"]))
	solid.box(Vector3(x0 + w * 0.5, y0 + h * 0.5, -at - EMBLEM_STANDOFF - 0.15), Vector3(w + SCREEN_RIM * 2.0,
		h + SCREEN_RIM * 2.0, 0.3), skin.gold_color, 0.0, MeshKit.PAT_GOLD, MeshKit.ALL_FACES & ~MeshKit.FACE_NZ, 0.9)
	for y: float in [y0 + 0.3, y0 + h - 0.3]:
		solid.box(Vector3((face_x + x_in) * 0.5, y, -at - 0.2), Vector3(SCREEN_GAP + 0.3, 0.1, 0.1), skin.gold_color, 0.0,
			MeshKit.PAT_GOLD, MeshKit.ALL_FACES, 0.9)
	CultFeed.screen(batch.layer(skin.feed_material()), Vector3(x0, y0, -at), Vector3(w, 0, 0), Vector3(0, h, 0),
		skin.feed_hung_brightness, b.id * 2 + (1 if b.side > 0 else 0))


## Where a gallery's frame hangs: its middle (center), facing (out of its face), right (the viewer's
## right along it), width and height, and the emblem's size (if it shows the emblem).
func _frame_spec(b: Building, f: Dictionary, face_x: float) -> Dictionary:
	var facing := Vector3(-b.side * cos(FRAME_TURN), 0.0, sin(FRAME_TURN))
	var right: Vector3 = Vector3.UP.cross(facing)
	var w: float = FRAME_SIZE.x
	var h: float = FRAME_SIZE.y
	var out: float = FRAME_GAP + w * 0.5 * absf(right.x) + FRAME_RIM
	var center := Vector3(face_x - b.side * out, FRAME_Y, -float(f["at"]))
	return {"center": center, "facing": facing, "right": right, "width": w, "height": h, "emblem": h * 0.8}


## A gilded frame hung out from a gallery's face on a gold bracket, turned toward the approaching
## runner: the cult's feed on its screen, or its emblem on red cloth.
func _frame(batch: MeshBatch, solid: MeshLayer, b: Building, f: Dictionary, face_x: float) -> void:
	var spec: Dictionary = _frame_spec(b, f, face_x)
	var c: Vector3 = spec["center"]
	var facing: Vector3 = spec["facing"]
	var right: Vector3 = spec["right"]
	var w: float = spec["width"]
	var h: float = spec["height"]
	var basis := Basis(right, Vector3.UP, facing)
	# The frame: a gold rim round a dark backing, all turned with the frame.
	var rim: float = FRAME_RIM
	for piece: Array in [[Vector3(0.0, (h + rim) * 0.5, 0.0), Vector3(w + rim * 2.0, rim, 0.14)],
			[Vector3(0.0, -(h + rim) * 0.5, 0.0), Vector3(w + rim * 2.0, rim, 0.14)],
			[Vector3((w + rim) * 0.5, 0.0, 0.0), Vector3(rim, h, 0.14)], [Vector3(-(w + rim) * 0.5, 0.0, 0.0), Vector3(rim, h, 0.14)]]:
		solid.box_xform(Transform3D(basis.scaled_local(piece[1]), c + basis * (piece[0] as Vector3)), skin.gold_color, 0.0,
			MeshKit.PAT_GOLD, MeshKit.ALL_FACES & ~MeshKit.FACE_NZ, 0.95)
	solid.box_xform(Transform3D(basis.scaled_local(Vector3(w, h, 0.06)), c - facing * 0.07), Color(0.05, 0.05, 0.06), 0.0,
		MeshKit.PAT_PLAIN, MeshKit.FACE_PZ)
	# The bracket to the wall.
	var back: Vector3 = c - facing * 0.1
	var wall_point := Vector3(face_x, c.y, back.z)
	solid.box((back + wall_point) * 0.5, Vector3(absf(back.x - wall_point.x) + 0.1, 0.12, 0.12), skin.gold_color, 0.0,
		MeshKit.PAT_GOLD, MeshKit.ALL_FACES, 0.9)
	var origin: Vector3 = c - right * (w * 0.5) - Vector3.UP * (h * 0.5) + facing * 0.03
	if f["feed"]:
		CultFeed.screen(batch.layer(skin.feed_material()), origin, right * w, Vector3.UP * h, skin.feed_frame_brightness,
			b.seed + int(f["at"]))
	else:
		GoldenSkin.emblem_panel(solid, origin, right * w, Vector3.UP * h, spec["emblem"], skin.red_color, 0)


## The near end of a building (the face at its start distance, toward the approaching runner), seen
## over a lower neighbour: from the street face (stepped back by `setback`) back DEPTH metres, from y0
## to y1. Only in the chunk holding the building's start.
func _near_end(facade: MeshLayer, b: Building, face_x: float, start: float, end: float, setback: float, y0: float,
		y1: float, style: int) -> void:
	if b.b0 < start or b.b0 >= end or y1 <= y0 + 0.01:
		return
	var xa: float = face_x + b.side * setback
	var xb: float = face_x + b.side * DEPTH
	var x_min: float = minf(xa, xb)
	var x_max: float = maxf(xa, xb)
	var z: float = -b.b0
	facade.quad_uv(Vector3(x_min, y0, z), Vector3(x_min, y1, z), Vector3(x_max, y1, z), Vector3(x_max, y0, z),
		Vector2(x_min, y0), Vector2(x_min, y1), Vector2(x_max, y1), Vector2(x_max, y0), b.wall, b.lit, style, float(b.seed + 3))


# --- Overhead -------------------------------------------------------------------------------

## The sky bridges between two track distances (see overhead()): at (the deck's middle's distance), y
## (the deck's underside), the faces they meet on either side (x_left, x_right), and the relief on the
## near face: its panel's size and the emblem's.
func sky_bridges(half_width: float, start: float, end: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var spacing: float = skin.sky_bridge_spacing
	var k: int = floori(start / spacing) - 1
	while float(k) * spacing < end + spacing:
		var at: float = (float(k) + 0.25 + 0.5 * MeshKit.hash01(k, 91)) * spacing
		var kk: int = k
		k += 1
		if at < start or at >= end or MeshKit.hash01(kk, 92) >= skin.sky_bridge_share:
			continue
		var y: float = skin.sky_bridge_height + 6.0 * MeshKit.hash01(kk, 93)
		var faces: Array[float] = []
		for side: int in [-1, 1]:
			var x: float = _tower_face_at(side, at, y, half_width)
			if x < 0.0:
				break
			faces.append(x)
		if faces.size() < 2:
			continue
		var panel: float = minf(skin.emblem_size * 1.5, SKY_DECK + 2.0)
		out.append({"at": at, "y": y, "x_left": -faces[0], "x_right": faces[1], "panel": panel,
			"emblem": minf(skin.emblem_size * 1.2, panel * 0.8)})
	return out


## Where the tower on `side` has its face at height y around distance `at` (both ends of a sky
## bridge's deck), as a distance from the track's centre; -1 if a tower isn't there, or isn't tall
## enough (with its crown above the deck).
func _tower_face_at(side: int, at: float, y: float, half_width: float) -> float:
	var lot: float = skin.lot_length
	var face: float = -1.0
	for d: float in [at - SKY_LENGTH * 0.5 - 1.0, at + SKY_LENGTH * 0.5 + 1.0]:
		var b: Building = building(side, MeshKit.lot_run(side, floori(d / lot), 0.45, 3, 5))
		if b.kind != Kind.TOWER or b.height - b.crown_h < y + SKY_DECK + 3.0:
			return -1.0
		var x: float = half_width + (b.setback if b.setback > 0.0 and y + SKY_DECK > b.setback_y - 0.3 else 0.0)
		face = maxf(face, x)
	return face


## Sky bridges slung between the towers high over the street (the future in its dominant shapes),
## between two track distances: a deck of cream stone on gold fascias, a glass balustrade under a gold
## rail, the cult's emblem in relief on its face toward the approach, lamps under it. Built with the
## left wall.
func overhead(batch: MeshBatch, half_width: float, start: float, end: float) -> void:
	var solid: MeshLayer = batch.layer(skin.solid_material())
	var glow: MeshLayer = batch.layer(skin.glow_material())
	for bridge: Dictionary in sky_bridges(half_width, start, end):
		var zn: float = -float(bridge["at"]) + SKY_LENGTH * 0.5
		var zc: float = -float(bridge["at"])
		var y: float = bridge["y"]
		var xl: float = float(bridge["x_left"]) - 1.0
		var xr: float = float(bridge["x_right"]) + 1.0
		var w: float = xr - xl
		var marble: Color = skin.stone_colors[2]
		# The deck, its underside and near face.
		solid.box(Vector3((xl + xr) * 0.5, y + SKY_DECK * 0.5, zc), Vector3(w, SKY_DECK, SKY_LENGTH), marble, 0.0,
			MeshKit.PAT_MARBLE, MeshKit.FACE_PZ | MeshKit.FACE_NY | MeshKit.FACE_PY)
		for gy: float in [y + 0.08, y + SKY_DECK - 0.08]:
			solid.box(Vector3((xl + xr) * 0.5, gy, zn + 0.02), Vector3(w, 0.14, 0.06), skin.gold_color, 0.0, MeshKit.PAT_GOLD,
				MeshKit.FACE_PZ | MeshKit.FACE_NY | MeshKit.FACE_PY, 0.95)
		# The balustrade: glass under a gold rail.
		solid.rect(Vector3(xl, y + SKY_DECK, zn - 0.2), Vector3(w, 0, 0), Vector3(0, 1.1, 0), skin.glass_color, 0.0,
			MeshKit.PAT_GLASS)
		solid.box(Vector3((xl + xr) * 0.5, y + SKY_DECK + 1.15, zn - 0.2), Vector3(w, 0.08, 0.08), skin.gold_color, 0.0,
			MeshKit.PAT_GOLD, MeshKit.ALL_FACES, 0.95)
		# The emblem, in relief on a gold-rimmed panel on the face.
		var panel: float = bridge["panel"]
		var py: float = y + SKY_DECK * 0.5
		solid.box(Vector3(0.0, py, zn + RIM_DEPTH * 0.5), Vector3(panel + 0.24, panel + 0.24, RIM_DEPTH), skin.gold_color, 0.0,
			MeshKit.PAT_GOLD, MeshKit.FACE_PZ | MeshKit.FACE_NY | MeshKit.FACE_PY | MeshKit.FACE_PX | MeshKit.FACE_NX, 0.95)
		GoldenSkin.emblem_panel(solid, Vector3(-panel * 0.5, py - panel * 0.5, zn + RIM_DEPTH + RELIEF_STANDOFF),
			Vector3(panel, 0, 0), Vector3(0, panel, 0), bridge["emblem"], skin.stone_colors[0], 1)
		# Lamps under the deck.
		var x: float = xl + 2.0
		while x < xr - 1.5:
			solid.box(Vector3(x, y - 0.03, zc), Vector3(0.3, 0.06, 0.3), skin.lamp_color, 0.6, MeshKit.PAT_PLAIN,
				MeshKit.ALL_FACES & ~MeshKit.FACE_PY)
			glow.rect(Vector3(x - 1.0, y - 0.08, zc + 1.0), Vector3(2.0, 0, 0), Vector3(0, 0, -2.0), skin.lamp_color, 0.18,
				MeshKit.SHAPE_RADIAL)
			x += 4.5


# --- Helpers ------------------------------------------------------------------------------

## A facade piece (golden_facade.gdshader) in the wall plane at x, facing the track, from distance u0
## to u1 and height y0 to y1. UV is (distance, height) in metres.
func _face(layer: MeshLayer, side: int, x: float, u0: float, u1: float, y0: float, y1: float, color: Color,
		lit: float, style: int, seed: int) -> void:
	if u1 <= u0 + 0.0005 or y1 <= y0 + 0.0005:
		return
	MeshKit.facade_quad(layer, side, x, u0, u1, y0, y1, y1, color, lit, style, float(seed))


## A facade piece like _face(), with the Gilded Sentinels' niches (`holes`) left out of it
## (GoldenSkin.open_rects; task C4).
func _open_face(layer: MeshLayer, side: int, x: float, u0: float, u1: float, y0: float, y1: float, color: Color,
		style: int, seed: int, holes: Array[Rect2]) -> void:
	if holes.is_empty():
		_face(layer, side, x, u0, u1, y0, y1, color, 0.0, style, seed)
		return
	for r: PackedFloat64Array in GoldenSkin.open_rects(u0, u1, y0, y1, holes):
		_face(layer, side, x, r[0], r[1], r[2], r[3], color, 0.0, style, seed)


## The box faces of something on the wall on `side` that the runner can see: toward the street and
## toward the approach (never the far face or the one against the wall).
static func _street_faces(side: int) -> int:
	return (MeshKit.FACE_PX if side < 0 else MeshKit.FACE_NX) | MeshKit.FACE_PZ


## The upper floors' window cell width for a seed (golden_facade.gdshader's UPPER style).
static func _cell_width(seed: int) -> float:
	var k: int = posmod(seed, 4)
	return 3.0 if k == 0 else (3.4 if k == 1 else (2.8 if k == 2 else 3.8))

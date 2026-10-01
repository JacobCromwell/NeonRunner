class_name GoldenPalaceWalls
extends RefCounted
## The Golden Palace's walls (GoldenPalaceSkin, GDD §5: "the hall's sides (colonnades, galleries,
## alcoves, tapestries, reliefs)"). A wall side is a colonnade: a flush marble panel (MeshKit.
## PAT_PALACE_PANEL, world position, with the gold wall-run height marks inlaid in it, the same
## language as every zone) from the floor up to frieze_top -- the calm band, exactly as flush and
## undecorated as every other zone's (GoldenFacades: "nothing but a hazard sign ever sticks out of
## the wall below the entablature") -- with gilded marble pilasters every lot_length metres standing
## above it, up to pilaster_height. Between two pilasters, a bay (GDD §5) is one of:
## - a gallery: a gold-framed rectangular opening into the hall beyond, showing the cult's feed
##   (CultFeed) or its emblem (gallery_share of the bays);
## - an alcove: a statue standing in the same arched, gold-framed niche a live Gilded Sentinel's does
##   (GoldenStatue.niche(), task C4's shape too: a decorative one here, GDD §9.11), in a decorative
##   pose, always at or above statue_min_height (statue_share of the bays);
## - a tapestry: a hanging length of the zone's red cloth with a gold trim and fringe (banner_share);
## - a relief: the cult's emblem in relief on a gold-rimmed marble panel (GDD §5: shown openly;
##   relief_share);
## - otherwise the flush panel simply carries on (no extra geometry: the cheapest and commonest bay).
## Decorative statues and every other bay's content stand only above frieze_top, far above the
## wall-run band (a statue at wall-run height is a live Gilded Sentinel; safe things look safe), the
## same rule GoldenFacades keeps for its ledge. All variety comes from hashing bay indices, so a
## chunk looks the same whenever it's built.
## Chunk space: x across, y up, z = -distance.

enum Content { PLAIN, GALLERY, ALCOVE, TAPESTRY, RELIEF }

## A gallery's opening and an alcove's niche (GoldenStatue.niche()).
const GALLERY_SIZE := Vector2(2.6, 3.2)
const GALLERY_RIM: float = 0.14
const GALLERY_DEPTH: float = 0.5
const ALCOVE_SIZE := Vector2(1.4, 3.4)
## How far a pilaster stands proud of the flush panel, and its cap's height.
const PILASTER_RADIUS: float = 0.28
const PILASTER_BASE: float = 0.3
const PILASTER_CAP: float = 0.26
## A standalone relief's panel is this much bigger than the emblem on it.
const RELIEF_PANEL: float = 1.3
const RIM_DEPTH: float = 0.08
const STANDOFF: float = 0.04

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: GoldenPalaceSkin:
	get:
		return _skin.get_ref() as GoldenPalaceSkin
var _skin: WeakRef


func _init(p_skin: GoldenPalaceSkin) -> void:
	_skin = weakref(p_skin)


## Adds one wall side's colonnade between two track distances: the flush panel, the pilasters, and
## every bay's content.
func build(batch: MeshBatch, side: int, face_x: float, start: float, end: float) -> void:
	var s: MeshLayer = batch.layer(skin.solid_material())
	MeshKit.facade_quad(s, side, face_x, start, end, 0.0, skin.frieze_top, skin.frieze_top, skin.stone_colors[0], 0.0,
		MeshKit.PAT_PALACE_PANEL, 0.0)
	# A gold cornice where the colonnade's upper zone begins.
	s.box(Vector3(face_x - side * 0.06, skin.frieze_top + 0.07, -(start + end) * 0.5), Vector3(0.12, 0.1, end - start),
		skin.gold_color, 0.0, MeshKit.PAT_GOLD, _street_faces(side), 0.9)
	var bay: float = skin.lot_length
	var k: int = floori(start / bay)
	while float(k) * bay < end:
		var bx: float = (float(k) + 0.5) * bay
		if bx >= start and bx < end:
			_bay(s, batch, side, face_x, k, bx)
		if float(k) * bay >= start and float(k) * bay < end:
			_pilaster(s, side, face_x, float(k) * bay)
		k += 1


## The pilaster at track distance `at` (shared by the two bays it stands between): an octagonal
## marble shaft on a gold-trimmed granite plinth, with a gold capital, from frieze_top to
## pilaster_height.
func _pilaster(s: MeshLayer, side: int, face_x: float, at: float) -> void:
	var y0: float = skin.frieze_top
	var y1: float = skin.pilaster_height
	var x: float = face_x - side * PILASTER_RADIUS * 0.7
	var z: float = -at
	s.prism(Vector3(x, y0, z), PILASTER_RADIUS * 0.85, PILASTER_BASE, 8, skin.granite_color, 0.0, MeshKit.PAT_MARBLE, true, 1.0)
	s.prism(Vector3(x, y0 + PILASTER_BASE, z), PILASTER_RADIUS * 0.6, y1 - y0 - PILASTER_BASE - PILASTER_CAP, 8,
		skin.stone_colors[0], 0.0, MeshKit.PAT_MARBLE, false, 0.0)
	s.prism(Vector3(x, y1 - PILASTER_CAP, z), PILASTER_RADIUS, PILASTER_CAP, 8, skin.gold_color, 0.0, MeshKit.PAT_GOLD, true, 0.9)


## One bay's content (Content), centred at track distance `at`, above frieze_top.
func _bay(s: MeshLayer, batch: MeshBatch, side: int, face_x: float, index: int, at: float) -> void:
	match _content(side, index):
		Content.GALLERY:
			_gallery(s, batch, side, face_x, index, at)
		Content.ALCOVE:
			_alcove(s, side, face_x, index, at)
		Content.TAPESTRY:
			_tapestry(s, side, face_x, index, at)
		Content.RELIEF:
			_relief(s, side, face_x, index, at)
		_:
			pass


## Which content a bay holds, by hashing its index (GALLERY, ALCOVE, TAPESTRY and RELIEF share the
## wall's existing exterior shares, reused for the interior's bays; otherwise PLAIN, the commonest).
func _content(side: int, index: int) -> int:
	var r: float = MeshKit.hash01(side, index, 211)
	var g: float = skin.gallery_share
	var a: float = g + skin.statue_share
	var t: float = a + skin.banner_share
	var l: float = t + skin.relief_share
	if r < g:
		return Content.GALLERY
	elif r < a:
		return Content.ALCOVE
	elif r < t:
		return Content.TAPESTRY
	elif r < l:
		return Content.RELIEF
	return Content.PLAIN


## A gold-framed rectangular opening into the hall beyond (GDD §5: "galleries"), showing the cult's
## feed in it (shows_feed()) or, otherwise, its emblem on a dark panel. The opening's width runs
## along the track (world z), its height up (world y); the frame bars are boxes thin in the axis
## they cross and full-length in the other, like any window in the mesh kit.
func _gallery(s: MeshLayer, batch: MeshBatch, side: int, face_x: float, index: int, at: float) -> void:
	var w: float = GALLERY_SIZE.x
	var h: float = GALLERY_SIZE.y
	var y0: float = maxf(skin.frieze_top, skin.decor_min_height) + 0.6
	var yc: float = y0 + h * 0.5
	var z: float = -at
	var rim: float = GALLERY_RIM
	var fx: float = face_x - side * 0.07
	for dy: float in [h * 0.5 + rim * 0.5, -(h * 0.5 + rim * 0.5)]:
		s.box(Vector3(fx, yc + dy, z), Vector3(0.14, rim, w + rim * 2.0), skin.gold_color, 0.0, MeshKit.PAT_GOLD,
			MeshKit.ALL_FACES, 0.95)
	for dz: float in [w * 0.5 + rim * 0.5, -(w * 0.5 + rim * 0.5)]:
		s.box(Vector3(fx, yc, z + dz), Vector3(0.14, h, rim), skin.gold_color, 0.0, MeshKit.PAT_GOLD, MeshKit.ALL_FACES, 0.95)
	s.box(Vector3(face_x + side * GALLERY_DEPTH * 0.5, yc, z), Vector3(GALLERY_DEPTH, h - rim, w - rim), Color(0.1, 0.09, 0.09),
		0.0, MeshKit.PAT_PLAIN, _street_faces(side) | MeshKit.FACE_PY | MeshKit.FACE_NY)
	var rv: Array = _wall_rect(side, face_x - side * STANDOFF, at - w * 0.5, w, y0, h)
	if skin.shows_feed(side, index, skin.feed_share):
		CultFeed.screen(batch.layer(skin.feed_material()), rv[0], rv[1], rv[2], skin.feed_frame_brightness,
			index * 2 + (1 if side > 0 else 0))
	else:
		GoldenSkin.emblem_panel(s, rv[0], rv[1], rv[2], h * 0.8, skin.red_color, 0)


## A statue standing in an arched, gold-framed niche (GoldenStatue.niche(): the same shape a live
## Gilded Sentinel's niche uses, task C4), in a decorative pose, at or above statue_min_height.
func _alcove(s: MeshLayer, side: int, face_x: float, index: int, at: float) -> void:
	var y: float = maxf(skin.frieze_top + 0.3, skin.statue_min_height)
	var facing := Vector3(-side, 0.0, 0.0)
	var basis := Basis(Vector3.UP, atan2(facing.x, facing.z))
	var origin := Vector3(face_x, y, -at)
	s.append(skin.statues().niche(ALCOVE_SIZE.x, ALCOVE_SIZE.y), Transform3D(basis, origin))
	var pose: int = MeshKit.hash_i(side, index, 221) % GoldenStatue.DECORATIVE.size()
	s.append(skin.statues().mesh(GoldenStatue.pose_named(GoldenStatue.DECORATIVE[pose])), Transform3D(basis, origin))


## A length of the zone's heavy red cloth with a gold trim and fringe, hung above the band
## (MeshKit.PAT_CLOTH, the same as the Golden Zone's banners: GoldenSkin.banner_width/banner_length).
func _tapestry(s: MeshLayer, side: int, face_x: float, _index: int, at: float) -> void:
	var w: float = skin.banner_width
	var h: float = skin.banner_length
	var top: float = minf(skin.frieze_top + h + 1.0, skin.pilaster_height - 0.6)
	var bottom: float = top - h
	s.box(Vector3(face_x - side * 0.05, top + 0.05, -at), Vector3(0.1, 0.1, w + 0.3), skin.gold_color, 0.0, MeshKit.PAT_GOLD,
		MeshKit.ALL_FACES, 0.9)
	var rv: Array = _wall_rect(side, face_x - side * STANDOFF, at - w * 0.5, w, bottom, top - bottom)
	s.rect(rv[0], rv[1], rv[2], skin.red_color, 0.0, MeshKit.PAT_CLOTH, Vector2(0.0, 0.0), Vector2(1.0, top - bottom),
		roundf(w * 100.0))


## The cult's emblem in relief on a gold-rimmed marble panel, standing off the flush panel (GDD §5:
## shown openly).
func _relief(s: MeshLayer, side: int, face_x: float, _index: int, at: float) -> void:
	var panel: float = skin.emblem_size * RELIEF_PANEL
	var y: float = maxf(skin.frieze_top, skin.decor_min_height) + panel * 0.5 + 0.4
	s.box(Vector3(face_x - side * RIM_DEPTH * 0.5, y, -at), Vector3(RIM_DEPTH, panel + 0.26, panel + 0.26), skin.gold_color,
		0.0, MeshKit.PAT_GOLD, _street_faces(side) | MeshKit.FACE_PY | MeshKit.FACE_NY, 0.95)
	var rv: Array = _wall_rect(side, face_x - side * (RIM_DEPTH + STANDOFF), at - panel * 0.5, panel, y - panel * 0.5, panel)
	GoldenSkin.emblem_panel(s, rv[0], rv[1], rv[2], skin.emblem_size, skin.stone_colors[0], 1)


# --- Listings (GoldenPalaceSkin's statue_spots, feed_boards, cult_emblems) --------------------

## The decorative statues whose feet lie in [start, end) (GoldenPalaceSkin.statue_spots()).
func statue_spots(side: int, face_x: float, start: float, end: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var bay: float = skin.lot_length
	var k: int = floori(start / bay)
	while float(k) * bay < end:
		var bx: float = (float(k) + 0.5) * bay
		if bx >= start and bx < end and _content(side, k) == Content.ALCOVE:
			var y: float = maxf(skin.frieze_top + 0.3, skin.statue_min_height)
			var pose: int = MeshKit.hash_i(side, k, 221) % GoldenStatue.DECORATIVE.size()
			out.append({"side": side, "at": bx, "center": Vector3(face_x, y, -bx), "facing": Vector3(-side, 0.0, 0.0),
				"height": GoldenStatue.PEDESTAL_HEIGHT + GoldenStatue.STATURE, "pose": GoldenStatue.DECORATIVE[pose]})
		k += 1
	return out


## The screens playing the feed (GoldenPalaceSkin.feed_boards()) with middles in [start, end): the
## galleries that show it instead of the emblem.
func feed_boards(side: int, face_x: float, start: float, end: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var bay: float = skin.lot_length
	var k: int = floori(start / bay)
	while float(k) * bay < end:
		var bx: float = (float(k) + 0.5) * bay
		if bx >= start and bx < end and _content(side, k) == Content.GALLERY and skin.shows_feed(side, k, skin.feed_share):
			var y0: float = maxf(skin.frieze_top, skin.decor_min_height) + 0.6
			out.append({"side": side, "at": bx, "kind": &"frame", "width": GALLERY_SIZE.x, "height": GALLERY_SIZE.y,
				"center": Vector3(face_x - side * STANDOFF, y0 + GALLERY_SIZE.y * 0.5, -bx)})
		k += 1
	return out


## The cult's emblems (GoldenPalaceSkin.cult_emblems()) with middles in [start, end): the galleries
## that show it instead of the feed, and the standalone reliefs (GDD §5: shown openly).
func cult_emblems(side: int, face_x: float, start: float, end: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var bay: float = skin.lot_length
	var k: int = floori(start / bay)
	while float(k) * bay < end:
		var bx: float = (float(k) + 0.5) * bay
		if bx >= start and bx < end:
			var content: int = _content(side, k)
			if content == Content.GALLERY and not skin.shows_feed(side, k, skin.feed_share):
				var y0: float = maxf(skin.frieze_top, skin.decor_min_height) + 0.6
				out.append({"side": side, "at": bx, "kind": &"frame", "size": GALLERY_SIZE.y * 0.8,
					"center": Vector3(face_x - side * STANDOFF, y0 + GALLERY_SIZE.y * 0.5, -bx)})
			elif content == Content.RELIEF:
				var panel: float = skin.emblem_size * RELIEF_PANEL
				var y: float = maxf(skin.frieze_top, skin.decor_min_height) + panel * 0.5 + 0.4
				out.append({"side": side, "at": bx, "kind": &"relief", "size": skin.emblem_size,
					"center": Vector3(face_x - side * (RIM_DEPTH + STANDOFF), y, -bx)})
		k += 1
	return out


static func _street_faces(side: int) -> int:
	return (MeshKit.FACE_PX if side < 0 else MeshKit.FACE_NX) | MeshKit.FACE_PZ | MeshKit.FACE_NZ


## The origin and axes (for MeshLayer.rect()) of a screen- or cloth-sized rect flush on the wall at
## `x`, facing the lanes from `side` (CultFeed.wall_screen()'s convention, so a feed screen and an
## emblem panel line up the same way): from track distance d0 back over `length`, from height y0 up
## over `height`.
static func _wall_rect(side: int, x: float, d0: float, length: float, y0: float, height: float) -> Array:
	if side < 0:
		return [Vector3(x, y0, -d0), Vector3(0, 0, -length), Vector3(0, height, 0)]
	return [Vector3(x, y0, -d0 - length), Vector3(0, 0, length), Vector3(0, height, 0)]

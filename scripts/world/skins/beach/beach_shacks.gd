class_name BeachShacks
extends RefCounted
## The Beach's walls (BeachSkin, GDD §5): a strip of low-rise shacks in the reference's spirit: bamboo-walled
## tiki bars, surf shops and lounges. A wall side is split into lots of `lot_length` metres (MeshKit.lot_run);
## a shack covers 1-3 lots, two to four storeys, so plenty of sky shows. Every shack's face is flush with the
## wall face from the pool tanks' level up past the wall-run band, in a pattern of its own (MeshKit.
## PAT_BEACH_WALL, laid out by world position so shacks and chunk cuts join): bamboo culms, woven palm mats,
## weathered planks, rusty corrugated sheets, shut roller shutters and serving hatches, flush wordless surf
## posters, between bamboo posts, with the wall-run height marks (unlit paint) at 2 m and 4 m. The band stays
## calm and closed up to band_top: nothing opens, glows, sticks out or looks like a window (a window cyborg's)
## or a vent. Everything decorative starts at decor_min_height (8 m):
## - the upper storeys' bamboo and the dark timber course at each floor;
## - a thatched roof on most (a gable at its near end, its eave reaching out over the street only on a shack
##   whose roofline is at OVER_STREET_MIN or higher), else a flat tin roof;
## - recessed upper verandas (a bar with a counter, bottles, paper lanterns and, on some, a TV playing the cult's
##   feed; a lounge; a deck with surfboards and chairs), their bamboo railings flush with the wall's plane;
## - carved tiki masks (unlit wood, no glowing eyes), swags of string lights and paper lanterns along the face;
## - on the roof, set back from the face: neon silhouette signs (a palm, a wave, a flamingo, a cocktail, a
##   surfboard, the sun or a tiki totem, never words; violet, blue or warm white), billboards (some playing the
##   cult's feed), surfboard racks, flags, palm trees, and the black rust-streaked industrial structures of the
##   reference (tanks, water towers, chimneys, dishes and antennas);
## - strings of lights and bunting across the street, on masts, no lower than string_height.
## Nothing of the walls hangs out over the street more than LIP below OVER_STREET_MIN (the same rule as the
## Corporate and Dead Zones'), higher than every ceiling reaches (BeachCeilings.TOP_LIMIT).
## Faces seen only from behind are left out. All variety comes from hashing lot indices, so chunk cuts never
## change a shack: everything but the shack's long pieces (its faces, its roof) is placed by its middle in the
## chunk that holds it.
## Template space (cached, then appended with a transform, mirrored for the right wall): the wall face at x = 0,
## the street at +x, the shack's inside at -x, y up, z along the track (+z toward the runner).

enum Roof { THATCH, TIN }
enum Verandah { BAR, LOUNGE, DECK }

## Nothing of the walls reaches further than this out from the face below OVER_STREET_MIN.
const LIP: float = 0.25
## The lowest anything hangs out over the street (the strings of lights, the thatch eaves, a palm leaning over
## it), above the highest a ceiling rises (BeachCeilings.TOP_LIMIT over the ceiling height, plus its thickness).
const OVER_STREET_MIN: float = 12.0
## How far a shack's near end face goes back from the street (seen only above lower neighbours).
const END_DEPTH: float = 7.0
## A thatched roof: its ridge's depth behind the face and its rise over the eave; an eave's reach over the street.
const ROOF_DEPTH: float = 5.0
const ROOF_RISE: float = 2.8
const EAVE_OUT: float = 1.3
## An alcove (a recessed upper veranda): its depth behind the face and its opening's height.
const ALCOVE_DEPTH: float = 1.6
const ALCOVE_HEIGHT: float = 3.0
## Roof stations: items stand every STATION metres along a shack.
const STATION: float = 6.0
## A mast's thickness, and how far behind the face's plane its foot stands.
const MAST: float = 0.12
## How far behind the face's plane a string's anchors (and its masts) are.
const STRING_BACK: float = 0.1
## The cult's emblem's clear square around its mark, as a multiple of the mark's size.
const EMBLEM_MARGIN: float = 1.3
## Template keys (a kind's base plus its variant) and the offset of a template's mirrored copy.
const KEY_PALM: int = 100
const KEY_INDUSTRY: int = 200
const KEY_RACK: int = 300
const KEY_FLAG: int = 400
const KEY_MASK: int = 500
const KEY_SWAG: int = 600
const KEY_ALCOVE: int = 10000
const MIRRORED: int = 1000000

## One shack's layout, computed from its lot run alone.
class Shack:
	var side: int
	var id: int
	var b0: float
	var b1: float
	var seed: int
	var storeys: int
	var height: float
	var roof: int
	var bamboo: Color
	## Recessed verandas: {u0, u1, y0, y1, kind, tv}.
	var alcoves: Array[Dictionary] = []
	## Roof and wall items: {kind, at, ...}, each built by the chunk holding its `at`.
	var items: Array[Dictionary] = []

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: BeachSkin:
	get:
		return _skin.get_ref() as BeachSkin
var _skin: WeakRef
var _shacks: Dictionary = {}
var _templates: Dictionary = {}
var _strings: Dictionary = {}
## The skin's shared materials, looked up once (every lookup through the skin costs microseconds a call).
var _solid: ShaderMaterial
var _glow: ShaderMaterial
var _feed: ShaderMaterial
## The wall gaps noted so far, by side (note_gaps): masts for a string of lights never stand over one.
var _gaps: Dictionary = {-1: [], 1: []}


func _init(p_skin: BeachSkin) -> void:
	_skin = weakref(p_skin)


## Looks the skin's materials up once.
func _prepare() -> void:
	if _solid == null:
		_solid = skin.solid_material()
		_glow = skin.glow_material()
		_feed = skin.feed_material()


## The wall gaps TrackBuilder is about to dress near a chunk (BeachSkin.note_wall_gaps): remembered, so the
## strings of lights across the street (drawn with the left wall) skip a mast over a gap on either wall.
func note_gaps(side: int, gaps: Array[Vector2]) -> void:
	var list: Array = _gaps[side]
	for g: Vector2 in gaps:
		if not list.has(g):
			list.append(g)
	if list.size() > 64:
		list.pop_front()


## Whether a gap on either wall lies within `margin` metres of track distance `d`.
func gap_near(d: float, margin: float) -> bool:
	for side: int in [-1, 1]:
		for g: Vector2 in _gaps[side]:
			if d > g.x - margin and d < g.y + margin:
				return true
	return false


## Adds the shacks of one wall side between two track distances.
func build(batch: MeshBatch, side: int, face_x: float, start: float, end: float) -> void:
	_prepare()
	var lot: float = skin.lot_length
	var span: Vector2i = lot_run(side, floori(start / lot))
	while span.x * lot < end:
		_shack(batch, shack(side, span), face_x, start, end)
		span = lot_run(side, span.y + 1)


## The lots of the run covering lot `lot_index` on `side`: one to three lots a shack.
func lot_run(side: int, lot_index: int) -> Vector2i:
	return MeshKit.lot_run(side, lot_index, 0.5, 3, 7)


## The shack on `side` covering the lot run `span` (cached: every chunk asks for its neighbours).
func shack(side: int, span: Vector2i) -> Shack:
	var key := Vector3i(side, span.x, span.y)
	var found: Shack = _shacks.get(key)
	if found != null:
		return found
	if _shacks.size() > 512:
		_shacks.clear()
	var b := Shack.new()
	var id: int = span.x
	var lot: float = skin.lot_length
	b.side = side
	b.id = id
	b.b0 = span.x * lot
	b.b1 = (span.y + 1) * lot
	# Whole numbers: the wall shader rounds the seed before using it.
	b.seed = MeshKit.hash_i(side, id, 11) % 997
	var r: float = MeshKit.hash01(side, id, 1)
	b.storeys = 2 if r < skin.low_share else (3 if r < skin.low_share + skin.mid_share else 4)
	b.height = skin.decor_min_height + 0.4 + float(b.storeys - 2) * skin.storey_height
	b.roof = Roof.THATCH if MeshKit.hash01(side, id, 2) < skin.thatch_share else Roof.TIN
	b.bamboo = skin.bamboo_colors[MeshKit.hash_i(side, id, 9) % skin.bamboo_colors.size()]
	_place_alcoves(b)
	_place_items(b)
	_shacks[key] = b
	return b


## The recessed verandas of a shack of three or four storeys (veranda_share of them): one, or two on a long
## one, each 4-6 m wide on the first or second upper storey, clear of the shack's ends and of each other.
func _place_alcoves(b: Shack) -> void:
	if b.storeys < 3 or MeshKit.hash01(b.side, b.id, 3) >= skin.veranda_share:
		return
	var length: float = b.b1 - b.b0
	var count: int = 2 if length >= 24.0 and MeshKit.hash01(b.side, b.id, 4) < 0.6 else 1
	for i: int in count:
		var w: float = 4.0 + float(MeshKit.hash_i(b.side, b.id, 5 + i) % 3)
		var lo: float = b.b0 + length * float(i) / float(count) + 1.5
		var hi: float = b.b0 + length * float(i + 1) / float(count) - 1.5 - w
		if hi < lo:
			continue
		var u0: float = lerpf(lo, hi, MeshKit.hash01(b.side, b.id, 7 + i))
		var level: int = (MeshKit.hash_i(b.side, b.id, 9 + i) + i) % (b.storeys - 2)
		var y0: float = skin.decor_min_height + float(level) * skin.storey_height
		var kind: int = MeshKit.hash_i(b.side, b.id, 13 + i) % 3
		b.alcoves.append({"u0": u0, "u1": u0 + w, "y0": y0, "y1": y0 + ALCOVE_HEIGHT, "kind": kind,
			"tv": kind == Verandah.BAR and skin.shows_feed(b.seed, 40 + i, skin.feed_tv_share)})


## What stands on a shack's roof and hangs on its face: one station every STATION metres along it, each
## with a roll for what stands there (a neon sign, a billboard, a palm, industry, a surfboard rack, a flag,
## or nothing), a tiki mask or a swag of lights on the face where its upper storeys are tall enough.
func _place_items(b: Shack) -> void:
	var length: float = b.b1 - b.b0
	var stations: int = maxi(floori(length / STATION), 1)
	var billboard: bool = false
	for j: int in stations:
		var at: float = b.b0 + (float(j) + 0.5) * length / float(stations)
		var k: int = MeshKit.hash_i(b.side, b.id * 16 + j, 21)
		var r: float = MeshKit.hash01(b.side, b.id * 16 + j, 22)
		var back: float = 2.8 + 3.0 * MeshKit.hash01(b.side, b.id * 16 + j, 23)
		var jitter: float = (MeshKit.hash01(b.side, b.id * 16 + j, 24) - 0.5) * 1.6
		var item: Dictionary = {"at": at + jitter, "variant": k % 8, "seed": k % 97}
		if r < 0.13 * skin.sign_share / 0.55:
			item["kind"] = &"sign"
			item["back"] = 0.7 + 0.6 * MeshKit.hash01(b.side, b.id * 16 + j, 25)
			item["glyph"] = k % MeshKit.GLYPH_COUNT
			item["tube"] = (k >> 4) % 3
			item["emblem"] = skin.carries_emblem(b.seed, 60 + j)
		elif r < 0.21 and not billboard and length >= 12.0 and stations >= 2:
			billboard = true
			item["kind"] = &"billboard"
			item["back"] = 0.9
			item["feed"] = skin.shows_feed(b.seed, 50 + j, skin.feed_board_share)
			item["glyph"] = k % 6
			item["emblem"] = not item["feed"] and skin.carries_emblem(b.seed, 70 + j)
		elif r < 0.21 + 0.24 * skin.palm_share:
			item["kind"] = &"palm"
			item["back"] = back
		elif r < 0.45 + 0.3 * skin.industry_share:
			item["kind"] = &"industry"
			item["back"] = back
			item["industry"] = (k >> 3) % 4
		elif r < 0.78:
			item["kind"] = &"rack" if k % 3 != 0 else &"flag"
			item["back"] = 1.9
		else:
			continue
		b.items.append(item)
	# On the face: tiki masks and swags of lights, where the storeys are tall enough for decoration.
	if b.storeys >= 3:
		var y: float = skin.decor_min_height + 0.5
		var j: int = 0
		var u: float = b.b0 + 2.0
		while u < b.b1 - 1.5:
			var r: float = MeshKit.hash01(b.side, b.id * 16 + j, 31)
			if r < 0.2 and not _in_alcove(b, u, 0.8):
				b.items.append({"kind": &"mask", "at": u, "y": y + 0.9 * MeshKit.hash01(b.side, b.id, 32 + j), "variant": j % 4})
			elif r < 0.5 and u + 3.0 < b.b1 - 0.5:
				b.items.append({"kind": &"swag", "at": u + 1.5, "y": b.height - 0.7, "variant": j % 3})
			u += 3.0
			j += 1


func _in_alcove(b: Shack, u: float, margin: float) -> bool:
	for a: Dictionary in b.alcoves:
		if u > float(a["u0"]) - margin and u < float(a["u1"]) + margin:
			return true
	return false


# --- A shack ----------------------------------------------------------------------------------

func _shack(batch: MeshBatch, b: Shack, face_x: float, start: float, end: float) -> void:
	var u0: float = maxf(b.b0, start)
	var u1: float = minf(b.b1, end)
	if u1 <= u0 + 0.001:
		return
	var solid: MeshLayer = batch.layer(_solid)
	var side: int = b.side
	var param: float = float(b.seed * 8)
	# The band: flush, closed, solid-looking, floor to band_top.
	_wall(solid, side, face_x, u0, u1, 0.0, skin.band_top, b.bamboo, param)
	# The upper storeys, with the recessed verandas' openings left out.
	var holes: Array[Rect2] = []
	for a: Dictionary in b.alcoves:
		holes.append(Rect2(float(a["u0"]), float(a["y0"]), float(a["u1"]) - float(a["u0"]), ALCOVE_HEIGHT))
	for piece: PackedFloat64Array in open_rects(u0, u1, skin.band_top, b.height, holes):
		_wall(solid, side, face_x, piece[0], piece[1], piece[2], piece[3], b.bamboo, param)
	# Its near end, where it stands above a lower neighbour, and its roof.
	if b.b0 >= start and b.b0 < end:
		_near_end(solid, b, face_x)
	_roof(solid, b, face_x, u0, u1)
	for a: Dictionary in b.alcoves:
		var mid: float = (float(a["u0"]) + float(a["u1"])) * 0.5
		if mid >= start and mid < end:
			_alcove(batch, b, a, face_x)
	for item: Dictionary in b.items:
		var at: float = item["at"]
		if at >= start and at < end:
			_item(batch, b, item, face_x)


## A flush face of the wall (the plane x = face_x), facing the street, from track distance u0 to u1 and
## height y0 to y1, in `pattern` with `param`.
func _wall(layer: MeshLayer, side: int, face_x: float, u0: float, u1: float, y0: float, y1: float, color: Color,
		param: float, pattern: int = MeshKit.PAT_BEACH_WALL) -> void:
	if u1 <= u0 + 0.0005 or y1 <= y0 + 0.0005:
		return
	if side < 0:
		layer.rect(Vector3(face_x, y0, -u0), Vector3(0, 0, -(u1 - u0)), Vector3(0, y1 - y0, 0), color, 0.0, pattern,
			Vector2(u0, y0), Vector2(u1, y1), param)
	else:
		layer.rect(Vector3(face_x, y0, -u1), Vector3(0, 0, u1 - u0), Vector3(0, y1 - y0, 0), color, 0.0, pattern,
			Vector2(u1, y0), Vector2(u0, y1), param)


## The pieces of the face [u0, u1] x [y0, y1] left once `holes` (Rect2 over (track distance, height)) are taken
## out, as [u0, u1, y0, y1] (plain floats, so neighbouring pieces share their edges exactly). Without a hole
## there, the whole face.
static func open_rects(u0: float, u1: float, y0: float, y1: float, holes: Array[Rect2]) -> Array[PackedFloat64Array]:
	var out: Array[PackedFloat64Array] = []
	var cuts: Array[Rect2] = []
	for h: Rect2 in holes:
		if h.position.x < u1 and h.end.x > u0 and h.position.y < y1 and h.end.y > y0:
			cuts.append(h)
	cuts.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.x < b.position.x)
	var at: float = u0
	for h: Rect2 in cuts:
		var h0: float = maxf(h.position.x, u0)
		var h1: float = minf(h.end.x, u1)
		if h0 > at:
			out.append(PackedFloat64Array([at, h0, y0, y1]))
		var lo: float = maxf(h.position.y, y0)
		var hi: float = minf(h.end.y, y1)
		if lo > y0:
			out.append(PackedFloat64Array([h0, h1, y0, lo]))
		if hi < y1:
			out.append(PackedFloat64Array([h0, h1, hi, y1]))
		at = maxf(at, h1)
	if u1 > at:
		out.append(PackedFloat64Array([at, u1, y0, y1]))
	return out


## A shack's near end (facing the runner), from the floor to its roofline and, under a thatched roof, the
## gable: seen above a lower neighbour.
func _near_end(solid: MeshLayer, b: Shack, face_x: float) -> void:
	var side: int = b.side
	var x_back: float = face_x + side * END_DEPTH
	var z: float = -b.b0
	var x0: float = minf(face_x, x_back)
	solid.rect(Vector3(x0, 0, z), Vector3(END_DEPTH, 0, 0), Vector3(0, b.height, 0), b.bamboo, 0.0, MeshKit.PAT_BEACH_WALL,
		Vector2(x0, 0), Vector2(x0 + END_DEPTH, b.height), float(b.seed * 8))
	if b.roof == Roof.THATCH:
		var ridge_x: float = face_x + side * ROOF_DEPTH
		var eave_x: float = face_x - side * (EAVE_OUT if b.height >= OVER_STREET_MIN else 0.0)
		var thatch: Color = skin.thatch_color
		# The gable: the roof's section, a triangle from the eave up to the ridge and down to the roofline.
		var fringe: float = 0.3 if b.height >= OVER_STREET_MIN else 0.0
		_quad(solid, Vector3(eave_x, b.height, z), Vector3(eave_x, b.height + fringe, z), Vector3(ridge_x, b.height + ROOF_RISE, z),
			Vector3(ridge_x, b.height, z), Vector3(0, 0, 1), thatch, MeshKit.PAT_BEACH_THATCH, 0.0)


## A shack's roof between track distances u0 and u1: a thatched slope up to the ridge, with the eave's fringe
## (out over the street only at OVER_STREET_MIN or higher), or the flat tin roof's flush parapet.
func _roof(solid: MeshLayer, b: Shack, face_x: float, u0: float, u1: float) -> void:
	var side: int = b.side
	if b.roof == Roof.TIN:
		_wall(solid, side, face_x, u0, u1, b.height, b.height + 0.5, b.bamboo * 0.85, float(b.seed * 8) + 1.0)
		return
	var over: bool = b.height >= OVER_STREET_MIN
	var eave_x: float = face_x - side * (EAVE_OUT if over else 0.0)
	var ridge_x: float = face_x + side * ROOF_DEPTH
	var ya: float = b.height
	var yb: float = b.height + ROOF_RISE
	var thatch: Color = skin.thatch_color
	var out := Vector3(-side, 1.0, 0.0)
	# Over the street the eave's fringe (a thick edge of thatch facing the street) stands on the eave line at
	# the roofline, its top 0.3 m up, and the slope runs on from there; flush, the slope starts at the roofline.
	var fringe: float = 0.3 if over else 0.0
	_quad(solid, Vector3(eave_x, ya + fringe, -u0), Vector3(ridge_x, yb, -u0), Vector3(ridge_x, yb, -u1), Vector3(eave_x, ya + fringe, -u1),
		out, thatch, MeshKit.PAT_BEACH_THATCH, 0.0)
	if over:
		_quad(solid, Vector3(eave_x, ya, -u0), Vector3(eave_x, ya + fringe, -u0), Vector3(eave_x, ya + fringe, -u1), Vector3(eave_x, ya, -u1),
			Vector3(-side, 0.0, 0.0), thatch * 0.85, MeshKit.PAT_BEACH_THATCH, 0.0)
		# Its underside, dark, seen from the street below.
		_quad(solid, Vector3(face_x, ya, -u0), Vector3(eave_x, ya, -u0), Vector3(eave_x, ya, -u1), Vector3(face_x, ya, -u1),
			Vector3(0.0, -1.0, 0.0), skin.thatch_dark_color, MeshKit.PAT_BEACH_THATCH, 0.0)


## A four-cornered face wound to face `outward` (Godot's front faces wind clockwise; MeshLayer.quad).
func _quad(layer: MeshLayer, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3, color: Color, pattern: int = 0,
		param: float = 0.0, glow: float = 0.0) -> void:
	if (b - a).cross(c - a).dot(outward) > 0.0:
		layer.quad(a, d, c, b, color, glow, pattern, param)
	else:
		layer.quad(a, b, c, d, color, glow, pattern, param)


# --- Items --------------------------------------------------------------------------------------

## The transform that places a template (see `_template`) at track distance `at` and height `y` on the wall whose
## face is at face_x: a translation only (the right wall's templates are mirrored once, when first asked for).
static func place(face_x: float, at: float, y: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(face_x, y, -at))


func _item(batch: MeshBatch, b: Shack, item: Dictionary, face_x: float) -> void:
	var solid: MeshLayer = batch.layer(_solid)
	var at: float = item["at"]
	var side: int = b.side
	match StringName(item["kind"]):
		&"palm":
			solid.append(_template(KEY_PALM + int(item["variant"]) % 3, side), place(face_x + side * float(item["back"]), at, b.height - 1.5))
		&"industry":
			solid.append(_template(KEY_INDUSTRY + int(item["industry"]) * 8 + int(item["variant"]), side),
				place(face_x + side * float(item["back"]), at, b.height - 0.1))
		&"rack":
			solid.append(_template(KEY_RACK + int(item["variant"]) % 3, side), place(face_x + side * float(item["back"]), at, b.height))
		&"flag":
			solid.append(_template(KEY_FLAG + int(item["variant"]) % 4, side), place(face_x + side * float(item["back"]), at, b.height))
		&"mask":
			solid.append(_template(KEY_MASK + int(item["variant"]), side), place(face_x, at, float(item["y"])))
		&"swag":
			_swag(batch, side, face_x, at, float(item["y"]), int(item["variant"]))
		&"sign":
			_sign(batch, b, item, face_x)
		&"billboard":
			_billboard(batch, b, item, face_x)


## The board facing the runner (+z) at track distance `z_at` standing on posts on the roof, its box x range
## (world) [x0, x1] and y range [y0, y1]: the dark timber frame and two posts down to the roof at `roof_y`.
func _board_frame(solid: MeshLayer, x0: float, x1: float, y0: float, y1: float, z: float, roof_y: float) -> void:
	var dark: Color = skin.timber_color * 0.55
	solid.box(Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, z - 0.06), Vector3(x1 - x0 + 0.24, y1 - y0 + 0.24, 0.12), dark, 0.0,
		MeshKit.PAT_BEACH_TIMBER, MeshKit.ALL_FACES & ~(MeshKit.FACE_PZ | MeshKit.FACE_NZ), MeshKit.beach_timber_param(1, 1, 5))
	for x: float in [x0 + 0.3, x1 - 0.3]:
		if y0 - roof_y > 0.1:
			solid.box(Vector3(x, (y0 + roof_y) * 0.5, z - 0.1), Vector3(0.12, y0 - roof_y, 0.12), skin.post_color, 0.0,
				MeshKit.PAT_BEACH_TIMBER, MeshKit.ALL_FACES & ~MeshKit.FACE_NY, MeshKit.beach_timber_param(0, 0, 9))


## A neon silhouette sign on a roof, set back from the face, facing the runner: a dark board with a glyph's
## outline and a frame glowing in a tube colour (violet, blue or warm white), a soft halo behind; on some, the
## cult's emblem as a warm-white badge on a board of its own under it.
func _sign(batch: MeshBatch, b: Shack, item: Dictionary, face_x: float) -> void:
	var solid: MeshLayer = batch.layer(_solid)
	var side: int = b.side
	var info: Dictionary = sign_spec(b, item, face_x)
	var x0: float = info["x0"]
	var w: float = info["width"]
	var h: float = info["height"]
	var y0: float = info["y0"]
	var z: float = -float(item["at"])
	var tube: Color = info["tube"]
	var roof_y: float = b.height
	_board_frame(solid, x0, x0 + w, y0, y0 + h, z, roof_y)
	solid.rect(Vector3(x0, y0, z), Vector3(w, 0, 0), Vector3(0, h, 0), tube, skin.neon_glow, MeshKit.PAT_BEACH_NEON,
		Vector2.ZERO, Vector2(w, h), MeshKit.beach_neon_param(int(item["glyph"]), w, h))
	var glow: MeshLayer = batch.layer(_glow)
	glow.rect(Vector3(x0 - 0.5, y0 - 0.5, z + 0.1), Vector3(w + 1.0, 0, 0), Vector3(0, h + 1.0, 0), tube, 0.16, MeshKit.SHAPE_RADIAL)
	if item.get("emblem", false):
		var e: float = skin.emblem_min_size
		var m: float = EMBLEM_MARGIN
		var half: float = e * m * 0.5
		var c := Vector3(x0 + w * 0.5, roof_y + 0.35 + half, z + 0.02)
		_mark(solid, c, e, skin.emblem_color(), skin.emblem_glow)


## A sign's layout, from its plan and the wall's face: x0 (the left edge, world), width, height, y0, tube (the
## neon's colour), and its emblem's centre (a Vector3, or none).
func sign_spec(b: Shack, item: Dictionary, face_x: float) -> Dictionary:
	var side: int = b.side
	var w: float = 2.6
	var h: float = 1.9
	var back: float = float(item["back"])
	var x0: float = face_x - w - back if side < 0 else face_x + back
	var lift: float = 2.0 if item.get("emblem", false) else 0.8
	var tubes: Array[Color] = [skin.neon_violet, skin.neon_blue, skin.neon_white]
	return {"x0": x0, "width": w, "height": h, "y0": b.height + lift, "tube": tubes[int(item["tube"])]}


## A billboard on a roof, set back from the face, facing the runner: a frame with the cult's feed playing in it,
## or a painted wordless poster (and on some the cult's emblem as a warm-white badge in its lower corner).
func _billboard(batch: MeshBatch, b: Shack, item: Dictionary, face_x: float) -> void:
	var solid: MeshLayer = batch.layer(_solid)
	var spec: Dictionary = billboard_spec(b, item, face_x)
	var x0: float = spec["x0"]
	var w: float = spec["width"]
	var h: float = spec["height"]
	var y0: float = spec["y0"]
	var z: float = -float(item["at"])
	_board_frame(solid, x0, x0 + w, y0, y0 + h, z, b.height)
	if item["feed"]:
		CultFeed.screen(batch.layer(_feed), Vector3(x0, y0, z + 0.02), Vector3(w, 0, 0), Vector3(0, h, 0),
			skin.feed_board_brightness, b.seed)
		return
	solid.rect(Vector3(x0, y0, z + 0.02), Vector3(w, 0, 0), Vector3(0, h, 0), skin.cream_color, 0.0, MeshKit.PAT_BEACH_PAINT,
		Vector2.ZERO, Vector2(w, h), MeshKit.beach_art_param(int(item["glyph"]), w, h, int(item["seed"])))
	if item.get("emblem", false):
		var e: float = float(spec["emblem"])
		var half: float = e * EMBLEM_MARGIN * 0.5
		_mark(solid, Vector3(x0 + w - half - 0.15, y0 + half + 0.15, z + 0.03), e, skin.emblem_color(), skin.emblem_glow)


## A billboard's layout: x0 (the left edge, world), width, height, y0 (its bottom) and, for one with the
## emblem, the mark's size.
func billboard_spec(b: Shack, item: Dictionary, face_x: float) -> Dictionary:
	var side: int = b.side
	var w: float = 4.4
	var h: float = 2.5
	var back: float = float(item["back"])
	var x0: float = face_x - w - back if side < 0 else face_x + back
	return {"x0": x0, "width": w, "height": h, "y0": b.height + 1.2, "emblem": maxf(skin.emblem_min_size, h * 0.26)}


## The cult's emblem `e` metres across centred on `c`, facing +z, in `color` (glowing at `glow`, or unlit paint
## at 0) on its own dark square (MeshKit.PAT_CULT_MARK).
func _mark(solid: MeshLayer, c: Vector3, e: float, color: Color, glow_amount: float) -> void:
	var half: float = e * EMBLEM_MARGIN * 0.5
	var m: float = EMBLEM_MARGIN
	solid.rect(c - Vector3(half, half, 0.0), Vector3(half * 2.0, 0, 0), Vector3(0, half * 2.0, 0), color, glow_amount,
		MeshKit.PAT_CULT_MARK, Vector2(-m, -m), Vector2(m, m))


## A swag of string lights along the face (3 m long, hung from two hooks), its bulbs warm white, blue or violet.
func _swag(batch: MeshBatch, side: int, face_x: float, at: float, y: float, variant: int) -> void:
	batch.layer(_solid).append(_template(KEY_SWAG + variant, side), place(face_x, at, y))


# --- Verandas -----------------------------------------------------------------------------------

## A recessed upper veranda: its inside (a floor, back and side walls, a ceiling, a counter with bottles and
## paper lanterns for a bar; low seats for a lounge; boards and chairs for a deck) behind a bamboo railing
## flush with the face, and on a bar with a TV the cult's feed playing on the back wall.
func _alcove(batch: MeshBatch, b: Shack, a: Dictionary, face_x: float) -> void:
	var width: float = float(a["u1"]) - float(a["u0"])
	var mid: float = (float(a["u0"]) + float(a["u1"])) * 0.5
	batch.layer(_solid).append(_template(KEY_ALCOVE + int(a["kind"]) * 100 + roundi(width - 4.0) * 10 + b.seed % 4, b.side),
		place(face_x, mid, float(a["y0"])))
	if a["tv"]:
		var spec: Dictionary = tv_spec(b, a, face_x)
		CultFeed.wall_screen(batch.layer(_feed), b.side, float(spec["x"]), float(spec["d0"]), float(spec["width"]),
			float(spec["y0"]), float(spec["height"]), skin.feed_tv_brightness, b.seed)


## Where an alcove's TV stands: on the back wall (x), from track distance d0 over `width`, from height y0
## over `height`, and its middle (center, world).
func tv_spec(b: Shack, a: Dictionary, face_x: float) -> Dictionary:
	var mid: float = (float(a["u0"]) + float(a["u1"])) * 0.5
	var w: float = 1.6
	var h: float = 0.9
	var x: float = face_x + b.side * (ALCOVE_DEPTH - 0.04)
	var y0: float = float(a["y0"]) + 1.55
	return {"x": x, "d0": mid - w * 0.5, "width": w, "height": h, "y0": y0,
		"center": Vector3(x, y0 + h * 0.5, -mid)}


# --- Strings of lights across the street ------------------------------------------------------------

## Strings of lights across the street between masts on both walls, one slot every string_spacing metres (a
## string_share of them built), no lower than string_height, with bunting on some; built with the left wall.
func overhead(batch: MeshBatch, wall: float, start: float, end: float) -> void:
	_prepare()
	var spacing: float = skin.string_spacing
	var k: int = floori(start / spacing)
	while float(k) * spacing < end:
		var spec: Dictionary = string_spec(k)
		if not spec.is_empty() and float(spec["at"]) >= start and float(spec["at"]) < end:
			_string(batch, spec, wall)
		k += 1


## The string in slot `k`: its distance (at), its anchors' height (y: the lowest of its bulbs and bunting stay
## above OVER_STREET_MIN), its sag and tilt (from a few quantized steps, so a few templates serve every string),
## whether it is bunting, or empty if the slot has none (or a mast would stand over a wall gap).
func string_spec(k: int) -> Dictionary:
	if MeshKit.hash01(k, 3, 81) >= skin.string_share:
		return {}
	var at: float = (float(k) + 0.2 + 0.6 * MeshKit.hash01(k, 4, 81)) * skin.string_spacing
	if gap_near(at, 3.0):
		return {}
	var y: float = skin.string_height + 1.15 + 2.0 * MeshKit.hash01(k, 5, 81)
	var sag_i: int = MeshKit.hash_i(k, 6, 81) % 3
	var tilt_i: int = MeshKit.hash_i(k, 8, 81) % 5
	return {"at": at, "y": y, "sag_i": sag_i, "tilt_i": tilt_i, "bunting": MeshKit.hash01(k, 7, 81) < 0.35}


func _string(batch: MeshBatch, spec: Dictionary, wall: float) -> void:
	var solid: MeshLayer = batch.layer(_solid)
	var at: float = spec["at"]
	var y: float = spec["y"]
	var tilt: float = float(int(spec["tilt_i"]) - 2) * 0.3
	var z: float = -at
	# The masts: from the roofline up to the anchor, just behind the face's plane; a hook on the face of a shack
	# that is already taller than the anchor.
	for side: int in [-1, 1]:
		var b: Shack = shack(side, lot_run(side, floori(at / skin.lot_length)))
		var ya: float = y + tilt * float(side) * 0.5
		var x: float = float(side) * (wall + STRING_BACK)
		if ya > b.height:
			solid.box(Vector3(x, (b.height + ya) * 0.5, z), Vector3(MAST, ya - b.height, MAST), skin.post_color, 0.0,
				MeshKit.PAT_BEACH_TIMBER, MeshKit.ALL_FACES & ~MeshKit.FACE_NY, MeshKit.beach_timber_param(0, 0, 4))
		else:
			solid.box(Vector3(float(side) * (wall + 0.02), ya, z), Vector3(0.1, 0.12, 0.12), skin.post_color)
	solid.append(_string_template(wall, int(spec["sag_i"]), int(spec["tilt_i"]), bool(spec["bunting"])), Transform3D(Basis.IDENTITY, Vector3(0, y, z)))


## A string of lights or bunting across a street whose walls stand at ±wall: its anchors at x = ±(wall +
## STRING_BACK), at heights ∓tilt/2 (the template's own height 0), sagging `sag` at the middle.
func _string_template(wall: float, sag_i: int, tilt_i: int, bunting: bool) -> MeshLayer:
	var key: int = roundi(wall * 10.0) * 100 + sag_i * 20 + tilt_i * 2 + (1 if bunting else 0)
	var found: MeshLayer = _strings.get(key)
	if found != null:
		return found
	var t := MeshLayer.new()
	var sag: float = 0.9 + 0.2 * float(sag_i)
	var tilt: float = float(tilt_i - 2) * 0.3
	var a := Vector3(-(wall + STRING_BACK), -tilt * 0.5, 0.0)
	var c := Vector3(wall + STRING_BACK, tilt * 0.5, 0.0)
	var count: int = 14
	var prev: Vector3 = a
	var wire: Color = skin.timber_color * 0.5
	for i: int in range(1, count + 1):
		var f: float = float(i) / float(count)
		var p: Vector3 = a.lerp(c, f)
		p.y -= sag * 4.0 * f * (1.0 - f)
		# The wire: a thin ribbon facing the runner (the street's axis), seen across the street.
		t.quad(prev + Vector3(0, 0.02, 0), p + Vector3(0, 0.02, 0), p - Vector3(0, 0.02, 0), prev - Vector3(0, 0.02, 0), wire)
		if bunting:
			if i % 2 == 0 and i < count:
				var col: Color = skin.flag_colors[(i / 2 + sag_i) % skin.flag_colors.size()]
				t.quad(p, p + Vector3(0.2, 0.0, 0.0), p + Vector3(0.1, -0.45, 0.0), p + Vector3(0.1, -0.45, 0.0), col, 0.0)
				t.quad(p, p + Vector3(0.1, -0.45, 0.0), p + Vector3(0.1, -0.45, 0.0), p + Vector3(0.2, 0.0, 0.0), col * 0.85, 0.0)
		elif i < count:
			_bulb_cross(t, p + Vector3(0, -0.1, 0), 0.07, _bulb_color(i + tilt_i), skin.lamp_glow)
		prev = p
	_strings[key] = t
	return t


## A bulb as two crossed quads (one facing +x, one facing +z), `half` its half size: cheap, and lit from
## wherever it is seen along the street or across it.
func _bulb_cross(layer: MeshLayer, c: Vector3, half: float, color: Color, glow_amount: float) -> void:
	layer.quad(c + Vector3(0, half, half), c + Vector3(0, half, -half), c + Vector3(0, -half, -half), c + Vector3(0, -half, half), color, glow_amount)
	layer.quad(c + Vector3(-half, half, 0), c + Vector3(half, half, 0), c + Vector3(half, -half, 0), c + Vector3(-half, -half, 0), color, glow_amount)


## The colour of the bulb numbered `i` on a string: warm white, blue or violet (decorative glows only).
func _bulb_color(i: int) -> Color:
	match posmod(i, 5):
		1:
			return skin.neon_blue
		3:
			return skin.neon_violet
	return skin.lamp_color


# --- Listings (BeachSkin's feed_boards and cult_emblems) ----------------------------------------------

## The screens playing the feed (BeachSkin.feed_boards()) with middles in [start, end).
func feed_boards(side: int, face_x: float, start: float, end: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lot: float = skin.lot_length
	var span: Vector2i = lot_run(side, floori(start / lot))
	while span.x * lot < end:
		var b: Shack = shack(side, span)
		for a: Dictionary in b.alcoves:
			var mid: float = (float(a["u0"]) + float(a["u1"])) * 0.5
			if a["tv"] and mid >= start and mid < end:
				var spec: Dictionary = tv_spec(b, a, face_x)
				out.append({"side": side, "at": mid, "kind": &"deck_tv", "width": spec["width"], "height": spec["height"],
					"center": spec["center"]})
		for item: Dictionary in b.items:
			if StringName(item["kind"]) == &"billboard" and item["feed"] and float(item["at"]) >= start and float(item["at"]) < end:
				var spec: Dictionary = billboard_spec(b, item, face_x)
				out.append({"side": side, "at": item["at"], "kind": &"roof_board", "width": spec["width"], "height": spec["height"],
					"center": Vector3(float(spec["x0"]) + float(spec["width"]) * 0.5, float(spec["y0"]) + float(spec["height"]) * 0.5,
						-float(item["at"]) + 0.02)})
		span = lot_run(side, span.y + 1)
	return out


## The cult's emblems (BeachSkin.cult_emblems()) with middles in [start, end).
func emblems(side: int, face_x: float, start: float, end: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lot: float = skin.lot_length
	var span: Vector2i = lot_run(side, floori(start / lot))
	while span.x * lot < end:
		var b: Shack = shack(side, span)
		for item: Dictionary in b.items:
			var at: float = item["at"]
			if at < start or at >= end or not item.get("emblem", false):
				continue
			if StringName(item["kind"]) == &"sign":
				var s: Dictionary = sign_spec(b, item, face_x)
				var half: float = skin.emblem_min_size * EMBLEM_MARGIN * 0.5
				out.append({"side": side, "at": at, "kind": &"sign", "size": skin.emblem_min_size,
					"center": Vector3(float(s["x0"]) + float(s["width"]) * 0.5, b.height + 0.35 + half, -at + 0.02)})
			elif StringName(item["kind"]) == &"billboard":
				var s: Dictionary = billboard_spec(b, item, face_x)
				var e: float = s["emblem"]
				var half: float = e * EMBLEM_MARGIN * 0.5
				out.append({"side": side, "at": at, "kind": &"billboard", "size": e,
					"center": Vector3(float(s["x0"]) + float(s["width"]) - half - 0.15, float(s["y0"]) + half + 0.15, -at + 0.03)})
		span = lot_run(side, span.y + 1)
	return out


# --- Cached templates (template space: the face at x = 0, the street at +x) ------------------------------

## A palm tree: a leaning, ringed trunk and a crown of drooping fronds, its foot at the origin, standing
## (variant 0-2) 8.5, 7 or 10 m to its crown. Its trunk is inside the shack; the crown's fronds stay behind the
## face (a palm set back so far that its leaves never reach out over the street).
func palm_template(variant: int, side: int = -1) -> MeshLayer:
	return _template(KEY_PALM + variant, side)


func _build_palm(variant: int) -> MeshLayer:
	var t := MeshLayer.new()
	var heights: Array[float] = [8.5, 7.0, 10.0]
	var leans: Array[float] = [0.7, -0.5, 0.2]
	var hgt: float = heights[variant]
	var lean: float = leans[variant]
	var segs: int = 5
	for i: int in segs:
		var f0: float = float(i) / float(segs)
		var f1: float = float(i + 1) / float(segs)
		var r0: float = lerpf(0.26, 0.14, f0)
		var a := Vector3(lean * f0 * f0, f0 * hgt, 0.0)
		var axis := Vector3(lean * f1 * f1, f1 * hgt, 0.0) - a
		# A segment of the trunk: a prism along its axis, its rings a pale band every 0.3 m (the timber pattern).
		t.prism_xform(Transform3D(Basis(Vector3(r0, 0, 0), axis, Vector3(0, 0, r0)), a), 6, skin.trunk_color, 0.0,
			MeshKit.PAT_BEACH_TIMBER, false, MeshKit.beach_timber_param(0, 2, variant))
	var crown := Vector3(lean, hgt, 0.0)
	# Fronds: arching blades drooping from the crown, each a strip of quads seen from below (the crown is always
	# far above the runner's eye).
	var fronds: int = 9
	for i: int in fronds:
		var ang: float = TAU * (float(i) + 0.5 * float(variant)) / float(fronds) + 0.2 * float(variant)
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var side := Vector3(-dir.z, 0.0, dir.x)
		var col: Color = skin.frond_colors[(i + variant) % skin.frond_colors.size()]
		var reach: float = 2.5 + 0.5 * float(i % 3)
		var pts: Array[Vector3] = [crown + Vector3(0, 0.1, 0), crown + dir * reach * 0.38 + Vector3(0, 0.62, 0),
			crown + dir * reach * 0.72 + Vector3(0, 0.55, 0), crown + dir * reach + Vector3(0, -0.45, 0)]
		var widths: Array[float] = [0.18, 0.5, 0.42, 0.04]
		for k: int in 3:
			var a0: Vector3 = pts[k] - side * widths[k]
			var a1: Vector3 = pts[k] + side * widths[k]
			var b0: Vector3 = pts[k + 1] - side * widths[k + 1]
			var b1: Vector3 = pts[k + 1] + side * widths[k + 1]
			_quad(t, a0, b0, b1, a1, Vector3.DOWN, col)
	return t


## The black industrial structures behind the shacks (the reference's rooftop tanks and chimneys), foot at
## the origin: kind 0 a tank, 1 a water tower, 2 a chimney, 3 a dish and antennas; variant 0-7 varies sizes.
func industry_template(kind: int, variant: int, side: int = -1) -> MeshLayer:
	return _template(KEY_INDUSTRY + kind * 8 + variant, side)


func _build_industry(kind: int, variant: int) -> MeshLayer:
	var t := MeshLayer.new()
	var steel: Color = skin.steel_color
	var rust: Color = skin.steel_rust_color
	var scale: float = 0.85 + 0.3 * float(variant) / 7.0
	match kind:
		0:
			var r: float = 2.0 * scale
			var h: float = 6.0 + 3.0 * float(variant % 3)
			t.prism(Vector3.ZERO, r, h, 10, steel, 0.0, MeshKit.PAT_BEACH_STEEL, false, 0.0)
			t.prism(Vector3(0, h, 0), r, 0.1, 10, steel * 1.2, 0.0, MeshKit.PAT_BEACH_STEEL, true, 0.0)
			t.prism(Vector3(0, h + 0.1, 0), r * 0.55, 0.45, 10, steel * 1.2, 0.0, MeshKit.PAT_BEACH_STEEL, true, 0.0)
			t.prism(Vector3(0, h * 0.82, 0), r * 1.05, 0.14, 10, steel * 1.4, 0.0, MeshKit.PAT_BEACH_STEEL, false, 0.0)
			# A pipe down its side and a ladder.
			t.prism(Vector3(r * 0.9, 0, 0.5), 0.2, h * 0.9, 5, rust * 0.6, 0.0, MeshKit.PAT_BEACH_STEEL, false, 1.0)
			for z: float in [-0.7, -0.3]:
				t.box(Vector3(r * 0.98, h * 0.45, z), Vector3(0.06, h * 0.9, 0.06), steel * 1.5, 0.0, MeshKit.PAT_PLAIN, MeshKit.NO_BOTTOM)
		1:
			var r: float = 1.7 * scale
			var leg: float = 4.5
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					t.box(Vector3(sx * r * 0.62, leg * 0.5, sz * r * 0.62), Vector3(0.22, leg, 0.22), steel * 1.3, 0.0,
						MeshKit.PAT_BEACH_STEEL, MeshKit.ALL_FACES, 1.0)
			for yy: float in [1.4, 3.0]:
				t.box(Vector3(0, yy, r * 0.62), Vector3(r * 1.25, 0.1, 0.1), steel * 1.5)
				t.box(Vector3(0, yy, -r * 0.62), Vector3(r * 1.25, 0.1, 0.1), steel * 1.5)
				t.box(Vector3(r * 0.62, yy, 0), Vector3(0.1, 0.1, r * 1.25), steel * 1.5)
				t.box(Vector3(-r * 0.62, yy, 0), Vector3(0.1, 0.1, r * 1.25), steel * 1.5)
			t.prism(Vector3(0, leg, 0), r, 3.0 * scale, 10, steel, 0.0, MeshKit.PAT_BEACH_STEEL, true, 0.0)
			_cone(t, Vector3(0, leg + 3.0 * scale, 0), r * 1.04, 1.2, 10, steel * 1.3)
		2:
			var h: float = 11.0 + 3.0 * float(variant % 4)
			t.prism(Vector3.ZERO, 0.55 * scale, h, 8, steel, 0.0, MeshKit.PAT_BEACH_STEEL, true, 1.0)
			t.prism(Vector3(0, h - 0.3, 0), 0.72 * scale, 0.45, 8, steel * 1.4, 0.0, MeshKit.PAT_BEACH_STEEL, true, 1.0)
			# A warm-white beacon on top: a decorative glow, never a hazard hue.
			t.box(Vector3(0, h + 0.3, 0), Vector3(0.2, 0.2, 0.2), skin.neon_white, skin.lamp_glow)
			# A smaller flue beside it.
			t.prism(Vector3(1.4, 0, 0.4), 0.28, h * 0.45, 6, steel * 1.1, 0.0, MeshKit.PAT_BEACH_STEEL, true, 1.0)
		_:
			# A dish on a pole, and antennas: a mast with crossbars and whips.
			t.box(Vector3(0, 1.2, 0), Vector3(0.14, 2.4, 0.14), steel * 1.5)
			var dish := Basis(Vector3(1.0, 0, 0), Vector3(0, 0.12, 0), Vector3(0, 0, 1.0)) * Basis(Vector3(1, 0, 0), -0.7)
			t.prism_xform(Transform3D(dish.scaled(Vector3(0.9 * scale, 1.0, 0.9 * scale)), Vector3(0, 2.7, 0)), 10, steel * 1.2,
				0.0, MeshKit.PAT_BEACH_STEEL, true, 2.0)
			t.box(Vector3(-1.6, 0.0 + 2.5, 0.0), Vector3(0.1, 5.0, 0.1), steel * 1.4)
			for yy: float in [3.2, 4.1, 4.9]:
				t.box(Vector3(-1.6, yy, 0), Vector3(0.9 - (yy - 3.2) * 0.2, 0.06, 0.06), steel * 1.6)
			t.box(Vector3(-1.1, 4.3, 0.2), Vector3(0.04, 2.2, 0.04), steel * 1.6)
	return t


## A cone from a ring of `sides` corners (radius r at `base`) up to its apex `height` over it.
func _cone(layer: MeshLayer, base: Vector3, r: float, height: float, sides: int, color: Color) -> void:
	var apex: Vector3 = base + Vector3(0, height, 0)
	for i: int in sides:
		var a0: float = TAU * float(i) / float(sides)
		var a1: float = TAU * float(i + 1) / float(sides)
		var p0: Vector3 = base + Vector3(cos(a0) * r, 0, sin(a0) * r)
		var p1: Vector3 = base + Vector3(cos(a1) * r, 0, sin(a1) * r)
		var mid: Vector3 = (p0 + p1) * 0.5 - base
		_quad(layer, p0, apex, apex, p1, mid.normalized() + Vector3(0, 0.5, 0), color, MeshKit.PAT_BEACH_STEEL, 0.0)


## A rack of surfboards on a roof: two timber posts, rails and five boards standing in it in muted paints with
## a pale stripe, its foot at the origin (the boards face +z, toward the runner).
func rack_template(variant: int, side: int = -1) -> MeshLayer:
	return _template(KEY_RACK + variant, side)


func _build_rack(variant: int) -> MeshLayer:
	var t := MeshLayer.new()
	var width: float = 2.8
	var dark: Color = skin.timber_color * 0.7
	for x: float in [-width * 0.5, width * 0.5]:
		t.box(Vector3(x, 0.8, 0), Vector3(0.12, 1.6, 0.12), skin.post_color, 0.0, MeshKit.PAT_BEACH_TIMBER, MeshKit.NO_BOTTOM,
			MeshKit.beach_timber_param(0, 0, variant))
	for y: float in [0.45, 1.4]:
		t.box(Vector3(0, y, 0), Vector3(width + 0.2, 0.08, 0.14), dark)
	for i: int in 5:
		var x: float = -width * 0.5 + 0.35 + float(i) * (width - 0.7) / 4.0
		var len: float = 1.9 + 0.25 * float((i + variant) % 3)
		var half := Vector3(0.26, len * 0.5, 0.05)
		var paint: Color = skin.paint_colors[(i + variant) % skin.paint_colors.size()]
		var board := Basis(Vector3(half.x, 0, 0), Vector3(0, 0, half.z), Vector3(0, half.y, 0))
		t.prism_xform(Transform3D(board, Vector3(x, 0.15 + len * 0.5, 0.02 * float(i % 2))), 6, paint, 0.0, MeshKit.PAT_PLAIN, true)
		var zf: float = 0.02 * float(i % 2) + 0.053
		t.quad(Vector3(x - 0.035, 0.15 + len * 0.95, zf), Vector3(x + 0.035, 0.15 + len * 0.95, zf), Vector3(x + 0.035, 0.15 + len * 0.05, zf),
			Vector3(x - 0.035, 0.15 + len * 0.05, zf), skin.cream_color)
	return t


## A flag on a pole on a roof, unlit: a pole and a pennant, its foot at the origin.
func flag_template(variant: int, side: int = -1) -> MeshLayer:
	return _template(KEY_FLAG + variant, side)


func _build_flag(variant: int) -> MeshLayer:
	var t := MeshLayer.new()
	t.box(Vector3(0, 1.6, 0), Vector3(0.07, 3.2, 0.07), skin.post_color, 0.0, MeshKit.PAT_BEACH_TIMBER, MeshKit.NO_BOTTOM,
		MeshKit.beach_timber_param(0, 0, 11))
	var col: Color = skin.flag_colors[variant % skin.flag_colors.size()]
	var top: float = 3.1
	# A pennant streaming toward the back of the building (-x): a flat triangle, seen from both sides.
	t.quad(Vector3(0, top, 0), Vector3(-1.1, top - 0.25, 0.0), Vector3(-1.1, top - 0.25, 0.0), Vector3(0, top - 0.55, 0.0), col, 0.0)
	t.quad(Vector3(0, top, 0), Vector3(0, top - 0.55, 0.0), Vector3(-1.1, top - 0.25, 0.0), Vector3(-1.1, top - 0.25, 0.0), col * 0.85, 0.0)
	return t


## A carved tiki mask on the face (unlit wood, no glowing eyes), 1 m tall, 0.2 m proud of the wall: a brow,
## two eye slots, a nose, a wide mouth and a thatch crest.
func mask_template(variant: int, side: int = -1) -> MeshLayer:
	return _template(KEY_MASK + variant, side)


func _build_mask(variant: int) -> MeshLayer:
	var t := MeshLayer.new()
	var wood: Color = skin.timber_color * (0.85 + 0.1 * float(variant % 3))
	var dark: Color = skin.bamboo_dark_color * 0.55
	var w: float = 0.55
	var h: float = 1.0
	t.box(Vector3(0.06, h * 0.5, 0), Vector3(0.12, h, w), wood, 0.0, MeshKit.PAT_BEACH_TIMBER, MeshKit.ALL_FACES & ~MeshKit.FACE_NX,
		MeshKit.beach_timber_param(0, 1, variant))
	# The brow, eye slots, nose, mouth and crest, on its +x face.
	t.box(Vector3(0.13, h * 0.72, 0), Vector3(0.1, 0.1, w * 1.06), wood * 1.1)
	for z: float in [-0.14, 0.14]:
		t.box(Vector3(0.125, h * 0.6, z), Vector3(0.012, 0.09, 0.14), dark)
	t.box(Vector3(0.15, h * 0.45, 0), Vector3(0.1, 0.22, 0.1), wood * 1.1)
	t.box(Vector3(0.125, h * 0.22, 0), Vector3(0.012, 0.13, 0.36), dark)
	t.box(Vector3(0.1, h + 0.12, 0), Vector3(0.18, 0.26, w * 0.9), skin.thatch_color * 0.8, 0.0, MeshKit.PAT_BEACH_THATCH)
	return t


## A swag of string lights (3 m long) along the face, hung from two hooks: a wire and nine bulbs in warm
## white, blue and violet; variant 0-2 shifts which. The bulbs glow; the wire is dark timber.
func swag_template(variant: int, side: int = -1) -> MeshLayer:
	return _template(KEY_SWAG + variant, side)


func _build_swag(variant: int) -> MeshLayer:
	var t := MeshLayer.new()
	var count: int = 9
	var prev := Vector3(0.1, 0.0, 1.5)
	var wire: Color = skin.timber_color * 0.5
	for i: int in range(1, count + 1):
		var f: float = float(i) / float(count)
		var p := Vector3(0.1, -0.4 * 4.0 * f * (1.0 - f), 1.5 - 3.0 * f)
		# The wire: a thin ribbon facing the street (+x).
		t.quad(prev + Vector3(0, 0.015, 0), p + Vector3(0, 0.015, 0), p - Vector3(0, 0.015, 0), prev - Vector3(0, 0.015, 0), wire)
		if i < count:
			_bulb_cross(t, p + Vector3(0.0, -0.08, 0.0), 0.055, _bulb_color(i + variant), skin.lamp_glow)
		prev = p
	for z: float in [-1.5, 1.5]:
		t.box(Vector3(0.05, 0.0, z), Vector3(0.1, 0.12, 0.12), skin.post_color, 0.0, MeshKit.PAT_PLAIN, MeshKit.ALL_FACES & ~MeshKit.FACE_NX)
	return t


## An alcove's inside, its floor at the origin, centred along the track, `width` wide, ALCOVE_DEPTH behind the
## face, ALCOVE_HEIGHT tall (kind 0 a bar, 1 a lounge, 2 a deck), with the bamboo railing at the face (flush).
func alcove_template(kind: int, width: float, seed: int, side: int = -1) -> MeshLayer:
	return _template(KEY_ALCOVE + kind * 100 + roundi(width - 4.0) * 10 + seed % 4, side)


func _build_alcove(kind: int, width: float, seed: int) -> MeshLayer:
	var t := MeshLayer.new()
	var hw: float = width * 0.5
	var d: float = ALCOVE_DEPTH
	var hh: float = ALCOVE_HEIGHT
	var bamboo: Color = skin.bamboo_colors[seed % skin.bamboo_colors.size()]
	var param: float = float(seed * 8)
	# The floor (planks along the track), the ceiling, the back wall and the two end walls.
	t.rect(Vector3(-d, 0, hw), Vector3(d, 0, 0), Vector3(0, 0, -width), skin.timber_color, 0.0, MeshKit.PAT_BEACH_TIMBER, Vector2.ZERO,
		Vector2.ONE, MeshKit.beach_timber_param(2, 1, seed))
	t.rect(Vector3(-d, hh, -hw), Vector3(d, 0, 0), Vector3(0, 0, width), skin.timber_color * 0.5, 0.0, MeshKit.PAT_BEACH_TIMBER,
		Vector2.ZERO, Vector2.ONE, MeshKit.beach_timber_param(2, 1, seed + 3))
	t.rect(Vector3(-d, 0, hw), Vector3(0, 0, -width), Vector3(0, hh, 0), bamboo * 0.8, 0.0, MeshKit.PAT_BEACH_WALL, Vector2.ZERO,
		Vector2.ONE, param)
	t.rect(Vector3(0, 0, hw), Vector3(-d, 0, 0), Vector3(0, hh, 0), bamboo * 0.7, 0.0, MeshKit.PAT_BEACH_WALL, Vector2.ZERO, Vector2.ONE, param)
	t.rect(Vector3(-d, 0, -hw), Vector3(d, 0, 0), Vector3(0, hh, 0), bamboo * 0.7, 0.0, MeshKit.PAT_BEACH_WALL, Vector2.ZERO, Vector2.ONE, param)
	# The railing flush with the face: bamboo posts and two rails.
	var posts: int = maxi(roundi(width / 1.1), 2)
	for i: int in posts + 1:
		var z: float = -hw + width * float(i) / float(posts)
		t.box(Vector3(0.06, 0.55, z), Vector3(0.07, 1.1, 0.07), skin.post_color, 0.0, MeshKit.PAT_BEACH_TIMBER, MeshKit.NO_BOTTOM,
			MeshKit.beach_timber_param(0, 0, seed + i))
	for y: float in [1.05, 0.55]:
		t.box(Vector3(0.06, y, 0), Vector3(0.07, 0.06, width), skin.post_color, 0.0, MeshKit.PAT_BEACH_TIMBER, MeshKit.ALL_FACES,
			MeshKit.beach_timber_param(2, 0, seed + 7))
	match kind:
		Verandah.BAR:
			# A counter along the back wall with a shelf of bottles over it, paper lanterns hung from the ceiling.
			t.box(Vector3(-d + 0.45, 0.52, 0), Vector3(0.6, 1.04, width - 0.8), skin.timber_color * 0.9, 0.0, MeshKit.PAT_BEACH_TIMBER,
				MeshKit.ALL_FACES & ~MeshKit.FACE_NY, MeshKit.beach_timber_param(2, 1, seed + 5))
			t.box(Vector3(-d + 0.45, 1.06, 0), Vector3(0.66, 0.06, width - 0.74), skin.timber_color * 0.65)
			t.box(Vector3(-d + 0.12, 1.55, 0), Vector3(0.22, 0.06, width - 1.2), skin.timber_color * 0.7)
			var bottles: int = maxi(roundi((width - 1.6) / 0.55), 3)
			for i: int in bottles:
				var z: float = -(width - 1.6) * 0.5 + (width - 1.6) * (float(i) + 0.5) / float(bottles)
				t.box(Vector3(-d + 0.12, 1.72, z), Vector3(0.11, 0.28, 0.11), skin.paint_colors[(i + seed) % skin.paint_colors.size()] * 0.8,
					0.0, MeshKit.PAT_PLAIN, MeshKit.NO_BOTTOM)
			for i: int in 3:
				_lantern(t, Vector3(-d * 0.45, hh - 0.5 - 0.12 * float(i % 2), -hw + width * (float(i) + 0.5) / 3.0), (i + seed) % 4)
		Verandah.LOUNGE:
			# Low seats and a table, string lights under the ceiling.
			for z: float in [-hw * 0.5, hw * 0.5]:
				t.box(Vector3(-d + 0.5, 0.25, z), Vector3(0.8, 0.5, 1.5), skin.paint_colors[(seed + int(z * 2.0)) % skin.paint_colors.size()] * 0.8)
				t.box(Vector3(-d + 0.2, 0.62, z), Vector3(0.14, 0.5, 1.5), skin.paint_colors[(seed + int(z * 2.0)) % skin.paint_colors.size()] * 0.7)
			t.box(Vector3(-d * 0.45, 0.28, 0), Vector3(0.5, 0.56, 0.7), skin.timber_color)
			for i: int in 4:
				_lantern(t, Vector3(-d * 0.5, hh - 0.3, -hw + width * (float(i) + 0.5) / 4.0), (i + seed) % 4)
		_:
			# A deck: boards leaning on the back wall, two deck chairs.
			for i: int in 3:
				var z: float = -hw * 0.5 + float(i) * hw * 0.5
				var half := Vector3(0.24, 1.0, 0.05)
				var lean := Basis(Vector3(1, 0, 0), 0.18)
				var board := lean * Basis(Vector3(half.x, 0, 0), Vector3(0, 0, half.z), Vector3(0, half.y, 0))
				t.prism_xform(Transform3D(board, Vector3(-d + 0.18, 1.05, z)), 6, skin.paint_colors[(i + seed) % skin.paint_colors.size()], 0.0,
					MeshKit.PAT_PLAIN, true)
			for z: float in [hw * 0.55, hw * 0.2]:
				t.box(Vector3(-d * 0.5, 0.2, z), Vector3(0.9, 0.12, 0.5), skin.paint_colors[(seed + 2) % skin.paint_colors.size()] * 0.85)
				t.box(Vector3(-d * 0.5 - 0.35, 0.5, z), Vector3(0.12, 0.6, 0.5), skin.paint_colors[(seed + 2) % skin.paint_colors.size()] * 0.75)
			_lantern(t, Vector3(-d * 0.4, hh - 0.4, 0.0), seed % 4)
	return t


## A paper lantern hung at `at`: a cord, a muted unlit shell, and the warm-white glow inside it (a small glowing
## panel at its foot, seen from the street below).
func _lantern(t: MeshLayer, at: Vector3, colour: int) -> void:
	var shell: Color = skin.lantern_shell_colors[colour % skin.lantern_shell_colors.size()]
	t.box(at + Vector3(0, 0.3, 0), Vector3(0.02, 0.4, 0.02), skin.timber_color * 0.5)
	t.prism(at - Vector3(0, 0.13, 0), 0.17, 0.3, 6, shell, 0.0, MeshKit.PAT_PLAIN, true)
	t.box(at + Vector3(0, -0.145, 0), Vector3(0.16, 0.02, 0.16), skin.lamp_color, skin.lamp_glow)


## The template with `key` (a KEY_* plus its variant), built once: as it is (the street at +x) for the left wall,
## mirrored once for the right wall (so appending it is a plain translation, never a flip of every vertex).
func _template(key: int, side: int) -> MeshLayer:
	var found: MeshLayer = _templates.get(key + (MIRRORED if side > 0 else 0))
	if found != null:
		return found
	var built: MeshLayer = _build(key)
	_templates[key] = built
	var mirrored := MeshLayer.new()
	mirrored.append(built, Transform3D(Basis.from_scale(Vector3(-1.0, 1.0, 1.0)), Vector3.ZERO))
	_templates[key + MIRRORED] = mirrored
	return mirrored if side > 0 else built


## Builds the template with `key` (see _template).
func _build(key: int) -> MeshLayer:
	if key >= KEY_ALCOVE:
		var k: int = key - KEY_ALCOVE
		return _build_alcove(k / 100, 4.0 + float((k % 100) / 10), k % 10)
	if key >= KEY_SWAG:
		return _build_swag(key - KEY_SWAG)
	if key >= KEY_MASK:
		return _build_mask(key - KEY_MASK)
	if key >= KEY_FLAG:
		return _build_flag(key - KEY_FLAG)
	if key >= KEY_RACK:
		return _build_rack(key - KEY_RACK)
	if key >= KEY_INDUSTRY:
		var k: int = key - KEY_INDUSTRY
		return _build_industry(k / 8, k % 8)
	return _build_palm(key - KEY_PALM)

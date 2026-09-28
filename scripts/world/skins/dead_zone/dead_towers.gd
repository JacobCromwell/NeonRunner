class_name DeadTowers
extends RefCounted
## The walls of the Dead Zone (DeadZoneSkin): the burnt-out towers of the dead city, the Neon City's
## own towers after the fire (GDD §5: every zone is set in the same future, so its dominant shapes are
## the ruins of the City's towers, not of an old town). A wall side is split into lots of lot_length
## metres (MeshKit.lot_run); a building covers 1–3 lots, laid out from its lot run alone, so every chunk
## that asks sees the same building:
## - a tower: a podium flush with the wall face from the street up past the calm band, and the tower
##   above it, often stepped back or behind an alley (as the City's); or a tower flush from the street
##   up. Its top is broken off (bites blown out of it), and some are burnt down to their steel frames,
##   columns and beams standing against the haze above the last of the cladding;
## - a stump: a building burnt down to its podium, a dead billboard on its roof (a few still play the
##   cult's feed) and a far row of ruins behind it;
## - some start with a side street choked with rubble flush with the wall face up past the band, so
##   every wall can be run.
## The faces are drawn by MeshKit.PAT_DZ_TOWER (the City's window grids, gutted), which keeps the calm
## band closed and solid-looking below band_top: nothing opens, glows, lights up or sticks out there,
## nothing looks like a vent at the foot (a screech's vent in the Dead Zone) or like a window (a window
## cyborg's window must be the only one); the wall-run height marks are pale unlit paint. Decoration
## starts at decor_min_height: dead neon banners (unlit tubes), dead roof boards, and on some towers a
## surviving screen hung out over the street, still playing the feed. The cult's emblem hides scorched
## and half-gone on some dead boards and at the foot of some banners. A few towers smoulder: rare rooms
## high above the play field still glow dimly with embers (the faces' COLOR.a, see PAT_DZ_TOWER).
## Overhead (overhead()): broken skybridges high over the street, where towers on both sides stand tall
## enough, all of it far above every ceiling (OVER_STREET_MIN).
## Chunk space: x across, y up (the street at y = 0), z = -distance. Faces and rubble are cut at the
## chunk's ends; props belong to the chunk holding their anchor distance.

## How far the buildings reach back from the street (their near ends show across alleys and side
## streets).
const DEPTH: float = 26.0
const SETBACKS: Array[float] = [0.0, 0.0, 0.0, 4.0, 8.0, 12.0]
## Share of buildings burnt down to a stump.
const LOW_SHARE: float = 0.28
## A broken top's profile has a point every STEP metres along the face.
const STEP: float = 2.0
## Every face reaches at least this far above the calm band.
const BAND_MARGIN: float = 1.4
## The steel frame over a tower burnt down to it: a column every BAY metres, beams every other storey.
const BAY: float = 4.2
const STOREY: float = 3.3
## The dead neon banners (the City's, unlit).
const BANNER_WIDTH: float = 2.4
const BANNER_HEIGHT: float = 12.0
## The stumps' roof boards.
const BOARD_HEIGHT: float = 5.0
const BOARD_MAX_LENGTH: float = 12.0
## A surviving screen hung out over the street: the gap between the wall and its inner edge, its
## casing's rim and depth, how far it keeps from the tower's ends and banner, and from its top.
const SCREEN_GAP: float = 0.5
const SCREEN_RIM: float = 0.15
const SCREEN_CASE: float = 0.4
const SCREEN_CLEAR: float = 2.0
const SCREEN_TOP_CLEAR: float = 3.0
## An emblem's clear square around its mark, as a multiple of the mark's size.
const EMBLEM_MARGIN: float = 1.25
## Nothing the walls hold out over the street comes lower than this: far above the play space and
## clear of every ceiling (DeadCeilings.TOP_LIMIT over the ceiling height).
const OVER_STREET_MIN: float = 14.0
## Broken skybridges: at most one per SKYBRIDGE_SLOT metres of street, SKYBRIDGE_Y to SKYBRIDGE_Y + 10
## metres up.
const SKYBRIDGE_SLOT: float = 150.0
const SKYBRIDGE_Y: float = 18.0
## Smoke rises only from ruins at least this tall (its base a little below their broken tops).
const PLUME_MIN_TOP: float = 20.0


## One building's layout, from its lot run alone (the same whichever chunk asks).
class Ruin:
	var side: int
	var id: int
	var b0: float
	var b1: float
	## Where the building's face starts: after the side street choked with rubble, if it has one.
	var f0: float
	## Where the tower's own face starts (after an alley above the podium).
	var t0: float
	var low: bool
	var podium_top: float
	## The broken face's nominal top, and the steel frame's (0: no frame).
	var height: float
	var frame_top: float = 0.0
	var setback: float
	var split: bool
	## The lowest the broken top goes.
	var floor_top: float
	var style: int
	var seed: int
	var wall: Color
	var smoulders: bool
	## Bites blown out of the top: (centre distance, half width, depth).
	var bites: Array[Vector3] = []
	## The dead neon banner on the tower: its near end and bottom (banner_d < 0: none).
	var banner_d: float = -1.0
	var banner_y: float = 0.0

	## The face's broken top at distance u (linear between profile points).
	func top(u: float) -> float:
		var g: float = u / STEP
		var i: int = floori(g)
		var f: float = g - float(i)
		if f < 0.0001:
			return point(i)
		return lerpf(point(i), point(i + 1), f)

	## Piece edges from u0 to u1 (every profile point between them) and the top edge at each.
	func outline(u0: float, u1: float, us: PackedFloat32Array, tops: PackedFloat32Array) -> void:
		var u: float = u0
		us.append(u)
		tops.append(top(u))
		while u < u1 - 0.001:
			u = minf((floorf(u / STEP + 0.001) + 1.0) * STEP, u1)
			us.append(u)
			tops.append(top(u))

	func point(i: int) -> float:
		var u: float = float(i) * STEP
		var h: float = height - (1.6 if low else 1.2) * MeshKit.hash01(side, i, 41)
		for bite: Vector3 in bites:
			h -= bite.z * maxf(0.0, 1.0 - absf(u - bite.x) / bite.y)
		return maxf(h, floor_top)


## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: DeadZoneSkin:
	get:
		return _skin.get_ref() as DeadZoneSkin
var _skin: WeakRef


func _init(p_skin: DeadZoneSkin) -> void:
	_skin = weakref(p_skin)


## Adds the ruins of one wall side between two track distances.
func build(batch: MeshBatch, side: int, face_x: float, start: float, end: float) -> void:
	var solid: MeshLayer = batch.layer(skin.solid_material())
	var lot: float = skin.lot_length
	var span: Vector2i = building_at(side, floori(start / lot))
	while span.x * lot < end:
		_building(batch, solid, ruin(side, span), face_x, start, end)
		span = building_at(side, span.y + 1)
	# The wall-run height marks: pale, unlit paint along the whole wall.
	var mark_x: float = face_x - side * 0.012
	for h: float in skin.wall_height_marks:
		solid.box(Vector3(mark_x, h, -(start + end) * 0.5), Vector3(0.02, 0.05, end - start), skin.wall_mark_color)
	# Below the street, seen through holes in the outer lanes: the walls in deep shade.
	MeshKit.facade_quad(solid, side, face_x, start, end, -skin.void_depth, 0.0, 0.0, skin.gap_inside_color, 0.0,
		MeshKit.PAT_DZ_UNDER, 1.0)


## The first and last lot of the building covering `lot_index` on this side.
func building_at(side: int, lot_index: int) -> Vector2i:
	return MeshKit.lot_run(side, lot_index, 0.45, 3, 5)


## The layout of the building covering lots span.x to span.y on this side.
func ruin(side: int, span: Vector2i) -> Ruin:
	var lot: float = skin.lot_length
	var r := Ruin.new()
	var id: int = span.x
	r.side = side
	r.id = id
	r.b0 = span.x * lot
	r.b1 = (span.y + 1) * lot
	var side_street: float = 0.0 if MeshKit.hash01(side, id, 3) < 0.72 else 3.0 + 3.0 * MeshKit.hash01(side, id, 4)
	r.f0 = r.b0 + side_street
	r.low = MeshKit.hash01(side, id, 20) < LOW_SHARE
	r.podium_top = skin.band_top + BAND_MARGIN + 1.0 + 4.0 * MeshKit.hash01(side, id, 6)
	r.style = MeshKit.hash_i(side, id, 7) % 4
	# Whole numbers: the shader rounds the seed before hashing it.
	r.seed = MeshKit.hash_i(side, id, 11) % 997
	r.wall = skin.facade_colors[MeshKit.hash_i(side, id, 9) % skin.facade_colors.size()]
	r.smoulders = not r.low and MeshKit.hash01(side, id, 12) < skin.smoulder_share
	if r.low:
		r.setback = 0.0
		r.split = true
		r.t0 = r.f0
		r.floor_top = skin.band_top + BAND_MARGIN
		r.height = r.floor_top + 0.8 + 2.6 * MeshKit.hash01(side, id, 2)
		r.bites.append(Vector3(lerpf(r.f0 + 3.0, r.b1 - 3.0, MeshKit.hash01(side, id, 34)), 2.5 + 2.0 *
			MeshKit.hash01(side, id, 31), 1.5 * MeshKit.hash01(side, id, 37)))
		return r
	r.setback = SETBACKS[MeshKit.hash_i(side, id, 13) % SETBACKS.size()]
	var alley: float = 0.0 if MeshKit.hash01(side, id, 14) < 0.55 else 2.0 + 4.0 * MeshKit.hash01(side, id, 15)
	r.split = r.setback > 0.0 or alley > 0.0
	r.t0 = r.f0 + alley
	r.floor_top = r.podium_top + 3.0 if r.split else skin.band_top + BAND_MARGIN
	var original: float = lerpf(skin.building_min_height, skin.building_max_height, pow(MeshKit.hash01(side, id, 2), 1.4))
	if MeshKit.hash01(side, id, 16) < skin.skeleton_share:
		# Burnt down to its frame: the cladding ends well below the tower's top, the steel goes on up.
		r.frame_top = original
		r.height = lerpf(r.floor_top + 4.0, original, 0.3 + 0.35 * MeshKit.hash01(side, id, 17))
	else:
		r.height = original
	var bites: int = MeshKit.hash_i(side, id, 30) % 3
	for i: int in bites:
		var half: float = 2.5 + 3.5 * MeshKit.hash01(side, id, 31 + i)
		var c: float = lerpf(r.t0 + half * 0.5, r.b1 - half * 0.5, MeshKit.hash01(side, id, 34 + i))
		var depth: float = (r.height - r.floor_top) * (0.3 + 0.6 * MeshKit.hash01(side, id, 37 + i))
		r.bites.append(Vector3(c, half, depth))
	var banner_d: float = r.t0 + 2.0 + 4.0 * MeshKit.hash01(side, id, 18)
	r.banner_y = (r.podium_top if r.split else skin.decor_min_height + 1.0) + 2.0
	if MeshKit.hash01(side, id, 19) < 0.55 and banner_d + BANNER_WIDTH < r.b1 - 1.0 \
			and minf(r.top(banner_d), r.top(banner_d + BANNER_WIDTH)) > r.banner_y + BANNER_HEIGHT + 2.0:
		r.banner_d = banner_d
	return r


## The height of the flush wall's top at track distance u on this side (a tower's face standing on the
## street's edge; 0 across a side street or where the tower is set back, and a stump's top).
func top_at(side: int, u: float) -> float:
	var r: Ruin = ruin(side, building_at(side, floori(u / skin.lot_length)))
	if u < r.f0:
		return 0.0
	if r.split:
		return r.podium_top if not r.low else r.top(u)
	return r.top(u)


func _building(batch: MeshBatch, solid: MeshLayer, r: Ruin, face_x: float, start: float, end: float) -> void:
	var side: int = r.side
	var ember: float = skin.ember_glow if r.smoulders else 0.0
	var param: float = MeshKit.dz_tower_param(r.style, r.seed)
	# A side street choked with rubble, and the building's near end across it.
	if r.f0 > r.b0:
		_side_street(solid, r, face_x, start, end)
		if r.f0 >= start and r.f0 < end:
			var top: float = r.podium_top if r.split and not r.low else r.top(r.f0)
			_end_face(solid, side, face_x, r.f0, 0.0, top, r.wall.darkened(0.15), 0.0 if r.low else ember, param)
	var u0: float = maxf(r.f0, start)
	var u1: float = minf(r.b1, end)
	var tower_x: float = face_x + side * r.setback
	if u1 > u0 + 0.001:
		if r.split and not r.low:
			# The podium, flush with the wall face, its top edge broken a little.
			var us := PackedFloat32Array()
			var tops := PackedFloat32Array()
			var u: float = u0
			while true:
				us.append(u)
				tops.append(r.podium_top - 0.5 * MeshKit.hash01(side, floori(u / STEP + 0.001), 43))
				if u >= u1 - 0.001:
					break
				u = minf((floorf(u / STEP + 0.001) + 1.0) * STEP, u1)
			MeshKit.facade_strip(solid, side, face_x, us, tops, 0.0, r.wall, 0.0, MeshKit.PAT_DZ_TOWER, param)
		else:
			# A flush tower (or a stump): one face from the street up to its broken top. Its band stays calm
			# (PAT_DZ_TOWER); only the part above ember_min_height may smoulder.
			var us := PackedFloat32Array()
			var tops := PackedFloat32Array()
			r.outline(u0, u1, us, tops)
			if r.low or ember <= 0.0:
				MeshKit.facade_strip(solid, side, face_x, us, tops, 0.0, r.wall, 0.0, MeshKit.PAT_DZ_TOWER, param)
			else:
				_split_face(solid, side, face_x, us, tops, r.wall, ember, param)
	if r.low:
		_stump(batch, solid, r, face_x, start, end)
		return
	# The tower over its podium, stepped back or behind its alley.
	var c0: float = maxf(r.t0, start)
	if r.split and u1 > c0 + 0.001:
		var us := PackedFloat32Array()
		var tops := PackedFloat32Array()
		r.outline(c0, u1, us, tops)
		if ember > 0.0:
			_split_face(solid, side, tower_x, us, tops, r.wall, ember, param, r.podium_top)
		else:
			MeshKit.facade_strip(solid, side, tower_x, us, tops, r.podium_top, r.wall, 0.0, MeshKit.PAT_DZ_TOWER, param)
	# The tower's near side, seen across its alley or over its setback.
	if r.split and r.t0 >= start and r.t0 < end:
		_end_face(solid, side, tower_x, r.t0, r.podium_top, r.top(r.t0), r.wall.darkened(0.1), ember, param)
	if r.frame_top > 0.0:
		_frame(solid, r, tower_x, start, end)
	if r.banner_d >= start and r.banner_d < end:
		_banner(solid, r, tower_x)
	# A broken ledge along the podium's top (or a flush tower's first storey over the band).
	_ledge(solid, r, face_x, maxf(r.f0, start), minf(r.b1, end))
	var smoke: Dictionary = plume(r, face_x)
	if not smoke.is_empty() and float(smoke["at"]) >= start and float(smoke["at"]) < end:
		_plume(batch.layer(skin.smoke_material()), smoke["base"], smoke["width"], smoke["height"])
	var screen: Dictionary = feed_screen(r, face_x)
	if not screen.is_empty() and float(screen["at"]) >= start and float(screen["at"]) < end:
		_feed_screen(batch, solid, r, face_x, screen)


## A face from its bottom (y0) to its broken tops, in two parts: the part below ember_min_height never
## glows, the part above may smoulder (the face's COLOR.a).
func _split_face(solid: MeshLayer, side: int, x: float, us: PackedFloat32Array, tops: PackedFloat32Array, wall: Color,
		ember: float, param: float, y0: float = 0.0) -> void:
	var cut: float = maxf(skin.ember_min_height, y0)
	var low_tops := PackedFloat32Array()
	var high_tops := PackedFloat32Array()
	var high: bool = false
	for t: float in tops:
		low_tops.append(minf(t, cut))
		high_tops.append(maxf(t, cut))
		high = high or t > cut + 0.05
	MeshKit.facade_strip(solid, side, x, us, low_tops, y0, wall, 0.0, MeshKit.PAT_DZ_TOWER, param)
	if high:
		MeshKit.facade_strip(solid, side, x, us, high_tops, cut, wall, ember, MeshKit.PAT_DZ_TOWER, param)


## A building's near end (facing the approaching runner), DEPTH deep from the face at x, from y0 to y1.
## If it smoulders (ember > 0), only its part above ember_min_height does.
func _end_face(solid: MeshLayer, side: int, x: float, u: float, y0: float, y1: float, wall: Color, ember: float,
		param: float) -> void:
	if y1 <= y0 + 0.05:
		return
	var cut: float = clampf(skin.ember_min_height, y0, y1) if ember > 0.0 else y1
	var x_min: float = minf(x, x + side * DEPTH)
	for part: Vector3 in [Vector3(y0, cut, 0.0), Vector3(cut, y1, ember)]:
		if part.y > part.x + 0.05:
			solid.rect(Vector3(x_min, part.x, -u), Vector3(DEPTH, 0, 0), Vector3(0, part.y - part.x, 0), wall, part.z,
				MeshKit.PAT_DZ_TOWER, Vector2(x_min, part.x), Vector2(x_min + DEPTH, part.y), param + 4.0 * 3.0)


## A side street between two buildings, choked with rubble flush with the wall face up past the band
## (so the wall can be run across it), its top ragged; behind it the dark street runs on.
func _side_street(solid: MeshLayer, r: Ruin, face_x: float, start: float, end: float) -> void:
	var a: float = maxf(r.b0, start)
	var b: float = minf(r.f0, end)
	if b <= a + 0.001:
		return
	var us := PackedFloat32Array()
	var tops := PackedFloat32Array()
	var u: float = a
	while true:
		us.append(u)
		tops.append(skin.band_top + 0.9 + 1.4 * MeshKit.hash01(r.side, floori(u / 1.0 + 0.001), 61))
		if u >= b - 0.001:
			break
		u = minf((floorf(u / 1.0 + 0.001) + 1.0) * 1.0, b)
	MeshKit.facade_strip(solid, r.side, face_x, us, tops, 0.0, skin.slab_color.darkened(0.2), 0.0, MeshKit.PAT_DZ_CONCRETE,
		2.0)


## The steel frame standing over a tower burnt down to it: columns every BAY metres rising out of the
## broken cladding (each broken off at its own height), beams every other storey between neighbours
## that both reach them, and a few floor beams running back into the ruin.
func _frame(solid: MeshLayer, r: Ruin, x: float, start: float, end: float) -> void:
	var side: int = r.side
	var steel: Color = skin.steel_color
	var k0: int = ceili((r.t0 + 0.6) / BAY)
	var k1: int = floori((r.b1 - 0.6) / BAY)
	var cx: float = x + side * 0.2
	for k: int in range(k0, k1 + 1):
		var u: float = float(k) * BAY
		if u < start or u >= end:
			continue
		var base_y: float = r.top(u) - 1.0
		var top_y: float = _column_top(r, k)
		if top_y <= base_y + 1.0:
			continue
		solid.box(Vector3(cx, (base_y + top_y) * 0.5, -u), Vector3(0.36, top_y - base_y, 0.36), steel, 0.0,
			MeshKit.PAT_DZ_STEEL)
		# Beams to the next column, every other storey both reach.
		if k < k1:
			var next_top: float = _column_top(r, k + 1)
			var next_base: float = r.top(u + BAY) - 1.0
			var y: float = ceilf(maxf(base_y, next_base) / (STOREY * 2.0)) * STOREY * 2.0
			while y < minf(top_y, next_top) - 0.4:
				if MeshKit.hash01(side, k, 200 + floori(y)) < 0.8:
					solid.box(Vector3(cx, y, -u - BAY * 0.5), Vector3(0.3, 0.34, BAY), steel, 0.0, MeshKit.PAT_DZ_STEEL)
				y += STOREY * 2.0
		# A floor beam running back into the ruin at some columns.
		if MeshKit.hash01(side, k, 190) < 0.3:
			var fy: float = floorf((base_y + top_y) * 0.5 / STOREY) * STOREY
			if fy > base_y + 0.5:
				solid.box(Vector3(cx + side * 3.0, fy, -u), Vector3(6.0, 0.3, 0.3), steel, 0.0, MeshKit.PAT_DZ_STEEL)


## Where the frame's column k breaks off.
func _column_top(r: Ruin, k: int) -> float:
	var jag: float = 9.0 * pow(MeshKit.hash01(r.side, k, 180), 1.5)
	return maxf(r.frame_top - jag, r.top(float(k) * BAY))


## A cornice of charred concrete along the podium's top (a flush tower's: at its first storey over the
## band), broken off in places, rebar bent out of the breaks and a cable hanging from some; all of it
## above the calm band, from u0 to u1 of this chunk.
func _ledge(solid: MeshLayer, r: Ruin, face_x: float, u0: float, u1: float) -> void:
	if u1 <= u0 + 0.01:
		return
	var side: int = r.side
	var y: float = (r.podium_top - 0.6) if r.split else skin.band_top + BAND_MARGIN + 1.0
	if r.low:
		return
	var out: float = 0.45
	var x: float = face_x - side * out * 0.5
	var steel: Color = skin.steel_color
	var concrete: Color = skin.slab_color.darkened(0.15)
	var c: int = floori(u0)
	while float(c) < u1:
		var a: float = maxf(float(c), u0)
		var b: float = minf(float(c + 1), u1)
		var gone: bool = MeshKit.hash01(side, c, 220) < 0.25 or MeshKit.hash01(side, floori(float(c) / 3.0), 221) < 0.12
		if not gone and b > a + 0.01:
			var sag: float = 0.12 * MeshKit.hash01(side, c, 222)
			solid.box(Vector3(x, y - sag, -(a + b) * 0.5), Vector3(out, 0.32, b - a), concrete, 0.0, MeshKit.PAT_DZ_CONCRETE)
		elif gone and float(c) >= u0 and MeshKit.hash01(side, c, 223) < 0.5:
			# Rebar bent out of the break.
			var bend := Basis.from_euler(Vector3((MeshKit.hash01(side, c, 224) - 0.5) * 1.2, 0.0, side * 0.5)).scaled_local(
				Vector3(0.025, 0.7, 0.025))
			solid.box_xform(Transform3D(bend, Vector3(face_x - side * 0.3, y - 0.3, -float(c) - 0.5)), steel, 0.0,
				MeshKit.PAT_DZ_STEEL)
		if float(c) >= u0 and MeshKit.hash01(side, c, 225) < 0.06:
			# A cable hanging from the ledge, well above the band.
			var length: float = minf(1.5 + 2.0 * MeshKit.hash01(side, c, 226), y - skin.band_top - 0.6)
			if length > 0.5:
				solid.box(Vector3(face_x - side * 0.3, y - 0.16 - length * 0.5, -float(c) - 0.5), Vector3(0.03, length, 0.03),
					steel.darkened(0.3))
		c += 1


## The column of smoke rising from a ruin's broken top: its distance (at), base (inside the building,
## below its top), width at the base and height. Empty if the ruin has none.
func plume(r: Ruin, face_x: float) -> Dictionary:
	if r.low or MeshKit.hash01(r.side, r.id, 210) >= skin.plume_share:
		return {}
	var at: float = lerpf(r.t0 + 2.0, r.b1 - 2.0, MeshKit.hash01(r.side, r.id, 211))
	var x: float = face_x + r.side * (r.setback + 5.0 + 8.0 * MeshKit.hash01(r.side, r.id, 212))
	var top: float = maxf(r.top(at), r.frame_top * 0.8)
	if top < PLUME_MIN_TOP:
		return {}
	return {"at": at, "base": Vector3(x, top - 3.0, -at), "width": 5.0 + 4.0 * MeshKit.hash01(r.side, r.id, 213),
		"height": 45.0 + 30.0 * MeshKit.hash01(r.side, r.id, 214)}


## One column of smoke (dead_smoke.gdshader): a quad whose six vertices sit at its base, spread out by
## the shader into a column facing the camera.
func _plume(layer: MeshLayer, base: Vector3, width: float, height: float) -> void:
	var c: Color = skin.plume_color
	layer.verts.append_array(PackedVector3Array([base, base, base, base, base, base]))
	layer.colors.append_array(PackedColorArray([c, c, c, c, c, c]))
	layer.uvs.append_array(PackedVector2Array([Vector2(-1, -1), Vector2(-1, 1), Vector2(1, 1), Vector2(-1, -1), Vector2(1, 1),
		Vector2(1, -1)]))
	var size := Vector2(width, height)
	layer.uv2s.append_array(PackedVector2Array([size, size, size, size, size, size]))


# --- Stumps -----------------------------------------------------------------------------------

## A stump's roof: a dead billboard on its roof (a few surviving ones still play the cult's feed, some
## dead ones carry the cult's emblem scorched and half-gone), and a far row of ruins behind it.
func _stump(batch: MeshBatch, solid: MeshLayer, r: Ruin, face_x: float, start: float, end: float) -> void:
	_far_row(solid, r, face_x, start, end)
	var board: Dictionary = roof_board(r, face_x)
	if board.is_empty():
		return
	var d0: float = board["d0"]
	if d0 < start or d0 >= end:
		return
	var side: int = r.side
	var len: float = board["length"]
	var px: float = board["x"]
	var y0: float = board["y0"]
	var h: float = BOARD_HEIGHT
	var steel: Color = skin.steel_color
	# The board's charred frame and its legs on the roof.
	solid.box(Vector3(px + side * 0.2, y0 + h * 0.5, -d0 - len * 0.5), Vector3(0.3, h + 0.4, len + 0.4), steel, 0.0,
		MeshKit.PAT_DZ_STEEL)
	for leg: float in [d0 + 1.0, d0 + len - 1.0]:
		var leg_y0: float = r.top(leg) - 0.4
		solid.box(Vector3(px + side * 0.2, (leg_y0 + y0) * 0.5, -leg), Vector3(0.2, y0 - leg_y0, 0.2), steel, 0.0,
			MeshKit.PAT_DZ_STEEL)
	if board["feed"]:
		# The cult's feed on a surviving screen: the same broadcast as everywhere (CultFeed), dim.
		CultFeed.wall_screen(batch.layer(skin.feed_material()), side, px - side * 0.004, d0, len, y0, h,
			skin.feed_board_brightness, r.id)
		return
	var content: Color = skin.board_colors[MeshKit.hash_i(side, r.id, 26) % skin.board_colors.size()]
	var kind: int = MeshKit.DZ_BOARD_SCREEN if MeshKit.hash01(side, r.id, 27) < 0.4 else MeshKit.DZ_BOARD_POSTER
	var param: float = float(MeshKit.hash_i(side, r.id, 28) % 100 + 100 * kind)
	_board_rect(solid, side, px, d0, len, y0, 0.0, len, 0.0, h, content, MeshKit.PAT_DZ_BOARD, param, Vector2.ZERO,
		Vector2(len, h))
	var e: float = board["emblem"]
	if e > 0.0:
		var m: float = e * EMBLEM_MARGIN
		_emblem(solid, side, px - side * 0.004, d0, len, y0, len - m, len, 0.0, m, e, r.id)


## A stump's roof board: its near end d0, length, the plane of its face (x), bottom (y0), whether it
## plays the cult's feed (`feed`) and, if it's a dead board with the cult's emblem, the emblem's size
## (`emblem`, 0 if none). Empty if the stump has none.
func roof_board(r: Ruin, face_x: float) -> Dictionary:
	if not r.low:
		return {}
	var len: float = minf(r.b1 - r.f0 - 4.0, BOARD_MAX_LENGTH)
	if len < 4.0 or MeshKit.hash01(r.side, r.id, 25) < 0.25:
		return {}
	var feed: bool = skin.shows_feed(r.side, r.id, skin.feed_share)
	var e: float = 0.0
	if not feed and skin.carries_emblem(r.side, r.id):
		# A badge small in the board's corner (GDD §5: never a centrepiece).
		e = maxf(BOARD_HEIGHT * 0.28, skin.emblem_min_size)
		if e > BOARD_HEIGHT * 0.36 or len < e * EMBLEM_MARGIN * 3.0:
			e = 0.0
	var d0: float = (r.f0 + r.b1 - len) * 0.5
	var roof: float = maxf(r.top(d0), r.top(d0 + len))
	return {"d0": d0, "length": len, "x": face_x + r.side * (1.6 - 0.03), "y0": maxf(roof + 1.0, skin.decor_min_height + 1.5),
		"feed": feed, "emblem": e}


## Behind a stump: a far row of taller ruins with broken tops, seen over it.
func _far_row(solid: MeshLayer, r: Ruin, face_x: float, start: float, end: float) -> void:
	var side: int = r.side
	var far := Ruin.new()
	far.side = side * 3
	far.height = 30.0 + 40.0 * MeshKit.hash01(side, r.id, 21)
	far.floor_top = far.height * 0.55
	far.bites.append(Vector3(lerpf(r.b0, r.b1, MeshKit.hash01(side, r.id, 23)), 6.0, far.height * 0.25))
	var x: float = face_x + side * (24.0 + 20.0 * MeshKit.hash01(side, r.id, 22))
	var u0: float = maxf(r.b0 - 2.0, start)
	var u1: float = minf(r.b1 + 2.0, end)
	if u1 > u0 + 0.001:
		var us := PackedFloat32Array()
		var tops := PackedFloat32Array()
		far.outline(u0, u1, us, tops)
		MeshKit.facade_strip(solid, side, x, us, tops, 6.0, skin.facade_colors[MeshKit.hash_i(side, r.id, 24) %
			skin.facade_colors.size()].darkened(0.2), 0.0, MeshKit.PAT_DZ_TOWER,
			MeshKit.dz_tower_param(MeshKit.hash_i(side, r.id, 29) % 4, (r.seed + 11) % 997))


# --- Dead neon, surviving screens, the emblem ------------------------------------------------

## The tower's dead neon banner: a housing of scorched steel and its tubes, unlit (the City's glyphs,
## dark), some with the cult's emblem scorched at its foot as the brand's mark.
func _banner(solid: MeshLayer, r: Ruin, x: float) -> void:
	var side: int = r.side
	var d: float = r.banner_d
	var y: float = r.banner_y
	var w: float = BANNER_WIDTH
	var h: float = BANNER_HEIGHT
	var px: float = x - side * 0.1
	solid.box(Vector3(x - side * 0.05, y + h * 0.5, -d - w * 0.5), Vector3(0.1, h + 0.3, w + 0.3), skin.steel_color, 0.0,
		MeshKit.PAT_DZ_STEEL)
	var e: float = banner_emblem(r)
	var foot: float = minf(e * EMBLEM_MARGIN, w) if e > 0.0 else 0.0
	if side < 0:
		solid.rect(Vector3(px, y + foot, -d), Vector3(0, 0, -w), Vector3(0, h - foot, 0), skin.dead_neon_color, 0.0,
			MeshKit.PAT_GLYPHS, Vector2(0, foot), Vector2(w, h), 0.0)
	else:
		solid.rect(Vector3(px, y + foot, -d - w), Vector3(0, 0, w), Vector3(0, h - foot, 0), skin.dead_neon_color, 0.0,
			MeshKit.PAT_GLYPHS, Vector2(w, foot), Vector2(0, h), 0.0)
	if e > 0.0:
		_emblem(solid, side, px, d, w, y, 0.0, w, 0.0, foot, e, r.id + 7)


## The size of the scorched emblem at the foot of the tower's dead banner (0 if it has none).
func banner_emblem(r: Ruin) -> float:
	if r.banner_d < 0.0 or not skin.carries_emblem(r.side, r.id):
		return 0.0
	return clampf(BANNER_WIDTH * 0.6, skin.emblem_min_size, 1.6)


## The surviving screen hung out over the street from a flush tower, still playing the cult's feed:
## clear of the tower's ends and banner, far above the play space and every ceiling, facing the
## oncoming runner. Its middle's distance (at), bottom (y0), width, height, and inner and outer edges
## (x_in at the wall end, x_out over the street). Empty if the tower has none.
func feed_screen(r: Ruin, face_x: float) -> Dictionary:
	if r.low or r.split or not skin.shows_feed(r.side, r.id + 1000, skin.feed_tower_share):
		return {}
	var w: float = minf(skin.feed_screen_width, absf(face_x) * skin.feed_screen_reach)
	var h: float = w * 9.0 / 16.0
	var lo: float = r.t0 + SCREEN_CLEAR
	var hi: float = r.b1 - SCREEN_CLEAR
	var at: float = lerpf(lo, hi, MeshKit.hash01(r.side, r.id, 142))
	if r.banner_d >= 0.0 and at > r.banner_d - SCREEN_CLEAR and at < r.banner_d + BANNER_WIDTH + SCREEN_CLEAR:
		at = r.banner_d + BANNER_WIDTH + SCREEN_CLEAR
	if hi < lo or at > hi:
		return {}
	var y0: float = maxf(skin.feed_screen_bottom, OVER_STREET_MIN) + 4.0 * MeshKit.hash01(r.side, r.id, 141)
	if y0 + h + SCREEN_TOP_CLEAR > minf(r.top(at - w), r.top(at + w)):
		return {}
	var x_in: float = face_x - r.side * SCREEN_GAP
	return {"at": at, "y0": y0, "width": w, "height": h, "x_in": x_in, "x_out": x_in - r.side * w}


## A surviving screen hung out over the street on two arms: a charred casing with the screen on its
## front, facing the oncoming runner (+z), playing the cult's feed.
func _feed_screen(batch: MeshBatch, solid: MeshLayer, r: Ruin, face_x: float, screen: Dictionary) -> void:
	var at: float = screen["at"]
	var w: float = screen["width"]
	var h: float = screen["height"]
	var y0: float = screen["y0"]
	var x_in: float = screen["x_in"]
	var x0: float = minf(x_in, screen["x_out"])
	solid.box(Vector3(x0 + w * 0.5, y0 + h * 0.5, -at - SCREEN_CASE * 0.5 - 0.03),
		Vector3(w + SCREEN_RIM * 2.0, h + SCREEN_RIM * 2.0, SCREEN_CASE), skin.steel_color, 0.0, MeshKit.PAT_DZ_STEEL)
	for y: float in [y0 + 0.25, y0 + h - 0.25]:
		solid.box(Vector3((face_x + x_in) * 0.5, y, -at - SCREEN_CASE * 0.5), Vector3(SCREEN_GAP + 0.2, 0.1, 0.1),
			skin.steel_color, 0.0, MeshKit.PAT_DZ_STEEL)
	CultFeed.screen(batch.layer(skin.feed_material()), Vector3(x0, y0, -at), Vector3(w, 0, 0), Vector3(0, h, 0),
		skin.feed_screen_brightness, r.id * 2 + (1 if r.side > 0 else 0))


## The surviving screens (DeadZoneSkin.feed_boards()) with middles in [start, end).
func feed_boards(side: int, face_x: float, start: float, end: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lot: float = skin.lot_length
	var span: Vector2i = building_at(side, floori(start / lot))
	while span.x * lot < end:
		var r: Ruin = ruin(side, span)
		var board: Dictionary = roof_board(r, face_x)
		if not board.is_empty() and board["feed"]:
			var at: float = float(board["d0"]) + float(board["length"]) * 0.5
			if at >= start and at < end:
				out.append({"side": side, "at": at, "kind": &"roof_board", "width": board["length"], "height": BOARD_HEIGHT,
					"center": Vector3(float(board["x"]) - side * 0.004, float(board["y0"]) + BOARD_HEIGHT * 0.5, -at)})
		var screen: Dictionary = feed_screen(r, face_x)
		if not screen.is_empty() and float(screen["at"]) >= start and float(screen["at"]) < end:
			out.append({"side": side, "at": screen["at"], "kind": &"tower_screen", "width": screen["width"],
				"height": screen["height"], "center": Vector3((float(screen["x_in"]) + float(screen["x_out"])) * 0.5,
				float(screen["y0"]) + float(screen["height"]) * 0.5, -float(screen["at"]))})
		span = building_at(side, span.y + 1)
	return out


## The scorched emblems (DeadZoneSkin.cult_emblems()) with middles in [start, end).
func emblems(side: int, face_x: float, start: float, end: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lot: float = skin.lot_length
	var span: Vector2i = building_at(side, floori(start / lot))
	while span.x * lot < end:
		var r: Ruin = ruin(side, span)
		var board: Dictionary = roof_board(r, face_x)
		if not board.is_empty() and float(board["emblem"]) > 0.0:
			var e: float = board["emblem"]
			var m: float = e * EMBLEM_MARGIN
			var len: float = board["length"]
			# The board's corner where it ends as read from the street: the far end on the left wall, the
			# near end on the right.
			var at: float = float(board["d0"]) + (len - m * 0.5 if side < 0 else m * 0.5)
			out.append({"side": side, "at": at, "kind": &"roof_board", "size": e,
				"center": Vector3(float(board["x"]) - side * 0.004, float(board["y0"]) + m * 0.5, -at)})
		var foot: float = banner_emblem(r)
		if foot > 0.0:
			var at: float = r.banner_d + BANNER_WIDTH * 0.5
			out.append({"side": side, "at": at, "kind": &"banner", "size": foot, "center": Vector3(
				_face_x(r, face_x) - side * 0.1, r.banner_y + foot * EMBLEM_MARGIN * 0.5, -at)})
		span = building_at(side, span.y + 1)
	var kept: Array[Dictionary] = []
	for e: Dictionary in out:
		if float(e["at"]) >= start and float(e["at"]) < end:
			kept.append(e)
	return kept


## The plane of the tower's face (set back from the wall's, or flush).
func _face_x(r: Ruin, face_x: float) -> float:
	return face_x + r.side * r.setback


## A part of a board facing the street (its face in the plane at x, the board from distance d0 over
## `length` and up from y0): from ua to ub along its reading direction (left to right as seen from the
## street) and from va to vb up it, UV from uv0 (its lower left) to uv1.
func _board_rect(layer: MeshLayer, side: int, x: float, d0: float, length: float, y0: float, ua: float, ub: float,
		va: float, vb: float, color: Color, pattern: int, param: float, uv0: Vector2, uv1: Vector2) -> void:
	if side < 0:
		layer.rect(Vector3(x, y0 + va, -(d0 + ua)), Vector3(0, 0, -(ub - ua)), Vector3(0, vb - va, 0), color, 0.0, pattern,
			uv0, uv1, param)
	else:
		layer.rect(Vector3(x, y0 + va, -(d0 + length - ua)), Vector3(0, 0, ub - ua), Vector3(0, vb - va, 0), color, 0.0,
			pattern, uv0, uv1, param)


## The cult's emblem `e` metres across, centred in the clear square [ua, ub] x [va, vb] of a board (as
## _board_rect()), scorched and half-gone in its unlit metal on the board's charred ground.
func _emblem(layer: MeshLayer, side: int, x: float, d0: float, length: float, y0: float, ua: float, ub: float,
		va: float, vb: float, e: float, seed: int) -> void:
	var half: float = e * 0.5
	var uc: float = (ua + ub) * 0.5
	var vc: float = (va + vb) * 0.5
	_board_rect(layer, side, x, d0, length, y0, ua, ub, va, vb, skin.emblem_metal_color(), MeshKit.PAT_DZ_MARK,
		float(posmod(seed, 997)), Vector2((ua - uc) / half, (va - vc) / half), Vector2((ub - uc) / half, (vb - vc) / half))


# --- Across the street -------------------------------------------------------------------------

## Broken skybridges high over the street, for one chunk (both sides: the skin adds them to the left
## wall): where flush towers on both sides stand tall enough, a stub of the bridge's deck juts out from
## each wall, broken off short of the middle, girders sticking out of its ends. All far above every
## ceiling (OVER_STREET_MIN).
func overhead(batch: MeshBatch, half_width: float, start: float, end: float) -> void:
	if skin.skybridge_share <= 0.0:
		return
	var solid: MeshLayer = batch.layer(skin.solid_material())
	var slot: int = floori(start / SKYBRIDGE_SLOT)
	while float(slot) * SKYBRIDGE_SLOT < end:
		var bridge: Dictionary = skybridge(slot, half_width)
		if not bridge.is_empty() and float(bridge["at"]) >= start and float(bridge["at"]) < end:
			_skybridge(solid, bridge, half_width)
		slot += 1


## The broken skybridge in slot `slot` (a street half_width wide to the wall faces): its distance
## (at), bottom (y), depth along the track and the lengths of its two stubs. Empty if the slot has none.
func skybridge(slot: int, half_width: float) -> Dictionary:
	if MeshKit.hash01(slot, 151) >= skin.skybridge_share:
		return {}
	var at: float = (float(slot) + 0.15 + 0.7 * MeshKit.hash01(slot, 152)) * SKYBRIDGE_SLOT
	var y: float = maxf(SKYBRIDGE_Y, OVER_STREET_MIN) + 10.0 * MeshKit.hash01(slot, 153)
	var depth: float = 3.2
	for side: int in [-1, 1]:
		if minf(top_at(side, at - depth), top_at(side, at + depth)) < y + 6.0:
			return {}
	var left: float = half_width * (0.25 + 0.35 * MeshKit.hash01(slot, 154))
	var right: float = half_width * (0.25 + 0.35 * MeshKit.hash01(slot, 155))
	return {"at": at, "y": y, "depth": depth, "left": left, "right": right}


func _skybridge(solid: MeshLayer, bridge: Dictionary, half_width: float) -> void:
	var at: float = bridge["at"]
	var y: float = bridge["y"]
	var depth: float = bridge["depth"]
	var steel: Color = skin.steel_color
	for side: int in [-1, 1]:
		var reach: float = bridge["left"] if side < 0 else bridge["right"]
		var x0: float = side * half_width
		var x1: float = side * (half_width - reach)
		var cx: float = (x0 + x1) * 0.5
		# The deck (charred concrete), the corridor's dark glass band and its roof.
		solid.box(Vector3(cx, y + 0.3, -at), Vector3(reach, 0.6, depth), skin.slab_color, 0.0, MeshKit.PAT_DZ_CONCRETE)
		solid.box(Vector3(cx, y + 1.7, -at), Vector3(reach, 2.2, depth - 0.3), skin.glass_color, 0.0, MeshKit.PAT_GLASS,
			MeshKit.ALL_FACES & ~(MeshKit.FACE_PY | MeshKit.FACE_NY))
		solid.box(Vector3(cx, y + 3.0, -at), Vector3(reach, 0.4, depth), skin.slab_color.darkened(0.2), 0.0,
			MeshKit.PAT_DZ_CONCRETE)
		# Girders sticking out of the broken end, bent down.
		for i: int in 3:
			var z: float = -at + (float(i) - 1.0) * depth * 0.35
			var length: float = 1.0 + 1.6 * MeshKit.hash01(floori(at), side, 160 + i)
			var droop: float = 0.15 + 0.5 * MeshKit.hash01(floori(at), side, 170 + i)
			var basis := Basis.from_euler(Vector3(0.0, 0.0, side * droop)).scaled_local(Vector3(length, 0.22, 0.22))
			var gy: float = y + (0.2 if i != 1 else 3.1)
			solid.box_xform(Transform3D(basis, Vector3(x1 - side * length * 0.45, gy - length * 0.4 * droop, z)), steel, 0.0,
				MeshKit.PAT_DZ_STEEL)

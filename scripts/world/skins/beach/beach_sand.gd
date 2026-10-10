class_name BeachSand
extends RefCounted
## The Beach's floor and its pools (BeachSkin, GDD §5; the owner's decision that gaps are pools). A floor
## segment is one lane's stretch of beach: sand (MeshKit.PAT_BEACH_SAND, laid out from world position, so
## lanes, pieces and chunk cuts join seamlessly: wind ripples, drifts, damp patches, footprints, flat
## shells and pebbles) with boardwalk runs (MeshKit.PAT_BEACH_BOARDWALK: weathered planks with rusty
## bolted steel plates) over stretches of it, chosen by hashing lane and slot (boardwalk_slot metres) so
## they line up across chunk cuts, with a timber beam across the lane where one starts or ends. The
## running surface is flat (y = 0) and nothing stands on it, so nothing looks like an obstacle, and
## nothing on it is round (in other zones a manhole is a sewer screech's lair, GDD §9.5). A soft seam
## shows where a neighbouring lane's sand runs beside it, so every lane reads as its own; the outer lanes
## run on to the building faces over a flush bamboo kerb.
## Where a gap borders the segment it is a POOL: the floor ends in the orange edge glow right on the
## collision edge (a lip on the floor and a strip along the top of the tank's wall, as bright as every
## zone's, and a soft halo along the far side), with a dark steel coping just outside the lip so the
## orange pops against the sand, and below it the black rust-streaked steel of the pool tank
## (MeshKit.PAT_BEACH_TANK in the skin's gap_inside_color) running down pool_depth (well under a metre) to
## the water (MeshKit.PAT_BEACH_WATER: opaque, unlit deep teal with ripples and glints, darker than any floor):
## a pool reads as a hole at a glance and, once the near edge stops hiding it, as water, and nothing in it is lit,
## glowing or floor-like. A runner who falls goes on down past the water (fall_death_depth) and out of sight
## into it. The tank is flush with the floor (the reference's stands proud of it: a raised rim would read as
## an obstacle that isn't there). Every segment also carries its sides along its lane edges in the same
## steel, hidden under the neighbouring lane unless that lane has a pool.
## Chunk space: x across, y up (the floor at y = 0), z = -distance.

## The orange edge language: a lip on the floor's last 0.18 m and a strip along the top of the tank's wall
## below it; taller and brighter than on the dark streets of other zones, as on every lit floor.
const EDGE_LIP: float = 0.18
const LIP_GLOW: float = 0.42
## The steel coping just outside the lip (flush with the floor).
const COPING: float = 0.28
const STRIP_TOP: float = 0.02
const STRIP_HEIGHT: float = 0.1
const STRIP_GLOW: float = 0.6
## The halo along the strip of a pool's far side (additive, kit_glow).
const EDGE_HALO: float = 0.35
## A timber beam across the lane where a boardwalk run starts or ends.
const BEAM: float = 0.16
## How many slots long a run of boardwalk may be.
const MAX_RUN: int = 3

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: BeachSkin:
	get:
		return _skin.get_ref() as BeachSkin
var _skin: WeakRef


func _init(p_skin: BeachSkin) -> void:
	_skin = weakref(p_skin)


## Adds one lane's floor piece. center/size describe its collision box (top at y = 0).
func build(batch: MeshBatch, center: Vector3, size: Vector3, lane_x: float, edge_start: bool, edge_end: bool) -> void:
	if size.z < 0.01:
		return
	var s: MeshLayer = batch.layer(skin.solid_material())
	var x0: float = center.x - size.x * 0.5
	var x1: float = center.x + size.x * 0.5
	# The collision box spans the lane; the outer lanes' boxes run on to the wall (the kerb).
	var half_lane: float = minf(x1 - lane_x, lane_x - x0)
	var l0: float = lane_x - half_lane
	var l1: float = lane_x + half_lane
	var left_kerb: bool = x0 < l0 - 0.01
	var right_kerb: bool = x1 > l1 + 0.01
	var near_d: float = -(center.z + size.z * 0.5)
	var far_d: float = -(center.z - size.z * 0.5)
	var length: float = far_d - near_d
	var lip_n: float = minf(EDGE_LIP, size.z * 0.3) if edge_start else 0.0
	var lip_f: float = minf(EDGE_LIP, size.z * 0.3) if edge_end else 0.0
	var cope_n: float = minf(COPING, size.z * 0.1) if edge_start else 0.0
	var cope_f: float = minf(COPING, size.z * 0.1) if edge_end else 0.0
	var a: float = near_d + lip_n + cope_n
	var b: float = far_d - lip_f - cope_f
	var lane: int = MeshKit.key(lane_x)
	var lane_hash: int = MeshKit.hash_i(lane, 9)
	var flags: int = (0 if left_kerb else MeshKit.BEACH_SEAM_LEFT) | (0 if right_kerb else MeshKit.BEACH_SEAM_RIGHT)
	if edge_start:
		flags |= MeshKit.BEACH_POOL_NEAR
	if edge_end:
		flags |= MeshKit.BEACH_POOL_FAR
	if lane_hash & 64:
		flags |= MeshKit.BEACH_ALT_TONE
	var param: float = MeshKit.sand_param(flags, length, lane_hash)

	if b > a:
		# The floor: runs of sand and boardwalk between the lips, each a rectangle of its own (UV.x -1 to 1
		# across the lane, UV.y metres from the piece's near end, so the wet rim round a pool is right).
		var cursor: float = a
		var runs: Array[Vector3] = boardwalk_runs(lane, a, b)
		for run: Vector3 in runs:
			if run.x > cursor + 0.001:
				_top(s, l0, l1, near_d, cursor, run.x, skin.sand_color, MeshKit.PAT_BEACH_SAND, param)
			_top(s, l0, l1, near_d, run.x, run.y, skin.boardwalk_color, MeshKit.PAT_BEACH_BOARDWALK, param)
			# A timber beam across the lane where the boardwalk starts and ends (a slot's own edge, not a cut).
			if run.z > 0.5:
				_beam(s, l0, l1, run.x)
			cursor = run.y
		if b > cursor + 0.001:
			_top(s, l0, l1, near_d, cursor, b, skin.sand_color, MeshKit.PAT_BEACH_SAND, param)
		for run: Vector3 in runs:
			if run.y < b - 0.001:
				_beam(s, l0, l1, run.y)
		# The flush bamboo kerb along the building faces.
		if left_kerb:
			_kerb(s, x0, l0, a, b)
		if right_kerb:
			_kerb(s, l1, x1, a, b)

	# The lane's sides along its edges, in the black steel of the tank: seen only where the neighbouring lane
	# has a pool.
	var depth: float = skin.pool_depth
	var steel: Color = skin.gap_inside_color
	if not left_kerb:
		s.rect(Vector3(x0, -depth, -far_d), Vector3(0, 0, far_d - near_d), Vector3(0, depth, 0), steel, 0.0,
			MeshKit.PAT_BEACH_TANK, Vector2.ZERO, Vector2.ONE, 1.0)
	if not right_kerb:
		s.rect(Vector3(x1, -depth, -near_d), Vector3(0, 0, -(far_d - near_d)), Vector3(0, depth, 0), steel, 0.0,
			MeshKit.PAT_BEACH_TANK, Vector2.ZERO, Vector2.ONE, 1.0)

	if edge_start:
		_edge(s, x0, x1, near_d, lip_n, cope_n, 1.0)
		# The far side of a pool faces the approaching runner: a soft orange halo along its strip, so the edge
		# carries from afar against the bright sand.
		batch.layer(skin.glow_material()).rect(Vector3(x0 - 0.15, -STRIP_TOP - STRIP_HEIGHT - 0.25, -near_d + 0.05),
			Vector3(x1 - x0 + 0.3, 0, 0), Vector3(0, STRIP_HEIGHT + 0.5, 0), skin.gap_edge_color, EDGE_HALO,
			MeshKit.SHAPE_STREAK)
	if edge_end:
		_edge(s, x0, x1, far_d, lip_f, cope_f, -1.0)


## One rectangle of the floor's top between track distances d0 and d1 over the lane [l0, l1].
func _top(s: MeshLayer, l0: float, l1: float, near_d: float, d0: float, d1: float, color: Color, pattern: int,
		param: float) -> void:
	if d1 <= d0 + 0.0005:
		return
	s.rect(Vector3(l0, 0, -d0), Vector3(l1 - l0, 0, 0), Vector3(0, 0, -(d1 - d0)), color, 0.0, pattern,
		Vector2(-1.0, d0 - near_d), Vector2(1.0, d1 - near_d), param)


## A timber beam flush across the lane at track distance d (BEAM wide): where the boardwalk meets the sand.
func _beam(s: MeshLayer, l0: float, l1: float, d: float) -> void:
	s.rect(Vector3(l0, 0.004, -(d - BEAM * 0.5)), Vector3(l1 - l0, 0, 0), Vector3(0, 0, -BEAM), skin.timber_color * 0.8, 0.0,
		MeshKit.PAT_BEACH_TIMBER, Vector2.ZERO, Vector2.ONE, MeshKit.beach_timber_param(1, 1, 3))


## The flush bamboo kerb from x0 to x1 along the track between distances a and b.
func _kerb(s: MeshLayer, x0: float, x1: float, a: float, b: float) -> void:
	s.rect(Vector3(x0, 0.0, -a), Vector3(x1 - x0, 0, 0), Vector3(0, 0, -(b - a)), skin.kerb_color, 0.0,
		MeshKit.PAT_BEACH_TIMBER, Vector2.ZERO, Vector2.ONE, MeshKit.beach_timber_param(2, 0, 7))


## Where the pool ends at distance d (facing the player when facing = 1, away when -1): the steel coping
## and the orange lip on the floor's edge, the orange strip along the top of the tank's wall, then the wall
## running down to the water.
func _edge(s: MeshLayer, x0: float, x1: float, d: float, lip: float, cope: float, facing: float) -> void:
	var z: float = -d
	var w: float = x1 - x0
	var edge: Color = skin.gap_edge_color
	var depth: float = skin.pool_depth
	var steel: Color = skin.gap_inside_color
	var strip_y: float = -STRIP_TOP - STRIP_HEIGHT
	if facing > 0.0:
		s.rect(Vector3(x0, 0, z), Vector3(w, 0, 0), Vector3(0, 0, -lip), edge, LIP_GLOW)
		s.rect(Vector3(x0, 0, z - lip), Vector3(w, 0, 0), Vector3(0, 0, -cope), skin.coping_color)
		s.rect(Vector3(x0, -depth, z), Vector3(w, 0, 0), Vector3(0, depth, 0), steel, 0.0, MeshKit.PAT_BEACH_TANK,
			Vector2.ZERO, Vector2.ONE, 0.0)
		s.rect(Vector3(x0, strip_y, z + 0.004), Vector3(w, 0, 0), Vector3(0, STRIP_HEIGHT, 0), edge, STRIP_GLOW)
	else:
		s.rect(Vector3(x0, 0, z + lip), Vector3(w, 0, 0), Vector3(0, 0, -lip), edge, LIP_GLOW)
		s.rect(Vector3(x0, 0, z + lip + cope), Vector3(w, 0, 0), Vector3(0, 0, -cope), skin.coping_color)
		s.rect(Vector3(x1, -depth, z), Vector3(-w, 0, 0), Vector3(0, depth, 0), steel, 0.0, MeshKit.PAT_BEACH_TANK,
			Vector2.ZERO, Vector2.ONE, 0.0)
		s.rect(Vector3(x1, strip_y, z - 0.004), Vector3(-w, 0, 0), Vector3(0, STRIP_HEIGHT, 0), edge, STRIP_GLOW)


## The boardwalk runs of a lane within the track distances [from, to], as Vector3(start, end, 1 if the run
## starts at its slot's own edge): a slot of boardwalk_slot metres belongs to a boardwalk where a run, one to
## MAX_RUN slots long, starts in it or in one of the slots before it, a run starting in boardwalk_share of the
## slots by hashing the lane's key and the slot's index. The slot grid is the track's own, so runs line up
## across chunk cuts and pieces; a run is clipped to [from, to].
func boardwalk_runs(lane: int, from: float, to: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var slot: float = skin.boardwalk_slot
	if skin.boardwalk_share <= 0.0 or slot <= 0.1:
		return out
	var k: int = floori(from / slot)
	var open_from: float = -1.0
	var last: int = floori(to / slot)
	while k <= last:
		if is_boardwalk(lane, k):
			if open_from < 0.0:
				open_from = maxf(float(k) * slot, from)
		elif open_from >= 0.0:
			var end: float = minf(float(k) * slot, to)
			if end > open_from + 0.001:
				out.append(Vector3(open_from, end, 1.0 if open_from > from else 0.0))
			open_from = -1.0
		k += 1
	if open_from >= 0.0 and to > open_from + 0.001:
		out.append(Vector3(open_from, to, 1.0 if open_from > from else 0.0))
	return out


## Whether slot `k` of the lane keyed `lane` is boardwalk.
func is_boardwalk(lane: int, k: int) -> bool:
	for back: int in MAX_RUN:
		var start: int = k - back
		if MeshKit.hash01(lane, start, 61) < skin.boardwalk_share and 1 + MeshKit.hash_i(lane, start, 62) % MAX_RUN > back:
			return true
	return false


## A floor cut through the beach (task B4; GDD §9.9): the sand or boardwalk split open down the lane (the
## track hides the floor as the cut runs, FloorCutSection). The floor beside it and beyond it ends in the
## pool's edge (the steel coping, the orange lip right on the collision edge, a strip along the top of the
## cut and the soft halo on its far side), and below everything is the black steel of the pool tank running
## down to the water, like any gap: nothing in it is lit, glowing or floor-like.
func cut(parent: Node3D, section: FloorCutSection) -> void:
	ZoneSkin.standard_floor_cut(parent, section, skin.solid_material(), skin.glow_material(), {
		"edge": skin.gap_edge_color, "inside": skin.gap_inside_color, "pattern": MeshKit.PAT_BEACH_TANK,
		"params": [0.0, 1.0, 0.0], "depth": skin.pool_depth, "bottom": false,
		"lip": EDGE_LIP, "lip_glow": LIP_GLOW, "strip_glow": STRIP_GLOW, "halo": EDGE_HALO,
		"dark_line": skin.coping_color, "dark": COPING,
	})


## The wall's face below the floor, in the tank's black steel (seen only through the pools beside it), for
## one wall piece.
func below_wall(batch: MeshBatch, side: int, face_x: float, start: float, end: float) -> void:
	var s: MeshLayer = batch.layer(skin.solid_material())
	var depth: float = skin.pool_depth
	if side < 0:
		s.rect(Vector3(face_x, -depth, -start), Vector3(0, 0, -(end - start)), Vector3(0, depth, 0), skin.gap_inside_color,
			0.0, MeshKit.PAT_BEACH_TANK, Vector2.ZERO, Vector2.ONE, 2.0)
	else:
		s.rect(Vector3(face_x, -depth, -end), Vector3(0, 0, end - start), Vector3(0, depth, 0), skin.gap_inside_color, 0.0,
			MeshKit.PAT_BEACH_TANK, Vector2.ZERO, Vector2.ONE, 2.0)


## The pool's water pool_depth below the floor, across the whole street (neither belongs to a lane, so the skin adds
## it to the left wall's mesh), and the sand blowing along the street, the leaves drifting and the speed
## streaks (the still floor's motion cues), for one piece of the left wall (a whole chunk or part of one, where the
## wall switches between standing and open inside it).
func below(batch: MeshBatch, half_width: float, start: float, end: float) -> void:
	batch.layer(skin.solid_material()).rect(Vector3(-half_width, -skin.pool_depth, -start), Vector3(half_width * 2.0, 0, 0),
		Vector3(0, 0, -(end - start)), skin.water_color, 0.0, MeshKit.PAT_BEACH_WATER)
	drift(batch, half_width, start, end)


## The motion cues of every drift slice that starts inside [start, end): the piece holding a slice's start gives
## the whole slice, so a chunk gets exactly one copy however its left wall is cut into pieces.
## MeshKit.drift_particles alone places only the slices that fit whole inside the range it is given, so a chunk
## whose left wall switched between standing and open inside it (two pieces, neither covering the slice) got no
## sand, leaves or streaks at all.
func drift(batch: MeshBatch, half_width: float, start: float, end: float) -> void:
	var slice: float = TrackBuilder.CHUNK_LENGTH
	var colors := PackedColorArray([skin.sand_grain_color, skin.leaf_color, skin.streak_color])
	var layer: MeshLayer = batch.layer(skin.drift_material())
	var index: int = ceili(start / slice - 0.001)
	while float(index) * slice < end - 0.001:
		MeshKit.drift_particles(layer, float(index) * slice, float(index + 1) * slice, slice, half_width - 0.7, 7.0,
			skin.sand_count, skin.leaf_count, skin.streak_count, colors)
		index += 1

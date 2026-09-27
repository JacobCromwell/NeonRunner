class_name CorporateTrains
extends RefCounted
## Maglev trains for the Corporate floor (CorporateSkin, GDD §5: "roofs of maglev trains"). A solid
## stretch of one lane is a train running in formation with its neighbours through a deep guideway
## trench, the same way as the runner (as the Chairman's train will in the zone's boss fight, GDD
## §10): a row of carriages on a per-lane grid, coupled by gangways, each with a smooth roof
## (PAT_CORP_ROOF: a corporate express in steel with the brand's pinstripe, or an olive military
## freight car, runs of carriages sharing a kind, some with the brand's mark painted on the roof).
## The roofs are flat to the touch (the running surface) and nothing stands on them or looks like an
## obstacle; their shoulders curve down along the lane's edges, so parallel trains show a dark slit.
## Where a gap borders the stretch, the roof ends in the orange edge glow right on the collision edge,
## as in every zone, with a strip along the top of the carriage's end below it; everything under the
## roofs (the carriages' sides and ends, the guideways on their piers, the trench far below) is in deep
## shade (PAT_CORP_UNDER), so a gap reads as a hole at a glance and nothing inside it is lit. The
## guideways' tops lie deeper than a fall that ends the run, so a fall never visibly lands.
## Carriages sit on the lane's grid and their kind comes from hashing grid cells, so a carriage cut by
## a chunk boundary continues seamlessly in the next chunk.
## Chunk space: x across, y up (roofs at y = 0), z = -distance.

## The orange edge language: a lip on the roof's last 0.18 m and a strip along the top of the
## carriage's end below it (as bright as the Marketplace's: from afar the strip is what shows).
const EDGE_LIP: float = 0.18
const LIP_GLOW: float = 0.4
const STRIP_TOP: float = 0.02
const STRIP_HEIGHT: float = 0.1
const STRIP_GLOW: float = 0.6
## A gangway between two carriages: half its length along the track, and the flush cover plate
## bridging it (so a joint never reads as a hole).
const JOINT_HALF: float = 0.3
const JOINT_PLATE: float = 0.55
## The roofs' rounded shoulders along the lane's edges: how wide and how far they fall.
const SHOULDER: float = 0.12
const SHOULDER_DROP: float = 0.08
## Carriages of one kind come in runs of this many.
const RUN: int = 4
## A grid line this close to a gap's edge gets no gangway: the stub between them is the end of the
## carriage on its other side, so no carriage at a gap is shorter than this.
const GAP_MARGIN: float = 5.0
## What sits on a grid line (_joint_at).
const NONE: int = 0
const GANGWAY: int = 1
const SEAM: int = 2
## The guideway beams and their piers.
const BEAM_WIDTH: float = 0.9
const BEAM_HEIGHT: float = 1.3
const PIER_SPACING: float = 24.0
## Styles of PAT_CORP_ROOF.
const EXPRESS: int = 0
const FREIGHT: int = 1

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: CorporateSkin:
	get:
		return _skin.get_ref() as CorporateSkin
var _skin: WeakRef


func _init(p_skin: CorporateSkin) -> void:
	_skin = weakref(p_skin)


## Half the width of a train's roof in a lane `lane_width` wide.
func roof_half_width(lane_width: float) -> float:
	return lane_width * 0.5 - skin.train_inset


## Adds one lane's floor piece. center/size describe its collision box (top at y = 0).
func build(batch: MeshBatch, center: Vector3, size: Vector3, lane_x: float, edge_start: bool, edge_end: bool) -> void:
	if size.z < 0.01:
		return
	var s: MeshLayer = batch.layer(skin.solid_material())
	var x0: float = center.x - size.x * 0.5
	var x1: float = center.x + size.x * 0.5
	var half_lane: float = minf(x1 - lane_x, lane_x - x0)
	var left_ledge: bool = x0 < lane_x - half_lane - 0.01
	var right_ledge: bool = x1 > lane_x + half_lane + 0.01
	var hw: float = roof_half_width(half_lane * 2.0)
	var t0: float = lane_x - hw
	var t1: float = lane_x + hw
	var near_d: float = -(center.z + size.z * 0.5)
	var far_d: float = -(center.z - size.z * 0.5)
	var lip_n: float = minf(EDGE_LIP, size.z * 0.4) if edge_start else 0.0
	var lip_f: float = minf(EDGE_LIP, size.z * 0.4) if edge_end else 0.0
	var a: float = near_d + lip_n
	var b: float = far_d - lip_f
	var lane_key: int = MeshKit.key(lane_x)
	var unit: float = carriage_unit(lane_key)

	# The carriages' roofs and what joins them (carriage_plan()).
	var plan: Dictionary = carriage_plan(lane_x, a, b, edge_start, edge_end)
	for j: Dictionary in plan["joints"]:
		var g: float = j["at"]
		if j["kind"] == GANGWAY:
			_gangway(s, t0, t1, g)
		else:
			s.rect(Vector3(t0 + SHOULDER, 0.003, -g + 0.03), Vector3(t1 - t0 - SHOULDER * 2.0, 0, 0), Vector3(0, 0, -0.06),
				skin.joint_color)
	for r: Dictionary in plan["roofs"]:
		var r0: float = r["from"]
		var r1: float = r["to"]
		_roof(s, t0, t1, r0, r1, r["start"], unit, lane_key, r["cell"], edge_start and r0 <= a + 0.001,
			edge_end and r1 >= b - 0.001, a, b)

	# The walkway along the building face beside an outer lane, flush with the roofs.
	if left_ledge:
		_ledge(s, x0, t0, near_d, far_d, lip_n, lip_f)
	if right_ledge:
		_ledge(s, t1, x1, near_d, far_d, lip_n, lip_f)
	# The carriages' sides, in the shade under the roofs: seen only through a neighbouring lane's gap
	# (the side under a walkway never is).
	var shade: Color = skin.gap_inside_color
	var depth: float = skin.train_depth
	for side: float in [-1.0, 1.0]:
		if (side < 0.0 and left_ledge) or (side > 0.0 and right_ledge):
			continue
		var x: float = lane_x + side * hw
		if side < 0.0:
			s.rect(Vector3(x, -depth, -far_d), Vector3(0, 0, far_d - near_d), Vector3(0, depth - SHOULDER_DROP, 0), shade, 0.0,
				MeshKit.PAT_CORP_UNDER, Vector2.ZERO, Vector2.ONE, 1.0)
		else:
			s.rect(Vector3(x, -depth, -near_d), Vector3(0, 0, -(far_d - near_d)), Vector3(0, depth - SHOULDER_DROP, 0), shade,
				0.0, MeshKit.PAT_CORP_UNDER, Vector2.ZERO, Vector2.ONE, 1.0)
	# The ends at gaps: the orange edge on the roof and along the top of the carriage's end, which drops
	# into the dark.
	var e0: float = x0 if left_ledge else t0
	var e1: float = x1 if right_ledge else t1
	if edge_start:
		_edge(s, e0, e1, t0, t1, near_d, lip_n, 1.0)
	if edge_end:
		_edge(s, e0, e1, t0, t1, far_d, lip_f, -1.0)


## The length of the carriages on the lane keyed `lane_key` (each lane its own, so gangways don't line
## up across the track).
func carriage_unit(lane_key: int) -> float:
	return skin.carriage_length * (0.9 + 0.2 * MeshKit.hash01(lane_key, 11))


## Where the carriages' grid lines lie in the lane centred on lane_x: at carriage_offset() + k *
## carriage_unit().
func carriage_offset(lane_key: int) -> float:
	return MeshKit.hash01(lane_key, 12) * carriage_unit(lane_key)


## The carriages on the roof of a floor piece whose roof runs from a to b (track distances) in the lane
## centred on lane_x, with a gap at a (edge_start) and at b (edge_end): {"roofs": the stretches of roof,
## each {"from", "to", "cell": the carriage's grid cell (carriage()), "start": where that cell starts},
## "joints": what joins them, each {"at": a grid line, "kind": GANGWAY or SEAM}}. The carriages sit on
## the lane's grid; what sits on a grid line is the business of the piece holding it (_joint_at): a
## gangway, a thin seam where a chunk cut leaves no room for one, or nothing near a gap's edge, where
## the short stub between the line and the edge belongs to the carriage on the line's other side.
func carriage_plan(lane_x: float, a: float, b: float, edge_start: bool, edge_end: bool) -> Dictionary:
	var lane_key: int = MeshKit.key(lane_x)
	var unit: float = carriage_unit(lane_key)
	var offset: float = carriage_offset(lane_key)
	var roofs: Array[Dictionary] = []
	var joints: Array[Dictionary] = []
	var k: int = floori((a - offset) / unit)
	var d: float = a
	var prev_cell: int = k
	while d < b - 0.001:
		var g0: float = offset + k * unit
		var g1: float = g0 + unit
		var d1: float = minf(g1, b)
		var cell: int = k
		if g0 > a + 0.001 and _joint_at(g0, a, b, edge_start, edge_end) == NONE:
			# No joint on the line: the carriage before it runs on to the gap.
			cell = prev_cell
		elif edge_start and g0 <= a + 0.001 and g1 < b - 0.001 and _joint_at(g1, a, b, edge_start, edge_end) == NONE:
			# The stub from the gap's edge to a line with no joint is the next carriage's end.
			cell = k + 1
		prev_cell = cell
		var r0: float = d
		var r1: float = d1
		if g0 > a + 0.001 and _joint_at(g0, a, b, edge_start, edge_end) == GANGWAY:
			r0 = g0 + JOINT_HALF
		if g1 < b - 0.001:
			var kind: int = _joint_at(g1, a, b, edge_start, edge_end)
			if kind == GANGWAY:
				r1 = g1 - JOINT_HALF
			if kind != NONE:
				joints.append({"at": g1, "kind": kind})
		if r1 > r0 + 0.001:
			roofs.append({"from": r0, "to": r1, "cell": cell, "start": offset + cell * unit})
		d = d1
		k += 1
	return {"roofs": roofs, "joints": joints}


## What the piece whose roof runs from a to b draws on the grid line at g: nothing within GAP_MARGIN of
## a gap's edge (edge_start at a, edge_end at b), a thin seam where a gangway would cross one of its
## ends that is a chunk cut (the next chunk's piece can't draw its other half), else a gangway. A piece
## end that isn't a gap's edge is always a chunk cut (TrackBuilder), so both neighbours agree.
func _joint_at(g: float, a: float, b: float, edge_start: bool, edge_end: bool) -> int:
	if (edge_start and g - a < GAP_MARGIN) or (edge_end and b - g < GAP_MARGIN):
		return NONE
	if g - JOINT_HALF < a or g + JOINT_HALF > b:
		return SEAM
	return GANGWAY


## The kind of carriage in grid cell `cell` of a lane: [style (EXPRESS or FREIGHT), roof colour,
## whether the brand's mark is painted on it, a seed 0-63]. Runs of RUN carriages share a kind and
## a colour.
func carriage(lane_key: int, cell: int) -> Array:
	var run: int = floori(float(cell) / RUN)
	var military: bool = MeshKit.hash01(lane_key, run, 21) < skin.military_car_share
	var colors: PackedColorArray = skin.military_roof_colors if military else skin.roof_colors
	var color: Color = colors[MeshKit.hash_i(lane_key, run, 22) % colors.size()]
	var logo: bool = MeshKit.hash01(lane_key, cell, 23) < skin.roof_logo_share
	return [FREIGHT if military else EXPRESS, color, logo, MeshKit.hash_i(lane_key, cell, 24) % 64]


## One carriage's roof from d0 to d1 (its grid cell starts at g0 and is `unit` long): the roof between
## its shoulders (UV.x -1 to 1 across the train, UV.y metres from the cell's start) and the shoulders.
## A painted mark is left off where a gap's edge (a, b, at the piece's gap ends) would cut it.
func _roof(s: MeshLayer, t0: float, t1: float, d0: float, d1: float, g0: float, unit: float, lane_key: int, cell: int,
		at_start: bool, at_end: bool, a: float, b: float) -> void:
	var kind: Array = carriage(lane_key, cell)
	var logo: bool = kind[2]
	var mid: float = g0 + unit * 0.5
	var reach: float = (t1 - t0) * 0.5
	if logo and ((at_start and mid - reach < a) or (at_end and mid + reach > b)):
		logo = false
	var param: float = float(int(kind[0]) + (4 if logo else 0) + 8 * int(kind[3]) + 512 * roundi(unit * 10.0))
	var color: Color = kind[1]
	var sx: float = SHOULDER
	s.rect(Vector3(t0 + sx, 0, -d0), Vector3(t1 - t0 - sx * 2.0, 0, 0), Vector3(0, 0, -(d1 - d0)), color, 0.0,
		MeshKit.PAT_CORP_ROOF, Vector2(-1.0 + 2.0 * sx / (t1 - t0), d0 - g0), Vector2(1.0 - 2.0 * sx / (t1 - t0), d1 - g0), param)
	var rim: Color = color.darkened(0.22)
	s.rect(Vector3(t1 - sx, 0, -d0), Vector3(sx, -SHOULDER_DROP, 0), Vector3(0, 0, -(d1 - d0)), rim)
	s.rect(Vector3(t0, -SHOULDER_DROP, -d0), Vector3(sx, SHOULDER_DROP, 0), Vector3(0, 0, -(d1 - d0)), rim)


## A gangway between two carriages at grid line g: a slightly recessed band of grey bellows across the
## train (never as dark as a gap's inside, so it never reads as a hole) with its folds as fine dark
## lines, and a flush cover plate bridging it.
func _gangway(s: MeshLayer, t0: float, t1: float, g: float) -> void:
	var z: float = -g
	var w: float = t1 - t0
	var bellows: Color = skin.joint_color
	s.rect(Vector3(t0, -0.04, z + JOINT_HALF), Vector3(w, 0, 0), Vector3(0, 0, -JOINT_HALF * 2.0), bellows)
	# The carriages' roof ends, a crisp lip either side of the band.
	for e: float in [z + JOINT_HALF, z - JOINT_HALF]:
		var facing: float = 1.0 if e < z else -1.0
		if facing > 0.0:
			s.rect(Vector3(t0 + SHOULDER, -0.04, e), Vector3(w - SHOULDER * 2.0, 0, 0), Vector3(0, 0.04, 0), bellows.lightened(0.2))
		else:
			s.rect(Vector3(t1 - SHOULDER, -0.04, e), Vector3(-(w - SHOULDER * 2.0), 0, 0), Vector3(0, 0.04, 0), bellows.lightened(0.2))
	for i: int in 4:
		var fz: float = z - JOINT_HALF + (float(i) + 0.5) * JOINT_HALF * 2.0 / 4.0
		s.rect(Vector3(t0, -0.035, fz + 0.012), Vector3(w, 0, 0), Vector3(0, 0, -0.024), bellows.darkened(0.45))
	var plate: float = minf(JOINT_PLATE, w * 0.5 - SHOULDER)
	var cx: float = (t0 + t1) * 0.5
	s.box(Vector3(cx, -0.015, z), Vector3(plate * 2.0, 0.03, JOINT_HALF * 2.0 + 0.1), skin.ledge_color, 0.0,
		MeshKit.PAT_PLAIN, MeshKit.FACE_PY | MeshKit.FACE_PZ | MeshKit.FACE_NZ)


## The walkway along the building face between x0 and x1 (world x), flush with the roofs: a brushed
## steel plate with a pale line along its lane-side edge. It ends where the lane's floor ends.
func _ledge(s: MeshLayer, x0: float, x1: float, near_d: float, far_d: float, lip_n: float, lip_f: float) -> void:
	var a: float = near_d + lip_n
	var b: float = far_d - lip_f
	if b <= a:
		return
	s.rect(Vector3(x0, 0, -a), Vector3(x1 - x0, 0, 0), Vector3(0, 0, -(b - a)), skin.ledge_color, 0.0, MeshKit.PAT_CORP_PLATE,
		Vector2.ZERO, Vector2.ONE, 2.0)


## Where the train ends at distance d (facing the player when facing = 1, away when -1): the orange
## lip on the roof (and the walkway beside an outer lane, e0 to e1) right at the collision edge, the
## strip along the top of the carriage's end below it, and the end itself dropping into the dark.
func _edge(s: MeshLayer, e0: float, e1: float, t0: float, t1: float, d: float, lip: float, facing: float) -> void:
	var z: float = -d
	var edge: Color = skin.gap_edge_color
	var shade: Color = skin.gap_inside_color
	var depth: float = skin.train_depth
	var strip_y: float = -STRIP_TOP - STRIP_HEIGHT
	var w: float = e1 - e0
	if facing > 0.0:
		s.rect(Vector3(e0, 0, z), Vector3(w, 0, 0), Vector3(0, 0, -lip), edge, LIP_GLOW)
		s.rect(Vector3(t0, -depth, z), Vector3(t1 - t0, 0, 0), Vector3(0, depth, 0), shade, 0.0, MeshKit.PAT_CORP_UNDER)
		s.rect(Vector3(e0, strip_y, z + 0.004), Vector3(w, 0, 0), Vector3(0, STRIP_HEIGHT, 0), edge, STRIP_GLOW)
		for x: Array in [[e0, t0], [t1, e1]]:
			if x[1] - x[0] > 0.01:
				s.rect(Vector3(x[0], -0.3, z), Vector3(x[1] - x[0], 0, 0), Vector3(0, 0.3, 0), shade, 0.0, MeshKit.PAT_CORP_UNDER)
	else:
		s.rect(Vector3(e0, 0, z + lip), Vector3(w, 0, 0), Vector3(0, 0, -lip), edge, LIP_GLOW)
		s.rect(Vector3(t1, -depth, z), Vector3(-(t1 - t0), 0, 0), Vector3(0, depth, 0), shade, 0.0, MeshKit.PAT_CORP_UNDER)
		s.rect(Vector3(e1, strip_y, z - 0.004), Vector3(-w, 0, 0), Vector3(0, STRIP_HEIGHT, 0), edge, STRIP_GLOW)
		for x: Array in [[e0, t0], [t1, e1]]:
			if x[1] - x[0] > 0.01:
				s.rect(Vector3(x[1], -0.3, z), Vector3(-(x[1] - x[0]), 0, 0), Vector3(0, 0.3, 0), shade, 0.0, MeshKit.PAT_CORP_UNDER)


## The trench under the trains for one chunk: a guideway beam under every lane on its piers, the
## trench's walls and floor far below, all in deep shade, and the drift of grit, drizzle and speed
## streaks over the roofs (GDD §5 motion effects). None of it belongs to a lane, so the skin adds it
## to the left wall's mesh. `lane_width` comes from the floor pieces.
func below(batch: MeshBatch, half_width: float, lane_width: float, start: float, end: float) -> void:
	var s: MeshLayer = batch.layer(skin.solid_material())
	var shade: Color = skin.gap_inside_color
	var floor_y: float = -skin.trench_depth
	s.rect(Vector3(-half_width, floor_y, -start), Vector3(half_width * 2.0, 0, 0), Vector3(0, 0, -(end - start)), shade, 0.0,
		MeshKit.PAT_CORP_UNDER, Vector2.ZERO, Vector2.ONE, 2.0)
	for side: float in [-1.0, 1.0]:
		var x: float = side * half_width
		if side < 0.0:
			s.rect(Vector3(x, floor_y, -end), Vector3(0, 0, end - start), Vector3(0, -floor_y, 0), shade, 0.0,
				MeshKit.PAT_CORP_UNDER, Vector2.ZERO, Vector2.ONE, 1.0)
		else:
			s.rect(Vector3(x, floor_y, -start), Vector3(0, 0, -(end - start)), Vector3(0, -floor_y, 0), shade, 0.0,
				MeshKit.PAT_CORP_UNDER, Vector2.ZERO, Vector2.ONE, 1.0)
	# One guideway per lane (lanes from the street's width: its margin to the walls is under half a lane).
	var lanes: int = maxi(1, floori(half_width * 2.0 / lane_width))
	var top: float = -skin.guideway_depth
	var mid: float = (start + end) * 0.5
	for i: int in lanes:
		var lx: float = (float(i) - (lanes - 1) * 0.5) * lane_width
		s.box(Vector3(lx, top - BEAM_HEIGHT * 0.5, -mid), Vector3(BEAM_WIDTH, BEAM_HEIGHT, end - start), shade, 0.0,
			MeshKit.PAT_CORP_UNDER, MeshKit.FACE_PY | MeshKit.FACE_PX | MeshKit.FACE_NX, 3.0)
		var p: float = ceilf(start / PIER_SPACING) * PIER_SPACING
		while p < end:
			s.box(Vector3(lx, (top - BEAM_HEIGHT + floor_y) * 0.5, -p), Vector3(BEAM_WIDTH * 0.8, top - BEAM_HEIGHT - floor_y, 1.0),
				shade, 0.0, MeshKit.PAT_CORP_UNDER, MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PZ, 3.0)
			p += PIER_SPACING
	MeshKit.drift_particles(batch.layer(skin.drift_material()), start, end, TrackBuilder.CHUNK_LENGTH, half_width - 0.7,
		7.0, skin.dust_count, skin.scrap_count, skin.streak_count,
		PackedColorArray([skin.dust_color, skin.scrap_color, skin.streak_color]))

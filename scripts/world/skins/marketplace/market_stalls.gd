class_name MarketStalls
extends RefCounted
## Market stalls for the Marketplace floor (MarketplaceSkin). A floor segment is a row of stall
## roofs along its lane: canvas in tans and creams, blue awnings (some striped), corrugated tin.
## Stalls sit on a grid of slots per lane (MeshKit.lot_run: a stall covers 1–3 slots), so a stall cut
## by a chunk boundary continues seamlessly in the next chunk. The roof's shape, its scalloped hem,
## the frame pole across each stall's start (the still floor's own motion cue, GDD §5) and the
## valleys along the lanes are all drawn by the kit shader (PAT_CANVAS, PAT_TIN), so a stall is one
## quad. The running surface is flat (y = 0) and nothing stands on it, so nothing looks like an
## obstacle.
## Where a gap borders the segment, the roof ends in the orange edge glow right on the collision
## edge; below it the stall's face drops to the market floor far below: the scalloped valance, an
## upper storey of boards or curtains, a counter heaped with goods under a warm lamp (PAT_STALL).
## Every segment also carries stall sides along its lane edges, hidden under the neighbouring lane
## unless that lane has a gap. Nothing round or grated sits on the roofs: in other zones, manholes
## are sewer-screech lairs (GDD §9.5).
## Chunk space: x across, y up (roofs at y = 0), z = -distance.

const EDGE_LIP: float = 0.18

enum Roof { CANVAS, AWNING, TIN }

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: MarketplaceSkin:
	get:
		return _skin.get_ref() as MarketplaceSkin
var _skin: WeakRef


func _init(p_skin: MarketplaceSkin) -> void:
	_skin = weakref(p_skin)


## Adds one lane's floor piece. center/size describe its collision box (top at y = 0).
func build(batch: MeshBatch, center: Vector3, size: Vector3, lane_x: float, edge_start: bool, edge_end: bool) -> void:
	if size.z < 0.01:
		return
	var s: MeshLayer = batch.layer(skin.solid_material())
	var x0: float = center.x - size.x * 0.5
	var x1: float = center.x + size.x * 0.5
	# The collision box spans the lane; the outer lanes' boxes run on to the wall (the ledge).
	var half_lane: float = minf(x1 - lane_x, lane_x - x0)
	var l0: float = lane_x - half_lane
	var l1: float = lane_x + half_lane
	var left_ledge: bool = x0 < l0 - 0.01
	var right_ledge: bool = x1 > l1 + 0.01
	var near_d: float = -(center.z + size.z * 0.5)
	var far_d: float = -(center.z - size.z * 0.5)
	var lip_n: float = minf(EDGE_LIP, size.z * 0.4) if edge_start else 0.0
	var lip_f: float = minf(EDGE_LIP, size.z * 0.4) if edge_end else 0.0
	var a: float = near_d + lip_n
	var b: float = far_d - lip_f
	var lane_key: int = MeshKit.key(lane_x)

	# The stalls' roofs, one quad each.
	var slot: float = skin.stall_slot
	var span: Vector2i = stall_at(lane_key, floori(a / slot))
	while span.x * slot < b:
		var s0: float = span.x * slot
		var s1: float = (span.y + 1) * slot
		var d0: float = maxf(s0, a)
		var d1: float = minf(s1, b)
		if d1 > d0 + 0.001:
			_roof(s, lane_key, span.x, l0, l1, s0, s1, d0, d1)
		span = stall_at(lane_key, span.y + 1)

	# The stone ledge along the building faces.
	if b > a:
		if left_ledge:
			s.rect(Vector3(x0, 0, -a), Vector3(l0 - x0, 0, 0), Vector3(0, 0, -(b - a)), skin.ledge_color, 0.0,
				MeshKit.PAT_STUCCO)
		if right_ledge:
			s.rect(Vector3(l1, 0, -a), Vector3(x1 - l1, 0, 0), Vector3(0, 0, -(b - a)), skin.ledge_color, 0.0,
				MeshKit.PAT_STUCCO)

	# Stall sides along the lane edges: seen only where the neighbouring lane has a gap.
	var depth: float = skin.market_depth
	var side_param: float = 1.0 + 4.0 * float(MeshKit.hash_i(lane_key, 3) % 97)
	if not left_ledge:
		s.rect(Vector3(x0, -depth, -far_d), Vector3(0, 0, far_d - near_d), Vector3(0, depth, 0),
			_canvas(lane_key, floori(near_d / slot)), 0.0, MeshKit.PAT_STALL, Vector2.ZERO, Vector2.ONE, side_param)
	if not right_ledge:
		s.rect(Vector3(x1, -depth, -near_d), Vector3(0, 0, -(far_d - near_d)), Vector3(0, depth, 0),
			_canvas(lane_key, floori(near_d / slot) + 1), 0.0, MeshKit.PAT_STALL, Vector2.ZERO, Vector2.ONE, side_param)

	if edge_start:
		_edge(s, x0, x1, near_d, lip_n, 1.0, lane_key)
	if edge_end:
		_edge(s, x0, x1, far_d, lip_f, -1.0, lane_key)


## The first and last slot of the stall covering `slot_index` in the lane keyed `lane_key`.
func stall_at(lane_key: int, slot_index: int) -> Vector2i:
	return MeshKit.lot_run(lane_key, slot_index, 0.45, 3, 7)


## Which roof a stall has and its colour and pattern parameter.
func roof_of(lane_key: int, first_slot: int) -> Array:
	var r: float = MeshKit.hash01(lane_key, first_slot, 11)
	var k: int = MeshKit.hash_i(lane_key, first_slot, 12)
	if r < skin.awning_share:
		var striped: bool = (k >> 4) % 5 < 3
		return [Roof.AWNING, skin.awning_colors[k % skin.awning_colors.size()], 1.0 if striped else 0.0]
	if r < skin.awning_share + skin.tin_share:
		return [Roof.TIN, skin.tin_color * Color(0.92 + 0.12 * MeshKit.hash01(k, 1), 0.92 + 0.12 * MeshKit.hash01(k, 1),
			0.92 + 0.12 * MeshKit.hash01(k, 1)), float((k >> 3) % 2)]
	var striped_across: bool = (k >> 5) % 6 == 0
	return [Roof.CANVAS, _canvas(lane_key, first_slot), 2.0 if striped_across else 0.0]


func _canvas(lane_key: int, first_slot: int) -> Color:
	return skin.canvas_colors[MeshKit.hash_i(lane_key, first_slot, 13) % skin.canvas_colors.size()]


## One stall's roof between d0 and d1 (clipped from the stall [s0, s1]), across [r0, r1].
func _roof(s: MeshLayer, lane_key: int, first_slot: int, r0: float, r1: float, s0: float, s1: float,
		d0: float, d1: float) -> void:
	var roof: Array = roof_of(lane_key, first_slot)
	var kind: int = roof[0]
	var color: Color = roof[1]
	var param: float = roof[2]
	var length: float = s1 - s0
	var uv0 := Vector2(0.0, (d0 - s0) / length)
	var uv1 := Vector2(1.0, (d1 - s0) / length)
	var pattern: int = MeshKit.PAT_TIN if kind == Roof.TIN else MeshKit.PAT_CANVAS
	# The stall's length rides along in the parameter, for the hem along its leading edge.
	param += 4.0 * roundf(length * 10.0)
	s.rect(Vector3(r0, 0, -d0), Vector3(r1 - r0, 0, 0), Vector3(0, 0, -(d1 - d0)), color, 0.0, pattern, uv0, uv1, param)


## Where the stalls end at distance d (facing the player when facing = 1, away when -1): the orange
## edge glow on the roof's edge and down the face, then the stall's face (front or back) dropping
## to the market floor, and a warm lamp over a front's counter.
func _edge(s: MeshLayer, x0: float, x1: float, d: float, lip: float, facing: float, lane_key: int) -> void:
	var z: float = -d
	var w: float = x1 - x0
	var edge: Color = skin.gap_edge_color
	var depth: float = skin.market_depth
	var slot: float = skin.stall_slot
	var slot_index: int = floori((d + 0.01 * facing) / slot)
	var first: int = stall_at(lane_key, slot_index).x
	var canvas: Color = roof_of(lane_key, first)[1]
	var seed: int = MeshKit.hash_i(lane_key, first, 17) % 997
	if facing > 0.0:
		s.rect(Vector3(x0, 0, z), Vector3(w, 0, 0), Vector3(0, 0, -lip), edge, 0.33)
		s.rect(Vector3(x0, -depth, z), Vector3(w, 0, 0), Vector3(0, depth, 0), canvas, 0.0, MeshKit.PAT_STALL,
			Vector2.ZERO, Vector2.ONE, 4.0 * float(seed))
		s.rect(Vector3(x0, -0.075, z + 0.004), Vector3(w, 0, 0), Vector3(0, 0.045, 0), edge, 0.45)
		# The stall's lamp, hanging over its counter (its glow is the bloom: a halo card would cost the
		# piece a second surface).
		var lx: float = x0 + w * (0.3 + 0.4 * MeshKit.hash01(seed, 2))
		s.box(Vector3(lx, -2.95, z + 0.25), Vector3(0.18, 0.14, 0.18), skin.lamp_color, 1.0)
	else:
		s.rect(Vector3(x0, 0, z + lip), Vector3(w, 0, 0), Vector3(0, 0, -lip), edge, 0.33)
		s.rect(Vector3(x1, -depth, z), Vector3(-w, 0, 0), Vector3(0, depth, 0), canvas, 0.0, MeshKit.PAT_STALL,
			Vector2.ZERO, Vector2.ONE, 2.0 + 4.0 * float(seed))
		s.rect(Vector3(x1, -0.075, z - 0.004), Vector3(-w, 0, 0), Vector3(0, 0.045, 0), edge, 0.45)


## The market floor far below the stalls, and the dust, paper scraps and speed streaks drifting over
## the roofs (GDD §5 motion effects), for one chunk. Neither belongs to a lane, so the skin adds them
## to the left wall's mesh.
func below(batch: MeshBatch, half_width: float, start: float, end: float) -> void:
	batch.layer(skin.solid_material()).rect(Vector3(-half_width, -skin.market_depth, -start), Vector3(half_width * 2.0, 0, 0),
		Vector3(0, 0, -(end - start)), skin.ground_color, 0.0, MeshKit.PAT_TILES)
	MeshKit.drift_particles(batch.layer(skin.drift_material()), start, end, TrackBuilder.CHUNK_LENGTH, half_width - 0.7,
		7.0, skin.dust_count, skin.scrap_count, skin.streak_count,
		PackedColorArray([skin.dust_color, skin.scrap_color, skin.streak_color]))

class_name MarketStalls
extends RefCounted
## Market stalls for the Marketplace floor (MarketplaceSkin). A floor segment is a row of stall
## roofs along its lane: canvas in tans and creams, blue awnings (some striped), corrugated tin.
## Stalls sit on a grid of slots per lane (a stall covers 1–3 slots) laid out by the kit shader
## itself (PAT_STALLS): a lane's roofs are one quad, and the shader works out, from world position,
## which stall a point belongs to, its roof, shape, scalloped hem, the frame pole across its start
## (the still floor's own motion cue, GDD §5) and the valleys along the lanes. The layout depends on
## track position alone, so stalls continue seamlessly across chunk cuts; the functions below mirror
## the shader's choices bit for bit (MeshKit.hash_i) for the faces built at gap edges. The running
## surface is flat (y = 0) and nothing stands on it, so nothing looks like an obstacle.
## Where a gap borders the segment, the roof ends in the orange edge glow right on the collision
## edge; below it the stall's face drops to the market floor far below: the scalloped valance, an
## upper storey of boards or curtains, a counter heaped with goods under a warm lamp (PAT_STALL).
## Every segment also carries stall sides along its lane edges, hidden under the neighbouring lane
## unless that lane has a gap. Nothing round or grated sits on the roofs: in other zones, manholes
## are sewer-screech lairs (GDD §9.5).
## Chunk space: x across, y up (roofs at y = 0), z = -distance.

const EDGE_LIP: float = 0.18
## Added to lane keys and slot indices before hashing, as the shader does, so they stay positive.
const KEY_OFFSET: int = 100000
## A stall starts at every third slot and at this share of the others.
const START_SHARE: float = 0.45

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
	var lane: int = lane_key(lane_x)

	# The row of stall roofs, laid out by the shader.
	if b > a:
		s.rect(Vector3(l0, 0, -a), Vector3(l1 - l0, 0, 0), Vector3(0, 0, -(b - a)), Color.WHITE, 0.0, MeshKit.PAT_STALLS,
			Vector2.ZERO, Vector2.ONE, float(lane))
		# The stone ledge along the building faces.
		if left_ledge:
			s.rect(Vector3(x0, 0, -a), Vector3(l0 - x0, 0, 0), Vector3(0, 0, -(b - a)), skin.ledge_color, 0.0,
				MeshKit.PAT_STUCCO)
		if right_ledge:
			s.rect(Vector3(l1, 0, -a), Vector3(x1 - l1, 0, 0), Vector3(0, 0, -(b - a)), skin.ledge_color, 0.0,
				MeshKit.PAT_STUCCO)

	# Stall sides along the lane edges: seen only where the neighbouring lane has a gap.
	var depth: float = skin.market_depth
	var side_param: float = 1.0 + 4.0 * float(MeshKit.hash_i(lane, 3) % 97)
	var curtain: Color = skin.canvas_colors[MeshKit.hash_i(lane, 4) % skin.canvas_colors.size()]
	if not left_ledge:
		s.rect(Vector3(x0, -depth, -far_d), Vector3(0, 0, far_d - near_d), Vector3(0, depth, 0), curtain, 0.0,
			MeshKit.PAT_STALL, Vector2.ZERO, Vector2.ONE, side_param)
	if not right_ledge:
		s.rect(Vector3(x1, -depth, -near_d), Vector3(0, 0, -(far_d - near_d)), Vector3(0, depth, 0), curtain, 0.0,
			MeshKit.PAT_STALL, Vector2.ZERO, Vector2.ONE, side_param)

	if edge_start:
		_edge(s, x0, x1, near_d, lip_n, 1.0, lane)
	if edge_end:
		_edge(s, x0, x1, far_d, lip_f, -1.0, lane)


## The key of the lane centred on lane_x for the stall layout (offset, as the shader gets it).
static func lane_key(lane_x: float) -> int:
	return MeshKit.key(lane_x) + KEY_OFFSET


## Whether a stall starts at `slot` (offset) in the lane keyed `lane`: every third slot, and by hash
## a share of the others (kit_market.gdshaderinc, mk_stall_starts()).
static func starts(lane: int, slot: int) -> bool:
	return posmod(slot, 3) == 0 or MeshKit.hash01(lane, slot, 7) < START_SHARE


## The first and last slot (offset) of the stall under the point `dist` metres along the lane.
func stall_at(lane: int, dist: float) -> Vector2i:
	var si: int = floori(dist / skin.stall_slot) + KEY_OFFSET
	var s0: int = si
	for j: int in 2:
		if starts(lane, s0):
			break
		s0 -= 1
	var s1: int = si + 1
	for j: int in 2:
		if starts(lane, s1):
			break
		s1 += 1
	return Vector2i(s0, s1 - 1)


## A stall's roof, as the shader draws it: its kind, colour and pattern (the skin passes the same
## palette to the shader: see MarketplaceSkin._solid_params()).
func roof_of(lane: int, first_slot: int) -> Array:
	var r: float = MeshKit.hash01(lane, first_slot, 11)
	var k: int = MeshKit.hash_i(lane, first_slot, 12)
	if r < skin.awning_share:
		var striped: bool = (k >> 4) % 5 < 3
		return [Roof.AWNING, skin.awning_colors[(k % 2) % skin.awning_colors.size()], 1.0 if striped else 0.0]
	if r < skin.awning_share + skin.tin_share:
		var tone: float = 0.92 + 0.12 * float((k >> 7) % 64) / 63.0
		return [Roof.TIN, skin.tin_color * Color(tone, tone, tone), float((k >> 3) % 2)]
	var striped_across: bool = (k >> 5) % 6 == 0
	var canvas: Color = skin.canvas_colors[(MeshKit.hash_i(lane, first_slot, 13) % 4) % skin.canvas_colors.size()]
	return [Roof.CANVAS, canvas, 2.0 if striped_across else 0.0]


## Where the stalls end at distance d (facing the player when facing = 1, away when -1): the orange
## edge glow on the roof's edge and down the face, then the stall's face (front or back) dropping
## to the market floor, and a warm lamp over a front's counter.
func _edge(s: MeshLayer, x0: float, x1: float, d: float, lip: float, facing: float, lane: int) -> void:
	var z: float = -d
	var w: float = x1 - x0
	var edge: Color = skin.gap_edge_color
	var depth: float = skin.market_depth
	var first: int = stall_at(lane, d + 0.01 * facing).x
	var canvas: Color = roof_of(lane, first)[1]
	var seed: int = MeshKit.hash_i(lane, first, 17) % 997
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

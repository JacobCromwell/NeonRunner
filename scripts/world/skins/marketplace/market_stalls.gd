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
## edge, as in every zone, and below it everything is in deep shade (PAT_UNDER): the stall's face
## drops into the dark toward the market floor far below, so a gap reads as a hole at a glance and
## nothing inside it is lit or looks like a roof. Every segment also carries stall sides along its
## lane edges, in the same shade, hidden under the neighbouring lane unless that lane has a gap.
## Nothing round or grated sits on the roofs: in other zones, manholes are sewer-screech lairs
## (GDD §9.5).
## Chunk space: x across, y up (roofs at y = 0), z = -distance.

## The orange edge language: a lip on the roof's last 0.18 m and a strip along the top of the face
## below it. The strip is taller and brighter than on the other zones' dark streets: against light
## roofs the glow's halo shows less, and from afar the strip is what shows of an edge.
const EDGE_LIP: float = 0.18
const LIP_GLOW: float = 0.4
const STRIP_TOP: float = 0.02
const STRIP_HEIGHT: float = 0.1
const STRIP_GLOW: float = 0.6
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

	# Stall sides along the lane edges, in the shade under the roofs: seen only where the neighbouring
	# lane has a gap.
	var depth: float = skin.market_depth
	var shade: Color = skin.gap_inside_color
	if not left_ledge:
		s.rect(Vector3(x0, -depth, -far_d), Vector3(0, 0, far_d - near_d), Vector3(0, depth, 0), shade, 0.0,
			MeshKit.PAT_UNDER, Vector2.ZERO, Vector2.ONE, 1.0)
	if not right_ledge:
		s.rect(Vector3(x1, -depth, -near_d), Vector3(0, 0, -(far_d - near_d)), Vector3(0, depth, 0), shade, 0.0,
			MeshKit.PAT_UNDER, Vector2.ZERO, Vector2.ONE, 1.0)

	if edge_start:
		_edge(s, x0, x1, near_d, lip_n, 1.0)
	if edge_end:
		_edge(s, x0, x1, far_d, lip_f, -1.0)


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
## edge glow on the roof's edge and along the top of the face, then the stall's face dropping into
## the dark.
func _edge(s: MeshLayer, x0: float, x1: float, d: float, lip: float, facing: float) -> void:
	var z: float = -d
	var w: float = x1 - x0
	var edge: Color = skin.gap_edge_color
	var depth: float = skin.market_depth
	var shade: Color = skin.gap_inside_color
	var strip_y: float = -STRIP_TOP - STRIP_HEIGHT
	if facing > 0.0:
		s.rect(Vector3(x0, 0, z), Vector3(w, 0, 0), Vector3(0, 0, -lip), edge, LIP_GLOW)
		s.rect(Vector3(x0, -depth, z), Vector3(w, 0, 0), Vector3(0, depth, 0), shade, 0.0, MeshKit.PAT_UNDER)
		s.rect(Vector3(x0, strip_y, z + 0.004), Vector3(w, 0, 0), Vector3(0, STRIP_HEIGHT, 0), edge, STRIP_GLOW)
	else:
		s.rect(Vector3(x0, 0, z + lip), Vector3(w, 0, 0), Vector3(0, 0, -lip), edge, LIP_GLOW)
		s.rect(Vector3(x1, -depth, z), Vector3(-w, 0, 0), Vector3(0, depth, 0), shade, 0.0, MeshKit.PAT_UNDER)
		s.rect(Vector3(x1, strip_y, z - 0.004), Vector3(-w, 0, 0), Vector3(0, STRIP_HEIGHT, 0), edge, STRIP_GLOW)


## The market floor far below the stalls, lost in their shade, and the dust, paper scraps and speed
## streaks drifting over the roofs (GDD §5 motion effects), for one chunk. Neither belongs to a lane,
## so the skin adds them to the left wall's mesh.
func below(batch: MeshBatch, half_width: float, start: float, end: float) -> void:
	batch.layer(skin.solid_material()).rect(Vector3(-half_width, -skin.market_depth, -start), Vector3(half_width * 2.0, 0, 0),
		Vector3(0, 0, -(end - start)), skin.gap_inside_color, 0.0, MeshKit.PAT_UNDER, Vector2.ZERO, Vector2.ONE, 2.0)
	MeshKit.drift_particles(batch.layer(skin.drift_material()), start, end, TrackBuilder.CHUNK_LENGTH, half_width - 0.7,
		7.0, skin.dust_count, skin.scrap_count, skin.streak_count,
		PackedColorArray([skin.dust_color, skin.scrap_color, skin.streak_color]))

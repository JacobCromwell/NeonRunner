class_name CasinoStreet
extends RefCounted
## The Casino's floor (CasinoSkin; task K1; the owner's reference image: a wet, dark paved street).
## A floor segment is one lane's piece of the street: flagstones in running bond with brass inlaid
## along both lane edges and across the lane every 6 m (PAT_CASINO_STREET, laid out by the kit shader
## from world position, so it continues seamlessly across chunk cuts). The running surface is flat
## (y = 0) and nothing stands on it, so nothing looks like an obstacle, and nothing round or grated
## lies on it: in the Casino, as in the Marketplace, manholes and vents are the screeches' lairs
## (GDD §9.5). The still street's motion cues are the brass bars streaming past underfoot, pools of
## lamplight every 12 m, and the dust, scraps and speed streaks drifting over it (CasinoStreet.below).
## DESIGN-TBD (docs/questions/k1.md 1, 4): the street is empty (the reference's few far-off pedestrians are left
## out: no new characters), and the gaps are open service trenches under the street: where a
## gap borders a piece, the paving ends in the orange edge glow right on the collision edge, as in every
## zone, and below it everything is deep shade (PAT_CASINO_UNDER): the trench's iron wall drops into
## the dark, far deeper than the fall that ends a run, so a gap reads as a hole at a glance and
## nothing inside it is lit or looks like a floor. Every segment also carries trench sides along its
## lane edges, in the same shade, hidden under the neighbouring lane unless that lane has a gap.
## Chunk space: x across, y up (paving at y = 0), z = -distance.

## The orange edge language: a lip on the paving's last 0.18 m and a strip along the top of the face
## below it, as on every other zone's floor.
const EDGE_LIP: float = 0.18
const LIP_GLOW: float = 0.4
const STRIP_TOP: float = 0.02
const STRIP_HEIGHT: float = 0.1
const STRIP_GLOW: float = 0.6

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: CasinoSkin:
	get:
		return _skin.get_ref() as CasinoSkin
var _skin: WeakRef


func _init(p_skin: CasinoSkin) -> void:
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
	var lip_n: float = minf(EDGE_LIP, size.z * 0.4) if edge_start else 0.0
	var lip_f: float = minf(EDGE_LIP, size.z * 0.4) if edge_end else 0.0
	var a: float = near_d + lip_n
	var b: float = far_d - lip_f
	var lane: int = lane_key(lane_x)

	# The paving, laid out by the shader.
	if b > a:
		s.rect(Vector3(l0, 0, -a), Vector3(l1 - l0, 0, 0), Vector3(0, 0, -(b - a)), skin.street_color, 0.0,
			MeshKit.PAT_CASINO_STREET, Vector2.ZERO, Vector2.ONE, float(lane))
		# The iron kerb along the building faces.
		if left_kerb:
			s.rect(Vector3(x0, 0, -a), Vector3(l0 - x0, 0, 0), Vector3(0, 0, -(b - a)), skin.iron_color, 0.0,
				MeshKit.PAT_CASINO_IRON, Vector2.ZERO, Vector2.ONE, 0.0)
		if right_kerb:
			s.rect(Vector3(l1, 0, -a), Vector3(x1 - l1, 0, 0), Vector3(0, 0, -(b - a)), skin.iron_color, 0.0,
				MeshKit.PAT_CASINO_IRON, Vector2.ZERO, Vector2.ONE, 0.0)

	# Trench sides along the lane edges, in the shade under the paving: seen only where the
	# neighbouring lane has a gap.
	var depth: float = skin.trench_depth
	var shade: Color = skin.gap_inside_color
	if not left_kerb:
		s.rect(Vector3(x0, -depth, -far_d), Vector3(0, 0, far_d - near_d), Vector3(0, depth, 0), shade, 0.0,
			MeshKit.PAT_CASINO_UNDER, Vector2.ZERO, Vector2.ONE, 1.0)
	if not right_kerb:
		s.rect(Vector3(x1, -depth, -near_d), Vector3(0, 0, -(far_d - near_d)), Vector3(0, depth, 0), shade, 0.0,
			MeshKit.PAT_CASINO_UNDER, Vector2.ZERO, Vector2.ONE, 1.0)

	if edge_start:
		_edge(s, x0, x1, near_d, lip_n, 1.0)
	if edge_end:
		_edge(s, x0, x1, far_d, lip_f, -1.0)


## The key of the lane centred on lane_x (the paving's tone seed).
static func lane_key(lane_x: float) -> int:
	return MeshKit.key(lane_x) + 100000


## Where the paving ends at distance d (facing the player when facing = 1, away when -1): the orange
## edge glow on the paving's edge and along the top of the trench wall below it, then the wall
## dropping into the dark.
func _edge(s: MeshLayer, x0: float, x1: float, d: float, lip: float, facing: float) -> void:
	var z: float = -d
	var w: float = x1 - x0
	var edge: Color = skin.gap_edge_color
	var depth: float = skin.trench_depth
	var shade: Color = skin.gap_inside_color
	var strip_y: float = -STRIP_TOP - STRIP_HEIGHT
	if facing > 0.0:
		s.rect(Vector3(x0, 0, z), Vector3(w, 0, 0), Vector3(0, 0, -lip), edge, LIP_GLOW)
		s.rect(Vector3(x0, -depth, z), Vector3(w, 0, 0), Vector3(0, depth, 0), shade, 0.0, MeshKit.PAT_CASINO_UNDER)
		s.rect(Vector3(x0, strip_y, z + 0.004), Vector3(w, 0, 0), Vector3(0, STRIP_HEIGHT, 0), edge, STRIP_GLOW)
	else:
		s.rect(Vector3(x0, 0, z + lip), Vector3(w, 0, 0), Vector3(0, 0, -lip), edge, LIP_GLOW)
		s.rect(Vector3(x1, -depth, z), Vector3(-w, 0, 0), Vector3(0, depth, 0), shade, 0.0, MeshKit.PAT_CASINO_UNDER)
		s.rect(Vector3(x1, strip_y, z - 0.004), Vector3(-w, 0, 0), Vector3(0, STRIP_HEIGHT, 0), edge, STRIP_GLOW)


## The trench floor far below the street, lost in the shade, and the dust, scraps and speed streaks
## drifting over the paving (GDD §5 motion effects), for one chunk. Neither belongs to a lane, so the
## skin adds them to the left wall's mesh.
func below(batch: MeshBatch, half_width: float, start: float, end: float) -> void:
	batch.layer(skin.solid_material()).rect(Vector3(-half_width, -skin.trench_depth, -start), Vector3(half_width * 2.0, 0, 0),
		Vector3(0, 0, -(end - start)), skin.gap_inside_color, 0.0, MeshKit.PAT_CASINO_UNDER, Vector2.ZERO, Vector2.ONE, 2.0)
	MeshKit.drift_particles(batch.layer(skin.drift_material()), start, end, TrackBuilder.CHUNK_LENGTH, half_width - 0.7,
		7.0, skin.dust_count, skin.scrap_count, skin.streak_count,
		PackedColorArray([skin.dust_color, skin.scrap_color, skin.streak_color]))

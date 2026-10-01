class_name CorporatePlaza
extends RefCounted
## An elevated corporate plaza for the Corporate floor (CorporateSkin with floor_style PLAZA; GDD §5:
## "roofs of maglev trains or plazas"). A floor segment is a stretch of the plaza's deck: large polished
## slabs in a world-space grid (PAT_CORP_PAVING, so lanes, pieces and chunk cuts join seamlessly), pale
## steel inlays along the lane boundaries, the brand's mark inlaid in dark paint now and then, and
## nothing standing on it (it's the running surface, and nothing on it may look like an obstacle).
## Gaps are open shafts through the deck to the city far below: the paving ends in the orange edge
## glow right on the collision edge, as in every zone, with a strip along the top of the deck's cut
## face, and everything below (the deck's faces, the shaft, the lower level) is in deep shade
## (PAT_CORP_UNDER), so a gap reads as a hole at a glance. The plaza stands still, so drifting grit,
## drizzle and speed streaks carry the sense of speed (GDD §5, proposed).
## Chunk space: x across, y up (the deck at y = 0), z = -distance.

const EDGE_LIP: float = CorporateTrains.EDGE_LIP
const LIP_GLOW: float = CorporateTrains.LIP_GLOW
const STRIP_TOP: float = CorporateTrains.STRIP_TOP
const STRIP_HEIGHT: float = CorporateTrains.STRIP_HEIGHT
const STRIP_GLOW: float = CorporateTrains.STRIP_GLOW
## The brand's mark inlaid in a lane: one slot per this many metres, some empty.
const INLAY_SPACING: float = 36.0

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: CorporateSkin:
	get:
		return _skin.get_ref() as CorporateSkin
var _skin: WeakRef


func _init(p_skin: CorporateSkin) -> void:
	_skin = weakref(p_skin)


## Adds one lane's floor piece. center/size describe its collision box (top at y = 0).
func build(batch: MeshBatch, center: Vector3, size: Vector3, lane_x: float, edge_start: bool, edge_end: bool) -> void:
	if size.z < 0.01:
		return
	var s: MeshLayer = batch.layer(skin.solid_material())
	var x0: float = center.x - size.x * 0.5
	var x1: float = center.x + size.x * 0.5
	var half_lane: float = minf(x1 - lane_x, lane_x - x0)
	var l0: float = lane_x - half_lane
	var l1: float = lane_x + half_lane
	var left_wall: bool = x0 < l0 - 0.01
	var right_wall: bool = x1 > l1 + 0.01
	var near_d: float = -(center.z + size.z * 0.5)
	var far_d: float = -(center.z - size.z * 0.5)
	var lip_n: float = minf(EDGE_LIP, size.z * 0.4) if edge_start else 0.0
	var lip_f: float = minf(EDGE_LIP, size.z * 0.4) if edge_end else 0.0
	var a: float = near_d + lip_n
	var b: float = far_d - lip_f
	var paving: Color = skin.paving_colors[0]
	if b > a:
		# The paving across the whole collision box, inlays along the lane boundaries (not along a wall).
		var flags: int = (0 if left_wall else 1) | (0 if right_wall else 2)
		var u0: float = -1.0 - 2.0 * (l0 - x0) / (l1 - l0)
		var u1: float = 1.0 + 2.0 * (x1 - l1) / (l1 - l0)
		s.rect(Vector3(x0, 0, -a), Vector3(x1 - x0, 0, 0), Vector3(0, 0, -(b - a)), paving, 0.0, MeshKit.PAT_CORP_PAVING,
			Vector2(u0, 0.0), Vector2(u1, 1.0), float(flags))
		_inlays(s, lane_x, half_lane, a, b)
	# The deck's sides, in the shade: seen only where the neighbouring lane has a gap.
	var shade: Color = skin.gap_inside_color
	var floor_y: float = -skin.trench_depth
	if not left_wall:
		s.rect(Vector3(x0, floor_y, -far_d), Vector3(0, 0, far_d - near_d), Vector3(0, -floor_y, 0), shade, 0.0,
			MeshKit.PAT_CORP_UNDER, Vector2.ZERO, Vector2.ONE, 1.0)
	if not right_wall:
		s.rect(Vector3(x1, floor_y, -near_d), Vector3(0, 0, -(far_d - near_d)), Vector3(0, -floor_y, 0), shade, 0.0,
			MeshKit.PAT_CORP_UNDER, Vector2.ZERO, Vector2.ONE, 1.0)
	if edge_start:
		_edge(s, x0, x1, near_d, lip_n, 1.0)
	if edge_end:
		_edge(s, x0, x1, far_d, lip_f, -1.0)


## The brand's mark inlaid in dark paint in the middle of the lane, now and then (non-glowing, so it
## never reads as a pad or a credit), whole or not at all within [a, b].
func _inlays(s: MeshLayer, lane_x: float, half_lane: float, a: float, b: float) -> void:
	var lane_key: int = MeshKit.key(lane_x)
	var e: float = minf(half_lane * 1.3, 2.2)
	var k: int = floori(a / INLAY_SPACING)
	while float(k) * INLAY_SPACING < b:
		var at: float = (float(k) + 0.5) * INLAY_SPACING
		var slot: int = k
		k += 1
		if MeshKit.hash01(lane_key, slot, 61) > 0.3 or at - e * 0.5 < a or at + e * 0.5 > b:
			continue
		var m: float = 1.0
		s.rect(Vector3(lane_x - e * 0.5, 0.004, -(at - e * 0.5)), Vector3(e, 0, 0), Vector3(0, 0, -e), skin.brand_paint_color,
			0.0, MeshKit.PAT_CORP_LOGO, Vector2(-m, -m), Vector2(m, m), 2.0)


## Where the deck ends at distance d (facing the player when facing = 1, away when -1): the orange lip
## on the paving right at the collision edge, the strip along the top of the cut face, and the face
## dropping into the shaft.
func _edge(s: MeshLayer, x0: float, x1: float, d: float, lip: float, facing: float) -> void:
	var z: float = -d
	var w: float = x1 - x0
	var edge: Color = skin.gap_edge_color
	var shade: Color = skin.gap_inside_color
	var strip_y: float = -STRIP_TOP - STRIP_HEIGHT
	var floor_y: float = -skin.trench_depth
	if facing > 0.0:
		s.rect(Vector3(x0, 0, z), Vector3(w, 0, 0), Vector3(0, 0, -lip), edge, LIP_GLOW)
		s.rect(Vector3(x0, floor_y, z), Vector3(w, 0, 0), Vector3(0, -floor_y, 0), shade, 0.0, MeshKit.PAT_CORP_UNDER)
		s.rect(Vector3(x0, strip_y, z + 0.004), Vector3(w, 0, 0), Vector3(0, STRIP_HEIGHT, 0), edge, STRIP_GLOW)
	else:
		s.rect(Vector3(x0, 0, z + lip), Vector3(w, 0, 0), Vector3(0, 0, -lip), edge, LIP_GLOW)
		s.rect(Vector3(x1, floor_y, z), Vector3(-w, 0, 0), Vector3(0, -floor_y, 0), shade, 0.0, MeshKit.PAT_CORP_UNDER)
		s.rect(Vector3(x1, strip_y, z - 0.004), Vector3(-w, 0, 0), Vector3(0, STRIP_HEIGHT, 0), edge, STRIP_GLOW)


## A floor cut through the plaza (task B4; GDD §9.9): the deck sliced open down the lane (the track hides
## the paving as the cut runs, FloorCutSection), an open shaft to the lower level like any gap: the
## deck's cut faces in the shade down to the lower level, the orange lips on the paving right at the
## cut's edges and a strip along the top of each cut face. Nothing in it is lit.
func cut(parent: Node3D, section: FloorCutSection) -> void:
	ZoneSkin.standard_floor_cut(parent, section, skin.solid_material(), skin.glow_material(), {
		"edge": skin.gap_edge_color, "inside": skin.gap_inside_color, "pattern": MeshKit.PAT_CORP_UNDER,
		"params": [0.0, 1.0, 2.0], "depth": skin.trench_depth, "bottom": false,
		"lip": EDGE_LIP, "lip_glow": LIP_GLOW, "strip_glow": STRIP_GLOW, "halo": 0.0,
	})


## The lower level far below the plaza, lost in the dark, its walls at the building faces, and the
## drifting grit, drizzle and speed streaks over the deck (GDD §5 motion effects), for one chunk. None
## of it belongs to a lane, so the skin adds it to the left wall's mesh.
func below(batch: MeshBatch, half_width: float, start: float, end: float) -> void:
	var s: MeshLayer = batch.layer(skin.solid_material())
	var shade: Color = skin.gap_inside_color
	var floor_y: float = -skin.trench_depth
	s.rect(Vector3(-half_width, floor_y, -start), Vector3(half_width * 2.0, 0, 0), Vector3(0, 0, -(end - start)), shade, 0.0,
		MeshKit.PAT_CORP_UNDER, Vector2.ZERO, Vector2.ONE, 2.0)
	s.rect(Vector3(-half_width, floor_y, -end), Vector3(0, 0, end - start), Vector3(0, -floor_y, 0), shade, 0.0,
		MeshKit.PAT_CORP_UNDER, Vector2.ZERO, Vector2.ONE, 1.0)
	s.rect(Vector3(half_width, floor_y, -start), Vector3(0, 0, -(end - start)), Vector3(0, -floor_y, 0), shade, 0.0,
		MeshKit.PAT_CORP_UNDER, Vector2.ZERO, Vector2.ONE, 1.0)
	MeshKit.drift_particles(batch.layer(skin.drift_material()), start, end, TrackBuilder.CHUNK_LENGTH, half_width - 0.7,
		7.0, skin.dust_count, skin.scrap_count, skin.streak_count,
		PackedColorArray([skin.dust_color, skin.scrap_color, skin.streak_color]))

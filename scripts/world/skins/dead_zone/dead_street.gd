class_name DeadStreet
extends RefCounted
## The rubble street of the Dead Zone (DeadZoneSkin, GDD §5: "a rubble street", proposed and agreed).
## A floor segment is one lane's stretch of it: the road's surface broken into plates under pale ash,
## scattered rubble and worn lane lines (MeshKit.PAT_DZ_STREET, laid out from world position, so lanes,
## pieces and chunk cuts join seamlessly). The running surface is flat (y = 0) and the rubble on it is
## drawn, never built, so nothing on it stands up like an obstacle; the outer lanes run on to the walls
## over a gutter where the ash piles up.
## Where a hole borders the segment, the street ends in the orange edge glow right on the collision
## edge (a lip on the street and a strip along the top of the cut below it, as bright as the
## Marketplace's and the Corporate zone's, and a soft halo along the far side), and below it there is
## only deep shade (MeshKit.PAT_DZ_UNDER in the skin's gap_inside_color) dropping into a dark void far
## below: on this near-black palette the ash-grey street's value and the orange edge carry the read of
## a hole, and nothing in one is lit or floor-like. Every segment also carries its sides along its lane
## edges in that shade, hidden under the neighbouring lane unless that lane has a hole.
## Chunk space: x across, y up (the street at y = 0), z = -distance.

## The orange edge language: a lip on the street's last 0.18 m and a strip along the top of the cut.
const EDGE_LIP: float = 0.18
const LIP_GLOW: float = 0.4
const STRIP_TOP: float = 0.02
const STRIP_HEIGHT: float = 0.1
const STRIP_GLOW: float = 0.6
## PAT_DZ_STREET's flags.
const LINE_LEFT: int = 1
const LINE_RIGHT: int = 2
const GUTTER: int = 4

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: DeadZoneSkin:
	get:
		return _skin.get_ref() as DeadZoneSkin
var _skin: WeakRef


func _init(p_skin: DeadZoneSkin) -> void:
	_skin = weakref(p_skin)


## Adds one lane's floor piece. center/size describe its collision box (top at y = 0).
func build(batch: MeshBatch, center: Vector3, size: Vector3, lane_x: float, edge_start: bool, edge_end: bool) -> void:
	if size.z < 0.01:
		return
	var s: MeshLayer = batch.layer(skin.solid_material())
	var x0: float = center.x - size.x * 0.5
	var x1: float = center.x + size.x * 0.5
	# The collision box spans the lane; the outer lanes' boxes run on to the wall (the gutter).
	var half_lane: float = minf(x1 - lane_x, lane_x - x0)
	var l0: float = lane_x - half_lane
	var l1: float = lane_x + half_lane
	var left_gutter: bool = x0 < l0 - 0.01
	var right_gutter: bool = x1 > l1 + 0.01
	var near_d: float = -(center.z + size.z * 0.5)
	var far_d: float = -(center.z - size.z * 0.5)
	var lip_n: float = minf(EDGE_LIP, size.z * 0.4) if edge_start else 0.0
	var lip_f: float = minf(EDGE_LIP, size.z * 0.4) if edge_end else 0.0
	var a: float = near_d + lip_n
	var b: float = far_d - lip_f

	if b > a:
		# The street (UV.x -1 to 1 across the lane), with worn lane lines on the sides that have neighbours.
		var flags: int = (0 if left_gutter else LINE_LEFT) | (0 if right_gutter else LINE_RIGHT)
		s.rect(Vector3(l0, 0, -a), Vector3(l1 - l0, 0, 0), Vector3(0, 0, -(b - a)), skin.road_color, 0.0,
			MeshKit.PAT_DZ_STREET, Vector2(-1, 0), Vector2(1, b - a), float(flags))
		if left_gutter:
			s.rect(Vector3(x0, 0, -a), Vector3(l0 - x0, 0, 0), Vector3(0, 0, -(b - a)), skin.gutter_color, 0.0,
				MeshKit.PAT_DZ_STREET, Vector2(-1, 0), Vector2(1, b - a), float(GUTTER))
		if right_gutter:
			s.rect(Vector3(l1, 0, -a), Vector3(x1 - l1, 0, 0), Vector3(0, 0, -(b - a)), skin.gutter_color, 0.0,
				MeshKit.PAT_DZ_STREET, Vector2(-1, 0), Vector2(1, b - a), float(GUTTER))

	# The lane's sides, in the shade under the street: seen only where the neighbouring lane has a hole.
	var depth: float = skin.void_depth
	var shade: Color = skin.gap_inside_color
	if not left_gutter:
		s.rect(Vector3(x0, -depth, -far_d), Vector3(0, 0, far_d - near_d), Vector3(0, depth, 0), shade, 0.0,
			MeshKit.PAT_DZ_UNDER, Vector2.ZERO, Vector2.ONE, 1.0)
	if not right_gutter:
		s.rect(Vector3(x1, -depth, -near_d), Vector3(0, 0, -(far_d - near_d)), Vector3(0, depth, 0), shade, 0.0,
			MeshKit.PAT_DZ_UNDER, Vector2.ZERO, Vector2.ONE, 1.0)

	if edge_start:
		_edge(s, x0, x1, near_d, lip_n, 1.0)
		if skin.edge_halo > 0.0:
			# The far side of a hole faces the approaching runner: a soft orange halo along its strip, so the
			# edge carries from afar.
			batch.layer(skin.glow_material()).rect(Vector3(x0 - 0.15, -STRIP_TOP - STRIP_HEIGHT - 0.25, -near_d + 0.05),
				Vector3(x1 - x0 + 0.3, 0, 0), Vector3(0, STRIP_HEIGHT + 0.5, 0), skin.gap_edge_color, skin.edge_halo,
				MeshKit.SHAPE_STREAK)
	if edge_end:
		_edge(s, x0, x1, far_d, lip_f, -1.0)


## Where the street breaks off at distance d (the far side of a hole, facing the player, when facing =
## 1; the near side, facing away, when -1): the orange lip on the street's edge, the strip along the
## top of the cut, and the cut dropping into the dark.
func _edge(s: MeshLayer, x0: float, x1: float, d: float, lip: float, facing: float) -> void:
	var z: float = -d
	var w: float = x1 - x0
	var edge: Color = skin.gap_edge_color
	var depth: float = skin.void_depth
	var shade: Color = skin.gap_inside_color
	var strip_y: float = -STRIP_TOP - STRIP_HEIGHT
	if facing > 0.0:
		s.rect(Vector3(x0, 0, z), Vector3(w, 0, 0), Vector3(0, 0, -lip), edge, LIP_GLOW)
		s.rect(Vector3(x0, -depth, z), Vector3(w, 0, 0), Vector3(0, depth, 0), shade, 0.0, MeshKit.PAT_DZ_UNDER)
		s.rect(Vector3(x0, strip_y, z + 0.004), Vector3(w, 0, 0), Vector3(0, STRIP_HEIGHT, 0), edge, STRIP_GLOW)
	else:
		s.rect(Vector3(x0, 0, z + lip), Vector3(w, 0, 0), Vector3(0, 0, -lip), edge, LIP_GLOW)
		s.rect(Vector3(x1, -depth, z), Vector3(-w, 0, 0), Vector3(0, depth, 0), shade, 0.0, MeshKit.PAT_DZ_UNDER)
		s.rect(Vector3(x1, strip_y, z - 0.004), Vector3(-w, 0, 0), Vector3(0, STRIP_HEIGHT, 0), edge, STRIP_GLOW)


## The void's floor, dark and deep below the street, and the ash, smoke and speed streaks drifting over
## the street (the still floor's motion cues), for one chunk. Neither belongs to a lane, so the skin
## adds them to the left wall's mesh.
func below(batch: MeshBatch, half_width: float, start: float, end: float) -> void:
	batch.layer(skin.solid_material()).rect(Vector3(-half_width, -skin.void_depth, -start), Vector3(half_width * 2.0, 0, 0),
		Vector3(0, 0, -(end - start)), skin.gap_inside_color, 0.0, MeshKit.PAT_DZ_UNDER, Vector2.ZERO, Vector2.ONE, 2.0)
	MeshKit.drift_particles(batch.layer(skin.drift_material()), start, end, TrackBuilder.CHUNK_LENGTH, half_width - 0.7,
		8.0, skin.ash_count, 0, skin.streak_count,
		PackedColorArray([skin.ash_flake_color, Color.TRANSPARENT, skin.streak_color, skin.smoke_puff_color]), skin.smoke_count)

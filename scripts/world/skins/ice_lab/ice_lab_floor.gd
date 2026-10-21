class_name IceLabFloor
extends RefCounted
## The Ice Lab's floor (IceLabSkin, GDD §5: "the floor is steel grating catwalks with packed snow and ice; the gaps are drops between
## catwalks into a frozen depth"). A floor segment is one lane's stretch of catwalk: every lane steel grating in panels with packed
## snow lying in drifts along its edges and ice here and there (MeshKit.PAT_IL_GRATING, laid out from world position, so lanes, pieces
## and chunk cuts join seamlessly; a dark seam between lanes so the lanes read), the outer lanes running on to the wall over a gutter
## where the snow piles deeper. The running surface is flat (y = 0) and everything on it is drawn, never built, so nothing on it
## stands up like an obstacle.
## Where a hole borders the segment, the catwalk ends in the orange edge glow right on the collision edge (a lip on the floor and a
## strip along the top of the cut below it, and a soft halo along the far side, as in every zone), and below it there is only deep
## shade (PAT_IL_UNDER in the skin's gap_inside_color: the catwalk's truss ghosted in, hoar furring near the top) dropping to a floor
## of dark ice far below: the grating's slots are far lighter than any hole. Every segment also carries its sides along its lane edges
## in that shade, hidden under the neighbouring lane unless that lane has a hole.
## Chunk space: x across, y up (the floor at y = 0), z = -distance.

## The orange edge language: a lip on the floor's last 0.18 m and a strip along the top of the cut.
const EDGE_LIP: float = 0.18
const LIP_GLOW: float = 0.4
const STRIP_TOP: float = 0.02
const STRIP_HEIGHT: float = 0.1
const STRIP_GLOW: float = 0.6
## Where the grating pattern reads a half width in its parameter (kit_ice_lab.gdshaderinc, il_half_width): above the three bits of flags.
const WIDTH_SHIFT: int = 3

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: IceLabSkin:
	get:
		return _skin.get_ref() as IceLabSkin
var _skin: WeakRef


func _init(p_skin: IceLabSkin) -> void:
	_skin = weakref(p_skin)


## The half width of the lane a floor piece belongs to: its box reaches at least this far to each side of the lane's middle (an outer
## lane's box runs on to the wall, so the nearer side counts). The pattern takes the lane's width from here and never from the level's
## tuning, which a skin is not given.
static func half_lane(center: Vector3, size: Vector3, lane_x: float) -> float:
	return minf(center.x + size.x * 0.5 - lane_x, lane_x - (center.x - size.x * 0.5))


## A floor pattern's parameter: the half width of what it is drawn on to the centimetre, over `flags` (MeshKit.IL_*).
static func half_width_param(half_width: float, flags: int = 0) -> float:
	return float((roundi(half_width * 100.0) << WIDTH_SHIFT) | flags)


## Adds one lane's floor piece. center/size describe its collision box (top at y = 0). Returns the wall face's distance from the
## track's centre when this is an outer lane (its box runs on to the wall), else 0.
func build(batch: MeshBatch, center: Vector3, size: Vector3, lane_x: float, edge_start: bool, edge_end: bool) -> float:
	if size.z < 0.01:
		return 0.0
	var s: MeshLayer = batch.layer(skin.solid_material())
	var x0: float = center.x - size.x * 0.5
	var x1: float = center.x + size.x * 0.5
	# The collision box spans the lane; the outer lanes' boxes run on to the wall (the gutter).
	var half: float = half_lane(center, size, lane_x)
	var l0: float = lane_x - half
	var l1: float = lane_x + half
	var left_gutter: bool = x0 < l0 - 0.01
	var right_gutter: bool = x1 > l1 + 0.01
	var near_d: float = -(center.z + size.z * 0.5)
	var far_d: float = -(center.z - size.z * 0.5)
	var lip_n: float = minf(EDGE_LIP, size.z * 0.4) if edge_start else 0.0
	var lip_f: float = minf(EDGE_LIP, size.z * 0.4) if edge_end else 0.0
	var a: float = near_d + lip_n
	var b: float = far_d - lip_f

	if b > a:
		var flags: int = (0 if left_gutter else MeshKit.IL_NEIGHBOUR_LEFT) | (0 if right_gutter else MeshKit.IL_NEIGHBOUR_RIGHT)
		s.rect(Vector3(l0, 0, -a), Vector3(l1 - l0, 0, 0), Vector3(0, 0, -(b - a)), skin.grating_color, 0.0,
			MeshKit.PAT_IL_GRATING, Vector2(-1, 0), Vector2(1, b - a), half_width_param(half, flags))
		# The gutter between the outer lane and the wall: the same grating under deeper snow (UV.x -1 to 1 across its width).
		if left_gutter:
			s.rect(Vector3(x0, 0, -a), Vector3(l0 - x0, 0, 0), Vector3(0, 0, -(b - a)), skin.gutter_color, 0.0,
				MeshKit.PAT_IL_GRATING, Vector2(-1, 0), Vector2(1, b - a), half_width_param((l0 - x0) * 0.5, MeshKit.IL_GUTTER))
		if right_gutter:
			s.rect(Vector3(l1, 0, -a), Vector3(x1 - l1, 0, 0), Vector3(0, 0, -(b - a)), skin.gutter_color, 0.0,
				MeshKit.PAT_IL_GRATING, Vector2(-1, 0), Vector2(1, b - a), half_width_param((x1 - l1) * 0.5, MeshKit.IL_GUTTER))

	# The lane's sides, in the shade under the catwalk: seen only where the neighbouring lane has a hole.
	var depth: float = skin.pit_depth
	var shade: Color = skin.gap_inside_color
	if not left_gutter:
		s.rect(Vector3(x0, -depth, -far_d), Vector3(0, 0, far_d - near_d), Vector3(0, depth, 0), shade, 0.0,
			MeshKit.PAT_IL_UNDER, Vector2.ZERO, Vector2.ONE, 1.0)
	if not right_gutter:
		s.rect(Vector3(x1, -depth, -near_d), Vector3(0, 0, -(far_d - near_d)), Vector3(0, depth, 0), shade, 0.0,
			MeshKit.PAT_IL_UNDER, Vector2.ZERO, Vector2.ONE, 1.0)

	if edge_start:
		_edge(s, x0, x1, near_d, lip_n, 1.0)
		if skin.edge_halo > 0.0:
			# The far side of a hole faces the approaching runner: a soft orange halo along its strip, so the edge carries from afar.
			batch.layer(skin.glow_material()).rect(Vector3(x0 - 0.15, -STRIP_TOP - STRIP_HEIGHT - 0.25, -near_d + 0.05),
				Vector3(x1 - x0 + 0.3, 0, 0), Vector3(0, STRIP_HEIGHT + 0.5, 0), skin.gap_edge_color, skin.edge_halo,
				MeshKit.SHAPE_STREAK)
	if edge_end:
		_edge(s, x0, x1, far_d, lip_f, -1.0)
	if left_gutter:
		return -x0
	if right_gutter:
		return x1
	return 0.0


## Where the catwalk breaks off at distance d (the far side of a hole, facing the player, when facing = 1; the near side, facing
## away, when -1): the orange lip on the floor's edge, the strip along the top of the cut, and the cut dropping into the dark.
func _edge(s: MeshLayer, x0: float, x1: float, d: float, lip: float, facing: float) -> void:
	var z: float = -d
	var w: float = x1 - x0
	var edge: Color = skin.gap_edge_color
	var depth: float = skin.pit_depth
	var shade: Color = skin.gap_inside_color
	var strip_y: float = -STRIP_TOP - STRIP_HEIGHT
	if facing > 0.0:
		s.rect(Vector3(x0, 0, z), Vector3(w, 0, 0), Vector3(0, 0, -lip), edge, LIP_GLOW)
		s.rect(Vector3(x0, -depth, z), Vector3(w, 0, 0), Vector3(0, depth, 0), shade, 0.0, MeshKit.PAT_IL_UNDER)
		s.rect(Vector3(x0, strip_y, z + 0.004), Vector3(w, 0, 0), Vector3(0, STRIP_HEIGHT, 0), edge, STRIP_GLOW)
	else:
		s.rect(Vector3(x0, 0, z + lip), Vector3(w, 0, 0), Vector3(0, 0, -lip), edge, LIP_GLOW)
		s.rect(Vector3(x1, -depth, z), Vector3(-w, 0, 0), Vector3(0, depth, 0), shade, 0.0, MeshKit.PAT_IL_UNDER)
		s.rect(Vector3(x1, strip_y, z - 0.004), Vector3(-w, 0, 0), Vector3(0, STRIP_HEIGHT, 0), edge, STRIP_GLOW)


## A floor cut through the catwalk (task B4; GDD §9.9): the grating split open down the lane (the track hides the floor as the cut
## runs, FloorCutSection). The floor ends in the zone's orange edge right on the collision edge (the lips on the neighbouring lanes and
## the strips along the tops of the cut, the halo on its far side), and below it only deep shade dropping to the frozen floor, like
## any hole: a few bent grating plates hang into the split from both sides (in the same shade, never lit, never level: nothing in the
## hole looks like floor).
func cut(parent: Node3D, section: FloorCutSection) -> void:
	ZoneSkin.standard_floor_cut(parent, section, skin.solid_material(), skin.glow_material(), {
		"edge": skin.gap_edge_color, "inside": skin.gap_inside_color, "pattern": MeshKit.PAT_IL_UNDER,
		"params": [0.0, 1.0, 2.0], "depth": skin.pit_depth, "bottom": false,
		"lip": EDGE_LIP, "lip_glow": LIP_GLOW, "strip_glow": STRIP_GLOW, "halo": skin.edge_halo,
	})
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(skin.solid_material())
	var shade: Color = skin.gap_inside_color
	var lane_key: int = MeshKit.key(section.lane_x)
	var d: float = section.start + 1.0
	var k: int = 0
	while d < section.end - 1.5:
		var length: float = 1.4 + 1.6 * MeshKit.hash01(lane_key, k, 71)
		for side: int in [-1, 1]:
			if MeshKit.hash01(lane_key, k, 72 + side) < 0.4:
				continue
			var x: float = section.edge_x(side) - side * (ZoneSkin.CUT_WALL_INSET + 0.02)
			var reach: float = 0.35 + 0.45 * MeshKit.hash01(lane_key, k, 74 + side)
			var drop: float = 0.5 + 0.9 * MeshKit.hash01(lane_key, k, 76 + side)
			_hanging_plate(s, x, -side, d, minf(d + length, section.end - 1.0), reach, drop, shade)
		d += length + 0.6 + 1.5 * MeshKit.hash01(lane_key, k, 78)
		k += 1
	var plates: MeshInstance3D = batch.commit(parent, "CutPlates")
	if plates != null:
		section.add_static(plates)


## One bent plate of grating hanging from the side of a split at x, leaning `inward` (+1 toward +x): from just below the floor's edge,
## `reach` metres in and `drop` metres down, between track distances d0 and d1, both faces in the shade.
func _hanging_plate(s: MeshLayer, x: float, inward: float, d0: float, d1: float, reach: float, drop: float, shade: Color) -> void:
	var top := -0.06
	var a := Vector3(x, top, -d0)
	var b := Vector3(x, top, -d1)
	var c := Vector3(x + inward * reach, top - drop, -d1 + 0.2)
	var e := Vector3(x + inward * reach * 0.8, top - drop * 0.8, -d0 - 0.15)
	# Both faces: seen from above through the hole, and from below.
	s.quad(a, b, c, e, shade, 0.0, MeshKit.PAT_IL_UNDER, 1.0)
	s.quad(a, e, c, b, shade, 0.0, MeshKit.PAT_IL_UNDER, 1.0)

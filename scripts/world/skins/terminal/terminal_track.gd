class_name TerminalTrack
extends RefCounted
## The Terminal's floor (TerminalSkin, GDD §5: "the track bed and platforms", proposed; "a couple of holes, not many"). A floor
## segment is one lane's stretch of it. Every lane but the outer two is a lane of track bed (MeshKit.PAT_TERMINAL_TRACK:
## ballast, a sleeper every 0.64 m, a pair of rails 1.44 m apart, cables snaking over it, puddles catching the lamps, a
## dark seam between lanes so the lanes read), the outer lanes the platform along each wall (PAT_TERMINAL_PLATFORM: worn
## concrete, a strip of pale studs on the edge that faces the track), all laid out from world position, so lanes, pieces and
## chunk cuts join seamlessly. The running surface is flat (y = 0) and everything on it is drawn, never built, so nothing
## on it stands up like an obstacle; the outer lanes run on to the wall over a gutter.
## Where a hole borders the segment, the track bed ends in the orange edge glow right on the collision edge (a lip on the
## floor and a strip along the top of the cut below it, and a soft halo along the far side, as in every zone), and below
## it there is only deep shade (PAT_TERMINAL_UNDER in the skin's gap_inside_color) dropping to a service level far below:
## the track bed's gravel and sleepers are far lighter than any hole. Every segment also carries its sides along its
## lane edges in that shade, hidden under the neighbouring lane unless that lane has a hole.
## DESIGN-TBD (docs/questions/o4.md item 2): which lanes are track bed and which platform (the outer two, here), and the
## rails in every lane.
## Chunk space: x across, y up (the floor at y = 0), z = -distance.

## The orange edge language: a lip on the floor's last 0.18 m and a strip along the top of the cut.
const EDGE_LIP: float = 0.18
const LIP_GLOW: float = 0.4
const STRIP_TOP: float = 0.02
const STRIP_HEIGHT: float = 0.1
const STRIP_GLOW: float = 0.6

## Where the patterns read a half width in their parameter (kit_terminal.gdshaderinc, tm_half_width): above the three bits
## the platform's flags use.
const WIDTH_SHIFT: int = 3

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: TerminalSkin:
	get:
		return _skin.get_ref() as TerminalSkin
var _skin: WeakRef


func _init(p_skin: TerminalSkin) -> void:
	_skin = weakref(p_skin)


## The half width of the lane a floor piece belongs to: its box reaches at least this far to each side of the lane's middle (an
## outer lane's box runs on to the wall, so the nearer side counts). The patterns take the lane's width from here and never
## from the level's tuning, which a skin is not given.
static func half_lane(center: Vector3, size: Vector3, lane_x: float) -> float:
	return minf(center.x + size.x * 0.5 - lane_x, lane_x - (center.x - size.x * 0.5))


## A floor pattern's parameter: the half width of what it is drawn on to the centimetre, over `flags` (PAT_TERMINAL_PLATFORM's).
static func half_width_param(half_width: float, flags: int = 0) -> float:
	return float((roundi(half_width * 100.0) << WIDTH_SHIFT) | flags)


## Adds one lane's floor piece. center/size describe its collision box (top at y = 0). Returns the wall face's distance
## from the track's centre when this is an outer lane (its box runs on to the wall), else 0.
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
		var platform: bool = left_gutter or right_gutter
		if platform:
			# An outer lane is the platform: its strip of studs lies along the edge that faces the track.
			var flags: int = MeshKit.TERMINAL_STRIP_RIGHT if left_gutter else MeshKit.TERMINAL_STRIP_LEFT
			s.rect(Vector3(l0, 0, -a), Vector3(l1 - l0, 0, 0), Vector3(0, 0, -(b - a)), skin.platform_color, 0.0,
				MeshKit.PAT_TERMINAL_PLATFORM, Vector2(-1, 0), Vector2(1, b - a), half_width_param(half, flags))
		else:
			s.rect(Vector3(l0, 0, -a), Vector3(l1 - l0, 0, 0), Vector3(0, 0, -(b - a)), skin.ballast_color, 0.0,
				MeshKit.PAT_TERMINAL_TRACK, Vector2(-1, 0), Vector2(1, b - a), half_width_param(half))
		# The gutter between the platform and the kerb, in the same concrete (UV.x -1 to 1 across its width).
		if left_gutter:
			s.rect(Vector3(x0, 0, -a), Vector3(l0 - x0, 0, 0), Vector3(0, 0, -(b - a)), skin.gutter_color, 0.0,
				MeshKit.PAT_TERMINAL_PLATFORM, Vector2(-1, 0), Vector2(1, b - a),
				half_width_param((l0 - x0) * 0.5, MeshKit.TERMINAL_GUTTER))
		if right_gutter:
			s.rect(Vector3(l1, 0, -a), Vector3(x1 - l1, 0, 0), Vector3(0, 0, -(b - a)), skin.gutter_color, 0.0,
				MeshKit.PAT_TERMINAL_PLATFORM, Vector2(-1, 0), Vector2(1, b - a),
				half_width_param((x1 - l1) * 0.5, MeshKit.TERMINAL_GUTTER))

	# The lane's sides, in the shade under the floor: seen only where the neighbouring lane has a hole.
	var depth: float = skin.pit_depth
	var shade: Color = skin.gap_inside_color
	if not left_gutter:
		s.rect(Vector3(x0, -depth, -far_d), Vector3(0, 0, far_d - near_d), Vector3(0, depth, 0), shade, 0.0,
			MeshKit.PAT_TERMINAL_UNDER, Vector2.ZERO, Vector2.ONE, 1.0)
	if not right_gutter:
		s.rect(Vector3(x1, -depth, -near_d), Vector3(0, 0, -(far_d - near_d)), Vector3(0, depth, 0), shade, 0.0,
			MeshKit.PAT_TERMINAL_UNDER, Vector2.ZERO, Vector2.ONE, 1.0)

	if edge_start:
		_edge(s, x0, x1, near_d, lip_n, 1.0)
		if skin.edge_halo > 0.0:
			# The far side of a hole faces the approaching runner: a soft orange halo along its strip, so the edge
			# carries from afar.
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


## Where the floor breaks off at distance d (the far side of a hole, facing the player, when facing = 1; the near side,
## facing away, when -1): the orange lip on the floor's edge, the strip along the top of the cut, and the cut dropping
## into the dark.
func _edge(s: MeshLayer, x0: float, x1: float, d: float, lip: float, facing: float) -> void:
	var z: float = -d
	var w: float = x1 - x0
	var edge: Color = skin.gap_edge_color
	var depth: float = skin.pit_depth
	var shade: Color = skin.gap_inside_color
	var strip_y: float = -STRIP_TOP - STRIP_HEIGHT
	if facing > 0.0:
		s.rect(Vector3(x0, 0, z), Vector3(w, 0, 0), Vector3(0, 0, -lip), edge, LIP_GLOW)
		s.rect(Vector3(x0, -depth, z), Vector3(w, 0, 0), Vector3(0, depth, 0), shade, 0.0, MeshKit.PAT_TERMINAL_UNDER)
		s.rect(Vector3(x0, strip_y, z + 0.004), Vector3(w, 0, 0), Vector3(0, STRIP_HEIGHT, 0), edge, STRIP_GLOW)
	else:
		s.rect(Vector3(x0, 0, z + lip), Vector3(w, 0, 0), Vector3(0, 0, -lip), edge, LIP_GLOW)
		s.rect(Vector3(x1, -depth, z), Vector3(-w, 0, 0), Vector3(0, depth, 0), shade, 0.0, MeshKit.PAT_TERMINAL_UNDER)
		s.rect(Vector3(x1, strip_y, z - 0.004), Vector3(-w, 0, 0), Vector3(0, STRIP_HEIGHT, 0), edge, STRIP_GLOW)


## A floor cut through the track bed (task B4; GDD §9.9): the track bed split open down the lane (the track hides the
## floor as the cut runs, FloorCutSection). The floor ends in the zone's orange edge right on the collision edge (the
## lips on the neighbouring lanes and the strips along the tops of the cut, the halo on its far side), and below it only
## deep shade dropping to the service level, like any hole: a few rails hang bent into the split from both sides (in the
## same shade, never lit, never level: nothing in the hole looks like floor).
func cut(parent: Node3D, section: FloorCutSection) -> void:
	ZoneSkin.standard_floor_cut(parent, section, skin.solid_material(), skin.glow_material(), {
		"edge": skin.gap_edge_color, "inside": skin.gap_inside_color, "pattern": MeshKit.PAT_TERMINAL_UNDER,
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
			_hanging_slab(s, x, -side, d, minf(d + length, section.end - 1.0), reach, drop, shade)
		d += length + 0.6 + 1.5 * MeshKit.hash01(lane_key, k, 78)
		k += 1
	var plates: MeshInstance3D = batch.commit(parent, "CutPlates")
	if plates != null:
		section.add_static(plates)


## One broken slab of track bed hanging from the side of a split at x, leaning `inward` (+1 toward +x): from just below
## the floor's edge, `reach` metres in and `drop` metres down, between track distances d0 and d1, both faces in the shade.
func _hanging_slab(s: MeshLayer, x: float, inward: float, d0: float, d1: float, reach: float, drop: float,
		shade: Color) -> void:
	var top := -0.06
	var a := Vector3(x, top, -d0)
	var b := Vector3(x, top, -d1)
	var c := Vector3(x + inward * reach, top - drop, -d1 + 0.2)
	var e := Vector3(x + inward * reach * 0.8, top - drop * 0.8, -d0 - 0.15)
	# Both faces: seen from above through the hole, and from below.
	s.quad(a, b, c, e, shade, 0.0, MeshKit.PAT_TERMINAL_UNDER, 1.0)
	s.quad(a, e, c, b, shade, 0.0, MeshKit.PAT_TERMINAL_UNDER, 1.0)

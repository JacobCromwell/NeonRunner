class_name GoldenPalaceFloor
extends RefCounted
## The Golden Palace's floor (GoldenPalaceSkin, GDD §5, "Final level: the Golden Palace": "a palace
## floor (marble, inlay, gold runners)"). A floor segment is one lane's stretch of the hall's floor:
## polished white and cream marble (MeshKit.PAT_PALACE_FLOOR, laid out from world position so the
## veins and the gold inlay runner down the lane's centre line up across chunk cuts) flush with the
## walls' plinth -- no raised kerb or rails, since the hall's floor is solid stone, not over water
## like the Golden Zone's walkways (GoldenWalkways), which this otherwise mirrors.
## Gaps are breaks in the floor (GDD §5: "a collapsed floor, an open stairwell, a light well"): the
## floor ends in the orange edge glow right on the collision edge, as in every zone (a dark line just
## before it so it pops against the marble), and below it everything is in deep shade
## (MeshKit.PAT_PALACE_WELL) dropping into the dark, so a gap reads as a hole at a glance.
## Chunk space: x across, y up (the floor at y = 0), z = -distance.

## The orange edge language: a lip on the floor's last EDGE_LIP metres and a strip along the top of
## the end face below it, with a dark line before the lip (as every zone's floor against a lit
## surface).
const EDGE_LIP: float = 0.16
const LIP_GLOW: float = 0.42
const EDGE_DARK: float = 0.05
const STRIP_TOP: float = 0.02
const STRIP_HEIGHT: float = 0.1
const STRIP_GLOW: float = 0.6
## The halo along the strip of a gap's far side (additive, kit_glow).
const EDGE_HALO: float = 0.35

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: GoldenPalaceSkin:
	get:
		return _skin.get_ref() as GoldenPalaceSkin
var _skin: WeakRef


func _init(p_skin: GoldenPalaceSkin) -> void:
	_skin = weakref(p_skin)


## Adds one lane's floor piece. center/size describe its collision box (top at y = 0).
func build(batch: MeshBatch, center: Vector3, size: Vector3, lane_x: float, edge_start: bool, edge_end: bool) -> void:
	if size.z < 0.01:
		return
	var s: MeshLayer = batch.layer(skin.solid_material())
	var x0: float = center.x - size.x * 0.5
	var x1: float = center.x + size.x * 0.5
	# The collision box spans the lane; it only reaches past the nominal lane width where a
	# neighbouring lane has a gap (the same convention as every floor in the mesh kit).
	var half_lane: float = minf(x1 - lane_x, lane_x - x0)
	var l0: float = lane_x - half_lane
	var l1: float = lane_x + half_lane
	var left_joint: bool = x0 < l0 - 0.01
	var right_joint: bool = x1 > l1 + 0.01
	var near_d: float = -(center.z + size.z * 0.5)
	var far_d: float = -(center.z - size.z * 0.5)
	var lip_n: float = minf(EDGE_LIP, size.z * 0.3) if edge_start else 0.0
	var lip_f: float = minf(EDGE_LIP, size.z * 0.3) if edge_end else 0.0
	var dark_n: float = minf(EDGE_DARK, size.z * 0.1) if edge_start else 0.0
	var dark_f: float = minf(EDGE_DARK, size.z * 0.1) if edge_end else 0.0
	var a: float = near_d + lip_n + dark_n
	var b: float = far_d - lip_f - dark_f
	if b > a:
		var flags: int = (MeshKit.PALACE_JOINT_LEFT if left_joint else 0) | (MeshKit.PALACE_JOINT_RIGHT if right_joint else 0)
		var param: float = MeshKit.palace_floor_param(flags, half_lane)
		s.rect(Vector3(x0, 0, -a), Vector3(x1 - x0, 0, 0), Vector3(0, 0, -(b - a)), skin.stone_colors[0], 0.0,
			MeshKit.PAT_PALACE_FLOOR, Vector2(x0 - lane_x, 0.0), Vector2(x1 - lane_x, b - a), param)
	# The floor's sides along its lane edges, in the well's shade: seen only where the neighbouring
	# lane has a gap.
	var depth: float = skin.canal_depth
	var shade: Color = skin.gap_inside_color
	if not left_joint:
		s.rect(Vector3(x0, -depth, -far_d), Vector3(0, 0, far_d - near_d), Vector3(0, depth, 0), shade, 0.0,
			MeshKit.PAT_PALACE_WELL)
	if not right_joint:
		s.rect(Vector3(x1, -depth, -near_d), Vector3(0, 0, -(far_d - near_d)), Vector3(0, depth, 0), shade, 0.0,
			MeshKit.PAT_PALACE_WELL)
	if edge_start:
		_edge(s, x0, x1, near_d, lip_n, dark_n, 1.0)
		# The far side of a gap faces the approaching runner: a soft orange halo along its strip, so
		# the edge carries from afar against the lit marble (as every zone's floor does).
		batch.layer(skin.glow_material()).rect(Vector3(x0 - 0.15, -STRIP_TOP - STRIP_HEIGHT - 0.25, -near_d + 0.05),
			Vector3(x1 - x0 + 0.3, 0, 0), Vector3(0, STRIP_HEIGHT + 0.5, 0), skin.gap_edge_color, EDGE_HALO, MeshKit.SHAPE_STREAK)
	if edge_end:
		_edge(s, x0, x1, far_d, lip_f, dark_f, -1.0)


## Where the floor ends at distance d (facing the player when facing = 1, away when -1): a dark line
## and the orange edge glow on the floor's edge, the orange strip along the top of the end face, then
## the face dropping into the well's dark.
func _edge(s: MeshLayer, x0: float, x1: float, d: float, lip: float, dark: float, facing: float) -> void:
	var z: float = -d
	var w: float = x1 - x0
	var edge: Color = skin.gap_edge_color
	var depth: float = skin.canal_depth
	var shade: Color = skin.gap_inside_color
	var strip_y: float = -STRIP_TOP - STRIP_HEIGHT
	if facing > 0.0:
		s.rect(Vector3(x0, 0, z), Vector3(w, 0, 0), Vector3(0, 0, -lip), edge, LIP_GLOW)
		s.rect(Vector3(x0, 0, z - lip), Vector3(w, 0, 0), Vector3(0, 0, -dark), skin.vein_color.darkened(0.4))
		s.rect(Vector3(x0, -depth, z), Vector3(w, 0, 0), Vector3(0, depth, 0), shade, 0.0, MeshKit.PAT_PALACE_WELL)
		s.rect(Vector3(x0, strip_y, z + 0.004), Vector3(w, 0, 0), Vector3(0, STRIP_HEIGHT, 0), edge, STRIP_GLOW)
	else:
		s.rect(Vector3(x0, 0, z + lip), Vector3(w, 0, 0), Vector3(0, 0, -lip), edge, LIP_GLOW)
		s.rect(Vector3(x0, 0, z + lip + dark), Vector3(w, 0, 0), Vector3(0, 0, -dark), skin.vein_color.darkened(0.4))
		s.rect(Vector3(x1, -depth, z), Vector3(-w, 0, 0), Vector3(0, depth, 0), shade, 0.0, MeshKit.PAT_PALACE_WELL)
		s.rect(Vector3(x1, strip_y, z - 0.004), Vector3(-w, 0, 0), Vector3(0, STRIP_HEIGHT, 0), edge, STRIP_GLOW)


## A floor cut through the hall (task B4; GDD §9.9): the marble floor split open down the lane (the
## track hides the floor as the cut runs, FloorCutSection), drawn like any break in it: the floor beside
## and beyond it ends in the zone's edge (a dark line, then the orange lip right on the collision edge,
## a strip along the top of the cut and the soft halo on its far side), and below is the well's deep
## shade dropping into the dark (below() draws its bottom across the hall). Nothing in it is marble,
## gold or lit.
func cut(parent: Node3D, section: FloorCutSection) -> void:
	ZoneSkin.standard_floor_cut(parent, section, skin.solid_material(), skin.glow_material(), {
		"edge": skin.gap_edge_color, "inside": skin.gap_inside_color, "pattern": MeshKit.PAT_PALACE_WELL,
		"params": [0.0, 0.0, 0.0], "depth": skin.canal_depth, "bottom": false,
		"lip": EDGE_LIP, "lip_glow": LIP_GLOW, "strip_glow": STRIP_GLOW, "halo": EDGE_HALO,
		"dark_line": skin.vein_color.darkened(0.4), "dark": EDGE_DARK,
	})


## The bottom of a break in the floor far below, the well's stone down the walls on both sides (so a hole
## in an outer lane shows the stairwell's wall, not the hall's outside: task H3), and the dust motes and
## speed streaks drifting over the hall's floor (the still floor's motion cue, the owner's review: GDD
## §5), for one chunk. None of it belongs to a lane, so the skin adds them to the left wall's mesh.
func below(batch: MeshBatch, half_width: float, start: float, end: float) -> void:
	var well: MeshLayer = batch.layer(skin.solid_material())
	var depth: float = skin.canal_depth
	# Faces toward the street (the kit culls back faces): the left wall's looks along +x, the right's along -x.
	well.rect(Vector3(-half_width, -depth, -start), Vector3(0, 0, -(end - start)), Vector3(0, depth, 0), skin.gap_inside_color, 0.0,
		MeshKit.PAT_PALACE_WELL)
	well.rect(Vector3(half_width, -depth, -end), Vector3(0, 0, end - start), Vector3(0, depth, 0), skin.gap_inside_color, 0.0,
		MeshKit.PAT_PALACE_WELL)
	batch.layer(skin.solid_material()).rect(Vector3(-half_width, -skin.canal_depth, -start), Vector3(half_width * 2.0, 0, 0),
		Vector3(0, 0, -(end - start)), skin.well_floor_color, 0.0, MeshKit.PAT_PALACE_WELL, Vector2.ZERO, Vector2.ONE, 1.0)
	MeshKit.drift_particles(batch.layer(skin.drift_material()), start, end, TrackBuilder.CHUNK_LENGTH, half_width - 0.7,
		7.0, skin.mist_count, skin.leaf_count, skin.streak_count,
		PackedColorArray([skin.mist_color, skin.leaf_color, skin.streak_color]))

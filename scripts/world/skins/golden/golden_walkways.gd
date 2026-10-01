class_name GoldenWalkways
extends RefCounted
## Golden walkways over water for the Golden Zone floor (GoldenSkin, GDD §5). A floor segment is one
## lane's walkway: a deck of burnished gold plates between polished rails (MeshKit.PAT_WALKWAY, laid
## out from world position, so plates continue seamlessly across chunk cuts), with a dark joint where
## a neighbouring lane's walkway runs beside it, so every lane reads as its own walkway; the outer
## lanes run on to the building faces over a marble kerb. The deck is flat (y = 0) and nothing stands
## on it, so nothing looks like an obstacle.
## Where a gap borders the segment, the deck ends in the orange edge glow right on the collision edge,
## as in every zone (a dark line just before it so it pops against the gold), and below it everything
## is in deep shade (MeshKit.PAT_UNDERDECK) dropping to the dark canal far below (MeshKit.PAT_CANAL):
## a gap reads as a hole at a glance, with nothing lit or deck-like inside it. Every segment also
## carries its sides along its lane edges in the same shade, hidden under the neighbouring walkway
## unless that lane has a gap.
## The cult's medallions (GDD §5: its emblem shown openly) are inlaid flush in some walkways: a disc
## of cream marble in a gold ring with the emblem in polished gold at its heart, one lane wide, only
## on unbroken walkway well clear of any gap's edge. Nothing round or grated sits on the deck
## otherwise (in other zones, manholes are sewer-screech lairs, GDD §9.5).
## Chunk space: x across, y up (the decks at y = 0), z = -distance.

## The orange edge language: a lip on the deck's last 0.18 m and a strip along the top of the end
## face below it; taller and brighter than on the dark streets of other zones, like the Marketplace's
## (against a lit floor the glow's halo shows less), with a dark line before the lip.
const EDGE_LIP: float = 0.18
const LIP_GLOW: float = 0.42
const EDGE_DARK: float = 0.05
const STRIP_TOP: float = 0.02
const STRIP_HEIGHT: float = 0.1
const STRIP_GLOW: float = 0.6
## The halo along the strip of a gap's far side (additive, kit_glow).
const EDGE_HALO: float = 0.35
## Medallions sit one slot per lane in each MEDALLION_SLOT metres of track (a chunk, so a medallion
## never straddles a chunk cut), their centres MEDALLION_INSET or more from the slot's ends, and
## MEDALLION_CLEAR or more from any gap's edge.
const MEDALLION_SLOT: float = TrackBuilder.CHUNK_LENGTH
const MEDALLION_INSET: float = 8.0
const MEDALLION_CLEAR: float = 1.5

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: GoldenSkin:
	get:
		return _skin.get_ref() as GoldenSkin
var _skin: WeakRef


func _init(p_skin: GoldenSkin) -> void:
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
	var lip_n: float = minf(EDGE_LIP, size.z * 0.3) if edge_start else 0.0
	var lip_f: float = minf(EDGE_LIP, size.z * 0.3) if edge_end else 0.0
	var dark_n: float = minf(EDGE_DARK, size.z * 0.1) if edge_start else 0.0
	var dark_f: float = minf(EDGE_DARK, size.z * 0.1) if edge_end else 0.0
	var a: float = near_d + lip_n + dark_n
	var b: float = far_d - lip_f - dark_f
	var width: float = l1 - l0
	var flags: int = (0 if left_kerb else MeshKit.WALKWAY_JOINT_LEFT) | (0 if right_kerb else MeshKit.WALKWAY_JOINT_RIGHT)

	if b > a:
		# The deck, split around its medallions (each on a square piece of its own, drawn by the shader).
		var cursor: float = a
		for m: float in medallions(lane_x, width, near_d, far_d, edge_start, edge_end):
			var m0: float = m - width * 0.5
			_deck(s, l0, width, cursor, m0, flags)
			_deck(s, l0, width, m0, m0 + width, flags | MeshKit.WALKWAY_MEDALLION)
			cursor = m0 + width
		_deck(s, l0, width, cursor, b, flags)
		# The marble kerb along the building faces.
		if left_kerb:
			s.rect(Vector3(x0, 0, -a), Vector3(l0 - x0, 0, 0), Vector3(0, 0, -(b - a)), skin.kerb_color, 0.0,
				MeshKit.PAT_MARBLE, Vector2.ZERO, Vector2.ONE, 1.0)
		if right_kerb:
			s.rect(Vector3(l1, 0, -a), Vector3(x1 - l1, 0, 0), Vector3(0, 0, -(b - a)), skin.kerb_color, 0.0,
				MeshKit.PAT_MARBLE, Vector2.ZERO, Vector2.ONE, 1.0)

	# The walkway's sides along its lane edges, in the shade under the decks: seen only where the
	# neighbouring lane has a gap.
	var depth: float = skin.canal_depth
	var shade: Color = skin.gap_inside_color
	if not left_kerb:
		s.rect(Vector3(x0, -depth, -far_d), Vector3(0, 0, far_d - near_d), Vector3(0, depth, 0), shade, 0.0,
			MeshKit.PAT_UNDERDECK)
	if not right_kerb:
		s.rect(Vector3(x1, -depth, -near_d), Vector3(0, 0, -(far_d - near_d)), Vector3(0, depth, 0), shade, 0.0,
			MeshKit.PAT_UNDERDECK)

	if edge_start:
		_edge(s, x0, x1, near_d, lip_n, dark_n, 1.0)
		# The far side of a gap faces the approaching runner: a soft orange halo along its strip, so the
		# edge carries from afar against the lit gold (as the City's marker lights do).
		batch.layer(skin.glow_material()).rect(Vector3(x0 - 0.15, -STRIP_TOP - STRIP_HEIGHT - 0.25, -near_d + 0.05),
			Vector3(x1 - x0 + 0.3, 0, 0), Vector3(0, STRIP_HEIGHT + 0.5, 0), skin.gap_edge_color, EDGE_HALO, MeshKit.SHAPE_STREAK)
	if edge_end:
		_edge(s, x0, x1, far_d, lip_f, dark_f, -1.0)


## The centres (track distances) of the medallions on the floor piece [near_d, far_d] of the lane at
## lane_x (`width` wide), in order: one slot per MEDALLION_SLOT metres, a medallion_share of them used,
## each only where the walkway runs on unbroken MEDALLION_CLEAR or more past both of its ends (and
## past a gap edge's lip).
func medallions(lane_x: float, width: float, near_d: float, far_d: float, edge_start: bool = false,
		edge_end: bool = false) -> Array[float]:
	var out: Array[float] = []
	if skin.medallion_share <= 0.0:
		return out
	var lane: int = MeshKit.key(lane_x)
	var lo: float = near_d + (EDGE_LIP + EDGE_DARK + MEDALLION_CLEAR if edge_start else 0.0)
	var hi: float = far_d - (EDGE_LIP + EDGE_DARK + MEDALLION_CLEAR if edge_end else 0.0)
	var k: int = floori(near_d / MEDALLION_SLOT)
	while k * MEDALLION_SLOT < far_d:
		if MeshKit.hash01(lane, k, 51) < skin.medallion_share:
			var c: float = k * MEDALLION_SLOT + MEDALLION_INSET + (MEDALLION_SLOT - MEDALLION_INSET * 2.0) * MeshKit.hash01(lane, k, 52)
			if c - width * 0.5 >= lo and c + width * 0.5 <= hi:
				out.append(c)
		k += 1
	return out


## A stretch of deck from track distance d0 to d1 (UV.x metres across from the lane's left edge l0).
func _deck(s: MeshLayer, l0: float, width: float, d0: float, d1: float, flags: int) -> void:
	if d1 <= d0 + 0.0005:
		return
	s.rect(Vector3(l0, 0, -d0), Vector3(width, 0, 0), Vector3(0, 0, -(d1 - d0)), skin.walkway_color, 0.0,
		MeshKit.PAT_WALKWAY, Vector2.ZERO, Vector2(width, d1 - d0), MeshKit.walkway_param(flags, width))


## Where the walkway ends at distance d (facing the player when facing = 1, away when -1): a dark
## line and the orange edge glow on the deck's edge, the orange strip along the top of the end face,
## then the face dropping into the dark.
func _edge(s: MeshLayer, x0: float, x1: float, d: float, lip: float, dark: float, facing: float) -> void:
	var z: float = -d
	var w: float = x1 - x0
	var edge: Color = skin.gap_edge_color
	var depth: float = skin.canal_depth
	var shade: Color = skin.gap_inside_color
	var strip_y: float = -STRIP_TOP - STRIP_HEIGHT
	if facing > 0.0:
		s.rect(Vector3(x0, 0, z), Vector3(w, 0, 0), Vector3(0, 0, -lip), edge, LIP_GLOW)
		s.rect(Vector3(x0, 0, z - lip), Vector3(w, 0, 0), Vector3(0, 0, -dark), skin.joint_color)
		s.rect(Vector3(x0, -depth, z), Vector3(w, 0, 0), Vector3(0, depth, 0), shade, 0.0, MeshKit.PAT_UNDERDECK)
		s.rect(Vector3(x0, strip_y, z + 0.004), Vector3(w, 0, 0), Vector3(0, STRIP_HEIGHT, 0), edge, STRIP_GLOW)
	else:
		s.rect(Vector3(x0, 0, z + lip), Vector3(w, 0, 0), Vector3(0, 0, -lip), edge, LIP_GLOW)
		s.rect(Vector3(x0, 0, z + lip + dark), Vector3(w, 0, 0), Vector3(0, 0, -dark), skin.joint_color)
		s.rect(Vector3(x1, -depth, z), Vector3(-w, 0, 0), Vector3(0, depth, 0), shade, 0.0, MeshKit.PAT_UNDERDECK)
		s.rect(Vector3(x1, strip_y, z - 0.004), Vector3(-w, 0, 0), Vector3(0, STRIP_HEIGHT, 0), edge, STRIP_GLOW)


## A floor cut through a walkway (task B4; GDD §9.9): the gold walkway cut open down the lane (the track
## hides the deck as the cut runs, FloorCutSection). The decks beside it and beyond it end in the zone's
## edge (a dark line, then the orange lip right on the collision edge, a strip along the top of the cut
## and the soft halo on its far side), and below everything is the deep shade under the decks dropping
## to the canal, like any gap: nothing in it is gold, lit or deck-like.
func cut(parent: Node3D, section: FloorCutSection) -> void:
	ZoneSkin.standard_floor_cut(parent, section, skin.solid_material(), skin.glow_material(), {
		"edge": skin.gap_edge_color, "inside": skin.gap_inside_color, "pattern": MeshKit.PAT_UNDERDECK,
		"params": [0.0, 0.0, 0.0], "depth": skin.canal_depth, "bottom": false,
		"lip": EDGE_LIP, "lip_glow": LIP_GLOW, "strip_glow": STRIP_GLOW, "halo": EDGE_HALO,
		"dark_line": skin.joint_color, "dark": EDGE_DARK,
	})


## The canal far below the walkways, flowing toward the player, and the mist, gold leaf and speed
## streaks drifting over the decks (the still floor's motion cues), for one chunk. Neither belongs to
## a lane, so the skin adds them to the left wall's mesh.
func below(batch: MeshBatch, half_width: float, start: float, end: float) -> void:
	batch.layer(skin.solid_material()).rect(Vector3(-half_width, -skin.canal_depth, -start), Vector3(half_width * 2.0, 0, 0),
		Vector3(0, 0, -(end - start)), skin.canal_color, 0.0, MeshKit.PAT_CANAL)
	MeshKit.drift_particles(batch.layer(skin.drift_material()), start, end, TrackBuilder.CHUNK_LENGTH, half_width - 0.7,
		7.0, skin.mist_count, skin.leaf_count, skin.streak_count,
		PackedColorArray([skin.mist_color, skin.leaf_color, skin.streak_color]))

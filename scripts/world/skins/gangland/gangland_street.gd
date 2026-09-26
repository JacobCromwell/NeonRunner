class_name GanglandStreet
extends RefCounted
## Gangland streets (GanglandSkin). A floor segment is a stretch of cracked asphalt (a world-space
## pattern, so lanes, pieces and chunk cuts join seamlessly) with worn dashed lines between lanes,
## sand blown over it in long drifts and a sandy gutter strip along the building faces. Where a gap
## borders the segment, the asphalt is scorched black toward the hole (a blast crater), the road
## ends in the orange edge glow right on the collision edge, and the cut shows the road's strata
## falling away into darkness, with broken slabs and rebar hanging below the rim (never at or above
## it, so the edge stays exactly where the collision ends). Every segment also carries strata along
## its lane sides, hidden under the neighbouring lane unless that lane has a hole.
## Chunk space: x across, y up (street at y = 0), z = -distance.

const EDGE_LIP: float = 0.18

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: GanglandSkin:
	get:
		return _skin.get_ref() as GanglandSkin
var _skin: WeakRef


func _init(p_skin: GanglandSkin) -> void:
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
	var zn: float = center.z + size.z * 0.5
	var zf: float = center.z - size.z * 0.5
	var lip_n: float = minf(EDGE_LIP, size.z * 0.4) if edge_start else 0.0
	var lip_f: float = minf(EDGE_LIP, size.z * 0.4) if edge_end else 0.0
	var top_n: float = zn - lip_n
	var top_f: float = zf + lip_f

	# The street: asphalt across the lane (UV.x -1..1, UV.y metres from the near end), lane lines on
	# the sides that have neighbours; the higher PAT_ASPHALT flags mark bordering holes and carry the
	# piece's length, for the scorch toward them.
	var length: float = top_n - top_f
	var edges: int = (4 if edge_start else 0) | (8 if edge_end else 0) | (roundi(length * 8.0) << 4)
	var flags: int = (0 if left_gutter else 1) | (0 if right_gutter else 2) | edges
	s.rect(Vector3(l0, 0, top_n), Vector3(l1 - l0, 0, 0), Vector3(0, 0, top_f - top_n), skin.asphalt_color, 0.0,
		MeshKit.PAT_ASPHALT, Vector2(-1, 0), Vector2(1, length), float(flags))
	if left_gutter:
		s.rect(Vector3(x0, 0, top_n), Vector3(l0 - x0, 0, 0), Vector3(0, 0, top_f - top_n), skin.gutter_color, 0.0,
			MeshKit.PAT_ASPHALT, Vector2(-1, 0), Vector2(1, length), float(edges))
	if right_gutter:
		s.rect(Vector3(l1, 0, top_n), Vector3(x1 - l1, 0, 0), Vector3(0, 0, top_f - top_n), skin.gutter_color, 0.0,
			MeshKit.PAT_ASPHALT, Vector2(-1, 0), Vector2(1, length), float(edges))

	# Strata along the lane sides: seen only where the neighbouring lane has a hole.
	var depth: float = skin.crater_depth
	if not left_gutter:
		s.rect(Vector3(x0, -depth, zf), Vector3(0, 0, zn - zf), Vector3(0, depth, 0), skin.earth_color, 0.0,
			MeshKit.PAT_STRATA)
	if not right_gutter:
		s.rect(Vector3(x1, -depth, zn), Vector3(0, 0, zf - zn), Vector3(0, depth, 0), skin.earth_color, 0.0,
			MeshKit.PAT_STRATA)

	var lane_key: int = MeshKit.key(lane_x)
	if edge_start:
		s.rect(Vector3(x0, 0, zn), Vector3(x1 - x0, 0, 0), Vector3(0, 0, -lip_n), skin.gap_edge_color, 0.33)
		_edge_face(s, x0, x1, zn, 1.0, lane_key, MeshKit.key(-zn))
	if edge_end:
		s.rect(Vector3(x0, 0, zf + lip_f), Vector3(x1 - x0, 0, 0), Vector3(0, 0, -lip_f), skin.gap_edge_color, 0.33)
		_edge_face(s, x0, x1, zf, -1.0, lane_key, MeshKit.key(-zf))


## Where the road breaks off at z (facing +z toward the player, or -z): the strata cut with the
## orange rim along its top, and broken slabs and rebar hanging below the rim.
func _edge_face(s: MeshLayer, x0: float, x1: float, z: float, facing: float, a: int, b: int) -> void:
	var depth: float = skin.crater_depth
	var w: float = x1 - x0
	var edge: Color = skin.gap_edge_color
	if facing > 0.0:
		s.rect(Vector3(x0, -depth, z), Vector3(w, 0, 0), Vector3(0, depth, 0), skin.earth_color, 0.0, MeshKit.PAT_STRATA)
		s.rect(Vector3(x0, -0.075, z + 0.004), Vector3(w, 0, 0), Vector3(0, 0.045, 0), edge, 0.45)
	else:
		s.rect(Vector3(x1, -depth, z), Vector3(-w, 0, 0), Vector3(0, depth, 0), skin.earth_color, 0.0, MeshKit.PAT_STRATA)
		s.rect(Vector3(x1, -0.075, z - 0.004), Vector3(-w, 0, 0), Vector3(0, 0.045, 0), edge, 0.45)
	# Slabs of road hanging off the cut (tops at least 0.3 m below the rim, reaching at most 0.3 m
	# into the hole).
	var slabs: int = 1 + MeshKit.hash_i(a, b, 1) % 2
	for i: int in slabs:
		var t: float = (float(i) + 0.2 + 0.6 * MeshKit.hash01(a, b, 10 + i)) / float(slabs)
		var width: float = minf(0.45 + 0.5 * MeshKit.hash01(a, b, 20 + i), w * 0.45)
		var y: float = -0.62 - 0.8 * MeshKit.hash01(a, b, 30 + i)
		var hang: float = 0.45 + 0.4 * MeshKit.hash01(a, b, 40 + i)
		var roll: float = (MeshKit.hash01(a, b, 50 + i) - 0.5) * 0.4
		var basis := Basis.from_euler(Vector3(facing * hang, 0.0, roll)).scaled_local(Vector3(width, 0.12, 0.45))
		var shade: float = 0.2 + 0.4 * exp(y + 0.3)
		s.box_xform(Transform3D(basis, Vector3(lerpf(x0, x1, t), y, z + facing * 0.05)),
			skin.gutter_color * Color(shade, shade, shade), 0.0, MeshKit.PAT_PLAIN)
	# Rebar poking out of the cut.
	for i: int in 2:
		var rx: float = lerpf(x0 + 0.2, x1 - 0.2, MeshKit.hash01(a, b, 60 + i))
		var ry: float = -0.35 - 0.6 * MeshKit.hash01(a, b, 70 + i)
		var length: float = 0.3 + 0.25 * MeshKit.hash01(a, b, 80 + i)
		var bend := Basis.from_euler(Vector3(facing * (0.4 + 0.7 * MeshKit.hash01(a, b, 90 + i)), 0.0,
			(MeshKit.hash01(a, b, 100 + i) - 0.5) * 1.2)).scaled_local(Vector3(0.025, 0.025, length))
		s.box_xform(Transform3D(bend, Vector3(rx, ry - 0.1, z + facing * length * 0.3)), skin.rust_color.darkened(0.3))


## The floor of the holes, dark and deep below the street, and the drifting ash, scraps and speed
## streaks over it (GDD §5 motion effects), for one chunk. Neither belongs to a lane, so the skin adds
## them to the left wall's mesh.
func below(batch: MeshBatch, half_width: float, start: float, end: float) -> void:
	batch.layer(skin.solid_material()).rect(Vector3(-half_width, -skin.crater_depth, -start), Vector3(half_width * 2.0, 0, 0),
		Vector3(0, 0, -(end - start)), skin.crater_floor_color)
	MeshKit.drift_particles(batch.layer(skin.drift_material()), start, end, TrackBuilder.CHUNK_LENGTH, half_width - 0.7,
		7.5, skin.ash_count, skin.scrap_count, skin.streak_count,
		PackedColorArray([skin.ash_color, skin.scrap_color, skin.streak_color]))

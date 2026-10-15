class_name GoldenConvergenceHole
extends RefCounted
## A Fist Slam's hole (GDD §10: "it leaves a large square hole at least two lanes wide at once (the floor turns
## into a gap during play, as it does under the Buzz Overdrive's cut) ... Its edges glow the usual gap-edge
## orange"; task E5d-b). The slam plans a row of floor cuts in every lane (FloorCut, task B4) before its
## sequence begins, since the footprint isn't known until the lock, and opens the footprint's lanes at once at
## the impact (FloorCut.advance_to). Only two or three lanes of a row ever open, so a row costs next to nothing
## until it does (E5d polish, the review's mobile performance finding: a look built for every lane of every row
## made about 8 meshes a cut in the chunk-build frame, outside the dressing budget, and drew every lane's hidden
## inside under the floor):
## - the Grand Court's floor_cut() (GoldenCourtSkin) draws nothing when the track builds a cut: a cut that never
##   opens is the floor as ever (the track draws it in slices);
## - open(cuts, skin): at the impact, the look of the whole square hole over the footprint's cuts, before they
##   open: one look across its lanes (no lips, dark lines or walls between them), the palace floor's break
##   (GoldenPalaceFloor.cut's style: the orange lips right on the collision edges with a dark line before them,
##   the strip along the top of the inside's walls, the halo on the far side, the well's deep shade below), its
##   parts registered on the first lane's cut (FloorCutSection: the inside a static, the side lips a span, the
##   near lip a front the cut moves to where its floor ends, the far lip and the halo fars), so the cut shows them
##   as it opens and holds;
## - its meshes are made once for each footprint at the fight's lane count and row (prewarm(), with the fight:
##   every row is as long as the hole is wide) and shared, kept in the skin (GoldenCourtSkin.hole_meshes), in the
##   hole's own space (z from its far end), and placed by a node at the row: a hole costs six nodes and five draws
##   from the moment it opens, never a mesh built mid-fight;
## - footprint(): the lanes a slam opens around the lane its fist locked onto (GDD §10, proposed: "two lanes
##   wide on 3 lanes, three on 5 or 6, as long as it is wide, around the locked lane (moved inward at the
##   track's edge)"), hole_lanes() how many.
## Nothing in it glows but the orange edges, and nothing flickers.

## The side a part runs along on its node (-1 left, 1 right, 0 across or both); HALO on the far halo.
const SIDE_META: StringName = &"hole_side"
const HALO: int = 2
## The halo reaches this far past the hole's sides and this far below and above the strip (the palace
## floor's break: ZoneSkin.standard_floor_cut's).
const HALO_SPILL: float = 0.15
const HALO_BELOW: float = 0.25
## Its parts by name, in order: the inside (a static), the side lips (a span), the near lip (a front), the far
## side (a far), the halo (a far).
const PARTS: Array[StringName] = [&"inside", &"sides", &"near", &"far", &"halo"]


## The lanes a slam opens around `lane` (where its fist locked) on a track of `lanes` lanes: hole_lanes() of
## them, centred on it and moved inward at the track's edge; with an even count, the extra lane goes toward
## the track's middle, or from the middle lane itself toward `side` (-1 left, 1 right: the slamming fist's).
static func footprint(lane: int, lanes: int, side: int = 1) -> Array[int]:
	var w: int = hole_lanes(lanes)
	var mid: float = (lanes - 1) * 0.5
	var first: int = lane - (w - 1) / 2
	if w % 2 == 0:
		var toward: int = (1 if side >= 0 else -1) if absf(float(lane) - mid) < 0.01 else (1 if float(lane) < mid else -1)
		first = lane - (w / 2 - 1) if toward > 0 else lane - w / 2
	first = clampi(first, 0, maxi(lanes - w, 0))
	var out: Array[int] = []
	for k: int in w:
		out.append(first + k)
	return out


## DESIGN-TBD (GDD §10, proposed; docs/OPEN_QUESTIONS.md, items 444–456): two lanes on 3 lanes, three on 5 or 6 (two on
## a 4-lane track, which no device uses); never every lane.
static func hole_lanes(lanes: int) -> int:
	return clampi(2 if lanes <= 4 else 3, 1, maxi(lanes - 1, 1))


## Makes the meshes of every hole a slam can open on `geo`'s track with rows `length` long (every footprint),
## kept in `skin` (the fight's load: never mid-fight). Returns how many footprints.
static func prewarm(skin: GoldenCourtSkin, geo: TrackGeometry, length: float) -> int:
	var w: int = hole_lanes(geo.lane_count)
	var n: int = 0
	for first: int in range(0, maxi(geo.lane_count - w, 0) + 1):
		meshes(skin, geo, first, first + w - 1, length)
		n += 1
	return n


## The look of the square hole over `cuts` (one slam's footprint on `geo`'s track: the same row in side-by-side
## lanes), made as it opens (call it before FloorCut.advance_to): its parts placed at the row under the first
## lane's cut and registered on it (FloorCutSection), from `skin`'s shared meshes. Returns the node holding them
## (null when there's nothing to open, or another skin drew the cuts' looks already: a review's --skin=).
static func open(cuts: Array[FloorCut], skin: ZoneSkin, geo: TrackGeometry) -> Node3D:
	var court := skin as GoldenCourtSkin
	var lo: FloorCut = null
	var hi: FloorCut = null
	for fc: FloorCut in cuts:
		if fc == null or not is_instance_valid(fc):
			continue
		if lo == null or fc.lane < lo.lane:
			lo = fc
		if hi == null or fc.lane > hi.lane:
			hi = fc
	if court == null or lo == null:
		return null
	var section: FloorCutSection = lo.section
	var m: Dictionary = meshes(court, geo, lo.lane, hi.lane, section.length())
	var look: Node3D = lo.get_node_or_null(^"Look") as Node3D
	var holder := Node3D.new()
	holder.name = "Hole"
	(look if look != null else lo as Node3D).add_child(holder)
	# The hole's own space: its far end at z = 0 (FloorCut moves the near lip on from there, relative to it).
	holder.position = Vector3(0.0, 0.0, TrackGeometry.world_z(section.end))
	for part: StringName in PARTS:
		var mesh: Mesh = m.get(part)
		if mesh == null:
			continue
		var node: MeshInstance3D = MeshBatch.add_instance(holder, mesh, "Hole" + String(part).capitalize())
		node.set_meta(SIDE_META, HALO if part == &"halo" else 0)
		match part:
			&"inside":
				section.add_static(node)
			&"sides":
				section.add_span(node)
			&"near":
				section.add_front(node)
			_:
				section.add_far(node)
	return holder


## The meshes of the hole over lanes `first` to `last` of `geo`'s track, `length` along it, in the hole's own
## space (x across as on the track, y up from the floor's top, z from its far end toward the runner): {inside,
## sides (null at a track edge on both sides), near, far, halo}, made once and kept in `skin`.
static func meshes(skin: GoldenCourtSkin, geo: TrackGeometry, first: int, last: int, length: float) -> Dictionary:
	var x0: float = geo.lane_floor_span(first).x
	var x1: float = geo.lane_floor_span(last).y
	var key: String = "%d|%d|%d|%.3f|%.3f|%.3f|%s|%s|%s|%.3f" % [geo.lane_count, first, last, x0, x1, length,
		skin.gap_edge_color.to_html(), skin.gap_inside_color.to_html(), skin.vein_color.to_html(), skin.canal_depth]
	var found: Variant = skin.hole_meshes.get(key)
	if found is Dictionary:
		return found
	var made: Dictionary = _build(skin, x0, x1, first > 0, last < geo.lane_count - 1, length)
	skin.hole_meshes[key] = made
	return made


## Builds the hole's meshes (meshes()): the palace floor's break round the whole hole from x0 to x1, the side
## lips only where a lane runs beside it (`left`, `right`).
static func _build(skin: GoldenPalaceSkin, x0: float, x1: float, left: bool, right: bool, length: float) -> Dictionary:
	var solid: Material = skin.solid_material()
	var glow: Material = skin.glow_material()
	var edge: Color = skin.gap_edge_color
	var inside: Color = skin.gap_inside_color
	var pattern: int = MeshKit.PAT_PALACE_WELL
	var depth: float = skin.canal_depth
	var lip: float = GoldenPalaceFloor.EDGE_LIP
	var dark: float = GoldenPalaceFloor.EDGE_DARK
	var dark_color: Color = skin.vein_color.darkened(0.4)
	var lip_glow: float = GoldenPalaceFloor.LIP_GLOW
	var strip_glow: float = GoldenPalaceFloor.STRIP_GLOW
	var strip_h: float = ZoneSkin.CUT_STRIP_HEIGHT
	var w: float = x1 - x0
	# The far end at z = 0, the near end `length` toward the runner.
	var zf: float = 0.0
	var zn: float = length
	var top: float = -ZoneSkin.CUT_STRIP_TOP
	var y: float = ZoneSkin.CUT_LIP_LIFT
	var inset: float = ZoneSkin.CUT_WALL_INSET
	var wall: float = depth + top
	var out: Dictionary = {}
	# The inside, below the floor: its end walls across the whole hole, its side walls just inside its sides.
	var ins := MeshBatch.new()
	var s: MeshLayer = ins.layer(solid)
	s.rect(Vector3(x0, -depth, zf + inset), Vector3(w, 0, 0), Vector3(0, wall, 0), inside, 0.0, pattern)
	s.rect(Vector3(x1, -depth, zn - inset), Vector3(-w, 0, 0), Vector3(0, wall, 0), inside, 0.0, pattern)
	s.rect(Vector3(x0 + inset, -depth, zn), Vector3(0, 0, -length), Vector3(0, wall, 0), inside, 0.0, pattern)
	s.rect(Vector3(x1 - inset, -depth, zf), Vector3(0, 0, length), Vector3(0, wall, 0), inside, 0.0, pattern)
	out[&"inside"] = ins.to_mesh()
	# Along its sides where a lane runs beside it: the lip on that lane's floor right at the edge, the dark line
	# outside it, and the strip along the top of the inside's wall.
	var along := MeshBatch.new()
	var a: MeshLayer = along.layer(solid)
	if left:
		a.rect(Vector3(x0 - lip, y, zn), Vector3(lip, 0, 0), Vector3(0, 0, -length), edge, lip_glow)
		a.rect(Vector3(x0 - lip - dark, y, zn), Vector3(dark, 0, 0), Vector3(0, 0, -length), dark_color)
		a.rect(Vector3(x0 + inset + 0.004, top - strip_h, zn), Vector3(0, 0, -length), Vector3(0, strip_h, 0), edge, strip_glow)
	if right:
		a.rect(Vector3(x1, y, zn), Vector3(lip, 0, 0), Vector3(0, 0, -length), edge, lip_glow)
		a.rect(Vector3(x1 + lip, y, zn), Vector3(dark, 0, 0), Vector3(0, 0, -length), dark_color)
		a.rect(Vector3(x1 - inset - 0.004, top - strip_h, zf), Vector3(0, 0, length), Vector3(0, strip_h, 0), edge, strip_glow)
	out[&"sides"] = along.to_mesh()
	# The floor's far end where the cut has got to, built at the hole's far end (FloorCut moves it to its front):
	# its lip and dark line, across the whole hole.
	var near := MeshBatch.new()
	var n: MeshLayer = near.layer(solid)
	n.rect(Vector3(x0, y, zf + lip), Vector3(w, 0, 0), Vector3(0, 0, -lip), edge, lip_glow)
	n.rect(Vector3(x0, y, zf + lip + dark), Vector3(w, 0, 0), Vector3(0, 0, -dark), dark_color)
	out[&"near"] = near.to_mesh()
	# The far side, facing the runner: the lip on the floor beyond it, its dark line, the strip along the top of
	# its face.
	var far := MeshBatch.new()
	var f: MeshLayer = far.layer(solid)
	f.rect(Vector3(x0, y, zf), Vector3(w, 0, 0), Vector3(0, 0, -lip), edge, lip_glow)
	f.rect(Vector3(x0, y, zf - lip), Vector3(w, 0, 0), Vector3(0, 0, -dark), dark_color)
	f.rect(Vector3(x0, top - strip_h, zf + inset + 0.004), Vector3(w, 0, 0), Vector3(0, strip_h, 0), edge, strip_glow)
	out[&"far"] = far.to_mesh()
	# The halo that carries the far side from afar: an additive streak along the top of its face.
	var halo := MeshBatch.new()
	halo.layer(glow).rect(Vector3(x0 - HALO_SPILL, top - strip_h - HALO_BELOW, zf + 0.05), Vector3(w + HALO_SPILL * 2.0, 0, 0),
		Vector3(0, strip_h + HALO_BELOW * 2.0, 0), edge, GoldenPalaceFloor.EDGE_HALO, MeshKit.SHAPE_STREAK)
	out[&"halo"] = halo.to_mesh()
	return out

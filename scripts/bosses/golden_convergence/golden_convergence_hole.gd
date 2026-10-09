class_name GoldenConvergenceHole
extends RefCounted
## A Fist Slam's hole (GDD §10: "it leaves a large square hole at least two lanes wide at once (the floor turns
## into a gap during play, as it does under the Buzz Overdrive's cut) ... Its edges glow the usual gap-edge
## orange"; task E5d-b). The slam plans a row of floor cuts in every lane (FloorCut, task B4) before its
## sequence begins and opens the footprint's lanes at once at the impact (FloorCut.advance_to). Each lane's cut
## draws its own look, and the standard look (ZoneSkin.standard_floor_cut) would leave a stray orange lip, a
## dark line and a wall of the hole's inside down the middle wherever two opened lanes meet. So:
## - build(): the Grand Court's floor cut look (GoldenCourtSkin.floor_cut calls it): the palace floor's break
##   (GoldenPalaceFloor.cut's style: the orange lips right on the collision edges with a dark line before them,
##   the strip along the top of the inside's walls, the halo on the far side, the well's deep shade below),
##   with every part along one side of the cut (the lip on the neighbouring lane's floor, its dark line, the
##   strip, the inside's wall under them) a node of its own tagged with its side (meta SIDE_META), the parts
##   across the lane (the near and far lips, their dark lines, the far strip, the inside's end walls) running
##   the lane's whole floor so side by side they meet without a seam, and the far halo a node of its own;
## - join(cuts): at the impact, the cuts opened together lose the parts that face another opened cut, and
##   their halos give way to one across the whole hole: one square hole, the usual orange edges round it and
##   a dark inside. The parts go from their FloorCutSection, so the cut never shows them again;
## - footprint(): the lanes a slam opens around the lane its fist locked onto (GDD §10, proposed: "two lanes
##   wide on 3 lanes, three on 5 or 6, as long as it is wide, around the locked lane (moved inward at the
##   track's edge)"), hole_lanes() how many.
## Nothing in it glows but the orange edges, and nothing flickers. A cut that never opens (a lane of the row
## outside the footprint) is the floor as ever: the track draws it in slices, and its look stays under them.

## The side a part runs along (-1 left, 1 right) on its node; HALO on the far halo.
const SIDE_META: StringName = &"hole_side"
const HALO: int = 2
## The halo reaches this far past the hole's sides and this far below and above the strip (the palace
## floor's break: ZoneSkin.standard_floor_cut's).
const HALO_SPILL: float = 0.15
const HALO_BELOW: float = 0.25


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


## DESIGN-TBD (GDD §10, proposed; docs/questions/e5d.md, E5d-b): two lanes on 3 lanes, three on 5 or 6 (two on
## a 4-lane track, which no device uses); never every lane.
static func hole_lanes(lanes: int) -> int:
	return clampi(2 if lanes <= 4 else 3, 1, maxi(lanes - 1, 1))


## The Grand Court's look of floor cut `cut` (a Fist Slam row's lane), drawn with `skin`'s palace floor
## materials and colours, its parts registered on `cut` (FloorCutSection) and side parts tagged.
static func build(parent: Node3D, cut: FloorCutSection, skin: GoldenPalaceSkin) -> void:
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
	var x0: float = cut.x0
	var x1: float = cut.x1
	var w: float = x1 - x0
	var z0: float = -cut.start
	var z1: float = -cut.end
	var length: float = cut.length()
	var top: float = -ZoneSkin.CUT_STRIP_TOP
	var y: float = ZoneSkin.CUT_LIP_LIFT
	var inset: float = ZoneSkin.CUT_WALL_INSET
	var wall: float = depth + top
	# The inside's end walls, below the floor, across the lane's whole floor (joined lanes' meet).
	var ends := MeshBatch.new()
	var e: MeshLayer = ends.layer(solid)
	e.rect(Vector3(x0, -depth, z1 + inset), Vector3(w, 0, 0), Vector3(0, wall, 0), inside, 0.0, pattern)
	e.rect(Vector3(x1, -depth, z0 - inset), Vector3(-w, 0, 0), Vector3(0, wall, 0), inside, 0.0, pattern)
	_add(cut, ends.commit(parent, "HoleEnds"), &"static", 0)
	for side: int in [-1, 1]:
		# The inside's wall along this side, just inside the lane's edge, facing into the hole.
		var walls := MeshBatch.new()
		var s: MeshLayer = walls.layer(solid)
		if side < 0:
			s.rect(Vector3(x0 + inset, -depth, z0), Vector3(0, 0, -length), Vector3(0, wall, 0), inside, 0.0, pattern)
		else:
			s.rect(Vector3(x1 - inset, -depth, z1), Vector3(0, 0, length), Vector3(0, wall, 0), inside, 0.0, pattern)
		_add(cut, walls.commit(parent, "HoleWall%s" % ("L" if side < 0 else "R")), &"static", side)
		if not cut.has_neighbour(side):
			continue
		# Along the cut on this side: the lip on the neighbouring lane's floor right at the edge, the dark line
		# outside it, and the strip along the top of the inside's wall.
		var along := MeshBatch.new()
		var a: MeshLayer = along.layer(solid)
		var ex: float = cut.edge_x(side)
		var lx: float = ex - lip if side < 0 else ex
		a.rect(Vector3(lx, y, z0), Vector3(lip, 0, 0), Vector3(0, 0, -length), edge, lip_glow)
		var dx: float = lx - dark if side < 0 else ex + lip
		a.rect(Vector3(dx, y, z0), Vector3(dark, 0, 0), Vector3(0, 0, -length), dark_color)
		if side < 0:
			a.rect(Vector3(x0 + inset + 0.004, top - strip_h, z0), Vector3(0, 0, -length), Vector3(0, strip_h, 0), edge, strip_glow)
		else:
			a.rect(Vector3(x1 - inset - 0.004, top - strip_h, z1), Vector3(0, 0, length), Vector3(0, strip_h, 0), edge, strip_glow)
		_add(cut, along.commit(parent, "HoleEdge%s" % ("L" if side < 0 else "R")), &"span", side)
	# The floor's far end where the cut has got to (built at its end, moved to its front): its lip and dark line.
	var near := MeshBatch.new()
	var n: MeshLayer = near.layer(solid)
	n.rect(Vector3(x0, y, z1 + lip), Vector3(w, 0, 0), Vector3(0, 0, -lip), edge, lip_glow)
	n.rect(Vector3(x0, y, z1 + lip + dark), Vector3(w, 0, 0), Vector3(0, 0, -dark), dark_color)
	_add(cut, near.commit(parent, "HoleFront"), &"front", 0)
	# The far side, facing the player: the lip on the floor beyond it, its dark line, the strip along the top
	# of its face.
	var far := MeshBatch.new()
	var f: MeshLayer = far.layer(solid)
	f.rect(Vector3(x0, y, z1), Vector3(w, 0, 0), Vector3(0, 0, -lip), edge, lip_glow)
	f.rect(Vector3(x0, y, z1 - lip), Vector3(w, 0, 0), Vector3(0, 0, -dark), dark_color)
	f.rect(Vector3(x0, top - strip_h, z1 + inset + 0.004), Vector3(w, 0, 0), Vector3(0, strip_h, 0), edge, strip_glow)
	_add(cut, far.commit(parent, "HoleFar"), &"far", 0)
	# The halo that carries the far side from afar: a node of its own (join() makes one across a whole hole).
	_add(cut, halo(parent, glow, edge, x0 - HALO_SPILL, x1 + HALO_SPILL, z1), &"far", HALO)


## The far side's halo over world x [from, to] at the far end `z1` (world z): an additive streak along the top
## of the hole's far face, the palace floor's.
static func halo(parent: Node3D, glow: Material, edge: Color, from: float, to: float, z1: float) -> MeshInstance3D:
	var batch := MeshBatch.new()
	var strip_h: float = ZoneSkin.CUT_STRIP_HEIGHT
	var top: float = -ZoneSkin.CUT_STRIP_TOP
	batch.layer(glow).rect(Vector3(from, top - strip_h - HALO_BELOW, z1 + 0.05), Vector3(to - from, 0, 0),
		Vector3(0, strip_h + HALO_BELOW * 2.0, 0), edge, GoldenPalaceFloor.EDGE_HALO, MeshKit.SHAPE_STREAK)
	return batch.commit(parent, "HoleHalo")


static func _add(cut: FloorCutSection, node: MeshInstance3D, kind: StringName, side: int) -> void:
	if node == null:
		return
	node.set_meta(SIDE_META, side)
	match kind:
		&"static":
			cut.add_static(node)
		&"span":
			cut.add_span(node)
		&"front":
			cut.add_front(node)
		_:
			cut.add_far(node)


## The cuts of one hole, opened together (side by side, in any order): every part along a side that faces
## another of them goes, and their halos give way to one across the whole hole. Returns the parts taken away.
static func join(cuts: Array[FloorCut]) -> int:
	var lanes: Dictionary = {}
	for fc: FloorCut in cuts:
		if fc != null and is_instance_valid(fc):
			lanes[fc.lane] = fc
	if lanes.size() < 2:
		return 0
	var removed: int = 0
	var lo: FloorCut = null
	var hi: FloorCut = null
	var halo_parts: Array = []
	for lane: int in lanes:
		var fc: FloorCut = lanes[lane]
		if lo == null or fc.lane < lo.lane:
			lo = fc
		if hi == null or fc.lane > hi.lane:
			hi = fc
		for side: int in [-1, 1]:
			if lanes.has(lane + side):
				removed += _take(fc.section, side)
		halo_parts.append_array(_parts(fc.section, HALO))
	if halo_parts.is_empty():
		return removed
	# One halo from the hole's left edge to its right, where the first lane's was.
	var first := halo_parts[0] as MeshInstance3D
	var glow: Material = first.mesh.surface_get_material(0) if first.mesh != null else null
	var parent: Node3D = first.get_parent() as Node3D
	var edge: Color = Color(ZoneSkin.CUT_EDGE_COLOR)
	var colors: Variant = first.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR] if first.mesh != null else null
	if colors is PackedColorArray and not (colors as PackedColorArray).is_empty():
		edge = Color((colors as PackedColorArray)[0], 1.0)
	for fc: FloorCut in lanes.values():
		removed += _take(fc.section, HALO)
	if parent != null and glow != null:
		var whole: MeshInstance3D = halo(parent, glow, edge, lo.section.x0 - HALO_SPILL, hi.section.x1 + HALO_SPILL, -lo.section.end)
		_add(lo.section, whole, &"far", HALO)
		whole.visible = lo.began()
	return removed


## The parts of `section` tagged `side` (any kind).
static func _parts(section: FloorCutSection, side: int) -> Array:
	var out: Array = []
	for list: Array in [section.statics, section.spans, section.fronts, section.fars]:
		for node: Variant in list:
			if is_instance_valid(node) and int((node as Node).get_meta(SIDE_META, 0)) == side:
				out.append(node)
	return out


## Takes the parts of `section` tagged `side` out of it and frees them. Returns how many.
static func _take(section: FloorCutSection, side: int) -> int:
	var count: int = 0
	for list: Array in [section.statics, section.spans, section.fronts, section.fars]:
		for i: int in range(list.size() - 1, -1, -1):
			var node: Variant = list[i]
			if not is_instance_valid(node) or int((node as Node).get_meta(SIDE_META, 0)) != side:
				continue
			list.remove_at(i)
			(node as Node3D).visible = false
			(node as Node).queue_free()
			count += 1
	return count

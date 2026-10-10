class_name BeachCeilings
extends RefCounted
## Ceiling sections on the Beach (BeachSkin), picked per ceiling from the lanes it covers and by hashing its
## position (weights in the skin):
## - a boardwalk footbridge between the upper verandas, across every lane: a plank underside with flush
##   joists, bamboo rails across its near end under strings of warm lights, a thatched pavilion on some;
## - a veranda deck, over fewer lanes where the ceiling reaches a building: a deck cantilevered from that
##   building and running to its wall, a plank underside, a thick fascia with corbels along its free edge
##   (all above the underside), a bamboo railing and a thatched lean-to roof on posts;
## - a hovering party barge (a cyberpunk tiki boat), any width, or over fewer lanes reaching neither wall: a
##   flat black steel-plated hull underside, raked bow carrying the cult's emblem in unlit bronze, a plank
##   deck with a bamboo hut under a thatch roof, deck chairs, a mast with strings of lights and engines at the
##   stern glowing violet-blue (MeshKit.stern_halo).
## Every kind is built from the ceiling it's given: its width and position come from the collision box and the
## lane seams (center, size, lane_edges_x) and which sides reach a wall, so a ceiling over fewer lanes just
## builds narrower; only a footbridge needs every lane. Every underside is one flat surface across its lanes
## (no gaps between lanes, GDD §3) with a dark seam and flush warm lamps along each lane seam, nothing hanging
## below it but those, and the far end carries the orange edge band of every zone (MeshKit.ceiling_end), so
## the drop back to the floor reads like a gap edge. Glows past the far end stay above the underside
## (RunCamera.ceiling_limit). Everything above the underside stays under TOP_LIMIT, so what the walls hold
## out over the street (BeachShacks.OVER_STREET_MIN) never cuts through a ceiling.
## Ceiling space: origin at the centre of the underside (the ceiling surface), z = -distance.

enum Kind { FOOTBRIDGE, VERANDA, BARGE }

const END_BAND: float = 1.2
const LAMP_SPACING: float = 7.5
## Nothing of a ceiling rises more than this above its underside (the Corporate and Dead Zones' TOP_LIMIT's
## idea, lower here: the Beach's walls hang things out from OVER_STREET_MIN, 12 m, over a ceiling at 6 m).
const TOP_LIMIT: float = 5.4
## A deck's thickness (the ceiling box's own thickness) and its bamboo rail's height over it.
const DECK: float = 0.8
const RAIL: float = 1.05
## How far the cult's emblem on a barge's hull stands off it, and its clear square (as BeachShacks.EMBLEM_MARGIN).
const EMBLEM_STANDOFF: float = 0.02

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: BeachSkin:
	get:
		return _skin.get_ref() as BeachSkin
var _skin: WeakRef
var _meshes: Dictionary = {}


func _init(p_skin: BeachSkin) -> void:
	_skin = weakref(p_skin)


## Dresses a ceiling from its section (the lanes it covers, its box, its seams, the walls it reaches).
func build(parent: Node3D, section: CeilingSection) -> void:
	_place(parent, section.center, section.size, section.lane_edges_x, section.wall_x, section.reaches_wall(-1),
		section.reaches_wall(1))


## Dresses a ceiling given as its box alone (the wall faces from the chunk's walls): which sides reach a wall
## comes from the box.
func build_box(parent: Node3D, center: Vector3, size: Vector3, lane_edges_x: Array[float], wall_x: float) -> void:
	_place(parent, center, size, lane_edges_x, wall_x, reaches(center, size, wall_x, -1), reaches(center, size, wall_x, 1))


## Whether a ceiling box reaches the building on `side`: its edge is at the outer lane's edge (a wall's
## margin, 0.3 m, from the face).
static func reaches(center: Vector3, size: Vector3, wall_x: float, side: int) -> bool:
	return absf(center.x + float(side) * size.x * 0.5) >= wall_x - 0.35


func _place(parent: Node3D, center: Vector3, size: Vector3, edges: Array[float], wall_x: float, reach_l: bool, reach_r: bool) -> void:
	var kind: int = kind_of(center, size, wall_x, reach_l, reach_r)
	var variant: int = MeshKit.hash_i(MeshKit.key(center.z), MeshKit.key(size.z), 91) % 4
	var id: String = "%d_%d_%s_%s_%s_%s_%s_%s_%s" % [kind, variant, size, edges, center.x, wall_x, center.y, reach_l, reach_r]
	var mesh: ArrayMesh = _meshes.get(id)
	if mesh == null:
		if _meshes.size() > 256:
			_meshes.clear()
		mesh = mesh_for(kind, variant, size, edges, center.x, wall_x, reach_l, reach_r)
		_meshes[id] = mesh
	MeshBatch.add_instance(parent, mesh, "", Vector3(center.x, center.y - size.y * 0.5, center.z))


## Which kind of structure forms this ceiling: a footbridge across every lane, a veranda deck over fewer lanes
## reaching a building, a barge anywhere (and the only one over lanes reaching neither wall).
func kind_of(center: Vector3, size: Vector3, wall_x: float, reach_l: bool = false, reach_r: bool = false) -> int:
	if not reach_l and not reach_r:
		reach_l = reaches(center, size, wall_x, -1)
		reach_r = reaches(center, size, wall_x, 1)
	var first: float = 0.0
	var kind: int = Kind.FOOTBRIDGE
	if reach_l and reach_r:
		first = skin.footbridge_weight
	elif reach_l or reach_r:
		first = skin.veranda_weight
		kind = Kind.VERANDA
	else:
		return Kind.BARGE
	var total: float = first + skin.barge_weight
	if total <= 0.0:
		return kind
	var r: float = MeshKit.hash01(MeshKit.key(center.z), MeshKit.key(size.z), 90) * total
	return kind if r < first else Kind.BARGE


## The mesh of a ceiling of `kind` (colour variant 0-3) with collision size `size` centred on offset_x, seams at
## lane_edges_x (world x), walls at ±wall_x, reaching the wall on the left and right where `reach_l`/`reach_r`.
## In ceiling space (see above); build() places it.
func mesh_for(kind: int, variant: int, size: Vector3, lane_edges_x: Array[float], offset_x: float, wall_x: float,
		reach_l: bool = false, reach_r: bool = false) -> ArrayMesh:
	var batch := MeshBatch.new()
	var edges: Array[float] = []
	for x: float in lane_edges_x:
		edges.append(x - offset_x)
	# The underside's extent across: to the wall face on a side that reaches one, else a little past the box.
	var left: float = -wall_x - offset_x if reach_l else -size.x * 0.5 - 0.15
	var right: float = wall_x - offset_x if reach_r else size.x * 0.5 + 0.15
	match kind:
		Kind.FOOTBRIDGE:
			_footbridge(batch, size, edges, left, right, variant)
		Kind.VERANDA:
			_veranda(batch, size, edges, left, right, reach_l, variant)
		_:
			_barge(batch, size, edges, -size.x * 0.5 - 0.15, size.x * 0.5 + 0.15, variant, left, right)
	return batch.to_mesh()


## The underside across [x0, x1] from the far end's band to the near end: one surface in `pattern`, a darker
## seam and flush warm lamps along each lane seam, and the orange band at the far end.
func _underside(s: MeshLayer, g: MeshLayer, x0: float, x1: float, zn: float, zf: float, edges: Array[float], color: Color,
		pattern: int, param: float) -> void:
	var z0: float = zf + END_BAND
	s.rect(Vector3(x0, 0, z0), Vector3(x1 - x0, 0, 0), Vector3(0, 0, zn - z0), color, 0.0, pattern, Vector2.ZERO, Vector2.ONE, param)
	var seam := Color(skin.seam_color, 1.0)
	var lamp: Color = skin.ceiling_lamp_color
	for x: float in edges:
		s.box(Vector3(x, -0.006, (zn + z0) * 0.5), Vector3(0.06, 0.012, zn - z0), seam, 0.0, MeshKit.PAT_PLAIN,
			MeshKit.ALL_FACES & ~MeshKit.FACE_PY)
		var z: float = z0 + 4.0
		while z < zn - 2.0:
			s.box(Vector3(x, -0.02, z), Vector3(0.24, 0.04, 0.24), lamp, 0.75, MeshKit.PAT_PLAIN,
				MeshKit.ALL_FACES & ~MeshKit.FACE_PY)
			g.rect(Vector3(x - 0.8, -0.06, z + 0.8), Vector3(1.6, 0, 0), Vector3(0, 0, -1.6), lamp, 0.28, MeshKit.SHAPE_RADIAL)
			z += LAMP_SPACING
	MeshKit.ceiling_end(s, g, (x1 - x0) * 0.5, zf, END_BAND, skin.gap_edge_color, (x0 + x1) * 0.5)


## A four-cornered face wound to face `outward` (Godot's front faces wind clockwise).
func _quad(layer: MeshLayer, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3, color: Color, pattern: int = 0,
		param: float = 0.0) -> void:
	if (b - a).cross(c - a).dot(outward) > 0.0:
		layer.quad(a, d, c, b, color, 0.0, pattern, param)
	else:
		layer.quad(a, b, c, d, color, 0.0, pattern, param)


## A bamboo railing along a line: posts every ~1.4 m and two rails, from (x0, y, z0) to (x1, y, z1) (at least one
## of the two axes constant), `height` tall.
func _railing(s: MeshLayer, a: Vector3, b: Vector3, height: float, seed: int) -> void:
	var length: float = a.distance_to(b)
	var posts: int = maxi(roundi(length / 1.4), 1)
	for i: int in posts + 1:
		var p: Vector3 = a.lerp(b, float(i) / float(posts))
		s.box(p + Vector3(0, height * 0.5, 0), Vector3(0.07, height, 0.07), skin.post_color, 0.0, MeshKit.PAT_BEACH_TIMBER,
			MeshKit.ALL_FACES & ~MeshKit.FACE_NY, MeshKit.beach_timber_param(0, 0, seed + i))
	var axis: int = 1 if absf(b.x - a.x) > absf(b.z - a.z) else 2
	for f: float in [1.0, 0.55]:
		s.box((a + b) * 0.5 + Vector3(0, height * f, 0), Vector3(maxf(absf(b.x - a.x), 0.07), 0.06, maxf(absf(b.z - a.z), 0.07)),
			skin.post_color, 0.0, MeshKit.PAT_BEACH_TIMBER, MeshKit.ALL_FACES, MeshKit.beach_timber_param(axis, 0, seed + 7))


## A hip roof of thatch over the rectangle centred (cx, cz), half sizes (hx, hz), eaves at height y0, rising `rise`
## to a ridge along the longer axis.
func _hip_roof(s: MeshLayer, cx: float, cz: float, hx: float, hz: float, y0: float, rise: float, color: Color) -> void:
	var inset: float = minf(hx, hz) * 0.9
	var pa := Vector3(cx - hx, y0, cz - hz)
	var pb := Vector3(cx - hx, y0, cz + hz)
	var pc := Vector3(cx + hx, y0, cz + hz)
	var pd := Vector3(cx + hx, y0, cz - hz)
	var r0: Vector3
	var r1: Vector3
	if hx >= hz:
		r0 = Vector3(cx - hx + inset, y0 + rise, cz)
		r1 = Vector3(cx + hx - inset, y0 + rise, cz)
		_quad(s, pa, pb, r0, r0, Vector3(-1, 1, 0), color * 0.92, MeshKit.PAT_BEACH_THATCH)
		_quad(s, pd, pc, r1, r1, Vector3(1, 1, 0), color * 0.92, MeshKit.PAT_BEACH_THATCH)
		_quad(s, pb, pc, r1, r0, Vector3(0, 1, 1), color, MeshKit.PAT_BEACH_THATCH)
		_quad(s, pa, pd, r1, r0, Vector3(0, 1, -1), color * 0.9, MeshKit.PAT_BEACH_THATCH)
	else:
		r0 = Vector3(cx, y0 + rise, cz - hz + inset)
		r1 = Vector3(cx, y0 + rise, cz + hz - inset)
		_quad(s, pa, pd, r0, r0, Vector3(0, 1, -1), color * 0.9, MeshKit.PAT_BEACH_THATCH)
		_quad(s, pb, pc, r1, r1, Vector3(0, 1, 1), color, MeshKit.PAT_BEACH_THATCH)
		_quad(s, pa, pb, r1, r0, Vector3(-1, 1, 0), color * 0.92, MeshKit.PAT_BEACH_THATCH)
		_quad(s, pd, pc, r1, r0, Vector3(1, 1, 0), color * 0.92, MeshKit.PAT_BEACH_THATCH)
	# The eaves' dark underside.
	s.rect(Vector3(cx - hx, y0 - 0.005, cz + hz), Vector3(hx * 2.0, 0, 0), Vector3(0, 0, -hz * 2.0), skin.thatch_dark_color, 0.0,
		MeshKit.PAT_PLAIN)


# --- A boardwalk footbridge ---------------------------------------------------------------------

## A footbridge between the upper verandas across every lane: the plank underside from wall to wall with
## flush joists every 2.4 m, a timber fascia at its near end under a bamboo rail strung with warm bulbs, and on
## some a thatched pavilion on four bamboo posts over the deck.
func _footbridge(batch: MeshBatch, size: Vector3, edges: Array[float], x0: float, x1: float, variant: int) -> void:
	var s: MeshLayer = batch.layer(skin.solid_material())
	var g: MeshLayer = batch.layer(skin.glow_material())
	var zn: float = size.z * 0.5
	var zf: float = -size.z * 0.5
	_underside(s, g, x0, x1, zn, zf, edges, skin.plank_color, MeshKit.PAT_BEACH_TIMBER, MeshKit.beach_timber_param(1, 1, variant))
	# Joists across, flush with the planks (they stream past a rider).
	var z: float = zn - 1.5
	while z > zf + END_BAND + 0.5:
		s.box(Vector3((x0 + x1) * 0.5, -0.004, z), Vector3(x1 - x0, 0.008, 0.16), skin.timber_color * 0.55, 0.0, MeshKit.PAT_PLAIN,
			MeshKit.FACE_NY)
		z -= 2.4
	# The near end: a plank fascia, a timber cap, and the rail with its bulbs.
	s.rect(Vector3(x0, 0, zn), Vector3(x1 - x0, 0, 0), Vector3(0, DECK, 0), skin.plank_color * 1.05, 0.0, MeshKit.PAT_BEACH_TIMBER,
		Vector2.ZERO, Vector2.ONE, MeshKit.beach_timber_param(1, 1, variant + 2))
	s.box(Vector3((x0 + x1) * 0.5, DECK + 0.03, zn - 0.02), Vector3(x1 - x0, 0.06, 0.4), skin.timber_color * 0.7, 0.0,
		MeshKit.PAT_BEACH_TIMBER, MeshKit.ALL_FACES & ~MeshKit.FACE_NY, MeshKit.beach_timber_param(1, 1, variant + 5))
	_railing(s, Vector3(x0 + 0.2, DECK, zn - 0.15), Vector3(x1 - 0.2, DECK, zn - 0.15), RAIL, variant)
	var bulbs: int = roundi((x1 - x0) / 0.55)
	for i: int in bulbs:
		var x: float = lerpf(x0 + 0.35, x1 - 0.35, (float(i) + 0.5) / float(bulbs))
		s.box(Vector3(x, DECK + RAIL + 0.1, zn - 0.15), Vector3(0.1, 0.1, 0.1), _bulb(i), skin.lamp_glow)
	# A pavilion on some: a thatched roof on four bamboo posts over the middle of the deck.
	if variant % 2 == 0:
		var pw: float = minf((x1 - x0) * 0.32, 4.2)
		var pl: float = minf(size.z * 0.18, 5.0)
		var cz: float = zn - 2.0 - pl
		var cx: float = (x0 + x1) * 0.5
		var post_h: float = 2.2
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				s.box(Vector3(cx + sx * pw, DECK + post_h * 0.5, cz + sz * pl), Vector3(0.12, post_h, 0.12), skin.post_color, 0.0,
					MeshKit.PAT_BEACH_TIMBER, MeshKit.NO_BOTTOM, MeshKit.beach_timber_param(0, 0, variant))
		_hip_roof(s, cx, cz, pw + 0.4, pl + 0.4, DECK + post_h, 1.0, skin.thatch_color)


func _bulb(i: int) -> Color:
	match posmod(i, 5):
		1:
			return skin.neon_blue
		3:
			return skin.neon_violet
	return skin.lamp_color


# --- A veranda deck -------------------------------------------------------------------------

## A veranda deck over the lanes a ceiling covers next to a building (`on_left`: the building on the left wall,
## else the right): the plank underside from the wall face to its free edge, flush joists, a thick fascia along
## the free edge and at the near end (corbels on its face: plates standing on the underside's plane), a bamboo
## railing along both, and a thatched lean-to roof from the building down to bamboo posts on the free edge.
func _veranda(batch: MeshBatch, size: Vector3, edges: Array[float], x0: float, x1: float, on_left: bool, variant: int) -> void:
	var s: MeshLayer = batch.layer(skin.solid_material())
	var g: MeshLayer = batch.layer(skin.glow_material())
	var zn: float = size.z * 0.5
	var zf: float = -size.z * 0.5
	_underside(s, g, x0, x1, zn, zf, edges, skin.plank_color, MeshKit.PAT_BEACH_TIMBER, MeshKit.beach_timber_param(1, 1, variant))
	var z: float = zn - 1.5
	while z > zf + END_BAND + 0.5:
		s.box(Vector3((x0 + x1) * 0.5, -0.004, z), Vector3(x1 - x0, 0.008, 0.16), skin.timber_color * 0.55, 0.0, MeshKit.PAT_PLAIN,
			MeshKit.FACE_NY)
		z -= 2.4
	var fs: float = 1.0 if on_left else -1.0
	# The free edge is on the opposite side to the building: x = free_x.
	var free_x: float = x1 if on_left else x0
	var wall_x: float = x0 if on_left else x1
	var dir: float = -fs
	# The fascia along the free edge, facing out over the lanes, and across the near end.
	_quad(s, Vector3(free_x, 0, zn), Vector3(free_x, DECK, zn), Vector3(free_x, DECK, zf), Vector3(free_x, 0, zf), Vector3(fs, 0, 0),
		skin.plank_color * 1.05, MeshKit.PAT_BEACH_TIMBER, MeshKit.beach_timber_param(2, 1, variant + 2))
	s.rect(Vector3(x0, 0, zn), Vector3(x1 - x0, 0, 0), Vector3(0, DECK, 0), skin.plank_color * 1.05, 0.0, MeshKit.PAT_BEACH_TIMBER,
		Vector2.ZERO, Vector2.ONE, MeshKit.beach_timber_param(1, 1, variant + 3))
	# Corbels: dark triangular plates on the free-edge fascia, standing on the underside's plane.
	var cz: float = zn - 2.0
	while cz > zf + END_BAND + 1.0:
		_quad(s, Vector3(free_x + fs * 0.02, 0.06, cz + 0.3), Vector3(free_x + fs * 0.02, DECK - 0.06, cz + 0.3),
			Vector3(free_x + fs * 0.02, 0.06, cz - 0.3), Vector3(free_x + fs * 0.02, 0.06, cz - 0.3), Vector3(fs, 0, 0), skin.timber_color * 0.5)
		cz -= 3.0
	# The railing along the free edge and across the near end, a cap beam over the fascia.
	s.box(Vector3(free_x - fs * 0.1, DECK + 0.03, (zn + zf) * 0.5), Vector3(0.3, 0.06, zn - zf), skin.timber_color * 0.7, 0.0,
		MeshKit.PAT_BEACH_TIMBER, MeshKit.ALL_FACES & ~MeshKit.FACE_NY, MeshKit.beach_timber_param(2, 1, variant + 5))
	_railing(s, Vector3(free_x - fs * 0.1, DECK, zn - 0.3), Vector3(free_x - fs * 0.1, DECK, zf + END_BAND + 0.3), RAIL, variant)
	_railing(s, Vector3(x0 + 0.1, DECK, zn - 0.15), Vector3(x1 - 0.1, DECK, zn - 0.15), RAIL, variant + 3)
	# The lean-to roof: from the building (high) down to posts on the free edge (low), over the deck's near half.
	var roof_len: float = minf(size.z * 0.4, 14.0)
	var roof_far: float = zn - 1.0 - roof_len
	var post_h: float = 2.3
	var hi: float = minf(post_h + 1.1, TOP_LIMIT - 0.4)
	var post_count: int = maxi(roundi(roof_len / 3.5), 1)
	for i: int in post_count + 1:
		var pz: float = lerpf(zn - 1.0, roof_far, float(i) / float(post_count))
		s.box(Vector3(free_x - fs * 0.1, DECK + post_h * 0.5, pz), Vector3(0.12, post_h, 0.12), skin.post_color, 0.0, MeshKit.PAT_BEACH_TIMBER,
			MeshKit.NO_BOTTOM, MeshKit.beach_timber_param(0, 0, variant))
		# A bracket from the post up to the roof (a diagonal strut, all over the deck).
		var strut := Vector3(dir * 0.7, 0.7, 0.0)
		s.box_xform(Transform3D(Basis.looking_at(strut.normalized(), Vector3.UP).scaled_local(Vector3(0.07, 0.07, strut.length())),
			Vector3(free_x - fs * 0.1, DECK + post_h - 0.35, pz) + strut * 0.5), skin.timber_color * 0.6)
	_quad(s, Vector3(wall_x, DECK + hi, zn - 1.0), Vector3(free_x - fs * 0.1, DECK + post_h, zn - 1.0), Vector3(free_x - fs * 0.1, DECK + post_h, roof_far),
		Vector3(wall_x, DECK + hi, roof_far), Vector3(fs, 1.0, 0.0), skin.thatch_color, MeshKit.PAT_BEACH_THATCH)
	# The roof's fringe facing the lanes.
	_quad(s, Vector3(free_x - fs * 0.1, DECK + post_h - 0.3, zn - 1.0), Vector3(free_x - fs * 0.1, DECK + post_h, zn - 1.0),
		Vector3(free_x - fs * 0.1, DECK + post_h, roof_far), Vector3(free_x - fs * 0.1, DECK + post_h - 0.3, roof_far), Vector3(fs, 0, 0),
		skin.thatch_color * 0.85, MeshKit.PAT_BEACH_THATCH)
	_quad(s, Vector3(wall_x, DECK + hi, zn - 1.0), Vector3(free_x - fs * 0.1, DECK + post_h, zn - 1.0), Vector3(free_x - fs * 0.1, DECK + post_h - 0.3, zn - 1.0),
		Vector3(wall_x, DECK + hi - 0.3, zn - 1.0), Vector3(0, 0, 1), skin.thatch_color * 0.8, MeshKit.PAT_BEACH_THATCH)
	# Bulbs along the roof's lower edge.
	var bulbs: int = maxi(roundi(roof_len / 0.8), 2)
	for i: int in bulbs:
		var bz: float = lerpf(zn - 1.2, roof_far + 0.2, (float(i) + 0.5) / float(bulbs))
		s.box(Vector3(free_x - fs * 0.1, DECK + post_h - 0.4, bz), Vector3(0.1, 0.1, 0.1), _bulb(i), skin.lamp_glow)


# --- A party barge --------------------------------------------------------------------------

## A hovering party barge heading toward the player: a flat black steel hull underside (the ceiling), sloped
## sides with a painted stripe and warm lamps, a raked bow carrying the cult's emblem in unlit bronze, a plank
## deck with a bamboo rail, a bamboo hut under a thatch roof, deck chairs, a mast with strings of lights and a
## flag, and engines at the stern glowing violet-blue. Its x range is the box's (a little past it); `reach_l`/
## `reach_r` ranges come in as left/right for a wide barge that spans to the walls.
func _barge(batch: MeshBatch, size: Vector3, edges: Array[float], x0: float, x1: float, variant: int, _wall_l: float,
		_wall_r: float) -> void:
	var s: MeshLayer = batch.layer(skin.solid_material())
	var g: MeshLayer = batch.layer(skin.glow_material())
	var zn: float = size.z * 0.5
	var zf: float = -size.z * 0.5
	var hw: float = (x1 - x0) * 0.5
	var cx: float = (x0 + x1) * 0.5
	var hull: Color = skin.hull_color
	var rise: float = 1.1
	var slope: float = minf(0.6, hw * 0.25)
	_underside(s, g, x0, x1, zn, zf, edges, hull, MeshKit.PAT_BEACH_STEEL, 2.0)
	var stripe: Color = skin.paint_colors[(variant + 1) % skin.paint_colors.size()]
	var lamp: Color = skin.lamp_color
	for side: float in [-1.0, 1.0]:
		var xe: float = cx + side * hw
		var xi: float = xe - side * slope
		# The hull's side, from the underside's edge up to the deck, facing out and up.
		_quad(s, Vector3(xe, 0, zn), Vector3(xi, rise, zn - 1.0), Vector3(xi, rise, zf), Vector3(xe, 0, zf), Vector3(side, 0.3, 0),
			hull, MeshKit.PAT_BEACH_STEEL, 2.0)
		# A painted stripe along it, and a warm lamp every few metres.
		var out := Vector3(side * 0.012, 0, 0)
		var f0: float = 0.45
		var f1: float = 0.62
		_quad(s, Vector3(lerpf(xe, xi, f0), rise * f0, zn - 1.0 * f0) + out, Vector3(lerpf(xe, xi, f1), rise * f1, zn - 1.0 * f1) + out,
			Vector3(lerpf(xe, xi, f1), rise * f1, zf) + out, Vector3(lerpf(xe, xi, f0), rise * f0, zf) + out, Vector3(side, 0.3, 0), stripe)
		var lz: float = zf + 3.0
		while lz < zn - 2.0:
			s.box(Vector3(lerpf(xe, xi, 0.8) + side * 0.01, rise * 0.8, lz), Vector3(0.1, 0.1, 0.1), lamp, 0.55)
			lz += 2.6
	# The raked bow, with the emblem; the deck over the hull; a bamboo rail round it.
	var bow: Color = hull * 1.15
	_quad(s, Vector3(x0, 0, zn), Vector3(x0 + slope, rise, zn - 1.0), Vector3(x1 - slope, rise, zn - 1.0), Vector3(x1, 0, zn),
		Vector3(0, 0.4, 1), bow, MeshKit.PAT_BEACH_STEEL, 2.0)
	var e: float = skin.emblem_min_size
	var half: float = e * BeachShacks.EMBLEM_MARGIN * 0.5
	if hw * 2.0 >= half * 2.0 + 0.4:
		var rake := Vector3(0, rise, -1.0).normalized()
		var ctr := Vector3(cx, rise * 0.5, zn - 0.5) + Vector3(0, 0, EMBLEM_STANDOFF) + Vector3(0, 0.02, 0.0)
		var u := Vector3(half * 2.0, 0, 0)
		var v: Vector3 = rake * (half * 2.0)
		var m: float = BeachShacks.EMBLEM_MARGIN
		s.rect(ctr - u * 0.5 - v * 0.5, u, v, skin.emblem_metal_color(), 0.0, MeshKit.PAT_CULT_MARK, Vector2(-m, -m), Vector2(m, m))
	var deck: Color = skin.plank_color
	s.rect(Vector3(x0 + slope, rise, zn - 1.0), Vector3(x1 - x0 - slope * 2.0, 0, 0), Vector3(0, 0, zf - (zn - 1.0)), deck * 1.05, 0.0,
		MeshKit.PAT_BEACH_TIMBER, Vector2.ZERO, Vector2.ONE, MeshKit.beach_timber_param(1, 1, variant))
	# The rail round the deck (post spacing wide: it is seen from far below).
	_railing(s, Vector3(x0 + slope + 0.15, rise, zn - 1.2), Vector3(x0 + slope + 0.15, rise, zf + END_BAND + 0.3), 0.85, variant)
	_railing(s, Vector3(x1 - slope - 0.15, rise, zn - 1.2), Vector3(x1 - slope - 0.15, rise, zf + END_BAND + 0.3), 0.85, variant + 1)
	_railing(s, Vector3(x0 + slope + 0.15, rise, zn - 1.2), Vector3(x1 - slope - 0.15, rise, zn - 1.2), 0.85, variant + 2)
	# The hut: a bamboo box with a dark door under a thatch roof, toward the stern.
	var hut_w: float = minf((x1 - x0 - slope * 2.0) * 0.55, 3.8)
	var hut_l: float = minf(size.z * 0.3, 6.0)
	var hut_z: float = zf + END_BAND + 2.0 + hut_l * 0.5
	var hut_h: float = 2.0
	var bamboo: Color = skin.bamboo_colors[variant % skin.bamboo_colors.size()]
	if hut_w > 1.2 and hut_l > 2.0 and hut_z + hut_l * 0.5 < zn - 3.0:
		s.box(Vector3(cx, rise + hut_h * 0.5, hut_z), Vector3(hut_w, hut_h, hut_l), bamboo, 0.0, MeshKit.PAT_BEACH_WALL,
			MeshKit.ALL_FACES & ~MeshKit.FACE_NY, float(variant * 8 + 40))
		s.box(Vector3(cx, rise + 0.85, hut_z + hut_l * 0.5 + 0.01), Vector3(0.9, 1.6, 0.02), skin.bamboo_dark_color * 0.5)
		_hip_roof(s, cx, hut_z, hut_w * 0.5 + 0.5, hut_l * 0.5 + 0.5, rise + hut_h, 0.9, skin.thatch_color)
		# Deck chairs in front of it: a frame, a canvas seat and back in muted paint.
		for k: int in 2:
			var chx: float = cx + (float(k) - 0.5) * minf(hut_w * 0.7, 2.2)
			var chz: float = hut_z + hut_l * 0.5 + 1.4
			var paint: Color = skin.paint_colors[(variant + k) % skin.paint_colors.size()]
			s.box(Vector3(chx, rise + 0.22, chz), Vector3(0.7, 0.1, 0.9), paint * 0.9)
			s.box(Vector3(chx, rise + 0.55, chz - 0.5), Vector3(0.7, 0.62, 0.08), paint * 0.8)
			s.box(Vector3(chx, rise + 0.1, chz), Vector3(0.6, 0.18, 0.8), skin.timber_color * 0.7)
		# The mast on the hut's roof: a bamboo pole with a pennant and a string of bulbs down to the bow.
		var mast_top: float = minf(rise + hut_h + 0.9 + 1.6, TOP_LIMIT - 0.15)
		var mast_x: float = cx
		var mast_z: float = hut_z
		s.box(Vector3(mast_x, (rise + hut_h + 0.9 + mast_top) * 0.5, mast_z), Vector3(0.08, mast_top - rise - hut_h - 0.9, 0.08), skin.post_color,
			0.0, MeshKit.PAT_BEACH_TIMBER, MeshKit.ALL_FACES, MeshKit.beach_timber_param(0, 0, variant))
		var flag: Color = skin.flag_colors[variant % skin.flag_colors.size()]
		s.quad(Vector3(mast_x, mast_top, mast_z), Vector3(mast_x + 0.9, mast_top - 0.2, mast_z), Vector3(mast_x + 0.9, mast_top - 0.2, mast_z),
			Vector3(mast_x, mast_top - 0.5, mast_z), flag, 0.0)
		s.quad(Vector3(mast_x, mast_top, mast_z), Vector3(mast_x, mast_top - 0.5, mast_z), Vector3(mast_x + 0.9, mast_top - 0.2, mast_z),
			Vector3(mast_x + 0.9, mast_top - 0.2, mast_z), flag * 0.85, 0.0)
		var from := Vector3(mast_x, mast_top - 0.2, mast_z)
		var to := Vector3(x0 + slope + 0.3, rise + 0.9, zn - 1.4)
		for i: int in 8:
			var t: float = float(i + 1) / 9.0
			var p: Vector3 = from.lerp(to, t)
			p.y -= 0.25 * 4.0 * t * (1.0 - t)
			s.box(p, Vector3(0.1, 0.1, 0.1), _bulb(i), skin.lamp_glow)
	# The engines at the stern: dark nozzles and violet-blue cores over the orange band; the halos stop at the
	# underside (MeshKit.stern_halo), as every far end must.
	var engines: int = clampi(roundi(hw * 2.0 / 4.0), 1, 4)
	for i: int in engines:
		var ex: float = x0 + (float(i) + 0.5) * hw * 2.0 / float(engines)
		var r: float = minf(0.7, hw / float(engines) * 0.7)
		var nozzle := Transform3D(Basis(Vector3(r, 0, 0), Vector3(0, 0, -1.0), Vector3(0, r, 0)), Vector3(ex, 0.8, zf))
		s.prism_xform(nozzle, 8, skin.hull_color * 1.4, 0.0, MeshKit.PAT_BEACH_STEEL, false, 2.0)
		var core := Transform3D(Basis(Vector3(r * 0.7, 0, 0), Vector3(0, 0, -0.05), Vector3(0, r * 0.7, 0)), Vector3(ex, 0.8, zf - 0.9))
		s.prism_xform(core, 8, skin.engine_color, 0.9)
		MeshKit.stern_halo(g, Vector3(ex, 0.8, zf - 1.1), r * 2.2, skin.engine_color, 0.35)

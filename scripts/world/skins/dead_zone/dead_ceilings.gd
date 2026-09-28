class_name DeadCeilings
extends RefCounted
## Ceiling sections in the Dead Zone (DeadZoneSkin), GDD §5: "only the remains of the destroyed city,
## such as the undersides of dead buildings and crumbling, charred grey bridges". The kind comes from
## the lanes the ceiling covers and, across every lane, from hashing its position (weights in the skin):
## - a BRIDGE (across every lane): a crumbling, charred grey elevated road running along the street,
##   carried into the towers on both sides: a cracked fascia across its near end with bites out of its
##   top, a broken crash barrier and bent railing, a burnt-out wreck and a toppled lamp post on its deck;
## - a BUILDING (across every lane): the burnt-out upper storeys of a dead tower bridging the street,
##   its gutted face toward the approach (MeshKit.PAT_DZ_TOWER), its top broken off, steel sticking out;
## - a SLAB (fewer lanes, reaching one wall): a floor slab broken off the tower on that side, jutting out
##   over its lanes, its free edge ragged with rebar, a stub of the storey that stood on it, and cables
##   from the tower holding it up;
## - a SPAN (fewer lanes, reaching neither wall): a collapsed span, a length of elevated walkway fallen
##   from the steel gantry that carried it (which still spans the street from wall to wall above it),
##   hanging from it on bent rods.
## Every kind is built from the ceiling it's given: its width and position come from the collision box
## and the lane seams (center, size, lane_edges_x), and each side either runs into a building face (it
## reaches the street's edge) or ends in a free edge over a floor lane, so a ceiling over fewer lanes
## (narrow ceilings, task B3) just builds narrower. Every underside is one flat surface of charred
## concrete across its lanes (no gaps between lanes, GDD §3) with a steel strip and a pale line along
## each lane seam, so a runner hanging from it reads the lanes; nothing hangs below it, and its far end
## carries the orange band of every zone (MeshKit.ceiling_end), so the drop back to the floor reads like
## a gap edge. Past the far end nothing reaches below the underside and nothing glows but that band.
## Nothing rises more than TOP_LIMIT above the underside, so what the walls hold out over the street
## (DeadTowers.OVER_STREET_MIN) never cuts through a ceiling.
## Ceiling space: origin at the centre of the underside (the ceiling surface), z = -distance.

enum Kind { BRIDGE, BUILDING, SLAB, SPAN }

const END_BAND: float = 1.2
## Nothing of a ceiling rises higher than this above its underside.
const TOP_LIMIT: float = 7.4
## How far the underside overhangs a free side.
const FREE_LIP: float = 0.15
## A side reaches the street's edge (and runs into the building face) when its collision box's edge is
## this close to the wall face or closer (the outer lane's edge is the wall margin away).
const WALL_REACH: float = 0.6
## The bridge's deck and fascia; the slab's and the span's thickness.
const DECK: float = 1.3
const SLAB: float = 0.8

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: DeadZoneSkin:
	get:
		return _skin.get_ref() as DeadZoneSkin
var _skin: WeakRef
var _meshes: Dictionary = {}


func _init(p_skin: DeadZoneSkin) -> void:
	_skin = weakref(p_skin)


## Dresses the ceiling with collision box center/size and seams lane_edges_x (world x). wall_x is the
## wall faces' distance from the track's centre.
func build(parent: Node3D, center: Vector3, size: Vector3, lane_edges_x: Array[float], wall_x: float) -> void:
	var kind: int = kind_of(center, size, wall_x)
	var variant: int = MeshKit.hash_i(MeshKit.key(center.z), MeshKit.key(size.z), 91) % 4
	var id: String = "%d_%d_%s_%s_%s_%s_%s" % [kind, variant, size, lane_edges_x, center.x, wall_x, center.y]
	var mesh: ArrayMesh = _meshes.get(id)
	if mesh == null:
		if _meshes.size() > 256:
			_meshes.clear()
		mesh = mesh_for(kind, variant, size, lane_edges_x, center.x, wall_x, center.y - size.y * 0.5)
		_meshes[id] = mesh
	MeshBatch.add_instance(parent, mesh, "", Vector3(center.x, center.y - size.y * 0.5, center.z))


## Whether the ceiling's side toward `side` (-1 left, +1 right) reaches the street's edge, where it can
## run into the building face.
static func reaches_wall(center: Vector3, size: Vector3, side: int, wall_x: float) -> bool:
	return side * (center.x + side * size.x * 0.5) > wall_x - WALL_REACH


## Which kind of remains forms this ceiling: across every lane a bridge or a dead building (by hash and
## weight), a slab broken off a tower when it reaches one wall, a collapsed span when it reaches none.
func kind_of(center: Vector3, size: Vector3, wall_x: float) -> int:
	var left: bool = reaches_wall(center, size, -1, wall_x)
	var right: bool = reaches_wall(center, size, 1, wall_x)
	if left != right:
		return Kind.SLAB
	if not left:
		return Kind.SPAN
	var total: float = skin.bridge_weight + skin.building_weight
	if total <= 0.0:
		return Kind.BRIDGE
	var r: float = MeshKit.hash01(MeshKit.key(center.z), MeshKit.key(size.z), 90) * total
	return Kind.BRIDGE if r < skin.bridge_weight else Kind.BUILDING


## The mesh of a ceiling of `kind` (variant 0-3) with collision size `size` centred on offset_x, seams at
## lane_edges_x (world x), its underside at world height surface_y, the walls at ±wall_x. In ceiling
## space (see above); build() places it. Which sides reach a wall follows from the box and wall_x.
func mesh_for(kind: int, variant: int, size: Vector3, lane_edges_x: Array[float], offset_x: float, wall_x: float,
		surface_y: float) -> ArrayMesh:
	var batch := MeshBatch.new()
	var center := Vector3(offset_x, 0.0, 0.0)
	var left: bool = reaches_wall(center, size, -1, wall_x)
	var right: bool = reaches_wall(center, size, 1, wall_x)
	var xa: float = (-wall_x - offset_x) if left else -size.x * 0.5 - FREE_LIP
	var xb: float = (wall_x - offset_x) if right else size.x * 0.5 + FREE_LIP
	var edges: Array[float] = []
	for x: float in lane_edges_x:
		edges.append(x - offset_x)
	var s: MeshLayer = batch.layer(skin.solid_material())
	var g: MeshLayer = batch.layer(skin.glow_material())
	var zn: float = size.z * 0.5
	var zf: float = -size.z * 0.5
	var color: Color = skin.bridge_color if kind == Kind.BRIDGE else skin.slab_color
	_underside(s, g, xa, xb, zn, zf, edges, color)
	match kind:
		Kind.BRIDGE:
			_bridge(s, xa, xb, zn, zf, variant, offset_x)
		Kind.BUILDING:
			_building(s, xa, xb, zn, zf, variant, surface_y)
		Kind.SLAB:
			_slab(s, xa, xb, zn, zf, variant, -1 if left else 1)
		_:
			_span(s, xa, xb, zn, zf, variant, wall_x, offset_x)
	return batch.to_mesh()


## The underside across [xa, xb] from the far end's band to the near end: one surface of charred
## concrete (PAT_DZ_CONCRETE's soffit, its formwork joints streaming past overhead), a steel strip with a
## pale line along each lane seam, and the orange band at the far end.
func _underside(s: MeshLayer, g: MeshLayer, xa: float, xb: float, zn: float, zf: float, edges: Array[float],
		color: Color) -> void:
	var z0: float = zf + END_BAND
	s.rect(Vector3(xa, 0, z0), Vector3(xb - xa, 0, 0), Vector3(0, 0, zn - z0), color, 0.0, MeshKit.PAT_DZ_CONCRETE,
		Vector2.ZERO, Vector2.ONE, 1.0)
	for x: float in edges:
		s.box(Vector3(x, -0.006, (zn + z0) * 0.5), Vector3(0.12, 0.012, zn - z0), skin.steel_color, 0.0, MeshKit.PAT_DZ_STEEL,
			MeshKit.ALL_FACES & ~MeshKit.FACE_PY)
		s.box(Vector3(x, -0.0135, (zn + z0) * 0.5), Vector3(0.035, 0.003, zn - z0), skin.seam_color, 0.0, MeshKit.PAT_PLAIN,
			MeshKit.FACE_NY)
	MeshKit.ceiling_end(s, g, (xb - xa) * 0.5, zf, END_BAND, skin.gap_edge_color, (xa + xb) * 0.5)


## A face across the ceiling's near end (toward the approaching runner) from xa to xb, from the
## underside up to a broken top: `height` less a ragged profile and a bite out of it.
func _near_face(s: MeshLayer, xa: float, xb: float, zn: float, height: float, color: Color, k: int, pattern: int,
		param: float, surface_y: float = 0.0) -> void:
	var bite_x: float = lerpf(xa + 1.0, xb - 1.0, MeshKit.hash01(k, 7))
	var bite_w: float = 1.5 + 2.0 * MeshKit.hash01(k, 8)
	var bite_d: float = height * (0.2 + 0.4 * MeshKit.hash01(k, 9))
	var x: float = xa
	var top: float = _profile(x, height, bite_x, bite_w, bite_d, k)
	while x < xb - 0.001:
		var nx: float = minf(floorf(x + 1.0001), xb)
		var ntop: float = _profile(nx, height, bite_x, bite_w, bite_d, k)
		if pattern == MeshKit.PAT_DZ_TOWER:
			s.quad_uv(Vector3(x, 0, zn), Vector3(x, top, zn), Vector3(nx, ntop, zn), Vector3(nx, 0, zn),
				Vector2(x, surface_y), Vector2(x, surface_y + top), Vector2(nx, surface_y + ntop), Vector2(nx, surface_y),
				color, 0.0, pattern, param)
		else:
			s.quad(Vector3(x, 0, zn), Vector3(x, top, zn), Vector3(nx, ntop, zn), Vector3(nx, 0, zn), color, 0.0, pattern, param)
		x = nx
		top = ntop


static func _profile(x: float, height: float, bite_x: float, bite_w: float, bite_d: float, k: int) -> float:
	var h: float = height - 0.25 * height * MeshKit.hash01(k, floori(x * 1.0001) + 1000, 3)
	return maxf(h - bite_d * maxf(0.0, 1.0 - absf(x - bite_x) / bite_w), height * 0.35)


## A free side's edge face (at x, facing out toward `side`) from the underside up to `height`, its top
## ragged, with rebar sticking out of the break.
func _free_edge(s: MeshLayer, x: float, side: float, zn: float, zf: float, height: float, color: Color, k: int) -> void:
	var z: float = zf
	while z < zn - 0.001:
		var nz: float = minf(z + 1.5, zn)
		var h0: float = height * (0.7 + 0.3 * MeshKit.hash01(k, floori(z * 10.0), 21))
		var h1: float = height * (0.7 + 0.3 * MeshKit.hash01(k, floori(nz * 10.0), 21))
		# quad() faces (d - a) x (b - a): out toward `side`.
		if side < 0.0:
			s.quad(Vector3(x, 0, z), Vector3(x, h0, z), Vector3(x, h1, nz), Vector3(x, 0, nz), color, 0.0,
				MeshKit.PAT_DZ_CONCRETE, 0.0)
		else:
			s.quad(Vector3(x, 0, nz), Vector3(x, h1, nz), Vector3(x, h0, z), Vector3(x, 0, z), color, 0.0,
				MeshKit.PAT_DZ_CONCRETE, 0.0)
		if MeshKit.hash01(k, floori(z * 10.0), 22) < 0.6:
			var length: float = 0.2 + 0.3 * MeshKit.hash01(k, floori(z * 10.0), 23)
			var bend := Basis.from_euler(Vector3(0.0, 0.0, side * (0.2 + 0.5 * MeshKit.hash01(k, floori(z * 10.0), 24))))
			s.box_xform(Transform3D(bend.scaled_local(Vector3(length, 0.025, 0.025)), Vector3(x + side * length * 0.45,
				height * 0.45, (z + nz) * 0.5)), skin.steel_color, 0.0, MeshKit.PAT_DZ_STEEL)
		z = nz


# --- A crumbling, charred grey bridge -------------------------------------------------------

## An elevated road running along the street over every lane, carried into the towers: a cracked,
## charred fascia across its near end, a crash barrier broken open, a bent railing, a burnt-out wreck
## and a toppled lamp post on its deck.
func _bridge(s: MeshLayer, xa: float, xb: float, zn: float, zf: float, variant: int, offset_x: float) -> void:
	var k: int = variant * 131 + MeshKit.key(zn - zf)
	var concrete: Color = skin.bridge_color
	_near_face(s, xa, xb, zn, DECK, concrete.lightened(0.04), k, MeshKit.PAT_DZ_CONCRETE, 0.0)
	# The crash barrier along the near edge: concrete segments, some knocked askew, one gone.
	var steel: Color = skin.steel_color
	var gone: int = MeshKit.hash_i(k, 3) % 5
	var x: float = xa + 0.3
	var i: int = 0
	while x < xb - 1.9:
		if i % 5 != gone:
			var tilt := Basis.from_euler(Vector3(0.0, (MeshKit.hash01(k, i, 4) - 0.5) * 0.3, (MeshKit.hash01(k, i, 5) - 0.5) * 0.12))
			s.box_xform(Transform3D(tilt.scaled_local(Vector3(1.9, 0.8, 0.45)), Vector3(x + 0.95, DECK + 0.4, zn - 0.4)),
				concrete, 0.0, MeshKit.PAT_DZ_CONCRETE)
		x += 2.1
		i += 1
	# A railing behind it: posts (some missing) and a rail sagging where they are.
	var px: float = xa + 0.6
	while px < xb - 0.3:
		if MeshKit.hash01(k, floori(px * 10.0), 6) < 0.7:
			s.box(Vector3(px, DECK + 1.3, zn - 0.9), Vector3(0.06, 1.0, 0.06), steel, 0.0, MeshKit.PAT_DZ_STEEL)
		px += 1.6
	s.box(Vector3((xa + xb) * 0.5, DECK + 1.75, zn - 0.9), Vector3(xb - xa - 0.4, 0.06, 0.06), steel, 0.0,
		MeshKit.PAT_DZ_STEEL)
	# A burnt-out hover-car on the deck, its roof showing over the barrier.
	var wx: float = lerpf(xa + 2.0, xb - 2.0, MeshKit.hash01(k, 8))
	_wreck(s, Vector3(wx, DECK, zn - 3.5 - 4.0 * MeshKit.hash01(k, 9)), MeshKit.hash01(k, 10) * TAU)
	# A lamp post toppled across the deck, its head over the barrier.
	var lx: float = lerpf(xa + 1.0, xb - 1.0, MeshKit.hash01(k, 11))
	var fall := Basis.from_euler(Vector3(1.25, (MeshKit.hash01(k, 12) - 0.5) * 1.2, 0.0))
	s.box_xform(Transform3D(fall.scaled_local(Vector3(0.14, 5.0, 0.14)), Vector3(lx, DECK + 1.3, zn - 3.2)), steel, 0.0,
		MeshKit.PAT_DZ_STEEL)
	# Rubble heaped on the deck behind the barrier.
	for j: int in 3:
		var rx: float = lerpf(xa + 1.0, xb - 1.0, MeshKit.hash01(k, j, 13))
		var rz: float = lerpf(zf + 3.0, zn - 5.0, MeshKit.hash01(k, j, 14))
		var turn := Basis.from_euler(Vector3(0.2, MeshKit.hash01(k, j, 15) * 3.0, 0.15))
		s.box_xform(Transform3D(turn.scaled_local(Vector3(1.6, 0.7, 1.2)), Vector3(rx, DECK + 0.25, rz)), concrete.darkened(0.2),
			0.0, MeshKit.PAT_DZ_CONCRETE, MeshKit.NO_BOTTOM, 2.0)


## A burnt-out hover-car: a low body and a cabin, dark and scorched, its thrusters dead.
func _wreck(s: MeshLayer, at: Vector3, yaw: float) -> void:
	var turn := Basis(Vector3.UP, yaw)
	var body := Transform3D(turn.scaled_local(Vector3(1.9, 0.6, 4.2)), at + Vector3(0, 0.45, 0))
	s.box_xform(body, skin.wreck_color, 0.0, MeshKit.PAT_DZ_STEEL)
	var cabin := Transform3D(turn.scaled_local(Vector3(1.6, 0.55, 2.0)), at + Vector3(0, 1.0, 0) + turn * Vector3(0, 0, 0.3))
	s.box_xform(cabin, skin.wreck_color.darkened(0.2), 0.0, MeshKit.PAT_DZ_STEEL)


# --- A dead building bridging the street -------------------------------------------------------

## The burnt-out upper storeys of a dead tower bridging the street from wall to wall: its gutted face
## toward the approach (MeshKit.PAT_DZ_TOWER; UV in world height, so its windows sit in storeys), the
## slab edges of its floors, and the steel sticking out of its broken top.
func _building(s: MeshLayer, xa: float, xb: float, zn: float, zf: float, variant: int, surface_y: float) -> void:
	var k: int = variant * 211 + MeshKit.key(zn - zf)
	var wall: Color = skin.facade_colors[MeshKit.hash_i(k, 3) % skin.facade_colors.size()]
	var height: float = TOP_LIMIT - 0.4 - 0.5 * float(variant % 2)
	var param: float = MeshKit.dz_tower_param(MeshKit.hash_i(k, 4) % 4, MeshKit.hash_i(k, 5) % 997)
	_near_face(s, xa, xb, zn, height, wall, k, MeshKit.PAT_DZ_TOWER, param, surface_y)
	# Its lowest slab along the bottom, lit ash-grey on its edge, so the ceiling's edge reads from the floor.
	s.box(Vector3((xa + xb) * 0.5, 0.2, zn + 0.1), Vector3(xb - xa, 0.4, 0.2), skin.slab_color.lightened(0.12), 0.0,
		MeshKit.PAT_DZ_CONCRETE, MeshKit.NO_BOTTOM)
	# Girders sticking up out of the broken top.
	for i: int in 4:
		var gx: float = lerpf(xa + 0.8, xb - 0.8, (float(i) + 0.3 + 0.4 * MeshKit.hash01(k, i, 6)) / 4.0)
		var top: float = minf(height + 0.6 * MeshKit.hash01(k, i, 7), TOP_LIMIT - 0.05)
		var base_y: float = height * 0.45
		var lean := Basis.from_euler(Vector3((MeshKit.hash01(k, i, 8) - 0.5) * 0.2, 0.0, (MeshKit.hash01(k, i, 9) - 0.5) * 0.3))
		s.box_xform(Transform3D(lean.scaled_local(Vector3(0.28, top - base_y, 0.28)), Vector3(gx, (top + base_y) * 0.5,
			zn - 0.4)), skin.steel_color, 0.0, MeshKit.PAT_DZ_STEEL)


# --- A slab broken off a tower ------------------------------------------------------------------

## A floor slab broken off the tower on `wall_side`, jutting out over the ceiling's lanes: its broken
## near end and free edge (rebar bristling from the break), a stub of the storey that stood on it (a
## column and a piece of wall by the tower), and two cables from high on the tower holding its free end.
func _slab(s: MeshLayer, xa: float, xb: float, zn: float, zf: float, variant: int, wall_side: int) -> void:
	var k: int = variant * 173 + MeshKit.key(zn - zf)
	var concrete: Color = skin.slab_color
	var free_x: float = xb if wall_side < 0 else xa
	var wall_face: float = xa if wall_side < 0 else xb
	_near_face(s, xa, xb, zn, SLAB, concrete.lightened(0.06), k, MeshKit.PAT_DZ_CONCRETE, 0.0)
	_free_edge(s, free_x, -float(wall_side), zn, zf, SLAB, concrete.lightened(0.04), k)
	# The storey's stub by the tower: a column and a ragged piece of wall.
	var inward: float = -float(wall_side)
	var cz: float = lerpf(zf + 2.0, zn - 2.0, MeshKit.hash01(k, 3))
	var col_h: float = 2.2 + 1.2 * MeshKit.hash01(k, 4)
	s.box(Vector3(wall_face + inward * 0.6, SLAB + col_h * 0.5, cz), Vector3(0.5, col_h, 0.5), concrete, 0.0,
		MeshKit.PAT_DZ_CONCRETE)
	var wz0: float = lerpf(zf + 1.0, zn - 5.0, MeshKit.hash01(k, 5))
	var wall_h: float = 1.4 + 1.6 * MeshKit.hash01(k, 6)
	s.box(Vector3(wall_face + inward * 0.2, SLAB + wall_h * 0.5, wz0 + 2.0), Vector3(0.3, wall_h, 4.0),
		skin.facade_colors[MeshKit.hash_i(k, 7) % skin.facade_colors.size()], 0.0, MeshKit.PAT_DZ_CONCRETE)
	# Cables from high on the tower down to the free edge, holding it.
	var anchor_y: float = TOP_LIMIT - 0.3
	for z: float in [zn - 1.0, zf + END_BAND + 1.0]:
		var a := Vector3(wall_face, anchor_y, z)
		var b := Vector3(free_x - inward * 0.3, SLAB, z)
		_rod(s, a, b, 0.05)


# --- A collapsed span ----------------------------------------------------------------------------

## A length of elevated walkway fallen from its steel gantry and hanging from it over the ceiling's
## lanes: the deck's broken ends and free edges, the gantry's beams spanning the street from wall to
## wall above it, and the bent rods it hangs from.
func _span(s: MeshLayer, xa: float, xb: float, zn: float, zf: float, variant: int, wall_x: float, offset_x: float) -> void:
	var k: int = variant * 157 + MeshKit.key(zn - zf)
	var concrete: Color = skin.slab_color
	_near_face(s, xa, xb, zn, SLAB, concrete.lightened(0.06), k, MeshKit.PAT_DZ_CONCRETE, 0.0)
	_free_edge(s, xa, -1.0, zn, zf, SLAB, concrete.lightened(0.04), k)
	_free_edge(s, xb, 1.0, zn, zf, SLAB, concrete.lightened(0.04), k + 1)
	# The gantry: two steel beams across the street from wall to wall, and a beam along each side over the
	# deck between them.
	var steel: Color = skin.steel_color
	var y: float = TOP_LIMIT - 0.9 - 0.4 * float(variant % 2)
	var z_near: float = zn - 1.2
	var z_far: float = zf + END_BAND + 1.0
	var w0: float = -wall_x - offset_x
	var w1: float = wall_x - offset_x
	for z: float in [z_near, z_far]:
		s.box(Vector3((w0 + w1) * 0.5, y, z), Vector3(w1 - w0, 0.5, 0.4), steel, 0.0, MeshKit.PAT_DZ_STEEL)
	for x: float in [xa + 0.3, xb - 0.3]:
		s.box(Vector3(x, y - 0.35, (z_near + z_far) * 0.5), Vector3(0.3, 0.3, z_near - z_far), steel, 0.0, MeshKit.PAT_DZ_STEEL)
		# The rods it hangs from, bent a little.
		for z: float in [z_near, z_far]:
			_rod(s, Vector3(x, y - 0.5, z), Vector3(x + 0.15 * (MeshKit.hash01(k, floori(x * 10.0), 3) - 0.5), SLAB,
				z + 0.3 * (MeshKit.hash01(k, floori(z), 4) - 0.5)), 0.06)


## A thin steel rod or cable from a to b.
func _rod(s: MeshLayer, a: Vector3, b: Vector3, thickness: float) -> void:
	var d: Vector3 = b - a
	var length: float = d.length()
	if length < 0.01:
		return
	var y_axis: Vector3 = d / length
	var x_axis: Vector3 = y_axis.cross(Vector3.FORWARD if absf(y_axis.z) < 0.9 else Vector3.RIGHT).normalized()
	var z_axis: Vector3 = x_axis.cross(y_axis)
	var basis := Basis(x_axis * thickness, y_axis * length, z_axis * thickness)
	s.box_xform(Transform3D(basis, (a + b) * 0.5), skin.steel_color, 0.0, MeshKit.PAT_DZ_STEEL)

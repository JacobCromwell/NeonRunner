class_name IceLabCeilings
extends RefCounted
## Ceiling sections in the Ice Lab (IceLabSkin; GDD §5, Zone 9: "the ceilings are crane gantries and overhead walkways"). The kind is picked
## by hashing where the ceiling is, against the skin's weights (the lean: the gantry the industrial one's, the walkway the lab's):
## - a GANTRY: a crane gantry girder lodged over its lanes: the underside is its bottom flange, a deep web along its middle with
##   cross ribs and rivets, a top flange with a rail and snow on it, a hoist trolley with its cable drum on the rail, an end truck at the
##   near end, rods hanging it from the hall's crane runways overhead;
## - a WALKWAY: an overhead grated walkway (an inspection catwalk): the underside is its grating seen from below (bars and cross rods
##   with the dark slots between), a toe plate and a railing on posts along each side with snow on the rail, lab equipment (cabinets and a
##   cable tray) standing on the deck, a small amber lamp on a post, rods up to the crane runways.
## Every kind is built from the ceiling it's given: its width and position come from the collision box and the lane seams (center, size,
## lane_edges_x), so a ceiling over more or fewer lanes just builds wider or narrower. Every underside is one flat surface across its lanes
## (no gaps between lanes, GDD §3) with a darker strip and a pale line along each lane seam, so a runner hanging from it reads the lanes;
## nothing hangs below it, and its far end carries the orange band of every zone (MeshKit.ceiling_end), so the drop back to the floor reads like
## a gap edge. Past the far end nothing reaches below the underside and nothing glows but that band.
## Nothing rises more than TOP_LIMIT above the underside but the hanging rods (thin, in the open): everything else stays under the wall's own
## cornice and the hall's runways.
## DESIGN-TBD (docs/questions/q2.md item 7): the two kinds and their weights.
## Ceiling space: origin at the centre of the underside (the ceiling surface), z = -distance.

enum Kind { GANTRY, WALKWAY }

const END_BAND: float = 1.2
## Nothing but the hanging rods rises higher than this above the underside.
const TOP_LIMIT: float = 1.9
## The gantry's web height, and the walkway's rail height.
const WEB: float = 1.0
const RAIL: float = 1.05
## How high the hanging rods go above the underside (up to the crane runways).
const ROD_TOP: float = 8.6

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: IceLabSkin:
	get:
		return _skin.get_ref() as IceLabSkin
var _skin: WeakRef
var _parts: IceLabParts
var _meshes: Dictionary = {}


func _init(p_skin: IceLabSkin) -> void:
	_skin = weakref(p_skin)
	_parts = IceLabParts.new(p_skin)


## Dresses the ceiling with collision box center/size and seams lane_edges_x (world x). wall_x is the wall faces' distance from the
## track's centre.
func build(parent: Node3D, center: Vector3, size: Vector3, lane_edges_x: Array[float], wall_x: float) -> void:
	var variant: int = MeshKit.hash_i(MeshKit.key(center.z), MeshKit.key(size.z), 91) % 4
	var kind: int = kind_of(center, size)
	var id: String = "%d_%d_%s_%s_%s_%s_%s" % [kind, variant, size, lane_edges_x, center.x, wall_x, center.y]
	var mesh: ArrayMesh = _meshes.get(id)
	if mesh == null:
		if _meshes.size() > 256:
			_meshes.clear()
		mesh = mesh_for(kind, variant, size, lane_edges_x, center.x, wall_x)
		_meshes[id] = mesh
	MeshBatch.add_instance(parent, mesh, "", Vector3(center.x, center.y - size.y * 0.5, center.z))


## Which kind of ceiling this is: by hash and weight.
func kind_of(center: Vector3, size: Vector3) -> int:
	var gantry: float = skin.lean(skin.gantry_weight_frost, skin.gantry_weight_lab)
	var walkway: float = skin.lean(skin.walkway_weight_frost, skin.walkway_weight_lab)
	var total: float = gantry + walkway
	if total <= 0.0:
		return Kind.GANTRY
	var r: float = MeshKit.hash01(MeshKit.key(center.z), MeshKit.key(size.z), 90) * total
	return Kind.GANTRY if r < gantry else Kind.WALKWAY


## The mesh of a ceiling of `kind` (variant 0-3) with collision size `size` centred on offset_x, seams at lane_edges_x (world x). In
## ceiling space (see above); build() places it.
func mesh_for(kind: int, variant: int, size: Vector3, lane_edges_x: Array[float], offset_x: float, wall_x: float) -> ArrayMesh:
	var batch := MeshBatch.new()
	var xa: float = -size.x * 0.5
	var xb: float = size.x * 0.5
	var edges: Array[float] = []
	for x: float in lane_edges_x:
		edges.append(x - offset_x)
	var s: MeshLayer = batch.layer(skin.solid_material())
	var g: MeshLayer = batch.layer(skin.glow_material())
	var zn: float = size.z * 0.5
	var zf: float = -size.z * 0.5
	_underside(s, g, xa, xb, zn, zf, edges, 1.0 if kind == Kind.GANTRY else 4.0)
	match kind:
		Kind.GANTRY:
			_gantry(s, g, xa, xb, zn, zf, variant)
		_:
			_walkway(s, g, xa, xb, zn, zf, variant)
	_rods(s, xa, xb, zn, zf, variant, kind)
	return batch.to_mesh()


## The underside across [xa, xb] from the far end's band to the near end: one surface (`mode` PAT_IL_STEEL: 1 plating with beams every 3 m
## streaming past overhead, 4 grating seen from below), a darker strip with a pale line along each lane seam, and the orange band at the
## far end.
func _underside(s: MeshLayer, g: MeshLayer, xa: float, xb: float, zn: float, zf: float, edges: Array[float], mode: float) -> void:
	var z0: float = zf + END_BAND
	s.rect(Vector3(xa, 0, z0), Vector3(xb - xa, 0, 0), Vector3(0, 0, zn - z0), skin.steel_color.lightened(0.04), 0.0,
		MeshKit.PAT_IL_STEEL, Vector2.ZERO, Vector2.ONE, mode)
	for x: float in edges:
		s.box(Vector3(x, -0.006, (zn + z0) * 0.5), Vector3(0.12, 0.012, zn - z0), skin.post_color, 0.0, MeshKit.PAT_IL_STEEL,
			MeshKit.ALL_FACES & ~MeshKit.FACE_PY, 0.0)
		s.box(Vector3(x, -0.0135, (zn + z0) * 0.5), Vector3(0.035, 0.003, zn - z0), Color(0.55, 0.62, 0.7), 0.0, MeshKit.PAT_PLAIN,
			MeshKit.FACE_NY)
	MeshKit.ceiling_end(s, g, (xb - xa) * 0.5, zf, END_BAND, skin.gap_edge_color, (xa + xb) * 0.5)


# --- A crane gantry --------------------------------------------------------------------------------

func _gantry(s: MeshLayer, g: MeshLayer, xa: float, xb: float, zn: float, zf: float, variant: int) -> void:
	var k: int = variant * 131 + MeshKit.key(zn - zf)
	var steel: Color = skin.steel_color
	var xm: float = (xa + xb) * 0.5
	var w: float = xb - xa
	var z_a: float = zf + END_BAND
	var length: float = zn - z_a
	# The bottom flange's edge faces (the underside's thickness), the web up its middle with cross ribs every 1.5 m, rivets in lines along
	# it, and the top flange wider than the web.
	s.box(Vector3(xm, 0.09, (zn + z_a) * 0.5), Vector3(w, 0.18, length), steel, 0.0, MeshKit.PAT_IL_STEEL,
		MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PY, 0.0)
	var web_w: float = minf(0.24, w * 0.22)
	s.box(Vector3(xm, 0.18 + WEB * 0.5, (zn + z_a) * 0.5), Vector3(web_w, WEB, length - 0.3), steel.lightened(0.05), 0.0,
		MeshKit.PAT_IL_STEEL, MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PY | MeshKit.FACE_PZ, 0.0)
	var z: float = zn - 1.0
	while z > z_a + 0.5:
		s.box(Vector3(xm, 0.18 + WEB * 0.5, z), Vector3(w * 0.7, WEB * 0.9, 0.1), steel.lightened(0.02), 0.0, MeshKit.PAT_IL_STEEL,
			MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PZ | MeshKit.FACE_PY, 0.0)
		z -= 1.5
	var top_y: float = 0.18 + WEB + 0.07
	s.box(Vector3(xm, top_y, (zn + z_a) * 0.5), Vector3(w * 0.9, 0.14, length - 0.2), steel.lightened(0.02), 0.0, MeshKit.PAT_IL_STEEL,
		MeshKit.ALL_FACES & ~MeshKit.FACE_NY, 0.0)
	# Snow lying on the top flange, a rail along its middle.
	_parts.snow_cap(s, z_a + 0.2, zn - 0.2, top_y + 0.07, xm - w * 0.4, xm + w * 0.4, k, 0.1)
	s.box(Vector3(xm, top_y + 0.14, (zn + z_a) * 0.5), Vector3(0.1, 0.1, length - 0.4), steel.lightened(0.2), 0.0, MeshKit.PAT_IL_STEEL,
		MeshKit.ALL_FACES & ~MeshKit.FACE_NY, 2.0)
	# The hoist trolley on the rail with its cable drum, and the end truck at the near end.
	var tz: float = lerpf(zn - 2.0, z_a + 2.0, 0.25 + 0.5 * MeshKit.hash01(k, 1, 3))
	s.box(Vector3(xm, top_y + 0.39, tz), Vector3(minf(w * 0.8, 1.4), 0.4, 1.2), skin.frame_color, 0.0, MeshKit.PAT_IL_STEEL,
		MeshKit.ALL_FACES & ~MeshKit.FACE_NY, 0.0)
	var drum := Transform3D(Basis.from_euler(Vector3(0.0, 0.0, PI * 0.5)).scaled_local(Vector3(0.16, minf(w * 0.7, 1.2), 0.16)),
		Vector3(xm + minf(w * 0.7, 1.2) * 0.5, top_y + 0.45, tz))
	s.prism_xform(drum, 8, steel.lightened(0.12), 0.0, MeshKit.PAT_IL_STEEL, true, 2.0)
	s.box(Vector3(xm, 0.45, zn - 0.15), Vector3(w, 0.9, 0.3), skin.frame_color, 0.0, MeshKit.PAT_IL_STEEL, MeshKit.FACE_PX | MeshKit.FACE_NX
		| MeshKit.FACE_PY | MeshKit.FACE_PZ, 0.0)
	for i: int in 4:
		var bx: float = lerpf(xa + 0.2, xb - 0.2, (float(i) + 0.5) / 4.0)
		s.box(Vector3(bx, 0.45, zn + 0.02), Vector3(0.1, 0.1, 0.06), skin.frame_color.lightened(0.15), 0.0, MeshKit.PAT_IL_STEEL,
			MeshKit.FACE_PZ, 2.0)


# --- An overhead grated walkway -------------------------------------------------------------------

func _walkway(s: MeshLayer, g: MeshLayer, xa: float, xb: float, zn: float, zf: float, variant: int) -> void:
	var k: int = variant * 157 + MeshKit.key(zn - zf)
	var steel: Color = skin.steel_color
	var w: float = xb - xa
	var xm: float = (xa + xb) * 0.5
	var z_a: float = zf + END_BAND
	var length: float = zn - z_a
	# The deck's top (grating, seen from above where a runner on the wall looks down on it), a toe plate and a handrail on posts with two
	# rails along each side, snow on the top rail.
	s.rect(Vector3(xa, 0.2, zn), Vector3(w, 0, 0), Vector3(0, 0, -length), steel.lightened(0.06), 0.0, MeshKit.PAT_IL_STEEL,
		Vector2.ZERO, Vector2.ONE, 4.0)
	for x: float in [xa + 0.05, xb - 0.05]:
		s.box(Vector3(x, 0.12, (zn + z_a) * 0.5), Vector3(0.1, 0.24, length), skin.frame_color, 0.0, MeshKit.PAT_IL_STEEL,
			MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PY | MeshKit.FACE_PZ, 0.0)
		var pz: float = zn - 0.4
		while pz > z_a + 0.3:
			s.box(Vector3(x, 0.24 + RAIL * 0.5, pz), Vector3(0.06, RAIL, 0.06), skin.frame_color.darkened(0.1), 0.0, MeshKit.PAT_IL_STEEL,
				MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PZ | MeshKit.FACE_NZ, 2.0)
			pz -= 1.5
		for ry: float in [0.24 + RAIL, 0.24 + RAIL * 0.5]:
			s.box(Vector3(x, ry, (zn + z_a) * 0.5), Vector3(0.05, 0.05, length - 0.5), skin.frame_color.darkened(0.15), 0.0,
				MeshKit.PAT_IL_STEEL, MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PY | MeshKit.FACE_PZ, 0.0)
		_parts.snow_cap(s, z_a + 0.4, zn - 0.4, 0.24 + RAIL + 0.025, x - 0.04, x + 0.04, k + int(x * 10.0), 0.05)
	# Cross-bearers under the deck's edge (seen from the sides), lab equipment standing on the deck: cabinets and a cable tray.
	s.box(Vector3(xm, 0.1, zn - 0.05), Vector3(w, 0.2, 0.1), steel.darkened(0.1), 0.0, MeshKit.PAT_IL_STEEL, MeshKit.FACE_PZ, 0.0)
	var z: float = zn - 1.0
	while z > z_a + 0.5:
		s.box(Vector3(xm, 0.1, z), Vector3(w, 0.2, 0.12), steel.darkened(0.1), 0.0, MeshKit.PAT_IL_STEEL,
			MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PZ | MeshKit.FACE_PY, 0.0)
		z -= 2.0
	var cz: float = zn - 1.6
	var i: int = 0
	while cz > z_a + 1.2:
		if MeshKit.hash01(k, i, 4) < 0.5 and w > 1.6:
			var cx: float = xm + (MeshKit.hash01(k, i, 5) - 0.5) * (w - 1.3)
			s.box(Vector3(cx, 0.2 + 0.45, cz), Vector3(0.7, 0.9, 0.8), skin.enamel_color, 0.0, MeshKit.PAT_IL_PANEL,
				float(MeshKit.IL_PANEL_CABINET + 4 * ((k + i) % 100)), MeshKit.ALL_FACES & ~MeshKit.FACE_NY)
			_parts.snow_cap(s, cz - 0.4, cz + 0.4, 1.1, cx - 0.35, cx + 0.35, k + i, 0.05)
		cz -= 2.4
		i += 1
	s.box(Vector3(xm, 0.28, (zn + z_a) * 0.5), Vector3(0.3, 0.08, length - 1.0), Color(0.06, 0.08, 0.1), 0.0, MeshKit.PAT_IL_STEEL,
		MeshKit.ALL_FACES & ~MeshKit.FACE_NY, 2.0)
	# A small amber lamp on a post near one end (from the deck up: never under the underside, never at floor level).
	var lz: float = lerpf(zn - 1.0, z_a + 1.0, 0.3 + 0.4 * MeshKit.hash01(k, 7, 6))
	var lx: float = xa + 0.4 if MeshKit.hash01(k, 8, 7) < 0.5 else xb - 0.4
	s.box(Vector3(lx, 0.2 + 0.7, lz), Vector3(0.05, 1.4, 0.05), skin.frame_color, 0.0, MeshKit.PAT_IL_STEEL, MeshKit.ALL_FACES, 2.0)
	s.box(Vector3(lx, 0.2 + 1.45, lz), Vector3(0.3, 0.18, 0.3), skin.lamp_color, skin.lamp_tube_glow(), MeshKit.PAT_IL_LAMP,
		MeshKit.ALL_FACES, float(k % 1000))


## Rods hanging the ceiling from the hall's crane runways: a pair every 6 m, thin, up to ROD_TOP over the underside (the one thing here that
## rises past TOP_LIMIT), the first of the near end one cut short and bent where a rod has given way, as the Terminal's walkways are.
func _rods(s: MeshLayer, xa: float, xb: float, zn: float, zf: float, variant: int, kind: int) -> void:
	var k: int = variant * 91 + kind * 7 + MeshKit.key(zn - zf)
	var rz: float = zn - 0.9
	var j: int = 0
	while rz > zf + END_BAND + 0.5:
		for x: float in [xa + 0.3, xb - 0.3]:
			var length: float = ROD_TOP
			var lean: float = 0.05 * (MeshKit.hash01(k, j, int(x * 10.0) + 9) - 0.5)
			var rod := Basis.from_euler(Vector3(0.0, 0.0, lean)).scaled_local(Vector3(0.05, length, 0.05))
			s.box_xform(Transform3D(rod, Vector3(x, 0.24 + length * 0.5, rz)), skin.post_color, 0.0, MeshKit.PAT_IL_STEEL,
				MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PZ | MeshKit.FACE_NZ, 2.0)
		rz -= 6.0
		j += 1

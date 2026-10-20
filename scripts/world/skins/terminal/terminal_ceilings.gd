class_name TerminalCeilings
extends RefCounted
## Ceiling sections in the Terminal (TerminalSkin; GDD §5, owner, October 20, 2026: few, every one a single lane wide, little
## shortcuts over part of the maze: "the underside of a fallen girder, a hanging walkway or a stranded subway car's roof"). The
## kind is picked by hashing where the ceiling is (weights in the skin):
## - a GIRDER: a plate girder fallen across the street and lodged: the underside is its bottom flange, a web up its middle with
##   stiffeners, a top flange, the near end torn open with the flange bent up and bolts sheared, rust and flaking verdigris;
## - a WALKWAY: a maintenance walkway hanging from the vault on rods (the underside plating under its deck, a handrail along
##   each side, broken at the near end where a rod has given way), rods running up to the vault;
## - a CAR: a stranded subway car wedged over the street: its belly is the underside, its sides in flaking paint with a
##   band of windows (PAT_TERMINAL_CAR), its roof rounded off with vines draped over it, the near end a blank cab front with a
##   dark window.
## Every kind is built from the ceiling it's given: its width and position come from the collision box and the lane seams
## (center, size, lane_edges_x), so a ceiling over more lanes (narrow ceilings are the Terminal's, but the track builder may
## give any range) just builds wider. Every underside is one flat surface of old steel across its lanes (no gaps between lanes,
## GDD §3) with a darker strip and a pale line along each lane seam, so a runner hanging from it reads the lanes; nothing
## hangs below it, and its far end carries the orange band of every zone (MeshKit.ceiling_end), so the drop back to the floor
## reads like a gap edge. Past the far end nothing reaches below the underside and nothing glows but that band.
## Nothing rises more than TOP_LIMIT above the underside, so the work lamps in the vault (kept above 8 m) never cut through
## one; the walkway's rods are the one exception, thin and in the open, since they hang from the vault.
## DESIGN-TBD (docs/questions/o4.md item 8): the three kinds, their weights and how a car is a ceiling.
## Ceiling space: origin at the centre of the underside (the ceiling surface), z = -distance.

enum Kind { GIRDER, WALKWAY, CAR }

const END_BAND: float = 1.2
## Nothing but a walkway's rods rises higher than this above the underside.
const TOP_LIMIT: float = 1.9
## The girder's web height, the walkway's rail height, and the car's body height above the underside.
const WEB: float = 0.85
const RAIL: float = 1.05
const BODY: float = 1.4

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: TerminalSkin:
	get:
		return _skin.get_ref() as TerminalSkin
var _skin: WeakRef
var _meshes: Dictionary = {}


func _init(p_skin: TerminalSkin) -> void:
	_skin = weakref(p_skin)


## Dresses the ceiling with collision box center/size and seams lane_edges_x (world x). wall_x is the wall faces' distance
## from the track's centre.
func build(parent: Node3D, center: Vector3, size: Vector3, lane_edges_x: Array[float], wall_x: float) -> void:
	var variant: int = MeshKit.hash_i(MeshKit.key(center.z), MeshKit.key(size.z), 91) % 4
	var kind: int = kind_of(center, size)
	var id: String = "%d_%d_%s_%s_%s_%s_%s" % [kind, variant, size, lane_edges_x, center.x, wall_x, center.y]
	var mesh: ArrayMesh = _meshes.get(id)
	if mesh == null:
		if _meshes.size() > 256:
			_meshes.clear()
		mesh = mesh_for(kind, variant, size, lane_edges_x, center.x, wall_x, center.y - size.y * 0.5)
		_meshes[id] = mesh
	MeshBatch.add_instance(parent, mesh, "", Vector3(center.x, center.y - size.y * 0.5, center.z))


## Which kind of ceiling this is: by hash and weight (a car needs a lane: always a one-lane-sized piece at least).
func kind_of(center: Vector3, size: Vector3) -> int:
	var total: float = skin.girder_weight + skin.walkway_weight + skin.car_weight
	if total <= 0.0:
		return Kind.GIRDER
	var r: float = MeshKit.hash01(MeshKit.key(center.z), MeshKit.key(size.z), 90) * total
	if r < skin.girder_weight:
		return Kind.GIRDER
	if r < skin.girder_weight + skin.walkway_weight:
		return Kind.WALKWAY
	return Kind.CAR


## The mesh of a ceiling of `kind` (variant 0-3) with collision size `size` centred on offset_x, seams at lane_edges_x (world x),
## its underside at world height surface_y. In ceiling space (see above); build() places it.
func mesh_for(kind: int, variant: int, size: Vector3, lane_edges_x: Array[float], offset_x: float, wall_x: float,
		surface_y: float) -> ArrayMesh:
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
	_underside(s, g, xa, xb, zn, zf, edges)
	match kind:
		Kind.GIRDER:
			_girder(s, xa, xb, zn, zf, variant, surface_y)
		Kind.WALKWAY:
			_walkway(s, xa, xb, zn, zf, variant, surface_y)
		_:
			_car(s, xa, xb, zn, zf, variant, surface_y)
	return batch.to_mesh()


## The underside across [xa, xb] from the far end's band to the near end: one surface of old steel (beams every 3 m streaming
## past overhead), a darker strip with a pale line along each lane seam, and the orange band at the far end.
func _underside(s: MeshLayer, g: MeshLayer, xa: float, xb: float, zn: float, zf: float, edges: Array[float]) -> void:
	var z0: float = zf + END_BAND
	s.rect(Vector3(xa, 0, z0), Vector3(xb - xa, 0, 0), Vector3(0, 0, zn - z0), skin.steel_color.darkened(0.15), 0.0,
		MeshKit.PAT_TERMINAL_STEEL, Vector2.ZERO, Vector2.ONE, 1.0)
	for x: float in edges:
		s.box(Vector3(x, -0.006, (zn + z0) * 0.5), Vector3(0.12, 0.012, zn - z0), skin.post_color, 0.0, MeshKit.PAT_TERMINAL_STEEL,
			MeshKit.ALL_FACES & ~MeshKit.FACE_PY, 0.0)
		s.box(Vector3(x, -0.0135, (zn + z0) * 0.5), Vector3(0.035, 0.003, zn - z0), Color(0.55, 0.5, 0.44), 0.0, MeshKit.PAT_PLAIN,
			MeshKit.FACE_NY)
	MeshKit.ceiling_end(s, g, (xb - xa) * 0.5, zf, END_BAND, skin.gap_edge_color, (xa + xb) * 0.5)


# --- A fallen girder ---------------------------------------------------------------------------

func _girder(s: MeshLayer, xa: float, xb: float, zn: float, zf: float, variant: int, surface_y: float) -> void:
	var k: int = variant * 131 + MeshKit.key(zn - zf)
	var steel: Color = skin.steel_color
	var rust: Color = skin.rust_color
	var xm: float = (xa + xb) * 0.5
	var w: float = xb - xa
	var z_a: float = zf + END_BAND
	# The bottom flange's edge faces (the underside's thickness) and the web up the middle, with stiffeners.
	s.box(Vector3(xm, 0.09, (zn + z_a) * 0.5), Vector3(w, 0.18, zn - z_a), steel, 0.0, MeshKit.PAT_TERMINAL_STEEL,
		MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PY, 0.0)
	var web_w: float = minf(0.22, w * 0.2)
	s.box(Vector3(xm, 0.18 + WEB * 0.5, (zn + z_a) * 0.5), Vector3(web_w, WEB, zn - z_a - 0.3), steel.lightened(0.03), 0.0,
		MeshKit.PAT_TERMINAL_STEEL, MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PY | MeshKit.FACE_PZ, 0.0)
	var z: float = zn - 1.2
	while z > z_a + 0.6:
		s.box(Vector3(xm, 0.18 + WEB * 0.5, z), Vector3(w * 0.7, WEB, 0.1), rust.darkened(0.1), 0.0, MeshKit.PAT_TERMINAL_STEEL,
			MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PZ | MeshKit.FACE_PY, 2.0)
		z -= 1.7
	# The top flange, narrower than the bottom one, bent up at the torn near end.
	var top_y: float = 0.18 + WEB + 0.07
	s.box(Vector3(xm, top_y, (zn - 1.6 + z_a) * 0.5), Vector3(w * 0.85, 0.14, zn - 1.6 - z_a), steel, 0.0, MeshKit.PAT_TERMINAL_STEEL,
		MeshKit.ALL_FACES & ~MeshKit.FACE_NY, 0.0)
	var bend := Basis.from_euler(Vector3(-(0.3 + 0.25 * MeshKit.hash01(k, 1, 3)), 0.0, 0.0))
	s.box_xform(Transform3D(bend.scaled_local(Vector3(w * 0.85, 0.14, 1.1)), Vector3(xm, top_y + 0.2, zn - 0.8)), rust, 0.0,
		MeshKit.PAT_TERMINAL_STEEL, MeshKit.ALL_FACES, 2.0)
	# Sheared bolts and a torn plate at the near end, rust blooming from it.
	for i: int in 4:
		var bx: float = lerpf(xa + 0.2, xb - 0.2, (float(i) + 0.5) / 4.0)
		s.box(Vector3(bx, 0.2, zn - 0.05), Vector3(0.1, 0.1, 0.18), rust, 0.0, MeshKit.PAT_TERMINAL_STEEL, MeshKit.ALL_FACES, 2.0)
	# A tangle of vine caught on its top flange.
	s.box(Vector3(xm + (MeshKit.hash01(k, 2, 4) - 0.5) * w * 0.4, top_y + 0.26, (zn + z_a) * 0.5 - 1.0), Vector3(w * 0.6, 0.3, 2.2),
		skin.vine_color, 0.0, MeshKit.PAT_TERMINAL_VINE, MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PY | MeshKit.FACE_PZ)


# --- A hanging maintenance walkway --------------------------------------------------------------------

func _walkway(s: MeshLayer, xa: float, xb: float, zn: float, zf: float, variant: int, surface_y: float) -> void:
	var k: int = variant * 157 + MeshKit.key(zn - zf)
	var steel: Color = skin.steel_color
	var w: float = xb - xa
	var xm: float = (xa + xb) * 0.5
	var z_a: float = zf + END_BAND
	# The deck's edge, a toe-plate along each side, and a handrail on posts (some missing) with two rails.
	for x: float in [xa + 0.05, xb - 0.05]:
		s.box(Vector3(x, 0.12, (zn + z_a) * 0.5), Vector3(0.1, 0.24, zn - z_a), steel.lightened(0.04), 0.0, MeshKit.PAT_TERMINAL_STEEL,
			MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PY | MeshKit.FACE_PZ, 0.0)
		var pz: float = zn - 0.4
		var i: int = 0
		while pz > z_a + 0.3:
			if MeshKit.hash01(k, i, int(x * 10.0) + 7) < 0.8:
				s.box(Vector3(x, 0.24 + RAIL * 0.5, pz), Vector3(0.06, RAIL, 0.06), steel.darkened(0.1), 0.0, MeshKit.PAT_TERMINAL_STEEL,
					MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PZ | MeshKit.FACE_NZ, 0.0)
			pz -= 1.5
			i += 1
		for ry: float in [0.24 + RAIL, 0.24 + RAIL * 0.5]:
			s.box(Vector3(x, ry, (zn + z_a) * 0.5), Vector3(0.05, 0.05, zn - z_a - 0.5), steel.darkened(0.2), 0.0, MeshKit.PAT_TERMINAL_STEEL,
				MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PY | MeshKit.FACE_PZ, 0.0)
	# Cross-bearers along the deck (above the underside: seen from the sides).
	var z: float = zn - 1.0
	while z > z_a + 0.5:
		s.box(Vector3(xm, 0.1, z), Vector3(w, 0.2, 0.12), steel.darkened(0.1), 0.0, MeshKit.PAT_TERMINAL_STEEL,
			MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PZ | MeshKit.FACE_PY, 0.0)
		z -= 2.0
	# Rods up toward the vault: a pair every 6 m, thin, one bent where a rod has given way at the near end.
	var rz: float = zn - 0.8
	var j: int = 0
	var rod_top: float = 6.2
	while rz > z_a + 0.5:
		for x: float in [xa + 0.3, xb - 0.3]:
			# One rod at the near end has given way: a stub of it hangs, bent.
			var broken: bool = j == 0 and x < xm
			var length: float = 1.4 if broken else rod_top
			var lean: float = 0.12 * (MeshKit.hash01(k, j, int(x * 10.0) + 9) - 0.5) + (0.25 if broken else 0.0)
			var rod := Basis.from_euler(Vector3(0.0, 0.0, lean)).scaled_local(Vector3(0.05, length, 0.05))
			s.box_xform(Transform3D(rod, Vector3(x, 0.24 + length * 0.5, rz)), skin.post_color, 0.0, MeshKit.PAT_TERMINAL_STEEL,
				MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PZ | MeshKit.FACE_NZ, 2.0)
		rz -= 6.0
		j += 1


# --- A stranded subway car ----------------------------------------------------------------------------

func _car(s: MeshLayer, xa: float, xb: float, zn: float, zf: float, variant: int, surface_y: float) -> void:
	var k: int = variant * 173 + MeshKit.key(zn - zf)
	var color: Color = skin.car_colors[k % skin.car_colors.size()]
	var seed: float = float(k % 100)
	var w: float = xb - xa
	var xm: float = (xa + xb) * 0.5
	var z_a: float = zf + END_BAND
	var length: float = zn - z_a
	# The sides in flaking paint with a band of windows (UV in metres along the car and up from where its floor would be a
	# metre below the underside, so the windows sit in the body), the near end a blank cab front with a dark window.
	s.rect(Vector3(xa, 0, zn), Vector3(0, 0, -length), Vector3(0, BODY, 0), color, 0.0, MeshKit.PAT_TERMINAL_CAR,
		Vector2(0, 1.0), Vector2(length, 1.0 + BODY), seed)
	s.rect(Vector3(xb, 0, z_a), Vector3(0, 0, length), Vector3(0, BODY, 0), color, 0.0, MeshKit.PAT_TERMINAL_CAR,
		Vector2(0, 1.0), Vector2(length, 1.0 + BODY), seed + 1.0)
	s.box(Vector3(xm, BODY * 0.5, zn + 0.01), Vector3(w, BODY, 0.04), color.darkened(0.15), 0.0, MeshKit.PAT_TERMINAL_STEEL,
		MeshKit.FACE_PZ, 0.0)
	s.box(Vector3(xm, BODY * 0.62, zn + 0.035), Vector3(w * 0.8, 0.7, 0.02), Color(0.02, 0.025, 0.025), 0.0, MeshKit.PAT_PLAIN,
		MeshKit.FACE_PZ)
	# The roof, rounded off with a narrower box, vents on it, vine over it.
	s.box(Vector3(xm, BODY + 0.05, (zn + z_a) * 0.5), Vector3(w, 0.1, length), color.darkened(0.2), 0.0, MeshKit.PAT_TERMINAL_STEEL,
		MeshKit.FACE_PY | MeshKit.FACE_PZ, 0.0)
	s.box(Vector3(xm, BODY + 0.16, (zn + z_a) * 0.5), Vector3(w * 0.65, 0.16, length * 0.97), color.darkened(0.3), 0.0,
		MeshKit.PAT_TERMINAL_STEEL, MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PY | MeshKit.FACE_PZ, 0.0)
	for i: int in 2:
		var vz: float = lerpf(zn - 2.0, z_a + 2.0, (float(i) + 0.3 + 0.4 * MeshKit.hash01(k, i, 5)) / 2.0)
		s.box(Vector3(xm, BODY + 0.33, vz), Vector3(w * 0.45, 0.18, 0.9), color.darkened(0.45), 0.0, MeshKit.PAT_TERMINAL_STEEL,
			MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PY | MeshKit.FACE_PZ, 0.0)
	s.box(Vector3(xm + (MeshKit.hash01(k, 7, 6) - 0.5) * w * 0.3, BODY + 0.3, (zn + z_a) * 0.5), Vector3(w * 0.55, 0.16, length * 0.4),
		skin.vine_color, 0.0, MeshKit.PAT_TERMINAL_VINE, MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PY | MeshKit.FACE_PZ)

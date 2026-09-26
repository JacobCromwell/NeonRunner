class_name GanglandBarge
extends RefCounted
## Ceiling sections in Gangland (GanglandSkin): the underside of a patched-together scavenger cargo
## barge hovering low over the street. The hull spans every ceiling lane as one surface of salvaged
## plates (PAT_RUST) in slightly different tones per lane, with dark welded seams and caged work
## lamps between the lanes. Its blunt bow rises above the near end behind a heavy bumper beam
## (nothing sharp: the hull is safe to run on), scrap cargo sits on deck, and its stern carries the
## orange edge (the surface ends here, like a gap edge) under a row of sooty engines, so the drop back
## to the floor is readable.
## DESIGN-TBD: the GDD leaves Gangland's ceiling open; the scavenger barge is the proposed look.
## Barge space: origin at the centre of the underside (the ceiling surface), z = -distance.

const STERN_BAND: float = 1.2
const RISE: float = 2.4
const SLOPE: float = 0.7

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: GanglandSkin:
	get:
		return _skin.get_ref() as GanglandSkin
var _skin: WeakRef
var _meshes: Dictionary = {}


func _init(p_skin: GanglandSkin) -> void:
	_skin = weakref(p_skin)


func build(parent: Node3D, center: Vector3, size: Vector3, lane_edges_x: Array[float]) -> void:
	var id: String = "%s_%s_%s" % [size, lane_edges_x, center.x]
	var mesh: ArrayMesh = _meshes.get(id)
	if mesh == null:
		mesh = _barge_mesh(size, lane_edges_x, center.x)
		_meshes[id] = mesh
	MeshBatch.add_instance(parent, mesh, "", Vector3(center.x, center.y - size.y * 0.5, center.z))


func _barge_mesh(size: Vector3, lane_edges_x: Array[float], offset_x: float) -> ArrayMesh:
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(skin.solid_material())
	var g: MeshLayer = batch.layer(skin.glow_material())
	var hw: float = size.x * 0.5 + 0.15
	var zn: float = size.z * 0.5
	var zf: float = -size.z * 0.5
	var hull: Color = skin.hull_color
	var lamp: Color = skin.hull_lamp_color
	var seam := Color(hull.darkened(0.55), 1.0)

	# Underside: salvaged plates, one strip per ceiling lane in its own tone, welded seams between.
	var edges: Array[float] = [-hw]
	for x: float in lane_edges_x:
		edges.append(x - offset_x)
	edges.append(hw)
	for i: int in edges.size() - 1:
		var tone: float = 0.9 + 0.2 * MeshKit.hash01(i, 5, 17)
		s.rect(Vector3(edges[i], 0, zf + STERN_BAND), Vector3(edges[i + 1] - edges[i], 0, 0),
			Vector3(0, 0, zn - zf - STERN_BAND), hull * Color(tone, tone, tone), 0.0, MeshKit.PAT_RUST)
		if i > 0:
			s.box(Vector3(edges[i], -0.012, (zn + zf + STERN_BAND) * 0.5), Vector3(0.07, 0.024, zn - zf - STERN_BAND),
				seam, 0.0, MeshKit.PAT_PLAIN, MeshKit.ALL_FACES & ~MeshKit.FACE_PY)
			var z: float = zf + 6.0
			while z < zn - 2.0:
				s.box(Vector3(edges[i], -0.035, z), Vector3(0.22, 0.07, 0.22), lamp, 0.7, MeshKit.PAT_PLAIN,
					MeshKit.ALL_FACES & ~MeshKit.FACE_PY)
				g.rect(Vector3(edges[i] - 0.7, -0.09, z + 0.7), Vector3(1.4, 0, 0), Vector3(0, 0, -1.4), lamp, 0.3,
					MeshKit.SHAPE_RADIAL)
				z += 9.0
	# The stern edge: the ceiling ends here (the orange edge language, as in every zone).
	MeshKit.ceiling_end(s, g, hw, zf, STERN_BAND, skin.gap_edge_color)

	# Sloped sides of patched plating with a row of dim portholes.
	for side: float in [-1.0, 1.0]:
		var x: float = side * hw
		var top := Vector3(-side * SLOPE, RISE, 0)
		var z0: float = zn if side > 0.0 else zf
		var u := Vector3(0, 0, zf - zn if side > 0.0 else zn - zf)
		s.rect(Vector3(x, 0, z0), u, top, hull.lightened(0.06), 0.0, MeshKit.PAT_RUST)
		var pz: float = zf + 2.5
		while pz < zn - 1.5:
			s.box(Vector3(x - side * SLOPE * 0.5, RISE * 0.5, pz), Vector3(0.28, 0.22, 0.28), lamp, 0.3)
			pz += 3.2

	# Blunt bow rising above the near end, with a heavy bumper beam.
	var bow_z: float = zn + 3.2
	var bl := Vector3(-hw, 0, zn)
	var br := Vector3(hw, 0, zn)
	var tl := Vector3(-hw + SLOPE, RISE, bow_z)
	var tr := Vector3(hw - SLOPE, RISE, bow_z)
	s.quad(bl, tl, tr, br, hull, 0.0, MeshKit.PAT_RUST)
	s.quad(br, tr, br + Vector3(-SLOPE, RISE, 0), br + Vector3(-SLOPE, RISE, 0), hull.lightened(0.06))
	s.quad(bl, bl + Vector3(SLOPE, RISE, 0), tl, tl, hull.lightened(0.06))
	s.box(Vector3(0, 0.14, zn + 0.18), Vector3(hw * 2.0 - 0.2, 0.28, 0.36), hull.darkened(0.35), 0.0, MeshKit.PAT_PLAIN,
		MeshKit.ALL_FACES & ~MeshKit.FACE_NY)
	# Headlamps on the bow, dim and dirty.
	for side: float in [-1.0, 1.0]:
		var lamp_at := Vector3(side * (hw - SLOPE - 0.6), RISE - 0.3, bow_z - 0.2)
		s.box(lamp_at, Vector3(0.4, 0.2, 0.2), lamp, 0.8)
		g.rect(lamp_at + Vector3(-1.0, -1.0, 0.15), Vector3(2.0, 0, 0), Vector3(0, 2.0, 0), lamp, 0.25, MeshKit.SHAPE_RADIAL)

	# Scrap cargo on deck, seen as a silhouette as the barge comes over.
	for i: int in 3:
		var cz: float = lerpf(zf + 3.0, zn - 3.0, (float(i) + 0.5) / 3.0)
		var ch: float = 1.2 + 1.2 * MeshKit.hash01(i, MeshKit.key(size.z), 3)
		var cw: float = hw * (0.5 + 0.35 * MeshKit.hash01(i, MeshKit.key(size.z), 4))
		s.box(Vector3((MeshKit.hash01(i, MeshKit.key(size.z), 5) - 0.5) * hw * 0.5, RISE + ch * 0.5, cz),
			Vector3(cw, ch, minf(5.0, (zn - zf) * 0.25)), skin.wreck_color, 0.0, MeshKit.PAT_RUST, MeshKit.NO_BOTTOM)

	# Stern: sooty engines above the orange edge, their dim glow dropping below the hull.
	s.rect(Vector3(-hw, 0, zf), Vector3(0, RISE, 0), Vector3(hw * 2.0, 0, 0), hull.darkened(0.35))
	var engines: int = clampi(roundi(hw * 2.0 / 4.0), 2, 4)
	for i: int in engines:
		var ex: float = -hw + (float(i) + 0.5) * hw * 2.0 / engines
		var r: float = minf(0.95, hw / engines * 0.8)
		var nozzle := Transform3D(Basis(Vector3(r, 0, 0), Vector3(0, 0, -1.3), Vector3(0, r, 0)), Vector3(ex, 1.1, zf))
		s.prism_xform(nozzle, 8, Color(0.08, 0.075, 0.07), 0.0, MeshKit.PAT_RUST, false)
		var core := Transform3D(Basis(Vector3(r * 0.7, 0, 0), Vector3(0, 0, -0.05), Vector3(0, r * 0.7, 0)),
			Vector3(ex, 1.1, zf - 1.2))
		s.prism_xform(core, 8, skin.engine_color, 0.18)
		g.rect(Vector3(ex - r * 2.4, 1.1 - r * 2.4, zf - 1.4), Vector3(r * 4.8, 0, 0), Vector3(0, r * 4.8, 0),
			skin.engine_color, 0.12, MeshKit.SHAPE_RADIAL)
		g.rect(Vector3(ex - r * 0.8, 1.1, zf - 1.4), Vector3(r * 1.6, 0, 0), Vector3(0, 0, -10.0), skin.engine_color, 0.14,
			MeshKit.SHAPE_BEAM)
	return batch.to_mesh()

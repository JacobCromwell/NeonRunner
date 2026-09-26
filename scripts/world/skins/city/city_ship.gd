class_name CityShip
extends RefCounted
## Ceiling sections in the city (CitySkin): the underside of a low-flying ship heading toward the
## player. The hull spans every ceiling lane as one plated surface with subtle lane seams; its bow
## rises above the near end, and its stern carries an orange edge (the surface ends here, like a
## gap edge) under a row of glowing engines, so the drop back to the floor is readable.
## Ship space: origin at the centre of the underside (the ceiling surface), z = -distance.

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: CitySkin:
	get:
		return _skin.get_ref() as CitySkin
var _skin: WeakRef
var _meshes: Dictionary = {}


func _init(p_skin: CitySkin) -> void:
	_skin = weakref(p_skin)


func build(parent: Node3D, center: Vector3, size: Vector3, lane_edges_x: Array[float]) -> void:
	var id: String = "%s_%s_%s" % [size, lane_edges_x, center.x]
	var mesh: ArrayMesh = _meshes.get(id)
	if mesh == null:
		mesh = _ship_mesh(size, lane_edges_x, center.x)
		_meshes[id] = mesh
	MeshBatch.add_instance(parent, mesh, "", Vector3(center.x, center.y - size.y * 0.5, center.z))


func _ship_mesh(size: Vector3, lane_edges_x: Array[float], offset_x: float) -> ArrayMesh:
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(skin.solid_material())
	var g: MeshLayer = batch.layer(skin.glow_material())
	var hw: float = size.x * 0.5 + 0.15
	var zn: float = size.z * 0.5
	var zf: float = -size.z * 0.5
	var hull: Color = skin.hull_color
	var light: Color = skin.hull_light_color
	var stern_lip: float = 1.2
	var rise: float = 2.6
	var slope: float = 0.9

	# Underside: one plate per ceiling lane, flush light seams between them.
	var edges: Array[float] = [-hw]
	for x: float in lane_edges_x:
		edges.append(x - offset_x)
	edges.append(hw)
	for i: int in edges.size() - 1:
		var x0: float = edges[i] + (0.04 if i > 0 else 0.0)
		var x1: float = edges[i + 1] - (0.04 if i < edges.size() - 2 else 0.0)
		s.rect(Vector3(x0, 0, zf + stern_lip), Vector3(x1 - x0, 0, 0), Vector3(0, 0, zn - zf - stern_lip), hull, 0.0,
			MeshKit.PAT_HULL)
		if i > 0:
			s.rect(Vector3(edges[i] - 0.04, 0, zf + stern_lip), Vector3(0.08, 0, 0), Vector3(0, 0, zn - zf - stern_lip),
				light, 0.12)
			var z: float = zf + 6.0
			while z < zn - 2.0:
				s.box(Vector3(edges[i], -0.02, z), Vector3(0.1, 0.04, 0.3), light, 0.8, MeshKit.PAT_PLAIN,
					MeshKit.ALL_FACES & ~MeshKit.FACE_PY)
				z += 9.0
		# Flush anti-grav emitters down each lane.
		var ez: float = zf + 9.0
		while ez < zn - 4.0:
			s.prism(Vector3((edges[i] + edges[i + 1]) * 0.5, -0.03, ez), 0.42, 0.03, 8, light, 0.3)
			ez += 15.0
	# The stern edge: a wide orange band with amber lights, the ceiling ends here (like a gap edge).
	s.rect(Vector3(-hw, 0, zf), Vector3(hw * 2.0, 0, 0), Vector3(0, 0, stern_lip), skin.gap_edge_color, 0.5)
	var lx: float = -hw + 0.6
	while lx < hw - 0.3:
		s.box(Vector3(lx, -0.025, zf + 0.25), Vector3(0.35, 0.05, 0.2), skin.gap_edge_color, 1.0, MeshKit.PAT_PLAIN,
			MeshKit.ALL_FACES & ~MeshKit.FACE_PY)
		lx += 1.2
	g.rect(Vector3(-hw, -0.05, zf + stern_lip + 1.5), Vector3(hw * 2.0, 0, 0), Vector3(0, 0, -(stern_lip + 3.0)),
		skin.gap_edge_color, 0.35, MeshKit.SHAPE_RADIAL)
	# Engine wash hanging below the stern, so the end reads from underneath.
	g.rect(Vector3(-hw, -2.4, zf - 0.3), Vector3(hw * 2.0, 0, 0), Vector3(0, 3.4, 0), skin.engine_color, 0.55,
		MeshKit.SHAPE_RADIAL)

	# Sloped sides with a band of lit windows and running lights along the underside edges.
	for side: float in [-1.0, 1.0]:
		var x: float = side * hw
		var top := Vector3(-side * slope, rise, 0)
		var z0: float = zn if side > 0.0 else zf
		var u := Vector3(0, 0, zf - zn if side > 0.0 else zn - zf)
		s.rect(Vector3(x, 0, z0), u, top, hull.lightened(0.08), 0.0, MeshKit.PAT_HULL)
		s.rect(Vector3(x, 0, z0) + top * 0.45 + Vector3(side * 0.01, 0, 0), u, top * 0.12, light, 0.3, MeshKit.PAT_HULL)
		s.box(Vector3(x - side * 0.05, -0.03, 0), Vector3(0.1, 0.06, size.z - 1.0), light, 0.35, MeshKit.PAT_PLAIN,
			MeshKit.FACE_NY | (MeshKit.FACE_PX if side > 0.0 else MeshKit.FACE_NX))

	# Bow: rises from the near end toward the player, narrowing to a nose with running lights.
	var tip_hw: float = hw * 0.55
	var tip_z: float = zn + 5.0
	var bl := Vector3(-hw, 0, zn)
	var br := Vector3(hw, 0, zn)
	var tl := Vector3(-tip_hw, rise, tip_z)
	var tr := Vector3(tip_hw, rise, tip_z)
	s.quad(bl, tl, tr, br, hull, 0.0, MeshKit.PAT_HULL)
	s.quad(br, tr, br + Vector3(-slope, rise, 0), br + Vector3(-slope, rise, 0), hull.lightened(0.08))
	s.quad(bl, bl + Vector3(slope, rise, 0), tl, tl, hull.lightened(0.08))
	s.box(Vector3(0, -0.03, zn - 0.1), Vector3(hw * 2.0 - 0.4, 0.06, 0.12), light, 0.5)
	for side: float in [-1.0, 1.0]:
		s.box(Vector3(side * tip_hw * 0.8, rise - 0.25, tip_z - 0.3), Vector3(0.5, 0.18, 0.2), skin.headlight_color, 1.0)
		g.rect(Vector3(side * tip_hw * 0.8 - 1.2, rise - 1.45, tip_z), Vector3(2.4, 0, 0), Vector3(0, 2.4, 0),
			skin.headlight_color, 0.35, MeshKit.SHAPE_RADIAL)

	# Stern: engines above the orange edge, their glow dropping below the hull so it reads from underneath.
	s.rect(Vector3(-hw, 0, zf), Vector3(0, rise, 0), Vector3(hw * 2.0, 0, 0), hull.darkened(0.3))
	var engines: int = clampi(roundi(hw * 2.0 / 4.0), 2, 5)
	for i: int in engines:
		var ex: float = -hw + (float(i) + 0.5) * hw * 2.0 / engines
		var r: float = minf(1.1, hw / engines * 0.9)
		var ez: float = zf
		var nozzle := Transform3D(Basis(Vector3(r, 0, 0), Vector3(0, 0, -1.4), Vector3(0, r, 0)), Vector3(ex, 1.1, ez))
		s.prism_xform(nozzle, 8, Color(0.1, 0.1, 0.13), 0.0, MeshKit.PAT_PLAIN, false)
		var core := Transform3D(Basis(Vector3(r * 0.75, 0, 0), Vector3(0, 0, -0.05), Vector3(0, r * 0.75, 0)),
			Vector3(ex, 1.1, ez - 1.3))
		s.prism_xform(core, 8, skin.engine_color, 1.0)
		g.rect(Vector3(ex - r * 2.6, 1.1 - r * 2.6, ez - 1.5), Vector3(r * 5.2, 0, 0), Vector3(0, r * 5.2, 0),
			skin.engine_color, 0.55, MeshKit.SHAPE_RADIAL)
		g.rect(Vector3(ex - r * 0.8, 1.1, ez - 1.5), Vector3(r * 1.6, 0, 0), Vector3(0, 0, -14.0), skin.engine_color, 0.22,
			MeshKit.SHAPE_BEAM)
	g.rect(Vector3(-hw, -0.06, zf + 3.0), Vector3(hw * 2.0, 0, 0), Vector3(0, 0, -6.0), skin.engine_color, 0.3,
		MeshKit.SHAPE_RADIAL)
	return batch.to_mesh()

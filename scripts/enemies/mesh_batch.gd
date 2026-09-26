extends RefCounted
## Merges simple primitives (boxes, wedges, cylinders, domes) into one ArrayMesh with one surface
## per material, so a procedural low-poly model costs one draw call per material instead of one per
## part (CLAUDE.md: keep draw calls low). Parts are given in the model's local space.
## Used by the drone and hover truck models; build once and cache the result.
##   var b := MeshBatch.new()
##   b.box(mat, Vector3(0, 1, 0), Vector3(2, 1, 4))
##   var mesh: ArrayMesh = b.commit()

static var _prims: Dictionary = {}

var _tools: Dictionary = {}
var _order: Array[Material] = []


## A box of `size` centred at `center`, rotated by `rotation` (Euler, radians).
func box(material: Material, center: Vector3, size: Vector3, rotation: Vector3 = Vector3.ZERO) -> void:
	_add(material, _prim(&"box"), center, size, rotation)


## A wedge: a triangular prism filling a `size` box, its ridge running along z at the top (+y).
## Rotated by x = -PI / 2 it becomes a flat arrowhead pointing forward (toward -z): then size.x is its
## width, size.y its length forward and size.z its height.
func wedge(material: Material, center: Vector3, size: Vector3, rotation: Vector3 = Vector3.ZERO) -> void:
	_add(material, _prim(&"wedge"), center, size, rotation)


## A cylinder along y, `size` = (diameter x, height, diameter z).
func cylinder(material: Material, center: Vector3, size: Vector3, rotation: Vector3 = Vector3.ZERO) -> void:
	_add(material, _prim(&"cylinder"), center, size, rotation)


## A dome (upper half sphere) standing on `center`, `size` = (diameter x, height, diameter z).
func dome(material: Material, center: Vector3, size: Vector3, rotation: Vector3 = Vector3.ZERO) -> void:
	_add(material, _prim(&"dome"), center, size, rotation)


## A four-sided spike pointing along +y from its base at `base`: `length` long, `width` wide.
func spike(material: Material, base: Vector3, length: float, width: float, rotation: Vector3 = Vector3.ZERO) -> void:
	var b := Basis.from_euler(rotation)
	_add_xform(material, _prim(&"spike"), Transform3D(b * Basis.from_scale(Vector3(width, length, width)),
		base + b * Vector3(0.0, length * 0.5, 0.0)))


func commit() -> ArrayMesh:
	var out := ArrayMesh.new()
	for m: Material in _order:
		(_tools[m] as SurfaceTool).commit(out)
		out.surface_set_material(out.get_surface_count() - 1, m)
	return out


func _add(material: Material, mesh: Mesh, center: Vector3, size: Vector3, rotation: Vector3) -> void:
	_add_xform(material, mesh, Transform3D(Basis.from_euler(rotation) * Basis.from_scale(size), center))


func _add_xform(material: Material, mesh: Mesh, xform: Transform3D) -> void:
	if not _tools.has(material):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[material] = st
		_order.append(material)
	(_tools[material] as SurfaceTool).append_from(mesh, 0, xform)


## Unit-sized primitives (1 × 1 × 1), shared by every batch.
static func _prim(kind: StringName) -> Mesh:
	if _prims.has(kind):
		return _prims[kind]
	var mesh: PrimitiveMesh
	match kind:
		&"box":
			var b := BoxMesh.new()
			b.size = Vector3.ONE
			mesh = b
		&"wedge":
			var p := PrismMesh.new()
			p.size = Vector3.ONE
			mesh = p
		&"cylinder":
			var c := CylinderMesh.new()
			c.top_radius = 0.5
			c.bottom_radius = 0.5
			c.height = 1.0
			c.radial_segments = 10
			c.rings = 1
			mesh = c
		&"dome":
			var s := SphereMesh.new()
			s.radius = 0.5
			s.height = 1.0
			s.is_hemisphere = true
			s.radial_segments = 12
			s.rings = 4
			mesh = s
		&"spike":
			var sp := CylinderMesh.new()
			sp.top_radius = 0.0
			sp.bottom_radius = 0.5
			sp.height = 1.0
			sp.radial_segments = 4
			sp.rings = 1
			mesh = sp
	_prims[kind] = mesh
	return mesh

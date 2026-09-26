class_name MeshBatch
extends RefCounted
## Geometry for one mesh, grouped into one MeshLayer per material. commit() turns it into a single
## MeshInstance3D with one surface (one draw call) per material, so a whole truck convoy or a
## stretch of facade costs a couple of draw calls however much detail it has.
##   var batch := MeshBatch.new()
##   batch.layer(solid_material).box(center, size, color)
##   batch.layer(glow_material).rect(...)
##   batch.commit(parent)

var _layers: Dictionary = {}


## The layer drawn with `material` (created on first use). A null material leaves the surface
## without one, for meshes whose material is set per instance.
func layer(material: Material) -> MeshLayer:
	var found: MeshLayer = _layers.get(material)
	if found == null:
		found = MeshLayer.new()
		_layers[material] = found
	return found


## Appends every layer of `other` (a cached multi-material template) placed by `xform`.
func append(other: MeshBatch, xform: Transform3D = Transform3D.IDENTITY) -> void:
	for material: Variant in other._layers:
		layer(material).append(other._layers[material], xform)


func is_empty() -> bool:
	for l: MeshLayer in _layers.values():
		if not l.is_empty():
			return false
	return true


func vertex_count() -> int:
	var total: int = 0
	for l: MeshLayer in _layers.values():
		total += l.size()
	return total


## Builds the ArrayMesh (null when there is nothing to draw).
func to_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for material: Variant in _layers:
		var l: MeshLayer = _layers[material]
		if l.is_empty():
			continue
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = l.verts
		arrays[Mesh.ARRAY_COLOR] = l.colors
		arrays[Mesh.ARRAY_TEX_UV] = l.uvs
		arrays[Mesh.ARRAY_TEX_UV2] = l.uv2s
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		if material != null:
			mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	return mesh if mesh.get_surface_count() > 0 else null


## Adds the batch to `parent` as one MeshInstance3D (no shadows). Returns null if it was empty.
func commit(parent: Node3D, node_name: String = "", at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh: ArrayMesh = to_mesh()
	if mesh == null:
		return null
	return MeshBatch.add_instance(parent, mesh, node_name, at)


## Adds a (usually cached, shared) mesh to `parent` as a shadowless MeshInstance3D.
static func add_instance(parent: Node3D, mesh: Mesh, node_name: String = "", at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = at
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if node_name != "":
		inst.name = node_name
	parent.add_child(inst)
	return inst

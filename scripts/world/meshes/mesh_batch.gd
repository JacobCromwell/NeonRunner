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


## The batch's main lit colours (sRGB, as the layers hold them), largest surface area first: at most
## `max_colors`, each covering at least `min_share` of the lit area, near-identical tones (the same to
## 1/32 in every channel) counted as one. Glowing faces (COLOR.a > 0) are left out. What a look's
## broken pieces fly off in (ZoneSkin.doodad_debris_colors, task H5): worked out once, from the
## vertices still on the CPU, never read back from a built mesh (a GPU read-back stalls the frame).
func palette(max_colors: int = 4, min_share: float = 0.04) -> PackedColorArray:
	var area_of: Dictionary = {}
	var color_of: Dictionary = {}
	var total: float = 0.0
	for l: MeshLayer in _layers.values():
		var n: int = l.verts.size() - l.verts.size() % 3
		for i: int in range(0, n, 3):
			var c: Color = l.colors[i]
			if c.a > 0.0:
				continue
			var a: float = (l.verts[i + 1] - l.verts[i]).cross(l.verts[i + 2] - l.verts[i]).length() * 0.5
			if a <= 0.0:
				continue
			var key := Vector3i(roundi(c.r * 32.0), roundi(c.g * 32.0), roundi(c.b * 32.0))
			if not area_of.has(key):
				area_of[key] = 0.0
				color_of[key] = Color(c.r, c.g, c.b)
			area_of[key] = float(area_of[key]) + a
			total += a
	var keys: Array = area_of.keys()
	keys.sort_custom(func(x: Vector3i, y: Vector3i) -> bool: return float(area_of[x]) > float(area_of[y]))
	var out := PackedColorArray()
	for key: Vector3i in keys:
		if out.size() >= max_colors or float(area_of[key]) < total * min_share:
			break
		out.append(color_of[key])
	return out


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

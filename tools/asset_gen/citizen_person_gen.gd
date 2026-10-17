extends SceneTree
## Bakes the Marketplace citizens' person (GDD §5, "Citizens"; task L7) from the shared HumanoidRig (CitizenRig): one
## low-poly mesh of a plain, ordinary person standing at ease, welded into one indexed surface and written to
## assets/models/market_person.res. MarketPeople draws every citizen of every shop window from it, as instances of one
## MultiMesh per wall section (market_person.gdshader dresses each one: skin, hair, clothes, and the sway, the head's
## turn and the cheer, all in the vertex shader). Nothing here runs at play time.
##
## What each vertex carries, so the shader can dress and move it from one shared mesh (the kit's meshes carry no
## normals either: the shader lights from screen-space derivatives):
##   UV2.x  the colour class: 0 trousers, 1 shirt, 2 skin, 3 hair, 4 shoes, 5 eyes (two small dark squares on the face,
##          so a head turning to watch the runner reads: the rig's head is a plain box)
##   UV2.y  what moves it: 0 the body, 1 the head (turns about the neck), 2 the left arm and 3 the right arm (the whole
##          arm, hand to shoulder, swings about the shoulder)
## and the mesh's meta holds the pivots the shader needs (neck, left and right shoulder), the person's height and
## its width, in the mesh's own metres (feet on y = 0, facing -z, +x the person's right: the rig's frame).
##
## Regenerate: tools/godot.sh citizens (headless; no rendering needed).

const OUT_PATH: String = "res://assets/models/market_person.res"
## The archetype whose colours tell the head's skin from its hair (any: the geometry is the same in every one).
const ARCHETYPE: int = 0
const SHOES: int = 4
const EYES: int = 5
## The eyes (metres at the rig's own scale): each side's distance from the middle, height above the head joint (the face's middle is the head's lift above it), size, and how
## far the face (the head's front, -z) is from the joint.
const EYE_SPREAD: float = 0.036
const EYE_HEIGHT: float = CitizenRig.HEAD_LIFT + 0.014
const EYE_SIZE := Vector3(0.026, 0.022, 0.008)
const FACE_Z: float = -0.075
## Vertices closer than this (metres), in one class and one moving part, are one.
const WELD: float = 0.00005

var _skin: Color
var _hair: Color


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var a: CitizenRig.Archetype = CitizenRig.ARCHETYPES[ARCHETYPE]
	_skin = a.skin_color.srgb_to_linear()
	_hair = a.hair_color.srgb_to_linear()
	var rig := HumanoidRig.new()
	root.add_child(rig)
	rig.build(CitizenRig.parts(ARCHETYPE), CitizenRig.material(), HumanoidAnimTuning.new())
	# Standing at ease: the idle's first pose (arms a little off the body, the forearms a little bent), on the ground.
	rig.apply_pose(CitizenRig.pose_at(CitizenRig.Clip.IDLE, 0.0))
	await process_frame
	var verts := PackedVector3Array()
	var uv2 := PackedVector2Array()
	for node: Node in rig.find_children("Part", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var joint: StringName = mi.get_parent().name
		var xf: Transform3D = rig.global_transform.affine_inverse() * mi.global_transform
		for s: int in mi.mesh.get_surface_count():
			var arrays: Array = mi.mesh.surface_get_arrays(s)
			var pv: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var pc: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			for i: int in pv.size():
				verts.append(xf * pv[i])
				uv2.append(_tag(joint, pc[i]))
	var head: Vector3 = rig.global_transform.affine_inverse() * rig.joint(&"head").global_position
	for side: int in [-1, 1]:
		_box(verts, uv2, head + Vector3(side * EYE_SPREAD, EYE_HEIGHT, FACE_Z + EYE_SIZE.z * 0.1), EYE_SIZE,
			Vector2(float(EYES), 1.0))
	var low: float = INF
	for v: Vector3 in verts:
		low = minf(low, v.y)
	for i: int in verts.size():
		verts[i].y -= low
	var out_verts := PackedVector3Array()
	var out_uv2 := PackedVector2Array()
	var out_index := PackedInt32Array()
	var seen: Dictionary = {}
	for i: int in verts.size():
		var cell := Vector3i((verts[i] / WELD).round())
		var key: String = "%d,%d,%d,%d,%d" % [cell.x, cell.y, cell.z, int(uv2[i].x), int(uv2[i].y)]
		if not seen.has(key):
			seen[key] = out_verts.size()
			out_verts.append(verts[i])
			out_uv2.append(uv2[i])
		out_index.append(seen[key])
	var arrays_out: Array = []
	arrays_out.resize(Mesh.ARRAY_MAX)
	arrays_out[Mesh.ARRAY_VERTEX] = out_verts
	arrays_out[Mesh.ARRAY_TEX_UV2] = out_uv2
	arrays_out[Mesh.ARRAY_INDEX] = out_index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays_out)
	mesh.resource_name = "market_person"
	var bounds: AABB = mesh.get_aabb()
	mesh.set_meta(&"pivots", {
		&"neck": _pivot(rig, &"head", low),
		&"shoulder_l": _pivot(rig, &"upper_arm_l", low),
		&"shoulder_r": _pivot(rig, &"upper_arm_r", low),
		&"height": bounds.end.y, &"width": bounds.size.x, &"depth": bounds.size.z})
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_PATH.get_base_dir()))
	var err: int = ResourceSaver.save(mesh, OUT_PATH, ResourceSaver.FLAG_COMPRESS)
	print("%s: %d vertices (from %d), %d triangles, %.2f m tall, %.2f m wide, neck %s, shoulders %s %s (error %d)" % [
		OUT_PATH, out_verts.size(), verts.size(), out_index.size() / 3, bounds.end.y, bounds.size.x,
		_pivot(rig, &"head", low), _pivot(rig, &"upper_arm_l", low), _pivot(rig, &"upper_arm_r", low), err])
	quit(0 if err == OK else 1)


## Appends a box of `size` centred on `center` (12 triangles, outward faces wound as Godot expects) tagged `tag`.
func _box(verts: PackedVector3Array, uv2: PackedVector2Array, center: Vector3, size: Vector3, tag: Vector2) -> void:
	var h: Vector3 = size * 0.5
	for axis: int in 3:
		for sign_: int in [-1, 1]:
			var n := Vector3.ZERO
			n[axis] = float(sign_)
			var u := Vector3.ZERO
			u[(axis + 1) % 3] = 1.0
			var v: Vector3 = n.cross(u)
			var c: Vector3 = center + n * h[axis]
			var du: Vector3 = u * h[(axis + 1) % 3]
			var dv: Vector3 = v * h[(axis + 2) % 3]
			# Corners counter-clockwise seen from outside (along -n): c - du - dv, c + du - dv, c + du + dv, c - du + dv.
			var quad: Array[Vector3] = [c - du - dv, c + du - dv, c + du + dv, c - du + dv]
			if (quad[1] - quad[0]).cross(quad[2] - quad[0]).dot(n) < 0.0:
				quad.reverse()
			for i: int in [0, 1, 2, 0, 2, 3]:
				verts.append(quad[i])
				uv2.append(tag)


## Where joint `joint_name` sits in the baked mesh's space.
func _pivot(rig: HumanoidRig, joint_name: StringName, low: float) -> Vector3:
	var p: Vector3 = rig.global_transform.affine_inverse() * rig.joint(joint_name).global_position
	return Vector3(p.x, p.y - low, p.z)


## UV2 for a vertex of joint `joint` whose rig colour is `color` (linear): its colour class and the part that moves it.
func _tag(joint: StringName, color: Color) -> Vector2:
	var name: String = String(joint)
	var moves: float = 0.0
	if name == "head":
		moves = 1.0
	elif name.ends_with("_arm_l") or name == "forearm_l" or name == "hand_l":
		moves = 2.0
	elif name.ends_with("_arm_r") or name == "forearm_r" or name == "hand_r":
		moves = 3.0
	var cls: float = 0.0
	if name == "chest" or name.begins_with("upper_arm"):
		cls = 1.0
	elif name == "neck" or name.begins_with("forearm") or name.begins_with("hand"):
		cls = 2.0
	elif name.begins_with("foot"):
		cls = float(SHOES)
	elif name == "head":
		var d_skin: float = Vector3(color.r - _skin.r, color.g - _skin.g, color.b - _skin.b).length()
		var d_hair: float = Vector3(color.r - _hair.r, color.g - _hair.g, color.b - _hair.b).length()
		cls = 2.0 if d_skin < d_hair else 3.0
	return Vector2(cls, moves)

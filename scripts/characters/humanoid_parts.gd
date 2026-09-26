class_name HumanoidParts
extends Resource
## What a HumanoidRig is made of: skeleton proportions, the low-poly pieces on each segment, and
## named attachment sets (equipment, zone variants) that can be switched on and off. The player
## (PlayerSuit) and later the enemy cyborgs share the rig and swap these parts (GDD §9.2: "one
## shared body and skeleton with swappable parts per zone").
##
## Units are metres at design scale; HumanoidRig scales the figure to whatever size it must fit.
## Rest pose: standing upright, arms hanging, facing -z, soles at y = 0, +x = the character's right.
## Segment meshes are built on first use and cached statically per `cache_key`, so any number of
## characters with the same look share them.

const SEGMENTS: Array[StringName] = [&"pelvis", &"chest", &"neck", &"head", &"upper_arm", &"forearm",
	&"hand", &"thigh", &"shin", &"foot"]

## Name for the static mesh cache. Give every distinct look its own key.
@export var cache_key: String = ""
## The box this character is modelled to fill in its run pose: width, height, depth.
@export var design_size: Vector3 = Vector3(0.6, 1.28, 0.52)

@export_group("Skeleton")
## Right hip joint relative to the pelvis joint (the left one is mirrored).
@export var hip_offset: Vector3 = Vector3(0.085, -0.035, 0.0)
@export var thigh_length: float = 0.3
@export var shin_length: float = 0.3
## Height of the ankle joint above the sole.
@export var ankle_height: float = 0.07
## Chest joint (bottom of the rib cage) relative to the pelvis joint.
@export var chest_offset: Vector3 = Vector3(0.0, 0.085, 0.0)
## Neck joint relative to the chest joint.
@export var neck_offset: Vector3 = Vector3(0.0, 0.29, 0.005)
## Head joint relative to the neck joint.
@export var head_offset: Vector3 = Vector3(0.0, 0.05, 0.0)
## Right shoulder joint relative to the chest joint (the left one is mirrored).
@export var shoulder_offset: Vector3 = Vector3(0.165, 0.245, 0.0)
@export var upper_arm_length: float = 0.2
@export var forearm_length: float = 0.18

@export_group("Pieces")
@export var pieces: Array[HumanoidPiece] = []
## Name → Array of HumanoidPiece. Merged into the segment meshes while switched on.
@export var attachments: Dictionary = {}

@export_group("Panels")
## Stiff flaps hinged at the waist (a coat's skirt), swung by HumanoidRig. Empty for most looks.
@export var panels: Array[HumanoidPanel] = []

static var _mesh_cache: Dictionary = {}
static var _support_cache: Dictionary = {}


## Height of the pelvis joint above the soles in the rest pose.
func pelvis_height() -> float:
	return -hip_offset.y + thigh_length + shin_length + ankle_height


## The merged mesh of one segment instance (`limb_side` -1 = left, 1 = right, 0 = centre segment)
## with the pieces of the `active` attachment sets. Null when nothing sits on it.
func segment_mesh(segment: StringName, limb_side: int, active: Array[StringName] = []) -> ArrayMesh:
	var names := PackedStringArray()
	for set_name: StringName in active:
		if _set_touches(attachments.get(set_name, []), segment):
			names.append(String(set_name))
	names.sort()
	var key: String = "%s|%s|%d|%s" % [_key(), segment, limb_side, ",".join(names)]
	if not _mesh_cache.has(key):
		var sets: Array = [pieces]
		for set_name: String in names:
			sets.append(attachments[StringName(set_name)])
		_mesh_cache[key] = _build_mesh(segment, limb_side, sets)
	return _mesh_cache[key]


## Every panel merged into one mesh in the pelvis joint's space (one surface, drawn with the body
## material; UV.y = panel index + 1). Its metadata: "points" (every vertex), "point_panels" (the
## panel of each point), "triangles" and "body_surface" (0). Null without panels.
func panel_mesh() -> ArrayMesh:
	if panels.is_empty():
		return null
	var key: String = "%s|panels" % _key()
	if not _mesh_cache.has(key):
		var builder := HumanoidMeshBuilder.new()
		var owners := PackedInt32Array()
		for i: int in panels.size():
			var panel: HumanoidPanel = panels[i]
			var before: int = builder.vertices.size()
			for piece: HumanoidPiece in panel.pieces:
				builder.add_piece(piece, panel.side < 0, i + 1)
			for v: int in builder.vertices.size() - before:
				owners.append(i)
		var mesh: ArrayMesh = null
		if not builder.is_empty():
			mesh = ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, builder.arrays())
			mesh.set_meta(&"body_surface", 0)
			mesh.set_meta(&"triangles", builder.triangle_count())
			mesh.set_meta(&"points", builder.vertices)
			mesh.set_meta(&"point_panels", owners)
		_mesh_cache[key] = mesh
	return _mesh_cache[key]


## A few extreme points of the bare segment (no attachments), for keeping the posed body on the
## ground cheaply: the lowest vertex of any pose is always close to one of these.
func support_points(segment: StringName, limb_side: int) -> PackedVector3Array:
	var key: String = "%s|%s|%d" % [_key(), segment, limb_side]
	if not _support_cache.has(key):
		var mesh: ArrayMesh = segment_mesh(segment, limb_side)
		var points := PackedVector3Array()
		if mesh != null:
			var all: PackedVector3Array = mesh.get_meta(&"points")
			for dir: Vector3 in _support_directions():
				var best: Vector3 = all[0]
				for p: Vector3 in all:
					if p.dot(dir) > best.dot(dir):
						best = p
				if not points.has(best):
					points.append(best)
		_support_cache[key] = points
	return _support_cache[key]


## Drops every cached mesh (after editing pieces at runtime, e.g. in a tool).
static func clear_cache() -> void:
	_mesh_cache.clear()
	_support_cache.clear()


func _key() -> String:
	return cache_key if cache_key != "" else "parts%d" % get_instance_id()


func _set_touches(set_pieces: Array, segment: StringName) -> bool:
	for piece: HumanoidPiece in set_pieces:
		if piece.segment == segment:
			return true
	return false


func _build_mesh(segment: StringName, limb_side: int, sets: Array) -> ArrayMesh:
	var body := HumanoidMeshBuilder.new()
	var custom: Dictionary = {}
	for set_pieces: Array in sets:
		for piece: HumanoidPiece in set_pieces:
			if piece.segment != segment:
				continue
			for mirrored: bool in piece.placements(limb_side):
				var builder: HumanoidMeshBuilder = body
				if piece.material != null:
					if not custom.has(piece.material):
						custom[piece.material] = HumanoidMeshBuilder.new()
					builder = custom[piece.material]
				builder.add_piece(piece, mirrored)
	if body.is_empty() and custom.is_empty():
		return null
	var mesh := ArrayMesh.new()
	var triangles: int = 0
	var points := PackedVector3Array()
	var body_surface: int = -1
	if not body.is_empty():
		body_surface = 0
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, body.arrays())
		triangles += body.triangle_count()
		points.append_array(body.vertices)
	for material: Material in custom:
		var builder: HumanoidMeshBuilder = custom[material]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, builder.arrays())
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
		triangles += builder.triangle_count()
		points.append_array(builder.vertices)
	mesh.set_meta(&"body_surface", body_surface)
	mesh.set_meta(&"triangles", triangles)
	mesh.set_meta(&"points", points)
	return mesh


static func _support_directions() -> Array[Vector3]:
	var dirs: Array[Vector3] = [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]
	for x: float in [-1.0, 1.0]:
		for y: float in [-1.0, 1.0]:
			for z: float in [-1.0, 1.0]:
				dirs.append(Vector3(x, y, z).normalized())
	return dirs

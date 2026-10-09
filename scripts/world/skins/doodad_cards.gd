class_name DoodadCards
extends RefCounted
## A zone's doodads as picture cards (owner's request October 9, 2026: keep each doodad a simple box,
## but draw on it a picture of the object it stands for, with the open air cut out). The pictures are
## painted by code (tools/asset_gen/doodad_art_gen.gd, `tools/godot.sh doodads`) into one atlas per
## zone, assets/sprites/doodads/<zone>.png, with a manifest (<zone>.json) of where each picture sits
## and which cards make each size class's looks: the box's faces, or cards inside it (a palm's crossed
## fronds, the fabrics down a stall's middle). See DoodadArtSet for the card format.
##
## A look is one mesh of quads inside the doodad's box (so it stays inside its collision box: what
## looks like contact is contact), built once per look and size and shared by every instance, on one
## material per zone (doodad_card.gdshader: the kit's fake city light, the open air discarded, never
## emissive). A zone's look for a doodad is picked from its seed (the same wherever it's built).

const DIR: String = "res://assets/sprites/doodads"
const SHADER_PATH: String = "res://scripts/world/meshes/shaders/doodad_card.gdshader"
## The zones with cards (tools/asset_gen/doodad_art_gen.gd paints one atlas for each).
const ZONES: Array[String] = ["city", "gangland", "marketplace", "corporate", "dead_zone", "golden"]

static var _sets: Dictionary = {}

var zone: String
## Loaded and usable (a zone without a manifest falls back to ZoneSkin's default look).
var ok: bool = false
var material: ShaderMaterial
## Looks by size class name: Array of {name, colors, cards}.
var designs: Dictionary = {}
var _uv: Dictionary = {}
var _meshes: Dictionary = {}


## The cards of `zone` (city, gangland, marketplace, corporate, dead_zone, golden), loaded once and
## kept while that zone is in use. Loading another zone lets go of the one before: an atlas is the
## biggest texture a level holds (about 2.8 MB VRAM-compressed), and a session needs one zone's at a
## time. Doodads already built keep their own mesh and material. The atlases stay VRAM-compressed, so
## loading one costs a file read: stored lossless, its decoding cost a 40 ms frame where a run without
## the shader warm-up (headless) met its first doodad (test_frame_times).
static func for_zone(p_zone: String) -> DoodadCards:
	if not _sets.has(p_zone):
		_sets.clear()
		_sets[p_zone] = DoodadCards.new(p_zone)
	return _sets[p_zone]


func _init(p_zone: String) -> void:
	zone = p_zone
	var path: String = DIR.path_join(zone + ".json")
	if not FileAccess.file_exists(path):
		push_warning("No doodad cards for %s (%s): run tools/godot.sh doodads" % [zone, path])
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Bad doodad manifest %s" % path)
		return
	var m: Dictionary = parsed
	var texture := load(String(m["atlas"])) as Texture2D
	if texture == null:
		push_error("No doodad atlas %s" % m["atlas"])
		return
	var size: Array = m["atlas_size"]
	var w: float = float(size[0])
	var h: float = float(size[1])
	var images: Dictionary = m["images"]
	for name: String in images:
		var r: Array = images[name]
		_uv[name] = Rect2(float(r[0]) / w, float(r[1]) / h, float(r[2]) / w, float(r[3]) / h)
	designs = m["designs"]
	material = ShaderMaterial.new()
	material.shader = load(SHADER_PATH) as Shader
	material.set_shader_parameter(&"atlas", texture)
	ok = true


## True if `m` is a zone's card material (the doodad_card shader: lit scenery, never emissive).
static func is_card_material(m: Material) -> bool:
	var sm := m as ShaderMaterial
	return sm != null and sm.shader != null and sm.shader.resource_path == SHADER_PATH


## The look for a doodad of `size_class` with `look_seed`, or {} when the zone has none for it.
func design(size_class: StringName, look_seed: int) -> Dictionary:
	var list: Array = designs.get(String(size_class), [])
	if list.is_empty():
		return {}
	return list[posmod(MeshKit.hash_i(look_seed, 0, 17), list.size())]


## Dresses `body` (a doodad's node, centred on its box of `size`) with its look. Without cards for it,
## the default look (ZoneSkin.default_doodad_mesh in `fallback_palette`, pushing to `side`).
## DESIGN-TBD (docs/questions/g6b.md): a card look is the same whichever side the doodad pushes to.
func build(body: Node3D, size: Vector3, size_class: StringName, side: int, look_seed: int,
		fallback_palette: PackedColorArray) -> void:
	var inst := MeshInstance3D.new()
	var d: Dictionary = design(size_class, look_seed) if ok else {}
	if d.is_empty():
		inst.mesh = ZoneSkin.default_doodad_mesh(size, side, fallback_palette)
		inst.material_override = MeshKit.solid()
	else:
		inst.mesh = mesh_for(d, size)
		inst.material_override = material
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(inst)


## The mesh of look `d` for a box of `size`: one quad per card, cached.
func mesh_for(d: Dictionary, size: Vector3) -> ArrayMesh:
	var key: String = "%s %s" % [d["name"], size]
	if _meshes.has(key):
		return _meshes[key]
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for c: Dictionary in d["cards"]:
		_add_card(c, size, verts, normals, uvs, indices)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_meshes[key] = mesh
	return mesh


## Adds card `c` ({plane, at, rect, image, flip}; DoodadArtSet) of a box of `size` as one quad.
func _add_card(c: Dictionary, size: Vector3, verts: PackedVector3Array, normals: PackedVector3Array,
		uvs: PackedVector2Array, indices: PackedInt32Array) -> void:
	var image: String = String(c["image"])
	if not _uv.has(image):
		push_error("Doodad card for %s shows a missing picture %s" % [zone, image])
		return
	var r: Rect2 = _uv[image]
	var rect: Array = c["rect"]
	var u0: float = float(rect[0])
	var v0: float = float(rect[1])
	var u1: float = float(rect[2])
	var v1: float = float(rect[3])
	var at: float = float(c["at"])
	var flip: bool = bool(c.get("flip", false))
	# The picture's left and right edges in the atlas (mirrored with flip), its bottom and top.
	var left: float = r.end.x if flip else r.position.x
	var right: float = r.position.x if flip else r.end.x
	var bottom: float = r.end.y
	var top: float = r.position.y
	var corners: Array[Vector3] = []
	var normal := Vector3.ZERO
	match String(c["plane"]):
		"z":
			var z: float = (at - 0.5) * size.z
			normal = Vector3(0, 0, 1 if at >= 0.5 else -1)
			for q: Vector2 in [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)]:
				corners.append(Vector3((q.x - 0.5) * size.x, (q.y - 0.5) * size.y, z))
		"x":
			var x: float = (at - 0.5) * size.x
			normal = Vector3(1 if at >= 0.5 else -1, 0, 0)
			for q: Vector2 in [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)]:
				corners.append(Vector3(x, (q.y - 0.5) * size.y, (0.5 - q.x) * size.z))
		_:
			var y: float = (at - 0.5) * size.y
			normal = Vector3(0, 1 if at >= 0.5 else -1, 0)
			for q: Vector2 in [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)]:
				corners.append(Vector3((q.x - 0.5) * size.x, y, (0.5 - q.y) * size.z))
	var base: int = verts.size()
	var tex: Array[Vector2] = [Vector2(left, bottom), Vector2(right, bottom), Vector2(right, top), Vector2(left, top)]
	for i: int in 4:
		verts.append(corners[i])
		normals.append(normal)
		uvs.append(tex[i])
	indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))

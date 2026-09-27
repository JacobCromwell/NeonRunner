class_name GreyboxMaterials
extends RefCounted
## Shared placeholder materials and meshes (player, debug overlays, grey-box skin).
## Cached so a whole level shares a handful of resources.

const PLAYER := Color(0.92, 0.94, 1.0)
const PLAYER_DEAD := Color(1.0, 0.1, 0.1)
const VISOR := Color(0.1, 0.9, 1.0)
const SHADOW := Color(0.0, 0.0, 0.0, 0.55)
const DEBUG_HITBOX := Color(1.0, 0.0, 0.0, 0.35)
const SCENERY_SHADER: Shader = preload("res://scripts/world/greybox_scenery.gdshader")

static var _cache: Dictionary = {}


static func flat(color: Color) -> StandardMaterial3D:
	var key: String = "flat_%s" % color.to_html()
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.8
		_cache[key] = m
	return _cache[key]


## The grey-box skin's plain scenery (floor, walls, ceilings): lit like flat(), and dimmed by a
## level's darker lighting (ZoneSkin.apply_darkness, the global `scenery_light`). Enemies, the
## player and hazards keep flat() and glow(), so they stay as they are.
static func scenery(color: Color) -> ShaderMaterial:
	var key: String = "scenery_%s" % color.to_html()
	if not _cache.has(key):
		var m := ShaderMaterial.new()
		m.shader = SCENERY_SHADER
		m.set_shader_parameter(&"albedo", color)
		_cache[key] = m
	return _cache[key]


static func glow(color: Color, energy: float = 2.0, alpha: float = 1.0) -> StandardMaterial3D:
	var key: String = "glow_%s_%s_%s" % [color.to_html(), energy, alpha]
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(color, alpha)
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = energy
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if alpha < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_cache[key] = m
	return _cache[key]


## Unshaded, see-through colour, drawn on top when `on_top` (debug overlays).
static func overlay(color: Color, on_top: bool) -> StandardMaterial3D:
	var key: String = "overlay_%s_%s" % [color.to_html(), on_top]
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.no_depth_test = on_top
		_cache[key] = m
	return _cache[key]


static func debug_hitbox() -> StandardMaterial3D:
	return overlay(DEBUG_HITBOX, true)


## A 1×1×1 box shared by every grey-box mesh; instances are sized with `scale`.
static func unit_box() -> BoxMesh:
	if not _cache.has("unit_box"):
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		_cache["unit_box"] = mesh
	return _cache["unit_box"]


## Adds a box-shaped mesh of `size` centred at `center` (in `parent`'s space).
static func add_box(parent: Node3D, center: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = unit_box()
	inst.material_override = material
	inst.position = center
	inst.scale = size
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(inst)
	return inst

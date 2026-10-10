class_name MechaGuppyWaterfall
extends Node3D
## The waterfall backdrop of Mecha Guppy and Captain Cogs' climb (GDD §10: "a waterfall in phases 1 and 2, while the
## runner climbs; the Beach's normal backdrop in phase 3"; task E5e-b1). A giant cascade far down the track, falling
## between dark cliffs, under Sunset Strip's sky: one wide card that keeps DISTANCE metres ahead of the camera, its
## middle DROP below the camera's height, so it never comes closer and copes with any height the climb reaches (the
## fight has no time limit: GDD §10). Its water is drawn from world height (mecha_guppy_waterfall.gdshader), so as the runner climbs the
## falls stream past at the climb's pace as well as their own, like a cascade that is really there; the card itself
## only follows the camera. It is unshaded and ignores the fog, blending into the run's fog colour by itself (the
## haze of distance), so it reads the same on every renderer. Nothing flickers: the water's streaks scroll
## smoothly, and Reduced flashing has nothing to calm. set_shown() fades it out for phase 3 (the Beach's own sky
## then) and back.

const SHADER_PATH: String = "res://scripts/bosses/mecha_guppy/mecha_guppy_waterfall.gdshader"
## How far ahead of the camera the cascade hangs, how wide and tall the card is (metres).
const DISTANCE: float = 230.0
const WIDTH: float = 760.0
const HEIGHT: float = 520.0
## The card's middle sits this far below the camera (it reaches higher than any view looks).
const DROP: float = 40.0

var world: RunWorld
## 1 shown, 0 gone (set_shown fades it).
var shown: float = 1.0
var _target: float = 1.0
var _speed: float = 0.0
var _mesh: MeshInstance3D
var _material: ShaderMaterial


func setup(p_world: RunWorld) -> void:
	world = p_world
	top_level = true
	_material = ShaderMaterial.new()
	_material.shader = load(SHADER_PATH) as Shader
	var fog := Color(0.86, 0.68, 0.7)
	var env: Environment = _environment()
	if env != null:
		fog = env.fog_light_color
	_material.set_shader_parameter(&"haze_color", Vector3(fog.r, fog.g, fog.b))
	var quad := QuadMesh.new()
	quad.size = Vector2(WIDTH, HEIGHT)
	_mesh = MeshInstance3D.new()
	_mesh.name = "Cascade"
	_mesh.mesh = quad
	_mesh.material_override = _material
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.extra_cull_margin = HEIGHT
	add_child(_mesh)
	_apply()


## Fades the waterfall in (`on`) or out over `seconds` (0: at once).
func set_shown(on: bool, seconds: float = 1.5) -> void:
	_target = 1.0 if on else 0.0
	if seconds <= 0.0:
		shown = _target
		_apply()
	else:
		_speed = 1.0 / seconds


func _process(delta: float) -> void:
	if shown != _target:
		shown = move_toward(shown, _target, _speed * delta)
		_apply()
	var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	var at: Vector3 = camera.global_position if camera != null else (world.player.position if world != null and world.player != null else Vector3.ZERO)
	global_position = Vector3(0.0, at.y - DROP, at.z - DISTANCE)


func _apply() -> void:
	if _mesh == null:
		return
	_mesh.visible = shown > 0.001
	_material.set_shader_parameter(&"fade", shown)


func _environment() -> Environment:
	if not is_inside_tree():
		return null
	var w: World3D = get_world_3d()
	return w.environment if w != null else null

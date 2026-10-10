class_name MechaGuppyWaterfall
extends Node3D
## The backdrop of Mecha Guppy and Captain Cogs' climb (GDD §10: "a waterfall in phases 1 and 2, while the runner
## climbs; the Beach's normal backdrop in phase 3"; task E5e-b1). DESIGN-TBD (docs/questions/e5e.md): its look.
## - The waterfall: a flat-topped massif far down the track with a great cascade in its middle, falling from its lip
##   LIP_Y metres up into the sea, mist billowing where it lands, its outer flanks sloping down to the sea so the
##   horizon stays in view beside it. It keeps DISTANCE ahead of the camera along the track, but its heights are the
##   world's (mecha_guppy_waterfall.gdshader draws its rock, lip and mist at world heights), so the climb reads as
##   climbing: the cliffs slide down past the runner, the falls' foot sinks below, and a runner who climbs past the lip
##   looks down on the top (the plateau: the river running to the lip). The climb has no time limit (GDD §10): at
##   any height it holds together, and above the lip it simply drops away below with the sea.
## - The sea far below: a plane at sea level around the camera (mecha_guppy_sea.gdshader) under everything else, out to
##   the camera's far plane, fading into the run's fog; the sky below the horizon takes the fog's colour (abyss_color,
##   once the run's environment is up), so however high the runner is, the far sea meets the horizon seamlessly.
## - Low cloud far below: layers of soft cloud at fixed world heights (CLOUD_BASE, then every CLOUD_STEP metres up),
##   beside the climb but never over it; a layer shows only once the runner is above it, and sinks away below as they
##   climb on (mecha_guppy_clouds.gdshader): a world-anchored sign of height at any height.
## set_shown() fades the waterfall (not the sea or the clouds) out for phase 3, where the Beach's own sky remains.
## Unshaded, so it reads the same on every renderer; nothing flickers (the water's streaks scroll smoothly: Reduced
## flashing has nothing to calm).

const SHADER_PATH: String = "res://scripts/bosses/mecha_guppy/mecha_guppy_waterfall.gdshader"
const SEA_SHADER_PATH: String = "res://scripts/bosses/mecha_guppy/mecha_guppy_sea.gdshader"
const CLOUD_SHADER_PATH: String = "res://scripts/bosses/mecha_guppy/mecha_guppy_clouds.gdshader"
## How far ahead of the camera the massif stands (metres), its half width, the main fall's half width, the lip's and
## the sea's world height, and how far back its top runs (within the camera's 600 m far plane).
const DISTANCE: float = 420.0
const HALF_WIDTH: float = 280.0
const FALL_HALF_WIDTH: float = 95.0
const LIP_Y: float = 150.0
const SEA_Y: float = -2.0
const PLATEAU: float = 160.0
## The sea plane's size around the camera, and the sky's colour below the horizon becoming the fog's this far down
## (abyss_depth: the sine of the angle; small, so the far sea, fogged, meets it at once).
const SEA_SIZE: float = 1300.0
const ABYSS_DEPTH: float = 0.025
## The cloud layers: the lowest at this world height, the next every CLOUD_STEP up; at most CLOUD_LAYERS shown, each
## fading in as the camera rises from CLOUD_SHOW to CLOUD_SHOW + CLOUD_FADE above it, and out once CLOUD_GONE below.
const CLOUD_BASE: float = 12.0
const CLOUD_STEP: float = 36.0
const CLOUD_LAYERS: int = 3
const CLOUD_SHOW: float = 5.0
const CLOUD_FADE: float = 12.0
const CLOUD_GONE: float = 170.0
const CLOUD_SIZE: float = 900.0

var world: RunWorld
## 1 shown, 0 gone (set_shown fades it).
var shown: float = 1.0
var _target: float = 1.0
var _speed: float = 0.0
var _cascade: MeshInstance3D
var _top: MeshInstance3D
var _sea: MeshInstance3D
var _material: ShaderMaterial
var _top_material: ShaderMaterial
var _clouds: Array[MeshInstance3D] = []
var _env_applied: bool = false


func setup(p_world: RunWorld) -> void:
	world = p_world
	top_level = true
	_material = _make_material(false)
	_top_material = _make_material(true)
	var height: float = LIP_Y + 12.0 - SEA_Y
	var card := QuadMesh.new()
	card.size = Vector2(HALF_WIDTH * 2.0, height)
	_cascade = MeshInstance3D.new()
	_cascade.name = "Cascade"
	_cascade.mesh = card
	_cascade.material_override = _material
	_cascade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_cascade)
	var top := PlaneMesh.new()
	top.size = Vector2(HALF_WIDTH * 2.0, PLATEAU)
	_top = MeshInstance3D.new()
	_top.name = "Top"
	_top.mesh = top
	_top.material_override = _top_material
	_top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_top)
	var sea_material := ShaderMaterial.new()
	sea_material.shader = load(SEA_SHADER_PATH) as Shader
	var beach := world.skin as BeachSkin if world != null else null
	if beach != null:
		sea_material.set_shader_parameter(&"sea_color", beach.sea_deep_color)
	var plane := PlaneMesh.new()
	plane.size = Vector2(SEA_SIZE, SEA_SIZE)
	_sea = MeshInstance3D.new()
	_sea.name = "Sea"
	_sea.mesh = plane
	_sea.material_override = sea_material
	_sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sea)
	var half_clear: float = world.geo.wall_x() + 22.0 if world != null and world.geo != null else 30.0
	for i: int in CLOUD_LAYERS:
		var m := ShaderMaterial.new()
		m.shader = load(CLOUD_SHADER_PATH) as Shader
		m.set_shader_parameter(&"clear_half_width", half_clear)
		var layer := PlaneMesh.new()
		layer.size = Vector2(CLOUD_SIZE, CLOUD_SIZE)
		var cloud := MeshInstance3D.new()
		cloud.name = "Clouds%d" % i
		cloud.mesh = layer
		cloud.material_override = m
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cloud.visible = false
		add_child(cloud)
		_clouds.append(cloud)
	_apply()
	_follow()


func _make_material(plateau: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(SHADER_PATH) as Shader
	m.set_shader_parameter(&"lip_y", LIP_Y)
	m.set_shader_parameter(&"sea_y", SEA_Y)
	m.set_shader_parameter(&"half_width", HALF_WIDTH)
	m.set_shader_parameter(&"fall_half_width", FALL_HALF_WIDTH)
	m.set_shader_parameter(&"plateau", 1.0 if plateau else 0.0)
	m.set_shader_parameter(&"plateau_depth", PLATEAU)
	return m


## Fades the waterfall in (`on`) or out over `seconds` (0: at once). The sea stays.
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
	if not _env_applied:
		_apply_environment()
	_follow()


## Keeps the massif DISTANCE ahead of the camera along the track (at its world heights) and the sea under the camera.
func _follow() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	var at: Vector3 = camera.global_position if camera != null else (world.player.position if world != null and world.player != null else Vector3.ZERO)
	var z: float = at.z - DISTANCE
	_cascade.global_position = Vector3(0.0, (SEA_Y + LIP_Y + 12.0) * 0.5, z)
	_top.global_position = Vector3(0.0, LIP_Y + 1.0, z - PLATEAU * 0.5)
	_top_material.set_shader_parameter(&"lip_z", z)
	_sea.global_position = Vector3(at.x, SEA_Y, at.z)
	# The cloud layers below the camera, highest first.
	var top: int = floori((at.y - CLOUD_SHOW - CLOUD_BASE) / CLOUD_STEP)
	for i: int in _clouds.size():
		var n: int = top - i
		var cloud: MeshInstance3D = _clouds[i]
		var y: float = CLOUD_BASE + CLOUD_STEP * float(n)
		var above: float = at.y - y
		var opacity: float = clampf((above - CLOUD_SHOW) / CLOUD_FADE, 0.0, 1.0) * (1.0 - smoothstep(CLOUD_GONE - 50.0, CLOUD_GONE, above))
		cloud.visible = n >= 0 and opacity > 0.001
		if cloud.visible:
			cloud.global_position = Vector3(at.x, y, at.z)
			var m := cloud.material_override as ShaderMaterial
			m.set_shader_parameter(&"opacity", opacity)
			m.set_shader_parameter(&"seed", float(n))


func _apply() -> void:
	if _cascade == null:
		return
	_cascade.visible = shown > 0.001
	_top.visible = shown > 0.001
	_material.set_shader_parameter(&"fade", shown)
	_top_material.set_shader_parameter(&"fade", shown)


## Once the run's environment is up: the haze toward its fog colour, and the sky below the horizon in that colour
## (the far sea, fogged, meets it seamlessly at any height).
func _apply_environment() -> void:
	var env: Environment = _environment()
	if env == null:
		return
	_env_applied = true
	var fog: Color = env.fog_light_color * env.fog_light_energy
	var haze := Vector3(fog.r, fog.g, fog.b)
	_material.set_shader_parameter(&"haze_color", haze)
	_top_material.set_shader_parameter(&"haze_color", haze)
	var sky: ShaderMaterial = env.sky.sky_material as ShaderMaterial if env.sky != null else null
	if sky != null:
		sky.set_shader_parameter(&"abyss_color", haze)
		sky.set_shader_parameter(&"abyss_depth", ABYSS_DEPTH)


func _environment() -> Environment:
	if not is_inside_tree():
		return null
	var w: World3D = get_world_3d()
	return w.environment if w != null else null

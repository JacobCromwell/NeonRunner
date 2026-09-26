class_name CitySkin
extends ZoneSkin
## Zone 1, the Neon City (GDD §5, §11). Floor segments are the roofs of hover-truck convoys driving
## toward the player, gaps are the spaces between them with a road far below, walls are tower
## facades, signs are neon billboards in a yellow/black hazard frame, electric fences are pink
## energy fields between the trucks' exhaust stacks, and ceilings are the undersides of low ships.
## Visuals only: TrackBuilder owns every collision shape and gameplay node, and all variety comes
## from hashing track positions (MeshKit.hash_i), so a chunk looks the same whenever it is built.
## Geometry is merged per piece (one node, one draw call per material) from cached templates.

@export_group("Environment")
@export var sky_zenith_color: Color = Color(0.015, 0.012, 0.05)
@export var sky_horizon_color: Color = Color(0.2, 0.1, 0.36)
## The glow of the city lights in the air near the horizon.
@export var haze_color: Color = Color(0.38, 0.22, 0.62)
@export var abyss_color: Color = Color(0.03, 0.02, 0.07)
@export var skyline_color: Color = Color(0.06, 0.05, 0.12)
@export var skyline_window_color: Color = Color(0.95, 0.78, 0.55)
@export var ambient_color: Color = Color(0.5, 0.45, 0.7)
## Distant geometry fades into this colour between fog_begin and fog_end.
@export var fog_color: Color = Color(0.14, 0.08, 0.26)
@export_range(0.0, 150.0, 1.0, "suffix:m") var fog_begin: float = 20.0
@export_range(50.0, 400.0, 5.0, "suffix:m") var fog_end: float = 190.0
@export_range(0.0, 1.0, 0.01) var fog_max: float = 1.0
## Extra fog below the track, so the street far below sits in glowing haze.
@export_range(0.0, 0.5, 0.005) var abyss_fog_density: float = 0.035
@export_range(0.0, 2.0, 0.05) var glow_intensity: float = 0.8
@export_range(0.5, 4.0, 0.05) var glow_threshold: float = 1.1
## Brightness of emissive kit parts (vertex glow 1.0 = this many times the albedo).
@export_range(1.0, 20.0, 0.5) var emissive_scale: float = 4.0
## Sky glow caught at grazing angles by roofs, hulls and glass.
@export var sheen_color: Color = Color(0.4, 0.28, 0.7)
@export_range(0.0, 1.0, 0.01) var sheen_strength: float = 0.18

@export_group("Trucks")
@export_range(1.0, 5.0, 0.1, "suffix:m") var truck_height: float = 2.6
## Space left on each side of a truck inside its lane (side-by-side trucks show a dark slit).
@export_range(0.0, 0.5, 0.01, "suffix:m") var truck_inset: float = 0.12
## Trailer couplings sit on a fixed grid of track distances (per lane), so they line up across chunks.
@export_range(4.0, 30.0, 0.5, "suffix:m") var trailer_length: float = 12.5
@export var roof_color: Color = Color(0.15, 0.155, 0.19)
## Trailer (container) paints, picked by hashing each trailer's grid cell.
@export var container_colors: PackedColorArray = PackedColorArray([
	Color(0.36, 0.1, 0.13), Color(0.13, 0.21, 0.36), Color(0.22, 0.23, 0.27),
	Color(0.44, 0.45, 0.49), Color(0.27, 0.14, 0.32), Color(0.1, 0.24, 0.27)])
@export var cab_colors: PackedColorArray = PackedColorArray([
	Color(0.78, 0.79, 0.83), Color(0.55, 0.07, 0.1), Color(0.1, 0.18, 0.5),
	Color(0.1, 0.1, 0.12), Color(0.33, 0.13, 0.46)])
@export var headlight_color: Color = Color(0.85, 0.92, 1.0)
@export var truck_light_color: Color = Color(0.55, 0.7, 1.0)
@export var thruster_color: Color = Color(0.42, 0.36, 1.0)
## Gap edges: cab and rear roof lips and marker lights (the orange edge language). Redder than it
## looks: the glow and the tonemapper lift the green, and it must stay orange, not sign yellow.
@export var gap_edge_color: Color = Color(1.0, 0.25, 0.04)

@export_group("Road below")
@export_range(4.0, 60.0, 0.5, "suffix:m") var road_depth: float = 14.0
## How fast the road streams toward the player: the trucks' speed over the ground.
@export_range(0.0, 60.0, 0.5, "suffix:m/s") var road_scroll_speed: float = 14.0
@export var road_color: Color = Color(0.04, 0.04, 0.06)
@export var road_marking_color: Color = Color(0.45, 0.45, 0.55)
@export var traffic_head_color: Color = Color(0.85, 0.9, 1.0)
## The other traffic stream. Not red: red plus glow drifts toward the fence pink.
@export var traffic_tail_color: Color = Color(0.5, 0.45, 1.0)

@export_group("Buildings")
@export_range(10.0, 200.0, 1.0, "suffix:m") var building_min_height: float = 24.0
@export_range(20.0, 300.0, 1.0, "suffix:m") var building_max_height: float = 150.0
## Buildings are 1–3 lots long; a lot is this long.
@export_range(6.0, 40.0, 1.0, "suffix:m") var lot_length: float = 16.0
@export var facade_colors: PackedColorArray = PackedColorArray([
	Color(0.08, 0.085, 0.12), Color(0.1, 0.085, 0.13), Color(0.065, 0.075, 0.1), Color(0.11, 0.1, 0.14)])
@export var window_warm_color: Color = Color(1.0, 0.9, 0.76)
@export var window_cool_color: Color = Color(0.7, 0.84, 1.0)
@export var window_neon_color: Color = Color(0.62, 0.45, 1.0)
@export_range(0.2, 3.0, 0.05) var window_glow: float = 1.05
## Building trims and decorative signs. Kept away from the hazard colours (pink, yellow, orange,
## cyan, green) so hazards stay the most readable things on screen.
@export var neon_colors: PackedColorArray = PackedColorArray([
	Color(0.55, 0.35, 1.0), Color(0.22, 0.34, 1.0), Color(0.8, 0.85, 1.0), Color(0.45, 0.3, 0.95)])
## Faint lines on the facades at these heights, to read how high a wall run is.
@export var wall_height_marks: PackedFloat32Array = PackedFloat32Array([2.0, 4.0])
@export var wall_mark_color: Color = Color(0.45, 0.35, 1.0)
@export var beacon_color: Color = Color(1.0, 0.12, 0.12)

@export_group("Hazards")
## Pink crackle always means electric fence (GDD §5).
@export var fence_color: Color = Color(1.0, 0.18, 0.62)
@export var fence_stack_color: Color = Color(0.5, 0.52, 0.58)
## Signs: a yellow/black hazard frame around colourful neon content.
@export var sign_frame_color: Color = Color(1.0, 0.8, 0.15)
## Kept clear of the other hazard hues (pink, orange, cyan, green).
@export var sign_content_colors: PackedColorArray = PackedColorArray([
	Color(0.9, 0.93, 1.0), Color(0.62, 0.45, 1.0), Color(0.35, 0.6, 1.0), Color(0.78, 0.6, 1.0)])

@export_group("Ceiling ships")
@export var hull_color: Color = Color(0.22, 0.21, 0.28)
@export var hull_light_color: Color = Color(0.6, 0.75, 1.0)
@export var engine_color: Color = Color(0.45, 0.6, 1.0)

@export_group("Pads, ramps, finish")
@export var pad_color: Color = Color(0.1, 1.0, 0.95)
## Height of the anti-grav pad's light column.
@export_range(1.0, 10.0, 0.1, "suffix:m") var pad_beam_height: float = 5.8
@export var ramp_color: Color = Color(0.3, 1.0, 0.35)
@export var finish_color: Color = Color(1.0, 1.0, 1.0)

var _materials: Dictionary = {}
var _trucks: CityTrucks
var _towers: CityTowers
var _ship: CityShip
var _props: CityProps


func make_environment() -> Environment:
	var sky_material := ShaderMaterial.new()
	sky_material.shader = MeshKit.shader("city_sky.gdshader")
	sky_material.set_shader_parameter("zenith_color", sky_zenith_color)
	sky_material.set_shader_parameter("horizon_color", sky_horizon_color)
	sky_material.set_shader_parameter("haze_color", haze_color)
	sky_material.set_shader_parameter("abyss_color", abyss_color)
	sky_material.set_shader_parameter("skyline_color", skyline_color)
	sky_material.set_shader_parameter("window_color", skyline_window_color)
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient_color
	env.ambient_light_energy = 0.8
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = glow_intensity
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = glow_threshold
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = fog_color
	env.fog_light_energy = 1.0
	env.fog_depth_begin = fog_begin
	env.fog_depth_end = fog_end
	env.fog_depth_curve = 1.3
	env.fog_density = fog_max
	env.fog_sky_affect = 0.0
	env.fog_height = -3.0
	env.fog_height_density = abyss_fog_density
	return env


func floor_segment(parent: Node3D, center: Vector3, size: Vector3, lane_x: float,
		edge_start: bool, edge_end: bool) -> void:
	# The collision box spans the lane (outer lanes reach the wall); the truck is centred on the lane.
	var half_lane: float = minf(center.x + size.x * 0.5 - lane_x, lane_x - (center.x - size.x * 0.5))
	var near_d: float = -(center.z + size.z * 0.5)
	var far_d: float = -(center.z - size.z * 0.5)
	var batch := MeshBatch.new()
	trucks().build(batch, lane_x, (half_lane - truck_inset) * 2.0, near_d, far_d, edge_start, edge_end)
	batch.commit(parent)


func wall_section(parent: Node3D, side: int, face_x: float, start: float, end: float) -> void:
	var batch := MeshBatch.new()
	towers().build(batch, side, face_x, start, end)
	batch.commit(parent)


func fence(hazard: Hazard, size: Vector3, ground_y: float, gapped: bool) -> void:
	props().fence(hazard, size, ground_y, gapped)


func wall_sign(hazard: Hazard, size: Vector3) -> void:
	props().wall_sign(hazard, size)


func hull(parent: Node3D, center: Vector3, size: Vector3, lane_edges_x: Array[float]) -> void:
	ship().build(parent, center, size, lane_edges_x)


func pad(trigger: Area3D, size: Vector3) -> void:
	props().pad(trigger, size)


func ramp(trigger: Area3D, size: Vector3, side: int) -> void:
	props().ramp(trigger, size, side)


func finish_line(parent: Node3D, width: float, distance: float) -> void:
	props().finish_line(parent, width, distance)


# --- Shared materials (built once per skin, shared by every mesh) ------------------------

func solid_material() -> ShaderMaterial:
	if not _materials.has(&"solid"):
		_materials[&"solid"] = MeshKit.solid(_solid_params())
	return _materials[&"solid"]


func glow_material() -> ShaderMaterial:
	if not _materials.has(&"glow"):
		_materials[&"glow"] = MeshKit.glow({"fade_begin": fog_begin, "fade_end": fog_end})
	return _materials[&"glow"]


func facade_material() -> ShaderMaterial:
	if not _materials.has(&"facade"):
		_materials[&"facade"] = MeshKit.material("facade.gdshader", {
			"window_warm": window_warm_color, "window_cool": window_cool_color, "window_neon": window_neon_color,
			"sheen_color": sheen_color, "sheen_strength": sheen_strength, "window_glow": window_glow,
			"street_y": -road_depth})
	return _materials[&"facade"]


func road_material() -> ShaderMaterial:
	if not _materials.has(&"road"):
		_materials[&"road"] = MeshKit.material("road.gdshader", {
			"scroll_speed": road_scroll_speed, "asphalt": road_color, "marking": road_marking_color,
			"head_color": traffic_head_color, "tail_color": traffic_tail_color})
	return _materials[&"road"]


## ON, WARNING and OFF materials for a fence's emissive parts (bars, nozzles). The ON material is
## its own instance (not the shared solid one), so these parts stay a separate surface to swap.
func fence_part_materials() -> Array[Material]:
	if not _materials.has(&"fence_parts"):
		var on: Dictionary = _solid_params()
		on["state_glow"] = 1.0
		_materials[&"fence_parts"] = MeshKit.state_materials("kit_solid.gdshader", on, {"flicker_hz": 12.0},
			{"state_glow": 0.12})
	return _materials[&"fence_parts"]


## ON, WARNING and OFF materials for a fence's energy field.
func fence_field_materials() -> Array[Material]:
	if not _materials.has(&"fence_field"):
		var on := {"color": fence_color, "intensity": 1.0, "fade_begin": fog_begin + 40.0, "fade_end": fog_end + 20.0}
		_materials[&"fence_field"] = MeshKit.state_materials("energy_field.gdshader", on,
			{"flicker_hz": 16.0, "intensity": 0.75}, {"intensity": 0.0})
	return _materials[&"fence_field"]


func _solid_params() -> Dictionary:
	return {"glow_scale": emissive_scale, "sheen_color": sheen_color, "sheen_strength": sheen_strength}


func trucks() -> CityTrucks:
	if _trucks == null:
		_trucks = CityTrucks.new(self)
	return _trucks


func towers() -> CityTowers:
	if _towers == null:
		_towers = CityTowers.new(self)
	return _towers


func ship() -> CityShip:
	if _ship == null:
		_ship = CityShip.new(self)
	return _ship


func props() -> CityProps:
	if _props == null:
		_props = CityProps.new(self)
	return _props

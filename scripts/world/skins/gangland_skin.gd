class_name GanglandSkin
extends ZoneSkin
## Zone 2, Gangland (GDD §5, §11): grimy, bombed-out streets. Floor segments are stretches of a
## cracked street, gaps are holes blown into the road (the orange edge glow sits on the collision
## edge, road strata show below), walls are bombed-out building faces with barricaded side streets,
## signs are salvaged billboards in the yellow/black hazard frame, electric fences are the same pink
## energy field strung between rubble and wrecks, and ceilings are the underside of a scavenger barge.
## The street stands still, unlike the city's trucks, so drifting ash, paper scraps and speed streaks
## carry the sense of speed (GDD §5, proposed; camera shake belongs to gameplay, not the skin).
## Grime and rust stay desaturated and fires burn only far from the play field, so hazards remain the
## most saturated things on screen. No decorative manholes or wall vents: in Gangland those are
## sewer-screech spawn points (GDD §9.5), and decorative ones would lie to the player.
## Visuals only: TrackBuilder owns every collision shape and gameplay node, and all variety comes
## from hashing track positions (MeshKit.hash_i), so a chunk looks the same whenever it is built.

@export_group("Environment")
@export var sky_zenith_color: Color = Color(0.02, 0.018, 0.02)
@export var sky_horizon_color: Color = Color(0.13, 0.1, 0.085)
## Smog lit from below by the fires of the city, low over the horizon.
@export var haze_color: Color = Color(0.24, 0.15, 0.1)
@export_range(0.0, 2.0, 0.05) var haze_strength: float = 0.7
@export var abyss_color: Color = Color(0.02, 0.018, 0.016)
@export var skyline_color: Color = Color(0.045, 0.04, 0.038)
@export var skyline_window_color: Color = Color(0.5, 0.36, 0.22)
## A pale moon, veiled by the smog.
@export var moon_color: Color = Color(0.8, 0.75, 0.62)
@export var moon_direction: Vector3 = Vector3(-0.2, 0.28, -0.94)
@export_range(0.0, 0.3, 0.005) var moon_radius: float = 0.06
@export_range(0.0, 1.0, 0.01) var moon_clarity: float = 0.35
## Columns of smoke over the far skyline, lit from below by fires far from the play field.
@export_range(0.0, 1.0, 0.01) var smoke_amount: float = 1.0
@export var smoke_color: Color = Color(0.06, 0.055, 0.05)
@export var distant_fire_color: Color = Color(0.5, 0.24, 0.1)
@export var ambient_color: Color = Color(0.5, 0.45, 0.42)
## Distant geometry fades into the smog between fog_begin and fog_end.
@export var fog_color: Color = Color(0.11, 0.095, 0.085)
@export_range(0.0, 150.0, 1.0, "suffix:m") var fog_begin: float = 14.0
@export_range(50.0, 400.0, 5.0, "suffix:m") var fog_end: float = 170.0
@export_range(0.0, 1.0, 0.01) var fog_max: float = 1.0
@export_range(0.0, 2.0, 0.05) var glow_intensity: float = 0.75
@export_range(0.5, 4.0, 0.05) var glow_threshold: float = 1.1
## Brightness of emissive kit parts (vertex glow 1.0 = this many times the albedo).
@export_range(1.0, 20.0, 0.5) var emissive_scale: float = 4.0
## Smog glow caught at grazing angles by the street, walls and hulls.
@export var sheen_color: Color = Color(0.3, 0.24, 0.2)
@export_range(0.0, 1.0, 0.01) var sheen_strength: float = 0.2

@export_group("Street")
@export var asphalt_color: Color = Color(0.17, 0.165, 0.16)
## Worn paint of the dashed lines between lanes. Pale and grey: yellow belongs to signs.
@export var lane_marking_color: Color = Color(0.42, 0.41, 0.39)
## The strip between the outer lanes and the building faces.
@export var gutter_color: Color = Color(0.24, 0.23, 0.215)
## The earth under the road, seen in the walls of the holes.
@export var earth_color: Color = Color(0.2, 0.16, 0.12)
@export var crater_floor_color: Color = Color(0.02, 0.018, 0.016)
## How far the holes go down before the dark floor (the road strata fade out well above it).
@export_range(2.0, 12.0, 0.1, "suffix:m") var crater_depth: float = 4.5
## Gap edges: the orange edge language, as in the city. Redder than it looks: the glow and the
## tonemapper lift the green, and it must stay orange, not sign yellow.
@export var gap_edge_color: Color = Color(1.0, 0.25, 0.04)

@export_group("Ruins")
@export_range(10.0, 80.0, 1.0, "suffix:m") var building_min_height: float = 14.0
@export_range(12.0, 120.0, 1.0, "suffix:m") var building_max_height: float = 34.0
## Buildings are 1–3 lots long; a lot is this long.
@export_range(6.0, 40.0, 1.0, "suffix:m") var lot_length: float = 14.0
## Stained concrete and brick, kept desaturated.
@export var facade_colors: PackedColorArray = PackedColorArray([
	Color(0.2, 0.19, 0.18), Color(0.23, 0.2, 0.18), Color(0.17, 0.17, 0.17), Color(0.22, 0.18, 0.16)])
## Windows are boarded or bricked up below this height (the wall-run band must look solid).
@export_range(4.0, 12.0, 0.1, "suffix:m") var boarded_below: float = 7.0
@export var board_color: Color = Color(0.26, 0.21, 0.16)
@export var shutter_color: Color = Color(0.3, 0.3, 0.29)
@export var soot_color: Color = Color(0.025, 0.022, 0.02)
## Graffiti on shutters, barricades and billboards: muted, never a hazard hue.
@export var graffiti_color: Color = Color(0.36, 0.48, 0.48)
@export var window_lamp_color: Color = Color(0.85, 0.65, 0.42)
@export_range(0.0, 3.0, 0.05) var window_glow: float = 0.9
## Burning windows high up and fires deep in side streets: far from the play field, and dim.
@export var fire_color: Color = Color(0.8, 0.4, 0.16)
## Rusty sheet metal barricading the side streets.
@export var barricade_color: Color = Color(0.25, 0.22, 0.2)
@export var rust_color: Color = Color(0.27, 0.19, 0.13)
## Faint lines on the facades at these heights, to read how high a wall run is.
@export var wall_height_marks: PackedFloat32Array = PackedFloat32Array([2.0, 4.0])
@export var wall_mark_color: Color = Color(0.55, 0.55, 0.6)

@export_group("Motion")
## DESIGN-TBD: GDD §5 proposes motion effects for still streets. Per 40 m of track: ash flecks,
## paper scraps and speed streaks drifting toward the player (a = opacity).
@export_range(0, 200, 1) var ash_count: int = 60
@export_range(0, 60, 1) var scrap_count: int = 6
@export_range(0, 60, 1) var streak_count: int = 14
@export var ash_color: Color = Color(0.55, 0.53, 0.5, 0.7)
@export var scrap_color: Color = Color(0.6, 0.58, 0.52, 0.8)
@export var streak_color: Color = Color(0.75, 0.78, 0.85, 0.35)
@export_range(0.0, 30.0, 0.5, "suffix:m/s") var ash_speed: float = 6.0
@export_range(0.0, 80.0, 0.5, "suffix:m/s") var streak_speed: float = 24.0

@export_group("Hazards")
## Pink crackle always means electric fence (GDD §5).
@export var fence_color: Color = Color(1.0, 0.18, 0.62)
@export var fence_pole_color: Color = Color(0.3, 0.27, 0.25)
@export var rubble_color: Color = Color(0.3, 0.29, 0.27)
@export var wreck_color: Color = Color(0.27, 0.22, 0.19)
## Signs: the yellow/black hazard frame around grimy salvaged billboards.
@export var sign_frame_color: Color = Color(1.0, 0.8, 0.15)
@export var sign_content_colors: PackedColorArray = PackedColorArray([
	Color(0.5, 0.47, 0.42), Color(0.42, 0.44, 0.45), Color(0.48, 0.42, 0.4), Color(0.4, 0.42, 0.38)])

@export_group("Ceiling barge")
## DESIGN-TBD: the GDD leaves Gangland's ceiling open; this is a patched-together scavenger cargo
## barge with salvaged plating.
@export var hull_color: Color = Color(0.25, 0.235, 0.22)
@export var hull_lamp_color: Color = Color(0.95, 0.85, 0.65)
@export var engine_color: Color = Color(0.6, 0.72, 0.9)

@export_group("Pads, ramps, finish")
@export var pad_color: Color = Color(0.1, 1.0, 0.95)
## Height of the anti-grav pad's light column.
@export_range(1.0, 10.0, 0.1, "suffix:m") var pad_beam_height: float = 5.8
@export var ramp_color: Color = Color(0.3, 1.0, 0.35)
## DESIGN-TBD: speed pads share the ramps' green "safe boost" family (MeshKit.speed_strip).
@export var speed_pad_color: Color = Color(0.45, 1.0, 0.55)
@export var finish_color: Color = Color(1.0, 1.0, 1.0)
## Scavenged steel under pads, ramps and the finish gantry.
@export var scrap_metal_color: Color = Color(0.17, 0.155, 0.14)

## Built on first use and shared by every mesh (exports changed later don't reach them).
var _materials: Dictionary = {}
var _street: GanglandStreet
var _ruins: GanglandRuins
var _barge: GanglandBarge
var _props: GanglandProps


func _init() -> void:
	enemy_variant = &"scavenger"


func make_environment() -> Environment:
	var sky := {"zenith_color": sky_zenith_color, "horizon_color": sky_horizon_color, "haze_color": haze_color,
		"haze_strength": haze_strength, "abyss_color": abyss_color, "skyline_color": skyline_color,
		"window_color": skyline_window_color, "moon_color": moon_color, "moon_direction": moon_direction,
		"moon_radius": moon_radius, "moon_clarity": moon_clarity, "star_amount": 0.1, "skyline_ruin": 1.0,
		"smoke_amount": smoke_amount, "smoke_color": smoke_color, "fire_color": distant_fire_color}
	return MeshKit.night_environment(sky, ambient_color, fog_color, fog_begin, fog_end, fog_max, 0.0,
		glow_intensity, glow_threshold)


func floor_segment(parent: Node3D, center: Vector3, size: Vector3, lane_x: float,
		edge_start: bool, edge_end: bool) -> void:
	var batch := MeshBatch.new()
	street().build(batch, center, size, lane_x, edge_start, edge_end)
	batch.commit(parent)


func wall_section(parent: Node3D, side: int, face_x: float, start: float, end: float) -> void:
	var batch := MeshBatch.new()
	ruins().build(batch, side, face_x, start, end)
	if side < 0:
		street().below(batch, absf(face_x), start, end)
	batch.commit(parent)


func fence(hazard: Hazard, size: Vector3, ground_y: float, gapped: bool) -> void:
	props().fence(hazard, size, ground_y, gapped)


func wall_sign(hazard: Hazard, size: Vector3) -> void:
	props().wall_sign(hazard, size)


func hull(parent: Node3D, center: Vector3, size: Vector3, lane_edges_x: Array[float]) -> void:
	barge().build(parent, center, size, lane_edges_x)


func pad(trigger: Area3D, size: Vector3) -> void:
	MeshBatch.add_instance(trigger, MeshKit.lift_pad(size, pad_color, scrap_metal_color, pad_beam_height,
		solid_material(), glow_material()))


func ramp(trigger: Area3D, size: Vector3, side: int) -> void:
	MeshBatch.add_instance(trigger, MeshKit.kicker_ramp(size, side, ramp_color, scrap_metal_color, solid_material(),
		glow_material()))


func speed_pad(trigger: Area3D, size: Vector3) -> void:
	MeshBatch.add_instance(trigger, MeshKit.speed_strip(size, speed_pad_color, scrap_metal_color, solid_material(),
		glow_material()))


func finish_line(parent: Node3D, width: float, distance: float) -> void:
	var batch := MeshBatch.new()
	MeshKit.finish_gate(batch, solid_material(), glow_material(), width, distance, finish_color, scrap_metal_color)
	batch.commit(parent)


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
			"ruin": 1.0, "band_top": boarded_below, "board_color": board_color, "shutter_color": shutter_color,
			"soot_color": soot_color, "graffiti_color": graffiti_color, "fire_color": fire_color,
			"window_warm": window_lamp_color, "window_glow": window_glow, "sheen_color": sheen_color,
			"sheen_strength": sheen_strength})
	return _materials[&"facade"]


func drift_material() -> ShaderMaterial:
	if not _materials.has(&"drift"):
		_materials[&"drift"] = MeshKit.material("drift.gdshader", {
			"slice_length": TrackBuilder.CHUNK_LENGTH, "ash_speed": ash_speed, "streak_speed": streak_speed})
	return _materials[&"drift"]


## ON, WARNING and OFF materials for a fence's glowing parts (bars, emitters, insulator caps).
func fence_part_materials() -> Array[Material]:
	if not _materials.has(&"fence_parts"):
		_materials[&"fence_parts"] = MeshKit.hazard_part_materials(_solid_params())
	return _materials[&"fence_parts"]


## ON, WARNING and OFF materials for a fence's energy field.
func fence_field_materials() -> Array[Material]:
	if not _materials.has(&"fence_field"):
		_materials[&"fence_field"] = MeshKit.fence_field_materials(fence_color, fog_begin + 40.0, fog_end + 20.0)
	return _materials[&"fence_field"]


func _solid_params() -> Dictionary:
	return {"glow_scale": emissive_scale, "sheen_color": sheen_color, "sheen_strength": sheen_strength,
		"marking_color": lane_marking_color, "rust_color": rust_color, "graffiti_color": graffiti_color}


func street() -> GanglandStreet:
	if _street == null:
		_street = GanglandStreet.new(self)
	return _street


func ruins() -> GanglandRuins:
	if _ruins == null:
		_ruins = GanglandRuins.new(self)
	return _ruins


func barge() -> GanglandBarge:
	if _barge == null:
		_barge = GanglandBarge.new(self)
	return _barge


func props() -> GanglandProps:
	if _props == null:
		_props = GanglandProps.new(self)
	return _props

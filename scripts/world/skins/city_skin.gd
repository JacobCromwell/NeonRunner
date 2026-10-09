class_name CitySkin
extends ZoneSkin
## Zone 1, the Neon City (GDD §5, §11). Floor segments are the roofs of hover-truck convoys driving
## toward the player, gaps are the spaces between them with a road far below, walls are tower
## facades, signs are neon billboards in a yellow/black hazard frame, electric fences are pink
## energy fields between the trucks' exhaust stacks, and ceilings are the undersides of low ships.
## The cult (GDD §5): its feed (CultFeed) plays on some roof billboards and on big screens hung out
## over the street from some towers, facing the traffic, and its emblem (the owner's pick) hides small
## in some neon ads in its warm-white neon, never on hazard signs. Both stay far above the wall-run
## band, which keeps calm; hazards stay the most saturated and brightest things on screen.
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
## A big moon low over the far end of the street, seen between the towers (sky direction, radius in radians).
@export var moon_color: Color = Color(0.85, 0.8, 1.0)
@export var moon_direction: Vector3 = Vector3(0.07, 0.3, -0.95)
@export_range(0.0, 0.3, 0.005) var moon_radius: float = 0.075
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
## DESIGN-TBD: the GDD says the trucks drive toward the player but not how fast.
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

@export_group("Cult feed")
## DESIGN-TBD (docs/questions/d9.md): how often the cult's feed (CultFeed, GDD §5 "Cyborg Viewing
## Devices") plays in the Neon City, alongside the ordinary neon ads: the share of the low buildings'
## roof billboards showing it instead of an ad, and of towers carrying a big screen playing it.
@export_range(0.0, 1.0, 0.01) var feed_share: float = 0.35
@export_range(0.0, 1.0, 0.01) var feed_tower_share: float = 0.4
## Brightness of the feed (0-1) on the roof billboards and on the towers' big screens.
@export_range(0.0, 1.0, 0.05) var feed_board_brightness: float = 0.9
@export_range(0.0, 1.0, 0.05) var feed_screen_brightness: float = 0.85
## The towers' big screens (16:9), hung out over the street facing the oncoming traffic: the widest,
## the share of the street's half width they may reach over, and the lowest their bottom edge goes
## (far above the wall-run band and the ships).
@export_range(2.0, 12.0, 0.1, "suffix:m") var feed_screen_width: float = 4.8
@export_range(0.2, 1.0, 0.01) var feed_screen_reach: float = 0.7
@export_range(9.0, 40.0, 0.5, "suffix:m") var feed_screen_bottom: float = 12.0

@export_group("Cult emblem")
## The cult's emblem hidden in the city's ads (GDD §5, proposed: in logos and ads in every zone): a
## sponsor's badge in a corner of some roof billboards, a brand mark at the foot of some towers' neon
## banners, in its own warm-white neon (CultEmblem.default_scheme), never an ad's main mark and never
## on hazard signs. It is the owner's pick (CultFeed.emblem_option(), from the choice file).
## DESIGN-TBD (docs/questions/d9.md): where and how often.
@export_range(0.0, 1.0, 0.01) var emblem_share: float = 0.4
## Never smaller than this: tiny, its three-fold silhouette could read like the radiation trefoil
## (the kit shader also fades it out before it spans fewer than about 24 pixels on screen).
@export_range(0.5, 3.0, 0.05, "suffix:m") var emblem_min_size: float = 0.9
## Glow of its warm-white neon.
@export_range(0.0, 1.5, 0.05) var emblem_glow: float = 0.6

@export_group("Doodads")
## Market-stall canopy colours for the City's doodads (GDD §3, task G6): muted, non-hazard tones, well
## apart from every hazard hue (pink, yellow and black, red, orange, green, cyan).
@export var doodad_stall_colors: PackedColorArray = PackedColorArray([
	Color(0.4, 0.3, 0.22), Color(0.3, 0.33, 0.4), Color(0.26, 0.28, 0.24)])

@export_group("Pads, ramps, finish")
@export var pad_color: Color = Color(0.1, 1.0, 0.95)
## Height of the anti-grav pad's light column.
@export_range(1.0, 10.0, 0.1, "suffix:m") var pad_beam_height: float = 5.8
@export var ramp_color: Color = Color(0.3, 1.0, 0.35)
## Speed pads share the ramps' green "safe boost" family (MeshKit.speed_strip; FB 49).
@export var speed_pad_color: Color = Color(0.45, 1.0, 0.55)
@export var finish_color: Color = Color(1.0, 1.0, 1.0)

## Built on first use and shared by every mesh (exports changed later don't reach them).
var _materials: Dictionary = {}
var _trucks: CityTrucks
var _towers: CityTowers
var _ship: CityShip
var _props: CityProps
var _doodads: CityDoodads
var _dash_walls: CityDashWall


func make_environment() -> Environment:
	var sky := {"zenith_color": sky_zenith_color, "horizon_color": sky_horizon_color, "haze_color": haze_color,
		"abyss_color": abyss_color, "skyline_color": skyline_color, "window_color": skyline_window_color,
		"moon_color": moon_color, "moon_direction": moon_direction, "moon_radius": moon_radius}
	return MeshKit.night_environment(sky, ambient_color, fog_color, fog_begin, fog_end, fog_max, abyss_fog_density,
		glow_intensity, glow_threshold)


func floor_segment(parent: Node3D, center: Vector3, size: Vector3, lane_x: float,
		edge_start: bool, edge_end: bool) -> void:
	# The collision box spans the lane (outer lanes reach the wall); the truck is centred on the lane.
	var half_lane: float = minf(center.x + size.x * 0.5 - lane_x, lane_x - (center.x - size.x * 0.5))
	var near_d: float = -(center.z + size.z * 0.5)
	var far_d: float = -(center.z - size.z * 0.5)
	var batch := MeshBatch.new()
	trucks().build(batch, lane_x, (half_lane - truck_inset) * 2.0, near_d, far_d, edge_start, edge_end)
	batch.commit(parent)


## A floor cut (ZoneSkin.floor_cut; task B4, H3): the lane's hover truck sliced open, and through it what
## any gap shows (GDD §9.9): the road far below, with its traffic (the chunk's own road, drawn with the
## left wall), between the neighbouring trucks' own sides. The inside draws no walls (the trucks beside
## it carry theirs, and no wall stands at the facade at a gap here) and no bottom: only the far end,
## where the lane's truck went on, a dark face as tall as a truck (the road is `road_depth` down, not
## 8 m of box). The orange edges and the halo are the standard ones.
## DESIGN-TBD (docs/questions/h3.md, question 2): a gap's far side is the next truck's cab, with lights; a
## cut's far end has no cab, so it is a plain dark face (never lit: lights there would be glows that
## mean something else beside the cut's orange).
func floor_cut(parent: Node3D, cut: FloorCutSection) -> void:
	standard_floor_cut(parent, cut, solid_material(), glow_material(), {
		"edge": gap_edge_color, "inside": CUT_INSIDE_COLOR, "depth": road_depth, "end_depth": truck_height,
		"bottom": false, "walls": false, "outer_walls": false,
	})


func wall_section(parent: Node3D, side: int, face_x: float, start: float, end: float) -> void:
	var batch := MeshBatch.new()
	towers().build(batch, side, face_x, start, end)
	batch.commit(parent)


## A wall gap (ZoneSkin.wall_gap), and with the left wall the road under the street that the towers
## draw with it.
func wall_gap(parent: Node3D, side: int, face_x: float, start: float, end: float, gap: Vector2) -> void:
	super(parent, side, face_x, start, end, gap)
	if side < 0:
		var w: float = absf(face_x)
		var batch := MeshBatch.new()
		batch.layer(road_material()).rect(Vector3(-w, -road_depth, -start), Vector3(w * 2.0, 0, 0),
			Vector3(0, 0, -(end - start)), road_color)
		batch.commit(parent)


func fence(hazard: Hazard, size: Vector3, ground_y: float, gapped: bool) -> void:
	props().fence(hazard, size, ground_y, gapped)


func wall_sign(hazard: Hazard, size: Vector3) -> void:
	props().wall_sign(hazard, size)


## A ship over the ceiling's lanes: over every lane a ship across the street, over fewer (a narrow
## ceiling, GDD §3) a smaller craft over its own lanes (CityShip).
func ceiling_section(parent: Node3D, section: CeilingSection) -> void:
	ship().build(parent, section.center, section.size, section.lane_edges_x, not section.full())


func hull(parent: Node3D, center: Vector3, size: Vector3, lane_edges_x: Array[float]) -> void:
	ship().build(parent, center, size, lane_edges_x)


func pad(trigger: Area3D, size: Vector3) -> void:
	props().pad(trigger, size)


func ramp(trigger: Area3D, size: Vector3, side: int) -> void:
	props().ramp(trigger, size, side)


func speed_pad(trigger: Area3D, size: Vector3) -> void:
	props().speed_pad(trigger, size)


func finish_line(parent: Node3D, width: float, distance: float) -> void:
	props().finish_line(parent, width, distance)


## A dash wall (task H7b): a dark block across the street, built from the towers' own kit (CityDashWall): the
## facade shader's four window grids, concrete slab bands, piers and a cornice with a dead neon trim.
func dash_wall(body: Node3D, size: Vector3, look_seed: int) -> void:
	DashWallKit.dress(body, dash_walls().mesh_for(size, look_seed))


## The surfaces a City dash wall draws with: the facade shader and the solid kit.
func dash_wall_materials() -> Array[Material]:
	return [solid_material(), facade_material()]


## A dash wall's default look colours (ZoneSkin.dash_wall, task H7a) in the City's own facades: a lighter shade of
## them, so the building reads as solid against the night street, trimmed in their darker one; dark glass. Kept as
## the palette the debris falls back on.
func dash_wall_colors() -> PackedColorArray:
	var body: Color = facade_colors[facade_colors.size() - 1].lightened(0.16)
	return PackedColorArray([body, facade_colors[0].lightened(0.08), Color(0.05, 0.06, 0.09), Color(0.02, 0.02, 0.03)])


## A pillar (small), a tiny market stall (medium) or a small storefront (large): CityDoodads.
func doodad(body: Node3D, size: Vector3, size_class: StringName, side: int, look_seed: int) -> void:
	doodads().build(body, size, size_class, side, look_seed)


# --- The cult's feed and emblem ------------------------------------------------------------

## The shared feed material (CultFeed): the same broadcast as in every zone.
func feed_material() -> ShaderMaterial:
	return CultFeed.material()


## Whether the screen keyed by (a, b) plays the cult's feed instead of an ad (`share` of them).
func shows_feed(a: int, b: int, share: float) -> bool:
	return MeshKit.hash01(a, b, 131) < share


## Whether the ad keyed by (a, b) carries the cult's emblem (emblem_share of them).
func carries_emblem(a: int, b: int) -> bool:
	return MeshKit.hash01(a, b, 97) < emblem_share


## The screens on the walls playing the feed (the roof billboards and the towers' big screens) whose
## middles lie between two track distances, for reviews and tests: side, at, kind (&"roof_board" or
## &"tower_screen"), width, height, center (the screen's middle, on its face). The same ones
## wall_section() builds.
func feed_boards(side: int, face_x: float, start: float, end: float) -> Array[Dictionary]:
	return towers().feed_boards(side, face_x, start, end)


## The cult's emblems on the walls whose middles lie between two track distances, for reviews and
## tests: side, at, kind (&"roof_board" or &"banner"), size (the mark's square, metres), center.
func cult_emblems(side: int, face_x: float, start: float, end: float) -> Array[Dictionary]:
	return towers().emblems(side, face_x, start, end)


## The warm white the emblem glows in on the city's ads: the chosen option's own neon.
func emblem_color() -> Color:
	return CultEmblem.default_scheme(CultFeed.emblem_option())["neon"]


# --- Shared materials (built once per skin, shared by every mesh) ------------------------

func solid_material() -> ShaderMaterial:
	if not _materials.has(&"solid"):
		var m: ShaderMaterial = MeshKit.solid(_solid_params())
		# The emblem's coverage for MeshKit.PAT_CULT_MARK (the owner's pick, drawn by CultEmblem).
		m.set_shader_parameter(&"cult_emblem", CultFeed.emblem_texture())
		_materials[&"solid"] = m
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


## ON, WARNING and OFF materials for a fence's emissive parts (bars, nozzles).
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
	return {"glow_scale": emissive_scale, "sheen_color": sheen_color, "sheen_strength": sheen_strength}


func trucks() -> CityTrucks:
	if _trucks == null:
		_trucks = CityTrucks.new(self)
	return _trucks


func dash_walls() -> CityDashWall:
	if _dash_walls == null:
		_dash_walls = CityDashWall.new(self)
	return _dash_walls


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


func doodads() -> CityDoodads:
	if _doodads == null:
		_doodads = CityDoodads.new(self)
	return _doodads

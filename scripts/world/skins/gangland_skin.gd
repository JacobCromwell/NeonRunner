class_name GanglandSkin
extends ZoneSkin
## Zone 2, Gangland (GDD §5, §11): Mad Max in a cyberpunk setting, futuristic rather than historical,
## in browns and tans. Floor segments are stretches of a cracked, sand-blown street, gaps are holes
## blasted into the road (scorched around, the orange edge glow on the collision edge, road strata
## below), walls are bombed-out building faces, signs are salvaged billboards in the yellow/black
## hazard frame, electric fences are the same pink energy field strung between rubble, oil drums and
## sandbags, and ceilings are the undersides of overpasses and of bombed-out buildings bridging the
## street (GanglandCeiling).
## Lived in (the owner's direction): graffiti everywhere, lit windows with curtains, laundry and
## balconies, rooftop water tanks, antennas and dishes, lines strung across the street, bulbs over the
## side streets. Gangs compete for power, and some are funded by corporate and military interests,
## so their things carry hints of it: military supply crates with stencilled codes, corporate
## containers used as barricades, notice boards, and corporate ads pasted among the posters. The
## cult behind it all hides in plain sight (GDD §5): its emblem (CultEmblem, the owner's pick) sits
## small and unlit beside some of those markings, never a centrepiece, and its feed (CultFeed) plays
## on salvaged screens among the posters on some overpass gantries and on TVs glowing in some upper
## windows, never in the boarded-up wall-run band.
## The street stands still, unlike the city's trucks, so drifting dust, paper scraps and speed
## streaks carry the sense of speed (GDD §5, proposed; camera shake belongs to gameplay, not the skin).
## Colour rule (GDD §5): browns and tans stay desaturated and never glow; the only glowing decoration
## near the play field is warm white light (lamps, windows, bulbs); fires burn only far from it. So
## hazards remain the most saturated things on screen. No decorative manholes or wall vents: in
## Gangland those are sewer-screech spawn points (GDD §9.5), and decorative ones would lie to the player.
## Visuals only: TrackBuilder owns every collision shape and gameplay node, and all variety comes
## from hashing track positions (MeshKit.hash_i), so a chunk looks the same whenever it is built.

@export_group("Environment")
## A dusty dusk: brown overhead, tan dust over the horizon.
## DESIGN-TBD: the GDD gives Gangland's palette (browns and tans), not its time of day or weather;
## a dusty dusk keeps the scene dark enough for the hazards' glow to pop.
@export var sky_zenith_color: Color = Color(0.17, 0.13, 0.095)
@export var sky_horizon_color: Color = Color(0.36, 0.275, 0.19)
## Dust lit by the low sun and the fires of the city, over the horizon.
@export var haze_color: Color = Color(0.5, 0.38, 0.25)
@export_range(0.0, 2.0, 0.05) var haze_strength: float = 0.9
@export var abyss_color: Color = Color(0.035, 0.028, 0.022)
@export var skyline_color: Color = Color(0.14, 0.11, 0.085)
@export var skyline_window_color: Color = Color(0.55, 0.42, 0.28)
## A pale sun low in the dust (the sky shader's moon), veiled.
@export var moon_color: Color = Color(0.9, 0.82, 0.66)
@export var moon_direction: Vector3 = Vector3(-0.2, 0.16, -0.96)
@export_range(0.0, 0.3, 0.005) var moon_radius: float = 0.07
@export_range(0.0, 1.0, 0.01) var moon_clarity: float = 0.3
## Columns of smoke over the far skyline, lit from below by fires far from the play field.
@export_range(0.0, 1.0, 0.01) var smoke_amount: float = 1.0
@export var smoke_color: Color = Color(0.11, 0.09, 0.075)
@export var distant_fire_color: Color = Color(0.45, 0.25, 0.12)
@export var ambient_color: Color = Color(0.58, 0.5, 0.42)
## Distant geometry fades into the dust between fog_begin and fog_end.
@export var fog_color: Color = Color(0.25, 0.195, 0.14)
@export_range(0.0, 150.0, 1.0, "suffix:m") var fog_begin: float = 14.0
@export_range(50.0, 400.0, 5.0, "suffix:m") var fog_end: float = 165.0
@export_range(0.0, 1.0, 0.01) var fog_max: float = 1.0
@export_range(0.0, 2.0, 0.05) var glow_intensity: float = 0.75
@export_range(0.5, 4.0, 0.05) var glow_threshold: float = 1.1
## Brightness of emissive kit parts (vertex glow 1.0 = this many times the albedo).
@export_range(1.0, 20.0, 0.5) var emissive_scale: float = 4.0
## Dust glow caught at grazing angles by the street, walls and ceilings.
@export var sheen_color: Color = Color(0.36, 0.28, 0.2)
@export_range(0.0, 1.0, 0.01) var sheen_strength: float = 0.2

@export_group("Street")
@export var asphalt_color: Color = Color(0.21, 0.19, 0.165)
## Worn paint of the dashed lines between lanes. Pale: yellow belongs to signs.
@export var lane_marking_color: Color = Color(0.5, 0.47, 0.41)
## The strip between the outer lanes and the building faces, where the sand piles up.
@export var gutter_color: Color = Color(0.33, 0.28, 0.215)
## Sand blown over the street in long drifts.
@export var sand_color: Color = Color(0.44, 0.37, 0.28)
@export_range(0.0, 1.0, 0.01) var sand_amount: float = 0.55
## Soot around the holes (blast craters); the orange edge reads against it.
@export_range(0.0, 1.0, 0.01) var scorch_amount: float = 0.8
## The earth under the road, seen in the walls of the holes.
@export var earth_color: Color = Color(0.24, 0.18, 0.13)
@export var crater_floor_color: Color = Color(0.025, 0.02, 0.016)
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
## Sandstone, adobe, umber concrete and tan plaster, kept desaturated.
@export var facade_colors: PackedColorArray = PackedColorArray([
	Color(0.36, 0.3, 0.235), Color(0.3, 0.24, 0.185), Color(0.27, 0.23, 0.195), Color(0.4, 0.34, 0.27),
	Color(0.24, 0.195, 0.16)])
## Windows are boarded or bricked up below this height (the wall-run band must look solid).
@export_range(4.0, 12.0, 0.1, "suffix:m") var boarded_below: float = 7.0
@export var board_color: Color = Color(0.3, 0.245, 0.19)
@export var shutter_color: Color = Color(0.34, 0.31, 0.27)
@export var soot_color: Color = Color(0.03, 0.025, 0.02)
## Graffiti on walls, shutters, barricades and fascias: dusty blue, steel grey, violet grey and faded
## cream, with dark outlines. Muted, and never a hazard hue.
@export var graffiti_color: Color = Color(0.3, 0.42, 0.55)
@export var graffiti_color_b: Color = Color(0.37, 0.43, 0.48)
@export var graffiti_color_c: Color = Color(0.41, 0.37, 0.49)
## Share of wall slots (4.2 x 2.8 m) painted, up to a storey above the wall-run band.
@export_range(0.0, 1.0, 0.01) var graffiti_amount: float = 0.6
## Lamplight in the windows: a warm white, not the orange of gap edges.
@export var window_lamp_color: Color = Color(0.92, 0.82, 0.66)
@export_range(0.0, 3.0, 0.05) var window_glow: float = 0.95
## Share of a building's upper windows that are lit (each building picks within this range).
@export_range(0.0, 1.0, 0.01) var ruin_lit_min: float = 0.12
@export_range(0.0, 1.0, 0.01) var ruin_lit_max: float = 0.32
## Share of lit windows with curtains, and their fabrics.
@export_range(0.0, 1.0, 0.01) var curtain_share: float = 0.55
@export var curtain_color: Color = Color(0.52, 0.4, 0.34)
@export var curtain_color_b: Color = Color(0.36, 0.42, 0.46)
## Burning windows high up and fires deep in side streets: far from the play field, and dim.
@export var fire_color: Color = Color(0.8, 0.4, 0.16)
## Rusty sheet metal barricading the side streets.
@export var barricade_color: Color = Color(0.3, 0.24, 0.19)
@export var rust_color: Color = Color(0.3, 0.19, 0.12)
## Faint lines on the facades at these heights, to read how high a wall run is.
@export var wall_height_marks: PackedFloat32Array = PackedFloat32Array([2.0, 4.0])
@export var wall_mark_color: Color = Color(0.62, 0.58, 0.52)

@export_group("Signs of life")
## Laundry, rags and flags on lines and balconies.
@export var cloth_colors: PackedColorArray = PackedColorArray([
	Color(0.62, 0.58, 0.5), Color(0.38, 0.42, 0.5), Color(0.5, 0.4, 0.33), Color(0.33, 0.4, 0.38),
	Color(0.55, 0.5, 0.56)])
@export var line_color: Color = Color(0.08, 0.07, 0.06)
## Share of tall buildings with makeshift balconies (laundry on the rail) above the wall-run band.
@export_range(0.0, 1.0, 0.01) var balcony_share: float = 0.55
## Share of rooftops (low stumps and the far row) with water tanks, antennas, dishes or shacks.
@export_range(0.0, 1.0, 0.01) var rooftop_share: float = 0.75
## Share of 30 m stretches with a washing line strung across the street, high above the play space
## (where both facades are tall enough to hold it).
@export_range(0.0, 1.0, 0.01) var cross_line_share: float = 0.8
## Bulbs strung over the side streets (warm white, never a hazard hue).
@export var bulb_color: Color = Color(0.95, 0.88, 0.74)
@export_range(0.0, 1.0, 0.01) var bulb_share: float = 0.6

@export_group("Funding hints")
## Military supply crates (olive, stencilled codes) and corporate containers (the logo on their
## doors) among the gangs' things.
## DESIGN-TBD: the owner asked for hints of corporate and military funding; these forms and shares
## are proposals. The logo on the containers, crates and ads is the Corporate zone's brand mark
## (kit_logo.gdshaderinc, task D4); the containers and ads keep their off-white and grey (whether they
## should take the brand's blue is docs/questions/d4.md's).
@export var military_crate_colors: PackedColorArray = PackedColorArray([
	Color(0.27, 0.28, 0.19), Color(0.3, 0.3, 0.21), Color(0.24, 0.25, 0.18)])
@export var container_colors: PackedColorArray = PackedColorArray([
	Color(0.43, 0.42, 0.4), Color(0.37, 0.38, 0.39), Color(0.34, 0.32, 0.3)])
## Share of side streets barricaded with stacked military crates, and with corporate containers
## (the rest use rusty sheets).
@export_range(0.0, 1.0, 0.01) var crate_barricade_share: float = 0.3
@export_range(0.0, 1.0, 0.01) var container_barricade_share: float = 0.3
## Share of posters that are corporate ads (billboards, gantries and walls).
@export_range(0.0, 1.0, 0.01) var poster_ads: float = 0.3
@export var ad_color: Color = Color(0.56, 0.57, 0.6)
## Share of tall buildings with a military notice board (a stencilled code) above the wall-run band.
@export_range(0.0, 1.0, 0.01) var notice_share: float = 0.35
## The cult's emblem hidden in plain sight (GDD §5): the share of corporate ads, containers, notice
## boards and larger crates carrying it, small, unlit and in its own colours beside their markings.
## It is the owner's pick (CULT_EMBLEM_CHOICE_PATH), drawn by CultEmblem, never a hardcoded option.
## DESIGN-TBD: GDD §5 proposes hiding it in logos and ads; where and how often is a proposal.
@export_range(0.0, 1.0, 0.01) var cult_emblem_share: float = 0.35

@export_group("Cult feed")
## The cult's feed (CultFeed, GDD §5 "Cyborg Viewing Devices") reaches Gangland too: salvaged
## screens among the posters on the overpasses' sign gantries play it, and a TV glows with it in an
## upper window of some ruins (never in the boarded-up wall-run band).
## DESIGN-TBD (docs/questions/d9.md): where and how often. The share of gantry billboards that are
## screens playing it, and of tall ruins with a TV window.
@export_range(0.0, 1.0, 0.01) var feed_share: float = 0.35
@export_range(0.0, 1.0, 0.01) var feed_window_share: float = 0.3
## Brightness of the feed (0-1) on the gantry screens, and on the TVs (dim: a dark room lit by one).
@export_range(0.0, 1.0, 0.05) var feed_board_brightness: float = 0.85
@export_range(0.0, 1.0, 0.05) var feed_window_brightness: float = 0.5
## The cold glow a TV throws over its window.
@export_range(0.0, 0.5, 0.01) var feed_window_glow: float = 0.1

@export_group("Motion")
## DESIGN-TBD: GDD §5 proposes motion effects for still streets. Per 40 m of track: dust flecks,
## paper scraps and speed streaks drifting toward the player (a = opacity).
@export_range(0, 200, 1) var ash_count: int = 60
@export_range(0, 60, 1) var scrap_count: int = 6
@export_range(0, 60, 1) var streak_count: int = 14
@export var ash_color: Color = Color(0.62, 0.55, 0.45, 0.7)
@export var scrap_color: Color = Color(0.66, 0.62, 0.54, 0.8)
@export var streak_color: Color = Color(0.8, 0.76, 0.68, 0.35)
@export_range(0.0, 30.0, 0.5, "suffix:m/s") var ash_speed: float = 6.0
@export_range(0.0, 80.0, 0.5, "suffix:m/s") var streak_speed: float = 24.0

@export_group("Hazards")
## Pink crackle always means electric fence (GDD §5).
@export var fence_color: Color = Color(1.0, 0.18, 0.62)
@export var fence_pole_color: Color = Color(0.32, 0.27, 0.23)
@export var rubble_color: Color = Color(0.34, 0.3, 0.25)
@export var wreck_color: Color = Color(0.3, 0.23, 0.18)
@export var sandbag_color: Color = Color(0.43, 0.38, 0.29)
## Signs: the yellow/black hazard frame around grimy salvaged billboards.
@export var sign_frame_color: Color = Color(1.0, 0.8, 0.15)
@export var sign_content_colors: PackedColorArray = PackedColorArray([
	Color(0.52, 0.47, 0.41), Color(0.44, 0.44, 0.44), Color(0.5, 0.43, 0.38), Color(0.43, 0.42, 0.37)])

@export_group("Ceilings")
## Share of ceilings formed by a bombed-out building bridging the street (the rest are overpasses).
## DESIGN-TBD: the GDD names the undersides of decaying or bombed-out buildings and overpasses; the
## two structures, their share and their looks are proposals.
@export_range(0.0, 1.0, 0.01) var ceiling_building_share: float = 0.45
## The overpass deck's cast concrete, and a building's bare floor slab.
@export var ceiling_concrete_color: Color = Color(0.37, 0.33, 0.28)
@export var ceiling_slab_color: Color = Color(0.31, 0.27, 0.23)
## The overpass fascia's height above the underside.
@export_range(0.6, 3.0, 0.05, "suffix:m") var overpass_depth: float = 1.3
## The work lamps along the lane seams: warm white.
@export var ceiling_lamp_color: Color = Color(0.95, 0.88, 0.72)
## Share of slots tagged on overpass undersides, and on their fascias and barriers.
@export_range(0.0, 1.0, 0.01) var ceiling_graffiti: float = 0.2
@export_range(0.0, 1.0, 0.01) var fascia_graffiti: float = 0.75

@export_group("Pads, ramps, finish")
@export var pad_color: Color = Color(0.1, 1.0, 0.95)
## Height of the anti-grav pad's light column.
@export_range(1.0, 10.0, 0.1, "suffix:m") var pad_beam_height: float = 5.8
@export var ramp_color: Color = Color(0.3, 1.0, 0.35)
## DESIGN-TBD: speed pads share the ramps' green "safe boost" family (MeshKit.speed_strip).
@export var speed_pad_color: Color = Color(0.45, 1.0, 0.55)
@export var finish_color: Color = Color(1.0, 1.0, 1.0)
## Scavenged steel under pads, ramps and the finish gantry, and on rails, masts and gantries.
@export var scrap_metal_color: Color = Color(0.2, 0.17, 0.145)

## The cult emblem the owner picked (D7) and the texture it is rasterised into (CultEmblem): small
## on screen by design (it fades out before it could read like a radiation trefoil), so a few dozen
## pixels are plenty, and it costs one short rasterisation per session.
const CULT_EMBLEM_CHOICE_PATH: String = "res://data/world/cult_emblem_choice.tres"
const CULT_EMBLEM_PIXELS: int = 64

## Emblem textures by option, shared by every skin instance.
static var _emblem_textures: Dictionary = {}

## Built on first use and shared by every mesh (exports changed later don't reach them).
var _materials: Dictionary = {}
var _street: GanglandStreet
var _ruins: GanglandRuins
var _ceiling: GanglandCeiling
var _props: GanglandProps


func _init() -> void:
	enemy_variant = &"scavenger"


func make_environment() -> Environment:
	var sky := {"zenith_color": sky_zenith_color, "horizon_color": sky_horizon_color, "haze_color": haze_color,
		"haze_strength": haze_strength, "abyss_color": abyss_color, "skyline_color": skyline_color,
		"window_color": skyline_window_color, "moon_color": moon_color, "moon_direction": moon_direction,
		"moon_radius": moon_radius, "moon_clarity": moon_clarity, "star_amount": 0.0, "skyline_ruin": 1.0,
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
		ruins().across(batch, absf(face_x), start, end)
	batch.commit(parent)


func fence(hazard: Hazard, size: Vector3, ground_y: float, gapped: bool) -> void:
	props().fence(hazard, size, ground_y, gapped)


func wall_sign(hazard: Hazard, size: Vector3) -> void:
	props().wall_sign(hazard, size)


## A ceiling over its lanes (GanglandCeiling): across the street (both sides run into the building
## faces) an overpass or a bombed-out building; over fewer lanes (a narrow ceiling, GDD §3) a slab
## broken off a building, lodged in the building face on a side that reaches the street's edge.
func ceiling_section(parent: Node3D, section: CeilingSection) -> void:
	ceiling().build(parent, section.center, section.size, section.lane_edges_x, section.reaches_wall(-1),
		section.reaches_wall(1), section.wall_x)


## A ceiling given as its box alone: across the street, both sides into the building faces.
func hull(parent: Node3D, center: Vector3, size: Vector3, lane_edges_x: Array[float]) -> void:
	ceiling().build(parent, center, size, lane_edges_x)


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


# --- The cult's feed ------------------------------------------------------------------------

## The shared feed material (CultFeed): the same broadcast as in every zone.
func feed_material() -> ShaderMaterial:
	return CultFeed.material()


## Whether the gantry billboard keyed by (a, b) is a screen playing the cult's feed (feed_share).
func shows_feed(a: int, b: int) -> bool:
	return MeshKit.hash01(a, b, 131) < feed_share


## The ruins' windows with a TV playing the feed whose middles lie between two track distances, for
## reviews and tests: side, at, center (the window's middle, on the wall face), width, bottom, top,
## and the TV's screen (screen_center, screen_width, screen_height). The same ones wall_section()
## builds.
func feed_windows(side: int, face_x: float, start: float, end: float) -> Array[Dictionary]:
	return ruins().tv_windows(side, face_x, start, end)


# --- Shared materials (built once per skin, shared by every mesh) ------------------------

func solid_material() -> ShaderMaterial:
	if not _materials.has(&"solid"):
		var m: ShaderMaterial = MeshKit.solid(_solid_params())
		m.set_shader_parameter(&"cult_emblem", cult_emblem_texture())
		_materials[&"solid"] = m
	return _materials[&"solid"]


## The option the owner picked for the cult's emblem (data/world/cult_emblem_choice.tres; the
## choice's own default if the file is missing).
static func cult_emblem_option() -> int:
	var choice := load(CULT_EMBLEM_CHOICE_PATH) as CultEmblemChoice
	if choice == null:
		push_error("GanglandSkin: no cult emblem choice at %s" % CULT_EMBLEM_CHOICE_PATH)
		choice = CultEmblemChoice.new()
	return choice.option


## The cult's emblem in its unlit colours (CultEmblem.default_scheme: "metal", with "metal_accent" for
## its detail) over a transparent background of the same colour, with mipmaps (the kit shader picks
## the level itself).
static func cult_emblem_texture() -> ImageTexture:
	var option: int = cult_emblem_option()
	if not _emblem_textures.has(option):
		var scheme: Dictionary = CultEmblem.default_scheme(option)
		var metal: Color = scheme["metal"]
		var img: Image = CultEmblem.build_image(option, CULT_EMBLEM_PIXELS, metal, scheme["metal_accent"],
			Color(metal, 0.0))
		img.generate_mipmaps()
		_emblem_textures[option] = ImageTexture.create_from_image(img)
	return _emblem_textures[option]


func glow_material() -> ShaderMaterial:
	if not _materials.has(&"glow"):
		_materials[&"glow"] = MeshKit.glow({"fade_begin": fog_begin, "fade_end": fog_end})
	return _materials[&"glow"]


func facade_material() -> ShaderMaterial:
	if not _materials.has(&"facade"):
		_materials[&"facade"] = MeshKit.material("facade.gdshader", {
			"ruin": 1.0, "band_top": boarded_below, "board_color": board_color, "shutter_color": shutter_color,
			"soot_color": soot_color, "graffiti_color": graffiti_color, "graffiti_color_b": graffiti_color_b,
			"graffiti_color_c": graffiti_color_c, "graffiti_amount": graffiti_amount, "fire_color": fire_color,
			"window_warm": window_lamp_color, "window_glow": window_glow, "curtain_share": curtain_share,
			"curtain_color": curtain_color, "curtain_color_b": curtain_color_b, "sheen_color": sheen_color,
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
		"marking_color": lane_marking_color, "rust_color": rust_color, "graffiti_color": graffiti_color,
		"graffiti_color_b": graffiti_color_b, "graffiti_color_c": graffiti_color_c, "graffiti_pieces": graffiti_amount,
		"sand_color": sand_color, "sand_amount": sand_amount, "scorch_amount": scorch_amount, "poster_ads": poster_ads,
		"ad_color": ad_color, "cult_emblem_share": cult_emblem_share}


func street() -> GanglandStreet:
	if _street == null:
		_street = GanglandStreet.new(self)
	return _street


func ruins() -> GanglandRuins:
	if _ruins == null:
		_ruins = GanglandRuins.new(self)
	return _ruins


func ceiling() -> GanglandCeiling:
	if _ceiling == null:
		_ceiling = GanglandCeiling.new(self)
	return _ceiling


func props() -> GanglandProps:
	if _props == null:
		_props = GanglandProps.new(self)
	return _props

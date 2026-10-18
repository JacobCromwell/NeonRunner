class_name MarketplaceSkin
extends ZoneSkin
## Zone 3, the Marketplace (GDD §5, §11): a bustling, happy open-air market at dusk, dustier and
## dirtier than the Neon City but in the same future (never historical: composite cladding, smart
## glass, roller shutters, air-conditioning units, dishes, antennas, drone racks, cables across the
## street, and the cult's feed on screens). Floor segments are rows of market-stall roofs and awnings
## (canvas, blue awnings, corrugated tin) with the market floor far below; gaps are the drops between
## the stalls, with the orange edge glow right on the collision edge. Walls are shopfronts and
## casinos: sun-bleached stucco with a row of lit shop windows at the low part of the wall (where the
## Marketplace citizens play, task D3: see shop_windows()), a calm band above them, and busy upper
## floors with shutters, awnings and decorative signs. Signs are shop signs in the yellow/black hazard
## frame; decorative signs are never framed and never below `decor_min_height`, so they can't be
## mistaken for hazard signs. Some shop windows hold a Marketplace citizen (task D3, MarketCitizens,
## scripts/world/skins/marketplace/): scenery only, warm and lit, never a window cyborg's dark glass.
## Electric fences are the same pink field, strung between poles standing
## in market crates. Ceilings are the undersides of buildings bridging the street, overpasses running
## along it, a few merchant ships and floating advertisements, each built from the lanes it covers.
## The stall roofs stand still, so dust, paper scraps and speed streaks, the seams between stalls and
## the bunting overhead carry the sense of speed (GDD §5, proposed).
## The cult's emblem (GDD §5: the owner's choice, drawn by CultEmblem) hides in plain sight: small
## and incidental on some floating ads, ad boards, casino signs and painted shop signs, never their
## main mark, in its warm-white neon or unlit bronze.
## Colour rule (GDD §5, proposed): blue awnings, red and orange goods and the like are lit, never
## glowing, and decorative lights keep to warm white, blue and violet, so the hazard colours (pink,
## yellow and black, red, orange, green, cyan) keep their meaning. Hazards stay the most saturated
## and brightest things on screen.
## Visuals only: TrackBuilder owns every collision shape and gameplay node, and all variety comes
## from hashing track positions (MeshKit.hash_i), so a chunk looks the same whenever it is built.

@export_group("Environment")
## DESIGN-TBD: the GDD gives the Marketplace's palette and mood but not its time of day. A warm,
## dusty dusk: the market's lights are on and the low sun gilds the upper floors of one side.
@export var sky_zenith_color: Color = Color(0.44, 0.47, 0.62)
@export var sky_horizon_color: Color = Color(0.86, 0.66, 0.5)
## Dust in the air near the horizon, lit by the setting sun.
@export var haze_color: Color = Color(0.9, 0.62, 0.42)
@export_range(0.0, 2.0, 0.05) var haze_strength: float = 0.6
@export var abyss_color: Color = Color(0.3, 0.24, 0.2)
@export var skyline_color: Color = Color(0.5, 0.43, 0.44)
@export var skyline_window_color: Color = Color(0.62, 0.52, 0.47)
## A pale early moon, off to one side of the street (radius in radians; 0 = none).
@export var moon_color: Color = Color(0.92, 0.9, 0.86)
@export var moon_direction: Vector3 = Vector3(-0.42, 0.42, -0.8)
@export_range(0.0, 0.3, 0.005) var moon_radius: float = 0.03
@export_range(0.0, 1.0, 0.01) var moon_clarity: float = 0.45
@export var ambient_color: Color = Color(0.85, 0.75, 0.66)
## Distant geometry fades into dusty air between fog_begin and fog_end (a light dust haze).
@export var fog_color: Color = Color(0.7, 0.58, 0.47)
@export_range(0.0, 150.0, 1.0, "suffix:m") var fog_begin: float = 14.0
@export_range(50.0, 400.0, 5.0, "suffix:m") var fog_end: float = 190.0
@export_range(0.0, 1.0, 0.01) var fog_max: float = 1.0
@export_range(0.0, 2.0, 0.05) var glow_intensity: float = 0.7
@export_range(0.5, 4.0, 0.05) var glow_threshold: float = 1.1
## Brightness of emissive kit parts (vertex glow 1.0 = this many times the albedo).
@export_range(1.0, 20.0, 0.5) var emissive_scale: float = 4.0
## Dusk sky caught at grazing angles by roofs, awnings and hulls.
@export var sheen_color: Color = Color(0.56, 0.42, 0.34)
@export_range(0.0, 1.0, 0.01) var sheen_strength: float = 0.14
## The low sun on the upper floors of the left-hand buildings; the street below is in shade.
@export var sun_color: Color = Color(1.0, 0.74, 0.48)
@export_range(0.0, 1.5, 0.05) var sun_strength: float = 0.7
@export_range(2.0, 30.0, 0.5, "suffix:m") var sun_line: float = 9.5

@export_group("Stalls")
## Stall roofs sit on a grid of slots along each lane; a stall covers 1–3 slots.
@export_range(1.0, 4.0, 0.1, "suffix:m") var stall_slot: float = 2.0
## DESIGN-TBD: how far below the stall roofs the market floor lies (deeper than the fall that ends a
## run, so a fall never visibly lands).
@export_range(4.5, 15.0, 0.1, "suffix:m") var market_depth: float = 6.5
## Canvas roofs: tan, sand, cream and off-white.
@export var canvas_colors: PackedColorArray = PackedColorArray([
	Color(0.52, 0.43, 0.32), Color(0.57, 0.48, 0.36), Color(0.61, 0.55, 0.44), Color(0.64, 0.6, 0.53)])
## Blue awnings (GDD §5): lit, never glowing, and deeper than the anti-grav pads' cyan.
@export var awning_colors: PackedColorArray = PackedColorArray([
	Color(0.2, 0.29, 0.46), Color(0.28, 0.36, 0.52)])
## The pale stripes on striped awnings.
@export var awning_stripe_color: Color = Color(0.74, 0.72, 0.66)
@export var tin_color: Color = Color(0.47, 0.46, 0.44)
## Share of stalls under a blue awning and under corrugated tin (the rest are canvas).
@export_range(0.0, 1.0, 0.01) var awning_share: float = 0.22
@export_range(0.0, 1.0, 0.01) var tin_share: float = 0.2
## The frame poles across the stalls and the valleys along the lanes.
@export var seam_color: Color = Color(0.4, 0.34, 0.27)
## Dust and wear (GDD §5: dustier and dirtier than the Neon City): the sand settling on roofs,
## awnings and ledges, and how worn the whole market looks (0 fresh paint, 1 as designed).
@export var dust_tint: Color = Color(0.74, 0.67, 0.56)
@export_range(0.0, 1.5, 0.05) var wear: float = 1.0
## The ledge between the outer lanes and the building faces.
@export var ledge_color: Color = Color(0.5, 0.45, 0.38)
## Everything under the stall roofs (stall faces, building faces, the market floor), seen only
## through gaps: deep shade at the roofs' level, darker below, so a gap reads as a hole at a glance.
## Kept far darker than any roof (tests/suites/test_marketplace_skin.gd).
@export var gap_inside_color: Color = Color(0.11, 0.095, 0.08)
## The festoon bulbs strung across the street: warm white, well away from the orange of gap edges.
@export var lamp_color: Color = Color(1.0, 0.88, 0.7)
## Gap edges: the orange edge language of every zone. Redder than it looks: the glow and the
## tonemapper lift the green, and it must stay orange, not sign yellow.
@export var gap_edge_color: Color = Color(1.0, 0.25, 0.04)

@export_group("Motion")
## DESIGN-TBD: GDD §5 proposes motion effects for still floors. Per 40 m of track: dust motes, paper
## scraps and speed streaks drifting toward the player (a = opacity).
@export_range(0, 200, 1) var dust_count: int = 80
@export_range(0, 60, 1) var scrap_count: int = 5
@export_range(0, 60, 1) var streak_count: int = 12
@export var dust_color: Color = Color(0.78, 0.7, 0.58, 0.32)
@export var scrap_color: Color = Color(0.72, 0.68, 0.6, 0.6)
@export var streak_color: Color = Color(0.9, 0.86, 0.78, 0.22)
@export_range(0.0, 30.0, 0.5, "suffix:m/s") var dust_speed: float = 5.0
@export_range(0.0, 80.0, 0.5, "suffix:m/s") var streak_speed: float = 24.0
## DESIGN-TBD: strings of pennants and festoon lights across the street, high above the ceilings.
@export_range(10.0, 120.0, 1.0, "suffix:m") var bunting_spacing: float = 34.0
@export_range(8.0, 30.0, 0.5, "suffix:m") var bunting_height: float = 13.5
@export var pennant_colors: PackedColorArray = PackedColorArray([
	Color(0.82, 0.8, 0.74), Color(0.24, 0.38, 0.66), Color(0.62, 0.36, 0.3), Color(0.44, 0.36, 0.6),
	Color(0.72, 0.64, 0.5)])

@export_group("Buildings")
@export_range(8.0, 60.0, 1.0, "suffix:m") var building_min_height: float = 12.0
@export_range(10.0, 120.0, 1.0, "suffix:m") var building_max_height: float = 30.0
## Buildings are 1–3 lots long; a lot is this long.
@export_range(6.0, 40.0, 1.0, "suffix:m") var lot_length: float = 13.0
## Sun-bleached stucco: sand, cream, whitewash, ochre, a pale blue-grey and a pale terracotta.
@export var stucco_colors: PackedColorArray = PackedColorArray([
	Color(0.62, 0.53, 0.42), Color(0.68, 0.62, 0.52), Color(0.72, 0.7, 0.65), Color(0.6, 0.5, 0.39),
	Color(0.54, 0.56, 0.57), Color(0.62, 0.48, 0.4)])
@export var trim_color: Color = Color(0.8, 0.77, 0.71)
## Window frames, piers, caps and conduits: pale anodised aluminium.
@export var window_metal_color: Color = Color(0.7, 0.72, 0.74)
## Frosted smart glass (windows in privacy mode).
@export var frost_color: Color = Color(0.62, 0.66, 0.7)
## Grime at the foot of the faces and in the streaks under the windows.
@export var grime_color: Color = Color(0.3, 0.26, 0.22)
## Roller shutters' paint (brushed metal, tinted): blue, dusty teal, bronze, grey. Lit, never glowing.
@export var shutter_colors: PackedColorArray = PackedColorArray([
	Color(0.3, 0.42, 0.6), Color(0.38, 0.5, 0.5), Color(0.52, 0.41, 0.31), Color(0.6, 0.58, 0.54)])
## The composite skirting panels of the plinth under the shop windows.
@export var plinth_color: Color = Color(0.46, 0.51, 0.57)
@export var plinth_light_color: Color = Color(0.74, 0.71, 0.64)
## DESIGN-TBD: the shop windows at the low part of the walls (GDD §5: citizens play there, task D3).
## The sill stays above the wall vents at the foot of the walls (sewer screeches, GDD §9.5).
@export_range(0.5, 1.5, 0.05, "suffix:m") var gallery_bottom: float = 0.85
@export_range(2.0, 3.5, 0.05, "suffix:m") var gallery_top: float = 2.8
## How deep the shop windows' displays reach into the buildings.
@export_range(0.3, 2.0, 0.05, "suffix:m") var shop_depth: float = 0.9
@export var window_warm_color: Color = Color(1.0, 0.9, 0.76)
@export_range(0.0, 3.0, 0.05) var window_glow: float = 0.75
## DESIGN-TBD: decorative signs, neon and lights never sit lower than this (the task plan: decorative
## signs stay unframed and high, above the wall-run band).
@export_range(6.0, 16.0, 0.25, "suffix:m") var decor_min_height: float = 8.0
## Decorative neon: kept away from the hazard colours (pink, yellow, orange, red, green, cyan).
@export var neon_colors: PackedColorArray = PackedColorArray([
	Color(0.62, 0.46, 1.0), Color(0.36, 0.55, 1.0), Color(0.92, 0.94, 1.0), Color(0.5, 0.42, 0.95)])
## Painted signs and boards high on the facades: lit, never glowing.
@export var painted_sign_colors: PackedColorArray = PackedColorArray([
	Color(0.22, 0.36, 0.62), Color(0.84, 0.8, 0.7), Color(0.56, 0.32, 0.28), Color(0.4, 0.32, 0.56),
	Color(0.26, 0.44, 0.5)])
## Casino lights: warm white bulbs, never gold (yellow belongs to signs).
@export var bulb_color: Color = Color(1.0, 0.9, 0.76)
@export_range(0.0, 1.0, 0.01) var casino_share: float = 0.2
@export_range(0.0, 1.0, 0.01) var hall_share: float = 0.15
## Faint lines on the facades at these heights, to read how high a wall run is.
@export var wall_height_marks: PackedFloat32Array = PackedFloat32Array([2.0, 4.0])
## DESIGN-TBD: dark, unlit paint on the Marketplace's light walls (the other zones' marks glow).
@export var wall_mark_color: Color = Color(0.36, 0.31, 0.26)

@export_group("Hazards")
## Pink crackle always means electric fence (GDD §5).
@export var fence_color: Color = Color(1.0, 0.18, 0.62)
@export var fence_pole_color: Color = Color(0.4, 0.39, 0.38)
@export var crate_color: Color = Color(0.46, 0.34, 0.23)
## Signs: the yellow/black hazard frame around a painted shop sign.
@export var sign_frame_color: Color = Color(1.0, 0.8, 0.15)
## Kept clear of the other hazard hues (pink, orange, cyan, green).
@export var sign_content_colors: PackedColorArray = PackedColorArray([
	Color(0.22, 0.38, 0.66), Color(0.84, 0.8, 0.7), Color(0.44, 0.34, 0.62), Color(0.26, 0.4, 0.58)])

@export_group("Ceilings")
## DESIGN-TBD: GDD §5 lists building and bridge undersides, overpasses, a few ships and floating ads;
## how often each appears is a proposal. Relative weights (a building bridging the street needs a
## ceiling across every lane; narrower ones become overpasses).
@export_range(0.0, 10.0, 0.1) var bridge_weight: float = 3.5
@export_range(0.0, 10.0, 0.1) var overpass_weight: float = 2.5
@export_range(0.0, 10.0, 0.1) var ship_weight: float = 1.5
@export_range(0.0, 10.0, 0.1) var ad_weight: float = 2.5
@export var soffit_color: Color = Color(0.5, 0.46, 0.41)
@export var concrete_color: Color = Color(0.52, 0.5, 0.47)
@export var girder_color: Color = Color(0.36, 0.37, 0.39)
@export var ship_hull_color: Color = Color(0.58, 0.55, 0.5)
## Tarps over the ships' cargo.
@export var cargo_colors: PackedColorArray = PackedColorArray([
	Color(0.22, 0.36, 0.6), Color(0.66, 0.58, 0.44), Color(0.56, 0.34, 0.28), Color(0.78, 0.76, 0.7)])
@export var engine_color: Color = Color(0.45, 0.6, 1.0)
@export var ad_frame_color: Color = Color(0.22, 0.22, 0.25)
## Ad screens: glowing, so kept to the decorative hues.
@export var ad_colors: PackedColorArray = PackedColorArray([
	Color(0.5, 0.4, 0.95), Color(0.3, 0.5, 0.95), Color(0.85, 0.88, 1.0)])
@export var ceiling_lamp_color: Color = Color(1.0, 0.9, 0.74)

@export_group("Cult emblem")
## Never smaller than this: tiny, its three-fold silhouette could read like the radiation trefoil.
@export_range(0.5, 3.0, 0.05, "suffix:m") var emblem_min_size: float = 0.9
## DESIGN-TBD: how often it hides in the market (GDD §5 proposes it in logos and ads in every zone).
## Share of floating ads, ad boards, casino signs and painted blade signs that carry it.
@export_range(0.0, 1.0, 0.01) var emblem_share: float = 0.4
## Glow of its warm-white neon on lit ads and signs.
@export_range(0.0, 1.5, 0.05) var emblem_glow: float = 0.6

@export_group("Cult feed")
## DESIGN-TBD: how often the cult's feed (CultFeed, GDD §5 "Cyborg Viewing Devices") plays in the
## market, alongside the ordinary ads: the share of billboards, casino signs and floating ad screens
## showing it. The shop windows hold no feed TV (the owner, October 17, 2026): see "Window displays".
@export_range(0.0, 1.0, 0.01) var feed_share: float = 0.35
## Brightness of the feed (0-1): full on billboards, low on the walls where the player runs.
@export_range(0.0, 1.0, 0.05) var feed_board_brightness: float = 1.0

@export_group("Window displays")
## DESIGN-TBD (docs/questions/l10.md; GDD §5 "Cyborg Viewing Devices", the owner, October 17, 2026: the old CRT feed
## TVs "don't really add much", so some shop windows get screens playing random ads, with the cult emblem flashing
## on them every once in a while, and others billboards that fit the world). The share of shop windows holding
## either (the TVs' 0.22), and how many of those are ad screens (the rest are lit posters). MarketCitizens skips
## every one of them, and so does a window cyborg's window (MarketFacades.display_of()).
@export_range(0.0, 1.0, 0.01) var window_display_share: float = 0.22
@export_range(0.0, 1.0, 0.01) var window_screen_share: float = 0.5
## An ad screen's glow (COLOR.a: how many times its albedo, at the emissive scale). 0.28 puts its brightest parts
## where the old TV's feed peaked, so it costs the bloom pass no more.
@export_range(0.0, 1.0, 0.01) var window_screen_glow: float = 0.28
## The dark frame of every panel, screens and posters (lit, never glowing).
@export var window_frame_color: Color = Color(0.13, 0.12, 0.14)
## How far a panel is turned toward the runner's approach (degrees from the wall's plane): a panel parallel to
## the wall is seen almost edge-on from the lanes.
@export_range(0.0, 45.0, 1.0, "suffix:deg") var window_screen_turn: float = 28.0
## The ads' colours (shader wd_palette; glowing, so only the decorative hues: blue to violet, warm white): blue, violet,
## deep indigo (backgrounds), warm white, pale blue-white (the drawn things), lavender (accents).
@export var window_ad_colors: PackedColorArray = PackedColorArray([
	Color(0.3, 0.5, 0.95), Color(0.5, 0.4, 0.95), Color(0.22, 0.26, 0.66), Color(1.0, 0.93, 0.82),
	Color(0.85, 0.88, 1.0), Color(0.78, 0.62, 0.92)])
## The posters' paint: lit, never glowing, and (the colour rule) never a hazard hue (no red, orange, yellow, green,
## cyan or pink): blues, violets, slate and mauve with a cream.
@export var window_poster_colors: PackedColorArray = PackedColorArray([
	Color(0.22, 0.36, 0.62), Color(0.44, 0.34, 0.62), Color(0.26, 0.4, 0.58), Color(0.84, 0.8, 0.7),
	Color(0.32, 0.42, 0.46), Color(0.56, 0.44, 0.54)])
## How long an ad stays up before the next, in seconds (each screen picks its own between these).
@export var ad_scene_time: Vector2 = Vector2(5.0, 7.5)
## Seconds between the cult emblem's flashes on one screen (each screen picks its own, from its window's position,
## and its own moment in the cycle, so no two flash together): the shortest and the longest.
@export var emblem_flash_period: Vector2 = Vector2(14.0, 26.0)
## One flash, in seconds: fading in, held and fading out. Never a hard cut, and one flash is a single event,
## never faster than about a third of a second. With Reduced flashing the slower, steadier one: the emblem
## fades in over most of a second and stays up for two.
@export var emblem_flash_times: Vector3 = Vector3(0.22, 1.1, 0.55)
@export var emblem_flash_times_reduced: Vector3 = Vector3(0.9, 2.0, 0.9)

@export_group("Doodads")
## The nice plants' pot (GDD §3, task G6: the owner's "plenty of nice plants") and their foliage, kept
## well apart from the ramps' and speed pads' hazard green.
@export var doodad_pot_color: Color = Color(0.56, 0.42, 0.33)
@export var doodad_plant_colors: PackedColorArray = PackedColorArray([
	Color(0.3, 0.38, 0.28), Color(0.36, 0.44, 0.3), Color(0.26, 0.33, 0.24)])
## The casino machines' cabinets (GDD §3: the owner's "casino machines") and their dim screen face,
## in the Marketplace's own casino-light white, never the bright glow of a real screen.
@export var doodad_cabinet_colors: PackedColorArray = PackedColorArray([
	Color(0.24, 0.18, 0.15), Color(0.2, 0.22, 0.27)])
@export var doodad_cabinet_trim_color: Color = Color(0.62, 0.52, 0.3)
@export var doodad_screen_color: Color = Color(0.48, 0.46, 0.42)

@export_group("Pads, ramps, finish")
@export var pad_color: Color = Color(0.1, 1.0, 0.95)
## Height of the anti-grav pad's light column.
@export_range(1.0, 10.0, 0.1, "suffix:m") var pad_beam_height: float = 5.8
@export var ramp_color: Color = Color(0.3, 1.0, 0.35)
## Speed pads share the ramps' green "safe boost" family (MeshKit.speed_strip; FB 49).
@export var speed_pad_color: Color = Color(0.45, 1.0, 0.55)
@export var finish_color: Color = Color(1.0, 1.0, 1.0)
## Painted steel under pads, ramps and the finish gantry.
@export var market_metal_color: Color = Color(0.3, 0.28, 0.26)

const CULT_EMBLEM_CHOICE_PATH: String = "res://data/world/cult_emblem_choice.tres"

## Built on first use and shared by every mesh (exports changed later don't reach them).
var _materials: Dictionary = {}
var _emblems: Dictionary = {}
var _stalls: MarketStalls
var _facades: MarketFacades
var _ceilings: MarketCeilings
var _props: MarketProps
var _citizens: MarketCitizens
var _doodads: MarketDoodads
var _dash_walls: MarketDashWall
## The latest wall face seen (wall_section runs before a chunk's ceilings): a building bridging the
## street reaches from wall to wall.
var _wall_x: float = 0.0
## Window cyborgs due in the chunk now building, by side (note_wall_enemies(), task D3): their
## track distance, so the citizens never share a window with one (GDD §9.2).
var _reserved: Dictionary = {-1: PackedFloat32Array(), 1: PackedFloat32Array()}
## Each side's wall gaps near the wall being drawn (note_wall_gaps).
var _wall_gaps: Dictionary = {}


func _init() -> void:
	# The cyborgs wear the Casino Mob Enforcer (GDD §9.2, CyborgSuit.look_for); the other enemies treat
	# any variant but &"scavenger" like &"city", so their look is the clean one it was.
	enemy_variant = &"casino"


func make_environment() -> Environment:
	var sky := {"zenith_color": sky_zenith_color, "horizon_color": sky_horizon_color, "haze_color": haze_color,
		"haze_strength": haze_strength, "haze_height": 0.14, "abyss_color": abyss_color, "skyline_color": skyline_color,
		"window_color": skyline_window_color, "moon_color": moon_color, "moon_direction": moon_direction,
		"moon_radius": moon_radius, "moon_clarity": moon_clarity, "star_amount": 0.0}
	return MeshKit.night_environment(sky, ambient_color, fog_color, fog_begin, fog_end, fog_max, 0.0,
		glow_intensity, glow_threshold)


func floor_segment(parent: Node3D, center: Vector3, size: Vector3, lane_x: float,
		edge_start: bool, edge_end: bool) -> void:
	var batch := MeshBatch.new()
	stalls().build(batch, center, size, lane_x, edge_start, edge_end)
	batch.commit(parent)


## A floor cut (ZoneSkin.floor_cut; task B4, H3): the stall roofs sliced open down the lane, and through
## it what any gap shows (GDD §9.9): the stalls' sides in their deep shade down the neighbouring lanes
## (their own, drawn with their roofs) and the market floor `market_depth` down, lost in the shade (the
## chunk draws it with the left wall). The cut draws only its two end faces, in the gap's own shade and
## pattern (MarketStalls, PAT_UNDER), and no walls and no bottom.
func floor_cut(parent: Node3D, cut: FloorCutSection) -> void:
	standard_floor_cut(parent, cut, solid_material(), glow_material(), {
		"edge": gap_edge_color, "inside": gap_inside_color, "pattern": MeshKit.PAT_UNDER, "params": [0.0, 1.0, 2.0],
		"depth": market_depth, "bottom": false, "walls": false,
	})


func wall_section(parent: Node3D, side: int, face_x: float, start: float, end: float) -> void:
	_wall_x = absf(face_x)
	var batch := MeshBatch.new()
	facades().build(batch, side, face_x, start, end)
	if side < 0:
		stalls().below(batch, absf(face_x), start, end)
		facades().overhead(batch, absf(face_x), start, end)
	batch.commit(parent)
	citizens().build(parent, side, face_x, start, end)


## With the left wall of a wall gap (ZoneSkin.wall_gap_extras), the stalls below (no lines strung from a missing wall).
func wall_gap_extras(batch: MeshBatch, side: int, face_x: float, start: float, end: float) -> void:
	_wall_x = absf(face_x)
	if side < 0:
		stalls().below(batch, absf(face_x), start, end)


## What a wall gap shows behind it (ZoneSkin.wall_gap_recess, task L4): an alley between the two buildings it cuts,
## their end faces in their own colours and window grids, the face across, the market floor (MarketFacades.recess).
func wall_gap_recess(batch: MeshBatch, side: int, face_x: float, start: float, end: float, gap: Vector2) -> void:
	facades().recess(batch, side, face_x, start, end, gap)


## The wall gaps near the wall TrackBuilder is about to draw (ZoneSkin hook): a shop window reaching
## into one is left out (MarketFacades), its pier running on instead, so no window floats in a gap.
func note_wall_gaps(side: int, gaps: Array[Vector2]) -> void:
	_wall_gaps[side] = gaps


## True if a wall gap on `side` (note_wall_gaps) overlaps the stretch [from, to].
func wall_gap_near(side: int, from: float, to: float) -> bool:
	for g: Vector2 in _wall_gaps.get(side, [] as Array[Vector2]):
		if g.x < to and g.y > from:
			return true
	return false


## The window cyborgs TrackBuilder is about to build on `side` in [start, end) (ZoneSkin hook, task
## D3): kept so citizens() never places one in a window a window cyborg stands in.
func note_wall_enemies(side: int, _start: float, _end: float, enemies: Array[Dictionary]) -> void:
	var spans := PackedFloat32Array()
	for e: Dictionary in enemies:
		if String(e.get("type", "")) == "window_cyborg" and int(e.get("side", 0)) == side:
			spans.append(float(e.get("at", 0.0)))
	_reserved[side] = spans


## True if a window cyborg on `side` stands within `margin` of track distance `at` (MarketCitizens).
func reserved_near(side: int, at: float, margin: float) -> bool:
	for a: float in _reserved.get(side, PackedFloat32Array()):
		if absf(a - at) <= margin:
			return true
	return false


func fence(hazard: Hazard, size: Vector3, ground_y: float, gapped: bool) -> void:
	props().fence(hazard, size, ground_y, gapped)


func wall_sign(hazard: Hazard, size: Vector3) -> void:
	props().wall_sign(hazard, size)


## A ceiling over its lanes, reaching to the wall faces where the section says they are
## (MarketCeilings: only a ceiling across every lane becomes a building bridging the street; over
## fewer lanes, a narrow ceiling (GDD §3), it builds narrower).
func ceiling_section(parent: Node3D, section: CeilingSection) -> void:
	ceilings().build(parent, section.center, section.size, section.lane_edges_x, section.wall_x)


## A ceiling given as its box alone (the wall faces from the chunk's walls).
func hull(parent: Node3D, center: Vector3, size: Vector3, lane_edges_x: Array[float]) -> void:
	ceilings().build(parent, center, size, lane_edges_x, _wall_x if _wall_x > 0.0 else size.x * 0.5 + 0.3)


func pad(trigger: Area3D, size: Vector3) -> void:
	MeshBatch.add_instance(trigger, MeshKit.lift_pad(size, pad_color, market_metal_color, pad_beam_height,
		solid_material(), glow_material()))


func ramp(trigger: Area3D, size: Vector3, side: int) -> void:
	MeshBatch.add_instance(trigger, MeshKit.kicker_ramp(size, side, ramp_color, market_metal_color, solid_material(),
		glow_material()))


func speed_pad(trigger: Area3D, size: Vector3) -> void:
	MeshBatch.add_instance(trigger, MeshKit.speed_strip(size, speed_pad_color, market_metal_color, solid_material(),
		glow_material()))


func finish_line(parent: Node3D, width: float, distance: float) -> void:
	var batch := MeshBatch.new()
	MeshKit.finish_gate(batch, solid_material(), glow_material(), width, distance, finish_color, market_metal_color)
	batch.commit(parent)


## A dash wall (task H7b): a shopfront across the market, built from the walls' own kit (MarketDashWall): the
## plinth, shop windows with their displays, piers, shuttered stucco storeys, a cornice.
func dash_wall(body: Node3D, size: Vector3, look_seed: int) -> void:
	DashWallKit.dress(body, dash_walls().mesh_for(size, look_seed))


## The surfaces a Marketplace dash wall draws with: the shopfront shader and the solid kit.
func dash_wall_materials() -> Array[Material]:
	return [solid_material(), facade_material()]


## A dash wall's default look colours (ZoneSkin.dash_wall, task H7a) in the Marketplace's own facades: sun-bleached
## stucco, its pale trim, dark glass and earthy cracks. Kept as the palette the debris falls back on.
func dash_wall_colors() -> PackedColorArray:
	return PackedColorArray([stucco_colors[0], trim_color, Color(0.12, 0.13, 0.15), Color(0.22, 0.17, 0.13)])


## A potted plant (small), a bank of casino machines (medium) or a planted hedge row (large): MarketDoodads.
func doodad(body: Node3D, size: Vector3, size_class: StringName, side: int, look_seed: int) -> void:
	doodads().build(body, size, size_class, side, look_seed)


## The shop windows at the low part of the wall on `side` (face at face_x) whose centres lie between
## two track distances: the hook for the Marketplace citizens (task D3, GDD §5), who play inside
## them. The same windows wall_section() builds, computed from track positions alone, so they can be
## asked for before or after a chunk exists. Each entry:
##   side      -1 left wall, +1 right wall
##   at        track distance of the window's centre
##   center    world position of the window's centre, on the glass (the wall face)
##   width     along the track; height: from `bottom` to `top` (world y)
##   depth     how far the display reaches into the building (inside is face_x + side * depth)
##   kind      &"shop", &"casino" or &"hall"
##   screen    true if the window holds an ad screen or a poster (task L10): a panel hung in it, so no
##             citizen stands there (MarketCitizens skips it)
##   display   what it holds: &"ad" (a screen playing ads, flashing the cult's emblem now and then), &"poster"
##             (a lit shop sign, sale, menu or product) or &"" (nothing)
## Anything standing inside faces the lanes (toward -side on x). Hazards on the wall (signs, window
## cyborgs, wall fences, vents) are the layout's business: the skin doesn't know where they are.
func shop_windows(side: int, face_x: float, start: float, end: float) -> Array[Dictionary]:
	return facades().windows(side, face_x, start, end)


# --- The cult's feed ------------------------------------------------------------------------

## The shared feed material (CultFeed): the same broadcast as in every zone.
func feed_material() -> ShaderMaterial:
	return CultFeed.material()


## Whether the screen keyed by (a, b) plays the cult's feed instead of an ad (feed_share of them).
func shows_feed(a: int, b: int) -> bool:
	return MeshKit.hash01(a, b, 131) < feed_share


## The billboards on the walls playing the feed (roof boards and casino signs) whose middles lie
## between two track distances, for reviews and tests: side, at, center (the screen's middle), width,
## height, kind (&"roof_board" or &"casino"). The same ones wall_section() builds.
func feed_boards(side: int, face_x: float, start: float, end: float) -> Array[Dictionary]:
	return facades().feed_boards(side, face_x, start, end)


# --- The cult's emblem ----------------------------------------------------------------------

## The cult's emblem 1 m across, centred on the origin and facing +Z, as a mesh-kit template for the
## solid material: `neon` in its warm-white neon (for lit ads and signs), otherwise unlit bronze.
## The option and colours come from the owner's choice (data/world/cult_emblem_choice.tres) and
## CultEmblem.default_scheme(), never hardcoded here. Empty if the choice can't be loaded.
func cult_emblem(neon: bool) -> MeshLayer:
	if _emblems.has(neon):
		return _emblems[neon]
	var t := MeshLayer.new()
	var choice := load(CULT_EMBLEM_CHOICE_PATH) as CultEmblemChoice
	if choice != null:
		var scheme: Dictionary = CultEmblem.default_scheme(choice.option)
		var mesh: ArrayMesh = CultEmblem.build_mesh(choice.option, 1.0, scheme["neon" if neon else "metal"],
			scheme["neon_accent" if neon else "metal_accent"], emblem_glow if neon else 0.0, solid_material())
		var arrays: Array = mesh.surface_get_arrays(0)
		t.verts = arrays[Mesh.ARRAY_VERTEX]
		t.colors = arrays[Mesh.ARRAY_COLOR]
		t.uvs = arrays[Mesh.ARRAY_TEX_UV]
		t.uv2s = arrays[Mesh.ARRAY_TEX_UV2]
	_emblems[neon] = t
	return t


## Adds the cult's emblem `size` metres across (never below emblem_min_size) to a solid-material
## layer, centred at `at` and facing `facing` (+Z toward the approaching player, ±X toward the track).
func add_cult_emblem(layer: MeshLayer, at: Vector3, facing: Vector3, size: float, neon: bool) -> void:
	var e: float = maxf(size, emblem_min_size)
	layer.append(cult_emblem(neon), Transform3D(Basis(Vector3.UP, atan2(facing.x, facing.z)).scaled(Vector3.ONE * e), at))


## Whether the ad, sign or logo keyed by (a, b) carries the cult's emblem (emblem_share of them).
func carries_emblem(a: int, b: int) -> bool:
	return MeshKit.hash01(a, b, 97) < emblem_share


# --- Shared materials (built once per skin, shared by every mesh) ------------------------

func solid_material() -> ShaderMaterial:
	if not _materials.has(&"solid"):
		var m: ShaderMaterial = MeshKit.solid(_solid_params())
		# The emblem's coverage the window screens flash (MeshKit.PAT_WINDOW_AD; the owner's pick, drawn by CultEmblem).
		m.set_shader_parameter(&"cult_emblem", CultFeed.emblem_texture())
		_materials[&"solid"] = m
	return _materials[&"solid"]


func glow_material() -> ShaderMaterial:
	if not _materials.has(&"glow"):
		_materials[&"glow"] = MeshKit.glow({"fade_begin": fog_begin, "fade_end": fog_end})
	return _materials[&"glow"]


## The building faces (shopfront.gdshader).
func facade_material() -> ShaderMaterial:
	if not _materials.has(&"facade"):
		_materials[&"facade"] = MeshKit.material("shopfront.gdshader", {
			"trim_color": trim_color, "shutter_a": shutter_colors[0], "shutter_b": shutter_colors[1],
			"shutter_c": shutter_colors[2], "shutter_d": shutter_colors[3], "window_warm": window_warm_color,
			"window_glow": window_glow, "sheen_color": sheen_color, "sheen_strength": sheen_strength,
			"sun_color": sun_color, "sun_strength": sun_strength, "sun_line": sun_line, "plinth_color": plinth_color,
			"plinth_light": plinth_light_color, "plinth_top": gallery_bottom, "metal_color": window_metal_color,
			"frost_color": frost_color, "grime_color": grime_color, "grime": wear,
			"bulb_color": bulb_color, "neon_a": neon_colors[0], "neon_b": neon_colors[1],
			"storey_base": gallery_top + 0.2, "storey": MarketFacades.STOREY, "calm_top": decor_min_height - 1.0,
			"decor_top": decor_min_height})
	return _materials[&"facade"]


func drift_material() -> ShaderMaterial:
	if not _materials.has(&"drift"):
		_materials[&"drift"] = MeshKit.material("drift.gdshader", {
			"slice_length": TrackBuilder.CHUNK_LENGTH, "ash_speed": dust_speed, "streak_speed": streak_speed})
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
	# The stall rows' layout and palette (PAT_STALLS), exactly as MarketStalls reads them.
	var canvas := PackedVector3Array()
	for i: int in 4:
		var c: Color = canvas_colors[i % canvas_colors.size()]
		canvas.append(Vector3(c.r, c.g, c.b))
	var awnings := PackedVector3Array()
	for i: int in 2:
		var c: Color = awning_colors[i % awning_colors.size()]
		awnings.append(Vector3(c.r, c.g, c.b))
	var params: Dictionary = {"glow_scale": emissive_scale, "sheen_color": sheen_color, "sheen_strength": sheen_strength,
		"canvas_stripe": awning_stripe_color, "canvas_pole": seam_color,
		"stall_slot": stall_slot, "stall_awning_share": awning_share, "stall_tin_share": tin_share,
		"stall_canvas": canvas, "stall_awning": awnings, "stall_tin": Vector3(tin_color.r, tin_color.g, tin_color.b),
		"market_dust": dust_tint, "market_dust_amount": wear}
	params.merge(window_display_params())
	return params


## The solid material's uniforms for the shop windows' ad screens (kit_window.gdshaderinc, task L10): the ads' palette
## (sRGB, as the shader wants it), the emblem's warm white, and the timing of the scenes and of the emblem's flash. The
## Casino merges these into its own.
func window_display_params() -> Dictionary:
	var palette := PackedVector3Array()
	for i: int in 6:
		var c: Color = window_ad_colors[i % window_ad_colors.size()]
		palette.append(Vector3(c.r, c.g, c.b))
	var emblem: Color = CultFeed.emblem_color()
	return {"wd_palette": palette, "wd_emblem": Vector3(emblem.r, emblem.g, emblem.b),
		"wd_flash_period": emblem_flash_period, "wd_flash": emblem_flash_times,
		"wd_flash_reduced": emblem_flash_times_reduced, "wd_scene_time": ad_scene_time}


func dash_walls() -> MarketDashWall:
	if _dash_walls == null:
		_dash_walls = MarketDashWall.new(self)
	return _dash_walls


func stalls() -> MarketStalls:
	if _stalls == null:
		_stalls = MarketStalls.new(self)
	return _stalls


func facades() -> MarketFacades:
	if _facades == null:
		_facades = MarketFacades.new(self)
	return _facades


func ceilings() -> MarketCeilings:
	if _ceilings == null:
		_ceilings = MarketCeilings.new(self)
	return _ceilings


func props() -> MarketProps:
	if _props == null:
		_props = MarketProps.new(self)
	return _props


func citizens() -> MarketCitizens:
	if _citizens == null:
		_citizens = MarketCitizens.new(self)
	return _citizens


## One citizen for the shader warm-up (ShaderWarmup, task PERF1, calls this on a skin that has it): the people's mesh and
## shader drawn once while the level loads, so the Compatibility renderer doesn't compile them the first time a window
## with a citizen comes into view mid-run.
func warm_samples(parent: Node3D) -> void:
	if Settings.citizens_enabled:
		citizens().spawn(parent, [MarketCitizens.sample_person()] as Array[Dictionary])


func doodads() -> MarketDoodads:
	if _doodads == null:
		_doodads = MarketDoodads.new(self)
	return _doodads

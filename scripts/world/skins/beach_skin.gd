class_name BeachSkin
extends ZoneSkin
## The Beach (task D10, the owner's request of October 9, 2026; not in the campaign yet: its slot is
## undecided): a cyberpunk party strip on the shore, in the same future as every zone (GDD §5), inspired
## by docs/art/reference/beach_zone.jpg: a sandy street with footprints running down to a turquoise sea
## and a palm-covered island on the horizon, between low bamboo-walled tiki bars, surf shops and lounges
## under thatch, with decks and verandas, tiki masks, surfboards, paper lanterns, bunting and strings of
## lights, and black rust-streaked industrial tanks, chimneys and dishes rising behind them (the
## cyberpunk touch), palm trees between. A bright tropical afternoon.
## Floors are sand with boardwalk runs (BeachSand): weathered planks with rusty bolted steel plates over
## stretches of some lanes. Gaps are POOLS (the owner's decision): deep black steel pool tanks sunk flush
## in the sand, their dark water far below the floor, deeper than a fall that ends a run; the orange edge
## language sits right on the collision edge as in every zone, with a dark steel coping beside it so it
## pops against the bright sand.
## Walls (BeachShacks) are shacks 1-3 lots long and two to four storeys: bamboo, palm mats, planks and
## rusty corrugated sheets in the calm band (flush, closed, with the wall-run marks), thatched roofs,
## recessed verandas, tiki masks, surfboards, paper lanterns, wordless neon silhouettes and strings of
## lights above it; palms and black steel tanks behind. Ceilings (BeachCeilings): a boardwalk footbridge
## between the upper verandas, a veranda deck cantilevered from the building it reaches, or a hovering
## party barge. Signs are the yellow/black hazard frame around a painted surf or bar sign; fences the
## same pink field between bamboo-wrapped steel posts in sand-filled drums.
## Colour rule (GDD §5; the reference's glowing turquoise water and its pink, yellow, cyan, green and
## orange neon are overruled, docs/questions/d10.md): the water never glows, decorative glows are warm
## white, violet and blue only, and every paint is muted and unlit, so only hazards glow in hazard
## colours. The cult hides its emblem on neon signs, billboards and the barge's hull, and its feed plays
## on TVs behind some upper-deck bars and on some roof billboards, never in the wall-run band.
## Visuals only: TrackBuilder owns every collision shape and gameplay node, and all variety comes from
## hashing track positions (MeshKit.hash_i), so a chunk looks the same whenever it is built.

@export_group("Environment")
## DESIGN-TBD (docs/questions/d10.md): the GDD gives no time of day for the Beach. The reference's bright
## tropical afternoon: a blue sky with white cumulus, a turquoise sea and a low palm island on the horizon
## down the street, warm sunlight. Daylight is a risk for the game's look: the sky stays under the glow
## threshold and the sand mid-bright, so neon and hazards still bloom and stay the brightest things.
@export var sky_zenith_color: Color = Color(0.13, 0.40, 0.80)
@export var sky_horizon_color: Color = Color(0.64, 0.82, 0.92)
@export var haze_color: Color = Color(0.94, 0.96, 0.98)
@export_range(0.0, 2.0, 0.05) var haze_strength: float = 0.2
## The sea below the horizon, beyond the end of the street: a muted turquoise.
@export var abyss_color: Color = Color(0.12, 0.46, 0.50)
## The island on the horizon: a low green-grey silhouette (the sky's far skyline, with no lit windows).
@export var skyline_color: Color = Color(0.28, 0.46, 0.44)
## The warm glow of the sun toward the far end of the street, and the white cumulus over it.
@export var sun_glow_color: Color = Color(1.0, 0.92, 0.72)
@export_range(0.0, 1.0, 0.01) var sun_glow_strength: float = 0.2
@export var sun_glow_direction: Vector3 = Vector3(0.35, 0.0, -0.94)
@export_range(0.0, 1.0, 0.01) var cloud_amount: float = 0.4
@export_range(0.5, 3.0, 0.05) var cloud_scale: float = 1.3
@export var cloud_color: Color = Color(0.94, 0.95, 0.97)
@export var cloud_lit_color: Color = Color(1.0, 0.96, 0.88)
@export var ambient_color: Color = Color(0.8, 0.82, 0.88)
## Distant geometry fades into the sea haze between fog_begin and fog_end.
@export var fog_color: Color = Color(0.74, 0.87, 0.94)
@export_range(0.0, 150.0, 1.0, "suffix:m") var fog_begin: float = 34.0
@export_range(50.0, 400.0, 5.0, "suffix:m") var fog_end: float = 250.0
@export_range(0.0, 1.0, 0.01) var fog_max: float = 0.9
@export_range(0.0, 2.0, 0.05) var glow_intensity: float = 0.75
@export_range(0.5, 4.0, 0.05) var glow_threshold: float = 1.2
## Brightness of emissive kit parts (vertex glow 1.0 = this many times the albedo).
@export_range(1.0, 20.0, 0.5) var emissive_scale: float = 4.0
## The sky caught at grazing angles by the roofs and undersides.
@export var sheen_color: Color = Color(0.72, 0.84, 0.92)
@export_range(0.0, 1.0, 0.01) var sheen_strength: float = 0.1

@export_group("Sand and boardwalk")
## The sand: warm tan, mid-bright rather than white (a pool beside it must read against it), with its
## light and dark drifts, flat shells and pebbles (drawn, never built).
@export var sand_color: Color = Color(0.70, 0.58, 0.41)
@export var sand_light_color: Color = Color(0.82, 0.72, 0.54)
@export var sand_dark_color: Color = Color(0.58, 0.47, 0.32)
@export var shell_color: Color = Color(0.84, 0.78, 0.68)
@export var pebble_color: Color = Color(0.42, 0.40, 0.37)
## Boardwalk runs: weathered planks laid across a lane with rusty steel plates bolted on, over stretches of
## some lanes (a slot of boardwalk_slot metres starts a run in boardwalk_share of the slots, one to three
## slots long, hashed by lane and slot so they line up across chunk cuts).
@export var boardwalk_color: Color = Color(0.50, 0.38, 0.27)
@export var plank_gap_color: Color = Color(0.24, 0.17, 0.11)
@export var plate_color: Color = Color(0.38, 0.27, 0.19)
@export var rust_color: Color = Color(0.42, 0.22, 0.11)
@export_range(0.0, 1.0, 0.01) var boardwalk_share: float = 0.3
@export_range(4.0, 40.0, 0.5, "suffix:m") var boardwalk_slot: float = 12.0
## The flush bamboo kerb between the outer lanes and the building faces.
@export var kerb_color: Color = Color(0.62, 0.49, 0.30)

@export_group("Pools")
## DESIGN-TBD (docs/questions/d10.md): the owner's decision that gaps are pools of water. The pool tank is
## black and gunmetal steel with rust streaks, flush in the sand (the reference's tanks stand proud of it:
## a raised rim would read as an obstacle that isn't there), its water pool_depth below the floor, deeper
## than a fall that ends a run (MovementTuning.fall_death_depth, 4 m), so a fall never visibly lands. The
## water is a deep unlit teal, darker with depth, and NEVER glows (the reference's glowing turquoise is too
## close to the anti-grav pads' cyan): a pool reads as a hole like every gap.
@export_range(4.5, 12.0, 0.1, "suffix:m") var pool_depth: float = 6.0
## Everything under the floor, seen only through gaps: deep shade that only darkens with depth, kept far
## darker than any floor material (tests/suites/test_beach_skin.gd).
@export var gap_inside_color: Color = Color(0.06, 0.065, 0.075)
@export var tank_rust_color: Color = Color(0.20, 0.10, 0.06)
@export var tide_color: Color = Color(0.07, 0.12, 0.13)
@export var water_color: Color = Color(0.015, 0.055, 0.065)
## The steel coping beside a pool's orange lip, so the orange pops against the bright sand.
@export var coping_color: Color = Color(0.09, 0.095, 0.105)
## Gap edges: the orange edge language of every zone. Redder than it looks: the glow and the tonemapper
## lift the green, and it must stay orange, not sign yellow.
@export var gap_edge_color: Color = Color(1.0, 0.25, 0.04)

@export_group("Motion")
## The still floor's motion cues (the owner's review): per 40 m of track, sand blowing along the street,
## a few leaves and petals drifting, and speed streaks drifting toward the player (a = opacity).
@export_range(0, 200, 1) var sand_count: int = 60
@export_range(0, 60, 1) var leaf_count: int = 8
@export_range(0, 60, 1) var streak_count: int = 12
@export var sand_grain_color: Color = Color(0.90, 0.80, 0.60, 0.6)
@export var leaf_color: Color = Color(0.50, 0.50, 0.28, 0.85)
@export var streak_color: Color = Color(0.97, 0.95, 0.9, 0.22)
@export_range(0.0, 30.0, 0.5, "suffix:m/s") var sand_speed: float = 5.0
@export_range(0.0, 80.0, 0.5, "suffix:m/s") var streak_speed: float = 24.0

@export_group("Shacks")
## The kit lights a wall with its night-city factor; the Beach is in bright afternoon sun, so its upright lit
## surfaces (walls, thatch, timber) take this much more (a factor on their albedo).
@export_range(1.0, 1.6, 0.01) var daylight: float = 1.2
## Buildings are 1-3 lots long, a lot is this long; two to four storeys of storey_height. The wall-run
## band (the floor to band_top, with a margin over the wall run's highest point) is flush: bamboo, mats,
## planks, rusty sheets, shut shutters and hatches, flush posters, and the wall-run height marks.
## Decoration (thatch, verandas, masks, boards, lanterns, flags, lights) starts at decor_min_height.
@export_range(6.0, 40.0, 1.0, "suffix:m") var lot_length: float = 12.0
@export_range(3.0, 4.5, 0.05, "suffix:m") var storey_height: float = 3.6
@export_range(6.0, 9.0, 0.1, "suffix:m") var band_top: float = 7.2
@export_range(6.0, 16.0, 0.25, "suffix:m") var decor_min_height: float = 8.0
## Shares of the shacks with two, three and four storeys (the rest of a hash picks the four-storey ones).
@export_range(0.0, 1.0, 0.01) var low_share: float = 0.4
@export_range(0.0, 1.0, 0.01) var mid_share: float = 0.4
## Thatch roofs, recessed upper verandas (a bar with a counter and lanterns, a lounge) and the black
## steel industrial structures behind (tanks, water towers, chimneys, dishes), as a share of the shacks.
@export_range(0.0, 1.0, 0.01) var thatch_share: float = 0.7
@export_range(0.0, 1.0, 0.01) var veranda_share: float = 0.6
@export_range(0.0, 1.0, 0.01) var industry_share: float = 0.5
@export_range(0.0, 1.0, 0.01) var palm_share: float = 0.6
## The bamboo of the walls: honey, sun-greyed, pale, green-grey (sRGB, lit, never glowing).
@export var bamboo_colors: PackedColorArray = PackedColorArray([
	Color(0.78, 0.56, 0.26), Color(0.66, 0.56, 0.38), Color(0.80, 0.62, 0.36), Color(0.72, 0.58, 0.38)])
@export var bamboo_dark_color: Color = Color(0.34, 0.23, 0.11)
@export var thatch_color: Color = Color(0.68, 0.53, 0.26)
@export var thatch_dark_color: Color = Color(0.30, 0.23, 0.13)
@export var timber_color: Color = Color(0.45, 0.35, 0.25)
## Muted painted boards (teal, coral, mustard, sage, dusty blue), unlit.
@export var paint_colors: PackedColorArray = PackedColorArray([
	Color(0.33, 0.50, 0.52), Color(0.62, 0.42, 0.34), Color(0.62, 0.55, 0.34), Color(0.45, 0.50, 0.40), Color(0.36, 0.40, 0.55)])
@export var cream_color: Color = Color(0.86, 0.82, 0.70)
## The black rust-streaked industrial steel (tanks, water towers, chimneys, dishes).
@export var steel_color: Color = Color(0.095, 0.10, 0.11)
@export var steel_rust_color: Color = Color(0.30, 0.15, 0.08)
## Palm trunks and fronds: muted greens, far from the ramps' and speed pads' hazard green.
@export var trunk_color: Color = Color(0.46, 0.38, 0.28)
@export var frond_colors: PackedColorArray = PackedColorArray([
	Color(0.22, 0.34, 0.24), Color(0.27, 0.38, 0.25), Color(0.20, 0.31, 0.26)])
## The wall-run height marks (GDD §3: how high a wall run is): unlit paint at 2 m and 4 m.
@export var wall_height_marks: PackedFloat32Array = PackedFloat32Array([2.0, 4.0])
@export var wall_mark_color: Color = Color(0.22, 0.14, 0.08)

@export_group("Lights and signs")
## Decorative glows are warm white, violet and blue only (the reference's pink, yellow, cyan, green and
## orange neon are hazard hues): neon silhouette signs (a palm, a wave, a flamingo, a cocktail, a
## surfboard, the sun, a tiki totem; never words), the bulbs on strings of lights, and a paper lantern's
## warm-white glow inside its muted unlit shell.
@export var neon_violet: Color = Color(0.68, 0.42, 1.0)
@export var neon_blue: Color = Color(0.32, 0.45, 1.0)
@export var neon_white: Color = Color(1.0, 0.92, 0.78)
@export_range(0.0, 1.0, 0.01) var neon_glow: float = 0.5
@export var lamp_color: Color = Color(1.0, 0.9, 0.74)
@export_range(0.0, 1.5, 0.05) var lamp_glow: float = 0.7
@export var lantern_shell_colors: PackedColorArray = PackedColorArray([
	Color(0.62, 0.42, 0.34), Color(0.62, 0.55, 0.34), Color(0.33, 0.50, 0.52), Color(0.45, 0.50, 0.40)])
## Unlit flags and bunting.
@export var flag_colors: PackedColorArray = PackedColorArray([
	Color(0.62, 0.42, 0.34), Color(0.33, 0.50, 0.52), Color(0.86, 0.82, 0.70), Color(0.36, 0.40, 0.55)])
## Strings of lights across the street, one slot every string_spacing metres (a share of them built), no
## lower than string_height (clear of every ceiling's TOP_LIMIT).
@export_range(20.0, 200.0, 1.0, "suffix:m") var string_spacing: float = 48.0
@export_range(0.0, 1.0, 0.01) var string_share: float = 0.7
@export_range(13.0, 30.0, 0.5, "suffix:m") var string_height: float = 13.0
## Neon signs (a share of the shacks carry one on the roofline, facing the runner) and the cult's emblem
## on some of them.
@export_range(0.0, 1.0, 0.01) var sign_share: float = 0.55

@export_group("Cult emblem")
## DESIGN-TBD (docs/questions/d10.md): GDD §5 proposes the emblem hidden in logos and ads in every zone. A
## small warm-white neon badge on some neon signs and billboards, unlit bronze on the party barge's hull,
## never smaller than emblem_min_size (tiny, its three-fold silhouette could read like the radiation
## trefoil; the kit also fades it out below about 24 pixels).
@export_range(0.0, 1.0, 0.01) var emblem_share: float = 0.4
@export_range(0.5, 3.0, 0.05, "suffix:m") var emblem_min_size: float = 0.9
@export_range(0.0, 1.5, 0.05) var emblem_glow: float = 0.55

@export_group("Cult feed")
## DESIGN-TBD (docs/questions/d10.md): the cult's feed (CultFeed, GDD §5 "Cyborg Viewing Devices") plays on
## a TV behind some upper-deck bars and on some roof billboards, never in the wall-run band.
@export_range(0.0, 1.0, 0.01) var feed_tv_share: float = 0.35
@export_range(0.0, 1.0, 0.01) var feed_board_share: float = 0.3
@export_range(0.0, 1.0, 0.05) var feed_tv_brightness: float = 0.7
@export_range(0.0, 1.0, 0.05) var feed_board_brightness: float = 0.85

@export_group("Ceilings")
## DESIGN-TBD (docs/questions/d10.md): the three kinds of ceiling. A boardwalk footbridge between the upper
## verandas (only across every lane), a veranda deck cantilevered from the building it reaches (narrow,
## reaching one wall), a hovering party barge (a cyberpunk tiki boat: any width, or reaching neither
## wall). Relative weights of a footbridge (across every lane) and a barge; and of a veranda deck and a
## barge, where a narrow ceiling reaches one wall.
@export_range(0.0, 10.0, 0.1) var footbridge_weight: float = 3.0
@export_range(0.0, 10.0, 0.1) var barge_weight: float = 2.0
@export_range(0.0, 10.0, 0.1) var veranda_weight: float = 3.0
@export var plank_color: Color = Color(0.52, 0.40, 0.28)
@export var hull_color: Color = Color(0.13, 0.135, 0.15)
@export var ceiling_lamp_color: Color = Color(1.0, 0.9, 0.74)
## The barge's engines: a pale violet-blue, far from the pads' cyan.
@export var engine_color: Color = Color(0.55, 0.5, 1.0)
@export var seam_color: Color = Color(0.09, 0.07, 0.05)

@export_group("Hazards")
## Pink crackle always means electric fence (GDD §5).
@export var fence_color: Color = Color(1.0, 0.18, 0.62)
## The steel drums the fence posts stand in, filled with sand, and the bamboo wrapped round the posts.
@export var drum_color: Color = Color(0.14, 0.145, 0.16)
@export var post_color: Color = Color(0.62, 0.50, 0.30)
## Signs: the yellow/black hazard frame around a painted surf or bar sign.
@export var sign_frame_color: Color = Color(1.0, 0.8, 0.15)
## The board's grounds (the paints in the poster shader choose its colours; these tint nothing glowing).
@export var sign_content_colors: PackedColorArray = PackedColorArray([
	Color(0.33, 0.50, 0.52), Color(0.62, 0.42, 0.34), Color(0.36, 0.40, 0.55)])

@export_group("Pads, ramps, finish")
@export var pad_color: Color = Color(0.1, 1.0, 0.95)
## Height of the anti-grav pad's light column.
@export_range(1.0, 10.0, 0.1, "suffix:m") var pad_beam_height: float = 5.8
@export var ramp_color: Color = Color(0.3, 1.0, 0.35)
## Speed pads share the ramps' green "safe boost" family (MeshKit.speed_strip; FB 49).
@export var speed_pad_color: Color = Color(0.45, 1.0, 0.55)
@export var finish_color: Color = Color(1.0, 1.0, 1.0)
## Gunmetal under pads, ramps and the finish gantry, so their glows read on the sand.
@export var trigger_metal_color: Color = Color(0.2, 0.2, 0.22)

## Built on first use and shared by every mesh (exports changed later don't reach them).
var _materials: Dictionary = {}
var _sand: BeachSand
var _shacks: BeachShacks
var _ceilings: BeachCeilings
var _props: BeachProps
var _doodads: BeachDoodads
## The latest wall face seen (wall_section runs before a chunk's ceilings): a ceiling across every lane
## reaches from wall to wall, and a narrow one knows which of its sides reach a wall.
var _wall_x: float = 0.0


func _init() -> void:
	# No new enemy assets for the Beach (the owner, October 9, 2026): the base cyborg, clean enemies.
	# DESIGN-TBD (docs/questions/d10.md): which existing look the Beach's enemies wear.
	enemy_variant = &"city"


func make_environment() -> Environment:
	# The sky's colours as sRGB Vector3s (srgb()), so the sky looks the same on both renderers.
	var sky := {"zenith_color": srgb(sky_zenith_color), "horizon_color": srgb(sky_horizon_color),
		"horizon_falloff": 0.5, "haze_color": srgb(haze_color), "haze_strength": haze_strength, "haze_height": 0.14,
		"abyss_color": srgb(abyss_color), "skyline_color": srgb(skyline_color), "window_color": srgb(skyline_color),
		"moon_radius": 0.0, "star_amount": 0.0, "skyline_hills": 1.0, "skyline_scale": 0.4, "sun_glow_color": srgb(sun_glow_color),
		"sun_glow_direction": sun_glow_direction, "sun_glow_strength": sun_glow_strength, "sun_glow_focus": 2.0,
		"sun_glow_height": 0.16, "cloud_amount": cloud_amount, "cloud_scale": cloud_scale, "cloud_opacity": 0.92,
		"cloud_color": srgb(cloud_color), "cloud_lit_color": srgb(cloud_lit_color), "cloud_lit_focus": 0.35}
	return MeshKit.night_environment(sky, ambient_color, fog_color, fog_begin, fog_end, fog_max, 0.0,
		glow_intensity, glow_threshold)


func floor_segment(parent: Node3D, center: Vector3, size: Vector3, lane_x: float,
		edge_start: bool, edge_end: bool) -> void:
	var batch := MeshBatch.new()
	sand().build(batch, center, size, lane_x, edge_start, edge_end)
	batch.commit(parent)


## A floor cut (task B4; GDD §9.9: the Buzz Overdrive may appear here too): the sand or boardwalk split open
## over the pool tank (BeachSand.cut).
func floor_cut(parent: Node3D, cut: FloorCutSection) -> void:
	sand().cut(parent, cut)


func wall_section(parent: Node3D, side: int, face_x: float, start: float, end: float) -> void:
	_wall_x = absf(face_x)
	var batch := MeshBatch.new()
	shacks().build(batch, side, face_x, start, end)
	sand().below_wall(batch, side, face_x, start, end)
	if side < 0:
		sand().below(batch, absf(face_x), start, end)
		shacks().overhead(batch, absf(face_x), start, end)
	batch.commit(parent)


## A wall gap (ZoneSkin.wall_gap), and with the left wall the pool water below (the street below it still
## needs its water, and the strings of lights across it are left out: no building to hang them from).
func wall_gap(parent: Node3D, side: int, face_x: float, start: float, end: float, gap: Vector2) -> void:
	_wall_x = absf(face_x)
	super(parent, side, face_x, start, end, gap)
	if side < 0:
		var batch := MeshBatch.new()
		sand().below(batch, absf(face_x), start, end)
		batch.commit(parent)


## The wall gaps near the chunk about to be built (ZoneSkin.note_wall_gaps): kept, so the strings of lights
## across the street (drawn with the left wall) skip a mast that would stand over a gap on either wall.
func note_wall_gaps(side: int, gaps: Array[Vector2]) -> void:
	shacks().note_gaps(side, gaps)


func fence(hazard: Hazard, size: Vector3, ground_y: float, gapped: bool) -> void:
	props().fence(hazard, size, ground_y, gapped)


func wall_sign(hazard: Hazard, size: Vector3) -> void:
	props().wall_sign(hazard, size)


## A ceiling over its lanes, reaching to the wall faces where the section says they are (BeachCeilings: only
## a ceiling across every lane becomes a footbridge; a narrow one reaching a wall a veranda deck; any width
## a party barge).
func ceiling_section(parent: Node3D, section: CeilingSection) -> void:
	ceilings().build(parent, section)


## A ceiling given as its box alone (the wall faces from the chunk's walls).
func hull(parent: Node3D, center: Vector3, size: Vector3, lane_edges_x: Array[float]) -> void:
	var wall: float = _wall_x if _wall_x > 0.0 else size.x * 0.5 + 0.3
	ceilings().build_box(parent, center, size, lane_edges_x, wall)


func pad(trigger: Area3D, size: Vector3) -> void:
	MeshBatch.add_instance(trigger, MeshKit.lift_pad(size, pad_color, trigger_metal_color, pad_beam_height,
		solid_material(), glow_material()))


func ramp(trigger: Area3D, size: Vector3, side: int) -> void:
	MeshBatch.add_instance(trigger, MeshKit.kicker_ramp(size, side, ramp_color, trigger_metal_color, solid_material(),
		glow_material()))


func speed_pad(trigger: Area3D, size: Vector3) -> void:
	MeshBatch.add_instance(trigger, MeshKit.speed_strip(size, speed_pad_color, trigger_metal_color, solid_material(),
		glow_material()))


func finish_line(parent: Node3D, width: float, distance: float) -> void:
	var batch := MeshBatch.new()
	MeshKit.finish_gate(batch, solid_material(), glow_material(), width, distance, finish_color, trigger_metal_color)
	batch.commit(parent)


## A surfboard rack (small), a beach cabana or a palm in a timber planter (medium, by look_seed) or a tiki
## bar kiosk (large): BeachDoodads.
func doodad(body: Node3D, size: Vector3, size_class: StringName, side: int, look_seed: int) -> void:
	doodads().build(body, size, size_class, side, look_seed)


# --- The cult's feed and emblem ------------------------------------------------------------

## The shared feed material (CultFeed): the same broadcast as in every zone.
func feed_material() -> ShaderMaterial:
	return CultFeed.material()


## Whether the screen keyed by (a, b) plays the cult's feed (`share` of them).
func shows_feed(a: int, b: int, share: float) -> bool:
	return MeshKit.hash01(a, b, 131) < share


## Whether the sign or board keyed by (a, b) carries the cult's emblem (emblem_share of them).
func carries_emblem(a: int, b: int) -> bool:
	return MeshKit.hash01(a, b, 97) < emblem_share


## The screens on the walls playing the feed whose middles lie between two track distances, for reviews
## and tests: side, at, kind (&"deck_tv" a TV behind an upper-deck bar, &"roof_board" a billboard on a
## roof), width, height, center (the screen's middle). The same ones wall_section() builds.
func feed_boards(side: int, face_x: float, start: float, end: float) -> Array[Dictionary]:
	return shacks().feed_boards(side, face_x, start, end)


## The cult's emblems on the walls and the ceilings' hulls whose middles lie between two track distances,
## for reviews and tests: side, at, kind (&"sign", &"billboard"), size (the mark's square, metres), center.
## The same ones wall_section() builds. (The barge's hull mark belongs to the ceilings.)
func cult_emblems(side: int, face_x: float, start: float, end: float) -> Array[Dictionary]:
	return shacks().emblems(side, face_x, start, end)


## The emblem's warm-white neon, and its unlit bronze (the chosen option's own colours).
func emblem_color() -> Color:
	return _emblem_scheme()["neon"]


func emblem_metal_color() -> Color:
	return _emblem_scheme()["metal"]


## The chosen emblem's colours (CultEmblem.default_scheme), looked up once.
func _emblem_scheme() -> Dictionary:
	if not _materials.has(&"emblem"):
		_materials[&"emblem"] = CultEmblem.default_scheme(CultFeed.emblem_option())
	return _materials[&"emblem"]


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
		_materials[&"glow"] = MeshKit.glow({"fade_begin": fog_begin + 20.0, "fade_end": fog_end})
	return _materials[&"glow"]


func drift_material() -> ShaderMaterial:
	if not _materials.has(&"drift"):
		_materials[&"drift"] = MeshKit.material("drift.gdshader", {
			"slice_length": TrackBuilder.CHUNK_LENGTH, "ash_speed": sand_speed, "streak_speed": streak_speed})
	return _materials[&"drift"]


## ON, WARNING and OFF materials for a fence's glowing parts (bars, emitters).
func fence_part_materials() -> Array[Material]:
	if not _materials.has(&"fence_parts"):
		_materials[&"fence_parts"] = MeshKit.hazard_part_materials(_solid_params())
	return _materials[&"fence_parts"]


## ON, WARNING and OFF materials for a fence's energy field.
func fence_field_materials() -> Array[Material]:
	if not _materials.has(&"fence_field"):
		_materials[&"fence_field"] = MeshKit.fence_field_materials(fence_color, fog_begin + 40.0, fog_end + 20.0)
	return _materials[&"fence_field"]


## A colour for this skin's shader uniforms: its sRGB values as a Vector3. Godot converts a Color set on a
## colour uniform to linear on Forward+ (not on the Compatibility renderer), and the kit's shaders convert
## once more (to_linear); as a Vector3 it arrives as authored on both renderers and is converted once, like
## a vertex colour, so the two renderers match (docs/ARCHITECTURE.md, Zone skins).
static func srgb(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)


func _solid_params() -> Dictionary:
	var marks: PackedFloat32Array = wall_height_marks
	var paints: PackedColorArray = paint_colors
	return {"glow_scale": emissive_scale, "sheen_color": srgb(sheen_color), "sheen_strength": sheen_strength,
		"bc_sand_light": srgb(sand_light_color), "bc_sand_dark": srgb(sand_dark_color), "bc_shell": srgb(shell_color),
		"bc_pebble": srgb(pebble_color), "bc_plank_gap": srgb(plank_gap_color), "bc_plate": srgb(plate_color),
		"bc_rust": srgb(rust_color), "bc_steel": srgb(steel_color), "bc_steel_rust": srgb(steel_rust_color),
		"bc_tank_rust": srgb(tank_rust_color), "bc_tide": srgb(tide_color), "bc_pool_depth": pool_depth, "bc_bamboo_dark": srgb(bamboo_dark_color),
		"bc_thatch_dark": srgb(thatch_dark_color), "bc_timber": srgb(timber_color),
		"bc_paint_a": srgb(paints[0]), "bc_paint_b": srgb(paints[1]), "bc_paint_c": srgb(paints[2]),
		"bc_paint_d": srgb(paints[3]), "bc_paint_e": srgb(paints[4]), "bc_cream": srgb(cream_color),
		"bc_band_top": band_top, "bc_daylight": daylight, "bc_mark_a": marks[0] if marks.size() > 0 else -10.0,
		"bc_mark_b": marks[1] if marks.size() > 1 else -10.0, "bc_mark": srgb(wall_mark_color)}


func sand() -> BeachSand:
	if _sand == null:
		_sand = BeachSand.new(self)
	return _sand


func shacks() -> BeachShacks:
	if _shacks == null:
		_shacks = BeachShacks.new(self)
	return _shacks


func ceilings() -> BeachCeilings:
	if _ceilings == null:
		_ceilings = BeachCeilings.new(self)
	return _ceilings


func props() -> BeachProps:
	if _props == null:
		_props = BeachProps.new(self)
	return _props


func doodads() -> BeachDoodads:
	if _doodads == null:
		_doodads = BeachDoodads.new(self)
	return _doodads

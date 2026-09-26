class_name MarketplaceSkin
extends ZoneSkin
## Zone 3, the Marketplace (GDD §5, §11): a bustling, happy open-air market at dusk, dustier than the
## Neon City but just as futuristic. Floor segments are rows of market-stall roofs and awnings
## (canvas, blue awnings, corrugated tin) with the market floor far below; gaps are the drops between
## the stalls, with the orange edge glow right on the collision edge. Walls are shopfronts and
## casinos: sun-bleached stucco with a row of lit shop windows at the low part of the wall (where the
## Marketplace citizens will play, task D3: see shop_windows()), a calm band above them, and busy upper
## floors with shutters, awnings and decorative signs. Signs are shop signs in the yellow/black hazard
## frame; decorative signs are never framed and never below `decor_min_height`, so they can't be
## mistaken for hazard signs. Electric fences are the same pink field, strung between poles standing
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
@export_range(0.0, 2.0, 0.05) var haze_strength: float = 0.45
@export var abyss_color: Color = Color(0.3, 0.24, 0.2)
@export var skyline_color: Color = Color(0.5, 0.43, 0.44)
@export var skyline_window_color: Color = Color(0.62, 0.52, 0.47)
## A pale early moon, off to one side of the street (radius in radians; 0 = none).
@export var moon_color: Color = Color(0.92, 0.9, 0.86)
@export var moon_direction: Vector3 = Vector3(-0.42, 0.42, -0.8)
@export_range(0.0, 0.3, 0.005) var moon_radius: float = 0.03
@export_range(0.0, 1.0, 0.01) var moon_clarity: float = 0.45
@export var ambient_color: Color = Color(0.85, 0.75, 0.66)
## Distant geometry fades into dusty air between fog_begin and fog_end.
@export var fog_color: Color = Color(0.68, 0.56, 0.47)
@export_range(0.0, 150.0, 1.0, "suffix:m") var fog_begin: float = 20.0
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
@export_range(0, 200, 1) var dust_count: int = 50
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
## Window shutters: blue, dusty teal, weathered wood, grey. Lit, never glowing.
@export var shutter_colors: PackedColorArray = PackedColorArray([
	Color(0.3, 0.42, 0.6), Color(0.38, 0.5, 0.5), Color(0.52, 0.41, 0.31), Color(0.6, 0.58, 0.54)])
## The tiles of the plinth under the shop windows.
@export var plinth_color: Color = Color(0.38, 0.44, 0.52)
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
## showing it, and of shop windows with a TV showing it.
@export_range(0.0, 1.0, 0.01) var feed_share: float = 0.35
@export_range(0.0, 1.0, 0.01) var feed_window_share: float = 0.22
## Brightness of the feed (0-1): full on billboards, dimmer on the TVs in shop windows, low on the
## walls where the player runs.
@export_range(0.0, 1.0, 0.05) var feed_board_brightness: float = 1.0
@export_range(0.0, 1.0, 0.05) var feed_window_brightness: float = 0.45

@export_group("Pads, ramps, finish")
@export var pad_color: Color = Color(0.1, 1.0, 0.95)
## Height of the anti-grav pad's light column.
@export_range(1.0, 10.0, 0.1, "suffix:m") var pad_beam_height: float = 5.8
@export var ramp_color: Color = Color(0.3, 1.0, 0.35)
## DESIGN-TBD: speed pads share the ramps' green "safe boost" family (MeshKit.speed_strip).
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
## The latest wall face seen (wall_section runs before a chunk's ceilings): a building bridging the
## street reaches from wall to wall.
var _wall_x: float = 0.0


func _init() -> void:
	# DESIGN-TBD: the GDD doesn't say whether Marketplace cyborgs are sleek citizens or scavengers
	# (§9.2); the market is a commercial district, so they dress as citizens for now.
	enemy_variant = &"city"


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


func wall_section(parent: Node3D, side: int, face_x: float, start: float, end: float) -> void:
	_wall_x = absf(face_x)
	var batch := MeshBatch.new()
	facades().build(batch, side, face_x, start, end)
	if side < 0:
		stalls().below(batch, absf(face_x), start, end)
		facades().overhead(batch, absf(face_x), start, end)
	batch.commit(parent)


func fence(hazard: Hazard, size: Vector3, ground_y: float, gapped: bool) -> void:
	props().fence(hazard, size, ground_y, gapped)


func wall_sign(hazard: Hazard, size: Vector3) -> void:
	props().wall_sign(hazard, size)


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
##   screen    true if a TV in the display plays the cult's feed (CultFeed): it stands at the back,
##             in the middle, about 1 m wide, so citizens may gather beside it
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
		_materials[&"solid"] = MeshKit.solid(_solid_params())
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
			"plinth_light": plinth_light_color, "plinth_top": gallery_bottom,
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
	return {"glow_scale": emissive_scale, "sheen_color": sheen_color, "sheen_strength": sheen_strength,
		"canvas_stripe": awning_stripe_color, "canvas_pole": seam_color,
		"stall_slot": stall_slot, "stall_awning_share": awning_share, "stall_tin_share": tin_share,
		"stall_canvas": canvas, "stall_awning": awnings, "stall_tin": Vector3(tin_color.r, tin_color.g, tin_color.b)}


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

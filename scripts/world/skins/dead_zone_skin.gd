class_name DeadZoneSkin
extends ZoneSkin
## Zone 5, the Dead Zone (GDD §5, §11): a blackened, bombed-out husk of the city, eerie, quiet and
## haunting: rubble, embers, smoke and silence, with not much life. Dark black, dark grey and ash grey.
## The same future as every zone, in its dominant shapes: these are the ruins of the Neon City's own
## towers (their window grids, podiums, dead neon banners and billboards, broken skybridges), gutted by
## fire, their tops sheared off and some burnt down to their steel frames.
## Floor segments are stretches of a rubble street (DeadStreet): broken road plates under pale ash,
## with scattered rubble drawn flat (nothing on the running surface stands up like an obstacle); gaps
## are collapsed holes whose edges carry the orange edge glow right on the collision edge, and inside
## them only deep shade dropping into a dark void, so a hole reads at a glance: the ash-grey street is
## far lighter than any hole. Walls are burnt-out towers (DeadTowers) over a calm, flush, closed band
## where nothing opens or glows; signs are dead billboards in the yellow/black hazard frame, and fences
## the same pink field between charred posts set in rubble (DeadProps). Ceilings are only the remains
## of the destroyed city (DeadCeilings): crumbling, charred grey bridges and the undersides of dead
## buildings, and over fewer lanes a slab broken off a tower or a collapsed span hanging from its
## skybridge's frame, each built from the lanes it covers.
## The street stands still, so ash drifting and falling, puffs of smoke and speed streaks carry the
## sense of speed (the owner's review: every still floor gets motion cues).
## Fires are kept minimal, dim and in the background (GDD §5): the smoke over the horizon glows faintly
## from below, and a few rooms high up in the towers still smoulder (dim embers far above the play
## field, below the bloom threshold, never as bright as a gap edge). Nothing else glows but hazards,
## triggers, the orange ends of ceilings and the cult's feed on a few surviving screens.
## Readability in the dark: distance fades into ash-grey haze, lighter than the ruins, so the black
## silhouette of the Cyborg's Bad Dream (first seen here, GDD §9.7) and the burned cyborgs' outlines
## stand out against it, while the hazards stay the brightest, most saturated things on screen. A
## level's darker lighting (The Hush) dims the scenery further (ZoneSkin.apply_darkness): all of it is
## drawn with the kit's solid and drift shaders, which follow `scenery_light`.
## The cult (GDD §5): its emblem (the owner's pick, never hardcoded) is scorched and half-gone on some
## dead billboards and at the foot of some dead neon banners; its feed still plays on a few surviving
## screens, dim and high up, far above the wall-run band and away from hazards.
## Visuals only: TrackBuilder owns every collision shape and gameplay node, and all variety comes from
## hashing track positions (MeshKit.hash_i), so a chunk looks the same whenever it is built.

@export_group("Environment")
## DESIGN-TBD (docs/questions/d5.md): the GDD gives the Dead Zone's palette and mood, not its hour. A
## smoke-choked night: a low pall of smoke, dark overhead and paler toward the horizon, where ash haze
## hangs (the ruins stand against it in dark silhouette), columns of smoke glowing faintly from fires far
## away, a veiled moon.
@export var sky_zenith_color: Color = Color(0.07, 0.07, 0.072)
@export var sky_horizon_color: Color = Color(0.2, 0.197, 0.194)
## The ash haze over the horizon, lit by the veiled moon.
@export var haze_color: Color = Color(0.34, 0.335, 0.33)
@export_range(0.0, 2.0, 0.05) var haze_strength: float = 0.6
@export var abyss_color: Color = Color(0.02, 0.02, 0.02)
@export var skyline_color: Color = Color(0.05, 0.05, 0.052)
## The rare embers in the far ruins' windows: dull and dim (the sky shader shows few in a ruined
## skyline).
@export var skyline_window_color: Color = Color(0.36, 0.2, 0.13)
@export var moon_color: Color = Color(0.72, 0.72, 0.74)
@export var moon_direction: Vector3 = Vector3(0.3, 0.2, -0.93)
@export_range(0.0, 0.3, 0.005) var moon_radius: float = 0.05
@export_range(0.0, 1.0, 0.01) var moon_clarity: float = 0.22
## Columns of smoke over the far skyline, glowing faintly from below by fires far from the play field.
@export_range(0.0, 1.0, 0.01) var smoke_amount: float = 1.0
@export var smoke_color: Color = Color(0.075, 0.073, 0.072)
@export var distant_fire_color: Color = Color(0.3, 0.14, 0.08)
## The light on everything lit by the engine (the runner, the enemies): a cold, pale ash.
@export var ambient_color: Color = Color(0.56, 0.57, 0.6)
## Distant geometry fades into the ash haze between fog_begin and fog_end: lighter than the ruins, so
## dark silhouettes (the Bad Dream, the cyborgs) read against it.
@export var fog_color: Color = Color(0.2, 0.197, 0.194)
@export_range(0.0, 150.0, 1.0, "suffix:m") var fog_begin: float = 10.0
@export_range(50.0, 400.0, 5.0, "suffix:m") var fog_end: float = 150.0
@export_range(0.0, 1.0, 0.01) var fog_max: float = 1.0
@export_range(0.0, 2.0, 0.05) var glow_intensity: float = 0.75
@export_range(0.5, 4.0, 0.05) var glow_threshold: float = 1.1
## Brightness of emissive kit parts (vertex glow 1.0 = this many times the albedo).
@export_range(1.0, 20.0, 0.5) var emissive_scale: float = 4.0
## The haze caught at grazing angles by the street, the walls and the undersides.
@export var sheen_color: Color = Color(0.3, 0.3, 0.31)
@export_range(0.0, 1.0, 0.01) var sheen_strength: float = 0.16

@export_group("Ash and soot")
## The pale ash lying over the street, the sills and the decks, and falling.
@export var ash_color: Color = Color(0.46, 0.452, 0.44)
## How much of the street the ash covers.
@export_range(0.0, 1.0, 0.01) var ash_amount: float = 0.45
@export var soot_color: Color = Color(0.03, 0.03, 0.03)

@export_group("Street")
## The road under the ash: a dark grey. With the ash, the street is far lighter than a hole.
@export var road_color: Color = Color(0.19, 0.188, 0.185)
## The strip between the outer lanes and the walls, where the ash piles up.
@export var gutter_color: Color = Color(0.2, 0.198, 0.195)
## Worn lane paint, mostly buried under the ash. Pale: yellow belongs to signs.
@export var lane_marking_color: Color = Color(0.52, 0.52, 0.5)
## The rubble scattered over the street (drawn flat).
@export var rubble_color: Color = Color(0.36, 0.355, 0.35)
## DESIGN-TBD (docs/questions/d5.md): everything below the street, seen only through holes (the
## broken road's cut, the building faces below it, the void): deep shade that only darkens with depth,
## so a hole reads as a hole at a glance. Kept far darker than the street
## (tests/suites/test_dead_zone_skin.gd).
@export var gap_inside_color: Color = Color(0.042, 0.042, 0.044)
## How far the void under the street goes down (deeper than a fall that ends the run, so a fall never
## visibly lands).
@export_range(4.5, 20.0, 0.1, "suffix:m") var void_depth: float = 7.0
## Gap edges: the orange edge language of every zone. Redder than it looks: the glow and the
## tonemapper lift the green, and it must stay orange, not sign yellow.
@export var gap_edge_color: Color = Color(1.0, 0.25, 0.04)
## A soft orange halo along the far edge of a hole, facing the approaching runner (additive).
@export_range(0.0, 1.0, 0.01) var edge_halo: float = 0.25

@export_group("Motion")
## DESIGN-TBD (docs/questions/d5.md): the still street's motion cues (the owner's review: every still
## floor gets them; here ash and drifting smoke). Per 40 m of track: flakes of ash drifting and
## falling, faint puffs of smoke drifting low, and speed streaks (a = opacity).
@export_range(0, 200, 1) var ash_count: int = 70
@export_range(0, 40, 1) var smoke_count: int = 7
@export_range(0, 60, 1) var streak_count: int = 12
@export var ash_flake_color: Color = Color(0.62, 0.61, 0.6, 0.65)
@export var smoke_puff_color: Color = Color(0.3, 0.3, 0.3, 0.22)
@export var streak_color: Color = Color(0.72, 0.72, 0.72, 0.24)
@export_range(0.0, 30.0, 0.5, "suffix:m/s") var ash_speed: float = 5.0
@export_range(0.0, 80.0, 0.5, "suffix:m/s") var streak_speed: float = 24.0

@export_group("Ruins")
## The towers' original heights (many are broken off well below them).
@export_range(20.0, 200.0, 1.0, "suffix:m") var building_min_height: float = 30.0
@export_range(30.0, 300.0, 1.0, "suffix:m") var building_max_height: float = 120.0
## Buildings are 1–3 lots long; a lot is this long.
@export_range(6.0, 40.0, 1.0, "suffix:m") var lot_length: float = 16.0
## Charred cladding and concrete: blacks and dark greys, one ash-grey.
@export var facade_colors: PackedColorArray = PackedColorArray([
	Color(0.15, 0.15, 0.152), Color(0.12, 0.12, 0.12), Color(0.18, 0.177, 0.173), Color(0.1, 0.1, 0.105),
	Color(0.23, 0.227, 0.22)])
## The calm band: nothing opens, sticks out, lights up or looks like a vent on the walls below this
## height (the wall-run band tops out below 6 m), and decoration starts at decor_min_height.
@export_range(6.0, 10.0, 0.1, "suffix:m") var band_top: float = 7.2
@export_range(7.0, 16.0, 0.25, "suffix:m") var decor_min_height: float = 8.0
## Smoked glass left in the windows.
@export var glass_color: Color = Color(0.06, 0.065, 0.072)
## Share of towers burnt down to their steel frames at the top, and the steel's colour.
@export_range(0.0, 1.0, 0.01) var skeleton_share: float = 0.4
@export var steel_color: Color = Color(0.12, 0.118, 0.118)
## Faint lines on the facades at these heights, to read how high a wall run is: unlit paint, a little
## paler than the charred walls.
@export var wall_height_marks: PackedFloat32Array = PackedFloat32Array([2.0, 4.0])
@export var wall_mark_color: Color = Color(0.24, 0.24, 0.235)
## The dead neon on the towers (banners of unlit tubes, as the City's were) and the dead boards.
@export var dead_neon_color: Color = Color(0.3, 0.3, 0.31)
@export var board_color: Color = Color(0.07, 0.07, 0.075)
@export var board_colors: PackedColorArray = PackedColorArray([
	Color(0.22, 0.216, 0.21), Color(0.16, 0.16, 0.162), Color(0.27, 0.265, 0.26)])
## Broken skybridges high over the street (the city's future in its ruins): the share of slots with
## one, where the towers on both sides stand tall enough. A boss arena can set it to 0.
@export_range(0.0, 1.0, 0.01) var skybridge_share: float = 0.5

@export_group("Smoke")
## DESIGN-TBD (docs/questions/d5.md): smoke rising from some ruins (GDD §5: rubble, embers, smoke and
## silence): the share of towers with a column of smoke rising from their broken tops, far above the
## play field, its colour (a = its opacity at the core) and how fast its billows rise.
@export_range(0.0, 1.0, 0.01) var plume_share: float = 0.22
@export var plume_color: Color = Color(0.2, 0.197, 0.194, 0.7)
@export_range(0.0, 5.0, 0.1, "suffix:m/s") var plume_rise: float = 1.2

@export_group("Embers")
## DESIGN-TBD (docs/questions/d5.md): fires are kept minimal, dim and in the background (GDD §5). The
## share of towers with rooms still smouldering high up, the lowest those rooms are, the share of
## their windows up there that glow, and how dimly (the kit's glow, kept below the bloom threshold).
## Embers are orange like a gap edge, so they stay small, dim and far above the play field.
@export_range(0.0, 1.0, 0.01) var smoulder_share: float = 0.35
@export_range(10.0, 60.0, 0.5, "suffix:m") var ember_min_height: float = 16.0
@export_range(0.0, 0.05, 0.001) var ember_window_share: float = 0.006
@export var ember_color: Color = Color(0.62, 0.24, 0.1)
@export_range(0.0, 0.5, 0.01) var ember_glow: float = 0.22

@export_group("Cult emblem")
## DESIGN-TBD (docs/questions/d5.md): GDD §5 proposes the emblem hidden in logos and ads in every
## zone; in the Dead Zone it's scorched and half-gone like everything else. The share of dead roof
## boards and dead neon banners carrying it, never smaller than emblem_min_size (tiny, its three-fold
## silhouette could read like the radiation trefoil; the kit also fades it out below about 24 pixels).
@export_range(0.0, 1.0, 0.01) var emblem_share: float = 0.4
@export_range(0.5, 3.0, 0.05, "suffix:m") var emblem_min_size: float = 0.9

@export_group("Cult feed")
## DESIGN-TBD (docs/questions/d5.md): the cult's feed (CultFeed, GDD §5 "Cyborg Viewing Devices")
## still plays on a few surviving screens: the share of low buildings' roof boards playing it, and of
## flush towers still hanging a big screen out over the street (facing the traffic). Sparse and dim.
@export_range(0.0, 1.0, 0.01) var feed_share: float = 0.2
@export_range(0.0, 1.0, 0.01) var feed_tower_share: float = 0.12
@export_range(0.0, 1.0, 0.05) var feed_board_brightness: float = 0.6
@export_range(0.0, 1.0, 0.05) var feed_screen_brightness: float = 0.65
## The towers' screens (16:9): the widest, the share of the street's half width they may reach over,
## and the lowest their bottom edge goes (far above the wall-run band and every ceiling).
@export_range(2.0, 12.0, 0.1, "suffix:m") var feed_screen_width: float = 4.4
@export_range(0.2, 1.0, 0.01) var feed_screen_reach: float = 0.65
@export_range(14.0, 40.0, 0.5, "suffix:m") var feed_screen_bottom: float = 15.0

@export_group("Ceilings")
## DESIGN-TBD (docs/questions/d5.md): GDD §5 names the undersides of dead buildings and crumbling,
## charred grey bridges. Relative weights of a bridge (an elevated road running along the street) and
## a dead building bridging it, for a ceiling across every lane; a narrower one is a slab broken off a
## tower (when it reaches a wall) or a collapsed span hanging from its skybridge's frame.
@export_range(0.0, 10.0, 0.1) var bridge_weight: float = 3.0
@export_range(0.0, 10.0, 0.1) var building_weight: float = 2.5
## The bridges' charred grey concrete, the dead buildings' slabs.
@export var bridge_color: Color = Color(0.33, 0.325, 0.32)
@export var slab_color: Color = Color(0.27, 0.267, 0.264)
## A pale line along each lane seam under a ceiling (unlit paint on a steel strip), so a runner hanging
## from it reads the lanes.
@export var seam_color: Color = Color(0.5, 0.5, 0.49)
## A burnt-out wreck of a hover-car or truck on a bridge's deck.
@export var wreck_color: Color = Color(0.1, 0.098, 0.096)

@export_group("Hazards")
## Pink crackle always means electric fence (GDD §5).
@export var fence_color: Color = Color(1.0, 0.18, 0.62)
## The charred steel posts the fences hang from.
@export var post_color: Color = Color(0.15, 0.148, 0.146)
## Signs: the yellow/black hazard frame around a dead billboard.
@export var sign_frame_color: Color = Color(1.0, 0.8, 0.15)
@export var sign_content_colors: PackedColorArray = PackedColorArray([
	Color(0.24, 0.235, 0.23), Color(0.18, 0.18, 0.182), Color(0.3, 0.295, 0.29)])

@export_group("Pads, ramps, finish")
@export var pad_color: Color = Color(0.1, 1.0, 0.95)
## Height of the anti-grav pad's light column.
@export_range(1.0, 10.0, 0.1, "suffix:m") var pad_beam_height: float = 5.8
@export var ramp_color: Color = Color(0.3, 1.0, 0.35)
## DESIGN-TBD: speed pads share the ramps' green "safe boost" family (MeshKit.speed_strip).
@export var speed_pad_color: Color = Color(0.45, 1.0, 0.55)
@export var finish_color: Color = Color(1.0, 1.0, 1.0)
## Scorched steel under pads, ramps and the finish gantry.
@export var trigger_metal_color: Color = Color(0.14, 0.138, 0.136)

## Built on first use and shared by every mesh (exports changed later don't reach them).
var _materials: Dictionary = {}
var _street: DeadStreet
var _towers: DeadTowers
var _ceilings: DeadCeilings
var _props: DeadProps
## The latest wall face seen (wall_section runs before a chunk's ceilings): a ceiling across every
## lane reaches from wall to wall, and a narrow one knows which of its sides reach a wall.
var _wall_x: float = 0.0


func _init() -> void:
	# GDD §9.2: the Dead Zone's cyborgs are the base, burned out (CyborgSuit's burned look); every other
	# enemy reads it as the clean look (docs/ARCHITECTURE.md, Zone skins).
	enemy_variant = &"burned"


func make_environment() -> Environment:
	# The sky's colours as sRGB Vector3s (srgb()), so the sky looks the same on both renderers.
	var sky := {"zenith_color": srgb(sky_zenith_color), "horizon_color": srgb(sky_horizon_color),
		"haze_color": srgb(haze_color), "haze_strength": haze_strength, "haze_height": 0.2,
		"abyss_color": srgb(abyss_color), "skyline_color": srgb(skyline_color), "window_color": srgb(skyline_window_color),
		"moon_color": srgb(moon_color), "moon_direction": moon_direction, "moon_radius": moon_radius,
		"moon_clarity": moon_clarity, "star_amount": 0.0, "skyline_ruin": 1.0, "smoke_amount": smoke_amount,
		"smoke_color": srgb(smoke_color), "fire_color": srgb(distant_fire_color)}
	return MeshKit.night_environment(sky, ambient_color, fog_color, fog_begin, fog_end, fog_max, 0.0,
		glow_intensity, glow_threshold)


func floor_segment(parent: Node3D, center: Vector3, size: Vector3, lane_x: float,
		edge_start: bool, edge_end: bool) -> void:
	var batch := MeshBatch.new()
	street().build(batch, center, size, lane_x, edge_start, edge_end)
	batch.commit(parent)


func wall_section(parent: Node3D, side: int, face_x: float, start: float, end: float) -> void:
	_wall_x = absf(face_x)
	var batch := MeshBatch.new()
	towers().build(batch, side, face_x, start, end)
	if side < 0:
		street().below(batch, absf(face_x), start, end)
		towers().overhead(batch, absf(face_x), start, end)
	batch.commit(parent)


func fence(hazard: Hazard, size: Vector3, ground_y: float, gapped: bool) -> void:
	props().fence(hazard, size, ground_y, gapped)


func wall_sign(hazard: Hazard, size: Vector3) -> void:
	props().wall_sign(hazard, size)


## A ceiling section, built from its collision box: which of its sides reach a wall (a narrow ceiling,
## task B3, may reach one or none) comes from the box and the walls seen last.
func hull(parent: Node3D, center: Vector3, size: Vector3, lane_edges_x: Array[float]) -> void:
	ceilings().build(parent, center, size, lane_edges_x, _wall_x if _wall_x > 0.0 else size.x * 0.5 + 0.3)


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


# --- The cult's feed and emblem ------------------------------------------------------------

## The shared feed material (CultFeed): the same broadcast as in every zone.
func feed_material() -> ShaderMaterial:
	return CultFeed.material()


## Whether the screen keyed by (a, b) still plays the cult's feed (`share` of them).
func shows_feed(a: int, b: int, share: float) -> bool:
	return MeshKit.hash01(a, b, 131) < share


## Whether the dead board or banner keyed by (a, b) carries the cult's emblem (emblem_share of them).
func carries_emblem(a: int, b: int) -> bool:
	return MeshKit.hash01(a, b, 97) < emblem_share


## The surviving screens on the walls still playing the feed whose middles lie between two track
## distances, for reviews and tests: side, at, kind (&"roof_board" on a low building's roof,
## &"tower_screen" hung out over the street), width, height, center (the screen's middle, on its
## face). The same ones wall_section() builds.
func feed_boards(side: int, face_x: float, start: float, end: float) -> Array[Dictionary]:
	return towers().feed_boards(side, face_x, start, end)


## The cult's scorched emblems on the walls whose middles lie between two track distances, for reviews
## and tests: side, at, kind (&"roof_board" or &"banner"), size (the mark's square, metres), center.
## The same ones wall_section() builds.
func cult_emblems(side: int, face_x: float, start: float, end: float) -> Array[Dictionary]:
	return towers().emblems(side, face_x, start, end)


## The emblem's paint on the dead boards: the chosen option's own unlit metal.
func emblem_metal_color() -> Color:
	return CultEmblem.default_scheme(CultFeed.emblem_option())["metal"]


# --- Shared materials (built once per skin, shared by every mesh) ------------------------

func solid_material() -> ShaderMaterial:
	if not _materials.has(&"solid"):
		var m: ShaderMaterial = MeshKit.solid(_solid_params())
		# The emblem's coverage for MeshKit.PAT_DZ_MARK (the owner's pick, drawn by CultEmblem).
		m.set_shader_parameter(&"cult_emblem", CultFeed.emblem_texture())
		_materials[&"solid"] = m
	return _materials[&"solid"]


func glow_material() -> ShaderMaterial:
	if not _materials.has(&"glow"):
		_materials[&"glow"] = MeshKit.glow({"fade_begin": fog_begin + 20.0, "fade_end": fog_end})
	return _materials[&"glow"]


## The columns of smoke rising from the ruins (dead_smoke.gdshader): scenery, dimmed by a level's
## darker lighting like the rest.
func smoke_material() -> ShaderMaterial:
	if not _materials.has(&"smoke"):
		_materials[&"smoke"] = MeshKit.material("dead_smoke.gdshader", {"rise_speed": plume_rise})
	return _materials[&"smoke"]


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


## A colour for this skin's shader uniforms: its sRGB values as a Vector3. Godot converts a Color set
## on a colour uniform to linear on Forward+ (not on the Compatibility renderer), and the kit's shaders
## convert once more (to_linear); as a Vector3 it arrives as authored on both renderers and is
## converted once, like a vertex colour, so the two renderers match (docs/ARCHITECTURE.md, Zone skins).
static func srgb(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)


func _solid_params() -> Dictionary:
	return {"glow_scale": emissive_scale, "sheen_color": srgb(sheen_color), "sheen_strength": sheen_strength,
		"dz_ash": srgb(ash_color), "dz_ash_amount": ash_amount, "dz_soot": srgb(soot_color), "dz_board": srgb(board_color),
		"dz_line": srgb(lane_marking_color), "dz_rubble": srgb(rubble_color), "dz_glass": srgb(glass_color),
		"dz_ember": srgb(ember_color), "dz_ember_height": ember_min_height, "dz_ember_share": ember_window_share,
		"dz_band_top": band_top}


func street() -> DeadStreet:
	if _street == null:
		_street = DeadStreet.new(self)
	return _street


func towers() -> DeadTowers:
	if _towers == null:
		_towers = DeadTowers.new(self)
	return _towers


func ceilings() -> DeadCeilings:
	if _ceilings == null:
		_ceilings = DeadCeilings.new(self)
	return _ceilings


func props() -> DeadProps:
	if _props == null:
		_props = DeadProps.new(self)
	return _props

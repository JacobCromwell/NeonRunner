class_name IceLabSkin
extends ZoneSkin
## Zone 9, the Ice Lab (GDD §5, owner, October 21, 2026; reference image docs/art/reference/ice_lab_zone.webp; task Q2): a
## frozen industrial laboratory, icy and crystalline, with steel catwalks and girders and cranes, lab equipment everywhere and
## specimen jars with brains floating in them, some holding a curled-up Octodog instead. An indoor frozen hall: there is no sky,
## only a cold fog the hall's far end fades into, dark ice and steel overhead, and small amber machine lamps.
## The runner's street is catwalk (IceLabFloor): every lane a stretch of steel grating in panels, with packed snow lying in drifts
## along the edges and in the gutter by the wall, patches of glossy ice, some solid tread plate (MeshKit.PAT_IL_GRATING, laid out
## from world position, so lanes, pieces and chunk cuts join seamlessly); gaps are drops between catwalks into a frozen depth, the
## orange gap edge right on the collision edge and, below it, only deep shade (the catwalk's truss, hoar furring) dropping to a floor
## of dark ice (PAT_IL_UNDER). The walls are lab machinery (IceLabWalls): bays of 5 m laid from the wall's own distance, each a run
## of pipes and girders, a lattice pillar, a pressure tank, a wall of ice, a bank of consoles, a row of server racks, clean-room
## tile, a service door, or an alcove of specimen jars (a brain in each, some holding an Octodog), their detail painted flush with the
## wall below the wall-run band's top and standing out from it only above (nothing sticks out more than 4.5 cm where a
## runner can touch it, nothing is recessed or lit there; the specimen jars' alcoves are above it). Over the wall stand the hall's gantry rail with its railing, ice crust and icicles, and beyond it the hall
## (IceLabHall): the far ice wall, crane runways and cross girders overhead with hanging chains and crane blocks, drifting snow and
## cold mist. Ceilings are crane gantries and overhead grated walkways (IceLabCeilings), each built from the lanes it covers. The
## doodads are brain jars, lab equipment, ice crystal clusters and crates of lab supplies, and the Octodog jar (IceLabDoodads, picture
## cards).
## The levels lean differently (owner, October 21, 2026: level 1 heavily into the snow and the industrial side, the last level much
## more into the laboratory, level 2 between): `lab_share`, 0 (snow and industry) to 1 (the laboratory), is the one number a level's
## skin sets (data/skins/ice_lab_frost_skin.tres, ice_lab_skin.tres and ice_lab_lab_skin.tres): it weighs the wall bays, the
## ceilings and the doodads and sets how much snow lies about and how clean the plates are, and tints the fog.
## Colour rule (GDD §5, looser in the later zones, the owner, October 20, 2026): the jars' cyan and the screens are pale and dim, the
## lamps small amber points, and the hazards keep their colours and shapes; nothing glows brightly near the track and nothing glows
## in a hazard's colour but the hazards, triggers, the orange edges and ends. A lamp is told from a gap edge as the Terminal's are
## (hue, a fraction of its glow under the bloom threshold, and height: up on the walls and the girders, never at floor level).
## Reduced flashing: the lamps' slow breathing holds still (kit_ice_lab.gdshaderinc, il_lamp_surface: the global `reduced_flashing`);
## nothing else flickers or flashes.
## No dash walls (GDD §5, §9.14): the base's default look stands, and `test_dash_walls` lists these skins among the ones that keep it.
## Visuals only: TrackBuilder owns every collision shape and gameplay node, and all variety comes from hashing track positions
## (MeshKit.hash_i), so a chunk looks the same whenever it is built.
## DESIGN-TBD (docs/questions/q2.md): the hall's proportions, the palette, the bays and their weights, the doodads' looks, the Octodog
## in its jar.

@export_group("Lean")
## 0 the snow and the industrial side (level 1), 1 the laboratory (the last level), about 0.5 in between (the owner, October 21,
## 2026). The one number a level's skin sets; everything below that depends on it takes its two ends from the exports below.
## DESIGN-TBD (docs/questions/q2.md item 8): the three values, 0.1, 0.5 and 0.9, and every end of the lean below, are proposals.
@export_range(0.0, 1.0, 0.01) var lab_share: float = 0.5
## How much of the floor, the ledges and the machinery lies under snow and frost at each end of the lean (0 none, 1 a drift
## everywhere).
@export_range(0.0, 1.0, 0.01) var snow_frost: float = 0.9
@export_range(0.0, 1.0, 0.01) var snow_lab: float = 0.14
## The wall bays' weights at each end of the lean (BAY_* in IceLabWalls, in order: pipes, lattice, tank, ice, consoles, racks,
## clean tile, door, jars, Octodog jars): blended by lab_share.
@export var bay_weights_frost: PackedFloat32Array = PackedFloat32Array([3.0, 2.0, 1.2, 3.2, 0.5, 0.3, 0.1, 0.5, 0.25, 0.05])
@export var bay_weights_lab: PackedFloat32Array = PackedFloat32Array([0.5, 0.4, 0.3, 0.4, 2.0, 1.8, 1.2, 0.7, 2.6, 0.4])

@export_group("Environment")
## The sky nobody sees (the hall is whole): near black blue, and the horizon the colour the fog fades the street's far end into,
## so the hall runs out into a cold haze. The haze's two ends of the lean (the frost level a touch bluer and brighter, the lab
## level darker and greener-grey).
@export var sky_zenith_color: Color = Color(0.04, 0.07, 0.115)
@export var fog_color_frost: Color = Color(0.12, 0.18, 0.26)
@export var fog_color_lab: Color = Color(0.085, 0.14, 0.19)
## The light on everything lit by the engine (the runner, the enemies): a cold, pale blue-grey.
@export var ambient_color: Color = Color(0.6, 0.68, 0.8)
## Distant geometry fades into the haze between fog_begin and fog_end.
@export_range(0.0, 150.0, 1.0, "suffix:m") var fog_begin: float = 12.0
@export_range(50.0, 400.0, 5.0, "suffix:m") var fog_end: float = 165.0
@export_range(0.0, 1.0, 0.01) var fog_max: float = 1.0
@export_range(0.0, 2.0, 0.05) var glow_intensity: float = 0.7
@export_range(0.5, 4.0, 0.05) var glow_threshold: float = 1.1
## Brightness of emissive kit parts (vertex glow 1.0 = this many times the albedo).
@export_range(1.0, 20.0, 0.5) var emissive_scale: float = 4.0
## The cold caught at grazing angles by the steel and the ice.
@export var sheen_color: Color = Color(0.22, 0.34, 0.5)
@export_range(0.0, 1.0, 0.01) var sheen_strength: float = 0.16

@export_group("Light")
## The machine lamps (GDD §5: small amber machine lamps): the Terminal's sodium amber, yellower than a gap edge's red-orange, a small
## box each, glowing a fraction of a gap edge's and under the bloom threshold (which the edge is over), on the walls from
## lamp_min_height up and on the girders overhead. DESIGN-TBD (docs/questions/q2.md item 4): how many and how bright.
@export var lamp_color: Color = Color(0.98, 0.6, 0.08)
@export_range(0.0, 0.6, 0.01) var lamp_glow: float = 0.09
## The same on the Compatibility renderer (web, low-end Android), which scales emissive colours in sRGB space where the others scale
## them in linear space: the same number draws far dimmer there, so this one draws about as bright as lamp_glow does on the others.
@export_range(0.0, 0.6, 0.01) var lamp_glow_compat: float = 0.16
## The lowest a lamp hangs: never at floor level, where a gap edge's orange is, and with its faint halo wholly over the wall-run band (so
## at least calm_top + 0.55: nothing lit down where a runner can touch the wall).
@export_range(6.2, 10.0, 0.1, "suffix:m") var lamp_min_height: float = 7.2
## The pale blue-white of the screens and the status LEDs and its glow (dim, and well under a gap edge's), and the same on the
## Compatibility renderer.
@export var screen_color: Color = Color(0.5, 0.74, 0.84)
@export_range(0.0, 0.3, 0.005) var screen_glow: float = 0.06
@export_range(0.0, 0.3, 0.005) var screen_glow_compat: float = 0.1
## The specimen jars' liquid: pale, desaturated cyan (never the anti-grav pad's saturated glow), and its glow.
@export var liquid_color: Color = Color(0.42, 0.7, 0.78)
@export_range(0.0, 0.3, 0.005) var liquid_glow: float = 0.07
@export_range(0.0, 0.3, 0.005) var liquid_glow_compat: float = 0.11

@export_group("Ice and snow")
## The ice's blue, its crystals' pale cyan-white, the packed snow and the frost on steel (all lit, never glowing).
@export var ice_color: Color = Color(0.3, 0.5, 0.66)
@export var crystal_color: Color = Color(0.62, 0.82, 0.95)
@export var snow_color: Color = Color(0.8, 0.86, 0.92)
@export var frost_color: Color = Color(0.5, 0.6, 0.72)

@export_group("Catwalk")
## The grating's steel (the bars: the slots between them are 0.42 of it) and the gutter's by the wall, the same grating deeper in snow.
@export var grating_color: Color = Color(0.17, 0.2, 0.25)
@export var gutter_color: Color = Color(0.15, 0.18, 0.22)
## Everything below the catwalks, seen only through holes and cuts: dim, and darkening with depth (PAT_IL_UNDER).
@export var gap_inside_color: Color = Color(0.03, 0.045, 0.07)
## The frozen floor far below (a top face, which the kit lights more than a wall: darker).
@export var pit_floor_color: Color = Color(0.03, 0.05, 0.085)
## How far below the street the frozen floor lies (deeper than a fall that ends a run, so a fall never visibly lands).
@export_range(4.5, 20.0, 0.1, "suffix:m") var pit_depth: float = 7.0
## Gap edges: the orange edge language of every zone. Redder than it looks: the glow and the tonemapper lift the green, and it must
## stay orange, not sign yellow.
@export var gap_edge_color: Color = Color(1.0, 0.25, 0.04)
## A soft orange halo along the far edge of a hole, facing the approaching runner (additive).
@export_range(0.0, 1.0, 0.01) var edge_halo: float = 0.25

@export_group("Motion")
## The still floor's motion cues (the owner's review: every still floor gets them): per 40 m of track, snow flakes drifting down,
## puffs of cold mist drifting low, and speed streaks (a = opacity). The snow thins toward the lab end of the lean.
@export_range(0, 200, 1) var snow_count: int = 70
@export_range(0, 40, 1) var mist_count: int = 7
@export_range(0, 60, 1) var streak_count: int = 10
@export var snow_flake_color: Color = Color(0.82, 0.9, 0.98, 0.6)
@export var mist_color: Color = Color(0.45, 0.58, 0.72, 0.2)
@export var streak_color: Color = Color(0.7, 0.8, 0.92, 0.2)
@export_range(0.0, 30.0, 0.5, "suffix:m/s") var snow_speed: float = 3.5
@export_range(0.0, 80.0, 0.5, "suffix:m/s") var streak_speed: float = 24.0

@export_group("Hall")
## The hall's shape (DESIGN-TBD, docs/questions/q2.md item 1): the walls stand wall_height tall (the machinery's detail: flush
## below band_top, standing out above it), the far ice wall stands hall_extra beyond the street's wall line, the crane runways ride
## at crane_height and the cross girders every girder_pitch metres.
@export_range(9.0, 16.0, 0.1, "suffix:m") var wall_height: float = 12.0
@export_range(7.0, 11.0, 0.1, "suffix:m") var band_top: float = 9.0
## Where a runner can touch the wall (wall running reaches about 6 m): below it the wall is calm, as in every wall-running zone: nothing
## stands out of its face more than 4.5 cm (IceLabParts.PROUD), nothing is recessed into it and nothing glows (its screens and status lights
## are dull and flush); above it up to band_top the wall may be deeper and lit (the jars' alcoves, bezelled screens, the machine lamps), and
## from band_top (above every ceiling's top) the machinery's depth, the crane gantry and the hall begin.
@export_range(6.2, 8.0, 0.1, "suffix:m") var calm_top: float = 6.6
@export_range(6.0, 30.0, 0.5, "suffix:m") var hall_extra: float = 14.0
@export_range(13.0, 22.0, 0.1, "suffix:m") var crane_height: float = 16.0
## The hall's roof (IceLabHall): its dim steel and ice underside over the whole hall, high over the cranes (DESIGN-TBD).
@export_range(20.0, 32.0, 0.5, "suffix:m") var roof_height: float = 25.0
@export_range(10.0, 40.0, 0.5, "suffix:m") var girder_pitch: float = 20.0
## The wall bays' share of lit amber lamps (a lamp on this share of the bays, from lamp_min_height up).
@export_range(0.0, 1.0, 0.01) var lamp_share: float = 0.45
## The share of jar bays whose middle jar is an Octodog's, scaled by the lean (DESIGN-TBD, docs/questions/q2.md item 6).
@export_range(0.0, 1.0, 0.01) var octodog_in_jar_share: float = 0.15
## The share of 40 m chunks a side whose far wall carries a crystal cluster, at each end of the lean.
@export_range(0.0, 1.0, 0.01) var crystal_frost: float = 0.8
@export_range(0.0, 1.0, 0.01) var crystal_lab: float = 0.3

@export_group("Steel")
## Frost-crusted black steel (plating, girders, pipes), a lighter one for the machinery's frames, the clean-room tile and the cabinets'
## enamel, the racks' faces, the doors, the brains and the Octodog's metal legs.
@export var steel_color: Color = Color(0.16, 0.19, 0.24)
@export var frame_color: Color = Color(0.25, 0.29, 0.35)
@export var tile_color: Color = Color(0.3, 0.37, 0.44)
@export var enamel_color: Color = Color(0.17, 0.21, 0.26)
@export var rack_color: Color = Color(0.13, 0.15, 0.19)
@export var door_color: Color = Color(0.22, 0.27, 0.32)
@export var brain_color: Color = Color(0.5, 0.43, 0.46)

@export_group("Ceilings")
## DESIGN-TBD (docs/questions/q2.md item 7): relative weights of the two kinds (GDD §5: crane gantries and overhead walkways), at each
## end of the lean (the gantry the industrial one, the walkway the lab's).
@export_range(0.0, 10.0, 0.1) var gantry_weight_frost: float = 3.0
@export_range(0.0, 10.0, 0.1) var gantry_weight_lab: float = 1.0
@export_range(0.0, 10.0, 0.1) var walkway_weight_frost: float = 1.0
@export_range(0.0, 10.0, 0.1) var walkway_weight_lab: float = 3.0

@export_group("Hazards")
## Pink crackle always means electric fence (GDD §5).
@export var fence_color: Color = Color(1.0, 0.18, 0.62)
## The frosted steel posts the fences hang from.
@export var post_color: Color = Color(0.17, 0.2, 0.25)
## Signs: the yellow/black hazard frame around a frosted dead panel.
@export var sign_frame_color: Color = Color(1.0, 0.8, 0.15)
@export var sign_content_colors: PackedColorArray = PackedColorArray([
	Color(0.12, 0.15, 0.19), Color(0.09, 0.12, 0.16), Color(0.16, 0.2, 0.25)])

@export_group("Pads, ramps, finish")
@export var pad_color: Color = Color(0.1, 1.0, 0.95)
## Height of the anti-grav pad's light column.
@export_range(1.0, 10.0, 0.1, "suffix:m") var pad_beam_height: float = 5.8
@export var ramp_color: Color = Color(0.3, 1.0, 0.35)
## Speed pads share the ramps' green "safe boost" family (MeshKit.speed_strip; FB 49).
@export var speed_pad_color: Color = Color(0.45, 1.0, 0.55)
@export var finish_color: Color = Color(1.0, 1.0, 1.0)
## Dark steel under pads, ramps and the finish gantry.
@export var trigger_metal_color: Color = Color(0.15, 0.17, 0.2)

## Built on first use and shared by every mesh (exports changed later don't reach them).
var _materials: Dictionary = {}
var _floor: IceLabFloor
var _walls: IceLabWalls
var _hall: IceLabHall
var _ceilings: IceLabCeilings
var _props: IceLabProps
var _doodads: IceLabDoodads
## The latest wall face seen (the floor and the walls run before a chunk's ceilings): a ceiling across every lane reaches from
## wall to wall, and a narrow one knows which of its sides reach a wall.
var _wall_x: float = 0.0
## The window cyborgs' tracks on each side, noted just before the walls (note_wall_enemies): no jar alcove stands beside one.
var _reserved: Dictionary = {}


func _init() -> void:
	# GDD §5: its cyborgs wear an existing zone's look until the owner asks for one of their own (the Dead Zone's burned base is the
	# nearest: a cold, ruined look; every other enemy reads it as the clean look, docs/ARCHITECTURE.md, Zone skins). DESIGN-TBD.
	enemy_variant = &"burned"


# --- The lean ---------------------------------------------------------------------------------

## A value at the frost end (`frost`) and the lab end (`lab`) of the lean.
func lean(frost: float, lab: float) -> float:
	return lerpf(frost, lab, lab_share)


func snow_amount() -> float:
	return lean(snow_frost, snow_lab)


func haze() -> Color:
	return fog_color_frost.lerp(fog_color_lab, lab_share)


## The weight of wall bay kind `kind` (IceLabWalls.BAY_*) at this lean.
func bay_weight(kind: int) -> float:
	var a: float = bay_weights_frost[kind] if kind < bay_weights_frost.size() else 0.0
	var b: float = bay_weights_lab[kind] if kind < bay_weights_lab.size() else 0.0
	return lerpf(a, b, lab_share)


func make_environment() -> Environment:
	# The sky's colours as sRGB Vector3s (srgb()), so the sky looks the same on both renderers. No stars, no moon, no skyline (the
	# skyline's colour is the sky's own, so it never shows): the hall is whole.
	var fog: Color = haze()
	var sky := {"zenith_color": srgb(sky_zenith_color), "horizon_color": srgb(fog),
		"haze_color": srgb(fog), "haze_strength": 0.0, "haze_height": 0.2,
		"abyss_color": srgb(fog), "skyline_color": srgb(fog),
		"window_color": srgb(fog), "moon_radius": 0.0, "star_amount": 0.0, "skyline_scale": 0.0,
		"horizon_falloff": 0.55}
	return MeshKit.night_environment(sky, ambient_color, fog, fog_begin, fog_end, fog_max, 0.0,
		glow_intensity, glow_threshold)


# --- The floor ---------------------------------------------------------------------------------

func floor_segment(parent: Node3D, center: Vector3, size: Vector3, lane_x: float,
		edge_start: bool, edge_end: bool) -> void:
	var batch := MeshBatch.new()
	var wall: float = floor_().build(batch, center, size, lane_x, edge_start, edge_end)
	batch.commit(parent)
	if wall > 0.0:
		_wall_x = wall


## A floor cut (task B4; GDD §9.9): the catwalk split open down the lane (IceLabFloor.cut).
func floor_cut(parent: Node3D, cut: FloorCutSection) -> void:
	floor_().cut(parent, cut)


# --- The walls ---------------------------------------------------------------------------------

## A wall section: bays of lab machinery (IceLabWalls), and with the left wall the hall beyond the street (IceLabHall).
func wall_section(parent: Node3D, side: int, face_x: float, start: float, end: float) -> void:
	_wall_x = absf(face_x)
	var batch := MeshBatch.new()
	walls().build(batch, side, face_x, start, end)
	if side < 0:
		hall().build(batch, absf(face_x), start, end)
	batch.commit(parent)


## With the left wall of a wall gap (ZoneSkin.wall_gap_extras), the hall beyond (no gantry from a missing wall).
func wall_gap_extras(batch: MeshBatch, side: int, face_x: float, start: float, end: float) -> void:
	_wall_x = absf(face_x)
	if side < 0:
		hall().build(batch, absf(face_x), start, end)


## What a wall gap shows behind it (ZoneSkin.wall_gap_recess, task L4): where the machinery wall is left out between two bays, the
## ends of the cut wall, the hall's far ice wall across and the frozen floor (IceLabWalls.recess).
func wall_gap_recess(batch: MeshBatch, side: int, face_x: float, start: float, end: float, gap: Vector2) -> void:
	walls().recess(batch, side, face_x, start, end, gap)


## The window cyborgs on each side about to be built (ZoneSkin.note_wall_enemies): their tracks, so no jar alcove opens beside one
## (a window cyborg's window must be the only opening in the wall, readability rules).
func note_wall_enemies(side: int, _start: float, _end: float, enemies: Array[Dictionary]) -> void:
	var spans := PackedFloat32Array()
	for e: Dictionary in enemies:
		if String(e.get("type", "")) == "window_cyborg" and int(e.get("side", 0)) == side:
			spans.append(float(e.get("at", 0.0)))
	_reserved[side] = spans


## True if a window cyborg on `side` stands within `margin` of track distance `at`.
func reserved_near(side: int, at: float, margin: float) -> bool:
	for a: float in _reserved.get(side, PackedFloat32Array()):
		if absf(a - at) <= margin:
			return true
	return false


# --- Hazards, ceilings, triggers ------------------------------------------------------------------

func fence(hazard: Hazard, size: Vector3, ground_y: float, gapped: bool) -> void:
	props().fence(hazard, size, ground_y, gapped)


func wall_sign(hazard: Hazard, size: Vector3) -> void:
	props().wall_sign(hazard, size)


## A ceiling over its lanes (IceLabCeilings: GDD §5, crane gantries and overhead grated walkways), each built from the lanes it covers.
func ceiling_section(parent: Node3D, section: CeilingSection) -> void:
	ceilings().build(parent, section.center, section.size, section.lane_edges_x, section.wall_x)


## A ceiling given as its collision box alone: which of its sides reach a wall comes from the box and the walls seen last.
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


## Brain jars, lab equipment, ice crystal clusters and crates of lab supplies, and the Octodog jar (IceLabDoodads, picture cards; GDD
## §3: "brain jars and other lab equipment", §5: some jars hold a curled-up Octodog), by the lean.
func doodad(body: Node3D, size: Vector3, size_class: StringName, side: int, look_seed: int) -> void:
	doodads().build(body, size, size_class, side, look_seed)


# --- Falling gantryways (task Q3) --------------------------------------------------------------------

## A falling gantryway's colours (ZoneSkin.gantryway, gantry_pillar, gantryway_wreck; GDD §5, Zone 9: "an upper walkway over one
## lane only, looking like a ceiling section"): the default frosted steel catwalk (GantrywayKit) in this hall's own steel, frame,
## frost, snow and ice, so it reads as one of its overhead walkways (IceLabCeilings). No lamp and nothing that glows: its warning is
## the gantryway's own, the same in every zone. DESIGN-TBD (docs/questions/q3.md): a look of its own, from the ceilings' kit.
func gantryway_colors() -> PackedColorArray:
	return PackedColorArray([steel_color, frame_color, frost_color, snow_color, ice_color])


## The kit's gantryway material (it dissolves near the camera, as every gantryway look must) with this hall's sky sheen.
func gantryway_material() -> Material:
	return GantrywayKit.material({"sheen_color": srgb(sheen_color), "sheen_strength": sheen_strength})


# --- Shared materials (built once per skin, shared by every mesh) ------------------------------------

func solid_material() -> ShaderMaterial:
	if not _materials.has(&"solid"):
		_materials[&"solid"] = MeshKit.solid(_solid_params())
	return _materials[&"solid"]


func glow_material() -> ShaderMaterial:
	if not _materials.has(&"glow"):
		_materials[&"glow"] = MeshKit.glow({"fade_begin": fog_begin + 20.0, "fade_end": fog_end})
	return _materials[&"glow"]


## The glow of a machine lamp on the renderer in use (lamp_glow, lamp_glow_compat).
func lamp_tube_glow() -> float:
	return lamp_glow_compat if is_compat() else lamp_glow


## The glow of a screen or a status LED on the renderer in use.
func screen_tube_glow() -> float:
	return screen_glow_compat if is_compat() else screen_glow


## The glow of a jar's liquid on the renderer in use.
func liquid_tube_glow() -> float:
	return liquid_glow_compat if is_compat() else liquid_glow


static func is_compat() -> bool:
	return RenderingServer.get_current_rendering_method() == "gl_compatibility"


## The steam, snow and dust drifting through the hall (drift.gdshader): scenery, dimmed by a level's darker lighting like the rest.
func drift_material() -> ShaderMaterial:
	if not _materials.has(&"drift"):
		_materials[&"drift"] = MeshKit.material("drift.gdshader", {
			"slice_length": TrackBuilder.CHUNK_LENGTH, "ash_speed": snow_speed, "streak_speed": streak_speed})
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


## A colour for this skin's shader uniforms: its sRGB values as a Vector3. Godot converts a Color set on a colour uniform to linear
## on Forward+ (not on the Compatibility renderer), and the kit's shaders convert once more (to_linear); as a Vector3 it arrives as
## authored on both renderers and is converted once, like a vertex colour, so the two renderers match (docs/ARCHITECTURE.md, Zone
## skins).
static func srgb(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)


func _solid_params() -> Dictionary:
	return {"glow_scale": emissive_scale, "sheen_color": srgb(sheen_color), "sheen_strength": sheen_strength,
		"il_ice": srgb(ice_color), "il_snow": srgb(snow_color), "il_frost": srgb(frost_color), "il_liquid": srgb(liquid_color),
		"il_screen": srgb(screen_color), "il_snow_amount": snow_amount(), "il_lab": lab_share}


func floor_() -> IceLabFloor:
	if _floor == null:
		_floor = IceLabFloor.new(self)
	return _floor


func walls() -> IceLabWalls:
	if _walls == null:
		_walls = IceLabWalls.new(self)
	return _walls


func hall() -> IceLabHall:
	if _hall == null:
		_hall = IceLabHall.new(self)
	return _hall


func ceilings() -> IceLabCeilings:
	if _ceilings == null:
		_ceilings = IceLabCeilings.new(self)
	return _ceilings


func props() -> IceLabProps:
	if _props == null:
		_props = IceLabProps.new(self)
	return _props


func doodads() -> IceLabDoodads:
	if _doodads == null:
		_doodads = IceLabDoodads.new(self)
	return _doodads

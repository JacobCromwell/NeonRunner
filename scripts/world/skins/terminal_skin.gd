class_name TerminalSkin
extends ZoneSkin
## Zone 8, the Terminal (GDD §5, owner, October 20, 2026; reference image docs/art/reference/terminal_zone.jpg; task
## O4): an abandoned subway under the city, wet black stone, rust and verdigris, vine green, sodium lamplight
## through haze, used only by a few scavengers and the cybernetic centipedes that hunt there. Underground:
## there is no sky, only a dark vaulted hall over the street that the lamps never quite reach.
## The runner's street is the hall's track bed: every lane but the outer two is a lane of track bed (ballast,
## sleepers, a pair of rails, snaking cables, puddles), the outer two the platform along each wall (worn concrete
## with a strip of pale studs on the edge that faces the track); gaps are holes in the track bed, the orange gap
## edge right on the collision edge and a dark service level below (TerminalTrack).
## Beyond a low kerb on each side stands the rest of the hall, which the runner only sees (TerminalHall): a second
## track with rusted, vine-grown subway cars parked on it in stretches, the far wall (old white tile under black
## ashlar, pipes, dead boards, work lamps), the vault overhead on steel ribs with a work lamp hanging from each,
## strung cables and steam. The hall is drawn by the floor, whatever the walls do, so that the open spaces between
## the arches read as open.
## The side walls are narrow arches (GDD §5: each wall section one space wide with about six lengths of open space
## between, mostly in pairs; TerminalArches): a riveted steel pier from the floor up into the vault, a rib springing
## from its head over the street. Where one is missing there is a broken stump about half its height, a ruin
## (wall_stump, which ZoneSkin gains in task O1). Ceilings are few and always one lane wide (TerminalCeilings): the
## underside of a fallen girder, a hanging maintenance walkway or a stranded car's roof. The doodads are debris
## (TerminalDoodads, picture cards, lower than other zones' ones).
## Colour rule (GDD §5, looser in the later zones, the owner, October 20, 2026: "it's ok if the color palette conflicts a
## bit with the rules"): the work lamps are orange, as the owner first asked and the reference shows, a sodium amber, and the
## hazards keep their colours and shapes. A lamp is told from a gap edge by its hue (yellower: amber against the edge's
## red-orange), its glow (a fraction of the edge's and under the bloom threshold, which the edge is over, so edges bloom and
## lamps do not) and its height (up in the vault and on the far walls, never at floor level); the red-orange plates are dull and
## matte, and signs carry no words. Nothing glows but the work lamps, hazards, triggers and the orange ends of ceilings and gaps.
## The hall is dark: the hazards stay the brightest, most saturated things on screen.
## Reduced flashing: the failing lamps' brownouts are a slow smooth dip (every few seconds, never a strobe) and hold
## still with Reduced flashing (kit_terminal.gdshaderinc, tm_burn: the global `reduced_flashing`).
## No dash walls (GDD §5, §9.14: its debris is enough): the base's default look stands, and `test_dash_walls` lists this skin among
## the ones that keep it.
## Visuals only: TrackBuilder owns every collision shape and gameplay node, and all variety comes from hashing track
## positions (MeshKit.hash_i), so a chunk looks the same whenever it is built.
## DESIGN-TBD (docs/questions/o4.md): the hall's proportions, the colours, the doodads' looks, the scavengers.

@export_group("Environment")
## The sky nobody sees (the vault is whole): near black, and the horizon the colour the fog fades the street's far end
## into, so the tunnel runs out into a warm haze.
@export var sky_zenith_color: Color = Color(0.016, 0.013, 0.011)
@export var sky_horizon_color: Color = Color(0.2, 0.115, 0.06)
## The light on everything lit by the engine (the runner, the enemies, the centipede): a warm, dim grey.
@export var ambient_color: Color = Color(0.6, 0.52, 0.46)
## Distant geometry fades into the haze between fog_begin and fog_end: sodium-orange through the steam.
@export var fog_color: Color = Color(0.2, 0.115, 0.06)
@export_range(0.0, 150.0, 1.0, "suffix:m") var fog_begin: float = 14.0
@export_range(50.0, 400.0, 5.0, "suffix:m") var fog_end: float = 170.0
@export_range(0.0, 1.0, 0.01) var fog_max: float = 1.0
@export_range(0.0, 2.0, 0.05) var glow_intensity: float = 0.7
@export_range(0.5, 4.0, 0.05) var glow_threshold: float = 1.1
## Brightness of emissive kit parts (vertex glow 1.0 = this many times the albedo).
@export_range(1.0, 20.0, 0.5) var emissive_scale: float = 4.0
## The haze caught at grazing angles by the stone and the steel.
@export var sheen_color: Color = Color(0.3, 0.2, 0.12)
@export_range(0.0, 1.0, 0.01) var sheen_strength: float = 0.14

@export_group("Light")
## DESIGN-TBD (docs/questions/o4.md item 5): how dark the hall is, and how bright and how many the lamps are. (The lamps'
## colour is the owner's: orange.)
## The work lamps (GDD §5: a few failing orange work lamps): a sodium amber, yellower than a gap edge's red-orange, and their
## light on the stone is painted the same colour (tm_lit). Hung from the
## vault every lamp_pitch metres, lamp_height up; a fifth are dead, a third failing, by a hash of their index
## (kit_terminal.gdshaderinc tm_burn), and the far walls carry lamps of their own half a pitch off, wall_lamp_height up.
@export var lamp_color: Color = Color(0.98, 0.6, 0.08)
@export_range(8.0, 40.0, 0.5, "suffix:m") var lamp_pitch: float = 18.0
@export_range(6.0, 12.0, 0.1, "suffix:m") var lamp_height: float = 8.4
@export_range(2.0, 7.0, 0.1, "suffix:m") var wall_lamp_height: float = 4.4
## How much of the lamps' light the scenery takes (0: none).
@export_range(0.0, 2.0, 0.05) var lamp_gain: float = 1.0
## The lamps' own glow (vertex glow, times emissive_scale): kept under the bloom threshold and a fraction of a gap edge's, so a
## lamp is a dim amber tube that never blooms: a hazard's glare stays the hazards'.
@export_range(0.0, 0.6, 0.01) var lamp_glow: float = 0.09
## The same on the Compatibility renderer (web, low-end Android), which scales emissive colours in sRGB space where the
## others scale them in linear space: the same number draws far dimmer there, so this one draws about as bright as lamp_glow does
## on the others (and, like it, a fraction of a gap edge's, under the bloom threshold).
@export_range(0.0, 0.6, 0.01) var lamp_glow_compat: float = 0.16
## What wet stone and puddles give back of the haze, and how wet it all is (0 dry).
@export var haze_color: Color = Color(0.42, 0.26, 0.14)
@export_range(0.0, 1.0, 0.05) var wetness: float = 0.7

@export_group("Track bed")
## The ballast (lit and patterned by PAT_TERMINAL_TRACK) and the platform's concrete: pale enough that every hole
## is far darker than the street around it.
@export var ballast_color: Color = Color(0.3, 0.285, 0.265)
@export var platform_color: Color = Color(0.31, 0.3, 0.285)
## The seam between the platform lane and the kerb (the gutter), a touch darker.
@export var gutter_color: Color = Color(0.27, 0.26, 0.245)
## Everything below the track bed, seen only through holes and cuts: dim, and darkening with depth (PAT_TERMINAL_UNDER).
@export var gap_inside_color: Color = Color(0.068, 0.063, 0.058)
## The service level's floor far below (a top face, which the kit lights more than a wall: darker).
@export var pit_floor_color: Color = Color(0.055, 0.05, 0.048)
## How far below the street the service level lies (deeper than a fall that ends a run, so a fall never visibly lands).
@export_range(4.5, 20.0, 0.1, "suffix:m") var pit_depth: float = 7.0
## Gap edges: the orange edge language of every zone. Redder than it looks: the glow and the tonemapper lift the
## green, and it must stay orange, not sign yellow.
@export var gap_edge_color: Color = Color(1.0, 0.25, 0.04)
## A soft orange halo along the far edge of a hole, facing the approaching runner (additive).
@export_range(0.0, 1.0, 0.01) var edge_halo: float = 0.25

@export_group("Motion")
## The still floor's motion cues (the owner's review: every still floor gets them): per 40 m of track, flecks of dust
## drifting in the lamplight, puffs of steam drifting low, and speed streaks (a = opacity).
@export_range(0, 200, 1) var dust_count: int = 50
@export_range(0, 40, 1) var steam_count: int = 8
@export_range(0, 60, 1) var streak_count: int = 10
@export var dust_color: Color = Color(0.75, 0.62, 0.5, 0.55)
@export var steam_color: Color = Color(0.5, 0.4, 0.33, 0.2)
## Plumes of steam leaking from the old pipes beyond the walls (soft smoke, scenery only: alpha-blended, never glowing, and not
## a light column like a pad's beam): the share of 10 m cells, a side, with one, their colour and how opaque they are at the core.
@export_range(0.0, 1.0, 0.01) var jet_share: float = 0.12
@export var steam_jet_color: Color = Color(0.62, 0.5, 0.4)
@export_range(0.0, 1.0, 0.01) var jet_opacity: float = 0.3
## The same on the Compatibility renderer (web, low-end Android), which blends in sRGB space and so shows the same alpha far
## fainter over the dark hall: this much there looks about as strong as jet_opacity does on the others.
@export_range(0.0, 1.0, 0.01) var jet_opacity_compat: float = 0.5
@export var streak_color: Color = Color(0.72, 0.6, 0.48, 0.2)
@export_range(0.0, 30.0, 0.5, "suffix:m/s") var dust_speed: float = 4.0
@export_range(0.0, 80.0, 0.5, "suffix:m/s") var streak_speed: float = 24.0

@export_group("Hall")
## The hall's shape (DESIGN-TBD, docs/questions/o4.md): the far wall stands this far beyond the street's wall line, the
## vault springs from it at spring_height and rises to crown_height over the middle of the street; the second track
## lies track_drop below the street's level, beyond a kerb kerb_height high.
@export_range(4.0, 14.0, 0.1, "suffix:m") var hall_extra: float = 7.6
@export_range(5.0, 10.0, 0.1, "suffix:m") var spring_height: float = 7.0
@export_range(9.0, 18.0, 0.1, "suffix:m") var crown_height: float = 12.6
@export_range(0.4, 2.0, 0.05, "suffix:m") var track_drop: float = 1.0
@export_range(0.2, 1.0, 0.05, "suffix:m") var kerb_height: float = 0.55
## The far wall's black ashlar, the old white tile at its foot, the vault's stone and the plain old concrete.
@export var stone_color: Color = Color(0.2, 0.185, 0.175)
@export var tile_color: Color = Color(0.3, 0.29, 0.26)
@export var vault_color: Color = Color(0.19, 0.175, 0.165)
@export var concrete_color: Color = Color(0.26, 0.25, 0.235)
## Old painted steel: the verdigris green the piers, ribs and girders were painted, the rust under it.
@export var steel_color: Color = Color(0.14, 0.23, 0.2)
@export var rust_color: Color = Color(0.29, 0.18, 0.125)
## The vines (opaque foliage) and the subway cars' flaking paint.
@export var vine_color: Color = Color(0.14, 0.27, 0.09)
@export var car_colors: PackedColorArray = PackedColorArray([
	Color(0.2, 0.23, 0.2), Color(0.24, 0.2, 0.16), Color(0.18, 0.22, 0.22)])
## The share of the second track's stretches with a train on it, and how many cars a train has at most.
@export_range(0.0, 1.0, 0.01) var train_share: float = 0.55
@export_range(1, 6) var train_cars: int = 4
## Dead departure boards (matte, unlit, wordless) and rust-red enamel plates on the piers (a painted border and four bolts:
## no symbol, DESIGN-TBD docs/questions/o4.md item 5).
@export var board_frame_color: Color = Color(0.14, 0.13, 0.12)
@export var plate_color: Color = Color(0.3, 0.125, 0.095)

@export_group("Scavengers")
## DESIGN-TBD (docs/questions/o4.md): GDD §5 gives the Terminal "a few scavengers", scenery only like the Marketplace's citizens
## (proposed): the share of 130 m blocks, a side, with a camp on the second track (a fire barrel with dim embers and three still
## silhouettes), and the embers' colour and glow (dimmer than a work lamp's, and far below a gap edge's).
@export_range(0.0, 1.0, 0.01) var camp_share: float = 0.4
@export var ember_color: Color = Color(0.7, 0.4, 0.2)
@export_range(0.0, 0.3, 0.01) var ember_glow: float = 0.14

@export_group("Arches")
## A pier's depth beyond the wall line, the longest it is along the track (a longer wall section gets several), and
## how far apart those are.
@export_range(0.8, 3.0, 0.05, "suffix:m") var pier_depth: float = 1.6
@export_range(1.5, 6.0, 0.1, "suffix:m") var pier_width: float = 3.0
@export_range(8.0, 40.0, 0.5, "suffix:m") var pier_pitch: float = 22.0

@export_group("Ceilings")
## DESIGN-TBD (docs/questions/o4.md): relative weights of the three kinds (GDD §5: the underside of a fallen girder, a
## hanging walkway, a stranded subway car's roof).
@export_range(0.0, 10.0, 0.1) var girder_weight: float = 3.0
@export_range(0.0, 10.0, 0.1) var walkway_weight: float = 2.0
@export_range(0.0, 10.0, 0.1) var car_weight: float = 2.5

@export_group("Hazards")
## Pink crackle always means electric fence (GDD §5).
@export var fence_color: Color = Color(1.0, 0.18, 0.62)
## The rusted steel posts the fences hang from.
@export var post_color: Color = Color(0.2, 0.17, 0.15)
## Signs: the yellow/black hazard frame around a dead board.
@export var sign_frame_color: Color = Color(1.0, 0.8, 0.15)
@export var sign_content_colors: PackedColorArray = PackedColorArray([
	Color(0.14, 0.14, 0.13), Color(0.1, 0.11, 0.11), Color(0.17, 0.16, 0.14)])

@export_group("Pads, ramps, finish")
@export var pad_color: Color = Color(0.1, 1.0, 0.95)
## Height of the anti-grav pad's light column.
@export_range(1.0, 10.0, 0.1, "suffix:m") var pad_beam_height: float = 5.8
@export var ramp_color: Color = Color(0.3, 1.0, 0.35)
## Speed pads share the ramps' green "safe boost" family (MeshKit.speed_strip; FB 49).
@export var speed_pad_color: Color = Color(0.45, 1.0, 0.55)
@export var finish_color: Color = Color(1.0, 1.0, 1.0)
## Rusted steel under pads, ramps and the finish gantry.
@export var trigger_metal_color: Color = Color(0.17, 0.15, 0.13)

## Built on first use and shared by every mesh (exports changed later don't reach them).
var _materials: Dictionary = {}
var _track: TerminalTrack
var _hall: TerminalHall
var _arches: TerminalArches
var _ceilings: TerminalCeilings
var _props: TerminalProps
var _doodads: TerminalDoodads
## The latest wall face seen (the floor and the walls run before a chunk's ceilings): a ceiling across every lane
## reaches from wall to wall, and a narrow one knows which of its sides reach a wall.
var _wall_x: float = 0.0
## The latest lane's half width, from its floor box (the hall's second track is drawn with the street's lanes' pattern).
var _lane_half: float = 0.0


func _init() -> void:
	# GDD §9.2: the Terminal has no cyborgs, but anything that does turn up there wears the Dead Zone's burned base
	# (CyborgSuit's burned look); every other enemy reads it as the clean look (docs/ARCHITECTURE.md, Zone skins).
	enemy_variant = &"burned"


func make_environment() -> Environment:
	# The sky's colours as sRGB Vector3s (srgb()), so the sky looks the same on both renderers. No stars, no moon, no
	# skyline (the skyline's colour is the sky's own, so it never shows): the vault is whole.
	var sky := {"zenith_color": srgb(sky_zenith_color), "horizon_color": srgb(sky_horizon_color),
		"haze_color": srgb(sky_horizon_color), "haze_strength": 0.0, "haze_height": 0.2,
		"abyss_color": srgb(sky_horizon_color), "skyline_color": srgb(sky_horizon_color),
		"window_color": srgb(sky_horizon_color), "moon_radius": 0.0, "star_amount": 0.0, "skyline_scale": 0.0,
		"horizon_falloff": 0.55}
	return MeshKit.night_environment(sky, ambient_color, fog_color, fog_begin, fog_end, fog_max, 0.0,
		glow_intensity, glow_threshold)


# --- The floor ---------------------------------------------------------------------------------

func floor_segment(parent: Node3D, center: Vector3, size: Vector3, lane_x: float,
		edge_start: bool, edge_end: bool) -> void:
	var batch := MeshBatch.new()
	var wall: float = track().build(batch, center, size, lane_x, edge_start, edge_end)
	batch.commit(parent)
	if wall > 0.0:
		_wall_x = wall
	# The lane's width is the floor box's own (never the tuning's: a skin is not given it), for the hall's second track.
	var half: float = TerminalTrack.half_lane(center, size, lane_x)
	if half > 0.0:
		_lane_half = half
	# The hall beyond the walls comes with the floor, whatever the walls do (the arches are a few and far between), once per
	# chunk: under the chunk's root, never under the slice of a floor cut, which the cut hides or shortens as it runs.
	if _wall_x > 0.0:
		hall().ensure(chunk_root(parent), _wall_x, _lane_half, -(center.z + size.z * 0.5), -(center.z - size.z * 0.5))


## The node a floor piece's hall hangs from: the chunk's root, the child of the TrackBuilder that `node` is or lies under. A
## floor cut draws its lane's floor in slices, each under a node of its own beneath the chunk (TrackBuilder._build_cut_slices;
## the names Godot gives the slices after the first aren't a reliable mark), which the cut hides or shortens as it runs: the
## hall must outlive them. Outside a track (a stage, a test, a review tool) it is `node` itself.
static func chunk_root(node: Node3D) -> Node3D:
	var at: Node = node
	while at != null and not (at.get_parent() is TrackBuilder):
		at = at.get_parent()
	return (at as Node3D) if at != null else node


## A floor cut (task B4; GDD §9.9): the track bed split open down the lane (TerminalTrack.cut).
func floor_cut(parent: Node3D, cut: FloorCutSection) -> void:
	track().cut(parent, cut)


# --- The walls: arches -------------------------------------------------------------------------

## A wall section: an arch, a riveted steel pier from the floor into the vault with a rib springing from its head
## (TerminalArches). O1's track builder gives sections one space long; a longer one gets several, so the skin also
## works with the wall every other zone has. The hall is the floor's (floor_segment), not the walls': an arch only draws
## itself, whole, in the chunk where it starts.
func wall_section(parent: Node3D, side: int, face_x: float, start: float, end: float) -> void:
	_wall_x = absf(face_x)
	var batch := MeshBatch.new()
	arches().build(batch, side, face_x, start, end)
	batch.commit(parent)


## A broken arch (task O1 adds this hook to ZoneSkin, with a plain default; GDD §5: where one side's section is missing, a
## section cut off about halfway up, as if it had deteriorated over time or fallen in an earthquake, a crumbled ruin):
## the pier broken off about halfway up, crumbled, with rebar and rubble at its foot (TerminalArches.stump).
func wall_stump(parent: Node3D, side: int, face_x: float, start: float, end: float) -> void:
	_wall_x = absf(face_x)
	var batch := MeshBatch.new()
	arches().stump(batch, side, face_x, start, end)
	batch.commit(parent)


## The open space between two arches (task O1 adds this hook to ZoneSkin, called once per chunk it reaches, in place of
## wall_gap where a level has no wall running): the hall beyond, which the floor draws (TerminalHall), so nothing more. A
## plain wall behind the arches, which ZoneSkin's default draws, would hide it.
func wall_opening(_parent: Node3D, _side: int, face_x: float, _start: float, _end: float, _gap: Vector2) -> void:
	_wall_x = absf(face_x)


# Wall gaps keep the base look (wall_gap_marks, wall_gap_recess): the TrackBuilder calls wall_gap only in a level
# with wall running, where a gap's orange marks are the warning that the wall-running surface stops (this skin on any
# other level, e.g. quick play's --skin=terminal). The Terminal's own levels have no wall running and call
# wall_opening instead, above.


# --- Hazards, ceilings, triggers ------------------------------------------------------------------

func fence(hazard: Hazard, size: Vector3, ground_y: float, gapped: bool) -> void:
	props().fence(hazard, size, ground_y, gapped)


func wall_sign(hazard: Hazard, size: Vector3) -> void:
	props().wall_sign(hazard, size)


## A ceiling over its lanes (TerminalCeilings: GDD §5, the underside of a fallen girder, a hanging maintenance walkway or
## a stranded subway car's roof), each built from the lanes it covers.
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


## Debris (TerminalDoodads, picture cards; GDD §3: a heap of broken concrete and rebar, a toppled ticket kiosk or vending
## machine, fallen ceiling slabs, cable drums and crates), lower than other zones' doodads (task O2 sets the boxes).
func doodad(body: Node3D, size: Vector3, size_class: StringName, side: int, look_seed: int) -> void:
	doodads().build(body, size, size_class, side, look_seed)


# --- Shared materials (built once per skin, shared by every mesh) ------------------------------------

func solid_material() -> ShaderMaterial:
	if not _materials.has(&"solid"):
		_materials[&"solid"] = MeshKit.solid(_solid_params())
	return _materials[&"solid"]


func glow_material() -> ShaderMaterial:
	if not _materials.has(&"glow"):
		_materials[&"glow"] = MeshKit.glow({"fade_begin": fog_begin + 20.0, "fade_end": fog_end})
	return _materials[&"glow"]


## The glow of a work lamp's tube on the renderer in use (lamp_glow, lamp_glow_compat).
func lamp_tube_glow() -> float:
	return lamp_glow_compat if RenderingServer.get_current_rendering_method() == "gl_compatibility" else lamp_glow


## How opaque the steam plumes are at their core on the renderer in use (jet_opacity, jet_opacity_compat).
func plume_opacity() -> float:
	return jet_opacity_compat if RenderingServer.get_current_rendering_method() == "gl_compatibility" else jet_opacity


## The plumes of steam leaking from the old pipes (the kit's smoke shader, dead_smoke.gdshader): scenery, dimmed by a level's
## darker lighting like the rest, and never flashing.
func smoke_material() -> ShaderMaterial:
	if not _materials.has(&"smoke"):
		_materials[&"smoke"] = MeshKit.material("dead_smoke.gdshader", {"rise_speed": 0.9})
	return _materials[&"smoke"]


## The steam and dust drifting through the hall (drift.gdshader): scenery, dimmed by a level's darker lighting like the rest.
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


## A colour for this skin's shader uniforms: its sRGB values as a Vector3. Godot converts a Color set on a colour
## uniform to linear on Forward+ (not on the Compatibility renderer), and the kit's shaders convert once more
## (to_linear); as a Vector3 it arrives as authored on both renderers and is converted once, like a vertex colour, so
## the two renderers match (docs/ARCHITECTURE.md, Zone skins).
static func srgb(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)


func _solid_params() -> Dictionary:
	return {"glow_scale": emissive_scale, "sheen_color": srgb(sheen_color), "sheen_strength": sheen_strength,
		"tm_lamp": srgb(lamp_color), "tm_haze": srgb(haze_color), "tm_rust": srgb(rust_color),
		"tm_green": srgb(steel_color), "tm_vine": srgb(vine_color), "tm_wet": wetness,
		"tm_pitch": lamp_pitch, "tm_lamp_y": lamp_height, "tm_wall_lamp_y": wall_lamp_height,
		"tm_lamp_gain": lamp_gain}


func track() -> TerminalTrack:
	if _track == null:
		_track = TerminalTrack.new(self)
	return _track


func hall() -> TerminalHall:
	if _hall == null:
		_hall = TerminalHall.new(self)
	return _hall


func arches() -> TerminalArches:
	if _arches == null:
		_arches = TerminalArches.new(self)
	return _arches


func ceilings() -> TerminalCeilings:
	if _ceilings == null:
		_ceilings = TerminalCeilings.new(self)
	return _ceilings


func props() -> TerminalProps:
	if _props == null:
		_props = TerminalProps.new(self)
	return _props


func doodads() -> TerminalDoodads:
	if _doodads == null:
		_doodads = TerminalDoodads.new(self)
	return _doodads

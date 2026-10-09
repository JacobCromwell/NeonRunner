class_name GoldenSkin
extends ZoneSkin
## Zone 6, the Golden Zone (GDD §5, §11): the city strictly for the elites and corporate bosses and
## home of the final boss, in decadent opulence: a white and slightly creamy base with red and gold
## accents, the gold reflective metal (never glowing neon), the red deep and unlit. The same future as
## every zone, in its dominant shapes: towers of champagne mirror glass on gold mullions under glazed
## crowns, palaces clad in seamless white panels with tall rounded smart-glass windows, sky bridges
## slung between the towers, hover-yachts.
## Floor segments are golden walkways over water (GoldenWalkways): a deck of burnished gold plates per
## lane between polished rails, a dark joint between neighbouring walkways; gaps are drops to the dark
## canal far below, with the orange edge glow on the collision edge as in every zone. The walkways
## stand still, so their plate seams, mist, drifting gold leaf and speed streaks carry the sense of
## speed (the owner's review: every still floor gets motion cues), and the canal flows in the gaps.
## Walls are opulent facades (GoldenFacades) whose wall-run band stays calm and flush; their palace
## bases carry golden statues holding halberds (the statue kit, GoldenStatue, shared with the Gilded
## Sentinels, task C4). A live Sentinel still stands in its wall-run-height niche, so the mesh-only
## base statues give it the same silhouette instead of advertising the dangerous placement from a ledge.
## Signs are boutique boards in the yellow/black hazard frame (GoldenProps); fences are the same pink
## field between gold stanchions. Ceilings (GoldenCeilings) are the undersides of golden bridges (some
## with water falling off their faces), galleries of golden arches and the elite's hover-yachts, each
## built from the lanes it covers.
## The cult is shown openly here (GDD §5): its emblem (the owner's pick, drawn by CultEmblem) is large
## and polished gold meeting at a small red centre stone, on red banners, on reliefs facing the
## approach (bridges, sky bridges, the towers' setbacks) and on medallions inlaid in the walkways; its
## feed (CultFeed) plays in gilded frames above the band and on big screens hung over the street.
## Colour rule (GDD §5): gold, red, cream and white stay lit and below the hazards' saturation, the
## only decorative glows are warm-white lamps and lit windows, so pink, yellow and black, red, orange,
## green and cyan keep their meaning and hazards stay the most saturated, brightest things on screen.
## Visuals only: TrackBuilder owns every collision shape and gameplay node, and all variety comes
## from hashing track positions (MeshKit.hash_i), so a chunk looks the same whenever it is built.

@export_group("Environment")
## DESIGN-TBD (docs/questions/d6a.md): the GDD gives the Golden Zone's palette and mood, not its time
## of day. The blue hour: a deep blue sky over the warm afterglow of the set sun, the white palaces
## floodlit and their gold gleaming against the dusk, the hazards' glow popping.
@export var sky_zenith_color: Color = Color(0.1, 0.14, 0.3)
@export var sky_horizon_color: Color = Color(0.56, 0.48, 0.52)
## The afterglow over the horizon.
@export var haze_color: Color = Color(0.92, 0.64, 0.46)
@export_range(0.0, 2.0, 0.05) var haze_strength: float = 0.4
@export var abyss_color: Color = Color(0.06, 0.06, 0.1)
## The far skyline: dark towers against the afterglow, glittering with warm windows.
@export var skyline_color: Color = Color(0.17, 0.18, 0.27)
@export var skyline_window_color: Color = Color(0.98, 0.86, 0.64)
## The moon (the sky shader's), high to one side over the far end of the street.
@export var moon_color: Color = Color(0.93, 0.92, 0.88)
@export var moon_direction: Vector3 = Vector3(-0.32, 0.36, -0.88)
@export_range(0.0, 0.3, 0.005) var moon_radius: float = 0.03
@export_range(0.0, 1.0, 0.01) var moon_clarity: float = 0.85
@export var ambient_color: Color = Color(0.62, 0.62, 0.72)
## Distant geometry fades into the dusk's haze between fog_begin and fog_end.
@export var fog_color: Color = Color(0.3, 0.29, 0.36)
@export_range(0.0, 150.0, 1.0, "suffix:m") var fog_begin: float = 26.0
@export_range(50.0, 400.0, 5.0, "suffix:m") var fog_end: float = 230.0
@export_range(0.0, 1.0, 0.01) var fog_max: float = 0.92
@export_range(0.0, 2.0, 0.05) var glow_intensity: float = 0.7
@export_range(0.5, 4.0, 0.05) var glow_threshold: float = 1.1
## Brightness of emissive kit parts (vertex glow 1.0 = this many times the albedo).
@export_range(1.0, 20.0, 0.5) var emissive_scale: float = 4.0
## The dusk sky caught at grazing angles by the walkways, walls and undersides.
@export var sheen_color: Color = Color(0.46, 0.46, 0.6)
@export_range(0.0, 1.0, 0.01) var sheen_strength: float = 0.14
## Where the afterglow lies (polished gold glints toward it).
@export var afterglow_direction: Vector3 = Vector3(0.3, 0.12, -0.95)
## The floodlights on the entablature washing the floors above it (and fading up over flood_reach),
## the street's lamplight on the band (at its foot and at its top), and the dusk's cool tint high up.
@export var flood_color: Color = Color(1.0, 0.86, 0.66)
@export_range(0.0, 1.5, 0.05) var flood_strength: float = 0.35
@export_range(2.0, 60.0, 0.5, "suffix:m") var flood_reach: float = 14.0
@export_range(0.2, 1.2, 0.01) var street_light_low: float = 0.56
@export_range(0.2, 1.2, 0.01) var street_light_high: float = 0.68
@export var dusk_tint: Color = Color(0.86, 0.9, 1.04)
## The same light on everything else lit (the walkways and kerbs low down, the ledges, statues and
## bridges in the floodlights): kit_golden's golden_light().
@export_range(0.2, 1.5, 0.01) var walkway_light: float = 0.9
@export_range(0.2, 1.5, 0.01) var ledge_light: float = 0.95

@export_group("Gold and red")
## The zone's gold: reflective metal, lit and never glowing (GDD §5, §11). The cult's emblem uses
## CultEmblem.GOLD_COLOR, the same gold (tests/suites/test_golden_skin.gd keeps them one).
@export var gold_color: Color = Color(0.78, 0.66, 0.42)
## Polished gold's brightest highlights: a pale champagne, never a yellow.
@export var gold_shine_color: Color = Color(0.97, 0.93, 0.83)
## The deep crimson of banners and lacquer: unlit (red glows only as enemy fire and weak points).
@export var red_color: Color = Color(0.44, 0.1, 0.12)
## White and cream stone and cladding: white, cream, ivory, champagne, a pale warm grey.
@export var stone_colors: PackedColorArray = PackedColorArray([
	Color(0.87, 0.86, 0.82), Color(0.86, 0.8, 0.68), Color(0.9, 0.86, 0.76), Color(0.82, 0.76, 0.66),
	Color(0.8, 0.79, 0.76)])
## The veins in the marble.
@export var vein_color: Color = Color(0.6, 0.55, 0.48)

@export_group("Walkways")
## DESIGN-TBD (docs/questions/d6a.md): the GDD's golden walkways over water (proposed, owner agreed).
## The deck's burnished gold, a deep gold well below the cream of the Golden Zone's cyborgs in value
## and saturation, so they stand out on it at gameplay distance (task P3's concern), and far brighter
## than the canal in the gaps.
@export var walkway_color: Color = Color(0.58, 0.47, 0.25)
## The dark joint between neighbouring walkways, so each lane reads as its own walkway.
@export var joint_color: Color = Color(0.1, 0.085, 0.07)
## The deck's plates: their seams streaming past are the still floor's own motion cue.
@export_range(0.6, 8.0, 0.1, "suffix:m") var plate_length: float = 3.6
## How polished the deck is (golden_metal()'s polish). A satin burnish: more polish makes the deck
## ahead reflect the afterglow and pale toward champagne, just where the cream cyborgs stand. The
## rails and the medallions' rings stay polished.
@export_range(0.0, 1.0, 0.01) var walkway_polish: float = 0.3
## The marble kerb between the outer lanes and the building faces.
@export var kerb_color: Color = Color(0.84, 0.8, 0.72)
## How far below the walkways the canal lies (deeper than the fall that ends a run, so a fall never
## visibly lands).
@export_range(4.5, 15.0, 0.1, "suffix:m") var canal_depth: float = 5.5
## The canal: dark water, never lighter than a gap's inside may be.
@export var canal_color: Color = Color(0.035, 0.055, 0.07)
## How fast the canal flows toward the player (a motion cue in the gaps).
@export_range(0.0, 6.0, 0.1, "suffix:m/s") var canal_flow: float = 1.4
## Everything under the walkways (their sides and piers, the building faces down to the water), seen
## only through gaps: deep shade that only darkens with depth, so a gap reads as a hole at a glance.
## Kept far darker than any walkway material (tests/suites/test_golden_skin.gd).
@export var gap_inside_color: Color = Color(0.075, 0.068, 0.06)
## Gap edges: the orange edge language of every zone. Redder than it looks: the glow and the
## tonemapper lift the green, and it must stay orange, not sign yellow.
@export var gap_edge_color: Color = Color(1.0, 0.25, 0.04)
## The cult's medallions inlaid in the walkways (GDD §5: its emblem shown openly): one slot per lane
## in every chunk (GoldenWalkways.MEDALLION_SLOT), medallion_share of them used where the walkway runs
## on unbroken. DESIGN-TBD (docs/questions/d6a.md): how often.
@export_range(0.0, 1.0, 0.01) var medallion_share: float = 0.15

@export_group("Motion")
## DESIGN-TBD (docs/questions/d6a.md): the walkways' motion cues (the owner's review: every still
## floor gets dust, scraps and speed streaks; over water, the equivalent): per 40 m of track, mist
## drifting up off the canal, flakes of gold leaf and speed streaks drifting toward the player
## (a = opacity).
@export_range(0, 200, 1) var mist_count: int = 55
@export_range(0, 60, 1) var leaf_count: int = 10
@export_range(0, 60, 1) var streak_count: int = 12
@export var mist_color: Color = Color(0.92, 0.94, 0.95, 0.3)
@export var leaf_color: Color = Color(0.82, 0.68, 0.4, 0.85)
@export var streak_color: Color = Color(0.97, 0.95, 0.9, 0.24)
@export_range(0.0, 30.0, 0.5, "suffix:m/s") var mist_speed: float = 4.5
@export_range(0.0, 80.0, 0.5, "suffix:m/s") var streak_speed: float = 24.0

@export_group("Buildings")
## Buildings are 1–3 lots long; a lot is this long.
@export_range(6.0, 40.0, 1.0, "suffix:m") var lot_length: float = 15.0
## Palaces (a statue ledge over the band, balconies, a balustraded roof), galleries (a glazed vault,
## the feed in gilded frames) and towers (mirror glass, setbacks, crowns, banners, hung screens).
@export_range(0.0, 1.0, 0.01) var palace_share: float = 0.45
@export_range(0.0, 1.0, 0.01) var gallery_share: float = 0.2
@export_range(10.0, 60.0, 1.0, "suffix:m") var palace_min_height: float = 17.0
@export_range(10.0, 80.0, 1.0, "suffix:m") var palace_max_height: float = 26.0
@export_range(20.0, 160.0, 1.0, "suffix:m") var tower_min_height: float = 34.0
@export_range(20.0, 200.0, 1.0, "suffix:m") var tower_max_height: float = 72.0
## The calm band: flush, solid-looking stone from the walkway up to band_top (the wall-run band and a
## margin), the entablature over it up to frieze_top, where the statues' ledge is.
@export_range(0.3, 1.5, 0.05, "suffix:m") var plinth_top: float = 0.9
@export_range(6.0, 9.0, 0.1, "suffix:m") var band_top: float = 7.0
@export_range(7.0, 11.0, 0.1, "suffix:m") var frieze_top: float = 8.6
## Decorative things (banners, frames, screens, reliefs on the walls) never sit lower than this.
@export_range(6.0, 16.0, 0.25, "suffix:m") var decor_min_height: float = 8.0
@export var granite_color: Color = Color(0.66, 0.62, 0.6)
@export var glass_color: Color = Color(0.1, 0.11, 0.13)
## Gold-mirrored and champagne mirror glass.
@export var mirror_color: Color = Color(0.64, 0.57, 0.46)
## Lamplight in the windows: warm white, below the glow threshold.
@export var window_warm_color: Color = Color(1.0, 0.9, 0.74)
@export_range(0.0, 3.0, 0.05) var window_glow: float = 0.8
## Share of a building's windows that are lit (each building picks within this range).
@export_range(0.0, 1.0, 0.01) var lit_min: float = 0.15
@export_range(0.0, 1.0, 0.01) var lit_max: float = 0.4
## The wall-run height marks (GDD §3: how high a wall run is): gold inlay lines, unlit, a deep gold
## that reads on the cream stone.
@export var wall_height_marks: PackedFloat32Array = PackedFloat32Array([2.0, 4.0])
@export var wall_mark_color: Color = Color(0.5, 0.4, 0.24)
## The warm-white lamps under balconies and along the bridges' seams.
@export var lamp_color: Color = Color(1.0, 0.92, 0.78)

@export_group("Statues")
## Decorative statues holding halberds are mounted at the bottom of the walls (GDD §9.11). This is
## deliberately separate from the live Sentinel's wall-run-height sill: the skin only builds a mesh,
## with no hitbox or enemy node. DESIGN-TBD (docs/questions/d6a.md): the exact base trim.
## Includes the small floor-safe trim under the visual recess; the model's pedestal begins at this
## height and the recess sill bottoms at the floor.
@export_range(0.0, 2.0, 0.01, "suffix:m") var statue_base_height: float = 0.10
## Extra safety inset behind the wall face, added to the pose-projected outward reach for the
## facade's three-quarter turn and the Palace's outward-facing pose. This keeps the actual halberd
## and arm envelope behind the wall without burying the whole model in an oversized radial recess.
@export_range(0.0, 1.5, 0.05, "suffix:m") var statue_base_inset: float = 0.10
## Kept as the old high-ledge tuning value for compatibility with existing reviews and data. It no
## longer controls decorative placement; use statue_base_height for the wall-base mount.
@export_range(7.0, 16.0, 0.1, "suffix:m") var statue_min_height: float = 8.8
## Metres between the wall-base statues, and the share of their places filled.
@export_range(3.0, 20.0, 0.5, "suffix:m") var statue_spacing: float = 5.2
@export_range(0.0, 1.0, 0.01) var statue_share: float = 0.9

@export_group("Cult emblem")
## DESIGN-TBD (docs/questions/d6a.md): how openly and where (GDD §5: shown openly only here). Red
## banners with the emblem hung out from the towers facing the approach, and reliefs on the faces of
## the towers' setbacks that face it (the share of towers carrying each).
@export_range(0.0, 1.0, 0.01) var banner_share: float = 0.6
@export_range(1.0, 5.0, 0.1, "suffix:m") var banner_width: float = 3.0
@export_range(3.0, 14.0, 0.1, "suffix:m") var banner_length: float = 6.5
@export_range(0.0, 1.0, 0.01) var relief_share: float = 0.7
## The emblem's size on banners (reliefs on towers are 1.3 times as big, on sky bridges 1.2 times; the
## bridges' crests and the medallions fit their own shapes). Large, so it still reads from afar: the
## kit fades a mark out when it is under about 24 pixels on screen (kit_solid's cult_mark()).
@export_range(0.8, 6.0, 0.1, "suffix:m") var emblem_size: float = 2.4

@export_group("Cult feed")
## DESIGN-TBD (docs/questions/d6a.md): where the cult's feed (CultFeed, GDD §5 "Cyborg Viewing
## Devices") plays here: in gilded frames on the palaces and galleries, above the band and angled to
## the approaching runner (feed_share of them), and on big screens hung out over the street from some
## towers, facing the traffic (feed_hung_share: a boss arena can set it to 0 to clear the airspace).
@export_range(0.0, 1.0, 0.01) var feed_share: float = 0.3
@export_range(0.0, 1.0, 0.01) var feed_hung_share: float = 0.35
@export_range(0.0, 1.0, 0.05) var feed_frame_brightness: float = 0.8
@export_range(0.0, 1.0, 0.05) var feed_hung_brightness: float = 0.9
## The hung screens (16:9): the widest, the share of the street's half width they may reach over (on a
## narrower street they are narrower), and the lowest their bottom edge goes (far above the wall-run
## band and the ceilings; never below GoldenFacades.OVER_STREET).
@export_range(2.0, 12.0, 0.1, "suffix:m") var feed_hung_width: float = 4.6
@export_range(0.2, 1.0, 0.01) var feed_hung_reach: float = 0.7
@export_range(12.5, 40.0, 0.5, "suffix:m") var feed_hung_bottom: float = 13.0

@export_group("Overhead")
## Sky bridges slung between the towers high over the street (the future in its dominant shapes),
## one slot every sky_bridge_spacing metres, sky_bridge_share of them built where both sides are tall
## enough; their faces carry the emblem toward the approach.
@export_range(30.0, 400.0, 1.0, "suffix:m") var sky_bridge_spacing: float = 110.0
@export_range(0.0, 1.0, 0.01) var sky_bridge_share: float = 0.7
@export_range(14.0, 60.0, 0.5, "suffix:m") var sky_bridge_height: float = 24.0

@export_group("Ceilings")
## DESIGN-TBD (docs/questions/d6a.md): GDD §5 names golden bridges, golden archways and other
## decadent structures; the mix is a proposal. Relative weights (bridges and archways need a ceiling
## across every lane; narrower ones become suspended galleries or yachts).
@export_range(0.0, 10.0, 0.1) var bridge_weight: float = 4.0
@export_range(0.0, 10.0, 0.1) var archway_weight: float = 3.0
@export_range(0.0, 10.0, 0.1) var yacht_weight: float = 2.0
## Share of bridges with water falling off their faces into a gilded trough (GDD §5: sparse, scenery
## only, kept above the ceiling so it never hides what's on the floor or walls).
@export_range(0.0, 1.0, 0.01) var water_share: float = 0.5
@export var water_color: Color = Color(0.74, 0.8, 0.84)
## The gold of the coffers and the cream of their ribs.
@export var coffer_color: Color = Color(0.7, 0.58, 0.36)
@export var rib_color: Color = Color(0.84, 0.8, 0.72)
@export var ceiling_lamp_color: Color = Color(1.0, 0.92, 0.78)
@export var yacht_hull_color: Color = Color(0.88, 0.86, 0.8)
## The yachts' engines: a pale blue-white, far from the pads' cyan.
@export var engine_color: Color = Color(0.62, 0.72, 1.0)

@export_group("Hazards")
## Pink crackle always means electric fence (GDD §5).
@export var fence_color: Color = Color(1.0, 0.18, 0.62)
## Signs: the yellow/black hazard frame around a boutique's board.
@export var sign_frame_color: Color = Color(1.0, 0.8, 0.15)
## The boards: cream, midnight blue, black lacquer, ivory, with gold lettering. They glow a little
## inside the hazard frame, so they keep clear of the other hazard hues (no crimson here).
@export var sign_content_colors: PackedColorArray = PackedColorArray([
	Color(0.86, 0.82, 0.72), Color(0.14, 0.17, 0.28), Color(0.1, 0.09, 0.1), Color(0.9, 0.87, 0.8)])

@export_group("Pads, ramps, finish")
@export var pad_color: Color = Color(0.1, 1.0, 0.95)
## Height of the anti-grav pad's light column.
@export_range(1.0, 10.0, 0.1, "suffix:m") var pad_beam_height: float = 5.8
@export var ramp_color: Color = Color(0.3, 1.0, 0.35)
## Speed pads share the ramps' green "safe boost" family (MeshKit.speed_strip; FB 49).
@export var speed_pad_color: Color = Color(0.45, 1.0, 0.55)
@export var finish_color: Color = Color(1.0, 1.0, 1.0)
## Dark graphite under pads, ramps and the finish gantry, so their glows read on the gold.
@export var trigger_metal_color: Color = Color(0.2, 0.19, 0.2)

const CULT_EMBLEM_CHOICE_PATH: String = "res://data/world/cult_emblem_choice.tres"
## The emblem is rasterised once at this size (with mipmaps) for every relief, banner and medallion.
const CULT_EMBLEM_PIXELS: int = 128

## Emblem textures by option, shared by every skin instance.
static var _emblem_textures: Dictionary = {}

## Built on first use and shared by every mesh (exports changed later don't reach them).
var _materials: Dictionary = {}
var _walkways: GoldenWalkways
var _facades: GoldenFacades
var _ceilings: GoldenCeilings
var _props: GoldenProps
var _doodads: GoldenDoodads
var _statues: GoldenStatue
var _decorative_inset: float = -1.0
var _decorative_projection: Vector2 = Vector2(-1.0, -1.0)
var _decorative_meshes: Dictionary = {}
## The latest wall face seen (wall_section runs before a chunk's ceilings): bridges and archways reach
## from wall to wall.
var _wall_x: float = 0.0
## The Gilded Sentinels' niches in the wall about to be built, by side (note_wall_enemies, task C4):
## Rect2 over (track distance, height).
var _niches: Dictionary = {}
## DESIGN-TBD (docs/questions/h1.md): the wall kept clear between a live Sentinel's niche and a decorative
## alcove beside it (crowds_niche()): the two gold frames (2 x 0.12 m) and a little more, so they never touch or
## overlap. No more than that: a live niche is not to stand apart from the decorative ones (USER_REQUESTS.md:
## the decorative statues are there so a live one can surprise the player).
const NICHE_CLEARANCE: float = 0.3


func _init() -> void:
	# The cyborgs wear the ceremonial enforcer (GDD §9.2, CyborgSuit.look_for); the other enemies treat
	# any variant but &"scavenger" like &"city", so their look is the clean one.
	enemy_variant = &"golden"


func make_environment() -> Environment:
	# The sky's colours as sRGB Vector3s (srgb()), so the sky looks the same on both renderers.
	var sky := {"zenith_color": srgb(sky_zenith_color), "horizon_color": srgb(sky_horizon_color),
		"haze_color": srgb(haze_color), "haze_strength": haze_strength, "haze_height": 0.12,
		"abyss_color": srgb(abyss_color), "skyline_color": srgb(skyline_color), "window_color": srgb(skyline_window_color),
		"moon_color": srgb(moon_color), "moon_direction": moon_direction, "moon_radius": moon_radius,
		"moon_clarity": moon_clarity, "star_amount": 0.15}
	return MeshKit.night_environment(sky, ambient_color, fog_color, fog_begin, fog_end, fog_max, 0.0,
		glow_intensity, glow_threshold)


func floor_segment(parent: Node3D, center: Vector3, size: Vector3, lane_x: float,
		edge_start: bool, edge_end: bool) -> void:
	var batch := MeshBatch.new()
	walkways().build(batch, center, size, lane_x, edge_start, edge_end)
	batch.commit(parent)


## A floor cut (task B4; GDD §9.9: the Buzz Overdrive appears in the Golden Zone too): the gold walkway
## cut open down the lane (GoldenWalkways.cut).
func floor_cut(parent: Node3D, cut: FloorCutSection) -> void:
	walkways().cut(parent, cut)


func wall_section(parent: Node3D, side: int, face_x: float, start: float, end: float) -> void:
	_wall_x = absf(face_x)
	var batch := MeshBatch.new()
	facades().build(batch, side, face_x, start, end)
	add_niches(batch, side, face_x)
	if side < 0:
		walkways().below(batch, absf(face_x), start, end)
		facades().overhead(batch, absf(face_x), start, end)
	batch.commit(parent)


## A wall gap (ZoneSkin.wall_gap), and with the left wall the walkways below (no sky bridge from a
## missing wall). The placement keeps gaps off a Gilded Sentinel's wall section, so no niche is here.
func wall_gap(parent: Node3D, side: int, face_x: float, start: float, end: float, gap: Vector2) -> void:
	_wall_x = absf(face_x)
	super(parent, side, face_x, start, end, gap)
	if side < 0:
		var batch := MeshBatch.new()
		walkways().below(batch, absf(face_x), start, end)
		batch.commit(parent)


## The wall enemies TrackBuilder is about to build on `side` (ZoneSkin.note_wall_enemies): each Gilded
## Sentinel's niche (GildedSentinel.niche_rect, task C4; GDD §9.11: a live one stands in a niche at
## wall-run height) is left out of the wall face here (niches(), open_rects()) and its recess appended
## (add_niches), so the statue stands back in the wall, clear of the wall-run path. Visual only.
func note_wall_enemies(side: int, _start: float, _end: float, enemies: Array[Dictionary]) -> void:
	var rects: Array[Rect2] = []
	for e: Dictionary in enemies:
		if String(e.get("type", "")) == "gilded_sentinel" and int(e.get("side", 0)) == side:
			rects.append(GildedSentinel.niche_rect(e))
	_niches[side] = rects


## The Gilded Sentinels' niches in the wall on `side` being built now (note_wall_enemies): Rect2 over
## (track distance, height).
func niches(side: int) -> Array[Rect2]:
	var out: Array[Rect2] = []
	out.assign(_niches.get(side, []))
	return out


## True if a decorative wall-base alcove `half_width` wide (the opening, not its frame) centred at track
## distance `at` on wall `side` would overlap or touch a live Sentinel's niche in the wall being built
## (niches(): the chunk's own, as TrackBuilder notes them): less than NICHE_CLEARANCE of wall between the two
## frames. The facades leave such an alcove out (its hole and its statue), so a live niche is never overlapped
## by a decorative one (task H1, GDD §9.11). A facade statue never straddles a chunk (GoldenFacades.
## _place_statues), so the alcove is in the one chunk that knows the niche, or in a chunk with no niche near it.
func crowds_niche(side: int, at: float, half_width: float) -> bool:
	for r: Rect2 in niches(side):
		if absf(at - r.get_center().x) < r.size.x * 0.5 + half_width + NICHE_CLEARANCE:
			return true
	return false


## Appends each niche's recess and frame (GoldenStatue.recess) for the wall on `side` at `face_x`.
func add_niches(batch: MeshBatch, side: int, face_x: float) -> void:
	var rects: Array[Rect2] = niches(side)
	if rects.is_empty():
		return
	var layer: MeshLayer = batch.layer(solid_material())
	var depth: float = GildedSentinel.niche_depth()
	var turn := Basis(Vector3.UP, -side * PI * 0.5)
	for r: Rect2 in rects:
		layer.append(statues().recess(r.size.x, r.size.y, depth),
			Transform3D(turn, Vector3(face_x, r.position.y, -(r.position.x + r.size.x * 0.5))))


## The pieces of the wall face [u0, u1] x [y0, y1] (track distance x height) left once `holes` (niches,
## Rect2 over the same axes, apart along the track) are taken out: whole strips between them, and the
## parts below and above each, in track order, as [u0, u1, y0, y1] (plain floats, so neighbouring pieces
## share their edges exactly). Without a hole there, the whole face.
static func open_rects(u0: float, u1: float, y0: float, y1: float, holes: Array[Rect2]) -> Array[PackedFloat64Array]:
	var out: Array[PackedFloat64Array] = []
	var cuts: Array[Rect2] = []
	for h: Rect2 in holes:
		if h.position.x < u1 and h.end.x > u0 and h.position.y < y1 and h.end.y > y0:
			cuts.append(h)
	cuts.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.x < b.position.x)
	var at: float = u0
	for h: Rect2 in cuts:
		var h0: float = maxf(h.position.x, u0)
		var h1: float = minf(h.end.x, u1)
		if h0 > at:
			out.append(PackedFloat64Array([at, h0, y0, y1]))
		var lo: float = maxf(h.position.y, y0)
		var hi: float = minf(h.end.y, y1)
		if lo > y0:
			out.append(PackedFloat64Array([h0, h1, y0, lo]))
		if hi < y1:
			out.append(PackedFloat64Array([h0, h1, hi, y1]))
		at = maxf(at, h1)
	if u1 > at:
		out.append(PackedFloat64Array([at, u1, y0, y1]))
	return out


func fence(hazard: Hazard, size: Vector3, ground_y: float, gapped: bool) -> void:
	props().fence(hazard, size, ground_y, gapped)


func wall_sign(hazard: Hazard, size: Vector3) -> void:
	props().wall_sign(hazard, size)


## A ceiling over its lanes, reaching to the wall faces where the section says they are
## (GoldenCeilings: only a ceiling across every lane becomes a bridge or an archway from wall to wall;
## over fewer lanes, a narrow ceiling (GDD §3), a bridge becomes a suspended gallery, and it builds
## narrower).
func ceiling_section(parent: Node3D, section: CeilingSection) -> void:
	ceilings().build(parent, section.center, section.size, section.lane_edges_x, section.wall_x)


## A ceiling given as its box alone (the wall faces from the chunk's walls).
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


## A dash wall's default look (ZoneSkin.dash_wall, task H7a) in the Golden Zone's own facades: white stone,
## gold trim (unlit), its glass and cracks a darker shade of the marble's veins. The Golden Palace's halls
## take it too. Task H7b builds the real face from the zone's facades.
func dash_wall_colors() -> PackedColorArray:
	return PackedColorArray([stone_colors[0], gold_color, glass_color, vein_color.darkened(0.45)])


## A gilded planter (small), a fountain (medium) or a robed statue on a plinth (large): GoldenDoodads.
## The statue is never the Gilded Sentinels' armoured guard (see GoldenDoodads' header).
func doodad(body: Node3D, size: Vector3, size_class: StringName, side: int, look_seed: int) -> void:
	doodads().build(body, size, size_class, side, look_seed)


# --- The statue kit (shared with the Gilded Sentinels, task C4) ------------------------------

## The zone's statue kit (GoldenStatue), drawn with this skin's materials: the decorative statues at
## the wall base come from it, and a live Gilded Sentinel builds its rig and niche with it.
func statues() -> GoldenStatue:
	if _statues == null:
		_statues = GoldenStatue.new(solid_material(), gold_color, stone_colors[0])
	return _statues


## The mesh-only decorative copy of a pose. Its gold is lifted slightly in albedo, not emissive, so
## a guard remains readable against the dark visual recess when the runner sees its side or back.
## The shared statue kit stays unchanged for live Gilded Sentinels.
func decorative_statue_mesh(pose: Dictionary) -> MeshLayer:
	var key: String = var_to_str(GoldenStatue.full_pose(pose))
	var found: MeshLayer = _decorative_meshes.get(key)
	if found != null:
		return found
	var source: MeshLayer = statues().mesh(pose)
	var out := MeshLayer.new()
	out.verts = source.verts.duplicate()
	out.uvs = source.uvs.duplicate()
	out.uv2s = source.uv2s.duplicate()
	out.colors = source.colors.duplicate()
	for i: int in out.colors.size():
		if roundi(out.uv2s[i].x) != MeshKit.PAT_GOLD:
			continue
		var c: Color = out.colors[i]
		out.colors[i] = Color(minf(c.r + 0.08, 1.0), minf(c.g + 0.08, 1.0), minf(c.b + 0.08, 1.0), c.a)
	_decorative_meshes[key] = out
	return out


## The decorative statues on the walls whose feet lie between two track distances, for reviews and
## tests: side, at, center (the statue's feet), facing, height, pose. The same ones wall_section()
## builds; every one is mounted at statue_base_height at the bottom of the wall.
func statue_spots(side: int, face_x: float, start: float, end: float) -> Array[Dictionary]:
	return facades().statue_spots(side, face_x, start, end)


## Shared floor-relative mount height for mesh-only decorative Sentinels. Both the outdoor facade and
## palace colonnade use this rather than the live enemy's niche sill, so moving scenery cannot move or
## resize the real Gilded Sentinel's hitboxes.
func decorative_statue_mount_y() -> float:
	return statue_base_height


## The actual projected horizontal envelope of every decorative pose. x is the largest reach toward
## the street (used for the mount inset); y is the largest reach toward the wall (used for the recess
## back). It covers both the Palace's direct outward turn and the facade's three-quarter approach turn.
func decorative_statue_projection() -> Vector2:
	if _decorative_projection.x >= 0.0:
		return _decorative_projection
	var outward: float = 0.0
	var wallward: float = 0.0
	var turn_sin: float = sin(GoldenFacades.STATUE_TURN)
	var turn_cos: float = cos(GoldenFacades.STATUE_TURN)
	for pose: StringName in GoldenStatue.DECORATIVE:
		for v: Vector3 in statues().mesh(GoldenStatue.pose_named(pose)).verts:
			# Palace statues face directly toward the street: local +Z is outward.
			outward = maxf(outward, v.z)
			wallward = maxf(wallward, -v.z)
			for side: int in [-1, 1]:
				# GoldenFacades turns local +Z toward (-side*cos(T), 0, sin(T)).
				var facade_outward: float = turn_cos * v.z - float(side) * turn_sin * v.x
				var facade_wallward: float = -facade_outward
				outward = maxf(outward, facade_outward)
				wallward = maxf(wallward, facade_wallward)
	_decorative_projection = Vector2(outward, wallward)
	return _decorative_projection


func decorative_statue_inset() -> float:
	if _decorative_inset >= 0.0:
		return _decorative_inset
	_decorative_inset = decorative_statue_projection().x + statue_base_inset
	return _decorative_inset


## The wallward extent of the actual projected poses, for the dark recess back and focused regressions.
func decorative_statue_wallward_extent() -> float:
	return decorative_statue_projection().y


## The visual recess leaves the actual wallward pose projection behind the mount before its dark back.
## This keeps the back from occluding a decorative model, while remaining mesh-only.
func decorative_statue_recess_depth() -> float:
	return decorative_statue_inset() + decorative_statue_wallward_extent() + 0.05


## The feet/origin of a base-mounted decorative statue. The side term is intentional: both walls use
## the same inward mount, regardless of lane count, while each skin keeps its own facing turn.
func decorative_statue_mount(side: int, face_x: float, at: float) -> Vector3:
	return Vector3(face_x + side * decorative_statue_inset(), decorative_statue_mount_y(), -at)


# --- The cult's feed and emblem ------------------------------------------------------------

## The shared feed material (CultFeed): the same broadcast as in every zone.
func feed_material() -> ShaderMaterial:
	return CultFeed.material()


## Whether the screen keyed by (a, b) plays the cult's feed (`share` of them).
func shows_feed(a: int, b: int, share: float) -> bool:
	return MeshKit.hash01(a, b, 131) < share


## The screens on the walls playing the feed whose middles lie between two track distances, for
## reviews and tests: side, at, kind (&"frame" gilded frames on the faces, &"hung" big screens hung
## out over the street), width, height, center (the screen's middle). The same ones wall_section()
## builds.
func feed_boards(side: int, face_x: float, start: float, end: float) -> Array[Dictionary]:
	return facades().feed_boards(side, face_x, start, end)


## The cult's emblems on the walls and overhead whose middles lie between two track distances, for
## reviews and tests: side, at, kind (&"banner", &"relief" on a tower's setback, &"sky_bridge"), size
## (the mark's square, metres), center. The same ones wall_section() builds. (The bridges' reliefs and
## the walkways' medallions belong to the ceilings and floor.)
func cult_emblems(side: int, face_x: float, start: float, end: float) -> Array[Dictionary]:
	return facades().emblems(side, face_x, start, end)


## The option the owner picked for the cult's emblem (data/world/cult_emblem_choice.tres; the
## choice's own default if the file is missing), never a hardcoded one.
static func cult_emblem_option() -> int:
	var choice := load(CULT_EMBLEM_CHOICE_PATH) as CultEmblemChoice
	if choice == null:
		push_error("GoldenSkin: no cult emblem choice at %s" % CULT_EMBLEM_CHOICE_PATH)
		choice = CultEmblemChoice.new()
	return choice.option


## The cult's emblem as the Golden Zone shows it (GDD §5): CultEmblem's drawing of the owner's choice
## in polished gold (CultEmblem.GOLD_COLOR) meeting at its small red centre stone
## (CultEmblem.GOLD_ACCENT_COLOR), over a transparent background of the same gold, with mipmaps (the
## kit shader picks the level itself and fades the mark out when it is small on screen).
static func cult_emblem_texture() -> ImageTexture:
	var option: int = cult_emblem_option()
	if not _emblem_textures.has(option):
		var img: Image = CultEmblem.build_image(option, CULT_EMBLEM_PIXELS, CultEmblem.GOLD_COLOR,
			CultEmblem.GOLD_ACCENT_COLOR, Color(CultEmblem.GOLD_COLOR, 0.0))
		img.generate_mipmaps()
		_emblem_textures[option] = ImageTexture.create_from_image(img)
	return _emblem_textures[option]


## A panel showing the emblem (MeshKit.PAT_EMBLEM) on a face: a rectangle from `origin` spanning u (to
## the viewer's right) and v (up), the mark `size` metres across centred on it, on `background`
## (cloth = 0, stone = 1) in `color`. The panel's own margin shows the background.
static func emblem_panel(layer: MeshLayer, origin: Vector3, u: Vector3, v: Vector3, size: float, color: Color,
		background: int) -> void:
	var half: float = maxf(size, 0.01) * 0.5
	var hu: float = u.length() * 0.5 / half
	var hv: float = v.length() * 0.5 / half
	layer.rect(origin, u, v, color, 0.0, MeshKit.PAT_EMBLEM, Vector2(-hu, -hv), Vector2(hu, hv), float(background))


# --- Shared materials (built once per skin, shared by every mesh) ------------------------

func solid_material() -> ShaderMaterial:
	if not _materials.has(&"solid"):
		var m: ShaderMaterial = MeshKit.solid(_solid_params())
		m.set_shader_parameter(&"cult_emblem", cult_emblem_texture())
		_materials[&"solid"] = m
	return _materials[&"solid"]


func glow_material() -> ShaderMaterial:
	if not _materials.has(&"glow"):
		_materials[&"glow"] = MeshKit.glow({"fade_begin": fog_begin, "fade_end": fog_end})
	return _materials[&"glow"]


## The building faces (golden_facade.gdshader).
func facade_material() -> ShaderMaterial:
	if not _materials.has(&"facade"):
		var marks: PackedFloat32Array = wall_height_marks
		_materials[&"facade"] = MeshKit.material("golden_facade.gdshader", {
			"glass_color": srgb(glass_color), "mirror_color": srgb(mirror_color), "gold_color": srgb(gold_color),
			"shine_color": srgb(gold_shine_color), "granite_color": srgb(granite_color),
			"window_warm": srgb(window_warm_color), "window_glow": window_glow, "drape_color": srgb(red_color),
			"sheen_color": srgb(sheen_color),
			"sheen_strength": sheen_strength, "flood_color": srgb(flood_color), "flood_strength": flood_strength,
			"flood_reach": flood_reach, "street_low": street_light_low, "street_high": street_light_high,
			"dusk_tint": srgb(dusk_tint), "plinth_top": plinth_top, "band_top": band_top, "frieze_top": frieze_top,
			"storey": GoldenFacades.STOREY, "mark_a": marks[0] if marks.size() > 0 else -10.0,
			"mark_b": marks[1] if marks.size() > 1 else -10.0, "mark_color": srgb(wall_mark_color),
			"canal_y": -canal_depth})
	return _materials[&"facade"]


## A colour for this skin's shader uniforms: its sRGB values as a Vector3. Godot converts a Color set
## on a colour uniform to linear on Forward+ (not on the Compatibility renderer), and the kit's shaders
## convert once more (to_linear); as a Vector3 it arrives as authored on both renderers, and is
## converted once, like a vertex colour, so the two renderers match.
static func srgb(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)


func drift_material() -> ShaderMaterial:
	if not _materials.has(&"drift"):
		_materials[&"drift"] = MeshKit.material("drift.gdshader", {
			"slice_length": TrackBuilder.CHUNK_LENGTH, "ash_speed": mist_speed, "streak_speed": streak_speed})
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


func _solid_params() -> Dictionary:
	var sun: Vector3 = afterglow_direction.normalized() if afterglow_direction.length() > 0.001 else Vector3.FORWARD
	return {"glow_scale": emissive_scale, "sheen_color": srgb(sheen_color), "sheen_strength": sheen_strength,
		"golden_shine": srgb(gold_shine_color), "golden_sun": sun, "golden_rail": srgb(gold_color),
		"golden_joint": srgb(joint_color), "golden_plate": plate_length, "golden_polish": walkway_polish,
		"golden_inlay": srgb(kerb_color), "golden_vein": srgb(vein_color), "golden_flow": canal_flow,
		"golden_trim": srgb(gold_color), "golden_rib": srgb(rib_color), "golden_light_street": walkway_light,
		"golden_light_flood": ledge_light}


func walkways() -> GoldenWalkways:
	if _walkways == null:
		_walkways = GoldenWalkways.new(self)
	return _walkways


func facades() -> GoldenFacades:
	if _facades == null:
		_facades = GoldenFacades.new(self)
	return _facades


func ceilings() -> GoldenCeilings:
	if _ceilings == null:
		_ceilings = GoldenCeilings.new(self)
	return _ceilings


func props() -> GoldenProps:
	if _props == null:
		_props = GoldenProps.new(self)
	return _props


func doodads() -> GoldenDoodads:
	if _doodads == null:
		_doodads = GoldenDoodads.new(self)
	return _doodads

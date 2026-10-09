class_name CorporateSkin
extends ZoneSkin
## Zone 4, Corporate (GDD §5, §11): a more oppressive Blade Runner, close to the Neon City but plainly
## corporate, where corporations and the military are one. Steel and gunmetal grey, military olive,
## cold and sterile white light, and one harsh brand colour (brand_color) on generic, soulless
## corporate art: the brand's mark (kit_logo.gdshaderinc, corp_logo()) on screens, banners, liveries,
## the ships of its army and even Gangland's crates.
## Floor segments are the roofs of maglev trains running in formation through a dark guideway trench
## (CorporateTrains; floor_style PLAZA paves them as an elevated plaza instead, CorporatePlaza); gaps
## are the spaces between the carriages, with the orange edge glow right on the collision edge and
## nothing lit below. Walls are corporate towers (CorporateTowers): glass curtain walls and fins over a
## calm, flush band of sterile cladding, or the military's blast walls around a compound, with
## floodlights, corner light strips, brand signs, banners and screens only above the wall-run band.
## Signs are corporate screens in the yellow/black hazard frame, electric fences the same pink field
## between security pylons, and ceilings the undersides of glass skyways, of towers bridging the
## street and of viaducts, and now and then a military gunship (CorporateCeilings), each built from
## the lanes it covers.
## The military presence (GDD §5, the owner's review): olive freight cars among the trains, blast
## walls, watchtowers and supply stacks around compounds, gunships hovering over the street and flying
## low as ceilings, all wearing the corporation's mark.
## The cult (GDD §5): its feed (CultFeed) plays on some corporate screens and on big screens hung out
## over the street, and its emblem (the owner's pick) hides small in the corner of some ads and banners,
## never a centrepiece. Both stay far above the wall-run band.
## Colour rule (GDD §5, proposed): only hazards glow in hazard colours. The olive is lit, never glowing;
## decorative light keeps to cold white and the brand's blue; hazards stay the most saturated and
## brightest things on screen.
## Visuals only: TrackBuilder owns every collision shape and gameplay node, and all variety comes from
## hashing track positions (MeshKit.hash_i), so a chunk looks the same whenever it is built.

enum FloorStyle { MAGLEV, PLAZA }

@export_group("Environment")
## DESIGN-TBD: the GDD gives the zone's palette and mood, not its hour or weather. A heavy overcast
## night: a low smog deck lit a cold grey from below by the city, no moon, no stars.
@export var sky_zenith_color: Color = Color(0.05, 0.06, 0.08)
@export var sky_horizon_color: Color = Color(0.16, 0.18, 0.22)
## The smog lit by the towers' cold light, low over the horizon.
@export var haze_color: Color = Color(0.3, 0.34, 0.4)
@export_range(0.0, 2.0, 0.05) var haze_strength: float = 0.7
@export var abyss_color: Color = Color(0.012, 0.015, 0.02)
@export var skyline_color: Color = Color(0.05, 0.058, 0.075)
@export var skyline_window_color: Color = Color(0.72, 0.8, 0.9)
@export var ambient_color: Color = Color(0.5, 0.55, 0.64)
## Distant geometry fades into the smog between fog_begin and fog_end.
@export var fog_color: Color = Color(0.13, 0.15, 0.19)
@export_range(0.0, 150.0, 1.0, "suffix:m") var fog_begin: float = 18.0
@export_range(50.0, 400.0, 5.0, "suffix:m") var fog_end: float = 190.0
@export_range(0.0, 1.0, 0.01) var fog_max: float = 1.0
@export_range(0.0, 2.0, 0.05) var glow_intensity: float = 0.8
@export_range(0.5, 4.0, 0.05) var glow_threshold: float = 1.1
## Brightness of emissive kit parts (vertex glow 1.0 = this many times the albedo).
@export_range(1.0, 20.0, 0.5) var emissive_scale: float = 4.0
## Cold sky light caught at grazing angles by roofs, glass and hulls.
@export var sheen_color: Color = Color(0.3, 0.34, 0.42)
@export_range(0.0, 1.0, 0.01) var sheen_strength: float = 0.2

@export_group("Brand")
## DESIGN-TBD (GDD §5 leaves the brand colour to the art agent; for the owner's review): an electric
## ultramarine. The colour rule leaves only blue to violet free for glowing decoration, and the UI owns
## azure and violet (its accents at about 209° and 252°), so the brand takes the middle (about 231°,
## over 20° from each), fully saturated where they are soft and light: the harsh, generic corporate
## blue of a screen's glare. Blue is also the dimmest hue, so the brand never outshines a hazard.
@export var brand_color: Color = Color(0.14, 0.27, 1.0)
## The brand's paint on banners, flags and plaques: lit, never glowing.
@export var brand_paint_color: Color = Color(0.11, 0.18, 0.46)
## The brand's livery on the trains' roofs (the painted mark, the pinstripes): lighter than the cloth,
## so nothing painted on a roof is ever as dark as a gap's inside.
@export var livery_color: Color = Color(0.26, 0.36, 0.62)
## How brightly the brand's signs glow.
@export_range(0.0, 1.5, 0.05) var brand_glow: float = 0.6
## Pale paint for markings and stencils, and the cold white of lettering on screens.
@export var marking_color: Color = Color(0.78, 0.8, 0.82)
@export var screen_text_color: Color = Color(0.88, 0.92, 1.0)

@export_group("Floor")
## DESIGN-TBD (GDD §5: "roofs of maglev trains or plazas", proposed and agreed): MAGLEV for the zone
## (Corporate 1 is the Maglev Line); PLAZA paves the floor as an elevated plaza deck (for Corporate 2,
## Checkpoint Plaza: data/skins/corporate_plaza_skin.tres).
@export var floor_style: FloorStyle = FloorStyle.MAGLEV
## Carriages sit on a per-lane grid of this length, so they line up across chunk cuts.
@export_range(8.0, 40.0, 0.5, "suffix:m") var carriage_length: float = 22.0
## Space left on each side of a train inside its lane (parallel trains show a dark slit).
@export_range(0.02, 0.5, 0.01, "suffix:m") var train_inset: float = 0.14
## How far a carriage's body reaches below its roof (all of it in the trench's shade).
@export_range(1.0, 5.0, 0.1, "suffix:m") var train_depth: float = 3.2
## Corporate express roofs: light steel, sterile white-grey and gunmetal.
@export var roof_colors: PackedColorArray = PackedColorArray([
	Color(0.46, 0.48, 0.52), Color(0.53, 0.55, 0.58), Color(0.38, 0.4, 0.44)])
## Military freight car roofs: olive drab.
@export var military_roof_colors: PackedColorArray = PackedColorArray([
	Color(0.3, 0.31, 0.25), Color(0.27, 0.285, 0.23)])
## DESIGN-TBD: the share of carriages that are military freight (runs of cars share a kind), and of
## corporate cars with the brand's mark painted on the roof.
@export_range(0.0, 1.0, 0.01) var military_car_share: float = 0.15
@export_range(0.0, 1.0, 0.01) var roof_logo_share: float = 0.3
## The gangway bellows between two carriages: a grey band across the roof, never as dark as a gap.
@export var joint_color: Color = Color(0.27, 0.28, 0.3)
## The walkway along the building faces beside the outer lanes (and the plaza's paving colour).
@export var ledge_color: Color = Color(0.38, 0.4, 0.43)
## DESIGN-TBD (docs/questions/h3.md): everything below the running surface (the carriages' sides and
## ends, the plaza deck's edges, the guideways, the trench or the plaza's lower level), seen only through
## gaps and cuts: dim, and darkening with depth, but showing what is there (PAT_CORP_UNDER; task H3, GDD
## §9.9: "the trench under the maglev line"), so a gap reads as a hole at a glance and still shows the
## trench. These are the brightest each is drawn (the patterns only darken them): kept far darker than
## any roof (tests/suites/test_corporate_skin.gd). The faces, the guideways' steel and the trench's wet
## concrete (or the plaza's lower level).
@export var gap_inside_color: Color = Color(0.15, 0.16, 0.18)
@export var guideway_color: Color = Color(0.125, 0.135, 0.155)
@export var trench_color: Color = Color(0.105, 0.115, 0.13)
## The guideway beams' tops and the trench's floor, below the depth at which a fall ends the run, so
## a fall never visibly lands.
@export_range(4.5, 20.0, 0.1, "suffix:m") var guideway_depth: float = 5.6
@export_range(6.0, 60.0, 0.5, "suffix:m") var trench_depth: float = 18.0
## Gap edges: the orange edge language of every zone. Redder than it looks: the glow and the
## tonemapper lift the green, and it must stay orange, not sign yellow.
@export var gap_edge_color: Color = Color(1.0, 0.25, 0.04)
## The plaza's paving (PLAZA): polished slabs.
@export var paving_colors: PackedColorArray = PackedColorArray([
	Color(0.4, 0.41, 0.43), Color(0.34, 0.35, 0.37)])

@export_group("Motion")
## DESIGN-TBD: GDD §5 proposes motion effects for still floors (the owner's review: every zone with a
## still floor gets them). Per 40 m of track: fine grit and drizzle, a few scraps of paper and speed
## streaks drifting toward the player (a = opacity). The trains also show their carriage joints.
@export_range(0, 200, 1) var dust_count: int = 20
@export_range(0, 60, 1) var scrap_count: int = 3
@export_range(0, 60, 1) var streak_count: int = 16
@export var dust_color: Color = Color(0.72, 0.76, 0.82, 0.22)
@export var scrap_color: Color = Color(0.74, 0.76, 0.78, 0.55)
@export var streak_color: Color = Color(0.86, 0.9, 0.96, 0.2)
@export_range(0.0, 30.0, 0.5, "suffix:m/s") var dust_speed: float = 7.0
@export_range(0.0, 80.0, 0.5, "suffix:m/s") var streak_speed: float = 26.0

@export_group("Towers")
@export_range(20.0, 200.0, 1.0, "suffix:m") var building_min_height: float = 44.0
@export_range(30.0, 300.0, 1.0, "suffix:m") var building_max_height: float = 170.0
## Buildings are 1–3 lots long; a lot is this long.
@export_range(6.0, 40.0, 1.0, "suffix:m") var lot_length: float = 16.0
## Curtain walls' mullions and spandrels, and fins: steel and gunmetal.
@export var facade_colors: PackedColorArray = PackedColorArray([
	Color(0.3, 0.32, 0.35), Color(0.22, 0.235, 0.26), Color(0.38, 0.4, 0.43), Color(0.26, 0.27, 0.28)])
## The sterile cladding of the calm band: dark granite, gunmetal and graphite, between brushed steel
## pilasters (darker than the floor, so the running surface reads as the play space).
@export var podium_colors: PackedColorArray = PackedColorArray([
	Color(0.2, 0.21, 0.23), Color(0.15, 0.16, 0.18), Color(0.25, 0.26, 0.28), Color(0.18, 0.18, 0.19)])
@export var pilaster_color: Color = Color(0.34, 0.36, 0.39)
## The military's blast walls: two olives and a grey (lit, never glowing).
@export var blast_colors: PackedColorArray = PackedColorArray([
	Color(0.3, 0.31, 0.22), Color(0.35, 0.36, 0.3), Color(0.4, 0.41, 0.42)])
## The offices' light: cold white, even and sterile.
@export var window_color: Color = Color(0.78, 0.86, 0.98)
@export_range(0.2, 3.0, 0.05) var window_glow: float = 0.95
## DESIGN-TBD: the calm band. Nothing lights up, sticks out or glows on the walls below this height
## (the wall-run band tops out below 6 m), so a pink wall fence (task B5) never competes with a band
## of light, and decorative signs, screens and lights start at decor_min_height.
@export_range(6.0, 10.0, 0.1, "suffix:m") var band_top: float = 7.2
@export_range(7.0, 16.0, 0.25, "suffix:m") var decor_min_height: float = 8.0
## Cold floodlights along the top of the calm band, washing the faces above in sterile white light.
@export var flood_color: Color = Color(0.86, 0.92, 1.0)
@export_range(0.0, 2.0, 0.05) var flood_strength: float = 0.45
@export_range(4.0, 20.0, 0.5, "suffix:m") var flood_spacing: float = 8.0
## Light strips up the towers' corners: cold white, some in the brand's blue.
@export_range(0.0, 1.0, 0.01) var strip_share: float = 0.7
## Faint lines on the facades at these heights, to read how high a wall run is.
@export var wall_height_marks: PackedFloat32Array = PackedFloat32Array([2.0, 4.0])
@export var wall_mark_color: Color = Color(0.42, 0.45, 0.5)
## DESIGN-TBD (generic, soulless corporate art, GDD §5): the share of towers carrying the brand's big
## sign near the top, banners hanging down their faces, and surveillance cameras over the band.
@export_range(0.0, 1.0, 0.01) var sign_share: float = 0.45
@export_range(0.0, 1.0, 0.01) var banner_share: float = 0.4
@export_range(0.0, 1.0, 0.01) var camera_share: float = 0.5

@export_group("Military presence")
## DESIGN-TBD (the owner's review: military ships and props are part of the zone's look, heavier in
## Corporate 2): the share of lots that are military compounds (blast walls, a watchtower, supply
## stacks), of 300 m stretches with a gunship hovering high over the street, and of ceilings that
## are gunships flying low (Ceilings group).
@export_range(0.0, 1.0, 0.01) var compound_share: float = 0.18
@export_range(0.0, 1.0, 0.01) var hover_ship_share: float = 0.55
## The military's olive and gunmetal (hulls, crates, watchtowers).
@export var olive_color: Color = Color(0.29, 0.3, 0.21)
@export var gunmetal_color: Color = Color(0.19, 0.2, 0.23)
## Searchlights on watchtowers and gunships: steady cold white beams into the sky, never on the lanes
## (a light that locks onto the lanes is the Floating Head's warning, GDD §10).
@export var searchlight_color: Color = Color(0.82, 0.88, 1.0)

@export_group("Overhead")
## DESIGN-TBD: glass skybridges between the towers, high over the street (a megastructure's future),
## where both towers are tall enough: the share of 180 m stretches with one. A boss arena whose boss
## flies over the street sets it to 0 (with hover_ship_share and street_screen_share).
@export_range(0.0, 1.0, 0.01) var skybridge_share: float = 0.6
@export_range(15.0, 80.0, 0.5, "suffix:m") var skybridge_min_height: float = 24.0

@export_group("Hazards")
## Pink crackle always means electric fence (GDD §5).
@export var fence_color: Color = Color(1.0, 0.18, 0.62)
@export var pylon_color: Color = Color(0.36, 0.38, 0.41)
## Signs: the yellow/black hazard frame around a corporate screen.
@export var sign_frame_color: Color = Color(1.0, 0.8, 0.15)

@export_group("Ceilings")
## DESIGN-TBD (GDD §5: undersides of buildings, bridges and similar, and occasionally a military
## ship): relative weights of a glass skyway running along the street, a tower bridging the street
## (a ceiling across every lane only), a concrete viaduct, and a military gunship.
@export_range(0.0, 10.0, 0.1) var skyway_weight: float = 3.0
@export_range(0.0, 10.0, 0.1) var gate_weight: float = 2.5
@export_range(0.0, 10.0, 0.1) var viaduct_weight: float = 2.5
@export_range(0.0, 10.0, 0.1) var ship_weight: float = 1.0
@export var soffit_color: Color = Color(0.34, 0.36, 0.39)
@export var concrete_color: Color = Color(0.42, 0.42, 0.41)
## The flush lamps along the lane seams under every ceiling: cold white.
@export var ceiling_lamp_color: Color = Color(0.86, 0.92, 1.0)
@export var engine_color: Color = Color(0.55, 0.66, 1.0)

@export_group("Cult emblem")
## Never smaller than this: tiny, its three-fold silhouette could read like the radiation trefoil
## (the kit shader also fades it out before it spans fewer than about 24 pixels on screen).
@export_range(0.5, 3.0, 0.05, "suffix:m") var emblem_min_size: float = 0.9
## DESIGN-TBD (GDD §5 proposes it in logos and ads in every zone): the share of corporate screens and
## banners carrying it small in a corner, like a sponsor's mark.
@export_range(0.0, 1.0, 0.01) var emblem_share: float = 0.35
## Glow of its warm-white neon on screens (banners carry it in unlit bronze).
@export_range(0.0, 1.5, 0.05) var emblem_glow: float = 0.6

@export_group("Cult feed")
## DESIGN-TBD: how often the cult's feed (CultFeed, GDD §5 "Cyborg Viewing Devices") plays here,
## alongside the corporate ads: the share of the towers' big screens showing it instead of an ad.
@export_range(0.0, 1.0, 0.01) var feed_share: float = 0.35
## The share of flush towers hanging a big screen out over the street, facing the oncoming runner
## (the feed or an ad). A boss arena whose boss flies over the street sets it to 0.
@export_range(0.0, 1.0, 0.01) var street_screen_share: float = 0.35
## Brightness of the feed (0-1) on the towers' screens and on the screens over the street.
@export_range(0.0, 1.0, 0.05) var feed_board_brightness: float = 0.9
@export_range(0.0, 1.0, 0.05) var feed_screen_brightness: float = 0.85
## The screens over the street (16:9): the widest, the share of the street's half width they may reach
## over, and the lowest their bottom edge goes (far above the wall-run band and the ceilings).
@export_range(2.0, 12.0, 0.1, "suffix:m") var street_screen_width: float = 5.2
@export_range(0.2, 1.0, 0.01) var street_screen_reach: float = 0.7
@export_range(9.0, 40.0, 0.5, "suffix:m") var street_screen_bottom: float = 12.5

@export_group("Doodads")
## Generic corporate doodads (GDD §3, task G6: "security barriers, kiosks, planters and sculpture
## plinths in steel and the brand colour"): a planter's trimmed topiary, kept cold and desaturated,
## well apart from the ramps' and speed pads' hazard green.
@export var doodad_topiary_color: Color = Color(0.25, 0.3, 0.26)
## Whether a medium doodad is a security barrier or a kiosk: the share that are barriers.
@export_range(0.0, 1.0, 0.01) var doodad_barrier_share: float = 0.5
@export var doodad_kiosk_color: Color = Color(0.16, 0.17, 0.2)

@export_group("Pads, ramps, finish")
@export var pad_color: Color = Color(0.1, 1.0, 0.95)
## Height of the anti-grav pad's light column.
@export_range(1.0, 10.0, 0.1, "suffix:m") var pad_beam_height: float = 5.8
@export var ramp_color: Color = Color(0.3, 1.0, 0.35)
## Speed pads share the ramps' green "safe boost" family (MeshKit.speed_strip; FB 49).
@export var speed_pad_color: Color = Color(0.45, 1.0, 0.55)
@export var finish_color: Color = Color(1.0, 1.0, 1.0)
## Steel under pads, ramps and the finish gantry.
@export var metal_color: Color = Color(0.2, 0.21, 0.24)

## Built on first use and shared by every mesh (exports changed later don't reach them).
var _materials: Dictionary = {}
var _trains: CorporateTrains
var _plaza: CorporatePlaza
var _towers: CorporateTowers
var _ceilings: CorporateCeilings
var _props: CorporateProps
var _doodads: CorporateDoodads
var _dash_walls: CorporateDashWall
## The latest wall face seen (wall_section runs before a chunk's ceilings): a tower bridging the
## street reaches from wall to wall.
var _wall_x: float = 0.0
## A lane's width, from the floor pieces seen (they're built before the walls in every chunk), so the
## trench below can lay one guideway under every lane, and the width the roofs' shading was set for.
var _lane_width: float = 2.4
var _shaded_lane_width: float = 2.4


func _init() -> void:
	# GDD §9.2: the Corporate zone's cyborgs are the "Wide-Aspect VR" Runner (CyborgSuit's vr_runner
	# look); every other enemy reads it as the clean look (docs/ARCHITECTURE.md, Zone skins).
	enemy_variant = &"vr_runner"


func make_environment() -> Environment:
	var sky := {"zenith_color": sky_zenith_color, "horizon_color": sky_horizon_color, "haze_color": haze_color,
		"haze_strength": haze_strength, "haze_height": 0.12, "abyss_color": abyss_color, "skyline_color": skyline_color,
		"window_color": skyline_window_color, "moon_radius": 0.0, "star_amount": 0.0}
	return MeshKit.night_environment(sky, ambient_color, fog_color, fog_begin, fog_end, fog_max, 0.0,
		glow_intensity, glow_threshold)


func floor_segment(parent: Node3D, center: Vector3, size: Vector3, lane_x: float,
		edge_start: bool, edge_end: bool) -> void:
	# The collision box spans the lane (outer lanes reach the wall).
	_lane_width = 2.0 * minf(center.x + size.x * 0.5 - lane_x, lane_x - (center.x - size.x * 0.5))
	if absf(_lane_width - _shaded_lane_width) > 0.001:
		# The lane width is tunable live (F6): the roofs' livery is laid out in metres across the roof.
		_shaded_lane_width = _lane_width
		solid_material().set_shader_parameter(&"corp_roof_half_width", trains().roof_half_width(_lane_width))
	var batch := MeshBatch.new()
	if floor_style == FloorStyle.PLAZA:
		plaza().build(batch, center, size, lane_x, edge_start, edge_end)
	else:
		trains().build(batch, center, size, lane_x, edge_start, edge_end)
	batch.commit(parent)


## A floor cut (task B4; GDD §9.9: the Buzz Overdrive first appears in Corporate 1): on the trains, the
## lane's carriage roof sliced open (CorporateTrains.cut), on the plaza the deck (CorporatePlaza.cut).
func floor_cut(parent: Node3D, cut: FloorCutSection) -> void:
	if floor_style == FloorStyle.PLAZA:
		plaza().cut(parent, cut)
	else:
		trains().cut(parent, cut)


func wall_section(parent: Node3D, side: int, face_x: float, start: float, end: float) -> void:
	_wall_x = absf(face_x)
	var batch := MeshBatch.new()
	towers().build(batch, side, face_x, start, end)
	if side < 0:
		if floor_style == FloorStyle.PLAZA:
			plaza().below(batch, absf(face_x), start, end)
		else:
			trains().below(batch, absf(face_x), _lane_width, start, end)
		towers().overhead(batch, absf(face_x), start, end)
	batch.commit(parent)


## A wall gap (ZoneSkin.wall_gap), and with the left wall the floor below (no skybridge from a missing
## wall).
func wall_gap(parent: Node3D, side: int, face_x: float, start: float, end: float, gap: Vector2) -> void:
	_wall_x = absf(face_x)
	super(parent, side, face_x, start, end, gap)
	if side < 0:
		var batch := MeshBatch.new()
		if floor_style == FloorStyle.PLAZA:
			plaza().below(batch, absf(face_x), start, end)
		else:
			trains().below(batch, absf(face_x), _lane_width, start, end)
		batch.commit(parent)


func fence(hazard: Hazard, size: Vector3, ground_y: float, gapped: bool) -> void:
	props().fence(hazard, size, ground_y, gapped)


func wall_sign(hazard: Hazard, size: Vector3) -> void:
	props().wall_sign(hazard, size)


## A ceiling over its lanes, reaching to the wall faces where the section says they are
## (CorporateCeilings: only a ceiling across every lane becomes a tower bridging the street; over
## fewer lanes, a narrow ceiling (GDD §3), it builds narrower).
func ceiling_section(parent: Node3D, section: CeilingSection) -> void:
	ceilings().build(parent, section.center, section.size, section.lane_edges_x, section.wall_x)


## A ceiling given as its box alone (the wall faces from the chunk's walls).
func hull(parent: Node3D, center: Vector3, size: Vector3, lane_edges_x: Array[float]) -> void:
	ceilings().build(parent, center, size, lane_edges_x, _wall_x if _wall_x > 0.0 else size.x * 0.5 + 0.3)


func pad(trigger: Area3D, size: Vector3) -> void:
	MeshBatch.add_instance(trigger, MeshKit.lift_pad(size, pad_color, metal_color, pad_beam_height, solid_material(),
		glow_material()))


func ramp(trigger: Area3D, size: Vector3, side: int) -> void:
	MeshBatch.add_instance(trigger, MeshKit.kicker_ramp(size, side, ramp_color, metal_color, solid_material(),
		glow_material()))


func speed_pad(trigger: Area3D, size: Vector3) -> void:
	MeshBatch.add_instance(trigger, MeshKit.speed_strip(size, speed_pad_color, metal_color, solid_material(),
		glow_material()))


func finish_line(parent: Node3D, width: float, distance: float) -> void:
	var batch := MeshBatch.new()
	MeshKit.finish_gate(batch, solid_material(), glow_material(), width, distance, finish_color, metal_color)
	batch.commit(parent)


## A dash wall (task H7b): the end of a tower standing across the street, built from the towers' own kit
## (CorporateDashWall): cladding, steel, curtain glass or the military's blast walls and armour.
func dash_wall(body: Node3D, size: Vector3, look_seed: int) -> void:
	DashWallKit.dress(body, dash_walls().mesh_for(size, look_seed))


## The surfaces a dash wall draws with: the towers' facade shader and the solid kit.
func dash_wall_materials() -> Array[Material]:
	return [solid_material(), facade_material()]


## The default dash wall look's colours (ZoneSkin.dash_wall, task H7a) in the towers' own calm band (CorporateTowers): the
## sterile cladding between brushed steel pilasters, dark glass. Kept as the palette the debris falls back on.
func dash_wall_colors() -> PackedColorArray:
	return PackedColorArray([podium_colors[2 % podium_colors.size()], pilaster_color, Color(0.08, 0.1, 0.13),
		Color(0.035, 0.04, 0.05)])


## A planter (small), a security barrier or a glass kiosk (medium) or a sculpture plinth (large): CorporateDoodads.
func doodad(body: Node3D, size: Vector3, size_class: StringName, side: int, look_seed: int) -> void:
	doodads().build(body, size, size_class, side, look_seed)


# --- The cult's feed and emblem ------------------------------------------------------------

## The shared feed material (CultFeed): the same broadcast as in every zone.
func feed_material() -> ShaderMaterial:
	return CultFeed.material()


## Whether the screen keyed by (a, b) plays the cult's feed instead of an ad (`share` of them).
func shows_feed(a: int, b: int, share: float) -> bool:
	return MeshKit.hash01(a, b, 131) < share


## Whether the ad or banner keyed by (a, b) carries the cult's emblem (emblem_share of them).
func carries_emblem(a: int, b: int) -> bool:
	return MeshKit.hash01(a, b, 97) < emblem_share


## The screens on the walls playing the feed whose middles lie between two track distances, for
## reviews and tests: side, at, kind (&"roof_board" on a low building's roof, &"street_screen" hung out
## over the street), width, height, center (the screen's middle, on its face). The same ones
## wall_section() builds.
func feed_boards(side: int, face_x: float, start: float, end: float) -> Array[Dictionary]:
	return towers().feed_boards(side, face_x, start, end)


## The cult's emblems on the walls whose middles lie between two track distances, for reviews and
## tests: side, at, kind (&"screen" on a street screen's ad, &"roof_board" or &"banner"), size (the
## mark, metres), center. The same ones wall_section() builds.
func cult_emblems(side: int, face_x: float, start: float, end: float) -> Array[Dictionary]:
	return towers().emblems(side, face_x, start, end)


## The warm white the emblem glows in on the corporate screens: the chosen option's own neon.
func emblem_color() -> Color:
	return CultEmblem.default_scheme(CultFeed.emblem_option())["neon"]


## The emblem's unlit colour (on banners and plaques): the chosen option's own metal.
func emblem_metal_color() -> Color:
	return CultEmblem.default_scheme(CultFeed.emblem_option())["metal"]


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


## The building faces (corp_facade.gdshader).
func facade_material() -> ShaderMaterial:
	if not _materials.has(&"facade"):
		_materials[&"facade"] = MeshKit.material("corp_facade.gdshader", {
			"window_cold": window_color, "window_glow": window_glow, "sheen_color": sheen_color,
			"sheen_strength": sheen_strength * 1.5, "storey_base": band_top, "calm_top": band_top,
			"blast_a": blast_colors[0], "blast_b": blast_colors[1 % blast_colors.size()],
			"blast_c": blast_colors[2 % blast_colors.size()], "stencil_color": marking_color,
			"flood_color": flood_color, "flood_strength": flood_strength, "flood_height": band_top + 0.3,
			"flood_spacing": flood_spacing, "pilaster_color": pilaster_color})
	return _materials[&"facade"]


func drift_material() -> ShaderMaterial:
	if not _materials.has(&"drift"):
		_materials[&"drift"] = MeshKit.material("drift.gdshader", {
			"slice_length": TrackBuilder.CHUNK_LENGTH, "ash_speed": dust_speed, "streak_speed": streak_speed})
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
	return {"glow_scale": emissive_scale, "sheen_color": sheen_color, "sheen_strength": sheen_strength,
		"corp_brand": livery_color, "corp_brand_glow": brand_color, "corp_marking": marking_color,
		"corp_text": screen_text_color, "corp_roof_half_width": trains().roof_half_width(_shaded_lane_width)}


func trains() -> CorporateTrains:
	if _trains == null:
		_trains = CorporateTrains.new(self)
	return _trains


func plaza() -> CorporatePlaza:
	if _plaza == null:
		_plaza = CorporatePlaza.new(self)
	return _plaza


func dash_walls() -> CorporateDashWall:
	if _dash_walls == null:
		_dash_walls = CorporateDashWall.new(self)
	return _dash_walls


func towers() -> CorporateTowers:
	if _towers == null:
		_towers = CorporateTowers.new(self)
	return _towers


func ceilings() -> CorporateCeilings:
	if _ceilings == null:
		_ceilings = CorporateCeilings.new(self)
	return _ceilings


func props() -> CorporateProps:
	if _props == null:
		_props = CorporateProps.new(self)
	return _props


func doodads() -> CorporateDoodads:
	if _doodads == null:
		_doodads = CorporateDoodads.new(self)
	return _doodads

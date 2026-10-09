class_name CasinoSkin
extends MarketplaceSkin
## Zone 4, the Casino (GDD §5, owner, October 8, 2026; task K1; the owner's reference image
## docs/art/reference/casino_zone.webp): a long covered casino street at night, gaudy, warm and a
## little seedy, under a vaulted roof of glass and iron. Walls of dark riveted iron and aged brass with
## thick brass pipes along them, stacked balconies, air-conditioning units, ivy in planters, lit
## marquees and casino signs, and low on the wall a row of lit lounge windows where the Marketplace
## citizens play (task D3). The floor is the street's dark wet paving with brass inlaid in it; its gaps
## are open service trenches, dark and deep. Ceilings are pieces of the covered street at the usual
## height: iron footbridges between the balconies, pipe-bundle gantries and sign gantries. The glass
## vault stays high overhead as background and is never a ceiling the player can use. Visuals only.
##
## It changes only the scenery: the owner asked for new walls, floor, ceilings and background and no
## new characters, so it reuses the Marketplace's skin as its base (`enemy_variant` &"casino": the
## Casino Mob Enforcer and the Marketplace's enemies, as they are) and with it the Marketplace's
## citizens, its plants and casino-machine doodads, its fences' and signs' shapes, the cult's feed and
## emblem. What the Marketplace draws with its stalls, shopfronts and ceilings, this draws itself: the
## export groups the Marketplace's own builders read (stalls, stucco, the ship kinds) stay unused here,
## and the ones the shared pieces read (the shop windows, the neon, the signs, the doodads) are given
## the Casino's palette in _init().
## Colour rule (GDD §5): the reference glows pink, cyan, green and orange, which are the hazards'
## colours here; they never glow near the track. Lit signs and bulbs are warm white, violet or blue,
## brass is lit metal (never neon), and the hazards stay the brightest, most saturated things on screen.
## Phones: the glass vault is opaque and faked (no transparency), nothing here is a real-time light,
## and every part is drawn with the one solid material and the one glow material in a chunk's batches.
## DESIGN-TBD (docs/questions/k1.md): the floor and gap look (1), the glow palette (2), the signs' names (3:
## lit signs carry a mark and glyphs, never words), pedestrians far down the street (4: there are none; the
## Marketplace's citizens play in the shop windows only), how busy the street is (5), the glass roof (6), the
## doodads (7: the Marketplace's, in the Casino's palette) and The House's plainer arena (8).

@export_group("Street")
## DESIGN-TBD (docs/questions/k1.md 1): the paving: dark flagstones, brass inlaid along the lanes.
@export var street_color: Color = Color(0.27, 0.25, 0.25)
@export var inlay_color: Color = Color(0.56, 0.45, 0.29)
## How wet the street looks, the lamps' haze on it at grazing angles (0 dry).
@export_range(0.0, 1.0, 0.05) var street_wet: float = 0.6
## DESIGN-TBD (docs/questions/k1.md 1): how deep the service trenches under the street go (deeper than
## the fall that ends a run, so a fall never visibly lands).
@export_range(4.5, 15.0, 0.1, "suffix:m") var trench_depth: float = 6.5

@export_group("Iron and brass")
## The facades' dark iron, four tones.
@export var iron_colors: PackedColorArray = PackedColorArray([
	Color(0.2, 0.17, 0.155), Color(0.22, 0.18, 0.155), Color(0.175, 0.165, 0.165), Color(0.235, 0.195, 0.165)])
## Dark painted iron: girders, ribs, cornices, balcony rails.
@export var iron_color: Color = Color(0.13, 0.12, 0.125)
## Aged brass: the pipes, the rails, the trims and the frames. Lit metal, never neon.
@export var brass_color: Color = Color(0.58, 0.44, 0.24)
@export var brass_dim_color: Color = Color(0.42, 0.32, 0.18)
## The pale highlight polished brass turns toward.
@export var brass_shine_color: Color = Color(0.96, 0.88, 0.7)
## The lamplight the wet street and the glass catch.
@export var lamp_light_color: Color = Color(1.0, 0.85, 0.66)

@export_group("Vault")
## Where the glass roof springs from (the facades' top), and the most it rises at its crown over the
## widest street (a narrower street's vault is shallower).
@export_range(14.0, 40.0, 0.5, "suffix:m") var eave_height: float = 22.0
@export_range(2.0, 14.0, 0.5, "suffix:m") var vault_rise_max: float = 9.0
## The roof is built in bays this long (three panes each), repeating down the street.
@export_range(4.0, 16.0, 0.5, "suffix:m") var bay_length: float = 8.0
## Share of panes missing (broken glass: the night sky shows through).
@export_range(0.0, 0.5, 0.01) var pane_open_share: float = 0.1
## The glass at night: deep blue, warmer low on the arch where it catches the lamplit haze.
@export var pane_color: Color = Color(0.05, 0.085, 0.14)
@export var pane_lit_color: Color = Color(0.3, 0.21, 0.13)
@export var star_color: Color = Color(0.8, 0.84, 0.95)
## DESIGN-TBD (docs/questions/k1.md 6): the glass roof as a whole (broken panes, still fans) and how often an
## iron girder crosses the street under it, carrying banners and lanterns; the shares of bays with a lantern, a
## ceiling fan and banners.
@export_range(10.0, 120.0, 1.0, "suffix:m") var crossbeam_spacing: float = 32.0
@export_range(0.0, 1.0, 0.01) var lantern_share: float = 0.5
@export_range(0.0, 1.0, 0.01) var fan_share: float = 0.28
@export_range(0.0, 1.0, 0.01) var banner_share: float = 0.7
## Heavy cloth in muted aubergine, ochre, indigo and slate (lit, never glowing), and its width.
@export var banner_colors: PackedColorArray = PackedColorArray([
	Color(0.26, 0.15, 0.3), Color(0.42, 0.3, 0.14), Color(0.16, 0.2, 0.36), Color(0.2, 0.26, 0.3)])
@export_range(0.8, 3.0, 0.1, "suffix:m") var banner_width: float = 1.8

@export_group("Casino ceilings")
## DESIGN-TBD (docs/questions/k1.md 5): how often each kind of ceiling appears, as relative weights (a
## footbridge across the street needs a ceiling across every lane; narrower ones become gantries).
@export_range(0.0, 10.0, 0.1) var footbridge_weight: float = 3.0
@export_range(0.0, 10.0, 0.1) var gantry_weight: float = 3.0
@export_range(0.0, 10.0, 0.1) var sign_weight: float = 2.0

@export_group("Facades")
## The calm band: the facades are flush up to here (no wall-vent shapes, nothing glowing or sticking
## out), and decorative signs, lights and machinery start at decor_min_height.
@export_range(5.0, 12.0, 0.25, "suffix:m") var band_top: float = 7.0
## Balconies, pipes, air-conditioning units and blade signs (the things that stand out of a face by more
## than a hand's width, over the outer lane) start no lower than this: the facades are flush below it. The
## Casino's own is 10 m (nothing hangs over the lanes below about 10 m but ceilings: the arrival flyover's
## camera flies under 9.5 m); The House's arena raises it above the machine (13.5 m: nothing hangs over the
## lanes below about 14.4 m but ceilings, and the machine fills the street to 35 cm off the walls).
## DESIGN-TBD (docs/questions/k1.md 8): the arena is plainer than the street leading to it.
@export_range(6.0, 20.0, 0.25, "suffix:m") var overhang_min_height: float = 10.0
## DESIGN-TBD (docs/questions/k1.md 5): how many balconies, pipe runs, air-conditioning units and
## planters the facades carry: per building, the chance of each.
@export_range(0.0, 1.0, 0.01) var balcony_share: float = 0.55
@export_range(0.0, 1.0, 0.01) var pipe_share: float = 0.55
@export_range(0.0, 1.0, 0.01) var unit_share: float = 0.5
@export_range(0.0, 1.0, 0.01) var planter_share: float = 0.5
## Dim, unlit ivy in the planters, far from the ramps' and speed pads' hazard green.
@export var ivy_color: Color = Color(0.16, 0.23, 0.15)
## Signs' dark panels and the lit lettering's palette (warm white, violet and blue only).
@export var sign_panel_color: Color = Color(0.07, 0.065, 0.075)
## DESIGN-TBD (docs/questions/k1.md 2): the reference's pink, cyan, green and orange boards, kept as dim
## painted signs in muted dusty rose, teal, moss and ochre: lit like any wall, never glowing (the hazard
## colours glow only on hazards), a share of the blade signs.
@export var dim_sign_colors: PackedColorArray = PackedColorArray([
	Color(0.5, 0.3, 0.36), Color(0.2, 0.4, 0.42), Color(0.3, 0.38, 0.22), Color(0.55, 0.42, 0.2)])
@export_range(0.0, 1.0, 0.01) var dim_sign_share: float = 0.3

## Built on first use and shared by every mesh (exports changed later don't reach them).
var _street: CasinoStreet
var _vault: CasinoVault
var _casino_ceilings: CasinoCeilings
var _casino_props: CasinoProps


func _init() -> void:
	super()
	_casino_palette()


## The Marketplace's exports the shared pieces read, given the Casino's palette (the .tres only has to
## say what differs from this). A night scene lit by lamps and signs, not by a setting sun.
func _casino_palette() -> void:
	# The sky and the haze: a deep night over a warm, lamplit haze (the arcade receding into it).
	sky_zenith_color = Color(0.02, 0.03, 0.07)
	sky_horizon_color = Color(0.24, 0.16, 0.12)
	haze_color = Color(0.5, 0.32, 0.2)
	haze_strength = 0.8
	abyss_color = Color(0.03, 0.025, 0.03)
	skyline_color = Color(0.09, 0.07, 0.08)
	skyline_window_color = Color(0.5, 0.36, 0.22)
	moon_radius = 0.0
	ambient_color = Color(0.74, 0.66, 0.6)
	fog_color = Color(0.3, 0.2, 0.14)
	fog_begin = 12.0
	fog_end = 170.0
	glow_intensity = 0.8
	glow_threshold = 1.1
	emissive_scale = 4.0
	sheen_color = Color(0.5, 0.34, 0.2)
	sheen_strength = 0.1
	# The street's gaps.
	gap_inside_color = Color(0.075, 0.065, 0.07)
	dust_color = Color(0.7, 0.58, 0.44, 0.28)
	scrap_color = Color(0.62, 0.55, 0.45, 0.55)
	streak_color = Color(0.85, 0.74, 0.58, 0.2)
	# The overhead strings: nothing hangs below this over the lanes (the arrival flyover's and The
	# House's limits), and the arena raises it.
	bunting_height = 16.0
	# The walls: iron, brass and warm light.
	stucco_colors = iron_colors
	trim_color = Color(0.5, 0.39, 0.22)
	window_metal_color = Color(0.56, 0.43, 0.24)
	frost_color = Color(0.5, 0.42, 0.3)
	grime_color = Color(0.07, 0.06, 0.05)
	plinth_color = Color(0.17, 0.15, 0.14)
	plinth_light_color = Color(0.3, 0.26, 0.22)
	shutter_colors = PackedColorArray([Color(0.2, 0.17, 0.14), Color(0.17, 0.2, 0.22), Color(0.26, 0.19, 0.14),
		Color(0.22, 0.22, 0.2)])
	window_warm_color = Color(1.0, 0.87, 0.68)
	window_glow = 0.62
	lamp_color = Color(1.0, 0.87, 0.68)
	bulb_color = Color(1.0, 0.88, 0.7)
	# The first two are the lounges' machine screens (violet, blue); lit signs and marquees pick from all six,
	# warm white (the reference's gold and amber, kept off the hazards' hues) as often as violet and blue.
	neon_colors = PackedColorArray([Color(0.62, 0.46, 1.0), Color(0.36, 0.55, 1.0), Color(0.96, 0.9, 0.78),
		Color(0.97, 0.92, 0.8), Color(0.5, 0.42, 0.95), Color(0.94, 0.88, 0.76)])
	painted_sign_colors = PackedColorArray([Color(0.2, 0.16, 0.3), Color(0.5, 0.4, 0.22), Color(0.18, 0.22, 0.34),
		Color(0.4, 0.34, 0.26), Color(0.26, 0.2, 0.3)])
	ad_colors = PackedColorArray([Color(0.5, 0.4, 0.95), Color(0.3, 0.5, 0.95), Color(0.92, 0.88, 0.8)])
	ceiling_lamp_color = Color(1.0, 0.88, 0.7)
	engine_color = Color(0.45, 0.6, 1.0)
	wall_mark_color = Color(0.5, 0.4, 0.26)
	# Fences, signs, pads: the shared hazard language; the metal around them is the Casino's.
	fence_pole_color = Color(0.5, 0.4, 0.22)
	crate_color = Color(0.2, 0.17, 0.15)
	sign_content_colors = PackedColorArray([Color(0.46, 0.38, 0.8), Color(0.84, 0.8, 0.7), Color(0.3, 0.44, 0.74),
		Color(0.7, 0.62, 0.9)])
	market_metal_color = Color(0.2, 0.17, 0.15)
	girder_color = Color(0.17, 0.16, 0.16)
	concrete_color = Color(0.2, 0.18, 0.17)
	soffit_color = Color(0.2, 0.18, 0.17)
	# Doodads (DESIGN-TBD, docs/questions/k1.md 7: the Marketplace's own, in the Casino's palette): dark cabinets
	# with brass trim, dim screens, deep-green plants in dark pots.
	doodad_pot_color = Color(0.3, 0.22, 0.17)
	doodad_plant_colors = PackedColorArray([Color(0.16, 0.24, 0.15), Color(0.2, 0.28, 0.17), Color(0.14, 0.2, 0.14)])
	doodad_cabinet_colors = PackedColorArray([Color(0.14, 0.1, 0.13), Color(0.11, 0.12, 0.16)])
	doodad_cabinet_trim_color = Color(0.5, 0.39, 0.2)
	doodad_screen_color = Color(0.34, 0.31, 0.38)
	doodad_palette = PackedColorArray([Color(0.3, 0.24, 0.2), Color(0.5, 0.4, 0.22), Color(0.13, 0.12, 0.125)])
	# Sizes of the shop windows' lounges.
	shop_depth = 0.9
	decor_min_height = 8.0
	casino_share = 0.28
	hall_share = 0.14


func make_environment() -> Environment:
	# A night over the covered street: the zenith nearly black with a few stars (glimpsed through the
	# roof's missing panes and over the far end of the street), the horizon a warm lamplit haze, and a
	# skyline in silhouette that the fog swallows. Nothing in the sky glows.
	var sky := {"zenith_color": sky_zenith_color, "horizon_color": sky_horizon_color, "haze_color": haze_color,
		"haze_strength": haze_strength, "haze_height": 0.2, "abyss_color": abyss_color, "skyline_color": skyline_color,
		"window_color": skyline_window_color, "moon_color": moon_color, "moon_direction": moon_direction,
		"moon_radius": moon_radius, "moon_clarity": moon_clarity, "star_amount": 0.7}
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
	facades().build(batch, side, face_x, start, end)
	if side < 0:
		_left_wall_extras(batch, face_x, start, end)
	batch.commit(parent)
	citizens().build(parent, side, face_x, start, end)


## A wall gap (ZoneSkin.wall_gap): with the left wall, the street below and the roof overhead are still
## there (the roof doesn't care that the building under it is cut away).
func wall_gap(parent: Node3D, side: int, face_x: float, start: float, end: float, gap: Vector2) -> void:
	_wall_x = absf(face_x)
	wall_gap_marks(parent, side, face_x, start, end, gap)
	if side < 0:
		var batch := MeshBatch.new()
		_left_wall_extras(batch, face_x, start, end)
		batch.commit(parent)


## What isn't a lane's or a wall's, built with the left wall: the shade far below the street with the
## drifting dust, scraps and speed streaks over it, and the glass roof high overhead.
func _left_wall_extras(batch: MeshBatch, face_x: float, start: float, end: float) -> void:
	street().below(batch, absf(face_x), start, end)
	vault().build(batch, absf(face_x), start, end)


func fence(hazard: Hazard, size: Vector3, ground_y: float, gapped: bool) -> void:
	casino_props().fence(hazard, size, ground_y, gapped)


func wall_sign(hazard: Hazard, size: Vector3) -> void:
	casino_props().wall_sign(hazard, size)


## A ceiling over its lanes, reaching to the wall faces where the section says they are
## (CasinoCeilings: a footbridge across the street needs every lane; over fewer lanes, a narrow ceiling
## (GDD §3), the other kinds build narrower).
func ceiling_section(parent: Node3D, section: CeilingSection) -> void:
	casino_ceilings().build(parent, section.center, section.size, section.lane_edges_x, section.wall_x)


## A ceiling given as its box alone (the wall faces from the chunk's walls).
func hull(parent: Node3D, center: Vector3, size: Vector3, lane_edges_x: Array[float]) -> void:
	casino_ceilings().build(parent, center, size, lane_edges_x, _wall_x if _wall_x > 0.0 else size.x * 0.5 + 0.3)


# --- Materials (built once per skin, shared by every mesh) ------------------------------------

## The Casino's building faces (casino_facade.gdshader): its colours as sRGB Vector3s, converted once
## in the shader, so both renderers draw them alike.
func facade_material() -> ShaderMaterial:
	if not _materials.has(&"facade"):
		_materials[&"facade"] = MeshKit.material("casino_facade.gdshader", {
			"trim_color": srgb(trim_color), "metal_color": srgb(brass_color),
			"shutter_a": srgb(shutter_colors[0]), "shutter_b": srgb(shutter_colors[1]),
			"shutter_c": srgb(shutter_colors[2]), "shutter_d": srgb(shutter_colors[3]),
			"window_warm": srgb(window_warm_color), "window_glow": window_glow,
			"frost_color": srgb(frost_color), "sheen_color": srgb(sheen_color), "sheen_strength": sheen_strength * 1.2,
			"plinth_color": srgb(plinth_color), "plinth_top": gallery_bottom, "storey_base": gallery_top + 0.2,
			"storey": MarketFacades.STOREY, "calm_top": band_top, "decor_top": decor_min_height,
			"bulb_color": srgb(bulb_color), "neon_a": srgb(neon_colors[0]), "neon_b": srgb(neon_colors[1]),
			"grime_color": srgb(grime_color), "grime": wear})
	return _materials[&"facade"]


## The solid kit material with the Casino's uniforms (kit_casino.gdshaderinc).
func _solid_params() -> Dictionary:
	return {"glow_scale": emissive_scale, "sheen_color": sheen_color, "sheen_strength": sheen_strength,
		"cas_shine": srgb(brass_shine_color), "cas_inlay": srgb(inlay_color), "cas_lamp": srgb(lamp_light_color),
		"cas_wet": street_wet, "cas_pane": srgb(pane_color), "cas_pane_lit": srgb(pane_lit_color),
		"cas_star": srgb(star_color), "cas_pane_len": bay_length / 3.0, "cas_vault_y": eave_height,
		"cas_vault_rise": vault_rise_max * 0.6, "cas_banner_w": banner_width, "cas_banner_trim": srgb(brass_dim_color)}


## A colour as an sRGB Vector3: it reaches a shader unconverted on every renderer, and the shader
## converts it once (docs/ARCHITECTURE.md, Zone skins: colours in a skin's own uniforms).
static func srgb(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)


# --- Builders ----------------------------------------------------------------------------------

## The Casino's facades (they stand in for the Marketplace's, which every shared piece asks for: the
## shop windows for the citizens, the feed's billboards).
func facades() -> MarketFacades:
	if _facades == null:
		_facades = CasinoFacades.new(self)
	return _facades


func street() -> CasinoStreet:
	if _street == null:
		_street = CasinoStreet.new(self)
	return _street


func vault() -> CasinoVault:
	if _vault == null:
		_vault = CasinoVault.new(self)
	return _vault


func casino_ceilings() -> CasinoCeilings:
	if _casino_ceilings == null:
		_casino_ceilings = CasinoCeilings.new(self)
	return _casino_ceilings


func casino_props() -> CasinoProps:
	if _casino_props == null:
		_casino_props = CasinoProps.new(self)
	return _casino_props

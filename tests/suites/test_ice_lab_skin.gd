extends SkinSuite
## The Ice Lab's skin (IceLabSkin, Zone 9, task Q2; GDD §5: a frozen industrial laboratory), in its three leans (data/skins/ice_lab_frost_skin.tres,
## ice_lab_skin.tres, ice_lab_lab_skin.tres: the owner, October 21, 2026: level 1 leans into the snow and the industrial side, the last level into the
## laboratory, level 2 between). The shared skin checks (SkinSuite) over a whole level for 3, 5 and 6 lanes (the Ice Lab's own campaign level once task
## Q1 adds it, else the Dead Zone's, whose walls are the long ones with wall running and whose ceilings it has), then the zone's own:
## - the palette and the colour rule (GDD §5, looser in the later zones): nothing glows but the machine lamps (small amber points, high up, under the
##   bloom threshold and a fraction of a gap edge), the screens, the status lights and the jars' liquid (pale, desaturated blue-white, dim), the hazards,
##   triggers and the orange ends of gaps and ceilings; the jars' cyan is nothing like the anti-grav pad's;
## - the sky is none: no stars, no moon, no skyline, the fog and the horizon the same cold haze;
## - the shaders: its patterns in their own include (ids 110-119) with one include and one dispatch line in the kit's solid shader, colours as sRGB
##   Vector3s, the lamps' slow breathing holds still with Reduced flashing (kit_ice_lab.gdshaderinc: il_lamp_surface);
## - gaps read as holes: below the catwalk only deep shade far darker than the grating as rendered, the orange edge on both of its edges;
## - the walls: bays laid from the wall's own distance, built once in wall space and set on either wall by a transform; below the wall-run band's top nothing
##   stands out of the face more than 4.5 cm (IceLabParts.PROUD, the convention of every wall-running zone: `wall - 0.05`), nothing is recessed or lit
##   there, the jar alcoves and the lit screens are above it; no alcove beside a window cyborg; the frost lean has the
##   industrial bays and the lab lean the laboratory's, the Octodog bays turn up in the lab;
## - the hall beyond the walls is drawn once however the walls are cut, with a far wall, crane runways and cross girders;
## - the play space stays clear and nothing glows on the lane side of the wall line;
## - the ceilings: both kinds turn up, one lane wide when asked, flat underneath, nothing but the hanging rods rising past the limit;
## - the doodads: five looks in each size class, the Octodog jar among the small ones with a name of its own (and a way to find it), none in a hazard's
##   colour, picked by the lean;
## - the lean: three skins that differ the way the owner asked (snow, bays, ceilings, doodads, fog).

const SKIN_PATH: String = "res://data/skins/ice_lab_skin.tres"
const FROST_PATH: String = "res://data/skins/ice_lab_frost_skin.tres"
const LAB_PATH: String = "res://data/skins/ice_lab_lab_skin.tres"
const ZONE_PATH: String = "res://data/zones/ice_lab.tres"
const ICE_LAB_LEVEL_PATH: String = "res://data/levels/ice_lab_1.tres"
## Until Q1 adds the Ice Lab's levels: the Dead Zone's (long wall sections with wall running, hosts, ceilings).
const FALLBACK_LEVEL_PATH: String = "res://data/levels/dead_zone_1.tres"
## What tells a machine lamp from a gap edge now that both are orange (GDD §5, looser in the later zones; the Terminal's rule): the lamp's hue lies at least
## this far (of a turn) toward yellow from the edge's and short of the hazard signs' yellow; its glow is at most this share of the edge's, and under the
## bloom threshold the edge is over; and it hangs at least this high above the street.
const LAMP_HUE_OVER_EDGE: float = 0.04
const LAMP_HUE_SHORT_OF_SIGN: float = 0.02
const LAMP_EDGE_SHARE: float = 0.4
const LAMP_MIN_HEIGHT: float = 6.2
## The grating's darkest tone as the shader draws it (kit_ice_lab.gdshaderinc, il_grating): the slots between the bars, base x 0.42.
const SLOT_SHADE: float = 0.42
## The showcase track's gap (SkinSuite.showcase_track): lane 3 of 5, 50-57 m.
const GAP_LANE := Vector2(1.2, 3.6)
const GAP := Vector2(50.0, 57.0)
## The most a thing on the wall may stand out of its face where a runner can touch it, as every wall-running zone's suite checks it (wall - 0.05).
const WALL_RELIEF: float = 0.05


func run() -> void:
	var skin := load(SKIN_PATH) as IceLabSkin
	var frost := load(FROST_PATH) as IceLabSkin
	var lab := load(LAB_PATH) as IceLabSkin
	check(skin != null and frost != null and lab != null, "the three Ice Lab skins load")
	if skin == null or frost == null or lab == null:
		return
	if ResourceLoader.exists(ZONE_PATH):
		var zone := load(ZONE_PATH) as ZoneDef
		check(zone != null, "the Ice Lab zone loads")
		if zone != null and not (zone.skin is IceLabSkin):
			# Task Q1 adds the zone with a stand-in skin; the merge switches its skin_path (and each level's) to these skins.
			print("  note: the Ice Lab zone still uses a placeholder skin (%s); its skin_path must become %s" % [zone.skin_path, SKIN_PATH])
	var level_path: String = ICE_LAB_LEVEL_PATH if ResourceLoader.exists(ICE_LAB_LEVEL_PATH) else FALLBACK_LEVEL_PATH
	start_error_count()
	check(skin.enemy_variant == &"burned" and CyborgSuit.look_for(skin.enemy_variant) == CyborgSuit.BURNED,
		"anything with a cyborg's look wears the burned base until the owner asks for the Ice Lab's own")
	for each: IceLabSkin in [frost, skin, lab]:
		var env: Environment = each.make_environment()
		check(env != null and env.sky != null and env.glow_enabled and env.fog_enabled, "the environment has a sky, glow and fog (lean %.2f)" % each.lab_share)
		_palette(each, env)
	_lean(frost, skin, lab)
	_shaders(skin)
	for lanes: int in [3, 5, 6]:
		await whole_level(skin, "ice lab", level_path, lanes)
	await whole_level(frost, "ice lab (frost)", level_path, 5)
	await whole_level(lab, "ice lab (lab)", level_path, 5)
	await hazards_and_triggers(skin)
	await _surfaces(skin, level_path)
	await _gaps(skin, level_path)
	_bays(frost, skin, lab)
	await _hall_once(skin)
	await _clear_play_space(skin, level_path)
	_ceilings(frost, skin, lab)
	_doodads(frost, skin, lab)
	await determinism(skin, level_path)
	for each: IceLabSkin in [frost, skin, lab]:
		doodads_ok(each, "ice lab (lean %.2f)" % each.lab_share)
	stop_error_count("building ice lab levels")


# --- Palette ------------------------------------------------------------------------------------

## Before anything is built: everything lit stays cold and mid-to-dark, the hazards far more saturated than any of them, the lamps amber but told from a
## gap edge, the screens and the jars pale and dim, the sky none (the hall is whole) and the haze the colour the street fades into.
func _palette(skin: IceLabSkin, env: Environment) -> void:
	var lit: Array[Color] = [skin.grating_color, skin.gutter_color, skin.gap_inside_color, skin.pit_floor_color, skin.steel_color, skin.frame_color,
		skin.tile_color, skin.enamel_color, skin.rack_color, skin.door_color, skin.brain_color, skin.post_color, skin.trigger_metal_color,
		skin.ice_color, skin.snow_color, skin.frost_color, skin.crystal_color]
	lit.append_array(Array(skin.sign_content_colors))
	var vivid: PackedStringArray = []
	for c: Color in lit:
		if _chroma(c) > 0.45:
			vivid.append(str(c))
	check(vivid.is_empty(), "no surface is as saturated as a hazard: %s" % ", ".join(vivid))
	for hazard: Color in [skin.fence_color, skin.sign_frame_color, skin.gap_edge_color, skin.pad_color, skin.ramp_color, skin.speed_pad_color]:
		check(_chroma(hazard) > 0.5, "hazard colour %s is far more saturated than anything in the zone" % hazard)
	# The brain is a pinkish grey, never fence pink: dim and desaturated.
	check(skin.brain_color.s < 0.2 and skin.brain_color.v < 0.65, "a brain is a dull grey-pink, nothing like the fence's pink (%s)" % skin.brain_color)
	# The lamps: amber, told from a gap edge by hue, brightness and height.
	var lamp: Color = skin.lamp_color
	var edge: Color = skin.gap_edge_color
	check(lamp.r >= lamp.g and lamp.g >= lamp.b and lamp.s > 0.7 and lamp.h > 0.05, "a machine lamp is an amber (%s, hue %.0f degrees)" % [lamp, lamp.h * 360.0])
	check(lamp.h >= edge.h + LAMP_HUE_OVER_EDGE and lamp.h <= skin.sign_frame_color.h - LAMP_HUE_SHORT_OF_SIGN,
		"a lamp is yellower than a gap edge (%.0f degrees against %.0f) and short of a hazard sign's yellow (%.0f)" % [
			lamp.h * 360.0, edge.h * 360.0, skin.sign_frame_color.h * 360.0])
	var edge_peak: float = _max_linear(edge) * IceLabFloor.LIP_GLOW * skin.emissive_scale
	var edge_peak_compat: float = edge.v * IceLabFloor.LIP_GLOW * skin.emissive_scale
	var lamp_peak: float = _max_linear(lamp) * skin.lamp_glow * skin.emissive_scale
	var lamp_peak_compat: float = lamp.v * skin.lamp_glow_compat * skin.emissive_scale
	check(lamp_peak < skin.glow_threshold and edge_peak > skin.glow_threshold and lamp_peak <= edge_peak * LAMP_EDGE_SHARE,
		"a lamp glows dimly (%.2f) under the bloom threshold (%.2f) and well under a gap edge, which blooms (%.2f)" % [lamp_peak, skin.glow_threshold, edge_peak])
	check(lamp_peak_compat < skin.glow_threshold and lamp_peak_compat <= edge_peak_compat * LAMP_EDGE_SHARE and lamp_peak_compat >= lamp_peak,
		"the same on the Compatibility renderer: %.2f, a fraction of the edge's %.2f, and no dimmer than elsewhere (%.2f)" % [lamp_peak_compat, edge_peak_compat, lamp_peak])
	check(skin.lamp_min_height >= LAMP_MIN_HEIGHT, "the lamps hang high above the street, never at floor level (%.1f m)" % skin.lamp_min_height)
	# The screens, the status lights and the jars' liquid: pale, desaturated, dim: nothing like the pad's saturated cyan or a hazard's glow.
	for pale: Color in [skin.screen_color, skin.liquid_color]:
		check(_chroma(pale) < 0.4 and _chroma(pad_cyan(skin)) > 0.8, "a pale glow is desaturated (%.2f) where the pad's cyan is not (%.2f)" % [_chroma(pale), _chroma(pad_cyan(skin))])
	for glow: Array in [[skin.screen_color, skin.screen_glow, skin.screen_glow_compat], [skin.liquid_color, skin.liquid_glow, skin.liquid_glow_compat]]:
		var c: Color = glow[0]
		var peak: float = _max_linear(c) * float(glow[1]) * skin.emissive_scale
		var peak_compat: float = c.v * float(glow[2]) * skin.emissive_scale
		check(peak < skin.glow_threshold and peak <= edge_peak * LAMP_EDGE_SHARE and peak_compat < skin.glow_threshold and peak_compat <= edge_peak_compat * LAMP_EDGE_SHARE,
			"%s glows dimly: %.2f (%.2f on the Compatibility renderer) against a gap edge's %.2f" % [c, peak, peak_compat, edge_peak])
	# No sky: nothing in it but the haze, and the street fades into the same haze.
	var sky := env.sky.sky_material as ShaderMaterial
	check(float(sky.get_shader_parameter("star_amount")) == 0.0 and float(sky.get_shader_parameter("moon_radius")) == 0.0
		and float(sky.get_shader_parameter("skyline_scale")) == 0.0, "there is no sky: no stars, no moon, no skyline")
	check(env.fog_light_color.is_equal_approx(skin.haze()), "the street fades into the cold haze")
	check(skin.haze().b > skin.haze().g and skin.haze().g > skin.haze().r and skin.haze().v < 0.4, "the haze is a dim cold blue (%s)" % skin.haze())
	# The hall's hand-set heights keep clear of the ceilings and the camera under them.
	check(skin.band_top > tuning.ceiling_height + TrackBuilder.HULL_THICKNESS + IceLabCeilings.TOP_LIMIT,
		"the wall's relief starts above every ceiling's top (%.1f over %.1f)" % [skin.band_top, tuning.ceiling_height + TrackBuilder.HULL_THICKNESS + IceLabCeilings.TOP_LIMIT])
	check(skin.crane_height - 0.6 - IceLabHall.HOOK_MIN > 0.5 and IceLabHall.HOOK_MIN > tuning.ceiling_height + TrackBuilder.HULL_THICKNESS + IceLabCeilings.TOP_LIMIT,
		"the chains' hooks hang over every ceiling's top (%.1f m)" % IceLabHall.HOOK_MIN)


static func pad_cyan(skin: IceLabSkin) -> Color:
	return skin.pad_color


## The three leans differ the way the owner asked: more snow in the frost one, more laboratory in the lab one, the middle between, and each set
## its shader's own uniforms.
func _lean(frost: IceLabSkin, skin: IceLabSkin, lab: IceLabSkin) -> void:
	check(frost.lab_share < skin.lab_share and skin.lab_share < lab.lab_share and frost.lab_share <= 0.2 and lab.lab_share >= 0.8,
		"the leans: level 1 heavily into snow and industry (%.2f), level 3 heavily into the laboratory (%.2f), level 2 between (%.2f)" % [
			frost.lab_share, lab.lab_share, skin.lab_share])
	check(frost.snow_amount() > skin.snow_amount() and skin.snow_amount() > lab.snow_amount(), "the snow thins from the frost level to the lab (%.2f, %.2f, %.2f)" % [
		frost.snow_amount(), skin.snow_amount(), lab.snow_amount()])
	var values: Array[float] = []
	for each: IceLabSkin in [frost, skin, lab]:
		var m: ShaderMaterial = each.solid_material()
		values.append(float(m.get_shader_parameter("il_snow_amount")))
		check(is_equal_approx(float(m.get_shader_parameter("il_lab")), each.lab_share), "the shader gets the lean (%.2f)" % each.lab_share)
	check(values[0] > values[1] and values[1] > values[2], "the floor's snow follows the lean (%s)" % [values])
	check(frost.solid_material() != lab.solid_material() and frost.solid_material().shader == lab.solid_material().shader,
		"each lean has its own material on the one shader")
	check(frost.haze().v > lab.haze().v, "the frost level's haze is brighter and bluer, the lab's darker")
	check(frost.bay_weight(IceLabWalls.BAY_ICE) > lab.bay_weight(IceLabWalls.BAY_ICE) and frost.bay_weight(IceLabWalls.BAY_JARS) < lab.bay_weight(IceLabWalls.BAY_JARS),
		"the bays' weights follow the lean")


# --- Shaders -------------------------------------------------------------------------------------

## The skin's shaders: its patterns in their own include (ids 110-119) with one include and one dispatch in the kit's solid shader; colours reach them as
## sRGB Vector3s (so both renderers match); the lamps' breathing honours Reduced flashing.
func _shaders(skin: IceLabSkin) -> void:
	var m: ShaderMaterial = skin.solid_material()
	var code: String = m.shader.code
	check(code.count("#include \"res://scripts/world/meshes/shaders/kit_ice_lab.gdshaderinc\"") == 1 and code.count("ice_lab_surface(") == 1,
		"the Ice Lab's patterns are one include and one dispatch line in the kit's solid shader")
	var ids: Dictionary = {}
	var constants: Dictionary = (load("res://scripts/world/meshes/mesh_kit.gd") as Script).get_script_constant_map()
	var count: int = 0
	for key: String in constants:
		if not key.begins_with("PAT_"):
			continue
		var id: int = int(constants[key])
		check(not ids.has(id), "pattern id %d (%s) is its own" % [id, key])
		ids[id] = key
		if key.begins_with("PAT_IL_"):
			count += 1
			check(id >= 110 and id < 120, "%s is in the Ice Lab's block of ids (%d)" % [key, id])
	check(count == 10, "the Ice Lab has ten patterns (%d)" % count)
	var vectors: PackedStringArray = []
	for u: String in ["sheen_color", "il_ice", "il_snow", "il_frost", "il_liquid", "il_screen"]:
		if not m.get_shader_parameter(u) is Vector3:
			vectors.append(u)
	var sky := skin.make_environment().sky.sky_material as ShaderMaterial
	for u: String in ["zenith_color", "horizon_color", "haze_color"]:
		if not sky.get_shader_parameter(u) is Vector3:
			vectors.append(u)
	check(vectors.is_empty(), "shader colours are sRGB Vector3s, the same on both renderers: %s" % ", ".join(vectors))
	var include: String = FileAccess.get_file_as_string("res://scripts/world/meshes/shaders/kit_ice_lab.gdshaderinc")
	var lamp: String = include.substr(include.find("vec3 il_lamp_surface("), include.find("// PAT_IL_JAR (117)") - include.find("vec3 il_lamp_surface("))
	check(lamp.contains("reduced_flashing"), "the lamps hold still with Reduced flashing")
	check(not include.contains("TIME"), "the include never reads the time itself: the lamps' breathing and the bubbles come from the one parameter the dispatch hands them")
	check(lamp.contains("t * (0.9 + 0.5 * ph)"), "a lamp breathes slowly and smoothly, about once every 4 to 7 seconds, never a strobe")
	check(skin.drift_material().shader == MeshKit.shader("drift.gdshader"), "the drifting snow and mist use the kit's drift shader")
	check(not include.contains("il_lane_w") and not code.contains("il_lane_w"), "the shader holds no lane width of its own")
	check(IceLabFloor.half_width_param(1.2) == 960.0 and IceLabFloor.half_width_param(1.5, MeshKit.IL_GUTTER) == 1204.0,
		"a half width is passed in the pattern's parameter, in centimetres over the flags")
	check(is_equal_approx(IceLabFloor.half_lane(Vector3(0.0, -0.5, 0.0), Vector3(3.0, 1.0, 10.0), 0.0), 1.5)
		and is_equal_approx(IceLabFloor.half_lane(Vector3(-5.4, -0.5, 0.0), Vector3(3.6, 1.0, 10.0), -4.8), 1.2),
		"a lane's half width is its floor box's, an outer lane's box (running on to the wall) counting from its nearer side")
	# The kit's Reduced-flashing handling of the hazards is untouched: the global uniform is declared once, by the flash include.
	check(code.count("global uniform float reduced_flashing") + FileAccess.get_file_as_string("res://scripts/world/meshes/shaders/kit_flash.gdshaderinc").count("global uniform float reduced_flashing") == 1,
		"Reduced flashing is the one global uniform the kit's flash include declares")


# --- Surfaces ------------------------------------------------------------------------------------

## Over the showcase track and a whole level: only hazard signs wear stripes; nothing glows but hazards, triggers, the orange edges and ends, the lamps,
## the screens, the status lights and the jars' liquid, each in its own colour and at most its own dim glow; the lamps hang high; the catwalk is drawn with
## each lane's own half width.
func _surfaces(skin: IceLabSkin, level_path: String) -> void:
	var track: TrackBuilder = showcase_track(skin)
	var stripes: int = 0
	var edges: Dictionary = {}
	var kinds: Dictionary = {}
	for node: Node in nodes_of(track, func(n: Node) -> bool: return n is MeshInstance3D):
		var m := node as MeshInstance3D
		if m.mesh == null or m.is_in_group(&"debug_hitbox"):
			continue
		var in_hazard: bool = under_hazard(m)
		for s: int in m.mesh.get_surface_count():
			var material: Material = m.mesh.surface_get_material(s)
			var arrays: Array = m.mesh.surface_get_arrays(s)
			var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
			if material == skin.drift_material():
				for k: Vector2 in uv2:
					kinds[roundi(k.x)] = true
				continue
			if material != skin.solid_material():
				continue
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			for i: int in verts.size():
				var c: Color = colors[i]
				var p: Vector3 = m.global_transform * verts[i]
				stripes += int(roundi(uv2[i].x) == MeshKit.PAT_STRIPES and not in_hazard)
				if c.a > 0.2 and _same_rgb(c, skin.gap_edge_color) and absf(p.y) < 0.01 and p.x > GAP_LANE.x - 0.01 and p.x < GAP_LANE.y + 0.01:
					for edge: float in [GAP.x, GAP.y]:
						if absf(-p.z - edge) < 0.25:
							edges[edge] = true
	check(edges.has(GAP.x) and edges.has(GAP.y), "a gap keeps the orange edge glow on both of its edges (%s)" % [edges.keys()])
	check(stripes == 0, "only hazard signs wear the striped frame (%d striped vertices elsewhere)" % stripes)
	check(kinds.has(MeshKit.DRIFT_ASH) and kinds.has(MeshKit.DRIFT_SMOKE) and kinds.has(MeshKit.DRIFT_STREAK),
		"the still track carries drifting snow, puffs of mist and speed streaks (%s)" % [kinds.keys()])
	await free_track(track)
	var glows: PackedStringArray = []
	var counts := {"lamps": 0, "screens": 0, "jars": 0, "halos": 0}
	var widths: Array[int] = [0, 0]
	var worst := {"lamp": 0.0, "screen": 0.0, "jar": 0.0, "lamp_low": INF, "halo": 0.0}
	var layout: LevelLayout = level(level_path, 5, 0.6)
	var lane_half_cm: int = roundi(tuning.lane_width * 50.0)
	await visit_level(layout, skin, func(m: MeshInstance3D, arrays: Array, material: Material) -> void:
		if under_hazard(m) or _set_piece(m) or material == skin.drift_material():
			return
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2] if arrays[Mesh.ARRAY_TEX_UV2] != null else PackedVector2Array()
		for i: int in verts.size():
			var c: Color = colors[i]
			var p: Vector3 = m.global_transform * verts[i]
			var pattern: int = roundi(uv2[i].x) if not uv2.is_empty() else -1
			# The grating carries the lane's half width, from the floor boxes (the gutters' own are narrower).
			if material == skin.solid_material() and pattern == MeshKit.PAT_IL_GRATING and (roundi(uv2[i].y) & MeshKit.IL_GUTTER) == 0:
				widths[int((roundi(uv2[i].y) >> IceLabFloor.WIDTH_SHIFT) == lane_half_cm)] += 1
			var glowing: bool = material == skin.glow_material() or (material == skin.solid_material() and c.a > 0.0)
			if not glowing or _same_rgb(c, skin.gap_edge_color):
				continue
			if absf(-p.z - layout.length) < 2.0:
				continue
			if material == skin.glow_material():
				# The lamps' halos: faint amber cards, high up.
				if _same_rgb(c, skin.lamp_color) and c.a <= 0.15:
					counts["halos"] += 1
					worst["halo"] = maxf(float(worst["halo"]), c.a)
				elif glows.size() < 4:
					glows.append("glow card %s at %s" % [c, p])
				continue
			if pattern == MeshKit.PAT_IL_LAMP and _same_rgb(c, skin.lamp_color) and c.a <= skin.lamp_tube_glow() + 0.001:
				counts["lamps"] += 1
				worst["lamp"] = maxf(float(worst["lamp"]), c.a)
				worst["lamp_low"] = minf(float(worst["lamp_low"]), p.y)
			elif (pattern == MeshKit.PAT_IL_LAMP or pattern == MeshKit.PAT_IL_SCREEN) and _same_rgb(c, skin.screen_color) and c.a <= skin.screen_tube_glow() + 0.001:
				counts["screens"] += 1
				worst["screen"] = maxf(float(worst["screen"]), c.a)
			elif pattern == MeshKit.PAT_IL_JAR and _same_rgb(c, skin.liquid_color) and c.a <= skin.liquid_tube_glow() + 0.001:
				counts["jars"] += 1
				worst["jar"] = maxf(float(worst["jar"]), c.a)
			elif glows.size() < 4:
				glows.append("%s pattern %d at %s" % [c, pattern, p]))
	check(glows.is_empty(), "nothing glows but hazards, triggers, the orange edges and ends, the lamps, the screens, the status lights and the jars' liquid: %s" % ", ".join(glows))
	check(counts["lamps"] > 0 and counts["screens"] > 0 and counts["jars"] > 0 and counts["halos"] > 0,
		"the lamps, screens, jars and lamp halos are drawn (%s)" % [counts])
	check(widths[1] > 0 and widths[0] == 0, "every lane of catwalk is drawn with its own half width, %d cm (%d vertices, %d without)" % [lane_half_cm, widths[1], widths[0]])
	check(float(worst["lamp"]) <= skin.lamp_tube_glow() + 0.001 and float(worst["screen"]) <= skin.screen_tube_glow() + 0.001
		and float(worst["jar"]) <= skin.liquid_tube_glow() + 0.001, "no lamp, screen or jar glows past its dim level (%s)" % [worst])
	check(float(worst["lamp_low"]) >= LAMP_MIN_HEIGHT - 0.1, "every machine lamp, as built, hangs high above the street (the lowest at %.1f m)" % float(worst["lamp_low"]))


## Gaps read as holes at a glance (CLAUDE.md readability rules): what a gap shows (the catwalk's truss in shade, the frozen floor) stays clearly darker than
## the grating as rendered (SkinSuite.hole_share, against the darkest the catwalk is drawn: its slots), and nothing in it glows but the orange edge; no
## floor is drawn in the edge's colour; the showcase gap carries the full orange edge on both sides (the lip right at the collision edge, the strip along the
## top of its cut, the halo on the far side).
func _gaps(skin: IceLabSkin, level_path: String) -> void:
	var slot: Color = Color(minf(skin.grating_color.r, skin.gutter_color.r), minf(skin.grating_color.g, skin.gutter_color.g),
		minf(skin.grating_color.b, skin.gutter_color.b)) * Color(SLOT_SHADE, SLOT_SHADE, SLOT_SHADE)
	check_hole_share("the Ice Lab", [skin.gap_inside_color], [skin.pit_floor_color], _linear_luminance(slot))
	var like_edge: PackedStringArray = []
	for c: Color in [skin.grating_color, skin.gutter_color, skin.steel_color, skin.frame_color, skin.snow_color, skin.ice_color]:
		if _near_colour(c, skin.gap_edge_color):
			like_edge.append(str(c))
	check(like_edge.is_empty(), "no floor or underside is drawn in the gap edge's colour: %s" % ", ".join(like_edge))
	var track: TrackBuilder = showcase_track(skin)
	var strip := Vector2(INF, -INF)
	var lip := Vector2(INF, -INF)
	var halo: bool = false
	for node: Node in nodes_of(track, func(n: Node) -> bool: return n is MeshInstance3D):
		var m := node as MeshInstance3D
		for s: int in m.mesh.get_surface_count() if m.mesh != null else 0:
			var material: Material = m.mesh.surface_get_material(s)
			if material != skin.solid_material() and material != skin.glow_material():
				continue
			var arrays: Array = m.mesh.surface_get_arrays(s)
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i: int in verts.size():
				var p: Vector3 = m.global_transform * verts[i]
				if not _same_rgb(colors[i], skin.gap_edge_color) or p.x < GAP_LANE.x - 0.2 or p.x > GAP_LANE.y + 0.2:
					continue
				if material == skin.glow_material():
					halo = halo or absf(-p.z - GAP.y) < 0.1
				elif absf(-p.z - GAP.y) <= 0.3:
					if p.y < -0.001 and colors[i].a >= IceLabFloor.STRIP_GLOW - 0.001:
						strip = Vector2(minf(strip.x, p.y), maxf(strip.y, p.y))
					elif absf(p.y) < 0.001 and colors[i].a >= IceLabFloor.LIP_GLOW - 0.001:
						lip = Vector2(minf(lip.x, -p.z), maxf(lip.y, -p.z))
	check(strip.y - strip.x >= IceLabFloor.STRIP_HEIGHT - 0.001 and strip.y > -0.05, "the far edge's orange strip runs along the top of its cut: %s" % strip)
	check(lip.x > GAP.y - 0.01 and lip.y - lip.x >= IceLabFloor.EDGE_LIP - 0.001, "the far edge's orange lip lies on the floor right at the collision edge: %s" % lip)
	check(halo, "the far edge carries its orange halo toward the approaching runner")
	await free_track(track)
	var limit: float = maxf(_linear_luminance(skin.gap_inside_color), _linear_luminance(skin.pit_floor_color)) + 0.0001
	for lanes: int in [3, 5]:
		var layout: LevelLayout = level(level_path, lanes, 0.6, 9)
		var bad: PackedStringArray = []
		var count: Array[int] = [0]
		await visit_level(layout, skin, func(m: MeshInstance3D, arrays: Array, material: Material) -> void:
			if under_hazard(m) or _set_piece(m) or material == skin.drift_material():
				return
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2] if arrays[Mesh.ARRAY_TEX_UV2] != null else PackedVector2Array()
			for i: int in verts.size():
				var p: Vector3 = m.global_transform * verts[i]
				# The finish gantry's posts stand on the floor; the hall's pit floor and pillars are the hall's (beyond the walls: past the wall line).
				if p.y >= -0.01 or absf(-p.z - layout.length) < 1.0:
					continue
				count[0] += 1
				var c: Color = colors[i]
				var fault: String = ""
				if material == skin.solid_material():
					var strip_edge: bool = _same_rgb(c, skin.gap_edge_color) and c.a >= IceLabFloor.STRIP_GLOW - 0.001
					var pattern: int = roundi(uv2[i].x)
					var dark: bool = pattern == MeshKit.PAT_IL_UNDER and c.a == 0.0 and _linear_luminance(c) <= limit
					# Pillars in the hall beyond the walls (steel, dark in the fog), standing down to the frozen floor: not under any hole.
					var hall_steel: bool = absf(p.x) >= geo_wall(lanes) - 0.001 and c.a == 0.0
					if not strip_edge and not dark and not hall_steel:
						fault = "%s pattern %d" % [c, pattern]
				elif material == skin.glow_material():
					if not _same_rgb(c, skin.gap_edge_color):
						fault = "glow %s" % c
				else:
					fault = "material %s" % (material.resource_path.get_file() if material != null else "none")
				if fault != "" and bad.size() < 4:
					bad.append("%s at %s" % [fault, p]))
		check(bad.is_empty() and count[0] > 0, "below the catwalk there is only deep shade and the orange edge (%d lanes, %d vertices): %s" % [
			lanes, count[0], ", ".join(bad)])


func geo_wall(lanes: int) -> float:
	return TrackGeometry.new(lanes, tuning).wall_x()


# --- The walls -------------------------------------------------------------------------------------

## The bays: their kinds follow the lean (the frost level's wall is pipes, lattice, tanks and ice, the lab's racks, consoles, tile, doors and jars, with
## Octodog jars in the lab and almost none in the frost), every bay of every kind and variant keeps below the band's top to PROUD off the wall face (the jar
## alcoves recessed behind it), a bay is built once and set by transform (the same bay mesh on both walls), a window cyborg's place gets a plain bay, a stretch a
## wall gap cuts is plain plating, and the left and right walls meet the same track distances.
func _bays(frost: IceLabSkin, skin: IceLabSkin, lab: IceLabSkin) -> void:
	var industrial: Array[int] = [IceLabWalls.BAY_PIPES, IceLabWalls.BAY_LATTICE, IceLabWalls.BAY_TANK, IceLabWalls.BAY_ICE]
	var laboratory: Array[int] = [IceLabWalls.BAY_CONSOLES, IceLabWalls.BAY_RACKS, IceLabWalls.BAY_TILE, IceLabWalls.BAY_DOOR, IceLabWalls.BAY_JARS, IceLabWalls.BAY_OCTODOG]
	var share: Dictionary = {}
	var octo: Dictionary = {}
	for each: IceLabSkin in [frost, skin, lab]:
		var lab_bays: int = 0
		var octodogs: int = 0
		var seen: Dictionary = {}
		for k: int in 400:
			for side: int in [-1, 1]:
				var kind: int = each.walls().bay_kind(side, k)
				seen[kind] = true
				lab_bays += int(laboratory.has(kind))
				octodogs += int(each.walls().is_octodog_bay(side, k))
		share[each.lab_share] = float(lab_bays) / 800.0
		octo[each.lab_share] = float(octodogs) / 800.0
		var missing: PackedStringArray = []
		for kind: int in IceLabWalls.BAY_COUNT:
			if not seen.has(kind):
				missing.append(str(kind))
		check(missing.is_empty() or each == frost, "every kind of bay turns up (lean %.2f): missing %s" % [each.lab_share, ",".join(missing)])
	var shares: Array = [share[frost.lab_share], share[skin.lab_share], share[lab.lab_share]]
	check(shares[0] < 0.3 and shares[2] > 0.7 and shares[0] < shares[1] and shares[1] < shares[2],
		"the walls lean the way the owner asked: the laboratory's bays are %.0f%% of the frost level's, %.0f%% of the middle's, %.0f%% of the lab's" % [shares[0] * 100.0, shares[1] * 100.0, shares[2] * 100.0])
	check(octo[lab.lab_share] > 0.02 and octo[lab.lab_share] > octo[frost.lab_share] * 3.0 and octo[frost.lab_share] < 0.03,
		"Octodog jars turn up on the lab level's walls and hardly on the frost level's (%.1f%%, %.1f%%)" % [octo[lab.lab_share] * 100.0, octo[frost.lab_share] * 100.0])
	# Relief: in the wall-run band (up to calm_top) every bay (every kind, every variant) stands out of the wall face 5 cm at most, has no opening
	# in it (the half-sunk pipes and the ice's bases bury themselves in the wall, never more than 0.4 m) and does not glow; the jar alcoves (0.8 m
	# deep) and the lit screens are above it.
	var recess_low: float = INF
	var glow_low: float = INF
	var over: PackedStringArray = []
	for each: IceLabSkin in [frost, skin, lab]:
		for kind: int in IceLabWalls.BAY_COUNT + 1:
			for variant: int in IceLabWalls.VARIANTS:
				var mesh: ArrayMesh = each.walls().bay(kind, variant).to_mesh()
				var bay_worst: float = -INF
				for s: int in mesh.get_surface_count():
					var verts: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
					var colors: PackedColorArray = mesh.surface_get_arrays(s)[Mesh.ARRAY_COLOR]
					for i: int in verts.size():
						var v: Vector3 = verts[i]
						if v.y > 0.06 and v.y < each.calm_top:
							bay_worst = maxf(bay_worst, v.x)
						if v.x < -0.4:
							recess_low = minf(recess_low, v.y)
						if colors[i].a > 0.0 and v.y > 0.0:
							glow_low = minf(glow_low, v.y)
				if bay_worst > WALL_RELIEF + 0.0005:
					over.append("lean %.2f kind %d variant %d: %.3f" % [each.lab_share, kind, variant, bay_worst])
	check(IceLabParts.PROUD <= WALL_RELIEF, "the parts' wall relief (%.3f m) is within the convention (%.2f m)" % [IceLabParts.PROUD, WALL_RELIEF])
	check(over.is_empty(), "nothing on a wall stands out of its face more than %.2f m in the wall-run band (below %.1f m): %s" % [WALL_RELIEF, skin.calm_top, ", ".join(over.slice(0, 4))])
	check(recess_low >= skin.calm_top, "the jar alcoves are recessed only above the wall-run band (the lowest recessed point at %.2f m, the band's top at %.1f m)" % [recess_low, skin.calm_top])
	check(glow_low >= skin.calm_top, "nothing on a bay glows below %.1f m: the screens, jars and lamps are over the band (the lowest glow at %.2f m)" % [skin.calm_top, glow_low])
	# A bay is built once: the same mesh for the same kind and variant, and the right wall is the left wall's bay turned.
	var walls: IceLabWalls = skin.walls()
	check(walls.bay(IceLabWalls.BAY_RACKS, 1) == walls.bay(IceLabWalls.BAY_RACKS, 1), "a bay is built once and shared")
	var left := MeshBatch.new()
	var right := MeshBatch.new()
	var k_first: int = 3
	var kind: int = walls.bay_kind(-1, k_first)
	walls.build(left, -1, -geo_wall(5), float(k_first) * IceLabWalls.SLOT, float(k_first + 1) * IceLabWalls.SLOT)
	var right_kind: int = walls.bay_kind(1, k_first)
	walls.build(right, 1, geo_wall(5), float(k_first) * IceLabWalls.SLOT, float(k_first + 1) * IceLabWalls.SLOT)
	var rail_5: int = walls.rail(IceLabWalls.SLOT).vertex_count()
	check(left.vertex_count() == walls.bay(kind, walls.bay_variant(-1, k_first)).vertex_count() + rail_5
		and right.vertex_count() == walls.bay(right_kind, walls.bay_variant(1, k_first)).vertex_count() + rail_5,
		"a bay of the wall is exactly its template and its stretch of rail (%d, %d vertices)" % [left.vertex_count(), right.vertex_count()])
	# The gantry rail along the top is one for a whole wall piece, not one in every bay: a chunk's wall is its bays and one rail.
	var chunk := MeshBatch.new()
	walls.build(chunk, -1, -geo_wall(5), 80.0, 80.0 + TrackBuilder.CHUNK_LENGTH)
	var expected: int = walls.rail(TrackBuilder.CHUNK_LENGTH).vertex_count()
	for kb: int in 8:
		expected += walls.bay(walls.bay_kind(-1, 16 + kb), walls.bay_variant(-1, 16 + kb)).vertex_count()
	check(chunk.vertex_count() == expected, "a chunk's wall is its eight bays and one gantry rail (%d vertices, %d expected)" % [chunk.vertex_count(), expected])
	# A window cyborg's place is plain, and the span of a wall gap is cut to plain plating.
	var jar_k: int = -1
	for k: int in 200:
		if lab.walls().bay_kind(-1, k) == IceLabWalls.BAY_JARS:
			jar_k = k
			break
	check(jar_k >= 0, "the lab level has a jar bay to test with")
	if jar_k >= 0:
		var u0: float = float(jar_k) * IceLabWalls.SLOT
		var plain := MeshBatch.new()
		var jars := MeshBatch.new()
		lab.walls().build(jars, -1, -geo_wall(5), u0, u0 + IceLabWalls.SLOT)
		var cyborgs: Array[Dictionary] = [{"type": "window_cyborg", "side": -1, "at": u0 + 2.5}]
		lab.note_wall_enemies(-1, u0, u0 + 40.0, cyborgs)
		check(lab.reserved_near(-1, u0 + 2.5, 1.0), "a window cyborg's place is noted")
		lab.walls().build(plain, -1, -geo_wall(5), u0, u0 + IceLabWalls.SLOT)
		var none: Array[Dictionary] = []
		lab.note_wall_enemies(-1, u0, u0 + 40.0, none)
		var deep_plain: float = 0.0
		var deep_jars: float = 0.0
		for pair: Array in [[plain, 0], [jars, 1]]:
			var mesh: ArrayMesh = (pair[0] as MeshBatch).to_mesh()
			for s: int in mesh.get_surface_count():
				for v: Vector3 in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
					var depth: float = absf(v.x) - geo_wall(5)
					if int(pair[1]) == 0:
						deep_plain = maxf(deep_plain, depth)
					else:
						deep_jars = maxf(deep_jars, depth)
		check(deep_plain < 0.3 and deep_jars >= 0.7, "beside a window cyborg no alcove opens in the wall (%.2f m behind the face against a jar bay's %.2f)" % [deep_plain, deep_jars])
		var cut := MeshBatch.new()
		lab.walls().build(cut, -1, -geo_wall(5), u0 + 1.0, u0 + 4.0)
		var cut_deep: float = 0.0
		var mesh_cut: ArrayMesh = cut.to_mesh()
		for s: int in mesh_cut.get_surface_count():
			for v: Vector3 in mesh_cut.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				cut_deep = maxf(cut_deep, absf(v.x) - geo_wall(5))
		check(cut_deep < 0.3 and mesh_cut != null, "a bay a wall gap cuts is plain plating: nothing recessed (%.2f m)" % cut_deep)


## The hall (IceLabHall) is drawn once per chunk's stretch whatever the walls do: with every wall piece and gap that tile a chunk, each far wall, runway,
## girder and pillar is built exactly once: the census of a chunk's walls (solid pieces and gaps' extras together) equals the census of the hall built over
## the whole chunk in one go.
func _hall_once(skin: IceLabSkin) -> void:
	var wall: float = geo_wall(5)
	for lo: float in [80.0, 120.0]:
		var hi: float = lo + TrackBuilder.CHUNK_LENGTH
		var whole := MeshBatch.new()
		skin.hall().build(whole, wall, lo, hi)
		# The same chunk cut into three pieces, a gap in the middle (as a layout's wall pieces and gaps tile it).
		var parts := MeshBatch.new()
		skin.hall().build(parts, wall, lo, lo + 13.0)
		skin.hall().build(parts, wall, lo + 13.0, lo + 27.5)
		skin.hall().build(parts, wall, lo + 27.5, hi)
		var a: Dictionary = _hall_census(whole, skin)
		var b: Dictionary = _hall_census(parts, skin)
		check(int(a["girders"]) >= 1 and int(a["far"]) >= 2 and int(a["pillars"]) >= 2, "a chunk's hall has its girders, far walls and pillars (%s)" % [a])
		check(int(a["roof"]) >= 6 and int(a["trusses"]) >= 4, "a chunk's hall is closed overhead: a roof across it at %.0f m with its trusses (%s)" % [skin.roof_height, a])
		check(a["trusses"] == b["trusses"] and int(b["roof"]) >= 6, "the roof's trusses are built once however the walls are cut (%s)" % [b])
		check(a["girders"] == b["girders"] and a["pillars"] == b["pillars"] and a["crystals"] == b["crystals"],
			"the hall holds its girders (%d), pillars (%d) and crystals (%d) once however the walls are cut (%s)" % [a["girders"], a["pillars"], a["crystals"], b])
	await tree.process_frame


## What a hall batch holds, counted from its vertices: girder boxes (the cross girders' plating, a box 0.9 m deep), far wall quads, pillars (0.9 m square
## boxes from the frozen floor up) and crystals (the far walls' big ones).
func _hall_census(batch: MeshBatch, skin: IceLabSkin) -> Dictionary:
	var out := {"girders": 0, "far": 0, "pillars": 0, "crystals": 0, "roof": 0, "trusses": 0}
	var mesh: ArrayMesh = batch.to_mesh()
	var wall: float = geo_wall(5)
	var far: float = wall + skin.hall_extra
	var pillar_low: Dictionary = {}
	var girder_z: Dictionary = {}
	var crystal_z: Dictionary = {}
	var truss_z: Dictionary = {}
	for s: int in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		for i: int in verts.size():
			var v: Vector3 = verts[i]
			if absf(absf(v.x) - far) < 0.01 and v.y > skin.crane_height and roundi(uv2[i].x) == MeshKit.PAT_IL_ICE and roundi(uv2[i].y) == 0:
				out["far"] += 1
			if roundi(uv2[i].x) == MeshKit.PAT_IL_STEEL and absf(v.y - (skin.crane_height + 0.55 + 0.45)) < 0.01 and absf(v.x) > wall + 3.0:
				girder_z[snappedf(v.z, 0.01)] = true
			if roundi(uv2[i].x) == MeshKit.PAT_IL_STEEL and roundi(uv2[i].y) == 1 and absf(v.y - skin.roof_height) < 0.001 and absf(absf(v.x) - far) < 0.01:
				out["roof"] += 1
			if roundi(uv2[i].x) == MeshKit.PAT_IL_STEEL and absf(v.y - (skin.roof_height - IceLabHall.ROOF_TRUSS)) < 0.001 and absf(absf(v.x) - far) < 0.01:
				truss_z[snappedf(v.z, 0.01)] = true
			if roundi(uv2[i].x) == MeshKit.PAT_IL_STEEL and absf(v.y + skin.pit_depth) < 0.001:
				pillar_low[Vector2i(roundi(v.x * 10.0), roundi(v.z * 10.0))] = true
			if roundi(uv2[i].x) == MeshKit.PAT_IL_ICE and roundi(uv2[i].y) == 1 and absf(v.x) > far - 5.0 and v.y > 4.0:
				crystal_z[snappedf(v.z, 0.5)] = true
	out["far"] = int(out["far"] > 0) * 2
	out["girders"] = girder_z.size()
	out["pillars"] = pillar_low.size()
	out["crystals"] = crystal_z.size()
	out["trusses"] = truss_z.size()
	return out


## Between the floor and the ceiling, over the lanes, the skin builds nothing solid but hazards, triggers and the play's set pieces (_set_piece: doodads,
## falling gantryways), anywhere in a whole level; nothing sticks out of
## the walls through the wall-run band by more than 5 cm (`wall - 0.05`, as the Corporate, Golden and Beach suites check it) and nothing on the walls or the
## lane side of them glows there but the orange edges.
func _clear_play_space(skin: IceLabSkin, level_path: String) -> void:
	for lanes: int in [3, 6]:
		var layout: LevelLayout = level(level_path, lanes, 0.6, 5)
		var geo := TrackGeometry.new(lanes, tuning)
		var half: float = geo.half_width()
		var wall: float = geo.wall_x()
		var intruders: PackedStringArray = []
		var sticking: PackedStringArray = []
		var lit: PackedStringArray = []
		var band: float = minf(skin.calm_top, tuning.ceiling_height - 0.1)
		await visit_level(layout, skin, func(m: MeshInstance3D, arrays: Array, material: Material) -> void:
			if _set_piece(m) or material == skin.drift_material():
				return
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var additive: bool = material == skin.glow_material()
			for i: int in verts.size():
				var p: Vector3 = m.global_transform * verts[i]
				var at_finish: bool = absf(-p.z - layout.length) < 1.0
				if not additive and absf(p.x) < half - 0.01 and p.y > 0.06 and p.y < tuning.ceiling_height - 0.1 and not at_finish and intruders.size() < 4:
					intruders.append(str(p))
				elif not additive and absf(p.x) >= half - 0.01 and absf(p.x) < wall - WALL_RELIEF and p.y > 0.06 and p.y < band \
						and not at_finish and sticking.size() < 4:
					sticking.append(str(p))
				var glowing: bool = additive or (material == skin.solid_material() and colors[i].a > 0.0)
				if glowing and absf(p.x) < wall + 1.0 and p.y > 0.06 and p.y < band and not at_finish \
						and not _same_rgb(colors[i], skin.gap_edge_color) and lit.size() < 4:
					lit.append("%s %s" % [colors[i], p]))
		check(intruders.is_empty(), "nothing decorative stands in the play space (%d lanes): %s" % [lanes, ", ".join(intruders)])
		check(sticking.is_empty(), "nothing sticks out of the walls through the wall-run band by more than %.2f m (%d lanes): %s" % [WALL_RELIEF, lanes, ", ".join(sticking)])
		check(lit.is_empty(), "nothing glows over the lanes or on the walls in the wall-run band, but the orange edges (%d lanes): %s" % [lanes, ", ".join(lit)])


# --- Ceilings and doodads -------------------------------------------------------------------------

## The ceilings: both kinds turn up at every lean, more gantries at the frost end and more walkways at the lab end, every one built for a single lane at 3, 5
## and 6 lanes in every lane: a flat underside over exactly its lane, nothing below it, nothing but the hanging rods rising past the limit.
func _ceilings(frost: IceLabSkin, skin: IceLabSkin, lab: IceLabSkin) -> void:
	var gantries: Dictionary = {}
	for each: IceLabSkin in [frost, skin, lab]:
		var counts: Dictionary = {}
		for i: int in 300:
			var size := Vector3(tuning.lane_width, TrackBuilder.HULL_THICKNESS, 24.0 + float(i % 5) * 4.0)
			var kind: int = each.ceilings().kind_of(Vector3(0.0, 6.4, -(100.0 + i * 7.3)), size)
			counts[kind] = int(counts.get(kind, 0)) + 1
		for kind: int in [IceLabCeilings.Kind.GANTRY, IceLabCeilings.Kind.WALKWAY]:
			check(int(counts.get(kind, 0)) > 30, "ceilings of kind %d turn up (lean %.2f: %s)" % [kind, each.lab_share, counts])
		gantries[each.lab_share] = int(counts.get(IceLabCeilings.Kind.GANTRY, 0))
	check(gantries[frost.lab_share] > gantries[skin.lab_share] and gantries[skin.lab_share] > gantries[lab.lab_share],
		"the gantries thin out toward the lab (%s)" % [gantries])
	var problems: PackedStringArray = []
	var ceilings: IceLabCeilings = skin.ceilings()
	for lanes: int in [3, 5, 6]:
		var geo := TrackGeometry.new(lanes, tuning)
		for lane: int in lanes:
			for kind: int in [IceLabCeilings.Kind.GANTRY, IceLabCeilings.Kind.WALKWAY]:
				var size := Vector3(tuning.lane_width, TrackBuilder.HULL_THICKNESS, 32.0)
				var x: float = geo.lane_x(lane)
				var mesh: ArrayMesh = ceilings.mesh_for(kind, lane % 4, size, [] as Array[float], x, geo.wall_x())
				var half: float = tuning.lane_width * 0.5 + 0.01
				var tag: String = "%d lanes, lane %d, kind %d" % [lanes, lane, kind]
				var top: float = 0.0
				var below: float = 0.0
				var wide: float = 0.0
				var tall_wide: float = 0.0
				for s: int in mesh.get_surface_count():
					for v: Vector3 in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
						below = minf(below, v.y)
						wide = maxf(wide, absf(v.x))
						if v.y > IceLabCeilings.TOP_LIMIT + 0.01:
							tall_wide = maxf(tall_wide, absf(v.x))
						top = maxf(top, v.y)
				# Only the thin hanging rods rise past the limit, and they stay over the lane.
				if below < -0.06 or wide > half or top > IceLabCeilings.ROD_TOP + 0.5 or tall_wide > half:
					problems.append("%s: below %.3f, wide %.2f, top %.2f" % [tag, below, wide, top])
	check(problems.is_empty(), "every ceiling is one lane wide, flat underneath and low:\n  %s" % "\n  ".join(problems.slice(0, 6)))


## The doodads: five looks in each size class, the Octodog jar among the small ones under its own name, a way to find it, every card look named on its body,
## none in a hazard's colour, and the lean picks among them (more crystals and crates at the frost end, more jars, racks and consoles at the lab's).
func _doodads(frost: IceLabSkin, skin: IceLabSkin, lab: IceLabSkin) -> void:
	var cards := DoodadCards.for_zone(IceLabDoodads.ZONE)
	check(cards.ok, "the Ice Lab has doodad cards (tools/godot.sh doodads --only=ice_lab)")
	if not cards.ok:
		return
	for size: StringName in LevelLayout.DOODAD_SIZES:
		var looks: Array = cards.designs.get(String(size), [])
		check(looks.size() == 5, "the %s doodads have five looks (%d)" % [size, looks.size()])
		for d: Dictionary in looks:
			check(IceLabDoodads.LOOKS.has(String(d["name"])), "%s has a laboratory affinity (IceLabDoodads.LOOKS)" % d["name"])
			for hex: String in d["colors"]:
				var c := Color.html(hex)
				check(not (c.r > 0.55 and c.g < 0.45 and c.b < 0.35) and not (c.g > 0.6 and c.r < 0.45 and c.b < 0.5) and c.v <= 1.0, "%s's colours are no hazard's (%s)" % [d["name"], hex])
	for name: String in IceLabDoodads.LOOKS:
		var found: bool = false
		for size: StringName in LevelLayout.DOODAD_SIZES:
			for d: Dictionary in cards.designs.get(String(size), []):
				found = found or d["name"] == name
		check(found, "the look %s has a design in the manifest" % name)
	# The Octodog jar, in the small class under its own name.
	var small_names: Array[String] = []
	for d: Dictionary in cards.designs.get("small", []):
		small_names.append(String(d["name"]))
	check(small_names.has(String(IceLabDoodads.OCTODOG_JAR)) and small_names.has("brain_jar"), "the small doodads include the brain jar and the Octodog jar (%s)" % [small_names])
	for each: IceLabSkin in [frost, skin, lab]:
		var doodads: IceLabDoodads = each.doodads()
		var seed_found: int = doodads.look_seed_for(&"small", IceLabDoodads.OCTODOG_JAR)
		check(seed_found >= 0 and doodads.is_octodog_jar(&"small", seed_found) and doodads.look_name(&"small", seed_found) == "octodog_jar",
			"a look seed finds the Octodog jar at lean %.2f (seed %d)" % [each.lab_share, seed_found])
		var body := Node3D.new()
		each.doodad(body, tuning.doodad_size(&"small"), &"small", 1, seed_found)
		check(body.has_meta(IceLabDoodads.META_LOOK) and body.get_meta(IceLabDoodads.META_LOOK) == IceLabDoodads.OCTODOG_JAR,
			"the built doodad carries its look's name, so Q5 can tell it from the brain jar beside it (%s)" % [body.get_meta(IceLabDoodads.META_LOOK, "none")])
		check(not each.doodad_debris_colors(body, &"small", 1, seed_found).is_empty(), "a smashed Octodog jar has pieces to fly off in")
		body.free()
		# The same look wherever it is built and whichever way it pushes: the Octodog jar is a card look in its box, nothing more.
		var a := Node3D.new()
		var b := Node3D.new()
		each.doodad(a, tuning.doodad_size(&"small"), &"small", -1, seed_found)
		each.doodad(b, tuning.doodad_size(&"small"), &"small", 1, seed_found)
		check((a.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh == (b.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh,
			"an Octodog jar looks the same whichever side it pushes to (%.2f)" % each.lab_share)
		a.free()
		b.free()
	# The lean picks among the looks: the crystal clusters are likelier at the frost end, the jars at the lab's.
	var crystals: Dictionary = {}
	var jars: Dictionary = {}
	for each: IceLabSkin in [frost, skin, lab]:
		var c: int = 0
		var j: int = 0
		for look_seed: int in 600:
			for size: StringName in LevelLayout.DOODAD_SIZES:
				var look: String = each.doodads().look_name(size, look_seed)
				c += int(look.begins_with("crystal"))
				j += int(look.contains("jar"))
		crystals[each.lab_share] = c
		jars[each.lab_share] = j
	check(crystals[frost.lab_share] > crystals[skin.lab_share] and crystals[skin.lab_share] > crystals[lab.lab_share] and jars[lab.lab_share] > jars[skin.lab_share] and jars[skin.lab_share] > jars[frost.lab_share],
		"the doodads lean the way the owner asked: crystals %s, jars %s" % [crystals, jars])
	check(jars[frost.lab_share] > 0 and crystals[lab.lab_share] > 0, "every look still turns up at the far end of the lean (jars %d, crystals %d)" % [jars[frost.lab_share], crystals[lab.lab_share]])


static func _chroma(c: Color) -> float:
	return maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))


static func _same_rgb(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01


static func _max_linear(c: Color) -> float:
	var l: Color = c.srgb_to_linear()
	return maxf(l.r, maxf(l.g, l.b))


static func _linear_luminance(c: Color) -> float:
	return srgb_luminance(c)


## Whether `c` is within the gap edge's hue and brightness range (a floor in that colour would pass for the edge).
static func _near_colour(c: Color, edge: Color) -> bool:
	return absf(c.h - edge.h) < 0.06 and c.s > 0.6 and c.v > 0.6


func _under(node: Node, test: Callable) -> bool:
	var parent: Node = node.get_parent()
	while parent != null:
		if test.call(parent):
			return true
		parent = parent.get_parent()
	return false


## Part of the play rather than the hall's scenery, so the whole-level checks leave it to its own suite: under an area (a
## hazard, a trigger, a doodad's or a pillar's body), or a falling gantryway's (task Q3: its walkway hangs over a lane at a
## ceiling's height, its wreck lies flat in the lane once it has fallen, built hidden; its shadow and its red warning line
## are drawn on the lane; test_gantryways checks every skin's gantryway looks: lit, never glowing, inside their boxes).
func _set_piece(node: Node) -> bool:
	return _under(node, func(n: Node) -> bool: return n is Area3D or n is Gantryway)

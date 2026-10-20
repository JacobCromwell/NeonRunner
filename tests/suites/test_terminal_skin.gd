extends SkinSuite
## The Terminal's skin (TerminalSkin, Zone 8, task O4; GDD §5: an abandoned subway under the city). The shared skin checks
## (SkinSuite) over a whole level for 3, 5 and 6 lanes (the Terminal's own campaign level once task O1 adds it, else the Dead
## Zone's, whose walls are the long ones every other zone has), then the zone's own:
## - the palette and the colour rule (GDD §5, the owner's note on the reference): nothing glows but the work lamps, the hazards,
##   triggers and the orange ends of gaps and ceilings; a lamp glows far below a gap edge and under the bloom threshold, in warm
##   white, never in a hazard's colour; the dead boards and the red-orange plates are matte;
## - the sky is none: no stars, no moon, no skyline, the fog and the horizon the same warm haze;
## - the shaders: its patterns in their own include (ids 100-108) with one include and one dispatch line in the kit's solid shader,
##   colours as sRGB Vector3s, and the failing lamps hold still with Reduced flashing (kit_terminal.gdshaderinc: tm_burn);
## - gaps read as holes: below the track bed only deep shade far darker than the track as rendered, the orange edge on both of
##   its edges;
## - the hall is drawn by the floor alone, whatever the walls do: a chunk with no wall section at all, and one whose outer lane has
##   a hole, still has the hall beyond the kerb over its whole length, once; also over a floor cut (its slices of floor never
##   hold the hall) and with arches crossing the chunk's edge (they add none);
## - the steam is soft smoke (the kit's smoke shader), not a light column; the patterns take the lane's width from the floor boxes;
## - the arches (wall sections one space long, mostly in pairs, O1) and stumps (about half height, a ruin): nothing in the play
##   space, nothing more than 5 cm off the wall line through the wall-run band, a stump about half its arch's height with rubble
##   and rebar, nothing of either inside the wall line; a wall gap draws no orange marks, nor does the open space between arches
##   (O1's wall_opening);
## - the play space stays clear and nothing glows on the lane side of the wall line;
## - the ceilings: all three kinds turn up, each one lane wide, nothing but a walkway's rods rising past the limit;
## - the doodads: three size classes with looks of their own, none in a hazard's colour.

const TERMINAL_SKIN_PATH: String = "res://data/skins/terminal_skin.tres"
const TERMINAL_ZONE_PATH: String = "res://data/zones/terminal.tres"
## The skin task O1's zone uses until the merge switches it to the Terminal's.
const PLACEHOLDER_SKIN_PATH: String = "res://data/skins/dead_zone_skin.tres"
const TERMINAL_LEVEL_PATH: String = "res://data/levels/terminal_1.tres"
## Until O1 adds the Terminal's levels: the Dead Zone's (long wall sections, hosts, ceilings).
const FALLBACK_LEVEL_PATH: String = "res://data/levels/dead_zone_1.tres"
## The track bed's darkest tone as the shader draws it (kit_terminal.gdshaderinc, tm_track): the sleepers' dark wood
## (PAT_TERMINAL_TRACK: wood colour x its darkest tone 0.7 x its darkest grain 0.85) lit by the least light (tm_lit: 0.62).
const SLEEPER_WOOD := Color(0.24, 0.17, 0.12)
const SLEEPER_SHADE_MIN: float = 0.7 * 0.85
const LIT_MIN: float = 0.62
## The showcase track's gap (SkinSuite.showcase_track): lane 3 of 5, 50-57 m.
const GAP_LANE := Vector2(1.2, 3.6)
const GAP := Vector2(50.0, 57.0)
## An arch or a stump stands this far off the wall line at most through the wall-run band (up to WALL_RUN_BAND).
const PROUD_MAX: float = 0.05
const WALL_RUN_BAND: float = 6.0


func run() -> void:
	var skin := load(TERMINAL_SKIN_PATH) as TerminalSkin
	check(skin != null, "the terminal skin loads")
	if skin == null:
		return
	if ResourceLoader.exists(TERMINAL_ZONE_PATH):
		var zone := load(TERMINAL_ZONE_PATH) as ZoneDef
		check(zone != null, "the Terminal zone loads")
		if zone != null and zone.skin_path == PLACEHOLDER_SKIN_PATH:
			# Task O1 adds the zone with the Dead Zone's skin as a stand-in; the merge switches its skin_path to this skin.
			print("  note: the Terminal zone still uses the placeholder skin (%s); its skin_path must become %s" % [
				PLACEHOLDER_SKIN_PATH, TERMINAL_SKIN_PATH])
		elif zone != null:
			check(zone.skin is TerminalSkin, "the Terminal uses the terminal skin")
	var level_path: String = TERMINAL_LEVEL_PATH if ResourceLoader.exists(TERMINAL_LEVEL_PATH) else FALLBACK_LEVEL_PATH
	check(skin.enemy_variant == &"burned" and CyborgSuit.look_for(skin.enemy_variant) == CyborgSuit.BURNED,
		"anything with a cyborg's look wears the burned base")
	start_error_count()
	var env: Environment = skin.make_environment()
	check(env != null and env.sky != null and env.glow_enabled and env.fog_enabled, "the terminal environment has a sky, glow and fog")
	_palette(skin, env)
	_shaders(skin)
	for lanes: int in [3, 5, 6]:
		await whole_level(skin, "terminal", level_path, lanes)
	await hazards_and_triggers(skin)
	await _surfaces(skin, level_path)
	await _gaps(skin, level_path)
	await _hall(skin)
	await _hall_once(skin)
	await _arches(skin)
	await _clear_play_space(skin, level_path)
	_ceilings(skin)
	_doodads(skin)
	await determinism(skin, level_path)
	doodads_ok(skin, "terminal")
	stop_error_count("building terminal levels")


## Before anything is built: the lamps and everything lit stay warm and dim, the hazards far more saturated than any of them,
## the sky none (the vault is whole) and the haze the colour the street fades into.
func _palette(skin: TerminalSkin, env: Environment) -> void:
	var lit: Array[Color] = [skin.ballast_color, skin.platform_color, skin.gutter_color, skin.gap_inside_color, skin.pit_floor_color,
		skin.stone_color, skin.tile_color, skin.vault_color, skin.concrete_color, skin.steel_color, skin.rust_color, skin.vine_color,
		skin.board_frame_color, skin.plate_color, skin.post_color, skin.trigger_metal_color]
	for list: PackedColorArray in [skin.car_colors, skin.sign_content_colors]:
		lit.append_array(Array(list))
	var pale: PackedStringArray = []
	for c: Color in lit:
		if c.v > 0.55:
			pale.append(str(c))
	check(pale.is_empty(), "nothing lit is paler than weathered concrete: %s" % ", ".join(pale))
	for hazard: Color in [skin.fence_color, skin.sign_frame_color, skin.gap_edge_color, skin.pad_color, skin.ramp_color,
			skin.speed_pad_color]:
		check(_chroma(hazard) > 0.5, "hazard colour %s is far more saturated than anything in the zone" % hazard)
	var vivid: PackedStringArray = []
	for c: Color in lit:
		if _chroma(c) > 0.3:
			vivid.append(str(c))
	check(vivid.is_empty(), "no surface is as saturated as a hazard: %s" % ", ".join(vivid))
	# The lamps: warm white or sodium, a dim tube far below a gap edge and under the bloom threshold.
	var lamp: Color = skin.lamp_color
	check(lamp.r >= lamp.g and lamp.g >= lamp.b and lamp.g > 0.6 and lamp.b > 0.3,
		"a work lamp is warm white or sodium, never a hazard's orange or yellow (%s)" % lamp)
	var lamp_peak: float = _max_linear(lamp) * skin.lamp_glow * skin.emissive_scale
	var edge_peak: float = _max_linear(skin.gap_edge_color) * TerminalTrack.LIP_GLOW * skin.emissive_scale
	check(lamp_peak < skin.glow_threshold and lamp_peak < edge_peak / 1.4,
		"a lamp glows dimly (%.2f), under the bloom threshold (%.2f) and well under what a gap edge does (%.2f)" % [
			lamp_peak, skin.glow_threshold, edge_peak])
	# No sky: nothing in it but the haze, and the street fades into the same haze.
	var sky := env.sky.sky_material as ShaderMaterial
	check(float(sky.get_shader_parameter("star_amount")) == 0.0 and float(sky.get_shader_parameter("moon_radius")) == 0.0
		and float(sky.get_shader_parameter("skyline_scale")) == 0.0, "there is no sky: no stars, no moon, no skyline")
	check(env.fog_light_color.is_equal_approx(skin.fog_color) and skin.sky_horizon_color.is_equal_approx(skin.fog_color),
		"the street fades into the horizon's own haze")
	check(skin.fog_color.r > skin.fog_color.g and skin.fog_color.g > skin.fog_color.b and skin.fog_color.v < 0.35,
		"the haze is a dim sodium orange (%s)" % skin.fog_color)
	# The hall's hand-set heights keep clear of the single-lane ceilings and the camera under them.
	check(skin.lamp_height > tuning.ceiling_height + TrackBuilder.HULL_THICKNESS + 0.9,
		"the lamps hang over every ceiling's top (%.1f m over %.1f m)" % [skin.lamp_height, tuning.ceiling_height + TrackBuilder.HULL_THICKNESS])
	check(skin.spring_height > tuning.ceiling_height + TrackBuilder.HULL_THICKNESS,
		"the vault springs above every ceiling's top")


## The skin's shaders: its patterns in their own include (ids 100-108) with one include and one dispatch in the kit's solid shader; colours
## reach them as sRGB Vector3s (so both renderers match); the failing lamps honour Reduced flashing.
func _shaders(skin: TerminalSkin) -> void:
	var m: ShaderMaterial = skin.solid_material()
	var code: String = m.shader.code
	check(code.count("#include \"res://scripts/world/meshes/shaders/kit_terminal.gdshaderinc\"") == 1
		and code.count("terminal_surface(") == 1, "the Terminal's patterns are one include and one dispatch in the kit's solid shader")
	var ids: Dictionary = {}
	var constants: Dictionary = (load("res://scripts/world/meshes/mesh_kit.gd") as Script).get_script_constant_map()
	var terminal: int = 0
	for key: String in constants:
		if not key.begins_with("PAT_"):
			continue
		var id: int = int(constants[key])
		check(not ids.has(id), "pattern id %d (%s) is its own" % [id, key])
		ids[id] = key
		if key.begins_with("PAT_TERMINAL_"):
			terminal += 1
			check(id >= 100 and id < 110, "%s is in the Terminal's block of ids (%d)" % [key, id])
	check(terminal == 9, "the Terminal has nine patterns (%d)" % terminal)
	var vectors: PackedStringArray = []
	for u: String in ["sheen_color", "tm_lamp", "tm_haze", "tm_rust", "tm_green", "tm_vine"]:
		if not m.get_shader_parameter(u) is Vector3:
			vectors.append(u)
	var sky := skin.make_environment().sky.sky_material as ShaderMaterial
	for u: String in ["zenith_color", "horizon_color", "haze_color"]:
		if not sky.get_shader_parameter(u) is Vector3:
			vectors.append(u)
	check(vectors.is_empty(), "shader colours are sRGB Vector3s, the same on both renderers: %s" % ", ".join(vectors))
	var include: String = FileAccess.get_file_as_string("res://scripts/world/meshes/shaders/kit_terminal.gdshaderinc")
	var burn: String = include.substr(include.find("float tm_burn("), include.find("// The light of the crown lamps") - include.find("float tm_burn("))
	check(burn.contains("reduced_flashing"), "the failing lamps hold still with Reduced flashing")
	check(include.count("TIME") <= 1 and not include.contains("TIME *"), "the include never reads the time itself: the lamps' brownouts come from one function that is passed it")
	# A slow, smooth dip: the failing lamps' brownout is one dip every few seconds, at 0.31 Hz.
	check(burn.contains("t * 0.31"), "a failing lamp dips every few seconds, never a strobe")
	check(skin.drift_material().shader == MeshKit.shader("drift.gdshader"), "the drifting dust and steam use the kit's drift shader")
	# The plumes of steam are soft alpha-blended smoke (the kit's smoke shader), never an additive light column like a pad's beam.
	var smoke_code: String = skin.smoke_material().shader.code
	check(skin.smoke_material().shader == MeshKit.shader("dead_smoke.gdshader") and smoke_code.contains("blend_mix")
		and not smoke_code.contains("blend_add"), "the steam plumes use the kit's soft, alpha-blended smoke shader")
	# The lane's width is read off each floor piece's box, never fixed in the shader.
	check(not include.contains("tm_lane_w") and not m.shader.code.contains("tm_lane_w"), "the shader holds no lane width of its own")
	check(TerminalTrack.half_width_param(1.2) == 960.0 and TerminalTrack.half_width_param(1.5, MeshKit.TERMINAL_GUTTER) == 1204.0,
		"a half width is passed in the pattern's parameter, in centimetres over the flags")
	check(is_equal_approx(TerminalTrack.half_lane(Vector3(0.0, -0.5, 0.0), Vector3(3.0, 1.0, 10.0), 0.0), 1.5)
		and is_equal_approx(TerminalTrack.half_lane(Vector3(-5.4, -0.5, 0.0), Vector3(3.6, 1.0, 10.0), -4.8), 1.2),
		"a lane's half width is its floor box's, an outer lane's box (running on to the wall) counting from its nearer side")


## Over the showcase track and a whole level: the gap in lane 3 (50-57 m) has the orange edge on both edges; only hazard signs wear
## stripes; nothing vent-like; nothing glows but hazards, triggers, the orange edges and ends, the work lamps and (matte) nothing
## else; lamps stay dim.
func _surfaces(skin: TerminalSkin, level_path: String) -> void:
	var track: TrackBuilder = showcase_track(skin)
	var edges: Dictionary = {}
	var stripes: int = 0
	var solid: Material = skin.solid_material()
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
			if material != solid:
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
		"the still track carries drifting dust, puffs of steam and speed streaks (%s)" % [kinds.keys()])
	await free_track(track)
	var glows: PackedStringArray = []
	var lamps: Array[int] = [0]
	var plumes: Array[int] = [0]
	var stray_plumes: PackedStringArray = []
	var widths: Array[int] = [0, 0]
	var lamp_glow: Array[float] = [0.0]
	var layout: LevelLayout = level(level_path, 5, 0.6)
	var lane_half_cm: int = roundi(tuning.lane_width * 50.0)
	await visit_level(layout, skin, func(m: MeshInstance3D, arrays: Array, material: Material) -> void:
		if under_hazard(m) or _under(m, func(n: Node) -> bool: return n is Area3D) or material == skin.drift_material():
			return
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2] if arrays[Mesh.ARRAY_TEX_UV2] != null else PackedVector2Array()
		for i: int in verts.size():
			var c: Color = colors[i]
			var p: Vector3 = m.global_transform * verts[i]
			if material == skin.smoke_material():
				# A plume of steam: smoke beyond the wall line, in the skin's colour and no more opaque than it says.
				plumes[0] += 1
				if not (_same_rgb(c, skin.steam_jet_color) and c.a <= skin.plume_opacity() + 0.001 and absf(p.x) > geo_wall(5)) and stray_plumes.size() < 4:
					stray_plumes.append("%s at %s" % [c, p])
				continue
			# The track bed's and the platforms' patterns carry the lane's half width, from the floor boxes (the gutters' own are narrower).
			var pattern: int = roundi(uv2[i].x) if not uv2.is_empty() else -1
			if material == solid and (pattern == MeshKit.PAT_TERMINAL_TRACK or (pattern == MeshKit.PAT_TERMINAL_PLATFORM
					and (roundi(uv2[i].y) & MeshKit.TERMINAL_GUTTER) == 0)):
				widths[int((roundi(uv2[i].y) >> TerminalTrack.WIDTH_SHIFT) == lane_half_cm)] += 1
			var glowing: bool = material == skin.glow_material() or (material == solid and c.a > 0.0)
			if not glowing or _same_rgb(c, skin.gap_edge_color):
				continue
			if absf(-p.z - layout.length) < 2.0:
				continue
			var lamp: bool = material == solid and pattern == MeshKit.PAT_TERMINAL_LAMP and c.a <= skin.lamp_glow + 0.001
			lamps[0] += int(lamp)
			if lamp:
				lamp_glow[0] = maxf(lamp_glow[0], c.a)
			elif glows.size() < 4:
				glows.append("%s pattern %d at %s" % [c, pattern, p]))
	check(glows.is_empty(), "nothing glows but hazards, triggers, the orange edges and ends and the work lamps: %s" % ", ".join(glows))
	check(lamps[0] > 0, "the work lamps are drawn (%d vertices)" % lamps[0])
	check(plumes[0] > 0 and stray_plumes.is_empty(), "plumes of steam leak beyond the walls, soft and in the skin's colour (%d vertices): %s" % [
		plumes[0], ", ".join(stray_plumes)])
	check(skin.jet_opacity <= 0.4 and skin.jet_opacity_compat <= 0.6 and skin.jet_opacity_compat >= skin.jet_opacity,
		"a plume is faint smoke on both renderers (%.2f, %.2f on the Compatibility renderer)" % [skin.jet_opacity, skin.jet_opacity_compat])
	check(widths[1] > 0 and widths[0] == 0, "every track bed and platform is drawn with its lane's own half width, %d cm (%d vertices, %d without)" % [
		lane_half_cm, widths[1], widths[0]])
	check(lamp_glow[0] <= skin.lamp_glow + 0.001, "no lamp glows past the skin's lamp glow (%.2f)" % lamp_glow[0])


## Gaps read as holes at a glance (CLAUDE.md readability rules): what a gap shows (the dark service level) stays clearly darker
## than the track bed as rendered (SkinSuite.hole_share, against the darkest the track is drawn: the sleepers), and nothing in it
## glows but the orange edge; no floor is drawn in (or near) the edge's colour; the showcase gap carries the full orange edge on
## both sides (the lip right at the collision edge, the strip along the top of its cut, the halo on the far side).
func _gaps(skin: TerminalSkin, level_path: String) -> void:
	var wood: Color = SLEEPER_WOOD * Color(SLEEPER_SHADE_MIN * LIT_MIN, SLEEPER_SHADE_MIN * LIT_MIN, SLEEPER_SHADE_MIN * LIT_MIN)
	check_hole_share("the Terminal", [skin.gap_inside_color], [skin.pit_floor_color], _linear_luminance(wood))
	var like_edge: PackedStringArray = []
	for c: Color in [skin.ballast_color, skin.platform_color, skin.gutter_color, skin.rust_color, skin.concrete_color, SLEEPER_WOOD]:
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
					if p.y < -0.001 and colors[i].a >= TerminalTrack.STRIP_GLOW - 0.001:
						strip = Vector2(minf(strip.x, p.y), maxf(strip.y, p.y))
					elif absf(p.y) < 0.001 and colors[i].a >= TerminalTrack.LIP_GLOW - 0.001:
						lip = Vector2(minf(lip.x, -p.z), maxf(lip.y, -p.z))
	check(strip.y - strip.x >= TerminalTrack.STRIP_HEIGHT - 0.001 and strip.y > -0.05, "the far edge's orange strip runs along the top of its cut: %s" % strip)
	check(lip.x > GAP.y - 0.01 and lip.y - lip.x >= TerminalTrack.EDGE_LIP - 0.001, "the far edge's orange lip lies on the floor right at the collision edge: %s" % lip)
	check(halo, "the far edge carries its orange halo toward the approaching runner")
	await free_track(track)
	var limit: float = maxf(_linear_luminance(skin.gap_inside_color), _linear_luminance(skin.pit_floor_color)) + 0.0001
	for lanes: int in [3, 5]:
		var layout: LevelLayout = level(level_path, lanes, 0.6, 9)
		var bad: PackedStringArray = []
		var count: Array[int] = [0]
		await visit_level(layout, skin, func(m: MeshInstance3D, arrays: Array, material: Material) -> void:
			if under_hazard(m) or _under(m, func(n: Node) -> bool: return n is Area3D) or material == skin.drift_material():
				return
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2] if arrays[Mesh.ARRAY_TEX_UV2] != null else PackedVector2Array()
			for i: int in verts.size():
				var p: Vector3 = m.global_transform * verts[i]
				# The finish gantry's posts stand on the floor, where no gap ever is; the kerb and the second track begin beyond the walls.
				if p.y >= -0.01 or absf(-p.z - layout.length) < 1.0 or absf(p.x) > geo_wall(lanes) + 0.05:
					continue
				count[0] += 1
				var c: Color = colors[i]
				var fault: String = ""
				if material == skin.solid_material():
					var strip_edge: bool = _same_rgb(c, skin.gap_edge_color) and c.a >= TerminalTrack.STRIP_GLOW - 0.001
					var dark: bool = roundi(uv2[i].x) == MeshKit.PAT_TERMINAL_UNDER and c.a == 0.0 and _linear_luminance(c) <= limit
					if not strip_edge and not dark:
						fault = "%s pattern %d" % [c, roundi(uv2[i].x)]
				elif material == skin.glow_material():
					if not _same_rgb(c, skin.gap_edge_color):
						fault = "glow %s" % c
				else:
					fault = "material %s" % (material.resource_path.get_file() if material != null else "none")
				if fault != "" and bad.size() < 4:
					bad.append("%s at %s" % [fault, p]))
		check(bad.is_empty() and count[0] > 0, "below the track bed there is only deep shade and the orange edge (%d lanes, %d vertices): %s" % [
			lanes, count[0], ", ".join(bad)])


func geo_wall(lanes: int) -> float:
	return TrackGeometry.new(lanes, tuning).wall_x()


## The hall (TerminalHall) is drawn by the floor, whatever the walls do: over a stretch with no wall section at all (every wall
## left out), a chunk has the hall beyond the kerb along its whole length (every 10 m cell of it, once), also where the outer
## lane has a hole; and the far wall, the vault and a second track are in it.
func _hall(skin: TerminalSkin) -> void:
	for lanes: int in [3, 5, 6]:
		var layout := RunSim.layout(lanes, 300.0)
		var mid: int = lanes / 2
		layout.wall_gaps.append({"side": -1, "start": 0.0, "end": 400.0})
		layout.wall_gaps.append({"side": 1, "start": 0.0, "end": 400.0})
		layout.gaps.append({"lane": 0, "start": 100.0, "end": 110.0})
		layout.gaps.append({"lane": lanes - 1, "start": 118.0, "end": 126.0})
		layout.gaps.append({"lane": mid, "start": 150.0, "end": 156.0})
		var world := Node3D.new()
		tree.root.add_child(world)
		var track := TrackBuilder.new()
		world.add_child(track)
		track.set_layout(layout, tuning, skin)
		track.update(150.0, 150.0 / tuning.run_speed)
		var wall: float = geo_wall(lanes)
		var h: float = wall + skin.hall_extra
		var chunks: int = 0
		var holes: PackedStringArray = []
		for chunk: Node in track.get_children():
			var index: int = int(String(chunk.name).trim_prefix("Chunk"))
			if index < 1 or index > 5:
				continue
			chunks += 1
			var cells: Dictionary = chunk.get_meta(TerminalHall.META_CELLS, {})
			var first: int = floori(float(index) * TrackBuilder.CHUNK_LENGTH / TerminalHall.CELL)
			for cell: int in range(first, first + int(TrackBuilder.CHUNK_LENGTH / TerminalHall.CELL)):
				if not cells.has(cell):
					holes.append("chunk %d cell %d" % [index, cell])
			# The far walls, as far as the hall's meshes reach, on both sides.
			var far: int = 0
			var vault: bool = false
			var hall_meshes: int = 0
			for node: Node in chunk.get_children():
				if node.name != &"Hall":
					continue
				hall_meshes += 1
				var mi := node as MeshInstance3D
				for s: int in mi.mesh.get_surface_count():
					var verts: PackedVector3Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
					for v: Vector3 in verts:
						far += int(absf(absf(v.x) - h) < 0.01)
						vault = vault or v.y > skin.crown_height - 0.5
			check(far > 0 and vault, "chunk %d has the far walls and the vault (%d lanes)" % [index, lanes])
			check(hall_meshes >= 1 and hall_meshes <= 4, "chunk %d draws its hall in a few meshes (%d, %d lanes)" % [index, hall_meshes, lanes])
		check(chunks >= 4, "the hall's chunks were looked at (%d, %d lanes)" % [chunks, lanes])
		check(holes.is_empty(), "every cell of every chunk has its hall (%d lanes): %s" % [lanes, ", ".join(holes.slice(0, 4))])
		world.queue_free()
		await tree.process_frame


## The hall is drawn once per chunk, under the chunk's root and nowhere else: over a chunk with a floor cut (the lane's floor is drawn
## in slices, each under a node of its own that the cut hides or shortens as it runs) and with arches and stumps crossing a chunk's
## edge (O1 draws each whole, in the chunk where it starts), every chunk holds its work lamps, cars and drifting dust exactly as
## often as one fresh run of the hall over the same stretch draws them (each is drawn once, whatever the floor pieces and the
## cuts), in meshes that hang from the chunk's root and from no slice, and the walls add none.
func _hall_once(skin: TerminalSkin) -> void:
	var lanes: int = 5
	var layout := RunSim.layout(lanes, 300.0)
	var cut: Dictionary = FloorCutPlan.make(lanes / 2, 150.0, 60.0, 50.0, 10.0, tuning.run_speed, 5.0, 5.0)
	layout.cuts.append(cut)
	layout.gaps.append({"lane": 0, "start": 112.0, "end": 119.0})
	var world := Node3D.new()
	tree.root.add_child(world)
	var track := TrackBuilder.new()
	world.add_child(track)
	track.set_layout(layout, tuning, skin)
	track.update(150.0, 150.0 / tuning.run_speed)
	var wall: float = geo_wall(lanes)
	var half: float = tuning.lane_width * 0.5
	var cut_node: FloorCut = track.floor_cut(int(cut["lane"]), float(cut["end"]))
	check(cut_node != null, "the floor cut is built")
	if cut_node == null:
		world.queue_free()
		return
	var cut_chunks: int = 0
	var checked: int = 0
	for chunk: Node in track.get_children():
		var index: int = int(String(chunk.name).trim_prefix("Chunk"))
		if index < 1 or index > 5:
			continue
		var root := chunk as Node3D
		var d0: float = float(index) * TrackBuilder.CHUNK_LENGTH
		var tag: String = "chunk %d" % index
		# The floor cut's slices of floor that lie under this chunk.
		var slices: int = 0
		for s: Dictionary in cut_node.slices():
			slices += int((s["node"] as Node).get_parent() == root)
		cut_chunks += int(slices > 0)
		var reference := Node3D.new()
		tree.root.add_child(reference)
		skin.hall().ensure(reference, wall, half, d0, d0 + TrackBuilder.CHUNK_LENGTH)
		var once: Dictionary = _hall_census(reference, skin)
		var built: Dictionary = _hall_census(root, skin)
		check(int(once["fixtures"]) > 0 and int(once["drift"]) > 0, "a hall of a chunk's length has lamps, cars and dust (%s)" % tag)
		check(built["fixtures"] == once["fixtures"] and built["drift"] == once["drift"],
			"%s holds its lamps, cars (%d, %d wanted) and dust (%d, %d wanted) once (%d floor cut slices)" % [
				tag, built["fixtures"], once["fixtures"], built["drift"], once["drift"], slices])
		check(built["misplaced"] == 0 and built["meshes"] > 0, "%s hangs its hall from its root, never from a floor cut's slice (%d elsewhere)" % [
			tag, built["misplaced"]])
		# An arch and a stump standing across the chunk's far edge, on each side, as O1's track builder gives them.
		for side: int in [-1, 1]:
			var edge: float = d0 + TrackBuilder.CHUNK_LENGTH
			skin.wall_section(root, side, side * wall, edge - 1.8, edge + 1.8)
			skin.wall_stump(root, side, side * wall, edge - 12.0, edge - 8.4)
			skin.wall_opening(root, side, side * wall, edge + 1.8, edge + 22.0, Vector2(edge + 1.8, edge + 22.0))
		var after: Dictionary = _hall_census(root, skin)
		check(after == built, "%s: arches, stumps and openings add no hall (%s, then %s)" % [tag, built, after])
		reference.queue_free()
		checked += 1
	check(checked >= 4 and cut_chunks >= 1, "the chunks with a floor cut and the arches were looked at (%d chunks, %d with a cut)" % [checked, cut_chunks])
	world.queue_free()
	await tree.process_frame


## What the halls under `root` hold that is drawn once per object (the vertices of its work lamps and cars, and of its drifting dust),
## with how many hall meshes there are and how many hang from something other than `root`.
func _hall_census(root: Node3D, skin: TerminalSkin) -> Dictionary:
	var out := {"meshes": 0, "misplaced": 0, "fixtures": 0, "drift": 0}
	for node: Node in root.find_children("*Hall*", "MeshInstance3D", true, false):
		var m := node as MeshInstance3D
		out["meshes"] += 1
		out["misplaced"] += int(m.get_parent() != root)
		for s: int in m.mesh.get_surface_count():
			var arrays: Array = m.mesh.surface_get_arrays(s)
			if m.mesh.surface_get_material(s) == skin.drift_material():
				out["drift"] += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
				continue
			for v: Vector2 in arrays[Mesh.ARRAY_TEX_UV2] as PackedVector2Array:
				var pattern: int = roundi(v.x)
				out["fixtures"] += int(pattern == MeshKit.PAT_TERMINAL_LAMP or pattern == MeshKit.PAT_TERMINAL_CAR)
	return out


## Arches and stumps as O1's track builder will give them: a wall section one space (3.6 m) long and a stump of the same
## length, on both sides at 3, 5 and 6 lanes: nothing inside the wall line but the straps (4.5 cm proud) in the wall-run band,
## the arch reaching up into the vault, the stump about half that, with rubble and rebar at its foot beyond the kerb; a wall gap
## draws no orange marks and the open space shows the hall; a long wall section gets several arches.
func _arches(skin: TerminalSkin) -> void:
	for lanes: int in [3, 5, 6]:
		var wall: float = geo_wall(lanes)
		var h: float = wall + skin.hall_extra
		for side: int in [-1, 1]:
			var tag: String = "%d lanes, side %+d" % [lanes, side]
			var arch_root := Node3D.new()
			tree.root.add_child(arch_root)
			skin.wall_section(arch_root, side, side * wall, 100.0, 103.6)
			var stump_root := Node3D.new()
			tree.root.add_child(stump_root)
			skin.wall_stump(stump_root, side, side * wall, 100.0, 103.6)
			var arch: Dictionary = _bounds_of(arch_root, "Hall")
			var stump: Dictionary = _bounds_of(stump_root, "Hall")
			check(arch["count"] > 0 and stump["count"] > 0, "an arch and a stump are dressed (%s)" % tag)
			# O1 draws each arch and stump whole in the chunk where it starts: they draw themselves and no hall (the floor's).
			check(arch_root.find_children("*Hall*", "MeshInstance3D", true, false).is_empty()
				and stump_root.find_children("*Hall*", "MeshInstance3D", true, false).is_empty(),
				"an arch and a stump draw no hall of their own (%s)" % tag)
			var top: float = skin.hall().vault_y(wall, h)
			check(float(arch["top"]) > top - 0.4 and float(arch["top"]) <= top + 0.8, "the arch reaches up into the vault (%.1f m of %.1f, %s)" % [arch["top"], top, tag])
			check(float(stump["top"]) > top * 0.3 and float(stump["top"]) < top * 0.75, "the stump is broken off about halfway up (%.1f m of %.1f, %s)" % [stump["top"], top, tag])
			check(float(arch["inside"]) >= wall - PROUD_MAX - 0.001, "the arch is no more than 5 cm off the wall line in the wall-run band (%.3f, %s)" % [arch["inside"], tag])
			check(float(stump["inside"]) >= wall - PROUD_MAX - 0.001, "the stump is no more than 5 cm off the wall line in the wall-run band (%.3f, %s)" % [stump["inside"], tag])
			check(float(stump["inside_all"]) >= wall - 0.001, "nothing of the stump is inside the wall line (%.3f, %s)" % [stump["inside_all"], tag])
			check(float(arch["z0"]) >= -104.1 and float(arch["z1"]) <= -99.5, "the arch stays within its space (z %.2f to %.2f, %s)" % [arch["z0"], arch["z1"], tag])
			check(float(stump["rubble_far"]) > wall + 0.3, "the stump has rubble at its foot beyond the kerb (%s)" % tag)
			arch_root.queue_free()
			stump_root.queue_free()
			# A long section (the wall every other zone has) gets several arches.
			var long_root := Node3D.new()
			tree.root.add_child(long_root)
			skin.wall_section(long_root, side, side * wall, 80.0, 120.0)
			check(skin.arches().piers(80.0, 120.0).size() >= 2, "a long wall section gets several arches (%s)" % tag)
			check(skin.arches().piers(100.0, 103.6).size() == 1, "a section a space long gets one (%s)" % tag)
			long_root.queue_free()
			# A wall gap: no marks (no wall running), nothing glowing.
			var gap_root := Node3D.new()
			tree.root.add_child(gap_root)
			skin.wall_gap(gap_root, side, side * wall, 103.6, 126.0, Vector2(103.6, 126.0))
			var glow: int = 0
			for node: Node in gap_root.find_children("*", "MeshInstance3D", true, false):
				for s: int in (node as MeshInstance3D).mesh.get_surface_count():
					for c: Color in (node as MeshInstance3D).mesh.surface_get_arrays(s)[Mesh.ARRAY_COLOR]:
						glow += int(c.a > 0.0)
			check(glow == 0, "a missing arch is not marked: no wall-gap glow (%d, %s)" % [glow, tag])
			gap_root.queue_free()
			# The open space between two arches (O1's wall_opening hook, once per chunk it reaches) draws nothing: the hall shows.
			var opening_root := Node3D.new()
			tree.root.add_child(opening_root)
			skin.wall_opening(opening_root, side, side * wall, 103.6, 126.0, Vector2(103.6, 126.0))
			check(opening_root.get_child_count() == 0, "the open space between arches draws nothing of its own (%s)" % tag)
			opening_root.queue_free()
	await tree.process_frame


## The extent of what a chunk root's non-hall meshes draw (`skip` names a node to leave out): the highest y, the nearest to the
## track's middle through the wall-run band and anywhere, the z range, and how far out the farthest low (rubble-high) vertex
## reaches.
func _bounds_of(root: Node3D, skip: String) -> Dictionary:
	var out := {"count": 0, "top": 0.0, "inside": INF, "inside_all": INF, "z0": INF, "z1": -INF, "rubble_far": 0.0}
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		if node.name == skip:
			continue
		var m := node as MeshInstance3D
		for s: int in m.mesh.get_surface_count():
			var arrays: Array = m.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for v: Vector3 in verts:
				var p: Vector3 = m.global_transform * v
				out["count"] += 1
				out["top"] = maxf(float(out["top"]), p.y)
				out["inside_all"] = minf(float(out["inside_all"]), absf(p.x))
				if p.y < WALL_RUN_BAND:
					out["inside"] = minf(float(out["inside"]), absf(p.x))
				if p.y < 1.2:
					out["rubble_far"] = maxf(float(out["rubble_far"]), absf(p.x))
				out["z0"] = minf(float(out["z0"]), p.z)
				out["z1"] = maxf(float(out["z1"]), p.z)
	return out


## Between the floor and the ceiling, over the lanes, the skin builds nothing solid but hazards and triggers, anywhere in a whole
## level; nothing sticks out of the wall line through the wall-run band (apart from the arches' 4.5 cm straps), and nothing on
## the lane side of the wall line glows.
func _clear_play_space(skin: TerminalSkin, level_path: String) -> void:
	for lanes: int in [3, 6]:
		var layout: LevelLayout = level(level_path, lanes, 0.6, 5)
		var geo := TrackGeometry.new(lanes, tuning)
		var half: float = geo.half_width()
		var wall: float = geo.wall_x()
		var intruders: PackedStringArray = []
		var sticking: PackedStringArray = []
		var lit: PackedStringArray = []
		await visit_level(layout, skin, func(m: MeshInstance3D, arrays: Array, material: Material) -> void:
			if _under(m, func(n: Node) -> bool: return n is Area3D) or material == skin.drift_material():
				return
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var additive: bool = material == skin.glow_material()
			for i: int in verts.size():
				var p: Vector3 = m.global_transform * verts[i]
				var at_finish: bool = absf(-p.z - layout.length) < 1.0
				if not additive and absf(p.x) < half - 0.01 and p.y > 0.06 and p.y < tuning.ceiling_height - 0.1 and not at_finish and intruders.size() < 4:
					intruders.append(str(p))
				elif not additive and absf(p.x) >= half - 0.01 and absf(p.x) < wall - PROUD_MAX - 0.001 and p.y > 0.06 and p.y < WALL_RUN_BAND \
						and not at_finish and sticking.size() < 4:
					sticking.append(str(p))
				var glowing: bool = additive or (material == skin.solid_material() and colors[i].a > 0.0)
				if glowing and absf(p.x) < wall - 0.01 and p.y > 0.06 and p.y < WALL_RUN_BAND and not at_finish \
						and not _same_rgb(colors[i], skin.gap_edge_color) and lit.size() < 4:
					lit.append("%s %s" % [colors[i], p]))
		check(intruders.is_empty(), "nothing decorative stands in the play space (%d lanes): %s" % [lanes, ", ".join(intruders)])
		check(sticking.is_empty(), "nothing sticks out of the wall line through the wall-run band (%d lanes): %s" % [lanes, ", ".join(sticking)])
		check(lit.is_empty(), "nothing glows over the lanes in the wall-run band (%d lanes): %s" % [lanes, ", ".join(lit)])


## The ceilings: each of the three kinds turns up (by the hash of where a ceiling is), every one built for a single lane at 3, 5 and 6
## lanes in every lane (the shared suites sweep every range): a flat underside over exactly its lane, nothing below it, nothing
## but a walkway's rods rising past TOP_LIMIT over it.
func _ceilings(skin: TerminalSkin) -> void:
	var ceilings: TerminalCeilings = skin.ceilings()
	var counts: Dictionary = {}
	for i: int in 200:
		var size := Vector3(tuning.lane_width, TrackBuilder.HULL_THICKNESS, 24.0 + float(i % 5) * 4.0)
		var kind: int = ceilings.kind_of(Vector3(0.0, 6.4, -(100.0 + i * 7.3)), size)
		counts[kind] = int(counts.get(kind, 0)) + 1
	for kind: int in [TerminalCeilings.Kind.GIRDER, TerminalCeilings.Kind.WALKWAY, TerminalCeilings.Kind.CAR]:
		check(int(counts.get(kind, 0)) > 25, "ceilings of kind %d turn up (%s)" % [kind, counts])
	var problems: PackedStringArray = []
	for lanes: int in [3, 5, 6]:
		var geo := TrackGeometry.new(lanes, tuning)
		for lane: int in lanes:
			for kind: int in [TerminalCeilings.Kind.GIRDER, TerminalCeilings.Kind.WALKWAY, TerminalCeilings.Kind.CAR]:
				var size := Vector3(tuning.lane_width, TrackBuilder.HULL_THICKNESS, 32.0)
				var x: float = geo.lane_x(lane)
				var mesh: ArrayMesh = ceilings.mesh_for(kind, lane % 4, size, [] as Array[float], x, geo.wall_x(), tuning.ceiling_height)
				var half: float = tuning.lane_width * 0.5 + 0.01
				var tag: String = "%d lanes, lane %d, kind %d" % [lanes, lane, kind]
				var top: float = 0.0
				var below: float = 0.0
				var wide: float = 0.0
				for s: int in mesh.get_surface_count():
					for v: Vector3 in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
						below = minf(below, v.y)
						wide = maxf(wide, absf(v.x))
						if v.y > top:
							top = v.y
				var limit: float = TerminalCeilings.TOP_LIMIT + 0.01 if kind != TerminalCeilings.Kind.WALKWAY else 6.5
				if below < -0.06 or wide > half or top > limit:
					problems.append("%s: below %.3f, wide %.2f, top %.2f" % [tag, below, wide, top])
	check(problems.is_empty(), "every ceiling is one lane wide, flat underneath and low:\n  %s" % "\n  ".join(problems.slice(0, 6)))


## The doodads: every size class has looks of their own (a stack of cable drums or crates, a toppled kiosk or vending machine or a
## heap, fallen slabs or a long heap), none in a hazard's colour.
func _doodads(skin: TerminalSkin) -> void:
	var cards := DoodadCards.for_zone("terminal")
	check(cards.ok, "the Terminal has doodad cards (tools/godot.sh doodads --only=terminal)")
	var names: Dictionary = {}
	for size: StringName in LevelLayout.DOODAD_SIZES:
		var looks: Array = cards.designs.get(String(size), [])
		check(looks.size() >= 2, "the %s doodads have at least two looks (%d)" % [size, looks.size()])
		for d: Dictionary in looks:
			names[d["name"]] = true
			for hex: String in d["colors"]:
				var c := Color.html(hex)
				check(not (c.r > 0.55 and c.g < 0.45 and c.b < 0.35) and c.v < 0.8, "%s's colours are no hazard's (%s)" % [d["name"], hex])
	check(names.size() >= 6, "the Terminal's doodads have looks of their own (%s)" % [names.keys()])
	for look_seed: int in 12:
		var body := Node3D.new()
		skin.doodad(body, tuning.doodad_size(&"medium"), &"medium", 1, look_seed)
		check(not skin.doodad_debris_colors(body, &"medium", 1, look_seed).is_empty(), "a smashed doodad has pieces to fly off in (seed %d)" % look_seed)
		body.free()


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

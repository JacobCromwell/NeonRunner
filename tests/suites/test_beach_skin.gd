extends SkinSuite
## The Beach skin (BeachSkin, task D10; the owner's request of October 9, 2026; not in the campaign yet, so no
## zone uses it). The shared skin checks (SkinSuite) over Corporate 2, the richest level before a likely slot
## (the Beach has no levels yet), for 3, 5 and 6 lanes, then the Beach's own:
## - the look: an existing enemy look (no new enemy assets), a bright daytime sky that stays under the glow
##   threshold, a muted sea and island;
## - the colour rule (GDD §5; the reference's glowing turquoise water and its pink, yellow, cyan, green and
##   orange neon are overruled): nothing but hazards glows in a hazard hue, lit surfaces stay well below the
##   hazards' saturation, the water, the sand, the bamboo, the thatch, the steel and the paints never glow,
##   the decorative glows are warm white, violet and blue only;
## - gaps are pools and read as holes, at 3 and at 5 lanes: everything under the floor is the black steel of
##   the tank or the dark water, far darker than any floor, nothing in it glows but the orange edge, deeper than
##   a fall that ends a run; both edges of a pool carry the orange edge with a steel coping beside it;
## - the floor is flat and nothing stands on it; boardwalk runs line up across chunk cuts;
## - the play space stays clear, the wall-run band is flush and calm (nothing glows, sticks out, or carries a
##   sign, a screen or an emblem), and what the walls hang over the street stays above every ceiling's reach;
## - every kind of ceiling builds from the lanes it covers (a footbridge across every lane, a veranda deck over
##   fewer lanes reaching a wall, a barge anywhere), under TOP_LIMIT;
## - the cult's emblem hides on neon signs, billboards and the barge's hull, never smaller than emblem_min_size;
##   its feed plays only high up, on TVs behind some upper-deck bars and some roof billboards;
## - nothing vent-like is drawn, only hazard signs wear stripes, and the still floor carries motion cues.

const BEACH_SKIN_PATH: String = "res://data/skins/beach_skin.tres"
## The richest campaign level before a likely slot for the Beach (it has no levels of its own yet).
const BEACH_LEVEL_PATH: String = "res://data/levels/corporate_2.tres"
## Lit (non-glowing) surfaces stay below this chroma (brightest minus darkest channel); the fence pink is about 0.8.
const MAX_SURFACE_CHROMA: float = 0.5
## A glowing colour this saturated (HSV) must keep to the decorative hues (blue to violet).
const GLOW_SATURATION_LIMIT: float = 0.35
## Gaps: the brightest factors PAT_BEACH_TANK and PAT_BEACH_WATER give their colours (kit_beach.gdshaderinc:
## the steel's panels and rivets at most 1.25, its rust streaks never lighter than tank_rust_color; the water
## 1.12 of its colour, its glints never lighter than water_glint_color), and how much of the darkest large
## floor area's luminance (sand, boardwalk, kerb) a pool's inside may reach: 40%, a real margin, so the water
## reads as teal water yet a pool is still a hole at a glance.
const TANK_MAX_FACTOR: float = 1.25
const TANK_RUST_FACTOR: float = 1.0
const WATER_MAX_FACTOR: float = 1.12
const GAP_CONTRAST: float = 0.4
## The sand's darkest area (its drifts, damp patches and the wet rim round a pool), the boardwalk's, the
## kerb's and the plates': the darkest factors the patterns give their colours.
const SAND_DARKEST: float = 0.55
const BOARD_DARKEST: float = 0.7
const PLATE_DARKEST: float = 0.75
const KERB_DARKEST: float = 0.8
const JOINT_DARKEST: float = 0.9


func run() -> void:
	var skin := load(BEACH_SKIN_PATH) as BeachSkin
	check(skin != null, "the beach skin loads")
	if skin == null:
		return
	# No new enemy assets (the owner, October 9, 2026): the Beach's enemies wear an existing look.
	check(CyborgSuit.LOOKS.has(CyborgSuit.look_for(skin.enemy_variant)) and BeachSkin.new().enemy_variant == skin.enemy_variant,
		"the beach's enemies wear an existing look (%s)" % skin.enemy_variant)
	check(not ResourceLoader.exists("res://data/zones/beach.tres"), "the Beach is not a campaign zone yet")
	start_error_count()
	var env: Environment = skin.make_environment()
	check(env != null and env.sky != null and env.glow_enabled and env.fog_enabled, "the beach environment has a sky, glow and fog")
	_palette(skin)
	_sky(skin)
	for lanes: int in [3, 5, 6]:
		await whole_level(skin, "beach", BEACH_LEVEL_PATH, lanes)
	await hazards_and_triggers(skin)
	await _surfaces(skin)
	await _gaps(skin)
	_floor(skin)
	_boardwalk(skin)
	await _clear_play_space(skin)
	_calm_band(skin)
	_over_street(skin)
	_dressing(skin)
	_ceilings(skin)
	await _cult_emblem(skin)
	await _cult_feed(skin)
	await _signs(skin)
	await determinism(skin, BEACH_LEVEL_PATH)
	doodads_ok(skin, "beach")
	_doodads(skin)
	_shader(skin)
	stop_error_count("building beach levels")


## The skin's colours keep to the colour rule before anything is built.
func _palette(skin: BeachSkin) -> void:
	var glowing: Array[Color] = [skin.neon_violet, skin.neon_blue, skin.neon_white, skin.lamp_color, skin.ceiling_lamp_color,
		skin.engine_color, skin.emblem_color()]
	var bad: PackedStringArray = []
	for c: Color in glowing:
		if _hazard_hue(c):
			bad.append(str(c))
	check(bad.is_empty(), "the decorative glows are warm white, violet and blue only (no pink, yellow, cyan, green or orange): %s" % ", ".join(bad))
	var lit: Array[Color] = [skin.sand_color, skin.sand_light_color, skin.sand_dark_color, skin.shell_color, skin.pebble_color,
		skin.boardwalk_color, skin.plank_gap_color, skin.plate_color, skin.rust_color, skin.kerb_color, skin.gap_inside_color,
		skin.tank_rust_color, skin.tide_color, skin.water_color, skin.coping_color, skin.bamboo_dark_color, skin.thatch_color,
		skin.thatch_dark_color, skin.timber_color, skin.cream_color, skin.steel_color, skin.steel_rust_color, skin.trunk_color,
		skin.wall_mark_color, skin.plank_color, skin.hull_color, skin.drum_color, skin.post_color, skin.trigger_metal_color,
		skin.seam_color]
	for list: PackedColorArray in [skin.bamboo_colors, skin.paint_colors, skin.lantern_shell_colors, skin.flag_colors,
			skin.frond_colors, skin.sign_content_colors]:
		lit.append_array(Array(list))
	var loud: PackedStringArray = []
	for c: Color in lit:
		if _chroma(c) > MAX_SURFACE_CHROMA:
			loud.append(str(c))
	check(loud.is_empty(), "the beach's paints are muted: lit colours stay well below the hazards' saturation: %s" % ", ".join(loud))
	check(_chroma(skin.fence_color) > MAX_SURFACE_CHROMA + 0.3, "the fence pink is far more saturated than any surface")
	# The water is deep and unlit: never within reach of the anti-grav pads' glowing cyan.
	check(skin.water_color.v < 0.2 and skin.gap_inside_color.v < 0.2 and skin.tide_color.v < 0.2,
		"the pool's water and tank are dark, never the pads' glowing cyan: %s, %s" % [skin.water_color, skin.gap_inside_color])
	# The palms are muted greens, far from the ramps' and speed pads' hazard green.
	var greens: PackedStringArray = []
	for c: Color in skin.frond_colors:
		if c.s > 0.5 or c.v > 0.5 or _near_colour(c, skin.ramp_color) or _near_colour(c, skin.speed_pad_color):
			greens.append(str(c))
	check(greens.is_empty(), "the palms are muted greens, far from the ramps' green: %s" % ", ".join(greens))
	# The sand is mid-bright rather than white: a pool beside it must read against it.
	var sand: float = _linear_luminance(skin.sand_color)
	check(sand > 0.15 and sand < 0.5, "the sand is mid-bright, not white (%.3f)" % sand)
	# The gap edge's orange stays orange, the sign frame yellow, the hazards as everywhere.
	check(skin.gap_edge_color == Color(1.0, 0.25, 0.04) and skin.sign_frame_color == Color(1.0, 0.8, 0.15)
		and skin.fence_color == Color(1.0, 0.18, 0.62), "the hazards keep their colours")
	var like_edge: PackedStringArray = []
	for c: Color in [skin.sand_color, skin.sand_light_color, skin.boardwalk_color, skin.plate_color, skin.rust_color, skin.kerb_color,
			skin.plank_color, skin.thatch_color] + Array(skin.bamboo_colors) + Array(skin.paint_colors):
		if _near_colour(c, skin.gap_edge_color) or _near_colour(c, skin.sign_frame_color):
			like_edge.append(str(c))
	check(like_edge.is_empty(), "no floor, wall or paint is drawn in a gap edge's or a sign frame's colour: %s" % ", ".join(like_edge))


## The sky: bright daytime, with an island and a sea; its brightest (the horizon's colour with the haze and the
## sun's glow on it just above the far skyline's lowest tops, and the clouds' lit undersides) stays under the
## environment's glow threshold, so it never blooms (only hazards glow in hazard colours), and every
## uniform it sets is one of the sky shader's.
func _sky(skin: BeachSkin) -> void:
	var env: Environment = skin.make_environment()
	var m := env.sky.sky_material as ShaderMaterial
	check(m != null and m.shader == MeshKit.shader("night_sky.gdshader"), "the beach uses the night sky shader")
	if m == null:
		return
	var names: Array[String] = []
	for u: Dictionary in m.shader.get_shader_uniform_list():
		names.append(String(u["name"]))
	for uniform: String in ["zenith_color", "horizon_color", "haze_color", "abyss_color", "skyline_color", "skyline_hills", "skyline_scale", "abyss_depth",
			"sun_glow_strength", "cloud_amount", "cloud_color", "cloud_lit_color"]:
		check(names.has(uniform) and m.get_shader_parameter(uniform) != null, "the sky sets %s" % uniform)
	check(float(m.get_shader_parameter("skyline_hills")) > 0.5 and float(m.get_shader_parameter("moon_radius")) == 0.0
		and float(m.get_shader_parameter("star_amount")) == 0.0 and float(m.get_shader_parameter("cloud_amount")) > 0.2,
		"a daytime sky: rolling hills on the horizon, clouds, no moon and no stars")
	var el: float = 0.02
	var horizon: Color = _linear(m, "horizon_color") + _linear(m, "haze_color") * (float(m.get_shader_parameter("haze_strength"))
		* exp(-el / float(m.get_shader_parameter("haze_height")))) + _linear(m, "sun_glow_color") \
		* (float(m.get_shader_parameter("sun_glow_strength")) * exp(-el / float(m.get_shader_parameter("sun_glow_height"))))
	var brightest: float = maxf(horizon.r, maxf(horizon.g, horizon.b))
	var cloud: Color = _linear(m, "cloud_lit_color")
	var sea: Color = _linear(m, "abyss_color")
	check(brightest < env.glow_hdr_threshold and maxf(cloud.r, maxf(cloud.g, cloud.b)) < env.glow_hdr_threshold
		and maxf(sea.r, maxf(sea.g, sea.b)) < env.glow_hdr_threshold,
		"the sky never blooms: its brightest %.2f, its clouds %.2f, under the glow threshold %.2f" % [brightest,
			maxf(cloud.r, maxf(cloud.g, cloud.b)), env.glow_hdr_threshold])
	# The sky is blue, the sea a muted turquoise: the zenith and the abyss are not pink, yellow or orange.
	var zenith: Color = skin.sky_zenith_color
	check(zenith.b > zenith.r and zenith.b > zenith.g and skin.abyss_color.g > skin.abyss_color.r and skin.abyss_color.b > skin.abyss_color.r,
		"a blue sky over a turquoise sea")


func _linear(m: ShaderMaterial, uniform: String) -> Color:
	var v: Vector3 = m.get_shader_parameter(uniform)
	return Color(v.x, v.y, v.z).srgb_to_linear()


## Over a whole level (Corporate 2, 5 lanes, chunk by chunk): glowing surfaces keep off the hazard hues (the
## orange edges aside); lit ones stay desaturated; the water, sand, boardwalk, walls, thatch, steel, paints and
## timber never glow (only the neon silhouettes do, in violet, blue or warm white); no surface uses the grille
## (vent) pattern; only hazard signs wear the striped frame; the drifting particles are there.
func _surfaces(skin: BeachSkin) -> void:
	var found := {"grilles": 0, "stripes": 0, "drift": 0, "neon": 0, "hazard_hues": [], "loud": [], "glowing": [], "on_hazards": 0,
		"bad_neon": []}
	var solid: Material = skin.solid_material()
	var glow: Material = skin.glow_material()
	var edge: Color = skin.gap_edge_color
	var never_glow: Array[int] = [MeshKit.PAT_BEACH_SAND, MeshKit.PAT_BEACH_BOARDWALK, MeshKit.PAT_BEACH_TANK, MeshKit.PAT_BEACH_WATER,
		MeshKit.PAT_BEACH_WALL, MeshKit.PAT_BEACH_THATCH, MeshKit.PAT_BEACH_STEEL, MeshKit.PAT_BEACH_PAINT, MeshKit.PAT_BEACH_TIMBER]
	var tubes: Array[Color] = [skin.neon_violet, skin.neon_blue, skin.neon_white]
	var visit := func(m: MeshInstance3D, arrays: Array, material: Material) -> void:
		if material == skin.drift_material():
			found["drift"] += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			return
		if material != solid and material != glow:
			return
		var in_hazard: bool = under_hazard(m)
		var in_trigger: bool = _under(m, func(n: Node) -> bool: return n is Area3D and n.has_meta(&"kind"))
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2] if arrays[Mesh.ARRAY_TEX_UV2] != null else PackedVector2Array()
		for i: int in verts.size():
			var c: Color = colors[i]
			if material == solid:
				var pattern: int = roundi(uv2[i].x)
				if pattern == MeshKit.PAT_GRILLE:
					found["grilles"] += 1
				if pattern == MeshKit.PAT_STRIPES and not in_hazard:
					found["stripes"] += 1
				if pattern == MeshKit.PAT_BEACH_NEON:
					found["neon"] += 1
					var tube: bool = false
					for t: Color in tubes:
						tube = tube or _same_rgb(c, t)
					if not tube and found["bad_neon"].size() < 4:
						found["bad_neon"].append(str(c))
				if c.a > 0.0 and not in_hazard and not in_trigger and never_glow.has(pattern) and found["glowing"].size() < 4:
					found["glowing"].append("%s pattern %d at %s" % [c, pattern, m.global_transform * verts[i]])
				if c.a == 0.0 and not in_hazard and not in_trigger and _chroma(c) > MAX_SURFACE_CHROMA and found["loud"].size() < 4:
					found["loud"].append("%s at %s" % [c, m.global_transform * verts[i]])
			var glowing: bool = material == glow or c.a > 0.0
			if glowing and not in_hazard and not in_trigger and _hazard_hue(c) and not _same_rgb(c, edge) \
					and found["hazard_hues"].size() < 4:
				found["hazard_hues"].append("%s at %s" % [c, m.global_transform * verts[i]])
	await visit_level(level(BEACH_LEVEL_PATH, 5, 0.6, 4), skin, visit)
	check(found["grilles"] == 0, "nothing vent-like: no surface uses the grille pattern (%d vertices)" % found["grilles"])
	check(found["stripes"] == 0, "only hazard signs wear the striped frame (%d striped vertices elsewhere)" % found["stripes"])
	check(found["hazard_hues"].is_empty(), "nothing but hazards (and the orange edges) glows in a hazard hue: %s" % ", ".join(
		found["hazard_hues"]))
	check(found["loud"].is_empty(), "lit surfaces stay desaturated: %s" % ", ".join(found["loud"]))
	check(found["glowing"].is_empty(), "the water, sand, boardwalk, walls, thatch, steel, paints and timber never glow (GDD §5): %s" % ", ".join(
		found["glowing"]))
	check(found["neon"] > 0 and found["bad_neon"].is_empty(), "the neon silhouettes glow in violet, blue or warm white only (%d vertices): %s" % [
		found["neon"], ", ".join(found["bad_neon"])])
	check(found["drift"] > 0, "the beach carries drifting sand, leaves and speed streaks (%d vertices)" % found["drift"])


## Gaps are pools and read as holes at a glance, as in every zone (CLAUDE.md readability rules): whatever a pool
## shows is the black steel of its tank or dark water, far darker than any floor can be drawn, and nothing in
## it glows but the orange edge; the water lies a fall that ends a run sinks into; no floor is drawn in the
## edge's colour; the showcase pool carries the full orange edge on both sides (the lip on the floor right at
## the collision edge with a steel coping beside it, the strip along the top of the tank's wall, and on the far
## side the halo). Checked over whole levels at 3 and 5 lanes.
func _gaps(skin: BeachSkin) -> void:
	# The darkest large floor areas: the sand's drifts, the planks and the kerb (the bolted plates are a few small
	# patches, the joints thin lines: the inside must stay under those too).
	var areas: Array[float] = [_linear_luminance(skin.sand_color * Color(SAND_DARKEST, SAND_DARKEST, SAND_DARKEST)),
		_linear_luminance(skin.boardwalk_color * Color(BOARD_DARKEST, BOARD_DARKEST, BOARD_DARKEST)),
		_linear_luminance(skin.kerb_color * Color(KERB_DARKEST, KERB_DARKEST, KERB_DARKEST))]
	var darkest: float = INF
	for l: float in areas:
		darkest = minf(darkest, l)
	var plates: float = _linear_luminance(skin.plate_color * Color(PLATE_DARKEST, PLATE_DARKEST, PLATE_DARKEST))
	var joints: float = _linear_luminance(skin.plank_gap_color * Color(JOINT_DARKEST, JOINT_DARKEST, JOINT_DARKEST))
	var inside: float = _inside_luminance(skin)
	check(inside <= darkest * GAP_CONTRAST and inside < joints and inside < plates,
		"a pool's inside stays darker than the darkest floor by a real margin: %.4f vs %.4f x %.2f (plates %.4f, joints %.4f)" % [
		inside, darkest, GAP_CONTRAST, plates, joints])
	# The water is filled to near the rim (like the reference's tanks) and a fall that ends a run sinks into it;
	# the chase camera stays above the floor, so above the water, even at that depth.
	check(skin.pool_depth >= 0.4 and skin.pool_depth <= 1.2 and skin.pool_depth < tuning.fall_death_depth,
		"the water lies 0.4-1.2 m under the rim, and a fall that ends a run sinks into it: %.2f m vs %.1f m" % [skin.pool_depth,
		tuning.fall_death_depth])
	var camera_low: float = tuning.camera_height - tuning.fall_death_depth * tuning.camera_follow_y
	check(camera_low > 1.0, "the chase camera at the fall's depth is still above the floor and the water (%.2f m)" % camera_low)
	# It reads as water, not as black steel: a saturated deep teal, far from the steel's grey and the pads' cyan glow.
	check(skin.water_color.s > 0.6 and skin.water_color.h > 0.45 and skin.water_color.h < 0.56 and skin.gap_inside_color.s < 0.25
		and skin.water_glint_color.s > 0.6 and skin.water_glint_color.h > 0.45 and skin.water_glint_color.h < 0.56,
		"the water is a deep teal (%s, glints %s), the tank's steel grey (%s)" % [skin.water_color, skin.water_glint_color, skin.gap_inside_color])
	var like_edge: PackedStringArray = []
	for c: Color in [skin.sand_color, skin.sand_light_color, skin.boardwalk_color, skin.plate_color, skin.rust_color, skin.kerb_color,
			skin.coping_color]:
		if _near_colour(c, skin.gap_edge_color):
			like_edge.append(str(c))
	check(like_edge.is_empty(), "no floor is drawn in the gap edge's colour: %s" % ", ".join(like_edge))
	# The showcase pool (lane 3, 50-57 m): the orange edge on both sides, the coping beside it, the halo on the far one.
	var track: TrackBuilder = showcase_track(skin)
	var strip := Vector2(INF, -INF)
	var lip := Vector2(INF, -INF)
	var near_lip := Vector2(INF, -INF)
	var halo: bool = false
	var coping: Vector2 = Vector2(INF, -INF)
	var near_coping: Vector2 = Vector2(INF, -INF)
	var water: bool = false
	for node: Node in nodes_of(track, func(n: Node) -> bool: return n is MeshInstance3D):
		var m := node as MeshInstance3D
		for s: int in m.mesh.get_surface_count() if m.mesh != null else 0:
			var material: Material = m.mesh.surface_get_material(s)
			if material != skin.solid_material() and material != skin.glow_material():
				continue
			var arrays: Array = m.mesh.surface_get_arrays(s)
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
			for i: int in verts.size():
				var p: Vector3 = m.global_transform * verts[i]
				if material == skin.solid_material() and roundi(uv2[i].x) == MeshKit.PAT_BEACH_WATER and absf(p.y + skin.pool_depth) < 0.001:
					water = true
				if p.x < 1.0 or p.x > 3.8:
					continue
				if _same_rgb(colors[i], skin.coping_color) and absf(p.y) < 0.001 and colors[i].a == 0.0 and roundi(uv2[i].x) == MeshKit.PAT_PLAIN:
					if -p.z > 57.0 - 0.001 and -p.z < 57.0 + BeachSand.COPING + 0.4 + BeachSand.EDGE_LIP:
						coping = Vector2(minf(coping.x, -p.z), maxf(coping.y, -p.z))
					elif -p.z < 50.0 + 0.001 and -p.z > 50.0 - BeachSand.COPING - BeachSand.EDGE_LIP - 0.4:
						near_coping = Vector2(minf(near_coping.x, -p.z), maxf(near_coping.y, -p.z))
				if not _same_rgb(colors[i], skin.gap_edge_color):
					continue
				if material == skin.glow_material():
					halo = halo or absf(-p.z - 57.0) < 0.1
				elif absf(-p.z - 57.0) <= 0.3:
					if p.y < -0.001 and colors[i].a >= BeachSand.STRIP_GLOW - 0.001:
						strip = Vector2(minf(strip.x, p.y), maxf(strip.y, p.y))
					elif absf(p.y) < 0.001 and colors[i].a >= BeachSand.LIP_GLOW - 0.001:
						lip = Vector2(minf(lip.x, -p.z), maxf(lip.y, -p.z))
				elif absf(-p.z - 50.0) <= 0.3 and absf(p.y) < 0.001 and colors[i].a >= BeachSand.LIP_GLOW - 0.001:
					near_lip = Vector2(minf(near_lip.x, -p.z), maxf(near_lip.y, -p.z))
	check(strip.y - strip.x >= BeachSand.STRIP_HEIGHT - 0.001 and strip.y > -0.05,
		"the far edge's orange strip runs along the top of the tank's wall: %s" % strip)
	check(lip.x > 56.99 and lip.y - lip.x >= BeachSand.EDGE_LIP - 0.001,
		"the far edge's orange lip lies on the floor right at the collision edge: %s" % lip)
	check(near_lip.y < 50.01 and near_lip.y - near_lip.x >= BeachSand.EDGE_LIP - 0.001,
		"the near edge's orange lip ends right at the collision edge: %s" % near_lip)
	check(halo, "the far edge carries its orange halo toward the approaching runner")
	check(coping.y - coping.x >= BeachSand.COPING - 0.001 and near_coping.y - near_coping.x >= BeachSand.COPING - 0.001,
		"a steel coping lies just outside each orange lip (%s, %s)" % [coping, near_coping])
	check(water, "the pool's water lies pool_depth (%.2f m) below the floor" % skin.pool_depth)
	await free_track(track)
	# Whole levels, chunk by chunk: below the floor only the tank's steel, the water, the strips and the halo.
	var shade: float = inside + 0.0001
	for lanes: int in [3, 5]:
		var layout: LevelLayout = level(BEACH_LEVEL_PATH, lanes, 0.6, 9)
		var world := Node3D.new()
		tree.root.add_child(world)
		var built := TrackBuilder.new()
		world.add_child(built)
		built.set_layout(layout, tuning, skin)
		var bad: PackedStringArray = []
		var seen: Dictionary = {}
		var under: int = 0
		var d: float = 0.0
		while d <= layout.length + TrackBuilder.RUN_OUT + TrackBuilder.CHUNK_LENGTH:
			built.update(d, d / tuning.run_speed)
			for chunk: Node in built.get_children():
				if not seen.has(chunk):
					seen[chunk] = true
					under += _check_below_floor(chunk, skin, layout.length, shade, bad)
			d += TrackBuilder.CHUNK_LENGTH
		check(bad.is_empty() and under > 0, "below the floor there is only the tank's black steel, dark water and the orange edge " +
			"(%d lanes, %d vertices): %s" % [lanes, under, ", ".join(bad)])
		world.queue_free()
		await tree.process_frame


## The brightest a pool's inside can be drawn (linear luminance): the tank's steel and rivets, its rust
## streaks, the water with its glints, and the tide mark at the water's level.
func _inside_luminance(skin: BeachSkin) -> float:
	var f: float = TANK_MAX_FACTOR
	var r: float = TANK_RUST_FACTOR
	var w: float = WATER_MAX_FACTOR
	return maxf(maxf(_linear_luminance(skin.gap_inside_color * Color(f, f, f)), _linear_luminance(skin.tank_rust_color * Color(r, r, r))),
		maxf(maxf(_linear_luminance(skin.water_color * Color(w, w, w)), _linear_luminance(skin.water_glint_color)),
			_linear_luminance(skin.tide_color)))


## Checks every vertex of the skin's meshes in `chunk` below the floor (hazards and triggers aside, and the
## finish gantry's posts at `finish`): the tank's steel, the water, an orange strip, the halo. Returns how many
## there were; problems (up to four) go to `bad`.
func _check_below_floor(chunk: Node, skin: BeachSkin, finish: float, shade: float, bad: PackedStringArray) -> int:
	var count: int = 0
	for node: Node in nodes_of(chunk, func(n: Node) -> bool: return n is MeshInstance3D):
		var m := node as MeshInstance3D
		if m.mesh == null or m.is_in_group(&"debug_hitbox") or under_hazard(m) \
				or _under(m, func(n: Node) -> bool: return n is Area3D):
			continue
		for s: int in m.mesh.get_surface_count():
			var material: Material = m.mesh.surface_get_material(s)
			var arrays: Array = m.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2] if arrays[Mesh.ARRAY_TEX_UV2] != null else PackedVector2Array()
			for i: int in verts.size():
				var p: Vector3 = m.global_transform * verts[i]
				if p.y >= -0.01 or absf(-p.z - finish) < 1.0:
					continue
				count += 1
				var c: Color = colors[i]
				var what: String = ""
				if material == skin.solid_material():
					var pattern: int = roundi(uv2[i].x)
					var strip: bool = _same_rgb(c, skin.gap_edge_color) and c.a >= BeachSand.STRIP_GLOW - 0.001
					var dark: bool = (pattern == MeshKit.PAT_BEACH_TANK and _same_rgb(c, skin.gap_inside_color) or pattern == MeshKit.PAT_BEACH_WATER
						and _same_rgb(c, skin.water_color)) and c.a == 0.0 and _linear_luminance(c) <= shade
					if not strip and not dark:
						what = "%s pattern %d" % [c, pattern]
				elif material == skin.glow_material():
					if not _same_rgb(c, skin.gap_edge_color):
						what = "glow %s" % c
				elif material != skin.drift_material():
					what = "material %s" % material.resource_path.get_file() if material != null else "no material"
				if what != "" and bad.size() < 4:
					bad.append("%s at %s" % [what, p])
	return count


## A floor segment is flat at y = 0 with nothing standing on it (nothing rises above 1 cm: no prism, nothing
## round), and under it only the tank; it draws no vent.
func _floor(skin: BeachSkin) -> void:
	var parent := Node3D.new()
	var bad: PackedStringArray = []
	var parts: int = 0
	for lane_x: float in [-4.8, 0.0, 2.4]:
		for pools: int in 2:
			for z: float in [-20.0, -52.0, -140.0]:
				skin.floor_segment(parent, Vector3(lane_x, -0.25, z), Vector3(2.4, 0.5, 30.0), lane_x, pools == 1, pools == 1)
	for node: Node in nodes_of(parent, func(n: Node) -> bool: return n is MeshInstance3D):
		var m := node as MeshInstance3D
		for s: int in m.mesh.get_surface_count():
			# The halo along a pool's far edge is an additive card, not an object.
			if m.mesh.surface_get_material(s) == skin.glow_material():
				continue
			var arrays: Array = m.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
			for i: int in verts.size():
				parts += 1
				var p: Vector3 = verts[i]
				if p.y > 0.0101 and bad.size() < 4:
					bad.append("%s rises %.3f m" % [p, p.y])
				if roundi(uv2[i].x) == MeshKit.PAT_GRILLE and bad.size() < 4:
					bad.append("a grille at %s" % p)
	check(parts > 0 and bad.is_empty(), "the beach's floor is flat and nothing stands on it (%d vertices): %s" % [parts, ", ".join(bad)])
	parent.free()


## Boardwalk runs (hashed by lane and slot) line up across chunk cuts, are a fair share of a lane over a long
## street and differ from lane to lane.
func _boardwalk(skin: BeachSkin) -> void:
	var sand: BeachSand = skin.sand()
	var same: bool = true
	var shares: Array[float] = []
	var distinct: Dictionary = {}
	for lane_x: float in [-4.8, -2.4, 0.0, 2.4, 4.8]:
		var lane: int = MeshKit.key(lane_x)
		var whole: Array[Vector3] = sand.boardwalk_runs(lane, 0.0, 3000.0)
		var total: float = 0.0
		for r: Vector3 in whole:
			total += r.y - r.x
		shares.append(total / 3000.0)
		distinct[var_to_str(whole.slice(0, 6))] = true
		# The same runs from the chunks' windows, merged where they meet.
		var merged: Array[Vector2] = []
		var d: float = 0.0
		while d < 3000.0:
			for r: Vector3 in sand.boardwalk_runs(lane, d, d + 40.0):
				if not merged.is_empty() and absf(merged[-1].y - r.x) < 0.001:
					merged[-1].y = r.y
				else:
					merged.append(Vector2(r.x, r.y))
			d += 40.0
		same = same and merged.size() == whole.size()
		for i: int in mini(merged.size(), whole.size()):
			same = same and absf(merged[i].x - whole[i].x) < 0.001 and absf(merged[i].y - whole[i].y) < 0.001
	var low: float = INF
	var high: float = 0.0
	for share: float in shares:
		low = minf(low, share)
		high = maxf(high, share)
	check(same, "boardwalk runs line up across chunk cuts")
	check(low > 0.08 and high < 0.6 and distinct.size() >= 3, "boardwalk covers %.0f-%.0f%% of a lane over 3 km, differently in each lane (%d patterns)" % [
		low * 100.0, high * 100.0, distinct.size()])
	var off := skin.duplicate() as BeachSkin
	off.boardwalk_share = 0.0
	check(off.sand().boardwalk_runs(MeshKit.key(0.0), 0.0, 500.0).is_empty(), "with boardwalk_share at 0 the beach is all sand")


## Between the floor and the ceiling, over the lanes, the skin builds nothing solid but hazards and triggers,
## anywhere in a whole level; and nothing sticks out of the walls through the wall-run band.
func _clear_play_space(skin: BeachSkin) -> void:
	for lanes: int in [3, 6]:
		var layout: LevelLayout = level(BEACH_LEVEL_PATH, lanes, 0.6, 5)
		var world := Node3D.new()
		tree.root.add_child(world)
		var track := TrackBuilder.new()
		world.add_child(track)
		track.set_layout(layout, tuning, skin)
		var geo := TrackGeometry.new(lanes, tuning)
		var intruders: PackedStringArray = []
		var sticking: PackedStringArray = []
		var seen: Dictionary = {}
		var d: float = 0.0
		while d <= layout.length + TrackBuilder.RUN_OUT + TrackBuilder.CHUNK_LENGTH:
			track.update(d, d / tuning.run_speed)
			for chunk: Node in track.get_children():
				if not seen.has(chunk):
					seen[chunk] = true
					_find_intruders(chunk, skin, geo, layout.length, intruders, sticking)
			d += TrackBuilder.CHUNK_LENGTH
		check(intruders.is_empty(), "nothing decorative stands in the play space (%d lanes, %d chunks): %s" % [lanes,
			seen.size(), ", ".join(intruders)])
		check(sticking.is_empty(), "nothing sticks out of the walls through the wall-run band (%d lanes): %s" % [lanes,
			", ".join(sticking)])
		world.queue_free()
		await tree.process_frame


## Solid vertices of the skin's meshes in `chunk` over the lanes between the floor and the ceiling (up to
## four, appended to `out`), and those sticking out of a wall face by more than 5 cm below the calm band's top
## (decor_min_height - 1 m, and below the ceilings), up to four in `sticking`; the finish gantry's posts (at
## `finish`, shared by every zone) don't count.
func _find_intruders(chunk: Node, skin: BeachSkin, geo: TrackGeometry, finish: float, out: PackedStringArray,
		sticking: PackedStringArray) -> void:
	var half: float = geo.half_width()
	var wall: float = geo.wall_x()
	var band_top: float = minf(skin.decor_min_height - 1.0, tuning.ceiling_height - 0.1)
	for node: Node in nodes_of(chunk, func(n: Node) -> bool: return n is MeshInstance3D):
		var m := node as MeshInstance3D
		if m.mesh == null or m.is_in_group(&"debug_hitbox") or _under(m, func(n: Node) -> bool: return n is Area3D):
			continue
		for s: int in m.mesh.get_surface_count():
			# Drifting sand and additive light (lamp halos, engine glow) aren't objects.
			var material: Material = m.mesh.surface_get_material(s)
			if material == skin.drift_material() or material == skin.glow_material():
				continue
			var verts: PackedVector3Array = m.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			for v: Vector3 in verts:
				var p: Vector3 = m.global_transform * v
				if absf(p.x) < half - 0.01 and p.y > 0.06 and p.y < tuning.ceiling_height - 0.1 and not under_hazard(m) \
						and out.size() < 4:
					out.append(str(p))
				elif absf(p.x) >= half - 0.01 and absf(p.x) < wall - 0.05 and p.y > 0.06 and p.y < band_top \
						and absf(-p.z - finish) > 1.0 and not under_hazard(m) and sticking.size() < 4:
					sticking.append(str(p))


## The wall-run band is flush and calm (GDD §5, the same rule as every zone): over 3 km of both walls at 3, 5
## and 6 lanes, nothing the shacks build below decor_min_height glows, plays the feed, carries a neon sign or the
## emblem, or stands out of the face by more than 5 cm.
func _calm_band(skin: BeachSkin) -> void:
	var glow_low: PackedStringArray = []
	var proud: PackedStringArray = []
	var checked: int = 0
	for lanes: int in [3, 5, 6]:
		var wall: float = TrackGeometry.new(lanes, tuning).wall_x()
		for side: int in [-1, 1]:
			var batch := MeshBatch.new()
			skin.shacks().build(batch, side, side * wall, 0.0, 3000.0)
			for material: Material in [skin.solid_material(), skin.glow_material(), skin.feed_material()]:
				var layer: MeshLayer = batch.layer(material)
				for i: int in layer.size():
					var p: Vector3 = layer.verts[i]
					if p.y >= skin.decor_min_height - 0.001:
						continue
					checked += 1
					var pattern: int = roundi(layer.uv2s[i].x)
					if (material != skin.solid_material() or layer.colors[i].a > 0.0 or pattern == MeshKit.PAT_BEACH_NEON
							or pattern == MeshKit.PAT_CULT_MARK) and glow_low.size() < 4:
						glow_low.append("%s pattern %d glow %.2f at %s" % [material.resource_path.get_file(), pattern, layer.colors[i].a, p])
					if wall - absf(p.x) > 0.05 and p.y < skin.decor_min_height and proud.size() < 4:
						proud.append(str(p))
	check(checked > 5000 and glow_low.is_empty(), "nothing glows or shows a screen, a neon sign or the emblem below %.0f m (%d vertices): %s" % [
		skin.decor_min_height, checked, ", ".join(glow_low)])
	check(proud.is_empty(), "the band's faces are flush with the wall (nothing out of it): %s" % ", ".join(proud))


## What the walls hang out over the street (further than LIP from the face) stays at OVER_STREET_MIN or higher,
## above everything a ceiling builds (BeachCeilings.TOP_LIMIT over the ceiling's underside): over 3 km of both
## walls and the strings of lights across the street, at 3 and 6 lanes.
func _over_street(skin: BeachSkin) -> void:
	var low: PackedStringArray = []
	var over: int = 0
	var strings: int = 0
	var lowest: float = INF
	for lanes: int in [3, 6]:
		var wall: float = TrackGeometry.new(lanes, tuning).wall_x()
		for side: int in [-1, 1]:
			var batch := MeshBatch.new()
			skin.shacks().build(batch, side, side * wall, 0.0, 3000.0)
			if side < 0:
				skin.shacks().overhead(batch, wall, 0.0, 3000.0)
			for material: Material in [skin.solid_material(), skin.feed_material(), skin.glow_material()]:
				var layer: MeshLayer = batch.layer(material)
				for p: Vector3 in layer.verts:
					var out: float = wall - absf(p.x)
					if out <= BeachShacks.LIP + 0.001:
						continue
					over += 1
					lowest = minf(lowest, p.y)
					if p.y < BeachShacks.OVER_STREET_MIN - 0.001 and low.size() < 4:
						low.append("%.2f m up, %.2f m out (%d lanes)" % [p.y, out, lanes])
		for k: int in 70:
			strings += 0 if skin.shacks().string_spec(k).is_empty() else 1
	check(over > 1000 and low.is_empty(), "the walls hang nothing out over the street below %.0f m (%d points, lowest %.2f m): %s" % [
		BeachShacks.OVER_STREET_MIN, over, lowest, ", ".join(low)])
	check(strings > 20, "strings of lights cross the street (%d slots of %.0f m)" % [strings, skin.string_spacing])
	check(tuning.ceiling_height + BeachCeilings.TOP_LIMIT < BeachShacks.OVER_STREET_MIN,
		"no ceiling reaches the walls' overhangs: %.1f m over its underside at %.1f m, under %.1f m" % [BeachCeilings.TOP_LIMIT,
			tuning.ceiling_height, BeachShacks.OVER_STREET_MIN])


## The reference's colour at street level and above, within the colour rule: seven bamboo tones that tell
## neighbouring shacks apart; the wall-run height marks a thin line of a slightly darker shade (a multiplier near 0.7,
## never a dark cable); paints that include turquoise, coral and sea blue; clusters of paper lanterns hung on the
## faces above decor_min_height, within LIP of the face, unlit muted shells with the warm-white glow inside; and
## striped awnings (muted paint and cream, unlit) across the top of the verandas' openings.
func _dressing(skin: BeachSkin) -> void:
	var tones: PackedColorArray = skin.bamboo_colors
	var apart: bool = tones.size() >= 7
	for i: int in tones.size():
		for j: int in range(i + 1, tones.size()):
			var d: Color = tones[i] - tones[j]
			if sqrt(d.r * d.r + d.g * d.g + d.b * d.b) < 0.05:
				apart = false
	check(apart, "the shacks' bamboo comes in seven or more tones that differ from each other (%d)" % tones.size())
	var m: Color = skin.wall_mark_color
	check(skin.wall_height_marks.size() == 2 and minf(m.r, minf(m.g, m.b)) >= 0.6 and maxf(m.r, maxf(m.g, m.b)) <= 0.85 and _chroma(m) < 0.1,
		"the wall-run marks are a slightly darker shade of the wall, not a dark line: x%s" % m)
	var named: Array[String] = ["turquoise", "coral", "sea blue"]
	var wanted: Array[Color] = [Color(0.22, 0.54, 0.56), Color(0.76, 0.42, 0.34), Color(0.28, 0.42, 0.62)]
	for k: int in wanted.size():
		var found: bool = false
		for c: Color in skin.paint_colors:
			var d: Color = c - wanted[k]
			found = found or sqrt(d.r * d.r + d.g * d.g + d.b * d.b) < 0.12
		check(found, "the paints include a muted %s" % named[k])
	# Lantern clusters on the faces, all above decor_min_height and below the roofline.
	var sh: BeachShacks = skin.shacks()
	var clusters: int = 0
	var bad: PackedStringArray = []
	for side: int in [-1, 1]:
		var lot: float = skin.lot_length
		var span: Vector2i = sh.lot_run(side, 0)
		while span.x * lot < 3000.0:
			var b: BeachShacks.Shack = sh.shack(side, span)
			for item: Dictionary in b.items:
				if StringName(item["kind"]) == &"lanterns":
					clusters += 1
					if float(item["y"]) - 2.8 < skin.decor_min_height - 0.001 or float(item["y"]) > b.height - 0.5:
						bad.append("%.1f m up on a %.1f m shack" % [float(item["y"]), b.height])
			span = sh.lot_run(side, span.y + 1)
	check(clusters > 20 and bad.is_empty(), "paper lanterns hang in clusters on the faces above %.0f m (%d clusters): %s" % [
		skin.decor_min_height, clusters, ", ".join(bad.slice(0, 4))])
	var faults: PackedStringArray = []
	var glows: int = 0
	for variant: int in 4:
		var t: MeshLayer = sh.lanterns_template(variant)
		for i: int in t.size():
			var p: Vector3 = t.verts[i]
			var c: Color = t.colors[i]
			if p.y < -2.8 or p.x > BeachShacks.LIP:
				faults.append("%s in variant %d" % [p, variant])
			if c.a > 0.001:
				glows += 1
				if not _same_rgb(c, skin.lamp_color):
					faults.append("a glow %s" % c)
			elif _hazard_hue_lit(c):
				faults.append("a shell %s" % c)
	check(faults.is_empty() and glows > 0, "each lantern cluster stays within %.2f m of the face, glows warm white inside unlit shells: %s" % [
		BeachShacks.LIP, ", ".join(faults.slice(0, 4))])
	# The striped awning on the verandas: a muted paint strip and a cream one, flush, unlit.
	var strips: Dictionary = {}
	var t2: MeshLayer = sh.alcove_template(0, 5.0, 1)
	for i: int in t2.size():
		var p: Vector3 = t2.verts[i]
		if absf(p.x - 0.05) < 0.001 and p.y > BeachShacks.ALCOVE_HEIGHT - 0.45 and t2.colors[i].a == 0.0 and roundi(t2.uv2s[i].x) == MeshKit.PAT_PLAIN:
			strips[t2.colors[i].to_html(false)] = true
	check(strips.size() == 2, "a veranda's awning is striped in two unlit colours (%s)" % str(strips.keys()))


## A lit colour a hazard could be mistaken for when it is bright and saturated (the lanterns' shells are muted).
func _hazard_hue_lit(c: Color) -> bool:
	return _chroma(c) > MAX_SURFACE_CHROMA

## Every kind of ceiling, on streets of 3, 5 and 6 lanes over every number of their lanes, full width or narrow
## and pushed against a wall (task B3): a flat underside covering exactly its lanes (a footbridge reaches from
## wall to wall, a veranda deck from the wall it reaches to its free edge, a barge covers its own lanes), nothing
## hanging below it but flush lamps and seams, the orange band at its far end, a seam under each lane boundary,
## everything above it under TOP_LIMIT; and a footbridge needs every lane, a veranda deck a wall.
func _ceilings(skin: BeachSkin) -> void:
	var lane_w: float = tuning.lane_width
	var problems: PackedStringArray = []
	var kinds_seen: Dictionary = {}
	var emblems: int = 0
	var barges: int = 0
	for street: int in [3, 5, 6]:
		var wall_x: float = street * lane_w * 0.5 + tuning.wall_margin
		for first: int in street:
			for last: int in range(first, street):
				var lanes: int = last - first + 1
				var x0: float = (float(first) - float(street) * 0.5) * lane_w
				var x1: float = x0 + float(lanes) * lane_w
				var offset: float = (x0 + x1) * 0.5
				var reach_l: bool = first == 0
				var reach_r: bool = last == street - 1
				var allowed: Array[int] = [BeachCeilings.Kind.BARGE]
				if reach_l and reach_r:
					allowed.append(BeachCeilings.Kind.FOOTBRIDGE)
				elif reach_l or reach_r:
					allowed.append(BeachCeilings.Kind.VERANDA)
				var size := Vector3(float(lanes) * lane_w, TrackBuilder.HULL_THICKNESS, 30.0)
				var edges: Array[float] = []
				for k: int in range(first + 1, last + 1):
					edges.append((float(k) - float(street) * 0.5) * lane_w)
				for kind: int in allowed:
					for variant: int in 4:
						size.z = 30.0 + 10.0 * float(variant)
						var tag: String = "kind %d, lanes %d-%d of %d, variant %d" % [kind, first, last, street, variant]
						var mesh: ArrayMesh = skin.ceilings().mesh_for(kind, variant, size, edges, offset, wall_x, reach_l, reach_r)
						kinds_seen[kind] = true
						var under := {"min_x": INF, "max_x": -INF, "lowest": 0.0, "band": false, "top": 0.0, "mark": 0, "mark_lit": 0}
						_ceiling_mesh(mesh, skin, size, under)
						var want_l: float = -wall_x - offset if (reach_l and kind != BeachCeilings.Kind.BARGE) else -size.x * 0.5 - 0.15
						var want_r: float = wall_x - offset if (reach_r and kind != BeachCeilings.Kind.BARGE) else size.x * 0.5 + 0.15
						if absf(under["min_x"] - want_l) > 0.02 or absf(under["max_x"] - want_r) > 0.02:
							problems.append("%s: underside spans %.2f..%.2f, not %.2f..%.2f" % [tag, under["min_x"], under["max_x"], want_l, want_r])
						if under["lowest"] < -0.06:
							problems.append("%s: something hangs %.2f m below the surface" % [tag, under["lowest"]])
						if not under["band"]:
							problems.append("%s: no orange band at the far end" % tag)
						if under["top"] > BeachCeilings.TOP_LIMIT + 0.001:
							problems.append("%s: something rises %.2f m over the underside, over TOP_LIMIT %.1f" % [tag, under["top"], BeachCeilings.TOP_LIMIT])
						for x: float in edges:
							if not _has_seam(mesh, x - offset, skin):
								problems.append("%s: no seam at x %.2f" % [tag, x - offset])
						if kind == BeachCeilings.Kind.BARGE:
							barges += 1
							emblems += 1 if under["mark"] > 0 and under["mark_lit"] == 0 else 0
						if problems.size() > 6:
							break
	check(problems.is_empty(), "every kind of ceiling builds from its lanes, full width or narrow:\n  %s" % "\n  ".join(problems))
	check(kinds_seen.size() == 3, "all three kinds of ceiling are built (%s)" % str(kinds_seen.keys()))
	check(barges > 0 and emblems == barges, "every barge carries the cult's emblem on its hull in unlit bronze (%d of %d)" % [emblems, barges])
	# Which kind a ceiling gets: a footbridge only across every lane, a veranda deck only against a wall.
	var full: Dictionary = {}
	var one_wall: Dictionary = {}
	var middle: Dictionary = {}
	var wall_x: float = 3.0 * lane_w + tuning.wall_margin
	for i: int in 300:
		var z: float = -(100.0 + float(i) * 7.3)
		var wide := Vector3(6.0 * lane_w, TrackBuilder.HULL_THICKNESS, 40.0 + float(i % 5) * 4.0)
		full[skin.ceilings().kind_of(Vector3(0, 6.4, z), wide, wall_x)] = true
		var narrow := Vector3(2.0 * lane_w, TrackBuilder.HULL_THICKNESS, wide.z)
		one_wall[skin.ceilings().kind_of(Vector3(-2.0 * lane_w, 6.4, z), narrow, wall_x)] = true
		middle[skin.ceilings().kind_of(Vector3(0.0, 6.4, z), narrow, wall_x)] = true
	check(full.size() == 2 and full.has(BeachCeilings.Kind.FOOTBRIDGE) and full.has(BeachCeilings.Kind.BARGE),
		"across every lane a ceiling is a footbridge or a barge")
	check(one_wall.size() == 2 and one_wall.has(BeachCeilings.Kind.VERANDA) and one_wall.has(BeachCeilings.Kind.BARGE),
		"against a wall a narrow ceiling is a veranda deck or a barge")
	check(middle.size() == 1 and middle.has(BeachCeilings.Kind.BARGE), "reaching neither wall a ceiling is a barge")


## One ceiling mesh's underside (its extent across, its lowest point, the orange band), its height over the
## underside, and the emblem's marks (PAT_CULT_MARK rects, unlit or glowing), into `under`.
func _ceiling_mesh(mesh: ArrayMesh, skin: BeachSkin, size: Vector3, under: Dictionary) -> void:
	for s: int in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		if mesh.surface_get_material(s) == skin.glow_material():
			continue
		for i: int in verts.size():
			var v: Vector3 = verts[i]
			under["lowest"] = minf(under["lowest"], v.y)
			under["top"] = maxf(under["top"], v.y)
			if roundi(uv2[i].x) == MeshKit.PAT_CULT_MARK:
				under["mark"] += 1
				under["mark_lit"] += 1 if colors[i].a > 0.0 or not _same_rgb(colors[i], skin.emblem_metal_color()) else 0
			if absf(v.y) < 0.001:
				under["min_x"] = minf(under["min_x"], v.x)
				under["max_x"] = maxf(under["max_x"], v.x)
				if _same_rgb(colors[i], skin.gap_edge_color) and v.z < -size.z * 0.5 + BeachCeilings.END_BAND + 0.01:
					under["band"] = true


## The cult's emblem (GDD §5): the owner's choice (data/world/cult_emblem_choice.tres), never hardcoded, hidden in
## plain sight: a warm-white neon badge on some neon signs and billboards, unlit bronze on the barge's hull,
## never smaller than emblem_min_size, never a hazard colour, never on a hazard, and high above the band.
func _cult_emblem(skin: BeachSkin) -> void:
	var choice := load(CultFeed.CHOICE_PATH) as CultEmblemChoice
	check(choice != null and CultFeed.emblem_option() == choice.option,
		"the beach draws the cult emblem the owner picked (option %s)" % (CultEmblem.option_letter(choice.option) if choice != null else "?"))
	if choice == null:
		return
	var scheme: Dictionary = CultEmblem.default_scheme(choice.option)
	check(skin.emblem_color() == scheme["neon"] and skin.emblem_metal_color() == scheme["metal"] and skin.emblem_glow > 0.0
		and skin.emblem_min_size >= 0.9 and not _hazard_hue(skin.emblem_color()),
		"it glows in the chosen emblem's warm-white neon, or is its unlit bronze, at least 0.9 m across")
	check(skin.solid_material().get_shader_parameter("cult_emblem") == CultFeed.emblem_texture(),
		"the kit material carries CultEmblem's drawing of that option")
	var geo := TrackGeometry.new(5, tuning)
	var wall: float = geo.wall_x()
	var kinds: Dictionary = {}
	var listed: Array[Dictionary] = []
	var small: PackedStringArray = []
	for side: int in [-1, 1]:
		for e: Dictionary in skin.cult_emblems(side, side * wall, -100.0, 3000.0):
			kinds[e["kind"]] = int(kinds.get(e["kind"], 0)) + 1
			listed.append(e)
			if float(e["size"]) < skin.emblem_min_size - 0.01 or (e["center"] as Vector3).y < skin.decor_min_height:
				small.append("%s %.2f m at %s" % [e["kind"], e["size"], e["center"]])
	print("  beach emblem (5 lanes): %s over 3 km of walls" % kinds)
	check(kinds.has(&"sign") and kinds.has(&"billboard"), "over 3 km the emblem hides on neon signs and billboards: %s" % kinds)
	check(small.is_empty(), "each is %.2f m across or more, high on the walls: %s" % [skin.emblem_min_size, ", ".join(small.slice(0, 4))])
	var built: Array[Dictionary] = []
	var bad: PackedStringArray = []
	await visit_level(level(BEACH_LEVEL_PATH, 5, 0.6), skin, func(m: MeshInstance3D, arrays: Array, material: Material) -> void:
		if material != skin.solid_material():
			return
		for r: Dictionary in rects_of(m, arrays):
			if r["pattern"] != MeshKit.PAT_CULT_MARK:
				continue
			built.append(r)
			var c: Color = r["color"]
			var neon: bool = _same_rgb(c, scheme["neon"]) and absf(c.a - skin.emblem_glow) < 0.01
			var metal: bool = _same_rgb(c, scheme["metal"]) and c.a == 0.0
			var extent: float = maxf((r["ou"] as Vector3).distance_to(r["o"]), (r["ov"] as Vector3).distance_to(r["o"]))
			if (not (neon or metal) or under_hazard(m) or extent / BeachShacks.EMBLEM_MARGIN < skin.emblem_min_size - 0.01) \
					and bad.size() < 4:
				bad.append("%s (colour %s, %.2f m)" % [r["center"], c, extent]))
	var unlisted: int = 0
	var neon_marks: int = 0
	for r: Dictionary in built:
		if (r["color"] as Color).a == 0.0:
			continue
		neon_marks += 1
		var found: bool = false
		for e: Dictionary in listed:
			found = found or (e["center"] as Vector3).distance_to(r["center"]) < 0.1
		unlisted += int(not found)
	check(not built.is_empty() and bad.is_empty(), "over a whole level the %d emblems are the chosen one, in its colours, big enough, off hazards: %s" % [
		built.size(), ", ".join(bad)])
	check(neon_marks > 0 and unlisted == 0, "every neon emblem built is one cult_emblems() lists (%d of %d unlisted)" % [unlisted, neon_marks])


## The cult's feed (CultFeed, GDD §5 "Cyborg Viewing Devices") plays on TVs behind some upper-deck bars and on
## some roof billboards, all with the one shared feed material, only high up (never on the wall-run band),
## behind the face's plane; every screen built is one feed_boards() lists.
func _cult_feed(skin: BeachSkin) -> void:
	check(skin.feed_material() == CultFeed.material(), "the Beach plays the shared feed")
	var kinds: Dictionary = {}
	var listed: Array[Dictionary] = []
	var geo := TrackGeometry.new(5, tuning)
	for lanes: int in [3, 6]:
		var wall: float = TrackGeometry.new(lanes, tuning).wall_x()
		for side: int in [-1, 1]:
			for board: Dictionary in skin.feed_boards(side, side * wall, 0.0, 3000.0):
				kinds[board["kind"]] = int(kinds.get(board["kind"], 0)) + 1
				check((board["center"] as Vector3).y - float(board["height"]) * 0.5 >= skin.decor_min_height, "a feed screen sits above the band: %s" % [board])
				if lanes == 3:
					listed.append(board)
	print("  beach feed (3 lanes): %s over 3 km of walls" % kinds)
	check(kinds.has(&"deck_tv") and kinds.has(&"roof_board"), "over 3 km the feed plays on deck TVs and roof billboards: %s" % kinds)
	var layout: LevelLayout = level(BEACH_LEVEL_PATH, 5, 0.6, 5)
	var wall: float = geo.wall_x()
	var shown := {"high": 0, "bad": []}
	var screens: Array[Vector3] = []
	var visit := func(m: MeshInstance3D, arrays: Array, material: Material) -> void:
		if material != skin.feed_material():
			return
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i: int in range(0, verts.size() - 5, 6):
			var p: Vector3 = m.global_transform * ((verts[i + 1] + verts[i + 5]) * 0.5)
			var low: float = minf((m.global_transform * verts[i]).y, (m.global_transform * verts[i + 1]).y)
			screens.append(p)
			if low >= skin.decor_min_height and absf(p.x) > wall - 0.05:
				shown["high"] += 1
			elif shown["bad"].size() < 4:
				shown["bad"].append(str(p))
	await visit_level(layout, skin, visit)
	check(shown["bad"].is_empty() and shown["high"] > 0, "the feed plays only high up, behind the wall's face (%d screens): %s" % [shown["high"],
		", ".join(shown["bad"])])
	var all: Array[Dictionary] = []
	for side: int in [-1, 1]:
		all.append_array(skin.feed_boards(side, side * wall, -100.0, layout.length + 200.0))
	var unlisted: int = 0
	for p: Vector3 in screens:
		var found: bool = false
		for board: Dictionary in all:
			found = found or (board["center"] as Vector3).distance_to(p) < 0.1
		unlisted += int(not found)
	check(unlisted == 0, "every feed screen built is one feed_boards() lists (%d unlisted of %d)" % [unlisted, screens.size()])


## Signs: the hazard frame around a painted wordless board; the neon signs and posters show every glyph (a sun,
## waves, a palm, a surfboard, a flamingo, a cocktail glass, a tiki totem) and every neon colour.
func _signs(skin: BeachSkin) -> void:
	var glyphs: Dictionary = {}
	var tubes: Dictionary = {}
	for lanes: int in [3, 6]:
		var wall: float = TrackGeometry.new(lanes, tuning).wall_x()
		for side: int in [-1, 1]:
			var batch := MeshBatch.new()
			skin.shacks().build(batch, side, side * wall, 0.0, 3000.0)
			var layer: MeshLayer = batch.layer(skin.solid_material())
			var i: int = 0
			while i + 5 < layer.size():
				if roundi(layer.uv2s[i].x) == MeshKit.PAT_BEACH_NEON:
					glyphs[int(layer.uv2s[i].y) % 8] = true
					tubes[layer.colors[i].to_html(false)] = true
					i += 6
				else:
					i += 1
	check(glyphs.size() == MeshKit.GLYPH_COUNT, "the neon signs show all %d silhouettes: %s" % [MeshKit.GLYPH_COUNT, str(glyphs.keys())])
	check(tubes.size() == 3, "in violet, blue and warm white: %s" % str(tubes.keys()))
	for glyph: int in MeshKit.GLYPH_COUNT:
		var param: float = MeshKit.beach_neon_param(glyph, 2.6, 1.9)
		check(int(param) % 8 == glyph and int(param / 8.0) % 64 == 19 and int(param / 512.0) == 26, "a neon sign's glyph, height and width round-trip (%d)" % glyph)
	# A painted board's too, and every pattern parameter stays small enough for a rasterizer's interpolation of a
	# constant (a few units in the last place off) to round back to what was written: under 2^20.
	var art: float = MeshKit.beach_art_param(5, 4.4, 2.5, 77)
	check(int(art) % 32 == 77 % 32 and int(art / 32.0) % 8 == 5 and int(art / 256.0) % 64 == 25 and int(art / 16384.0) == 44,
		"a painted board's seed, glyph, height and width round-trip (%s)" % art)
	var biggest: float = maxf(maxf(MeshKit.sand_param(63, 100.0, 99), MeshKit.beach_art_param(9, 99.0, 99.0, 99)),
		maxf(MeshKit.beach_neon_param(9, 99.0, 99.0), MeshKit.beach_timber_param(3, 3, 99)))
	check(biggest < 1048576.0, "every Beach pattern parameter stays under 2^20 (%s)" % biggest)
	check(MeshKit.sand_param(63, 100.0, 99) == 63.0 + 64.0 * 255.0 + 16384.0 * 3.0, "a sand parameter keeps its flags, its length (a quarter of a metre) and its lane")
	# A hazard sign's painted board: the frame is the hazard, the board's paints are muted.
	var track: TrackBuilder = showcase_track(skin)
	var boards: int = 0
	var frames: int = 0
	for node: Node in nodes_of(track, func(n: Node) -> bool: return n is Hazard):
		var hazard := node as Hazard
		if not hazard.hazard_name.begins_with("sign"):
			continue
		for m: MeshInstance3D in visible_meshes(hazard):
			for s: int in m.mesh.get_surface_count():
				var uv2: PackedVector2Array = m.mesh.surface_get_arrays(s)[Mesh.ARRAY_TEX_UV2]
				var colors: PackedColorArray = m.mesh.surface_get_arrays(s)[Mesh.ARRAY_COLOR]
				for i: int in uv2.size():
					var pattern: int = roundi(uv2[i].x)
					if pattern == MeshKit.PAT_BEACH_PAINT:
						boards += 1
						check(colors[i].a == 0.0, "a sign's painted board never glows")
					if pattern == MeshKit.PAT_STRIPES:
						frames += 1
	check(boards > 0 and frames > 0, "signs are the hazard frame around a painted board (%d board vertices, %d frame vertices)" % [boards, frames])
	await free_track(track)


## The doodads: a surfboard rack (small), a cabana or a palm in a planter (medium, by look_seed), a tiki bar
## kiosk (large), each a look of its own.
func _doodads(skin: BeachSkin) -> void:
	var meshes: Dictionary = {}
	var mediums: Dictionary = {}
	for size: StringName in LevelLayout.DOODAD_SIZES:
		var box: Vector3 = tuning.doodad_size(size)
		for look_seed: int in 24:
			var body := Node3D.new()
			skin.doodad(body, box, size, 1, look_seed)
			var inst := body.get_child(0) as MeshInstance3D
			meshes[inst.mesh] = size
			if size == &"medium":
				mediums[inst.mesh] = true
			body.free()
	check(meshes.size() >= 6 and mediums.size() >= 2, "the doodads vary with their seed (%d meshes, %d mediums)" % [meshes.size(), mediums.size()])
	for size: StringName in LevelLayout.DOODAD_SIZES:
		var box: Vector3 = tuning.doodad_size(size)
		var body := Node3D.new()
		skin.doodad(body, box, size, 1, 3)
		var aabb: AABB = (body.get_child(0) as MeshInstance3D).mesh.get_aabb()
		# They fill most of their box.
		check(aabb.size.x > box.x * 0.55 and aabb.size.y > box.y * 0.75 and aabb.size.z > box.z * 0.55,
			"the %s doodad fills most of its box (%s in %s)" % [size, aabb.size, box])
		body.free()


## The shader and the kit: pattern ids 80-89 are the Beach's, unique among every kit pattern, dispatched in
## kit_solid; the water honours Reduced flashing and nothing else in the Beach's patterns reads the time.
func _shader(skin: BeachSkin) -> void:
	var ids: Dictionary = {}
	var clash: PackedStringArray = []
	var beach: int = 0
	var constants: Dictionary = (load("res://scripts/world/meshes/mesh_kit.gd") as Script).get_script_constant_map()
	for key: String in constants:
		if not key.begins_with("PAT_"):
			continue
		var id: int = int(constants[key])
		if ids.has(id) and clash.size() < 4:
			clash.append("%s and %s" % [key, ids[id]])
		ids[id] = key
		if key.begins_with("PAT_BEACH_"):
			beach += 1
			check(id >= 80 and id <= 89, "%s is in the Beach's block of ids (%d)" % [key, id])
	check(clash.is_empty() and beach == 10, "every pattern id is unique, and the Beach has its ten: %s" % ", ".join(clash))
	var solid: String = FileAccess.get_file_as_string("res://scripts/world/meshes/shaders/kit_solid.gdshader")
	var include: String = FileAccess.get_file_as_string("res://scripts/world/meshes/shaders/kit_beach.gdshaderinc")
	check(solid.contains("kit_beach.gdshaderinc") and solid.contains("pattern >= 80 && pattern < 90"), "kit_solid includes and dispatches the Beach's patterns")
	var uniforms: Array[String] = []
	for u: Dictionary in skin.solid_material().shader.get_shader_uniform_list():
		uniforms.append(String(u["name"]))
	check(uniforms.has("bc_paint_a") and uniforms.has("bc_pool_depth") and uniforms.has("bc_daylight") and uniforms.has("bc_water_glint"),
		"the beach's patterns are part of the solid material's shader")
	check(include.contains("reduced_flashing") and include.count("TIME") == 0 and include.contains("float t) {"),
		"the water ripple honours Reduced flashing, and only the water takes the time")
	var neon: String = include.substr(include.find("vec3 bc_neon("), include.find("// PAT_BEACH_TIMBER") - include.find("vec3 bc_neon("))
	check(not neon.contains(" t") or not neon.contains("TIME"), "the neon signs don't flicker")


func _under(node: Node, test: Callable) -> bool:
	var parent: Node = node.get_parent()
	while parent != null:
		if test.call(parent):
			return true
		parent = parent.get_parent()
	return false


func _has_seam(mesh: ArrayMesh, x: float, skin: BeachSkin) -> bool:
	for s: int in mesh.get_surface_count():
		if mesh.surface_get_material(s) != skin.solid_material():
			continue
		for v: Vector3 in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			if absf(v.x - (x - 0.03)) < 0.002 and v.y < 0.0 and v.y > -0.02:
				return true
	return false


static func _chroma(c: Color) -> float:
	return maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))


## A saturated colour outside the decorative blue-to-violet band: pink, red, orange, yellow, green or cyan (GDD §5:
## those glow only on hazards).
static func _hazard_hue(c: Color) -> bool:
	if c.s < GLOW_SATURATION_LIMIT:
		return false
	return c.h < 0.58 or c.h > 0.8


static func _same_rgb(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01


static func _rgb_distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


## Relative luminance of an sRGB colour, in linear light.
static func _linear_luminance(c: Color) -> float:
	var l: Color = c.srgb_to_linear()
	return 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b


## Whether `c` could pass for `target` (a bright, saturated hazard colour): close in RGB, or as bright and
## saturated and within 20 degrees of its hue. A lit brown, honey or coral is not one: the hazards are the
## brightest, most saturated things on screen.
static func _near_colour(c: Color, target: Color) -> bool:
	if _rgb_distance(c, target) < 0.35:
		return true
	var dh: float = absf(c.h - target.h)
	return c.s > 0.6 and c.v > 0.7 and minf(dh, 1.0 - dh) < 20.0 / 360.0

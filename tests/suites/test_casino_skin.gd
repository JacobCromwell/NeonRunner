extends SkinSuite
## The Casino skin (CasinoSkin, Zone 4; task K1; the owner's reference image, GDD §5), which the
## Casino zone and The House's arena use. The shared skin checks (SkinSuite) over a whole level for 3, 5
## and 6 lanes (the Marketplace's richest, whose features the Casino's levels share), then the Casino's
## own:
## - it is the owner's request: scenery only. The enemies keep the Marketplace's look (enemy_variant
##   &"casino"), the citizens in the shop windows are the Marketplace's own class (MarketCitizen, in the
##   group The House's crowds use), and nothing here builds a character;
## - gaps keep the orange edge glow right on the collision edge, and read as holes: everything under the
##   paving is in deep shade, far darker than any paving, nothing in there glows but the orange edge;
## - the colour rule (GDD §5): nothing but hazards glows in a hazard hue (pink, red, orange, yellow,
##   green, cyan), the reference's neon only ever as dim background, and lit surfaces stay well below the
##   hazards' saturation;
## - the play space stays clear: between the floor and the ceiling over the lanes there is nothing but
##   hazards and triggers, nothing sticks out of the walls through the wall-run band, and nothing vent-like
##   is drawn (the screeches' lairs);
## - decorative signs, banners and lights are unframed and never below decor_min_height, and only
##   hazard signs wear the striped frame;
## - the shop windows for the citizens are where shop_windows() says, above the vent zone, each with its
##   display;
## - every kind of ceiling builds from the lanes it covers, full width or narrow (task B3): a flat
##   underside over exactly its lanes, the orange end band, the lane seams, nothing hanging below it, its
##   structure under the arrival flyover's height and its signs above decor_min_height;
## - the named casinos' lettering (task K3): the big signs spell "Gasket's House of Chance" and "The Brass
##   Lotus" in the repo's own font as plain triangles in the chunk's solid layer, on a blade sign and on the
##   sign, never below decor_min_height, in warm white, within a vertex budget, and nowhere else;
## - the glass vault is background and whole (no missing panes): opaque (no transparency: the solid and glow
##   materials only), far above everything the player can reach, and whatever hangs from it stays above
##   `bunting_height`: its girders run wall to wall under the eave and its fans' blades stay inside the
##   glass; the arena's variant (The House is 13.5 m tall) keeps its facades flush below 14.4 m (the
##   street's are flush below its own 10 m), hangs nothing and raises the roof above the phase-3
##   billboard's drop (at 3, 5 and 6 lanes);
## - the cult's emblem is the owner's choice, hidden here and there on signs, never smaller than
##   emblem_min_size; the cult's feed (CultFeed) plays only on lit billboards and signs high up and on TVs
##   in some shop windows;
## - the still floor carries drifting dust and speed streaks, and brass inlaid across it.

const CASINO_SKIN_PATH: String = "res://data/skins/casino_skin.tres"
const ARENA_SKIN_PATH: String = "res://data/bosses/casino_boss_skin.tres"
## The campaign level whose features the Casino's levels share (Marketplace 2 adds wall vents and wall
## fences); the layouts are the same whatever skin dresses them.
const CASINO_LEVEL_PATH: String = "res://data/levels/marketplace_2.tres"
## Lit (non-glowing) surfaces stay below this chroma (brightest minus darkest channel); the fence pink is
## about 0.8.
const MAX_SURFACE_CHROMA: float = 0.45
## A glowing colour this saturated (HSV) must keep to the decorative hues (blue to violet).
const GLOW_SATURATION_LIMIT: float = 0.35
## Gaps: the paving's lowest broad factor (a darker flagstone), PAT_CASINO_UNDER's brightest factor (the
## top of a face, at the lip), and how much darker than the darkest paving a gap's inside must stay
## (linear luminance).
const STREET_SHADE_MIN: float = 0.7
const UNDER_MAX_FACTOR: float = 0.9
const GAP_CONTRAST: float = 0.35
## The most any ceiling's structure may rise above its underside (the arrival flyover's height).
const CEILING_TOP: float = 6.3
## The lowest thing The House's arena may hang over the lanes (the machine is 13.5 m tall).
const ARENA_CLEARANCE: float = 14.4
## The named signs' lettering (task K3): the most vertices one layout may have, how many a 40 m stretch of one
## wall may carry, and the length of street the checks walk.
const MAX_LAYOUT_VERTICES: int = 2400
const MAX_LETTER_VERTICES: int = 8000
const STREET_LENGTH: float = 1200.0


func run() -> void:
	var skin := load(CASINO_SKIN_PATH) as CasinoSkin
	check(skin != null, "the casino skin loads")
	if skin == null:
		return
	# The owner's request: no new character looks. The Marketplace's enemies, as they are.
	check(skin.enemy_variant == &"casino" and CasinoSkin.new().enemy_variant == &"casino"
		and CyborgSuit.look_for(skin.enemy_variant) == CyborgSuit.CASINO,
		"casino cyborgs wear the Casino Mob Enforcer: the Marketplace's enemies, no new looks")
	check(BarnacleTurretModel.is_creature(skin.enemy_variant), "its turrets wear the creature look, as the Marketplace's")
	check(skin is MarketplaceSkin, "it builds on the Marketplace's skin: the same citizens, doodads, signs and feed")
	var arena := load(ARENA_SKIN_PATH) as CasinoSkin
	check(arena != null and arena.enemy_variant == &"casino", "The House's arena has its own casino skin")
	start_error_count()
	var env: Environment = skin.make_environment()
	check(env != null and env.sky != null and env.glow_enabled and env.fog_enabled,
		"the casino environment has a sky, glow and fog")
	check(env.glow_hdr_threshold >= 1.0, "its glow threshold stays high: only emissive parts bloom (%.2f)" % env.glow_hdr_threshold)
	_palette(skin)
	_shader_hooks(skin)
	for lanes: int in [3, 5, 6]:
		await whole_level(skin, "casino", CASINO_LEVEL_PATH, lanes)
	await hazards_and_triggers(skin)
	await _surfaces(skin)
	await _gaps(skin)
	await _clear_play_space(skin)
	await _shop_windows(skin)
	await _citizens(skin)
	_ceilings(skin)
	_vault(skin)
	await _arena(skin, arena)
	_lettering(skin, arena)
	_cult_emblem(skin)
	await _cult_feed(skin)
	await determinism(skin, CASINO_LEVEL_PATH)
	doodads_ok(skin, "casino")
	doodads_ok(arena, "casino arena")
	stop_error_count("building casino levels")


## The skin's decorative colours keep to the colour rule before anything is built.
func _palette(skin: CasinoSkin) -> void:
	var glowing: Array[Color] = [skin.lamp_color, skin.bulb_color, skin.window_warm_color, skin.ceiling_lamp_color,
		skin.engine_color, skin.lamp_light_color, skin.lettering_color]
	glowing.append_array(Array(skin.neon_colors))
	glowing.append_array(Array(skin.ad_colors))
	# Sign faces glow a little: inside the hazard frame, but kept off the other hazard hues too.
	glowing.append_array(Array(skin.sign_content_colors))
	var bad: PackedStringArray = []
	for c: Color in glowing:
		if _hazard_hue(c):
			bad.append(str(c))
	check(bad.is_empty(), "lamps, bulbs, neon and ads keep to warm white, blue and violet: %s" % ", ".join(bad))
	var lit: Array[Color] = [skin.street_color, skin.inlay_color, skin.iron_color, skin.brass_color, skin.brass_dim_color,
		skin.pane_color, skin.pane_lit_color, skin.ivy_color, skin.sign_panel_color, skin.gap_inside_color]
	for list: PackedColorArray in [skin.iron_colors, skin.shutter_colors, skin.painted_sign_colors, skin.dim_sign_colors,
			skin.banner_colors, skin.sign_content_colors, skin.doodad_plant_colors, skin.doodad_cabinet_colors]:
		lit.append_array(Array(list))
	var loud: PackedStringArray = []
	for c: Color in lit:
		if _chroma(c) > MAX_SURFACE_CHROMA:
			loud.append(str(c))
	check(loud.is_empty(), "lit surfaces stay well below the hazards' saturation: %s" % ", ".join(loud))
	check(_chroma(skin.fence_color) > MAX_SURFACE_CHROMA + 0.3, "the fence pink is far more saturated than any surface")
	# The brass is metal, never neon: it is lit through the shader's own reflection, not glowing: nothing the
	# skin builds in brass or iron carries glow (checked over a level in _surfaces()).
	var palette_ok: bool = true
	for c: Color in skin.doodad_palette:
		palette_ok = palette_ok and _chroma(c) <= MAX_SURFACE_CHROMA
	check(palette_ok, "the doodad palette is muted")


## The shader side: the solid material carries the Casino's uniforms (sRGB Vector3s, so both renderers
## draw them alike), the facade material is its own shader, and the kit dispatches the casino patterns.
func _shader_hooks(skin: CasinoSkin) -> void:
	var solid: ShaderMaterial = skin.solid_material()
	var has_all: bool = true
	for u: String in ["cas_shine", "cas_inlay", "cas_lamp", "cas_wet", "cas_pane", "cas_pane_lit", "cas_star", "cas_pane_len",
			"cas_vault_y", "cas_vault_rise", "cas_banner_w", "cas_banner_trim"]:
		has_all = has_all and solid.get_shader_parameter(u) != null
	check(has_all, "the solid material carries the casino's uniforms")
	check(solid.get_shader_parameter("cas_inlay") is Vector3 and solid.get_shader_parameter("cas_pane") is Vector3,
		"its colours reach the shader as sRGB Vector3s")
	check(is_equal_approx(float(solid.get_shader_parameter("cas_pane_len")) * 3.0, skin.bay_length),
		"the shader's pane length is a third of a bay")
	var facade: ShaderMaterial = skin.facade_material()
	check(facade.shader.resource_path.ends_with("casino_facade.gdshader"), "the facades are drawn by the casino's own shader")
	var kit: String = FileAccess.get_file_as_string("res://scripts/world/meshes/shaders/kit_solid.gdshader")
	check(kit.contains("casino_surface(pattern") and kit.contains("pattern >= 80 && pattern < 90"),
		"the kit shader dispatches the casino's pattern block (80-89)")
	var code: String = FileAccess.get_file_as_string("res://scripts/world/meshes/shaders/casino_facade.gdshader")
	check(code.contains("global uniform float scenery_light;") and code.contains("light_factor(scenery_light)"),
		"the facade shader dims with the scenery light")
	check(code.contains("reduced_flashing"), "the marquee bulbs honour Reduced flashing")
	var kc: String = FileAccess.get_file_as_string("res://scripts/world/meshes/shaders/kit_casino.gdshaderinc")
	check(kc.contains("reduced_flashing"), "the signs' breathing honours Reduced flashing")
	# Anything that moves with time in the casino's shaders goes through reduced_flashing on the same line:
	# a still street, steady marquees and signs when the setting is on (checked by rendering both ways in the
	# task's review as well).
	var unguarded: PackedStringArray = []
	var moving: int = 0
	var uses_time := RegEx.create_from_string("\\bTIME\\b|-\\s*t\\s*\\*")
	for source: String in [code, kc]:
		for line: String in source.split("\n"):
			var text: String = line.strip_edges()
			if text.begins_with("//"):
				continue
			if uses_time.search(text) != null:
				moving += 1
				if not text.contains("reduced_flashing"):
					unguarded.append(text)
	check(moving >= 2 and unguarded.is_empty(), "everything that moves with time is steady with Reduced flashing (%d lines): %s" % [
		moving, ", ".join(unguarded)])
	for id: int in [MeshKit.PAT_CASINO_STREET, MeshKit.PAT_CASINO_UNDER, MeshKit.PAT_CASINO_IRON, MeshKit.PAT_CASINO_BRASS,
			MeshKit.PAT_CASINO_VAULT, MeshKit.PAT_CASINO_SIGN, MeshKit.PAT_CASINO_BANNER]:
		check(id >= 80 and id < 90, "pattern %d is in the casino's block" % id)


## Over the showcase track (every kind of piece): the gap in lane 3 (50-57 m) has the orange edge glow on
## both edges; glowing surfaces keep off the hazard hues; lit ones stay desaturated; no surface uses the
## grille (vent) pattern; decorative signs are high; only hazards wear stripes; the drifting particles are
## there and the street has its brass.
func _surfaces(skin: CasinoSkin) -> void:
	var track: TrackBuilder = showcase_track(skin)
	var lane := Vector2(1.2, 3.6)
	var edges: Dictionary = {}
	var grilles: int = 0
	var stripes: int = 0
	var low_signs: PackedStringArray = []
	var hazard_hues: PackedStringArray = []
	var loud: PackedStringArray = []
	var drift_vertices: int = 0
	var street_vertices: int = 0
	var glowing_metal: int = 0
	var solid: Material = skin.solid_material()
	var glow: Material = skin.glow_material()
	var signs := [MeshKit.PAT_GLYPHS, MeshKit.PAT_AD, MeshKit.PAT_BULBS, MeshKit.PAT_SHOPSIGN, MeshKit.PAT_CASINO_SIGN,
		MeshKit.PAT_CASINO_BANNER]
	for node: Node in nodes_of(track, func(n: Node) -> bool: return n is MeshInstance3D):
		var m := node as MeshInstance3D
		if m.mesh == null or m.is_in_group(&"debug_hitbox"):
			continue
		var in_hazard: bool = _under(m, func(n: Node) -> bool: return n is Hazard)
		var in_trigger: bool = _under(m, func(n: Node) -> bool: return n is Area3D and n.has_meta(&"kind"))
		for s: int in m.mesh.get_surface_count():
			var material: Material = m.mesh.surface_get_material(s)
			var arrays: Array = m.mesh.surface_get_arrays(s)
			if material == skin.drift_material():
				drift_vertices += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
				continue
			if material != solid and material != glow:
				continue
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
			for i: int in verts.size():
				var c: Color = colors[i]
				var p: Vector3 = m.global_transform * verts[i]
				var pattern: int = roundi(uv2[i].x)
				if material == solid:
					if pattern == MeshKit.PAT_GRILLE:
						grilles += 1
					if pattern == MeshKit.PAT_STRIPES and not in_hazard:
						stripes += 1
					if pattern == MeshKit.PAT_CASINO_STREET:
						street_vertices += 1
					if (pattern == MeshKit.PAT_CASINO_BRASS or pattern == MeshKit.PAT_CASINO_IRON) and c.a > 0.0 and not in_hazard \
							and not in_trigger:
						glowing_metal += 1
					if signs.has(pattern) and not in_hazard and p.y < skin.decor_min_height - 0.01 and low_signs.size() < 4:
						low_signs.append("%d at %s" % [pattern, p])
					if c.a == 0.0 and _chroma(c) > MAX_SURFACE_CHROMA and loud.size() < 4:
						loud.append("%s at %s" % [c, p])
					if c.a > 0.2 and _same_rgb(c, skin.gap_edge_color) and absf(p.y) < 0.01 \
							and p.x > lane.x - 0.01 and p.x < lane.y + 0.01:
						for edge: float in [50.0, 57.0]:
							if absf(-p.z - edge) < 0.25:
								edges[edge] = true
				var glowing: bool = material == glow or c.a > 0.0
				if glowing and not in_hazard and not in_trigger and _hazard_hue(c) \
						and not _same_rgb(c, skin.gap_edge_color) and hazard_hues.size() < 4:
					hazard_hues.append("%s at %s" % [c, p])
	check(edges.has(50.0) and edges.has(57.0), "a gap keeps the orange edge glow on both of its edges (%s)" % [edges.keys()])
	check(grilles == 0, "nothing vent-like: no surface uses the grille pattern (%d vertices)" % grilles)
	check(stripes == 0, "only hazard signs wear the striped frame (%d striped vertices elsewhere)" % stripes)
	check(low_signs.is_empty(), "decorative signs, banners and bulbs stay above %.1f m: %s" % [skin.decor_min_height,
		", ".join(low_signs)])
	check(hazard_hues.is_empty(), "nothing but hazards (and the orange edges) glows in a hazard hue: %s" % ", ".join(hazard_hues))
	check(loud.is_empty(), "lit surfaces stay desaturated: %s" % ", ".join(loud))
	check(glowing_metal == 0, "brass and iron are lit metal, never neon (%d glowing vertices)" % glowing_metal)
	check(drift_vertices > 0, "the street carries drifting dust and speed streaks (%d vertices)" % drift_vertices)
	check(street_vertices > 0, "the street is paved with the casino's own pattern (%d vertices)" % street_vertices)
	# The facade shader's lights come from uniforms, not vertices: they keep to the rule too.
	var facade: ShaderMaterial = skin.facade_material()
	var lights: PackedStringArray = []
	for u: String in ["window_warm", "bulb_color", "neon_a", "neon_b"]:
		var v: Vector3 = facade.get_shader_parameter(u)
		var c := Color(v.x, v.y, v.z)
		if _hazard_hue(c):
			lights.append("%s %s" % [u, c])
	check(lights.is_empty(), "the facades' lights keep off the hazard hues: %s" % ", ".join(lights))
	await free_track(track)


## Gaps read as holes at a glance, as in every zone (CLAUDE.md readability rules): whatever a gap shows is
## in deep shade, far darker than any paving can be drawn, and nothing in it glows but the orange strip
## along the edge; no paving is drawn in (or near) the edge's colour; and the far edge of the showcase gap
## carries the full orange edge: the lip on the paving and the strip below it. Checked over a whole
## level: below the paving there is nothing but the shade and the strips.
func _gaps(skin: CasinoSkin) -> void:
	var paving: Array[Color] = [skin.street_color, skin.inlay_color, skin.iron_color]
	var darkest: float = _linear_luminance(skin.street_color * Color(STREET_SHADE_MIN, STREET_SHADE_MIN, STREET_SHADE_MIN))
	var like_edge: PackedStringArray = []
	for c: Color in paving:
		if _near_colour(c, skin.gap_edge_color):
			like_edge.append(str(c))
	var inside: float = _linear_luminance(skin.gap_inside_color * Color(UNDER_MAX_FACTOR, UNDER_MAX_FACTOR, UNDER_MAX_FACTOR))
	check(inside < darkest * GAP_CONTRAST, "a gap's inside stays far darker than the darkest paving: %.4f vs %.4f" % [
		inside, darkest])
	check(like_edge.is_empty(), "no paving or inlay is drawn in the gap edge's colour: %s" % ", ".join(like_edge))
	# The showcase gap (lane 3, 50-57 m): its far edge, facing the player, has the lip and the strip.
	var track: TrackBuilder = showcase_track(skin)
	var strip := Vector2(INF, -INF)
	var lip := Vector2(INF, -INF)
	for node: Node in nodes_of(track, func(n: Node) -> bool: return n is MeshInstance3D):
		var m := node as MeshInstance3D
		for s: int in m.mesh.get_surface_count() if m.mesh != null else 0:
			if m.mesh.surface_get_material(s) != skin.solid_material():
				continue
			var arrays: Array = m.mesh.surface_get_arrays(s)
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i: int in verts.size():
				var p: Vector3 = m.global_transform * verts[i]
				if not _same_rgb(colors[i], skin.gap_edge_color) or p.x < 1.2 or p.x > 3.6 or absf(-p.z - 57.0) > 0.3:
					continue
				if p.y < -0.001 and colors[i].a >= CasinoStreet.STRIP_GLOW - 0.001:
					strip = Vector2(minf(strip.x, p.y), maxf(strip.y, p.y))
				elif absf(p.y) < 0.001 and colors[i].a >= CasinoStreet.LIP_GLOW - 0.001:
					lip = Vector2(minf(lip.x, -p.z), maxf(lip.y, -p.z))
	check(strip.y - strip.x >= CasinoStreet.STRIP_HEIGHT - 0.001 and strip.y > -0.05,
		"the far edge's orange strip runs along the top of its face: %s" % strip)
	check(lip.x > 56.99 and lip.y - lip.x >= CasinoStreet.EDGE_LIP - 0.001,
		"the far edge's orange lip lies on the paving right at the collision edge: %s" % lip)
	await free_track(track)
	# A whole level, chunk by chunk: below the paving only the shade (PAT_CASINO_UNDER, no brighter than the
	# skin's gap_inside_color, unlit) and the orange strips.
	var layout: LevelLayout = level(CASINO_LEVEL_PATH, 5, 0.6, 9)
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
				under += _check_under_paving(chunk, skin, layout.length, bad)
		d += TrackBuilder.CHUNK_LENGTH
	check(bad.is_empty() and under > 0, "below the paving there is only deep shade and the orange strips (%d vertices): %s" % [
		under, ", ".join(bad)])
	world.queue_free()
	await tree.process_frame


## Checks every vertex of the skin's meshes in `chunk` below the paving (hazards and triggers aside, and the
## finish gantry's posts at `finish`, which stand on the kerbs where no gap ever is): the shade or an
## orange strip. Returns how many there were; problems (up to four) go to `bad`.
func _check_under_paving(chunk: Node, skin: CasinoSkin, finish: float, bad: PackedStringArray) -> int:
	var count: int = 0
	var shade: float = _linear_luminance(skin.gap_inside_color) + 0.0001
	for node: Node in nodes_of(chunk, func(n: Node) -> bool: return n is MeshInstance3D):
		var m := node as MeshInstance3D
		if m.mesh == null or m.is_in_group(&"debug_hitbox") or _under(m, func(n: Node) -> bool: return n is Hazard) \
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
				var what: String = ""
				if material == skin.solid_material():
					var c: Color = colors[i]
					var strip: bool = _same_rgb(c, skin.gap_edge_color) and c.a >= CasinoStreet.STRIP_GLOW - 0.001
					var dark: bool = roundi(uv2[i].x) == MeshKit.PAT_CASINO_UNDER and c.a == 0.0 and _linear_luminance(c) <= shade
					if not strip and not dark:
						what = "%s pattern %d" % [c, roundi(uv2[i].x)]
				elif material != skin.drift_material():
					what = "material %s" % material.resource_path.get_file() if material != null else "no material"
				if what != "" and bad.size() < 4:
					bad.append("%s at %s" % [what, p])
	return count


## Between the floor and the ceiling, over the lanes, the skin builds nothing solid but hazards and
## triggers, anywhere in a whole level: the paving is flat, gap faces hang below it, and walls, signs and
## balconies stay outside the lanes or up high; and nothing sticks out of a wall through the wall-run band
## (the calm band: the facades are flush from the street up past it).
func _clear_play_space(skin: CasinoSkin) -> void:
	for lanes: int in [3, 6]:
		var layout: LevelLayout = level(CASINO_LEVEL_PATH, lanes, 0.6, 5)
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


## Solid vertices of the skin's meshes in `chunk` that lie over the lanes between the floor and the
## ceiling (up to four, appended to `out`), and those sticking out of a wall face by more than 5 cm below
## the calm band's top (band_top, and below the ceilings), up to four in `sticking`; the finish gantry's
## posts (at `finish`, shared by every zone) stand on the kerbs and don't count.
func _find_intruders(chunk: Node, skin: CasinoSkin, geo: TrackGeometry, finish: float, out: PackedStringArray,
		sticking: PackedStringArray) -> void:
	var half: float = geo.half_width()
	var wall: float = geo.wall_x()
	# The calm band's top, below the ceilings (which reach from wall to wall by design).
	var band_top: float = minf(skin.band_top, tuning.ceiling_height - 0.1)
	for node: Node in nodes_of(chunk, func(n: Node) -> bool: return n is MeshInstance3D):
		var m := node as MeshInstance3D
		if m.mesh == null or m.is_in_group(&"debug_hitbox") or _under(m, func(n: Node) -> bool: return n is Area3D):
			continue
		for s: int in m.mesh.get_surface_count():
			# Drifting dust and additive light (lamp halos) aren't objects.
			var material: Material = m.mesh.surface_get_material(s)
			if material == skin.drift_material() or material == skin.glow_material():
				continue
			var verts: PackedVector3Array = m.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			for v: Vector3 in verts:
				var p: Vector3 = m.global_transform * v
				if absf(p.x) < half - 0.01 and p.y > 0.06 and p.y < tuning.ceiling_height - 0.1 and out.size() < 4:
					out.append(str(p))
				elif absf(p.x) >= half - 0.01 and absf(p.x) < wall - 0.05 and p.y > 0.06 and p.y < band_top \
						and absf(-p.z - finish) > 1.0 and not _under(m, func(n: Node) -> bool: return n is Hazard) \
						and sticking.size() < 4:
					sticking.append(str(p))


## The citizens' windows (task D3): where shop_windows() says, the same every time, above the wall vents'
## zone, one after another along the wall, and really open in the built wall (a display's back wall behind
## each).
func _shop_windows(skin: CasinoSkin) -> void:
	var geo := TrackGeometry.new(5, tuning)
	var ok: bool = true
	var count: int = 0
	for side: int in [-1, 1]:
		var face_x: float = side * geo.wall_x()
		var windows: Array[Dictionary] = skin.shop_windows(side, face_x, 0.0, 200.0)
		check(windows == skin.shop_windows(side, face_x, 0.0, 200.0), "shop windows are the same every time (side %d)" % side)
		count += windows.size()
		var last_end: float = -INF
		for w: Dictionary in windows:
			var at: float = w["at"]
			var half: float = float(w["width"]) * 0.5
			ok = ok and at >= 0.0 and at < 200.0 and float(w["bottom"]) >= 0.75 and float(w["top"]) > float(w["bottom"]) + 1.2
			ok = ok and float(w["width"]) > 1.0 and float(w["depth"]) >= 0.3 and is_equal_approx((w["center"] as Vector3).x, face_x)
			ok = ok and at - half >= last_end - 0.001 and [&"shop", &"casino", &"hall"].has(w["kind"])
			last_end = at + half
	check(ok and count > 40, "shop windows sit low on the walls above the vents, one after another (%d in 200 m)" % count)
	# Built walls have a display behind every window: an interior face at face_x + side * depth.
	var batch := MeshBatch.new()
	skin.facades().build(batch, 1, geo.wall_x(), 40.0, 80.0)
	var mesh: ArrayMesh = batch.to_mesh()
	var interiors: Array[Vector3] = []
	for s: int in mesh.get_surface_count():
		if mesh.surface_get_material(s) != skin.facade_material():
			continue
		var arrays: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		for i: int in verts.size():
			if roundi(uv2[i].x) == MarketFacades.STYLE_INTERIOR:
				interiors.append(verts[i])
	var missing: int = 0
	var windows: Array[Dictionary] = skin.shop_windows(1, geo.wall_x(), 40.0, 80.0)
	for w: Dictionary in windows:
		var found: bool = false
		for v: Vector3 in interiors:
			if absf(v.x - (geo.wall_x() + skin.shop_depth)) < 0.01 and absf(-v.z - float(w["at"])) <= float(w["width"]) * 0.5 + 0.01:
				found = true
				break
		if not found:
			missing += 1
	check(not windows.is_empty() and missing == 0, "every shop window has its display built behind it (%d of %d missing)" % [
		missing, windows.size()])


## The Marketplace citizens play in the Casino's windows (the owner's request: no new characters): the very
## same class, in the group The House's crowds cheer and duck through (market_citizens), placed in free
## windows only, and switched off with Settings.citizens_enabled.
func _citizens(skin: CasinoSkin) -> void:
	var geo := TrackGeometry.new(5, tuning)
	var side: int = 1
	var face_x: float = side * geo.wall_x()
	var windows: Array[Dictionary] = skin.shop_windows(side, face_x, 0.0, 240.0)
	var free_at: float = -1.0
	for w: Dictionary in windows:
		if not bool(w["screen"]):
			free_at = float(w["at"])
			break
	skin.note_wall_enemies(side, 0.0, 240.0, [{"type": "window_cyborg", "at": free_at, "side": side}])
	var parent := Node3D.new()
	tree.root.add_child(parent)
	skin.citizens().build(parent, side, face_x, 0.0, 240.0)
	var placed: Array[MarketCitizen] = []
	for child: Node in parent.get_children():
		if child is MarketCitizen:
			placed.append(child as MarketCitizen)
	var avoided: bool = true
	for c: MarketCitizen in placed:
		avoided = avoided and absf(c.at - free_at) > MarketCitizens.CYBORG_MARGIN
	check(not placed.is_empty() and avoided, "the Marketplace's citizens play in the casino's windows, never beside a window cyborg (%d)" % placed.size())
	var grouped: int = 0
	for c: MarketCitizen in placed:
		grouped += 1 if c.is_in_group(&"market_citizens") else 0
	check(grouped == placed.size() and grouped > 0, "they join the market_citizens group The House's crowds use (%d of %d)" % [
		grouped, placed.size()])
	skin.note_wall_enemies(side, 0.0, 240.0, [])
	var saved: bool = Settings.citizens_enabled
	Settings.citizens_enabled = false
	var off := Node3D.new()
	tree.root.add_child(off)
	skin.citizens().build(off, side, face_x, 0.0, 240.0)
	check(off.get_child_count() == 0, "switched off by Settings > citizens: none built")
	Settings.citizens_enabled = saved
	off.queue_free()
	parent.queue_free()
	await tree.process_frame


## Every kind of ceiling, over every number of lanes from one to six, full width or narrow and off centre
## (task B3): a flat underside covering exactly its lanes, nothing hanging below it but flush lamps and
## seams, the orange band at its far end, a seam under each lane boundary, its structure under the arrival
## flyover's height and its signs above decor_min_height.
func _ceilings(skin: CasinoSkin) -> void:
	var lane_w: float = tuning.lane_width
	var wall_x: float = 3.0 * lane_w + tuning.wall_margin
	var problems: PackedStringArray = []
	var kinds_seen: Dictionary = {}
	for kind: int in [CasinoCeilings.Kind.FOOTBRIDGE, CasinoCeilings.Kind.GANTRY, CasinoCeilings.Kind.SIGN]:
		for lanes: int in range(1, 7):
			if kind == CasinoCeilings.Kind.FOOTBRIDGE and lanes != 6:
				continue
			for variant: int in 4:
				var offset: float = 0.0 if lanes == 6 else (6 - lanes) * lane_w * 0.5 * (1.0 if lanes % 2 == 0 else -1.0)
				var size := Vector3(lanes * lane_w, TrackBuilder.HULL_THICKNESS, 30.0)
				var edges: Array[float] = []
				for k: int in range(1, lanes):
					edges.append(offset - size.x * 0.5 + k * lane_w)
				var mesh: ArrayMesh = skin.casino_ceilings().mesh_for(kind, variant, size, edges, offset, wall_x,
					tuning.ceiling_height)
				var tag: String = "kind %d, %d lanes, variant %d" % [kind, lanes, variant]
				var under := {"min_x": INF, "max_x": -INF, "lowest": 0.0, "highest": -INF, "band": false}
				for s: int in mesh.get_surface_count():
					var arrays: Array = mesh.surface_get_arrays(s)
					var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
					var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
					var material: Material = mesh.surface_get_material(s)
					var glow_surface: bool = material == skin.glow_material()
					for i: int in verts.size():
						var v: Vector3 = verts[i]
						if not glow_surface:
							under["lowest"] = minf(under["lowest"], v.y)
							under["highest"] = maxf(under["highest"], v.y)
						if absf(v.y) < 0.001 and not glow_surface:
							under["min_x"] = minf(under["min_x"], v.x)
							under["max_x"] = maxf(under["max_x"], v.x)
							if _same_rgb(colors[i], skin.gap_edge_color) and v.z < -size.z * 0.5 + CasinoCeilings.END_BAND + 0.01:
								under["band"] = true
						if material == skin.solid_material() and roundi(uv2[i].x) == MeshKit.PAT_CASINO_SIGN \
								and tuning.ceiling_height + v.y < skin.decor_min_height - 0.01 and problems.size() < 8:
							problems.append("%s: a sign at %.2f m, below decor_min_height" % [tag, tuning.ceiling_height + v.y])
				var reach: float = size.x * 0.5 + 0.15
				var full: bool = kind == CasinoCeilings.Kind.FOOTBRIDGE
				var want: float = wall_x if full else reach
				if absf(under["min_x"] + want) > 0.02 or absf(under["max_x"] - want) > 0.02:
					problems.append("%s: underside spans %.2f..%.2f, not ±%.2f" % [tag, under["min_x"], under["max_x"], want])
				if under["lowest"] < -0.06:
					problems.append("%s: something hangs %.2f m below the surface" % [tag, under["lowest"]])
				if under["highest"] > CEILING_TOP:
					problems.append("%s: the structure rises %.2f m above the underside (limit %.1f)" % [tag, under["highest"], CEILING_TOP])
				if not under["band"]:
					problems.append("%s: no orange band at the far end" % tag)
				# Seams: a darker strip centred on each lane boundary.
				for x: float in edges:
					if not _has_seam(mesh, x - offset, skin):
						problems.append("%s: no seam at x %.2f" % [tag, x - offset])
				kinds_seen[kind] = true
				if problems.size() > 8:
					break
	check(problems.is_empty(), "every kind of ceiling builds from its lanes, full width or narrow:\n  %s" % "\n  ".join(problems))
	check(kinds_seen.size() == 3, "footbridges, gantries and sign gantries all build (%d kinds)" % kinds_seen.size())
	# Only a ceiling across every lane may become an iron footbridge between the balconies.
	var bridged: int = 0
	var narrow_bridged: int = 0
	var all_kinds: Dictionary = {}
	for i: int in 200:
		var z: float = -(100.0 + i * 7.3)
		var full := Vector3(6.0 * lane_w, TrackBuilder.HULL_THICKNESS, 40.0 + float(i % 5) * 4.0)
		var k: int = skin.casino_ceilings().kind_of(Vector3(0, 6.4, z), full, wall_x)
		all_kinds[k] = true
		if k == CasinoCeilings.Kind.FOOTBRIDGE:
			bridged += 1
		var narrow := Vector3(2.0 * lane_w, TrackBuilder.HULL_THICKNESS, full.z)
		if skin.casino_ceilings().kind_of(Vector3(lane_w, 6.4, z), narrow, wall_x) == CasinoCeilings.Kind.FOOTBRIDGE:
			narrow_bridged += 1
	check(bridged > 20 and narrow_bridged == 0 and all_kinds.size() == 3,
		"only full-width ceilings become footbridges (%d of 200 full, %d narrow), and every kind turns up" % [bridged, narrow_bridged])
	# The hooks TrackBuilder uses end in the same builder: a section and a bare box give the same kind.
	var geo := TrackGeometry.new(5, tuning)
	var section := CeilingSection.make(geo, tuning.ceiling_height, TrackBuilder.HULL_THICKNESS, 300.0, 340.0, Vector2i(1, 2))
	var root := Node3D.new()
	tree.root.add_child(root)
	skin.ceiling_section(root, section)
	check(root.get_child_count() == 1, "ceiling_section() dresses a section with one mesh")
	root.queue_free()


func _has_seam(mesh: ArrayMesh, x: float, skin: CasinoSkin) -> bool:
	for s: int in mesh.get_surface_count():
		if mesh.surface_get_material(s) != skin.solid_material():
			continue
		for v: Vector3 in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			if absf(v.x - (x - 0.03)) < 0.002 and v.y < 0.0 and v.y > -0.02:
				return true
	return false


## The glass vault (task K1; the owner's reference: a vaulted roof of glass and iron): background high
## overhead. Opaque and faked (the kit's solid and glow materials, no transparency: the phone rule), over
## the whole street at every lane count, springing from the facades' top and rising to a crown; WHOLE (owner,
## October 9, 2026: no broken or missing panes, every bay with every pane); everything that hangs from it
## stays above `bunting_height` (the arrival flyover and The House pass under it).
func _vault(skin: CasinoSkin) -> void:
	for lanes: int in [3, 5, 6]:
		var geo := TrackGeometry.new(lanes, tuning)
		var wall: float = geo.wall_x()
		var batch := MeshBatch.new()
		skin.vault().build(batch, wall, 0.0, 400.0)
		var mesh: ArrayMesh = batch.to_mesh()
		check(mesh != null, "the vault builds over %d lanes" % lanes)
		var arch: Dictionary = skin.vault().arch_of(wall)
		check(is_equal_approx(float(arch["crown"]), skin.eave_height + float(arch["rise"]))
			and is_equal_approx(CasinoVault.height_at(arch, wall), skin.eave_height)
			and is_equal_approx(CasinoVault.height_at(arch, 0.0), float(arch["crown"])),
			"the roof springs from the facades' top (%.0f m) and rises to its crown (%.1f m) at %d lanes" % [skin.eave_height,
				arch["crown"], lanes])
		check(float(arch["rise"]) <= skin.vault_rise_max + 0.001 and float(arch["crown"]) > skin.eave_height + 2.0,
			"its rise suits the street (%.1f m at %d lanes)" % [arch["rise"], lanes])
		var opaque: bool = true
		var lowest: float = INF
		var panes: int = 0
		var pane_tris: Dictionary = {}
		var highest: float = -INF
		for s: int in mesh.get_surface_count():
			var material: Material = mesh.surface_get_material(s)
			opaque = opaque and (material == skin.solid_material() or material == skin.glow_material())
			var arrays: Array = mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
			var glow_surface: bool = material == skin.glow_material()
			for i: int in verts.size():
				if not glow_surface:
					# The glass, ribs and everything hung from them, over the lanes or not.
					lowest = minf(lowest, verts[i].y)
					highest = maxf(highest, verts[i].y)
					if roundi(uv2[i].x) == MeshKit.PAT_CASINO_VAULT:
						panes += 1
						if i % 3 == 0:
							# One count per triangle, in the bay its middle is in.
							var bay: int = floori(-(verts[i].z + verts[i + 1].z + verts[i + 2].z) / 3.0 / skin.bay_length)
							pane_tris[bay] = int(pane_tris.get(bay, 0)) + 1
		check(opaque, "the vault is drawn with the solid and glow materials alone: no transparency (%d lanes)" % lanes)
		check(lowest >= skin.bunting_height - 0.001, "nothing hangs over the street below bunting_height (%.1f m, lowest %.2f) at %d lanes" % [
			skin.bunting_height, lowest, lanes])
		check(lowest >= 14.4, "and so nothing is lower than The House's 14.4 m (%.2f m)" % lowest)
		var full_panes: int = roundi(400.0 / skin.bay_length) * CasinoVault.ARC_SEGMENTS * CasinoVault.PANES_PER_BAY * 6
		check(panes == full_panes, "the roof is whole: every pane is there (%d of %d vertices) at %d lanes" % [panes, full_panes, lanes])
		var bays_whole: bool = pane_tris.size() == roundi(400.0 / skin.bay_length)
		for bay: int in pane_tris:
			bays_whole = bays_whole and int(pane_tris[bay]) == CasinoVault.ARC_SEGMENTS * CasinoVault.PANES_PER_BAY * 2
		check(bays_whole, "and every bay of it has all its %d panes at %d lanes" % [
			CasinoVault.ARC_SEGMENTS * CasinoVault.PANES_PER_BAY, lanes])
		check(highest <= float(arch["crown"]) + 1.5, "the roof stays under its crown (%.1f m)" % highest)
		_girders_and_fans(skin, wall, arch, lanes)
	# The iron of the walls is the iron_colors export, whatever sets it (a .tres included).
	var recoloured := CasinoSkin.new()
	recoloured.iron_colors = PackedColorArray([Color(0.1, 0.1, 0.1)])
	check(recoloured.stucco_colors == recoloured.iron_colors and skin.stucco_colors == skin.iron_colors,
		"the walls take the iron_colors export: stucco_colors follows it")
	# The roof builds the same for any piece of the left wall (a wall gap's part builds its own bays), and
	# bays are never built twice: two halves make what the whole makes.
	var geo5 := TrackGeometry.new(5, tuning)
	var whole := MeshBatch.new()
	skin.vault().build(whole, geo5.wall_x(), 0.0, 240.0)
	var parts := MeshBatch.new()
	skin.vault().build(parts, geo5.wall_x(), 0.0, 100.0)
	skin.vault().build(parts, geo5.wall_x(), 100.0, 240.0)
	var springers: int = 4
	check(absi(whole.vertex_count() - parts.vertex_count()) <= springers * 36 and parts.vertex_count() > 0,
		"the roof over a stretch is the roof over its pieces (%d vs %d vertices)" % [whole.vertex_count(), parts.vertex_count()])


## What hangs from the roof reaches what it hangs between: every girder under the eave runs from one wall
## face to the other (the roof there is as wide as the street, and a girder that ends short floats in the air),
## and a ceiling fan's blades stay inside the glass, at 3, 5 and 6 lanes.
func _girders_and_fans(skin: CasinoSkin, wall: float, arch: Dictionary, lanes: int) -> void:
	var vault: CasinoVault = skin.vault()
	var length: float = skin.bay_length
	var girders: int = 0
	var short: PackedStringArray = []
	for k: int in 300:
		var girder: Dictionary = vault.girder_of(arch, k)
		if girder.is_empty():
			continue
		girders += 1
		var beam_y: float = girder["y"]
		if beam_y + 0.3 > skin.eave_height:
			continue
		# Build its bay alone and read the girder's ends off the mesh: its box is 0.42 m tall about beam_y.
		var batch := MeshBatch.new()
		vault.build(batch, wall, float(k) * length, float(k + 1) * length)
		var mesh: ArrayMesh = batch.to_mesh()
		var reach_left: float = 0.0
		var reach_right: float = 0.0
		for s: int in mesh.get_surface_count():
			if mesh.surface_get_material(s) != skin.solid_material():
				continue
			for v: Vector3 in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				if absf(v.y - beam_y) < 0.215:
					reach_left = maxf(reach_left, -v.x)
					reach_right = maxf(reach_right, v.x)
		if reach_left < wall - 0.01 or reach_right < wall - 0.01:
			short.append("bay %d reaches %.2f / %.2f of %.2f" % [k, reach_left, reach_right, wall])
	check(girders >= 5, "girders cross the street at %d lanes (%d in 300 bays)" % [lanes, girders])
	check(short.is_empty(), "every girder under the eave runs from wall to wall at %d lanes: %s" % [lanes,
		", ".join(short.slice(0, 3))])
	var fans: int = 0
	var poking: PackedStringArray = []
	for k: int in 2000:
		var fan: Dictionary = vault.fan_of(arch, k)
		if fan.is_empty():
			continue
		fans += 1
		var at: Vector3 = fan["at"]
		# The blades' tips (their tops are 0.18 m under the hub) and the rod's top against the glass itself.
		var tips: float = CasinoVault.glass_at(arch, absf(at.x) + CasinoVault.FAN_RADIUS)
		var top: float = CasinoVault.glass_at(arch, at.x)
		if tips < at.y - 0.18 + 0.1 or top < at.y + CasinoVault.FAN_DROP - 0.03:
			poking.append("bay %d (x %.2f)" % [k, at.x])
	check(fans > 100, "ceiling fans hang at %d lanes (%d in 2000 bays)" % [lanes, fans])
	check(poking.is_empty(), "no fan's blades or rod reach the glass at %d lanes: %s" % [lanes, ", ".join(poking.slice(0, 3))])


## The arena's skin (The House is 13.5 m tall, GDD §10): its facades are flush through to 14.4 m (no
## balcony, pipe, unit, blade sign or halo sticks out of a wall below that: the machine fills the street to
## 35 cm off the walls), nothing hangs from its roof, and the roof is above the phase-3 billboard's whole drop
## (it comes down from 26 m over its 6 m ceiling), over the widest and the narrowest street.
func _arena(skin: CasinoSkin, arena: CasinoSkin) -> void:
	if arena == null:
		check(false, "the arena skin loads")
		return
	check(arena.bunting_height >= 25.0, "the arena strings nothing low over the street (%.1f m)" % arena.bunting_height)
	check(arena.overhang_min_height >= ARENA_CLEARANCE, "and its facades are flush up to %.1f m" % arena.overhang_min_height)
	check(not arena.hangings and skin.hangings, "the arena hangs nothing from its roof (the billboard drops through the space)")
	check(skin.overhang_min_height >= 10.0 and skin.overhang_min_height >= skin.decor_min_height,
		"the Casino's own overhangs start no lower than the arrival flyover's 10 m (%.1f m)" % skin.overhang_min_height)
	# The faces are flush below the overhang line, the street's as much as the arena's: nothing, glow and the
	# feed included, stands more than 30 cm out of a face below it.
	_flush_below(arena, ARENA_CLEARANCE, "the arena's")
	_flush_below(skin, skin.overhang_min_height - 0.1, "the street's")
	# The arena's roof, over the lanes: nothing below the machine's top (its springing is above it too).
	var geo6 := TrackGeometry.new(6, tuning)
	var roof := MeshBatch.new()
	arena.vault().build(roof, geo6.wall_x(), 0.0, 400.0)
	var mesh: ArrayMesh = roof.to_mesh()
	var lowest: float = INF
	var panes: int = 0
	for s: int in mesh.get_surface_count():
		if mesh.surface_get_material(s) == arena.glow_material():
			continue
		var arrays: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		for i: int in verts.size():
			lowest = minf(lowest, verts[i].y)
			panes += 1 if roundi(uv2[i].x) == MeshKit.PAT_CASINO_VAULT else 0
	check(panes == roundi(400.0 / arena.bay_length) * CasinoVault.ARC_SEGMENTS * CasinoVault.PANES_PER_BAY * 6,
		"the arena's roof is whole too (%d pane vertices)" % panes)
	check(lowest >= arena.eave_height - 0.7 and arena.eave_height - 0.7 > ARENA_CLEARANCE,
		"the arena's roof, and anything hung from it, starts above The House's top and the 14.4 m limit (lowest %.2f m)" % lowest)
	for lanes: int in [3, 5, 6]:
		_billboard_clear(arena, lanes)


## No vertex of the facades on `skin` stands more than 30 cm out of a wall face between the floor and
## `limit` (both walls, 400 m), whatever material it is.
func _flush_below(skin: CasinoSkin, limit: float, label: String) -> void:
	var geo := TrackGeometry.new(6, tuning)
	var wall: float = geo.wall_x()
	var intrusions: PackedStringArray = []
	var vertices: int = 0
	for side: int in [-1, 1]:
		var batch := MeshBatch.new()
		skin.facades().build(batch, side, side * wall, 0.0, 400.0)
		var walls: ArrayMesh = batch.to_mesh()
		for s: int in walls.get_surface_count():
			for v: Vector3 in walls.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				vertices += 1
				# How far the point stands out of the face toward the lanes.
				var out: float = wall - absf(v.x)
				if v.y > 0.06 and v.y < limit and out > 0.3 and intrusions.size() < 4:
					intrusions.append("%s (%.2f m out of the face)" % [v, out])
	check(vertices > 0 and intrusions.is_empty(), "%s facades keep everything within 0.3 m of the wall below %.1f m: %s" % [
		label, limit, ", ".join(intrusions)])


## The billboard that drops over the lanes in The House's phase 3 (TheHouseCeiling: a slab DROP_FROM over
## the ceiling, a sign on its middle, pods on its top) passes nothing: the arena's roof is above its top at
## the start of the drop, across the board's whole width (the arch's inside less the ribs' thickness, or the
## springer beams' underside under the eave), with 20 cm to spare.
func _billboard_clear(arena: CasinoSkin, lanes: int) -> void:
	var geo := TrackGeometry.new(lanes, tuning)
	var arch: Dictionary = arena.vault().arch_of(geo.wall_x())
	var eave: float = arena.eave_height
	var half: float = geo.half_width() + geo.wall_margin * 0.6
	var top: float = tuning.ceiling_height + TheHouseCeiling.DROP_FROM + TheHouseCeiling.SLAB
	var sign_half: float = minf(half * 1.2, 6.0) * 0.5 + 0.15
	var least: float = INF
	var at: float = 0.0
	var x: float = -half
	while x <= half:
		var need: float = top
		if absf(x) <= sign_half:
			need += 2.5
		elif absf(absf(x) - half * 0.6) <= 0.7:
			need += 0.5
		# Above the circle's middle the glass and its ribs are the circle's rim; at the walls, the springer
		# beams hang 0.45 m under the eave (the lower half of the circle is not built).
		var clear: float = INF
		if need >= float(arch["cy"]):
			clear = float(arch["rho"]) - Vector2(x, need - float(arch["cy"])).length() - 0.3
		if absf(x) > geo.wall_x() - 0.45:
			clear = minf(clear, eave - 0.45 - need)
		if clear < least:
			least = clear
			at = x
		x += 0.1
	check(least >= 0.2, "the House's billboard (%.1f m at the start of its drop) passes under the arena's roof at %d lanes (least clearance %.2f m at x %.1f)" % [
		top + 2.5, lanes, least, at])


## The named casinos' lettering (task K3; the owner, October 9, 2026: the big signs spell "Gasket's House of
## Chance" and "The Brass Lotus" in real letters): the owner's two names and no others, in the repo's own
## OFL font, as plain triangles in the chunk's solid layer (no node, no surface of their own); every casino
## with a big sign carries one of them, by hash, on a tall blade sign at one end and on its sign (Gasket's as
## a strip over a feed sign, which the Brass Lotus's lacks); warm white, never a hazard hue; never below
## decor_min_height (the blades above overhang_min_height, so the arena's flush-below-14.5 m rule holds);
## every other sign keeps its glyph rows and no sign says "HAZARD"; what they add to a chunk stays small.
func _lettering(skin: CasinoSkin, arena: CasinoSkin) -> void:
	check(CasinoLettering.NAMES == ["GASKET'S HOUSE OF CHANCE", "THE BRASS LOTUS"],
		"the two names are the owner's: Gasket's House of Chance and The Brass Lotus")
	var says_hazard: bool = false
	for n: String in CasinoLettering.NAMES:
		says_hazard = says_hazard or n.to_upper().contains("HAZARD")
	check(not says_hazard, "and neither says HAZARD")
	var licences: String = FileAccess.get_file_as_string("res://assets/LICENSES.md")
	check(CasinoLettering.FONT_PATH.begins_with("res://assets/fonts/exo2/") and ResourceLoader.exists(CasinoLettering.FONT_PATH)
		and licences.contains("assets/fonts/exo2/Exo2[wght].ttf"),
		"the letters are the project's own Exo 2, whose OFL licence is recorded in assets/LICENSES.md")
	# Every layout is triangles in one plane, wound clockwise seen from the front (the kit's front faces).
	var big_layouts: bool = true
	var sizes: PackedStringArray = []
	for layout: int in CasinoLettering.Layout.values():
		var l: MeshLayer = CasinoLettering.layer(layout, skin.lettering_color, skin.lettering_glow)
		var ok: bool = l.size() > 0 and l.size() % 3 == 0 and CasinoLettering.layout_size(layout).x > 0.0
		for i: int in range(0, l.size(), 3):
			var a: Vector3 = l.verts[i]
			var b: Vector3 = l.verts[i + 1]
			var c: Vector3 = l.verts[i + 2]
			ok = ok and is_zero_approx(a.z) and (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x) <= 0.0
		big_layouts = big_layouts and ok and l.size() <= MAX_LAYOUT_VERTICES
		sizes.append("%s %d" % [CasinoLettering.Layout.keys()[layout], l.size()])
	check(big_layouts, "every layout is flat clockwise triangles, each at most %d vertices (%s)" % [MAX_LAYOUT_VERTICES,
		", ".join(sizes)])
	var colours_ok: bool = not _hazard_hue(skin.lettering_color) and _chroma(skin.lettering_color) <= MAX_SURFACE_CHROMA \
		and skin.lettering_color.s < GLOW_SATURATION_LIMIT and skin.lettering_color.v > 0.8
	check(colours_ok, "the lettering is warm white, no hazard hue and well below the hazards' saturation (%s)" % skin.lettering_color)
	var per_append: int = 0
	var letters: MeshLayer = CasinoLettering.layer(CasinoLettering.Layout.GASKETS_BOARD, skin.lettering_color, skin.lettering_glow)
	var t0: int = Time.get_ticks_usec()
	for i: int in 200:
		var into := MeshLayer.new()
		into.append(letters, Transform3D(Basis.from_scale(Vector3(1.3, 1.3, 1.3)), Vector3(1, 2, 3)))
	per_append = (Time.get_ticks_usec() - t0) / 200
	print("  casino lettering: a Gasket's board is %d vertices and %d us to place" % [letters.size(), per_append])
	check(per_append < 400, "placing a sign's letters is a bulk append of a cached layout (%d us, at most 400)" % per_append)
	for variant: Array in [[skin, "the street's"], [arena, "the arena's"]]:
		_lettering_on_walls(variant[0] as CasinoSkin, variant[1] as String)


## The lettering over a long street of one skin: where the facades say it goes (named_signs()) is exactly
## where the built walls have it, nothing else is lettered, and every rule above holds.
func _lettering_on_walls(skin: CasinoSkin, label: String) -> void:
	var geo := TrackGeometry.new(6, tuning)
	var wall: float = geo.wall_x()
	var facades: CasinoFacades = skin.facades() as CasinoFacades
	var lot: float = skin.lot_length
	var colour := Color(skin.lettering_color, skin.lettering_glow)
	var counts: Dictionary = {}
	var kinds: Dictionary = {}
	var expected_vertices: int = 0
	var found_vertices: int = 0
	var chunk_most: int = 0
	var low_y: float = INF
	var low_blade: float = INF
	var misplaced: PackedStringArray = []
	var casinos: int = 0
	var carrying: int = 0
	var wrong_name: int = 0
	var d: float = 0.0
	while d < STREET_LENGTH:
		for side: int in [-1, 1]:
			var pieces: Array[Dictionary] = facades.named_signs(side, side * wall, d, d + 40.0)
			var batch := MeshBatch.new()
			facades.build(batch, side, side * wall, d, d + 40.0)
			var layer: MeshLayer = batch.layer(skin.solid_material())
			var verts := PackedVector3Array()
			for i: int in layer.size():
				var c: Color = layer.colors[i]
				if layer.uv2s[i].x == float(MeshKit.PAT_PLAIN) and absf(c.r - colour.r) < 0.002 and absf(c.g - colour.g) < 0.002 \
						and absf(c.b - colour.b) < 0.002 and absf(c.a - colour.a) < 0.002:
					verts.append(layer.verts[i])
			found_vertices += verts.size()
			chunk_most = maxi(chunk_most, verts.size())
			var chunk_expected: int = 0
			for piece: Dictionary in pieces:
				var name_id: int = piece["name"]
				counts[name_id] = int(counts.get(name_id, 0)) + 1
				var kind: String = String(piece["kind"])
				kinds[kind] = int(kinds.get(kind, 0)) + 1
				chunk_expected += CasinoLettering.vertex_count(piece["layout"])
				low_y = minf(low_y, float(piece["y_min"]))
				if piece["kind"] == &"blade":
					low_blade = minf(low_blade, float(piece["board_y0"]))
				# Its letters are where it says: the block's box in the plane of the wall (or the blade's).
				var centre: Vector3 = piece["center"]
				var box: Vector2 = piece["box"]
				var inside: int = 0
				var blade: bool = piece["kind"] == &"blade"
				for v: Vector3 in verts:
					# A board's letters lie in the wall's plane (along z); a blade's face the player (across x).
					var in_plane: bool = absf(v.z - centre.z) <= 0.03 if blade else absf(v.x - centre.x) <= 0.01
					var in_width: bool = absf(v.x - centre.x) <= box.x * 0.5 + 0.01 if blade else absf(v.z - centre.z) <= box.x * 0.5 + 0.01
					if in_plane and in_width and absf(v.y - centre.y) <= box.y * 0.5 + 0.01:
						inside += 1
				if inside < CasinoLettering.vertex_count(piece["layout"]):
					misplaced.append("%s at %.1f (%d of %d)" % [kind, float(piece["at"]), inside, CasinoLettering.vertex_count(piece["layout"])])
			expected_vertices += chunk_expected
			# The casinos of this stretch: each with a big sign carries one blade and the name by hash.
			var lo: float = d
			var span: Vector2i = MeshKit.lot_run(side, floori(lo / lot), 0.45, 3, 3)
			while span.x * lot < d + 40.0:
				var b: MarketFacades.Building = facades.building(side, span)
				var mid: float = (b.b0 + b.b1) * 0.5
				var spec: Dictionary = facades._casino_sign(b, side * wall)
				if b.kind == MarketFacades.Kind.CASINO and not spec.is_empty() and mid >= d and mid < d + 40.0:
					casinos += 1
					var mine: Array[Dictionary] = []
					for piece: Dictionary in facades.named_signs(side, side * wall, b.b0 - 2.0, b.b1 + 2.0):
						if absf((piece["center"] as Vector3).z + mid) < (b.b1 - b.b0) * 0.5 + 0.01:
							mine.append(piece)
					var blades: int = 0
					for piece: Dictionary in mine:
						blades += 1 if piece["kind"] == &"blade" else 0
						wrong_name += 0 if int(piece["name"]) == CasinoLettering.pick(side, b.id) else 1
					carrying += 1 if blades == 1 and not mine.is_empty() else 0
				span = MeshKit.lot_run(side, span.y + 1, 0.45, 3, 3)
		d += 40.0
	var total: int = int(counts.get(0, 0)) + int(counts.get(1, 0))
	check(counts.size() == 2 and int(counts.get(0, 0)) >= 3 and int(counts.get(1, 0)) >= 3,
		"%s street has both names, and only those two (Gasket's %d pieces, the Brass Lotus %d)" % [label, int(counts.get(0, 0)), int(counts.get(1, 0))])
	check(casinos > 5 and carrying == casinos and wrong_name == 0,
		"%s every casino with a big sign carries its hash's name on a blade (%d of %d)" % [label, carrying, casinos])
	check(found_vertices == expected_vertices and total > 0,
		"%s walls have letters exactly where the facades place them and nowhere else (%d vertices, %d expected)" % [
			label, found_vertices, expected_vertices])
	check(misplaced.is_empty(), "%s letters sit inside their sign's box: %s" % [label, ", ".join(misplaced.slice(0, 3))])
	check(low_y >= skin.decor_min_height and low_blade >= skin.overhang_min_height,
		"%s letters are never below decor_min_height (%.1f m, lowest %.2f) and the blades start above overhang_min_height (%.1f m, lowest %.2f)" % [
			label, skin.decor_min_height, low_y, skin.overhang_min_height, low_blade])
	check(chunk_most <= MAX_LETTER_VERTICES,
		"%s a 40 m stretch of wall carries at most %d letter vertices (most %d; %d kinds %s)" % [label, MAX_LETTER_VERTICES, chunk_most,
			kinds.size(), kinds])


## The cult's emblem (GDD §5): the owner's choice, never hardcoded, in its scheme's warm-white neon or
## unlit bronze; over a long street it turns up on the signs, each at least emblem_min_size across (smaller,
## its three-fold shape could read like the radiation trefoil) and small beside its sign.
func _cult_emblem(skin: CasinoSkin) -> void:
	var choice := load(MarketplaceSkin.CULT_EMBLEM_CHOICE_PATH) as CultEmblemChoice
	check(choice != null, "the cult emblem choice loads")
	if choice == null:
		return
	var scheme: Dictionary = CultEmblem.default_scheme(choice.option)
	var reference: ArrayMesh = CultEmblem.build_mesh(choice.option, 1.0, Color.WHITE, Color.WHITE, 0.0,
		skin.solid_material())
	var count: int = reference.surface_get_array_len(0)
	var neon: MeshLayer = skin.cult_emblem(true)
	check(neon.size() == count and neon.verts == reference.surface_get_arrays(0)[Mesh.ARRAY_VERTEX],
		"the skin draws the chosen emblem's geometry (option %s)" % CultEmblem.option_letter(choice.option))
	# Find every emblem over 3 km of both walls and on every sign gantry's face.
	var unit: float = maxf(reference.get_aabb().size.x, reference.get_aabb().size.y)
	var sizes: Array[float] = []
	var lit: int = 0
	var layers: Array[MeshLayer] = []
	for side: int in [-1, 1]:
		var d: float = 0.0
		while d < 3000.0:
			var batch := MeshBatch.new()
			skin.facades().build(batch, side, side * 6.3, d, d + 40.0)
			layers.append(batch.layer(skin.solid_material()))
			d += 40.0
	for variant: int in 24:
		var mesh: ArrayMesh = skin.casino_ceilings().mesh_for(CasinoCeilings.Kind.SIGN, variant, Vector3(12.0, 0.8, 40.0), [], 0.0,
			6.3, 6.0)
		var sign_layer := MeshLayer.new()
		for s: int in mesh.get_surface_count():
			if mesh.surface_get_material(s) == skin.solid_material():
				var arrays: Array = mesh.surface_get_arrays(s)
				sign_layer.verts = arrays[Mesh.ARRAY_VERTEX]
				sign_layer.colors = arrays[Mesh.ARRAY_COLOR]
		layers.append(sign_layer)
	for layer: MeshLayer in layers:
		var i: int = 0
		while i + count <= layer.size():
			var c: Color = layer.colors[i]
			var is_neon: bool = _same_rgb(c, scheme["neon"]) or _same_rgb(c, scheme["neon_accent"])
			var is_bronze: bool = _same_rgb(c, scheme["metal"]) or _same_rgb(c, scheme["metal_accent"])
			if not is_neon and not is_bronze:
				i += 1
				continue
			var box := AABB(layer.verts[i], Vector3.ZERO)
			for j: int in count:
				box = box.expand(layer.verts[i + j])
			sizes.append(maxf(box.size.y, maxf(box.size.x, box.size.z)) / unit)
			lit += 1
			i += count
	check(lit > 0, "the emblem hides on the casino's signs: %d lit over 3 km and the sign gantries" % lit)
	var smallest: float = INF
	var largest: float = 0.0
	for size: float in sizes:
		smallest = minf(smallest, size)
		largest = maxf(largest, size)
	check(sizes.is_empty() or (smallest >= skin.emblem_min_size - 0.01 and largest <= 1.6),
		"each emblem is %.2f-%.2f m across: never below %.2f m, never a centrepiece" % [smallest, largest, skin.emblem_min_size])


## The cult's feed (CultFeed, GDD §5 "Cyborg Viewing Devices") plays in the Casino alongside the ordinary
## signs: on billboards and sign gantries high up, and on TVs inside some shop windows, all with the one
## shared feed material, and nowhere else (never on the wall-run band's faces, never over the lanes below
## the ceilings). Checked over a whole level.
func _cult_feed(skin: CasinoSkin) -> void:
	check(skin.feed_material() == CultFeed.material(), "the casino plays the shared feed")
	var geo := TrackGeometry.new(5, tuning)
	var wall: float = geo.wall_x()
	var boards: int = 0
	var tvs: int = 0
	for side: int in [-1, 1]:
		var found: Array[Dictionary] = skin.feed_boards(side, side * wall, 0.0, 3000.0)
		boards += found.size()
		for b: Dictionary in found:
			check(float((b["center"] as Vector3).y) - float(b["height"]) * 0.5 >= skin.decor_min_height - 0.01,
				"a feed billboard stays above decor_min_height")
		for w: Dictionary in skin.shop_windows(side, side * wall, 0.0, 3000.0):
			if w["screen"]:
				tvs += 1
	check(boards > 0 and tvs > 0, "over 3 km the feed plays on %d billboards and %d shop-window TVs" % [boards, tvs])
	var layout: LevelLayout = level(CASINO_LEVEL_PATH, 5, 0.6, 5)
	var world := Node3D.new()
	tree.root.add_child(world)
	var track := TrackBuilder.new()
	world.add_child(track)
	track.set_layout(layout, tuning, skin)
	var seen: Dictionary = {}
	var shown := {"display": 0, "high": 0}
	var bad: PackedStringArray = []
	var d: float = 0.0
	while d <= layout.length:
		track.update(d, d / tuning.run_speed)
		for chunk: Node in track.get_children():
			if seen.has(chunk):
				continue
			seen[chunk] = true
			for node: Node in nodes_of(chunk, func(n: Node) -> bool: return n is MeshInstance3D):
				var m := node as MeshInstance3D
				for s: int in m.mesh.get_surface_count() if m.mesh != null else 0:
					if m.mesh.surface_get_material(s) != skin.feed_material():
						continue
					var verts: PackedVector3Array = m.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
					for i: int in range(0, verts.size(), 6):
						var p: Vector3 = m.global_transform * ((verts[i] + verts[i + 2]) * 0.5)
						var inside: float = absf(p.x) - wall
						if inside > 0.05 and inside < skin.shop_depth and p.y > skin.gallery_bottom and p.y < skin.gallery_top:
							shown["display"] += 1
						elif p.y >= skin.decor_min_height:
							shown["high"] += 1
						elif bad.size() < 4:
							bad.append(str(p))
		d += TrackBuilder.CHUNK_LENGTH
	check(bad.is_empty() and shown["display"] > 0 and shown["high"] > 0,
		"the feed plays only high up (%d screens) and inside shop windows (%d TVs): %s" % [shown["high"], shown["display"],
		", ".join(bad)])
	world.queue_free()
	await tree.process_frame


func _under(node: Node, test: Callable) -> bool:
	var parent: Node = node.get_parent()
	while parent != null:
		if test.call(parent):
			return true
		parent = parent.get_parent()
	return false


static func _chroma(c: Color) -> float:
	return maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))


## A saturated colour outside the decorative blue-to-violet band: pink, red, orange, yellow, green or cyan
## (GDD §5: those glow only on hazards).
static func _hazard_hue(c: Color) -> bool:
	if c.s < GLOW_SATURATION_LIMIT:
		return false
	return c.h < 0.58 or c.h > 0.8


static func _same_rgb(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01


## Relative luminance of an sRGB colour, in linear light.
static func _linear_luminance(c: Color) -> float:
	var l: Color = c.srgb_to_linear()
	return 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b


## Whether `c` could pass for `target` (a saturated hazard colour): close in RGB, or as saturated and within
## 25 degrees of its hue.
static func _near_colour(c: Color, target: Color) -> bool:
	var dr: float = c.r - target.r
	var dg: float = c.g - target.g
	var db: float = c.b - target.b
	if sqrt(dr * dr + dg * dg + db * db) < 0.35:
		return true
	var dh: float = absf(c.h - target.h)
	return c.s > 0.5 and minf(dh, 1.0 - dh) < 25.0 / 360.0

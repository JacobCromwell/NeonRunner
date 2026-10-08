extends SkinSuite
## The Dead Zone skin (DeadZoneSkin, Zone 5), which the Dead Zone uses. The shared skin checks
## (SkinSuite) over the whole of Dead Zone 1 for 3, 5 and 6 lanes, then the zone's own:
## - its cyborgs are the base, burned out (GDD §9.2);
## - the palette (GDD §5): dark black, dark grey and ash grey, every surface a near-neutral grey far
##   below the hazards' saturation; the distance fades into ash grey many times lighter than the Bad
##   Dream's black body, so its silhouette reads against it; the embers stay dim, below the bloom
##   threshold and far dimmer than a gap edge; colours reach the shaders as sRGB Vector3s (D6a's rule);
## - gaps read as holes, at 3 and at 5 lanes: below the street only deep shade far darker than the
##   street can be drawn, and nothing in it glows but the orange edge; both edges of a gap carry the
##   orange edge, and the far one its halo;
## - the colour rule: nothing glows but hazards, triggers, the orange edges and ends, the rare embers
##   high up and the cult's feed;
## - the play space stays clear, nothing sticks out of the walls through the wall-run band, and nothing
##   glows on the walls there;
## - every kind of ceiling builds from the lanes it covers (task B3) on streets of 3, 5 and 6 lanes,
##   full width or narrow, against a wall or in mid-street: a bridge or a dead building across every
##   lane, a slab broken off a tower against one wall, a collapsed span in mid-street;
## - the cult: its emblem is the owner's choice, scorched and never glowing, big enough, high on the
##   walls, where cult_emblems() says; its feed plays on a few surviving screens with the shared
##   material, dim, untinted, far above the band, where feed_boards() says;
## - the still street carries ash, smoke and speed streaks; smoke rises from some ruins, far above;
## - a level's darker lighting reaches the skin's own smoke shader.

const DZ_SKIN_PATH: String = "res://data/skins/dead_zone_skin.tres"
const DZ_ZONE_PATH: String = "res://data/zones/dead_zone.tres"
## The Dead Zone's campaign level with the most in it (hosts and the Bad Dream arrive in it).
const DZ_LEVEL_PATH: String = "res://data/levels/dead_zone_1.tres"
## Every lit surface is a near-neutral grey: at most this chroma (brightest minus darkest channel).
const MAX_SURFACE_CHROMA: float = 0.04
## A glowing colour this saturated (HSV) must keep to the decorative hues (blue to violet).
const GLOW_SATURATION_LIMIT: float = 0.35
## Gaps: the street's lowest broad shading factor (kit_dead_zone.gdshaderinc, dz_street: the plates'
## tone, the burn marks and the rubble spills; the ash only lightens it), PAT_DZ_UNDER's brightest
## factor, and how much darker than the darkest street a gap's inside must stay (linear luminance).
const STREET_SHADE_MIN: float = 0.7
const UNDER_MAX_FACTOR: float = 1.0
## (Task H3, GDD §9.9: a hole shows the ruined basements and the void's rubble, dim but recognisable: its
## brightest colour (PAT_DZ_UNDER's factors never pass 1) may reach this share of the darkest street at its
## darkest shading, where it used to be 0.35. The street is the darkest of the zones' floors, so the share is
## the highest of them, and what is drawn is dimmer still: the patterns darken the colour.)
const GAP_CONTRAST: float = 1.3
## The showcase track's gap (SkinSuite.showcase_track): lane 3 of 5, 50-57 m.
const GAP_LANE := Vector2(1.2, 3.6)
const GAP := Vector2(50.0, 57.0)


func run() -> void:
	var skin := load(DZ_SKIN_PATH) as DeadZoneSkin
	check(skin != null, "the dead zone skin loads")
	if skin == null:
		return
	var zone := load(DZ_ZONE_PATH) as ZoneDef
	check(zone != null and zone.skin is DeadZoneSkin, "the Dead Zone uses the dead zone skin")
	check(skin.enemy_variant == &"burned" and DeadZoneSkin.new().enemy_variant == &"burned"
		and CyborgSuit.look_for(skin.enemy_variant) == CyborgSuit.BURNED, "dead zone cyborgs are the base, burned out")
	start_error_count()
	var env: Environment = skin.make_environment()
	check(env != null and env.sky != null and env.glow_enabled and env.fog_enabled,
		"the dead zone environment has a sky, glow and fog")
	_palette(skin, env)
	_shaders(skin)
	for lanes: int in [3, 5, 6]:
		await whole_level(skin, "dead zone", DZ_LEVEL_PATH, lanes)
	await hazards_and_triggers(skin)
	await _surfaces(skin)
	await _gaps(skin)
	await _clear_play_space(skin)
	_ceilings(skin)
	await _cult_emblem(skin)
	await _cult_feed(skin)
	await determinism(skin, DZ_LEVEL_PATH)
	doodads_ok(skin, "dead zone")
	stop_error_count("building dead zone levels")


## Dark black, dark grey and ash grey (GDD §5) before anything is built: every surface a near-neutral
## grey, none brighter than the ash, the hazards far more saturated than any of them; the distance
## fading into an ash grey lighter than the ruins and far lighter than the Bad Dream's black body; the
## embers dim.
func _palette(skin: DeadZoneSkin, env: Environment) -> void:
	var lit: Array[Color] = [skin.road_color, skin.gutter_color, skin.lane_marking_color, skin.rubble_color, skin.ash_color,
		skin.soot_color, skin.board_color, skin.glass_color, skin.steel_color, skin.dead_neon_color, skin.bridge_color,
		skin.slab_color, skin.seam_color, skin.wreck_color, skin.post_color, skin.trigger_metal_color, skin.wall_mark_color,
		skin.gap_inside_color, skin.ash_flake_color, skin.smoke_puff_color, skin.streak_color, skin.plume_color,
		skin.sky_zenith_color, skin.sky_horizon_color, skin.haze_color, skin.fog_color, skin.skyline_color, skin.smoke_color]
	for list: PackedColorArray in [skin.facade_colors, skin.board_colors, skin.sign_content_colors]:
		lit.append_array(Array(list))
	var off: PackedStringArray = []
	for c: Color in lit:
		if _chroma(c) > MAX_SURFACE_CHROMA:
			off.append(str(c))
	check(off.is_empty(), "every surface is a near-neutral grey: %s" % ", ".join(off))
	# Dark black, dark grey and ash grey: no surface paler than a light ash (the drifting flakes and
	# streaks aside, which are specks).
	var pale: PackedStringArray = []
	for c: Color in lit:
		if c != skin.ash_flake_color and c != skin.streak_color and c.v > 0.55:
			pale.append(str(c))
	check(pale.is_empty(), "no surface is paler than a light ash grey: %s" % ", ".join(pale))
	for hazard: Color in [skin.fence_color, skin.sign_frame_color, skin.gap_edge_color, skin.pad_color, skin.ramp_color,
			skin.speed_pad_color]:
		check(_chroma(hazard) > 0.5, "hazard colour %s is far more saturated than anything in the zone" % hazard)
	# The distance: an ash grey lighter than any facade as the kit shades a wall across the street, and
	# far lighter than the Bad Dream's black body.
	var fog: float = _linear_luminance(env.fog_light_color)
	var darker: PackedStringArray = []
	for c: Color in skin.facade_colors:
		if _linear_luminance(c * Color(0.72, 0.72, 0.72)) >= fog:
			darker.append(str(c))
	check(darker.is_empty(), "the distance fades into a grey lighter than the ruins' faces: %s" % ", ".join(darker))
	check(fog > 10.0 * _linear_luminance(BadDreamModel.BLACK),
		"the distance is far lighter than the Bad Dream's black body, so its silhouette reads (%.4f)" % fog)
	# The embers: dim (below the bloom threshold), far dimmer than a gap edge, far above the play field.
	var ember_peak: float = _max_linear(skin.ember_color) * skin.ember_glow * skin.emissive_scale
	var edge_peak: float = _max_linear(skin.gap_edge_color) * DeadStreet.LIP_GLOW * skin.emissive_scale
	check(ember_peak < skin.glow_threshold and ember_peak < edge_peak / 3.0,
		"the embers glow dimly (%.2f), below the bloom threshold and far below a gap edge (%.2f)" % [ember_peak, edge_peak])
	check(skin.ember_min_height >= 12.0 and skin.ember_share <= 0.1 and skin.smoulder_share <= 0.5,
		"the embers are few and far above the play field (%.1f m)" % skin.ember_min_height)
	check(skin.distant_fire_color.v < 0.4, "the fires in the smoke over the horizon are dim (%s)" % skin.distant_fire_color)


## The skin's shaders: its patterns in their own include (ids 40-49) with one include and one dispatch
## line in the kit's solid shader; colours reach them as sRGB Vector3s, as D6a's rule has it, so both
## renderers match; the smoke's shader dims with a level's darker lighting like the rest of the scenery.
func _shaders(skin: DeadZoneSkin) -> void:
	var code: String = skin.solid_material().shader.code
	check(code.count("#include \"res://scripts/world/meshes/shaders/kit_dead_zone.gdshaderinc\"") == 1
		and code.count("dz_surface(") == 1, "the Dead Zone's patterns are one include and one dispatch in the kit's solid shader")
	for id: int in [MeshKit.PAT_DZ_STREET, MeshKit.PAT_DZ_UNDER, MeshKit.PAT_DZ_TOWER, MeshKit.PAT_DZ_CONCRETE,
			MeshKit.PAT_DZ_STEEL, MeshKit.PAT_DZ_BOARD, MeshKit.PAT_DZ_MARK]:
		check(id >= 40 and id < 50, "pattern %d is in the Dead Zone's block of ids" % id)
	var m: ShaderMaterial = skin.solid_material()
	var vectors: PackedStringArray = []
	for u: String in ["sheen_color", "dz_ash", "dz_soot", "dz_board", "dz_line", "dz_rubble", "dz_glass", "dz_ember"]:
		if not m.get_shader_parameter(u) is Vector3:
			vectors.append(u)
	var sky := skin.make_environment().sky.sky_material as ShaderMaterial
	for u: String in ["zenith_color", "horizon_color", "haze_color", "fire_color"]:
		if not sky.get_shader_parameter(u) is Vector3:
			vectors.append(u)
	check(vectors.is_empty(), "shader colours are sRGB Vector3s, the same on both renderers: %s" % ", ".join(vectors))
	var smoke: String = skin.smoke_material().shader.code
	check(smoke.contains("global uniform float scenery_light;") and smoke.contains("light_factor(scenery_light)"),
		"the smoke rising from the ruins dims with a level's darker lighting")
	check(skin.drift_material().shader == MeshKit.shader("drift.gdshader"), "the drifting ash and smoke use the kit's drift shader")


## Over the showcase track (every kind of piece): the gap in lane 3 (50-57 m) has the orange edge on
## both edges; nothing is vent-like; only hazard signs wear stripes; lit surfaces stay near-neutral; the
## still street carries ash, puffs of smoke and speed streaks. Then over a whole level: nothing glows
## but hazards, triggers, the orange edges and ends, the embers (only on tower faces, only high up) and
## the feed; smoke rises from some ruins, far above the play field.
func _surfaces(skin: DeadZoneSkin) -> void:
	var track: TrackBuilder = showcase_track(skin)
	var edges: Dictionary = {}
	var grilles: int = 0
	var stripes: int = 0
	var loud: PackedStringArray = []
	var kinds: Dictionary = {}
	var solid: Material = skin.solid_material()
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
				var pattern: int = roundi(uv2[i].x)
				grilles += int(pattern == MeshKit.PAT_GRILLE)
				stripes += int(pattern == MeshKit.PAT_STRIPES and not in_hazard)
				# The cult's emblem keeps its chosen scheme's unlit metal (checked in _cult_emblem()).
				if c.a == 0.0 and not in_hazard and pattern != MeshKit.PAT_DZ_MARK and _chroma(c) > MAX_SURFACE_CHROMA \
						and loud.size() < 4:
					loud.append("%s at %s" % [c, p])
				if c.a > 0.2 and _same_rgb(c, skin.gap_edge_color) and absf(p.y) < 0.01 and p.x > GAP_LANE.x - 0.01 \
						and p.x < GAP_LANE.y + 0.01:
					for edge: float in [GAP.x, GAP.y]:
						if absf(-p.z - edge) < 0.25:
							edges[edge] = true
	check(edges.has(GAP.x) and edges.has(GAP.y), "a gap keeps the orange edge glow on both of its edges (%s)" % [edges.keys()])
	check(grilles == 0, "nothing vent-like: no surface uses the grille pattern (%d vertices)" % grilles)
	check(stripes == 0, "only hazard signs wear the striped frame (%d striped vertices elsewhere)" % stripes)
	check(loud.is_empty(), "lit surfaces stay near-neutral greys: %s" % ", ".join(loud))
	check(kinds.has(MeshKit.DRIFT_ASH) and kinds.has(MeshKit.DRIFT_SMOKE) and kinds.has(MeshKit.DRIFT_STREAK),
		"the still street carries drifting ash, puffs of smoke and speed streaks (%s)" % [kinds.keys()])
	await free_track(track)
	var glows: PackedStringArray = []
	var embers: Array[int] = [0]
	var plumes: Array[float] = [INF]
	var count: Array[int] = [0]
	var layout: LevelLayout = level(DZ_LEVEL_PATH, 5, 0.6)
	await visit_level(layout, skin, func(m: MeshInstance3D, arrays: Array, material: Material) -> void:
		if under_hazard(m) or _under(m, func(n: Node) -> bool: return n is Area3D):
			return
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2] if arrays[Mesh.ARRAY_TEX_UV2] != null else PackedVector2Array()
		if material == skin.smoke_material():
			for v: Vector3 in verts:
				plumes[0] = minf(plumes[0], (m.global_transform * v).y)
				count[0] += 1
			return
		if material == skin.drift_material() or material == skin.feed_material():
			return
		for i: int in verts.size():
			var c: Color = colors[i]
			var glowing: bool = material == skin.glow_material() or (material == solid and c.a > 0.0)
			if not glowing or _same_rgb(c, skin.gap_edge_color):
				continue
			var p: Vector3 = m.global_transform * verts[i]
			# The finish gantry's checkers glow in every zone.
			if absf(-p.z - layout.length) < 2.0:
				continue
			var ember: bool = material == solid and roundi(uv2[i].x) == MeshKit.PAT_DZ_TOWER and c.a <= skin.ember_glow + 0.001 \
				and p.y >= skin.ember_min_height - 0.01
			embers[0] += int(ember)
			if not ember and glows.size() < 4:
				glows.append("%s pattern %d at %s" % [c, roundi(uv2[i].x) if not uv2.is_empty() else -1, p]))
	check(glows.is_empty(), "nothing glows but hazards, triggers, the orange edges and ends, the embers high up and the feed: %s" %
		", ".join(glows))
	check(embers[0] > 0, "some tower faces smoulder high up (%d vertices)" % embers[0])
	check(count[0] > 0 and plumes[0] > 12.0, "smoke rises from some ruins, far above the play field (%d vertices, lowest %.1f m)" % [
		count[0], plumes[0]])


## Gaps read as holes at a glance (CLAUDE.md readability rules): whatever a gap shows is deep shade far
## darker than the street can be drawn, and nothing in it glows but the orange edge; no floor is drawn
## in (or near) the edge's colour; the showcase gap carries the full orange edge on both sides (the
## lip on the street right at the collision edge, the strip along the top of its cut, and on the far
## side the halo). Checked over whole levels at 3 and 5 lanes: below the street there is nothing but
## the shade, the strips and the halo.
func _gaps(skin: DeadZoneSkin) -> void:
	var shade := Color(STREET_SHADE_MIN, STREET_SHADE_MIN, STREET_SHADE_MIN)
	var darkest: float = minf(_linear_luminance(skin.road_color * shade), _linear_luminance(skin.gutter_color * shade))
	var inside: float = _linear_luminance(skin.gap_inside_color * Color(UNDER_MAX_FACTOR, UNDER_MAX_FACTOR, UNDER_MAX_FACTOR))
	check(inside < darkest * GAP_CONTRAST, "a gap's inside stays far darker than the darkest street: %.4f vs %.4f" % [inside,
		darkest])
	var like_edge: PackedStringArray = []
	for c: Color in [skin.road_color, skin.gutter_color, skin.ash_color, skin.lane_marking_color, skin.rubble_color,
			skin.bridge_color, skin.slab_color, skin.seam_color]:
		if _near_colour(c, skin.gap_edge_color):
			like_edge.append(str(c))
	check(like_edge.is_empty(), "no floor or underside is drawn in the gap edge's colour: %s" % ", ".join(like_edge))
	var track: TrackBuilder = showcase_track(skin)
	var strip := Vector2(INF, -INF)
	var lip := Vector2(INF, -INF)
	var near_lip := Vector2(INF, -INF)
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
					if p.y < -0.001 and colors[i].a >= DeadStreet.STRIP_GLOW - 0.001:
						strip = Vector2(minf(strip.x, p.y), maxf(strip.y, p.y))
					elif absf(p.y) < 0.001 and colors[i].a >= DeadStreet.LIP_GLOW - 0.001:
						lip = Vector2(minf(lip.x, -p.z), maxf(lip.y, -p.z))
				elif absf(-p.z - GAP.x) <= 0.3 and absf(p.y) < 0.001 and colors[i].a >= DeadStreet.LIP_GLOW - 0.001:
					near_lip = Vector2(minf(near_lip.x, -p.z), maxf(near_lip.y, -p.z))
	check(strip.y - strip.x >= DeadStreet.STRIP_HEIGHT - 0.001 and strip.y > -0.05,
		"the far edge's orange strip runs along the top of its cut: %s" % strip)
	check(lip.x > GAP.y - 0.01 and lip.y - lip.x >= DeadStreet.EDGE_LIP - 0.001,
		"the far edge's orange lip lies on the street right at the collision edge: %s" % lip)
	check(near_lip.y < GAP.x + 0.01 and near_lip.y - near_lip.x >= DeadStreet.EDGE_LIP - 0.001,
		"the near edge's orange lip ends right at the collision edge: %s" % near_lip)
	check(halo, "the far edge carries its orange halo toward the approaching runner")
	await free_track(track)
	var limit: float = inside + 0.0001
	for lanes: int in [3, 5]:
		var layout: LevelLayout = level(DZ_LEVEL_PATH, lanes, 0.6, 9)
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
				# The finish gantry's posts stand on the street, where no gap ever is.
				if p.y >= -0.01 or absf(-p.z - layout.length) < 1.0:
					continue
				count[0] += 1
				var c: Color = colors[i]
				var fault: String = ""
				if material == skin.solid_material():
					var strip_edge: bool = _same_rgb(c, skin.gap_edge_color) and c.a >= DeadStreet.STRIP_GLOW - 0.001
					var dark: bool = roundi(uv2[i].x) == MeshKit.PAT_DZ_UNDER and c.a == 0.0 and _linear_luminance(c) <= limit
					if not strip_edge and not dark:
						fault = "%s pattern %d" % [c, roundi(uv2[i].x)]
				elif material == skin.glow_material():
					if not _same_rgb(c, skin.gap_edge_color):
						fault = "glow %s" % c
				else:
					fault = "material %s" % (material.resource_path.get_file() if material != null else "none")
				if fault != "" and bad.size() < 4:
					bad.append("%s at %s" % [fault, p]))
		check(bad.is_empty() and count[0] > 0, "below the street there is only deep shade and the orange edge (%d lanes, %d vertices): %s" % [
			lanes, count[0], ", ".join(bad)])


## Between the floor and the ceiling, over the lanes, the skin builds nothing solid but hazards and
## triggers, anywhere in a whole level; nothing sticks out of the walls through the wall-run band, and
## nothing on the walls glows or lights up below band_top.
func _clear_play_space(skin: DeadZoneSkin) -> void:
	for lanes: int in [3, 6]:
		var layout: LevelLayout = level(DZ_LEVEL_PATH, lanes, 0.6, 5)
		var geo := TrackGeometry.new(lanes, tuning)
		var half: float = geo.half_width()
		var wall: float = geo.wall_x()
		var band: float = minf(skin.band_top, tuning.ceiling_height - 0.1)
		var intruders: PackedStringArray = []
		var sticking: PackedStringArray = []
		var lit: PackedStringArray = []
		await visit_level(layout, skin, func(m: MeshInstance3D, arrays: Array, material: Material) -> void:
			if _under(m, func(n: Node) -> bool: return n is Area3D) or material == skin.drift_material() \
					or material == skin.smoke_material():
				return
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var additive: bool = material == skin.glow_material()
			# The walls' meshes sit at the chunk's origin; ceilings are placed instances.
			var on_walls: bool = m.position == Vector3.ZERO
			for i: int in verts.size():
				var p: Vector3 = m.global_transform * verts[i]
				var at_finish: bool = absf(-p.z - layout.length) < 1.0
				if not additive and absf(p.x) < half - 0.01 and p.y > 0.06 and p.y < tuning.ceiling_height - 0.1 and intruders.size() < 4:
					intruders.append(str(p))
				elif not additive and absf(p.x) >= half - 0.01 and absf(p.x) < wall - 0.05 and p.y > 0.06 and p.y < band \
						and not at_finish and sticking.size() < 4:
					sticking.append(str(p))
				var glowing: bool = additive or material == skin.feed_material() or (material == skin.solid_material() and colors[i].a > 0.0)
				if glowing and on_walls and absf(p.x) >= wall - 0.3 and p.y > 0.06 and p.y < skin.band_top and not at_finish \
						and not _same_rgb(colors[i], skin.gap_edge_color) and lit.size() < 4:
					lit.append("%s %s" % [colors[i], p]))
		check(intruders.is_empty(), "nothing decorative stands in the play space (%d lanes): %s" % [lanes, ", ".join(intruders)])
		check(sticking.is_empty(), "nothing sticks out of the walls through the wall-run band (%d lanes): %s" % [lanes,
			", ".join(sticking)])
		check(lit.is_empty(), "nothing glows on the walls in the wall-run band (%d lanes): %s" % [lanes, ", ".join(lit)])


## Every kind of ceiling on streets of 3, 5 and 6 lanes, over every number of their lanes at every
## position (task B3): across every lane a bridge or a dead building, against one wall a slab broken
## off the tower there, in mid-street a collapsed span. Each has a flat underside covering exactly its
## lanes (running into the building face on a side that reaches the wall, a lip past a free side),
## nothing hanging below it but its seams, a seam under each lane boundary, the orange band at its far
## end and nothing else past it, and nothing rising past TOP_LIMIT (so what the walls hold out over the
## street clears it). Across every lane both kinds turn up; a narrower ceiling never becomes either.
func _ceilings(skin: DeadZoneSkin) -> void:
	var lane_w: float = tuning.lane_width
	var ceilings: DeadCeilings = skin.ceilings()
	var problems: PackedStringArray = []
	var seen: Dictionary = {}
	for lanes: int in [3, 5, 6]:
		var geo := TrackGeometry.new(lanes, tuning)
		var wall_x: float = geo.wall_x()
		for count: int in range(1, lanes + 1):
			for first: int in range(0, lanes - count + 1):
				var last: int = first + count - 1
				var full: bool = count == lanes
				var x0: float = -geo.half_width() if full else geo.lane_x(first) - lane_w * 0.5
				var x1: float = geo.half_width() if full else geo.lane_x(last) + lane_w * 0.5
				var size := Vector3(x1 - x0, TrackBuilder.HULL_THICKNESS, 14.0 + 4.0 * count)
				var center := Vector3((x0 + x1) * 0.5, tuning.ceiling_height + TrackBuilder.HULL_THICKNESS * 0.5, -100.0)
				var edges: Array[float] = []
				for lane: int in range(first + 1, last + 1):
					edges.append(geo.lane_x(lane) - lane_w * 0.5)
				var left: bool = first == 0
				var right: bool = last == lanes - 1
				var want: int = DeadCeilings.Kind.SLAB if left != right else DeadCeilings.Kind.SPAN
				var kind: int = ceilings.kind_of(center, size, wall_x)
				var tag: String = "%d-lane street, lanes %d-%d" % [lanes, first, last]
				if full and kind != DeadCeilings.Kind.BRIDGE and kind != DeadCeilings.Kind.BUILDING or not full and kind != want:
					problems.append("%s: kind %d" % [tag, kind])
				var kinds: Array[int] = [want]
				if full:
					kinds = [DeadCeilings.Kind.BRIDGE, DeadCeilings.Kind.BUILDING]
				for k: int in kinds:
					seen[k] = true
					var mesh: ArrayMesh = ceilings.mesh_for(k, (first + count) % 4, size, edges, center.x, wall_x,
						tuning.ceiling_height)
					_check_ceiling(mesh, skin, "%s, kind %d" % [tag, k], size, edges, center.x, wall_x, left, right, problems)
				if problems.size() > 8:
					break
	check(problems.is_empty(), "every kind of ceiling builds from its lanes, full width or narrow:\n  %s" % "\n  ".join(problems))
	check(seen.size() == 4, "every kind of ceiling is built (%d kinds)" % seen.size())
	check(DeadCeilings.TOP_LIMIT + tuning.ceiling_height < DeadTowers.OVER_STREET_MIN,
		"what the walls hold out over the street clears every ceiling")
	var geo6 := TrackGeometry.new(6, tuning)
	var counts: Dictionary = {}
	for i: int in 200:
		var size := Vector3(geo6.half_width() * 2.0, TrackBuilder.HULL_THICKNESS, 30.0 + float(i % 5) * 4.0)
		var k: int = ceilings.kind_of(Vector3(0.0, 6.4, -(100.0 + i * 7.3)), size, geo6.wall_x())
		counts[k] = int(counts.get(k, 0)) + 1
	check(int(counts.get(DeadCeilings.Kind.BRIDGE, 0)) > 40 and int(counts.get(DeadCeilings.Kind.BUILDING, 0)) > 40,
		"across every lane both bridges and dead buildings turn up: %s" % counts)


## One ceiling mesh's checks (see _ceilings()), problems appended to `problems`.
func _check_ceiling(mesh: ArrayMesh, skin: DeadZoneSkin, tag: String, size: Vector3, edges: Array[float], offset: float,
		wall_x: float, left: bool, right: bool, problems: PackedStringArray) -> void:
	var zf: float = -size.z * 0.5
	var under := {"min_x": INF, "max_x": -INF, "lowest": 0.0, "glow_lowest": 0.0, "highest": 0.0, "band": false,
		"past_below": 0.0, "past_glow": 0.0}
	for s: int in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var glow_surface: bool = mesh.surface_get_material(s) == skin.glow_material()
		for i: int in verts.size():
			var v: Vector3 = verts[i]
			var band_colour: bool = _same_rgb(colors[i], skin.gap_edge_color)
			under["highest"] = maxf(under["highest"], v.y)
			var past: float = 0.0 if band_colour else zf - v.z
			if past > 0.001 and v.y < -0.001:
				under["past_below"] = maxf(under["past_below"], past)
			if glow_surface or colors[i].a > 0.0:
				under["past_glow"] = maxf(under["past_glow"], past)
			if glow_surface:
				under["glow_lowest"] = minf(under["glow_lowest"], v.y)
				continue
			under["lowest"] = minf(under["lowest"], v.y)
			if absf(v.y) < 0.001:
				under["min_x"] = minf(under["min_x"], v.x)
				under["max_x"] = maxf(under["max_x"], v.x)
				if band_colour and v.z < zf + DeadCeilings.END_BAND + 0.01:
					under["band"] = true
	var want0: float = (-wall_x - offset) if left else -size.x * 0.5 - DeadCeilings.FREE_LIP
	var want1: float = (wall_x - offset) if right else size.x * 0.5 + DeadCeilings.FREE_LIP
	if absf(under["min_x"] - want0) > 0.02 or absf(under["max_x"] - want1) > 0.02:
		problems.append("%s: underside spans %.2f..%.2f, not %.2f..%.2f" % [tag, under["min_x"], under["max_x"], want0, want1])
	if under["lowest"] < -0.06:
		problems.append("%s: something hangs %.2f m below the surface" % [tag, under["lowest"]])
	if under["glow_lowest"] < -0.1:
		problems.append("%s: a glow hangs %.2f m below the surface" % [tag, under["glow_lowest"]])
	if under["highest"] > DeadCeilings.TOP_LIMIT + 0.01:
		problems.append("%s: something rises %.2f m above the surface (limit %.1f)" % [tag, under["highest"], DeadCeilings.TOP_LIMIT])
	if not under["band"]:
		problems.append("%s: no orange band at the far end" % tag)
	# The camera passes the far end as the runner drops off: nothing reaches below the underside past it,
	# and nothing glowing but the shared band reaches past it at all.
	if under["past_below"] > 0.0 or under["past_glow"] > 0.05:
		problems.append("%s: something reaches %.2f m past the far end below the underside (glowing: %.2f m)" % [tag,
			under["past_below"], under["past_glow"]])
	for x: float in edges:
		if not _has_seam(mesh, x - offset, skin):
			problems.append("%s: no seam at x %.2f" % [tag, x - offset])


## The cult's emblem (GDD §5, hidden in plain sight; here scorched and half-gone): the owner's choice
## (the choice file, never a hardcoded option), in its unlit metal, never glowing; over 3 km of walls it
## turns up on dead roof boards and at the foot of dead neon banners, each at least emblem_min_size
## across (smaller, it could read like the radiation trefoil) and small beside its board, high on the
## walls; over a whole level every one built is one cult_emblems() lists, never on a hazard.
func _cult_emblem(skin: DeadZoneSkin) -> void:
	var choice := load(CultFeed.CHOICE_PATH) as CultEmblemChoice
	check(choice != null and CultFeed.emblem_option() == choice.option,
		"the skin draws the cult emblem the owner picked (option %s)" % (CultEmblem.option_letter(choice.option)
			if choice != null else "?"))
	if choice == null:
		return
	var scheme: Dictionary = CultEmblem.default_scheme(choice.option)
	check(skin.emblem_metal_color() == scheme["metal"], "it is painted in the chosen emblem's unlit metal")
	check(skin.solid_material().get_shader_parameter("cult_emblem") == CultFeed.emblem_texture(),
		"the kit material carries CultEmblem's drawing of that option")
	var geo := TrackGeometry.new(5, tuning)
	var wall: float = geo.wall_x()
	var kinds: Dictionary = {}
	var listed: Array[Dictionary] = []
	var sizes := Vector2(INF, 0.0)
	var low: int = 0
	for side: int in [-1, 1]:
		for e: Dictionary in skin.cult_emblems(side, side * wall, -100.0, 3000.0):
			kinds[e["kind"]] = int(kinds.get(e["kind"], 0)) + 1
			listed.append(e)
			sizes = Vector2(minf(sizes.x, e["size"]), maxf(sizes.y, e["size"]))
			low += int((e["center"] as Vector3).y < skin.decor_min_height)
	print("  dead zone emblem (5 lanes): %s over 3 km of walls" % kinds)
	check(kinds.size() == 2, "over 3 km the emblem hides on dead roof boards and dead banners: %s" % kinds)
	check(sizes.x >= skin.emblem_min_size - 0.01 and sizes.y <= 1.6 and low == 0,
		"each is %.2f-%.2f m across (never below %.2f m, never a centrepiece), high on the walls (%d low)" % [sizes.x,
			sizes.y, skin.emblem_min_size, low])
	var built: Array[Dictionary] = []
	var bad: PackedStringArray = []
	await visit_level(level(DZ_LEVEL_PATH, 5, 0.6), skin, func(m: MeshInstance3D, arrays: Array, material: Material) -> void:
		if material != skin.solid_material():
			return
		for r: Dictionary in rects_of(m, arrays):
			if r["pattern"] != MeshKit.PAT_DZ_MARK and r["pattern"] != MeshKit.PAT_CULT_MARK:
				continue
			built.append(r)
			var c: Color = r["color"]
			var extent: float = maxf((r["ou"] as Vector3).distance_to(r["o"]), (r["ov"] as Vector3).distance_to(r["o"]))
			if (r["pattern"] != MeshKit.PAT_DZ_MARK or not _same_rgb(c, scheme["metal"]) or c.a != 0.0 or under_hazard(m)
					or extent / DeadTowers.EMBLEM_MARGIN < skin.emblem_min_size - 0.01) and bad.size() < 4:
				bad.append("%s (colour %s, %.2f m)" % [r["center"], c, extent]))
	var unlisted: int = 0
	for r: Dictionary in built:
		var found: bool = false
		for e: Dictionary in listed:
			found = found or (e["center"] as Vector3).distance_to(r["center"]) < 0.1
		unlisted += int(not found)
	check(not built.is_empty() and bad.is_empty(), "over a whole level the %d emblems are the chosen one, scorched and unlit, big enough, off hazards: %s" % [
		built.size(), ", ".join(bad)])
	check(unlisted == 0, "every emblem built is one cult_emblems() lists (%d unlisted)" % unlisted)


## The cult's feed (CultFeed, GDD §5 "Cyborg Viewing Devices") still plays on a few surviving screens,
## with the shared material: on some dead roof boards and hung out over the street from a few towers.
## Over a whole level every screen it builds is one feed_boards() lists, plays the untinted picture
## dimly, faces the runner or the street, and sits far above the wall-run band; they are sparse.
func _cult_feed(skin: DeadZoneSkin) -> void:
	check(skin.feed_material() == CultFeed.material(), "the Dead Zone plays the shared feed")
	var geo := TrackGeometry.new(5, tuning)
	var wall: float = geo.wall_x()
	var kinds: Dictionary = {}
	var listed: Array[Dictionary] = []
	for side: int in [-1, 1]:
		for board: Dictionary in skin.feed_boards(side, side * wall, -100.0, 3000.0):
			kinds[board["kind"]] = int(kinds.get(board["kind"], 0)) + 1
			listed.append(board)
	print("  dead zone feed (5 lanes): %s over 3 km of walls" % kinds)
	check(int(kinds.get(&"roof_board", 0)) > 0 and int(kinds.get(&"tower_screen", 0)) > 0,
		"over 3 km the feed still plays on some roof boards and screens over the street: %s" % kinds)
	check(listed.size() <= 30, "the surviving screens are sparse (%d over 3 km of both walls)" % listed.size())
	var screens: Array[Dictionary] = []
	var bad: PackedStringArray = []
	await visit_level(level(DZ_LEVEL_PATH, 5, 0.6), skin, func(m: MeshInstance3D, arrays: Array, material: Material) -> void:
		if material != skin.feed_material():
			return
		for r: Dictionary in rects_of(m, arrays):
			screens.append(r)
			var lowest: float = minf(r["o"].y, minf(r["ov"].y, r["ou"].y))
			var n: Vector3 = r["normal"]
			var facing: bool = n.is_equal_approx(Vector3.BACK) or n.is_equal_approx(Vector3(-signf(r["center"].x), 0, 0))
			var c: Color = r["color"]
			if (lowest < skin.decor_min_height or not _same_rgb(c, Color.WHITE) or c.a > 0.7 or not facing or under_hazard(m)) \
					and bad.size() < 4:
				bad.append("%s (normal %s, colour %s)" % [r["center"], n, c]))
	var unlisted: int = 0
	for r: Dictionary in screens:
		var found: bool = false
		for board: Dictionary in listed:
			found = found or (board["center"] as Vector3).distance_to(r["center"]) < 0.05
		unlisted += int(not found)
	check(not screens.is_empty() and bad.is_empty(),
		"over a whole level the feed's %d screens face the runner or the street, untinted and dim, far above the band: %s" % [
			screens.size(), ", ".join(bad)])
	check(unlisted == 0, "every feed screen built is one feed_boards() lists (%d unlisted)" % unlisted)


## Whether the ceiling mesh has the pale line of a lane seam at x (the line is 3.5 cm wide, just below
## the steel strip under the underside).
func _has_seam(mesh: ArrayMesh, x: float, skin: DeadZoneSkin) -> bool:
	for s: int in mesh.get_surface_count():
		if mesh.surface_get_material(s) != skin.solid_material():
			continue
		var arrays: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		for i: int in verts.size():
			if _same_rgb(colors[i], skin.seam_color) and absf(verts[i].x - (x - 0.0175)) < 0.002 and verts[i].y < 0.0:
				return true
	return false


func _under(node: Node, test: Callable) -> bool:
	var parent: Node = node.get_parent()
	while parent != null:
		if test.call(parent):
			return true
		parent = parent.get_parent()
	return false


static func _chroma(c: Color) -> float:
	return maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))


static func _same_rgb(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01


## Relative luminance of an sRGB colour, in linear light.
static func _linear_luminance(c: Color) -> float:
	var l: Color = c.srgb_to_linear()
	return 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b


## The brightest channel of an sRGB colour, in linear light.
static func _max_linear(c: Color) -> float:
	var l: Color = c.srgb_to_linear()
	return maxf(l.r, maxf(l.g, l.b))


## Whether `c` could pass for `target` (a saturated hazard colour): close in RGB, or as saturated and
## within 25 degrees of its hue.
static func _near_colour(c: Color, target: Color) -> bool:
	var dr: float = c.r - target.r
	var dg: float = c.g - target.g
	var db: float = c.b - target.b
	if sqrt(dr * dr + dg * dg + db * db) < 0.35:
		return true
	var dh: float = absf(c.h - target.h)
	return c.s > 0.5 and minf(dh, 1.0 - dh) < 25.0 / 360.0

extends SkinSuite
## The Golden Zone skin (GoldenSkin, Zone 6), which the Golden Zone uses. The shared skin checks
## (SkinSuite) over the whole of Golden 2 for 3, 5 and 6 lanes, then the Golden Zone's own:
## - the look: the ceremonial enforcer cyborgs (GDD §9.2), a sky, glow and fog;
## - the colour rule (GDD §5): nothing but hazards glows in a hazard hue, lit surfaces stay well below
##   the hazards' saturation, nothing gold, red, marble or cloth ever glows, and the gold never passes
##   for sign yellow or gap-edge orange; the zone's gold is the cult emblem's gold;
## - gaps read as holes, at 3 and at 5 lanes: everything below the walkways is deep shade or dark
##   water, far darker than any walkway can be drawn, and nothing in there glows but the orange edge;
##   no floor is drawn in or near the edge's colour; both edges of a gap carry the orange edge;
## - the play space stays clear, and nothing sticks out of the walls through the wall-run band;
## - decorative statues stand only far above the wall-run band (a statue at wall-run height is a live
##   Gilded Sentinel), where statue_spots() says, and never glow; the statue kit's API for task C4;
## - every kind of ceiling builds from the lanes it covers (task B3), and its water stays above it;
## - the cult's emblem is the owner's choice in the zone's gold and red, shown openly and large on
##   banners, reliefs, sky bridges, frames and medallions, never on a hazard sign;
## - the cult's feed plays only on the shared material and only high up; a boss arena can turn the
##   hung screens off;
## - nothing vent-like is drawn, only hazard signs wear stripes, and the still floor carries motion cues.

const GOLDEN_SKIN_PATH: String = "res://data/skins/golden_skin.tres"
const GOLDEN_ZONE_PATH: String = "res://data/zones/golden.tres"
## The Golden Zone's campaign level with the most in it.
const GOLDEN_LEVEL_PATH: String = "res://data/levels/golden_2.tres"
## Lit (non-glowing) surfaces stay below this chroma (brightest minus darkest channel); the fence
## pink is about 0.8.
const MAX_SURFACE_CHROMA: float = 0.45
## A glowing colour this saturated (HSV) must keep to the decorative hues (blue to violet).
const GLOW_SATURATION_LIMIT: float = 0.35
## The gold never passes for sign yellow or gap-edge orange: at least this far from them in RGB, and
## this much less saturated (HSV).
const GOLD_DISTANCE: float = 0.3
const GOLD_SATURATION_GAP: float = 0.25
## Gaps: the darkest golden_metal() draws a gold (the dark end of its reflection: half its colour,
## a quarter greyed; kit_golden.gdshaderinc), the brightest factors PAT_UNDERDECK and PAT_CANAL
## give their colours, and how much darker than the darkest floor a gap's inside must stay (linear
## luminance).
const GOLD_DARKEST: float = 0.5
const UNDER_MAX_FACTOR: float = 1.0
const CANAL_MAX_FACTOR: float = 1.12
const GAP_CONTRAST: float = 0.35
## The emblem is shown openly and large (GDD §5): never smaller than this on the walls and overhead.
const EMBLEM_MIN_SIZE: float = 2.0


func run() -> void:
	var skin := load(GOLDEN_SKIN_PATH) as GoldenSkin
	check(skin != null, "the golden skin loads")
	if skin == null:
		return
	# GDD §9.2: the Golden Zone's cyborgs wear the ceremonial enforcer (task P3); the other enemies keep
	# their clean look.
	check(skin.enemy_variant == &"golden" and GoldenSkin.new().enemy_variant == &"golden"
		and CyborgSuit.look_for(skin.enemy_variant) == CyborgSuit.GOLDEN,
		"golden cyborgs wear the ceremonial enforcer")
	var zone := load(GOLDEN_ZONE_PATH) as ZoneDef
	check(zone != null and zone.skin is GoldenSkin, "the Golden Zone uses the golden skin")
	start_error_count()
	var env: Environment = skin.make_environment()
	check(env != null and env.sky != null and env.glow_enabled and env.fog_enabled,
		"the golden environment has a sky, glow and fog")
	_palette(skin)
	for lanes: int in [3, 5, 6]:
		await whole_level(skin, "golden", GOLDEN_LEVEL_PATH, lanes)
	await hazards_and_triggers(skin)
	await _surfaces(skin)
	await _gaps(skin)
	await _clear_play_space(skin)
	_statues(skin)
	await _statue_kit(skin)
	_ceilings(skin)
	_medallions(skin)
	_cult_emblem(skin)
	await _cult_feed(skin)
	await determinism(skin, GOLDEN_LEVEL_PATH)
	stop_error_count("building golden levels")


## The skin's colours keep to the colour rule before anything is built.
func _palette(skin: GoldenSkin) -> void:
	var glowing: Array[Color] = [skin.lamp_color, skin.window_warm_color, skin.ceiling_lamp_color, skin.engine_color,
		skin.skyline_window_color]
	# Sign faces glow a little: inside the hazard frame, but kept off the other hazard hues too.
	glowing.append_array(Array(skin.sign_content_colors))
	var bad: PackedStringArray = []
	for c: Color in glowing:
		if _hazard_hue(c):
			bad.append(str(c))
	check(bad.is_empty(), "the zone's lamps, windows and engines glow warm white or pale blue: %s" % ", ".join(bad))
	var lit: Array[Color] = [skin.gold_color, skin.gold_shine_color, skin.red_color, skin.walkway_color, skin.joint_color,
		skin.kerb_color, skin.vein_color, skin.granite_color, skin.glass_color, skin.mirror_color, skin.wall_mark_color,
		skin.water_color, skin.coffer_color, skin.rib_color, skin.yacht_hull_color, skin.trigger_metal_color,
		skin.canal_color, skin.gap_inside_color, CultEmblem.GOLD_COLOR, CultEmblem.GOLD_ACCENT_COLOR]
	lit.append_array(Array(skin.stone_colors))
	lit.append_array(Array(skin.sign_content_colors))
	var loud: PackedStringArray = []
	for c: Color in lit:
		if _chroma(c) > MAX_SURFACE_CHROMA:
			loud.append(str(c))
	check(loud.is_empty(), "gold, red, cream and white stay well below the hazards' saturation: %s" % ", ".join(loud))
	check(_chroma(skin.fence_color) > MAX_SURFACE_CHROMA + 0.3, "the fence pink is far more saturated than any surface")
	# GDD §5: the gold is reflective metal, never sign yellow or gap-edge orange; the red is deep.
	var golds: Array[Color] = [skin.gold_color, skin.gold_shine_color, skin.walkway_color, skin.coffer_color,
		skin.wall_mark_color, Color(skin.leaf_color, 1.0), CultEmblem.GOLD_COLOR]
	var close: PackedStringArray = []
	for hazard: Color in [skin.sign_frame_color, skin.gap_edge_color]:
		for c: Color in golds:
			if _rgb_distance(c, hazard) < GOLD_DISTANCE or c.s > hazard.s - GOLD_SATURATION_GAP:
				close.append("%s near %s" % [c, hazard])
	check(close.is_empty(), "the zone's golds never pass for sign yellow or gap-edge orange: %s" % ", ".join(close))
	check(_same_rgb(skin.gold_color, CultEmblem.GOLD_COLOR), "the zone's gold is the cult emblem's gold")
	check(skin.red_color.v < 0.6 and _chroma(CultEmblem.GOLD_ACCENT_COLOR) <= MAX_SURFACE_CHROMA,
		"the zone's red and the emblem's centre stone are a deep crimson")


## Over a whole level (Golden 2, 5 lanes, chunk by chunk): glowing surfaces keep off the hazard hues
## (the orange edges aside); lit ones stay desaturated; nothing gold, red, marble, cloth or water ever
## glows; no surface uses the grille (vent) pattern; only hazard signs wear the striped frame; the
## emblem never sits on a hazard; the drifting particles are there. The facades' lights come from
## uniforms: they keep to the rule too.
func _surfaces(skin: GoldenSkin) -> void:
	var found := {"grilles": 0, "stripes": 0, "drift": 0, "emblems": 0, "hazard_hues": [], "loud": [], "glowing": [],
		"on_hazards": 0}
	var solid: Material = skin.solid_material()
	var glow: Material = skin.glow_material()
	var edge: Color = skin.gap_edge_color
	var never_glow: Array[int] = [MeshKit.PAT_GOLD, MeshKit.PAT_WALKWAY, MeshKit.PAT_MARBLE, MeshKit.PAT_UNDERDECK,
		MeshKit.PAT_CANAL, MeshKit.PAT_WATER, MeshKit.PAT_EMBLEM, MeshKit.PAT_COFFER, MeshKit.PAT_CLOTH]
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
				if pattern == MeshKit.PAT_EMBLEM:
					found["emblems"] += 1
					if in_hazard:
						found["on_hazards"] += 1
				if c.a > 0.0 and not in_hazard and not in_trigger and (never_glow.has(pattern)
						or _same_rgb(c, skin.red_color) or _same_rgb(c, skin.gold_color)) and found["glowing"].size() < 4:
					found["glowing"].append("%s pattern %d at %s" % [c, pattern, m.global_transform * verts[i]])
				if c.a == 0.0 and not in_hazard and not in_trigger and _chroma(c) > MAX_SURFACE_CHROMA \
						and found["loud"].size() < 4:
					found["loud"].append("%s at %s" % [c, m.global_transform * verts[i]])
			var glowing: bool = material == glow or c.a > 0.0
			if glowing and not in_hazard and not in_trigger and _hazard_hue(c) and not _same_rgb(c, edge) \
					and found["hazard_hues"].size() < 4:
				found["hazard_hues"].append("%s at %s" % [c, m.global_transform * verts[i]])
	await visit_level(level(GOLDEN_LEVEL_PATH, 5, 0.6, 4), skin, visit)
	check(found["grilles"] == 0, "nothing vent-like: no surface uses the grille pattern (%d vertices)" % found["grilles"])
	check(found["stripes"] == 0, "only hazard signs wear the striped frame (%d striped vertices elsewhere)" % found["stripes"])
	check(found["hazard_hues"].is_empty(), "nothing but hazards (and the orange edges) glows in a hazard hue: %s" % ", ".join(
		found["hazard_hues"]))
	check(found["loud"].is_empty(), "lit surfaces stay desaturated: %s" % ", ".join(found["loud"]))
	check(found["glowing"].is_empty(), "gold, red, marble, cloth and water never glow (GDD §5): %s" % ", ".join(found["glowing"]))
	check(found["emblems"] > 0 and found["on_hazards"] == 0, "the emblem is shown (%d vertices), never on a hazard (%d)" % [
		found["emblems"], found["on_hazards"]])
	check(found["drift"] > 0, "the walkways carry drifting mist, gold leaf and speed streaks (%d vertices)" % found["drift"])
	var facade: ShaderMaterial = skin.facade_material()
	var lights: PackedStringArray = []
	for u: String in ["window_warm"]:
		var v: Vector3 = facade.get_shader_parameter(u)
		if _hazard_hue(Color(v.x, v.y, v.z)):
			lights.append("%s %s" % [u, v])
	check(lights.is_empty(), "the facades' lit windows keep off the hazard hues: %s" % ", ".join(lights))
	var drapes: Vector3 = facade.get_shader_parameter("drape_color")
	check(_same_rgb(Color(drapes.x, drapes.y, drapes.z), skin.red_color), "the windows' drapes are the zone's red (unlit)")


## Gaps read as holes at a glance, as in every zone (CLAUDE.md readability rules): whatever a gap
## shows is in deep shade or dark water, far darker than any walkway or ridden underside can be
## drawn, and nothing in it glows but the orange edge; no floor is drawn in (or near) the edge's
## colour; the showcase gap carries the full orange edge on both sides (the lip on the deck right at
## the collision edge, the strip along the top of its face, and on the far side the halo). Checked
## over whole levels at 3 and 5 lanes: below the walkways there is nothing but the shade, the water,
## the strips and the halo.
func _gaps(skin: GoldenSkin) -> void:
	var floors: Array[Color] = [_darkest_gold(skin.walkway_color) * Color(skin.walkway_light, skin.walkway_light,
		skin.walkway_light), _darkest_gold(skin.gold_color) * Color(skin.walkway_light, skin.walkway_light, skin.walkway_light),
		skin.kerb_color * Color(0.8, 0.8, 0.8)]
	var darkest: float = INF
	for c: Color in floors:
		darkest = minf(darkest, _linear_luminance(c))
	var inside: float = maxf(_linear_luminance(skin.gap_inside_color * Color(UNDER_MAX_FACTOR, UNDER_MAX_FACTOR,
		UNDER_MAX_FACTOR)), _linear_luminance(skin.canal_color * Color(CANAL_MAX_FACTOR, CANAL_MAX_FACTOR, CANAL_MAX_FACTOR)))
	check(inside < darkest * GAP_CONTRAST, "a gap's inside stays far darker than the darkest walkway: %.4f vs %.4f" % [
		inside, darkest])
	# Floors: the walkways and kerbs, and the undersides a rider runs on (bridges, archways, yachts).
	var like_edge: PackedStringArray = []
	var surfaces: Array[Color] = [skin.walkway_color, skin.gold_color, skin.gold_shine_color, skin.kerb_color, skin.coffer_color,
		skin.rib_color, skin.yacht_hull_color]
	surfaces.append_array(Array(skin.stone_colors))
	for c: Color in surfaces:
		if _near_colour(c, skin.gap_edge_color):
			like_edge.append(str(c))
	check(like_edge.is_empty(), "no floor is drawn in the gap edge's colour: %s" % ", ".join(like_edge))
	# The showcase gap (lane 3, 50-57 m): the orange edge on both sides, the halo on the far one.
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
				if not _same_rgb(colors[i], skin.gap_edge_color) or p.x < 1.0 or p.x > 3.8:
					continue
				if material == skin.glow_material():
					halo = halo or absf(-p.z - 57.0) < 0.1
				elif absf(-p.z - 57.0) <= 0.3:
					if p.y < -0.001 and colors[i].a >= GoldenWalkways.STRIP_GLOW - 0.001:
						strip = Vector2(minf(strip.x, p.y), maxf(strip.y, p.y))
					elif absf(p.y) < 0.001 and colors[i].a >= GoldenWalkways.LIP_GLOW - 0.001:
						lip = Vector2(minf(lip.x, -p.z), maxf(lip.y, -p.z))
				elif absf(-p.z - 50.0) <= 0.3 and absf(p.y) < 0.001 and colors[i].a >= GoldenWalkways.LIP_GLOW - 0.001:
					near_lip = Vector2(minf(near_lip.x, -p.z), maxf(near_lip.y, -p.z))
	check(strip.y - strip.x >= GoldenWalkways.STRIP_HEIGHT - 0.001 and strip.y > -0.05,
		"the far edge's orange strip runs along the top of its face: %s" % strip)
	check(lip.x > 56.99 and lip.y - lip.x >= GoldenWalkways.EDGE_LIP - 0.001,
		"the far edge's orange lip lies on the deck right at the collision edge: %s" % lip)
	check(near_lip.y < 50.01 and near_lip.y - near_lip.x >= GoldenWalkways.EDGE_LIP - 0.001,
		"the near edge's orange lip ends right at the collision edge: %s" % near_lip)
	check(halo, "the far edge carries its orange halo toward the approaching runner")
	await free_track(track)
	# Whole levels, chunk by chunk: below the walkways only the shade, the water, the strips, the halo.
	var shade: float = inside + 0.0001
	for lanes: int in [3, 5]:
		var layout: LevelLayout = level(GOLDEN_LEVEL_PATH, lanes, 0.6, 9)
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
					under += _check_below_walkways(chunk, skin, layout.length, shade, bad)
			d += TrackBuilder.CHUNK_LENGTH
		check(bad.is_empty() and under > 0, "below the walkways there is only deep shade, dark water and the orange edge " +
			"(%d lanes, %d vertices): %s" % [lanes, under, ", ".join(bad)])
		world.queue_free()
		await tree.process_frame


## Checks every vertex of the skin's meshes in `chunk` below the walkways (hazards and triggers aside,
## and the finish gantry's posts at `finish`): the shade, the canal, an orange strip, the halo, the
## deep facade faces. Returns how many there were; problems (up to four) go to `bad`.
func _check_below_walkways(chunk: Node, skin: GoldenSkin, finish: float, shade: float, bad: PackedStringArray) -> int:
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
					var strip: bool = _same_rgb(c, skin.gap_edge_color) and c.a >= GoldenWalkways.STRIP_GLOW - 0.001
					var dark: bool = (pattern == MeshKit.PAT_UNDERDECK or pattern == MeshKit.PAT_CANAL) and c.a == 0.0 \
						and _linear_luminance(c) <= shade
					if not strip and not dark:
						what = "%s pattern %d" % [c, pattern]
				elif material == skin.facade_material():
					if roundi(uv2[i].x) != GoldenFacades.STYLE_DEEP or not _same_rgb(c, skin.gap_inside_color):
						what = "facade %s style %d" % [c, roundi(uv2[i].x)]
				elif material == skin.glow_material():
					if not _same_rgb(c, skin.gap_edge_color):
						what = "glow %s" % c
				elif material != skin.drift_material():
					what = "material %s" % material.resource_path.get_file() if material != null else "no material"
				if what != "" and bad.size() < 4:
					bad.append("%s at %s" % [what, p])
	return count


## Between the floor and the ceiling, over the lanes, the skin builds nothing solid but hazards and
## triggers, anywhere in a whole level: the walkways are flat, gap faces hang below them, ceilings
## keep above their undersides, and statues, banners, frames and screens stay outside the lanes or up
## high; and nothing sticks out of the walls through the wall-run band.
func _clear_play_space(skin: GoldenSkin) -> void:
	for lanes: int in [3, 6]:
		var layout: LevelLayout = level(GOLDEN_LEVEL_PATH, lanes, 0.6, 5)
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


## Solid vertices of the skin's meshes in `chunk` over the lanes between the floor and the ceiling
## (up to four, appended to `out`), and those sticking out of a wall face by more than 5 cm below the
## calm band's top (decor_min_height - 1 m, and below the ceilings), up to four in `sticking`; the
## finish gantry's posts (at `finish`, shared by every zone) don't count.
func _find_intruders(chunk: Node, skin: GoldenSkin, geo: TrackGeometry, finish: float, out: PackedStringArray,
		sticking: PackedStringArray) -> void:
	var half: float = geo.half_width()
	var wall: float = geo.wall_x()
	var band_top: float = minf(skin.decor_min_height - 1.0, tuning.ceiling_height - 0.1)
	for node: Node in nodes_of(chunk, func(n: Node) -> bool: return n is MeshInstance3D):
		var m := node as MeshInstance3D
		if m.mesh == null or m.is_in_group(&"debug_hitbox") or _under(m, func(n: Node) -> bool: return n is Area3D):
			continue
		for s: int in m.mesh.get_surface_count():
			# Drifting mist and additive light (lamp halos, engine glow) aren't objects.
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


## Golden statues line the walls (GDD §9.11), every decorative one far above the wall-run band (a
## statue at wall-run height is a live Gilded Sentinel: safe things look safe), in a decorative pose,
## the same every time; the built walls hold a statue at every listed spot, and no statue glows.
func _statues(skin: GoldenSkin) -> void:
	var wall_run_top: float = tuning.wall_max_height + tuning.visual_size.y
	check(skin.statue_min_height >= wall_run_top + 2.0 and skin.statue_min_height >= tuning.ceiling_height + 2.0,
		"decorative statues stand far above the wall-run band (from %.1f m; a wall run reaches %.1f m)" % [
			skin.statue_min_height, wall_run_top])
	check(skin.facades().ledge_top() >= skin.statue_min_height - 0.001,
		"the palaces' statue ledge is at statue_min_height or higher (%.1f m)" % skin.facades().ledge_top())
	var geo := TrackGeometry.new(5, tuning)
	var count: int = 0
	var poses: Dictionary = {}
	var low: PackedStringArray = []
	for side: int in [-1, 1]:
		var spots: Array[Dictionary] = skin.statue_spots(side, side * geo.wall_x(), 0.0, 3000.0)
		check(spots == skin.statue_spots(side, side * geo.wall_x(), 0.0, 3000.0), "statues stand in the same places every time")
		for s: Dictionary in spots:
			count += 1
			poses[s["pose"]] = true
			var c: Vector3 = s["center"]
			if c.y < skin.statue_min_height - 0.001 or not GoldenStatue.DECORATIVE.has(s["pose"]) or absf(c.x) < geo.wall_x() - 1.0:
				low.append("%s %s" % [c, s["pose"]])
	check(count > 200 and poses.size() == GoldenStatue.DECORATIVE.size() and low.is_empty(),
		"%d decorative statues over 3 km of both walls, in all %d poses, all high on the palaces: %s" % [count, poses.size(),
			", ".join(low)])
	# Built: a statue's gold at every listed spot (its figure over its pedestal), nothing of it glowing.
	var batch := MeshBatch.new()
	skin.facades().build(batch, 1, geo.wall_x(), 0.0, 400.0)
	var layer: MeshLayer = batch.layer(skin.solid_material())
	var spots: Array[Dictionary] = skin.statue_spots(1, geo.wall_x(), 0.0, 400.0)
	var missing: int = 0
	for s: Dictionary in spots:
		var c: Vector3 = s["center"]
		var head: bool = false
		for i: int in layer.size():
			var p: Vector3 = layer.verts[i]
			if absf(p.x - c.x) < 0.6 and absf(p.z - c.z) < 0.6 and p.y > c.y + GoldenStatue.STATURE * 0.8 \
					and p.y < c.y + GoldenStatue.PEDESTAL_HEIGHT + GoldenStatue.STATURE + 0.2 \
					and roundi(layer.uv2s[i].x) == MeshKit.PAT_GOLD:
				head = true
				break
		if not head:
			missing += 1
	check(not spots.is_empty() and missing == 0, "every listed statue is built on its ledge (%d of %d missing)" % [missing,
		spots.size()])
	var lit: bool = true
	for pose: StringName in GoldenStatue.DECORATIVE:
		var statue: MeshLayer = skin.statues().mesh(GoldenStatue.pose_named(pose))
		for c: Color in statue.colors:
			lit = lit and c.a == 0.0
	check(lit, "decorative statues never glow: their eyes are dark bronze (only a live Sentinel's glow red)")


## The statue kit for the Gilded Sentinels (task C4): shared by the skin, poses fill in from REST and
## blend, merged meshes are cached per pose and stand on their pedestal, the rig has every pivot and
## poses like the merged mesh, and the niche frames its opening.
func _statue_kit(skin: GoldenSkin) -> void:
	var kit: GoldenStatue = skin.statues()
	check(kit == skin.statues() and kit.material == skin.solid_material() and _same_rgb(kit.gold, skin.gold_color),
		"the skin's statue kit is shared and drawn in its gold with its solid material")
	var named: bool = GoldenStatue.POSES.has(&"raise") and GoldenStatue.POSES.has(&"strike")
	for pose: StringName in GoldenStatue.DECORATIVE:
		named = named and GoldenStatue.POSES.has(pose)
	check(named and GoldenStatue.full_pose({}) == GoldenStatue.REST, "the kit names its decorative and swing poses")
	var mid: Dictionary = GoldenStatue.blend_poses(GoldenStatue.pose_named(&"raise"), GoldenStatue.pose_named(&"strike"), 0.5)
	check(is_equal_approx(float(mid["elbow_r"]), 25.0) and (mid["shoulder_r"] as Vector3).is_equal_approx(Vector3(110.0, -10.0, 4.0)),
		"poses blend joint by joint (a Sentinel's swing)")
	var guard: MeshLayer = kit.mesh(GoldenStatue.pose_named(&"guard"))
	check(guard == kit.mesh(GoldenStatue.pose_named(&"guard")) and guard != kit.mesh(GoldenStatue.pose_named(&"vigil")),
		"merged statues are cached per pose")
	var box := AABB(guard.verts[0], Vector3.ZERO)
	for v: Vector3 in guard.verts:
		box = box.expand(v)
	check(box.position.y > -0.001 and box.end.y > GoldenStatue.PEDESTAL_HEIGHT + GoldenStatue.STATURE * 0.98
		and box.size.x < 1.5 and box.size.z < 1.5, "a statue stands on its pedestal, as tall as its halberd: %s" % box)
	var holder := Node3D.new()
	tree.root.add_child(holder)
	var nodes: Dictionary = kit.rig(holder, GoldenStatue.pose_named(&"guard"))
	var complete: bool = true
	for key: StringName in [&"root", &"body", &"pedestal", &"head", &"eyes", &"arm_r", &"arm_l", &"elbow_r", &"elbow_l",
			&"grip", &"halberd"]:
		complete = complete and nodes.get(key) is Node3D
	check(complete and nodes[&"eyes"] is MeshInstance3D and nodes[&"halberd"] is MeshInstance3D,
		"the rig has the body, the helmet, the eyes, both arms' pivots, the grip and the halberd")
	var before: Basis = (nodes[&"arm_r"] as Node3D).basis
	GoldenStatue.apply_pose(nodes, GoldenStatue.pose_named(&"raise"))
	check(not (nodes[&"arm_r"] as Node3D).basis.is_equal_approx(before), "apply_pose() turns the rig's pivots")
	var root: Node3D = nodes[&"root"]
	var xforms: Dictionary = GoldenStatue.part_transforms(GoldenStatue.pose_named(&"raise"))
	var halberd: Transform3D = root.global_transform.affine_inverse() * (nodes[&"halberd"] as Node3D).global_transform
	var head: Transform3D = root.global_transform.affine_inverse() * (nodes[&"head"] as Node3D).global_transform
	check(halberd.is_equal_approx(xforms[GoldenStatue.Part.HALBERD]) and head.is_equal_approx(xforms[GoldenStatue.Part.HEAD]),
		"the rig poses exactly like the merged statue")
	holder.queue_free()
	await tree.process_frame
	var niche: MeshLayer = kit.niche(1.3, 3.4)
	var nb := AABB(niche.verts[0], Vector3.ZERO)
	for v: Vector3 in niche.verts:
		nb = nb.expand(v)
	check(niche == kit.niche(1.3, 3.4) and nb.position.y > -0.2 and nb.end.y > 3.4 and nb.end.y < 3.7 and nb.size.x > 1.5
		and nb.size.x < 2.0 and nb.position.z > -0.001, "the niche frames its opening, proud of the wall: %s" % nb)


## Every kind of ceiling, over every number of lanes from one to six, full width or narrow and off
## centre (task B3): a flat underside covering exactly its lanes (bridges and archways across every
## lane reach from wall to wall), nothing hanging below it but flush lamps and seams, the orange band
## at its far end, a seam under each lane boundary; the water off the bridges stays above the
## underside, on some of them only.
func _ceilings(skin: GoldenSkin) -> void:
	var lane_w: float = tuning.lane_width
	var wall_x: float = 3.0 * lane_w + tuning.wall_margin
	var problems: PackedStringArray = []
	var water := {"bridges": 0, "wrong": 0, "low": 0}
	for kind: int in [GoldenCeilings.Kind.BRIDGE, GoldenCeilings.Kind.ARCHWAY, GoldenCeilings.Kind.YACHT]:
		for lanes: int in range(1, 7):
			var offset: float = 0.0 if lanes == 6 else (6 - lanes) * lane_w * 0.5 * (1.0 if lanes % 2 == 0 else -1.0)
			var size := Vector3(lanes * lane_w, TrackBuilder.HULL_THICKNESS, 30.0)
			var edges: Array[float] = []
			for k: int in range(1, lanes):
				edges.append(offset - size.x * 0.5 + k * lane_w)
			var tag: String = "kind %d, %d lanes" % [kind, lanes]
			for variant: int in 4:
				var length: float = 30.0 + 10.0 * variant
				size.z = length
				var mesh: ArrayMesh = skin.ceilings().mesh_for(kind, variant, size, edges, offset, wall_x)
				var under := {"min_x": INF, "max_x": -INF, "lowest": 0.0, "band": false, "water": 0, "water_low": 0}
				for s: int in mesh.get_surface_count():
					var arrays: Array = mesh.surface_get_arrays(s)
					var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
					var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
					var glow_surface: bool = mesh.surface_get_material(s) == skin.glow_material()
					for i: int in verts.size():
						var v: Vector3 = verts[i]
						if glow_surface:
							continue
						under["lowest"] = minf(under["lowest"], v.y)
						if roundi(uv2[i].x) == MeshKit.PAT_WATER:
							under["water"] += 1
							if v.y < -0.001:
								under["water_low"] += 1
						if absf(v.y) < 0.001:
							under["min_x"] = minf(under["min_x"], v.x)
							under["max_x"] = maxf(under["max_x"], v.x)
							if _same_rgb(colors[i], skin.gap_edge_color) and v.z < -size.z * 0.5 + GoldenCeilings.END_BAND + 0.01:
								under["band"] = true
				var full: bool = lanes == 6 and kind != GoldenCeilings.Kind.YACHT
				var want: float = wall_x if full else size.x * 0.5 + 0.15
				if absf(under["min_x"] + want) > 0.02 or absf(under["max_x"] - want) > 0.02:
					problems.append("%s: underside spans %.2f..%.2f, not ±%.2f" % [tag, under["min_x"], under["max_x"], want])
				if under["lowest"] < -0.06:
					problems.append("%s: something hangs %.2f m below the surface" % [tag, under["lowest"]])
				if not under["band"]:
					problems.append("%s: no orange band at the far end" % tag)
				if kind == GoldenCeilings.Kind.BRIDGE and full:
					water["bridges"] += 1
					water["wrong"] += 1 if (under["water"] > 0) != skin.ceilings().has_water(variant, length) else 0
				elif under["water"] > 0:
					problems.append("%s: water off a ceiling that isn't a bridge" % tag)
				water["low"] += under["water_low"]
				for x: float in edges:
					if not _has_seam(mesh, x - offset, skin):
						problems.append("%s: no seam at x %.2f" % [tag, x - offset])
				if problems.size() > 6:
					break
	check(problems.is_empty(), "every kind of ceiling builds from its lanes, full width or narrow:\n  %s" % "\n  ".join(problems))
	var with_water: int = 0
	var bridges: int = 0
	for variant: int in 4:
		for length: float in [24.0, 31.0, 38.0, 45.0, 52.0, 60.0]:
			bridges += 1
			with_water += 1 if skin.ceilings().has_water(variant, length) else 0
	check(with_water > 0 and with_water < bridges and water["wrong"] == 0 and water["low"] == 0,
		"water pours off some bridges (%d of %d), always above the underside" % [with_water, bridges])
	# Only a ceiling across every lane may become a bridge or archway reaching from wall to wall.
	var kinds_full: Dictionary = {}
	var kinds_narrow: Dictionary = {}
	for i: int in 300:
		var z: float = -(100.0 + i * 7.3)
		var full := Vector3(6.0 * lane_w, TrackBuilder.HULL_THICKNESS, 40.0 + float(i % 5) * 4.0)
		kinds_full[skin.ceilings().kind_of(Vector3(0, 6.4, z), full, wall_x)] = true
		var narrow := Vector3(2.0 * lane_w, TrackBuilder.HULL_THICKNESS, full.z)
		kinds_narrow[skin.ceilings().kind_of(Vector3(lane_w, 6.4, z), narrow, wall_x)] = true
	check(kinds_full.size() == 3 and not kinds_narrow.has(GoldenCeilings.Kind.ARCHWAY),
		"full-width ceilings mix bridges, archways and yachts; narrow ones never become archways")


## The cult's medallions in the walkways: some over a long street, each clear of any gap's edge.
func _medallions(skin: GoldenSkin) -> void:
	var walkways: GoldenWalkways = skin.walkways()
	var width: float = tuning.lane_width
	var count: int = 0
	var clear: bool = true
	for lane_x: float in [-4.8, -2.4, 0.0, 2.4, 4.8]:
		count += walkways.medallions(lane_x, width, 0.0, 3000.0).size()
		for start: float in [13.0, 57.5, 101.0, 333.3]:
			var far: float = start + 30.0
			for c: float in walkways.medallions(lane_x, width, start, far, true, true):
				var room: float = GoldenWalkways.EDGE_LIP + GoldenWalkways.EDGE_DARK + GoldenWalkways.MEDALLION_CLEAR - 0.001
				clear = clear and c - width * 0.5 - start >= room and far - (c + width * 0.5) >= room
	check(count > 20 and clear, "the cult's medallions are inlaid in the walkways (%d over 3 km of 5 lanes), clear of gaps" % count)


## The cult's emblem (GDD §5): the owner's choice (data/world/cult_emblem_choice.tres), never
## hardcoded, drawn by CultEmblem in the zone's gold meeting at its red stone; shown openly and large
## on banners, reliefs, frames and sky bridges over a long street, high above the band.
func _cult_emblem(skin: GoldenSkin) -> void:
	var choice := load(GoldenSkin.CULT_EMBLEM_CHOICE_PATH) as CultEmblemChoice
	check(choice != null and GoldenSkin.cult_emblem_option() == choice.option,
		"the golden skin draws the emblem the owner picked (option %s)" % (CultEmblem.option_letter(choice.option)
			if choice != null else "?"))
	if choice == null:
		return
	var texture := skin.solid_material().get_shader_parameter("cult_emblem") as ImageTexture
	var expected: Image = CultEmblem.build_image(choice.option, GoldenSkin.CULT_EMBLEM_PIXELS, CultEmblem.GOLD_COLOR,
		CultEmblem.GOLD_ACCENT_COLOR, Color(CultEmblem.GOLD_COLOR, 0.0))
	var same: bool = texture != null and texture == GoldenSkin.cult_emblem_texture() \
		and texture.get_image().get_width() == expected.get_width() and texture.get_image().has_mipmaps()
	var gold: int = 0
	var stone: int = 0
	if same:
		var got: Image = texture.get_image()
		for y: int in range(0, expected.get_height(), 2):
			for x: int in range(0, expected.get_width(), 2):
				var e: Color = expected.get_pixel(x, y)
				var g: Color = got.get_pixel(x, y)
				same = same and g.is_equal_approx(e) if e.a > 0.0 else same and g.a < 0.01
				if e.a > 0.99:
					gold += int(_same_rgb(e, CultEmblem.GOLD_COLOR))
					stone += int(_same_rgb(e, CultEmblem.GOLD_ACCENT_COLOR))
	check(same and gold > 50 and stone > 0, "the kit material carries CultEmblem's drawing of that option in gold (%d samples) " % gold +
		"meeting at its red stone (%d)" % stone)
	# Listed over 3 km of both walls and overhead: every kind, large, high up; built where listed.
	var geo := TrackGeometry.new(5, tuning)
	var kinds: Dictionary = {}
	var small: PackedStringArray = []
	for side: int in [-1, 1]:
		for e: Dictionary in skin.cult_emblems(side, side * geo.wall_x(), 0.0, 3000.0):
			kinds[e["kind"]] = int(kinds.get(e["kind"], 0)) + 1
			if float(e["size"]) < EMBLEM_MIN_SIZE or (e["center"] as Vector3).y - float(e["size"]) * 0.5 < skin.decor_min_height:
				small.append("%s %.2f m at %s" % [e["kind"], e["size"], e["center"]])
	check(kinds.has(&"banner") and kinds.has(&"relief") and kinds.has(&"frame") and kinds.has(&"sky_bridge"),
		"the emblem is shown openly on banners, reliefs, frames and sky bridges over 3 km: %s" % kinds)
	check(small.is_empty(), "every emblem is %.1f m across or more, high above the band: %s" % [EMBLEM_MIN_SIZE,
		", ".join(small.slice(0, 4))])
	var batch := MeshBatch.new()
	var face_x: float = -geo.wall_x()
	skin.facades().build(batch, -1, face_x, 0.0, 600.0)
	skin.facades().overhead(batch, geo.wall_x(), 0.0, 600.0)
	var centres: Array[Vector3] = _emblem_centres(batch.layer(skin.solid_material()))
	var listed: Array[Dictionary] = skin.cult_emblems(-1, face_x, 0.0, 600.0)
	var missing: PackedStringArray = []
	for e: Dictionary in listed:
		var found: bool = false
		for c: Vector3 in centres:
			found = found or c.distance_to(e["center"]) < 0.05
		if not found:
			missing.append("%s at %s" % [e["kind"], e["center"]])
	check(not listed.is_empty() and missing.is_empty(), "every listed emblem is built where listed (%d): %s" % [listed.size(),
		", ".join(missing)])


## The middles of the emblem panels (PAT_EMBLEM rects, six vertices each) in a layer.
static func _emblem_centres(layer: MeshLayer) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var i: int = 0
	while i + 5 < layer.size():
		if roundi(layer.uv2s[i].x) == MeshKit.PAT_EMBLEM:
			out.append((layer.verts[i + 1] + layer.verts[i + 5]) * 0.5)
			i += 6
		else:
			i += 1
	return out


## The cult's feed (CultFeed, GDD §5 "Cyborg Viewing Devices") plays in gilded frames and on big
## screens hung over the street, all with the one shared feed material, only high up (never on the
## wall-run band, never over the lanes below the ceilings); the hung screens fit the street and a boss
## arena can turn them off (feed_hung_share).
func _cult_feed(skin: GoldenSkin) -> void:
	check(skin.feed_material() == CultFeed.material(), "the Golden Zone plays the shared feed")
	var counts: Dictionary = {}
	var narrow: float = 0.0
	var wide: float = 0.0
	for lanes: int in [3, 6]:
		var geo := TrackGeometry.new(lanes, tuning)
		for side: int in [-1, 1]:
			for board: Dictionary in skin.feed_boards(side, side * geo.wall_x(), 0.0, 3000.0):
				counts[board["kind"]] = int(counts.get(board["kind"], 0)) + 1
				if board["kind"] == &"hung":
					if lanes == 3:
						narrow = maxf(narrow, board["width"])
					else:
						wide = maxf(wide, board["width"])
	check(counts.has(&"frame") and counts.has(&"hung"), "over 3 km the feed plays in frames and on hung screens: %s" % counts)
	var reach3: float = TrackGeometry.new(3, tuning).wall_x() * skin.feed_hung_reach
	check(narrow > 0.0 and narrow <= reach3 and wide > narrow and wide <= skin.feed_hung_width,
		"hung screens fit the street: %.2f m wide at 3 lanes, %.2f m at 6" % [narrow, wide])
	var arena := skin.duplicate() as GoldenSkin
	arena.feed_hung_share = 0.0
	var hung: int = 0
	for side: int in [-1, 1]:
		for board: Dictionary in arena.feed_boards(side, side * 6.3, 0.0, 3000.0):
			hung += 1 if board["kind"] == &"hung" else 0
	check(hung == 0, "with feed_hung_share at 0 no screens hang over the street (%d)" % hung)
	# A whole level: every feed screen is high up.
	var layout: LevelLayout = level(GOLDEN_LEVEL_PATH, 5, 0.6, 5)
	var shown := {"high": 0, "bad": []}
	var visit := func(m: MeshInstance3D, arrays: Array, material: Material) -> void:
		if material != skin.feed_material():
			return
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i: int in range(0, verts.size() - 5, 6):
			var p: Vector3 = m.global_transform * ((verts[i + 1] + verts[i + 5]) * 0.5)
			var low: float = minf((m.global_transform * verts[i]).y, (m.global_transform * verts[i + 1]).y)
			if low >= skin.decor_min_height:
				shown["high"] += 1
			elif shown["bad"].size() < 4:
				shown["bad"].append(str(p))
	await visit_level(layout, skin, visit)
	check(shown["bad"].is_empty() and shown["high"] > 0, "the feed plays only high up (%d screens): %s" % [shown["high"],
		", ".join(shown["bad"])])


## golden_metal()'s darkest rendering of a gold (see GOLD_DARKEST): a quarter greyed, halved.
static func _darkest_gold(c: Color) -> Color:
	var grey: float = c.r * 0.3 + c.g * 0.55 + c.b * 0.15
	return c.lerp(Color(grey, grey, grey), 0.25) * Color(GOLD_DARKEST, GOLD_DARKEST, GOLD_DARKEST)


func _has_seam(mesh: ArrayMesh, x: float, skin: GoldenSkin) -> bool:
	for s: int in mesh.get_surface_count():
		if mesh.surface_get_material(s) != skin.solid_material():
			continue
		for v: Vector3 in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			if absf(v.x - (x - 0.03)) < 0.002 and v.y < 0.0 and v.y > -0.02:
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


## A saturated colour outside the decorative blue-to-violet band: pink, red, orange, yellow, green
## or cyan (GDD §5: those glow only on hazards).
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


## Whether `c` could pass for `target` (a saturated hazard colour): close in RGB, or as saturated and
## within 25 degrees of its hue.
static func _near_colour(c: Color, target: Color) -> bool:
	if _rgb_distance(c, target) < 0.35:
		return true
	var dh: float = absf(c.h - target.h)
	return c.s > 0.5 and minf(dh, 1.0 - dh) < 25.0 / 360.0

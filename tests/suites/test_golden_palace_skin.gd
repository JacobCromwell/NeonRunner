extends SkinSuite
## The Golden Palace interior skin (GoldenPalaceSkin, Golden 3, GDD §5 "Final level: the Golden
## Palace"), which reuses D6a's materials and statue kit. The shared skin checks (SkinSuite) over
## the whole of Golden 3 for 3, 5 and 6 lanes, then the palace's own:
## - it loads as the Golden Zone's ceremonial-enforcer cyborgs, with the stars (but not the moon,
##   the exported field) turned off its inherited sky, and Golden 3 is set to use it;
## - the colour rule (GDD §5), as the Golden Zone's: nothing but hazards glows in a hazard hue, lit
##   surfaces stay well below the hazards' saturation, and nothing gold, marble, cloth or coffered
##   ever glows;
## - gaps read as holes, at 3 and 5 lanes: everything below the floor is deep shade, far darker than
##   any floor can be drawn, and nothing in it glows but the orange edge; the showcase gap carries
##   the full orange edge on both sides;
## - the play space stays clear, and nothing sticks out of the walls below the colonnade's
##   entablature (frieze_top), the same calm band every zone keeps;
## - decorative statues stand only in an alcove above statue_min_height, in the same niche shape a
##   live Gilded Sentinel's uses, and never glow; statue_spots() lists exactly where they are built;
## - the ceiling pieces (a bridge or an archway needs every lane; a chandelier hangs over any width;
##   a hanging chandelier never dips below the running surface) are left to the shared test_ceilings
##   suite, which sweeps every skin in data/skins/ as soon as its file exists;
## - the cult's emblem and feed are shown in the colonnade's galleries and reliefs, built where
##   listed, never on a hazard;
## - the floor carries the still floor's motion cues.

const PALACE_SKIN_PATH: String = "res://data/skins/golden_palace_skin.tres"
const PALACE_LEVEL_PATH: String = "res://data/levels/golden_3.tres"
## Lit (non-glowing) surfaces stay below this chroma (brightest minus darkest channel); the fence
## pink is about 0.8 (the same budget test_golden_skin uses for the Golden Zone).
const MAX_SURFACE_CHROMA: float = 0.45
const GLOW_SATURATION_LIMIT: float = 0.35
## Gaps: the darkest golden_metal() draws a gold (kit_golden.gdshaderinc), and how much darker than
## the darkest floor a gap's inside must stay (linear luminance).
const GOLD_DARKEST: float = 0.5
const GAP_CONTRAST: float = 0.35
## The emblem is shown openly and large (GDD §5): never smaller than this on the walls.
const EMBLEM_MIN_SIZE: float = 2.0


func run() -> void:
	var skin := load(PALACE_SKIN_PATH) as GoldenPalaceSkin
	check(skin != null, "the Golden Palace skin loads")
	if skin == null:
		return
	check(skin.enemy_variant == &"golden" and CyborgSuit.look_for(skin.enemy_variant) == CyborgSuit.GOLDEN,
		"the palace's cyborgs wear the ceremonial enforcer (GDD §9.2), inherited from the Golden Zone")
	var level := load(PALACE_LEVEL_PATH) as LevelConfig
	check(level != null and level.skin == skin, "Golden 3 (the Golden Palace) is set to use it")
	start_error_count()
	var env: Environment = skin.make_environment()
	check(env != null and env.sky != null and env.glow_enabled and env.fog_enabled,
		"the palace's environment has a sky, glow and fog (inherited from the Golden Zone)")
	var sky_material: ShaderMaterial = env.sky.sky_material as ShaderMaterial
	check(sky_material != null and float(sky_material.get_shader_parameter(&"star_amount")) == 0.0
		and absf(float(sky_material.get_shader_parameter(&"moon_radius"))) < 0.001,
		"no stars or moon in the vast interior")
	for lanes: int in [3, 5, 6]:
		await whole_level(skin, "golden palace", PALACE_LEVEL_PATH, lanes)
	await hazards_and_triggers(skin)
	await _surfaces(skin)
	await _gaps(skin)
	await _clear_play_space(skin)
	_statues(skin)
	_ceiling_kinds(skin)
	await _cult(skin)
	await determinism(skin, PALACE_LEVEL_PATH)
	stop_error_count("building golden palace levels")


## Over a whole level (Golden 3, 5 lanes, chunk by chunk): glowing surfaces keep off the hazard hues
## (the orange edges aside); lit ones stay desaturated; nothing gold, marble, coffered or cloth ever
## glows; no surface uses the grille (vent) pattern; only hazard signs wear the striped frame; the
## emblem never sits on a hazard; the floor's drifting particles are there.
func _surfaces(skin: GoldenPalaceSkin) -> void:
	var found := {"grilles": 0, "stripes": 0, "drift": 0, "emblems": 0, "hazard_hues": [], "loud": [], "glowing": [],
		"on_hazards": 0}
	var solid: Material = skin.solid_material()
	var glow: Material = skin.glow_material()
	var edge: Color = skin.gap_edge_color
	var never_glow: Array[int] = [MeshKit.PAT_GOLD, MeshKit.PAT_MARBLE, MeshKit.PAT_PALACE_FLOOR, MeshKit.PAT_PALACE_WELL,
		MeshKit.PAT_PALACE_PANEL, MeshKit.PAT_EMBLEM, MeshKit.PAT_COFFER, MeshKit.PAT_CLOTH]
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
				if c.a > 0.0 and not in_hazard and not in_trigger and never_glow.has(pattern) and found["glowing"].size() < 4:
					found["glowing"].append("%s pattern %d at %s" % [c, pattern, m.global_transform * verts[i]])
				if c.a == 0.0 and not in_hazard and not in_trigger and _chroma(c) > MAX_SURFACE_CHROMA and found["loud"].size() < 4:
					found["loud"].append("%s at %s" % [c, m.global_transform * verts[i]])
			var glowing: bool = material == glow or c.a > 0.0
			if glowing and not in_hazard and not in_trigger and _hazard_hue(c) and not _same_rgb(c, edge) \
					and found["hazard_hues"].size() < 4:
				found["hazard_hues"].append("%s at %s" % [c, m.global_transform * verts[i]])
	await visit_level(level(PALACE_LEVEL_PATH, 5, 0.6, 4), skin, visit)
	check(found["grilles"] == 0, "nothing vent-like: no surface uses the grille pattern (%d vertices)" % found["grilles"])
	check(found["stripes"] == 0, "only hazard signs wear the striped frame (%d striped vertices elsewhere)" % found["stripes"])
	check(found["hazard_hues"].is_empty(), "nothing but hazards (and the orange edges) glows in a hazard hue: %s" % ", ".join(
		found["hazard_hues"]))
	check(found["loud"].is_empty(), "lit surfaces stay desaturated: %s" % ", ".join(found["loud"]))
	check(found["glowing"].is_empty(), "gold, marble, coffered surfaces and cloth never glow (GDD §5): %s" % ", ".join(
		found["glowing"]))
	check(found["emblems"] > 0 and found["on_hazards"] == 0, "the emblem is shown (%d vertices), never on a hazard (%d)" % [
		found["emblems"], found["on_hazards"]])
	check(found["drift"] > 0, "the hall's floor carries drifting dust motes, glints and speed streaks (%d vertices)" % found["drift"])


## Gaps read as holes at a glance (CLAUDE.md readability rules): whatever a gap shows is in deep
## shade, far darker than any floor can be drawn, and nothing in it glows but the orange edge; no
## floor is drawn in (or near) the edge's colour; the showcase gap carries the full orange edge on
## both sides. Checked over whole levels at 3 and 5 lanes.
func _gaps(skin: GoldenPalaceSkin) -> void:
	var darkest: float = _linear_luminance(_darkest_gold(skin.stone_colors[0]))
	var inside: float = _linear_luminance(skin.gap_inside_color)
	check(inside < darkest * GAP_CONTRAST, "a gap's inside stays far darker than the darkest floor: %.4f vs %.4f" % [
		inside, darkest])
	var like_edge: PackedStringArray = []
	var surfaces: Array[Color] = [skin.gold_color, skin.gold_shine_color, skin.coffer_color, skin.rib_color]
	surfaces.append_array(Array(skin.stone_colors))
	for c: Color in surfaces:
		if _near_colour(c, skin.gap_edge_color):
			like_edge.append(str(c))
	check(like_edge.is_empty(), "no floor is drawn in the gap edge's colour: %s" % ", ".join(like_edge))
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
					if p.y < -0.001 and colors[i].a >= GoldenPalaceFloor.STRIP_GLOW - 0.001:
						strip = Vector2(minf(strip.x, p.y), maxf(strip.y, p.y))
					elif absf(p.y) < 0.001 and colors[i].a >= GoldenPalaceFloor.LIP_GLOW - 0.001:
						lip = Vector2(minf(lip.x, -p.z), maxf(lip.y, -p.z))
				elif absf(-p.z - 50.0) <= 0.3 and absf(p.y) < 0.001 and colors[i].a >= GoldenPalaceFloor.LIP_GLOW - 0.001:
					near_lip = Vector2(minf(near_lip.x, -p.z), maxf(near_lip.y, -p.z))
	check(strip.y - strip.x >= GoldenPalaceFloor.STRIP_HEIGHT - 0.001 and strip.y > -0.05,
		"the far edge's orange strip runs along the top of its face: %s" % strip)
	check(lip.x > 56.99 and lip.y - lip.x >= GoldenPalaceFloor.EDGE_LIP - 0.001,
		"the far edge's orange lip lies on the floor right at the collision edge: %s" % lip)
	check(near_lip.y < 50.01 and near_lip.y - near_lip.x >= GoldenPalaceFloor.EDGE_LIP - 0.001,
		"the near edge's orange lip ends right at the collision edge: %s" % near_lip)
	check(halo, "the far edge carries its orange halo toward the approaching runner")
	await free_track(track)
	for lanes: int in [3, 5]:
		var layout: LevelLayout = level(PALACE_LEVEL_PATH, lanes, 0.6, 9)
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
					under += _check_below_floor(chunk, skin, layout.length, inside + 0.0001, bad)
			d += TrackBuilder.CHUNK_LENGTH
		check(bad.is_empty() and under > 0, "below the floor there is only deep shade and the orange edge " +
			"(%d lanes, %d vertices): %s" % [lanes, under, ", ".join(bad)])
		world.queue_free()
		await tree.process_frame


## Checks every vertex of the skin's meshes in `chunk` below the floor (hazards and triggers aside,
## and the finish gantry's posts at `finish`): the shade, an orange strip, the halo. Returns how
## many there were; problems (up to four) go to `bad`.
func _check_below_floor(chunk: Node, skin: GoldenPalaceSkin, finish: float, shade: float, bad: PackedStringArray) -> int:
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
					var strip: bool = _same_rgb(c, skin.gap_edge_color) and c.a >= GoldenPalaceFloor.STRIP_GLOW - 0.001
					var dark: bool = pattern == MeshKit.PAT_PALACE_WELL and c.a == 0.0 and _linear_luminance(c) <= shade
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


## Between the floor and the ceiling, over the lanes, the skin builds nothing solid but hazards and
## triggers, anywhere in a whole level; and nothing sticks out of the walls below frieze_top, the
## colonnade's entablature (the same calm band every zone keeps).
func _clear_play_space(skin: GoldenPalaceSkin) -> void:
	for lanes: int in [3, 6]:
		var layout: LevelLayout = level(PALACE_LEVEL_PATH, lanes, 0.6, 5)
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
		check(sticking.is_empty(), "nothing sticks out of the walls below frieze_top (%d lanes): %s" % [lanes,
			", ".join(sticking)])
		world.queue_free()
		await tree.process_frame


func _find_intruders(chunk: Node, skin: GoldenPalaceSkin, geo: TrackGeometry, finish: float, out: PackedStringArray,
		sticking: PackedStringArray) -> void:
	var half: float = geo.half_width()
	var wall: float = geo.wall_x()
	var band_top: float = minf(skin.frieze_top - 0.05, tuning.ceiling_height - 0.1)
	for node: Node in nodes_of(chunk, func(n: Node) -> bool: return n is MeshInstance3D):
		var m := node as MeshInstance3D
		if m.mesh == null or m.is_in_group(&"debug_hitbox") or _under(m, func(n: Node) -> bool: return n is Area3D):
			continue
		for s: int in m.mesh.get_surface_count():
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


## Statues stand only in an alcove above statue_min_height, in a decorative pose, and never glow;
## statue_spots() lists exactly where the built walls put them, in the same niche shape a live
## Gilded Sentinel's uses (GoldenStatue.niche(), task C4).
func _statues(skin: GoldenPalaceSkin) -> void:
	var wall_run_top: float = tuning.wall_max_height + tuning.visual_size.y
	check(skin.statue_min_height >= wall_run_top + 2.0, "decorative statues stand far above the wall-run band " +
		"(from %.1f m; a wall run reaches %.1f m)" % [skin.statue_min_height, wall_run_top])
	var geo := TrackGeometry.new(5, tuning)
	var count: int = 0
	var poses: Dictionary = {}
	var low: PackedStringArray = []
	for side: int in [-1, 1]:
		var spots: Array[Dictionary] = skin.statue_spots(side, side * geo.wall_x(), 0.0, 1600.0)
		check(spots == skin.statue_spots(side, side * geo.wall_x(), 0.0, 1600.0), "statues stand in the same places every time")
		for s: Dictionary in spots:
			count += 1
			poses[s["pose"]] = true
			var c: Vector3 = s["center"]
			if c.y < skin.statue_min_height - 0.001 or not GoldenStatue.DECORATIVE.has(s["pose"]):
				low.append("%s %s" % [c, s["pose"]])
	check(count > 20 and poses.size() == GoldenStatue.DECORATIVE.size() and low.is_empty(),
		"%d decorative statues over 1.6 km of both walls, in all %d poses, all above statue_min_height: %s" % [count,
			poses.size(), ", ".join(low)])
	var batch := MeshBatch.new()
	skin.walls().build(batch, 1, geo.wall_x(), 0.0, 400.0)
	var layer: MeshLayer = batch.layer(skin.solid_material())
	var spots: Array[Dictionary] = skin.statue_spots(1, geo.wall_x(), 0.0, 400.0)
	var missing: int = 0
	for s: Dictionary in spots:
		var c: Vector3 = s["center"]
		var head: bool = false
		for i: int in layer.size():
			var p: Vector3 = layer.verts[i]
			if absf(p.x - c.x) < 0.6 and absf(p.z - c.z) < 0.6 and p.y > c.y + GoldenStatue.STATURE * 0.8 \
					and roundi(layer.uv2s[i].x) == MeshKit.PAT_GOLD:
				head = true
				break
		if not head:
			missing += 1
	check(not spots.is_empty() and missing == 0, "every listed statue is built in its alcove (%d of %d missing)" % [missing,
		spots.size()])
	var lit: bool = true
	for pose: StringName in GoldenStatue.DECORATIVE:
		for c: Color in skin.statues().mesh(GoldenStatue.pose_named(pose)).colors:
			lit = lit and c.a == 0.0
	check(lit, "decorative statues never glow: their eyes are dark bronze (only a live Sentinel's glow red)")


## The ceiling pieces' weights (GDD §5): a bridge or an archway needs every lane (over fewer lanes
## both fold into the narrower balcony); a chandelier (the yacht's weight, reused) hangs over any
## width. test_ceilings sweeps every skin's full mesh-building rules; this checks only the choice.
func _ceiling_kinds(skin: GoldenPalaceSkin) -> void:
	var lane_w: float = tuning.lane_width
	var wall_x: float = 3.0 * lane_w + tuning.wall_margin
	var kinds_full: Dictionary = {}
	var kinds_narrow: Dictionary = {}
	for i: int in 300:
		var z: float = -(100.0 + i * 7.3)
		var full := Vector3(6.0 * lane_w, TrackBuilder.HULL_THICKNESS, 40.0 + float(i % 5) * 4.0)
		kinds_full[skin.palace_ceilings().kind_of(Vector3(0, 6.4, z), full, wall_x)] = true
		var narrow := Vector3(2.0 * lane_w, TrackBuilder.HULL_THICKNESS, full.z)
		kinds_narrow[skin.palace_ceilings().kind_of(Vector3(lane_w, 6.4, z), narrow, wall_x)] = true
	check(kinds_full.size() == 3 and not kinds_narrow.has(GoldenPalaceCeilings.Kind.ARCHWAY)
		and not kinds_narrow.has(GoldenPalaceCeilings.Kind.BRIDGE) and kinds_narrow.has(GoldenPalaceCeilings.Kind.BALCONY)
		and kinds_narrow.has(GoldenPalaceCeilings.Kind.CHANDELIER),
		"full-width ceilings mix bridges, archways and chandeliers; narrow ones become balconies or chandeliers, never archways")
	check(skin.palace_ceilings().headroom() == skin.hall_clear_height, "ceiling pieces keep hall_clear_height above their underside")


## The cult's emblem (GDD §5) is the owner's choice, shown in the colonnade's galleries and reliefs,
## large, built where listed; the feed plays in some galleries with the shared material.
func _cult(skin: GoldenPalaceSkin) -> void:
	check(skin.feed_material() == CultFeed.material(), "the Golden Palace plays the shared feed")
	var geo := TrackGeometry.new(5, tuning)
	var kinds: Dictionary = {}
	var small: PackedStringArray = []
	for side: int in [-1, 1]:
		for e: Dictionary in skin.cult_emblems(side, side * geo.wall_x(), 0.0, 1600.0):
			kinds[e["kind"]] = int(kinds.get(e["kind"], 0)) + 1
			if float(e["size"]) < EMBLEM_MIN_SIZE:
				small.append("%s %.2f m at %s" % [e["kind"], e["size"], e["center"]])
	check(kinds.has(&"relief") and kinds.has(&"frame"), "the emblem is shown openly in galleries and reliefs: %s" % kinds)
	check(small.is_empty(), "every emblem is %.1f m across or more: %s" % [EMBLEM_MIN_SIZE, ", ".join(small.slice(0, 4))])
	var found_feed: int = 0
	for side: int in [-1, 1]:
		found_feed += skin.feed_boards(side, side * geo.wall_x(), 0.0, 1600.0).size()
	check(found_feed > 0, "the cult's feed plays in some of the galleries (%d over 1.6 km of both walls)" % found_feed)
	var batch := MeshBatch.new()
	var face_x: float = -geo.wall_x()
	skin.walls().build(batch, -1, face_x, 0.0, 600.0)
	var centres: Array[Vector3] = _emblem_centres(batch.layer(skin.solid_material()))
	var listed: Array[Dictionary] = skin.cult_emblems(-1, face_x, 0.0, 600.0)
	var missing: PackedStringArray = []
	for e: Dictionary in listed:
		var found: bool = false
		for c: Vector3 in centres:
			found = found or c.distance_to(e["center"]) < 0.05
		if not found:
			missing.append("%s at %s" % [e["kind"], e["center"]])
	check(not listed.is_empty() and missing.is_empty(), "every listed relief emblem is built where listed (%d): %s" % [
		listed.size(), ", ".join(missing)])


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


## golden_metal()'s darkest rendering of a gold (see GOLD_DARKEST): a quarter greyed, halved.
static func _darkest_gold(c: Color) -> Color:
	var grey: float = c.r * 0.3 + c.g * 0.55 + c.b * 0.15
	return c.lerp(Color(grey, grey, grey), 0.25) * Color(GOLD_DARKEST, GOLD_DARKEST, GOLD_DARKEST)


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


## Whether `c` could pass for `target` (a saturated hazard colour): close in RGB, or as saturated
## and within 25 degrees of its hue.
static func _near_colour(c: Color, target: Color) -> bool:
	if _rgb_distance(c, target) < 0.35:
		return true
	var dh: float = absf(c.h - target.h)
	return c.s > 0.5 and minf(dh, 1.0 - dh) < 25.0 / 360.0

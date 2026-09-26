extends SkinSuite
## The Marketplace skin (MarketplaceSkin, Zone 3), which the Marketplace zone uses. The shared skin
## checks (SkinSuite) over the whole of Marketplace 2 for 3, 5 and 6 lanes, then the Marketplace's own:
## - gaps keep the orange edge glow right on the collision edge, and read as holes: everything under
##   the stall roofs is in deep shade, far darker than any roof, nothing in there glows but the
##   orange edge, and no roof is drawn in the edge's colour;
## - the colour rule (GDD §5): nothing but hazards glows in a hazard hue (pink, red, orange, yellow,
##   green, cyan), and lit surfaces stay well below the hazards' saturation;
## - the play space stays clear: between the floor and the ceiling over the lanes there is nothing
##   but hazards and triggers, so no decoration looks like an obstacle;
## - decorative signs, ads and lights are unframed and never below decor_min_height, and only
##   hazard signs wear the striped frame;
## - nothing vent-like is drawn (in the Marketplace, wall vents are sewer-screech lairs);
## - the shop windows for the citizens (task D3) are where shop_windows() says, above the vent zone;
## - every kind of ceiling builds from the lanes it covers, full width or narrow (task B3): a flat
##   underside over exactly its lanes, the orange end band, the lane seams;
## - the cult's emblem is the owner's choice (data/world/cult_emblem_choice.tres) in its own colours,
##   hidden here and there in ads and shop signs, never smaller than emblem_min_size;
## - the cult's feed (CultFeed) plays on billboards and ads high up and on TVs in some shop windows,
##   and nowhere else;
## - the still floor carries drifting dust and speed streaks.

const MARKET_SKIN_PATH: String = "res://data/skins/marketplace_skin.tres"
const MARKET_ZONE_PATH: String = "res://data/zones/marketplace.tres"
## The Marketplace's campaign level with the most in it (Marketplace 2 adds wall vents and wall fences).
const MARKET_LEVEL_PATH: String = "res://data/levels/marketplace_2.tres"
## Lit (non-glowing) surfaces stay below this chroma (brightest minus darkest channel); the fence
## pink is about 0.8.
const MAX_SURFACE_CHROMA: float = 0.45
## A glowing colour this saturated (HSV) must keep to the decorative hues (blue to violet).
const GLOW_SATURATION_LIMIT: float = 0.35
## Gaps: the roof shading's lowest broad factor (a stall's eaves and the shaded half of its tent;
## kit_market.gdshaderinc, mk_tent), PAT_UNDER's brightest factor (the top of a face, at the lip),
## and how much darker than the darkest roof a gap's inside must stay (linear luminance).
const ROOF_SHADE_MIN: float = 0.7
const UNDER_MAX_FACTOR: float = 0.9
const GAP_CONTRAST: float = 0.35


func run() -> void:
	var skin := load(MARKET_SKIN_PATH) as MarketplaceSkin
	check(skin != null, "the marketplace skin loads")
	if skin == null:
		return
	# DESIGN-TBD placeholder (docs/questions/d2.md): Marketplace cyborgs dress as citizens.
	check(skin.enemy_variant == &"city" and MarketplaceSkin.new().enemy_variant == &"city",
		"marketplace enemies wear the city look (placeholder)")
	var zone := load(MARKET_ZONE_PATH) as ZoneDef
	check(zone != null and zone.skin is MarketplaceSkin, "the Marketplace zone uses the marketplace skin")
	start_error_count()
	var env: Environment = skin.make_environment()
	check(env != null and env.sky != null and env.glow_enabled and env.fog_enabled,
		"the marketplace environment has a sky, glow and fog")
	_palette(skin)
	for lanes: int in [3, 5, 6]:
		await whole_level(skin, "marketplace", MARKET_LEVEL_PATH, lanes)
	await hazards_and_triggers(skin)
	await _surfaces(skin)
	await _gaps(skin)
	await _clear_play_space(skin)
	await _shop_windows(skin)
	_ceilings(skin)
	_cult_emblem(skin)
	await _cult_feed(skin)
	_stall_layout(skin)
	await determinism(skin, MARKET_LEVEL_PATH)
	stop_error_count("building marketplace levels")


## The skin's decorative colours keep to the colour rule before anything is built.
func _palette(skin: MarketplaceSkin) -> void:
	var glowing: Array[Color] = [skin.lamp_color, skin.bulb_color, skin.window_warm_color, skin.ceiling_lamp_color,
		skin.engine_color]
	glowing.append_array(Array(skin.neon_colors))
	glowing.append_array(Array(skin.ad_colors))
	# Sign faces glow a little: inside the hazard frame, but kept off the other hazard hues too.
	glowing.append_array(Array(skin.sign_content_colors))
	var bad: PackedStringArray = []
	for c: Color in glowing:
		if _hazard_hue(c):
			bad.append(str(c))
	check(bad.is_empty(), "decorative lights, neon and ads keep to warm white, blue and violet: %s" % ", ".join(bad))
	var lit: Array[Color] = []
	for list: PackedColorArray in [skin.canvas_colors, skin.awning_colors, skin.stucco_colors, skin.shutter_colors,
			skin.painted_sign_colors, skin.pennant_colors, skin.cargo_colors, skin.sign_content_colors]:
		lit.append_array(Array(list))
	var loud: PackedStringArray = []
	for c: Color in lit:
		if _chroma(c) > MAX_SURFACE_CHROMA:
			loud.append(str(c))
	check(loud.is_empty(), "lit surfaces stay well below the hazards' saturation: %s" % ", ".join(loud))
	check(_chroma(skin.fence_color) > MAX_SURFACE_CHROMA + 0.3, "the fence pink is far more saturated than any surface")


## Over the showcase track (every kind of piece): the gap in lane 3 (50-57 m) has the orange edge
## glow on both edges; glowing surfaces keep off the hazard hues; lit ones stay desaturated; no
## surface uses the grille (vent) pattern; decorative signs are high; only hazards wear stripes;
## the drifting particles are there.
func _surfaces(skin: MarketplaceSkin) -> void:
	var track: TrackBuilder = showcase_track(skin)
	var lane := Vector2(1.2, 3.6)
	var edges: Dictionary = {}
	var grilles: int = 0
	var stripes: int = 0
	var low_signs: PackedStringArray = []
	var hazard_hues: PackedStringArray = []
	var loud: PackedStringArray = []
	var drift_vertices: int = 0
	var solid: Material = skin.solid_material()
	var glow: Material = skin.glow_material()
	var signs := [MeshKit.PAT_GLYPHS, MeshKit.PAT_AD, MeshKit.PAT_BULBS, MeshKit.PAT_SHOPSIGN]
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
	check(low_signs.is_empty(), "decorative signs, ads and bulbs stay above %.1f m: %s" % [skin.decor_min_height,
		", ".join(low_signs)])
	check(hazard_hues.is_empty(), "nothing but hazards (and the orange edges) glows in a hazard hue: %s" % ", ".join(hazard_hues))
	check(loud.is_empty(), "lit surfaces stay desaturated: %s" % ", ".join(loud))
	check(drift_vertices > 0, "the stalls carry drifting dust and speed streaks (%d vertices)" % drift_vertices)
	# The facade shader's lights come from uniforms, not vertices: they keep to the rule too.
	var facade: ShaderMaterial = skin.facade_material()
	var lights: PackedStringArray = []
	for u: String in ["window_warm", "bulb_color", "neon_a", "neon_b"]:
		var c: Color = facade.get_shader_parameter(u)
		if _hazard_hue(c):
			lights.append("%s %s" % [u, c])
	check(lights.is_empty(), "the facades' lights keep off the hazard hues: %s" % ", ".join(lights))
	await free_track(track)


## Gaps read as holes at a glance, as in every zone (CLAUDE.md readability rules): whatever a gap
## shows is in deep shade, far darker than any roof can be drawn, and nothing in it glows but the
## orange strip along the edge; no roof is drawn in (or near) the edge's colour; and the far edge of
## the showcase gap carries the full orange edge: the lip on the roof and the strip below it. Checked
## over a whole level: below the roofs there is nothing but the shade and the strips.
func _gaps(skin: MarketplaceSkin) -> void:
	var roofs: Array[Color] = [skin.tin_color * Color(0.92, 0.92, 0.92), skin.awning_stripe_color, skin.seam_color,
		skin.ledge_color]
	roofs.append_array(Array(skin.canvas_colors))
	roofs.append_array(Array(skin.awning_colors))
	var darkest: float = INF
	var like_edge: PackedStringArray = []
	for c: Color in roofs:
		darkest = minf(darkest, _linear_luminance(c * Color(ROOF_SHADE_MIN, ROOF_SHADE_MIN, ROOF_SHADE_MIN)))
		if _near_colour(c, skin.gap_edge_color):
			like_edge.append(str(c))
	var inside: float = _linear_luminance(skin.gap_inside_color * Color(UNDER_MAX_FACTOR, UNDER_MAX_FACTOR, UNDER_MAX_FACTOR))
	check(inside < darkest * GAP_CONTRAST, "a gap's inside stays far darker than the darkest roof: %.4f vs %.4f" % [
		inside, darkest])
	check(like_edge.is_empty(), "no roof is drawn in the gap edge's colour: %s" % ", ".join(like_edge))
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
				if p.y < -0.001 and colors[i].a >= MarketStalls.STRIP_GLOW - 0.001:
					strip = Vector2(minf(strip.x, p.y), maxf(strip.y, p.y))
				elif absf(p.y) < 0.001 and colors[i].a >= MarketStalls.LIP_GLOW - 0.001:
					lip = Vector2(minf(lip.x, -p.z), maxf(lip.y, -p.z))
	check(strip.y - strip.x >= MarketStalls.STRIP_HEIGHT - 0.001 and strip.y > -0.05,
		"the far edge's orange strip runs along the top of its face: %s" % strip)
	check(lip.x > 56.99 and lip.y - lip.x >= MarketStalls.EDGE_LIP - 0.001,
		"the far edge's orange lip lies on the roof right at the collision edge: %s" % lip)
	await free_track(track)
	# A whole level, chunk by chunk: below the roofs only the shade (PAT_UNDER, no brighter than the
	# skin's gap_inside_color, unlit) and the orange strips.
	var layout: LevelLayout = level(MARKET_LEVEL_PATH, 5, 0.6, 9)
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
				under += _check_under_roofs(chunk, skin, layout.length, bad)
		d += TrackBuilder.CHUNK_LENGTH
	check(bad.is_empty() and under > 0, "below the stall roofs there is only deep shade and the orange strips (%d vertices): %s" % [
		under, ", ".join(bad)])
	world.queue_free()
	await tree.process_frame


## Checks every vertex of the skin's meshes in `chunk` below the roofs (hazards and triggers aside,
## and the finish gantry's posts at `finish`, which stand on the ledges where no gap ever is): the
## shade or an orange strip. Returns how many there were; problems (up to four) go to `bad`.
func _check_under_roofs(chunk: Node, skin: MarketplaceSkin, finish: float, bad: PackedStringArray) -> int:
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
					var strip: bool = _same_rgb(c, skin.gap_edge_color) and c.a >= MarketStalls.STRIP_GLOW - 0.001
					var dark: bool = roundi(uv2[i].x) == MeshKit.PAT_UNDER and c.a == 0.0 and _linear_luminance(c) <= shade
					if not strip and not dark:
						what = "%s pattern %d" % [c, roundi(uv2[i].x)]
				elif material != skin.drift_material():
					what = "material %s" % material.resource_path.get_file() if material != null else "no material"
				if what != "" and bad.size() < 4:
					bad.append("%s at %s" % [what, p])
	return count


## Between the floor and the ceiling, over the lanes, the skin builds nothing solid but hazards and
## triggers, anywhere in a whole level: stall roofs are flat, gap faces hang below the roofs,
## ceilings keep above their undersides, and walls, signs and awnings stay outside the lanes or up high.
func _clear_play_space(skin: MarketplaceSkin) -> void:
	for lanes: int in [3, 6]:
		var layout: LevelLayout = level(MARKET_LEVEL_PATH, lanes, 0.6, 5)
		var world := Node3D.new()
		tree.root.add_child(world)
		var track := TrackBuilder.new()
		world.add_child(track)
		track.set_layout(layout, tuning, skin)
		var half: float = TrackGeometry.new(lanes, tuning).half_width()
		var intruders: PackedStringArray = []
		var seen: Dictionary = {}
		var d: float = 0.0
		while d <= layout.length + TrackBuilder.RUN_OUT + TrackBuilder.CHUNK_LENGTH:
			track.update(d, d / tuning.run_speed)
			for chunk: Node in track.get_children():
				if not seen.has(chunk):
					seen[chunk] = true
					_find_intruders(chunk, skin, half, intruders)
			d += TrackBuilder.CHUNK_LENGTH
		check(intruders.is_empty(), "nothing decorative stands in the play space (%d lanes, %d chunks): %s" % [lanes,
			seen.size(), ", ".join(intruders)])
		world.queue_free()
		await tree.process_frame


## Solid vertices of the skin's meshes in `chunk` that lie over the lanes between the floor and the
## ceiling (up to four, appended to `out`).
func _find_intruders(chunk: Node, skin: MarketplaceSkin, half: float, out: PackedStringArray) -> void:
	for node: Node in nodes_of(chunk, func(n: Node) -> bool: return n is MeshInstance3D):
		var m := node as MeshInstance3D
		if m.mesh == null or m.is_in_group(&"debug_hitbox") or _under(m, func(n: Node) -> bool: return n is Area3D):
			continue
		for s: int in m.mesh.get_surface_count():
			# Drifting dust and additive light (lamp halos, engine glow) aren't objects.
			var material: Material = m.mesh.surface_get_material(s)
			if material == skin.drift_material() or material == skin.glow_material():
				continue
			var verts: PackedVector3Array = m.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			for v: Vector3 in verts:
				var p: Vector3 = m.global_transform * v
				if absf(p.x) < half - 0.01 and p.y > 0.06 and p.y < tuning.ceiling_height - 0.1 and out.size() < 4:
					out.append(str(p))


## The citizens' windows (task D3): where shop_windows() says, the same every time, above the wall
## vents' zone, one after another along the wall, and really open in the built wall (a display's
## back wall behind each).
func _shop_windows(skin: MarketplaceSkin) -> void:
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


## Every kind of ceiling, over every number of lanes from one to six, full width or narrow and off
## centre (task B3): a flat underside covering exactly its lanes, nothing hanging below it but flush
## lamps and seams, the orange band at its far end, and a seam under each lane boundary.
func _ceilings(skin: MarketplaceSkin) -> void:
	var lane_w: float = tuning.lane_width
	var wall_x: float = 3.0 * lane_w + tuning.wall_margin
	var problems: PackedStringArray = []
	for kind: int in [MarketCeilings.Kind.BRIDGE, MarketCeilings.Kind.OVERPASS, MarketCeilings.Kind.SHIP,
			MarketCeilings.Kind.AD]:
		for lanes: int in range(1, 7):
			if kind == MarketCeilings.Kind.BRIDGE and lanes != 6:
				continue
			var offset: float = 0.0 if lanes == 6 else (6 - lanes) * lane_w * 0.5 * (1.0 if lanes % 2 == 0 else -1.0)
			var size := Vector3(lanes * lane_w, TrackBuilder.HULL_THICKNESS, 30.0)
			var edges: Array[float] = []
			for k: int in range(1, lanes):
				edges.append(offset - size.x * 0.5 + k * lane_w)
			var mesh: ArrayMesh = skin.ceilings().mesh_for(kind, 1, size, edges, offset, wall_x, tuning.ceiling_height)
			var tag: String = "kind %d, %d lanes" % [kind, lanes]
			var under := {"min_x": INF, "max_x": -INF, "lowest": 0.0, "band": false, "seams": 0}
			for s: int in mesh.get_surface_count():
				var arrays: Array = mesh.surface_get_arrays(s)
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
				var glow_surface: bool = mesh.surface_get_material(s) == skin.glow_material()
				for i: int in verts.size():
					var v: Vector3 = verts[i]
					if not glow_surface:
						under["lowest"] = minf(under["lowest"], v.y)
					if absf(v.y) < 0.001 and not glow_surface:
						under["min_x"] = minf(under["min_x"], v.x)
						under["max_x"] = maxf(under["max_x"], v.x)
						if _same_rgb(colors[i], skin.gap_edge_color) and v.z < -size.z * 0.5 + MarketCeilings.END_BAND + 0.01:
							under["band"] = true
			var reach: float = size.x * 0.5 + 0.15
			var full: bool = kind == MarketCeilings.Kind.BRIDGE
			var want: float = wall_x if full else reach
			if absf(under["min_x"] + want) > 0.02 or absf(under["max_x"] - want) > 0.02:
				problems.append("%s: underside spans %.2f..%.2f, not ±%.2f" % [tag, under["min_x"], under["max_x"], want])
			if under["lowest"] < -0.06:
				problems.append("%s: something hangs %.2f m below the surface" % [tag, under["lowest"]])
			if not under["band"]:
				problems.append("%s: no orange band at the far end" % tag)
			if problems.size() > 6:
				break
			# Seams: a darker strip centred on each lane boundary.
			for x: float in edges:
				if not _has_seam(mesh, x - offset, skin):
					problems.append("%s: no seam at x %.2f" % [tag, x - offset])
	check(problems.is_empty(), "every kind of ceiling builds from its lanes, full width or narrow:\n  %s" % "\n  ".join(problems))
	# Only a ceiling across every lane may become a building bridging the street.
	var bridged: int = 0
	var narrow_bridged: int = 0
	for i: int in 200:
		var z: float = -(100.0 + i * 7.3)
		var full := Vector3(6.0 * lane_w, TrackBuilder.HULL_THICKNESS, 40.0 + float(i % 5) * 4.0)
		if skin.ceilings().kind_of(Vector3(0, 6.4, z), full, wall_x) == MarketCeilings.Kind.BRIDGE:
			bridged += 1
		var narrow := Vector3(2.0 * lane_w, TrackBuilder.HULL_THICKNESS, full.z)
		if skin.ceilings().kind_of(Vector3(lane_w, 6.4, z), narrow, wall_x) == MarketCeilings.Kind.BRIDGE:
			narrow_bridged += 1
	check(bridged > 20 and narrow_bridged == 0, "only full-width ceilings become bridging buildings (%d of 200 full, %d narrow)" % [
		bridged, narrow_bridged])


## The cult's emblem (GDD §5): the owner's choice, never hardcoded, in its scheme's warm-white neon
## or unlit bronze; over a long street it turns up both ways, each at least emblem_min_size across
## (smaller, its three-fold shape could read like the radiation trefoil) and small beside its ad.
func _cult_emblem(skin: MarketplaceSkin) -> void:
	var choice := load(MarketplaceSkin.CULT_EMBLEM_CHOICE_PATH) as CultEmblemChoice
	check(choice != null, "the cult emblem choice loads")
	if choice == null:
		return
	var scheme: Dictionary = CultEmblem.default_scheme(choice.option)
	var reference: ArrayMesh = CultEmblem.build_mesh(choice.option, 1.0, Color.WHITE, Color.WHITE, 0.0,
		skin.solid_material())
	var count: int = reference.surface_get_array_len(0)
	var neon: MeshLayer = skin.cult_emblem(true)
	var bronze: MeshLayer = skin.cult_emblem(false)
	check(neon.size() == count and bronze.size() == count and neon.verts == reference.surface_get_arrays(0)[Mesh.ARRAY_VERTEX],
		"the skin draws the chosen emblem's geometry (option %s)" % CultEmblem.option_letter(choice.option))
	var colours_ok: bool = true
	for i: int in count:
		colours_ok = colours_ok and (_same_rgb(neon.colors[i], scheme["neon"]) or _same_rgb(neon.colors[i], scheme["neon_accent"]))
		colours_ok = colours_ok and is_equal_approx(neon.colors[i].a, skin.emblem_glow) and bronze.colors[i].a == 0.0
		colours_ok = colours_ok and (_same_rgb(bronze.colors[i], scheme["metal"]) or _same_rgb(bronze.colors[i], scheme["metal_accent"]))
	check(colours_ok, "the emblem glows only in its warm-white neon, or is unlit bronze")
	# Find every emblem over 3 km of both walls and on every floating ad's screen.
	var unit: float = maxf(reference.get_aabb().size.x, reference.get_aabb().size.y)
	var sizes: Array[float] = []
	var lit: int = 0
	var unlit: int = 0
	var layers: Array[MeshLayer] = []
	for side: int in [-1, 1]:
		var d: float = 0.0
		while d < 3000.0:
			var batch := MeshBatch.new()
			skin.facades().build(batch, side, side * 6.3, d, d + 40.0)
			layers.append(batch.layer(skin.solid_material()))
			d += 40.0
	for variant: int in 4:
		var mesh: ArrayMesh = skin.ceilings().mesh_for(MarketCeilings.Kind.AD, variant, Vector3(12.0, 0.8, 40.0), [], 0.0,
			6.3, 6.0)
		var ad := MeshLayer.new()
		for s: int in mesh.get_surface_count():
			if mesh.surface_get_material(s) == skin.solid_material():
				var arrays: Array = mesh.surface_get_arrays(s)
				ad.verts = arrays[Mesh.ARRAY_VERTEX]
				ad.colors = arrays[Mesh.ARRAY_COLOR]
		layers.append(ad)
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
			if is_neon:
				lit += 1
			else:
				unlit += 1
			i += count
	check(lit > 0 and unlit > 0, "the emblem hides in the market: %d lit and %d unlit over 3 km and the floating ads" % [lit, unlit])
	var smallest: float = INF
	var largest: float = 0.0
	for size: float in sizes:
		smallest = minf(smallest, size)
		largest = maxf(largest, size)
	check(sizes.is_empty() or (smallest >= skin.emblem_min_size - 0.01 and largest <= 1.6),
		"each emblem is %.2f-%.2f m across: never below %.2f m, never a centrepiece" % [smallest, largest, skin.emblem_min_size])


## The cult's feed (CultFeed, GDD §5 "Cyborg Viewing Devices") plays in the market alongside the
## ordinary ads: on billboards, casino signs and floating ads high up, and on TVs inside some shop
## windows, all with the one shared feed material, and nowhere else (never on the wall-run band's
## faces, never over the lanes below the ceilings). Checked over a whole level.
func _cult_feed(skin: MarketplaceSkin) -> void:
	check(skin.feed_material() == CultFeed.material(), "the market plays the shared feed")
	var geo := TrackGeometry.new(5, tuning)
	var wall: float = geo.wall_x()
	var boards: int = 0
	var tvs: int = 0
	for side: int in [-1, 1]:
		boards += skin.feed_boards(side, side * wall, 0.0, 3000.0).size()
		for w: Dictionary in skin.shop_windows(side, side * wall, 0.0, 3000.0):
			if w["screen"]:
				tvs += 1
	check(boards > 0 and tvs > 0, "over 3 km the feed plays on %d billboards and %d shop-window TVs" % [boards, tvs])
	var layout: LevelLayout = level(MARKET_LEVEL_PATH, 5, 0.6, 5)
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


## The stall layout the shader draws (PAT_STALLS) is the one the scripts compute: every slot belongs
## to exactly one stall of 1-3 slots, stalls tile each lane, and roofs keep to the skin's palette.
func _stall_layout(skin: MarketplaceSkin) -> void:
	var stalls: MarketStalls = skin.stalls()
	var ok: bool = true
	var kinds: Dictionary = {}
	for lane_x: float in [-4.8, -2.4, 0.0, 2.4, 4.8, 1.2]:
		var lane: int = MarketStalls.lane_key(lane_x)
		var d: float = -40.0
		var last := Vector2i(-1, -1)
		while d < 600.0:
			var span: Vector2i = stalls.stall_at(lane, d)
			var slot: int = floori(d / skin.stall_slot) + MarketStalls.KEY_OFFSET
			ok = ok and span.x <= slot and slot <= span.y and span.y - span.x <= 2
			ok = ok and MarketStalls.starts(lane, span.x) and MarketStalls.starts(lane, span.y + 1)
			ok = ok and (span == last or span.x == last.y + 1 or last.x < 0)
			for k: int in range(span.x + 1, span.y + 1):
				ok = ok and not MarketStalls.starts(lane, k)
			var roof: Array = stalls.roof_of(lane, span.x)
			kinds[roof[0]] = true
			last = span
			d += skin.stall_slot * 0.5
	check(ok, "stalls tile every lane in runs of 1-3 slots, as the shader lays them out")
	check(kinds.size() == 3, "stall rows mix canvas, blue awnings and tin (%d kinds)" % kinds.size())
	# The shader gets the same layout and palette.
	var solid: ShaderMaterial = skin.solid_material()
	check(is_equal_approx(float(solid.get_shader_parameter("stall_slot")), skin.stall_slot)
		and is_equal_approx(float(solid.get_shader_parameter("stall_awning_share")), skin.awning_share)
		and (solid.get_shader_parameter("stall_canvas") as PackedVector3Array).size() == 4,
		"the shader lays stalls out with the skin's slots, shares and palette")


func _has_seam(mesh: ArrayMesh, x: float, skin: MarketplaceSkin) -> bool:
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


## Relative luminance of an sRGB colour, in linear light.
static func _linear_luminance(c: Color) -> float:
	var l: Color = c.srgb_to_linear()
	return 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b


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

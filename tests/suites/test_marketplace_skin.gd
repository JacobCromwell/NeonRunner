extends SkinSuite
## The Marketplace skin (MarketplaceSkin, Zone 3). The shared skin checks (SkinSuite) over whole
## levels for 3, 5 and 6 lanes, then the Marketplace's own:
## - gaps keep the orange edge glow right on the collision edge;
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
## - the still floor carries drifting dust and speed streaks.

const MARKET_SKIN_PATH: String = "res://data/skins/marketplace_skin.tres"
const MARKET_ZONE_PATH: String = "res://data/zones/marketplace.tres"
## Lit (non-glowing) surfaces stay below this chroma (brightest minus darkest channel); the fence
## pink is about 0.8.
const MAX_SURFACE_CHROMA: float = 0.45
## A glowing colour this saturated (HSV) must keep to the decorative hues (blue to violet).
const GLOW_SATURATION_LIMIT: float = 0.35


func run() -> void:
	var skin := load(MARKET_SKIN_PATH) as MarketplaceSkin
	check(skin != null, "the marketplace skin loads")
	if skin == null:
		return
	# DESIGN-TBD placeholder (docs/questions/d2.md): Marketplace cyborgs dress as citizens.
	check(skin.enemy_variant == &"city" and MarketplaceSkin.new().enemy_variant == &"city",
		"marketplace enemies wear the city look (placeholder)")
	if ResourceLoader.exists(MARKET_ZONE_PATH):
		var zone := load(MARKET_ZONE_PATH) as ZoneDef
		check(zone != null and zone.skin is MarketplaceSkin, "the Marketplace zone uses the marketplace skin")
	start_error_count()
	var env: Environment = skin.make_environment()
	check(env != null and env.sky != null and env.glow_enabled and env.fog_enabled,
		"the marketplace environment has a sky, glow and fog")
	_palette(skin)
	for lanes: int in [3, 5, 6]:
		await whole_level(skin, "marketplace", LEVEL_PATH, lanes)
	await hazards_and_triggers(skin)
	await _surfaces(skin)
	await _clear_play_space(skin)
	await _shop_windows(skin)
	_ceilings(skin)
	await determinism(skin, LEVEL_PATH)
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


## Between the floor and the ceiling, over the lanes, the skin builds nothing solid but hazards and
## triggers: stall roofs are flat, gap faces hang below the roofs, ceilings keep above their
## undersides, and walls, signs and awnings stay outside the lanes or up high.
func _clear_play_space(skin: MarketplaceSkin) -> void:
	for lanes: int in [3, 6]:
		var layout: LevelLayout = level(LEVEL_PATH, lanes, 0.6, 5)
		var world := Node3D.new()
		tree.root.add_child(world)
		var track := TrackBuilder.new()
		world.add_child(track)
		track.set_layout(layout, tuning, skin)
		var half: float = TrackGeometry.new(lanes, tuning).half_width()
		var intruders: PackedStringArray = []
		var d: float = 0.0
		while d < 400.0:
			track.update(d, 0.0)
			d += TrackBuilder.CHUNK_LENGTH
		for node: Node in nodes_of(track, func(n: Node) -> bool: return n is MeshInstance3D):
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
					if absf(p.x) < half - 0.01 and p.y > 0.06 and p.y < tuning.ceiling_height - 0.1 and intruders.size() < 4:
						intruders.append(str(p))
		check(intruders.is_empty(), "nothing decorative stands in the play space (%d lanes): %s" % [lanes,
			", ".join(intruders)])
		world.queue_free()
		await tree.process_frame


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

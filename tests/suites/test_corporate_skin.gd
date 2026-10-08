extends SkinSuite
## The Corporate skin (CorporateSkin, Zone 4), which the Corporate zone uses, and its plaza variant. The
## shared skin checks (SkinSuite) over the whole of Corporate 2 for 3, 5 and 6 lanes (and the plaza's at
## 5), then the zone's own:
## - its cyborgs are the Wide-Aspect VR Runner (GDD §9.2);
## - the palette and the brand: one harsh brand colour, clear of every hazard hue and the UI's accents,
##   and the brand's mark shared with Gangland's hints of corporate funding;
## - gaps read as holes (CLAUDE.md readability rules): the orange edge glow right on the collision
##   edge, and below the running surface nothing but deep shade far darker than any floor material and
##   the orange strips, for the trains and the plaza alike;
## - the carriages keep to their grid: no gangway near a gap's edge or across a chunk cut, and the same
##   carriage on both sides of a cut;
## - the colour rule (GDD §5): nothing but hazards glows in a hazard hue, and lit surfaces stay well
##   below the hazards' saturation;
## - the play space stays clear, and the wall-run band stays calm: nothing sticks out of the walls or
##   glows there (so a pink wall fence never competes with a band of light), decorative screens and
##   signs sit above decor_min_height, and only hazard signs wear the striped frame;
## - every kind of ceiling builds from the lanes it covers, full width or narrow (task B3);
## - the cult: its emblem is the owner's choice, small and high, where cult_emblems() says; its feed
##   plays on the shared material where feed_boards() says, untinted, far above the wall-run band;
## - a boss arena can clear everything hung over the street;
## - the still floor carries drifting grit and speed streaks.

const CORP_SKIN_PATH: String = "res://data/skins/corporate_skin.tres"
const PLAZA_SKIN_PATH: String = "res://data/skins/corporate_plaza_skin.tres"
const CORP_ZONE_PATH: String = "res://data/zones/corporate.tres"
## The Corporate zone's campaign level with the most in it (Corporate 2 adds the Tithe Collector and a
## heavier military presence).
const CORP_LEVEL_PATH: String = "res://data/levels/corporate_2.tres"
## Lit (non-glowing) surfaces stay below this chroma (brightest minus darkest channel); the fence pink
## is about 0.8.
const MAX_SURFACE_CHROMA: float = 0.45
## A glowing colour this saturated (HSV) must keep to the decorative hues (blue to violet).
const GLOW_SATURATION_LIMIT: float = 0.35
## Gaps: the floor shading's lowest broad factor (a freight car's corrugation, sheet tone and
## shoulders; kit_corporate.gdshaderinc, corp_roof), PAT_CORP_UNDER's brightest factor (the top of a
## face), and how much darker than the darkest floor a gap's inside must stay (linear luminance).
const FLOOR_SHADE_MIN: float = 0.6
const UNDER_MAX_FACTOR: float = 1.0
## (Task H3, GDD §9.9: a gap shows the trench under the maglev line, or the plaza's lower level, dim but
## recognisable: the brightest colour below (the guideways' steel, PAT_CORP_UNDER's factors never pass 1) may
## reach this share of the darkest floor at its darkest shading, which is the military freight cars' olive in
## deep shade, where it used to be 0.35. What is drawn is dimmer still: the patterns darken the colours.)
const GAP_CONTRAST: float = 1.3
## The showcase track's gap (SkinSuite.showcase_track): lane 3 of 5, 50-57 m.
const GAP_LANE := Vector2(1.2, 3.6)
const GAP := Vector2(50.0, 57.0)


func run() -> void:
	var skin := load(CORP_SKIN_PATH) as CorporateSkin
	check(skin != null, "the corporate skin loads")
	if skin == null:
		return
	var zone := load(CORP_ZONE_PATH) as ZoneDef
	check(zone != null and zone.skin is CorporateSkin, "the Corporate zone uses the corporate skin")
	check(skin.enemy_variant == &"vr_runner" and CorporateSkin.new().enemy_variant == &"vr_runner"
		and CyborgSuit.look_for(skin.enemy_variant) == &"vr_runner", "corporate cyborgs are the Wide-Aspect VR Runner")
	check(skin.floor_style == CorporateSkin.FloorStyle.MAGLEV, "the zone runs on the maglev trains' roofs")
	start_error_count()
	var env: Environment = skin.make_environment()
	check(env != null and env.sky != null and env.glow_enabled and env.fog_enabled,
		"the corporate environment has a sky, glow and fog")
	_palette(skin)
	_brand(skin)
	_live_lane_width()
	for lanes: int in [3, 5, 6]:
		await whole_level(skin, "corporate", CORP_LEVEL_PATH, lanes)
	await hazards_and_triggers(skin)
	await _surfaces(skin)
	await _gaps(skin, "the trains")
	_carriages(skin)
	await _clear_play_space(skin)
	_ceilings(skin)
	await _cult_emblem(skin)
	await _cult_feed(skin)
	await _boss_arena(skin)
	await determinism(skin, CORP_LEVEL_PATH)
	doodads_ok(skin, "corporate")
	var plaza := load(PLAZA_SKIN_PATH) as CorporateSkin
	check(plaza != null and plaza.floor_style == CorporateSkin.FloorStyle.PLAZA and plaza.enemy_variant == &"vr_runner",
		"the plaza variant loads, with the zone's cyborgs")
	if plaza != null:
		await whole_level(plaza, "corporate plaza", CORP_LEVEL_PATH, 5)
		await hazards_and_triggers(plaza)
		await _gaps(plaza, "the plaza")
		await determinism(plaza, CORP_LEVEL_PATH)
	stop_error_count("building corporate levels")


## The palette keeps to the colour rule before anything is built: decorative light in cold white and
## the brand's blue, lit surfaces desaturated, the fence pink far more saturated than any of them.
func _palette(skin: CorporateSkin) -> void:
	var glowing: Array[Color] = [skin.brand_color, skin.flood_color, skin.window_color, skin.ceiling_lamp_color,
		skin.engine_color, skin.searchlight_color, skin.screen_text_color, skin.emblem_color()]
	var bad: PackedStringArray = []
	for c: Color in glowing:
		if _hazard_hue(c):
			bad.append(str(c))
	check(bad.is_empty(), "decorative light keeps to cold white and the brand's blue: %s" % ", ".join(bad))
	var lit: Array[Color] = [skin.olive_color, skin.gunmetal_color, skin.pilaster_color, skin.soffit_color,
		skin.concrete_color, skin.joint_color, skin.ledge_color, skin.livery_color, skin.brand_paint_color, skin.marking_color,
		skin.pylon_color, skin.metal_color, skin.gap_inside_color, skin.wall_mark_color]
	for list: PackedColorArray in [skin.roof_colors, skin.military_roof_colors, skin.podium_colors, skin.facade_colors,
			skin.blast_colors, skin.paving_colors]:
		lit.append_array(Array(list))
	var loud: PackedStringArray = []
	for c: Color in lit:
		if _chroma(c) > MAX_SURFACE_CHROMA:
			loud.append(str(c))
	check(loud.is_empty(), "lit surfaces stay well below the hazards' saturation: %s" % ", ".join(loud))
	check(_chroma(skin.fence_color) > MAX_SURFACE_CHROMA + 0.3, "the fence pink is far more saturated than any surface")
	# Steel and gunmetal, military olive (GDD §5): the steels are near-neutral greys, the olive a green-
	# tinged khaki, never a green that could pass for a ramp.
	var greys: PackedStringArray = []
	for c: Color in Array(skin.roof_colors) + Array(skin.podium_colors) + Array(skin.facade_colors) + [skin.gunmetal_color,
			skin.pilaster_color]:
		if _chroma(c) > 0.08:
			greys.append(str(c))
	check(greys.is_empty(), "the steels are greys: %s" % ", ".join(greys))
	check(skin.olive_color.g >= skin.olive_color.b and _chroma(skin.olive_color) < 0.15
		and _hue_distance(skin.olive_color, skin.ramp_color) > 0.08, "the olive is a dull khaki, far from the ramps' green")


## The brand (GDD §5: one harsh brand colour, chosen away from the hazard colours; the task plan: away
## from the UI's azure and violet): saturated, clear of the hazards' hues as the cult emblem's neon is
## (test_cult_emblem.gd), and its mark is the one kit_logo.gdshaderinc draws for Gangland's crates,
## containers and ads.
func _brand(skin: CorporateSkin) -> void:
	var brand: Color = skin.brand_color
	check(brand.s >= 0.8 and brand.v >= 0.9, "the brand's colour is harsh: fully saturated and bright (%s)" % brand)
	var grey := GreyboxSkin.new()
	var style: UiStyle = UiTheme.style()
	var reserved: Dictionary = {"fence pink": skin.fence_color, "gap orange": skin.gap_edge_color, "sign yellow":
		skin.sign_frame_color, "enemy red": Color(1.0, 0.1, 0.1)}
	var near: Dictionary = {"pad cyan": skin.pad_color, "ramp green": skin.ramp_color, "speed pad green": skin.speed_pad_color,
		"UI azure": style.accent, "UI violet": style.accent_2, "grey box stripe": grey.wall_stripe_color}
	for what: String in reserved:
		check(_hue_distance(brand, reserved[what]) >= 0.08, "the brand's blue stays clear of the %s (%.3f)" % [what,
			_hue_distance(brand, reserved[what])])
	for what: String in near:
		check(_hue_distance(brand, near[what]) >= 0.05, "the brand's blue is distinct from the %s (%.3f)" % [what,
			_hue_distance(brand, near[what])])
	check(_hue_distance(skin.livery_color, brand) < 0.03 and _hue_distance(skin.brand_paint_color, brand) < 0.03,
		"its paint and livery are the same blue, lit")
	var shader: Shader = skin.solid_material().shader
	check(shader.code.contains("kit_corporate.gdshaderinc") and FileAccess.get_file_as_string(
		"res://scripts/world/meshes/shaders/kit_corporate.gdshaderinc").contains("corp_logo("),
		"the Corporate patterns draw the brand's mark with corp_logo()")
	var gang := load("res://data/skins/gangland_skin.tres") as GanglandSkin
	check(gang != null and gang.solid_material().shader == shader and FileAccess.get_file_as_string(
		"res://scripts/world/meshes/shaders/kit_logo.gdshaderinc").contains("float corp_logo("),
		"Gangland's crates, containers and ads carry the same mark (kit_logo.gdshaderinc)")
	var m: ShaderMaterial = skin.solid_material()
	check(m.get_shader_parameter("corp_brand_glow") == brand and m.get_shader_parameter("corp_brand") == skin.livery_color,
		"the kit material carries the brand's colours")


## The roofs' livery is laid out in metres across the roof (kit_corporate.gdshaderinc, corp_roof), so
## the material follows the lane width, which F6 tunes live. A fresh skin: the loaded one is shared.
func _live_lane_width() -> void:
	var fresh := CorporateSkin.new()
	var parent := Node3D.new()
	for width: float in [3.0, 2.4]:
		fresh.floor_segment(parent, Vector3(0.0, -0.25, -10.0), Vector3(width, 0.5, 20.0), 0.0, false, false)
		var half: float = fresh.solid_material().get_shader_parameter(&"corp_roof_half_width")
		check(is_equal_approx(half, fresh.trains().roof_half_width(width)),
			"the roofs' livery follows a %.1f m lane (half width %.2f)" % [width, half])
	parent.free()


## Over the showcase track (every kind of piece): the gap in lane 3 (50-57 m) has the orange edge glow
## on both edges; glowing surfaces keep off the hazard hues; lit ones stay desaturated; nothing is
## vent-like; glowing signs and screens on the walls stay above decor_min_height; only hazards wear
## stripes; the drifting particles are there; the facade shader's lights keep off the hazard hues.
func _surfaces(skin: CorporateSkin) -> void:
	var track: TrackBuilder = showcase_track(skin)
	var geo := TrackGeometry.new(5, tuning)
	var edges: Dictionary = {}
	var grilles: int = 0
	var stripes: int = 0
	var low_signs: PackedStringArray = []
	var hazard_hues: PackedStringArray = []
	var loud: PackedStringArray = []
	var drift_vertices: int = 0
	var solid: Material = skin.solid_material()
	var glow: Material = skin.glow_material()
	var signs := [MeshKit.PAT_CORP_AD, MeshKit.PAT_CORP_LOGO, MeshKit.PAT_GLYPHS, MeshKit.PAT_CULT_MARK]
	for node: Node in nodes_of(track, func(n: Node) -> bool: return n is MeshInstance3D):
		var m := node as MeshInstance3D
		if m.mesh == null or m.is_in_group(&"debug_hitbox"):
			continue
		var in_hazard: bool = under_hazard(m)
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
					var on_wall: bool = absf(p.x) > geo.half_width() - 0.01
					if signs.has(pattern) and c.a > 0.0 and on_wall and not in_hazard and p.y < skin.decor_min_height - 0.01 \
							and low_signs.size() < 4:
						low_signs.append("%d at %s" % [pattern, p])
					if c.a == 0.0 and _chroma(c) > MAX_SURFACE_CHROMA and loud.size() < 4:
						loud.append("%s at %s" % [c, p])
					if c.a > 0.2 and _same_rgb(c, skin.gap_edge_color) and absf(p.y) < 0.01 and p.x > GAP_LANE.x - 0.01 \
							and p.x < GAP_LANE.y + 0.01:
						for edge: float in [GAP.x, GAP.y]:
							if absf(-p.z - edge) < 0.25:
								edges[edge] = true
				var glowing: bool = material == glow or c.a > 0.0
				if glowing and not in_hazard and not in_trigger and _hazard_hue(c) and not _same_rgb(c, skin.gap_edge_color) \
						and hazard_hues.size() < 4:
					hazard_hues.append("%s at %s" % [c, p])
	check(edges.has(GAP.x) and edges.has(GAP.y), "a gap keeps the orange edge glow on both of its edges (%s)" % [edges.keys()])
	check(grilles == 0, "nothing vent-like: no surface uses the grille pattern (%d vertices)" % grilles)
	check(stripes == 0, "only hazard signs wear the striped frame (%d striped vertices elsewhere)" % stripes)
	check(low_signs.is_empty(), "glowing signs and screens on the walls stay above %.1f m: %s" % [skin.decor_min_height,
		", ".join(low_signs)])
	check(hazard_hues.is_empty(), "nothing but hazards (and the orange edges) glows in a hazard hue: %s" % ", ".join(hazard_hues))
	check(loud.is_empty(), "lit surfaces stay desaturated: %s" % ", ".join(loud))
	check(drift_vertices > 0, "the still floor carries drifting grit and speed streaks (%d vertices)" % drift_vertices)
	var facade: ShaderMaterial = skin.facade_material()
	var lights: PackedStringArray = []
	for u: String in ["window_cold", "flood_color", "blast_a", "blast_b", "blast_c", "stencil_color", "pilaster_color"]:
		var c: Color = facade.get_shader_parameter(u)
		if _hazard_hue(c):
			lights.append("%s %s" % [u, c])
	check(lights.is_empty(), "the facades' lights and paints keep off the hazard hues: %s" % ", ".join(lights))
	await free_track(track)


## Gaps read as holes at a glance (CLAUDE.md readability rules): whatever a gap shows is in deep shade,
## far darker than any floor material, and nothing in it glows but the orange strip along the edge; no
## floor material is drawn in the edge's colour; the showcase gap's far edge carries the full orange
## edge, the lip on the roof right at the collision edge and the strip below it. Then a whole level,
## chunk by chunk: below the running surface there is nothing but the shade and the strips.
func _gaps(skin: CorporateSkin, what: String) -> void:
	var floors: Array[Color] = [skin.ledge_color, skin.joint_color, skin.livery_color]
	var list: PackedColorArray = skin.paving_colors if skin.floor_style == CorporateSkin.FloorStyle.PLAZA else \
		skin.roof_colors + skin.military_roof_colors
	floors.append_array(Array(list))
	var darkest: float = INF
	var like_edge: PackedStringArray = []
	for c: Color in floors:
		darkest = minf(darkest, _linear_luminance(c * Color(FLOOR_SHADE_MIN, FLOOR_SHADE_MIN, FLOOR_SHADE_MIN)))
		if _near_colour(c, skin.gap_edge_color):
			like_edge.append(str(c))
	var inside: float = 0.0
	for c: Color in [skin.gap_inside_color, skin.guideway_color, skin.trench_color]:
		inside = maxf(inside, _linear_luminance(c * Color(UNDER_MAX_FACTOR, UNDER_MAX_FACTOR, UNDER_MAX_FACTOR)))
	check(inside < darkest * GAP_CONTRAST, "%s: a gap's inside stays far darker than the darkest floor: %.4f vs %.4f" % [
		what, inside, darkest])
	check(like_edge.is_empty(), "%s: no floor is drawn in the gap edge's colour: %s" % [what, ", ".join(like_edge)])
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
				if not _same_rgb(colors[i], skin.gap_edge_color) or p.x < GAP_LANE.x or p.x > GAP_LANE.y or absf(-p.z - GAP.y) > 0.3:
					continue
				if p.y < -0.001 and colors[i].a >= CorporateTrains.STRIP_GLOW - 0.001:
					strip = Vector2(minf(strip.x, p.y), maxf(strip.y, p.y))
				elif absf(p.y) < 0.001 and colors[i].a >= CorporateTrains.LIP_GLOW - 0.001:
					lip = Vector2(minf(lip.x, -p.z), maxf(lip.y, -p.z))
	check(strip.y - strip.x >= CorporateTrains.STRIP_HEIGHT - 0.001 and strip.y > -0.05,
		"%s: the far edge's orange strip runs along the top of its face: %s" % [what, strip])
	check(lip.x > GAP.y - 0.01 and lip.y - lip.x >= CorporateTrains.EDGE_LIP - 0.001,
		"%s: the far edge's orange lip lies on the floor right at the collision edge: %s" % [what, lip])
	await free_track(track)
	var layout: LevelLayout = level(CORP_LEVEL_PATH, 5, 0.6, 9)
	var bad: PackedStringArray = []
	var count: Array[int] = [0]
	var shade: float = maxf(_linear_luminance(skin.gap_inside_color), maxf(_linear_luminance(skin.guideway_color),
		_linear_luminance(skin.trench_color))) + 0.0001
	var geo := TrackGeometry.new(5, tuning)
	await visit_level(layout, skin, func(m: MeshInstance3D, arrays: Array, material: Material) -> void:
		if under_hazard(m) or _under(m, func(n: Node) -> bool: return n is Area3D) or material == skin.drift_material():
			return
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2] if arrays[Mesh.ARRAY_TEX_UV2] != null else PackedVector2Array()
		for i: int in verts.size():
			var p: Vector3 = m.global_transform * verts[i]
			# Below the roofs' shoulders (0.08 m) and the gangways, within the walls; the finish gantry's
			# posts stand on the walkways, where no gap ever is.
			if p.y >= -0.1 or absf(p.x) > geo.wall_x() + 0.01 or absf(-p.z - layout.length) < 1.0:
				continue
			count[0] += 1
			var fault: String = ""
			if material == skin.solid_material():
				var c: Color = colors[i]
				var edge: bool = _same_rgb(c, skin.gap_edge_color) and c.a >= CorporateTrains.STRIP_GLOW - 0.001
				var dark: bool = roundi(uv2[i].x) == MeshKit.PAT_CORP_UNDER and c.a == 0.0 and _linear_luminance(c) <= shade
				if not edge and not dark:
					fault = "%s pattern %d" % [c, roundi(uv2[i].x)]
			else:
				fault = "material %s" % (material.resource_path.get_file() if material != null else "none")
			if fault != "" and bad.size() < 4:
				bad.append("%s at %s" % [fault, p]))
	check(bad.is_empty() and count[0] > 0, "%s: below the running surface there is only deep shade and the orange strips (%d vertices): %s" % [
		what, count[0], ", ".join(bad)])


## The carriages keep to their lane's grid (CorporateTrains.carriage_plan()), on stretches of track
## cut by gaps and 40 m chunks the way TrackBuilder cuts them: roofs and gangways tile each piece; no
## joint lies within GAP_MARGIN of a gap's edge, so no carriage at a gap is shorter (unless its piece
## is); no gangway crosses a chunk cut (a thin seam stands in); the same carriage continues across every
## cut; every other grid line has its gangway; runs of carriages share a kind.
func _carriages(skin: CorporateSkin) -> void:
	var trains: CorporateTrains = skin.trains()
	var problems: PackedStringArray = []
	var freight: int = 0
	var cells: int = 0
	var gangways: int = 0
	for lane_x: float in [-4.8, -2.4, 0.0, 2.4, 4.8, 1.2, -3.6]:
		var key: int = MeshKit.key(lane_x)
		var unit: float = trains.carriage_unit(key)
		var offset: float = trains.carriage_offset(key)
		# Gaps 4-10 m long, 12-70 m apart, from a hash of the lane.
		var gaps: Array[Vector2] = []
		var d: float = 20.0 + 30.0 * MeshKit.hash01(key, 1)
		var n: int = 0
		while d < 900.0:
			var len: float = 4.0 + 6.0 * MeshKit.hash01(key, n, 2)
			gaps.append(Vector2(d, d + len))
			d += len + 12.0 + 58.0 * MeshKit.hash01(key, n, 3)
			n += 1
		var last_cell: int = 0
		var last_end: float = -1.0
		for c: int in 24:
			var c0: float = c * TrackBuilder.CHUNK_LENGTH
			var c1: float = c0 + TrackBuilder.CHUNK_LENGTH
			for piece: Vector2 in _pieces(gaps, c0, c1):
				var edge_start: bool = piece.x > c0
				var edge_end: bool = piece.y < c1
				var lip_n: float = minf(CorporateTrains.EDGE_LIP, (piece.y - piece.x) * 0.4) if edge_start else 0.0
				var lip_f: float = minf(CorporateTrains.EDGE_LIP, (piece.y - piece.x) * 0.4) if edge_end else 0.0
				var a: float = piece.x + lip_n
				var b: float = piece.y - lip_f
				var plan: Dictionary = trains.carriage_plan(lane_x, a, b, edge_start, edge_end)
				var covered: float = 0.0
				for r: Dictionary in plan["roofs"]:
					covered += float(r["to"]) - float(r["from"])
				for j: Dictionary in plan["joints"]:
					var g: float = j["at"]
					if j["kind"] == CorporateTrains.GANGWAY:
						covered += CorporateTrains.JOINT_HALF * 2.0
						gangways += 1
						if g - CorporateTrains.JOINT_HALF < a - 0.001 or g + CorporateTrains.JOINT_HALF > b + 0.001:
							problems.append("lane %.1f: a gangway at %.2f crosses its piece's end (%.2f-%.2f)" % [lane_x, g, a, b])
					if (edge_start and g - a < CorporateTrains.GAP_MARGIN - 0.001) or (edge_end and b - g < CorporateTrains.GAP_MARGIN - 0.001):
						problems.append("lane %.1f: a joint at %.2f is within %.1f m of a gap's edge (%.2f-%.2f)" % [lane_x, g,
							CorporateTrains.GAP_MARGIN, a, b])
				if absf(covered - (b - a)) > 0.01 and b > a:
					problems.append("lane %.1f: the roofs and gangways cover %.2f of %.2f m (%.2f-%.2f)" % [lane_x, covered, b - a, a, b])
				# Every grid line well inside the piece has its joint.
				var k: int = ceili((a - offset) / unit)
				while offset + k * unit < b:
					var g: float = offset + k * unit
					k += 1
					var far_from_gaps: bool = (not edge_start or g - a >= CorporateTrains.GAP_MARGIN) and (not edge_end
						or b - g >= CorporateTrains.GAP_MARGIN)
					if not far_from_gaps or g <= a + 0.001:
						continue
					var found: bool = false
					for j: Dictionary in plan["joints"]:
						found = found or absf(float(j["at"]) - g) < 0.001
					if not found:
						problems.append("lane %.1f: no joint on the grid line at %.2f (%.2f-%.2f)" % [lane_x, g, a, b])
				var roofs: Array = plan["roofs"]
				if not roofs.is_empty():
					if not edge_start and absf(last_end - a) < 0.001 and int(roofs[0]["cell"]) != last_cell:
						problems.append("lane %.1f: carriage %d meets carriage %d at the chunk cut at %.1f" % [lane_x, last_cell,
							roofs[0]["cell"], a])
					last_cell = roofs[roofs.size() - 1]["cell"]
					last_end = b if not edge_end else -1.0
				if problems.size() > 6:
					break
		for cell: int in 400:
			cells += 1
			if trains.carriage(key, cell)[0] == CorporateTrains.FREIGHT:
				freight += 1
			if trains.carriage(key, cell)[0] != trains.carriage(key, cell - posmod(cell, CorporateTrains.RUN))[0]:
				problems.append("lane %.1f: carriage %d isn't the kind of its run" % [lane_x, cell])
				break
	check(problems.is_empty() and gangways > 50, "the carriages keep to their grid (%d gangways):\n  %s" % [gangways,
		"\n  ".join(problems.slice(0, 6))])
	var share: float = float(freight) / cells
	check(absf(share - skin.military_car_share) < 0.12, "military freight cars make up about %.2f of the trains (%.2f)" % [
		skin.military_car_share, share])


## The solid floor pieces of one lane within a chunk [c0, c1), as TrackBuilder._floor_pieces() cuts them.
static func _pieces(gaps: Array[Vector2], c0: float, c1: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var cursor: float = c0
	for g: Vector2 in gaps:
		if g.y <= cursor:
			continue
		if g.x >= c1:
			break
		if g.x > cursor:
			out.append(Vector2(cursor, g.x))
		cursor = maxf(cursor, g.y)
	if cursor < c1:
		out.append(Vector2(cursor, c1))
	return out


## Between the floor and the ceiling, over the lanes, the skin builds nothing solid but hazards and
## triggers, anywhere in a whole level (the stretch behind the start too); nothing sticks out of the
## walls through the wall-run band, and nothing on the walls glows or lights up below band_top (a pink
## wall fence, task B5, never competes with a band of light). Ceilings are placed instances, checked in
## _ceilings().
func _clear_play_space(skin: CorporateSkin) -> void:
	for lanes: int in [3, 6]:
		var layout: LevelLayout = level(CORP_LEVEL_PATH, lanes, 0.6, 5)
		var geo := TrackGeometry.new(lanes, tuning)
		var half: float = geo.half_width()
		var wall: float = geo.wall_x()
		var band: float = minf(skin.band_top, tuning.ceiling_height - 0.1)
		var intruders: PackedStringArray = []
		var sticking: PackedStringArray = []
		var lit: PackedStringArray = []
		await visit_level(layout, skin, func(m: MeshInstance3D, arrays: Array, material: Material) -> void:
			if _under(m, func(n: Node) -> bool: return n is Area3D) or material == skin.drift_material():
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


## Every kind of ceiling, over every number of lanes from one to six, full width or narrow and off
## centre (task B3): a flat underside covering exactly its lanes (a gate: from wall to wall), nothing
## hanging below it but flush lamps and seams, the orange band at its far end and nothing else past
## it (a runner dropping off the end passes whatever hangs there, glowing or not, right in front of the
## camera), a seam under each lane boundary, and nothing rising past TOP_LIMIT; only a ceiling across
## every lane becomes a gate.
func _ceilings(skin: CorporateSkin) -> void:
	var lane_w: float = tuning.lane_width
	var wall_x: float = 3.0 * lane_w + tuning.wall_margin
	var problems: PackedStringArray = []
	for kind: int in [CorporateCeilings.Kind.SKYWAY, CorporateCeilings.Kind.GATE, CorporateCeilings.Kind.VIADUCT,
			CorporateCeilings.Kind.SHIP]:
		for lanes: int in range(1, 7):
			if kind == CorporateCeilings.Kind.GATE and lanes != 6:
				continue
			var offset: float = 0.0 if lanes == 6 else (6 - lanes) * lane_w * 0.5 * (1.0 if lanes % 2 == 0 else -1.0)
			var size := Vector3(lanes * lane_w, TrackBuilder.HULL_THICKNESS, 30.0)
			var edges: Array[float] = []
			for k: int in range(1, lanes):
				edges.append(offset - size.x * 0.5 + k * lane_w)
			var mesh: ArrayMesh = skin.ceilings().mesh_for(kind, 1, size, edges, offset, wall_x, tuning.ceiling_height)
			var tag: String = "kind %d, %d lanes" % [kind, lanes]
			var under := {"min_x": INF, "max_x": -INF, "lowest": 0.0, "glow_lowest": 0.0, "highest": 0.0, "band": false,
				"past_glow": 0.0, "past_any": 0.0}
			for s: int in mesh.get_surface_count():
				var arrays: Array = mesh.surface_get_arrays(s)
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
				var glow_surface: bool = mesh.surface_get_material(s) == skin.glow_material()
				for i: int in verts.size():
					var v: Vector3 = verts[i]
					under["highest"] = maxf(under["highest"], v.y)
					var past: float = -size.z * 0.5 - v.z
					if _same_rgb(colors[i], skin.gap_edge_color):
						past = 0.0
					if glow_surface or colors[i].a > 0.0:
						under["past_glow"] = maxf(under["past_glow"], past)
					under["past_any"] = maxf(under["past_any"], past)
					if glow_surface:
						under["glow_lowest"] = minf(under["glow_lowest"], v.y)
						continue
					under["lowest"] = minf(under["lowest"], v.y)
					if absf(v.y) < 0.001:
						under["min_x"] = minf(under["min_x"], v.x)
						under["max_x"] = maxf(under["max_x"], v.x)
						if _same_rgb(colors[i], skin.gap_edge_color) and v.z < -size.z * 0.5 + CorporateCeilings.END_BAND + 0.01:
							under["band"] = true
			var want: float = wall_x if kind == CorporateCeilings.Kind.GATE else size.x * 0.5 + 0.15
			if absf(under["min_x"] + want) > 0.02 or absf(under["max_x"] - want) > 0.02:
				problems.append("%s: underside spans %.2f..%.2f, not ±%.2f" % [tag, under["min_x"], under["max_x"], want])
			if under["lowest"] < -0.06:
				problems.append("%s: something hangs %.2f m below the surface" % [tag, under["lowest"]])
			# A runner dropping off the end passes through anything glowing below it (a flash).
			if under["glow_lowest"] < -0.1:
				problems.append("%s: a glow hangs %.2f m below the surface" % [tag, under["glow_lowest"]])
			if under["highest"] > CorporateCeilings.TOP_LIMIT + 0.01:
				problems.append("%s: something rises %.2f m above the surface (limit %.1f)" % [tag, under["highest"],
					CorporateCeilings.TOP_LIMIT])
			if not under["band"]:
				problems.append("%s: no orange band at the far end" % tag)
			# The camera passes the far end as the runner drops off: whatever sticks out past it would be right
			# in front of it (the shared orange band's glow aside).
			if under["past_any"] > CorporateCeilings.NOZZLE_RIM + 0.01 or under["past_glow"] > 0.05:
				problems.append("%s: something reaches %.2f m past the far end (glowing: %.2f m)" % [tag, under["past_any"],
					under["past_glow"]])
			for x: float in edges:
				if not _has_seam(mesh, x - offset, skin):
					problems.append("%s: no seam at x %.2f" % [tag, x - offset])
			if problems.size() > 6:
				break
	check(problems.is_empty(), "every kind of ceiling builds from its lanes, full width or narrow:\n  %s" % "\n  ".join(problems))
	check(CorporateCeilings.TOP_LIMIT + tuning.ceiling_height < CorporateTowers.OVER_STREET_MIN,
		"what hangs over the street from the walls clears every ceiling")
	var gates: int = 0
	var narrow_gates: int = 0
	var kinds: Dictionary = {}
	for i: int in 200:
		var z: float = -(100.0 + i * 7.3)
		var full := Vector3(6.0 * lane_w, TrackBuilder.HULL_THICKNESS, 40.0 + float(i % 5) * 4.0)
		var k: int = skin.ceilings().kind_of(Vector3(0, 6.4, z), full, wall_x)
		kinds[k] = true
		gates += int(k == CorporateCeilings.Kind.GATE)
		var narrow := Vector3(2.0 * lane_w, TrackBuilder.HULL_THICKNESS, full.z)
		narrow_gates += int(skin.ceilings().kind_of(Vector3(lane_w, 6.4, z), narrow, wall_x) == CorporateCeilings.Kind.GATE)
	check(gates > 20 and narrow_gates == 0, "only full-width ceilings become towers bridging the street (%d of 200 full, %d narrow)" % [
		gates, narrow_gates])
	check(kinds.size() == 4, "every kind of ceiling turns up, the gunship among them (%d kinds)" % kinds.size())


## The cult's emblem (GDD §5, hidden in plain sight): the owner's choice (the choice file, never a
## hardcoded option), in its own warm-white neon on screens and unlit metal on banners; over 3 km of
## walls it turns up on screens, roof boards and banners, each at least emblem_min_size across (smaller,
## it could read like the radiation trefoil), small beside its ad, high on the walls; over a whole level
## every one built is one cult_emblems() lists, never on a hazard.
func _cult_emblem(skin: CorporateSkin) -> void:
	var choice := load(CultFeed.CHOICE_PATH) as CultEmblemChoice
	check(choice != null and CultFeed.emblem_option() == choice.option,
		"the skin draws the cult emblem the owner picked (option %s)" % (CultEmblem.option_letter(choice.option)
			if choice != null else "?"))
	if choice == null:
		return
	var scheme: Dictionary = CultEmblem.default_scheme(choice.option)
	check(skin.emblem_color() == scheme["neon"] and skin.emblem_metal_color() == scheme["metal"] and skin.emblem_glow > 0.0,
		"it glows in the chosen emblem's warm-white neon, or is its unlit metal")
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
	print("  corporate emblem (5 lanes): %s over 3 km of walls" % kinds)
	check(kinds.size() == 3, "over 3 km the emblem hides on screens, roof boards and banners: %s" % kinds)
	check(sizes.x >= skin.emblem_min_size - 0.01 and sizes.y <= 1.6 and low == 0,
		"each is %.2f-%.2f m across (never below %.2f m, never a centrepiece), high on the walls (%d low)" % [sizes.x,
			sizes.y, skin.emblem_min_size, low])
	var built: Array[Dictionary] = []
	var bad: PackedStringArray = []
	await visit_level(level(CORP_LEVEL_PATH, 5, 0.6), skin, func(m: MeshInstance3D, arrays: Array, material: Material) -> void:
		if material != skin.solid_material():
			return
		for r: Dictionary in rects_of(m, arrays):
			if r["pattern"] != MeshKit.PAT_CULT_MARK:
				continue
			built.append(r)
			var c: Color = r["color"]
			var neon: bool = _same_rgb(c, scheme["neon"]) and is_equal_approx(c.a, skin.emblem_glow)
			var metal: bool = _same_rgb(c, scheme["metal"]) and c.a == 0.0
			var extent: float = maxf((r["ou"] as Vector3).distance_to(r["o"]), (r["ov"] as Vector3).distance_to(r["o"]))
			if (not (neon or metal) or under_hazard(m) or extent / CorporateTowers.EMBLEM_MARGIN < skin.emblem_min_size - 0.01) \
					and bad.size() < 4:
				bad.append("%s (colour %s, %.2f m)" % [r["center"], c, extent]))
	var unlisted: int = 0
	for r: Dictionary in built:
		var found: bool = false
		for e: Dictionary in listed:
			found = found or (e["center"] as Vector3).distance_to(r["center"]) < 0.1
		unlisted += int(not found)
	check(not built.is_empty() and bad.is_empty(), "over a whole level the %d emblems are the chosen one, in its colours, big enough, off hazards: %s" % [
		built.size(), ", ".join(bad)])
	check(unlisted == 0, "every emblem built is one cult_emblems() lists (%d unlisted)" % unlisted)


## The cult's feed (CultFeed, GDD §5 "Cyborg Viewing Devices") plays alongside the corporate ads on the
## shared material, on the screens hung over the street and on low buildings' roof boards; over a whole
## level every screen it builds is one feed_boards() lists, plays the untinted picture, faces the runner
## or the street, and sits far above the wall-run band.
func _cult_feed(skin: CorporateSkin) -> void:
	check(skin.feed_material() == CultFeed.material(), "the Corporate zone plays the shared feed")
	var geo := TrackGeometry.new(5, tuning)
	var wall: float = geo.wall_x()
	var kinds: Dictionary = {}
	var listed: Array[Dictionary] = []
	for side: int in [-1, 1]:
		for board: Dictionary in skin.feed_boards(side, side * wall, -100.0, 3000.0):
			kinds[board["kind"]] = int(kinds.get(board["kind"], 0)) + 1
			listed.append(board)
	print("  corporate feed (5 lanes): %s over 3 km of walls" % kinds)
	check(int(kinds.get(&"street_screen", 0)) > 0 and int(kinds.get(&"roof_board", 0)) > 0,
		"over 3 km the feed plays on screens over the street and on roof boards: %s" % kinds)
	var screens: Array[Dictionary] = []
	var bad: PackedStringArray = []
	await visit_level(level(CORP_LEVEL_PATH, 5, 0.6), skin, func(m: MeshInstance3D, arrays: Array, material: Material) -> void:
		if material != skin.feed_material():
			return
		for r: Dictionary in rects_of(m, arrays):
			screens.append(r)
			var lowest: float = minf(r["o"].y, minf(r["ov"].y, r["ou"].y))
			var n: Vector3 = r["normal"]
			var facing: bool = n.is_equal_approx(Vector3.BACK) or n.is_equal_approx(Vector3(-signf(r["center"].x), 0, 0))
			if (lowest < skin.decor_min_height or not _same_rgb(r["color"], Color.WHITE) or not facing or under_hazard(m)) \
					and bad.size() < 4:
				bad.append("%s (normal %s, colour %s)" % [r["center"], n, r["color"]]))
	var unlisted: int = 0
	for r: Dictionary in screens:
		var found: bool = false
		for board: Dictionary in listed:
			found = found or (board["center"] as Vector3).distance_to(r["center"]) < 0.05
		unlisted += int(not found)
	check(not screens.is_empty() and bad.is_empty(),
		"over a whole level the feed's %d screens face the runner or the street, untinted, far above the band: %s" % [
			screens.size(), ", ".join(bad)])
	check(unlisted == 0, "every feed screen built is one feed_boards() lists (%d unlisted)" % unlisted)


## A boss whose ship flies over the street (Hostile Takeover's gunship, GDD §10) needs the air over the
## street clear: with street_screen_share, banner_share, skybridge_share and hover_ship_share at 0,
## nothing the walls build reaches out over the lanes (above the ceilings, more than a floodlight's
## halo from the walls; the watchtowers' searchlights lean away from the street).
func _boss_arena(skin: CorporateSkin) -> void:
	var arena := skin.duplicate() as CorporateSkin
	arena.street_screen_share = 0.0
	arena.banner_share = 0.0
	arena.skybridge_share = 0.0
	arena.hover_ship_share = 0.0
	var geo := TrackGeometry.new(5, tuning)
	var counts: Array[int] = [0, 0]
	for which: int in 2:
		var s: CorporateSkin = skin if which == 0 else arena
		await visit_level(level(CORP_LEVEL_PATH, 5, 0.6, 4), s, func(m: MeshInstance3D, arrays: Array, material: Material) -> void:
			# The walls' meshes sit at the chunk's origin (ceilings, hazards and triggers are placed nodes).
			if m.position != Vector3.ZERO or material == s.drift_material():
				return
			for v: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				if absf(v.x) < geo.half_width() - 1.0 and v.y > tuning.ceiling_height + 2.0:
					counts[which] += 1)
	check(counts[0] > 0 and counts[1] == 0, "a boss arena can clear the air over the street (%d vertices over it, %d cleared)" % [
		counts[0], counts[1]])


func _has_seam(mesh: ArrayMesh, x: float, skin: CorporateSkin) -> bool:
	for s: int in mesh.get_surface_count():
		if mesh.surface_get_material(s) != skin.solid_material():
			continue
		for v: Vector3 in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			if absf(v.x - (x - 0.035)) < 0.002 and v.y < 0.0 and v.y > -0.02:
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


## A saturated colour outside the decorative blue-to-violet band: pink, red, orange, yellow, green or
## cyan (GDD §5: those glow only on hazards).
static func _hazard_hue(c: Color) -> bool:
	if c.s < GLOW_SATURATION_LIMIT:
		return false
	return c.h < 0.58 or c.h > 0.8


static func _hue_distance(a: Color, b: Color) -> float:
	var d: float = absf(a.h - b.h)
	return minf(d, 1.0 - d)


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

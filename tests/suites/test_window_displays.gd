extends SkinSuite
## The shop windows' displays of the Marketplace and the Casino (task L10; GDD §5 "Cyborg Viewing Devices", the owner's
## October 17, 2026 decision): no feed TVs in the shop windows, but ad screens playing a few cycling procedurally drawn
## ads, with the cult's emblem flashing onto them every once in a while, and lit posters that fit the world.
## - which windows hold one is seeded from the window's own position, in data (window_display_share, window_screen_share),
##   keeps the old TVs' share, and shop_windows() says so (`screen`, which keeps the citizens out, and `display`);
## - every display is built where it says, inside the window's display (never sticking out of the wall, nothing hung from
##   the band's face), in the solid material (no mesh surface of its own, no feed material), no costlier than a TV was, and
##   not in a window a window cyborg stands in;
## - the colour rule: the ads' palette keeps to the decorative hues (blue to violet, warm white), and the posters' paint is
##   off every hazard hue as well (no red, orange, yellow, green, cyan or pink), none near a hazard's colour;
## - the emblem's flash is a single slow event: never faster than a third of a second to come in, seconds apart, each
##   screen at its own moment, and Reduced flashing gives a slower, steadier one, read by the shader from the global
##   uniform (nothing strobes);
## - the shader's pieces are in place (kit_solid dispatches ids 100-109, the emblem texture is on the solid material).

const SKIN_PATHS: Dictionary = {
	"marketplace": "res://data/skins/marketplace_skin.tres", "casino": "res://data/skins/casino_skin.tres"}
## The old feed TV added this many vertices to a chunk: two boxes of five faces (60) and the screen's two triangles (6).
const TV_VERTICES: int = 66
## No more than this share of a stretch's screens may be flashing the emblem at once (over 100 s at a quarter-second).
const MAX_FLASHING_SHARE: float = 0.5
## A flash never comes in faster than this (seconds): about three flashes a second is the most the guidelines allow, and a
## flash here is one event, seconds apart.
const MIN_FADE_IN: float = 0.15
const MIN_PERIOD: float = 10.0
## The hazards' colours a display must stay clear of (the fence's pink, the sign frame's yellow, the ramps' green, the
## pads' cyan, the gap edge's orange).
const HAZARD_COLOURS: Array[Color] = [Color(1.0, 0.18, 0.62), Color(1.0, 0.8, 0.15), Color(0.3, 1.0, 0.35),
	Color(0.1, 1.0, 0.95), Color(1.0, 0.55, 0.1), Color(1.0, 0.15, 0.1)]


func run() -> void:
	for skin_name: String in SKIN_PATHS:
		var skin := load(String(SKIN_PATHS[skin_name])) as MarketplaceSkin
		check(skin != null, "the %s skin loads" % skin_name)
		if skin == null:
			continue
		_palettes(skin, skin_name)
		_shares_and_determinism(skin, skin_name)
		await _built_panels(skin, skin_name)
		await _cyborg_windows(skin, skin_name)
		await _cost(skin, skin_name)
		_flash_timing(skin, skin_name)
		_material(skin, skin_name)
	_shader_source()


# --- Colours ----------------------------------------------------------------------------------

## The ads glow, so keep to the decorative hues (blue to violet, warm white); the posters are lit paint but keep off every
## hazard hue too (the owner: no hazard colours on these), and nothing is near a hazard's own colour.
func _palettes(skin: MarketplaceSkin, tag: String) -> void:
	check(skin.window_ad_colors.size() >= 6, "%s: the ads' palette has the six colours the shader reads" % tag)
	var bad: PackedStringArray = []
	for c: Color in skin.window_ad_colors:
		if _hazard_hue(c):
			bad.append("ad %s" % str(c))
	for c: Color in skin.window_poster_colors:
		if _hazard_hue(c) or _chroma(c) > 0.45:
			bad.append("poster %s" % str(c))
	for c: Color in Array(skin.window_ad_colors) + Array(skin.window_poster_colors) + [skin.window_frame_color]:
		for hazard: Color in HAZARD_COLOURS:
			if _near_colour(c, hazard):
				bad.append("%s near the hazard %s" % [str(c), str(hazard)])
	check(bad.is_empty(), "%s: the ads and posters keep off every hazard colour: %s" % [tag, ", ".join(bad)])
	check(skin.window_poster_colors.size() >= 3 and skin.window_frame_color.v < 0.35,
		"%s: the posters have a few colours and a dark frame" % tag)
	# The shader's palette is the skin's.
	var palette: PackedVector3Array = skin.solid_material().get_shader_parameter(&"wd_palette")
	var same: bool = palette.size() == 6
	for i: int in mini(palette.size(), 6):
		var c: Color = skin.window_ad_colors[i]
		same = same and palette[i].is_equal_approx(Vector3(c.r, c.g, c.b))
	check(same, "%s: the solid material carries the skin's ad palette" % tag)


## A saturated colour outside the decorative blue-to-violet band (GDD §5: those glow only on hazards).
static func _hazard_hue(c: Color) -> bool:
	return c.s >= 0.35 and (c.h < 0.58 or c.h > 0.8)


static func _chroma(c: Color) -> float:
	return maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))


static func _near_colour(c: Color, target: Color) -> bool:
	var dr: float = c.r - target.r
	var dg: float = c.g - target.g
	var db: float = c.b - target.b
	if sqrt(dr * dr + dg * dg + db * db) < 0.35:
		return true
	var dh: float = absf(c.h - target.h)
	return c.s > 0.5 and minf(dh, 1.0 - dh) < 25.0 / 360.0


# --- Which windows ------------------------------------------------------------------------------

## Over 3 km of both walls: window_display_share of the windows hold a display, window_screen_share of those an ad screen,
## the rest posters; the same every time; and `screen` says so.
func _shares_and_determinism(skin: MarketplaceSkin, tag: String) -> void:
	var geo := TrackGeometry.new(5, tuning)
	var total: int = 0
	var ads: int = 0
	var posters: int = 0
	var flags_ok: bool = true
	var same: bool = true
	for side: int in [-1, 1]:
		var windows: Array[Dictionary] = skin.shop_windows(side, side * geo.wall_x(), 0.0, 3000.0)
		same = same and windows == skin.shop_windows(side, side * geo.wall_x(), 0.0, 3000.0)
		for w: Dictionary in windows:
			total += 1
			var display: StringName = w["display"]
			flags_ok = flags_ok and bool(w["screen"]) == (display != &"") and [&"", &"ad", &"poster"].has(display)
			ads += 1 if display == &"ad" else 0
			posters += 1 if display == &"poster" else 0
	var share: float = float(ads + posters) / float(maxi(total, 1))
	check(same and flags_ok, "%s: the displays are the same every time and `screen` says which windows hold one" % tag)
	check(absf(share - skin.window_display_share) < 0.04,
		"%s: %.2f of %d windows hold a display (window_display_share %.2f, the TVs' share)" % [tag, share, total,
		skin.window_display_share])
	var screen_share: float = float(ads) / float(maxi(ads + posters, 1))
	check(ads > 20 and posters > 20 and absf(screen_share - skin.window_screen_share) < 0.12,
		"%s: %d ad screens and %d posters (%.2f screens; window_screen_share %.2f)" % [tag, ads, posters, screen_share,
		skin.window_screen_share])


# --- What is built ---------------------------------------------------------------------------------

## The solid vertices of display panels in a batch: [{pattern, kind, seed, centre, size, colour}] (one per rectangle).
func _panels_in(skin: MarketplaceSkin, batch: MeshBatch) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var layer: MeshLayer = batch.layer(skin.solid_material())
	var i: int = 0
	while i + 6 <= layer.size():
		var pattern: int = roundi(layer.uv2s[i].x)
		if pattern == MeshKit.PAT_WINDOW_AD or pattern == MeshKit.PAT_WINDOW_POSTER:
			var box := AABB(layer.verts[i], Vector3.ZERO)
			for j: int in 6:
				box = box.expand(layer.verts[i + j])
			var param: int = roundi(layer.uv2s[i].y)
			out.append({"pattern": pattern, "seed": param % 1000, "kind": (param / 1000) % 10, "aspect": float(param / 10000) * 0.1,
				"centre": box.get_center(), "size": box.size, "colour": layer.colors[i]})
		i += 6
	return out


## Built over 3 km: one panel to every window that holds a display, in the window, inside its display, of the right pattern
## and colours, the ads glowing at window_screen_glow and the posters lit paint; every poster kind turns up; no feed screen
## in a window.
func _built_panels(skin: MarketplaceSkin, tag: String) -> void:
	var geo := TrackGeometry.new(5, tuning)
	var wall: float = geo.wall_x()
	var wanted: int = 0
	var found: int = 0
	var problems: PackedStringArray = []
	var kinds: Dictionary = {}
	var d: float = 0.0
	while d < 1200.0:
		for side: int in [-1, 1]:
			var face_x: float = side * wall
			var batch := MeshBatch.new()
			skin.facades().build(batch, side, face_x, d, d + 40.0)
			var panels: Array[Dictionary] = _panels_in(skin, batch)
			var windows: Array[Dictionary] = skin.shop_windows(side, face_x, d, d + 40.0)
			for w: Dictionary in windows:
				if not bool(w["screen"]):
					continue
				wanted += 1
				var mine: Array[Dictionary] = []
				for p: Dictionary in panels:
					if absf(-(p["centre"] as Vector3).z - float(w["at"])) <= float(w["width"]) * 0.5:
						mine.append(p)
				if mine.size() != 1:
					problems.append("window at %.1f holds %d panels" % [float(w["at"]), mine.size()])
					continue
				found += 1
				var p: Dictionary = mine[0]
				var inside: float = absf((p["centre"] as Vector3).x) - wall
				var size: Vector3 = p["size"]
				var colour: Color = p["colour"]
				var ad: bool = w["display"] == &"ad"
				if (p["pattern"] == MeshKit.PAT_WINDOW_AD) != ad:
					problems.append("window at %.1f: the wrong pattern for a %s" % [float(w["at"]), w["display"]])
				if inside < 0.05 or inside > skin.shop_depth - 0.03:
					problems.append("window at %.1f: the panel is %.2f m in (the display is %.2f deep)" % [float(w["at"]), inside,
						skin.shop_depth])
				var y: float = (p["centre"] as Vector3).y
				if y - size.y * 0.5 < float(w["bottom"]) + 0.2 or y + size.y * 0.5 > float(w["top"]) - 0.05:
					problems.append("window at %.1f: the panel runs from %.2f to %.2f" % [float(w["at"]), y - size.y * 0.5, y + size.y * 0.5])
				if maxf(size.z, size.x) > float(w["width"]) - 0.4:
					problems.append("window at %.1f: the panel is wider than its window" % float(w["at"]))
				if ad:
					if not (is_equal_approx(colour.a, skin.window_screen_glow) and not _hazard_hue(colour)):
						problems.append("window at %.1f: the ad screen's colour %s" % [float(w["at"]), str(colour)])
				else:
					kinds[p["kind"]] = true
					var palette: Array = Array(skin.window_poster_colors)
					var from_palette: bool = false
					for c: Color in palette:
						from_palette = from_palette or (is_equal_approx(c.r, colour.r) and is_equal_approx(c.g, colour.g)
							and is_equal_approx(c.b, colour.b))
					if colour.a != 0.0 or not from_palette:
						problems.append("window at %.1f: the poster's paint %s" % [float(w["at"]), str(colour)])
			# Every panel built belongs to a window that lists a display.
			for p: Dictionary in panels:
				var owned: bool = false
				for w: Dictionary in windows:
					owned = owned or (bool(w["screen"]) and absf(-(p["centre"] as Vector3).z - float(w["at"])) <= float(w["width"]) * 0.5)
				if not owned:
					problems.append("a panel at z %.1f belongs to no display window" % (p["centre"] as Vector3).z)
		d += 40.0
		if problems.size() > 6:
			break
	check(problems.is_empty() and wanted > 40 and found == wanted,
		"%s: every display window has exactly one panel, inside its display, in its own colours (%d of %d): %s" % [tag, found,
		wanted, ", ".join(problems.slice(0, 4))])
	check(kinds.size() == 4, "%s: every poster kind (sign, sale, menu, product) turns up over 1.2 km (%s)" % [tag, str(kinds.keys())])
	await tree.process_frame


## A window a window cyborg stands in gets no display (nothing beside a screen-headed cyborg can pass for another, GDD §9.2),
## and the same window gets its display again when the cyborg is gone.
func _cyborg_windows(skin: MarketplaceSkin, tag: String) -> void:
	var geo := TrackGeometry.new(5, tuning)
	var side: int = 1
	var face_x: float = side * geo.wall_x()
	var target: Dictionary = {}
	for w: Dictionary in skin.shop_windows(side, face_x, 40.0, 200.0):
		if bool(w["screen"]):
			target = w
			break
	check(not target.is_empty(), "%s: there is a display window to put a cyborg beside" % tag)
	if target.is_empty():
		return
	var at: float = float(target["at"])
	var counts: Array[int] = []
	for cyborg: bool in [true, false]:
		var enemies: Array[Dictionary] = []
		if cyborg:
			enemies.append({"type": "window_cyborg", "at": at, "side": side})
		skin.note_wall_enemies(side, 0.0, 400.0, enemies)
		var batch := MeshBatch.new()
		skin.facades().build(batch, side, face_x, at - 20.0, at + 20.0)
		var near: int = 0
		for p: Dictionary in _panels_in(skin, batch):
			if absf(-(p["centre"] as Vector3).z - at) <= MarketCitizens.CYBORG_MARGIN:
				near += 1
		counts.append(near)
	skin.note_wall_enemies(side, 0.0, 400.0, [] as Array[Dictionary])
	check(counts == [0, 1], "%s: a window cyborg's window holds no display, and does again without it (%s)" % [tag, str(counts)])
	await tree.process_frame


## A display adds no mesh surface of its own (the solid material's layer), no feed screen, and no more vertices than the TV it
## replaces (66).
func _cost(skin: MarketplaceSkin, tag: String) -> void:
	var plain := skin.duplicate() as MarketplaceSkin
	plain.window_display_share = 0.0
	var full := skin.duplicate() as MarketplaceSkin
	full.window_display_share = 1.0
	var geo := TrackGeometry.new(5, tuning)
	var extra: int = 0
	var windows: int = 0
	var surfaces_ok: bool = true
	var feed_same: bool = true
	for d: float in [0.0, 40.0, 80.0, 120.0, 160.0]:
		var batches: Array[MeshBatch] = []
		for s: MarketplaceSkin in [plain, full]:
			var batch := MeshBatch.new()
			s.facades().build(batch, 1, geo.wall_x(), d, d + 40.0)
			batches.append(batch)
		extra += batches[1].vertex_count() - batches[0].vertex_count()
		windows += (full.shop_windows(1, geo.wall_x(), d, d + 40.0) as Array).size()
		surfaces_ok = surfaces_ok and batches[0].to_mesh().get_surface_count() == batches[1].to_mesh().get_surface_count()
		# (Billboards above the street still play the feed in both; the windows add none.)
		feed_same = feed_same and batches[1].layer(full.feed_material()).size() == batches[0].layer(plain.feed_material()).size()
	check(windows > 20 and surfaces_ok and feed_same, "%s: displays add no mesh surface and no feed screen (%d windows)" % [tag, windows])
	var per_window: float = float(extra) / float(maxi(windows, 1))
	check(per_window <= float(TV_VERTICES), "%s: a display adds %.1f vertices a window, no more than the TV's %d" % [tag, per_window, TV_VERTICES])
	await tree.process_frame


# --- The emblem's flash --------------------------------------------------------------------------

## The shader's flash envelope, mirrored (kit_window.gdshaderinc, wd_ad): whether the emblem is up on the screen of `seed` at
## time `t`, by the skin's timings.
static func _flashing(skin: MarketplaceSkin, seed: float, t: float, reduced: bool) -> bool:
	var period: float = lerpf(skin.emblem_flash_period.x, skin.emblem_flash_period.y, DashWallKit.hash11(seed * 6.7 + 2.0))
	var ph: float = fposmod(t + DashWallKit.hash11(seed * 8.9 + 4.0) * period, period)
	var times: Vector3 = skin.emblem_flash_times_reduced if reduced else skin.emblem_flash_times
	return ph < times.x + times.y + times.z


## The flash is one slow event (no strobe), Reduced flashing gives a slower, steadier one, every screen flashes at its own
## moment, and the ads' scenes cross-fade softly.
func _flash_timing(skin: MarketplaceSkin, tag: String) -> void:
	var normal: Vector3 = skin.emblem_flash_times
	var reduced: Vector3 = skin.emblem_flash_times_reduced
	check(normal.x >= MIN_FADE_IN and normal.z >= MIN_FADE_IN and skin.emblem_flash_period.x >= MIN_PERIOD
		and normal.x + normal.y + normal.z <= skin.emblem_flash_period.x * 0.25,
		"%s: the emblem fades in over %.2f s and out over %.2f s, once every %.0f-%.0f s: one event, never a strobe" % [tag,
		normal.x, normal.z, skin.emblem_flash_period.x, skin.emblem_flash_period.y])
	check(reduced.x >= 0.5 and reduced.z >= 0.5 and reduced.x > normal.x and reduced.y >= normal.y and reduced.z >= normal.z,
		"%s: with Reduced flashing the emblem fades in over %.2f s, stays %.1f s and fades out over %.2f s" % [tag, reduced.x,
		reduced.y, reduced.z])
	check(skin.ad_scene_time.x >= 3.0 and skin.ad_scene_time.y >= skin.ad_scene_time.x,
		"%s: an ad stays up %.1f-%.1f s (cross-faded over a tenth of that, never cut)" % [tag, skin.ad_scene_time.x, skin.ad_scene_time.y])
	# The shader reads the same numbers.
	var m: ShaderMaterial = skin.solid_material()
	check((m.get_shader_parameter(&"wd_flash") as Vector3).is_equal_approx(normal)
		and (m.get_shader_parameter(&"wd_flash_reduced") as Vector3).is_equal_approx(reduced)
		and (m.get_shader_parameter(&"wd_flash_period") as Vector2).is_equal_approx(skin.emblem_flash_period)
		and (m.get_shader_parameter(&"wd_scene_time") as Vector2).is_equal_approx(skin.ad_scene_time),
		"%s: the solid material carries the skin's scene and flash timings" % tag)
	# Over a 160 m stretch the screens flash at their own moments, each at least once a minute, never most at once.
	var geo := TrackGeometry.new(5, tuning)
	var seeds: Array[float] = []
	for side: int in [-1, 1]:
		var batch := MeshBatch.new()
		skin.facades().build(batch, side, side * geo.wall_x(), 400.0, 560.0)
		for p: Dictionary in _panels_in(skin, batch):
			if p["pattern"] == MeshKit.PAT_WINDOW_AD:
				seeds.append(float(p["seed"]))
	check(seeds.size() >= 3, "%s: a 160 m stretch has several ad screens (%d)" % [tag, seeds.size()])
	var worst: int = 0
	var ever: Dictionary = {}
	var t: float = 0.0
	while t < 100.0:
		var up: int = 0
		for i: int in seeds.size():
			if _flashing(skin, seeds[i], t, false):
				up += 1
				ever[i] = true
		worst = maxi(worst, up)
		t += 0.25
	check(ever.size() == seeds.size() and float(worst) <= maxf(3.0, ceilf(float(seeds.size()) * MAX_FLASHING_SHARE)),
		"%s: over 100 s every one of %d screens flashes the emblem, never more than %d at once" % [tag, seeds.size(), worst])
	var distinct: Dictionary = {}
	for seed: float in seeds:
		distinct[snappedf(DashWallKit.hash11(seed * 8.9 + 4.0), 0.02)] = true
	check(distinct.size() >= mini(seeds.size(), 3), "%s: the screens' flashes start at their own moments" % tag)


# --- The material and the shader -----------------------------------------------------------------

func _material(skin: MarketplaceSkin, tag: String) -> void:
	var m: ShaderMaterial = skin.solid_material()
	var emblem: Variant = m.get_shader_parameter(&"cult_emblem")
	check(emblem is Texture2D and (emblem as Texture2D).get_width() == CultFeed.EMBLEM_PIXELS,
		"%s: the solid material carries the owner's chosen emblem for the screens to flash" % tag)
	var warm: Vector3 = m.get_shader_parameter(&"wd_emblem")
	var neon: Color = CultFeed.emblem_color()
	check(warm.is_equal_approx(Vector3(neon.r, neon.g, neon.b)) and not _hazard_hue(neon),
		"%s: the emblem flashes in its own warm white, never a hazard hue" % tag)
	var names: Array[String] = []
	for u: Dictionary in m.shader.get_shader_uniform_list():
		names.append(String(u["name"]))
	check(names.has("wd_palette") and names.has("wd_flash") and names.has("wd_flash_reduced") and names.has("wd_flash_period")
		and names.has("wd_scene_time") and names.has("wd_emblem"), "%s: the solid shader compiles with the displays' uniforms" % tag)


func _shader_source() -> void:
	var solid: String = FileAccess.get_file_as_string("res://scripts/world/meshes/shaders/kit_solid.gdshader")
	var include: String = FileAccess.get_file_as_string("res://scripts/world/meshes/shaders/kit_window.gdshaderinc")
	check(MeshKit.PAT_WINDOW_AD == 100 and MeshKit.PAT_WINDOW_POSTER == 101, "the displays' pattern ids are 100 and 101")
	check(solid.contains("kit_window.gdshaderinc") and solid.contains("pattern >= 100 && pattern < 110")
		and solid.contains("window_surface(pattern"), "kit_solid includes and dispatches the displays' patterns")
	var flash: String = include.substr(include.find("The cult's emblem, flashed onto the screen"))
	check(flash.contains("reduced_flashing") and flash.contains("wd_flash_reduced") and flash.contains("smoothstep(0.0, times.x, ph)"),
		"the emblem's flash reads Reduced flashing and fades in and out (never a step)")
	check(include.contains("cult_mark(") and include.contains("mk_ad(") and include.contains("market_logo(")
		and include.contains("mk_shopsign("), "the displays reuse the cult emblem, the market's ad, logos and shop signs")
	check(not include.contains("step(0.5, fract(TIME"), "nothing in the displays blinks on the clock")
	# The parameter survives the GPU's interpolation: small enough not to wander by whole numbers.
	check(MeshKit.window_param(999, 9, 5.0) < 600000.0, "the displays' parameter stays small enough to interpolate exactly")

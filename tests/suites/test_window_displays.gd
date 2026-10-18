extends SkinSuite
## The shop windows' displays of the Marketplace and the Casino (task L10; GDD §5 "Cyborg Viewing Devices", the owner's
## October 17, 2026 decision): no feed TVs in the shop windows, but ad screens playing a few cycling procedurally drawn
## ads, with the cult's emblem flashing onto them every once in a while, and lit posters that fit the world.
## - which windows hold one is seeded from the window's own position, in data (window_display_share, window_screen_share),
##   keeps the old TVs' share, and shop_windows() says so (`screen`, which keeps the citizens out, and `display`, which is
##   empty in a window a window cyborg stands in);
## - every display is built where it says, wholly inside the window's display (every vertex of the face and of its frame
##   between the glass and the back wall, never sticking out of the wall), in a material of its own (one surface a chunk that has
##   displays, WindowDisplay: not a pattern of the solid kit shader, which every zone compiles), no costlier than a TV was;
## - the colour rule: the ads' palette keeps to the decorative hues (blue to violet, warm white), and the posters' paint is
##   off every hazard hue as well (no red, orange, yellow, green, cyan or pink), none near a hazard's colour;
## - the emblem's flash is a single slow event: never faster than a third of a second to come in, seconds apart, each
##   screen at its own moment, and Reduced flashing gives a slower, steadier one, read by the shader from the global
##   uniform (nothing strobes); an ad changes by a dip through the screen's dark, never two pictures at once;
## - the shader's pieces are in place (the solid kit shader knows nothing of the displays, the material compiles with its
##   uniforms, the emblem texture and the Casino's own set are on it, the warm-up draws one).

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
## How close a vertex may come to the back wall or the glass without being outside, in metres (a float's rounding).
const EDGE_TOLERANCE: float = 0.001


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
		await _warm_up(skin, skin_name)
	_fit_turn()
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
	var palette: PackedVector3Array = skin.display_material().get_shader_parameter(&"wd_palette")
	var same: bool = palette.size() == 6
	for i: int in mini(palette.size(), 6):
		var c: Color = skin.window_ad_colors[i]
		same = same and palette[i].is_equal_approx(Vector3(c.r, c.g, c.b))
	check(same, "%s: the display material carries the skin's ad palette" % tag)


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


static func _same_colour(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.004 and absf(a.g - b.g) < 0.004 and absf(a.b - b.b) < 0.004


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

## The display faces in a batch: [{kind, seed, aspect, centre, size, colour, first}] (one per rectangle of the display
## material; `first` its first vertex).
func _panels_in(skin: MarketplaceSkin, batch: MeshBatch) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var layer: MeshLayer = batch.layer(skin.display_material())
	var i: int = 0
	while i + 6 <= layer.size():
		var box := AABB(layer.verts[i], Vector3.ZERO)
		for j: int in 6:
			box = box.expand(layer.verts[i + j])
		var param: int = roundi(layer.uv2s[i].y)
		out.append({"kind": roundi(layer.uv2s[i].x), "seed": param % 1000, "aspect": float(param / 1000) * 0.1,
			"centre": box.get_center(), "size": box.size, "colour": layer.colors[i], "first": i})
		i += 6
	return out


## The frame pieces (the solid layer's dark `window_frame_color` boxes: the panel's frame, a plinth, legs or a rod) in a batch.
func _frame_vertices(skin: MarketplaceSkin, batch: MeshBatch) -> PackedVector3Array:
	var out := PackedVector3Array()
	var layer: MeshLayer = batch.layer(skin.solid_material())
	for i: int in layer.size():
		if roundi(layer.uv2s[i].x) == MeshKit.PAT_PLAIN and layer.colors[i].a == 0.0 \
				and _same_colour(layer.colors[i], skin.window_frame_color):
			out.append(layer.verts[i])
	return out


## Built over 1.2 km: one face to every window that holds a display, in the window, of the right kind and colours, the ads
## glowing at window_screen_glow and the posters lit paint; every vertex of every face and every frame piece (the plinth,
## legs and rod too) inside the window's display: between the glass and the back wall, within the window's length and
## between its sill and lintel; every poster kind turns up.
func _built_panels(skin: MarketplaceSkin, tag: String) -> void:
	var geo := TrackGeometry.new(5, tuning)
	var wall: float = geo.wall_x()
	var wanted: int = 0
	var found: int = 0
	var problems: PackedStringArray = []
	var kinds: Dictionary = {}
	var checked: int = 0
	var d: float = 0.0
	while d < 1200.0:
		for side: int in [-1, 1]:
			var face_x: float = side * wall
			var batch := MeshBatch.new()
			skin.facades().build(batch, side, face_x, d, d + 40.0)
			var panels: Array[Dictionary] = _panels_in(skin, batch)
			var frames: PackedVector3Array = _frame_vertices(skin, batch)
			var layer: MeshLayer = batch.layer(skin.display_material())
			var windows: Array[Dictionary] = skin.shop_windows(side, face_x, d, d + 40.0)
			for w: Dictionary in windows:
				if not bool(w["screen"]):
					continue
				wanted += 1
				var lo: float = float(w["at"]) - float(w["width"]) * 0.5
				var hi: float = float(w["at"]) + float(w["width"]) * 0.5
				var mine: Array[Dictionary] = []
				for p: Dictionary in panels:
					if absf(-(p["centre"] as Vector3).z - float(w["at"])) <= float(w["width"]) * 0.5:
						mine.append(p)
				if mine.size() != 1:
					problems.append("window at %.1f holds %d panels" % [float(w["at"]), mine.size()])
					continue
				found += 1
				var p: Dictionary = mine[0]
				var colour: Color = p["colour"]
				var ad: bool = w["display"] == &"ad"
				if (p["kind"] == WindowDisplay.AD) != ad:
					problems.append("window at %.1f: the wrong kind for a %s" % [float(w["at"]), w["display"]])
				if float(p["aspect"]) < 0.65 or float(p["aspect"]) > 4.3:
					problems.append("window at %.1f: the aspect %s" % [float(w["at"]), p["aspect"]])
				# Every vertex of the face and of every frame piece of this window: between the glass and the back wall.
				var vertices := PackedVector3Array()
				for k: int in range(int(p["first"]), int(p["first"]) + 6):
					vertices.append(layer.verts[k])
				for v: Vector3 in frames:
					if -v.z >= lo - 0.05 and -v.z <= hi + 0.05:
						vertices.append(v)
				for v: Vector3 in vertices:
					var inward: float = float(side) * (v.x - face_x)
					checked += 1
					if inward < -EDGE_TOLERANCE or inward > skin.shop_depth + EDGE_TOLERANCE:
						problems.append("window at %.1f: a vertex %.3f m in (the display is %.2f deep)" % [float(w["at"]), inward,
							skin.shop_depth])
					if -v.z < lo - EDGE_TOLERANCE or -v.z > hi + EDGE_TOLERANCE:
						problems.append("window at %.1f: a vertex at %.2f outside the window %.2f-%.2f" % [float(w["at"]), -v.z, lo, hi])
					if v.y < float(w["bottom"]) - EDGE_TOLERANCE or v.y > float(w["top"]) + EDGE_TOLERANCE:
						problems.append("window at %.1f: a vertex at height %.2f" % [float(w["at"]), v.y])
				if ad:
					if not (is_equal_approx(colour.a, skin.window_screen_glow) and not _hazard_hue(colour)):
						problems.append("window at %.1f: the ad screen's colour %s" % [float(w["at"]), str(colour)])
				else:
					kinds[p["kind"]] = true
					var from_palette: bool = false
					for c: Color in skin.window_poster_colors:
						from_palette = from_palette or _same_colour(c, colour)
					if colour.a != 0.0 or not from_palette or int(p["kind"]) < WindowDisplay.SIGN or int(p["kind"]) > WindowDisplay.PRODUCT:
						problems.append("window at %.1f: the poster's paint %s, kind %s" % [float(w["at"]), str(colour), p["kind"]])
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
	check(problems.is_empty() and wanted > 40 and found == wanted and checked > 1000,
		"%s: every display window has exactly one panel, every vertex of it and its frame inside the display (%d of %d, %d vertices): %s" % [
		tag, found, wanted, checked, ", ".join(problems.slice(0, 4))])
	check(kinds.size() == 4, "%s: every poster kind (sign, sale, menu, product) turns up over 1.2 km (%s)" % [tag, str(kinds.keys())])
	await tree.process_frame


## A window a window cyborg stands in gets no display (nothing beside a screen-headed cyborg can pass for another, GDD §9.2),
## shop_windows() says so too (`display` empty), and the same window gets its display again when the cyborg is gone.
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
	var listed: Array[StringName] = []
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
		for w: Dictionary in skin.shop_windows(side, face_x, at - 1.0, at + 1.0):
			if is_equal_approx(float(w["at"]), at):
				listed.append(w["display"])
	skin.note_wall_enemies(side, 0.0, 400.0, [] as Array[Dictionary])
	check(counts == [0, 1], "%s: a window cyborg's window holds no display, and does again without it (%s)" % [tag, str(counts)])
	check(listed.size() == 2 and listed[0] == &"" and listed[1] != &"",
		"%s: shop_windows() lists no display for that window while the cyborg is there (%s)" % [tag, str(listed)])
	await tree.process_frame


## A display adds one mesh surface (the display material's) to a chunk that has any, and no feed screen, and no more
## vertices (the face and its frame together) than the TV it replaces (66).
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
		surfaces_ok = surfaces_ok and batches[1].to_mesh().get_surface_count() == batches[0].to_mesh().get_surface_count() + 1 \
			and not batches[1].layer(full.display_material()).is_empty() and batches[0].layer(plain.display_material()).is_empty()
		# (Billboards above the street still play the feed in both; the windows add none.)
		feed_same = feed_same and batches[1].layer(full.feed_material()).size() == batches[0].layer(plain.feed_material()).size()
	check(windows > 20 and surfaces_ok and feed_same,
		"%s: a chunk with displays draws exactly one more surface (the display material's), and no feed screen (%d windows)" % [tag, windows])
	var per_window: float = float(extra) / float(maxi(windows, 1))
	check(per_window <= float(TV_VERTICES), "%s: a display adds %.1f vertices a window, no more than the TV's %d" % [tag, per_window, TV_VERTICES])
	await tree.process_frame


# --- The emblem's flash --------------------------------------------------------------------------

## The shader's flash envelope, mirrored (window_display.gdshaderinc, wd_ad): whether the emblem is up on the screen of `seed`
## at time `t`, by the skin's timings.
static func _flashing(skin: MarketplaceSkin, seed: float, t: float, reduced: bool) -> bool:
	var period: float = lerpf(skin.emblem_flash_period.x, skin.emblem_flash_period.y, DashWallKit.hash11(seed * 6.7 + 2.0))
	var ph: float = fposmod(t + DashWallKit.hash11(seed * 8.9 + 4.0) * period, period)
	var times: Vector3 = skin.emblem_flash_times_reduced if reduced else skin.emblem_flash_times
	return ph < times.x + times.y + times.z


## The flash is one slow event (no strobe), Reduced flashing gives a slower, steadier one, every screen flashes at its own
## moment, and the ads change by a soft dip.
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
	# An ad stays up for seconds and changes by a dip of at least a fifth of a second each way (slower still with Reduced
	# flashing), never a cut, and the dips and the picture leave most of the time to the picture.
	check(skin.ad_scene_time.x >= 3.0 and skin.ad_scene_time.y >= skin.ad_scene_time.x
		and skin.ad_dip.x * skin.ad_scene_time.x >= 0.2 and skin.ad_dip.y > skin.ad_dip.x and skin.ad_dip.y * 2.0 < 0.5,
		"%s: an ad stays up %.1f-%.1f s and changes by a dip of %.2f-%.2f s each way (%.2f of its time with Reduced flashing)" % [tag,
		skin.ad_scene_time.x, skin.ad_scene_time.y, skin.ad_dip.x * skin.ad_scene_time.x, skin.ad_dip.x * skin.ad_scene_time.y, skin.ad_dip.y])
	# The shader reads the same numbers.
	var m: ShaderMaterial = skin.display_material()
	check((m.get_shader_parameter(&"wd_flash") as Vector3).is_equal_approx(normal)
		and (m.get_shader_parameter(&"wd_flash_reduced") as Vector3).is_equal_approx(reduced)
		and (m.get_shader_parameter(&"wd_flash_period") as Vector2).is_equal_approx(skin.emblem_flash_period)
		and (m.get_shader_parameter(&"wd_scene_time") as Vector2).is_equal_approx(skin.ad_scene_time)
		and (m.get_shader_parameter(&"wd_dip") as Vector2).is_equal_approx(skin.ad_dip),
		"%s: the display material carries the skin's scene, dip and flash timings" % tag)
	# Over a 160 m stretch the screens flash at their own moments, each at least once a minute, never most at once.
	var geo := TrackGeometry.new(5, tuning)
	var seeds: Array[float] = []
	for side: int in [-1, 1]:
		var batch := MeshBatch.new()
		skin.facades().build(batch, side, side * geo.wall_x(), 400.0, 560.0)
		for p: Dictionary in _panels_in(skin, batch):
			if p["kind"] == WindowDisplay.AD:
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
	var m: ShaderMaterial = skin.display_material()
	check(m == skin.display_material() and m.shader != null, "%s: one shared display material" % tag)
	var emblem: Variant = m.get_shader_parameter(&"wd_emblem_tex")
	check(emblem is Texture2D and (emblem as Texture2D).get_width() == CultFeed.EMBLEM_PIXELS,
		"%s: the display material carries the owner's chosen emblem for the screens to flash" % tag)
	var warm: Vector3 = m.get_shader_parameter(&"wd_emblem")
	var neon: Color = CultFeed.emblem_color()
	check(warm.is_equal_approx(Vector3(neon.r, neon.g, neon.b)) and not _hazard_hue(neon),
		"%s: the emblem flashes in its own warm white, never a hazard hue" % tag)
	var names: Array[String] = []
	for u: Dictionary in m.shader.get_shader_uniform_list():
		names.append(String(u["name"]))
	check(names.has("wd_palette") and names.has("wd_flash") and names.has("wd_flash_reduced") and names.has("wd_flash_period")
		and names.has("wd_scene_time") and names.has("wd_dip") and names.has("wd_emblem") and names.has("wd_emblem_tex")
		and names.has("wd_casino") and names.has("glow_scale"), "%s: the display shader compiles with its uniforms" % tag)
	var casino: bool = skin is CasinoSkin
	check(int(m.get_shader_parameter(&"wd_casino")) == (1 if casino else 0)
		and is_equal_approx(float(m.get_shader_parameter(&"glow_scale")), skin.emissive_scale),
		"%s: the display material plays the %s ads at the skin's emissive scale" % [tag, "Casino's" if casino else "Marketplace's"])
	check(skin.solid_material() != m and skin.facade_material() != m, "%s: the displays are not drawn with the solid kit's material" % tag)


## The shader warm-up (ShaderWarmup calls the skin's warm_samples) draws one display face with the material the real displays
## use, so the Compatibility renderer never compiles it mid-run.
func _warm_up(skin: MarketplaceSkin, tag: String) -> void:
	var parent := Node3D.new()
	tree.root.add_child(parent)
	skin.warm_samples(parent)
	var drawn: bool = false
	for node: Node in parent.get_children():
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var mesh: Mesh = (node as MeshInstance3D).mesh
			for s: int in mesh.get_surface_count():
				drawn = drawn or mesh.surface_get_material(s) == skin.display_material()
	check(drawn, "%s: the warm-up draws a display face with the display material" % tag)
	parent.queue_free()
	await tree.process_frame


## How far a panel may turn and still sit inside the display: a turned panel's whole frame takes
## cos(t) * PANEL_DEPTH + sin(t) * (pw + 2 * PANEL_BORDER) of the depth (MarketFacades.fit_turn()).
func _fit_turn() -> void:
	var want: float = deg_to_rad(28.0)
	var ok: bool = true
	var shown: PackedStringArray = []
	for pw: float in [0.7, 1.0, 1.4, 1.6, 1.9, 2.1]:
		for room: float in [0.82, 0.86, 0.9]:
			var t: float = MarketFacades.fit_turn(pw, want, room)
			var across: float = pw + MarketFacades.PANEL_BORDER * 2.0
			var taken: float = cos(t) * MarketFacades.PANEL_DEPTH + sin(t) * across
			ok = ok and t >= 0.0 and t <= want + 1e-6 and taken <= room + 1e-4
			if is_equal_approx(room, 0.86):
				shown.append("%.1f m: %.0f deg" % [pw, rad_to_deg(t)])
	check(ok, "a panel turns only as far as its whole frame fits the display (at 0.86 m: %s)" % ", ".join(shown))
	check(is_equal_approx(MarketFacades.fit_turn(1.0, want, 2.0), want), "a panel in a deep display turns as much as asked")


func _shader_source() -> void:
	var solid: String = FileAccess.get_file_as_string("res://scripts/world/meshes/shaders/kit_solid.gdshader")
	var market: String = FileAccess.get_file_as_string("res://scripts/world/meshes/shaders/kit_market.gdshaderinc")
	var main: String = FileAccess.get_file_as_string("res://scripts/world/meshes/shaders/window_display.gdshader")
	var include: String = FileAccess.get_file_as_string("res://scripts/world/meshes/shaders/window_display.gdshaderinc")
	# The solid kit shader, which every zone compiles, knows nothing of the displays (their code once cost every zone seconds
	# of compile time).
	check(not solid.contains("window_display") and not solid.contains("wd_") and not market.contains("wd_")
		and market.contains("kit_market_signs.gdshaderinc"), "the solid kit shader carries none of the displays' code")
	check(main.contains("window_display.gdshaderinc") and main.contains("kit_market_signs.gdshaderinc")
		and main.contains("render_mode unshaded"), "the display material is a small unshaded shader of its own")
	var ad: String = include.substr(include.find("vec3 wd_ad("), include.find("// A poster (sRGB)") - include.find("vec3 wd_ad("))
	var flash: String = ad.substr(ad.find("The cult's emblem, flashed onto the screen"))
	check(flash.contains("reduced_flashing") and flash.contains("wd_flash_reduced") and flash.contains("smoothstep(0.0, times.x, ph)"),
		"the emblem's flash reads Reduced flashing and fades in and out (never a step)")
	# One scene a pixel: the ad is drawn once, by its own number, then dipped; no second scene is mixed in.
	check(ad.count("wd_scene(") == 1 and ad.contains("float dip = mix(wd_dip.x, wd_dip.y, reduced_flashing)")
		and ad.contains("col = mix(dusk, col, up)") and not ad.contains("fade"),
		"an ad changes by a dip through the screen's dark: one scene a pixel, never two mixed")
	check(ad.contains("seed + float(id)") and not ad.contains("seed + 7.0"), "a scene is drawn with the same seed at whatever moment")
	check(include.contains("wd_emblem_tex") and include.contains("mk_ad(") and include.contains("market_logo(")
		and include.contains("mk_shopsign("), "the displays draw the cult emblem and reuse the market's ad, logos and shop signs")
	check(include.contains("filtered_pulse(p.x * 6.0") and include.contains("1.0 - smoothstep(0.012, 0.04, max(fw.x, fw.y))"),
		"the drone's dashes and the posters' grain are filtered by distance (no shimmer)")
	check(not include.contains("step(0.5, fract(TIME"), "nothing in the displays blinks on the clock")
	# The parameter survives the GPU's interpolation: small enough not to wander by whole numbers.
	check(WindowDisplay.param(999, 5.0) < 100000.0, "the displays' parameter stays small enough to interpolate exactly")
	check(WindowDisplay.param(7, 1.8) == 18007.0 and WindowDisplay.AD == 0 and WindowDisplay.SIGN == 1, "the display face's parameter and kinds")

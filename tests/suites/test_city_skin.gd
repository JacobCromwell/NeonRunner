extends SkinSuite
## The Neon City skin (CitySkin, the prototype level's skin) and the mesh kit it is built on. The
## shared skin checks (SkinSuite): whole levels build for 3, 5 and 6 lanes without errors, the skin
## adds no collision, hazard visuals cover their hitboxes, pulsing fences show their state, triggers
## are drawn, the same chunk always looks the same, and chunk builds stay cheap. Then the cult (GDD
## §5): its feed plays on the shared CultFeed material, on roof billboards and on big screens hung
## out over the street, all far above the wall-run band and the ships and never tinted; its emblem is
## the owner's choice from the choice file, small (never below emblem_min_size, never a centrepiece)
## in its warm-white neon, on ads only (never on hazard signs), and fades out on screen when tiny.

const CITY_SKIN_PATH: String = "res://data/skins/city_skin.tres"
## The Neon City's campaign level with the most in it (pulsing fences, window cyborgs, hover trucks).
const CITY_LEVEL_PATH: String = "res://data/levels/city_3.tres"
## Screens and marks on the walls stay above this: the wall-run band tops out below 6 m (the highest
## wall run plus the runner) and the City's decorative neon starts near 9 m.
const DECOR_MIN_HEIGHT: float = 8.5


func run() -> void:
	var skin := load(CITY_SKIN_PATH) as CitySkin
	check(skin != null, "the city skin loads")
	if skin == null:
		return
	check((load(LEVEL_PATH) as LevelConfig).skin is CitySkin, "the prototype level uses the city skin")
	check(skin.enemy_variant == &"city", "city enemies wear the sleek city look")
	start_error_count()
	var env: Environment = skin.make_environment()
	check(env != null and env.sky != null and env.glow_enabled and env.fog_enabled, "the city environment has a sky, glow and fog")
	_kit()
	for lanes: int in [3, 5, 6]:
		await whole_level(skin, "city", LEVEL_PATH, lanes)
	await hazards_and_triggers(skin)
	await determinism(skin, LEVEL_PATH)
	await _greybox_still_works()
	await _cult_feed(skin)
	await _cult_emblem(skin)
	stop_error_count("building city levels")


# --- The cult (GDD §5) --------------------------------------------------------------------------

## The feed (CultFeed, "Cyborg Viewing Devices") plays on the shared material, on both kinds of screen
## the skin lists; over a whole level every screen it builds is one the listing names, plays the
## untinted picture, faces the street or the oncoming traffic, and hangs far above the wall-run band
## (and, over the lanes, above the ships' tops).
func _cult_feed(skin: CitySkin) -> void:
	check(skin.feed_material() == CultFeed.material(), "the city plays the shared feed")
	var geo := TrackGeometry.new(5, tuning)
	var wall: float = geo.wall_x()
	var kinds: Dictionary = {}
	var listed: Array[Dictionary] = []
	for side: int in [-1, 1]:
		for board: Dictionary in skin.feed_boards(side, side * wall, -100.0, 3000.0):
			kinds[board["kind"]] = int(kinds.get(board["kind"], 0)) + 1
			listed.append(board)
	check(int(kinds.get(&"roof_board", 0)) > 0 and int(kinds.get(&"tower_screen", 0)) > 0,
		"over 3 km the feed plays on roof billboards (%d) and on the towers' big screens (%d)" % [
			kinds.get(&"roof_board", 0), kinds.get(&"tower_screen", 0)])
	# The ships (CityShip) rise less than 3 m above their underside.
	var ship_top: float = tuning.ceiling_height + 3.0
	var screens: Array[Dictionary] = []
	var bad: PackedStringArray = []
	await visit_level(level(CITY_LEVEL_PATH, 5, 0.6), skin, func(m: MeshInstance3D, arrays: Array, material: Material) -> void:
		if material != skin.feed_material():
			return
		for r: Dictionary in rects_of(m, arrays):
			screens.append(r)
			var lowest: float = minf(r["o"].y, minf(r["ov"].y, r["ou"].y))
			var over_lanes: bool = absf(r["center"].x) < geo.half_width()
			var c: Color = r["color"]
			var n: Vector3 = r["normal"]
			var facing: bool = n.is_equal_approx(Vector3.BACK) or n.is_equal_approx(Vector3(-signf(r["center"].x), 0, 0))
			if (lowest < DECOR_MIN_HEIGHT or (over_lanes and lowest < maxf(ship_top, skin.feed_screen_bottom - 0.01))
					or not _same_rgb(c, Color.WHITE) or not facing or under_hazard(m)) and bad.size() < 4:
				bad.append("%s (normal %s, colour %s)" % [r["center"], n, c]))
	print("  city feed (5 lanes): %d roof billboards and %d hung screens over 3 km of walls, %d screens over City 3" % [
		kinds.get(&"roof_board", 0), kinds.get(&"tower_screen", 0), screens.size()])
	var unlisted: int = 0
	for r: Dictionary in screens:
		var found: bool = false
		for board: Dictionary in listed:
			found = found or (board["center"] as Vector3).distance_to(r["center"]) < 0.05
		unlisted += int(not found)
	check(not screens.is_empty() and bad.is_empty(),
		"over a whole level the feed's %d screens face the street or the traffic, untinted, far above the wall-run band and the ships: %s" % [
			screens.size(), ", ".join(bad)])
	check(unlisted == 0, "every feed screen built is one feed_boards() lists (%d unlisted)" % unlisted)


## The emblem (GDD §5, hidden in plain sight): the owner's choice (the choice file, never a
## hardcoded option), drawn by CultEmblem, carried by the kit material for PAT_CULT_MARK; over a whole
## level and 3 km of walls it hides on roof billboards and banners, in its own warm-white neon, each
## at least emblem_min_size across and small beside its ad, high on the walls, never on a hazard.
func _cult_emblem(skin: CitySkin) -> void:
	var choice := load(CultFeed.CHOICE_PATH) as CultEmblemChoice
	check(choice != null and CultFeed.emblem_option() == choice.option,
		"the city draws the cult emblem the owner picked (option %s)" % (CultEmblem.option_letter(choice.option)
			if choice != null else "?"))
	if choice == null:
		return
	var scheme: Dictionary = CultEmblem.default_scheme(choice.option)
	check(skin.emblem_color() == scheme["neon"] and skin.emblem_glow > 0.0,
		"it glows in the chosen emblem's own warm-white neon")
	var texture := skin.solid_material().get_shader_parameter("cult_emblem") as ImageTexture
	var expected: Image = CultEmblem.build_image(choice.option, CultFeed.EMBLEM_PIXELS, Color.WHITE, Color.WHITE,
		Color(1.0, 1.0, 1.0, 0.0))
	var same: bool = texture != null and texture.get_image().get_width() == expected.get_width()
	var covered: int = 0
	if same:
		var got: Image = texture.get_image()
		for y: int in range(0, expected.get_height(), 4):
			for x: int in range(0, expected.get_width(), 4):
				same = same and is_equal_approx(got.get_pixel(x, y).a, expected.get_pixel(x, y).a)
				covered += int(expected.get_pixel(x, y).a > 0.99)
	check(same and covered > 20, "the kit material carries CultEmblem's drawing of that option (%d covered samples)" % covered)
	var shader_code: String = skin.solid_material().shader.code
	check(shader_code.contains("kit_cult.gdshaderinc") and FileAccess.get_file_as_string(
		"res://scripts/world/meshes/shaders/kit_cult.gdshaderinc").contains("cult_mark("),
		"the mark fades out on screen when tiny, like the feed's and Gangland's (cult_mark)")
	# Listed over 3 km of both walls: both kinds, each within the size rule.
	var geo := TrackGeometry.new(5, tuning)
	var kinds: Dictionary = {}
	var sizes_ok: bool = true
	for side: int in [-1, 1]:
		for e: Dictionary in skin.cult_emblems(side, side * geo.wall_x(), -100.0, 3000.0):
			kinds[e["kind"]] = int(kinds.get(e["kind"], 0)) + 1
			sizes_ok = sizes_ok and float(e["size"]) >= skin.emblem_min_size - 0.001 and float(e["size"]) <= 1.6
	check(int(kinds.get(&"roof_board", 0)) > 0 and int(kinds.get(&"banner", 0)) > 0 and sizes_ok,
		"over 3 km the emblem hides on roof billboards (%d) and banners (%d), %.2f-1.6 m across" % [
			kinds.get(&"roof_board", 0), kinds.get(&"banner", 0), skin.emblem_min_size])
	# Built over a whole level: every mark (hazard signs use the same solid material).
	var marks: Array[Dictionary] = []
	var bad: PackedStringArray = []
	await visit_level(level(CITY_LEVEL_PATH, 5, 0.6), skin, func(m: MeshInstance3D, arrays: Array, material: Material) -> void:
		if material != skin.solid_material():
			return
		for r: Dictionary in rects_of(m, arrays):
			if r["pattern"] != MeshKit.PAT_CULT_MARK:
				continue
			marks.append(r)
			# The mark's square spans UV -1..1 of the rect.
			var span: float = absf(float(r["uv1"].x) - float(r["uv0"].x))
			var size: float = (r["ou"] - r["o"]).length() / span * 2.0
			var c: Color = r["color"]
			var lowest: float = minf(r["o"].y, minf(r["ov"].y, r["ou"].y))
			var colour_ok: bool = (c.a > 0.0 and _same_rgb(c, scheme["neon"])) or (c.a == 0.0 and _same_rgb(c, scheme["metal"]))
			if (under_hazard(m) or size < skin.emblem_min_size - 0.001 or size > 1.6 or not colour_ok
					or lowest < DECOR_MIN_HEIGHT) and bad.size() < 4:
				bad.append("%s: %.2f m, colour %s%s" % [r["center"], size, c, " (on a hazard)" if under_hazard(m) else ""]))
	print("  city emblem (5 lanes): %d on roof billboards and %d on banners over 3 km of walls, %d over City 3" % [
		kinds.get(&"roof_board", 0), kinds.get(&"banner", 0), marks.size()])
	check(not marks.is_empty() and bad.is_empty(),
		"over a whole level its %d marks are warm-white neon, %.2f-1.6 m across, high on the walls, never on a hazard: %s" % [
			marks.size(), skin.emblem_min_size, ", ".join(bad)])


## Mesh kit basics other skins build on: hashing, face masks, winding, one surface per material.
func _kit() -> void:
	check(MeshKit.hash_i(3, 7, 11) == MeshKit.hash_i(3, 7, 11) and MeshKit.hash_i(3, 7, 11) != MeshKit.hash_i(3, 7, 12),
		"kit hashing is deterministic and changes with its inputs")
	var in_range: bool = true
	for i: int in 500:
		var v: float = MeshKit.hash01(i, -i, 5)
		in_range = in_range and v >= 0.0 and v < 1.0
	check(in_range, "hash01 stays in [0, 1)")
	var full := MeshLayer.new()
	full.box(Vector3.ZERO, Vector3.ONE, Color.WHITE)
	check(full.size() == 36, "a box is 36 vertices (%d)" % full.size())
	var open := MeshLayer.new()
	open.box(Vector3.ZERO, Vector3.ONE, Color.WHITE, 0.0, MeshKit.PAT_PLAIN, MeshKit.NO_BOTTOM)
	check(open.size() == 30, "hidden box sides are skipped (%d)" % open.size())
	check(_winds_outward(full), "box faces wind clockwise seen from outside (Godot's front faces)")
	var mirrored := MeshLayer.new()
	mirrored.box_xform(Transform3D(Basis.from_scale(Vector3(-2.0, 1.0, 1.0)), Vector3.ZERO), Color.WHITE)
	var template := MeshLayer.new()
	template.prism(Vector3(0, -0.5, 0), 1.0, 1.0, 6, Color.WHITE)
	mirrored.append(template, Transform3D(Basis.from_scale(Vector3(1.0, 1.0, -1.0)), Vector3.ZERO))
	check(_winds_outward(mirrored), "mirroring transforms keep faces winding outward")
	var batch := MeshBatch.new()
	batch.layer(MeshKit.solid()).box(Vector3.ZERO, Vector3.ONE, Color.WHITE)
	batch.layer(MeshKit.glow()).rect(Vector3.ZERO, Vector3.RIGHT, Vector3.UP, Color.WHITE, 1.0, MeshKit.SHAPE_RADIAL)
	batch.layer(MeshKit.solid()).box(Vector3.ONE, Vector3.ONE, Color.RED)
	var mesh: ArrayMesh = batch.to_mesh()
	check(mesh != null and mesh.get_surface_count() == 2 and mesh.surface_get_material(0) == MeshKit.solid(),
		"a batch commits one surface per material")
	# Lots: a run starts every third lot at the latest, and neighbouring runs meet without overlap.
	var runs_ok: bool = true
	var span: Vector2i = MeshKit.lot_run(1, -7, 0.45)
	for i: int in 40:
		var next: Vector2i = MeshKit.lot_run(1, span.y + 1, 0.45)
		runs_ok = runs_ok and next.x == span.y + 1 and next.y - next.x < 3 and MeshKit.lot_run(1, next.y, 0.45) == next
		span = next
	check(runs_ok, "building lots split a wall into runs of 1-3 lots that tile it")


## Every triangle of a closed convex shape around the origin faces away from its centre.
func _winds_outward(layer: MeshLayer) -> bool:
	for t: int in range(0, layer.size(), 3):
		var a: Vector3 = layer.verts[t]
		var b: Vector3 = layer.verts[t + 1]
		var c: Vector3 = layer.verts[t + 2]
		if (c - a).cross(b - a).dot((a + b + c) / 3.0) <= 0.0:
			return false
	return true


## Vertex colours come back quantised to 8 bits.
static func _same_rgb(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01


## Tests and anything without a skin still get the grey box.
func _greybox_still_works() -> void:
	var layout: LevelLayout = level(LEVEL_PATH, 3, 0.3)
	var stats: Dictionary = await build_all(layout, GreyboxSkin.new())
	check(stats["chunks_without_visuals"] == 0 and stats["chunks"] > 10, "the grey-box skin still builds a whole level")

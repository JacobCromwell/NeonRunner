extends SkinSuite
## The Neon City skin (CitySkin, the prototype level's skin) and the mesh kit it is built on. The
## shared skin checks (SkinSuite): whole levels build for 3, 5 and 6 lanes without errors, the skin
## adds no collision, hazard visuals cover their hitboxes, pulsing fences show their state, triggers
## are drawn, the same chunk always looks the same, and chunk builds stay cheap.

const CITY_SKIN_PATH: String = "res://data/skins/city_skin.tres"


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
	stop_error_count("building city levels")


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


## Tests and anything without a skin still get the grey box.
func _greybox_still_works() -> void:
	var layout: LevelLayout = level(LEVEL_PATH, 3, 0.3)
	var stats: Dictionary = await build_all(layout, GreyboxSkin.new())
	check(stats["chunks_without_visuals"] == 0 and stats["chunks"] > 10, "the grey-box skin still builds a whole level")

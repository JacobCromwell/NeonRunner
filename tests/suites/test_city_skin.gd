extends TestSuite
## The Neon City skin (CitySkin, the prototype level's skin): whole levels build for 3, 5 and 6 lanes
## without errors, the skin adds no collision, hazard visuals cover their hitboxes, pulsing fences
## show their state, the same chunk always looks the same, and chunk builds stay cheap.

const CITY_SKIN_PATH: String = "res://data/skins/city_skin.tres"
## One chunk build with the city skin, headless (no GPU upload). Measured ~1 ms on a dev machine;
## the budget leaves room for slower CI machines but catches a skin that got expensive.
const BUILD_BUDGET_MEAN_MS: float = 4.0
const BUILD_BUDGET_MAX_MS: float = 16.0
## Visible mesh surfaces (one draw call each when on screen) a 5-lane chunk may add on average.
const SURFACE_BUDGET_PER_CHUNK: float = 32.0


## Collects engine and script errors (not warnings) while the suite builds levels.
class ErrorCounter extends Logger:
	var errors: PackedStringArray = []
	var _mutex := Mutex.new()

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_mutex.lock()
		errors.append("%s:%d %s %s" % [file, line, code, rationale])
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


func run() -> void:
	var skin := load(CITY_SKIN_PATH) as CitySkin
	check(skin != null, "the city skin loads")
	if skin == null:
		return
	check((load(LEVEL_PATH) as LevelConfig).skin is CitySkin, "the prototype level uses the city skin")
	var counter := ErrorCounter.new()
	OS.add_logger(counter)
	var env: Environment = skin.make_environment()
	check(env != null and env.sky != null and env.glow_enabled and env.fog_enabled, "the city environment has a sky, glow and fog")
	_kit()
	for lanes: int in [3, 5, 6]:
		await _whole_level(skin, lanes)
	await _hazards(skin)
	await _determinism(skin)
	await _greybox_still_works()
	OS.remove_logger(counter)
	check(counter.errors.is_empty(), "no errors while building city levels:\n  " + "\n  ".join(counter.errors.slice(0, 8)))


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


## Every triangle of a closed convex shape around the origin faces away from its centre.
func _winds_outward(layer: MeshLayer) -> bool:
	for t: int in range(0, layer.size(), 3):
		var a: Vector3 = layer.verts[t]
		var b: Vector3 = layer.verts[t + 1]
		var c: Vector3 = layer.verts[t + 2]
		if (c - a).cross(b - a).dot((a + b + c) / 3.0) <= 0.0:
			return false
	return true


func _level(lanes: int, difficulty: float, level_seed: int = 3) -> LevelLayout:
	var config := (load(LEVEL_PATH) as LevelConfig).duplicate() as LevelConfig
	config.lane_count = lanes
	config.difficulty = difficulty
	config.level_seed = level_seed
	return LevelGenerator.new().generate(config, tuning, LevelGenerator.load_patterns(config.patterns_path))


func _whole_level(skin: ZoneSkin, lanes: int) -> void:
	var tag: String = "(%d lanes)" % lanes
	var layout: LevelLayout = _level(lanes, 0.6)
	var city: Dictionary = await _build_all(layout, skin)
	var bare: Dictionary = await _build_all(layout, ZoneSkin.new())
	check(city["chunks"] == ceili((layout.length + TrackBuilder.RUN_OUT) / TrackBuilder.CHUNK_LENGTH) + 1,
		"every chunk of the level is built %s: %d" % [tag, city["chunks"]])
	check(city["collision_objects"] == bare["collision_objects"] and city["collision_shapes"] == bare["collision_shapes"],
		"the skin adds no collision objects or shapes %s: %d/%d vs %d/%d" % [tag, city["collision_objects"],
			city["collision_shapes"], bare["collision_objects"], bare["collision_shapes"]])
	check(city["physics_under_visuals"] == 0, "no physics nodes under skin visuals %s" % tag)
	check(city["chunks_without_visuals"] == 0, "every chunk has visuals %s (%d without)" % [tag, city["chunks_without_visuals"]])
	var times: Array = city["times"]
	var mean: float = 0.0
	var worst: float = 0.0
	for t: float in times:
		mean += t / times.size()
		worst = maxf(worst, t)
	var surfaces: float = float(city["surfaces"]) / city["chunks"]
	print("  city skin %s: %d chunks, build mean %.2f ms, max %.2f ms, %.1f surfaces and %d vertices per chunk" % [
		tag, city["chunks"], mean, worst, surfaces, city["vertices"] / city["chunks"]])
	check(mean < BUILD_BUDGET_MEAN_MS, "chunk build time %s: mean %.2f ms (budget %.1f)" % [tag, mean, BUILD_BUDGET_MEAN_MS])
	check(worst < BUILD_BUDGET_MAX_MS, "chunk build time %s: max %.2f ms (budget %.1f)" % [tag, worst, BUILD_BUDGET_MAX_MS])
	if lanes == 5:
		check(surfaces < SURFACE_BUDGET_PER_CHUNK, "mesh surfaces per chunk %s: %.1f (budget %.0f)" % [
			tag, surfaces, SURFACE_BUDGET_PER_CHUNK])


## Builds a whole level chunk by chunk and tallies what each new chunk contains.
func _build_all(layout: LevelLayout, skin: ZoneSkin) -> Dictionary:
	var world := Node3D.new()
	tree.root.add_child(world)
	var track := TrackBuilder.new()
	world.add_child(track)
	track.set_layout(layout, tuning, skin)
	var stats := {"chunks": 0, "collision_objects": 0, "collision_shapes": 0, "physics_under_visuals": 0,
		"chunks_without_visuals": 0, "surfaces": 0, "vertices": 0, "times": []}
	var seen: Dictionary = {}
	var d: float = 0.0
	while d <= layout.length + TrackBuilder.RUN_OUT + TrackBuilder.CHUNK_LENGTH:
		var t0: int = Time.get_ticks_usec()
		track.update(d, d / tuning.run_speed)
		var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
		var fresh: int = 0
		for chunk: Node in track.get_children():
			if not seen.has(chunk):
				seen[chunk] = true
				fresh += 1
				_tally(chunk, stats)
		# The first update builds several chunks and the shared templates; time the steady state.
		if d > 0.0 and fresh > 0:
			stats["times"].append(ms / fresh)
		d += TrackBuilder.CHUNK_LENGTH
	stats["chunks"] = seen.size()
	world.queue_free()
	await tree.process_frame
	return stats


func _tally(chunk: Node, stats: Dictionary) -> void:
	var visuals: int = 0
	var stack: Array[Node] = [chunk]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is CollisionObject3D:
			stats["collision_objects"] += 1
		elif node is CollisionShape3D or node is CollisionPolygon3D:
			stats["collision_shapes"] += 1
		if (node is CollisionObject3D or node is CollisionShape3D) and _has_visual_ancestor(node, chunk):
			stats["physics_under_visuals"] += 1
		var mesh_node := node as MeshInstance3D
		if mesh_node != null and mesh_node.visible and mesh_node.mesh != null:
			visuals += 1
			stats["surfaces"] += mesh_node.mesh.get_surface_count()
			var array_mesh := mesh_node.mesh as ArrayMesh
			if array_mesh != null:
				for s: int in array_mesh.get_surface_count():
					stats["vertices"] += array_mesh.surface_get_array_len(s)
		stack.append_array(node.get_children())
	if visuals == 0:
		stats["chunks_without_visuals"] += 1


func _has_visual_ancestor(node: Node, chunk: Node) -> bool:
	var parent: Node = node.get_parent()
	while parent != null and parent != chunk:
		if parent is VisualInstance3D or parent is HazardStateVisual:
			return true
		parent = parent.get_parent()
	return false


## Fences and signs: visuals cover the hitbox, gapped fences are open below, states switch materials.
func _hazards(skin: ZoneSkin) -> void:
	var layout := RunSim.layout(5, 200.0)
	var pulsing := RunSim.fence(2, 40.0, "full")
	pulsing["pulsing"] = true
	layout.fences.append(pulsing)
	layout.fences.append(RunSim.fence(1, 40.0, "gapped"))
	layout.signs.append({"side": 1, "start": 60.0, "end": 70.0, "bottom": 2.8, "top": 5.5})
	layout.signs.append({"side": -1, "start": 80.0, "end": 88.0, "bottom": 0.0, "top": 1.4})
	var world := Node3D.new()
	tree.root.add_child(world)
	var track := TrackBuilder.new()
	world.add_child(track)
	track.set_layout(layout, tuning, skin)
	track.update(0.0, 0.0)
	var hazards: Array[Hazard] = []
	var stack: Array[Node] = [track]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Hazard:
			hazards.append(node)
		stack.append_array(node.get_children())
	check(hazards.size() == 4, "the test layout has 2 fences and 2 signs (%d hazards)" % hazards.size())
	for hazard: Hazard in hazards:
		var hitbox: AABB = _hitbox(hazard)
		var visual: AABB = _visual_bounds(hazard)
		check(visual.grow(0.001).encloses(hitbox), "%s at %s: the visual (%s) covers the hitbox (%s)" % [
			hazard.hazard_name, hazard.position, visual, hitbox])
		if hazard.hazard_name.begins_with("fence (gapped"):
			var world_bottom: float = hazard.position.y + _field_bounds(hazard).position.y
			check(world_bottom > 0.5, "a gapped fence's field is visibly open underneath (bottom at %.2f m)" % world_bottom)
		if hazard.hazard_name.contains("pulsing"):
			var state_visual: HazardStateVisual = null
			for child: Node in hazard.get_children():
				if child is HazardStateVisual:
					state_visual = child
			check(state_visual != null, "a pulsing fence has a state visual")
			if state_visual == null:
				continue
			var shown: Array[Material] = []
			for state: Hazard.State in [Hazard.State.ON, Hazard.State.WARNING, Hazard.State.OFF]:
				hazard.state = state
				hazard.state_changed.emit(state)
				shown.append(state_visual.material_of(0))
				check(state_visual.material_of(1) != null, "the fence's glowing parts follow state %d" % state)
			check(shown[0] != shown[1] and shown[1] != shown[2] and shown[0] != shown[2],
				"the fence field looks different when ON, WARNING and OFF")
			check(shown[2] is ShaderMaterial and float((shown[2] as ShaderMaterial).get_shader_parameter("intensity")) == 0.0,
				"an OFF fence shows no energy field")
	world.queue_free()
	await tree.process_frame


func _hitbox(hazard: Hazard) -> AABB:
	for child: Node in hazard.get_children():
		if child is CollisionShape3D:
			var size: Vector3 = ((child as CollisionShape3D).shape as BoxShape3D).size
			return AABB(-size * 0.5, size)
	return AABB()


## Union of the skin's visible meshes under a hazard, in hazard space (the debug hitbox is hidden).
func _visual_bounds(hazard: Hazard) -> AABB:
	var out := AABB()
	var first: bool = true
	for child: Node in hazard.get_children():
		var m := child as MeshInstance3D
		if m == null or not m.visible or m.mesh == null or m.is_in_group(&"debug_hitbox"):
			continue
		var box: AABB = m.transform * m.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out


## The energy field's bounds (the mesh whose material follows the state; the first visual child).
func _field_bounds(hazard: Hazard) -> AABB:
	for child: Node in hazard.get_children():
		var m := child as MeshInstance3D
		if m != null and m.visible and not m.is_in_group(&"debug_hitbox"):
			return m.transform * m.get_aabb()
	return AABB()


## Variety comes from hashing track positions: rebuilding a level gives identical meshes.
func _determinism(skin: ZoneSkin) -> void:
	var layout: LevelLayout = _level(5, 0.4, 7)
	var a: Array = await _mesh_signature(layout, skin)
	var b: Array = await _mesh_signature(layout, skin)
	check(not a.is_empty() and a == b, "rebuilding the same level gives the same meshes (%d meshes)" % a.size())


func _mesh_signature(layout: LevelLayout, skin: ZoneSkin) -> Array:
	var world := Node3D.new()
	tree.root.add_child(world)
	var track := TrackBuilder.new()
	world.add_child(track)
	track.set_layout(layout, tuning, skin)
	track.update(400.0, 0.0)
	var out: Array = []
	var stack: Array[Node] = [track]
	while not stack.is_empty():
		var node: Node = stack.pop_front()
		var m := node as MeshInstance3D
		if m != null and m.mesh != null and not m.is_in_group(&"debug_hitbox"):
			var sig: Array = [m.global_position.snapped(Vector3.ONE * 0.001)]
			for s: int in m.mesh.get_surface_count():
				var arrays: Array = m.mesh.surface_get_arrays(s)
				sig.append(arrays[Mesh.ARRAY_VERTEX].size())
				sig.append(hash(arrays[Mesh.ARRAY_VERTEX]))
				sig.append(hash(arrays[Mesh.ARRAY_COLOR]))
			out.append(sig)
		stack.append_array(node.get_children())
	world.queue_free()
	await tree.process_frame
	return out


## Tests and anything without a skin still get the grey box.
func _greybox_still_works() -> void:
	var layout: LevelLayout = _level(3, 0.3)
	var stats: Dictionary = await _build_all(layout, GreyboxSkin.new())
	check(stats["chunks_without_visuals"] == 0 and stats["chunks"] > 10, "the grey-box skin still builds a whole level")

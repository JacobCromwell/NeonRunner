class_name SkinSuite
extends TestSuite
## Shared checks for zone skin suites (test_city_skin, test_gangland_skin): whole levels build for
## 3, 5 and 6 lanes without errors, the skin adds no collision, hazard visuals cover their hitboxes,
## gapped fences are open underneath, pulsing fences show their state, triggers are drawn, the same
## chunk always looks the same, and chunk builds stay cheap.

## One chunk build, headless (no GPU upload). Measured ~1 ms on a dev machine; the budget leaves room
## for slower CI machines but catches a skin that got expensive.
const BUILD_BUDGET_MEAN_MS: float = 4.0
const BUILD_BUDGET_MAX_MS: float = 16.0
## Timed builds of the dressed level whole_level() takes, keeping the fastest of the three per build
## step (T-BUDGET): several agents' test runs can share this machine's CPUs, and OS preemption only
## ever adds wall-clock time to a build, never removes it, so the minimum across a few fresh builds
## stays a faithful reading of the skin's real cost even when one pass gets paused mid-build.
const BUILD_TIMING_PASSES: int = 3
## Visible mesh surfaces (one draw call each when on screen) a 5-lane chunk may add on average.
const SURFACE_BUDGET_PER_CHUNK: float = 32.0


## Collects engine and script errors (not warnings) while a suite builds levels.
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


var _counter: ErrorCounter


func start_error_count() -> void:
	_counter = ErrorCounter.new()
	OS.add_logger(_counter)


func stop_error_count(what: String) -> void:
	OS.remove_logger(_counter)
	check(_counter.errors.is_empty(), "no errors while %s:\n  %s" % [what, "\n  ".join(_counter.errors.slice(0, 8))])


## The level at `level_path`, generated for this many lanes.
func level(level_path: String, lanes: int, difficulty: float, level_seed: int = 3) -> LevelLayout:
	var config := (load(level_path) as LevelConfig).duplicate() as LevelConfig
	config.lane_count = lanes
	config.difficulty = difficulty
	config.level_seed = level_seed
	return LevelGenerator.new().generate(config, tuning, LevelGenerator.load_patterns(config.patterns_path))


## Builds a whole level with `skin` and with no skin, compares them and checks the budgets.
func whole_level(skin: ZoneSkin, name: String, level_path: String, lanes: int) -> void:
	var tag: String = "(%d lanes)" % lanes
	var layout: LevelLayout = level(level_path, lanes, 0.6)
	# Only the dressed build's time is checked against the budget, so only it pays for extra passes;
	# the bare comparison build (for the collision counts below) needs just the one.
	var dressed: Dictionary = await build_all(layout, skin, BUILD_TIMING_PASSES)
	var bare: Dictionary = await build_all(layout, ZoneSkin.new())
	check(dressed["chunks"] == ceili((layout.length + TrackBuilder.RUN_OUT) / TrackBuilder.CHUNK_LENGTH) + 1,
		"every chunk of the level is built %s: %d" % [tag, dressed["chunks"]])
	check(dressed["collision_objects"] == bare["collision_objects"] and dressed["collision_shapes"] == bare["collision_shapes"],
		"the skin adds no collision objects or shapes %s: %d/%d vs %d/%d" % [tag, dressed["collision_objects"],
			dressed["collision_shapes"], bare["collision_objects"], bare["collision_shapes"]])
	check(dressed["physics_under_visuals"] == 0, "no physics nodes under skin visuals %s" % tag)
	check(dressed["chunks_without_visuals"] == 0, "every chunk has visuals %s (%d without)" % [tag,
		dressed["chunks_without_visuals"]])
	check(dressed["bare_triggers"] == 0, "every pad, ramp and speed pad is drawn %s (%d bare of %d)" % [tag,
		dressed["bare_triggers"], dressed["triggers"]])
	var times: Array = dressed["times"]
	var mean: float = 0.0
	var worst: float = 0.0
	for t: float in times:
		mean += t / times.size()
		worst = maxf(worst, t)
	var surfaces: float = float(dressed["surfaces"]) / dressed["chunks"]
	print("  %s skin %s: %d chunks, build mean %.2f ms, max %.2f ms, %.1f surfaces and %d vertices per chunk" % [
		name, tag, dressed["chunks"], mean, worst, surfaces, dressed["vertices"] / dressed["chunks"]])
	check(mean < BUILD_BUDGET_MEAN_MS, "chunk build time %s: mean %.2f ms (budget %.1f)" % [tag, mean, BUILD_BUDGET_MEAN_MS])
	check(worst < BUILD_BUDGET_MAX_MS, "chunk build time %s: max %.2f ms (budget %.1f)" % [tag, worst, BUILD_BUDGET_MAX_MS])
	if lanes == 5:
		check(surfaces < SURFACE_BUDGET_PER_CHUNK, "mesh surfaces per chunk %s: %.1f (budget %.0f)" % [
			tag, surfaces, SURFACE_BUDGET_PER_CHUNK])


## Builds a whole level chunk by chunk and tallies what each new chunk contains. `timing_passes`
## builds the level this many times over (a fresh TrackBuilder and world each time, as a single pass
## always did) and keeps, per build step, the minimum time seen across passes -- see
## BUILD_TIMING_PASSES. The tallies (surfaces, vertices, collision, triggers) come from the first
## pass only; only its "times" differ from a single pass's own.
func build_all(layout: LevelLayout, skin: ZoneSkin, timing_passes: int = 1) -> Dictionary:
	var stats: Dictionary = await _build_once(layout, skin)
	for _p: int in (timing_passes - 1):
		var extra: Dictionary = await _build_once(layout, skin)
		var times: Array = stats["times"]
		var extra_times: Array = extra["times"]
		for i: int in mini(times.size(), extra_times.size()):
			times[i] = minf(times[i], extra_times[i])
	return stats


## One build of a whole level, chunk by chunk, tallying what each new chunk contains.
func _build_once(layout: LevelLayout, skin: ZoneSkin) -> Dictionary:
	var world := Node3D.new()
	tree.root.add_child(world)
	var track := TrackBuilder.new()
	world.add_child(track)
	track.set_layout(layout, tuning, skin)
	var stats := {"chunks": 0, "collision_objects": 0, "collision_shapes": 0, "physics_under_visuals": 0,
		"chunks_without_visuals": 0, "surfaces": 0, "vertices": 0, "times": [], "triggers": 0, "bare_triggers": 0}
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
		if node is Area3D and node.has_meta(&"kind"):
			stats["triggers"] += 1
			if visible_meshes(node).is_empty():
				stats["bare_triggers"] += 1
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


## The skin's visible meshes directly under a node (the debug hitbox excluded).
func visible_meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for child: Node in node.get_children():
		var m := child as MeshInstance3D
		if m != null and m.visible and m.mesh != null and not m.is_in_group(&"debug_hitbox"):
			out.append(m)
	return out


## A hand-built 5-lane layout with every kind of hazard and trigger, built around distance 0.
func showcase_track(skin: ZoneSkin) -> TrackBuilder:
	var layout := RunSim.layout(5, 200.0)
	var pulsing := RunSim.fence(2, 40.0, "full")
	pulsing["pulsing"] = true
	layout.fences.append(pulsing)
	layout.fences.append(RunSim.fence(1, 40.0, "gapped"))
	layout.signs.append({"side": 1, "start": 60.0, "end": 70.0, "bottom": 2.8, "top": 5.5})
	layout.signs.append({"side": -1, "start": 80.0, "end": 88.0, "bottom": 0.0, "top": 1.4})
	layout.gaps.append({"lane": 3, "start": 50.0, "end": 57.0})
	layout.pads.append({"lane": 0, "at": 20.0})
	layout.ramps.append({"side": 1, "at": 90.0})
	layout.speed_pads.append({"lane": 2, "at": 100.0})
	layout.hulls.append({"start": 110.0, "end": 150.0})
	var world := Node3D.new()
	tree.root.add_child(world)
	var track := TrackBuilder.new()
	world.add_child(track)
	track.set_layout(layout, tuning, skin)
	track.update(0.0, 0.0)
	return track


## Builds a whole level chunk by chunk and calls visit(mesh, arrays, material) once for every surface
## of every chunk's meshes (the debug hitbox left out), while the mesh is still in the tree, for
## checks on what a skin puts where.
func visit_level(layout: LevelLayout, skin: ZoneSkin, visit: Callable) -> void:
	var world := Node3D.new()
	tree.root.add_child(world)
	var track := TrackBuilder.new()
	world.add_child(track)
	track.set_layout(layout, tuning, skin)
	var seen: Dictionary = {}
	var d: float = 0.0
	while d <= layout.length + TrackBuilder.RUN_OUT + TrackBuilder.CHUNK_LENGTH:
		track.update(d, d / tuning.run_speed)
		for chunk: Node in track.get_children():
			if seen.has(chunk):
				continue
			seen[chunk] = true
			for node: Node in nodes_of(chunk, func(n: Node) -> bool: return n is MeshInstance3D):
				var m := node as MeshInstance3D
				if m.mesh == null or m.is_in_group(&"debug_hitbox"):
					continue
				for s: int in m.mesh.get_surface_count():
					visit.call(m, m.mesh.surface_get_arrays(s), m.mesh.surface_get_material(s))
		d += TrackBuilder.CHUNK_LENGTH
	world.queue_free()
	await tree.process_frame


## The rectangles (MeshLayer.rect(), six vertices each) among a surface's vertices, in world space:
## for each, its corners o (UV's start), o + v and o + u, its UV at o and at the far corner, its
## colour and its pattern (UV2.x). Surfaces made only of rects (screens, marks) split exactly.
static func rects_of(m: MeshInstance3D, arrays: Array) -> Array[Dictionary]:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var uv2s: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var out: Array[Dictionary] = []
	for i: int in range(0, verts.size() - 5, 6):
		var o: Vector3 = m.global_transform * verts[i]
		var ov: Vector3 = m.global_transform * verts[i + 1]
		var ou: Vector3 = m.global_transform * verts[i + 5]
		out.append({"o": o, "ov": ov, "ou": ou, "center": (ov + ou) * 0.5, "uv0": uvs[i], "uv1": uvs[i + 2],
			"color": colors[i], "pattern": roundi(uv2s[i].x), "normal": (ou - o).cross(ov - o).normalized()})
	return out


## Whether `node` hangs under a hazard (a fence's or a sign's visuals).
static func under_hazard(node: Node) -> bool:
	var parent: Node = node.get_parent()
	while parent != null:
		if parent is Hazard:
			return true
		parent = parent.get_parent()
	return false


func free_track(track: TrackBuilder) -> void:
	track.get_parent().queue_free()
	await tree.process_frame


func nodes_of(root: Node, test: Callable) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if test.call(node):
			out.append(node)
		stack.append_array(node.get_children())
	return out


## Fences and signs: visuals cover the hitbox, gapped fences are open below, states switch
## materials; pads, ramps and speed pads are drawn.
func hazards_and_triggers(skin: ZoneSkin) -> void:
	var track: TrackBuilder = showcase_track(skin)
	var hazards: Array[Node] = nodes_of(track, func(n: Node) -> bool: return n is Hazard)
	check(hazards.size() == 4, "the test layout has 2 fences and 2 signs (%d hazards)" % hazards.size())
	for node: Node in hazards:
		var hazard := node as Hazard
		var hitbox: AABB = _hitbox(hazard)
		var visual: AABB = _visual_bounds(hazard)
		check(visual.grow(0.001).encloses(hitbox), "%s at %s: the visual (%s) covers the hitbox (%s)" % [
			hazard.hazard_name, hazard.position, visual, hitbox])
		if hazard.hazard_name.begins_with("fence (gapped"):
			var field: Array[MeshInstance3D] = visible_meshes(hazard)
			var world_bottom: float = hazard.position.y + (field[0].transform * field[0].get_aabb()).position.y
			check(world_bottom > 0.5, "a gapped fence's field is visibly open underneath (bottom at %.2f m)" % world_bottom)
		if hazard.hazard_name.contains("pulsing"):
			_pulsing_states(hazard)
	var triggers: Array[Node] = nodes_of(track, func(n: Node) -> bool: return n is Area3D and n.has_meta(&"kind"))
	check(triggers.size() == 3, "the test layout has a pad, a ramp and a speed pad (%d triggers)" % triggers.size())
	for trigger: Node in triggers:
		check(not visible_meshes(trigger).is_empty(), "the %s is drawn" % trigger.get_meta(&"kind"))
	await free_track(track)


func _pulsing_states(hazard: Hazard) -> void:
	var state_visual: HazardStateVisual = null
	for child: Node in hazard.get_children():
		if child is HazardStateVisual:
			state_visual = child
	check(state_visual != null, "a pulsing fence has a state visual")
	if state_visual == null:
		return
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
	for m: MeshInstance3D in visible_meshes(hazard):
		var box: AABB = m.transform * m.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out


## Variety comes from hashing track positions: rebuilding a level gives identical meshes.
func determinism(skin: ZoneSkin, level_path: String) -> void:
	var layout: LevelLayout = level(level_path, 5, 0.4, 7)
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

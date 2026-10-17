extends SceneTree
## Measures what the Marketplace's citizens cost to build (task L7): the same level built chunk by chunk with
## the citizens off and on (Settings.citizens_enabled), and the citizens' own build alone (MarketCitizens.build
## over the same walls), so the flipbook cards and the real people can be compared with the same tool on either
## version of the code. From the project folder (with XDG_DATA_HOME set as for the tests):
##   godot4 --headless -s res://tools/measure/market_people_cost.gd -- [options]
## Options:
##   --levels=marketplace_1,marketplace_2   level files in data/levels/ (default both)
##   --lanes=3,5,6                          lane counts (default 3,5,6)
##   --passes=5                             builds of each, alternating off and on; the fastest time of each chunk
##                                          step is kept, since another process's work only ever adds time
##   --skin=marketplace                     the skin (data/skins/<name>_skin.tres; casino reuses the citizens)
## Prints, per level and lane count: the mean and worst chunk build time without and with citizens, the
## citizens' own build time per chunk (a micro-benchmark over 40 m chunks of both walls), and what they add per
## chunk: nodes, MeshInstance3D and MultiMeshInstance3D nodes, mesh surfaces, vertices drawn (a MultiMesh's
## instances count each one's), and the draw calls those make when everything is in view. SkinSuite's tally
## counts MeshInstance3D surfaces only: a MultiMeshInstance3D shows there as nothing, so read this tool's lines
## for what the people draw.

const TUNING_PATH: String = "res://data/tuning/movement.tres"
const CHUNK: float = 40.0

var _levels: PackedStringArray = ["marketplace_1", "marketplace_2"]
var _lanes: Array[int] = [3, 5, 6]
var _passes: int = 5
var _skin_name: String = "marketplace"
var _tuning: MovementTuning


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var value: String = arg.get_slice("=", 1)
		if arg.begins_with("--levels="):
			_levels = value.split(",", false)
		elif arg.begins_with("--lanes="):
			_lanes.clear()
			for v: String in value.split(",", false):
				_lanes.append(int(v))
		elif arg.begins_with("--passes="):
			_passes = maxi(1, int(value))
		elif arg.begins_with("--skin="):
			_skin_name = value
	_tuning = load(TUNING_PATH) as MovementTuning
	var skin := load("res://data/skins/%s_skin.tres" % _skin_name) as ZoneSkin
	for level_name: String in _levels:
		for lanes: int in _lanes:
			await _measure(skin, level_name, lanes)
	quit(0)


func _layout(level_name: String, lanes: int) -> LevelLayout:
	var config := (load("res://data/levels/%s.tres" % level_name) as LevelConfig).duplicate() as LevelConfig
	config.lane_count = lanes
	config.difficulty = 0.6
	config.level_seed = 3
	return LayoutCache.generate(config, _tuning, LevelGenerator.load_patterns(config.patterns_path))


func _measure(skin: ZoneSkin, level_name: String, lanes: int) -> void:
	var layout: LevelLayout = _layout(level_name, lanes)
	var was: bool = Settings.citizens_enabled
	var off: Dictionary = {}
	var on: Dictionary = {}
	for p: int in _passes:
		# Alternate which goes first, so neither always pays a cold cache.
		var first: bool = p % 2 == 1
		for enabled: bool in [first, not first]:
			Settings.citizens_enabled = enabled
			var r: Dictionary = await _build(layout, skin)
			var into: Dictionary = on if enabled else off
			if into.is_empty():
				into.merge(r)
			else:
				var t: Array = into["times"]
				for i: int in mini(t.size(), (r["times"] as Array).size()):
					t[i] = minf(t[i], (r["times"] as Array)[i])
	Settings.citizens_enabled = true
	var alone: float = _citizens_alone(skin, lanes)
	Settings.citizens_enabled = was
	var chunks: int = int(on["chunks"])
	print("%s, %d lanes, %d chunks (best of %d passes)" % [level_name, lanes, chunks, _passes])
	print("  chunk build, citizens off: mean %.3f ms, worst %.3f ms" % [_mean(off["times"]), _worst(off["times"])])
	print("  chunk build, citizens on:  mean %.3f ms, worst %.3f ms  (%+.3f ms a chunk)" % [_mean(on["times"]),
		_worst(on["times"]), _mean(on["times"]) - _mean(off["times"])])
	print("  citizens' own build: %.3f ms a chunk (both walls, MarketCitizens.build alone)" % alone)
	for key: String in ["nodes", "mesh_nodes", "multimeshes", "surfaces", "instances", "vertices_drawn", "draws"]:
		print("  %-16s off %8.2f   on %8.2f   citizens add %+7.2f a chunk" % [key, float(off[key]) / chunks,
			float(on[key]) / chunks, (float(on[key]) - float(off[key])) / chunks])


## One whole build, chunk step by chunk step, with the tallies of what the chunks hold.
func _build(layout: LevelLayout, skin: ZoneSkin) -> Dictionary:
	var world := Node3D.new()
	root.add_child(world)
	var track := TrackBuilder.new()
	world.add_child(track)
	track.set_layout(layout, _tuning, skin)
	var stats := {"chunks": 0, "times": [], "nodes": 0, "mesh_nodes": 0, "multimeshes": 0, "surfaces": 0,
		"instances": 0, "vertices_drawn": 0, "draws": 0}
	var seen: Dictionary = {}
	var d: float = 0.0
	while d <= layout.length + TrackBuilder.RUN_OUT + TrackBuilder.CHUNK_LENGTH:
		var t0: int = Time.get_ticks_usec()
		track.update(d, d / _tuning.run_speed)
		var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
		var fresh: int = 0
		for chunk: Node in track.get_children():
			if not seen.has(chunk):
				seen[chunk] = true
				fresh += 1
				_tally(chunk, stats)
		if d > 0.0 and fresh > 0:
			stats["times"].append(ms / fresh)
		d += TrackBuilder.CHUNK_LENGTH
	stats["chunks"] = seen.size()
	world.queue_free()
	await process_frame
	return stats


func _tally(chunk: Node, stats: Dictionary) -> void:
	var stack: Array[Node] = [chunk]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stats["nodes"] += 1
		var mi := node as MeshInstance3D
		if mi != null and mi.mesh != null and mi.visible:
			stats["mesh_nodes"] += 1
			stats["surfaces"] += mi.mesh.get_surface_count()
			stats["draws"] += mi.mesh.get_surface_count()
			stats["vertices_drawn"] += _vertices(mi.mesh)
		var mm := node as MultiMeshInstance3D
		if mm != null and mm.multimesh != null and mm.visible and mm.multimesh.mesh != null:
			stats["multimeshes"] += 1
			stats["instances"] += mm.multimesh.visible_instance_count if mm.multimesh.visible_instance_count >= 0 \
				else mm.multimesh.instance_count
			stats["draws"] += mm.multimesh.mesh.get_surface_count()
			stats["vertices_drawn"] += _vertices(mm.multimesh.mesh) * (mm.multimesh.visible_instance_count \
				if mm.multimesh.visible_instance_count >= 0 else mm.multimesh.instance_count)
		stack.append_array(node.get_children())


static func _vertices(mesh: Mesh) -> int:
	var n: int = 0
	var am := mesh as ArrayMesh
	if am != null:
		for s: int in am.get_surface_count():
			n += am.surface_get_array_len(s)
	return n


## MarketCitizens.build over the walls of 60 chunks on both sides, timed apart from everything else the walls
## build (the fastest of a few repeats).
func _citizens_alone(skin: ZoneSkin, lanes: int) -> float:
	var market := skin as MarketplaceSkin
	if market == null:
		return -1.0
	var geo := TrackGeometry.new(lanes, _tuning)
	var best: float = INF
	for rep: int in 4:
		var parent := Node3D.new()
		root.add_child(parent)
		var t0: int = Time.get_ticks_usec()
		for k: int in 60:
			for side: int in [-1, 1]:
				market.citizens().build(parent, side, side * geo.wall_x(), k * CHUNK, (k + 1) * CHUNK)
		best = minf(best, float(Time.get_ticks_usec() - t0) / 1000.0 / 60.0)
		parent.free()
	return best


static func _mean(times: Array) -> float:
	var s: float = 0.0
	for t: float in times:
		s += t
	return s / maxf(1.0, float(times.size()))


static func _worst(times: Array) -> float:
	var w: float = 0.0
	for t: float in times:
		w = maxf(w, t)
	return w

extends SceneTree
## Measures what the zone doodads cost a run's track (task L6: the owner asked whether more doodads hurt
## performance). Each campaign level is generated at each lane count (its own seed) and built chunk by chunk with
## its zone's own skin, the way a run builds it (TrackBuilder.update a chunk at a time, as SkinSuite.build_all
## times it), then again with LevelConfig.doodad_share 0 (the same level without zone doodads). From the project
## folder (with XDG_DATA_HOME set as for the tests):
##   godot --headless -s res://tools/measure/doodad_cost.gd -- [options]
## Options:
##   --levels=golden/2,dead_zone/1   campaign steps (default: every level)
##   --lanes=3,5,6                   lane counts (default 3,5,6)
##   --passes=N                      builds per level whose per-chunk times are folded to their minimum
##                                   (default 3: a loaded machine's preemption left out, as the skin suites do)
## Per level and lane count, with and without the doodads: the zone doodads in the level; per chunk, the build
## time (mean and worst, milliseconds, the minimum over the passes), the mesh surfaces (each one draw call when
## it is on screen) and the collision objects; and over the run, the most the track holds at once (from
## TrackBuilder.KEEP_BEHIND behind the runner to BUILD_AHEAD ahead, what a run keeps built): doodads, collision
## objects (the player's queries and the physics broadphase see these) and mesh surfaces (what the renderer may
## draw). The headless build times are the CPU's (scripts and nodes), never the GPU's.

const CAMPAIGN_PATH: String = "res://data/campaign/campaign.tres"
const TUNING_PATH: String = "res://data/tuning/movement.tres"

var _levels: PackedStringArray = []
var _lanes: Array[int] = [3, 5, 6]
var _passes: int = 3


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var value: String = arg.get_slice("=", 1)
		if arg.begins_with("--levels="):
			_levels = value.split(",", false)
		elif arg.begins_with("--lanes="):
			_lanes.clear()
			for s: String in value.split(",", false):
				_lanes.append(int(s))
		elif arg.begins_with("--passes="):
			_passes = maxi(int(value), 1)
	var campaign := load(CAMPAIGN_PATH) as Campaign
	var tuning := load(TUNING_PATH) as MovementTuning
	if _levels.is_empty():
		for s: CampaignStep in campaign.steps():
			if s.is_level() and not s.is_minigame():
				_levels.append(s.id)
	print("%-14s %5s %7s | %5s | %13s %8s %8s | %26s" % ["level", "lanes", "doodads", "/min", "chunk ms mean/max",
		"surf/ch", "coll/ch", "at once: doodads/coll/surf"])
	var started: int = Time.get_ticks_msec()
	for id: String in _levels:
		var step: CampaignStep = campaign.step(id)
		if step == null or not step.is_level() or step.is_minigame():
			continue
		for lanes: int in _lanes:
			for with_doodads: bool in [true, false]:
				var config: LevelConfig = campaign.configure(step, lanes)
				if not with_doodads:
					config.doodad_share = 0.0
				var gen := LevelGenerator.new()
				var layout: LevelLayout = gen.generate(config, tuning, LevelGenerator.load_for(config))
				var movement: MovementTuning = config.movement_for(tuning)
				var skin: ZoneSkin = config.skin if config.skin != null else GreyboxSkin.new()
				var stats: Dictionary = {}
				for p: int in _passes:
					var one: Dictionary = await _build(layout, movement, skin)
					if p == 0:
						stats = one
					else:
						for i: int in mini((stats["times"] as Array).size(), (one["times"] as Array).size()):
							stats["times"][i] = minf(float(stats["times"][i]), float(one["times"][i]))
				var zone: int = 0
				for d: Dictionary in layout.doodads:
					zone += 0 if d.has("stash") else 1
				var minutes: float = (layout.length - config.end_clear_distance - config.start_clear_distance) \
					/ movement.run_speed / 60.0
				var times: Array = stats["times"]
				var mean: float = 0.0
				var worst: float = 0.0
				for t: float in times:
					mean += t / maxf(times.size(), 1.0)
					worst = maxf(worst, t)
				var chunks: float = maxf(float(stats["chunks"]), 1.0)
				print("%-14s %5d %7s | %5.1f | %6.2f/%6.2f %8.1f %8.1f | %8d/%5d/%5d%s" % [id, lanes,
					str(zone) if with_doodads else "(none)", zone / maxf(minutes, 0.01), mean, worst,
					float(stats["surfaces"]) / chunks, float(stats["collision"]) / chunks, int(stats["most_doodads"]),
					int(stats["most_collision"]), int(stats["most_surfaces"]), "" if with_doodads else "  (doodad_share 0)"])
	print("measured in %.0f s" % ((Time.get_ticks_msec() - started) / 1000.0))
	quit(0)


## One build of `layout` with `skin`, chunk by chunk as a run builds it: {chunks, times (ms per new chunk, as
## SkinSuite._build_once times the steady state), surfaces and collision (summed over every chunk built), and
## the most doodads, collision objects and mesh surfaces the track held at once}.
func _build(layout: LevelLayout, movement: MovementTuning, skin: ZoneSkin) -> Dictionary:
	var world := Node3D.new()
	root.add_child(world)
	var track := TrackBuilder.new()
	world.add_child(track)
	track.set_layout(layout, movement, skin)
	var out := {"chunks": 0, "times": [], "surfaces": 0, "collision": 0, "most_doodads": 0, "most_collision": 0,
		"most_surfaces": 0}
	var seen: Dictionary = {}
	var d: float = 0.0
	while d <= layout.length + TrackBuilder.RUN_OUT + TrackBuilder.CHUNK_LENGTH:
		var t0: int = Time.get_ticks_usec()
		track.update(d, d / movement.run_speed)
		var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
		var fresh: int = 0
		var live := {"doodads": 0, "collision": 0, "surfaces": 0}
		for chunk: Node in track.get_children():
			# A chunk the track let go of this step is freed at the frame's end: no longer the run's.
			if chunk.is_queued_for_deletion():
				continue
			var tally: Dictionary = _tally(chunk)
			for k: String in live:
				live[k] += int(tally[k])
			if not seen.has(chunk):
				seen[chunk] = true
				fresh += 1
				out["surfaces"] += int(tally["surfaces"])
				out["collision"] += int(tally["collision"])
		if d > 0.0 and fresh > 0:
			(out["times"] as Array).append(ms / fresh)
		out["most_doodads"] = maxi(int(out["most_doodads"]), int(live["doodads"]))
		out["most_collision"] = maxi(int(out["most_collision"]), int(live["collision"]))
		out["most_surfaces"] = maxi(int(out["most_surfaces"]), int(live["surfaces"]))
		d += TrackBuilder.CHUNK_LENGTH
	out["chunks"] = seen.size()
	world.queue_free()
	await process_frame
	return out


## What `node` holds: zone doodads standing (a DashBreakable of kind doodad), collision objects, and the surfaces
## of its visible meshes.
func _tally(node: Node) -> Dictionary:
	var out := {"doodads": 0, "collision": 0, "surfaces": 0}
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is DashBreakable and (n as DashBreakable).kind == &"doodad":
			out["doodads"] += 1
		if n is CollisionObject3D:
			out["collision"] += 1
		var mesh_node := n as MeshInstance3D
		if mesh_node != null and mesh_node.visible and mesh_node.mesh != null:
			out["surfaces"] += mesh_node.mesh.get_surface_count()
		stack.append_array(n.get_children())
	return out

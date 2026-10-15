extends SceneTree
## Measures what a hover truck costs a run (task I5, the owner's "big performance drop on a playtester's
## phone", October 14, 2026): plays a quick-play run with the hover truck's feature (so the level readies
## it as a real one does), spawns trucks at set times and frames each phase of their visit apart: away,
## hidden, banging, the burst, pacing, the cannon, the lurches, the wreck. From the project folder (with
## XDG_DATA_HOME set as for the tests), on the renderer to judge (a phone's is the Compatibility one):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot4 --path . --resolution 640x360 --fixed-fps 60 \
##     --rendering-method gl_compatibility -s res://tools/measure/truck_cost.gd -- [options]
## Options:
##   --skin=gangland     the zone skin (data/skins/<name>_skin.tres; default gangland, the scavenger look; city
##                       is the sleek one)
##   --lanes=5           the lane count
##   --trucks=3          trucks spawned, one after another (default 3)
##   --gap=12            seconds between a truck's wreck (or leaving) and the next one's spawn
##   --stay=9            how long each truck stays (the `stay` spawn param; GDD 20-30 s, shortened to keep runs short)
##   --kill=5            seconds after a truck first paces that it is defeated (the spin-out and explosion);
##                       0 lets it leave instead
##   --probe-lights      while a truck is out, alternate every PROBE_FRAMES frames between every OmniLight3D shown
##                       and hidden, and compare the two (what the lights cost, in this renderer)
##   --pre-burst         two spark bursts (frames 40 and 100) before any truck, to see what the run's first
##                       burst costs on its own
##   --trace             print each change of a truck's phase with the tick it came on (to find frames in a movie:
##                       --write-movie at --fixed-fps F captures one frame every 60 / F ticks)
##   --bench             also time the truck's own script work: each truck's spawn (the first is the one that builds
##                       its model unless the level readied it), and its per-frame _tick (delta 0, so it decides
##                       nothing) while it waits hidden, bangs and paces, in microseconds a call
##   --out=build/i5/x.json   write every frame's numbers there
## Each frame's whole time (what the player sees), the game's part of it before the renderer draws (scripts,
## physics, building nodes) and the rest (the renderer: drawing, and compiling a shader the first time it is
## drawn, which is what a Compatibility renderer does mid-run) come from a FrameMonitor. A real renderer in
## software (xvfb) shows the shape of the time, not a phone's: the counts mean the same on any renderer
## (draw calls, objects, primitives, nodes, lights), and a frame that compiled shaders stands out by hundreds
## of milliseconds. Set MESA_SHADER_CACHE_DISABLE=true so the driver's own disk cache doesn't hide the compiles.
## Output: one row per phase (frames, median and worst frame ms, the game's median ms, median draw calls,
## objects, nodes and lights in the tree, and the pipelines a Forward+ or Mobile renderer built in it: 0 on
## Compatibility, which compiles shaders without counting them), the slowest frames with their phase and tags, and each truck's
## cost over the frames before it came.

const MONITOR_SCRIPT: String = "res://scripts/run/frame_monitor.gd"
## Frames per half of the --probe-lights comparison.
const PROBE_FRAMES: int = 90
## Slowest frames listed.
const WORST_LISTED: int = 12
## Frames to play before the first truck is spawned (the run settles, the load's last draws are done).
const SETTLE_FRAMES: int = 90
const AWAY: String = "away"


## Stands in for scenes/main.tscn: the App plays runs under its world root.
class ToolMain extends Node:
	var world_root: Node3D
	var ui_root: CanvasLayer
	var overlay_root: CanvasLayer

	func _init() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		world_root = Node3D.new()
		world_root.name = "World"
		world_root.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(world_root)
		ui_root = CanvasLayer.new()
		ui_root.layer = 10
		add_child(ui_root)
		overlay_root = CanvasLayer.new()
		overlay_root.layer = 20
		add_child(overlay_root)


var _skin: String = "gangland"
var _lanes: int = 5
var _trucks: int = 3
var _gap: float = 12.0
var _stay: float = 9.0
var _kill: float = 5.0
var _probe_lights: bool = false
var _pre_burst: bool = false
var _no_light: bool = false
var _bench: bool = false
var _trace: bool = false
var _last_phase: String = ""
var _spawn_ms: PackedFloat32Array = PackedFloat32Array()
var _benched: Dictionary = {}
var _bench_lines: PackedStringArray = PackedStringArray()
var _out: String = ""

var _app: Node
var _monitor: Node
var _run: Node
var _world: Node
var _player: Node
var _rng := RandomNumberGenerator.new()
var _frame: int = 0
var _spawned: int = 0
var _next_spawn_frame: int = SETTLE_FRAMES
var _truck: Node
var _states: Dictionary = {}
var _paced_frames: int = 0
var _done: bool = false
## Per frame: the phase, draw calls, primitives, objects, nodes, lights shown, lights probed on.
var _phases := PackedStringArray()
var _draws := PackedInt32Array()
var _primitives := PackedInt32Array()
var _objects := PackedInt32Array()
var _nodes := PackedInt32Array()
var _lights := PackedInt32Array()
var _probe_on := PackedByteArray()
var _pipelines := PackedInt32Array()
var _compiles_seen: int = 0
var _truck_no := PackedInt32Array()
var _rendering: bool = false


func _initialize() -> void:
	_run_all.call_deferred()


func _run_all() -> void:
	_parse_args()
	_rendering = DisplayServer.get_name() != "headless"
	_app = root.get_node(^"App")
	_app.set(&"autosave", false)
	_app.set(&"save_path", "user://measure_profile.json")
	var main := ToolMain.new()
	root.add_child(main)
	_app.set(&"main", main)
	_monitor = (load(MONITOR_SCRIPT) as GDScript).new() as Node
	_monitor.set(&"keep_all", true)
	root.add_child(_monitor)
	_app.set(&"profile", Profile.new())
	var args := PackedStringArray(["--god", "--nofall", "--lanes=%d" % _lanes, "--seed=4", "--difficulty=0.6",
		"--skin=" + _skin, "--features=hover_truck"])
	var t0: int = Time.get_ticks_usec()
	_app.call(&"start_quick", args)
	if _app.has_method(&"begin_run"):
		_app.call(&"begin_run")
	var load_ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	_run = _app.get(&"run")
	if _run == null:
		print("The App started no run")
		quit(1)
		return
	_world = _run.get(&"world")
	_player = _world.get(&"player")
	_monitor.call(&"watch", _world)
	_rng.seed = 7919 + _lanes
	await physics_frame
	_monitor.call(&"clear")
	print("I5 hover truck cost: %d lanes, skin %s, %d trucks, %s, Godot %s, load %.0f ms" % [_lanes, _skin, _trucks,
		RenderingServer.get_current_rendering_method() if _rendering else "headless",
		Engine.get_version_info()["string"], load_ms])
	while not _done:
		await physics_frame
	_report()
	_app.call(&"_end_run")
	await process_frame
	quit(0)


func _parse_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var value: String = arg.get_slice("=", 1)
		if arg.begins_with("--skin="):
			_skin = value
		elif arg.begins_with("--lanes="):
			_lanes = int(value)
		elif arg.begins_with("--trucks="):
			_trucks = maxi(int(value), 1)
		elif arg.begins_with("--gap="):
			_gap = float(value)
		elif arg.begins_with("--stay="):
			_stay = float(value)
		elif arg.begins_with("--kill="):
			_kill = float(value)
		elif arg == "--probe-lights":
			_probe_lights = true
		elif arg == "--pre-burst":
			_pre_burst = true
		elif arg == "--no-light":
			_no_light = true
		elif arg == "--bench":
			_bench = true
		elif arg == "--trace":
			_trace = true
		elif arg.begins_with("--out="):
			_out = value


## Every physics frame, before the player moves: the scripted runner, the truck spawns, the kill, and the
## frame's numbers. Its own time is left out of the frame (FrameMonitor.discount).
func _physics_process(_delta: float) -> bool:
	if _done or _run == null or not is_instance_valid(_run) or _world == null or not is_instance_valid(_world):
		return false
	var t0: int = Time.get_ticks_usec()
	_frame += 1
	if bool(_player.get(&"running")) and bool(_player.get(&"alive")) and _frame % 50 == 0:
		_move()
	if _pre_burst and (_frame == 40 or _frame == 100):
		var at: Vector3 = (_player.get(&"global_position") as Vector3) + Vector3(0.0, 1.5, -8.0)
		(_world.get(&"effects") as Object).call(&"burst", at, Color(1.0, 0.62, 0.2) if _frame == 40 else Color(0.3, 0.9, 0.5), 24, 0.8)
	_step_trucks()
	_record()
	_monitor.call(&"discount", Time.get_ticks_usec() - t0)
	return false


## One move of the scripted runner: lane switches and jumps, nothing that ends the run (god mode).
func _move() -> void:
	var lanes: int = int((_world.get(&"geo") as Object).get(&"lane_count"))
	var lane: int = int(_player.get(&"lane"))
	var roll: float = _rng.randf()
	if roll < 0.6:
		var dir: int = -1 if _rng.randf() < 0.5 else 1
		if lane + dir < 0 or lane + dir >= lanes:
			dir = -dir
		_player.call(&"press", &"move_left" if dir < 0 else &"move_right")
	elif roll < 0.9:
		_player.call(&"press", &"jump")
	else:
		_player.call(&"press", &"slide")


## Spawns the next truck when it is time, and defeats the current one `--kill` seconds after it first paces.
func _step_trucks() -> void:
	if _truck != null and not is_instance_valid(_truck):
		_truck = null
		_next_spawn_frame = _frame + int(_gap * 60.0)
	if _truck == null:
		if _spawned >= _trucks:
			if _frame >= _next_spawn_frame:
				_done = true
			return
		if _frame >= _next_spawn_frame:
			_spawn_truck()
		return
	if _states.is_empty():
		_states = _state_names(_truck)
	if _bench:
		_bench_truck()
	if _kill > 0.0 and String(_states.get(int(_truck.get(&"state")), "")) in ["PACE", "ALONGSIDE", "HOLD_BACK", "LURCH_BACK"]:
		_paced_frames += 1
		if _paced_frames >= int(_kill * 60.0) and bool(_truck.get(&"alive")):
			_truck.call(&"defeat", &"weapon")


## Times the truck's _tick (delta 0: it decides nothing and nothing moves) 300 times the first frame it is in each of
## HIDDEN, BANGING and PACE.
func _bench_truck() -> void:
	var phase: String = _phase()
	if not phase in ["HIDDEN", "BANGING", "PACE"] or _benched.has("%d %s" % [_spawned, phase]):
		return
	_benched["%d %s" % [_spawned, phase]] = true
	var t0: int = Time.get_ticks_usec()
	for i: int in 300:
		_truck.call(&"_tick", 0.0)
	_bench_lines.append("  truck %d _tick while %-7s %6.1f us a call" % [_spawned, phase, (Time.get_ticks_usec() - t0) / 300.0])


func _spawn_truck() -> void:
	var director: Object = _world.get(&"director")
	var geo: Object = _world.get(&"geo")
	var layout: Object = _world.get(&"layout")
	var side: int = 1 if _spawned % 2 == 0 else -1
	var speed: float = maxf(float(_player.get(&"speed")), 10.0)
	var at: float = float(_player.get(&"distance")) + speed * 6.0
	var t0: int = Time.get_ticks_usec()
	_truck = director.call(&"spawn", {"type": "hover_truck", "at": at, "lane": layout.call(&"outer_lane", side),
		"side": side, "seed": 5 + _spawned, "params": {"stay": _stay}}) as Node
	_spawn_ms.append((Time.get_ticks_usec() - t0) / 1000.0)
	_spawned += 1
	if _no_light and _truck != null:
		for l: Node in _truck.find_children("*", "OmniLight3D", true, false):
			l.free()
	_paced_frames = 0
	_states = {}
	if geo == null or _truck == null:
		print("Could not spawn a truck")
		_done = true


## The truck script's State enum, by value.
static func _state_names(truck: Node) -> Dictionary:
	var out: Dictionary = {}
	var states: Variant = (truck.get_script() as GDScript).get_script_constant_map().get("State")
	if states is Dictionary:
		for k: Variant in states:
			out[int((states as Dictionary)[k])] = String(k)
	return out


func _phase() -> String:
	if _truck == null or not is_instance_valid(_truck):
		return AWAY
	if _states.is_empty():
		_states = _state_names(_truck)
	return String(_states.get(int(_truck.get(&"state")), "?"))


func _record() -> void:
	_phases.append(_phase())
	if _trace and _phases[-1] != _last_phase:
		_last_phase = _phases[-1]
		print("tick %d: %s" % [_frame, _last_phase])
	_truck_no.append(_spawned if _truck != null else 0)
	if _rendering:
		_draws.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		_primitives.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
		_objects.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
	else:
		_draws.append(0)
		_primitives.append(0)
		_objects.append(0)
	_nodes.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	var compiled: int = 0
	for info: int in [RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS, RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH,
			RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE, RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW,
			RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION]:
		compiled += RenderingServer.get_rendering_info(info)
	_pipelines.append(compiled - _compiles_seen)
	_compiles_seen = compiled
	var lights: Array[Node] = _run.find_children("*", "OmniLight3D", true, false)
	var shown: int = 0
	var probed: int = 1
	if _probe_lights and _phase() != AWAY and _phase() != "HIDDEN":
		probed = int(_frame / PROBE_FRAMES) % 2
		for l: Node in lights:
			(l as Light3D).visible = probed == 1
	for l: Node in lights:
		if (l as Light3D).is_visible_in_tree():
			shown += 1
	_lights.append(shown)
	_probe_on.append(probed)


func _report() -> void:
	var totals: PackedInt32Array = _monitor.get(&"totals")
	var logics: PackedInt32Array = _monitor.get(&"logics")
	var tags: Array = _monitor.get(&"tags")
	var n: int = mini(totals.size(), _phases.size())
	var monitor_class: GDScript = load(MONITOR_SCRIPT) as GDScript
	var by_phase: Dictionary = {}
	for i: int in n:
		var key: String = _phases[i]
		if not by_phase.has(key):
			by_phase[key] = []
		(by_phase[key] as Array).append(i)
	var order: Array[String] = [AWAY, "HIDDEN", "BANGING", "EMERGE", "PACE", "LURCH_BACK", "HOLD_BACK", "REV", "LURCH_FWD",
		"ALONGSIDE", "RIDDEN", "LEAVING", "WRECKED"]
	for k: Variant in by_phase:
		if not order.has(String(k)):
			order.append(String(k))
	print("phase         frames | frame ms: median   p95  worst | game ms | draws prims  objects nodes lights pipelines")
	for key: String in order:
		if not by_phase.has(key):
			continue
		var idx: Array = by_phase[key]
		print(_row(key, idx, totals, logics, monitor_class))
	if _probe_lights:
		for on: int in [0, 1]:
			var idx: Array = []
			for i: int in n:
				if _phases[i] != AWAY and _phases[i] != "HIDDEN" and int(_probe_on[i]) == on and _frames_since_light_flip(i) > 3:
					idx.append(i)
			if not idx.is_empty():
				print(_row("lights " + ("on" if on == 1 else "off"), idx, totals, logics, monitor_class))
	# Each truck's visit against the frames before it came.
	for k: int in range(1, _spawned + 1):
		var idx: Array = []
		for i: int in n:
			if _truck_no[i] == k:
				idx.append(i)
		if not idx.is_empty():
			print(_row("truck %d visit" % k, idx, totals, logics, monitor_class))
	if _bench:
		var spawns: PackedStringArray = []
		for ms: float in _spawn_ms:
			spawns.append("%.1f" % ms)
		print("bench: spawning the trucks took (ms) %s" % ", ".join(spawns))
		for line: String in _bench_lines:
			print(line)
	var slow: Array[int] = []
	for i: int in n:
		slow.append(i)
	slow.sort_custom(func(a: int, b: int) -> bool: return totals[a] > totals[b])
	print("slowest frames (frame, ms, game ms, phase, tags):")
	for i: int in mini(WORST_LISTED, slow.size()):
		var f: int = slow[i]
		print("  %5d  %8.1f  %7.1f  %-10s %s" % [f, totals[f] / 1000.0, logics[f] / 1000.0, _phases[f], " ".join(tags[f])])
	if _out != "":
		var rows: Array = []
		for i: int in n:
			rows.append({"phase": _phases[i], "truck": _truck_no[i], "total_us": totals[i], "game_us": logics[i],
				"draws": _draws[i], "primitives": _primitives[i], "objects": _objects[i], "nodes": _nodes[i],
				"lights": _lights[i], "tags": Array(tags[i])})
		var path: String = ProjectSettings.globalize_path("res://" + _out) if not _out.begins_with("/") else _out
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(JSON.stringify(rows))
		f.close()
		print("Wrote %s" % path)


func _frames_since_light_flip(i: int) -> int:
	return i % PROBE_FRAMES


func _row(label: String, idx: Array, totals: PackedInt32Array, logics: PackedInt32Array, monitor_class: GDScript) -> String:
	var ms := PackedFloat32Array()
	var game := PackedFloat32Array()
	var draws := PackedFloat32Array()
	var prims := PackedFloat32Array()
	var objs := PackedFloat32Array()
	var nodes := PackedFloat32Array()
	var lights := PackedFloat32Array()
	for i: Variant in idx:
		var f: int = int(i)
		ms.append(totals[f] / 1000.0)
		game.append(logics[f] / 1000.0)
		draws.append(_draws[f])
		prims.append(_primitives[f])
		objs.append(_objects[f])
		nodes.append(_nodes[f])
		lights.append(_lights[f])
	var s: Dictionary = monitor_class.call(&"summarize", ms)
	var g: Dictionary = monitor_class.call(&"summarize", game)
	var pipelines: int = 0
	for i: Variant in idx:
		pipelines += _pipelines[int(i)]
	return "%-13s %6d | %8.1f %7.1f %7.1f | %6.2f | %5d %6d %6d %5d %4d %8d" % [label, idx.size(), float(s["median"]),
		float(s["p95"]), float(s["worst"]), float(g["median"]), int(_median(draws)), int(_median(prims)),
		int(_median(objs)), int(_median(nodes)), int(_median(lights)), pipelines]


static func _median(values: PackedFloat32Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array = Array(values)
	sorted.sort()
	return float(sorted[sorted.size() / 2])

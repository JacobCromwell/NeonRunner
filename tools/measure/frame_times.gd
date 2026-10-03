extends SceneTree
## Measures the game's frame times (task PERF1, the owner's "lag spikes are more common", October 2,
## 2026): plays campaign levels and built boss fights through the App as the game does (the run, its
## camera, HUD, speed lines and hints), with a scripted runner in god mode that never falls, at the
## real zone speed, and times every frame with a FrameMonitor (scripts/run/frame_monitor.gd: what
## a frame is, and its tags). From the project folder (with XDG_DATA_HOME set as for the tests):
##   godot --headless --fixed-fps 60 -s res://tools/measure/frame_times.gd -- [options]
## Options:
##   --levels=city/1,gangland/2    campaign levels (default: every level); --levels= for none
##   --bosses=city_boss            zone bosses (default: every built one, and every one still being built
##                                 that has a preview scene, played as --boss= plays it); --bosses= for none
##   --lanes=5                     the lane count (default: a PC's, GameRules.lanes_pc)
##   --loadout=full|none           what the runner brings (default full: its weapon fires and kills as a
##                                 stocked-up player's does, so kills and their hit-stops happen)
##   --seconds=N                   stop each run after N s of play (default: a level's finish; a boss
##                                 fight's end, or BOSS_SECONDS)
##   --passes=N                    play each run N times, each in a fresh Godot process, and keep each
##                                 frame's fastest time (default 2): a seeded run plays the same frames
##                                 every time, so the minimum strips out moments another process took the
##                                 CPU, while each pass still pays what the first time costs (a session
##                                 starting at that level)
##   --session                     play every run in this one process instead, in order, as a player's
##                                 session would: what an earlier run built first (an enemy type's
##                                 model, a material) is already there for the later ones
##   --log                         keep each run's event log (the enemies' states as AttackWatch logs
##                                 them, every kill, the runner's place every second) and print its hash:
##                                 two builds that decide the same print the same hash
##   --frames                      print every slow frame (over SPIKE_MS) with its tags
##   --shaders                     look at the materials on screen every SHADER_SCAN_FRAMES frames (its
##                                 own time left out of the frames) and list the shaders first drawn
##                                 after the level's load, with what drew them (always on under xvfb)
##   --out=build/measure/x.json    write every run's numbers, frame times and tags there
##   --reference                   also time a reference build every REFERENCE_EVERY frames (SkinSuite's:
##                                 a REFERENCE_LANES-lane grey-box chunk, far off to one side, its time left
##                                 out of the frames), whose times tell how loaded the machine is
##                                 (SkinSuite.load_factor; test_frame_times)
## The headless run uses the dummy renderer: times are the CPU's (scripts, physics, building and freeing
## nodes), never the GPU's. Under xvfb (a real renderer, in software) the times mean nothing, but each run
## also counts what the renderer draws: draw calls, primitives and objects a frame, the render pipelines
## compiled during the run, and the materials and shaders on screen (README.md, Performance):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --resolution 960x540 --fixed-fps 60 \
##     [--rendering-method gl_compatibility] -s res://tools/measure/frame_times.gd -- --session --seconds=30
##
## Each run prints its frame times (median, 95th and 99th percentile, worst, frames over 8 and 16 ms),
## the level's load (generating it and building the world, before its first frame), its kills and
## hit-stops (how many began, frames the camera was held, the longest hold and holds that ran into the
## next), and the causes of its spikes: the tags of the frames over SPIKE_MS, by how much time they took
## over the run's median, then by count. A spike without tags ("-") is most often another process taking
## the CPU; a second pass tells them apart.
##
## The runner: the level's own seed picks a move every 0.5 to 1.25 s (a lane switch, now and then onto a
## wall, a jump or a slide), through the player's named actions; a boss fight is played by its test bot
## (FloatingHeadBot, SleepTakerBot, SewerSwarmBot) when one exists, in god mode too.

const SPIKE_MS: float = 4.0
## A boss fight that never ends (no bot for it) stops after this long.
const BOSS_SECONDS: float = 240.0
const BOTS: Dictionary = {"city_boss": "res://tests/helpers/floating_head_bot.gd",
	"dead_zone_boss": "res://tests/helpers/sleep_taker_bot.gd", "gangland_boss": "res://tests/helpers/sewer_swarm_bot.gd"}
const MONITOR_SCRIPT: String = "res://scripts/run/frame_monitor.gd"
const ATTACK_WATCH: String = "res://tools/measure/attack_watch.gd"
## Where a pass in its own process leaves its numbers for this one.
const PASS_DIR: String = "res://build/measure/passes"
## Frames between two looks at the materials on screen (--shaders, and under xvfb).
const SHADER_SCAN_FRAMES: int = 20
## Frames between two reference builds (--reference).
const REFERENCE_EVERY: int = 60
## Where the reference track is built: far from the run, so nothing in it ever meets the run's.
const REFERENCE_AT := Vector3(100000.0, -100000.0, 0.0)


## Stands in for scenes/main.tscn: the App plays runs under its world root (App.boot is left out, so the
## command line here never starts a run of its own).
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


var _levels: PackedStringArray = []
var _bosses: PackedStringArray = []
var _levels_given: bool = false
var _bosses_given: bool = false
var _lanes: int = 0
var _full_loadout: bool = true
var _limit: float = INF
var _passes: int = 2
var _session: bool = false
var _log: bool = false
var _print_frames: bool = false
var _shaders_scan: bool = false
var _reference: bool = false
var _out: String = ""
## A pass in its own process: the run to play and where to write it.
var _child: String = ""
var _child_out: String = ""

var _app: Node
var _monitor: Node
## The run being driven, its runner's moves and its event log.
var _run: Node
var _bot: Object
var _watch: RefCounted
var _rng := RandomNumberGenerator.new()
var _frame: int = 0
var _next_move: int = 0
var _events := PackedStringArray()
var _rendering: bool = false
var _draws := PackedInt32Array()
var _primitives := PackedInt32Array()
var _objects := PackedInt32Array()
var _materials: Dictionary = {}
var _shaders: Dictionary = {}
var _peak_materials: int = 0
var _peak_shaders: int = 0
## Shaders first drawn after the level's load: {frame, shader, node}.
var _firsts: Array[Dictionary] = []
## The reference build (--reference): its track, how far it's built, and each chunk's build time (ms).
var _ref_world: Node3D
var _ref_track: TrackBuilder
var _ref_d: float = 0.0
var _ref_times := PackedFloat32Array()


func _initialize() -> void:
	_run_all.call_deferred()


func _run_all() -> void:
	_parse_args()
	_rendering = DisplayServer.get_name() != "headless"
	if _child != "":
		await _run_child()
		return
	var campaign: Object = root.get_node(^"App").get(&"campaign")
	if _lanes <= 0:
		_lanes = int((root.get_node(^"App").get(&"rules") as Object).get(&"lanes_pc"))
	if not _levels_given:
		for s: Object in campaign.call(&"steps"):
			if bool(s.call(&"is_level")):
				_levels.append(String(s.get(&"id")))
	if not _bosses_given:
		for s: Object in campaign.call(&"steps"):
			var def: Object = s.get(&"boss")
			if def != null and (bool(def.call(&"is_built")) or (def.has_method(&"preview") and def.call(&"preview") != null)):
				_bosses.append(String(def.get(&"id")))
	var ids: Array[String] = []
	for id: String in _levels:
		ids.append("level:" + id)
	for id: String in _bosses:
		ids.append("boss:" + id)
	print("PERF1 frame times: %d lanes, %s loadout, %s, %s, Godot %s, %s" % [_lanes,
		"full" if _full_loadout else "no", "one session" if _session else "%d fresh pass(es) a run" % _passes,
		OS.get_processor_name(), Engine.get_version_info()["string"],
		RenderingServer.get_current_rendering_method() if _rendering else "headless"])
	print("run              speed   secs frames load ms | median  p95   p99  worst  >8ms >16ms | kills stops held long chain"
		+ " | causes of spikes over %.0f ms (ms over the median, count)" % SPIKE_MS)
	if _session:
		_start_app()
	var runs: Array[Dictionary] = []
	for key: String in ids:
		var best: Dictionary = {}
		if _session:
			best = await _measure(campaign, key)
		else:
			for p: int in _passes:
				var r: Dictionary = _pass_in_process(key, p)
				if r.is_empty():
					break
				best = r if best.is_empty() else _fold(best, r)
		if best.is_empty():
			continue
		_finish(best)
		runs.append(best)
		print(_line(best))
		if _rendering:
			print(_render_line(best))
		if best.has("shader_firsts"):
			print(_shaders_line(best))
		if _print_frames:
			_print_slow_frames(best)
	_print_totals(runs)
	if _out != "":
		_write(_out, runs)
		print("Wrote %s" % _out)
	if _session:
		root.get_node(^"App").call(&"_end_run")
		await process_frame
	quit(0)


func _parse_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var value: String = arg.get_slice("=", 1)
		if arg.begins_with("--levels="):
			_levels = value.split(",", false)
			_levels_given = true
		elif arg.begins_with("--bosses="):
			_bosses = value.split(",", false)
			_bosses_given = true
		elif arg.begins_with("--lanes="):
			_lanes = int(value)
		elif arg.begins_with("--loadout="):
			_full_loadout = value != "none"
		elif arg.begins_with("--seconds="):
			_limit = float(value)
		elif arg.begins_with("--passes="):
			_passes = maxi(int(value), 1)
		elif arg == "--session":
			_session = true
		elif arg == "--log":
			_log = true
		elif arg == "--frames":
			_print_frames = true
		elif arg == "--shaders":
			_shaders_scan = true
		elif arg == "--reference":
			_reference = true
		elif arg.begins_with("--out="):
			_out = value
		elif arg.begins_with("--child="):
			_child = value
		elif arg.begins_with("--child-out="):
			_child_out = value


## The App, without its own boot, ready to play runs under a stand-in for the main scene.
func _start_app() -> void:
	_app = root.get_node(^"App")
	_app.set(&"autosave", false)
	_app.set(&"save_path", "user://measure_profile.json")
	var main := ToolMain.new()
	root.add_child(main)
	_app.set(&"main", main)
	_monitor = (load(MONITOR_SCRIPT) as GDScript).new() as Node
	_monitor.set(&"keep_all", true)
	root.add_child(_monitor)


## A pass in its own process (--child): plays the one run and writes it for the process that asked.
func _run_child() -> void:
	_start_app()
	var r: Dictionary = await _measure(_app.get(&"campaign"), _child)
	_write(_child_out, [r] if not r.is_empty() else [])
	_app.call(&"_end_run")
	await process_frame
	quit(0)


## Plays `key` in a fresh Godot process (the same options, headless) and reads back what it measured.
func _pass_in_process(key: String, index: int) -> Dictionary:
	var file: String = "%s/%s_%d.json" % [PASS_DIR, key.replace(":", "_").replace("/", "_"), index]
	var args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--fixed-fps", "60", "-s", "res://tools/measure/frame_times.gd", "--", "--child=" + key,
		"--child-out=" + file, "--lanes=%d" % _lanes, "--loadout=" + ("full" if _full_loadout else "none")])
	if _limit < INF:
		args.append("--seconds=%f" % _limit)
	if _log:
		args.append("--log")
	if _shaders_scan:
		args.append("--shaders")
	if _reference:
		args.append("--reference")
	var output: Array = []
	OS.execute(OS.get_executable_path(), args, output, true)
	var path: String = ProjectSettings.globalize_path(file)
	if not FileAccess.file_exists(path):
		print("%s: its pass wrote nothing:\n%s" % [key, "\n".join(output)])
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	DirAccess.remove_absolute(path)
	if not parsed is Array or (parsed as Array).is_empty():
		print("%s: its pass measured nothing:\n%s" % [key, "\n".join(output)])
		return {}
	return _from_json(parsed[0])


## A run read back from JSON: its frame lists as packed arrays again.
static func _from_json(d: Dictionary) -> Dictionary:
	var totals := PackedInt32Array()
	var physics := PackedInt32Array()
	var frozen := PackedInt32Array()
	for v: Variant in d["totals"]:
		totals.append(int(v))
	for v: Variant in d["physics"]:
		physics.append(int(v))
	for v: Variant in d["frozen"]:
		frozen.append(int(v))
	var tags: Array = []
	for list: Variant in d["tags"]:
		tags.append(PackedStringArray(list))
	d["totals"] = totals
	d["physics"] = physics
	d["frozen"] = frozen
	d["tags"] = tags
	return d


func _write(file: String, runs: Array) -> void:
	var path: String = file if file.begins_with("/") else ProjectSettings.globalize_path(
		file if file.begins_with("res://") else "res://" + file)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(runs))
	f.close()


## One run of a campaign level ("level:<step id>") or a boss fight ("boss:<boss id>"), played through the
## App to its end (or the time limit). Empty if there's no such step.
func _measure(campaign: Object, key: String) -> Dictionary:
	var is_boss: bool = key.begins_with("boss:")
	var id: String = key.get_slice(":", 1)
	var step: Object = null
	for s: Object in campaign.call(&"steps"):
		if is_boss and s.get(&"boss") != null and String((s.get(&"boss") as Object).get(&"id")) == id:
			step = s
		elif not is_boss and String(s.get(&"id")) == id and bool(s.call(&"is_level")):
			step = s
	if step == null:
		print("%s: no such campaign step" % key)
		return {}
	# The same fresh profile every run (first-time hints and the doghouse's first Octodogs alike).
	_app.set(&"profile", Profile.new())
	var args := PackedStringArray(["--god", "--nofall", "--lanes=%d" % _lanes])
	if _full_loadout:
		args.append("--full-loadout")
	_app.set(&"_review_args", args)
	_monitor.set(&"world", null)
	await physics_frame
	var t0: int = Time.get_ticks_usec()
	var boss_def: Object = step.get(&"boss") if is_boss else null
	var preview: Object = boss_def.call(&"preview") if boss_def != null and boss_def.has_method(&"preview") else null
	if preview != null:
		# A fight still being built plays its preview scene as quick play, as --boss= does.
		_app.call(&"start_boss_quick", preview, args)
	else:
		_app.call(&"play_step", step, 0)
	var load_ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	_run = _app.get(&"run")
	if _run == null:
		print("%s: the App started no run" % key)
		return {}
	var world: Node = _run.get(&"world")
	_monitor.call(&"watch", world)
	var encounter: Node = _run.get(&"encounter")
	if encounter != null:
		_monitor.call(&"watch_boss", encounter)
	_bot = null
	if is_boss and BOTS.has(id) and ResourceLoader.exists(BOTS[id]) and encounter != null:
		_bot = (load(BOTS[id]) as GDScript).new(encounter)
	_watch = null
	_events.clear()
	if _log and ResourceLoader.exists(ATTACK_WATCH):
		_watch = (load(ATTACK_WATCH) as GDScript).new(world, false)
		_watch.set(&"keep_lane", -1)
		var director: Object = world.get(&"director")
		director.connect(&"enemy_defeated", func(e: Node, cause: StringName) -> void:
			_events.append("%.3f kill %s %s" % [float(world.call(&"level_time")), e.get(&"type_id"), cause]))
	var player: Node = world.get(&"player")
	var config: Object = world.get(&"config")
	_rng.seed = int(config.get(&"level_seed")) * 7919 + _lanes
	_frame = 0
	_next_move = 30
	_draws.clear()
	_primitives.clear()
	_objects.clear()
	_materials.clear()
	_shaders.clear()
	_peak_materials = 0
	_peak_shaders = 0
	_firsts.clear()
	_ref_times.clear()
	_shaders_scan = _shaders_scan or _rendering
	var compiles_before: Array[int] = _compiles()
	var speed: float = float((world.get(&"tuning") as Object).get(&"run_speed"))
	# The frame that built the level ends at the next physics step: the run's frames start after it.
	await physics_frame
	_monitor.call(&"clear")
	if _shaders_scan:
		_scan_materials(false)
	var layout_length: float = float((world.get(&"layout") as Object).get(&"length"))
	var limit: float = _limit if _limit < INF else (BOSS_SECONDS if is_boss else INF)
	while true:
		await physics_frame
		if not is_instance_valid(_run) or not is_instance_valid(world):
			break
		# A level ends at its finish; a boss fight once its defeat has played out (LevelRun._victory_time).
		var state: int = int(_run.get(&"state"))
		var victory: Variant = _run.get(&"_victory_time")
		if state != 0 and (victory == null or float(victory) < 0.0):  # 0: LevelRun.State.RUNNING
			break
		if encounter == null and float(player.get(&"distance")) >= layout_length:
			break
		if float(world.call(&"level_time")) >= limit:
			break
	var seconds: float = float(world.call(&"level_time")) if is_instance_valid(world) else 0.0
	var r: Dictionary = {"run": key, "lanes": _lanes, "speed": speed, "seconds": seconds, "load_ms": load_ms,
		"totals": (_monitor.get(&"totals") as PackedInt32Array).duplicate(),
		"physics": (_monitor.get(&"physics") as PackedInt32Array).duplicate(),
		# (JSON keeps a byte array as a string: the holds go as ints.)
		"frozen": PackedInt32Array(Array(_monitor.get(&"frozen") as PackedByteArray)),
		"tags": (_monitor.get(&"tags") as Array).duplicate(true)}
	if _watch != null:
		var log := PackedStringArray(_watch.get(&"log") as PackedStringArray)
		log.append_array(_events)
		log.sort()
		r["log_hash"] = "\n".join(log).md5_text()
		r["log_lines"] = log.size()
		r["log"] = Array(log)
	if _reference:
		r["reference_times"] = Array(_ref_times)
	if _shaders_scan:
		_scan_materials()
		r["shader_firsts"] = _firsts.duplicate()
		r["shaders_at_load"] = _shaders.size() - _firsts.size()
	if _rendering:
		var compiles_after: Array[int] = _compiles()
		var compiled: Array[int] = []
		for i: int in compiles_after.size():
			compiled.append(compiles_after[i] - compiles_before[i])
		r["draws"] = _draws.duplicate()
		r["primitives"] = _primitives.duplicate()
		r["objects"] = _objects.duplicate()
		r["compiled"] = compiled
		r["materials"] = _materials.size()
		r["shaders"] = _shaders.size()
		r["peak_materials"] = _peak_materials
		r["peak_shaders"] = _peak_shaders
	_monitor.set(&"world", null)
	_run = null
	_bot = null
	_watch = null
	return r


## Drives the run every physics frame, before the player moves: the bot or the scripted runner, and the
## event log. Its own time is left out of the frame (FrameMonitor.discount).
func _physics_process(_delta: float) -> bool:
	if _run == null or not is_instance_valid(_run) or _monitor == null:
		return false
	var t0: int = Time.get_ticks_usec()
	var world: Node = _run.get(&"world")
	if world != null and is_instance_valid(world):
		var player: Node = world.get(&"player")
		_frame += 1
		if _bot != null:
			_bot.call(&"step")
		elif bool(player.get(&"running")) and bool(player.get(&"alive")) and _frame >= _next_move:
			_next_move = _frame + _rng.randi_range(30, 75)
			_move(player, world)
		if _watch != null:
			_watch.call(&"observe")
			if _frame % 60 == 0:
				_events.append("%.3f runner lane=%d surface=%d d=%.2f" % [float(world.call(&"level_time")),
					int(player.get(&"lane")), int(player.get(&"surface")), float(player.get(&"distance"))])
		if _rendering:
			_draws.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
			_primitives.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
			_objects.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
		if _shaders_scan and _frame % SHADER_SCAN_FRAMES == 0:
			_scan_materials()
		if _reference and _frame % REFERENCE_EVERY == 0:
			_reference_step()
	_monitor.call(&"discount", Time.get_ticks_usec() - t0)
	return false


## Builds the reference track's next chunk and times it (--reference): SkinSuite's reference, a
## REFERENCE_LANES-lane grey-box layout one chunk-step at a time, started afresh when it runs out.
func _reference_step() -> void:
	if _ref_track == null or _ref_d > 3800.0:
		if _ref_world != null:
			_ref_world.queue_free()
		_ref_world = Node3D.new()
		_ref_world.position = REFERENCE_AT
		root.add_child(_ref_world)
		_ref_track = TrackBuilder.new()
		_ref_world.add_child(_ref_track)
		_ref_track.set_layout(RunSim.layout(_reference_lanes(), 4000.0), load(TestSuite.TUNING_PATH) as MovementTuning,
			GreyboxSkin.new())
		_ref_track.update(0.0, 0.0)
		_ref_d = 0.0
		return
	_ref_d += TrackBuilder.CHUNK_LENGTH
	var t0: int = Time.get_ticks_usec()
	_ref_track.update(_ref_d, 0.0)
	_ref_times.append((Time.get_ticks_usec() - t0) / 1000.0)
	# The chunks it left behind go now, inside the time left out of the frame, not at the frame's end.
	for chunk: Node in _ref_track.get_children():
		if chunk.is_queued_for_deletion():
			chunk.free()


## SkinSuite.REFERENCE_LANES, looked up by name so the tool still loads in a tree without it (an older
## build measured for comparison).
static func _reference_lanes() -> int:
	for c: Dictionary in ProjectSettings.get_global_class_list():
		if StringName(c["class"]) == &"SkinSuite":
			return int((load(String(c["path"])) as GDScript).get_script_constant_map().get("REFERENCE_LANES", 40))
	return 40


## One move of the scripted runner: mostly lane switches (one onto a wall now and then), some jumps and
## slides, picked by the level's seed.
func _move(player: Node, world: Node) -> void:
	var lanes: int = int((world.get(&"geo") as Object).get(&"lane_count"))
	var lane: int = int(player.get(&"lane"))
	var roll: float = _rng.randf()
	if roll < 0.55:
		var dir: int = -1 if _rng.randf() < 0.5 else 1
		# Onto a wall only now and then: from an outer lane, a move outward one time in four.
		if (lane + dir < 0 or lane + dir >= lanes) and _rng.randf() > 0.25:
			dir = -dir
		player.call(&"press", &"move_left" if dir < 0 else &"move_right")
	elif roll < 0.85:
		player.call(&"press", &"jump")
	else:
		player.call(&"press", &"slide")


## The renderer's pipeline compilations so far, by source: canvas, mesh, surface, draw, specialization.
static func _compiles() -> Array[int]:
	var out: Array[int] = []
	for info: int in [RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS,
			RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH, RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE,
			RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW, RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION]:
		out.append(RenderingServer.get_rendering_info(info))
	return out


## Notes the materials and shaders of everything visible in the run (its world, the camera's view and
## its HUD), for the run's totals and the most at once. A shader seen for the first time since the run
## began playing is a first use: its frame is tagged shader+N (a pipeline or shader the renderer must
## compile right then, unless the level's load already drew it), and noted with what drew it.
func _scan_materials(during_play: bool = true) -> void:
	if _run == null or not is_instance_valid(_run):
		return
	var materials: Dictionary = {}
	var shaders: Dictionary = {}
	var stack: Array[Node] = [_run]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child: Node in node.get_children():
			stack.append(child)
		var used: Array[Material] = []
		var canvas := node as CanvasItem
		if canvas != null:
			if canvas.is_visible_in_tree() and canvas.material != null:
				used.append(canvas.material)
		var geometry := node as GeometryInstance3D
		if geometry != null and geometry.is_visible_in_tree():
			if geometry.material_override != null:
				used.append(geometry.material_override)
			else:
				var mesh_instance := geometry as MeshInstance3D
				var mesh: Mesh = mesh_instance.mesh if mesh_instance != null else null
				if mesh_instance == null:
					var multimesh := geometry as MultiMeshInstance3D
					mesh = multimesh.multimesh.mesh if multimesh != null and multimesh.multimesh != null else null
					var particles := geometry as CPUParticles3D
					if particles != null:
						mesh = particles.mesh
				if mesh != null:
					for k: int in mesh.get_surface_count():
						var m: Material = mesh_instance.get_surface_override_material(k) if mesh_instance != null else null
						if m == null:
							m = mesh.surface_get_material(k)
						if m != null:
							used.append(m)
		for m: Material in used:
			while m != null:
				materials[m.get_instance_id()] = true
				var key: String = _shader_key(m)
				if not shaders.has(key):
					shaders[key] = node
				m = m.next_pass
	for k: Variant in materials:
		_materials[k] = true
	var fresh: int = 0
	for k: String in shaders:
		if not _shaders.has(k):
			_shaders[k] = true
			if during_play:
				fresh += 1
				var where: Node = shaders[k]
				_firsts.append({"frame": int(_monitor.call(&"frame_count")), "shader": k,
					"node": _short_path(where)})
	if fresh > 0:
		_monitor.call(&"tag", "shader+%d" % fresh)
	# The most at once during play: the look at the load also sees the shader warm-up's samples (ShaderWarmup).
	if during_play:
		_peak_materials = maxi(_peak_materials, materials.size())
		_peak_shaders = maxi(_peak_shaders, shaders.size())


## Where a node is in the run, short: its first two and last two names (World/Enemies/.../Body/Part).
func _short_path(node: Node) -> String:
	var parts: PackedStringArray = String(_run.get_path_to(node)).split("/")
	if parts.size() > 4:
		parts = PackedStringArray([parts[0], parts[1], "...", parts[-2], parts[-1]])
	return "/".join(parts)


## What makes a material's shader, by name: a shader material's own shader (its file, or a hash of its
## code), or a standard material's features (the ones that change the shader Godot makes for it).
static func _shader_key(m: Material) -> String:
	var sm := m as ShaderMaterial
	if sm != null:
		if sm.shader == null:
			return "shader:none"
		if sm.shader.resource_path != "":
			return "shader:" + sm.shader.resource_path.get_file()
		return "shader:code-%s" % sm.shader.code.md5_text().substr(0, 8)
	var b := m as BaseMaterial3D
	if b == null:
		return m.get_class()
	return "std:t%d s%d b%d c%d d%d n%d v%d e%d a%d bb%d r%d" % [b.transparency, b.shading_mode, b.blend_mode,
		b.cull_mode, b.depth_draw_mode, int(b.no_depth_test), int(b.vertex_color_use_as_albedo),
		int(b.emission_enabled), int(b.albedo_texture != null), b.billboard_mode, int(b.disable_receive_shadows)]


## Two passes of the same run: each frame's faster time, if they played the same frames.
func _fold(a: Dictionary, b: Dictionary) -> Dictionary:
	var ta: PackedInt32Array = a["totals"]
	var tb: PackedInt32Array = b["totals"]
	if ta.size() != tb.size():
		print("  %s: the passes played %d and %d frames; keeping the first pass" % [a["run"], ta.size(), tb.size()])
		return a
	var pa: PackedInt32Array = a["physics"]
	var pb: PackedInt32Array = b["physics"]
	for i: int in ta.size():
		if tb[i] < ta[i]:
			ta[i] = tb[i]
			pa[i] = pb[i]
	a["load_ms"] = minf(float(a["load_ms"]), float(b["load_ms"]))
	if a.has("log_hash") and b.has("log_hash") and a["log_hash"] != b["log_hash"]:
		print("  %s: the passes' event logs differ (%s, %s)" % [a["run"], a["log_hash"], b["log_hash"]])
	return a


## The run's numbers from its frames: the times, the hit-stops and the causes of its spikes.
func _finish(r: Dictionary) -> void:
	var totals: PackedInt32Array = r["totals"]
	var ms := PackedFloat32Array()
	ms.resize(totals.size())
	for i: int in totals.size():
		ms[i] = totals[i] / 1000.0
	var s: Dictionary = (load(MONITOR_SCRIPT) as GDScript).call(&"summarize", ms)
	r.merge(s, true)
	var tags: Array = r["tags"]
	var frozen: PackedInt32Array = r["frozen"]
	var kills: int = 0
	var stops: int = 0
	var held: int = 0
	var longest: int = 0
	var run_len: int = 0
	var chained: int = 0
	for i: int in tags.size():
		for t: String in tags[i]:
			if t.begins_with("kill:"):
				kills += 1
			elif t == "hit-stop":
				stops += 1
				if i > 0 and frozen[i - 1] == 1:
					chained += 1
		if frozen[i] == 1:
			held += 1
			run_len += 1
			longest = maxi(longest, run_len)
		else:
			run_len = 0
	r["kills"] = kills
	r["hit_stops"] = stops
	r["held_frames"] = held
	r["longest_hold"] = longest
	r["chained_stops"] = chained
	var median: float = float(s["median"])
	var excess: Dictionary = {}
	var counts: Dictionary = {}
	var spikes: int = 0
	for i: int in ms.size():
		if ms[i] <= SPIKE_MS:
			continue
		spikes += 1
		var names: Dictionary = {}
		for t: String in tags[i]:
			names[_cause(t)] = true
		if names.is_empty():
			names["-"] = true
		for n: String in names:
			excess[n] = float(excess.get(n, 0.0)) + ms[i] - median
			counts[n] = int(counts.get(n, 0)) + 1
	var causes: Array = excess.keys()
	causes.sort_custom(func(x: String, y: String) -> bool: return float(excess[x]) > float(excess[y]))
	var top: Array[Dictionary] = []
	for c: String in causes:
		top.append({"cause": c, "ms": excess[c], "count": counts[c]})
	r["spikes"] = spikes
	r["causes"] = top


## A tag without its numbers, so the same cause groups together (chunk+1 and chunk+2 are both chunk+).
static func _cause(t: String) -> String:
	for prefix: String in ["chunk+", "chunk-", "nodes+", "nodes-", "obj+", "compile:", "physics:"]:
		if t.begins_with(prefix):
			return prefix.trim_suffix(":")
	return t


func _line(r: Dictionary) -> String:
	var causes: PackedStringArray = []
	for c: Dictionary in (r["causes"] as Array).slice(0, 6):
		causes.append("%s %.0f/%d" % [c["cause"], float(c["ms"]), int(c["count"])])
	var line: String = "%-16s %5.1f %6.1f %6d %7.0f | %5.2f %5.2f %5.2f %6.2f %5d %5d | %5d %5d %4d %4d %5d | %s" % [
		String(r["run"]).trim_prefix("level:"), float(r["speed"]), float(r["seconds"]), int(r["frames"]),
		float(r["load_ms"]), float(r["median"]), float(r["p95"]), float(r["p99"]), float(r["worst"]), int(r["over8"]),
		int(r["over16"]), int(r["kills"]), int(r["hit_stops"]), int(r["held_frames"]), int(r["longest_hold"]),
		int(r["chained_stops"]), ", ".join(causes)]
	if r.has("log_hash"):
		line += "  log %s (%d lines)" % [String(r["log_hash"]).substr(0, 10), int(r["log_lines"])]
	return line


## What the renderer drew in a run (a real renderer only): draw calls, primitives and objects a frame
## (median and most), pipelines compiled during the run by source, and the materials and shaders seen.
func _render_line(r: Dictionary) -> String:
	var out: PackedStringArray = []
	for key: String in ["draws", "primitives", "objects"]:
		var values := PackedFloat32Array()
		for v: int in r[key]:
			values.append(v)
		var s: Dictionary = (load(MONITOR_SCRIPT) as GDScript).call(&"summarize", values)
		out.append("%s %d/%d" % [key, int(s["median"]), int(s["worst"])])
	var c: Array = r["compiled"]
	return "    renderer: %s (median/most a frame); pipelines compiled canvas %d, mesh %d, surface %d, draw %d, specialization %d; materials %d (%d at once), shaders %d (%d at once)" % [
		", ".join(out), c[0], c[1], c[2], c[3], c[4], int(r["materials"]), int(r["peak_materials"]), int(r["shaders"]),
		int(r["peak_shaders"])]


## The shaders first drawn after the level's load, each with the frame and what drew it.
func _shaders_line(r: Dictionary) -> String:
	var firsts: Array = r["shader_firsts"]
	var parts: PackedStringArray = []
	for f: Dictionary in firsts:
		parts.append("%s at %.1f s (%s)" % [f["shader"], int(f["frame"]) / 60.0, f["node"]])
	return "    shaders: %d at the load, %d first drawn later%s" % [int(r["shaders_at_load"]), firsts.size(),
		(": " + "; ".join(parts)) if not parts.is_empty() else ""]


func _print_slow_frames(r: Dictionary) -> void:
	var totals: PackedInt32Array = r["totals"]
	var physics: PackedInt32Array = r["physics"]
	var tags: Array = r["tags"]
	for i: int in totals.size():
		if totals[i] / 1000.0 > SPIKE_MS:
			print("    frame %5d (%6.2f s) %6.2f ms (physics %5.2f) %s" % [i, i / 60.0, totals[i] / 1000.0,
				physics[i] / 1000.0, " ".join(tags[i])])


func _print_totals(runs: Array[Dictionary]) -> void:
	if runs.is_empty():
		return
	var all := PackedFloat32Array()
	var kills: int = 0
	var stops: int = 0
	var seconds: float = 0.0
	for r: Dictionary in runs:
		var totals: PackedInt32Array = r["totals"]
		for t: int in totals:
			all.append(t / 1000.0)
		kills += int(r["kills"])
		stops += int(r["hit_stops"])
		seconds += float(r["seconds"])
	var s: Dictionary = (load(MONITOR_SCRIPT) as GDScript).call(&"summarize", all)
	print("all %d runs: %d frames, median %.2f, p95 %.2f, p99 %.2f, worst %.2f ms, %d over 8 ms, %d over 16 ms; %d kills, %d hit-stops (%.1f a minute)" % [
		runs.size(), int(s["frames"]), float(s["median"]), float(s["p95"]), float(s["p99"]), float(s["worst"]),
		int(s["over8"]), int(s["over16"]), kills, stops, stops / maxf(seconds / 60.0, 0.001)])

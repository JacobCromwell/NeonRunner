extends SceneTree
## Checks an exported web demo from the inside (task E2). Run its pack with the desktop Godot, headless:
##   godot --headless --main-pack exports/web/index.pck --fixed-fps 60 -s <absolute path>/tools/web/check_pack.gd
## (`tools/godot.sh web` exports the demo and runs this). The game then runs from the pack alone, so
## anything the demo needs that the export filter left out fails here:
## - it is the web demo by the export's own feature tag (no --flavor);
## - every music track and sound the demo can play loads from the pack, and the tracks and riffs it
##   never plays aren't in it (the export stays lean);
## - the demo's flow, walked from the title to the "get the full game" screen (demo_walk.gd: the
##   City's three levels and the Floating Head, with the results and the shop between them), logs no
##   error or warning.
## Prints what it found and exits with 0 when all is well, 1 otherwise. The profile it plays is a fresh
## one, never saved.

## A check still running after this long (real time) is stuck.
const WATCHDOG_SECONDS: int = 900

var _watcher: Watcher
var _deadline_msec: int = 0


## Collects every error and warning logged while the check runs (warnings too: a missing music file
## or sound is only a warning).
class Watcher:
	extends Logger

	var lines: PackedStringArray = []
	var _lock: Mutex = Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
			error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		var kind: String = ["ERROR", "WARNING", "SCRIPT ERROR", "SHADER ERROR"][clampi(error_type, 0, 3)]
		_lock.lock()
		lines.append("%s: %s (%s:%d, %s)" % [kind, rationale if rationale != "" else code, file, line, function])
		_lock.unlock()

	func _log_message(message: String, error: bool) -> void:
		if error:
			_lock.lock()
			lines.append(message.strip_edges())
			_lock.unlock()


func _initialize() -> void:
	_deadline_msec = Time.get_ticks_msec() + WATCHDOG_SECONDS * 1000
	_watcher = Watcher.new()
	OS.add_logger(_watcher)
	_run.call_deferred()


func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() > _deadline_msec:
		print("PACK CHECK STUCK: no result after %d s of real time" % WATCHDOG_SECONDS)
		quit(1)
	return false


func _run() -> void:
	# A main-loop script compiles before the autoloads are named globals: reach them through the tree.
	var app: Node = root.get_node(^"App")
	var platform: Node = root.get_node(^"Platform")
	var walk_script := load((get_script() as Script).resource_path.get_base_dir().path_join("demo_walk.gd")) as GDScript
	var problems := PackedStringArray()
	print("Checking the web demo's pack with Godot %s" % Engine.get_version_info()["string"])
	# The build: the web demo by its own feature tag.
	if not OS.has_feature("web_demo") or BuildFlavor.current() != BuildFlavor.Kind.WEB_DEMO:
		problems.append("the pack isn't the web demo: no web_demo feature tag (flavor %s)" % BuildFlavor.name_of(BuildFlavor.current()))
	if platform.call(&"ads_available") or platform.call(&"purchases_available") or platform.call(&"leaderboards_available"):
		problems.append("the platform offers ads, purchases or leaderboards")
	# Music and sounds: the demo's all load, the rest are left out.
	var campaign: Campaign = app.get(&"campaign")
	var sfx: SfxLibrary = app.get(&"sfx_library")
	var tracks: PackedStringArray = walk_script.call(&"demo_tracks", campaign)
	var music := load(MusicDirector.LIBRARY_PATH) as MusicLibrary
	var left_out: int = 0
	for track: String in music.names():
		var file: String = music.path(StringName(track))
		if tracks.has(track):
			if not ResourceLoader.exists(file) or not load(file) is AudioStream:
				problems.append("the demo plays the %s track, but %s isn't in the pack" % [track, file])
		elif ResourceLoader.exists(file):
			problems.append("%s is in the pack, but the demo never plays the %s track" % [file, track])
		else:
			left_out += 1
	var sounds: PackedStringArray = walk_script.call(&"demo_sounds", sfx, tracks)
	var loaded_sounds: int = 0
	for sound: String in sfx.names():
		var path: String = sfx.folder.path_join(sound + ".wav")
		if sounds.has(sound):
			if ResourceLoader.exists(path) and load(path) is AudioStream:
				loaded_sounds += 1
			else:
				problems.append("the demo may play %s, but %s isn't in the pack" % [sound, path])
		elif ResourceLoader.exists(path):
			problems.append("%s is in the pack, but the demo never plays it" % path)
		else:
			left_out += 1
	print("  music: %s load; %d sounds load; %d tracks and riffs left out" % [", ".join(tracks), loaded_sounds, left_out])
	# The flow, from the title to the end screen.
	var main_scene: Node = (load(String(ProjectSettings.get_setting("application/run/main_scene"))) as PackedScene).instantiate()
	root.add_child(main_scene)
	await process_frame
	app.set(&"autosave", false)
	app.set(&"profile", Profile.new())
	var walk: RefCounted = walk_script.new(self)
	var reached: bool = await walk.call(&"walk")
	for line: String in walk.get(&"runs") as PackedStringArray:
		print("  " + line)
	print("  screens: %s" % ", ".join(walk.get(&"screens") as PackedStringArray))
	if not reached:
		problems.append("the walk didn't reach the end screen")
	problems.append_array(walk.get(&"problems") as PackedStringArray)
	for offer: String in walk.get(&"offers") as PackedStringArray:
		problems.append("an offer of ads, purchases or leaderboards on %s" % offer)
	app.call(&"show_title")
	await process_frame
	main_scene.queue_free()
	app.set(&"main", null)
	await process_frame
	OS.remove_logger(_watcher)
	for line: String in _watcher.lines:
		problems.append("logged: " + line)
	if problems.is_empty():
		print("PACK CHECK PASSED: the demo plays from the title to its end screen from the pack alone")
		quit(0)
	else:
		for p: String in problems:
			print("PROBLEM: " + p)
		print("PACK CHECK FAILED (%d problems)" % problems.size())
		quit(1)

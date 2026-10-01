extends SceneTree
## Checks an exported web demo from the inside (task E2). Run its pack with the desktop Godot, headless,
## from the pack's folder:
##   cd exports/web && godot --headless --main-pack index.pck --fixed-fps 60 -s <repo>/tools/web/check_pack.gd
## (`tools/godot.sh web` exports the demo and runs this). The game then runs from the pack alone, so
## anything the demo needs that the export filter left out fails here:
## - it is the web demo by the export's own feature tag (no --flavor), with no ads, purchases or
##   leaderboards;
## - every music track and sound the demo can play loads from the pack (demo_filter.gd names them
##   from the data), and no other music or riff is in it (the export stays lean);
## - the demo's flow, walked from the title to the "get the full game" screen (demo_walk.gd: the
##   City's three levels and the Floating Head, with the results and the shop between them), logs no
##   error or warning.
## Prints what it found and exits with 0 when all is well, 1 otherwise. It plays a fresh profile and
## never saves it.

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
	var here: String = (get_script() as Script).resource_path.get_base_dir()
	var filter_script := load(here.path_join("demo_filter.gd")) as GDScript
	var walk_script := load(here.path_join("demo_walk.gd")) as GDScript
	var problems := PackedStringArray()
	print("Checking the web demo's pack with Godot %s" % Engine.get_version_info()["string"])
	# The build: the web demo by its own feature tag.
	if not OS.has_feature("web_demo") or BuildFlavor.current() != BuildFlavor.Kind.WEB_DEMO:
		problems.append("the pack isn't the web demo: no web_demo feature tag (flavor %s)" % BuildFlavor.name_of(BuildFlavor.current()))
	if platform.call(&"ads_available") or platform.call(&"purchases_available") or platform.call(&"leaderboards_available"):
		problems.append("the platform offers ads, purchases or leaderboards")
	problems.append_array(_check_audio(app, filter_script))
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


## The demo's music and sounds load from the pack; nothing else of the music library's folders, and
## no riff of a track it never plays, is in it.
func _check_audio(app: Node, filter_script: GDScript) -> PackedStringArray:
	var problems := PackedStringArray()
	var campaign: Campaign = app.get(&"campaign")
	var sfx: SfxLibrary = app.get(&"sfx_library")
	var music := load(MusicDirector.LIBRARY_PATH) as MusicLibrary
	var tracks: PackedStringArray = filter_script.call(&"demo_tracks", campaign)
	var sounds: PackedStringArray = filter_script.call(&"demo_sounds", sfx, music, tracks)
	var keep: PackedStringArray = filter_script.call(&"demo_audio_files", music, sfx, tracks)
	for file: String in keep:
		if not ResourceLoader.exists(file) or not load(file) is AudioStream:
			problems.append("the demo needs %s, but it isn't in the pack" % file)
	# In a pack, a folder lists an imported file by its .import remap.
	var folders := PackedStringArray([sfx.folder])
	for track: String in music.names():
		var folder: String = music.path(StringName(track)).get_base_dir()
		if folder != "" and not folders.has(folder):
			folders.append(folder)
	var extensions: PackedStringArray = filter_script.get_script_constant_map()["AUDIO_EXTENSIONS"]
	var shipped: int = 0
	for folder: String in folders:
		for file_name: String in DirAccess.get_files_at(folder):
			var path: String = folder.path_join(file_name.trim_suffix(".import").trim_suffix(".remap"))
			if not file_name.ends_with(".import") or not extensions.has(path.get_extension().to_lower()):
				continue
			shipped += 1
			if not keep.has(path):
				problems.append("%s is in the pack, but the demo never plays it" % path)
	print("  music: %s; %d of %d sounds; %d audio files in the pack" % [", ".join(tracks), sounds.size(),
		sfx.names().size(), shipped])
	return problems

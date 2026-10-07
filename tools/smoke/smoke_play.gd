extends SceneTree
## The smoke run for a campaign level or boss (`tools/godot.sh smoke --level=city/1`, `--boss=...`).
## A campaign run waits at its level introduction (the owner's hints before PLAY) until the player presses
## PLAY, so the plain game would only build the level and show that screen. This runs the real main scene
## as the game does and presses PLAY through the App (App.begin_run, as the PLAY button does and as
## tools/measure/frame_times.gd does), then lets the level play for the rest of the run. The intro screen
## itself is still built and shown first, so anything it prints still reaches the smoke run's output.
## Prints only problems (a level that never left its introduction, or never ran) and exits 1 if there are
## any; script errors the level raises are Godot's own output. From the project folder:
##   godot --headless --fixed-fps 60 --quit-after 2500 -s res://tools/smoke/smoke_play.gd -- --level=city/1 [game args]
## Options (besides the game's own, which are passed on):
##   --smoke-frames=N   stop after N frames (default SMOKE_FRAMES)
##   --smoke-report     also print what the run did (frames, state, the runner's furthest distance)
##   --smoke-hold       don't press PLAY (proves the "never left the introduction" check; tests only)

## The run's length, as quick play's smoke run (tools/godot.sh passes a larger --quit-after as a backstop: the
## check has to run before the tree is torn down).
const SMOKE_FRAMES: int = 2400
## Frames the app gets to build the run and its introduction before PLAY is pressed.
const PRESS_AFTER_FRAMES: int = 2

var _frames: int = 0
var _stop_after: int = SMOKE_FRAMES
var _hold: bool = false
var _report: bool = false
var _saw_run: bool = false
var _pressed: bool = false
var _distance: float = 0.0
var _finished: bool = false


var _app: Node


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--smoke-frames="):
			_stop_after = int(arg.get_slice("=", 1))
		elif arg == "--smoke-report":
			_report = true
		elif arg == "--smoke-hold":
			_hold = true
	# The same scene the project runs; its autoloads (App, Music, ...) exist already.
	var main_scene := load(str(ProjectSettings.get_setting("application/run/main_scene"))) as PackedScene
	root.add_child(main_scene.instantiate())
	_app = root.get_node("App")


func _process(_delta: float) -> bool:
	_frames += 1
	var run: Object = _run()
	if run != null:
		_saw_run = true
		if int(run.get(&"state")) == _ready_state(run) and not _hold and not _pressed and _frames >= PRESS_AFTER_FRAMES:
			_app.call(&"begin_run")
			_pressed = true
		var world: Object = run.get(&"world")
		var player: Object = world.get(&"player") if world != null else null
		if player != null:
			_distance = maxf(_distance, float(player.get(&"distance")))
	if _stop_after > 0 and _frames >= _stop_after:
		_finish()
		return true
	return false


## LevelRun.State.READY. (Not named in this script: compiling LevelRun here, before the autoloads it uses
## exist in a -s script, fails.)
func _ready_state(run: Object) -> int:
	var states: Dictionary = (run.get_script() as GDScript).get_script_constant_map().get("State", {})
	return int(states.get("READY", -1))


func _run() -> Object:
	return _app.get(&"run")


func _finish() -> void:
	if _finished:
		return
	_finished = true
	var run: Object = _run()
	var problems: PackedStringArray = []
	if not _saw_run:
		problems.append("smoke: the App started no run")
	elif run != null and int(run.get(&"state")) == _ready_state(run):
		problems.append("smoke: the level never left its introduction screen (PLAY was %s)" % (
			"not pressed (--smoke-hold)" if _hold else "pressed but did not start it"))
	elif _distance <= 0.0:
		problems.append("smoke: the level started but the runner never moved")
	if _report:
		var states: Dictionary = (run.get_script() as GDScript).get_script_constant_map().get("State", {}) if run != null else {}
		print("smoke report: %d frames, run %s, PLAY %s, furthest distance %.0f m" % [_frames,
			states.find_key(int(run.get(&"state"))) if run != null else "gone (left the level)",
			"pressed" if _pressed else "not pressed", _distance])
	for p: String in problems:
		print(p)
	if not problems.is_empty():
		quit(1)

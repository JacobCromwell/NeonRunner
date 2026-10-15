extends SceneTree
## Plays the Beach's volleyball level (`--level=beach/2`, VolleyballMatch) through the real main scene, presses PLAY,
## lets a bot play the match (VolleyballBot) and saves screenshots, for reviewing the court, the rival, the ball and
## the match's flow. Needs a display (not --headless); under WSL or a container, xvfb-run and the Compatibility
## renderer work:
##   xvfb-run -a godot --rendering-method gl_compatibility --resolution 960x540 --fixed-fps 30 \
##     -s res://tools/showcase/volleyball_review.gd -- --bot=perfect --shot-every=45 [game args, e.g. --lanes=5]
## Options:
##   --bot=perfect|idle|stand|wrong|points:N   how the runner plays (VolleyballBot; default perfect)
##   --shot-every=N    save a screenshot every N frames to build/volleyball/<frame>.png (0: none; default 0)
##   --shots=a,b,...   save screenshots at these frames
##   --shot-events=a,b  save a screenshot when the match logs one of these events (VolleyballMatch.events, by their
##                     start: hit, winner, point, match, exit, bonk, drop), named <frame>_<event>.png, and
##                     --event-delay=N frames after it (default 0)
##   --frames=N        stop after N frames (default 5400), or when the run ends
##   --camera=rival|side  a review camera instead of the chase camera once the match is built: in front of the rival
##                     (his model and moves up close), or beside the court (the ball's arcs over the net)
## Prints the match's events and its result at the end.

const OUT_DIR: String = "res://build/volleyball"
## Loaded once the game is up: a script run with -s compiles before the autoloads exist, so it names none of the
## game's classes that need them (LevelRun needs App), as tools/smoke/smoke_play.gd doesn't.
const BOT_PATH: String = "res://tests/helpers/volleyball_bot.gd"

var _app: Node
var _frames: int = 0
var _stop_after: int = 5400
var _every: int = 0
var _shots: PackedInt32Array = []
var _skill: String = "perfect"
var _pressed: bool = false
var _bot: RefCounted
var _game: Node
var _printed: bool = false
## The match's last known result (the match goes with the run when it ends).
var _result: Dictionary = {}
var _shot_events: PackedStringArray = []
var _event_delay: int = 0
var _seen_events: int = 0
var _pending: Array = []
var _camera_mode: String = ""
var _camera: Camera3D


func _initialize() -> void:
	var has_level: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--bot="):
			_skill = arg.get_slice("=", 1)
		elif arg.begins_with("--shot-every="):
			_every = int(arg.get_slice("=", 1))
		elif arg.begins_with("--shots="):
			for v: String in arg.get_slice("=", 1).split(",", false):
				_shots.append(int(v))
		elif arg.begins_with("--shot-events="):
			_shot_events = arg.get_slice("=", 1).split(",", false)
		elif arg.begins_with("--event-delay="):
			_event_delay = int(arg.get_slice("=", 1))
		elif arg.begins_with("--camera="):
			_camera_mode = arg.get_slice("=", 1)
		elif arg.begins_with("--frames="):
			_stop_after = int(arg.get_slice("=", 1))
		elif arg.begins_with("--level="):
			has_level = true
	if not has_level:
		push_error("volleyball_review: pass --level=beach/2 among the game args")
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	FileAccess.open("res://build/.gdignore", FileAccess.WRITE).store_string("")
	var main_scene := load(str(ProjectSettings.get_setting("application/run/main_scene"))) as PackedScene
	root.add_child(main_scene.instantiate())
	_app = root.get_node("App")
	physics_frame.connect(_on_physics)


func _on_physics() -> void:
	if _bot != null:
		_bot.call(&"step")


func _process(_delta: float) -> bool:
	_frames += 1
	var run: Node = _app.get(&"run") as Node
	if run != null and not is_instance_valid(run):
		run = null
	if run != null:
		# LevelRun.State.READY: the level introduction waits for PLAY.
		if int(run.get(&"state")) == 3 and not _pressed and _frames >= 3:
			_app.call(&"begin_run")
			_pressed = true
		var game: Node = run.get(&"minigame") as Node
		if _game == null and game != null:
			_game = game
			_bot = (load(BOT_PATH) as GDScript).new(_game, _skill)
			if _camera_mode != "":
				_camera = Camera3D.new()
				_camera.fov = 45.0 if _camera_mode == "rival" else 55.0
				_game.add_child(_camera)
	if _camera != null and is_instance_valid(_camera) and _game != null and is_instance_valid(_game):
		_aim_camera()
	if (_every > 0 and _frames % _every == 0) or _shots.has(_frames):
		_shot("%05d" % _frames)
	if _game != null and is_instance_valid(_game):
		var events: PackedStringArray = _game.get(&"events")
		while _seen_events < events.size():
			var e: String = events[_seen_events]
			_seen_events += 1
			for want: String in _shot_events:
				if e.begins_with(want):
					_pending.append([_frames + _event_delay, "%05d_%s" % [_frames + _event_delay, e.replace(":", "-")]])
	for p: Array in _pending.duplicate():
		if _frames >= int(p[0]):
			_shot(String(p[1]))
			_pending.erase(p)
	if _game != null and is_instance_valid(_game):
		_result = {"won": _game.get(&"points_won"), "lost": _game.get(&"points_lost"),
			"returns": _game.get(&"total_returns"), "payout": _game.call(&"payout"), "events": _game.get(&"events")}
	var done: bool = _pressed and run == null
	if done or _frames >= _stop_after:
		if _result.is_empty():
			print("volleyball_review: no match ran")
		else:
			print("volleyball_review: %s, points %d-%d, returns %d, payout %d, %d frames%s" % [_skill, _result["won"],
				_result["lost"], _result["returns"], _result["payout"], _frames, " (run ended)" if done else ""])
			print("  events: %s" % ", ".join(_result["events"]))
		return true
	return false


func _aim_camera() -> void:
	var rival: Node3D = _game.get(&"rival") as Node3D
	if rival == null:
		return
	var net_z: float = -float(_game.get(&"net_at"))
	if _camera_mode == "rival":
		_camera.position = rival.global_position + Vector3(1.4, 1.2, 3.6)
		_camera.look_at(rival.global_position + Vector3(0.0, 0.75, 0.0))
	else:
		_camera.position = Vector3(11.0, 3.5, net_z + 1.0)
		_camera.look_at(Vector3(0.0, 1.6, net_z + 0.5))
	_camera.make_current()


func _shot(file_name: String) -> void:
	root.get_texture().get_image().save_png(OUT_DIR.path_join(file_name + ".png"))

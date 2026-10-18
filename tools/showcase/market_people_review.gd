extends Node3D
## The Marketplace citizens' review, for visual review only (not part of the game; task L7): a plain straight street in
## the Marketplace (or Casino) skin, seen from the game's camera as a runner passes the shop windows, or from still cameras
## close to a citizen's window and to a window with an ad screen or a poster (task L10). Render it on both renderers:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot4 --path . --resolution 960x540 --fixed-fps 10 \
##     --write-movie build/people/f.png --quit-after 120 res://tools/showcase/market_people_review.tscn -- --view=run
## (add --rendering-method gl_compatibility before the scene path for the web / low-end renderer).
## Options:
##   --skin=name     marketplace (default) or casino
##   --lanes=N       lane count (default 5)
##   --view=run      (default) a pseudo-runner at the game's pace from --from=D (default 0) along the street, the game's
##                   follow camera; --cheer-at=S has a big pickup's cheer fire S seconds in (and --shot-scale for none)
##   --view=window   still cameras, one every --hold frames (default 3): the nearest citizen's window from the lane
##                   beside it, from the game camera, close up; the nearest display window's the same; --shot=N shows one;
##                   --cheer has a cheer begin two frames into each shot (--hold=20 or more, past the cooldown), and
##                   --flinch The House's duck instead; --sweep=M walks the runner past the shot's citizen from M metres
##                   before it to M metres after over --sweep-frames (default 30), to see the heads turn
##   --focus=feet|head|full  with --view=window, the close shots: at the person's feet, at their head and shoulders, or
##                   at the whole of them (default)
##   --reduced-flashing  Settings > Reduced flashing on
##   --no-citizens   Settings.citizens_enabled off
## It prints each citizen it finds with its track distance and side.

const TUNING_PATH: String = "res://data/tuning/movement.tres"
const LENGTH: float = 600.0

var tuning: MovementTuning
var skin: ZoneSkin
var lanes: int = 5
var track: TrackBuilder
var camera: Camera3D
var layout: LevelLayout
var distance: float = 0.0
var elapsed: float = 0.0
var _frame: int = 0
var _hold: int = 3
var _shots: Array = []
var _view: String = "run"
var _cheer_at: float = -1.0
var _cheered: bool = false
## The z the shot's camera is looking at (INF in a run view): what --sweep walks the runner past.
var _look_z: float = INF


func _ready() -> void:
	tuning = load(TUNING_PATH) as MovementTuning
	lanes = int(_opt("lanes", "5"))
	_view = _opt("view", "run")
	_hold = int(_opt("hold", "3"))
	_cheer_at = float(_opt("cheer-at", "-1"))
	if _flag("reduced-flashing"):
		Settings.flashing_reduced = true
		RenderingServer.global_shader_parameter_set(&"reduced_flashing", 1.0)
	if _flag("no-citizens"):
		Settings.citizens_enabled = false
	skin = load("res://data/skins/%s_skin.tres" % _opt("skin", "marketplace")) as ZoneSkin
	var env := WorldEnvironment.new()
	env.environment = skin.level_environment(0.0, null)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
	sun.light_energy = 0.7
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)
	layout = LevelLayout.new()
	layout.lane_count = lanes
	layout.length = LENGTH
	track = TrackBuilder.new()
	add_child(track)
	track.set_layout(layout, tuning, skin)
	camera = Camera3D.new()
	camera.far = 600.0
	camera.fov = tuning.camera_fov
	add_child(camera)
	camera.make_current()
	distance = float(_opt("from", "0"))
	if _view == "window":
		track.update(120.0, 0.0)
		_shots = _shot_list()
		var only: String = _opt("shot", "")
		if only != "":
			_shots = [_shots[int(only)]]
		_show_shot(0)
		return
	track.update(distance, 0.0)
	MarketPeople.set_runner(Vector3(0.0, 1.0, -distance))
	_place_game_camera()
	_print_citizens()


func _physics_process(delta: float) -> void:
	if _view != "run":
		return
	distance += tuning.run_speed * delta
	elapsed += delta
	track.update(distance, elapsed)


func _process(_delta: float) -> void:
	_frame += 1
	if _view == "run":
		MarketPeople.set_runner(Vector3(0.0, 1.0, -distance))
		_place_game_camera()
		if _cheer_at >= 0.0 and not _cheered and elapsed >= _cheer_at:
			_cheered = true
			_fire_cheer()
		return
	if _frame % _hold == 0 and _frame / _hold < _shots.size():
		_show_shot(_frame / _hold)
	if _view == "window" and _opt("sweep", "") != "" and _look_z < INF:
		var progress: float = clampf(float(_frame) / float(_opt("sweep-frames", "30")), 0.0, 1.0)
		var reach: float = float(_opt("sweep", "0"))
		MarketPeople.set_runner(Vector3(0.0, 1.0, _look_z + reach * (1.0 - 2.0 * progress)))
	if _frame % _hold == 2 and (_flag("cheer") or _flag("flinch")):
		MarketPeople.react(&"startled" if _flag("flinch") else &"cheer")


func _fire_cheer() -> void:
	print("cheer at %.1f s, runner at %.1f m" % [elapsed, distance])
	get_tree().call_group(&"market_citizens", &"react", &"cheer")


func _place_game_camera() -> void:
	camera.position = Vector3(0.0, tuning.camera_height, -(distance - tuning.camera_distance))
	camera.look_at(Vector3(0.0, 1.0, -(distance + tuning.camera_look_ahead)))


## Where the citizens are now (the cards: each its own node in the group; the people: each crowd node's spots).
func _print_citizens() -> void:
	for n: Node in get_tree().get_nodes_in_group(&"market_citizens"):
		if n.has_method(&"spots"):
			for p: Vector3 in n.call(&"spots"):
				print("citizen at %.1f m, side %d" % [-p.z, int(signf(p.x))])
		elif n is Node3D:
			var p: Vector3 = (n as Node3D).global_position
			print("citizen at %.1f m, side %d" % [-p.z, int(signf(p.x))])


func _citizen_spots() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for n: Node in get_tree().get_nodes_in_group(&"market_citizens"):
		if n.has_method(&"spots"):
			for p: Vector3 in n.call(&"spots"):
				out.append(p)
		elif n is Node3D:
			out.append((n as Node3D).global_position)
	return out


func _shot_list() -> Array:
	var geo := TrackGeometry.new(lanes, tuning)
	var w: float = geo.wall_x()
	var out: Array = []
	var spots: Array[Vector3] = _citizen_spots()
	spots.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.z > b.z)
	var shown: int = 0
	for p: Vector3 in spots:
		if shown >= 3 or -p.z < 30.0:
			continue
		shown += 1
		var side: float = signf(p.x)
		var at: float = -p.z
		var eye := Vector3(p.x - side * 2.6, 1.7, p.z + 2.4)
		var look := Vector3(p.x, 1.2, p.z)
		match _opt("focus", "full"):
			"feet":
				eye = Vector3(p.x - side * 1.5, p.y + 0.3, p.z + 1.1)
				look = Vector3(p.x, p.y + 0.2, p.z)
			"head":
				eye = Vector3(p.x - side * 1.5, p.y + 1.55, p.z + 1.1)
				look = Vector3(p.x, p.y + 1.45, p.z)
		out.append([at, eye, look, "citizen %d close, from the lane beside it (%.1f m)" % [shown, at]])
		out.append([at, Vector3(0.0, tuning.camera_height, -(at - 14.0)), Vector3(p.x, 1.3, p.z),
			"citizen %d from the game camera 14 m before" % shown])
		out.append([at, Vector3(0.0, tuning.camera_height, -(at - 7.0)), Vector3(p.x, 1.3, p.z),
			"citizen %d from the game camera 7 m before" % shown])
	var display: Dictionary = {}
	for side: int in [1, -1]:
		for found: Dictionary in skin.call(&"shop_windows", side, side * w, 40.0, LENGTH - 60.0):
			if found.get("screen", false) and (display.is_empty() or float(found["at"]) < float(display["at"])):
				display = found
	if not display.is_empty():
		var c: Vector3 = display["center"]
		var side: float = float(display["side"])
		var inside := Vector3(c.x + side * 0.45, 1.55, c.z)
		out.append([float(display["at"]), Vector3(c.x - side * 2.6, 1.9, c.z + 2.2), inside,
			"the nearest window with an ad screen or a poster, close up"])
		out.append([float(display["at"]), Vector3(0.0, tuning.camera_height, c.z + 14.0), inside,
			"that window from the game camera"])
	return out


func _show_shot(index: int) -> void:
	var shot: Array = _shots[index]
	track.set_layout(layout, tuning, skin)
	track.update(float(shot[0]), float(shot[0]) / tuning.run_speed)
	camera.position = shot[1]
	camera.look_at(shot[2])
	_look_z = (shot[2] as Vector3).z
	# The runner is where the game camera would have them (a still shot has no runner: they are a few metres before the
	# camera), so the people's heads turn toward the camera.
	MarketPeople.set_runner(Vector3(camera.position.x, 1.0, camera.position.z - tuning.camera_distance))
	print("shot %d at frame %d: %s" % [index, _frame, String(shot[3])])


static func _opt(opt_name: String, default: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % opt_name):
			return arg.get_slice("=", 1)
	return default


static func _flag(opt_name: String) -> bool:
	return OS.get_cmdline_user_args().has("--%s" % opt_name)

extends Node3D
## Gameplay review for ramps and blocked wall entries (GDD §3): a real RunWorld on a hand-built track,
## driven with press() like the tests' RunSim, seen through the game's camera (RunCamera).
## - ramp: the runner rides a ramp onto the right wall, with its fading speed boost and the credits the
##   generator puts along its wall run (LevelGenerator.wall_run_credits), and drops back into the lane.
## - blocked: on the left, a sign that reaches the floor blocks the wall: the clank and the bump,
##   stopped at the sign's face; the runner jumps right after and takes the wall past the sign. Then
##   on the right a high sign blocks it: the bump's full reach.
##
##   Render:  godot --path . --write-movie build/review/f.png --fixed-fps 30 --quit-after 240
##            res://tools/showcase/ramp_wall_review.tscn -- [options]
##   Options (after --):
##     --case=ramp|blocked   one part only, starting just before it (default: both, ramp first)
##     --skin=<zone id>      the zone's look (data/skins/<id>_skin.tres; default city)
##     --lanes=N             lane count (default 3)
##     --close               a close camera that stays over the lane, so the bump shows against it
##     --reduced-flashing    Settings' Reduced flashing on (hazard warnings hold steady)
## Each scripted action and movement event is printed with its time and distance, to find the frames
## (frame = time × render fps).

const TUNING_PATH: String = "res://data/tuning/movement.tres"
const RULES_PATH: String = "res://data/tuning/game_rules.tres"

var tuning: MovementTuning
var world: RunWorld
var camera: Camera3D
var lanes: int = 3
var close: bool = false
var _pending: Array = []


func _ready() -> void:
	tuning = load(TUNING_PATH) as MovementTuning
	var skin_id: String = "city"
	var case: String = ""
	var reduced: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):
			case = arg.get_slice("=", 1)
		elif arg.begins_with("--skin="):
			skin_id = arg.get_slice("=", 1)
		elif arg.begins_with("--lanes="):
			lanes = clampi(int(arg.get_slice("=", 1)), 3, 8)
		elif arg == "--close":
			close = true
		elif arg == "--reduced-flashing":
			reduced = true
	var skin: ZoneSkin = GreyboxSkin.new()
	var skin_path: String = "res://data/skins/%s_skin.tres" % skin_id
	if ResourceLoader.exists(skin_path):
		skin = load(skin_path) as ZoneSkin
	else:
		push_warning("ramp_wall_review: no skin at %s; using the grey box" % skin_path)
	RenderingServer.global_shader_parameter_set(&"reduced_flashing", 1.0 if reduced else 0.0)

	var layout := LevelLayout.new()
	layout.lane_count = lanes
	var start_lane: int = lanes - 1
	var at: float = 0.0
	if case != "blocked":
		at = _add_ramp(layout, at)
	else:
		start_lane = 0
	if case != "ramp":
		at = _add_blocked(layout, at)
	layout.length = at + 40.0

	var config := LevelConfig.new()
	config.lane_count = lanes
	config.skin = skin
	var sfx := load("res://data/audio/sfx_library.tres") as SfxLibrary
	world = RunWorld.new()
	add_child(world)
	world.build(config, layout, tuning, load(RULES_PATH) as GameRules, null, null, sfx)
	world.player.setup(tuning, world.geo, start_lane)
	world.player.steady_flash = reduced
	world.player.movement_event.connect(func(kind: StringName) -> void:
		print("%5.2f s  %6.1f m  %s" % [world.player.elapsed, world.player.distance, kind]))

	var env := WorldEnvironment.new()
	env.environment = skin.make_environment()
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
	sun.light_energy = 0.7
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)
	if close:
		camera = Camera3D.new()
		camera.fov = 55.0
		add_child(camera)
		_update_close_camera()
	else:
		var run_camera := RunCamera.new()
		add_child(run_camera)
		run_camera.follow(world)
		camera = run_camera
	camera.make_current()
	world.start()


## The ramp: in the right outer lane, 30 m in, with the credits along its wall run; then across to the
## left outer lane once the runner is back on the floor. Returns where the next part may start.
func _add_ramp(layout: LevelLayout, at: float) -> float:
	var ramp := {"side": 1, "at": at + 30.0}
	layout.ramps.append(ramp)
	layout.credits.append_array(LevelGenerator.wall_run_credits(layout, ramp, tuning, tuning.run_speed))
	var launch := RampLaunch.of(ramp, tuning, tuning.run_speed)
	print("ramp at %.1f m: launch %.1f m, on the wall at %.1f m, drops at %.1f m (%.1f m of wall run)"
		% [ramp["at"], launch.start, launch.wall_reached(), launch.end(), launch.end() - launch.start])
	var back: float = launch.end() + 8.0
	for i: int in lanes - 1:
		_pending.append([back + i * 5.0, &"move_left"])
	return back + (lanes - 1) * 5.0 + 6.0


## A sign down to the floor on the left wall: pressing into it clanks and bumps; a jump right after;
## then the left wall past the sign. Back across to the right, a high sign there: the full bump.
func _add_blocked(layout: LevelLayout, at: float) -> float:
	var low := at + 20.0
	layout.signs.append({"side": -1, "start": low, "end": low + 16.0, "bottom": 0.0, "top": 2.3})
	_pending.append([low + 5.0, &"move_left"])
	_pending.append([low + 9.0, &"jump"])
	_pending.append([low + 23.0, &"move_left"])
	var back: float = low + 23.0 + tuning.run_speed * (tuning.wall_entry_time + tuning.wall_slide_time) + 6.0
	for i: int in lanes - 1:
		_pending.append([back + i * 5.0, &"move_right"])
	var high: float = back + (lanes - 1) * 5.0 + 12.0
	layout.signs.append({"side": 1, "start": high, "end": high + 16.0, "bottom": 2.8, "top": 5.5})
	_pending.append([high + 5.0, &"move_right"])
	return high + 30.0


func _physics_process(_delta: float) -> void:
	var player: Player = world.player
	while not _pending.is_empty() and player.distance >= float(_pending[0][0]):
		var action: StringName = _pending.pop_front()[1]
		print("%5.2f s  %6.1f m  > %s" % [player.elapsed, player.distance, action])
		player.press(action)


func _process(_delta: float) -> void:
	if close:
		_update_close_camera()


## Low behind the runner and over the middle of its lane (it doesn't follow the runner sideways), so
## a bump moves the runner against the frame and the sign beside it.
func _update_close_camera() -> void:
	var p: Player = world.player
	var x: float = world.geo.lane_x(p.lane) * 0.85
	camera.position = Vector3(x, 1.9, p.position.z + 4.2)
	camera.look_at(Vector3(x, 1.0, p.position.z - 6.0))

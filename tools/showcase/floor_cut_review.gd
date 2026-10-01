extends Node3D
## Gameplay review for floors that turn into gaps during play (task B4; GDD §9.9): a real RunWorld on a
## hand-built track with one floor cut and its cause (the floor cutter stand-in, until task C2's Buzz
## Overdrive), driven with press() like the tests' RunSim, seen through the game's camera (RunCamera)
## or a high one over the cut.
## The runner starts in the cut's lane, sees the warning (the red line and the rev), switches to the
## lane beside it and runs on alongside: the cutter charges back down its lane, the floor behind it
## goes, it passes, and the gap it leaves runs on ahead beside the runner. A normal hole further on in
## the cut's lane shows the zone's own gap beside the cut's.
##
##   Render:  godot --path . --write-movie build/review/f.png --fixed-fps 10 --quit-after 120
##            res://tools/showcase/floor_cut_review.tscn -- [options]
##   Options (after --):
##     --skin=<zone id>      the zone's look (data/skins/<id>_skin.tres; default city; corporate_plaza
##                           for the plaza)
##     --lanes=N             lane count (default 3)
##     --lane=N              the cut's lane (default the middle one)
##     --side=-1|1           the lane the runner escapes to (default: toward the track's middle)
##     --speed=N             the run speed (a zone's: 21 m/s in the City to 25 in the Golden Zone;
##                           default the base 18); the cut keeps its timing in seconds
##     --high                a camera high behind the runner, looking down the cut
##     --stay                the runner stays in the cut's lane: its armor blocks the blade, the floor
##                           holds for a second, then it switches out
##     --kill=D              the cutter is killed when the runner reaches distance D: the cut stops there
##     --reduced-flashing    Reduced flashing on (the line holds steady, no sparks)
## Each scripted action and movement event is printed with its time and distance, and the cut's
## warning, charge, meeting point and end, to find the frames (frame = time × render fps).

const TUNING_PATH: String = "res://data/tuning/movement.tres"
const RULES_PATH: String = "res://data/tuning/game_rules.tres"
const Rules = preload("res://scripts/enemies/floor_cutter_rules.gd")

var tuning: MovementTuning
var world: RunWorld
var camera: Camera3D
var high: bool = false
var cut: Dictionary = {}
var _pending: Array = []
var _kill_at: float = INF


func _ready() -> void:
	tuning = load(TUNING_PATH) as MovementTuning
	var skin_id: String = "city"
	var lanes: int = 3
	var lane: int = -1
	var side: int = 0
	var stay: bool = false
	for arg: String in OS.get_cmdline_user_args():
		var v: String = arg.get_slice("=", 1)
		if arg.begins_with("--skin="):
			skin_id = v
		elif arg.begins_with("--lanes="):
			lanes = clampi(int(v), 3, 8)
		elif arg.begins_with("--lane="):
			lane = int(v)
		elif arg.begins_with("--side="):
			side = signi(int(v))
		elif arg.begins_with("--speed="):
			tuning = tuning.duplicate() as MovementTuning
			tuning.run_speed = maxf(float(v), 5.0)
		elif arg == "--high":
			high = true
		elif arg == "--stay":
			stay = true
		elif arg.begins_with("--kill="):
			_kill_at = float(v)
		elif arg == "--reduced-flashing":
			Settings.flashing_reduced = true
			RenderingServer.global_shader_parameter_set(&"reduced_flashing", 1.0)
	if lane < 0 or lane >= lanes:
		lane = lanes / 2
	if side == 0:
		side = 1 if lane < lanes / 2 else -1
	if lane + side < 0 or lane + side >= lanes:
		side = -side
	var skin: ZoneSkin = GreyboxSkin.new()
	var skin_path: String = "res://data/skins/%s_skin.tres" % skin_id
	if ResourceLoader.exists(skin_path):
		skin = load(skin_path) as ZoneSkin
	else:
		push_warning("floor_cut_review: no skin at %s; using the grey box" % skin_path)

	var t: FloorCutterTuning = Rules.tuning()
	var v: float = tuning.run_speed
	var speed: float = t.charge_speed * tuning.pace()
	var charge: float = t.charge_seconds * (v + speed)
	var warn: float = charge + t.warn_seconds * v
	var end: float = 60.0 + warn
	cut = FloorCutPlan.make(lane, end, warn, charge, speed, v, t.run_past, t.keep())
	var layout := LevelLayout.new()
	layout.lane_count = lanes
	layout.cuts.append(cut)
	layout.enemies.append({"type": "floor_cutter", "at": end, "lane": lane, "side": 0, "seed": 1, "params": {}})
	# A normal hole further on in the cut's lane, to compare the zone's gap with the cut's.
	layout.gaps.append({"lane": lane, "start": end + 40.0, "end": end + 46.0})
	layout.length = end + 220.0
	var meet: float = FloorCutPlan.meet(cut, v)
	print("cut in lane %d: %.1f-%.1f m; warning at %.1f m (%.2f s), charge at %.1f m (%.2f s), meets the runner at %.1f m (%.2f s), ends with the runner at %.1f m (%.2f s)" % [
		lane, cut["start"], end, FloorCutPlan.warn_at(cut), FloorCutPlan.warn_at(cut) / v, FloorCutPlan.charge_at(cut),
		FloorCutPlan.charge_at(cut) / v, meet, meet / v, FloorCutPlan.done_at(cut, v), FloorCutPlan.done_at(cut, v) / v])

	var config := LevelConfig.new()
	config.lane_count = lanes
	config.skin = skin
	var sfx := load("res://data/audio/sfx_library.tres") as SfxLibrary
	var loadout := Loadout.new()
	world = RunWorld.new()
	add_child(world)
	world.build(config, layout, tuning, load(RULES_PATH) as GameRules, null, loadout, sfx)
	world.player.setup(tuning, world.geo, lane)
	if stay:
		world.player.armor = 1
		_pending.append([meet + 3.0, &"move_left" if side < 0 else &"move_right"])
	else:
		_pending.append([FloorCutPlan.warn_at(cut) + 10.0, &"move_left" if side < 0 else &"move_right"])
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
	if high:
		camera = Camera3D.new()
		camera.fov = 62.0
		add_child(camera)
		_update_high_camera()
	else:
		var run_camera := RunCamera.new()
		add_child(run_camera)
		run_camera.follow(world)
		camera = run_camera
	camera.make_current()
	world.start()


func _physics_process(_delta: float) -> void:
	var player: Player = world.player
	while not _pending.is_empty() and player.distance >= float(_pending[0][0]):
		var action: StringName = _pending.pop_front()[1]
		print("%5.2f s  %6.1f m  > %s" % [player.elapsed, player.distance, action])
		player.press(action)
	if player.distance >= _kill_at:
		_kill_at = INF
		for e: Enemy in world.director.active:
			if is_instance_valid(e) and e.alive and e.type_id == &"floor_cutter":
				print("%5.2f s  %6.1f m  > the cutter is killed" % [player.elapsed, player.distance])
				e.defeat(&"weapon")


func _process(_delta: float) -> void:
	if high:
		_update_high_camera()


## High behind the runner and over the cut's lane, looking down the track: the cut's whole stretch.
func _update_high_camera() -> void:
	var p: Player = world.player
	var x: float = world.geo.lane_x(int(cut["lane"]))
	camera.position = Vector3(x * 0.6, 9.0, p.position.z + 9.0)
	camera.look_at(Vector3(x, 0.0, p.position.z - 22.0))

extends Node3D
## Gameplay review for zone doodads (GDD §3, owner's playtest September 30, 2026; task G5): a real
## RunWorld on a hand-built track, driven with press() like the tests' RunSim, seen through the game's
## camera (RunCamera) or a close one.
## The runner keeps to the middle lane: head-on into a small doodad that pushes it right (with the
## thud), back to the middle, into a medium one that pushes it left, back again, and into a large one
## pushing right, alongside which a lane switch into its side clanks and bumps. With five lanes or more,
## others stand in the other inner lanes, seen coming alongside.
##
##   Render:  godot --path . --write-movie build/review/f.png --fixed-fps 30 --quit-after 150
##            res://tools/showcase/doodad_review.tscn -- [options]
##   Options (after --):
##     --skin=<zone id>      the zone's look (data/skins/<id>_skin.tres; default city)
##     --lanes=N             lane count (default 3)
##     --close               a close camera low behind the runner, over its lane
##     --hitboxes            show the doodads' bodies (the hitbox view)
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
	var hitboxes: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--skin="):
			skin_id = arg.get_slice("=", 1)
		elif arg.begins_with("--lanes="):
			lanes = clampi(int(arg.get_slice("=", 1)), 3, 8)
		elif arg == "--close":
			close = true
		elif arg == "--hitboxes":
			hitboxes = true
	var skin: ZoneSkin = GreyboxSkin.new()
	var skin_path: String = "res://data/skins/%s_skin.tres" % skin_id
	if ResourceLoader.exists(skin_path):
		skin = load(skin_path) as ZoneSkin
	else:
		push_warning("doodad_review: no skin at %s; using the grey box" % skin_path)

	var layout := LevelLayout.new()
	layout.lane_count = lanes
	var mid: int = lanes / 2
	# Head-on into a small one that pushes right, back to the middle, into a medium one that pushes
	# left, back again, then into a large one pushing right: alongside it, a move into its side.
	var at: float = 60.0
	var plan: Array[Array] = [[&"small", 1], [&"medium", -1], [&"large", 1]]
	for i: int in plan.size():
		var d: Dictionary = _add(layout, mid, at, plan[i][0], plan[i][1])
		var back: StringName = &"move_left" if int(plan[i][1]) > 0 else &"move_right"
		if i < plan.size() - 1:
			_pending.append([float(d["end"]) + 8.0, back])
		else:
			_pending.append([float(d["end"]) - 3.0, back])
		# Others in the other inner lanes, seen coming alongside (five lanes or more).
		for lane: int in range(1, lanes - 1):
			if lane != mid:
				_add(layout, lane, at + 18.0 + 6.0 * lane, LevelLayout.DOODAD_SIZES[(i + lane) % 3], 1 if lane < mid else -1)
		at = float(d["end"]) + 45.0
	layout.length = at + 80.0

	var config := LevelConfig.new()
	config.lane_count = lanes
	config.skin = skin
	var sfx := load("res://data/audio/sfx_library.tres") as SfxLibrary
	world = RunWorld.new()
	add_child(world)
	world.build(config, layout, tuning, load(RULES_PATH) as GameRules, null, null, sfx)
	world.player.setup(tuning, world.geo, mid)
	world.track.set_hitboxes_visible(hitboxes)
	world.player.movement_event.connect(func(kind: StringName) -> void:
		print("%5.2f s  %6.1f m  %s" % [world.player.elapsed, world.player.distance, kind]))
	for d: Dictionary in layout.doodads:
		print("doodad %-6s lane %d  %5.1f–%5.1f m  pushes %s" % [d["size"], d["lane"], d["start"], d["end"],
			"right" if int(d["side"]) > 0 else "left"])

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
		camera.fov = 60.0
		add_child(camera)
		_update_close_camera()
	else:
		var run_camera := RunCamera.new()
		add_child(run_camera)
		run_camera.follow(world)
		camera = run_camera
	camera.make_current()
	world.start()


func _add(layout: LevelLayout, lane: int, start: float, size: StringName, side: int) -> Dictionary:
	var d := {"lane": lane, "start": start, "end": start + tuning.doodad_size(size).z, "size": size, "side": side,
		"seed": layout.doodads.size()}
	layout.doodads.append(d)
	return d


func _physics_process(_delta: float) -> void:
	var player: Player = world.player
	while not _pending.is_empty() and player.distance >= float(_pending[0][0]):
		var action: StringName = _pending.pop_front()[1]
		print("%5.2f s  %6.1f m  > %s" % [player.elapsed, player.distance, action])
		player.press(action)


func _process(_delta: float) -> void:
	if close:
		_update_close_camera()


## Low behind the runner (above the doodads) and over the middle of the track, so a push moves the
## runner across the frame.
func _update_close_camera() -> void:
	var p: Player = world.player
	camera.position = Vector3(0.0, 3.4, p.position.z + 6.5)
	camera.look_at(Vector3(0.0, 1.2, p.position.z - 8.0))

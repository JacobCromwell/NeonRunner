extends Node3D
## Visual review of the Cybernetic Centipede (task O3; GDD §9.15): its model up close in each of its looks, or a scripted
## encounter in a hand-made block of the debris maze (MazeKit) in a real RunWorld on the Terminal's skin, seen through the
## game's camera (RunCamera), a camera high behind the runner, or one low beside the maze.
## The encounter: the runner comes in through the block's first wall in the middle lane; the centipede waits ahead in the
## same lane, wakes (the hiss), rears and comes at them; with --dash the runner dashes through it head-on (it's wounded:
## the cracked tube, the leak, sparks) and it turns and chases from behind; the runner stops at the closed wall at the
## room's end and it catches them up and bites (its head rearing, its jaws open and glowing red first); after its second
## bite the runner dashes on through the wall (meeting its jaws, the dash's second contact kills it). God mode keeps the
## run going (the bites land on nothing).
##
##   Render:  godot --path . --resolution 960x540 --fixed-fps 10 --write-movie build/centipede/f.png --quit-after 120
##            res://tools/showcase/centipede_showcase.tscn -- [options]
##   (add --rendering-method gl_compatibility before the scene path for the web / low-end renderer)
##   Options (after --):
##     --scenario=chase|model  the scripted encounter (default), or the model up close
##     --pose=walk|sleep|wake|bite|wounded   the model's pose (default walk: its legs stepping along a curving trail)
##     --angle=D               the model's camera fixed D degrees round from in front of its head (default: circling)
##     --near                  the model's camera close on its head (on its cracked canister, wounded)
##     --skin=<zone id>        the look (data/skins/<id>_skin.tres; default terminal)
##     --lanes=N               lane count (default 5)
##     --dash=M                the runner dashes this many metres before the centipede's spot (default 12; 0: never)
##     --high                  a camera high behind the runner
##     --side                  a camera low beside the maze, level with the centipede
##     --reduced-flashing      Reduced flashing on (no sparks from its wound)
## The run prints the centipede's states and the runner's events with their times, to find the frames (frame = time ×
## render fps).

const TUNING_PATH: String = "res://data/tuning/movement.tres"
const RULES_PATH: String = "res://data/tuning/game_rules.tres"
## The Terminal's run speed (ZoneDef.run_speed).
const SPEED: float = 24.6

var tuning: MovementTuning
var world: RunWorld
var camera: Camera3D
var mode: String = "game"
var pose: String = "walk"
## The model's camera angle (radians round from in front of its head), or NAN to circle.
var angle: float = NAN
var near: bool = false
var centipede: Centipede
var _model: CentipedeModel
var _t: float = 0.0
var _pending: Array = []
var _last: String = ""
var _spot := Vector2.ZERO
var _found: bool = false


func _ready() -> void:
	tuning = load(TUNING_PATH) as MovementTuning
	var scenario: String = "chase"
	var skin_id: String = "terminal"
	var lanes: int = 5
	var dash: float = 12.0
	for arg: String in OS.get_cmdline_user_args():
		var v: String = arg.get_slice("=", 1)
		if arg.begins_with("--scenario="):
			scenario = v
		elif arg.begins_with("--pose="):
			pose = v
		elif arg.begins_with("--angle="):
			angle = deg_to_rad(float(v))
		elif arg == "--near":
			near = true
		elif arg.begins_with("--skin="):
			skin_id = v
		elif arg.begins_with("--lanes="):
			lanes = clampi(int(v), 3, 8)
		elif arg.begins_with("--dash="):
			dash = float(v)
		elif arg == "--high":
			mode = "high"
		elif arg == "--side":
			mode = "side"
		elif arg == "--reduced-flashing":
			Settings.flashing_reduced = true
			RenderingServer.global_shader_parameter_set(&"reduced_flashing", 1.0)
	var skin: ZoneSkin = GreyboxSkin.new()
	var path: String = "res://data/skins/%s_skin.tres" % skin_id
	if ResourceLoader.exists(path):
		skin = load(path) as ZoneSkin
	tuning = tuning.duplicate() as MovementTuning
	tuning.run_speed = SPEED
	var env := WorldEnvironment.new()
	env.environment = skin.make_environment()
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
	sun.light_energy = 0.7
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)
	if scenario == "model":
		_build_model(skin)
		return
	var mid: int = lanes / 2
	var layout: LevelLayout = MazeKit.block(tuning, lanes, [[mid], [], [mid]], [[], [maxi(mid - 2, 0), mini(mid + 2, lanes - 1)]],
		{"entry": 80.0, "room": 34.0})
	var b: Dictionary = layout.maze[0]
	var room: Dictionary = (b["rooms"] as Array)[0]
	var at: float = float(room["start"]) + 22.0
	_spot = Vector2(0.0, at)
	layout.enemies.append(MazeKit.centipede(at, mid))
	var config := LevelConfig.new()
	config.lane_count = lanes
	config.skin = skin
	config.doodads_stop = true
	config.wall_running = false
	world = RunWorld.new()
	add_child(world)
	world.build(config, layout, tuning, load(RULES_PATH) as GameRules, load("res://data/tuning/powerups.tres") as PowerupTuning,
		Loadout.new(), load("res://data/audio/sfx_library.tres") as SfxLibrary)
	world.player.setup(tuning, world.geo, mid)
	world.player.distance = float(b["entry"]) - 30.0
	world.player.god_mode = true
	if dash > 0.0:
		_pending.append([at - dash, &"dash"])
	# Through the closed wall at the room's end once it has bitten (well after the first dash's recharge).
	_pending.append([float((b["walls"] as Array)[1]["start"]) - 1.0, &"dash_later"])
	world.player.movement_event.connect(func(kind: StringName) -> void:
		print("%5.2f s  %6.1f m  %s" % [world.player.elapsed, world.player.distance, kind]))
	if mode == "game":
		var run_camera := RunCamera.new()
		add_child(run_camera)
		run_camera.follow(world)
		camera = run_camera
	else:
		camera = Camera3D.new()
		camera.fov = 60.0
		add_child(camera)
	camera.make_current()
	world.start()


func _physics_process(_delta: float) -> void:
	if world == null:
		return
	var p: Player = world.player
	while not _pending.is_empty() and p.distance >= float(_pending[0][0]):
		var action: StringName = _pending[0][1]
		if action == &"dash_later":
			# At the closed wall: once it has bitten twice (god mode: the bites show but nothing applies), dash on through.
			if not _found or not is_instance_valid(centipede) or _live_bites() < 2:
				break
			action = &"dash"
		_pending.pop_front()
		print("%5.2f s  %6.1f m  > %s" % [p.elapsed, p.distance, action])
		RunSim.act(p, action)
	if not _found:
		for e: Enemy in world.director.active:
			if is_instance_valid(e) and e is Centipede:
				centipede = e
				_found = true
	if _found and is_instance_valid(centipede):
		var state: String = "%s jaw %d" % [Centipede.STATE_NAMES[centipede.state], centipede.jaw]
		if state != _last:
			_last = state
			print("%5.2f s  %6.1f m  the centipede: %s (head %.1f m, wounds %d)" % [p.elapsed, p.distance, state,
				centipede.head().y, centipede.dash_wounds])


## The centipede's bites that have gone live (struck).
func _live_bites() -> int:
	var n: int = 0
	for bite: Array in centipede.bites:
		if float(bite[1]) >= 0.0:
			n += 1
	return n


func _process(delta: float) -> void:
	_t += delta
	if _model != null:
		_animate_model(delta)
	elif world != null and mode != "game":
		var p: Player = world.player
		if mode == "high":
			camera.position = Vector3(0.0, 10.0, p.position.z + 10.0)
			camera.look_at(Vector3(0.0, 0.0, p.position.z - 22.0))
		else:
			var x: float = world.geo.half_width() + 3.0
			var z: float = TrackGeometry.world_z(_spot.y)
			camera.position = Vector3(x, 2.2, z + 6.0)
			camera.look_at(Vector3(0.0, 0.6, z - 2.0))


## The model on a dark floor in the zone's light, posed (see the header), a camera circling it slowly.
func _build_model(skin: ZoneSkin) -> void:
	_model = CentipedeModel.new()
	add_child(_model)
	_model.build(skin.enemy_variant if skin != null else &"city", Centipede.SEGMENTS, false)
	_model.set_awake(pose != "sleep")
	if pose == "wounded":
		_model.set_wounded(true, Settings.flashing_reduced)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(16.0, 16.0)
	floor_mesh.mesh = plane
	floor_mesh.material_override = GreyboxMaterials.flat(Color(0.12, 0.12, 0.13))
	add_child(floor_mesh)
	camera = Camera3D.new()
	camera.fov = 40.0
	add_child(camera)
	camera.make_current()


func _animate_model(delta: float) -> void:
	# Its trail: a gentle S-curve back from the head, which crawls along it on the spot (the legs step).
	var segs: Array[Transform3D] = []
	var phase: float = _t * 1.5
	for i: int in Centipede.SEGMENTS:
		var s: float = Centipede.SEGMENT_SPACING * (i + 1)
		var x: float = sin(s * 0.55 + phase * 0.3) * 0.45
		var ahead: float = Centipede.SEGMENT_SPACING * (i + 0.5)
		var xa: float = sin(ahead * 0.55 + phase * 0.3) * 0.45
		var basis := Basis.looking_at(Vector3(xa - x, 0.0, -(ahead - s)).normalized(), Vector3.UP)
		segs.append(Transform3D(basis, Vector3(x, 0.0, -s)))
	# Its head faces +z, away from its body (the model looks along its basis's -z).
	var head := Transform3D(Basis(Vector3.UP, PI), Vector3(sin(phase * 0.3) * 0.45, 0.0, 0.0))
	var rear: float = 0.0
	var open: float = 0.0
	match pose:
		"bite":
			rear = clampf(fmod(_t, 1.6) / 0.6, 0.0, 1.0)
			open = rear
		"wake":
			rear = 0.6
	var moving: float = 1.0 if pose == "walk" or pose == "wounded" else 0.0
	_model.pose(head, segs, _t * 4.0 * moving, moving, rear, open, delta)
	var a: float = 0.6 + _t * 0.25 if is_nan(angle) else angle
	if near and pose == "wounded":
		# Close on its cracked canister.
		var z: float = -Centipede.SEGMENT_SPACING * 4.0
		camera.position = Vector3(sin(a) * 2.4, 2.4, z + cos(a) * 2.4)
		camera.look_at(Vector3(0.0, 1.0, z))
	elif near:
		var head_y: float = Centipede.HEAD_HEIGHT + rear * CentipedeModel.REAR_HEIGHT
		camera.position = Vector3(sin(a) * 3.0, head_y + 1.0, cos(a) * 3.0)
		camera.look_at(Vector3(0.0, head_y - 0.1, -0.4))
	else:
		camera.position = Vector3(sin(a) * 6.5, 2.4, -1.8 + cos(a) * 6.5)
		camera.look_at(Vector3(0.0, 0.6, -2.0))

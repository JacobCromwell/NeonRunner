extends Node3D
## Close-up showcase of the cyborg family and fence generators, for visual review only (not part of
## the game). Render frames of it, e.g. (the Compatibility renderer with --rendering-method
## gl_compatibility before the --):
##   godot --path . --write-movie build/f.png --quit-after 6 res://tools/showcase/enemy_showcase.tscn -- --view=faces
## Views:
##   poses (default)  the pose row: idle, walking, aiming with the cannon charged, the panic variant's
##                    run with its shocked "O", cowering, and a host
##   faces            the screen head close up: calm, aiming, shocked, ERR (defeated) and a host
##   turn             front, side, back and the other side (the backpack, cables and cyber arm)
##   window           window cyborgs on the facade
##   far              gameplay distance: the run camera's view, with every expression and window
##                    cyborgs ahead (the expressions must read here)
##   generator        fence generators in a real RunWorld
##   charge           a cyborg charging its cannon at the camera
##   play             a generated level with the enemies on, run by a god-mode player with grapples (so
##                    gaps don't end the run) through the real run camera (options: --seed=N --lanes=N
##                    --difficulty=X --start=metres --features=a,b --claws); it runs until closed
## Every view takes --skin=res://path/to/skin.tres (default: the grey box) and --variant=<name>, the
## skin's enemy_variant (CyborgSuit.look_for picks the cyborgs' look from it; every name wears the base
## until the zone variants exist).

const Kit = preload("res://scripts/enemies/cyborg_kit.gd")

var _world: RunWorld
var _camera: Camera3D


func _ready() -> void:
	var view: String = "poses"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--view="):
			view = arg.get_slice("=", 1)
	if view == "play":
		_play()
		return
	_world = _build_world(view)
	var variant: StringName = StringName(_opt("variant", "city"))
	_camera = Camera3D.new()
	_camera.fov = 50.0
	add_child(_camera)
	_camera.make_current()
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
	sun.light_energy = 0.7
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = _world.skin.make_environment()
	add_child(env)
	match view:
		"faces":
			_face_row(variant)
			_look(Vector3(0.0, 1.45, 2.3), Vector3(0.0, 1.32, -1.0))
		"turn":
			_turn_row(variant)
			_look(Vector3(0.0, 1.2, 4.0), Vector3(0.0, 0.85, -1.0))
		"window":
			_window_scene()
			_look(Vector3(2.0, 2.3, -6.0), Vector3(4.2, 2.0, -12.0))
		"generator":
			_generator_scene()
			_look(Vector3(-1.5, 2.6, -2.0), Vector3(0.6, 0.4, -14.0))
		"charge":
			_charge_scene()
			_look(Vector3(0.6, 1.4, -2.0), Vector3(0.0, 1.0, -9.0))
		"far":
			_far_scene()
		_:
			_pose_row(variant)
			_look(Vector3(0.0, 1.3, 5.2), Vector3(0.0, 0.8, -1.0))


## The value of a --name=value argument, or `default`.
static func _opt(opt_name: String, default: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % opt_name):
			return arg.get_slice("=", 1)
	return default


## The skin from --skin (default: the grey box), dressed in the --variant enemy look.
static func _skin(variant: StringName) -> ZoneSkin:
	var path: String = _opt("skin", "res://data/skins/greybox_skin.tres")
	var base: ZoneSkin = load(path) as ZoneSkin if ResourceLoader.exists(path) else null
	if base == null:
		base = load("res://data/skins/greybox_skin.tres") as ZoneSkin
	var skin := base.duplicate() as ZoneSkin
	skin.enemy_variant = variant
	return skin


func _play() -> void:
	var config := (load("res://data/levels/prototype_level.tres") as LevelConfig).duplicate() as LevelConfig
	config.features = PackedStringArray(["ceilings", "pulsing", "ramps", "cyborg", "window_cyborg", "generator"])
	config.lane_count = 5
	config.difficulty = 0.6
	var start: float = 0.0
	for arg: String in OS.get_cmdline_user_args():
		var v: String = arg.get_slice("=", 1)
		if arg.begins_with("--seed="):
			config.level_seed = int(v)
		elif arg.begins_with("--lanes="):
			config.lane_count = int(v)
		elif arg.begins_with("--difficulty="):
			config.difficulty = float(v)
		elif arg.begins_with("--start="):
			start = float(v)
		elif arg.begins_with("--features="):
			config.features = PackedStringArray(v.split(",", false))
	config.skin = _skin(StringName(_opt("variant", "city")))
	var t := load("res://data/tuning/movement.tres") as MovementTuning
	var layout: LevelLayout = LevelGenerator.new().generate(config, t, LevelGenerator.load_for(config))
	for e: Dictionary in layout.enemies:
		print("enemy %s at %.0f lane %d side %d %s" % [e["type"], e["at"], e["lane"], e["side"], str(e["params"])])
	var loadout := Loadout.new()
	loadout.charges[&"grapple"] = 999
	if OS.get_cmdline_user_args().has("--claws"):
		loadout.tiers[&"claws"] = 1
	_world = RunWorld.new()
	add_child(_world)
	_world.build(config, layout, t, load("res://data/tuning/game_rules.tres") as GameRules,
		load("res://data/tuning/powerups.tres") as PowerupTuning, loadout)
	_world.player.god_mode = true
	_world.player.distance = start
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
	sun.light_energy = 0.7
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = _world.skin.make_environment()
	add_child(env)
	var cam := RunCamera.new()
	add_child(cam)
	cam.make_current()
	cam.follow(_world)
	_world.start()


func _build_world(view: String) -> RunWorld:
	var layout := LevelLayout.new()
	layout.lane_count = 5
	layout.length = 400.0
	if view == "generator":
		for lane: int in 5:
			if lane != 3:
				layout.fences.append({"lane": lane, "at": 20.0, "variant": "full", "pulsing": false,
					"pulse_on": 1.0, "pulse_off": 1.0, "phase": 0.0})
		for lane: int in 5:
			layout.fences.append({"lane": lane, "at": 69.0, "variant": "gapped", "pulsing": false,
				"pulse_on": 1.0, "pulse_off": 1.0, "phase": 0.0})
	var config := LevelConfig.new()
	config.lane_count = 5
	config.skin = _skin(StringName(_opt("variant", "city")))
	var world := RunWorld.new()
	add_child(world)
	world.build(config, layout, load("res://data/tuning/movement.tres") as MovementTuning,
		load("res://data/tuning/game_rules.tres") as GameRules, load("res://data/tuning/powerups.tres") as PowerupTuning)
	world.player.visible = view == "window" or view == "generator"
	return world


func _look(from: Vector3, to: Vector3) -> void:
	_camera.position = from
	_camera.look_at(to)


func _body(v: StringName, host: bool, pos: Vector3, seed_value: int) -> CyborgBody:
	var b := CyborgBody.new()
	add_child(b)
	b.build(v, host, false, seed_value)
	b.position = pos
	return b


## Idle, walk, aim (charged), panic run, cower, host.
func _pose_row(v: StringName) -> void:
	var xs: Array[float] = [-3.0, -1.8, -0.6, 0.6, 1.8, 3.0]
	var idle := _body(v, false, Vector3(xs[0], 0.0, 0.0), 1)
	idle.set_pose(CyborgBody.Pose.IDLE)
	var walk := _body(v, false, Vector3(xs[1], 0.0, 0.0), 2)
	walk.set_pose(CyborgBody.Pose.WALK)
	walk.set_move_speed(1.4)
	var aim := _body(v, false, Vector3(xs[2], 0.0, 0.0), 3)
	aim.set_pose(CyborgBody.Pose.AIM)
	aim.aim_at(Vector3(xs[2] + 0.8, 0.8, 8.0))
	aim.set_charge(1.0)
	aim.set_expression(Kit.Face.AIMING)
	var run := _body(v, false, Vector3(xs[3], 0.0, 0.0), 4)
	run.rotation.y = PI * 0.8
	run.set_pose(CyborgBody.Pose.RUN_AWAY)
	run.set_move_speed(8.5)
	run.aim_at(Vector3(xs[3], 0.8, 8.0))
	run.set_charge(0.6)
	run.set_expression(Kit.Face.SHOCKED)
	var cower := _body(v, false, Vector3(xs[4], 0.0, 0.0), 5)
	cower.set_pose(CyborgBody.Pose.COWER)
	cower.set_expression(Kit.Face.SHOCKED)
	var host := _body(v, true, Vector3(xs[5], 0.0, 0.0), 6)
	host.set_pose(CyborgBody.Pose.IDLE)


## Calm, aiming, shocked, ERR (a defeated cyborg's screen before it goes dark) and a host.
func _face_row(v: StringName) -> void:
	var faces: Array = [Kit.Face.NEUTRAL, Kit.Face.AIMING, Kit.Face.SHOCKED, Kit.Face.DEAD]
	for i: int in faces.size():
		var b := _body(v, false, Vector3(-1.1 + i * 0.55, 0.0, 0.0), 10 + i)
		b.set_expression(faces[i])
	var h := _body(v, true, Vector3(1.1, 0.0, 0.0), 21)
	h.set_expression(Kit.Face.NEUTRAL)


## The same cyborg from the front, its right side, the back and its left side.
func _turn_row(v: StringName) -> void:
	for i: int in 4:
		var b := _body(v, false, Vector3(-1.8 + i * 1.2, 0.0, 0.0), 40)
		b.rotation.y = -PI * 0.5 * i


func _window_scene() -> void:
	for spec: Array in [[1, 12.0, 1], [-1, 20.0, 2], [1, 30.0, 3]]:
		_world.director.spawn({"type": "window_cyborg", "at": spec[1], "lane": 4 if spec[0] > 0 else 0,
			"side": spec[0], "seed": spec[2], "params": {}})


func _generator_scene() -> void:
	_world.director.spawn({"type": "generator", "at": 11.0, "lane": 1, "side": 0, "seed": 1, "params": {}})
	var dead: Enemy = _world.director.spawn({"type": "generator", "at": 60.0, "lane": 3, "side": 0, "seed": 2, "params": {}})
	dead.defeat(&"dash")


## Gameplay distance: the run camera's view from a player at the start (behind and above, as
## MovementTuning places it), with cyborgs ahead showing each expression and window cyborgs on the walls.
func _far_scene() -> void:
	var t := load("res://data/tuning/movement.tres") as MovementTuning
	_world.player.visible = true
	_camera.fov = t.camera_fov
	_look(Vector3(0.0, t.camera_height, t.camera_distance), Vector3(0.0, 1.0, -t.camera_look_ahead))
	var v: StringName = StringName(_opt("variant", "city"))
	var specs: Array = [[12.0, 1, Kit.Face.NEUTRAL, false], [18.0, 3, Kit.Face.SHOCKED, false],
		[26.0, 2, Kit.Face.AIMING, false], [34.0, 4, Kit.Face.NEUTRAL, true], [44.0, 0, Kit.Face.SHOCKED, false]]
	for spec: Array in specs:
		var b := _body(v, spec[3], _world.lane_point(spec[1], spec[0]), 30 + int(spec[0]))
		b.set_expression(spec[2])
		if spec[2] == Kit.Face.AIMING:
			b.set_pose(CyborgBody.Pose.AIM)
			b.aim_at(Vector3(0.0, 1.0, 0.0))
			b.set_charge(0.8)
	for spec: Array in [[1, 22.0, 5], [-1, 38.0, 6]]:
		_world.director.spawn({"type": "window_cyborg", "at": spec[1], "lane": 4 if spec[0] > 0 else 0,
			"side": spec[0], "seed": spec[2], "params": {"fires": false}})


func _charge_scene() -> void:
	var c: Enemy = _world.director.spawn({"type": "cyborg", "at": 9.0, "lane": 2, "side": 0, "seed": 7,
		"params": {"panic": false, "fires": false}})
	var body: CyborgBody = c.get(&"body")
	body.set_pose(CyborgBody.Pose.AIM)
	body.aim_at(Vector3(0.6, 1.2, -2.0))
	body.set_charge(1.0)
	body.set_expression(Kit.Face.AIMING)
	c.set_physics_process(false)

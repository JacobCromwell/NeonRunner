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
##   lineup           every look side by side, the base first (GDD §9.2's zone variants), idle with the
##                    calm face; --face=aiming|shocked|dead shows another expression (aiming charges the
##                    weapon), --host makes them all hosts, --back turns them round, --side shows their
##                    right side (the weapon arm)
##   lineup_far       every look at gameplay distance through the run camera: calm faces 14 m ahead,
##                    aiming ones (weapons charged) behind them, shocked ones behind those
## Every view takes --skin=res://path/to/skin.tres (default: the grey box) and --variant=<name>, the
## skin's enemy_variant: a look's own name (base, brute, casino, vr_runner, burned, golden) or a skin's
## (city: the base; scavenger: Gangland's Brute), as CyborgSuit.look_for reads it. Live, ui_left and
## ui_right switch the look (the view rebuilds with it). --nolabel hides the captions.

const Kit = preload("res://scripts/enemies/cyborg_kit.gd")
const SCENE: String = "res://tools/showcase/enemy_showcase.tscn"

## The look picked live with ui_left / ui_right: it outlives the scene's reload.
static var _picked: StringName = &""

var _world: RunWorld
var _camera: Camera3D
var _variant: StringName = &"city"


func _ready() -> void:
	var view: String = _opt("view", "poses")
	_variant = _picked if _picked != &"" else StringName(_opt("variant", "city"))
	if view == "play":
		_play()
		return
	_world = _build_world(view)
	var variant: StringName = _variant
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
		"lineup":
			_lineup()
			_look(Vector3(0.0, 1.0, 4.05), Vector3(0.0, 0.86, -1.0))
		"lineup_far":
			_far_lineup()
		_:
			_pose_row(variant)
			_look(Vector3(0.0, 1.3, 5.2), Vector3(0.0, 0.8, -1.0))
	if not OS.get_cmdline_user_args().has("--nolabel") and not view.begins_with("lineup") and view != "generator":
		_caption("%s   (enemy_variant %s)" % [CyborgSuit.LOOK_TITLES[CyborgSuit.look_for(variant)], variant])


## ui_left / ui_right: the previous or next look, rebuilding the view with it.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_right") or event.is_action_pressed(&"ui_left"):
		var step: int = 1 if event.is_action_pressed(&"ui_right") else -1
		var looks: Array[StringName] = CyborgSuit.LOOKS
		_picked = looks[posmod(looks.find(CyborgSuit.look_for(_variant)) + step, looks.size())]
		get_tree().change_scene_to_file(SCENE)


## A caption at the top of the screen.
func _caption(text: String) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.text = text
	label.position = Vector2(16.0, 10.0)
	label.add_theme_font_size_override(&"font_size", 22)
	label.add_theme_color_override(&"font_color", Color(0.85, 0.9, 1.0))
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0))
	label.add_theme_constant_override(&"outline_size", 6)
	layer.add_child(label)


## A caption floating in the scene, facing the camera.
func _label(at: Vector3, text: String, size: int = 28) -> void:
	if OS.get_cmdline_user_args().has("--nolabel"):
		return
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.85, 0.9, 1.0)
	label.outline_size = 8
	label.position = at
	add_child(label)


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
	config.skin = _skin(_variant)
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
	config.skin = _skin(_variant)
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
## MovementTuning places it), with a row of cyborgs 14 m ahead and another 28 m ahead, each showing the
## calm face, the panic variant's shocked "O", the aiming face (cannon charged) and a host, and window
## cyborgs on both walls. Prints where each head is on screen (for cropping review frames).
func _far_scene() -> void:
	var t := load("res://data/tuning/movement.tres") as MovementTuning
	_world.player.visible = true
	_camera.fov = t.camera_fov
	_look(Vector3(0.0, t.camera_height, t.camera_distance), Vector3(0.0, 1.0, -t.camera_look_ahead))
	var v: StringName = _variant
	var faces: Array = [[Kit.Face.NEUTRAL, false], [Kit.Face.SHOCKED, false], [Kit.Face.AIMING, false],
		[Kit.Face.NEUTRAL, true]]
	var bodies: Array[CyborgBody] = []
	for row: int in 2:
		var at: float = 14.0 + 14.0 * row
		for i: int in faces.size():
			var b := _body(v, faces[i][1], _world.lane_point(i + row, at), 30 + row * 10 + i)
			b.set_expression(faces[i][0])
			if faces[i][0] == Kit.Face.AIMING:
				b.set_pose(CyborgBody.Pose.AIM)
				b.aim_at(Vector3(0.0, 1.0, 0.0))
				b.set_charge(0.8)
			bodies.append(b)
	for spec: Array in [[1, 21.0, 5], [-1, 35.0, 6]]:
		_world.director.spawn({"type": "window_cyborg", "at": spec[1], "lane": 4 if spec[0] > 0 else 0,
			"side": spec[0], "seed": spec[2], "params": {"fires": false}})
	await get_tree().process_frame
	for b: CyborgBody in bodies:
		var head: Vector3 = b.rig.joint(&"head").global_position + Vector3(0.0, 0.15, 0.0)
		var p: Vector2 = _camera.unproject_position(head) / Vector2(get_viewport().get_visible_rect().size)
		print("far head %s host=%s at %.0f m: screen %.4f %.4f" % [Kit.Face.keys()[b.face], b.host,
			-b.global_position.z, p.x, p.y])


func _charge_scene() -> void:
	var c: Enemy = _world.director.spawn({"type": "cyborg", "at": 9.0, "lane": 2, "side": 0, "seed": 7,
		"params": {"panic": false, "fires": false}})
	var body: CyborgBody = c.get(&"body")
	body.set_pose(CyborgBody.Pose.AIM)
	body.aim_at(Vector3(0.6, 1.2, -2.0))
	body.set_charge(1.0)
	body.set_expression(Kit.Face.AIMING)
	c.set_physics_process(false)


## Every look side by side, the base first, 1.1 m apart and facing the camera (or turned by --back or
## --side), each captioned with its name and zone.
func _lineup() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var faces: Dictionary = {"calm": Kit.Face.NEUTRAL, "aiming": Kit.Face.AIMING, "shocked": Kit.Face.SHOCKED,
		"dead": Kit.Face.DEAD}
	var face: Kit.Face = faces.get(_opt("face", "calm"), Kit.Face.NEUTRAL)
	var looks: Array[StringName] = CyborgSuit.LOOKS
	for i: int in looks.size():
		var x: float = (i - (looks.size() - 1) * 0.5) * 1.1
		var b := _body(looks[i], args.has("--host"), Vector3(x, 0.0, 0.0), 50 + i)
		if args.has("--back"):
			b.rotation.y = PI
		elif args.has("--side"):
			b.rotation.y = -PI * 0.5
		b.set_expression(face)
		if face == Kit.Face.AIMING:
			b.set_pose(CyborgBody.Pose.AIM)
			b.aim_at(Vector3(x * 0.6, 1.0, 6.0))
			b.set_charge(1.0)
		var title: String = CyborgSuit.LOOK_TITLES[looks[i]]
		_label(Vector3(x, 1.78, 0.0), title.replace(" · ", "\n"), 24)


## Every look at gameplay distance through the run camera: the calm face 14 m ahead, the aiming face
## (weapon charged) 21 m ahead and the shocked one 28 m ahead, each row spread across the lanes.
func _far_lineup() -> void:
	var t := load("res://data/tuning/movement.tres") as MovementTuning
	_world.player.visible = true
	_camera.fov = t.camera_fov
	_look(Vector3(0.0, t.camera_height, t.camera_distance), Vector3(0.0, 1.0, -t.camera_look_ahead))
	var looks: Array[StringName] = CyborgSuit.LOOKS
	var left: float = _world.lane_point(0, 0.0).x
	var right: float = _world.lane_point(_world.geo.lane_count - 1, 0.0).x
	var rows: Array = [[14.0, Kit.Face.NEUTRAL], [21.0, Kit.Face.AIMING], [28.0, Kit.Face.SHOCKED]]
	for r: int in rows.size():
		var at: float = rows[r][0]
		for i: int in looks.size():
			var x: float = lerpf(left, right, (i + 0.25 + 0.5 * (r % 2)) / (looks.size() - 0.5))
			var b := _body(looks[i], false, Vector3(x, 0.0, _world.lane_point(0, at).z), 70 + r * 10 + i)
			b.set_expression(rows[r][1])
			if rows[r][1] == Kit.Face.AIMING:
				b.set_pose(CyborgBody.Pose.AIM)
				b.aim_at(Vector3(0.0, 1.0, 0.0))
				b.set_charge(0.8)

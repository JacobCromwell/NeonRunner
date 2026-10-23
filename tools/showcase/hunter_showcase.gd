extends Node3D
## Visual review of the Hunter (GDD §9.17; task S2): its model up close in its three poses, or a scripted chase in a real
## RunWorld on Specimen Vault's look, through the game's camera (RunCamera) or a camera beside or behind it.
##
##   Render:  godot --path . --resolution 960x540 --write-movie build/hunter/f.png --fixed-fps 10 --quit-after 200
##            res://tools/showcase/hunter_showcase.tscn -- [options]
##   Options (after --):
##     --scenario=chase|model
##                           chase (default): it arrives from behind (its whine), comes up beside the runner on the side
##                           away from the bait's step out, and warns of its first flurry (both blades up, the scrape, the
##                           red mark on the runner's lane); the runner steps away from it (--stay: they don't, and the
##                           armor takes the cuts) and it follows into the lane they left. Then the bait: the runner dashes
##                           a falling gantryway's pillar in their lane and steps out away from it; it follows into the
##                           walkway's lane and the walkway lands on it;
##                           model: three of it side by side on a dark floor, calm, warning (blades raised, eyes and
##                           blades bright) and mid-flurry, the camera circling
##     --skin=<id>           the look (data/skins/<id>_skin.tres; default ice_lab_lab, Specimen Vault's)
##     --lanes=N             lane count (default 5; the runner starts in lane 1)
##     --camera=game|side|behind  the game's camera (default), one low beside the track looking across at it, or one high
##                           behind it
##     --stay                (chase) the runner stays in their lane through the first flurry (the armor absorbs it)
##     --mortal              (chase) no god mode: a cut that lands ends the run (with --stay the armor still saves them)
##     --reduced-flashing    Reduced flashing on (the warning mark widens without pulsing)
## The run prints the Hunter's events (arrive, alongside, warn, cut, cut_end, steer, yield, give_up, defeat) and each
## scripted action, with times, to find the frames (frame = time x render fps).

const TUNING_PATH: String = "res://data/tuning/movement.tres"
const RULES_PATH: String = "res://data/tuning/game_rules.tres"
const GantrywayRules = preload("res://scripts/enemies/gantryway_rules.gd")
const ICE_LAB_SPEED: float = 24.8
## Where it arrives and where the bait's pillar stands (metres): the first flurry comes between them, and the next is
## held by the bait's run-up (HunterTuning.bait_hold_seconds).
const ARRIVE: float = 40.0
const PILLAR: float = 250.0
## The runner's reaction (seconds) to the warning and to the pillar breaking (the suites' REACTION).
const REACTION: float = 0.35

var tuning: MovementTuning
var world: RunWorld
var camera: Camera3D
var camera_mode: String = "game"
var scenario: String = "chase"
var hunter: Hunter
var _pending: Array = []
var _models: Array[HunterModel] = []
var _t: float = 0.0
var _events: int = 0
var _stay: bool = false
var _dodged: bool = false
var _heading: int = -1


func _ready() -> void:
	tuning = load(TUNING_PATH) as MovementTuning
	var skin_id: String = "ice_lab_lab"
	var lanes: int = 5
	var mortal: bool = false
	for arg: String in OS.get_cmdline_user_args():
		var v: String = arg.get_slice("=", 1)
		if arg.begins_with("--scenario="):
			scenario = v
		elif arg.begins_with("--skin="):
			skin_id = v
		elif arg.begins_with("--lanes="):
			lanes = clampi(int(v), 3, 8)
		elif arg.begins_with("--camera="):
			camera_mode = v
		elif arg == "--stay":
			_stay = true
		elif arg == "--mortal":
			mortal = true
		elif arg == "--reduced-flashing":
			Settings.flashing_reduced = true
			RenderingServer.global_shader_parameter_set(&"reduced_flashing", 1.0)
	var skin: ZoneSkin = GreyboxSkin.new()
	var skin_path: String = "res://data/skins/%s_skin.tres" % skin_id
	if ResourceLoader.exists(skin_path):
		skin = load(skin_path) as ZoneSkin
	else:
		push_warning("hunter_showcase: no skin at %s; using the grey box" % skin_path)
	tuning = tuning.duplicate() as MovementTuning
	tuning.run_speed = ICE_LAB_SPEED
	_light()
	if scenario == "model":
		_build_model(skin)
		return
	_build_run(skin, lanes, mortal)


func _build_run(skin: ZoneSkin, lanes: int, mortal: bool) -> void:
	var lane: int = 1
	var walk_lane: int = lane + 1
	var layout := LevelLayout.new()
	layout.lane_count = lanes
	var config := LevelConfig.new()
	config.lane_count = lanes
	config.skin = skin
	config.enemy_scaling = 0.865  # Specimen Vault's
	config.features = PackedStringArray([GantrywayRules.FEATURE, "hunter"])
	# The bait as the gantryways' rules hang one: over the lane the runner will be in after their first dodge, its pillar
	# pushing (and the runner stepping out) away from the Hunter.
	var gen: LevelGenerator = LevelGenerator.for_layout(config, tuning, layout)
	var gt: GantrywayTuning = GantrywayTuning.load_default()
	var walkway: float = GantrywayRules.walkway_length(gen, gt)
	var calm: float = GantrywayRules.calm_length(gen, gt)
	var start: float = PILLAR - GantrywayRules.NEAR_OVERHANG
	layout.gantryways.append({"id": 0, "lane": walk_lane, "start": start, "end": start + walkway, "pillar": PILLAR,
		"side": 1, "calm": [PILLAR, PILLAR + calm], "seed": 5, "intro": false, "both": false})
	var pillar: Vector3 = tuning.doodad_size(Gantryway.PILLAR_SIZE)
	layout.doodads.append({"lane": walk_lane, "start": PILLAR, "end": PILLAR + pillar.z, "size": Gantryway.PILLAR_SIZE,
		"side": 1, "seed": 5, LevelLayout.GANTRY_PILLAR: 0})
	layout.enemies.append({"type": "hunter", "at": ARRIVE, "lane": lane, "side": 0, "seed": 3,
		"params": {"baits": [{"at": PILLAR, "lane": walk_lane, "side": 1, "id": 0}]}})
	layout.length = start + walkway + 300.0
	var pt := load("res://data/tuning/powerups.tres") as PowerupTuning
	var dashing: float = tuning.run_speed + pt.dash_speed_bonus
	_pending.append([PILLAR - 0.6 * pt.dash_duration * dashing, &"dash"])
	_pending.append([PILLAR + REACTION * dashing, &"move_right"])
	var loadout := Loadout.new()
	loadout.tiers[&"dash"] = 4
	loadout.armor = true
	world = RunWorld.new()
	add_child(world)
	world.build(config, layout, tuning, load(RULES_PATH) as GameRules, null, loadout,
		load("res://data/audio/sfx_library.tres") as SfxLibrary)
	world.player.setup(world.tuning, world.geo, lane)
	world.player.god_mode = not mortal
	world.player.movement_event.connect(func(kind: StringName) -> void:
		print("%5.2f s  %6.1f m  %s" % [world.player.elapsed, world.player.distance, kind]))
	world.player.died.connect(func(cause: String) -> void:
		print("%5.2f s  %6.1f m  died (%s)" % [world.player.elapsed, world.player.distance, cause]))
	world.track.gantryway_fell.connect(func(_g: Gantryway) -> void:
		print("%5.2f s  %6.1f m  the gantryway falls" % [world.player.elapsed, world.player.distance]))
	world.track.gantryway_landed.connect(func(_g: Gantryway) -> void:
		print("%5.2f s  %6.1f m  the gantryway landed" % [world.player.elapsed, world.player.distance]))
	world.director.enemy_defeated.connect(func(e: Enemy, cause: StringName) -> void:
		print("%5.2f s  %6.1f m  %s defeated (%s)" % [world.player.elapsed, world.player.distance, e.type_id, cause]))
	print("the Hunter arrives at %.0f m; the bait's pillar at %.0f m in lane %d (step out right)" % [ARRIVE, PILLAR, walk_lane])
	var env := WorldEnvironment.new()
	env.environment = skin.make_environment()
	add_child(env)
	if camera_mode == "game":
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
	var player: Player = world.player
	if hunter == null:
		for e: Variant in world.director.active:
			if is_instance_valid(e) and e is Hunter:
				hunter = e as Hunter
	while not _pending.is_empty() and player.distance >= float(_pending[0][0]):
		var action: StringName = _pending.pop_front()[1]
		print("%5.2f s  %6.1f m  > %s" % [player.elapsed, player.distance, action])
		if action == &"dash":
			world.powerups.call(&"try_dash")
		else:
			player.press(action)
	# The first flurry: the runner steps away from it a reaction into its warning (unless --stay).
	if not _dodged and not _stay and is_instance_valid(hunter) and hunter.slash == Hunter.Slash.WARNING \
			and float(hunter.get(&"_slash_t")) >= REACTION:
		_dodged = true
		var away: StringName = &"move_right" if hunter.side < 0 else &"move_left"
		print("%5.2f s  %6.1f m  > %s (away from the warning)" % [player.elapsed, player.distance, away])
		player.press(away)
	if is_instance_valid(hunter) and hunter.history.size() > _events:
		for i: int in range(_events, hunter.history.size()):
			print("%5.2f s  %6.1f m  the Hunter: %s (lane %d, side %d, gap %.1f m)" % [player.elapsed, player.distance,
				hunter.history[i][0], hunter.lane, hunter.side, hunter.gap])
		_events = hunter.history.size()
	if is_instance_valid(hunter) and hunter.visible and hunter.target_lane != _heading:
		_heading = hunter.target_lane
		print("%5.2f s  %6.1f m  the Hunter heads for lane %d (the runner in lane %d)" % [player.elapsed, player.distance,
			_heading, player.lane])


func _process(delta: float) -> void:
	_t += delta
	if not _models.is_empty():
		_animate_models(delta)
	elif world != null and camera_mode != "game":
		_update_camera()


## Low beside the track across from it, looking at it and the runner; or high behind it, looking down its lane.
func _update_camera() -> void:
	var p: Player = world.player
	var x: float = hunter.global_position.x if is_instance_valid(hunter) and hunter.visible else p.position.x
	var z: float = hunter.global_position.z if is_instance_valid(hunter) and hunter.visible else p.position.z
	if camera_mode == "behind":
		camera.position = Vector3(x * 0.6, 6.0, z + 9.0)
		camera.look_at(Vector3(x * 0.6, 1.0, z - 6.0))
	else:
		var across: float = world.geo.wall_x() - 0.8
		var side_x: float = across if x <= p.position.x else -across
		camera.position = Vector3(side_x, 1.9, z - 3.5)
		camera.look_at(Vector3((x + p.position.x) * 0.5, 1.3, z + 1.0))


func _light() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
	sun.light_energy = 0.7
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)


## Three of it side by side on a dark floor: calm, warning, mid-flurry.
func _build_model(skin: ZoneSkin) -> void:
	var env := WorldEnvironment.new()
	env.environment = skin.make_environment()
	add_child(env)
	for i: int in 3:
		var m := HunterModel.new()
		m.position = Vector3((i - 1) * 2.6, 0.0, 0.0)
		add_child(m)
		m.build()
		_models.append(m)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(14.0, 14.0)
	floor_mesh.mesh = plane
	floor_mesh.material_override = GreyboxMaterials.flat(Color(0.12, 0.12, 0.14))
	add_child(floor_mesh)
	camera = Camera3D.new()
	camera.fov = 40.0
	add_child(camera)
	camera.make_current()


func _animate_models(delta: float) -> void:
	var a: float = _t * 0.35
	var r: float = 8.5
	camera.position = Vector3(sin(a) * r, 2.6, -cos(a) * r)
	camera.look_at(Vector3(0.0, 1.1, 0.0))
	# Calm; warning (raised, alert); the flurry, its cuts looping.
	_models[1].raise = 1.0
	_models[1].alert = true
	_models[2].raise = 1.0
	_models[2].alert = true
	_models[2].lean = 0.32
	_models[2].cut = fmod(_t * 0.8, 1.0)
	for m: HunterModel in _models:
		m.animate(delta)

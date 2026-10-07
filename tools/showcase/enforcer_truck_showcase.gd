extends Node3D
## Visual review of the Enforcer Truck (GDD §9.13; task C6): its model up close, or a scripted run in a real
## RunWorld on any zone's skin, through the game's camera (RunCamera) or a camera behind or beside the truck.
##
##   Render:  godot --path . --write-movie build/enforcer/f.png --fixed-fps 10 --quit-after 200
##            res://tools/showcase/enforcer_truck_showcase.tscn -- [options]
##   Options (after --):
##     --scenario=chase|octodog|buzz|gap|model
##                           chase (default): it arrives behind the runner (its siren, its lights sliding in
##                           on the floor, its marker), picks up a cyborg the runner passed in its lane, and
##                           fires a volley (the red line and the whine) that the runner dodges;
##                           octodog: an Octodog charges, it closes right up behind the runner (its riders on
##                           its roof), and the runner dodges late, so the lunge flattens it (--early: the
##                           runner dodges at once and it follows out of the lane, unharmed);
##                           buzz: a Buzz Overdrive revs in the runner's lane, the runner leaves late and its
##                           charge destroys the truck; gap: the runner jumps a gap too wide for it to hop;
##                           model: the model turning on a plinth with its riders and lights
##     --skin=<zone id>      the zone's look (data/skins/<id>_skin.tres; default corporate_plaza)
##     --lanes=N             lane count (default 3)
##     --speed=N             the run speed (default the zone's: Corporate 23.4, the Dead Zone 24.2, Golden 25)
##     --riders=N            riders it starts with (default 2 in the octodog scenario, else 0)
##     --camera=game|behind|side  the game's camera (default), one high behind the truck, or one beside it
##     --early               (octodog) the runner dodges as the wind-up starts
##     --reduced-flashing    Reduced flashing on (its light bar steady, the line only widening)
## The run prints the truck's events (arrive, close, warn, fire, rider, hop, leave, wreck) and each scripted
## action, with times, to find the frames (frame = time x render fps).

const TUNING_PATH: String = "res://data/tuning/movement.tres"
const RULES_PATH: String = "res://data/tuning/game_rules.tres"
const BuzzRules = preload("res://scripts/enemies/buzz_overdrive_rules.gd")
const ZONE_SPEEDS: Dictionary = {"corporate": 23.4, "corporate_plaza": 23.4, "dead_zone": 24.2, "golden": 25.0,
	"golden_palace": 25.0}

var tuning: MovementTuning
var world: RunWorld
var camera: Camera3D
var camera_mode: String = "game"
var scenario: String = "chase"
var truck: EnforcerTruck
var _pending: Array = []
var _model: EnforcerTruckModel
var _model_lights: Node3D
var _t: float = 0.0
var _events: int = 0
var _dog: Octodog
var _windup_t: float = -1.0
var _early: bool = false
var _dodged: bool = false
var _riders: int = -1
var _buzz_meet: float = INF


func _ready() -> void:
	tuning = load(TUNING_PATH) as MovementTuning
	var skin_id: String = "corporate_plaza"
	var lanes: int = 3
	var speed: float = -1.0
	for arg: String in OS.get_cmdline_user_args():
		var v: String = arg.get_slice("=", 1)
		if arg.begins_with("--scenario="):
			scenario = v
		elif arg.begins_with("--skin="):
			skin_id = v
		elif arg.begins_with("--lanes="):
			lanes = clampi(int(v), 3, 8)
		elif arg.begins_with("--speed="):
			speed = maxf(float(v), 5.0)
		elif arg.begins_with("--riders="):
			_riders = clampi(int(v), 0, 3)
		elif arg.begins_with("--camera="):
			camera_mode = v
		elif arg == "--early":
			_early = true
		elif arg == "--reduced-flashing":
			Settings.flashing_reduced = true
			RenderingServer.global_shader_parameter_set(&"reduced_flashing", 1.0)
	var skin: ZoneSkin = GreyboxSkin.new()
	var skin_path: String = "res://data/skins/%s_skin.tres" % skin_id
	if ResourceLoader.exists(skin_path):
		skin = load(skin_path) as ZoneSkin
	else:
		push_warning("enforcer_truck_showcase: no skin at %s; using the grey box" % skin_path)
	if speed < 0.0:
		speed = float(ZONE_SPEEDS.get(skin_id, tuning.run_speed))
	tuning = tuning.duplicate() as MovementTuning
	tuning.run_speed = speed
	_light()
	if scenario == "model":
		_build_model(skin)
		return
	_build_run(skin, lanes, speed)


func _build_run(skin: ZoneSkin, lanes: int, speed: float) -> void:
	var lane: int = lanes / 2
	var layout := LevelLayout.new()
	layout.lane_count = lanes
	layout.length = 2000.0
	var arrive: float = 30.0
	layout.enemies.append({"type": "enforcer_truck", "at": arrive, "lane": lane, "side": 0, "seed": 1, "params": {}})
	var pace: float = tuning.pace()
	match scenario:
		"chase":
			# A cyborg in the runner's lane, passed alive, which the truck picks up; a volley the runner dodges.
			layout.enemies.append({"type": "cyborg", "at": 70.0 * pace, "lane": lane, "side": 0, "seed": 2,
				"params": {"fires": false, "panic": false}})
		"octodog":
			layout.enemies.append({"type": "octodog", "at": 230.0 * pace, "lane": lane, "side": 0, "seed": 3,
				"params": {"doghouse": false}})
			if _riders < 0:
				_riders = 2
		"buzz":
			var cut: Dictionary = BuzzRules.plan_for(BuzzRules.tuning(), lane, 150.0 * pace, speed, pace, 0.64)
			layout.cuts.append(cut)
			layout.enemies.append({"type": "buzz_overdrive", "at": float(cut["end"]), "lane": lane, "side": 0, "seed": 4,
				"params": {}})
			_buzz_meet = FloorCutPlan.meet(cut, speed)
		"gap":
			var jump: float = tuning.jump_distance(speed)
			layout.gaps.append({"lane": lane, "start": 170.0 * pace, "end": 170.0 * pace + jump * 0.78})
			_pending.append([170.0 * pace - jump * 0.15, &"jump"])
	var config := LevelConfig.new()
	config.lane_count = lanes
	config.skin = skin
	config.enemy_scaling = 0.64
	world = RunWorld.new()
	add_child(world)
	world.build(config, layout, tuning, load(RULES_PATH) as GameRules, null, Loadout.new(),
		load("res://data/audio/sfx_library.tres") as SfxLibrary)
	world.player.setup(tuning, world.geo, lane)
	world.player.god_mode = true
	if scenario == "chase":
		# Leave the lane early in the first volley's warning.
		_pending.append([-1.0, &"volley_dodge"])
	if scenario == "buzz":
		_pending.append([_buzz_meet - 0.55 * speed, &"move_right"])
	world.player.movement_event.connect(func(kind: StringName) -> void:
		print("%5.2f s  %6.1f m  %s" % [world.player.elapsed, world.player.distance, kind]))
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
	if truck == null:
		for e: Variant in world.director.active:
			if is_instance_valid(e) and e is EnforcerTruck:
				truck = e as EnforcerTruck
				if _riders > 0:
					truck.riders = _riders
					truck.model.set_riders(_riders)
					truck.marker.riders = _riders
	if _dog == null:
		for e: Variant in world.director.active:
			if is_instance_valid(e) and e is Octodog:
				_dog = e as Octodog
	while not _pending.is_empty() and float(_pending[0][0]) >= 0.0 and player.distance >= float(_pending[0][0]):
		var action: StringName = _pending.pop_front()[1]
		print("%5.2f s  %6.1f m  > %s" % [player.elapsed, player.distance, action])
		player.press(action)
	if not _pending.is_empty() and _pending[0][1] == &"volley_dodge" and is_instance_valid(truck) \
			and truck.volley == EnforcerTruck.Volley.WARNING and truck._volley_t >= 0.35:
		_pending.pop_front()
		print("%5.2f s  %6.1f m  > move_right (the volley's warning)" % [player.elapsed, player.distance])
		player.press(&"move_right" if player.lane < world.geo.lane_count - 1 else &"move_left")
	if scenario == "octodog" and is_instance_valid(_dog) and _dog.phase == Octodog.Phase.WINDUP and _windup_t < 0.0:
		_windup_t = player.elapsed
		_dodged = false
	if _windup_t >= 0.0 and not _dodged and player.elapsed - _windup_t >= (0.15 if _early else 0.9):
		_dodged = true
		print("%5.2f s  %6.1f m  > dodge (%.2f s after the wind-up)" % [player.elapsed, player.distance, player.elapsed - _windup_t])
		player.press(&"move_right" if player.lane < world.geo.lane_count - 1 else &"move_left")
	if is_instance_valid(_dog) and _dog.phase not in [Octodog.Phase.WINDUP, Octodog.Phase.LUNGE]:
		_windup_t = -1.0
	if is_instance_valid(truck) and truck.history.size() > _events:
		for i: int in range(_events, truck.history.size()):
			print("%5.2f s  %6.1f m  the truck: %s (gap %.1f m, lane %d, riders %d)" % [player.elapsed, player.distance,
				truck.history[i][0], truck.gap, truck.lane, truck.riders])
		_events = truck.history.size()


func _process(delta: float) -> void:
	_t += delta
	if _model != null:
		_animate_model(delta)
	elif world != null and camera_mode != "game":
		_update_camera()


## High behind the truck, looking down its lane past the runner; or low beside it.
func _update_camera() -> void:
	var p: Player = world.player
	var x: float = truck.global_position.x if is_instance_valid(truck) else p.position.x
	var z: float = truck.global_position.z if is_instance_valid(truck) and truck.visible else p.position.z + 8.0
	if camera_mode == "behind":
		camera.position = Vector3(x * 0.6 + 2.0, 6.5, z + 11.0)
		camera.look_at(Vector3(x, 1.0, p.position.z - 6.0))
	else:
		var side_x: float = x + (world.geo.lane_width * 3.0 if x <= 0.0 else -world.geo.lane_width * 3.0)
		camera.position = Vector3(side_x, 2.2, z - 1.0)
		camera.look_at(Vector3(x, 1.2, z + 2.0))


func _light() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
	sun.light_energy = 0.7
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)


## The model turning on a dark plinth with its riders aboard, its light bar taking turns and its floor lights.
func _build_model(skin: ZoneSkin) -> void:
	var t: EnforcerTruckTuning = EnemyDirector.tuning_for("enforcer_truck") as EnforcerTruckTuning
	var env := WorldEnvironment.new()
	env.environment = skin.make_environment()
	add_child(env)
	_model = EnforcerTruckModel.new()
	add_child(_model)
	_model.build(skin.enemy_variant if skin != null else &"city", t.body_size)
	_model.set_riders(3 if _riders < 0 else _riders)
	_model_lights = EnforcerTruckModel.floor_lights()
	_model_lights.position.y = 0.02
	add_child(_model_lights)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(16.0, 34.0)
	floor_mesh.mesh = plane
	floor_mesh.position = Vector3(0.0, 0.0, -8.0)
	floor_mesh.material_override = GreyboxMaterials.flat(Color(0.12, 0.12, 0.14))
	add_child(floor_mesh)
	camera = Camera3D.new()
	camera.fov = 45.0
	add_child(camera)
	camera.make_current()


func _animate_model(_delta: float) -> void:
	var a: float = _t * 0.4 + 0.6
	var r: float = 11.0
	camera.position = Vector3(sin(a) * r, 4.2, cos(a) * r + 3.2)
	camera.look_at(Vector3(0.0, 1.2, 3.2))
	var phase: int = int(_t * 4.0) % 2
	_model.set_flash(phase, Settings.flashing_reduced)
	var dim: Material = EnforcerTruckModel.floor_material(&"dim")
	var bright: Material = EnforcerTruckModel.floor_material(&"bright")
	(_model_lights.get_node(^"WashRed") as MeshInstance3D).material_override = dim if Settings.flashing_reduced or phase != 0 else bright
	(_model_lights.get_node(^"WashBlue") as MeshInstance3D).material_override = dim if Settings.flashing_reduced or phase != 1 else bright

extends Node3D
## Visual review of the cyborgs planted in charge paths (task G7; GDD §9.13 "Teaching"; ChargePathPlacement): an
## Octodog's planted lunge or a parked Buzz Overdrive's charge flattening its cyborg, in a real RunWorld on any
## zone's skin, through the game's camera (RunCamera) or one high behind the runner. The encounter is planned and
## planted by the placement itself (dog_option or tank_option, then plant) on a plain track.
##
##   Render:  godot --path . --write-movie build/charge_paths/f.png --fixed-fps 10 --quit-after 110
##            res://tools/showcase/charge_path_review.tscn -- [options]
##   Options (after --):
##     --scenario=octodog|buzz
##                           octodog (default): the dog in --lane winds up and lunges along its planned line,
##                           two lanes across, through the cyborg standing in the lane beside it; the runner
##                           starts in the far lane and leaves it a reaction after the wind-up starts;
##                           buzz: the tank waits parked at its cut's end in --lane, revs and charges back down the
##                           lane through the cyborg standing in front of its blade; the runner leaves the lane
##                           at its warning
##     --skin=<zone id>      the zone's look (data/skins/<id>_skin.tres; default corporate_plaza)
##     --lanes=N             lane count (default 5)
##     --lane=N              the dog's lane, or the cut's (default 0)
##     --speed=N             the run speed (default the zone's: Corporate 23.4, the Dead Zone 24.2, Golden 25)
##     --camera=game|behind  the game's camera (default) or one high behind the runner
##     --reduced-flashing    Reduced flashing on
## The run prints the encounter's plan, the warning, the runner's move and the cyborg's death (with how far ahead
## of the runner it was), with times, to find the frames (frame = time x render fps).

const TUNING_PATH: String = "res://data/tuning/movement.tres"
const RULES_PATH: String = "res://data/tuning/game_rules.tres"
const OctodogRules = preload("res://scripts/enemies/octodog_rules.gd")
const BuzzRules = preload("res://scripts/enemies/buzz_overdrive_rules.gd")
const ZONE_SPEEDS: Dictionary = {"city": 21.0, "gangland": 21.8, "marketplace": 22.6, "casino": 23.0, "corporate": 23.4,
	"corporate_plaza": 23.4, "dead_zone": 24.2, "golden": 25.0, "golden_palace": 25.0}
## Seconds after the dog's wind-up starts that the runner leaves the far lane.
const DOG_REACTION: float = 0.3

var tuning: MovementTuning
var world: RunWorld
var camera: Camera3D
var camera_mode: String = "game"
var scenario: String = "octodog"
var _away: int = -1
var _leave_at: float = INF
var _windup: float = -1.0
var _left: bool = false


func _ready() -> void:
	tuning = load(TUNING_PATH) as MovementTuning
	var skin_id: String = "corporate_plaza"
	var lanes: int = 5
	var lane: int = 0
	var speed: float = -1.0
	for arg: String in OS.get_cmdline_user_args():
		var v: String = arg.get_slice("=", 1)
		if arg.begins_with("--scenario="):
			scenario = v
		elif arg.begins_with("--skin="):
			skin_id = v
		elif arg.begins_with("--lanes="):
			lanes = clampi(int(v), 3, 8)
		elif arg.begins_with("--lane="):
			lane = maxi(int(v), 0)
		elif arg.begins_with("--speed="):
			speed = maxf(float(v), 5.0)
		elif arg.begins_with("--camera="):
			camera_mode = v
		elif arg == "--reduced-flashing":
			Settings.flashing_reduced = true
			RenderingServer.global_shader_parameter_set(&"reduced_flashing", 1.0)
	var skin: ZoneSkin = GreyboxSkin.new()
	var skin_path: String = "res://data/skins/%s_skin.tres" % skin_id
	if ResourceLoader.exists(skin_path):
		skin = load(skin_path) as ZoneSkin
	else:
		push_warning("charge_path_review: no skin at %s; using the grey box" % skin_path)
	if speed < 0.0:
		speed = float(ZONE_SPEEDS.get(skin_id, tuning.run_speed))
	tuning = tuning.duplicate() as MovementTuning
	tuning.run_speed = speed
	_build_run(skin, lanes, mini(lane, lanes - 1), speed)


func _build_run(skin: ZoneSkin, lanes: int, lane: int, speed: float) -> void:
	var layout := LevelLayout.new()
	layout.lane_count = lanes
	layout.length = 2000.0
	var config := LevelConfig.new()
	config.lane_count = lanes
	config.skin = skin
	config.enemy_scaling = 11.0 / 16.0  # Corporate 2's
	config.features = PackedStringArray(["cyborg", "octodog", "buzz_overdrive"])
	var gen: LevelGenerator = LevelGenerator.for_layout(config, tuning, layout)
	var t: ChargePathTuning = ChargePathPlacement.tuning()
	var option: Dictionary = {}
	var start_lane: int = lane
	if scenario == "buzz":
		var cut: Dictionary = BuzzRules.plan_for(BuzzRules.tuning(), lane, 4.0 * speed + 30.0, speed, gen.pace,
			config.enemy_scaling)
		layout.cuts.append(cut)
		var tank := {"type": "buzz_overdrive", "at": float(cut["end"]), "lane": lane, "side": 0, "seed": 4, "params": {}}
		layout.enemies.append(tank)
		option = ChargePathPlacement.tank_option(gen, t, tank)
		_away = lane + 1 if lane < lanes - 1 else lane - 1
		_leave_at = FloorCutPlan.warn_at(cut) + config.cut_reaction_seconds * speed
	else:
		var a0: float = 4.0 * speed + 30.0
		var dog := {"type": "octodog", "at": a0 + OctodogRules.tuning().stop_distance(speed, config.enemy_scaling, gen.pace),
			"lane": lane, "side": 0, "seed": 3, "params": {"doghouse": false, "charges": 1, "charge_at": [a0]}}
		layout.enemies.append(dog)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		option = ChargePathPlacement.dog_option(gen, t, rng, dog)
	if not option.has("cyborg"):
		push_warning("charge_path_review: no fair planted encounter here (%s)" % option.get("why", "?"))
		return
	var planted: Dictionary = ChargePathPlacement.plant(gen, option, 0)
	var cyborg: Dictionary = planted["cyborg"]
	var charger: Dictionary = planted["charger"]
	if scenario != "buzz":
		var far: int = int(cyborg["lane"]) + (int(cyborg["lane"]) - int(charger["lane"]))
		start_lane = far
		# Away from the dog's side where there's a lane, else back toward the cyborg's (flattened by then).
		_away = far + (far - int(cyborg["lane"]))
		if _away < 0 or _away >= lanes:
			_away = int(cyborg["lane"])
	print("%s in lane %d at %.1f m; its cyborg in lane %d at %.1f m (holds fire %.0f-%.0f m); the runner in lane %d, leaving for %d"
		% [planted["kind"], int(charger["lane"]), float(charger["at"]), int(cyborg["lane"]), float(cyborg["at"]),
		(cyborg["params"]["hold_fire"] as Vector2).x, (cyborg["params"]["hold_fire"] as Vector2).y, start_lane, _away])
	world = RunWorld.new()
	add_child(world)
	world.build(config, layout, tuning, load(RULES_PATH) as GameRules, null, Loadout.new(),
		load("res://data/audio/sfx_library.tres") as SfxLibrary)
	world.player.setup(tuning, world.geo, start_lane)
	world.player.god_mode = true
	world.director.enemy_defeated.connect(func(e: Enemy, cause: StringName) -> void:
		print("%5.2f s  %6.1f m  %s down (%s), %.1f m ahead of the runner" % [world.player.elapsed, world.player.distance,
			e.type_id, cause, e.track_distance() - world.player.distance]))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
	sun.light_energy = 0.7
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)
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
	if scenario != "buzz" and _windup < 0.0:
		for e: Variant in world.director.active:
			if is_instance_valid(e) and e is Octodog and (e as Octodog).phase == Octodog.Phase.WINDUP:
				_windup = player.elapsed
				print("%5.2f s  %6.1f m  the dog winds up" % [player.elapsed, player.distance])
				_leave_at = player.distance + DOG_REACTION * player.speed
	if not _left and _away >= 0 and player.distance >= _leave_at:
		_left = true
		print("%5.2f s  %6.1f m  > leave for lane %d" % [player.elapsed, player.distance, _away])
		player.press(&"move_right" if _away > player.lane else &"move_left")


func _process(_delta: float) -> void:
	if world == null or camera_mode == "game":
		return
	var p: Player = world.player
	camera.position = Vector3(p.position.x * 0.5, 6.0, p.position.z + 9.0)
	camera.look_at(Vector3(0.0, 0.8, p.position.z - 14.0))

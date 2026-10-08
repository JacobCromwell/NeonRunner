extends Node3D
## Visual review of the wider gaps (task G7; GDD §9.13 "Holes"; WideGapPlacement): a scripted run in a real
## RunWorld on any zone's skin, through the game's camera (RunCamera) or one beside the gap.
##
##   Render:  godot --path . --write-movie build/wide_gaps/f.png --fixed-fps 10 --quit-after 110
##            res://tools/showcase/wide_gap_review.tscn -- [options]
##   Options (after --):
##     --scenario=jump|enforcer
##                           jump (default): a row of the wider length (WideGapPlacement.length_for) in every lane
##                           but the last, the runner jumping it from the middle of its take-off window;
##                           enforcer: an Enforcer Truck arrives behind the runner, settles, and follows them
##                           over such a row, where it's wrecked (the player's kill)
##     --skin=<zone id>      the zone's look (data/skins/<id>_skin.tres; default corporate_plaza)
##     --lanes=N             lane count (default 5)
##     --speed=N             the run speed (default the zone's: Corporate 23.4, the Dead Zone 24.2, Golden 25)
##     --camera=game|side    the game's camera (default) or one low beside the gap
##     --reduced-flashing    Reduced flashing on
## The run prints the jump, the landing and the truck's events, with times, to find the frames (frame = time x
## render fps).

const TUNING_PATH: String = "res://data/tuning/movement.tres"
const RULES_PATH: String = "res://data/tuning/game_rules.tres"
const ZONE_SPEEDS: Dictionary = {"city": 21.0, "gangland": 21.8, "marketplace": 22.6, "corporate": 23.4,
	"corporate_plaza": 23.4, "dead_zone": 24.2, "golden": 25.0, "golden_palace": 25.0}

var tuning: MovementTuning
var world: RunWorld
var camera: Camera3D
var camera_mode: String = "game"
var scenario: String = "jump"
var truck: EnforcerTruck
var _gap := Vector2.ZERO
var _take_off: float = INF
var _jumped: bool = false
var _landed: bool = false
var _events: int = 0


func _ready() -> void:
	tuning = load(TUNING_PATH) as MovementTuning
	var skin_id: String = "corporate_plaza"
	var lanes: int = 5
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
		push_warning("wide_gap_review: no skin at %s; using the grey box" % skin_path)
	if speed < 0.0:
		speed = float(ZONE_SPEEDS.get(skin_id, tuning.run_speed))
	tuning = tuning.duplicate() as MovementTuning
	tuning.run_speed = speed
	_build_run(skin, lanes, speed)


func _build_run(skin: ZoneSkin, lanes: int, speed: float) -> void:
	var lane: int = lanes / 2
	var layout := LevelLayout.new()
	layout.lane_count = lanes
	layout.length = 2000.0
	var config := LevelConfig.new()
	config.lane_count = lanes
	config.skin = skin
	config.enemy_scaling = 0.64
	var gen: LevelGenerator = LevelGenerator.for_layout(config, tuning, layout)
	var length: float = WideGapPlacement.length_for(gen)
	var start: float = 3.0 * speed + 40.0
	if scenario == "enforcer":
		var et: EnforcerTruckTuning = EnemyDirector.tuning_for("enforcer_truck") as EnforcerTruckTuning
		layout.enemies.append({"type": "enforcer_truck", "at": 30.0, "lane": lane, "side": 0, "seed": 1, "params": {}})
		start = 30.0 + (et.bait_after_seconds + 3.0) * speed
	_gap = Vector2(start, start + length)
	for l: int in lanes - 1:
		layout.gaps.append({"lane": l, "start": _gap.x, "end": _gap.y})
	_take_off = _gap.x - (gen.jump_distance - length) * 0.5
	print("wider row %.1f-%.1f m (%.2f of a %.1f m jump), lanes 0-%d; take-off at %.1f m" % [_gap.x, _gap.y,
		length / gen.jump_distance, gen.jump_distance, lanes - 2, _take_off])
	world = RunWorld.new()
	add_child(world)
	world.build(config, layout, tuning, load(RULES_PATH) as GameRules, null, Loadout.new(),
		load("res://data/audio/sfx_library.tres") as SfxLibrary)
	world.player.setup(tuning, world.geo, lane)
	world.player.god_mode = true
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
	if truck == null:
		for e: Variant in world.director.active:
			if is_instance_valid(e) and e is EnforcerTruck:
				truck = e as EnforcerTruck
	if not _jumped and player.distance >= _take_off:
		_jumped = true
		print("%5.2f s  %6.1f m  > jump" % [player.elapsed, player.distance])
		player.press(&"jump")
	if _jumped and not _landed and player.grounded and player.distance > _gap.y:
		_landed = true
		print("%5.2f s  %6.1f m  landed past the gap" % [player.elapsed, player.distance])
	if is_instance_valid(truck) and truck.history.size() > _events:
		for i: int in range(_events, truck.history.size()):
			print("%5.2f s  %6.1f m  the truck: %s (gap %.1f m, lane %d)" % [player.elapsed, player.distance,
				truck.history[i][0], truck.gap, truck.lane])
		_events = truck.history.size()


func _process(_delta: float) -> void:
	if world == null or camera_mode == "game":
		return
	# Low beside the gap's row, on the open lane's side, looking across it.
	var mid: float = (_gap.x + _gap.y) * 0.5
	var x: float = world.geo.lane_x(world.geo.lane_count - 1) + world.geo.lane_width * 1.5
	camera.position = Vector3(x, 2.4, TrackGeometry.world_z(mid - 4.0))
	camera.look_at(Vector3(world.geo.lane_x(world.geo.lane_count / 2), 0.6, TrackGeometry.world_z(mid + 2.0)))

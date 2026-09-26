extends Node3D
## Scripted scenes for visual checks of the heli drone and the hover truck (not part of the game).
## A flat hand-built track, the enemy, and a scripted player, filmed by the run camera or a close
## camera. Render with the Compatibility renderer, e.g.:
##   SCENE=res://tools/showcase/enemy_showcase.tscn render.sh . build/show 180 -- --scenario=truck
## or play it: godot --path . res://tools/showcase/enemy_showcase.tscn -- --scenario=drone
## Scenarios:
##   truck        (default) banging, burst, pacing and cannon, lurches, route (b) onto the cab,
##                stomp, spin-out and explosion
##   drone        swoop, follow, wind-up with aim line, barrage, dodge, anti-grav pad
##   close_truck  a close camera beside a truck's front through its rev and forward lurch
##   close_drone  a close camera beside a drone (model, wind-up and barrage)
## Options: --variant=scavenger (the zone look), --lanes=N, --scaling=0..1 (window shooters).

const TruckScript := preload("res://scripts/enemies/hover_truck.gd")
const DroneScript := preload("res://scripts/enemies/drone.gd")

var world: RunWorld
var scenario: String = "truck"
var truck: TruckScript
var drone: DroneScript
var _cam: Camera3D
var _run_cam: RunCamera
var _t: float = 0.0
var _step: int = 0
var _mark: float = 0.0


func _ready() -> void:
	var lanes: int = 3
	var variant: StringName = &"city"
	var scaling: float = 0.0
	for arg: String in OS.get_cmdline_user_args():
		var v: String = arg.get_slice("=", 1)
		if arg.begins_with("--scenario="):
			scenario = v
		elif arg.begins_with("--variant="):
			variant = StringName(v)
		elif arg.begins_with("--lanes="):
			lanes = int(v)
		elif arg.begins_with("--scaling="):
			scaling = float(v)
	if scenario == "drone" and lanes == 3:
		lanes = 5
	var tuning := load("res://data/tuning/movement.tres") as MovementTuning
	var skin := GreyboxSkin.new()
	skin.enemy_variant = variant
	var config := LevelConfig.new()
	config.lane_count = lanes
	config.skin = skin
	config.enemy_scaling = scaling
	var layout := LevelLayout.new()
	layout.lane_count = lanes
	layout.length = 900.0
	if scenario == "drone":
		layout.pads.append({"lane": lanes / 2 - 1, "at": 190.0})
		layout.hulls.append({"start": 187.0, "end": 260.0})
	world = RunWorld.new()
	add_child(world)
	world.build(config, layout, tuning, load("res://data/tuning/game_rules.tres") as GameRules,
		load("res://data/tuning/powerups.tres") as PowerupTuning)
	world.player.god_mode = true

	var env := WorldEnvironment.new()
	env.environment = skin.make_environment()
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
	sun.light_energy = 0.7
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)
	_run_cam = RunCamera.new()
	add_child(_run_cam)
	_run_cam.follow(world)
	_run_cam.make_current()

	match scenario:
		"truck":
			truck = _spawn_truck({}, 120.0)
		"close_truck":
			world.player.setup(tuning, world.geo, lanes - 2)
			truck = _spawn_truck({"skip_entrance": true, "phase": "hold_back", "offset": -7.0}, 0.0)
			_close_camera()
		"drone", "close_drone":
			drone = world.director.spawn({"type": "drone", "at": 30.0, "lane": 1, "side": 0, "seed": 4,
				"params": {"slot": 0}}) as DroneScript
			if scenario == "close_drone":
				_close_camera()
	world.start()


func _spawn_truck(params: Dictionary, at: float) -> TruckScript:
	return world.director.spawn({"type": "hover_truck", "at": at, "lane": world.layout.lane_count - 1, "side": 1,
		"seed": 5, "params": params}) as TruckScript


func _close_camera() -> void:
	_cam = Camera3D.new()
	_cam.fov = 55.0
	add_child(_cam)
	_cam.make_current()


func _physics_process(delta: float) -> void:
	_t += delta
	var p: Player = world.player
	match scenario:
		"truck":
			_script_truck(p)
		"drone":
			if _step == 0 and is_instance_valid(drone) and drone.state == DroneScript.State.FIRE:
				p.press(&"move_left")  # dodge the barrage; the pad waits in this lane
				_step = 1


func _process(_delta: float) -> void:
	if _cam == null:
		return
	var p: Player = world.player
	match scenario:
		"close_truck":
			# Beside the truck's front, from the lanes: the cab, the driver, the weak point, the
			# spikes flashing through the rev and the forward lurch.
			if is_instance_valid(truck):
				var c: Vector3 = truck.global_position
				_cam.global_position = Vector3(c.x - 6.0, 3.0, c.z - 1.0)
				_cam.look_at(c + Vector3(0.0, 1.1, -3.2), Vector3.UP)
		"close_drone":
			if is_instance_valid(drone) and drone.visible:
				var d: Vector3 = drone.global_position
				_cam.global_position = d + Vector3(-3.2, -0.6, 3.8)
				_cam.look_at(d + Vector3(0.0, -0.4, 0.0), Vector3.UP)


## Route (b): into its lane once it's behind, onto the wall late in its rev, then a wall jump onto
## the cab as it comes alongside.
func _script_truck(p: Player) -> void:
	if not is_instance_valid(truck) or not truck.alive:
		return
	match _step:
		0:
			if truck.state == TruckScript.State.HOLD_BACK:
				for i: int in truck.lane - p.lane:
					p.press(&"move_right")  # presses in one frame chain into one switch
				_step = 1
		1:
			if truck.state == TruckScript.State.REV:
				_mark = _t
				_step = 2
		2:
			if _t - _mark >= truck.tune.rev_seconds * 0.6:
				p.press(&"move_right")
				_step = 3
		3:
			if truck.state == TruckScript.State.ALONGSIDE:
				p.press(&"jump")
				_step = 4

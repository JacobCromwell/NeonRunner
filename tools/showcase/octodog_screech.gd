extends Node3D
## Close-up showcase of the Octodog and the Sewer Screech in their key poses, for visual review:
##   SCENE=res://tools/showcase/octodog_screech.tscn render.sh . build/showcase 40 [-- city|scavenger]
## Builds a real RunWorld (grey-box skin) with the player standing still, spawns the enemies through
## the EnemyDirector and freezes each in one phase (their physics is paused; their animation runs).

var world: RunWorld
var _dogs: Array[Octodog] = []
var _screeches: Array[Screech] = []
var _t: float = 0.0


func _ready() -> void:
	var variant: StringName = &"scavenger" if OS.get_cmdline_user_args().has("scavenger") else &"city"
	var tuning := load("res://data/tuning/movement.tres") as MovementTuning
	var config := LevelConfig.new()
	config.lane_count = 5
	var skin := GreyboxSkin.new()
	skin.enemy_variant = variant
	config.skin = skin
	var layout := LevelLayout.new()
	layout.lane_count = 5
	layout.length = 300.0
	world = RunWorld.new()
	add_child(world)
	world.build(config, layout, tuning, load("res://data/tuning/game_rules.tres") as GameRules)
	world.player.visible = false
	var env := WorldEnvironment.new()
	env.environment = skin.make_environment()
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sun.light_energy = 0.8
	add_child(sun)
	# Views: the whole group (default), or close on the left / right wall's vent.
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var cam := Camera3D.new()
	cam.fov = 60.0
	add_child(cam)
	if args.has("left"):
		cam.position = Vector3(-3.2, 1.5, -3.5)
		cam.look_at(Vector3(-6.3, 0.35, -7.5))
	elif args.has("right"):
		cam.position = Vector3(3.2, 1.5, -4.0)
		cam.look_at(Vector3(6.3, 0.35, -8.0))
	elif args.has("close"):
		cam.position = Vector3(1.0, 1.4, -1.5)
		cam.look_at(Vector3(1.6, 0.3, -5.0))
	else:
		cam.position = Vector3(0.0, 2.6, -2.0)
		cam.look_at(Vector3(0.0, 0.4, -11.0))
	cam.make_current()

	# Octodogs, left to right: doghouse, idle, wind-up (aiming one lane over), lunge, running ahead.
	var poses: Array = [[-4.8, 13.0, "doghouse"], [-2.4, 12.0, "idle"], [0.0, 12.0, "windup"],
		[2.4, 11.0, "lunge"], [4.8, 12.5, "sprint"]]
	for p: Array in poses:
		var lane: int = int(round(float(p[0]) / 2.4)) + 2
		var dog := world.director.spawn({"type": "octodog", "at": float(p[1]), "lane": lane, "side": 0,
			"seed": lane, "params": {"doghouse": p[2] == "doghouse", "charges": 3}}) as Octodog
		dog.set_physics_process(false)
		_dogs.append(dog)
		match p[2]:
			"windup":
				dog.target_lane = 1
				dog.phase = Octodog.Phase.WINDUP
				dog.call(&"_show_telegraph")
			"lunge":
				dog.target_lane = 2
				dog.phase = Octodog.Phase.LUNGE
				dog.lunge_velocity = Vector2(-2.0, -9.0)
			"sprint":
				dog.phase = Octodog.Phase.SPRINT
	# Screeches, nearer: a manhole at rest, one shaking, one out mid-swipe; vents on both walls.
	var screeches: Array = [[0, 6.0, "manhole", "rest"], [1, 6.5, "manhole", "shake"], [3, 5.0, "manhole", "swipe"],
		[-1, 7.5, "vent", "shake"], [1, 8.0, "vent", "wall"]]
	for s: Array in screeches:
		var side: int = int(s[0]) if s[2] == "vent" else 0
		var lane: int = int(s[0]) if s[2] == "manhole" else world.layout.outer_lane(side)
		var scr := world.director.spawn({"type": "screech", "at": float(s[1]), "lane": lane, "side": side,
			"seed": 3 + lane, "params": {"source": s[2]}}) as Screech
		scr.set_physics_process(false)
		_screeches.append(scr)
		match s[3]:
			"shake":
				scr.phase = Screech.Phase.SHAKE
				scr.get_node("Lair").call(&"set_shaking", true)
			"swipe":
				scr.call(&"_burst_out")
				scr.set(&"_y", 0.0)
				scr.call(&"_place")
				scr.phase = Screech.Phase.SWIPE
			"wall":
				scr.wall_mode = true
				scr.call(&"_burst_out")
				scr.set(&"_x", side * (world.geo.wall_x() - 0.4))
				scr.set(&"_y", 0.0)
				scr.call(&"_place")
				scr.phase = Screech.Phase.VENT_SWIPE


func _process(delta: float) -> void:
	_t += delta
	# Drive the swipes in a loop so the frames show the claw up, striking and back.
	for scr: Screech in _screeches:
		if is_instance_valid(scr) and scr.phase in [Screech.Phase.SWIPE, Screech.Phase.VENT_SWIPE]:
			scr.set(&"_swipe", fmod(_t * 0.8, 1.0))

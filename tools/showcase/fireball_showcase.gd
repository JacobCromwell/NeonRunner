extends Node3D
## Visual check of the shared explosion (task H6, FireballPool): a stage with the player standing still
## and the run camera behind them, and one explosion set off a moment after the scene starts, through the
## real code each one comes from (not for the game). Render frames of it, e.g.:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot4 --path . --resolution 960x540 --fixed-fps 10 \
##     --write-movie build/h6/f.png --quit-after 30 res://tools/showcase/fireball_showcase.tscn -- --scenario=drone
## (add --rendering-method gl_compatibility before the -- for the web / low-end renderer, and --reduced
## for Reduced flashing).
## Scenarios (--scenario=):
##   sizes       fireballs of 1.5, 2.2, 3.4, 7 and 14 m in turn, in the street ahead (--size=N: just that one)
##   drone       a heli drone shot down: it spins and crashes
##   truck       a hover truck stomped: it spins out and explodes
##   buzz        a Buzz Overdrive shot down
##   enforcer    an Enforcer truck wrecked
##   generator   a fence generator destroyed (the EMP ring stays cyan)
##   missile     the heavy missile's blast, set off as its hit does (the cyan ring shows the splash reach;
##               --tier=3 for the plain missile's pop)
##   bomb        a boss's bomb blast, by the size its code gives
## The enemies' scenarios run the stage (the player runs, the camera follows) and set the explosion off by
## defeating them; sizes and bomb stand still. Options: --skin=city|gangland|... (default: the grey box),
## --lanes=N, --reduced, --at=metres ahead,
## --cam=close (a camera beside the event), --delay=seconds before it goes off.

const SIZES: Array[float] = [1.5, 2.2, 3.4, 7.0, 14.0]

var world: RunWorld
var scenario: String = "sizes"
var delay: float = 0.4
var ahead: float = 20.0
var close_cam: bool = false
var side_cam: bool = false
var _t: float = 0.0
var _step: int = 0
var _enemy: Enemy
var _cam: Camera3D
var _focus: Vector3 = Vector3.ZERO
var _lanes: int = 5
var _size_override: float = -1.0
var tier: int = 4


func _ready() -> void:
	var skin_name: String = "greybox"
	var one_size: float = -1.0
	for arg: String in OS.get_cmdline_user_args():
		var v: String = arg.get_slice("=", 1)
		if arg.begins_with("--scenario="):
			scenario = v
		elif arg.begins_with("--skin="):
			skin_name = v
		elif arg.begins_with("--lanes="):
			_lanes = int(v)
		elif arg.begins_with("--size="):
			one_size = float(v)
		elif arg.begins_with("--at="):
			ahead = float(v)
		elif arg.begins_with("--delay="):
			delay = float(v)
		elif arg == "--cam=close":
			close_cam = true
		elif arg == "--cam=side":
			close_cam = true
			side_cam = true
		elif arg.begins_with("--tier="):
			tier = int(v)
		elif arg == "--reduced":
			var profile := Profile.new()
			Settings.set_value(profile, "reduced_flashing", true)
			Settings.apply_visuals(profile)
	var tuning := load("res://data/tuning/movement.tres") as MovementTuning
	var skin: ZoneSkin = (load("res://data/skins/%s_skin.tres" % skin_name) as ZoneSkin).duplicate() as ZoneSkin
	var config := LevelConfig.new()
	config.lane_count = _lanes
	config.skin = skin
	var layout := LevelLayout.new()
	layout.lane_count = _lanes
	layout.length = 600.0
	if scenario == "generator":
		for lane: int in _lanes:
			layout.fences.append({"lane": lane, "at": 60.0, "variant": "full", "pulsing": false,
				"pulse_on": 1.0, "pulse_off": 1.0, "phase": 0.0})
	if scenario == "buzz":
		# A Buzz Overdrive comes with the floor cut it makes (the generator plans both together).
		var rules: GDScript = load("res://scripts/enemies/buzz_overdrive_rules.gd")
		var cut: Dictionary = rules.plan_for(rules.tuning(), _lanes / 2, ahead - 20.0, tuning.run_speed, tuning.pace(), 0.57)
		layout.cuts.append(cut)
		layout.enemies.append({"type": "buzz_overdrive", "at": float(cut["end"]), "lane": _lanes / 2, "side": 0, "seed": 11,
			"params": {}})
	var loadout := Loadout.new()
	if scenario == "missile":
		loadout.tiers[&"weapon"] = tier
	world = RunWorld.new()
	add_child(world)
	world.build(config, layout, tuning, load("res://data/tuning/game_rules.tres") as GameRules,
		load("res://data/tuning/powerups.tres") as PowerupTuning, loadout)
	world.player.god_mode = true
	var env := WorldEnvironment.new()
	env.environment = skin.make_environment()
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
	sun.light_energy = 0.7
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)
	if close_cam:
		_cam = Camera3D.new()
		_cam.fov = 55.0
		add_child(_cam)
		_cam.make_current()
	else:
		var run_cam := RunCamera.new()
		add_child(run_cam)
		run_cam.follow(world)
		run_cam.make_current()
	_focus = world.lane_point(_lanes / 2, ahead, 1.4)
	match scenario:
		"drone":
			_enemy = world.director.spawn({"type": "drone", "at": ahead + 6.0, "lane": _lanes / 2, "side": 0, "seed": 4,
				"params": {"slot": 0}})
		"truck":
			_enemy = world.director.spawn({"type": "hover_truck", "at": ahead, "lane": _lanes - 1, "side": 1, "seed": 5,
				"params": {"skip_entrance": true, "phase": "pace", "offset": ahead, "guns": false}})
		"buzz":
			pass
		"enforcer":
			_enemy = world.director.spawn({"type": "enforcer_truck", "at": ahead, "lane": _lanes / 2, "seed": 1,
				"params": {}})
		"generator":
			_enemy = world.director.spawn({"type": "generator", "at": ahead, "lane": _lanes / 2, "side": 0, "seed": 3,
				"params": {}})
	_size_override = one_size
	if scenario != "sizes" and scenario != "bomb":
		world.start()


func _physics_process(delta: float) -> void:
	_t += delta
	if scenario == "sizes":
		var list: Array[float] = SIZES.duplicate()
		if _size_override > 0.0:
			list = [_size_override]
		var due: int = int((_t - delay) / 2.6) if _t >= delay else -1
		while _step <= due and _step < list.size():
			_play_size(list[_step])
			_step += 1
		return
	if _t < delay or _step > 0:
		return
	if scenario == "drone" and is_instance_valid(_enemy) and int(_enemy.get(&"state")) != 2:
		return
	if scenario == "buzz" and not _buzz_ready():
		return
	_step = 1
	match scenario:
		"missile":
			# What WeaponPowerup does on a missile's hit (the plain missile's pop, or the heavy one's blast).
			var spot: Vector3 = world.lane_point(_lanes / 2, ahead, 1.4)
			if tier >= 4:
				world.powerups.weapon.fx.blast(spot, world.powerup_tuning.splash_radius)
			else:
				world.powerups.weapon.fx.missile_pop(spot)
		"drone", "truck", "buzz", "enforcer", "generator":
			if scenario == "buzz" and _enemy == null:
				for e: Enemy in world.director.active:
					if e.type_id == &"buzz_overdrive":
						_enemy = e
			if is_instance_valid(_enemy):
				_focus = _enemy.global_position + Vector3(0.0, 1.2, 0.0)
				_enemy.defeat(&"weapon")
		"bomb":
			world.effects.fireball(world.lane_point(_lanes / 2, ahead, 0.6), 1.7, false, 1.3)


## Whether the Buzz Overdrive is in play, on screen and within 45 m (it is made when the runner nears it).
func _buzz_ready() -> bool:
	for e: Enemy in world.director.active:
		if e.type_id == &"buzz_overdrive" and e.alive and e.visible \
				and e.global_position.distance_to(world.player.global_position) < 45.0:
			return true
	return false


func _play_size(size: float) -> void:
	world.effects.fireball(world.lane_point(_lanes / 2, ahead, size * 0.35 + 0.6), size)
	print("fireball size ", size)


func _process(_delta: float) -> void:
	if _cam == null:
		return
	var at: Vector3 = _focus
	if is_instance_valid(_enemy) and _enemy.alive:
		at = _enemy.global_position + Vector3(0.0, 1.2, 0.0)
	_cam.global_position = Vector3(at.x + 15.0, at.y, at.z) if side_cam else Vector3(at.x + 2.5, at.y + 0.2, at.z + 12.0)
	_cam.look_at(at, Vector3.UP)

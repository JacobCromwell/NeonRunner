extends Node3D
## Visual check for the power-ups (a dev tool, not part of the game or the test run): a RunWorld
## with the full loadout and dummy enemies pacing ahead, so the shots, missiles, splash, health
## bars, dash, magnet field and slow-time tint can be rendered and looked at. For example, with the
## Compatibility renderer at 10 fps:
##   godot --path . res://tests/showcase/powerups_showcase.tscn --rendering-method gl_compatibility \
##     --fixed-fps 10 --write-movie build/showcase/f.png --quit-after 60 -- --tier=4 --dash=2.5
## Args after `--`: --tier=1..4 (weapon tier, default 4), --lanes=N (default 5), --dash=S and
## --slow=S (use them S seconds in), --wall=S (run onto the right wall), --ceiling=M (an anti-grav
## pad and a ship hull M metres in), --no-hud (hide the hud_state readout).

const PACER: String = "res://tests/helpers/pacing_dummy.gd"
const DUMMY: String = "res://tests/helpers/dummy_enemy.gd"
const RESPAWN_DELAY: float = 1.2

var world: RunWorld
var camera: RunCamera
var controller: PowerupController

var _tier: int = 4
var _lanes: int = 5
var _dash_at: float = -1.0
var _slow_at: float = -1.0
var _wall_at: float = -1.0
var _ceiling_at: float = -1.0
var _show_hud: bool = true
var _time: float = 0.0
## Pacing enemies kept in play: {lead, lane, params, enemy, wait}.
var _slots: Array[Dictionary] = []
var _hud: Label


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var v: String = arg.get_slice("=", 1)
		if arg.begins_with("--tier="):
			_tier = clampi(int(v), 1, 4)
		elif arg.begins_with("--lanes="):
			_lanes = maxi(int(v), 3)
		elif arg.begins_with("--dash="):
			_dash_at = float(v)
		elif arg.begins_with("--slow="):
			_slow_at = float(v)
		elif arg.begins_with("--wall="):
			_wall_at = float(v)
		elif arg.begins_with("--ceiling="):
			_ceiling_at = float(v)
		elif arg == "--no-hud":
			_show_hud = false
	_build_world()


func _build_world() -> void:
	var tuning := load("res://data/tuning/movement.tres") as MovementTuning
	var layout := LevelLayout.new()
	layout.lane_count = _lanes
	layout.length = 3000.0
	var c: int = _lanes / 2
	for i: int in 60:
		var lane: int = c - 1 if i % 2 == 0 else c + 1
		layout.credits.append({"at": 12.0 + i * 3.5, "surface": "floor", "lane": lane, "side": 0, "height": 0.7,
			"value": 5 if i % 5 == 0 else 1})
	if _ceiling_at > 0.0:
		layout.pads.append({"lane": c, "at": _ceiling_at})
		layout.hulls.append({"start": _ceiling_at - 3.0, "end": _ceiling_at + 90.0})
	var config := LevelConfig.new()
	config.lane_count = _lanes
	var loadout: Loadout = Loadout.full(App.catalog)
	loadout.tiers[&"weapon"] = _tier
	world = RunWorld.new()
	world.name = "World"
	add_child(world)
	world.build(config, layout, tuning, load("res://data/tuning/game_rules.tres") as GameRules,
		load("res://data/tuning/powerups.tres") as PowerupTuning, loadout, App.sfx_library)
	world.player.god_mode = true
	controller = world.powerups as PowerupController

	var env := WorldEnvironment.new()
	env.environment = world.skin.make_environment()
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
	sun.light_energy = 0.7
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)
	camera = RunCamera.new()
	add_child(camera)
	camera.make_current()
	camera.follow(world)

	# Targets: a tough one ahead, a mid one, a screech-like one, a host (never shot, no bar) and a
	# swarm cluster behind them for the heavy missile's splash.
	_slot(24.0, c, {"health": 15.0})
	_slot(32.0, c - 1, {"health": 5.0})
	_slot(28.0, c + 1, {"health": 15.0, "host": true})
	_slot(40.0, mini(c + 2, _lanes - 1), {"health": 1.0})
	_slot(52.0, c - 1, {"health": 12.0, "swarm": true})
	_slot(52.0, c, {"health": 12.0, "swarm": true, "height": 1.3})
	_slot(52.0, c + 1, {"health": 12.0, "swarm": true})
	if _dash_at >= 0.0:
		# A plain enemy in the player's lane, right where the dash will hit it.
		var at: float = tuning.run_speed * _dash_at + 12.0
		world.director.spawn({"type": "dummy", "script": DUMMY, "at": at, "lane": c, "seed": 9, "params": {"health": 50.0}})

	if _show_hud:
		var layer := CanvasLayer.new()
		layer.layer = 6
		add_child(layer)
		_hud = Label.new()
		_hud.position = Vector2(14.0, 10.0)
		_hud.add_theme_font_size_override(&"font_size", 15)
		_hud.add_theme_color_override(&"font_outline_color", Color.BLACK)
		_hud.add_theme_constant_override(&"outline_size", 4)
		layer.add_child(_hud)
	world.start()


func _slot(lead: float, lane: int, params: Dictionary) -> void:
	_slots.append({"lead": lead, "lane": clampi(lane, 0, _lanes - 1), "params": params, "enemy": null, "wait": 0.0})


func _physics_process(delta: float) -> void:
	if world == null:
		return
	_time += delta
	if _dash_at >= 0.0 and _time >= _dash_at:
		_dash_at = -1.0
		controller.try_dash()
	if _slow_at >= 0.0 and _time >= _slow_at:
		_slow_at = -1.0
		controller.try_slow_time()
	if _wall_at >= 0.0 and _time >= _wall_at:
		_wall_at = -1.0
		for i: int in _lanes:
			world.player.press(&"move_right")
	for s: Dictionary in _slots:
		var e: Variant = s["enemy"]
		if e != null and is_instance_valid(e) and (e as Enemy).alive:
			continue
		s["wait"] = float(s["wait"]) - delta
		if float(s["wait"]) > 0.0 and e != null:
			continue
		var p: Dictionary = (s["params"] as Dictionary).duplicate()
		p["lead"] = float(s["lead"]) + (10.0 if e != null else 0.0)
		s["enemy"] = world.director.spawn({"type": "dummy", "script": PACER, "at": world.player_distance() + float(p["lead"]),
			"lane": s["lane"], "seed": 1, "params": p})
		s["wait"] = RESPAWN_DELAY


func _process(_delta: float) -> void:
	if _hud == null or controller == null:
		return
	var lines: PackedStringArray = ["t %.1f s   time scale %.2f   %s" % [_time, Engine.time_scale, controller.equipment()]]
	for e: Dictionary in controller.hud_state():
		lines.append("%-10s tier %d  ready %.2f  %s  charges %d" % [e["id"], e["tier"], e["ready"],
			"ACTIVE" if e["active"] else "      ", e["charges"]])
	_hud.text = "\n".join(lines)

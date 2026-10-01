extends Node3D
## Showcase of the Barnacle Turret (GDD §9.8), for visual review only (not part of the game). Render it
## on the Compatibility renderer too, e.g.
##   xvfb-run -a godot4 --path . --rendering-method gl_compatibility --resolution 960x540 --fixed-fps 10 \
##     --write-movie build/bt/f.png --quit-after 60 res://tools/showcase/barnacle_turret_showcase.tscn -- --view=ride
## Views:
##   model (default)  both looks close up under a strip of the skin's ceiling, from below and in front:
##                    the creature (Gangland and the Marketplace) and the mechanical turret (every other
##                    zone), each at rest on the left and charging (its muzzle swelling red) on the right
##   floor            a real RunWorld through the run camera: a runner passes the pad by and runs under a
##                    ceiling with turrets; they pop out as the runner nears and never fire down
##   ride             the same ceiling, ridden: the runner takes the pad, a turret charges up and fires,
##                    the runner switches lanes once the charge-up is over, and rides on past it (god
##                    mode, so nothing ends the run)
## Options: --close (floor and ride: a camera beside the next turret on the player's side, below the ceiling,
## three-quarter on to its face, instead of the run camera), --skin=<zone id> (data/skins/<id>_skin.tres; default
## marketplace), --lanes=N (default 3),
## --variant=<name> (another look: a skin's enemy_variant such as casino or vr_runner), --pair (a second
## turret on the ceiling), --reduced (Reduced flashing on), --nolabel.

const AT_PAD: float = 43.0
const CEIL_FROM: float = 40.0
const CEIL_TO: float = 150.0

var _world: RunWorld
var _camera: Camera3D
var _view: String = "model"
var _lanes: int = 3
var _close: bool = false
var _guns: Array[CyborgGun] = []
var _turret_lanes: Array[int] = []
var _models: Array[BarnacleTurretModel] = []
## Gun index → the burst (its count of charge-ups) the ride already dodged.
var _dodged: Dictionary = {}
var _t: float = 0.0


func _ready() -> void:
	var skin_name: String = "marketplace"
	var variant: String = ""
	var pair: bool = false
	for arg: String in OS.get_cmdline_user_args():
		var v: String = arg.get_slice("=", 1)
		if arg.begins_with("--view="):
			_view = v
		elif arg.begins_with("--lanes="):
			_lanes = int(v)
		elif arg.begins_with("--skin="):
			skin_name = v
		elif arg.begins_with("--variant="):
			variant = v
		elif arg == "--pair":
			pair = true
		elif arg == "--close":
			_close = true
		elif arg == "--reduced":
			RenderingServer.global_shader_parameter_set(&"reduced_flashing", 1.0)
			Settings.flashing_reduced = true
	var tuning := load("res://data/tuning/movement.tres") as MovementTuning
	var config := LevelConfig.new()
	config.lane_count = _lanes
	config.enemy_scaling = 0.43
	var skin_path: String = "res://data/skins/%s_skin.tres" % skin_name
	var skin: ZoneSkin = load(skin_path) as ZoneSkin if ResourceLoader.exists(skin_path) else null
	if skin != null and variant != "":
		skin = skin.duplicate() as ZoneSkin
		skin.enemy_variant = StringName(variant)
	config.skin = skin
	var pad_lane: int = _lanes / 2
	var layout := LevelLayout.new()
	layout.lane_count = _lanes
	layout.length = 600.0
	layout.hulls.append({"start": CEIL_FROM, "end": CEIL_TO})
	layout.pads.append({"lane": pad_lane, "at": AT_PAD})
	_world = RunWorld.new()
	add_child(_world)
	_world.build(config, layout, tuning, load("res://data/tuning/game_rules.tres") as GameRules,
		load("res://data/tuning/powerups.tres") as PowerupTuning)
	_world.player.god_mode = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sun.light_energy = 0.8
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = _world.skin.make_environment()
	add_child(env)
	var look: StringName = _world.skin.enemy_variant
	if _view == "model":
		_build_model_view()
	else:
		var spots: Array = [[100.0, maxi(pad_lane - 1, 0)]]
		if pair:
			spots.append([125.0, mini(pad_lane + 1, _lanes - 1)])
		for k: int in spots.size():
			var t := _world.director.spawn({"type": "barnacle_turret", "at": float(spots[k][0]), "lane": int(spots[k][1]),
				"side": 0, "seed": 11 + k, "params": {"hull_start": CEIL_FROM, "hull_end": CEIL_TO, "first_lane": 0,
				"last_lane": _lanes - 1}}) as BarnacleTurret
			_guns.append(t.gun)
			_turret_lanes.append(int(spots[k][1]))
		if _close:
			_camera = Camera3D.new()
			_camera.fov = 60.0
			_camera.far = 400.0
			add_child(_camera)
		else:
			var cam := RunCamera.new()
			add_child(cam)
			cam.follow(_world)
			_camera = cam
		_camera.make_current()
		_world.start()
	if not OS.get_cmdline_user_args().has("--nolabel"):
		_caption("Barnacle Turret: %s, %s look (%s), %d lanes%s" % [_view,
			"creature" if BarnacleTurretModel.is_creature(look) else "mechanical", look, _lanes,
			", Reduced flashing" if Settings.flashing_reduced else ""])


## Both looks under the ceiling's underside, at rest and charging, the camera below and in front.
func _build_model_view() -> void:
	_world.player.visible = false
	var h: float = _world.tuning.ceiling_height
	var looks: Array[StringName] = [&"casino", &"vr_runner"]
	var z: float = -60.0
	for i: int in 4:
		var m := BarnacleTurretModel.new()
		add_child(m)
		m.build(looks[i / 2], 20 + i)
		m.position = Vector3(-3.3 + 2.2 * i, h, z)
		m.set_charge(0.0 if i % 2 == 0 else 0.85)
		_models.append(m)
		if not OS.get_cmdline_user_args().has("--nolabel"):
			_label(m.position + Vector3(0.0, -1.35, 0.6), "%s, %s" % ["creature" if i < 2 else "mechanical",
				"at rest" if i % 2 == 0 else "charging"])
	_camera = Camera3D.new()
	_camera.fov = 50.0
	add_child(_camera)
	_camera.position = Vector3(0.0, h - 2.6, z + 6.5)
	_camera.look_at(Vector3(0.0, h - 0.6, z))
	_camera.make_current()


func _process(delta: float) -> void:
	_t += delta
	if _view == "model":
		# The models watch a point swinging slowly in front of them (their idle turn and the eyes).
		var p := Vector3(sin(_t * 0.8) * 3.0, _world.tuning.ceiling_height - 1.0, -54.0)
		for m: BarnacleTurretModel in _models:
			m.watch(p)
	elif _close and _world != null:
		# Beside the next turret on the player's side, below the ceiling, three-quarter on to its face (its
		# charge-up and its bolts leaving); behind the player once none is left ahead.
		var player: Vector3 = _world.player.global_position
		var turret: BarnacleTurret = null
		for e: Enemy in _world.director.active:
			if e is BarnacleTurret and e.alive and e.track_distance() > _world.player.distance - 1.0:
				turret = e as BarnacleTurret
				break
		if turret != null:
			var at: Vector3 = turret.aim_point()
			_camera.position = at + Vector3(3.0, -2.3, 6.0)
			_camera.look_at(at + Vector3(0.0, -0.3, 1.5))
		else:
			_camera.position = player + Vector3(1.5, -1.5, 6.0)
			_camera.look_at(player + Vector3(0.0, 0.0, -20.0))


## The floor view: the runner passes the pad by, into the first turret's lane, and runs right under it.
## The ride: the runner takes the pad, then switches lanes away from each burst once its charge-up is
## over (never into a turret's lane).
func _physics_process(_delta: float) -> void:
	if _world == null or _view == "model" or _guns.is_empty():
		return
	var p: Player = _world.player
	if _view == "floor":
		if p.surface == Player.Surface.FLOOR and p.lane != _turret_lanes[0] and p.distance > AT_PAD - 18.0 \
				and p.distance < AT_PAD and absf(p.global_position.x - _world.geo.lane_x(p.lane)) < 0.05:
			p.press(&"move_left" if _turret_lanes[0] < p.lane else &"move_right")
		return
	for k: int in _guns.size():
		var bursts: int = _guns[k].events.filter(func(e: Dictionary) -> bool: return e["event"] == &"charge").size()
		if _guns[k].state != CyborgGun.State.FIRING or p.surface != Player.Surface.CEILING or _dodged.get(k, -1) == bursts:
			continue
		_dodged[k] = bursts
		for dir: int in [1, -1]:
			var to: int = p.lane + dir
			if to >= 0 and to < _lanes and not _turret_lanes.has(to):
				p.press(&"move_right" if dir > 0 else &"move_left")
				break


func _caption(text: String) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.text = text
	label.position = Vector2(16.0, 10.0)
	label.add_theme_font_size_override(&"font_size", 20)
	label.add_theme_color_override(&"font_color", Color(0.85, 0.9, 1.0))
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0))
	label.add_theme_constant_override(&"outline_size", 6)
	layer.add_child(label)


func _label(at: Vector3, text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.position = at
	l.font_size = 40
	l.pixel_size = 0.004
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.outline_size = 8
	add_child(l)

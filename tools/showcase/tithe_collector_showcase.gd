extends Node3D
## Showcase of the Tithe Collector (GDD §9.12, task C5), for visual review only (not part of the
## game). Render it on the Compatibility renderer too, e.g.
##   xvfb-run -a godot4 --path . --rendering-method gl_compatibility --resolution 960x540 \
##     --fixed-fps 10 --write-movie build/tc/f.png --quit-after 180 \
##     res://tools/showcase/tithe_collector_showcase.tscn -- --skin=corporate_plaza
## A real RunWorld, a credit trail and a gap off to one side (so it has somewhere to weave toward),
## run by a god-mode player through the run camera. Two collectors in sequence:
## 1. the player holds its lane: shows the vacuum (the coin stream into it) and then the theft
##    (it touches the player, the HUD's credits dip, it flees);
## 2. the player follows it and jumps onto it as it closes in: the catch (it bursts, pays out).
## Options: --lanes=N (default 5), --skin=<name> (data/skins/<name>_skin.tres, default the grey box),
## --nolabel.

const AT_FIRST: float = 40.0
const AT_SECOND: float = 220.0

var _world: RunWorld
var _camera: RunCamera
var _lanes: int = 5
var _jumped: bool = false


func _ready() -> void:
	var skin_name: String = ""
	for arg: String in OS.get_cmdline_user_args():
		var v: String = arg.get_slice("=", 1)
		if arg.begins_with("--lanes="):
			_lanes = int(v)
		elif arg.begins_with("--skin="):
			skin_name = v
	var tuning := load("res://data/tuning/movement.tres") as MovementTuning
	var config := LevelConfig.new()
	config.lane_count = _lanes
	var skin_path: String = "res://data/skins/%s_skin.tres" % skin_name
	config.skin = load(skin_path) as ZoneSkin if skin_name != "" and ResourceLoader.exists(skin_path) else null
	var layout := LevelLayout.new()
	layout.lane_count = _lanes
	layout.length = 400.0
	_build_credits(layout)
	# A gap off to one side, only near the second collector: it has somewhere more dangerous than the
	# player's own lane to weave toward, and the player follows it there for the catch.
	var side_lane: int = _lanes - 1
	for at: float in [AT_SECOND + 14.0, AT_SECOND + 20.0, AT_SECOND + 26.0]:
		layout.gaps.append({"lane": side_lane, "start": at, "end": at + 1.3})
	_world = RunWorld.new()
	add_child(_world)
	var loadout := Loadout.new()
	loadout.charges[&"grapple"] = 999  # chasing it into the gap lane never ends the run on a fall.
	_world.build(config, layout, tuning, load("res://data/tuning/game_rules.tres") as GameRules,
		load("res://data/tuning/powerups.tres") as PowerupTuning, loadout)
	_world.player.setup(tuning, _world.geo, _lanes / 2)
	_world.player.god_mode = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sun.light_energy = 0.8
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = _world.skin.make_environment()
	add_child(env)
	_world.director.spawn({"type": "tithe_collector", "at": AT_FIRST, "lane": _lanes / 2, "side": 0, "seed": 1})
	_camera = RunCamera.new()
	add_child(_camera)
	_camera.follow(_world)
	_camera.make_current()
	_world.start()
	if not OS.get_cmdline_user_args().has("--nolabel"):
		_caption("Tithe Collector: the vacuum and a theft, then a catch (%d lanes)" % _lanes)


## A trail of small credits down the middle lane, so the first collector has something to vacuum
## right along its path (GDD §9.12: "sucks up the credits in its path").
func _build_credits(layout: LevelLayout) -> void:
	var lane: int = layout.lane_count / 2
	var at: float = AT_FIRST + 4.0
	while at < AT_FIRST + 30.0:
		layout.credits.append({"at": at, "surface": "floor", "lane": lane, "side": 0, "height": 0.7, "value": 5})
		at += 3.0
	at = AT_SECOND + 4.0
	while at < AT_SECOND + 30.0:
		layout.credits.append({"at": at, "surface": "floor", "lane": lane, "side": 0, "height": 0.7, "value": 5})
		at += 3.0


## Holds its lane for the first collector (the vacuum and the theft); for the second, follows it
## into the lane it weaves toward and jumps onto it as it closes in (the catch). Spawns the second
## once the first is gone.
func _physics_process(_delta: float) -> void:
	if _world == null or not is_instance_valid(_world.player):
		return
	var p: Player = _world.player
	if p.distance > AT_FIRST + 45.0 and p.distance < AT_SECOND - 20.0 and _world.director.count_alive(&"tithe_collector") == 0:
		_world.director.spawn({"type": "tithe_collector", "at": AT_SECOND, "lane": _lanes / 2, "side": 0, "seed": 2})
	if p.distance < AT_SECOND:
		return
	for e: Enemy in _world.director.active:
		if e.type_id != &"tithe_collector" or not e.alive:
			continue
		var c: TitheCollector = e as TitheCollector
		if c.state != TitheCollector.State.APPROACH:
			continue
		if p.lane < c.target_lane:
			p.press(&"move_right")
		elif p.lane > c.target_lane:
			p.press(&"move_left")
		elif c.rel_ahead <= 3.0 and p.grounded:
			p.press(&"jump")
			_jumped = true


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

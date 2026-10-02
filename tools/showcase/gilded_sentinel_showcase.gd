extends Node3D
## Showcase of the Gilded Sentinels (GDD §9.11), for visual review only (not part of the game): a real
## RunWorld on a Golden Zone street with Sentinels in its walls (placed in the layout, so the skin opens
## their niches) and a runner in god mode taking one route past each. Render it on both renderers, e.g.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot4 --path . --resolution 960x540 --fixed-fps 10 \
##     --write-movie build/sentinel/f.png --quit-after 60 res://tools/showcase/gilded_sentinel_showcase.tscn \
##     -- --view=close --route=lane
## (add --rendering-method gl_compatibility before the scene path for the web / low-end renderer).
## Views:
##   play (default)  the run camera behind the runner
##   close           a camera across the street from the next Sentinel, looking at its niche as the runner
##                   comes: the warning (its eyes flare, the marks of its cut light up), the swing
##   wall            a camera low on the far side, looking along the Sentinel's wall as the runner passes it
## Routes (--route=): floor (stays in the outer lane: the cut passes through the god-mode runner), lane
## (the lane beside it, safe), high (jumps onto its wall just before it and runs above the band; --kick
## jumps off right by its head and kicks it), low (onto the wall early, below the band).
## Options: --skin=<name> (data/skins/<name>_skin.tres; default golden, golden_palace for the Palace),
## --lanes=N (default 5), --double (each swings twice), --pair (two facing each other), --side=left|right
## (default left), --count=N Sentinels every SPACING metres (default 3), --speed=N (m/s; default 25, the
## Golden Zone's), --reduced (Reduced flashing), --nolabel.

const FIRST: float = 92.0
const SPACING: float = 80.0

var _world: RunWorld
var _camera: Camera3D
var _view: String = "play"
var _route: String = "lane"
var _kick: bool = false
var _side: int = -1
var _spots: Array[float] = []
var _tune: GildedSentinelTuning
var _swings: int = 1


func _ready() -> void:
	var skin_name: String = "golden"
	var lanes: int = 5
	var pair: bool = false
	var count: int = 3
	var speed: float = 25.0
	for arg: String in OS.get_cmdline_user_args():
		var v: String = arg.get_slice("=", 1)
		if arg.begins_with("--view="):
			_view = v
		elif arg.begins_with("--route="):
			_route = v
		elif arg == "--kick":
			_kick = true
		elif arg.begins_with("--skin="):
			skin_name = v
		elif arg.begins_with("--lanes="):
			lanes = int(v)
		elif arg == "--double":
			_swings = 2
		elif arg == "--pair":
			pair = true
		elif arg.begins_with("--side="):
			_side = 1 if v == "right" else -1
		elif arg.begins_with("--count="):
			count = maxi(int(v), 1)
		elif arg.begins_with("--speed="):
			speed = float(v)
		elif arg == "--reduced":
			RenderingServer.global_shader_parameter_set(&"reduced_flashing", 1.0)
			Settings.flashing_reduced = true
	_tune = EnemyDirector.tuning_for("gilded_sentinel") as GildedSentinelTuning
	var tuning := load("res://data/tuning/movement.tres") as MovementTuning
	var config := LevelConfig.new()
	config.lane_count = lanes
	config.run_speed = speed
	config.enemy_scaling = 1.0
	var skin_path: String = "res://data/skins/%s_skin.tres" % skin_name
	config.skin = load(skin_path) as ZoneSkin if ResourceLoader.exists(skin_path) else null
	var layout := LevelLayout.new()
	layout.lane_count = lanes
	layout.length = FIRST + SPACING * count + 200.0
	var rules := load("res://scripts/enemies/gilded_sentinel_rules.gd") as GDScript
	for k: int in count:
		var at: float = rules.call("in_chunk", _tune, FIRST + SPACING * k)
		_spots.append(at)
		var sides: Array[int] = [_side]
		if pair:
			sides.append(-_side)
		for s: int in sides:
			layout.enemies.append({"type": "gilded_sentinel", "at": at, "lane": layout.outer_lane(s), "side": s,
				"seed": 7 + k, "params": {"swings": _swings}})
	_world = RunWorld.new()
	add_child(_world)
	_world.build(config, layout, tuning, load("res://data/tuning/game_rules.tres") as GameRules,
		load("res://data/tuning/powerups.tres") as PowerupTuning)
	var outer: int = layout.outer_lane(_side)
	_world.player.setup(_world.tuning, _world.geo, outer if _route != "lane" else outer - _side)
	_world.player.god_mode = true
	var env := WorldEnvironment.new()
	env.environment = _world.skin.make_environment()
	add_child(env)
	if _view == "play":
		var cam := RunCamera.new()
		add_child(cam)
		cam.follow(_world)
		_camera = cam
	else:
		_camera = Camera3D.new()
		_camera.fov = 60.0
		_camera.far = 600.0
		add_child(_camera)
	_camera.make_current()
	_world.start()
	if not OS.get_cmdline_user_args().has("--nolabel"):
		_caption("Gilded Sentinel: %s view, route %s%s, %d lanes, %s%s%s" % [_view, _route, " + kick" if _kick else "",
			lanes, skin_name, ", swings twice" if _swings == 2 else (", a pair" if pair else ""),
			", Reduced flashing" if Settings.flashing_reduced else ""])


## The next Sentinel's spot ahead of the runner (or the last one).
func _next_spot() -> float:
	var p: float = _world.player.distance
	for at: float in _spots:
		if at + _tune.section_length > p:
			return at
	return _spots[-1]


func _process(_delta: float) -> void:
	if _world == null or _view == "play":
		return
	var at: float = _next_spot()
	var wall_x: float = _world.geo.wall_x()
	var niche := Vector3(_side * wall_x, 2.0, TrackGeometry.world_z(at))
	if _view == "close":
		_camera.position = Vector3(-_side * 1.2, 2.7, TrackGeometry.world_z(at - 10.0))
		_camera.look_at(niche + Vector3(-_side * 1.0, -0.2, 0.0))
	elif _view == "front":
		_camera.position = Vector3(_side * (wall_x - 4.5), 2.2, TrackGeometry.world_z(at - 2.5))
		_camera.look_at(niche)
	else:
		_camera.position = Vector3(-_side * (wall_x - 1.0), 1.4, TrackGeometry.world_z(at + 9.0))
		_camera.look_at(Vector3(_side * (wall_x - 0.4), 2.0, TrackGeometry.world_z(at - 4.0)))


## The runner's route past each Sentinel (see the header), pressing only named actions.
func _physics_process(_delta: float) -> void:
	if _world == null:
		return
	var p: Player = _world.player
	var v: float = maxf(p.speed, 1.0)
	var at: float = _next_spot()
	var guard: Vector2 = _tune.guarded_stretch(at, _swings)
	var toward: StringName = &"move_left" if _side < 0 else &"move_right"
	match _route:
		"high":
			# Jump in the outer lane, then onto the wall at the jump's top, just before the stretch.
			var jump_at: float = guard.x - 0.55 * v
			if p.surface == Player.Surface.FLOOR and p.grounded and p.distance >= jump_at and p.distance < guard.x - 0.3 * v:
				p.press(&"jump")
			elif p.surface == Player.Surface.FLOOR and not p.grounded and p.vh <= 0.5 and p.distance < guard.x:
				p.press(toward)
			elif _kick and p.surface == Player.Surface.WALL and p.distance >= at - 0.7 and p.distance < at:
				p.press(&"jump")
		"low":
			if p.surface == Player.Surface.FLOOR and p.grounded and p.distance >= guard.x - 1.65 * v \
					and p.distance < guard.x - 1.3 * v:
				p.press(toward)


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

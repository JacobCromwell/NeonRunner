extends Node3D
## Showcase of the Cyborg's Bad Dream, for visual review only (not part of the game). Render it with
## the Compatibility renderer, e.g.
##   xvfb-run -a $GODOT --path . --rendering-method gl_compatibility --resolution 960x540 --fixed-fps 10 \
##     --write-movie build/bd/f.png --quit-after 230 res://tools/showcase/bad_dream_showcase.tscn -- --view=play
## A real RunWorld with a scripted player in god mode (so every slash shows without ending the run):
## the player dashes into a host (the Bad Dream bursts out), sits out one slash and dodges the next,
## runs through fences it floats through, takes an anti-grav pad (it waits below), comes back down,
## and outlasts the chase until it dissolves.
## Views: play (default, the real run camera) or close (a camera beside the player, looking at it).
## Options: --lanes=N, --skin=<name> (data/skins/<name>_skin.tres), --chase=seconds (default 16),
## --wall (dodge onto a wall rather than to a lane), --reduced (Reduced flashing on).

const HOST_AT: float = 70.0
const PAD_AT: float = 250.0
const HULL_SECONDS: float = 4.0

var _world: RunWorld
var _camera: Camera3D
var _close: bool = false
var _dream: BadDream
var _host: Enemy
var _lane: int = 2
var _chase: float = 16.0
var _to_wall: bool = false
var _telegraphs_seen: int = 0
var _dodge_at: float = -1.0
var _dodge_dir: int = 0
var _dodge_moves: int = 0


func _ready() -> void:
	var lanes: int = 5
	var skin_name: String = "city"
	for arg: String in OS.get_cmdline_user_args():
		var v: String = arg.get_slice("=", 1)
		if arg.begins_with("--lanes="):
			lanes = int(v)
		elif arg.begins_with("--skin="):
			skin_name = v
		elif arg.begins_with("--chase="):
			_chase = float(v)
		elif arg == "--view=close":
			_close = true
		elif arg == "--wall":
			_to_wall = true
		elif arg == "--reduced":
			RenderingServer.global_shader_parameter_set(&"reduced_flashing", 1.0)
	_lane = lanes / 2
	var tuning := load("res://data/tuning/movement.tres") as MovementTuning
	var config := LevelConfig.new()
	config.lane_count = lanes
	config.enemy_scaling = 0.8
	var skin_path: String = "res://data/skins/%s_skin.tres" % skin_name
	config.skin = load(skin_path) as ZoneSkin if ResourceLoader.exists(skin_path) else null
	var layout := LevelLayout.new()
	layout.lane_count = lanes
	layout.length = 1000.0
	# Fences it floats straight through, and a ship to escape up to.
	for lane: int in lanes:
		if lane < lanes / 2:
			layout.fences.append({"lane": lane, "at": 150.0, "variant": "full", "pulsing": false,
				"pulse_on": 1.0, "pulse_off": 1.0, "phase": 0.0})
		elif lane > lanes / 2:
			layout.fences.append({"lane": lane, "at": 195.0, "variant": "gapped", "pulsing": false,
				"pulse_on": 1.0, "pulse_off": 1.0, "phase": 0.0})
	layout.pads.append({"lane": _lane, "at": PAD_AT})
	layout.hulls.append({"start": PAD_AT - config.hull_lead_in, "end": PAD_AT + HULL_SECONDS * tuning.run_speed})
	_world = RunWorld.new()
	add_child(_world)
	_world.build(config, layout, tuning, load("res://data/tuning/game_rules.tres") as GameRules,
		load("res://data/tuning/powerups.tres") as PowerupTuning)
	_world.player.setup(tuning, _world.geo, _lane)
	_world.player.god_mode = true
	_world.director.enemy_spawned.connect(_on_spawned)
	_host = _world.director.spawn({"type": "cyborg", "at": HOST_AT, "lane": _lane, "side": 0, "seed": 3,
		"params": {"host": true, "panic": false, "fires": false}})
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
	sun.light_energy = 0.7
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = _world.skin.make_environment()
	add_child(env)
	if _close:
		_camera = Camera3D.new()
		_camera.fov = 60.0
		add_child(_camera)
	else:
		var cam := RunCamera.new()
		add_child(cam)
		cam.follow(_world)
		_camera = cam
	_camera.make_current()
	_world.start()


func _on_spawned(enemy: Enemy) -> void:
	if enemy is BadDream and _dream == null:
		_dream = enemy as BadDream
		_dream.chase_seconds = _chase


## The scripted player: dash into the host, sit out the first slash, dodge the next, take the pad.
func _physics_process(_delta: float) -> void:
	var p: Player = _world.player
	if is_instance_valid(_host) and _host.alive and _host.track_distance() - p.distance < 7.0 and not p.dashing:
		p.start_dash(0.6, 8.0)
	if is_instance_valid(_dream) and _dream.alive:
		var told: int = 0
		for h: Array in _dream.history:
			if h[0] == "telegraph":
				told += 1
		if told > _telegraphs_seen:
			_telegraphs_seen = told
			if told % 2 == 0:
				_plan_dodge(p)
	if _dodge_at >= 0.0 and _world.level_time() >= _dodge_at:
		for i: int in _dodge_moves:
			p.press(&"move_left" if _dodge_dir < 0 else &"move_right")
		_dodge_at = -1.0
	# Line up with the pad's lane once it's close.
	if p.surface == Player.Surface.FLOOR and PAD_AT - p.distance > 10.0 and PAD_AT - p.distance < 45.0 \
			and p.lane != _lane and _dodge_at < 0.0:
		p.press(&"move_left" if p.lane > _lane else &"move_right")


func _plan_dodge(p: Player) -> void:
	var n: int = _world.geo.lane_count
	var b: Vector2i = _dream.band
	_dodge_at = _world.level_time() + 0.35
	if _to_wall:
		_dodge_dir = -1 if p.lane < n / 2 else 1
		_dodge_moves = (p.lane + 1) if _dodge_dir < 0 else (n - p.lane)
		return
	var left: int = p.lane - (b.x - 1)
	var right: int = (b.y + 1) - p.lane
	if b.x - 1 >= 0 and (b.y + 1 >= n or left <= right):
		_dodge_dir = -1
		_dodge_moves = left
	else:
		_dodge_dir = 1
		_dodge_moves = right


func _process(_delta: float) -> void:
	if not _close or _world == null:
		return
	var p: Vector3 = _world.player.position
	var target: Vector3 = _dream.head_point() + Vector3(0.0, -0.6, 0.0) if is_instance_valid(_dream) \
		else p + Vector3(0.0, 1.5, -8.0)
	_camera.position = p + Vector3(3.6, 2.0, 1.5)
	_camera.look_at(target)

extends Node3D
## Showcase of the Resonator (GDD §9.10), for visual review only (not part of the game). Render it on the
## Compatibility renderer too, e.g.
##   xvfb-run -a godot4 --path . --rendering-method gl_compatibility --resolution 960x540 --fixed-fps 10 \
##     --write-movie build/res/f.png --quit-after 90 res://tools/showcase/resonator_showcase.tscn -- --view=play
## Views:
##   model (default)  the Resonator close up over a strip of floor, looping: at rest (its halos tumbling),
##                    the warning (the halos swing into line facing the camera, one at each of
##                    Resonator.LINE_UP_AT, the core and trims glowing red), the pulse, and a wave rolling
##                    toward the camera; --turn circles the camera around it, --side looks from the side
##   play             a real RunWorld through the run camera: a runner (god mode, so nothing ends the run)
##                    who jumps each wave as it comes; the Resonator hovers far ahead, warns and pulses
##   close            the same run with a camera beside the runner, looking ahead at the Resonator and
##                    its waves
## Options: --lanes=N (default 5), --skin=<name> (data/skins/<name>_skin.tres, default the grey box),
## --pulses=N, --double (every pulse after the first sends two waves), --wall (the runner rides a wall
## as each wave passes instead of jumping it), --stand (the runner doesn't dodge: the wave passes
## through the god-mode runner), --reduced (Reduced flashing on), --nolabel.

const AT: float = 60.0

var _world: RunWorld
var _camera: Camera3D
var _resonator: Resonator
var _view: String = "model"
var _lanes: int = 5
var _wall: bool = false
var _stand: bool = false
var _turn: bool = false
var _side: bool = false
# The model view's own loop.
var _model: ResonatorModel
var _wave: MeshInstance3D
var _wave_mat: ShaderMaterial
var _t: float = 0.0


func _ready() -> void:
	var skin_name: String = ""
	var pulses: int = 3
	var double: bool = false
	for arg: String in OS.get_cmdline_user_args():
		var v: String = arg.get_slice("=", 1)
		if arg.begins_with("--view="):
			_view = v
		elif arg.begins_with("--lanes="):
			_lanes = int(v)
		elif arg.begins_with("--skin="):
			skin_name = v
		elif arg.begins_with("--pulses="):
			pulses = int(v)
		elif arg == "--double":
			double = true
		elif arg == "--wall":
			_wall = true
		elif arg == "--stand":
			_stand = true
		elif arg == "--turn":
			_turn = true
		elif arg == "--side":
			_side = true
		elif arg == "--reduced":
			RenderingServer.global_shader_parameter_set(&"reduced_flashing", 1.0)
			Settings.flashing_reduced = true
	var tuning := load("res://data/tuning/movement.tres") as MovementTuning
	var config := LevelConfig.new()
	config.lane_count = _lanes
	config.enemy_scaling = 1.0 if double else 14.0 / 16.0  # the Golden Palace's, or Golden 1's
	var skin_path: String = "res://data/skins/%s_skin.tres" % skin_name
	config.skin = load(skin_path) as ZoneSkin if skin_name != "" and ResourceLoader.exists(skin_path) else null
	var layout := LevelLayout.new()
	layout.lane_count = _lanes
	layout.length = 1200.0
	_world = RunWorld.new()
	add_child(_world)
	_world.build(config, layout, tuning, load("res://data/tuning/game_rules.tres") as GameRules,
		load("res://data/tuning/powerups.tres") as PowerupTuning)
	_world.player.setup(tuning, _world.geo, _lanes - 1 if _wall else _lanes / 2)
	_world.player.god_mode = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sun.light_energy = 0.8
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = _world.skin.make_environment()
	add_child(env)
	if _view == "model":
		_build_model_view()
	else:
		var doubles: Array[bool] = []
		for i: int in pulses:
			doubles.append(double and i > 0)
		_resonator = _world.director.spawn({"type": "resonator", "at": AT, "lane": _lanes / 2, "side": 0, "seed": 3,
			"params": {"pulses": pulses, "double": doubles}}) as Resonator
		if _view == "close":
			_camera = Camera3D.new()
			_camera.fov = 55.0
			_camera.far = 600.0
			add_child(_camera)
		else:
			var cam := RunCamera.new()
			add_child(cam)
			cam.follow(_world)
			_camera = cam
		_camera.make_current()
		_world.start()
	if not OS.get_cmdline_user_args().has("--nolabel"):
		_caption("Resonator: %s, %d lanes%s%s" % [_view, _lanes, ", double waves" if double else "",
			", Reduced flashing" if Settings.flashing_reduced else ""])


## The model on its own over a strip of floor (the world's track, the runner hidden), looping its warning
## and pulse by the Resonator's own timings (LINE_UP_AT, warning_seconds).
func _build_model_view() -> void:
	_world.player.visible = false
	var t: ResonatorTuning = EnemyDirector.tuning_for("resonator") as ResonatorTuning
	_model = ResonatorModel.new()
	add_child(_model)
	_model.build(t.model_scale)
	_model.position = Vector3(0.0, t.hover_height, -12.0)
	var half: float = t.band_half_width(_lanes, _world.tuning)
	_wave = MeshInstance3D.new()
	_wave.mesh = ResonatorModel.wave_mesh(half, t.wave_height * Resonator.CREST_HEIGHT_SCALE,
		t.wave_depth * Resonator.CREST_DEPTH_SCALE, Resonator.CREST_END_TAPER, Resonator.WAKE_LENGTH)
	_wave_mat = ShaderMaterial.new()
	_wave_mat.shader = ResonatorModel.wave_shader()
	_wave.material_override = _wave_mat
	_wave.visible = false
	add_child(_wave)
	_camera = Camera3D.new()
	_camera.fov = 50.0
	add_child(_camera)
	_camera.make_current()
	_place_model_camera()


func _place_model_camera() -> void:
	var target := Vector3(0.0, 2.2, -12.0)
	if _turn:
		var a: float = _t * 0.35
		_camera.position = target + Vector3(sin(a) * 9.0, 0.8, cos(a) * 9.0)
	elif _side:
		_camera.position = target + Vector3(8.5, 0.6, 2.5)
	else:
		_camera.position = Vector3(0.0, 2.1, -3.0)
	_camera.look_at(target)


func _process(delta: float) -> void:
	if _view == "model":
		_model_loop(delta)
		return
	if _view == "close" and _world != null:
		var p: Vector3 = _world.player.position
		_camera.position = p + Vector3(2.6, 2.0, 3.2)
		var look: Vector3 = _resonator.global_position if is_instance_valid(_resonator) else p + Vector3(0.0, 2.0, -30.0)
		_camera.look_at(look.lerp(p + Vector3(0.0, 0.5, -6.0), 0.35))


## The runner: jumps each wave as it comes (or rides the wall as it passes, with --wall).
func _physics_process(_delta: float) -> void:
	if _view == "model" or _world == null or not is_instance_valid(_resonator) or _stand:
		return
	var p: Player = _world.player
	for w: Resonator.Wave in _resonator.wave_list():
		if not w.on_its_way():
			continue
		var gap: float = (w.d - _resonator.tune.wave_depth * 0.5) - (p.distance + _world.tuning.hurtbox_size.z * 0.5)
		var arrival: float = gap / maxf(w.speed + p.speed, 1.0)
		if _wall:
			if arrival < 1.2 and p.surface == Player.Surface.FLOOR and p.grounded:
				p.press(&"move_right")
		elif arrival < 0.32 and p.grounded and p.surface == Player.Surface.FLOOR:
			p.press(&"jump")


## The model view's loop, 4.5 s long: at rest, the warning (the Resonator's own LINE_UP_AT), the
## pulse, and a wave rolling toward the camera.
func _model_loop(delta: float) -> void:
	_t += delta
	var t: ResonatorTuning = EnemyDirector.tuning_for("resonator") as ResonatorTuning
	var cycle: float = fmod(_t, 4.5)
	var warn: float = cycle - 1.0
	var warning: bool = warn >= 0.0 and warn < t.warning_seconds
	# (Held in line a moment after the pulse here, so the flare reads in stills.)
	var held: bool = warn >= t.warning_seconds and warn < t.warning_seconds + 0.35
	for k: int in 3:
		var target: float = 1.0 if held else 0.0
		if warning:
			target = smoothstep(Resonator.LINE_UP_AT[k] - Resonator.LINE_UP_BEFORE,
				Resonator.LINE_UP_AT[k] + Resonator.LINE_UP_AFTER, warn)
		var now: float = _model.align[k]
		_model.align[k] = target if target >= now else move_toward(now, target, delta * 1.4)
		_model.halo_glow[k] = _model.align[k] * (1.0 if warning else 0.6)
	var charge: float = clampf(warn / t.warning_seconds, 0.0, 1.0) if warning else 0.0
	_model.spin = move_toward(_model.spin, 1.0 if warning else 0.0, delta * (2.0 if warning else 0.8))
	_model.core_glow = 1.0 + 1.6 * charge
	_model.emitter_glow = charge
	var since: float = warn - t.warning_seconds
	_model.flash = maxf(0.0, 1.0 - since * 3.5) if since >= 0.0 else 0.0
	_model.animate(delta)
	# The wave: leaves from the floor under it and rolls toward the camera (slowed down here, so it's seen
	# leaving; in play it closes at the wave's speed plus the runner's).
	_wave.visible = since >= 0.0 and since < 1.8
	if _wave.visible:
		var d: float = since * 6.0
		_wave.position = Vector3(0.0, 0.0, -12.0 + d)
		var spread: float = clampf(since / Resonator.WAVE_SPREAD, 0.0, 1.0)
		_wave.scale = Vector3(lerpf(0.12, 1.0, spread * (2.0 - spread)), 1.0, 1.0)
		_wave_mat.set_shader_parameter(&"strength", lerpf(0.5, 1.0, spread) * clampf((1.8 - since) / 0.3, 0.0, 1.0))
		if not Settings.flashing_reduced:
			_wave_mat.set_shader_parameter(&"roll", _t * 1.8)
	_place_model_camera()


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

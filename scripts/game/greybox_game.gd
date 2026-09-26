extends Node3D
## Grey-box game loop for risk test R1 (core movement). Generates a level, runs it,
## restarts on death with the same seed (campaign rule), and moves to the next seed on completion.

const TUNING_PATH: String = "res://data/tuning/movement.tres"
const LEVEL_PATH: String = "res://data/levels/prototype_level.tres"
const SFX_PATH: String = "res://data/audio/sfx_library.tres"
const LANE_OPTIONS: Array[int] = [3, 5, 6]
const DIFFICULTY_OPTIONS: Array[float] = [0.0, 0.3, 0.6, 0.9]
const DEATH_PAUSE: float = 1.2
const COMPLETE_PAUSE: float = 2.5

enum State { RUNNING, DEAD, COMPLETE }

var tuning: MovementTuning
var config: LevelConfig
var patterns: Array = []
var layout: LevelLayout
var track: TrackBuilder
var player: Player
var camera: Camera3D
var hud: DebugHud
var tuning_panel: TuningPanel
var sfx: PlayerSfx

var state: State = State.RUNNING
var attempts: int = 0
var deaths_by_cause: Dictionary = {}
var _restart_in: float = 0.0
var _show_hitboxes: bool = false
var _cam_focus: Vector3 = Vector3.ZERO
var _cam_look_y: float = 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	tuning = load(TUNING_PATH) as MovementTuning
	config = (load(LEVEL_PATH) as LevelConfig).duplicate() as LevelConfig
	if config.skin == null:
		config.skin = GreyboxSkin.new()
	config.lane_count = config.lanes_for_device(DeviceProfile.is_mobile())
	patterns = LevelGenerator.load_patterns(config.patterns_path)

	var world_env := WorldEnvironment.new()
	world_env.environment = config.skin.make_environment()
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
	sun.light_energy = 0.7
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)

	track = TrackBuilder.new()
	track.name = "Track"
	track.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(track)
	player = Player.new()
	player.name = "Player"
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	player.died.connect(_on_player_died)
	var library := load(SFX_PATH) as SfxLibrary
	track.sfx = library
	sfx = PlayerSfx.new()
	add_child(sfx)
	sfx.setup(library)
	sfx.bind(player)
	camera = Camera3D.new()
	camera.far = 400.0
	add_child(camera)
	camera.make_current()
	hud = DebugHud.new()
	add_child(hud)
	tuning_panel = TuningPanel.new()
	add_child(tuning_panel)
	var sections: Array[Dictionary] = [
		{"title": "Movement", "resource": tuning, "path": TUNING_PATH},
		{"title": "Level pacing", "resource": config, "path": LEVEL_PATH},
	]
	tuning_panel.setup(sections)
	tuning_panel.restart_requested.connect(_restart_same_seed)
	tuning_panel.close_requested.connect(_toggle_tuning_panel)
	_apply_command_line()
	start_level()


## Optional overrides after `--` on the command line: --lanes=6 --seed=4 --difficulty=0.6 --god
func _apply_command_line() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var value: String = arg.get_slice("=", 1)
		if arg.begins_with("--lanes="):
			config.lane_count = int(value)
		elif arg.begins_with("--seed="):
			config.level_seed = int(value)
		elif arg.begins_with("--difficulty="):
			config.difficulty = float(value)
		elif arg == "--god":
			player.god_mode = true


func start_level() -> void:
	_set_paused(false, "")
	tuning_panel.close()
	var generator := LevelGenerator.new()
	layout = generator.generate(config, tuning, patterns)
	for line: String in generator.warnings:
		push_warning("LevelGenerator: " + line)
	track.set_layout(layout, tuning, config.skin)
	player.setup(tuning, TrackGeometry.new(config.lane_count, tuning), config.lane_count / 2)
	player.running = true
	player.set_hitbox_visible(_show_hitboxes)
	track.update(0.0, 0.0)
	attempts += 1
	state = State.RUNNING
	hud.set_message("")
	_cam_focus = Vector3(player.position.x, tuning.camera_height, 0.0)
	_cam_look_y = 1.0
	_update_camera(1.0)


func _physics_process(_delta: float) -> void:
	if get_tree().paused or state != State.RUNNING:
		return
	track.update(player.distance, player.elapsed)
	if player.distance >= layout.length:
		state = State.COMPLETE
		player.running = false
		_restart_in = COMPLETE_PAUSE
		hud.set_message("LEVEL COMPLETE\n%d attempt(s)" % attempts)
		sfx.play(&"level_complete")


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_update_camera(delta)
	if state != State.RUNNING:
		_restart_in -= delta
		if _restart_in <= 0.0:
			if state == State.COMPLETE:
				config.level_seed += 1
				attempts = 0
			start_level()
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_tuning_panel"):
		_toggle_tuning_panel()
	elif event.is_action_pressed(&"pause"):
		if tuning_panel.visible:
			_toggle_tuning_panel()
		else:
			_set_paused(not get_tree().paused, "PAUSED")
	elif event.is_action_pressed(&"debug_restart"):
		_restart_same_seed()
	elif event.is_action_pressed(&"debug_cycle_lanes"):
		config.lane_count = LANE_OPTIONS[(LANE_OPTIONS.find(config.lane_count) + 1) % LANE_OPTIONS.size()]
		_restart_fresh()
	elif event.is_action_pressed(&"debug_new_seed"):
		config.level_seed += 1
		_restart_fresh()
	elif event.is_action_pressed(&"debug_cycle_difficulty"):
		var i: int = DIFFICULTY_OPTIONS.find(config.difficulty)
		config.difficulty = DIFFICULTY_OPTIONS[(i + 1) % DIFFICULTY_OPTIONS.size()]
		_restart_fresh()
	elif event.is_action_pressed(&"debug_god_mode"):
		player.god_mode = not player.god_mode
	elif event.is_action_pressed(&"debug_toggle_hitboxes"):
		_show_hitboxes = not _show_hitboxes
		track.set_hitboxes_visible(_show_hitboxes)
		player.set_hitbox_visible(_show_hitboxes)
	elif event.is_action_pressed(&"debug_mute"):
		AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))


func _restart_same_seed() -> void:
	start_level()


## A different level (seed, lanes or difficulty): attempt and death counts start over.
func _restart_fresh() -> void:
	attempts = 0
	deaths_by_cause.clear()
	start_level()


func _toggle_tuning_panel() -> void:
	if tuning_panel.visible:
		tuning_panel.close()
		_set_paused(false, "")
	else:
		tuning_panel.open()
		_set_paused(true, "TUNING (game paused)")


func _set_paused(on: bool, text: String) -> void:
	get_tree().paused = on
	hud.set_pause_text(text if on else "")


func _on_player_died(cause: String) -> void:
	state = State.DEAD
	_restart_in = DEATH_PAUSE
	deaths_by_cause[cause] = int(deaths_by_cause.get(cause, 0)) + 1
	hud.set_message("DIED: %s" % cause)


func _update_camera(delta: float) -> void:
	var p: Vector3 = player.position
	var cam_y: float = tuning.camera_height + p.y * tuning.camera_follow_y
	var look_y: float = p.y * tuning.camera_follow_y + 1.0
	if player.surface == Player.Surface.CEILING:
		# Drop below the ceiling and look up at the player hanging from it.
		cam_y = tuning.camera_ceiling_height
		look_y = tuning.ceiling_height - 1.2
	var k: float = 1.0 - exp(-tuning.camera_smoothing * delta)
	_cam_focus.x = lerpf(_cam_focus.x, p.x * tuning.camera_follow_x, k)
	_cam_focus.y = lerpf(_cam_focus.y, cam_y, k)
	_cam_look_y = lerpf(_cam_look_y, look_y, k)
	camera.fov = tuning.camera_fov
	camera.position = Vector3(_cam_focus.x, _cam_focus.y, p.z + tuning.camera_distance)
	camera.look_at(Vector3(_cam_focus.x, _cam_look_y, p.z - tuning.camera_look_ahead))


func _update_hud() -> void:
	var deaths: PackedStringArray = []
	for cause: String in deaths_by_cause:
		deaths.append("%s ×%d" % [cause, deaths_by_cause[cause]])
	var text: String = "Seed %d   Lanes %d   Difficulty %.1f   Attempt %d%s%s\n" % [
		config.level_seed, config.lane_count, config.difficulty, attempts,
		"   [GOD MODE]" if player.god_mode else "", "   [MUTED]" if AudioServer.is_bus_mute(0) else ""]
	text += "Time %.1fs   Distance %d / %d m   Speed %.1f m/s\n" % [
		player.elapsed, player.distance, layout.length, player.speed]
	text += "Surface: %s   Lane %d   %s%s\n" % [
		player.surface_name(), player.lane, "sliding  " if player.is_sliding() else "",
		"airborne" if not player.grounded and player.surface != Player.Surface.WALL else ""]
	text += "Last: %s\n" % player.last_event
	if not deaths.is_empty():
		text += "Deaths: %s" % ", ".join(deaths)
	hud.set_info(text, clampf(player.distance / layout.length, 0.0, 1.0))

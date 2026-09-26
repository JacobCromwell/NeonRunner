class_name LevelRun
extends Node3D
## One level being played. Generates the layout for a RunContext, builds the RunWorld, and runs the
## camera, HUD, music and debug tools. The App owns the flow around a run (death screen, revive,
## results, shop, retry); LevelRun only plays and reports:
## - `died` when the player dies (after a short pause so the death reads). The App answers with
##   revive() or give_up().
## - `finished` with the RunResult when the level is completed or the player gives up.
## - `pause_requested` when the pause action is pressed.
##
## Quick play (RunContext.Mode.QUICK, the grey-box workflow) restarts by itself after a death and
## moves to the next seed after a finish, and keeps the debug keys (F1–F6, R, M).

signal died(run: LevelRun)
signal finished(result: RunResult)
signal pause_requested
## A breakable item broke (armor, shield, grapple): passed on from the current world's player.
signal item_used(item: StringName)

enum State { RUNNING, DEAD, COMPLETE }

const LANE_OPTIONS: Array[int] = [3, 5, 6]
const DIFFICULTY_OPTIONS: Array[float] = [0.0, 0.3, 0.6, 0.9]
const COMPLETE_PAUSE: float = 2.0
const QUICK_DEATH_PAUSE: float = 1.2

var context: RunContext
var rules: GameRules
var world: RunWorld
var camera: RunCamera
var hud: RunHud
var state: State = State.RUNNING
var death_cause: String = ""
## Debug readout and live tuning, only in debug builds.
var debug_hud: DebugHud
var tuning_panel: TuningPanel

var _timer: float = 0.0
var _show_hitboxes: bool = false
var _env: WorldEnvironment
var _deaths_by_cause: Dictionary = {}
var _hints: HintDirector


func start(p_context: RunContext) -> void:
	context = p_context
	rules = App.rules
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build()


## Builds (or rebuilds) the world for the current context.
func _build() -> void:
	if world != null:
		world.queue_free()
		remove_child(world)
	var gen := LevelGenerator.new()
	var layout: LevelLayout = gen.generate(context.config, context.tuning, LevelGenerator.load_for(context.config))
	for line: String in gen.warnings:
		push_warning("LevelGenerator: " + line)
	world = RunWorld.new()
	world.name = "World"
	add_child(world)
	world.build(context.config, layout, context.tuning, rules, App.powerup_tuning, context.loadout, App.sfx_library)
	world.player.god_mode = context.god_mode
	if context.no_fall:
		world.player.grapples = 1_000_000
	world.player.died.connect(_on_player_died)
	world.player.item_used.connect(func(item: StringName) -> void: item_used.emit(item))
	world.player.set_hitbox_visible(_show_hitboxes)
	world.effects.shake_scale = Settings.shake_scale(App.profile)
	world.player.steady_flash = Settings.reduced_flashing(App.profile)

	if _env == null:
		_env = WorldEnvironment.new()
		add_child(_env)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
		sun.light_energy = 0.7
		sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
		add_child(sun)
	_env.environment = world.skin.make_environment()
	if camera == null:
		camera = RunCamera.new()
		add_child(camera)
	camera.make_current()
	camera.follow(world)
	if hud == null:
		hud = RunHud.new()
		add_child(hud)
		hud.pause_pressed.connect(func() -> void: pause_requested.emit())
	hud.bind(world, context)
	if _hints != null:
		_hints.queue_free()
		_hints = null
	if context.mode != RunContext.Mode.QUICK and bool(Settings.value(App.profile, "hints")):
		_hints = HintDirector.new()
		add_child(_hints)
		_hints.setup(world, App.profile, App.mobile or DisplayServer.is_touchscreen_available())
		_hints.hint_shown.connect(func(_id: String, text: String) -> void: hud.show_hint(text))
	if OS.is_debug_build() and debug_hud == null:
		_build_debug_tools()
	state = State.RUNNING
	death_cause = ""
	world.start()


## Continues after a death (revive item or rewarded ad). The App calls this.
func revive() -> void:
	if state != State.DEAD:
		return
	context.revives_used += 1
	world.player.revive()
	state = State.RUNNING
	hud.set_message("")


## Ends the run after a death without reviving. Emits `finished` with a failed result.
func give_up() -> void:
	if state != State.DEAD:
		return
	state = State.COMPLETE
	finished.emit(RunResult.from_world(world, context, false, death_cause, rules))


## Starts the same level again in place (debug restart and quick play).
func restart(next_context: RunContext = null) -> void:
	context = next_context if next_context != null else context.retry()
	_build()


func _physics_process(_delta: float) -> void:
	if state != State.RUNNING or world == null:
		return
	if world.player.distance >= world.layout.length:
		state = State.COMPLETE
		world.player.running = false
		_timer = COMPLETE_PAUSE
		hud.set_message("LEVEL COMPLETE")
		world.play_sfx(&"level_complete")


func _process(delta: float) -> void:
	if world == null:
		return
	if debug_hud != null:
		_update_debug_hud()
	if _timer <= 0.0:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	if state == State.COMPLETE:
		if context.mode == RunContext.Mode.QUICK:
			context.config.level_seed += 1
			_restart_fresh()
		else:
			finished.emit(RunResult.from_world(world, context, true, "", rules))
	elif state == State.DEAD:
		if context.mode == RunContext.Mode.QUICK:
			restart()
		else:
			died.emit(self)


func _on_player_died(cause: String) -> void:
	state = State.DEAD
	death_cause = cause
	_deaths_by_cause[cause] = int(_deaths_by_cause.get(cause, 0)) + 1
	_timer = QUICK_DEATH_PAUSE if context.mode == RunContext.Mode.QUICK else rules.death_screen_delay
	hud.set_message("DIED: %s" % cause)
	world.effects.shake(0.35, 0.35)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		if tuning_panel != null and tuning_panel.visible:
			_toggle_tuning_panel()
		elif state == State.RUNNING:
			pause_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if not OS.is_debug_build():
		return
	if event.is_action_pressed(&"debug_tuning_panel"):
		_toggle_tuning_panel()
	elif event.is_action_pressed(&"debug_restart"):
		restart()
	elif event.is_action_pressed(&"debug_cycle_lanes"):
		var c: LevelConfig = context.config
		c.lane_count = LANE_OPTIONS[(LANE_OPTIONS.find(c.lane_count) + 1) % LANE_OPTIONS.size()]
		_restart_fresh()
	elif event.is_action_pressed(&"debug_new_seed"):
		context.config.level_seed += 1
		_restart_fresh()
	elif event.is_action_pressed(&"debug_cycle_difficulty"):
		var i: int = DIFFICULTY_OPTIONS.find(snappedf(context.config.difficulty, 0.1))
		context.config.difficulty = DIFFICULTY_OPTIONS[(i + 1) % DIFFICULTY_OPTIONS.size()]
		_restart_fresh()
	elif event.is_action_pressed(&"debug_god_mode"):
		context.god_mode = not context.god_mode
		world.player.god_mode = context.god_mode
	elif event.is_action_pressed(&"debug_toggle_hitboxes"):
		_show_hitboxes = not _show_hitboxes
		world.track.set_hitboxes_visible(_show_hitboxes)
		world.player.set_hitbox_visible(_show_hitboxes)
	elif event.is_action_pressed(&"debug_mute"):
		AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))


## A different level (seed, lanes or difficulty; debug keys and quick play): counts start over.
func _restart_fresh() -> void:
	var next: RunContext = context.retry()
	next.attempt = 1
	_deaths_by_cause.clear()
	restart(next)


# --- Debug tools (debug builds only) ----------------------------------------------------

func _build_debug_tools() -> void:
	debug_hud = DebugHud.new()
	add_child(debug_hud)
	debug_hud.visible = context.mode == RunContext.Mode.QUICK
	tuning_panel = TuningPanel.new()
	add_child(tuning_panel)
	var sections: Array[Dictionary] = [
		{"title": "Movement", "resource": context.tuning, "path": App.TUNING_PATH},
		{"title": "Game rules", "resource": rules, "path": App.RULES_PATH},
		{"title": "Power-ups", "resource": App.powerup_tuning, "path": App.POWERUPS_PATH},
		{"title": "Runner animation", "resource": load(PlayerAvatar.ANIM_TUNING_PATH), "path": PlayerAvatar.ANIM_TUNING_PATH},
		{"title": "Level pacing", "resource": context.config, "path": context.config.resource_path},
	]
	if context.config.resource_path == "":
		sections.pop_back()
	# The level's enemy types. Every enemy of a type shares its tuning resource, so changes reach the
	# ones in play (numbers an enemy reads once, such as health, apply to the next ones spawned).
	for feature: String in context.config.features:
		var enemy_tuning: Resource = EnemyDirector.tuning_for(feature)
		if enemy_tuning != null and enemy_tuning.resource_path != "":
			sections.append({"title": "Enemy: " + feature.capitalize(), "resource": enemy_tuning,
				"path": enemy_tuning.resource_path})
	tuning_panel.setup(sections)
	tuning_panel.restart_requested.connect(func() -> void: restart())
	tuning_panel.close_requested.connect(_toggle_tuning_panel)


func _toggle_tuning_panel() -> void:
	if tuning_panel == null:
		return
	if tuning_panel.visible:
		tuning_panel.close()
		get_tree().paused = false
		debug_hud.set_pause_text("")
	else:
		tuning_panel.open()
		get_tree().paused = true
		debug_hud.set_pause_text("TUNING (game paused)")


func _update_debug_hud() -> void:
	var p: Player = world.player
	var deaths: PackedStringArray = []
	for cause: String in _deaths_by_cause:
		deaths.append("%s ×%d" % [cause, _deaths_by_cause[cause]])
	var text: String = "Seed %d   Lanes %d   Difficulty %.2f   Attempt %d%s%s\n" % [
		context.config.level_seed, context.config.lane_count, context.config.difficulty, context.attempt,
		"   [GOD MODE]" if p.god_mode else "", "   [MUTED]" if AudioServer.is_bus_mute(0) else ""]
	text += "Time %.1fs   Distance %d / %d m   Speed %.1f m/s   Enemies %d\n" % [
		p.elapsed, p.distance, world.layout.length, p.speed, world.director.active.size()]
	text += "Surface: %s   Lane %d   %s%s\n" % [p.surface_name(), p.lane, "sliding  " if p.is_sliding() else "",
		"airborne" if not p.grounded and p.surface != Player.Surface.WALL else ""]
	text += "Loadout: %s\nLast: %s\n" % [context.loadout.describe() if context.loadout != null else "-", p.last_event]
	if not deaths.is_empty():
		text += "Deaths: %s" % ", ".join(deaths)
	debug_hud.set_info(text, clampf(p.distance / world.layout.length, 0.0, 1.0))

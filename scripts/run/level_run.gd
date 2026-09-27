class_name LevelRun
extends Node3D
## One level or boss fight being played. Generates the layout for a RunContext (a boss fight's arena
## comes from its BossEncounter, GDD §10), builds the RunWorld, and runs the camera, HUD, music and
## debug tools. The App owns the flow around a run (death screen, revive, results, shop, retry);
## LevelRun only plays and reports:
## - `died` when the player dies (after a short pause so the death reads). The App answers with
##   revive() or give_up().
## - `finished` with the RunResult when the level is completed (a boss fight: the boss is beaten) or
##   the player gives up.
## - `pause_requested` when the pause action is pressed.
##
## Quick play (RunContext.Mode.QUICK, the grey-box workflow) restarts by itself after a death and
## moves to the next seed after a finish (a boss fight starts over), and keeps the debug keys
## (F1–F6, R, M).

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
## The boss fight in this run, or null for a level.
var encounter: BossEncounter
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
	encounter = null
	var layout: LevelLayout
	var arena: BossArena = null
	if context.is_boss():
		encounter = BossEncounter.create(context.boss)
		if encounter == null:
			push_error("LevelRun: boss %s has no fight to play (BossDef.scene)" % context.boss.id)
		arena = encounter.plan_arena(context) if encounter != null else null
	if arena != null:
		layout = arena.layout
	else:
		var gen := LevelGenerator.new()
		layout = gen.generate(context.config, context.tuning, LevelGenerator.load_for(context.config))
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
	if encounter != null:
		encounter.setup(world, context, arena)
		encounter.defeated.connect(_on_boss_defeated)
	if not context.review_pickups.is_empty():
		world.pickups.start_review(context.review_pickups)

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
	finished.emit(_result(false))


## The run's result: a level's, or a boss fight's (GDD §10).
func _result(completed: bool) -> RunResult:
	if context.is_boss():
		return RunResult.from_boss(world, encounter, context, completed, "" if completed else death_cause, rules)
	return RunResult.from_world(world, context, completed, "" if completed else death_cause, rules)


## The result for leaving from the pause menu (GDD §4, decided September 26, 2026): never a
## completion, so it keeps the same share of this attempt's credits as a death
## (`death_cause` is still "" here since the player hasn't died) but never a "died" cause. The App
## uses this instead of `finished`, since quitting doesn't go through the death/revive flow.
func quit_result() -> RunResult:
	return _result(false)


## Starts the same level again in place (debug restart and quick play).
func restart(next_context: RunContext = null) -> void:
	context = next_context if next_context != null else context.retry()
	_build()


func _physics_process(_delta: float) -> void:
	if state != State.RUNNING or world == null:
		return
	# A boss fight ends with the boss (_on_boss_defeated); its arena never runs out.
	if encounter == null and world.player.distance >= world.layout.length:
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
			if not context.is_boss():
				context.config.level_seed += 1
			_restart_fresh()
		else:
			finished.emit(_result(true))
	elif state == State.DEAD:
		if context.mode == RunContext.Mode.QUICK:
			restart()
		else:
			died.emit(self)


## The boss is beaten (GDD §10): the run is won. The runner keeps running while the defeat plays out
## (the Floating Head crashes into the street ahead and the runner runs through the wreck), safe from
## anything still in the air, then the results follow (DESIGN-TBD: then the shop, as after a level).
func _on_boss_defeated() -> void:
	if state != State.RUNNING:
		return
	state = State.COMPLETE
	_timer = COMPLETE_PAUSE
	world.player.god_mode = true
	hud.set_message("BOSS DEFEATED")
	world.play_sfx(&"level_complete")


func _on_player_died(cause: String) -> void:
	if state == State.COMPLETE:
		return  # Nothing after the finish counts (a shot still in the air, a fall past a boss's wreck).
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


## A different level (seed, lanes or difficulty; debug keys and quick play): counts start over, and a
## boss fight starts from its beginning.
func _restart_fresh() -> void:
	var next: RunContext = context.retry()
	next.attempt = 1
	next.boss_resume = {}
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
		{"title": "Pickups", "resource": world.pickups.tuning, "path": PickupField.TUNING_PATH},
		{"title": "Level pacing", "resource": context.config, "path": context.config.resource_path},
	]
	if context.config.resource_path == "":
		sections.pop_back()
	if context.is_boss():
		# The boss's numbers (health, rewards, par times) and its script's own tuning.
		var def: BossDef = context.boss
		if def.resource_path != "":
			sections.append({"title": "Boss: " + def.display_name, "resource": def, "path": def.resource_path})
		if def.tuning != null and def.tuning.resource_path != "":
			sections.append({"title": "Boss tuning", "resource": def.tuning, "path": def.tuning.resource_path})
	# The level's enemy types. Every enemy of a type shares its tuning resource, so changes reach the
	# ones in play (numbers an enemy reads once, such as health, apply to the next ones spawned).
	var types: PackedStringArray = []
	for feature: String in context.config.features:
		# Hosts are cyborgs that release a Bad Dream.
		for type: String in (["cyborg", "bad_dream"] if feature == "host" else [feature]):
			if not types.has(type):
				types.append(type)
	for type: String in types:
		var enemy_tuning: Resource = EnemyDirector.tuning_for(type)
		if enemy_tuning != null and enemy_tuning.resource_path != "":
			sections.append({"title": "Enemy: " + type.capitalize(), "resource": enemy_tuning,
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
	if encounter != null and is_instance_valid(encounter):
		text += "Boss: phase %d/%d %s   health %.0f / %.0f   weapons %.0f / %.0f   fight %.1fs   lap %d%s\n" % [
			encounter.phase_index + 1, encounter.phase_count(), BossEncounter.State.keys()[encounter.state],
			encounter.health, encounter.max_health, encounter.weapon_damage,
			encounter.max_health * encounter.def.weapon_share_cap, encounter.fight_time(),
			encounter.arena.lap_at(p.distance) if encounter.arena != null else 0,
			"   [checkpoint: phase %d]" % (int(context.boss_resume["phase"]) + 1) if context.boss_resume.has("phase") else ""]
	text += "Loadout: %s\nLast: %s\n" % [context.loadout.describe() if context.loadout != null else "-", p.last_event]
	if not deaths.is_empty():
		text += "Deaths: %s" % ", ".join(deaths)
	# A boss fight's progress is the boss's health taken.
	var progress: float = 1.0 - encounter.health_ratio() if encounter != null and is_instance_valid(encounter) \
		else p.distance / world.layout.length
	debug_hud.set_info(text, clampf(progress, 0.0, 1.0))

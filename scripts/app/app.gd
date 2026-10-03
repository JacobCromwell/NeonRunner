extends Node
## Autoload "App": the game's state and flow. Holds the data (tuning, rules, campaign, shop
## catalog, profile) and moves the player between screens and runs:
##
##   title → level select → [cinematic] → level → results → shop → next level … → boss → …
##   death → revive offer (item, or rewarded ad on mobile) → run summary → shop → retry  (GDD §4)
##
## Screens are Controls under Main's UI layer; they call this API and never change state
## themselves. Runs, bosses and cinematics live under Main's world root. Command-line options
## after `--` start straight into play (the grey-box workflow):
##   --quick                 quick play: the prototype level, restarts on death, F1–F6 debug keys
##   --seed=N --lanes=N --difficulty=X --god   quick play with overrides (any of these implies --quick)
##   --features=cyborg,drone  quick play with extra level features (enemy types, ramps, ...)
##   --full-loadout          quick play with every power-up
##   --nofall                quick play where falls never end the run (for reviewing levels and art)
##   --skin=gangland         quick play in another zone's look (data/skins/<name>_skin.tres)
##   --speed=25              quick play at another run speed (a zone's: 21 in the City to 25 in the
##                           Golden Zone, GDD §3); the level keeps its timing in seconds
##   --doodads=0.6           quick play with zone doodads (GDD §3; LevelConfig.doodad_share: the chance
##                           each stretch with room for one gets one)
##   --thief                 quick play with stand-in thieves, one after another: a gold block that
##                           crosses the lanes and robs a runner who touches it (GDD §9.12; StandInThief)
##   --level=city/2          a campaign level, with the full flow (also takes --lanes=N, --god,
##                           --nofall and --full-loadout, for reviews)
##   --boss=city_boss        a boss fight by its BossDef id: a zone's boss with the full flow (like
##                           --level=city/boss; a fight still being built, its preview_scene, as quick
##                           play), any other (data/bosses/<id>.tres, e.g. the test boss) as quick
##                           play, starting over after a death or a win. Both take --lanes=N,
##                           --god, --nofall, --full-loadout, --skin=<zone> (quick play only) and
##                           --phase=N (start at phase N, as a checkpoint would)
##   --flavor=web_demo       pretend to be another build flavor (full_pc, full_mobile, web_demo)

signal profile_changed

const TUNING_PATH: String = "res://data/tuning/movement.tres"
const RULES_PATH: String = "res://data/tuning/game_rules.tres"
const POWERUPS_PATH: String = "res://data/tuning/powerups.tres"
const CAMPAIGN_PATH: String = "res://data/campaign/campaign.tres"
const SFX_PATH: String = "res://data/audio/sfx_library.tres"
const QUICK_LEVEL_PATH: String = "res://data/levels/prototype_level.tres"
## Where --boss=<id> finds a boss that isn't in the campaign (the test boss).
const BOSSES_DIR: String = "res://data/bosses"
## The look of a quick-play boss fight whose arena has none (--skin= picks another).
const QUICK_BOSS_SKIN: String = "res://data/skins/city_skin.tres"
## DESIGN-TBD: endless mode (OPEN_QUESTIONS §8): one long level whose difficulty keeps rising.
const ENDLESS_SECONDS: float = 1200.0

var tuning: MovementTuning
var rules: GameRules
var powerup_tuning: PowerupTuning
var campaign: Campaign
var catalog: ShopCatalog
var sfx_library: SfxLibrary
var profile: Profile
## Mobile device (3 lanes, touch, no slow time).
var mobile: bool = false
var save_path: String = SaveService.PATH
## Tests turn this off so they never touch the player's save.
var autosave: bool = true

## The Main scene (world_root, ui_root, overlay_root); null until it boots.
var main: Node
var run: LevelRun
var screen: Control
var overlay: Control
var _boss_node: Node
## Command-line review aids for --level= runs (see _apply_review_args).
var _review_args: PackedStringArray = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	tuning = load(TUNING_PATH) as MovementTuning
	rules = load(RULES_PATH) as GameRules
	powerup_tuning = load(POWERUPS_PATH) as PowerupTuning
	campaign = load(CAMPAIGN_PATH) as Campaign
	catalog = ShopCatalog.load_from()
	sfx_library = load(SFX_PATH) as SfxLibrary
	mobile = DeviceProfile.is_mobile()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--flavor="):
			BuildFlavor.set_override(BuildFlavor.from_name(arg.get_slice("=", 1)))
			if has_node(^"/root/Platform"):
				Platform.configure_for(BuildFlavor.current())
	profile = SaveService.load_profile(save_path)
	Settings.apply(profile)
	get_tree().root.size_changed.connect(_on_window_resized)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			# A phone call, the home button or another window: never keep running unattended.
			if run != null and run.state == LevelRun.State.RUNNING and run.context.mode != RunContext.Mode.QUICK:
				pause_game()
			save()
		NOTIFICATION_WM_CLOSE_REQUEST:
			save()


## True when the web demo runs on a touch screen held upright. The game is laid out for landscape
## everywhere (GDD §2), so the page then covers it with "turn your phone sideways" (the web preset's
## head include). DESIGN-TBD (docs/questions/e2.md): what the web demo does on a phone held upright.
func web_upright() -> bool:
	var window: Vector2i = get_tree().root.size
	return OS.has_feature("web") and DeviceProfile.has_touch() and window.y > window.x


## A running level pauses while the web demo's phone is held upright, so nothing happens unseen; the
## pause menu waits when it's turned back.
func _on_window_resized() -> void:
	if web_upright() and run != null and run.state == LevelRun.State.RUNNING and run.context.mode != RunContext.Mode.QUICK:
		pause_game()


## Main calls this once its layers exist. Starts wherever the command line says.
func boot(p_main: Node) -> void:
	main = p_main
	# The command-line starts are development aids: release builds always open on the title screen,
	# so they can't skip progression or farm credits and leaderboard scores with --god.
	var args: PackedStringArray = OS.get_cmdline_user_args() if OS.is_debug_build() else PackedStringArray()
	for arg: String in args:
		if arg.begins_with("--level="):
			var s: CampaignStep = campaign.step(arg.get_slice("=", 1))
			if s != null:
				_review_args = args
				play_step(s)
				return
	for arg: String in args:
		if arg.begins_with("--boss="):
			if _start_boss_arg(arg.get_slice("=", 1), args):
				return
	for arg: String in args:
		if arg == "--quick" or arg == "--god" or arg.begins_with("--seed=") or arg.begins_with("--lanes=") \
				or arg.begins_with("--difficulty=") or arg.begins_with("--features=") or arg == "--full-loadout" \
				or arg == "--nofall" or arg.begins_with("--skin=") or arg.begins_with("--pickups") \
				or arg.begins_with("--speed=") or arg.begins_with("--doodads=") or arg == "--thief":
			start_quick(args)
			return
	show_title()


# --- Screens ----------------------------------------------------------------------

func show_title() -> void:
	_end_run()
	_play_music(&"menu")
	show_screen(TitleScreen.new())


func show_level_select() -> void:
	_end_run()
	_play_music(&"menu")
	show_screen(LevelSelectScreen.new())


## The shop. `on_close` runs when the player leaves it (defaults to the title screen); `play_label`
## names the primary way out (e.g. "Retry" or "Next level").
func show_shop(on_close: Callable = Callable(), play_label: String = "") -> void:
	_end_run()
	_play_music(&"menu")
	var s := ShopScreen.new()
	s.on_close = on_close if on_close.is_valid() else show_title
	s.play_label = play_label
	show_screen(s)


func show_settings(on_close: Callable = Callable()) -> void:
	var s := SettingsScreen.new()
	s.on_close = on_close if on_close.is_valid() else show_title
	show_screen(s)


## After a settings change: volumes and keys are live already (Settings.set_value applies them);
## a run paused under the settings overlay picks up the comfort options too.
func apply_settings() -> void:
	Settings.apply_visuals(profile)
	if run != null and run.world != null:
		run.world.effects.shake_scale = Settings.shake_scale(profile)
		run.world.player.steady_flash = Settings.reduced_flashing(profile)


func show_demo_end() -> void:
	_end_run()
	_play_music(&"menu")
	show_screen(DemoEndScreen.new())


## Replaces the current full screen (and closes any overlay).
func show_screen(s: Control) -> void:
	close_overlay()
	if screen != null and is_instance_valid(screen):
		screen.queue_free()
	screen = s
	if main != null:
		main.ui_root.add_child(s)


## Shows a screen above the current one (pause, revive offer).
func show_overlay(o: Control) -> void:
	close_overlay()
	overlay = o
	if main != null:
		main.overlay_root.add_child(o)


func close_overlay() -> void:
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null


## UI sounds (ui_buy, ui_error, star, ...) share one path with the widgets' ui_move/ui_select:
## UiSounds, on the SFX bus when it exists; a sound the library doesn't have yet stays silent.
func play_ui_sound(sound: StringName) -> void:
	UiSounds.play(sound)


func quit() -> void:
	save()
	get_tree().quit()


# --- Campaign ------------------------------------------------------------------------

## True if the player may start this step: the first step, or the one before it is done.
## The web demo stops after its zone (GDD §2).
func step_unlocked(s: CampaignStep, difficulty_tier: int = 0) -> bool:
	if s.index == 0:
		return true
	var previous: CampaignStep = campaign.steps()[s.index - 1]
	return profile.is_completed(previous.id, difficulty_tier)


func in_demo_scope(s: CampaignStep) -> bool:
	return not BuildFlavor.is_demo() or s.zone.in_demo


## The first step not completed yet (the "Continue" button), or null when everything is done.
func next_unfinished_step(difficulty_tier: int = 0) -> CampaignStep:
	for s: CampaignStep in campaign.steps():
		if not profile.is_completed(s.id, difficulty_tier):
			return s
	return null


func continue_campaign() -> void:
	var s: CampaignStep = next_unfinished_step()
	if s == null:
		show_level_select()
	else:
		play_step(s)


## Plays a campaign step: a level, a boss (placeholder until built) or a cinematic.
func play_step(s: CampaignStep, difficulty_tier: int = 0) -> void:
	if not in_demo_scope(s):
		show_demo_end()
		return
	match s.kind:
		CampaignStep.Kind.LEVEL:
			start_level(s, difficulty_tier)
		CampaignStep.Kind.BOSS:
			_play_boss(s, difficulty_tier)
		CampaignStep.Kind.CINEMATIC:
			_play_cinematic(s)


## Goes on from a finished step: the next step, the demo's end screen, or the level select.
func advance_from(s: CampaignStep) -> void:
	var next: CampaignStep = campaign.next_step(s)
	if next == null:
		show_level_select()
	elif not in_demo_scope(next):
		show_demo_end()
	else:
		play_step(next)


## Marks a boss or cinematic slot as done (placeholders complete when the player continues; a built
## boss records its fight through the results instead, so a boss slot passed as a placeholder earns
## no stars that would show once the fight is built). The campaign's last step is a cinematic.
func complete_step(s: CampaignStep, score: int = 0) -> void:
	profile.record_run(s.id, 0, true, score, 0 if s.kind == CampaignStep.Kind.BOSS else 3, 0.0)
	_check_game_finished()
	save()


func lane_count() -> int:
	return rules.lanes_for_device(mobile)


## What the player takes into the next run, from what they own and have switched on, plus what a
## boss fight grants (GDD §8).
func make_loadout(boss: BossDef = null) -> Loadout:
	var out: Loadout = Loadout.from_profile(profile, catalog, mobile)
	if boss != null:
		out.grant(boss.granted_items, catalog, mobile)
	return out


# --- Runs --------------------------------------------------------------------------

func start_level(s: CampaignStep, difficulty_tier: int = 0) -> void:
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.CAMPAIGN
	ctx.step = s
	ctx.difficulty_tier = difficulty_tier
	ctx.config = campaign.configure(s, lane_count(), difficulty_tier)
	# The level's run speed (its zone's, times the tier's multiplier) wins over the base one.
	ctx.tuning = ctx.config.movement_for(_tuning_for_tier(difficulty_tier))
	ctx.loadout = make_loadout()
	ctx.level_index = s.level_index
	_apply_review_args(ctx)
	_start_run(ctx, s.zone.music)


## A campaign boss fight (GDD §10): it plays in the run world like a level, on the boss's own arena at
## its zone's speed (GDD §3), with its granted items, and goes through the same flow (death screen,
## results, shop, retry).
func start_boss(s: CampaignStep, difficulty_tier: int = 0) -> void:
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.CAMPAIGN
	ctx.step = s
	ctx.boss = s.boss
	ctx.difficulty_tier = difficulty_tier
	ctx.config = campaign.configure_boss(s, lane_count(), difficulty_tier)
	# Its zone's speed, like the zone's levels (GDD §3), and it never rises during the fight.
	ctx.tuning = _boss_tuning(ctx.config.movement_for(_tuning_for_tier(difficulty_tier)))
	ctx.loadout = make_loadout(s.boss)
	_apply_review_args(ctx)
	_start_run(ctx, _music_for(ctx))


## A boss fight as quick play (--boss= for a boss outside the campaign, such as the test boss; debug
## builds): no records or wallet, starting over after a death or a win, with the quick-play overrides.
func start_boss_quick(def: BossDef, args: PackedStringArray = PackedStringArray()) -> void:
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = def
	ctx.config = BossArena.base_config(def)
	ctx.config.lane_count = lane_count()
	if ctx.config.skin == null and ResourceLoader.exists(QUICK_BOSS_SKIN):
		ctx.config.skin = load(QUICK_BOSS_SKIN) as ZoneSkin
	ctx.tuning = _boss_tuning(tuning)
	ctx.loadout = make_loadout(def)
	_review_args = args
	_apply_review_args(ctx)
	_start_run(ctx, def.music if def.music != &"" else &"city")


## Review aids for campaign steps started with --level= or --boss= (debug builds): the lane count,
## god mode, no falls, a full loadout, and for a boss fight its starting phase (--phase=N) and, in
## quick play, its look (--skin=), for every run the session plays.
func _apply_review_args(ctx: RunContext) -> void:
	for arg: String in _review_args:
		if arg.begins_with("--lanes="):
			ctx.config.lane_count = int(arg.get_slice("=", 1))
		elif arg == "--god":
			ctx.god_mode = true
		elif arg == "--nofall":
			ctx.no_fall = true
		elif arg == "--full-loadout":
			ctx.loadout = Loadout.full(catalog)
			if ctx.boss != null:
				ctx.loadout.grant(ctx.boss.granted_items, catalog, mobile)
		elif arg.begins_with("--phase=") and ctx.boss != null:
			var index: int = clampi(int(arg.get_slice("=", 1)) - 1, 0, ctx.boss.phase_count() - 1)
			ctx.boss_resume = {"phase": index} if index > 0 else {}
		elif arg.begins_with("--skin=") and ctx.boss != null and ctx.mode == RunContext.Mode.QUICK:
			var skin_path: String = "res://data/skins/%s_skin.tres" % arg.get_slice("=", 1)
			if ResourceLoader.exists(skin_path):
				ctx.config.skin = load(skin_path) as ZoneSkin


## --boss=<id>: a zone's boss by its step (the full flow; a fight still being built, BossDef.preview(),
## as quick play), or data/bosses/<id>.tres as quick play. False if there's no such boss, or it isn't
## built.
func _start_boss_arg(id: String, args: PackedStringArray) -> bool:
	for s: CampaignStep in campaign.steps():
		if s.kind == CampaignStep.Kind.BOSS and s.boss != null and String(s.boss.id) == id:
			var preview: BossDef = s.boss.preview()
			if preview != null:
				start_boss_quick(preview, args)
				return true
			_review_args = args
			play_step(s)
			return true
	var path: String = BOSSES_DIR.path_join(id + ".tres")
	var def: BossDef = load(path) as BossDef if ResourceLoader.exists(path) else null
	if def == null or not def.is_built():
		push_warning("App: no built boss '%s' (%s)" % [id, path])
		return false
	start_boss_quick(def, args)
	return true


## A boss fight's movement tuning: the run speed never rises during the fight (GDD §10: no
## escalation, however long it lasts).
func _boss_tuning(base: MovementTuning) -> MovementTuning:
	if is_zero_approx(base.speed_gain_per_minute):
		return base
	var t: MovementTuning = base.duplicate() as MovementTuning
	t.speed_gain_per_minute = 0.0
	return t


## The grey-box workflow: the prototype level with command-line overrides, restarting on death.
func start_quick(args: PackedStringArray = PackedStringArray()) -> void:
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.config = (load(QUICK_LEVEL_PATH) as LevelConfig).duplicate() as LevelConfig
	ctx.config.lane_count = lane_count()
	ctx.tuning = tuning
	ctx.loadout = make_loadout()
	for arg: String in args:
		var v: String = arg.get_slice("=", 1)
		if arg.begins_with("--lanes="):
			ctx.config.lane_count = int(v)
		elif arg.begins_with("--seed="):
			ctx.config.level_seed = int(v)
		elif arg.begins_with("--difficulty="):
			ctx.config.difficulty = float(v)
		elif arg.begins_with("--speed="):
			# Review aid: quick play at a zone's run speed (GDD §3: 21 m/s in the City to 25 in the
			# Golden Zone); the level stretches its patterns to keep their timing (MovementTuning.pace).
			ctx.config.run_speed = maxf(float(v), 0.0)
		elif arg.begins_with("--doodads="):
			# Review aid: the prototype level has no doodads (GDD §3); this gives it a share of them.
			ctx.config.doodad_share = clampf(float(v), 0.0, 1.0)
		elif arg == "--god":
			ctx.god_mode = true
		elif arg == "--nofall":
			ctx.no_fall = true
		elif arg.begins_with("--skin="):
			var skin_path: String = "res://data/skins/%s_skin.tres" % v
			if ResourceLoader.exists(skin_path):
				ctx.config.skin = load(skin_path) as ZoneSkin
			else:
				push_warning("App: no zone skin at %s" % skin_path)
		elif arg.begins_with("--features="):
			for f: String in v.split(",", false):
				if not ctx.config.features.has(f):
					ctx.config.features.append(f)
		elif arg == "--full-loadout":
			ctx.loadout = Loadout.full(catalog)
		elif arg == "--pickups" or arg.begins_with("--pickups="):
			# Review aid: pickups in turn (all three, or the ones listed), though levels have none.
			ctx.review_pickups = v.split(",", false) if arg.contains("=") else PackedStringArray(PickupField.ITEMS)
		elif arg == "--thief":
			# Review aid: stand-in thieves (GDD §9.12, task B6), though the prototype level has none.
			ctx.review_thief = true
	ctx.tuning = ctx.config.movement_for(tuning)
	_start_run(ctx, &"city")


## DESIGN-TBD (OPEN_QUESTIONS §8): endless mode is one long random level in the furthest zone
## reached, getting harder the longer it lasts; credits pay out like a death (a share).
func start_endless() -> void:
	var zone: ZoneDef = _furthest_zone()
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.ENDLESS
	var base: LevelConfig = zone.levels[zone.levels.size() - 1] if zone != null and not zone.levels.is_empty() \
		else load(QUICK_LEVEL_PATH) as LevelConfig
	ctx.config = base.duplicate() as LevelConfig
	ctx.config.id = &"endless"
	ctx.config.display_name = "Endless"
	ctx.config.level_seed = randi()
	ctx.config.lane_count = lane_count()
	ctx.config.duration_seconds = ENDLESS_SECONDS
	ctx.config.difficulty = 0.2
	ctx.config.difficulty_ramp = 0.8
	ctx.config.enemy_scaling = 1.0
	# Everything the zone has, from the start: a campaign level's introductions (feature_starts)
	# would hold features back for minutes in a 20-minute level. (A new dictionary: the copy shares
	# the level's.)
	ctx.config.feature_starts = {}
	# A 20-minute random level brings every feature many times over, so the campaign's guarantee
	# (every feature at least once, which may rebuild the level) would only cost load time.
	ctx.config.guarantee_features = false
	# The zone's play, not one level's own shape: The Hush's quiet stretches and bursts, the hosts it
	# picks more often for them (its quiet features' weights) and its darker lighting stay in The Hush
	# (GDD §5). (A new dictionary: the copy shares the level's.)
	ctx.config.quiet_seconds = 0.0
	ctx.config.darkness = 0.0
	var weights: Dictionary[String, float] = ctx.config.feature_weights.duplicate()
	for f: String in ctx.config.quiet_features:
		weights.erase(f)
	ctx.config.feature_weights = weights
	ctx.config.quiet_features = PackedStringArray()
	if ctx.config.skin == null and zone != null:
		ctx.config.skin = zone.skin
	# The zone's pace (GDD §3: the run speed rises zone by zone), unless its level has its own.
	if ctx.config.run_speed <= 0.0 and zone != null:
		ctx.config.run_speed = zone.run_speed
	ctx.tuning = ctx.config.movement_for(tuning)
	ctx.loadout = make_loadout()
	_start_run(ctx, zone.music if zone != null else &"city")


## The next attempt at the same level or boss fight (same seed; a boss fight resumes at a checkpoint
## it reached, GDD §10), with the loadout as the shop left it.
func retry(ctx: RunContext) -> void:
	var next: RunContext = ctx.retry()
	next.loadout = make_loadout(ctx.boss)
	next.revives_used = 0
	_start_run(next, _music_for(next))


func pause_game() -> void:
	if run == null or get_tree().paused:
		return
	get_tree().paused = true
	if has_node(^"/root/Music"):
		get_node(^"/root/Music").call(&"set_ducked", true)
	show_overlay(PauseScreen.new())


func resume_game() -> void:
	close_overlay()
	get_tree().paused = false
	if has_node(^"/root/Music"):
		get_node(^"/root/Music").call(&"set_ducked", false)


## Leaves a run from the pause menu (GDD §4, decided September 26, 2026): keeps
## `GameRules.death_credit_keep_fraction` of this attempt's credits, like a death, but it's never a
## completion and never touches a level's best score, stars, best time or leaderboard placement (the
## `deaths` stat isn't bumped either: quitting isn't dying). Quick play (the grey-box review tool)
## never touches the wallet or profile at all on a quit, same as on a death or a finish there. A
## boss fight quit follows the same rule; it just can't keep a checkpoint reached this attempt, since
## starting the step afresh never does (RunContext.boss_resume, documented there) and quitting has
## nowhere else to carry it to.
func quit_run() -> void:
	if run == null:
		resume_game()
		return
	var campaign_run: bool = run.context.is_campaign()
	var result: RunResult = run.quit_result() if run.context.mode != RunContext.Mode.QUICK else null
	resume_game()
	if result != null:
		_apply_result(result, false)
	if campaign_run:
		show_level_select()
	else:
		show_title()
	if result != null and result.credits_earned > 0:
		Toast.show_message(screen, "+%s credits kept" % UiTheme.format_int(result.credits_earned),
			IconFactory.credit_icon(100))


func _start_run(ctx: RunContext, music: StringName) -> void:
	_end_run()
	close_overlay()
	if screen != null and is_instance_valid(screen):
		screen.queue_free()
	screen = null
	get_tree().paused = false
	run = LevelRun.new()
	run.name = "LevelRun"
	main.world_root.add_child(run)
	run.died.connect(_on_run_died)
	run.finished.connect(_on_run_finished)
	run.pause_requested.connect(pause_game)
	run.item_used.connect(_on_item_used)
	run.start(ctx)
	TouchInput.enabled = true
	var director: MusicDirector = MusicDirector.instance()
	if director != null:
		_play_music(director.library.run_track(music, ctx.boss.id if ctx.is_boss() else &""))


func _end_run() -> void:
	get_tree().paused = false
	TouchInput.enabled = false
	if run != null and is_instance_valid(run):
		run.queue_free()
	run = null
	if _boss_node != null and is_instance_valid(_boss_node):
		_boss_node.queue_free()
	_boss_node = null


## A breakable item broke during a run: it leaves the stock at once (GDD §8), so quitting can't
## save it. An item a boss fight granted, or one picked up during the fight, was the fight's, not the
## player's (Loadout.costs_stock). The armor is no stock (GDD §8: a permanent upgrade to the free
## armor, which comes back), so its breaks cost nothing.
func _on_item_used(item: StringName) -> void:
	var shop_item: ShopItem = catalog.item(item)
	if shop_item == null or shop_item.kind != ShopItem.Kind.BREAKABLE:
		return
	if run != null and run.context.loadout != null and not run.context.loadout.costs_stock(item):
		return
	profile.use_stock(item)
	save()
	profile_changed.emit()


func _on_run_died(_run: LevelRun) -> void:
	get_tree().paused = true
	show_overlay(DeathScreen.new())


## What the revive offer can show (GDD §4: mobile: rewarded ad or revive item; PC: revive item).
func revive_options() -> Dictionary:
	var left: bool = run != null and run.context.revives_used < rules.max_revives_per_attempt
	return {
		"item": left and profile.stock(&"revive") > 0 and profile.is_equipped(&"revive"),
		"ad": left and Platform.ads_available(),
		"stock": profile.stock(&"revive"),
	}


func revive_with_item() -> void:
	if run == null or not revive_options()["item"]:
		return
	profile.use_stock(&"revive")
	save()
	_revive()


func revive_with_ad() -> void:
	if run == null or not revive_options()["ad"]:
		return
	var rewarded: bool = await Platform.show_rewarded_ad(&"revive")
	if rewarded and run != null:
		_revive()


func decline_revive() -> void:
	close_overlay()
	get_tree().paused = false
	if run != null:
		run.give_up()


func _revive() -> void:
	close_overlay()
	get_tree().paused = false
	run.revive()


func _on_run_finished(result: RunResult) -> void:
	_apply_result(result)
	var ctx: RunContext = result.context
	var s := ResultsScreen.new()
	s.result = result
	_end_run()
	_play_music(&"menu")
	show_screen(s)
	if not result.completed:
		play_ui_sound(&"ui_back")
	elif ctx.is_campaign() and result.record.get("first_clear", false):
		play_ui_sound(&"ui_unlock")


## Pays the wallet, stores records and submits leaderboards for a finished run. `count_as_death`
## gates the `deaths` stat only: quitting from the pause menu (quit_run) keeps the same credit share
## as a death (GDD §4) without having died.
func _apply_result(result: RunResult, count_as_death: bool = true) -> void:
	var ctx: RunContext = result.context
	profile.add_earned(result.credits_earned)
	profile.stat_add("runs")
	profile.stat_add("kills", int(result.stats.get("kills", 0)))
	profile.stat_add("credits_collected", result.credits_collected)
	if result.completed:
		profile.stat_add("bosses_defeated" if ctx.is_boss() else "levels_completed")
	elif count_as_death:
		profile.stat_add("deaths")
	if ctx.is_campaign():
		# Levels and bosses alike (GDD §10: bosses have records, stars and leaderboards like levels).
		result.record = profile.record_run(ctx.step.id, ctx.difficulty_tier, result.completed, result.score,
			result.stars, result.time)
		if result.completed:
			Platform.submit_score(ctx.leaderboard_id(), result.score)
			_check_game_finished()
	elif ctx.mode == RunContext.Mode.ENDLESS:
		var key: String = "%d/%d" % [ctx.config.lane_count, ctx.difficulty_tier]
		if result.score > int(profile.endless_best.get(key, 0)):
			profile.endless_best[key] = result.score
			result.record = {"new_best": true}
		Platform.submit_score(ctx.leaderboard_id(), result.score)
	Platform.submit_score("net_worth", profile.net_worth())
	save()
	profile_changed.emit()


## After the last campaign step, the next difficulty tier opens (GDD §6).
func _check_game_finished() -> void:
	var all: Array[CampaignStep] = campaign.steps()
	if all.is_empty():
		return
	for tier: int in range(profile.unlocked_tier, -1, -1):
		if profile.is_completed(all[-1].id, tier) and profile.unlocked_tier == tier \
				and tier + 1 < campaign.tier_count():
			profile.unlocked_tier = tier + 1


## The way on from a results screen: the shop, then the next level or a retry (GDD §4, §8).
func continue_after_result(result: RunResult) -> void:
	var ctx: RunContext = result.context
	if ctx.is_campaign() and result.completed:
		show_shop(func() -> void: advance_from(ctx.step), "Next")
	elif ctx.mode == RunContext.Mode.ENDLESS:
		show_shop(start_endless, "Play again")
	else:
		show_shop(func() -> void: retry(ctx), "Retry")


# --- Shop ----------------------------------------------------------------------------

## The price of the next purchase of an item (next tier, or one more unit), or -1 if it can't be
## bought (maxed out or not sold here).
func next_price(item: ShopItem) -> int:
	if not item.available_on(mobile):
		return -1
	if item.kind == ShopItem.Kind.PERMANENT:
		var next_tier: int = profile.tier(item.id) + 1
		return item.price_of(next_tier, mobile) if next_tier <= item.tier_count() else -1
	return item.price_of(1, mobile) if profile.stock(item.id) < item.max_stock else -1


## Buys the next tier or one more unit. False (nothing spent) if it can't be bought or afforded.
func buy(id: StringName) -> bool:
	var item: ShopItem = catalog.item(id)
	if item == null:
		return false
	var price: int = next_price(item)
	if price < 0 or not profile.spend(price):
		play_ui_sound(&"ui_error")
		return false
	if item.kind == ShopItem.Kind.PERMANENT:
		profile.set_tier(id, profile.tier(id) + 1)
	else:
		profile.add_stock(id, 1)
	play_ui_sound(&"ui_buy")
	save()
	profile_changed.emit()
	return true


## The shop's equip toggle (GDD §8: challenge runs, net-worth play, balance safety valve).
func set_equipped(id: StringName, on: bool) -> void:
	profile.set_equipped(id, on)
	play_ui_sound(&"ui_equip")
	save()
	profile_changed.emit()


## Mobile only: buys a credit pack through the platform (GDD §7: tracked apart from earned credits).
func buy_credit_pack(product_id: StringName) -> bool:
	for p: Dictionary in Platform.products():
		if p["id"] == product_id:
			var ok: bool = await Platform.purchase(product_id)
			if ok:
				profile.add_purchased(int(p["credits"]))
				save()
				profile_changed.emit()
			return ok
	return false


func save() -> void:
	if autosave:
		SaveService.save_profile(profile, save_path)


# --- Bosses and cinematics (placeholder cards until built) --------------------------------

## A boss step: the fight (a run like a level's, start_boss), or its placeholder card until built.
func _play_boss(s: CampaignStep, difficulty_tier: int) -> void:
	_end_run()
	if s.boss == null or not s.boss.is_built():
		var card := SlotScreen.new()
		card.step = s
		show_screen(card)
		return
	start_boss(s, difficulty_tier)


## A cinematic step: its scene under the world root (it takes its zone and slot from the step), skippable
## (skip_cinematic), then on to the next step; or its placeholder card until built.
func _play_cinematic(s: CampaignStep) -> void:
	_end_run()
	if s.cinematic == null or not s.cinematic.is_built():
		var card := SlotScreen.new()
		card.step = s
		show_screen(card)
		return
	close_overlay()
	if screen != null and is_instance_valid(screen):
		screen.queue_free()
	screen = null
	var node: Node = (load(s.cinematic.scene) as PackedScene).instantiate()
	_boss_node = node
	main.world_root.add_child(node)
	var c := node as Cinematic
	c.skip_requested.connect(skip_cinematic)
	c.finished.connect(func() -> void:
		profile.mark_seen("cinematic/" + s.id)
		complete_step(s)
		advance_from(s), CONNECT_ONE_SHOT)
	c.play(s.cinematic, s)


## The cinematic playing (a built cinematic slot), or null.
func playing_cinematic() -> Cinematic:
	return _boss_node as Cinematic if _boss_node != null and is_instance_valid(_boss_node) else null


## Skips the cinematic playing, if any: the player asked (the pause action, or its skip button). It ends
## at once and the campaign moves on, as when it plays out.
func skip_cinematic() -> void:
	var c: Cinematic = playing_cinematic()
	if c != null:
		c.skip()


# --- Helpers ----------------------------------------------------------------------------

func _tuning_for_tier(difficulty_tier: int) -> MovementTuning:
	var mult: float = campaign.speed_multiplier(difficulty_tier)
	if is_equal_approx(mult, 1.0):
		return tuning
	var t: MovementTuning = tuning.duplicate() as MovementTuning
	t.run_speed *= mult
	return t


func _furthest_zone() -> ZoneDef:
	var best: ZoneDef = null
	for s: CampaignStep in campaign.steps():
		if s.is_level() and step_unlocked(s) and in_demo_scope(s):
			best = s.zone
	return best


func _music_for(ctx: RunContext) -> StringName:
	if ctx.is_boss() and ctx.boss.music != &"":
		return ctx.boss.music
	return ctx.step.zone.music if ctx.is_campaign() else &"city"


func _play_music(track: StringName) -> void:
	if has_node(^"/root/Music") and track != &"":
		get_node(^"/root/Music").call(&"play", track)

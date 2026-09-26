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
##   --level=city/2          a campaign level, with the full flow
##   --flavor=web_demo       pretend to be another build flavor (full_pc, full_mobile, web_demo)

signal profile_changed

const TUNING_PATH: String = "res://data/tuning/movement.tres"
const RULES_PATH: String = "res://data/tuning/game_rules.tres"
const POWERUPS_PATH: String = "res://data/tuning/powerups.tres"
const CAMPAIGN_PATH: String = "res://data/campaign/campaign.tres"
const SFX_PATH: String = "res://data/audio/sfx_library.tres"
const QUICK_LEVEL_PATH: String = "res://data/levels/prototype_level.tres"
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


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			# A phone call, the home button or another window: never keep running unattended.
			if run != null and run.state == LevelRun.State.RUNNING and run.context.mode != RunContext.Mode.QUICK:
				pause_game()
			save()
		NOTIFICATION_WM_CLOSE_REQUEST:
			save()


## Main calls this once its layers exist. Starts wherever the command line says.
func boot(p_main: Node) -> void:
	main = p_main
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for arg: String in args:
		if arg.begins_with("--level="):
			var s: CampaignStep = campaign.step(arg.get_slice("=", 1))
			if s != null:
				play_step(s)
				return
	for arg: String in args:
		if arg == "--quick" or arg == "--god" or arg.begins_with("--seed=") or arg.begins_with("--lanes=") \
				or arg.begins_with("--difficulty=") or arg.begins_with("--features=") or arg == "--full-loadout":
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


## Marks a boss or cinematic step as done (placeholders complete when the player continues).
func complete_step(s: CampaignStep, score: int = 0) -> void:
	profile.record_run(s.id, 0, true, score, 3, 0.0)
	save()


func lane_count() -> int:
	return rules.lanes_for_device(mobile)


## What the player takes into the next run, from what they own and have switched on.
func make_loadout() -> Loadout:
	return Loadout.from_profile(profile, catalog, mobile)


# --- Runs --------------------------------------------------------------------------

func start_level(s: CampaignStep, difficulty_tier: int = 0) -> void:
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.CAMPAIGN
	ctx.step = s
	ctx.difficulty_tier = difficulty_tier
	ctx.config = campaign.configure(s, lane_count(), difficulty_tier)
	ctx.tuning = _tuning_for_tier(difficulty_tier)
	ctx.loadout = make_loadout()
	ctx.level_index = s.level_index
	_start_run(ctx, s.zone.music)


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
		elif arg == "--god":
			ctx.god_mode = true
		elif arg.begins_with("--features="):
			for f: String in v.split(",", false):
				if not ctx.config.features.has(f):
					ctx.config.features.append(f)
		elif arg == "--full-loadout":
			ctx.loadout = Loadout.full(catalog)
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
	if ctx.config.skin == null and zone != null:
		ctx.config.skin = zone.skin
	ctx.tuning = tuning
	ctx.loadout = make_loadout()
	_start_run(ctx, zone.music if zone != null else &"city")


func retry(ctx: RunContext) -> void:
	var next: RunContext = ctx.retry()
	next.loadout = make_loadout()
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


## Leaves a run from the pause menu (no credits, like quitting a level in most runners).
func quit_run() -> void:
	var campaign_run: bool = run != null and run.context.is_campaign()
	resume_game()
	if campaign_run:
		show_level_select()
	else:
		show_title()


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
	_play_music(music)


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
## save it.
func _on_item_used(item: StringName) -> void:
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


## Pays the wallet, stores records and submits leaderboards for a finished run.
func _apply_result(result: RunResult) -> void:
	var ctx: RunContext = result.context
	profile.add_earned(result.credits_earned)
	profile.stat_add("runs")
	profile.stat_add("kills", int(result.stats.get("kills", 0)))
	profile.stat_add("credits_collected", result.credits_collected)
	if result.completed:
		profile.stat_add("levels_completed")
	else:
		profile.stat_add("deaths")
	if ctx.is_campaign():
		result.record = profile.record_run(ctx.step.id, ctx.difficulty_tier, result.completed, result.score,
			result.stars, result.time)
		if result.completed:
			Platform.submit_score("level/%s/%d" % [ctx.step.id, ctx.difficulty_tier], result.score)
			_check_game_finished()
	elif ctx.mode == RunContext.Mode.ENDLESS:
		var key: String = "%d/%d" % [ctx.config.lane_count, ctx.difficulty_tier]
		if result.score > int(profile.endless_best.get(key, 0)):
			profile.endless_best[key] = result.score
			result.record = {"new_best": true}
		Platform.submit_score("endless/%s" % key, result.score)
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


# --- Bosses and cinematics (slots until designed) ----------------------------------------

func _play_boss(s: CampaignStep, difficulty_tier: int) -> void:
	_end_run()
	if s.boss == null or not s.boss.is_built():
		var card := SlotScreen.new()
		card.step = s
		show_screen(card)
		return
	close_overlay()
	if screen != null and is_instance_valid(screen):
		screen.queue_free()
	screen = null
	var node: Node = (load(s.boss.scene) as PackedScene).instantiate()
	_boss_node = node
	main.world_root.add_child(node)
	var encounter := node as BossEncounter
	encounter.finished.connect(func(won: bool, score: int, earned: int) -> void:
		profile.add_earned(earned)
		if won:
			complete_step(s, score)
			advance_from(s)
		else:
			save()
			play_step(s, difficulty_tier))
	encounter.begin(s.boss, make_loadout(), lane_count(), difficulty_tier)


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
	c.finished.connect(func() -> void:
		profile.mark_seen("cinematic/" + s.id)
		complete_step(s)
		advance_from(s), CONNECT_ONE_SHOT)
	c.play(s.cinematic)


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
	return ctx.step.zone.music if ctx.is_campaign() else &"city"


func _play_music(track: StringName) -> void:
	if has_node(^"/root/Music") and track != &"":
		get_node(^"/root/Music").call(&"play", track)

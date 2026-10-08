extends TestSuite
## The game's flow through the App on the real main scene: title, campaign levels, the death flow
## (revive offer → summary → shop → retry, GDD §4), completion and records, pause, boss and
## cinematic slots, the web demo's end screen, rewarded-ad revives on mobile, and endless mode.

var main: Node


func run() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var saved: Profile = App.profile
	App.profile = Profile.new()

	check(App.screen is TitleScreen, "the game boots to the title screen")
	await _test_death_flow()
	await _test_revive_with_item()
	await _test_completion()
	await _test_pause()
	await _test_slots_and_demo()
	await _test_ad_revive()
	await _test_darker_level()
	await _test_level_sky()
	await _test_endless()

	App.show_title()
	await tree.process_frame
	App.profile = saved
	main.queue_free()
	App.main = null
	await tree.process_frame


func _campaign_level(id: String) -> void:
	App.start_level(App.campaign.step(id))
	App.begin_run()
	await physics_frames(10)


func _kill_player() -> void:
	App.run.world.player._die("test hazard")
	# The death reads for a moment before the revive offer (rules.death_screen_delay).
	await physics_frames(int((App.rules.death_screen_delay + 0.3) * 60.0))
	await tree.process_frame


func _test_death_flow() -> void:
	await _campaign_level("city/1")
	check(App.run != null and App.run.context.is_campaign(), "a campaign level starts")
	check(App.run.world.geo.lane_count == 5, "with the PC lane count")
	App.run.world.score.add_credit(25)
	await _kill_player()
	await tree.process_frame
	# No revive item and no ads on PC: straight to the run summary.
	check(App.screen is ResultsScreen, "with nothing to revive with, the summary shows (%s)" % App.screen)
	var result: RunResult = (App.screen as ResultsScreen).result if App.screen is ResultsScreen else null
	check(result != null and not result.completed, "the summary is for a failed run")
	if result == null:
		return
	check(result.credits_earned == 5, "dying keeps 20%% of the credits collected (GDD §4): %d" % result.credits_earned)
	check(App.profile.credits() == 5, "and pays them into the wallet")
	check(not App.profile.is_completed("city/1"), "the level isn't completed")
	App.continue_after_result(result)
	check(App.screen is ShopScreen and (App.screen as ShopScreen).play_label == "Retry", "then the shop, with a way to retry")
	(App.screen as ShopScreen).on_close.call()
	await physics_frames(5)
	check(App.run != null and App.run.context.attempt == 2, "retry starts attempt 2 of the same level")
	check(App.run.context.config.level_seed == App.campaign.step("city/1").level.level_seed, "with the same seed (GDD §6)")


func _test_revive_with_item() -> void:
	App.profile.add_stock(&"revive", 1)
	await _campaign_level("city/1")
	await _kill_player()
	check(App.overlay is DeathScreen, "with a revive in stock, the revive offer shows")
	check(get_tree_paused(), "the game is paused behind the offer")
	App.revive_with_item()
	await physics_frames(3)
	check(App.run.world.player.alive and App.profile.stock(&"revive") == 0, "reviving uses the item and continues the run")
	check(not get_tree_paused() and App.overlay == null, "and unpauses")
	App.run.world.player._die("again")
	await physics_frames(int((App.rules.death_screen_delay + 0.3) * 60.0))
	await tree.process_frame
	check(App.screen is ResultsScreen, "one revive per attempt: the next death goes to the summary")


func _test_completion() -> void:
	App.profile = Profile.new()
	await _campaign_level("city/1")
	var world: RunWorld = App.run.world
	world.score.add_credit(100)
	world.player.distance = world.layout.length - 3.0
	await physics_frames(int((LevelRun.COMPLETE_PAUSE + 0.5) * 60.0))
	await tree.process_frame
	check(App.screen is ResultsScreen, "finishing a level shows the results (%s)" % App.screen)
	if not App.screen is ResultsScreen:
		return
	var result: RunResult = (App.screen as ResultsScreen).result
	check(result.completed and result.stars >= 1, "completed with at least one star")
	var bonus: int = App.rules.completion_bonus(0)
	check(result.credits_earned == 100 + bonus and App.profile.credits() == 100 + bonus,
		"completion pays everything collected plus the bonus (%d)" % result.credits_earned)
	check(App.profile.is_completed("city/1") and App.step_unlocked(App.campaign.step("city/2")), "and unlocks the next level")
	App.continue_after_result(result)
	check(App.screen is ShopScreen and (App.screen as ShopScreen).play_label == "Next", "the shop sits between levels")
	(App.screen as ShopScreen).on_close.call()
	await physics_frames(5)
	check(App.run != null and App.run.context.step.id == "city/2", "then the next level starts")


func _test_pause() -> void:
	App.begin_run()
	App.pause_game()
	check(get_tree_paused() and App.overlay is PauseScreen, "pause shows the pause menu and stops the game")
	var d: float = App.run.world.player.distance
	await physics_frames(10)
	check(is_equal_approx(App.run.world.player.distance, d), "nothing moves while paused")
	App.resume_game()
	await physics_frames(10)
	check(not get_tree_paused() and App.run.world.player.distance > d, "resume continues the run")


func _test_slots_and_demo() -> void:
	# The City's boss is built (task E1d; test_floating_head_defeat.gd plays its whole flow), and Gangland's
	# (E4b), the Marketplace's and the Dead Zone's; the Golden Palace's is still a placeholder card.
	App.play_step(App.campaign.step("golden/boss"))
	check(App.screen is SlotScreen and App.run == null, "an unbuilt boss shows its placeholder card")
	var card := App.screen as SlotScreen
	if card == null:
		return
	App.complete_step(card.step)
	App.advance_from(card.step)
	check(App.screen is SlotScreen and (App.screen as SlotScreen).step.id == "golden/outro",
		"continuing moves on to the next step (the outro cinematic slot)")
	BuildFlavor.set_override(BuildFlavor.Kind.WEB_DEMO)
	App.advance_from(App.campaign.step("city/outro"))
	check(App.screen is DemoEndScreen, "the web demo ends after Zone 1 with the store-link screen (GDD §2)")
	BuildFlavor.set_override(-1)
	App.show_level_select()
	check(App.screen is LevelSelectScreen, "the level select opens")
	App.show_shop()
	check(App.screen is ShopScreen, "the shop opens from the menu")
	App.show_settings()
	check(App.screen is SettingsScreen, "settings open")


func _test_ad_revive() -> void:
	Platform.configure_for(BuildFlavor.Kind.FULL_MOBILE)
	(Platform.backend as StubBackend).fake_ad_seconds = 0.0
	check(Platform.ads_available(), "mobile builds offer rewarded ads")
	await _campaign_level("city/1")
	await _kill_player()
	check(App.overlay is DeathScreen and App.revive_options()["ad"], "the revive offer includes an ad on mobile")
	await App.revive_with_ad()
	await physics_frames(3)
	check(App.run != null and App.run.world.player.alive, "watching the ad revives the player")
	Platform.configure_for(BuildFlavor.current())
	check(not Platform.ads_available(), "no ads on PC")


## Endless mode plays the furthest zone's last level (here City 3, which introduces its new things
## at starts of their own) with every feature there from the start; the campaign level keeps its
## starts.
func _test_endless() -> void:
	for id: String in ["city/intro", "city/1", "city/2"]:
		App.profile.record_run(id, 0, true, 100, 3, 10.0)
	var city_3: LevelConfig = App.campaign.step("city/3").level
	App.start_endless()
	App.begin_run()
	await physics_frames(3)
	var ctx: RunContext = App.run.context if App.run != null else null
	check(ctx != null and ctx.mode == RunContext.Mode.ENDLESS, "endless mode starts")
	if ctx != null:
		check(ctx.config.features == city_3.features and ctx.config.feature_starts.is_empty(),
			"endless plays the furthest zone's features from the start (%s)" % [ctx.config.feature_starts])
	check(city_3.feature_starts.size() == 3, "and the campaign level keeps its own starts")
	if ctx != null:
		check(not ctx.config.guarantee_features and city_3.guarantee_features,
			"endless skips the campaign's every-feature guarantee (a 20-minute level needs no rebuilds)")
		check(ctx.config.sky == null and city_3.sky != null and _cloud_amount(App.run) == 0.0,
			"endless has the zone's own sky, not its last level's dawn (City 3 keeps it)")
	App.show_title()
	# With the Dead Zone reached, endless copies The Hush but not its own remix: its pacing in bursts,
	# the hosts it picks more often, or its darkness.
	for s: CampaignStep in App.campaign.steps():
		if s.index < App.campaign.step("dead_zone/2").index:
			App.profile.record_run(s.id, 0, true, 100, 3, 10.0)
	var hush: LevelConfig = App.campaign.step("dead_zone/2").level
	App.start_endless()
	App.begin_run()
	await physics_frames(3)
	var dead: RunContext = App.run.context if App.run != null else null
	check(dead != null and dead.config.features == hush.features
		and not dead.config.paced_in_bursts() and dead.config.darkness == 0.0,
		"endless in the Dead Zone plays The Hush's features, evenly paced, in the zone's own light")
	check(dead != null and dead.config.feature_weight("host") == 1.0 and dead.config.quiet_features.is_empty()
		and hush.feature_weight("host") > 1.0 and hush.quiet_features == PackedStringArray(["host"]),
		"with hosts as often as elsewhere, and The Hush keeps its own")
	App.show_title()


## GDD §5: The Hush's darker lighting reaches its run: the run's environment is the zone skin's with
## the level's darkness (ZoneSkin.level_environment), and the scenery light comes back when the run
## ends.
func _test_darker_level() -> void:
	await _campaign_level("dead_zone/2")
	var run: LevelRun = App.run
	check(run != null and run.context.config.darkness > 0.0, "The Hush starts, with its darkness")
	if run == null:
		return
	# The run's WorldEnvironment sets its world's environment.
	var env: Environment = run.get_world_3d().environment
	var plain: Environment = run.world.skin.make_environment()
	var light: float = ZoneSkin.scenery_light_for(run.context.config.darkness)
	check(env != null and is_equal_approx(env.background_energy_multiplier, plain.background_energy_multiplier * ZoneSkin.energy_factor(light))
		and is_equal_approx(ZoneSkin.scenery_light_now, light), "its run's scenery is darker (%.2f)" % ZoneSkin.scenery_light_now)
	# The next level's run sets its own light, and The Hush's, freed after it started, leaves it alone.
	await _campaign_level("golden/1")
	check(ZoneSkin.scenery_light_now == 1.0, "the next level has its zone's own light (%.2f)" % ZoneSkin.scenery_light_now)
	await _campaign_level("dead_zone/2")
	App.show_title()
	await physics_frames(2)
	check(ZoneSkin.scenery_light_now == 1.0, "and the light comes back when the run ends")


## A level's own sky (LevelConfig.sky; owner, October 8, 2026) reaches its run: Gangland 3's run has its
## cloudy blood-red sky and fog, and Gangland 2's the zone's own.
func _test_level_sky() -> void:
	await _campaign_level("gangland/3")
	var run: LevelRun = App.run
	var sky: LevelSky = run.context.config.sky if run != null else null
	check(sky != null and sky.sky.has("cloud_amount"), "Gangland 3 starts, with its own sky")
	if sky == null:
		return
	var env: Environment = run.get_world_3d().environment
	check(env != null and is_equal_approx(_cloud_amount(run), float(sky.sky["cloud_amount"]))
		and env.fog_light_color == sky.fog_color, "its run's sky is cloudy, and the fog takes its colour")
	await _campaign_level("gangland/2")
	check(App.run != null and App.run.context.config.sky == null and _cloud_amount(App.run) == 0.0
		and App.run.get_world_3d().environment.fog_light_color == (App.run.world.skin as GanglandSkin).fog_color,
		"Gangland 2's run has the zone's own sky")
	App.show_title()


## The cloud cover of a run's sky (0 when the shader's default, no clouds, holds).
func _cloud_amount(run: LevelRun) -> float:
	var env: Environment = run.get_world_3d().environment if run != null else null
	var m: ShaderMaterial = env.sky.sky_material as ShaderMaterial if env != null and env.sky != null else null
	var v: Variant = m.get_shader_parameter("cloud_amount") if m != null else null
	return float(v) if v != null else 0.0


func get_tree_paused() -> bool:
	return tree.paused

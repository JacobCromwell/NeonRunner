extends TestSuite
## The game's flow through the App on the real main scene: title, campaign levels, the death flow
## (revive offer → summary → shop → retry, GDD §4), completion and records, pause, boss and
## cinematic slots, the web demo's end screen, and rewarded-ad revives on mobile.

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

	App.show_title()
	await tree.process_frame
	App.profile = saved
	main.queue_free()
	App.main = null
	await tree.process_frame


func _campaign_level(id: String) -> void:
	App.start_level(App.campaign.step(id))
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
	App.pause_game()
	check(get_tree_paused() and App.overlay is PauseScreen, "pause shows the pause menu and stops the game")
	var d: float = App.run.world.player.distance
	await physics_frames(10)
	check(is_equal_approx(App.run.world.player.distance, d), "nothing moves while paused")
	App.resume_game()
	await physics_frames(10)
	check(not get_tree_paused() and App.run.world.player.distance > d, "resume continues the run")


func _test_slots_and_demo() -> void:
	App.play_step(App.campaign.step("city/boss"))
	check(App.screen is SlotScreen and App.run == null, "an unbuilt boss shows its placeholder card")
	var card := App.screen as SlotScreen
	App.complete_step(card.step)
	App.advance_from(card.step)
	check(App.screen is SlotScreen and (App.screen as SlotScreen).step.id == "city/outro",
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


func get_tree_paused() -> bool:
	return tree.paused

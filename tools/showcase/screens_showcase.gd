extends Node
## Every game screen on the real App flow, for reviewing the look (not part of the game). It boots
## the main scene with a sample profile (SampleProfiles.rich(); nothing is saved) and opens one
## screen:
##   godot --path . res://tools/showcase/screens_showcase.tscn -- --screen=shop
## Screens: title, levels, shop, shop_next, settings, pause, pause_settings, death, results,
## failed, slot, cinematic, demo_end, hud.
## Options: --fresh (a new profile), --progress=<step id> (every campaign step before that one
## completed, e.g. --progress=golden/1), --touch (phone/tablet sizing), --mobile (a mobile build:
## 3 lanes, credit packs, rewarded ads), --flavor=web_demo (read by App), --scroll-end (scrolls the
## screen's list to its end), --wait=N (frames before a shot), --shot=<png> (saves a screenshot and
## quits: any window size, unlike --write-movie).

var main: Node


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--touch"):
		UiTheme.touch_override = 1
	App.autosave = false
	if args.has("--mobile"):
		App.mobile = true
		Platform.configure_for(BuildFlavor.Kind.FULL_MOBILE)
		(Platform.backend as StubBackend).fake_ad_seconds = 30.0
	App.profile = SampleProfiles.fresh() if args.has("--fresh") else SampleProfiles.rich()
	if args.has("--mobile") and not args.has("--fresh"):
		App.profile.add_purchased(1000)
	for arg: String in args:
		if arg.begins_with("--progress="):
			SampleProfiles.complete_until(App.profile, App.campaign, arg.get_slice("=", 1))
	InputMap.load_from_project_settings()
	Settings.apply(App.profile)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	var screen: String = "title"
	var wait: int = 12
	for arg: String in args:
		if arg.begins_with("--screen="):
			screen = arg.get_slice("=", 1)
		elif arg.begins_with("--wait="):
			wait = int(arg.get_slice("=", 1))
	await _open(screen)
	if args.has("--scroll-end"):
		await get_tree().process_frame
		for node: Node in App.screen.find_children("*", "ScrollContainer", true, false):
			(node as ScrollContainer).scroll_vertical = 100000
	for arg: String in args:
		if arg.begins_with("--shot="):
			_screenshot(arg.get_slice("=", 1), wait)


func _open(screen: String) -> void:
	match screen:
		"title":
			pass
		"levels":
			App.show_level_select()
		"shop":
			App.show_shop()
		"shop_next":
			App.show_shop(App.show_title, "Next")
		"settings":
			App.show_settings()
		"pause", "pause_settings":
			await _play("city/2", 1.5)
			App.pause_game()
			if screen == "pause_settings":
				(App.overlay as PauseScreen).call(&"_open_settings")
		"death":
			await _play("city/2", 1.5)
			App.run.world.player.call(&"_die", "Cyborg")
			await _seconds(App.rules.death_screen_delay + 0.8)
		"results", "failed":
			var s := ResultsScreen.new()
			s.result = SampleProfiles.result(screen == "results")
			App.show_screen(s)
		"slot":
			App.play_step(App.campaign.step("city/boss"))
		"cinematic":
			App.play_step(App.campaign.step("city/intro"))
		"demo_end":
			App.show_demo_end()
		"hud":
			await _play("city/1", 2.5)
			var world: RunWorld = App.run.world
			world.score.add_bonus(&"kill", 150, "Cyborg")
			world.score.add_bonus(&"stomp", 50, "Stomp")
			world.score.multiplier = 2.0
			App.run.hud.show_hint("Cyborgs fire in bursts: watch the arm glow, then switch lanes. Stomp their heads!")
		_:
			push_warning("screens showcase: unknown screen '%s'" % screen)


## Starts a campaign level with god mode (so nothing ends it) and lets it run a while.
func _play(step_id: String, seconds: float) -> void:
	App.start_level(App.campaign.step(step_id))
	App.run.context.god_mode = true
	App.run.world.player.god_mode = true
	await _seconds(seconds)


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


## Saves what the window shows after `frames` frames, then quits.
func _screenshot(path: String, frames: int) -> void:
	for i: int in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var err: Error = image.save_png(path)
	print("saved %s (%dx%d): %s" % [path, image.get_width(), image.get_height(), error_string(err)])
	get_tree().quit()

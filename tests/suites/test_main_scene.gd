extends TestSuite
## Boots the real main scene and plays two seconds of quick play: catches errors in scripts only the
## game loads.


func run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	check(scene != null, "main scene loads")
	if scene == null:
		return
	var main: Node = scene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	check(App.screen is TitleScreen, "the game boots to the title screen")
	App.start_quick()
	await physics_frames(120)
	var level_run: LevelRun = App.run
	check(level_run != null and level_run.world.player.distance > 20.0, "quick play runs: the player moves forward")
	check(level_run != null and level_run.world.geo.lane_count == 5,
		"PC runs default to 5 lanes (%d)" % (level_run.world.geo.lane_count if level_run else -1))
	App.show_title()
	await tree.process_frame
	main.queue_free()
	App.main = null
	await tree.process_frame

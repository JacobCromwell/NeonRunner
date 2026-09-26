extends TestSuite
## Boots the real game scene for two seconds: catches errors in scripts only the game loads.


func run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	check(scene != null, "main scene loads")
	if scene == null:
		return
	var game: Node = scene.instantiate()
	tree.root.add_child(game)
	await physics_frames(120)
	var player := game.get_node_or_null("Player") as Player
	check(player != null and player.distance > 20.0, "the game runs: the player moves forward")
	check(player != null and player.geo.lane_count == 5, "PC runs default to 5 lanes (%d)" % (player.geo.lane_count if player else -1))
	game.queue_free()
	await tree.process_frame

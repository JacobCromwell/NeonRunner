class_name MiniGameDef
extends Resource
## A mini-game a level plays instead of a generated layout (LevelConfig.minigame; the owner, October 10, 2026: the
## Beach's second level, a beach volleyball match). Like a boss slot (BossDef), it names a scene whose root extends
## MiniGame (scripts/minigames/minigame.gd), which plans the level's track and plays the game on it, and the game's
## own numbers in a tuning resource of its own class and file, so the F6 tuning panel can show and save them.

@export var id: StringName = &""
@export var display_name: String = ""
## The game: a scene whose root extends MiniGame. Empty: not built (the level then plays its generated layout).
@export_file("*.tscn") var scene: String = ""
## The game's own numbers (timings, distances, scoring, payout): data/minigames/<id>_tuning.tres.
@export var tuning: Resource


func is_built() -> bool:
	return scene != "" and ResourceLoader.exists(scene)

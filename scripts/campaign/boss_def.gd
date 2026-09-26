class_name BossDef
extends Resource
## A zone's boss slot (GDD §10). Bosses are standalone mini-games with their own scene and rules
## (owner decision, September 26, 2026); their designs come later. Until a boss has a scene, the
## game shows a placeholder card in its place and lets the player continue.
##
## A boss scene's root must extend BossEncounter (scripts/campaign/boss_encounter.gd).

@export var id: StringName = &""
@export var display_name: String = "Boss"
## The boss mini-game. Empty = not built yet (placeholder).
@export_file("*.tscn") var scene: String = ""
## Power-ups the fight grants before it starts (GDD §8: every boss must be beatable with only
## what the game grants).
@export var granted_items: PackedStringArray = PackedStringArray()
## Design notes shown on the placeholder card.
@export_multiline var notes: String = ""


func is_built() -> bool:
	return scene != "" and ResourceLoader.exists(scene)

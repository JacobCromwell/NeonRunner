class_name CinematicDef
extends Resource
## A short cinematic between levels or zones, for a sense of progression (owner decision,
## September 26, 2026). Content comes later: until a cinematic has a scene, a placeholder card
## shows its title and text, and can be skipped.
##
## A cinematic scene's root must extend Cinematic (scripts/campaign/cinematic.gd).

@export var id: StringName = &""
@export var title: String = ""
## The cinematic. Empty = not built yet (placeholder card).
@export_file("*.tscn") var scene: String = ""
## Shown on the placeholder card: what this cinematic will show, once designed.
@export_multiline var placeholder_text: String = ""


func is_built() -> bool:
	return scene != "" and ResourceLoader.exists(scene)

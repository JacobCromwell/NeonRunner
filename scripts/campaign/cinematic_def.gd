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
## An empty slot the campaign skips (owner, October 14, 2026, item 395: every boss has an intro slot, filled
## when the owner adds its beats). While the slot has no scene, the campaign builds no step for it: no card, no
## screen, nothing saved, and the flow goes straight on. Setting `scene` is all it takes to bring the step in. A
## slot that is not marked shows its placeholder card until built, as the zone intros and outros do.
@export var skip_while_empty: bool = false
## Shown on the placeholder card: what this cinematic will show, once designed.
@export_multiline var placeholder_text: String = ""


## True for a slot the campaign leaves out of its steps: marked skip_while_empty and still without a scene.
func is_skipped() -> bool:
	return skip_while_empty and not is_built()


func is_built() -> bool:
	return scene != "" and ResourceLoader.exists(scene)

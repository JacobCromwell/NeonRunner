class_name SlotScreen
extends Control
## Stands in for a boss or cinematic that isn't built yet (owner decision: bosses and cinematics
## are designed later; the build leaves their slots). Shows what will go here and lets the player
## continue, which counts the step as done.

var step: CampaignStep


func _ready() -> void:
	ScreenKit.fill(self)
	var col: VBoxContainer = ScreenKit.column(self, 600.0)
	if step.kind == CampaignStep.Kind.BOSS:
		ScreenKit.title(col, "BOSS: %s" % step.boss.display_name.to_upper(), 34)
		ScreenKit.label(col, "This boss is a standalone mini-game that is still being designed.", 18)
		if step.boss.notes != "":
			ScreenKit.label(col, step.boss.notes, 14)
	else:
		ScreenKit.title(col, step.cinematic.title if step.cinematic.title != "" else "CINEMATIC", 34)
		ScreenKit.label(col, step.cinematic.placeholder_text if step.cinematic.placeholder_text != "" \
			else "A short cinematic will play here.", 18)
	var r: HBoxContainer = ScreenKit.row(col)
	ScreenKit.button(r, "Continue", func() -> void:
		App.complete_step(step)
		App.advance_from(step))
	ScreenKit.button(r, "Back", App.show_level_select)
	ScreenKit.focus_first(self)

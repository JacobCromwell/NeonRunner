class_name SlotScreen
extends ScreenBase
## Stands in for a boss or cinematic that isn't built yet (owner decision: bosses and cinematics
## are designed later; the build leaves their slots). Shows what will go here and lets the player
## continue, which counts the step as done. Back returns to the level select.

var step: CampaignStep
var continue_button: NeonButton


func _ready() -> void:
	var zone: ZoneDef = step.zone
	title = "ZONE %d · %s" % [step.zone_index + 1, zone.display_name.to_upper()] if zone != null else "CAMPAIGN"
	back_requested.connect(App.show_level_select)
	var boss: bool = step.kind == CampaignStep.Kind.BOSS
	var column: VBoxContainer = add_panel(UiTheme.DIALOG, 700.0)
	column.add_theme_constant_override(&"separation", roundi(UiTheme.px(10)))
	var s: UiStyle = UiTheme.style()
	var icon := NeonIcon.make(&"boss" if boss else &"film", UiTheme.px(64), s.danger if boss else s.accent)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(icon)
	column.add_child(ScreenBase.make_label("BOSS" if boss else LevelSelectScreen.slot_name(step), UiTheme.SUBHEADING,
		HORIZONTAL_ALIGNMENT_CENTER))
	var heading := ScreenBase.make_label(step.title().to_upper(), UiTheme.TITLE, HORIZONTAL_ALIGNMENT_CENTER)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(heading)
	column.add_child(_chip())

	# The notes say how far each boss is (the Floating Head is designed, others are still open).
	var text: String = "A boss fight will play here." if boss else "A short cinematic will play here."
	var body := ScreenBase.make_label(text, &"", HORIZONTAL_ALIGNMENT_CENTER)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(body)
	var notes: String = ""
	if boss and step.boss != null:
		notes = step.boss.notes
	elif not boss and step.cinematic != null:
		notes = step.cinematic.placeholder_text
	# The data's notes are written for the team ("DESIGN-TBD: ..."); show them as a plain sentence.
	notes = notes.trim_prefix("DESIGN-TBD:").strip_edges()
	notes = notes.left(1).to_upper() + notes.substr(1)
	if notes != "":
		column.add_child(ScreenBase.make_heading("PLANNED", &"info"))
		var note := ScreenBase.make_label(notes, UiTheme.CAPTION)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(note)

	var gap := Control.new()
	gap.custom_minimum_size.y = UiTheme.px(6)
	column.add_child(gap)
	continue_button = NeonButton.make("CONTINUE", NeonButton.Kind.PRIMARY, &"chevron_right")
	continue_button.custom_minimum_size.x = UiTheme.px(240)
	continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	continue_button.tooltip_text = "Counts this step as done"
	continue_button.pressed.connect(_continue)
	column.add_child(continue_button)
	initial_focus = continue_button


func _chip() -> Control:
	var chip := PanelContainer.new()
	chip.theme_type_variation = UiTheme.HUD_PANEL
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	chip.add_child(row)
	var icon := NeonIcon.make(&"info", UiTheme.px(18), UiTheme.style().accent_2)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var label := ScreenBase.make_label("COMING IN A LATER BUILD", UiTheme.CAPTION)
	label.add_theme_color_override(&"font_color", UiTheme.style().accent_2.lerp(Color.WHITE, 0.3))
	row.add_child(label)
	return chip


func _continue() -> void:
	App.complete_step(step)
	App.advance_from(step)

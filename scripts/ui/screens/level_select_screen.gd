class_name LevelSelectScreen
extends Control
## The campaign map: every zone with its steps (cinematics, levels, boss), locks and stars.
## Zones not designed yet show as "coming soon". Placeholder look (ScreenKit).


func _ready() -> void:
	ScreenKit.fill(self)
	var col: VBoxContainer = ScreenKit.column(self, 760.0)
	ScreenKit.title(col, "CAMPAIGN", 36)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 430.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override(&"separation", 12)
	scroll.add_child(list)
	var steps: Array[CampaignStep] = App.campaign.steps()
	for zi: int in App.campaign.zones.size():
		var zone: ZoneDef = App.campaign.zones[zi]
		ScreenKit.label(list, "Zone %d: %s" % [zi + 1, zone.display_name], 22)
		if zone.placeholder or zone.levels.is_empty():
			ScreenKit.label(list, "Coming soon.", 14)
			continue
		if zone.tagline != "":
			ScreenKit.label(list, zone.tagline, 14)
		var r: HBoxContainer = ScreenKit.row(list)
		for s: CampaignStep in steps:
			if s.zone != zone:
				continue
			var locked: bool = not App.step_unlocked(s)
			var text: String = _step_text(s)
			if not App.in_demo_scope(s):
				text += " (full game)"
			var b: Button = ScreenKit.button(r, text, func() -> void: App.play_step(s), locked)
			b.tooltip_text = s.title()
	ScreenKit.button(col, "Back", App.show_title)
	ScreenKit.focus_first(self)


func _step_text(s: CampaignStep) -> String:
	match s.kind:
		CampaignStep.Kind.LEVEL:
			var stars: int = App.profile.stars(s.id)
			return "%d  %s" % [s.number_in_zone, "*".repeat(stars) if stars > 0 else "-"]
		CampaignStep.Kind.BOSS:
			return "BOSS"
	return "Scene"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		App.show_title()

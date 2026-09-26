class_name TitleScreen
extends Control
## Main menu: continue the campaign, pick a level, endless mode, shop, settings, quit.
## Placeholder look (ScreenKit); the flow is final.


func _ready() -> void:
	ScreenKit.fill(self)
	var col: VBoxContainer = ScreenKit.column(self, 460.0)
	ScreenKit.title(col, "NEON RUNNER", 52)
	var wallet: Label = ScreenKit.label(col, "Credits: %d" % App.profile.credits(), 18)
	wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var next: CampaignStep = App.next_unfinished_step()
	var play_text: String = "Play" if next == null or next.index == 0 else "Continue: %s" % next.title()
	ScreenKit.button(col, play_text, App.continue_campaign)
	ScreenKit.button(col, "Level select", App.show_level_select)
	ScreenKit.button(col, "Endless", App.start_endless)
	ScreenKit.button(col, "Shop", func() -> void: App.show_shop())
	ScreenKit.button(col, "Settings", func() -> void: App.show_settings())
	if not OS.has_feature("web") and not App.mobile:
		ScreenKit.button(col, "Quit", App.quit)
	if BuildFlavor.is_demo():
		ScreenKit.label(col, "Demo: Zone 1 and its boss.", 14).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ScreenKit.focus_first(self)

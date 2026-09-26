class_name DemoEndScreen
extends Control
## The web demo's last screen (GDD §2): the demo is Zone 1 and its boss, then this "get the full
## game" screen with store links. DESIGN-TBD: portal-specific versions if portals restrict outbound
## links (OPEN_QUESTIONS §8). Placeholder look.

const STORE_LABELS: Dictionary = {"steam": "Steam (PC)", "app_store": "App Store", "google_play": "Google Play"}


func _ready() -> void:
	ScreenKit.fill(self)
	var col: VBoxContainer = ScreenKit.column(self, 560.0)
	ScreenKit.title(col, "THANKS FOR PLAYING", 38)
	ScreenKit.label(col, "That's the end of the demo. The full game has more zones, more enemies and a boss at the end of every zone.", 18)
	for store: String in Platform.store_names():
		ScreenKit.button(col, "Get it on %s" % STORE_LABELS.get(store, store), func() -> void: Platform.open_store(StringName(store)))
	ScreenKit.button(col, "Main menu", App.show_title)
	ScreenKit.focus_first(self)

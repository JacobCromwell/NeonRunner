class_name DemoEndScreen
extends ScreenBase
## The web demo's last screen (GDD §2): the demo is Zone 1 and its boss, then this "get the full
## game" screen with store links. DESIGN-TBD: portal-specific versions if portals restrict outbound
## links (OPEN_QUESTIONS §8).

const STORE_LABELS: Dictionary = {"steam": "Steam (PC)", "app_store": "App Store", "google_play": "Google Play"}

## Store name -> its button.
var store_buttons: Dictionary = {}
var menu_button: NeonButton


func _ready() -> void:
	show_title_bar = false
	back_requested.connect(App.show_title)
	set_hints([[&"ui_accept", "SELECT"], [&"ui_cancel", "MENU"]])
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", roundi(UiTheme.px(16)))
	column.custom_minimum_size.x = UiTheme.px(720)
	center.add_child(column)
	column.add_child(ScreenBase.make_label("END OF THE DEMO", UiTheme.SUBHEADING, HORIZONTAL_ALIGNMENT_CENTER))
	var heading := ScreenBase.make_label("THANKS FOR PLAYING", UiTheme.TITLE, HORIZONTAL_ALIGNMENT_CENTER)
	heading.add_theme_font_size_override(&"font_size", roundi(UiTheme.px(56)))
	column.add_child(heading)
	var text := ScreenBase.make_label("That's the end of the demo. The full game has more zones, more enemies and a boss at the end of every zone.",
		&"", HORIZONTAL_ALIGNMENT_CENTER)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(text)

	var stores := HFlowContainer.new()
	stores.alignment = FlowContainer.ALIGNMENT_CENTER
	stores.add_theme_constant_override(&"h_separation", roundi(UiTheme.px(14)))
	stores.add_theme_constant_override(&"v_separation", roundi(UiTheme.px(14)))
	column.add_child(stores)
	for store: String in Platform.store_names():
		var tile: TileButton = _store_tile(store)
		stores.add_child(tile)
		store_buttons[store] = tile
	menu_button = NeonButton.make("MAIN MENU", NeonButton.Kind.FLAT, &"home")
	menu_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_button.pressed.connect(App.show_title)
	column.add_child(menu_button)
	initial_focus = store_buttons.values()[0] if not store_buttons.is_empty() else menu_button


func _store_tile(store: String) -> TileButton:
	var tile := TileButton.new()
	tile.kind = NeonButton.Kind.PRIMARY if store_buttons.is_empty() else NeonButton.Kind.NORMAL
	tile.custom_minimum_size.x = UiTheme.px(220)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	tile.content.add_child(row)
	var icon := NeonIcon.make(&"store", UiTheme.px(30), Color.WHITE)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var words := VBoxContainer.new()
	words.add_theme_constant_override(&"separation", 0)
	row.add_child(words)
	words.add_child(ScreenBase.make_label("GET IT ON", UiTheme.CAPTION))
	words.add_child(ScreenBase.make_label(String(STORE_LABELS.get(store, store.capitalize())), UiTheme.CARD_TITLE))
	tile.tooltip_text = Platform.store_link(StringName(store))
	tile.pressed.connect(Platform.open_store.bind(StringName(store)))
	return tile

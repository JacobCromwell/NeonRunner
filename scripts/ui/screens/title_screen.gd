class_name TitleScreen
extends ScreenBase
## The main menu: continue the campaign (or play it from the start), level select, endless mode,
## shop, settings, and quit on desktop. The wallet sits top right; the web demo shows a note.

var continue_button: TileButton
var wallet: CreditCounter
## The menu's buttons by name (continue, levels, endless, shop, settings, quit), for tests.
var buttons: Dictionary = {}


func _ready() -> void:
	show_back = false
	set_hints([[&"ui_accept", "SELECT"]])
	# The title bar only carries the wallet here, without its strip, a little in from the corner.
	var bare := StyleBoxEmpty.new()
	bare.content_margin_left = UiTheme.px(24)
	bare.content_margin_right = UiTheme.px(24)
	bare.content_margin_top = UiTheme.px(18)
	title_bar.add_theme_stylebox_override(&"panel", bare)
	wallet = CreditCounter.new()
	wallet.set_value(App.profile.credits(), false)
	header_right.add_child(wallet)
	App.profile_changed.connect(_on_profile_changed)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(center)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", roundi(UiTheme.px(14)))
	center.add_child(column)
	column.add_child(TitleLogo.new())

	var menu := VBoxContainer.new()
	menu.custom_minimum_size.x = UiTheme.px(460)
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(menu)
	continue_button = _continue_tile()
	menu.add_child(continue_button)
	buttons["continue"] = continue_button
	var entries: Array = [["levels", "LEVEL SELECT", &"map", App.show_level_select]]
	if not BuildFlavor.is_demo():
		# DESIGN-TBD: endless mode isn't part of the web demo (GDD §2: the demo is Zone 1 and its boss).
		entries.append(["endless", "ENDLESS", &"infinity", App.start_endless])
	entries.append(["shop", "SHOP", &"store", func() -> void: App.show_shop()])
	entries.append(["settings", "SETTINGS", &"settings", func() -> void: App.show_settings()])
	# Two buttons a row; a lone last button takes the whole row.
	var row: HBoxContainer
	for i: int in entries.size():
		if i % 2 == 0:
			row = HBoxContainer.new()
			menu.add_child(row)
		var b := NeonButton.make(entries[i][1], NeonButton.Kind.NORMAL, entries[i][2])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(entries[i][3])
		row.add_child(b)
		buttons[entries[i][0]] = b
	if not OS.has_feature("web") and not App.mobile:
		var quit := NeonButton.make("QUIT", NeonButton.Kind.FLAT, &"power")
		quit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		quit.pressed.connect(App.quit)
		menu.add_child(quit)
		buttons["quit"] = quit
	if BuildFlavor.is_demo():
		column.add_child(_demo_note())
	initial_focus = continue_button


func _on_profile_changed() -> void:
	wallet.set_value(App.profile.credits())


## The big first button: PLAY at the start, CONTINUE with the next step's name afterwards.
func _continue_tile() -> TileButton:
	var tile := TileButton.new()
	tile.kind = NeonButton.Kind.PRIMARY
	tile.custom_minimum_size.y = UiTheme.px(70)
	var next: CampaignStep = App.next_unfinished_step()
	var fresh: bool = next == null or next.index == 0
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 14)
	tile.content.add_child(row)
	var icon := NeonIcon.make(&"play", UiTheme.px(26), Color.WHITE)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var words := VBoxContainer.new()
	words.add_theme_constant_override(&"separation", 0)
	row.add_child(words)
	words.add_child(ScreenBase.make_label("PLAY" if fresh else "CONTINUE", UiTheme.HEADING))
	var caption: String = "Start the campaign"
	if next == null:
		caption = "Every step cleared: pick any level"
	elif not fresh:
		caption = "Next: %s · %s" % [next.zone.display_name, next.title()]
	words.add_child(ScreenBase.make_label(caption, UiTheme.CAPTION))
	tile.pressed.connect(App.continue_campaign)
	return tile


func _demo_note() -> Control:
	var chip := PanelContainer.new()
	chip.theme_type_variation = UiTheme.HUD_PANEL
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	chip.add_child(row)
	var icon := NeonIcon.make(&"store", UiTheme.px(20), UiTheme.style().accent_2)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	row.add_child(ScreenBase.make_label("DEMO: Zone 1 and its boss. The full game has more zones.", UiTheme.CAPTION))
	return chip


## The game's name in the display face, with a neon underline that fades out at both ends.
class TitleLogo:
	extends VBoxContainer

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_theme_constant_override(&"separation", 2)
		var label := ScreenBase.make_label("NEON RUNNER", UiTheme.TITLE, HORIZONTAL_ALIGNMENT_CENTER)
		label.add_theme_font_size_override(&"font_size", roundi(UiTheme.px(84)))
		label.add_theme_constant_override(&"shadow_outline_size", roundi(UiTheme.px(18)))
		add_child(label)
		var line := Underline.new()
		line.custom_minimum_size = Vector2(UiTheme.px(560), UiTheme.px(10))
		line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		add_child(line)


class Underline:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var accent: Color = get_theme_color(&"accent", UiTheme.NEON)
		var violet: Color = get_theme_color(&"accent_2", UiTheme.NEON)
		var y: float = size.y * 0.5
		var clear := Color(accent, 0.0)
		# A soft glow band, then the bright core line; both fade at the ends.
		for layer: Array in [[size.y, 0.18], [3.0, 0.95]]:
			var h: float = layer[0]
			var mid: Color = Color(accent.lerp(violet, 0.35), layer[1])
			var top: float = y - h * 0.5
			var bottom: float = y + h * 0.5
			var cx: float = size.x * 0.5
			draw_polygon(PackedVector2Array([Vector2(0, top), Vector2(cx, top), Vector2(cx, bottom), Vector2(0, bottom)]),
				PackedColorArray([clear, mid, mid, clear]))
			draw_polygon(PackedVector2Array([Vector2(cx, top), Vector2(size.x, top), Vector2(size.x, bottom), Vector2(cx, bottom)]),
				PackedColorArray([mid, clear, clear, mid]))

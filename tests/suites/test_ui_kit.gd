extends TestSuite
## The UI kit: the theme builds with every style screens need (desktop, touch and HUD), the
## palette keeps clear of the hazard colours, every icon draws, every widget instantiates, lays
## out and frees cleanly, keyboard focus moves with ui actions, and the counters, cards, switches,
## dialogs, toasts and key binding behave.

var _root: Control


func run() -> void:
	UiTheme.touch_override = 0
	UiSounds.muted = false
	_test_theme()
	_test_hud_theme()
	_test_palette()
	_test_icons()
	_test_text_helpers()
	_root = Control.new()
	UiTheme.apply(_root)
	_root.size = Vector2(1280, 720)
	tree.root.add_child(_root)
	await _test_widgets_lifecycle()
	await _test_focus_navigation()
	await _test_screen_base()
	await _test_credit_counter()
	await _test_item_card()
	await _test_toggle_switch()
	await _test_confirm_dialog()
	await _test_toast()
	await _test_key_bind_button()
	await _test_star_row()
	_test_cooldown_icon()
	_test_sounds()
	_root.queue_free()
	await tree.process_frame
	UiTheme.touch_override = -1


# --- Helpers -------------------------------------------------------------------

func _frames(count: int) -> void:
	for i: int in count:
		await tree.process_frame


func _action(action: StringName, pressed: bool = true) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	tree.root.push_input(event)


## Press and release, as a key tap would.
func _tap(action: StringName) -> void:
	_action(action, true)
	_action(action, false)


func _focus_owner() -> Control:
	return tree.root.gui_get_focus_owner()


func _key(code: Key) -> InputEventKey:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.keycode = code
	key.pressed = true
	return key


# --- Theme ---------------------------------------------------------------------

func _test_theme() -> void:
	var s: UiStyle = UiTheme.style()
	check(s != null and s.display_font != null and s.body_font != null, "the UI style loads with both fonts")
	for touch: bool in [false, true]:
		var tag: String = "touch" if touch else "desktop"
		var theme: Theme = UiTheme.build(s, touch)
		check(theme.default_font != null and theme.default_font_size > 0, "default font (%s)" % tag)
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			check(theme.has_stylebox(state, &"Button"), "Button %s style (%s)" % [state, tag])
		for kind: StringName in [UiTheme.PRIMARY_BUTTON, UiTheme.DANGER_BUTTON, UiTheme.FLAT_BUTTON,
				UiTheme.ICON_BUTTON, UiTheme.HUD_BUTTON, UiTheme.PRICE_BUTTON]:
			check(theme.get_type_variation_base(kind) != &"" and theme.has_stylebox(&"normal", kind), "button kind %s (%s)" % [kind, tag])
		for label: StringName in [UiTheme.TITLE, UiTheme.SCREEN_TITLE, UiTheme.HEADING, UiTheme.SUBHEADING,
				UiTheme.CAPTION, UiTheme.ACCENT_CAPTION, UiTheme.DANGER_CAPTION, UiTheme.CARD_TITLE, UiTheme.ACCENT_TEXT,
				UiTheme.DANGER_TEXT, UiTheme.VALUE, UiTheme.KEY_CAP, UiTheme.HUD_TEXT, UiTheme.HUD_VALUE, UiTheme.HUD_CAPTION]:
			check(theme.is_type_variation(label, &"Label") and theme.has_font(&"font", label) and theme.has_font_size(&"font_size", label),
				"label style %s (%s)" % [label, tag])
		for panel: StringName in [UiTheme.CARD, UiTheme.DIALOG, UiTheme.BAR, UiTheme.FOOTER, UiTheme.HUD_PANEL,
				UiTheme.TOAST, UiTheme.TOAST_WARNING]:
			check(theme.is_type_variation(panel, &"PanelContainer") and theme.has_stylebox(&"panel", panel), "panel style %s (%s)" % [panel, tag])
		var needed: Array = [
			[&"panel", &"PanelContainer"], [&"panel", &"Panel"], [&"background", &"ProgressBar"], [&"fill", &"ProgressBar"],
			[&"background", UiTheme.THIN_BAR], [&"fill", UiTheme.THIN_BAR],
			[&"slider", &"HSlider"], [&"grabber_area", &"HSlider"], [&"grabber_area_highlight", &"HSlider"],
			[&"slider", &"VSlider"], [&"scroll", &"VScrollBar"], [&"grabber", &"VScrollBar"], [&"grabber_pressed", &"HScrollBar"],
			[&"normal", &"LineEdit"], [&"focus", &"LineEdit"], [&"read_only", &"LineEdit"], [&"normal", &"TextEdit"],
			[&"panel", &"TooltipPanel"], [&"panel", &"PopupMenu"], [&"hover", &"PopupMenu"], [&"panel", &"PopupPanel"],
			[&"tab_selected", &"TabContainer"], [&"tab_unselected", &"TabBar"], [&"panel", &"TabContainer"],
			[&"focus", &"CheckBox"], [&"focus", &"CheckButton"], [&"separator", &"HSeparator"],
			[&"chip", &"CreditCounter"], [&"icon_frame", &"ItemCard"], [&"focus", UiTheme.NEON]]
		for item: Array in needed:
			check(theme.has_stylebox(item[0], item[1]), "style %s/%s (%s)" % [item[1], item[0], tag])
		for icon: Array in [[&"grabber", &"HSlider"], [&"grabber_highlight", &"HSlider"], [&"grabber_disabled", &"VSlider"],
				[&"checked", &"CheckBox"], [&"unchecked", &"CheckBox"], [&"radio_checked", &"CheckBox"],
				[&"checked", &"CheckButton"], [&"unchecked_mirrored", &"CheckButton"], [&"arrow", &"OptionButton"],
				[&"submenu", &"PopupMenu"]]:
			check(theme.get_icon(icon[0], icon[1]) != null and theme.get_icon(icon[0], icon[1]).get_width() > 0,
				"icon %s/%s (%s)" % [icon[1], icon[0], tag])
		# A focus ring you can see: a bright border at least 2 px wide, drawn outside the control.
		var focus := theme.get_stylebox(&"focus", &"Button") as StyleBoxFlat
		check(focus != null and focus.border_width_top >= 2 and focus.border_color.a > 0.8 and focus.expand_margin_top > 0.0,
			"the focus ring is clearly visible (%s)" % tag)
		# Buttons are at least the control height (finger size on touch).
		var target: int = s.touch_control_height if touch else s.control_height
		check(theme.get_constant(&"control_height", UiTheme.NEON) == target, "control height constant (%s)" % tag)
		var font: Font = theme.get_font(&"font", &"Button")
		var font_size: int = theme.get_font_size(&"font_size", &"Button")
		var button_h: float = font.get_height(font_size) + theme.get_stylebox(&"normal", &"Button").get_minimum_size().y
		check(button_h >= target - 1.0, "a text button is %.0f px tall, target %d (%s)" % [button_h, target, tag])
		var icon_h: float = theme.get_constant(&"icon_size", UiTheme.NEON) + theme.get_stylebox(&"normal", UiTheme.ICON_BUTTON).get_minimum_size().y
		check(icon_h >= target - 1.0, "an icon button is %.0f px tall, target %d (%s)" % [icon_h, target, tag])
	check(UiTheme.build(s, true).default_font_size > UiTheme.build(s, false).default_font_size, "touch text is larger")
	check(UiTheme.get_theme() == UiTheme.get_theme(), "the shared theme is built once")


func _test_hud_theme() -> void:
	var menu: Theme = UiTheme.build(UiTheme.style(), false, false)
	var hud: Theme = UiTheme.build(UiTheme.style(), false, true)
	check(hud.get_constant(&"outline_size", &"Label") > 0 and menu.get_constant(&"outline_size", &"Label") == 0,
		"HUD text is outlined; menu text isn't")
	var hud_panel := hud.get_stylebox(&"panel", &"PanelContainer") as StyleBoxFlat
	var menu_panel := menu.get_stylebox(&"panel", &"PanelContainer") as StyleBoxFlat
	check(hud_panel != null and menu_panel != null and hud_panel.bg_color.a < menu_panel.bg_color.a,
		"HUD panels are lighter than menu panels")
	check(hud.get_stylebox(&"normal", &"Button") == hud.get_stylebox(&"normal", UiTheme.HUD_BUTTON), "HUD buttons are the HUD kind")


## UI accents must not look like hazards (GDD §5): compare the shipped style's hues
## (data/ui/ui_style.tres, what UiTheme uses) with the game's own hazard colours.
func _test_palette() -> void:
	var s: UiStyle = UiTheme.style()
	check(s.resource_path == UiTheme.STYLE_PATH, "the palette test checks the shipped style (%s)" % s.resource_path)
	var skin := GreyboxSkin.new()
	var reserved: Dictionary = {"fence pink": skin.fence_color, "gap orange": skin.gap_edge_color, "sign yellow": skin.sign_color}
	var gameplay: Dictionary = {"pad cyan": skin.pad_color, "ramp green": skin.ramp_color}
	for accent: Array in [["accent", s.accent], ["accent_2", s.accent_2], ["star", s.star]]:
		var color: Color = accent[1]
		for hazard: String in reserved:
			# Near-white (the star) has no real hue; saturation decides.
			var far: bool = color.s < 0.2 or _hue_distance(color, reserved[hazard]) >= 0.08
			check(far, "%s stays clear of the %s" % [accent[0], hazard])
		for piece: String in gameplay:
			check(color.s < 0.2 or _hue_distance(color, gameplay[piece]) >= 0.05, "%s is distinct from the %s" % [accent[0], piece])
	check(_hue_distance(s.danger, skin.fence_color) >= 0.05, "warning red is distinct from the fence pink")
	for i: int in s.credit_colors.size():
		var c: Color = s.credit_colors[i]
		for hazard: String in reserved:
			check(c.s < 0.2 or _hue_distance(c, reserved[hazard]) >= 0.08, "credit colour %d stays clear of the %s" % [i, hazard])


func _hue_distance(a: Color, b: Color) -> float:
	var d: float = absf(a.h - b.h)
	return minf(d, 1.0 - d)


func _test_icons() -> void:
	for required: String in ["credit_1", "credit_5", "credit_25", "credit_100", "armor", "shield", "grapple", "revive",
			"weapon_1", "weapon_2", "weapon_3", "weapon_4", "claws", "dash", "magnet", "slow_time", "star", "lock",
			"pause", "play", "settings", "back", "trophy", "leaderboard", "store"]:
		check(IconFactory.has_icon(StringName(required)), "icon '%s' exists" % required)
	for icon_name: StringName in IconFactory.NAMES:
		var pen := IconFactory.Pen.new()
		IconFactory.trace(pen, icon_name)
		check(pen.shapes > 0, "icon '%s' has shapes" % icon_name)
		var image := Image.new()
		var err: Error = image.load_svg_from_string(IconFactory.svg(icon_name, 48.0))
		var coverage: float = _coverage(image) if err == OK else 0.0
		check(err == OK and coverage > 0.03 and coverage < 0.8, "icon '%s' renders (%.0f%% ink)" % [icon_name, coverage * 100.0])
	var texture: Texture2D = IconFactory.texture(&"star", 24.0)
	check(texture is DPITexture and texture.get_width() == 24, "icon textures are crisp DPITextures")
	check(IconFactory.texture(&"star", 24.0) == texture, "icon textures are cached")
	check(IconFactory.credit_icon(1) == &"credit_1" and IconFactory.credit_icon(24) == &"credit_5"
		and IconFactory.credit_icon(25) == &"credit_25" and IconFactory.credit_icon(5000) == &"credit_100",
		"credit amounts map to denomination icons")
	check(IconFactory.weapon_icon(0) == &"weapon_1" and IconFactory.weapon_icon(4) == &"weapon_4", "weapon tiers map to icons")


func _coverage(image: Image) -> float:
	var ink: int = 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a > 0.5:
				ink += 1
	return float(ink) / (image.get_width() * image.get_height())


func _test_text_helpers() -> void:
	check(UiTheme.format_int(0) == "0" and UiTheme.format_int(999) == "999" and UiTheme.format_int(1000) == "1,000"
		and UiTheme.format_int(12450) == "12,450" and UiTheme.format_int(-1234567) == "-1,234,567", "thousands separators")
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	check(UiTheme.event_text(space) == "Space", "key names (%s)" % UiTheme.event_text(space))
	var combo := InputEventKey.new()
	combo.keycode = KEY_E
	combo.ctrl_pressed = true
	combo.shift_pressed = true
	check(UiTheme.event_text(combo) == "Ctrl+Shift+E", "modifier order (%s)" % UiTheme.event_text(combo))
	check(UiTheme.action_text(&"ui_cancel") == "Esc", "hint for ui_cancel (%s)" % UiTheme.action_text(&"ui_cancel"))
	check(UiTheme.action_text(&"jump") != "" and UiTheme.action_text(&"no_such_action") == "", "hints for game actions")
	var font: Font = UiTheme.style().body_font
	check(is_equal_approx(UiTheme.tabular_width(font, "1111", 20), UiTheme.tabular_width(font, "8888", 20)),
		"tabular digits all take the same width")
	check(UiTheme.credit_color(100) == UiTheme.style().credit_colors[3], "credit colours by denomination")
	var theme: Theme = UiTheme.get_theme()
	for amount: int in [1, 3, 5, 24, 25, 99, 100, 5000]:
		check(UiTheme.credit_color(amount) == theme.get_color(IconFactory.credit_icon(amount), UiTheme.NEON),
			"credit colour for %d matches the theme's" % amount)


# --- Widgets ---------------------------------------------------------------------

func _test_widgets_lifecycle() -> void:
	await _frames(1)
	var orphans_before: float = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var makers: Dictionary = {
		"NeonButton": func() -> Control: return NeonButton.make("PLAY", NeonButton.Kind.PRIMARY, &"play"),
		"NeonIcon": func() -> Control: return NeonIcon.make(&"shield", 32),
		"ToggleSwitch": func() -> Control: return ToggleSwitch.new(),
		"CreditCounter": func() -> Control:
			var c := CreditCounter.new()
			c.set_value(12450)
			return c,
		"StarRow": func() -> Control:
			var r := StarRow.new()
			r.reveal(3)
			return r,
		"ProgressMeter": func() -> Control:
			var m := ProgressMeter.new()
			m.markers = PackedFloat32Array([0.3, 0.6])
			m.value = 0.5
			return m,
		"CooldownIcon": func() -> Control:
			var c := CooldownIcon.new()
			c.count = 2
			c.key_hint = "E"
			c.start_cooldown(1.0)
			return c,
		"ItemCard": func() -> Control:
			var card := ItemCard.new()
			card.configure({"title": "Shield", "icon_name": &"shield", "price": 400, "credits": 1000,
				"description": "Blocks one hit of anything."})
			return card,
		"KeyBindButton": func() -> Control: return KeyBindButton.for_action(&"jump"),
		"ConfirmDialog": func() -> Control:
			var d := ConfirmDialog.new()
			d.title = "SURE?"
			return d,
		"ScreenBase": func() -> Control: return ScreenBase.new(),
	}
	for widget_name: String in makers:
		var widget: Control = makers[widget_name].call()
		_root.add_child(widget)
		if widget is ConfirmDialog:
			(widget as ConfirmDialog).open()
		await _frames(3)
		var min_size: Vector2 = widget.get_combined_minimum_size()
		if widget is ConfirmDialog or widget is ScreenBase:
			check(widget.size.x >= 1279.0 and widget.size.y >= 719.0, "%s fills its parent" % widget_name)
		else:
			check(min_size.x > 0.0 and min_size.y > 0.0, "%s has a minimum size (%s)" % [widget_name, min_size])
			widget.size = Vector2.ZERO
			check(widget.size.x >= min_size.x - 0.5 and widget.size.y >= min_size.y - 0.5, "%s lays out at its minimum size" % widget_name)
		check(widget.has_theme_constant(&"control_height", UiTheme.NEON), "%s uses the UI theme" % widget_name)
		widget.queue_free()
		await _frames(1)
		check(not is_instance_valid(widget), "%s frees" % widget_name)
	await _frames(12)
	var orphans_after: float = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	check(orphans_after <= orphans_before, "widgets leave no orphan nodes (%d → %d)" % [orphans_before, orphans_after])

	# A widget under a CanvasLayer (which doesn't pass themes down) themes itself.
	var layer := CanvasLayer.new()
	tree.root.add_child(layer)
	var lone := CreditCounter.new()
	layer.add_child(lone)
	await _frames(2)
	check(lone.theme != null and lone.has_theme_constant(&"control_height", UiTheme.NEON), "a widget with no themed parent themes itself")
	var lone_card := ItemCard.new()
	lone_card.configure({"title": "Shield", "price": 400})
	layer.add_child(lone_card)
	var themed_card := ItemCard.new()
	themed_card.configure({"title": "Shield", "price": 400})
	_root.add_child(themed_card)
	await _frames(3)
	check(absf(lone_card.get_combined_minimum_size().y - themed_card.get_combined_minimum_size().y) < 1.0
		and absf(lone_card.description_label.custom_minimum_size.y - themed_card.description_label.custom_minimum_size.y) < 0.5,
		"a card that themes itself measures its text like a themed one (%s vs %s)"
		% [lone_card.get_combined_minimum_size(), themed_card.get_combined_minimum_size()])
	themed_card.queue_free()
	# One under a HUD root keeps the HUD theme.
	var hud := Control.new()
	UiTheme.apply(hud, true)
	layer.add_child(hud)
	var hud_counter := CreditCounter.new()
	hud.add_child(hud_counter)
	await _frames(2)
	check(hud_counter.theme == null and hud_counter.get_theme_constant(&"outline_size", &"CreditCounter") > 0,
		"a widget under a HUD root takes the HUD look")
	layer.queue_free()
	await _frames(1)


func _test_focus_navigation() -> void:
	var column := VBoxContainer.new()
	_root.add_child(column)
	var buttons: Array[NeonButton] = []
	for i: int in 3:
		var b := NeonButton.make("B%d" % i)
		column.add_child(b)
		buttons.append(b)
	await _frames(2)
	var heard: Array[StringName] = []
	UiSounds.hook = func(sound: StringName) -> void: heard.append(sound)
	UiSounds._last_played.clear()
	UiSounds._quiet_until_ms = 0
	buttons[0].grab_focus()
	_action(&"ui_down")
	await _frames(1)
	check(_focus_owner() == buttons[1], "ui_down moves focus to the next button")
	_action(&"ui_down")
	await _frames(1)
	check(_focus_owner() == buttons[2], "and on to the third")
	_action(&"ui_up")
	await _frames(1)
	check(_focus_owner() == buttons[1], "ui_up moves back")
	var presses: Array[int] = [0]
	buttons[1].pressed.connect(func() -> void: presses[0] += 1)
	_tap(&"ui_accept")
	await _frames(1)
	check(presses[0] == 1, "ui_accept presses the focused button")
	check(heard.has(UiSounds.MOVE) and heard.has(UiSounds.SELECT), "focus plays ui_move and pressing plays ui_select (%s)" % [heard])
	heard.clear()
	UiSounds._last_played.clear()
	buttons[2].sound_select = &"ui_custom"
	buttons[2].pressed.emit()
	check(heard == [&"ui_custom"], "a button's own sound names are used (%s)" % [heard])
	UiSounds.hook = Callable()
	# A disabled button is skipped by ScreenBase's first-focus search.
	buttons[0].disabled = true
	check(ScreenBase.first_focusable(column) == buttons[1], "first focusable skips disabled buttons")
	column.queue_free()
	await _frames(1)


func _test_screen_base() -> void:
	var screen := ScreenBase.new()
	screen.title = "TEST"
	var first := NeonButton.make("FIRST")
	var chosen := NeonButton.make("CHOSEN")
	screen.content.add_child(first)
	screen.content.add_child(chosen)
	screen.initial_focus = chosen
	_root.add_child(screen)
	await _frames(3)
	check(screen.title_label.text == "TEST", "the title shows")
	check(_focus_owner() == chosen, "the screen gives initial_focus the focus")
	check(screen.footer.visible and screen.back_button.visible, "desktop screens show the back button and key hints")
	var backs: Array[int] = [0]
	screen.back_requested.connect(func() -> void: backs[0] += 1)
	_action(&"ui_cancel")
	await _frames(1)
	check(backs[0] == 1, "ui_cancel means back")
	screen.back_button.pressed.emit()
	check(backs[0] == 2, "so does the back button")
	screen.show_back = false
	_action(&"ui_cancel")
	await _frames(1)
	check(backs[0] == 2 and not screen.back_button.visible, "no back when the screen has none")
	# A dialog opened on the screen keeps the focus when the screen re-applies its first focus.
	var dialog := ConfirmDialog.ask(screen, "SURE?", "")
	await _frames(1)
	screen.focus_initial()
	await _frames(1)
	check(_focus_owner() == dialog.confirm_button, "the screen doesn't take focus from its open dialog")
	dialog.close(false)
	screen.queue_free()
	# Without initial_focus, the first focusable control in the content gets it.
	var plain := ScreenBase.new()
	var only := NeonButton.make("ONLY")
	plain.content.add_child(only)
	_root.add_child(plain)
	await _frames(3)
	check(_focus_owner() == only, "the first control gets focus by default")
	plain.queue_free()
	await _frames(1)


func _test_credit_counter() -> void:
	var counter := CreditCounter.new()
	_root.add_child(counter)
	await _frames(1)
	counter.set_value(0, false)
	check(counter.displayed_value() == 0 and not counter.is_counting(), "set_value(v, false) jumps")
	var finished: Array[int] = [0]
	counter.count_finished.connect(func() -> void: finished[0] += 1)
	counter.set_value(1234)
	check(counter.is_counting() and counter.displayed_value() < 1234, "set_value counts")
	await _frames(3)
	var midway: int = counter.displayed_value()
	check(midway > 0 and midway < 1234, "the count is under way (%d)" % midway)
	await _frames(70)
	check(counter.displayed_value() == 1234 and not counter.is_counting() and finished[0] == 1,
		"the counter reaches its target (%d)" % counter.displayed_value())
	counter.add(66)
	await _frames(40)
	check(counter.displayed_value() == 1300 and counter.value == 1300, "add() counts on from the target")
	counter.set_value(40)
	await _frames(70)
	check(counter.displayed_value() == 40, "it counts down too")
	counter.set_value(500, false)
	var positive_w: float = counter.get_combined_minimum_size().x
	counter.set_value(-500, false)
	check(counter.get_combined_minimum_size().x > positive_w, "a negative count has room for its minus sign")
	counter.set_value(99999)
	counter.finish()
	check(counter.displayed_value() == 99999 and not counter.is_counting(), "finish() jumps to the target")
	counter.queue_free()
	await _frames(1)


func _test_item_card() -> void:
	var card := ItemCard.new()
	_root.add_child(card)
	card.configure({"item_id": &"shield", "icon_name": &"shield", "title": "Shield", "price": 400, "credits": 100,
		"description": "Blocks one hit of anything."})
	await _frames(2)
	var heights: Array[float] = [card.get_combined_minimum_size().y]
	check(card.state == ItemCard.State.CANT_AFFORD and card.buy_button.visible and card.buy_button.disabled,
		"price above the wallet: can't afford, buy disabled")
	check(card.buy_button.text == "400" and card.status_label.visible, "the price and the reason show")
	card.configure({"credits": 500})
	check(card.state == ItemCard.State.AVAILABLE and not card.buy_button.disabled and not card.equip_switch.visible,
		"affordable: buy enabled, no equip toggle yet")
	var bought: Array[StringName] = []
	card.buy_pressed.connect(func(id: StringName) -> void: bought.append(id))
	card.buy_button.grab_focus()
	_tap(&"ui_accept")
	await _frames(1)
	check(bought == [&"shield"], "buy emits buy_pressed with the item id")
	card.configure({"tier": 1})
	await _frames(1)
	heights.append(card.get_combined_minimum_size().y)
	check(card.state == ItemCard.State.OWNED and not card.buy_button.visible and card.equip_switch.visible
		and card.status_label.text == "OWNED", "owned: no buy button, equip toggle shown")
	var toggles: Array = []
	card.equip_toggled.connect(func(id: StringName, on: bool) -> void: toggles.append([id, on]))
	card.equip_switch.button_pressed = false
	check(toggles == [[&"shield", false]] and not card.equipped, "the equip toggle emits equip_toggled")
	card.configure({"max_tier": 4, "tier": 2, "price": 1200, "credits": 5000})
	await _frames(1)
	heights.append(card.get_combined_minimum_size().y)
	check(card.state == ItemCard.State.AVAILABLE and card.buy_button.visible and card.equip_switch.visible
		and card.pips.visible and card.pips.owned == 2 and card.status_label.text == "UPGRADE",
		"a partly upgraded item offers the next tier and keeps its toggle")
	card.configure({"tier": 4})
	check(card.state == ItemCard.State.MAXED and not card.buy_button.visible, "all tiers bought: maxed")
	card.configure({"locked": true, "locked_reason": "ZONE 2"})
	await _frames(1)
	heights.append(card.get_combined_minimum_size().y)
	check(card.state == ItemCard.State.LOCKED and card.lock_icon.visible and not card.buy_button.visible
		and not card.equip_switch.visible and card.status_label.text == "ZONE 2", "locked: lock shown, nothing to buy or toggle")
	check(heights.max() - heights.min() < 1.0, "the card keeps its height in every state (%s)" % [heights])
	check(card.size.x >= card.get_theme_constant(&"width", &"ItemCard") - 0.5, "cards have the theme's width")
	card.queue_free()
	await _frames(1)


func _test_toggle_switch() -> void:
	var sw := ToggleSwitch.new()
	_root.add_child(sw)
	await _frames(1)
	check(sw.get_combined_minimum_size().y >= sw.get_theme_constant(&"control_height", UiTheme.NEON), "a switch is a full-height touch target")
	var seen: Array[bool] = []
	sw.toggled.connect(func(on: bool) -> void: seen.append(on))
	sw.grab_focus()
	_tap(&"ui_accept")
	await _frames(1)
	check(sw.is_on() and seen == [true], "ui_accept flips the switch and emits toggled")
	await _frames(15)
	check(not sw.is_processing(), "the knob animation settles")
	sw.set_on(false, false)
	check(not sw.is_on() and seen == [true], "set_on() without notify is silent")
	sw.queue_free()
	await _frames(1)


func _test_confirm_dialog() -> void:
	var d := ConfirmDialog.ask(_root, "QUIT RUN?", "Sure?", "QUIT", "STAY", true)
	await _frames(2)
	check(d.is_open() and _focus_owner() == d.cancel_button, "a dangerous question focuses the safe answer first")
	_action(&"ui_right")
	await _frames(1)
	check(_focus_owner() == d.confirm_button, "ui_right moves to the other answer")
	_action(&"ui_down")
	await _frames(1)
	check(_focus_owner() == d.confirm_button, "focus can't leave the dialog")
	var outside := NeonButton.make("OUTSIDE")
	_root.add_child(outside)
	outside.grab_focus()
	await _frames(2)
	check(_focus_owner() != null and d.is_ancestor_of(_focus_owner()), "the dialog takes the focus back while it's open")
	outside.queue_free()
	var answers: Array[bool] = []
	d.closed.connect(func(accepted: bool) -> void: answers.append(accepted))
	_action(&"ui_cancel")
	await _frames(1)
	check(answers == [false], "ui_cancel answers no")
	await _frames(20)
	check(not is_instance_valid(d), "the dialog frees itself after closing")

	var opener := NeonButton.make("OPENER")
	_root.add_child(opener)
	await _frames(1)
	opener.grab_focus()
	var again := ConfirmDialog.ask(_root, "SURE?", "", "YES", "NO")
	await _frames(1)
	check(again.is_ancestor_of(_focus_owner()), "the dialog takes the focus")
	_action(&"ui_cancel")
	await _frames(1)
	check(_focus_owner() == opener, "closing gives the focus back to the control that had it")
	opener.queue_free()
	await _frames(20)

	var yes := ConfirmDialog.ask(_root, "BUY?", "", "BUY", "CANCEL")
	await _frames(2)
	check(_focus_owner() == yes.confirm_button, "a normal question focuses confirm first")
	var confirmed: Array[int] = [0]
	yes.confirmed.connect(func() -> void: confirmed[0] += 1)
	_tap(&"ui_accept")
	await _frames(1)
	check(confirmed[0] == 1, "confirm emits confirmed")
	await _frames(20)
	check(not is_instance_valid(yes), "and frees")


func _test_toast() -> void:
	var toast := Toast.show_message(_root, "Hello", &"info", Toast.Kind.INFO, 0.3)
	await _frames(2)
	check(toast.get_parent().name == Toast.STACK_NAME and toast.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"toasts stack and ignore the mouse")
	var second := Toast.show_message(_root, "Careful", &"warning", Toast.Kind.WARNING, 0.3)
	check(second.get_parent() == toast.get_parent(), "toasts share one stack")
	check(second.theme_type_variation == UiTheme.TOAST_WARNING, "warnings use the warning style")
	await _frames(roundi((Toast.FADE_IN + 0.3 + Toast.FADE_OUT) * 60.0) + 4)
	check(not is_instance_valid(toast) and not is_instance_valid(second), "toasts free themselves")


func _test_key_bind_button() -> void:
	var button := KeyBindButton.for_action(&"jump")
	_root.add_child(button)
	await _frames(1)
	var original: InputEvent = button.current_event()
	check(original != null and button.text == UiTheme.event_text(original).to_upper(), "shows the action's key (%s)" % button.text)
	var requests: Array = []
	button.rebind_requested.connect(func(action: StringName, event: InputEvent) -> void: requests.append([action, event]))
	button.grab_focus()
	_tap(&"ui_accept")
	await _frames(1)
	check(button.listening and button.text == KeyBindButton.WAITING_TEXT, "pressing it waits for a key")
	tree.root.push_input(_key(KEY_W))
	await _frames(1)
	check(requests.size() == 1 and requests[0][0] == &"jump" and (requests[0][1] as InputEventKey).physical_keycode == KEY_W,
		"the next key is emitted as rebind_requested")
	check(not button.listening, "and it stops listening")
	check(button.current_event() != null and (button.current_event() as InputEventKey).physical_keycode == (original as InputEventKey).physical_keycode,
		"the InputMap itself is untouched (settings apply it)")
	button.start_listening()
	tree.root.push_input(_key(KEY_ESCAPE))
	await _frames(1)
	check(not button.listening and requests.size() == 1, "Esc cancels")
	button.start_listening()
	tree.root.push_input(_key(KEY_SHIFT))
	await _frames(1)
	check(requests.size() == 2 and (requests[1][1] as InputEventKey).physical_keycode == KEY_SHIFT,
		"a modifier alone is a binding (dash defaults to Shift)")
	button.queue_free()
	await _frames(1)


func _test_star_row() -> void:
	var row := StarRow.new()
	_root.add_child(row)
	var revealed: Array[int] = []
	var done: Array[int] = [0]
	row.star_revealed.connect(func(i: int) -> void: revealed.append(i))
	row.reveal_finished.connect(func() -> void: done[0] += 1)
	row.reveal(2)
	check(row.is_revealing(), "reveal() animates")
	await _frames(roundi((row.reveal_interval * 2.0 + StarRow.POP_TIME) * 60.0) + 4)
	check(revealed == [0, 1] and done[0] == 1 and not row.is_revealing() and row.stars == 2, "stars pop in one by one")
	row.stars = 3
	check(row.stars == 3 and not row.is_revealing(), "setting stars shows them at once")
	row.stars = 9
	check(row.stars == 3, "no more stars than slots")
	row.queue_free()
	await _frames(1)


func _test_cooldown_icon() -> void:
	var icon := CooldownIcon.new()
	var readies: Array[int] = [0]
	icon.became_ready.connect(func() -> void: readies[0] += 1)
	icon.set_cooldown(2.0, 4.0)
	check(not icon.is_ready() and is_equal_approx(icon.charge(), 0.5), "an external cooldown shows its charge")
	icon.set_cooldown(0.0, 4.0)
	check(icon.is_ready() and readies[0] == 1, "reaching zero flashes ready")
	icon.start_cooldown(0.5)
	icon._process(0.6)
	check(icon.is_ready() and readies[0] == 2, "a self-timed cooldown ends on its own")
	icon.free()


func _test_sounds() -> void:
	check(not UiSounds.has_sound(&"no_such_ui_sound"), "a missing sound is reported as missing")
	UiSounds.play(&"no_such_ui_sound")
	var heard: Array[StringName] = []
	UiSounds.hook = func(sound: StringName) -> void: heard.append(sound)
	UiSounds._last_played.clear()
	UiSounds._quiet_until_ms = 0
	UiSounds.play(UiSounds.SELECT)
	UiSounds.play(UiSounds.SELECT)
	check(heard == [UiSounds.SELECT], "the hook gets sounds, and an instant repeat is dropped")
	UiSounds.quiet(10.0)
	UiSounds.play(UiSounds.MOVE)
	check(heard.size() == 1, "quiet() silences UI sounds")
	UiSounds._quiet_until_ms = 0
	UiSounds.hook = Callable()

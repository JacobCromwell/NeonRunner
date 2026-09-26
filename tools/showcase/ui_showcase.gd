extends ScreenBase
## Every UI kit widget and icon on one screen, for reviewing the look (not part of the game).
##   godot --path . res://tools/showcase/ui_showcase.tscn [-- --touch] [-- --dialog]
## Render it headless with the Compatibility renderer (see CLAUDE.md, "Rendered frames").
## --touch uses the phone/tablet sizing; --dialog opens the confirm dialog on top.

var _credits: CreditCounter


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--touch"):
		UiTheme.touch_override = 1
		theme = UiTheme.get_theme()
	title = "UI KIT"
	back_requested.connect(func() -> void: get_tree().quit())
	set_hints([[&"ui_accept", "SELECT"], [&"ui_focus_next", "NEXT"], [&"ui_cancel", "QUIT"]])

	_credits = CreditCounter.new()
	_credits.set_value(12450)
	header_right.add_child(_credits)
	var settings := NeonButton.make("", NeonButton.Kind.ICON, &"settings")
	settings.tooltip_text = "Settings"
	header_right.add_child(settings)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	scroll.add_child(rows)

	if args.has("--page=controls"):
		title = "UI KIT: CONTROLS"
		_standard_controls_page(rows)
	else:
		initial_focus = _buttons_row(rows)
		_shop_row(rows)
		_controls_row(rows)
		_hud_row(rows)
		_icons_row(rows)

	# Toasts normally sit top centre; here they go bottom left, where the footer is empty.
	var toasts := Toast.stack_for(self)
	toasts.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	toasts.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toasts.grow_horizontal = Control.GROW_DIRECTION_END
	toasts.offset_left = 24
	toasts.offset_bottom = -6
	Toast.show_message(self, "Shield equipped", &"shield")
	if args.has("--dialog"):
		_ask_quit.call_deferred()
	for arg: String in args:
		if arg.begins_with("--shot="):
			_screenshot(arg.get_slice("=", 1))


## Saves what the window shows after a few frames, then quits. --write-movie always writes the
## project's 1280×720, so this is the way to check other window sizes and aspect ratios.
func _screenshot(path: String) -> void:
	for i: int in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var err: Error = image.save_png(path)
	print("saved %s (%dx%d): %s" % [path, image.get_width(), image.get_height(), error_string(err)])
	get_tree().quit()


func _row(parent: Control) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	parent.add_child(row)
	return row


func _buttons_row(parent: Control) -> Control:
	var row := _row(parent)
	row.add_child(NeonButton.make("NORMAL"))
	var hover := NeonButton.make("HOVER")
	hover.add_theme_stylebox_override(&"normal", get_theme_stylebox(&"hover", &"Button"))
	hover.add_theme_color_override(&"font_color", get_theme_color(&"font_hover_color", &"Button"))
	row.add_child(hover)
	var pressed := NeonButton.make("PRESSED")
	pressed.toggle_mode = true
	pressed.button_pressed = true
	row.add_child(pressed)
	var focused := NeonButton.make("FOCUS")
	row.add_child(focused)
	var disabled := NeonButton.make("DISABLED")
	disabled.disabled = true
	row.add_child(disabled)
	var play := NeonButton.make("PLAY", NeonButton.Kind.PRIMARY, &"play")
	play.pressed.connect(func() -> void: Toast.show_message(self, "Starting run...", &"play"))
	row.add_child(play)
	var quit := NeonButton.make("QUIT", NeonButton.Kind.DANGER)
	quit.pressed.connect(_ask_quit)
	row.add_child(quit)
	row.add_child(NeonButton.make("CREDITS", NeonButton.Kind.FLAT, &"store"))
	return focused


func _shop_row(parent: Control) -> void:
	var row := _row(parent)
	var cards: Array[Dictionary] = [
		{"item_id": &"weapon", "icon_name": &"weapon_2", "title": "Enhanced laser", "tier": 2, "max_tier": 4,
			"description": "Fires at the nearest target. Tier 3 swaps the laser for missiles.", "price": 1200},
		{"item_id": &"shield", "icon_name": &"shield", "title": "Shield",
			"description": "Blocks one hit of anything, then breaks.", "price": 99000},
		{"item_id": &"magnet", "icon_name": &"magnet", "title": "Magnet", "tier": 1, "equipped": false,
			"description": "Pulls in nearby credits in your lane and the lanes beside it."},
		{"item_id": &"claws", "icon_name": &"claws", "title": "Claws", "locked": true,
			"locked_reason": "UNLOCKS IN ZONE 2", "description": "Longer wall runs. Kill enemies on contact."},
	]
	for data: Dictionary in cards:
		var card := ItemCard.new()
		data["credits"] = 12450
		card.configure(data)
		card.buy_pressed.connect(func(id: StringName) -> void:
			Toast.show_message(self, "Bought %s" % id, IconFactory.credit_icon(1)))
		card.equip_toggled.connect(func(id: StringName, on: bool) -> void:
			Toast.show_message(self, "%s %s" % [id, "on" if on else "off"], &"check"))
		row.add_child(card)


func _controls_row(parent: Control) -> void:
	var row := _row(parent)
	var music := HBoxContainer.new()
	var sw := ToggleSwitch.new()
	sw.set_on(true, false)
	music.add_child(sw)
	var music_label := Label.new()
	music_label.text = "Music"
	music_label.size_flags_vertical = Control.SIZE_FILL
	music_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	music.add_child(music_label)
	row.add_child(music)
	var shake := CheckBox.new()
	shake.text = "Screen shake"
	shake.button_pressed = true
	row.add_child(shake)
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(180, get_theme_constant(&"control_height", UiTheme.NEON))
	slider.value = 70
	row.add_child(slider)
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "Runner name"
	name_edit.custom_minimum_size.x = 190
	row.add_child(name_edit)
	var jump := KeyBindButton.for_action(&"jump")
	jump.rebind_requested.connect(func(action: StringName, event: InputEvent) -> void:
		Toast.show_message(self, "%s → %s" % [action, UiTheme.event_text(event)], &"check"))
	row.add_child(jump)
	var waiting := KeyBindButton.for_action(&"slide")
	row.add_child(waiting)
	waiting.start_listening.call_deferred()
	# The level-complete reveal: the first star pops in the first frames of a render.
	var stars := StarRow.new()
	stars.star_size = 34
	stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stars.reveal(3)
	row.add_child(stars)


func _hud_row(parent: Control) -> void:
	var game := FakeGame.new()
	game.custom_minimum_size.y = 96
	UiTheme.apply(game, true)
	parent.add_child(game)
	var hud := HBoxContainer.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.offset_left = 16
	hud.offset_right = -16
	game.add_child(hud)
	var score := VBoxContainer.new()
	score.alignment = BoxContainer.ALIGNMENT_CENTER
	score.add_theme_constant_override(&"separation", -4)
	var score_value := Label.new()
	score_value.theme_type_variation = UiTheme.VALUE
	score_value.text = UiTheme.format_int(48210)
	score.add_child(score_value)
	var score_caption := Label.new()
	score_caption.theme_type_variation = UiTheme.CAPTION
	score_caption.text = "SCORE"
	score.add_child(score_caption)
	hud.add_child(score)
	var credits := CreditCounter.new()
	credits.set_value(1280, false)
	credits.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hud.add_child(credits)
	credits.add.call_deferred(35)
	var meter := ProgressMeter.new()
	meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meter.markers = PackedFloat32Array([0.2, 0.45, 0.72])
	meter.value = 0.52
	hud.add_child(meter)
	var dash := CooldownIcon.new()
	dash.icon_name = &"dash"
	dash.set_cooldown(3.0, 5.0)
	hud.add_child(dash)
	var slow := CooldownIcon.new()
	slow.icon_name = &"slow_time"
	slow.key_hint = "E"
	hud.add_child(slow)
	slow.flash_ready.call_deferred()
	var armor := CooldownIcon.new()
	armor.icon_name = &"armor"
	armor.count = 2
	hud.add_child(armor)
	var shield := CooldownIcon.new()
	shield.icon_name = &"shield"
	shield.count = 0
	hud.add_child(shield)
	for c: CooldownIcon in [dash, slow, armor, shield]:
		c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pause := NeonButton.make("", NeonButton.Kind.HUD, &"pause")
	pause.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hud.add_child(pause)


func _icons_row(parent: Control) -> void:
	var row := _row(parent)
	var grid := GridContainer.new()
	grid.columns = ceili(IconFactory.NAMES.size() / 2.0)
	grid.add_theme_constant_override(&"h_separation", 12)
	grid.add_theme_constant_override(&"v_separation", 8)
	row.add_child(grid)
	var items: Array[StringName] = [&"armor", &"shield", &"grapple", &"revive", &"weapon_1", &"weapon_2",
		&"weapon_3", &"weapon_4", &"claws", &"dash", &"magnet", &"slow_time"]
	for icon_name: StringName in IconFactory.NAMES:
		var icon := NeonIcon.make(icon_name, 28)
		icon.tooltip_text = icon_name
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		if String(icon_name).begins_with("credit_"):
			icon.color = UiTheme.credit_color(String(icon_name).get_slice("_", 1).to_int())
		elif items.has(icon_name):
			icon.color = get_theme_color(&"accent", UiTheme.NEON)
		elif icon_name == &"star":
			icon.color = get_theme_color(&"star", UiTheme.NEON)
		elif icon_name == &"warning":
			icon.color = get_theme_color(&"danger", UiTheme.NEON)
		grid.add_child(icon)
	var ladder := HBoxContainer.new()
	ladder.alignment = BoxContainer.ALIGNMENT_CENTER
	for s: float in [16.0, 24.0, 36.0, 52.0, 72.0]:
		var icon := NeonIcon.make(&"shield" if s < 50.0 else &"settings", s, get_theme_color(&"accent", UiTheme.NEON))
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ladder.add_child(icon)
	row.add_child(ladder)


## Page 2 (--page=controls): the type styles and Godot's standard controls under the theme.
func _standard_controls_page(parent: Control) -> void:
	var row := _row(parent)
	var type := VBoxContainer.new()
	type.add_theme_constant_override(&"separation", 6)
	row.add_child(type)
	for spec: Array in [[UiTheme.TITLE, "NEON RUNNER"], [UiTheme.HEADING, "Zone 1: Neon City"],
			[UiTheme.SUBHEADING, "LEVEL COMPLETE"], [&"", "Body text: runs, walls and ceilings."],
			[UiTheme.CAPTION, "Caption: dimmer supporting text."], [UiTheme.ACCENT_CAPTION, "NEW ITEM"],
			[UiTheme.DANGER_CAPTION, "NOT ENOUGH CREDITS"], [UiTheme.VALUE, "98,765"]]:
		var label := Label.new()
		label.theme_type_variation = spec[0]
		label.text = spec[1]
		type.add_child(label)
	var keys := HBoxContainer.new()
	for key: String in ["ESC", "ENTER", "E"]:
		var cap := Label.new()
		cap.theme_type_variation = UiTheme.KEY_CAP
		cap.text = key
		keys.add_child(cap)
	type.add_child(keys)

	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(430, 250)
	for tab_name: String in ["WEAPONS", "PROTECTION", "MOBILITY"]:
		var page := VBoxContainer.new()
		page.name = tab_name
		var text := RichTextLabel.new()
		text.bbcode_enabled = true
		text.fit_content = true
		text.text = "[b]%s[/b]: items for this category. Rich text with [b]bold[/b] words." % tab_name.capitalize()
		page.add_child(text)
		page.add_child(HSeparator.new())
		var bar := ProgressBar.new()
		bar.value = 64
		page.add_child(bar)
		var thin := ProgressBar.new()
		thin.theme_type_variation = UiTheme.THIN_BAR
		thin.show_percentage = false
		thin.value = 40
		page.add_child(thin)
		tabs.add_child(page)
	row.add_child(tabs)

	var column := VBoxContainer.new()
	row.add_child(column)
	var quality := OptionButton.new()
	for item: String in ["Low", "Medium", "High"]:
		quality.add_item(item)
	quality.select(1)
	column.add_child(quality)
	var vibration := CheckButton.new()
	vibration.text = "Vibration"
	vibration.button_pressed = true
	column.add_child(vibration)
	var lanes := ButtonGroup.new()
	for lane_text: String in ["3 lanes", "5 lanes"]:
		var radio := CheckBox.new()
		radio.text = lane_text
		radio.button_group = lanes
		radio.button_pressed = lane_text == "5 lanes"
		column.add_child(radio)
	var locked := LineEdit.new()
	locked.text = "Read-only field"
	locked.editable = false
	column.add_child(locked)
	var tip := PanelContainer.new()
	tip.theme_type_variation = &"TooltipPanel"
	var tip_label := Label.new()
	tip_label.theme_type_variation = &"TooltipLabel"
	tip_label.text = "A tooltip"
	tip.add_child(tip_label)
	column.add_child(tip)
	var volume := VSlider.new()
	volume.custom_minimum_size = Vector2(32, 200)
	volume.value = 35
	row.add_child(volume)
	initial_focus = quality
	quality.show_popup.call_deferred()


func _ask_quit() -> void:
	var d := ConfirmDialog.ask(self, "QUIT RUN?", "You keep 20% of the credits collected in this attempt.",
		"QUIT", "KEEP RUNNING", true)
	d.confirmed.connect(func() -> void: Toast.show_message(self, "Run abandoned", &"warning", Toast.Kind.WARNING))


## A stand-in for the 3D game behind the HUD: dark, with hazard-coloured shapes, so the HUD's
## legibility and colour separation can be judged.
class FakeGame:
	extends Control

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, 0), r.end, Vector2(0, r.end.y)]),
			PackedColorArray([Color(0.1, 0.05, 0.2), Color(0.25, 0.08, 0.3), Color(0.05, 0.05, 0.1), Color(0.02, 0.02, 0.05)]))
		draw_rect(Rect2(size.x * 0.18, size.y * 0.35, size.x * 0.05, size.y * 0.5), Color(1.0, 0.18, 0.62, 0.8))
		draw_rect(Rect2(size.x * 0.4, size.y * 0.78, size.x * 0.2, 4), Color(1.0, 0.45, 0.1))
		draw_rect(Rect2(size.x * 0.66, size.y * 0.1, size.x * 0.06, size.y * 0.25), Color(1.0, 0.8, 0.15, 0.9))
		draw_rect(Rect2(size.x * 0.52, size.y * 0.55, size.x * 0.08, size.y * 0.12), Color(0.1, 1.0, 0.95, 0.7))
		draw_rect(Rect2(size.x * 0.86, size.y * 0.6, size.x * 0.05, size.y * 0.3), Color(0.3, 1.0, 0.35, 0.7))
		for i: int in 12:
			draw_line(Vector2(size.x * 0.5, 0), Vector2(i * size.x / 11.0, size.y), Color(1, 1, 1, 0.06), 2.0)

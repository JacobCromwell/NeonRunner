class_name SettingsScreen
extends Control
## Settings (GDD §3): audio volumes, full key rebinding, and accessibility (screen shake, reduced
## flashing). Works as a full screen or an overlay (from the pause menu). Placeholder look.

var on_close: Callable

var _waiting_for: StringName = &""
var _bind_buttons: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ScreenKit.fill(self)
	ScreenKit.backdrop(self, 0.85)
	var col: VBoxContainer = ScreenKit.column(self, 640.0)
	ScreenKit.title(col, "SETTINGS", 34)
	for bus: String in ["master", "music", "sfx"]:
		var r: HBoxContainer = ScreenKit.row(col)
		ScreenKit.label(r, {"master": "Volume", "music": "Music", "sfx": "Sound effects"}[bus], 18).custom_minimum_size.x = 180.0
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = float(Settings.value(App.profile, "volume_" + bus))
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(func(v: float) -> void:
			Settings.set_value(App.profile, "volume_" + bus, v)
			App.save())
		r.add_child(slider)
	for key: String in ["screen_shake", "reduced_flashing"]:
		var check := CheckButton.new()
		check.text = {"screen_shake": "Screen shake", "reduced_flashing": "Reduced flashing"}[key]
		check.button_pressed = bool(Settings.value(App.profile, key))
		check.toggled.connect(func(on: bool) -> void:
			Settings.set_value(App.profile, key, on)
			App.save())
		col.add_child(check)
	ScreenKit.label(col, "Keys (select one, then press the new key)", 16)
	var grid := GridContainer.new()
	grid.columns = 2
	col.add_child(grid)
	for action: StringName in Settings.REBINDABLE:
		if action == &"slow_time" and App.mobile:
			continue
		ScreenKit.label(grid, Settings.ACTION_LABELS[action], 16).custom_minimum_size.x = 220.0
		var b: Button = ScreenKit.button(grid, "", func() -> void: _start_rebind(action))
		b.custom_minimum_size.x = 200.0
		_bind_buttons[action] = b
	_refresh_bindings()
	var buttons: HBoxContainer = ScreenKit.row(col)
	ScreenKit.button(buttons, "Reset keys", func() -> void:
		Settings.reset_bindings(App.profile)
		App.save()
		_refresh_bindings())
	ScreenKit.button(buttons, "Back", _close)
	ScreenKit.focus_first(self)


func _start_rebind(action: StringName) -> void:
	_waiting_for = action
	(_bind_buttons[action] as Button).text = "Press a key..."


func _refresh_bindings() -> void:
	for action: StringName in _bind_buttons:
		(_bind_buttons[action] as Button).text = ", ".join(Settings.key_names(action))


func _input(event: InputEvent) -> void:
	if _waiting_for == &"" or not (event is InputEventKey) or not event.pressed or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	if (event as InputEventKey).keycode != KEY_ESCAPE:
		Settings.bind_key(App.profile, _waiting_for, event as InputEventKey)
		App.save()
	_waiting_for = &""
	_refresh_bindings()


func _unhandled_input(event: InputEvent) -> void:
	if _waiting_for == &"" and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	if on_close.is_valid():
		on_close.call()

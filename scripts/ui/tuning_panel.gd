class_name TuningPanel
extends CanvasLayer
## Live tuning for the feel test (F6). One slider per ranged MovementTuning property, built from
## the resource's own range hints, so new tunables show up with no extra code. Edits apply to the
## shared resource at once; Save writes it back to its .tres file (or user:// in an exported build).

signal restart_requested
signal close_requested

const FALLBACK_SAVE_PATH: String = "user://movement_tuning.tres"

var tuning: MovementTuning
var _rows: VBoxContainer
var _status: Label
var _sliders: Dictionary = {}
var _value_labels: Dictionary = {}
var _suffixes: Dictionary = {}
var _checks: Dictionary = {}


func setup(p_tuning: MovementTuning) -> void:
	tuning = p_tuning
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	visible = false
	_build()


func open() -> void:
	_refresh()
	_status.text = ""
	visible = true


func close() -> void:
	visible = false
	var viewport := get_viewport()
	if viewport != null:
		viewport.gui_release_focus()


## Number of generated controls, for tests.
func control_count() -> int:
	return _sliders.size() + _checks.size()


func _build() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -430.0
	panel.offset_right = -12.0
	panel.offset_top = 12.0
	panel.offset_bottom = -12.0
	add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)

	var title := Label.new()
	title.text = "Movement tuning (live)"
	title.add_theme_font_size_override(&"font_size", 20)
	box.add_child(title)
	var note := Label.new()
	note.text = "Changes apply at once. Speed, jump and size changes also reshape the level: press Restart to rebuild it."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.modulate = Color(1, 1, 1, 0.7)
	box.add_child(note)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	_build_rows()

	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	_button(buttons, "Save", _save)
	_button(buttons, "Reload file", _reload)
	_button(buttons, "Restart level", func() -> void: restart_requested.emit())
	_button(buttons, "Close (F6)", func() -> void: close_requested.emit())
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)


func _build_rows() -> void:
	var group: String = ""
	for prop: Dictionary in tuning.get_property_list():
		var usage: int = prop["usage"]
		if usage & PROPERTY_USAGE_GROUP:
			group = prop["name"]
			continue
		if not (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or not (usage & PROPERTY_USAGE_EDITOR):
			continue
		var is_range: bool = prop["type"] == TYPE_FLOAT and prop["hint"] == PROPERTY_HINT_RANGE
		var is_bool: bool = prop["type"] == TYPE_BOOL
		if not is_range and not is_bool:
			continue
		if group != "":
			var header := Label.new()
			header.text = group
			header.add_theme_color_override(&"font_color", Color(0.55, 0.8, 1.0))
			_rows.add_child(header)
			group = ""
		var prop_name: String = prop["name"]
		var row := HBoxContainer.new()
		_rows.add_child(row)
		var label := Label.new()
		label.text = prop_name.capitalize()
		label.custom_minimum_size.x = 170.0
		label.clip_text = true
		row.add_child(label)
		if is_bool:
			var check := CheckBox.new()
			check.focus_mode = Control.FOCUS_NONE
			check.toggled.connect(func(on: bool) -> void: tuning.set(prop_name, on))
			row.add_child(check)
			_checks[prop_name] = check
			continue
		var hint: PackedStringArray = String(prop["hint_string"]).split(",")
		var slider := HSlider.new()
		slider.min_value = float(hint[0])
		slider.max_value = float(hint[1])
		slider.step = float(hint[2]) if hint.size() > 2 and hint[2].is_valid_float() else 0.01
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		# No keyboard focus: arrow keys must stay with the game.
		slider.focus_mode = Control.FOCUS_NONE
		slider.value_changed.connect(_on_slider_changed.bind(prop_name))
		row.add_child(slider)
		var value_label := Label.new()
		value_label.custom_minimum_size.x = 90.0
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value_label)
		_sliders[prop_name] = slider
		_value_labels[prop_name] = value_label
		for part: String in hint:
			if part.begins_with("suffix:"):
				_suffixes[prop_name] = part.trim_prefix("suffix:")


func _on_slider_changed(value: float, key: String) -> void:
	tuning.set(key, value)
	_show_value(key)


func _show_value(key: String) -> void:
	(_value_labels[key] as Label).text = "%s %s" % [String.num(float(tuning.get(key)), 3), _suffixes.get(key, "")]


func _refresh() -> void:
	for key: String in _sliders:
		(_sliders[key] as HSlider).set_value_no_signal(float(tuning.get(key)))
		_show_value(key)
	for key: String in _checks:
		(_checks[key] as CheckBox).set_pressed_no_signal(bool(tuning.get(key)))


func _save() -> void:
	var path: String = tuning.resource_path
	var err: Error = ResourceSaver.save(tuning, path) if path != "" else ERR_FILE_BAD_PATH
	if err != OK:
		path = FALLBACK_SAVE_PATH
		err = ResourceSaver.save(tuning, path)
	_status.text = "Saved to %s" % path if err == OK else "Save failed (%s)" % error_string(err)


func _reload() -> void:
	var fresh := ResourceLoader.load(tuning.resource_path, "", ResourceLoader.CACHE_MODE_IGNORE) as MovementTuning
	if fresh == null:
		_status.text = "Could not read %s" % tuning.resource_path
		return
	for prop: Dictionary in tuning.get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			tuning.set(prop["name"], fresh.get(prop["name"]))
	_refresh()
	_status.text = "Reloaded from %s" % tuning.resource_path


func _button(parent: Control, text: String, on_press: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_press)
	parent.add_child(b)

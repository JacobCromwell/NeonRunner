class_name TuningPanel
extends CanvasLayer
## Live tuning for the feel test (F6). Shows one control per ranged number or bool of each
## registered resource, built from the resource's own range hints, so new tunables show up with
## no extra code. Edits apply to the live resource at once. Save writes the shown values back to
## each resource's .tres file (or to user:// in an exported build, where res:// is read-only).

signal restart_requested
signal close_requested

## One entry per control: {resource, prop, section, slider|check, label, suffix, is_int}.
var _controls: Array[Dictionary] = []
## [{title, resource, path}]
var _sections: Array[Dictionary] = []
var _rows: VBoxContainer
var _status: Label


## `sections`: [{"title": String, "resource": Resource, "path": String}]. `path` is the file that
## Save and Reload use; the live resource may be an unsaved copy of it.
func setup(sections: Array[Dictionary]) -> void:
	_sections = sections
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
	return _controls.size()


## The slider for a property, for tests. Null if there's none.
func find_slider(prop: String) -> HSlider:
	for c: Dictionary in _controls:
		if c["prop"] == prop and c.has("slider"):
			return c["slider"]
	return null


func _build() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -440.0
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
	title.text = "Live tuning"
	title.add_theme_font_size_override(&"font_size", 20)
	box.add_child(title)
	var note := Label.new()
	note.text = "Changes apply at once. Level pacing and any speed, jump or size change reshape the level: press Restart level to rebuild it."
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
	for i: int in _sections.size():
		_build_section(i)

	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	_button(buttons, "Save", _save)
	_button(buttons, "Reload files", _reload)
	_button(buttons, "Restart level", func() -> void: restart_requested.emit())
	_button(buttons, "Close (F6)", func() -> void: close_requested.emit())
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)


func _build_section(index: int) -> void:
	var section: Dictionary = _sections[index]
	var resource: Resource = section["resource"]
	var heading := Label.new()
	heading.text = section["title"]
	heading.add_theme_font_size_override(&"font_size", 18)
	heading.add_theme_color_override(&"font_color", Color(1.0, 0.45, 0.8))
	_rows.add_child(heading)
	var group: String = ""
	for prop: Dictionary in _editable_props(resource):
		if prop.has("group"):
			group = prop["group"]
			continue
		if group != "":
			var header := Label.new()
			header.text = group
			header.add_theme_color_override(&"font_color", Color(0.55, 0.8, 1.0))
			_rows.add_child(header)
			group = ""
		_build_row(resource, prop)


## The ranged numbers and bools the panel can edit, with {"group": name} markers in between.
func _editable_props(resource: Resource) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for prop: Dictionary in resource.get_property_list():
		var usage: int = prop["usage"]
		if usage & PROPERTY_USAGE_GROUP:
			out.append({"group": prop["name"]})
			continue
		if not (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or not (usage & PROPERTY_USAGE_EDITOR):
			continue
		var ranged: bool = prop["type"] in [TYPE_FLOAT, TYPE_INT] and prop["hint"] == PROPERTY_HINT_RANGE
		if ranged or prop["type"] == TYPE_BOOL:
			out.append(prop)
	return out


func _build_row(resource: Resource, prop: Dictionary) -> void:
	var prop_name: String = prop["name"]
	var row := HBoxContainer.new()
	_rows.add_child(row)
	var label := Label.new()
	label.text = prop_name.capitalize()
	label.custom_minimum_size.x = 180.0
	label.clip_text = true
	row.add_child(label)
	var control := {"resource": resource, "prop": prop_name}
	if prop["type"] == TYPE_BOOL:
		var check := CheckBox.new()
		check.focus_mode = Control.FOCUS_NONE
		check.toggled.connect(func(on: bool) -> void: resource.set(prop_name, on))
		row.add_child(check)
		control["check"] = check
		_controls.append(control)
		return
	var hint: PackedStringArray = String(prop["hint_string"]).split(",")
	var is_int: bool = prop["type"] == TYPE_INT
	var slider := HSlider.new()
	slider.min_value = float(hint[0])
	slider.max_value = float(hint[1])
	slider.step = 1.0 if is_int else (float(hint[2]) if hint.size() > 2 and hint[2].is_valid_float() else 0.01)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# No keyboard focus: arrow keys must stay with the game.
	slider.focus_mode = Control.FOCUS_NONE
	row.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size.x = 90.0
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	control["slider"] = slider
	control["label"] = value_label
	control["is_int"] = is_int
	control["suffix"] = ""
	for part: String in hint:
		if part.begins_with("suffix:"):
			control["suffix"] = part.trim_prefix("suffix:")
	slider.value_changed.connect(_on_slider_changed.bind(control))
	_controls.append(control)


func _on_slider_changed(value: float, control: Dictionary) -> void:
	var resource: Resource = control["resource"]
	resource.set(control["prop"], int(value) if control["is_int"] else value)
	_show_value(control)


func _show_value(control: Dictionary) -> void:
	var value: Variant = (control["resource"] as Resource).get(control["prop"])
	var text: String = str(value) if control["is_int"] else String.num(float(value), 3)
	(control["label"] as Label).text = "%s %s" % [text, control["suffix"]]


func _refresh() -> void:
	for c: Dictionary in _controls:
		var value: Variant = (c["resource"] as Resource).get(c["prop"])
		if c.has("slider"):
			(c["slider"] as HSlider).set_value_no_signal(float(value))
			_show_value(c)
		else:
			(c["check"] as CheckBox).set_pressed_no_signal(bool(value))


## Copies the shown values onto a fresh copy of each file and saves it, so only tunables are
## written (a live copy may carry debug changes such as the current seed).
func _save() -> void:
	var lines: PackedStringArray = []
	for section: Dictionary in _sections:
		var path: String = section["path"]
		var target: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if target == null:
			lines.append("Could not read %s" % path)
			continue
		_copy_shown(section["resource"], target)
		var err: Error = ResourceSaver.save(target, path)
		if err != OK:
			path = "user://" + path.get_file()
			err = ResourceSaver.save(target, path)
		lines.append("Saved %s" % path if err == OK else "Save failed for %s (%s)" % [path, error_string(err)])
	_status.text = "\n".join(lines)


func _reload() -> void:
	for section: Dictionary in _sections:
		var fresh: Resource = ResourceLoader.load(section["path"], "", ResourceLoader.CACHE_MODE_IGNORE)
		if fresh != null:
			_copy_shown(fresh, section["resource"])
	_refresh()
	_status.text = "Reloaded from the saved files."


func _copy_shown(from: Resource, to: Resource) -> void:
	for prop: Dictionary in _editable_props(from):
		if not prop.has("group"):
			to.set(prop["name"], from.get(prop["name"]))


func _button(parent: Control, text: String, on_press: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_press)
	parent.add_child(b)

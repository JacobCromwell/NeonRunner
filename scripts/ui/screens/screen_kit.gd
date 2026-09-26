class_name ScreenKit
extends RefCounted
## Small builders for the placeholder screens: a centred panel with a column, titles, labels and
## buttons. The themed widget kit (scripts/ui/widgets) replaces these as screens get their final look.


static func fill(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## A dimmed full-screen backdrop (for overlays) under `c`.
static func backdrop(c: Control, alpha: float = 0.65) -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.0, 0.04, alpha)
	fill(bg)
	c.add_child(bg)


## A centred panel holding a vertical column; returns the column.
static func column(parent: Control, min_width: float = 520.0) -> VBoxContainer:
	var center := CenterContainer.new()
	fill(center)
	parent.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = min_width
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	margin.add_child(box)
	return box


static func title(parent: Control, text: String, size: int = 40) -> Label:
	var l := label(parent, text, size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override(&"font_color", Color(0.55, 0.85, 1.0))
	return l


static func label(parent: Control, text: String, size: int = 18) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l


static func button(parent: Control, text: String, on_press: Callable, disabled: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = disabled
	b.custom_minimum_size = Vector2(0.0, 44.0)
	b.pressed.connect(on_press)
	b.focus_entered.connect(func() -> void: App.play_ui_sound(&"ui_move"))
	b.pressed.connect(func() -> void: App.play_ui_sound(&"ui_select"))
	parent.add_child(b)
	return b


static func row(parent: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 10)
	parent.add_child(h)
	return h


## Gives keyboard focus to the first enabled button under `root` (after layout).
static func focus_first(root: Control) -> void:
	var first: Button = _first_button(root)
	if first != null:
		first.grab_focus.call_deferred()


static func _first_button(n: Node) -> Button:
	for child: Node in n.get_children():
		if child is Button and not (child as Button).disabled and (child as Button).visible:
			return child
		var found: Button = _first_button(child)
		if found != null:
			return found
	return null

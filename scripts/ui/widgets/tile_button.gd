class_name TileButton
extends NeonButton
## A button that holds a small layout instead of one line of text: level tiles, zone cards, store
## buttons, credit packs. It keeps everything a NeonButton has (states, focus ring, sounds,
## keyboard and touch); its content goes in `content`, a VBoxContainer inside the button's padding,
## and the button grows to fit it. Controls added to the content never take clicks from the button.
##   var tile := TileButton.new()
##   tile.content.add_child(NeonIcon.make(&"film", 32))
##   tile.add_label("INTRO", UiTheme.CAPTION)

var content: VBoxContainer
var _pad: MarginContainer


func _init() -> void:
	super()
	_pad = MarginContainer.new()
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_pad)
	content = VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	_pad.add_child(content)
	_pad.minimum_size_changed.connect(_fit)
	content.child_entered_tree.connect(_quiet_child)


## Adds a label with a theme type variation (UiTheme.CAPTION, UiTheme.CARD_TITLE, ...).
func add_label(label_text: String, variation: StringName = &"", align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = label_text
	l.theme_type_variation = variation
	l.horizontal_alignment = align
	content.add_child(l)
	return l


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_pad_to_style()


## The content sits inside the normal style's padding, like a button's text would.
func _pad_to_style() -> void:
	var sb: StyleBox = get_theme_stylebox(&"normal")
	if sb == null or _pad == null:
		return
	_pad.add_theme_constant_override(&"margin_left", roundi(sb.get_margin(SIDE_LEFT)))
	_pad.add_theme_constant_override(&"margin_right", roundi(sb.get_margin(SIDE_RIGHT)))
	# Tiles are taller than a text button; they don't need its vertical centring padding.
	_pad.add_theme_constant_override(&"margin_top", 10)
	_pad.add_theme_constant_override(&"margin_bottom", 10)
	_fit()


func _fit() -> void:
	custom_minimum_size = custom_minimum_size.max(_pad.get_combined_minimum_size())


## Everything inside the tile lets the pointer through to the button.
func _quiet_child(node: Node) -> void:
	var c := node as Control
	if c != null:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.focus_mode = Control.FOCUS_NONE
	if not node.child_entered_tree.is_connected(_quiet_child):
		node.child_entered_tree.connect(_quiet_child)

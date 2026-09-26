class_name DebugHud
extends CanvasLayer
## Prototype-only readout: level progress, movement state and debug controls. This isn't the game HUD.

var _info: Label
var _center: Label
var _pause: Label
var _help: Label
var _progress: ProgressBar


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_progress = ProgressBar.new()
	_progress.show_percentage = false
	_progress.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_progress.offset_left = 16
	_progress.offset_right = -16
	_progress.offset_top = 10
	_progress.offset_bottom = 18
	add_child(_progress)

	_info = _label(16)
	_info.position = Vector2(16, 28)
	add_child(_info)

	_center = _centered_label(40, 0.0)
	_pause = _centered_label(28, 60.0)

	_help = _label(14)
	_help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_help.offset_left = 16
	_help.offset_top = -70
	_help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_help.modulate = Color(1, 1, 1, 0.7)
	# The default font has no arrow glyphs, so keys are spelled out.
	_help.text = "Left/Right: lanes & wall entry   Up/Space: jump   Down: slide   (touch: swipe)   Esc/P: pause\n" \
		+ "R restart   F1 lanes 3/5/6   F2 next seed   F3 difficulty   F4 god mode   F5 hitboxes   F6 tuning   M mute"
	add_child(_help)


func set_info(text: String, progress: float) -> void:
	_info.text = text
	_progress.value = progress * 100.0


func set_message(text: String) -> void:
	_center.text = text


func set_pause_text(text: String) -> void:
	_pause.text = text


func _centered_label(size: int, y_offset: float) -> Label:
	var label := _label(size)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	label.offset_top += y_offset
	label.offset_bottom += y_offset
	add_child(label)
	return label


func _label(size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.add_theme_constant_override(&"outline_size", 4)
	return label

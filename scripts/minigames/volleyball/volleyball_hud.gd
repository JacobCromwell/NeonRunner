class_name VolleyballHud
extends CanvasLayer
## The volleyball match's scoreboard (VolleyballMatch), on the HUD's theme beside the run's own HUD (RunHud): under
## the level's progress meter, the points ("YOU 2 – 1 RIVAL") with "FIRST TO 4" under them, and a pip for each return
## the rally needs, lit as the runner makes them; a call in the middle of the screen for each point ("POINT!",
## "MISSED") and the match's end with its payout. It shows when the match begins and goes when the runner sets off.
## Steady text and colours only (Settings > Reduced flashing has nothing to hold back here).

const POINT_COLOR := Color(0.75, 0.9, 1.0)

var root: Control
var _panel: PanelContainer
var _you: Label
var _rival: Label
var _caption: Label
var _pips: HBoxContainer
var _call: Label
var _payout: HBoxContainer
var _payout_label: Label
var _call_tween: Tween


func _ready() -> void:
	layer = 4
	root = Control.new()
	root.name = "VolleyballHudRoot"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiTheme.apply(root, true)
	add_child(root)

	_panel = PanelContainer.new()
	_panel.name = "Scoreboard"
	_panel.theme_type_variation = UiTheme.HUD_PANEL
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(_panel)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", roundi(UiTheme.px(2)))
	_panel.add_child(column)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", roundi(UiTheme.px(14)))
	column.add_child(row)
	row.add_child(_label("YOU", UiTheme.HUD_CAPTION))
	_you = _label("0", UiTheme.HUD_VALUE)
	_you.add_theme_font_size_override(&"font_size", roundi(UiTheme.px(30)))
	row.add_child(_you)
	row.add_child(_label("–", UiTheme.HUD_VALUE))
	_rival = _label("0", UiTheme.HUD_VALUE)
	_rival.add_theme_font_size_override(&"font_size", roundi(UiTheme.px(30)))
	row.add_child(_rival)
	row.add_child(_label("RIVAL", UiTheme.HUD_CAPTION))
	_caption = _label("", UiTheme.HUD_CAPTION)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_caption)
	_pips = HBoxContainer.new()
	_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pips.alignment = BoxContainer.ALIGNMENT_CENTER
	_pips.add_theme_constant_override(&"separation", roundi(UiTheme.px(8)))
	column.add_child(_pips)

	_call = _label("", UiTheme.HUD_VALUE)
	_call.name = "Call"
	_call.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_call.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_call.add_theme_font_size_override(&"font_size", roundi(UiTheme.px(46)))
	_call.add_theme_constant_override(&"outline_size", roundi(UiTheme.px(8)))
	_call.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_call.offset_bottom = -UiTheme.px(120)
	root.add_child(_call)

	_payout = HBoxContainer.new()
	_payout.name = "Payout"
	_payout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_payout.alignment = BoxContainer.ALIGNMENT_CENTER
	_payout.add_theme_constant_override(&"separation", roundi(UiTheme.px(10)))
	_payout.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_payout.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_payout.grow_vertical = Control.GROW_DIRECTION_BOTH
	_payout.offset_top = UiTheme.px(10)
	_payout.offset_bottom = UiTheme.px(60)
	_payout.visible = false
	root.add_child(_payout)
	_payout_label = _label("", UiTheme.HUD_VALUE)
	_payout_label.add_theme_font_size_override(&"font_size", roundi(UiTheme.px(36)))
	_payout_label.add_theme_constant_override(&"outline_size", roundi(UiTheme.px(6)))
	_payout.add_child(_payout_label)
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = IconFactory.texture(IconFactory.credit_icon(100), UiTheme.px(34), Color.WHITE)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_payout.add_child(icon)
	_place()
	root.resized.connect(_place)
	visible = false


## The points, the match's target and the rally's returns so far (of `needed`).
func show_score(you: int, rival: int, points_to_win: int, returns: int, needed: int) -> void:
	_you.text = str(you)
	_rival.text = str(rival)
	_caption.text = "FIRST TO %d" % points_to_win
	while _pips.get_child_count() < needed:
		var pip := ColorRect.new()
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.custom_minimum_size = Vector2.ONE * UiTheme.px(12)
		_pips.add_child(pip)
	while _pips.get_child_count() > needed:
		var last: Node = _pips.get_child(_pips.get_child_count() - 1)
		_pips.remove_child(last)
		last.queue_free()
	var lit: Color = UiTheme.style().accent.lerp(Color.WHITE, 0.35)
	var dim: Color = UiTheme.style().text_disabled
	for i: int in _pips.get_child_count():
		(_pips.get_child(i) as ColorRect).color = lit if i < returns else dim


## A call in the middle of the screen for a moment ("POINT!", "MISSED"); "" clears it.
func call_out(text: String, color: Color = Color.WHITE, seconds: float = 1.2) -> void:
	_call.text = text
	_call.add_theme_color_override(&"font_color", color)
	if _call_tween != null:
		_call_tween.kill()
	_call.modulate.a = 1.0
	if text == "":
		return
	_call.pivot_offset = _call.size * 0.5
	_call.scale = Vector2(0.85, 0.85)
	_call_tween = _call.create_tween()
	_call_tween.tween_property(_call, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if seconds > 0.0:
		_call_tween.tween_interval(seconds)
		_call_tween.tween_property(_call, "modulate:a", 0.0, 0.3)


## The match's payout under the call ("+300" with the credit icon), or hidden with 0 or less.
func show_payout(credits: int) -> void:
	_payout.visible = credits > 0
	_payout_label.text = "+%s" % UiTheme.format_int(credits)
	_payout_label.add_theme_color_override(&"font_color", UiTheme.credit_color(100))


func call_text() -> String:
	return _call.text if _call.modulate.a > 0.0 else ""


## Under the level's progress meter, inside the safe area.
func _place() -> void:
	var safe: Vector4 = UiTheme.safe_area_margins(root)
	_panel.offset_top = safe.y + UiTheme.px(64)
	_panel.offset_bottom = _panel.offset_top
	_panel.offset_left = 0.0
	_panel.offset_right = 0.0


func _label(text: String, variation: StringName) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

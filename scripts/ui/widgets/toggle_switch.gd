class_name ToggleSwitch
extends BaseButton
## An on/off switch with an animated knob. It's a toggle button: `button_pressed` is the state,
## `toggled(on)` fires on change, ui_accept and clicks flip it. The control is as tall as a touch
## target; the pill is centred in it.
##   var sw := ToggleSwitch.new()
##   sw.set_on(true, false)
##   sw.toggled.connect(func(on: bool) -> void: ...)

## Knob travel time in seconds.
const SLIDE_TIME: float = 0.12

@export var sound_move: StringName = UiSounds.MOVE
@export var sound_select: StringName = UiSounds.SELECT

## 0 = off, 1 = on; follows button_pressed with a short slide.
var _knob: float = 0.0


func _init() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func() -> void:
		if not disabled:
			UiSounds.play(sound_move))
	focus_entered.connect(func() -> void:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			UiSounds.play(sound_move))
	pressed.connect(func() -> void: UiSounds.play(sound_select))
	set_process(false)


## Sets the state; `animate` = slide the knob, `notify` = emit toggled.
func set_on(on: bool, animate: bool = true, notify: bool = false) -> void:
	if notify:
		button_pressed = on
	else:
		set_pressed_no_signal(on)
	if animate:
		set_process(true)
	else:
		_knob = 1.0 if on else 0.0
	queue_redraw()


func is_on() -> bool:
	return button_pressed


func _toggled(_on: bool) -> void:
	set_process(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		_ensure_theme.call_deferred()
		_knob = 1.0 if button_pressed else 0.0
	elif what == NOTIFICATION_THEME_CHANGED:
		update_minimum_size()
		queue_redraw()


func _ensure_theme() -> void:
	UiTheme.ensure(self)


func _process(delta: float) -> void:
	var target: float = 1.0 if button_pressed else 0.0
	_knob = move_toward(_knob, target, delta / SLIDE_TIME)
	if is_equal_approx(_knob, target):
		_knob = target
		set_process(false)
	queue_redraw()


func _get_minimum_size() -> Vector2:
	var w: float = get_theme_constant(&"width", &"ToggleSwitch")
	var h: float = maxf(get_theme_constant(&"height", &"ToggleSwitch"), get_theme_constant(&"control_height", UiTheme.NEON))
	return Vector2(w, h)


func _draw() -> void:
	var t: StringName = &"ToggleSwitch"
	var w: float = get_theme_constant(&"width", t)
	var h: float = get_theme_constant(&"height", t)
	var pill := Rect2(Vector2(0.0, (size.y - h) * 0.5), Vector2(w, h))
	var r: float = h * 0.5
	var k: float = _knob * _knob * (3.0 - 2.0 * _knob)
	var track: Color = get_theme_color(&"track_off", t).lerp(get_theme_color(&"track_on", t), k)
	var border: Color = get_theme_color(&"border_off", t).lerp(get_theme_color(&"border_on", t), k)
	var knob: Color = get_theme_color(&"knob_off", t).lerp(get_theme_color(&"knob_on", t), k)
	if disabled:
		track = Color(track, track.a * 0.5)
		border = get_theme_color(&"disabled", t)
		knob = get_theme_color(&"disabled", t)
	elif is_hovered() or has_focus(true):
		border = border.lerp(Color.WHITE, 0.35)
	if k > 0.0 and not disabled:
		var glow: Color = get_theme_color(&"glow", t)
		_draw_pill(pill.grow(3.0), Color(glow, glow.a * k * 0.6))
	_draw_pill(pill, track)
	_draw_pill_outline(pill, border, 1.5)
	var knob_r: float = r - maxf(4.0, h * 0.16)
	var cx: float = lerpf(pill.position.x + r, pill.end.x - r, k)
	var pressing: bool = get_draw_mode() == DRAW_PRESSED or get_draw_mode() == DRAW_HOVER_PRESSED
	draw_circle(Vector2(cx, pill.get_center().y), knob_r * (0.9 if pressing else 1.0), knob, true, -1.0, true)
	if has_focus(true):
		draw_style_box(get_theme_stylebox(&"focus", UiTheme.NEON), pill)


## One polygon (not a rect plus circles), so translucent colours don't double up where they overlap.
static func pill_points(rect: Rect2, inset: float = 0.0) -> PackedVector2Array:
	var r: float = minf(rect.size.x, rect.size.y) * 0.5
	var arcs := IconFactory.arc_points(Vector2(rect.end.x - r, rect.position.y + rect.size.y * 0.5), r - inset, -PI / 2.0, PI / 2.0, 16)
	arcs.append_array(IconFactory.arc_points(Vector2(rect.position.x + r, rect.position.y + rect.size.y * 0.5), r - inset, PI / 2.0, PI * 1.5, 16))
	# A pill as wide as it is tall is a circle: its two arcs meet, so drop the doubled points
	# (the triangulator rejects them).
	var points := PackedVector2Array()
	for p: Vector2 in arcs:
		if points.is_empty() or points[points.size() - 1].distance_to(p) > 0.01:
			points.append(p)
	if points.size() > 1 and points[0].distance_to(points[points.size() - 1]) <= 0.01:
		points.remove_at(points.size() - 1)
	return points


func _draw_pill(rect: Rect2, color: Color) -> void:
	draw_colored_polygon(pill_points(rect), color)


func _draw_pill_outline(rect: Rect2, color: Color, width: float) -> void:
	var points := pill_points(rect, width * 0.5)
	points.append(points[0])
	draw_polyline(points, color, width, true)

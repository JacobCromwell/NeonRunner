class_name CreditCounter
extends Control
## Credits: the credit icon and a number that counts to its target, with a little pop on gains.
## Digits are drawn in fixed-width cells, so the number doesn't jitter while it counts.
##   counter.set_value(1250)          # counts from the number shown now
##   counter.add(30)                  # counts up by 30
##   counter.set_value(0, false)      # jumps
## Under the HUD theme it draws a lighter chip and outlined digits.

signal count_finished

## The target value. Setting it counts to it (same as set_value(v)).
@export var value: int = 0:
	set(v):
		set_value(v)
	get:
		return _target
## Which credit icon (1, 5, 25 or 100).
@export var denomination: int = 1:
	set(v):
		denomination = v
		queue_redraw()
## Longest count, in seconds; small changes count faster.
@export_range(0.1, 3.0, 0.05, "suffix:s") var count_time: float = 0.9
## The background chip (the theme's CreditCounter/chip style).
@export var show_chip: bool = true:
	set(v):
		show_chip = v
		update_minimum_size()
		queue_redraw()

## The number on screen right now (moves towards `value`).
var shown: float = 0.0
var _target: int = 0
var _from: float = 0.0
var _progress: float = 1.0
var _duration: float = 0.0
var _pop: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


## Counts to `target` (or jumps there when `animate` is false).
func set_value(target: int, animate: bool = true) -> void:
	var gain: bool = target > roundi(shown)
	_target = target
	if not animate or not is_inside_tree():
		shown = target
		_progress = 1.0
		set_process(_pop > 0.0)
	else:
		_from = shown
		_progress = 0.0
		_duration = clampf(0.25 + absf(target - shown) / 600.0, 0.25, count_time)
		if gain:
			_pop = 1.0
		set_process(true)
	update_minimum_size()
	queue_redraw()


func add(amount: int) -> void:
	set_value(_target + amount)


## Jumps to the target now.
func finish() -> void:
	if is_counting():
		_progress = 1.0
		shown = _target
		count_finished.emit()
		queue_redraw()


func is_counting() -> bool:
	return _progress < 1.0


## The whole number on screen right now.
func displayed_value() -> int:
	return roundi(shown)


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		_ensure_theme.call_deferred()
	elif what == NOTIFICATION_THEME_CHANGED:
		update_minimum_size()
		queue_redraw()


func _ensure_theme() -> void:
	UiTheme.ensure(self)


func _process(delta: float) -> void:
	if _progress < 1.0:
		_progress = minf(1.0, _progress + delta / maxf(_duration, 0.001))
		var eased: float = 1.0 - pow(1.0 - _progress, 3.0)
		shown = lerpf(_from, _target, eased)
		if _progress >= 1.0:
			shown = _target
			count_finished.emit()
	_pop = maxf(0.0, _pop - delta * 2.5)
	if _progress >= 1.0 and _pop <= 0.0:
		set_process(false)
	queue_redraw()


func _text_for(v: float) -> String:
	return UiTheme.format_int(roundi(v))


func _get_minimum_size() -> Vector2:
	var t: StringName = &"CreditCounter"
	var font: Font = get_theme_font(&"font", t)
	var font_size: int = get_theme_font_size(&"font_size", t)
	var icon: float = get_theme_constant(&"icon_size", t)
	# Room for the longer of the shown and target numbers, so the chip doesn't twitch.
	var longest: String = _text_for(maxf(absf(shown), absf(_target)))
	var w: float = icon + get_theme_constant(&"separation", t) + UiTheme.tabular_width(font, longest, font_size)
	var h: float = maxf(icon, font.get_height(font_size))
	var chip: StyleBox = get_theme_stylebox(&"chip", t)
	if show_chip and chip != null:
		w += chip.get_margin(SIDE_LEFT) + chip.get_margin(SIDE_RIGHT)
		h += chip.get_margin(SIDE_TOP) + chip.get_margin(SIDE_BOTTOM)
	return Vector2(ceilf(w), ceilf(h))


func _draw() -> void:
	var t: StringName = &"CreditCounter"
	var rect := Rect2(Vector2.ZERO, size)
	var chip: StyleBox = get_theme_stylebox(&"chip", t)
	if show_chip and chip != null:
		draw_style_box(chip, rect)
		rect = Rect2(rect.position + Vector2(chip.get_margin(SIDE_LEFT), chip.get_margin(SIDE_TOP)),
			rect.size - chip.get_minimum_size())
	var icon: float = get_theme_constant(&"icon_size", t)
	var pop: float = sin(_pop * PI) * 0.22
	var icon_rect := Rect2(rect.position.x, rect.get_center().y - icon * 0.5, icon, icon)
	# The icon name doubles as the theme's colour name for that denomination (Neon/credit_25).
	var icon_id: StringName = IconFactory.credit_icon(denomination)
	var c: Color = get_theme_color(icon_id, UiTheme.NEON)
	IconFactory.draw(self, icon_id, icon_rect.grow(icon * pop * 0.5), c.lerp(Color.WHITE, _pop * 0.5))
	var font: Font = get_theme_font(&"font", t)
	var font_size: int = get_theme_font_size(&"font_size", t)
	var baseline: float = rect.get_center().y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	var color: Color = get_theme_color(&"font_color", t).lerp(get_theme_color(&"font_gain_color", t), _pop)
	UiTheme.draw_tabular(self, font, Vector2(icon_rect.end.x + get_theme_constant(&"separation", t), baseline),
		_text_for(shown), font_size, color, get_theme_constant(&"outline_size", t), get_theme_color(&"font_outline_color", t))

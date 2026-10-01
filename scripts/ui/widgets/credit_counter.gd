class_name CreditCounter
extends Control
## Credits: the credit icon and a number that counts to its target, with a little pop on gains.
## Digits are drawn in fixed-width cells, so the number doesn't jitter while it counts.
##   counter.set_value(1250)          # counts from the number shown now
##   counter.add(30)                  # counts up by 30
##   counter.set_value(0, false)      # jumps
## Under the HUD theme it draws a lighter chip and outlined digits. With show_icon and show_chip off
## it is a plain counting number (scores); theme overrides on the node work as usual, e.g.
## add_theme_font_size_override(&"font_size", 56).
## With drop_on_loss, a value that goes down (the run's credits after a theft, GDD §9.12) counts down
## with its digits in the theme's font_loss_color, dipped a little, fading back once: never a blink,
## and softer with Reduced flashing.

signal count_finished

## How long the loss look takes to fade (seconds), and its strength with Reduced flashing (1 without).
const LOSS_TIME: float = 0.9
const LOSS_REDUCED: float = 0.5

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
@export var show_icon: bool = true:
	set(v):
		show_icon = v
		update_minimum_size()
		queue_redraw()
## Flash and pop when the value goes up.
@export var pop_on_gain: bool = true
## Tint and dip when the value goes down (see the header).
@export var drop_on_loss: bool = false

## The number on screen right now (moves towards `value`).
var shown: float = 0.0
var _target: int = 0
var _from: float = 0.0
var _progress: float = 1.0
var _duration: float = 0.0
var _pop: float = 0.0
## The loss look's strength now: its peak when the value drops, fading to 0.
var _loss: float = 0.0


func _init() -> void:
	# Theme items come from the CreditCounter type, and node overrides apply to them.
	theme_type_variation = &"CreditCounter"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


## Counts to `target` (or jumps there when `animate` is false).
func set_value(target: int, animate: bool = true) -> void:
	var gain: bool = target > roundi(shown)
	var loss: bool = target < roundi(shown)
	_target = target
	if not animate or not is_inside_tree():
		shown = target
		_progress = 1.0
		set_process(_pop > 0.0 or _loss > 0.0)
	else:
		_from = shown
		_progress = 0.0
		_duration = clampf(0.25 + absf(target - shown) / 600.0, 0.25, count_time)
		if gain and pop_on_gain:
			_pop = 1.0
		if loss and drop_on_loss:
			_loss = LOSS_REDUCED if Settings.flashing_reduced else 1.0
		set_process(true)
	update_minimum_size()
	queue_redraw()


## The loss look's strength now (0 when it isn't showing): tests and tools.
func loss_look() -> float:
	return _loss


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
		UiTheme.ensure_later(self)
	elif what == NOTIFICATION_THEME_CHANGED:
		update_minimum_size()
		queue_redraw()


func _process(delta: float) -> void:
	if _progress < 1.0:
		_progress = minf(1.0, _progress + delta / maxf(_duration, 0.001))
		var eased: float = 1.0 - pow(1.0 - _progress, 3.0)
		shown = lerpf(_from, _target, eased)
		if _progress >= 1.0:
			shown = _target
			count_finished.emit()
	_pop = maxf(0.0, _pop - delta * 2.5)
	_loss = maxf(0.0, _loss - delta / LOSS_TIME)
	if _progress >= 1.0 and _pop <= 0.0 and _loss <= 0.0:
		set_process(false)
	queue_redraw()


func _text_for(v: float) -> String:
	return UiTheme.format_int(roundi(v))


func _icon_size() -> float:
	return float(get_theme_constant(&"icon_size")) if show_icon else 0.0


func _get_minimum_size() -> Vector2:
	var font: Font = get_theme_font(&"font")
	var font_size: int = get_theme_font_size(&"font_size")
	var icon: float = _icon_size()
	# Room for the wider of the shown and target numbers (a count between them is never wider), so
	# the chip doesn't twitch while counting. Signs included.
	var text_w: float = maxf(UiTheme.tabular_width(font, _text_for(shown), font_size),
		UiTheme.tabular_width(font, _text_for(_target), font_size))
	var w: float = icon + (get_theme_constant(&"separation") if show_icon else 0.0) + text_w
	var h: float = maxf(icon, font.get_height(font_size))
	var chip: StyleBox = get_theme_stylebox(&"chip")
	if show_chip and chip != null:
		w += chip.get_margin(SIDE_LEFT) + chip.get_margin(SIDE_RIGHT)
		h += chip.get_margin(SIDE_TOP) + chip.get_margin(SIDE_BOTTOM)
	return Vector2(ceilf(w), ceilf(h))


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var chip: StyleBox = get_theme_stylebox(&"chip")
	if show_chip and chip != null:
		draw_style_box(chip, rect)
		rect = Rect2(rect.position + Vector2(chip.get_margin(SIDE_LEFT), chip.get_margin(SIDE_TOP)),
			rect.size - chip.get_minimum_size())
	var icon: float = _icon_size()
	var text_x: float = rect.position.x
	if show_icon:
		var pop: float = sin(_pop * PI) * 0.22
		var icon_rect := Rect2(rect.position.x, rect.get_center().y - icon * 0.5, icon, icon)
		# The icon name doubles as the theme's colour name for that denomination (Neon/credit_25).
		var icon_id: StringName = IconFactory.credit_icon(denomination)
		var c: Color = get_theme_color(icon_id, UiTheme.NEON)
		IconFactory.draw(self, icon_id, icon_rect.grow(icon * pop * 0.5), c.lerp(Color.WHITE, _pop * 0.5))
		text_x = icon_rect.end.x + get_theme_constant(&"separation")
	var font: Font = get_theme_font(&"font")
	var font_size: int = get_theme_font_size(&"font_size")
	var baseline: float = rect.get_center().y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	var color: Color = get_theme_color(&"font_color").lerp(get_theme_color(&"font_gain_color"), _pop)
	if _loss > 0.0:
		# The loss look: the digits dip and take the loss colour, rising back as it fades.
		color = color.lerp(get_theme_color(&"font_loss_color"), _loss)
		baseline += font_size * 0.12 * _loss
	UiTheme.draw_tabular(self, font, Vector2(text_x, baseline), _text_for(shown), font_size, color,
		get_theme_constant(&"outline_size"), get_theme_color(&"font_outline_color"))

class_name CooldownIcon
extends Control
## A power-up on the HUD: its icon in a round badge, a radial sweep while it recharges, a flash
## when it's ready, and an optional count (charges or stock) and key hint.
## Either let it time itself, or drive it from gameplay every frame:
##   dash_icon.start_cooldown(4.0)                    # counts down on its own
##   dash_icon.set_cooldown(remaining, total)          # or: gameplay owns the timer
## Cooldown lengths come from gameplay data (CLAUDE.md principle 7), never from here.

## Emitted when a cooldown ends (after the ready flash starts).
signal became_ready

@export var icon_name: StringName = &"dash":
	set(v):
		icon_name = v
		queue_redraw()
## Charges or stock shown in a badge; -1 hides it. 0 dims the icon (nothing left).
@export var count: int = -1:
	set(v):
		count = v
		queue_redraw()
## A key shown in the corner on keyboard devices (e.g. "E" for slow time); empty = none.
@export var key_hint: String = "":
	set(v):
		key_hint = v
		queue_redraw()

## Length of the ready flash.
const FLASH_TIME: float = 0.45

var remaining: float = 0.0
var total: float = 0.0
var _self_timed: bool = false
var _flash: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


## Starts a cooldown the icon times itself.
func start_cooldown(seconds: float) -> void:
	total = maxf(seconds, 0.0)
	remaining = total
	_self_timed = true
	set_process(true)
	queue_redraw()


## Shows gameplay's own timer. Call every frame while cooling down; reaching 0 flashes.
func set_cooldown(seconds_left: float, seconds_total: float) -> void:
	var was_cooling: bool = remaining > 0.0
	_self_timed = false
	total = maxf(seconds_total, 0.0)
	remaining = clampf(seconds_left, 0.0, total)
	if was_cooling and remaining <= 0.0:
		_on_ready()
	queue_redraw()


func is_ready() -> bool:
	return remaining <= 0.0


## 0 = just started, 1 = ready.
func charge() -> float:
	return 1.0 if total <= 0.0 else 1.0 - remaining / total


func flash_ready() -> void:
	_flash = FLASH_TIME
	set_process(true)
	queue_redraw()


func _on_ready() -> void:
	remaining = 0.0
	flash_ready()
	became_ready.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		UiTheme.ensure_later(self)
	elif what == NOTIFICATION_THEME_CHANGED:
		update_minimum_size()
		queue_redraw()


func _process(delta: float) -> void:
	if _self_timed and remaining > 0.0:
		remaining = maxf(0.0, remaining - delta)
		if remaining <= 0.0:
			_on_ready()
	_flash = maxf(0.0, _flash - delta)
	if (not _self_timed or remaining <= 0.0) and _flash <= 0.0:
		set_process(false)
	queue_redraw()


func _get_minimum_size() -> Vector2:
	var s: float = get_theme_constant(&"size", &"CooldownIcon")
	return Vector2(s, s)


func _draw() -> void:
	var t: StringName = &"CooldownIcon"
	var ring_w: float = get_theme_constant(&"ring_width", t)
	var center: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.5 - ring_w - 2.0
	var cooling: bool = remaining > 0.0
	var empty: bool = count == 0
	var f: float = _flash / FLASH_TIME
	draw_circle(center, r + ring_w * 0.5, get_theme_color(&"disc", t), true, -1.0, true)

	var icon_color: Color = get_theme_color(&"icon_cooling", t) if cooling or empty else get_theme_color(&"icon", t)
	if empty:
		icon_color = Color(icon_color, icon_color.a * 0.45)
	icon_color = icon_color.lerp(get_theme_color(&"flash", t), f)
	var icon_r: float = r * 0.62
	IconFactory.draw(self, icon_name, Rect2(center - Vector2(icon_r, icon_r), Vector2(icon_r, icon_r) * 2.0), icon_color)

	var start: float = -PI / 2.0
	if cooling:
		# The part still recharging is shaded; it clears clockwise.
		var done: float = charge()
		var sweep: Color = get_theme_color(&"sweep", t)
		if done < 0.001:
			# A full pie would start and end on the same point, which the triangulator rejects.
			draw_circle(center, r, sweep, true, -1.0, true)
		elif done < 0.999:
			var pie := PackedVector2Array([center])
			pie.append_array(IconFactory.arc_points(center, r, start + TAU * done, start + TAU, maxi(2, ceili(48.0 * (1.0 - done)))))
			draw_colored_polygon(pie, sweep)
		draw_arc(center, r + ring_w * 0.5, 0.0, TAU, 64, get_theme_color(&"ring", t), ring_w, true)
		if done > 0.001:
			draw_arc(center, r + ring_w * 0.5, start, start + TAU * done, maxi(2, ceili(64.0 * done)),
				get_theme_color(&"progress", t), ring_w, true)
	else:
		var ring_color: Color = get_theme_color(&"ring", t) if empty else get_theme_color(&"ready", t)
		if not empty:
			draw_arc(center, r + ring_w * 0.5, 0.0, TAU, 64, Color(ring_color, 0.3), ring_w * 3.0, true)
		draw_arc(center, r + ring_w * 0.5, 0.0, TAU, 64, ring_color, ring_w, true)
	if f > 0.0:
		var k: float = 1.0 - f
		draw_arc(center, (r + ring_w) * (1.0 + 0.35 * k), 0.0, TAU, 64,
			Color(get_theme_color(&"flash", t), f), ring_w * (1.0 + f), true)

	var font: Font = get_theme_font(&"font", t)
	var font_size: int = get_theme_font_size(&"font_size", t)
	if count >= 0:
		var text: String = str(count)
		var br: float = maxf(r * 0.34, font.get_height(font_size) * 0.55)
		var bc: Vector2 = center + Vector2(r, r) * 0.72
		var badge_w: float = maxf(0.0, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x - br)
		var badge := Rect2(bc - Vector2(br + badge_w * 0.5, br), Vector2(br * 2.0 + badge_w, br * 2.0))
		var badge_color: Color = get_theme_color(&"ring", t) if empty else get_theme_color(&"badge", t)
		draw_colored_polygon(IconFactory.pill_points(badge), badge_color)
		draw_string(font, Vector2(badge.position.x, bc.y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5),
			text, HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, font_size, get_theme_color(&"badge_text", t))
	if key_hint != "" and not UiTheme.is_touch():
		# A small key cap on the top-left of the ring.
		var text_size: Vector2 = font.get_string_size(key_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var cap_size := Vector2(maxf(text_size.x + 8.0, font.get_height(font_size) + 2.0), font.get_height(font_size) + 2.0)
		var cap := Rect2(center + Vector2(-r - ring_w, -r - ring_w) * 0.92 - cap_size * 0.35, cap_size)
		draw_rect(cap, get_theme_color(&"hint_outline", t))
		draw_rect(cap, Color(get_theme_color(&"hint", t), 0.7), false, 1.0)
		draw_string(font, Vector2(cap.position.x, cap.get_center().y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5),
			key_hint, HORIZONTAL_ALIGNMENT_CENTER, cap.size.x, font_size, get_theme_color(&"hint", t))

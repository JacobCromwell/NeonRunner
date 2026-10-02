class_name ProgressMeter
extends Control
## Level progress: a thin glowing bar with a bright head at the current position, optional markers
## (they light up once passed) and a finish post. Values are fractions of the level, 0–1.
##   meter.markers = PackedFloat32Array([0.25, 0.5, 0.8])
##   meter.value = player.distance / layout.length
## The HUD shows a progress bar (FB 58); what the markers stand for (hull sections, drone waves, the
## boss...) stays undecided. This only draws them.

@export_range(0.0, 1.0, 0.001) var value: float = 0.0:
	set(v):
		value = clampf(v, 0.0, 1.0)
		queue_redraw()
## Marker positions, as fractions of the level.
@export var markers: PackedFloat32Array = PackedFloat32Array():
	set(v):
		markers = v
		queue_redraw()
@export var show_head: bool = true:
	set(v):
		show_head = v
		queue_redraw()
@export var show_finish: bool = true:
	set(v):
		show_finish = v
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		UiTheme.ensure_later(self)
	elif what == NOTIFICATION_THEME_CHANGED:
		update_minimum_size()
		queue_redraw()


func _get_minimum_size() -> Vector2:
	return Vector2(120.0, get_theme_constant(&"height", &"ProgressMeter"))


## The x position of a fraction along the track.
func position_of(fraction: float) -> float:
	var pad: float = _pad()
	return lerpf(pad, size.x - pad, clampf(fraction, 0.0, 1.0))


func _pad() -> float:
	return maxf(get_theme_constant(&"marker_size", &"ProgressMeter"), get_theme_constant(&"thickness", &"ProgressMeter")) * 0.75


func _draw() -> void:
	var t: StringName = &"ProgressMeter"
	var thick: float = get_theme_constant(&"thickness", t)
	var mark: float = get_theme_constant(&"marker_size", t)
	var y: float = size.y * 0.5
	var x0: float = position_of(0.0)
	var x1: float = position_of(1.0)
	var xv: float = position_of(value)
	var track := Rect2(x0, y - thick * 0.5, x1 - x0, thick)
	draw_rect(track, get_theme_color(&"track", t))
	draw_rect(track, get_theme_color(&"track_border", t), false, 1.0)
	var fill: Color = get_theme_color(&"fill", t)
	var glow: Color = get_theme_color(&"glow", t)
	if xv > x0:
		draw_rect(Rect2(x0, y - thick * 0.5 - 2.0, xv - x0, thick + 4.0), Color(glow, glow.a * 0.6))
		draw_rect(Rect2(x0, y - thick * 0.5, xv - x0, thick), fill)
	if show_finish:
		var post: Color = get_theme_color(&"marker", t) if value < 1.0 else get_theme_color(&"marker_passed", t)
		draw_rect(Rect2(x1 - 1.0, y - thick * 1.6, 2.0, thick * 3.2), post)
	for m: float in markers:
		var x: float = position_of(m)
		var passed: bool = m <= value
		var r: float = mark * 0.5
		var diamond := PackedVector2Array([Vector2(x, y - r), Vector2(x + r, y), Vector2(x, y + r), Vector2(x - r, y)])
		var c: Color = get_theme_color(&"marker_passed", t) if passed else get_theme_color(&"marker", t)
		draw_colored_polygon(diamond, get_theme_color(&"track", t).lerp(c, 0.9 if passed else 0.0))
		diamond.append(diamond[0])
		draw_polyline(diamond, c, 1.5, true)
	if show_head:
		var head: Color = get_theme_color(&"head", t)
		draw_circle(Vector2(xv, y), thick * 1.9, Color(glow, glow.a * 0.8), true, -1.0, true)
		draw_circle(Vector2(xv, y), thick * 1.1, fill.lerp(head, 0.5), true, -1.0, true)
		draw_circle(Vector2(xv, y), thick * 0.62, head, true, -1.0, true)

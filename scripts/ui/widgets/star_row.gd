class_name StarRow
extends Control
## A row of star slots (0–3 earned by default) with an animated reveal: each earned star pops in
## with a burst, one after another. The level-complete screen calls reveal(); lists use `stars`.
##   stars.reveal(2)                  # pops two stars in; emits star_revealed(i), reveal_finished
##   stars.stars = 3                  # shows three at once

signal star_revealed(index: int)
signal reveal_finished

@export_range(1, 5, 1) var max_stars: int = 3:
	set(v):
		max_stars = v
		update_minimum_size()
		queue_redraw()
## Earned stars, shown at once (no animation).
@export_range(0, 5, 1) var stars: int = 0:
	set(v):
		stars = clampi(v, 0, max_stars)
		_timer = -1.0
		set_process(false)
		queue_redraw()
## Star size in pixels; 0 = the theme's.
@export_range(0.0, 200.0, 1.0, "suffix:px") var star_size: float = 0.0:
	set(v):
		star_size = v
		update_minimum_size()
## Time between stars during a reveal.
@export_range(0.05, 2.0, 0.05, "suffix:s") var reveal_interval: float = 0.4

## Length of one star's pop animation.
const POP_TIME: float = 0.45

## Seconds since reveal() started; -1 when not revealing.
var _timer: float = -1.0
var _announced: int = 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


## Animates `count` stars in, one by one, from none.
func reveal(count: int) -> void:
	stars = clampi(count, 0, max_stars)
	_timer = 0.0
	_announced = 0
	set_process(true)
	queue_redraw()


func is_revealing() -> bool:
	return _timer >= 0.0


## Jumps to the end of a reveal.
func finish() -> void:
	if is_revealing():
		_timer = reveal_interval * stars + POP_TIME
		_process(0.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		UiTheme.ensure_later(self)
	elif what == NOTIFICATION_THEME_CHANGED:
		update_minimum_size()
		queue_redraw()


func _process(delta: float) -> void:
	_timer += delta
	while _announced < stars and _timer >= reveal_interval * _announced:
		star_revealed.emit(_announced)
		_announced += 1
	if _timer >= reveal_interval * maxi(stars - 1, 0) + POP_TIME:
		_timer = -1.0
		set_process(false)
		reveal_finished.emit()
	queue_redraw()


func _size() -> float:
	return star_size if star_size > 0.0 else float(get_theme_constant(&"star_size", &"StarRow"))


func _get_minimum_size() -> Vector2:
	var s: float = _size()
	var gap: float = get_theme_constant(&"separation", &"StarRow")
	return Vector2(s * max_stars + gap * (max_stars - 1), s)


## 0 → 1 with an overshoot: the "pop".
static func _ease_out_back(x: float) -> float:
	var c1: float = 1.9
	var c3: float = c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)


func _draw() -> void:
	var t: StringName = &"StarRow"
	var s: float = _size()
	var gap: float = get_theme_constant(&"separation", t)
	var total: float = s * max_stars + gap * (max_stars - 1)
	var x0: float = (size.x - total) * 0.5
	var on: Color = get_theme_color(&"star_on", t)
	var off: Color = get_theme_color(&"star_off", t)
	var glow: Color = get_theme_color(&"glow", t)
	for i: int in max_stars:
		var center := Vector2(x0 + i * (s + gap) + s * 0.5, size.y * 0.5)
		var slot := Rect2(center - Vector2(s, s) * 0.5, Vector2(s, s))
		# Empty slot outline (always drawn, so an earned star lands in its slot).
		var outline := IconFactory.star_points(center, s * 0.46, s * 0.19)
		outline.append(outline[0])
		draw_polyline(outline, off, maxf(1.5, s * 0.045), true)
		if i >= stars:
			continue
		var age: float = POP_TIME
		if is_revealing():
			age = _timer - reveal_interval * i
			if age < 0.0:
				continue
		var k: float = clampf(age / POP_TIME, 0.0, 1.0)
		var pop: float = _ease_out_back(k)
		if pop < 0.02:
			continue
		# Halo behind the star.
		for ring: int in 3:
			draw_circle(center, s * (0.34 + ring * 0.1) * pop, Color(glow, glow.a * (0.35 - ring * 0.1)), true, -1.0, true)
		# Burst ring while it pops.
		if k < 1.0:
			draw_arc(center, s * (0.4 + 0.5 * k), 0.0, TAU, 40, Color(on, 1.0 - k), maxf(1.0, s * 0.05 * (1.0 - k)), true)
		var flash: float = 1.0 - k
		IconFactory.draw(self, &"star", Rect2(center - slot.size * 0.5 * pop, slot.size * pop),
			on.lerp(Color.WHITE, flash), Color(on, 0.0))

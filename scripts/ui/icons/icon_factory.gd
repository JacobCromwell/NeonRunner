class_name IconFactory
extends RefCounted
## Every UI icon, drawn in code (no image files). Each icon is defined once on a 24-unit grid
## against a small Pen interface, which has two back ends:
## - draw(): CanvasItem draw_* calls, vector and crisp at any size (NeonIcon and the widgets use it);
## - texture(): the same shapes as SVG in a DPITexture, which re-rasterizes for the screen scale.
##   Use it where Godot wants a Texture2D (Button.icon, TextureRect, theme icons).
##
## Icons use one colour plus a soft fill (the colour at low alpha by default). Callers choose the
## colour: the theme's text/accent colours, or UiTheme.credit_color() for credits.

const GRID: float = 24.0
## Default line width on the 24-unit grid.
const STROKE: float = 2.0

const NAMES: Array[StringName] = [
	&"credit_1", &"credit_5", &"credit_25", &"credit_100",
	&"armor", &"shield", &"grapple", &"revive",
	&"weapon_1", &"weapon_2", &"weapon_3", &"weapon_4",
	&"claws", &"dash", &"magnet", &"slow_time",
	&"star", &"lock", &"pause", &"play", &"settings", &"back",
	&"trophy", &"leaderboard", &"store",
	&"check", &"close", &"plus", &"chevron_left", &"chevron_right", &"chevron_down", &"warning", &"info",
	&"restart", &"home", &"power", &"infinity", &"map", &"film", &"boss", &"ad", &"volume", &"keyboard", &"eye",
]
## Credit denominations, in the order of UiStyle.credit_colors.
const DENOMINATIONS: Array[int] = [1, 5, 25, 100]

static var _textures: Dictionary = {}


static func has_icon(icon: StringName) -> bool:
	return NAMES.has(icon)


## The denomination (1, 5, 25 or 100) for an amount: the nearest lower one.
static func denomination_for(amount: int) -> int:
	var best: int = DENOMINATIONS[0]
	for d: int in DENOMINATIONS:
		if amount >= d:
			best = d
	return best


## The icon for a credit denomination (1, 5, 25 or 100; other values use the nearest lower one).
static func credit_icon(denomination: int) -> StringName:
	return StringName("credit_%d" % denomination_for(denomination))


## The weapon icon for a tier (1–4, GDD §8: laser, enhanced laser, missile, heavy missile).
static func weapon_icon(tier: int) -> StringName:
	return StringName("weapon_%d" % clampi(tier, 1, 4))


## Draws `icon` centred in `rect` (square, fitted to the shorter side). Call from a _draw().
## `soft` is the fill colour; transparent means `color` at 28% alpha.
static func draw(ci: CanvasItem, icon: StringName, rect: Rect2, color: Color, soft: Color = Color(0, 0, 0, 0)) -> void:
	# Below a pixel every shape collapses to a point, which the triangulator rejects.
	if minf(rect.size.x, rect.size.y) < 1.0:
		return
	_emit(CanvasPen.new(ci, rect, color, _soft_or_default(color, soft)), icon)


## The icon as an SVG document, `size` pixels square.
static func svg(icon: StringName, size: float = 24.0, color: Color = Color.WHITE, soft: Color = Color(0, 0, 0, 0)) -> String:
	var pen := SvgPen.new(color, _soft_or_default(color, soft))
	_emit(pen, icon)
	return pen.document(size)


## A crisp texture of the icon (cached). White icons can be tinted with modulate or the Button
## icon colours.
static func texture(icon: StringName, size: float = 24.0, color: Color = Color.WHITE) -> Texture2D:
	var key: String = "%s|%s|%s" % [icon, size, color.to_html()]
	if not _textures.has(key):
		_textures[key] = DPITexture.create_from_string(svg(icon, size, color))
	return _textures[key]


## Runs the icon's shapes through `pen` (for tests and custom back ends).
static func trace(pen: Pen, icon: StringName) -> void:
	_emit(pen, icon)


static func _soft_or_default(color: Color, soft: Color) -> Color:
	return soft if soft.a > 0.0 else Color(color, color.a * 0.28)


# --- Pens ----------------------------------------------------------------------

## Receives an icon's shapes in 24-unit grid coordinates (x right, y down).
class Pen:
	extends RefCounted
	var color: Color
	var soft: Color
	var shapes: int = 0

	func stroke(_points: PackedVector2Array, _closed: bool = false, _width: float = IconFactory.STROKE) -> void:
		shapes += 1

	func fill(_points: PackedVector2Array, _use_soft: bool = false) -> void:
		shapes += 1

	func circle(_center: Vector2, _radius: float, _use_soft: bool = false) -> void:
		shapes += 1

	func ring(center: Vector2, radius: float, width: float = IconFactory.STROKE) -> void:
		stroke(IconFactory.arc_points(center, radius, 0.0, TAU, 40), true, width)

	func arc(center: Vector2, radius: float, from_angle: float, to_angle: float, width: float = IconFactory.STROKE) -> void:
		stroke(IconFactory.arc_points(center, radius, from_angle, to_angle, 24), false, width)

	## A filled shape with a soft interior and a solid outline: the look of most icons.
	func shape(points: PackedVector2Array, width: float = IconFactory.STROKE) -> void:
		fill(points, true)
		stroke(points, true, width)


class CanvasPen:
	extends Pen
	var ci: CanvasItem
	var origin: Vector2
	var unit: float

	func _init(canvas_item: CanvasItem, rect: Rect2, main: Color, soft_fill: Color) -> void:
		ci = canvas_item
		color = main
		soft = soft_fill
		unit = minf(rect.size.x, rect.size.y) / IconFactory.GRID
		origin = rect.position + (rect.size - Vector2.ONE * IconFactory.GRID * unit) * 0.5

	func _map(points: PackedVector2Array) -> PackedVector2Array:
		var out := PackedVector2Array()
		out.resize(points.size())
		for i: int in points.size():
			out[i] = origin + points[i] * unit
		return out

	func stroke(points: PackedVector2Array, closed: bool = false, width: float = IconFactory.STROKE) -> void:
		shapes += 1
		var pts := _map(points)
		var w: float = width * unit
		if closed:
			pts.append(pts[0])
			# Round the closing corner, where the polyline's two ends meet.
			ci.draw_circle(pts[0], w * 0.5, color, true, -1.0, true)
		ci.draw_polyline(pts, color, w, true)

	func fill(points: PackedVector2Array, use_soft: bool = false) -> void:
		shapes += 1
		var c: Color = soft if use_soft else color
		var pts := _map(points)
		ci.draw_colored_polygon(pts, c)
		if not use_soft:
			# Polygons aren't antialiased; a hairline around the edge smooths it.
			pts.append(pts[0])
			ci.draw_polyline(pts, c, 1.0, true)

	func circle(center: Vector2, radius: float, use_soft: bool = false) -> void:
		shapes += 1
		ci.draw_circle(origin + center * unit, radius * unit, soft if use_soft else color, true, -1.0, true)


class SvgPen:
	extends Pen
	var parts: PackedStringArray = []

	func _init(main: Color, soft_fill: Color) -> void:
		color = main
		soft = soft_fill

	func document(size: float) -> String:
		return ('<svg xmlns="http://www.w3.org/2000/svg" width="%s" height="%s" viewBox="0 0 24 24">%s</svg>'
			% [size, size, "".join(parts)])

	func stroke(points: PackedVector2Array, closed: bool = false, width: float = IconFactory.STROKE) -> void:
		shapes += 1
		parts.append('<path d="%s" fill="none" stroke="#%s" stroke-opacity="%.3f" stroke-width="%.2f" stroke-linejoin="round"/>'
			% [_path(points, closed), color.to_html(false), color.a, width])

	func fill(points: PackedVector2Array, use_soft: bool = false) -> void:
		shapes += 1
		var c: Color = soft if use_soft else color
		parts.append('<path d="%s" fill="#%s" fill-opacity="%.3f"/>' % [_path(points, true), c.to_html(false), c.a])

	func circle(center: Vector2, radius: float, use_soft: bool = false) -> void:
		shapes += 1
		var c: Color = soft if use_soft else color
		parts.append('<circle cx="%.2f" cy="%.2f" r="%.2f" fill="#%s" fill-opacity="%.3f"/>'
			% [center.x, center.y, radius, c.to_html(false), c.a])

	func _path(points: PackedVector2Array, closed: bool) -> String:
		var d: PackedStringArray = []
		for i: int in points.size():
			d.append("%s%.2f %.2f" % ["M" if i == 0 else "L", points[i].x, points[i].y])
		if closed:
			d.append("Z")
		return " ".join(d)


# --- Geometry helpers ------------------------------------------------------------

## Flat [x0, y0, x1, y1, ...] to points.
static func pts(flat: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in range(0, flat.size() - 1, 2):
		out.append(Vector2(flat[i], flat[i + 1]))
	return out


## Points along an arc; angles in radians, 0 = right, growing clockwise (y is down).
static func arc_points(center: Vector2, radius: float, from_angle: float, to_angle: float, segments: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in segments + 1:
		var a: float = lerpf(from_angle, to_angle, float(i) / segments)
		out.append(center + Vector2(cos(a), sin(a)) * radius)
	return out


static func regular_polygon(center: Vector2, radius: float, sides: int, rotation: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in sides:
		var a: float = rotation + TAU * i / sides
		out.append(center + Vector2(cos(a), sin(a)) * radius)
	return out


static func star_points(center: Vector2, outer: float, inner: float, points: int = 5) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in points * 2:
		var a: float = -PI / 2.0 + PI * i / points
		out.append(center + Vector2(cos(a), sin(a)) * (outer if i % 2 == 0 else inner))
	return out


## A pill (a rectangle with fully rounded ends) as one polygon, in any coordinate space.
static func pill_points(rect: Rect2, inset: float = 0.0) -> PackedVector2Array:
	var r: float = minf(rect.size.x, rect.size.y) * 0.5
	var cy: float = rect.position.y + rect.size.y * 0.5
	var arcs := arc_points(Vector2(rect.end.x - r, cy), r - inset, -PI / 2.0, PI / 2.0, 16)
	arcs.append_array(arc_points(Vector2(rect.position.x + r, cy), r - inset, PI / 2.0, PI * 1.5, 16))
	# A pill as wide as it is tall is a circle: its two arcs meet, so drop the doubled points
	# (the triangulator rejects them).
	var points := PackedVector2Array()
	for p: Vector2 in arcs:
		if points.is_empty() or points[points.size() - 1].distance_to(p) > 0.01:
			points.append(p)
	if points.size() > 1 and points[0].distance_to(points[points.size() - 1]) <= 0.01:
		points.remove_at(points.size() - 1)
	return points


static func _mirror_x(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in points:
		out.append(Vector2(GRID - p.x, p.y))
	return out


static func _mirror_y(points: PackedVector2Array, axis_y: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in points:
		out.append(Vector2(p.x, 2.0 * axis_y - p.y))
	return out


## A tapered slash (pointed at both ends) along a quadratic curve a → b bending towards c.
static func _slash(a: Vector2, c: Vector2, b: Vector2, half_width: float) -> PackedVector2Array:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var steps: int = 12
	for i: int in steps + 1:
		var t: float = float(i) / steps
		var p: Vector2 = a.lerp(c, t).lerp(c.lerp(b, t), t)
		var tangent: Vector2 = ((c - a) * (1.0 - t) + (b - c) * t).normalized()
		var n := Vector2(-tangent.y, tangent.x) * half_width * sin(PI * t)
		left.append(p + n)
		right.append(p - n)
	right.reverse()
	left.append_array(right.slice(1, right.size() - 1))
	return left


# --- Icons (24-unit grid) --------------------------------------------------------

static func _emit(p: Pen, icon: StringName) -> void:
	match icon:
		&"credit_1": _credit_1(p)
		&"credit_5": _credit_5(p)
		&"credit_25": _credit_25(p)
		&"credit_100": _credit_100(p)
		&"armor": _armor(p)
		&"shield": _shield(p)
		&"grapple": _grapple(p)
		&"revive": _revive(p)
		&"weapon_1": _weapon_1(p)
		&"weapon_2": _weapon_2(p)
		&"weapon_3": _weapon_3(p)
		&"weapon_4": _weapon_4(p)
		&"claws": _claws(p)
		&"dash": _dash(p)
		&"magnet": _magnet(p)
		&"slow_time": _slow_time(p)
		&"star": p.fill(star_points(Vector2(12, 12.9), 10.5, 4.3))
		&"lock": _lock(p)
		&"pause":
			p.fill(pts([6.5, 4.5, 10, 4.5, 10, 19.5, 6.5, 19.5]))
			p.fill(pts([14, 4.5, 17.5, 4.5, 17.5, 19.5, 14, 19.5]))
		&"play": p.fill(pts([7.5, 4.5, 19.5, 12, 7.5, 19.5]))
		&"settings": _settings(p)
		&"back":
			p.stroke(pts([19.5, 12, 5.5, 12]), false, 2.2)
			p.stroke(pts([11, 5.5, 4.5, 12, 11, 18.5]), false, 2.2)
		&"trophy": _trophy(p)
		&"leaderboard": _leaderboard(p)
		&"store": _store(p)
		&"check": p.stroke(pts([4.5, 12.5, 9.5, 17.5, 19.5, 6.5]), false, 2.6)
		&"close":
			p.stroke(pts([6, 6, 18, 18]), false, 2.4)
			p.stroke(pts([18, 6, 6, 18]), false, 2.4)
		&"plus":
			p.stroke(pts([12, 5, 12, 19]), false, 2.4)
			p.stroke(pts([5, 12, 19, 12]), false, 2.4)
		&"chevron_left": p.stroke(pts([15, 5, 8, 12, 15, 19]), false, 2.4)
		&"chevron_right": p.stroke(pts([9, 5, 16, 12, 9, 19]), false, 2.4)
		&"chevron_down": p.stroke(pts([5, 9, 12, 16, 19, 9]), false, 2.4)
		&"warning":
			p.shape(pts([12, 3, 21.5, 20, 2.5, 20]), 2.0)
			p.stroke(pts([12, 9, 12, 14.2]), false, 2.2)
			p.circle(Vector2(12, 17), 1.3)
		&"info":
			p.ring(Vector2(12, 12), 9.5, 2.0)
			p.circle(Vector2(12, 7.4), 1.3)
			p.stroke(pts([12, 10.5, 12, 17]), false, 2.2)
		&"restart": _restart(p)
		&"home":
			p.shape(pts([6, 11, 12, 5.5, 18, 11, 18, 20, 13.8, 20, 13.8, 15, 10.2, 15, 10.2, 20, 6, 20]), 1.8)
			p.stroke(pts([3, 12.5, 12, 4, 21, 12.5]), false, 2.0)
		&"power":
			p.arc(Vector2(12, 12.5), 7.8, -PI * 0.3, PI * 1.3, 2.2)
			p.stroke(pts([12, 3, 12, 11.5]), false, 2.2)
		&"infinity": _infinity(p)
		&"map":
			p.shape(pts([3, 5.5, 9, 3.5, 15, 5.5, 21, 3.5, 21, 18.5, 15, 20.5, 9, 18.5, 3, 20.5]), 1.8)
			p.stroke(pts([9, 3.5, 9, 18.5]), false, 1.4)
			p.stroke(pts([15, 5.5, 15, 20.5]), false, 1.4)
		&"film": _film(p)
		&"boss": _boss(p)
		&"ad":
			p.shape(pts([3, 4.5, 21, 4.5, 21, 16.5, 3, 16.5]), 1.8)
			p.stroke(pts([12, 16.5, 12, 20]), false, 1.6)
			p.stroke(pts([8, 20.2, 16, 20.2]), false, 1.8)
			p.fill(pts([10, 7.8, 15.2, 10.5, 10, 13.2]))
		&"volume":
			p.shape(pts([3, 9, 7, 9, 12, 4.5, 12, 19.5, 7, 15, 3, 15]), 1.8)
			p.arc(Vector2(12, 12), 4.2, -0.8, 0.8, 1.7)
			p.arc(Vector2(12, 12), 7.8, -0.75, 0.75, 1.7)
		&"keyboard": _keyboard(p)
		&"eye": _eye(p)
		_:
			# Unknown name: a crossed box, visible but obviously wrong.
			p.stroke(pts([4, 4, 20, 4, 20, 20, 4, 20]), true, 1.5)
			p.stroke(pts([4, 4, 20, 20]), false, 1.5)


## 1: a small hexagonal chip with one notch.
static func _credit_1(p: Pen) -> void:
	p.shape(regular_polygon(Vector2(12, 12), 8.0, 6, -PI / 2.0), 1.8)
	p.stroke(pts([12, 8.6, 12, 15.4]), false, 2.2)


## 5: a larger chip with an inner ring.
static func _credit_5(p: Pen) -> void:
	p.shape(regular_polygon(Vector2(12, 12), 10.0, 6, -PI / 2.0), 1.8)
	p.stroke(regular_polygon(Vector2(12, 12), 5.2, 6, -PI / 2.0), true, 1.6)
	p.circle(Vector2(12, 12), 1.6)


## 25: a diamond crystal.
static func _credit_25(p: Pen) -> void:
	p.shape(pts([12, 2, 20, 12, 12, 22, 4, 12]), 1.8)
	p.stroke(pts([4, 12, 20, 12]), false, 1.2)
	p.stroke(pts([12, 2, 9.4, 12, 12, 22]), false, 1.2)
	p.stroke(pts([12, 2, 14.6, 12, 12, 22]), false, 1.2)


## 100: a cut gem with a sparkle.
static func _credit_100(p: Pen) -> void:
	p.shape(pts([7.5, 4.5, 15.5, 4.5, 20, 9.5, 11.5, 21, 3, 9.5]), 1.8)
	p.stroke(pts([3, 9.5, 20, 9.5]), false, 1.2)
	p.stroke(pts([7.5, 4.5, 9.6, 9.5, 11.5, 21]), false, 1.2)
	p.stroke(pts([15.5, 4.5, 13.4, 9.5, 11.5, 21]), false, 1.2)
	p.fill(star_points(Vector2(19.6, 3.6), 3.2, 0.9, 4))


static func _armor(p: Pen) -> void:
	p.shape(pts([8, 3, 12, 5.5, 16, 3, 20.5, 5, 20.5, 10, 18.2, 11.2, 18.2, 19, 12, 21.5, 5.8, 19,
		5.8, 11.2, 3.5, 10, 3.5, 5]), 1.8)
	p.stroke(pts([12, 5.5, 12, 21.5]), false, 1.3)
	p.stroke(pts([7.5, 14, 16.5, 14]), false, 1.3)
	p.stroke(pts([8, 17.4, 16, 17.4]), false, 1.3)


static func _shield(p: Pen) -> void:
	var outer := pts([12, 2.5, 19.5, 5, 19.5, 11, 18.8, 14.2, 17, 17.2, 14.6, 19.8, 12, 21.5,
		9.4, 19.8, 7, 17.2, 5.2, 14.2, 4.5, 11, 4.5, 5])
	p.shape(outer, 1.9)
	var inner := PackedVector2Array()
	for v: Vector2 in outer:
		inner.append(Vector2(12, 11.5) + (v - Vector2(12, 11.5)) * 0.55)
	p.stroke(inner, true, 1.3)


## Hooks on top of the shaft curving back down, and a rope trailing from the bottom: not a
## trident (prongs pointing up) and not an anchor (crossbar, flukes at the bottom).
static func _grapple(p: Pen) -> void:
	var hook := pts([12, 5.4, 9.4, 3.6, 6.6, 3.8, 4.8, 5.8, 4.6, 8.6, 6.0, 10.8])
	p.stroke(hook, false, 1.9)
	p.stroke(_mirror_x(hook), false, 1.9)
	p.stroke(pts([12, 5.4, 10.4, 8.0, 10.0, 11.2]), false, 1.7)
	p.stroke(pts([12, 17.6, 12, 4.4]), false, 2.1)
	p.ring(Vector2(12, 19.2), 1.6, 1.4)
	p.stroke(pts([10.9, 20.4, 9.4, 21.9, 7.4, 21.6, 5.6, 22.5, 3.2, 21.8]), false, 1.4)


## A heart with a pulse line: the revive item.
static func _revive(p: Pen) -> void:
	var heart := PackedVector2Array()
	for i: int in 48:
		var t: float = TAU * i / 48.0
		var x: float = 16.0 * pow(sin(t), 3.0)
		var y: float = 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		heart.append(Vector2(12.0 + x * 0.56, 10.6 - y * 0.58))
	p.shape(heart, 1.8)
	p.stroke(pts([5.5, 11.8, 8.8, 11.8, 10.2, 8.8, 12.6, 15.2, 14.2, 10.6, 15.2, 11.8, 18.5, 11.8]), false, 1.5)


## Tier 1: laser.
static func _weapon_1(p: Pen) -> void:
	p.shape(pts([3, 10, 9.5, 10, 11.5, 11.2, 11.5, 12.8, 9.5, 14, 3, 14]), 1.6)
	p.stroke(pts([5, 14, 5, 17.5]), false, 1.6)
	p.stroke(pts([13.5, 12, 20.4, 12]), false, 1.7)
	p.circle(Vector2(20.8, 12), 1.8)


## Tier 2: enhanced laser (thicker beam).
static func _weapon_2(p: Pen) -> void:
	p.shape(pts([2.5, 9, 9.5, 9, 12, 10.5, 12, 13.5, 9.5, 15, 2.5, 15]), 1.6)
	p.stroke(pts([5, 15, 5, 18.5]), false, 1.6)
	p.stroke(pts([13.8, 12, 20.2, 12]), false, 3.2)
	p.circle(Vector2(20.8, 12), 2.3)
	p.stroke(pts([15, 8.8, 19.5, 8.8]), false, 1.0)
	p.stroke(pts([15, 15.2, 19.5, 15.2]), false, 1.0)


## Tier 3: missile.
static func _weapon_3(p: Pen) -> void:
	p.shape(pts([21, 12, 17, 9.8, 7, 9.8, 7, 14.2, 17, 14.2]), 1.6)
	p.stroke(pts([17, 9.8, 17, 14.2]), false, 1.2)
	var fin := pts([10, 9.8, 6.8, 6.2, 4.8, 6.2, 6.2, 9.8])
	p.shape(fin, 1.4)
	p.shape(_mirror_y(fin, 12.0), 1.4)
	p.stroke(pts([5, 12, 2, 12]), false, 1.6)


## Tier 4: heavy missile with splash damage.
static func _weapon_4(p: Pen) -> void:
	p.shape(pts([18, 12, 14.5, 8.8, 5.5, 8.8, 5.5, 15.2, 14.5, 15.2]), 1.7)
	p.stroke(pts([12.2, 8.8, 12.2, 15.2]), false, 1.6)
	var fin := pts([8.8, 8.8, 5.2, 4.2, 2.8, 4.2, 4.4, 8.8])
	p.shape(fin, 1.4)
	p.shape(_mirror_y(fin, 12.0), 1.4)
	p.arc(Vector2(18, 12), 3.0, -0.9, 0.9, 1.4)
	p.arc(Vector2(18, 12), 5.4, -0.75, 0.75, 1.4)


static func _claws(p: Pen) -> void:
	for i: int in 3:
		var dx: float = (i - 1) * 5.2
		p.fill(_slash(Vector2(15.2 + dx, 2.5), Vector2(14.6 + dx, 13.5), Vector2(8.2 + dx, 21.5), 1.5))


static func _dash(p: Pen) -> void:
	p.stroke(pts([9.5, 6, 15.5, 12, 9.5, 18]), false, 2.4)
	p.stroke(pts([14.5, 6, 20.5, 12, 14.5, 18]), false, 2.4)
	p.stroke(pts([3, 8.5, 7, 8.5]), false, 1.6)
	p.stroke(pts([1.5, 12, 8, 12]), false, 1.6)
	p.stroke(pts([3, 15.5, 7, 15.5]), false, 1.6)


static func _magnet(p: Pen) -> void:
	# The U: down the left leg, round the bottom (angle PI to 0 passes through "down"), up the right.
	var u := pts([6.5, 7.6])
	u.append_array(arc_points(Vector2(12, 12.5), 5.5, PI, 0.0, 16))
	u.append(Vector2(17.5, 7.6))
	p.stroke(u, false, 3.0)
	p.fill(pts([4.7, 3, 8.3, 3, 8.3, 6.6, 4.7, 6.6]))
	p.fill(pts([15.7, 3, 19.3, 3, 19.3, 6.6, 15.7, 6.6]))


static func _slow_time(p: Pen) -> void:
	p.stroke(pts([6, 3.2, 18, 3.2]), false, 2.0)
	p.stroke(pts([6, 20.8, 18, 20.8]), false, 2.0)
	p.stroke(pts([7.6, 3.6, 16.4, 3.6, 12.8, 12, 16.4, 20.4, 7.6, 20.4, 11.2, 12]), true, 1.7)
	p.fill(pts([9.4, 19.8, 14.6, 19.8, 12, 16.6]))
	p.fill(pts([9.6, 5.8, 14.4, 5.8, 12, 9.6]), true)


static func _lock(p: Pen) -> void:
	var shackle := pts([8, 11])
	shackle.append_array(arc_points(Vector2(12, 7.6), 4.0, PI, TAU, 16))
	shackle.append(Vector2(16, 11))
	p.stroke(shackle, false, 2.0)
	p.shape(pts([5, 10.5, 19, 10.5, 19, 21, 5, 21]), 1.8)
	p.circle(Vector2(12, 14.8), 1.7)
	p.stroke(pts([12, 15.6, 12, 18.4]), false, 1.7)


static func _settings(p: Pen) -> void:
	var gear := PackedVector2Array()
	var teeth: int = 8
	var span: float = TAU / teeth
	for k: int in teeth:
		var a: float = k * span - PI / 2.0
		gear.append(Vector2(12, 12) + Vector2.from_angle(a - span * 0.30) * 7.4)
		gear.append(Vector2(12, 12) + Vector2.from_angle(a - span * 0.15) * 10.0)
		gear.append(Vector2(12, 12) + Vector2.from_angle(a + span * 0.15) * 10.0)
		gear.append(Vector2(12, 12) + Vector2.from_angle(a + span * 0.30) * 7.4)
	p.shape(gear, 1.8)
	p.ring(Vector2(12, 12), 3.0, 1.8)


static func _trophy(p: Pen) -> void:
	p.shape(pts([6.5, 3.5, 17.5, 3.5, 17.3, 8.2, 16, 11, 14, 12.9, 12, 13.6, 10, 12.9, 8, 11,
		6.7, 8.2]), 1.8)
	var handle := pts([6.6, 5.4, 3.8, 5.4, 3.8, 8, 5, 10, 7.4, 11.2])
	p.stroke(handle, false, 1.6)
	p.stroke(_mirror_x(handle), false, 1.6)
	p.stroke(pts([12, 13.6, 12, 17.5]), false, 2.0)
	p.shape(pts([7.5, 17.5, 16.5, 17.5, 17.5, 21, 6.5, 21]), 1.6)


static func _leaderboard(p: Pen) -> void:
	p.shape(pts([3, 11, 9, 11, 9, 21, 3, 21]), 1.7)
	p.shape(pts([15, 14, 21, 14, 21, 21, 15, 21]), 1.7)
	p.shape(pts([9, 6, 15, 6, 15, 21, 9, 21]), 1.7)
	p.fill(star_points(Vector2(12, 11.6), 2.6, 1.1))


## A circular "again" arrow: most of a circle, with an arrowhead at its end.
static func _restart(p: Pen) -> void:
	var start: float = -PI * 0.3
	var end: float = start + PI * 1.62
	var c := Vector2(12, 12.5)
	var r: float = 7.6
	p.arc(c, r, start, end, 2.2)
	var tip: Vector2 = c + Vector2.from_angle(end) * r
	var along := Vector2(-sin(end), cos(end))
	var out := Vector2.from_angle(end)
	p.fill(PackedVector2Array([tip + along * 3.4, tip + out * 3.0, tip - out * 3.0]))


static func _infinity(p: Pen) -> void:
	var loop := PackedVector2Array()
	for i: int in 48:
		var t: float = TAU * i / 48.0
		var d: float = 1.0 + sin(t) * sin(t)
		loop.append(Vector2(12.0 + 9.2 * cos(t) / d, 12.0 + 9.2 * sin(t) * cos(t) / d))
	p.stroke(loop, true, 2.2)


## A film frame with sprocket holes and a play mark: the cinematic slots.
static func _film(p: Pen) -> void:
	p.stroke(pts([3.5, 3.5, 20.5, 3.5, 20.5, 20.5, 3.5, 20.5]), true, 1.8)
	p.fill(pts([7.2, 6.5, 16.8, 6.5, 16.8, 17.5, 7.2, 17.5]), true)
	for y: float in [6.2, 10.1, 13.9, 17.8]:
		p.circle(Vector2(5.35, y), 0.85)
		p.circle(Vector2(18.65, y), 0.85)
	p.fill(pts([10.4, 9.2, 14.6, 12, 10.4, 14.8]))


## A horned mask with angry eyes: the boss slots.
static func _boss(p: Pen) -> void:
	var horn := pts([8.2, 9.2, 5.6, 6.8, 4.4, 2.8])
	p.stroke(horn, false, 1.9)
	p.stroke(_mirror_x(horn), false, 1.9)
	p.shape(pts([6.2, 8.6, 17.8, 8.6, 18.8, 13.8, 15.6, 20, 8.4, 20, 5.2, 13.8]), 1.8)
	var eye := pts([7.8, 12, 11, 13.2, 8.2, 14.6])
	p.fill(eye)
	p.fill(_mirror_x(eye))
	p.stroke(pts([9.4, 17.2, 10.7, 16.2, 12, 17.2, 13.3, 16.2, 14.6, 17.2]), false, 1.3)


static func _keyboard(p: Pen) -> void:
	p.shape(pts([2.5, 6, 21.5, 6, 21.5, 18, 2.5, 18]), 1.8)
	for row: int in 2:
		for col: int in 5:
			p.circle(Vector2(5.8 + col * 3.1, 9.2 + row * 2.9), 0.85)
	p.stroke(pts([8, 15.2, 16, 15.2]), false, 1.6)


## Two lid arcs from circles above and below, meeting at the eye's corners.
static func _eye(p: Pen) -> void:
	var r: float = 13.0
	var d: float = 9.5
	var a: float = atan2(d, sqrt(r * r - d * d))
	var almond := arc_points(Vector2(12, 12 + d), r, -PI + a, -a, 14)
	almond.append_array(arc_points(Vector2(12, 12 - d), r, a, PI - a, 14).slice(1, 14))
	p.shape(almond, 1.8)
	p.circle(Vector2(12, 12), 3.2)


static func _store(p: Pen) -> void:
	p.shape(pts([5, 8, 19, 8, 20, 21, 4, 21]), 1.8)
	p.stroke(arc_points(Vector2(12, 8.5), 4.0, PI, TAU, 16), false, 1.8)
	p.stroke(pts([9, 12.5, 15, 12.5]), false, 1.4)

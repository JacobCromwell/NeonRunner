class_name NeonIcon
extends Control
## One IconFactory icon, drawn with vector calls: crisp at any size. It fills its rect (kept square
## and centred); its minimum size is `icon_size`, or the theme's icon size when that is 0.
##   var icon := NeonIcon.make(&"shield", 32)

## An IconFactory name (IconFactory.NAMES).
@export var icon_name: StringName = &"star":
	set(value):
		icon_name = value
		queue_redraw()
## Transparent = the theme's text colour.
@export var color: Color = Color(0, 0, 0, 0):
	set(value):
		color = value
		queue_redraw()
## The soft fill; transparent = `color` at low alpha.
@export var soft: Color = Color(0, 0, 0, 0):
	set(value):
		soft = value
		queue_redraw()
@export_range(0.0, 256.0, 1.0, "suffix:px") var icon_size: float = 0.0:
	set(value):
		icon_size = value
		update_minimum_size()


static func make(icon: StringName, size_px: float = 0.0, tint: Color = Color(0, 0, 0, 0)) -> NeonIcon:
	var n := NeonIcon.new()
	n.icon_name = icon
	n.icon_size = size_px
	n.color = tint
	return n


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		_ensure_theme.call_deferred()
	elif what == NOTIFICATION_THEME_CHANGED:
		update_minimum_size()
		queue_redraw()


func _ensure_theme() -> void:
	UiTheme.ensure(self)


func _get_minimum_size() -> Vector2:
	var s: float = icon_size if icon_size > 0.0 else float(get_theme_constant(&"icon_size", UiTheme.NEON))
	return Vector2(s, s)


func _draw() -> void:
	var tint: Color = color if color.a > 0.0 else get_theme_color(&"text", UiTheme.NEON)
	IconFactory.draw(self, icon_name, Rect2(Vector2.ZERO, size), tint, soft)

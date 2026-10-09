class_name GoldenConvergenceMagnateMarker
extends Control
## The Magnate's marker (GDD §10, proposed: "behind the runner, his shadow and a marker at the screen's bottom
## edge show his lane, as with the Enforcer Truck"; the Pounce: "with a roar, his marker turns red"): a small
## chevron at the bottom edge of the screen, under the floor of his lane near the runner (EnforcerTruckMarker's
## way), in the cult's warm white while he only follows, turning the enemy attacks' red as a Pounce's warning
## begins (`alarm`, 0-1; steady: it never flashes, Reduced flashing or not). Two claw marks over it tell it from
## the Enforcer's. GoldenConvergenceMagnate moves it (lane_x, his world x) and fades it in while he's behind the
## runner; it draws itself from the camera each frame, under the HUD (its own CanvasLayer).

## The chevron's size at the UI's base scale (UiTheme.px), and its gap from the bottom edge.
const WIDTH: float = 46.0
const HEIGHT: float = 22.0
const BOTTOM_MARGIN: float = 10.0
## Its point on the floor: this far behind the runner, in his lane (near the bottom of the view).
const BEHIND: float = 3.0
## Its colours: the cult's warm white (his feed's), and the warning red (BossProps.WARNING_COLOR).
const CALM := Color(1.0, 0.93, 0.82)
const ALARM := Color(1.0, 0.12, 0.08)

## His world x, and the runner's world z (the marker sits under the floor of his lane there).
var lane_x: float = 0.0
var runner_z: float = 0.0
## 0 calm (he follows) to 1 red (a Pounce's warning).
var alarm: float = 0.0
## 0 (hidden) to 1 (shown).
var shown: float = 0.0
## Where it was drawn last (screen pixels; tests and the showcase read it).
var screen_point := Vector2.ZERO


func _init() -> void:
	name = "MagnateMarker"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


## Its colour now (tests).
func color() -> Color:
	return CALM.lerp(ALARM, clampf(alarm, 0.0, 1.0))


## Where its chevron's tip goes on screen: under the floor of his lane near the runner (projected by the
## current camera), at the bottom edge. Without a camera (headless), the middle of the bottom edge.
func place() -> Vector2:
	var view: Vector2 = get_viewport_rect().size
	var x: float = view.x * 0.5
	var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera != null:
		var point := Vector3(lane_x, 0.0, runner_z + BEHIND)
		if not camera.is_position_behind(point):
			x = camera.unproject_position(point).x
	var s: float = UiTheme.px(1.0)
	x = clampf(x, WIDTH * s, view.x - WIDTH * s)
	screen_point = Vector2(x, view.y - (BOTTOM_MARGIN + HEIGHT) * s)
	return screen_point


func _draw() -> void:
	if shown <= 0.01:
		return
	var tip: Vector2 = place()
	var s: float = UiTheme.px(1.0)
	var w: float = WIDTH * s * 0.5
	var h: float = HEIGHT * s
	var a: float = clampf(shown, 0.0, 1.0)
	var c: Color = color()
	var dark := Color(0.02, 0.02, 0.03, 0.75 * a)
	# A dark backing, then the chevron pointing up, and two claw marks over it.
	draw_colored_polygon(PackedVector2Array([tip + Vector2(0.0, -3.0 * s), tip + Vector2(w + 4.0 * s, h + 2.0 * s),
		tip + Vector2(0.0, h * 0.55), tip + Vector2(-w - 4.0 * s, h + 2.0 * s)]), dark)
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(w, h), tip + Vector2(0.0, h * 0.42), tip + Vector2(-w, h)]),
		Color(c, a))
	for k: int in 2:
		var x0: float = (float(k) - 0.5) * 9.0 * s
		draw_line(tip + Vector2(x0 - 2.0 * s, -15.0 * s), tip + Vector2(x0 + 2.0 * s, -6.0 * s), Color(c, a), 2.5 * s, true)

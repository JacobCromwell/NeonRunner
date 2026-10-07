class_name EnforcerTruckMarker
extends Control
## The Enforcer Truck's marker (GDD §9.13: "a small marker at the screen's bottom edge shows its lane"): a
## small chevron at the bottom edge of the screen, under the floor of the truck's lane, in its light bar's
## red and blue (they take turns with the light bar; with Reduced flashing both halves stay lit, steady). A
## dot over it for each rider aboard. The truck that owns it moves it (lane_x, its own world x) and shows it
## while it chases; it draws itself from the camera each frame, under the HUD (its own CanvasLayer).
## Two filled polygons, a few circles: a handful of canvas commands a frame.

## The chevron's size at the UI's base scale (UiTheme.px), and its gap from the bottom edge.
const WIDTH: float = 44.0
const HEIGHT: float = 22.0
const BOTTOM_MARGIN: float = 10.0
## Its point on the floor: this far behind the runner, in the truck's lane (near the bottom of the view).
const BEHIND: float = 3.0

## The truck's world x, and the runner's world z (the marker sits under the floor of the truck's lane there).
var lane_x: float = 0.0
var runner_z: float = 0.0
## Riders aboard (a dot each).
var riders: int = 0
## Which half is lit (0 red, 1 blue), or -1: both, steady (Reduced flashing).
var phase: int = 0
## 0 (hidden) to 1 (shown): it fades in as the truck arrives and out as it leaves.
var shown: float = 0.0
## Where it was drawn last (screen pixels; tests and the showcase read it).
var screen_point := Vector2.ZERO


func _init() -> void:
	name = "EnforcerTruckMarker"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


## Where its chevron's tip goes on screen: under the floor of the truck's lane near the runner (projected
## by the current camera), at the bottom edge. Without a camera (headless), the middle of the bottom edge.
func place() -> Vector2:
	var view: Vector2 = get_viewport_rect().size
	var x: float = view.x * 0.5
	var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera != null:
		var point := Vector3(lane_x, 0.0, runner_z + BEHIND)
		if not camera.is_position_behind(point):
			x = camera.unproject_position(point).x
	var s: float = _scale()
	x = clampf(x, WIDTH * s, view.x - WIDTH * s)
	screen_point = Vector2(x, view.y - (BOTTOM_MARGIN + HEIGHT) * s)
	return screen_point


func _draw() -> void:
	if shown <= 0.01:
		return
	var tip: Vector2 = place()
	var s: float = _scale()
	var w: float = WIDTH * s * 0.5
	var h: float = HEIGHT * s
	var a: float = clampf(shown, 0.0, 1.0)
	var red := Color(EnforcerTruckModel.BAR_RED, a * (1.0 if phase != 1 else 0.45))
	var blue := Color(EnforcerTruckModel.BAR_BLUE.lightened(0.2), a * (1.0 if phase != 0 else 0.45))
	var dark := Color(0.02, 0.02, 0.04, 0.75 * a)
	# A dark backing, then the chevron's two halves: red on the left, blue on the right, pointing up.
	draw_colored_polygon(PackedVector2Array([tip + Vector2(0.0, -3.0 * s), tip + Vector2(w + 4.0 * s, h + 2.0 * s),
		tip + Vector2(0.0, h * 0.55), tip + Vector2(-w - 4.0 * s, h + 2.0 * s)]), dark)
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(0.0, h * 0.42), tip + Vector2(-w, h)]), red)
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(w, h), tip + Vector2(0.0, h * 0.42)]), blue)
	for i: int in riders:
		draw_circle(tip + Vector2((i - (riders - 1) * 0.5) * 9.0 * s, -9.0 * s), 3.0 * s, Color(0.85, 0.9, 1.0, a))


func _scale() -> float:
	return UiTheme.px(1.0)

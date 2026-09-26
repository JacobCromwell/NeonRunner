extends Node
## Touch layer (autoload "TouchInput"): turns swipes and taps into named input actions,
## so gameplay code never reads touch events. Swipe left/right = move, up = jump,
## down = slide, tap = dash (GDD §3). Mouse drags count as touches on desktop for testing.
## A swipe fires as soon as the finger has moved far enough, not on release, so it feels immediate.

const TUNING_PATH: String = "res://data/tuning/movement.tres"

## Off in menus (App switches it on only during runs), so taps on buttons never fire gameplay actions.
var enabled: bool = true

var _tuning: MovementTuning
var _finger: int = -1
var _start_pos: Vector2 = Vector2.ZERO
var _start_time: float = 0.0
var _fired: bool = false


## The action for a drag of `delta` pixels, or &"" while it is still too short to count.
static func swipe_action(delta: Vector2, threshold: float) -> StringName:
	if delta.length() < threshold:
		return &""
	if absf(delta.x) > absf(delta.y):
		return &"move_right" if delta.x > 0.0 else &"move_left"
	return &"slide" if delta.y > 0.0 else &"jump"


## Whether a released touch that moved `moved` pixels in `duration` seconds is a tap.
static func is_tap(moved: float, duration: float, threshold: float, tap_max_time: float) -> bool:
	return duration <= tap_max_time and moved < threshold * 0.5


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_tuning = load(TUNING_PATH) as MovementTuning


func _input(event: InputEvent) -> void:
	if not enabled:
		_finger = -1
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _finger == -1:
			_finger = touch.index
			_start_pos = touch.position
			_start_time = _now()
			_fired = false
		elif not touch.pressed and touch.index == _finger:
			var moved: float = (touch.position - _start_pos).length()
			if not _fired and is_tap(moved, _now() - _start_time, _swipe_threshold(), _tuning.tap_max_time):
				_fire(&"dash")
			_finger = -1
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index != _finger or _fired:
			return
		var action: StringName = swipe_action(drag.position - _start_pos, _swipe_threshold())
		if action != &"":
			_fired = true
			_fire(action)


func _swipe_threshold() -> float:
	var size: Vector2 = get_viewport().get_visible_rect().size
	return minf(size.x, size.y) * _tuning.swipe_min_distance


func _fire(action: StringName) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

class_name KeyBindButton
extends NeonButton
## Shows the key bound to an input action. Pressing it starts listening: the next key pressed is
## emitted as rebind_requested(action, event), and Esc (or a click elsewhere) cancels. One key per
## binding, like the defaults in project.godot: Shift, Ctrl and Alt count as keys (dash is Shift).
## It doesn't change the InputMap itself: the settings screen applies, checks for clashes and saves.
##   var jump_key := KeyBindButton.for_action(&"jump")
##   jump_key.rebind_requested.connect(_on_rebind)

signal rebind_requested(action: StringName, event: InputEvent)
signal listening_changed(listening: bool)

const WAITING_TEXT: String = "PRESS A KEY"

@export var action: StringName = &"":
	set(v):
		action = v
		refresh()
## Which of the action's key bindings this button shows (0 = the first); -1 shows them all
## ("UP / SPACE"), for settings where a new key replaces all of an action's keys.
@export var binding_index: int = 0:
	set(v):
		binding_index = v
		refresh()

var listening: bool = false
var _pulse: float = 0.0
var _ring: StyleBoxFlat


static func for_action(action_name: StringName, index: int = 0) -> KeyBindButton:
	var b := KeyBindButton.new()
	b.action = action_name
	b.binding_index = index
	return b


func _init() -> void:
	super()
	set_process(false)


## The action's keyboard events.
func key_events() -> Array[InputEvent]:
	var keys: Array[InputEvent] = []
	if InputMap.has_action(action):
		for e: InputEvent in InputMap.action_get_events(action):
			if e is InputEventKey:
				keys.append(e)
	return keys


## The event this button shows (the first one when it shows them all), or null.
func current_event() -> InputEvent:
	var keys: Array[InputEvent] = key_events()
	var i: int = maxi(binding_index, 0)
	return keys[i] if i < keys.size() else null


## Re-reads the binding (call after the InputMap changes).
func refresh() -> void:
	if listening:
		text = WAITING_TEXT
		return
	var names := PackedStringArray()
	if binding_index < 0:
		for e: InputEvent in key_events():
			names.append(UiTheme.event_text(e).to_upper())
	else:
		var e: InputEvent = current_event()
		if e != null:
			names.append(UiTheme.event_text(e).to_upper())
	text = " / ".join(names) if not names.is_empty() else "—"


func start_listening() -> void:
	if listening:
		return
	listening = true
	_pulse = 0.0
	set_process(true)
	refresh()
	listening_changed.emit(true)


func stop_listening() -> void:
	if not listening:
		return
	listening = false
	set_process(false)
	refresh()
	queue_redraw()
	listening_changed.emit(false)


func _pressed() -> void:
	start_listening()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		custom_minimum_size.x = get_theme_constant(&"min_width", &"KeyBindButton")
		_ring = null
	elif what == NOTIFICATION_FOCUS_EXIT:
		stop_listening()


func _input(event: InputEvent) -> void:
	if not listening:
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		get_viewport().set_input_as_handled()
		var code: Key = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		if code == KEY_ESCAPE:
			stop_listening()
			return
		var binding := InputEventKey.new()
		binding.physical_keycode = code
		stop_listening()
		rebind_requested.emit(action, binding)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		if not get_global_rect().has_point((event as InputEventMouseButton).position):
			stop_listening()


func _process(delta: float) -> void:
	if not listening:
		# Godot turns processing on when the node is ready; only listening needs it.
		set_process(false)
		return
	_pulse += delta
	queue_redraw()


func _draw() -> void:
	if not listening:
		return
	# The focus ring, pulsing in the second accent, while waiting for a key.
	if _ring == null:
		var focus := get_theme_stylebox(&"focus", UiTheme.NEON) as StyleBoxFlat
		_ring = focus.duplicate() as StyleBoxFlat if focus != null else StyleBoxFlat.new()
	var c: Color = get_theme_color(&"listening", &"KeyBindButton")
	var a: float = 0.55 + 0.45 * sin(_pulse * TAU * 1.2)
	_ring.draw_center = false
	_ring.border_color = Color(c, a)
	_ring.shadow_color = Color(c, 0.4 * a)
	draw_style_box(_ring, Rect2(Vector2.ZERO, size))

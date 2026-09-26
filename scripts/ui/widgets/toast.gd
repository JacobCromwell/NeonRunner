class_name Toast
extends PanelContainer
## A short notification ("+250 credits", "Controller connected"): slides in at the top centre,
## stays a moment, fades out and frees itself. Toasts stack; they never take focus or clicks.
##   Toast.show_message(screen, "Shield equipped", &"shield")
##   Toast.show_message(hud_root, "Purchase failed", &"warning", Toast.Kind.WARNING)

enum Kind { INFO, WARNING }

const STACK_NAME: String = "ToastStack"
const FADE_IN: float = 0.18
const FADE_OUT: float = 0.3

@export var text: String = "":
	set(v):
		text = v
		label.text = v
@export var icon_name: StringName = &"info":
	set(v):
		icon_name = v
		icon.icon_name = v
		icon.visible = v != &""
@export var kind: Kind = Kind.INFO:
	set(v):
		kind = v
		theme_type_variation = UiTheme.TOAST_WARNING if v == Kind.WARNING else UiTheme.TOAST
		_tint_icon()
## Seconds fully shown (not counting the fades).
@export_range(0.3, 10.0, 0.1, "suffix:s") var duration: float = 2.2

var icon: NeonIcon
var label: Label
var _age: float = 0.0


## Shows a toast in `host`'s toast stack (created on first use, top centre of `host`).
static func show_message(host: Node, message: String, icon_id: StringName = &"info", toast_kind: Kind = Kind.INFO,
		seconds: float = 2.2) -> Toast:
	var t := Toast.new()
	t.text = message
	t.icon_name = icon_id
	t.kind = toast_kind
	t.duration = seconds
	stack_for(host).add_child(t)
	return t


## The VBoxContainer under `host` that holds its toasts.
static func stack_for(host: Node) -> VBoxContainer:
	var stack := host.get_node_or_null(STACK_NAME) as VBoxContainer
	if stack == null:
		stack = VBoxContainer.new()
		stack.name = STACK_NAME
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		stack.grow_horizontal = Control.GROW_DIRECTION_BOTH
		stack.offset_top = 88.0
		stack.process_mode = Node.PROCESS_MODE_ALWAYS
		host.add_child(stack)
	return stack


func _init() -> void:
	theme_type_variation = UiTheme.TOAST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	modulate.a = 0.0
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	icon = NeonIcon.new()
	icon.icon_name = icon_name
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	label = Label.new()
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	_tint_icon()


## Starts fading out now.
func dismiss() -> void:
	_age = maxf(_age, FADE_IN + duration)


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		_ensure_theme.call_deferred()
	elif what == NOTIFICATION_THEME_CHANGED:
		_tint_icon()


func _ensure_theme() -> void:
	# Theme the stack too, so a toast under an unthemed CanvasLayer still looks right.
	var stack := get_parent() as Control
	if stack != null:
		UiTheme.ensure(stack)
	UiTheme.ensure(self)


func _tint_icon() -> void:
	if icon != null:
		icon.color = get_theme_color(&"danger" if kind == Kind.WARNING else &"accent", UiTheme.NEON)


func _process(delta: float) -> void:
	_age += delta
	var alpha: float = 1.0
	if _age < FADE_IN:
		alpha = _age / FADE_IN
	elif _age > FADE_IN + duration:
		alpha = 1.0 - (_age - FADE_IN - duration) / FADE_OUT
	modulate.a = clampf(alpha, 0.0, 1.0)
	# A small pop on arrival (scale, not position: the stack container owns the position).
	pivot_offset = size * 0.5
	scale = Vector2.ONE * lerpf(0.92, 1.0, clampf(_age / FADE_IN, 0.0, 1.0))
	if _age >= FADE_IN + duration + FADE_OUT:
		queue_free()

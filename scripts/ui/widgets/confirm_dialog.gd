class_name ConfirmDialog
extends Control
## A modal yes/no question over the current screen: dims everything behind it, blocks clicks,
## keeps keyboard focus on its two buttons, and treats ui_cancel as "no". It frees itself when
## closed unless free_on_close is off.
##   var d := ConfirmDialog.ask(self, "QUIT RUN?", "You keep 20% of the credits from this attempt.",
##       "QUIT", "KEEP RUNNING", true)
##   d.confirmed.connect(_quit)

signal confirmed
signal cancelled
## After either answer (true = confirmed).
signal closed(accepted: bool)

## Fade in/out time.
const FADE_TIME: float = 0.14

@export var title: String = "":
	set(v):
		title = v
		title_label.text = v
@export_multiline var message: String = "":
	set(v):
		message = v
		message_label.text = v
		message_label.visible = v != ""
@export var confirm_text: String = "CONFIRM":
	set(v):
		confirm_text = v
		confirm_button.text = v
@export var cancel_text: String = "CANCEL":
	set(v):
		cancel_text = v
		cancel_button.text = v
## A destructive question: the confirm button is red and CANCEL gets the first focus.
@export var dangerous: bool = false:
	set(v):
		dangerous = v
		confirm_button.kind = NeonButton.Kind.DANGER if v else NeonButton.Kind.PRIMARY
@export var free_on_close: bool = true

var panel: PanelContainer
var title_label: Label
var message_label: Label
var confirm_button: NeonButton
var cancel_button: NeonButton
var _fade: float = 0.0
var _closing: bool = false
var _accepted: bool = false


## Adds a dialog to `host` and opens it.
static func ask(host: Node, title_text: String, message_text: String, confirm: String = "CONFIRM",
		cancel: String = "CANCEL", is_dangerous: bool = false) -> ConfirmDialog:
	var d := ConfirmDialog.new()
	d.title = title_text
	d.message = message_text
	d.confirm_text = confirm
	d.cancel_text = cancel
	d.dangerous = is_dangerous
	host.add_child(d)
	d.open()
	return d


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	set_process(false)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	panel = PanelContainer.new()
	panel.theme_type_variation = UiTheme.DIALOG
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 18)
	panel.add_child(column)
	title_label = Label.new()
	title_label.theme_type_variation = UiTheme.HEADING
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title_label)
	message_label = Label.new()
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.theme_type_variation = UiTheme.CAPTION
	column.add_child(message_label)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override(&"separation", 16)
	column.add_child(buttons)
	cancel_button = NeonButton.make(cancel_text)
	cancel_button.pressed.connect(close.bind(false))
	buttons.add_child(cancel_button)
	confirm_button = NeonButton.make(confirm_text, NeonButton.Kind.PRIMARY)
	confirm_button.pressed.connect(close.bind(true))
	buttons.add_child(confirm_button)
	for b: NeonButton in [cancel_button, confirm_button]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.x = 170


func open() -> void:
	_closing = false
	visible = true
	_fade = 0.0
	set_process(true)
	# Keep keyboard/controller focus inside the dialog: the two buttons point at each other.
	for b: NeonButton in [cancel_button, confirm_button]:
		var other: NeonButton = confirm_button if b == cancel_button else cancel_button
		var self_path: NodePath = b.get_path_to(b)
		var other_path: NodePath = b.get_path_to(other)
		b.focus_neighbor_top = self_path
		b.focus_neighbor_bottom = self_path
		b.focus_next = other_path
		b.focus_previous = other_path
	cancel_button.focus_neighbor_left = cancel_button.get_path_to(cancel_button)
	cancel_button.focus_neighbor_right = cancel_button.get_path_to(confirm_button)
	confirm_button.focus_neighbor_left = confirm_button.get_path_to(cancel_button)
	confirm_button.focus_neighbor_right = confirm_button.get_path_to(confirm_button)
	if is_inside_tree():
		UiSounds.quiet()
		(cancel_button if dangerous else confirm_button).grab_focus(UiTheme.is_touch())
		if not get_viewport().gui_focus_changed.is_connected(_on_focus_changed):
			get_viewport().gui_focus_changed.connect(_on_focus_changed)


## Answers the dialog (true = confirm) and closes it.
func close(accepted: bool) -> void:
	if _closing:
		return
	_closing = true
	_accepted = accepted
	_release_focus_watch()
	if accepted:
		confirmed.emit()
	else:
		cancelled.emit()
	closed.emit(accepted)
	set_process(true)


func is_open() -> bool:
	return visible and not _closing


## The dialog is modal: if anything outside it takes the focus while it's open, take it back.
func _on_focus_changed(control: Control) -> void:
	if not is_open():
		_release_focus_watch()
	elif control != null and not is_ancestor_of(control):
		var answer: NeonButton = cancel_button if dangerous else confirm_button
		answer.grab_focus.call_deferred(UiTheme.is_touch())


func _release_focus_watch() -> void:
	var viewport: Viewport = get_viewport()
	if viewport != null and viewport.gui_focus_changed.is_connected(_on_focus_changed):
		viewport.gui_focus_changed.disconnect(_on_focus_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		_release_focus_watch()
	elif what == NOTIFICATION_ENTER_TREE:
		_ensure_theme.call_deferred()
	elif what == NOTIFICATION_THEME_CHANGED:
		var w: float = get_theme_constant(&"control_height", UiTheme.NEON) * 9.5
		panel.custom_minimum_size.x = w
		message_label.custom_minimum_size.x = w - 80.0


func _ensure_theme() -> void:
	UiTheme.ensure(self)


func _unhandled_input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close(false)


func _process(delta: float) -> void:
	_fade = move_toward(_fade, 0.0 if _closing else 1.0, delta / FADE_TIME)
	modulate.a = _fade
	panel.scale = Vector2.ONE * lerpf(0.94, 1.0, _fade)
	panel.pivot_offset = panel.size * 0.5
	queue_redraw()
	if _closing and _fade <= 0.0:
		set_process(false)
		visible = false
		if free_on_close:
			queue_free()
	elif not _closing and _fade >= 1.0:
		set_process(false)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), get_theme_color(&"dim", &"ScreenBase"))

class_name ScreenBase
extends Control
## The common screen layout: a title bar (back button, title, a slot on the right for credits or
## a settings button), a content area, and a footer with button hints (keyboard and controller
## only; hidden on touch devices). ui_cancel means back. When shown, the screen gives
## `initial_focus` (or its first focusable control) the focus, so keyboard and controller
## navigation work at once; on touch devices that focus stays invisible until a key is used.
## The screen applies the menu theme to itself and runs while the game is paused.
##
##   class_name ShopScreen
##   extends ScreenBase
##   func _ready() -> void:
##       title = "SHOP"
##       header_right.add_child(credits)            # a CreditCounter
##       var play := NeonButton.make("PLAY", NeonButton.Kind.PRIMARY, &"play")
##       content.add_child(play)
##       initial_focus = play
##       back_requested.connect(_on_back)
##
## Subclasses may override _ready and _draw freely (the base does its setup in _notification).
## If you override _unhandled_input, call super(event) to keep ui_cancel = back.
## Children placed under the screen in a .tscn are moved into `content`.

signal back_requested

enum Backdrop { FULL, DIM, NONE }

@export var title: String = "":
	set(v):
		title = v
		title_label.text = v
@export var show_back: bool = true:
	set(v):
		show_back = v
		back_button.visible = v
		_update_hints()
## FULL: the menu backdrop. DIM: darkens the game behind (pause). NONE: transparent.
@export var backdrop: Backdrop = Backdrop.FULL:
	set(v):
		backdrop = v
		_backdrop.queue_redraw()
@export var show_footer: bool = true:
	set(v):
		show_footer = v
		_update_hints()
## Gets focus when the screen opens; unset = the first focusable control in `content`.
@export var initial_focus: Control

var title_bar: PanelContainer
var title_label: Label
var back_button: NeonButton
## The right end of the title bar.
var header_right: HBoxContainer
## Where the screen's UI goes: a VBoxContainer filling the space between title bar and footer.
var content: VBoxContainer
var footer: PanelContainer
var _hints: HBoxContainer
var _hint_list: Array = []
var _backdrop: Control
var _safe: MarginContainer
var _body: MarginContainer


func _init() -> void:
	theme = UiTheme.get_theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	_backdrop = BackdropView.new()
	_backdrop.name = "Backdrop"
	add_child(_backdrop)
	_safe = MarginContainer.new()
	_safe.name = "SafeArea"
	_safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_safe)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override(&"separation", 0)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_safe.add_child(layout)

	title_bar = PanelContainer.new()
	title_bar.name = "TitleBar"
	title_bar.theme_type_variation = UiTheme.BAR
	layout.add_child(title_bar)
	var bar := HBoxContainer.new()
	title_bar.add_child(bar)
	back_button = NeonButton.make("BACK", NeonButton.Kind.FLAT, &"back")
	back_button.name = "Back"
	back_button.pressed.connect(go_back)
	bar.add_child(back_button)
	title_label = Label.new()
	title_label.theme_type_variation = UiTheme.SCREEN_TITLE
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.size_flags_vertical = Control.SIZE_FILL
	bar.add_child(title_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(spacer)
	header_right = HBoxContainer.new()
	header_right.name = "HeaderRight"
	header_right.alignment = BoxContainer.ALIGNMENT_END
	bar.add_child(header_right)

	_body = MarginContainer.new()
	_body.name = "Body"
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(_body)
	content = VBoxContainer.new()
	content.name = "Content"
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(content)

	footer = PanelContainer.new()
	footer.name = "Footer"
	footer.theme_type_variation = UiTheme.FOOTER
	layout.add_child(footer)
	_hints = HBoxContainer.new()
	_hints.alignment = BoxContainer.ALIGNMENT_END
	_hints.add_theme_constant_override(&"separation", 22)
	footer.add_child(_hints)
	set_hints([[&"ui_accept", "SELECT"], [&"ui_cancel", "BACK"]])


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_READY:
			# Children from a .tscn (owned by this scene) go into the content area; nodes added by
			# code (a dialog, a toast) stay where they were put.
			for child: Node in get_children():
				if child != _backdrop and child != _safe and child is Control and child.owner == self:
					child.reparent(content, false)
			_update_layout()
			focus_initial.call_deferred()
		NOTIFICATION_THEME_CHANGED:
			if _body != null:
				_update_layout()
				_update_hints()
		NOTIFICATION_RESIZED:
			if _body != null:
				_update_layout()
		NOTIFICATION_VISIBILITY_CHANGED:
			if is_node_ready() and is_visible_in_tree():
				focus_initial.call_deferred()


## Hints for the footer: pairs of [action, label], e.g. [[&"ui_accept", "SELECT"]]. Each shows the
## action's current key. The back hint only shows while the back button does.
func set_hints(hints: Array) -> void:
	_hint_list = hints
	_update_hints()


## Moves focus to `initial_focus` or the first focusable control in the content.
func focus_initial() -> void:
	if not is_visible_in_tree():
		return
	var target: Control = null
	if is_instance_valid(initial_focus) and initial_focus.is_visible_in_tree():
		target = initial_focus
	if target == null:
		target = first_focusable(content)
	if target == null and back_button.visible:
		target = back_button
	if target != null:
		UiSounds.quiet()
		target.grab_focus(UiTheme.is_touch())


## Called by the back button and ui_cancel. Override to intercept; the default emits back_requested.
func go_back() -> void:
	back_requested.emit()


## The first visible, enabled control under `root` that takes keyboard focus (depth first).
static func first_focusable(root: Node) -> Control:
	for child: Node in root.get_children():
		var c := child as Control
		if c == null or not c.visible:
			continue
		if c.focus_mode == Control.FOCUS_ALL and not (c is BaseButton and (c as BaseButton).disabled):
			return c
		var inner: Control = first_focusable(c)
		if inner != null:
			return inner
	return null


func _unhandled_input(event: InputEvent) -> void:
	if show_back and is_visible_in_tree() and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		go_back()


func _update_layout() -> void:
	var margin: int = get_theme_constant(&"margin", UiTheme.NEON)
	var gap: int = get_theme_constant(&"spacing", UiTheme.NEON)
	var safe: Vector4 = UiTheme.safe_area_margins(self)
	_safe.add_theme_constant_override(&"margin_left", roundi(safe.x))
	_safe.add_theme_constant_override(&"margin_top", roundi(safe.y))
	_safe.add_theme_constant_override(&"margin_right", roundi(safe.z))
	_safe.add_theme_constant_override(&"margin_bottom", roundi(safe.w))
	_body.add_theme_constant_override(&"margin_left", margin)
	_body.add_theme_constant_override(&"margin_right", margin)
	_body.add_theme_constant_override(&"margin_top", gap + 4)
	_body.add_theme_constant_override(&"margin_bottom", gap + 4)
	# On touch screens the back button is a big icon; with a keyboard it also says BACK.
	back_button.text = "" if get_theme_constant(&"touch", UiTheme.NEON) == 1 else "BACK"


func _update_hints() -> void:
	if _hints == null:
		return
	for child: Node in _hints.get_children():
		_hints.remove_child(child)
		child.queue_free()
	footer.visible = show_footer and not UiTheme.is_touch() and not _hint_list.is_empty()
	if not footer.visible:
		return
	for hint: Array in _hint_list:
		var action: StringName = hint[0]
		if action == &"ui_cancel" and not show_back:
			continue
		var key_text: String = UiTheme.action_text(action)
		if key_text == "":
			continue
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override(&"separation", 8)
		var key := Label.new()
		key.theme_type_variation = UiTheme.KEY_CAP
		key.text = key_text.to_upper()
		key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pair.add_child(key)
		var label := Label.new()
		label.theme_type_variation = UiTheme.CAPTION
		label.text = String(hint[1])
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pair.add_child(label)
		_hints.add_child(pair)


## Draws the screen's backdrop behind everything else.
class BackdropView:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED or what == NOTIFICATION_THEME_CHANGED:
			queue_redraw()

	func _draw() -> void:
		var screen := get_parent() as ScreenBase
		var mode: Backdrop = screen.backdrop if screen != null else Backdrop.FULL
		var rect := Rect2(Vector2.ZERO, size)
		if mode == Backdrop.DIM:
			draw_rect(rect, get_theme_color(&"dim", &"ScreenBase"))
		elif mode == Backdrop.FULL:
			_draw_menu_backdrop(rect)

	## A dark gradient with a faint perspective grid under a violet horizon.
	func _draw_menu_backdrop(rect: Rect2) -> void:
		var top: Color = get_theme_color(&"backdrop_top", UiTheme.NEON)
		var bottom: Color = get_theme_color(&"backdrop_bottom", UiTheme.NEON)
		draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y)]), PackedColorArray([top, top, bottom, bottom]))
		var grid: Color = get_theme_color(&"grid", &"ScreenBase")
		var glow: Color = get_theme_color(&"horizon", &"ScreenBase")
		var horizon: float = rect.size.y * 0.64
		var vanish := Vector2(rect.size.x * 0.5, horizon)
		for i: int in 6:
			var h: float = 3.0 + i * 7.0
			draw_rect(Rect2(0.0, horizon - h * 0.5, rect.size.x, h), Color(glow, glow.a * 0.09))
		draw_line(Vector2(0.0, horizon), Vector2(rect.size.x, horizon), glow, 1.0)
		var depth: float = rect.size.y - horizon
		for i: int in range(-14, 15):
			draw_line(vanish, Vector2(vanish.x + i * rect.size.x * 0.11, rect.size.y), Color(grid, grid.a * 0.85), 1.0, true)
		for j: int in range(1, 10):
			var f: float = float(j) / 9.0
			var y: float = horizon + depth * f * f
			draw_line(Vector2(0.0, y), Vector2(rect.size.x, y), Color(grid, grid.a * (0.25 + 0.75 * f)), 1.0)

class_name LevelIntroScreen
extends ScreenBase
## The prepared run waits here without advancing. One hint per page, never run popups.
## Selection and acknowledgement belong to HintDirector; this screen only presents its entries.

signal play_requested
signal hints_presented(entries: Array[Dictionary])

var context: RunContext
var hints: Array[Dictionary] = []
var play_button: NeonButton
var hint_list: VBoxContainer
var page_index: int = 0
var previous_button: NeonButton
var next_button: NeonButton
var page_label: Label
var _hint_label: Label
var _scroll: ScrollContainer
var _presented: Array[Dictionary] = []


func _ready() -> void:
	title = "BOSS" if context.is_boss() else "LEVEL"
	back_requested.connect(App.show_level_select if context.is_campaign() else App.show_title)
	var heading: String = context.step.title() if context.step != null else context.config.display_name
	var heading_label := make_label(heading.to_upper(), UiTheme.TITLE, HORIZONTAL_ALIGNMENT_CENTER)
	heading_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(heading_label)
	if context.step != null and context.step.zone != null:
		content.add_child(make_label(context.step.zone.display_name, UiTheme.SUBHEADING,
			HORIZONTAL_ALIGNMENT_CENTER))
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(_scroll)
	hint_list = VBoxContainer.new()
	hint_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(hint_list)
	if not hints.is_empty():
		hint_list.add_child(make_heading("HINTS", &"info"))
		_hint_label = make_label("")
		_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hint_list.add_child(_hint_label)
		var pager := HBoxContainer.new()
		pager.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_child(pager)
		previous_button = NeonButton.make("PREVIOUS")
		previous_button.pressed.connect(func() -> void: change_page(-1))
		pager.add_child(previous_button)
		page_label = make_label("", UiTheme.CAPTION, HORIZONTAL_ALIGNMENT_CENTER)
		page_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pager.add_child(page_label)
		next_button = NeonButton.make("NEXT")
		next_button.pressed.connect(func() -> void: change_page(1))
		pager.add_child(next_button)
		_show_page()
		set_hints([[&"move_left", "PREVIOUS HINT"], [&"move_right", "NEXT HINT"],
			[&"ui_accept", "SELECT"], [&"ui_cancel", "BACK"]])
	play_button = NeonButton.make("PLAY", NeonButton.Kind.PRIMARY, &"play")
	play_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play_button.pressed.connect(func() -> void:
		hints_presented.emit(_presented.duplicate(true))
		play_requested.emit())
	content.add_child(play_button)
	initial_focus = play_button


func _process(_delta: float) -> void:
	if is_visible_in_tree() and not hints.is_empty():
		var entry: Dictionary = hints[page_index]
		if not _presented.has(entry):
			_presented.append(entry.duplicate(true))


## Intercept before GUI focus navigation, including when PLAY owns focus or the rebound key
## also maps to ui_accept. Releases and repeats are consumed too; only fresh presses page.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	for action: StringName in [&"move_left", &"move_right"]:
		if event.is_action(action):
			if event.is_action_pressed(action) and not hints.is_empty():
				change_page(-1 if action == &"move_left" else 1)
			get_viewport().set_input_as_handled()
			return


func change_page(direction: int) -> void:
	if hints.is_empty():
		return
	page_index = clampi(page_index + direction, 0, hints.size() - 1)
	_show_page()


func _show_page() -> void:
	_hint_label.text = String(hints[page_index]["text"])
	_scroll.scroll_vertical = 0
	page_label.text = "%d / %d" % [page_index + 1, hints.size()]
	previous_button.disabled = page_index == 0
	next_button.disabled = page_index == hints.size() - 1
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused == previous_button and previous_button.disabled \
			or focused == next_button and next_button.disabled:
		if play_button != null:
			play_button.grab_focus()

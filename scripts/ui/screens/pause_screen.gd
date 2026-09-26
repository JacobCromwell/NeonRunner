class_name PauseScreen
extends ScreenBase
## The pause overlay over the stopped run: which level this is and how far along, then resume,
## restart the level, settings, and quit to the menu (after a check, since the run's credits are
## lost). Pause or back (Esc) resumes.

## The menu's buttons by name (resume, restart, settings, quit), for tests.
var buttons: Dictionary = {}
var progress: ProgressMeter
var _quit_dialog: ConfirmDialog


func _ready() -> void:
	backdrop = Backdrop.DIM
	show_title_bar = false
	back_requested.connect(App.resume_game)
	set_hints([[&"ui_accept", "SELECT"], [&"ui_cancel", "RESUME"]])
	var column: VBoxContainer = add_panel(UiTheme.DIALOG, 440.0)
	column.add_theme_constant_override(&"separation", roundi(UiTheme.px(10)))
	column.add_child(ScreenBase.make_label("PAUSED", UiTheme.TITLE, HORIZONTAL_ALIGNMENT_CENTER))

	var run: LevelRun = App.run
	if run != null and run.context != null:
		var names: PackedStringArray = ResultsScreen.run_names(run.context)
		column.add_child(ScreenBase.make_label(names[0], UiTheme.SUBHEADING, HORIZONTAL_ALIGNMENT_CENTER))
		if names[1] != "":
			column.add_child(ScreenBase.make_label(names[1], UiTheme.HEADING, HORIZONTAL_ALIGNMENT_CENTER))
		if run.world != null and run.world.layout != null and run.context.mode != RunContext.Mode.ENDLESS:
			var fraction: float = clampf(run.world.player.distance / maxf(run.world.layout.length, 1.0), 0.0, 1.0)
			var row := HBoxContainer.new()
			row.add_theme_constant_override(&"separation", 12)
			column.add_child(row)
			progress = ProgressMeter.new()
			progress.value = fraction
			progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(progress)
			row.add_child(ScreenBase.make_label("%d%%" % floori(fraction * 100.0), UiTheme.VALUE))

	var gap := Control.new()
	gap.custom_minimum_size.y = UiTheme.px(4)
	column.add_child(gap)
	_add_button(column, "resume", "RESUME", NeonButton.Kind.PRIMARY, &"play", App.resume_game)
	_add_button(column, "restart", "RESTART LEVEL", NeonButton.Kind.NORMAL, &"restart", _restart)
	_add_button(column, "settings", "SETTINGS", NeonButton.Kind.NORMAL, &"settings", _open_settings)
	_add_button(column, "quit", "QUIT TO MENU", NeonButton.Kind.FLAT, &"home", _ask_quit)
	initial_focus = buttons["resume"]


func _add_button(parent: Control, id: String, label: String, kind: NeonButton.Kind, icon_name: StringName,
		action: Callable) -> void:
	var b := NeonButton.make(label, kind, icon_name)
	b.pressed.connect(action)
	parent.add_child(b)
	buttons[id] = b


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed(&"pause") and not _dialog_open():
		get_viewport().set_input_as_handled()
		App.resume_game()
		return
	super(event)


func _dialog_open() -> bool:
	return is_instance_valid(_quit_dialog) and _quit_dialog.is_open()


func _restart() -> void:
	if App.run == null:
		return
	var ctx: RunContext = App.run.context
	App.resume_game()
	App.retry(ctx)


func _open_settings() -> void:
	var s := SettingsScreen.new()
	s.on_close = PauseScreen.reopen
	App.show_overlay(s)


## Back from the settings overlay to the pause menu.
static func reopen() -> void:
	App.show_overlay(PauseScreen.new())


func _ask_quit() -> void:
	# DESIGN-TBD: whether quitting mid-level asks first; the run's credits are lost either way.
	_quit_dialog = ConfirmDialog.ask(self, "QUIT THIS RUN?", "Credits picked up in this run are lost.",
		"QUIT", "KEEP PLAYING", true)
	_quit_dialog.confirmed.connect(App.quit_run)

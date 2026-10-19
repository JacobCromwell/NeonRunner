class_name PauseScreen
extends ScreenBase
## The pause overlay over the stopped run: which level or boss fight this is and how far along, then
## resume, restart (a boss fight restarts from a checkpoint it reached), settings, and quit to the menu
## (after a check: quitting keeps the same credit share as a death, GDD §4). Pause or back (Esc) resumes.

## The menu's buttons by name (resume, restart, settings, quit), for tests.
var buttons: Dictionary = {}
var progress: ProgressMeter
var _quit_dialog: ConfirmDialog


func _ready() -> void:
	backdrop = Backdrop.DIM
	show_title_bar = false
	back_requested.connect(App.resume_game)
	set_hints([[&"ui_accept", "SELECT"], [&"ui_cancel", "RESUME"]])
	var column: VBoxContainer = add_panel(UiTheme.DIALOG, 640.0 if is_short() else 440.0)
	column.add_theme_constant_override(&"separation", roundi(UiTheme.px(10)))
	column.add_child(ScreenBase.make_label("PAUSED", UiTheme.TITLE, HORIZONTAL_ALIGNMENT_CENTER))

	var run: LevelRun = App.run
	if run != null and run.context != null:
		var names: PackedStringArray = ResultsScreen.run_names(run.context)
		column.add_child(ScreenBase.make_label(names[0], UiTheme.SUBHEADING, HORIZONTAL_ALIGNMENT_CENTER))
		if names[1] != "":
			column.add_child(ScreenBase.make_label(names[1], UiTheme.HEADING, HORIZONTAL_ALIGNMENT_CENTER))
		var row: Control = DeathScreen.progress_row(run)
		if row != null:
			column.add_child(row)
			progress = row.get_child(0) as ProgressMeter

	var gap := Control.new()
	gap.custom_minimum_size.y = UiTheme.px(4)
	column.add_child(gap)
	var boss: bool = run != null and run.context != null and run.context.is_boss()
	# A phone held sideways has no height for four stacked buttons: two columns of two.
	var grid: Container = column
	if is_short():
		var two := GridContainer.new()
		two.columns = 2
		two.add_theme_constant_override(&"h_separation", roundi(UiTheme.px(10)))
		two.add_theme_constant_override(&"v_separation", roundi(UiTheme.px(10)))
		column.add_child(two)
		grid = two
	_add_button(grid, "resume", "RESUME", NeonButton.Kind.PRIMARY, &"play", App.resume_game)
	_add_button(grid, "restart", "RESTART FIGHT" if boss else "RESTART LEVEL", NeonButton.Kind.NORMAL, &"restart", _restart)
	_add_button(grid, "settings", "SETTINGS", NeonButton.Kind.NORMAL, &"settings", _open_settings)
	_add_button(grid, "quit", "QUIT TO MENU", NeonButton.Kind.FLAT, &"home", _ask_quit)
	initial_focus = buttons["resume"]


func _add_button(parent: Container, id: String, label: String, kind: NeonButton.Kind, icon_name: StringName,
		action: Callable) -> void:
	var b := NeonButton.make(label, kind, icon_name)
	b.pressed.connect(action)
	if parent is GridContainer:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	var share: int = roundi((App.rules.death_credit_keep_fraction if App.rules != null else 0.0) * 100.0)
	var weekly: bool = App.run != null and App.run.context != null and App.run.context.is_weekly()
	# The weekly challenge pays only for the week's first clear (GDD §6), so there are no credits to keep.
	var text: String = "This run won't count for the board, and the weekly challenge pays only for a clear." if weekly \
		else "You'll keep %d%% of the credits picked up in this run, like a death." % share
	_quit_dialog = ConfirmDialog.ask(self, "QUIT THIS RUN?", text, "QUIT", "KEEP PLAYING", true)
	_quit_dialog.confirmed.connect(App.quit_run)

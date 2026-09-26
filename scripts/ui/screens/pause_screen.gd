class_name PauseScreen
extends Control
## The pause overlay: resume, restart the level, settings, quit to the menu. Placeholder look.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ScreenKit.fill(self)
	ScreenKit.backdrop(self)
	var col: VBoxContainer = ScreenKit.column(self, 380.0)
	ScreenKit.title(col, "PAUSED", 36)
	ScreenKit.button(col, "Resume", App.resume_game)
	ScreenKit.button(col, "Restart level", func() -> void:
		var ctx: RunContext = App.run.context
		App.resume_game()
		App.retry(ctx))
	ScreenKit.button(col, "Settings", func() -> void:
		var s := SettingsScreen.new()
		s.on_close = func() -> void: App.show_overlay(PauseScreen.new())
		App.show_overlay(s))
	ScreenKit.button(col, "Quit to menu", App.quit_run)
	ScreenKit.focus_first(self)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		App.resume_game()

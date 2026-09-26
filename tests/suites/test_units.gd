extends TestSuite
## Small units: pulsing hazard states, touch gesture classification, the sound library, the tuning panel.

const TouchInputScript: GDScript = preload("res://scripts/input/touch_input.gd")


func run() -> void:
	_test_hazard_pulse()
	_test_touch_gestures()
	_test_sound_library()
	await _test_tuning_panel()


func _test_hazard_pulse() -> void:
	var hazard := Hazard.new()
	var seen: Array = []
	hazard.state_changed.connect(func(s: Hazard.State) -> void: seen.append(s))
	hazard.setup_pulsing(1.0, 1.0, 0.35, 0.0, 0.0)
	check(hazard.state == Hazard.State.ON and hazard.is_active(), "pulse starts ON at phase 0")
	hazard._physics_process(1.2)
	check(hazard.state == Hazard.State.OFF and not hazard.is_active(), "pulse is OFF after its on-time")
	hazard._physics_process(0.5)
	check(hazard.state == Hazard.State.WARNING and not hazard.is_active(), "pulse warns (still safe) before switching on")
	hazard._physics_process(0.4)
	check(hazard.state == Hazard.State.ON, "pulse switches back ON after the warning")
	check(seen == [Hazard.State.OFF, Hazard.State.WARNING, Hazard.State.ON], "state_changed fires once per change")
	hazard.free()

	var late := Hazard.new()
	late.setup_pulsing(1.0, 1.0, 0.35, 0.0, 5.3)
	check(late.state == Hazard.State.OFF, "a hazard built mid-level picks up the level clock")
	late.free()


func _test_touch_gestures() -> void:
	var t: float = 36.0
	check(TouchInputScript.swipe_action(Vector2(10, 5), t) == &"", "short drag is not a swipe")
	check(TouchInputScript.swipe_action(Vector2(50, 10), t) == &"move_right", "swipe right")
	check(TouchInputScript.swipe_action(Vector2(-50, 20), t) == &"move_left", "swipe left")
	check(TouchInputScript.swipe_action(Vector2(10, -50), t) == &"jump", "swipe up = jump")
	check(TouchInputScript.swipe_action(Vector2(-10, 50), t) == &"slide", "swipe down = slide")
	check(TouchInputScript.is_tap(4.0, 0.1, t, 0.22), "quick still touch is a tap")
	check(not TouchInputScript.is_tap(4.0, 0.5, t, 0.22), "long press is not a tap")
	check(not TouchInputScript.is_tap(30.0, 0.1, t, 0.22), "moving touch is not a tap")


func _test_sound_library() -> void:
	var library := load("res://data/audio/sfx_library.tres") as SfxLibrary
	check(library != null and library.names().size() >= 12, "sound library lists the game's sounds")
	for event: StringName in [&"jump", &"land", &"slide", &"wall_enter", &"wall_jump", &"wall_blocked",
			&"ramp", &"pad", &"hull_end", &"died", &"fence_warning", &"level_complete"]:
		check(library.names().has(String(event)), "sound library covers '%s'" % event)
	for sound: String in library.names():
		var stream: AudioStream = library.stream(sound)
		var length: float = stream.get_length() if stream != null else 0.0
		if stream is AudioStreamRandomizer:
			length = (stream as AudioStreamRandomizer).get_stream(0).get_length()
		check(length > 0.1 and length < 2.5, "sound '%s' loads with a sensible length (%.2f s)" % [sound, length])


func _test_tuning_panel() -> void:
	var t: MovementTuning = tuning.duplicate() as MovementTuning
	var config: LevelConfig = (load(LEVEL_PATH) as LevelConfig).duplicate() as LevelConfig
	var rules: GameRules = (load("res://data/tuning/game_rules.tres") as GameRules).duplicate() as GameRules
	var panel := TuningPanel.new()
	tree.root.add_child(panel)
	var sections: Array[Dictionary] = [
		{"title": "Movement", "resource": t, "path": TUNING_PATH},
		{"title": "Game rules", "resource": rules, "path": "res://data/tuning/game_rules.tres"},
		{"title": "Level pacing", "resource": config, "path": LEVEL_PATH},
	]
	panel.setup(sections)
	check(panel.control_count() >= 55, "tuning panel has a control per tunable (%d)" % panel.control_count())
	panel.open()
	var slider: HSlider = panel.find_slider("run_speed")
	check(slider != null and is_equal_approx(slider.value, t.run_speed), "tuning panel shows current values")
	if slider != null:
		slider.value = 25.0
		check(is_equal_approx(t.run_speed, 25.0), "moving a slider edits the tuning live")
	var spacing: HSlider = panel.find_slider("spacing_seconds_easy")
	if spacing != null:
		spacing.value = 2.5
	check(spacing != null and is_equal_approx(config.spacing_seconds_easy, 2.5), "level pacing is tunable live")
	var lanes: HSlider = panel.find_slider("lanes_pc")
	if lanes != null:
		lanes.value = 6.0
	check(lanes != null and rules.lanes_pc == 6 and typeof(rules.lanes_pc) == TYPE_INT, "integer tunables stay integers")
	panel.queue_free()
	await tree.process_frame

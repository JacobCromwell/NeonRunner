extends SceneTree
## Headless test runner. From the project folder:
##   godot --headless --fixed-fps 60 -s res://tests/run_tests.gd
## Exits with code 0 on success and 1 on any failure.

const TUNING_PATH: String = "res://data/tuning/movement.tres"
const LEVEL_PATH: String = "res://data/levels/prototype_level.tres"
const TouchInputScript: GDScript = preload("res://scripts/input/touch_input.gd")

var _tuning: MovementTuning
var _failures: PackedStringArray = []
var _checks: int = 0


func _initialize() -> void:
	_tuning = load(TUNING_PATH) as MovementTuning
	_run.call_deferred()


func _run() -> void:
	var started: int = Time.get_ticks_msec()
	_test_generator()
	_test_hazard_pulse()
	_test_touch_gestures()
	_test_placeholder_audio()
	await _test_tuning_panel()
	await _test_movement()
	print("")
	if _failures.is_empty():
		print("ALL TESTS PASSED (%d checks, %.1f s)" % [_checks, (Time.get_ticks_msec() - started) / 1000.0])
		quit(0)
	else:
		for f: String in _failures:
			print("FAIL: " + f)
		print("%d of %d checks FAILED" % [_failures.size(), _checks])
		quit(1)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


# --- Generator ---------------------------------------------------------------

func _test_generator() -> void:
	var base: LevelConfig = load(LEVEL_PATH) as LevelConfig
	var patterns: Array = LevelGenerator.load_patterns(base.patterns_path)
	_check(patterns.size() > 0, "patterns loaded")
	var levels: int = 0
	var used_ids: Dictionary = {}
	for lanes: int in [3, 5, 6]:
		for difficulty: float in [0.0, 0.3, 0.6, 1.0]:
			for level_seed: int in range(1, 31):
				var config: LevelConfig = base.duplicate() as LevelConfig
				config.lane_count = lanes
				config.difficulty = difficulty
				config.level_seed = level_seed
				var a: LevelLayout = LevelGenerator.new().generate(config, _tuning, patterns)
				var b: LevelLayout = LevelGenerator.new().generate(config, _tuning, patterns)
				var tag: String = "lanes=%d diff=%.1f seed=%d" % [lanes, difficulty, level_seed]
				_check(JSON.stringify(a.to_dict()) == JSON.stringify(b.to_dict()), "deterministic " + tag)
				_check(a.fences.size() + a.gaps.size() > 10, "level has content " + tag)
				_check_layout(a, config, tag)
				levels += 1
	print("generator: checked %d levels" % levels)


func _check_layout(layout: LevelLayout, config: LevelConfig, tag: String) -> void:
	var n: int = layout.lane_count
	var max_gap: float = _tuning.jump_distance(_tuning.run_speed) * config.max_gap_jump_fraction + 0.001
	var finish_buffer: float = layout.length - config.end_clear_distance + 0.001
	var landing: float = config.hull_landing_seconds * _tuning.run_speed
	for g: Dictionary in layout.gaps:
		_check(g["lane"] >= 0 and g["lane"] < n, "gap lane in range " + tag)
		_check(g["end"] - g["start"] <= max_gap, "gap jumpable (%.1f m) %s" % [g["end"] - g["start"], tag])
		_check(g["end"] <= finish_buffer, "gap before the end-clear stretch " + tag)
	for f: Dictionary in layout.fences:
		_check(f["lane"] >= 0 and f["lane"] < n, "fence lane in range " + tag)
		_check(not _gapped_at(layout, f["lane"], f["at"]), "fence not over a gap at %.1f %s" % [f["at"], tag])
		_check(f["at"] <= finish_buffer, "fence before the end-clear stretch " + tag)
	_check(_longest_all_lane_hole(layout) <= max_gap, "every all-lane hole is jumpable " + tag)
	for p: Dictionary in layout.pads:
		var covered: bool = false
		for h: Dictionary in layout.hulls:
			if h["start"] <= p["at"] - 1.0 and h["end"] >= p["at"] + 10.0:
				covered = true
		_check(covered, "pad at %.1f has a hull above %s" % [p["at"], tag])
		_check(not _gapped_between(layout, p["lane"], p["at"] - 6.0, p["at"] + _tuning.pad_length),
			"pad at %.1f is reachable on solid floor %s" % [p["at"], tag])
	for h: Dictionary in layout.hulls:
		_check(h["end"] + landing <= finish_buffer, "hull and its landing end before the finish " + tag)
		for lane: int in n:
			_check(not _gapped_between(layout, lane, h["end"] - 2.0, h["end"] + landing * 0.8),
				"hull landing clear at %.1f %s" % [h["end"], tag])
	for r: Dictionary in layout.ramps:
		var lane: int = layout.outer_lane(r["side"])
		_check(not _gapped_between(layout, lane, r["at"], r["at"] + _tuning.ramp_length), "ramp on solid floor " + tag)
		for s: Dictionary in layout.signs:
			if s["side"] == r["side"]:
				_check(s["end"] < r["at"] - 2.0 or s["start"] > r["at"] + _tuning.ramp_length + 2.0,
					"ramp entry not blocked by a sign " + tag)
	for s: Dictionary in layout.signs:
		_check(s["end"] <= finish_buffer, "sign before the end-clear stretch " + tag)


func _gapped_at(layout: LevelLayout, lane: int, d: float) -> bool:
	return _gapped_between(layout, lane, d, d)


func _gapped_between(layout: LevelLayout, lane: int, from: float, to: float) -> bool:
	for g: Dictionary in layout.gaps:
		if g["lane"] == lane and g["start"] <= to and g["end"] >= from:
			return true
	return false


## Longest stretch where every lane is a hole at once (intersection of the lanes' gap intervals).
func _longest_all_lane_hole(layout: LevelLayout) -> float:
	var common: Array[Vector2] = []
	for lane: int in layout.lane_count:
		var mine: Array[Vector2] = []
		for g: Dictionary in layout.gaps:
			if g["lane"] == lane:
				mine.append(Vector2(g["start"], g["end"]))
		if lane == 0:
			common = mine
			continue
		var next: Array[Vector2] = []
		for a: Vector2 in common:
			for b: Vector2 in mine:
				var lo: float = maxf(a.x, b.x)
				var hi: float = minf(a.y, b.y)
				if hi > lo:
					next.append(Vector2(lo, hi))
		common = next
	var longest: float = 0.0
	for v: Vector2 in common:
		longest = maxf(longest, v.y - v.x)
	return longest


# --- Hazard pulse, touch, audio, tuning panel ----------------------------------

func _test_hazard_pulse() -> void:
	var hazard := Hazard.new()
	var seen: Array = []
	hazard.state_changed.connect(func(s: Hazard.State) -> void: seen.append(s))
	hazard.setup_pulsing(1.0, 1.0, 0.35, 0.0, 0.0)
	_check(hazard.state == Hazard.State.ON and hazard.is_active(), "pulse starts ON at phase 0")
	hazard._physics_process(1.2)
	_check(hazard.state == Hazard.State.OFF and not hazard.is_active(), "pulse is OFF after its on-time")
	hazard._physics_process(0.5)
	_check(hazard.state == Hazard.State.WARNING and not hazard.is_active(), "pulse warns (still safe) before switching on")
	hazard._physics_process(0.4)
	_check(hazard.state == Hazard.State.ON, "pulse switches back ON after the warning")
	_check(seen == [Hazard.State.OFF, Hazard.State.WARNING, Hazard.State.ON], "state_changed fires once per change")
	hazard.free()

	var late := Hazard.new()
	late.setup_pulsing(1.0, 1.0, 0.35, 0.0, 5.3)
	_check(late.state == Hazard.State.OFF, "a hazard built mid-level picks up the level clock")
	late.free()


func _test_touch_gestures() -> void:
	var t: float = 36.0
	_check(TouchInputScript.swipe_action(Vector2(10, 5), t) == &"", "short drag is not a swipe")
	_check(TouchInputScript.swipe_action(Vector2(50, 10), t) == &"move_right", "swipe right")
	_check(TouchInputScript.swipe_action(Vector2(-50, 20), t) == &"move_left", "swipe left")
	_check(TouchInputScript.swipe_action(Vector2(10, -50), t) == &"jump", "swipe up = jump")
	_check(TouchInputScript.swipe_action(Vector2(-10, 50), t) == &"slide", "swipe down = slide")
	_check(TouchInputScript.is_tap(4.0, 0.1, t, 0.22), "quick still touch is a tap")
	_check(not TouchInputScript.is_tap(4.0, 0.5, t, 0.22), "long press is not a tap")
	_check(not TouchInputScript.is_tap(30.0, 0.1, t, 0.22), "moving touch is not a tap")


func _test_placeholder_audio() -> void:
	for sound: StringName in PlaceholderSfx.names():
		var stream: AudioStreamWAV = PlaceholderSfx.get_stream(sound)
		_check(stream != null and stream.data.size() > 1000, "placeholder sound '%s' generated" % sound)


func _test_tuning_panel() -> void:
	var tuning: MovementTuning = _tuning.duplicate() as MovementTuning
	var panel := TuningPanel.new()
	root.add_child(panel)
	panel.setup(tuning)
	_check(panel.control_count() >= 40, "tuning panel has a control per tunable (%d)" % panel.control_count())
	panel.open()
	var slider: HSlider = panel._sliders.get("run_speed")
	_check(slider != null and is_equal_approx(slider.value, tuning.run_speed), "tuning panel shows current values")
	if slider != null:
		slider.value = 25.0
		_check(is_equal_approx(tuning.run_speed, 25.0), "moving a slider edits the tuning live")
	panel.queue_free()
	await process_frame


# --- Movement (real physics, hand-built layouts) -------------------------------

func _test_movement() -> void:
	var r: Dictionary

	r = await _simulate(_layout(3), 1, 3.0, [])
	_check(r["alive"] and r["surface"] == "floor", "flat run survives")
	_check(absf(r["distance"] - _tuning.run_speed * 3.0) < 1.0, "runs at run_speed (%.1f m)" % r["distance"])

	# Gaps
	var gap := _layout(3)
	gap.gaps.append({"lane": 1, "start": 30.0, "end": 36.0})
	r = await _simulate(gap, 1, 3.0, [])
	_check(not r["alive"] and r["cause"] == "fell", "running into a gap falls (%s)" % r["cause"])
	r = await _simulate(gap, 1, 3.0, [[27.0, &"jump"]])
	_check(r["alive"], "jumping a gap survives (%s)" % r["cause"])
	r = await _simulate(gap, 1, 3.0, [[20.0, &"move_left"]])
	_check(r["alive"] and r["lane"] == 0, "switching away from a gap survives")
	r = await _simulate(gap, 0, 3.0, [[29.0, &"move_right"]])
	_check(not r["alive"] and r["cause"] == "fell", "switching into a gapped lane falls (%s)" % r["cause"])
	r = await _simulate(gap, 1, 3.0, [[29.5, &"jump"]])
	_check(r["alive"], "coyote-time jump at the gap edge survives (%s)" % r["cause"])
	r = await _simulate(gap, 1, 2.0, [[10.0, &"jump"], [21.0, &"jump"]])
	_check(r["events"].count(&"jump") == 2, "a jump pressed just before landing fires on landing (buffer)")

	# Fences
	var full := _layout(3)
	full.fences.append(_fence(1, 30.0, "full"))
	r = await _simulate(full, 1, 3.0, [])
	_check(not r["alive"] and r["cause"].begins_with("fence"), "running into a full fence dies (%s)" % r["cause"])
	r = await _simulate(full, 1, 3.0, [[25.0, &"jump"]])
	_check(r["alive"], "jumping a full fence survives (%s)" % r["cause"])
	r = await _simulate(full, 1, 3.0, [[25.0, &"slide"]])
	_check(not r["alive"], "sliding into a full fence dies")

	var gapped := _layout(3)
	gapped.fences.append(_fence(1, 30.0, "gapped"))
	r = await _simulate(gapped, 1, 3.0, [])
	_check(not r["alive"], "running into a gapped fence dies")
	r = await _simulate(gapped, 1, 3.0, [[25.0, &"slide"]])
	_check(r["alive"], "sliding under a gapped fence survives (%s)" % r["cause"])
	r = await _simulate(gapped, 1, 3.0, [[25.0, &"jump"]])
	_check(not r["alive"], "jumping into a gapped fence dies")
	r = await _simulate(gapped, 1, 3.0, [[18.0, &"jump"], [22.0, &"slide"]], [29.0])
	_check(r["alive"] and r["at"][29.0]["sliding"], "air slide drops fast and slides under (%s)" % r["cause"])

	# Collision is swept: a thin fence can't be skipped between physics frames at any speed.
	var fast: MovementTuning = _tuning.duplicate() as MovementTuning
	fast.run_speed = 90.0
	var thin := _layout(3)
	thin.fences.append(_fence(1, 100.0, "full"))
	r = await _simulate(thin, 1, 2.0, [], [], fast)
	_check(not r["alive"] and r["cause"].begins_with("fence"), "no tunnelling through a fence at 90 m/s (%s)" % r["cause"])

	# Pulsing fences follow the level clock, even when their chunk is built mid-level.
	# Arrival at ~230 m is at ~12.8 s: phase 0 => ON (dies), phase 0.25 => OFF (survives).
	var pulse := _layout(3)
	var f_pulse := _fence(1, 230.0, "full")
	f_pulse["pulsing"] = true
	pulse.fences.append(f_pulse)
	r = await _simulate(pulse, 1, 13.2, [])
	_check(not r["alive"] and r["cause"].contains("pulsing"), "pulsing fence ON at arrival kills (%s)" % r["cause"])
	var pulse_off := pulse.copy()
	pulse_off.fences[0]["phase"] = 0.25
	r = await _simulate(pulse_off, 1, 13.2, [])
	_check(r["alive"], "pulsing fence OFF at arrival is safe (%s)" % r["cause"])

	# Walls
	var walls := _layout(3)
	r = await _simulate(walls, 2, 0.8, [[10.0, &"move_right"]])
	_check(r["surface"] == "wall" and r["events"].has(&"wall_enter"), "moving past the outer lane enters the wall")
	r = await _simulate(walls, 2, 3.5, [[10.0, &"move_right"]])
	_check(r["alive"] and r["surface"] == "floor" and r["lane"] == 2, "wall run ends back in the outer lane")
	r = await _simulate(walls, 0, 1.2, [[10.0, &"move_left"], [20.0, &"jump"]])
	_check(r["alive"] and r["surface"] == "floor" and r["lane"] == 0 and r["events"].has(&"wall_jump"),
		"wall jump returns to the lanes")
	r = await _simulate(walls, 0, 1.2, [[10.0, &"move_left"], [20.0, &"move_right"]])
	_check(r["surface"] == "floor", "moving inward leaves the wall")
	r = await _simulate(walls, 2, 1.2, [[10.0, &"jump"], [12.0, &"jump"], [12.5, &"move_right"]], [16.0])
	_check(r["at"][16.0]["surface"] == "wall", "a jump buffered in the air doesn't instantly wall-jump after entry")

	var outer_gap := _layout(3)
	outer_gap.gaps.append({"lane": 2, "start": 30.0, "end": 36.0})
	r = await _simulate(outer_gap, 2, 2.5, [[30.6, &"move_right"]], [33.0])
	_check(r["at"][33.0]["surface"] == "wall", "wall entry within coyote time at a gap edge works")
	r = await _simulate(outer_gap, 2, 2.5, [[32.1, &"move_right"]])
	_check(not r["alive"] and r["cause"] == "fell" and not r["events"].has(&"wall_enter"),
		"no wall entry once already falling into a gap (%s)" % r["cause"])

	# Signs
	var high_sign := _layout(3)
	high_sign.signs.append({"side": 1, "start": 40.0, "end": 50.0, "bottom": 2.8, "top": 5.5})
	r = await _simulate(high_sign, 2, 3.5, [[10.0, &"move_right"]], [45.0])
	_check(r["alive"] and r["at"][45.0]["surface"] == "wall", "late in a wall run the player passes under a high sign (%s)" % r["cause"])
	r = await _simulate(high_sign, 2, 2.6, [[42.0, &"move_right"]], [45.0])
	_check(r["at"][45.0]["surface"] == "floor" and r["events"].has(&"wall_blocked"), "a sign blocks wall entry")

	var tall_sign := _layout(3)
	tall_sign.signs.append({"side": 1, "start": 25.0, "end": 35.0, "bottom": 0.0, "top": 5.5})
	r = await _simulate(tall_sign, 2, 3.0, [[10.0, &"move_right"]])
	_check(not r["alive"] and r["cause"] == "sign", "running along the wall into a sign dies (%s)" % r["cause"])

	# Ramps
	var ramp := _layout(3)
	ramp.ramps.append({"side": 1, "at": 20.0})
	r = await _simulate(ramp, 2, 1.45, [])
	_check(r["surface"] == "wall" and r["events"].has(&"ramp") and r["max_wall_h"] > _tuning.wall_entry_height + 0.5,
		"ramp launches higher onto the wall (max %.2f m)" % r["max_wall_h"])

	# Ceiling
	var hull := _layout(3)
	hull.pads.append({"lane": 1, "at": 20.0})
	hull.hulls.append({"start": 17.0, "end": 70.0})
	r = await _simulate(hull, 1, 2.0, [])
	_check(r["alive"] and r["surface"] == "ceiling" and r["grounded"], "anti-grav pad puts the player on the ceiling")
	r = await _simulate(hull, 1, 2.2, [[30.0, &"move_left"]])
	_check(r["alive"] and r["lane"] == 0 and r["surface"] == "ceiling", "lane switching works on the ceiling")
	r = await _simulate(hull, 1, 5.0, [])
	_check(r["alive"] and r["surface"] == "floor" and r["grounded"] and r["events"].has(&"hull_end"),
		"hull end drops the player back to the floor")
	var hull_fence := hull.copy()
	hull_fence.fences.append(_fence(1, 45.0, "full"))
	r = await _simulate(hull_fence, 1, 4.0, [], [45.0])
	_check(r["alive"] and r["at"][45.0]["surface"] == "ceiling", "the ceiling passes over floor fences (%s)" % r["cause"])

	# Lane counts
	var six := _layout(6)
	six.gaps.append({"lane": 0, "start": 40.0, "end": 45.0})
	r = await _simulate(six, 2, 3.0, [[10.0, &"move_left"], [14.0, &"move_left"], [18.0, &"move_left"]], [30.0])
	_check(r["at"][30.0]["surface"] == "wall", "6 lanes: three moves left reach the left wall")
	r = await _simulate(six, 3, 1.0, [[10.0, &"move_right"], [13.0, &"move_right"]])
	_check(r["lane"] == 5, "6 lanes: lane switching works (lane %d)" % r["lane"])


func _layout(lanes: int) -> LevelLayout:
	var layout := LevelLayout.new()
	layout.lane_count = lanes
	layout.length = 400.0
	return layout


func _fence(lane: int, at: float, variant: String) -> Dictionary:
	return {"lane": lane, "at": at, "variant": variant, "pulsing": false,
		"pulse_on": 1.0, "pulse_off": 1.0, "phase": 0.0}


## Runs a player over `layout` for `seconds` of physics time.
## `actions`: [distance, action] pairs, each fired once when the player reaches that distance.
## `probes`: distances at which to record the player's state in result["at"][distance].
func _simulate(layout: LevelLayout, start_lane: int, seconds: float, actions: Array,
		probes: Array = [], tuning: MovementTuning = _tuning) -> Dictionary:
	var world := Node3D.new()
	root.add_child(world)
	var track := TrackBuilder.new()
	world.add_child(track)
	track.set_layout(layout, tuning)
	track.update(0.0, 0.0)
	var player := Player.new()
	world.add_child(player)
	player.setup(tuning, TrackGeometry.new(layout.lane_count, tuning), start_lane)
	var result := {"cause": "", "max_wall_h": 0.0, "events": [], "at": {}}
	player.died.connect(func(cause: String) -> void: result["cause"] = cause)
	player.movement_event.connect(func(kind: StringName) -> void: result["events"].append(kind))
	await physics_frame
	await physics_frame
	player.running = true
	var pending: Array = actions.duplicate()
	var pending_probes: Array = probes.duplicate()
	var frames: int = int(seconds * Engine.physics_ticks_per_second)
	for i: int in frames:
		while not pending.is_empty() and player.distance >= float(pending[0][0]):
			player.press(pending.pop_front()[1])
		track.update(player.distance, player.elapsed)
		await physics_frame
		while not pending_probes.is_empty() and player.distance >= float(pending_probes[0]):
			result["at"][pending_probes.pop_front()] = {"surface": player.surface_name(), "lane": player.lane,
				"h": player.h, "sliding": player.is_sliding(), "alive": player.alive}
		if player.surface == Player.Surface.WALL:
			result["max_wall_h"] = maxf(result["max_wall_h"], player.h)
		if not player.alive:
			break
	for d: Variant in pending_probes:
		result["at"][d] = {"surface": "not reached", "lane": -1, "h": 0.0, "sliding": false, "alive": player.alive}
	result["alive"] = player.alive
	result["surface"] = player.surface_name()
	result["lane"] = player.lane
	result["distance"] = player.distance
	result["grounded"] = player.grounded
	world.queue_free()
	await process_frame
	return result

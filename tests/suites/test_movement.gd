extends TestSuite
## Movement scenarios on real physics over hand-built layouts.

var sim: RunSim


func run() -> void:
	sim = RunSim.new(tree, tuning)
	var r: Dictionary

	r = await sim.run(RunSim.layout(3), 1, 3.0, [])
	check(r["alive"] and r["surface"] == "floor", "flat run survives")
	check(absf(r["distance"] - tuning.run_speed * 3.0) < 1.0, "runs at run_speed (%.1f m)" % r["distance"])

	# Gaps
	var gap := RunSim.layout(3)
	gap.gaps.append({"lane": 1, "start": 30.0, "end": 36.0})
	r = await sim.run(gap, 1, 3.0, [])
	check(not r["alive"] and r["cause"] == "fell", "running into a gap falls (%s)" % r["cause"])
	r = await sim.run(gap, 1, 3.0, [[27.0, &"jump"]])
	check(r["alive"], "jumping a gap survives (%s)" % r["cause"])
	r = await sim.run(gap, 1, 3.0, [[20.0, &"move_left"]])
	check(r["alive"] and r["lane"] == 0, "switching away from a gap survives")
	r = await sim.run(gap, 0, 3.0, [[29.0, &"move_right"]])
	check(not r["alive"] and r["cause"] == "fell", "switching into a gapped lane falls (%s)" % r["cause"])
	r = await sim.run(gap, 1, 3.0, [[29.5, &"jump"]])
	check(r["alive"], "coyote-time jump at the gap edge survives (%s)" % r["cause"])
	r = await sim.run(gap, 1, 2.0, [[10.0, &"jump"], [21.0, &"jump"]])
	check(r["events"].count(&"jump") == 2, "a jump pressed just before landing fires on landing (buffer)")

	# Fences
	var full := RunSim.layout(3)
	full.fences.append(RunSim.fence(1, 30.0, "full"))
	r = await sim.run(full, 1, 3.0, [])
	check(not r["alive"] and r["cause"].begins_with("fence"), "running into a full fence dies (%s)" % r["cause"])
	r = await sim.run(full, 1, 3.0, [[25.0, &"jump"]])
	check(r["alive"], "jumping a full fence survives (%s)" % r["cause"])
	r = await sim.run(full, 1, 3.0, [[25.0, &"slide"]])
	check(not r["alive"], "sliding into a full fence dies")

	var gapped := RunSim.layout(3)
	gapped.fences.append(RunSim.fence(1, 30.0, "gapped"))
	r = await sim.run(gapped, 1, 3.0, [])
	check(not r["alive"], "running into a gapped fence dies")
	r = await sim.run(gapped, 1, 3.0, [[25.0, &"slide"]])
	check(r["alive"], "sliding under a gapped fence survives (%s)" % r["cause"])
	r = await sim.run(gapped, 1, 3.0, [[25.0, &"jump"]])
	check(not r["alive"], "jumping into a gapped fence dies")
	r = await sim.run(gapped, 1, 3.0, [[18.0, &"jump"], [22.0, &"slide"]], [29.0])
	check(r["alive"] and r["at"][29.0]["sliding"], "air slide drops fast and slides under (%s)" % r["cause"])

	# Collision is swept: a thin fence can't be skipped between physics frames at any speed.
	var fast: MovementTuning = tuning.duplicate() as MovementTuning
	fast.run_speed = 90.0
	var thin := RunSim.layout(3)
	thin.fences.append(RunSim.fence(1, 100.0, "full"))
	r = await sim.run(thin, 1, 2.0, [], [], fast)
	check(not r["alive"] and r["cause"].begins_with("fence"), "no tunnelling through a fence at 90 m/s (%s)" % r["cause"])

	# Pulsing fences follow the level clock, even when their chunk is built mid-level.
	# Arrival at ~230 m is at ~12.8 s: phase 0 => ON (dies), phase 0.25 => OFF (survives).
	var pulse := RunSim.layout(3)
	var f_pulse := RunSim.fence(1, 230.0, "full")
	f_pulse["pulsing"] = true
	pulse.fences.append(f_pulse)
	r = await sim.run(pulse, 1, 13.2, [])
	check(not r["alive"] and r["cause"].contains("pulsing"), "pulsing fence ON at arrival kills (%s)" % r["cause"])
	var pulse_off := pulse.copy()
	pulse_off.fences[0]["phase"] = 0.25
	r = await sim.run(pulse_off, 1, 13.2, [])
	check(r["alive"], "pulsing fence OFF at arrival is safe (%s)" % r["cause"])

	# Walls
	var walls := RunSim.layout(3)
	r = await sim.run(walls, 2, 0.8, [[10.0, &"move_right"]])
	check(r["surface"] == "wall" and r["events"].has(&"wall_enter"), "moving past the outer lane enters the wall")
	r = await sim.run(walls, 2, 3.5, [[10.0, &"move_right"]])
	check(r["alive"] and r["surface"] == "floor" and r["lane"] == 2, "wall run ends back in the outer lane")
	r = await sim.run(walls, 0, 1.2, [[10.0, &"move_left"], [20.0, &"jump"]])
	check(r["alive"] and r["surface"] == "floor" and r["lane"] == 0 and r["events"].has(&"wall_jump"),
		"wall jump returns to the lanes")
	r = await sim.run(walls, 0, 1.2, [[10.0, &"move_left"], [20.0, &"move_right"]])
	check(r["surface"] == "floor", "moving inward leaves the wall")
	r = await sim.run(walls, 2, 1.2, [[10.0, &"jump"], [12.0, &"jump"], [12.5, &"move_right"]], [16.0])
	check(r["at"][16.0]["surface"] == "wall", "a jump buffered in the air doesn't instantly wall-jump after entry")

	var outer_gap := RunSim.layout(3)
	outer_gap.gaps.append({"lane": 2, "start": 30.0, "end": 36.0})
	r = await sim.run(outer_gap, 2, 2.5, [[30.6, &"move_right"]], [33.0])
	check(r["at"][33.0]["surface"] == "wall", "wall entry within coyote time at a gap edge works")
	r = await sim.run(outer_gap, 2, 2.5, [[32.1, &"move_right"]])
	check(not r["alive"] and r["cause"] == "fell" and not r["events"].has(&"wall_enter"),
		"no wall entry once already falling into a gap (%s)" % r["cause"])

	# Signs
	var high_sign := RunSim.layout(3)
	high_sign.signs.append({"side": 1, "start": 40.0, "end": 50.0, "bottom": 2.8, "top": 5.5})
	r = await sim.run(high_sign, 2, 3.5, [[10.0, &"move_right"]], [45.0])
	check(r["alive"] and r["at"][45.0]["surface"] == "wall", "late in a wall run the player passes under a high sign (%s)" % r["cause"])
	r = await sim.run(high_sign, 2, 2.6, [[42.0, &"move_right"]], [45.0])
	check(r["at"][45.0]["surface"] == "floor" and r["events"].has(&"wall_blocked"), "a sign blocks wall entry")

	var tall_sign := RunSim.layout(3)
	tall_sign.signs.append({"side": 1, "start": 25.0, "end": 35.0, "bottom": 0.0, "top": 5.5})
	r = await sim.run(tall_sign, 2, 3.0, [[10.0, &"move_right"]])
	check(not r["alive"] and r["cause"] == "sign", "running along the wall into a sign dies (%s)" % r["cause"])

	# Ramps
	var ramp := RunSim.layout(3)
	ramp.ramps.append({"side": 1, "at": 20.0})
	r = await sim.run(ramp, 2, 1.45, [])
	check(r["surface"] == "wall" and r["events"].has(&"ramp") and r["max_wall_h"] > tuning.wall_entry_height + 0.5,
		"ramp launches higher onto the wall (max %.2f m)" % r["max_wall_h"])

	# Ceiling
	var hull := RunSim.layout(3)
	hull.pads.append({"lane": 1, "at": 20.0})
	hull.hulls.append({"start": 17.0, "end": 70.0})
	r = await sim.run(hull, 1, 2.0, [])
	check(r["alive"] and r["surface"] == "ceiling" and r["grounded"], "anti-grav pad puts the player on the ceiling")
	r = await sim.run(hull, 1, 2.2, [[30.0, &"move_left"]])
	check(r["alive"] and r["lane"] == 0 and r["surface"] == "ceiling", "lane switching works on the ceiling")
	r = await sim.run(hull, 1, 5.0, [])
	check(r["alive"] and r["surface"] == "floor" and r["grounded"] and r["events"].has(&"hull_end"),
		"hull end drops the player back to the floor")
	var hull_fence := hull.copy()
	hull_fence.fences.append(RunSim.fence(1, 45.0, "full"))
	r = await sim.run(hull_fence, 1, 4.0, [], [45.0])
	check(r["alive"] and r["at"][45.0]["surface"] == "ceiling", "the ceiling passes over floor fences (%s)" % r["cause"])

	# Lane counts
	var six := RunSim.layout(6)
	six.gaps.append({"lane": 0, "start": 40.0, "end": 45.0})
	r = await sim.run(six, 2, 3.0, [[10.0, &"move_left"], [14.0, &"move_left"], [18.0, &"move_left"]], [30.0])
	check(r["at"][30.0]["surface"] == "wall", "6 lanes: three moves left reach the left wall")
	r = await sim.run(six, 3, 1.0, [[10.0, &"move_right"], [13.0, &"move_right"]])
	check(r["lane"] == 5, "6 lanes: lane switching works (lane %d)" % r["lane"])

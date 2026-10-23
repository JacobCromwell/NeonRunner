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

	await _test_ramp_boost()
	_test_ramp_launch_math()
	await _test_ramp_wall_run()
	await _test_wall_bump()
	await _test_dismounts()


## GDD §3 (decided September 26, 2026): a ramp adds a speed boost that fades away the same way a speed
## pad's does. On real physics, the extra speed after a ramp and after a speed pad of the same size
## follow one curve, frame by frame: MovementTuning.boost_left, falling at boost_decay_per_second.
func _test_ramp_boost() -> void:
	check(tuning.ramp_speed_boost > 0.0, "a ramp adds a speed boost (%.1f m/s)" % tuning.ramp_speed_boost)
	var dt: float = 1.0 / Engine.physics_ticks_per_second
	var same: MovementTuning = tuning.duplicate() as MovementTuning
	same.speed_pad_boost = same.ramp_speed_boost
	var ramp := RunSim.layout(3)
	ramp.ramps.append({"side": 1, "at": 20.0})
	var pad := RunSim.layout(3)
	pad.speed_pads.append({"lane": 2, "at": 20.0})
	sim.trace = true
	var r: Dictionary = await sim.run(ramp, 2, 3.5, [], [], same)
	var p: Dictionary = await sim.run(pad, 2, 3.5, [], [], same)
	sim.trace = false
	var from_ramp: Array[float] = _extra_speed(r, same.run_speed)
	var from_pad: Array[float] = _extra_speed(p, same.run_speed)
	var fade: int = ceili(same.ramp_speed_boost / same.boost_decay_per_second / dt)
	check(from_ramp.size() > fade + 2 and from_pad.size() > fade + 2, "both boosts show (%d, %d frames)" % [from_ramp.size(), from_pad.size()])
	if from_ramp.size() <= fade + 2 or from_pad.size() <= fade + 2:
		return
	var off_curve: float = 0.0
	var apart: float = 0.0
	for j: int in fade + 2:
		off_curve = maxf(off_curve, absf(from_ramp[j] - same.boost_left(same.ramp_speed_boost, (j + 1) * dt)))
		apart = maxf(apart, absf(from_ramp[j] - from_pad[j]))
	check(from_ramp[0] > same.ramp_speed_boost - same.boost_decay_per_second * dt - 0.001,
		"the ramp's boost starts at its full size (%.2f m/s)" % from_ramp[0])
	check(off_curve < 0.0005, "it fades at boost_decay_per_second (%.4f m/s off the curve at most)" % off_curve)
	check(apart < 0.0005, "a ramp's boost fades exactly like a speed pad's (%.4f m/s apart at most)" % apart)
	check(from_ramp[fade + 1] == 0.0 and from_pad[fade + 1] == 0.0, "and both are gone after %.2f s" % (fade * dt))


## Extra speed above `run_speed` in a traced run, frame by frame from the first boosted frame on.
static func _extra_speed(r: Dictionary, run_speed: float) -> Array[float]:
	var out: Array[float] = []
	for s: Dictionary in r["trace"]:
		var extra: float = float(s["speed"]) - run_speed
		if extra > 0.0001 or not out.is_empty():
			out.append(maxf(extra, 0.0))
	return out


## RampLaunch's own arithmetic: time and distance agree, the boost has faded by the time it should,
## and without a boost it's the plain wall run at run speed.
func _test_ramp_launch_math() -> void:
	var ramp := {"side": -1, "at": 50.0}
	var launch := RampLaunch.of(ramp, tuning, tuning.run_speed)
	var fade: float = tuning.ramp_speed_boost / tuning.boost_decay_per_second
	check(is_equal_approx(launch.speed_at(0.0), tuning.run_speed + tuning.ramp_speed_boost)
		and is_equal_approx(launch.speed_at(fade + 0.01), tuning.run_speed),
		"a ramp launches at run speed plus its boost, and is back to run speed once the boost has faded")
	var worst: float = 0.0
	for i: int in 50:
		var t: float = i * 0.05
		worst = maxf(worst, absf(launch.time_at(launch.distance_at(t)) - t))
	check(worst < 0.0001, "time_at() undoes distance_at() (%.6f s at most)" % worst)
	check(is_equal_approx(launch.end() - launch.start,
		tuning.run_speed * launch.duration() + tuning.boost_distance(tuning.ramp_speed_boost, launch.duration())),
		"the wall run is run speed plus the fading boost, for its whole length")
	check(is_equal_approx(launch.height_at(tuning.wall_entry_time), launch.peak)
		and is_equal_approx(launch.height_at(launch.duration()), tuning.wall_exit_height)
		and is_equal_approx(launch.height_at_distance(launch.wall_reached()), launch.peak),
		"up to its peak by the wall, down to the exit height at the end")
	var body: Vector2 = launch.body_at(1.0)
	check(is_equal_approx(body.y - body.x, tuning.hurtbox_size.x) and is_equal_approx((body.x + body.y) * 0.5, launch.height_at(1.0)),
		"the body it predicts is the wall runner's hitbox")
	var flat: MovementTuning = tuning.duplicate() as MovementTuning
	flat.ramp_speed_boost = 0.0
	var plain := RampLaunch.of(ramp, flat, flat.run_speed)
	check(is_equal_approx(plain.end() - plain.start, flat.run_speed * plain.duration()),
		"without a boost it's the plain wall run at run speed")
	check(launch.end() > plain.end() + 1.0, "the boost carries the wall run %.1f m further" % (launch.end() - plain.end()))


## The ramp's wall run on real physics against RampLaunch, the prediction every generator rule about a
## ramp's wall run uses (the credits along it; B5's wall fences): at 3, 5 and 6 lanes, on both walls,
## the launch where it says, the same heights at the same times, the same speed, distances within a
## frame's motion, and the drop back into the ramp's lane where it says.
func _test_ramp_wall_run() -> void:
	var dt: float = 1.0 / Engine.physics_ticks_per_second
	var motion: float = tuning.run_speed * dt
	sim.trace = true
	for lanes: int in [3, 5, 6]:
		for side: int in [-1, 1]:
			var tag: String = "(lanes=%d, side %d)" % [lanes, side]
			var layout := RunSim.layout(lanes)
			var ramp := {"side": side, "at": 30.0}
			layout.ramps.append(ramp)
			var outer: int = layout.outer_lane(side)
			var r: Dictionary = await sim.run(layout, outer, 4.5, [])
			var launch := RampLaunch.of(ramp, tuning, tuning.run_speed)
			var trace: Array = r["trace"]
			var first: int = -1
			for i: int in trace.size():
				if trace[i]["surface"] == "wall":
					first = i
					break
			check(first >= 0 and r["events"].has(&"ramp"), "the ramp launches the player onto the wall " + tag)
			if first < 0:
				continue
			var d0: float = trace[first]["d"]
			check(d0 >= launch.start - 0.001 and d0 <= launch.start + motion + 0.001,
				"at the launch it predicts (%.2f m, predicted from %.2f m) %s" % [d0, launch.start, tag])
			var off_h: float = 0.0
			var off_v: float = 0.0
			var ahead := Vector2(INF, -INF)
			var last: int = first
			for j: int in range(first, trace.size()):
				var s: Dictionary = trace[j]
				if s["surface"] != "wall":
					break
				var t: float = (j - first) * dt
				off_h = maxf(off_h, absf(float(s["h"]) - launch.height_at(t)))
				if j > first:  # The launch frame's speed was set before the ramp added its boost.
					off_v = maxf(off_v, absf(float(s["speed"]) - launch.speed_at(t)))
				var d: float = float(s["d"]) - launch.distance_at(t)
				ahead = Vector2(minf(ahead.x, d), maxf(ahead.y, d))
				last = j
			check(off_h < 0.001, "the heights on the wall are the ones it predicts (%.4f m off at most) %s" % [off_h, tag])
			check(off_v < 0.001, "and so is the speed, boost and all (%.4f m/s off at most) %s" % [off_v, tag])
			check(ahead.x > -0.1 and ahead.y < motion + 0.1,
				"the distances too, within a frame's motion (%.2f to %.2f m ahead) %s" % [ahead.x, ahead.y, tag])
			var exit_d: float = float(trace[last + 1]["d"]) if last + 1 < trace.size() else INF
			check(exit_d > launch.end() - 0.1 and exit_d < launch.end() + 2.0 * motion + 0.1,
				"the wall run ends where it predicts (%.2f m, predicted %.2f m) %s" % [exit_d, launch.end(), tag])
			check(r["alive"] and r["surface"] == "floor" and r["lane"] == outer, "and the player drops back into the ramp's lane " + tag)
	sim.trace = false


## GDD §3 (decided September 26, 2026): a blocked wall entry plays the clank and a small sideways bump,
## out toward the wall and back, so the player sees why they didn't get on. The bump moves the player,
## not the collision: they stay in the outer lane, a sign that reaches down to them stops the bump at
## its face so it never hurts, and they can act again right after (a jump; the wall once past the
## sign). At 3, 5 and 6 lanes, on both walls.
func _test_wall_bump() -> void:
	var half: float = tuning.visual_size.x * 0.5
	var bump_run: float = tuning.run_speed * tuning.wall_bump_time
	sim.trace = true
	for lanes: int in [3, 5, 6]:
		var geo := TrackGeometry.new(lanes, tuning)
		for side: int in [-1, 1]:
			var tag: String = "(lanes=%d, side %d)" % [lanes, side]
			var outer: int = lanes - 1 if side > 0 else 0
			var home: float = geo.lane_x(outer)
			var toward: StringName = &"move_right" if side > 0 else &"move_left"
			var inward: StringName = &"move_left" if side > 0 else &"move_right"
			# How far the body may go before it touches a sign that reaches down to the floor.
			var room: float = geo.wall_x() - tuning.sign_depth - half - absf(home)

			var low := RunSim.layout(lanes)
			low.signs.append({"side": side, "start": 20.0, "end": 36.0, "bottom": 0.0, "top": 2.3})
			var r: Dictionary = await sim.run(low, outer, 3.0, [[24.0, toward], [28.0, &"jump"], [42.0, toward]])
			var events: Array = r["events"]
			var out: float = _bump_peak(r, home, side, 24.0, 28.0)
			check(events.count(&"wall_blocked") == 1 and not events.slice(0, events.find(&"jump")).has(&"wall_enter"),
				"a sign blocks the wall entry, with the clank %s" % tag)
			check(out > 0.5 * room and out <= room + 0.0001,
				"the bump goes out toward the wall and stops at a low sign's face (%.3f m of %.3f) %s" % [out, room, tag])
			var back: Dictionary = _trace_at(r, 24.0 + bump_run + 0.7)
			check(absf(float(back.get("x", INF)) - home) < 0.001 and int(back.get("lane", -1)) == outer,
				"then it's back in the middle of the outer lane %s" % tag)
			var leans: Array = _trace_values(r, "lean", 24.0, 24.0 + bump_run + 0.4)
			check(leans.has(-side) and not leans.has(side), "the runner is pushed back: it leans away from the wall, never into the sign %s" % tag)
			check(events.find(&"jump") > events.find(&"wall_blocked") and events.find(&"wall_enter") > events.find(&"jump"),
				"right after, the player can jump, and past the sign the wall takes them (%s) %s" % [events, tag])
			check(r["alive"], "the bump never hurts (%s) %s" % [r["cause"], tag])

			# A sign high on the wall blocks the entry too; nothing is in the bump's way. (The frames
			# may miss the bump's very tip by up to a frame's share of it.)
			var high := RunSim.layout(lanes)
			high.signs.append({"side": side, "start": 20.0, "end": 36.0, "bottom": 2.8, "top": 5.5})
			r = await sim.run(high, outer, 2.0, [[24.0, toward]])
			out = _bump_peak(r, home, side, 24.0, 30.0)
			var tip: float = 2.0 * tuning.wall_bump_distance / (tuning.wall_bump_time * Engine.physics_ticks_per_second)
			check(r["events"].has(&"wall_blocked") and out > tuning.wall_bump_distance - tip and out <= tuning.wall_bump_distance + 0.0001
				and r["alive"] and r["lane"] == outer,
				"under a high sign the bump goes its full %.2f m (%.3f m) %s" % [tuning.wall_bump_distance, out, tag])

			# Pressing again mid-bump clanks and bumps again, still never past the sign's face; a move
			# inward mid-bump just goes.
			r = await sim.run(low, outer, 2.0, [[24.0, toward], [25.0, toward]])
			out = _bump_peak(r, home, side, 24.0, 30.0)
			check(r["events"].count(&"wall_blocked") == 2 and out <= room + 0.0001 and r["alive"] and r["lane"] == outer,
				"a second press mid-bump bumps again, no further than the sign's face (%.3f m) %s" % [out, tag])
			r = await sim.run(low, outer, 2.0, [[24.0, toward], [25.0, inward]])
			var moved: Dictionary = _trace_at(r, 32.0)
			check(r["lane"] == outer - side and absf(float(moved.get("x", INF)) - geo.lane_x(outer - side)) < 0.001,
				"a move inward mid-bump switches lanes as usual %s" % tag)

			# A ramp whose wall is blocked (say a boss has taken it away) clanks once, not every frame.
			var ramp := RunSim.layout(lanes)
			ramp.ramps.append({"side": side, "at": 30.0})
			ramp.signs.append({"side": side, "start": 26.0, "end": 40.0, "bottom": 0.0, "top": 5.5})
			r = await sim.run(ramp, outer, 2.5, [])
			check(r["events"].count(&"wall_blocked") == 1 and not r["events"].has(&"ramp") and r["alive"] and r["lane"] == outer,
				"a blocked ramp clanks and bumps once (%d) %s" % [r["events"].count(&"wall_blocked"), tag])
	sim.trace = false


## Task S3 (the owner, October 23, 2026: coming off the wall "must behave exactly as it does everywhere else in the
## game: one lane"). A move away from the wall while on it is a wall jump into the outer lane: one lane, anywhere on a
## free entry's wall run or a ramp's. Where a wall gap sets the runner down (LevelLayout.SETS_DOWN: an extended wall
## run's notch at its platform, test_extended_wall_runs), a move away until their wall run would have ended on a whole
## wall is still that dismount: one lane, landed or not; one after that, or a second one, switches lanes, and a move
## back toward the wall past the gap steps back on (Player._on_move). Everywhere else nothing changed: after the wall
## run's own end or a plain wall gap's drop a move away switches lanes, a move back toward the wall steps back on, and
## after a wall jump of their own (the jump) a move away is a lane switch. At 3, 5 and 6 lanes, on both walls.
func _test_dismounts() -> void:
	var v: float = tuning.run_speed
	var whole: float = tuning.wall_entry_time + tuning.wall_slide_time
	var on: float = 6.0
	var gap_at_wall: float = 1.0
	sim.trace = true
	for lanes: int in [3, 5, 6]:
		for side: int in [-1, 1]:
			var tag: String = "(lanes=%d, %s wall)" % [lanes, "left" if side < 0 else "right"]
			var outer: int = lanes - 1 if side > 0 else 0
			var toward: StringName = &"move_right" if side > 0 else &"move_left"
			var away: StringName = &"move_left" if side > 0 else &"move_right"
			var walls := RunSim.layout(lanes, 300.0)
			var seconds: float = (on + whole * v) / v + 0.8
			var r: Dictionary = await sim.run(walls, outer, seconds, [[on, toward]])
			var exit_at: float = _off_wall_at(r, 0.0)
			check(r["events"].has(&"wall_exit") and exit_at < INF and r["lane"] == outer,
				"a wall run left to its end drops back into the outer lane (%.1f m) %s" % [exit_at, tag])
			# A move away while on the wall: a wall jump, one lane.
			for at: float in [0.3, 2.0]:
				r = await sim.run(walls, outer, seconds, [[on, toward], [on + at * v, away]])
				check(r["alive"] and r["events"].has(&"wall_jump") and _lanes_seen(r) == [outer] and r["surface"] == "floor",
					"a move away %.1f s into the wall run is a wall jump into the outer lane, one lane (%s) %s"
					% [at, _lanes_seen(r), tag])
			# After the wall run's own end, as it always was.
			r = await sim.run(walls, outer, seconds, [[on, toward], [exit_at + 0.05 * v, away]])
			check(r["alive"] and r["lane"] == outer - side,
				"after the wall run's own end a move away switches lanes, as before (lane %d) %s" % [r["lane"], tag])
			r = await sim.run(walls, outer, seconds, [[on, toward], [exit_at + 0.05 * v, toward]], [exit_at + 0.5 * v])
			check(r["events"].count(&"wall_enter") == 2 and r["at"][exit_at + 0.5 * v]["surface"] == "wall",
				"and a move back toward the wall steps back on (%s) %s" % [r["events"], tag])
			r = await sim.run(walls, outer, seconds, [[on, toward], [on + 1.0 * v, &"jump"], [on + 1.1 * v, away]])
			check(r["alive"] and r["events"].has(&"wall_jump") and r["lane"] == outer - side,
				"after a wall jump of their own (the jump), a move away is a lane switch, as before (lane %d) %s" % [r["lane"], tag])

			# A plain wall gap drops the wall runner off: a move away after it switches lanes, as before; one before it is a
			# wall jump.
			var gap := {"side": side, "start": on + gap_at_wall * v, "end": on + gap_at_wall * v + 12.0}
			var plain := RunSim.layout(lanes, 300.0)
			plain.wall_gaps.append(gap.duplicate())
			r = await sim.run(plain, outer, seconds, [[on, toward]])
			var drop_at: float = _off_wall_at(r, 0.0)
			var rest: float = whole - (drop_at - _on_wall_at(r)) / v
			check(r["events"].has(&"wall_gap_drop") and absf(drop_at - float(gap["start"])) < 1.0 and rest > 0.8,
				"a wall gap drops the runner off (%.1f m, %.2f s of their wall run left) %s" % [drop_at, rest, tag])
			r = await sim.run(plain, outer, seconds, [[on, toward], [drop_at + 0.05 * v, away]])
			check(r["alive"] and r["lane"] == outer - side,
				"after a plain wall gap's drop a move away switches lanes, as before (lane %d) %s" % [r["lane"], tag])
			r = await sim.run(plain, outer, seconds, [[on, toward], [drop_at - 0.1 * v, away]])
			check(r["alive"] and r["events"].has(&"wall_jump") and _lanes_seen(r) == [outer],
				"a move away just before it is a wall jump, one lane (%s) %s" % [_lanes_seen(r), tag])

			# The same gap setting the runner down (an extended wall run's notch).
			var sets := RunSim.layout(lanes, 300.0)
			var marked: Dictionary = gap.duplicate()
			marked[LevelLayout.SETS_DOWN] = true
			sets.wall_gaps.append(marked)
			for after: float in [0.0, rest - 0.1]:
				r = await sim.run(sets, outer, seconds, [[on, toward], [drop_at + after * v, away]])
				check(r["alive"] and r["events"].has(&"wall_gap_drop") and _lanes_seen(r) == [outer] and r["lane"] == outer,
					"set down, a move away %.2f s after the drop (their wall run not yet over) is the dismount: one lane (%s) %s"
					% [after, _lanes_seen(r), tag])
			r = await sim.run(sets, outer, seconds, [[on, toward], [drop_at + (rest + 0.15) * v, away]])
			check(r["alive"] and r["lane"] == outer - side,
				"once their wall run would have ended, a move away switches lanes (lane %d) %s" % [r["lane"], tag])
			r = await sim.run(sets, outer, seconds, [[on, toward], [drop_at + 0.05 * v, away], [drop_at + 0.3 * v, away]])
			check(r["alive"] and r["lane"] == outer - side, "and so does a second move away (lane %d) %s" % [r["lane"], tag])
			var past: float = float(gap["end"]) + 1.0
			r = await sim.run(sets, outer, seconds, [[on, toward], [past, toward]], [past + 0.4 * v])
			check(r["events"].count(&"wall_enter") == 2 and r["at"][past + 0.4 * v]["surface"] == "wall",
				"a move back toward the wall past the gap steps back on (%s) %s" % [r["events"], tag])

			# A ramp's wall run: a wall jump on it, a lane switch after its own end, as before.
			var ramp := RunSim.layout(lanes, 300.0)
			ramp.ramps.append({"side": side, "at": 20.0})
			var launch := RampLaunch.of(ramp.ramps[0], tuning, v)
			r = await sim.run(ramp, outer, launch.end() / v + 0.8, [[launch.distance_at(1.0), away]])
			check(r["alive"] and r["events"].has(&"wall_jump") and _lanes_seen(r) == [outer],
				"a move away on a ramp's wall run is a wall jump, one lane (%s) %s" % [_lanes_seen(r), tag])
			r = await sim.run(ramp, outer, launch.end() / v + 0.8, [[launch.end() + 0.06 * v, away]])
			check(r["alive"] and r["events"].has(&"wall_exit") and r["lane"] == outer - side,
				"after a ramp's wall run's own end a move away switches lanes, as before (lane %d) %s" % [r["lane"], tag])
	sim.trace = false


## The distance of the first traced frame on a wall (INF if the runner never got on one).
static func _on_wall_at(r: Dictionary) -> float:
	for s: Dictionary in r["trace"]:
		if s["surface"] == "wall":
			return float(s["d"])
	return INF


## The distance of the first traced frame off the wall after `from`, once the runner has been on it (where they left
## it); INF if they never did.
static func _off_wall_at(r: Dictionary, from: float) -> float:
	var on: bool = false
	for s: Dictionary in r["trace"]:
		if float(s["d"]) < from:
			continue
		if s["surface"] == "wall":
			on = true
		elif on:
			return float(s["d"])
	return INF


## The lanes the runner was in over a traced run, in order, each once.
static func _lanes_seen(r: Dictionary) -> Array:
	var out: Array = []
	for s: Dictionary in r["trace"]:
		if out.is_empty() or out[-1] != s["lane"]:
			out.append(s["lane"])
	return out


## The furthest the player got toward the wall on `side` from `home` (world x) between two distances.
static func _bump_peak(r: Dictionary, home: float, side: int, from: float, to: float) -> float:
	var out: float = 0.0
	for s: Dictionary in r["trace"]:
		if float(s["d"]) >= from and float(s["d"]) <= to:
			out = maxf(out, side * (float(s["x"]) - home))
	return out


## The first traced frame at or past distance `d` ({} if the run didn't get there).
static func _trace_at(r: Dictionary, d: float) -> Dictionary:
	for s: Dictionary in r["trace"]:
		if float(s["d"]) >= d:
			return s
	return {}


## The distinct values of one traced field between two distances.
static func _trace_values(r: Dictionary, key: String, from: float, to: float) -> Array:
	var out: Array = []
	for s: Dictionary in r["trace"]:
		if float(s["d"]) >= from and float(s["d"]) <= to and not out.has(s[key]):
			out.append(s[key])
	return out

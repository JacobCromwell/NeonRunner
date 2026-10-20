extends TestSuite
## The debris maze (task O2; the owner, October 20, 2026, GDD §5 Zone 8: in the Terminal "doodads stand so thickly that
## the empty space between them forms a maze, and the runner can't get through without dashing"; a doodad "stops the
## runner here instead of pushing them aside"; "the dash recharges as usual"; the Terminal's doodads are lower).
## - The stop on real physics (Player.doodads_stop) at 3, 5 and 6 lanes: running into a doodad's front brings the
##   runner to a complete stop facing it, once, costing nothing but time (alive, no push, the level clock running on,
##   the distance waiting, `speed` reading 0), the body never sinking into it; they set off by switching into a lane open
##   beside them (at the run speed again) or by dashing through (smashed, on at the dash's speed); a switch into a lane
##   with a doodad beside them is a blocked move (the clank), and they stay stopped; a stopped runner moves along the face
##   of a wall of debris to its opening and runs through it; a jump or a slide while stopped plays out in place; a jump
##   into one comes down in front of it; a switch toward a lane with a doodad just ahead is refused (it would meet its
##   side), one further ahead stops them at its front; a front corner caught mid-switch stops them, never sinking in; a
##   body caught in a doodad's side all the same moves back out with the clank (Player._start_bounce); the dash smashes
##   one before contact; with the flag off the same doodad pushes, as before; in a full world the stop plays the push's
##   thud and the score is untouched.
## - The lower doodads (LevelConfig.doodad_height through movement_for): the Terminal's levels' boxes on the track are
##   their height, still out of a jump's reach, and every other level's as before.
## - The generator (DebrisMaze, debris_maze_rules.gd) over the Terminal's levels and other seeds at 3, 5 and 6 lanes:
##   every build passes LayoutChecks.check_debris_maze (the blocks' structure, a dash needed, finishable at the dash's
##   slowest recharge with waits, no hole near, the ceilings over the maze), the same level every time, the maze over
##   most of Rubble Line and in stretches of Last Stop, both one and two breaks in Rubble Line's blocks, dead ends and
##   cells walled in; the API for what lives in the maze (sections, links, open_group, section_at) consistent with the
##   debris, and with what dashes smash (a wall broken into a divider's lane, a divider's end into the next wall, an edge
##   lane's divider, and random smashes against a flood fill of the free floor); endless mode's 20-minute copy of Last
##   Stop on arbitrary seeds, without warnings and keeping every rule of the maze; a level without the feature has none
##   of it.
## - The bot on real physics: a block of each Terminal level at 3, 5 and 6 lanes run by the route MazeRoute finds, the
##   dash at its slowest recharge (8 s), dashing where the route does and waiting for it: it gets through alive, never
##   refused a switch, in about the route's time; and each whole level the same way, from its start to its end-clear
##   stretch (a real run: the maze, the normal track's doodads and holes and all).
## - The first-encounter hint (data/hints/hints.json, trigger debris_maze): it says debris stops the runner and names the
##   lane switch and the dash, and is picked for a level with a maze, at its first wall (HintDirector), not without one.

## Seeds besides each level's own the generator sweep builds.
const OTHER_SEEDS: Array[int] = [8911, 8912, 8913]
## How far the body may sink into a doodad on a frame (metres): never more than rounding.
const SINK_TOLERANCE: float = 0.03
## The dash's slowest recharge (PowerupTuning.dash_cooldown, tier I; GDD §8: 8, 6, 4 and 3 seconds).
const SLOWEST_RECHARGE: float = 8.0

var sim: RunSim


func run() -> void:
	sim = RunSim.new(tree, tuning)
	sim.trace = true
	await _test_stop()
	await _test_switch_out()
	await _test_wall_face()
	await _test_dash()
	await _test_jump_and_slide()
	await _test_switch_ahead()
	await _test_bounce()
	await _test_pushes_without_flag()
	await _test_full_world()
	await _test_lower_doodads()
	_test_generator()
	_test_endless()
	_test_without_feature()
	await _test_bot()
	await _test_bot_levels()
	_test_hint()


## The first-encounter hint (see the header).
func _test_hint() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/hints/hints.json"))
	var hint: Dictionary = {}
	for h: Dictionary in (parsed as Dictionary).get("hints", []):
		if String(h.get("id", "")) == "debris_maze":
			hint = h
	var text: String = String(hint.get("text", ""))
	check(String(hint.get("trigger", "")) == "debris_maze" and text.to_lower().contains("stops you")
		and text.contains("{dash}") and text.contains("{move_left}") and text.contains("{move_right}"),
		"the hint says debris stops the runner, and names the lane switch and the dash (%s)" % [hint])
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var config: LevelConfig = campaign.configure(campaign.step("terminal/1"), 5)
	var maze: LevelLayout = LayoutCache.generate(config, tuning, LevelGenerator.load_for(config))
	for with_maze: bool in [true, false]:
		var world := RunWorld.new()
		world.config = config if with_maze else LevelConfig.new()
		world.layout = maze if with_maze else RunSim.layout(5)
		world.director = EnemyDirector.new()
		world.add_child(world.director)
		var director := HintDirector.new()
		director.setup(world, Profile.new(), false)
		var ids: Array = director.intro_hints.map(func(entry: Dictionary) -> String: return entry["id"])
		check(ids.has("debris_maze") == with_maze, "the hint is picked %s (%s)" % ["for a maze" if with_maze else "only with a maze",
			ids])
		if with_maze:
			check(is_equal_approx(float(director.call(&"_first_at", "debris_maze")), float(maze.maze[0]["start"])),
				"at the maze's first wall")
			for entry: Dictionary in director.intro_hints:
				if entry["id"] == "debris_maze":
					check(not String(entry["text"]).contains("{"), "its text names the keys (%s)" % entry["text"])
		director.free()
		world.free()


# --- The stop on real physics -------------------------------------------------------------------

## A doodad entry of `size` in `lane` from `start`.
func _doodad(lane: int, start: float, size: StringName = &"medium", side: int = 1) -> Dictionary:
	return {"lane": lane, "start": start, "end": start + tuning.doodad_size(size).z, "size": size, "side": side, "seed": 5}


## A plain layout of `lanes` lanes whose doodads stop the runner, holding copies of `doodads`.
func _stop_layout(lanes: int, doodads: Array) -> LevelLayout:
	var layout := RunSim.layout(lanes)
	layout.doodads_stop = true
	for d: Dictionary in doodads:
		layout.doodads.append(d.duplicate())
	return layout


## The most the visual body sank into doodad `d` over a run's trace (metres; 0 if it never touched it).
func _sink(trace: Array, d: Dictionary, geo: TrackGeometry) -> float:
	var box: Vector3 = tuning.doodad_size(StringName(d["size"]))
	var x0: float = geo.lane_x(int(d["lane"])) - box.x * 0.5
	var x1: float = geo.lane_x(int(d["lane"])) + box.x * 0.5
	var hx: float = tuning.visual_size.x * 0.5
	var hz: float = tuning.visual_size.z * 0.5
	var worst: float = 0.0
	for s: Dictionary in trace:
		# Once the dash has smashed it, it's gone: the body runs through where it stood.
		if String(s["surface"]) != "floor" or int(s.get("smashes", 0)) > 0:
			continue
		var x: float = float(s["x"])
		var dist: float = float(s["d"])
		var h: float = float(s["h"])
		var ox: float = minf(x + hx, x1) - maxf(x - hx, x0)
		var oz: float = minf(dist + hz, float(d["end"])) - maxf(dist - hz, float(d["start"]))
		var oy: float = minf(h + tuning.visual_size.y, box.y) - maxf(h, 0.0)
		if ox > 0.0 and oz > 0.0 and oy > 0.0:
			worst = maxf(worst, minf(ox, minf(oz, oy)))
	return worst


## The inner lanes of a track of `lanes` lanes, and its outer ones.
static func _lanes(lanes: int) -> Array[int]:
	var out: Array[int] = []
	for l: int in lanes:
		out.append(l)
	return out


## Head-on into a doodad, in every lane at 3, 5 and 6 lanes, small and large: one stop, facing it (the body's front a
## hair short of its front), standing (speed 0) while the level clock runs on, no push, no damage, never sinking in.
func _test_stop() -> void:
	for lanes: int in [3, 5, 6]:
		var geo := TrackGeometry.new(lanes, tuning)
		for lane: int in _lanes(lanes):
			for size: StringName in [&"small", &"large"]:
				var tag: String = "(lanes=%d, lane %d, %s)" % [lanes, lane, size]
				var d: Dictionary = _doodad(lane, 40.0, size)
				var r: Dictionary = await sim.run(_stop_layout(lanes, [d]), lane, 4.0, [])
				var trace: Array = r["trace"]
				var last: Dictionary = trace[-1]
				var events: Array = r["events"]
				var rest: float = float(d["start"]) - tuning.visual_size.z * 0.5 - Player.STOP_CLEARANCE
				check(r["alive"] and int(r["stops"]) == 1 and events.count(&"doodad_stop") == 1 and int(r["pushes"]) == 0
					and not events.has(&"doodad_push") and int(r["lane"]) == lane,
					"running into a doodad stops the runner once, in their lane, with no push and no harm %s: %s" % [tag, events])
				check(absf(float(r["distance"]) - rest) < 0.01, "they stop facing it, a hair short of its front (%.3f, %.3f) %s"
					% [r["distance"], rest, tag])
				check(bool(last["stopped"]) and absf(float(last["speed"])) < 0.001 and float(last["t"]) > 3.9,
					"standing, the level clock running on (%.2f s, speed %.2f) %s" % [last["t"], last["speed"], tag])
				var sink: float = _sink(trace, d, geo)
				check(sink <= SINK_TOLERANCE, "the body never sinks into it (%.3f m) %s" % [sink, tag])


## Stopped, then a switch into the lane open beside: they set off at the run speed and pass it; a switch toward a lane
## with a doodad beside them is a blocked move (the clank and the bump), and they stay stopped facing theirs.
func _test_switch_out() -> void:
	for lanes: int in [3, 5, 6]:
		var geo := TrackGeometry.new(lanes, tuning)
		for lane: int in _lanes(lanes):
			var tag: String = "(lanes=%d, lane %d)" % [lanes, lane]
			var d: Dictionary = _doodad(lane, 40.0, &"large")
			var to_lane: int = lane + 1 if lane + 1 < lanes else lane - 1
			var rest: float = float(d["start"]) - tuning.visual_size.z * 0.5 - Player.STOP_CLEARANCE
			# Stopped by ~1.6 s; the switch pressed once the body stands there (an action keyed to where it stands).
			var action: StringName = &"move_right" if to_lane > lane else &"move_left"
			var r: Dictionary = await sim.run(_stop_layout(lanes, [d]), lane, 3.5, [[rest - 0.001, action]])
			var trace: Array = r["trace"]
			var moved: bool = false
			for s: Dictionary in trace:
				moved = moved or float(s["d"]) > float(d["end"]) + 1.0
			check(r["alive"] and int(r["lane"]) == to_lane and moved and absf(float(trace[-1]["speed"]) - tuning.run_speed) < 0.01,
				"a switch into the lane open beside sets them off, at the run speed, past it %s (lane %d)" % [tag, r["lane"]])
			check(_sink(trace, d, geo) <= SINK_TOLERANCE, "setting off never sinks the body into it %s" % tag)
			# A doodad beside them in that lane (its side level with them): blocked, still stopped.
			var beside: Dictionary = _doodad(to_lane, 30.0, &"large")
			beside["end"] = 46.0
			var b: Dictionary = await sim.run(_stop_layout(lanes, [d, beside]), lane, 3.5, [[rest - 0.001, action]])
			var events: Array = b["events"]
			check(b["alive"] and int(b["lane"]) == lane and events.has(&"lane_blocked") and absf(float(b["distance"]) - rest) < 0.01
				and bool((b["trace"] as Array)[-1]["stopped"]),
				"a switch toward a doodad beside them is refused with the clank; they stay stopped %s: %s" % [tag, events])


## A wall of debris across every lane but one, the runner stopped at its far end from the opening: they move along its
## face lane by lane, stopped all the while (the distance waits), and run through the opening; every face they pass is
## level, and the body never sinks into any of it.
func _test_wall_face() -> void:
	for lanes: int in [3, 5, 6]:
		var geo := TrackGeometry.new(lanes, tuning)
		for size: StringName in [&"medium", &"large"]:
			var tag: String = "(lanes=%d, %s)" % [lanes, size]
			var wall: Array = []
			for lane: int in range(0, lanes - 1):
				wall.append(_doodad(lane, 40.0, size))
			var rest: float = 40.0 - tuning.visual_size.z * 0.5 - Player.STOP_CLEARANCE
			# One press a step along the face, each well after the last switch has played out (time, not distance:
			# the distance waits while they're stopped).
			var r: Dictionary = await _run_timed(_stop_layout(lanes, wall), 0, 6.0, rest, lanes - 1)
			var trace: Array = r["trace"]
			var through: bool = float(trace[-1]["d"]) > 40.0 + tuning.doodad_size(size).z + 2.0
			var held: bool = true
			for s: Dictionary in trace:
				if float(s["x"]) < geo.lane_x(lanes - 2) + 0.3 and float(s["t"]) > 2.0:
					held = held and float(s["d"]) <= rest + 0.02
			check(r["alive"] and int(r["lane"]) == lanes - 1 and through and int(r["blocked"]) == 0,
				"stopped at a wall's far end, they move along its face to the opening and run through %s (lane %d, %.1f m, %d refused)"
				% [tag, r["lane"], trace[-1]["d"], r["blocked"]])
			check(held, "they stay stopped while they move along the face %s" % tag)
			var sink: float = 0.0
			for d: Dictionary in wall:
				sink = maxf(sink, _sink(trace, d, geo))
			check(sink <= SINK_TOLERANCE, "the body never sinks into the wall (%.3f m) %s" % [sink, tag])


## Runs a Player over `layout` in `lane` for `seconds`: once it stands at `rest`, it moves right a lane at a time
## (a press each 0.4 s) until it's in `to_lane`. {alive, lane, blocked, trace}.
func _run_timed(layout: LevelLayout, lane: int, seconds: float, rest: float, to_lane: int) -> Dictionary:
	var world := Node3D.new()
	tree.root.add_child(world)
	var track := TrackBuilder.new()
	world.add_child(track)
	track.set_layout(layout, tuning)
	track.update(0.0, 0.0)
	var player := Player.new()
	world.add_child(player)
	player.setup(tuning, TrackGeometry.new(layout.lane_count, tuning), lane)
	player.doodads_stop = layout.doodads_stop
	player.wall_running = layout.wall_running
	var out := {"blocked": 0, "trace": []}
	player.movement_event.connect(func(kind: StringName) -> void:
		if kind == &"lane_blocked":
			out["blocked"] = int(out["blocked"]) + 1)
	await tree.physics_frame
	await tree.physics_frame
	player.running = true
	var next_press: float = -1.0
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		if player.stopped and player.distance >= rest - 0.01 and player.lane < to_lane and player.elapsed >= next_press:
			if next_press < 0.0:
				next_press = player.elapsed + 0.3
			else:
				player.press(&"move_right")
				next_press = player.elapsed + 0.4
		track.update(player.distance, player.elapsed)
		await tree.physics_frame
		(out["trace"] as Array).append({"t": player.elapsed, "d": player.distance, "x": player.position.x, "h": player.h,
			"surface": player.surface_name(), "stopped": player.stopped})
	out["alive"] = player.alive
	out["lane"] = player.lane
	world.queue_free()
	await tree.process_frame
	return out


## The dash through a doodad: from a stop it smashes it and they run on at the dash's speed, in their lane, no push; a
## dash begun running toward one smashes it before the body touches it, no stop.
func _test_dash() -> void:
	for lanes: int in [3, 5, 6]:
		var geo := TrackGeometry.new(lanes, tuning)
		for lane: int in _lanes(lanes):
			var tag: String = "(lanes=%d, lane %d)" % [lanes, lane]
			var d: Dictionary = _doodad(lane, 40.0, &"large")
			var rest: float = float(d["start"]) - tuning.visual_size.z * 0.5 - Player.STOP_CLEARANCE
			var r: Dictionary = await sim.run(_stop_layout(lanes, [d]), lane, 3.0, [[rest - 0.001, &"dash"]])
			var fast: bool = false
			for s: Dictionary in r["trace"]:
				fast = fast or float(s["speed"]) > tuning.run_speed + 1.0
			check(r["alive"] and int(r["smashes"]) == 1 and int(r["pushes"]) == 0 and int(r["lane"]) == lane and fast
				and float(r["distance"]) > float(d["end"]) + 5.0,
				"a dash from the stop smashes it and they run on at the dash's speed %s" % tag)
			var run: Dictionary = await sim.run(_stop_layout(lanes, [d]), lane, 3.0, [[30.0, &"dash"]])
			check(run["alive"] and int(run["smashes"]) == 1 and int(run["stops"]) == 0,
				"a dash begun running toward it smashes it before contact, no stop %s (stops %d)" % [tag, run["stops"]])
			check(_sink(run["trace"], d, geo) <= SINK_TOLERANCE, "the dash never sinks the body into it %s" % tag)


## A jump or a slide while stopped plays out in place (still stopped, the same distance); a jump into a doodad comes down
## in front of it (stopped in the air), never sinking in.
func _test_jump_and_slide() -> void:
	for lanes: int in [3, 5, 6]:
		var geo := TrackGeometry.new(lanes, tuning)
		var lane: int = lanes / 2
		var tag: String = "(lanes=%d)" % lanes
		var d: Dictionary = _doodad(lane, 40.0, &"medium")
		var rest: float = float(d["start"]) - tuning.visual_size.z * 0.5 - Player.STOP_CLEARANCE
		for action: StringName in [&"jump", &"slide"]:
			var r: Dictionary = await sim.run(_stop_layout(lanes, [d]), lane, 3.5, [[rest - 0.001, action]])
			var events: Array = r["events"]
			check(r["alive"] and events.has(action) and absf(float(r["distance"]) - rest) < 0.01 and int(r["stops"]) == 1
				and bool((r["trace"] as Array)[-1]["stopped"]),
				"a %s while stopped plays out in place: still stopped, facing it %s" % [action, tag])
			check(_sink(r["trace"], d, geo) <= SINK_TOLERANCE, "a %s while stopped never sinks into it %s" % [action, tag])
		# A jump just before it: stopped in the air, down in front of it.
		var j: Dictionary = await sim.run(_stop_layout(lanes, [d]), lane, 3.0, [[rest - 5.0, &"jump"]])
		var high: float = 0.0
		for s: Dictionary in j["trace"]:
			high = maxf(high, float(s["h"]))
		check(j["alive"] and absf(float(j["distance"]) - rest) < 0.05 and float(j["trace"][-1]["h"]) < 0.01 and high > 0.5
			and _sink(j["trace"], d, geo) <= SINK_TOLERANCE,
			"a jump into it is stopped in the air and comes down in front of it (too tall to jump) %s" % tag)


## A switch into a lane whose doodad starts just ahead (where the body's side would meet it) is refused; one further
## ahead lets the switch through and stops the runner at its front, never sinking in; and a front corner caught mid-switch
## stops them there.
func _test_switch_ahead() -> void:
	var player_ahead: float = tuning.visual_size.z * 0.5
	for lanes: int in [3, 5, 6]:
		var geo := TrackGeometry.new(lanes, tuning)
		var lane: int = 0
		var to_lane: int = 1
		var tag: String = "(lanes=%d)" % lanes
		# Just ahead: half a metre past the body's front when the switch is pressed.
		var near: Dictionary = _doodad(to_lane, 40.0, &"small")
		var r: Dictionary = await sim.run(_stop_layout(lanes, [near]), lane, 3.0, [[40.0 - player_ahead - 0.5, &"move_right"]])
		check(r["alive"] and int(r["lane"]) == lane and (r["events"] as Array).has(&"lane_blocked") and int(r["stops"]) == 0,
			"a switch toward a doodad just ahead in that lane is refused (it would meet its side) %s" % tag)
		# Further ahead: 6 m past the body's front.
		var far: Dictionary = _doodad(to_lane, 40.0, &"small")
		var f: Dictionary = await sim.run(_stop_layout(lanes, [far]), lane, 3.0, [[40.0 - player_ahead - 6.0, &"move_right"]])
		var rest: float = 40.0 - player_ahead - Player.STOP_CLEARANCE
		check(f["alive"] and int(f["lane"]) == to_lane and int(f["stops"]) == 1 and absf(float(f["distance"]) - rest) < 0.01
			and _sink(f["trace"], far, geo) <= SINK_TOLERANCE,
			"a switch toward a doodad further ahead goes through, and they stop at its front %s" % tag)
		# A front corner caught mid-switch: the switch begun 2.5 m before the body's front reaches it, every size.
		for size: StringName in [&"small", &"medium", &"large"]:
			var c: Dictionary = _doodad(to_lane, 40.0, size)
			var k: Dictionary = await sim.run(_stop_layout(lanes, [c]), lane, 3.0, [[40.0 - player_ahead - 2.5, &"move_right"]])
			check(k["alive"] and int(k["stops"]) <= 1 and _sink(k["trace"], c, geo) <= SINK_TOLERANCE,
				"a front corner caught mid-switch never sinks the body in (%s, %d stops) %s" % [size, k["stops"], tag])


## The fallback for a body that ends up in a doodad's side all the same (Player._start_bounce; here the run begins with
## the body's front already past a doodad's front in its lane, so it stands beside the body, not ahead): the body moves
## back out into the lane beside with the blocked move's clank (lane_blocked), alive, never stopped by it, never pushed,
## and runs on there.
func _test_bounce() -> void:
	for lanes: int in [3, 5, 6]:
		var geo := TrackGeometry.new(lanes, tuning)
		var lane: int = 1
		var d: Dictionary = _doodad(lane, 0.0, &"medium")
		var r: Dictionary = await sim.run(_stop_layout(lanes, [d]), lane, 1.5, [])
		var trace: Array = r["trace"]
		var last: Dictionary = trace[-1] if not trace.is_empty() else {}
		check(r["alive"] and int(r["lane"]) == lane - 1 and (r["events"] as Array).has(&"lane_blocked") and int(r["stops"]) == 0
			and int(r["pushes"]) == 0 and not last.is_empty() and absf(float(last["x"]) - geo.lane_x(lane - 1)) < 0.01
			and float(r["distance"]) > float(d["end"]),
			"a body caught in a doodad's side moves back out into the lane beside with the clank, and runs on (%s, lane %d, %s) (lanes=%d)"
			% [r["cause"], r["lane"], r["events"], lanes])


## With the flag off (every other level), the same doodad pushes as before.
func _test_pushes_without_flag() -> void:
	for lanes: int in [3, 5, 6]:
		var layout := RunSim.layout(lanes)
		var lane: int = 1
		layout.doodads.append(_doodad(lane, 40.0, &"medium", 1))
		var r: Dictionary = await sim.run(layout, lane, 3.0, [])
		check(r["alive"] and int(r["pushes"]) == 1 and int(r["stops"]) == 0 and int(r["lane"]) == lane + 1,
			"without the flag a doodad pushes, as before (lanes=%d)" % lanes)


## In a full world: the stop plays the push's thud (PlayerSfx hears doodad_push for it), shakes a little, and costs no
## score or credits; the run's clock (RunResult.time) runs on through it.
func _test_full_world() -> void:
	var layout := _stop_layout(5, [_doodad(2, 40.0, &"large")])
	var world: RunWorld = sim.build_world(layout)
	var sounds: Array = []
	world.sounds.requested.connect(func(s: StringName) -> void: sounds.append(s))
	var r: Dictionary = await sim.step_world(world, 3.0)
	check(world.player.doodads_stop and world.player.stopped and sounds.has(&"doodad_push") and int(world.score.score) == 0
		and world.player.elapsed > 2.9 and (r["events"] as Array).has(&"doodad_stop"),
		"in a full world the stop plays the thud, scores nothing, and the clock runs on (%s)" % [sounds])
	await sim.free_world(world)


# --- The lower doodads -------------------------------------------------------------------------

## The Terminal's levels' doodads stand at their own height (LevelConfig.doodad_height, through movement_for: the
## generator's, the track's and the runner's tuning), lower than the standard ones and still out of a jump's reach (a
## jump's feet reach jump_height); every other level's are the movement tuning's.
func _test_lower_doodads() -> void:
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	for s: CampaignStep in campaign.steps():
		if not s.is_level() or s.is_minigame():
			continue
		var level_tuning: MovementTuning = s.level.movement_for(tuning)
		if s.zone.id == &"terminal":
			check(s.level.doodads_stop and level_tuning.doodad_height < tuning.doodad_height
				and level_tuning.doodad_height > tuning.jump_height + Player.DOODAD_FEET_CLEARANCE + 0.1
				and is_equal_approx(level_tuning.doodad_height, s.level.doodad_height),
				"%s's doodads stop the runner and stand lower (%.2f m), out of a jump's reach (%.2f m)" % [s.id,
					level_tuning.doodad_height, tuning.jump_height])
		else:
			check(not s.level.doodads_stop and is_equal_approx(level_tuning.doodad_height, tuning.doodad_height),
				"%s's doodads push and stand at the standard height" % s.id)
	# On the track: a Terminal level's box is its height.
	var config: LevelConfig = campaign.configure(campaign.step("terminal/1"), 5)
	var low: MovementTuning = config.movement_for(tuning)
	var layout := _stop_layout(5, [_doodad(2, 40.0, &"medium")])
	var track := TrackBuilder.new()
	tree.root.add_child(track)
	track.set_layout(layout, low)
	track.update(0.0, 0.0)
	var heights: Array[float] = []
	for b: Node in track.find_children("*", "Area3D", true, false):
		if b is DashBreakable:
			heights.append((b as DashBreakable).size.y)
	track.queue_free()
	await tree.process_frame
	check(heights.size() == 1 and is_equal_approx(heights[0], config.doodad_height),
		"a Terminal level's doodad is built at its height on the track (%s)" % [heights])


# --- The generator ------------------------------------------------------------------------------

## Every build of the Terminal's levels at 3, 5 and 6 lanes, on their own seeds and OTHER_SEEDS, as the campaign
## configures them: no warnings, every fairness check (LayoutChecks.check_layout, its check_debris_maze among them, and
## check_rules), the same level on a second build; the maze over most of Rubble Line and in a few stretches of Last
## Stop, Rubble Line's blocks taking one break or two, dead ends and walled-in cells along the way, a few one-lane
## ceilings over the maze; and the sections, links and groups of the maze (DebrisMaze) consistent with its debris.
func _test_generator() -> void:
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var shares: Dictionary = {"terminal/1": [], "terminal/2": []}
	var breaks: Dictionary = {}
	var dead_ends: int = 0
	var walled_in: int = 0
	var cells: int = 0
	var maze_ceilings: int = 0
	var pieces: Array[int] = []
	for id: String in ["terminal/1", "terminal/2"]:
		var step: CampaignStep = campaign.step(id)
		for lanes: int in [3, 5, 6]:
			for k: int in OTHER_SEEDS.size() + 1:
				var config: LevelConfig = campaign.configure(step, lanes)
				if k > 0:
					config.level_seed = OTHER_SEEDS[k - 1]
				var tag: String = "%s lanes=%d seed=%d" % [id, lanes, config.level_seed]
				var patterns: Array = LevelGenerator.load_for(config)
				var gen: LevelGenerator = LayoutCache.generator(config, tuning, patterns)
				var layout: LevelLayout = gen.layout
				check(gen.warnings.is_empty(), "no warnings %s %s" % [tag, gen.warnings])
				var report: Dictionary = gen.debris_maze_result
				var missing: Array = []
				for c: Variant in report.get("constraints", []):
					if String(c).begins_with("slot"):
						missing.append(c)
				check(not report.is_empty() and missing.is_empty() and int(report["blocks"]) == int(report["slots"]),
					"every slot has its block %s %s" % [tag, report])
				LayoutChecks.check_layout(self, layout, config, tag)
				LayoutChecks.check_rules(self, layout, config, tag)
				if k == 0:
					var again: LevelLayout = LevelGenerator.new().generate(config, tuning, patterns)
					check(JSON.stringify(again.to_dict()) == JSON.stringify(layout.to_dict()), "the same maze every attempt " + tag)
				var maze: float = 0.0
				for b: Dictionary in layout.maze:
					maze += float(b["end"]) - float(b["start"])
					if id == "terminal/1":
						breaks[int(b["breaks"])] = int(breaks.get(int(b["breaks"]), 0)) + 1
					var counted: Vector3i = _cells_of(b, lanes)
					cells += counted.x
					dead_ends += counted.y
					walled_in += counted.z
				(shares[id] as Array).append(maze / layout.length)
				var count: int = 0
				for d: Dictionary in layout.doodads:
					count += 1 if LevelLayout.is_maze_debris(d) else 0
				pieces.append(count)
				for h: Dictionary in layout.hulls:
					maze_ceilings += 1 if h.has("maze") else 0
				_check_sections(layout, tag)
	var one: Array = shares["terminal/1"]
	var two: Array = shares["terminal/2"]
	check(one.min() > 0.6 and two.max() < 0.45 and two.min() > 0.2,
		"the maze covers most of Rubble Line (%.2f-%.2f) and stretches of Last Stop (%.2f-%.2f)" % [one.min(), one.max(),
			two.min(), two.max()])
	check(int(breaks.get(1, 0)) > 0 and int(breaks.get(2, 0)) > 0, "Rubble Line's blocks take one break or two (%s)" % [breaks])
	check(dead_ends > 0 and walled_in > 0 and maze_ceilings > 0,
		"the mazes have dead ends (%d) and cells walled in (%d) of %d cells, and ceilings over them (%d)" % [dead_ends, walled_in,
			cells, maze_ceilings])
	pieces.sort()
	print("  debris maze: Rubble Line's share %.2f-%.2f, Last Stop's %.2f-%.2f; Rubble Line's breaks %s; %d cells, %d dead ends, %d walled in; %d maze ceilings; pieces a build %d-%d"
		% [one.min(), one.max(), two.min(), two.max(), breaks, cells, dead_ends, walled_in, maze_ceilings, pieces[0], pieces[-1]])


## Block record `b`'s cells (in `lanes` lanes): Vector3i(how many, how many are dead ends: no opening of the wall after
## them in their lanes, how many are walled in: no opening into them from the wall before either).
func _cells_of(b: Dictionary, lanes: int) -> Vector3i:
	var out := Vector3i.ZERO
	var rooms: Array = b["rooms"]
	var walls: Array = b["walls"]
	for r: int in rooms.size():
		for c: Vector2i in DebrisMaze.cells_of(rooms[r]["dividers"], lanes):
			out.x += 1
			var ahead: bool = false
			var behind: bool = false
			for lane: int in range(c.x, c.y + 1):
				ahead = ahead or (walls[r + 1]["open"] as Array).has(lane)
				behind = behind or (walls[r]["open"] as Array).has(lane)
			out.y += 0 if ahead else 1
			out.z += 0 if behind else 1
	return out


## The maze's sections and links (DebrisMaze: what lives in it, task O3, reads them) agree with its debris: every
## section open floor (no doodad in its lanes over its stretch), every spot of a cell found in its section and a spot
## in a divider in none; every opening link joins sections of the rooms either side of its wall through an open lane;
## a cell with no opening on either side is a group of its own; smashing a wall's piece joins the sections either side
## of it (links with `broken`); what a dash opens onto a divider's lane (_check_broken_cases); and, after random smashes,
## the groups links make are the real floor's (_check_broken_flood).
func _check_sections(layout: LevelLayout, tag: String) -> void:
	var secs: Array[Dictionary] = DebrisMaze.sections(layout)
	var lanes: int = layout.lane_count
	var open_ok: bool = true
	var found_ok: bool = true
	for id: int in secs.size():
		var s: Dictionary = secs[id]
		for lane: int in range(int(s["first"]), int(s["last"]) + 1):
			for d: Dictionary in layout.doodads:
				if int(d["lane"]) == lane and float(d["start"]) < float(s["end"]) - 0.01 and float(d["end"]) > float(s["start"]) + 0.01:
					open_ok = false
			var mid: float = (float(s["start"]) + float(s["end"])) * 0.5
			found_ok = found_ok and DebrisMaze.section_at(secs, lane, mid) == id
	check(open_ok, "every section of the maze is open floor %s" % tag)
	check(found_ok, "section_at finds every section's spots %s" % tag)
	var divider_ok: bool = true
	for b: Dictionary in layout.maze:
		for room: Dictionary in b["rooms"]:
			for lane: Variant in room["dividers"]:
				var mid: float = (float(room["start"]) + float(room["end"])) * 0.5
				divider_ok = divider_ok and DebrisMaze.section_at(secs, int(lane), mid) == -1
	check(divider_ok, "a spot in a divider is in no section %s" % tag)
	var links: Array[Dictionary] = DebrisMaze.links(layout, secs)
	var links_ok: bool = true
	for k: Dictionary in links:
		var a: Dictionary = secs[int(k["from"])]
		var c: Dictionary = secs[int(k["to"])]
		var lane: int = int(k["lane"])
		links_ok = links_ok and String(k["kind"]) == "opening" and int(a["block"]) == int(c["block"]) \
			and int(c["room"]) == int(a["room"]) + 1 and lane >= int(a["first"]) and lane <= int(a["last"]) \
			and lane >= int(c["first"]) and lane <= int(c["last"])
	check(links_ok, "every link joins the sections either side of a wall through an opening %s" % tag)
	var alone_ok: bool = true
	for id: int in secs.size():
		var s: Dictionary = secs[id]
		if int(s["room"]) < 0 or int(s["room"]) >= (layout.maze[int(s["block"])]["rooms"] as Array).size():
			continue
		var linked: bool = false
		for k: Dictionary in links:
			linked = linked or int(k["from"]) == id or int(k["to"]) == id
		alone_ok = alone_ok and (linked or DebrisMaze.open_group(links, id) == PackedInt32Array([id]))
	check(alone_ok, "a cell with no opening either side is a group of its own %s" % tag)
	# A dash through a wall's piece joins the sections either side of it in its lane (where both are open there).
	if layout.maze.is_empty():
		return
	var copy: LevelLayout = layout.copy()
	var b0: Dictionary = copy.maze[0]
	var w: int = 1
	var lane: int = -1
	for l: int in lanes:
		if not (b0["walls"][w]["open"] as Array).has(l) and not (b0["rooms"][0]["dividers"] as Array).has(l) \
				and not (b0["rooms"][1]["dividers"] as Array).has(l):
			lane = l
			break
	if lane >= 0:
		for d: Dictionary in copy.doodads:
			if int(d.get("maze", -1)) == 0 and String(d["part"]) == "wall" and int(d["index"]) == w and int(d["lane"]) == lane:
				d["smashed"] = true
		var secs_b: Array[Dictionary] = DebrisMaze.sections(copy, true)
		var before: int = DebrisMaze.section_id(secs_b, 0, 0, lane)
		var after: int = DebrisMaze.section_id(secs_b, 0, 1, lane)
		var broken: Array[Dictionary] = DebrisMaze.links(copy, secs_b, true)
		var joined: bool = false
		for k: Dictionary in broken:
			joined = joined or (String(k["kind"]) == "broken" and (int(k["from"]) == after or int(k["to"]) == after))
		check(joined and DebrisMaze.open_group(broken, before).has(after) and secs_b.size() == secs.size(),
			"a smashed wall piece joins the sections either side of it %s" % tag)
	_check_broken_cases(layout, tag)
	_check_broken_flood(layout, tag)


## The pieces of maze block `block`'s `part` ("wall" or "divider") number `index` in `lane`, in `layout`, in order along
## the track.
static func _maze_pieces(layout: LevelLayout, block: int, part: String, index: int, lane: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d: Dictionary in layout.doodads:
		if int(d.get("maze", -1)) == block and String(d["part"]) == part and int(d["index"]) == index and int(d["lane"]) == lane:
			out.append(d)
	out.sort_custom(func(a: Dictionary, c: Dictionary) -> bool: return float(a["start"]) < float(c["start"]))
	return out


## The cases where a dash opens a way through debris onto a divider's lane (links with `broken`, task O2's review): the
## first such case of each kind in `layout`, on a copy of it with those pieces smashed.
## - A wall broken in a lane that's a divider past it (the wall's piece and the divider's first piece smashed, as a dash
##   from the wall's face does): the stretch is a section of its own (section_at finds it), and the section before the
##   wall reaches it and the cells beside it.
## - A divider's last piece and the next wall's piece in its lane smashed: the cells beside the stretch reach what's open
##   past that wall in its lane.
## - A divider in an edge lane, one of its pieces smashed: the stretch joins the one cell beside it.
func _check_broken_cases(layout: LevelLayout, tag: String) -> void:
	var lanes: int = layout.lane_count
	var seen: Dictionary = {}
	for bi: int in layout.maze.size():
		var b: Dictionary = layout.maze[bi]
		var walls: Array = b["walls"]
		var rooms: Array = b["rooms"]
		for r: int in rooms.size():
			for lane_v: Variant in rooms[r]["dividers"]:
				var lane: int = int(lane_v)
				var pieces: Array[Dictionary] = _maze_pieces(layout, bi, "divider", r, lane)
				# Into it: wall r, closed in its lane, open before it (the run-in, or a cell of room r - 1).
				if not seen.has("into") and not (walls[r]["open"] as Array).has(lane) \
						and (r == 0 or not (rooms[r - 1]["dividers"] as Array).has(lane)):
					seen["into"] = true
					var copy: LevelLayout = layout.copy()
					_smash_like(copy, _maze_pieces(layout, bi, "wall", r, lane)[0])
					_smash_like(copy, pieces[0])
					var secs: Array[Dictionary] = DebrisMaze.sections(copy, true)
					var links: Array[Dictionary] = DebrisMaze.links(copy, secs, true)
					var before: int = DebrisMaze.section_id(secs, bi, r - 1, lane)
					var stretch: int = DebrisMaze.section_at(secs, lane, (float(pieces[0]["start"]) + float(pieces[0]["end"])) * 0.5)
					var group: PackedInt32Array = DebrisMaze.open_group(links, before)
					var beside: bool = stretch >= 0 and bool(secs[stretch].get("broken", false)) and group.has(stretch)
					for side: int in [lane - 1, lane + 1]:
						var cell: int = DebrisMaze.section_id(secs, bi, r, side)
						beside = beside and (cell < 0 or group.has(cell))
					check(beside, "a wall broken into a divider's lane leads into the smashed stretch and the cells beside it (block %d, wall %d, lane %d) %s"
						% [bi, r, lane, tag])
				# Out of it: its last piece and wall r + 1's piece in its lane, open past that wall.
				if not seen.has("out") and not (walls[r + 1]["open"] as Array).has(lane) \
						and (r + 1 == rooms.size() or not (rooms[r + 1]["dividers"] as Array).has(lane)):
					seen["out"] = true
					var copy: LevelLayout = layout.copy()
					_smash_like(copy, pieces[-1])
					_smash_like(copy, _maze_pieces(layout, bi, "wall", r + 1, lane)[0])
					var secs: Array[Dictionary] = DebrisMaze.sections(copy, true)
					var links: Array[Dictionary] = DebrisMaze.links(copy, secs, true)
					var past: int = DebrisMaze.section_id(secs, bi, r + 1, lane)
					var reached: bool = past >= 0
					for side: int in [lane - 1, lane + 1]:
						var cell: int = DebrisMaze.section_id(secs, bi, r, side)
						reached = reached and (cell < 0 or DebrisMaze.open_group(links, cell).has(past))
					check(reached, "a divider's smashed end and the wall after it lead from the cells beside it on past the wall (block %d, room %d, lane %d) %s"
						% [bi, r, lane, tag])
				# An edge lane's divider.
				if not seen.has("edge") and (lane == 0 or lane == lanes - 1) and pieces.size() >= 2:
					seen["edge"] = true
					var copy: LevelLayout = layout.copy()
					var piece: Dictionary = pieces[pieces.size() / 2]
					_smash_like(copy, piece)
					var secs: Array[Dictionary] = DebrisMaze.sections(copy, true)
					var links: Array[Dictionary] = DebrisMaze.links(copy, secs, true)
					var stretch: int = DebrisMaze.section_at(secs, lane, (float(piece["start"]) + float(piece["end"])) * 0.5)
					var cell: int = DebrisMaze.section_id(secs, bi, r, 1 if lane == 0 else lanes - 2)
					check(stretch >= 0 and cell >= 0 and DebrisMaze.open_group(links, cell).has(stretch),
						"a smashed piece of an edge lane's divider joins the cell beside it (block %d, room %d, lane %d) %s"
						% [bi, r, lane, tag])


## Marks the entry of `copy` that is `piece` (the same block, part, index, lane and start) smashed, as a dash's smash does.
static func _smash_like(copy: LevelLayout, piece: Dictionary) -> void:
	for d: Dictionary in copy.doodads:
		if int(d.get("maze", -1)) == int(piece["maze"]) and String(d["part"]) == String(piece["part"]) \
				and int(d["index"]) == int(piece["index"]) and int(d["lane"]) == int(piece["lane"]) \
				and absf(float(d["start"]) - float(piece["start"])) < 0.001:
			d["smashed"] = true


## Metres of track per step of the flood fill (_check_broken_flood): more than the sliver between two pieces of debris.
const FLOOD_STEP: float = 0.25
## The share of a block's pieces the flood fill's trials smash.
const FLOOD_SMASH_SHARE: float = 0.35


## Links with `broken` agree with the real floor (task O2's review): for each block of `layout`, two trials smashing a
## random share of its pieces (FLOOD_SMASH_SHARE, a stream of the layout's seed), the block's free floor (lanes by
## FLOOD_STEP steps from its run-in to its breather's end, a step blocked where a standing piece of its debris reaches
## into it) split into the groups a flood fill joins, across lanes and along them; then every section's group by
## open_group(links) is exactly the sections whose floor the same flood reaches, and every free spot's section_at is one
## of those (or none: inside a wall's opening or a smashed piece of it).
func _check_broken_flood(layout: LevelLayout, tag: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([layout.length, layout.lane_count, layout.doodads.size()])
	var lanes: int = layout.lane_count
	var agree: bool = true
	var spots_ok: bool = true
	var where: String = ""
	var spot_where: String = ""
	for bi: int in layout.maze.size():
		var b: Dictionary = layout.maze[bi]
		var from: float = float(b["entry"])
		var steps: int = int(ceil((float(b["exit"]) - from) / FLOOD_STEP))
		for trial: int in 2:
			var copy: LevelLayout = layout.copy()
			for d: Dictionary in copy.doodads:
				if int(d.get("maze", -1)) == bi and rng.randf() < FLOOD_SMASH_SHARE:
					d["smashed"] = true
			var blocked := PackedByteArray()
			blocked.resize(lanes * steps)
			for d: Dictionary in copy.doodads:
				if int(d.get("maze", -1)) != bi or bool(d.get("smashed", false)):
					continue
				var k0: int = maxi(int(floor((float(d["start"]) - from) / FLOOD_STEP)), 0)
				var k1: int = mini(int(ceil((float(d["end"]) - from) / FLOOD_STEP)), steps)
				for k: int in range(k0, k1):
					blocked[int(d["lane"]) * steps + k] = 1
			# The groups of free floor: a flood across lanes and along them.
			var group := PackedInt32Array()
			group.resize(lanes * steps)
			group.fill(-1)
			var groups: int = 0
			for start: int in lanes * steps:
				if blocked[start] == 1 or group[start] >= 0:
					continue
				var todo: Array[int] = [start]
				group[start] = groups
				while not todo.is_empty():
					var at: int = todo.pop_back()
					var lane: int = at / steps
					var k: int = at % steps
					for next: int in [at - 1 if k > 0 else -1, at + 1 if k + 1 < steps else -1,
							at - steps if lane > 0 else -1, at + steps if lane + 1 < lanes else -1]:
						if next >= 0 and blocked[next] == 0 and group[next] < 0:
							group[next] = groups
							todo.append(next)
				groups += 1
			var secs: Array[Dictionary] = DebrisMaze.sections(copy, true)
			var links: Array[Dictionary] = DebrisMaze.links(copy, secs, true)
			# Each section of this block: the flood group of the spot at its middle.
			var of: Dictionary = {}
			for id: int in secs.size():
				var s: Dictionary = secs[id]
				if int(s["block"]) != bi:
					continue
				var k: int = clampi(int(floor(((float(s["start"]) + float(s["end"])) * 0.5 - from) / FLOOD_STEP)), 0, steps - 1)
				of[id] = group[int(s["first"]) * steps + k]
			for id: Variant in of:
				var want: Array[int] = []
				for other: Variant in of:
					if int(of[other]) == int(of[id]) and int(of[id]) >= 0:
						want.append(int(other))
				want.sort()
				var got: Array[int] = []
				for g: int in DebrisMaze.open_group(links, int(id)):
					got.append(g)
				if want != got and agree:
					agree = false
					where = "block %d, trial %d, section %d %s: flood %s, links %s" % [bi, trial, int(id), secs[int(id)], want, got]
			# Each section's floor is free and in one flood group, section_at finds the section by its ends and its middle,
			# and the sections cover the free floor but inside the walls (their openings and smashed pieces).
			var sec_of := PackedInt32Array()
			sec_of.resize(lanes * steps)
			sec_of.fill(-1)
			for id: Variant in of:
				var s: Dictionary = secs[int(id)]
				# The steps wholly inside it are its floor; any step it reaches into counts as covered.
				var k0: int = clampi(int(ceil((float(s["start"]) - from) / FLOOD_STEP)), 0, steps)
				var k1: int = clampi(int(floor((float(s["end"]) - from) / FLOOD_STEP)), 0, steps)
				var c0: int = clampi(int(floor((float(s["start"]) - from) / FLOOD_STEP)), 0, steps)
				var c1: int = clampi(int(ceil((float(s["end"]) - from) / FLOOD_STEP)), 0, steps)
				for lane: int in range(int(s["first"]), int(s["last"]) + 1):
					for k: int in range(c0, c1):
						sec_of[lane * steps + k] = int(id)
					for k: int in range(k0, k1):
						var c: int = lane * steps + k
						if spots_ok and (blocked[c] == 1 or group[c] != int(of[id])):
							spots_ok = false
							spot_where = "section %s's spot at %.2f in lane %d" % [s, from + k * FLOOD_STEP, lane]
				for at: float in [float(s["start"]) + 0.05, (float(s["start"]) + float(s["end"])) * 0.5, float(s["end"]) - 0.05]:
					if spots_ok and DebrisMaze.section_at(secs, int(s["first"]), at) != int(id):
						spots_ok = false
						spot_where = "section_at(%d, %.2f) for section %s" % [int(s["first"]), at, s]
			for c: int in lanes * steps:
				if blocked[c] == 1 or sec_of[c] >= 0:
					continue
				var mid: float = from + ((c % steps) + 0.5) * FLOOD_STEP
				# The block's floor only (the flood's last step may reach past its breather's end).
				var in_wall: bool = mid > float(b["exit"]) - FLOOD_STEP
				for wall: Dictionary in b["walls"]:
					in_wall = in_wall or (mid >= float(wall["start"]) - FLOOD_STEP and mid <= float(wall["end"]) + FLOOD_STEP)
				if spots_ok and not in_wall:
					spots_ok = false
					spot_where = "free floor in no section at %.2f in lane %d" % [mid, c / steps]
	check(agree, "open_group over links with what's smashed is the real floor's flood fill, section by section %s %s" % [tag, where])
	check(spots_ok, "the sections are the free floor (but inside the walls), each in one flood group, section_at finding them %s %s"
		% [tag, spot_where])


## Endless mode in the Terminal (App.start_endless: the zone's last level, Last Stop, made a 20-minute level of everything
## the zone has from the start, at the zone's speed, on a random seed), here on two arbitrary seeds at 5 lanes: it builds
## without warnings, with the maze along the whole of it, and keeps every rule of the maze (check_debris_maze).
func _test_endless() -> void:
	var zone := load("res://data/zones/terminal.tres") as ZoneDef
	for level_seed: int in [7310, 424242]:
		var config: LevelConfig = (zone.levels[zone.levels.size() - 1] as LevelConfig).duplicate() as LevelConfig
		# As App.start_endless makes it.
		config.id = &"endless"
		config.level_seed = level_seed
		config.lane_count = 5
		config.duration_seconds = App.ENDLESS_SECONDS
		config.difficulty = 0.2
		config.difficulty_ramp = 0.8
		config.enemy_scaling = 1.0
		var starts: Dictionary[String, float] = {}
		config.feature_starts = starts
		config.guarantee_features = false
		config.quiet_seconds = 0.0
		config.extended_wall_runs = []
		var features: PackedStringArray = config.features.duplicate()
		for f: String in config.features_left_out:
			if not features.has(f):
				features.append(f)
		config.features = features
		config.features_left_out = PackedStringArray()
		config.darkness = 0.0
		config.sky = null
		if config.run_speed <= 0.0:
			config.run_speed = zone.run_speed
		var tag: String = "(endless in the Terminal, seed %d)" % level_seed
		var gen := LevelGenerator.new()
		var layout: LevelLayout = gen.generate(config, tuning, LevelGenerator.load_for(config))
		check(gen.warnings.is_empty(), "no warnings %s %s" % [tag, gen.warnings])
		var last_end: float = float(layout.maze[-1]["end"]) if not layout.maze.is_empty() else 0.0
		check(layout.maze.size() >= 20 and last_end > layout.length * 0.8,
			"the maze along the whole of it (%d blocks, the last ending at %.0f of %.0f m) %s" % [layout.maze.size(), last_end,
				layout.length, tag])
		LayoutChecks.check_debris_maze(self, layout, config, tag)


## A level without the feature has no maze, and its doodads push (the Dead Zone's last level and the Golden Zone's first,
## either side of the Terminal).
func _test_without_feature() -> void:
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	for id: String in ["dead_zone/2", "golden/1"]:
		var config: LevelConfig = campaign.configure(campaign.step(id), 5)
		var layout: LevelLayout = LayoutCache.generate(config, tuning, LevelGenerator.load_for(config))
		var pieces: int = 0
		for d: Dictionary in layout.doodads:
			pieces += 1 if LevelLayout.is_maze_debris(d) else 0
		check(layout.maze.is_empty() and pieces == 0 and not layout.doodads_stop and not layout.to_dict().has("maze")
			and not layout.to_dict().has("doodads_stop"), "%s has no maze, and its doodads push as before" % id)


# --- The bot on real physics --------------------------------------------------------------------

## A block of each Terminal level (its own seed) at 3, 5 and 6 lanes, run on real physics by the way MazeRoute finds,
## the dash at its slowest recharge, just used as the run-in begins: through alive, every route move made, never refused
## a switch, dashing as often as the route, in about its time. The first block, and the one with the most waiting.
func _test_bot() -> void:
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var recharge: float = LayoutChecks.maze_recharge()
	check(is_equal_approx(recharge, SLOWEST_RECHARGE), "the dash's slowest recharge is %.0f s (GDD §8)" % recharge)
	for id: String in ["terminal/1", "terminal/2"]:
		for lanes: int in [3, 5, 6]:
			var config: LevelConfig = campaign.configure(campaign.step(id), lanes)
			var level_tuning: MovementTuning = config.movement_for(tuning)
			var layout: LevelLayout = LayoutCache.generate(config, tuning, LevelGenerator.load_for(config))
			var route := MazeRoute.new(layout, level_tuning)
			var picks: Array[int] = [0]
			var worst: float = -1.0
			var worst_i: int = 0
			for i: int in layout.maze.size():
				var b: Dictionary = layout.maze[i]
				var r: Dictionary = route.find(float(b["entry"]), float(b["end"]) + 2.0, recharge)
				if bool(r["ok"]) and float(r["waits"]) > worst:
					worst = float(r["waits"])
					worst_i = i
			if worst_i != 0:
				picks.append(worst_i)
			for i: int in picks:
				var b: Dictionary = layout.maze[i]
				var tag: String = "(%s lanes=%d block %d)" % [id, lanes, i]
				var to: float = float(b["end"]) + 2.0
				var plan: Dictionary = route.find(float(b["entry"]), to, recharge)
				check(bool(plan["ok"]), "a way through the block %s" % tag)
				if not bool(plan["ok"]):
					continue
				var bot := MazeBot.new(tree, level_tuning)
				var run: Dictionary = await bot.run(layout.copy(), plan, float(b["entry"]), to, recharge)
				var planned: float = float(plan["seconds"])
				check(run["alive"] and run["reached"] and int(run["moves_left"]) == 0 and int(run["blocked"]) == 0
					and int(run["dashes"]) == int(plan["dashes"]),
					"the bot runs the route through alive, every move made, never refused (%s, %d moves left, %d refused, %d of %d dashes) %s"
					% [run["cause"], run["moves_left"], run["blocked"], run["dashes"], plan["dashes"], tag])
				check(float(run["seconds"]) <= planned + 1.0 + planned * 0.05,
					"in about the route's time (%.2f s, planned %.2f s, waits %.1f s) %s" % [run["seconds"], planned, plan["waits"], tag])


## Each Terminal level (its own seed) at 3, 5 and 6 lanes run whole on real physics, from its start to its end-clear
## stretch, by the way MazeRoute finds with the dash at its slowest recharge (just used as the run begins): through
## alive, every route move made, never refused a switch nor pushed, dashing as often as the route, in about its time.
## Prints each run's time against the level's own length, and its waits for the dash.
func _test_bot_levels() -> void:
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var recharge: float = LayoutChecks.maze_recharge()
	var lines: PackedStringArray = []
	for id: String in ["terminal/1", "terminal/2"]:
		for lanes: int in [3, 5, 6]:
			var config: LevelConfig = campaign.configure(campaign.step(id), lanes)
			var level_tuning: MovementTuning = config.movement_for(tuning)
			var layout: LevelLayout = LayoutCache.generate(config, tuning, LevelGenerator.load_for(config))
			var tag: String = "(%s lanes=%d, the whole level)" % [id, lanes]
			var route := MazeRoute.new(layout, level_tuning)
			var from: float = 20.0
			var to: float = layout.length - config.end_clear_distance
			var plan: Dictionary = route.find(from, to, recharge)
			check(bool(plan["ok"]), "a way through the whole level (%s) %s" % [plan["reason"], tag])
			if not bool(plan["ok"]):
				continue
			var bot := MazeBot.new(tree, level_tuning)
			var run: Dictionary = await bot.run(layout.copy(), plan, from, to, recharge)
			var planned: float = float(plan["seconds"])
			check(run["alive"] and run["reached"] and int(run["moves_left"]) == 0 and int(run["blocked"]) == 0
				and int(run["pushes"]) == 0 and int(run["dashes"]) == int(plan["dashes"]),
				"the bot runs the whole level alive, every move made, never refused nor pushed (%s at %.0f m, %d moves left, %d refused, %d of %d dashes) %s"
				% [run["cause"], run["distance"], run["moves_left"], run["blocked"], run["dashes"], plan["dashes"], tag])
			check(float(run["seconds"]) <= planned + 1.0 + planned * 0.02,
				"in about the route's time (%.1f s, planned %.1f s) %s" % [run["seconds"], planned, tag])
			lines.append("%s at %d lanes %.0f s for %.0f s of track (%.0f s waiting, %d dashes, %d stops)" % [id, lanes,
				float(run["seconds"]), (to - from) / level_tuning.run_speed, float(plan["waits"]), int(run["dashes"]),
				int(run["stops"])])
	print("  the bot through whole Terminal levels, the dash at %.0f s: %s" % [recharge, "; ".join(lines)])

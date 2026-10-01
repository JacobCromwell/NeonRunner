extends SceneTree
## Measures how forgiving the Floating Head's ways onto its head are (GDD §10; task E1e, from the
## owner's playtest, and E1f: the fight at its zone's speed, GDD §3), in its fight on a plain street, a
## runner playing the face-off by its warnings (FloatingHeadBot) until a tower pins the ship. From the
## project folder (with XDG_DATA_HOME set as for the tests):
##   godot --headless --fixed-fps 60 -s res://tools/measure/stomp_routes.gd -- [options]
## Options:
##   --lanes=3,5,6          lane counts (default 3,5,6)
##   --routes=ramp,wall,ceiling   which ways up (default all)
##   --speed=N              the run speed in m/s (default: the City boss step's through the campaign,
##                          Campaign.configure_boss: 21 m/s; 18 is the reference speed E1e measured at)
##   --e1c                  E1c's numbers instead of the tuning's: one straight ramp slab whose sides
##                          block from a step high (ramp_board_share 0), stomp boxes 3 m deep reaching
##                          0.55 m over their sockets and not over the outer lanes, the jump 3 m before
##                          its face (E1c's bot)
##   --second-move          on the wall route, one more move inward in the air 0.1 s after the wall jump
##   --fine                 on the wall route, also finds each end of the window by bisection between
##                          the sweep's points; the window is then where the jumps that stomp were
##                          pressed (a press is read on the next physics frame, a 60th of a second, at
##                          any speed)
##   --phases=N             with --fine, the bisections again with the runner nudged by N-ths of a
##                          frame's run as the pin begins, so the window's ends are found to a frame's
##                          N-th whatever the frames' phase against the ship (default 1)
##   --set=key:value        tries a tuning number before it goes in the data (FloatingHeadTuning's
##                          names, e.g. --set=stomp_depth:4.5; several --set may be given)
## What it prints, in metres at the run speed and in seconds of running (what stays the same at every
## speed: the fight's distances follow the pace, FloatingHead.run_pace):
##   ramp     the boarding window: the latest lane switch into the ramp's lane from the lane beside it
##            (on each side) that still ends in a stomp, before the ship's face and past the ramp's foot
##            (a binary search to about 0.15 m at 18 m/s);
##   wall     the jump points that stomp (X), from 6 m before the jump mark to 6 m past it in 0.5 m steps
##            (at 18 m/s; stretched by the pace at another speed), for a runner who gets onto the wall
##            where the marks start, and just before the window's release line, and jumps off it once
##            toward the ship: where they lie before the face, the window's length and how far the
##            mark is from either end of it;
##   ceiling  from a pad in each lane, riding straight ahead and dropping off the end: a stomp or not.
## The whole default run takes a few minutes.

## The wall route's sweep: jump points this many steps either side of the jump mark, each this long
## (metres at 18 m/s).
const WALL_STEPS: int = 12
const WALL_STEP: float = 0.5

var _lanes: Array[int] = [3, 5, 6]
var _routes: PackedStringArray = ["ramp", "wall", "ceiling"]
var _e1c: bool = false
var _second_move: bool = false
var _fine: bool = false
var _phases: int = 1
var _speed: float = 0.0
var _sets: Dictionary = {}
var _tuning: MovementTuning
var _sim: RunSim
var _def: BossDef


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--lanes="):
			_lanes.clear()
			for s: String in arg.get_slice("=", 1).split(",", false):
				_lanes.append(int(s))
		elif arg.begins_with("--routes="):
			_routes = arg.get_slice("=", 1).split(",", false)
		elif arg.begins_with("--speed="):
			_speed = float(arg.get_slice("=", 1))
		elif arg == "--e1c":
			_e1c = true
		elif arg == "--second-move":
			_second_move = true
		elif arg == "--fine":
			_fine = true
		elif arg.begins_with("--phases="):
			_phases = maxi(int(arg.get_slice("=", 1)), 1)
		elif arg.begins_with("--set="):
			var kv: String = arg.get_slice("=", 1)
			_sets[kv.get_slice(":", 0)] = float(kv.get_slice(":", 1))
	var app: Node = root.get_node_or_null(^"App")
	if app != null:
		app.set(&"autosave", false)
		app.set(&"save_path", "user://measure_profile.json")
	_tuning = _fight_tuning(load("res://data/tuning/movement.tres") as MovementTuning)
	_sim = RunSim.new(self, _tuning)
	_def = _make_def()
	var t := _def.tuning as FloatingHeadTuning
	print("Floating Head's ways up at %.1f m/s (pace %.3f; %s numbers, metres at 18 m/s): ramp %.1f m (lead-in %.0f%% of it, %.2f m high), stomp boxes %.1f m deep and %.2f m over their sockets%s; wall marks %.1f to %.1f m before its face" % [
		_tuning.run_speed, _tuning.pace(), "E1c's" if _e1c else "the tuning's", t.ramp_length, t.ramp_board_share * 100.0,
		t.ramp_board_height, t.stomp_depth, t.stomp_top, ", covering the outer lanes" if t.stomp_covers_outer_lanes else "",
		t.wall_entry_before, t.wall_jump_before])
	for lanes: int in _lanes:
		if _routes.has("ramp"):
			await _measure_ramp(lanes)
		if _routes.has("wall"):
			await _measure_wall(lanes)
		if _routes.has("ceiling"):
			await _measure_ceiling(lanes)
	quit(0)


## The movement tuning at the measured speed: --speed's, or the City boss step's as the campaign plays it
## (its zone's speed: Campaign.configure_boss, LevelConfig.movement_for).
func _fight_tuning(base: MovementTuning) -> MovementTuning:
	var speed: float = _speed
	if speed <= 0.0:
		var campaign := load("res://data/campaign/campaign.tres") as Campaign
		var step: CampaignStep = campaign.step("city/boss") if campaign != null else null
		if step != null:
			speed = campaign.configure_boss(step, 3).movement_for(base).run_speed
	if speed <= 0.0 or is_equal_approx(speed, base.run_speed):
		return base
	var out: MovementTuning = base.duplicate() as MovementTuning
	out.run_speed = speed
	return out


## The fight on a plain street, straight into the face-off with a tower lined up at once.
func _make_def() -> BossDef:
	var base := load("res://data/bosses/city_boss.tres") as BossDef
	var out: BossDef = base.duplicate() as BossDef
	var t := (base.tuning as FloatingHeadTuning).duplicate() as FloatingHeadTuning
	t.first_run_seconds = 0.0
	t.later_runs = 0
	t.tower_first = 160.0
	t.tower_spacing = 200.0
	t.towers_after = 0
	if _e1c:
		t.ramp_board_share = 0.0
		t.stomp_covers_outer_lanes = false
		t.stomp_depth = 3.0
		t.stomp_top = 0.55
		t.wall_jump_before = 3.0
	for key: String in _sets:
		if not key in t:
			push_warning("stomp_routes: no tuning number '%s'" % key)
			continue
		t.set(key, _sets[key])
		print("  (trying %s = %s)" % [key, _sets[key]])
	out.tuning = t
	out.arena = null
	return out


## Plays phase `phase` at `lanes` until the pin, then calls `drive` every frame until a stomp or a
## missed window: {stomped, from (the lane driven from, -1 none)}. `nudge`: the runner moves on this far
## as the pin begins (a fraction of a frame's run: another phase of the frames against the ship).
func _play(phase: int, lanes: int, drive: Callable, nudge: float = 0.0) -> Dictionary:
	var head := BossEncounter.create(_def) as FloatingHead
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = _def
	ctx.config = BossArena.base_config(_def)
	ctx.config.lane_count = lanes
	ctx.tuning = _tuning
	ctx.boss_resume = {"phase": phase} if phase > 0 else {}
	var arena: BossArena = head.plan_arena(ctx)
	var world: RunWorld = _sim.build_world(arena.layout, null, _tuning, ctx.config)
	head.setup(world, ctx, arena)
	world.player.god_mode = true
	var bot := FloatingHeadBot.new(head, true)
	bot.routes = false
	await physics_frame
	world.player.running = true
	var out := {"stomped": false, "from": -1}
	var pinned: bool = false
	for i: int in 60 * 60:
		if not pinned and (head.step == FloatingHead.Step.PIN_FALL or head.step == FloatingHead.Step.PINNED):
			pinned = true
			world.player.distance += nudge
		if pinned:
			drive.call(head, out)
		else:
			bot.step()
		var done: bool = false
		for e: Dictionary in head.events:
			if e["event"] == &"weak_point":
				out["stomped"] = true
				done = true
			elif e["event"] == &"window_missed":
				done = true
		if done:
			break
		await physics_frame
	await _sim.free_world(world)
	return out


static func _steer(p: Player, lane: int) -> void:
	if p.lane != lane and p.surface == Player.Surface.FLOOR:
		p.press(&"move_right" if lane > p.lane else &"move_left")


## `metres` at the run speed as seconds of running.
func _s(metres: float) -> float:
	return metres / _tuning.run_speed


# --- The ramp --------------------------------------------------------------------------------------

func _measure_ramp(lanes: int) -> void:
	var t := _def.tuning as FloatingHeadTuning
	var pace: float = _tuning.pace()
	for side: int in [1, -1]:
		# side 1: from the lane nearer the middle; -1: from the lane nearer the wall.
		var lo: float = 0.0
		var hi: float = (t.ramp_length + 6.0) * pace
		var first: Dictionary = await _ramp_try(lanes, side, hi)
		if int(first["from"]) < 0:
			continue
		if not first["stomped"]:
			print("  ramp, %d lanes, from lane %d: even a switch before its foot doesn't stomp" % [lanes, int(first["from"])])
			continue
		for k: int in 7:
			var mid: float = (lo + hi) * 0.5
			if (await _ramp_try(lanes, side, mid))["stomped"]:
				hi = mid
			else:
				lo = mid
		var length: float = float(first.get("length", t.ramp_length * pace))
		print("  ramp, %d lanes, from lane %d (%s side): the latest switch that stomps is %.2f m (%.3f s) before its face, %.2f m (%.3f s) past its foot (%.0f%% of its %.1f m)" % [
			lanes, int(first["from"]), "inner" if side > 0 else "outer", hi, _s(hi), length - hi, _s(length - hi),
			(length - hi) / length * 100.0, length])


func _ramp_try(lanes: int, side: int, gap: float) -> Dictionary:
	var state := {"switched": false}
	var drive := func(head: FloatingHead, out: Dictionary) -> void:
		var p: Player = head.world.player
		var lane: int = head.ramp_lane_for(head.pin_side)
		var to_middle: int = -1 if lane * 2 > lanes - 1 else 1
		var from: int = lane + side * to_middle
		if from < 0 or from >= lanes:
			out["from"] = -2
			return
		out["from"] = from
		if head.ramp != null and is_instance_valid(head.ramp):
			out["length"] = head.pin_stern - head.ramp.foot
		if state["switched"]:
			return
		if p.lane != from:
			_steer(p, from)
		elif head.pin_stern - p.distance <= gap:
			_steer(p, lane)
			state["switched"] = true
	return await _play(0, lanes, drive)


# --- The wall ----------------------------------------------------------------------------------------

func _measure_wall(lanes: int) -> void:
	var pace: float = _tuning.pace()
	var marks: Dictionary = await _wall_marks(lanes)
	if marks.is_empty():
		print("  wall, %d lanes: no wall marks" % lanes)
		return
	var mark: float = marks["jump"]
	var step: float = WALL_STEP * pace
	for wall: int in [-1, 1]:
		for entry: float in [float(marks["start"]), float(marks["release"]) + 0.8 * pace]:
			var row: String = ""
			# The sweep's points by index (jump points mark + (WALL_STEPS - k) * step): tried, and stomped.
			var tried: Array[int] = []
			var ok: Array[int] = []
			# Where the jumps that stomped were pressed (--fine).
			var pressed: Array[float] = []
			for k: int in 2 * WALL_STEPS + 1:
				var jump: float = mark + (WALL_STEPS - k) * step
				if jump >= entry - 1.0 * pace:
					row += " "
					continue
				tried.append(k)
				var r: Dictionary = await _wall_try(lanes, wall, entry, jump)
				row += "X" if r["stomped"] else "."
				if r["stomped"]:
					ok.append(k)
					pressed.append(float(r["pressed"]))
			var found: String = "none"
			if not ok.is_empty():
				var early: float = mark + (WALL_STEPS - ok[0]) * step
				var late: float = mark + (WALL_STEPS - ok[ok.size() - 1]) * step
				if _fine:
					# Each end between its last stomping point and the next one tried (if any was), at
					# each phase of the frames.
					var frame: float = _tuning.run_speed / Engine.physics_ticks_per_second
					for n: int in _phases:
						var nudge: float = frame * n / _phases
						if tried.has(ok[0] - 1):
							pressed.append_array(await _wall_edge(lanes, wall, entry, early, early + step, nudge))
						if tried.has(ok[ok.size() - 1] + 1):
							pressed.append_array(await _wall_edge(lanes, wall, entry, late, late - step, nudge))
					early = pressed.max()
					late = pressed.min()
				found = "%.2f to %.2f m before its face: a window of %.2f m, %.3f s; the mark %.3f s from its early end and %.3f s from its late end" % [
					early, late, early - late, _s(early - late), _s(early - mark), _s(mark - late)]
			print("  wall, %d lanes, %s wall, onto it %.1f m before its face%s: jumps %.1f..%.1f m [%s] stomp at %s" % [lanes,
				"left" if wall < 0 else "right", entry, ", a second move" if _second_move else "",
				mark + WALL_STEPS * step, mark - WALL_STEPS * step, row, found])


## The end of a wall jump's window between `inside` (a jump point that stomps) and `outside` (one that
## doesn't), by bisection with the runner nudged `nudge` as the pin begins: where each jump that stomped
## was pressed (metres before the face).
func _wall_edge(lanes: int, wall: int, entry: float, inside: float, outside: float, nudge: float) -> Array[float]:
	var out: Array[float] = []
	for i: int in 5:
		var mid: float = (inside + outside) * 0.5
		var r: Dictionary = await _wall_try(lanes, wall, entry, mid, nudge)
		if r["stomped"]:
			inside = mid
			out.append(float(r["pressed"]))
		else:
			outside = mid
	return out


## Where the second window's wall marks start and where their jump mark is, and the window's release
## line, as metres before the pinned ship's face: {start, jump, release} (empty: no marks).
func _wall_marks(lanes: int) -> Dictionary:
	var found := {}
	var drive := func(head: FloatingHead, _out: Dictionary) -> void:
		if found.is_empty() and head.wall_marks != null and is_instance_valid(head.wall_marks):
			found["start"] = head.pin_stern - head.wall_marks.start
			found["jump"] = head.pin_stern - head.wall_marks.jump_at
			found["release"] = head.release_gap()
	await _play(1, lanes, drive)
	return found


## A wall jump: onto the wall `entry` and off it `jump` metres before the face (with the runner nudged
## `nudge` as the pin begins): {stomped, pressed (where the jump was pressed, metres before the face)}.
func _wall_try(lanes: int, wall: int, entry: float, jump: float, nudge: float = 0.0) -> Dictionary:
	var state := {"stage": &"lane", "t": 0.0, "pressed": jump}
	var drive := func(head: FloatingHead, _out: Dictionary) -> void:
		var p: Player = head.world.player
		var outer: int = 0 if wall < 0 else lanes - 1
		var gap: float = head.pin_stern - p.distance
		var inward: StringName = &"move_right" if wall < 0 else &"move_left"
		match state["stage"]:
			&"lane":
				_steer(p, outer)
				if p.lane == outer and p.grounded and gap <= entry:
					p.press(&"move_left" if wall < 0 else &"move_right")
					state["stage"] = &"wall"
			&"wall":
				if p.surface == Player.Surface.WALL and gap <= jump:
					p.press(inward)
					state["stage"] = &"jumped"
					state["t"] = p.elapsed
					state["pressed"] = gap
			&"jumped":
				if _second_move and p.elapsed - float(state["t"]) >= 0.1:
					p.press(inward)
					state["stage"] = &"done"
	var out: Dictionary = await _play(1, lanes, drive, nudge)
	out["pressed"] = state["pressed"]
	return out


# --- The ceiling -------------------------------------------------------------------------------------

func _measure_ceiling(lanes: int) -> void:
	var row: PackedStringArray = []
	for lane: int in lanes:
		var drive := func(head: FloatingHead, _out: Dictionary) -> void:
			var p: Player = head.world.player
			if p.surface == Player.Surface.FLOOR and p.distance < head.pad_at:
				_steer(p, lane)
		var r: Dictionary = await _play(2, lanes, drive)
		row.append("lane %d %s" % [lane, "stomps" if r["stomped"] else "MISSES"])
	print("  ceiling, %d lanes, from a pad riding straight ahead: %s" % [lanes, ", ".join(row)])

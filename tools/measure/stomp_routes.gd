extends SceneTree
## Measures how forgiving the Floating Head's ways onto its head are (GDD §10; task E1e, from the
## owner's playtest), in its fight on a plain street, a runner playing the face-off by its warnings
## (FloatingHeadBot) until a tower pins the ship. From the project folder (with XDG_DATA_HOME set as for
## the tests):
##   godot --headless --fixed-fps 60 -s res://tools/measure/stomp_routes.gd -- [options]
## Options:
##   --lanes=3,5,6          lane counts (default 3,5,6)
##   --routes=ramp,wall,ceiling   which ways up (default all)
##   --e1c                  E1c's numbers instead of the tuning's: one straight ramp slab whose sides
##                          block from a step high (ramp_board_share 0), stomp boxes 3 m deep reaching
##                          0.55 m over their sockets and not over the outer lanes, the jump 3 m before
##                          its face (E1c's bot)
##   --second-move          on the wall route, one more move inward in the air 0.1 s after the wall jump
## What it prints:
##   ramp     the boarding window: the latest lane switch into the ramp's lane from the lane beside it
##            (on each side) that still ends in a stomp, as metres before the ship's face and past the
##            ramp's foot (a binary search to about 0.15 m);
##   wall     the jump points that stomp (metres before the face, 10 to -2 in 0.5 m steps: X stomps) for
##            a runner who gets onto the wall at the marks' start, and just before the window's release
##            line, and jumps off it once toward the ship;
##   ceiling  from a pad in each lane, riding straight ahead and dropping off the end: a stomp or not.
## The whole default run takes a few minutes.

var _lanes: Array[int] = [3, 5, 6]
var _routes: PackedStringArray = ["ramp", "wall", "ceiling"]
var _e1c: bool = false
var _second_move: bool = false
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
		elif arg == "--e1c":
			_e1c = true
		elif arg == "--second-move":
			_second_move = true
	var app: Node = root.get_node_or_null(^"App")
	if app != null:
		app.set(&"autosave", false)
		app.set(&"save_path", "user://measure_profile.json")
	_tuning = load("res://data/tuning/movement.tres") as MovementTuning
	_sim = RunSim.new(self, _tuning)
	_def = _make_def()
	var t := _def.tuning as FloatingHeadTuning
	print("Floating Head's ways up (%s numbers): ramp %.1f m (lead-in %.0f%% of it, %.2f m high), stomp boxes %.1f m deep and %.2f m over their sockets%s; wall marks %.1f to %.1f m before its face" % [
		"E1c's" if _e1c else "the tuning's", t.ramp_length, t.ramp_board_share * 100.0, t.ramp_board_height, t.stomp_depth, t.stomp_top,
		", covering the outer lanes" if t.stomp_covers_outer_lanes else "", t.wall_entry_before, t.wall_jump_before])
	for lanes: int in _lanes:
		if _routes.has("ramp"):
			await _measure_ramp(lanes)
		if _routes.has("wall"):
			await _measure_wall(lanes)
		if _routes.has("ceiling"):
			await _measure_ceiling(lanes)
	quit(0)


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
	out.tuning = t
	out.arena = null
	return out


## Plays phase `phase` at `lanes` until the pin, then calls `drive` every frame until a stomp or a
## missed window: {stomped, from (the lane driven from, -1 none)}.
func _play(phase: int, lanes: int, drive: Callable) -> Dictionary:
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
		pinned = pinned or head.step == FloatingHead.Step.PIN_FALL or head.step == FloatingHead.Step.PINNED
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


# --- The ramp --------------------------------------------------------------------------------------

func _measure_ramp(lanes: int) -> void:
	var t := _def.tuning as FloatingHeadTuning
	for side: int in [1, -1]:
		# side 1: from the lane nearer the middle; -1: from the lane nearer the wall.
		var lo: float = 0.0
		var hi: float = t.ramp_length + 6.0
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
		print("  ramp, %d lanes, from lane %d (%s side): the latest switch that stomps is %.2f m before its face, %.2f m past its foot (%.0f%% of its %.1f m)" % [
			lanes, int(first["from"]), "inner" if side > 0 else "outer", hi, t.ramp_length - hi,
			(t.ramp_length - hi) / t.ramp_length * 100.0, t.ramp_length])


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
	var t := _def.tuning as FloatingHeadTuning
	for wall: int in [-1, 1]:
		for entry: float in [t.wall_entry_before, t.window_release_gap + 0.8]:
			var row: String = ""
			var ok: PackedStringArray = []
			for k: int in 25:
				var jump: float = 10.0 - k * 0.5
				if jump >= entry - 1.0:
					row += " "
					continue
				var r: Dictionary = await _wall_try(lanes, wall, entry, jump)
				row += "X" if r["stomped"] else "."
				if r["stomped"]:
					ok.append("%.1f" % jump)
			print("  wall, %d lanes, %s wall, onto it %.1f m before its face%s: jumps 10..-2 m [%s] stomp at %s" % [lanes,
				"left" if wall < 0 else "right", entry, ", a second move" if _second_move else "", row,
				(ok[0] + " to " + ok[ok.size() - 1]) if not ok.is_empty() else "none"])


func _wall_try(lanes: int, wall: int, entry: float, jump: float) -> Dictionary:
	var state := {"stage": &"lane", "t": 0.0}
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
			&"jumped":
				if _second_move and p.elapsed - float(state["t"]) >= 0.1:
					p.press(inward)
					state["stage"] = &"done"
	return await _play(1, lanes, drive)


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

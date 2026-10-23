extends TestSuite
## Extended wall runs (the owner, October 19, 2026, for The Hush: "three sections where the extended wall run is
## required ... double and triple wide sections", one small platform by the wall to recharge the wall run on in a
## double, two in a triple, a wall on one side only but in one of them; LevelConfig.extended_wall_runs,
## WallRunGapPlacement). Checked here:
## - the numbers, at the shared tuning's speed and The Hush's: each hole is a standard wall-run gap's (longer than any
##   jump), each platform long enough for the latest standard wall run over the hole before it to land on, the
##   double about two standard wall runs long and the triple about three;
## - the generator: The Hush at 3, 5 and 6 lanes on its own seed has its three, in order (a double with both walls,
##   then a double and a triple with one wall), each keeping its rules (LayoutChecks.check_wall_run_gaps), its other
##   wall open over its crossing where it has one lit wall, a floor route across it (FloorRoute: a step onto the wall
##   from each stretch to step on), no warnings; no other campaign level asks for any;
## - real physics at 3, 5 and 6 lanes: a runner who steps onto the lit wall in its lit stretch, lands on each platform
##   and steps back on from it crosses (early, midway or late in each stretch), on either wall where both are lit;
##   one who stays on the platform falls into the next hole, one who jumps from it too, and one who heads for the open
##   wall falls in; the grapple's save over a later hole carries the runner onto the platform after it.

const APPROACH_AT: float = 100.0
const HUSH: String = "dead_zone/2"

var sim: RunSim
var campaign: Campaign


func run() -> void:
	sim = RunSim.new(tree, tuning)
	campaign = load("res://data/campaign/campaign.tres") as Campaign
	_test_numbers()
	_test_hush()
	await _test_dismounts()
	await _test_crossings()
	await _test_falls()
	await _test_claws_and_dash()
	await _test_save()


## A track of `lanes` lanes with one extended wall run of `runs` wall runs (WallRunGapPlacement.make) whose clear run-in
## starts at `approach`, its lit wall on `side` (and the other too with `both`): its holes, its open wall and its
## platforms' notches (WallRunGapPlacement.openings_of), shaped for movement tuning `mt`'s run speed (the shared
## tuning's by default).
func _track(lanes: int, runs: int, side: int, both: bool, mt: MovementTuning = null, approach: float = APPROACH_AT) -> LevelLayout:
	var m: MovementTuning = mt if mt != null else tuning
	var l := RunSim.layout(lanes, 700.0)
	var w: Dictionary = WallRunGapPlacement.make(WallRunGapPlacement.shape_for(m, m.run_speed, null, null, runs),
		approach, side, both)
	l.wall_run_gaps.append(w)
	for lane: int in lanes:
		for h: Vector2 in WallRunGapPlacement.lane_holes(l, w, lane):
			l.gaps.append({"lane": lane, "start": h.x, "end": h.y, LevelLayout.WALL_RUN_HOLE: true})
	l.wall_gaps.append_array(WallRunGapPlacement.openings_of(w, m.run_speed))
	l.wall_gaps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["start"]) < float(b["start"]))
	return l


## Task S3 (the owner, October 23, 2026: on The Hush's extended wall runs, pressing left or right to come off the wall
## threw the runner two lanes, not one, so he died many times). The notch at each platform's near end
## (WallRunGapPlacement.openings_of) drops every standard wall run off onto the platform just where the move to come
## off the wall is due, and that move, made a moment after the drop, was a lane switch from the outer lane: one lane
## further, over the hole beside the platform. Now a move away from the wall while the runner comes down from a wall the
## game took them off is the dismount it meant (Player._on_move, MovementTuning.wall_release_grace). At The Hush's own
## speed, at 3, 5 and 6 lanes, on a triple on either wall and a double with both lit (on each): a runner who steps onto
## the wall early or late in each stretch and presses away from it around each platform's near end (on the wall before
## it: a wall jump; at it, and as the notch drops them) comes down onto the platform in the outer lane, one lane off the
## wall, steps back on from its last stretch and crosses; and once more just as the last wall run ends over the landing
## floor. With the grace off (the old rule), the same press over the first platform falls into the hole beside it.
func _test_dismounts() -> void:
	var mt: MovementTuning = campaign.configure(campaign.step(HUSH), 5).movement_for(tuning)
	var v: float = mt.run_speed
	var wall_run: float = (mt.wall_entry_time + mt.wall_slide_time) * v
	var old: MovementTuning = mt.duplicate() as MovementTuning
	old.wall_release_grace = 0.0
	check(v > tuning.run_speed and mt.wall_release_grace > 0.0, "(The Hush runs at %.1f m/s; the grace is %.2f s)"
		% [v, mt.wall_release_grace])
	for lanes: int in [3, 5, 6]:
		for case: Array in [[3, -1, false], [3, 1, false], [2, 1, true]]:
			var runs: int = case[0]
			var walls: Array = [-1, 1] if bool(case[2]) else [int(case[1])]
			for side: int in walls:
				var layout: LevelLayout = _track(lanes, runs, int(case[1]), bool(case[2]), mt, 30.0)
				var w: Dictionary = layout.wall_run_gaps[0]
				var c: Array[Vector3] = WallRunGapPlacement.crossings_of(w)
				var p: Array[Vector2] = WallRunGapPlacement.platforms_of(w)
				var toward: StringName = &"move_left" if side < 0 else &"move_right"
				var away: StringName = &"move_right" if side < 0 else &"move_left"
				var outer: int = layout.outer_lane(side)
				var landing: float = float(w["landing"])
				var tag: String = "(%d lanes, %d runs, %s wall%s)" % [lanes, runs, "left" if side < 0 else "right",
					", both lit" if bool(case[2]) else ""]
				for k: float in [0.15, 0.9]:
					# Seconds from each platform's near end (its notch's start): before it, on the wall over the hole, the
					# move is a wall jump; from it on the notch has dropped the runner and they are coming down.
					for off: float in [-0.12, 0.0, 0.05, 0.12, 0.2]:
						var actions: Array = []
						var probes: Array = []
						var last_on: float = 0.0
						for i: int in c.size():
							last_on = lerpf(c[i].x + 0.3, c[i].y - 0.8, k)
							actions.append([last_on, toward])
							if i < p.size():
								actions.append([p[i].x + off * v, away])
								probes.append(p[i].x + 0.6 * v)
						# The last wall run's own end, over the landing floor: a move away just after it.
						var ends_at: float = last_on + wall_run
						actions.append([ends_at + 0.06 * v, away])
						probes.append(ends_at + 0.5 * v)
						var r: Dictionary = await sim.run(layout, outer, (ends_at + 0.6 * v) / v, actions, probes, mt)
						var what: String = "stepping on %d%% into each stretch and pressing away %+.2f s from each platform %s" \
							% [roundi(k * 100.0), off, tag]
						var on_platforms: bool = true
						for q: float in probes.slice(0, p.size()):
							var at: Dictionary = r["at"][q]
							on_platforms = on_platforms and at["surface"] == "floor" and int(at["lane"]) == outer and bool(at["alive"])
						check(on_platforms, "a runner who comes off the wall onto each platform lands on it, one lane off the wall (%s): %s"
							% [r["at"], what])
						var events: Array = r["events"]
						check(bool(r["alive"]) and events.count(&"wall_enter") == runs and events.count(&"wall_exit") == 1,
							"and crosses on %d wall runs: %s %s, %s" % [runs, r["cause"], events, what])
						var end: Dictionary = r["at"][probes[-1]]
						check(end["surface"] == "floor" and int(end["lane"]) == outer and ends_at > float(w["end"]) and ends_at < landing,
							"a move away just as the last wall run ends comes off it one lane too (%s) %s" % [end, what])
				# The old rule: the move made as the notch drops the runner switched them one lane further, into the hole.
				var drop_at: float = p[0].x + 0.05 * v
				var before: Dictionary = await sim.run(layout, outer, (p[0].x + 0.8 * v) / v,
					[[lerpf(c[0].x + 0.3, c[0].y - 0.8, 0.5), toward], [drop_at, away]], [], old)
				check(not bool(before["alive"]) and String(before["cause"]) == "fell"
					and (before["events"] as Array).has(&"wall_gap_drop") and int(before["lane"]) == outer - side,
					"(with the grace off, the old rule, the same move throws the runner a second lane, into the hole: %s, lane %d) %s"
					% [before["cause"], int(before["lane"]), tag])


func _test_numbers() -> void:
	var t: WallRunGapTuning = WallRunGapPlacement.tuning()
	var pt: PowerupTuning = WallRunGapPlacement.powerups()
	var hush: LevelConfig = campaign.configure(campaign.step(HUSH), 5)
	for mt: MovementTuning in [tuning, hush.movement_for(tuning)]:
		var v: float = mt.run_speed
		var one: WallRunGapPlacement.Shape = WallRunGapPlacement.shape_for(mt, v)
		var wall_run: float = (mt.wall_entry_time + mt.wall_slide_time) * v
		var drop: float = WallRunGapPlacement.drop_seconds(mt) * v
		var fast: float = v + maxf(mt.speed_pad_boost, mt.ramp_speed_boost)
		var reach: float = mt.jump_distance(fast) + mt.coyote_time * fast + pt.dash_duration * pt.dash_speed_bonus \
			+ mt.visual_size.z
		for runs: int in [2, 3]:
			var s: WallRunGapPlacement.Shape = WallRunGapPlacement.shape_for(mt, v, t, pt, runs)
			var tag: String = "(%d runs at %.1f m/s)" % [runs, v]
			check(is_equal_approx(s.gap, one.gap) and s.gap > reach,
				"each hole is an ordinary wall-run gap's, longer than any jump (%.1f m against %.1f m) %s" % [s.gap, reach, tag])
			check(s.platform >= (t.entry_window_seconds + t.exit_margin_seconds + mt.coyote_time) * v + drop - 0.01,
				"a platform holds where the latest standard wall run over the hole before it drops the runner %s" % tag)
			check(s.platform < wall_run * 0.75, "a platform is small: under three quarters of a wall run (%.1f m) %s"
				% [s.platform, tag])
			var across: float = s.span() + s.window
			check(absf(across - runs * wall_run) < wall_run * 0.3,
				"from its lit stretch to its far edge it is about %d standard wall runs long (%.1f m, %.1f m each) %s"
				% [runs, across, wall_run, tag])
			var w: Dictionary = WallRunGapPlacement.make(s, 0.0, 1)
			check(WallRunGapPlacement.platforms_of(w).size() == runs - 1 and WallRunGapPlacement.crossings_of(w).size() == runs,
				"%d platforms and %d wall runs %s" % [runs - 1, runs, tag])
			check(WallRunGapPlacement.open_wall_of(w).get("side", 0) == -1
				and WallRunGapPlacement.open_wall_of(WallRunGapPlacement.make(s, 0.0, 1, true)).is_empty(),
				"one lit wall opens the other; both lit open none " + tag)


func _test_hush() -> void:
	for s: CampaignStep in campaign.steps():
		if s.is_level() and s.id != HUSH:
			check(s.level.extended_wall_runs.is_empty(), "no extended wall runs in %s" % s.id)
	var want: Array = [[2, 2], [2, 1], [3, 1]]
	for lanes: int in [3, 5, 6]:
		var config: LevelConfig = campaign.configure(campaign.step(HUSH), lanes)
		var tag: String = "%s lanes=%d" % [HUSH, lanes]
		var gen: LevelGenerator = LayoutCache.generator(config, tuning, LevelGenerator.load_for(config))
		var layout: LevelLayout = gen.layout
		check(gen.warnings.is_empty(), "no warnings %s %s" % [tag, gen.warnings])
		var extended: Array[Dictionary] = []
		for w: Dictionary in layout.wall_run_gaps:
			if WallRunGapPlacement.runs_of(w) > 1:
				extended.append(w)
		var got: Array = []
		for w: Dictionary in extended:
			got.append([WallRunGapPlacement.runs_of(w), WallRunGapPlacement.sides_of(w).size()])
		check(got == want, "its three, in order: a double with both walls, a double and a triple with one (%s) %s"
			% [got, tag])
		LayoutChecks.check_wall_run_gaps(self, layout, config, tag)
		var grid := FloorRoute.new(layout, config.movement_for(tuning))
		for w: Dictionary in extended:
			var where: String = "(%d runs at %.0f m) %s" % [WallRunGapPlacement.runs_of(w), float(w["start"]), tag]
			var open: Dictionary = WallRunGapPlacement.open_wall_of(w)
			if not open.is_empty():
				check(layout.wall_gap_between(float(w["approach"]) + 0.5, float(w["end"]) - 0.5, int(open["side"])),
					"its other wall is open over its crossing " + where)
			# Its lit walls stand over each stretch to step on and each hole, but for the platforms' notches.
			var whole: bool = true
			for s: int in WallRunGapPlacement.sides_of(w):
				for c: Vector3 in WallRunGapPlacement.crossings_of(w):
					var d: float = c.x
					while d < c.z:
						var notch: bool = false
						for p: Vector2 in WallRunGapPlacement.platforms_of(w):
							notch = notch or (d >= p.x - 0.01 and d <= p.x + 3.0)
						whole = whole and (notch or layout.wall_supported(s, d))
						d += 1.0
			check(whole, "its lit walls stand where it is crossed, but for its platforms' notches " + where)
			var route: Dictionary = grid.find(grid.clear_start(float(w["entry"])), float(w["landing"]))
			check(bool(route["ok"]), "a way across it %s: %s" % [where, route.get("reason", "")])
			var steps: int = 0
			for c: Vector3 in WallRunGapPlacement.crossings_of(w):
				for a: Array in route.get("actions", []):
					if String(a[1]) in ["move_left", "move_right"] and float(a[0]) >= c.x - 0.01 and float(a[0]) <= c.y + 0.01:
						steps += 1
						break
			check(steps == WallRunGapPlacement.runs_of(w),
				"the way across steps onto the wall from each stretch to step on (%d of %d) %s" % [steps, WallRunGapPlacement.runs_of(w), where])


func _test_crossings() -> void:
	for lanes: int in [3, 5, 6]:
		for case: Array in [[3, -1, false], [3, 1, false], [2, 1, true]]:
			var runs: int = case[0]
			var walls: Array = [-1, 1] if bool(case[2]) else [int(case[1])]
			for side: int in walls:
				var layout: LevelLayout = _track(lanes, runs, int(case[1]), bool(case[2]))
				var w: Dictionary = layout.wall_run_gaps[0]
				var toward: StringName = &"move_left" if side < 0 else &"move_right"
				var landing: float = float(w["landing"])
				var tag: String = "(%d lanes, %d runs, %s wall%s)" % [lanes, runs, "left" if side < 0 else "right",
					", both lit" if bool(case[2]) else ""]
				for k: float in [0.15, 0.5, 0.9]:
					var actions: Array = []
					for c: Vector3 in WallRunGapPlacement.crossings_of(w):
						actions.append([lerpf(c.x + 0.3, c.y - 0.8, k), toward])
					var r: Dictionary = await sim.run(layout, layout.outer_lane(side), (landing + 20.0) / tuning.run_speed,
						actions, [landing])
					var what: String = "steps onto the wall %d%% into each stretch %s" % [roundi(k * 100.0), tag]
					var enters: int = (r["events"] as Array).count(&"wall_enter")
					check(bool(r["alive"]) and enters == runs, "a runner who %s crosses on %d wall runs: %s, %d"
						% [what, runs, r["cause"], enters])
					check(r["at"][landing]["surface"] == "floor" and int(r["at"][landing]["lane"]) == layout.outer_lane(side),
						"and lands on the landing floor (%s) %s" % [r["at"][landing], what])


func _test_falls() -> void:
	for lanes: int in [3, 5, 6]:
		var layout: LevelLayout = _track(lanes, 2, 1, false)
		var w: Dictionary = layout.wall_run_gaps[0]
		var c: Array[Vector3] = WallRunGapPlacement.crossings_of(w)
		var seconds: float = (float(w["landing"]) + 20.0) / tuning.run_speed
		var tag: String = "(%d lanes)" % lanes
		var first: float = (c[0].x + c[0].y) * 0.5
		var r: Dictionary = await sim.run(layout, lanes - 1, seconds, [[first, &"move_right"]])
		check(not bool(r["alive"]) and String(r["cause"]) == "fell" and float(r["distance"]) > c[1].y,
			"a runner who stays on the platform falls into the next hole %s: %s at %.0f m" % [tag, r["cause"], r["distance"]])
		r = await sim.run(layout, lanes - 1, seconds, [[first, &"move_right"], [c[1].y - 1.0, &"jump"]])
		check(not bool(r["alive"]) and String(r["cause"]) == "fell", "a jump from the platform's end falls in %s: %s"
			% [tag, r["cause"]])
		r = await sim.run(layout, 0, seconds, [[first, &"move_left"]])
		check(not bool(r["alive"]) and (r["events"] as Array).has(&"wall_missing"),
			"a runner who heads for the open wall falls in %s: %s %s" % [tag, r["cause"], r["events"]])


## A wall run longer than the standard one (claws, PowerupTuning.claws_wall_time_multiplier; the dash on the wall) still
## comes down on each platform: the notch at its near end drops the runner off (WallRunGapPlacement.openings_of), and
## a step back on from it carries them over the next hole. And a step back on as soon as the runner lands works too.
func _test_claws_and_dash() -> void:
	for lanes: int in [3, 5, 6]:
		for side: int in [-1, 1]:
			var layout: LevelLayout = _track(lanes, 3, side, false)
			var w: Dictionary = layout.wall_run_gaps[0]
			var c: Array[Vector3] = WallRunGapPlacement.crossings_of(w)
			var p: Array[Vector2] = WallRunGapPlacement.platforms_of(w)
			var toward: StringName = &"move_left" if side < 0 else &"move_right"
			var landing: float = float(w["landing"])
			var tag: String = "(%d lanes, %s wall)" % [lanes, "left" if side < 0 else "right"]
			for k: float in [0.15, 0.9]:
				var loadout := Loadout.new()
				loadout.tiers[&"claws"] = 1
				var world: RunWorld = sim.build_world(layout, loadout)
				world.player.setup(tuning, world.geo, layout.outer_lane(side))
				world.player.apply_loadout(DamageRules.Armor.create(world.rules, 0, false), 0, 0, true,
					world.powerup_tuning.claws_wall_time_multiplier)
				var actions: Array = []
				for x: Vector3 in c:
					actions.append([lerpf(x.x + 0.3, x.y - 0.8, k), toward])
				var r: Dictionary = await sim.step_world(world, (landing + 20.0) / tuning.run_speed, actions, [landing])
				check(bool(r["alive"]) and float(r["distance"]) > landing and (r["events"] as Array).count(&"wall_enter") == 3,
					"with claws, stepping on %d%% into each stretch, a runner crosses on three wall runs %s: %s at %.0f m, %s"
					% [roundi(k * 100.0), tag, r["cause"], float(r["distance"]), r["events"]])
				await sim.free_world(world)
			# The dash on each wall run, midway along it; and a step back on just after landing on each platform.
			var dashed: Array = []
			var eager: Array = [[(c[0].x + c[0].y) * 0.5, toward]]
			for x: Vector3 in c:
				dashed.append([(x.x + x.y) * 0.5, toward])
				dashed.append([x.y + 12.0, &"dash"])
			for q: Vector2 in p:
				eager.append([q.x + 0.3 * tuning.run_speed, toward])
			for case: Array in [["with the dash on each wall run", dashed], ["stepping back on as soon as it lands", eager]]:
				var acts: Array = case[1]
				acts.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
				var r: Dictionary = await sim.run(layout, layout.outer_lane(side), (landing + 20.0) / tuning.run_speed, acts,
					[landing])
				check(bool(r["alive"]) and float(r["distance"]) > landing and (r["events"] as Array).count(&"wall_enter") == 3,
					"%s, a runner crosses %s: %s at %.0f m, %s" % [case[0], tag, r["cause"], float(r["distance"]), r["events"]])


## The grapple's save in the triple's second hole puts the runner on its lit wall, whose run ends over the platform
## after it: they step back on from there and cross.
func _test_save() -> void:
	for side: int in [-1, 1]:
		var layout: LevelLayout = _track(5, 3, side, false)
		var w: Dictionary = layout.wall_run_gaps[0]
		var c: Array[Vector3] = WallRunGapPlacement.crossings_of(w)
		var toward: StringName = &"move_left" if side < 0 else &"move_right"
		var world: RunWorld = sim.build_world(layout)
		world.player.grapples = 1
		world.player.distance = c[1].y - 6.0
		var tag: String = "(%s wall)" % ("left" if side < 0 else "right")
		var r: Dictionary = await sim.step_world(world, (float(w["landing"]) + 20.0 - world.player.distance) / tuning.run_speed,
			[[(c[2].x + c[2].y) * 0.5, toward]], [float(w["landing"])])
		check((r["events"] as Array).has(&"grapple") and bool(r["alive"]) and float(r["distance"]) > float(w["landing"]),
			"the grapple's save over a later hole leaves the runner on the platform after it, to cross on %s: %s %s"
			% [tag, r["cause"], r["events"]])
		await sim.free_world(world)

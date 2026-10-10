extends TestSuite
## Mecha Guppy and Captain Cogs' climb on real physics (GDD §10; task E5e-b1; its data, plan and pieces:
## test_mecha_guppy.gd), at 3, 5 and 6 lanes, at the reference 18 m/s and the Beach's 23.8 m/s, without god mode:
## - a runner who reads the climb (MechaGuppyBot: the lanes that lead up read off the hut and the roofs, a lane switch
##   at a time) climbs through phases 1 and 2 without a fall, with hits landed as it climbs (a stand-in for E5e-b2's
##   bombs: one each time it lands on a higher roof), into phase 3's top, which ends the fight; phase 2's climb is
##   15-25% faster, measured;
## - the worst case, on physics: before every step's pads the runner goes to the lane farthest from the lanes that
##   lead up and jumps right before the pads (the latest anyone flips up), dashing as it jumps too, then reads only
##   read_seconds after settling on the hut: it still makes every step, with time to spare (the margin, measured);
## - a wrong drop is a fall: death, before the higher roof's front, even from the farthest wrong lane dashing as its
##   lane ends, at both cues, at 3 and 6 lanes and both speeds; the grapple saves it up onto the higher roof, into
##   its nearest lane that leads up (its rope from the lifted runner to the roof's edge), and a revive after the fall
##   goes there too;
## - phase changes: the first steps planned in phase 2 (closer) and phase 3's top come right after the steps already
##   in sight, and nothing in sight changes; the top's arrival is logged (top_reached), the stub's minute and the
##   waterfall's fade start there;
## - no escalation: through a long phase 1 with no hits the climb keeps the same rhythm; a retry plays the same; the
##   builder's work a frame doesn't grow with the fight;
## - the climbing camera over the climb: the runner on screen, the camera never inside a roof (each step's rise well
##   within RunCamera.FLOOR_REACH) and never snapping (its ease after a drop off a hut moves it under 0.40 m on the
##   first frame, E5e-a's bound); the runner's shadow on the roof under them.
## Each test prints its figures (the phases' ends, the time to spare, phase 2's rate) for the report.

const BOSS_PATH: String = "res://data/bosses/beach_boss.tres"
const LANES: Array[int] = [3, 5, 6]
const SPEEDS: Array[float] = [18.0, 23.8]
## A player's reaction (the suites' bots' usual 0.35 s).
const REACTION: float = 0.35

var sim: RunSim
var def: BossDef


func run() -> void:
	sim = RunSim.new(tree, tuning)
	var slot := load(BOSS_PATH) as BossDef
	def = slot.preview() if slot != null else null
	if def == null:
		check(false, "Mecha Guppy and Captain Cogs' fight loads")
		return
	await _test_climb_through()
	await _test_worst_case()
	await _test_wrong_drops()
	await _test_phase_changes()
	await _test_rhythm_and_retry()
	await _test_camera()


# --- Helpers -------------------------------------------------------------------------------

func _movement(speed: float) -> MovementTuning:
	if is_equal_approx(speed, tuning.run_speed):
		return tuning
	var t: MovementTuning = tuning.duplicate() as MovementTuning
	t.run_speed = speed
	return t


## The fight at `lanes` and `speed` m/s (with `p_def`, the slot's preview by default; with the dash power-up at its
## best tier, a 3 s cooldown, with `dash`): [world, boss].
func _fight(lanes: int, speed: float, p_def: BossDef = null, dash: bool = false) -> Array:
	var d: BossDef = p_def if p_def != null else def
	var t: MovementTuning = _movement(speed)
	var boss := BossEncounter.create(d) as MechaGuppy
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = d
	ctx.config = BossArena.base_config(d)
	ctx.config.lane_count = lanes
	ctx.tuning = t
	var arena: BossArena = boss.plan_arena(ctx)
	var loadout: Loadout = null
	if dash:
		loadout = Loadout.new()
		loadout.tiers[&"dash"] = 4
	var world: RunWorld = sim.build_world(arena.layout, loadout, t, ctx.config)
	boss.setup(world, ctx, arena)
	return [world, boss]


func _def_with(edit: Callable) -> BossDef:
	var out: BossDef = def.duplicate() as BossDef
	var t: MechaGuppyTuning = (def.tuning as MechaGuppyTuning).duplicate() as MechaGuppyTuning
	edit.call(t)
	out.tuning = t
	return out


func _events(boss: BossEncounter, event: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in boss.events:
		if e["event"] == event:
			out.append(e)
	return out


## Steps the world until `done` holds, the runner dies or `seconds` pass, calling `each` before every frame.
func _run(world: RunWorld, seconds: float, done: Callable, each: Callable = Callable()) -> void:
	if not world.player.running:
		await tree.physics_frame
		world.player.running = true
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		if each.is_valid():
			each.call()
		if done.call() or not world.player.alive:
			return
		await tree.physics_frame


# --- Through phases 1 and 2 -------------------------------------------------------------------

## A runner who reads the climb climbs through phases 1 and 2, a hit landing each time it reaches a higher roof
## (E5e-b2's bombs stand-in), into phase 3's top, which ends the fight, without a fall, at every lane count and both
## speeds. Then phase 2's faster climb, measured: eight steps planned in each phase, landing to landing.
func _test_climb_through() -> void:
	var quick: BossDef = _def_with(func(t: MechaGuppyTuning) -> void: t.top_seconds = 8.0)
	for speed: float in SPEEDS:
		for lanes: int in LANES:
			var tag: String = "(%d lanes, %.1f m/s)" % [lanes, speed]
			var pair: Array = _fight(lanes, speed, quick)
			var world: RunWorld = pair[0]
			var boss: MechaGuppy = pair[1]
			var p: Player = world.player
			var bot := MechaGuppyBot.new(boss)
			bot.reaction = REACTION
			var cause: Array[String] = [""]
			p.died.connect(func(c: String) -> void: cause[0] = c)
			var state: Dictionary = {"climbed": 0}
			await _run(world, 240.0, func() -> bool: return boss.is_defeated(), func() -> void:
				bot.step()
				if bot.steps_climbed > int(state["climbed"]):
					state["climbed"] = bot.steps_climbed
					boss.register_hit(&"stand_in"))
			check(boss.is_defeated() and p.alive, "a runner who reads the climb makes it through phases 1 and 2 and phase 3's top %s%s"
				% [tag, "" if p.alive else ": %s at %.0f m, %.1f s" % [cause[0], p.distance, boss.fight_time()]])
			check(bot.min_slack >= REACTION, "with time to spare on every hut (at least %.2f s) %s" % [bot.min_slack, tag])
			var ends: Array[Dictionary] = _events(boss, &"phase_end")
			var times: Array = ends.map(func(e: Dictionary) -> String: return "%.1f" % float(e["t"]))
			check(ends.size() == 2 and _events(boss, &"hit").size() == 10 and not _events(boss, &"top_over").is_empty(),
				"4 hits end phase 1, 6 more phase 2, and phase 3's top runs out (%d phase ends, %d hits; phases end at %s s) %s"
				% [ends.size(), _events(boss, &"hit").size(), times, tag])
			print("  Mecha Guppy's climb %s, a hit on each landing: phases 1 and 2 end at %s s, %d roofs, %.0f m up; least time to spare on a hut %.2f s"
				% [tag, " and ".join(PackedStringArray(times)), bot.steps_climbed, p.floor_y, bot.min_slack])
			await sim.free_world(world)
			check(await _phase_rates(lanes, speed), "phase 2's climb is faster as planned %s" % tag)


## Phase 2's climb against phase 1's, on physics: eight steps planned in phase 1, landing to landing, then four hits
## (phase 2), then eight steps planned in phase 2. GDD §10: 15-25% faster (proposed: about 20%). True if it is.
func _phase_rates(lanes: int, speed: float) -> bool:
	var tag: String = "(%d lanes, %.1f m/s)" % [lanes, speed]
	var pair: Array = _fight(lanes, speed)
	var world: RunWorld = pair[0]
	var boss: MechaGuppy = pair[1]
	var p: Player = world.player
	var bot := MechaGuppyBot.new(boss)
	bot.reaction = REACTION
	# Landings by the phase their step was planned in: [[t, height], ...].
	var by_phase: Array = [[], []]
	var state: Dictionary = {"climbed": 0}
	await _run(world, 200.0, func() -> bool: return (by_phase[1] as Array).size() >= 9, func() -> void:
		bot.step()
		if bot.steps_climbed > int(state["climbed"]):
			state["climbed"] = bot.steps_climbed
			var s: MechaGuppyClimb.Step = boss.climb.step_at(p.distance - 15.0)
			if s != null and s.phase <= 1 and s.index >= 1:
				(by_phase[s.phase] as Array).append([boss.fight_time(), p.floor_y])
			# Phase 1's eight steps landed: four hits, phase 2.
			if (by_phase[0] as Array).size() == 9 and boss.phase_index == 0:
				for i: int in 4:
					boss.register_hit(&"stand_in"))
	var rate: Array[float] = [0.0, 0.0]
	for ph: int in 2:
		var list: Array = by_phase[ph]
		if list.size() >= 9:
			var a: Array = list[0]
			var b: Array = list[8]
			rate[ph] = (float(b[1]) - float(a[1])) / maxf(float(b[0]) - float(a[0]), 0.001)
	var faster: float = rate[1] / maxf(rate[0], 0.001) - 1.0
	var ok: bool = p.alive and faster >= 0.15 and faster <= 0.25
	print("  Mecha Guppy's climb %s: phase 1 %.3f m/s, phase 2 %.3f m/s (%.1f%% faster)" % [tag, rate[0], rate[1], faster * 100.0])
	check(ok, "GDD §10: phase 2 climbs %.1f%% faster on physics (%.3f against %.3f m/s over eight steps each) %s"
		% [faster * 100.0, rate[1], rate[0], tag])
	await sim.free_world(world)
	return ok


# --- The worst case ---------------------------------------------------------------------------

## The fairness margin on physics: the runner takes every step from the lane farthest from its lanes that lead up,
## flips up as late as anyone can (a jump right before the pads), and reads only read_seconds after settling: it
## makes every step, the measured time to spare never below zero.
func _test_worst_case() -> void:
	var t := def.tuning as MechaGuppyTuning
	for dashing: bool in [false, true]:
		for speed: float in SPEEDS:
			for lanes: int in LANES:
				var tag: String = "(%d lanes, %.1f m/s%s)" % [lanes, speed, ", dashing" if dashing else ""]
				var pair: Array = _fight(lanes, speed, null, dashing)
				var world: RunWorld = pair[0]
				var boss: MechaGuppy = pair[1]
				var bot := MechaGuppyBot.new(boss)
				bot.worst_case = true
				bot.dash_flip = dashing
				bot.reaction = t.read_seconds
				await _run(world, 50.0, func() -> bool: return false, bot.step)
				check(world.player.alive and bot.steps_climbed >= 6,
					"from the farthest lane, flipping up as late as anyone can%s and reading %.1f s after settling, it makes every step (%d) %s"
					% [" (a jump and the dash right before the pads)" if dashing else "", t.read_seconds, bot.steps_climbed, tag])
				if dashing:
					check(bot.dashes >= bot.steps_climbed - 1, "it dashed into the flip on every step (%d dashes, %d steps) %s"
						% [bot.dashes, bot.steps_climbed, tag])
				var most: int = 0
				for r: Dictionary in bot.reads:
					var up: Array = r["lanes"]
					if not up.is_empty():
						most = maxi(most, maxi(int(up[0]), lanes - 1 - int(up[-1])))
				check(bot.min_slack >= 0.0, "with time to spare at the last moment (%.3f s; up to %d switches on one hut) %s"
					% [bot.min_slack, most, tag])
				print("  Mecha Guppy's climb, the worst case %s: %d steps, %.3f s to spare at the last moment, up to %d switches"
					% [tag, bot.steps_climbed, bot.min_slack, most])
				await sim.free_world(world)
	# The lanes that reach back at the far end of their F6 range (30 m): the latest dashing flip still never meets their
	# front (MechaGuppyClimb.TONGUE_CLEAR; task E5e-b1's review found 20 m killing such a runner).
	var far_reach: BossDef = _def_with(func(rt: MechaGuppyTuning) -> void: rt.reach_back = 30.0)
	for speed: float in SPEEDS:
		var tag: String = "(3 lanes, %.1f m/s, reach_back 30 m, dashing)" % speed
		var pair: Array = _fight(3, speed, far_reach, true)
		var world: RunWorld = pair[0]
		var bot := MechaGuppyBot.new(pair[1])
		bot.worst_case = true
		bot.dash_flip = true
		bot.reaction = t.read_seconds
		await _run(world, 40.0, func() -> bool: return false, bot.step)
		check(world.player.alive and bot.steps_climbed >= 5 and bot.min_slack >= 0.0,
			"the latest dashing flip never meets the front of lanes that reach back far (%d steps, %.3f s to spare) %s"
			% [bot.steps_climbed, bot.min_slack, tag])
		await sim.free_world(world)


# --- Wrong drops, the grapple, a revive ------------------------------------------------------

## A drop off a hut in a lane that doesn't lead up falls into the floor Mecha Guppy has eaten: death, before the higher
## roof's front in its lane, even from the lane farthest from the lanes that lead up, dashing as that lane ends, at both
## cues (step 0: RUN_ON, step 1: REACH_BACK), at 3 and 6 lanes and both speeds. With a grapple, the save pulls the runner
## up onto the higher roof into its nearest lane that leads up (GDD §10, proposed), its rope running from the lifted
## runner to the roof's edge, and they climb on; a revive after the fall goes there too. And from the nearest wrong lane
## without the dash (5 lanes).
func _test_wrong_drops() -> void:
	var cases: Array[Dictionary] = []
	for lanes: int in [3, 6]:
		for speed: float in SPEEDS:
			for k: int in [0, 1]:
				for mode: String in ["fall", "grapple", "revive"]:
					cases.append({"lanes": lanes, "speed": speed, "step": k, "mode": mode, "far": true})
	for mode: String in ["fall", "grapple", "revive"]:
		cases.append({"lanes": 5, "speed": 23.8, "step": 0, "mode": mode, "far": false})
	for c: Dictionary in cases:
		await _wrong_drop(c)


func _wrong_drop(c: Dictionary) -> void:
	var lanes: int = c["lanes"]
	var speed: float = c["speed"]
	var k: int = c["step"]
	var mode: String = c["mode"]
	var far: bool = c["far"]
	var tag: String = "(%d lanes, %.1f m/s, %s, %s%s)" % [lanes, speed, "RUN_ON" if k % 2 == 0 else "REACH_BACK", mode,
		", the farthest wrong lane, dashing" if far else ", the nearest wrong lane"]
	var pair: Array = _fight(lanes, speed, null, far)
	var world: RunWorld = pair[0]
	var boss: MechaGuppy = pair[1]
	var p: Player = world.player
	var bot := MechaGuppyBot.new(boss)
	bot.reaction = REACTION
	bot.wrong = true
	bot.wrong_at = k
	bot.wrong_far = far
	bot.dash_drop = far
	p.grapples = 1 if mode == "grapple" else 0
	var state: Dictionary = {"cause": "", "death_d": NAN, "lane": -1, "was_ceiling": false, "rope": PackedVector3Array()}
	p.died.connect(func(cause: String) -> void:
		state["cause"] = cause
		state["death_d"] = p.distance)
	var used: Array[StringName] = []
	p.item_used.connect(func(item: StringName) -> void: used.append(item))
	# Up to step k's hut and off its end.
	await _run(world, 40.0, func() -> bool: return boss.climb.steps.size() > k and p.distance > boss.climb.steps[k].deadline + 2.0 \
			and p.surface == Player.Surface.FLOOR, func() -> void:
		bot.step()
		var on_ceiling: bool = p.surface == Player.Surface.CEILING
		if bool(state["was_ceiling"]) and not on_ceiling and boss.climb.steps.size() > k \
				and p.distance >= boss.climb.steps[k].deadline - 1.0:
			state["lane"] = p.lane
		state["was_ceiling"] = on_ceiling)
	var s: MechaGuppyClimb.Step = boss.climb.steps[k]
	var roof: MechaGuppyClimb.Roof = boss.climb.roofs[k + 1]
	var dropped: int = int(state["lane"]) if int(state["lane"]) >= 0 else p.lane
	check(not s.leads_up(dropped) and (not far or bot.dashes >= 1),
		"it drops in a lane that doesn't lead up (lane %d; up %s%s) %s" % [dropped, s.up, ", dashing" if far else "", tag])
	if mode == "grapple":
		await _run(world, 3.0, func() -> bool: return p.grounded and p.surface == Player.Surface.FLOOR, func() -> void:
			if (state["rope"] as PackedVector3Array).is_empty():
				for node: Node in boss.get_children():
					if node is MechaGuppyRope:
						state["rope"] = (node as MechaGuppyRope).ends())
		check(p.alive and used.has(&"grapple") and absf(p.floor_y - roof.top) < 0.01 and p.lane == s.nearest_up(dropped),
			"the grapple pulls them up onto the higher roof, into its nearest lane that leads up (lane %d, on %.1f m) %s"
			% [p.lane, p.floor_y, tag])
		var rope: PackedVector3Array = state["rope"]
		check(rope.size() == 2 and rope[0].y > roof.top - 1.5 and absf(rope[1].y - roof.top) < 0.05,
			"its rope runs from the lifted runner (%.1f m up) to the roof's edge (%.1f m) %s"
			% [rope[0].y if rope.size() == 2 else NAN, roof.top, tag])
		bot.wrong = false
		var at: int = bot.steps_climbed
		await _run(world, 14.0, func() -> bool: return bot.steps_climbed >= at + 2, bot.step)
		check(p.alive and bot.steps_climbed >= at + 1, "and they climb on (%d roofs) %s" % [bot.steps_climbed - at, tag])
	else:
		await _run(world, 3.0, func() -> bool: return false)
		check(not p.alive and state["cause"] == "fell" and float(state["death_d"]) < roof.start_in(dropped),
			"a wrong drop falls into the eaten floor: death (%s at %.1f m), before the higher roof's front (%.1f m) %s"
			% [state["cause"], state["death_d"], roof.start_in(dropped), tag])
		if mode == "revive":
			p.revive()
			await _run(world, 3.0, func() -> bool: return p.grounded and p.surface == Player.Surface.FLOOR)
			check(p.alive and absf(p.floor_y - roof.top) < 0.01 and p.lane == s.nearest_up(dropped),
				"a revive after the fall goes where the grapple would: onto the higher roof, its nearest lane that leads up (lane %d) %s"
				% [p.lane, tag])
	await sim.free_world(world)


# --- Phase changes --------------------------------------------------------------------------------

## A phase change reaches the climb with the first step the runner can't see yet: after the third landing in phase 1
## four hits bring phase 2, after the third in phase 2 six more bring phase 3. Every step in sight at the change stays
## as it was, the next one is phase 2's (closer) or phase 3's top, and no step is ever planned within sight (its hut past
## the edge of sight when it's planned). The runner's arrival on the top is logged (top_reached); the waterfall starts
## fading then, and the stub's minute is counted from then.
func _test_phase_changes() -> void:
	var quick: BossDef = _def_with(func(t: MechaGuppyTuning) -> void: t.top_seconds = 5.0)
	for lanes: int in [3, 6]:
		for speed: float in SPEEDS:
			var tag: String = "(%d lanes, %.1f m/s)" % [lanes, speed]
			var pair: Array = _fight(lanes, speed, quick)
			var world: RunWorld = pair[0]
			var boss: MechaGuppy = pair[1]
			var p: Player = world.player
			var stairs: MechaGuppyStairs = boss.stairs
			var bot := MechaGuppyBot.new(boss)
			bot.reaction = REACTION
			var st: Dictionary = {"climbed": 0, "phase_at": 0, "count": boss.climb.steps.size(), "in_sight_ok": true,
				"changes": [], "first2": -1, "first2_t": -1.0, "top_shown": -1.0, "after_top": -1.0}
			await _run(world, 200.0, func() -> bool: return boss.is_defeated(), func() -> void:
				bot.step()
				# Every step planned live: its hut past the edge of sight (the top has none).
				while int(st["count"]) < boss.climb.steps.size():
					var planned: MechaGuppyClimb.Step = boss.climb.steps[int(st["count"])]
					st["count"] = int(st["count"]) + 1
					if not planned.top and planned.hut_start < p.distance + stairs.sight - 0.5:
						st["in_sight_ok"] = false
				if boss.climb.steps.size() < int(st["count"]):
					st["count"] = boss.climb.steps.size()
				if bot.steps_climbed > int(st["climbed"]):
					st["climbed"] = bot.steps_climbed
					if boss.is_vulnerable() and boss.phase_index < 2 and bot.steps_climbed - int(st["phase_at"]) >= 3:
						var change: Dictionary = {"phase": boss.phase_index + 1, "t": boss.fight_time(),
							"seen": _in_sight(boss, p.distance + stairs.sight)}
						(st["changes"] as Array).append(change)
						for i: int in boss.phase().hits:
							boss.register_hit(&"stand_in")
						st["phase_at"] = bot.steps_climbed
				var first2: int = int(st["first2"])
				if first2 < 0:
					for i: int in boss.climb.steps.size():
						if boss.climb.steps[i].phase == 1 and not boss.climb.steps[i].top:
							st["first2"] = i
							break
				elif float(st["first2_t"]) < 0.0 and p.distance >= boss.climb.steps[first2].pad:
					st["first2_t"] = boss.fight_time()
				if boss.top_reached_at >= 0.0:
					if float(st["top_shown"]) < 0.0:
						st["top_shown"] = boss.waterfall.shown
					elif float(st["after_top"]) < 0.0 and boss.fight_time() >= boss.top_reached_at + 2.5:
						st["after_top"] = boss.waterfall.shown)
			var changes: Array = st["changes"]
			check(boss.is_defeated() and p.alive and changes.size() == 2, "the fight runs through its phases (%d changes) %s"
				% [changes.size(), tag])
			var kept: bool = true
			var next_ok: bool = true
			for change: Dictionary in changes:
				var seen: Dictionary = change["seen"]
				kept = kept and _same_as_seen(boss, seen)
				var after: int = int(seen["last"]) + 1
				if after < boss.climb.steps.size():
					var nxt: MechaGuppyClimb.Step = boss.climb.steps[after]
					next_ok = next_ok and (nxt.top if int(change["phase"]) == 2 else nxt.phase == 1)
				else:
					next_ok = false
			check(kept, "nothing in sight changes when the phase does %s" % tag)
			check(next_ok, "the first step past what's in sight is the new phase's: phase 2's closer step, phase 3's top %s" % tag)
			check(bool(st["in_sight_ok"]), "no step is ever planned within sight %s" % tag)
			var delay: float = float(st["first2_t"]) - float((changes[0] as Dictionary)["t"]) if not changes.is_empty() else INF
			check(float(st["first2_t"]) > 0.0 and delay < 20.0,
				"phase 2's first (closer) step's pads come %.1f s after the phase begins %s" % [delay, tag])
			var reached: Array[Dictionary] = _events(boss, &"top_reached")
			var over: Array[Dictionary] = _events(boss, &"top_over")
			check(reached.size() == 1 and over.size() == 1
				and absf(float(over[0]["t"]) - float(reached[0]["t"]) - 5.0) < 0.1,
				"the runner's arrival on the top is logged, and the stub's minute is counted from it (%s) %s"
				% [[reached.size(), over.size()], tag])
			check(float(st["top_shown"]) > 0.95 and float(st["after_top"]) >= 0.0 and float(st["after_top"]) < 0.01,
				"the waterfall stays until the top is reached, then fades (%.2f then %.2f) %s" % [st["top_shown"], st["after_top"], tag])
			var top_after: float = float(reached[0]["t"]) - float((changes[1] as Dictionary)["t"]) if reached.size() == 1 and changes.size() == 2 else NAN
			print("  Mecha Guppy's phase changes %s: phase 2's first closer step %.1f s after it begins, the top reached %.1f s after phase 3 begins (%d steps taken back and planned again)"
				% [tag, delay, top_after, stairs.replanned])
			await sim.free_world(world)


## What the runner can see at a phase change (huts and roofs that start before track distance `edge`): the steps' and
## roofs' numbers, and the last such step's index.
func _in_sight(boss: MechaGuppy, edge: float) -> Dictionary:
	var steps: Array = []
	var last: int = -1
	for s: MechaGuppyClimb.Step in boss.climb.steps:
		if s.top or s.hut_start >= edge:
			break
		steps.append([s.index, s.pad, s.pad_end, s.hut_start, s.deadline, s.up, s.ends.duplicate()])
		last = s.index
	var roofs: Array = []
	for r: MechaGuppyClimb.Roof in boss.climb.roofs:
		if r.index > 0 and r.first_start() >= edge:
			break
		roofs.append([r.index, r.top, r.starts.duplicate()])
	return {"steps": steps, "roofs": roofs, "last": last}


func _same_as_seen(boss: MechaGuppy, seen: Dictionary) -> bool:
	for entry: Array in seen["steps"]:
		var i: int = entry[0]
		if i >= boss.climb.steps.size():
			return false
		var s: MechaGuppyClimb.Step = boss.climb.steps[i]
		if not (is_equal_approx(s.pad, entry[1]) and is_equal_approx(s.pad_end, entry[2]) and is_equal_approx(s.hut_start, entry[3])
				and is_equal_approx(s.deadline, entry[4]) and s.up == entry[5] and s.ends == entry[6]):
			return false
	for entry: Array in seen["roofs"]:
		var i: int = entry[0]
		if i >= boss.climb.roofs.size():
			return false
		var r: MechaGuppyClimb.Roof = boss.climb.roofs[i]
		if not (is_equal_approx(r.top, entry[1]) and r.starts == entry[2]):
			return false
	return true


# --- No escalation, a retry -------------------------------------------------------------------

## GDD §10: no escalation. Through a long phase 1 with no hits the climb keeps its rhythm (the time between landings
## for steps alike, early and late, the same to a frame); and a retry plays the same (the same lanes, at the same
## moments).
func _test_rhythm_and_retry() -> void:
	var logs: Array[String] = []
	for attempt: int in 2:
		var pair: Array = _fight(5, 23.8)
		var world: RunWorld = pair[0]
		var boss: MechaGuppy = pair[1]
		var bot := MechaGuppyBot.new(boss)
		bot.reaction = REACTION
		var landings: PackedFloat32Array = PackedFloat32Array()
		var state: Dictionary = {"climbed": 0, "visited": 0}
		await _run(world, 130.0, func() -> bool: return false, func() -> void:
			bot.step()
			state["visited"] = maxi(int(state["visited"]), boss.stairs.visited)
			if bot.steps_climbed > int(state["climbed"]):
				state["climbed"] = bot.steps_climbed
				landings.append(boss.fight_time()))
		check(world.player.alive and boss.phase_index == 0 and landings.size() >= 20,
			"a long phase 1 with no hits: the climb goes on (%d roofs, %.0f m up) (attempt %d)" % [landings.size(), world.player.floor_y,
				attempt + 1])
		check(int(state["visited"]) <= 8 and boss.climb.steps.size() >= 20,
			"the builder's work a frame doesn't grow with the fight (at most %d roofs and steps looked at, %d planned) (attempt %d)"
			% [state["visited"], boss.climb.steps.size(), attempt + 1])
		# Steps six apart are alike (the cue and the count cycle with periods 2 and 3).
		var same: bool = landings.size() >= 20
		for i: int in range(8, landings.size() - 1):
			var late: float = landings[i + 1] - landings[i]
			var early: float = landings[i + 1 - 6] - landings[i - 6]
			same = same and absf(late - early) <= 0.05
		check(same, "no escalation: a late step takes as long as the early step like it")
		var lines: PackedStringArray = []
		for r: Dictionary in bot.reads:
			lines.append("%d:%s" % [int(r["step"]), r["lanes"]])
		for l: float in landings:
			lines.append("%.3f" % l)
		logs.append(";".join(lines))
		await sim.free_world(world)
	check(logs[0] == logs[1] and logs[0] != "", "a retry plays the same: the same lanes lead up, the same landings")


# --- The climbing camera ------------------------------------------------------------------------

## The run camera over the climb (RunWorld.camera_climbs, on for the fight): the runner on screen all the way up, the
## camera never inside a roof (each step's rise is well within RunCamera.FLOOR_REACH, so it sees every roof it must
## clear) and never 0.40 m or more from where it was a frame before; the runner's shadow on the roof under them.
func _test_camera() -> void:
	for lanes: int in [3, 6]:
		var tag: String = "(%d lanes)" % lanes
		var pair: Array = _fight(lanes, 23.8)
		var world: RunWorld = pair[0]
		var boss: MechaGuppy = pair[1]
		var p: Player = world.player
		world.effects.shake_scale = 0.0
		var camera := RunCamera.new()
		tree.root.add_child(camera)
		camera.follow(world)
		var bot := MechaGuppyBot.new(boss)
		var shadow := p.get(&"_shadow") as MeshInstance3D
		var out: Dictionary = {"off": 0, "in_roof": 0, "step": 0.0, "shadow_bad": 0, "shadow_ok": 0, "last": NAN, "top": 0.0}
		var rect := Rect2(Vector2.ZERO, camera.get_viewport().get_visible_rect().size)
		world.start()
		for i: int in int(45.0 * Engine.physics_ticks_per_second):
			bot.step()
			await tree.physics_frame
			await tree.process_frame
			if not p.alive:
				break
			var cam: Vector3 = camera.global_position
			var head: Vector3 = p.position + Vector3(0.0, -1.2 if p.surface == Player.Surface.CEILING else 1.2, 0.0)
			for point: Vector3 in [p.position, head]:
				if camera.is_position_behind(point) or not rect.has_point(camera.unproject_position(point)):
					out["off"] = int(out["off"]) + 1
			if _in_roof(boss.climb, world, cam):
				out["in_roof"] = int(out["in_roof"]) + 1
			if not is_nan(float(out["last"])):
				out["step"] = maxf(float(out["step"]), absf(cam.y - float(out["last"])))
			out["last"] = cam.y
			out["top"] = maxf(float(out["top"]), p.floor_y)
			if p.surface == Player.Surface.FLOOR and p.grounded and p.floor_y > 0.5:
				if shadow.visible and absf(shadow.global_position.y - (p.floor_y + 0.02)) < 0.01:
					out["shadow_ok"] = int(out["shadow_ok"]) + 1
				else:
					out["shadow_bad"] = int(out["shadow_bad"]) + 1
		check(p.alive and float(out["top"]) >= 15.0, "the runner climbs to %.0f m %s" % [out["top"], tag])
		check(int(out["off"]) == 0, "the climbing camera keeps the runner on screen all the way up (%d frames off) %s" % [out["off"], tag])
		check(int(out["in_roof"]) == 0, "the camera is never inside a roof (%d frames) %s" % [out["in_roof"], tag])
		# The largest step is the camera's own ease (RunCamera, camera_smoothing) from the view under a hut to the usual
		# framing as the rider drops off its end: about 0.33 m on its first frame with huts 8.5 m up (the view under a hut
		# is then 1.9 m over the higher roof, so the aim moves less than it did with lower huts).
		check(float(out["step"]) < 0.40, "and never snaps (at most %.3f m a frame) %s" % [out["step"], tag])
		print("  Mecha Guppy's climb, the camera %s: up to %.0f m, at most %.3f m a frame, %d frames off screen, %d inside a roof"
			% [tag, out["top"], out["step"], out["off"], out["in_roof"]])
		check(int(out["shadow_bad"]) == 0 and int(out["shadow_ok"]) > 60,
			"the runner's shadow lies on the roof under them (%d frames right, %d wrong) %s" % [out["shadow_ok"], out["shadow_bad"], tag])
		camera.queue_free()
		await sim.free_world(world)


## True if world point `pos` is inside one of the climb's roofs as built (its top over its lanes, down to the street,
## from its lane starts to its eaten edge).
static func _in_roof(climb: MechaGuppyClimb, world: RunWorld, pos: Vector3) -> bool:
	var d: float = -pos.z
	for r: MechaGuppyClimb.Roof in climb.roofs:
		if r.index == 0:
			continue
		if pos.y >= r.top or pos.y < 0.0:
			continue
		for lane: int in world.geo.lane_count:
			var span: Vector2 = world.geo.lane_floor_span(lane)
			if pos.x >= span.x and pos.x <= span.y and r.covers(lane, d):
				return true
	return false

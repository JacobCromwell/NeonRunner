extends TestSuite
## Mecha Guppy's hits by baiting (GDD §10, the owner, October 11, 2026: Captain Cogs' bombs lock onto the runner's lane,
## and one dodged where the lane runs out falls past the edge into Mecha Guppy's jaws; a player who doesn't manage it
## still progresses, more slowly: Captain Cogs sometimes misses into the chasm anyway; task E5e-b3), on real physics:
## - the bait at 3 lanes at 23.8 m/s and 6 lanes at 18 m/s (MechaGuppyBot baiting): its circle shows only on the floor
##   where the bomb will land, following the runner's lane while it seeks (Captain Cogs' aim heard as it begins), and
##   locks with the throw onto the lane the runner is in then; locked in the notch's lane, the bomb goes into the jaws
##   as it passes the roof's top (a hit); the runner left the notch's lane in time, after a reaction;
## - a runner who never baits (MechaGuppyBot.baits off, keeping out of the notch's lane while a bait can lock there)
##   still wins phases 1 and 2 by the fallback, at 3, 5 and 6 lanes and both speeds: every hit Captain Cogs' miss into
##   the chasm, each once fallback_after steps in a row have gone by without one, and slower than a runner who baits
##   (both bots' phase times printed), never hurt, never with a circle in its lane and no floor to switch to;
## - no hit on a step the runner fell, even if the grapple saved them: a runner who lures the bait and then runs off
##   the notch's edge (saved) gets no hit from the bomb that falls past it, and a wrong drop (saved) on a step whose
##   fallback was due gets none either;
## - a runner falling in the notch can't switch into the roof's side below its top (just under it, the switch bumps;
##   deeper, in the pit, a move does nothing), and the grapple's save takes them back up onto the roof, into its lane
##   beside the notch;
## - with no room for a notch on any roof (an extreme tuning), no bait is offered and the fallback still brings the hits.

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
	await _test_bait(3, 23.8)
	await _test_bait(6, 18.0)
	for speed: float in SPEEDS:
		for lanes: int in LANES:
			await _test_both_bots(lanes, speed)
	await _test_fall_in_notch()
	await _test_wrong_drop_on_fallback()
	await _test_notch_side()
	await _test_no_notch()


# --- Helpers -------------------------------------------------------------------------------

func _movement(speed: float) -> MovementTuning:
	if is_equal_approx(speed, tuning.run_speed):
		return tuning
	var t: MovementTuning = tuning.duplicate() as MovementTuning
	t.run_speed = speed
	return t


## The fight at `lanes` and `speed` m/s (with `p_def`, the slot's preview by default), attacks on: [world, boss].
func _fight(lanes: int, speed: float, p_def: BossDef = null) -> Array:
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
	var world: RunWorld = sim.build_world(arena.layout, null, t, ctx.config)
	boss.setup(world, ctx, arena)
	return [world, boss]


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


# --- The bait ----------------------------------------------------------------------------------

## The baiting bot through phase 1: the bait's circle, its lock and its catch (see the header).
func _test_bait(lanes: int, speed: float) -> void:
	var tag: String = "(%d lanes, %.1f m/s)" % [lanes, speed]
	var pair: Array = _fight(lanes, speed)
	var world: RunWorld = pair[0]
	var boss: MechaGuppy = pair[1]
	var p: Player = world.player
	var bombs: MechaGuppyBombs = boss.bombs
	var mt: MechaGuppyTuning = boss.tuning
	var bot := MechaGuppyBot.new(boss)
	bot.reaction = REACTION
	var geo: TrackGeometry = world.geo
	var problems: Array[String] = []
	var st: Dictionary = {"seek_frames": 0}
	await _run(world, 80.0, func() -> bool: return boss.phase_index >= 1, func() -> void:
		bot.step()
		var ring: MeshInstance3D = bombs.seek_ring()
		if ring != null:
			st["seek_frames"] = int(st["seek_frames"]) + 1
			var bait: Dictionary = bombs.bait
			# Where the bomb will land, on that roof's floor, following the runner's lane (sliding there within a lane
			# switch).
			if absf(ring.global_position.z - TrackGeometry.world_z(float(bait["at"]))) > 0.05 \
					or absf(ring.global_position.y - float(bait["y"]) - 0.05) > 0.05:
				problems.append("the following circle is away from where the bomb lands")
			if absf(ring.global_position.x - geo.lane_x(p.lane)) > geo.lane_width + 0.05:
				problems.append("the following circle lags a lane behind the runner")
		# Out of the notch's lane before its edge.
		var k: int = boss.climb.step_index_at(p.distance)
		if k >= 0 and k + 1 < boss.climb.roofs.size():
			var roof: MechaGuppyClimb.Roof = boss.climb.roofs[k + 1]
			if roof.notched() and p.lane == roof.notch_lane and p.distance >= roof.notch_from and absf(p.floor_y - roof.top) < 0.05 \
					and p.surface == Player.Surface.FLOOR:
				problems.append("the runner ran on past the notch's edge at %.0f m" % p.distance))
	check(p.alive and boss.phase_index >= 1, "the baiting runner makes it through phase 1 %s" % tag)
	var seeks: Array[Dictionary] = _events(boss, &"bait_seek")
	var locks: Array[Dictionary] = _events(boss, &"bait_lock")
	var into: Array[Dictionary] = _events(boss, &"shark_hit")
	var ok: bool = seeks.size() == locks.size() and locks.size() >= 4 and int(st["seek_frames"]) > 0
	for e: Dictionary in locks:
		ok = ok and bool(e["baited"]) and absf(float(e["seek"]) - mt.bait_seek) < 0.02 and absf(float(e["warning"]) - mt.lock_seconds) < 0.02
	check(ok and problems.is_empty(), "each bait's circle follows the runner's lane where the bomb will land for %.2f s, then locks onto their lane with the throw %.2f s before it lands (%d baits) %s%s"
		% [mt.bait_seek, mt.lock_seconds, locks.size(), tag, "" if problems.is_empty() else ": " + "; ".join(problems.slice(0, 3))])
	var caught: bool = into.size() == 4
	for e: Dictionary in into:
		caught = caught and int(e["kind"]) == MechaGuppyBombs.Kind.BAIT and bool(e["counted"]) \
			and float(e["y"]) >= float(e["floor"]) - 0.1 and float(e["y"]) <= float(e["floor"]) + 1.6
	check(caught, "every bait locked in the notch's lane goes into the jaws as it passes the roof's top: 4 hits end phase 1 (%s) %s"
		% [into.map(func(e: Dictionary) -> String: return "%.2f m over" % (float(e["y"]) - float(e["floor"]))), tag])
	await sim.free_world(world)


# --- Both bots ---------------------------------------------------------------------------------

## A runner who baits and one who doesn't, through phases 1 and 2 (see the header).
func _test_both_bots(lanes: int, speed: float) -> void:
	var times: Array = []
	for baits: bool in [true, false]:
		var tag: String = "(%d lanes, %.1f m/s, %s)" % [lanes, speed, "baiting" if baits else "not baiting"]
		var pair: Array = _fight(lanes, speed)
		var world: RunWorld = pair[0]
		var boss: MechaGuppy = pair[1]
		var p: Player = world.player
		var mt: MechaGuppyTuning = boss.tuning
		var bot := MechaGuppyBot.new(boss)
		bot.reaction = REACTION
		bot.baits = baits
		var cause: Array[String] = [""]
		p.died.connect(func(c: String) -> void: cause[0] = c)
		var hurt: Array[int] = [0]
		p.item_used.connect(func(_item: StringName) -> void: hurt[0] += 1)
		var traps: Array[String] = []
		await _run(world, 400.0, func() -> bool: return boss.phase_index >= 2, func() -> void:
			bot.step()
			var trap: String = MechaGuppyBot.circle_trap(boss)
			if trap != "" and traps.size() < 3:
				traps.append(trap))
		var ends: Array[Dictionary] = _events(boss, &"phase_end")
		times.append(ends.map(func(e: Dictionary) -> float: return float(e["t"])))
		check(p.alive and boss.phase_index >= 2 and hurt[0] == 0 and traps.is_empty(),
			"the runner wins phases 1 and 2, never hurt, never with a circle in its lane and no floor beside it %s%s"
			% [tag, "" if p.alive and traps.is_empty() else ": %s %s" % [cause[0], "; ".join(traps)]])
		var into: Array[Dictionary] = _events(boss, &"shark_hit")
		var kinds_ok: bool = into.size() == 10
		for e: Dictionary in into:
			kinds_ok = kinds_ok and int(e["kind"]) == (MechaGuppyBombs.Kind.BAIT if baits else MechaGuppyBombs.Kind.HIT) and bool(e["counted"])
		var fallbacks: Array[Dictionary] = _events(boss, &"fallback")
		var cadence: bool = true
		for e: Dictionary in fallbacks:
			cadence = cadence and int(e["dry"]) >= mt.fallback_after
		if baits:
			check(kinds_ok and fallbacks.is_empty() and int(boss.bombs.stats["baited"]) == 10,
				"every hit a bait, no fallback needed (%d hits) %s" % [into.size(), tag])
		else:
			check(kinds_ok and fallbacks.size() == 10 and cadence and int(boss.bombs.stats["baited"]) == 0,
				"every hit Captain Cogs' miss into the chasm, each after %d steps in a row without a hit (%d hits, %d fallbacks) %s"
				% [mt.fallback_after, into.size(), fallbacks.size(), tag])
		await sim.free_world(world)
	var bait_t: Array = times[0]
	var miss_t: Array = times[1]
	var slower: bool = bait_t.size() >= 2 and miss_t.size() >= 2 and float(miss_t[0]) > float(bait_t[0]) * 1.8 \
		and float(miss_t[1]) > float(bait_t[1]) * 1.8
	check(slower, "a runner who doesn't bait progresses, more slowly: phase 1 ends at %s s against %s s, phase 2 at %s s against %s s (%d lanes, %.1f m/s)"
		% ["%.1f" % float(miss_t[0]) if miss_t.size() > 0 else "-", "%.1f" % float(bait_t[0]) if bait_t.size() > 0 else "-",
			"%.1f" % float(miss_t[1]) if miss_t.size() > 1 else "-", "%.1f" % float(bait_t[1]) if bait_t.size() > 1 else "-", lanes, speed])
	print("  Mecha Guppy's hits (%d lanes, %.1f m/s): baiting, phase 1 ends at %s s, phase 2 at %s s; not baiting, at %s s and %s s"
		% [lanes, speed, "%.1f" % float(bait_t[0]) if bait_t.size() > 0 else "-", "%.1f" % float(bait_t[1]) if bait_t.size() > 1 else "-",
			"%.1f" % float(miss_t[0]) if miss_t.size() > 0 else "-", "%.1f" % float(miss_t[1]) if miss_t.size() > 1 else "-"])


# --- No hit from a fall --------------------------------------------------------------------------

## A runner who lures the bait into the notch's lane and then runs off the notch's edge (the grapple saving them) gets no
## hit from the bomb that falls past the edge; they're pulled back up onto the roof beside the notch and climb on.
func _test_fall_in_notch() -> void:
	var pair: Array = _fight(3, 23.8)
	var world: RunWorld = pair[0]
	var boss: MechaGuppy = pair[1]
	var p: Player = world.player
	p.grapples = 1
	var bot := MechaGuppyBot.new(boss)
	bot.reaction = REACTION
	bot.stay_in_notch_at = 1
	var fell_lane: Array[int] = [-1]
	await _run(world, 40.0, func() -> bool: return bot.steps_climbed >= 4, func() -> void:
		bot.step()
		if fell_lane[0] < 0 and not _events(boss, &"fell").is_empty():
			fell_lane[0] = p.lane)
	var falls: Array[Dictionary] = _events(boss, &"fell")
	var locks: Array[Dictionary] = _events(boss, &"bait_lock")
	var step1_hit: bool = false
	for e: Dictionary in _events(boss, &"hit"):
		step1_hit = step1_hit or (float(e["t"]) > float(locks[1]["t"]) and float(e["t"]) < float(locks[1]["t"]) + 2.0 if locks.size() > 1 else false)
	check(p.alive and falls.size() == 1 and int(falls[0]["step"]) == 1 and locks.size() >= 2 and bool(locks[1]["baited"]) and not step1_hit
		and boss.pattern.fell_on(1) and int(boss.bombs.stats["chasm"]) >= 1,
		"a runner who lured the bait and ran off the notch's edge (the grapple saving them) gets no hit from it: the bomb falls past (%d falls, %d hits)"
		% [falls.size(), boss.hits_landed])
	var saves: Array[Dictionary] = _events(boss, &"save")
	var roof: MechaGuppyClimb.Roof = boss.climb.roofs[2]
	var beside: int = roof.notch_lane + (1 if roof.notch_lane == 0 else -1)
	check(saves.size() == 1 and int(saves[0]["lane"]) == beside and bot.steps_climbed >= 4,
		"the grapple pulls them back up onto the roof, into its lane beside the notch (lane %s, %d steps climbed)"
		% [saves[0]["lane"] if not saves.is_empty() else "-", bot.steps_climbed])
	await sim.free_world(world)


## A wrong drop (the grapple saving it) on a step whose fallback was due: no fallback that step; it comes at the next.
func _test_wrong_drop_on_fallback() -> void:
	var pair: Array = _fight(3, 23.8)
	var world: RunWorld = pair[0]
	var boss: MechaGuppy = pair[1]
	var p: Player = world.player
	p.grapples = 1
	var mt: MechaGuppyTuning = boss.tuning
	var due: int = mt.fallback_after
	var bot := MechaGuppyBot.new(boss)
	bot.reaction = REACTION
	bot.baits = false
	bot.wrong = true
	bot.wrong_at = due
	await _run(world, 60.0, func() -> bool: return bot.steps_climbed >= due + 3, bot.step)
	var skipped: Array[Dictionary] = _events(boss, &"fallback_skipped")
	var fallbacks: Array[Dictionary] = _events(boss, &"fallback")
	check(p.alive and not skipped.is_empty() and int(skipped[0]["step"]) == due and not fallbacks.is_empty()
		and int(fallbacks[0]["step"]) == due + 1 and boss.hits_landed == 1,
		"a wrong drop saved by the grapple on step %d, whose fallback was due, gets no hit; the fallback comes at the next step (%s, %d hits)"
		% [due, fallbacks.map(func(e: Dictionary) -> int: return int(e["step"])), boss.hits_landed])
	await sim.free_world(world)


# --- The notch's side ------------------------------------------------------------------------------

## A runner falling in the notch, below the roof's top, can't switch into the roof's side beside it: just under the top (above
## MovementTuning.pit_depth) the switch bumps; deeper, in the pit, a move does nothing (Player: no lane moves in a pit).
func _test_notch_side() -> void:
	var pair: Array = _fight(3, 18.0)
	var world: RunWorld = pair[0]
	var boss: MechaGuppy = pair[1]
	var c: MechaGuppyClimb = boss.climb
	var p: Player = world.player
	c.plan_until(600.0, 0)
	var roof: MechaGuppyClimb.Roof = c.roofs[1]
	var notch: int = roof.notch_lane
	var inner: int = notch + (1 if notch == 0 else -1)
	var events: Array[StringName] = []
	p.movement_event.connect(func(kind: StringName) -> void: events.append(kind))
	boss.stairs.update(roof.notch_from - 20.0)
	await tree.physics_frame
	world.start()
	var results: Array[String] = []
	for below: float in [1.0, 0.1]:
		events.clear()
		p.distance = roof.notch_from + 3.0
		p.surface = Player.Surface.FLOOR
		p.floor_y = roof.top
		p.h = roof.top - below
		p.vh = 0.0
		p.grounded = false
		p.in_pit = false
		p.lane = notch
		p.set(&"_x", world.geo.lane_x(notch))
		p.floor_base = roof.top
		p.grapples = 0
		await tree.physics_frame
		var pit: bool = p.in_pit
		p.press(&"move_right" if inner > notch else &"move_left")
		await physics_frames(3)
		var x_off: float = absf(float(p.get(&"_x")) - world.geo.lane_x(notch))
		results.append("%.1f m under: %s, %s, lane %d" % [below, "in the pit" if pit else "above the pit", events, p.lane])
		if pit:
			check(roof.notched() and p.lane == notch and not events.has(&"lane_blocked") and x_off < 0.01,
				"falling in the notch %.1f m under the roof's top (in the pit), a switch toward the roof does nothing (%s)"
				% [below, results.back()])
		else:
			check(roof.notched() and events.has(&"lane_blocked") and p.lane == notch,
				"falling in the notch %.1f m under the roof's top, a switch into the roof's side bumps (%s)" % [below, results.back()])
	await sim.free_world(world)


# --- No room for a notch ---------------------------------------------------------------------------

## With no room for a notch on any roof (an extreme tuning: the shortest run on a roof, the longest notch), no bait is
## ever offered, and the fallback still brings the hits, one every fallback_after + 1 steps: the fight never stalls.
func _test_no_notch() -> void:
	var d: BossDef = def.duplicate() as BossDef
	var t: MechaGuppyTuning = (def.tuning as MechaGuppyTuning).duplicate() as MechaGuppyTuning
	t.roof_seconds = 1.0
	t.notch_back = 16.0
	d.tuning = t
	var pair: Array = _fight(3, 18.0, d)
	var world: RunWorld = pair[0]
	var boss: MechaGuppy = pair[1]
	var bot := MechaGuppyBot.new(boss)
	bot.reaction = REACTION
	var due: int = t.fallback_after
	await _run(world, 90.0, func() -> bool: return boss.hits_landed >= 2, bot.step)
	var notched: int = 0
	for r: MechaGuppyClimb.Roof in boss.climb.roofs:
		notched += 1 if r.notched() else 0
	var fallbacks: Array[Dictionary] = _events(boss, &"fallback")
	check(world.player.alive and notched == 0 and _events(boss, &"bait_seek").is_empty() and boss.hits_landed >= 2
		and fallbacks.size() >= 2 and int(fallbacks[0]["step"]) == due and int(fallbacks[1]["step"]) == 2 * due + 1,
		"with no room for a notch on any roof (roof_seconds %.1f s, notch_back %.0f m), no bait is offered and the fallback still brings the hits, every %d steps (%d roofs notched, fallbacks on steps %s, %d hits)"
		% [t.roof_seconds, t.notch_back, due + 1, notched, fallbacks.map(func(e: Dictionary) -> int: return int(e["step"])),
			boss.hits_landed])
	await sim.free_world(world)

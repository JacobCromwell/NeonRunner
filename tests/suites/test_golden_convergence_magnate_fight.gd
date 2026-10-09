extends TestSuite
## The Golden Convergence's second stage, The Magnate, played through (GDD §10; task E5d-d), at 3, 5 and 6 lanes
## and at quick play's 18 m/s and the Golden Zone's 25 m/s, with a runner who plays it by what it shows
## (GoldenConvergenceBot, reacting REACTION late; no god mode, no armor):
## - from the checkpoint (phase 4) to the end: the transition, then each phase's beats (the Pounce, the bait, the
##   Cable Lash from phase 5), the bot dodging every Pounce and answering every Lash untouched, taking each bait
##   and stomping his back once a phase (three stomps: his paces 1, 1.15 and 1.3), the hurl after each of the
##   first two; every Pounce locked at least LOCK_MIN before he lands, every Lash warned for lash_warning before
##   the whip; then the defeat, the runner past him, and victory_over;
## - the release at every lane count and speed: a runner who doesn't jump onto his back is never reached;
## - it plays the same on every attempt.
## His parts one at a time: test_golden_convergence_magnate.gd.

const BOSS_PATH: String = "res://data/bosses/golden_boss.tres"
const STAGE_2: int = 3
const LANES: Array[int] = [3, 5, 6]
## Quick play's speed and the Golden Zone's (GDD §3).
const SPEEDS: Array[float] = [18.0, 25.0]
const REACTION: float = 0.35
const LOCK_MIN: float = 1.0
const FRAME: float = 1.0 / 60.0
## Stage 2 from the checkpoint is over well within this (measured about 76 s of fight).
const MAX_SECONDS: float = 150.0

var sim: RunSim
var def: BossDef


func run() -> void:
	sim = RunSim.new(tree, tuning)
	var slot := load(BOSS_PATH) as BossDef
	def = slot if slot != null and slot.is_built() else null
	if def == null:
		check(false, "the Golden Convergence's fight is built")
		return
	for lanes: int in LANES:
		for speed: float in SPEEDS:
			await _test_stage_two(lanes, speed)
	for lanes: int in LANES:
		for speed: float in SPEEDS:
			await _test_release(lanes, speed)
	await _test_same_every_attempt()


func _fight(lanes: int, speed: float, beats: String = "") -> Array:
	var d: BossDef = def
	if beats != "":
		d = def.duplicate() as BossDef
		var t := (def.tuning as GoldenConvergenceTuning).duplicate() as GoldenConvergenceTuning
		var list := PackedStringArray()
		for i: int in t.phase_beats.size():
			list.append(beats)
		t.phase_beats = list
		d.tuning = t
	var boss := BossEncounter.create(d) as GoldenConvergence
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = d
	ctx.config = BossArena.base_config(d)
	ctx.config.lane_count = lanes
	ctx.config.run_speed = speed
	ctx.tuning = tuning
	ctx.boss_resume = {"phase": STAGE_2}
	var arena: BossArena = boss.plan_arena(ctx)
	var world: RunWorld = sim.build_world(arena.layout, null, tuning, ctx.config)
	boss.setup(world, ctx, arena)
	return [world, boss]


func _bot(boss: GoldenConvergence) -> GoldenConvergenceBot:
	var bot := GoldenConvergenceBot.new(boss)
	bot.reaction = REACTION
	return bot


func _events(boss: BossEncounter, event: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in boss.events:
		if e["event"] == event:
			out.append(e)
	return out


func _run(world: RunWorld, bot: GoldenConvergenceBot, seconds: float, done: Callable = Callable(),
		each: Callable = Callable()) -> void:
	if not world.player.running:
		await tree.physics_frame
		world.player.running = true
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		if bot != null:
			bot.step()
		if each.is_valid():
			each.call()
		if (done.is_valid() and done.call()) or not world.player.alive:
			return
		await tree.physics_frame


func _death(world: RunWorld) -> Array[String]:
	var cause: Array[String] = [""]
	world.player.died.connect(func(c: String) -> void: cause[0] = c)
	return cause


# --- Stage 2 played through --------------------------------------------------------------------------------

func _test_stage_two(lanes: int, speed: float) -> void:
	var tag: String = "(%d lanes, %.0f m/s)" % [lanes, speed]
	var pair: Array = _fight(lanes, speed)
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var bot := _bot(boss)
	var cause: Array[String] = _death(world)
	var paces: Array[float] = []
	boss.phase_started.connect(func(_index: int) -> void: paces.append(boss.pace()))
	await _run(world, bot, MAX_SECONDS, func() -> bool: return boss.is_defeated() and boss.victory_over())
	var pc: GoldenConvergencePounce = boss.pounce
	var m: GoldenConvergenceMagnate = boss.magnate
	print("  stage 2 %s: won at %.1f s of fight, %d pounces (%d baits, %d stuns, %d misses), %d lashes, %d overtakes" % [
		tag, boss.fight_time(), pc.pounces, pc.baits, pc.stuns, pc.misses, boss.lash.lashes, boss.overtake.count])
	check(world.player.alive and boss.is_defeated() and boss.victory_over() and m.touches.is_empty(),
		"the bot wins stage 2 from the checkpoint untouched, without god mode %s (%s, %s)" % [tag, cause[0], m.touches])
	check(pc.stomps == 3 and _events(boss, &"weak_point").size() == 3 and boss.transition.hurls == 2 and boss.transition.played == 1,
		"three stomps, one a phase, the hurl after the first two %s" % tag)
	# The second stage's paces, from its first phase (the resume) on.
	check(paces.size() >= 2 and is_equal_approx(paces[-2], 1.15) and is_equal_approx(paces[-1], 1.3),
		"each phase faster: paces %s %s" % [paces, tag])
	var locks: Array[Dictionary] = _events(boss, &"pounce_lock")
	var crashes: Array[Dictionary] = _events(boss, &"pounce_crash")
	var stuns: Array[Dictionary] = _events(boss, &"stun")
	var lock_ok: bool = locks.size() == crashes.size() + stuns.size()
	var landings: Array[Dictionary] = crashes + stuns
	landings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))
	for i: int in mini(locks.size(), landings.size()):
		lock_ok = lock_ok and float(landings[i]["t"]) - float(locks[i]["t"]) >= LOCK_MIN - FRAME
	check(lock_ok, "every Pounce locked at least %.1f s before he lands (%d) %s" % [LOCK_MIN, locks.size(), tag])
	var warned: Array[Dictionary] = _events(boss, &"lash_warned")
	var whips: Array[Dictionary] = _events(boss, &"lash_whip")
	var lash_ok: bool = warned.size() > 0 and warned.size() == whips.size()
	for i: int in mini(warned.size(), whips.size()):
		lash_ok = lash_ok and float(whips[i]["t"]) - float(warned[i]["t"]) >= boss.tuning.lash_warning - FRAME
	var first_lash_phase: int = int(warned[0]["phase"]) if not warned.is_empty() else -1
	check(lash_ok and first_lash_phase == STAGE_2 + 1, "every Cable Lash warned for %.2f s, from the second phase of stage 2 %s" % [
		boss.tuning.lash_warning, tag])
	check(_events(boss, &"runner_past").size() == 1 and _events(boss, &"defeat_over").size() == 1,
		"the feed dies, he collapses and the runner runs past him %s" % tag)
	await sim.free_world(world)


# --- The release -------------------------------------------------------------------------------------------

## A runner in his lane who doesn't jump is never reached: he shakes free release_gap before them at any speed.
func _test_release(lanes: int, speed: float) -> void:
	var tag: String = "(%d lanes, %.0f m/s)" % [lanes, speed]
	var pair: Array = _fight(lanes, speed, "pounce:bait")
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var pc: GoldenConvergencePounce = boss.pounce
	var bot := _bot(boss)
	bot.stomps = false
	var cause: Array[String] = _death(world)
	var rec := {"min_gap": INF}
	await _run(world, bot, 40.0, func() -> bool: return pc.misses >= 1 and not pc.busy(), func() -> void:
		if pc.stunned():
			rec["min_gap"] = minf(float(rec["min_gap"]), pc.stun_back() - world.player.distance))
	var released: Array[Dictionary] = _events(boss, &"stun_released")
	check(pc.stuns == 1 and released.size() == 1 and float(rec["min_gap"]) > 0.0 and world.player.alive
		and boss.magnate.touches.is_empty(), "he shakes free before the runner reaches his back (%.1f m short) %s (%s)" % [
		rec["min_gap"], tag, cause[0]])
	await sim.free_world(world)


# --- Determinism -------------------------------------------------------------------------------------------

func _test_same_every_attempt() -> void:
	var runs: Array = []
	for attempt: int in 2:
		var pair: Array = _fight(5, 18.0)
		var world: RunWorld = pair[0]
		var boss: GoldenConvergence = pair[1]
		var bot := _bot(boss)
		await _run(world, bot, MAX_SECONDS, func() -> bool: return boss.is_defeated() and boss.victory_over())
		var trace: Array[String] = []
		for e: Dictionary in boss.events:
			if e["event"] == &"sound":
				continue
			trace.append("%s@%.3f/%d" % [e["event"], float(e["t"]), int(e["phase"])])
		runs.append({"trace": trace, "distance": snappedf(world.player.distance, 0.001)})
		await sim.free_world(world)
	check(runs.size() == 2 and runs[0]["trace"] == runs[1]["trace"] and runs[0]["distance"] == runs[1]["distance"],
		"stage 2 plays the same on every attempt (%d events)" % (runs[0]["trace"] as Array).size())

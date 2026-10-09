extends TestSuite
## The Golden Convergence's Fist Slam, its bait and the Missile Barrage played through (GDD §10; task E5d-b) by a
## runner who plays them by what they show (GoldenConvergenceBot, reacting REACTION late; no god mode, no armor),
## at 3, 5 and 6 lanes and at quick play's 18 m/s and the Golden Zone's 25 m/s:
## - phase 1's sequence (ON, ON, AHEAD; chances on 2 and 3) and a later phase's (ON, AHEAD, ON, ON, AHEAD;
##   chances on 3 and 4): out from under every fist that comes down on it, over every hole ahead, into the
##   first chance's gate lane as the fist locks: the gate smashed, its tower down beside the causeway, the
##   barrage warming up at once, the runner onto the tower's wall as the marks fill in and on it through the
##   whole burn: untouched from the first slam to the fire's end;
## - every frame: no fist touch live but at an impact, no fire but in its burn, no opened hole but a slam's
##   footprint, a hole never through a standing gate;
## - it plays the same on every attempt.

const BOSS_PATH: String = "res://data/bosses/golden_boss.tres"
const LANES: Array[int] = [3, 5, 6]
const SPEEDS: Array[float] = [18.0, 25.0]
const REACTION: float = 0.35

var sim: RunSim
var def: BossDef


func run() -> void:
	sim = RunSim.new(tree, tuning)
	var slot := load(BOSS_PATH) as BossDef
	def = slot if slot != null and slot.is_built() else null
	if def == null:
		check(false, "the Golden Convergence's fight is built")
		return
	for phase: int in [0, 1]:
		for lanes: int in LANES:
			for speed: float in SPEEDS:
				await _test_clean(phase, lanes, speed)
	await _test_same_every_attempt()


func _fight(lanes: int, speed: float, phase: int) -> Array:
	var d: BossDef = def.duplicate() as BossDef
	var t := (def.tuning as GoldenConvergenceTuning).duplicate() as GoldenConvergenceTuning
	var list := PackedStringArray()
	for i: int in t.phase_beats.size():
		list.append("slams,barrage")
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
	ctx.boss_resume = {"phase": phase, "time": 0.0}
	var arena: BossArena = boss.plan_arena(ctx)
	var world: RunWorld = sim.build_world(arena.layout, null, tuning, ctx.config)
	boss.setup(world, ctx, arena)
	return [world, boss]


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
		bot.step()
		if each.is_valid():
			each.call()
		if (done.is_valid() and done.call()) or not world.player.alive:
			return
		await tree.physics_frame


## Every frame: nothing hurts but at its moment, nothing opens but a footprint, never through a standing gate.
func _watch(boss: GoldenConvergence, rec: Dictionary) -> void:
	var sl: GoldenConvergenceSlams = boss.slams
	var br: GoldenConvergenceBarrage = boss.barrage
	var now: float = boss.fight_time()
	for i: int in GoldenConvergenceFist.RIGS:
		if not sl.fist.touch_on(i):
			continue
		var ok: bool = false
		for s: Dictionary in sl.in_play():
			ok = ok or (int(s["fist"]) == i and int(s["stage"]) == GoldenConvergenceSlams.SlamStage.HIT)
		if not ok:
			(rec["faults"] as Array).append("%.2f: a fist's touch live with no impact" % now)
	if br.missiles.live() and br.stage != GoldenConvergenceBarrage.Stage.FIRE:
		(rec["faults"] as Array).append("%.2f: fire outside its burn" % now)
	if br.stage == GoldenConvergenceBarrage.Stage.FIRE:
		rec["burn_frames"] = int(rec["burn_frames"]) + 1
		if boss.world.player.surface == Player.Surface.WALL:
			rec["wall_frames"] = int(rec["wall_frames"]) + 1
	for fc: FloorCut in boss.world.track.floor_cuts():
		if not fc.began():
			continue
		var key: String = "%d:%d" % [fc.lane, roundi(fc.end * 10.0)]
		if (rec["checked"] as Dictionary).has(key):
			continue
		rec["checked"][key] = true
		var owned: bool = false
		for s: Dictionary in sl.in_play():
			owned = owned or ((s["row"] as Vector2).y == fc.end and (s["lanes"] as Array).has(fc.lane))
		if not owned:
			(rec["faults"] as Array).append("%.2f: lane %d opened outside a footprint" % [now, fc.lane])
		for b: GoldenConvergenceButtress in boss.buttresses:
			if b.standing() and b.lane == fc.lane and fc.end > b.span().x - 0.001 and fc.start < b.span().y:
				(rec["faults"] as Array).append("%.2f: a hole through a standing gate (lane %d)" % [now, fc.lane])


func _test_clean(phase: int, lanes: int, speed: float) -> void:
	var tag: String = "(phase %d, %d lanes, %.0f m/s)" % [phase + 1, lanes, speed]
	var pair: Array = _fight(lanes, speed, phase)
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var bot := GoldenConvergenceBot.new(boss)
	bot.reaction = REACTION
	var cause: Array[String] = [""]
	world.player.died.connect(func(c: String) -> void: cause[0] = c)
	var rec := {"faults": [], "checked": {}, "burn_frames": 0, "wall_frames": 0}
	await _run(world, bot, 50.0, func() -> bool: return not _events(boss, &"barrage_out").is_empty(), func() -> void: _watch(boss, rec))
	var bait: Array[Dictionary] = _events(boss, &"slam_bait")
	var impacts: Array[Dictionary] = _events(boss, &"slam_impact")
	var fire: Array[Dictionary] = _events(boss, &"barrage_fire")
	var first_chance: int = 1 if phase == 0 else 2
	check(world.player.alive and boss.slams.fist.hits.is_empty() and boss.barrage.missiles.hits.is_empty(),
		"the bot plays the slams, the bait and the barrage untouched (%s) %s" % [cause[0], tag])
	check(bait.size() == 1 and int(bait[0]["n"]) == first_chance and impacts.size() == first_chance + 1,
		"it baits the fist into the first chance's gate (slam %d), and the sequence ends there %s" % [first_chance + 1, tag])
	var down: Array[Dictionary] = _events(boss, &"tower_down")
	var warned: Array[Dictionary] = _events(boss, &"barrage_warned")
	check(down.size() == 1 and warned.size() == 1 and not bait.is_empty() and is_equal_approx(float(warned[0]["t"]), float(bait[0]["t"])),
		"the tower comes down and the barrage warms up at once as it falls %s" % tag)
	check(fire.size() == 1 and int(fire[0]["wall"]) != 0 and int(fire[0]["surface"]) == Player.Surface.WALL
		and int(rec["wall_frames"]) == int(rec["burn_frames"]) and int(rec["burn_frames"]) > 0,
		"the runner is on the tower's wall as the fire lands and through the whole burn (%d of %d frames) %s" % [
			rec["wall_frames"], rec["burn_frames"], tag])
	check((rec["faults"] as Array).is_empty(), "nothing hurts but at its moment, no hole but a footprint, none through a gate %s: %s" % [
		tag, ", ".join(PackedStringArray((rec["faults"] as Array).slice(0, 3)))])
	print("  Golden Convergence slams %s: bait at %.1f s, fire at %.1f s, %d slams" % [tag,
		float(bait[0]["t"]) if not bait.is_empty() else -1.0, float(fire[0]["t"]) if not fire.is_empty() else -1.0, impacts.size()])
	await sim.free_world(world)


func _test_same_every_attempt() -> void:
	var logs: Array[String] = []
	for attempt: int in 2:
		var pair: Array = _fight(5, 25.0, 1)
		var world: RunWorld = pair[0]
		var boss: GoldenConvergence = pair[1]
		var bot := GoldenConvergenceBot.new(boss)
		bot.reaction = REACTION
		await _run(world, bot, 30.0)
		logs.append(JSON.stringify(boss.events))
		await sim.free_world(world)
	check(logs[0] == logs[1] and logs[0].length() > 100, "it plays the same on every attempt (30 s of the log)")

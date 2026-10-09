extends TestSuite
## WIP exploration of the Refill Ship.

const BOSS_PATH: String = "res://data/bosses/golden_boss.tres"
const REACTION: float = 0.35

var sim: RunSim
var def: BossDef


func run() -> void:
	sim = RunSim.new(tree, tuning)
	var slot := load(BOSS_PATH) as BossDef
	def = slot if slot.is_built() else slot.preview()
	await _explore(5, 18.0, &"generator")
	await _explore(5, 25.0, &"miss")


func _fight(lanes: int, speed: float, loadout: Loadout = null, phase: int = -1, beats: String = "") -> Array:
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
	if phase > 0:
		ctx.boss_resume = {"phase": phase}
	elif phase < 0:
		ctx.boss_resume = {"phase": 0, "time": 0.0}
	var arena: BossArena = boss.plan_arena(ctx)
	var world: RunWorld = sim.build_world(arena.layout, loadout, tuning, ctx.config)
	boss.setup(world, ctx, arena)
	return [world, boss]


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


func _explore(lanes: int, speed: float, way: StringName) -> void:
	var pair: Array = _fight(lanes, speed, null, -1, "refill:VVH,slams")
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var bot := GoldenConvergenceBot.new(boss)
	bot.reaction = REACTION
	bot.refill_way = way
	var cause: Array[String] = [""]
	world.player.died.connect(func(c: String) -> void: cause[0] = c)
	await _run(world, bot, 40.0, func() -> bool: return boss.phase_index >= 1 or _has(boss, &"slams_start"))
	for e: Dictionary in boss.events:
		if e["event"] in [&"sound"]:
			continue
		print("  %.2f %s" % [float(e["t"]), str(e)])
	print("  alive %s cause %s phase %d" % [world.player.alive, cause[0], boss.phase_index])
	check(true, "explored")
	await sim.free_world(world)


func _has(boss: BossEncounter, event: StringName) -> bool:
	for e: Dictionary in boss.events:
		if e["event"] == event:
			return true
	return false

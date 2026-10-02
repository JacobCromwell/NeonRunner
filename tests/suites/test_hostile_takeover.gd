extends TestSuite
## Hostile Takeover, the Corporate zone's boss (GDD §10; task E5b-a): its slot and data, the train arena.

const BOSS_PATH: String = "res://data/bosses/corporate_boss.tres"
const LANES: Array[int] = [3, 5, 6]
const SPEEDS: Array[float] = [18.0, 23.4]

var sim: RunSim
var slot: BossDef
var def: BossDef


func run() -> void:
	sim = RunSim.new(tree, tuning)
	slot = load(BOSS_PATH) as BossDef
	def = slot.preview() if slot != null else null
	if def == null:
		check(false, "Hostile Takeover's fight loads as a preview")
		return
	await _test_smoke()
	for lanes: int in LANES:
		for speed: float in SPEEDS:
			await _test_bot(lanes, speed)


func _fight(p_def: BossDef, lanes: int, speed: float, loadout: Loadout = null) -> Array:
	var boss := BossEncounter.create(p_def) as HostileTakeover
	var t: MovementTuning = tuning
	if not is_equal_approx(speed, tuning.run_speed):
		t = tuning.duplicate() as MovementTuning
		t.run_speed = speed
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = p_def
	ctx.config = BossArena.base_config(p_def)
	ctx.config.lane_count = lanes
	ctx.tuning = t
	var arena: BossArena = boss.plan_arena(ctx)
	var world: RunWorld = sim.build_world(arena.layout, loadout, t, ctx.config)
	boss.setup(world, ctx, arena)
	return [world, boss]


func _test_smoke() -> void:
	var pair: Array = _fight(def, 5, 18.0)
	var world: RunWorld = pair[0]
	var boss: HostileTakeover = pair[1]
	world.player.god_mode = true
	world.player.grapples = 1_000_000
	world.player.running = true
	for i: int in 60 * 25:
		await tree.physics_frame
	print("  events: ", boss.events.size(), " planned ", boss.board.planned, " lit ", boss.shown.size(), " missed ", boss.missed.size())
	for e: Dictionary in boss.events.filter(func(x: Dictionary) -> bool: return x["event"] != &"carriage_planned").slice(0, 40):
		print("   ", e)
	check(boss.shown.size() > 0, "couplings light up")
	await sim.free_world(world)


func _test_bot(lanes: int, speed: float) -> void:
	var tag: String = "(%d lanes, %.1f m/s)" % [lanes, speed]
	var pair: Array = _fight(def, lanes, speed)
	var world: RunWorld = pair[0]
	var boss: HostileTakeover = pair[1]
	var bot := HostileTakeoverBot.new(boss)
	await tree.physics_frame
	world.player.running = true
	for i: int in 60 * 60:
		bot.step()
		if boss.phase_index >= 1 or not world.player.alive:
			break
		await tree.physics_frame
	var stomps: Array = boss.events.filter(func(e: Dictionary) -> bool: return e["event"] == &"coupling_stomped")
	print("  bot %s: alive %s phase %d stomps %s t %.1f cause %s" % [tag, world.player.alive, boss.phase_index, stomps, boss.fight_time(),
		world.player.last_event])
	if not world.player.alive:
		for l: Dictionary in bot.log.slice(-12):
			print("    ", l)
	check(world.player.alive and boss.phase_index == 1, "the bot wins phase 1 %s" % tag)
	await sim.free_world(world)

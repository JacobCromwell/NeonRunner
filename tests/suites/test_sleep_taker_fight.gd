extends TestSuite
## The Sleep Taker's fight (GDD §10; task E5c-b; its build and attacks: test_sleep_taker.gd,
## test_sleep_taker_attacks.gd), at 3, 5 and 6 lanes and at the reference 18 m/s and the Dead Zone's
## 24.2 m/s.

const BOSS_PATH: String = "res://data/bosses/dead_zone_boss.tres"
const LANES: Array[int] = [3, 5, 6]
const SPEEDS: Array[float] = [18.0, 24.2]
## A player's reaction: the runner moves this long after a warning starts.
const REACTION: float = 0.35

var sim: RunSim
var def: BossDef


func run() -> void:
	sim = RunSim.new(tree, tuning)
	var slot := load(BOSS_PATH) as BossDef
	def = slot if slot != null and slot.is_built() else null
	if def == null:
		check(false, "the Sleep Taker's fight loads")
		return
	await _test_whole_fight()


# --- Helpers -------------------------------------------------------------------------------

## The fight at `lanes` and `speed` m/s: [world, boss].
func _fight(p_def: BossDef, lanes: int, speed: float = 0.0) -> Array:
	var boss := BossEncounter.create(p_def) as SleepTaker
	var t: MovementTuning = tuning
	if speed > 0.0 and not is_equal_approx(speed, tuning.run_speed):
		t = tuning.duplicate() as MovementTuning
		t.run_speed = speed
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = p_def
	ctx.config = BossArena.base_config(p_def)
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


## Steps the fight until `done` holds, the runner dies or `seconds` pass, calling `each` every frame.
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


# --- The whole fight -------------------------------------------------------------------------

## A runner who reads the fight (SleepTakerBot: it dodges by the warnings, runs the arena and stomps
## each generator) beats it on its real arena, without god mode or armor, at every lane count and both
## speeds: three EMPs, three phases, in 60-120 s (GDD §10).
func _test_whole_fight() -> void:
	for speed: float in SPEEDS:
		for lanes: int in LANES:
			var pair: Array = _fight(def, lanes, speed)
			var world: RunWorld = pair[0]
			var boss: SleepTaker = pair[1]
			var bot := SleepTakerBot.new(boss, &"pad")
			bot.reaction = REACTION
			var cause: Array = [""]
			world.player.died.connect(func(c: String) -> void: cause[0] = c)
			await _run(world, 200.0, func() -> bool: return boss.is_defeated(), func() -> void: bot.step())
			var tag: String = "(%d lanes, %.1f m/s)" % [lanes, speed]
			var line: PackedStringArray = []
			for e: Dictionary in boss.events:
				if e["event"] in [&"phase", &"pattern", &"generator", &"lure", &"in_reach", &"generator_smashed",
						&"emp_hit", &"emp_missed", &"lure_missed", &"defeated"]:
					line.append("%s %.1f" % [e["event"], float(e["t"])])
			print("  %s: %s" % [tag, ", ".join(line)])
			check(boss.is_defeated() and world.player.alive, "a runner who reads it beats it %s%s" % [tag,
				"" if world.player.alive else ": %s at %.0f m, %.1f s" % [cause[0], world.player.distance, boss.fight_time()]])
			await sim.free_world(world)

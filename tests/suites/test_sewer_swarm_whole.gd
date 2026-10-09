extends TestSuite
## The Sewer Swarm's whole fight (GDD §10; task E4b): the Rising, Surrounded and The Host in a row:
## - a runner who reads it (SewerSwarmBot: it baits every surge and lunge and takes every crouch's ramp; no god
##   mode, no loadout or armor pickups) wins the whole fight at 3, 5 and 6 lanes and both speeds, phase after phase,
##   never touched, and nothing is made mid-fight;
## - every attempt plays out the same way;
## - its par times: three stars for a clean win, two for one that lets a chance go by in each phase;
## - a death in Surrounded, then a retry (RunContext.retry: the fight over from its start), the same fight, won;
## - through the campaign at every lane count: Gangland 3, then the fight (no god mode), a death in its second
##   phase and the retry, a win through all three phases, its results and stars, the shop and Gangland's
##   outro.

const BOSS_PATH: String = "res://data/bosses/gangland_boss.tres"
const LANES: Array[int] = [3, 5, 6]
const SPEEDS: Array[float] = [18.0, 21.8]
const GANGLAND_SPEED: float = 21.8
## A player's reaction: the runner moves this long after a warning starts or locks.
const REACTION: float = 0.35
## The events compared between attempts.
const LOGGED: Array[StringName] = [&"phase", &"phase_end", &"surge_warn", &"surge_lock", &"surge_crash", &"surge_bait",
	&"surge_pass", &"surge_hit", &"cluster_destroyed", &"cluster_reformed", &"bait_missed", &"climb", &"climb_end",
	&"host_burst", &"host_fling", &"host_splat", &"host_lunge_warn", &"host_lunge", &"host_lunge_pass", &"host_shocked",
	&"host_crouch", &"host_stomped", &"host_missed", &"host_freed", &"host_hit", &"armor_pickup", &"defeated"]

var sim: RunSim
var def: BossDef
## The whole fight's log at 5 lanes and Gangland's speed, and how long it took (s): a clean win.
var _log_5: String = ""
var _clean: float = -1.0


func run() -> void:
	sim = RunSim.new(tree, tuning)
	var slot := load(BOSS_PATH) as BossDef
	def = slot if slot != null and slot.is_built() else null
	if def == null:
		check(false, "the Sewer Swarm's fight is built")
		return
	await _test_wins_whole_fight()
	await _test_same_every_attempt()
	await _test_par_times()
	await _test_retry()
	await _test_campaign()


# --- Helpers -------------------------------------------------------------------------------------

## The fight at `lanes` and `speed` m/s (or as `ctx_in` has it: a retry): [world, boss, context].
func _fight(lanes: int, speed: float, ctx_in: RunContext = null) -> Array:
	var ctx: RunContext = ctx_in
	if ctx == null:
		var t: MovementTuning = tuning
		if not is_equal_approx(speed, tuning.run_speed):
			t = tuning.duplicate() as MovementTuning
			t.run_speed = speed
		ctx = RunContext.new()
		ctx.mode = RunContext.Mode.QUICK
		ctx.boss = def.duplicate() as BossDef
		ctx.boss.armor_rule = false
		ctx.config = BossArena.base_config(def)
		ctx.config.lane_count = lanes
		ctx.tuning = t
	var boss := BossEncounter.create(ctx.boss) as SewerSwarm
	var arena: BossArena = boss.plan_arena(ctx)
	var world: RunWorld = sim.build_world(arena.layout, ctx.loadout, ctx.tuning, ctx.config)
	boss.setup(world, ctx, arena)
	return [world, boss, ctx]


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


func _events(boss: BossEncounter, event: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in boss.events:
		if e["event"] == event:
			out.append(e)
	return out


## What happened in a fight, for comparing attempts.
func _fight_log(boss: BossEncounter) -> String:
	var line: PackedStringArray = []
	for e: Dictionary in boss.events:
		if e["event"] in LOGGED:
			var extra: Dictionary = e.duplicate()
			extra.erase("t")
			extra.erase("event")
			line.append("%s %.3f %s" % [e["event"], float(e["t"]), str(extra)])
	return " | ".join(line)


## A whole fight won by the bot (`skips` chances let go by in each phase): [world, boss, won, phases seen,
## the cause of a death, crowds made after the fight began].
func _play(lanes: int, speed: float, skips: int = 0, ctx_in: RunContext = null) -> Array:
	var pair: Array = _fight(lanes, speed, ctx_in)
	var world: RunWorld = pair[0]
	var boss: SewerSwarm = pair[1]
	var made: int = SwarmCrowd.made
	var bot := SewerSwarmBot.new(boss)
	bot.reaction = REACTION
	bot.skips = skips
	var cause: Array = [""]
	world.player.died.connect(func(c: String) -> void: cause[0] = c)
	var phases: Dictionary = {}
	await _run(world, 300.0, func() -> bool: return boss.is_defeated() and boss.victory_over(), func() -> void:
		phases[boss.phase_index] = true
		bot.step())
	var won: bool = boss.is_defeated() and boss.victory_over() and world.player.alive
	return [world, boss, won, phases.size(), cause[0], SwarmCrowd.made - made]


# --- The whole fight -------------------------------------------------------------------------------

## A runner who reads it wins the whole fight at every lane count and both speeds, through every phase in
## turn, never touched by an attack, without god mode, a loadout or armor pickups; no crowd is made mid-fight.
func _test_wins_whole_fight() -> void:
	for speed: float in SPEEDS:
		for lanes: int in LANES:
			await _wins(lanes, speed)


func _wins(lanes: int, speed: float) -> void:
	var tag: String = "(%d lanes, %.1f m/s)" % [lanes, speed]
	var out: Array = await _play(lanes, speed)
	var world: RunWorld = out[0]
	var boss: SewerSwarm = out[1]
	check(bool(out[2]) and int(out[3]) == 3, "a runner who reads it wins the whole fight, phase after phase %s%s" % [tag,
		"" if world.player.alive else ": %s at %.0f m in phase %d" % [out[4], world.player.distance, boss.phase_index + 1]])
	check(_events(boss, &"surge_hit").is_empty() and _events(boss, &"host_hit").is_empty(),
		"never touched by a surge or the Host %s" % tag)
	check(world.player.armor == 0 and world.player.shield == 0 and _events(boss, &"armor_pickup").is_empty(),
		"the harder fight needs no protection or powerups %s" % tag)
	var baited: int = 0
	for e: Dictionary in _events(boss, &"cluster_destroyed"):
		baited += 1 if e["cause"] in [&"fence", &"hole"] else 0
	var hits: int = baited + boss.host_attacks.stomps + boss.host_attacks.shocked
	check(baited == 5 and hits == 5 + def.phase_list()[2].hits and boss.host_attacks.stomps >= 1,
		"five clusters baited, then the Host's six hits (%d stomps, %d shocked by fences) %s" % [boss.host_attacks.stomps,
		boss.host_attacks.shocked, tag])
	check(int(out[5]) == 0, "every crowd was made before the fight began, none during it %s" % tag)
	var beaten: Array[Dictionary] = _events(boss, &"defeated")
	var took: float = float(beaten[0]["t"]) if not beaten.is_empty() else -1.0
	if lanes == 5 and is_equal_approx(speed, GANGLAND_SPEED):
		_log_5 = _fight_log(boss)
		_clean = took
	check(took > 0.0 and def.stars_for(true, took) == 3, "a clean win (%.1f s) earns three stars %s" % [took, tag])
	var ends: PackedStringArray = []
	for e: Dictionary in _events(boss, &"phase_end"):
		ends.append("%.1f" % float(e["t"]))
	print("  Sewer Swarm, the whole fight (%d lanes, %.1f m/s): %.1f s (phases end at %s)" % [lanes, speed, took, ", ".join(ends)])
	await sim.free_world(world)


## A second attempt with the same moves plays out as the first did.
func _test_same_every_attempt() -> void:
	var out: Array = await _play(5, GANGLAND_SPEED)
	var boss: SewerSwarm = out[1]
	var again: String = _fight_log(boss)
	check(_log_5 != "" and again == _log_5 and again.contains("host_stomped"), "every attempt plays out the same way")
	await sim.free_world(out[0])


## Its par times (BossDef): a clean win earns three stars; one that lets a chance go by in each phase (a surge
## not baited in the Rising and in Surrounded, a lunge or a crouch in The Host) two.
func _test_par_times() -> void:
	check(def.three_star_seconds < def.two_star_seconds, "its par times: three stars under %.0f s, two under %.0f s" % [
		def.three_star_seconds, def.two_star_seconds])
	check(_clean > 0.0 and def.stars_for(true, _clean) == 3, "a clean win (%.1f s) earns three stars" % _clean)
	var out: Array = await _play(5, GANGLAND_SPEED, 1)
	var boss: SewerSwarm = out[1]
	var took: float = boss.fight_time()
	check(bool(out[2]) and def.stars_for(true, took) == 2,
		"a win that lets a chance go by in each phase (%.1f s) earns two" % took)
	await sim.free_world(out[0])
	out = await _play(5, GANGLAND_SPEED, 2)
	var slow: float = (out[1] as SewerSwarm).fight_time()
	check(bool(out[2]) and def.stars_for(true, slow) < 3 and slow > took,
		"one letting two chances go by in each phase (%.1f s) is slower still, and earns no more than two" % slow)
	print("  Sewer Swarm: a clean win %.1f s, one chance missed a phase %.1f s, two %.1f s (par times %.0f s and %.0f s)" % [
		_clean, took, slow, def.three_star_seconds, def.two_star_seconds])
	await sim.free_world(out[0])


# --- A death and a retry -----------------------------------------------------------------------------

## At Gangland's speed on the phone's street: a death in Surrounded (after its first surge), then a retry
## (RunContext.retry: the same fight from its start, no checkpoint), won; the retry plays as the first attempt
## did up to the death.
func _test_retry() -> void:
	var pair: Array = _fight(3, GANGLAND_SPEED)
	var world: RunWorld = pair[0]
	var boss: SewerSwarm = pair[1]
	var ctx: RunContext = pair[2]
	var bot := SewerSwarmBot.new(boss)
	bot.reaction = REACTION
	await _run(world, 120.0, func() -> bool:
		return boss.phase_index == 1 and _events(boss, &"surge_bait").size() >= 3, func() -> void: bot.step())
	check(boss.phase_index == 1 and world.player.alive, "the first attempt reaches Surrounded and baits a strike there")
	var first: String = _fight_log(boss)
	world.player._die("test hazard")
	await sim.free_world(world)
	var next: RunContext = ctx.retry()
	var out: Array = await _play(3, GANGLAND_SPEED, 0, next)
	boss = out[1]
	check(next.attempt == 2 and next.boss_resume.is_empty() and bool(out[2]) and int(out[3]) == 3,
		"a retry starts the fight over and is won through all three phases (3 lanes, %.1f m/s)" % GANGLAND_SPEED)
	check(_fight_log(boss).begins_with(first), "the same fight as the first attempt, up to its death")
	await sim.free_world(out[0])


# --- Through the campaign ---------------------------------------------------------------------------

## The fight in the campaign's flow at every lane count, played by the bot (no god mode): Gangland's last
## level, its boss intro (skipped), then the fight: a death in its second phase, the retry starting it over, and a win through all three
## phases; its results and stars, the shop and the outro's slot.
func _test_campaign() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var saved: Profile = App.profile
	var lanes_pc: int = App.rules.lanes_pc
	for lanes: int in LANES:
		App.profile = SampleProfiles.fresh()
		App.rules.lanes_pc = lanes
		await _campaign_flow(lanes)
	App.rules.lanes_pc = lanes_pc
	App.show_title()
	await tree.process_frame
	App.profile = saved
	main.queue_free()
	App.main = null
	await tree.process_frame


func _campaign_flow(lanes: int) -> void:
	var tag: String = "(%d lanes)" % lanes
	App.play_step(App.campaign.step("gangland/3"))
	App.begin_run()
	await physics_frames(10)
	check(App.run != null and App.run.state == LevelRun.State.RUNNING and App.run.world.player.running
		and App.run.world.geo.lane_count == lanes, "Gangland's last level starts %s" % tag)
	if App.run == null:
		return
	App.run.world.player.distance = App.run.world.layout.length - 3.0
	await physics_frames(int((LevelRun.COMPLETE_PAUSE + 0.5) * 60.0))
	await tree.process_frame
	var level_result: RunResult = (App.screen as ResultsScreen).result if App.screen is ResultsScreen else null
	check(level_result != null and level_result.completed, "and finished %s" % tag)
	if level_result == null:
		return
	App.continue_after_result(level_result)
	(App.screen as ShopScreen).on_close.call()
	await tree.process_frame
	# The boss intro plays (the owner's beats: the swarm rising, SewerSwarmIntro); the player skips it.
	var intro: Cinematic = App.playing_cinematic()
	check(intro is SewerSwarmIntro and intro.step.id == "gangland/boss_intro", "then the boss intro's cinematic %s" % tag)
	if intro == null:
		return
	App.skip_cinematic()
	App.begin_run()
	await physics_frames(3)
	var run: LevelRun = App.run
	check(run != null and run.encounter is SewerSwarm and run.context.step.id == "gangland/boss"
		and run.world.geo.lane_count == lanes and not run.world.player.god_mode
		and is_equal_approx(run.world.tuning.run_speed, GANGLAND_SPEED), "then the fight at Gangland's speed, no god mode %s" % tag)
	if run == null or not run.encounter is SewerSwarm:
		return
	# The first attempt: the Rising won, then a death in Surrounded.
	var boss := run.encounter as SewerSwarm
	var bot := SewerSwarmBot.new(boss)
	bot.reaction = REACTION
	for i: int in 120 * 60:
		if boss.phase_index >= 1 and boss.state == BossEncounter.State.FIGHT or not run.world.player.alive:
			break
		bot.step()
		await tree.physics_frame
	check(boss.phase_index == 1 and run.world.player.alive, "the Rising falls to two baited clusters %s" % tag)
	run.world.player._die("test hazard")
	await physics_frames(int((App.rules.death_screen_delay + 0.3) * 60.0))
	await tree.process_frame
	var died: RunResult = (App.screen as ResultsScreen).result if App.screen is ResultsScreen else null
	check(died != null and not died.completed, "a death ends the attempt %s" % tag)
	if died == null:
		return
	App.continue_after_result(died)
	var shop := App.screen as ShopScreen
	check(shop != null and shop.play_label == "Retry", "with a retry %s" % tag)
	if shop == null:
		return
	shop.on_close.call()
	App.begin_run()
	await physics_frames(3)
	run = App.run
	boss = run.encounter as SewerSwarm if run != null else null
	check(boss != null and run.context.attempt == 2 and run.context.boss_resume.is_empty() and boss.phase_index == 0
		and is_equal_approx(boss.health, boss.max_health) and boss.destroyed == 0,
		"the retry starts the fight over, whole %s" % tag)
	if boss == null:
		return
	# The retry, won.
	bot = SewerSwarmBot.new(boss)
	bot.reaction = REACTION
	var events: Array[Dictionary] = boss.events
	var phases: Dictionary = {}
	for i: int in 300 * 60:
		if App.screen is ResultsScreen or App.run != run or not run.world.player.alive:
			break
		if is_instance_valid(boss):
			phases[boss.phase_index] = true
			bot.step()
		await tree.physics_frame
	await tree.process_frame
	var freed: bool = false
	for e: Dictionary in events:
		freed = freed or e["event"] == &"host_freed"
	check(phases.size() == 3 and freed, "the retry plays all three phases to the Host's freeing %s" % tag)
	var result: RunResult = (App.screen as ResultsScreen).result if App.screen is ResultsScreen else null
	check(result != null and result.completed and result.context.is_boss(), "a win's results follow %s" % tag)
	if result == null:
		return
	check(result.stars == def.stars_for(true, result.time) and result.stars == 3,
		"three stars for a clean fight (%.1f s) %s" % [result.time, tag])
	check(App.profile.is_completed("gangland/boss"), "the boss step counts as done %s" % tag)
	App.continue_after_result(result)
	shop = App.screen as ShopScreen
	check(shop != null and shop.play_label == "Next", "then the shop %s" % tag)
	if shop == null:
		return
	shop.on_close.call()
	await tree.process_frame
	var outro := App.screen as SlotScreen
	var cine: Cinematic = App.playing_cinematic()
	check((outro != null and outro.step.id == "gangland/outro") or (cine != null and cine.step.id == "gangland/outro"),
		"then Gangland's outro %s" % tag)

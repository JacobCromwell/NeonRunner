extends TestSuite
## The Golden Convergence played whole (GDD §10; task E5d-c), with a runner who plays it by what it shows
## (GoldenConvergenceBot, reacting REACTION late; no god mode, no armor), at 3, 5 and 6 lanes and at quick play's
## 18 m/s and the Golden Zone's 25 m/s:
## - from its entrance: stage 1 won (each phase's Refill Ship brought down from its pad: three ships, a third of
##   the suit's health each, the first blowing out one shoulder's pipes, the second the other's, the third bursting
##   the suit open; never a pad missed), then stage 2 from the checkpoint (The Magnate's three stomps), the defeat,
##   the runner past him and victory_over; the runner never touched;
## - the par times (BossDef: two_star_seconds, three_star_seconds, time_bonus_seconds) set from the clean fights'
##   times at the campaign's 25 m/s the way Hostile Takeover's are (three stars a little over a clean fight, two
##   about 40 % over it), and a clean fight at 18 m/s earns three stars too;
## - the campaign (App, the Golden Zone's boss step at its 25 m/s): the real fight, not a preview; a death in stage
##   2 shows the run summary, and the retry resumes at the checkpoint (stage 2's first phase, its transition, the
##   time so far) and is won: the results, its stars from the par times.
## The Refill Ship's parts one at a time: test_golden_convergence_refill.gd; stage 2 alone:
## test_golden_convergence_magnate_fight.gd.

const BOSS_PATH: String = "res://data/bosses/golden_boss.tres"
const STAGE_2: int = 3
const LANES: Array[int] = [3, 5, 6]
## Quick play's speed and the Golden Zone's (GDD §3).
const SPEEDS: Array[float] = [18.0, 25.0]
const CAMPAIGN_SPEED: float = 25.0
const REACTION: float = 0.35
## The whole fight is over well within this (measured about 230 s of fight).
const MAX_SECONDS: float = 480.0
## Hostile Takeover's par times over its clean fight (corporate_boss.tres: 74 s and 96 s over 68.6 s).
const THREE_STAR_OVER: float = 74.0 / 68.6
const TWO_STAR_OVER: float = 96.0 / 68.6

var sim: RunSim
var def: BossDef
## The clean fights' times: "<lanes>/<speed>" → seconds of fight at the defeat.
var times: Dictionary = {}


func run() -> void:
	sim = RunSim.new(tree, tuning)
	var slot := load(BOSS_PATH) as BossDef
	def = slot if slot != null and slot.is_built() else null
	if def == null:
		check(false, "the Golden Convergence's fight is built")
		return
	for lanes: int in LANES:
		for speed: float in SPEEDS:
			await _test_whole(lanes, speed)
	_test_par_times()
	await _test_campaign()


func _fight(lanes: int, speed: float, phase: int = 0) -> Array:
	var boss := BossEncounter.create(def) as GoldenConvergence
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = def
	ctx.config = BossArena.base_config(def)
	ctx.config.lane_count = lanes
	ctx.config.run_speed = speed
	ctx.tuning = tuning
	if phase > 0:
		ctx.boss_resume = {"phase": phase}
	var arena: BossArena = boss.plan_arena(ctx)
	var world: RunWorld = sim.build_world(arena.layout, null, tuning, ctx.config)
	boss.setup(world, ctx, arena)
	return [world, boss]


func _bot(boss: GoldenConvergence) -> GoldenConvergenceBot:
	var bot := GoldenConvergenceBot.new(boss)
	bot.reaction = REACTION
	bot.refill_way = &"generator"
	return bot


func _events(boss: BossEncounter, event: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in boss.events:
		if e["event"] == event:
			out.append(e)
	return out


func _run(world: RunWorld, bot: GoldenConvergenceBot, seconds: float, done: Callable = Callable()) -> void:
	if not world.player.running:
		await tree.physics_frame
		world.player.running = true
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		if bot != null:
			bot.step()
		if (done.is_valid() and done.call()) or not world.player.alive:
			return
		await tree.physics_frame


## Notes every blow the runner takes (an armor or a shield spent) and how they died.
func _watch(player: Player) -> Dictionary:
	var rec := {"blows": [], "cause": ""}
	player.movement_event.connect(func(kind: StringName) -> void:
		if kind in [&"armor_hit", &"armor_break", &"shield_break"]:
			(rec["blows"] as Array).append(kind))
	player.died.connect(func(c: String) -> void: rec["cause"] = c)
	return rec


# --- The whole fight ---------------------------------------------------------------------------------------

func _test_whole(lanes: int, speed: float) -> void:
	var tag: String = "(%d lanes, %.0f m/s)" % [lanes, speed]
	var pair: Array = _fight(lanes, speed)
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var bot := _bot(boss)
	var rec: Dictionary = _watch(world.player)
	var stage_one := {"t": -1.0, "pipes": [], "health": -1.0}
	boss.phase_started.connect(func(index: int) -> void:
		if index == STAGE_2 and float(stage_one["t"]) < 0.0:
			stage_one["t"] = boss.fight_time()
			stage_one["health"] = boss.health)
	boss.refill.hit_landed.connect(func(_info: Dictionary) -> void:
		(stage_one["pipes"] as Array).append([boss.suit.pipes_broken[0], boss.suit.pipes_broken[1]]))
	await _run(world, bot, MAX_SECONDS, func() -> bool: return boss.is_defeated() and boss.victory_over())
	var r: GoldenConvergenceRefill = boss.refill
	var hits: Array[Dictionary] = _events(boss, &"refill_hit")
	var t_won: float = boss.fight_time()
	print("  whole fight %s: stage 1 won at %.1f s (%d refills, %d misses), the fight at %.1f s" % [tag, float(stage_one["t"]),
		r.refills, r.misses, t_won])
	# Stage 1: three ships brought down, one a phase, each a third of the suit's health.
	var damage_ok: bool = hits.size() == 3
	for i: int in hits.size():
		damage_ok = damage_ok and int(hits[i]["phase"]) == i and is_equal_approx(float(hits[i]["damage"]), boss.max_health / 6.0)
	check(float(stage_one["t"]) > 0.0 and r.chains == 3 and r.hits == 3 and damage_ok and r.misses == 0,
		"the bot wins stage 1 from its pads: three ships, one a phase, a third of the suit's health each %s (%d hits, %d misses)" % [
			tag, r.hits, r.misses])
	check(is_equal_approx(float(stage_one["health"]), boss.phase_start_health(STAGE_2)) and not _events(boss, &"checkpoint").is_empty(),
		"stage 2 begins at the fight's checkpoint, at half its health %s" % tag)
	var pipes: Array = stage_one["pipes"]
	check(pipes.size() == 3 and pipes[0] == [true, false] and pipes[1] == [true, true],
		"the first ship blows out his right shoulder's pipes, the second his left's %s (%s)" % [tag, pipes])
	var bursts: Array[Dictionary] = hits.filter(func(e: Dictionary) -> bool: return bool(e["burst"]))
	check(bursts.size() == 1 and int(bursts[0]["phase"]) == STAGE_2 - 1, "and the third bursts the suit open %s" % tag)
	# Stage 2 and the end.
	check(world.player.alive and boss.is_defeated() and boss.victory_over() and (rec["blows"] as Array).is_empty(),
		"the bot wins the whole fight untouched, without god mode %s (%s, %s)" % [tag, rec["cause"], rec["blows"]])
	check(boss.pounce.stomps == 3 and boss.transition.played == 1, "The Magnate's three stomps, after the transition %s" % tag)
	if world.player.alive and boss.is_defeated():
		times["%d/%.0f" % [lanes, speed]] = t_won
	await sim.free_world(world)


# --- The par times -----------------------------------------------------------------------------------------

## Set from the clean fights the way Hostile Takeover's are: three stars a little over a clean fight at the
## campaign's speed, two about 40 % over it; a clean fight at quick play's 18 m/s earns three stars too; the time
## bonus runs out a little past two stars.
func _test_par_times() -> void:
	var at_campaign: Array[float] = []
	var at_quick: Array[float] = []
	for lanes: int in LANES:
		var key: String = "%d/%.0f" % [lanes, CAMPAIGN_SPEED]
		if times.has(key):
			at_campaign.append(float(times[key]))
		var quick: String = "%d/%.0f" % [lanes, SPEEDS[0]]
		if times.has(quick):
			at_quick.append(float(times[quick]))
	if at_campaign.size() != LANES.size() or at_quick.size() != LANES.size():
		check(false, "the par times need every clean fight (%s)" % [times])
		return
	var slowest: float = at_campaign.max()
	print("  clean fights at %.0f m/s: %s; at %.0f m/s: %s; par %.0f / %.0f s, time bonus to %.0f s" % [CAMPAIGN_SPEED,
		at_campaign, SPEEDS[0], at_quick, def.three_star_seconds, def.two_star_seconds, def.time_bonus_seconds])
	check(at_campaign.max() - at_campaign.min() < 5.0, "a clean fight takes about as long at 3, 5 and 6 lanes (%s)" % [at_campaign])
	check(absf(def.three_star_seconds - slowest * THREE_STAR_OVER) <= 3.0 and absf(def.two_star_seconds - slowest * TWO_STAR_OVER) <= 5.0,
		"three stars at %.0f s and two at %.0f s: Hostile Takeover's margins over a clean fight (%.1f s)" % [def.three_star_seconds,
			def.two_star_seconds, slowest])
	check(at_quick.max() <= def.three_star_seconds, "a clean fight at %.0f m/s earns three stars too (%s)" % [SPEEDS[0], at_quick])
	check(def.time_bonus_seconds > def.two_star_seconds and def.time_bonus_seconds <= def.two_star_seconds * 1.3,
		"the time bonus runs out a little past two stars (%.0f s)" % def.time_bonus_seconds)


# --- The campaign ------------------------------------------------------------------------------------------

## The Golden Zone's boss step through the game itself: the real fight at the zone's 25 m/s; the runner wins
## stage 1, then dies in stage 2; the retry resumes at the checkpoint and is won.
func _test_campaign() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var saved: Profile = App.profile
	App.profile = SampleProfiles.fresh()
	await _campaign_flow()
	App.show_title()
	await tree.process_frame
	App.profile = saved
	main.queue_free()
	App.main = null
	await tree.process_frame


func _campaign_flow() -> void:
	var step: CampaignStep = App.campaign.step("golden/boss")
	check(step != null and step.boss != null and step.boss.is_built() and step.boss.preview_scene == "",
		"the Golden Zone's boss step is the built fight, not a preview")
	if step == null:
		return
	App.play_step(step)
	App.begin_run()
	await physics_frames(3)
	var run: LevelRun = App.run
	check(run != null and run.encounter is GoldenConvergence and run.context.step.id == "golden/boss"
		and is_equal_approx(run.world.tuning.run_speed, CAMPAIGN_SPEED) and not run.world.player.god_mode,
		"the campaign plays the real fight at the Golden Zone's %.0f m/s, no god mode" % CAMPAIGN_SPEED)
	if run == null or not run.encounter is GoldenConvergence:
		return
	var boss := run.encounter as GoldenConvergence
	var bot := _bot(boss)
	# Stage 1, won; then into stage 2 until The Magnate hunts the runner.
	for i: int in int(MAX_SECONDS * 60.0):
		if (boss.phase_index >= STAGE_2 and boss.is_vulnerable() and boss.chase.home()) or not run.world.player.alive:
			break
		bot.step()
		await tree.physics_frame
	check(run.world.player.alive and boss.phase_index == STAGE_2 and int(run.context.boss_resume.get("phase", -1)) == STAGE_2,
		"stage 1 falls to its three ships, and the fight reaches its checkpoint (phase %d)" % (boss.phase_index + 1))
	var at_checkpoint: float = float(run.context.boss_resume.get("time", 0.0))
	run.world.player._die("test hazard")
	await physics_frames(int((App.rules.death_screen_delay + 0.3) * 60.0))
	await tree.process_frame
	var died: RunResult = (App.screen as ResultsScreen).result if App.screen is ResultsScreen else null
	check(died != null and not died.completed and died.stats.get("phase", 0) == STAGE_2 + 1,
		"a death in stage 2 shows the run summary, with the phase reached")
	if died == null:
		return
	App.continue_after_result(died)
	var shop := App.screen as ShopScreen
	check(shop != null and shop.play_label == "Retry", "with a retry")
	if shop == null:
		return
	shop.on_close.call()
	App.begin_run()
	await physics_frames(3)
	run = App.run
	boss = run.encounter as GoldenConvergence if run != null else null
	check(boss != null and run.context.attempt == 2 and boss.phase_index == STAGE_2
		and is_equal_approx(boss.health, boss.phase_start_health(STAGE_2)) and is_equal_approx(boss.carried_time, at_checkpoint),
		"the retry resumes at the checkpoint: stage 2's first phase, its health, the time so far (%.1f s)" % at_checkpoint)
	if boss == null:
		return
	bot = _bot(boss)
	var retry := {"transitions": 0, "defeated": false}
	for i: int in int(MAX_SECONDS * 60.0):
		if App.screen is ResultsScreen or App.run != run or not is_instance_valid(boss) or not run.world.player.alive:
			break
		retry["transitions"] = boss.transition.played
		retry["defeated"] = boss.is_defeated()
		bot.step()
		await tree.physics_frame
	check(int(retry["transitions"]) == 1 and bool(retry["defeated"]), "the transition plays again, and the retry is won")
	await physics_frames(int((LevelRun.COMPLETE_PAUSE + 0.5) * 60.0))
	await tree.process_frame
	var won: RunResult = (App.screen as ResultsScreen).result if App.screen is ResultsScreen else null
	check(won != null and won.completed and won.stars == def.stars_for(true, won.time),
		"the results: beaten, its stars from the par times (%s)" % [str([won.stars, snappedf(won.time, 0.1)]) if won != null else "none"])

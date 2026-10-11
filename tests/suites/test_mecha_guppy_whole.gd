extends TestSuite
## Mecha Guppy and Captain Cogs played whole (GDD §10; task E5e-c), with a runner who plays it by what it shows
## (MechaGuppyBot: it reads the lanes that lead up `REACTION` late and dodges Captain Cogs' bombs, rounds and waves the
## planner's dodge_reaction late; no god mode, no loadout), at 3, 5 and 6 lanes and at quick play's 18 m/s and the
## Beach's 23.8 m/s, baiting and not:
## - from its start: phase 1 won by 4 hits, phase 2 by 6 (a baiting runner's every hit a bait into the notch's jaws, a
##   runner who never baits every hit Captain Cogs' miss into the chasm, more slowly), then the climb's last steps to the
##   top, phase 3's minute dodged, the leap and the swim away, and victory_over; the runner never touched;
## - the par times (BossDef: two_star_seconds, three_star_seconds, time_bonus_seconds) set from the baiting runner's clean
##   fights at the campaign's 23.8 m/s the way Hostile Takeover's are (three stars a little over the slowest, two about
##   40 % over it), and a clean fight at 18 m/s earns three stars too; a runner who never baits wins too, with fewer;
## - the campaign (App): the Beach's boss step follows its last level, the real fight at the Beach's 23.8 m/s under Sunset
##   Strip's sky, no god mode; a death in phase 2 shows the run summary, and the retry starts the fight over and plays
##   the same; it's won: the results wait for Mecha Guppy to swim away (victory_over) and LevelRun.COMPLETE_PAUSE, then
##   show its stars from the par times, recorded for the level select's boss tile (stars, best score and time).
## Each part alone: test_mecha_guppy_climb (the climb), test_mecha_guppy_bombs and test_mecha_guppy_bait (phases 1
## and 2), test_mecha_guppy_top (phase 3 and the defeat).

const BOSS_PATH: String = "res://data/bosses/beach_boss.tres"
const SKY_PATH: String = "res://data/skies/beach_sunset.tres"
const LANES: Array[int] = [3, 5, 6]
## Quick play's speed and the Beach's (GDD §3).
const SPEEDS: Array[float] = [18.0, 23.8]
const CAMPAIGN_SPEED: float = 23.8
## The bot's reaction reading a hut's lanes (the suites' usual 0.35 s; it dodges the planner's dodge_reaction late).
const REACTION: float = 0.35
## The whole fight is over well within this (measured 157-170 s baiting and 223-244 s not, with the leap's 7 s after).
const MAX_SECONDS: float = 480.0
## Hostile Takeover's par times over its clean fight (corporate_boss.tres: 74 s and 96 s over 68.6 s).
const THREE_STAR_OVER: float = 74.0 / 68.6
const TWO_STAR_OVER: float = 96.0 / 68.6
## A frame's slack (seconds).
const FRAME: float = 1.0 / 60.0 + 0.001
## The events compared between a first attempt and its retry.
const LOGGED: Array[StringName] = [&"phase", &"phase_end", &"climb_phase", &"volley", &"bait_seek", &"bait_lock",
	&"throw", &"hit", &"shark_hit", &"fallback", &"top_reached"]

var sim: RunSim
var def: BossDef
## The fights' moments: "<lanes>/<speed>/<bait|miss>" → {phase_1, phase_2, top, won, over} (seconds of fight; over:
## seconds after the win).
var times: Dictionary = {}


func run() -> void:
	sim = RunSim.new(tree, tuning)
	var slot := load(BOSS_PATH) as BossDef
	def = slot if slot != null and slot.is_built() else null
	if def == null:
		check(false, "Mecha Guppy and Captain Cogs' fight is built")
		return
	for baits: bool in [true, false]:
		for speed: float in SPEEDS:
			for lanes: int in LANES:
				await _test_whole(lanes, speed, baits)
	_test_par_times()
	await _test_campaign()


# --- Helpers -------------------------------------------------------------------------------

func _movement(speed: float) -> MovementTuning:
	if is_equal_approx(speed, tuning.run_speed):
		return tuning
	var t: MovementTuning = tuning.duplicate() as MovementTuning
	t.run_speed = speed
	return t


func _fight(lanes: int, speed: float) -> Array:
	var t: MovementTuning = _movement(speed)
	var boss := BossEncounter.create(def) as MechaGuppy
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = def
	ctx.config = BossArena.base_config(def)
	ctx.config.lane_count = lanes
	ctx.tuning = t
	var arena: BossArena = boss.plan_arena(ctx)
	var world: RunWorld = sim.build_world(arena.layout, null, t, ctx.config)
	boss.setup(world, ctx, arena)
	return [world, boss]


func _events(boss: BossEncounter, event: StringName) -> Array[Dictionary]:
	return _of(boss.events, event)


func _of(events: Array[Dictionary], event: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in events:
		if e["event"] == event:
			out.append(e)
	return out


func _sounds(events: Array[Dictionary], sound: StringName) -> int:
	var n: int = 0
	for e: Dictionary in events:
		if e["event"] == &"sound" and e["name"] == sound:
			n += 1
	return n


## The fight's log up to fight time `before`: its LOGGED events, their moments and where they were.
func _fight_log(events: Array[Dictionary], before: float = INF) -> String:
	var lines: PackedStringArray = []
	for e: Dictionary in events:
		if float(e["t"]) >= before or not LOGGED.has(e["event"]):
			continue
		lines.append("%s %.2f %d %s %s" % [e["event"], float(e["t"]), int(e["phase"]), e.get("step", ""), e.get("lane", "")])
	return ";".join(lines)


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


# --- The whole fight ---------------------------------------------------------------------------------------

func _test_whole(lanes: int, speed: float, baits: bool) -> void:
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
	var used: Array[StringName] = []
	p.item_used.connect(func(item: StringName) -> void: used.append(item))
	var won := {"t": -1.0, "frames": 0}
	await _run(world, MAX_SECONDS, func() -> bool: return boss.is_defeated() and boss.victory_over(), func() -> void:
		bot.step()
		if boss.is_defeated():
			won["frames"] = int(won["frames"]) + 1)
	var ends: Array[Dictionary] = _events(boss, &"phase_end")
	var hits: Array[Dictionary] = _events(boss, &"hit")
	var per_phase: Array[int] = [0, 0, 0]
	for e: Dictionary in hits:
		per_phase[clampi(int(e["phase"]), 0, 2)] += 1
	var defeated: Array[Dictionary] = _events(boss, &"defeated")
	var t_won: float = float(defeated[0]["t"]) if defeated.size() == 1 else -1.0
	var over_after: float = float(won["frames"]) / Engine.physics_ticks_per_second
	print("  whole fight %s: phase 1 ends at %s s, phase 2 at %s s, the top reached at %.1f s, the fight won at %.1f s, Mecha Guppy swum away %.1f s later"
		% [tag, "%.1f" % float(ends[0]["t"]) if ends.size() > 0 else "-", "%.1f" % float(ends[1]["t"]) if ends.size() > 1 else "-",
			boss.top_reached_at, t_won, over_after])
	check(p.alive and boss.is_defeated() and boss.victory_over() and used.is_empty() and not p.god_mode,
		"the bot wins the whole fight untouched, without god mode %s%s" % [tag,
			"" if p.alive and used.is_empty() else ": %s %s at %.1f s" % [cause[0], used, boss.fight_time()]])
	check(ends.size() >= 2 and per_phase[0] == 4 and per_phase[1] == 6 and per_phase[2] == 0,
		"4 hits end phase 1, 6 phase 2, none counts in phase 3 (%s) %s" % [per_phase, tag])
	var into: Array[Dictionary] = _events(boss, &"shark_hit")
	var kinds_ok: bool = into.size() == 10
	for e: Dictionary in into:
		kinds_ok = kinds_ok and bool(e["counted"]) \
			and int(e["kind"]) == (MechaGuppyBombs.Kind.BAIT if baits else MechaGuppyBombs.Kind.HIT)
	check(kinds_ok and (_events(boss, &"fallback").is_empty() if baits else _events(boss, &"fallback").size() == 10),
		"every hit %s %s" % ["a bait into the notch's jaws" if baits else "Captain Cogs' miss into the chasm (the fallback)", tag])
	var over: Array[Dictionary] = _events(boss, &"top_over")
	check(boss.top_reached_at > float(ends[1]["t"]) if ends.size() > 1 else false,
		"then the climb's last steps to the top, after phase 2 (%.1f s) %s" % [boss.top_reached_at, tag])
	check(over.size() == 1 and absf(t_won - boss.top_reached_at - mt.top_seconds) < FRAME * 2.0,
		"phase 3 is won as its minute ends, %.0f s after the top is reached %s" % [mt.top_seconds, tag])
	var plan: Array[Dictionary] = MechaGuppyTop.plan(mt)
	var beats: int = _events(boss, &"round").size() + _events(boss, &"round_skipped").size() + _events(boss, &"wave").size()
	check(beats == plan.size() and bot.top_jumps == _events(boss, &"wave").size(),
		"the minute's beats all came (%d of %d), every wave jumped %s" % [beats, plan.size(), tag])
	var leap: MechaGuppyLeap = boss.leap
	check(leap != null and leap.over() and over_after <= mt.leap_rise + mt.leap_hang + mt.leap_fall + mt.swim_seconds + 0.1
		and over_after < LevelRun.BOSS_VICTORY_MAX and boss.ship.swallowed,
		"the defeat: Mecha Guppy leaps, gulps Captain Cogs and swims away in %.1f s (at most %.0f s) %s"
		% [over_after, LevelRun.BOSS_VICTORY_MAX, tag])
	if p.alive and boss.is_defeated():
		times["%d/%.1f/%s" % [lanes, speed, "bait" if baits else "miss"]] = {
			"phase_1": float(ends[0]["t"]) if ends.size() > 0 else -1.0,
			"phase_2": float(ends[1]["t"]) if ends.size() > 1 else -1.0,
			"top": boss.top_reached_at, "won": t_won, "over": over_after}
	await sim.free_world(world)


# --- The par times -----------------------------------------------------------------------------------------

## Set from the baiting runner's clean fights the way Hostile Takeover's are: three stars a little over the slowest
## clean fight at the campaign's speed, two about 40 % over it; a clean fight at quick play's 18 m/s earns three stars
## too; the time bonus runs out a little past two stars. A runner who never baits still wins, with fewer stars.
func _test_par_times() -> void:
	var at_campaign: Array[float] = []
	var at_quick: Array[float] = []
	var missing: Array[float] = []
	for lanes: int in LANES:
		var key: String = "%d/%.1f/bait" % [lanes, CAMPAIGN_SPEED]
		if times.has(key):
			at_campaign.append(float(times[key]["won"]))
		var quick: String = "%d/%.1f/bait" % [lanes, SPEEDS[0]]
		if times.has(quick):
			at_quick.append(float(times[quick]["won"]))
		for speed: float in SPEEDS:
			var miss: String = "%d/%.1f/miss" % [lanes, speed]
			if times.has(miss):
				missing.append(float(times[miss]["won"]))
	if at_campaign.size() != LANES.size() or at_quick.size() != LANES.size() or missing.size() != LANES.size() * 2:
		check(false, "the par times need every clean fight (%s)" % [times])
		return
	var slowest: float = at_campaign.max()
	print("  clean fights baiting at %.1f m/s: %s; at %.1f m/s: %s; not baiting: %s; par %.0f / %.0f s, time bonus to %.0f s"
		% [CAMPAIGN_SPEED, at_campaign, SPEEDS[0], at_quick, missing, def.three_star_seconds, def.two_star_seconds,
			def.time_bonus_seconds])
	check(at_campaign.max() - at_campaign.min() < 8.0, "a clean fight takes about as long at 3, 5 and 6 lanes (%s)" % [at_campaign])
	check(absf(def.three_star_seconds - slowest * THREE_STAR_OVER) <= 3.0 and absf(def.two_star_seconds - slowest * TWO_STAR_OVER) <= 5.0,
		"three stars at %.0f s and two at %.0f s: Hostile Takeover's margins over the slowest clean fight (%.1f s)"
		% [def.three_star_seconds, def.two_star_seconds, slowest])
	check(at_quick.max() <= def.three_star_seconds, "a clean fight at %.0f m/s earns three stars too (%s)" % [SPEEDS[0], at_quick])
	var miss_stars: Array[int] = []
	for t: float in missing:
		miss_stars.append(def.stars_for(true, t))
	check(missing.min() > def.three_star_seconds and not miss_stars.has(0),
		"a runner who never baits wins too, more slowly, with fewer stars (%s)" % [miss_stars])
	check(def.time_bonus_seconds > def.two_star_seconds and def.time_bonus_seconds <= def.two_star_seconds * 1.3,
		"the time bonus runs out a little past two stars (%.0f s)" % def.time_bonus_seconds)


# --- The campaign ------------------------------------------------------------------------------------------

## The Beach's boss step through the game itself (see the header).
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
	var step: CampaignStep = App.campaign.step("beach/boss")
	var last: CampaignStep = App.campaign.step("beach/3")
	check(step != null and step.boss != null and step.boss.id == def.id and step.boss.is_built() and step.boss.preview_scene == ""
		and last != null and App.campaign.next_step(last) == step,
		"the Beach's boss step is the built fight, not a preview, after the Beach's last level")
	if step == null or last == null:
		return
	# The Beach's last level, run to its end; its results, the shop, and on.
	App.play_step(last)
	App.begin_run()
	await physics_frames(10)
	if App.run == null:
		check(false, "the Beach's last level starts")
		return
	App.run.world.player.distance = App.run.world.layout.length - 3.0
	await physics_frames(int((LevelRun.COMPLETE_PAUSE + 0.5) * 60.0))
	await tree.process_frame
	var level_result: RunResult = (App.screen as ResultsScreen).result if App.screen is ResultsScreen else null
	check(level_result != null and level_result.completed, "the Beach's last level is finished")
	if level_result == null:
		return
	App.continue_after_result(level_result)
	var level_shop := App.screen as ShopScreen
	if level_shop == null:
		check(false, "the shop follows the level")
		return
	level_shop.on_close.call()
	await tree.process_frame
	App.begin_run()
	await physics_frames(3)
	var run: LevelRun = App.run
	check(run != null and run.encounter is MechaGuppy and run.context.step.id == "beach/boss"
		and is_equal_approx(run.world.tuning.run_speed, CAMPAIGN_SPEED) and run.context.config.sky == load(SKY_PATH)
		and not run.world.player.god_mode,
		"then the real fight at the Beach's %.1f m/s, under Sunset Strip's sky, no god mode" % CAMPAIGN_SPEED)
	if run == null or not run.encounter is MechaGuppy:
		return
	# The first attempt: phase 1 won, then a death in phase 2.
	var boss := run.encounter as MechaGuppy
	var bot := MechaGuppyBot.new(boss)
	bot.reaction = REACTION
	for i: int in int(MAX_SECONDS * 60.0):
		if (boss.phase_index >= 1 and boss.is_vulnerable()) or not run.world.player.alive:
			break
		bot.step()
		await tree.physics_frame
	check(run.world.player.alive and boss.phase_index == 1, "phase 1 falls to four hits, and phase 2 begins")
	var died_at: float = boss.fight_time()
	var first: String = _fight_log(boss.events, died_at)
	run.world.player._die("test hazard")
	await physics_frames(int((App.rules.death_screen_delay + 0.3) * 60.0))
	await tree.process_frame
	var died: RunResult = (App.screen as ResultsScreen).result if App.screen is ResultsScreen else null
	check(died != null and not died.completed and died.stars == 0, "a death shows the run summary, no stars")
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
	boss = run.encounter as MechaGuppy if run != null else null
	check(boss != null and run.context.attempt == 2 and run.context.boss_resume.is_empty() and boss.phase_index == 0
		and is_equal_approx(boss.health, boss.max_health) and is_equal_approx(boss.carried_time, 0.0),
		"the retry starts the fight over, whole (GDD §10: no checkpoint)")
	if boss == null:
		return
	# The retry, won: the results only once Mecha Guppy has swum away, and COMPLETE_PAUSE after.
	bot = MechaGuppyBot.new(boss)
	bot.reaction = REACTION
	var events: Array[Dictionary] = boss.events
	var at := {"defeat": -1, "over": -1, "results": -1, "god": false}
	for i: int in int(MAX_SECONDS * 60.0):
		if App.screen is ResultsScreen:
			at["results"] = i
			break
		if App.run != run or not run.world.player.alive:
			break
		if is_instance_valid(boss):
			if boss.is_defeated() and int(at["defeat"]) < 0:
				at["defeat"] = i
				at["god"] = run.world.player.god_mode
			if boss.is_defeated() and boss.victory_over() and int(at["over"]) < 0:
				at["over"] = i
			bot.step()
		await tree.physics_frame
	check(_fight_log(events, died_at) == first and first != "", "the retry plays the same fight as the first attempt, up to its death")
	var mt := def.tuning as MechaGuppyTuning
	var leap_s: float = float(int(at["over"]) - int(at["defeat"])) / 60.0
	var pause_s: float = float(int(at["results"]) - int(at["over"])) / 60.0
	check(int(at["defeat"]) > 0 and bool(at["god"]) and leap_s >= mt.leap_rise + mt.leap_hang + mt.leap_fall + mt.swim_seconds - 0.1
		and leap_s < LevelRun.BOSS_VICTORY_MAX,
		"the retry is won; the runner safe (god mode) while Mecha Guppy leaps, eats Captain Cogs and swims away (%.1f s)" % leap_s)
	check(int(at["results"]) > 0 and absf(pause_s - LevelRun.COMPLETE_PAUSE) < 0.1,
		"the results only once it has swum away, %.1f s later (%.1f s)" % [LevelRun.COMPLETE_PAUSE, pause_s])
	check(_of(events, &"riff").size() == (1 if mt.victory_riff_on else 0) and _sounds(events, &"guppy_gulp") == 1,
		"the victory riff after the gulp, once")
	var won: RunResult = (App.screen as ResultsScreen).result if App.screen is ResultsScreen else null
	check(won != null and won.completed and won.context.step.id == "beach/boss" and won.stars == def.stars_for(true, won.time)
		and won.stars == 3, "the results: beaten, three stars for a clean fight from the par times (%s)"
		% [str([won.stars, snappedf(won.time, 0.1)]) if won != null else "none"])
	if won == null:
		return
	var record: Dictionary = App.profile.record("beach/boss")
	check(App.profile.is_completed("beach/boss") and App.profile.stars("beach/boss") == won.stars
		and is_equal_approx(float(record.get("best_time", 0.0)), won.time) and int(record.get("best_score", 0)) == won.score
		and won.score >= def.defeat_score, "the profile records it: done, its stars, its best score (%d) and time (%.1f s)"
		% [int(record.get("best_score", 0)), float(record.get("best_time", 0.0))])
	# The level select's boss tile shows them.
	App.show_level_select()
	await tree.process_frame
	await tree.process_frame
	var want: String = "BEST %s · %s" % [UiTheme.format_int(won.score), ResultsScreen.format_time(won.time)]
	var found: Array[bool] = [false, false]
	var stack: Array[Node] = [App.screen]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n == null:
			continue
		if n is Label and (n as Label).text == want:
			found[0] = true
			# Its tile's stars.
			var tile: Node = n.get_parent()
			while tile != null and not tile is TileButton:
				tile = tile.get_parent()
			if tile != null:
				var inner: Array[Node] = [tile]
				while not inner.is_empty():
					var m: Node = inner.pop_back()
					if m is StarRow and (m as StarRow).stars == won.stars:
						found[1] = true
					inner.append_array(m.get_children())
		stack.append_array(n.get_children())
	check(App.screen is LevelSelectScreen and found[0] and found[1],
		"the level select's boss tile shows its stars and its best (%s)" % want)

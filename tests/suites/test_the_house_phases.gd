extends TestSuite
## The House's phases 2 and 3, its defeat and its slot in the campaign (GDD §10; task E5a-b), at 3, 5 and 6
## lanes, at the reference 18 m/s and the Casino's 23 m/s (its zone's since task K2), with a runner who
## plays it by what it shows (TheHouseBot, reacting REACTION late; no god mode, no armor):
## - phase 2: wall fences stand along both walls, pulsing; the special reel's 7 button stands on a wall,
##   lit in plain view before the runner gets there, and a runner who reads it runs along the wall over it
##   and back to the street (every wall fence it passes off as it goes by: it lives); the machine's
##   attacks wait while they go for it, and its strikes keep off the wall fences' drop windows;
## - phase 3: a floating billboard comes down over every lane with its pad; the machine squats under it
##   (it's taller than a ceiling); Barnacle Turrets hang past the button (one or two, never over the pad's
##   lane) and fire at the rider; the 7 button on its underside is lit in plain view before the runner gets
##   there and the rider runs over it on the ceiling, dodges the bolts and drops back onto clear floor; the
##   attacks wait while they're up there;
## - the defeat: the last stomp, then it lurches out and rises, its reels spin wildly and jam, TILT shows,
##   it collapses into the street in an explosion of coins, ahead of the runner, the citizens cheering;
##   then it's over;
## - the campaign at 23 m/s and every lane count: Casino 2, then the fight (a death in its second
##   phase, the retry from the start, all three phases won), its results and stars, the shop and the
##   Casino's outro.

const BOSS_PATH: String = "res://data/bosses/casino_boss.tres"
const LANES: Array[int] = [3, 5, 6]
const SPEEDS: Array[float] = [18.0, 23.0]
const REACTION: float = 0.35
## A button shows at least this long before the runner reaches it.
const BUTTON_SIGHT: float = 1.0

var sim: RunSim
var def: BossDef


func run() -> void:
	sim = RunSim.new(tree, tuning)
	var slot := load(BOSS_PATH) as BossDef
	def = slot if slot != null and slot.is_built() else null
	if def == null:
		check(false, "The House's fight loads")
		return
	for lanes: int in LANES:
		for speed: float in SPEEDS:
			await _test_wall(lanes, speed)
	for lanes: int in LANES:
		for speed: float in SPEEDS:
			await _test_ceiling_and_defeat(lanes, speed)
	await _test_campaign()


## A copy of the slot whose spins offer buttons from the start.
func _rigged() -> BossDef:
	var out: BossDef = def.duplicate() as BossDef
	var t: TheHouseTuning = (def.tuning as TheHouseTuning).duplicate() as TheHouseTuning
	t.opening_spins = PackedInt32Array([0, 0, 0])
	out.tuning = t
	return out


## The fight at `lanes` and `speed`, from phase `phase` (0-based, as a checkpoint would): [world, boss].
func _fight(p_def: BossDef, lanes: int, speed: float, phase: int) -> Array:
	var boss := BossEncounter.create(p_def) as TheHouse
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
	if phase > 0:
		ctx.boss_resume = {"phase": phase}
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


## Steps the fight until `done` holds, the runner dies or `seconds` pass, the bot playing; `each` every frame.
func _run(world: RunWorld, bot: TheHouseBot, seconds: float, done: Callable, each: Callable = Callable()) -> void:
	if not world.player.running:
		await tree.physics_frame
		world.player.running = true
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		if bot != null:
			bot.step()
		if each.is_valid():
			each.call()
		if done.call() or not world.player.alive:
			return
		await tree.physics_frame


# --- Phase 2: the wall button ---------------------------------------------------------------------

func _test_wall(lanes: int, speed: float) -> void:
	var tag: String = "(%d lanes, %.1f m/s)" % [lanes, speed]
	var pair: Array = _fight(_rigged(), lanes, speed, 1)
	var world: RunWorld = pair[0]
	var boss: TheHouse = pair[1]
	var bot := TheHouseBot.new(boss)
	bot.reaction = REACTION
	var cause: Array[String] = [""]
	world.player.died.connect(func(c: String) -> void: cause[0] = c)
	var w := {"on": false, "off": false, "on_wall": false, "held_strikes": 0, "drop_strikes": 0, "seen": {}, "sides": {}}
	var watch := func() -> void:
		for h: Hazard in world.track.wall_fence_hazards():
			if not is_instance_valid(h):
				continue
			w["on"] = bool(w["on"]) or h.state == Hazard.State.ON
			w["off"] = bool(w["off"]) or h.state != Hazard.State.ON
		w["on_wall"] = bool(w["on_wall"]) or world.player.surface == Player.Surface.WALL
		for s: Dictionary in boss.attacks.strikes:
			if (w["seen"] as Dictionary).has(int(s["n"])):
				continue
			(w["seen"] as Dictionary)[int(s["n"])] = true
			if boss.walls.in_drop_window(boss.attacks.strike_obstacles(s)):
				w["drop_strikes"] = int(w["drop_strikes"]) + 1
			if boss.attacks_held():
				w["held_strikes"] = int(w["held_strikes"]) + 1
		for e: Dictionary in boss.walls.entries:
			(w["sides"] as Dictionary)[int(e["side"])] = true
	await _run(world, bot, 45.0, func() -> bool: return boss.phase_index >= 2, watch)
	check(world.player.alive and boss.phase_index == 2,
		"a runner who reads it wins phase 2 %s%s" % [tag, "" if world.player.alive else ": " + cause[0]])
	check(boss.walls.entries.size() >= 3 and (w["sides"] as Dictionary).size() == 2 and boss.walls.refused == 0,
		"wall fences stand along both walls (%d) %s" % [boss.walls.entries.size(), tag])
	check(bool(w["on"]) and bool(w["off"]), "they pulse on and off %s" % tag)
	var planned: Array = _events(boss, &"button_planned").filter(func(e: Dictionary) -> bool: return e["kind"] == "wall")
	var lit: Array = _events(boss, &"button_lit").filter(func(e: Dictionary) -> bool: return e["kind"] == "wall")
	var pressed: Array = _events(boss, &"button_pressed").filter(func(e: Dictionary) -> bool: return e["kind"] == "wall")
	check(not planned.is_empty() and int(planned[0]["lane"]) == (0 if int(planned[0]["side"]) < 0 else lanes - 1),
		"its special button stands on a wall, by the outer lane %s" % tag)
	check(not lit.is_empty() and not pressed.is_empty() and float(pressed[0]["t"]) - float(lit[0]["t"]) >= BUTTON_SIGHT,
		"lit at least %.1f s before the runner gets there %s" % [BUTTON_SIGHT, tag])
	check(bool(w["on_wall"]) and pressed.size() == planned.size(), "the runner runs along the wall over it %s" % tag)
	check(int(w["held_strikes"]) == 0, "no attack comes while they go for it %s" % tag)
	check(int(w["drop_strikes"]) == 0, "its strikes keep off the wall fences' drop windows %s" % tag)
	check(bot.stuck == 0, "the runner always finds a way %s" % tag)
	await sim.free_world(world)


# --- Phase 3: the ceiling button, and the defeat --------------------------------------------------

func _test_ceiling_and_defeat(lanes: int, speed: float) -> void:
	var tag: String = "(%d lanes, %.1f m/s)" % [lanes, speed]
	var pair: Array = _fight(_rigged(), lanes, speed, 2)
	var world: RunWorld = pair[0]
	var boss: TheHouse = pair[1]
	var bot := TheHouseBot.new(boss)
	bot.reaction = REACTION
	var cause: Array[String] = [""]
	world.player.died.connect(func(c: String) -> void: cause[0] = c)
	var c := {"ceiling": false, "taller": 0, "held_strikes": 0, "seen": {}, "shots": {}, "turret_lanes": [], "pad_lane": -1,
		"defeat": [], "front_ok": true, "cheers": 0, "coins": 0, "tilt": false, "jammed": false, "wild": 0.0}
	var watch := func() -> void:
		var p: Player = world.player
		var seg: Dictionary = boss.ceiling.segment
		if not seg.is_empty() and bool(seg.get("shown", false)):
			c["pad_lane"] = int(seg["pad_lane"])
			if boss.ceiling.turrets.size() > (c["turret_lanes"] as Array).size():
				var lanes_now: Array = []
				for e: Variant in boss.ceiling.turrets:
					if is_instance_valid(e):
						lanes_now.append((e as BarnacleTurret).lane)
				c["turret_lanes"] = lanes_now
			# Squatting while the billboard is over it.
			if float(seg["start"]) <= boss.body.back_at(boss.front_at) and float(seg["end"]) >= boss.front_at \
					and boss.body.top_height() > world.tuning.ceiling_height - 0.3:
				c["taller"] = int(c["taller"]) + 1
		if p.surface == Player.Surface.CEILING:
			c["ceiling"] = true
			for shot: Projectile in world.projectiles.live_shots():
				if not shot.friendly:
					(c["shots"] as Dictionary)[shot.get_instance_id()] = true
		for s: Dictionary in boss.attacks.strikes:
			if (c["seen"] as Dictionary).has(int(s["n"])):
				continue
			(c["seen"] as Dictionary)[int(s["n"])] = true
			if boss.attacks_held():
				c["held_strikes"] = int(c["held_strikes"]) + 1
		if boss.step == TheHouse.Step.DEFEAT:
			var steps: Array = c["defeat"]
			if steps.is_empty() or steps[-1][0] != boss.defeat_step:
				steps.append([boss.defeat_step, world.level_time()])
			if boss.defeat_step != TheHouse.Defeat.RECOVER and boss.front_at <= p.distance + 5.0:
				c["front_ok"] = false
			c["coins"] = maxi(int(c["coins"]), boss.jackpot.debris.size())
			c["tilt"] = bool(c["tilt"]) or boss.body.model.tilt > 0.9
			c["wild"] = maxf(float(c["wild"]), boss.body.reels.blur().x)
			c["jammed"] = boss.body.reels.jammed.count(1) == 3
	await _run(world, bot, 60.0, func() -> bool: return boss.victory_over(), watch)
	check(world.player.alive and boss.is_defeated(),
		"a runner who reads it wins phase 3, and the fight %s%s" % [tag, "" if world.player.alive else ": " + cause[0]])
	var planned: Array = _events(boss, &"ceiling_planned")
	check(not planned.is_empty() and int(planned[0]["button_lane"]) == int(planned[0]["pad_lane"]),
		"its special button is on a ceiling, in its pad's lane %s" % tag)
	var turret_lanes: Array = c["turret_lanes"]
	check(turret_lanes.size() >= 1 and turret_lanes.size() <= 2 and not turret_lanes.has(int(c["pad_lane"])),
		"one or two Barnacle Turrets guard it, never over the pad's lane (%s) %s" % [turret_lanes, tag])
	check(int(c["taller"]) == 0, "the machine squats under the billboard while it's over it %s" % tag)
	check(bool(c["ceiling"]) and (c["shots"] as Dictionary).size() >= 1,
		"the runner rides the ceiling, and the turrets fire at them (%d bolts) %s" % [(c["shots"] as Dictionary).size(), tag])
	var lit: Array = _events(boss, &"button_lit").filter(func(e: Dictionary) -> bool: return e["kind"] == "ceiling")
	var pressed: Array = _events(boss, &"button_pressed").filter(func(e: Dictionary) -> bool: return e["kind"] == "ceiling")
	check(not lit.is_empty() and not pressed.is_empty() and float(pressed[0]["t"]) - float(lit[0]["t"]) >= BUTTON_SIGHT,
		"lit at least %.1f s before the runner gets there, and run over on the ceiling %s" % [BUTTON_SIGHT, tag])
	check(int(c["held_strikes"]) == 0, "no attack comes while they go for it %s" % tag)
	# The defeat.
	var steps: Array = c["defeat"]
	var order: Array = []
	for st: Array in steps:
		order.append(st[0])
	check(order == [TheHouse.Defeat.RECOVER, TheHouse.Defeat.WILD, TheHouse.Defeat.JAM, TheHouse.Defeat.COLLAPSE,
		TheHouse.Defeat.DONE], "the defeat: it rises, spins wildly, jams, collapses %s" % tag)
	if order.size() == 5:
		var t: TheHouseTuning = boss.tuning
		var wild: float = float(steps[2][1]) - float(steps[1][1])
		var jam: float = float(steps[3][1]) - float(steps[2][1])
		check(absf(wild - t.tilt_spin_seconds) < 0.1 and absf(jam - t.tilt_seconds) < 0.1,
			"the wild spin and TILT last their seconds (%.1f, %.1f) %s" % [wild, jam, tag])
	check(float(c["wild"]) > 1.5 and bool(c["jammed"]) and bool(c["tilt"]),
		"its reels spin wildly and jam, and TILT shows %s" % tag)
	check(int(c["coins"]) >= 30, "it collapses in an explosion of coins (%d) %s" % [int(c["coins"]), tag])
	check(boss.body.top_height() < 0.0 and bool(c["front_ok"]), "into the street, ahead of the runner %s" % tag)
	check(int(boss.reactions.get(&"cheer", 0)) >= 4 and boss.victory_over(), "the citizens cheer, and it's over %s" % tag)
	check(bot.stuck == 0, "the runner always finds a way %s" % tag)
	await sim.free_world(world)


# --- The campaign ---------------------------------------------------------------------------------

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
	App.play_step(App.campaign.step("casino/2"))
	App.begin_run()
	await physics_frames(10)
	check(App.run != null and App.run.world.geo.lane_count == lanes, "Casino 2 starts %s" % tag)
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
	App.begin_run()
	await physics_frames(3)
	var run: LevelRun = App.run
	check(run != null and run.encounter is TheHouse and run.context.step.id == "casino/boss"
		and run.world.geo.lane_count == lanes and is_equal_approx(run.world.tuning.run_speed, SPEEDS[1])
		and not run.world.player.god_mode, "then The House's fight, at the Casino's 23 m/s, no god mode %s" % tag)
	if run == null or not run.encounter is TheHouse:
		return
	# The first attempt: the first phase won, then a death in the second.
	var boss := run.encounter as TheHouse
	var bot := TheHouseBot.new(boss)
	bot.reaction = REACTION
	for i: int in 90 * 60:
		if boss.phase_index >= 1 and boss.state == BossEncounter.State.FIGHT or not run.world.player.alive:
			break
		bot.step()
		await tree.physics_frame
	check(boss.phase_index == 1 and run.world.player.alive, "the first phase falls to its first stomp %s" % tag)
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
	boss = run.encounter as TheHouse if run != null else null
	check(boss != null and run.context.attempt == 2 and run.context.boss_resume.is_empty() and boss.phase_index == 0
		and boss.step == TheHouse.Step.ENTER and is_equal_approx(boss.health, boss.max_health),
		"the retry starts the fight over: its entrance, at full health %s" % tag)
	if boss == null:
		return
	# The retry, won.
	bot = TheHouseBot.new(boss)
	bot.reaction = REACTION
	var phases: Dictionary = {}
	var stomps: int = 0
	for i: int in 200 * 60:
		if App.screen is ResultsScreen or App.run != run or not run.world.player.alive:
			break
		if is_instance_valid(boss):
			phases[boss.phase_index] = true
			stomps = _events(boss, &"weak_point").size()
			bot.step()
		await tree.physics_frame
	await tree.process_frame
	check(phases.size() == 3 and stomps == 3, "the retry plays all three phases to the win %s" % tag)
	var result: RunResult = (App.screen as ResultsScreen).result if App.screen is ResultsScreen else null
	check(result != null and result.completed and result.context.is_boss(), "a win's results follow the collapse %s" % tag)
	if result == null:
		return
	check(result.stars == def.stars_for(true, result.time) and result.stars == 3,
		"three stars for a fight without a miss (%.1f s) %s" % [result.time, tag])
	check(App.profile.is_completed("casino/boss"), "the boss step counts as done %s" % tag)
	App.continue_after_result(result)
	shop = App.screen as ShopScreen
	check(shop != null and shop.play_label == "Next", "then the shop %s" % tag)
	if shop == null:
		return
	shop.on_close.call()
	await tree.process_frame
	var outro := App.screen as SlotScreen
	var cine: Cinematic = App.playing_cinematic()
	check((outro != null and outro.step.id == "casino/outro") or (cine != null and cine.step.id == "casino/outro"),
		"then the Casino's outro %s" % tag)
	await tree.process_frame

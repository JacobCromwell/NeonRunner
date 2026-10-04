extends TestSuite
## The House's fight (GDD §10; tasks E5a-a and E5a-b), its 7 buttons, its jackpot and its phases, at 3, 5 and 6
## lanes, at the reference 18 m/s and the Marketplace's 22.6 m/s, with a runner who plays it by what it
## shows (TheHouseBot, reacting REACTION late; no god mode, no armor):
## - the buttons: each lights up in plain view before the runner reaches it, in its own lane (never the
##   last one's, at most button_max_shift away), safe to run over; running over one stops its reel on 7,
##   locked; three locked is the JACKPOT;
## - a missed button: its reel stops on its symbol and its attack follows; the locks stay, so the next spin
##   offers only the buttons still needed (a missed set just spins again, nothing escalates);
## - the jackpot: the sirens, the citizens cheer, the fountain's credits land as real credits on the street
##   ahead (some are grabbed), the machine stalls and sinks with its hopper open as its red weak point
##   (its cabinet no longer solid, its deck a floor), well ahead of the runner;
## - a stomp on the hopper is the big hit (a third of its health) and phase 2 begins; it lurches out from
##   under the runner and rises back to where it paces; a missed hopper means it spins again, at full health;
## - weapons chip at it only while it can be hurt, and never past its cap (at most one stomp saved);
## - it plays the same on every attempt;
## - the scripted runner wins phase 1 at every lane count and both speeds, in quick play, dies, and wins
##   the whole fight in the retry that starts it over (all three phases: test_the_house_phases.gd plays
##   phases 2 and 3 and the campaign on their own).

const BOSS_PATH: String = "res://data/bosses/marketplace_boss.tres"
const LANES: Array[int] = [3, 5, 6]
const SPEEDS: Array[float] = [18.0, 22.6]
const REACTION: float = 0.35
## A button shows at least this long before the runner reaches it; the hopper opens at least this long
## before the runner reaches its stomp box.
const BUTTON_SIGHT: float = 1.0
const HOPPER_SIGHT: float = 1.3
## Phase 1 for a runner who never misses (GDD §10: a fight of 60-120 s, three phases).
const PHASE_ONE_MAX: float = 40.0

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
			await _test_buttons_and_jackpot(lanes, speed)
	await _test_missed_button()
	await _test_missed_set()
	await _test_missed_hopper()
	await _test_weapons()
	await _test_same_every_attempt()
	await _test_quick_play_and_retry()


## A copy of the slot whose spins offer buttons from the start (`opening` spins without), with `spins`.
func _rigged(opening: int = 0, spins: String = "") -> BossDef:
	var out: BossDef = def.duplicate() as BossDef
	var t: TheHouseTuning = (def.tuning as TheHouseTuning).duplicate() as TheHouseTuning
	t.opening_spins = PackedInt32Array([opening, opening, opening])
	if spins != "":
		t.spin_patterns = PackedStringArray([spins, spins, spins])
	out.tuning = t
	return out


func _fight(p_def: BossDef, lanes: int, speed: float, loadout: Loadout = null) -> Array:
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
	var arena: BossArena = boss.plan_arena(ctx)
	var world: RunWorld = sim.build_world(arena.layout, loadout, t, ctx.config)
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


# --- Buttons and the jackpot ---------------------------------------------------------------------

func _test_buttons_and_jackpot(lanes: int, speed: float) -> void:
	var tag: String = "(%d lanes, %.1f m/s)" % [lanes, speed]
	var pair: Array = _fight(_rigged(), lanes, speed)
	var world: RunWorld = pair[0]
	var boss: TheHouse = pair[1]
	var t: TheHouseTuning = boss.tuning
	var bot := TheHouseBot.new(boss)
	bot.reaction = REACTION
	var hints: Array[String] = []
	boss.hint_due.connect(func(key: String) -> void: hints.append(key))
	# Watch the jackpot's window as it opens.
	var w := {"open_at": -1.0, "span": Vector2.ZERO, "runner": 0.0, "sunk": false, "solid": true, "front": [], "credits0": -1,
		"placed": 0, "weak": false}
	var watch := func() -> void:
		if boss.jackpot.stage == TheHouseJackpot.Stage.SAG and int(w["credits0"]) < 0:
			w["credits0"] = world.credits.remaining()
		if boss.jackpot.window_open():
			if float(w["open_at"]) < 0.0:
				w["open_at"] = boss.fight_time()
				w["span"] = boss.jackpot.hopper_span()
				w["runner"] = world.player.distance
				w["sunk"] = boss.body.is_sunk()
				w["solid"] = boss.body.core_hitbox().is_active()
				w["weak"] = boss.body.weak_points_enabled()
			(w["front"] as Array).append(boss.front_at)
		w["placed"] = boss.jackpot.placed
	await _run(world, bot, 60.0, func() -> bool: return boss.phase_index >= 1 and not boss.jackpot.busy(), watch)
	check(world.player.alive, "the runner lives through the spin, the jackpot and the stomp %s" % tag)
	var lit: Array[Dictionary] = _events(boss, &"button_lit")
	var pressed: Array[Dictionary] = _events(boss, &"button_pressed")
	check(lit.size() == 3 and pressed.size() == 3, "three 7 buttons light up and the runner runs over all three %s" % tag)
	var sight_ok: bool = true
	var lanes_ok: bool = true
	var prev_lane: int = -1
	for i: int in mini(lit.size(), pressed.size()):
		if float(pressed[i]["t"]) - float(lit[i]["t"]) < BUTTON_SIGHT:
			sight_ok = false
		var lane: int = int(lit[i]["lane"])
		if prev_lane >= 0 and (lane == prev_lane or absi(lane - prev_lane) > t.button_max_shift):
			lanes_ok = false
		prev_lane = lane
	check(sight_ok, "each lights up at least %.1f s before the runner reaches it %s" % [BUTTON_SIGHT, tag])
	check(lanes_ok, "each in a lane of its own, at most %d lanes from the one before %s" % [t.button_max_shift, tag])
	var sevens: int = 0
	for e: Dictionary in _events(boss, &"reel"):
		if e["symbol"] == "seven" and e["locked"]:
			sevens += 1
	check(sevens == 3, "each button run over stops its reel on 7, locked %s" % tag)
	var results: Array[Dictionary] = _events(boss, &"result")
	check(not results.is_empty() and results[0]["jackpot"], "three 7s: JACKPOT %s" % tag)
	check(hints.has("marketplace_boss/buttons") and hints.has("marketplace_boss/jackpot"), "the buttons' and the jackpot's hints come %s" % tag)
	check(_events(boss, &"jackpot").size() == 1 and boss.events.any(func(e: Dictionary) -> bool:
		return e["event"] == &"sound" and e["name"] == &"house_jackpot"), "the sirens sound %s" % tag)
	check(int(boss.reactions.get(&"cheer", 0)) >= 2, "the citizens cheer at the jackpot and the stomp %s" % tag)
	# The window.
	check(float(w["open_at"]) >= 0.0 and w["sunk"] and not w["solid"] and w["weak"],
		"the hopper bursts open as its weak point, the machine sunk (its cabinet no longer solid, its deck a floor) %s" % tag)
	var span: Vector2 = w["span"]
	check((span.x - float(w["runner"])) / speed >= HOPPER_SIGHT,
		"it opens %.1f s before the runner reaches it %s" % [(span.x - float(w["runner"])) / speed, tag])
	var fronts: Array = w["front"]
	check(not fronts.is_empty() and absf(float(fronts[0]) - float(fronts[-1])) < 0.01, "it stays put while its hopper is open %s" % tag)
	check(span.y - span.x >= t.stomp_depth * speed / MovementTuning.REFERENCE_SPEED - 0.01, "a stomp box as long as the run's pace makes it %s" % tag)
	check(int(w["placed"]) == t.fountain_count and world.score.credits > 0,
		"the fountain's %d credits land as real credits, and some are grabbed (%d) %s" % [t.fountain_count, world.score.credits, tag])
	# The stomp: the big hit.
	var hits: Array[Dictionary] = _events(boss, &"weak_point")
	check(hits.size() == 1 and boss.phase_index == 1 and is_equal_approx(boss.health, boss.max_health * 2.0 / 3.0),
		"a stomp on the hopper takes a third of its health and phase 2 begins %s" % tag)
	check(boss.step == TheHouse.Step.PACE and not boss.body.is_sunk() and boss.body.core_hitbox().is_active()
		and is_equal_approx(boss.body.sag, 0.0) and absf(boss.front_at - world.player.distance - boss.stand_distance()) < 0.5,
		"it lurches out from under the runner and rises back to where it paces %s" % tag)
	var phase_one: float = float(hits[0]["t"]) if not hits.is_empty() else INF
	check(phase_one <= PHASE_ONE_MAX, "phase 1 takes %.1f s %s" % [phase_one, tag])
	print("  The House, buttons from the first spin %s: jackpot at %.1f s, stomped at %.1f s, the hopper open %.2f s before the runner reached it" % [
		tag, float(_events(boss, &"jackpot")[0]["t"]) if not _events(boss, &"jackpot").is_empty() else -1.0, phase_one,
		(span.x - float(w["runner"])) / speed])
	await sim.free_world(world)


# --- Misses --------------------------------------------------------------------------------------

## A runner who lets reel 2's button go by: it stops on its symbol and that attack follows; the other two
## stay locked, so the next spin offers only its button; taken, the jackpot.
func _test_missed_button() -> void:
	var pair: Array = _fight(_rigged(0, "cherry,bar,lightning|bar,cherry,bar"), 5, 18.0)
	var world: RunWorld = pair[0]
	var boss: TheHouse = pair[1]
	var bot := TheHouseBot.new(boss)
	bot.reaction = REACTION
	bot.skip_reels = [1]
	await _run(world, bot, 30.0, func() -> bool: return _events(boss, &"result").size() >= 1)
	var reels: Array[Dictionary] = _events(boss, &"reel")
	var missed: Array[Dictionary] = _events(boss, &"button_missed")
	check(missed.size() == 1 and int(missed[0]["reel"]) == 1, "the runner lets reel 2's button go by")
	var shown: Dictionary = {}
	for e: Dictionary in reels:
		shown[int(e["reel"])] = e
	check(shown.has(1) and shown[1]["symbol"] == "bar" and not shown[1]["locked"], "reel 2 stops on its symbol (BAR)")
	check(shown.has(0) and shown[0]["locked"] and shown.has(2) and shown[2]["locked"], "the other two lock on 7")
	bot.skip_reels = []
	await _run(world, bot, 40.0, func() -> bool: return _events(boss, &"jackpot").size() >= 1)
	var attacks: Array[Dictionary] = _events(boss, &"attack")
	check(attacks.size() >= 1 and attacks[0]["kind"] == "bar" and int(attacks[0]["size"]) == 1, "its BAR attack follows")
	var spins: Array[Dictionary] = _events(boss, &"spin")
	var planned: Array[Dictionary] = _events(boss, &"button_planned")
	check(spins.size() == 2 and (spins[1]["locked"] as PackedByteArray) == PackedByteArray([1, 0, 1]),
		"it just spins again, reels 1 and 3 still locked on 7")
	check(planned.size() == 4 and int(planned[3]["reel"]) == 1, "the next spin offers only reel 2's button")
	check(_events(boss, &"jackpot").size() == 1 and world.player.alive, "run over, the jackpot")
	await sim.free_world(world)


## A runner who lets a whole set go by: every reel shows its symbol and all three attacks follow; the next
## spin offers the set again, at the same rhythm.
func _test_missed_set() -> void:
	var pair: Array = _fight(_rigged(0, "cherry,bar,lightning"), 3, 22.6)
	var world: RunWorld = pair[0]
	var boss: TheHouse = pair[1]
	var bot := TheHouseBot.new(boss)
	bot.reaction = REACTION
	bot.avoids_buttons = true
	await _run(world, bot, 40.0, func() -> bool: return _events(boss, &"button_lit").size() >= 6)
	var results: Array[Dictionary] = _events(boss, &"result")
	check(_events(boss, &"button_missed").size() >= 3 and not results.is_empty() and results[0]["symbols"] == PackedStringArray(["cherry", "bar", "lightning"]),
		"a set let go by: the reels show their symbols")
	var kinds: Array = []
	for e: Dictionary in _events(boss, &"attack"):
		kinds.append(e["kind"])
	check(kinds.slice(0, 3) == ["cherry", "bar", "lightning"], "and all three attacks follow, in reel order")
	var planned: Array[Dictionary] = _events(boss, &"button_planned")
	check(planned.size() >= 6 and world.player.alive, "it just spins again, with the whole set (and the runner lived)")
	await sim.free_world(world)


## A runner who doesn't jump for the hopper: the window closes, it lurches away and spins again, its locks
## gone, at full health; the runner, who ran over its deck, is unhurt.
func _test_missed_hopper() -> void:
	var pair: Array = _fight(_rigged(), 5, 18.0)
	var world: RunWorld = pair[0]
	var boss: TheHouse = pair[1]
	var bot := TheHouseBot.new(boss)
	bot.reaction = REACTION
	bot.stomps = false
	var gaps: Array[float] = []
	await _run(world, bot, 60.0, func() -> bool: return _events(boss, &"spin").size() >= 2)
	var missed: Array[Dictionary] = _events(boss, &"hopper_missed")
	check(missed.size() == 1 and _events(boss, &"weak_point").is_empty() and is_equal_approx(boss.health, boss.max_health),
		"a hopper not stomped: the window closes, no damage")
	check(_events(boss, &"spin_again").size() == 1 and world.player.alive, "it spins again, and the runner is unhurt")
	var spins: Array[Dictionary] = _events(boss, &"spin")
	check(spins.size() >= 2 and (spins[1]["locked"] as PackedByteArray) == PackedByteArray([0, 0, 0]) and spins[1]["rigging"],
		"its locks are gone and the next spin offers all three buttons again")
	await _run(world, bot, 30.0, func() -> bool: return _events(boss, &"button_lit").size() >= 6)
	var lit: Array[Dictionary] = _events(boss, &"button_lit")
	check(lit.size() >= 6, "three buttons again")
	if lit.size() >= 6:
		# No escalation: the second set comes with the same rhythm as the first.
		for k: int in 2:
			gaps.append(float(lit[k + 1]["t"]) - float(lit[k]["t"]))
			gaps.append(float(lit[k + 4]["t"]) - float(lit[k + 3]["t"]))
		check(absf(gaps[0] - gaps[1]) < 0.05 and absf(gaps[2] - gaps[3]) < 0.05, "at the same rhythm as before (nothing escalates)")
	await sim.free_world(world)


# --- Weapons -------------------------------------------------------------------------------------

## GDD §10: "weapons chip away at it; stomps do the real damage". Shots count only while it can be hurt
## and never past its cap; a real weapon fires at it.
func _test_weapons() -> void:
	var loadout := Loadout.new()
	loadout.tiers = {&"weapon": 4}
	var pair: Array = _fight(_rigged(0), 5, 18.0, loadout)
	var world: RunWorld = pair[0]
	var boss: TheHouse = pair[1]
	var bot := TheHouseBot.new(boss)
	bot.reaction = REACTION
	world.player.god_mode = true
	var before_fight: Dictionary = {"damage": 0.0, "targeted": false}
	await _run(world, bot, 8.0, func() -> bool: return boss.is_vulnerable(), func() -> void:
		if not boss.is_vulnerable():
			before_fight["targeted"] = before_fight["targeted"] or boss.body.targetable()
			before_fight["damage"] = boss.weapon_damage)
	check(not before_fight["targeted"] and is_equal_approx(float(before_fight["damage"]), 0.0),
		"weapons can't touch it during its entrance")
	await _run(world, bot, 30.0, func() -> bool: return boss.weapon_damage > 0.0 or _events(boss, &"weak_point").size() >= 1)
	check(boss.weapon_damage > 0.0, "a weapon chips at it (%.1f)" % boss.weapon_damage)
	# Weapons pouring in all fight long stop at the cap.
	await _run(world, bot, 120.0, func() -> bool: return boss.is_defeated(), func() -> void:
		if boss.is_vulnerable():
			boss.body.take_damage(25.0, &"weapon"))
	var cap: float = boss.max_health * def.weapon_share_cap
	check(boss.weapon_damage <= cap + 0.01 and boss.weapon_damage > cap - 1.0,
		"weapons deal up to their cap and no more (%.1f of %.1f)" % [boss.weapon_damage, cap])
	check(boss.is_defeated() and _events(boss, &"weak_point").size() >= 2,
		"even with weapons at their cap it takes two stomps (%d)" % _events(boss, &"weak_point").size())
	check(not boss.body.targetable(), "beaten, it's no target")
	await sim.free_world(world)


# --- The same every attempt ----------------------------------------------------------------------

func _test_same_every_attempt() -> void:
	var logs: Array[String] = []
	for attempt: int in 2:
		var pair: Array = _fight(def, 5, 22.6)
		var world: RunWorld = pair[0]
		var boss: TheHouse = pair[1]
		var bot := TheHouseBot.new(boss)
		bot.reaction = REACTION
		await _run(world, bot, 160.0, func() -> bool: return boss.is_defeated())
		var parts := PackedStringArray()
		for e: Dictionary in boss.events:
			if e["event"] in [&"spin", &"strike", &"button_planned", &"button_pressed", &"result", &"jackpot", &"weak_point",
					&"wall_fences", &"ceiling_planned", &"ceiling_shown", &"defeat"]:
				var copy: Dictionary = e.duplicate()
				copy.erase("t")
				parts.append("%.2f %s" % [float(e["t"]), copy])
		logs.append("\n".join(parts))
		await sim.free_world(world)
	check(logs.size() == 2 and logs[0] == logs[1] and logs[0].length() > 200 and logs[0].contains("ceiling_shown"),
		"it plays the same on every attempt: the same spins, strikes, buttons, wall fences, ceilings and jackpots at the same times")


# --- Quick play, a death and the retry -----------------------------------------------------------

## Through the game itself (quick play, as App.start_boss_quick): at every lane count and both speeds the
## runner wins phase 1, then dies; quick play retries, starting the fight over; and the runner plays all
## three phases to the win (its wall and ceiling buttons included), without a loadout or armor pickups.
func _test_quick_play_and_retry() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var saved: Profile = App.profile
	var lanes_pc: int = App.rules.lanes_pc
	for lanes: int in LANES:
		for speed: float in SPEEDS:
			App.profile = SampleProfiles.fresh()
			App.rules.lanes_pc = lanes
			await _quick_flow(lanes, speed)
	App.rules.lanes_pc = lanes_pc
	App.show_title()
	await tree.process_frame
	App.profile = saved
	main.queue_free()
	App.main = null
	await tree.process_frame


func _quick_flow(lanes: int, speed: float) -> void:
	var tag: String = "(%d lanes, %.1f m/s)" % [lanes, speed]
	var quick: BossDef = def.duplicate() as BossDef
	quick.armor_rule = false
	quick.arena = def.arena.duplicate() as LevelConfig
	quick.arena.run_speed = speed
	App.start_boss_quick(quick)
	var run: LevelRun = App.run
	if run != null:
		# Profile runs always carry free armor, even with no purchased tiers. Rebuild with a genuinely
		# bare loadout before its entrance runs; the real quick retry keeps this same loadout.
		run.context.loadout = Loadout.new()
		run.restart(run.context)
	await physics_frames(3)
	run = App.run
	check(run != null and run.encounter is TheHouse and run.world.geo.lane_count == lanes
		and is_equal_approx(run.world.tuning.run_speed, speed) and not run.world.player.god_mode,
		"quick play plays the fight, no god mode %s" % tag)
	if run == null or not run.encounter is TheHouse:
		return
	check(run.context.loadout != null and run.context.loadout.tiers.is_empty()
		and run.context.loadout.charges.is_empty() and not run.context.loadout.has_armor()
		and run.world.player.armor == 0 and run.world.player.shield == 0,
		"the full-fight runner brings no powerups %s" % tag)
	var boss := run.encounter as TheHouse
	var bot := TheHouseBot.new(boss)
	bot.reaction = REACTION
	for i: int in 90 * 60:
		if boss.phase_index >= 1 or not run.world.player.alive:
			break
		bot.step()
		await tree.physics_frame
	check(boss.phase_index == 1 and run.world.player.alive, "the runner wins phase 1 %s" % tag)
	run.world.player._die("test hazard")
	await physics_frames(int((LevelRun.QUICK_DEATH_PAUSE + 0.4) * 60.0))
	run = App.run
	boss = run.encounter as TheHouse if run != null else null
	check(boss != null and boss.phase_index == 0 and boss.step == TheHouse.Step.ENTER and is_equal_approx(boss.health, boss.max_health)
		and run.context.attempt == 2 and run.world.player.alive,
		"after a death, quick play retries: the fight starts over, its entrance, at full health %s" % tag)
	if boss == null:
		return
	bot = TheHouseBot.new(boss)
	bot.reaction = REACTION
	var phases: Dictionary = {}
	for i: int in 160 * 60:
		if boss.is_defeated() or not run.world.player.alive:
			break
		phases[boss.phase_index] = true
		bot.step()
		await tree.physics_frame
	var stomps: int = _events(boss, &"weak_point").size()
	check(boss.is_defeated() and run.world.player.alive and phases.size() == 3 and stomps == 3,
		"and the retry plays all three phases to the win (%.0f s) %s" % [boss.fight_time(), tag])
	check(run.world.player.armor == 0 and run.world.player.shield == 0 and _events(boss, &"armor_pickup").is_empty(),
		"the harder fight is won without protection or armor pickups %s" % tag)
	var attack_only: int = 0
	for e: Dictionary in _events(boss, &"spin"):
		attack_only += 1 if not bool(e["rigging"]) else 0
	check(attack_only == 9 and boss.attacks.count >= 27 and boss.attacks.skipped == 0,
		"all nine attack-only spins deliver their pressure before the three jackpots %s" % tag)
	var kinds: Dictionary = {}
	for e: Dictionary in _events(boss, &"button_pressed"):
		kinds[e["kind"]] = true
	check(kinds.has("floor") and kinds.has("wall") and kinds.has("ceiling"),
		"its buttons on the floor, on a wall and on a ceiling all run over %s" % tag)
	check(bot.stuck == 0 and boss.fight_time() >= 60.0 and boss.fight_time() <= def.three_star_seconds,
		"a clean fight in %.0f s: in GDD §10's 60-120 s, within three stars' par %s" % [boss.fight_time(), tag])
	print("  The House, the unprotected whole fight (%d lanes, %.1f m/s): %.1f s, %d attack-only spins, %d strikes" % [
		lanes, speed, boss.fight_time(), attack_only, boss.attacks.count])

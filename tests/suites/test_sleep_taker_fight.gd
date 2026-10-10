extends TestSuite
## The Sleep Taker's fight (GDD §10; task E5c-b; its build and attacks: test_sleep_taker.gd,
## test_sleep_taker_attacks.gd), at 3, 5 and 6 lanes, at the reference 18 m/s and the Dead Zone's
## 24.2 m/s:
## - its data: the slot plays it, five phases each faster (owner, October 10, 2026: two more, the hands
##   about 10% and 20% more often than in the third, nothing new), one EMP each, the standard armor rule (with a
##   phase begun unprotected counting as a break), par times, its new sounds and its generator hint, no
##   victory riff (its defeat ends in silence);
## - the whole fight on its real arena (twice the holes it was first built with, its wall gaps, rounds of
##   hands spread along the street and lights out half as bright: owner, October 8, 2026), for a runner
##   who reads it and stomps each generator (no god mode,
##   no armor): five EMPs win it in FIGHT_MIN-FIGHT_MAX; each generator shows from afar in a lane clear around it,
##   the nightmare lunges in lure_seconds before the runner reaches it and attacks nothing while lured,
##   the arcs show it's in reach well before the runner must jump (the window), and every stomp's EMP
##   reaches it; each hit tears a chunk away and the next phase is faster; the same every attempt;
## - a missed generator: it pulls back, another comes, nothing escalates;
## - an EMP out of reach (hovering, or during a phase's intro) does nothing to it; weapons never set a
##   generator off;
## - the defeat: hundreds of wisps, the silence (the music fades out), the grey dawn, then the results;
##   the lights and the scenery's light come back after the fight;
## - through the campaign at every lane count: the Dead Zone's last level, then the fight (a death in
##   its second phase, a retry from the start, a win), its results and stars, the shop and the outro.

const BOSS_PATH: String = "res://data/bosses/dead_zone_boss.tres"
const LANES: Array[int] = [3, 5, 6]
const SPEEDS: Array[float] = [18.0, 24.2]
## A player's reaction: the runner moves this long after a warning starts.
const REACTION: float = 0.35
const NEW_SOUNDS: Array[StringName] = [&"sleep_taker_lure", &"sleep_taker_crackle", &"sleep_taker_torn",
	&"sleep_taker_wisps"]
## GDD §10: a boss fight lasts about as long as a level, 60-120 s; owner, October 10, 2026: the Sleep
## Taker "ends almost too fast", so two more phases make it longer (about 130 s for a runner who never
## misses).
const FIGHT_MIN: float = 60.0
const FIGHT_MAX: float = 160.0
## Owner, October 10, 2026: the fourth and fifth phases' hands about 10% and 20% more often than the
## third's.
const LATE_PHASE_MORE: Array[float] = [0.1, 0.2]
## The arcs must show this long, at least, before the runner reaches the generator.
const WINDOW_MIN: float = 1.2

var sim: RunSim
var def: BossDef
## The cleanest fight's length (s), measured by _test_whole_fight, for the par times.
var _clean: float = 0.0
## The whole fight's log at 5 lanes and 18 m/s (_test_whole_fight), for _test_same_every_attempt.
var _log_5: String = ""


func run() -> void:
	sim = RunSim.new(tree, tuning)
	var slot := load(BOSS_PATH) as BossDef
	def = slot if slot != null and slot.is_built() else null
	if def == null:
		check(false, "the Sleep Taker's fight loads")
		return
	_test_data()
	await _test_whole_fight()
	await _test_same_every_attempt()
	await _test_missed_generator()
	await _test_out_of_reach()
	await _test_defeat()
	await _test_campaign()


# --- Helpers -------------------------------------------------------------------------------

## The fight at `lanes` and `speed` m/s (0: 18): [world, boss].
func _fight(p_def: BossDef, lanes: int, speed: float = 0.0, resume: Dictionary = {}) -> Array:
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
	ctx.boss_resume = resume
	var arena: BossArena = boss.plan_arena(ctx)
	var world: RunWorld = sim.build_world(arena.layout, null, t, ctx.config)
	boss.setup(world, ctx, arena)
	return [world, boss]


## The fight on a plain street with only its generators (no refuges, no other attacks).
func _generators_only() -> BossDef:
	var out: BossDef = def.duplicate() as BossDef
	var t: SleepTakerTuning = (def.tuning as SleepTakerTuning).duplicate() as SleepTakerTuning
	t.refuge_first = 100000.0
	t.attack_gap = 100000.0
	out.tuning = t
	out.arena = null
	return out


func _events(boss: BossEncounter, event: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in boss.events:
		if e["event"] == event:
			out.append(e)
	return out


func _sounds(boss: BossEncounter, sound: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in _events(boss, &"sound"):
		if e["name"] == sound:
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


# --- Data ------------------------------------------------------------------------------------

func _test_data() -> void:
	var list: Array[BossPhase] = def.phase_list()
	var one_hit: bool = true
	var faster: bool = true
	var paces: PackedStringArray = []
	for i: int in list.size():
		one_hit = one_hit and list[i].hits == 1
		faster = faster and (i == 0 or list[i].pace > list[i - 1].pace)
		paces.append("%.2f" % list[i].pace)
	check(list.size() == 5 and one_hit, "five phases, five EMP hits (GDD §10: three; owner, October 10, 2026: two more)")
	check(faster, "hungrier each phase: each one faster (%s)" % ", ".join(paces))
	var t := def.tuning as SleepTakerTuning
	check(t.pattern_for(2).count("lights_out") > t.pattern_for(0).count("lights_out"), "and more lights out in the third phase's list")
	if list.size() == 5:
		var near: bool = true
		for k: int in LATE_PHASE_MORE.size():
			near = near and absf(list[3 + k].pace / list[2].pace - (1.0 + LATE_PHASE_MORE[k])) <= 0.03
		check(near and t.pattern_for(3) == t.pattern_for(2) and t.pattern_for(4) == t.pattern_for(2),
			"the last two phases bring nothing new: the third's list, its hands %.0f%% and %.0f%% more often (paces %.2f, %.2f over %.2f)" % [
			(list[3].pace / list[2].pace - 1.0) * 100.0, (list[4].pace / list[2].pace - 1.0) * 100.0, list[3].pace, list[4].pace,
			list[2].pace])
	check(def.armor_rule and def.armor_delay_min == 15.0 and def.armor_delay_max == 17.0 and def.armor_when_unprotected,
		"the standard armor rule (15-17 s), a phase begun unprotected counting as a break (as the Floating Head's)")
	check(def.three_star_seconds < def.two_star_seconds and def.three_star_seconds >= FIGHT_MIN,
		"par times: %.0f s for three stars, %.0f s for two" % [def.three_star_seconds, def.two_star_seconds])
	var sfx := load("res://data/audio/sfx_library.tres") as SfxLibrary
	for sound: StringName in NEW_SOUNDS:
		check(sfx.names().has(String(sound)) and sfx.stream(sound) != null, "its sound %s exists" % sound)
	check(sfx.stream(&"sleep_taker_crackle").get_length() <= 2.0, "the arcs' crackle is short (it's a cue)")
	check(sfx.stream(&"sleep_taker_wisps").get_length() <= t.wisp_seconds, "the wisps' sound fades within their rise")
	var hints: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/hints/hints.json"))
	var triggers: Array = []
	for h: Dictionary in (hints as Dictionary).get("hints", []):
		triggers.append(h.get("trigger", ""))
	check(triggers.has("boss:dead_zone_boss/generator"), "the generator's first-time hint exists")
	var boss := BossEncounter.create(def) as SleepTaker
	check(boss != null and not boss.victory_riff(), "GDD §10: its defeat ends in silence (no victory riff)")
	if boss != null:
		boss.free()


# --- The whole fight -------------------------------------------------------------------------

## A runner who reads the fight (SleepTakerBot: it dodges by the warnings, runs the arena and stomps
## each generator) beats it on its real arena, without god mode or armor, at every lane count and both
## speeds; every lure is fair and readable along the way.
func _test_whole_fight() -> void:
	for speed: float in SPEEDS:
		for lanes: int in LANES:
			await _whole_fight(lanes, speed)


func _whole_fight(lanes: int, speed: float) -> void:
	var tag: String = "(%d lanes, %.1f m/s)" % [lanes, speed]
	var pair: Array = _fight(def, lanes, speed)
	var world: RunWorld = pair[0]
	var boss: SleepTaker = pair[1]
	var t: SleepTakerTuning = boss.tuning
	var k: float = boss.run_pace()
	var bot := SleepTakerBot.new(boss, &"wall")
	bot.reaction = REACTION
	var cause: Array = [""]
	world.player.died.connect(func(c: String) -> void: cause[0] = c)
	# Every frame: where the nightmare is while lured, and whether anything attacked meanwhile.
	var seen := {"lured_ahead": [], "attack_while_lured": 0}
	await _run(world, 200.0, func() -> bool: return boss.is_defeated(), func() -> void:
		bot.step()
		if boss.lure.stage == SleepTakerLure.Stage.HOLD:
			(seen["lured_ahead"] as Array).append(boss.body.global_position.z * -1.0 - world.player.distance)
			if boss.slash.busy() or (boss.hands.busy() and not boss.hands.active.is_empty() and
					int(boss.hands.active[0]["stage"]) == SleepTakerHands.Stage.MIST) or boss.dark.warning_on():
				seen["attack_while_lured"] = int(seen["attack_while_lured"]) + 1)
	check(boss.is_defeated() and world.player.alive, "a runner who reads it beats it %s%s" % [tag,
		"" if world.player.alive else ": %s at %.0f m, %.1f s" % [cause[0], world.player.distance, boss.fight_time()]])
	if not boss.is_defeated():
		await sim.free_world(world)
		return
	var fight: float = boss.fight_time()
	check(fight >= FIGHT_MIN and fight <= FIGHT_MAX, "the fight lasts %.0f-%.0f s (%.1f s) %s" % [FIGHT_MIN, FIGHT_MAX, fight, tag])
	_clean = maxf(_clean, fight)
	var hits: Array[Dictionary] = _events(boss, &"emp_hit")
	check(hits.size() == 5 and _events(boss, &"emp_missed").is_empty() and _events(boss, &"lure_missed").is_empty(),
		"five EMPs, one a phase, each reaching it %s" % tag)
	var all_torn: bool = true
	for chunk: int in SleepTakerModel.CHUNK_HEADS.size():
		all_torn = all_torn and boss.body.torn(chunk) >= 1.0
	check(SleepTakerModel.CHUNK_HEADS.size() == 4 and all_torn and _sounds(boss, &"sleep_taker_torn").size() == 4,
		"the first four each tear a chunk away (with its howl); the fifth bursts it %s" % tag)
	# Each generator: in sight from afar, in a lane clear around it.
	var gens: Array[Dictionary] = _events(boss, &"generator")
	var sighted: bool = true
	var clear: bool = true
	for g: Dictionary in gens:
		sighted = sighted and float(g["at"]) - float(g["d"]) >= t.generator_sight * k - 0.01
		var lane: int = int(g["lane"])
		var at: float = float(g["at"])
		clear = clear and boss.arena.floor_clear(at - t.generator_clear_before * k, at + t.generator_clear_after * k, lane)
		# Where the stomp's bounce comes down (the bot's stomps land in it, without a fall).
		var landing: Vector2 = SleepTakerLure.landing_span(at, world.player.speed, world.tuning, world.rules)
		clear = clear and boss.arena.floor_clear(landing.x, landing.y, lane)
	check(gens.size() == 5 and sighted and clear, "each generator comes into sight from afar (%.0f m), its lane clear around it and where a stomp's bounce comes down %s" % [
		t.generator_sight * k, tag])
	# Each lure: on time, held close, nothing attacking; the arcs well before the runner must jump.
	var lures: Array[Dictionary] = _events(boss, &"lure")
	var reach: Array[Dictionary] = _events(boss, &"in_reach")
	var smashes: Array[Dictionary] = _events(boss, &"generator_smashed")
	var on_time: bool = lures.size() == 5
	var window: float = INF
	for i: int in mini(lures.size(), mini(reach.size(), smashes.size())):
		var v: float = world.player.speed
		on_time = on_time and absf(float(lures[i]["d"]) - (float(lures[i]["at"]) - v * t.lure_seconds)) <= v / 60.0 + 0.01
		window = minf(window, float(smashes[i]["t"]) - float(reach[i]["t"]))
		on_time = on_time and bool(smashes[i]["in_reach"]) and smashes[i]["cause"] == &"stomp"
	check(on_time, "it lunges in %.1f s before the runner reaches each generator, and every stomp's EMP reaches it %s" % [
		t.lure_seconds, tag])
	if lanes == 5 and is_equal_approx(speed, tuning.run_speed):
		_log_5 = _fight_log(boss)
	var bot_lead: float = bot.stomp_lead() / world.player.speed
	check(window >= WINDOW_MIN, "the arcs show it's in reach %.2f s before the stomp lands (%.2f s before the jump) %s" % [
		window, window - bot_lead, tag])
	var ahead: Array = seen["lured_ahead"]
	var lured: float = boss.lure.lure_ahead()
	var held: bool = not ahead.is_empty()
	for a: Variant in ahead:
		held = held and absf(float(a) - lured) < 1.5
	check(held, "lured, it holds close in front of the runner (%.1f m ahead) %s" % [lured, tag])
	check(int(seen["attack_while_lured"]) == 0, "it attacks nothing while lured %s" % tag)
	# The phases: each faster, each begun with its recoil (nothing attacking), the last ended by the defeat.
	var reforms: Array[Dictionary] = _events(boss, &"reform")
	check(reforms.size() == 4, "after each of the first four hits it recoils and re-forms %s" % tag)
	# Owner, October 8, 2026: rounds of hands spread along the street (and on its walls), each with its way
	# through, in every phase.
	var round_phases: Dictionary = {}
	var wall_hands: int = 0
	for e: Dictionary in _events(boss, &"round"):
		round_phases[int(e["phase"])] = true
	for e: Dictionary in _events(boss, &"mist"):
		wall_hands += 1 if int(e["side"]) != 0 else 0
	check(boss.hands.rounds >= 3 and round_phases.size() >= 2 and wall_hands > 0
		and bot.routes_found == boss.hands.rounds and bot.routes_missing == 0,
		"%d rounds of hands across %d phases (%d wall hands), each with its way through %s" % [boss.hands.rounds,
		round_phases.size(), wall_hands, tag])
	if lanes == 5:
		print("  Sleep Taker's whole fight (5 lanes, %.1f m/s): %.1f s, generators in sight %.1f s before their lure, arcs %.2f s before the stomp" % [
			speed, fight, (float(lures[0]["t"]) - float(gens[0]["t"])) if not lures.is_empty() and not gens.is_empty() else 0.0, window])
	await sim.free_world(world)


## A second attempt with the same moves plays out as the first did (_test_whole_fight's at 5 lanes):
## generators, lures, attacks, hits and the defeat.
func _test_same_every_attempt() -> void:
	var pair: Array = _fight(def, 5)
	var world: RunWorld = pair[0]
	var boss: SleepTaker = pair[1]
	var bot := SleepTakerBot.new(boss, &"wall")
	bot.reaction = REACTION
	await _run(world, 200.0, func() -> bool: return boss.is_defeated(), func() -> void: bot.step())
	var again: String = _fight_log(boss)
	check(_log_5 != "" and again == _log_5 and again.contains("emp_hit"), "every attempt plays out the same way")
	await sim.free_world(world)


## What happened in a fight, for comparing attempts.
func _fight_log(boss: SleepTaker) -> String:
	var line: PackedStringArray = []
	for e: Dictionary in boss.events:
		if e["event"] in [&"generator", &"lure", &"in_reach", &"emp_hit", &"phase", &"mist", &"slash", &"dark", &"defeated"]:
			line.append("%s %.3f %s %s" % [e["event"], float(e["t"]), e.get("lane", ""), e.get("at", "")])
	return " | ".join(line)


# --- A missed generator --------------------------------------------------------------------------

## A runner who lets the generators go by: each lure ends, it pulls back to hover, and another generator
## comes generator_again later; the fight stays in its first phase, and each lure plays like the last
## (GDD §10: no time limit, no escalation).
func _test_missed_generator() -> void:
	var pair: Array = _fight(_generators_only(), 5)
	var world: RunWorld = pair[0]
	var boss: SleepTaker = pair[1]
	var t: SleepTakerTuning = boss.tuning
	var bot := SleepTakerBot.new(boss)
	bot.smashes = false
	var back: Array = [false]
	await _run(world, 60.0, func() -> bool: return boss.lure.count >= 3 and boss.lure.stage == SleepTakerLure.Stage.WAITING,
		func() -> void:
			bot.step()
			if boss.lure.missed >= 1 and boss.lure.stage == SleepTakerLure.Stage.IDLE:
				back[0] = bool(back[0]) or absf(boss.pose.z - t.hover_ahead) < 0.5)
	var gens: Array[Dictionary] = _events(boss, &"generator")
	var missed: Array[Dictionary] = _events(boss, &"lure_missed")
	check(world.player.alive and gens.size() >= 3 and missed.size() >= 2, "a missed generator is followed by another (%d, %d missed)" % [
		gens.size(), missed.size()])
	check(bool(back[0]) and is_equal_approx(boss.health, boss.max_health) and boss.phase_index == 0,
		"it pulls back to hover after each, unhurt, still in its first phase")
	var lures: Array[Dictionary] = _events(boss, &"lure")
	var same: bool = lures.size() >= 2
	for i: int in range(1, mini(lures.size(), gens.size())):
		var first: float = float(lures[0]["t"]) - float(gens[0]["t"])
		same = same and absf((float(lures[i]["t"]) - float(gens[i]["t"])) - first) < 0.05
	var gaps_ok: bool = true
	for i: int in range(1, mini(gens.size(), missed.size() + 1)):
		gaps_ok = gaps_ok and float(gens[i]["t"]) - float(missed[i - 1]["t"]) >= t.generator_again - 0.01
	check(same and gaps_ok, "each comes generator_again after the last miss, and plays like the first: nothing escalates")
	await sim.free_world(world)
	# On its real arena: the first generator let go by, then a win; what the miss cost, against the par
	# times.
	pair = _fight(def, 5)
	world = pair[0]
	boss = pair[1]
	bot = SleepTakerBot.new(boss, &"wall")
	bot.reaction = REACTION
	bot.skips = 1
	await _run(world, 200.0, func() -> bool: return boss.is_defeated(), func() -> void: bot.step())
	var fight: float = boss.fight_time()
	check(boss.is_defeated() and world.player.alive and _events(boss, &"lure_missed").size() == 1,
		"on its arena, a runner who lets the first generator go by still wins (%.1f s)" % fight)
	check(def.stars_for(true, fight) == 2 and (_clean <= 0.0 or def.stars_for(true, _clean) == 3),
		"three stars without a miss (%.1f s), two with one (%.1f s)" % [_clean, fight])
	print("  Sleep Taker: one missed generator costs %.1f s (%.1f s against %.1f s)" % [fight - _clean, fight, _clean])
	await sim.free_world(world)


# --- Out of reach ----------------------------------------------------------------------------------

## An EMP that goes off while the nightmare isn't lured (it hovers far ahead), or during a phase's intro,
## does nothing to it; and weapons never set a generator off.
func _test_out_of_reach() -> void:
	var pair: Array = _fight(_generators_only(), 5)
	var world: RunWorld = pair[0]
	var boss: SleepTaker = pair[1]
	world.player.god_mode = true
	world.player.running = true
	# During its entrance (it can't be hurt yet).
	await physics_frames(30)
	world.emp(world.lane_point(2, world.player.distance + 20.0), 16.0)
	check(_events(boss, &"emp_missed").size() == 1 and _events(boss, &"emp_missed")[0]["why"] == &"not_vulnerable"
		and is_equal_approx(boss.health, boss.max_health), "an EMP during its entrance does nothing to it")
	await _run(world, 10.0, func() -> bool: return boss.state == BossEncounter.State.FIGHT)
	# Hovering: a generator smashed far ahead of the lure.
	check(boss.lure.place_at(world.player.distance + 120.0, 2), "a generator stands ahead")
	var gen: FenceGenerator = boss.lure.generator
	check(gen != null and gen.immune_to_weapons and not gen.targetable(), "weapons never set it off (GDD §9.1): auto-fire ignores it")
	if gen != null:
		gen.take_damage(1000.0, &"weapon")
		check(gen.alive, "and no shot destroys it")
		gen.defeat(&"stomp")
	await physics_frames(2)
	var missed: Array[Dictionary] = _events(boss, &"emp_missed")
	var gap: float = float(missed[1].get("gap", 0.0)) if missed.size() > 1 else 0.0
	check(missed.size() == 2 and missed[1]["why"] == &"out_of_reach" and is_equal_approx(boss.health, boss.max_health)
		and boss.phase_index == 0, "smashed while it hovers, not lured, its EMP doesn't reach it (%.1f m away)" % gap)
	await sim.free_world(world)


# --- The defeat ------------------------------------------------------------------------------------

## The last EMP (its fifth phase, the runner stomping the generator): hundreds of wisps, the music fading
## out, the grey dawn, then the results; the lights come back as they were once the fight ends.
func _test_defeat() -> void:
	var scenery_before: float = ZoneSkin.scenery_light_now
	var music: MusicDirector = MusicDirector.instance()
	if music != null:
		music.play(&"dead_zone", 0.0)
	var pair: Array = _fight(_generators_only(), 5, 0.0, {"phase": 4})
	var world: RunWorld = pair[0]
	var boss: SleepTaker = pair[1]
	var t: SleepTakerTuning = boss.tuning
	var bot := SleepTakerBot.new(boss)
	var gone: bool = true
	for chunk: int in SleepTakerModel.CHUNK_HEADS.size():
		gone = gone and boss.body.torn(chunk) >= 1.0
	check(gone, "resumed at its last phase, its four chunks are already gone")
	await _run(world, 60.0, func() -> bool: return boss.is_defeated(), func() -> void: bot.step())
	check(boss.is_defeated() and _events(boss, &"emp_hit").size() == 1, "the last EMP beats it")
	var defeat: SleepTakerDefeat = boss.defeat
	check(defeat.wisps.emitting and defeat.wisps.amount >= 100, "GDD §10: it bursts into hundreds of wisps (%d)" % defeat.wisps.amount)
	check(_sounds(boss, &"sleep_taker_wisps").size() == 1, "with the dreams' release")
	check(music == null or music.current() == &"", "then silence: the music fades out")
	var light_at_defeat: float = ZoneSkin.scenery_light_now
	var over_at: Array = [-1.0]
	var faded: Array = [false]
	await _run(world, 15.0, func() -> bool: return float(over_at[0]) >= 0.0, func() -> void:
		faded[0] = bool(faded[0]) or boss.body.fade >= 1.0
		if boss.victory_over() and float(over_at[0]) < 0.0:
			over_at[0] = boss.state_time)
	check(bool(faded[0]), "it comes apart as they burst out")
	check(float(over_at[0]) >= t.dawn_delay + t.dawn_seconds - 0.05 and float(over_at[0]) <= maxf(t.wisp_seconds, t.dawn_delay + t.dawn_seconds) + 0.1,
		"the results wait for the dawn (%.1f s after the last EMP)" % float(over_at[0]))
	check(not _events(boss, &"dawn").is_empty() and ZoneSkin.scenery_light_now > maxf(light_at_defeat, 1.0) + 0.1,
		"the first grey dawn breaks: brighter than the zone's own light (%.2f)" % ZoneSkin.scenery_light_now)
	await sim.free_world(world)
	check(is_equal_approx(ZoneSkin.scenery_light_now, scenery_before), "the scenery's light is back as it was after the fight")
	if music != null:
		music.stop(0.0)


# --- Through the campaign ---------------------------------------------------------------------------

## The fight in the campaign's flow at every lane count, played by the bot (no god mode): the Dead Zone's
## last level, then the fight: a death in its second phase, the retry starting it over, and a win through
## all five phases; its results and stars, the shop and the outro's slot.
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
	App.play_step(App.campaign.step("dead_zone/2"))
	App.begin_run()
	await physics_frames(10)
	check(App.run != null and App.run.world.geo.lane_count == lanes, "the Dead Zone's last level starts %s" % tag)
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
	check(run != null and run.encounter is SleepTaker and run.context.step.id == "dead_zone/boss"
		and run.world.geo.lane_count == lanes and not run.world.player.god_mode, "then the fight, no god mode %s" % tag)
	if run == null or not run.encounter is SleepTaker:
		return
	# The first attempt: the first phase won, then a death in the second.
	var boss := run.encounter as SleepTaker
	var bot := SleepTakerBot.new(boss, &"wall")
	bot.reaction = REACTION
	for i: int in 120 * 60:
		if boss.phase_index >= 1 and boss.state == BossEncounter.State.FIGHT or not run.world.player.alive:
			break
		bot.step()
		await tree.physics_frame
	check(boss.phase_index == 1 and run.world.player.alive, "the first phase falls to its first EMP %s" % tag)
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
	boss = run.encounter as SleepTaker if run != null else null
	check(boss != null and run.context.attempt == 2 and run.context.boss_resume.is_empty() and boss.phase_index == 0
		and boss.step == SleepTaker.Step.ENTER and is_equal_approx(boss.health, boss.max_health)
		and boss.body.torn(0) == 0.0, "the retry starts the fight over: its entrance, whole, at full health %s" % tag)
	if boss == null:
		return
	# The retry, won.
	bot = SleepTakerBot.new(boss, &"wall")
	bot.reaction = REACTION
	var events: Array[Dictionary] = boss.events
	var phases: Dictionary = {}
	for i: int in 200 * 60:
		if App.screen is ResultsScreen or App.run != run or not run.world.player.alive:
			break
		if is_instance_valid(boss):
			phases[boss.phase_index] = true
			bot.step()
		await tree.physics_frame
	await tree.process_frame
	var hits: int = 0
	for e: Dictionary in events:
		hits += 1 if e["event"] == &"emp_hit" else 0
	check(phases.size() == 5 and hits == 5, "the retry plays all five phases to the win %s" % tag)
	var result: RunResult = (App.screen as ResultsScreen).result if App.screen is ResultsScreen else null
	check(result != null and result.completed and result.context.is_boss(), "a win's results follow the dawn %s" % tag)
	if result == null:
		return
	check(result.stars == def.stars_for(true, result.time) and result.stars == 3,
		"three stars for a fight without a miss (%.1f s) %s" % [result.time, tag])
	check(App.profile.is_completed("dead_zone/boss"), "the boss step counts as done %s" % tag)
	App.continue_after_result(result)
	shop = App.screen as ShopScreen
	check(shop != null and shop.play_label == "Next", "then the shop %s" % tag)
	if shop == null:
		return
	shop.on_close.call()
	await tree.process_frame
	var outro := App.screen as SlotScreen
	var cine: Cinematic = App.playing_cinematic()
	check((outro != null and outro.step.id == "dead_zone/outro") or (cine != null and cine.step.id == "dead_zone/outro"),
		"then the Dead Zone's outro %s" % tag)

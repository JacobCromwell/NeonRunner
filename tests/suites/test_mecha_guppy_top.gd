extends TestSuite
## Phase 3 of Mecha Guppy and Captain Cogs, "Level with Captain Cogs", and the defeat (GDD §10; task E5e-c), on real
## physics (MechaGuppyTop, MechaGuppyRounds, MechaGuppyWaves, MechaGuppyLeap; the whole fight: test_mecha_guppy_whole):
## - the script (MechaGuppyTop.plan), at the defaults and with every phase 3 tunable at both ends of its range: beats on the
##   looped script from top_first, top_beat apart; every round's cannonballs reach the runner at least a reaction, a
##   switch and dodge_margin after its warning; every wave's surge reaches them at least a reaction and a jump's rise after
##   its swell starts; no beat's warning before the last beat's attack has passed (never a jump and a switch at once);
##   none after top_clear before the minute's end; every round leaves every other lane clear, one switch from any lane;
## - the minute counts from top_reached: the boss bar runs down over it (GDD §10, proposed) and the fight is won as it
##   ends, not before; hits don't end phase 3; the ship comes level alongside the top, at the runner's height, in view;
## - every round and wave warned, seen and heard, before it lands: a round's red lines down exactly the lanes it strikes
##   (on the top's deck) with the cannons' charge, a wave's swell rising beside the top with its roar, its crest over the
##   deck's edge from MechaGuppyWaves.CREST_BY into the warning (task E5e-c's review); a dodging runner
##   (MechaGuppyBot, the planner's reaction) lives through the minute untouched at 3, 5 and 6 lanes and 18 and 23.8 m/s,
##   switching out of every round and jumping every wave, the beats as planned;
## - real contact only: a cannonball kills a runner who stays in its lane, and one who jumps it (too tall to jump), and
##   never one a lane away; a wave kills a runner who doesn't jump it and spares one who does; armor and the shield block
##   either (the item spent), the dash passes through either;
## - no escalation, a retry plays the same: the script's loops alike, and two attempts the same, beat for beat; beats held
##   back (the pattern off a while, as an intro would) start late one at a time, each keeping its gap after the last;
## - the boss bar runs down through the minute at 30, 50 and 60 rendered frames a second, its white segment draining with
##   the red (BossEncounter.health_runs_down; task E5e-c's review), while a hit's white segment still holds a moment;
## - the defeat: Mecha Guppy bursts up beside the top under the ship, gulps the captain with the ship's stern half (the
##   bow half falling away), falls back, then breaches out at sea past the shoreline, where the run camera sees it over
##   the deck's edge, and dives back in with a plume of spray (task E5e-c's review: the swim away must be seen); nothing
##   of its jaws or its body ever over the lanes or the eaves, nothing in it hurts the runner (no hazard live after the
##   win), the riff after the gulp, and victory_over dive_after its dive, well within LevelRun.BOSS_VICTORY_MAX;
## - the sounds: phase 3's in the library, the warnings as long as their warnings, with no pitch variation.

const BOSS_PATH: String = "res://data/bosses/beach_boss.tres"
const LANES: Array[int] = [3, 5, 6]
const SPEEDS: Array[float] = [18.0, 23.8]
const REACTION: float = 0.35
## A frame's slack in the timing checks (seconds).
const FRAME: float = 1.0 / 60.0 + 0.001
## A swell's crest stands at least this far over the deck from MechaGuppyWaves.CREST_BY into its warning (metres).
const CREST_SHOWN: float = 1.0
## The run camera's horizontal view half-angle reckoned for "seen" (degrees: 51 at 16:9, 43 at 4:3).
const VIEW: float = 48.0

var sim: RunSim
var def: BossDef


func run() -> void:
	sim = RunSim.new(tree, tuning)
	var slot := load(BOSS_PATH) as BossDef
	def = slot if slot != null and slot.is_built() else null
	if def == null:
		check(false, "Mecha Guppy and Captain Cogs' fight loads")
		return
	_test_plan()
	_test_plan_tunables()
	_test_sounds()
	await _test_minute()
	for speed: float in SPEEDS:
		for lanes: int in LANES:
			await _test_live(lanes, speed)
	await _test_rounds_contact()
	await _test_waves_contact()
	await _test_retry()
	await _test_held_beats()
	await _test_bar()
	await _test_defeat()


# --- Helpers -------------------------------------------------------------------------------

func _movement(speed: float) -> MovementTuning:
	if is_equal_approx(speed, tuning.run_speed):
		return tuning
	var t: MovementTuning = tuning.duplicate() as MovementTuning
	t.run_speed = speed
	return t


## Phase 3 at `lanes` and `speed` m/s (as a checkpoint at phase 3 would start it: the climb's last steps, then the top),
## with `p_def` (the slot by default): [world, boss].
func _fight(lanes: int, speed: float, p_def: BossDef = null) -> Array:
	var d: BossDef = p_def if p_def != null else def
	var t: MovementTuning = _movement(speed)
	var boss := BossEncounter.create(d) as MechaGuppy
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = d
	ctx.config = BossArena.base_config(d)
	ctx.config.lane_count = lanes
	ctx.tuning = t
	ctx.boss_resume = {"phase": 2}
	var arena: BossArena = boss.plan_arena(ctx)
	var world: RunWorld = sim.build_world(arena.layout, null, t, ctx.config)
	boss.setup(world, ctx, arena)
	return [world, boss]


func _def_with(edit: Callable) -> BossDef:
	var out: BossDef = def.duplicate() as BossDef
	var t: MechaGuppyTuning = (def.tuning as MechaGuppyTuning).duplicate() as MechaGuppyTuning
	edit.call(t)
	out.tuning = t
	return out


func _events(boss: BossEncounter, event: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in boss.events:
		if e["event"] == event:
			out.append(e)
	return out


func _sounds(boss: BossEncounter, sound: StringName) -> Array[float]:
	var out: Array[float] = []
	for e: Dictionary in boss.events:
		if e["event"] == &"sound" and e["name"] == sound:
			out.append(float(e["t"]))
	return out


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


## Climbs to the top with a reading bot (the climb's last steps); true once the runner stands on it.
func _to_top(world: RunWorld, boss: MechaGuppy, bot: MechaGuppyBot) -> bool:
	await _run(world, 40.0, func() -> bool: return boss.top_reached_at >= 0.0, bot.step)
	return boss.top_reached_at >= 0.0


## The least time a round's balls or a wave's surge takes to reach the runner after its warning, by the plan's rule.
func _round_need(mt: MechaGuppyTuning) -> float:
	return mt.dodge_reaction + tuning.lane_switch_time + mt.dodge_margin


## A jump's time to rise clear of a wave's band (its feet over wave_height), on the run's movement.
func _jump_clear(height: float) -> float:
	var v: float = tuning.jump_velocity()
	var g: float = tuning.gravity()
	# v t - g t^2 / 2 = h, the first root.
	var disc: float = maxf(v * v - 2.0 * g * height, 0.0)
	return (v - sqrt(disc)) / g


# --- The script ------------------------------------------------------------------------------------

## MechaGuppyTop.plan at the defaults: the looped script, its spacing and its promises.
func _test_plan() -> void:
	var mt := def.tuning as MechaGuppyTuning
	var beats: Array[Dictionary] = MechaGuppyTop.plan(mt)
	check(beats.size() >= 15, "phase 3's minute holds the script's beats (%d)" % beats.size())
	var problem: String = _plan_problem(mt, beats)
	check(problem == "", "the script keeps its promises at the defaults%s" % ("" if problem == "" else ": " + problem))
	# The looped script: beats on the grid, the letters in order, the rounds' struck lanes alternating.
	var script: String = mt.top_script
	var grid_ok: bool = true
	var last_parity: int = 1
	var rounds: int = 0
	var waves: int = 0
	for b: Dictionary in beats:
		var k: int = int(b["k"])
		grid_ok = grid_ok and absf(float(b["at"]) - (mt.top_first + mt.top_beat * k)) < 0.001
		var letter: String = script[k % script.length()]
		grid_ok = grid_ok and ((letter == "R") == (b["kind"] == &"round"))
		if b["kind"] == &"round":
			grid_ok = grid_ok and int(b["parity"]) == 1 - last_parity
			last_parity = int(b["parity"])
			rounds += 1
		else:
			waves += 1
	check(grid_ok and rounds > 0 and waves > 0 and int(beats[0]["k"]) == 0,
		"the beats follow the looped script (%s) top_beat apart from top_first, the rounds' lanes alternating (%d rounds, %d waves)"
		% [script, rounds, waves])
	# No escalation: a beat a loop later is the same beat, the same gap later.
	var loop_ok: bool = true
	for b: Dictionary in beats:
		for c: Dictionary in beats:
			if int(c["k"]) == int(b["k"]) + script.length():
				loop_ok = loop_ok and c["kind"] == b["kind"] \
					and absf(float(c["at"]) - float(b["at"]) - mt.top_beat * script.length()) < 0.001
	check(loop_ok, "no escalation: every loop of the script plays the same beats at the same gaps")
	# Every other lane: always a lane clear, one switch from any lane.
	var lanes_ok: bool = true
	for lanes: int in [3, 4, 5, 6]:
		for parity: int in [0, 1]:
			var struck: Array[int] = MechaGuppyTop.struck(parity, lanes)
			lanes_ok = lanes_ok and not struck.is_empty() and struck.size() < lanes
			for lane: int in lanes:
				var near: bool = not struck.has(lane) or (lane > 0 and not struck.has(lane - 1)) \
					or (lane < lanes - 1 and not struck.has(lane + 1))
				lanes_ok = lanes_ok and near
	check(lanes_ok, "a round strikes every other lane: always a lane clear, one switch from any lane (3 to 6 lanes)")
	print("  Mecha Guppy's phase 3 script: %d beats (%d rounds, %d waves), the last over %.1f s into the minute; a round reaches the runner %.2f s after its warning, a wave %.2f s"
		% [beats.size(), rounds, waves, float(beats[-1]["ends"]), float(beats[0]["lead"]),
			mt.wave_warning + mt.wave_ahead / mt.wave_close])


## Why `beats` (plan(mt)) break the script's promises, or "".
func _plan_problem(mt: MechaGuppyTuning, beats: Array[Dictionary]) -> String:
	var last_end: float = -INF
	for b: Dictionary in beats:
		var at: float = float(b["at"])
		if at < mt.top_first - 0.001:
			return "a beat before top_first (%.2f s)" % at
		if at < last_end - 0.001:
			return "beat %d warns at %.2f s, before the last attack has passed (%.2f s)" % [int(b["k"]), at, last_end]
		if float(b["ends"]) > mt.top_seconds - mt.top_clear + 0.001:
			return "beat %d ends at %.2f s, past the minute's top_clear" % [int(b["k"]), float(b["ends"])]
		var lead: float = float(b["lead"])
		if b["kind"] == &"round":
			if lead < _round_need(mt) - 0.001:
				return "a round reaches the runner %.2f s after its warning (needs %.2f s)" % [lead, _round_need(mt)]
		elif lead < mt.dodge_reaction + _jump_clear(mt.wave_height) - 0.001:
			return "a wave reaches the runner %.2f s after its swell (needs %.2f s)" % [lead, mt.dodge_reaction + _jump_clear(mt.wave_height)]
		last_end = float(b["ends"])
	return ""


## Every phase 3 tunable (MechaGuppyTuning.TOP_TUNABLES with a range) at both ends of its range keeps the plan's
## promises; and the wave's band stays jumpable, the cannonball too tall to jump.
func _test_plan_tunables() -> void:
	var base := def.tuning as MechaGuppyTuning
	var bad: Array[String] = []
	var tried: int = 0
	for prop: Dictionary in base.get_property_list():
		var name: String = String(prop["name"])
		if not MechaGuppyTuning.TOP_TUNABLES.has(name) or int(prop["hint"]) != PROPERTY_HINT_RANGE:
			continue
		var parts: PackedStringArray = String(prop["hint_string"]).split(",")
		for v: float in [float(parts[0]), float(parts[1])]:
			var t: MechaGuppyTuning = base.duplicate() as MechaGuppyTuning
			t.set(name, v)
			tried += 1
			var beats: Array[Dictionary] = MechaGuppyTop.plan(t)
			var problem: String = _plan_problem(t, beats)
			if problem != "":
				bad.append("%s=%s: %s" % [name, v, problem])
			if beats.is_empty() and t.top_seconds > t.top_first + 6.0:
				bad.append("%s=%s: no beat at all" % [name, v])
			var ball_top: float = t.round_radius * 2.0 * MechaGuppyRounds.HIT_HEIGHT
			if ball_top < tuning.jump_height + 0.1:
				bad.append("%s=%s: a jump clears the cannonball (%.2f m)" % [name, v, ball_top])
			if t.wave_height > tuning.jump_height * 0.5:
				bad.append("%s=%s: the wave is no low band (%.2f m)" % [name, v, t.wave_height])
	check(tried >= 30 and bad.is_empty(), "every phase 3 tunable at both ends of its range keeps the script's promises (%d tried)%s"
		% [tried, "" if bad.is_empty() else ": " + "; ".join(bad.slice(0, 4))])


## Phase 3's sounds: in the library, the warnings as long as their warnings and the same every time.
func _test_sounds() -> void:
	var library := load("res://data/audio/sfx_library.tres") as SfxLibrary
	var missing: Array[String] = []
	for sound: StringName in [&"cogs_charge", &"cogs_cannon", &"wave_swell", &"wave_crash", &"guppy_leap", &"guppy_gulp",
			&"guppy_swim"]:
		if library.stream(sound) == null or not library.volume_db.has(String(sound)):
			missing.append(String(sound))
	check(missing.is_empty(), "phase 3's and the defeat's sounds are in the library (%s missing)" % [missing])
	var mt := def.tuning as MechaGuppyTuning
	var charge: AudioStream = library.stream(&"cogs_charge")
	var swell: AudioStream = library.stream(&"wave_swell")
	check(charge != null and absf(charge.get_length() - mt.round_warning) < 0.02 and swell != null
		and absf(swell.get_length() - mt.wave_warning) < 0.02,
		"the cannons' charge lasts the round's warning (%.2f s) and the swell's roar the wave's (%.2f s)"
		% [charge.get_length() if charge != null else 0.0, swell.get_length() if swell != null else 0.0])
	check(not library.pitch_variation.has("cogs_charge") and not library.pitch_variation.has("wave_swell"),
		"the warnings sound exactly the same every time (no pitch variation)")


# --- The minute and the bar --------------------------------------------------------------------------

## The minute counts from top_reached; the boss bar runs down over it, the fight won as it ends; the ship comes level.
func _test_minute() -> void:
	var pair: Array = _fight(5, 23.8)
	var world: RunWorld = pair[0]
	var boss: MechaGuppy = pair[1]
	var p: Player = world.player
	var mt: MechaGuppyTuning = boss.tuning
	var bot := MechaGuppyBot.new(boss)
	bot.reaction = REACTION
	var reached: bool = await _to_top(world, boss, bot)
	check(reached and boss.top.started() and is_equal_approx(boss.top.began_at, boss.top_reached_at),
		"the minute begins as the runner reaches the top (%.1f s)" % boss.top_reached_at)
	if not reached:
		await sim.free_world(world)
		return
	var full: float = boss.phase_start_health(2)
	check(absf(boss.health - full) < 0.01 * boss.max_health, "the bar starts phase 3's minute full (%.3f of %.3f)"
		% [boss.health_ratio(), full / boss.max_health])
	check(not boss.register_hit() and boss.phase_index == 2, "hits don't end phase 3 (GDD §10: a minute of dodging does)")
	var samples: Array = []
	var level := {"ok": true, "level_at": -1.0, "seen": false}
	var ship: CaptainCogsShip = boss.ship
	await _run(world, mt.top_seconds + 2.0, func() -> bool: return boss.is_defeated(), func() -> void:
		bot.step()
		var e: float = boss.fight_time() - boss.top_reached_at
		if samples.size() < 6 and e >= float(samples.size()) * 10.0 + 5.0:
			samples.append([e, boss.health])
		if ship.is_level() and float(level["level_at"]) < 0.0:
			level["level_at"] = e
			# Alongside the top at the runner's height, ahead of them, outside the roof's eaves.
			var at: Vector3 = ship.global_position
			var inner: float = absf(at.x) - CaptainCogsModel.BEAM * 0.5
			level["ok"] = absf(at.y - (p.floor_base + mt.level_keel)) < 0.6 and inner > world.geo.wall_x() + MechaGuppyLooks.EAVE_REACH \
				and absf(-at.z - p.distance - mt.level_ahead) < 0.5)
	var bar_ok: bool = samples.size() >= 5
	for s: Array in samples:
		var want: float = full * (1.0 - float(s[0]) / mt.top_seconds)
		bar_ok = bar_ok and absf(float(s[1]) - want) < 0.01 * boss.max_health
	check(bar_ok, "the boss bar runs down over the minute (GDD §10, proposed): %s" % [samples.map(func(s: Array) -> String:
		return "%.0f s %.3f" % [float(s[0]), float(s[1]) / boss.max_health])])
	var over: Array[Dictionary] = _events(boss, &"top_over")
	check(boss.is_defeated() and over.size() == 1 and absf(float(over[0]["t"]) - boss.top_reached_at - mt.top_seconds) < FRAME * 2.0,
		"the fight is won as the minute ends, %.0f s after the top is reached, not before (%s)" % [mt.top_seconds,
			"%.2f s" % (float(over[0]["t"]) - boss.top_reached_at) if over.size() == 1 else "none"])
	check(float(level["level_at"]) > 0.0 and float(level["level_at"]) <= mt.level_seconds + 0.1 and bool(level["ok"]),
		"the ship comes level alongside the top in %.1f s: at the runner's height, ahead of them, clear of the eaves"
		% float(level["level_at"]))
	await sim.free_world(world)


# --- The rounds and the waves, live ------------------------------------------------------------------

## The dodging runner through the minute (see the header), every warning seen and heard before its attack.
func _test_live(lanes: int, speed: float) -> void:
	var tag: String = "(%d lanes, %.1f m/s)" % [lanes, speed]
	var pair: Array = _fight(lanes, speed)
	var world: RunWorld = pair[0]
	var boss: MechaGuppy = pair[1]
	var p: Player = world.player
	var mt: MechaGuppyTuning = boss.tuning
	var bot := MechaGuppyBot.new(boss)
	bot.reaction = REACTION
	var hurt: Array[int] = [0]
	p.item_used.connect(func(_item: StringName) -> void: hurt[0] += 1)
	var reached: bool = await _to_top(world, boss, bot)
	if not reached:
		check(false, "the runner reaches the top %s" % tag)
		await sim.free_world(world)
		return
	var problems: Array[String] = []
	var seen: Dictionary = {}
	var crests: Dictionary = {}
	await _run(world, mt.top_seconds + 2.0, func() -> bool: return boss.is_defeated(), func() -> void:
		bot.step()
		# A round's red lines down exactly the lanes it strikes, on the top's deck, while it warns.
		for r: Dictionary in boss.top.rounds.rounds:
			var k: int = int(r["k"])
			if seen.has(k) or int(r["state"]) != MechaGuppyRounds.State.WARN:
				continue
			seen[k] = true
			for lane: int in lanes:
				var lined: bool = boss.props.warned(lane, float(r["d_meet"]), float(r["d_land"]), float(r["y"]))
				if lined != (r["lanes"] as Array).has(lane):
					problems.append("round %d: lane %d %s" % [k, lane, "lined but not struck" if lined else "struck but not lined"])
		# A wave's swell rising beside the top while it warns, its crest over the deck's edge early in the warning.
		for w: Dictionary in boss.top.waves.waves:
			if int(w["state"]) == MechaGuppyWaves.State.SWELL:
				var swell: MeshInstance3D = w["swell"]
				if swell == null or not swell.visible or swell.global_position.x * float(MechaGuppyWaves.WAVE_SIDE) < world.geo.wall_x() - 0.01:
					problems.append("wave %d warns without its swell beside the top" % int(w["k"]))
				var into: float = boss.top.waves.clock - float(w["start"])
				var crest: float = boss.top.waves.crest_above(w)
				if crest > 0.0 and not crests.has(int(w["k"])):
					crests[int(w["k"])] = into
				if into >= MechaGuppyWaves.CREST_BY and crest < CREST_SHOWN:
					problems.append("wave %d's crest %.2f m over the deck %.2f s into its warning" % [int(w["k"]), crest, into]))
	check(boss.is_defeated() and p.alive and hurt[0] == 0,
		"the dodging runner lives through the minute untouched, and the fight is won %s%s" % [tag,
			"" if p.alive else " (died at %.1f s)" % boss.fight_time()])
	var crest_by: float = 0.0
	for k: int in crests:
		crest_by = maxf(crest_by, float(crests[k]))
	check(problems.is_empty() and crests.size() == _events(boss, &"wave").size(),
		"every round lines exactly its lanes, every wave's swell rises beside the top as it warns, its crest over the deck by %.2f s (at most %.2f s) %s%s"
		% [crest_by, MechaGuppyWaves.CREST_BY, tag, "" if problems.is_empty() else ": " + "; ".join(problems.slice(0, 3))])
	# The beats as planned, each warned (seen and heard) its lead before its attack, none over another.
	var plan: Array[Dictionary] = MechaGuppyTop.plan(mt)
	var rounds: Array[Dictionary] = _events(boss, &"round")
	var waves: Array[Dictionary] = _events(boss, &"wave")
	var charges: Array[float] = _sounds(boss, &"cogs_charge")
	var swells: Array[float] = _sounds(boss, &"wave_swell")
	var t0: float = boss.top_reached_at
	var timing_ok: bool = rounds.size() + waves.size() == plan.size() and charges.size() == rounds.size() \
		and swells.size() == waves.size()
	for e: Dictionary in rounds + waves:
		var beat: Dictionary = {}
		for b: Dictionary in plan:
			if int(b["k"]) == int(e["k"]):
				beat = b
		timing_ok = timing_ok and not beat.is_empty() and absf(float(e["t"]) - t0 - float(beat.get("at", -9.0))) < FRAME
	var lead_ok: bool = true
	for e: Dictionary in rounds:
		lead_ok = lead_ok and float(e["warning"]) >= _round_need(mt) and charges.has(float(e["t"]))
		var struck: Array = e["lanes"]
		lead_ok = lead_ok and struck.size() < lanes
	for e: Dictionary in waves:
		lead_ok = lead_ok and float(e["warning"]) >= mt.dodge_reaction + _jump_clear(mt.wave_height) and swells.has(float(e["t"]))
	var passed: Array[Dictionary] = _events(boss, &"round_passed") + _events(boss, &"wave_passed")
	var apart: bool = passed.size() == rounds.size() + waves.size()
	for e: Dictionary in rounds + waves:
		for q: Dictionary in passed:
			# The beat before this one has passed before this one warns.
			if int(q["k"]) < int(e["k"]) and float(q["t"]) > float(e["t"]) + FRAME:
				apart = false
	check(timing_ok, "the beats come as planned, timed from the top (%d rounds, %d waves of %d beats) %s"
		% [rounds.size(), waves.size(), plan.size(), tag])
	check(lead_ok, "every round warned with its red lines and the cannons' charge, every wave with its swell and roar, long enough before %s" % tag)
	check(apart, "no beat warns before the last one's attack has passed the runner (never a jump and a switch at once) %s" % tag)
	check(bot.top_jumps == waves.size() and bot.top_switches >= rounds.size() - 1,
		"the waves jumped (%d of %d), the rounds dodged by switching lanes (%d switches for %d rounds) %s"
		% [bot.top_jumps, waves.size(), bot.top_switches, rounds.size(), tag])
	print("  Mecha Guppy's phase 3 %s: the top reached at %.1f s, %d rounds and %d waves, %d switches and %d jumps, won at %.1f s"
		% [tag, t0, rounds.size(), waves.size(), bot.top_switches, bot.top_jumps, boss.fight_time()])
	await sim.free_world(world)


# --- Real contact --------------------------------------------------------------------------------

## A world on the top, the script off (MechaGuppy.attacks_enabled: the beats wait), the runner in lane `lane`, still
## running: [world, boss], or [] if the top isn't reached.
func _on_top(lanes: int, speed: float, lane: int) -> Array:
	var pair: Array = _fight(lanes, speed)
	var world: RunWorld = pair[0]
	var boss: MechaGuppy = pair[1]
	var bot := MechaGuppyBot.new(boss)
	bot.reaction = REACTION
	if not await _to_top(world, boss, bot):
		await sim.free_world(world)
		return []
	boss.attacks_enabled = false
	var p: Player = world.player
	# On along the top until it's full width (its lanes that led up reach back further), with nothing picked up on the
	# climb (the armor rule's armor) or waiting ahead.
	var roof: MechaGuppyClimb.Roof = boss.climb.roofs[-1]
	await _run(world, 5.0, func() -> bool: return p.distance > roof.full_from() + 2.0)
	world.pickups.clear()
	p.armor = 0
	p.shield = 0
	for i: int in 8:
		if p.lane == lane:
			break
		p.press(&"move_right" if lane > p.lane else &"move_left")
		await physics_frames(int(tuning.lane_switch_time * 60.0) + 2)
	await physics_frames(10)
	return pair


func _test_rounds_contact() -> void:
	for mode: String in ["stay", "jump", "switch", "beside", "armor", "shield", "dash"]:
		var pair: Array = await _on_top(3, 18.0, 1)
		if pair.is_empty():
			check(false, "the runner reaches the top (%s)" % mode)
			continue
		var world: RunWorld = pair[0]
		var boss: MechaGuppy = pair[1]
		var p: Player = world.player
		var mt: MechaGuppyTuning = boss.tuning
		var cause: Array[String] = [""]
		p.died.connect(func(c: String) -> void: cause[0] = c)
		var used: Array[StringName] = []
		p.item_used.connect(func(item: StringName) -> void: used.append(item))
		match mode:
			"armor":
				p.armor = 1
			"shield":
				p.shield = 1
		var target: int = 0 if mode == "beside" else p.lane
		var lanes: Array[int] = [target]
		var r: Dictionary = boss.top.rounds.fire(0, lanes)
		var st: Dictionary = {"acted": false, "rules": false}
		await _run(world, 3.0, func() -> bool: return int(r["state"]) == MechaGuppyRounds.State.DONE, func() -> void:
			var rounds: MechaGuppyRounds = boss.top.rounds
			var to_meet: float = float(r["meet"]) - rounds.clock
			if not bool(st["acted"]):
				if mode == "switch" and rounds.clock - float(r["start"]) >= REACTION:
					st["acted"] = true
					p.press(&"move_right")
				elif mode == "jump" and to_meet <= 0.3:
					st["acted"] = true
					p.press(&"jump")
				elif mode == "dash" and to_meet <= 0.15:
					st["acted"] = true
					p.start_dash(0.6, 0.0)
			var live: Array[Hazard] = rounds.ball_hazards()
			if not live.is_empty() and not bool(st["rules"]):
				st["rules"] = true
				var h: Hazard = live[0]
				var d := DamageRules.Defense.new()
				var ok: bool = DamageRules.resolve(h, d) == DamageRules.Outcome.KILL
				d.armor = true
				ok = ok and DamageRules.resolve(h, d) == DamageRules.Outcome.BLOCKED_ARMOR
				d.armor = false
				d.shield = true
				ok = ok and DamageRules.resolve(h, d) == DamageRules.Outcome.BLOCKED_SHIELD
				d.shield = false
				d.dashing = true
				ok = ok and DamageRules.resolve(h, d) == DamageRules.Outcome.IGNORE
				var ball: float = mt.round_radius * 2.0
				check(ok and h.is_enemy_attack and h.size.y > tuning.jump_height + 0.1 and h.size.y < ball
					and h.size.x < ball and h.size.x < world.geo.lane_width and absf(h.global_position.y - h.size.y * 0.5 - p.floor_base) < 0.05,
					"a cannonball's hitbox: an enemy attack (armor and the shield block it, the dash passes), too tall to jump (%.2f m), smaller than the ball, on the deck"
					% h.size.y))
		match mode:
			"stay":
				check(not p.alive and cause[0] == MechaGuppyRounds.BALL_NAME,
					"a cannonball kills a runner who stays in its lane (%s)" % cause[0])
			"jump":
				check(not p.alive and cause[0] == MechaGuppyRounds.BALL_NAME,
					"and one who jumps it: it's too tall to jump (%s)" % cause[0])
			"switch":
				check(p.alive and used.is_empty() and p.lane == 2, "a switch out of its lane, a reaction after its warning, dodges it")
			"beside":
				check(p.alive and used.is_empty(), "it never touches a runner a lane away (real contact only)")
			"armor":
				check(p.alive and used.has(&"armor"), "armor blocks it (the armor spent: %s)" % [used])
			"shield":
				check(p.alive and used.has(&"shield"), "the shield blocks it (%s)" % [used])
			"dash":
				check(p.alive and used.is_empty(), "the dash passes through it (%s)" % cause[0])
		await sim.free_world(world)


func _test_waves_contact() -> void:
	for mode: String in ["stay", "jump", "armor", "shield", "dash"]:
		var pair: Array = await _on_top(3, 23.8, 1)
		if pair.is_empty():
			check(false, "the runner reaches the top (%s)" % mode)
			continue
		var world: RunWorld = pair[0]
		var boss: MechaGuppy = pair[1]
		var p: Player = world.player
		var mt: MechaGuppyTuning = boss.tuning
		var cause: Array[String] = [""]
		p.died.connect(func(c: String) -> void: cause[0] = c)
		var used: Array[StringName] = []
		p.item_used.connect(func(item: StringName) -> void: used.append(item))
		match mode:
			"armor":
				p.armor = 1
			"shield":
				p.shield = 1
		var w: Dictionary = boss.top.waves.start(0)
		var st: Dictionary = {"acted": false, "rules": false}
		await _run(world, 4.0, func() -> bool: return int(w["state"]) == MechaGuppyWaves.State.DONE, func() -> void:
			var waves: MechaGuppyWaves = boss.top.waves
			if int(w["state"]) == MechaGuppyWaves.State.ROLL and not bool(st["acted"]):
				var front: float = MechaGuppyWaves.surge_d(w, waves.clock) - mt.wave_depth * 0.5
				var to_reach: float = (front - p.distance - tuning.hurtbox_size.z * 0.5) / (float(w["speed"]) + p.speed)
				if mode == "jump" and to_reach <= MechaGuppyBot.JUMP_LEAD:
					st["acted"] = true
					p.press(&"jump")
				elif mode == "dash" and to_reach <= 0.15:
					st["acted"] = true
					p.start_dash(0.6, 0.0)
			var live: Array[Hazard] = waves.band_hazards()
			if not live.is_empty() and not bool(st["rules"]):
				st["rules"] = true
				var h: Hazard = live[0]
				var d := DamageRules.Defense.new()
				var ok: bool = DamageRules.resolve(h, d) == DamageRules.Outcome.KILL
				d.armor = true
				ok = ok and DamageRules.resolve(h, d) == DamageRules.Outcome.BLOCKED_ARMOR
				d.armor = false
				d.shield = true
				ok = ok and DamageRules.resolve(h, d) == DamageRules.Outcome.BLOCKED_SHIELD
				d.shield = false
				d.dashing = true
				ok = ok and DamageRules.resolve(h, d) == DamageRules.Outcome.IGNORE
				check(ok and h.is_enemy_attack and is_equal_approx(h.size.y, mt.wave_height) and h.size.y < tuning.jump_height * 0.5
					and h.size.x >= world.geo.half_width() * 2.0 - 0.2,
					"a wave's surge: an enemy attack across every lane (armor and the shield block it, the dash passes), a low band (%.2f m: a jump clears it)"
					% h.size.y))
		match mode:
			"stay":
				check(not p.alive and cause[0] == MechaGuppyWaves.WAVE_NAME, "a wave kills a runner who doesn't jump it (%s)" % cause[0])
			"jump":
				check(p.alive and used.is_empty(), "a normal jump clears it, like the Resonator's ring (%s)" % cause[0])
			"armor":
				check(p.alive and used.has(&"armor"), "armor blocks it (%s)" % [used])
			"shield":
				check(p.alive and used.has(&"shield"), "the shield blocks it (%s)" % [used])
			"dash":
				check(p.alive and used.is_empty(), "the dash passes through it (%s)" % cause[0])
		await sim.free_world(world)


# --- A retry ----------------------------------------------------------------------------------------

## Two attempts play phase 3 the same: the same beats at the same moments from the top, the same lanes struck.
func _test_retry() -> void:
	var logs: Array[String] = []
	for attempt: int in 2:
		var pair: Array = _fight(6, 23.8)
		var world: RunWorld = pair[0]
		var boss: MechaGuppy = pair[1]
		var bot := MechaGuppyBot.new(boss)
		bot.reaction = REACTION
		await _run(world, 120.0, func() -> bool: return boss.is_defeated(), bot.step)
		var lines: PackedStringArray = []
		for e: Dictionary in boss.events:
			if e["event"] in [&"round", &"wave", &"round_shot", &"wave_crash", &"top_over"]:
				lines.append("%s %.3f %s" % [e["event"], float(e["t"]) - boss.top_reached_at, e.get("lanes", [])])
		logs.append(";".join(lines))
		await sim.free_world(world)
	check(logs[0] != "" and logs[0] == logs[1], "a retry plays phase 3 the same: the same beats at the same moments, the same lanes")


# --- Held beats -------------------------------------------------------------------------------------

## Beats held back (the pattern off for a while after the top is reached, as phase 3's intro would) start late, one at a
## time, each keeping its gap after the last (task E5e-c's review: every overdue beat used to start in the same step, two
## rounds of opposite lanes striking every lane between them); the runner still dodges them all.
func _test_held_beats() -> void:
	var pair: Array = _fight(5, 23.8)
	var world: RunWorld = pair[0]
	var boss: MechaGuppy = pair[1]
	var mt: MechaGuppyTuning = boss.tuning
	var bot := MechaGuppyBot.new(boss)
	bot.reaction = REACTION
	var hurt: Array[int] = [0]
	world.player.item_used.connect(func(_item: StringName) -> void: hurt[0] += 1)
	if not await _to_top(world, boss, bot):
		check(false, "the runner reaches the top (held beats)")
		await sim.free_world(world)
		return
	# Three beats overdue when the pattern comes back.
	boss.attacks_enabled = false
	var held: float = mt.top_first + mt.top_beat * 2.5
	await _run(world, held, func() -> bool: return false, bot.step)
	var released: float = boss.fight_time()
	boss.attacks_enabled = true
	await _run(world, 12.0, func() -> bool: return false, bot.step)
	var starts: Array[Dictionary] = _events(boss, &"round") + _events(boss, &"wave")
	starts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["k"]) < int(b["k"]))
	var planned: Dictionary = {}
	for b: Dictionary in MechaGuppyTop.plan(mt):
		planned[int(b["k"])] = float(b["at"])
	var ok: bool = starts.size() >= 3 and absf(float(starts[0]["t"]) - released) < FRAME * 2.0
	for i: int in range(1, starts.size()):
		var gap: float = float(planned.get(int(starts[i]["k"]), INF)) - float(planned.get(int(starts[i - 1]["k"]), 0.0))
		ok = ok and float(starts[i]["t"]) - float(starts[i - 1]["t"]) >= gap - FRAME
	check(ok and world.player.alive and hurt[0] == 0,
		"beats held back start late, one at a time, each its planned gap after the last (%d beats from %.1f s, %.1f s late), dodged untouched"
		% [starts.size(), released - boss.top_reached_at, boss.top.late])
	await sim.free_world(world)


# --- The boss bar ------------------------------------------------------------------------------------

## The boss bar (BossBar) through phase 3's minute at 30, 50 and 60 rendered frames a second (task E5e-c's review: below
## about 55 fps every rendered frame's drop re-armed the white segment's hold, so it never drained): its white segment
## follows the red fill down (BossEncounter.health_runs_down); and a hit's white segment (every other boss's, and this
## one's in phases 1 and 2) still holds a moment before it drains.
func _test_bar() -> void:
	var pair: Array = _fight(5, 23.8)
	var world: RunWorld = pair[0]
	var boss: MechaGuppy = pair[1]
	var bot := MechaGuppyBot.new(boss)
	bot.reaction = REACTION
	check(not boss.health_runs_down(), "the bar's health doesn't run down before the top (hits show their white segment)")
	if not await _to_top(world, boss, bot):
		check(false, "the runner reaches the top (the bar)")
		await sim.free_world(world)
		return
	var rates: Array[float] = [30.0, 50.0, 60.0]
	var bars: Array[BossBar] = []
	var acc: Array[float] = []
	var worst: Array[float] = []
	for fps: float in rates:
		var bar := BossBar.new()
		tree.root.add_child(bar)
		bar.set_process(false)
		bar.bind(boss)
		bars.append(bar)
		acc.append(0.0)
		worst.append(0.0)
	var start_ratio: float = boss.health_ratio()
	await _run(world, 25.0, func() -> bool: return boss.is_defeated(), func() -> void:
		bot.step()
		for i: int in bars.size():
			acc[i] += 1.0 / Engine.physics_ticks_per_second
			var dt: float = 1.0 / rates[i]
			while acc[i] >= dt - 0.00001:
				acc[i] -= dt
				bars[i]._process(dt)
			if boss.fight_time() - boss.top_reached_at > 1.0:
				worst[i] = maxf(worst[i], bars[i].drain_value() - bars[i].value))
	var drained: bool = boss.health_runs_down() and boss.health_ratio() < start_ratio - 0.1
	for w: float in worst:
		drained = drained and w < 0.005
	check(drained, "through the minute the bar's white segment drains with the red at 30, 50 and 60 fps (at most %s of the bar behind; the red went from %.3f to %.3f)"
		% [worst.map(func(w: float) -> String: return "%.4f" % w), start_ratio, boss.health_ratio()])
	for bar: BossBar in bars:
		bar.queue_free()
	# A hit (no steady run-down): the white segment holds DRAIN_DELAY, then drains.
	var hit := BossBar.new()
	tree.root.add_child(hit)
	hit.set_process(false)
	hit.set_state(0.8, PackedFloat32Array(), true, "")
	hit._process(0.5)
	hit._process(1.0)
	hit.set_state(0.7, PackedFloat32Array(), true, "")
	hit._process(1.0 / 30.0)
	var held: bool = is_equal_approx(hit.drain_value(), 0.8)
	for i: int in int(BossBar.DRAIN_DELAY * 30.0) + 6:
		hit._process(1.0 / 30.0)
	check(held and hit.drain_value() < 0.8 - 0.01, "a hit's white segment still holds %.1f s before draining (%.3f after)"
		% [BossBar.DRAIN_DELAY, hit.drain_value()])
	hit.queue_free()
	await sim.free_world(world)


# --- The defeat -------------------------------------------------------------------------------------

## True if the run camera (where RunCamera puts it for the runner now: MovementTuning's camera numbers) sees world point
## `q`: ahead of it within VIEW degrees of its forward axis, and not under its line past the deck's edge (the coping,
## MechaGuppyLeap.KERB) on q's side.
func _seen(world: RunWorld, q: Vector3) -> bool:
	var p: Player = world.player
	var mt: MovementTuning = world.tuning
	var cam := Vector3(p.position.x * mt.camera_follow_x, p.floor_base + mt.camera_height, p.position.z + mt.camera_distance)
	var rel: Vector3 = q - cam
	if rel.z >= 0.0 or rad_to_deg(atan2(absf(rel.x), -rel.z)) > VIEW:
		return false
	var side: float = signf(q.x)
	var edge: float = side * (world.geo.wall_x() + MechaGuppyLeap.KERB.x)
	if absf(q.x) <= absf(edge) or absf(rel.x) < 0.001:
		return true
	var y_at: float = cam.y + rel.y * (edge - cam.x) / rel.x
	return y_at > p.floor_base + MechaGuppyLeap.KERB.y


## The leap (see the header), with a short minute, at 3 and 6 lanes.
func _test_defeat() -> void:
	for lanes: int in [3, 6]:
		var tag: String = "(%d lanes)" % lanes
		var quick: BossDef = _def_with(func(t: MechaGuppyTuning) -> void: t.top_seconds = 6.0)
		var pair: Array = _fight(lanes, 23.8, quick)
		var world: RunWorld = pair[0]
		var boss: MechaGuppy = pair[1]
		var p: Player = world.player
		var mt: MechaGuppyTuning = boss.tuning
		var bot := MechaGuppyBot.new(boss)
		bot.reaction = REACTION
		await _run(world, 60.0, func() -> bool: return boss.is_defeated(), bot.step)
		check(boss.is_defeated() and boss.leap != null and not boss.victory_over() and not boss.victory_riff(),
			"the minute up, Mecha Guppy leaps; the results wait, and no riff at the defeat itself %s" % tag)
		if boss.leap == null:
			await sim.free_world(world)
			continue
		var leap: MechaGuppyLeap = boss.leap
		# The lanes and the top's eaves beside them.
		var half: float = world.geo.half_width() + MechaGuppyLooks.EAVE_REACH
		var st: Dictionary = {"over_lanes": 0, "hazards": 0, "max_y": -INF, "air": 0, "seen": 0, "top_y": -INF,
			"top_seen": false, "top_body": 0, "plume": 0.0, "plume_seen": false, "shore": [], "over_at": -1.0}
		await _run(world, LevelRun.BOSS_VICTORY_MAX + 4.0, func() -> bool:
			return leap.step == MechaGuppyLeap.Step.GONE and leap.over() and not leap.plumes[1].playing(), func() -> void:
			bot.step()
			var points: PackedVector3Array = boss.shark.jaws_points()
			points.append_array(boss.shark.body_points())
			for q: Vector3 in points:
				if absf(q.x) < half and q.y > p.floor_base - 6.0:
					st["over_lanes"] = int(st["over_lanes"]) + 1
				st["max_y"] = maxf(float(st["max_y"]), q.y)
			var live: int = boss.top.rounds.ball_hazards().size() + boss.top.waves.band_hazards().size() + boss.bombs.blast_hazards().size()
			st["hazards"] = int(st["hazards"]) + live
			if boss.victory_over() and float(st["over_at"]) < 0.0:
				st["over_at"] = leap.time
			# The breach, from its snout breaking the sea to its dive: the hinge seen by the run camera.
			if leap.marks.has("surface") and not leap.marks.has("dive") and leap.step == MechaGuppyLeap.Step.BREACH:
				var hinge: Vector3 = boss.shark.head_transform().origin
				st["air"] = int(st["air"]) + 1
				if _seen(world, hinge):
					st["seen"] = int(st["seen"]) + 1
				if hinge.y > float(st["top_y"]):
					st["top_y"] = hinge.y
					st["top_seen"] = _seen(world, hinge)
					var body: int = 0
					for q: Vector3 in boss.shark.body_points():
						body += 1 if _seen(world, q) else 0
					st["top_body"] = body
			# Where it breaks the sea and dives back in: past the shoreline.
			for i: int in 2:
				var mark: String = "surface" if i == 0 else "dive"
				if leap.marks.has(mark) and (st["shore"] as Array).size() == i:
					var tip: Vector3 = leap.snout()
					(st["shore"] as Array).append(absf(tip.x) - world.geo.wall_x() - BeachOpen.shore(int(signf(tip.x)), -tip.z))
			# The dive's plume at its tallest: seen.
			var plume: MechaGuppySplash = leap.plumes[1]
			if plume.playing() and plume.standing() > float(st["plume"]):
				st["plume"] = plume.standing()
				st["plume_seen"] = _seen(world, plume.global_position + Vector3(0.0, plume.standing(), 0.0)))
		var marks: Dictionary = leap.marks
		var order: bool = true
		var last: float = -1.0
		for key: String in ["rise", "gulp", "fall", "breach", "surface", "dive", "over"]:
			order = order and marks.has(key) and float(marks[key]) >= last
			last = float(marks.get(key, -1.0))
		check(order and boss.victory_over() and absf(float(marks["gulp"]) - mt.leap_rise) < FRAME * 2.0
			and absf(float(marks["over"]) - float(marks["dive"]) - mt.dive_after) < FRAME * 2.0
			and float(marks["over"]) <= leap.over_by() + FRAME * 2.0 and is_equal_approx(leap.over_by(), MechaGuppyLeap.seconds_to_over(mt))
			and absf(float(st["over_at"]) - float(marks["over"])) < FRAME * 2.0 and float(marks["over"]) < LevelRun.BOSS_VICTORY_MAX
			and marks.has("gone"),
			"it bursts up, gulps at %.2f s, falls back, breaches out at sea at %.2f s and dives back in at %.2f s; the results may follow %.1f s after the win (at most %.0f s), and it's gone at %.1f s %s"
			% [float(marks.get("gulp", -1.0)), float(marks.get("surface", -1.0)), float(marks.get("dive", -1.0)),
				float(marks.get("over", -1.0)), LevelRun.BOSS_VICTORY_MAX, float(marks.get("gone", -1.0)), tag])
		var ship: CaptainCogsShip = boss.ship
		check(ship.swallowed and not ship.rig.visible and ship.wreck() != null,
			"the gulp: the captain and the ship's stern half swallowed, the bow half broken away %s" % tag)
		check(float(st["max_y"]) > p.floor_base + 4.0, "it rises above the top, where the camera sees it (%.1f m over the deck) %s"
			% [float(st["max_y"]) - p.floor_base, tag])
		var seen_share: float = float(st["seen"]) / maxf(float(st["air"]), 1.0)
		check(bool(st["top_seen"]) and int(st["top_body"]) >= 3 and seen_share >= 0.6 and bool(st["plume_seen"]),
			"the swim away is seen by the run camera over the deck's edge: the breach's hinge %.0f%% of its leap, at its top its head and the front of its body (%d of 7 points along it: the rest, toward the runner, out of the view's side), and the dive's plume (%.0f m tall) %s"
			% [seen_share * 100.0, int(st["top_body"]), float(st["plume"]), tag])
		var shore: Array = st["shore"]
		check(shore.size() == 2 and float(shore[0]) > 4.0 and float(shore[1]) > 4.0,
			"out at sea: from this low top the camera sees the sea's surface, and it breaks the sea and dives back in past the shoreline (%s m past it) %s"
			% [shore.map(func(m: float) -> String: return "%.0f" % m), tag])
		check(int(st["over_lanes"]) == 0, "nothing of its jaws or its body ever over the lanes or the top's eaves (%d points) %s" % [st["over_lanes"], tag])
		check(int(st["hazards"]) == 0 and p.alive, "nothing in the leap can hurt the runner: no hazard live after the win %s" % tag)
		var riff: Array[Dictionary] = _events(boss, &"riff")
		check(riff.size() == (1 if mt.victory_riff_on else 0) and _sounds(boss, &"guppy_gulp").size() == 1
			and _sounds(boss, &"guppy_leap").size() == 2 and _sounds(boss, &"guppy_swim").size() == 1,
			"the leap and the breach roar, the gulp and the dive's splash heard, the victory riff after the gulp %s" % tag)
		print("  Mecha Guppy's defeat %s: the breach %.0f m out, %.0f m ahead, %.0f m over the sea (the camera's line past the deck's edge reckoned from %.0f m out); seen %.0f%% of its leap; the results may follow %.2f s after the win"
			% [tag, float(leap.breach["out"]), float(leap.breach["ahead"]), float(leap.breach["high"]), float(leap.breach["seen"]),
				seen_share * 100.0, float(marks.get("over", -1.0))])
		await sim.free_world(world)

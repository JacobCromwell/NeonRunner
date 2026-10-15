extends TestSuite
## Phase 3 of Mecha Guppy and Captain Cogs, "Level with Captain Cogs", and the defeat (GDD §10; tasks E5e-c and E5e-g: the
## owner's rework, October 15, 2026), on real physics (MechaGuppyTop, MechaGuppyBarrage, MechaGuppyWaves, MechaGuppyShark's
## watch, dive and splash, the top's floor bites, MechaGuppyLeap; the whole fight: test_mecha_guppy_whole):
## - the bombs' shape, at the defaults and with every phase 3 tunable at both ends of its range: a low bomb's hitbox under a
##   jump's feet with time to spare as it crosses the runner's lane, over a slide's hurtbox's top (a slide doesn't pass
##   it); a high bomb's over a slide's hurtbox and under a standing one's top (a jump doesn't clear it); its warning a
##   reaction and a jump's rise before it can reach the nearest lane; the barrage script's words;
## - live at 3, 5 and 6 lanes and 18 and 23.8 m/s, a reading runner (MechaGuppyBot, the planner's reaction) wins phase 3
##   untouched: Captain Cogs' ship level on the left and Mecha Guppy in its watch on the right, both in the run camera's
##   view (the captain and the shark's head); every bomb warned (its red line across the lanes at its height, the cannon's
##   charge) its warning before the shot, never before the last has passed the runner; every low bomb jumped, every high
##   one slid under; every bomb past the runner hits Mecha Guppy and drops the bar by one hit, BossPhase.hits of them
##   winning the fight; after every dive_every hits it dives, splashes up ahead on the right where the wave's swell rises
##   (its crest over the deck early in its warning), the wave jumped, then its floor bite (leaving a lane, then across every
##   lane, alternating) dodged, and it rises again; nothing of the shark over the lanes but its floor bite's jaws;
## - real contact only: a low bomb kills a runner who stays or slides and spares one who jumps; a high one kills a runner
##   who stays or jumps and spares one who slides; armor and the shield block either (the bomb bursts: no hit), the dash
##   passes through either (the bomb flies on: a hit); a wave kills a runner who doesn't jump it and spares one who does;
##   a runner with the grapple who runs on into a floor bite's gap on the top is pulled back up onto the deck;
## - no escalation, a retry plays the same; nothing comes while the attacks are held, and the barrage keeps its spacing
##   after;
## - the defeat: Mecha Guppy dives from its watch, bursts up beside the top under the ship, gulps the captain with the
##   ship's stern half (the bow half falling away), falls back, then breaches out at sea past the shoreline, where the run
##   camera sees it over the deck's edge, and dives back in with a plume of spray; nothing of its jaws or its body ever over
##   the lanes or the eaves, nothing in it hurts the runner (no hazard live after the win), the riff after the gulp, and
##   victory_over dive_after its dive, well within LevelRun.BOSS_VICTORY_MAX;
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
## A bomb's hitbox clears what it must clear by at least this much (metres).
const BAND_MARGIN: float = 0.08

var sim: RunSim
var def: BossDef


func run() -> void:
	sim = RunSim.new(tree, tuning)
	var slot := load(BOSS_PATH) as BossDef
	def = slot if slot != null and slot.is_built() else null
	if def == null:
		check(false, "Mecha Guppy and Captain Cogs' fight loads")
		return
	_test_shape(def.tuning as MechaGuppyTuning, "at the defaults")
	_test_tunables()
	_test_sounds()
	for speed: float in SPEEDS:
		for lanes: int in LANES:
			await _test_live(lanes, speed)
	await _test_bombs_contact()
	await _test_waves_contact()
	await _test_top_fall()
	await _test_retry()
	await _test_held()
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


func _def_with(edit: Callable, top_hits: int = -1) -> BossDef:
	var out: BossDef = def.duplicate() as BossDef
	var t: MechaGuppyTuning = (def.tuning as MechaGuppyTuning).duplicate() as MechaGuppyTuning
	edit.call(t)
	out.tuning = t
	if top_hits > 0:
		var phases: Array[BossPhase] = []
		for ph: BossPhase in def.phases:
			phases.append(ph.duplicate() as BossPhase)
		phases[2].hits = top_hits
		out.phases = phases
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


## A jump's clear stretch over a low bomb's hitbox (MechaGuppyBot.jump_clear) must hold the bomb's crossing of the runner's
## hurtbox (its hitbox's width and theirs, at bomb_speed) with this much to spare either side (seconds).
const JUMP_SPARE: float = 0.1


# --- The bombs' shape ------------------------------------------------------------------------------

## Why `mt`'s bombs break their promises (see the header), or "".
func _shape_problem(mt: MechaGuppyTuning) -> String:
	var low: Vector2 = MechaGuppyBarrage.hit_band(mt, false)
	var high: Vector2 = MechaGuppyBarrage.hit_band(mt, true)
	var stand: float = tuning.hurtbox_size.y
	var slide: float = tuning.hurtbox_slide_height
	if low.x > slide - BAND_MARGIN or low.y > tuning.jump_height - 0.3:
		return "a low bomb's hitbox %.2f-%.2f m: a slide (%.2f m) must not pass it, a jump (%.2f m) must clear it" % [low.x,
			low.y, slide, tuning.jump_height]
	var clear: Vector2 = MechaGuppyBot.jump_clear(tuning, low.y)
	var cross: float = (MechaGuppyBarrage.hit_size(mt).x + tuning.hurtbox_size.x) / mt.bomb_speed
	if clear.y - clear.x < cross + JUMP_SPARE * 2.0:
		return "a jump clears a low bomb for %.2f s, its crossing takes %.2f s" % [clear.y - clear.x, cross]
	if high.x < slide + BAND_MARGIN or high.x > stand - BAND_MARGIN:
		return "a high bomb's hitbox from %.2f m: over a slide (%.2f m), under a standing runner's top (%.2f m)" % [high.x,
			slide, stand]
	if mt.bomb_warning < mt.dodge_reaction + clear.x:
		return "a bomb's warning %.2f s: less than a reaction and a jump's rise (%.2f s)" % [mt.bomb_warning,
			mt.dodge_reaction + clear.x]
	var size: Vector3 = MechaGuppyBarrage.hit_size(mt)
	if size.x >= mt.bomb_radius * 2.0 or size.y >= mt.bomb_radius * 2.0 or size.z >= mt.bomb_radius * 2.0:
		return "the hitbox isn't smaller than the bomb"
	if MechaGuppyTop.words(mt).is_empty():
		return "no barrage in the script"
	return ""


func _test_shape(mt: MechaGuppyTuning, what: String) -> void:
	var problem: String = _shape_problem(mt)
	check(problem == "", "the bombs %s: a low one jumped, not slid under; a high one slid under, not jumped or stood under; warned a reaction and a jump's rise ahead%s"
		% [what, "" if problem == "" else " (" + problem + ")"])
	if what == "at the defaults":
		var words: Array[String] = MechaGuppyTop.words(mt)
		var both: bool = not words.is_empty()
		for w: String in words:
			both = both and w.contains("L") and w.contains("H") and w.length() >= mt.dive_every
		check(both, "every barrage mixes low and high bombs and holds a dive's hits (%s)" % [words])


## Every phase 3 tunable (MechaGuppyTuning.TOP_TUNABLES with a range) at both ends of its range keeps the bombs' promises.
func _test_tunables() -> void:
	var base := def.tuning as MechaGuppyTuning
	var bad: Array[String] = []
	var swept: int = 0
	for prop: Dictionary in base.get_property_list():
		var key: String = prop["name"]
		if not MechaGuppyTuning.TOP_TUNABLES.has(key) or int(prop["hint"]) != PROPERTY_HINT_RANGE:
			continue
		var parts: PackedStringArray = String(prop["hint_string"]).split(",")
		for end: int in 2:
			var mt: MechaGuppyTuning = base.duplicate() as MechaGuppyTuning
			var v: float = float(parts[end])
			mt.set(key, int(v) if prop["type"] == TYPE_INT else v)
			var problem: String = _shape_problem(mt)
			if problem != "":
				bad.append("%s=%s: %s" % [key, parts[end], problem])
		swept += 1
	check(swept >= 20 and bad.is_empty(), "every phase 3 tunable at both ends of its range keeps the bombs fair (%d swept)%s"
		% [swept, "" if bad.is_empty() else ": " + "; ".join(bad.slice(0, 3))])


## Phase 3's sounds: in the library, the warnings as long as their warnings and the same every time.
func _test_sounds() -> void:
	var library := load("res://data/audio/sfx_library.tres") as SfxLibrary
	var missing: Array[String] = []
	for sound: StringName in [&"cogs_charge", &"cogs_cannon", &"wave_swell", &"wave_crash", &"guppy_leap", &"guppy_gulp",
			&"guppy_swim", &"guppy_clang", &"guppy_rumble", &"guppy_floor_warn", &"guppy_bite"]:
		if library.stream(sound) == null or not library.volume_db.has(String(sound)):
			missing.append(String(sound))
	check(missing.is_empty(), "phase 3's and the defeat's sounds are in the library (%s missing)" % [missing])
	var mt := def.tuning as MechaGuppyTuning
	var charge: AudioStream = library.stream(&"cogs_charge")
	var swell: AudioStream = library.stream(&"wave_swell")
	check(charge != null and absf(charge.get_length() - mt.bomb_warning) < 0.02 and swell != null
		and absf(swell.get_length() - mt.wave_warning) < 0.02,
		"the cannon's charge lasts a bomb's warning (%.2f s) and the swell's roar the wave's (%.2f s)"
		% [charge.get_length() if charge != null else 0.0, swell.get_length() if swell != null else 0.0])
	check(not library.pitch_variation.has("cogs_charge") and not library.pitch_variation.has("wave_swell"),
		"the warnings sound exactly the same every time (no pitch variation)")


# --- Live ------------------------------------------------------------------------------------------

## The reading runner through phase 3 (see the header).
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
	var full: float = boss.phase_start_health(2)
	var share: float = boss.hit_damage()
	check(absf(boss.health - full) < 0.01 * boss.max_health and not boss.health_runs_down(),
		"the bar starts phase 3 full, Mecha Guppy's health, and it drops only by hits %s" % tag)
	var st: Dictionary = {"lines": [], "crests": {}, "over_lanes": 0, "shark_seen": 0, "watch": 0, "captain_seen": 0,
		"level": 0, "drops": [], "health": boss.health, "ship_ok": true, "shark_ok": true, "sail_seen": 0, "inner": 0}
	var problems: Array[String] = []
	var ship: CaptainCogsShip = boss.ship
	var shark: MechaGuppyShark = boss.shark
	var half: float = world.geo.half_width() + MechaGuppyLooks.EAVE_REACH
	await _run(world, 150.0, func() -> bool: return boss.is_defeated(), func() -> void:
		bot.step()
		if boss.health < float(st["health"]) - 0.0001:
			(st["drops"] as Array).append(float(st["health"]) - boss.health)
			st["health"] = boss.health
		# Each bomb's red line across the lanes at its height while it warns.
		for b: Dictionary in boss.top.barrage.bombs:
			if int(b["state"]) != MechaGuppyBarrage.State.WARN:
				continue
			var line: MeshInstance3D = b["line"]
			if line == null or not line.visible or absf(line.global_position.y - p.floor_base - float(b["y"])) > 0.01 \
					or line.scale.x < world.geo.wall_x() * 2.0 or absf(-line.global_position.z - p.distance) > 0.5:
				problems.append("bomb %d warns without its line across the lanes at its height" % int(b["k"]))
		# The wave's swell beside the top, its crest over the deck early in the warning.
		for w: Dictionary in boss.top.waves.waves:
			if int(w["state"]) == MechaGuppyWaves.State.SWELL:
				var into: float = boss.top.waves.clock - float(w["start"])
				var crest: float = boss.top.waves.crest_above(w)
				if crest > 0.0 and not (st["crests"] as Dictionary).has(int(w["k"])):
					st["crests"][int(w["k"])] = into
				if into >= MechaGuppyWaves.CREST_BY and crest < CREST_SHOWN:
					problems.append("wave %d's crest %.2f m over the deck %.2f s into its warning" % [int(w["k"]), crest, into])
		# The ship level on the left and the captain in view; Mecha Guppy's watch on the right, in view, never over the lanes.
		# The captain from every lane but the outer ones on the right of a wide top (the last on 5 lanes, the last two on 6);
		# his ship's sail from every lane.
		if ship.is_level() and not ship.swallowed:
			st["level"] = int(st["level"]) + 1
			var sail: Vector3 = ship.global_transform * Vector3(0.0, CaptainCogsModel.DECK + 5.0, -2.0)
			if _seen(world, sail) and sail.x < -world.geo.wall_x():
				st["sail_seen"] = int(st["sail_seen"]) + 1
			if p.lane < lanes - (lanes - 2) / 2:
				st["inner"] = int(st["inner"]) + 1
				var captain: Vector3 = ship.global_transform * CaptainCogsModel.CAPTAIN_SPOT + Vector3(0.0, 1.0, 0.0)
				if _seen(world, captain) and captain.x < -world.geo.wall_x():
					st["captain_seen"] = int(st["captain_seen"]) + 1
		if shark.watching():
			st["watch"] = int(st["watch"]) + 1
			var seen: bool = false
			for q: Vector3 in shark.jaws_points():
				seen = seen or (_seen(world, q) and q.x > world.geo.wall_x())
			if seen:
				st["shark_seen"] = int(st["shark_seen"]) + 1
			if absf(-shark.hinge.z - p.distance - mt.guppy_ahead) > 0.5:
				st["shark_ok"] = false
		var kind: int = int(shark.action.get("kind", -1))
		if kind == MechaGuppyShark.Kind.WATCH or kind == MechaGuppyShark.Kind.SPLASH:
			var points: PackedVector3Array = shark.jaws_points()
			points.append_array(shark.body_points())
			for q: Vector3 in points:
				if absf(q.x) < half and q.y > p.floor_base - 6.0:
					st["over_lanes"] = int(st["over_lanes"]) + 1)
	var hits: int = def.phases[2].hits
	check(boss.is_defeated() and p.alive and hurt[0] == 0,
		"the reading runner wins phase 3 untouched %s%s" % [tag, "" if p.alive else " (died at %.1f s: %s)" % [boss.fight_time(),
			boss.top.act]])
	var landed: Array[Dictionary] = _events(boss, &"bomb_landed")
	var drops: Array = st["drops"]
	var drops_ok: bool = drops.size() == hits
	for d: float in drops:
		drops_ok = drops_ok and absf(d - share) < 0.001 * boss.max_health + 0.0001
	check(landed.size() == hits and boss.top.hits == hits and drops_ok and boss.top.barrage.burst == 0,
		"every bomb past the runner flies on into Mecha Guppy: %d hits, each dropping the bar one hit's share, win it (%d drops of %s; %d burst) %s"
		% [landed.size(), drops.size(), drops.map(func(d: float) -> String: return "%.3f" % d).slice(0, 3), boss.top.barrage.burst, tag])
	# The warnings: seen (the line, checked above) and heard, each its warning before its shot, none before the last passed.
	var warns: Array[Dictionary] = _events(boss, &"bomb_warning")
	var shots: Array[Dictionary] = _events(boss, &"bomb_shot")
	var passed: Array[Dictionary] = _events(boss, &"bomb_passed")
	var charges: Array[float] = _sounds(boss, &"cogs_charge")
	var warn_ok: bool = warns.size() == shots.size() and charges.size() == warns.size() and warns.size() >= hits
	for i: int in mini(warns.size(), shots.size()):
		warn_ok = warn_ok and absf(float(shots[i]["t"]) - float(warns[i]["t"]) - mt.bomb_warning) < FRAME * 2.0 \
			and charges.has(float(warns[i]["t"])) and float(warns[i]["meets"]) >= mt.dodge_reaction + 0.13
	var apart: bool = true
	for i: int in range(1, warns.size()):
		var prev: float = INF
		for q: Dictionary in passed:
			if int(q["k"]) == int(warns[i - 1]["k"]):
				prev = float(q["t"])
		apart = apart and float(warns[i]["t"]) >= prev + mt.beat_spare - FRAME \
			and float(warns[i]["t"]) >= float(warns[i - 1]["t"]) + mt.bomb_gap - FRAME
	check(warn_ok and problems.is_empty(), "every bomb warned by its red line at its height and the cannon's charge, %.1f s before the shot %s%s"
		% [mt.bomb_warning, tag, "" if problems.is_empty() else ": " + "; ".join(problems.slice(0, 3))])
	check(apart, "never a bomb's warning before the last bomb has passed the runner, nor sooner than bomb_gap (one dodge at a time) %s" % tag)
	var lows: int = 0
	var highs: int = 0
	for e: Dictionary in warns:
		if bool(e["high"]):
			highs += 1
		else:
			lows += 1
	var waves: Array[Dictionary] = _events(boss, &"wave")
	check(bot.top_slides == highs and bot.top_jumps == lows + waves.size() and highs > 0 and lows > 0
		and bot.bomb_margin >= JUMP_SPARE * 0.5,
		"the low bombs jumped (%d), the high ones slid under (%d), the waves jumped (%d), a low bomb cleared by %.2f s at the least %s"
		% [lows, highs, waves.size(), bot.bomb_margin, tag])
	# The interludes: a dive after every dive_every hits, then the splash, the wave, the floor bite, the watch again.
	var dives: Array[Dictionary] = _events(boss, &"guppy_dive")
	var splashes: Array[Dictionary] = _events(boss, &"guppy_splash")
	var bites: Array[Dictionary] = _events(boss, &"floor_bite_warning")
	var snaps: Array[Dictionary] = _events(boss, &"floor_bite_snap")
	var watches: Array[Dictionary] = _events(boss, &"guppy_watch")
	var want: int = (hits - 1) / mt.dive_every
	var counts: Array[int] = [dives.size(), splashes.size(), waves.size(), bites.size(), snaps.size(), watches.size()]
	var order_ok: bool = counts == [want, want, want, want, want, want + 1]
	var why: Array[String] = []
	for i: int in mini(want, mini(dives.size(), mini(splashes.size(), mini(waves.size(), mini(bites.size(), snaps.size()))))):
		var seq: bool = float(dives[i]["t"]) < float(splashes[i]["t"]) and float(splashes[i]["t"]) < float(waves[i]["t"]) \
			and float(waves[i]["t"]) < float(bites[i]["t"]) and float(bites[i]["t"]) < float(snaps[i]["t"]) \
			and (i + 1 >= watches.size() or float(watches[i + 1]["t"]) > float(snaps[i]["t"]))
		var kind: bool = bool(bites[i]["full"]) == (i % 2 == 1) and int(bites[i]["side"]) == 1
		var spot: float = absf(float(splashes[i]["at"]) - float(waves[i]["d_crash"]))
		if not seq:
			why.append("%d out of order" % i)
		if not kind:
			why.append("%d's bite full %s side %d" % [i, bites[i]["full"], int(bites[i]["side"])])
		if spot >= 0.5:
			why.append("%d's splash %.2f m off its swell" % [i, spot])
		order_ok = order_ok and seq and kind and spot < 0.5
		var before: int = 0
		for e: Dictionary in landed:
			if float(e["t"]) < float(dives[i]["t"]):
				before += 1
		if before != (i + 1) * mt.dive_every:
			why.append("%d after %d hits" % [i, before])
		order_ok = order_ok and before == (i + 1) * mt.dive_every
	var crest_by: float = 0.0
	for k: int in st["crests"]:
		crest_by = maxf(crest_by, float(st["crests"][k]))
	check(order_ok and (st["crests"] as Dictionary).size() == waves.size(),
		"after every %d hits Mecha Guppy dives, bursts up ahead on the right where the wave's swell rises (its crest up by %.2f s), the wave, then its floor bite from the right (one leaving a lane, then one across every lane), and it rises again: %d times %s%s"
		% [mt.dive_every, crest_by, dives.size(), tag, "" if order_ok else " (%s; %s)" % [counts, why]])
	check(bot.bites.size() == want and bot.bite_slack >= 0.0 and bot.jump_margin >= 0.0,
		"its floor bites on the top read and dodged (%d; %.2f s to spare, jumps by %.2f s) %s" % [bot.bites.size(), bot.bite_slack,
			bot.jump_margin if bot.jump_margin < INF else -1.0, tag])
	var watch: int = int(st["watch"])
	check(int(st["level"]) > 0 and float(st["sail_seen"]) >= 0.95 * float(st["level"])
		and float(st["captain_seen"]) >= 0.9 * float(st["inner"]) and watch > 0
		and float(st["shark_seen"]) >= 0.9 * float(watch) and bool(st["shark_ok"]),
		"Captain Cogs' ship on the left of the run camera's view (its sail %.0f%% of the time level; the captain %.0f%% from every lane but a wide top's outer right ones), Mecha Guppy on the right (%.0f%% of its watch), its head just ahead of the runner %s"
		% [100.0 * float(st["sail_seen"]) / maxf(float(st["level"]), 1.0), 100.0 * float(st["captain_seen"]) / maxf(float(st["inner"]), 1.0),
			100.0 * float(st["shark_seen"]) / maxf(float(watch), 1.0), tag])
	check(int(st["over_lanes"]) == 0, "nothing of Mecha Guppy over the lanes or the eaves in its watch, dive or splash (%d points) %s"
		% [st["over_lanes"], tag])
	print("  Mecha Guppy's phase 3 %s: the top reached at %.1f s, %d bombs (%d low, %d high), %d dives, won at %.1f s (%.1f s on the top)"
		% [tag, boss.top_reached_at, warns.size(), lows, highs, dives.size(), boss.fight_time(), boss.fight_time() - boss.top_reached_at])
	await sim.free_world(world)


# --- Real contact --------------------------------------------------------------------------------

## A world on the top, the script off (MechaGuppy.attacks_enabled: nothing comes), Mecha Guppy in its watch, the runner in
## lane `lane`, still running: [world, boss], or [] if the top isn't reached.
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
	# On along the top until it's full width (its lanes that led up reach back further) and Mecha Guppy is up, with nothing
	# picked up on the climb (the armor rule's armor) or waiting ahead.
	var roof: MechaGuppyClimb.Roof = boss.climb.roofs[-1]
	await _run(world, 5.0, func() -> bool: return p.distance > roof.full_from() + 2.0 and boss.shark.watching())
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


func _test_bombs_contact() -> void:
	var cases: Array = [[false, "stay"], [false, "jump"], [false, "slide"], [false, "armor"], [false, "shield"],
		[false, "dash"], [true, "stay"], [true, "slide"], [true, "jump"], [true, "armor"]]
	var rules_checked: bool = false
	for c: Array in cases:
		var high: bool = c[0]
		var mode: String = c[1]
		var what: String = "a %s bomb (%s)" % ["high" if high else "low", mode]
		var pair: Array = await _on_top(3, 18.0, 1)
		if pair.is_empty():
			check(false, "the runner reaches the top (%s)" % what)
			continue
		var world: RunWorld = pair[0]
		var boss: MechaGuppy = pair[1]
		var p: Player = world.player
		var mt: MechaGuppyTuning = boss.tuning
		var cause: Array[String] = [""]
		p.died.connect(func(c2: String) -> void: cause[0] = c2)
		var used: Array[StringName] = []
		p.item_used.connect(func(item: StringName) -> void: used.append(item))
		match mode:
			"armor":
				p.armor = 1
			"shield":
				p.shield = 1
		var barrage: MechaGuppyBarrage = boss.top.barrage
		var landed_before: int = barrage.landed
		var b: Dictionary = barrage.fire(0, 0, high)
		var st: Dictionary = {"acted": false}
		var clear: Vector2 = MechaGuppyBot.jump_clear(tuning, MechaGuppyBarrage.hit_band(mt, false).y)
		await _run(world, 3.0, func() -> bool: return int(b["state"]) == MechaGuppyBarrage.State.DONE, func() -> void:
			var coming: Array[Dictionary] = barrage.incoming(p.position.x)
			var at: float = float(coming[0]["at"]) if not coming.is_empty() else INF
			if not bool(st["acted"]):
				if mode == "jump" and at <= (clear.x + clear.y) * 0.5:
					st["acted"] = true
					p.press(&"jump")
				elif mode == "slide" and at <= MechaGuppyBot.SLIDE_LEAD:
					st["acted"] = true
					p.press(&"slide")
				elif mode == "dash" and at <= 0.15:
					st["acted"] = true
					p.start_dash(0.6, 0.0)
			var live: Array[Hazard] = barrage.bomb_hazards()
			if not live.is_empty() and not rules_checked:
				rules_checked = true
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
				var bomb: float = mt.bomb_radius * 2.0
				check(ok and h.is_enemy_attack and h.size.x < bomb and h.size.y < bomb and h.size.z < bomb
					and absf(-h.global_position.z - p.distance) < 0.6,
					"a bomb's hitbox: an enemy attack (armor and the shield block it, the dash passes), smaller than the bomb, crossing the lanes at the runner's distance"))
		var hit: bool = barrage.landed > landed_before
		match mode:
			"stay":
				check(not p.alive and cause[0] == MechaGuppyBarrage.BOMB_NAME, "%s kills a runner who stays put (%s)" % [what, cause[0]])
			"jump":
				if high:
					check(not p.alive and cause[0] == MechaGuppyBarrage.BOMB_NAME, "%s kills a runner who jumps into it (%s)" % [what, cause[0]])
				else:
					check(p.alive and used.is_empty() and hit, "%s: a normal jump clears it, and it flies on into Mecha Guppy (a hit)" % what)
			"slide":
				if high:
					check(p.alive and used.is_empty() and hit, "%s: a slide passes under it, and it flies on into Mecha Guppy (a hit)" % what)
				else:
					check(not p.alive and cause[0] == MechaGuppyBarrage.BOMB_NAME, "%s kills a runner who slides into it (%s)" % [what, cause[0]])
			"armor":
				check(p.alive and used.has(&"armor") and not hit and barrage.burst > 0,
					"%s: armor blocks it (spent: %s); it bursts there and hits nothing" % [what, used])
			"shield":
				check(p.alive and used.has(&"shield") and not hit, "%s: the shield blocks it (%s); no hit" % [what, used])
			"dash":
				check(p.alive and used.is_empty() and hit, "%s: the dash passes through it, and it flies on (a hit)" % what)
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


## A runner who runs on in a lane Mecha Guppy's floor bite on the top takes falls into its gap; the grapple's save pulls
## them back up onto the top, on its floor, and they run on (the top's bites are Roof.top_bites: MechaGuppyStairs.save_spot
## reads them as the climb's).
func _test_top_fall() -> void:
	var pair: Array = await _on_top(3, 23.8, 2)
	if pair.is_empty():
		check(false, "the runner reaches the top (a fall into a top bite)")
		return
	var world: RunWorld = pair[0]
	var boss: MechaGuppy = pair[1]
	var p: Player = world.player
	p.grapples = 1
	var used: Array[StringName] = []
	p.item_used.connect(func(item: StringName) -> void: used.append(item))
	boss.shark.top_dive()
	await _run(world, 3.0, func() -> bool: return boss.shark.idle())
	boss.top.interludes = 1
	boss.top._floor_bite()
	var bite: MechaGuppyCrescent = boss.top.bite
	var roof: MechaGuppyClimb.Roof = boss.climb.roofs[-1]
	if bite == null or not roof.top_bites.has(bite) or boss.floor_bite.bite != bite:
		check(false, "a floor bite planned on the top (%s)" % bite)
		await sim.free_world(world)
		return
	await _run(world, 6.0, func() -> bool: return used.has(&"grapple"))
	var landed: Dictionary = {}
	await _run(world, 4.0, func() -> bool: return not landed.is_empty(), func() -> void:
		if p.alive and p.grounded and p.surface == Player.Surface.FLOOR and absf(p.floor_y - roof.top) < 0.01 and used.has(&"grapple"):
			landed["lane"] = p.lane
			landed["d"] = p.distance)
	var ok: bool = not landed.is_empty() and roof.covers(int(landed["lane"]), float(landed["d"]))
	await _run(world, 3.0, func() -> bool: return p.distance > bite.to + 5.0)
	check(ok and not bite.full and p.alive and p.distance > bite.to + 5.0 and absf(p.floor_y - roof.top) < 0.01,
		"running on into the top's floor bite is a fall, and the grapple's save pulls the runner back up onto the top (lane %s at %s m; the gap %.1f-%.1f m), running on"
		% [landed.get("lane", "-"), "%.1f" % float(landed["d"]) if not landed.is_empty() else "-", bite.from, bite.to])
	await sim.free_world(world)


# --- A retry, and held attacks --------------------------------------------------------------------

## Two attempts play phase 3 the same: the same bombs, waves and bites at the same moments from the top.
func _test_retry() -> void:
	var logs: Array[String] = []
	for attempt: int in 2:
		var pair: Array = _fight(6, 23.8)
		var world: RunWorld = pair[0]
		var boss: MechaGuppy = pair[1]
		var bot := MechaGuppyBot.new(boss)
		bot.reaction = REACTION
		await _run(world, 150.0, func() -> bool: return boss.is_defeated(), bot.step)
		var lines: PackedStringArray = []
		for e: Dictionary in boss.events:
			if e["event"] in [&"bomb_warning", &"bomb_shot", &"bomb_landed", &"wave", &"guppy_dive", &"guppy_splash",
					&"floor_bite_warning", &"floor_bite_snap"]:
				lines.append("%s %.3f %s" % [e["event"], float(e["t"]) - boss.top_reached_at, e.get("high", "")])
		logs.append(";".join(lines))
		await sim.free_world(world)
	check(logs[0] != "" and logs[0] == logs[1], "a retry plays phase 3 the same: the same bombs, waves and bites at the same moments")


## Attacks held after the top is reached (MechaGuppy.attacks_enabled off, as an intro would hold them): nothing comes;
## once they're back, the barrage starts at once and keeps its spacing, dodged untouched.
func _test_held() -> void:
	var pair: Array = _fight(5, 23.8)
	var world: RunWorld = pair[0]
	var boss: MechaGuppy = pair[1]
	var mt: MechaGuppyTuning = boss.tuning
	var bot := MechaGuppyBot.new(boss)
	bot.reaction = REACTION
	var hurt: Array[int] = [0]
	world.player.item_used.connect(func(_item: StringName) -> void: hurt[0] += 1)
	if not await _to_top(world, boss, bot):
		check(false, "the runner reaches the top (held attacks)")
		await sim.free_world(world)
		return
	boss.attacks_enabled = false
	await _run(world, mt.top_first + 4.0, func() -> bool: return false, bot.step)
	var held: int = _events(boss, &"bomb_warning").size()
	var released: float = boss.fight_time()
	boss.attacks_enabled = true
	await _run(world, 10.0, func() -> bool: return false, bot.step)
	var warns: Array[Dictionary] = _events(boss, &"bomb_warning")
	var ok: bool = held == 0 and warns.size() >= 3 and absf(float(warns[0]["t"]) - released) < FRAME * 2.0
	for i: int in range(1, warns.size()):
		ok = ok and float(warns[i]["t"]) - float(warns[i - 1]["t"]) >= mt.bomb_gap - FRAME
	check(ok and world.player.alive and hurt[0] == 0,
		"nothing comes while the attacks are held; then the barrage starts at once and keeps its spacing (%d bombs), dodged untouched"
		% warns.size())
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


## The leap (see the header), phase 3 cut to two hits, at 3 and 6 lanes.
func _test_defeat() -> void:
	for lanes: int in [3, 6]:
		var tag: String = "(%d lanes)" % lanes
		var quick: BossDef = _def_with(func(t: MechaGuppyTuning) -> void: t.dive_every = 8, 2)
		var pair: Array = _fight(lanes, 23.8, quick)
		var world: RunWorld = pair[0]
		var boss: MechaGuppy = pair[1]
		var p: Player = world.player
		var mt: MechaGuppyTuning = boss.tuning
		var bot := MechaGuppyBot.new(boss)
		bot.reaction = REACTION
		await _run(world, 60.0, func() -> bool: return boss.is_defeated(), bot.step)
		check(boss.is_defeated() and boss.leap != null and not boss.victory_over() and not boss.victory_riff(),
			"phase 3's last hit, and Mecha Guppy leaps; the results wait, and no riff at the defeat itself %s" % tag)
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
			var live: int = boss.top.barrage.bomb_hazards().size() + boss.top.waves.band_hazards().size() + boss.bombs.blast_hazards().size()
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
		check(order and boss.victory_over() and absf(float(marks["gulp"]) - float(marks["rise"]) - mt.leap_rise) < FRAME * 2.0
			and absf(float(marks["rise"]) - MechaGuppyLeap.DIVE_SECONDS) < FRAME * 2.0
			and absf(float(marks["over"]) - float(marks["dive"]) - mt.dive_after) < FRAME * 2.0
			and float(marks["over"]) <= leap.over_by() + FRAME * 2.0 and is_equal_approx(leap.over_by(), MechaGuppyLeap.seconds_to_over(mt))
			and absf(float(st["over_at"]) - float(marks["over"])) < FRAME * 2.0 and float(marks["over"]) < LevelRun.BOSS_VICTORY_MAX
			and marks.has("gone"),
			"it dives from its watch, bursts up, gulps at %.2f s, falls back, breaches out at sea at %.2f s and dives back in at %.2f s; the results may follow %.1f s after the win (at most %.0f s), and it's gone at %.1f s %s"
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

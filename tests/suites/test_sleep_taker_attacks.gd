extends TestSuite
## The Sleep Taker's attacks (GDD §10; task E5c-a), at 3, 5 and 6 lanes:
## - the giant slash: it strikes only after its warning (the shriek and its lanes lit red), only within
##   the lanes it warned; a runner who reacts as the warning starts always escapes, to the refuge's pad
##   or (at 5 and 6 lanes) out of its lanes, from every lane; the ceiling is always safe; every attempt
##   plays the same;
## - the grasping hands: the mist warns the lane (with its whispering, and pickups keep off it) before a
##   hand rises; a lane switch always escapes, from every lane; every attempt plays the same;
## - the whole pattern on its real arena (its holes and fences, refuges, hands and lights out): a runner
##   who reads the warnings (SleepTakerBot) gets through at every lane count, without god mode.

const BOSS_PATH: String = "res://data/bosses/dead_zone_boss.tres"
const LANES: Array[int] = [3, 5, 6]
## A player's reaction: the runner moves this long after a warning starts.
const REACTION: float = 0.35

var sim: RunSim
var def: BossDef


func run() -> void:
	sim = RunSim.new(tree, tuning)
	var slot := load(BOSS_PATH) as BossDef
	def = slot.preview() if slot != null else null
	if def == null:
		check(false, "the Sleep Taker's preview loads")
		return
	await _test_slash_warning()
	await _test_slash_escapes()
	await _test_slash_same_every_attempt()
	await _test_hands_warning()
	await _test_hands_escapes()
	await _test_hands_same_every_attempt()
	await _test_real_arena()


# --- Helpers -------------------------------------------------------------------------------

func _fight(p_def: BossDef, lanes: int) -> Array:
	var boss := BossEncounter.create(p_def) as SleepTaker
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = p_def
	ctx.config = BossArena.base_config(p_def)
	ctx.config.lane_count = lanes
	ctx.tuning = tuning
	var arena: BossArena = boss.plan_arena(ctx)
	var world: RunWorld = sim.build_world(arena.layout, null, tuning, ctx.config)
	boss.setup(world, ctx, arena)
	return [world, boss]


## The Sleep Taker on a plain street (floor and walls), with its attack list `pattern` in every phase;
## `refuges` off takes its refuges away, and with `quiet` nothing but the refuges' slashes comes.
func _plain_def(pattern: String, refuges: bool = true, quiet: bool = false) -> BossDef:
	var out: BossDef = def.duplicate() as BossDef
	var t: SleepTakerTuning = (def.tuning as SleepTakerTuning).duplicate() as SleepTakerTuning
	t.attack_patterns = PackedStringArray([pattern, pattern, pattern])
	if not refuges:
		t.refuge_first = 100000.0
	if quiet:
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


## True if the runner's body overlaps one of the attack's live damage boxes now.
func _touching(world: RunWorld, boxes: Array[Hazard]) -> bool:
	var body: AABB = world.player.hurtbox_aabb()
	for h: Hazard in boxes:
		if h.is_active() and AABB(h.global_position - h.size * 0.5, h.size).intersects(body):
			return true
	return false


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


# --- The giant slash ---------------------------------------------------------------------------

## A runner who stays in its lane (god mode, so it runs on): the slash touches it only after its whole
## warning (the shriek, its lanes lit from the warning's start), only inside the lanes it warned (and
## those count as floor warnings: pickups keep off them), and never a runner on the ceiling.
func _test_slash_warning() -> void:
	var t := def.tuning as SleepTakerTuning
	check(t.slash_height < tuning.ceiling_height - tuning.hurtbox_size.y - 0.5,
		"the slash's reach (%.2f m) stops well below a ceiling rider (from %.2f m)" % [t.slash_height,
		tuning.ceiling_height - tuning.hurtbox_size.y])
	check(t.slash_height > tuning.jump_height + 0.3, "and above a jump's top: only leaving its lanes or the ceiling dodges it")
	for lanes: int in LANES:
		var tag: String = "(%d lanes)" % lanes
		var pair: Array = _fight(_plain_def("hands", true, true), lanes)
		var world: RunWorld = pair[0]
		var boss: SleepTaker = pair[1]
		world.player.god_mode = true
		var bot := SleepTakerBot.new(boss, &"none")
		# An outer lane: never a refuge's pad lane, always in the slash.
		bot.home_lane = 0
		var seen: Dictionary = {"warned_at": -1.0, "marks": true, "touch": -1.0, "warned_lanes": true, "others_clear": true}
		await _run(world, 40.0, func() -> bool: return not _events(boss, &"slash_over").is_empty(), func() -> void:
			bot.step()
			var s: SleepTakerSlash = boss.slash
			if s.warning_on():
				if float(seen["warned_at"]) < 0.0:
					seen["warned_at"] = boss.fight_time()
				seen["marks"] = bool(seen["marks"]) and s.marks_shown()
				var d: float = world.player.distance
				for l: int in lanes:
					var inside: bool = l >= int(s.attack["first"]) and l <= int(s.attack["last"])
					if inside and not boss.props.warned(l, d, d + 1.0):
						seen["warned_lanes"] = false
					if not inside and boss.props.warned(l, d - 50.0, d + 50.0):
						seen["others_clear"] = false
			var live: Array[Hazard] = [s.hitbox()]
			if float(seen["touch"]) < 0.0 and _touching(world, live):
				seen["touch"] = boss.fight_time())
		var warnings: Array[Dictionary] = _events(boss, &"slash_warning")
		check(not warnings.is_empty(), "a slash comes at the first refuge %s" % tag)
		if warnings.is_empty():
			await sim.free_world(world)
			continue
		var w: Dictionary = warnings[0]
		var shrieks: int = 0
		for e: Dictionary in _events(boss, &"sound"):
			if e["name"] == &"sleep_taker_shriek" and absf(float(e["t"]) - float(w["t"])) < 0.001:
				shrieks += 1
		check(shrieks == 1, "its warning is heard: the shriek as it starts %s" % tag)
		check(bool(seen["marks"]), "its lanes are lit from the warning's start until it strikes %s" % tag)
		check(bool(seen["warned_lanes"]) and bool(seen["others_clear"]),
			"its lanes, and only those, count as floor warnings (pickups keep off them) %s" % tag)
		var touch: float = float(seen["touch"])
		check(touch >= 0.0 and touch - float(w["t"]) >= t.slash_warning() - 0.02,
			"a runner who stays in its lanes is struck, only after the whole warning (%.2f s after it, of %.2f) %s" % [
			touch - float(w["t"]), t.slash_warning(), tag])
		# Only the lanes it warned: its damage box lies within them, and clear of the walls.
		var geo: TrackGeometry = world.geo
		var first: int = int(w["first"])
		var last: int = int(w["last"])
		var box: AABB = boss.slash.box_for(Vector2i(first, last))
		var half: float = geo.lane_width * 0.5
		check(last - first + 1 == mini(3, lanes), "GDD §10: across three lanes (%d-%d) %s" % [first, last, tag])
		check(box.position.x >= geo.lane_x(first) - half - 0.001 and box.end.x <= geo.lane_x(last) + half + 0.001
			and box.position.x > -geo.wall_x() + 0.5 and box.end.x < geo.wall_x() - 0.5,
			"its damage box stays inside the lanes it lit, clear of the walls %s" % tag)
		check(box.size.y < tuning.ceiling_height - tuning.hurtbox_size.y, "and below a ceiling rider %s" % tag)
		await sim.free_world(world)


## A runner who reacts as the warning starts always gets away, from every lane, at every lane count:
## to the refuge's nearest pad and up onto the ceiling, or (at 5 and 6 lanes) to a lane outside the slash.
## No god mode and no armor: a hit ends the run. On the ceiling as it strikes, it's always safe.
func _test_slash_escapes() -> void:
	for lanes: int in LANES:
		for escape: StringName in ([&"pad"] if lanes == 3 else [&"pad", &"lanes"]):
			var survived: int = 0
			var ceiling_ok: bool = true
			var strikes: int = 0
			for start: int in lanes:
				var pair: Array = _fight(_plain_def("hands", true, true), lanes)
				var world: RunWorld = pair[0]
				var boss: SleepTaker = pair[1]
				var bot := SleepTakerBot.new(boss, escape)
				bot.home_lane = start
				bot.reaction = REACTION
				boss.slash.hitbox()
				var surfaces: Array = []
				var counted: Array = [0]
				await _run(world, 40.0, func() -> bool: return _events(boss, &"slash_over").size() >= 2, func() -> void:
					bot.step()
					if boss.slash.strikes > int(counted[0]):
						counted[0] = boss.slash.strikes
						surfaces.append(world.player.surface))
				strikes += boss.slash.strikes
				if world.player.alive and boss.slash.strikes >= 2:
					survived += 1
				if escape == &"pad":
					for s: Variant in surfaces:
						ceiling_ok = ceiling_ok and int(s) == Player.Surface.CEILING
				await sim.free_world(world)
			check(survived == lanes, "a runner reacting %.2f s into the warning escapes by %s from every lane (%d of %d) (%d lanes)" % [
				REACTION, escape, survived, lanes, lanes])
			check(strikes >= 2 * lanes, "two slashes struck in every run (%d) (%d lanes, %s)" % [strikes, lanes, escape])
			if escape == &"pad":
				check(ceiling_ok, "taking the pad, it rides the ceiling as every slash strikes: the ceiling is safe (%d lanes)" % lanes)


## The same runner on the same fight sees the same slashes, every attempt.
func _test_slash_same_every_attempt() -> void:
	var logs: Array[String] = []
	for attempt: int in 2:
		var pair: Array = _fight(_plain_def("hands", true, true), 5)
		var world: RunWorld = pair[0]
		var boss: SleepTaker = pair[1]
		var bot := SleepTakerBot.new(boss, &"lanes")
		bot.home_lane = 1
		await _run(world, 40.0, func() -> bool: return _events(boss, &"slash_over").size() >= 2, func() -> void: bot.step())
		var line: PackedStringArray = []
		for e: Dictionary in boss.events:
			if e["event"] in [&"slash_warning", &"slash", &"slash_over"]:
				line.append("%s %.3f %s %s" % [e["event"], e["t"], e.get("first", ""), e.get("last", "")])
		logs.append(" | ".join(line))
		await sim.free_world(world)
	check(logs[0] == logs[1] and logs[0].contains("slash_warning"), "every attempt plays the same slashes")


# --- The grasping hands --------------------------------------------------------------------------

## A runner who stays in its lane (god mode): each hand's mist warns its lane (a floor warning: pickups
## keep off it) with the whispering, before the hand rises; the hand touches the runner only after the
## whole warning, and only in its lane.
func _test_hands_warning() -> void:
	var t := def.tuning as SleepTakerTuning
	for lanes: int in LANES:
		var tag: String = "(%d lanes)" % lanes
		var pair: Array = _fight(_plain_def("hands", false), lanes)
		var world: RunWorld = pair[0]
		var boss: SleepTaker = pair[1]
		world.player.god_mode = true
		var seen: Dictionary = {"warned": true, "early": false, "touches": 0, "first_touch": {}, "pickup": true, "other": true}
		await _run(world, 30.0, func() -> bool: return boss.hands.count >= 3 and not boss.hands.busy(), func() -> void:
			var d: float = world.player.distance
			for h: Dictionary in boss.hands.active:
				var lane: int = int(h["lane"])
				var at: float = float(h["at"])
				if int(h["stage"]) == SleepTakerHands.Stage.MIST:
					seen["warned"] = bool(seen["warned"]) and boss.props.warned(lane, at - 1.0, at + 1.0)
					seen["pickup"] = bool(seen["pickup"]) and not world.pickups.spot_fair(lane, at)
					for l: int in lanes:
						if l != lane and boss.props.warned(l, at - 1.0, at + 1.0):
							seen["other"] = false
					var hz: Hazard = (h["rig"] as Dictionary)["hazard"]
					if hz.is_active():
						seen["early"] = true
				var key: int = int(h["n"])
				var live: Array[Hazard] = [(h["rig"] as Dictionary)["hazard"]]
				if not (seen["first_touch"] as Dictionary).has(key) and _touching(world, live):
					(seen["first_touch"] as Dictionary)[key] = boss.fight_time()
					seen["touches"] = int(seen["touches"]) + 1)
		var mists: Array[Dictionary] = _events(boss, &"mist")
		check(mists.size() >= 3, "hands keep coming (%d) %s" % [mists.size(), tag])
		check(bool(seen["warned"]) and bool(seen["other"]), "each mist warns its lane, and only its lane, until the hand rises %s" % tag)
		check(bool(seen["pickup"]), "no pickup may appear in the mist %s" % tag)
		check(not bool(seen["early"]), "no hand is live while its mist still warns %s" % tag)
		var whispers: int = 0
		for e: Dictionary in _events(boss, &"sound"):
			if e["name"] == &"sleep_taker_whisper":
				whispers += 1
		check(whispers == mists.size(), "every mist whispers (%d of %d) %s" % [whispers, mists.size(), tag])
		var timely: bool = true
		for m: Dictionary in mists:
			var touch: Variant = (seen["first_touch"] as Dictionary).get(int(m["n"]))
			# The hand is live from halfway up: no touch before it has risen out of its mist.
			timely = timely and touch != null and float(touch) - float(m["t"]) >= t.mist_seconds + t.hand_rise_seconds * 0.5 - 0.02
		check(timely and int(seen["touches"]) == mists.size(),
			"a runner who stays put meets every hand, each only once it has risen out of its mist %s" % tag)
		await sim.free_world(world)


## A runner who reacts as the mist appears always gets away by one lane switch, from every lane, at every
## lane count. No god mode and no armor.
func _test_hands_escapes() -> void:
	for lanes: int in LANES:
		var survived: int = 0
		var hands: int = 0
		var adjacent: bool = true
		for start: int in lanes:
			var pair: Array = _fight(_plain_def("hands", false), lanes)
			var world: RunWorld = pair[0]
			var boss: SleepTaker = pair[1]
			var bot := SleepTakerBot.new(boss)
			bot.home_lane = start
			bot.reaction = REACTION
			await _run(world, 40.0, func() -> bool: return boss.hands.count >= 4 and not boss.hands.busy(), func() -> void: bot.step())
			hands += boss.hands.count
			if world.player.alive and boss.hands.count >= 4:
				survived += 1
			for m: Dictionary in _events(boss, &"mist"):
				adjacent = adjacent and absi(int(m["escape"]) - int(m["lane"])) == 1
			await sim.free_world(world)
		check(survived == lanes, "a runner reacting %.2f s into the mist escapes every hand from every lane (%d of %d, %d hands) (%d lanes)" % [
			REACTION, survived, lanes, hands, lanes])
		check(adjacent, "each hand leaves the next lane free: one switch is always enough (%d lanes)" % lanes)


func _test_hands_same_every_attempt() -> void:
	var logs: Array[String] = []
	for attempt: int in 2:
		var pair: Array = _fight(_plain_def("hands", false), 5)
		var world: RunWorld = pair[0]
		var boss: SleepTaker = pair[1]
		var bot := SleepTakerBot.new(boss)
		await _run(world, 30.0, func() -> bool: return boss.hands.count >= 4 and not boss.hands.busy(), func() -> void: bot.step())
		var line: PackedStringArray = []
		for e: Dictionary in boss.events:
			if e["event"] in [&"mist", &"hand"]:
				line.append("%s %.3f %d %.2f" % [e["event"], e["t"], e["lane"], e["at"]])
		logs.append(" | ".join(line))
		await sim.free_world(world)
	check(logs[0] == logs[1] and logs[0].contains("mist"), "every attempt plays the same hands")


# --- The real arena ----------------------------------------------------------------------------

## The whole pattern as it comes, on its real arena (its holes and fences, the refuges, hands and lights
## out), for a runner who reads it: through a whole lap at every lane count, without god mode or armor;
## the slash's lane escape at 5 and 6 lanes too.
func _test_real_arena() -> void:
	for lanes: int in LANES:
		for escape: StringName in ([&"pad"] if lanes == 3 else [&"pad", &"lanes"]):
			var pair: Array = _fight(def, lanes)
			var world: RunWorld = pair[0]
			var boss: SleepTaker = pair[1]
			var bot := SleepTakerBot.new(boss, escape)
			bot.reaction = REACTION
			var lap: float = boss.arena.lap_length
			var cause: Array = [""]
			world.player.died.connect(func(c: String) -> void: cause[0] = c)
			await _run(world, 90.0, func() -> bool: return world.player.distance >= lap + 100.0, func() -> void: bot.step())
			var tag: String = "(%d lanes, %s)" % [lanes, escape]
			check(world.player.alive, "a runner who reads it gets through a whole lap and more %s%s" % [tag,
				"" if world.player.alive else ": %s at %.0f m, %.1f s" % [cause[0], world.player.distance, boss.fight_time()]])
			check(boss.slash.strikes >= 4 and boss.hands.count >= 6 and boss.dark.count >= 1,
				"every attack came: %d slashes, %d hands, %d lights out %s" % [boss.slash.strikes, boss.hands.count, boss.dark.count, tag])
			check(_events(boss, &"refuge_missed").is_empty(), "no refuge went by without its slash %s" % tag)
			if lanes == 5 and escape == &"pad":
				print("  Sleep Taker on its arena (5 lanes): %.0f s of pattern, %d slashes, %d hands, %d lights out" % [
					boss.fight_time() - boss.phase().intro_seconds, boss.slash.count, boss.hands.count, boss.dark.count])
			await sim.free_world(world)

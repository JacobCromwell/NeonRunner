extends TestSuite
## The Sleep Taker's attacks (GDD §10; task E5c-a), at 3, 5 and 6 lanes:
## - the giant slash: it strikes only after its warning (the shriek and its lanes lit red), only within
##   the lanes it warned; a runner who reacts as the warning starts always escapes, to the refuge's pad
##   or (at 5 and 6 lanes) out of its lanes, from every lane; the ceiling is always safe; every attempt
##   plays the same;
## - the grasping hands (owner, October 8, 2026: spread along the street, and on the walls): rounds of
##   rows growing from two to four, each row leaving its door one lane over from the last and standing
##   in the lane the runner kept free before, wall hands on every row; every hand's mist warns its spot,
##   each round whispers; a round comes only with a way through it, proved on real physics: a runner who
##   moves a reaction time after its mists show gets through every round from every lane, at every lane
##   count, in every phase (its pace) and at both speeds, switching lanes at every row, without god mode;
##   every attempt plays the same;
## - the whole pattern on its real arena (its holes and fences, doubled; its wall gaps, refuges, hands and
##   lights out): a runner who reads the warnings (SleepTakerBot) gets through at every lane count, without
##   god mode.

const BOSS_PATH: String = "res://data/bosses/dead_zone_boss.tres"
const LANES: Array[int] = [3, 5, 6]
## The run speeds it's played at: the reference 18 m/s (quick play) and the Dead Zone's (GDD §3:
## ZoneDef.run_speed, which its campaign fight runs at).
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
	await _test_slash_warning()
	await _test_slash_escapes()
	await _test_slash_same_every_attempt()
	await _test_hands_warning()
	await _test_hands_rounds()
	await _test_hands_planning()
	await _test_hands_routes()
	await _test_hands_same_every_attempt()
	await _test_real_arena()


# --- Helpers -------------------------------------------------------------------------------

## The fight at `lanes`, at `speed` m/s (0: the suite's tuning, 18 m/s), from its phase `phase` (as a
## checkpoint resumes it: that phase's pace).
func _fight(p_def: BossDef, lanes: int, speed: float = 0.0, phase: int = 0) -> Array:
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
	if phase > 0:
		ctx.boss_resume = {"phase": phase}
	var arena: BossArena = boss.plan_arena(ctx)
	var world: RunWorld = sim.build_world(arena.layout, null, t, ctx.config)
	boss.setup(world, ctx, arena)
	return [world, boss]


## The Sleep Taker on a plain street (floor and walls), with its attack list `pattern` in every phase and
## no generators (its attacks alone); `refuges` off takes its refuges away, and with `quiet` nothing but
## the refuges' slashes comes.
func _plain_def(pattern: String, refuges: bool = true, quiet: bool = false) -> BossDef:
	var out: BossDef = def.duplicate() as BossDef
	var t: SleepTakerTuning = (def.tuning as SleepTakerTuning).duplicate() as SleepTakerTuning
	t.attack_patterns = PackedStringArray([pattern, pattern, pattern])
	t.generator_delay = 100000.0
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
	for speed: float in SPEEDS:
		for lanes: int in LANES:
			for escape: StringName in _escapes(lanes, speed):
				await _slash_escapes(lanes, escape, speed)


## The slash's escapes to play at `lanes` and `speed`: the pad at every lane count, leaving the lanes
## at 5 and 6; at the Dead Zone's speed only the tightest case, the pad at 3 lanes (the whole fight at
## both speeds, test_sleep_taker_fight, plays the rest), to keep the suite's time down.
static func _escapes(lanes: int, speed: float) -> Array[StringName]:
	var out: Array[StringName] = [&"pad"]
	if speed > MovementTuning.REFERENCE_SPEED + 0.5:
		if lanes > 3:
			out.clear()
		return out
	if lanes > 3:
		out.append(&"lanes")
	return out


func _slash_escapes(lanes: int, escape: StringName, speed: float) -> void:
	var tag: String = "(%d lanes, %.1f m/s)" % [lanes, speed]
	var survived: int = 0
	var ceiling_ok: bool = true
	var strikes: int = 0
	for start: int in lanes:
		var pair: Array = _fight(_plain_def("hands", true, true), lanes, speed)
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
	check(survived == lanes, "a runner reacting %.2f s into the warning escapes by %s from every lane (%d of %d) %s" % [
		REACTION, escape, survived, lanes, tag])
	check(strikes >= 2 * lanes, "two slashes struck in every run (%d) (%s) %s" % [strikes, escape, tag])
	if escape == &"pad":
		check(ceiling_ok, "taking the pad, it rides the ceiling as every slash strikes: the ceiling is safe %s" % tag)


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

## The fight's rounds of hands from its events: round number → {round (its event), mists, hands (the
## mist and hand events of its hands, in order)}.
func _rounds(boss: SleepTaker) -> Dictionary:
	var out: Dictionary = {}
	for e: Dictionary in boss.events:
		match e["event"]:
			&"round":
				out[int(e["n"])] = {"round": e, "mists": [], "hands": []}
			&"mist", &"hand":
				if out.has(int(e["round"])):
					((out[int(e["round"])] as Dictionary)["mists" if e["event"] == &"mist" else "hands"] as Array).append(e)
	return out


## A runner who stays in its lane (god mode, so it runs on): every hand's mist warns its spot (a floor
## mist its lane, and only its lane: a floor warning, so pickups keep off it) until the hand rises, each
## round whispers once and each row's burst sounds once, no hand is live while its mist warns, and a hand
## touches the runner only after it has risen, only in its lane.
func _test_hands_warning() -> void:
	var t := def.tuning as SleepTakerTuning
	for lanes: int in LANES:
		var tag: String = "(%d lanes)" % lanes
		var pair: Array = _fight(_plain_def("hands", false), lanes)
		var world: RunWorld = pair[0]
		var boss: SleepTaker = pair[1]
		world.player.god_mode = true
		var seen: Dictionary = {"warned": true, "early": false, "touches": {}, "pickup": true, "other": true}
		await _run(world, 40.0, func() -> bool: return boss.hands.rounds >= 3 and not boss.hands.busy(), func() -> void:
			for h: Dictionary in boss.hands.active:
				var lane: int = int(h["lane"])
				var at: float = float(h["at"])
				if int(h["stage"]) == SleepTakerHands.Stage.MIST:
					if int(h["side"]) == 0:
						seen["warned"] = bool(seen["warned"]) and boss.props.warned(lane, at - 1.0, at + 1.0)
						seen["pickup"] = bool(seen["pickup"]) and not world.pickups.spot_fair(lane, at)
					for l: int in lanes:
						var here: bool = false
						for other: Dictionary in boss.hands.active:
							here = here or (int(other["side"]) == 0 and int(other["lane"]) == l and absf(float(other["at"]) - at) < 0.01)
						if boss.props.warned(l, at - 1.0, at + 1.0) != here:
							seen["other"] = false
					if ((h["rig"] as Dictionary)["hazard"] as Hazard).is_active():
						seen["early"] = true
				var live: Array[Hazard] = [(h["rig"] as Dictionary)["hazard"]]
				if not (seen["touches"] as Dictionary).has(int(h["n"])) and _touching(world, live):
					(seen["touches"] as Dictionary)[int(h["n"])] = boss.fight_time())
		var rounds: Dictionary = _rounds(boss)
		check(rounds.size() >= 3, "rounds of hands keep coming (%d) %s" % [rounds.size(), tag])
		check(bool(seen["warned"]) and bool(seen["other"]), "each mist warns its spot, and only its lane, until its hand rises %s" % tag)
		check(bool(seen["pickup"]), "no pickup may appear in a mist %s" % tag)
		check(not bool(seen["early"]), "no hand is live while its mist still warns %s" % tag)
		var whispers: int = 0
		var bursts: int = 0
		for e: Dictionary in _events(boss, &"sound"):
			whispers += 1 if e["name"] == &"sleep_taker_whisper" else 0
			bursts += 1 if e["name"] == &"sleep_taker_hand" else 0
		var rows: int = 0
		for n: int in rounds:
			rows += int((rounds[n]["round"] as Dictionary)["rows"])
		check(whispers == boss.hands.rounds and bursts == rows,
			"every round whispers as its mists pool (%d of %d), and each row's hands burst up with a sound (%d of %d rows) %s" % [
			whispers, boss.hands.rounds, bursts, rows, tag])
		# A runner who stays put meets every hand in its lane, each only after it has risen, and no other.
		var rose: Dictionary = {}
		for e: Dictionary in _events(boss, &"hand"):
			rose[int(e["n"])] = float(e["t"])
		var timely: bool = true
		var mine: int = 0
		for e: Dictionary in _events(boss, &"mist"):
			var touch: Variant = (seen["touches"] as Dictionary).get(int(e["n"]))
			if int(e["side"]) != 0 or int(e["lane"]) != world.player.lane:
				timely = timely and touch == null
				continue
			mine += 1
			# Live from halfway up: no touch before it has risen out of its mist.
			timely = timely and touch != null and rose.has(int(e["n"])) \
				and float(touch) >= float(rose[int(e["n"])]) + t.hand_rise_seconds * 0.5 - 0.02
		check(timely and mine > 0 and (seen["touches"] as Dictionary).size() == mine,
			"a runner who stays put meets only its lane's hands (%d), each after it rises from its mist %s" % [mine, tag])
		await sim.free_world(world)


## Owner, October 8, 2026: the hands spread out. On a plain street (every hand fits) a runner who stays
## put sees rounds of hand_rows_first, then a row more each round up to hand_rows_max rows; each row
## hand_row_seconds after the one before along the street (at run speed), leaving only its door, one lane
## over from the last door (the first from the runner's lane), with a hand in the lane the runner kept free
## at the row before (so every row makes them switch lanes) and in every other floor lane, and a wall hand
## on every row (alternating, never beside a door in an outer lane, only over an outer lane with its own
## hand), both walls over the rounds. The progression carries over a phase change; the pooled rigs serve
## floor and wall hands in turn.
func _test_hands_rounds() -> void:
	var t := def.tuning as SleepTakerTuning
	for lanes: int in LANES:
		var tag: String = "(%d lanes)" % lanes
		var pair: Array = _fight(_plain_def("hands", false), lanes)
		var world: RunWorld = pair[0]
		var boss: SleepTaker = pair[1]
		world.player.god_mode = true
		await _run(world, 40.0, func() -> bool: return boss.hands.rounds >= 4 and not boss.hands.busy())
		var rounds: Dictionary = _rounds(boss)
		check(rounds.size() == 4, "four rounds of hands come (%d) %s" % [rounds.size(), tag])
		var spacing: float = world.player.speed * t.hand_row_seconds / boss.pace()
		var walls: Array[int] = []
		for n: int in rounds:
			var r: Dictionary = rounds[n]["round"]
			var path: Array = r["path"]
			var count: int = int(r["rows"])
			check(count == t.rows_for(n), "round %d has %d rows (%d) %s" % [n, t.rows_for(n), count, tag])
			check(path.size() == count + 1 and int(path[0]) == int(r["lane"]), "its doors start from the runner's lane %s" % tag)
			var spread: bool = true
			var doors_ok: bool = true
			var forced: bool = true
			var full: bool = true
			var wall_ok: bool = true
			for i: int in count:
				var at: float = float(r["at"]) + i * spacing
				var door: int = int(path[i + 1])
				var leave: int = int(path[i])
				doors_ok = doors_ok and absi(door - leave) == 1
				var floors: Array[int] = []
				var row_walls: Array[int] = []
				for m: Dictionary in rounds[n]["mists"]:
					if int(m["row"]) != i:
						continue
					spread = spread and absf(float(m["at"]) - at) < 0.01 and int(m["door"]) == door
					if int(m["side"]) == 0:
						floors.append(int(m["lane"]))
					else:
						row_walls.append(int(m["side"]))
				forced = forced and floors.has(leave) and not floors.has(door)
				full = full and floors.size() == lanes - 1
				wall_ok = wall_ok and row_walls.size() == t.wall_hands_per_row
				for s: int in row_walls:
					var outer: int = 0 if s < 0 else lanes - 1
					wall_ok = wall_ok and outer != door and floors.has(outer)
					if not walls.has(s):
						walls.append(s)
			check(spread, "round %d's rows stand %.1f m apart along the street (%.2f s at run speed), each its own distance %s" % [
				n, spacing, t.hand_row_seconds, tag])
			check(doors_ok, "each row's door is one lane over from the last %s" % tag)
			check(forced, "every row stands in the lane the runner kept free at the row before, never in its own door: a lane switch at every row %s" % tag)
			check(full, "every floor lane but the door has a hand %s" % tag)
			check(wall_ok, "every row has its wall hand, never beside a door in an outer lane, only over an outer lane with its own hand %s" % tag)
		check(walls.has(-1) and walls.has(1), "the rounds attack both side walls %s" % tag)
		boss.hands.clear()
		check(boss.hands.rounds == 4 and boss.hands.active.is_empty(),
			"clearing hands between phases keeps the progression and frees every rig %s" % tag)
		var next: Dictionary = boss.hands.plan()
		check(not next.is_empty() and (next["rows"] as Array).size() == t.rows_for(5),
			"the next phase keeps its rounds' size instead of starting over (%d rows) %s" % [t.rows_for(5), tag])
		# Reuse the same rigs as wall hands, then query the real physics shapes.
		var at: float = world.player.distance + 20.0
		boss.hands.start({"at": at, "spots": [{"lane": 0, "side": -1}, {"lane": lanes - 1, "side": 1}]})
		for h: Dictionary in boss.hands.active:
			h["stage"] = SleepTakerHands.Stage.RISE
			h["t"] = boss.tuning.hand_rise_seconds
		boss.hands.tick(0.0)
		await tree.physics_frame
		for h: Dictionary in boss.hands.active:
			var rig: Dictionary = h["rig"]
			var hz: Hazard = rig["hazard"]
			var side: int = int(h["side"])
			var root: Node3D = rig["root"]
			var visual: Node3D = rig["visual"]
			check(visual.global_basis.y.dot(Vector3(-side, 0.0, 0.0)) > 0.99 \
				and is_equal_approx(absf(root.global_position.x), world.geo.wall_x()),
				"the wall hand and its mist face inward from the wall %s" % tag)
			var query := PhysicsShapeQueryParameters3D.new()
			var box := BoxShape3D.new()
			var height: float = world.tuning.hurtbox_size.y
			box.size = Vector3(height, world.tuning.hurtbox_size.x, world.tuning.hurtbox_size.z)
			query.shape = box
			query.collision_mask = TrackBuilder.LAYER_HAZARD
			query.collide_with_areas = true
			query.collide_with_bodies = false
			query.transform.origin = root.global_position + Vector3(-side * height * 0.5, 0.0, 0.0)
			var contacts: Array[Dictionary] = world.get_world_3d().direct_space_state.intersect_shape(query)
			var hits: bool = false
			for contact: Dictionary in contacts:
				hits = hits or contact["collider"] == hz
			check(hits and hz.is_active(), "a wall runner contacts the live wall hand %s" % tag)
			box.size = world.tuning.hurtbox_size
			query.transform.origin = Vector3(world.geo.lane_x(int(h["lane"])), height * 0.5, -at)
			check(world.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),
				"the wall hand leaves a grounded floor runner safe %s" % tag)
		boss.hands.clear()
		check(boss.hands.hazards().all(func(hz: Hazard) -> bool: return not hz.is_active()),
			"clearing a round disables every damage box %s" % tag)
		boss.hands.start({"lane": 0, "at": at})
		var reused: Hazard = (boss.hands.active[0]["rig"] as Dictionary)["hazard"]
		check(is_equal_approx(reused.size.y, boss.tuning.hand_height) and reused.position.x == 0.0 \
			and is_equal_approx(reused.position.y, boss.tuning.hand_height * 0.5),
			"a reused wall rig restores its floor-hand hitbox %s" % tag)
		await sim.free_world(world)


## Planning a round on a plain street: from every floor lane a round of the most rows comes with its way
## through (the router's), never a hand in a door; a whole round's hands fill the pool; its numbers are
## respected (hand_rows_max, hand_row_open, wall_hands_per_row); a round takes the rows that are over in
## time, never fewer than hand_rows_min; never a round at a ceiling rider.
func _test_hands_planning() -> void:
	for lanes: int in LANES:
		var tag: String = "(%d lanes)" % lanes
		var pair: Array = _fight(_plain_def("hands", false), lanes)
		var world: RunWorld = pair[0]
		var boss: SleepTaker = pair[1]
		var t: SleepTakerTuning = boss.tuning
		await tree.physics_frame
		for lane: int in lanes:
			world.player.lane = lane
			boss.hands.rounds = 3
			var plan: Dictionary = boss.hands.plan()
			check(not plan.is_empty() and bool((plan["route"] as Dictionary)["ok"]) and int((plan["path"] as Array)[0]) == lane
				and (plan["rows"] as Array).size() == t.hand_rows_max,
				"a round of %d rows, with a way through it, can be planned from floor lane %d %s" % [t.hand_rows_max, lane, tag])
			if plan.is_empty():
				continue
			var clean: bool = true
			for row: Dictionary in plan["rows"]:
				for spot: Dictionary in row["spots"]:
					clean = clean and (int(spot["side"]) != 0 or not (row["open"] as Array).has(int(spot["lane"])))
			check(clean, "no hand stands in a row's door %s" % tag)
			boss.hands.start(plan)
			check(boss.hands.plan().is_empty() and int(plan["count"]) == boss.hands.pool_size(),
				"its biggest round fills the pool (%d hands): no other comes meanwhile %s" % [int(plan["count"]), tag])
			boss.hands.clear()
		world.player.lane = lanes / 2
		boss.hands.rounds = 10
		t.hand_rows_max = 2
		check((boss.hands.plan()["rows"] as Array).size() == 2, "hand_rows_max is respected %s" % tag)
		t.hand_rows_max = 4
		t.hand_row_open = 2
		var open: Dictionary = boss.hands.plan()
		var two: bool = not open.is_empty()
		for row: Dictionary in open.get("rows", []):
			var floors: int = 0
			for spot: Dictionary in row["spots"]:
				floors += 1 if int(spot["side"]) == 0 else 0
			two = two and (row["open"] as Array).size() == 2 and floors == lanes - 2
		check(two, "hand_row_open is respected: two lanes open in every row %s" % tag)
		t.hand_row_open = 1
		for walls: int in [0, 2]:
			t.wall_hands_per_row = walls
			var plan: Dictionary = boss.hands.plan()
			var ok: bool = not plan.is_empty()
			for row: Dictionary in plan.get("rows", []):
				var count: int = 0
				for spot: Dictionary in row["spots"]:
					count += 1 if int(spot["side"]) != 0 else 0
				var door: int = int(row["door"])
				var most: int = 2 if door != 0 and door != lanes - 1 else 1
				ok = ok and count == mini(walls, most)
			check(ok, "wall_hands_per_row %d is respected %s" % [walls, tag])
		t.wall_hands_per_row = 1
		# A budget: the rows that are over in time, never fewer than hand_rows_min.
		var v: float = world.player.speed
		var two_rows: float = boss.hands.warning_seconds() + (boss.hands.row_spacing(v) + boss.hands.over_distance()) / v + 0.05
		var fit: Dictionary = boss.hands.plan(two_rows)
		check(not fit.is_empty() and (fit["rows"] as Array).size() == 2, "a round takes the rows that are over in time %s" % tag)
		check(boss.hands.plan(two_rows - 0.5).is_empty(), "and waits rather than come with fewer than hand_rows_min %s" % tag)
		world.player.surface = Player.Surface.CEILING
		check(boss.hands.plan().is_empty(), "hands never come at a ceiling rider %s" % tag)
		await sim.free_world(world)


## The owner's spread hands, proved escapable: in each phase (its pace: rows closer together, warnings
## shorter), at the reference 18 m/s and the Dead Zone's 24.2, a runner who moves REACTION seconds after a
## round's mists show finds its way through every round (the router the round was planned by, with the
## real lane switch time), switches lanes at every row, and following it on real physics gets through
## every round without god mode or armor: from every lane in the first phase, from the edges and the
## middle in the others (the whole fight at both speeds, test_sleep_taker_fight, plays the rest).
func _test_hands_routes() -> void:
	for speed: float in SPEEDS:
		for phase: int in 3:
			if speed > MovementTuning.REFERENCE_SPEED + 0.5 and phase < 2:
				continue
			for lanes: int in LANES:
				await _hands_routes(lanes, speed, phase)


func _hands_routes(lanes: int, speed: float, phase: int) -> void:
	var tag: String = "(%d lanes, %.1f m/s, phase %d)" % [lanes, speed, phase + 1]
	var starts: Array[int] = []
	if phase == 0 and speed <= MovementTuning.REFERENCE_SPEED + 0.5:
		for l: int in lanes:
			starts.append(l)
	else:
		starts.assign([0, lanes / 2, lanes - 1])
	var survived: int = 0
	var rounds: int = 0
	var found: bool = true
	var switching: bool = true
	var cause: Array = [""]
	for start: int in starts:
		var pair: Array = _fight(_plain_def("hands", false), lanes, speed, phase)
		var world: RunWorld = pair[0]
		var boss: SleepTaker = pair[1]
		world.player.lane = start
		var bot := SleepTakerBot.new(boss)
		bot.home_lane = start
		bot.reaction = REACTION
		world.player.died.connect(func(c: String) -> void: cause[0] = c)
		await _run(world, 40.0, func() -> bool: return boss.hands.rounds >= 3 and not boss.hands.busy(), func() -> void: bot.step())
		if world.player.alive and boss.hands.rounds >= 3:
			survived += 1
		rounds += boss.hands.rounds
		found = found and bot.routes_found == boss.hands.rounds and bot.routes_missing == 0
		var by_round: Dictionary = _rounds(boss)
		var k: int = 0
		for e: Dictionary in bot.log:
			if e["action"] == &"round":
				k += 1
				var rows: int = int((by_round[k]["round"] as Dictionary)["rows"]) if by_round.has(k) else -1
				switching = switching and String(e["why"]) == "%d switches" % rows
		await sim.free_world(world)
	check(survived == starts.size(), "a runner moving %.2f s after the mists show gets through every round from lanes %s (%d of %d) %s%s" % [
		REACTION, starts, survived, starts.size(), tag, "" if survived == starts.size() else ": %s" % cause[0]])
	check(found and rounds >= 3 * starts.size(), "it finds its way through every round as the round was planned (%d rounds) %s" % [rounds, tag])
	check(switching, "its way switches lanes at every row of every round %s" % tag)


func _test_hands_same_every_attempt() -> void:
	var logs: Array[String] = []
	for attempt: int in 2:
		var pair: Array = _fight(_plain_def("hands", false), 5)
		var world: RunWorld = pair[0]
		var boss: SleepTaker = pair[1]
		var bot := SleepTakerBot.new(boss)
		await _run(world, 30.0, func() -> bool: return boss.hands.rounds >= 3 and not boss.hands.busy(), func() -> void: bot.step())
		var line: PackedStringArray = []
		for e: Dictionary in boss.events:
			if e["event"] in [&"mist", &"hand"]:
				line.append("%s %.3f %d %d %d %.2f" % [e["event"], e["t"], e["row"], e["side"], e["lane"], e["at"]])
		logs.append(" | ".join(line))
		await sim.free_world(world)
	check(logs[0] == logs[1] and logs[0].contains("mist"), "every attempt plays the same rounds of hands")


# --- The real arena ----------------------------------------------------------------------------

## The whole pattern as it comes, on its real arena (its holes and fences, twice as many holes as first
## built, its wall gaps, the refuges, rounds of hands with their wall hands and lights out, and its
## generators), for a runner who reads it but lets every generator go by (so the fight never moves on: GDD
## §10, it keeps cycling its pattern): through a whole lap at every lane count, without god mode or armor;
## the slash's lane escape at 5 and 6 lanes too. (At the Dead Zone's 24.2 m/s, the whole fight on its
## arena at every lane count: test_sleep_taker_fight.)
func _test_real_arena() -> void:
	for lanes: int in LANES:
		for escape: StringName in _escapes(lanes, MovementTuning.REFERENCE_SPEED):
			await _real_arena(lanes, escape, MovementTuning.REFERENCE_SPEED)


func _real_arena(lanes: int, escape: StringName, speed: float) -> void:
	var pair: Array = _fight(def, lanes, speed)
	var world: RunWorld = pair[0]
	var boss: SleepTaker = pair[1]
	var bot := SleepTakerBot.new(boss, escape)
	bot.reaction = REACTION
	bot.smashes = false
	var lap: float = boss.arena.lap_length
	var cause: Array = [""]
	world.player.died.connect(func(c: String) -> void: cause[0] = c)
	await _run(world, 90.0, func() -> bool: return world.player.distance >= lap + 100.0 * boss.run_pace(),
		func() -> void: bot.step())
	var tag: String = "(%d lanes, %s, %.1f m/s)" % [lanes, escape, speed]
	check(world.player.alive, "a runner who reads it gets through a whole lap and more %s%s" % [tag,
		"" if world.player.alive else ": %s at %.0f m, %.1f s" % [cause[0], world.player.distance, boss.fight_time()]])
	check(boss.slash.strikes >= 4 and boss.hands.rounds >= 2 and boss.dark.count >= 1,
		"every attack came: %d slashes, %d rounds of hands (%d hands), %d lights out %s" % [boss.slash.strikes, boss.hands.rounds,
		boss.hands.count, boss.dark.count, tag])
	var wall_hands: int = 0
	var rows: int = 0
	for e: Dictionary in _events(boss, &"mist"):
		wall_hands += 1 if int(e["side"]) != 0 else 0
	for e: Dictionary in _events(boss, &"round"):
		rows += int(e["rows"])
	check(wall_hands >= rows / 2 and bot.routes_found == boss.hands.rounds and bot.routes_missing == 0,
		"the hands reach in from the walls on most rows (%d of %d rows), and every round had its way through %s" % [wall_hands,
		rows, tag])
	check(not boss.arena.layout.wall_gaps.is_empty(), "its walls have their gaps %s" % tag)
	check(_events(boss, &"refuge_missed").is_empty(), "no refuge went by without its slash %s" % tag)
	check(boss.lure.count >= 2 and boss.lure.missed == boss.lure.lures and boss.phase_index == 0,
		"generators keep coming while it lets them go by (%d, %d lures), and the fight stays where it is %s" % [
		boss.lure.count, boss.lure.lures, tag])
	if lanes == 5 and escape == &"pad":
		print("  Sleep Taker on its arena (5 lanes, %.1f m/s, generators let go by): %.0f s of pattern, %d slashes, %d hands, %d lights out, %d generators" % [
			speed, boss.fight_time() - boss.phase().intro_seconds, boss.slash.count, boss.hands.count, boss.dark.count, boss.lure.count])
	await sim.free_world(world)

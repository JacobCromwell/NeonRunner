extends TestSuite
## The Sewer Swarm's phase 2, Surrounded (GDD §10; task E4b), from the phase's start (as a retry from its
## checkpoint resumes it), at 3, 5 and 6 lanes and 18 and 21.8 m/s:
## - a runner who reads it (SewerSwarmBot: no god mode, no armor) baits the rest of the clusters into fences
##   and holes, from behind and from ahead, and wins the phase, at every lane count and both speeds;
## - every strike from behind is warned (its chitter, the wave rising behind the runner and curling over their
##   lane, the red line down the lane ahead) behind_warning_seconds before it crashes down, locks
##   behind_lock_seconds before, and hits only through its hitbox, live only from the crash; from every lane
##   there's a way out of it, at both speeds;
## - a strike from behind baited into a fence or a hole ahead is destroyed there, in front of the runner, its
##   line locked from the runner to the bait and no further;
## - the swarm climbs one wall at a time for climb_seconds, sides alternating: one wall is always free, the
##   climbed one refuses entry (the clank and the bump) while the other takes the runner, and it never climbs
##   the wall the runner is on;
## - nobody baiting: the surges keep coming from behind and ahead in turn, each warned as long as the last, and
##   phase 2 never ends (no time limit, no escalation).

const BOSS_PATH: String = "res://data/bosses/gangland_boss.tres"
const LANES: Array[int] = [3, 5, 6]
const SPEEDS: Array[float] = [18.0, 21.8]
## Surrounded's index in the fight's phases.
const PHASE: int = 1
## A player's reaction: the runner moves this long after a warning starts or locks.
const REACTION: float = 0.35

var sim: RunSim
var def: BossDef


func run() -> void:
	sim = RunSim.new(tree, tuning)
	var slot := load(BOSS_PATH) as BossDef
	def = slot if slot != null and slot.is_built() else null
	if def == null:
		check(false, "the Sewer Swarm's fight is built")
		return
	await _test_wins_phase_two()
	await _test_behind_warned()
	await _test_behind_escapes()
	await _test_behind_baits()
	await _test_climb()
	await _test_climb_waits()
	await _test_keeps_cycling()


# --- Helpers -------------------------------------------------------------------------------------

## The fight at `lanes` and `speed` m/s from Surrounded's start: [world, boss]. `p_def` may carry a tuning of
## its own.
func _fight(p_def: BossDef, lanes: int, speed: float = 0.0) -> Array:
	var boss := BossEncounter.create(p_def) as SewerSwarm
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
	ctx.boss_resume = {"phase": PHASE}
	var arena: BossArena = boss.plan_arena(ctx)
	var world: RunWorld = sim.build_world(arena.layout, null, t, ctx.config)
	boss.setup(world, ctx, arena)
	return [world, boss]


## The boss with a tuning of its own, changed by `edit` (it gets a copy).
func _with(edit: Callable) -> BossDef:
	var out: BossDef = def.duplicate() as BossDef
	var t: SewerSwarmTuning = (def.tuning as SewerSwarmTuning).duplicate() as SewerSwarmTuning
	edit.call(t)
	out.tuning = t
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


## Surge `n`'s event of kind `event`, or {}.
func _of(boss: BossEncounter, event: StringName, n: int) -> Dictionary:
	for e: Dictionary in _events(boss, event):
		if int(e["n"]) == n:
			return e
	return {}


## Puts the runner on the street in `lane` at its distance now, in the middle of the lane.
func _place(player: Player, lane: int) -> void:
	player.lane = lane
	player.set(&"_x", player.geo.lane_x(lane))
	player.set(&"_switch_t", 1.0)
	player.set(&"_bumping", false)
	player.surface = Player.Surface.FLOOR
	player.h = 0.0
	player.vh = 0.0
	player.grounded = true
	player.in_pit = false


## True if both walls are taken away where the runner is (the climb must always leave one free).
func _both_walls_blocked(player: Player) -> bool:
	return bool(player.call(&"_wall_blocked", -1)) and bool(player.call(&"_wall_blocked", 1))


# --- Phase 2, won by baiting ---------------------------------------------------------------------

## A runner who reads it baits the rest of the clusters, from behind and from ahead, and wins phase 2, at every
## lane count and both speeds, without god mode or armor; every strike from behind along the way is warned and
## locks on time; the swarm climbs the walls meanwhile, one at a time.
func _test_wins_phase_two() -> void:
	for speed: float in SPEEDS:
		for lanes: int in LANES:
			await _wins(lanes, speed)


func _wins(lanes: int, speed: float) -> void:
	var tag: String = "(%d lanes, %.1f m/s)" % [lanes, speed]
	var pair: Array = _fight(def, lanes, speed)
	var world: RunWorld = pair[0]
	var boss: SewerSwarm = pair[1]
	var t: SewerSwarmTuning = boss.tuning
	var bot := SewerSwarmBot.new(boss)
	bot.reaction = REACTION
	var cause: Array = [""]
	world.player.died.connect(func(c: String) -> void: cause[0] = c)
	var both: Array = [0]
	await _run(world, 150.0, func() -> bool: return boss.phase_index > PHASE, func() -> void:
		bot.step()
		if boss.climb.blocked_side() != 0 and _both_walls_blocked(world.player):
			both[0] = int(both[0]) + 1)
	check(boss.phase_index > PHASE and world.player.alive, "a runner who baits wins phase 2 %s%s" % [tag,
		"" if world.player.alive else ": %s at %.0f m" % [cause[0], world.player.distance]])
	var hits: int = def.phase_list()[PHASE].hits
	var destroyed: Array[Dictionary] = _events(boss, &"cluster_destroyed")
	var baited: int = 0
	for e: Dictionary in destroyed:
		baited += 1 if e["cause"] in [&"fence", &"hole"] else 0
	check(destroyed.size() == hits and baited == hits and _events(boss, &"surge_hit").is_empty(),
		"the rest of the clusters (%d) baited into fences or holes end it, none ever touching the runner %s" % [hits, tag])
	var behind: int = 0
	var ahead: int = 0
	for b: Dictionary in _events(boss, &"surge_bait"):
		if bool(b["behind"]):
			behind += 1
		else:
			ahead += 1
	check(behind >= 1 and ahead >= 1, "baited from behind (%d) and from ahead (%d) %s" % [behind, ahead, tag])
	# Every strike from behind: its chitter with its warning, the lock and the crash on time.
	var timed: bool = behind >= 1
	var shortest: float = INF
	for w: Dictionary in _events(boss, &"surge_warn"):
		if not bool(w["behind"]):
			continue
		var n: int = int(w["n"])
		var lock: Dictionary = _of(boss, &"surge_lock", n)
		var crash: Dictionary = _of(boss, &"surge_crash", n)
		var heard: bool = false
		for s: Dictionary in _sounds(boss, &"swarm_wave"):
			heard = heard or absf(float(s["t"]) - float(w["t"])) < 0.001
		if lock.is_empty() or crash.is_empty() or not heard:
			timed = false
			continue
		timed = timed and absf(float(lock["t"]) - float(w["t"]) - (t.behind_warning_seconds - t.behind_lock_seconds)) < 0.03
		shortest = minf(shortest, float(crash["t"]) - float(w["t"]))
	check(timed and shortest >= t.behind_warning_seconds - 0.1,
		"every strike from behind is heard and seen from its warning, locks %.1f s later and crashes no sooner than %.1f s after it (%.2f s) %s" % [
		t.behind_warning_seconds - t.behind_lock_seconds, t.behind_warning_seconds, shortest, tag])
	check(int(both[0]) == 0 and not _events(boss, &"climb").is_empty(),
		"the swarm climbs the walls meanwhile (%d climbs), never both %s" % [_events(boss, &"climb").size(), tag])
	var ends: Array[Dictionary] = _events(boss, &"phase_end")
	var took: float = float(ends[0]["t"]) if not ends.is_empty() else -1.0
	check(took > 0.0 and took <= 100.0, "phase 2 takes %.1f s %s" % [took, tag])
	if lanes == 5:
		print("  Sewer Swarm phase 2 (5 lanes, %.1f m/s): %.1f s, %d surges, %d climbs" % [speed, took,
			_events(boss, &"surge_warn").size(), _events(boss, &"climb").size()])
	await sim.free_world(world)


# --- Strikes from behind ---------------------------------------------------------------------------

## A runner who stands in a strike from behind's lane (with armor to spare) is hit no sooner than
## behind_warning_seconds after its warning starts, through its hitbox, live only from the crash; from the
## warning on the wave rises behind them in their lane and curls over it, its chitter rises and the red line
## runs down the lane ahead; at the lock the wave stands risen over the locked lane. At both speeds.
func _test_behind_warned() -> void:
	var only_behind: BossDef = _with(func(t: SewerSwarmTuning) -> void: t.surge_sides = PackedStringArray(["behind"]))
	for speed: float in SPEEDS:
		var tag: String = "(%.1f m/s)" % speed
		var pair: Array = _fight(only_behind, 5, speed)
		var world: RunWorld = pair[0]
		var boss: SewerSwarm = pair[1]
		var t: SewerSwarmTuning = boss.tuning
		world.player.armor = 50
		var bot := SewerSwarmBot.new(boss)
		bot.baits = false
		bot.dodges = false
		var seen := {"early": 0, "warns": 0, "aim": 0, "locks": 0, "wave_ok": 0, "n": -1, "locked_n": -1, "curl": true}
		await _run(world, 60.0, func() -> bool: return not _events(boss, &"surge_hit").is_empty(), func() -> void:
			bot.step()
			var s: SwarmSurges = boss.surges
			var d: float = world.player.distance
			if not s.surge.is_empty() and int(s.surge["n"]) != int(seen["n"]):
				seen["n"] = int(s.surge["n"])
				seen["warns"] = int(seen["warns"]) + 1
				if s.aim.visible:
					seen["aim"] = int(seen["aim"]) + 1
			if not s.surge.is_empty() and int(s.surge["locked"]) >= 0 and int(s.surge["n"]) != int(seen["locked_n"]):
				seen["locked_n"] = int(s.surge["n"])
				seen["locks"] = int(seen["locks"]) + 1
				var c: SwarmCluster = s.surge["cluster"]
				var shape := Vector4(c.crowd.material.get_shader_parameter(&"wave_shape"))
				if c.stage == SwarmCluster.Stage.WAVE and c.crowd.visible and c.rise >= 0.99 and c.wave_at < d - 1.0 \
						and absf(c.lane_x - world.geo.lane_x(int(s.surge["locked"]))) < 0.3 and shape.y > d - c.wave_at:
					seen["wave_ok"] = int(seen["wave_ok"]) + 1
			for c: SwarmCluster in boss.clusters:
				if is_instance_valid(c) and c.hitbox.is_active() and (s.surge.is_empty() or s.surge["cluster"] != c
						or s.stage != SwarmSurges.Stage.CHARGE):
					seen["early"] = int(seen["early"]) + 1)
		var hits: Array[Dictionary] = _events(boss, &"surge_hit")
		check(not hits.is_empty() and int(hits[0]["outcome"]) == DamageRules.Outcome.BLOCKED_ARMOR,
			"a strike from behind that catches the runner is an enemy attack: their armor blocks it %s" % tag)
		if hits.is_empty():
			await sim.free_world(world)
			continue
		var warn: Dictionary = _of(boss, &"surge_warn", int(hits[0]["n"]))
		var lead: float = float(hits[0]["t"]) - float(warn.get("t", INF))
		check(bool(warn.get("behind", false)) and lead >= t.behind_warning_seconds - 0.1,
			"it hits %.2f s after its warning starts (behind_warning_seconds %.1f) %s" % [lead, t.behind_warning_seconds, tag])
		check(int(seen["early"]) == 0, "its hitbox is live only from the crash %s" % tag)
		check(int(seen["aim"]) == int(seen["warns"]) and int(seen["warns"]) > 0 and _sounds(boss, &"swarm_wave").size() >= int(seen["warns"]),
			"its chitter and the red line ahead start with each warning (%d) %s" % [int(seen["warns"]), tag])
		check(int(seen["locks"]) > 0 and int(seen["wave_ok"]) == int(seen["locks"]),
			"at each lock the wave stands risen behind the runner over the locked lane, its crest curling on past them %s" % tag)
		check(_sounds(boss, &"swarm_surge").size() >= 1 and not _events(boss, &"surge_crash").is_empty(),
			"then it crashes down with its rush %s" % tag)
		await sim.free_world(world)


## From every lane, at every lane count, a runner who doesn't bait gets out of every strike from behind's way
## and is never touched (on a stretch with bait spots closer together, every surge from behind); at 21.8 m/s
## too, from the outer lanes of the narrowest and the widest street.
func _test_behind_escapes() -> void:
	var dense: BossDef = _with(func(t: SewerSwarmTuning) -> void:
		t.surge_sides = PackedStringArray(["behind"])
		t.bait_first = 140.0
		t.bait_spacing = 100.0)
	var runs: Array[Array] = []
	for lanes: int in LANES:
		for home: int in [0, lanes / 2, lanes - 1]:
			runs.append([lanes, home, 18.0])
	for lanes: int in [3, 6]:
		for home: int in [0, lanes - 1]:
			runs.append([lanes, home, 21.8])
	for r: Array in runs:
		var lanes: int = int(r[0])
		var home: int = int(r[1])
		var speed: float = float(r[2])
		var pair: Array = _fight(dense, lanes, speed)
		var world: RunWorld = pair[0]
		var boss: SewerSwarm = pair[1]
		var bot := SewerSwarmBot.new(boss)
		bot.baits = false
		bot.home_lane = home
		bot.reaction = REACTION
		await _run(world, 50.0, func() -> bool:
			return boss.phase_index > PHASE or (_events(boss, &"surge_lock").size() >= 4 and not boss.surges.busy()),
			func() -> void: bot.step())
		var locks: Array[Dictionary] = _events(boss, &"surge_lock")
		var in_lane: int = 0
		var all_behind: bool = not locks.is_empty()
		for l: Dictionary in locks:
			in_lane += 1 if int(l["lane"]) == home else 0
			all_behind = all_behind and bool(l["behind"])
		check(world.player.alive and _events(boss, &"surge_hit").is_empty() and locks.size() >= 3 and in_lane >= 2 and all_behind,
			"from lane %d of %d at %.1f m/s: out of the way of every strike from behind (%d, %d down its lane)" % [
			home, lanes, speed, locks.size(), in_lane])
		await sim.free_world(world)


## A strike from behind dodged in time surges on into the fence or the hole ahead in its lane: shocked or
## falling, destroyed in front of the runner; its line locked from the runner to the bait, never past it.
func _test_behind_baits() -> void:
	for r: Array in [["fence", 5, 18.0], ["hole", 6, 21.8]]:
		var kind: String = r[0]
		var lanes: int = int(r[1])
		var speed: float = float(r[2])
		var tag: String = "(%s, %d lanes, %.1f m/s)" % [kind, lanes, speed]
		var only: BossDef = _with(func(t: SewerSwarmTuning) -> void:
			t.bait_kinds = PackedStringArray([kind])
			t.surge_sides = PackedStringArray(["behind"]))
		var pair: Array = _fight(only, lanes, speed)
		var world: RunWorld = pair[0]
		var boss: SewerSwarm = pair[1]
		var start_health: float = boss.health
		var bot := SewerSwarmBot.new(boss)
		bot.reaction = REACTION
		var line: Dictionary = {}
		await _run(world, 40.0, func() -> bool: return not _events(boss, &"surge_bait").is_empty(), func() -> void:
			bot.step()
			var s: SwarmSurges = boss.surges
			if line.is_empty() and s.stage == SwarmSurges.Stage.CHARGE and s.is_behind() and not (s.surge["bait"] as Dictionary).is_empty():
				var lane: int = int(s.surge["locked"])
				var bait_at: float = float(s.surge["bait"]["at"])
				var d: float = world.player.distance
				line["on"] = boss.props.warned(lane, d + 1.0, bait_at - 0.5)
				line["short"] = not boss.props.warned(lane, bait_at + 1.0, bait_at + 30.0))
		var baits: Array[Dictionary] = _events(boss, &"surge_bait")
		check(baits.size() == 1 and baits[0]["kind"] == kind and bool(baits[0]["behind"]) and world.player.alive,
			"a strike from behind baited into a %s ahead %s" % [kind, tag])
		if baits.is_empty():
			await sim.free_world(world)
			continue
		var destroyed: Array[Dictionary] = _events(boss, &"cluster_destroyed")
		check(destroyed.size() == 1 and destroyed[0]["cause"] == (&"fence" if kind == "fence" else &"hole"),
			"is destroyed by it %s" % tag)
		check(float(baits[0]["at"]) - float(baits[0]["d"]) >= 4.0, "in front of the runner (%.1f m ahead) %s" % [
			float(baits[0]["at"]) - float(baits[0]["d"]), tag])
		check(_events(boss, &"surge_hit").is_empty() and is_equal_approx(boss.health, start_health - boss.hit_damage())
			and world.score.bonuses.get(&"swarm_bait", 0) == boss.tuning.bait_score,
			"the runner untouched, the boss hurt (its hit) and the bait scored %s" % tag)
		check(bool(line.get("on", false)) and bool(line.get("short", false)),
			"its line locked from the runner to the bait, never past it %s" % tag)
		check(_sounds(boss, &"swarm_shock" if kind == "fence" else &"swarm_fall").size() == 1, "with its sound %s" % tag)
		await sim.free_world(world)


# --- The wall climb --------------------------------------------------------------------------------

## The swarm climbs one wall at a time for climb_seconds, climb_gap_seconds apart, sides alternating, seen and
## heard: one wall is always free; never the wall the runner is on. The climbed wall refuses an entry (the
## clank and the bump, no harm) while the other wall takes the runner. At 3 and 6 lanes.
func _test_climb() -> void:
	for lanes: int in [3, 6]:
		var tag: String = "(%d lanes)" % lanes
		var pair: Array = _fight(def, lanes, 18.0)
		var world: RunWorld = pair[0]
		var boss: SewerSwarm = pair[1]
		var t: SewerSwarmTuning = boss.tuning
		var player: Player = world.player
		player.god_mode = true
		var bot := SewerSwarmBot.new(boss)
		bot.baits = false
		var seen := {"both": 0, "on_climbed": 0, "unseen": 0, "frames": 0}
		await _run(world, 30.0, func() -> bool: return _events(boss, &"climb_end").size() >= 3, func() -> void:
			bot.step()
			var c: SwarmClimb = boss.climb
			if _both_walls_blocked(player):
				seen["both"] = int(seen["both"]) + 1
			if c.state == SwarmClimb.State.CLIMB:
				seen["frames"] = int(seen["frames"]) + 1
				if player.surface == Player.Surface.WALL and player.wall_side == c.side:
					seen["on_climbed"] = int(seen["on_climbed"]) + 1
				if c.blocked_side() != c.side or (c.rise > 0.0 and not c.crowd.visible):
					seen["unseen"] = int(seen["unseen"]) + 1)
		var climbs: Array[Dictionary] = _events(boss, &"climb")
		var ends: Array[Dictionary] = _events(boss, &"climb_end")
		check(climbs.size() >= 3 and int(seen["both"]) == 0 and int(seen["on_climbed"]) == 0 and int(seen["frames"]) > 0,
			"it climbs one wall at a time (%d climbs): one wall is always free, never the runner's %s" % [climbs.size(), tag])
		var alternate: bool = climbs.size() >= 3
		var timed: bool = ends.size() >= 3
		for i: int in climbs.size():
			if i > 0:
				alternate = alternate and int(climbs[i]["side"]) == -int(climbs[i - 1]["side"])
			if i < ends.size():
				timed = timed and absf(float(ends[i]["t"]) - float(climbs[i]["t"]) - t.climb_seconds) < 0.05
			if i > 0 and i - 1 < ends.size():
				timed = timed and float(climbs[i]["t"]) - float(ends[i - 1]["t"]) >= t.climb_gap_seconds - 0.02
		check(alternate, "sides alternating %s" % tag)
		check(timed, "each climb lasts %.1f s, %.1f s apart %s" % [t.climb_seconds, t.climb_gap_seconds, tag])
		check(int(seen["unseen"]) == 0 and _sounds(boss, &"swarm_climb").size() == climbs.size(),
			"while it's up its wall is taken away, the swarm seen covering it and heard %s" % tag)
		# The climbed wall refuses an entry; the other takes the runner.
		var moves: Array[StringName] = []
		player.movement_event.connect(func(kind: StringName) -> void: moves.append(kind))
		var ready: Array = [false]
		await _run(world, 15.0, func() -> bool: return bool(ready[0]), func() -> void:
			var c: SwarmClimb = boss.climb
			var d: float = player.distance
			ready[0] = c.state == SwarmClimb.State.CLIMB and c.t >= t.climb_rise_seconds \
				and c.t <= t.climb_seconds - t.climb_rise_seconds - 1.0 and player.surface == Player.Surface.FLOOR \
				and boss.arena.floor_clear(d - 2.0, d + 14.0, 0) and boss.arena.floor_clear(d - 2.0, d + 14.0, lanes - 1))
		check(bool(ready[0]), "a climb with both outer lanes clear to try the walls %s" % tag)
		if bool(ready[0]):
			var side: int = boss.climb.side
			_place(player, 0 if side < 0 else lanes - 1)
			moves.clear()
			player.press(&"move_left" if side < 0 else &"move_right")
			await physics_frames(3)
			check(moves.has(&"wall_blocked") and player.surface == Player.Surface.FLOOR and player.alive,
				"the climbed wall refuses an entry: the clank and the bump, no harm %s" % tag)
			await physics_frames(int(t.climb_rise_seconds * 30.0))
			_place(player, lanes - 1 if side < 0 else 0)
			moves.clear()
			player.press(&"move_right" if side < 0 else &"move_left")
			await physics_frames(3)
			check(moves.has(&"wall_enter") and player.surface == Player.Surface.WALL and player.wall_side == -side,
				"the other wall takes the runner %s" % tag)
		await sim.free_world(world)


## The climb never takes the wall the runner is on: one on that wall as its gap ends holds it off until they've
## left it; then the swarm climbs it.
func _test_climb_waits() -> void:
	var pair: Array = _fight(def, 5, 18.0)
	var world: RunWorld = pair[0]
	var boss: SewerSwarm = pair[1]
	var t: SewerSwarmTuning = boss.tuning
	var player: Player = world.player
	player.god_mode = true
	await _run(world, 15.0, func() -> bool:
		var c: SwarmClimb = boss.climb
		var d: float = player.distance
		var lane: int = 0 if c.side < 0 else 4
		return boss.step == SewerSwarm.Step.FIGHT and c.state == SwarmClimb.State.GAP and c.t >= t.climb_gap_seconds - 0.3 \
			and boss.arena.floor_clear(d - 2.0, d + 10.0, lane))
	var side: int = boss.climb.side
	_place(player, 0 if side < 0 else 4)
	player.press(&"move_left" if side < 0 else &"move_right")
	await physics_frames(3)
	check(player.surface == Player.Surface.WALL and player.wall_side == side, "the runner gets on the wall the swarm climbs next")
	var held: Dictionary = {"started_on_it": false, "past_gap": false, "from": boss.climb.t, "to": 0.0}
	await _run(world, 6.0, func() -> bool: return player.surface != Player.Surface.WALL, func() -> void:
		var c: SwarmClimb = boss.climb
		held["to"] = c.t
		if c.state == SwarmClimb.State.CLIMB and player.surface == Player.Surface.WALL and player.wall_side == side:
			held["started_on_it"] = true
		elif c.t > t.climb_gap_seconds + 0.2:
			held["past_gap"] = true)
	check(not bool(held["started_on_it"]) and bool(held["past_gap"]),
		"it holds off past its gap while the runner is on that wall (its gap %.2f-%.2f s on the wall%s)" % [
		float(held["from"]), float(held["to"]), ", but it climbed" if bool(held["started_on_it"]) else ""])
	await _run(world, 3.0, func() -> bool: return boss.climb.state == SwarmClimb.State.CLIMB)
	check(boss.climb.state == SwarmClimb.State.CLIMB and boss.climb.side == side, "and climbs it once they've left it")
	await sim.free_world(world)


# --- No escalation -----------------------------------------------------------------------------------

## Nobody baits: phase 2 keeps cycling, unhurt, the surges from behind and ahead in turn, each warned as long
## as the last of its kind (GDD §10: no time limit, no escalation), the climbs alternating meanwhile.
func _test_keeps_cycling() -> void:
	var pair: Array = _fight(def, 5, 18.0)
	var world: RunWorld = pair[0]
	var boss: SewerSwarm = pair[1]
	var t: SewerSwarmTuning = boss.tuning
	var start_health: float = boss.health
	var bot := SewerSwarmBot.new(boss)
	bot.baits = false
	bot.avoids_surge_baits = true
	bot.reaction = REACTION
	await _run(world, 150.0, func() -> bool: return _events(boss, &"surge_pass").size() >= 6, func() -> void: bot.step())
	var warns: Array[Dictionary] = _events(boss, &"surge_warn")
	var passes: Array[Dictionary] = _events(boss, &"surge_pass")
	check(world.player.alive and passes.size() >= 6 and boss.phase_index == PHASE and is_equal_approx(boss.health, start_health)
		and _events(boss, &"surge_hit").is_empty(), "no bait, no end: %d surges, still Surrounded, unhurt" % passes.size())
	var in_turn: bool = warns.size() >= 6
	var leads: Dictionary = {}
	var same: bool = true
	for i: int in warns.size():
		var behind: bool = bool(warns[i]["behind"])
		in_turn = in_turn and behind == (t.surge_side(i) == "behind")
		var lock: Dictionary = _of(boss, &"surge_lock", int(warns[i]["n"]))
		if lock.is_empty():
			continue
		var lead: float = float(lock["t"]) - float(warns[i]["t"])
		if leads.has(behind):
			same = same and absf(lead - float(leads[behind])) < 0.02
		else:
			leads[behind] = lead
	var sides: PackedStringArray = []
	for w: Dictionary in warns:
		sides.append("behind" if bool(w["behind"]) else "ahead")
	check(in_turn, "the surges come from behind and ahead in turn (%s)" % ", ".join(sides))
	check(same and leads.size() == 2, "each warned as long as the last of its kind")
	var climbs: Array[Dictionary] = _events(boss, &"climb")
	var alternate: bool = climbs.size() >= 4
	for i: int in range(1, climbs.size()):
		alternate = alternate and int(climbs[i]["side"]) == -int(climbs[i - 1]["side"])
	check(alternate, "the swarm keeps climbing the walls in turn (%d climbs)" % climbs.size())
	await sim.free_world(world)

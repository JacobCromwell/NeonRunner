extends TestSuite
## The Sewer Swarm's phase 1, the Rising (GDD §10; task E4a; its data, crowds and arena: test_sewer_swarm.gd),
## at 3, 5 and 6 lanes, at Gangland's 21.8 m/s and quick play's 18 m/s:
## - a runner who reads it (SewerSwarmBot: no god mode, no armor) baits two clusters into a fence or a hole
##   and wins the phase, at every lane count and both speeds, and again after a death and a retry (through
##   quick play's own restart at 3 lanes, and at 21.8 m/s through RunContext.retry at 6);
## - every surge is warned (the chitter and the red line) warning_seconds before it can hit, and its hitbox is
##   live only from the lock;
## - a surge dodged in time reaches its fence or hole: the cluster is shocked or falls, in front of the runner,
##   whether they switch out of the lane or jump the bait;
## - a surge that catches the runner hits only through its hitbox (an enemy attack: armor blocks it), never
##   when they're in the next lane;
## - from every lane there's a way out of every surge;
## - weapons thin a surging cluster (and only a surging one), the heavy missile's swarm bonus applies, and a
##   cluster thinned to nothing is destroyed and counts;
## - nobody baiting: it keeps cycling the same way, phase 1 never ends (no time limit, no escalation);
## - the standard armor rule, with and without armor at the start;
## - the crowd size changes only the look (the same event log at two crowd sizes), and every attempt plays
##   out the same way.

const BOSS_PATH: String = "res://data/bosses/gangland_boss.tres"
const LANES: Array[int] = [3, 5, 6]
const SPEEDS: Array[float] = [18.0, 21.8]
const GANGLAND_SPEED: float = 21.8
## The retries' streets: one each (every attempt plays the same, and _test_wins_phase_one wins at every count).
const RETRY_LANES: Array[int] = [6]
const QUICK_PLAY_LANES: Array[int] = [3]
## A player's reaction: the runner moves this long after a warning starts or locks.
const REACTION: float = 0.35
## The events compared between fights (determinism, crowd sizes).
const LOGGED: Array[StringName] = [&"surge_warn", &"surge_lock", &"surge_bait", &"surge_pass", &"surge_hit",
	&"cluster_destroyed", &"phase", &"phase_end", &"bait_missed", &"armor_pickup"]

var sim: RunSim
var def: BossDef
## Phase 1's log at 5 lanes and 18 m/s (_test_wins_phase_one), for _test_same_every_attempt.
var _log_5: String = ""


func run() -> void:
	sim = RunSim.new(tree, tuning)
	var slot := load(BOSS_PATH) as BossDef
	def = slot.preview() if slot != null else null
	if def == null:
		check(false, "the Sewer Swarm's fight loads as a preview")
		return
	await _test_wins_phase_one()
	await _test_same_every_attempt()
	await _test_warned_before_hit()
	await _test_baits()
	await _test_hit_only_by_hitbox()
	await _test_escapes()
	await _test_keeps_cycling()
	await _test_weapons()
	await _test_armor_rule()
	await _test_crowd_size()
	await _test_retry()
	await _test_retry_through_quick_play()


# --- Helpers -------------------------------------------------------------------------------------

## The fight at `lanes` and `speed` m/s: [world, boss, context]. `p_def` may carry a tuning of its own.
func _fight(p_def: BossDef, lanes: int, speed: float = 0.0, loadout: Loadout = null, resume: Dictionary = {},
		ctx_in: RunContext = null) -> Array:
	var boss := BossEncounter.create(p_def) as SewerSwarm
	var ctx: RunContext = ctx_in
	if ctx == null:
		var t: MovementTuning = tuning
		if speed > 0.0 and not is_equal_approx(speed, tuning.run_speed):
			t = tuning.duplicate() as MovementTuning
			t.run_speed = speed
		ctx = RunContext.new()
		ctx.mode = RunContext.Mode.QUICK
		ctx.boss = p_def
		ctx.config = BossArena.base_config(p_def)
		ctx.config.lane_count = lanes
		ctx.tuning = t
		ctx.loadout = loadout
		ctx.boss_resume = resume
	var arena: BossArena = boss.plan_arena(ctx)
	var world: RunWorld = sim.build_world(arena.layout, ctx.loadout, ctx.tuning, ctx.config)
	boss.setup(world, ctx, arena)
	return [world, boss, ctx]


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


## What happened in a fight, for comparing fights.
func _fight_log(boss: BossEncounter) -> String:
	var line: PackedStringArray = []
	for e: Dictionary in boss.events:
		if e["event"] in LOGGED:
			var extra: Dictionary = e.duplicate()
			extra.erase("t")
			extra.erase("event")
			line.append("%s %.3f %s" % [e["event"], float(e["t"]), str(extra)])
	return " | ".join(line)


func _phase_one_over(boss: SewerSwarm) -> bool:
	return boss.phase_index >= 1


# --- Phase 1, won by baiting ---------------------------------------------------------------------

## A runner who reads it baits two clusters and wins phase 1, at every lane count and both speeds, without god
## mode or armor; every surge along the way is warned, locks on time and meets its bait ahead of the runner.
func _test_wins_phase_one() -> void:
	for speed: float in SPEEDS:
		for lanes: int in LANES:
			await _wins_phase_one(lanes, speed)


func _wins_phase_one(lanes: int, speed: float) -> void:
	var tag: String = "(%d lanes, %.1f m/s)" % [lanes, speed]
	var pair: Array = _fight(def, lanes, speed)
	var world: RunWorld = pair[0]
	var boss: SewerSwarm = pair[1]
	var t: SewerSwarmTuning = boss.tuning
	var bot := SewerSwarmBot.new(boss)
	bot.reaction = REACTION
	var cause: Array = [""]
	world.player.died.connect(func(c: String) -> void: cause[0] = c)
	await _run(world, 90.0, func() -> bool: return _phase_one_over(boss), func() -> void: bot.step())
	check(_phase_one_over(boss) and world.player.alive, "a runner who baits wins phase 1 %s%s" % [tag,
		"" if world.player.alive else ": %s at %.0f m" % [cause[0], world.player.distance]])
	var destroyed: Array[Dictionary] = _events(boss, &"cluster_destroyed")
	var baited: int = 0
	for e: Dictionary in destroyed:
		baited += 1 if e["cause"] in [&"fence", &"hole"] else 0
	check(destroyed.size() == 2 and baited == 2 and _events(boss, &"surge_hit").is_empty(),
		"two clusters baited into fences or holes end it, and none ever touched the runner %s" % tag)
	var phase_end: Array[Dictionary] = _events(boss, &"phase_end")
	var took: float = float(phase_end[0]["t"]) if not phase_end.is_empty() else -1.0
	check(took > 0.0 and took <= 45.0, "phase 1 takes %.1f s %s" % [took, tag])
	# Every surge: warned (the chitter, the line), locked lock_seconds before the strike, its bait met ahead.
	var warns: Array[Dictionary] = _events(boss, &"surge_warn")
	var locks: Array[Dictionary] = _events(boss, &"surge_lock")
	var baits: Array[Dictionary] = _events(boss, &"surge_bait")
	var chitters: Array[Dictionary] = _sounds(boss, &"swarm_chitter")
	var timed: bool = warns.size() == locks.size() and warns.size() == chitters.size() and not warns.is_empty()
	for i: int in mini(warns.size(), locks.size()):
		timed = timed and absf(float(locks[i]["t"]) - float(warns[i]["t"]) - (t.warning_seconds - t.lock_seconds)) < 0.03
		timed = timed and absf(float(chitters[i]["t"]) - float(warns[i]["t"])) < 0.001
	check(timed, "every surge's chitter and line start together, and it locks %.1f s later %s" % [
		t.warning_seconds - t.lock_seconds, tag])
	var ahead: bool = baits.size() == 2
	for b: Dictionary in baits:
		ahead = ahead and float(b["at"]) - float(b["d"]) >= 4.0
	check(ahead, "each baited cluster meets its fence or hole in front of the runner %s" % tag)
	if lanes == 5 and is_equal_approx(speed, 18.0):
		_log_5 = _fight_log(boss)
	if lanes == 5:
		print("  Sewer Swarm phase 1 (5 lanes, %.1f m/s): %.1f s, %d surges" % [speed, took, warns.size()])
	await sim.free_world(world)


## A second attempt with the same moves plays out as the first did.
func _test_same_every_attempt() -> void:
	var pair: Array = _fight(def, 5, 18.0)
	var world: RunWorld = pair[0]
	var boss: SewerSwarm = pair[1]
	var bot := SewerSwarmBot.new(boss)
	bot.reaction = REACTION
	await _run(world, 90.0, func() -> bool: return _phase_one_over(boss), func() -> void: bot.step())
	var again: String = _fight_log(boss)
	check(_log_5 != "" and again == _log_5 and again.contains("surge_bait"), "every attempt plays out the same way")
	await sim.free_world(world)


# --- Warnings --------------------------------------------------------------------------------------

## A runner who stands in a surge's lane (with armor to spare) is hit no sooner than warning_seconds after its
## warning starts; its hitbox is live only from the lock; the line and the chitter start the warning. At both
## speeds.
func _test_warned_before_hit() -> void:
	for speed: float in SPEEDS:
		var pair: Array = _fight(def, 5, speed)
		var world: RunWorld = pair[0]
		var boss: SewerSwarm = pair[1]
		var t: SewerSwarmTuning = boss.tuning
		world.player.armor = 50
		var bot := SewerSwarmBot.new(boss)
		bot.baits = false
		bot.dodges = false
		var seen := {"early_hitbox": 0, "aim_at_warn": 0, "warns": 0}
		var last_warn: Array = [-1]
		await _run(world, 80.0, func() -> bool: return not _events(boss, &"surge_hit").is_empty(), func() -> void:
			bot.step()
			var s: SwarmSurges = boss.surges
			if not s.surge.is_empty() and int(s.surge["n"]) != int(last_warn[0]):
				last_warn[0] = int(s.surge["n"])
				seen["warns"] = int(seen["warns"]) + 1
				if s.aim.visible:
					seen["aim_at_warn"] = int(seen["aim_at_warn"]) + 1
			for c: SwarmCluster in boss.clusters:
				if is_instance_valid(c) and c.hitbox.is_active() and (s.surge.is_empty() or s.surge["cluster"] != c
						or s.stage != SwarmSurges.Stage.CHARGE):
					seen["early_hitbox"] = int(seen["early_hitbox"]) + 1)
		var hits: Array[Dictionary] = _events(boss, &"surge_hit")
		var tag: String = "(%.1f m/s)" % speed
		check(not hits.is_empty() and int(hits[0]["outcome"]) == DamageRules.Outcome.BLOCKED_ARMOR,
			"a surge that catches the runner is an enemy attack: their armor blocks it %s" % tag)
		if hits.is_empty():
			await sim.free_world(world)
			continue
		var n: int = int(hits[0]["n"])
		var warn: Dictionary = {}
		for w: Dictionary in _events(boss, &"surge_warn"):
			if int(w["n"]) == n:
				warn = w
		var lead: float = float(hits[0]["t"]) - float(warn.get("t", INF))
		check(lead >= t.warning_seconds - 0.1, "it hits %.2f s after its warning starts (warning_seconds %.1f) %s" % [
			lead, t.warning_seconds, tag])
		check(int(seen["early_hitbox"]) == 0, "its hitbox is live only while it charges, from the lock %s" % tag)
		check(int(seen["aim_at_warn"]) == int(seen["warns"]) and int(seen["warns"]) > 0,
			"the red line shows from each warning's start %s" % tag)
		check(_sounds(boss, &"swarm_chitter").size() >= int(seen["warns"]) and _sounds(boss, &"swarm_surge").size() >= 1,
			"with the rising chitter, then the rush at the lock %s" % tag)
		await sim.free_world(world)


# --- Baits -------------------------------------------------------------------------------------------

## A surge dodged in time reaches its fence or hole: shocked or falling, destroyed, in front of the runner,
## whether the runner switches out of the bait's lane or jumps the bait; the line locks from the bait to the
## cluster, never on toward the runner.
func _test_baits() -> void:
	for kind: String in ["fence", "hole"]:
		for escape: StringName in [&"switch", &"jump"]:
			var lanes: int = 3 if escape == &"jump" else 5
			var speed: float = GANGLAND_SPEED if kind == "hole" else 18.0
			await _bait(kind, escape, lanes, speed)


func _bait(kind: String, escape: StringName, lanes: int, speed: float) -> void:
	var tag: String = "(%s, %s, %d lanes, %.1f m/s)" % [kind, escape, lanes, speed]
	var only: BossDef = _with(func(t: SewerSwarmTuning) -> void: t.bait_kinds = PackedStringArray([kind]))
	var pair: Array = _fight(only, lanes, speed)
	var world: RunWorld = pair[0]
	var boss: SewerSwarm = pair[1]
	var bot := SewerSwarmBot.new(boss)
	bot.bait_escape = escape
	bot.reaction = REACTION
	var line: Dictionary = {}
	await _run(world, 30.0, func() -> bool: return not _events(boss, &"surge_bait").is_empty(), func() -> void:
		bot.step()
		var s: SwarmSurges = boss.surges
		if line.is_empty() and s.stage == SwarmSurges.Stage.CHARGE and not (s.surge["bait"] as Dictionary).is_empty():
			var lane: int = int(s.surge["locked"])
			var bait_at: float = float(s.surge["bait"]["at"])
			line["on"] = boss.props.warned(lane, bait_at + 0.5, float(s.surge["entry"]) - 0.5)
			line["short"] = not boss.props.warned(lane, world.player.distance + 2.0, bait_at - 1.5))
	var baits: Array[Dictionary] = _events(boss, &"surge_bait")
	check(baits.size() == 1 and baits[0]["kind"] == kind and world.player.alive,
		"a cluster baited into a %s %s" % [kind, tag])
	if baits.is_empty():
		await sim.free_world(world)
		return
	var destroyed: Array[Dictionary] = _events(boss, &"cluster_destroyed")
	var cause: StringName = &"fence" if kind == "fence" else &"hole"
	check(destroyed.size() == 1 and destroyed[0]["cause"] == cause, "is destroyed by it %s" % tag)
	var cluster: SwarmCluster = null
	for c: SwarmCluster in boss.clusters:
		if is_instance_valid(c) and c.index == int(destroyed[0]["index"]):
			cluster = c
	check(cluster != null and cluster.stage == (SwarmCluster.Stage.SHOCKED if kind == "fence" else SwarmCluster.Stage.FALLING),
		"and %s %s" % ["is shocked" if kind == "fence" else "falls into it", tag])
	check(float(baits[0]["at"]) - float(baits[0]["d"]) >= 4.0, "in front of the runner (%.1f m ahead) %s" % [
		float(baits[0]["at"]) - float(baits[0]["d"]), tag])
	check(_events(boss, &"surge_hit").is_empty() and boss.health < boss.max_health
		and world.score.bonuses.get(&"swarm_bait", 0) == boss.tuning.bait_score,
		"the runner untouched, the boss hurt (its hit) and the bait scored %s" % tag)
	check(bool(line.get("on", false)) and bool(line.get("short", false)),
		"its line locked from the bait to the cluster, never on toward the runner %s" % tag)
	check(_sounds(boss, &"swarm_shock" if kind == "fence" else &"swarm_fall").size() == 1, "with its sound %s" % tag)
	await sim.free_world(world)


# --- The hitbox ------------------------------------------------------------------------------------

## A surge hits only through its hitbox: a runner in its lane is hit as the hitbox reaches them (not before,
## though the mass's front is ahead of it), once; one in the next lane, beside the passing mass, never.
func _test_hit_only_by_hitbox() -> void:
	# Standing in it.
	var pair: Array = _fight(def, 5, 18.0)
	var world: RunWorld = pair[0]
	var boss: SewerSwarm = pair[1]
	world.player.armor = 50
	var bot := SewerSwarmBot.new(boss)
	bot.baits = false
	bot.dodges = false
	var overlap: Dictionary = {"first": -1.0}
	await _run(world, 80.0, func() -> bool: return not _events(boss, &"surge_hit").is_empty(), func() -> void:
		bot.step()
		var s: SwarmSurges = boss.surges
		if s.stage == SwarmSurges.Stage.CHARGE and float(overlap["first"]) < 0.0:
			var c: SwarmCluster = s.surge["cluster"]
			if _boxes_overlap(c.hitbox, world.player):
				overlap["first"] = boss.fight_time())
	var hits: Array[Dictionary] = _events(boss, &"surge_hit")
	check(hits.size() == 1 and float(overlap["first"]) >= 0.0 and absf(float(hits[0]["t"]) - float(overlap["first"])) <= 1.5 / 60.0,
		"a runner standing in a surge is hit as its hitbox reaches them (%.3f s, the overlap %.3f s)" % [
		float(hits[0]["t"]) if not hits.is_empty() else -1.0, float(overlap["first"])])
	await _run(world, 3.0, func() -> bool: return false, func() -> void: bot.step())
	check(_events(boss, &"surge_hit").size() == 1, "once: it passes on through them")
	await sim.free_world(world)
	# Beside it.
	pair = _fight(def, 5, 18.0)
	world = pair[0]
	boss = pair[1]
	world.player.armor = 50
	bot = SewerSwarmBot.new(boss)
	bot.baits = false
	var closest: Array = [INF]
	await _run(world, 60.0, func() -> bool: return _events(boss, &"surge_pass").size() >= 3, func() -> void:
		bot.step()
		var s: SwarmSurges = boss.surges
		if s.stage == SwarmSurges.Stage.CHARGE:
			var c: SwarmCluster = s.surge["cluster"]
			if absf(c.at - world.player.distance) < boss.tuning.mass_length:
				closest[0] = minf(float(closest[0]), absf(world.player.position.x - c.lane_x)))
	check(_events(boss, &"surge_pass").size() >= 3 and _events(boss, &"surge_hit").is_empty() and world.player.armor == 50,
		"a runner who switches out of its lane at the lock is never touched, surge after surge")
	check(float(closest[0]) <= world.geo.lane_width + 0.2,
		"though the mass passes right beside them (%.1f m from its middle)" % float(closest[0]))
	await sim.free_world(world)


## True if a hazard's box overlaps the player's hurtbox now.
func _boxes_overlap(h: Hazard, player: Player) -> bool:
	var box := AABB(h.global_position - h.size * 0.5, h.size)
	return box.intersects(player.hurtbox_aabb())


# --- A way out from every lane --------------------------------------------------------------------

## From every lane, at every lane count, a runner who doesn't bait gets out of every surge's way and is never
## touched (on a stretch of the arena with bait spots closer together, so many surges come quickly).
func _test_escapes() -> void:
	var dense: BossDef = _with(func(t: SewerSwarmTuning) -> void:
		t.bait_first = 140.0
		t.bait_spacing = 100.0)
	for lanes: int in LANES:
		for home: int in ([0, lanes / 2, lanes - 1] if lanes == 3 else [0, 1, lanes - 1]):
			var pair: Array = _fight(dense, lanes, 18.0)
			var world: RunWorld = pair[0]
			var boss: SewerSwarm = pair[1]
			var bot := SewerSwarmBot.new(boss)
			bot.baits = false
			bot.home_lane = home
			bot.reaction = REACTION
			await _run(world, 50.0, func() -> bool: return _events(boss, &"surge_lock").size() >= 4 and not boss.surges.busy(),
				func() -> void: bot.step())
			var locks: Array[Dictionary] = _events(boss, &"surge_lock")
			var in_lane: int = 0
			for l: Dictionary in locks:
				in_lane += 1 if int(l["lane"]) == home and not bool(l["baited"]) else 0
			check(world.player.alive and _events(boss, &"surge_hit").is_empty() and locks.size() >= 4 and in_lane >= 2,
				"from lane %d of %d: out of the way of every surge (%d, %d unbaited down its lane)" % [home, lanes, locks.size(), in_lane])
			await sim.free_world(world)


# --- No escalation -----------------------------------------------------------------------------------

## Nobody baits: phase 1 keeps cycling, unhurt, each surge the same as the last (GDD §10: no time limit, no
## escalation).
func _test_keeps_cycling() -> void:
	var pair: Array = _fight(def, 5, 18.0)
	var world: RunWorld = pair[0]
	var boss: SewerSwarm = pair[1]
	var bot := SewerSwarmBot.new(boss)
	bot.baits = false
	bot.reaction = REACTION
	await _run(world, 85.0, func() -> bool: return _events(boss, &"surge_pass").size() >= 6, func() -> void: bot.step())
	var warns: Array[Dictionary] = _events(boss, &"surge_warn")
	var locks: Array[Dictionary] = _events(boss, &"surge_lock")
	var passes: Array[Dictionary] = _events(boss, &"surge_pass")
	check(world.player.alive and passes.size() >= 6 and boss.phase_index == 0 and is_equal_approx(boss.health, boss.max_health),
		"no bait, no end: %d surges, still the Rising, unhurt" % passes.size())
	var same: bool = locks.size() >= 6
	var lead0: float = float(locks[0]["t"]) - float(warns[0]["t"]) if not locks.is_empty() else 0.0
	var reach0: float = float(warns[0]["entry"]) - float(warns[0]["d"]) if not warns.is_empty() else 0.0
	for i: int in mini(warns.size(), locks.size()):
		same = same and absf(float(locks[i]["t"]) - float(warns[i]["t"]) - lead0) < 0.02
		same = same and absf(float(warns[i]["entry"]) - float(warns[i]["d"]) - reach0) < 0.4
	check(same, "every surge warns as long and gathers as far ahead as the first (%.2f s, %.1f m)" % [lead0, reach0])
	# Each surge comes from its bait's side of the street (there's always one waiting there), and the clusters
	# on a side take turns.
	var sided: bool = not warns.is_empty()
	var last_on: Dictionary = {}
	var turns: bool = true
	for w: Dictionary in warns:
		var want: int = boss.side_of_lane(int(w["spot_lane"]))
		sided = sided and (want == 0 or int(w["side"]) == want)
		var side: int = int(w["side"])
		turns = turns and int(last_on.get(side, -1)) != int(w["cluster"])
		last_on[side] = int(w["cluster"])
	check(sided, "each surge pours in from its bait's side of the street")
	check(turns, "and the clusters on a side take turns")
	await sim.free_world(world)


# --- Weapons -------------------------------------------------------------------------------------------

## Weapons thin a surging cluster (and never one waiting at the roadside), the heavy missile's swarm bonus
## applies, and a cluster thinned to nothing is destroyed like a baited one.
func _test_weapons() -> void:
	var pt := load("res://data/tuning/powerups.tres") as PowerupTuning
	for tier: int in [1, 4]:
		var loadout := Loadout.new()
		loadout.tiers[&"weapon"] = tier
		var pair: Array = _fight(def, 5, 18.0, loadout)
		var world: RunWorld = pair[0]
		var boss: SewerSwarm = pair[1]
		world.player.god_mode = true
		var hits: Array[Dictionary] = []
		world.projectiles.enemy_hit.connect(func(e: Enemy, dmg: float, splash: bool) -> void:
			hits.append({"enemy": e, "dmg": dmg, "splash": splash}))
		var thinned_at: Array[Dictionary] = []
		for c: SwarmCluster in boss.clusters:
			c.health_changed.connect(func(e: Enemy) -> void:
				thinned_at.append({"surging": (e as SwarmCluster).surging(), "health": e.health}))
		var bot := SewerSwarmBot.new(boss)
		bot.baits = false
		var waiting_targeted: Array = [0]
		await _run(world, 40.0, func() -> bool: return _events(boss, &"surge_pass").size() >= 2, func() -> void:
			bot.step()
			for c: SwarmCluster in boss.queue:
				if is_instance_valid(c) and c.targetable():
					waiting_targeted[0] = int(waiting_targeted[0]) + 1)
		var direct: float = PowerupTuning.at_tier(pt.weapon_damage, tier) * (pt.swarm_bonus_multiplier if tier == 4 else 1.0)
		var all_surging: bool = not thinned_at.is_empty()
		for h: Dictionary in thinned_at:
			all_surging = all_surging and bool(h["surging"])
		var direct_ok: bool = false
		for h: Dictionary in hits:
			if not bool(h["splash"]) and h["enemy"] is SwarmCluster:
				direct_ok = is_equal_approx(float(h["dmg"]), direct)
		var tag: String = "(weapon tier %d)" % tier
		check(all_surging and int(waiting_targeted[0]) == 0,
			"weapons thin only a surging cluster, never one waiting at the roadside (%d hits) %s" % [thinned_at.size(), tag])
		check(direct_ok, "each direct hit takes %.1f%s %s" % [direct, " (the heavy missile's swarm bonus)" if tier == 4 else "", tag])
		var thinned: SwarmCluster = null
		for c: SwarmCluster in boss.clusters:
			if is_instance_valid(c) and c.health < c.max_health:
				thinned = c
		check(thinned != null and thinned.alive and Vector4(thinned.crowd.material.get_shader_parameter(&"life")).x < 1.0,
			"a cluster hit is thinned: its crowd shows fewer screeches %s" % tag)
		await sim.free_world(world)
	# Thinned to nothing: destroyed, and it counts.
	var frail: BossDef = _with(func(t: SewerSwarmTuning) -> void: t.cluster_health = 8.0)
	var heavy := Loadout.new()
	heavy.tiers[&"weapon"] = 4
	var pair2: Array = _fight(frail, 5, 18.0, heavy)
	var w2: RunWorld = pair2[0]
	var b2: SewerSwarm = pair2[1]
	w2.player.god_mode = true
	var bot2 := SewerSwarmBot.new(b2)
	bot2.baits = false
	await _run(w2, 40.0, func() -> bool: return not _events(b2, &"cluster_destroyed").is_empty(), func() -> void: bot2.step())
	var gone: Array[Dictionary] = _events(b2, &"cluster_destroyed")
	check(gone.size() == 1 and gone[0]["cause"] == &"weapon" and is_equal_approx(b2.health, b2.max_health - b2.hit_damage()),
		"a cluster thinned to nothing by weapons is destroyed, and counts as the phase's hit")
	check(_events(b2, &"surge_end").size() >= 1 and not b2.surges.busy(), "its surge ends with it")
	await sim.free_world(w2)


# --- The armor rule --------------------------------------------------------------------------------

## GDD §10's standard armor rule (15-17 s), with armor at the start (a surge breaks it: a pickup follows) and
## without (the phase begins unprotected: a pickup follows), once a phase; and one at the final phase's start.
func _test_armor_rule() -> void:
	# Without armor.
	var pair: Array = _fight(def, 5, 18.0)
	var world: RunWorld = pair[0]
	var boss: SewerSwarm = pair[1]
	world.player.god_mode = true
	var bot := SewerSwarmBot.new(boss)
	await _run(world, 20.0, func() -> bool: return not _events(boss, &"armor_pickup").is_empty(), func() -> void: bot.step())
	var picks: Array[Dictionary] = _events(boss, &"armor_pickup")
	check(not picks.is_empty() and picks[0]["reason"] == &"unprotected" and float(picks[0]["t"]) >= 15.0
		and float(picks[0]["t"]) <= 17.05, "without armor, a pickup comes %.1f s into the phase (15-17 s)" % (
		float(picks[0]["t"]) if not picks.is_empty() else -1.0))
	await sim.free_world(world)
	# With armor: a surge breaks it.
	var armored := Loadout.new()
	armored.armor = true
	pair = _fight(def, 5, 18.0, armored)
	world = pair[0]
	boss = pair[1]
	check(world.player.armor > 0 and _events(boss, &"armor_scheduled").is_empty(), "with armor, nothing is due at the start")
	bot = SewerSwarmBot.new(boss)
	bot.baits = false
	bot.dodges = false
	await _run(world, 60.0, func() -> bool: return not _events(boss, &"protection_broken").is_empty(), func() -> void: bot.step())
	var broken: Array[Dictionary] = _events(boss, &"protection_broken")
	check(not broken.is_empty() and world.player.alive, "a surge breaks the armor (it blocks the attack)")
	if not broken.is_empty():
		var at: float = float(broken[0]["t"])
		world.player.god_mode = true
		await _run(world, 20.0, func() -> bool: return not _events(boss, &"armor_pickup").is_empty(), func() -> void: bot.step())
		var after: Array[Dictionary] = _events(boss, &"armor_pickup")
		check(not after.is_empty() and after[0]["reason"] == &"protection_broken"
			and float(after[0]["t"]) - at >= 15.0 and float(after[0]["t"]) - at <= 17.05,
			"its pickup comes %.1f s after the break (15-17 s)" % (float(after[0]["t"]) - at if not after.is_empty() else -1.0))
	await sim.free_world(world)
	# The final phase's.
	pair = _fight(def, 5, 18.0, armored, {"phase": 2})
	world = pair[0]
	boss = pair[1]
	picks = _events(boss, &"armor_pickup")
	check(not picks.is_empty() and picks[0]["reason"] == &"final_phase" and boss.phase_index == 2,
		"the final phase begins with an armor pickup")
	await sim.free_world(world)


# --- Crowd sizes ---------------------------------------------------------------------------------------

## The crowd size is the look only: the same runner at two crowd sizes plays out the same fight.
func _test_crowd_size() -> void:
	var logs: Array[String] = []
	for size: int in [30, 400]:
		var sized: BossDef = _with(func(t: SewerSwarmTuning) -> void:
			t.cluster_creatures = size
			t.horde_creatures = size * 2
			t.spill_creatures = size / 20)
		var pair: Array = _fight(sized, 5, 18.0)
		var world: RunWorld = pair[0]
		var boss: SewerSwarm = pair[1]
		check(boss.clusters[0].crowd.count == size, "a fight drawn with %d screeches a cluster" % size)
		var bot := SewerSwarmBot.new(boss)
		bot.reaction = REACTION
		await _run(world, 90.0, func() -> bool: return _phase_one_over(boss), func() -> void: bot.step())
		logs.append(_fight_log(boss))
		await sim.free_world(world)
	check(logs.size() == 2 and logs[0] == logs[1] and logs[0].contains("surge_bait"),
		"plays out the same at 30 and 400 screeches a cluster: the crowd size changes only the look")


# --- Retries ---------------------------------------------------------------------------------------------

## At Gangland's speed: a death in phase 1 (after one bait), then a retry (RunContext.retry: the same fight from
## the start), won by baiting; the retry's surges are the first attempt's. At the widest street only: every
## attempt plays the same (the log's check below), and _test_wins_phase_one wins it at every lane count.
func _test_retry() -> void:
	for lanes: int in RETRY_LANES:
		var pair: Array = _fight(def, lanes, GANGLAND_SPEED)
		var world: RunWorld = pair[0]
		var boss: SewerSwarm = pair[1]
		var ctx: RunContext = pair[2]
		var bot := SewerSwarmBot.new(boss)
		bot.reaction = REACTION
		await _run(world, 60.0, func() -> bool: return not _events(boss, &"surge_bait").is_empty(), func() -> void: bot.step())
		var first: String = _fight_log(boss)
		world.player._die("test hazard")
		await sim.free_world(world)
		var next: RunContext = ctx.retry()
		pair = _fight(def, lanes, 0.0, null, {}, next)
		world = pair[0]
		boss = pair[1]
		check(next.attempt == 2 and boss.phase_index == 0 and is_equal_approx(boss.health, boss.max_health)
			and boss.destroyed == 0, "a retry starts the fight over, whole (%d lanes)" % lanes)
		bot = SewerSwarmBot.new(boss)
		bot.reaction = REACTION
		await _run(world, 90.0, func() -> bool: return _phase_one_over(boss), func() -> void: bot.step())
		check(_phase_one_over(boss) and world.player.alive and _fight_log(boss).begins_with(first),
			"and the retry, the same fight, is won by baiting (%d lanes, %.1f m/s)" % [lanes, GANGLAND_SPEED])
		await sim.free_world(world)


## Through quick play (./play.sh --boss=gangland_boss plays the preview): a death in phase 1 restarts the fight
## by itself, and the restarted fight is won by baiting (at 3 lanes, the phone's street: the other counts as
## _test_retry).
func _test_retry_through_quick_play() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var lanes_pc: int = App.rules.lanes_pc
	var saved: Profile = App.profile
	for lanes: int in QUICK_PLAY_LANES:
		App.profile = SampleProfiles.fresh()
		App.rules.lanes_pc = lanes
		App.start_boss_quick(def, PackedStringArray())
		await physics_frames(3)
		var run: LevelRun = App.run
		var boss := run.encounter as SewerSwarm if run != null else null
		check(boss != null and run.world.geo.lane_count == lanes and not run.world.player.god_mode,
			"quick play plays the preview (%d lanes)" % lanes)
		if boss == null:
			continue
		var bot := SewerSwarmBot.new(boss)
		bot.reaction = REACTION
		for i: int in 40 * 60:
			if not _events(boss, &"surge_bait").is_empty() or not run.world.player.alive:
				break
			bot.step()
			await tree.physics_frame
		run.world.player._die("test hazard")
		await physics_frames(int((LevelRun.QUICK_DEATH_PAUSE + 0.4) * 60.0))
		boss = run.encounter as SewerSwarm
		check(boss != null and run.context.attempt == 2 and boss.phase_index == 0 and boss.destroyed == 0,
			"a death restarts it, from the start (%d lanes)" % lanes)
		if boss == null:
			continue
		bot = SewerSwarmBot.new(boss)
		bot.reaction = REACTION
		for i: int in 90 * 60:
			if _phase_one_over(boss) or not run.world.player.alive:
				break
			bot.step()
			await tree.physics_frame
		check(_phase_one_over(boss) and run.world.player.alive, "and the retry is won by baiting (%d lanes)" % lanes)
	App.rules.lanes_pc = lanes_pc
	App.show_title()
	await tree.process_frame
	App.profile = saved
	main.queue_free()
	App.main = null
	await tree.process_frame

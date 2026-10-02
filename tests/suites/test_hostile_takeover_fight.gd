extends TestSuite
## Hostile Takeover's fight (GDD §10; task E5b-a: phase 1, The Board, which every phase plays until tasks
## E5b-b and E5b-c bring theirs), at 3, 5 and 6 lanes, at the reference 18 m/s and the Corporate zone's
## 23.4 m/s, with a runner who plays it by what it shows (HostileTakeoverBot, reacting REACTION late; no god
## mode, no armor unless a test says so):
## - the entrance: the gunship roars in; the phase's opening gaps stay dark; then each gap's coupling glows
##   red in plain view (at least lit_sight before the runner reaches its gap) in a lane of its own, its cue
##   sounding and its hint coming with the first; the guards, the Tithe Collector and the wall fences come;
## - landing on a coupling while jumping the gap stomps it: a third of the boss's health and phase 2 begins,
##   the carriages behind breaking away (the train's material) with their sounds; from the lane beside it
##   too, moving in while in the air;
## - a coupling missed is safe: jumped the usual way from its own lane it's sailed over, the runner lands
##   on the next carriage and the next gap's coupling glows; one let go by from another lane just passes;
##   a runner who runs off the roof's edge without jumping falls (that's no stomp);
## - the Tithe Collector skims the trail laid for it;
## - weapons chip at the gunship only while it can be hurt, and never past their cap;
## - the armor rule: after the free armor breaks, without armor, and as the final phase begins;
## - it plays the same on every attempt, to the preview's placeholder defeat;
## - quick play: the runner wins phase 1 at every lane count and both speeds, dies, and in the retry (the
##   fight starts over, the train whole again, the same plan) wins it again.

const BOSS_PATH: String = "res://data/bosses/corporate_boss.tres"
const LANES: Array[int] = [3, 5, 6]
## Quick play's speed and the Corporate zone's (GDD §3).
const SPEEDS: Array[float] = [18.0, 23.4]
const REACTION: float = 0.35
## Phase 1 for a runner who never misses (GDD §10: a fight of 60-120 s, three phases).
const PHASE_ONE_MAX: float = 40.0
## Events that make up the fight's plan and its course (the same on every attempt).
const COURSE: Array[StringName] = [&"enter", &"pattern", &"phase", &"couplings_from", &"carriage_planned", &"coupling_lit",
	&"coupling_missed", &"coupling_stomped", &"weak_point", &"tithe_trail", &"defeat"]

var sim: RunSim
var def: BossDef


func run() -> void:
	sim = RunSim.new(tree, tuning)
	var slot := load(BOSS_PATH) as BossDef
	def = slot.preview() if slot != null else null
	if def == null:
		check(false, "Hostile Takeover's fight loads as a preview")
		return
	for lanes: int in LANES:
		for speed: float in SPEEDS:
			await _test_phase_one(lanes, speed)
	await _test_side_lanes()
	await _test_missed_in_lane()
	await _test_let_go_by()
	await _test_run_off_the_edge()
	await _test_tithe()
	await _test_weapons()
	await _test_armor_broken()
	await _test_armor_unprotected()
	await _test_armor_final_phase()
	await _test_same_every_attempt()
	await _test_quick_play_and_retry()


## The fight at `lanes` and `speed` m/s (the arena config at that speed, as the campaign sets it), from
## phase `phase` (a checkpoint's resume): [world, boss].
func _fight(lanes: int, speed: float, loadout: Loadout = null, phase: int = 0) -> Array:
	var boss := BossEncounter.create(def) as HostileTakeover
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = def
	ctx.config = BossArena.base_config(def)
	ctx.config.lane_count = lanes
	ctx.config.run_speed = speed
	ctx.tuning = tuning
	ctx.boss_resume = {"phase": phase} if phase > 0 else {}
	var arena: BossArena = boss.plan_arena(ctx)
	var world: RunWorld = sim.build_world(arena.layout, loadout, tuning, ctx.config)
	boss.setup(world, ctx, arena)
	return [world, boss]


func _bot(boss: HostileTakeover) -> HostileTakeoverBot:
	var bot := HostileTakeoverBot.new(boss)
	bot.reaction = REACTION
	return bot


func _events(boss: BossEncounter, event: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in boss.events:
		if e["event"] == event:
			out.append(e)
	return out


func _sounded(boss: BossEncounter, sound_name: StringName) -> bool:
	return boss.events.any(func(e: Dictionary) -> bool: return e["event"] == &"sound" and e["name"] == sound_name)


## Steps the fight until `done` holds, the runner dies or `seconds` pass, the bot playing; `each` every frame.
func _run(world: RunWorld, bot: HostileTakeoverBot, seconds: float, done: Callable, each: Callable = Callable()) -> void:
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


func _death(world: RunWorld) -> Array[String]:
	var cause: Array[String] = [""]
	world.player.died.connect(func(c: String) -> void: cause[0] = c)
	return cause


# --- Phase 1 -------------------------------------------------------------------------------------

func _test_phase_one(lanes: int, speed: float) -> void:
	var tag: String = "(%d lanes, %.1f m/s)" % [lanes, speed]
	var pair: Array = _fight(lanes, speed)
	var world: RunWorld = pair[0]
	var boss: HostileTakeover = pair[1]
	var t: HostileTakeoverTuning = boss.tuning
	var bot := _bot(boss)
	var cause: Array[String] = _death(world)
	var hints: Array[String] = []
	boss.hint_due.connect(func(key: String) -> void: hints.append(key))
	var seen := {"cyborgs": 0, "collectors": 0, "fences": 0, "intro_targetable": false, "gunship_ahead": true, "chairman": true}
	world.director.enemy_spawned.connect(func(e: Enemy) -> void:
		if e.type_id == &"cyborg":
			seen["cyborgs"] += 1
		elif e.type_id == &"tithe_collector":
			seen["collectors"] += 1)
	var watch := func() -> void:
		seen["fences"] = maxi(int(seen["fences"]), world.track.wall_fence_hazards().size())
		if not boss.is_vulnerable() and boss.gunship.targetable():
			seen["intro_targetable"] = true
		if boss.is_vulnerable():
			# Over the train ahead of the runner, the locomotive far ahead with the Chairman at its window.
			var ahead: float = boss.gunship.track_distance() - world.player.distance
			if ahead < t.gunship_ahead or boss.gunship.global_position.y < t.gunship_height - 1.0:
				seen["gunship_ahead"] = false
			if absf(boss.locomotive.front_at - world.player.distance - t.loco_ahead) > 0.5 or not boss.locomotive.chairman.visible:
				seen["chairman"] = false
	await _run(world, bot, 60.0, func() -> bool: return boss.phase_index >= 1, watch)
	check(world.player.alive, "the runner lives through phase 1 (%s) %s" % [cause[0], tag])
	# The entrance.
	check(_events(boss, &"enter").size() == 1 and _sounded(boss, &"takeover_gunship") and not seen["intro_targetable"],
		"the gunship sweeps in roaring, no target during its entrance %s" % tag)
	check(seen["gunship_ahead"] and seen["chairman"], "it paces the train overhead, the locomotive and the Chairman far ahead %s" % tag)
	# The couplings: dark at first, then each in plain view in a lane of its own.
	var from: Array[Dictionary] = _events(boss, &"couplings_from")
	var lit: Array[Dictionary] = _events(boss, &"coupling_lit")
	var first_gap: int = int(from[0]["gap"]) if not from.is_empty() else -1
	check(from.size() == 1 and first_gap >= t.opening_for(0) and lit.size() >= 1 and int(lit[0]["gap"]) == first_gap,
		"the first %d gaps stay dark, then the couplings glow from gap %d %s" % [t.opening_for(0), first_gap, tag])
	var sight_ok: bool = true
	var lanes_ok: bool = true
	var least: float = INF
	for e: Dictionary in lit:
		var k: int = int(e["gap"])
		least = minf(least, float(e["ahead"]) / speed)
		sight_ok = sight_ok and float(e["ahead"]) / speed >= t.lit_sight - 0.05
		var prev: int = int(boss.board.lanes.get(k - 1, -1))
		var lane: int = int(e["lane"])
		lanes_ok = lanes_ok and lane >= 0 and lane < lanes and lane != prev and absi(lane - prev) <= t.coupling_max_shift
	check(sight_ok, "each glows at least %.1f s before the runner reaches its gap (%.1f s) %s" % [t.lit_sight, least, tag])
	check(lanes_ok, "each in a lane of its own, at most %d lanes from the last %s" % [t.coupling_max_shift, tag])
	check(_sounded(boss, &"takeover_couplings") and hints.has("corporate_boss/couplings"),
		"the first one's cue sounds and its hint comes %s" % tag)
	check(int(seen["cyborgs"]) >= 2 and int(seen["fences"]) >= 1, "guards on the roofs (%d) and wall fences on the barriers %s" % [
		seen["cyborgs"], tag])
	# The stomp.
	var stomped: Array[Dictionary] = _events(boss, &"coupling_stomped")
	var hits: Array[Dictionary] = _events(boss, &"weak_point")
	check(stomped.size() == 1 and hits.size() == 1 and int(stomped[0]["lane"]) == int(stomped[0]["runner_lane"]),
		"landing on a coupling while jumping its gap stomps it %s" % tag)
	check(boss.phase_index == 1 and is_equal_approx(boss.health, boss.max_health * 2.0 / 3.0),
		"a third of its health: phase 2 begins %s" % tag)
	check(_sounded(boss, &"takeover_decouple") and _sounded(boss, &"takeover_breakaway"), "it breaks with its sounds %s" % tag)
	var m: ShaderMaterial = (world.skin as HostileTakeoverSkin).train_material()
	var k_stomped: int = int(stomped[0]["gap"]) if not stomped.is_empty() else -1
	await physics_frames(20)
	check(k_stomped >= 0 and is_equal_approx(float(m.get_shader_parameter(&"break_z")), TrackGeometry.world_z(boss.train.gap_start(k_stomped)))
		and float(m.get_shader_parameter(&"break_age")) > 0.0 and not boss.couplings.is_live(k_stomped),
		"the coupling breaks open and the carriages behind its gap break away %s" % tag)
	var phase_one: float = float(hits[0]["t"]) if not hits.is_empty() else INF
	check(phase_one <= PHASE_ONE_MAX, "phase 1 takes %.1f s %s" % [phase_one, tag])
	print("  Hostile Takeover %s: couplings glow from gap %d, %.1f s ahead at the least; gap %d stomped at %.1f s, %d guards, %d Collectors" % [
		tag, first_gap, least, k_stomped, phase_one, seen["cyborgs"], seen["collectors"]])
	await sim.free_world(world)


## GDD §10: the coupling sits in one lane, reached by a normal jump from its lane and the lanes beside it:
## a runner who runs up beside it and moves in while in the air comes down on it too (at the edge, from
## the other side).
func _test_side_lanes() -> void:
	for c: Array in [[5, 18.0, -1], [5, 23.4, 1], [3, 23.4, 1], [6, 18.0, -1]]:
		var lanes: int = c[0]
		var speed: float = c[1]
		var side: int = c[2]
		var tag: String = "(%d lanes, %.1f m/s, from the %s)" % [lanes, speed, "left" if side < 0 else "right"]
		var pair: Array = _fight(lanes, speed)
		var world: RunWorld = pair[0]
		var boss: HostileTakeover = pair[1]
		var bot := _bot(boss)
		bot.side_lane = side
		await _run(world, bot, 60.0, func() -> bool: return boss.phase_index >= 1)
		var stomped: Array[Dictionary] = _events(boss, &"coupling_stomped")
		var k: int = int(stomped[0]["gap"]) if not stomped.is_empty() else -1
		var from_lane: int = int(bot.takeoffs.get(k, -1))
		var lane: int = int(boss.board.lanes.get(k, -1))
		check(world.player.alive and stomped.size() == 1 and absi(from_lane - lane) == 1,
			"a jump from the lane beside it (%d for %d), moving in while in the air, stomps it %s" % [from_lane, lane, tag])
		await sim.free_world(world)


# --- Misses --------------------------------------------------------------------------------------

## A runner in the coupling's lane who jumps the gap the usual way (from HostileTakeoverBot.HOLE_LEAD before
## its edge) sails over the coupling and lands on the next carriage; the next gap's coupling glows (no time
## limit, nothing escalates), and stomped, phase 2 begins.
func _test_missed_in_lane() -> void:
	var pair: Array = _fight(5, 18.0)
	var world: RunWorld = pair[0]
	var boss: HostileTakeover = pair[1]
	var bot := _bot(boss)
	bot.misses = 1
	bot.skip_in_lane = true
	await _run(world, bot, 60.0, func() -> bool: return boss.phase_index >= 1)
	var missed: Array[Dictionary] = _events(boss, &"coupling_missed")
	var k: int = int(missed[0]["gap"]) if not missed.is_empty() else -1
	check(missed.size() == 1 and int(bot.takeoffs.get(k, -1)) == int(missed[0]["lane"]),
		"a runner in the coupling's lane who jumps the gap the usual way sails over it: missed")
	var stomped: Array[Dictionary] = _events(boss, &"coupling_stomped")
	check(world.player.alive and stomped.size() == 1 and int(stomped[0]["gap"]) == k + 1,
		"landed safe on the next carriage, the next gap's coupling glows, and stomped, phase 2 begins")
	check(_events(boss, &"weak_point").size() == 1 and boss.phase_index == 1, "only the stomp hurt it")
	await sim.free_world(world)


## Couplings let go by from other lanes: each passes (missed, no damage), and the next one always comes.
func _test_let_go_by() -> void:
	var pair: Array = _fight(3, 23.4)
	var world: RunWorld = pair[0]
	var boss: HostileTakeover = pair[1]
	var bot := _bot(boss)
	bot.misses = 2
	await _run(world, bot, 60.0, func() -> bool: return boss.phase_index >= 1)
	var missed: Array[Dictionary] = _events(boss, &"coupling_missed")
	var stomped: Array[Dictionary] = _events(boss, &"coupling_stomped")
	check(missed.size() == 2 and int(missed[1]["gap"]) == int(missed[0]["gap"]) + 1 and _events(boss, &"weak_point").size() == 1,
		"two couplings let go by are missed, one after the other (3 lanes, 23.4 m/s)")
	check(world.player.alive and stomped.size() == 1 and int(stomped[0]["gap"]) == int(missed[1]["gap"]) + 1,
		"and the third is there to stomp (3 lanes, 23.4 m/s)")
	await sim.free_world(world)


## A runner who runs off the roof's edge in the coupling's lane without jumping never comes down on it from
## above: the stomp box's top less the stomp tolerance is over the roof, so that's no stomp. They fall.
func _test_run_off_the_edge() -> void:
	var pair: Array = _fight(5, 23.4)
	var world: RunWorld = pair[0]
	var boss: HostileTakeover = pair[1]
	var bot := _bot(boss)
	bot.drops = true
	var cause: Array[String] = _death(world)
	var lane_then := {"lane": -1}
	world.player.died.connect(func(_c: String) -> void: lane_then["lane"] = world.player.lane)
	await _run(world, bot, 60.0, func() -> bool: return boss.phase_index >= 1)
	var lit: Array[Dictionary] = _events(boss, &"coupling_lit")
	check(not world.player.alive and cause[0] == "fell" and _events(boss, &"weak_point").is_empty() and is_equal_approx(boss.health, boss.max_health),
		"running off the edge in its lane is no stomp: the runner falls (%s)" % cause[0])
	check(not lit.is_empty() and int(lane_then["lane"]) == int(lit[0]["lane"]), "in the coupling's own lane")
	await sim.free_world(world)


# --- The Tithe Collector ---------------------------------------------------------------------------

## GDD §10: "a Tithe Collector skims credits": as one comes into play a trail of credits is laid on the roof
## ahead of it in its lane, and it vacuums them up (TitheCollector).
func _test_tithe() -> void:
	var pair: Array = _fight(5, 18.0)
	var world: RunWorld = pair[0]
	var boss: HostileTakeover = pair[1]
	var t: HostileTakeoverTuning = boss.tuning
	world.player.god_mode = true
	world.player.grapples = 1_000_000
	var bot := _bot(boss)
	var collectors: Array[Enemy] = []
	world.director.enemy_spawned.connect(func(e: Enemy) -> void:
		if e.type_id == &"tithe_collector":
			collectors.append(e))
	var held := {"most": 0}
	await _run(world, bot, 45.0, func() -> bool: return int(held["most"]) >= t.tithe_value * 2, func() -> void:
		for c: Enemy in collectors:
			if is_instance_valid(c):
				held["most"] = maxi(int(held["most"]), world.score.held_by(c)))
	var trails: Array[Dictionary] = _events(boss, &"tithe_trail")
	check(not collectors.is_empty() and trails.size() >= 1 and int(trails[0]["count"]) >= 3,
		"a Tithe Collector comes with a trail of credits laid ahead of it (%d)" % (int(trails[0]["count"]) if not trails.is_empty() else 0))
	check(int(held["most"]) >= t.tithe_value * 2, "and skims them (it holds %d)" % held["most"])
	await sim.free_world(world)


# --- Weapons -------------------------------------------------------------------------------------

## GDD §10: weapons chip; stomps do the real damage. Shots count only while it can be hurt and never past
## its cap; a real weapon fires at the gunship. Even with weapons at their cap, every stomp of the later
## phases is still needed (in the preview: phase 2's and phase 3's three).
func _test_weapons() -> void:
	var loadout := Loadout.new()
	loadout.tiers = {&"weapon": 4}
	var pair: Array = _fight(5, 23.4, loadout)
	var world: RunWorld = pair[0]
	var boss: HostileTakeover = pair[1]
	world.player.god_mode = true
	world.player.grapples = 1_000_000
	var bot := _bot(boss)
	var before := {"damage": 0.0, "targeted": false}
	await _run(world, bot, 8.0, func() -> bool: return boss.is_vulnerable(), func() -> void:
		if not boss.is_vulnerable():
			before["targeted"] = before["targeted"] or boss.gunship.targetable()
			before["damage"] = boss.weapon_damage)
	check(not before["targeted"] and is_equal_approx(float(before["damage"]), 0.0), "weapons can't touch it during its entrance")
	await _run(world, bot, 40.0, func() -> bool: return boss.weapon_damage > 0.0 or boss.phase_index >= 1)
	check(boss.weapon_damage > 0.0, "a weapon chips at the gunship (%.1f)" % boss.weapon_damage)
	await _run(world, bot, 120.0, func() -> bool: return boss.is_defeated(), func() -> void:
		if boss.is_vulnerable():
			boss.gunship.take_damage(25.0, &"weapon"))
	var cap: float = boss.max_health * def.weapon_share_cap
	check(boss.weapon_damage <= cap + 0.01 and boss.weapon_damage > cap - 1.0,
		"weapons deal up to their cap and no more (%.1f of %.1f)" % [boss.weapon_damage, cap])
	var stomps: int = _events(boss, &"weak_point").size()
	check(boss.is_defeated() and stomps >= 4, "even with weapons at their cap it takes the later phases' stomps (%d)" % stomps)
	check(not boss.gunship.targetable(), "beaten, it's no target")
	await sim.free_world(world)


# --- The armor rule ------------------------------------------------------------------------------

## GDD §10's standard rule (15-17 s): the free armor broken (a guard's bolt), an armor pickup is due 15-17 s
## later and appears on a roof, never over a gap.
func _test_armor_broken() -> void:
	var armored := Loadout.new()
	armored.armor = true
	var pair: Array = _fight(5, 23.4, armored)
	var world: RunWorld = pair[0]
	var boss: HostileTakeover = pair[1]
	var bot := _bot(boss)
	await _run(world, bot, 10.0, func() -> bool: return boss.is_vulnerable())
	check(_events(boss, &"armor_scheduled").is_empty(), "with the free armor up, no pickup is due at the start")
	var shot := Hazard.new()
	shot.hazard_name = "test bolt"
	shot.is_enemy_attack = true
	world.player.receive_hit(shot)
	shot.free()
	var broke: float = boss.fight_time()
	var spots := {"bad": 0, "seen": 0}
	await _run(world, bot, 25.0, func() -> bool: return world.pickups.made >= 1 and float(spots["seen"]) > 0.0, func() -> void:
		for p: Pickup in world.pickups.active:
			spots["seen"] += 1
			if world.layout.gapped_between(p.lane, p.at - 1.0, p.at + 1.0):
				spots["bad"] += 1)
	var dues: Array[Dictionary] = _events(boss, &"armor_pickup")
	var after: float = float(dues[0]["t"]) - broke if not dues.is_empty() else -1.0
	check(_events(boss, &"protection_broken").size() == 1 and dues.size() == 1 and dues[0]["reason"] == &"protection_broken"
		and after >= def.armor_delay_min - 0.02 and after <= def.armor_delay_max + 0.02,
		"its free armor broken, an armor pickup is due %.1f s later" % after)
	check(world.pickups.made >= 1 and int(spots["bad"]) == 0 and world.player.alive, "and appears on a roof, never over a gap")
	await sim.free_world(world)


## Without armor (the free armor broken before the fight, or a run without it): the phase begun unprotected
## counts as a break, an armor pickup 15-17 s in.
func _test_armor_unprotected() -> void:
	var pair: Array = _fight(3, 18.0)
	var world: RunWorld = pair[0]
	var boss: HostileTakeover = pair[1]
	var bot := _bot(boss)
	await _run(world, bot, 25.0, func() -> bool: return world.pickups.made >= 1)
	var dues: Array[Dictionary] = _events(boss, &"armor_pickup")
	var t0: float = float(dues[0]["t"]) if not dues.is_empty() else -1.0
	check(world.player.armor == 0 and dues.size() == 1 and dues[0]["reason"] == &"unprotected" and int(dues[0]["phase"]) == 0
		and t0 >= def.armor_delay_min - 0.02 and t0 <= def.armor_delay_max + 0.02,
		"without armor, an armor pickup is due %.1f s into the first phase" % t0)
	check(world.pickups.made >= 1 and world.player.alive, "and appears on the track")
	await sim.free_world(world)


## The final phase begins with an armor pickup (in the preview, phase 3 plays The Board too).
func _test_armor_final_phase() -> void:
	var armored := Loadout.new()
	armored.armor = true
	var pair: Array = _fight(6, 23.4, armored, 2)
	var world: RunWorld = pair[0]
	var boss: HostileTakeover = pair[1]
	var bot := _bot(boss)
	await _run(world, bot, 10.0, func() -> bool: return world.pickups.made >= 1)
	var dues: Array[Dictionary] = _events(boss, &"armor_pickup")
	check(boss.is_final_phase() and not dues.is_empty() and dues[0]["reason"] == &"final_phase" and world.pickups.made >= 1,
		"the final phase begins with an armor pickup, which appears")
	check(_events(boss, &"enter").is_empty() and boss.step == HostileTakeover.Step.FLY, "a later phase begins with no entrance")
	await sim.free_world(world)


# --- The same every attempt, to the preview's defeat -----------------------------------------------

func _test_same_every_attempt() -> void:
	var logs: Array[String] = []
	var bot_logs: Array[String] = []
	var won: Array[bool] = []
	for attempt: int in 2:
		var pair: Array = _fight(5, 23.4)
		var world: RunWorld = pair[0]
		var boss: HostileTakeover = pair[1]
		var bot := _bot(boss)
		await _run(world, bot, 150.0, func() -> bool: return boss.is_defeated())
		var parts := PackedStringArray()
		for e: Dictionary in boss.events:
			if e["event"] in COURSE:
				parts.append(str(e))
		logs.append("\n".join(parts))
		var moves := PackedStringArray()
		for e: Dictionary in bot.log:
			moves.append("%.3f %s %s" % [float(e["t"]), e["action"], e["why"]])
		bot_logs.append("\n".join(moves))
		# The preview's placeholder defeat: the couplings go dark, the gunship climbs away, the results follow.
		var lit_after: bool = false
		for k: int in range(boss.train.next_gap(world.player.distance) - 2, boss.train.next_gap(world.player.distance) + 4):
			lit_after = lit_after or boss.coupling_live(k)
		var y0: float = boss.gunship.global_position.y
		await _run(world, null, HostileTakeover.DEFEAT_SECONDS + 0.2, func() -> bool: return boss.victory_over())
		won.append(boss.is_defeated() and world.player.alive and _events(boss, &"weak_point").size() == 5 and not lit_after
			and boss.gunship.global_position.y > y0 + 5.0 and boss.victory_over())
		await sim.free_world(world)
	check(won == [true, true], "the preview plays every phase as The Board, five stomps to its placeholder defeat (%s)" % [won])
	check(logs.size() == 2 and logs[0] == logs[1] and logs[0].length() > 400 and logs[0].contains("coupling_stomped"),
		"it plays the same on every attempt: the same carriages, guards, couplings and stomps at the same times")
	check(bot_logs[0] == bot_logs[1], "and the runner's every move matches")


# --- Quick play, a death and the retry -------------------------------------------------------------

## Through the game itself (quick play, as App.start_boss_quick with the preview): at every lane count and
## both speeds the runner wins phase 1, then dies; quick play retries, starting the fight over (its entrance,
## full health, the train whole again, the same plan), and the runner wins phase 1 again.
func _test_quick_play_and_retry() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var lanes_pc: int = App.rules.lanes_pc
	for lanes: int in LANES:
		for speed: float in SPEEDS:
			App.rules.lanes_pc = lanes
			await _quick_flow(lanes, speed)
	App.rules.lanes_pc = lanes_pc
	App.show_title()
	await tree.process_frame
	main.queue_free()
	App.main = null
	await tree.process_frame


func _quick_flow(lanes: int, speed: float) -> void:
	var tag: String = "(%d lanes, %.1f m/s)" % [lanes, speed]
	var quick: BossDef = def.duplicate() as BossDef
	quick.arena = def.arena.duplicate() as LevelConfig
	quick.arena.run_speed = speed
	App.start_boss_quick(quick)
	await physics_frames(3)
	var run: LevelRun = App.run
	check(run != null and run.encounter is HostileTakeover and run.world.geo.lane_count == lanes
		and is_equal_approx(run.world.tuning.run_speed, speed) and not run.world.player.god_mode,
		"quick play plays the fight, no god mode %s" % tag)
	if run == null or not run.encounter is HostileTakeover:
		return
	var boss := run.encounter as HostileTakeover
	var plan: Array[String] = []
	var won: bool = await _phase_one_in(run, boss)
	check(won, "the runner wins phase 1 %s" % tag)
	plan.append(_plan_of(boss))
	run.world.player._die("test hazard")
	await physics_frames(int((LevelRun.QUICK_DEATH_PAUSE + 0.4) * 60.0))
	run = App.run
	boss = run.encounter as HostileTakeover if run != null else null
	var m: ShaderMaterial = (run.world.skin as HostileTakeoverSkin).train_material() if run != null and run.world.skin is HostileTakeoverSkin else null
	check(boss != null and boss.phase_index == 0 and boss.step == HostileTakeover.Step.ENTER and is_equal_approx(boss.health, boss.max_health)
		and run.context.attempt == 2 and run.world.player.alive and m != null and float(m.get_shader_parameter(&"break_age")) < 0.0,
		"after a death, quick play retries: the fight starts over, its entrance, at full health, the train whole %s" % tag)
	if boss == null:
		return
	won = await _phase_one_in(run, boss)
	plan.append(_plan_of(boss))
	check(won, "and the runner wins phase 1 again in the retry %s" % tag)
	check(plan[0] == plan[1] and plan[0].length() > 100, "the retry's train, guards and couplings are the first attempt's %s" % tag)


## Plays phase 1 of `boss` in `run` with the bot: true if the runner stomped its way to phase 2.
func _phase_one_in(run: LevelRun, boss: HostileTakeover) -> bool:
	var bot := _bot(boss)
	for i: int in 60 * 60:
		if boss.phase_index >= 1 or not run.world.player.alive:
			break
		bot.step()
		await tree.physics_frame
	return boss.phase_index == 1 and run.world.player.alive and _events(boss, &"coupling_stomped").size() == 1


## The plan of the carriages the fight has laid out so far (no times).
func _plan_of(boss: HostileTakeover) -> String:
	var parts := PackedStringArray()
	for e: Dictionary in _events(boss, &"carriage_planned"):
		var copy: Dictionary = e.duplicate()
		copy.erase("t")
		if int(copy["carriage"]) <= 8:
			parts.append(str(copy))
	return "\n".join(parts)

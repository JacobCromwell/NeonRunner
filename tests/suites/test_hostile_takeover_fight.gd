extends TestSuite
## Hostile Takeover's fight (GDD §10; task E5b: phase 1, The Board; phase 2, The Contract; phase 3, The
## Merger; the defeat; its slot in the campaign), at 3, 5 and 6 lanes, at the reference 18 m/s and the
## Corporate zone's 23.4 m/s, with a runner who plays it by what it shows (HostileTakeoverBot, reacting
## REACTION late; no god mode, no armor unless a test says so), the whole fight at every setup:
## - phase 1: the entrance (the gunship roars in); the phase's opening gaps stay dark; then each gap's
##   coupling glows red in plain view (at least lit_sight before the runner reaches its gap) in a lane of its
##   own, its cue sounding and its hint coming with the first; the guards, the Tithe Collector and the wall
##   fences come; landing on a coupling while jumping the gap stomps it: a third of the boss's health and
##   phase 2 begins, the carriages behind breaking away (the train's material) with their sounds; from the
##   lane beside it too, moving in while in the air;
## - phase 2, on from there: phase 1's guards still to come never show up and its wall fences ahead are
##   off; the strafes (each warned by its red lines and the rising whine, raking only its warned lanes and
##   only once the warning is over, the runner's lane among them and a lane beside them free), the drop
##   (marked, released, landed; the Buzz Overdrive in play on its cut, revving before it charges), the
##   armored carriage in sight from ARMORED_SIGHT, the runway of pads, the ride on the belly and the drop
##   bay stomped: another third of its health, phase 3 begins;
## - phase 3, on from there: the docking once phase 2's ride is over (the locomotive back, the gunship
##   settling onto it, its clamps locking with their sound, then MERGER COMPLETE on the screens with its
##   sting and its hint); the attacks of both phases again, each warned as before (the strafes' lines and
##   whine, raking only their warned lanes once the warning is over; the drops marked; the Board's guards);
##   the passes (the war engine back over the runner, the clamps' hint, the runway, the belly), a clamp live
##   only while the runner rides under it and until it's torn loose, each stomped from a lane under it: three
##   stomps (counted: BossEncounter.phase_hits) beat it;
## - the defeat: the gunship pulls free, climbs away spinning and explodes explode_at seconds after the last
##   stomp, the locomotive veers off the guideway into the lobby set up beside the line ahead of the runner
##   (crash_at), its sculpture toppling, the screens dark, each with its sound; the results come
##   defeat_seconds after the stomp, the runner running on;
## - a coupling missed is safe: jumped the usual way from its own lane it's sailed over, the runner lands
##   on the next carriage and the next gap's coupling glows; one let go by from another lane just passes;
##   a runner who runs off the roof's edge without jumping falls (that's no stomp);
## - the Tithe Collector skims the trail laid for it;
## - a runner who stays in a strafe's lane is hit there once its warning is over; the dropped Buzz
##   Overdrive keeps its rules (its rev, then its charge; the armor blocks its blade and the floor holds);
##   without the runway of pads the armored carriage can't be passed; a drop bay let go by is missed and the
##   next cycle comes; a pass let go by is missed and the next comes, and clamps left in a pass stay for the
##   next;
## - weapons chip at the gunship only while it can be hurt, never past their cap and never to a phase's
##   end (BossDef.weapons_can_end_phase off): each phase still takes its stomps, phase 3 its three clamps
##   however far weapons chipped it;
## - the armor rule: after the free armor breaks, without armor, and as the final phase begins;
## - it plays the same on every attempt, to the defeat;
## - quick play: the runner wins phases 1 and 2, dies once the war engine has docked, and in the retry (the
##   fight starts over, the train whole again, the same plan) wins the whole fight (here at QUICK_PLAY's two
##   setups; every lane count and speed: tools/measure/hostile_takeover.gd);
## - the campaign at the Corporate zone's 23.4 m/s and every lane count: Corporate 2, then the fight (a death
##   in its last phase, the retry from the start, all three phases won), its results and stars, the shop and
##   the zone's outro.

const BOSS_PATH: String = "res://data/bosses/corporate_boss.tres"
const LANES: Array[int] = [3, 5, 6]
## Quick play's speed and the Corporate zone's (GDD §3).
const SPEEDS: Array[float] = [18.0, 23.4]
## The setups quick play's death and retry are played at here ([lanes, speed]).
const QUICK_PLAY: Array[Array] = [[3, 23.4], [6, 18.0]]
const REACTION: float = 0.35
## Each phase for a runner who never misses (GDD §10: a fight of 60-120 s, three phases).
const PHASE_ONE_MAX: float = 40.0
const PHASE_TWO_MAX: float = 40.0
const PHASE_THREE_MAX: float = 35.0
## Events that make up the fight's plan and its course (the same on every attempt).
const COURSE: Array[StringName] = [&"enter", &"pattern", &"phase", &"couplings_from", &"carriage_planned", &"coupling_lit",
	&"coupling_missed", &"coupling_stomped", &"weak_point", &"tithe_trail", &"defeat", &"stand_down", &"contract",
	&"drop_planned", &"drop_marked", &"saw_released", &"saw_landed", &"ride_planned", &"ride_placed", &"ride_begins",
	&"ride_boarded", &"ride_landed", &"ride_missed", &"bay_stomped", &"strafe_warned", &"strafe_rake", &"strafe_done",
	&"docking", &"clamps_locked", &"merger_complete", &"pass_planned", &"pass_placed", &"pass_begins", &"pass_boarded",
	&"pass_landed", &"pass_missed", &"clamp_stomped", &"defeated", &"gunship_exploded", &"locomotive_crashed"]

const BuzzOverdriveScript = preload("res://scripts/enemies/buzz_overdrive.gd")

var sim: RunSim
var def: BossDef


func run() -> void:
	sim = RunSim.new(tree, tuning)
	var slot := load(BOSS_PATH) as BossDef
	def = slot if slot != null and slot.is_built() else null
	if def == null:
		check(false, "Hostile Takeover's fight loads")
		return
	for lanes: int in LANES:
		for speed: float in SPEEDS:
			await _test_phases(lanes, speed)
	await _test_side_lanes()
	await _test_missed_in_lane()
	await _test_let_go_by()
	await _test_run_off_the_edge()
	await _test_tithe()
	await _test_strafe_strikes()
	await _test_saw_rules()
	await _test_armored_blocks()
	await _test_missed_bay()
	await _test_missed_clamps()
	await _test_weapons()
	await _test_armor_broken()
	await _test_armor_unprotected()
	await _test_armor_final_phase()
	await _test_same_every_attempt()
	await _test_quick_play_and_retry()
	await _test_campaign()


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
	return _sounds(boss, sound_name) > 0


func _sounds(boss: BossEncounter, sound_name: StringName) -> int:
	return boss.events.filter(func(e: Dictionary) -> bool: return e["event"] == &"sound" and e["name"] == sound_name).size()


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


# --- The whole fight ------------------------------------------------------------------------------

func _test_phases(lanes: int, speed: float) -> void:
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
	# Guards coming into play once phase 2 has begun, and those of them still in play then.
	var late := {"guards": 0, "alive": 0}
	world.director.enemy_spawned.connect(func(e: Enemy) -> void:
		if e.type_id == &"cyborg":
			seen["cyborgs"] += 1
			if boss.phase_index >= 1:
				late["guards"] += 1
				late["alive"] += 1 if e.alive else 0
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
	var phase_one: float = float(hits[0]["t"]) if not hits.is_empty() else INF
	await _run(world, bot, 0.34, func() -> bool: return false)
	check(k_stomped >= 0 and is_equal_approx(float(m.get_shader_parameter(&"break_z")), TrackGeometry.world_z(boss.train.gap_start(k_stomped)))
		and float(m.get_shader_parameter(&"break_age")) > 0.0 and not boss.couplings.is_live(k_stomped),
		"the coupling breaks open and the carriages behind its gap break away %s" % tag)
	check(phase_one <= PHASE_ONE_MAX, "phase 1 takes %.1f s %s" % [phase_one, tag])
	var phase_two: float = await _phase_two(world, boss, bot, cause, hints, late, tag, phase_one)
	var strafes_two: int = boss.contract.strafes
	var phase_three: float = await _phase_three(world, boss, bot, cause, hints, tag, phase_one + phase_two)
	print("  Hostile Takeover %s: couplings glow from gap %d, %.1f s ahead at the least; gap %d stomped at %.1f s, %d guards, %d Collectors; phase 2 %.1f s, %d strafes, %d guards retired; phase 3 %.1f s, %d strafes, %d passes; beaten at %.1f s" % [
		tag, first_gap, least, k_stomped, phase_one, seen["cyborgs"], seen["collectors"], phase_two, strafes_two,
		boss.guards_retired, phase_three, boss.contract.strafes - strafes_two, _events(boss, &"pass_begins").size(), boss.fight_time()])
	if boss.is_defeated():
		await _defeat_plays_out(world, boss, bot, tag)
	await sim.free_world(world)


## Plays phase 2 with the bot from `from` (the fight time it began) to its stomp, checking it as it goes
## (see the header; `late`: phase 1's guards that came into play once it had begun, and those of them
## still in play then). Returns how long it took.
func _phase_two(world: RunWorld, boss: HostileTakeover, bot: HostileTakeoverBot, cause: Array[String], hints: Array[String],
		late: Dictionary, tag: String, from: float) -> float:
	var t: HostileTakeoverTuning = boss.tuning
	var c: HostileTakeoverContract = boss.contract
	var lanes: int = boss.lane_count()
	var w := {"rake_ok": true, "fences_on": 0, "saw": null, "saws": 0, "cut_ok": false, "states": []}
	world.director.enemy_spawned.connect(func(e: Enemy) -> void:
		if e.type_id == &"buzz_overdrive" and int(w["saws"]) == 0:
			w["saws"] += 1
			w["saw"] = e
			w["cut_ok"] = not c.drops.is_empty() and e.get("cut") == c.drops[0]["cut"])
	var watch := func() -> void:
		var d: float = world.player.distance
		# A rake only in its strafe's warned lanes, and only once the warning is over.
		var s: Dictionary = c.strafe
		for rig: Dictionary in boss.strafes.rigs:
			if (rig["hazard"] as Hazard).is_active() and (s.is_empty() or int(s["stage"]) != HostileTakeoverContract.StrafeStage.RAKE
					or float(s["t"]) < t.strafe_warning - 0.001 or not (s["lanes"] as Array).has(int(rig["lane"]))):
				w["rake_ok"] = false
		# Phase 1's wall fences ahead are off.
		for h: Hazard in world.track.wall_fence_hazards():
			if h.is_active() and -h.global_position.z > d:
				w["fences_on"] += 1
		# The dropped tank's states, in order.
		var saw: Variant = w["saw"]
		if is_instance_valid(saw):
			var states: Array = w["states"]
			var state: int = int((saw as Object).get("state"))
			if states.is_empty() or int(states[-1]) != state:
				states.append(state)
	await _run(world, bot, 60.0, func() -> bool: return boss.phase_index >= 2, watch)
	var took: float = boss.fight_time() - from
	check(world.player.alive, "the runner lives through phase 2 (%s) %s" % [cause[0], tag])
	# The stand-down.
	check(_events(boss, &"stand_down").size() == 1 and int(w["fences_on"]) == 0,
		"as phase 2 begins phase 1's wall fences ahead switch off %s" % tag)
	check(int(late["alive"]) == 0 and boss.guards_retired == int(late["guards"]),
		"and its guards still to come never show up (%d retired) %s" % [boss.guards_retired, tag])
	# The strafes.
	var warned: Array[Dictionary] = _events(boss, &"strafe_warned")
	var raked: Array[Dictionary] = _events(boss, &"strafe_rake")
	var timing_ok: bool = warned.size() == raked.size() or warned.size() == raked.size() + 1
	var lanes_ok: bool = true
	for i: int in warned.size():
		var struck: Array = warned[i]["lanes"]
		var lo: int = int(struck.min())
		var hi: int = int(struck.max())
		lanes_ok = lanes_ok and struck.has(int(warned[i]["lane"])) and struck.size() < lanes and hi - lo + 1 == struck.size()
		if i < raked.size():
			timing_ok = timing_ok and absf(float(raked[i]["t"]) - float(warned[i]["t"]) - t.strafe_warning) < 0.03
	check(warned.size() >= 1 and _sounds(boss, &"takeover_whine") == warned.size() and timing_ok and hints.has("corporate_boss/strafe"),
		"the gunship strafes (%d), each warned by its lines and the rising whine %.1f s before it rakes %s" % [
			warned.size(), t.strafe_warning, tag])
	check(lanes_ok, "a strafe strikes the runner's lane and the ones beside it, never all of them %s" % tag)
	check(w["rake_ok"], "its guns rake only its warned lanes, once the warning is over %s" % tag)
	# The drop.
	var planned: Array[Dictionary] = _events(boss, &"drop_planned")
	var marked: Array[Dictionary] = _events(boss, &"drop_marked")
	var released: Array[Dictionary] = _events(boss, &"saw_released")
	var landed: Array[Dictionary] = _events(boss, &"saw_landed")
	check(not planned.is_empty() and not landed.is_empty() and float(marked[0]["t"]) < float(released[0]["t"])
		and float(released[0]["t"]) < float(landed[0]["t"]) and _sounded(boss, &"takeover_drop"),
		"it drops a Buzz Overdrive: its spot marked, let go, landed with its sound %s" % tag)
	var states: Array = w["states"]
	var rev: int = states.find(BuzzOverdriveScript.State.REV)
	var charge: int = states.find(BuzzOverdriveScript.State.CHARGE)
	check(int(w["saws"]) == 1 and w["cut_ok"] and rev >= 0 and charge > rev,
		"the tank comes into play on its cut and revs before it charges (%s) %s" % [states, tag])
	# The ride.
	var placed: Array[Dictionary] = _events(boss, &"ride_placed")
	var begins: Array[Dictionary] = _events(boss, &"ride_begins")
	check(not placed.is_empty() and float(placed[0]["ahead"]) >= HostileTakeoverContract.ARMORED_SIGHT - 1.0,
		"the armored carriage stands in sight %.0f m ahead %s" % [float(placed[0]["ahead"]) if not placed.is_empty() else 0.0, tag])
	check(not begins.is_empty() and begins[0]["bay"] and _sounded(boss, &"takeover_bay") and hints.has("corporate_boss/ride"),
		"the gunship comes down with its drop bay open %s" % tag)
	var stomped: Array[Dictionary] = _events(boss, &"bay_stomped")
	check(_events(boss, &"ride_boarded").size() >= 1 and stomped.size() == 1 and _events(boss, &"weak_point").size() == 2,
		"the runner takes the pads, rides the belly over the armored carriage and stomps the drop bay %s" % tag)
	check(boss.phase_index == 2 and is_equal_approx(boss.health, boss.max_health / 3.0), "another third: phase 3 begins %s" % tag)
	check(took <= PHASE_TWO_MAX, "phase 2 takes %.1f s %s" % [took, tag])
	return took


## Plays phase 3 with the bot from `from` (the fight time it began) to the last clamp, checking it as it
## goes (see the header). Returns how long it took.
func _phase_three(world: RunWorld, boss: HostileTakeover, bot: HostileTakeoverBot, cause: Array[String], hints: Array[String],
		tag: String, from: float) -> float:
	var t: HostileTakeoverTuning = boss.tuning
	var c: HostileTakeoverContract = boss.contract
	var lanes: int = boss.lane_count()
	var w := {"rake_ok": true, "live_ok": true, "words": false, "guards": 0, "saws": 0, "chairman": true}
	world.director.enemy_spawned.connect(func(e: Enemy) -> void:
		if boss.phase_index < 2 or boss.is_defeated():
			return
		if e.type_id == &"cyborg":
			w["guards"] += 1
		elif e.type_id == &"buzz_overdrive":
			w["saws"] += 1)
	var watch := func() -> void:
		# A rake only in its strafe's warned lanes, and only once the warning is over.
		var s: Dictionary = c.strafe
		for rig: Dictionary in boss.strafes.rigs:
			if (rig["hazard"] as Hazard).is_active() and (s.is_empty() or int(s["stage"]) != HostileTakeoverContract.StrafeStage.RAKE
					or float(s["t"]) < t.strafe_warning - 0.001 or not (s["lanes"] as Array).has(int(rig["lane"]))):
				w["rake_ok"] = false
		# A clamp is live only while the runner rides the belly in a pass, and until it's torn loose.
		var ride: Dictionary = c.ride_now()
		for cl: Dictionary in boss.gunship.clamps:
			if (cl["point"] as Hazard).is_active() and (cl["torn"] or world.player.surface != Player.Surface.CEILING
					or ride.is_empty() or not ride["pass"]):
				w["live_ok"] = false
		if boss.screens.words_shown():
			w["words"] = true
		if boss.docked and boss.locomotive.chairman.visible:
			w["chairman"] = false
	await _run(world, bot, 60.0, func() -> bool: return boss.is_defeated(), watch)
	var took: float = boss.fight_time() - from
	check(world.player.alive, "the runner lives through phase 3 (%s) %s" % [cause[0], tag])
	# The docking.
	var docking: Array[Dictionary] = _events(boss, &"docking")
	var locked: Array[Dictionary] = _events(boss, &"clamps_locked")
	var merged: Array[Dictionary] = _events(boss, &"merger_complete")
	var ride_end: float = -INF
	for e: Dictionary in _events(boss, &"ride_landed"):
		ride_end = maxf(ride_end, float(e["t"]))
	var in_order: bool = docking.size() == 1 and locked.size() == 1 and merged.size() == 1 and float(docking[0]["t"]) >= ride_end \
		and float(locked[0]["t"]) > float(docking[0]["t"]) and absf(float(merged[0]["t"]) - float(docking[0]["t"]) - t.dock_seconds) < 0.05
	check(in_order, "once phase 2's ride is over the gunship docks onto the locomotive, its clamps lock, and %.1f s in, MERGER COMPLETE %s" % [
		t.dock_seconds, tag])
	check(_sounded(boss, &"takeover_clamps") and _sounded(boss, &"takeover_merger") and hints.has("corporate_boss/merger") and w["words"]
		and w["chairman"], "with its sounds and its hint, the words on the screens, the Chairman's face on them %s" % tag)
	# The attacks of both phases, each warned.
	var warned: Array[Dictionary] = _events(boss, &"strafe_warned")
	var raked: Array[Dictionary] = _events(boss, &"strafe_rake")
	var timing_ok: bool = warned.size() == raked.size() or warned.size() == raked.size() + 1
	var lanes_ok: bool = true
	var late: int = 0
	for i: int in warned.size():
		var struck: Array = warned[i]["lanes"]
		lanes_ok = lanes_ok and struck.has(int(warned[i]["lane"])) and struck.size() < lanes
		if i < raked.size():
			timing_ok = timing_ok and absf(float(raked[i]["t"]) - float(warned[i]["t"]) - t.strafe_warning) < 0.03
		if int(warned[i]["phase"]) == 2:
			late += 1
			lanes_ok = lanes_ok and float(warned[i]["t"]) >= float(merged[0]["t"] if not merged.is_empty() else INF)
	check(_sounds(boss, &"takeover_whine") == warned.size() and timing_ok and lanes_ok and w["rake_ok"],
		"phase 3's strafes (%d), docked, each warned by its lines and the whine, raking only its warned lanes once it's over, a lane beside free %s" % [
			late, tag])
	var drops_ok: bool = true
	var marked: Array[Dictionary] = _events(boss, &"drop_marked")
	var released: Array[Dictionary] = _events(boss, &"saw_released")
	for r: Dictionary in released:
		var seen_mark: bool = false
		for mk: Dictionary in marked:
			seen_mark = seen_mark or (is_equal_approx(float(mk["parked"]), float(r["parked"])) and float(mk["t"]) < float(r["t"]))
		drops_ok = drops_ok and seen_mark
	check(drops_ok and int(w["saws"]) >= 1, "its drops (%d), each marked before it's let go, the Board's guards (%d) between %s" % [
		w["saws"], w["guards"], tag])
	# The passes and the clamps.
	var begins: Array[Dictionary] = _events(boss, &"pass_begins")
	var stomped: Array[Dictionary] = _events(boss, &"clamp_stomped")
	var hits: Array = _events(boss, &"weak_point").filter(func(e: Dictionary) -> bool: return int(e["phase"]) == 2)
	check(not begins.is_empty() and hints.has("corporate_boss/clamps") and _events(boss, &"pass_boarded").size() >= 1,
		"the war engine comes back over the runner, who takes the pads and rides its belly %s" % tag)
	var under_ok: bool = stomped.size() == 3
	var third: float = boss.gunship.belly_width / 3.0
	for e: Dictionary in stomped:
		under_ok = under_ok and absf(world.geo.lane_x(int(e["runner_lane"])) - float(e["side"]) * third) <= third * 0.5 + 0.01
	check(under_ok and hits.size() == 3 and boss.gunship.clamps_left() == 0 and boss.is_defeated() and boss.phase_hits == 3
		and _sounds(boss, &"takeover_clamp") == 3, "a jump from its belly comes back up onto each clamp, from a lane under it: three stomps tear it loose %s" % tag)
	check(w["live_ok"], "a clamp is live only while the runner rides the belly in a pass, until it's torn loose %s" % tag)
	check(took <= PHASE_THREE_MAX, "phase 3 takes %.1f s %s" % [took, tag])
	return took


## The defeat (see the header), the runner running on with the bot: the lobby set up ahead beside the
## line, the gunship climbing away spinning and exploding, the locomotive veering into the lobby, the
## sculpture down, the screens dark, each when it should; then it's over.
func _defeat_plays_out(world: RunWorld, boss: HostileTakeover, bot: HostileTakeoverBot, tag: String) -> void:
	var t: HostileTakeoverTuning = boss.tuning
	var defeat: Array[Dictionary] = _events(boss, &"defeat")
	var lobby_at: float = float(defeat[0]["lobby"]) if not defeat.is_empty() else -INF
	var wall: float = world.geo.wall_x()
	check(boss.step == HostileTakeover.Step.DEFEAT and boss.lobby.visible and lobby_at > world.player.distance + 40.0
		and absf(boss.lobby.global_position.x) > wall + 5.0, "beaten: a corporate tower's lobby stands beside the line ahead (%.0f m) %s" % [
			lobby_at - world.player.distance, tag])
	var y0: float = boss.gunship.global_position.y
	var w := {"exploded": -1.0, "crashed": -1.0, "dark": -1.0, "climb": 0.0, "spin": 0.0, "ahead": -INF, "over": -1.0}
	await _run(world, bot, t.defeat_seconds + 1.0, func() -> bool: return boss.victory_over(), func() -> void:
		var st: float = boss.step_time
		if boss.gunship.visible:
			w["climb"] = maxf(float(w["climb"]), boss.gunship.global_position.y - y0)
			w["spin"] = maxf(float(w["spin"]), absf(boss.gunship.rotation.z))
		elif float(w["exploded"]) < 0.0:
			w["exploded"] = st
		if float(w["crashed"]) < 0.0 and not _events(boss, &"locomotive_crashed").is_empty():
			w["crashed"] = st
			w["ahead"] = lobby_at - world.player.distance
		if float(w["dark"]) < 0.0 and not boss.screens.on:
			w["dark"] = st)
	var step: float = 1.0 / Engine.physics_ticks_per_second + 0.001
	check(float(w["climb"]) > 3.0 and float(w["spin"]) > 0.5 and absf(float(w["exploded"]) - t.explode_at) <= step
		and _sounded(boss, &"takeover_explode"), "the gunship pulls free, climbs away spinning (%.1f m) and explodes %.1f s on, with its sound %s" % [
			float(w["climb"]), float(w["exploded"]), tag])
	var loco: Vector3 = boss.locomotive.global_position
	check(absf(float(w["crashed"]) - t.crash_at) <= step and _sounded(boss, &"takeover_derail") and float(w["ahead"]) > 0.0
		and absf(loco.x) > wall and absf(boss.locomotive.front_at - (lobby_at - HostileTakeover.DERAIL_SHORT)) < 0.5,
		"the locomotive leaves the guideway and ploughs into the lobby ahead of the runner %.1f s on, with its sound %s" % [float(w["crashed"]), tag])
	check(boss.lobby.sculpture.rotation.x > 1.4 and float(w["dark"]) >= 0.0 and float(w["dark"]) <= HostileTakeover.SCREENS_DARK_AT + step,
		"the sculpture comes down, the screens go dark %s" % tag)
	check(boss.victory_over() and absf(boss.step_time - t.defeat_seconds) <= step and world.player.alive,
		"and %.1f s after the last stomp it's over, the runner running on %s" % [t.defeat_seconds, tag])


## GDD §10: the coupling sits in one lane, reached by a normal jump from its lane and the lanes beside it:
## a runner who runs up beside it and moves in while in the air comes down on it too (at the edge, from
## the other side; a guard in the lane beside it, from the other side too).
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

## GDD §10: "a Tithe Collector skims credits": one comes into play in the runner's lane on a flatcar (no
## guards: nothing draws it off), a trail of credits is laid on the roof ahead of it in its lane, and it
## vacuums them up (TitheCollector).
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
	var held := {"most": 0, "lane": -1}
	world.director.enemy_spawned.connect(func(e: Enemy) -> void:
		if e.type_id == &"tithe_collector" and int(held["lane"]) < 0:
			held["lane"] = world.player.lane)
	await _run(world, bot, 45.0, func() -> bool: return int(held["most"]) >= t.tithe_value * t.tithe_credits, func() -> void:
		for c: Enemy in collectors:
			if is_instance_valid(c):
				held["most"] = maxi(int(held["most"]), world.score.held_by(c)))
	var trails: Array[Dictionary] = _events(boss, &"tithe_trail")
	var first: Dictionary = trails[0] if not trails.is_empty() else {}
	check(not collectors.is_empty() and int(first.get("count", 0)) == t.tithe_credits and int(first.get("lane", -2)) == int(held["lane"]),
		"a Tithe Collector comes in the runner's lane, a trail of %d credits laid ahead of it" % int(first.get("count", 0)))
	check(int(held["most"]) >= t.tithe_value * (t.tithe_credits / 2), "and skims them (it holds %d of %d)" % [
		held["most"], t.tithe_value * t.tithe_credits])
	print("  Hostile Takeover's Tithe Collector skims %d of its trail's %d credits" % [int(held["most"]) / t.tithe_value, t.tithe_credits])
	await sim.free_world(world)


# --- Phase 2's rules ------------------------------------------------------------------------------

## A runner who stays in a strafe's lane is hit by its guns there, once its warning is over: where and when
## the warning said (the bot that leaves the lane lives: _test_phases). From a checkpoint's phase 2.
func _test_strafe_strikes() -> void:
	var pair: Array = _fight(5, 23.4, null, 1)
	var world: RunWorld = pair[0]
	var boss: HostileTakeover = pair[1]
	var t: HostileTakeoverTuning = boss.tuning
	var bot := _bot(boss)
	bot.ignores_strafes = true
	var cause: Array[String] = _death(world)
	var then := {"lane": -1, "stage": -1, "t": -1.0, "lanes": []}
	world.player.died.connect(func(_c: String) -> void:
		then["lane"] = world.player.lane
		var s: Dictionary = boss.contract.strafe
		if not s.is_empty():
			then["stage"] = int(s["stage"])
			then["t"] = float(s["t"])
			then["lanes"] = s["lanes"])
	await _run(world, bot, 15.0, func() -> bool: return false)
	check(not world.player.alive and cause[0] == "the gunship's guns", "a runner who stays in a strafe's lane is hit (%s)" % cause[0])
	check((then["lanes"] as Array).has(int(then["lane"])) and int(then["stage"]) == HostileTakeoverContract.StrafeStage.RAKE
		and float(then["t"]) >= t.strafe_warning, "in a warned lane, once its warning is over (%.2f s after it began)" % float(then["t"]))
	await sim.free_world(world)


## The dropped Buzz Overdrive keeps its own rules (task C2): it revs (its warning) before it charges, and
## when the armor blocks its blade, the floor under the runner holds a moment (GameRules.cut_hold_seconds)
## for them to leave its lane. From a checkpoint's phase 2 at 18 m/s (its first flatcar's drop planned as
## the phase begins), with the armor, the runner heading into its lane.
func _test_saw_rules() -> void:
	var armored := Loadout.new()
	armored.armor = true
	var pair: Array = _fight(5, 18.0, armored, 1)
	var world: RunWorld = pair[0]
	var boss: HostileTakeover = pair[1]
	var bot := _bot(boss)
	bot.meets_saw = true
	var cause: Array[String] = _death(world)
	var w := {"saw": null, "saws": 0, "states": [], "held": false}
	world.director.enemy_spawned.connect(func(e: Enemy) -> void:
		if e.type_id == &"buzz_overdrive" and int(w["saws"]) == 0:
			w["saws"] += 1
			w["saw"] = e)
	var c: HostileTakeoverContract = boss.contract
	await _run(world, bot, 30.0, func() -> bool:
		return not c.drops.is_empty() and int(c.drops[0]["stage"]) == HostileTakeoverContract.DropStage.DONE, func() -> void:
		var saw: Variant = w["saw"]
		if not is_instance_valid(saw):
			return
		var states: Array = w["states"]
		var state: int = int((saw as Object).get("state"))
		if states.is_empty() or int(states[-1]) != state:
			states.append(state)
		var cut := (saw as Object).get("floor_cut") as FloorCut
		if cut != null and cut.holding():
			w["held"] = true)
	var states: Array = w["states"]
	var rev: int = states.find(BuzzOverdriveScript.State.REV)
	check(int(w["saws"]) == 1 and rev >= 0 and states.find(BuzzOverdriveScript.State.CHARGE) > rev,
		"the dropped Buzz Overdrive revs before it charges (%s)" % [states])
	check(_events(boss, &"protection_broken").size() == 1 and w["held"] and world.player.alive,
		"the armor blocks its blade, the floor holds and the runner leaves its lane (%s)" % cause[0])
	await sim.free_world(world)


## The armored carriage can only be passed on the gunship's belly: with its runway of pads switched off, a
## runner who jumps its gap as any other crashes into its front (no jump reaches its roof) and dies there.
func _test_armored_blocks() -> void:
	var pair: Array = _fight(3, 23.4, null, 1)
	var world: RunWorld = pair[0]
	var boss: HostileTakeover = pair[1]
	var bot := _bot(boss)
	var cause: Array[String] = _death(world)
	var then := {"d": -1.0, "y": -1.0}
	world.player.died.connect(func(_c: String) -> void:
		then["d"] = world.player.distance
		then["y"] = world.player.global_position.y)
	await _run(world, bot, 40.0, func() -> bool: return boss.phase_index >= 2, func() -> void:
		if boss.armored.in_use():
			for area: Area3D in boss.armored.pads:
				area.collision_layer = 0)
	var body: Vector2 = boss.armored.body_span()
	check(not world.player.alive and cause[0] == "the armored carriage" and absf(float(then["d"]) - body.x) < 3.0
		and float(then["y"]) < boss.tuning.armored_height and _events(boss, &"ride_boarded").is_empty(),
		"without the pads the armored carriage can't be passed: the runner crashes into its front (%s, %.1f m from it)" % [
			cause[0], float(then["d"]) - body.x])
	await sim.free_world(world)


## A ride whose drop bay isn't stomped is missed, harmlessly: the runner drops off past the armored
## carriage, the gunship takes on another tank, and the next flatcar's drop and ride come the same way (no
## time limit, nothing escalates); stomped then, phase 3 begins.
func _test_missed_bay() -> void:
	var pair: Array = _fight(3, 23.4, null, 1)
	var world: RunWorld = pair[0]
	var boss: HostileTakeover = pair[1]
	var bot := _bot(boss)
	bot.bay_misses = 1
	var cause: Array[String] = _death(world)
	await _run(world, bot, 90.0, func() -> bool: return boss.phase_index >= 2)
	var missed: Array[Dictionary] = _events(boss, &"ride_missed")
	var stomped: Array[Dictionary] = _events(boss, &"bay_stomped")
	check(world.player.alive and missed.size() == 1 and _events(boss, &"saw_landed").size() == 2,
		"a drop bay let go by is missed, the runner lands, and the next drop comes (%s)" % cause[0])
	check(stomped.size() == 1 and not missed.is_empty() and int(stomped[0]["carriage"]) > int(missed[0]["carriage"])
		and _events(boss, &"weak_point").size() == 1 and boss.phase_index == 2, "the next ride's bay stomped, phase 3 begins")
	await sim.free_world(world)


## GDD §10: "missed weak points come around again". From phase 3's start (a checkpoint's): a pass let go by
## is missed, harmlessly (the runner drops back onto the roof, nothing hurt it), and the next flatcar's drop
## and pass come the same way (no time limit, nothing escalates); clamps not torn loose in a pass stay for
## the next one (two in the first pass, the third in the next); the third beats it.
func _test_missed_clamps() -> void:
	for setup: Array in [[5, 23.4, 1, 3], [3, 18.0, 0, 2]]:
		var tag: String = "(%d lanes, %.1f m/s)" % [setup[0], setup[1]]
		var pair: Array = _fight(int(setup[0]), float(setup[1]), null, 2)
		var world: RunWorld = pair[0]
		var boss: HostileTakeover = pair[1]
		var bot := _bot(boss)
		bot.pass_misses = int(setup[2])
		bot.clamps_per_pass = int(setup[3])
		var cause: Array[String] = _death(world)
		await _run(world, bot, 120.0, func() -> bool: return boss.is_defeated())
		var begins: Array[Dictionary] = _events(boss, &"pass_begins")
		var missed: Array[Dictionary] = _events(boss, &"pass_missed")
		var landed: Array[Dictionary] = _events(boss, &"pass_landed")
		var stomped: Array[Dictionary] = _events(boss, &"clamp_stomped")
		if int(setup[2]) > 0:
			var first_stomp: float = float(stomped[0]["t"]) if not stomped.is_empty() else -1.0
			check(world.player.alive and missed.size() == 1 and int(missed[0]["torn"]) == 0 and first_stomp > float(missed[0]["t"])
				and _events(boss, &"saw_landed").size() >= 2 and begins.size() == 2,
				"a pass let go by is missed, the runner lands, and the next drop and pass come (%s) %s" % [cause[0], tag])
		else:
			var later: bool = stomped.size() == 3 and not landed.is_empty() and float(stomped[2]["t"]) > float(landed[0]["t"])
			check(world.player.alive and not landed.is_empty() and int(landed[0]["torn"]) == 2 and later and begins.size() == 2,
				"two clamps torn loose in a pass, the third stays and comes around in the next (%s) %s" % [cause[0], tag])
		check(boss.is_defeated() and stomped.size() == 3 and _events(boss, &"weak_point").size() == 3,
			"the third clamp beats it %s" % tag)
		await sim.free_world(world)


# --- Weapons -------------------------------------------------------------------------------------

## GDD §10: weapons chip; stomps do the real damage. Shots count only while it can be hurt and never past its
## cap, and never to a phase's end (BossDef.weapons_can_end_phase off: DESIGN-TBD): poured on from the
## start, they leave phase 1 just above its end, and its stomp ends it exactly there (nothing carries into
## phase 2); what's left of their cap chips phase 2, whose stomp ends it exactly at its end too; phase 3, its
## cap spent, takes its three clamps; a real weapon fires at the gunship. And from phase 3's start (a
## checkpoint's, the cap whole), weapons poured on leave it just above 0, and still only the third clamp
## beats it (its hits are counted: BossEncounter.phase_hits).
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
	check(not def.weapons_can_end_phase, "Hostile Takeover's phases end only on their stomps (its data)")
	check(not before["targeted"] and is_equal_approx(float(before["damage"]), 0.0), "weapons can't touch it during its entrance")
	await _run(world, bot, 40.0, func() -> bool: return boss.weapon_damage > 0.0 or boss.phase_index >= 1)
	check(boss.weapon_damage > 0.0, "a weapon chips at the gunship (%.1f)" % boss.weapon_damage)
	var cap: float = boss.max_health * def.weapon_share_cap
	for phase: int in 3:
		var pour := {"frames": 0}
		await _run(world, bot, 90.0, func() -> bool: return boss.phase_index > phase or boss.is_defeated(), func() -> void:
			if boss.is_vulnerable() and int(pour["frames"]) < 90:
				pour["frames"] += 1
				boss.gunship.take_damage(25.0, &"weapon")
				if int(pour["frames"]) == 90:
					var end: float = boss.phase_start_health(phase + 1)
					var spent: bool = boss.weapon_damage >= cap - 0.01
					check(boss.phase_index == phase and boss.health > end and (boss.health < end + 0.5 or spent) and not boss.weapons_can_hurt()
						and not boss.gunship.targetable(),
						"poured on in phase %d, weapons stop just above its end or at their cap (%.2f, %.1f of %.1f spent)" % [phase + 1,
							boss.health, boss.weapon_damage, cap]))
		if phase < 2:
			check(world.player.alive and boss.phase_index == phase + 1 and _events(boss, &"weak_point").size() == phase + 1
				and is_equal_approx(boss.health, boss.phase_start_health(phase + 1)),
				"and its stomp ends phase %d, exactly at its end" % (phase + 1))
	check(world.player.alive and boss.is_defeated() and _events(boss, &"clamp_stomped").size() == 3 and _events(boss, &"weak_point").size() == 5,
		"phase 3 takes its three clamps")
	check(boss.weapon_damage <= cap + 0.01, "weapons never deal more than their cap (%.1f of %.1f)" % [boss.weapon_damage, cap])
	await sim.free_world(world)
	# From phase 3's start, the cap whole: chipped to just above 0, it still takes all three clamps.
	pair = _fight(5, 18.0, loadout, 2)
	world = pair[0]
	boss = pair[1]
	world.player.god_mode = true
	world.player.grapples = 1_000_000
	bot = _bot(boss)
	var left := {"health": -1.0, "hits": -1}
	await _run(world, bot, 60.0, func() -> bool: return boss.is_defeated(), func() -> void:
		if boss.is_vulnerable() and float(left["health"]) < 0.0:
			for i: int in 60:
				boss.gunship.take_damage(25.0, &"weapon")
			left["health"] = boss.health
			left["hits"] = boss.phase_hits)
	var clamps: Array[Dictionary] = _events(boss, &"clamp_stomped")
	var defeated: Array[Dictionary] = _events(boss, &"defeated")
	check(float(left["health"]) > 0.0 and float(left["health"]) < 0.5 and int(left["hits"]) == 0,
		"from phase 3's start, weapons poured on leave it just above 0 (%.3f)" % float(left["health"]))
	check(boss.is_defeated() and clamps.size() == 3 and not defeated.is_empty() and float(clamps[1]["t"]) < float(defeated[0]["t"])
		and float(defeated[0]["t"]) >= float(clamps[2]["t"]) and boss.phase_hits == 3,
		"and still only the third clamp beats it: weapons can't shortcut phase 3")
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


## The final phase begins with an armor pickup (its docking under way).
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
	await _run(world, bot, 0.2, func() -> bool: return false)
	check(_events(boss, &"enter").is_empty() and boss.step in [HostileTakeover.Step.DOCK, HostileTakeover.Step.MERGED],
		"a later phase begins with no entrance; phase 3 with the docking")
	await sim.free_world(world)


# --- The same every attempt, to the defeat ---------------------------------------------------------

func _test_same_every_attempt() -> void:
	var logs: Array[String] = []
	var bot_logs: Array[String] = []
	var won: Array[bool] = []
	for attempt: int in 2:
		var pair: Array = _fight(5, 23.4)
		var world: RunWorld = pair[0]
		var boss: HostileTakeover = pair[1]
		var bot := _bot(boss)
		await _run(world, bot, 150.0, func() -> bool: return boss.victory_over() and boss.is_defeated())
		var parts := PackedStringArray()
		for e: Dictionary in boss.events:
			if e["event"] in COURSE:
				parts.append(str(e))
		logs.append("\n".join(parts))
		var moves := PackedStringArray()
		for e: Dictionary in bot.log:
			moves.append("%.3f %s %s" % [float(e["t"]), e["action"], e["why"]])
		bot_logs.append("\n".join(moves))
		won.append(boss.is_defeated() and world.player.alive and _events(boss, &"weak_point").size() == 5
			and _events(boss, &"bay_stomped").size() == 1 and _events(boss, &"clamp_stomped").size() == 3
			and _events(boss, &"gunship_exploded").size() == 1 and _events(boss, &"locomotive_crashed").size() == 1 and boss.victory_over())
		await sim.free_world(world)
	check(won == [true, true], "The Board, The Contract and The Merger: five stomps, then the defeat plays out (%s)" % [won])
	check(logs.size() == 2 and logs[0] == logs[1] and logs[0].length() > 400 and logs[0].contains("coupling_stomped")
		and logs[0].contains("bay_stomped") and logs[0].contains("clamp_stomped") and logs[0].contains("strafe_rake")
		and logs[0].contains("locomotive_crashed"),
		"it plays the same on every attempt: the same carriages, guards, couplings, strafes, drops, rides, passes and stomps at the same times")
	check(bot_logs[0] == bot_logs[1], "and the runner's every move matches")


# --- Quick play, a death and the retry -------------------------------------------------------------

## Through the game itself (quick play, as App.start_boss_quick), at QUICK_PLAY's setups: the runner wins
## phases 1 and 2, then dies once the war engine has docked; quick play retries, starting the fight over (its
## entrance, full health, the train whole again, the same plan), and the runner wins the whole fight; once
## its defeat has played out, quick play starts it over.
func _test_quick_play_and_retry() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var lanes_pc: int = App.rules.lanes_pc
	for setup: Array in QUICK_PLAY:
		App.rules.lanes_pc = int(setup[0])
		await _quick_flow(int(setup[0]), float(setup[1]))
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
	var bot := _bot(boss)
	var won: bool = await _won_phases(run, boss, 2, bot)
	check(won, "the runner wins phases 1 and 2 %s" % tag)
	var docked: bool = await _play_until(run, boss, bot, func() -> bool: return boss.docked)
	check(docked and boss.screens.on, "the war engine docks: MERGER COMPLETE %s" % tag)
	plan.append(_plan_of(boss))
	run.world.player._die("test hazard")
	await physics_frames(int((LevelRun.QUICK_DEATH_PAUSE + 0.4) * 60.0))
	run = App.run
	boss = run.encounter as HostileTakeover if run != null else null
	var m: ShaderMaterial = (run.world.skin as HostileTakeoverSkin).train_material() if run != null and run.world.skin is HostileTakeoverSkin else null
	check(boss != null and boss.phase_index == 0 and boss.step == HostileTakeover.Step.ENTER and is_equal_approx(boss.health, boss.max_health)
		and run.context.attempt == 2 and run.world.player.alive and m != null and float(m.get_shader_parameter(&"break_age")) < 0.0
		and not boss.armored.in_use() and not boss.gunship.docked and not boss.screens.on,
		"after a death, quick play retries: the fight starts over, its entrance, at full health, the train whole %s" % tag)
	if boss == null:
		return
	bot = _bot(boss)
	won = await _won_phases(run, boss, 2, bot)
	var beaten: bool = won and await _play_until(run, boss, bot, func() -> bool: return boss.is_defeated())
	plan.append(_plan_of(boss))
	check(beaten and _events(boss, &"weak_point").size() == 5 and run.world.player.alive,
		"and the runner wins the whole fight in the retry %s" % tag)
	check(plan[1].begins_with(plan[0]) and plan[0].length() > 100,
		"the retry's train, guards, couplings, drops, rides and passes are the first attempt's %s" % tag)
	# The defeat plays out, then quick play starts the fight over.
	var old: HostileTakeover = boss
	for i: int in int((boss.tuning.defeat_seconds + LevelRun.COMPLETE_PAUSE + 1.5) * 60.0):
		if App.run == null or App.run.encounter != old:
			break
		bot.step()
		await tree.physics_frame
	var again: HostileTakeover = App.run.encounter as HostileTakeover if App.run != null else null
	check(again != null and again != old and again.phase_index == 0 and is_equal_approx(again.health, again.max_health),
		"once its defeat has played out, quick play starts the fight over %s" % tag)


## Plays `boss` in `run` with `bot` (a new one if none) until phase `count` + 1 begins: true if the runner
## stomped its way there alive.
func _won_phases(run: LevelRun, boss: HostileTakeover, count: int, bot: HostileTakeoverBot = null) -> bool:
	if bot == null:
		bot = _bot(boss)
	for i: int in 120 * 60:
		if boss.phase_index >= count or not run.world.player.alive:
			break
		bot.step()
		await tree.physics_frame
	return boss.phase_index == count and run.world.player.alive and _events(boss, &"weak_point").size() == count


## Plays `boss` in `run` with `bot` until `done` holds: true if it did with the runner alive.
func _play_until(run: LevelRun, boss: HostileTakeover, bot: HostileTakeoverBot, done: Callable) -> bool:
	for i: int in 120 * 60:
		if done.call() or not run.world.player.alive:
			break
		bot.step()
		await tree.physics_frame
	return done.call() and run.world.player.alive


## The plan of the carriages, drops, rides and passes the fight has laid out so far (no times).
func _plan_of(boss: HostileTakeover) -> String:
	var parts := PackedStringArray()
	for e: Dictionary in boss.events:
		if not e["event"] in [&"carriage_planned", &"drop_planned", &"ride_planned", &"pass_planned"]:
			continue
		var copy: Dictionary = e.duplicate()
		copy.erase("t")
		if e["event"] != &"carriage_planned" or int(copy["carriage"]) <= 8:
			parts.append(str(copy))
	return "\n".join(parts)


# --- The campaign ---------------------------------------------------------------------------------

## The campaign at every lane count (the Corporate zone's 23.4 m/s): Corporate 2 finished, then the fight;
## the first attempt wins phases 1 and 2 and dies once the war engine has docked (no checkpoint: GDD §10);
## the retry starts over and wins all three; its results and stars, the shop and the zone's outro.
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
	App.play_step(App.campaign.step("corporate/2"))
	await physics_frames(10)
	check(App.run != null and App.run.world.geo.lane_count == lanes, "Corporate 2 starts %s" % tag)
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
	await physics_frames(3)
	var run: LevelRun = App.run
	check(run != null and run.encounter is HostileTakeover and run.context.step.id == "corporate/boss"
		and run.world.geo.lane_count == lanes and is_equal_approx(run.world.tuning.run_speed, 23.4)
		and not run.world.player.god_mode, "then Hostile Takeover's fight, at the Corporate zone's 23.4 m/s, no god mode %s" % tag)
	if run == null or not run.encounter is HostileTakeover:
		return
	# The first attempt: phases 1 and 2 won, then a death once the war engine has docked.
	var boss := run.encounter as HostileTakeover
	var first := _bot(boss)
	var won: bool = await _won_phases(run, boss, 2, first)
	var docked: bool = won and await _play_until(run, boss, first, func() -> bool: return boss.docked)
	check(docked, "phases 1 and 2 fall to their stomps, and the war engine docks %s" % tag)
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
	await physics_frames(3)
	run = App.run
	boss = run.encounter as HostileTakeover if run != null else null
	check(boss != null and run.context.attempt == 2 and run.context.boss_resume.is_empty() and boss.phase_index == 0
		and boss.step == HostileTakeover.Step.ENTER and is_equal_approx(boss.health, boss.max_health),
		"the retry starts the fight over: its entrance, at full health (no checkpoint) %s" % tag)
	if boss == null:
		return
	# The retry, won.
	var bot := _bot(boss)
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
	check(phases.size() == 3 and stomps == 5, "the retry plays all three phases to the win (%d stomps) %s" % [stomps, tag])
	var result: RunResult = (App.screen as ResultsScreen).result if App.screen is ResultsScreen else null
	check(result != null and result.completed and result.context.is_boss(), "a win's results follow the defeat %s" % tag)
	if result == null:
		return
	check(result.stars == def.stars_for(true, result.time) and result.stars == 3,
		"three stars for a fight without a miss (%.1f s) %s" % [result.time, tag])
	check(App.profile.is_completed("corporate/boss"), "the boss step counts as done %s" % tag)
	App.continue_after_result(result)
	shop = App.screen as ShopScreen
	check(shop != null and shop.play_label == "Next", "then the shop %s" % tag)
	if shop == null:
		return
	shop.on_close.call()
	await tree.process_frame
	var outro := App.screen as SlotScreen
	var cine: Cinematic = App.playing_cinematic()
	check((outro != null and outro.step.id == "corporate/outro") or (cine != null and cine.step.id == "corporate/outro"),
		"then the Corporate zone's outro %s" % tag)
	await tree.process_frame

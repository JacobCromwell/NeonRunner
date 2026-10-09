extends TestSuite
## The boss framework (GDD §10, task B8): boss data (phases, stars from par times, the time bonus);
## the arena (planned from the seed lap by lap, the same on every attempt, joined ahead of the player
## for as long as the fight lasts, with pieces added during the fight); health and phases (a single
## hit never skips a phase, intros can't be hurt, the weapon cap, the checkpoint and resuming at it);
## the shared damage rules on a boss (claws never, the dash passes, weak points take stomps, on real
## physics too); no escalation (constant run speed, the same pattern cycle after cycle); the test boss's
## telegraphed attack; the standard armor rule's events; props, spawns, EMPs, parts with health of
## their own, the light and the HUD's boss bar; and the app flow around a boss (win, payout, records,
## stars, the leaderboard, death, revive, retry, the checkpoint restart, the web demo's end).

const TEST_BOSS_PATH: String = "res://data/bosses/test_boss.tres"

var sim: RunSim
var test_def: BossDef


func run() -> void:
	sim = RunSim.new(tree, tuning)
	test_def = load(TEST_BOSS_PATH) as BossDef
	_test_data()
	await _test_arena()
	await _test_arena_during_fight()
	await _test_health_and_phases()
	await _test_weapons_ending_a_phase()
	await _test_checkpoint_resume()
	await _test_damage_rules()
	await _test_stomp_on_real_physics()
	await _test_no_escalation()
	await _test_telegraphed_attack()
	await _test_armor_rule()
	await _test_props()
	await _test_hooks()
	await _test_light()
	await _test_hud_and_hints()
	await _test_app_flow()


# --- Helpers -------------------------------------------------------------------------------

## A fight in a bare RunWorld (no App, no LevelRun): the encounter's arena, a world built on it, and
## the encounter set up in it.
func _fight(enc: BossEncounter, def: BossDef, lanes: int = 5, loadout: Loadout = null,
		t: MovementTuning = null, resume: Dictionary = {}) -> RunWorld:
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = def
	ctx.config = BossArena.base_config(def)
	ctx.config.lane_count = lanes
	ctx.tuning = t if t != null else tuning
	ctx.boss_resume = resume
	var arena: BossArena = enc.plan_arena(ctx)
	var world: RunWorld = sim.build_world(arena.layout, loadout, ctx.tuning, ctx.config)
	enc.setup(world, ctx, arena)
	return world


## Steps the world until `condition` holds or `seconds` pass. True if it held.
func _until(world: RunWorld, condition: Callable, seconds: float) -> bool:
	if not world.player.running:
		await tree.physics_frame
		world.player.running = true
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		if condition.call():
			return true
		await tree.physics_frame
	return condition.call()


## The test boss's data with a plain track (no arena config), for exact scenarios.
func _plain_test_def() -> BossDef:
	var def: BossDef = test_def.duplicate() as BossDef
	def.arena = null
	return def


# --- Data ----------------------------------------------------------------------------------

func _test_data() -> void:
	var three: BossDef = DummyBoss.make_def([[1, 1, false, 0.5], [1, 1, true, 0.5], [1, 1, false, 0.5]])
	var ends: PackedFloat32Array = three.phase_ends()
	check(ends.size() == 3 and is_equal_approx(ends[0], 2.0 / 3.0) and is_equal_approx(ends[1], 1.0 / 3.0)
		and is_zero_approx(ends[2]), "three equal phases end at 2/3, 1/3 and 0 of the health (%s)" % [ends])
	var uneven: PackedFloat32Array = DummyBoss.make_def([[2, 1, false, 0.5], [1, 1, false, 0.5], [1, 1, false, 0.5]]).phase_ends()
	check(is_equal_approx(uneven[0], 0.5) and is_equal_approx(uneven[1], 0.25), "phase shares are scaled to add up (%s)" % [uneven])
	var none := BossDef.new()
	check(none.phase_count() == 1 and none.phase_ends().size() == 1 and none.checkpoint_phase() == -1,
		"a boss without phases has one")
	check(three.checkpoint_phase() == 1, "the checkpoint phase is found")
	# Stars and the time bonus (GDD §10, proposed).
	var d := BossDef.new()
	d.two_star_seconds = 75.0
	d.three_star_seconds = 50.0
	d.time_bonus_per_second = 50
	d.time_bonus_seconds = 120.0
	check(d.stars_for(false, 10.0) == 0 and d.stars_for(true, 45.0) == 3 and d.stars_for(true, 60.0) == 2
		and d.stars_for(true, 200.0) == 1, "one star for a win, two and three for beating the par times")
	check(d.time_bonus(60.0) == 3000 and d.time_bonus(130.0) == 0, "the time bonus pays for every second under its mark")

	# The test boss: built, outside the campaign, exercising a checkpoint and a faster phase.
	check(test_def != null and test_def.is_built(), "the test boss is built")
	var in_campaign: bool = false
	for zone: ZoneDef in (load("res://data/campaign/campaign.tres") as Campaign).zones:
		if zone.boss != null and zone.boss.id == test_def.id:
			in_campaign = true
	check(not in_campaign, "the test boss isn't in the campaign")
	var phases: Array[BossPhase] = test_def.phase_list()
	check(phases.size() == 3 and test_def.checkpoint_phase() == 1 and phases[2].pace > phases[0].pace,
		"the test boss has three phases, a checkpoint and a faster last phase")
	check(test_def.granted_items.has("armor") and test_def.tuning is TestBossTuning, "it grants armor and has its own tuning")
	var sfx := load("res://data/audio/sfx_library.tres") as SfxLibrary
	for sound: StringName in [&"truck_cannon_charge", &"truck_cannon", &"truck_bang", &"drone_swoop", &"truck_explode"]:
		check(sfx.stream(sound) != null, "the test boss's sound %s exists" % sound)

	# The campaign's boss slots carry the standard armor rule (GDD §10: 15–17 s; the Floating Head 10–15).
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	for zone: ZoneDef in campaign.zones:
		var b: BossDef = zone.boss
		var gentle: bool = zone.id == &"city"
		check(b.armor_rule and is_equal_approx(b.armor_delay_min, 10.0 if gentle else 15.0)
			and is_equal_approx(b.armor_delay_max, 15.0 if gentle else 17.0),
			"%s's boss uses the armor rule with a %s s delay" % [zone.id, "10–15" if gentle else "15–17"])


# --- The arena -----------------------------------------------------------------------------

func _test_arena() -> void:
	var config: LevelConfig = BossArena.base_config(test_def)
	config.lane_count = 5
	check(is_zero_approx(config.difficulty_ramp) and config.feature_starts.is_empty(),
		"the arena doesn't ramp up and has every feature from the start (GDD §10: no escalation)")
	check(config != test_def.arena, "the boss's arena config itself is left alone")
	var a: BossArena = BossArena.plan(test_def, config, tuning)
	var b: BossArena = BossArena.plan(test_def, config, tuning)
	check(a.laps.size() == test_def.arena_laps, "the arena plans its distinct laps (%d)" % a.laps.size())
	check(is_equal_approx(a.lap_length, tuning.run_speed * test_def.arena.duration_seconds),
		"a lap lasts the arena's duration at run speed (%.0f m)" % a.lap_length)
	check(var_to_str(a.layout.to_dict()) == var_to_str(b.layout.to_dict()), "the arena is the same on every attempt")
	check(a.laps_joined == BossArena.LAPS_AHEAD + 1 and is_equal_approx(a.layout.length, a.lap_length * a.laps_joined),
		"the track starts with the laps it needs ahead (%d)" % a.laps_joined)
	check(a.layout.credits.is_empty(), "the arena carries no credits (DESIGN-TBD: no pay for stalling)")
	var pieces: int = a.layout.gaps.size() + a.layout.fences.size() + a.layout.hulls.size()
	check(pieces > 0, "the laps have the runner's pieces (%d)" % pieces)
	var different: bool = var_to_str(a.laps[0].gaps) != var_to_str(a.laps[1].gaps)
	check(different, "each distinct lap has its own seed")
	# Lap k repeats lap k % n, moved along.
	var lap2: LevelLayout = a.lap(a.laps.size())
	var first: Dictionary = a.laps[0].gaps[0] if not a.laps[0].gaps.is_empty() else {}
	var moved: Dictionary = lap2.gaps[0] if not lap2.gaps.is_empty() else {}
	check(not first.is_empty() and is_equal_approx(float(moved.get("start", -1.0)), float(first["start"]) + a.lap_length * a.laps.size()),
		"the laps cycle: lap %d is lap 0 moved along" % a.laps.size())
	# Fair laps: the generator's fairness checks hold on every lap, at every lane count.
	for lanes: int in [3, 5, 6]:
		var c: LevelConfig = BossArena.base_config(test_def)
		c.lane_count = lanes
		var arena: BossArena = BossArena.plan(test_def, c, tuning)
		for i: int in arena.laps.size():
			LayoutChecks.check_layout(self, arena.laps[i], c, "(test boss arena lap %d, %d lanes)" % [i, lanes])

	# A plain arena: floor and walls only.
	var plain: BossArena = BossArena.plan(_plain_test_def(), config, tuning)
	check(plain.laps.size() == 1 and plain.layout.gaps.is_empty() and plain.layout.fences.is_empty(),
		"a boss without an arena config fights on a plain track")
	# GDD §3 (E1f): an arena at a zone's speed (its config's run_speed: the campaign's, Campaign.configure_boss)
	# is planned at that speed, as the generator builds a level: its laps last as many seconds, and the
	# clear stretches at a lap's start and end (the boss's entrance) keep theirs too. Quick play's and the
	# tests' arena keeps the base speed.
	check(config.run_speed == 0.0 and config.movement_for(tuning) == tuning and is_equal_approx(a.tuning.run_speed, tuning.run_speed),
		"quick play's arena runs at the base speed (%.1f m/s)" % a.tuning.run_speed)
	var fast_config: LevelConfig = config.duplicate() as LevelConfig
	fast_config.run_speed = 25.0
	var fast: BossArena = BossArena.plan(test_def, fast_config, tuning)
	var p: float = 25.0 / MovementTuning.REFERENCE_SPEED
	check(is_equal_approx(fast.tuning.run_speed, 25.0) and is_equal_approx(fast.tuning.pace(), p)
		and is_equal_approx(fast.lap_length, 25.0 * test_def.arena.duration_seconds),
		"an arena at 25 m/s is planned at its speed: a lap lasts its %.0f s (%.0f m)" % [test_def.arena.duration_seconds, fast.lap_length])
	var first_piece: float = INF
	var last_piece: float = -INF
	for lap: LevelLayout in fast.laps:
		for g: Dictionary in lap.gaps:
			first_piece = minf(first_piece, float(g["start"]))
			last_piece = maxf(last_piece, float(g["end"]))
		for f: Dictionary in lap.fences:
			first_piece = minf(first_piece, float(f["at"]))
			last_piece = maxf(last_piece, float(f["at"]))
	check(first_piece >= test_def.arena.start_clear_distance * p - 0.01
		and last_piece <= fast.lap_length - test_def.arena.end_clear_distance * p + 0.01,
		"its laps' clear start and end keep their seconds (pieces from %.0f m to %.0f m of %.0f)" % [first_piece, last_piece,
			fast.lap_length])
	for lanes: int in [3, 6]:
		var fc: LevelConfig = fast_config.duplicate() as LevelConfig
		fc.lane_count = lanes
		var fast_arena: BossArena = BossArena.plan(test_def, fc, tuning)
		for i: int in fast_arena.laps.size():
			LayoutChecks.check_layout(self, fast_arena.laps[i], fc, "(test boss arena at 25 m/s, lap %d, %d lanes)" % [i, lanes])


## During the fight the next laps join the track ahead of the player, for as long as it lasts; the
## boss adds its own pieces past the built track, and enemies of laps joined later still come in.
func _test_arena_during_fight() -> void:
	var fight_def: BossDef = DummyBoss.make_def([[1, 1, false, 0.2]])
	fight_def.arena = test_def.arena.duplicate() as LevelConfig
	fight_def.arena.duration_seconds = 30.0
	fight_def.arena.features = PackedStringArray(["ceilings", "cyborg"])
	fight_def.arena_laps = 2
	var enc := DummyBoss.new()
	var world: RunWorld = _fight(enc, fight_def, 5)
	check(enc.heard.has("plan_lap 0") and enc.heard.has("plan_lap 1"), "the boss shapes each distinct lap before the fight")
	var arena: BossArena = enc.arena
	world.player.god_mode = true
	world.player.grapples = 1_000_000
	await _until(world, func() -> bool: return true, 0.1)
	var spawned: Dictionary = {}
	world.director.enemy_spawned.connect(func(e: Enemy) -> void:
		if e.type_id == &"cyborg":
			spawned[e.spawn.get("at", 0.0)] = true)
	# Run through six laps a few metres a frame: the track must always be built ahead.
	var ok: bool = true
	var d: float = 0.0
	var laps: int = 6
	while d < arena.lap_length * laps:
		d += 12.0
		world.player.distance = d
		await tree.physics_frame
		if world.track.built_until() < d + TrackBuilder.BUILD_AHEAD - TrackBuilder.CHUNK_LENGTH \
				or world.layout.length < d + arena.lap_length:
			ok = false
			break
	check(ok, "the track keeps going ahead of the player lap after lap (%.0f m, built to %.0f m)" % [d, world.track.built_until()])
	check(arena.laps_joined == arena.lap_at(d) + BossArena.LAPS_AHEAD + 1, "a lap joins as the player enters the one before (%d)" % arena.laps_joined)
	var late: int = 0
	for at: Variant in spawned:
		if float(at) > arena.lap_length * 2.0:
			late += 1
	check(late > 0, "enemies of laps joined during the fight come into play (%d)" % late)

	# The boss's own pieces: past the built track they join it; nearer ones are refused.
	var extra := LevelLayout.new()
	extra.lane_count = 5
	var far: float = arena.stream_from() + 30.0
	extra.fences.append(RunSim.fence(1, far, "full"))
	extra.fences.append(RunSim.fence(2, d + 10.0, "full"))
	var added: int = arena.add_pieces(extra)
	check(added == 1, "a piece past the built track joins it, a nearer one is left out (%d)" % added)
	world.player.distance = far - 60.0
	await tree.physics_frame
	await tree.physics_frame
	var found: bool = false
	for h: Hazard in world.track.fence_hazards():
		if absf(-h.global_position.z - far) < 0.5 and absf(h.global_position.x - world.geo.lane_x(1)) < 0.1:
			found = true
	check(found, "the added fence is built when the player comes near")
	check(arena.live_fence_between(far - 1.0, far + 1.0, 1) and not arena.floor_clear(far - 1.0, far + 1.0),
		"the arena's queries see the added fence")
	await sim.free_world(world)


# --- Health and phases ---------------------------------------------------------------------

func _test_health_and_phases() -> void:
	var def: BossDef = DummyBoss.make_def([[1, 1, false, 0.5], [1, 2, true, 0.5], [1, 1, false, 0.5]], 90.0)
	def.weapon_share_cap = 0.2
	var enc := DummyBoss.new()
	var world: RunWorld = _fight(enc, def, 5)
	var started: Array[int] = []
	var ended: Array[int] = []
	var checkpoints: Array[int] = []
	enc.phase_started.connect(func(i: int) -> void: started.append(i))
	enc.phase_ended.connect(func(i: int) -> void: ended.append(i))
	enc.checkpoint_reached.connect(func(i: int) -> void: checkpoints.append(i))
	check(enc.phase_index == 0 and enc.state == BossEncounter.State.INTRO and not enc.is_vulnerable(),
		"the fight starts with the first phase's intro")
	check(is_zero_approx(enc.damage(30.0, &"weapon")) and is_equal_approx(enc.health, 90.0), "the boss can't be hurt during an intro")
	check(not enc.body.targetable(), "and auto-fire leaves it alone meanwhile")
	await _until(world, func() -> bool: return enc.is_vulnerable(), 2.0)
	check(enc.is_vulnerable() and enc.heard.has("pattern 0"), "after the intro, the pattern runs and the boss can be hurt")
	check(enc.body.targetable() and enc.body.is_boss and enc.body.claw_immune and not enc.body.dash_kills,
		"its body is a boss's: targetable, claw-immune, not killed by the dash")

	# Weapons chip, up to the cap.
	enc.body.take_damage(10.0, &"weapon")
	check(is_equal_approx(enc.health, 80.0) and is_equal_approx(enc.body.health, 80.0), "weapon hits hurt the boss (%.1f)" % enc.health)
	enc.body.take_damage(10.0, &"weapon", true)
	check(is_equal_approx(enc.health, 80.0), "splash damage doesn't count")
	enc.body.take_damage(20.0, &"weapon")
	check(is_equal_approx(enc.weapon_damage, 18.0) and is_equal_approx(enc.health, 72.0),
		"weapons stop at the boss's cap (%.1f dealt)" % enc.weapon_damage)
	check(not enc.weapons_can_hurt() and not enc.body.targetable(), "then auto-fire stops aiming at it")
	check(is_zero_approx(enc.damage(5.0, &"weapon")), "and weapon damage does nothing more")

	# A big hit takes the rest of the phase (hit_damage), with chip damage carried.
	check(is_equal_approx(enc.hit_damage(), 30.0), "a big hit is the phase's share over its hits (%.1f)" % enc.hit_damage())
	enc.damage(enc.hit_damage(), &"stomp")
	check(ended == [0] and enc.phase_index == 1 and enc.state == BossEncounter.State.INTRO,
		"the hit ends the phase and the next one's intro begins")
	check(is_equal_approx(enc.health, 42.0), "the damage beyond the phase carries into the next (%.1f)" % enc.health)
	check(checkpoints == [1] and int(enc.context.boss_resume.get("phase", -1)) == 1,
		"reaching the checkpoint phase stores where a retry resumes (%s)" % [enc.context.boss_resume])
	check(is_equal_approx(float(enc.context.boss_resume.get("weapon_damage", -1.0)), 18.0),
		"with the weapon damage so far")
	await _until(world, func() -> bool: return enc.is_vulnerable(), 2.0)
	check(is_equal_approx(enc.hit_damage(), 15.0), "a phase with two hits takes half its share each (%.1f)" % enc.hit_damage())

	# A single hit never skips a phase.
	enc.damage(1000.0, &"test")
	check(enc.phase_index == 2 and not enc.is_defeated(), "a huge hit ends only the current phase")
	check(enc.health > 0.0 and enc.health <= 30.0 + 0.1, "and leaves the next phase's health (%.2f)" % enc.health)
	await _until(world, func() -> bool: return enc.is_vulnerable(), 2.0)
	var score_before: int = world.score.score
	var defeats: Array[int] = [0]
	enc.defeated.connect(func() -> void: defeats[0] += 1)
	enc.damage(1000.0, &"stomp")
	check(enc.is_defeated() and defeats[0] == 1 and enc.heard.has("defeated"), "the last phase's end beats the boss")
	check(enc.heard.has("phase_started 0") and started == [1, 2] and ended == [0, 1],
		"every phase started once and ended in order (%s, %s)" % [started, ended])
	check(not is_instance_valid(enc.body) or not enc.body.alive, "its parts are defeated with it")
	var gained: int = world.score.score - score_before
	check(gained >= def.defeat_score and int(world.score.bonuses.get("boss", 0)) == def.defeat_score,
		"the defeat scores (%d)" % gained)
	check(int(world.score.bonuses.get("time", 0)) == def.time_bonus(enc.fight_time()), "with the time bonus")
	check(world.score.kills == 1, "and counts one kill (%d)" % world.score.kills)
	var frozen: float = enc.fight_time()
	await _until(world, func() -> bool: return false, 0.3)
	check(is_equal_approx(enc.fight_time(), frozen), "the fight time stops at the defeat")
	check(is_zero_approx(enc.damage(10.0, &"weapon")), "a beaten boss takes no more damage")
	await sim.free_world(world)


## BossDef.weapons_can_end_phase: on (every boss's default, GDD §10's Floating Head rule: the best weapon
## may save a stomp), weapon hits chipped to a phase's end end it; off (DESIGN-TBD, Hostile Takeover's),
## they chip it only to just above its end, auto-fire then leaves the boss alone, and its big hits are
## counted: each takes an equal part of what's left, and only its last one ends the phase (exactly at its
## end, nothing carried), the last phase's too, however much weapons chipped it.
func _test_weapons_ending_a_phase() -> void:
	for can_end: bool in [true, false]:
		var tag: String = "(weapons_can_end_phase %s)" % ("on" if can_end else "off")
		var def: BossDef = DummyBoss.make_def([[1, 1, false, 0.2], [1, 3, false, 0.2]], 100.0)
		def.weapon_share_cap = 1.0
		def.weapons_can_end_phase = can_end
		var enc := DummyBoss.new()
		var world: RunWorld = _fight(enc, def, 5)
		await _until(world, func() -> bool: return enc.is_vulnerable(), 2.0)
		for i: int in 6:
			enc.body.take_damage(10.0, &"weapon")
		if can_end:
			check(enc.phase_index == 1 and is_equal_approx(enc.health, 50.0), "weapons alone end a phase (%.1f) %s" % [enc.health, tag])
		else:
			check(enc.phase_index == 0 and enc.health > 50.0 and enc.health < 50.1 and not enc.weapons_can_hurt()
				and not enc.body.targetable(), "weapons chip a phase only to just above its end (%.3f) %s" % [enc.health, tag])
			enc.damage(enc.hit_damage(), &"stomp")
			check(enc.phase_index == 1 and is_equal_approx(enc.health, 50.0), "its big hit ends it exactly at its end (%.3f) %s" % [enc.health, tag])
			await _until(world, func() -> bool: return enc.is_vulnerable(), 2.0)
			check(is_equal_approx(enc.hit_damage(), 50.0 / 3.0), "unchipped, a hit is the phase's share over its hits %s" % tag)
			for i: int in 8:
				enc.body.take_damage(10.0, &"weapon")
			check(enc.phase_index == 1 and not enc.is_defeated() and enc.health > 0.0 and enc.health < 0.1,
				"in the last phase weapons never beat the boss (%.3f) %s" % [enc.health, tag])
			var beaten_after: int = 0
			for i: int in 3:
				enc.damage(enc.hit_damage(), &"stomp")
				if enc.is_defeated() and beaten_after == 0:
					beaten_after = i + 1
			check(beaten_after == 3, "chipped to its floor, the last phase still takes all three of its hits (%d) %s" % [beaten_after, tag])
		await sim.free_world(world)


## A retry after a checkpoint starts at that phase, with the fight so far carried.
func _test_checkpoint_resume() -> void:
	var def: BossDef = DummyBoss.make_def([[1, 1, false, 0.5], [1, 1, true, 0.5], [1, 1, false, 0.5]], 90.0)
	def.weapon_share_cap = 0.2
	var enc := DummyBoss.new()
	var world: RunWorld = _fight(enc, def, 5, null, null, {"phase": 1, "time": 20.0, "score": 1500, "weapon_damage": 18.0})
	check(enc.phase_index == 1 and is_equal_approx(enc.health, 60.0), "the fight resumes at the checkpoint phase (%.0f)" % enc.health)
	check(is_equal_approx(enc.carried_time, 20.0) and world.score.score == 1500, "with the time and score carried")
	check(not enc.weapons_can_hurt(), "and the weapon damage already dealt")
	await _until(world, func() -> bool: return world.player.elapsed > 0.5, 1.0)
	check(enc.fight_time() > 20.4, "the fight time goes on from the carried time (%.1f)" % enc.fight_time())
	check(int(enc.context.boss_resume.get("phase", -1)) == 1 and is_equal_approx(float(enc.context.boss_resume.get("time", 0.0)), 20.0),
		"resuming doesn't move the checkpoint")
	await sim.free_world(world)


# --- The shared damage rules on a boss ---------------------------------------------------------

## GDD §8, §10: bosses ignore claw contact kills, only weak points (stomped) and weapons hurt them, and
## the dash passes through them safely. The boss's parts only declare it; DamageRules decides.
func _test_damage_rules() -> void:
	var def: BossDef = DummyBoss.make_def([[1, 1, false, 0.1], [1, 1, false, 0.1]])
	var enc := DummyBoss.new()
	var world: RunWorld = _fight(enc, def, 5)
	await _until(world, func() -> bool: return enc.is_vulnerable(), 1.0)
	var part: BossPart = enc.body
	var body: Hazard = part.get(&"body")
	var weak: Hazard = part.get(&"weak")
	var d := DamageRules.Defense.new()
	d.claws = true
	check(DamageRules.resolve(body, d) == DamageRules.Outcome.KILL, "claws never defeat a boss: its body still kills")
	d.claws = false
	d.dashing = true
	check(DamageRules.resolve(body, d) == DamageRules.Outcome.IGNORE, "the dash passes through a boss safely")
	check(DamageRules.resolve(weak, d, true) == DamageRules.Outcome.STOMP, "a stomp on a weak point counts while dashing")
	d.dashing = false
	check(DamageRules.resolve(weak, d, true) == DamageRules.Outcome.STOMP and DamageRules.resolve(weak, d, false) == DamageRules.Outcome.IGNORE,
		"weak points take stomps and are harmless otherwise")
	# Through the player, as a real contact.
	world.player.claws = true
	var outcome: DamageRules.Outcome = world.player.receive_hit(weak, true)
	check(outcome == DamageRules.Outcome.STOMP and enc.weak_points_hit == 1 and enc.heard.has("weak_point"),
		"a stomp on the weak point is a hit on the boss")
	check(enc.phase_index == 1 and part.alive and world.player.alive and world.player.vh > 0.0,
		"it takes the phase, the boss's body stays, and the player bounces")
	check(world.score.stomps == 1 and int(world.score.bonuses.get("weak_point", 0)) == def.weak_point_score and world.score.kills == 0,
		"it scores as a stomp on a weak point, not as a kill")
	check(not weak.is_active(), "the weak point goes dark until the boss script shows it again")
	world.player.receive_hit(body, false)
	check(part.alive and not world.player.alive, "claws don't save the player from the boss's body either")
	await sim.free_world(world)


## A real stomp on the test boss: it drops dazed into the player's lane, and a jump timed onto its
## weak point takes the phase (on real physics, through the player's own stomp detection).
func _test_stomp_on_real_physics() -> void:
	var enc := BossEncounter.create(test_def) as TestBoss
	check(enc != null, "the test boss's scene makes a TestBoss")
	if enc == null:
		return
	var world: RunWorld = _fight(enc, _plain_test_def(), 5)
	world.player.god_mode = true
	var dropping: bool = await _until(world, func() -> bool: return enc.step == TestBoss.Step.DROP, 40.0)
	check(dropping and enc.target_lane == world.player.lane,
		"the test boss drops into the player's lane ahead (%s)" % [TestBoss.Step.keys()[enc.step]])
	if not dropping:
		await sim.free_world(world)
		return
	var spot: float = enc.drop_spot
	await _until(world, func() -> bool: return world.player.distance >= spot - 10.3, 5.0)
	check(enc.step == TestBoss.Step.DAZED and enc.body.weak_points_enabled(),
		"it lies dazed with its weak point up before the player gets there")
	world.player.press(&"jump")
	var hit: bool = await _until(world, func() -> bool: return enc.weak_points_hit > 0 or world.player.distance > spot + 4.0, 3.0)
	check(hit and enc.weak_points_hit == 1, "a jump onto the dazed core stomps its weak point")
	check(enc.phase_index == 1 and enc.state == BossEncounter.State.INTRO, "which ends the phase: the core shakes free and rises")
	check(int(enc.context.boss_resume.get("phase", -1)) == 1, "the second phase is the test boss's checkpoint")
	await sim.free_world(world)


# --- No escalation --------------------------------------------------------------------------

## GDD §10: no time limit, no escalation. The run speed never rises during a fight, and a pattern that
## isn't beaten keeps cycling the same way; only a later phase may be faster.
func _test_no_escalation() -> void:
	var gaining: MovementTuning = tuning.duplicate() as MovementTuning
	gaining.speed_gain_per_minute = 3.0
	var boss_tuning: MovementTuning = App._boss_tuning(gaining)
	check(is_zero_approx(boss_tuning.speed_gain_per_minute) and is_equal_approx(gaining.speed_gain_per_minute, 3.0),
		"a boss fight's tuning never speeds the run up (and leaves the level tuning alone)")
	var cycles: Dictionary = {}
	for phase: int in [0, 2]:
		var enc := BossEncounter.create(test_def) as TestBoss
		var world: RunWorld = _fight(enc, _plain_test_def(), 5, null, boss_tuning, {"phase": phase} if phase > 0 else {})
		world.player.god_mode = true
		var steady: Array[bool] = [true]
		await _until(world, func() -> bool:
			if absf(world.player.speed - boss_tuning.run_speed) > 0.001:
				steady[0] = false
			return _count(enc, &"drop") >= 3, 70.0)
		var drops: Array[float] = _times(enc, &"drop")
		var blasts: Array[float] = _times(enc, &"blast")
		check(drops.size() >= 3, "phase %d: the pattern keeps cycling while the player misses (%d windows)" % [phase + 1, drops.size()])
		check(steady[0], "phase %d: the run speed stays the same all fight" % (phase + 1))
		check(enc.phase_index == phase and enc.is_vulnerable() and is_equal_approx(enc.health, enc.phase_start_health(phase)),
			"phase %d: nothing else changes while the player struggles" % (phase + 1))
		if drops.size() >= 3:
			var a: float = drops[1] - drops[0]
			var b: float = drops[2] - drops[1]
			check(absf(a - b) < 0.05, "phase %d: every cycle takes as long as the last (%.2f s, %.2f s)" % [phase + 1, a, b])
			cycles[phase] = b
			check(blasts.size() >= 2 * (drops.size() - 1), "phase %d: two blasts every cycle (%d)" % [phase + 1, blasts.size()])
		await sim.free_world(world)
	if cycles.size() == 2:
		check(cycles[2] < cycles[0], "the last, faster phase cycles quicker (%.2f s vs %.2f s)" % [cycles[2], cycles[0]])


func _times(enc: BossEncounter, event: StringName) -> Array[float]:
	var out: Array[float] = []
	for e: Dictionary in enc.events:
		if e["event"] == event:
			out.append(float(e["t"]))
	return out


func _count(enc: BossEncounter, event: StringName) -> int:
	return _times(enc, event).size()


# --- The test boss's telegraphed attack ------------------------------------------------------

## Every attack has a visual and an audio warning first (CLAUDE.md): the lane lights up and the core
## charges before any bolt flies, and leaving the lane dodges the burst.
func _test_telegraphed_attack() -> void:
	for dodge: bool in [false, true]:
		var enc := BossEncounter.create(test_def) as TestBoss
		var world: RunWorld = _fight(enc, _plain_test_def(), 5)
		var charging: bool = await _until(world, func() -> bool: return enc.step == TestBoss.Step.CHARGE, 20.0)
		check(charging and enc.props.count() > 0, "a blast starts with its red lane warning (%s)" % ("dodging" if dodge else "staying"))
		var lane: int = enc.target_lane
		if dodge:
			world.player.press(&"move_left" if lane > 0 else &"move_right")
		var cause: Array[String] = [""]
		world.player.died.connect(func(c: String) -> void: cause[0] = c)
		await _until(world, func() -> bool: return enc.step == TestBoss.Step.COOLDOWN or not world.player.alive, 5.0)
		await _until(world, func() -> bool: return not world.player.alive, 2.0)
		var blast: Array[float] = _times(enc, &"blast")
		var bolts: Array[float] = _times(enc, &"bolt")
		check(not blast.is_empty() and not bolts.is_empty() and bolts[0] - blast[0] >= enc.tuning.charge_seconds / enc.pace() - 0.02,
			"the first bolt flies only after the full charge-up")
		if dodge:
			check(world.player.alive, "leaving the lit lane dodges the whole burst")
		else:
			check(not world.player.alive and cause[0] == TestBoss.BOLT_NAME, "staying in it gets hit (%s)" % cause[0])
		await sim.free_world(world)


# --- The standard armor rule -----------------------------------------------------------------

## GDD §10: an armor pickup at the start of the final phase, and another a while after the player's
## armor or shield breaks, at most once per phase. The fight says when; task B7 places the pickups.
func _test_armor_rule() -> void:
	var def: BossDef = DummyBoss.make_def([[1, 1, false, 0.1], [1, 1, false, 0.1], [1, 1, false, 0.1]])
	def.armor_delay_min = 2.0
	def.armor_delay_max = 3.0
	var loadout := Loadout.new()
	loadout.armor = true
	loadout.charges = {&"shield": 1}
	var enc := DummyBoss.new()
	var world: RunWorld = _fight(enc, def, 5, loadout)
	var due: Array = []
	var broken: Array[StringName] = []
	enc.armor_pickup_due.connect(func(reason: StringName) -> void: due.append([reason, enc.fight_time(), enc.phase_index]))
	enc.protection_broken.connect(func(item: StringName) -> void: broken.append(item))
	await _until(world, func() -> bool: return enc.is_vulnerable(), 1.0)
	var shot := Hazard.new()
	shot.hazard_name = "test shot"
	shot.is_enemy_attack = true
	world.player.receive_hit(shot)
	var t0: float = enc.fight_time()
	check(broken == [&"armor"], "the fight hears the armor break")
	await _until(world, func() -> bool: return not due.is_empty(), 4.0)
	check(due.size() == 1 and due[0][0] == &"protection_broken", "a pickup is due after the break (%s)" % [due])
	if not due.is_empty():
		var delay: float = float(due[0][1]) - t0
		check(delay >= 2.0 - 0.02 and delay <= 3.0 + 0.02, "after the boss's delay (%.2f s)" % delay)
	world.player.invulnerable_left = 0.0
	world.player.receive_hit(shot)
	await _until(world, func() -> bool: return due.size() > 1, 4.0)
	check(broken == [&"armor", &"shield"] and due.size() == 1, "a second break in the same phase brings none (%s)" % [due])
	enc.damage(enc.hit_damage(), &"test")
	await _until(world, func() -> bool: return enc.is_vulnerable(), 1.0)
	world.player.armor = 1
	world.player.invulnerable_left = 0.0
	world.player.receive_hit(shot)
	await _until(world, func() -> bool: return due.size() > 1, 4.0)
	check(due.size() == 2 and due[1][0] == &"protection_broken" and int(due[1][2]) == 1, "a break in the next phase brings one again")
	enc.damage(enc.hit_damage(), &"test")
	check(due.size() == 3 and due[2][0] == &"final_phase" and enc.is_final_phase(), "the final phase begins with one (%s)" % [due])
	await sim.free_world(world)
	# Without the rule, nothing is due.
	def.armor_rule = false
	enc = DummyBoss.new()
	world = _fight(enc, def, 5, loadout)
	var none: Array[int] = [0]
	enc.armor_pickup_due.connect(func(_r: StringName) -> void: none[0] += 1)
	await _until(world, func() -> bool: return enc.is_vulnerable(), 1.0)
	world.player.receive_hit(shot)
	enc.damage(enc.hit_damage(), &"test")
	enc.damage(enc.hit_damage(), &"test")
	await _until(world, func() -> bool: return false, 3.5)
	check(none[0] == 0, "a boss without the armor rule never asks for pickups")
	shot.free()
	await sim.free_world(world)


# --- Props, hooks and the light ---------------------------------------------------------------

## What a boss puts in the arena within sight (BossProps): fences, blocks, pads and ceilings, a wall
## taken away, and floor warnings, all with the track's rules, and freed once passed.
func _test_props() -> void:
	var def: BossDef = DummyBoss.make_def([[1, 1, false, 0.1]])
	var enc := DummyBoss.new()
	var world: RunWorld = _fight(enc, def, 5)
	# The dummy's solid body keeps ahead in the first lane, out of the way.
	enc.lane = 0
	await _until(world, func() -> bool: return enc.is_vulnerable(), 1.0)
	enc.lane = 0
	var props: BossProps = enc.props
	var d: float = world.player.distance
	# A fence that comes in flickering: harmless while it warns, then a normal fence.
	var fence: Hazard = props.fence(1, d + 80.0, "full", 0.5)
	check(fence.is_electrical and fence.state == Hazard.State.WARNING and not fence.is_active(), "a fence can come in with its warning first")
	await _until(world, func() -> bool: return fence.is_active(), 1.0)
	check(fence.is_active(), "then it switches on")
	var armored := DamageRules.Defense.new()
	armored.armor = true
	var clawed := DamageRules.Defense.new()
	clawed.claws = true
	check(DamageRules.resolve(fence, armored) == DamageRules.Outcome.BLOCKED_ARMOR and DamageRules.resolve(fence, clawed) == DamageRules.Outcome.KILL,
		"with the normal fence rules: armor gets through, claws don't")
	# A block slammed into a lane: solid (armor doesn't help), and the player can't switch into it.
	var block_at: float = world.player.distance + 40.0
	var block: Hazard = props.block(3, block_at, Vector3(2.0, 1.5, 4.0), "gold block")
	check(block.is_solid and DamageRules.resolve(block, armored) == DamageRules.Outcome.KILL, "a block is a solid obstacle")
	world.player.distance = block_at + 1.0
	await tree.physics_frame
	await tree.physics_frame
	check(world.player.call(&"_lane_blocked", 3) and not world.player.call(&"_lane_blocked", 1), "switching into the block's lane bumps back")
	# A pad under a ceiling: the player flips up, rides it, and drops back after it ends.
	var pad_at: float = world.player.distance + 45.0
	props.pad(2, pad_at)
	props.ceiling(pad_at - 3.0, pad_at + 50.0)
	var up: bool = await _until(world, func() -> bool: return world.player.surface == Player.Surface.CEILING, 5.0)
	check(up, "a pad placed during the fight flips the player onto its ceiling")
	var landed := func() -> bool:
		return world.player.surface == Player.Surface.FLOOR and world.player.grounded and world.player.distance > pad_at + 50.0
	var down: bool = await _until(world, landed, 6.0)
	check(down and world.player.alive, "and the player drops back when the ceiling ends")
	# A wall taken away: entering it there is refused.
	var events: Array[StringName] = []
	world.player.movement_event.connect(func(kind: StringName) -> void: events.append(kind))
	var wall_from: float = world.player.distance + 15.0
	props.block_wall(1, wall_from, wall_from + 40.0)
	world.player.press(&"move_right")
	world.player.press(&"move_right")
	await _until(world, func() -> bool: return world.player.lane == 4, 2.0)
	await _until(world, func() -> bool: return world.player.distance > wall_from + 5.0, 3.0)
	world.player.press(&"move_right")
	await _until(world, func() -> bool: return events.has(&"wall_blocked"), 0.5)
	check(events.has(&"wall_blocked") and world.player.surface == Player.Surface.FLOOR, "a wall taken away can't be entered")
	await _until(world, func() -> bool: return world.player.distance > wall_from + 45.0, 4.0)
	world.player.press(&"move_right")
	var entered: bool = await _until(world, func() -> bool: return world.player.surface == Player.Surface.WALL, 0.5)
	check(entered, "past it, the wall is there again")
	# Warnings, and props freed once passed.
	var line: MeshInstance3D = props.lane_warning(2, world.player.distance, world.player.distance + 30.0)
	var circle: MeshInstance3D = props.circle_warning(world.player.distance + 20.0, 1, 1.2)
	check(is_instance_valid(line) and is_instance_valid(circle) and line.visible and circle.visible, "floor warnings show")
	props.remove(line)
	await tree.process_frame
	check(not is_instance_valid(line), "a warning goes when its attack comes")
	world.player.distance += 200.0
	await tree.physics_frame
	await tree.process_frame
	check(props.count() == 0 and not is_instance_valid(circle) and not is_instance_valid(fence), "everything is freed once the player is past")
	await sim.free_world(world)


## Hooks for what the designed bosses need (GDD §10): normal enemies spawned mid-fight, EMPs reaching
## the boss (Sleep Taker), parts with health of their own (the Sewer Swarm's clusters).
func _test_hooks() -> void:
	var def: BossDef = DummyBoss.make_def([[1, 1, false, 0.1], [1, 2, false, 0.1], [1, 1, false, 0.1]])
	var seeds: Array[int] = []
	for i: int in 2:
		var enc := DummyBoss.new()
		var world: RunWorld = _fight(enc, def, 5)
		await _until(world, func() -> bool: return enc.is_vulnerable(), 1.0)
		var cyborg: Enemy = enc.spawn_enemy("cyborg", enc.player_distance() + 60.0, 1)
		check(cyborg != null and cyborg.type_id == &"cyborg" and world.director.active.has(cyborg),
			"a boss brings a normal enemy into play mid-fight (the cyborg drop)")
		seeds.append(int(cyborg.spawn["seed"]) if cyborg != null else -1)
		if i == 0:
			# An EMP reaching the boss.
			world.emp(enc.body.global_position, 6.0)
			check(enc.heard.has("emp") and enc.phase_index == 1, "an EMP near the boss reaches it (Sleep Taker's weakness)")
			await _until(world, func() -> bool: return enc.is_vulnerable(), 1.0)
			# A part with health of its own.
			var cluster: BossPart = enc.add_part(load(DummyBoss.PART_SCRIPT) as Script,
				{"shares_health": false, "health": 3.0, "swarm": true})
			cluster.position = world.lane_point(3, enc.player_distance() + 30.0)
			check(cluster.targetable() and cluster.is_swarm and is_equal_approx(cluster.max_health, 3.0),
				"a part can have health of its own (a swarm cluster)")
			var health: float = enc.health
			cluster.take_damage(1.0, &"weapon")
			check(is_equal_approx(enc.health, health) and is_equal_approx(cluster.health, 2.0), "weapons hurt the part, not the boss")
			check(EnemyHealthBars.wants_bar(cluster) and not EnemyHealthBars.wants_bar(enc.body),
				"the part shows a health bar; the boss's body has the HUD's bar instead")
			cluster.take_damage(2.0, &"weapon")
			check(not cluster.alive and enc.heard.has("part_defeated weapon") and enc.health < health,
				"its defeat reaches the boss script, which hurts the boss")
			check(world.score.kills == 0, "a part declared as an obstacle isn't a kill")
			var baited: BossPart = enc.add_part(load(DummyBoss.PART_SCRIPT) as Script, {"shares_health": false, "health": 3.0})
			baited.defeat(&"fence")
			check(enc.heard.has("part_defeated fence") and enc.phase_index == 2, "a boss script can defeat a part itself (baited into a fence)")
		await sim.free_world(world)
	check(seeds.size() == 2 and seeds[0] == seeds[1], "enemies a boss brings in are the same on every attempt")


## GDD §10 (Sleep Taker): the arena gets darker, but never pitch black, and the light comes back.
func _test_light() -> void:
	var env := Environment.new()
	env.ambient_light_energy = 1.0
	env.background_energy_multiplier = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	tree.root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.8
	tree.root.add_child(sun)
	env.fog_light_energy = 1.0
	# The arena's own darker light (LevelConfig.darkness, as LevelRun sets it).
	ZoneSkin.set_scenery_light(0.8)
	var enc := DummyBoss.new()
	var world: RunWorld = _fight(enc, DummyBoss.make_def([[1, 1, false, 0.1]]), 5)
	await _until(world, func() -> bool: return enc.is_vulnerable(), 1.0)
	enc.set_light_level(0.05, 0.5)
	await _until(world, func() -> bool: return is_equal_approx(enc.light_level(), BossEncounter.MIN_LIGHT_LEVEL), 1.0)
	check(is_equal_approx(enc.light_level(), BossEncounter.MIN_LIGHT_LEVEL), "the light never goes below its floor (%.2f)" % enc.light_level())
	check(is_equal_approx(env.ambient_light_energy, BossEncounter.MIN_LIGHT_LEVEL) and is_equal_approx(sun.light_energy, 0.8 * BossEncounter.MIN_LIGHT_LEVEL),
		"the ambient light and the sun dim (%.2f, %.2f)" % [env.ambient_light_energy, sun.light_energy])
	# The skins' scenery is unshaded: its own light (scenery_light) dims too, never below its floor.
	check(is_equal_approx(ZoneSkin.scenery_light_now, ZoneSkin.MIN_SCENERY_LIGHT) and is_equal_approx(env.fog_light_energy, BossEncounter.MIN_LIGHT_LEVEL),
		"the scenery's light and the fog's dim, never below the scenery's floor (%.2f, %.2f)" % [ZoneSkin.scenery_light_now, env.fog_light_energy])
	enc.set_light_level(0.9, 0.0)
	check(is_equal_approx(ZoneSkin.scenery_light_now, 0.72), "the scenery's light follows the arena's own (0.8 × 0.9: %.2f)" % ZoneSkin.scenery_light_now)
	enc.set_light_level(1.0, 0.0)
	check(is_equal_approx(env.ambient_light_energy, 1.0) and is_equal_approx(ZoneSkin.scenery_light_now, 0.8), "and come back")
	enc.set_light_level(0.5, 0.0)
	await sim.free_world(world)
	check(is_equal_approx(sun.light_energy, 0.8) and is_equal_approx(env.ambient_light_energy, 1.0)
		and is_equal_approx(env.fog_light_energy, 1.0) and is_equal_approx(ZoneSkin.scenery_light_now, 0.8),
		"the fight gives the light back when it ends")
	# A newer run's own light stays: the fight only gives back the light it set.
	var enc2 := DummyBoss.new()
	world = _fight(enc2, DummyBoss.make_def([[1, 1, false, 0.1]]), 5)
	await _until(world, func() -> bool: return enc2.is_vulnerable(), 1.0)
	enc2.set_light_level(0.5, 0.0)
	ZoneSkin.set_scenery_light(0.6)
	await sim.free_world(world)
	check(is_equal_approx(ZoneSkin.scenery_light_now, 0.6), "a newer run's scenery light stays when the old fight ends (%.2f)" % ZoneSkin.scenery_light_now)
	ZoneSkin.set_scenery_light(1.0)
	we.queue_free()
	sun.queue_free()
	await tree.process_frame


## The HUD shows a boss's health bar with phase markers in the progress meter's place, and the
## first boss brings its hint.
func _test_hud_and_hints() -> void:
	var enc := DummyBoss.new()
	var world: RunWorld = _fight(enc, DummyBoss.make_def([[1, 1, false, 0.1], [1, 1, true, 0.1], [1, 1, false, 0.1]]), 5)
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.CAMPAIGN
	var hud := RunHud.new()
	tree.root.add_child(hud)
	hud.bind(world, ctx)
	var profile := Profile.new()
	var hints := HintDirector.new()
	world.add_child(hints)
	hints.setup(world, profile, false)
	var shown: Array[String] = []
	hints.hint_shown.connect(func(id: String, _text: String) -> void: shown.append(id))
	hints.acknowledge(hints.intro_hints)
	await _until(world, func() -> bool: return enc.is_vulnerable(), 1.0)
	await tree.process_frame
	check(hud.boss_bar.visible and not hud.progress.visible, "a boss fight shows the boss bar instead of the progress meter")
	check(hud.boss_bar.marks.size() == 2 and is_equal_approx(hud.boss_bar.marks[0], 2.0 / 3.0), "with a marker where each phase ends")
	check(hud.boss_bar.name_label.text == "DUMMY BOSS" and hud.boss_bar.phase_label.text.contains("1/3"), "the boss's name and phase")
	check(shown.has("boss"), "the first boss brings its hint (%s)" % [shown])
	enc.damage(enc.hit_damage(), &"stomp")
	await tree.process_frame
	await tree.process_frame
	check(is_equal_approx(hud.boss_bar.value, 2.0 / 3.0) and hud.boss_bar.drain_value() > hud.boss_bar.value,
		"the bar drops with the hit, a white segment draining after it")
	check(not hud.boss_bar.vulnerable and hud.boss_bar.phase_label.text.contains("2/3"), "and greys out while the boss can't be hurt")
	check(hud.hint_text().contains("Checkpoint"), "a checkpoint says so (%s)" % hud.hint_text())
	var view := Rect2(Vector2.ZERO, hud.root.get_viewport_rect().size)
	var bar_rect: Rect2 = hud.boss_bar.get_global_rect()
	var hint_rect: Rect2 = (hud.get_node(^"HudRoot/SafeFrame/Hint") as Control).get_global_rect()
	var score_rect: Rect2 = (hud.get_node(^"HudRoot/SafeFrame/Score") as Control).get_global_rect()
	check(view.encloses(bar_rect) and not bar_rect.intersects(hint_rect) and not bar_rect.intersects(score_rect),
		"the bar is on screen, clear of the hint and the score (%s)" % bar_rect)
	# A level shows the progress meter again.
	var level: RunWorld = sim.build_world(RunSim.layout(5, 400.0))
	hud.bind(level, ctx)
	await tree.process_frame
	check(not hud.boss_bar.visible and hud.progress.visible, "a level shows its progress meter")
	hud.queue_free()
	await sim.free_world(level)
	await sim.free_world(world)


# --- The app flow around a boss -----------------------------------------------------------------

## On the real main scene, with the test boss in the City's boss slot: a win (payout, records, stars,
## the leaderboard, on to the outro), a death (summary, shop, retry; granted items cost no stock), a
## revive, the checkpoint restart, and the web demo's end after the City's boss.
func _test_app_flow() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var saved: Profile = App.profile
	var step: CampaignStep = App.campaign.step("city/boss")
	var slot: BossDef = step.boss
	# A slot passed while still a placeholder earns no stars that would show once its boss is built.
	App.profile = Profile.new()
	SampleProfiles.complete_until(App.profile, App.campaign, "city/boss")
	App.complete_step(step)
	check(App.profile.is_completed("city/boss") and App.profile.stars("city/boss") == 0,
		"a boss slot passed as a placeholder counts as done, with no stars")
	step.boss = test_def
	App.show_level_select()
	await tree.process_frame
	var passed: TileButton = (App.screen as LevelSelectScreen).tiles.get("city/boss")
	var passed_labels: PackedStringArray = []
	for node: Node in passed.find_children("*", "Label", true, false):
		passed_labels.append((node as Label).text)
	check(passed_labels.has("DONE") and not passed_labels.has("NEW"), "and its built boss's tile says so, without a best")
	App.profile = Profile.new()
	await _app_win(step)
	App.profile = Profile.new()
	await _app_death_and_retry(step)
	App.profile = Profile.new()
	await _app_revive(step)
	App.profile = Profile.new()
	await _app_checkpoint(step)
	App.profile = Profile.new()
	await _app_demo(step)
	step.boss = slot
	# Quick play (--boss=test_boss) keeps the base speed; the campaign's fights run at their zone's (GDD §3).
	App.start_boss_quick(test_def)
	await physics_frames(3)
	check(App.run != null and App.run.context.mode == RunContext.Mode.QUICK
		and is_equal_approx(App.run.world.tuning.run_speed, App.tuning.run_speed),
		"quick play's fight keeps the base speed (%.1f m/s)" % (App.run.world.tuning.run_speed if App.run != null else 0.0))
	App.show_title()
	await tree.process_frame
	App.profile = saved
	main.queue_free()
	App.main = null
	await tree.process_frame


## Beats the fight App is running: every phase, as soon as it can be hurt.
func _beat(enc: BossEncounter) -> void:
	for i: int in 60 * 20:
		if enc == null or not is_instance_valid(enc) or enc.is_defeated():
			return
		if enc.is_vulnerable():
			enc.damage(enc.max_health, &"test")
		await tree.physics_frame


func _results_after_win() -> ResultsScreen:
	await physics_frames(int((LevelRun.COMPLETE_PAUSE + 0.5) * 60.0))
	await tree.process_frame
	return App.screen as ResultsScreen


func _kill_player() -> void:
	App.run.world.player._die("test hazard")
	await physics_frames(int((App.rules.death_screen_delay + 0.3) * 60.0))
	await tree.process_frame


func _app_win(step: CampaignStep) -> void:
	App.play_step(step)
	App.begin_run()
	await physics_frames(3)
	var run: LevelRun = App.run
	check(run != null and run.context.is_boss() and run.encounter is TestBoss and App.screen == null,
		"a built boss plays as a run in the world (GDD §10)")
	if run == null or run.encounter == null:
		return
	check(run.context.is_campaign() and run.world.geo.lane_count == App.lane_count(), "in the campaign flow, on the device's lanes")
	check(run.context.loadout.tier(&"armor") == 1 and run.context.loadout.is_granted(&"armor")
		and run.world.player.armor == App.rules.armor_hits_at(1),
		"with the items the boss grants (GDD §8; its armor: the upgrade's first tier over the free armor)")
	check(is_zero_approx(run.context.tuning.speed_gain_per_minute) and run.hud.boss_bar.visible, "no speed-up, and the boss bar shows")
	check(is_equal_approx(run.world.tuning.run_speed, step.zone.run_speed) and is_equal_approx(run.context.tuning.run_speed,
		step.zone.run_speed) and is_equal_approx(run.encounter.arena.tuning.run_speed, step.zone.run_speed),
		"at its zone's speed, like the zone's levels (GDD §3: %.1f m/s)" % run.world.tuning.run_speed)
	check(run.world.skin is CitySkin, "the arena wears the zone's look")
	await _beat(run.encounter)
	var results: ResultsScreen = await _results_after_win()
	check(results != null and results.result.completed, "beating the boss shows the results (%s)" % App.screen)
	if results == null:
		return
	var r: RunResult = results.result
	check(r.stars == 3 and r.time < test_def.three_star_seconds, "stars from the par times (%d in %.1f s)" % [r.stars, r.time])
	check(r.completion_bonus == test_def.payout_credits and r.credits_earned == test_def.payout_credits
		and App.profile.credits() == test_def.payout_credits, "the boss pays its credits into the wallet (%d)" % App.profile.credits())
	check(r.score >= test_def.defeat_score + test_def.time_bonus(r.time) and int(r.stats.get("time_bonus", -1)) == test_def.time_bonus(r.time),
		"the boss score includes the defeat and the time bonus (%d)" % r.score)
	var rec: Dictionary = App.profile.record("city/boss")
	check(bool(rec.get("completed", false)) and int(rec.get("best_score", 0)) == r.score and int(rec.get("stars", 0)) == 3
		and is_equal_approx(float(rec.get("best_time", 0.0)), r.time), "the boss's record: best score, best time, stars (%s)" % [rec])
	check(int((Platform.backend as StubBackend).scores.get("boss/test_boss/0", -1)) == r.score, "and its leaderboard gets the score")
	check(int(App.profile.stats.get("bosses_defeated", 0)) == 1, "the profile counts the boss")
	var labels: PackedStringArray = []
	for node: Node in results.find_children("*", "Label", true, false):
		labels.append((node as Label).text)
	check(labels.has("BOSS DEFEATED") and labels.has(ResultsScreen.par_text(test_def)), "the results say so, with the par times")
	App.continue_after_result(r)
	check(App.screen is ShopScreen and (App.screen as ShopScreen).play_label == "Next", "then the shop")
	(App.screen as ShopScreen).on_close.call()
	App.begin_run()
	await physics_frames(3)
	check(App.playing_cinematic() is CityOutro and App.playing_cinematic().step.id == "city/outro",
		"and on to the zone's outro (task F2a)")
	App.show_level_select()
	await tree.process_frame
	var tile: TileButton = (App.screen as LevelSelectScreen).tiles.get("city/boss")
	var stars: Array = tile.find_children("*", "StarRow", true, false) if tile != null else []
	check(not stars.is_empty() and (stars[0] as StarRow).stars == 3, "the level select shows the boss's stars like a level's")


func _app_death_and_retry(step: CampaignStep) -> void:
	App.profile.add_stock(&"shield", 2)
	App.play_step(step)
	App.begin_run()
	await physics_frames(3)
	var shot := Hazard.new()
	shot.is_enemy_attack = true
	App.run.world.player.receive_hit(shot)
	shot.free()
	check(App.profile.stock(&"shield") == 2 and App.run.world.player.armor == App.rules.armor_hits_at(1) - 1
		and App.run.world.player.shield == 1, "a hit on the granted armor costs no stock (the armor is none, GDD §8)")
	await _kill_player()
	check(App.screen is ResultsScreen and not (App.screen as ResultsScreen).result.completed,
		"with nothing to revive with, a death shows the run summary")
	if not App.screen is ResultsScreen:
		return
	var r: RunResult = (App.screen as ResultsScreen).result
	check(r.stars == 0 and r.credits_earned == 0 and not App.profile.is_completed("city/boss")
		and int(App.profile.record("city/boss").get("attempts", 0)) == 1, "the boss isn't beaten, and the attempt is recorded")
	App.continue_after_result(r)
	check(App.screen is ShopScreen and (App.screen as ShopScreen).play_label == "Retry", "then the shop, with a way to retry (GDD §4)")
	(App.screen as ShopScreen).on_close.call()
	App.begin_run()
	await physics_frames(3)
	check(App.run != null and App.run.context.is_boss() and App.run.context.attempt == 2 and App.run.encounter.phase_index == 0,
		"retry restarts the fight from the beginning (GDD §10)")
	check(App.run.context.loadout.is_granted(&"armor") and App.run.world.player.armor == App.rules.armor_hits_at(1),
		"with the granted items again")


func _app_revive(step: CampaignStep) -> void:
	App.profile.add_stock(&"revive", 1)
	App.play_step(step)
	App.begin_run()
	await physics_frames(3)
	var enc: BossEncounter = App.run.encounter
	await _kill_player()
	check(App.overlay is DeathScreen, "with a revive in stock, the revive offer shows")
	var labels: PackedStringArray = []
	for node: Node in App.overlay.find_children("*", "Label", true, false):
		labels.append((node as Label).text)
	check(labels.has("PHASE 1/3"), "showing the phase reached (%s)" % [labels])
	App.revive_with_item()
	await physics_frames(3)
	check(App.run.world.player.alive and App.run.encounter == enc and App.profile.stock(&"revive") == 0,
		"reviving continues the same fight")


func _app_checkpoint(step: CampaignStep) -> void:
	App.play_step(step)
	App.begin_run()
	await physics_frames(3)
	var enc: BossEncounter = App.run.encounter
	for i: int in 60 * 5:
		if enc.is_vulnerable():
			break
		await tree.physics_frame
	enc.damage(enc.hit_damage(), &"test")
	await tree.process_frame
	check(enc.phase_index == 1 and int(App.run.context.boss_resume.get("phase", -1)) == 1, "the fight reaches its checkpoint phase")
	await physics_frames(2)
	check(App.run.hud.hint_text().contains("Checkpoint"), "the HUD says so")
	await _kill_player()
	var r: RunResult = (App.screen as ResultsScreen).result if App.screen is ResultsScreen else null
	check(r != null and r.stats.get("phase", 0) == 2, "the summary shows the phase reached")
	if r == null:
		return
	App.continue_after_result(r)
	(App.screen as ShopScreen).on_close.call()
	App.begin_run()
	await physics_frames(3)
	enc = App.run.encounter
	check(enc.phase_index == 1 and is_equal_approx(enc.health, enc.phase_start_health(1)) and enc.carried_time > 0.0,
		"a retry after the checkpoint starts at that phase, with the time so far (GDD §10)")
	App.pause_game()
	await tree.process_frame
	await tree.process_frame
	var pause := App.overlay as PauseScreen
	check(pause != null and (pause.buttons["restart"] as NeonButton).text.contains("FIGHT"), "the pause menu restarts the fight")
	(pause.buttons["restart"] as BaseButton).pressed.emit()
	App.begin_run()
	await physics_frames(3)
	check(App.run.encounter.phase_index == 1, "from the checkpoint too")
	# FB 14 (decided September 26, 2026): a boss fight quit keeps the same credit share as a death.
	App.run.world.score.credits = 40
	var wallet_before: int = App.profile.credits()
	App.quit_run()
	await tree.process_frame
	check(App.profile.credits() == wallet_before + floori(40 * App.rules.death_credit_keep_fraction),
		"quitting a boss fight pays the wallet too")
	App.play_step(step)
	App.begin_run()
	await physics_frames(3)
	check(App.run.encounter.phase_index == 0 and App.run.context.boss_resume.is_empty(),
		"starting the fight again from the map starts it afresh (its checkpoint isn't kept on a quit either)")


## GDD §2: the web demo is Zone 1 including its boss, then the store-link screen; no leaderboards.
func _app_demo(step: CampaignStep) -> void:
	BuildFlavor.set_override(BuildFlavor.Kind.WEB_DEMO)
	Platform.configure_for(BuildFlavor.Kind.WEB_DEMO)
	check(App.in_demo_scope(step), "the City's boss is in the demo")
	App.play_step(step)
	App.begin_run()
	await physics_frames(3)
	await _beat(App.run.encounter)
	var results: ResultsScreen = await _results_after_win()
	check(results != null and results.result.completed, "the demo's boss can be beaten")
	check((Platform.backend as StubBackend).scores.is_empty(), "and nothing goes to a leaderboard in the demo")
	if results != null:
		App.continue_after_result(results.result)
		(App.screen as ShopScreen).on_close.call()
		await physics_frames(3)
		check(App.playing_cinematic() is CityOutro and App.playing_cinematic().step.id == "city/outro",
			"the City's outro follows")
		App.skip_cinematic()
		await tree.process_frame
		check(App.screen is DemoEndScreen, "then the demo ends with the store links")
	BuildFlavor.set_override(-1)
	Platform.configure_for(BuildFlavor.current())

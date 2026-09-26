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
	await _test_checkpoint_resume()
	await _test_damage_rules()
	await _test_stomp_on_real_physics()
	await _test_no_escalation()
	await _test_telegraphed_attack()
	await _test_armor_rule()


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
	loadout.charges = {&"armor": 1, &"shield": 1}
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

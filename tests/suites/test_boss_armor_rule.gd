extends TestSuite
## GDD §10's standard armor rule on every boss that uses it, at 3, 5 and 6 lanes (task I9; owner, October
## 14, 2026: only the armor taking a hit brings the armor pickup, never a shield break). In a fight begun
## with the free armor and two shields: a shield break with the armor still on (a solid hit, which the armor
## doesn't block) and one with the armor down schedule no armor pickup, and nothing of the boss's own offers
## one; a hit the armor survives (the upgrade's hits) then schedules the phase's one, the boss's delay
## later, so the shield breaks didn't use it up; and the armor's last hit in that phase brings no second.
## The bosses come from the campaign's slots and the test boss: every one with the armor rule and a built
## scene, so a boss built later is checked too. The framework's own cases (the final phase, the next phase,
## a boss without the rule) are test_bosses'; each boss's suite plays its pickups out in a real fight.

const TEST_BOSS_PATH: String = "res://data/bosses/test_boss.tres"
const CAMPAIGN_PATH: String = "res://data/campaign/campaign.tres"
const LANES: Array[int] = [3, 5, 6]
## The bosses built when the rule changed (October 14, 2026); each must still be found and checked.
const BUILT: Array[StringName] = [&"city_boss", &"gangland_boss", &"casino_boss", &"corporate_boss",
	&"dead_zone_boss", &"golden_boss", &"test_boss"]

var sim: RunSim


func run() -> void:
	sim = RunSim.new(tree, tuning)
	var defs: Array[BossDef] = _armor_rule_bosses()
	var ids: Array[StringName] = []
	for def: BossDef in defs:
		ids.append(def.id)
	for id: StringName in BUILT:
		check(ids.has(id), "%s uses the standard armor rule and is checked (%s)" % [id, ids])
	for def: BossDef in defs:
		for lanes: int in LANES:
			await _check_boss(def, lanes)


## Every built boss with the armor rule: the campaign's slots and the test boss, each once.
func _armor_rule_bosses() -> Array[BossDef]:
	var all: Array[BossDef] = []
	var campaign := load(CAMPAIGN_PATH) as Campaign
	if campaign != null:
		for zone: ZoneDef in campaign.zones:
			if zone.boss != null:
				all.append(zone.boss)
	var test_def := load(TEST_BOSS_PATH) as BossDef
	if test_def != null:
		all.append(test_def)
	var out: Array[BossDef] = []
	var seen: Dictionary = {}
	for def: BossDef in all:
		if def.armor_rule and def.is_built() and not seen.has(def.id):
			seen[def.id] = true
			out.append(def)
	return out


## A fight in a bare RunWorld, as the boss suites start one: the boss's arena at `lanes`, a world on it with
## `loadout`, the encounter set up in it (its first phase begun). [world, boss], or [] if the scene isn't one.
func _fight(def: BossDef, lanes: int, loadout: Loadout) -> Array:
	var boss: BossEncounter = BossEncounter.create(def)
	if boss == null:
		return []
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = def
	ctx.config = BossArena.base_config(def)
	ctx.config.lane_count = lanes
	ctx.tuning = tuning
	ctx.loadout = loadout
	var arena: BossArena = boss.plan_arena(ctx)
	var world: RunWorld = sim.build_world(arena.layout, loadout, tuning, ctx.config)
	boss.setup(world, ctx, arena)
	return [world, boss]


## Runs the fight `frames` physics frames (starting the run if it hasn't started).
func _frames(world: RunWorld, frames: int) -> void:
	if not world.player.running:
		await tree.physics_frame
		world.player.running = true
	for i: int in frames:
		await tree.physics_frame


func _events(boss: BossEncounter, event: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in boss.events:
		if e["event"] == event:
			out.append(e)
	return out


## Armor pickups offered, waiting for a spot or on the track.
func _armor_offers(world: RunWorld, boss: BossEncounter) -> int:
	var count: int = 0
	for e: Dictionary in _events(boss, &"pickup_offered"):
		count += 1 if e.get("item", &"") == &"armor" else 0
	for offer: Dictionary in world.pickups.pending:
		count += 1 if offer["item"] == &"armor" else 0
	for pickup: Pickup in world.pickups.active:
		count += 1 if is_instance_valid(pickup) and pickup.item == &"armor" else 0
	return count


## One contact through the player's own rules (DamageRules), with god mode lifted for it and the moment of
## invulnerability after the last one over.
func _hit(p: Player, hazard: Hazard) -> DamageRules.Outcome:
	p.invulnerable_left = 0.0
	p.god_mode = false
	var outcome: DamageRules.Outcome = p.receive_hit(hazard)
	p.god_mode = true
	return outcome


func _check_boss(def: BossDef, lanes: int) -> void:
	var tag: String = "(%s, %d lanes)" % [def.id, lanes]
	var loadout := Loadout.new()
	loadout.armor = true
	loadout.charges = {&"shield": 2}
	var pair: Array = _fight(def, lanes, loadout)
	check(not pair.is_empty(), "%s's scene makes a boss fight %s" % [def.id, tag])
	if pair.is_empty():
		return
	var world: RunWorld = pair[0]
	var boss: BossEncounter = pair[1]
	var p: Player = world.player
	# The runner can't be hurt but by the hits below (the fight goes on around them).
	p.god_mode = true
	await _frames(world, 2)
	check(p.armor == 1 and p.shield == 2 and _events(boss, &"armor_scheduled").is_empty() and boss.phase_index == 0,
		"the fight begins with the armor on and nothing due %s" % tag)
	var wall := Hazard.new()
	wall.hazard_name = "test wall"
	wall.is_solid = true
	var shot := Hazard.new()
	shot.hazard_name = "test shot"
	shot.is_enemy_attack = true

	# (1) Shield breaks: with the armor still on (a solid hit), then with it down (an attack).
	var with_armor: DamageRules.Outcome = _hit(p, wall)
	var armor_on: bool = p.armor == 1
	p.armor = 0
	var without: DamageRules.Outcome = _hit(p, shot)
	var broken: Array[Dictionary] = _events(boss, &"protection_broken")
	check(with_armor == DamageRules.Outcome.BLOCKED_SHIELD and armor_on and without == DamageRules.Outcome.BLOCKED_SHIELD
		and p.shield == 0 and broken.size() == 2 and broken[0]["item"] == &"shield" and broken[1]["item"] == &"shield",
		"the fight hears two shield breaks, the first with the armor still on %s" % tag)
	await _frames(world, 15)
	check(_events(boss, &"armor_scheduled").is_empty() and _events(boss, &"armor_pickup").is_empty()
		and _armor_offers(world, boss) == 0 and boss.phase_index == 0,
		"a shield break schedules no armor pickup, with the armor on or down %s" % tag)

	# (2) The armor takes a hit it survives: the phase's pickup, the boss's delay later.
	p.armor = 2
	var t0: float = boss.fight_time()
	var hit: DamageRules.Outcome = _hit(p, shot)
	var scheduled: Array[Dictionary] = _events(boss, &"armor_scheduled")
	var delay: float = float(scheduled[0]["at"]) - t0 if scheduled.size() == 1 else -1.0
	check(hit == DamageRules.Outcome.BLOCKED_ARMOR and p.armor == 1 and scheduled.size() == 1
		and scheduled[0]["reason"] == &"armor_hit" and int(scheduled[0]["phase"]) == 0,
		"an armor hit schedules an armor pickup %s" % tag)
	check(delay >= def.armor_delay_min - 0.001 and delay <= maxf(def.armor_delay_max, def.armor_delay_min) + 0.001,
		"due the boss's %.0f–%.0f s later (%.2f s) %s" % [def.armor_delay_min, def.armor_delay_max, delay, tag])
	# Its last hit, in the same phase: no second.
	var last: DamageRules.Outcome = _hit(p, shot)
	await _frames(world, 2)
	check(last == DamageRules.Outcome.BLOCKED_ARMOR and p.armor == 0 and _events(boss, &"armor_scheduled").size() == 1,
		"the armor's last hit in the same phase brings no second %s" % tag)
	wall.free()
	shot.free()
	await sim.free_world(world)

extends TestSuite
## Fence generators (GDD §9.1). (Named test_fence_generator: test_generator is the level
## generator's suite.) Weapons, a stomp or the dash destroy one; claws and plain contact don't.
## Destroying it sets off an EMP that switches off its fences for the rest of the level, so a player
## then runs through them safely, while fences out of reach stay on. It scores as an obstacle, not a
## kill. Its patterns place it with a fence group it powers, and most fences have none.

const GEN_TUNING_PATH: String = "res://data/enemies/generator.tres"
const GEN_AT: float = 40.0
const FENCE_AT: float = 49.0
const FAR_FENCE_AT: float = 200.0
## Jump this far (track distance) before a generator to land on it.
const STOMP_LEAD: float = 10.0

var sim: RunSim
var gt: FenceGeneratorTuning


func run() -> void:
	sim = RunSim.new(tree, tuning)
	gt = load(GEN_TUNING_PATH) as FenceGeneratorTuning
	check(gt != null, "the generator tuning loads")
	if gt == null:
		return
	_test_hitboxes()
	await _test_weapons()
	await _test_stomp()
	await _test_dash_claws_contact()
	_test_generation()


## Full fences across all 3 lanes just past the generator, and another group far ahead.
func _layout() -> LevelLayout:
	var l: LevelLayout = RunSim.layout(3, 400.0)
	for lane: int in 3:
		l.fences.append(RunSim.fence(lane, FENCE_AT, "full"))
		l.fences.append(RunSim.fence(lane, FAR_FENCE_AT, "full"))
	return l


func _spawn(w: RunWorld, lane: int) -> FenceGenerator:
	return w.director.spawn({"type": "generator", "at": GEN_AT, "lane": lane, "side": 0, "seed": 3,
		"params": {}}) as FenceGenerator


func _loadout(items: Dictionary) -> Loadout:
	var l := Loadout.new()
	for k: String in items:
		if k in ["armor", "shield", "grapple"]:
			l.charges[StringName(k)] = items[k]
		else:
			l.tiers[StringName(k)] = items[k]
	return l


func _step_until(w: RunWorld, done: Callable, seconds: float) -> bool:
	if not w.player.running:
		await tree.physics_frame
		w.player.running = true
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		await tree.physics_frame
		if done.call():
			return true
	return false


static func _disabled_at(layout: LevelLayout, at: float) -> int:
	var n: int = 0
	for f: Dictionary in layout.fences:
		if is_equal_approx(float(f["at"]), at) and f.get("disabled", false):
			n += 1
	return n


func _test_hitboxes() -> void:
	var rules := load("res://data/tuning/game_rules.tres") as GameRules
	var top: float = FenceGenerator.TOP_Y + FenceGenerator.TOP_SIZE.y * 0.5
	check(FenceGenerator.BODY_SIZE.y <= top - rules.stomp_tolerance + 0.001,
		"its body ends at the stomp line, so dropping onto it only touches its top")


## GDD §9.1 (decided September 26, 2026): weapons never set off a generator, by any path. Only a
## stomp or the dash does (see _test_stomp, _test_dash_claws_contact).
func _test_weapons() -> void:
	var pt: PowerupTuning = load("res://data/tuning/powerups.tres") as PowerupTuning
	var looks: Array[StringName] = [&"laser", &"laser_2", &"missile", &"heavy_missile"]
	var w: RunWorld = sim.build_world(_layout())
	var g: FenceGenerator = _spawn(w, 0)
	check(g.powered.size() == 3, "it powers the fence group just ahead (%d fences)" % g.powered.size())
	check(g.is_obstacle and g.claw_immune and g.stompable and g.dash_kills and g.immune_to_weapons,
		"declared: an obstacle, stompable, dash-breakable, not by claws, immune to weapons")
	await sim.free_world(w)

	# Every weapon tier: not targeted (even as the only enemy in range), and no damage from a direct
	# hit (a stray shot aimed elsewhere, or a homing missile actually locked onto it).
	for tier: int in [1, 2, 3, 4]:
		w = sim.build_world(_layout())
		g = _spawn(w, 0)
		check(not g.targetable(), "tier %d: it isn't targetable" % tier)
		check(w.director.targets_ahead(g.aim_point(), 200.0).is_empty(),
			"tier %d: auto-fire finds nothing, even with the generator its only enemy in range" % tier)
		var dmg: float = PowerupTuning.at_tier(pt.weapon_damage, tier)
		var heavy: bool = tier >= 4
		var splash_r: float = pt.splash_radius if heavy else 0.0
		var splash_s: float = pt.splash_damage_share if heavy else 0.0
		for i: int in 20:
			w.projectiles.fire_player(g.aim_point() + Vector3(0.0, 0.0, 6.0), Vector3(0.0, 0.0, -90.0),
				dmg, looks[tier - 1], null, 0.0, splash_r, splash_s)
			await physics_frames(6)
		check(g.alive and is_equal_approx(g.health, g.max_health),
			"tier %d: 20 stray direct hits leave it undamaged" % tier)
		if tier >= 3:
			# A homing missile explicitly locked onto it (auto-fire would never pick it, but the
			# damage path itself must refuse it too).
			w.projectiles.fire_player(g.aim_point() + Vector3(1.0, 0.5, 10.0), Vector3(0.0, 0.0, -60.0),
				dmg, looks[tier - 1], g, pt.missile_turn_rate, splash_r, splash_s)
			await physics_frames(120)
			check(g.alive and is_equal_approx(g.health, g.max_health),
				"tier %d: a homing missile locked onto it never lands a hit" % tier)
		await sim.free_world(w)

	# The heavy missile's splash, exploding right next to it from a direct hit on a neighbour.
	w = sim.build_world(_layout())
	g = _spawn(w, 0)
	var near: Enemy = w.director.spawn({"type": "dummy", "script": "res://tests/helpers/dummy_enemy.gd",
		"at": GEN_AT, "lane": 1, "seed": 2, "params": {"health": 30.0}})
	var dmg4: float = PowerupTuning.at_tier(pt.weapon_damage, 4)
	w.projectiles.fire_player(near.aim_point() + Vector3(0.0, 0.0, 6.0), Vector3(0.0, 0.0, -90.0),
		dmg4, &"heavy_missile", null, 0.0, pt.splash_radius, pt.splash_damage_share)
	await physics_frames(10)
	check(near.health < 30.0, "sanity: the heavy missile hit its direct target")
	check(g.alive and is_equal_approx(g.health, g.max_health),
		"its splash, exploding right next to the generator, doesn't damage it")
	await sim.free_world(w)

	# Equipped for real, with the generator its only enemy in range: auto-fire never fires at all,
	# and it never shows a health bar (it's never damaged to trigger one, but check the declared
	# property directly too, the same rule health bars use for hosts).
	w = sim.build_world(_layout(), _loadout({"weapon": 4}))
	g = _spawn(w, 0)
	var health_bars: EnemyHealthBars = (w.powerups as PowerupController).weapon.health_bars
	var shots: Array[int] = [0]
	(w.powerups as PowerupController).fired.connect(func(_t: int) -> void: shots[0] += 1)
	var r: Dictionary = await sim.step_world(w, 2.0)
	check(r["alive"] and shots[0] == 0 and g.alive,
		"equipped and running, auto-fire never fires with only a generator ahead (%s)" % r["cause"])
	check(not EnemyHealthBars.wants_bar(g) and not health_bars.is_shown(g), "and it never shows a health bar")
	await sim.free_world(w)

	# The same fences kill without the EMP (the control case).
	w = sim.build_world(_layout())
	_spawn(w, 0)
	r = await sim.step_world(w, 3.0)
	check(not r["alive"] and String(r["cause"]).begins_with("fence"), "its fences are live until it goes (%s)" % r["cause"])
	await sim.free_world(w)


func _test_stomp() -> void:
	var w: RunWorld = sim.build_world(_layout())
	var g: FenceGenerator = _spawn(w, 1)
	await _step_until(w, func() -> bool: return GEN_AT - w.player.distance <= STOMP_LEAD, 4.0)
	w.player.press(&"jump")
	var r: Dictionary = await sim.step_world(w, 2.0)
	check(r["alive"] and r["events"].has(&"stomp") and not g.alive, "a stomp destroys it (%s)" % r["cause"])
	check(_disabled_at(w.layout, FENCE_AT) == 3 and float(r["distance"]) > FENCE_AT + 5.0,
		"and the player carries on through its dead fences")
	check(w.score.stomps == 1 and w.score.kills == 0, "the stomp counts, the obstacle isn't a kill")
	await sim.free_world(w)


func _test_dash_claws_contact() -> void:
	# The dash smashes it.
	var w: RunWorld = sim.build_world(_layout())
	var g: FenceGenerator = _spawn(w, 1)
	await _step_until(w, func() -> bool: return GEN_AT - w.player.distance <= 5.0, 4.0)
	w.player.start_dash(0.6, 0.0)
	var r: Dictionary = await sim.step_world(w, 1.5)
	check(r["alive"] and not g.alive and _disabled_at(w.layout, FENCE_AT) == 3, "the dash destroys it (%s)" % r["cause"])
	await sim.free_world(w)

	# DESIGN-TBD: claws don't. Running into it with claws still hurts, and it keeps running.
	w = sim.build_world(_layout(), _loadout({"claws": 1}))
	g = _spawn(w, 1)
	r = await sim.step_world(w, 3.0)
	check(not r["alive"] and r["cause"] == "generator" and g.alive, "claws don't destroy it (%s)" % r["cause"])
	await sim.free_world(w)

	# Plain contact: a solid collision that armor doesn't stop.
	w = sim.build_world(_layout(), _loadout({"armor": 1}))
	g = _spawn(w, 1)
	r = await sim.step_world(w, 3.0)
	check(not r["alive"] and r["cause"] == "generator" and w.player.armor == 1 and g.alive,
		"running into it kills, armor or not (%s)" % r["cause"])
	await sim.free_world(w)


func _test_generation() -> void:
	var base: LevelConfig = load(LEVEL_PATH) as LevelConfig
	var generators: int = 0
	var rows: int = 0
	var powered_rows: int = 0
	for lanes: int in [3, 5, 6]:
		for difficulty: float in [0.3, 0.6, 0.9]:
			for level_seed: int in range(1, 13):
				var config: LevelConfig = base.duplicate() as LevelConfig
				config.lane_count = lanes
				config.difficulty = difficulty
				config.level_seed = level_seed
				config.features = PackedStringArray(["ramps", "ceilings", "pulsing", "generator"])
				var patterns: Array = LevelGenerator.load_for(config)
				var gen := LevelGenerator.new()
				var a: LevelLayout = gen.generate(config, tuning, patterns)
				var tag: String = "lanes=%d diff=%.1f seed=%d" % [lanes, difficulty, level_seed]
				check(gen.warnings.is_empty(), "generator patterns generate without warnings " + tag)
				var b: LevelLayout = LevelGenerator.new().generate(config, tuning, patterns)
				check(JSON.stringify(a.enemies) == JSON.stringify(b.enemies), "same seed, same generators " + tag)
				var geo := TrackGeometry.new(lanes, tuning)
				var fed: Dictionary = {}
				for e: Dictionary in a.enemies:
					if String(e["type"]) != "generator":
						continue
					generators += 1
					var at: float = e["at"]
					var lane: int = e["lane"]
					var powered: Array[Dictionary] = FenceGenerator.fences_in_reach(a, geo, at, lane, gt.emp_radius)
					check(not powered.is_empty(), "every generator powers a fence group " + tag)
					for f: Dictionary in a.fences:
						if float(f["at"]) > at + 0.5 and float(f["at"]) < at + 12.0:
							check(powered.has(f), "its EMP reaches every fence of its group (lane %d) %s" % [int(f["lane"]), tag])
					for f: Dictionary in powered:
						fed[snappedf(float(f["at"]), 0.01)] = true
					check(not a.under_hull(at) and not a.gapped_between(lane, at - 1.5, at + 1.5),
						"a generator stands on clear floor " + tag)
					check(lane >= 0 and lane < lanes, "generator lane in range " + tag)
				var row_ats: Dictionary = {}
				for f: Dictionary in a.fences:
					row_ats[snappedf(float(f["at"]), 0.01)] = true
				rows += row_ats.size()
				powered_rows += fed.size()
	check(generators > 40, "generators appear (%d)" % generators)
	var share: float = float(powered_rows) / maxf(float(rows), 1.0)
	check(share > 0.02 and share < 0.3, "most fences have no generator (%.2f of %d fence rows powered)" % [share, rows])

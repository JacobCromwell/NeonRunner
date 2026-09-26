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


func _test_weapons() -> void:
	var w: RunWorld = sim.build_world(_layout())
	var g: FenceGenerator = _spawn(w, 0)
	check(g.powered.size() == 3, "it powers the fence group just ahead (%d fences)" % g.powered.size())
	check(g.is_obstacle and g.claw_immune and g.stompable and g.dash_kills, "declared: an obstacle, stompable, dash-breakable, not by claws")
	check(w.director.targets_ahead(Vector3(0.0, 0.8, 0.0), 80.0).has(g), "auto-fire can target it (weapons destroy it)")
	var needed: int = ceili(gt.health_at(0.0) - 0.001)
	for i: int in needed:
		w.projectiles.fire_player(g.aim_point() + Vector3(0.0, 0.0, 6.0), Vector3(0.0, 0.0, -90.0), 1.0)
		await physics_frames(10)
		if i < needed - 1:
			check(g.alive, "still running after %d of %d shots" % [i + 1, needed])
	check(not g.alive, "weapons destroy it (%d laser shots)" % needed)
	check(_disabled_at(w.layout, FENCE_AT) == 3, "its EMP switches its fences off")
	check(_disabled_at(w.layout, FAR_FENCE_AT) == 0, "fences out of the EMP's reach stay on")
	check(w.score.kills == 0 and w.score.score >= gt.score_value, "it scores as an obstacle, not a kill (%d)" % w.score.score)
	var r: Dictionary = await sim.step_world(w, 4.0)
	check(r["alive"] and float(r["distance"]) > FENCE_AT + 5.0, "a player then runs through its fences safely (%s)" % r["cause"])
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

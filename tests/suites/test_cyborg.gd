extends TestSuite
## The cyborg (GDD §9.2): telegraphed bursts that hit a player who stays in their path and miss one
## who switches lanes after the charge-up; stomp, weapon, claw and dash kills; the panic variant;
## hosts (GDD §9.7); movement that keeps clear of obstacles; the cyborg patterns and rules over many
## seeds and lane counts; and full levels played in god mode checking every burst's fairness.

const Kit = preload("res://scripts/enemies/cyborg_kit.gd")
const CyborgRules = preload("res://scripts/enemies/cyborg_rules.gd")
const CYBORG_TUNING_PATH: String = "res://data/enemies/cyborg.tres"
## Jump this far (track distance) before a walking cyborg to land on its head.
const STOMP_LEAD: float = 9.5

var sim: RunSim
var ct: CyborgTuning


func run() -> void:
	sim = RunSim.new(tree, tuning)
	ct = load(CYBORG_TUNING_PATH) as CyborgTuning
	check(ct != null, "the cyborg tuning loads")
	if ct == null:
		return
	_test_hitbox_rules()
	await _test_burst()
	await _test_contact()
	await _test_weapons()
	await _test_panic()
	await _test_hosts()
	await _test_keeps_clear()
	_test_generation()
	await _test_fair_play()


func _spawn(w: RunWorld, at: float, lane: int, params: Dictionary, seed_value: int = 7) -> Cyborg:
	return w.director.spawn({"type": "cyborg", "at": at, "lane": lane, "side": 0, "seed": seed_value,
		"params": params}) as Cyborg


func _loadout(items: Dictionary) -> Loadout:
	var l := Loadout.new()
	for k: String in items:
		if k in ["armor", "shield", "grapple"]:
			l.charges[StringName(k)] = items[k]
		else:
			l.tiers[StringName(k)] = items[k]
	return l


## Steps the world a frame at a time until `done` returns true or `seconds` pass.
func _step_until(w: RunWorld, done: Callable, seconds: float) -> bool:
	if not w.player.running:
		await tree.physics_frame
		w.player.running = true
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		await tree.physics_frame
		if done.call():
			return true
	return false


static func _events_of(gun: CyborgGun, kind: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in gun.events:
		if e["event"] == kind:
			out.append(e)
	return out


## No live fence and no gap in any lane between two track distances.
static func _clear(layout: LevelLayout, from_d: float, to_d: float) -> bool:
	for f: Dictionary in layout.fences:
		if float(f["at"]) >= from_d and float(f["at"]) <= to_d and not f.get("disabled", false):
			return false
	for g: Dictionary in layout.gaps:
		if float(g["start"]) <= to_d and float(g["end"]) >= from_d:
			return false
	return true


## The body ends below the stomp line, and a running player can't reach the stomp zone.
func _test_hitbox_rules() -> void:
	var rules := load("res://data/tuning/game_rules.tres") as GameRules
	var head_top: float = Cyborg.HEAD_Y + Cyborg.HEAD_SIZE.y * 0.5
	check(Cyborg.BODY_SIZE.y <= head_top - rules.stomp_tolerance + 0.001,
		"the body ends below the stomp line, so dropping onto the head only touches the head")
	check(Cyborg.HEAD_Y - Cyborg.HEAD_SIZE.y * 0.5 > tuning.hurtbox_size.y,
		"a running player can't touch the stomp zone (only a jumping one)")


func _test_burst() -> void:
	# A player who stays in the burst's path is hit.
	var w: RunWorld = sim.build_world(RunSim.layout(3, 600.0))
	var c: Cyborg = _spawn(w, 110.0, 2, {"panic": false})
	var gun: CyborgGun = c.gun
	var r: Dictionary = await sim.step_world(w, 8.0)
	check(not r["alive"] and r["cause"] == CyborgGun.SHOT_NAME, "a burst hits a player who stays in its path (%s)" % r["cause"])
	var charges: Array[Dictionary] = _events_of(gun, &"charge")
	var shots: Array[Dictionary] = _events_of(gun, &"shot")
	check(not charges.is_empty() and shots.size() >= 1, "it charged up and fired (%d shots)" % shots.size())
	if not charges.is_empty() and not shots.is_empty():
		check(int(charges[0]["shots"]) >= 2 and int(charges[0]["shots"]) <= 3, "a burst is 2–3 bolts (%d)" % int(charges[0]["shots"]))
		check(float(shots[0]["t"]) - float(charges[0]["t"]) >= ct.charge_time - 0.02,
			"the visible charge-up comes before the first bolt (%.2f s)" % (float(shots[0]["t"]) - float(charges[0]["t"])))
		check(float(shots[0]["arrive"]) - float(shots[0]["t"]) >= ct.min_warning_time,
			"the first bolt takes at least the minimum warning time to arrive")
	await sim.free_world(w)

	# A player who switches lanes once the charge-up is over dodges the whole burst.
	w = sim.build_world(RunSim.layout(3, 600.0))
	c = _spawn(w, 110.0, 2, {"panic": false})
	gun = c.gun
	var fired: bool = await _step_until(w, func() -> bool: return not _events_of(gun, &"shot").is_empty(), 8.0)
	check(fired, "the cyborg fires at an approaching player")
	w.player.press(&"move_left")
	await _step_until(w, func() -> bool: return gun.state != CyborgGun.State.FIRING, 2.0)
	var burst: Array[Dictionary] = _events_of(gun, &"shot")
	var last_arrival: float = 0.0
	for s: Dictionary in burst:
		last_arrival = maxf(last_arrival, float(s["arrive"]))
	await _step_until(w, func() -> bool: return w.level_time() > last_arrival + 0.3, 5.0)
	check(burst.size() >= 2, "the whole burst was fired (%d bolts)" % burst.size())
	check(w.player.alive and w.player.lane == 0, "switching lanes after the charge-up dodges the whole burst")
	await sim.free_world(w)


func _test_contact() -> void:
	var flat: LevelLayout = RunSim.layout(3, 400.0)
	# Stomp: drop onto its head.
	var w: RunWorld = sim.build_world(flat)
	var c: Cyborg = _spawn(w, 45.0, 1, {"panic": false, "fires": false})
	await _step_until(w, func() -> bool: return c.track_distance() - w.player.distance <= STOMP_LEAD, 4.0)
	w.player.press(&"jump")
	var r: Dictionary = await sim.step_world(w, 1.5)
	check(r["alive"] and r["events"].has(&"stomp"), "a stomp on the head kills it (%s)" % r["cause"])
	check(w.score.stomps == 1 and w.score.kills == 1, "the stomp is counted as a kill")
	check(w.score.score >= ct.score_value + App.rules.stomp_bonus, "and scores the kill plus the stomp bonus (%d)" % w.score.score)
	await sim.free_world(w)

	# Running into its body kills, and armor doesn't stop that (a solid collision).
	w = sim.build_world(flat, _loadout({"armor": 1}))
	_spawn(w, 45.0, 1, {"panic": false, "fires": false})
	r = await sim.step_world(w, 3.0)
	check(not r["alive"] and r["cause"] == "cyborg" and w.player.armor == 1,
		"running into its body kills, armor or not (%s)" % r["cause"])
	await sim.free_world(w)

	# Claws and the dash defeat it on contact.
	w = sim.build_world(flat, _loadout({"claws": 1}))
	_spawn(w, 45.0, 1, {"panic": false, "fires": false})
	r = await sim.step_world(w, 3.0)
	check(r["alive"] and w.score.kills == 1, "claws kill it on contact (%s)" % r["cause"])
	await sim.free_world(w)
	w = sim.build_world(flat)
	c = _spawn(w, 45.0, 1, {"panic": false, "fires": false})
	await _step_until(w, func() -> bool: return c.track_distance() - w.player.distance <= 6.0, 4.0)
	w.player.start_dash(0.8, 0.0)
	r = await sim.step_world(w, 1.5)
	check(r["alive"] and w.score.kills == 1, "the dash kills it (%s)" % r["cause"])
	await sim.free_world(w)


func _test_weapons() -> void:
	for scaling: float in [0.0, 1.0]:
		var config := LevelConfig.new()
		config.enemy_scaling = scaling
		var w: RunWorld = sim.build_world(RunSim.layout(3, 400.0), null, null, config)
		var c: Cyborg = _spawn(w, 50.0, 0, {"panic": false, "fires": false})
		var needed: int = ceili(ct.health_at(scaling) - 0.001)
		check(is_equal_approx(c.max_health, ct.health_at(scaling)), "health scales across the campaign (%.1f)" % c.max_health)
		for i: int in needed:
			w.projectiles.fire_player(c.aim_point() + Vector3(0.0, 0.0, 6.0), Vector3(0.0, 0.0, -90.0), 1.0)
			await physics_frames(10)
			if i < needed - 1:
				check(c.alive, "still up after %d of %d laser shots" % [i + 1, needed])
		check(not c.alive and w.score.kills == 1, "%d laser tier 1 shots kill it at scaling %.0f" % [needed, scaling])
		await sim.free_world(w)


func _test_panic() -> void:
	var w: RunWorld = sim.build_world(RunSim.layout(3, 600.0))
	w.player.god_mode = true
	var c: Cyborg = _spawn(w, 120.0, 0, {"panic": true})
	var start: float = c.track_distance()
	await _step_until(w, func() -> bool: return c.mode == Cyborg.Mode.STARTLED, 6.0)
	check(c.mode == Cyborg.Mode.STARTLED and c.track_distance() - w.player.distance <= ct.panic_trigger_distance + 0.5,
		"the panic variant notices the player at its trigger distance")
	await _step_until(w, func() -> bool: return c.mode == Cyborg.Mode.FLEE, 2.0)
	await physics_frames(3)
	check(c.mode == Cyborg.Mode.FLEE and c.body.face == Kit.Face.SHOCKED and c.body.pose == CyborgBody.Pose.RUN_AWAY,
		"then runs away with a shocked \"O\" face")
	await sim.step_world(w, 2.5)
	check(c.track_distance() > start + 15.0, "and gets well ahead of where it stood (%.1f m)" % (c.track_distance() - start))
	var shots: Array[Dictionary] = _events_of(c.gun, &"shot")
	check(c.gun.wild and not shots.is_empty(), "firing wildly over its shoulder (%d bolts)" % shots.size())
	for s: Dictionary in shots:
		check(float(s["shooter_d"]) > float(s["player_d"]), "a fleeing cyborg only fires from ahead")
	await sim.free_world(w)

	# Without a panic param (e.g. spawned by hand) the cyborg rolls it from its own seed.
	var panicked: int = 0
	w = sim.build_world(RunSim.layout(3, 400.0))
	for i: int in 90:
		var e: Cyborg = _spawn(w, 300.0 + i, i % 3, {"fires": false}, 1000 + i)
		if e.is_panic:
			panicked += 1
	check(panicked >= 18 and panicked <= 42, "about 1 in 3 hand-spawned cyborgs panic too (%d of 90)" % panicked)
	await sim.free_world(w)


func _test_hosts() -> void:
	var w: RunWorld = sim.build_world(RunSim.layout(3, 400.0))
	var normal: Cyborg = _spawn(w, 40.0, 1, {"panic": false, "fires": false}, 1)
	var host: Cyborg = _spawn(w, 41.0, 2, {"host": true, "fires": false}, 2)
	check(host.is_host and not host.is_panic and host.body.host, "a host is marked (its visor glitches) and doesn't panic")
	var ahead: Array[Enemy] = w.director.targets_ahead(Vector3(0.0, 0.8, 0.0), 80.0)
	check(ahead.has(normal) and not ahead.has(host), "auto-fire never targets a host")
	var before: float = host.health
	w.projectiles.fire_player(normal.aim_point() + Vector3(0.0, 0.0, 6.0), Vector3(0.0, 0.0, -80.0), 1.0,
		&"heavy_missile", null, 0.0, 5.0, 1.0)
	await physics_frames(10)
	check(normal.health < normal.max_health, "a missile hits the cyborg next to it")
	check(is_equal_approx(host.health, before), "missile splash never hurts a host")
	await sim.free_world(w)

	# Killing a host (here a stomp) pays the host bonus; no Bad Dream script yet, so nothing spawns.
	w = sim.build_world(RunSim.layout(3, 400.0))
	host = _spawn(w, 45.0, 1, {"host": true, "fires": false})
	await _step_until(w, func() -> bool: return host.track_distance() - w.player.distance <= STOMP_LEAD, 4.0)
	w.player.press(&"jump")
	var r: Dictionary = await sim.step_world(w, 1.0)
	check(r["alive"] and r["events"].has(&"stomp"), "a host can be stomped (%s)" % r["cause"])
	check(int(w.score.bonuses.get(&"host", 0)) == ct.host_bonus, "killing a host pays the host bonus (%s)" % str(w.score.bonuses))
	await physics_frames(2)
	check(w.director.count_alive() == 0, "no Bad Dream appears until its script exists")
	await sim.free_world(w)


## A walking cyborg stops short of a gap behind it; a panic run stops short of a fence ahead.
func _test_keeps_clear() -> void:
	var l: LevelLayout = RunSim.layout(5, 600.0)
	l.gaps.append({"lane": 4, "start": 60.0, "end": 66.0})
	l.fences.append(RunSim.fence(0, 112.0, "full"))
	var w: RunWorld = sim.build_world(l)
	w.player.god_mode = true
	var walker: Cyborg = _spawn(w, 80.0, 1, {"panic": false, "fires": false}, 1)
	var runner: Cyborg = _spawn(w, 92.0, 3, {"panic": true, "fires": false}, 2)
	var margin: float = ct.obstacle_margin
	check(walker.walk_limit >= 66.0 + margin - 0.01, "a cyborg's walk stops short of a gap (%.1f)" % walker.walk_limit)
	check(runner.run_limit <= 112.0 - tuning.fence_depth - margin + 0.01, "a panic run stops short of a fence (%.1f)" % runner.run_limit)
	var lowest: float = walker.track_distance()
	var highest: float = runner.track_distance()
	if not w.player.running:
		await tree.physics_frame
		w.player.running = true
	for i: int in 240:
		await tree.physics_frame
		if walker.alive and walker.mode != Cyborg.Mode.PASSED:
			lowest = minf(lowest, walker.track_distance())
		if runner.alive and runner.mode != Cyborg.Mode.PASSED:
			highest = maxf(highest, runner.track_distance())
	check(lowest >= 66.0 + margin - 0.05 and lowest < 79.0, "the walker walked, then stopped clear of the gap (%.1f)" % lowest)
	check(highest <= 112.0 - tuning.fence_depth - margin + 0.05 and highest > 95.0,
		"the runner ran, then stopped clear of the fence (%.1f)" % highest)
	await sim.free_world(w)

	# A cyborg that finds itself under a ceiling section (e.g. one added by a later rule) leaves play.
	l = RunSim.layout(3, 600.0)
	l.hulls.append({"start": 140.0, "end": 200.0})
	w = sim.build_world(l)
	var under: Cyborg = _spawn(w, 160.0, 1, {"fires": false})
	check(under.misplaced, "a cyborg under a ceiling section is flagged")
	await sim.step_world(w, 0.1)
	check(not is_instance_valid(under) or not under.alive or under.is_queued_for_deletion(),
		"and leaves play (GDD §3: the floor under a ceiling stays clear)")
	await sim.free_world(w)


func _test_generation() -> void:
	var base: LevelConfig = load(LEVEL_PATH) as LevelConfig
	var normal: int = 0
	var panics: int = 0
	var hosts: int = 0
	for lanes: int in [3, 5, 6]:
		for difficulty: float in [0.2, 0.5, 0.8]:
			for level_seed: int in range(1, 16):
				var config: LevelConfig = base.duplicate() as LevelConfig
				config.lane_count = lanes
				config.difficulty = difficulty
				config.level_seed = level_seed
				config.features = PackedStringArray(["ramps", "ceilings", "pulsing", "speed_pads", "cyborg", "host"])
				var patterns: Array = LevelGenerator.load_for(config)
				var gen := LevelGenerator.new()
				var a: LevelLayout = gen.generate(config, tuning, patterns)
				var tag: String = "lanes=%d diff=%.1f seed=%d" % [lanes, difficulty, level_seed]
				check(gen.warnings.is_empty(), "cyborg patterns generate without warnings " + tag)
				var b: LevelLayout = LevelGenerator.new().generate(config, tuning, patterns)
				check(JSON.stringify(a.enemies) == JSON.stringify(b.enemies), "same seed, same cyborgs " + tag)
				var spans: Array[Vector2] = CyborgRules.obstacle_spans(a, tuning)
				for e: Dictionary in a.enemies:
					if String(e["type"]) != "cyborg":
						continue
					var p: Dictionary = e["params"]
					check(p.has("panic"), "the generator decides the panic variant " + tag)
					if bool(p.get("host", false)):
						hosts += 1
						check(not bool(p["panic"]), "hosts don't panic " + tag)
					else:
						normal += 1
						if bool(p["panic"]):
							panics += 1
					check(int(e["lane"]) >= 0 and int(e["lane"]) < lanes, "cyborg lane in range " + tag)
					check(not CyborgRules.near_any(spans, float(e["at"]), ct.obstacle_margin - 0.01),
						"a cyborg stands clear of gaps, fences, ramps, pads and ceilings at %.1f %s" % [float(e["at"]), tag])
					check(not a.under_hull(float(e["at"])), "no cyborg under a ceiling " + tag)
	var share: float = float(panics) / maxf(float(normal), 1.0)
	check(normal > 200, "plenty of cyborgs generated (%d)" % normal)
	check(share > 0.26 and share < 0.41, "about 1 in 3 cyborgs panics (%.2f of %d)" % [share, normal])
	check(hosts > 20, "host patterns place hosts (%d)" % hosts)

	# Levels without the feature have no cyborgs.
	var plain: LevelConfig = base.duplicate() as LevelConfig
	var none: LevelLayout = LevelGenerator.new().generate(plain, tuning, LevelGenerator.load_for(plain))
	check(none.enemies.is_empty(), "levels without the cyborg feature place none")


## Full levels in god mode (the player runs straight through everything; grapples pull them out of
## gaps) over lane counts and seeds: every bolt follows a charge-up, comes from ahead with enough
## warning, never arrives near a fence or gap, only one burst is in the air at a time, and no cyborg
## ever stands near an obstacle.
func _test_fair_play() -> void:
	var base: LevelConfig = load(LEVEL_PATH) as LevelConfig
	var total_shots: int = 0
	for lanes: int in [3, 5, 6]:
		for level_seed: int in [2, 5]:
			var config: LevelConfig = base.duplicate() as LevelConfig
			config.lane_count = lanes
			config.difficulty = 0.7
			config.level_seed = level_seed
			config.features = PackedStringArray(["ceilings", "pulsing", "cyborg"])
			var layout: LevelLayout = LevelGenerator.new().generate(config, tuning, LevelGenerator.load_for(config))
			var tag: String = "lanes=%d seed=%d" % [lanes, level_seed]
			var w: RunWorld = sim.build_world(layout, _loadout({"grapple": 999}), null, config)
			w.player.god_mode = true
			var guns: Array[CyborgGun] = []
			w.director.enemy_spawned.connect(func(e: Enemy) -> void:
				if e is Cyborg:
					guns.append((e as Cyborg).gun))
			var spans: Array[Vector2] = CyborgRules.obstacle_spans(layout, tuning)
			var too_close: int = 0
			await tree.physics_frame
			w.player.running = true
			for i: int in 40 * 60:
				await tree.physics_frame
				if i % 5 != 0:
					continue
				for e: Enemy in w.director.active:
					var c := e as Cyborg
					if c != null and c.alive and c.mode != Cyborg.Mode.PASSED \
							and CyborgRules.near_any(spans, c.track_distance(), ct.obstacle_margin - 0.05):
						too_close += 1
			check(too_close == 0, "no cyborg ever stands near an obstacle " + tag)
			var shots: int = 0
			var bursts: Array = []
			for gun: CyborgGun in guns:
				var charge_t: float = -1.0
				var first: bool = false
				for ev: Dictionary in gun.events:
					match ev["event"]:
						&"charge":
							charge_t = ev["t"]
							first = true
							bursts.append([float(ev["t"]), float(ev["t"])])
						&"cancel":
							charge_t = -1.0
						&"shot":
							shots += 1
							var t: float = ev["t"]
							check(charge_t >= 0.0 and t - charge_t >= ct.charge_time - 0.02, "every bolt follows a charge-up " + tag)
							check(float(ev["shooter_d"]) > float(ev["player_d"]), "bolts only come from ahead " + tag)
							var warning: float = float(ev["arrive"]) - t
							var need: float = ct.min_warning_time if first else ct.min_warning_time * 0.5
							check(warning >= need - 0.02, "every bolt gives enough warning (%.2f s) %s" % [warning, tag])
							first = false
							var impact: float = ev["impact"]
							check(_clear(layout, impact - ct.clear_before_impact + 1.5, impact + ct.clear_after_impact - 1.5),
								"no bolt arrives near a fence or gap (%.1f) %s" % [impact, tag])
							bursts[-1][1] = t
			bursts.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
			for k: int in range(1, bursts.size()):
				check(float(bursts[k][0]) >= float(bursts[k - 1][1]) - 0.001, "one burst in the air at a time " + tag)
			check(w.player.distance > 700.0, "the run covers most of a level (%.0f m) %s" % [w.player.distance, tag])
			total_shots += shots
			await sim.free_world(w)
	check(total_shots > 40, "cyborgs fire throughout full levels (%d bolts)" % total_shots)

extends TestSuite
## The window cyborg (GDD §9.2): a wall enemy at a fixed height. Its body blocks wall runs at its
## height, not above (a ramp entry) or below (entering early), and never the floor lanes; armor
## doesn't stop its body but does stop its shots; it doesn't move; its bursts are telegraphed and
## dodged by a lane switch; and its patterns generate cleanly for 3, 5 and 6 lanes.

const WINDOW_TUNING_PATH: String = "res://data/enemies/window_cyborg.tres"
const WINDOW_AT: float = 70.0

var sim: RunSim
var wt: WindowCyborgTuning


func run() -> void:
	sim = RunSim.new(tree, tuning)
	wt = load(WINDOW_TUNING_PATH) as WindowCyborgTuning
	check(wt != null, "the window cyborg tuning loads")
	if wt == null:
		return
	await _test_heights()
	await _test_armor()
	await _test_shots()
	_test_generation()


func _spawn(w: RunWorld, at: float, side: int, params: Dictionary) -> WindowCyborg:
	return w.director.spawn({"type": "window_cyborg", "at": at, "lane": w.layout.outer_lane(side), "side": side,
		"seed": 11, "params": params}) as WindowCyborg


func _loadout(items: Dictionary) -> Loadout:
	var l := Loadout.new()
	for k: String in items:
		if k == "armor":
			l.armor = true
		else:
			l.charges[StringName(k)] = items[k]
	return l


## Runs a 3-lane world with a (non-firing) window cyborg on the right wall; `actions` as in RunSim.
func _run(actions: Array, layout: LevelLayout = null, loadout: Loadout = null) -> Dictionary:
	var l: LevelLayout = layout if layout != null else RunSim.layout(3, 400.0)
	var w: RunWorld = sim.build_world(l, loadout)
	var wc: WindowCyborg = _spawn(w, WINDOW_AT, 1, {"fires": false})
	var r: Dictionary = await sim.step_world(w, 5.5, actions, [WINDOW_AT + 3.0])
	r["band"] = Vector2(wc.band_bottom, wc.band_top) if is_instance_valid(wc) else Vector2.ZERO
	r["stayed"] = is_instance_valid(wc) and absf(wc.track_distance() - WINDOW_AT) < 0.001
	await sim.free_world(w)
	return r


func _test_heights() -> void:
	var center: float = tuning.wall_entry_height + wt.band_offset
	# A free entry just before it: at entry height when passing, which is its band.
	var r: Dictionary = await _run([[WINDOW_AT - 16.0, &"move_right"], [WINDOW_AT - 12.0, &"move_right"]])
	check(not r["alive"] and r["cause"] == "window cyborg", "a wall run at its height hits it (%s)" % r["cause"])
	var band: Vector2 = r["band"]
	check(absf((band.x + band.y) * 0.5 - center) < 0.001 and absf(band.y - band.x - wt.band_height) < 0.001,
		"its band is centred on the wall-entry height (%.2f–%.2f m)" % [band.x, band.y])
	# Entering early: slid down below it by the time it's reached.
	r = await _run([[WINDOW_AT - 32.0, &"move_right"], [WINDOW_AT - 28.0, &"move_right"]])
	check(r["alive"] and r["at"][WINDOW_AT + 3.0]["alive"], "entering early passes below it (%s)" % r["cause"])
	# A ramp launch: far above it.
	var ramp: LevelLayout = RunSim.layout(3, 400.0)
	ramp.ramps.append({"side": 1, "at": WINDOW_AT - 12.0})
	r = await _run([[WINDOW_AT - 30.0, &"move_right"]], ramp)
	check(r["alive"] and r["events"].has(&"ramp") and r["at"][WINDOW_AT + 3.0]["surface"] == "wall",
		"a ramp-launched wall run passes above it (%s)" % r["cause"])
	# The floor lanes below it are safe, even jumping in the outer lane.
	r = await _run([[WINDOW_AT - 30.0, &"move_right"], [WINDOW_AT - 6.0, &"jump"]])
	check(r["alive"] and r["stayed"], "running and jumping in the outer lane below it is safe, and it never moves")


func _test_armor() -> void:
	# Armor doesn't stop its body (a solid collision)...
	var r: Dictionary = await _run([[WINDOW_AT - 16.0, &"move_right"], [WINDOW_AT - 12.0, &"move_right"]],
		null, _loadout({"armor": 1}))
	check(not r["alive"] and r["cause"] == "window cyborg", "armor doesn't block its body (%s)" % r["cause"])
	# ...but does stop its shots.
	var w: RunWorld = sim.build_world(RunSim.layout(3, 600.0), _loadout({"armor": 1}))
	var wc: WindowCyborg = _spawn(w, 120.0, 1, {})
	var gun: CyborgGun = wc.gun
	var got_shot: bool = false
	if not w.player.running:
		await tree.physics_frame
		w.player.running = true
	for i: int in 6 * 60:
		await tree.physics_frame
		if w.player.armor == 0:
			got_shot = true
			break
	check(got_shot and w.player.alive, "armor blocks a window cyborg's bolt")
	var first: bool = false
	for e: Dictionary in gun.events:
		if e["event"] == &"charge":
			first = true
		elif e["event"] == &"shot":
			check(first, "its bolts follow a charge-up")
			break
	await sim.free_world(w)


func _test_shots() -> void:
	# A player on the floor who stays in the line is hit; one who switches lanes after the charge-up isn't.
	var w: RunWorld = sim.build_world(RunSim.layout(3, 600.0))
	_spawn(w, 120.0, 1, {})
	var r: Dictionary = await sim.step_world(w, 8.0)
	check(not r["alive"] and r["cause"] == CyborgGun.SHOT_NAME, "its burst hits a player who stays in its path (%s)" % r["cause"])
	await sim.free_world(w)

	w = sim.build_world(RunSim.layout(3, 600.0))
	var wc: WindowCyborg = _spawn(w, 120.0, 1, {})
	var gun: CyborgGun = wc.gun
	if not w.player.running:
		await tree.physics_frame
		w.player.running = true
	var fired: bool = false
	for i: int in 8 * 60:
		await tree.physics_frame
		if gun.state == CyborgGun.State.FIRING:
			fired = true
			break
	check(fired, "it fires at an approaching player")
	w.player.press(&"move_left")
	for i: int in 3 * 60:
		await tree.physics_frame
		if gun.state == CyborgGun.State.RELOADING:
			break
	var last_arrival: float = 0.0
	for e: Dictionary in gun.events:
		if e["event"] == &"shot":
			last_arrival = maxf(last_arrival, float(e["arrive"]))
	while w.level_time() < last_arrival + 0.3 and w.player.alive:
		await tree.physics_frame
	check(w.player.alive, "switching lanes after its charge-up dodges the burst")
	await sim.free_world(w)

	# DESIGN-TBD rule: it holds fire at a player running along its own wall (its body is the hazard
	# there), and opens up again once they're back on the floor.
	w = sim.build_world(RunSim.layout(3, 600.0))
	wc = _spawn(w, 150.0, 1, {})
	gun = wc.gun
	r = await sim.step_world(w, 5.5, [[52.0, &"move_right"], [56.0, &"move_right"]], [60.0, 90.0])
	check(r["at"][60.0]["surface"] == "wall" and r["at"][90.0]["surface"] == "wall", "the player runs along its wall")
	var charged_on_wall: bool = false
	var charged_later: bool = false
	for e: Dictionary in gun.events:
		if e["event"] == &"charge":
			if float(e["player_d"]) > 58.0 and float(e["player_d"]) < 92.0:
				charged_on_wall = true
			elif float(e["player_d"]) >= 92.0:
				charged_later = true
	check(not charged_on_wall, "it holds fire at a player on its own wall")
	check(charged_later, "and opens up once they're back on the floor")
	await sim.free_world(w)


func _test_generation() -> void:
	var base: LevelConfig = load(LEVEL_PATH) as LevelConfig
	var count: int = 0
	var sides: Dictionary = {}
	for lanes: int in [3, 5, 6]:
		for difficulty: float in [0.2, 0.5, 0.8]:
			for level_seed: int in range(1, 13):
				var config: LevelConfig = base.duplicate() as LevelConfig
				config.lane_count = lanes
				config.difficulty = difficulty
				config.level_seed = level_seed
				config.features = PackedStringArray(["ramps", "ceilings", "pulsing", "window_cyborg"])
				var patterns: Array = LevelGenerator.load_for(config)
				var gen := LevelGenerator.new()
				var a: LevelLayout = gen.generate(config, tuning, patterns)
				var tag: String = "lanes=%d diff=%.1f seed=%d" % [lanes, difficulty, level_seed]
				check(gen.warnings.is_empty(), "window cyborg patterns generate without warnings " + tag)
				var b: LevelLayout = LevelGenerator.new().generate(config, tuning, patterns)
				check(JSON.stringify(a.enemies) == JSON.stringify(b.enemies), "same seed, same window cyborgs " + tag)
				for e: Dictionary in a.enemies:
					if String(e["type"]) != "window_cyborg":
						continue
					count += 1
					var side: int = e["side"]
					sides[side] = true
					check(side == -1 or side == 1, "placed by side " + tag)
					check(int(e["lane"]) == a.outer_lane(side), "on the outer lane's wall " + tag)
					for s: Dictionary in a.signs:
						if int(s["side"]) == side:
							check(float(e["at"]) < float(s["start"]) - wt.window_length * 0.5 \
								or float(e["at"]) > float(s["end"]) + wt.window_length * 0.5,
								"no sign covers a window at %.1f %s" % [float(e["at"]), tag])
	check(count > 60 and sides.size() == 2, "window cyborgs appear on both walls (%d)" % count)

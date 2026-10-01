extends TestSuite
## The Tithe Collector (GDD §9.12, task C5): a gold drone that paces the player, weaves toward the
## most dangerous lanes ahead of itself, vacuums the credits in its path, and carries the shared
## theft contract (task B6; test_theft.gd covers that contract itself — DamageRules, the books, the
## pay, the feedback — over every protection and every catch; this suite covers what's unique to the
## collector):
## - its look: gold, plain metal (never glows), no rotors, an eye that glows no hazard colour;
## - it vacuums only the credits in its path (its own lane, within reach), held so stars stay fair;
## - it weaves toward the lane with the most hazards ahead of it, never the player's own lane when
##   one is more dangerous, and settles over the player's lane when nothing is;
## - anti-grav pads don't affect it, unlike the heli drone;
## - the approach cue plays once it exists;
## - a catch (any defeat, including caught mid-flight after a theft) pays what it holds plus the
##   jackpot: test_theft.gd already covers every way to catch a thief (stomp, dash, claws, a weapon)
##   on the shared contract, which this declares identically;
## - it's spawned through the director, with no big-attack turn (it isn't an attack);
## - it plays out identically on every attempt;
## - the campaign: corporate/2 introduces it, it's left out of the Dead Zone, and it's out of
##   LevelConfig.PLANNED_FEATURES.

const TYPE: String = "tithe_collector"

var sim: RunSim
var _nodes: Array[Node] = []


func run() -> void:
	sim = RunSim.new(tree, tuning)
	await _test_declares()
	await _test_look()
	await _test_vacuum_path_only()
	await _test_weaves_to_danger()
	await _test_settles_on_player_with_nothing_dangerous()
	await _test_pads_dont_affect_it()
	await _test_approach_cue()
	await _test_catch_pays_jackpot()
	await _test_no_big_attack_turn()
	await _test_determinism()
	_test_campaign_data()
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


# --- Declares (CLAUDE.md principle 8: enemies declare, DamageRules decides) ---------------------

func _test_declares() -> void:
	var world: RunWorld = sim.build_world(RunSim.layout(5, 600.0))
	var c: TitheCollector = _spawn(world, 2)
	check(c != null and c.jackpot_credits == c.tune.jackpot_credits and is_equal_approx(c.box.steals_share, 0.25),
		"it declares the theft (25%, GDD §9.12) and its jackpot from its data")
	check(not c.claw_immune and c.box.part == &"top", "the claws catch it like any enemy (GDD §8), from above it's a stomp")
	check(c.jackpot_credits > 0, "a catch always pays a jackpot on top of what it holds")
	await sim.free_world(world)


# --- The look (GDD §9.12: gold, metal, never glows; not a heli drone: no rotors) -----------------

func _test_look() -> void:
	var world: RunWorld = sim.build_world(RunSim.layout(5, 600.0))
	var c: TitheCollector = _spawn(world, 2)
	var meshes: Array = c.find_children("*", "MeshInstance3D", true, false)
	check(meshes.size() == 1, "one merged mesh (CLAUDE.md: one draw call), not a rotored drone's several (%d)" % meshes.size())
	var mat := (meshes[0] as MeshInstance3D).mesh.surface_get_material(0) as StandardMaterial3D
	check(mat != null and not mat.emission_enabled and mat.albedo_color.r > mat.albedo_color.b + 0.3,
		"the body is gold and never glows (GDD §9.12: \"Gold here is metal\")")
	var skin := GreyboxSkin.new()
	var hazard_colors: Array[Color] = [skin.fence_color, skin.gap_edge_color, skin.sign_color, skin.pad_color,
		skin.ramp_color, Color(1.0, 0.12, 0.08)]  # the enemy fire / weak point red
	var far: bool = true
	for col: Color in hazard_colors:
		far = far and _hue_distance(TitheCollector.EYE_COLOR, col) >= 0.06
	check(far, "its eye glows no hazard colour (%s)" % TitheCollector.EYE_COLOR)
	await sim.free_world(world)


# --- The vacuum (GDD §9.12: "sucks up the credits in its path") ----------------------------------

func _test_vacuum_path_only() -> void:
	var layout: LevelLayout = RunSim.layout(5, 400.0)
	# Three credits at the same distance, one in the collector's lane (2), two in others: only the
	# one in its path is ever taken. Ahead of where it appears (start_ahead ~30 m), so it's still to
	# come when it spawns.
	for lane: int in [1, 2, 3]:
		layout.credits.append({"at": 40.0, "surface": "floor", "lane": lane, "side": 0, "height": 0.7, "value": 5})
	var world: RunWorld = sim.build_world(layout)
	var p: Player = world.player
	await _run(world, func() -> bool: return p.elapsed > 0.05, 1.0)
	var c: TitheCollector = world.director.spawn({"type": TYPE, "at": p.distance, "lane": 2, "seed": 1}) as TitheCollector
	# It closes in on the player (ahead of it the whole time): catches the credits well before it
	# could ever reach the player itself.
	await _run(world, func() -> bool: return c.track_d > 44.0, 3.0)
	check(world.score.held_by(c) == 5, "it took the 5 credits in its own lane (held %d)" % world.score.held_by(c))
	check(world.credits.remaining() == 2, "the credits in the other two lanes are untouched, left for the player")
	check(c.state == TitheCollector.State.APPROACH and world.score.thefts == 0, "still well ahead: no theft yet")
	await sim.free_world(world)


# --- Weaving (GDD §9.12: "weaves through the most dangerous lanes") ------------------------------

func _test_weaves_to_danger() -> void:
	var layout: LevelLayout = RunSim.layout(5, 400.0)
	# Gaps only in lane 4, ahead of where it appears (start_ahead ~30 m), within its first lookahead
	# window.
	for at: float in [40.0, 46.0, 52.0]:
		layout.gaps.append({"lane": 4, "start": at, "end": at + 1.0})
	var world: RunWorld = sim.build_world(layout)
	var p: Player = world.player
	await _run(world, func() -> bool: return p.elapsed > 0.05, 1.0)
	var c: TitheCollector = world.director.spawn({"type": TYPE, "at": p.distance, "lane": 0, "seed": 1}) as TitheCollector
	check(c.target_lane == 0, "it starts where it was aimed")
	await _run(world, func() -> bool: return c.target_lane == 4, 4.0)
	check(c.target_lane == 4, "it weaves toward the only lane with hazards ahead of it (lane %d)" % c.target_lane)
	await _run(world, func() -> bool: return absf(c.lane_x_now - world.geo.lane_x(4)) < 0.1, 4.0)
	check(absf(c.lane_x_now - world.geo.lane_x(4)) < 0.1, "and actually crosses the lanes to get there")
	await sim.free_world(world)


func _test_settles_on_player_with_nothing_dangerous() -> void:
	var world: RunWorld = sim.build_world(RunSim.layout(5, 400.0))
	var p: Player = world.player
	await _run(world, func() -> bool: return p.elapsed > 0.05, 1.0)
	p.lane = 3
	var c: TitheCollector = world.director.spawn({"type": TYPE, "at": p.distance, "lane": 0, "seed": 1}) as TitheCollector
	await _run(world, func() -> bool: return c.target_lane == 3, 4.0)
	check(c.target_lane == 3, "with nothing dangerous ahead it settles over the player's own lane (lane %d)" % c.target_lane)
	await sim.free_world(world)


# --- Pads (GDD §9.12, proposed: "anti-grav pads don't affect it") --------------------------------

func _test_pads_dont_affect_it() -> void:
	var layout: LevelLayout = RunSim.layout(5, 500.0)
	layout.pads.append({"lane": 2, "at": 40.0})
	layout.hulls.append({"start": 20.0, "end": 200.0})
	var world: RunWorld = sim.build_world(layout)
	var p: Player = world.player
	await _run(world, func() -> bool: return p.elapsed > 0.05, 1.0)
	var c: TitheCollector = world.director.spawn({"type": TYPE, "at": p.distance, "lane": 2, "seed": 1}) as TitheCollector
	var before: float = c.rel_ahead
	await _to_lane(world, 2)
	# Rides the pad up onto the ceiling (a heli drone on screen would be hurled into the hull here).
	await _run(world, func() -> bool: return p.distance > 45.0, 6.0)
	check(c.alive and c.state == TitheCollector.State.APPROACH and c.rel_ahead < before,
		"stepping on a pad (and riding the ceiling) does nothing to it: it keeps closing in as usual, unlike a heli drone (GDD §9.12)")
	await sim.free_world(world)


# --- The approach cue (GDD §9.12: noticeable, not a hazard warning) ------------------------------

func _test_approach_cue() -> void:
	var world: RunWorld = sim.build_world(RunSim.layout(5, 400.0))
	var sounds: Array[StringName] = []
	world.sounds.requested.connect(func(sound: StringName) -> void: sounds.append(sound))
	_spawn(world, 2)
	check(sounds.has(&"tithe_collector_cue"), "its approach cue plays once it exists (%s)" % [sounds])
	var library: SfxLibrary = load("res://data/audio/sfx_library.tres") as SfxLibrary
	check(library.has_file(&"tithe_collector_cue") and library.names().has("tithe_collector_cue"),
		"the sound is in the library, with its file")
	await sim.free_world(world)


# --- Catches (the shared contract, test_theft.gd; here: its own data pays through, mid-flight too) -

func _test_catch_pays_jackpot() -> void:
	var world: RunWorld = sim.build_world(RunSim.layout(5, 600.0))
	var p: Player = world.player
	await _run(world, func() -> bool: return p.elapsed > 0.05, 1.0)
	world.score.add_credit(400)
	var c: TitheCollector = _spawn(world, p.lane)
	world.score.rob(c, 0.25)
	var jackpot: int = c.jackpot_credits
	var held: int = world.score.held_by(c)
	var before: int = world.score.credits
	c.take_damage(1000.0, &"laser")
	check(world.score.credits == before + held + jackpot and world.score.held_by(c) == 0,
		"a catch mid-flight pays what it held plus the jackpot (%d + %d)" % [held, jackpot])
	await sim.free_world(world)


# --- No big-attack turn (GDD §9.12: it isn't an attack) -------------------------------------------

func _test_no_big_attack_turn() -> void:
	var world: RunWorld = sim.build_world(RunSim.layout(5, 600.0))
	var c: TitheCollector = _spawn(world, 2)
	check(not c.is_major_attack_active() and not world.director.major_attack_blocked(c),
		"it never reports a big attack, and never waits for another type's turn")
	await sim.free_world(world)


# --- Determinism (GDD, every enemy: the same seed plays out the same way) ------------------------

func _test_determinism() -> void:
	var layout: LevelLayout = RunSim.layout(5, 400.0)
	# Ahead of where it appears (start_ahead ~30 m): gaps in lane 1 and a credit in lane 0.
	for at: float in [40.0, 44.0, 48.0]:
		layout.gaps.append({"lane": 1, "start": at, "end": at + 1.0})
	layout.credits.append({"at": 35.0, "surface": "floor", "lane": 0, "side": 0, "height": 0.7, "value": 5})
	var a: Dictionary = await _weave_run(layout.copy(), 1)
	var b: Dictionary = await _weave_run(layout.copy(), 1)
	check(a["trace"] == b["trace"] and a["held"] == b["held"] and not (a["trace"] as Array).is_empty(),
		"the same seed weaves and vacuums identically every attempt (%d frames traced)" % (a["trace"] as Array).size())


func _weave_run(layout: LevelLayout, seed_value: int) -> Dictionary:
	var world: RunWorld = sim.build_world(layout)
	var p: Player = world.player
	await _run(world, func() -> bool: return p.elapsed > 0.05, 1.0)
	var c: TitheCollector = world.director.spawn({"type": TYPE, "at": p.distance, "lane": 0, "seed": seed_value}) as TitheCollector
	var trace: Array = []
	await _run(world, func() -> bool:
		trace.append(snappedf(c.lane_x_now, 0.001))
		return c.track_d > 50.0, 4.0)
	var out := {"trace": trace, "held": world.score.held_by(c)}
	await sim.free_world(world)
	return out


# --- The campaign (GDD §5, §9.12) -----------------------------------------------------------------

func _test_campaign_data() -> void:
	check(not LevelConfig.PLANNED_FEATURES.has("tithe_collector"), "it's out of LevelConfig.PLANNED_FEATURES: it's built")
	var patterns: Array = LevelGenerator.load_for(load("res://data/levels/corporate_2.tres") as LevelConfig)
	var has_pattern: bool = false
	for pat: Dictionary in patterns:
		has_pattern = has_pattern or (pat.get("requires", []) as Array).has(TYPE)
	check(has_pattern, "a pattern places it (data/patterns/tithe_collector.json)")
	var corporate_2 := load("res://data/levels/corporate_2.tres") as LevelConfig
	var corporate_1 := load("res://data/levels/corporate_1.tres") as LevelConfig
	check(corporate_2.has_feature(TYPE) and not corporate_1.has_feature(TYPE),
		"Corporate 2 introduces it, Corporate 1 doesn't yet (GDD §5)")
	for id: String in ["dead_zone_1", "dead_zone_2"]:
		check(not (load("res://data/levels/%s.tres" % id) as LevelConfig).has_feature(TYPE),
			"%s leaves it out (GDD §9.12, proposed: it skips the Dead Zone)" % id)
	for id: String in ["golden_1", "golden_2", "golden_3"]:
		check((load("res://data/levels/%s.tres" % id) as LevelConfig).has_feature(TYPE),
			"%s brings it back (GDD §9.12, proposed: it returns in the Golden Zone)" % id)


# --- Helpers ---------------------------------------------------------------------------------------

func _spawn(world: RunWorld, lane: int, seed_value: int = 1) -> TitheCollector:
	return world.director.spawn({"type": TYPE, "at": world.player.distance, "lane": lane, "seed": seed_value}) as TitheCollector


func _run(world: RunWorld, condition: Callable, seconds: float) -> bool:
	if not world.player.running:
		await tree.physics_frame
		world.player.running = true
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		if condition.call():
			return true
		await tree.physics_frame
	return condition.call()


func _to_lane(world: RunWorld, lane: int) -> void:
	var p: Player = world.player
	for i: int in 12:
		if p.lane == lane:
			break
		p.press(&"move_left" if lane < p.lane else &"move_right")
		await physics_frames(12)
	await physics_frames(6)


func _hue_distance(a: Color, b: Color) -> float:
	var d: float = absf(a.h - b.h)
	return minf(d, 1.0 - d)

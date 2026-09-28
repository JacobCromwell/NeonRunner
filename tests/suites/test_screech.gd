extends TestSuite
## The Sewer Screech (GDD §9.5) in full RunWorlds on real physics: hidden unless the player is in its
## lane, the warning first, the dash and swipe, dodges, wall vents (floor and wall cases), protection,
## weapons and contact kills, its generator patterns, and its swarm-ready body.

var sim: RunSim
var t: ScreechTuning


func run() -> void:
	sim = RunSim.new(tree, tuning)
	t = EnemyDirector.tuning_for("screech") as ScreechTuning
	check(t != null, "data/enemies/screech.tres is a ScreechTuning")
	if t == null:
		return
	await _test_hidden_unless_in_lane()
	await _test_attacks_in_lane()
	await _test_dodges()
	await _test_wall_vent_floor()
	await _test_wall_vent_wall()
	await _test_protection()
	await _test_kills()
	await _test_spines()
	_test_generator()
	_test_body()


# --- Helpers ------------------------------------------------------------------------------------

func _loadout(items: Dictionary) -> Loadout:
	var l := Loadout.new()
	for k: String in items:
		if k in ["armor", "shield", "grapple", "revive"]:
			l.charges[StringName(k)] = items[k]
		else:
			l.tiers[StringName(k)] = items[k]
	return l


## A world with the player in `player_lane` and a screech `at` metres ahead: a manhole in `lane`, or
## a vent on `side` (±1) when side isn't 0.
func _world(lanes: int, player_lane: int, lane: int, side: int = 0, loadout: Loadout = null,
		at: float = 45.0) -> Array:
	var w: RunWorld = sim.build_world(RunSim.layout(lanes, 400.0), loadout)
	w.player.setup(tuning, w.geo, player_lane)
	var entry := {"type": "screech", "at": at, "lane": lane, "side": side, "seed": 9,
		"params": {"source": "vent" if side != 0 else "manhole"}}
	if side != 0:
		entry["lane"] = w.layout.outer_lane(side)
	var s := w.director.spawn(entry) as Screech
	await tree.physics_frame
	w.player.running = true
	return [w, s]


func _until(cond: Callable, seconds: float) -> bool:
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		if cond.call():
			return true
		await tree.physics_frame
	return cond.call()


func _wait(seconds: float) -> void:
	await _until(func() -> bool: return false, seconds)


## The screech with this instance id, or null once it's freed.
func _screech(id: int) -> Screech:
	var o: Object = instance_from_id(id)
	return o as Screech if is_instance_valid(o) else null


func _phase_is(id: int, phase: Screech.Phase) -> bool:
	var s: Screech = _screech(id)
	return s != null and s.alive and s.phase == phase


func _rel(w: RunWorld, id: int) -> float:
	var s: Screech = _screech(id)
	return -s.global_position.z - w.player.distance if s != null else -INF


## True if any of its hitboxes could hurt right now.
func _harmful(id: int) -> bool:
	var s: Screech = _screech(id)
	if s == null:
		return false
	for c: Node in s.get_children():
		if c is Hazard and (c as Hazard).is_active():
			return true
	return false


func _gone(s: Variant) -> bool:
	return not is_instance_valid(s) or not (s as Screech).alive


func _names(s: Screech) -> PackedStringArray:
	var out := PackedStringArray()
	for h: Array in s.history:
		out.append(String(h[0]))
	return out


# --- Behaviour ----------------------------------------------------------------------------------

## GDD §9.5: it comes out only if the player is in its lane; otherwise it stays hidden, and a hidden
## screech never hurts (even run over, even if the player moves into its lane too late for a warning).
func _test_hidden_unless_in_lane() -> void:
	for lanes: int in [3, 5, 6]:
		for lane: int in [0, lanes - 1]:
			var player_lane: int = 1 if lane == 0 else lanes - 2
			var made: Array = await _world(lanes, player_lane, lane)
			var w: RunWorld = made[0]
			var s: Screech = made[1]
			var id: int = s.get_instance_id()
			var ever_harmful := [false]
			for i: int in 240:
				ever_harmful[0] = ever_harmful[0] or _harmful(id)
				await tree.physics_frame
			check(w.player.alive and s.history.is_empty() and not ever_harmful[0],
				"with the player in another lane it stays hidden and harmless (lanes=%d lane=%d)" % [lanes, lane])
			check(not s.targetable(), "a hidden screech isn't a target")
			await _until(func() -> bool: return _screech(id) == null or _screech(id).is_queued_for_deletion(), 3.0)
			check(_screech(id) == null or _screech(id).is_queued_for_deletion(), "and it's left behind")
			await sim.free_world(w)
	# Moving into its lane too late for a fair warning: it stays hidden and the cover is safe.
	var made2: Array = await _world(3, 1, 0)
	var w2: RunWorld = made2[0]
	var s2: Screech = made2[1]
	var id2: int = s2.get_instance_id()
	await _until(func() -> bool: return _rel(w2, id2) < t.min_warning_seconds * tuning.run_speed - 5.0, 4.0)
	w2.player.press(&"move_left")
	await _until(func() -> bool: return _rel(w2, id2) < -3.0, 3.0)
	check(w2.player.alive and s2.history.is_empty(), "moving into its lane too late: it stays hidden, the cover is safe")
	await sim.free_world(w2)


## In its lane: warning first (shake, then burst), then the dash and one swipe, which hits a player
## who stays. Nothing about it can hurt before the shake has run and it's out.
func _test_attacks_in_lane() -> void:
	for lanes: int in [3, 5, 6]:
		for lane: int in [0, lanes / 2, lanes - 1]:
			var tag: String = "lanes=%d lane=%d" % [lanes, lane]
			var made: Array = await _world(lanes, lane, lane)
			var w: RunWorld = made[0]
			var s: Screech = made[1]
			var id: int = s.get_instance_id()
			var harmful_at: Array = []
			var shake_at := [-1.0]
			var frames: int = 0
			while w.player.alive and frames < 300:
				if shake_at[0] < 0.0 and s.phase == Screech.Phase.SHAKE:
					shake_at[0] = w.player.elapsed
				if harmful_at.is_empty() and _harmful(id):
					harmful_at = [w.player.elapsed, _names(s)]
				await tree.physics_frame
				frames += 1
			check(not w.player.alive and w.player.last_event.contains("Sewer Screech"),
				"staying in its lane gets swiped %s (%s)" % [tag, w.player.last_event])
			var names: PackedStringArray = _names(s)
			check(names.size() >= 4 and names[0] == "shake" and names[1] == "emerge" and names[2] == "dash"
				and names[3] == "swipe", "shake, burst out, dash, swipe %s (%s)" % [tag, names])
			var shook_from: float = -1.0
			if not s.history.is_empty():
				shook_from = float(s.history[0][1])
			check(-s.global_position.z - shook_from >= t.min_warning_seconds * tuning.run_speed - t.dash_max_distance - 0.5,
				"the shake starts with time to react " + tag)
			check(not harmful_at.is_empty() and shake_at[0] >= 0.0
				and float(harmful_at[0]) >= shake_at[0] + t.shake_time(0.0) - 0.02
				and not (harmful_at[1] as PackedStringArray).has("hidden"),
				"the shake always comes first: harmless until it's out " + tag)
			await sim.free_world(w)


## GDD §9.5: dodge by switching lanes (any time after the shake starts) or jumping over it.
func _test_dodges() -> void:
	for lanes: int in [3, 5, 6]:
		for lane: int in [0, lanes - 1]:
			for delay: float in [0.1, t.shake_time(0.0) + t.emerge_time]:
				var made: Array = await _world(lanes, lane, lane)
				var w: RunWorld = made[0]
				var s: Screech = made[1]
				var id: int = s.get_instance_id()
				await _until(_phase_is.bind(id, Screech.Phase.SHAKE), 4.0)
				await _wait(delay)
				w.player.press(&"move_right" if lane == 0 else &"move_left")
				await _until(func() -> bool: return _rel(w, id) < -3.0, 3.0)
				check(w.player.alive, "switching lanes %.2f s after the shake starts dodges (lanes=%d lane=%d, %s)"
					% [delay, lanes, lane, w.player.last_event])
				check(_names(s).has("swipe"), "it still dashes and swipes at the empty lane")
				await sim.free_world(w)
		var made2: Array = await _world(lanes, 1, 1)
		var w2: RunWorld = made2[0]
		var s2: Screech = made2[1]
		var id2: int = s2.get_instance_id()
		await _until(func() -> bool: return _phase_is(id2, Screech.Phase.DASH) and _rel(w2, id2) < 6.5, 4.0)
		w2.player.press(&"jump")
		await _until(func() -> bool: return _rel(w2, id2) < -3.0 and w2.player.grounded, 3.0)
		check(w2.player.alive, "jumping over it dodges its swipe (lanes=%d, %s)" % [lanes, w2.player.last_event])
		await sim.free_world(w2)


## GDD §9.5 wall vents, player on the nearby floor: it drops to that lane and attacks.
func _test_wall_vent_floor() -> void:
	for lanes: int in [3, 6]:
		for side: int in [-1, 1]:
			var outer: int = 0 if side < 0 else lanes - 1
			var made: Array = await _world(lanes, outer, outer, side)
			var w: RunWorld = made[0]
			var s: Screech = made[1]
			await _until(func() -> bool: return not w.player.alive, 4.0)
			check(not w.player.alive and w.player.last_event.contains("Sewer Screech"),
				"a vent screech drops into the lane beside it and swipes (lanes=%d side=%d, %s)" % [lanes, side, w.player.last_event])
			check(is_instance_valid(s) and not s.wall_mode and _names(s).has("dash"), "it came out onto the floor")
			await sim.free_world(w)
			# Switching away dodges it; the far lanes and the other wall never trigger it.
			made = await _world(lanes, outer, outer, side)
			w = made[0]
			s = made[1]
			var id: int = s.get_instance_id()
			await _until(_phase_is.bind(id, Screech.Phase.SHAKE), 4.0)
			w.player.press(&"move_right" if side < 0 else &"move_left")
			await _until(func() -> bool: return _rel(w, id) < -3.0, 3.0)
			check(w.player.alive, "switching away from a vent's lane dodges it")
			await sim.free_world(w)
			var other: int = lanes - 1 - outer
			made = await _world(lanes, other, outer, side)
			w = made[0]
			s = made[1]
			id = s.get_instance_id()
			await _until(func() -> bool: return _rel(w, id) < -3.0, 4.0)
			check(w.player.alive and s.history.is_empty(), "a vent stays shut for a player in the far lanes")
			await sim.free_world(w)


## GDD §9.5 wall vents, player on the wall at the vent: it swipes from the vent, then drops.
## Lingering low on the wall gets you swiped; jumping off the wall escapes.
func _test_wall_vent_wall() -> void:
	for side: int in [-1, 1]:
		for escape: bool in [false, true]:
			var lanes: int = 5
			var outer: int = 0 if side < 0 else lanes - 1
			var w: RunWorld = sim.build_world(RunSim.layout(lanes, 400.0))
			w.player.setup(tuning, w.geo, outer)
			var s := w.director.spawn({"type": "screech", "at": 35.0, "lane": outer, "side": side, "seed": 3,
				"params": {"source": "vent"}}) as Screech
			var id: int = s.get_instance_id()
			await tree.physics_frame
			w.player.running = true
			await _until(func() -> bool: return w.player.distance >= 5.0, 1.0)
			w.player.press(&"move_left" if side < 0 else &"move_right")
			await _until(_phase_is.bind(id, Screech.Phase.SHAKE), 3.0)
			check(w.player.surface == Player.Surface.WALL and is_instance_valid(s) and s.wall_mode,
				"with the player on the wall above it, it comes out at the vent (side %d)" % side)
			if escape:
				await _wait(t.shake_time(0.0))
				w.player.press(&"jump")
			await _until(func() -> bool: return not w.player.alive or _rel(w, id) < -4.0, 3.0)
			if escape:
				check(w.player.alive, "jumping off the wall escapes the vent's swipe (side %d, %s)" % [side, w.player.last_event])
				await _until(_phase_is.bind(id, Screech.Phase.DONE), 2.0)
				var names: PackedStringArray = _names(s) if is_instance_valid(s) else PackedStringArray()
				check(names.has("vent_swipe") and names.has("drop") and names.has("done"),
					"it swipes from the vent, then drops to the floor (%s)" % names)
				check(is_instance_valid(s) and absf(s.global_position.x - w.geo.lane_x(outer)) < 0.05,
					"and lands in the lane beside the vent")
			else:
				check(not w.player.alive and w.player.last_event.contains("Sewer Screech"),
					"lingering low on the wall at the vent gets swiped (side %d, %s)" % [side, w.player.last_event])
			await sim.free_world(w)


## GDD §9.5: armor and the shield block its swipe.
func _test_protection() -> void:
	for item: String in ["armor", "shield"]:
		var made: Array = await _world(3, 1, 1, 0, _loadout({item: 1}))
		var w: RunWorld = made[0]
		var events: Array = []
		w.player.movement_event.connect(func(k: StringName) -> void: events.append(k))
		var s: Screech = made[1]
		var id: int = s.get_instance_id()
		await _until(func() -> bool: return _rel(w, id) < -3.0, 4.0)
		check(w.player.alive and events.has(StringName(item + "_break")), "%s blocks the swipe (%s)" % [item, w.player.last_event])
		await sim.free_world(w)


## GDD §9.5: any weapon in one hit (never while hidden), claws, or the dash.
func _test_kills() -> void:
	var made: Array = await _world(3, 1, 1)
	var w: RunWorld = made[0]
	var s: Screech = made[1]
	w.player.running = false
	w.projectiles.fire_player(Vector3(w.geo.lane_x(1), 0.3, -10.0), Vector3(0.0, 0.0, -90.0), 1.0)
	await _until(func() -> bool: return w.projectiles.live_count() == 0, 1.0)
	check(s.alive and is_equal_approx(s.health, 1.0), "a hidden screech can't be shot")
	check(is_equal_approx(s.max_health, 1.0), "one laser tier 1 shot's worth of health")
	s._burst_out()
	var id: int = s.get_instance_id()
	await _until(_phase_is.bind(id, Screech.Phase.DASH), 1.0)
	check(s.targetable(), "once out, it's a target")
	w.projectiles.fire_player(Vector3(w.geo.lane_x(1), 0.3, -10.0), Vector3(0.0, 0.0, -90.0), 1.0)
	await _until(func() -> bool: return w.projectiles.live_count() == 0, 1.0)
	check(_gone(s) and w.score.kills == 1, "one weapon hit kills it")
	await tree.physics_frame
	check(not _harmful(id) and (_screech(id) == null or not _screech(id).targetable()),
		"a defeated screech can't hurt and isn't a target (its lair stays in view)")
	await sim.free_world(w)

	for item: String in ["claws", "dash"]:
		made = await _world(3, 1, 1, 0, _loadout({"claws": 1} if item == "claws" else {}))
		w = made[0]
		s = made[1]
		id = s.get_instance_id()
		if item == "dash":
			await _until(func() -> bool: return _phase_is(id, Screech.Phase.DASH) and _rel(w, id) < 7.0, 4.0)
			w.player.start_dash(0.6, 8.0)
		await _until(func() -> bool: return not w.player.alive or _gone(_screech(id)), 4.0)
		check(w.player.alive and _gone(s) and w.score.kills == 1, "%s kill it (%s)" % [item, w.player.last_event])
		await sim.free_world(w)


## GDD §9.5: landing on it without claws hurts (its spines); with claws it dies.
func _test_spines() -> void:
	for claws: bool in [false, true]:
		var w: RunWorld = sim.build_world(RunSim.layout(3, 400.0), _loadout({"claws": 1} if claws else {}))
		w.player.setup(tuning, w.geo, 1)
		var s := w.director.spawn({"type": "screech", "at": 30.0, "lane": 1, "side": 0, "seed": 1,
			"params": {"source": "manhole"}}) as Screech
		var id: int = s.get_instance_id()
		await tree.physics_frame
		# Out of its hole and sitting still (as after an attack), then the player jumps onto it.
		s._burst_out()
		await _until(_phase_is.bind(id, Screech.Phase.DASH), 1.0)
		s.phase = Screech.Phase.DONE
		w.player.running = true
		var stomped := [false]
		await _until(func() -> bool: return _rel(w, id) <= 11.5, 3.0)
		w.player.press(&"jump")
		w.player.movement_event.connect(func(k: StringName) -> void: stomped[0] = stomped[0] or k == &"stomp")
		await _until(func() -> bool: return not w.player.alive or _gone(_screech(id)), 2.0)
		if claws:
			check(w.player.alive and _gone(s), "with claws, landing on it kills it (%s)" % w.player.last_event)
		else:
			check(not w.player.alive and w.player.last_event.contains("Sewer Screech") and not stomped[0],
				"landing on its spines without claws hurts (%s)" % w.player.last_event)
		await sim.free_world(w)


# --- Generator and body -------------------------------------------------------------------------

func _test_generator() -> void:
	var base: LevelConfig = load(LEVEL_PATH) as LevelConfig
	var manholes: int = 0
	var vents: int = 0
	var under_ceilings: int = 0
	for features: PackedStringArray in [PackedStringArray(["ramps", "ceilings", "pulsing", "screech"]),
			PackedStringArray(["ramps", "ceilings", "pulsing", "screech_vents"])]:
		var vents_only: bool = features.has("screech_vents")
		var count: int = 0
		for lanes: int in [3, 5, 6]:
			for difficulty: float in [0.2, 0.7]:
				for level_seed: int in range(1, 13):
					var config: LevelConfig = base.duplicate() as LevelConfig
					config.lane_count = lanes
					config.difficulty = difficulty
					config.level_seed = level_seed
					config.features = features
					var tag: String = "%s lanes=%d diff=%.1f seed=%d" % [features[-1], lanes, difficulty, level_seed]
					var patterns: Array = LevelGenerator.load_for(config)
					var gen := LevelGenerator.new()
					var a: LevelLayout = gen.generate(config, tuning, patterns)
					check(gen.warnings.is_empty(), "screech patterns generate without warnings " + tag)
					var b: LevelLayout = LevelGenerator.new().generate(config, tuning, patterns)
					check(JSON.stringify(a.to_dict()) == JSON.stringify(b.to_dict()), "same seed, same level " + tag)
					for e: Dictionary in a.enemies:
						if e["type"] != "screech":
							continue
						count += 1
						var at: float = float(e["at"])
						var lane: int = int(e["lane"])
						if a.under_hull(at):
							under_ceilings += 1
						if String(e["params"].get("source", "")) == "vent":
							vents += 1
							check(absi(int(e["side"])) == 1 and lane == a.outer_lane(int(e["side"])),
								"a vent sits at the foot of a wall, beside the outer lane " + tag)
							check(not _sign_over(a, int(e["side"]), at), "a vent isn't hidden behind a sign " + tag)
						else:
							manholes += 1
							check(not vents_only, "the screech_vents feature gets vents only " + tag)
							check(int(e["side"]) == 0 and lane >= 0 and lane < a.lane_count, "a manhole sits in a floor lane " + tag)
							check(not a.gapped_between(lane, at - 15.0, at + 2.0) and not _fence_near(a, lane, at - 15.0, at + 2.0),
								"a manhole's lane is clear where it attacks " + tag)
					# GDD §3: a screech may lurk under a ceiling, but never where the player lands or
					# steps onto a pad (its reach covers where it springs out at them).
					LayoutChecks.check_ceilings(self, a, config, tag)
		check(count > 20, "levels with %s get screeches (%d)" % [features[-1], count])
	check(manholes > 20 and vents > 20, "manholes and vents both appear (%d, %d)" % [manholes, vents])
	check(under_ceilings > 0, "some screeches lurk under a ceiling (GDD §3: the floor there may be dangerous): %d" % under_ceilings)
	var plain: LevelConfig = base.duplicate() as LevelConfig
	var layout: LevelLayout = LevelGenerator.new().generate(plain, tuning, LevelGenerator.load_for(plain))
	var none: bool = true
	for e: Dictionary in layout.enemies:
		none = none and e["type"] != "screech"
	check(none, "no screeches without the feature")


func _sign_over(layout: LevelLayout, side: int, at: float) -> bool:
	for s: Dictionary in layout.signs:
		if int(s["side"]) == side and float(s["start"]) <= at + 1.0 and float(s["end"]) >= at - 1.0:
			return true
	return false


func _fence_near(layout: LevelLayout, lane: int, from: float, to: float) -> bool:
	for f: Dictionary in layout.fences:
		if int(f["lane"]) == lane and float(f["at"]) >= from and float(f["at"]) <= to:
			return true
	return false


## The swarm boss (GDD §10) will draw hundreds of these: one mesh, one shared material per zone
## variant, and a MultiMesh material that reads per-creature state from instance custom data.
func _test_body() -> void:
	var mesh: ArrayMesh = ScreechModel.mesh()
	check(mesh != null and mesh.get_surface_count() == 1, "the body is one mesh with one surface")
	check(mesh.get_faces().size() / 3 < 1500, "and low-poly (%d triangles)" % (mesh.get_faces().size() / 3))
	check(ScreechModel.material(&"city") == ScreechModel.material(&"city"), "every screech shares its variant's material")
	check(ScreechModel.material(&"city") != ScreechModel.material(&"scavenger"), "the zone variant only weathers it")
	var mm: ShaderMaterial = ScreechModel.multimesh_material(&"scavenger")
	check(bool(mm.get_shader_parameter(&"use_custom")) and mm.shader == ScreechModel.material(&"scavenger").shader,
		"a MultiMesh copy of the material reads per-creature state from custom data")

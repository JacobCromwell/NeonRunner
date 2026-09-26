extends TestSuite
## The Octodog (GDD §9.4) in full RunWorlds on real physics: the wind-up and lunge, dodging by lane
## switch or jump at 3, 5 and 6 lanes (edges included), its charges, the straight line, gap bait,
## the grab, weapons, protection, the doghouse, and its generator patterns and rules.

var sim: RunSim
var t: OctodogTuning


func run() -> void:
	sim = RunSim.new(tree, tuning)
	t = EnemyDirector.tuning_for("octodog") as OctodogTuning
	check(t != null, "data/enemies/octodog.tres is an OctodogTuning")
	if t == null:
		return
	await _test_lunge_hits_and_dodges()
	await _test_jump_dodge()
	await _test_straight_line()
	await _test_charges_and_give_up()
	await _test_gap_bait()
	await _test_grab_and_claws()
	await _test_weapons()
	await _test_protection_and_dash()
	await _test_passing_is_harmless()
	await _test_gives_up_before_ceiling()
	await _test_doghouse()
	_test_generator()


# --- Helpers ------------------------------------------------------------------------------------

func _loadout(items: Dictionary) -> Loadout:
	var l := Loadout.new()
	for k: String in items:
		if k in ["armor", "shield", "grapple", "revive"]:
			l.charges[StringName(k)] = items[k]
		else:
			l.tiers[StringName(k)] = items[k]
	return l


## A world with the player in `player_lane` and one dog `ahead` metres away in `dog_lane`.
func _world(lanes: int, player_lane: int, dog_lane: int, params: Dictionary = {}, loadout: Loadout = null,
		ahead: float = 70.0, length: float = 900.0) -> Array:
	var w: RunWorld = sim.build_world(RunSim.layout(lanes, length), loadout)
	w.player.setup(tuning, w.geo, player_lane)
	var p: Dictionary = {"doghouse": false, "charges": 1}
	p.merge(params, true)
	var dog := w.director.spawn({"type": "octodog", "at": ahead, "lane": dog_lane, "side": 0, "seed": 11,
		"params": p}) as Octodog
	await tree.physics_frame
	w.player.running = true
	return [w, dog]


## Steps physics frames until `cond` is true (true) or `seconds` pass (false).
func _until(cond: Callable, seconds: float) -> bool:
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		if cond.call():
			return true
		await tree.physics_frame
	return cond.call()


## The dog with this instance id, or null once it's freed (predicates never hold a freed object).
func _dog(id: int) -> Octodog:
	var o: Object = instance_from_id(id)
	return o as Octodog if is_instance_valid(o) else null


func _phase_is(id: int, phase: Octodog.Phase) -> bool:
	var dog: Octodog = _dog(id)
	return dog != null and dog.alive and dog.phase == phase


func _lunge_over(w: RunWorld, id: int) -> bool:
	var dog: Octodog = _dog(id)
	return not w.player.alive or dog == null or not dog.alive \
		or (dog.phase != Octodog.Phase.WINDUP and dog.phase != Octodog.Phase.LUNGE and dog.phase != Octodog.Phase.IDLE)


## Relative distance from the player to the dog (m), or -INF once it's gone.
func _rel(w: RunWorld, id: int) -> float:
	var dog: Octodog = _dog(id)
	return -dog.global_position.z - w.player.distance if dog != null else -INF


func _gone(dog: Variant) -> bool:
	return not is_instance_valid(dog) or not (dog as Octodog).alive


# --- Lunge fairness ---------------------------------------------------------------------------

## GDD §9.4: the lunge hurts a player who stays in its line and misses one who switches lanes any
## time after the wind-up starts, at every lane count, from the edges too, head-on or diagonal.
func _test_lunge_hits_and_dodges() -> void:
	var switch_after: Array[float] = [0.15, t.windup_time(0.0)]
	for lanes: int in [3, 5, 6]:
		for player_lane: int in [0, lanes / 2, lanes - 1]:
			for dog_offset: int in [0, -1, 1]:
				var dog_lane: int = player_lane + dog_offset
				if dog_lane < 0 or dog_lane >= lanes:
					continue
				var tag: String = "lanes=%d player=%d dog=%d" % [lanes, player_lane, dog_lane]
				# Staying in line is hit.
				var made: Array = await _world(lanes, player_lane, dog_lane)
				var w: RunWorld = made[0]
				var dog: Octodog = made[1]
				var wound: bool = await _until(_phase_is.bind(dog.get_instance_id(), Octodog.Phase.WINDUP), 4.0)
				check(wound, "the dog winds up " + tag)
				check(dog.target_lane == player_lane, "it aims at the player's lane " + tag)
				await _until(_lunge_over.bind(w, dog.get_instance_id()), 4.0)
				check(not w.player.alive and w.player.last_event.contains("Octodog"),
					"staying in its line is hit %s (%s)" % [tag, w.player.last_event])
				check(is_instance_valid(dog) and dog.history.size() >= 2 and dog.history[0][0] == "windup"
					and dog.history[1][0] == "lunge",
					"the wind-up comes before the lunge " + tag)
				await sim.free_world(w)
				# Switching lanes after the wind-up starts (a quick or a last-moment reaction) dodges.
				var dirs: Array[StringName] = []
				if player_lane > 0:
					dirs.append(&"move_left")
				if player_lane < lanes - 1:
					dirs.append(&"move_right")
				for dir: StringName in dirs:
					for delay: float in switch_after:
						made = await _world(lanes, player_lane, dog_lane)
						w = made[0]
						dog = made[1]
						await _until(_phase_is.bind(dog.get_instance_id(), Octodog.Phase.WINDUP), 4.0)
						await _until(func() -> bool: return false, delay)
						w.player.press(dir)
						await _until(_lunge_over.bind(w, dog.get_instance_id()), 4.0)
						check(w.player.alive, "a %s %.2f s into the wind-up dodges %s (%s)" % [dir, delay, tag,
							w.player.last_event])
						check(is_instance_valid(dog) and dog.charges_done == 1, "and the lunge went past " + tag)
						await sim.free_world(w)


## GDD §9.4: jumping over it dodges too (the leap is low), timed like any jump; jumping too early
## lands in front of it.
func _test_jump_dodge() -> void:
	for lanes: int in [3, 5, 6]:
		for case: Vector2i in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(lanes / 2, 0), Vector2i(lanes - 1, -1)]:
			var dog_offset: int = case.y
			var made: Array = await _world(lanes, case.x, case.x + dog_offset)
			var w: RunWorld = made[0]
			var dog: Octodog = made[1]
			await _until(_phase_is.bind(dog.get_instance_id(), Octodog.Phase.LUNGE), 4.0)
			var dog_id: int = dog.get_instance_id()
			await _until(func() -> bool: return _rel(w, dog_id) < 8.0, 2.0)
			w.player.press(&"jump")
			await _until(_lunge_over.bind(w, dog.get_instance_id()), 3.0)
			check(w.player.alive, "jumping over a lunge dodges it (lanes=%d player %d dog offset %d, %s)" % [lanes,
				case.x, dog_offset, w.player.last_event])
			await sim.free_world(w)
	var made2: Array = await _world(5, 2, 2)
	var w2: RunWorld = made2[0]
	var dog2: Octodog = made2[1]
	await _until(_phase_is.bind(dog2.get_instance_id(), Octodog.Phase.WINDUP), 4.0)
	w2.player.press(&"jump")
	await _until(_lunge_over.bind(w2, dog2.get_instance_id()), 4.0)
	check(not w2.player.alive, "a jump at the very start of the wind-up lands before the lunge arrives")
	await sim.free_world(w2)


## GDD §9.4: the lunge is a straight line it can't change mid-leap: the aim is locked at the wind-up,
## and a lane switch during the lunge doesn't bend it.
func _test_straight_line() -> void:
	var made: Array = await _world(5, 2, 3)
	var w: RunWorld = made[0]
	var dog: Octodog = made[1]
	await _until(_phase_is.bind(dog.get_instance_id(), Octodog.Phase.WINDUP), 4.0)
	var aimed: int = dog.target_lane
	w.player.press(&"move_left")
	await _until(_phase_is.bind(dog.get_instance_id(), Octodog.Phase.LUNGE), 2.0)
	var v0: Vector2 = dog.lunge_velocity
	var start := Vector2(dog.position.x, dog.position.z)
	var straight: bool = true
	var frames: int = 0
	w.player.press(&"move_right")
	while _phase_is(dog.get_instance_id(), Octodog.Phase.LUNGE) and frames < 120:
		await tree.physics_frame
		frames += 1
		if not _phase_is(dog.get_instance_id(), Octodog.Phase.LUNGE):
			break
		var p := Vector2(dog.position.x, dog.position.z) - start
		var dir := Vector2(v0.x, -v0.y).normalized()
		var off_line: float = absf(p.cross(dir))
		straight = straight and dog.lunge_velocity == v0 and off_line < 0.01
	check(aimed == 2, "the aim is the player's lane when the wind-up starts (%d)" % aimed)
	check(frames > 10 and straight, "the lunge keeps one straight line while the player moves (%d frames)" % frames)
	check(is_equal_approx(v0.x, (w.geo.lane_x(2) - w.geo.lane_x(3)) / t.time_to_meet(tuning.run_speed, 0.0))
		or absf(v0.x - (w.geo.lane_x(2) - w.geo.lane_x(3)) / t.time_to_meet(tuning.run_speed, 0.0)) < 0.6,
		"it cuts diagonally toward the aimed lane (vx %.2f)" % v0.x)
	await sim.free_world(w)


## GDD §9.4: 2–3 charges early, up to 4 at the maximum, then it gives up (and is left behind).
func _test_charges_and_give_up() -> void:
	check(t.charges_range(0.0) == Vector2i(2, 3), "2–3 charges early (%s)" % t.charges_range(0.0))
	check(t.charges_range(1.0) == Vector2i(3, 4), "up to 4 at the maximum (%s)" % t.charges_range(1.0))
	var w: RunWorld = sim.build_world(RunSim.layout(3, 400))
	var seen := {}
	for s: int in 40:
		var d := w.director.spawn({"type": "octodog", "at": 300.0, "lane": 1, "side": 0, "seed": s,
			"params": {"doghouse": false}}) as Octodog
		seen[d.charges] = true
		check(d.charges >= 2 and d.charges <= 3, "an unplanned early dog picks 2–3 charges (%d)" % d.charges)
		d.retire()
	check(seen.has(2) and seen.has(3), "both 2 and 3 happen")
	await sim.free_world(w)

	for lanes: int in [3, 6]:
		var made: Array = await _world(lanes, 0, 0, {"charges": 4}, null, 70.0, 1500.0)
		w = made[0]
		var dog: Octodog = made[1]
		var id: int = dog.get_instance_id()
		var dodges: int = 0
		var dir: StringName = &"move_right"
		var windups_seen: int = 0
		for i: int in 6:
			var wound: bool = await _until(func() -> bool:
				return _phase_is(id, Octodog.Phase.WINDUP) and _dog(id).charges_done == i, 9.0)
			if not wound:
				break
			windups_seen += 1
			await _until(func() -> bool: return false, 0.2)
			# Dodge toward the middle, alternating.
			dir = &"move_right" if w.player.lane < lanes / 2 or (w.player.lane == lanes / 2 and i % 2 == 0) else &"move_left"
			w.player.press(dir)
			await _until(func() -> bool: return not _phase_is(id, Octodog.Phase.WINDUP) and not _phase_is(id, Octodog.Phase.LUNGE), 3.0)
			if w.player.alive:
				dodges += 1
			if dodges == 4:
				break
		check(w.player.alive and dodges == 4 and windups_seen == 4,
			"four charges, each dodged (lanes=%d: %d wind-ups, %d dodges, %s)" % [lanes, windups_seen, dodges, w.player.last_event])
		check(is_instance_valid(dog) and dog.phase == Octodog.Phase.GIVE_UP and dog.charges_done == 4,
			"after its last charge it gives up (lanes=%d)" % lanes)
		await _until(func() -> bool: return _dog(id) == null or _dog(id).is_queued_for_deletion(), 5.0)
		check(_dog(id) == null or _dog(id).is_queued_for_deletion(), "and is left behind (retired)")
		await sim.free_world(w)


## GDD §9.4: a lunge that carries it over a hole in its lane drops it in: a kill and a skill bonus.
## A diagonal lunge that leaves the lane before the hole clears it.
func _test_gap_bait() -> void:
	var gap_len: float = 0.4 * tuning.jump_distance(tuning.run_speed)
	var at: float = 80.0
	for diagonal: bool in [false, true]:
		var layout := RunSim.layout(5, 600)
		layout.gaps.append({"lane": 2, "start": at - t.bait_distance - gap_len, "end": at - t.bait_distance})
		var w: RunWorld = sim.build_world(layout)
		# Lined up with the dog (head-on), or one lane over (it cuts diagonally).
		w.player.setup(tuning, w.geo, 1 if diagonal else 2)
		var dog := w.director.spawn({"type": "octodog", "at": at, "lane": 2, "side": 0, "seed": 4,
			"params": {"doghouse": false, "charges": 1}}) as Octodog
		await tree.physics_frame
		w.player.running = true
		await _until(_phase_is.bind(dog.get_instance_id(), Octodog.Phase.WINDUP), 5.0)
		# Get out of the line (and away from the hole's lane) after the wind-up starts.
		await _until(func() -> bool: return false, 0.2)
		w.player.press(&"move_right" if not diagonal else &"move_left")
		var fell := [false]
		var id: int = dog.get_instance_id()
		dog.defeated.connect(func(_e: Enemy, cause: StringName) -> void: fell[0] = cause == &"gap")
		await _until(func() -> bool: return _dog(id) == null or not _dog(id).alive or _dog(id).charges_done > 0, 3.0)
		if not diagonal:
			check(fell[0], "a head-on lunge over the hole drops it in")
			check(w.score.bonuses.has(&"gap_bait") and int(w.score.bonuses[&"gap_bait"]) == t.gap_bait_bonus,
				"baiting it into a gap scores the skill bonus (%s)" % w.score.bonuses)
			check(w.score.kills == 1, "and counts as a kill")
		else:
			check(not fell[0] and is_instance_valid(dog) and dog.alive,
				"a diagonal lunge that leaves the lane before the hole clears it")
		check(w.player.alive, "the player is fine (%s)" % w.player.last_event)
		await sim.free_world(w)


## GDD §9.4: landing on it without claws, the tentacles grab (it hurts; armor blocks it as an attack);
## with claws the landing kills it (claws beat tentacles).
func _test_grab_and_claws() -> void:
	for case: String in ["none", "armor", "claws"]:
		var items: Dictionary = {}
		if case == "armor":
			items = {"armor": 1}
		elif case == "claws":
			items = {"claws": 1}
		var w: RunWorld = sim.build_world(RunSim.layout(3, 400), _loadout(items))
		await tree.physics_frame
		# Stand a dog 1 m ahead (it's winding up: standing still) and drop the player onto its back.
		var dog := w.director.spawn({"type": "octodog", "at": 1.2, "lane": 1, "side": 0, "seed": 2,
			"params": {"doghouse": false, "charges": 1}}) as Octodog
		w.player.running = true
		w.player.grounded = false
		w.player.h = 1.02
		w.player.vh = -3.0
		var events: Array = []
		var id: int = dog.get_instance_id()
		w.player.movement_event.connect(func(k: StringName) -> void: events.append(k))
		await _until(func() -> bool: return (not w.player.alive or _dog(id) == null or not _dog(id).alive
			or events.has(&"armor_break")), 0.5)
		match case:
			"none":
				check(not w.player.alive and w.player.last_event.contains("Octodog"),
					"landing on it without claws, the tentacles grab (%s)" % w.player.last_event)
			"armor":
				check(w.player.alive and events.has(&"armor_break"), "armor blocks the grab (an enemy attack)")
			"claws":
				check(w.player.alive and _gone(dog) and w.score.kills == 1, "with claws, landing on it kills it")
		await sim.free_world(w)


## GDD §8/§9.4: 5 laser tier 1 shots; auto-fire only picks it once it's in view.
func _test_weapons() -> void:
	var w: RunWorld = sim.build_world(RunSim.layout(3, 400))
	await tree.physics_frame
	var far := w.director.spawn({"type": "octodog", "at": 90.0, "lane": 0, "side": 0, "seed": 1,
		"params": {"doghouse": false}}) as Octodog
	var dog := w.director.spawn({"type": "octodog", "at": 40.0, "lane": 1, "side": 0, "seed": 1,
		"params": {"doghouse": false}}) as Octodog
	check(not far.targetable() and dog.targetable(), "auto-fire only targets a dog in view (within %.0f m)" % t.appear_distance)
	check(is_equal_approx(dog.max_health, 5.0), "health: 5 laser tier 1 shots (%.1f)" % dog.max_health)
	var laser: float = App.powerup_tuning.weapon_damage[0] if has_app() else 1.0
	for i: int in 5:
		w.projectiles.fire_player(Vector3(w.geo.lane_x(1), 0.65, -8.0), Vector3(0.0, 0.0, -90.0), laser)
		await _until(func() -> bool: return w.projectiles.live_count() == 0, 1.0)
		if i < 4:
			check(not _gone(dog) and is_equal_approx(dog.health, 5.0 - (i + 1) * laser),
				"alive after %d shots" % [i + 1])
	check(_gone(dog) and w.score.kills == 1, "the fifth laser tier 1 shot kills it")
	await sim.free_world(w)


func has_app() -> bool:
	return tree.root.get_node_or_null(^"App") != null


## GDD §9.4: armor and the shield each block one lunge; the dash kills it; claws kill a lunging dog.
func _test_protection_and_dash() -> void:
	for case: String in ["armor", "shield", "claws", "dash"]:
		var items: Dictionary = {}
		if case == "armor" or case == "shield":
			items = {case: 1}
		elif case == "claws":
			items = {"claws": 1}
		var made: Array = await _world(3, 1, 1, {}, _loadout(items))
		var w: RunWorld = made[0]
		var dog: Octodog = made[1]
		var events: Array = []
		var dog_id: int = dog.get_instance_id()
		w.player.movement_event.connect(func(k: StringName) -> void: events.append(k))
		await _until(_phase_is.bind(dog_id, Octodog.Phase.LUNGE), 4.0)
		if case == "dash":
			await _until(func() -> bool: return _rel(w, dog_id) < 6.0, 2.0)
			w.player.start_dash(0.6, 8.0)
		await _until(_lunge_over.bind(w, dog_id), 3.0)
		match case:
			"armor", "shield":
				check(w.player.alive and events.has(StringName(case + "_break")), "%s blocks one lunge" % case)
			"claws", "dash":
				check(w.player.alive and _gone(dog) and w.score.kills == 1,
					"%s kills a lunging dog (%s)" % [case, w.player.last_event])
		await sim.free_world(w)


## After a lunge it runs past the player in another lane, harmless until it's ahead again: moving
## into its lane as it passes never hurts (no attack from behind).
func _test_passing_is_harmless() -> void:
	for lanes: int in [3, 5]:
		var made: Array = await _world(lanes, 1, 1, {"charges": 2}, null, 70.0, 1200.0)
		var w: RunWorld = made[0]
		var dog: Octodog = made[1]
		await _until(_phase_is.bind(dog.get_instance_id(), Octodog.Phase.WINDUP), 4.0)
		w.player.press(&"move_left")
		await _until(_phase_is.bind(dog.get_instance_id(), Octodog.Phase.SPRINT), 3.0)
		# Step back into its lane while it overtakes.
		var id: int = dog.get_instance_id()
		await _until(func() -> bool: return _rel(w, id) > -1.0, 2.0)
		var dog_lane: int = int(round((dog.global_position.x - w.geo.lane_x(0)) / w.geo.lane_width))
		w.player.press(&"move_right" if dog_lane > w.player.lane else &"move_left")
		await _until(_phase_is.bind(dog.get_instance_id(), Octodog.Phase.PACE), 3.0)
		check(w.player.alive, "its overtake never hurts (lanes=%d, %s)" % [lanes, w.player.last_event])
		check(dog.global_position.z < w.player.position.z - 20.0, "it's ahead again, about halfway up the screen")
		await sim.free_world(w)


## GDD §3: floor enemies never go under a ceiling section. Unplanned, a dog gives up rather than
## charge again with a ceiling coming.
func _test_gives_up_before_ceiling() -> void:
	var layout := RunSim.layout(3, 800)
	layout.hulls.append({"start": 110.0, "end": 180.0})
	layout.pads.append({"lane": 1, "at": 113.0})
	var w: RunWorld = sim.build_world(layout)
	w.player.setup(tuning, w.geo, 1)
	var dog := w.director.spawn({"type": "octodog", "at": 60.0, "lane": 1, "side": 0, "seed": 5,
		"params": {"doghouse": false, "charges": 3}}) as Octodog
	await tree.physics_frame
	w.player.running = true
	await _until(_phase_is.bind(dog.get_instance_id(), Octodog.Phase.WINDUP), 4.0)
	w.player.press(&"move_left")
	var id: int = dog.get_instance_id()
	await _until(func() -> bool: return (_dog(id) != null and _dog(id).charges_done >= 1
		and _dog(id).phase != Octodog.Phase.LUNGE), 3.0)
	check(is_instance_valid(dog) and dog.phase == Octodog.Phase.GIVE_UP,
		"with a ceiling section ahead it gives up after 1 charge")
	await sim.free_world(w)


## GDD §9.4: a doghouse warns of the first appearances only. It hides the dog until it bursts out;
## gameplay is the same with or without it. DESIGN-TBD: the first few Octodogs of the profile.
func _test_doghouse() -> void:
	var made: Array = await _world(3, 1, 1, {"doghouse": true}, null, 120.0)
	var w: RunWorld = made[0]
	var dog: Octodog = made[1]
	check(dog.in_doghouse and dog.get_node_or_null(^"Doghouse") != null, "the doghouse hides the dog")
	check(not dog.targetable(), "a dog in its doghouse isn't a target")
	var id: int = dog.get_instance_id()
	await _until(func() -> bool: return _dog(id) != null and not _dog(id).in_doghouse, 5.0)
	var rel: float = -dog.global_position.z - w.player.distance
	check(not dog.in_doghouse and rel > t.stop_distance(tuning.run_speed, 0.0),
		"it bursts out before its wind-up (%.1f m away)" % rel)
	await tree.process_frame
	check(dog.get_node_or_null(^"Doghouse") == null, "and the doghouse is gone")
	await sim.free_world(w)

	if not has_app():
		return
	var saved: Profile = App.profile
	App.profile = Profile.new()
	var shown: Array[bool] = []
	for i: int in t.doghouse_appearances + 1:
		var w2: RunWorld = sim.build_world(RunSim.layout(3, 400))
		w2.player.setup(tuning, w2.geo, 1)
		var d := w2.director.spawn({"type": "octodog", "at": 70.0, "lane": 1, "side": 0, "seed": i,
			"params": {"charges": 1}}) as Octodog
		shown.append(d.in_doghouse)
		await tree.physics_frame
		w2.player.running = true
		var did: int = d.get_instance_id()
		await _until(func() -> bool: return _dog(did) == null or not _dog(did).in_doghouse, 3.0)
		await sim.free_world(w2)
	var expected: Array[bool] = []
	for i: int in t.doghouse_appearances:
		expected.append(true)
	expected.append(false)
	check(shown == expected, "the first %d Octodogs of a profile come with a doghouse, later ones don't (%s)"
		% [t.doghouse_appearances, shown])
	App.profile = saved


# --- Generator --------------------------------------------------------------------------------

func _test_generator() -> void:
	var base: LevelConfig = load(LEVEL_PATH) as LevelConfig
	var dogs_total: int = 0
	var bait_total: int = 0
	var counts := {}
	for lanes: int in [3, 5, 6]:
		for scaling: float in [0.0, 1.0]:
			for difficulty: float in [0.2, 0.7]:
				for level_seed: int in range(1, 13):
					var config: LevelConfig = base.duplicate() as LevelConfig
					config.lane_count = lanes
					config.difficulty = difficulty
					config.enemy_scaling = scaling
					config.level_seed = level_seed
					config.features = PackedStringArray(["ramps", "ceilings", "pulsing", "octodog"])
					var tag: String = "lanes=%d scaling=%.0f diff=%.1f seed=%d" % [lanes, scaling, difficulty, level_seed]
					var patterns: Array = LevelGenerator.load_for(config)
					var gen := LevelGenerator.new()
					var a: LevelLayout = gen.generate(config, tuning, patterns)
					check(gen.warnings.is_empty(), "octodog patterns generate without warnings " + tag)
					var b: LevelLayout = LevelGenerator.new().generate(config, tuning, patterns)
					check(JSON.stringify(a.to_dict()) == JSON.stringify(b.to_dict()), "same seed, same level " + tag)
					var n: int = _check_dogs(a, config, tag)
					dogs_total += n
					for e: Dictionary in a.enemies:
						if e["type"] == "octodog":
							counts[int(e["params"]["charges"])] = true
							if e["params"].get("bait", false):
								bait_total += 1
	check(dogs_total > 30, "levels with the feature get Octodogs (%d)" % dogs_total)
	check(bait_total > 5, "some are placed to be baited into a gap (%d)" % bait_total)
	check(counts.has(2) and counts.has(3) and counts.has(4) and not counts.has(5), "2 to 4 charges (%s)" % counts)

	# Without the feature, none (GDD §6: one new thing at a time).
	var plain: LevelConfig = base.duplicate() as LevelConfig
	var layout: LevelLayout = LevelGenerator.new().generate(plain, tuning, LevelGenerator.load_for(plain))
	var none: bool = true
	for e: Dictionary in layout.enemies:
		none = none and e["type"] != "octodog"
	check(none, "no Octodogs without the feature")


## Each planned dog: charges within the scaled range, every charge's stretch clear, no ceiling
## anywhere along its run, one dog at a time, bait dogs just past their hole. Returns the count.
func _check_dogs(layout: LevelLayout, config: LevelConfig, tag: String) -> int:
	var speed: float = tuning.run_speed
	var s: float = config.enemy_scaling
	var stop: float = t.stop_distance(speed, s)
	var window: float = t.window_length(speed, s)
	var r: Vector2i = t.charges_range(s)
	var count: int = 0
	var busy_until: float = -INF
	var dogs: Array[Dictionary] = []
	for e: Dictionary in layout.enemies:
		if e["type"] == "octodog":
			dogs.append(e)
	for e: Dictionary in dogs:
		count += 1
		var p: Dictionary = e["params"]
		var at: Array = p.get("charge_at", [])
		var charges: int = int(p.get("charges", 0))
		check(charges >= 2 and charges <= r.y and at.size() == charges, "planned charges %d in 2..%d %s" % [charges, r.y, tag])
		check(int(e["lane"]) >= 0 and int(e["lane"]) < layout.lane_count, "dog lane in range " + tag)
		check(not layout.gapped_between(int(e["lane"]), float(e["at"]) - 1.0, float(e["at"]) + 1.0),
			"a dog stands on solid floor " + tag)
		if at.is_empty():
			continue
		check(float(at[0]) > busy_until, "one Octodog at a time " + tag)
		for i: int in at.size():
			var a: float = float(at[i])
			check(Octodog.window_clear(layout, a, a + window), "charge %d at %.0f is never stacked with an obstacle %s" % [i, a, tag])
			if i > 0:
				check(a - float(at[i - 1]) >= t.cycle_distance(speed, s) - 0.01, "charges are spaced out " + tag)
		check(not Octodog.ceiling_between(layout, float(at[0]) - 6.0, float(at[-1]) + stop + 2.0),
			"its whole run stays off ceiling sections " + tag)
		busy_until = float(at[-1]) + window + stop
		if p.get("bait", false):
			var baited: bool = false
			for g: Dictionary in layout.gaps:
				if int(g["lane"]) == int(e["lane"]) and absf(float(g["end"]) + t.bait_distance - float(e["at"])) < 0.01:
					baited = true
			check(baited, "a bait dog stands %.1f m past the hole in its lane %s" % [t.bait_distance, tag])
	return count

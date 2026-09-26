extends TestSuite
## The heli drone (GDD §9.6) in full RunWorlds on real physics, and its generator rules.

const DroneScript := preload("res://scripts/enemies/drone.gd")

var sim: RunSim


func run() -> void:
	sim = RunSim.new(tree, tuning)
	await _test_swoop_and_follow()
	await _test_barrage()
	await _test_zigzag_and_lane_counts()
	await _test_protection()
	await _test_wall_and_ceiling()
	await _test_pad()
	await _test_weapons()
	_test_barrage_numbers()


# --- Helpers -------------------------------------------------------------------------------------

func _loadout(items: Dictionary) -> Loadout:
	var l := Loadout.new()
	for k: String in items:
		if k in ["armor", "shield", "grapple", "revive"]:
			l.charges[StringName(k)] = items[k]
		else:
			l.tiers[StringName(k)] = items[k]
	return l


func _drone(w: RunWorld, at: float, slot: int = 0, seed_value: int = 7) -> DroneScript:
	return w.director.spawn({"type": "drone", "at": at, "lane": 1, "side": 0, "seed": seed_value,
		"params": {"slot": slot}}) as DroneScript


## Runs the world one physics frame at a time (starting the player if needed) until `done` returns
## true or `seconds` pass. Returns whether `done` became true.
func _run_until(w: RunWorld, seconds: float, done: Callable) -> bool:
	if not w.player.running:
		await tree.physics_frame
		w.player.running = true
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		if done.call():
			return true
		await tree.physics_frame
	return done.call()


func _wait(w: RunWorld, seconds: float) -> void:
	await _run_until(w, seconds, func() -> bool: return false)


## The cause of the player's death in this world ("" while alive).
func _death_cause(w: RunWorld) -> Array:
	var cause: Array = [""]
	w.player.died.connect(func(c: String) -> void: cause[0] = c)
	return cause


# --- Tests ---------------------------------------------------------------------------------------

func _test_swoop_and_follow() -> void:
	var w: RunWorld = sim.build_world(RunSim.layout(3, 600.0))
	var d := _drone(w, 30.0)
	check(d != null and d.state == DroneScript.State.WAITING and not d.visible and not d.targetable(),
		"a drone waits out of sight (and out of weapons' reach) until the player reaches its spot")
	var swooped: bool = await _run_until(w, 3.0, func() -> bool: return d.state == DroneScript.State.SWOOP)
	check(swooped and w.player.distance >= 30.0 and w.player.distance < 31.0,
		"it swoops in when the player reaches its spot (%.1f m)" % w.player.distance)
	check(d.rel_ahead > 40.0 and d.targetable(), "from the distance (%.0f m ahead)" % d.rel_ahead)
	var settled: bool = await _run_until(w, 3.0, func() -> bool: return d.state == DroneScript.State.FOLLOW)
	check(settled and absf(d.rel_x - w.geo.lane_x(1)) < 0.3 and absf(d.rel_ahead - d.tune.hover_ahead) < 0.6
		and d.rel_y < w.tuning.ceiling_height - 1.0,
		"it settles ahead of the player over their lane, under the ceiling (x %.2f, %.1f m ahead, %.1f m up)"
		% [d.rel_x, d.rel_ahead, d.rel_y])
	w.player.press(&"move_left")
	await _wait(w, 0.8)
	check(d.state == DroneScript.State.FOLLOW and absf(d.rel_x - w.geo.lane_x(0)) < 0.3,
		"it follows the player to another lane (x %.2f)" % d.rel_x)
	await _wait(w, 25.0)
	check(is_instance_valid(d) and d.alive and w.director.active.has(d), "it stays in play (GDD §9.6: until destroyed or the level ends)")
	await sim.free_world(w)


func _test_barrage() -> void:
	# Staying in the lane: the barrage hits.
	var w: RunWorld = sim.build_world(RunSim.layout(3, 600.0))
	var cause: Array = _death_cause(w)
	var d := _drone(w, 20.0)
	var wound: bool = await _run_until(w, 8.0, func() -> bool: return d.state == DroneScript.State.WINDUP)
	check(wound and w.player.alive, "it winds up before firing (nothing is fired during the swoop)")
	check(w.projectiles.live_count() == 0, "no bullet flies before the wind-up is over")
	await _run_until(w, 4.0, func() -> bool: return not w.player.alive)
	check(not w.player.alive and cause[0] == DroneScript.SHOT_NAME,
		"a player who stays in the lane during a barrage is hit (%s)" % cause[0])
	await sim.free_world(w)

	# Switching lanes once it starts firing dodges the whole barrage; the drone holds still meanwhile
	# and moves again afterwards.
	w = sim.build_world(RunSim.layout(3, 600.0))
	d = _drone(w, 20.0)
	await _run_until(w, 8.0, func() -> bool: return d.state == DroneScript.State.FIRE)
	var x_fire: float = d.rel_x
	var ahead_fire: float = d.rel_ahead
	w.player.press(&"move_right")
	var moved: Array = [false]
	await _run_until(w, 3.0, func() -> bool:
		if d.state == DroneScript.State.FIRE and (absf(d.rel_x - x_fire) > 0.01 or absf(d.rel_ahead - ahead_fire) > 0.01):
			moved[0] = true
		return d.state == DroneScript.State.FOLLOW)
	check(w.player.alive and d.bullets_fired >= d.tune.bullets_early,
		"a player who switches lanes once the barrage starts isn't hit (%d bullets)" % d.bullets_fired)
	check(not moved[0], "the drone is stationary while firing")
	await _wait(w, 1.0)
	check(absf(d.rel_x - w.geo.lane_x(2)) < 0.3, "then it moves again, following the player (x %.2f)" % d.rel_x)
	await sim.free_world(w)

	# During the wind-up the aim tracks the player: switching early and staying there is hit.
	w = sim.build_world(RunSim.layout(3, 600.0))
	cause = _death_cause(w)
	d = _drone(w, 20.0)
	await _run_until(w, 8.0, func() -> bool: return d.state == DroneScript.State.WINDUP)
	w.player.press(&"move_left")
	await _run_until(w, 4.0, func() -> bool: return not w.player.alive)
	check(not w.player.alive and cause[0] == DroneScript.SHOT_NAME and w.player.lane == 0,
		"the wind-up's aim follows a player who moves before it fires (%s)" % cause[0])
	await sim.free_world(w)


## GDD §9.6: enough spacing between bullets to zigzag through; dodgeable at every lane count.
func _test_zigzag_and_lane_counts() -> void:
	var w: RunWorld = sim.build_world(RunSim.layout(3, 600.0))
	var d := _drone(w, 20.0)
	await _run_until(w, 8.0, func() -> bool: return d.state == DroneScript.State.FIRE)
	w.player.press(&"move_left")  # out of the stream (lane 1) into lane 0
	await _wait(w, 0.2)
	# Wait until a bullet has just passed the player, then cross the stream to lane 2 in one go.
	var passed: Array = [0]
	var crossed: bool = await _run_until(w, 2.0, func() -> bool:
		var n: int = 0
		for s: Projectile in w.projectiles.live_shots():
			if not s.friendly and s.position.z > w.player.position.z + 0.5:
				n += 1
		if n > passed[0] and passed[0] > 0:
			return true
		passed[0] = maxi(passed[0], n)
		return false)
	w.player.press(&"move_right")
	w.player.press(&"move_right")
	await _run_until(w, 2.5, func() -> bool: return d.state == DroneScript.State.FOLLOW)
	check(crossed and w.player.alive and w.player.lane == 2,
		"a player can zigzag back through the stream between two bullets (lane %d)" % w.player.lane)
	await sim.free_world(w)

	for lanes: int in [3, 5, 6]:
		for start: int in [0, lanes / 2, lanes - 1]:
			w = sim.build_world(RunSim.layout(lanes, 600.0))
			w.player.setup(tuning, w.geo, start)
			d = _drone(w, 20.0)
			await _run_until(w, 8.0, func() -> bool: return d.state == DroneScript.State.FIRE)
			w.player.press(&"move_right" if start < lanes - 1 else &"move_left")
			await _run_until(w, 3.0, func() -> bool: return d.state == DroneScript.State.FOLLOW)
			var bullets_ok: bool = d.bullets_fired > 0
			check(w.player.alive and bullets_ok,
				"%d lanes, from lane %d: one lane switch dodges a barrage" % [lanes, start])
			await sim.free_world(w)


## GDD §9.6: armor or a shield plus the invulnerability window protects through a barrage.
func _test_protection() -> void:
	for item: String in ["armor", "shield"]:
		var w: RunWorld = sim.build_world(RunSim.layout(3, 600.0), _loadout({item: 1}))
		var d := _drone(w, 20.0)
		await _run_until(w, 8.0, func() -> bool: return d.state == DroneScript.State.FIRE)
		await _run_until(w, 3.0, func() -> bool: return d.state == DroneScript.State.FOLLOW)
		await _wait(w, 0.6)
		check(w.player.alive and w.score.blocked == 1 and d.bullets_fired >= 6,
			"%s protects through a whole barrage (blocked %d, %d bullets)" % [item, w.score.blocked, d.bullets_fired])
		await sim.free_world(w)


func _test_wall_and_ceiling() -> void:
	# A player who is on a wall when the barrage starts is fired at there, and hit if they stay.
	var w: RunWorld = sim.build_world(RunSim.layout(3, 600.0))
	w.player.setup(tuning, w.geo, 2)
	var cause: Array = _death_cause(w)
	var d := _drone(w, 20.0)
	await _run_until(w, 8.0, func() -> bool: return d.state == DroneScript.State.WINDUP)
	await _wait(w, d.tune.windup_early - 0.45)
	w.player.press(&"move_right")
	var on_wall: bool = await _run_until(w, 1.0, func() -> bool: return d.state == DroneScript.State.FIRE)
	check(on_wall and w.player.surface == Player.Surface.WALL, "the player is on the wall as the barrage starts")
	await _run_until(w, 3.0, func() -> bool: return not w.player.alive)
	check(not w.player.alive and cause[0] == DroneScript.SHOT_NAME,
		"the drone keeps firing at a player on a wall (%s)" % cause[0])
	await sim.free_world(w)

	# ... and a wall jump out of it dodges.
	w = sim.build_world(RunSim.layout(3, 600.0))
	w.player.setup(tuning, w.geo, 2)
	d = _drone(w, 20.0)
	await _run_until(w, 8.0, func() -> bool: return d.state == DroneScript.State.WINDUP)
	await _wait(w, d.tune.windup_early - 0.45)
	w.player.press(&"move_right")
	await _run_until(w, 1.0, func() -> bool: return d.state == DroneScript.State.FIRE)
	w.player.press(&"jump")
	await _run_until(w, 3.0, func() -> bool: return d.state == DroneScript.State.FOLLOW)
	check(w.player.alive, "a wall jump out of the stream dodges it")
	await sim.free_world(w)

	# It waits while the player is on the ceiling, then attacks once they drop back down.
	var hull := RunSim.layout(3, 600.0)
	hull.pads.append({"lane": 1, "at": 40.0})
	hull.hulls.append({"start": 37.0, "end": 190.0})
	w = sim.build_world(hull)
	d = _drone(w, 50.0)  # arrives while the player is already up on the ceiling
	var fired_up: Array = [false]
	var back: bool = await _run_until(w, 14.0, func() -> bool:
		if w.player.surface == Player.Surface.CEILING and (d.state == DroneScript.State.WINDUP or d.state == DroneScript.State.FIRE):
			fired_up[0] = true
		return w.player.distance > 195.0 and w.player.surface == Player.Surface.FLOOR)
	check(back and d.alive and d.barrages == 0 and not fired_up[0],
		"a drone waits while the player is on the ceiling (barrages %d)" % d.barrages)
	await _run_until(w, 6.0, func() -> bool: return d.barrages > 0)
	check(d.barrages > 0, "and attacks again once the player is back on the floor")
	await sim.free_world(w)


## GDD §9.6: an anti-grav pad hurls every drone on screen into the hull; drones not yet in play stay.
func _test_pad() -> void:
	var layout := RunSim.layout(3, 600.0)
	layout.pads.append({"lane": 1, "at": 120.0})
	layout.hulls.append({"start": 117.0, "end": 190.0})
	var w: RunWorld = sim.build_world(layout)
	w.player.god_mode = true  # survive the barrages on the way to the pad
	var causes: Dictionary = {}
	w.director.enemy_defeated.connect(func(e: Enemy, c: StringName) -> void: causes[e] = c)
	var a := _drone(w, 20.0, 0, 1)
	var b := _drone(w, 20.0, 1, 2)
	var later := _drone(w, 400.0, 0, 3)
	await _run_until(w, 10.0, func() -> bool: return w.player.surface == Player.Surface.CEILING)
	check(w.player.surface == Player.Surface.CEILING, "the player took the pad")
	check(causes.get(a) == &"pad" and causes.get(b) == &"pad" and w.score.kills == 2,
		"stepping on a pad destroys every drone on screen (%d kills)" % w.score.kills)
	check(is_instance_valid(later) and later.alive, "a drone that hasn't arrived yet isn't affected")
	var refs: Array[WeakRef] = [weakref(a), weakref(b)]
	a = null
	b = null
	var gone: bool = await _run_until(w, 1.5, func() -> bool:
		return refs[0].get_ref() == null and refs[1].get_ref() == null)
	check(gone, "the hurled drones crash into the hull and disappear")
	await sim.free_world(w)


## GDD §8 damage reference: 15 shots at laser tier 1, 5 at missile tier 4. Claws don't work.
func _test_weapons() -> void:
	var w: RunWorld = sim.build_world(RunSim.layout(3, 600.0))
	w.player.god_mode = true
	var laser: float = PowerupTuning.at_tier(w.powerup_tuning.weapon_damage, 1)
	var heavy: float = PowerupTuning.at_tier(w.powerup_tuning.weapon_damage, 4)
	var d := _drone(w, 20.0)
	await _run_until(w, 4.0, func() -> bool: return d.state == DroneScript.State.FOLLOW)
	check(d.claw_immune and d.targetable(), "claws don't work on a drone; weapons can target it")
	# Laser shots through the pool, from the player toward the drone.
	var hits: Array = [0]
	w.projectiles.enemy_hit.connect(func(_e: Enemy, _dmg: float, _splash: bool) -> void: hits[0] += 1)
	for i: int in 14:
		var from: Vector3 = w.player.position + Vector3(0.0, 1.0, 0.0)
		var dir: Vector3 = (d.aim_point() - from).normalized()
		w.projectiles.fire_player(from, dir * 90.0 + Vector3(0.0, 0.0, -w.player.speed), laser)
		await _wait(w, 0.25)
	check(d.alive and hits[0] == 14, "14 laser tier 1 hits don't bring it down (%d hits)" % hits[0])
	var from2: Vector3 = w.player.position + Vector3(0.0, 1.0, 0.0)
	w.projectiles.fire_player(from2, (d.aim_point() - from2).normalized() * 90.0 + Vector3(0.0, 0.0, -w.player.speed), laser)
	await _wait(w, 0.3)
	check(not d.alive and w.score.kills == 1, "the 15th does")
	await sim.free_world(w)

	w = sim.build_world(RunSim.layout(3, 600.0))
	d = _drone(w, 20.0)
	await _run_until(w, 4.0, func() -> bool: return d.state == DroneScript.State.FOLLOW)
	for i: int in 4:
		d.take_damage(heavy, &"weapon")
	check(d.alive, "4 heavy missiles don't bring it down")
	d.take_damage(heavy, &"weapon")
	check(not d.alive, "5 heavy missiles (tier 4) do")
	await sim.free_world(w)


## The barrage numbers keep the fairness rules at every campaign scaling.
func _test_barrage_numbers() -> void:
	var t := load("res://data/enemies/drone.tres") as DroneTuning
	var rules := load("res://data/tuning/game_rules.tres") as GameRules
	check(t != null and is_equal_approx(t.health_early, 15.0) and is_equal_approx(t.health_late, 15.0),
		"drone health is 15 laser tier 1 shots early and late (GDD §8)")
	for s: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
		var n: int = t.barrage_count(s, rules.hit_invulnerability)
		var interval: float = t.bullet_interval_at(s)
		check((n - 1) * interval <= rules.hit_invulnerability,
			"scaling %.2f: the barrage (%d bullets) fits in the invulnerability window" % [s, n])
		# A bullet occupies the player's depth for (hurtbox + bullet) / speed; the rest of the
		# interval is the gap to zigzag through, which must beat a lane switch's crossing time.
		var busy: float = (tuning.hurtbox_size.z + 0.12) / t.bullet_speed_at(s)
		check(interval - busy > 0.08, "scaling %.2f: %.2f s gaps between bullets to zigzag through" % [s, interval - busy])
		check(t.windup_at(s) >= 0.8, "scaling %.2f: the wind-up is a readable warning (%.2f s)" % [s, t.windup_at(s)])

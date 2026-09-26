extends TestSuite
## The player's protection, enemies, projectiles, credits and score in full RunWorlds on real physics.

const DUMMY: String = "res://tests/helpers/dummy_enemy.gd"

var sim: RunSim


func run() -> void:
	sim = RunSim.new(tree, tuning)
	await _test_protection()
	await _test_grapple_and_revive()
	await _test_dash()
	await _test_enemies()
	await _test_projectiles()
	await _test_credits()
	await _test_speed_pad_and_emp()


func _loadout(items: Dictionary) -> Loadout:
	var l := Loadout.new()
	for k: String in items:
		if k in ["armor", "shield", "grapple", "revive"]:
			l.charges[StringName(k)] = items[k]
		else:
			l.tiers[StringName(k)] = items[k]
	return l


func _test_protection() -> void:
	var two_fences := RunSim.layout(3)
	two_fences.fences.append(RunSim.fence(1, 30.0, "full"))
	two_fences.fences.append(RunSim.fence(1, 60.0, "full"))

	var w: RunWorld = sim.build_world(two_fences, _loadout({"armor": 1}))
	var r: Dictionary = await sim.step_world(w, 4.0, [], [40.0])
	check(r["at"][40.0]["alive"] and r["events"].has(&"armor_break"), "armor blocks the first fence")
	check(w.player.armor == 0 and w.score.blocked == 1, "the armor is used up and counted")
	check(not r["alive"] and r["cause"].begins_with("fence"), "the second fence, after the invulnerability window, kills (%s)" % r["cause"])
	await sim.free_world(w)

	var close := RunSim.layout(3)
	close.fences.append(RunSim.fence(1, 30.0, "full"))
	close.fences.append(RunSim.fence(1, 38.0, "full"))
	w = sim.build_world(close, _loadout({"armor": 1}))
	r = await sim.step_world(w, 2.5)
	check(r["alive"], "a second hit inside the invulnerability window is ignored (%s)" % r["cause"])
	await sim.free_world(w)

	var wall_sign := RunSim.layout(3)
	wall_sign.signs.append({"side": 1, "start": 25.0, "end": 35.0, "bottom": 0.0, "top": 5.5})
	var to_wall: Array = [[6.0, &"move_right"], [10.0, &"move_right"]]
	w = sim.build_world(wall_sign, _loadout({"armor": 1}))
	r = await sim.step_world(w, 2.0, to_wall)
	check(not r["alive"] and r["cause"] == "sign", "armor doesn't stop a sign (%s)" % r["cause"])
	await sim.free_world(w)
	w = sim.build_world(wall_sign, _loadout({"shield": 1}))
	r = await sim.step_world(w, 2.0, to_wall)
	check(r["alive"] and r["events"].has(&"shield_break"), "the shield stops a sign")
	await sim.free_world(w)


func _test_grapple_and_revive() -> void:
	var gaps := RunSim.layout(3)
	gaps.gaps.append({"lane": 1, "start": 30.0, "end": 36.0})
	gaps.gaps.append({"lane": 1, "start": 90.0, "end": 96.0})
	var w: RunWorld = sim.build_world(gaps, _loadout({"grapple": 1}))
	var r: Dictionary = await sim.step_world(w, 6.0, [], [60.0])
	check(r["at"][60.0]["alive"] and r["events"].has(&"grapple"), "the grapple saves the first fall")
	check(not r["alive"] and r["cause"] == "fell", "the second fall, with the grapple gone, kills")
	w.player.revive()
	r = await sim.step_world(w, 1.5)
	check(r["alive"] and w.player.grounded and r["distance"] > 100.0, "a revive after a fall pulls the player back onto the track")
	await sim.free_world(w)

	var fence := RunSim.layout(3)
	fence.fences.append(RunSim.fence(1, 30.0, "full"))
	w = sim.build_world(fence)
	r = await sim.step_world(w, 2.0)
	check(not r["alive"], "dies on the fence")
	w.player.revive()
	check(w.player.is_invulnerable(), "a revived player is briefly invulnerable")
	r = await sim.step_world(w, 1.0)
	check(r["alive"], "and passes through the hazard that killed them")
	await sim.free_world(w)


func _test_dash() -> void:
	var fence := RunSim.layout(3)
	fence.fences.append(RunSim.fence(1, 30.0, "full"))
	var w: RunWorld = sim.build_world(fence)
	await tree.physics_frame
	w.player.running = true
	w.player.start_dash(1.5, 5.0)
	var r: Dictionary = await sim.step_world(w, 2.0)
	check(r["alive"], "the dash passes through a fence (%s)" % r["cause"])
	check(r["events"].has(&"dash_end"), "the dash ends after its duration")
	await sim.free_world(w)


func _test_enemies() -> void:
	# Stomp: jump so the player drops onto the enemy's top.
	var flat := RunSim.layout(3)
	var w: RunWorld = sim.build_world(flat)
	var e: Enemy = w.director.spawn({"type": "dummy", "script": DUMMY, "at": 30.0, "lane": 1, "seed": 1})
	check(e != null and w.director.active.size() == 1, "the director spawns a scripted enemy")
	var r: Dictionary = await sim.step_world(w, 2.0, [[21.0, &"jump"]])
	check(r["alive"], "dropping onto an enemy stomps it (%s)" % r["cause"])
	check(r["events"].has(&"stomp") and w.score.stomps == 1 and w.score.kills == 1, "the stomp is counted")
	check(w.score.score >= 100 + App.rules.stomp_bonus, "and scores the kill plus the stomp bonus (%d)" % w.score.score)
	await sim.free_world(w)

	# Running into it kills; claws win; the dash wins.
	w = sim.build_world(flat)
	w.director.spawn({"type": "dummy", "script": DUMMY, "at": 30.0, "lane": 1, "seed": 1})
	r = await sim.step_world(w, 2.0)
	check(not r["alive"] and r["cause"] == "dummy", "running into an enemy's body kills (%s)" % r["cause"])
	await sim.free_world(w)
	w = sim.build_world(flat, _loadout({"claws": 1}))
	w.director.spawn({"type": "dummy", "script": DUMMY, "at": 30.0, "lane": 1, "seed": 1})
	r = await sim.step_world(w, 2.0)
	check(r["alive"] and w.score.kills == 1, "claws defeat an enemy on contact")
	await sim.free_world(w)

	# Spiny enemies hurt when landed on without claws.
	w = sim.build_world(flat)
	w.director.spawn({"type": "dummy", "script": DUMMY, "at": 30.0, "lane": 1, "seed": 1, "params": {"stompable": false}})
	r = await sim.step_world(w, 2.0, [[21.0, &"jump"]])
	check(not r["alive"], "landing on a non-stompable enemy hurts")
	await sim.free_world(w)

	# A solid side bumps a lane switch back (GDD §9.3).
	w = sim.build_world(flat)
	w.director.spawn({"type": "dummy", "script": DUMMY, "at": 12.0, "lane": 2, "seed": 1,
		"params": {"blocker": true}})
	r = await sim.step_world(w, 0.8, [[8.0, &"move_right"]])
	check(r["lane"] == 1 and r["events"].has(&"lane_blocked"), "a lane blocker bumps the player back (lane %d)" % r["lane"])
	await sim.free_world(w)

	# Enemies behind the player retire.
	w = sim.build_world(flat)
	w.director.spawn({"type": "dummy", "script": DUMMY, "at": 10.0, "lane": 0, "seed": 1})
	await sim.step_world(w, 4.0)
	check(w.director.active.is_empty(), "enemies left far behind are retired")
	await sim.free_world(w)

	# Layout entries spawn as the player approaches.
	var spawns := RunSim.layout(3)
	spawns.enemies.append({"type": "dummy", "script": DUMMY, "at": 200.0, "lane": 0, "side": 0, "seed": 3, "params": {}})
	w = sim.build_world(spawns)
	await sim.step_world(w, 0.5)
	check(w.director.active.is_empty(), "far enemies aren't spawned yet")
	await sim.step_world(w, 5.5)
	check(w.director.active.size() == 1, "enemies spawn when the player comes within their lead")
	await sim.free_world(w)


func _test_projectiles() -> void:
	var flat := RunSim.layout(3)
	var w: RunWorld = sim.build_world(flat)
	await tree.physics_frame
	w.player.running = true
	w.projectiles.fire_enemy(Vector3(w.geo.lane_x(1), 0.7, -40.0), Vector3(0.0, 0.0, 20.0))
	var r: Dictionary = await sim.step_world(w, 2.0)
	check(not r["alive"] and r["cause"] == "enemy fire", "an enemy shot in the player's path kills (%s)" % r["cause"])
	await sim.free_world(w)

	w = sim.build_world(flat)
	await tree.physics_frame
	w.player.running = true
	w.projectiles.fire_enemy(Vector3(w.geo.lane_x(0), 0.7, -40.0), Vector3(0.0, 0.0, 20.0))
	r = await sim.step_world(w, 2.0)
	check(r["alive"], "a shot in another lane doesn't touch the player (GDD §3: damage only on contact)")
	await sim.free_world(w)

	w = sim.build_world(flat, _loadout({"armor": 1}))
	await tree.physics_frame
	w.player.running = true
	w.projectiles.fire_enemy(Vector3(w.geo.lane_x(1), 0.7, -40.0), Vector3(0.0, 0.0, 20.0))
	r = await sim.step_world(w, 2.0)
	check(r["alive"] and w.player.armor == 0 and w.projectiles.live_count() == 0, "armor blocks an enemy shot, which is used up")
	await sim.free_world(w)

	# Very fast shots can't tunnel through the player.
	w = sim.build_world(flat)
	await tree.physics_frame
	w.player.running = true
	w.projectiles.fire_enemy(Vector3(w.geo.lane_x(1), 0.7, -60.0), Vector3(0.0, 0.0, 250.0))
	r = await sim.step_world(w, 1.0)
	check(not r["alive"], "a 250 m/s shot still hits (swept)")
	await sim.free_world(w)

	# Player shots damage enemies; splash never hurts hosts.
	w = sim.build_world(flat)
	var target: Enemy = w.director.spawn({"type": "dummy", "script": DUMMY, "at": 40.0, "lane": 1, "seed": 1, "params": {"health": 2.0}})
	var host: Enemy = w.director.spawn({"type": "dummy", "script": DUMMY, "at": 41.0, "lane": 2, "seed": 2, "params": {"health": 2.0, "host": true}})
	check(not host.targetable() and target.targetable(), "hosts are never auto-fire targets (GDD §9.7)")
	var ahead: Array[Enemy] = w.director.targets_ahead(Vector3(0.0, 0.6, 0.0), 80.0)
	check(ahead.size() == 1 and ahead[0] == target, "targets_ahead skips hosts")
	w.projectiles.fire_player(Vector3(w.geo.lane_x(1), 0.6, -20.0), Vector3(0.0, 0.0, -80.0), 1.0, &"missile",
		null, 0.0, 5.0, 1.0)
	await sim.step_world(w, 0.4, [], [], false)
	check(is_equal_approx(target.health, 1.0), "a player shot damages its target (%.1f)" % target.health)
	check(is_equal_approx(host.health, 2.0), "splash never damages a host")
	w.projectiles.fire_player(Vector3(w.geo.lane_x(1), 0.6, -30.0), Vector3(0.0, 0.0, -80.0), 1.0)
	await sim.step_world(w, 0.3, [], [], false)
	check((not is_instance_valid(target) or not target.alive) and w.score.kills == 1, "enough damage defeats the enemy and counts the kill")
	await sim.free_world(w)


func _test_credits() -> void:
	var layout := RunSim.layout(3)
	for i: int in 5:
		layout.credits.append({"at": 20.0 + i * 3.0, "surface": "floor", "lane": 1, "side": 0, "height": 0.7, "value": 1})
	layout.credits.append({"at": 40.0, "surface": "floor", "lane": 0, "side": 0, "height": 0.7, "value": 5})
	layout.credits.append({"at": 45.0, "surface": "floor", "lane": 1, "side": 0, "height": 2.5, "value": 25})
	var w: RunWorld = sim.build_world(layout)
	var r: Dictionary = await sim.step_world(w, 3.0)
	check(w.score.credits == 5 and w.score.credit_pickups == 5, "the player collects the credits in their lane (%d)" % w.score.credits)
	check(w.credits.remaining() == 2, "credits in other lanes or out of reach stay (%d)" % w.credits.remaining())
	await sim.free_world(w)

	w = sim.build_world(layout)
	r = await sim.step_world(w, 3.0, [[38.5, &"jump"]])
	check(w.score.credits == 30, "jumping reaches a high credit (%d)" % w.score.credits)
	await sim.free_world(w)

	# Magnet: pulls the adjacent lane, never two lanes over (GDD §8).
	var wide := RunSim.layout(5)
	wide.credits.append({"at": 40.0, "surface": "floor", "lane": 3, "side": 0, "height": 0.7, "value": 5})
	wide.credits.append({"at": 40.0, "surface": "floor", "lane": 4, "side": 0, "height": 0.7, "value": 25})
	w = sim.build_world(wide)
	w.credits.magnet_radius = 10.0
	r = await sim.step_world(w, 3.0)
	check(w.score.credits == 5, "the magnet pulls the next lane but never two lanes over (%d)" % w.score.credits)
	await sim.free_world(w)

	# Surfaces: wall credits only from the wall, ceiling credits only from the ceiling.
	var surfaces := RunSim.layout(3)
	surfaces.credits.append({"at": 30.0, "surface": "wall", "lane": 2, "side": 1, "height": 2.0, "value": 5})
	surfaces.credits.append({"at": 30.0, "surface": "ceiling", "lane": 2, "side": 0, "height": 0.6, "value": 25})
	w = sim.build_world(surfaces)
	w.credits.magnet_radius = 3.0
	r = await sim.step_world(w, 2.5, [[10.0, &"move_right"], [16.0, &"move_right"]])
	check(w.score.credits == 5, "a wall run collects wall credits, never ceiling ones (%d)" % w.score.credits)
	await sim.free_world(w)

	# Ramp multiplier (GDD §3): credits on the ramp's wall run score double.
	var ramp := RunSim.layout(3)
	ramp.ramps.append({"side": 1, "at": 20.0})
	ramp.credits.append({"at": 34.0, "surface": "wall", "lane": 2, "side": 1, "height": 3.9, "value": 5})
	w = sim.build_world(ramp)
	w.player.setup(tuning, w.geo, 2)
	r = await sim.step_world(w, 2.0)
	check(w.score.credits == 5 and w.score.score == roundi(5 * App.rules.ramp_score_multiplier),
		"a ramp's wall run multiplies credit score (%d)" % w.score.score)
	check(w.score.ramps == 1, "ramps are counted")
	await sim.free_world(w)


func _test_speed_pad_and_emp() -> void:
	var pad := RunSim.layout(3)
	pad.speed_pads.append({"lane": 1, "at": 20.0})
	var w: RunWorld = sim.build_world(pad)
	var r: Dictionary = await sim.step_world(w, 2.0, [], [28.0])
	check(r["at"][28.0]["speed"] > tuning.run_speed + 1.0 and r["events"].count(&"speed_pad") == 1,
		"a speed pad boosts once (%.1f m/s)" % r["at"][28.0]["speed"])
	await sim.free_world(w)

	var fences := RunSim.layout(3)
	fences.fences.append(RunSim.fence(1, 30.0, "full"))
	fences.fences.append(RunSim.fence(1, 300.0, "full"))
	w = sim.build_world(fences)
	var n: int = w.track.disable_fences_near(Vector3(0.0, 1.0, -30.0), 15.0)
	var n_far: int = w.track.disable_fences_near(Vector3(0.0, 1.0, -300.0), 15.0)
	check(n == 1 and n_far == 1, "an EMP disables fences near it, built or not yet built")
	r = await sim.step_world(w, 2.5)
	check(r["alive"], "a disabled fence is harmless")
	await sim.free_world(w)

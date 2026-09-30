extends TestSuite
## The hover truck (GDD §9.3) in full RunWorlds on real physics, and its generator rules.

const TruckScript := preload("res://scripts/enemies/hover_truck.gd")
const DroneScript := preload("res://scripts/enemies/drone.gd")
const AttackWatch = preload("res://tools/measure/attack_watch.gd")
const S := TruckScript.State

var sim: RunSim


func run() -> void:
	sim = RunSim.new(tree, tuning)
	await _test_entrance()
	await _test_sides()
	await _test_front()
	await _test_escape_rule()
	await _test_roof_and_weak_point()
	await _test_route_a()
	await _test_route_b()
	await _test_cannon()
	await _test_leaving()
	await _test_weapons()
	await _test_takes_turns()
	_test_rules()


# --- Helpers -------------------------------------------------------------------------------------

func _loadout(items: Dictionary) -> Loadout:
	var l := Loadout.new()
	for k: String in items:
		if k in ["armor", "shield", "grapple", "revive"]:
			l.charges[StringName(k)] = items[k]
		else:
			l.tiers[StringName(k)] = items[k]
	return l


## A truck bursting from the right wall at `at` (or, with skip_entrance in params, already in its lane).
func _truck(w: RunWorld, at: float, params: Dictionary = {}, side: int = 1, seed_value: int = 5) -> TruckScript:
	return w.director.spawn({"type": "hover_truck", "at": at, "lane": w.layout.outer_lane(side), "side": side,
		"seed": seed_value, "params": params}) as TruckScript


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


func _death_cause(w: RunWorld) -> Array:
	var cause: Array = [""]
	w.player.died.connect(func(c: String) -> void: cause[0] = c)
	return cause


# --- Tests ---------------------------------------------------------------------------------------

## GDD §9.3: it bangs on the wall as a warning, then bursts through; only the burst hurts, and only
## a player on that wall section.
func _test_entrance() -> void:
	# On the floor: warned, then passed safely; the truck lands in the outer lane.
	var w: RunWorld = sim.build_world(RunSim.layout(3, 600.0))
	var t := _truck(w, 90.0, {"guns": false})
	check(t != null and t.state == S.HIDDEN and not t.targetable(), "a truck waits inside the building, out of reach")
	await _run_until(w, 8.0, func() -> bool: return t.state == S.PACE)
	check(t.bangs >= 2 and t.first_bang_time >= 0.0 and t.burst_time > t.first_bang_time,
		"it bangs on the wall (%d bangs) before it bursts through" % t.bangs)
	check(t.burst_time - t.first_bang_time >= t.tune.min_warning_seconds - 0.01,
		"the banging warns for %.2f s" % (t.burst_time - t.first_bang_time))
	check(w.player.alive and t.lane == 2 and absf(t.global_position.x - w.geo.lane_x(2)) < 0.05,
		"it lands in the outer lane on its side; a player on the floor is unhurt")
	await sim.free_world(w)

	# On the wall section as it bursts: hurt by the burst (an attack: armor stops it).
	w = sim.build_world(RunSim.layout(3, 600.0))
	w.player.setup(tuning, w.geo, 2)
	var cause: Array = _death_cause(w)
	t = _truck(w, 90.0, {"guns": false})
	await _run_until(w, 8.0, func() -> bool: return w.player.distance >= 64.0)
	w.player.press(&"move_right")
	await _run_until(w, 3.0, func() -> bool: return not w.player.alive)
	check(not w.player.alive and cause[0] == TruckScript.BURST_NAME and t.burst_time >= 0.0,
		"a player on that wall section is hurt by the burst (%s)" % cause[0])
	await sim.free_world(w)

	w = sim.build_world(RunSim.layout(3, 600.0), _loadout({"armor": 1}))
	w.player.setup(tuning, w.geo, 2)
	t = _truck(w, 90.0, {"guns": false})
	await _run_until(w, 8.0, func() -> bool: return w.player.distance >= 64.0)
	w.player.press(&"move_right")
	await _wait(w, 2.0)
	check(w.player.alive and w.player.armor == 0, "armor blocks the burst (it's an attack)")
	await sim.free_world(w)

	# On the wall during the banging but off it before the burst: the banging never hurts.
	w = sim.build_world(RunSim.layout(3, 600.0))
	w.player.setup(tuning, w.geo, 2)
	t = _truck(w, 90.0, {"guns": false})
	await _run_until(w, 8.0, func() -> bool: return w.player.distance >= 32.0)
	w.player.press(&"move_right")
	var on_wall_while_banging: bool = await _run_until(w, 2.5, func() -> bool:
		return w.player.surface == Player.Surface.WALL and t.state == S.BANGING)
	await _run_until(w, 6.0, func() -> bool: return t.state == S.PACE)
	check(on_wall_while_banging and w.player.alive, "the banging never hurts a player on that wall")
	await sim.free_world(w)

	# On the other wall: unhurt.
	w = sim.build_world(RunSim.layout(3, 600.0))
	w.player.setup(tuning, w.geo, 0)
	t = _truck(w, 90.0, {"guns": false})
	await _run_until(w, 8.0, func() -> bool: return w.player.distance >= 64.0)
	w.player.press(&"move_left")
	await _wait(w, 2.0)
	check(w.player.alive, "a player on the other wall is unhurt by the burst")
	await sim.free_world(w)


## GDD §9.3: the sides are safe but solid: switching lanes into it bumps the player back.
func _test_sides() -> void:
	var w: RunWorld = sim.build_world(RunSim.layout(3, 600.0))
	var t := _truck(w, 0.0, {"skip_entrance": true, "phase": "alongside", "offset": -2.8, "guns": false})
	await _wait(w, 0.3)
	w.player.press(&"move_right")
	var r: Dictionary = await sim.step_world(w, 0.5)
	check(r["alive"] and w.player.lane == 1 and r["events"].has(&"lane_blocked"),
		"switching into its side bumps the player back (lane %d)" % w.player.lane)
	# Ahead of it, the lane is open (the blocker only covers its length).
	await sim.free_world(w)
	w = sim.build_world(RunSim.layout(3, 600.0))
	t = _truck(w, 0.0, {"skip_entrance": true, "phase": "pace", "offset": 10.0, "guns": false})
	await _wait(w, 0.3)
	w.player.press(&"move_right")
	await _wait(w, 0.5)
	check(w.player.alive and w.player.lane == 2 and t.player_in_lane(), "the lane behind it is open")
	# It never backs into a player in its lane behind it (the rear is safe).
	var min_gap: Array = [INF]
	await _run_until(w, 10.0, func() -> bool:
		min_gap[0] = minf(min_gap[0], t.offset - t.tune.length * 0.5)
		return false)
	check(w.player.alive and min_gap[0] >= t.tune.rear_gap, "its rear never backs into the player (closest %.2f m)" % min_gap[0])
	await sim.free_world(w)


## GDD §9.3: being in front of it when it lurches forward kills; nothing else about it does.
func _test_front() -> void:
	# In its lane ahead of it: safe while it holds back and revs, killed by the forward lurch.
	var w: RunWorld = sim.build_world(RunSim.layout(3, 600.0))
	w.player.setup(tuning, w.geo, 2)
	var cause: Array = _death_cause(w)
	var t := _truck(w, 0.0, {"skip_entrance": true, "phase": "hold_back", "offset": t_back(), "guns": false})
	var revved: bool = await _run_until(w, 4.0, func() -> bool: return t.state == S.REV)
	check(revved and w.player.alive, "a player ahead of it in its lane is unhurt while it holds back")
	var state_at_death: Array = [-1]
	await _run_until(w, 3.0, func() -> bool:
		if not w.player.alive:
			return true
		state_at_death[0] = t.state
		return false)
	check(not w.player.alive and cause[0] == TruckScript.SPIKES_NAME and state_at_death[0] == S.LURCH_FWD,
		"the forward lurch kills a player in front of it (%s)" % cause[0])
	await sim.free_world(w)

	# A player in its lane ahead of it while it paces: it can't pace past them, so it holds, revs and
	# lurches (the telegraphed threat) rather than idling behind them.
	w = sim.build_world(RunSim.layout(3, 600.0))
	w.player.setup(tuning, w.geo, 2)
	t = _truck(w, 0.0, {"skip_entrance": true, "phase": "pace", "offset": t_back() - 1.0, "guns": false})
	var warned: bool = await _run_until(w, 5.0, func() -> bool: return t.state == S.REV or not w.player.alive)
	check(warned and w.player.alive, "pacing behind a player in its lane, it holds and revs before any lurch")
	await sim.free_world(w)

	# Armor doesn't stop the spikes (solid); a shield does.
	w = sim.build_world(RunSim.layout(3, 600.0), _loadout({"armor": 1}))
	w.player.setup(tuning, w.geo, 2)
	t = _truck(w, 0.0, {"skip_entrance": true, "phase": "hold_back", "offset": t_back(), "guns": false})
	await _run_until(w, 6.0, func() -> bool: return not w.player.alive)
	check(not w.player.alive and w.player.armor == 1, "armor doesn't stop the spikes (a solid hit)")
	await sim.free_world(w)
	w = sim.build_world(RunSim.layout(3, 600.0), _loadout({"shield": 1}))
	w.player.setup(tuning, w.geo, 2)
	t = _truck(w, 0.0, {"skip_entrance": true, "phase": "hold_back", "offset": t_back(), "guns": false})
	await _run_until(w, 6.0, func() -> bool: return t.state == S.ALONGSIDE)
	check(w.player.alive and w.player.shield == 0, "a shield does")
	await sim.free_world(w)

	# A lurch never catches a player who stays out of its lane, at any lane count, beside it or on
	# the wall next to it.
	for lanes: int in [3, 5, 6]:
		for start: int in range(lanes - 1):
			w = sim.build_world(RunSim.layout(lanes, 600.0))
			w.player.setup(tuning, w.geo, start)
			t = _truck(w, 0.0, {"skip_entrance": true, "phase": "hold_back", "offset": t_back(), "guns": false})
			await _run_until(w, 12.0, func() -> bool: return t.forward_lurches >= 2 or not w.player.alive)
			check(w.player.alive and t.forward_lurches >= 1,
				"%d lanes, player in lane %d: the lurches pass by (%d lurches)" % [lanes, start, t.forward_lurches])
			await sim.free_world(w)
	w = sim.build_world(RunSim.layout(3, 600.0))
	w.player.setup(tuning, w.geo, 2)
	t = _truck(w, 0.0, {"skip_entrance": true, "phase": "hold_back", "offset": t_back(), "guns": false})
	await _run_until(w, 4.0, func() -> bool: return t.state == S.REV)
	w.player.press(&"move_right")  # onto the wall beside its lane
	var passed: bool = await _run_until(w, 3.0, func() -> bool: return t.state == S.ALONGSIDE or not w.player.alive)
	check(passed and w.player.alive and w.player.surface == Player.Surface.WALL,
		"a player on the wall beside it is passed safely by the lurch")
	await sim.free_world(w)


func t_back() -> float:
	return (load("res://data/enemies/hover_truck.tres") as HoverTruckTuning).back_offset


## Never an unavoidable combination: it doesn't start the forward lurch while a player in its lane
## ahead of it has no way out (a sign blocks the wall and the next lane has a hole).
func _test_escape_rule() -> void:
	var layout := RunSim.layout(3, 600.0)
	layout.signs.append({"side": 1, "start": 0.0, "end": 130.0, "bottom": 0.0, "top": 5.5})
	layout.gaps.append({"lane": 1, "start": 20.0, "end": 100.0})
	var w: RunWorld = sim.build_world(layout)
	w.player.setup(tuning, w.geo, 2)
	var t := _truck(w, 0.0, {"skip_entrance": true, "phase": "hold_back", "offset": t_back(), "guns": false})
	var revved_early: Array = [false]
	await _run_until(w, 5.0, func() -> bool:
		if t.state == S.REV:
			revved_early[0] = true
		return w.player.distance > 90.0)
	check(not revved_early[0] and w.player.alive and t.state == S.HOLD_BACK,
		"no forward lurch while the player in front of it has no way out")
	var revved: bool = await _run_until(w, 4.0, func() -> bool: return t.state == S.REV)
	check(revved, "it revs once the way out is open again")
	await sim.free_world(w)


## GDD §9.3: land on its roof (a moving floor), ride it, and stomp the weak point on the cab.
func _test_roof_and_weak_point() -> void:
	var w: RunWorld = sim.build_world(RunSim.layout(3, 600.0))
	w.player.setup(tuning, w.geo, 2)
	w.player.god_mode = false
	await _run_until(w, 1.0, func() -> bool: return w.player.distance > 2.0)
	w.player.press(&"move_right")
	await _run_until(w, 1.0, func() -> bool: return w.player.surface == Player.Surface.WALL)
	await _wait(w, 0.2)
	# The truck arrives beside the wall-runner with its cargo roof next to them.
	var t := _truck(w, 0.0, {"skip_entrance": true, "phase": "alongside", "offset": 3.0, "guns": false})
	w.player.press(&"jump")
	var landed: Array = [false]
	var rode: Array = [false]
	var causes: Dictionary = {}
	w.director.enemy_defeated.connect(func(e: Enemy, c: StringName) -> void: causes[e] = c)
	await _run_until(w, 6.0, func() -> bool:
		if is_instance_valid(t) and t.alive and w.player.grounded and absf(w.player.h - t.tune.roof_height) < 0.12:
			landed[0] = true
		if is_instance_valid(t) and t.alive and t.state == S.RIDDEN:
			rode[0] = true
		return causes.size() > 0)
	check(landed[0], "a wall jump lands the player on its cargo roof")
	check(rode[0], "the player rides the roof as it moves")
	check(causes.values().has(&"stomp") and w.player.alive and w.score.stomps == 1,
		"riding forward drops the player onto the weak point: the stomp destroys it (%s)" % str(causes.values()))
	var wrecked: bool = is_instance_valid(t) and t.state == S.WRECKED
	var gone: bool = await _run_until(w, 2.0, func() -> bool: return w.director.active.is_empty())
	check(wrecked and gone and w.player.alive, "it spins out and explodes; the player lands safely")
	await sim.free_world(w)

	# Touching the weak point any other way is harmless, and standing on the floor can't reach it.
	w = sim.build_world(RunSim.layout(3, 600.0))
	t = _truck(w, 0.0, {"skip_entrance": true, "phase": "alongside", "offset": -2.8, "guns": false})
	await _wait(w, 0.3)
	w.player.press(&"jump")
	await _wait(w, 0.2)
	w.player.press(&"move_right")
	await _wait(w, 1.0)
	check(t.alive and w.player.alive and w.player.lane == 1, "a jump from the next lane can't get onto it (bumped back)")
	await sim.free_world(w)


## Route (a): take a ramp onto the wall, then wall-jump onto the truck.
func _test_route_a() -> void:
	var tt := load("res://data/enemies/hover_truck.tres") as HoverTruckTuning
	var layout := RunSim.layout(3, 600.0)
	# The ramp is where the player reaches it while the truck revs behind them.
	layout.ramps.append({"side": 1, "at": tuning.run_speed * (tt.hold_back_seconds + 0.4)})
	var w: RunWorld = sim.build_world(layout)
	w.player.setup(tuning, w.geo, 2)
	var t := _truck(w, 0.0, {"skip_entrance": true, "phase": "hold_back", "offset": t_back(), "guns": false})
	var causes: Dictionary = {}
	w.director.enemy_defeated.connect(func(e: Enemy, c: StringName) -> void: causes[e] = c)
	var ramped: bool = await _run_until(w, 4.0, func() -> bool: return w.player.surface == Player.Surface.WALL)
	check(ramped and w.player.last_event == "ramp", "the ramp launches the player onto the wall")
	await _run_until(w, 3.0, func() -> bool: return t.state == S.ALONGSIDE)
	check(w.player.surface == Player.Surface.WALL and w.player.alive, "the truck lurches up beside the wall-runner")
	w.player.press(&"jump")
	await _run_until(w, 4.0, func() -> bool: return causes.size() > 0 or not w.player.alive)
	check(causes.values().has(&"stomp") and w.player.alive, "route (a): ramp, wall, wall jump, stomp (%s)" % str(causes.values()))
	await sim.free_world(w)


## Route (b): during a backward lurch get ahead of it, jump onto the wall, wait for the forward
## lurch, then jump onto the truck. Played through its own cycle from pacing ahead.
func _test_route_b() -> void:
	var w: RunWorld = sim.build_world(RunSim.layout(3, 800.0))
	w.player.setup(tuning, w.geo, 1)
	var t := _truck(w, 0.0, {"skip_entrance": true, "phase": "pace", "offset": 10.0, "guns": false})
	var causes: Dictionary = {}
	w.director.enemy_defeated.connect(func(e: Enemy, c: StringName) -> void: causes[e] = c)
	var held: bool = await _run_until(w, 10.0, func() -> bool: return t.state == S.HOLD_BACK)
	check(held and t.offset < 0.0, "it lurches back behind the player")
	w.player.press(&"move_right")  # into its lane, ahead of it
	await _wait(w, 0.4)
	check(t.player_in_lane() and w.player.alive, "the player gets ahead of it in its lane")
	await _run_until(w, 4.0, func() -> bool: return t.state == S.REV)
	await _wait(w, t.tune.rev_seconds * 0.6)
	w.player.press(&"move_right")  # onto the wall late in the rev, so it's still high when the truck arrives
	await _run_until(w, 3.0, func() -> bool: return t.state == S.ALONGSIDE)
	check(w.player.surface == Player.Surface.WALL and w.player.alive, "on the wall, the forward lurch passes safely")
	w.player.press(&"jump")
	await _run_until(w, 4.0, func() -> bool: return causes.size() > 0 or not w.player.alive)
	check(causes.values().has(&"stomp") and w.player.alive, "route (b): wall jump onto the cab and stomp (%s)" % str(causes.values()))
	await sim.free_world(w)


## GDD §9.3: a cannon with a slow fire rate, telegraphed; a lane switch after the shot dodges it.
func _test_cannon() -> void:
	var w: RunWorld = sim.build_world(RunSim.layout(3, 800.0))
	var cause: Array = _death_cause(w)
	var t := _truck(w, 0.0, {"skip_entrance": true, "phase": "pace", "offset": 10.0})
	var charged: Array = [-1.0]
	var fired: Array = [-1.0]
	await _run_until(w, 8.0, func() -> bool:
		if t.charging() and charged[0] < 0.0:
			charged[0] = w.level_time()
		if w.projectiles.live_count() > 0 and fired[0] < 0.0:
			fired[0] = w.level_time()
		return not w.player.alive)
	check(charged[0] >= 0.0 and fired[0] - charged[0] >= t.tune.cannon_charge_seconds - 0.02,
		"the cannon charges for %.2f s before it fires" % (fired[0] - charged[0]))
	check(not w.player.alive and cause[0] == TruckScript.CANNON_NAME, "a player who stays put is hit (%s)" % cause[0])
	await sim.free_world(w)

	w = sim.build_world(RunSim.layout(3, 800.0))
	t = _truck(w, 0.0, {"skip_entrance": true, "phase": "pace", "offset": 10.0})
	await _run_until(w, 8.0, func() -> bool: return t.cannon_shots > 0)
	w.player.press(&"move_left")
	await _wait(w, 2.0)
	check(w.player.alive and t.cannon_shots == 1, "a lane switch after the shot dodges it")
	await sim.free_world(w)

	# Window shooters: none early, two by the last levels, firing just after the cannon.
	var tt := load("res://data/enemies/hover_truck.tres") as HoverTruckTuning
	check(tt.shooters_at(0.0) == 0 and tt.shooters_at(0.6) == 1 and tt.shooters_at(1.0) == 2,
		"window shooters scale 0 → 1 → 2 across the campaign")
	var late := LevelConfig.new()
	late.enemy_scaling = 1.0
	w = sim.build_world(RunSim.layout(3, 800.0), null, null, late)
	w.player.god_mode = true
	t = _truck(w, 0.0, {"skip_entrance": true, "phase": "pace", "offset": 10.0})
	var shots: Array = [0]
	await _run_until(w, 8.0, func() -> bool:
		shots[0] = maxi(shots[0], w.projectiles.live_count())
		return t.cannon_shots > 0 and w.level_time() > 5.0)
	check(t.shooters == 2 and shots[0] >= 3, "late trucks add two gunners to the volley (%d shots in the air)" % shots[0])
	await sim.free_world(w)


## GDD §9.3: it falls behind after 20–30 s if not destroyed.
func _test_leaving() -> void:
	for seed_value: int in [1, 2, 3]:
		var w: RunWorld = sim.build_world(RunSim.layout(3, 1200.0))
		w.player.setup(tuning, w.geo, 0)
		var ref: WeakRef = weakref(_truck(w, 90.0, {"guns": false}, 1, seed_value))
		var times: Array = [-1.0, -1.0]
		await _run_until(w, 50.0, func() -> bool:
			var t: TruckScript = ref.get_ref() as TruckScript
			if t == null or t.is_queued_for_deletion():
				return true
			times[0] = t.burst_time
			times[1] = t.leave_time
			return false)
		var stay: float = times[1] - times[0]
		check(times[0] >= 0.0 and stay >= 20.0 - 0.01 and stay <= 31.5,
			"seed %d: it leaves %.1f s after bursting in (20–30 s)" % [seed_value, stay])
		check(w.director.active.is_empty() and w.player.alive, "seed %d: then falls behind and is gone" % seed_value)
		await sim.free_world(w)


## GDD §8 damage reference: 17 laser tier 1 shots, 5 missile tier 4 shots (owner's September 30,
## 2026 playtest; was 15 laser tier 1 shots).
func _test_weapons() -> void:
	var w: RunWorld = sim.build_world(RunSim.layout(3, 600.0))
	var laser: float = PowerupTuning.at_tier(w.powerup_tuning.weapon_damage, 1)
	var heavy: float = PowerupTuning.at_tier(w.powerup_tuning.weapon_damage, 4)
	var t := _truck(w, 0.0, {"skip_entrance": true, "phase": "pace", "offset": 10.0, "guns": false})
	await _wait(w, 0.2)
	check(t.targetable(), "weapons can target it once it's in play")
	var hits: Array = [0]
	w.projectiles.enemy_hit.connect(func(_e: Enemy, _d: float, _s: bool) -> void: hits[0] += 1)
	for i: int in 17:
		var from: Vector3 = w.player.position + Vector3(0.0, 1.0, 0.0)
		var dir: Vector3 = (t.aim_point() - from).normalized()
		w.projectiles.fire_player(from, dir * 90.0 + Vector3(0.0, 0.0, -w.player.speed), laser)
		await _wait(w, 0.2)
		if i == 15:
			check(t.alive and hits[0] == 16, "16 laser tier 1 hits don't stop it (%d hits)" % hits[0])
	check(not t.alive and hits[0] == 17, "the 17th does")
	await sim.free_world(w)

	w = sim.build_world(RunSim.layout(3, 600.0))
	t = _truck(w, 0.0, {"skip_entrance": true, "phase": "pace", "offset": 10.0, "guns": false})
	await _wait(w, 0.2)
	for i: int in 4:
		t.take_damage(heavy, &"weapon")
	check(t.alive, "4 heavy missiles don't stop it")
	t.take_damage(heavy, &"weapon")
	check(not t.alive and t.state == S.WRECKED, "5 heavy missiles (tier 4) do: it spins out")
	await sim.free_world(w)


## GDD §9, big attacks take turns: its lurch and its cannon shot are big attacks
## (is_major_attack_active: the rev and the lurch; the charge and the volley). Ready to rev while a
## drone's barrage is on, it holds back behind the player, and ready to charge its cannon it keeps
## pacing; each goes once the barrage's last bullet has passed the player, and its shell holds its own
## turn the same way. Switched off (GameRules.big_attacks_take_turns), each goes during the barrage,
## as before the rule.
func _test_takes_turns() -> void:
	var dt := load("res://data/enemies/drone.tres") as DroneTuning
	var tt := load("res://data/enemies/hover_truck.tres") as HoverTruckTuning
	# The drone swoops in at once and fires from about fire_at until about barrage_end.
	var fire_at: float = dt.swoop_time + dt.first_follow_time + dt.windup_early
	for kind: String in ["lurch", "cannon"]:
		for turns: bool in [true, false]:
			var tag: String = "%s, turns %s" % [kind, "on" if turns else "off"]
			var w: RunWorld = sim.build_world(RunSim.layout(3, 800.0))
			w.rules = w.rules.duplicate() as GameRules
			w.rules.big_attacks_take_turns = turns
			w.player.setup(tuning, w.geo, 0)
			w.player.god_mode = true
			var watch := AttackWatch.new(w)
			var d := w.director.spawn({"type": "drone", "at": 0.0, "lane": 0, "side": 0, "seed": 7,
				"params": {"slot": 0}}) as DroneScript
			# The truck gets ready (hold-back over, or its first shot due) as the barrage starts.
			var ready_in: float = tt.hold_back_seconds if kind == "lurch" else tt.first_shot_delay
			var spawn_at: float = fire_at + 0.2 - ready_in
			var t: TruckScript = null
			var went: float = -1.0
			var barrage_over: float = -1.0
			var held_ok: bool = true
			var waited: float = 0.0
			var active_ok: bool = true
			var saw_active: bool = false
			var shell_holds: bool = false
			await tree.physics_frame
			w.player.running = true
			for i: int in 9 * Engine.physics_ticks_per_second:
				await tree.physics_frame
				watch.observe()
				var now: float = w.level_time()
				if t == null and now >= spawn_at:
					var params := {"skip_entrance": true, "guns": kind == "cannon",
						"phase": "hold_back" if kind == "lurch" else "pace",
						"offset": tt.back_offset if kind == "lurch" else tt.pace_offset}
					t = _truck(w, 0.0, params, 1)
				if d.barrages > 0 and barrage_over < 0.0 and d.state != DroneScript.State.FIRE \
						and not w.director.shots_on_their_way(&"drone"):
					barrage_over = now
				if t == null:
					continue
				var going: bool = t.state == S.REV if kind == "lurch" else t.charging()
				if going and went < 0.0:
					went = now
				var attacking: bool = t.state == S.REV or t.state == S.LURCH_FWD or t.charging() \
					or not (t.get(&"_volley") as Array).is_empty()
				active_ok = active_ok and t.is_major_attack_active() == attacking
				saw_active = saw_active or t.is_major_attack_active()
				if w.director.is_waiting(t):
					waited += 1.0 / Engine.physics_ticks_per_second
					held_ok = held_ok and (t.state == S.HOLD_BACK and absf(t.offset - tt.back_offset) < 1.0 if kind == "lurch"
						else t.state == S.PACE and absf(t.offset - tt.pace_offset) < 1.5)
				if kind == "cannon" and t.cannon_shots > 0:
					shell_holds = shell_holds or w.director.shots_on_their_way(&"hover_truck")
				if went >= 0.0 and barrage_over >= 0.0 and now > maxf(went, barrage_over) + 2.0:
					break
			check(t != null and went >= 0.0 and d.barrages >= 1, "%s: the truck and the drone both attacked" % tag)
			check(active_ok and saw_active, "%s: its big attack is on exactly through its rev and lurch, and its charge and volley" % tag)
			if kind == "cannon":
				check(t != null and t.cannon_shots >= 1 and shell_holds, "%s: it fired, and its shell held its turn until it passed" % tag)
			if turns:
				check(went >= barrage_over - 0.001 and waited > 0.3,
					"%s: it goes once the barrage's last bullet has passed (%.2f s, the barrage over at %.2f s, after waiting %.2f s)"
					% [tag, went, barrage_over, waited])
				check(held_ok, "%s: meanwhile it %s" % [tag, "holds back behind the player" if kind == "lurch" else "keeps pacing"])
				check(is_zero_approx(watch.overlap), "%s: the two big attacks never overlap (%.2f s)" % [tag, watch.overlap])
			else:
				check(went >= 0.0 and went < barrage_over and waited == 0.0,
					"%s: it goes during the barrage, as before the rule (%.2f s, the barrage over at %.2f s)" % [tag, went, barrage_over])
				check(watch.overlap > 0.2, "%s: the two overlap (%.2f s)" % [tag, watch.overlap])
			await sim.free_world(w)


## Generator rules (GDD §9.3) over many seeds, difficulties and lane counts, and in the campaign
## levels that use the truck (city/3 introduces it).
func _test_rules() -> void:
	var t := load("res://data/enemies/hover_truck.tres") as HoverTruckTuning
	var base: LevelConfig = load(LEVEL_PATH) as LevelConfig
	var patterns: Array = LevelGenerator.load_for(base)
	var per_difficulty: Dictionary = {}
	var levels: int = 0
	for lanes: int in [3, 5, 6]:
		for difficulty: float in [0.2, 0.6, 1.0]:
			for level_seed: int in range(1, 13):
				for with_ramps: bool in [false, true]:
					var config: LevelConfig = base.duplicate() as LevelConfig
					config.lane_count = lanes
					config.difficulty = difficulty
					config.enemy_scaling = difficulty
					config.level_seed = level_seed
					config.features = PackedStringArray(["ceilings", "pulsing", "hover_truck"])
					if with_ramps:
						config.features.append("ramps")
					var tag: String = "lanes=%d diff=%.1f seed=%d ramps=%s" % [lanes, difficulty, level_seed, with_ramps]
					var gen := LevelGenerator.new()
					var a: LevelLayout = gen.generate(config, tuning, patterns)
					check(gen.warnings.is_empty(), "truck levels generate without warnings %s %s" % [tag, gen.warnings])
					var b: LevelLayout = LevelGenerator.new().generate(config, tuning, patterns)
					check(JSON.stringify(a.to_dict()) == JSON.stringify(b.to_dict()), "same seed, same trucks " + tag)
					var n: int = _check_rules(a, config, t, tag)
					check(n >= 1, "every truck level has a truck " + tag)
					check(n <= t.max_per_level_at(config.enemy_scaling), "no more trucks than the level's scaling allows " + tag)
					per_difficulty[difficulty] = int(per_difficulty.get(difficulty, 0)) + n
					levels += 1
	check(per_difficulty[0.2] < per_difficulty[1.0],
		"rare early, more frequent later (%d trucks at difficulty 0.2, %d at 1.0)" % [per_difficulty[0.2], per_difficulty[1.0]])

	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var totals: Dictionary = {}
	for id: String in ["city/3", "gangland/1", "gangland/2", "gangland/3"]:
		for lanes: int in [3, 5, 6]:
			var config: LevelConfig = campaign.configure(campaign.step(id), lanes)
			var gen := LevelGenerator.new()
			var layout: LevelLayout = gen.generate(config, tuning, LevelGenerator.load_for(config))
			var n: int = _check_rules(layout, config, t, "%s lanes=%d" % [id, lanes])
			check(gen.warnings.is_empty() and n >= 1, "%s has trucks and follows the rules (%d, %d lanes)" % [id, n, lanes])
			totals[id] = int(totals.get(id, 0)) + n
	check(totals["city/3"] == 3, "city/3 introduces the truck: one per level (%d over 3 lane counts)" % totals["city/3"])
	# Gangland is early in the planned campaign (levels 4–6 of 18), where the scaling still allows one
	# truck per level; more come in later zones (the difficulty sweep above checks the growth).
	check(totals["gangland/3"] >= totals["city/3"], "later levels bring at least as many (%d vs %d)" % [totals["gangland/3"], totals["city/3"]])


## Checks one layout against the truck rules. Returns the number of trucks.
func _check_rules(layout: LevelLayout, config: LevelConfig, t: HoverTruckTuning, tag: String) -> int:
	var speed: float = tuning.run_speed
	var rules := load("res://scripts/enemies/hover_truck_rules.gd")
	var trucks: Array[Dictionary] = []
	for e: Dictionary in layout.enemies:
		if String(e["type"]) == "hover_truck":
			trucks.append(e)
	var prev_end: float = -INF
	for e: Dictionary in trucks:
		var at: float = e["at"]
		var side: int = e["side"]
		var lane: int = e["lane"]
		check(side != 0 and lane == layout.outer_lane(side), "a truck holds the outer lane on its side " + tag)
		check(at + t.stay_min_seconds * speed <= layout.length - config.end_clear_distance + 0.01,
			"room for its shortest stay before the finish (at %.0f) %s" % [at, tag])
		var from: float = rules.window_start(t, at)
		var to: float = rules.window_end(t, at, speed)
		check(from >= prev_end, "one truck at a time %s" % tag)
		prev_end = to
		for g: Dictionary in layout.gaps:
			check(not (int(g["lane"]) == lane and float(g["start"]) <= to and float(g["end"]) >= from),
				"no gap in its lane while it's around (%.0f) %s" % [g["start"], tag])
		for f: Dictionary in layout.fences:
			check(not (int(f["lane"]) == lane and float(f["at"]) >= from and float(f["at"]) <= to),
				"no fence in its lane while it's around (%.0f) %s" % [f["at"], tag])
		for o: Dictionary in layout.enemies:
			if LevelGenerator.enemy_uses_floor(o) and int(o["lane"]) == lane:
				check(float(o["at"]) < from or float(o["at"]) > to, "its lane is free of other enemies (%s) %s" % [o["type"], tag])
		var section: Vector2 = rules.burst_section(t, at)
		for s: Dictionary in layout.signs:
			check(not (int(s["side"]) == side and float(s["start"]) <= section.y and float(s["end"]) >= section.x),
				"no sign where it bursts through the wall %s" % tag)
		if config.has_feature("ramps"):
			var ramp: bool = false
			for r: Dictionary in layout.ramps:
				if int(r["side"]) == side and float(r["at"]) >= at + t.ramp_after_seconds * speed - 0.01 \
						and float(r["at"]) <= at + t.stay_min_seconds * speed:
					ramp = true
			check(ramp, "route (a) has a ramp on its side while it's around (at %.0f) %s" % [at, tag])
		else:
			check(layout.ramps.is_empty(), "no ramps in a level without the ramps feature " + tag)
	# The ramps it adds follow the usual ramp fairness.
	for r: Dictionary in layout.ramps:
		var rl: int = layout.outer_lane(int(r["side"]))
		check(not layout.gapped_between(rl, float(r["at"]), float(r["at"]) + tuning.ramp_length), "ramp on solid floor " + tag)
		for s: Dictionary in layout.signs:
			if int(s["side"]) == int(r["side"]):
				check(float(s["end"]) < float(r["at"]) - 2.0 or float(s["start"]) > float(r["at"]) + tuning.ramp_length + 2.0,
					"ramp entry not blocked by a sign " + tag)
	return trucks.size()

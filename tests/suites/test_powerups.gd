extends TestSuite
## The permanent power-ups (GDD §8) run by PowerupController from the run's loadout: the weapon
## line with enemy health bars, the juggernaut dash, the magnet and slow time; hud_state() and
## equipment(). Full RunWorlds on real physics, with dummy enemies as weapon targets.

const DUMMY: String = "res://tests/helpers/dummy_enemy.gd"
const PACER: String = "res://tests/helpers/pacing_dummy.gd"
const PERMANENT: Array[String] = ["weapon", "claws", "dash", "magnet", "slow_time"]

var sim: RunSim
var pt: PowerupTuning


func run() -> void:
	sim = RunSim.new(tree, tuning)
	pt = load("res://data/tuning/powerups.tres") as PowerupTuning
	await _test_nothing_without_items()
	await _test_each_item_alone()
	await _test_targeting()
	await _test_muzzle()
	await _test_shot_counts()
	await _test_splash()
	await _test_health_bars()
	await _test_dash()
	await _test_magnet()
	await _test_slow_time()
	await _test_slow_time_restores()
	await _test_slow_time_mobile()
	await _test_slow_time_through_app()
	await _test_hud_state()
	# Never leak a slowed engine into the next suite, even after a failed check.
	Engine.time_scale = 1.0


func _loadout(items: Dictionary) -> Loadout:
	var l := Loadout.new()
	for k: String in items:
		if k in ["armor", "shield", "grapple", "revive"]:
			l.charges[StringName(k)] = items[k]
		else:
			l.tiers[StringName(k)] = items[k]
	return l


func _controller(w: RunWorld) -> PowerupController:
	return w.powerups as PowerupController


## A dummy that stays `lead` metres ahead of the player.
func _pacer(w: RunWorld, lead: float, lane: int, params: Dictionary = {}) -> Enemy:
	var p: Dictionary = params.duplicate()
	p["lead"] = lead
	return w.director.spawn({"type": "dummy", "script": PACER, "at": w.player_distance() + lead, "lane": lane,
		"seed": 1, "params": p})


## Presses and releases a named input action the way TouchInput does, and waits until it's delivered.
func _send_action(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = pressed
		Input.parse_input_event(e)
	await tree.process_frame
	await tree.process_frame


## Steps the world until the player has run `distance` metres (or `max_seconds` pass).
func _run_to(w: RunWorld, distance: float, max_seconds: float = 10.0) -> void:
	var frames: int = int(max_seconds * Engine.physics_ticks_per_second)
	if not w.player.running:
		await tree.physics_frame
		w.player.running = true
	for i: int in frames:
		if w.player.distance >= distance or not w.player.alive:
			return
		await tree.physics_frame


func _friendly_shots(w: RunWorld) -> int:
	var n: int = 0
	for p: Projectile in w.projectiles.live_shots():
		if p.friendly:
			n += 1
	return n


func _entry(state: Array[Dictionary], id: StringName) -> Dictionary:
	for e: Dictionary in state:
		if e["id"] == id:
			return e
	return {}


# --- Loadout ------------------------------------------------------------------------------

func _test_nothing_without_items() -> void:
	var layout := RunSim.layout(3)
	layout.credits.append({"at": 30.0, "surface": "floor", "lane": 0, "side": 0, "height": 0.7, "value": 5})
	var w: RunWorld = sim.build_world(layout)
	var c: PowerupController = _controller(w)
	check(c != null, "RunWorld creates the power-up controller by convention")
	if c == null:
		await sim.free_world(w)
		return
	check(c.get_index() > w.credits.get_index() and c.get_index() > w.player.get_index(),
		"the controller runs after the player, enemies, projectiles and credits")
	check(c.modules.is_empty() and c.hud_state().is_empty(), "an empty loadout runs no power-ups and shows none")
	var target: Enemy = _pacer(w, 25.0, 1, {"health": 3.0})
	await _run_to(w, 5.0)
	await _send_action(&"dash")
	await _send_action(&"slow_time")
	check(not w.player.dashing and is_equal_approx(Engine.time_scale, 1.0), "the dash and slow_time actions do nothing")
	await sim.step_world(w, 1.5)
	check(not c.try_dash() and not w.player.dashing, "no dash without the dash")
	check(not c.try_slow_time() and is_equal_approx(Engine.time_scale, 1.0), "no slow time without slow time")
	check(_friendly_shots(w) == 0 and is_equal_approx(target.health, 3.0), "no shots without the weapon")
	check(c.weapon == null and w.powerups.find_child("HealthBars", true, false) == null, "no health bars without the weapon")
	check(is_zero_approx(w.credits.magnet_radius) and w.score.credits == 0, "no magnet pull without the magnet")
	var e := c.equipment()
	check(not e["claws"] and not e["armor"] and not e["shield"] and e["weapon_tier"] == 0 and not e["magnet"],
		"equipment() is empty without items (%s)" % e)
	await sim.free_world(w)


func _test_each_item_alone() -> void:
	for item: String in PERMANENT:
		var w: RunWorld = sim.build_world(RunSim.layout(3), _loadout({item: 1}))
		var c: PowerupController = _controller(w)
		var ids: Array[StringName] = []
		for m: PowerupModule in c.modules:
			ids.append(m.id)
		check(ids == [StringName(item)], "a loadout with only %s runs only it (%s)" % [item, ids])
		check(c.hud_state().size() == 1 and c.hud_state()[0]["id"] == StringName(item),
			"and hud_state() lists only it")
		check((c.weapon != null) == (item == "weapon") and (c.dash != null) == (item == "dash")
			and (c.magnet != null) == (item == "magnet") and (c.slow_time != null) == (item == "slow_time")
			and (c.claws != null) == (item == "claws"), "%s: the other modules don't exist" % item)
		await sim.free_world(w)


# --- Weapon -------------------------------------------------------------------------------

func _test_targeting() -> void:
	var layout := RunSim.layout(5)
	layout.fences.append(RunSim.fence(4, 20.0, "full"))
	var w: RunWorld = sim.build_world(layout, _loadout({"weapon": 1}))
	var c: PowerupController = _controller(w)
	# Hosts and immune enemies sit nearest, on the right; the valid targets are on the left, out of
	# the line of fire to them.
	var host: Enemy = _pacer(w, 12.0, 4, {"health": 3.0, "host": true})
	var immune: Enemy = _pacer(w, 14.0, 3, {"health": 3.0, "immune": true})
	var near: Enemy = _pacer(w, 30.0, 0, {"health": 3.0})
	var far: Enemy = _pacer(w, 45.0, 1, {"health": 3.0})
	var ids: Dictionary = {host.get_instance_id(): "host", immune.get_instance_id(): "immune",
		near.get_instance_id(): "near", far.get_instance_id(): "far"}
	var targets: Array[String] = []
	var tiers: Array[int] = []
	c.fired.connect(func(t: int) -> void:
		tiers.append(t)
		targets.append(ids.get(c.weapon.last_target.get_instance_id(), "?")))
	await _run_to(w, 3.0)
	check(not targets.is_empty() and targets[0] == "near", "auto-fire picks the nearest valid target first (%s)" % [targets])
	await sim.step_world(w, 3.0)
	check(not is_instance_valid(near) or not near.alive, "and destroys it")
	check(targets.has("far"), "then moves on to the next nearest (%s)" % [targets])
	check(not targets.has("host") and not targets.has("immune"), "hosts and weapon-immune enemies are never targeted")
	check(is_equal_approx(host.health, 3.0) and is_equal_approx(immune.health, 3.0), "and never hurt")
	check(not tiers.is_empty() and tiers.count(1) == tiers.size(), "fired(tier) reports the weapon tier")
	check(w.player.alive and w.score.kills >= 1, "kills count (%d)" % w.score.kills)
	await sim.free_world(w)


## Shots leave the player's left shoulder (Razor Echo's gold arm carries the weapon), turned with
## the player onto a wall or the ceiling.
func _test_muzzle() -> void:
	var w: RunWorld = sim.build_world(RunSim.layout(3), _loadout({"weapon": 1}))
	var c: PowerupController = _controller(w)
	await _run_to(w, 5.0)
	var p: Player = w.player
	var m: Vector3 = c.weapon.muzzle_point() - p.global_position
	check(p.surface == Player.Surface.FLOOR and m.y > 0.6 and m.x < -0.1 and m.z < 0.0,
		"on the floor, shots leave the gold arm's shoulder (the left), in front (%s)" % m)
	await sim.step_world(w, 1.0, [[6.0, &"move_right"], [10.0, &"move_right"]])
	m = c.weapon.muzzle_point() - p.global_position
	check(p.surface == Player.Surface.WALL and p.wall_side == 1 and m.x < -0.6,
		"on the right wall, from the body sticking out toward the lanes (%s)" % m)
	await sim.free_world(w)

	var ceiling := RunSim.layout(3)
	ceiling.pads.append({"lane": 1, "at": 20.0})
	ceiling.hulls.append({"start": 17.0, "end": 120.0})
	w = sim.build_world(ceiling, _loadout({"weapon": 1}))
	c = _controller(w)
	await sim.step_world(w, 2.5)
	p = w.player
	m = c.weapon.muzzle_point() - p.global_position
	check(p.surface == Player.Surface.CEILING and m.y < -0.6, "on the ceiling, from the body hanging below the hull (%s)" % m)
	await sim.free_world(w)


## GDD §8 damage reference: laser tier 1 kills a hover truck or drone (15) in 15 shots, an Octodog
## (5) in 5 and a screech (1) in 1; the heavy missile (tier 4) kills a truck in 5 and a screech in 1.
## Tiers 2–3 follow the tuning.
func _test_shot_counts() -> void:
	var gdd: Dictionary = {"1/15": 15, "1/5": 5, "1/1": 1, "4/15": 5, "4/1": 1}
	for weapon_tier: int in [1, 2, 3, 4]:
		for health: float in [15.0, 5.0, 1.0]:
			var w: RunWorld = sim.build_world(RunSim.layout(3, 1200.0), _loadout({"weapon": weapon_tier}))
			var c: PowerupController = _controller(w)
			var dummy: Enemy = _pacer(w, 25.0, 1, {"health": health})
			var shots: Array[int] = [0]
			var hits: Array[int] = [0]
			c.fired.connect(func(_t: int) -> void: shots[0] += 1)
			w.projectiles.enemy_hit.connect(func(e: Enemy, _d: float, splash: bool) -> void:
				if e == dummy and not splash:
					hits[0] += 1)
			await _run_to(w, 1.0)
			for i: int in 25 * 60:
				if not is_instance_valid(dummy) or not dummy.alive:
					break
				await tree.physics_frame
			var expected: int = ceili(health / PowerupTuning.at_tier(pt.weapon_damage, weapon_tier) - 0.0001)
			var key: String = "%d/%d" % [weapon_tier, int(health)]
			if gdd.has(key):
				expected = gdd[key]
			var dead: bool = not is_instance_valid(dummy) or not dummy.alive
			check(dead and shots[0] == expected and hits[0] == expected,
				"tier %d kills health %.0f in %d shots (dead %s, fired %d, hits %d)" % [weapon_tier, health, expected,
				dead, shots[0], hits[0]])
			await sim.free_world(w)


func _test_splash() -> void:
	var w: RunWorld = sim.build_world(RunSim.layout(5, 1200.0), _loadout({"weapon": 4}))
	var c: PowerupController = _controller(w)
	var target: Enemy = _pacer(w, 30.0, 2, {"health": 15.0})
	var near: Enemy = _pacer(w, 30.0, 3, {"health": 15.0})
	var host: Enemy = _pacer(w, 30.0, 1, {"health": 15.0, "host": true})
	var swarm: Enemy = _pacer(w, 30.0, 2, {"health": 15.0, "swarm": true, "height": 2.4})
	var far: Enemy = _pacer(w, 30.0, 4, {"health": 15.0})
	await _run_to(w, 1.0)
	for i: int in 5 * 60:
		if target.health < 15.0:
			break
		await tree.physics_frame
	var d: float = PowerupTuning.at_tier(pt.weapon_damage, 4)
	check(c.weapon.last_target == target and is_equal_approx(target.health, 15.0 - d),
		"the heavy missile hits the nearest target for full damage (%.2f)" % target.health)
	check(is_equal_approx(near.health, 15.0 - d * pt.splash_damage_share),
		"its splash hits a neighbour for a share (%.2f)" % near.health)
	check(is_equal_approx(swarm.health, 15.0 - d * pt.splash_damage_share * pt.swarm_bonus_multiplier),
		"with the swarm bonus on a swarm enemy (%.2f)" % swarm.health)
	check(is_equal_approx(far.health, 15.0), "enemies beyond the splash radius are untouched")
	await sim.step_world(w, 4.0)
	check(is_equal_approx(host.health, 15.0), "splash never damages a host, however many missiles land")
	await sim.free_world(w)

	w = sim.build_world(RunSim.layout(3, 1200.0), _loadout({"weapon": 4}))
	var cluster: Enemy = _pacer(w, 30.0, 1, {"health": 30.0, "swarm": true})
	await _run_to(w, 1.0)
	for i: int in 5 * 60:
		if cluster.health < 30.0:
			break
		await tree.physics_frame
	check(is_equal_approx(cluster.health, 30.0 - d * pt.swarm_bonus_multiplier),
		"a direct heavy missile hit on a swarm enemy gets the swarm bonus (%.2f)" % cluster.health)
	await sim.free_world(w)

	w = sim.build_world(RunSim.layout(3, 1200.0), _loadout({"weapon": 3}))
	var a: Enemy = _pacer(w, 30.0, 1, {"health": 15.0})
	var b: Enemy = _pacer(w, 30.0, 2, {"health": 15.0})
	await _run_to(w, 1.0)
	for i: int in 5 * 60:
		if a.health < 15.0:
			break
		await tree.physics_frame
	check(a.health < 15.0 and is_equal_approx(b.health, 15.0), "the tier 3 missile doesn't splash")
	await sim.free_world(w)


func _test_health_bars() -> void:
	var w: RunWorld = sim.build_world(RunSim.layout(3), _loadout({"weapon": 1}))
	var bars: EnemyHealthBars = _controller(w).weapon.health_bars
	var enemy: Enemy = w.director.spawn({"type": "dummy", "script": DUMMY, "at": 40.0, "lane": 0, "seed": 1,
		"params": {"health": 3.0}})
	var host: Enemy = w.director.spawn({"type": "dummy", "script": DUMMY, "at": 40.0, "lane": 2, "seed": 2,
		"params": {"health": 3.0, "host": true}})
	var immune: Enemy = w.director.spawn({"type": "dummy", "script": DUMMY, "at": 45.0, "lane": 1, "seed": 3,
		"params": {"health": 3.0, "immune": true}})
	await tree.process_frame
	check(bars.shown().is_empty(), "no bars while every enemy is at full health")
	enemy.take_damage(1.0, &"weapon")
	host.take_damage(1.0, &"weapon")  # a host is immune_to_weapons: a stray direct hit can't clip it
	immune.take_damage(1.0, &"weapon")
	await tree.process_frame
	check(bars.is_shown(enemy), "a damaged enemy shows a health bar")
	check(not bars.is_shown(host) and not bars.is_shown(immune), "never on hosts or weapon-immune enemies")
	check(is_equal_approx(host.health, 3.0) and is_equal_approx(immune.health, 3.0),
		"a direct hit does no damage to a host or a weapon-immune enemy")
	check(bars.shown().size() == 1, "one bar (%d)" % bars.shown().size())
	enemy.take_damage(5.0, &"weapon")
	await tree.process_frame
	await tree.process_frame
	check(bars.shown().is_empty(), "the bar goes when the enemy does")
	await sim.free_world(w)


# --- Dash ---------------------------------------------------------------------------------

func _test_dash() -> void:
	# Cooldown, and a dash through a fence.
	var layout := RunSim.layout(3, 1200.0)
	layout.fences.append(RunSim.fence(1, 30.0, "full"))
	var w: RunWorld = sim.build_world(layout, _loadout({"dash": 1}))
	var c: PowerupController = _controller(w)
	var started: Array[int] = [0]
	var ready: Array[int] = [0]
	c.dash_started.connect(func() -> void: started[0] += 1)
	c.dash_ready.connect(func() -> void: ready[0] += 1)
	await _run_to(w, 20.0)
	check(c.try_dash() and w.player.dashing and started[0] == 1, "the dash starts")
	check(not c.try_dash(), "a second dash is refused while dashing")
	var r: Dictionary = await sim.step_world(w, 1.5)
	check(r["alive"] and w.player.distance > 32.0, "the dash passes through a fence (%s)" % r["cause"])
	check(not w.player.dashing and not c.try_dash(), "a second dash is refused until the cooldown is over")
	var dash_state: Dictionary = _entry(c.hud_state(), &"dash")
	check(dash_state["ready"] > 0.0 and dash_state["ready"] < 1.0 and not dash_state["active"],
		"hud_state shows the cooldown filling (%.2f)" % dash_state["ready"])
	await sim.step_world(w, pt.dash_cooldown - 1.5 + 0.1)
	check(ready[0] == 1 and is_equal_approx(_entry(c.hud_state(), &"dash")["ready"], 1.0), "dash_ready fires once it's back")
	check(c.try_dash(), "then the dash works again")
	await sim.free_world(w)

	# The dash smashes an enemy it runs into.
	w = sim.build_world(RunSim.layout(3), _loadout({"dash": 1}))
	c = _controller(w)
	var causes: Array[StringName] = []
	w.director.enemy_defeated.connect(func(_e: Enemy, cause: StringName) -> void: causes.append(cause))
	w.director.spawn({"type": "dummy", "script": DUMMY, "at": 30.0, "lane": 1, "seed": 1})
	await _run_to(w, 20.0)
	c.try_dash()
	r = await sim.step_world(w, 1.5)
	check(r["alive"] and causes == [&"dash"] and w.score.kills == 1, "a dash smashes an enemy (%s, %s)" % [r["cause"], causes])
	await sim.free_world(w)

	# The named input action (Shift on PC, a tap on mobile through TouchInput) starts it.
	w = sim.build_world(RunSim.layout(3), _loadout({"dash": 1}))
	await _run_to(w, 5.0)
	await _send_action(&"dash")
	check(w.player.dashing, "the dash action starts the dash")
	await sim.free_world(w)


# --- Magnet -------------------------------------------------------------------------------

func _test_magnet() -> void:
	for magnet_tier: int in [1, 2, 3]:
		var layout := RunSim.layout(3)
		layout.credits.append({"at": 40.0, "surface": "floor", "lane": 2, "side": 0, "height": 0.7, "value": 5})
		var w: RunWorld = sim.build_world(layout, _loadout({"magnet": magnet_tier}))
		var radius: float = PowerupTuning.at_tier(pt.magnet_radius, magnet_tier)
		check(is_equal_approx(w.credits.magnet_radius, radius) and is_equal_approx(w.credits.magnet_pull_speed, pt.magnet_pull_speed),
			"magnet tier %d sets a %.1f m pull" % [magnet_tier, radius])
		await sim.step_world(w, 3.0)
		var reaches: bool = radius >= w.geo.lane_width
		check((w.score.credits == 5) == reaches, "tier %d %s the next lane (%d)" % [magnet_tier,
			"pulls from" if reaches else "doesn't reach", w.score.credits])
		await sim.free_world(w)


# --- Slow time ----------------------------------------------------------------------------

func _test_slow_time() -> void:
	var w: RunWorld = sim.build_world(RunSim.layout(3, 2000.0), _loadout({"slow_time": 1}))
	var c: PowerupController = _controller(w)
	var changes: Array[bool] = []
	var ended_at: Array[float] = [0.0]
	c.slow_time_changed.connect(func(on: bool) -> void:
		changes.append(on)
		if not on:
			ended_at[0] = w.player.elapsed)
	check(not c.try_slow_time(), "slow time needs a running player")
	await _run_to(w, 5.0)
	var before: float = w.player.distance
	await tree.physics_frame
	var normal_step: float = w.player.distance - before
	check(c.try_slow_time() and is_equal_approx(Engine.time_scale, pt.slow_time_scale) and changes == [true],
		"slow time scales the world (%.2f)" % Engine.time_scale)
	var started_at: float = w.player.elapsed
	check(not c.try_slow_time(), "pressing it again while slowed does nothing")
	await tree.physics_frame
	before = w.player.distance
	await tree.physics_frame
	check(absf((w.player.distance - before) - normal_step * pt.slow_time_scale) < 0.001,
		"the player moves slower per frame (%.3f vs %.3f m)" % [w.player.distance - before, normal_step])
	await sim.step_world(w, pt.slow_time_duration - 0.2)
	check(c.slow_time.active, "it lasts its duration in real seconds")
	await sim.step_world(w, 0.3)
	check(not c.slow_time.active and is_equal_approx(Engine.time_scale, 1.0) and changes == [true, false],
		"then normal time comes back")
	var slowed: float = ended_at[0] - started_at
	check(absf(slowed - pt.slow_time_duration * pt.slow_time_scale) < 0.05,
		"%.1f real seconds were %.2f game seconds" % [pt.slow_time_duration, slowed])
	check(not c.try_slow_time(), "then it cools down")
	await sim.step_world(w, pt.slow_time_cooldown - 1.0)
	check(not c.try_slow_time() and _entry(c.hud_state(), &"slow_time")["ready"] < 1.0, "for its whole cooldown")
	await sim.step_world(w, 1.2)
	await _send_action(&"slow_time")
	check(c.slow_time.active and Engine.time_scale < 1.0, "and can then be used again, with the slow_time action (E)")
	await sim.free_world(w)
	check(is_equal_approx(Engine.time_scale, 1.0), "freeing the world restores normal time")


func _test_slow_time_restores() -> void:
	var scenarios: Array[String] = ["end of run", "freed controller", "death", "pause"]
	for scenario: String in scenarios:
		var w: RunWorld = sim.build_world(RunSim.layout(3, 1200.0), _loadout({"slow_time": 1}))
		var c: PowerupController = _controller(w)
		await _run_to(w, 5.0)
		check(c.try_slow_time() and Engine.time_scale < 1.0, "%s: slowed" % scenario)
		match scenario:
			"end of run":
				w.player.running = false
				await tree.physics_frame
			"freed controller":
				c.queue_free()
				await tree.process_frame
			"death":
				w.player._die("test hazard")
			"pause":
				tree.paused = true
				check(is_equal_approx(Engine.time_scale, 1.0), "pause: normal time while the game is paused")
				check(not c.can_process(), "pause: the power-ups pause with the game")
				await tree.process_frame
				tree.paused = false
				check(is_equal_approx(Engine.time_scale, pt.slow_time_scale) and c.slow_time.active,
					"pause: the slow-down resumes after unpausing")
				w.player._die("test hazard")
		check(is_equal_approx(Engine.time_scale, 1.0), "%s: normal time is restored (%.2f)" % [scenario, Engine.time_scale])
		await tree.physics_frame
		check(is_equal_approx(Engine.time_scale, 1.0), "%s: and stays restored" % scenario)
		await sim.free_world(w)
		Engine.time_scale = 1.0


func _test_slow_time_mobile() -> void:
	var was_mobile: bool = App.mobile
	App.mobile = true
	var w: RunWorld = sim.build_world(RunSim.layout(3), _loadout({"slow_time": 1, "dash": 1}))
	var c: PowerupController = _controller(w)
	await _run_to(w, 5.0)
	await _send_action(&"slow_time")
	check(c.slow_time == null and not c.try_slow_time() and is_equal_approx(Engine.time_scale, 1.0),
		"slow time isn't available on mobile (GDD §3)")
	check(_entry(c.hud_state(), &"slow_time").is_empty() and not _entry(c.hud_state(), &"dash").is_empty(),
		"and isn't in the mobile HUD state; the dash is")
	await sim.free_world(w)
	App.mobile = was_mobile


## Through the real App: pause menu, quitting the run, and a death in quick play.
func _test_slow_time_through_app() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var saved: Profile = App.profile
	App.profile = Profile.new()
	App.start_quick(PackedStringArray(["--full-loadout"]))
	await physics_frames(10)
	var c: PowerupController = App.run.world.powerups as PowerupController
	check(c != null and c.slow_time != null and c.try_slow_time() and Engine.time_scale < 1.0, "app: slowed in a quick run")
	App.pause_game()
	check(is_equal_approx(Engine.time_scale, 1.0), "app: the pause menu runs at normal speed")
	App.resume_game()
	check(Engine.time_scale < 1.0, "app: resuming continues the slow-down")
	App.run.world.score.credits = 50  # quick play never pays the wallet, quit or not (a review tool)
	var wallet_before: int = App.profile.credits()
	App.quit_run()
	await tree.process_frame
	check(is_equal_approx(Engine.time_scale, 1.0) and App.run == null, "app: quitting the run restores normal time")
	check(App.profile.credits() == wallet_before, "app: quitting a quick-play run doesn't touch the wallet")

	App.start_quick(PackedStringArray(["--full-loadout"]))
	await physics_frames(10)
	c = App.run.world.powerups as PowerupController
	check(c.try_slow_time(), "app: slowed again")
	App.run.world.player._die("test hazard")
	check(is_equal_approx(Engine.time_scale, 1.0), "app: dying restores normal time")
	App.show_title()
	await tree.process_frame
	App.profile = saved
	main.queue_free()
	App.main = null
	await tree.process_frame
	Engine.time_scale = 1.0


# --- HUD and player model -----------------------------------------------------------------

func _test_hud_state() -> void:
	var layout := RunSim.layout(5, 1500.0)
	layout.fences.append(RunSim.fence(2, 30.0, "full"))
	var w: RunWorld = sim.build_world(layout, Loadout.full(App.catalog))
	var c: PowerupController = _controller(w)
	var ids: Array[StringName] = []
	for e: Dictionary in c.hud_state():
		ids.append(e["id"])
		check(e.has_all(["id", "icon", "tier", "ready", "active", "charges"]), "%s: every hud_state key" % e["id"])
	check(ids == [&"weapon", &"claws", &"dash", &"magnet", &"slow_time", &"armor", &"shield", &"grapple"],
		"hud_state lists the full loadout in shop order (%s)" % [ids])
	var weapon: Dictionary = _entry(c.hud_state(), &"weapon")
	check(weapon["tier"] == 4 and weapon["icon"] == &"weapon" and _entry(c.hud_state(), &"magnet")["tier"] == 3,
		"with tiers and icons")
	check(_entry(c.hud_state(), &"armor")["charges"] == 1 and _entry(c.hud_state(), &"armor")["active"],
		"armor carries its charge")
	var eq: Dictionary = c.equipment()
	check(eq == {"claws": true, "armor": true, "shield": true, "weapon_tier": 4, "magnet": true},
		"equipment() for the player model (%s)" % eq)
	var changed: Array[Dictionary] = []
	c.equipment_changed.connect(func(e: Dictionary) -> void: changed.append(e))

	await _run_to(w, 36.0)
	var armor: Dictionary = _entry(c.hud_state(), &"armor")
	check(w.player.alive and armor["charges"] == 0 and not armor["active"], "armor used up on a fence: 0 charges")
	check(not changed.is_empty() and not changed[-1]["armor"] and changed[-1]["shield"], "equipment_changed reports it")

	c.try_dash()
	c.try_slow_time()
	await tree.physics_frame
	var dash: Dictionary = _entry(c.hud_state(), &"dash")
	var slow: Dictionary = _entry(c.hud_state(), &"slow_time")
	check(dash["active"] and dash["ready"] < 0.1 and slow["active"] and is_zero_approx(slow["ready"]),
		"dash and slow time show active, cooling down")
	await sim.step_world(w, pt.slow_time_duration + 0.2)
	slow = _entry(c.hud_state(), &"slow_time")
	check(not slow["active"] and slow["ready"] < 0.1, "slow time's cooldown starts when it ends")
	await sim.step_world(w, pt.slow_time_cooldown + 0.2)
	check(is_equal_approx(_entry(c.hud_state(), &"dash")["ready"], 1.0) and is_equal_approx(_entry(c.hud_state(), &"slow_time")["ready"], 1.0),
		"both ready again")
	await sim.free_world(w)
	Engine.time_scale = 1.0

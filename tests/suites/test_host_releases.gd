extends TestSuite
## Weapons hit hosts (task H8; GDD §9.7, owner, October 8, 2026, replacing the September 26 rule that made hosts
## immune to all weapon damage), and what that does to the campaign's fairness:
## - auto-fire targets a host, never a fence generator beside it (GDD §9.1), and a heavy missile's splash on the
##   host spares the generator; a splash that kills a host releases its Bad Dream; the shared damage rules let a
##   weapon kill a host, never another enemy's charge (Enemy.charge_can_hurt, DESIGN-TBD);
## - over the campaign's host levels (Dead Zone 1–2, Golden 1–3) a runner carrying the weapon (tier 2, whose
##   kills come furthest ahead of the hosts' spots: tools/measure/host_releases.gd) shoots hosts down ahead of
##   their spots, yet every chase begins where the generator planned it (a Bad Dream released ahead lurks until
##   the runner comes, BadDream) and keeps the generator's guarantees (host_rules.gd): its anti-grav pads, nothing
##   the generator keeps off chases met outside the planned stretch, one chase at a time, no slash during an
##   Octodog's charge or a drone's barrage (tools/measure/host_watch.gd, attack_watch.gd); and in every host
##   level's layout at 3, 5 and 6 lanes, nothing the generator keeps off chases lies where a chase may begin
##   early (from a lurk or a host that walked toward the runner).
## The full sweep over every weapon tier and lane count is tools/measure/host_releases.gd (docs/ARCHITECTURE.md,
## Review tools).

const AttackWatch = preload("res://tools/measure/attack_watch.gd")
const HostWatch = preload("res://tools/measure/host_watch.gd")
const HostRules = preload("res://scripts/enemies/host_rules.gd")
const HOST_LEVELS: Array[String] = ["dead_zone/1", "dead_zone/2", "golden/1", "golden/2", "golden/3"]
## Each host level played once, at a lane count of its own (all three lane counts are covered). Golden 2 at 5 lanes
## since the owner's October 10, 2026 call (task I1): in its 3-lane build the tier-2 weapon no longer shoots a host
## down ahead of its spot.
const PLAYED: Array = [["dead_zone/1", 5], ["dead_zone/2", 3], ["golden/1", 6], ["golden/2", 5], ["golden/3", 5]]
## The weapon tier played: tier 2 kills hosts furthest ahead of their spots (a median of 1.48 s of run measured,
## against tier 3's 1.06 s and tier 4's 1.23 s; tier 1's 42 m never reached a host before the runner did).
const TIER: int = 2

var sim: RunSim
var t: BadDreamTuning
var ct: CyborgTuning


func run() -> void:
	sim = RunSim.new(tree, tuning)
	t = HostRules.tuning()
	ct = EnemyDirector.tuning_for("cyborg") as CyborgTuning
	check(ct != null, "the cyborg tuning loads")
	if ct == null:
		return
	await _test_targets_hosts_not_generators()
	await _test_splash_kill()
	await _test_charge_rules()
	_test_layouts()
	await _test_campaign()


## Auto-fire targets a host and never the fence generator beside it; the heavy missile's splash on the host
## spares the generator; the host's Bad Dream bursts out of it.
func _test_targets_hosts_not_generators() -> void:
	var l := Loadout.new()
	l.tiers[&"weapon"] = 4
	var w: RunWorld = sim.build_world(RunSim.layout(3, 600.0), l)
	w.player.setup(tuning, w.geo, 0)
	var host := w.director.spawn({"type": "cyborg", "at": 60.0, "lane": 2, "side": 0, "seed": 3,
		"params": {"host": true, "panic": false, "fires": false, "stand": true}}) as Cyborg
	var generator: Enemy = w.director.spawn({"type": "generator", "at": 61.5, "lane": 2, "side": 0, "seed": 4, "params": {}})
	var beside: bool = generator.aim_point().distance_to(host.aim_point()) < w.powerup_tuning.splash_radius
	var weapon: WeaponPowerup = (w.powerups as PowerupController).weapon
	var targets: Array[Enemy] = []
	(w.powerups as PowerupController).fired.connect(func(_tier: int) -> void: targets.append(weapon.last_target))
	var causes: Dictionary = {}
	w.director.enemy_defeated.connect(func(e: Enemy, cause: StringName) -> void: causes[e.get_instance_id()] = cause)
	var gen_health: float = generator.health
	var ahead: Array[Enemy] = w.director.targets_ahead(Vector3(0.0, 0.8, 0.0), 200.0)
	check(ahead.has(host) and not ahead.has(generator) and not generator.targetable(),
		"auto-fire may target the host, never the fence generator beside it")
	await tree.physics_frame
	w.player.running = true
	for i: int in 4 * 60:
		await tree.physics_frame
		if not host.alive:
			break
	await physics_frames(3)
	check(not host.alive and causes.get(host.get_instance_id(), &"") == &"weapon", "the weapon kills the host")
	check(not targets.is_empty() and not targets.has(generator), "and never fired at the generator (%d shots)" % targets.size())
	check(beside and generator.alive and is_equal_approx(generator.health, gen_health),
		"the heavy missile's splash on the host, beside it, spares the generator")
	check(w.director.count_alive(&"bad_dream") == 1, "the host's Bad Dream bursts out")
	await sim.free_world(w)


## A heavy missile's splash that kills a host beside its target releases the host's Bad Dream like a direct hit
## would: a weapon kill, with the kill's score and no host bonus (CyborgTuning.weapon_host_bonus, DESIGN-TBD).
func _test_splash_kill() -> void:
	var w: RunWorld = sim.build_world(RunSim.layout(3, 400.0))
	var target := w.director.spawn({"type": "cyborg", "at": 40.0, "lane": 1, "side": 0, "seed": 1,
		"params": {"panic": false, "fires": false, "stand": true}}) as Cyborg
	var host := w.director.spawn({"type": "cyborg", "at": 41.0, "lane": 2, "side": 0, "seed": 2,
		"params": {"host": true, "fires": false, "stand": true, "health": 1.0}}) as Cyborg
	var splashed: Array[bool] = [false]
	w.projectiles.enemy_hit.connect(func(e: Enemy, _dmg: float, splash: bool) -> void:
		if e == host and splash:
			splashed[0] = true)
	await tree.physics_frame
	w.projectiles.fire_player(target.aim_point() + Vector3(0.0, 0.0, 6.0), Vector3(0.0, 0.0, -80.0), 1.0,
		&"heavy_missile", null, 0.0, 5.0, 1.0)
	await physics_frames(12)
	check(splashed[0] and not host.alive and target.alive,
		"a heavy missile's splash on the cyborg beside it kills the host (target %.1f health left)" % target.health)
	check(w.director.count_alive(&"bad_dream") == 1, "and its Bad Dream bursts out")
	check(int(w.score.bonuses.get(&"host", 0)) == ct.weapon_host_bonus and w.score.kills == 1,
		"a weapon kill: the kill's score, no host bonus (%s)" % str(w.score.bonuses))
	await sim.free_world(w)


## The shared damage rules (Enemy): a weapon hurts a host, another enemy's charge never does (DESIGN-TBD,
## docs/OPEN_QUESTIONS.md item 629); a plain cyborg takes both; a fence generator neither.
func _test_charge_rules() -> void:
	var w: RunWorld = sim.build_world(RunSim.layout(3, 400.0))
	var host: Enemy = w.director.spawn({"type": "cyborg", "at": 60.0, "lane": 0, "side": 0, "seed": 3,
		"params": {"host": true, "fires": false}})
	var cyborg: Enemy = w.director.spawn({"type": "cyborg", "at": 60.0, "lane": 1, "side": 0, "seed": 5,
		"params": {"fires": false, "panic": false}})
	var generator: Enemy = w.director.spawn({"type": "generator", "at": 60.0, "lane": 2, "side": 0, "seed": 4, "params": {}})
	check(not host.charge_can_hurt() and cyborg.charge_can_hurt() and not generator.charge_can_hurt(),
		"charges hurt a plain cyborg, never a host or a fence generator")
	for e: Enemy in [host, cyborg, generator]:
		e.set_physics_process(false)
	var before: Array[float] = [host.health, cyborg.health, generator.health]
	host.take_damage(1.0, Enemy.CHARGE_DAMAGE_CAUSE)
	cyborg.take_damage(1.0, Enemy.CHARGE_DAMAGE_CAUSE)
	generator.take_damage(1.0, Enemy.CHARGE_DAMAGE_CAUSE)
	check(is_equal_approx(host.health, before[0]) and is_equal_approx(cyborg.health, before[1] - 1.0)
		and is_equal_approx(generator.health, before[2]), "a charge's contact passes the host and the generator by")
	host.take_damage(1.0, &"weapon")
	generator.take_damage(1.0, &"weapon")
	check(is_equal_approx(host.health, before[0] - 1.0) and is_equal_approx(generator.health, before[2]),
		"a weapon hurts the host, never the generator")
	await sim.free_world(w)


## Every host level's layout at 3, 5 and 6 lanes: where a chase may begin before its planned stretch (a host
## walks up to walk_max toward the runner, and a Bad Dream shot down ahead lurks until the runner is within
## hover_ahead of it), nothing lies that the generator keeps off chases for reasons of its own (HostWatch's list:
## zone doodads, a floor cut's attack, a wall fence's drop window, an Octodog's charges, a Gilded Sentinel's
## attack, a cyborg planted in a charge's path).
func _test_layouts() -> void:
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var early: float = ct.walk_max + t.hover_ahead
	var hosts: int = 0
	for id: String in HOST_LEVELS:
		for lanes: int in [3, 5, 6]:
			var config: LevelConfig = campaign.configure(campaign.step(id), lanes)
			config.skin = null
			var gen: LevelGenerator = LayoutCache.generator(config, tuning, LevelGenerator.load_for(config))
			var kept: Array[Dictionary] = HostWatch.kept_off_chases(gen)
			for e: Dictionary in HostRules.hosts_in(gen.layout):
				hosts += 1
				var at: float = float(e["at"])
				var met: PackedStringArray = []
				for k: Dictionary in kept:
					var span: Vector2 = k["span"]
					if span.x < at and span.y >= at - early:
						met.append("%s %.0f-%.0f" % [k["what"], span.x, span.y])
				check(met.is_empty(), "%s at %d lanes: nothing kept off chases where the host at %.0f's chase may begin (%.1f m before it): %s"
					% [id, lanes, at, early, met])
	check(hosts >= 15, "the host levels keep their hosts (%d)" % hosts)


## The host levels played with the weapon (see the header): each one once, a god-mode runner in the middle
## lane stomping any host the weapon leaves (AttackWatch).
func _test_campaign() -> void:
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var weapon_kills: int = 0
	for case: Array in PLAYED:
		var tag: String = "%s at %d lanes" % [case[0], case[1]]
		var config: LevelConfig = campaign.configure(campaign.step(case[0]), case[1])
		config.skin = null
		var layout: LevelLayout = LayoutCache.generate(config, tuning, LevelGenerator.load_for(config))
		var l := Loadout.new()
		l.tiers[&"weapon"] = TIER
		var w: RunWorld = sim.build_world(layout, l, null, config)
		w.player.god_mode = true
		w.player.grapples = 1_000_000
		var attacks := AttackWatch.new(w, true)
		var hosts := HostWatch.new(w)
		await tree.physics_frame
		w.player.running = true
		while w.player.distance < layout.length:
			await tree.physics_frame
			attacks.observe()
			hosts.observe()
		var gen: LevelGenerator = LevelGenerator.for_layout(config, tuning, layout)
		var r: Dictionary = hosts.check(gen)
		var planned: int = HostRules.hosts_in(layout).size()
		check(planned > 0 and (r["chases"] as Array).size() == planned and int(r["released"]) == planned,
			"%s: every host releases its Bad Dream and its chase begins (%d of %d)" % [tag, int(r["released"]), planned])
		check(int(r["fizzled"]) == 0 and int(r["overlapping"]) == 0,
			"%s: one chase at a time: none fizzled (%d), none overlaps the next (%d)" % [tag, int(r["fizzled"]), int(r["overlapping"])])
		var shot_ahead: int = 0
		for c: Dictionary in r["chases"]:
			var x: String = "(host at %.0f, %s, killed at %.0f, chase %.0f-%.0f) %s" % [float(c["host_at"]), c["cause"],
				float(c["kill_d"]), float(c["begin_d"]), float(c["end_d"]), tag]
			if String(c["cause"]) == "weapon" and float(c["host_at"]) - float(c["kill_d"]) > 0.5 * gen.speed:
				shot_ahead += 1
			if not c.has("planned"):
				continue
			check(float(c["early"]) <= ct.walk_max + t.hover_ahead + 0.5,
				"its chase begins where the generator planned it: %.1f m before its stretch at most %.1f %s"
				% [float(c["early"]), ct.walk_max + t.hover_ahead, x])
			check(float(c["pad_gap_claws"]) <= t.pad_gap_seconds + 0.05,
				"from its first claws, never more than %.0f s without an anti-grav pad (%.2f s) %s"
				% [t.pad_gap_seconds, float(c["pad_gap_claws"]), x])
			check(float(c["pad_gap"]) <= t.pad_gap_seconds + (ct.walk_max + t.hover_ahead) / gen.speed + 0.05,
				"from its start, no longer without a pad than a chase begun at its host (%.2f s) %s" % [float(c["pad_gap"]), x])
			check((c["kept"] as PackedStringArray).is_empty(),
				"it meets nothing the generator keeps off chases outside its planned stretch (%s) %s" % [c["kept"], x])
			if float(c["telegraph_d"]) >= 0.0:
				check(float(c["telegraph_ahead"]) <= t.hover_ahead + 1.5,
					"its first telegraph comes from its hover spot in front of the runner (%.1f m ahead) %s"
					% [float(c["telegraph_ahead"]), x])
		weapon_kills += shot_ahead
		check(shot_ahead > 0, "%s: the weapon shoots hosts down ahead of their spots (%d)" % [tag, shot_ahead])
		var pairs: Dictionary = attacks.overlap_pairs
		var exclusive: float = 0.0
		for pair: String in pairs:
			if pair.contains("bad_dream") and (pair.contains("octodog") or pair.contains("drone")):
				exclusive += float(pairs[pair])
		check(is_zero_approx(exclusive), "%s: no slash with an Octodog's charge or a drone's barrage open (%.2f s)" % [tag, exclusive])
		check(int(attacks.attacks.get("dream_slash", 0)) > 0, "%s: the Bad Dreams slash (%s)" % [tag, attacks.attacks])
		await sim.free_world(w)
	check(weapon_kills >= PLAYED.size(), "hosts shot down ahead of their spots in every level (%d)" % weapon_kills)

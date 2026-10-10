extends TestSuite
## Cyborgs in charge paths (task G7; owner, October 7, 2026, answering open question 353; GDD §9.13 "Teaching":
## "occasionally a cyborg stands in the path of an Octodog's lunge or a Buzz Overdrive's charge, so the player
## sees a charge flatten another enemy. At least one comes before the Enforcer's first appearance in Corporate
## 2"; ChargePathPlacement, data/tuning/charge_paths.tres):
## - The campaign at 3, 5 and 6 lanes: each level with Octodogs or Buzz Overdrives asks for one, the others none;
##   each planted cyborg is a plain floor cyborg (never a host, the panic variant or a window cyborg) standing in
##   its charge's planned path, reached in view, holding its fire, with no other big attack planned around it
##   (LayoutChecks.check_charge_paths); at least one comes before the Enforcer Truck's first appearance in
##   Corporate 2; how many each level got is printed.
## - On real physics, at 3, 5 and 6 lanes, at quick play's speed and Corporate 2's (its enemy scaling too): an
##   Octodog's planted lunge (the dog in an outer lane and in the middle one, which a 3-lane track moves to an
##   outer lane) and a parked Buzz Overdrive's charge (in an outer lane and the middle one), each planned and
##   planted by the placement itself on a plain track, flatten their cyborg (Enemy.CHARGE_DAMAGE_CAUSE, never the
##   player's kill) with the runner still in_view_seconds behind it; no bolt of the cyborg's lands, and none is
##   charged, while the runner is in its hold_fire stretch; a runner who leaves the charge's far lane (the cut's
##   lane) a reaction after its warning is never touched, and one who stays is hit (the attack is real).
## - In the campaign's own builds, played from the level's start by a scripted runner (god mode, grapples, no
##   weapons): at each lane count the first planted Octodog encounter (the one that teaches it) and the earliest
##   planted Buzz Overdrive encounter flatten their cyborgs in view, the cyborg holding its fire.
## - Off: quick play, the prototype level and a boss arena (even asked) plant nothing; a level plants the same
##   on every attempt.

const OctodogRules = preload("res://scripts/enemies/octodog_rules.gd")
const BuzzRules = preload("res://scripts/enemies/buzz_overdrive_rules.gd")
const EnforcerRules = preload("res://scripts/enemies/enforcer_truck_rules.gd")
const LANES: Array[int] = [3, 5, 6]
## Seconds after a charge's warning starts that the scripted runner leaves its lane (a dog's wind-up; a cut's
## warning uses the level's cut_reaction_seconds, as test_buzz_overdrive's runner).
const DOG_REACTION: float = 0.3

var sim: RunSim
var t: ChargePathTuning
var frame: float = 1.0 / 60.0


func run() -> void:
	sim = RunSim.new(tree, tuning)
	t = ChargePathPlacement.tuning()
	frame = 1.0 / float(Engine.physics_ticks_per_second)
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	_test_campaign(campaign)
	_test_off(campaign)
	var c2: LevelConfig = campaign.configure(campaign.step("corporate/2"), 5)
	c2.skin = null
	var paces: Array[LevelConfig] = [LevelConfig.new(), c2]
	await _test_dog_physics(paces)
	await _test_tank_physics(paces)
	await _test_campaign_plays(campaign)


# --- Campaign --------------------------------------------------------------------------------------

func _test_campaign(campaign: Campaign) -> void:
	for lanes: int in LANES:
		var before_enforcer: int = 0
		var line: PackedStringArray = []
		for s: CampaignStep in campaign.steps():
			if not s.is_level():
				continue
			var config: LevelConfig = campaign.configure(s, lanes)
			var tag: String = "%s at %d lanes" % [s.id, lanes]
			var charges: bool = config.has_feature("octodog") or config.has_feature("buzz_overdrive")
			check(config.charge_path_cyborgs == (1 if charges else 0),
				"%s asks for %d cyborgs in charge paths (%d)" % [tag, 1 if charges else 0, config.charge_path_cyborgs])
			var gen: LevelGenerator = LayoutCache.generator(config, tuning, LevelGenerator.load_for(config))
			var planted: Array[Dictionary] = ChargePathPlacement.planted_in(gen.layout)
			LayoutChecks.check_charge_paths(self, gen.layout, config, tag)
			for e: Dictionary in planted:
				var params: Dictionary = e["params"]
				check(String(e["type"]) == "cyborg" and not bool(params.get("host", false)) and not bool(params.get("panic", true)),
					"%s: a planted cyborg is a plain one, never a host (%s)" % [tag, params])
			var enforcer: float = INF
			for e: Dictionary in EnforcerRules.trucks_in(gen.layout):
				enforcer = minf(enforcer, float(e["at"]))
			if before_enforcer >= 0:
				for e: Dictionary in planted:
					var charger: Dictionary = ChargePathPlacement.charger_of(gen.layout, e)
					if float(charger.get("at", INF)) < enforcer:
						before_enforcer += 1
				if enforcer < INF:
					check(before_enforcer >= 1,
						"at %d lanes a charge flattens a cyborg before the Enforcer Truck's first appearance (%s at %.0f m): %d"
						% [lanes, s.id, enforcer, before_enforcer])
					before_enforcer = -1
			if charges:
				var kinds: PackedStringArray = []
				for e: Dictionary in planted:
					kinds.append("%s at %.0f m" % [String(e["params"][ChargePathPlacement.PARAM]), float(e["at"])])
				line.append("%s %s" % [s.id, ", ".join(kinds) if not kinds.is_empty() else "none (%s)" % ", ".join(
					gen.charge_path_result.get("constraints", []))])
		print("  %d lanes: %s" % [lanes, "; ".join(line)])


func _test_off(campaign: Campaign) -> void:
	for s: CampaignStep in campaign.steps():
		if s.boss == null or s.boss.arena == null:
			continue
		var config: LevelConfig = BossArena.base_config(s.boss)
		config.lane_count = 5
		config.charge_path_cyborgs = 2
		var gen := LevelGenerator.new()
		var layout: LevelLayout = gen.generate(config, tuning, LevelGenerator.load_for(config))
		check(gen.charge_path_result.is_empty() and ChargePathPlacement.planted_in(layout).is_empty(),
			"%s: nothing planted in a boss arena, even asked" % config.id)
	var quick := LevelConfig.new()
	quick.features = PackedStringArray(["cyborg", "octodog", "buzz_overdrive"])
	var prototype := load("res://data/levels/prototype_level.tres") as LevelConfig
	for config: LevelConfig in [quick, prototype]:
		var gen := LevelGenerator.new()
		var layout: LevelLayout = gen.generate(config, tuning, LevelGenerator.load_for(config))
		check(config.charge_path_cyborgs == 0 and gen.charge_path_result.is_empty() and ChargePathPlacement.planted_in(layout).is_empty(),
			"%s asks for none and plants nothing" % ("quick play" if config == quick else "the prototype level"))
	# Golden 2 (Buzz Overdrive charges, no Octodogs) at a lane count where it plants one: the same on every
	# attempt. Which lane counts it plants at moves with its layout (6 lanes before the Casino's levels
	# re-spaced the campaign's curve, task K2; 5 on K2's curve; 3 on task K4's).
	var planted_at: int = 0
	for lanes: int in [6, 5, 3]:
		var g2: LevelConfig = campaign.configure(campaign.step("golden/2"), lanes)
		var a := LevelGenerator.new()
		var first: LevelLayout = a.generate(g2, tuning, LevelGenerator.load_for(g2))
		if ChargePathPlacement.planted_in(first).is_empty():
			continue
		var b := LevelGenerator.new()
		var again: LevelLayout = b.generate(g2, tuning, LevelGenerator.load_for(g2))
		check(first.to_dict() == again.to_dict(), "Golden 2 plants the same on every attempt (%d lanes)" % lanes)
		planted_at = lanes
		break
	check(planted_at > 0, "Golden 2 plants a cyborg in a charge path at some lane count")


# --- Real physics ------------------------------------------------------------------------------------

## A plain track at `base`'s speed and enemy scaling with one Octodog in `dog_lane`, its first lunge from its spot
## when the runner is 6 s of run plus 20 m in, planned and planted by the placement (dog_option, plant).
## {layout, config, movement, planted, far (the lane its lunge ends in)}, or {why}.
func _dog_encounter(base: LevelConfig, lanes: int, dog_lane: int) -> Dictionary:
	var config: LevelConfig = base.duplicate() as LevelConfig
	config.lane_count = lanes
	var movement: MovementTuning = config.movement_for(tuning)
	var v: float = movement.run_speed
	var layout := RunSim.layout(lanes, 30.0 * v)
	var gen: LevelGenerator = LevelGenerator.for_layout(config, tuning, layout)
	var a0: float = 6.0 * v + 20.0
	var d: float = a0 + OctodogRules.tuning().stop_distance(v, config.enemy_scaling, gen.pace)
	var dog := {"type": "octodog", "at": d, "lane": dog_lane, "side": 0, "seed": 11,
		"params": {"doghouse": false, "charges": 1, "charge_at": [a0]}}
	layout.enemies.append(dog)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var option: Dictionary = ChargePathPlacement.dog_option(gen, t, rng, dog)
	if not option.has("cyborg"):
		return {"why": String(option.get("why", "?"))}
	var planted: Dictionary = ChargePathPlacement.plant(gen, option, 0)
	var through: int = int((planted["cyborg"] as Dictionary)["lane"])
	return {"layout": layout, "config": config, "movement": movement, "planted": planted,
		"far": through + (through - int(dog["lane"]))}


## As _dog_encounter, a Buzz Overdrive whose cut in `lane` sets off with the runner 6 s of run plus 20 m in
## (tank_option, plant: its cut parked). {layout, config, movement, planted, far (the cut's lane), cut}, or {why}.
func _tank_encounter(base: LevelConfig, lanes: int, lane: int) -> Dictionary:
	var config: LevelConfig = base.duplicate() as LevelConfig
	config.lane_count = lanes
	var movement: MovementTuning = config.movement_for(tuning)
	var v: float = movement.run_speed
	var cut: Dictionary = BuzzRules.plan_for(BuzzRules.tuning(), lane, 6.0 * v + 20.0, v, movement.pace(), config.enemy_scaling)
	var layout := RunSim.layout(lanes, float(cut["end"]) + 20.0 * v)
	layout.cuts.append(cut)
	var tank := {"type": "buzz_overdrive", "at": float(cut["end"]), "lane": lane, "side": 0, "seed": 11, "params": {}}
	layout.enemies.append(tank)
	var gen: LevelGenerator = LevelGenerator.for_layout(config, tuning, layout)
	var option: Dictionary = ChargePathPlacement.tank_option(gen, t, tank)
	if not option.has("cyborg"):
		return {"why": String(option.get("why", "?"))}
	var planted: Dictionary = ChargePathPlacement.plant(gen, option, 0)
	return {"layout": layout, "config": config, "movement": movement, "planted": planted, "far": lane, "cut": cut}


func _test_dog_physics(paces: Array[LevelConfig]) -> void:
	for base: LevelConfig in paces:
		for lanes: int in LANES:
			for dog_lane: int in [0, lanes / 2]:
				var enc: Dictionary = _dog_encounter(base, lanes, dog_lane)
				var v: float = (base.movement_for(tuning)).run_speed
				var tag: String = "(Octodog in lane %d, %d lanes, %.1f m/s)" % [dog_lane, lanes, v]
				check(enc.has("planted"), "%s a fair planted lunge is found (%s)" % [tag, enc.get("why", "")])
				if not enc.has("planted"):
					continue
				var far: int = int(enc["far"])
				var away: int = far + (far - int((enc["planted"]["cyborg"] as Dictionary)["lane"]))
				if away < 0 or away >= lanes:
					away = int((enc["planted"]["cyborg"] as Dictionary)["lane"])
				var r: Dictionary = await _play_encounter(enc, far, away)
				_check_flattened(r, enc, "%s, the runner leaving its far lane %d for lane %d" % [tag, far, away])
				check(bool(r["alive"]) and not bool(r["hit"]), "%s a runner who leaves its far lane after its wind-up starts is never touched (%s)"
					% [tag, r["death"]])
				if dog_lane == 0:
					var stay: Dictionary = await _play_encounter(enc, far, -1)
					check(not bool(stay["alive"]) or bool(stay["hit"]), "%s a runner who stays in its far lane is hit" % tag)
					check(String(stay["cause"]) == String(Enemy.CHARGE_DAMAGE_CAUSE), "%s and the cyborg is flattened first (%s)"
						% [tag, stay["cause"]])


func _test_tank_physics(paces: Array[LevelConfig]) -> void:
	for base: LevelConfig in paces:
		for lanes: int in LANES:
			for lane: int in [0, lanes / 2]:
				var enc: Dictionary = _tank_encounter(base, lanes, lane)
				var v: float = (base.movement_for(tuning)).run_speed
				var tag: String = "(Buzz Overdrive in lane %d, %d lanes, %.1f m/s)" % [lane, lanes, v]
				check(enc.has("planted"), "%s a fair planted charge is found (%s)" % [tag, enc.get("why", "")])
				if not enc.has("planted"):
					continue
				var away: int = lane + 1 if lane < lanes - 1 else lane - 1
				var r: Dictionary = await _play_encounter(enc, lane, away)
				_check_flattened(r, enc, "%s, the runner leaving its lane for lane %d" % [tag, away])
				check(bool(r["alive"]) and not bool(r["hit"]), "%s a runner who leaves its lane at the warning is never touched (%s)"
					% [tag, r["death"]])
				if lane == 0:
					var stay: Dictionary = await _play_encounter(enc, lane, -1)
					check(not bool(stay["alive"]) or bool(stay["hit"]), "%s a runner who stays in its lane is hit" % tag)
					check(String(stay["cause"]) == String(Enemy.CHARGE_DAMAGE_CAUSE), "%s and the cyborg is flattened first (%s)"
						% [tag, stay["cause"]])


## The flattened cyborg's checks for a run's record (_play_encounter / _play_level).
func _check_flattened(r: Dictionary, enc: Dictionary, tag: String) -> void:
	var v: float = (enc["movement"] as MovementTuning).run_speed
	var hold: Vector2 = ((enc["planted"]["cyborg"] as Dictionary)["params"] as Dictionary)["hold_fire"]
	check(String(r["cause"]) == String(Enemy.CHARGE_DAMAGE_CAUSE) and int(r["player_kills"]) == 0,
		"%s: the charge flattens the cyborg, never the player's kill (%s)" % [tag, r["cause"]])
	check(float(r["gap"]) >= t.in_view_seconds * v - v * frame - 0.05,
		"%s: in view, the runner %.1f m behind it (%.1f m wanted)" % [tag, float(r["gap"]), t.in_view_seconds * v])
	var held: bool = bool(r["spawned"])
	for e: Dictionary in r["events"]:
		if StringName(e["event"]) == &"shot" and float(e["impact"]) >= hold.x and float(e["impact"]) <= hold.y:
			held = false
		if StringName(e["event"]) == &"charge" and float(e["player_d"]) >= hold.x and float(e["player_d"]) <= hold.y:
			held = false
	check(held, "%s: the cyborg charges no burst and lands no bolt while the runner is in %.0f-%.0f m" % [tag, hold.x, hold.y])


## Plays encounter `enc` on real physics, the runner (no armor, no weapons) starting in `lane` and leaving for
## `away` a reaction after the charge's warning starts (a dog's wind-up; the cut's warning point), or staying
## (`away` -1). {cause (the planted cyborg's death cause, "" if it lived), gap (its track distance less the
## runner's then), events (its gun's), spawned, alive, hit (the runner hurt), death, player_kills}.
func _play_encounter(enc: Dictionary, lane: int, away: int) -> Dictionary:
	var movement: MovementTuning = enc["movement"]
	var v: float = movement.run_speed
	var w: RunWorld = sim.build_world(enc["layout"], Loadout.new(), movement, enc["config"])
	w.player.setup(movement, w.geo, lane)
	var out := {"cause": "", "gap": -INF, "events": [], "spawned": false, "alive": true, "hit": false, "death": "",
		"player_kills": 0}
	_watch(w, out)
	w.player.died.connect(func(cause: String) -> void: out["death"] = cause)
	w.player.movement_event.connect(func(kind: StringName) -> void:
		if kind in [&"armor_hit", &"shield_break"]:
			out["hit"] = true)
	await tree.physics_frame
	w.player.running = true
	var charger: Dictionary = enc["planted"]["charger"]
	var end: float = float(charger["at"]) + 2.0 * v
	var warned: float = -1.0
	var leave_at: float = INF
	if enc.has("cut"):
		leave_at = FloorCutPlan.warn_at(enc["cut"]) + (enc["config"] as LevelConfig).cut_reaction_seconds * v
	for i: int in int(40.0 / frame):
		if away >= 0 and w.player.lane != away and w.player.alive:
			var go: bool = w.player.distance >= leave_at
			if not enc.has("cut"):
				var dog: Octodog = _dog(w)
				if warned < 0.0 and dog != null and dog.phase == Octodog.Phase.WINDUP:
					warned = w.level_time()
				go = warned >= 0.0 and w.level_time() - warned >= DOG_REACTION
			if go and w.player.surface == Player.Surface.FLOOR:
				w.player.press(&"move_right" if away > w.player.lane else &"move_left")
		await tree.physics_frame
		if not w.player.alive or w.player.distance > end:
			break
	out["alive"] = w.player.alive
	out["player_kills"] = w.score.kills
	await sim.free_world(w)
	return out


## Follows the planted cyborg in world `w` into `out` (see _play_encounter).
func _watch(w: RunWorld, out: Dictionary) -> void:
	var cyborg: Array[Enemy] = [null]
	w.director.enemy_spawned.connect(func(e: Enemy) -> void:
		if e is Cyborg and (e.spawn.get("params", {}) as Dictionary).has(ChargePathPlacement.PARAM):
			cyborg[0] = e
			out["spawned"] = true
			out["events"] = (e as Cyborg).gun.events)
	w.director.enemy_defeated.connect(func(e: Enemy, cause: StringName) -> void:
		if e == cyborg[0] and String(out["cause"]) == "":
			out["cause"] = String(cause)
			out["gap"] = e.track_distance() - w.player.distance)


func _dog(w: RunWorld) -> Octodog:
	for e: Variant in w.director.active:
		if is_instance_valid(e) and e is Octodog:
			return e as Octodog
	return null


# --- Campaign plays ------------------------------------------------------------------------------------

## At each lane count, the first planted Octodog encounter in the campaign and the earliest (in level time)
## planted Buzz Overdrive encounter, each played in its level's own build from the start.
func _test_campaign_plays(campaign: Campaign) -> void:
	for lanes: int in LANES:
		var picks: Dictionary = {}  # kind -> [config, cyborg entry, level seconds]
		for s: CampaignStep in campaign.steps():
			if not s.is_level():
				continue
			var config: LevelConfig = campaign.configure(s, lanes)
			var gen: LevelGenerator = LayoutCache.generator(config, tuning, LevelGenerator.load_for(config))
			for e: Dictionary in ChargePathPlacement.planted_in(gen.layout):
				var kind: String = String(e["params"][ChargePathPlacement.PARAM])
				var seconds: float = float(e["at"]) / gen.speed
				if not picks.has(kind) or (kind == ChargePathPlacement.TANK and seconds < float(picks[kind][2])):
					picks[kind] = [config, e, seconds, s.id]
		for kind: String in [ChargePathPlacement.DOG, ChargePathPlacement.TANK]:
			check(picks.has(kind), "at %d lanes the campaign plants a cyborg in a %s's path" % [lanes, kind])
			if not picks.has(kind):
				continue
			var config: LevelConfig = (picks[kind][0] as LevelConfig).duplicate() as LevelConfig
			config.skin = null  # the grey box: skins never change gameplay
			var r: Dictionary = await _play_level(config, picks[kind][1])
			var tag: String = "%s at %d lanes, the %s's cyborg at %.0f m" % [picks[kind][3], lanes, kind, float(picks[kind][1]["at"])]
			var movement: MovementTuning = config.movement_for(tuning)
			_check_flattened(r, {"movement": movement, "planted": {"cyborg": picks[kind][1]}}, tag)
			print("  %s: %s" % [tag, ("flattened %.1f m ahead of the runner" % float(r["gap"])) if String(r["cause"]) != ""
				else "not flattened"])


## Plays `config`'s own build from its start (god mode, grapples, no weapons; the runner keeps to the middle lane)
## until the planted cyborg `cyborg` dies or the runner is 2 s of run past it. As _play_encounter's record, but for
## player_kills (left 0).
func _play_level(config: LevelConfig, cyborg: Dictionary) -> Dictionary:
	var layout: LevelLayout = LayoutCache.generate(config, tuning, LevelGenerator.load_for(config))
	var w: RunWorld = sim.build_world(layout, Loadout.new(), null, config)
	w.player.god_mode = true
	w.player.grapples = 1_000_000
	var v: float = w.tuning.run_speed
	var out := {"cause": "", "gap": -INF, "events": [], "spawned": false, "alive": true, "hit": false, "death": "",
		"player_kills": 0}
	_watch(w, out)
	await tree.physics_frame
	w.player.running = true
	var middle: int = layout.lane_count / 2
	var next_step: float = -INF
	var end: float = float(cyborg["at"]) + 2.0 * v
	var frames_left: int = int(end / v * 2.0 / frame)
	while frames_left > 0 and w.player.distance < end and String(out["cause"]) == "":
		frames_left -= 1
		var p: Player = w.player
		if p.running and p.surface == Player.Surface.FLOOR and p.grounded and p.lane != middle and w.level_time() >= next_step:
			next_step = w.level_time() + 0.3
			p.press(&"move_right" if middle > p.lane else &"move_left")
		await tree.physics_frame
	# The runner's own kills in a whole level (an Enforcer Truck led into a wider gap is one) aren't the charge's:
	# that a charge's kill is never the player's is test_charge_contacts' (and the hand-built runs' here).
	await sim.free_world(w)
	return out

extends TestSuite
## The Enforcer Truck (GDD §9.13; task C6), from its numbers and look to its placement (its runs on real
## physics are test_enforcer_truck_runs.gd):
## - Its numbers: the owner's (about 0.8 s lane delay, about 25 s chase, up to 3 riders, up to 2 a level),
##   its close gap inside an Octodog's lunge at every zone's pace, its follow gap behind the camera, a volley's
##   bolts reaching over a slide and a whole jump.
## - Its look: in every zone's look within an enemy's budget, only its lights and its riders' faces glow (the
##   light bar's red and a blue well away from the safe cyan); at its close gap nothing of it rises into the
##   camera's line of sight to the runner's feet (GDD §9.13: it must not hide the runner).
## - The core hooks (Enemy.charge_bait, ScoreKeeper, EnemyTuning.behind_runner): a charge contact destroys it
##   and is the player's kill; weapons (direct, splash, targeting, health bars) never touch it; a stomp, the
##   claws and the dash never defeat it; hosts, generators and every other enemy keep their old behaviour
##   (charges pass hosts and generators by; another enemy a charge flattens earns nothing); an Octodog whose
##   charges a wait moved on still winds up past its entry.
## - Placement: every campaign level that lists it at 3, 5 and 6 lanes (its own seed and others): at most 2,
##   never two at once, each with a bait in its chase, arriving off every bait's attack; Corporate 2 always
##   has one; the same every build; a level differs from the same level without it only by its trucks
##   (danger density off); quick play without a bait has none.
## - Its marker, its light bar and Reduced flashing; its warm-up look (no physics object); its data (the
##   hint, its sounds).

const Rules = preload("res://scripts/enemies/enforcer_truck_rules.gd")
const BuzzRules = preload("res://scripts/enemies/buzz_overdrive_rules.gd")
const DUMMY: String = "res://tests/helpers/dummy_enemy.gd"
## Its levels (GDD §9.13: introduced in Corporate 2, then every later level with an Octodog or a Buzz
## Overdrive).
const LEVELS: Array[String] = ["corporate/2", "dead_zone/1", "dead_zone/2", "golden/1", "golden/2", "golden/3"]
## The zones' run speeds where it appears.
const SPEEDS: Array[float] = [23.4, 24.2, 25.0]
const VARIANTS: Array[StringName] = [&"city", &"vr_runner", &"burned", &"scavenger", &"golden", &"casino"]

var sim: RunSim
var t: EnforcerTruckTuning


func run() -> void:
	sim = RunSim.new(tree, tuning)
	t = Rules.tuning()
	_test_numbers()
	await _test_model()
	_test_line_of_sight()
	await _test_charge_bait()
	await _test_weapons_never()
	await _test_contacts_never()
	await _test_old_behaviour()
	await _test_dog_past_its_entry()
	_test_campaign()
	_test_only_its_trucks()
	_test_quick_play()
	await _test_marker_and_lights()
	await _test_warm_up()
	_test_data()


# --- Helpers -------------------------------------------------------------------------------------

func _mt(speed: float = 0.0) -> MovementTuning:
	if speed <= 0.0:
		return tuning
	var out: MovementTuning = tuning.duplicate() as MovementTuning
	out.run_speed = speed
	return out


## A world on a plain track of `lanes` lanes whose truck arrives at once, the runner in the middle lane.
func _world(lanes: int = 3, mt: MovementTuning = null, extra: Array[Dictionary] = []) -> RunWorld:
	var layout := RunSim.layout(lanes, 1500.0)
	layout.enemies.append({"type": "enforcer_truck", "at": 1.0, "lane": lanes / 2, "side": 0, "seed": 7, "params": {}})
	for e: Dictionary in extra:
		layout.enemies.append(e)
	var w: RunWorld = sim.build_world(layout, Loadout.new(), mt if mt != null else tuning)
	w.player.god_mode = true
	return w


func _truck(w: RunWorld) -> EnforcerTruck:
	for e: Variant in w.director.active:
		if is_instance_valid(e) and e is EnforcerTruck:
			return e as EnforcerTruck
	return null


## Steps `w` until `done` holds or `seconds` pass. True if it held.
func _run_until(w: RunWorld, seconds: float, done: Callable) -> bool:
	if not w.player.running:
		await tree.physics_frame
		w.player.running = true
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		if done.call():
			return true
		await tree.physics_frame
	return done.call()


## A world whose truck has arrived and settled behind the runner, its volleys held off for the test.
func _chasing(lanes: int = 3, mt: MovementTuning = null, extra: Array[Dictionary] = []) -> RunWorld:
	var w: RunWorld = _world(lanes, mt, extra)
	await _run_until(w, 6.0, func() -> bool:
		var tr: EnforcerTruck = _truck(w)
		return tr != null and tr.state == EnforcerTruck.State.CHASING)
	var truck: EnforcerTruck = _truck(w)
	if truck != null:
		truck.tuning = truck.tuning.duplicate() as EnforcerTruckTuning
		truck.tuning.first_volley_seconds = 999.0
	return w


# --- Numbers --------------------------------------------------------------------------------------

func _test_numbers() -> void:
	check(is_equal_approx(t.lane_delay_seconds, 0.8) and is_equal_approx(t.chase_seconds, 25.0),
		"it copies the runner's lane about 0.8 s late and gives up after about 25 s (GDD §9.13)")
	check(t.max_riders == 3 and t.per_level_max == 2, "up to 3 riders, up to 2 a level (GDD §9.13)")
	var dog := EnemyDirector.tuning_for("octodog") as OctodogTuning
	for pace: float in [1.0, 21.0 / 18.0, 23.4 / 18.0, 24.2 / 18.0, 25.0 / 18.0]:
		var gap: float = t.close_gap_for(dog, pace)
		# The lunge ends lunge_overshoot behind the runner (stretched by the pace), its body half a metre deep.
		check(gap <= dog.lunge_overshoot * pace - t.close_margin + 0.001 and gap >= EnforcerTruck.MIN_GAP,
			"at pace %.2f its close gap (%.2f m) is inside the lunge's reach (%.2f m) and never on the runner" % [pace, gap,
			dog.lunge_overshoot * pace])
	check(t.follow_gap > tuning.camera_distance, "it follows behind the camera (%.1f m > %.1f m)" % [t.follow_gap, tuning.camera_distance])
	check(t.hitbox_size.z + 0.2 <= t.body_size.z and t.hitbox_size.y + t.hitbox_floor <= t.body_size.y + 0.001
		and t.hitbox_size.x <= t.body_size.x, "its hitbox is a little smaller than its look")
	# A shot's column of bolts reaches a runner at any height of a jump, and a sliding one.
	var radius: float = 0.09
	var uncovered: PackedStringArray = []
	var top: float = tuning.jump_height + 0.05
	var h: float = 0.0
	while h <= top:
		var hit: bool = false
		for b: float in t.bolt_heights:
			hit = hit or (b + radius > h and b - radius < h + tuning.hurtbox_size.y)
		if not hit:
			uncovered.append("%.2f" % h)
		h += 0.02
	var slide_hit: bool = false
	for b: float in t.bolt_heights:
		slide_hit = slide_hit or b - radius < tuning.hurtbox_slide_height
	check(uncovered.is_empty() and slide_hit, "a shot's bolts reach a sliding runner and one at any height of a jump (%s)" % [uncovered])
	check(t.warning_seconds >= 0.8 and t.bolt_flight_seconds >= 0.2,
		"a volley's warning (%.2f s) and the bolts' flight (%.2f s) give time to change lanes" % [t.warning_seconds,
		t.bolt_flight_seconds])
	var intervals: Array[float] = []
	for n: int in t.max_riders + 1:
		intervals.append(t.volley_interval(n))
	var faster: bool = true
	for i: int in range(1, intervals.size()):
		faster = faster and intervals[i] < intervals[i - 1] - 0.01
	check(faster, "each rider raises its rate of fire: the intervals %s" % [intervals])
	check(not t.uses_floor and t.behind_runner, "it never stands on the floor ahead of the runner (no floor use, behind_runner)")


# --- Look -----------------------------------------------------------------------------------------

func _test_model() -> void:
	var looks: Dictionary = {}
	for variant: StringName in VARIANTS:
		var m := EnforcerTruckModel.new()
		tree.root.add_child(m)
		m.build(variant, t.body_size)
		m.set_riders(3)
		looks[EnforcerTruckModel.look_of(variant)] = true
		check(m.draw_call_count() <= 12, "%s: a few draw calls with three riders (%d)" % [variant, m.draw_call_count()])
		check(m.triangle_count() <= 2400, "%s: %d triangles with three riders (within an enemy's 2,400)" % [variant, m.triangle_count()])
		var faults: PackedStringArray = []
		var glowing: int = 0
		for entry: Dictionary in m.materials():
			var mat := entry["material"] as StandardMaterial3D
			if mat == null or not mat.emission_enabled:
				continue
			glowing += 1
			var c: Color = mat.emission
			var part: String = String(entry["part"])
			var red: bool = c.r > 0.85 and c.g < 0.3 and c.b < 0.3
			var blue: bool = c.b > 0.8 and c.r < 0.3 and c.g < 0.45
			var white: bool = c.r > 0.75 and c.g > 0.85 and c.b > 0.9
			var ok: bool = (part.begins_with("light bar") or part.begins_with("Bar")) and (red or blue \
				or (c.v < 0.6 and (c.r > c.g * 2.0 or c.b > c.r * 2.0)))
			ok = ok or (part == "Headlights" and white) or (part.ends_with("/Face") and white)
			if not ok:
				faults.append("%s glows %s" % [part, c])
		check(faults.is_empty() and glowing >= 5, "%s: only its headlights, its light bar and its riders' faces glow %s" % [variant, faults])
		m.queue_free()
	check(looks.size() == 3, "three looks: clean, weathered and gilded (%s)" % [looks.keys()])
	# The light bar's blue stays well away from the safe cyan (GDD: only hazards glow in hazard colours).
	var blue: Color = EnforcerTruckModel.BAR_BLUE
	var cyan := Color(0.25, 0.85, 1.0)
	check(absf(blue.h - cyan.h) > 0.08, "the light bar's blue (hue %.2f) is no safe cyan (hue %.2f)" % [blue.h, cyan.h])
	# Its floor lights: unshaded, added light, in its lane.
	var lights: Node3D = EnforcerTruckModel.floor_lights()
	var additive: bool = true
	for c: Node in lights.get_children():
		var mat := (c as MeshInstance3D).material_override as StandardMaterial3D
		additive = additive and mat != null and mat.blend_mode == BaseMaterial3D.BLEND_MODE_ADD \
			and mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
		var aabb: AABB = (c as MeshInstance3D).mesh.get_aabb()
		additive = additive and aabb.size.y < 0.01 and aabb.position.x >= -t.body_size.x * 0.7 \
			and aabb.end.x <= t.body_size.x * 0.7
	check(lights.get_child_count() == 3 and additive,
		"its headlights' beams and the light bar's washes are flat, unshaded, additive shapes on the floor of its lane")
	lights.free()
	await tree.process_frame


## GDD §9.13: while it closes up behind the runner it must not hide them. At its close gap, at every zone's
## pace, every vertex of its body, light bar and riders lies under the line from the camera (its height and
## distance behind the runner, MovementTuning) to the runner's feet, at its own distance behind them.
func _test_line_of_sight() -> void:
	var dog := EnemyDirector.tuning_for("octodog") as OctodogTuning
	for variant: StringName in [&"vr_runner", &"burned", &"golden"]:
		var m := EnforcerTruckModel.new()
		m.build(variant, t.body_size)
		m.set_riders(3)
		var verts: PackedVector3Array = m.solid_vertices()
		for pace: float in [1.0, 23.4 / 18.0, 25.0 / 18.0]:
			var gap: float = t.close_gap_for(dog, pace)
			var worst: float = INF
			var worst_at: Vector3 = Vector3.ZERO
			for v: Vector3 in verts:
				var behind: float = gap + v.z
				var limit: float = tuning.camera_height * behind / tuning.camera_distance
				if limit - v.y < worst:
					worst = limit - v.y
					worst_at = Vector3(v.x, v.y, behind)
			check(worst > 0.0, "%s at pace %.2f: nothing of it rises into the camera's line of sight to the runner's feet (closest %.2f m below it, at %.1f m behind, %.2f m up)"
				% [variant, pace, worst, worst_at.z, worst_at.y])
		m.free()


# --- Core hooks -------------------------------------------------------------------------------------

## A charge contact (Enemy._hurt_charge_contacts) destroys it, as the player's kill with its score and the
## rider bonus; the director relays one defeat with the charge's cause.
func _test_charge_bait() -> void:
	var w: RunWorld = await _chasing(3)
	var truck: EnforcerTruck = _truck(w)
	check(truck != null and truck.charge_bait and truck.immune_to_weapons, "it declares charge_bait and weapon immunity")
	if truck == null:
		await sim.free_world(w)
		return
	truck.riders = 2
	truck.model.set_riders(2)
	var attacker := Enemy.new()
	w.add_child(attacker)
	attacker.setup(w, {}, null)
	var box: Hazard = attacker.add_hitbox(&"body", Vector3(0.8, 0.8, 0.9), Vector3(0.0, 0.4, 0.0), true)
	attacker.global_position = truck.global_position + Vector3(0.0, 0.0, 1.5)
	attacker.set_physics_process(false)
	var causes: Array[StringName] = []
	w.director.enemy_defeated.connect(func(e: Enemy, cause: StringName) -> void:
		if e == truck:
			causes.append(cause))
	var before: Dictionary = w.score.stats()
	await physics_frames(2)
	attacker._begin_charge_contacts()
	attacker._hurt_charge_contacts(box, box.global_transform)
	var after: Dictionary = w.score.stats()
	check(not truck.alive and causes == [Enemy.CHARGE_DAMAGE_CAUSE], "a charge's contact destroys it, once (%s)" % [causes])
	check(int(after["kills"]) == int(before["kills"]) + 1, "it's the player's kill (a bait)")
	var gained: int = int(after["score"]) - int(before["score"])
	check(gained == t.score_value + 2 * t.rider_bonus, "with its score and a bonus for each rider aboard (%d)" % gained)
	check(int((after["bonuses"] as Dictionary).get("enforcer_riders", 0)) == 2 * t.rider_bonus,
		"the riders' bonus shows as its own (%s)" % [after["bonuses"]])
	check(truck.history.back()[0] == "wreck:enemy_charge", "it's wrecked by the charge (%s)" % [truck.history.back()])
	attacker.free()
	await sim.free_world(w)


## Weapons never touch it: auto-fire never targets it, a shot through it and a missile's splash beside it do
## nothing, and it shows no health bar.
func _test_weapons_never() -> void:
	var w: RunWorld = await _chasing(3)
	var truck: EnforcerTruck = _truck(w)
	if truck == null:
		check(false, "a truck to shoot at")
		await sim.free_world(w)
		return
	var hits: Array[int] = [0]
	w.projectiles.enemy_hit.connect(func(e: Enemy, _d: float, _s: bool) -> void:
		if e == truck:
			hits[0] += 1)
	var targets: Array[Enemy] = w.director.targets_ahead(truck.aim_point() + Vector3(0.0, 0.0, 20.0), 100.0)
	check(not targets.has(truck) and not truck.targetable(), "auto-fire never picks it")
	var from: Vector3 = truck.aim_point() + Vector3(0.0, 0.0, 6.0)
	w.projectiles.fire_player(from, Vector3(0.0, 0.0, -60.0), 99.0, &"laser")
	w.projectiles.fire_player(from, Vector3(0.0, 0.0, -60.0), 99.0, &"heavy_missile", null, 0.0, 6.0, 1.0)
	truck.take_damage(99.0, &"weapon")
	truck.take_damage(99.0, &"weapon", true)
	await physics_frames(20)
	check(truck.alive and hits[0] == 0 and is_equal_approx(truck.health, truck.max_health),
		"shots and splash pass it by: no hit, no damage (%d hits, health %.1f)" % [hits[0], truck.health])
	check(not EnemyHealthBars.wants_bar(truck), "it never shows a health bar")
	await sim.free_world(w)


## A stomp, the claws and the dash never defeat it, whatever protects the runner (DamageRules on its
## hitbox); it never touches the runner anyway (its gap, test_enforcer_truck_runs.gd).
func _test_contacts_never() -> void:
	var w: RunWorld = await _chasing(3)
	var truck: EnforcerTruck = _truck(w)
	var box: Hazard = truck.get(&"_body") as Hazard if truck != null else null
	check(box != null and box.part == &"body" and box.is_active(), "its body is a live hitbox (charges can reach it)")
	if box != null:
		var faults: PackedStringArray = []
		for protection: String in ["", "armor", "shield", "claws", "dashing", "invulnerable", "god_mode"]:
			for stomping: bool in [false, true]:
				var d := DamageRules.Defense.new()
				if protection != "":
					d.set(protection, true)
				var outcome: DamageRules.Outcome = DamageRules.resolve(box, d, stomping)
				if outcome == DamageRules.Outcome.STOMP or outcome == DamageRules.Outcome.DEFEAT_ENEMY:
					faults.append("%s/stomp=%s" % [protection, stomping])
		check(faults.is_empty(), "a stomp, the claws and the dash never defeat it (%s)" % [faults])
		check(not truck.stompable and truck.claw_immune and not truck.dash_kills, "it declares it: not stompable, claw-immune, no dash kill")
	await sim.free_world(w)


## Hosts and fence generators keep their immunity to charges (a generator's to weapons too; weapons hit hosts
## since October 8, 2026, GDD §9.7); another enemy a charge flattens still earns the player nothing.
func _test_old_behaviour() -> void:
	var w: RunWorld = _world(3)
	await physics_frames(2)
	var host: Enemy = w.director.spawn({"type": "cyborg", "at": 60.0, "lane": 1, "side": 0, "seed": 3,
		"params": {"host": true, "fires": false}})
	var generator: Enemy = w.director.spawn({"type": "generator", "at": 60.0, "lane": 1, "side": 0, "seed": 4, "params": {}})
	var cyborg: Enemy = w.director.spawn({"type": "cyborg", "at": 60.0, "lane": 1, "side": 0, "seed": 5,
		"params": {"fires": false}})
	for e: Enemy in [host, generator, cyborg]:
		e.set_physics_process(false)
		e.global_position = Vector3(0.0, 0.0, -60.0)
	var attacker := Enemy.new()
	w.add_child(attacker)
	attacker.setup(w, {}, null)
	var box: Hazard = attacker.add_hitbox(&"body", Vector3(1.0, 1.6, 1.0), Vector3(0.0, 0.8, 0.0), true)
	attacker.global_position = Vector3(0.0, 0.0, -60.0)
	attacker.set_physics_process(false)
	var before: Dictionary = w.score.stats()
	await physics_frames(2)
	attacker._begin_charge_contacts()
	attacker._hurt_charge_contacts(box, box.global_transform)
	var after: Dictionary = w.score.stats()
	check(host.alive and generator.alive, "a charge passes a host and a fence generator by, as before")
	check(not host.charge_bait and not generator.charge_bait and not cyborg.charge_bait, "none of them declares charge_bait")
	check(not cyborg.alive and int(after["kills"]) == int(before["kills"]) and int(after["score"]) == int(before["score"]),
		"a cyborg a charge flattens is no kill of the player's, as before")
	generator.take_damage(99.0, &"weapon")
	check(generator.alive, "weapons still never hurt a generator")
	host.take_damage(99.0, &"weapon")
	check(not host.alive, "while they hit a host now, unlike a charge (GDD §9.7, owner, October 8, 2026)")
	attacker.free()
	await sim.free_world(w)


## An Octodog whose charges a wait moved on checks other enemies near its stretch (Octodog.charge_clear); a
## truck's entry there (where it arrived) never holds it back, while any other enemy there still does.
func _test_dog_past_its_entry() -> void:
	var layout := RunSim.layout(3, 600.0)
	layout.enemies.append({"type": "enforcer_truck", "at": 205.0, "lane": 1, "side": 0, "seed": 1, "params": {}})
	check(Octodog.charge_clear(layout, 200.0, 40.0), "a truck's entry inside a charge's stretch keeps it clear")
	layout.enemies.append({"type": "cyborg", "at": 205.0, "lane": 1, "side": 0, "seed": 2, "params": {}})
	check(not Octodog.charge_clear(layout, 200.0, 40.0), "a cyborg there still doesn't")
	await tree.process_frame


# --- Placement ------------------------------------------------------------------------------------

func _test_campaign() -> void:
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	for s: CampaignStep in campaign.steps():
		if not s.is_level():
			continue
		var listed: bool = s.level.has_feature("enforcer_truck")
		check(listed == LEVELS.has(String(s.id)), "%s %s the Enforcer Truck" % [s.id, "lists" if listed else "doesn't list"])
		if not listed:
			continue
		var counts: PackedStringArray = []
		var with_baits: bool = true
		for lanes: int in [3, 5, 6]:
			for k: int in 3:
				var config: LevelConfig = campaign.configure(s, lanes)
				if k > 0:
					config.level_seed = 9100 + k
				var m: MovementTuning = config.movement_for(tuning)
				var patterns: Array = LevelGenerator.load_for(config)
				var gen: LevelGenerator = LayoutCache.generator(config, m, patterns) if k == 0 \
					else _generate(config, m, patterns)
				var tag: String = "(%s, %d lanes, seed %d)" % [s.id, lanes, config.level_seed]
				var trucks: Array[Dictionary] = Rules.trucks_in(gen.layout)
				var problems: PackedStringArray = Rules.problems(gen)
				check(problems.is_empty(), "its placement rules hold %s: %s" % [tag, "; ".join(problems)])
				for e: Dictionary in trucks:
					with_baits = with_baits and not ((e.get("params", {}) as Dictionary).get("baits", []) as Array).is_empty()
				if k == 0:
					counts.append("%d lanes: %d" % [lanes, trucks.size()])
					if String(s.id) == "corporate/2":
						check(not trucks.is_empty(), "Corporate 2 introduces it on its own seed %s" % tag)
					var again: LevelLayout = LevelGenerator.new().generate(config, m, patterns)
					check(JSON.stringify(Rules.trucks_in(again)) == JSON.stringify(trucks), "the same trucks every build " + tag)
		check(with_baits, "%s: every truck lists the baits planned in its chase" % s.id)
		print("  %s Enforcer Trucks: %s" % [s.id, ", ".join(counts)])


func _generate(config: LevelConfig, m: MovementTuning, patterns: Array) -> LevelGenerator:
	var gen := LevelGenerator.new()
	gen.generate(config, m, patterns)
	return gen


## Its rules only add its trucks: with danger density off (whose enemy count counts them) and the wider gaps off
## (task G7: they go in a truck's chase first), Corporate 2 and Golden 2 are the same level with or without the
## feature but for the trucks.
func _test_only_its_trucks() -> void:
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	for id: String in ["corporate/2", "golden/2"]:
		var config: LevelConfig = campaign.configure(campaign.step(id), 5)
		config.danger_density_increase = 0.0
		config.wide_gaps = 0
		var m: MovementTuning = config.movement_for(tuning)
		var patterns: Array = LevelGenerator.load_for(config)
		var with_it: LevelLayout = LevelGenerator.new().generate(config, m, patterns)
		var without: LevelConfig = config.duplicate() as LevelConfig
		var features: PackedStringArray = config.features.duplicate()
		features.remove_at(features.find("enforcer_truck"))
		without.features = features
		var plain: LevelLayout = LevelGenerator.new().generate(without, m, patterns)
		var stripped: LevelLayout = with_it.copy()
		var kept: Array[Dictionary] = []
		for e: Dictionary in stripped.enemies:
			if String(e["type"]) != "enforcer_truck":
				kept.append(e)
		stripped.enemies = kept
		check(not Rules.trucks_in(with_it).is_empty() and JSON.stringify(stripped.to_dict()) == JSON.stringify(plain.to_dict()),
			"%s (no danger density, no wider gaps): the same level but for its trucks" % id)


## Quick play: no bait, no truck (GDD §9.13: only where an Octodog or a Buzz Overdrive charges); with
## Octodogs, around their charges.
func _test_quick_play() -> void:
	var base := load("res://data/levels/prototype_level.tres") as LevelConfig
	for features: PackedStringArray in [PackedStringArray(["cyborg", "enforcer_truck"]),
			PackedStringArray(["cyborg", "octodog", "enforcer_truck"])]:
		for lanes: int in [3, 5, 6]:
			var config: LevelConfig = base.duplicate() as LevelConfig
			config.lane_count = lanes
			config.features = features
			config.duration_seconds = 120.0
			var gen := LevelGenerator.new()
			var layout: LevelLayout = gen.generate(config, tuning, LevelGenerator.load_for(config))
			var trucks: Array[Dictionary] = Rules.trucks_in(layout)
			var baits: bool = features.has("octodog") and not Rules.bait_points(gen).is_empty()
			check(Rules.problems(gen).is_empty(), "quick play %s at %d lanes keeps its rules (%s)" % [features, lanes,
				"; ".join(Rules.problems(gen))])
			if not features.has("octodog"):
				check(trucks.is_empty(), "quick play without a bait at %d lanes has no truck" % lanes)
			elif baits:
				check(not trucks.is_empty(), "quick play with Octodogs at %d lanes has trucks around their charges" % lanes)


# --- Marker, lights -------------------------------------------------------------------------------

func _test_marker_and_lights() -> void:
	var w: RunWorld = await _chasing(5)
	var truck: EnforcerTruck = _truck(w)
	if truck == null:
		check(false, "a truck for its marker")
		await sim.free_world(w)
		return
	var marker: EnforcerTruckMarker = truck.marker
	check(marker.is_inside_tree() and (marker.get_parent() as CanvasLayer).visible and marker.shown > 0.99,
		"its marker shows while it chases")
	check(is_equal_approx(marker.lane_x, truck.global_position.x), "its marker stands under the truck's lane")
	var p: Vector2 = marker.place()
	check(p.y > marker.get_viewport_rect().size.y * 0.8, "its marker sits at the screen's bottom edge (y %.0f)" % p.y)
	# The light bar takes turns; with Reduced flashing both halves stay lit, steady.
	var phases: Dictionary = {}
	for i: int in 40:
		await tree.physics_frame
		phases[truck.model.flash_phase] = true
	check(phases.has(0) and phases.has(1), "its light bar's red and blue take turns (%s)" % [phases.keys()])
	Settings.flashing_reduced = true
	var steady: bool = true
	for i: int in 40:
		await tree.physics_frame
		steady = steady and truck.model.flash_phase == -1 and marker.phase == -1 \
			and (truck.get(&"_wash_red") as MeshInstance3D).material_override == EnforcerTruckModel.floor_material(&"dim") \
			and (truck.get(&"_wash_blue") as MeshInstance3D).material_override == EnforcerTruckModel.floor_material(&"dim")
	Settings.flashing_reduced = false
	check(steady, "with Reduced flashing its light bar, its washes and its marker stay lit, steady")
	await sim.free_world(w)


func _test_warm_up() -> void:
	var w: RunWorld = _world(3)
	var look: Node = EnforcerTruck.warm_up(w, {"type": "enforcer_truck", "at": 1.0, "lane": 1, "seed": 1, "params": {}})
	var geometry: int = 0
	var physics: int = 0
	var stack: Array[Node] = [look]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is GeometryInstance3D:
			geometry += 1
		if n is CollisionObject3D:
			physics += 1
		stack.append_array(n.get_children())
	check(not look.is_inside_tree() and geometry >= 15 and physics == 0,
		"its warm-up look has every part (%d to draw), outside the tree, and no physics object" % geometry)
	look.free()
	check(w.director.warm_entries().any(func(e: Dictionary) -> bool: return String(e["type"]) == "enforcer_truck"),
		"the director readies it with the level")
	await sim.free_world(w)


# --- Data -----------------------------------------------------------------------------------------

func _test_data() -> void:
	check(not LevelConfig.PLANNED_FEATURES.has("enforcer_truck") and LayoutChecks.known_feature("enforcer_truck"),
		"it's a built feature, never a planned one")
	var hints: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/hints/hints.json"))
	var hint: bool = false
	for h: Dictionary in (hints as Dictionary).get("hints", []):
		hint = hint or String(h.get("trigger", "")) == "enemy:enforcer_truck"
	check(hint, "its first encounter has a hint")
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var config: LevelConfig = campaign.configure(campaign.step("corporate/2"), 3)
	check(int(config.feature_ages.get("enforcer_truck", -1)) == 0, "Corporate 2 introduces it (its age there is 0)")
	var library := load("res://data/audio/sfx_library.tres") as SfxLibrary
	var missing: PackedStringArray = []
	for sound: StringName in [&"enforcer_siren", &"enforcer_whine", &"enforcer_laser", &"enforcer_pickup", &"enforcer_crash",
			&"truck_explode"]:
		if library.stream(sound) == null or not library.volume_db.has(String(sound)):
			missing.append(String(sound))
	check(missing.is_empty(), "its siren, warning, shots, rider, crash and explosion have sounds (missing %s)" % [missing])
	var whine: AudioStream = library.stream(&"enforcer_whine")
	check(whine != null and absf(whine.get_length() - t.warning_seconds) < 0.05,
		"its whine lasts its warning (%.2f s)" % (whine.get_length() if whine != null else 0.0))

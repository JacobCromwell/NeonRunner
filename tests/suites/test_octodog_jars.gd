extends TestSuite
## Octodog jars that break open (task Q5; GDD §5, Zone 9, the owner, October 21, 2026: "some jars hold a curled-up Octodog
## instead of a brain. Sometimes smashing an Octodog jar doodad releases its Octodog into the world, and the runner has to
## fight it"; proposed: smashed as every doodad is, a releasing jar looking the same as one that won't, the freed dog
## tumbling out, running ahead and starting its usual attack from the first wind-up, with its cue, fought and killed like
## any Octodog).
## - The layout: a doodad marked LevelLayout.HOLDS holds the Octodog marked LevelLayout.HELD at its front in its lane
##   (holder_of, held_by), both kept by copy() and to_dict(); a plain doodad holds nothing; a held dog is never one of the
##   level's standing Octodogs (LevelGenerator.feature_positions, OctodogRules.dogs_in).
## - The generator (octodog_jar_rules.gd) over the Ice Lab's three levels at 3, 5 and 6 lanes: each has its jars
##   (LevelConfig.octodog_jars), each holding a dog of its own with its charges planned from the release, its first wind-up
##   release_distance past the jar, the rules' re-check clean; in Frost Foundry, which introduces them, none before the
##   feature's start and the first right after it at five lanes; built again it's the same; a level without the feature,
##   or with a count of 0, stands none and is built as without it. (Every build's fairness: test_ice_lab_levels and
##   test_campaign through LayoutChecks.check_octodog_jars and check_doodads.)
## - The skin: the Ice Lab dresses a jar holding an Octodog as its Octodog jar, the look its other Octodog jars (which hold
##   nothing) have too; every other skin dresses it as any doodad.
## - On real physics at 3, 5 and 6 lanes (inner and outermost lanes): held, the dog is out of play (no look of its own, no
##   hitbox, no target, immune); a runner who passes the jar without smashing it (pushed aside) never meets it, and it
##   leaves play; a runner who dashes it lets it out (the octodog_release sound), it tumbles out harmless, runs ahead and
##   makes its planned charges, each from its wind-up with the growl and the telegraph, never sooner than planned: a
##   runner who sidesteps each wind-up lives, one who stays in line is hit by its lunge, one who dashes its lunge kills it
##   (an Octodog kill). A wall runner who breaks a jar by its side wall (task L3) lets its dog out too. A plain doodad
##   dashed lets nothing out. One dog at a time: a freed dog whose wind-up comes due while another dog's charges are on
##   waits for them to end.
## - Every number of the jars' tuning reaches the F6 panel.

const OctodogJarRules := preload("res://scripts/enemies/octodog_jar_rules.gd")
const OctodogRules := preload("res://scripts/enemies/octodog_rules.gd")
const CAMPAIGN_PATH: String = "res://data/campaign/campaign.tres"
const ICE_LAB_SKIN: String = "res://data/skins/ice_lab_frost_skin.tres"
const LANE_COUNTS: Array[int] = [3, 5, 6]
## The jar's front on the hand-built tracks (metres): past the run's start, where the runner is at full speed.
const JAR: float = 90.0
## Seconds after a wind-up starts that a dodging runner switches lanes (a quick reaction, test_octodog's).
const REACTION: float = 0.2

var sim: RunSim
var t: OctodogTuning
var pt: PowerupTuning


func run() -> void:
	sim = RunSim.new(tree, tuning)
	t = EnemyDirector.tuning_for("octodog") as OctodogTuning
	pt = load("res://data/tuning/powerups.tres") as PowerupTuning
	check(t != null, "data/enemies/octodog.tres is an OctodogTuning")
	if t == null:
		return
	_test_layout()
	_test_generator()
	_test_skin()
	await _test_held()
	await _test_release()
	await _test_wall_runner()
	await _test_empty_jar()
	await _test_one_dog_at_a_time()
	_test_tuning()


# --- The layout ---------------------------------------------------------------------------------

func _test_layout() -> void:
	var lay := RunSim.layout(5, 400.0)
	var jar: Dictionary = _jar(2, 1, 80.0)
	var plain: Dictionary = _jar(3, -1, 130.0, false)
	lay.doodads.append(jar)
	lay.doodads.append(plain)
	var dog: Dictionary = _held_dog(2, 80.0, [140.0, 210.0])
	lay.enemies.append(dog)
	check(LevelLayout.holds_enemy(jar) and LevelLayout.held_type(jar) == "octodog" and LevelLayout.is_held(dog),
		"a jar is marked with what it holds, its dog as held")
	check(is_same(lay.holder_of(dog), jar) and is_same(lay.held_by(jar), dog), "the jar and its dog find each other")
	check(not LevelLayout.holds_enemy(plain) and lay.held_by(plain).is_empty(), "a plain doodad holds nothing")
	var copy: LevelLayout = lay.copy()
	check(LevelLayout.holds_enemy(copy.doodads[0]) and LevelLayout.is_held(copy.enemies[0])
		and is_same(copy.holder_of(copy.enemies[0]), copy.doodads[0]), "copy() carries them, each finding its own")
	copy.doodads[0]["smashed"] = true
	check(not jar.has("smashed"), "an attempt's smash stays its own copy's")
	var dict: Dictionary = lay.to_dict()
	var doodads: Array = dict.get("doodads", [])
	check(not doodads.is_empty() and String((doodads[0] as Dictionary).get(LevelLayout.HOLDS, "")) == "octodog",
		"to_dict() carries what a jar holds")
	check(LevelGenerator.feature_positions(lay, "octodog").is_empty() and OctodogRules.dogs_in(lay).is_empty(),
		"a held dog is none of the level's standing Octodogs")
	check(OctodogJarRules.positions(lay) == [80.0] and LevelGenerator.feature_positions(lay, OctodogJarRules.FEATURE) == [80.0],
		"the every-feature check finds the jar at its front")
	# A decoy: marked as holding an Octodog, and DECOY, with no dog of its own.
	var decoy: Dictionary = _jar(1, 1, 250.0, true, 7, true)
	lay.doodads.append(decoy)
	check(LevelLayout.holds_enemy(decoy) and LevelLayout.held_type(decoy) == "octodog" and LevelLayout.is_decoy(decoy)
		and not LevelLayout.is_decoy(jar) and lay.held_by(decoy).is_empty(),
		"a decoy is marked as holding an Octodog, as a decoy, and holds no dog")
	check(OctodogJarRules.positions(lay) == [80.0], "the every-feature check never counts a decoy")
	check(LevelLayout.is_decoy(lay.copy().doodads[-1]), "copy() keeps a decoy one")


# --- The generator ------------------------------------------------------------------------------

func _test_generator() -> void:
	var campaign := load(CAMPAIGN_PATH) as Campaign
	var twos: int = 0
	var jars: int = 0
	for n: int in [1, 2, 3]:
		var step: CampaignStep = campaign.step("ice_lab/%d" % n)
		for lanes: int in LANE_COUNTS:
			var config: LevelConfig = campaign.configure(step, lanes)
			var tag: String = "%s lanes=%d" % [step.id, lanes]
			var patterns: Array = LevelGenerator.load_for(config)
			var gen: LevelGenerator = LayoutCache.generator(config, tuning, patterns)
			var lay: LevelLayout = gen.layout
			var held: Array[Dictionary] = _jars_of(lay)
			check(config.has_feature(OctodogJarRules.FEATURE) and config.octodog_jars >= 1 and held.size() == config.octodog_jars,
				"%d of %d jars holding an Octodog %s" % [held.size(), config.octodog_jars, tag])
			check(OctodogJarRules.positions(lay) == LevelGenerator.feature_positions(lay, OctodogJarRules.FEATURE),
				"the every-feature check finds them at their fronts " + tag)
			var release: float = OctodogJarRules.release_distance(gen)
			var most: int = t.charges_range(config.enemy_scaling).y
			for d: Dictionary in held:
				jars += 1
				var dog: Dictionary = lay.held_by(d)
				var p: Dictionary = dog.get("params", {})
				var anchors: Array = p.get("charge_at", [])
				check(String(dog.get("type", "")) == "octodog" and int(dog["lane"]) == int(d["lane"])
					and not bool(p.get("doghouse", true)) and int(p.get("charges", 0)) == anchors.size()
					and anchors.size() >= 1 and anchors.size() <= most,
					"the jar at %.0f m holds a dog of its own, with no doghouse and its charges planned (%d) %s"
					% [float(d["start"]), anchors.size(), tag])
				if anchors.is_empty():
					continue
				twos += 1 if anchors.size() >= OctodogJarRules.MIN_CHARGES else 0
				check(absf(float(anchors[0]) - float(d["start"]) - release) < 0.01,
					"... its first wind-up release_distance (%.1f m) past the jar %s" % [release, tag])
			check(OctodogJarRules.problems(gen).is_empty(), "the jars keep every placement rule %s %s"
				% [tag, OctodogJarRules.problems(gen)])
			# The level that introduces them (a start of its own: Frost Foundry): nothing before the start, and at five
			# lanes (the game's own count) its first jar within the introduction's window of it (_intro).
			if config.feature_starts.has(OctodogJarRules.FEATURE) and not held.is_empty():
				var start: float = gen.feature_start(OctodogJarRules.FEATURE)
				var fronts: Array[float] = OctodogJarRules.positions(lay)
				fronts.sort()
				var first: float = fronts[0]
				check(first >= start, "no jar before the feature's start (%.0f m: %.0f) %s" % [start, first, tag])
				if lanes == 5:
					check(first <= start + t.jar_intro_window_seconds * gen.speed,
						"the introduction comes right after its start (%.0f m: %.0f) %s" % [start, first, tag])
			var warned: bool = false
			for w: String in gen.warnings:
				warned = warned or w.begins_with("octodog jars")
			check(not warned, "no warning for the jars " + tag)
			if lanes == 5:
				# Built again, the same jars and dogs.
				var again := LevelGenerator.new()
				var lay2: LevelLayout = again.generate(config, tuning, patterns)
				check(var_to_str(_jar_data(lay2)) == var_to_str(_jar_data(lay)), "built again, the same jars and dogs " + tag)
	check(jars >= 9 and twos * 4 >= jars * 3, "most freed dogs make their usual charges, 2 at least (%d of %d)" % [twos, jars])
	# A level without the feature, or with none of them, stands none and is built as without them.
	var config: LevelConfig = campaign.configure(campaign.step("ice_lab/1"), 5)
	var without: LevelConfig = config.duplicate() as LevelConfig
	without.features = config.features.duplicate()
	without.features.remove_at(without.features.find(OctodogJarRules.FEATURE))
	var none: LevelConfig = config.duplicate() as LevelConfig
	none.octodog_jars = 0
	var lay_without: LevelLayout = LevelGenerator.new().generate(without, tuning, LevelGenerator.load_for(without))
	var lay_none: LevelLayout = LevelGenerator.new().generate(none, tuning, LevelGenerator.load_for(none))
	check(_jars_of(lay_without).is_empty() and _jars_of(lay_none).is_empty(), "no feature or a count of 0: no jar holds a dog")
	check(var_to_str(lay_without.to_dict()) == var_to_str(lay_none.to_dict()),
		"a count of 0 builds the level exactly as without the feature")


## Every jar holding an Octodog in `lay`.
func _jars_of(lay: LevelLayout) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d: Dictionary in lay.doodads:
		if LevelLayout.holds_enemy(d):
			out.append(d)
	return out


## The jars of `lay` and the dogs they hold, as plain data (the determinism check).
func _jar_data(lay: LevelLayout) -> Array:
	var out: Array = []
	for d: Dictionary in _jars_of(lay):
		out.append([d["start"], d["lane"], d["side"], d["seed"], (lay.held_by(d).get("params", {}) as Dictionary)])
	return out


# --- The skin -----------------------------------------------------------------------------------

func _test_skin() -> void:
	var lab := load(ICE_LAB_SKIN) as IceLabSkin
	check(lab != null, "the Ice Lab's skin loads")
	if lab == null:
		return
	var doodads: IceLabDoodads = lab.doodads()
	for look_seed: int in [1, 7, 12345, 99991]:
		var look: int = lab.held_doodad_look(&"small", &"octodog", look_seed)
		check(doodads.is_octodog_jar(&"small", look), "the Ice Lab dresses a jar holding an Octodog as its Octodog jar (seed %d)"
			% look_seed)
		check(lab.held_doodad_look(&"small", &"something", look_seed) == look_seed,
			"... and something it has no container for as any doodad")
	var plain := ZoneSkin.new()
	check(plain.held_doodad_look(&"small", &"octodog", 4242) == 4242, "a skin with no jars dresses it as any doodad")
	# The jar the generator stands carries the Octodog jar's look, as the skin's own Octodog jars that hold nothing do.
	var body := Node3D.new()
	lab.doodad(body, tuning.doodad_size(&"small"), &"small", 1, lab.held_doodad_look(&"small", &"octodog", 3))
	var empty := Node3D.new()
	lab.doodad(empty, tuning.doodad_size(&"small"), &"small", 1, doodads.look_seed_for(&"small", IceLabDoodads.OCTODOG_JAR))
	check(body.get_meta(IceLabDoodads.META_LOOK, &"") == IceLabDoodads.OCTODOG_JAR
		and empty.get_meta(IceLabDoodads.META_LOOK, &"") == IceLabDoodads.OCTODOG_JAR,
		"a jar that will let its dog out looks the same as one that won't")
	body.free()
	empty.free()


# --- Real physics ---------------------------------------------------------------------------------

## Held in its jar, the dog is out of play; the track dresses the jar as the zone's Octodog jar.
func _test_held() -> void:
	var made: Dictionary = await _jar_world(5, 2, 1, true)
	var w: RunWorld = made["world"]
	await _until(func() -> bool: return _find_dog(w) != null, 6.0)
	var dog: Octodog = _find_dog(w)
	check(dog != null and dog.phase == Octodog.Phase.HELD and dog.in_jar, "the dog spawns held in its jar")
	if dog != null:
		check(not dog.targetable() and dog.immune_to_weapons and not dog._hitboxes_on and not dog._model.visible,
			"held, it has no look of its own, no hitbox, no target and takes no shot")
		check(not dog.is_major_attack_active(), "held, it holds no turn")
	var jar_node: DashBreakable = _breakable_for(w, made["jar"])
	check(jar_node != null and jar_node.get_meta(IceLabDoodads.META_LOOK, &"") == IceLabDoodads.OCTODOG_JAR,
		"the Ice Lab's track dresses it as its Octodog jar (%s)" % [jar_node.get_meta(IceLabDoodads.META_LOOK, &"none")
			if jar_node != null else "no node"])
	await sim.free_world(w)


## Dashed, the jar lets its dog out, which makes its planned charges, each warned; passed without the dash, never.
func _test_release() -> void:
	for lanes: int in LANE_COUNTS:
		for lane: int in [lanes / 2, 0, lanes - 1]:
			var side: int = 1 if lane == 0 else (-1 if lane == lanes - 1 else (1 if lanes % 2 == 0 else -1))
			var tag: String = "(lanes=%d lane=%d side=%d)" % [lanes, lane, side]
			var r: Dictionary = await _take(lanes, lane, side, "dodge")
			check(bool(r["alive"]) and int(r["smashes"]) == 1 and bool(r["released"]),
				"dashed, the jar breaks and lets its dog out %s %s" % [_brief(r), tag])
			check(bool(r["harmless_out"]), "it tumbles out and runs ahead harmless (no hitbox) until it's ahead %s" % tag)
			check(int(r["windups"]) == int(r["charges"]) and int(r["lunges"]) == int(r["charges"]) and bool(r["warned"]),
				"it makes its %d planned charges, each lunge after its wind-up with the growl and the telegraph %s %s"
				% [int(r["charges"]), _brief(r), tag])
			check(float(r["first_windup"]) >= float(r["a0"]) - 0.5,
				"its first wind-up comes no sooner than planned (%.1f m, planned %.1f m) %s" % [float(r["first_windup"]),
					float(r["a0"]), tag])
			check(float(r["first_windup"]) <= float(r["a0"]) + 10.0,
				"... and it's in position for it by then (%.1f m) %s" % [float(r["first_windup"]), tag])
			check((r["sounds"] as Array).size() >= 1 and (r["sounds"] as Array)[0] == &"octodog_release",
				"it comes out with the octodog_release sound (%s) %s" % [r["sounds"], tag])
			if lane != lanes / 2:
				continue
			r = await _take(lanes, lane, side, "stay")
			check(not bool(r["alive"]) and String(r["event"]).contains("Octodog") and int(r["windups"]) >= 1
				and float(r["died_at"]) >= float(r["first_windup"]),
				"a runner who stays in its line is hit by its lunge, after its wind-up %s %s" % [_brief(r), tag])
			r = await _take(lanes, lane, side, "kill")
			check(bool(r["alive"]) and int(r["kills"]) == 1 and bool(r["dog_gone"]),
				"a runner who dashes its lunge kills it, an Octodog kill %s %s" % [_brief(r), tag])
			r = await _take(lanes, lane, side, "pass")
			check(bool(r["alive"]) and int(r["pushes"]) == 1 and int(r["smashes"]) == 0 and not bool(r["released"])
				and int(r["windups"]) == 0 and (r["sounds"] as Array).is_empty() and bool(r["dog_gone"]),
				"a runner who runs into the jar without the dash is pushed aside and never meets its dog, which leaves play %s %s"
				% [_brief(r), tag])


## A wall runner low on a side wall breaks a jar by it (task L3), and it lets its dog out too.
func _test_wall_runner() -> void:
	for lanes: int in LANE_COUNTS:
		var wall: int = -1 if lanes != 5 else 1
		var lane: int = 0 if wall < 0 else lanes - 1
		var r: Dictionary = await _take(lanes, lane, -wall, "wall")
		var tag: String = "(lanes=%d, by wall %+d)" % [lanes, wall]
		check(int(r["passes"]) == 1 and bool(r["released"]), "a wall runner breaks the jar by their wall and its dog comes out %s %s"
			% [_brief(r), tag])
		check(bool(r["alive"]) and int(r["windups"]) >= 1 and bool(r["warned"]),
			"... and it attacks as any freed dog, warned, a runner who sidesteps it living %s %s" % [_brief(r), tag])


## A plain doodad dashed lets nothing out, even dressed as an Octodog jar.
func _test_empty_jar() -> void:
	var lay := RunSim.layout(5, 400.0)
	var lab := load(ICE_LAB_SKIN) as IceLabSkin
	var look_seed: int = lab.doodads().look_seed_for(&"small", IceLabDoodads.OCTODOG_JAR) if lab != null else 7
	lay.doodads.append(_jar(2, 1, JAR, false, look_seed))
	var w: RunWorld = sim.build_world(lay, null, null, _config())
	w.player.setup(tuning, w.geo, 2)
	var dash_at: float = JAR - 0.5 * pt.dash_duration * (tuning.run_speed + pt.dash_speed_bonus)
	var r: Dictionary = await sim.step_world(w, (JAR + 60.0) / tuning.run_speed, [[dash_at, &"dash"]])
	check(bool(r["alive"]) and w.player.smashes == 1 and w.director.active.is_empty(),
		"an Octodog jar that holds nothing breaks and lets nothing out")
	await sim.free_world(w)


## GDD §9: one dog at a time. A standing dog's charges are on as a freed dog's first wind-up comes due: the freed one
## waits for them to end (Octodog._another_dog_charging), never two dogs' attacks at once.
func _test_one_dog_at_a_time() -> void:
	var lay := RunSim.layout(5, 1400.0)
	var jar_at: float = 70.0
	var plan: Dictionary = _plan_for(lay, jar_at, 2)
	lay.doodads.append(_jar(2, 1, jar_at))
	lay.enemies.append(_held_dog(2, jar_at, plan["anchors"]))
	var w: RunWorld = sim.build_world(lay, null, null, _config())
	w.player.setup(tuning, w.geo, 2)
	# A standing dog whose charges start just before the freed one's first wind-up is due.
	var stop: float = t.stop_distance(tuning.run_speed, 0.0)
	var a0: float = float((plan["anchors"] as Array)[0])
	var standing := w.director.spawn({"type": "octodog", "at": a0 - 10.0 + stop, "lane": 4, "side": 0, "seed": 5,
		"params": {"doghouse": false, "charges": 2}}) as Octodog
	var dash_at: float = jar_at - 0.5 * pt.dash_duration * (tuning.run_speed + pt.dash_speed_bonus)
	await tree.physics_frame
	w.player.god_mode = true
	w.player.running = true
	var both: bool = false
	var freed_first: float = -1.0
	var standing_done_at: float = INF
	var dashed: bool = false
	var standing_id: int = standing.get_instance_id()
	for i: int in int(30.0 * Engine.physics_ticks_per_second):
		if not dashed and w.player.distance >= dash_at:
			RunSim.act(w.player, &"dash")
			dashed = true
		await tree.physics_frame
		var a: Octodog = _dog(standing_id)
		var freed: Octodog = _find_dog(w, true)
		var a_on: bool = a != null and a.is_major_attack_active()
		if a != null and a.charges_done >= 1 and not a_on and standing_done_at == INF:
			standing_done_at = w.player.distance
		if a == null and standing_done_at == INF:
			standing_done_at = w.player.distance
		if freed != null and freed.phase in [Octodog.Phase.WINDUP, Octodog.Phase.LUNGE]:
			if freed_first < 0.0:
				freed_first = w.player.distance
			both = both or a_on
		if freed != null and freed.charges_done >= 1 and freed.phase in [Octodog.Phase.GIVE_UP, Octodog.Phase.LEAVE]:
			break
	check(freed_first >= 0.0, "the freed dog makes its attack (first wind-up at %.0f m)" % freed_first)
	check(not both, "never while the standing dog's charges are on")
	check(freed_first >= standing_done_at - 0.01, "it winds up only once they're over (at %.0f m, over at %.0f m)"
		% [freed_first, standing_done_at])
	await sim.free_world(w)


# --- Tuning -------------------------------------------------------------------------------------

func _test_tuning() -> void:
	var count: int = 0
	var ranged: bool = true
	for p: Dictionary in t.get_property_list():
		if not String(p["name"]).begins_with("jar_"):
			continue
		count += 1
		if int(p["hint"]) != PROPERTY_HINT_RANGE:
			ranged = false
			failures.append("OctodogTuning.%s has no range hint" % p["name"])
	check(ranged and count >= 4, "every number of the jars' tuning has a range for the F6 panel (%d)" % count)
	check(LevelConfig.new().octodog_jars >= 0, "LevelConfig.octodog_jars defaults to a count")
	var found: bool = false
	for p: Dictionary in LevelConfig.new().get_property_list():
		if String(p["name"]) == "octodog_jars":
			found = int(p["hint"]) == PROPERTY_HINT_RANGE
	check(found, "LevelConfig.octodog_jars has a range for the F6 panel")


# --- Helpers ------------------------------------------------------------------------------------

## A bare level config dressed by the Ice Lab's skin.
func _config() -> LevelConfig:
	var c := LevelConfig.new()
	c.skin_path = ICE_LAB_SKIN
	return c


## A jar doodad of the small class in `lane` from `at`, pushing to `side`, holding an Octodog (nothing with `holds` off;
## one that never comes out, a decoy, with `decoy`), its look `look_seed`.
func _jar(lane: int, side: int, at: float, holds: bool = true, look_seed: int = 7, decoy: bool = false) -> Dictionary:
	var d := {"lane": lane, "start": at, "end": at + tuning.doodad_size(&"small").z, "size": &"small", "side": side,
		"seed": look_seed}
	if holds:
		d[LevelLayout.HOLDS] = "octodog"
	if decoy:
		d[LevelLayout.DECOY] = true
	return d


## The Octodog a jar at `at` in `lane` holds, its charges planned at `anchors` (player distances) as the jar rules plan them,
## each `window` metres long (a charge's stretch at the reference speed and no enemy scaling by default).
func _held_dog(lane: int, at: float, anchors: Array, window: float = -1.0) -> Dictionary:
	var planned: Array[float] = []
	for a: Variant in anchors:
		planned.append(float(a))
	if window < 0.0:
		window = t.window_length(tuning.run_speed, 0.0)
	return {"type": "octodog", "at": at, "lane": lane, "side": 0, "seed": 11, "params": {LevelLayout.HELD: true,
		"doghouse": false, "charges": planned.size(), "charge_at": planned,
		"floor_span": Vector2(planned[0] - 10.0, planned[-1] + window)}}


## The jar rules' plan for a dog held in a jar at `at` on `lay`'s bare track, making `count` charges, in the level of
## `config` (the bare one by default: the reference speed, no enemy scaling): {anchors, window}.
func _plan_for(lay: LevelLayout, at: float, count: int, config: LevelConfig = null) -> Dictionary:
	var c: LevelConfig = config if config != null else _config()
	var gen: LevelGenerator = LevelGenerator.for_layout(c, tuning, lay)
	var a0: float = at + OctodogJarRules.release_distance(gen)
	var cycle: float = t.cycle_distance(gen.speed, c.enemy_scaling, gen.pace)
	var anchors: Array[float] = []
	for k: int in count:
		anchors.append(a0 + k * cycle)
	return {"anchors": anchors, "window": t.window_length(gen.speed, c.enemy_scaling, gen.pace)}


## A track `lanes` wide with a jar in `lane` at JAR pushing to `side` (holding a dog making two charges with `holds`),
## dressed by the Ice Lab's skin, the runner in `lane`, in the level of `config` (the bare one by default; a campaign
## level's at its own speed and enemy scaling): {world, jar, dog (its entry), anchors, window, movement}.
func _jar_world(lanes: int, lane: int, side: int, holds: bool, config: LevelConfig = null) -> Dictionary:
	var c: LevelConfig = config if config != null else _config()
	var movement: MovementTuning = c.movement_for(tuning)
	var lay := RunSim.layout(lanes, 1200.0)
	var plan: Dictionary = _plan_for(lay, JAR, 2, c)
	var jar: Dictionary = _jar(lane, side, JAR, holds)
	lay.doodads.append(jar)
	var dog: Dictionary = {}
	if holds:
		dog = _held_dog(lane, JAR, plan["anchors"], float(plan["window"]))
		lay.enemies.append(dog)
	var w: RunWorld = sim.build_world(lay, null, movement, c)
	w.player.setup(movement, w.geo, lane)
	await tree.physics_frame
	w.player.running = true
	return {"world": w, "jar": jar, "dog": dog, "anchors": plan["anchors"], "window": plan["window"], "movement": movement}


## One take on real physics: a jar in `lane` pushing to `side`, its dog planned for two charges, the runner coming at it in
## that lane. `how`: "dodge" (dash the jar, then sidestep each wind-up), "stay" (dash it and stay in line), "kill" (dash
## it, then dash the first lunge), "pass" (run into it without the dash), "wall" (onto the side wall by an outermost
## lane's jar before it, breaking it low on the wall, then sidestep each wind-up). In the level of `config` (the bare one by
## default; a campaign level's at its own speed and enemy scaling).
func _take(lanes: int, lane: int, side: int, how: String, config: LevelConfig = null) -> Dictionary:
	var made: Dictionary = await _jar_world(lanes, lane, side, true, config)
	var w: RunWorld = made["world"]
	var p: Player = w.player
	var anchors: Array = made["anchors"]
	var speed: float = (made["movement"] as MovementTuning).run_speed
	var dash_at: float = JAR - 0.5 * pt.dash_duration * (speed + pt.dash_speed_bonus)
	var r := {"alive": true, "event": "", "released": false, "windups": 0, "lunges": 0, "warned": true,
		"harmless_out": true, "first_windup": INF, "a0": float(anchors[0]), "charges": anchors.size(), "sounds": [],
		"died_at": -1.0, "kills": 0, "dog_gone": false, "smashes": 0, "pushes": 0, "passes": 0}
	var dog_id: int = 0
	var last_phase: int = -1
	var dodge_at: float = INF
	var dashed: bool = false
	var killed_dash: bool = false
	var toward: StringName = &"move_left" if lane == 0 else &"move_right"
	var seconds: float = (float(anchors[-1]) + float(made["window"]) + 40.0) / speed + 2.0
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		if how in ["dodge", "stay", "kill"] and not dashed and p.distance >= dash_at:
			RunSim.act(p, &"dash")
			dashed = true
		if how == "wall" and not dashed and p.distance >= JAR - 15.0:
			p.press(toward)
			dashed = true
		if p.elapsed >= dodge_at:
			p.press(&"move_left" if p.lane > 0 else &"move_right")
			dodge_at = INF
		await tree.physics_frame
		if dog_id == 0:
			var found: Octodog = _find_dog(w)
			dog_id = found.get_instance_id() if found != null else 0
		var dog: Octodog = _dog(dog_id)
		if dog != null:
			if dog.phase != last_phase:
				match dog.phase:
					Octodog.Phase.TUMBLE:
						r["released"] = true
					Octodog.Phase.WINDUP:
						r["windups"] = int(r["windups"]) + 1
						r["first_windup"] = minf(float(r["first_windup"]), p.distance)
						if how in ["dodge", "wall"]:
							dodge_at = p.elapsed + REACTION
					Octodog.Phase.LUNGE:
						r["lunges"] = int(r["lunges"]) + 1
						# Its lunge comes out of a wind-up that played its growl (CLAUDE.md: seen and heard first).
						var heard: int = dog.sounds_played.count(&"octodog_windup")
						r["warned"] = bool(r["warned"]) and last_phase == Octodog.Phase.WINDUP and heard >= int(r["lunges"])
				last_phase = dog.phase
			if dog.phase == Octodog.Phase.WINDUP and dog._phase_time > 0.05:
				r["warned"] = bool(r["warned"]) and dog._telegraph.visible
			if dog.phase in [Octodog.Phase.TUMBLE] or (dog.phase == Octodog.Phase.SPRINT and dog.charges_done == 0
					and _rel(w, dog_id) < t.pass_clearance - 0.01):
				r["harmless_out"] = bool(r["harmless_out"]) and not dog._hitboxes_on
			r["sounds"] = dog.sounds_played.duplicate()
			if how == "kill" and not killed_dash and dog.phase == Octodog.Phase.LUNGE and _rel(w, dog_id) < 6.0:
				p.start_dash(0.6, 8.0)
				killed_dash = true
		if not p.alive:
			r["died_at"] = p.distance
			break
		if dog_id != 0 and dog == null and how in ["kill", "pass"]:
			break
	r["alive"] = p.alive
	r["event"] = p.last_event
	r["kills"] = w.score.kills
	r["smashes"] = p.smashes
	r["pushes"] = p.pushes
	r["passes"] = p.doodad_passes
	r["dog_gone"] = dog_id != 0 and (_dog(dog_id) == null or not _dog(dog_id).alive)
	await sim.free_world(w)
	return r


## The Octodog in play in `w` (the held one with `held_only`), or null.
func _find_dog(w: RunWorld, held_only: bool = false) -> Octodog:
	for e: Enemy in w.director.active:
		if is_instance_valid(e) and e is Octodog and (not held_only or LevelLayout.is_held(e.spawn)):
			return e as Octodog
	return null


## The dog with this instance id, or null once it's freed.
func _dog(id: int) -> Octodog:
	if id == 0:
		return null
	var o: Object = instance_from_id(id)
	return o as Octodog if is_instance_valid(o) else null


## Metres from the runner to the dog with this id (-INF once it's gone).
func _rel(w: RunWorld, id: int) -> float:
	var dog: Octodog = _dog(id)
	return -dog.global_position.z - w.player.distance if dog != null else -INF


## The DashBreakable the track built for doodad entry `d`, or null.
func _breakable_for(w: RunWorld, d: Dictionary) -> DashBreakable:
	for n: Node in w.track.find_children("*", "", true, false):
		if n is DashBreakable and is_same((n as DashBreakable).entry, d):
			return n as DashBreakable
	return null


## Steps physics frames until `cond` is true (true) or `seconds` pass (false).
func _until(cond: Callable, seconds: float) -> bool:
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		if cond.call():
			return true
		await tree.physics_frame
	return cond.call()


func _brief(r: Dictionary) -> String:
	return "(alive %s, '%s', released %s, wind-ups %d, lunges %d, warned %s, first wind-up %.1f of %.1f, kills %d, smashes %d, pushes %d)" % [
		r.get("alive"), r.get("event", ""), r.get("released"), int(r.get("windups", 0)), int(r.get("lunges", 0)),
		r.get("warned"), float(r.get("first_windup", INF)), float(r.get("a0", 0.0)), int(r.get("kills", 0)),
		int(r.get("smashes", 0)), int(r.get("pushes", 0))]

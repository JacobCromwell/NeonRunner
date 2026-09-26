extends TestSuite
## Generator fairness over many seeds, lane counts and difficulties, plus pattern-data checks;
## features that start partway into a level (introductions, and every rules script that adds a
## feature's enemies or pieces keeping to the start), per-level feature weights, and the guarantee
## that every feature appears (LevelConfig.guarantee_features, and the host and Octodog rules' own).

const HostRules := preload("res://scripts/enemies/host_rules.gd")


func run() -> void:
	var base: LevelConfig = load(LEVEL_PATH) as LevelConfig
	var patterns: Array = LevelGenerator.load_patterns(base.patterns_path)
	check(patterns.size() > 0, "patterns loaded")
	var levels: int = 0
	for lanes: int in [3, 5, 6]:
		for difficulty: float in [0.0, 0.3, 0.6, 1.0]:
			for level_seed: int in range(1, 31):
				var config: LevelConfig = base.duplicate() as LevelConfig
				config.lane_count = lanes
				config.difficulty = difficulty
				config.level_seed = level_seed
				var tag: String = "lanes=%d diff=%.1f seed=%d" % [lanes, difficulty, level_seed]
				var gen := LevelGenerator.new()
				var a: LevelLayout = gen.generate(config, tuning, patterns)
				check(gen.warnings.is_empty(), "shipped patterns produce no warnings " + tag)
				var b: LevelLayout = LevelGenerator.new().generate(config, tuning, patterns)
				check(JSON.stringify(a.to_dict()) == JSON.stringify(b.to_dict()), "deterministic " + tag)
				check(a.fences.size() + a.gaps.size() > 10, "level has content " + tag)
				LayoutChecks.check_layout(self, a, config, tag)
				levels += 1

	# A pattern that tries to put floor pieces under its own ceiling gets them dropped (GDD §3).
	var bad_pattern := [{"id": "bad_hull", "length": 10, "elements": [
		{"kind": "hull", "at": 0, "lanes": {"mode": "center"}, "length_seconds": 3.0},
		{"kind": "fence", "at": 20, "variant": "full", "lanes": {"mode": "all"}},
		{"kind": "gap", "at": 30, "lanes": {"mode": "all"}, "jump_frac": 0.4}]}]
	var config: LevelConfig = base.duplicate() as LevelConfig
	config.duration_seconds = 30.0
	var bad_generator := LevelGenerator.new()
	var bad: LevelLayout = bad_generator.generate(config, tuning, bad_pattern)
	check(bad.hulls.size() > 0 and bad.fences.is_empty() and bad.gaps.is_empty(),
		"generator drops floor pieces a pattern places under a ceiling")
	check(bad_generator.warnings.size() == 1, "and reports the bad pattern once (%d)" % bad_generator.warnings.size())

	_test_rule_ceilings_keep_off_floor_enemies(base)
	_test_feature_starts(base)
	_test_rules_keep_to_starts(base)
	_test_rules_share_levels(base)
	_test_feature_weights(base)
	_test_pattern_features()
	_test_guarantee(base)
	_test_rules_guarantees(base)


## Ceilings that enemy rules add later (drone pads, add_hull_with_pad) keep off the floor enemies
## use (GDD §3: the floor beneath a ceiling stays clear): a tuning's reach around the enemy, a run
## its rules planned (params.floor_span), and nothing for enemies that don't use the floor.
func _test_rule_ceilings_keep_off_floor_enemies(base: LevelConfig) -> void:
	var config: LevelConfig = base.duplicate() as LevelConfig
	config.duration_seconds = 60.0
	config.features = PackedStringArray()
	var speed: float = tuning.run_speed
	var at: float = 400.0
	var cases: Array = [
		["cyborg", {}, Vector2(at - 10.0, at + 10.0)],
		["screech", {"source": "vent"}, Vector2(at - 10.0, at + 10.0)],
		["cyborg", {"floor_span": Vector2(at - 150.0, at + 60.0)}, Vector2(at - 150.0, at + 60.0)],
		["window_cyborg", {}, Vector2(INF, -INF)],
	]
	for c: Array in cases:
		var tag: String = "%s %s" % [c[0], c[1]]
		var span: Vector2 = c[2]
		check(LevelGenerator.enemy_floor_span({"type": c[0], "at": at, "params": c[1]}) == span,
			"floor span of " + tag)
		var mismatches: int = 0
		for pad_at: float in range(int(at) - 240, int(at) + 160, 1):
			# Nothing but the enemy under test: a level generated from no patterns is empty.
			var gen := LevelGenerator.new()
			gen.generate(config, tuning, [])
			gen.add_enemy(String(c[0]), at, 1, 0, (c[1] as Dictionary).duplicate())
			var added: bool = gen.add_hull_with_pad(0, pad_at, 2.0)
			var from: float = pad_at - config.hull_lead_in - 6.0
			var to: float = pad_at + (2.0 + config.hull_landing_seconds) * speed
			if added == (span.x <= to and span.y >= from):
				mismatches += 1
		check(mismatches == 0, "a rule's ceiling keeps off exactly the floor of %s (%d wrong)" % [tag, mismatches])

	# Octodogs: however many ceilings later rules squeeze in, none reaches a planned charge run.
	var squeezed: int = 0
	var refused_by_dogs: int = 0
	for lanes: int in [3, 5, 6]:
		for level_seed: int in range(1, 13):
			var dog_config: LevelConfig = base.duplicate() as LevelConfig
			dog_config.features = PackedStringArray(["ceilings", "octodog"])
			dog_config.lane_count = lanes
			dog_config.difficulty = 0.6
			dog_config.level_seed = level_seed
			var tag: String = "lanes=%d seed=%d" % [lanes, level_seed]
			var gen := LevelGenerator.new()
			var layout: LevelLayout = gen.generate(dog_config, tuning, LevelGenerator.load_for(dog_config))
			var dogs: Array[Dictionary] = []
			for e: Dictionary in layout.enemies:
				if String(e["type"]) == "octodog":
					dogs.append(e)
					var fs: Variant = e["params"].get("floor_span")
					var anchors: Array = e["params"].get("charge_at", [])
					check(fs is Vector2 and not anchors.is_empty() and fs.x < float(anchors[0]) and fs.x < float(e["at"])
						and fs.y > float(anchors[-1]) and fs.y > float(e["at"]), "dog's floor span covers its run " + tag)
			var first_new: int = layout.hulls.size()
			for pad_at: float in range(60, int(layout.length), 9):
				var clear_without_dogs: bool = _floor_clear_ignoring_enemies(layout, pad_at, dog_config, speed)
				if gen.add_hull_with_pad(0, pad_at, 1.5):
					squeezed += 1
				elif clear_without_dogs:
					refused_by_dogs += 1
			for i: int in range(first_new, layout.hulls.size()):
				var h: Dictionary = layout.hulls[i]
				for dog: Dictionary in dogs:
					var a0: float = float(dog["params"]["charge_at"][0])
					var run_end: float = (dog["params"]["floor_span"] as Vector2).y
					check(not (float(h["start"]) - Octodog.CEILING_LEAD <= run_end
						and float(h["end"]) + Octodog.CEILING_LANDING >= a0 - Octodog.CEILING_LEAD),
						"a later ceiling (%.0f–%.0f) keeps off a dog's run (%.0f–%.0f) %s" % [h["start"], h["end"], a0, run_end, tag])
	check(squeezed > 50, "later ceilings still fit around the dogs (%d)" % squeezed)
	check(refused_by_dogs > 10, "and some are refused because of them (%d)" % refused_by_dogs)


## add_hull_with_pad's test for a pad at `pad_at` (1.5 s ceiling) counting only gaps, fences and
## other ceilings.
func _floor_clear_ignoring_enemies(layout: LevelLayout, pad_at: float, config: LevelConfig, speed: float) -> bool:
	var start: float = pad_at - config.hull_lead_in
	var end: float = pad_at + 1.5 * speed
	var landing_end: float = end + config.hull_landing_seconds * speed
	if landing_end > layout.length - config.end_clear_distance:
		return false
	for g: Dictionary in layout.gaps:
		if g["start"] <= landing_end and g["end"] >= start - 6.0:
			return false
	for f: Dictionary in layout.fences:
		if f["at"] >= start - 6.0 and f["at"] <= landing_end:
			return false
	for h: Dictionary in layout.hulls:
		if start <= h["end"] + 1.0 and end >= h["start"] - 1.0:
			return false
	return true


## Features that start partway into a level (LevelConfig.feature_starts): nothing of the feature
## comes before its start, and the first pattern picked from there uses it (its introduction), so it
## shows up right after the start. The rest of the level stays fair and deterministic.
func _test_feature_starts(base: LevelConfig) -> void:
	var starts: Dictionary[String, float] = {"ramps": 0.3, "ceilings": 0.55, "pulsing": 0.75}
	# From a start to the first pick at or after it: the longest pattern (a ceiling with its landing)
	# plus the widest spacing between patterns.
	var reach: float = (4.0 + base.hull_landing_seconds + base.spacing_seconds_easy) * tuning.run_speed + 1.0
	var late: int = 0
	for lanes: int in [3, 5, 6]:
		for difficulty: float in [0.0, 0.4, 0.8]:
			for level_seed: int in range(1, 13):
				var config: LevelConfig = base.duplicate() as LevelConfig
				config.lane_count = lanes
				config.difficulty = difficulty
				config.level_seed = level_seed
				config.feature_starts = starts
				var tag: String = "lanes=%d diff=%.1f seed=%d" % [lanes, difficulty, level_seed]
				var gen := LevelGenerator.new()
				var layout: LevelLayout = gen.generate(config, tuning, LevelGenerator.load_for(config))
				check(gen.warnings.is_empty(), "late features generate without warnings " + tag)
				LayoutChecks.check_layout(self, layout, config, tag)
				var again: LevelLayout = LevelGenerator.new().generate(config, tuning, LevelGenerator.load_for(config))
				check(JSON.stringify(layout.to_dict()) == JSON.stringify(again.to_dict()), "deterministic with late features " + tag)
				for feature: String in starts:
					var start: float = starts[feature] * layout.length
					var at: Array[float] = LayoutChecks.feature_positions(layout, feature)
					check(not at.is_empty() and at[0] >= start - 0.01,
						"nothing of `%s` before its start (%.0f m, first %s) %s" % [feature, start, at.slice(0, 1), tag])
					check(not at.is_empty() and at[0] <= start + reach,
						"`%s` is introduced right after its start (%.0f m, first %s) %s" % [feature, start, at.slice(0, 1), tag])
				for h: Dictionary in layout.hulls:
					check(float(h["start"]) >= starts["ceilings"] * layout.length - config.hull_lead_in - 0.01,
						"no ceiling before the ceilings' start " + tag)
				late += 1
	check(late == 108, "late starts checked over %d levels" % late)

	# A feature listed with start 0 is introduced by the first pattern of the level.
	var config: LevelConfig = base.duplicate() as LevelConfig
	config.feature_starts = {"ceilings": 0.0}
	var first: LevelLayout = LevelGenerator.new().generate(config, tuning, LevelGenerator.load_for(config))
	check(not first.pads.is_empty() and is_equal_approx(float(first.pads[0]["at"]), config.start_clear_distance),
		"a start of 0 introduces the feature with the level's first pattern (%s)" % [first.pads.slice(0, 1)])
	# A start for a feature the level doesn't have changes nothing.
	var plain: LevelConfig = base.duplicate() as LevelConfig
	var odd: LevelConfig = base.duplicate() as LevelConfig
	odd.feature_starts = {"octodog": 0.5}
	check(JSON.stringify(LevelGenerator.new().generate(plain, tuning, LevelGenerator.load_for(plain)).to_dict())
		== JSON.stringify(LevelGenerator.new().generate(odd, tuning, LevelGenerator.load_for(odd)).to_dict()),
		"a start for a feature the level doesn't have changes nothing")
	check(base.feature_starts.is_empty(), "copies never write into the level resource's starts")


## Rules scripts that add a feature's enemies or pieces keep to its start: drones and their pads
## (the pads are the `ceilings` feature's), hover trucks and the ramp they add (a `ramps` piece),
## hosts and the pads of their chases. The guaranteed drone wave and hover truck still come.
func _test_rules_keep_to_starts(base: LevelConfig) -> void:
	var speed: float = tuning.run_speed
	var dt := EnemyDirector.tuning_for("drone") as DroneTuning
	var cases: Array = [
		# [features, starts, what to check, fewest enemies over the 24 levels (drones and trucks are
		# guaranteed one per level; hosts are only placed by patterns)]
		[["ceilings", "pulsing", "drone"], {"drone": 0.5}, "drone", 24],
		[["ceilings", "pulsing", "drone"], {"ceilings": 0.6}, "drone_pads", 24],
		[["ceilings", "pulsing", "hover_truck"], {"hover_truck": 0.5}, "hover_truck", 24],
		[["ramps", "ceilings", "hover_truck"], {"ramps": 0.8}, "truck_ramp", 24],
		[["ceilings", "cyborg", "host"], {"host": 0.4}, "host", 3],
		[["ceilings", "cyborg", "host"], {"ceilings": 0.5}, "host_pads", 3],
	]
	var counts: Dictionary = {}
	var fewest: Dictionary = {}
	for c: Array in cases:
		var what: String = c[2]
		counts[what] = 0
		fewest[what] = c[3]
		for lanes: int in [3, 5, 6]:
			for level_seed: int in range(1, 9):
				var config: LevelConfig = base.duplicate() as LevelConfig
				config.lane_count = lanes
				config.difficulty = 0.5
				config.enemy_scaling = 0.5
				config.level_seed = level_seed
				config.features = PackedStringArray(c[0])
				var starts: Dictionary[String, float] = {}
				starts.assign(c[1])
				config.feature_starts = starts
				var tag: String = "%s lanes=%d seed=%d" % [what, lanes, level_seed]
				var gen := LevelGenerator.new()
				var layout: LevelLayout = gen.generate(config, tuning, LevelGenerator.load_for(config))
				check(gen.warnings.is_empty(), "no warnings " + tag)
				LayoutChecks.check_layout(self, layout, config, tag)
				LayoutChecks.check_rules(self, layout, config, tag)
				var length: float = layout.length
				match what:
					"drone":
						var drones: Array[float] = LayoutChecks.feature_positions(layout, "drone")
						check(not drones.is_empty() and drones[0] >= 0.5 * length - 0.01,
							"drones only after their start, the guaranteed wave included (%s) %s" % [drones.slice(0, 1), tag])
						counts[what] += drones.size()
					"drone_pads":
						var pads: Array[float] = LayoutChecks.feature_positions(layout, "ceilings")
						var drones: Array[float] = LayoutChecks.feature_positions(layout, "drone")
						check(pads.is_empty() or pads[0] >= 0.6 * length - 0.01,
							"a drone's pads only after the ceilings' start (%s) %s" % [pads.slice(0, 1), tag])
						check(drones.is_empty() or drones[0] >= 0.6 * length - dt.first_pad_seconds * speed - 0.01,
							"no drone so early that its first pad would come before the ceilings' start " + tag)
						counts[what] += drones.size()
					"hover_truck":
						var trucks: Array[float] = LayoutChecks.feature_positions(layout, "hover_truck")
						check(not trucks.is_empty() and trucks[0] >= 0.5 * length - 0.01,
							"hover trucks only after their start, the guaranteed one included (%s) %s" % [trucks.slice(0, 1), tag])
						counts[what] += trucks.size()
					"truck_ramp":
						var ramps: Array[float] = LayoutChecks.feature_positions(layout, "ramps")
						check(ramps.is_empty() or ramps[0] >= 0.8 * length - 0.01,
							"a hover truck's ramp only after the ramps' start (%s) %s" % [ramps.slice(0, 1), tag])
						counts[what] += LayoutChecks.feature_positions(layout, "hover_truck").size()
					"host":
						var hosts: Array[float] = LayoutChecks.feature_positions(layout, "host")
						check(hosts.is_empty() or hosts[0] >= 0.4 * length - 0.01, "hosts only after their start " + tag)
						counts[what] += hosts.size()
					"host_pads":
						var hosts: Array[float] = LayoutChecks.feature_positions(layout, "host")
						var pads: Array[float] = LayoutChecks.feature_positions(layout, "ceilings")
						check(hosts.is_empty() or hosts[0] >= 0.5 * length - 0.01,
							"no host whose chase would need pads before the ceilings' start " + tag)
						check(pads.is_empty() or pads[0] >= 0.5 * length - 0.01, "a chase's pads only after the ceilings' start " + tag)
						counts[what] += hosts.size()
	for what: String in counts:
		check(int(counts[what]) >= int(fewest[what]),
			"the late-start cases still place their enemies (%s: %d, at least %d)" % [what, counts[what], fewest[what]])


## Enemy rules still hold when enemy types share a level: the cyborg rules run after the hover
## truck's (the ramp it adds keeps the cyborgs' margin), and drone, host, Octodog and generator
## rules keep theirs.
func _test_rules_share_levels(base: LevelConfig) -> void:
	for features: Array in [["ramps", "ceilings", "pulsing", "cyborg", "hover_truck"],
			["cyborg", "ceilings", "ramps", "hover_truck", "octodog", "generator", "drone", "host"]]:
		for lanes: int in [3, 5, 6]:
			for difficulty: float in [0.3, 0.7]:
				for level_seed: int in range(1, 9):
					var config: LevelConfig = base.duplicate() as LevelConfig
					config.lane_count = lanes
					config.difficulty = difficulty
					config.enemy_scaling = difficulty
					config.level_seed = level_seed
					config.features = PackedStringArray(features)
					var tag: String = "%d features lanes=%d diff=%.1f seed=%d" % [features.size(), lanes, difficulty, level_seed]
					var gen := LevelGenerator.new()
					var layout: LevelLayout = gen.generate(config, tuning, LevelGenerator.load_for(config))
					check(gen.warnings.is_empty(), "shared levels generate without warnings " + tag)
					LayoutChecks.check_rules(self, layout, config, tag)


## LevelConfig.feature_weights scales how often a feature's patterns are picked: 0 leaves them out,
## a higher factor picks them more often.
func _test_feature_weights(base: LevelConfig) -> void:
	var plain: int = 0
	var heavy: int = 0
	var none: int = 0
	for lanes: int in [3, 5, 6]:
		for level_seed: int in range(1, 13):
			var config: LevelConfig = base.duplicate() as LevelConfig
			config.lane_count = lanes
			config.level_seed = level_seed
			plain += LevelGenerator.new().generate(config, tuning, LevelGenerator.load_for(config)).ramps.size()
			config.feature_weights = {"ramps": 3.0}
			heavy += LevelGenerator.new().generate(config, tuning, LevelGenerator.load_for(config)).ramps.size()
			config.feature_weights = {"ramps": 0.0}
			none += LevelGenerator.new().generate(config, tuning, LevelGenerator.load_for(config)).ramps.size()
	check(none == 0, "a weight of 0 leaves the feature's patterns out (%d ramps)" % none)
	check(heavy > plain * 2, "a weight of 3 picks them far more often (%d ramps against %d)" % [heavy, plain])
	check(base.feature_weights.is_empty(), "copies never write into the level resource's weights")


## Every feature a pattern requires is one the game knows: a mechanic, an enemy type, or a planned
## feature (LevelConfig.PLANNED_FEATURES), so a typo can't hide a pattern for good.
func _test_pattern_features() -> void:
	var base: LevelConfig = load(LEVEL_PATH) as LevelConfig
	for p: Dictionary in LevelGenerator.load_for(base):
		for need: Variant in p.get("requires", []):
			check(LayoutChecks.known_feature(String(need)), "pattern %s requires a known feature (%s)" % [p.get("id", "?"), need])


## LevelConfig.guarantee_features: every feature a pattern can place appears, whatever the seed. A
## feature chance rarely picks (weight 0.02) shows up in every level with it and in far from every
## level without it; the result stays fair and deterministic. A feature no pattern can place (one
## still to be built) isn't required, and one that can't appear at all ends in a warning after the
## most builds, not in an endless search.
func _test_guarantee(base: LevelConfig) -> void:
	var without: int = 0
	var retried: int = 0
	for lanes: int in [3, 5, 6]:
		for level_seed: int in range(1, 11):
			var config: LevelConfig = base.duplicate() as LevelConfig
			config.lane_count = lanes
			config.level_seed = level_seed
			config.features = PackedStringArray(["ramps", "ceilings", "pulsing", "speed_pads", "resonator"])
			config.feature_weights = {"speed_pads": 0.02}
			var tag: String = "lanes=%d seed=%d" % [lanes, level_seed]
			var plain := LevelGenerator.new()
			var natural: LevelLayout = plain.generate(config, tuning, LevelGenerator.load_for(config))
			check(plain.attempts == 1, "without the guarantee a level is built once " + tag)
			if natural.speed_pads.is_empty():
				without += 1
			config.guarantee_features = true
			var gen := LevelGenerator.new()
			var layout: LevelLayout = gen.generate(config, tuning, LevelGenerator.load_for(config))
			check(not layout.speed_pads.is_empty(), "with it, the rare feature appears " + tag)
			check(gen.warnings.is_empty(), "and nothing is reported missing " + tag + " %s" % [gen.warnings])
			check(not gen.placeable_features(LevelGenerator.load_for(config)).has("resonator"),
				"a feature no pattern places yet isn't required " + tag)
			LayoutChecks.check_layout(self, layout, config, tag)
			var again := LevelGenerator.new()
			check(JSON.stringify(again.generate(config, tuning, LevelGenerator.load_for(config)).to_dict()) == JSON.stringify(layout.to_dict())
				and again.attempts == gen.attempts, "the guarantee is deterministic " + tag)
			if gen.attempts > 1:
				retried += 1
	check(without >= 15, "chance alone leaves the rare feature out of most levels (%d of 30)" % without)
	check(retried >= 15, "and the guarantee builds those again (%d of 30)" % retried)

	# Hosts without ceilings can never keep their Bad Dream's pads: the search gives up with a warning.
	var stuck: LevelConfig = base.duplicate() as LevelConfig
	stuck.features = PackedStringArray(["cyborg", "host"])
	stuck.guarantee_features = true
	var gen := LevelGenerator.new()
	var layout: LevelLayout = gen.generate(stuck, tuning, LevelGenerator.load_for(stuck))
	check(gen.attempts == LevelGenerator.GUARANTEE_ATTEMPTS and HostRules.hosts_in(layout).is_empty(),
		"a feature that can't appear stops the search after %d builds (%d)" % [LevelGenerator.GUARANTEE_ATTEMPTS, gen.attempts])
	var said: bool = false
	for w: String in gen.warnings:
		said = said or (w.begins_with("guarantee:") and w.contains("host"))
	check(said, "and the level reports it (%s)" % [gen.warnings])


## The host and Octodog rules' own guarantees (guarantee_features): a level left without one (every
## one dropped, or none placed: here its patterns' weight is 0) gets one where it fits every rule: a
## host whose Bad Dream's chase gets its pads, a dog with at least two charges off ceilings and
## chases. Drones, cyborgs and the rest keep their rules too (LayoutChecks.check_rules). A host fits
## somewhere in every level below, and so does a dog among ceilings and a hover truck; but a dog needs
## a long clear run, so in the busiest level (drone pads, hosts' chases) it may find none, and in a
## campaign level the generator's next build then forces a dog pattern instead.
func _test_rules_guarantees(base: LevelConfig) -> void:
	var busy: Array = ["cyborg", "ceilings", "octodog", "generator", "drone", "host"]
	var dogs_with_chases: int = 0
	for c: Array in [["host", busy, true], ["octodog", ["ramps", "ceilings", "octodog", "hover_truck"], true],
			["octodog", busy, false]]:
		var feature: String = c[0]
		var added: int = 0
		for lanes: int in [3, 5, 6]:
			for level_seed: int in range(1, 9):
				var config: LevelConfig = base.duplicate() as LevelConfig
				config.lane_count = lanes
				config.level_seed = level_seed
				config.difficulty = 0.6
				config.enemy_scaling = 0.8
				config.features = PackedStringArray(c[1])
				config.feature_weights = {feature: 0.0}
				var tag: String = "%s in %s lanes=%d seed=%d" % [feature, c[1], lanes, level_seed]
				check(LayoutChecks.feature_positions(LevelGenerator.new().generate(config, tuning, LevelGenerator.load_for(config)), feature).is_empty(),
					"no pattern places it at weight 0 " + tag)
				config.guarantee_features = true
				var gen := LevelGenerator.new()
				var layout: LevelLayout = gen.generate(config, tuning, LevelGenerator.load_for(config))
				var found: Array[float] = LayoutChecks.feature_positions(layout, feature)
				check(found.size() <= 1, "its rules add at most one (%d) %s" % [found.size(), tag])
				check(gen.warnings.is_empty(), "no warnings " + tag + " %s" % [gen.warnings])
				LayoutChecks.check_layout(self, layout, config, tag)
				LayoutChecks.check_rules(self, layout, config, tag)
				for e: Dictionary in layout.enemies:
					if String(e["type"]) == "octodog":
						check(((e["params"] as Dictionary).get("charge_at", []) as Array).size() >= 2,
							"a guaranteed dog gets at least two charges " + tag)
				added += found.size()
				if feature == "octodog" and not found.is_empty() and not LayoutChecks.feature_positions(layout, "host").is_empty():
					dogs_with_chases += 1
		if bool(c[2]):
			check(added == 24, "every level got its %s (%d of 24) in %s" % [feature, added, c[1]])
	check(dogs_with_chases > 0, "some guaranteed dogs share their level with a Bad Dream's chase (%d)" % dogs_with_chases)

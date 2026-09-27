extends TestSuite
## Generator fairness over many seeds, lane counts and difficulties, plus pattern-data checks;
## ceilings over a dangerous floor (GDD §3: a pattern's gauntlet under its own ceiling, rules'
## ceilings over whatever the floor holds, the safe landing zone, pads the player can step on, and a
## floor route under every ceiling, run on real physics); features that start partway into a level
## (introductions, and every rules script that adds a feature's enemies or pieces keeping to the
## start), per-level feature weights, and the guarantee that every feature appears
## (LevelConfig.guarantee_features, and the host and Octodog rules' own).

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

	_test_pattern_ceilings(base)
	_test_rule_ceilings_keep_off_floor_enemies(base)
	_test_feature_starts(base)
	_test_rules_keep_to_starts(base)
	_test_rules_share_levels(base)
	_test_feature_weights(base)
	_test_pattern_features()
	_test_guarantee(base)
	_test_rules_guarantees(base)
	await _test_floor_routes_on_physics(base)


## GDD §3 (changed September 26, 2026): a pattern may put gaps, fences and floor enemies under its
## own ceiling, a gauntlet the ceiling lets the player escape; they're kept, with no warning, and the
## floor route under it is checked like every ceiling's (LayoutChecks). What a pattern puts in its
## ceiling's landing zone, or in its pad's lane around the pad, is dropped with a warning.
func _test_pattern_ceilings(base: LevelConfig) -> void:
	var gauntlet := [{"id": "test_gauntlet", "length": 10, "elements": [
		{"kind": "hull", "at": 0, "lanes": {"mode": "edge"}, "length_seconds": 4.0},
		{"kind": "fence", "at_seconds": 1.2, "variant": "full", "lanes": {"mode": "all_but", "count": 1}},
		{"kind": "gap", "at_seconds": 2.4, "lanes": {"mode": "all_but", "count": 1}, "jump_frac": 0.4}]}]
	var bad := [{"id": "bad_hull", "length": 10, "elements": [
		{"kind": "hull", "at": 0, "lanes": {"mode": "center"}, "length_seconds": 3.0},
		{"kind": "gap", "at": 3, "lanes": {"mode": "all"}, "jump_frac": 0.4},
		{"kind": "fence", "at_seconds": 3.3, "variant": "full", "lanes": {"mode": "all"}}]}]
	for lanes: int in [3, 5, 6]:
		var config: LevelConfig = base.duplicate() as LevelConfig
		config.duration_seconds = 40.0
		config.lane_count = lanes
		var tag: String = "lanes=%d" % lanes
		var zones := CeilingZones.make(config, tuning)
		var gen := LevelGenerator.new()
		var layout: LevelLayout = gen.generate(config, tuning, gauntlet)
		check(gen.warnings.is_empty(), "a gauntlet under its own ceiling is fine pattern data %s %s" % [tag, gen.warnings])
		var under: int = 0
		for h: Dictionary in layout.hulls:
			for f: Dictionary in layout.fences:
				under += 1 if float(f["at"]) > float(h["start"]) and float(f["at"]) < float(h["end"]) else 0
			for g: Dictionary in layout.gaps:
				under += 1 if float(g["start"]) > float(h["start"]) and float(g["end"]) < float(h["end"]) else 0
		check(layout.hulls.size() >= 3 and under == layout.hulls.size() * 2 * (lanes - 1),
			"its fences and gaps stay under the ceiling (%d pieces under %d ceilings) %s" % [under, layout.hulls.size(), tag])
		LayoutChecks.check_layout(self, layout, config, tag)

		var bad_generator := LevelGenerator.new()
		var dropped: LevelLayout = bad_generator.generate(config, tuning, bad)
		check(bad_generator.warnings.size() == 1 and bad_generator.warnings[0].contains("bad_hull"),
			"a pattern's pieces in its landing zone or at its pad are reported once %s %s" % [tag, bad_generator.warnings])
		check(dropped.fences.is_empty(), "and its fences in the landing zone are dropped %s" % tag)
		var pad_lane_gaps: int = 0
		for g: Dictionary in dropped.gaps:
			pad_lane_gaps += 1 if int(g["lane"]) == lanes / 2 else 0
		check(pad_lane_gaps == 0 and dropped.gaps.size() == dropped.hulls.size() * (lanes - 1),
			"and its gap in the pad's lane, while the gaps in the other lanes stay under the ceiling %s" % tag)
		LayoutChecks.check_layout(self, dropped, config, tag)
		check(zones.landing > 0.0 and zones.run_up > 0.0 and zones.rise > 0.0, "the zones have a size " + tag)


## Ceilings that enemy rules add later (drone pads, add_hull_with_pad) lie over whatever the floor
## holds, floor enemies included (GDD §3: the floor under a ceiling may be dangerous), but keep their
## pad's spot and their landing zone off the floor enemies use (CeilingZones): a tuning's reach around
## the enemy, a run its rules planned (params.floor_span), and nothing for enemies that don't use the
## floor.
func _test_rule_ceilings_keep_off_floor_enemies(base: LevelConfig) -> void:
	var config: LevelConfig = base.duplicate() as LevelConfig
	config.duration_seconds = 60.0
	config.features = PackedStringArray()
	var speed: float = tuning.run_speed
	var zones := CeilingZones.make(config, tuning)
	var at: float = 400.0
	var cyborg := EnemyDirector.tuning_for("cyborg") as EnemyTuning
	var screech := EnemyDirector.tuning_for("screech") as EnemyTuning
	var cases: Array = [
		["cyborg", {}, Vector2(at - cyborg.floor_reach_before, at + cyborg.floor_reach_after)],
		["screech", {"source": "vent"}, Vector2(at - screech.floor_reach_before, at + screech.floor_reach_after)],
		["cyborg", {"floor_span": Vector2(at - 150.0, at + 60.0)}, Vector2(at - 150.0, at + 60.0)],
		["window_cyborg", {}, Vector2(INF, -INF)],
	]
	for c: Array in cases:
		var tag: String = "%s %s" % [c[0], c[1]]
		var span: Vector2 = c[2]
		check(LevelGenerator.enemy_floor_span({"type": c[0], "at": at, "params": c[1]}) == span,
			"floor span of " + tag)
		var mismatches: int = 0
		var over: int = 0
		var seconds: float = 3.0
		for pad_at: float in range(int(at) - 240, int(at) + 160, 1):
			# Nothing but the enemy under test: a level generated from no patterns is empty.
			var gen := LevelGenerator.new()
			gen.generate(config, tuning, [])
			gen.add_enemy(String(c[0]), at, 1, 0, (c[1] as Dictionary).duplicate())
			var added: bool = gen.add_hull_with_pad(0, pad_at, seconds)
			var spot: Vector2 = zones.pad_spot(pad_at)
			var landing: Vector2 = zones.landing_zone({"end": pad_at + seconds * speed})
			var touches: bool = (span.x <= spot.y and span.y >= spot.x) or (span.x <= landing.y and span.y >= landing.x)
			if added == touches:
				mismatches += 1
			if added and at > pad_at - config.hull_lead_in and at < pad_at + seconds * speed:
				over += 1
		check(mismatches == 0, "a rule's ceiling keeps its pad and landing off exactly the floor of %s (%d wrong)" % [tag, mismatches])
		# A ceiling may lie over an enemy whose stretch fits between its pad and its end.
		if span.y - span.x < seconds * speed - tuning.pad_length - 1.0:
			check(over > 0, "and may lie over it (%d ceilings over %s)" % [over, tag])

	# Octodogs: however many ceilings later rules squeeze in, their pads and landings keep off every
	# dog's planned run, and no planned charge meets a player dropping off a ceiling.
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
			var ot := EnemyDirector.tuning_for("octodog") as OctodogTuning
			var window: float = ot.window_length(speed, dog_config.enemy_scaling)
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
				var clear_without_dogs: bool = _pad_and_landing_clear_ignoring_enemies(layout, pad_at, dog_config, zones)
				if gen.add_hull_with_pad(0, pad_at, 1.5):
					squeezed += 1
				elif clear_without_dogs:
					refused_by_dogs += 1
			for i: int in range(first_new, layout.hulls.size()):
				var h: Dictionary = layout.hulls[i]
				var landing: Vector2 = zones.landing_zone(h)
				var pad: Vector2 = zones.pad_spot(float(h["start"]) + dog_config.hull_lead_in)
				for dog: Dictionary in dogs:
					var run: Vector2 = dog["params"]["floor_span"]
					check((run.y < landing.x or run.x > landing.y) and (run.y < pad.x or run.x > pad.y),
						"a later ceiling (%.0f–%.0f) keeps its pad and landing off a dog's run (%.0f–%.0f) %s"
						% [h["start"], h["end"], run.x, run.y, tag])
					for a: Variant in dog["params"]["charge_at"]:
						check(float(h["end"]) + Octodog.CEILING_LANDING < float(a) or float(h["end"]) > float(a) + window - 0.01,
							"no planned charge meets a player dropping off a later ceiling %s" % tag)
	check(squeezed > 50, "later ceilings still fit around the dogs (%d)" % squeezed)
	check(refused_by_dogs > 10, "and some are refused because of them (%d)" % refused_by_dogs)


## add_hull_with_pad's test for a pad at `pad_at` in lane 0 (1.5 s ceiling) counting only the floor
## pieces in its pad's lane and on its landing zone, and other ceilings.
func _pad_and_landing_clear_ignoring_enemies(layout: LevelLayout, pad_at: float, config: LevelConfig,
		zones: CeilingZones) -> bool:
	var start: float = pad_at - config.hull_lead_in
	var end: float = pad_at + 1.5 * tuning.run_speed
	var landing: Vector2 = zones.landing_zone({"end": end})
	if landing.y > layout.length - config.end_clear_distance:
		return false
	var zone: Vector2 = zones.pad_zone(pad_at)
	for g: Dictionary in layout.gaps:
		if (float(g["start"]) <= landing.y and float(g["end"]) >= landing.x) \
				or (int(g["lane"]) == 0 and float(g["start"]) <= zone.y and float(g["end"]) >= zone.x):
			return false
	for f: Dictionary in layout.fences:
		if (float(f["at"]) >= landing.x - 0.2 and float(f["at"]) <= landing.y + 0.2) \
				or (int(f["lane"]) == 0 and float(f["at"]) >= zone.x - 0.2 and float(f["at"]) <= zone.y + 0.2):
			return false
	for r: Dictionary in layout.ramps:
		if layout.outer_lane(int(r["side"])) == 0 and float(r["at"]) <= pad_at + tuning.pad_length \
				and float(r["at"]) + tuning.ramp_length >= zone.x:
			return false
	for h: Dictionary in layout.hulls:
		if start <= float(h["end"]) + 1.0 and end >= float(h["start"]) - 1.0:
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


## GDD §3: the floor route under a ceiling is always survivable without the pad. The routes FloorRoute
## finds under ceilings (the model LayoutChecks checks every ceiling with) are run by the real Player
## on real physics, on the floor pieces, pads and ceilings of the layout (enemies keep to their own
## fairness rules and aren't in it): under each gauntlet pattern's ceiling (the pattern alone in a
## level), and under the drone's pad schedule over ordinary floors, at 3, 5 and 6 lanes. The player
## comes through on the floor, alive, never having stepped on the pad.
func _test_floor_routes_on_physics(base: LevelConfig) -> void:
	var sim := RunSim.new(tree, tuning)
	var cases: Array = []  # [tag, features, patterns, ceilings to run, seeds]
	for p: Dictionary in LevelGenerator.load_for(base):
		var hull: bool = false
		var pieces: int = 0
		for e: Dictionary in p.get("elements", []):
			if String(e.get("kind", "")) == "hull":
				hull = true
			elif String(e.get("kind", "")) in ["gap", "fence", "enemy"]:
				pieces += 1
		if hull and pieces > 0:
			var features: Array = ["pulsing"]
			features.append_array(p.get("requires", []))
			cases.append([String(p["id"]), features, [p], 3, 1])
	check(cases.size() >= 6, "gauntlet patterns put floor pieces or enemies under their own ceiling (%d)" % cases.size())
	cases.append(["drone", ["ceilings", "pulsing", "ramps", "speed_pads", "drone"], LevelGenerator.load_for(base), 3, 2])
	var ran: int = 0
	for c: Array in cases:
		for lanes: int in [3, 5, 6]:
			for level_seed: int in range(1, int(c[4]) + 1):
				var config: LevelConfig = base.duplicate() as LevelConfig
				config.lane_count = lanes
				config.difficulty = 0.8
				config.enemy_scaling = 0.8
				config.level_seed = level_seed
				config.features = PackedStringArray(c[1])
				var tag: String = "%s lanes=%d seed=%d" % [c[0], lanes, level_seed]
				var gen := LevelGenerator.new()
				var layout: LevelLayout = gen.generate(config, tuning, c[2])
				check(gen.warnings.is_empty(), "no warnings %s %s" % [tag, gen.warnings])
				check(not layout.hulls.is_empty(), "the level has ceilings " + tag)
				var zones := CeilingZones.make(config, tuning)
				var runs: int = 0
				for h: Dictionary in layout.hulls:
					if runs >= int(c[3]):
						break
					var route: Dictionary = LayoutChecks.floor_route(layout, tuning, zones, h)
					check(bool(route["ok"]), "a floor route under the ceiling at %.0f (%s) %s" % [h["start"], route["reason"], tag])
					if not bool(route["ok"]):
						continue
					var r: Dictionary = await _replay(sim, layout, route)
					var what: String = "under the ceiling at %.0f (%d moves) %s" % [h["start"], (route["actions"] as Array).size(), tag]
					check(bool(r["alive"]), "the player runs the floor route %s: %s" % [what, r["cause"]])
					check(not (r["events"] as Array).has(&"pad"), "without stepping on the pad " + what)
					check(r["surface"] == "floor" and bool(r["reached"]), "and comes through on the floor %s (%s at %.0f)"
						% [what, r["surface"], r["distance"]])
					runs += 1
					ran += 1
	check(ran >= 60, "floor routes run on physics: %d" % ran)


## Runs `route` (FloorRoute) on real physics: the layout's floor pieces, pads and ceilings from the
## route's start to its end (and a little past), moved to start after a run-up; no enemies. Returns
## RunSim.run's result, and `reached`: the player got past the route's end.
func _replay(sim: RunSim, layout: LevelLayout, route: Dictionary) -> Dictionary:
	const LEAD: float = 30.0
	var from: float = float(route["from"])
	var to: float = float(route["to"])
	var offset: float = LEAD - from
	var part := RunSim.layout(layout.lane_count, to - from + LEAD + 80.0)
	var lists: Dictionary = layout.to_dict()
	var into: Dictionary = part.to_dict()
	for key: String in ["gaps", "fences", "pads", "hulls", "ramps", "speed_pads", "signs"]:
		for item: Dictionary in lists[key]:
			var start: float = float(item.get("start", item.get("at", 0.0)))
			var end: float = float(item.get("end", start + 5.0))
			if end < from - 1.0 or start > to + 40.0:
				continue
			var moved: Dictionary = item.duplicate()
			for k: String in ["at", "start", "end"]:
				if moved.has(k):
					moved[k] = float(moved[k]) + offset
			(into[key] as Array).append(moved)
	var actions: Array = []
	for a: Array in route["actions"]:
		# One physics step early: the Player acts on a press in its next step.
		actions.append([float(a[0]) + offset - tuning.run_speed / Engine.physics_ticks_per_second, a[1]])
	var seconds: float = (to - from + LEAD + 10.0) / tuning.run_speed
	var r: Dictionary = await sim.run(part, int(route["start_lane"]), seconds, actions)
	r["reached"] = float(r["distance"]) >= to + offset
	return r

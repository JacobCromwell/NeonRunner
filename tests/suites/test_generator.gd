extends TestSuite
## Generator fairness over many seeds, lane counts and difficulties, plus pattern-data checks;
## ceilings over a dangerous floor (GDD §3: a pattern's gauntlet under its own ceiling, rules'
## ceilings over whatever the floor holds, the safe landing zone, pads the player can step on, and a
## floor route under every ceiling, run on real physics); features that start partway into a level
## (introductions, and every rules script that adds a feature's enemies or pieces keeping to the
## start), per-level feature weights, and the guarantee that every feature appears
## (LevelConfig.guarantee_features, and the host and Octodog rules' own); the campaign's recency
## curve for pick weights (FeatureRecency); quiet stretches and bursts (LevelConfig.quiet_seconds).

const HostRules := preload("res://scripts/enemies/host_rules.gd")


func run() -> void:
	var base: LevelConfig = load(LEVEL_PATH) as LevelConfig
	var patterns: Array = LevelGenerator.load_patterns(base.patterns_path)
	check(patterns.size() > 0, "patterns loaded")
	var levels: int = 0
	var wall_lines := Vector2i.ZERO
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
				wall_lines += _check_wall_run_credits(a, tag)
				levels += 1
	check(wall_lines.x * 2 > wall_lines.y, "most ramps have credits along their wall run (%d of %d)" % [wall_lines.x, wall_lines.y])
	print("  ramps with credits along their wall run: %d of %d, in %d levels" % [wall_lines.x, wall_lines.y, levels])

	_test_pattern_ceilings(base)
	_test_narrow_landing(base)
	_test_narrow_ceilings(base)
	_test_rule_ceilings_keep_off_floor_enemies(base)
	_test_feature_starts(base)
	_test_rules_keep_to_starts(base)
	_test_rules_share_levels(base)
	_test_feature_weights(base)
	_test_pattern_features()
	_test_guarantee(base)
	_test_rules_guarantees(base)
	_test_recency(base)
	_test_pacing(base)
	_test_pacing_introductions(base)
	await _test_floor_routes_on_physics(base)


## GDD §3 and §7: the credits along each ramp's wall run are the ones LevelGenerator.wall_run_credits
## puts on the path the boosted player takes (RampLaunch; test_interactions rides them on real
## physics), all of them kept. Returns how many ramps have some, and how many ramps there are.
func _check_wall_run_credits(layout: LevelLayout, tag: String) -> Vector2i:
	var lines: int = 0
	for r: Dictionary in layout.ramps:
		var line: Array[Dictionary] = LevelGenerator.wall_run_credits(layout, r, tuning, tuning.run_speed)
		var kept: int = 0
		for c: Dictionary in line:
			kept += 1 if layout.credits.has(c) else 0
		check(kept == line.size(), "the credits along the wall run of the ramp at %.1f are on its boosted path (%d of %d) %s"
			% [float(r["at"]), kept, line.size(), tag])
		lines += 1 if not line.is_empty() else 0
	return Vector2i(lines, layout.ramps.size())


## GDD §3 (changed September 26, 2026): a pattern may put gaps, fences and floor enemies under its
## own ceiling, a gauntlet the ceiling lets the player escape; they're kept, with no warning, and the
## floor route under it is checked like every ceiling's (LayoutChecks). What a pattern puts in its
## ceiling's landing zone, or in its pad's lane around the pad, is dropped with a warning. (Ceilings
## over every lane here; narrow ones in _test_narrow_landing.)
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
		config.narrow_ceiling_share = 0.0
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


## GDD §3 with narrow ceilings: a ceiling's landing zone covers the lanes the ceiling covers (its
## rider drops from one of those), so what a pattern puts in the landing zone is dropped there and kept
## in the other lanes, and its gap in the pad's lane is dropped as always.
func _test_narrow_landing(base: LevelConfig) -> void:
	var bad := [{"id": "bad_hull", "length": 10, "elements": [
		{"kind": "hull", "at": 0, "lanes": {"mode": "center"}, "length_seconds": 3.0},
		{"kind": "gap", "at": 3, "lanes": {"mode": "all"}, "jump_frac": 0.4},
		{"kind": "fence", "at_seconds": 3.3, "variant": "full", "lanes": {"mode": "all"}}]}]
	for lanes: int in [3, 5, 6]:
		var config: LevelConfig = base.duplicate() as LevelConfig
		config.duration_seconds = 40.0
		config.lane_count = lanes
		config.narrow_ceiling_share = 1.0
		var tag: String = "lanes=%d" % lanes
		var gen := LevelGenerator.new()
		var layout: LevelLayout = gen.generate(config, tuning, bad)
		check(gen.warnings.size() == 1 and gen.warnings[0].contains("bad_hull"),
			"a pattern's pieces in a narrow ceiling's landing zone are reported once %s %s" % [tag, gen.warnings])
		check(layout.hulls.size() >= 3, "the level has ceilings %s (%d)" % [tag, layout.hulls.size()])
		var ok: bool = true
		for h: Dictionary in layout.hulls:
			var lanes_h: Vector2i = layout.hull_lanes(h)
			ok = ok and lanes_h.y - lanes_h.x + 1 >= 2 and lanes_h.y - lanes_h.x + 1 < lanes
			for f: Dictionary in layout.fences:
				if float(f["at"]) > float(h["end"]) and float(f["at"]) < float(h["end"]) + 8.0:
					ok = ok and not layout.hull_covers(h, int(f["lane"]))
			var kept: int = 0
			for f: Dictionary in layout.fences:
				kept += 1 if float(f["at"]) > float(h["end"]) and float(f["at"]) < float(h["end"]) + 8.0 else 0
			ok = ok and kept == lanes - (lanes_h.y - lanes_h.x + 1)
		check(ok, "the fences in its landing zone go from the ceiling's lanes and stay in the others, over a "
			+ "gauntlet's narrow ceiling (two lanes to all but one) %s" % tag)
		LayoutChecks.check_layout(self, layout, config, tag)


## GDD §3 (decided September 26, 2026): ceilings don't have to cover every lane. With a level's
## narrow_ceiling_share, that share of its ceilings (the patterns' and the rules') cover a contiguous
## range of lanes holding their pads, at 3, 5 and 6 lanes alike: every width from one lane to all but
## one comes up, a one-lane ceiling only where its pattern puts nothing under it (or a rule's), and
## every check LayoutChecks makes of a ceiling holds for each range (its pads inside it and steppable,
## a one-lane one short, its landing zone safe over its lanes, a floor route under it without the pad,
## credits on it within its lanes), as do the enemy rules around the pads. Levels generate the same
## way every time; no ceiling is narrow before narrow_ceiling_start, or with a share of 0; and
## narrowing ceilings changes nothing else about the pattern pass (with no one-lane ceilings, whose
## shorter length moves the patterns after them, the same patterns come in the same spots).
func _test_narrow_ceilings(base: LevelConfig) -> void:
	var feature_sets: Array = [["ramps", "ceilings", "pulsing"],
		["cyborg", "ceilings", "ramps", "hover_truck", "octodog", "generator", "drone", "host", "screech"]]
	var widths: Dictionary = {}
	var narrow: int = 0
	var total: int = 0
	var one_lane_gauntlets: int = 0
	var rule_narrow: int = 0
	var late: int = 0
	var unchanged_picks: int = 0
	var runs: int = 0
	for features: Array in feature_sets:
		for lanes: int in [3, 5, 6]:
			for level_seed: int in range(1, 13):
				var config: LevelConfig = base.duplicate() as LevelConfig
				config.lane_count = lanes
				config.difficulty = 0.6
				config.enemy_scaling = 0.6
				config.level_seed = level_seed
				config.features = PackedStringArray(features)
				config.narrow_ceiling_share = 0.7
				var tag: String = "narrow %d features lanes=%d seed=%d" % [features.size(), lanes, level_seed]
				var patterns: Array = LevelGenerator.load_for(config)
				var gen := LevelGenerator.new()
				var layout: LevelLayout = gen.generate(config, tuning, patterns)
				check(gen.warnings.is_empty(), "narrow ceilings generate without warnings %s %s" % [tag, gen.warnings])
				var again: LevelLayout = LevelGenerator.new().generate(config, tuning, patterns)
				check(JSON.stringify(layout.to_dict()) == JSON.stringify(again.to_dict()), "deterministic " + tag)
				LayoutChecks.check_layout(self, layout, config, tag)
				LayoutChecks.check_rules(self, layout, config, tag)
				# The pads the pattern pass placed, and whether their pattern put anything under its ceiling.
				var pattern_pads: Dictionary = {}
				var by_id: Dictionary = {}
				for p: Dictionary in patterns:
					by_id[String(p.get("id", ""))] = p
				for pick: Dictionary in gen.picks:
					var pattern: Dictionary = by_id.get(String(pick["id"]), {})
					for e: Dictionary in pattern.get("elements", []):
						if String(e.get("kind", "")) == "hull":
							var pad_at: float = float(pick["at"]) + float(e.get("at", 0.0)) + float(e.get("at_seconds", 0.0)) * tuning.run_speed
							pattern_pads[snappedf(pad_at, 0.01)] = LevelGenerator.plain_ceiling(pattern)
				for h: Dictionary in layout.hulls:
					total += 1
					var width: int = layout.hull_width(h)
					if width == lanes:
						continue
					narrow += 1
					var key: String = "%d:%d" % [lanes, width]
					widths[key] = int(widths.get(key, 0)) + 1
					for p: Dictionary in layout.pads:
						if float(p["at"]) < float(h["start"]) or float(p["at"]) > float(h["end"]):
							continue
						var at: float = snappedf(float(p["at"]), 0.01)
						if not pattern_pads.has(at):
							rule_narrow += 1
						elif width == 1 and not bool(pattern_pads[at]):
							one_lane_gauntlets += 1
				# Narrow ceilings start at narrow_ceiling_start.
				var started: LevelConfig = config.duplicate() as LevelConfig
				started.narrow_ceiling_start = 0.5
				var half: LevelLayout = LevelGenerator.new().generate(started, tuning, patterns)
				for h: Dictionary in half.hulls:
					if h.has("first_lane") and float(h["start"]) + started.hull_lead_in < 0.5 * half.length - 0.01:
						late += 1
				# Without one-lane ceilings the pattern pass is the one a level without narrow ceilings makes.
				var two_up: LevelConfig = config.duplicate() as LevelConfig
				two_up.one_lane_ceiling_share = 0.0
				var off: LevelConfig = config.duplicate() as LevelConfig
				off.narrow_ceiling_share = 0.0
				var gen_two := LevelGenerator.new()
				gen_two.generate(two_up, tuning, patterns)
				var gen_off := LevelGenerator.new()
				var plain_layout: LevelLayout = gen_off.generate(off, tuning, patterns)
				unchanged_picks += 1 if JSON.stringify(gen_two.picks) == JSON.stringify(gen_off.picks) else 0
				runs += 1
				for h: Dictionary in plain_layout.hulls:
					check(not h.has("first_lane"), "a share of 0 keeps every ceiling over every lane " + tag)
	print("  narrow ceilings at a share of 0.7: %d of %d ceilings, %d of them the rules'; by lanes:width %s" % [narrow,
		total, rule_narrow, widths])
	check(narrow * 10 > total * 5, "a share of 0.7 makes most ceilings narrow (%d of %d)" % [narrow, total])
	for lanes: int in [3, 5, 6]:
		for width: int in range(1, lanes):
			check(int(widths.get("%d:%d" % [lanes, width], 0)) > 0, "narrow ceilings %d lanes wide at %d lanes (%s)"
				% [width, lanes, widths])
	check(one_lane_gauntlets == 0, "a gauntlet's ceiling is never one lane (%d)" % one_lane_gauntlets)
	check(rule_narrow > 0, "the rules' ceilings (a drone's pads, a chase's) are narrow too (%d)" % rule_narrow)
	check(late == 0, "no narrow ceiling before narrow_ceiling_start (%d)" % late)
	check(unchanged_picks == runs, "narrowing ceilings leaves the pattern picks alone (%d of %d levels)" % [unchanged_picks, runs])


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
		for pad_lane: int in [0, 1]:
			for pad_at: float in range(int(at) - 240, int(at) + 160, 1):
				# Nothing but the enemy under test (in lane 1): a level generated from no patterns is empty.
				var gen := LevelGenerator.new()
				gen.generate(config, tuning, [])
				gen.add_enemy(String(c[0]), at, 1, 0, (c[1] as Dictionary).duplicate())
				var added: bool = gen.add_hull_with_pad(pad_lane, pad_at, seconds)
				# From its own lane the enemy keeps off the pad's whole zone, from another off its spot.
				var keep: Vector2 = zones.pad_zone(pad_at) if pad_lane == 1 else zones.pad_spot(pad_at)
				var landing: Vector2 = zones.landing_zone({"end": pad_at + seconds * speed})
				var touches: bool = (span.x <= keep.y and span.y >= keep.x) or (span.x <= landing.y and span.y >= landing.x)
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
					var charges: Array = dog["params"]["charge_at"]
					for a: Variant in charges:
						check(float(h["end"]) + Octodog.CEILING_LANDING < float(a) or float(h["end"]) > float(a) + window - 0.01,
							"no planned charge meets a player dropping off a later ceiling %s" % tag)
					check(pad.x < float(charges[0]) - 2.0 * Octodog.CEILING_LEAD or pad.x > float(charges[-1]) + window,
						"nor a player stepping onto its pad (%.0f, charges from %.0f) %s" % [pad.x, float(charges[0]), tag])
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
	var unbuilt: String = _unbuilt_feature()
	for lanes: int in [3, 5, 6]:
		for level_seed: int in range(1, 11):
			var config: LevelConfig = base.duplicate() as LevelConfig
			config.lane_count = lanes
			config.level_seed = level_seed
			var features := PackedStringArray(["ramps", "ceilings", "pulsing", "speed_pads"])
			if unbuilt != "":
				features.append(unbuilt)
			config.features = features
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
			if unbuilt != "":
				check(not gen.placeable_features(LevelGenerator.load_for(config)).has(unbuilt),
					"a feature no pattern places yet (`%s`) isn't required %s" % [unbuilt, tag])
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


## A planned feature (LevelConfig.PLANNED_FEATURES) that no pattern requires yet, one still to be built,
## for the guarantee's check that such a feature isn't required; "" once every planned one is built.
func _unbuilt_feature() -> String:
	var patterns: Array = LevelGenerator.load_for(load(LEVEL_PATH) as LevelConfig)
	for f: String in LevelConfig.PLANNED_FEATURES:
		var placed: bool = false
		for p: Dictionary in patterns:
			placed = placed or (p.get("requires", []) as Array).has(f)
		if not placed:
			return f
	return ""


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


## The campaign's recency curve (GDD §5, owner's review P2 13: beyond the guarantee, a level's newest
## things get the most picks; FeatureRecency): a pattern's pick weight is multiplied by the curve's
## factor for its newest feature's age, no more than a capped feature's cap (max_factor); with
## keep_feature_share the features' patterns, capped ones apart, are then scaled back so that
## together they weigh what they did without it, kind by kind with keep_share_by_kind
## (LevelGenerator.pattern_kind; patterns with enemies by the enemies they place, enemy_count), and
## plain obstacles keep their weight, so the level picks them as often as before. Without ages, or
## with the curve off, every weight is as it was. Over many levels the feature the level introduces
## gets more picks (from the other features of its kind), the oldest fewer, never none, and the level
## places about as many enemies.
func _test_recency(base: LevelConfig) -> void:
	var patterns: Array = LevelGenerator.load_for(base)
	var by_id: Dictionary = {}
	for p: Dictionary in patterns:
		by_id[String(p["id"])] = p
	_test_pattern_kinds(by_id)
	var curve := FeatureRecency.new()
	var plain: LevelConfig = base.duplicate() as LevelConfig
	plain.features = PackedStringArray(["cyborg", "ceilings", "pulsing", "window_cyborg", "ramps", "speed_pads"])
	plain.difficulty = 0.5
	var ages: Dictionary[String, int] = {"cyborg": 6, "ceilings": 3, "pulsing": 2, "window_cyborg": 2, "ramps": 1,
		"speed_pads": 0}
	var curved: LevelConfig = plain.duplicate() as LevelConfig
	curved.feature_ages = ages
	curved.feature_recency = curve
	check(not plain.recency_on() and curved.recency_on(), "the curve shapes only a level the campaign dated")
	check(curved.recency_factor(["window_cyborg", "ramps"]) == curve.one_level_later
		and curved.recency_factor(["ceilings", "cyborg"]) == curve.three_levels_later and curved.recency_factor([]) == 1.0,
		"a pattern follows its newest feature, and one that requires nothing isn't touched")
	check(curve.factor(0) == curve.introduced and curve.factor(4) == curve.older and curve.factor(9) == curve.older,
		"four levels on and later, a feature has the curve's `older` factor")
	var copy: LevelConfig = curved.duplicate() as LevelConfig
	check(copy.feature_ages == ages and copy.feature_recency == curve, "a copy of a level keeps its ages and curve")

	var gen := LevelGenerator.new()
	gen.generate(plain, tuning, patterns)
	var at: float = 600.0
	var w0: Dictionary = _weights_by_id(gen.pick_weights(patterns, 0.5, at))
	gen.config = curved
	var w1: Dictionary = _weights_by_id(gen.pick_weights(patterns, 0.5, at))
	curve.keep_share_by_kind = false
	var together: Dictionary = _weights_by_id(gen.pick_weights(patterns, 0.5, at))
	curve.keep_feature_share = false
	var raw: Dictionary = _weights_by_id(gen.pick_weights(patterns, 0.5, at))
	curve.keep_feature_share = true
	curve.keep_share_by_kind = true
	var caps: Dictionary[String, float] = {"window_cyborg": 1.0}
	curve.max_factor = caps
	check(curved.recency_factor(["window_cyborg", "ramps"]) == 1.0 and curved.recency_capped(["window_cyborg", "ramps"])
		and not curved.recency_capped(["ramps"]), "a capped feature holds a pattern that requires it at its cap")
	var capped: Dictionary = _weights_by_id(gen.pick_weights(patterns, 0.5, at))
	var no_caps: Dictionary[String, float] = {}
	curve.max_factor = no_caps
	curve.enabled = false
	var off: Dictionary = _weights_by_id(gen.pick_weights(patterns, 0.5, at))
	curve.enabled = true
	check(off == w0, "with the curve off, every pattern weighs what it did")
	check(w1.keys() == w0.keys() and w0.size() > 10, "the curve changes weights, not which patterns fit (%d)" % w0.size())
	# Per kind, what the features' patterns weigh (those with enemies, by the enemies they place):
	# without the curve [0], with it [1], and with window cyborgs capped at 1 [2]; each kind's scale.
	var sums: Array[Array] = [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]
	var scales: Array[float] = [-1.0, -1.0, -1.0]
	var capped_scales: Array[float] = [-1.0, -1.0, -1.0]
	var one_scale: float = -1.0
	var feat0: float = 0.0
	var feat_together: float = 0.0
	var combos: int = 0
	var capped_ok: bool = true
	var capped_seen: int = 0
	for id: String in w0:
		var p: Dictionary = by_id[id]
		var requires: Array = p.get("requires", [])
		var factor: float = curved.recency_factor(requires)
		check(is_equal_approx(float(raw[id]), float(w0[id]) * factor),
			"%s's weight is multiplied by its newest feature's factor (%.2f)" % [id, factor])
		if requires.is_empty():
			check(is_equal_approx(float(w1[id]), float(w0[id])) and is_equal_approx(float(together[id]), float(w0[id]))
				and is_equal_approx(float(capped[id]), float(w0[id])), "a plain obstacle (%s) keeps its weight" % id)
			continue
		combos += 1 if requires.size() > 1 else 0
		var kind: int = LevelGenerator.pattern_kind(p)
		var measure: float = float(LevelGenerator.enemy_count(p, plain.lane_count)) if kind == 0 else 1.0
		sums[0][kind] += float(w0[id]) * measure
		sums[1][kind] += float(w1[id]) * measure
		sums[2][kind] += float(capped[id]) * measure
		var s: float = float(w1[id]) / (float(w0[id]) * factor)
		if scales[kind] < 0.0:
			scales[kind] = s
		check(is_equal_approx(s, scales[kind]), "a kind's patterns are scaled back alike (%s: %.3f, %.3f)" % [id, s, scales[kind]])
		var s1: float = float(together[id]) / (float(w0[id]) * factor)
		if one_scale < 0.0:
			one_scale = s1
		check(is_equal_approx(s1, one_scale), "without keep_share_by_kind, all alike (%s: %.3f, %.3f)" % [id, s1, one_scale])
		feat0 += float(w0[id])
		feat_together += float(together[id])
		if requires.has("window_cyborg"):
			# Capped at 1: its own weight, never scaled back.
			capped_ok = capped_ok and is_equal_approx(float(capped[id]), float(w0[id]))
			capped_seen += 1
		else:
			var sc: float = float(capped[id]) / (float(w0[id]) * factor)
			if capped_scales[kind] < 0.0:
				capped_scales[kind] = sc
			check(is_equal_approx(sc, capped_scales[kind]), "with a cap, the rest of a kind is scaled back alike (%s)" % id)
	for kind: int in 3:
		check(sums[0][kind] > 0.0, "kind %d was checked" % kind)
		check(is_equal_approx(sums[0][kind], sums[1][kind]) and is_equal_approx(sums[0][kind], sums[2][kind]),
			"kind %d weighs what it did (%s), with a cap too: %.3f, %.3f, %.3f" % [kind,
			"by the enemies its patterns place" if kind == 0 else "its share", sums[0][kind], sums[1][kind], sums[2][kind]])
	check(is_equal_approx(feat0, feat_together) and one_scale > 0.0 and one_scale < 1.0,
		"without keep_share_by_kind, the features' patterns weigh together what they did (%.3f, %.3f; scale %.3f)"
		% [feat0, feat_together, one_scale])
	check(capped_ok and capped_seen >= 2, "a capped feature's patterns keep their own weight (%d)" % capped_seen)
	check(combos >= 2, "patterns requiring several features were checked (%d)" % combos)

	# Over many levels, picks follow the curve, and the level's patterns place as many enemies.
	var tally: Array[Dictionary] = [{}, {}]
	var placed: Array[int] = [0, 0]
	for lanes: int in [3, 5, 6]:
		for level_seed: int in range(1, 9):
			for k: int in 2:
				var config: LevelConfig = (plain if k == 0 else curved).duplicate() as LevelConfig
				config.lane_count = lanes
				config.level_seed = level_seed
				var g := LevelGenerator.new()
				g.generate(config, tuning, patterns)
				check(g.warnings.is_empty(), "no warnings with the curve lanes=%d seed=%d %s" % [lanes, level_seed, g.warnings])
				for p: Dictionary in g.picks:
					var requires: Array = p["requires"]
					for f: Variant in (["core"] if requires.is_empty() else requires):
						tally[k][String(f)] = int(tally[k].get(String(f), 0)) + 1
					tally[k]["total"] = int(tally[k].get("total", 0)) + 1
					placed[k] += LevelGenerator.enemy_count(by_id[String(p["id"])], lanes)
	var before: Dictionary = tally[0]
	var after: Dictionary = tally[1]
	# A safe mechanic takes its extra picks from the other safe ones only (keep_share_by_kind).
	check(int(after.get("speed_pads", 0)) * 10 >= int(before.get("speed_pads", 0)) * 12,
		"the feature the level introduces gets more picks (%d, without the curve %d)" % [after.get("speed_pads", 0), before.get("speed_pads", 0)])
	check(int(after.get("cyborg", 0)) < int(before.get("cyborg", 0)) and int(after.get("cyborg", 0)) > 0,
		"the oldest gets fewer, but some (%d, without the curve %d)" % [after.get("cyborg", 0), before.get("cyborg", 0)])
	var core0: float = float(before.get("core", 0)) / float(before["total"])
	var core1: float = float(after.get("core", 0)) / float(after["total"])
	check(absf(core1 - core0) < 0.04, "plain obstacles keep their share of the picks (%.3f, without the curve %.3f)" % [core1, core0])
	check(placed[1] >= placed[0] * 0.9, "the level's patterns place about as many enemies (%d, without the curve %d)"
		% [placed[1], placed[0]])
	print("  recency curve: picks of the newest feature %d -> %d, the oldest %d -> %d, plain obstacles' share %.3f -> %.3f, enemies placed %d -> %d"
		% [before.get("speed_pads", 0), after.get("speed_pads", 0), before.get("cyborg", 0), after.get("cyborg", 0), core0, core1,
		placed[0], placed[1]])


## LevelGenerator.pattern_kind (enemies, obstacles only, safe) and enemy_count (as _pick_lanes picks
## lanes) on made-up patterns and a real one.
func _test_pattern_kinds(by_id: Dictionary) -> void:
	var enemy_row: Dictionary = {"elements": [{"kind": "fence", "lanes": {"mode": "random", "count": 2}},
		{"kind": "enemy", "type": "cyborg", "lanes": {"mode": "others"}},
		{"kind": "enemy", "type": "cyborg", "lanes": {"mode": "same"}},
		{"kind": "enemy", "type": "window_cyborg", "side": "random"}]}
	check(LevelGenerator.pattern_kind(enemy_row) == 0 and LevelGenerator.pattern_kind({"elements": [{"kind": "gap"}]}) == 1
		and LevelGenerator.pattern_kind({"elements": [{"kind": "sign", "side": "left"}]}) == 1
		and LevelGenerator.pattern_kind({"elements": [{"kind": "hull"}, {"kind": "credits"}]}) == 2
		and LevelGenerator.pattern_kind({"elements": [{"kind": "ramp"}]}) == 2, "patterns' kinds: enemies, obstacles only, safe")
	# 2 fenced lanes; the others (3 of 5) get a cyborg each; "same" repeats those 3; one on the wall.
	check(LevelGenerator.enemy_count(enemy_row, 5) == 7 and LevelGenerator.enemy_count(enemy_row, 3) == 3,
		"enemies a pattern places: its selectors' lanes, one per wall enemy (%d at 5 lanes, %d at 3)"
		% [LevelGenerator.enemy_count(enemy_row, 5), LevelGenerator.enemy_count(enemy_row, 3)])
	var selectors: Dictionary = {"all": 6, "all_but": 5, "edge": 1, "center": 1}
	for mode: String in selectors:
		var one: Dictionary = {"elements": [{"kind": "enemy", "type": "screech", "lanes": {"mode": mode, "count": 1}}]}
		check(LevelGenerator.enemy_count(one, 6) == int(selectors[mode]), "a `%s` selector's enemies at 6 lanes" % mode)
	var frac: Dictionary = {"elements": [{"kind": "enemy", "type": "cyborg", "lanes": {"mode": "random", "frac": 0.5}}]}
	check(LevelGenerator.enemy_count(frac, 5) == 3 and LevelGenerator.enemy_count(frac, 3) == 2,
		"a `frac` selector rounds, as the generator does")
	check(by_id.has("host_single") and LevelGenerator.enemy_count(by_id["host_single"], 6) == 1
		and LevelGenerator.pattern_kind(by_id["host_single"]) == 0, "a host's pattern places one host")


## pick_weights()'s result as pattern id → weight.
func _weights_by_id(pool: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for i: int in (pool["patterns"] as Array).size():
		out[String(pool["patterns"][i]["id"])] = float(pool["weights"][i])
	return out


## Quiet stretches and bursts (LevelConfig.quiet_seconds; GDD §5, The Hush: long silent stretches
## broken by sudden threats): the stretches alternate from the level's first pattern, quiet first; a
## quiet stretch picks no enemy but its quiet features', which it keeps inside it, and stays sparse;
## a burst picks only threats, densely, its enemies inside it; rules that guarantee an enemy put it in
## a burst, or a quiet feature's in a quiet stretch (burst_spot, pacing_pools). Every rule, fairness
## check and the guarantee still hold, at 3, 5 and 6 lanes, and it's deterministic.
## With quiet_seconds 0 the other settings change nothing.
func _test_pacing(base: LevelConfig) -> void:
	var paced: LevelConfig = base.duplicate() as LevelConfig
	paced.features = PackedStringArray(["cyborg", "ceilings", "pulsing", "window_cyborg", "hover_truck", "ramps",
		"octodog", "speed_pads", "generator", "drone", "host"])
	paced.duration_seconds = 150.0
	paced.difficulty = 0.7
	paced.enemy_scaling = 0.7
	paced.guarantee_features = true
	paced.quiet_seconds = 14.0
	paced.burst_seconds = 7.0
	paced.quiet_spacing_seconds = 4.0
	paced.burst_spacing_seconds = 0.9
	paced.quiet_features = PackedStringArray(["host"])
	var patterns: Array = LevelGenerator.load_for(paced)
	var by_id: Dictionary = {}
	for p: Dictionary in patterns:
		by_id[String(p["id"])] = p
	var speed: float = tuning.run_speed
	var cycle: float = (paced.quiet_seconds + paced.burst_seconds) * speed
	# Metres, enemies (hosts apart), hosts and obstacle rows in quiet stretches [0] and bursts [1]; the
	# same level paced evenly [2].
	var metres: Array[float] = [0.0, 0.0, 0.0]
	var enemies: Array[int] = [0, 0, 0]
	var rows: Array[int] = [0, 0, 0]
	var hosts: int = 0
	var quiet_hosts: int = 0
	var bursts: int = 0
	var on_time: int = 0
	for lanes: int in [3, 5, 6]:
		for level_seed: int in range(1, 7):
			var config: LevelConfig = paced.duplicate() as LevelConfig
			config.lane_count = lanes
			config.level_seed = level_seed
			var tag: String = "paced lanes=%d seed=%d" % [lanes, level_seed]
			var gen := LevelGenerator.new()
			var layout: LevelLayout = gen.generate(config, tuning, patterns)
			check(gen.warnings.is_empty(), "a level paced in bursts generates without warnings %s %s" % [tag, gen.warnings])
			LayoutChecks.check_layout(self, layout, config, tag)
			LayoutChecks.check_rules(self, layout, config, tag)
			var again: LevelLayout = LevelGenerator.new().generate(config, tuning, patterns)
			check(JSON.stringify(again.to_dict()) == JSON.stringify(layout.to_dict()), "deterministic " + tag)
			for f: String in config.features:
				check(not LayoutChecks.feature_positions(layout, f).is_empty(), "it has `%s` %s" % [f, tag])
			var last: float = layout.length - config.end_clear_distance
			var stretches: Array[Vector2] = gen.quiet_stretches()
			check(stretches.size() == ceili((last - config.start_clear_distance) / cycle), "its quiet stretches " + tag)
			var level_quiet: float = 0.0
			for i: int in stretches.size():
				var s: Vector2 = stretches[i]
				check(is_equal_approx(s.x, config.start_clear_distance + i * cycle) and gen.quiet_at(s.x + 0.5)
					and gen.quiet_at(s.y - 0.5) and gen.burst_index(s.x + 0.5) == -1,
					"quiet stretch %d starts on the beat and is quiet throughout %s" % [i, tag])
				if s.y + 0.5 < last:
					check(not gen.quiet_at(s.y + 0.5) and gen.burst_index(s.y + 0.5) == i
						and is_equal_approx(gen.stretch_end(s.y + 0.5), s.y + config.burst_seconds * speed)
						and is_equal_approx(gen.stretch_end(s.x + 0.5), s.y), "burst %d follows it %s" % [i, tag])
					# The burst's first pick comes a burst spacing after its start at the latest, or after
					# the pattern running into it: the quiet spacing never carries the cursor past it. (A
					# burst right at the level's end may have room for no pattern at all.)
					var prev_end: float = 0.0
					var picked: bool = false
					for p: Dictionary in gen.picks:
						if float(p["at"]) >= s.y - 0.01:
							var due: float = maxf(s.y, prev_end) + config.burst_spacing_seconds * speed + 0.01
							bursts += 1
							on_time += 1 if float(p["at"]) <= due else 0
							picked = true
							break
						prev_end = float(p["at"]) + float(p["used"])
					check(picked or s.y > last - 130.0, "a burst gets its threats (at %.0f, the level's end-clear at %.0f) %s"
						% [s.y, last, tag])
				level_quiet += s.y - s.x
			metres[0] += level_quiet
			metres[1] += last - config.start_clear_distance - level_quiet
			for p: Dictionary in gen.picks:
				var pattern: Dictionary = by_id[String(p["id"])]
				var requires: Array = pattern.get("requires", [])
				var quiet_feature: bool = not requires.is_empty()
				for need: Variant in requires:
					quiet_feature = quiet_feature and config.quiet_features.has(String(need))
				var threat: bool = false
				var last_enemy: float = -1.0
				for e: Dictionary in pattern.get("elements", []):
					var kind: String = String(e.get("kind", ""))
					threat = threat or kind in ["gap", "fence", "sign", "enemy"]
					if kind == "enemy":
						last_enemy = maxf(last_enemy, float(e.get("at", 0.0)) + float(e.get("at_seconds", 0.0)) * speed)
				var at: float = float(p["at"])
				if gen.quiet_at(at):
					check(last_enemy < 0.0 or (quiet_feature and at + last_enemy < gen.stretch_end(at)),
						"a quiet stretch picks no enemy but its quiet features', whose enemies stand in it (%s at %.0f) %s"
						% [p["id"], at, tag])
				else:
					check(threat, "a burst picks only threats (%s at %.0f) %s" % [p["id"], at, tag])
					check(last_enemy < 0.0 or (not quiet_feature and at + last_enemy < gen.stretch_end(at)),
						"a burst's enemies stand in it, and a quiet feature's belong to the quiet stretches (%s at %.0f) %s"
						% [p["id"], at, tag])
			for e: Dictionary in layout.enemies:
				if String(e["type"]) == "cyborg" and bool((e.get("params", {}) as Dictionary).get("host", false)):
					hosts += 1
					quiet_hosts += 1 if gen.quiet_at(float(e["at"])) else 0
				else:
					enemies[0 if gen.quiet_at(float(e["at"])) else 1] += 1
			for at: float in _row_starts(layout):
				rows[0 if gen.quiet_at(at) else 1] += 1
			# The same level paced evenly.
			var even: LevelConfig = config.duplicate() as LevelConfig
			even.quiet_seconds = 0.0
			var flat: LevelLayout = LevelGenerator.new().generate(even, tuning, patterns)
			metres[2] += last - config.start_clear_distance
			enemies[2] += flat.enemies.size() - HostRules.hosts_in(flat).size()
			rows[2] += _row_starts(flat).size()
	var quiet_e: float = enemies[0] / metres[0] * 100.0
	var burst_e: float = enemies[1] / metres[1] * 100.0
	var even_e: float = enemies[2] / metres[2] * 100.0
	var quiet_r: float = rows[0] / metres[0] * 100.0
	var burst_r: float = rows[1] / metres[1] * 100.0
	var even_r: float = rows[2] / metres[2] * 100.0
	print("  quiet stretches and bursts, per 100 m: enemies %.2f quiet, %.2f in bursts, %.2f paced evenly; obstacle rows %.2f, %.2f, %.2f; %d hosts in 18 levels, %d in quiet stretches"
		% [quiet_e, burst_e, even_e, quiet_r, burst_r, even_r, hosts, quiet_hosts])
	check(quiet_hosts == hosts, "a quiet feature's enemies stand in the quiet stretches (%d of %d hosts)" % [quiet_hosts, hosts])
	check(quiet_e < burst_e * 0.25, "quiet stretches have few enemies (%.2f per 100 m, bursts %.2f)" % [quiet_e, burst_e])
	check(quiet_r < burst_r * 0.8, "and sparse obstacles (%.2f rows per 100 m, bursts %.2f)" % [quiet_r, burst_r])
	check(burst_e > even_e and burst_r > even_r * 0.9,
		"bursts are dense: more enemies than the level paced evenly (%.2f against %.2f per 100 m), as many obstacles (%.2f, %.2f)"
		% [burst_e, even_e, burst_r, even_r])
	check(on_time == bursts, "every burst begins on time (%d of %d)" % [on_time, bursts])

	# Rules that guarantee an enemy put it in a burst, a quiet feature's (the host here) in a quiet stretch.
	var gen := LevelGenerator.new()
	gen.generate(paced, tuning, patterns)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var in_bursts: bool = true
	for i: int in 200:
		var at: float = gen.burst_spot(rng, 500.0, 2000.0, "drone")
		in_bursts = in_bursts and not is_nan(at) and at >= 500.0 and at <= 2000.0 and not gen.quiet_at(at)
	check(in_bursts, "burst_spot draws spots in bursts")
	check(is_nan(gen.burst_spot(rng, 500.0, 2000.0, "host")), "burst_spot draws nothing for a quiet feature")
	check(is_nan(gen.burst_spot(rng, 70.0, 300.0, "drone")), "with no burst in reach, the rule picks its spot as usual")
	var spots: Array[float] = []
	for i: int in 150:
		spots.append(500.0 + i * 10.0)
	var drone_pools: Array[Array] = gen.pacing_pools(spots, "drone")
	var host_pools: Array[Array] = gen.pacing_pools(spots, "host")
	var pools_ok: bool = drone_pools.size() == 2 and host_pools.size() == 2 and not drone_pools[0].is_empty() \
		and not host_pools[0].is_empty() and drone_pools[0].size() + drone_pools[1].size() == spots.size() \
		and drone_pools[0].size() == host_pools[1].size()
	for at: float in drone_pools[0]:
		pools_ok = pools_ok and not gen.quiet_at(at)
	for at: float in host_pools[0]:
		pools_ok = pools_ok and gen.quiet_at(at)
	check(pools_ok, "pacing_pools offers a burst's spots first, and a quiet feature's the quiet stretches' (%d, %d of %d)"
		% [drone_pools[0].size(), host_pools[0].size(), spots.size()])
	var even_gen := LevelGenerator.new()
	var even_config: LevelConfig = paced.duplicate() as LevelConfig
	even_config.quiet_seconds = 0.0
	even_gen.generate(even_config, tuning, patterns)
	var state: int = rng.state
	check(is_nan(even_gen.burst_spot(rng, 500.0, 2000.0, "drone")) and rng.state == state and even_gen.quiet_stretches().is_empty()
		and not even_gen.quiet_at(600.0) and even_gen.burst_index(600.0) == -1
		and even_gen.pacing_pools(spots, "drone") == [spots] and even_gen.pacing_pools(spots, "host") == [spots],
		"a level paced evenly has no quiet stretches or bursts, and draws nothing for them")

	# quiet_seconds 0 switches it all off: the other settings change nothing.
	var reference: LevelConfig = paced.duplicate() as LevelConfig
	var defaults := LevelConfig.new()
	reference.quiet_seconds = 0.0
	reference.burst_seconds = defaults.burst_seconds
	reference.quiet_spacing_seconds = defaults.quiet_spacing_seconds
	reference.burst_spacing_seconds = defaults.burst_spacing_seconds
	reference.quiet_features = defaults.quiet_features
	check(JSON.stringify(LevelGenerator.new().generate(even_config, tuning, patterns).to_dict())
		== JSON.stringify(LevelGenerator.new().generate(reference, tuning, patterns).to_dict()),
		"with quiet_seconds 0, the other pacing settings change nothing")


## The track distances where a row of holes or fences starts (one per row, whatever its lanes).
func _row_starts(layout: LevelLayout) -> Array[float]:
	var seen: Dictionary = {}
	for g: Dictionary in layout.gaps:
		seen["g%.2f" % float(g["start"])] = float(g["start"])
	for f: Dictionary in layout.fences:
		seen["f%.2f" % float(f["at"])] = float(f["at"])
	var out: Array[float] = []
	out.assign(seen.values())
	return out


## GDD §6 (one new thing at a time): in a level paced in bursts, a burst takes at most one
## introduction. Two enemies whose starts fall in the same quiet stretch wait for the bursts (a quiet
## stretch places no enemy), and come in different ones, each after its start.
func _test_pacing_introductions(base: LevelConfig) -> void:
	var patterns: Array = LevelGenerator.load_for(base)
	var checked: int = 0
	for lanes: int in [3, 5, 6]:
		for level_seed: int in range(1, 7):
			var config: LevelConfig = base.duplicate() as LevelConfig
			config.features = PackedStringArray(["cyborg", "window_cyborg", "pulsing"])
			config.lane_count = lanes
			config.level_seed = level_seed
			config.difficulty = 0.4
			config.duration_seconds = 150.0
			config.quiet_seconds = 14.0
			config.burst_seconds = 7.0
			var starts: Dictionary[String, float] = {"cyborg": 0.2, "window_cyborg": 0.2}
			config.feature_starts = starts
			var tag: String = "lanes=%d seed=%d" % [lanes, level_seed]
			var gen := LevelGenerator.new()
			var layout: LevelLayout = gen.generate(config, tuning, patterns)
			check(gen.warnings.is_empty(), "two introductions in a level paced in bursts: no warnings " + tag)
			var start: float = 0.2 * layout.length
			check(gen.quiet_at(start), "both starts fall in a quiet stretch " + tag)
			var first: Dictionary = {}
			for p: Dictionary in gen.picks:
				for f: String in ["cyborg", "window_cyborg"]:
					if (p["requires"] as Array).has(f) and not first.has(f):
						first[f] = float(p["at"])
			if first.size() < 2:
				check(false, "both features are introduced " + tag)
				continue
			for f: String in first:
				check(float(first[f]) >= start and not gen.quiet_at(float(first[f])),
					"`%s` is introduced after its start, in a burst (%.0f) %s" % [f, first[f], tag])
			check(gen.burst_index(float(first["cyborg"])) != gen.burst_index(float(first["window_cyborg"])),
				"in different bursts (%.0f, %.0f) %s" % [first["cyborg"], first["window_cyborg"], tag])
			checked += 1
	check(checked == 18, "introductions checked in %d levels" % checked)


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
			cases.append([String(p["id"]), features, [p], 2, 1])
	check(cases.size() >= 6, "gauntlet patterns put floor pieces or enemies under their own ceiling (%d)" % cases.size())
	cases.append(["drone", ["ceilings", "pulsing", "ramps", "speed_pads", "drone"], LevelGenerator.load_for(base), 2, 2])
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
				var grid := FloorRoute.new(layout, tuning)
				var runs: int = 0
				for h: Dictionary in layout.hulls:
					if runs >= int(c[3]):
						break
					var route: Dictionary = LayoutChecks.floor_route(grid, zones, h)
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
	check(ran >= 45, "floor routes run on physics: %d" % ran)


## Runs `route` (FloorRoute) on real physics: the layout's floor pieces, pads and ceilings the route
## passes (from its start to its end: what lies beyond is the next stretch's), moved to start after a
## run-up; no enemies. Returns RunSim.run's result, and `reached`: the player got past the route's
## end.
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
			if end < from - 1.0 or start > to:
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

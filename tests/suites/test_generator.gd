extends TestSuite
## Generator fairness over many seeds, lane counts and difficulties, plus pattern-data checks.


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
				_check_layout(a, config, tag)
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


func _check_layout(layout: LevelLayout, config: LevelConfig, tag: String) -> void:
	var n: int = layout.lane_count
	var max_gap: float = tuning.jump_distance(tuning.run_speed) * config.max_gap_jump_fraction + 0.001
	var finish_buffer: float = layout.length - config.end_clear_distance + 0.001
	var landing: float = config.hull_landing_seconds * tuning.run_speed
	for g: Dictionary in layout.gaps:
		check(g["lane"] >= 0 and g["lane"] < n, "gap lane in range " + tag)
		check(g["end"] - g["start"] <= max_gap, "gap jumpable (%.1f m) %s" % [g["end"] - g["start"], tag])
		check(g["end"] <= finish_buffer, "gap before the end-clear stretch " + tag)
	for f: Dictionary in layout.fences:
		check(f["lane"] >= 0 and f["lane"] < n, "fence lane in range " + tag)
		check(not _gapped_at(layout, f["lane"], f["at"]), "fence not over a gap at %.1f %s" % [f["at"], tag])
		check(f["at"] <= finish_buffer, "fence before the end-clear stretch " + tag)
	check(_longest_all_lane_hole(layout) <= max_gap, "every all-lane hole is jumpable " + tag)
	for p: Dictionary in layout.pads:
		var covered: bool = false
		for h: Dictionary in layout.hulls:
			if h["start"] <= p["at"] - 1.0 and h["end"] >= p["at"] + 10.0:
				covered = true
		check(covered, "pad at %.1f has a hull above %s" % [p["at"], tag])
		check(not _gapped_between(layout, p["lane"], p["at"] - 6.0, p["at"] + tuning.pad_length),
			"pad at %.1f is reachable on solid floor %s" % [p["at"], tag])
	for h: Dictionary in layout.hulls:
		check(h["end"] + landing <= finish_buffer, "hull and its landing end before the finish " + tag)
		for f: Dictionary in layout.fences:
			check(f["at"] < h["start"] or f["at"] > h["end"], "no fence under the ceiling at %.1f %s" % [f["at"], tag])
		for lane: int in n:
			check(not _gapped_between(layout, lane, h["start"], h["end"]), "no gap under the ceiling at %.1f %s" % [h["start"], tag])
		for lane: int in n:
			check(not _gapped_between(layout, lane, h["end"] - 2.0, h["end"] + landing * 0.8),
				"hull landing clear at %.1f %s" % [h["end"], tag])
	for r: Dictionary in layout.ramps:
		var lane: int = layout.outer_lane(r["side"])
		check(not _gapped_between(layout, lane, r["at"], r["at"] + tuning.ramp_length), "ramp on solid floor " + tag)
		for s: Dictionary in layout.signs:
			if s["side"] == r["side"]:
				check(s["end"] < r["at"] - 2.0 or s["start"] > r["at"] + tuning.ramp_length + 2.0,
					"ramp entry not blocked by a sign " + tag)
	for s: Dictionary in layout.signs:
		check(s["end"] <= finish_buffer, "sign before the end-clear stretch " + tag)


func _gapped_at(layout: LevelLayout, lane: int, d: float) -> bool:
	return _gapped_between(layout, lane, d, d)


func _gapped_between(layout: LevelLayout, lane: int, from: float, to: float) -> bool:
	for g: Dictionary in layout.gaps:
		if g["lane"] == lane and g["start"] <= to and g["end"] >= from:
			return true
	return false


## Longest stretch where every lane is a hole at once (intersection of the lanes' gap intervals).
func _longest_all_lane_hole(layout: LevelLayout) -> float:
	var common: Array[Vector2] = []
	for lane: int in layout.lane_count:
		var mine: Array[Vector2] = []
		for g: Dictionary in layout.gaps:
			if g["lane"] == lane:
				mine.append(Vector2(g["start"], g["end"]))
		if lane == 0:
			common = mine
			continue
		var next: Array[Vector2] = []
		for a: Vector2 in common:
			for b: Vector2 in mine:
				var lo: float = maxf(a.x, b.x)
				var hi: float = minf(a.y, b.y)
				if hi > lo:
					next.append(Vector2(lo, hi))
		common = next
	var longest: float = 0.0
	for v: Vector2 in common:
		longest = maxf(longest, v.y - v.x)
	return longest

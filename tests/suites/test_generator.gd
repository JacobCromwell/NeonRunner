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

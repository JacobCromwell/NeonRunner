extends TestSuite
## Approved City 1 density: both encounter count and mean width rise by 30%, rounded up.
## Baselines come from copies with only the new tunables disabled, never shared resource rewrites.


func run() -> void:
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	for lanes: int in [3, 5, 6]:
		var config: LevelConfig = campaign.configure(campaign.step("city/1"), lanes)
		_compare(config, true)
		for level_seed: int in range(1, 9):
			var sweep: LevelConfig = config.duplicate() as LevelConfig
			sweep.level_seed = level_seed
			_compare(sweep, false)
		for tier: int in range(1, campaign.tier_count()):
			_compare(campaign.configure(campaign.step("city/1"), lanes, tier), false)
	_test_disabled_levels(campaign)
	_test_constraints()
	_test_widening_beside_doodads()
	_test_separate_tunables(campaign)


func _compare(config: LevelConfig, shipped: bool) -> void:
	var lanes: int = config.lane_count
	var tag: String = "lanes=%d seed=%d difficulty=%.2f" % [lanes, config.level_seed, config.difficulty]
	var patterns: Array = LevelGenerator.load_for(config)
	var gen := LevelGenerator.new()
	var layout: LevelLayout = gen.generate(config, tuning, patterns)
	var baseline: LevelConfig = config.duplicate() as LevelConfig
	baseline.gap_encounter_increase = 0.0
	baseline.gap_lane_increase = 0.0
	var baseline_gen := LevelGenerator.new()
	var before: LevelLayout = baseline_gen.generate(baseline, tuning, patterns)
	var original_rows: Array[Dictionary] = GapDensity.rows(before)
	var after_rows: Array[Dictionary] = GapDensity.rows(layout)
	var count_target: int = ceili(original_rows.size() * 1.3)
	var mean_target: float = float(before.gaps.size()) / original_rows.size() * 1.3
	var lane_target: int = ceili(after_rows.size() * mean_target)
	var mean: float = float(layout.gaps.size()) / after_rows.size()
	if shipped:
		print("  City 1 %s: %.0fs, rows/lane-gaps %d/%d -> %d/%d; mean %.3f -> %.3f; targets %d rows, %.3f mean (%d lane-gaps)"
			% [tag, config.duration_seconds, original_rows.size(), before.gaps.size(), after_rows.size(),
				layout.gaps.size(), float(before.gaps.size()) / original_rows.size(), mean, count_target,
				mean_target, lane_target])
		check(after_rows.size() >= count_target, "shipped encounters increase at least 30% " + tag)
		check(mean >= mean_target, "shipped mean missing lanes increases at least 30% " + tag)
		check((gen.gap_density_result["constraints"] as PackedStringArray).is_empty(), "shipped targets unconstrained " + tag)
		var cached_baseline: LevelLayout = LayoutCache.generate(baseline, tuning, patterns)
		var cached: LevelGenerator = LayoutCache.generator(config, tuning, patterns)
		check(cached_baseline.to_dict() == before.to_dict() and cached.layout.to_dict() == layout.to_dict(),
			"cache distinguishes enabled and disabled tunables " + tag)
		check(cached.gap_density_result == gen.gap_density_result, "cache preserves density report " + tag)
	var constraints: PackedStringArray = gen.gap_density_result["constraints"]
	if not constraints.is_empty():
		print("  Constrained City 1 %s: rows %d/%d, mean %.3f/%.3f: %s"
			% [tag, after_rows.size(), count_target, mean, mean_target, "; ".join(constraints)])
	check(after_rows.size() >= count_target or not constraints.is_empty(), "encounter shortfalls explicitly reported " + tag)
	check(mean >= mean_target or not constraints.is_empty(), "width shortfalls explicitly reported " + tag)
	check(int(gen.gap_density_result["row_target"]) == count_target
		and int(gen.gap_density_result["lane_gap_target"]) == lane_target, "exact independent round-up targets " + tag)
	check(is_equal_approx(layout.length, before.length) and config.duration_seconds == 55.0,
		"City 1 stays 55 seconds " + tag)
	check(gen.warnings.is_empty(), "no pattern or guarantee warnings " + tag)
	for gap: Dictionary in before.gaps:
		check(layout.gaps.has(gap), "every original gap preserved " + tag)
	for key: String in before.to_dict():
		if key not in ["gaps", "credits"]:
			check(layout.to_dict()[key] == before.to_dict()[key], "non-gap pieces unchanged: %s %s" % [key, tag])
	check(gen.picks == baseline_gen.picks and gen.fills == baseline_gen.fills,
		"patterns, introductions and fills unchanged " + tag)
	check(baseline_gen.gap_density_result.is_empty(), "zero tunables disable pass " + tag)
	var again: LevelLayout = LevelGenerator.new().generate(config, tuning, patterns)
	check(layout.to_dict() == again.to_dict(), "complete layout deterministic " + tag)
	LayoutChecks.check_layout(self, layout, config, tag)
	LayoutChecks.check_rules(self, layout, config, tag)
	var route: Dictionary = FloorRoute.new(layout, config.movement_for(tuning)).find(0.0, layout.length)
	check(route["ok"], "viable floor route " + tag)
	for row: Dictionary in after_rows:
		check(float(row["start"]) >= config.start_clear_distance, "intro buffer intact " + tag)
		var original: bool = false
		for old: Dictionary in original_rows:
			original = original or (row["start"] == old["start"] and row["end"] == old["end"])
		if original:
			continue
		if (row["lanes"] as Array).size() == lanes:
			var window := Vector2(float(row["start"]) - config.spacing_seconds_hard * gen.speed,
				float(row["end"]) + config.spacing_seconds_hard * gen.speed)
			for fence: Dictionary in layout.fences:
				check(float(fence["at"]) < window.x or float(fence["at"]) > window.y,
					"full-width new row has clear jump and landing " + tag)
		for other: Dictionary in after_rows:
			if is_same(other, row):
				continue
			var separation: float = maxf(float(row["start"]) - float(other["end"]),
				float(other["start"]) - float(row["end"]))
			check(separation >= config.spacing_seconds_hard * gen.speed - 0.001,
				"new encounter separate, not a staggered part of another " + tag)


func _test_disabled_levels(campaign: Campaign) -> void:
	check(LevelConfig.new().gap_encounter_increase == 0.0 and LevelConfig.new().gap_lane_increase == 0.0,
		"new tunables default off")
	for step: CampaignStep in campaign.steps():
		if not step.is_level() or step.id == "city/1" or step.is_minigame():
			continue
		for lanes: int in [3, 5, 6]:
			var config: LevelConfig = campaign.configure(step, lanes)
			check(config.gap_encounter_increase == 0.0 and config.gap_lane_increase == 0.0,
				"other level disabled: %s lanes=%d" % [step.id, lanes])
			var copy: LevelConfig = config.duplicate() as LevelConfig
			copy.gap_encounter_increase = 0.0
			copy.gap_lane_increase = 0.0
			var patterns: Array = LevelGenerator.load_for(config)
			var a: LevelLayout = LayoutCache.generate(config, tuning, patterns)
			var b: LevelLayout = LevelGenerator.new().generate(copy, tuning, patterns)
			check(a.to_dict() == b.to_dict(), "other level byte-for-byte unchanged: %s lanes=%d" % [step.id, lanes])


func _test_constraints() -> void:
	var config := LevelConfig.new()
	config.lane_count = 3
	config.gap_encounter_increase = 0.3
	config.gap_lane_increase = 0.3
	# One existing all-lane row fills all usable floor; no extra encounter or lane can fit.
	var layout := LevelLayout.new()
	layout.lane_count = 3
	var start: float = config.start_clear_distance
	var end: float = start + tuning.jump_distance(tuning.run_speed) * 0.5
	layout.length = end + config.end_clear_distance
	for lane: int in 3:
		layout.gaps.append({"lane": lane, "start": start, "end": end})
	var before: Dictionary = layout.to_dict().duplicate(true)
	var gen: LevelGenerator = LevelGenerator.for_layout(config, tuning, layout)
	var result: Dictionary = GapDensity.apply(gen)
	check(layout.to_dict() == before, "constraints never remove pieces or lengthen level")
	check(int(result["row_target"]) == 2 and int(result["lane_gap_target"]) == 4,
		"constrained integer targets still round up independently")
	check((result["constraints"] as PackedStringArray).size() == 2,
		"reports both no encounter room and impossible mean width, not proxy success")


## FIX4: a zone doodad standing just past a row (as the doodads may: they keep only their push's lead
## clear before them) doesn't stop the row widening in lanes away from it: a widening keeps off the
## doodad's own lane (never the lane the row leaves open beside it) and its window, not the margin
## around it in every lane. With that margin, a doodad decided which rows widened, so City 1's doodads
## moved its extra gaps (test_doodads: doodads only add). A full-width jump still keeps the margin.
func _test_widening_beside_doodads() -> void:
	var config := LevelConfig.new()
	config.lane_count = 5
	config.gap_encounter_increase = 0.0
	config.gap_lane_increase = 0.5
	var row_start: float = config.start_clear_distance + 60.0
	var row_end: float = row_start + 7.0
	for case: Array in [["beside a doodad in lane 2", [1, 3]], ["one lane short of full width", [0, 1, 3, 4]]]:
		var layout := LevelLayout.new()
		layout.lane_count = 5
		layout.length = row_end + 400.0
		for lane: int in case[1]:
			layout.gaps.append({"lane": lane, "start": row_start, "end": row_end})
		var gen: LevelGenerator = LevelGenerator.for_layout(config, tuning, layout)
		var small: float = gen.tuning.doodad_size(&"small").z
		var at: float = row_end + LevelGenerator.doodad_lead_for(gen.tuning) + 0.5
		layout.doodads.append({"lane": 2, "start": at, "end": at + small, "size": "small", "side": -1, "seed": 1})
		var result: Dictionary = GapDensity.apply(gen)
		var lanes: Array[int] = []
		for g: Dictionary in layout.gaps:
			lanes.append(int(g["lane"]))
		var tag: String = case[0]
		if (case[1] as Array).size() == 2:
			check(layout.gaps.size() == 3 and not lanes.has(2) and (lanes.has(0) or lanes.has(4)),
				"a row %s widens in a lane away from it, never the doodad's (lanes %s)" % [tag, lanes])
		else:
			check(layout.gaps.size() == 4 and not lanes.has(2)
				and not (result["constraints"] as PackedStringArray).is_empty(),
				"a row %s beside a doodad stays as it is: no full-width jump beside one, the doodad's lane open (lanes %s)"
				% [tag, lanes])


func _test_separate_tunables(campaign: Campaign) -> void:
	for encounter_increase: float in [0.0, 0.3]:
		var config: LevelConfig = campaign.configure(campaign.step("city/1"), 5)
		config.gap_encounter_increase = encounter_increase
		config.gap_lane_increase = 0.3 if encounter_increase == 0.0 else 0.0
		var gen := LevelGenerator.new()
		var layout: LevelLayout = gen.generate(config, tuning, LevelGenerator.load_for(config))
		var baseline: LevelConfig = config.duplicate() as LevelConfig
		baseline.gap_encounter_increase = 0.0
		baseline.gap_lane_increase = 0.0
		var before: LevelLayout = LevelGenerator.new().generate(baseline, tuning, LevelGenerator.load_for(baseline))
		var original_count: int = GapDensity.rows(before).size()
		var count: int = GapDensity.rows(layout).size()
		var mean: float = float(layout.gaps.size()) / count
		check(count == ceili(original_count * (1.0 + encounter_increase)), "encounter tunable independent")
		check(mean >= float(before.gaps.size()) / original_count * (1.0 + config.gap_lane_increase),
			"mean tunable independent")

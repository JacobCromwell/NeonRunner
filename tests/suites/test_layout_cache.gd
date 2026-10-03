extends TestSuite
## T-SPEED: LayoutCache (tests/helpers/layout_cache.gd), the test-only cache of built level layouts
## shared by every suite in one `tools/godot.sh test` run. Checked here: a cached layout is identical
## (field by field) to a fresh, uncached build of the same (config, tuning, patterns), hitting the
## cache is far cheaper than building, two separately-duplicated LevelConfigs with the same content
## share one build, a content difference (even one the resource_path shortcut could have missed) is
## never conflated, mutating what generate() hands back never corrupts a later call's copy,
## generator()'s stand-in answers its pure queries exactly as a real generator would, and `enabled`
## turns caching off cleanly. Suites that use the cache are checked over the ordinary suites' own
## runs, not here (its own doc comment lists the rule: never cache both sides of a "does regenerating
## give the same layout" comparison). Uses the inherited TestSuite.LEVEL_PATH (the prototype level).


func run() -> void:
	LayoutCache.clear()
	_test_identical_to_fresh()
	_test_cheaper_than_building()
	_test_duplicated_configs_share_one_build()
	_test_content_differences_never_conflated()
	_test_copies_are_independent()
	_test_generator_stand_in()
	_test_disabled()
	LayoutCache.clear()


## A cached layout matches a fresh, uncached build field by field (to_dict(), JSON.stringify): the
## cache never hands back something a real generate() would not have.
func _test_identical_to_fresh() -> void:
	LayoutCache.clear()
	var config := _config(5, 0.6, 11)
	var patterns: Array = LevelGenerator.load_patterns(config.patterns_path)
	var fresh: LevelLayout = LevelGenerator.new().generate(config.duplicate() as LevelConfig, tuning, patterns)
	var cached: LevelLayout = LayoutCache.generate(config, tuning, patterns)
	check(JSON.stringify(cached.to_dict()) == JSON.stringify(fresh.to_dict()), "a cached layout matches a fresh build")
	check(LayoutCache.misses == 1 and LayoutCache.hits == 0, "the first ask for it is a miss (%d miss, %d hit)" %
		[LayoutCache.misses, LayoutCache.hits])
	# A second ask for the identical content is a hit, and still matches.
	var again: LevelLayout = LayoutCache.generate(config, tuning, patterns)
	check(JSON.stringify(again.to_dict()) == JSON.stringify(fresh.to_dict()), "a second ask still matches a fresh build")
	check(LayoutCache.hits == 1, "the second ask for the same content is a hit (%d)" % LayoutCache.hits)


## Reading the same level through the cache costs less, per call, than building it for real (a loose
## bound on purpose: this runs on a machine several agents' test runs and renders may be sharing at
## once, T-BUDGET2, so it compares *per-call* averages from the minimum of a few timed passes of each
## side, as skin_suite.gd's own build-time budgets do, rather than a single, noise-prone sample --
## comparing batch totals at different batch sizes, as an earlier version of this check did, let a
## heavily loaded machine's fixed per-call scheduling overhead -- paid by every call, cached or not --
## swamp the signal, since 100 cheap calls then pay that fixed cost 100 times over to 1 real build's
## once).
func _test_cheaper_than_building() -> void:
	LayoutCache.clear()
	var config := _config(5, 0.6, 12)
	var patterns: Array = LevelGenerator.load_patterns(config.patterns_path)
	var huge: int = 1 << 30  # far beyond any plausible build time, in microseconds
	var build_usec: int = huge
	for pass_i: int in 3:
		var t0: int = Time.get_ticks_usec()
		LevelGenerator.new().generate(config.duplicate() as LevelConfig, tuning, patterns)
		build_usec = mini(build_usec, Time.get_ticks_usec() - t0)
	LayoutCache.generate(config, tuning, patterns)  # primes the cache (one real build; not timed)
	const READS: int = 100
	var cached_usec_per_read: float = huge
	for pass_i: int in 3:
		var t1: int = Time.get_ticks_usec()
		for i: int in READS:
			LayoutCache.generate(config, tuning, patterns)
		cached_usec_per_read = minf(cached_usec_per_read, float(Time.get_ticks_usec() - t1) / READS)
	check(cached_usec_per_read < float(build_usec), "a cached read (%.1f us, best of 3) costs less than a real build (%d us, best of 3)" %
		[cached_usec_per_read, build_usec])


## Two LevelConfigs duplicated separately (as every suite does to set lane count, seed and
## difficulty), with the same content but no shared identity and no resource_path, still share one
## build: the signature is field by field, not by instance or by path.
func _test_duplicated_configs_share_one_build() -> void:
	LayoutCache.clear()
	var a := _config(6, 0.4, 21)
	var b := _config(6, 0.4, 21)  # _config() duplicate()s the base level fresh each call: a != b.
	check(a != b, "the two configs are different instances")
	var patterns: Array = LevelGenerator.load_patterns(a.patterns_path)
	LayoutCache.generate(a, tuning, patterns)
	LayoutCache.generate(b, tuning, patterns)
	check(LayoutCache.misses == 1 and LayoutCache.hits == 1, "one real build, one cache hit (%d miss, %d hit)" %
		[LayoutCache.misses, LayoutCache.hits])


## Two configs that differ in only one field (lane count here, difficulty, and a feature_starts entry
## a resource_path shortcut would never see since it's set on an in-memory duplicate) never share a
## build: every difference the generator could see is in the signature.
func _test_content_differences_never_conflated() -> void:
	LayoutCache.clear()
	var patterns: Array = LevelGenerator.load_patterns(_config(5, 0.6, 30).patterns_path)
	var lanes_a := _config(5, 0.6, 30)
	var lanes_b := _config(6, 0.6, 30)
	LayoutCache.generate(lanes_a, tuning, patterns)
	LayoutCache.generate(lanes_b, tuning, patterns)
	check(LayoutCache.misses == 2, "different lane counts never share a build (%d miss)" % LayoutCache.misses)
	LayoutCache.clear()
	var diff_a := _config(5, 0.6, 30)
	var diff_b := _config(5, 0.61, 30)
	LayoutCache.generate(diff_a, tuning, patterns)
	LayoutCache.generate(diff_b, tuning, patterns)
	check(LayoutCache.misses == 2, "different difficulties never share a build (%d miss)" % LayoutCache.misses)
	LayoutCache.clear()
	var starts_a := _config(5, 0.6, 30)
	var starts_b := _config(5, 0.6, 30)
	var starts: Dictionary[String, float] = {"ramps": 0.3}
	starts_b.feature_starts = starts
	LayoutCache.generate(starts_a, tuning, patterns)
	LayoutCache.generate(starts_b, tuning, patterns)
	check(LayoutCache.misses == 2, "a feature_starts entry set only on one of them is never missed (%d miss)" % LayoutCache.misses)
	# But two with the same content and different cosmetics (id, display_name) do share one: neither
	# reaches the generator.
	LayoutCache.clear()
	var cosmetic_a := _config(5, 0.6, 30)
	var cosmetic_b := _config(5, 0.6, 30)
	cosmetic_b.id = &"renamed"
	cosmetic_b.display_name = "Renamed"
	LayoutCache.generate(cosmetic_a, tuning, patterns)
	LayoutCache.generate(cosmetic_b, tuning, patterns)
	check(LayoutCache.misses == 1 and LayoutCache.hits == 1, "a cosmetic-only difference still shares a build (%d miss, %d hit)" %
		[LayoutCache.misses, LayoutCache.hits])


## generate() always hands back a layout the caller can mutate freely: appending to one call's lists,
## or changing its length, never changes what a later call for the identical content returns.
func _test_copies_are_independent() -> void:
	LayoutCache.clear()
	var config := _config(5, 0.6, 40)
	var patterns: Array = LevelGenerator.load_patterns(config.patterns_path)
	var first: LevelLayout = LayoutCache.generate(config, tuning, patterns)
	var before: String = JSON.stringify(first.to_dict())
	first.gaps.append({"lane": 0, "start": 0.0, "end": 1.0})
	first.length = -1.0
	var second: LevelLayout = LayoutCache.generate(config, tuning, patterns)
	check(JSON.stringify(second.to_dict()) == before, "mutating one call's layout never reaches the next call's")
	check(second.length != -1.0 and second.gaps.size() != first.gaps.size(), "the mutation stayed local (%d vs %d gaps)" %
		[second.gaps.size(), first.gaps.size()])


## generator()'s LevelGenerator stand-in answers warnings, attempts, picks and fills, and its pure,
## read-only queries (feature_start, quiet_at, difficulty_at, placeable_features), exactly as the real
## generator that built the cached layout did.
func _test_generator_stand_in() -> void:
	LayoutCache.clear()
	var config := _config(5, 0.6, 50)
	config.features = PackedStringArray(["ramps", "ceilings", "pulsing", "cyborg"])
	config.feature_starts = {"cyborg": 0.2}
	var patterns: Array = LevelGenerator.load_patterns(config.patterns_path)
	var real := LevelGenerator.new()
	var real_layout: LevelLayout = real.generate(config.duplicate() as LevelConfig, tuning, patterns)
	var stand_in: LevelGenerator = LayoutCache.generator(config, tuning, patterns)
	check(JSON.stringify(stand_in.layout.to_dict()) == JSON.stringify(real_layout.to_dict()), "the stand-in's layout matches")
	check(stand_in.warnings == real.warnings, "its warnings match (%s vs %s)" % [stand_in.warnings, real.warnings])
	check(stand_in.attempts == real.attempts, "its attempts match (%d vs %d)" % [stand_in.attempts, real.attempts])
	check(JSON.stringify(stand_in.picks) == JSON.stringify(real.picks), "its picks match")
	check(JSON.stringify(stand_in.fills) == JSON.stringify(real.fills), "its fills match")
	check(is_equal_approx(stand_in.feature_start("cyborg"), real.feature_start("cyborg")), "feature_start matches (%.2f vs %.2f)" %
		[stand_in.feature_start("cyborg"), real.feature_start("cyborg")])
	check(is_equal_approx(stand_in.difficulty_at(0.5), real.difficulty_at(0.5)), "difficulty_at matches")
	check(is_equal_approx(stand_in.pace, real.pace) and is_equal_approx(stand_in.speed, real.speed), "pace and speed match")
	check(stand_in.placeable_features(patterns) == real.placeable_features(patterns), "placeable_features matches")
	for at: float in [50.0, 500.0, 1500.0]:
		check(stand_in.quiet_at(at) == real.quiet_at(at), "quiet_at(%.0f) matches" % at)


## `enabled = false` makes every call build fresh (always a miss): used by a suite proving its checks
## still pass without the cache.
func _test_disabled() -> void:
	LayoutCache.clear()
	var config := _config(5, 0.6, 60)
	var patterns: Array = LevelGenerator.load_patterns(config.patterns_path)
	LayoutCache.generate(config, tuning, patterns)
	LayoutCache.enabled = false
	LayoutCache.generate(config, tuning, patterns)
	LayoutCache.generate(config, tuning, patterns)
	LayoutCache.enabled = true
	check(LayoutCache.misses == 1, "disabled, nothing is ever cached (still %d miss, not 3)" % LayoutCache.misses)


func _config(lanes: int, difficulty: float, level_seed: int) -> LevelConfig:
	var config := (load(LEVEL_PATH) as LevelConfig).duplicate() as LevelConfig
	config.lane_count = lanes
	config.difficulty = difficulty
	config.level_seed = level_seed
	return config

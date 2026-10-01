extends SkinSuite
## T-BUDGET: SkinSuite.build_all()'s build-time budget check (BUILD_BUDGET_MEAN_MS,
## BUILD_BUDGET_MAX_MS) measures each build step as the minimum of BUILD_TIMING_PASSES fresh
## builds, so a loaded machine preempting one pass doesn't fail a skin that is as cheap as ever
## (see whole_level()). T-BUDGET2: build_all() also scales the budget by load_factor(), read off a
## reference build timed alongside the skin's own passes, so a machine where *every* pass is slow
## (several agents' test runs and renders at once) doesn't fail it either. This proves the other side
## still holds under both: a skin that really is expensive still fails the mean budget, at whatever
## load this run happens to measure, including the heaviest load MEAN_FACTOR_CAP still lets through.
## SlowTestSkin (tests/helpers/slow_test_skin.gd) draws exactly like GreyboxSkin but busy-waits a few
## extra milliseconds of real wall-clock time per lane in floor_segment() -- a cost that, unlike a
## real skin's, grows slower than the reference's own under load, so the scaled-and-capped budget
## never quite catches up to it, whether this suite runs alone or the machine is busy with other
## work.

func run() -> void:
	var layout: LevelLayout = RunSim.layout(3, 200.0)
	var skin := SlowTestSkin.new()
	var stats: Dictionary = await build_all(layout, skin, BUILD_TIMING_PASSES)
	var mean: float = mean_ms(stats["times"])
	var worst: float = max_ms(stats["times"])
	var factor: float = load_factor(stats["reference_times"], MEAN_SAFETY_MARGIN, MEAN_FACTOR_CAP)
	var budget_mean: float = BUILD_BUDGET_MEAN_MS * factor
	print(("  slow test skin (3 lanes, min of %d passes): build mean %.2f ms, max %.2f ms, load " +
		"factor %.2fx (budget %.1f/%.1f at load factor 1x)") % [BUILD_TIMING_PASSES, mean, worst, factor,
		BUILD_BUDGET_MEAN_MS, BUILD_BUDGET_MAX_MS])
	check(not stats["times"].is_empty(), "the test level builds some chunks to time (%d)" % stats["times"].size())
	check(mean > budget_mean, "an expensive skin still fails the mean build budget even scaled for load: mean %.2f ms (budget %.1f at load factor %.2fx)" % [
		mean, budget_mean, factor])
	# The added cost is real, not noise: a single pass (no minimum-of-several, no load scaling)
	# already shows it.
	var single: Dictionary = await build_all(layout, skin)
	var single_mean: float = mean_ms(single["times"])
	check(single_mean > BUILD_BUDGET_MEAN_MS, "a single build already shows the expense: mean %.2f ms" % single_mean)

extends SkinSuite
## T-BUDGET: SkinSuite.build_all()'s build-time budget check (BUILD_BUDGET_MEAN_MS,
## BUILD_BUDGET_MAX_MS) measures each build step as the minimum of BUILD_TIMING_PASSES fresh
## builds, so a loaded machine preempting one pass doesn't fail a skin that is as cheap as ever
## (see whole_level()). This proves the other side still holds: a skin that really is expensive
## still fails the mean budget. SlowTestSkin (tests/helpers/slow_test_skin.gd) draws exactly like
## GreyboxSkin but busy-waits a few extra milliseconds of real wall-clock time per lane in
## floor_segment(), so every pass -- and so the minimum across passes -- carries the added cost,
## whether this suite runs alone or the machine is busy with other work.

func run() -> void:
	var layout: LevelLayout = RunSim.layout(3, 200.0)
	var skin := SlowTestSkin.new()
	var stats: Dictionary = await build_all(layout, skin, BUILD_TIMING_PASSES)
	var mean: float = _mean(stats["times"])
	var worst: float = _max(stats["times"])
	print("  slow test skin (3 lanes, min of %d passes): build mean %.2f ms, max %.2f ms (budget %.1f/%.1f)" % [
		BUILD_TIMING_PASSES, mean, worst, BUILD_BUDGET_MEAN_MS, BUILD_BUDGET_MAX_MS])
	check(not stats["times"].is_empty(), "the test level builds some chunks to time (%d)" % stats["times"].size())
	check(mean > BUILD_BUDGET_MEAN_MS, "an expensive skin still fails the mean build budget: mean %.2f ms (budget %.1f)" % [
		mean, BUILD_BUDGET_MEAN_MS])
	# The added cost is real, not noise: a single pass (no minimum-of-several) already shows it.
	var single: Dictionary = await build_all(layout, skin)
	var single_mean: float = _mean(single["times"])
	check(single_mean > BUILD_BUDGET_MEAN_MS, "a single build already shows the expense: mean %.2f ms" % single_mean)


func _mean(times: Array) -> float:
	var mean: float = 0.0
	for t: float in times:
		mean += t / times.size()
	return mean


func _max(times: Array) -> float:
	var worst: float = 0.0
	for t: float in times:
		worst = maxf(worst, t)
	return worst

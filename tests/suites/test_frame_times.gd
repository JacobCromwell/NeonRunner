extends SkinSuite
## Task PERF1's frame-time regression check (the owner's "lag spikes are more common", October 2,
## 2026): plays a few representative campaign levels as the game does, through the App with a scripted
## runner (tools/measure/frame_times.gd), each pass in a fresh Godot process so a pass pays what a
## session starting at that level pays (a type's first spawn, a first build), and checks the 99th
## percentile and the worst frame's CPU time against PerformanceTuning's test budgets
## (data/tuning/performance.tres): City 3 (the first cyborgs, window cyborgs and a hover truck),
## Marketplace 2 (the heaviest chunks, the citizens, a Barnacle Turret) and Golden 2 (the most kinds of
## enemy). A future task that makes the game slower fails here.
##
## Robust on a busy machine the way the skin suites' chunk budgets are (SkinSuite.load_factor,
## T-BUDGET2): each pass also times a reference build (REFERENCE_LANES-lane grey-box chunks, one every
## REFERENCE_EVERY frames, far off to one side, its time left out of the frames), so the budgets widen by
## how much slower the machine is right now, never below their own values; and each frame keeps its
## faster time of PASSES passes, since a moment another process takes the CPU shows in one pass only.
##
## FIX3: the reference reads the machine's *typical* load, so its passes are pooled, never folded to
## their minimum. A real chunk build happens 2400 times in 40 s; the reference, far cheaper, only
## REFERENCE_EVERY/60 times a second (~40 times in 40 s). Folding two such sparse passes to their
## per-sample minimum (as the level's own frames safely are, with 2400 samples to spare) needs *both*
## passes to be slow at the same one-in-forty moment before it counts, which a bursty, sustained load
## clears far more rarely than it clears the level frames' tail (p99 only needs 1% of 2400 frames
## caught slow in both passes at once, a much lower bar than the mean of 40 needs); measured on a
## machine kept busy by other agents' test runs, folding read load factor 1.00x while the level's own
## p99 and worst frame were plainly slower. Pooling both passes' reference samples (so the mean is
## their plain, combined average, not each-index's smaller half) fixes that without touching the
## level frames' own fold-to-minimum, which has 2400 samples to find a slow pair in and reads the
## budgeted statistics (p99, worst) rather than a mean, so it stays a fair reading of the real cost.

const RUNS: Array[String] = ["level:city/3", "level:marketplace/2", "level:golden/2"]
## Seconds of each level played (each one's first enemies of every kind come well within it).
const SECONDS: float = 40.0
const PASSES: int = 2
const TOOL: String = "res://tools/measure/frame_times.gd"


func run() -> void:
	var budgets: PerformanceTuning = PerformanceTuning.load_default()
	for key: String in RUNS:
		var passes: Array[Dictionary] = []
		for p: int in PASSES:
			var r: Dictionary = _pass(key, p)
			if r.is_empty():
				break
			passes.append(r)
		check(passes.size() == PASSES, "%s: every pass played (%d of %d)" % [key, passes.size(), PASSES])
		if passes.size() < PASSES:
			continue
		var totals: Array = passes[0]["totals"]
		var same: bool = true
		for r: Dictionary in passes:
			same = same and (r["totals"] as Array).size() == totals.size()
		check(same and totals.size() >= int(SECONDS * 60.0) - 2,
			"%s: the passes played the same %d frames (a seeded run decides the same every time)" % [key, totals.size()])
		var ms := PackedFloat32Array()
		var reference: Array = []
		for i: int in totals.size():
			var best: float = INF
			for r: Dictionary in passes:
				best = minf(best, float((r["totals"] as Array)[i]) / 1000.0)
			ms.append(best)
		# Pooled, not folded to a minimum: see the FIX3 note above the suite's doc comment.
		for r: Dictionary in passes:
			reference.append_array(r["reference_times"])
		var s: Dictionary = FrameMonitor.summarize(ms)
		var p99_factor: float = load_factor(reference, MEAN_SAFETY_MARGIN, MEAN_FACTOR_CAP)
		var worst_factor: float = load_factor(reference, MAX_SAFETY_MARGIN, MAX_FACTOR_CAP)
		var p99_budget: float = budgets.test_p99_ms * p99_factor
		var worst_budget: float = budgets.test_worst_ms * worst_factor
		var worst_frame: int = ms.find(float(s["worst"]))
		var worst_tags: String = " ".join(PackedStringArray((passes[0]["tags"] as Array)[worst_frame])) if worst_frame >= 0 else ""
		print("  %s: %d frames, median %.2f, p99 %.2f, worst %.2f ms (%s); reference %.2f ms, load factor %.2fx/%.2fx" % [
			key, totals.size(), float(s["median"]), float(s["p99"]), float(s["worst"]), worst_tags, mean_ms(reference),
			p99_factor, worst_factor])
		check(float(s["p99"]) < p99_budget, "%s: the 99th percentile frame %.2f ms (budget %.1f at load factor %.2fx)" % [
			key, float(s["p99"]), p99_budget, p99_factor])
		check(float(s["worst"]) < worst_budget, "%s: the worst frame %.2f ms, %s (budget %.1f at load factor %.2fx)" % [
			key, float(s["worst"]), worst_tags, worst_budget, worst_factor])


## One pass of `key` in a fresh Godot process (the tool's --child mode): its frames' times and tags and
## the reference build's times, or {} if it measured nothing.
func _pass(key: String, index: int) -> Dictionary:
	var file: String = OS.get_user_data_dir().path_join("frame_times_%s_%d.json" % [key.replace(":", "_").replace("/", "_"), index])
	var args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--fixed-fps", "60",
		"-s", TOOL, "--", "--child=" + key, "--child-out=" + file, "--lanes=5", "--loadout=full",
		"--seconds=%f" % SECONDS, "--reference"])
	var output: Array = []
	OS.execute(OS.get_executable_path(), args, output, true)
	if not FileAccess.file_exists(file):
		failures.append("%s: pass %d wrote nothing:\n%s" % [key, index, "\n".join(output).right(1500)])
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(file))
	DirAccess.remove_absolute(file)
	if not parsed is Array or (parsed as Array).is_empty() or not (parsed[0] as Dictionary).has("reference_times"):
		failures.append("%s: pass %d measured nothing:\n%s" % [key, index, "\n".join(output).right(1500)])
		return {}
	return parsed[0]

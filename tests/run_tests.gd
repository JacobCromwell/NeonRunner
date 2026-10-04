extends SceneTree
## Headless test runner. From the project folder:
##   godot --headless --fixed-fps 60 -s res://tests/run_tests.gd [-- --suite=movement]
## Runs every tests/suites/test_*.gd (a TestSuite) in name order; --suite=<text> runs only the
## suites whose file name contains <text>; --files=a.gd,b.gd (tools/godot.sh test --jobs, below)
## runs only those exact files, in the order given, for one of --jobs's N processes. Exits with code
## 0 on success and 1 on any failure.
##
## T-SPEED: --no-layout-cache switches off LayoutCache (tests/helpers/layout_cache.gd), the test-only
## cache of built level layouts shared by every suite in the run, for a suite that must prove its
## checks still pass without it. After a run that covers every suite (no --suite or --files), each
## suite's seconds are saved to SUITE_TIMES_PATH so `tools/godot.sh test --jobs=N` can balance the
## next run's N processes by how long each suite actually took last time.

const SUITES_DIR: String = "res://tests/suites"
## Where each suite's last measured seconds are kept (git-ignored: a local, disposable timing hint),
## read and refreshed by whichever process(es) just ran it. tools/godot.sh test --jobs=N reads it to
## balance the suites across N processes; missing or stale entries just fall back to an equal split.
const SUITE_TIMES_PATH: String = "res://tests/.suite_times.json"
## A run that takes longer than this (real time) is stuck, e.g. a suite awaiting something that
## never comes or a script error that stopped the runner: it fails instead of hanging. Timers
## can't measure this: --fixed-fps runs game time far faster than real time. A full run (78 suites,
## about 6.4 million checks) takes about 27 minutes of CPU, 13 minutes of wall time on 3 jobs, on
## the owner's machine with a native Godot, and has run far longer under load from other agents,
## so the limit leaves room above that. `tools/godot.sh test --gate` (tests/suite_map.json,
## tools/test_plan.py) runs the fast suites plus the ones for the changed files in under a minute.
const WATCHDOG_SECONDS: int = 2400

var _deadline_msec: int = 0


func _initialize() -> void:
	_deadline_msec = Time.get_ticks_msec() + WATCHDOG_SECONDS * 1000
	_run.call_deferred()


func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() > _deadline_msec:
		print("TEST RUN STUCK: no result after %d s of real time (see the errors above)" % WATCHDOG_SECONDS)
		quit(1)
	return false


func _run() -> void:
	var started: int = Time.get_ticks_msec()
	var only: String = ""
	var only_files: PackedStringArray = []
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--suite="):
			only = arg.get_slice("=", 1)
		elif arg.begins_with("--files="):
			only_files = arg.get_slice("=", 1).split(",", false)
		elif arg == "--no-layout-cache":
			LayoutCache.enabled = false
	var tuning := load(TestSuite.TUNING_PATH) as MovementTuning
	# Never touch the player's real save: suites get a fresh profile and saving goes to a test file.
	var app: Node = root.get_node_or_null(^"App")
	if app != null:
		app.set(&"autosave", false)
		app.set(&"save_path", "user://test_profile.json")
		app.set(&"profile", Profile.new())
	var failures: PackedStringArray = []
	var checks: int = 0
	var files: PackedStringArray = DirAccess.get_files_at(SUITES_DIR)
	files.sort()
	if not only_files.is_empty():
		files = only_files
	var ran: int = 0
	var suite_seconds: Dictionary = {}
	for file: String in files:
		if not file.begins_with("test_") or not file.ends_with(".gd"):
			continue
		if only != "" and not file.contains(only):
			continue
		var script := load(SUITES_DIR.path_join(file)) as GDScript
		if script == null or not script.can_instantiate():
			failures.append("%s: could not load the suite (a parse error?)" % file)
			continue
		var suite := script.new() as TestSuite
		if suite == null:
			failures.append("%s: is not a TestSuite" % file)
			continue
		suite.tree = self
		suite.tuning = tuning
		var suite_started: int = Time.get_ticks_msec()
		var before: Array[Node] = root.get_children()
		await suite.run()
		# Whatever a suite leaves in the tree (e.g. after a failed check) must not leak into the next
		# suite's physics space.
		var leaked: int = 0
		for child: Node in root.get_children():
			if not before.has(child):
				child.queue_free()
				leaked += 1
		if leaked > 0:
			suite.failures.append("left %d node(s) in the tree" % leaked)
			await process_frame
		paused = false
		ran += 1
		checks += suite.checks
		var suite_seconds_elapsed: float = (Time.get_ticks_msec() - suite_started) / 1000.0
		suite_seconds[file] = suite_seconds_elapsed
		for f: String in suite.failures:
			failures.append("%s: %s" % [file.get_basename(), f])
		print("%-28s %6d checks  %5.1f s  %s" % [file.get_basename(), suite.checks,
			suite_seconds_elapsed, "ok" if suite.failures.is_empty() else "%d FAILED" % suite.failures.size()])
	print("")
	if not suite_seconds.is_empty():
		_save_suite_times(suite_seconds)
	if ran == 0 and failures.is_empty():
		print("No test suites matched '%s'." % only)
		quit(1)
	elif failures.is_empty():
		print("ALL TESTS PASSED (%d suites, %d checks, %.1f s)" % [ran, checks, (Time.get_ticks_msec() - started) / 1000.0])
		quit(0)
	else:
		for f: String in failures:
			print("FAIL: " + f)
		print("%d of %d checks FAILED" % [failures.size(), checks])
		quit(1)


## Merges `suite_seconds` (file name -> seconds just measured) into SUITE_TIMES_PATH, so the next
## `tools/godot.sh test --jobs=N` balances by the freshest timing seen for each suite. Several
## `--jobs` processes may call this at once (each covering a different subset of suites); a lost
## update from that is harmless, since this file is only ever a balancing hint, never read by a check.
func _save_suite_times(suite_seconds: Dictionary) -> void:
	var all: Dictionary = {}
	var existing := FileAccess.open(SUITE_TIMES_PATH, FileAccess.READ)
	if existing != null:
		var parsed: Variant = JSON.parse_string(existing.get_as_text())
		existing.close()
		if parsed is Dictionary:
			all = parsed
	for file: String in suite_seconds:
		all[file] = suite_seconds[file]
	var out := FileAccess.open(SUITE_TIMES_PATH, FileAccess.WRITE)
	if out != null:
		out.store_string(JSON.stringify(all, "\t"))
		out.close()

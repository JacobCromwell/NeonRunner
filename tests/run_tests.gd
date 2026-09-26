extends SceneTree
## Headless test runner. From the project folder:
##   godot --headless --fixed-fps 60 -s res://tests/run_tests.gd [-- --suite=movement]
## Runs every tests/suites/test_*.gd (a TestSuite) in name order; --suite=<text> runs only the
## suites whose file name contains <text>. Exits with code 0 on success and 1 on any failure.

const SUITES_DIR: String = "res://tests/suites"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var started: int = Time.get_ticks_msec()
	var only: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--suite="):
			only = arg.get_slice("=", 1)
	var tuning := load(TestSuite.TUNING_PATH) as MovementTuning
	var failures: PackedStringArray = []
	var checks: int = 0
	var files: PackedStringArray = DirAccess.get_files_at(SUITES_DIR)
	files.sort()
	var ran: int = 0
	for file: String in files:
		if not file.begins_with("test_") or not file.ends_with(".gd"):
			continue
		if only != "" and not file.contains(only):
			continue
		var script := load(SUITES_DIR.path_join(file)) as GDScript
		if script == null:
			failures.append("%s: could not load the suite" % file)
			continue
		var suite := script.new() as TestSuite
		suite.tree = self
		suite.tuning = tuning
		var suite_started: int = Time.get_ticks_msec()
		await suite.run()
		ran += 1
		checks += suite.checks
		for f: String in suite.failures:
			failures.append("%s: %s" % [file.get_basename(), f])
		print("%-28s %6d checks  %5.1f s  %s" % [file.get_basename(), suite.checks,
			(Time.get_ticks_msec() - suite_started) / 1000.0, "ok" if suite.failures.is_empty() else "%d FAILED" % suite.failures.size()])
	print("")
	if ran == 0:
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

extends SceneTree
## Headless test runner. From the project folder:
##   godot --headless --fixed-fps 60 -s res://tests/run_tests.gd [-- --suite=movement]
## Runs every tests/suites/test_*.gd (a TestSuite) in name order; --suite=<text> runs only the
## suites whose file name contains <text>. Exits with code 0 on success and 1 on any failure.

const SUITES_DIR: String = "res://tests/suites"
## A run that takes longer than this (real time) is stuck, e.g. a suite awaiting something that
## never comes or a script error that stopped the runner: it fails instead of hanging. Timers
## can't measure this: --fixed-fps runs game time far faster than real time. A full run takes about
## 400 s on a quiet machine and nearer 600 s when several runs share its CPUs, so the limit leaves room.
const WATCHDOG_SECONDS: int = 1200

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
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--suite="):
			only = arg.get_slice("=", 1)
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
	var ran: int = 0
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
		for f: String in suite.failures:
			failures.append("%s: %s" % [file.get_basename(), f])
		print("%-28s %6d checks  %5.1f s  %s" % [file.get_basename(), suite.checks,
			(Time.get_ticks_msec() - suite_started) / 1000.0, "ok" if suite.failures.is_empty() else "%d FAILED" % suite.failures.size()])
	print("")
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

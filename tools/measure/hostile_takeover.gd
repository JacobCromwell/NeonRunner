extends SceneTree
## Measures Hostile Takeover's fight (GDD §10; task E5b) over every setup the test suite only samples:
## through quick play itself (App.start_boss_quick, as the fight suite's quick play test does), a runner who
## plays by what it shows (HostileTakeoverBot) at each lane count and run speed dies in the last phase once
## the war engine has docked, then plays quick play's retry (the fight starts over) to the win, its defeat
## played out. From the project folder (with XDG_DATA_HOME set as for the tests):
##   godot --headless --fixed-fps 60 -s res://tools/measure/hostile_takeover.gd -- [options]
## Options:
##   --lanes=3,5,6        lane counts (default 3,5,6)
##   --speeds=18,23.4     run speeds in m/s (default: quick play's 18 and the Corporate zone's 23.4)
##   --attempts=N         attempts at each setup (default 2): all but the last die, quick play retrying after
##                        each; the last plays the whole fight
##   --die-in=N           the phase those die in (default 3, once the war engine has docked; 1 or 2: as that
##                        phase begins)
##   --misses=N           couplings the bot lets go by in phase 1, each attempt (default 0)
##   --bay-misses=N       drop bays it lets go by in phase 2, each attempt (default 0)
##   --pass-misses=N      passes it lets go by in phase 3, each attempt (default 0)
##   --clamps-per-pass=N  the most clamps it goes for in a pass (default 3)
##   --reaction=S         the bot's reaction time in seconds (default 0.35)
## What it prints, for each setup and attempt: whether the runner won (the defeat played out: the gunship
## exploded, the locomotive crashed) or how it died, the fight's seconds at each stomp, the strafes, the drops
## (and the flatcars refused one), the rides (missed, stomped), the passes (missed, the clamps torn in each),
## phase 1's guards retired at the phase change, the Tithe Collectors that came and those the cap left out,
## and the run's credits; for each setup, whether every attempt played the same (the same plan and course,
## as the suite's check, up to where the earlier attempt died). A line at the end sums it up. The default run
## takes about a minute.

const BOSS_PATH: String = "res://data/bosses/corporate_boss.tres"
## LevelRun's script, loaded once the autoloads are up (it names the App autoload, which a tool's script
## can't while it compiles).
const LEVEL_RUN: String = "res://scripts/run/level_run.gd"
## Events that make up the fight's plan and course (the fight suite's COURSE).
const COURSE: Array[StringName] = [&"pattern", &"phase", &"couplings_from", &"carriage_planned", &"coupling_lit",
	&"coupling_missed", &"coupling_stomped", &"weak_point", &"tithe_trail", &"stand_down", &"contract", &"drop_planned",
	&"drop_marked", &"saw_released", &"saw_landed", &"ride_planned", &"ride_placed", &"ride_begins", &"ride_boarded",
	&"ride_landed", &"ride_missed", &"bay_stomped", &"strafe_warned", &"strafe_rake", &"strafe_done", &"docking",
	&"clamps_locked", &"merger_complete", &"pass_planned", &"pass_placed", &"pass_begins", &"pass_boarded", &"pass_landed",
	&"pass_missed", &"clamp_stomped", &"defeated", &"gunship_exploded", &"locomotive_crashed"]

var _lanes: Array[int] = [3, 5, 6]
var _speeds: Array[float] = [18.0, 23.4]
var _attempts: int = 2
var _die_in: int = 3
var _misses: int = 0
var _bay_misses: int = 0
var _pass_misses: int = 0
var _clamps_per_pass: int = 3
var _reaction: float = 0.35


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var v: String = arg.get_slice("=", 1)
		if arg.begins_with("--lanes="):
			_lanes.clear()
			for s: String in v.split(",", false):
				_lanes.append(int(s))
		elif arg.begins_with("--speeds="):
			_speeds.clear()
			for s: String in v.split(",", false):
				_speeds.append(float(s))
		elif arg.begins_with("--attempts="):
			_attempts = maxi(int(v), 1)
		elif arg.begins_with("--die-in="):
			_die_in = clampi(int(v), 1, 3)
		elif arg.begins_with("--misses="):
			_misses = maxi(int(v), 0)
		elif arg.begins_with("--bay-misses="):
			_bay_misses = maxi(int(v), 0)
		elif arg.begins_with("--pass-misses="):
			_pass_misses = maxi(int(v), 0)
		elif arg.begins_with("--clamps-per-pass="):
			_clamps_per_pass = clampi(int(v), 1, 3)
		elif arg.begins_with("--reaction="):
			_reaction = maxf(float(v), 0.0)
	var app: Node = root.get_node_or_null(^"App")
	if app == null:
		push_error("hostile_takeover: no App autoload")
		quit(1)
		return
	app.set(&"autosave", false)
	app.set(&"save_path", "user://measure_profile.json")
	var slot := load(BOSS_PATH) as BossDef
	var def: BossDef = slot if slot != null and slot.is_built() else null
	if def == null:
		push_error("hostile_takeover: the fight doesn't load")
		quit(1)
		return
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var rules: GameRules = app.get(&"rules")
	var lanes_pc: int = rules.lanes_pc
	print("Hostile Takeover through quick play: %d attempt(s) a setup (the earlier ones dying in phase %d), the bot reacting %.2f s late%s%s%s%s" % [
		_attempts, _die_in, _reaction, ", letting %d coupling(s) go by" % _misses if _misses > 0 else "",
		", letting %d drop bay(s) go by" % _bay_misses if _bay_misses > 0 else "",
		", letting %d pass(es) go by" % _pass_misses if _pass_misses > 0 else "",
		", at most %d clamp(s) a pass" % _clamps_per_pass if _clamps_per_pass < 3 else ""])
	var won: int = 0
	var to_win: int = 0
	var died_as_planned: int = 0
	var to_die: int = 0
	var same: int = 0
	for lanes: int in _lanes:
		for speed: float in _speeds:
			rules.lanes_pc = lanes
			var courses: Array[Array] = []
			for attempt: int in _attempts:
				var last: bool = attempt == _attempts - 1
				var out: Dictionary = await _attempt(app, def, lanes, speed, attempt == 0, last)
				if last:
					to_win += 1
					won += 1 if out["won"] else 0
				else:
					to_die += 1
					died_as_planned += 1 if out["planned"] else 0
				courses.append(out["course"])
				print("  %d lanes, %.1f m/s, attempt %d: %s" % [lanes, speed, attempt + 1, out["line"]])
			var alike: bool = _alike(courses)
			same += 1 if alike else 0
			print("  %d lanes, %.1f m/s: every attempt %s" % [lanes, speed, "played the same" if alike else "DIFFERED"])
	rules.lanes_pc = lanes_pc
	app.call(&"show_title")
	await process_frame
	main.queue_free()
	await process_frame
	print("Won %d of %d whole fights; %d of %d earlier attempts reached phase %d alive; %d of %d setups played the same on every attempt" % [
		won, to_win, died_as_planned, to_die, _die_in, same, _lanes.size() * _speeds.size()])
	quit(0)


## One attempt at `lanes` and `speed`: the fight started (`fresh`) or retried after a death, played until
## the runner dies in phase _die_in (as planned) or, `last`, wins the whole fight and its defeat has played
## out. Returns {won, planned (reached the planned death alive), course ([t, entry] pairs), line}.
func _attempt(app: Node, def: BossDef, lanes: int, speed: float, fresh: bool, last: bool) -> Dictionary:
	if fresh:
		var quick: BossDef = def.duplicate() as BossDef
		quick.arena = def.arena.duplicate() as LevelConfig
		quick.arena.run_speed = speed
		app.call(&"start_boss_quick", quick)
		for i: int in 3:
			await physics_frame
	var run: Node = app.get(&"run")
	var boss := run.get(&"encounter") as HostileTakeover if run != null else null
	var world: RunWorld = run.get(&"world") as RunWorld if run != null else null
	if boss == null or world == null or world.geo.lane_count != lanes:
		return {"won": false, "planned": false, "course": [], "line": "quick play didn't start the fight"}
	var bot := HostileTakeoverBot.new(boss)
	bot.reaction = _reaction
	bot.misses = _misses
	bot.bay_misses = _bay_misses
	bot.pass_misses = _pass_misses
	bot.clamps_per_pass = _clamps_per_pass
	var cause: Array[String] = [""]
	world.player.died.connect(func(c: String) -> void: cause[0] = c)
	var done := func() -> bool:
		if last:
			return boss.is_defeated() and boss.victory_over()
		return boss.phase_index >= _die_in - 1 and (_die_in < 3 or boss.docked)
	for i: int in 300 * 60:
		if done.call() or not world.player.alive:
			break
		bot.step()
		await physics_frame
	var won: bool = last and boss.is_defeated() and world.player.alive
	var planned: bool = not last and done.call() and world.player.alive
	var stomps := PackedStringArray()
	var counts: Dictionary = {}
	var torn := PackedStringArray()
	var course: Array = []
	for e: Dictionary in boss.events:
		var event: StringName = e["event"]
		counts[event] = int(counts.get(event, 0)) + 1
		if event == &"weak_point":
			stomps.append("%.1f" % float(e["t"]))
		if event == &"pass_landed" or event == &"pass_missed":
			torn.append(str(int(e["torn"])))
		if event in COURSE:
			course.append([float(e["t"]), str(e)])
	if boss.is_defeated():
		# The last pass ends in the defeat (no landing logged): the clamps left before it.
		var before: int = 0
		for x: String in torn:
			before += int(x)
		torn.append(str(boss.gunship.clamps.size() - before))
	var outcome: String = "won in %.1f s (the gunship %s, the locomotive %s)" % [boss.fight_time(),
		"exploded" if int(counts.get(&"gunship_exploded", 0)) > 0 else "NOT EXPLODED",
		"crashed" if int(counts.get(&"locomotive_crashed", 0)) > 0 else "NOT CRASHED"] if won \
		else ("died as planned in phase %d" % _die_in if planned else "died (%s) in phase %d" % [cause[0], boss.phase_index + 1])
	var line: String = "%s; stomps at %s s; %d strafes, %d drops (%d refused), %d rides (%d missed, %d stomped), %d passes (%d missed; clamps torn a pass: %s); %d guards retired; %d Collectors, %d left out; %d credits" % [
		outcome, ", ".join(stomps), int(counts.get(&"strafe_warned", 0)), int(counts.get(&"saw_landed", 0)),
		int(counts.get(&"drop_refused", 0)), int(counts.get(&"ride_begins", 0)), int(counts.get(&"ride_missed", 0)),
		int(counts.get(&"bay_stomped", 0)), int(counts.get(&"pass_begins", 0)), int(counts.get(&"pass_missed", 0)),
		", ".join(torn) if not torn.is_empty() else "-", boss.guards_retired, int(counts.get(&"tithe_trail", 0)),
		boss.board.visits_skipped, world.score.credits]
	if not last and world.player.alive:
		world.player.call(&"_die", "the measure's retry")
		var pause: float = float((load(LEVEL_RUN) as GDScript).get_script_constant_map().get("QUICK_DEATH_PAUSE", 1.2))
		for i: int in int((pause + 0.4) * 60.0):
			await physics_frame
	return {"won": won, "planned": planned, "course": course, "line": line}


## True if every attempt's course matches the others up to where the shorter one ends (a second before
## its last entry: the frame it died in may log more).
func _alike(courses: Array[Array]) -> bool:
	for i: int in range(1, courses.size()):
		var a: Array = courses[i - 1]
		var b: Array = courses[i]
		var until: float = minf(float(a[-1][0]) if not a.is_empty() else 0.0, float(b[-1][0]) if not b.is_empty() else 0.0) - 1.0
		var pa: Array = a.filter(func(x: Array) -> bool: return float(x[0]) <= until)
		var pb: Array = b.filter(func(x: Array) -> bool: return float(x[0]) <= until)
		if pa != pb or pa.is_empty():
			return false
	return true

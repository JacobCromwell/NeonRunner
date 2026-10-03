extends SceneTree
## Measures Hostile Takeover's fight (GDD §10; task E5b-b) over every setup the test suite only samples:
## through quick play itself (App.start_boss_quick with the preview, as the fight suite's quick play test
## does), a runner who plays by what it shows (HostileTakeoverBot) at each lane count and run speed wins
## its phases, dies, and plays quick play's retry (the fight starts over) the same way. From the project
## folder (with XDG_DATA_HOME set as for the tests):
##   godot --headless --fixed-fps 60 -s res://tools/measure/hostile_takeover.gd -- [options]
## Options:
##   --lanes=3,5,6        lane counts (default 3,5,6)
##   --speeds=18,23.4     run speeds in m/s (default: quick play's 18 and the Corporate zone's 23.4)
##   --phases=N           phases to win in each attempt (default 2: The Board and The Contract)
##   --attempts=N         attempts at each setup, a death and quick play's retry between them (default 2)
##   --misses=N           couplings the bot lets go by in phase 1, each attempt (default 0)
##   --bay-misses=N       drop bays it lets go by in phase 2, each attempt (default 0)
##   --reaction=S         the bot's reaction time in seconds (default 0.35)
## What it prints, for each setup and attempt: whether the runner won the phases (or what killed it), when
## each phase ended (fight seconds), the strafes, the drops (and the flatcars refused one), the rides
## (missed and stomped), phase 1's guards retired at the phase change, the Tithe Collectors that came and
## those the cap left out, and the run's credits; for each setup, whether every attempt played the same
## (the same plan and course, as the suite's check). A line at the end sums it up. The default run takes
## a few minutes.

const BOSS_PATH: String = "res://data/bosses/corporate_boss.tres"
## LevelRun's script, loaded once the autoloads are up (it names the App autoload, which a tool's script
## can't while it compiles).
const LEVEL_RUN: String = "res://scripts/run/level_run.gd"
## Events that make up the fight's plan and course (the fight suite's COURSE).
const COURSE: Array[StringName] = [&"pattern", &"phase", &"couplings_from", &"carriage_planned", &"coupling_lit",
	&"coupling_missed", &"coupling_stomped", &"weak_point", &"tithe_trail", &"stand_down", &"contract", &"drop_planned",
	&"drop_marked", &"saw_released", &"saw_landed", &"ride_planned", &"ride_placed", &"ride_begins", &"ride_boarded",
	&"ride_landed", &"ride_missed", &"bay_stomped", &"strafe_warned", &"strafe_rake", &"strafe_done"]

var _lanes: Array[int] = [3, 5, 6]
var _speeds: Array[float] = [18.0, 23.4]
var _phases: int = 2
var _attempts: int = 2
var _misses: int = 0
var _bay_misses: int = 0
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
		elif arg.begins_with("--phases="):
			_phases = clampi(int(v), 1, 3)
		elif arg.begins_with("--attempts="):
			_attempts = maxi(int(v), 1)
		elif arg.begins_with("--misses="):
			_misses = maxi(int(v), 0)
		elif arg.begins_with("--bay-misses="):
			_bay_misses = maxi(int(v), 0)
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
	var def: BossDef = slot.preview() if slot != null else null
	if def == null:
		push_error("hostile_takeover: the fight doesn't load as a preview")
		quit(1)
		return
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var rules: GameRules = app.get(&"rules")
	var lanes_pc: int = rules.lanes_pc
	print("Hostile Takeover through quick play: %d phase(s) an attempt, %d attempt(s), the bot reacting %.2f s late%s%s" % [
		_phases, _attempts, _reaction, ", letting %d coupling(s) go by" % _misses if _misses > 0 else "",
		", letting %d drop bay(s) go by" % _bay_misses if _bay_misses > 0 else ""])
	var won: int = 0
	var played: int = 0
	var same: int = 0
	for lanes: int in _lanes:
		for speed: float in _speeds:
			rules.lanes_pc = lanes
			var courses: Array[String] = []
			for attempt: int in _attempts:
				var out: Dictionary = await _attempt(app, def, lanes, speed, attempt == 0)
				played += 1
				won += 1 if out["won"] else 0
				courses.append(out["course"])
				print("  %d lanes, %.1f m/s, attempt %d: %s" % [lanes, speed, attempt + 1, out["line"]])
			var alike: bool = courses.all(func(c: String) -> bool: return c == courses[0])
			same += 1 if alike else 0
			print("  %d lanes, %.1f m/s: every attempt %s" % [lanes, speed, "played the same" if alike else "DIFFERED"])
	rules.lanes_pc = lanes_pc
	app.call(&"show_title")
	await process_frame
	main.queue_free()
	await process_frame
	print("Won %d of %d attempts; %d of %d setups played the same on every attempt" % [won, played, same, _lanes.size() * _speeds.size()])
	quit(0)


## One attempt at `lanes` and `speed`: the fight started (`fresh`) or retried after a death, played until
## the runner has won _phases phases or died, then the runner dies (quick play then retries). Returns
## {won, course, line}.
func _attempt(app: Node, def: BossDef, lanes: int, speed: float, fresh: bool) -> Dictionary:
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
		return {"won": false, "course": "", "line": "quick play didn't start the fight"}
	var bot := HostileTakeoverBot.new(boss)
	bot.reaction = _reaction
	bot.misses = _misses
	bot.bay_misses = _bay_misses
	var cause: Array[String] = [""]
	world.player.died.connect(func(c: String) -> void: cause[0] = c)
	for i: int in 240 * 60:
		if boss.phase_index >= _phases or not world.player.alive:
			break
		bot.step()
		await physics_frame
	var won: bool = boss.phase_index >= _phases and world.player.alive
	var ends := PackedStringArray()
	var counts: Dictionary = {}
	var course := PackedStringArray()
	for e: Dictionary in boss.events:
		var event: StringName = e["event"]
		counts[event] = int(counts.get(event, 0)) + 1
		if event == &"weak_point":
			ends.append("%.1f" % float(e["t"]))
		if event in COURSE:
			course.append(str(e))
	var line: String = "%s; phases ended at %s s; %d strafes, %d drops (%d refused), %d rides (%d missed, %d stomped); %d guards retired; %d Collectors, %d left out; %d credits" % [
		"won" if won else "died (%s) in phase %d" % [cause[0], boss.phase_index + 1], ", ".join(ends),
		int(counts.get(&"strafe_warned", 0)), int(counts.get(&"saw_landed", 0)), int(counts.get(&"drop_refused", 0)),
		int(counts.get(&"ride_begins", 0)), int(counts.get(&"ride_missed", 0)), int(counts.get(&"bay_stomped", 0)),
		boss.guards_retired, int(counts.get(&"tithe_trail", 0)), boss.board.visits_skipped, world.score.credits]
	if world.player.alive:
		world.player.call(&"_die", "the measure's retry")
	var pause: float = float((load(LEVEL_RUN) as GDScript).get_script_constant_map().get("QUICK_DEATH_PAUSE", 1.2))
	for i: int in int((pause + 0.4) * 60.0):
		await physics_frame
	return {"won": won, "course": "\n".join(course), "line": line}

extends SceneTree
## Measures how long a run takes to build its level (task PERF2): each campaign level's first build (the
## level generator's, as a run starts one: LevelGenerator.load_for and generate), each campaign boss
## arena's plan (BossEncounter.plan_arena), and the time from pressing retry to the run starting, through
## the real main scene: the results screen's retry (App.retry, a new LevelRun) and the in-place restart
## (LevelRun.restart: quick play and the debug key). From the project folder (with XDG_DATA_HOME set as
## for the tests):
##   godot --headless -s res://tools/measure/level_builds.gd -- [options]
## Options (named apart from the game's own, which the main scene reads at boot):
##   --levels=city/1,corporate/2   campaign steps for the first-build table (default: every level)
##   --lane-counts=3,5,6           lane counts (default 3,5,6)
##   --repeat=N                    builds of each; the table shows the fastest (default 1)
##   --no-table                    skip the first-build table
##   --bosses                      also time each campaign boss arena's plan at each lane count
##   --retry=corporate/2,dead_zone/1  levels whose retries to time (default: none), each retried
##                                 --retries=N times (default 3) both ways, at --retry-lanes=N (default 5)
##   --passes=corporate/2:5,...    where one build's time goes, for each level:lanes: generate()'s first
##                                 build replayed pass by pass with a clock around each (each enemy type's
##                                 rules apart), checked against the generator's own build of it
## A first build is timed after one untimed build in the same process, so the scripts and tunings the
## generator loads once are loaded already; "builds" is how many times the generator built the level
## before every feature it can place was in it (LevelConfig.guarantee_features; LevelGenerator.attempts).
## A retry is timed from the call (App.retry or LevelRun.restart) to the next frame, when the run is built
## and its level introduction is up; "build" is the call alone. Timings depend on the machine and its
## load: compare runs made on the same machine at the same time.

const CAMPAIGN_PATH: String = "res://data/campaign/campaign.tres"
const TUNING_PATH: String = "res://data/tuning/movement.tres"
## The game's level cache (task PERF2), if this version has one (the tool also runs on older versions, for
## the times before it): LevelCache.last_reused says whether a retry reused the built level.
const LEVEL_CACHE_PATH: String = "res://scripts/run/level_cache.gd"

var _levels: PackedStringArray = []
var _lanes: Array[int] = [3, 5, 6]
var _repeat: int = 1
var _table: bool = true
var _bosses: bool = false
var _retry_levels: PackedStringArray = []
var _retries: int = 3
var _retry_lanes: int = 5
var _passes: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_parse_args()
	var campaign := load(CAMPAIGN_PATH) as Campaign
	var tuning := load(TUNING_PATH) as MovementTuning
	if _levels.is_empty():
		for s: CampaignStep in campaign.steps():
			if s.is_level() and not s.is_minigame():
				_levels.append(s.id)
	if _table:
		_first_builds(campaign, tuning)
	if _bosses:
		_arena_plans(campaign, tuning)
	for spec: String in _passes:
		var step: CampaignStep = campaign.step(spec.get_slice(":", 0))
		if step == null or not step.is_level() or step.is_minigame():
			print("%s: not a campaign level" % spec)
			continue
		_pass_times(spec, campaign.configure(step, int(spec.get_slice(":", 1))), tuning)
	if not _retry_levels.is_empty():
		await _retry_times(campaign)
	quit(0)


func _parse_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var value: String = arg.get_slice("=", 1)
		if arg.begins_with("--levels="):
			_levels = value.split(",", false)
		elif arg.begins_with("--lane-counts="):
			_lanes.clear()
			for v: String in value.split(",", false):
				_lanes.append(int(v))
		elif arg.begins_with("--repeat="):
			_repeat = maxi(int(value), 1)
		elif arg == "--no-table":
			_table = false
		elif arg == "--bosses":
			_bosses = true
		elif arg.begins_with("--retry="):
			_retry_levels = value.split(",", false)
		elif arg.begins_with("--retries="):
			_retries = maxi(int(value), 1)
		elif arg.begins_with("--retry-lanes="):
			_retry_lanes = int(value)
		elif arg.begins_with("--passes="):
			_passes = value.split(",", false)


## Every level's first build at each lane count, slowest last in a ranking.
func _first_builds(campaign: Campaign, tuning: MovementTuning) -> void:
	# One untimed build first: what the generator loads once a process (its rules' scripts, the tunings).
	_build(campaign.configure(campaign.step(_levels[0]), _lanes[0]), tuning)
	print("First builds (ms, the fastest of %d; builds: the generator's attempts for its every-feature guarantee)" % _repeat)
	var header: String = "%-14s" % "level"
	for lanes: int in _lanes:
		header += " | %2d lanes: %7s %6s" % [lanes, "ms", "builds"]
	print(header)
	var all: Array[Dictionary] = []
	var total: float = 0.0
	for id: String in _levels:
		var step: CampaignStep = campaign.step(id)
		if step == null or not step.is_level() or step.is_minigame():
			print("%s: not a campaign level" % id)
			continue
		var line: String = "%-14s" % id
		for lanes: int in _lanes:
			var best: Dictionary = {}
			for k: int in _repeat:
				var built: Dictionary = _build(campaign.configure(step, lanes), tuning)
				if best.is_empty() or float(built["ms"]) < float(best["ms"]):
					best = built
			line += " | %9s %7.0f %6d" % ["", float(best["ms"]), int(best["attempts"])]
			all.append({"id": id, "lanes": lanes, "ms": float(best["ms"]), "attempts": int(best["attempts"]),
				"enemies": int(best["enemies"])})
			total += float(best["ms"])
		print(line)
	all.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["ms"]) > float(b["ms"]))
	print("Total %.1f s over %d builds. Slowest:" % [total / 1000.0, all.size()])
	for i: int in mini(8, all.size()):
		var row: Dictionary = all[i]
		print("  %-14s %d lanes  %6.0f ms  %d builds (%.0f ms each)  %d enemies" % [row["id"], row["lanes"], row["ms"],
			row["attempts"], float(row["ms"]) / maxf(float(row["attempts"]), 1.0), row["enemies"]])


## One level build, as LevelRun makes it: the patterns read, then the generator.
func _build(config: LevelConfig, base: MovementTuning) -> Dictionary:
	var t: MovementTuning = config.movement_for(base)
	var started: int = Time.get_ticks_usec()
	var gen := LevelGenerator.new()
	var layout: LevelLayout = gen.generate(config, t, LevelGenerator.load_for(config))
	var ms: float = (Time.get_ticks_usec() - started) / 1000.0
	return {"ms": ms, "attempts": gen.attempts, "enemies": layout.enemies.size()}


## Where one build's time goes (`spec` is "level:lanes"): generate()'s first build of `config` (no forced picks
## yet) replayed in LevelGenerator._build's order with a clock around each pass and each enemy type's rules,
## then checked against the generator's own first build: a replay that no longer builds the same layout
## says so (update it to match _build).
func _pass_times(spec: String, config: LevelConfig, base: MovementTuning) -> void:
	var patterns: Array = LevelGenerator.load_for(config)
	var whole := LevelGenerator.new()
	var whole_start: int = Time.get_ticks_usec()
	whole.generate(config, base, patterns)
	var whole_ms: float = (Time.get_ticks_usec() - whole_start) / 1000.0
	# generate()'s setup (for_layout makes the same), then _build's, as it is.
	var gen: LevelGenerator = LevelGenerator.for_layout(config, base, null)
	gen.attempts = 1
	var times: Array[Array] = []
	var clock: Array[int] = [Time.get_ticks_usec()]
	var lap := func(what: String) -> void:
		times.append([what, Time.get_ticks_usec() - clock[0]])
		clock[0] = Time.get_ticks_usec()
	gen._rng.seed = config.level_seed
	gen._ceiling_rng.seed = hash([config.level_seed, "narrow_ceilings"])
	gen.layout = LevelLayout.new()
	gen.layout.lane_count = config.lane_count
	gen._clear_stretches.clear()
	gen._enemy_count = 0
	gen.warnings.clear()
	gen.picks.clear()
	gen.fills.clear()
	gen.uncredited.clear()
	gen.wide_gap_result = {}
	gen.charge_path_result = {}
	gen.show_window_result = {}
	gen.danger_density_plan = null
	gen._intro_burst = -1
	var accel: float = gen.tuning.speed_gain_per_minute / 60.0
	gen.layout.length = gen.speed * config.duration_seconds + 0.5 * accel * config.duration_seconds * config.duration_seconds
	gen._due = gen._due_picks({})
	gen._clear_stretches.append(Vector2(20.0, config.start_clear_distance))
	var cursor: float = config.start_clear_distance
	while cursor < gen.layout.length - config.end_clear_distance:
		var difficulty: float = gen.difficulty_at(cursor / gen.layout.length)
		var pattern: Dictionary = gen._pick_due(patterns, difficulty, cursor)
		var due: bool = not pattern.is_empty()
		if pattern.is_empty():
			pattern = gen._pick_pattern(patterns, difficulty, cursor)
		if pattern.is_empty():
			break
		var pattern_start_counts: Dictionary = gen._counts()
		var used: float = gen._place_pattern(pattern, cursor)
		if cursor + used > gen.layout.length - config.end_clear_distance:
			gen._rollback(pattern_start_counts)
			break
		if gen.layout.hulls.size() > int(pattern_start_counts["hulls"]):
			gen._secure_ceilings(pattern, pattern_start_counts)
		gen._settle_due(pattern, cursor)
		gen.picks.append({"id": String(pattern.get("id", "?")), "requires": pattern.get("requires", []), "at": cursor,
			"used": used, "due": due})
		var end: float = cursor + used
		var clear_end: float = end + gen._spacing_seconds(end, difficulty) * gen.speed
		if config.paced_in_bursts() and gen.quiet_at(end):
			clear_end = maxf(minf(clear_end, gen.stretch_end(end)), end + config.burst_spacing_seconds * gen.speed)
		gen._clear_stretches.append(Vector2(end, minf(clear_end, gen.layout.length - config.end_clear_distance)))
		cursor = clear_end
	lap.call("patterns")
	# _apply_enemy_rules, a type at a time.
	var pending: Array[Array] = []
	for feature: String in config.features:
		var path: String = LevelGenerator.RULES_DIR.path_join("%s_rules.gd" % feature)
		var script: GDScript = load(path) as GDScript if ResourceLoader.exists(path) else null
		if script != null and script.has_method("apply"):
			pending.append([feature, script])
	while not pending.is_empty():
		var next: int = 0
		for i: int in pending.size():
			if not LevelGenerator._waits_for_others(pending, i):
				next = i
				break
		var item: Array = pending.pop_at(next)
		(item[1] as GDScript).call("apply", gen)
		lap.call("rules: " + String(item[0]))
	gen.danger_density_result = LevelGenerator.DangerDensity.apply_enemies(gen, patterns)
	lap.call("danger density, enemies")
	gen.charge_path_result = ChargePathPlacement.place(gen)
	lap.call("charge paths")
	gen.wide_gap_result = WideGapPlacement.place(gen)
	lap.call("wider gaps")
	gen._fill_empty_stretches(patterns)
	lap.call("fill")
	WideGapPlacement.widen_deferred(gen)
	lap.call("wider gaps, deferred")
	gen.danger_density_result = LevelGenerator.DangerDensity.apply_obstacles(gen, patterns, gen.danger_density_result)
	lap.call("danger density, obstacles")
	gen._place_doodads(patterns)
	gen.danger_density_plan = null
	lap.call("doodads")
	gen._place_wall_fences()
	lap.call("wall fences")
	WallGapPlacement.place(gen)
	lap.call("wall gaps")
	gen.gap_density_result = GapDensity.apply(gen)
	lap.call("gap density")
	gen._place_credits()
	gen.layout.enemies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["at"] < b["at"])
	lap.call("credits")
	var own := LevelGenerator.for_layout(config, base, null)
	own.attempts = 1
	own._build(patterns, {})
	var same: bool = var_to_str(own.layout.to_dict()) == var_to_str(gen.layout.to_dict())
	var total: int = 0
	for t: Array in times:
		total += int(t[1])
	print("%s: generate() %.0f ms in %d builds; its first build pass by pass (%.0f ms)%s" % [spec, whole_ms,
		whole.attempts, total / 1000.0, "" if same else
		" -- THE REPLAY NO LONGER BUILDS THE GENERATOR'S LAYOUT: update _pass_times to match LevelGenerator._build"])
	times.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) > int(b[1]))
	for t: Array in times:
		if int(t[1]) >= 1000 or t == times[0]:
			print("  %-28s %6.0f ms  %3.0f%%" % [t[0], int(t[1]) / 1000.0, 100.0 * int(t[1]) / maxf(total, 1.0)])


## Each campaign boss arena's plan (its laps from the generator, shaped by the boss's script), as LevelRun
## makes it after BossEncounter.create (not timed: a run instantiates its boss either way).
func _arena_plans(campaign: Campaign, tuning: MovementTuning) -> void:
	print("Boss arena plans (ms, the fastest of %d)" % _repeat)
	for s: CampaignStep in campaign.steps():
		if s.kind != CampaignStep.Kind.BOSS or s.boss == null:
			continue
		var line: String = "%-22s" % s.id
		if not s.boss.is_built():
			print(line + " | not built yet")
			continue
		for lanes: int in _lanes:
			var best: float = INF
			for k: int in _repeat:
				var ctx := RunContext.new()
				ctx.mode = RunContext.Mode.CAMPAIGN
				ctx.step = s
				ctx.boss = s.boss
				ctx.config = campaign.configure_boss(s, lanes)
				ctx.tuning = ctx.config.movement_for(tuning)
				var encounter: BossEncounter = BossEncounter.create(s.boss)
				if encounter == null:
					break
				var started: int = Time.get_ticks_usec()
				var arena: BossArena = encounter.plan_arena(ctx)
				best = minf(best, (Time.get_ticks_usec() - started) / 1000.0)
				if arena == null:
					break
				encounter.free()
			line += " | %d lanes %7.0f" % [lanes, best]
		print(line)


## The time from pressing retry to the run starting, both ways, on the real main scene.
func _retry_times(campaign: Campaign) -> void:
	var main_scene := load(str(ProjectSettings.get_setting("application/run/main_scene"))) as PackedScene
	root.add_child(main_scene.instantiate())
	await process_frame
	var app: Node = root.get_node("App")
	app.set(&"profile", Profile.new())
	app.set(&"_review_args", PackedStringArray(["--lanes=%d" % _retry_lanes]))
	var cache: GDScript = load(LEVEL_CACHE_PATH) as GDScript if ResourceLoader.exists(LEVEL_CACHE_PATH) else null
	print("Retries at %d lanes (ms: the call / to the next frame%s)" % [_retry_lanes,
		", and whether the built level was reused" if cache != null else ""])
	for id: String in _retry_levels:
		var step: CampaignStep = campaign.step(id)
		if step == null or not step.is_level() or step.is_minigame():
			print("%s: not a campaign level" % id)
			continue
		var started: int = Time.get_ticks_usec()
		app.call(&"start_level", step)
		var first_ms: float = (Time.get_ticks_usec() - started) / 1000.0
		await process_frame
		app.call(&"begin_run")
		for i: int in 5:
			await physics_frame
		print("%s: first start %.0f ms" % [id, first_ms])
		for way: String in ["App.retry", "LevelRun.restart"]:
			var calls: PackedStringArray = []
			for k: int in _retries:
				var run: Node = app.get(&"run")
				var t0: int = Time.get_ticks_usec()
				if way == "App.retry":
					app.call(&"retry", run.get(&"context"))
				else:
					run.call(&"restart")
				var t1: int = Time.get_ticks_usec()
				await process_frame
				var t2: int = Time.get_ticks_usec()
				var reused: String = ""
				if cache != null:
					reused = " reused" if bool(cache.get(&"last_reused")) else " built"
				calls.append("%.0f/%.0f%s" % [(t1 - t0) / 1000.0, (t2 - t0) / 1000.0, reused])
				# Start the attempt, as PLAY does, and let it run a moment.
				app.call(&"begin_run")
				for i: int in 5:
					await physics_frame
			print("  %-16s %s" % [way, "   ".join(calls)])
	app.call(&"show_title")
	await process_frame

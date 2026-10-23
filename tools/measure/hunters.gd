extends SceneTree
## Measures the Hunters' placement (task S2; scripts/enemies/hunter_rules.gd) over the campaign's levels that have them, and
## the weekly challenge's weeks of their zone: for each build, how many arrive of the most a level takes, where (as a share
## of the level), which arrive not calm (no calm arrival for their bait), their introduction's distance past the feature's
## start (test_campaign's introduction reach, metres at the level's pace), how many falling gantryways each has in its
## chase, how many of the level's gantryways can be baits, and what HunterRules.problems() and the re-checks of the rules
## that run before it (gantryways, teleporters, Octodog jars) find (nothing, on every build the suites check). From the
## project folder:
##   godot --headless -s res://tools/measure/hunters.gd -- [--levels=ice_lab/3] [--lanes=3,5,6] [--seeds=N] [--weekly]
## --seeds=N builds each level on its own seed and N others (9001, 9002, ...; default 3). --weekly also builds the weekly
## challenge's weeks whose zone lists the feature (data/weekly/weekly_seeds.json). --why prints why a gantryway is no bait
## or a bait got no Hunter (HunterRules.debug). --gantryways=N and --start=F try a level's gantryway count and the Hunter's
## feature start (a share of the level) other than its own.

const HunterRules = preload("res://scripts/enemies/hunter_rules.gd")
const GantrywayRules = preload("res://scripts/enemies/gantryway_rules.gd")
const TeleporterRules = preload("res://scripts/enemies/teleporter_rules.gd")
const OctodogJarRules = preload("res://scripts/enemies/octodog_jar_rules.gd")
## test_campaign's INTRODUCTION_REACH (metres at MovementTuning.REFERENCE_SPEED, stretched by the level's pace).
const INTRODUCTION_REACH: float = 210.0

var _levels: PackedStringArray = []
var _lanes: Array[int] = [3, 5, 6]
var _seeds: int = 3
var _weekly: bool = false
## Overrides for trying other numbers (-1: the level's own): its gantryway count, the Hunter's feature start.
var _gantryways: int = -1
var _start: float = -1.0
var _tuning: MovementTuning
var _stats := {"builds": 0, "placed": 0, "not_calm": 0, "none": 0, "late": 0, "problems": 0}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--levels="):
			_levels = arg.get_slice("=", 1).split(",", false)
		elif arg.begins_with("--lanes="):
			_lanes.clear()
			for s: String in arg.get_slice("=", 1).split(",", false):
				_lanes.append(int(s))
		elif arg.begins_with("--seeds="):
			_seeds = int(arg.get_slice("=", 1))
		elif arg == "--weekly":
			_weekly = true
		elif arg == "--why":
			HunterRules.debug = true
		elif arg.begins_with("--gantryways="):
			_gantryways = int(arg.get_slice("=", 1))
		elif arg.begins_with("--start="):
			_start = float(arg.get_slice("=", 1))
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	_tuning = load("res://data/tuning/movement.tres") as MovementTuning
	for s: CampaignStep in campaign.steps():
		if not s.is_level() or s.is_minigame() or not s.level.has_feature(HunterRules.TYPE):
			continue
		if not _levels.is_empty() and not _levels.has(s.id):
			continue
		for lanes: int in _lanes:
			for k: int in _seeds + 1:
				var config: LevelConfig = campaign.configure(s, lanes)
				if k > 0:
					config.level_seed = 9000 + k
				_measure(config, "%s lanes=%d seed=%d" % [s.id, lanes, config.level_seed])
	if _weekly:
		var def := load(WeeklyChallenge.PATH) as WeeklyChallenge
		var entries: Array[Dictionary] = def.entries()
		for i: int in entries.size():
			var w: WeeklyWeek = def.week(i)
			var config: LevelConfig = def.build_config(campaign, w)
			if config != null and config.has_feature(HunterRules.TYPE):
				_measure(config, "week %d (%s, seed %d)" % [i, entries[i]["zone"], entries[i]["seed"]])
	print("%d builds: %d Hunters (%d not calm), %d builds without one, %d introductions past the reach, %d problems" % [
		_stats["builds"], _stats["placed"], _stats["not_calm"], _stats["none"], _stats["late"], _stats["problems"]])
	quit()


func _measure(config: LevelConfig, tag: String) -> void:
	if _gantryways >= 0:
		config.gantryways = _gantryways
	if _start >= 0.0 and config.feature_starts.has(HunterRules.TYPE):
		config.feature_starts = config.feature_starts.duplicate()
		config.feature_starts[HunterRules.TYPE] = _start
	var patterns: Array = LevelGenerator.load_for(config)
	var t0: int = Time.get_ticks_usec()
	var gen := LevelGenerator.new()
	var layout: LevelLayout = gen.generate(config, _tuning, patterns)
	var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	var t: HunterTuning = HunterRules.tuning()
	var baits: Array[Dictionary] = HunterRules.bait_points(gen, t)
	var hunters: Array[Dictionary] = HunterRules.hunters_in(layout)
	var parts: PackedStringArray = []
	for e: Dictionary in hunters:
		var at: float = float(e["at"])
		var params: Dictionary = e.get("params", {})
		var n_baits: int = (params.get(HunterRules.BAITS, []) as Array).size()
		var calm: bool = params.has(HunterRules.CALM)
		if not calm:
			_stats["not_calm"] = int(_stats["not_calm"]) + 1
		parts.append("%.2f (%d bait%s%s)" % [at / layout.length, n_baits, "" if n_baits == 1 else "s",
			"" if calm else ", not calm"])
	var found: PackedStringArray = HunterRules.problems(gen)
	found.append_array(GantrywayRules.problems(gen))
	found.append_array(TeleporterRules.problems(gen))
	found.append_array(OctodogJarRules.problems(gen))
	var late: String = ""
	if config.feature_starts.has(HunterRules.TYPE) and not hunters.is_empty():
		var start: float = gen.feature_start(HunterRules.TYPE)
		var past: float = float(hunters[0]["at"]) - start
		late = ", intro %.0f m past its start (reach %.0f)" % [past, INTRODUCTION_REACH * gen.pace]
		if past > INTRODUCTION_REACH * gen.pace:
			_stats["late"] = int(_stats["late"]) + 1
	_stats["builds"] = int(_stats["builds"]) + 1
	_stats["placed"] = int(_stats["placed"]) + hunters.size()
	if hunters.is_empty():
		_stats["none"] = int(_stats["none"]) + 1
	_stats["problems"] = int(_stats["problems"]) + found.size()
	var gantries: PackedStringArray = []
	for g: Dictionary in layout.gantryways:
		gantries.append("%.2f" % (float(g["pillar"]) / layout.length))
	print("%s: %d Hunters [%s]%s; gantryways [%s], %d can be baits; %.0f ms, %d builds%s%s" % [tag, hunters.size(),
		", ".join(parts), late, ", ".join(gantries), baits.size(), ms, gen.attempts,
		"" if found.is_empty() else "; PROBLEMS: " + "; ".join(found),
		"" if gen.warnings.is_empty() else "; warnings: " + "; ".join(gen.warnings)])

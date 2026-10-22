extends SceneTree
## Measures the falling gantryways (task Q3; scripts/enemies/gantryway_rules.gd) over the campaign's levels that have
## them: for each build, how many stand of the level's count, where (their pillars' fronts as a share of the level),
## which have a cyborg planted under them and which keep both lanes beside them clear, how long the build took, and
## what GantrywayRules.problems() finds (nothing, on every build the suites check). From the project folder:
##   godot --headless -s res://tools/measure/gantryways.gd -- [--levels=ice_lab/1,ice_lab/3] [--lanes=3,5,6] [--seeds=N]
## --seeds=N builds each level on its own seed and N others (9001, 9002, ...; default 3). --why prints why an
## introduction found no spot in its window (GantrywayRules.debug).

const GantrywayRules = preload("res://scripts/enemies/gantryway_rules.gd")

var _levels: PackedStringArray = []
var _lanes: Array[int] = [3, 5, 6]
var _seeds: int = 3


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
		elif arg == "--why":
			GantrywayRules.debug = true
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var tuning := load("res://data/tuning/movement.tres") as MovementTuning
	var builds: int = 0
	var placed: int = 0
	var wanted: int = 0
	var planted: int = 0
	var problems: int = 0
	var slowest: float = 0.0
	for s: CampaignStep in campaign.steps():
		if not s.is_level() or s.is_minigame() or not s.level.has_feature(GantrywayRules.FEATURE):
			continue
		if not _levels.is_empty() and not _levels.has(s.id):
			continue
		for lanes: int in _lanes:
			for k: int in _seeds + 1:
				var config: LevelConfig = campaign.configure(s, lanes)
				if k > 0:
					config.level_seed = 9000 + k
				var patterns: Array = LevelGenerator.load_for(config)
				GantrywayRules.spent_usec = 0
				var t0: int = Time.get_ticks_usec()
				var gen := LevelGenerator.new()
				var layout: LevelLayout = gen.generate(config, tuning, patterns)
				var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
				var rules_ms: float = GantrywayRules.spent_usec / 1000.0
				# The same level without its gantryways, for the builds and the time they cost.
				var bare: LevelConfig = config.duplicate() as LevelConfig
				bare.features = config.features.duplicate()
				bare.features.remove_at(bare.features.find(GantrywayRules.FEATURE))
				bare.feature_starts = config.feature_starts.duplicate()
				bare.feature_starts.erase(GantrywayRules.FEATURE)
				var t1: int = Time.get_ticks_usec()
				var bare_gen := LevelGenerator.new()
				bare_gen.generate(bare, tuning, patterns)
				var bare_ms: float = (Time.get_ticks_usec() - t1) / 1000.0
				slowest = maxf(slowest, ms)
				builds += 1
				wanted += config.gantryways
				var found: PackedStringArray = GantrywayRules.problems(gen)
				problems += found.size()
				var parts: PackedStringArray = []
				for g: Dictionary in layout.gantryways:
					placed += 1
					var under: bool = not GantrywayRules.planted_under(layout, g).is_empty()
					planted += 1 if under else 0
					parts.append("%.2f L%d%s%s%s" % [float(g["pillar"]) / layout.length, int(g["lane"]),
						" intro" if g.has("intro") else "", " both" if g.has("both") else "", "" if under else " (no cyborg)"])
				print("%s lanes=%d seed=%d: %d of %d [%s] %.0f ms (%.0f in the rules, %.0f without), %d builds (%d without)%s%s"
					% [s.id, lanes, config.level_seed, layout.gantryways.size(), config.gantryways, ", ".join(parts), ms, rules_ms,
					bare_ms, gen.attempts,
					bare_gen.attempts,
					"" if gen.warnings.is_empty() else " WARNINGS %s" % [gen.warnings],
					"" if found.is_empty() else " PROBLEMS %s" % [found]])
	print("builds %d: %d of %d gantryways stand, %d with a cyborg under them; %d problems; slowest build %.0f ms"
		% [builds, placed, wanted, planted, problems, slowest])
	quit()

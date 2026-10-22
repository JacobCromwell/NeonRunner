extends SceneTree
## Measures the Octodog jars that break open (task Q5; scripts/enemies/octodog_jar_rules.gd) over the campaign's levels
## that have them: for each build, how many jars holding an Octodog stand of the level's count, where (their fronts as a
## share of the level, their lanes, the charges planned for the dog each holds), how far past the feature's start the
## introduction stands, how many of the level's other doodads wear the Octodog jar's look and hold nothing (its skin's
## variety, IceLabDoodads), how long the build took and what OctodogJarRules.problems() finds (nothing, on every build the
## suites check). From the project folder:
##   godot --headless -s res://tools/measure/octodog_jars.gd -- [--levels=ice_lab/1,ice_lab/3] [--lanes=3,5,6] [--seeds=N]
## --seeds=N builds each level on its own seed and N others (9001, 9002, ...; default 3).

const OctodogJarRules = preload("res://scripts/enemies/octodog_jar_rules.gd")

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
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var tuning := load("res://data/tuning/movement.tres") as MovementTuning
	var builds: int = 0
	var placed: int = 0
	var wanted: int = 0
	var looks: int = 0
	var problems: int = 0
	var warned: int = 0
	var slowest: float = 0.0
	var spent: float = 0.0
	for s: CampaignStep in campaign.steps():
		if not s.is_level() or s.is_minigame() or not s.level.has_feature(OctodogJarRules.FEATURE):
			continue
		if not _levels.is_empty() and not _levels.has(s.id):
			continue
		for lanes: int in _lanes:
			for k: int in _seeds + 1:
				var config: LevelConfig = campaign.configure(s, lanes)
				if k > 0:
					config.level_seed = 9000 + k
				var patterns: Array = LevelGenerator.load_for(config)
				OctodogJarRules.spent_usec = 0
				var t0: int = Time.get_ticks_usec()
				var gen := LevelGenerator.new()
				var layout: LevelLayout = gen.generate(config, tuning, patterns)
				var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
				var rules_ms: float = OctodogJarRules.spent_usec / 1000.0
				slowest = maxf(slowest, rules_ms)
				spent += rules_ms
				builds += 1
				wanted += config.octodog_jars
				var found: PackedStringArray = OctodogJarRules.problems(gen)
				problems += found.size()
				warned += 0 if gen.warnings.is_empty() else 1
				var parts: PackedStringArray = []
				var start: float = gen.feature_start(OctodogJarRules.FEATURE)
				for d: Dictionary in layout.doodads:
					if not LevelLayout.holds_enemy(d):
						continue
					placed += 1
					var dog: Dictionary = layout.held_by(d)
					var charges: int = int((dog.get("params", {}) as Dictionary).get("charges", 0))
					parts.append("%.2f L%d x%d%s" % [float(d["start"]) / layout.length, int(d["lane"]), charges,
						(" intro +%.0f m" % (float(d["start"]) - start)) if d.has("intro") else ""])
				# The skin's own Octodog jars: small doodads whose look is the jar, holding nothing.
				var skin_jars: int = 0
				var skin := config.skin as IceLabSkin
				if skin != null:
					for d: Dictionary in layout.doodads:
						if LevelLayout.holds_enemy(d) or StringName(d["size"]) != &"small" or LevelLayout.is_gantry_pillar(d):
							continue
						if skin.doodads().is_octodog_jar(&"small", int(d.get("look", d.get("seed", 0)))):
							skin_jars += 1
				looks += skin_jars
				print("%s lanes=%d seed=%d: %d of %d [%s], %d more Octodog jars holding nothing, %.0f ms (%.1f in the rules), %d builds%s%s"
					% [s.id, lanes, config.level_seed, parts.size(), config.octodog_jars, ", ".join(parts), skin_jars, ms,
						rules_ms, gen.attempts, (" WARN %s" % [gen.warnings]) if not gen.warnings.is_empty() else "",
						(" PROBLEMS %s" % [found]) if not found.is_empty() else ""])
	print("%d builds: %d of %d jars, %d of the skin's empty Octodog jars, %d problems, %d builds with warnings; the rules took %.1f ms on average and %.1f at most"
		% [builds, placed, wanted, looks, problems, warned, spent / maxf(builds, 1.0), slowest])
	quit()

extends SceneTree
## Measures the Octodog jars that break open (task Q5; scripts/enemies/octodog_jar_rules.gd) over the campaign's levels
## that have them: for each build, how many jars holding an Octodog stand of the level's count, where (their fronts as a
## share of the level, their lanes, the charges planned for the dog each holds), how many pieces and enemies the rules
## took out to make room, how many decoys stand (LevelLayout.DECOY: jars whose dog never comes out), how many of the
## level's other doodads wear the Octodog jar's look and hold nothing (its skin's variety, IceLabDoodads), how long the
## build and the rules took and what OctodogJarRules.problems() finds (nothing, on every build the suites check). From the
## project folder:
##   godot --headless -s res://tools/measure/octodog_jars.gd -- [--levels=ice_lab/1,ice_lab/3] [--lanes=3,5,6] [--seeds=N]
##   [--seed-base=8800] [--why] [--without] [--start=S] [--max-taken=N] [--max-ceilings=N]
## --seeds=N builds each level on its own seed and N others (9001, 9002, ...; default 3; --seed-base=8800 for 8801, 8802,
## ...: test_ice_lab_levels' OTHER_SEEDS). --why counts, build by build,
## what turned down the jar fronts tried (OctodogJarRules.debug). --without builds each level without its jars too, for
## the builds and the time they cost. --start=S starts the feature at share S of the level that introduces it (Frost
## Foundry) instead of its own start, and every build of that level says whether its first jar came right after the start
## (test_campaign's INTRODUCTION_REACH) or late. --max-taken=N and --max-ceilings=N try other caps on what one jar takes
## out of its way (OctodogJarRules.max_taken, max_ceilings: MAX_TAKEN_OUT and MAX_CEILINGS_TAKEN_OUT by default).

const OctodogJarRules = preload("res://scripts/enemies/octodog_jar_rules.gd")
## How far past its start an introduction may come and still count as right after it (test_campaign's
## INTRODUCTION_REACH, metres at the reference speed, stretched by the level's pace).
const INTRODUCTION_REACH: float = 210.0

var _levels: PackedStringArray = []
var _lanes: Array[int] = [3, 5, 6]
var _seeds: int = 3
var _without: bool = false
var _seed_base: int = 9000
## --start=S: the share of the level the introducing level (the one that gives the feature a start) starts it from,
## instead of its own (to try a placeholder value).
var _start: float = -1.0


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
			OctodogJarRules.debug = true
		elif arg.begins_with("--seed-base="):
			_seed_base = int(arg.get_slice("=", 1))
		elif arg == "--without":
			_without = true
		elif arg.begins_with("--start="):
			_start = float(arg.get_slice("=", 1))
		elif arg.begins_with("--max-taken="):
			OctodogJarRules.max_taken = int(arg.get_slice("=", 1))
		elif arg.begins_with("--max-ceilings="):
			OctodogJarRules.max_ceilings = int(arg.get_slice("=", 1))
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var tuning := load("res://data/tuning/movement.tres") as MovementTuning
	var builds: int = 0
	var placed: int = 0
	var wanted: int = 0
	var looks: int = 0
	var problems: int = 0
	var warned: int = 0
	var taken: int = 0
	var slowest: float = 0.0
	var spent: float = 0.0
	var intros: int = 0
	var all_decoys: int = 0
	var late_intros: int = 0
	for s: CampaignStep in campaign.steps():
		if not s.is_level() or s.is_minigame() or not s.level.has_feature(OctodogJarRules.FEATURE):
			continue
		if not _levels.is_empty() and not _levels.has(s.id):
			continue
		for lanes: int in _lanes:
			for k: int in _seeds + 1:
				var config: LevelConfig = campaign.configure(s, lanes)
				if k > 0:
					config.level_seed = _seed_base + k
				if _start >= 0.0 and config.feature_starts.has(OctodogJarRules.FEATURE):
					var starts: Dictionary[String, float] = config.feature_starts.duplicate()
					starts[OctodogJarRules.FEATURE] = _start
					config.feature_starts = starts
				var patterns: Array = LevelGenerator.load_for(config)
				if _without:
					# The same level without its jars: the builds and the time they cost.
					var bare: LevelConfig = config.duplicate() as LevelConfig
					bare.features = config.features.duplicate()
					bare.features.remove_at(bare.features.find(OctodogJarRules.FEATURE))
					bare.feature_starts = config.feature_starts.duplicate()
					bare.feature_starts.erase(OctodogJarRules.FEATURE)
					var t1: int = Time.get_ticks_usec()
					var bare_gen := LevelGenerator.new()
					var bare_layout: LevelLayout = bare_gen.generate(bare, tuning, LevelGenerator.load_for(bare))
					print("  without the jars: %d builds, %.0f ms, %d Octodogs standing" % [bare_gen.attempts,
						(Time.get_ticks_usec() - t1) / 1000.0, LevelGenerator.feature_positions(bare_layout, "octodog").size()])
				OctodogJarRules.spent_usec = 0
				OctodogJarRules.taken_out = 0
				OctodogJarRules.why.clear()
				var t0: int = Time.get_ticks_usec()
				var gen := LevelGenerator.new()
				var layout: LevelLayout = gen.generate(config, tuning, patterns)
				var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
				var rules_ms: float = OctodogJarRules.spent_usec / 1000.0
				slowest = maxf(slowest, rules_ms)
				spent += rules_ms
				builds += 1
				wanted += config.octodog_jars
				taken += OctodogJarRules.last_taken
				var found: PackedStringArray = OctodogJarRules.problems(gen)
				problems += found.size()
				warned += 0 if gen.warnings.is_empty() else 1
				var parts: PackedStringArray = []
				var decoys: int = 0
				for d: Dictionary in layout.doodads:
					if not LevelLayout.holds_enemy(d):
						continue
					if LevelLayout.is_decoy(d):
						decoys += 1
						continue
					placed += 1
					var dog: Dictionary = layout.held_by(d)
					var charges: int = int((dog.get("params", {}) as Dictionary).get("charges", 0))
					parts.append("%.2f L%d x%d" % [float(d["start"]) / layout.length, int(d["lane"]), charges])
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
				var standing: int = LevelGenerator.feature_positions(layout, "octodog").size()
				# The level that introduces them (a start of its own): its first jar right after the start, or late.
				var intro: String = ""
				if config.feature_starts.has(OctodogJarRules.FEATURE):
					var at: Array[float] = OctodogJarRules.positions(layout)
					at.sort()
					var late: bool = at.is_empty() or at[0] > gen.feature_start(OctodogJarRules.FEATURE) + INTRODUCTION_REACH * gen.pace
					intros += 1
					late_intros += 1 if late else 0
					intro = ", introduced %s" % ("LATE" if late else "right after its start")
				all_decoys += decoys
				print("%s lanes=%d seed=%d: %d of %d [%s]%s, %d taken out, %d decoys, %d more Octodog jars holding nothing, %d Octodogs standing, %.0f ms (%.1f in the rules), %d builds%s%s"
					% [s.id, lanes, config.level_seed, parts.size(), config.octodog_jars, ", ".join(parts), intro,
						OctodogJarRules.last_taken, decoys, skin_jars, standing, ms, rules_ms, gen.attempts,
						(" WARN %s" % [gen.warnings]) if not gen.warnings.is_empty() else "",
						(" PROBLEMS %s" % [found]) if not found.is_empty() else ""])
				if OctodogJarRules.debug:
					print("  turned down: %s" % [OctodogJarRules.why])
	print("%d builds: %d of %d jars, %d taken out, %d decoys, %d of the skin's empty Octodog jars, %d problems, %d builds with warnings; the rules took %.1f ms on average and %.1f at most; %d of %d introductions late"
		% [builds, placed, wanted, taken, all_decoys, looks, problems, warned, spent / maxf(builds, 1.0), slowest, late_intros,
			intros])
	quit()

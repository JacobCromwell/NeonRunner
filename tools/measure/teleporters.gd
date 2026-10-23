extends SceneTree
## Measures the teleporters (task Q4; scripts/enemies/teleporter_rules.gd) over the campaign's levels that have them: for
## each build, how many stand of the level's count, where (their pads' fronts as a share of the level), what kind (one
## output pad, two with a fixed light, two with a blinking one; the introductions), their lanes and how far they lead, how
## long the build took with them and without them, and what TeleporterRules.problems() finds, and the falling gantryways'
## GantrywayRules.problems(), which counts every rule's keep-outs (nothing, on every build the suites check). From the
## project folder:
##   godot --headless -s res://tools/measure/teleporters.gd -- [--levels=ice_lab/2,ice_lab/3] [--lanes=3,5,6] [--seeds=N]
##     [--seed-list=a,b,c] [--why] [--rules]
## --seeds=N builds each level on its own seed and N others (9001, 9002, ...; default 3), --seed-list on its own and the
## seeds listed. --why prints why an introduction found no spot in its window (TeleporterRules.debug). --rules (task Q6,
## the Golden Zone) also runs, on the same build, the re-checks of the other features whose rules read a teleporter's
## calm stretches or its keep-outs (LevelLayout.doodad_between, LevelGenerator.rules_doodad_keep_outs): the Resonators'
## pulses, the Gilded Sentinels', the Enforcer Trucks' and the dash walls', and the level's wider gaps against its count,
## and prints what each finds, and what the same level without its teleporters has (wider gaps, dash walls).

const TeleporterRules = preload("res://scripts/enemies/teleporter_rules.gd")
const GantrywayRules = preload("res://scripts/enemies/gantryway_rules.gd")
const ResonatorRules = preload("res://scripts/enemies/resonator_rules.gd")
const SentinelRules = preload("res://scripts/enemies/gilded_sentinel_rules.gd")
const EnforcerRules = preload("res://scripts/enemies/enforcer_truck_rules.gd")
const DashWallRules = preload("res://scripts/enemies/dash_wall_rules.gd")

var _levels: PackedStringArray = []
var _lanes: Array[int] = [3, 5, 6]
var _seeds: int = 3
## --seed-list=a,b: these seeds instead of 9001, 9002, ...
var _seed_list: Array[int] = []
## --rules: the other features' re-checks of each build (_other_rules).
var _rules: bool = false


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
		elif arg.begins_with("--seed-list="):
			for v: String in arg.get_slice("=", 1).split(",", false):
				_seed_list.append(int(v))
		elif arg == "--why":
			TeleporterRules.debug = true
		elif arg == "--rules":
			_rules = true
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var tuning := load("res://data/tuning/movement.tres") as MovementTuning
	var builds: int = 0
	var placed: int = 0
	var wanted: int = 0
	var blinking: int = 0
	var blink_wanted: int = 0
	var problems: int = 0
	var slowest: float = 0.0
	var rules_most: float = 0.0
	var rules_total: float = 0.0
	for s: CampaignStep in campaign.steps():
		if not s.is_level() or s.is_minigame() or not s.level.has_feature(TeleporterRules.FEATURE):
			continue
		if not _levels.is_empty() and not _levels.has(s.id):
			continue
		for lanes: int in _lanes:
			for k: int in (_seed_list.size() if not _seed_list.is_empty() else _seeds) + 1:
				var config: LevelConfig = campaign.configure(s, lanes)
				if k > 0:
					config.level_seed = _seed_list[k - 1] if not _seed_list.is_empty() else 9000 + k
				var patterns: Array = LevelGenerator.load_for(config)
				TeleporterRules.spent_usec = 0
				var t0: int = Time.get_ticks_usec()
				var gen := LevelGenerator.new()
				var layout: LevelLayout = gen.generate(config, tuning, patterns)
				var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
				var rules_ms: float = TeleporterRules.spent_usec / 1000.0
				rules_most = maxf(rules_most, rules_ms / maxf(gen.attempts, 1))
				rules_total += rules_ms
				# The same level without its teleporters, for the builds and the time they cost.
				var bare: LevelConfig = config.duplicate() as LevelConfig
				bare.features = config.features.duplicate()
				for f: String in [TeleporterRules.FEATURE, TeleporterRules.BLINKING]:
					if bare.features.has(f):
						bare.features.remove_at(bare.features.find(f))
				bare.feature_starts = config.feature_starts.duplicate()
				bare.feature_starts.erase(TeleporterRules.FEATURE)
				bare.feature_starts.erase(TeleporterRules.BLINKING)
				var t1: int = Time.get_ticks_usec()
				var bare_gen := LevelGenerator.new()
				bare_gen.generate(bare, tuning, patterns)
				var bare_ms: float = (Time.get_ticks_usec() - t1) / 1000.0
				var others: String = _other_rules(gen, bare_gen, tuning) if _rules else ""
				slowest = maxf(slowest, ms)
				builds += 1
				wanted += config.teleporters
				var blink_count: int = config.blinking_teleporters if config.has_feature(TeleporterRules.BLINKING) else 0
				blink_wanted += blink_count
				var found: PackedStringArray = TeleporterRules.problems(gen)
				# The falling gantryways' re-check counts every rule's keep-outs, the teleporters' among them.
				if config.has_feature(GantrywayRules.FEATURE):
					found.append_array(GantrywayRules.problems(gen))
				# A fenced ceiling's pick plays out alone (CeilingScenarios.event_spans): no teleporter's window in it.
				for tp: Dictionary in layout.teleporters:
					for w: Vector2 in TeleporterRules.windows_of(gen, tp).get(-1, []):
						for h: Dictionary in layout.hulls:
							var pick: Variant = h.get("pick")
							if pick is Array and (pick as Array).size() == 2 and w.x < float(pick[1]) and w.y > float(pick[0]):
								found.append("the teleporter at %.1f m: its window %.1f-%.1f m in a fenced ceiling's pick %.1f-%.1f m"
									% [float(tp["at"]), w.x, w.y, float(pick[0]), float(pick[1])])
				problems += found.size()
				var parts: PackedStringArray = []
				for tp: Dictionary in layout.teleporters:
					placed += 1
					var outs: PackedStringArray = []
					for o: Dictionary in tp["outputs"]:
						outs.append(str(int(o["lane"])))
					var kind: String = "one"
					if float(tp["blink"]) > 0.0:
						kind = "blink"
						blinking += 1
					elif (tp["outputs"] as Array).size() > 1:
						kind = "fixed %s" % ("L" if int(tp["light"]) < 0 else "R")
					parts.append("%.2f L%d>%s %s +%.0fm%s" % [float(tp["at"]) / layout.length, int(tp["lane"]), "/".join(outs),
						kind, float((tp["outputs"] as Array)[0]["at"]) - float(tp["at"]), " intro" if tp.has("intro") else ""])
				print("%s lanes=%d seed=%d: %d of %d [%s] %.0f ms (%.0f in the rules, %.0f without), %d builds (%d without)%s%s%s"
					% [s.id, lanes, config.level_seed, layout.teleporters.size(), config.teleporters, ", ".join(parts), ms,
					rules_ms, bare_ms, gen.attempts, bare_gen.attempts,
					"" if gen.warnings.is_empty() else " WARNINGS %s" % [gen.warnings],
					"" if found.is_empty() else " PROBLEMS %s" % [found], others])
				if _rules and others.contains("PROBLEMS"):
					problems += 1
	print("builds %d: %d of %d teleporters stand, %d of %d blinking; %d problems; slowest build %.0f ms; the rules %.0f ms a build on average, %.0f at most"
		% [builds, placed, wanted, blinking, blink_wanted, problems, slowest, rules_total / maxf(builds, 1), rules_most])
	quit()


## --rules: what the other features' own re-checks find in `gen`'s build (the Resonators' pulses, the Gilded Sentinels',
## the Enforcer Trucks', the dash walls'), and its wider gaps and dash walls against the level's counts and against the
## same level built without its teleporters (`bare`), as a line to print.
func _other_rules(gen: LevelGenerator, bare: LevelGenerator, tuning: MovementTuning) -> String:
	var config: LevelConfig = gen.config
	var layout: LevelLayout = gen.layout
	var found: PackedStringArray = []
	if config.has_feature("resonator"):
		for p: String in ResonatorRules.problems(layout, config, tuning):
			found.append("resonator: " + p)
	if config.has_feature("gilded_sentinel"):
		for p: String in SentinelRules.problems(layout, config, tuning):
			found.append("sentinel: " + p)
	if config.has_feature("enforcer_truck"):
		for p: String in EnforcerRules.problems(gen):
			found.append("enforcer truck: " + p)
	if config.has_feature(DashWallRules.FEATURE):
		for p: String in DashWallRules.problems(gen):
			found.append("dash wall: " + p)
	var jump: float = gen.tuning.jump_distance(gen.speed)
	var et := EnemyDirector.tuning_for("enforcer_truck") as EnforcerTruckTuning
	var hop: float = et.max_hop_jump_fraction if et != null else 0.6
	var wide: int = WideGapPlacement.wide_rows(layout, jump, hop).size()
	var bare_wide: int = WideGapPlacement.wide_rows(bare.layout, jump, hop).size()
	return " | wide gaps %d of %d (%d without), dash walls %d of %d (%d without), resonators %d (%d without)%s" % [wide,
		config.wide_gaps, bare_wide, layout.dash_walls.size(), config.dash_walls if config.has_feature(DashWallRules.FEATURE) else 0,
		bare.layout.dash_walls.size(), ResonatorRules.resonators_in(layout).size(),
		ResonatorRules.resonators_in(bare.layout).size(), "" if found.is_empty() else " PROBLEMS %s" % [found]]

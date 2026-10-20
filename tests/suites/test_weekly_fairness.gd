extends TestSuite
## The weekly challenge's seed list, held to the per-feature checks the campaign's own suites make (task N5, the
## review's finding on fairness): test_weekly_challenge generates every entry and runs the checks every level gets
## (LayoutChecks); this runs the ones each feature's own suite makes of a level that has it, and builds each twice.
## Every entry of data/weekly/weekly_seeds.json passes them, at five lanes, as the weekly kit has it:
## - danger density's fairness (test_danger_density `_check_fair`: a floor route through the level, an open lane around
##   everything the pass added, only small threats added, the count it says it kept);
## - the hover trucks' rules (test_hover_truck `_check_rules`) and the Enforcer Truck's own placement rules
##   (EnforcerTruckRules.problems);
## - the Gilded Sentinels' and the Resonators' rules (their `problems()`);
## - wall gaps clear of their keep-outs, and no wall credit where a wall is gone;
## - a host's chase: nothing the rules keep off a chase stands where it may begin (HostWatch.kept_off_chases, the
##   early-chase margin of a runner who walks to the host);
## - a way across every wall-run gap (FloorRoute);
## - the same layout from a second build.
## A slow suite (about 70 s: it builds every level twice more); the weekly files map to it in tests/suite_map.json, and
## the generator's own changes run it with the full tier. tools/measure/weekly_seeds.gd runs check_deep on candidate
## seeds, so the list is only ever given entries that pass it.
## It reaches into test_danger_density's and test_hover_truck's checks (`_build_pair`, `_check_fair`, `_check_rules`)
## rather than copy them: if one is renamed, `_setup` says so.

const EnforcerRules = preload("res://scripts/enemies/enforcer_truck_rules.gd")
const GildedSentinelRules = preload("res://scripts/enemies/gilded_sentinel_rules.gd")
const ResonatorRules = preload("res://scripts/enemies/resonator_rules.gd")
const HostWatch = preload("res://tools/measure/host_watch.gd")
const HostRules = preload("res://scripts/enemies/host_rules.gd")
const DangerDensity := preload("res://scripts/world/danger_density.gd")

var campaign: Campaign
var def: WeeklyChallenge
var _danger: TestSuite
var _hover: TestSuite
var _hover_tuning: HoverTruckTuning


func run() -> void:
	campaign = load("res://data/campaign/campaign.tres") as Campaign
	def = WeeklyChallenge.load_default()
	if not setup():
		return
	var entries: Array[Dictionary] = def.entries()
	for i: int in entries.size():
		var w: WeeklyWeek = def.week(i)
		check_deep(w, "week %d (%s, seed %d)" % [i, w.zone_id, w.level_seed])


## Gets the two suites whose checks this one borrows ready (needs `tree`, `tuning`, `campaign` and `def` set). False,
## with a failure, if one of their checks is gone.
func setup() -> bool:
	_danger = (load("res://tests/suites/test_danger_density.gd") as GDScript).new() as TestSuite
	_danger.tree = tree
	_danger.tuning = tuning
	_danger.set(&"_dd_tuning", DangerDensity.tuning())
	_hover = (load("res://tests/suites/test_hover_truck.gd") as GDScript).new() as TestSuite
	_hover.tree = tree
	_hover.tuning = tuning
	_hover_tuning = load("res://data/enemies/hover_truck.tres") as HoverTruckTuning
	var ok: bool = _danger.has_method(&"_build_pair") and _danger.has_method(&"_check_fair") and _hover.has_method(&"_check_rules")
	check(ok, "test_danger_density still has _build_pair and _check_fair and test_hover_truck _check_rules: this suite borrows them")
	return ok


## One week's level through every per-feature check (see the header). Failures are added to `failures`.
func check_deep(w: WeeklyWeek, tag: String) -> void:
	var config: LevelConfig = def.build_config(campaign, w)
	check(config != null, "%s has a level" % tag)
	if config == null:
		return
	var danger_before: int = _danger.failures.size()
	var hover_before: int = _hover.failures.size()
	# The level built with the danger density dial and without it (two fresh builds): the pass's fairness.
	var built: Dictionary = _danger.call(&"_build_pair", config)
	var gen: LevelGenerator = built["gen"]
	var layout: LevelLayout = gen.layout
	_danger.call(&"_check_fair", config, gen, built["off"], tag, built["off_gen"])
	if config.has_feature("hover_truck"):
		_hover.call(&"_check_rules", layout, config, _hover_tuning, tag)
	if config.has_feature("enforcer_truck"):
		var enforcer: PackedStringArray = EnforcerRules.problems(gen)
		check(enforcer.is_empty(), "enforcer truck rules %s: %s" % [tag, "; ".join(enforcer)])
	if config.has_feature("gilded_sentinel"):
		var sentinels: PackedStringArray = GildedSentinelRules.problems(layout, config, tuning)
		check(sentinels.is_empty(), "gilded sentinel rules %s: %s" % [tag, sentinels])
	if config.has_feature("resonator"):
		var resonators: PackedStringArray = ResonatorRules.problems(layout, config, tuning)
		check(resonators.is_empty(), "resonator rules %s: %s" % [tag, resonators])
	if config.has_feature(WallGapPlacement.FEATURE):
		_check_wall_gaps(gen, layout, config, tag)
	if config.has_feature("host"):
		_check_host_chases(gen, layout, tag)
	if config.has_feature("wall_run_gaps"):
		var movement: MovementTuning = config.movement_for(tuning)
		var grid := FloorRoute.new(layout, movement)
		for gap: Dictionary in layout.wall_run_gaps:
			var from: float = grid.clear_start(float(gap["entry"]))
			var route: Dictionary = grid.find(from, float(gap["landing"]))
			check(bool(route["ok"]), "a way across the wall-run gap at %.0f %s: %s" % [float(gap["start"]), tag, route.get("reason", "")])
	# Determinism: the level the cache built (or builds) and this build are the same.
	var cached: LevelLayout = LayoutCache.generate(config, tuning, LevelGenerator.load_for(config))
	check(JSON.stringify(cached.to_dict()) == JSON.stringify(layout.to_dict()), "the same layout twice " + tag)
	# What the borrowed checks found.
	for message: String in _danger.failures.slice(danger_before):
		check(false, "danger density: " + message)
	for message: String in _hover.failures.slice(hover_before):
		check(false, "hover truck: " + message)


## Wall gaps clear of their keep-outs, and no wall credit in a gap (test_wall_gaps' rules). A level without wall running
## (the Terminal's, task O1) has nothing on its walls to keep them standing: its arches keep clear of nothing
## (WallGapPlacement._arches; LayoutChecks.check_boundary_walls checks there is nothing).
func _check_wall_gaps(gen: LevelGenerator, layout: LevelLayout, config: LevelConfig, tag: String) -> void:
	var tuning_gaps: WallGapTuning = WallGapPlacement.tuning_for(config)
	for side: int in ([-1, 1] if layout.wall_running else []):
		var keeps: Array[Vector2] = WallGapPlacement.keep_outs(gen, layout, side, tuning_gaps)
		for gap: Dictionary in layout.wall_gaps:
			if int(gap["side"]) != side:
				continue
			for keep: Vector2 in keeps:
				check(not (float(gap["start"]) < keep.y - 0.01 and float(gap["end"]) > keep.x + 0.01),
					"wall gap %s clear of keep-out %s %s" % [gap, keep, tag])
	for credit: Dictionary in layout.credits:
		if credit["surface"] == "wall":
			check(layout.wall_supported(int(credit["side"]), float(credit["at"])), "no wall credit in a gap %s" % tag)


## Hosts: nothing the rules keep off a chase stands where a chase may begin, with the early-chase margin of a runner who
## walks up to the host (CyborgTuning.walk_max and the Bad Dream's hover_ahead).
func _check_host_chases(gen: LevelGenerator, layout: LevelLayout, tag: String) -> void:
	var bad_dream: BadDreamTuning = HostRules.tuning()
	var cyborg := EnemyDirector.tuning_for("cyborg") as CyborgTuning
	var early: float = cyborg.walk_max + bad_dream.hover_ahead
	var kept: Array[Dictionary] = HostWatch.kept_off_chases(gen)
	for host: Dictionary in HostRules.hosts_in(layout):
		var at: float = float(host["at"])
		var met: PackedStringArray = []
		for k: Dictionary in kept:
			var span: Vector2 = k["span"]
			if span.x < at and span.y >= at - early:
				met.append("%s %.0f-%.0f" % [k["what"], span.x, span.y])
		check(met.is_empty(), "%s: nothing kept off chases where the host at %.0f's chase may begin: %s" % [tag, at, met])

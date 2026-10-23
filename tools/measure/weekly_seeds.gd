extends SceneTree
## Looks for seeds the weekly challenge's shipped list (data/weekly/weekly_seeds.json) can take (task N5): each seed
## of a zone is built as that zone's weekly level at five lanes and put through every check the list is held to,
## test_weekly_challenge's (the campaign levels' fairness checks, LayoutChecks, the generator's warnings, the guarantee
## that every feature of the zone appears, the level's config) and test_weekly_fairness's (the per-feature checks, a
## second build). A seed that passes is safe to add; adding one is a line in the JSON, and the suites then check it
## again. From the project folder (with XDG_DATA_HOME set as for the tests):
##   godot --headless -s res://tools/measure/weekly_seeds.gd -- [--zone=city] [--from=9100] [--block=100] [--count=20]
##       [--pick=4 --max-builds=3] [--failures]
## Options:
##   --zone=city,gangland   the zones to look in (default: every zone in the campaign)
##   --from=9100            where the first zone's seeds start (default 9100)
##   --block=100            a zone's seeds start `block` above the one before it, counting the campaign's zones in
##                          order (so `--zone=golden`, the tenth zone, starts at 10000 with the defaults); 0: every zone
##                          starts at --from
##   --count=20             how many seeds in a row to try for each zone (default 20; with --pick, at most that many)
##   --pick=4               stop a zone after this many seeds have been chosen (0, the default: list every passing seed)
##   --max-builds=3         with --pick: only a seed whose level the generator built in this many builds or fewer
##                          can be chosen (default 3)
##   --failures             also print what each failing seed failed
## THE RULE THE SHIPPED LIST WAS MADE BY (item 1036): for each zone, in the campaign's order, try the
## seeds from the zone's block upward (--from=9100 --block=100: the Neon City 9100, Gangland 9200, ...) and take the first
## four that pass every check and were built in at most three builds. The generator builds a level again until
## every feature appears (the guarantee), so a build count is how hard the level was to make, and a build takes about
## 1.3 s on a desktop and several times that on a phone: a level of five or six builds would be a long wait for the
## week's first load. The list then goes round by round, the first pick of every zone, then the second pick of every
## zone, and so on, which is the order this prints under "Passed" when it picks. Run with `--pick=4` and no --zone to
## remake it; the output is the list's entries.

const CAMPAIGN_PATH: String = "res://data/campaign/campaign.tres"

var _zones: PackedStringArray = []
var _from: int = 9100
var _block: int = 100
var _count: int = 20
var _pick: int = 0
var _max_builds: int = 3
var _failures: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--zone="):
			_zones = arg.get_slice("=", 1).split(",", false)
		elif arg.begins_with("--from="):
			_from = int(arg.get_slice("=", 1))
		elif arg.begins_with("--block="):
			_block = int(arg.get_slice("=", 1))
		elif arg.begins_with("--count="):
			_count = int(arg.get_slice("=", 1))
		elif arg.begins_with("--pick="):
			_pick = int(arg.get_slice("=", 1))
		elif arg.begins_with("--max-builds="):
			_max_builds = int(arg.get_slice("=", 1))
		elif arg == "--failures":
			_failures = true
	var campaign := load(CAMPAIGN_PATH) as Campaign
	var all_zones: PackedStringArray = []
	for zone: ZoneDef in campaign.zones:
		if not zone.placeholder and not zone.levels.is_empty():
			all_zones.append(String(zone.id))
	if _zones.is_empty():
		_zones = all_zones
	var def: WeeklyChallenge = WeeklyChallenge.load_default()
	var basic: TestSuite = (load("res://tests/suites/test_weekly_challenge.gd") as GDScript).new() as TestSuite
	basic.tree = self
	basic.tuning = load(TestSuite.TUNING_PATH) as MovementTuning
	basic.set(&"campaign", campaign)
	basic.set(&"def", def)
	var deep: TestSuite = (load("res://tests/suites/test_weekly_fairness.gd") as GDScript).new() as TestSuite
	deep.tree = self
	deep.tuning = basic.tuning
	deep.set(&"campaign", campaign)
	deep.set(&"def", def)
	if not deep.call(&"setup"):
		print("the per-feature checks can't be set up: ", deep.failures)
		quit(1)
		return
	var density_config: LevelConfig = campaign.configure(campaign.step(def.density_step), def.lanes)
	var picked: Dictionary = {}
	for zone: String in _zones:
		var first: int = _from + _block * all_zones.find(zone) if _block > 0 else _from
		picked[zone] = []
		for level_seed: int in range(first, first + _count):
			var w := WeeklyWeek.new()
			w.zone_id = StringName(zone)
			w.level_seed = level_seed
			var tag: String = "%s %d" % [zone, level_seed]
			var basic_before: int = basic.failures.size()
			var deep_before: int = deep.failures.size()
			var stats := {"builds": 0, "levels": 0}
			basic.call(&"check_entry", w, tag, stats, density_config)
			deep.call(&"check_deep", w, tag)
			var added: int = basic.failures.size() - basic_before + deep.failures.size() - deep_before
			var builds: int = int(stats["builds"])
			if added > 0:
				print("%s: FAILS %d" % [tag, added])
				if _failures:
					var messages: PackedStringArray = basic.failures.slice(basic_before) + deep.failures.slice(deep_before)
					for message: String in messages.slice(0, 4):
						print("    " + message)
			elif _pick > 0 and builds > _max_builds:
				print("%s: ok, but %d builds (more than %d)" % [tag, builds, _max_builds])
			else:
				print("%s: ok (%d builds)" % [tag, builds])
				(picked[zone] as Array).append(level_seed)
				if _pick > 0 and (picked[zone] as Array).size() >= _pick:
					break
	print("\nPassed (%s):" % ("round by round" if _pick > 0 else "every seed that passes"))
	var lines: PackedStringArray = []
	if _pick > 0:
		for round: int in _pick:
			for zone: String in _zones:
				var seeds: Array = picked[zone]
				if round < seeds.size():
					lines.append('\t\t{"zone": "%s", "seed": %d}' % [zone, seeds[round]])
	else:
		for zone: String in _zones:
			for level_seed: Variant in picked[zone]:
				lines.append('\t\t{"zone": "%s", "seed": %d}' % [zone, level_seed])
	print(",\n".join(lines))
	quit()

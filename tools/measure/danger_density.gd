extends SceneTree
## Measures each campaign level's actual danger density (owner's request, docs/USER_REQUESTS.md: more
## enemies and obstacles, about 15% more in the first levels rising to about 35% in the last; the
## open-lane allowance tightened): every level at 3, 5 and 6 lanes, on its own seed and others, built
## with its LevelConfig.danger_density_increase and with it forced to 0 (the build as it was before the
## request: the pass is off and every random stream untouched). From the project folder:
##   godot --headless -s res://tools/measure/danger_density.gd -- [options]
## Options:
##   --levels=city/1,golden/3   campaign steps (default: every level)
##   --lanes=3,5,6              lane counts (default 3,5,6)
##   --seeds=N                  each level's own seed and N others, 9001.. (default 2)
##   --dump=FILE                write every baseline (increase 0) layout as JSON (LevelLayout.to_dict)
##   --compare=FILE             check every baseline layout against FILE's (a dump made before the
##                              change): the off switch must build exactly what the old code built
## Counts (per layout, then the sum over seeds per lane count):
## - enemies: every layout enemy (LevelLayout.enemies);
## - obstacles: every lane piece of danger: each lane of a hole, each lane of a fence, each sign, each
##   wall fence and each floor cut (doodads never hurt and aren't counted);
## - floor: obstacles without wall fences (the pass's floor target; wall fences come after it);
## - credits: the layout's credit value (LevelLayout.total_credit_value), to see what the economy gets;
## - rows: floor rows (holes or fences at one spot), signs, wall fences and floor cuts;
## - free: the mean lanes a floor row leaves open (the open-lane allowance the request tightens).
## Prints, per level and lane count, the baseline and the boosted counts, their ratio, and the
## LevelGenerator.danger_density_result shortfalls; then each zone's, each dial band's (early: dial up to
## 0.20, middle: up to 0.29, late: the rest) and the campaign's sums; then every danger category
## separately (enemies by type; obstacles as gap lanes, fence lanes, signs, wall fences and floor cuts)
## per band and over the whole sample. A bounded representative run (the suite's levels):
##   --levels=city/1,city/2,gangland/2,marketplace/2,corporate/1,dead_zone/1,golden/2,golden/3 --seeds=2

const CAMPAIGN_PATH: String = "res://data/campaign/campaign.tres"
const TUNING_PATH: String = "res://data/tuning/movement.tres"
const KNOB: String = "danger_density_increase"
const CATEGORY: String = "cat:"
## Bands by the level's dial, as tests/suites/test_danger_density.gd samples them: [name, highest dial].
const BANDS: Array = [["early", 0.20], ["middle", 0.29], ["late", 1.0]]

var _levels: PackedStringArray = []
var _lanes: Array[int] = [3, 5, 6]
var _seeds: int = 2
var _dump: String = ""
var _compare: String = ""


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
	var old: Dictionary = {}
	if _compare != "":
		old = JSON.parse_string(FileAccess.get_file_as_string(_compare))
	var dump: Dictionary = {}
	var mismatches: PackedStringArray = []
	var started: int = Time.get_ticks_msec()
	var ms_off: int = 0
	var ms_on: int = 0
	var has_knob: bool = false
	var totals: Dictionary = {}
	print("%-14s %5s %5s | %-24s | %-24s | %-24s | %-15s | %s" % ["level", "lanes", "inc", "enemies off->on (x)",
		"obstacles off->on (x)", "floor off->on (x)", "free lanes/row", "credits x, rows off->on, builds, shortfalls"])
	for id: String in _levels:
		var step: CampaignStep = campaign.step(id)
		if step == null or not step.is_level() or step.is_minigame():
			print("%s: not a campaign level" % id)
			continue
		for lanes: int in _lanes:
			var sum_off: Dictionary = {}
			var sum_on: Dictionary = {}
			var increase: float = 0.0
			var shortfalls: PackedStringArray = []
			for k: int in _seeds + 1:
				var config: LevelConfig = campaign.configure(step, lanes)
				if k > 0:
					config.level_seed = 9000 + k
				has_knob = KNOB in config
				if has_knob:
					increase = float(config.get(KNOB))
				var off: LevelConfig = config.duplicate() as LevelConfig
				if has_knob:
					off.set(KNOB, 0.0)
				var t0: int = Time.get_ticks_msec()
				var gen_off := LevelGenerator.new()
				var layout_off: LevelLayout = gen_off.generate(off, tuning, LevelGenerator.load_for(off))
				ms_off += Time.get_ticks_msec() - t0
				var key: String = "%s lanes=%d seed=%d" % [id, lanes, config.level_seed]
				var dict: Dictionary = layout_off.to_dict()
				if _dump != "":
					dump[key] = dict
				if old.has(key) and JSON.stringify(old[key], "", true, true) != JSON.stringify(
						JSON.parse_string(JSON.stringify(dict, "", true, true)), "", true, true):
					mismatches.append(key)
				_add(sum_off, count(layout_off), gen_off.attempts)
				var gen_on: LevelGenerator = gen_off
				var layout_on: LevelLayout = layout_off
				if has_knob and increase > 0.0:
					t0 = Time.get_ticks_msec()
					gen_on = LevelGenerator.new()
					layout_on = gen_on.generate(config, tuning, LevelGenerator.load_for(config))
					ms_on += Time.get_ticks_msec() - t0
					var result: Dictionary = gen_on.get("danger_density_result") if "danger_density_result" in gen_on else {}
					for c: String in result.get("constraints", PackedStringArray()):
						shortfalls.append("seed %d: %s" % [config.level_seed, c])
					if not gen_on.warnings.is_empty():
						shortfalls.append("seed %d warnings: %s" % [config.level_seed, gen_on.warnings])
				_add(sum_on, count(layout_on), gen_on.attempts)
			_print_row(id, lanes, increase, sum_off, sum_on, shortfalls)
			var zone: String = id.get_slice("/", 0)
			var scopes: Array[String] = [zone, "campaign"]
			if increase > 0.0:
				scopes.append("band " + _band(increase))
			for scope: String in scopes:
				var tkey: String = "%s|%d" % [scope, lanes]
				if not totals.has(tkey):
					totals[tkey] = {"off": {}, "on": {}}
				_merge(totals[tkey]["off"], sum_off)
				_merge(totals[tkey]["on"], sum_on)
	print("\n%-14s %5s | %-24s | %-24s | %-24s | %-15s | %s" % ["zone", "lanes", "enemies off->on (x)",
		"obstacles off->on (x)", "floor off->on (x)", "free lanes/row", "credits off->on (x)"])
	for tkey: String in totals:
		var off_t: Dictionary = totals[tkey]["off"]
		var on_t: Dictionary = totals[tkey]["on"]
		print("%-14s %5s | %-24s | %-24s | %-24s | %5.2f -> %5.2f | %s" % [tkey.get_slice("|", 0), tkey.get_slice("|", 1),
			_ratio(off_t, on_t, "enemies"), _ratio(off_t, on_t, "obstacles"), _ratio(off_t, on_t, "floor"),
			_free(off_t), _free(on_t), _ratio(off_t, on_t, "credits")])
	_print_categories(totals)
	if _dump != "":
		var file := FileAccess.open(_dump, FileAccess.WRITE)
		file.store_string(JSON.stringify(dump, "", true, true))
		file.close()
		print("wrote %d baseline layouts to %s" % [dump.size(), _dump])
	if _compare != "":
		print("baseline vs %s: %d of %d layouts differ %s" % [_compare, mismatches.size(), old.size(), mismatches])
	print("knob %s: %s; build time off %.1f s, on %.1f s; measured in %.0f s" % [KNOB,
		"present" if has_knob else "absent (old code: only the baseline)", ms_off / 1000.0, ms_on / 1000.0,
		(Time.get_ticks_msec() - started) / 1000.0])
	quit(1 if not mismatches.is_empty() else 0)


func _parse_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var value: String = arg.get_slice("=", 1)
		if arg.begins_with("--levels="):
			_levels = value.split(",", false)
		elif arg.begins_with("--lanes="):
			_lanes.clear()
			for v: String in value.split(",", false):
				_lanes.append(int(v))
		elif arg.begins_with("--seeds="):
			_seeds = int(value)
		elif arg.begins_with("--dump="):
			_dump = value
		elif arg.begins_with("--compare="):
			_compare = value


## One layout's danger: {enemies, obstacles, rows, row_lanes, floor_rows}.
static func count(layout: LevelLayout) -> Dictionary:
	var rows: Dictionary = {}
	for g: Dictionary in layout.gaps:
		var key: String = "%.1f" % float(g["start"])
		rows[key] = int(rows.get(key, 0)) + 1
	for f: Dictionary in layout.fences:
		var key: String = "%.1f" % float(f["at"])
		rows[key] = int(rows.get(key, 0)) + 1
	var row_lanes: int = 0
	for key: String in rows:
		row_lanes += mini(int(rows[key]), layout.lane_count)
	var obstacles: int = layout.gaps.size() + layout.fences.size() + layout.signs.size() \
		+ layout.wall_fences.size() + layout.cuts.size()
	var c: Dictionary = {"enemies": layout.enemies.size(), "obstacles": obstacles,
		"floor": obstacles - layout.wall_fences.size(), "wall_fences": layout.wall_fences.size(),
		"credits": layout.total_credit_value(),
		"rows": rows.size() + layout.signs.size() + layout.wall_fences.size() + layout.cuts.size(),
		"floor_rows": rows.size(), "free": rows.size() * layout.lane_count - row_lanes,
		CATEGORY + "obstacle gap lanes": layout.gaps.size(), CATEGORY + "obstacle fence lanes": layout.fences.size(),
		CATEGORY + "obstacle signs": layout.signs.size(), CATEGORY + "obstacle wall fences": layout.wall_fences.size(),
		CATEGORY + "obstacle floor cuts": layout.cuts.size()}
	for e: Dictionary in layout.enemies:
		var key: String = CATEGORY + "enemy " + String(e.get("type", "?"))
		c[key] = int(c.get(key, 0)) + 1
	return c


func _add(sum: Dictionary, c: Dictionary, attempts: int) -> void:
	for key: String in c:
		sum[key] = int(sum.get(key, 0)) + int(c[key])
	sum["builds"] = int(sum.get("builds", 0)) + attempts


func _merge(into: Dictionary, sum: Dictionary) -> void:
	for key: String in sum:
		into[key] = int(into.get(key, 0)) + int(sum[key])


func _ratio(off: Dictionary, on: Dictionary, key: String) -> String:
	var a: int = int(off.get(key, 0))
	var b: int = int(on.get(key, 0))
	return "%5d -> %5d (%5.3f)" % [a, b, float(b) / maxf(a, 1.0)]


func _print_row(id: String, lanes: int, increase: float, off: Dictionary, on: Dictionary,
		shortfalls: PackedStringArray) -> void:
	print("%-14s %5d %5.2f | %-24s | %-24s | %-24s | %5.2f -> %5.2f | %5.3f, %d -> %d, %d/%d, %s" % [id, lanes,
		increase, _ratio(off, on, "enemies"), _ratio(off, on, "obstacles"), _ratio(off, on, "floor"), _free(off),
		_free(on), float(on["credits"]) / maxf(float(off["credits"]), 1.0), off["rows"], on["rows"],
		off["builds"], on["builds"], shortfalls if not shortfalls.is_empty() else "-"])


## The mean lanes a floor row leaves open in sums `c`.
func _free(c: Dictionary) -> float:
	return float(c.get("free", 0)) / maxf(float(c.get("floor_rows", 0)), 1.0)


func _band(increase: float) -> String:
	for b: Array in BANDS:
		if increase <= float(b[1]) + 0.0001:
			return String(b[0])
	return String(BANDS[-1][0])


## Each danger category (enemies by type, obstacles by kind) per band and the whole sample, off -> on
## at every measured lane count.
func _print_categories(totals: Dictionary) -> void:
	var scopes: PackedStringArray = []
	for b: Array in BANDS:
		scopes.append("band " + String(b[0]))
	scopes.append("campaign")
	for scope: String in scopes:
		var categories: Dictionary = {}
		for lanes: int in _lanes:
			var tkey: String = "%s|%d" % [scope, lanes]
			if totals.has(tkey):
				for side: String in ["off", "on"]:
					for key: String in totals[tkey][side]:
						if key.begins_with(CATEGORY):
							categories[key] = true
		if categories.is_empty():
			continue
		var header: String = "\n%-34s" % ("categories: " + scope)
		for lanes: int in _lanes:
			header += " | %-24s" % ("%d lanes off->on (x)" % lanes)
		print(header)
		var keys: Array = categories.keys()
		keys.sort()
		for key: String in keys:
			var line: String = "%-34s" % key.substr(CATEGORY.length())
			for lanes: int in _lanes:
				var tkey: String = "%s|%d" % [scope, lanes]
				line += " | " + (_ratio(totals[tkey]["off"], totals[tkey]["on"], key) if totals.has(tkey) else "%-24s" % "-")
			print(line)

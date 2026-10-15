extends SceneTree
## Measures the campaign's shape (task R5): for each level, each feature's share of the pattern
## pass's picks (GDD §5, owner's review P2 13: a level's newest things get the most picks, through the
## campaign's recency curve, FeatureRecency), the enemy and obstacle counts, the features that appear
## only thanks to the every-feature guarantee, and for a level paced in bursts (The Hush,
## LevelConfig.quiet_seconds) its quiet stretches against its bursts. Each setting can be switched off
## to see what it changes. From the project folder (with XDG_DATA_HOME set as for the tests):
##   godot --headless -s res://tools/measure/level_shape.gd -- [options]
## Options:
##   --levels=dead_zone/1,dead_zone/2   campaign steps (default: every level)
##   --lanes=3,5,6                      lane counts (default 3,5,6)
##   --seeds=N                          each level's own seed and N others (default 8)
##   --curve=on,off                     the recency curve (default both)
##   --remix=on|off                     off resets the levels' quiet stretches, quiet features, darkness
##                                      and feature weights (default on)
## The whole campaign, both ways, takes about a minute and a half.
##
## Per level and setting it prints: builds (how many the every-feature guarantee took, on average);
## enemies (hosts apart), hosts and obstacle rows (a row of holes or fences, and signs) per level;
## `alone`: features some layouts have only thanks to the guarantee (built without it, the layout
## has none), with in how many; and each built feature's share of the feature picks, newest first,
## `*` marking those the level introduces. A level paced in bursts adds its enemies and obstacle rows
## per 100 m in quiet stretches and in bursts.

var _levels: PackedStringArray = []
var _lanes: Array[int] = [3, 5, 6]
var _seeds: int = 8
var _curves: Array[bool] = [true, false]
var _remix: bool = true


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_parse_args()
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var tuning := load("res://data/tuning/movement.tres") as MovementTuning
	if _levels.is_empty():
		for s: CampaignStep in campaign.steps():
			if s.is_level() and not s.is_minigame():
				_levels.append(s.id)
	var started: int = Time.get_ticks_msec()
	for id: String in _levels:
		var step: CampaignStep = campaign.step(id)
		if step == null or not step.is_level() or step.is_minigame():
			print("%s: not a campaign level" % id)
			continue
		for curve: bool in _curves:
			_measure(campaign, step, tuning, curve)
	print("measured in %.0f s" % ((Time.get_ticks_msec() - started) / 1000.0))
	quit(0)


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
		elif arg.begins_with("--curve="):
			_curves.clear()
			for v: String in value.split(",", false):
				_curves.append(v == "on")
		elif arg.begins_with("--remix="):
			_remix = value == "on"


func _measure(campaign: Campaign, step: CampaignStep, tuning: MovementTuning, curve: bool) -> void:
	var picks: Dictionary = {}
	var feature_picks: int = 0
	var alone: Dictionary = {}
	var totals: Dictionary = {"levels": 0, "builds": 0, "enemies": 0, "hosts": 0, "rows": 0}
	var paced: Dictionary = {"quiet_m": 0.0, "burst_m": 0.0, "quiet_e": 0, "burst_e": 0, "quiet_r": 0, "burst_r": 0}
	var ages: Dictionary = {}
	for lanes: int in _lanes:
		for k: int in _seeds + 1:
			var config: LevelConfig = campaign.configure(step, lanes)
			if k > 0:
				config.level_seed = 9000 + k
			if not curve:
				config.feature_recency = null
			if not _remix:
				_reset_remix(config)
			ages = config.feature_ages
			var patterns: Array = LevelGenerator.load_for(config)
			var gen := LevelGenerator.new()
			var layout: LevelLayout = gen.generate(config, tuning, patterns)
			var plain: LevelConfig = config.duplicate() as LevelConfig
			plain.guarantee_features = false
			var natural: LevelLayout = LevelGenerator.new().generate(plain, tuning, patterns)
			totals["levels"] = int(totals["levels"]) + 1
			totals["builds"] = int(totals["builds"]) + gen.attempts
			for p: Dictionary in gen.picks:
				for f: Variant in p["requires"]:
					picks[String(f)] = int(picks.get(String(f), 0)) + 1
					feature_picks += 1
			for f: String in config.features:
				if LayoutChecks.can_locate(f) and LevelGenerator.feature_positions(natural, f).is_empty() \
						and not LevelGenerator.feature_positions(layout, f).is_empty():
					alone[f] = int(alone.get(f, 0)) + 1
			var rows: Array[float] = _row_starts(layout)
			totals["rows"] = int(totals["rows"]) + rows.size()
			for e: Dictionary in layout.enemies:
				var host: bool = String(e["type"]) == "cyborg" and bool((e.get("params", {}) as Dictionary).get("host", false))
				totals["hosts" if host else "enemies"] = int(totals["hosts" if host else "enemies"]) + 1
				if not host and config.paced_in_bursts():
					var key: String = "quiet_e" if gen.quiet_at(float(e["at"])) else "burst_e"
					paced[key] = int(paced[key]) + 1
			if config.paced_in_bursts():
				var quiet: float = 0.0
				for s: Vector2 in gen.quiet_stretches():
					quiet += s.y - s.x
				paced["quiet_m"] = float(paced["quiet_m"]) + quiet
				paced["burst_m"] = float(paced["burst_m"]) + layout.length - config.end_clear_distance \
					- config.start_clear_distance - quiet
				for at: float in rows:
					var key: String = "quiet_r" if gen.quiet_at(at) else "burst_r"
					paced[key] = int(paced[key]) + 1
	var n: float = float(totals["levels"])
	var shares: Array = []
	for f: String in picks:
		shares.append([f, 100.0 * int(picks[f]) / maxf(feature_picks, 1.0)])
	shares.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	var share_text: PackedStringArray = []
	for s: Array in shares:
		share_text.append("%s%s %.0f%%" % ["*" if int(ages.get(s[0], -1)) == 0 else "", s[0], s[1]])
	var alone_text: PackedStringArray = []
	for f: String in alone:
		alone_text.append("%s %d" % [f, alone[f]])
	print("%-14s curve %-3s builds %.2f  enemies %5.1f  hosts %.2f  obstacle rows %5.1f  alone: %s" % [step.id,
		"on" if curve else "off", int(totals["builds"]) / n, int(totals["enemies"]) / n, int(totals["hosts"]) / n,
		int(totals["rows"]) / n, ", ".join(alone_text) if not alone_text.is_empty() else "-"])
	print("               picks: %s" % ", ".join(share_text))
	if float(paced["quiet_m"]) > 0.0:
		print("               per 100 m: enemies %.2f in quiet stretches, %.2f in bursts; obstacle rows %.2f and %.2f" % [
			100.0 * int(paced["quiet_e"]) / float(paced["quiet_m"]), 100.0 * int(paced["burst_e"]) / float(paced["burst_m"]),
			100.0 * int(paced["quiet_r"]) / float(paced["quiet_m"]), 100.0 * int(paced["burst_r"]) / float(paced["burst_m"])])


## A level's own shape switched off: even pacing, no quiet features, its zone's light, no feature weights.
func _reset_remix(config: LevelConfig) -> void:
	var defaults := LevelConfig.new()
	config.quiet_seconds = defaults.quiet_seconds
	config.quiet_features = defaults.quiet_features
	config.darkness = defaults.darkness
	var none: Dictionary[String, float] = {}
	config.feature_weights = none


## The track distances where a row of holes or fences starts, and each sign's.
func _row_starts(layout: LevelLayout) -> Array[float]:
	var seen: Dictionary = {}
	for g: Dictionary in layout.gaps:
		seen["g%.2f" % float(g["start"])] = float(g["start"])
	for f: Dictionary in layout.fences:
		seen["f%.2f" % float(f["at"])] = float(f["at"])
	for s: Dictionary in layout.signs:
		seen["s%.2f" % float(s["start"])] = float(s["start"])
	var out: Array[float] = []
	out.assign(seen.values())
	return out

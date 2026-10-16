extends SceneTree
## Measures the wall-run gaps (task J2; WallRunGapPlacement): every campaign level that has them, at each lane count,
## on its own seed and `--seeds` others (9001 on), as the campaign configures it: where they may start from (the
## feature's start or the run-up), how many each build places, where (the gap's start, its lit wall's side), what each
## took out of its way (its cost; the plain pieces and the enemies that went), the pass's constraints and any rule a
## placed one breaks (WallRunGapPlacement.problem); then a summary per zone (the mean count a build). `--set=name:value`
## sets the shared tuning's numbers in memory for the run.
## `--dump=<step id>` prints a text map of each wall-run gap in that level's build (one row per lane and per wall, a
## column per DUMP_STEP metres, from its clear run-in to its landing floor's end): the level dump a review asks for.
## From the project folder (with XDG_DATA_HOME set as for the tests):
##   godot --headless -s res://tools/measure/wall_run_gaps.gd -- [--lanes=3,5,6] [--seeds=2] [--levels=golden/1,...]
##       [--dump=marketplace/1] [--seed-list=9206,9208] [--no-remix] [--set=name:value,...]

const CAMPAIGN_PATH: String = "res://data/campaign/campaign.tres"
## Metres a column of the dump's map stands for.
const DUMP_STEP: float = 2.0

var _lanes: Array[int] = [3, 5, 6]
var _seeds: int = 0
var _levels: PackedStringArray = []
var _dump: String = ""
var _seed_list: Array[int] = []
var _no_remix: bool = false
## The shared tuning, held for the whole run so a --set stays (the resource cache keeps no resource nothing holds).
var _tuning: WallRunGapTuning


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_tuning = WallRunGapPlacement.tuning()
	for arg: String in OS.get_cmdline_user_args():
		var value: String = arg.get_slice("=", 1)
		if arg.begins_with("--lanes="):
			_lanes.clear()
			for part: String in value.split(",", false):
				_lanes.append(int(part))
		elif arg.begins_with("--seeds="):
			_seeds = int(value)
		elif arg.begins_with("--levels="):
			_levels = value.split(",", false)
		elif arg.begins_with("--dump="):
			_dump = value
		elif arg.begins_with("--seed-list="):
			# Review aid: these seeds too (after the level's own and --seeds').
			for part: String in value.split(",", false):
				_seed_list.append(int(part))
		elif arg == "--no-remix":
			# Review aid: each build without a paced level's remix (test_campaign's "The Hush without the remix").
			_no_remix = true
		elif arg.begins_with("--set="):
			# Review aid: --set=approach_seconds:0.8,entry_window_seconds:0.5 sets the shared tuning's numbers in memory.
			for pair: String in value.split(",", false):
				_tuning.set(pair.get_slice(":", 0), float(pair.get_slice(":", 1)))
	var campaign := load(CAMPAIGN_PATH) as Campaign
	var base := load("res://data/tuning/movement.tres") as MovementTuning
	var t: WallRunGapTuning = WallRunGapPlacement.tuning()
	var zones: Dictionary = {}
	for s: CampaignStep in campaign.steps():
		if not s.is_level() or s.is_minigame():
			continue
		if not _levels.is_empty() and not _levels.has(s.id):
			continue
		if not s.level.has_feature(WallRunGapPlacement.FEATURE):
			continue
		for lanes: int in _lanes:
			var seeds: Array[int] = [-1]
			for k: int in _seeds:
				seeds.append(9001 + k)
			seeds.append_array(_seed_list)
			for level_seed: int in seeds:
				var config: LevelConfig = campaign.configure(s, lanes)
				if level_seed >= 0:
					config.level_seed = level_seed
				if _no_remix:
					config.quiet_seconds = 0.0
					config.quiet_features = PackedStringArray()
					var none: Dictionary[String, float] = {}
					config.feature_weights = none
					config.darkness = 0.0
				var gen := LevelGenerator.new()
				var t0: int = Time.get_ticks_msec()
				var layout: LevelLayout = gen.generate(config, base, LevelGenerator.load_for(config))
				var ms: int = Time.get_ticks_msec() - t0
				var shape: WallRunGapPlacement.Shape = WallRunGapPlacement.shape_of(gen, t)
				var where: PackedStringArray = []
				var problems: PackedStringArray = []
				for w: Dictionary in layout.wall_run_gaps:
					where.append("%.0f m %s" % [float(w["start"]), "L" if int(w["side"]) < 0 else "R"])
					var why: String = WallRunGapPlacement.problem(gen, w)
					if why != "":
						problems.append("%.0f m: %s" % [float(w["start"]), why])
				var report: Dictionary = gen.wall_run_gap_result
				print("%s lanes=%d seed=%d (%.1f m/s, gap %.1f m, zone %.0f m, from %.0f m): %d [%s] cost %s (%d pieces, %d enemies), the pass %d ms of the build's %d ms%s%s%s" % [
					s.id, lanes, config.level_seed, gen.speed, shape.gap, shape.zone(),
					maxf(gen.feature_start(WallRunGapPlacement.FEATURE), config.start_clear_distance), layout.wall_run_gaps.size(),
					", ".join(where), report.get("costs", []), int(report.get("taken_out", 0)),
					int(report.get("enemies_taken_out", 0)), int(report.get("ms", 0)), ms,
					"" if problems.is_empty() else "; PROBLEMS: " + "; ".join(problems),
					"" if (report.get("constraints", []) as Array).is_empty() else "; " + "; ".join(report["constraints"]),
					"" if gen.warnings.is_empty() else "; WARNINGS: " + "; ".join(gen.warnings)])
				var key: String = String(s.zone.id)
				if not zones.has(key):
					zones[key] = Vector2i.ZERO
				zones[key] += Vector2i(layout.wall_run_gaps.size(), 1)
				if s.id == _dump and level_seed < 0:
					for w: Dictionary in layout.wall_run_gaps:
						_print_map(layout, w)
	print("per zone, mean wall-run gaps a build:")
	for key: String in zones:
		var v: Vector2i = zones[key]
		print("  %s: %.2f (%d over %d builds)" % [key, float(v.x) / maxf(float(v.y), 1.0), v.x, v.y])
	quit()


## A text map of wall-run gap `w` in `layout`: a row per wall and lane (the left wall on top), a column per DUMP_STEP
## metres from its clear run-in to its landing floor's end. Floor: `.` floor, `#` a hole, `f` a fence, `d` a doodad;
## walls: `|` wall, `=` its lit stretch (where to step on), `~` its lit wall over the gap, ` ` a wall gap, `s` a sign,
## `w` a wall fence.
func _print_map(layout: LevelLayout, w: Dictionary) -> void:
	var from: float = float(w["approach"])
	var to: float = float(w["landing"])
	var cols: int = int(ceil((to - from) / DUMP_STEP))
	print("  wall-run gap %.1f-%.1f m (lit wall %s from %.1f m; run-in from %.1f m, landing floor to %.1f m, wall clear to %.1f m)"
		% [float(w["start"]), float(w["end"]), "left" if int(w["side"]) < 0 else "right", float(w["entry"]), from, to,
		float(w["wall_to"])])
	for row: int in range(-1, layout.lane_count + 1):
		var line: String = ""
		for c: int in cols:
			var d: float = from + (c + 0.5) * DUMP_STEP
			line += _cell(layout, w, row, d)
		var label: String = "L wall" if row < 0 else ("R wall" if row >= layout.lane_count else "lane %d" % row)
		print("  %-7s %s" % [label, line])


func _cell(layout: LevelLayout, w: Dictionary, row: int, d: float) -> String:
	var half: float = DUMP_STEP * 0.5
	if row < 0 or row >= layout.lane_count:
		var side: int = -1 if row < 0 else 1
		if not layout.wall_supported(side, d):
			return " "
		for s: Dictionary in layout.signs:
			if int(s["side"]) == side and float(s["start"]) <= d + half and float(s["end"]) >= d - half:
				return "s"
		if layout.wall_fence_between(d - half, d + half, side):
			return "w"
		if int(w["side"]) == side and d >= float(w["entry"]) and d <= float(w["end"]):
			return "=" if d < float(w["start"]) else "~"
		return "|"
	if layout.gapped_between(row, d - half + 0.01, d + half - 0.01):
		return "#"
	for f: Dictionary in layout.fences:
		if int(f["lane"]) == row and absf(float(f["at"]) - d) <= half:
			return "f"
	if layout.doodad_between(d - half, d + half, row):
		return "d"
	return "."

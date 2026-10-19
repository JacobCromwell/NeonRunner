extends SceneTree
## Measures the wall-hop credits (task N1; WallHopPlacement): every campaign level that asks for them
## (LevelConfig.wall_hop_lines), at each lane count, on its own seed and `--seeds` others (9001 on), as the campaign
## configures it: the line's shape at the level's speed (one wall run's reach with and without claws, where the
## high-value credits lie and how high, its stretch's length), how many lines each build places and where, the
## longest stretch that would have fitted on either wall where none did, and any rule a placed one breaks
## (WallHopPlacement.problem); then the share of builds with a line, per zone.
## From the project folder (with XDG_DATA_HOME set as for the tests):
##   godot --headless -s res://tools/measure/wall_hops.gd -- [--lanes=3,5,6] [--seeds=2] [--levels=gangland/1,...]

const CAMPAIGN_PATH: String = "res://data/campaign/campaign.tres"

var _lanes: Array[int] = [3, 5, 6]
var _seeds: int = 0
var _levels: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var v: String = arg.get_slice("=", 1)
		if arg.begins_with("--lanes="):
			_lanes.clear()
			for s: String in v.split(","):
				_lanes.append(int(s))
		elif arg.begins_with("--seeds="):
			_seeds = int(v)
		elif arg.begins_with("--levels="):
			_levels = v.split(",")
	var campaign := load(CAMPAIGN_PATH) as Campaign
	var base := load("res://data/tuning/movement.tres") as MovementTuning
	var t: WallHopTuning = WallHopPlacement.tuning()
	var by_zone: Dictionary = {}
	var shown: Dictionary = {}
	for s: CampaignStep in campaign.steps():
		if not s.is_level() or s.is_minigame() or s.level.wall_hop_lines <= 0:
			continue
		if not _levels.is_empty() and not _levels.has(s.id):
			continue
		for lanes: int in _lanes:
			for k: int in _seeds + 1:
				var config: LevelConfig = campaign.configure(s, lanes)
				if k > 0:
					config.level_seed = 9000 + k
				var gen := LevelGenerator.new()
				var layout: LevelLayout = gen.generate(config, base, LevelGenerator.load_for(config))
				var v: float = gen.speed
				var shape: Dictionary = WallHopPlacement.shape_for(gen.tuning, v, t)
				if not shown.has(s.zone.id) and not shape.is_empty():
					shown[s.zone.id] = true
					var path: WallHopPath = shape["path"]
					var gems: Array = shape["gems"]
					print("%s at %.1f m/s: one wall run reaches %.1f m (%.2f s), with claws %.1f m; lead-in %d credits; %d high-value at %.2f m high from %.1f to %.1f m (%.2f-%.2f s, wall run %d of the hopper's, %d hops); its stretch %.0f m (%.1f s)"
						% [s.zone.id, v, path.distance_at(path.run_end(0)), path.run_end(0),
						path.distance_at(path.run_end(0, WallHopPlacement.claws_multiplier())), (shape["lead"] as Array).size(),
						gems.size(), float(gems[0]["height"]), float(gems[0]["at"]), float(gems[-1]["at"]), float(gems[0]["t"]),
						float(gems[-1]["t"]), int(shape["run"]) + 1, int(shape["run"]),
						float(shape["to"]) - float(shape["from"]), (float(shape["to"]) - float(shape["from"])) / v])
				var tag: String = "%-14s lanes=%d seed=%d" % [s.id, lanes, config.level_seed]
				var zone: String = String(s.zone.id)
				if not by_zone.has(zone):
					by_zone[zone] = [0, 0]
				by_zone[zone][1] = int(by_zone[zone][1]) + 1
				if layout.wall_hops.is_empty():
					var need: float = float(shape.get("to", 0.0)) - float(shape.get("from", 0.0))
					var best: float = 0.0
					for side: int in [-1, 1]:
						for free: Vector2 in LevelGenerator.free_stretches(WallHopPlacement.busy_spans(gen, side),
								config.start_clear_distance, layout.length - config.end_clear_distance):
							best = maxf(best, free.y - free.x)
					print("%s  none: the longest clear stretch %.0f m (%.1f s), one needs %.0f m" % [tag, best, best / v, need])
					continue
				by_zone[zone][0] = int(by_zone[zone][0]) + 1
				for w: Dictionary in layout.wall_hops:
					var problem: String = WallHopPlacement.problem(gen, w)
					print("%s  %s wall, entry at %.0f m (%.0f%%), high-value from %.0f to %.0f m%s" % [tag,
						"left" if int(w["side"]) < 0 else "right", float(w["entry"]), 100.0 * float(w["entry"]) / layout.length,
						float(w["gems_from"]), float(w["gems_to"]), "" if problem == "" else "  PROBLEM: " + problem])
	print("Builds with a line, by zone:")
	for zone: String in by_zone:
		print("  %-12s %d of %d" % [zone, by_zone[zone][0], by_zone[zone][1]])
	quit()

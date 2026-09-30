extends SceneTree
## Measures each campaign level's pace and density (task G1; GDD §3, "Pace and busier levels": the
## owner's playtest asked for a faster runner and busier levels, "so there is always something going
## on"). From the project folder (with XDG_DATA_HOME set as for the tests):
##   godot --headless -s res://tools/measure/level_pace.gd -- [options]
## Options:
##   --levels=city/1,dead_zone/2   campaign steps (default: every level)
##   --lanes=3,5,6                 lane counts (default 3,5,6)
##   --seeds=N                     each level's own seed and N others (default 4)
##   --speed=zone|base             zone: each level's own run speed (its zone's, LevelConfig.run_speed);
##                                 base: the movement tuning's run speed for every level (default zone)
##   --old-data=DIR                before generating, copy the values of DIR's .tres files onto the live
##                                 resources of the same path under res://data (DIR/levels/city_1.tres onto
##                                 res://data/levels/city_1.tres, DIR/enemies/..., DIR/tuning/...,
##                                 DIR/zones/...), and take the patterns from DIR/patterns if it has them:
##                                 a level built with another version's data (the byte-identity proof)
##   --dump=FILE                   also write every layout (LevelLayout.to_dict) to FILE as JSON, keyed
##                                 "<level> lanes=<n> seed=<s>", plus the prototype level (quick play) at
##                                 several difficulties and seeds, with and without every enemy feature
##   --no-measure                  only the dump
##
## Per level (the average over its lane counts and seeds) it prints the run speed, the level's length,
## and per minute of play: obstacle rows (a row of holes or fences at one spot, and each sign), of which
## rows of holes; enemies; big attacks (each Octodog charge and Resonator pulse the generator planned,
## each drone wave and each hover truck); mechanics (ramps, anti-grav pads, speed pads); and all events
## (rows, enemies and mechanics). Then its empty stretches, in seconds at its run speed: the longest
## (the mean of each layout's longest, and the longest of all) and the mean, over the level between its
## run-up and its end-clear stretch. What counts as going on (the rest is empty):
## - every hole, fence and sign; every ramp, pad and speed pad; a ceiling ride isn't (it's optional);
## - a floor or window cyborg (host too) for 2 s before its spot (its charge-up and bolts come as the
##   player closes in), a screech for its trigger time (1.6 s), a fence generator at its spot;
## - an Octodog over the run its charges use (its floor_span), a Resonator from each pulse's warning to
##   where its wave meets the player, a drone wave from its arrival to its first pad, a hover truck for
##   its shortest stay.
## In a level paced in bursts (The Hush) it also prints the longest empty stretch inside its bursts
## (its quiet stretches are empty by design). Credits: the credits' total value and count per level.

const CAMPAIGN_PATH: String = "res://data/campaign/campaign.tres"
const TUNING_PATH: String = "res://data/tuning/movement.tres"
const QUICK_LEVEL: String = "res://data/levels/prototype_level.tres"
## Seconds before its spot a cyborg (and the like) counts as going on, per enemy type; types with
## their own rule are handled in _activity.
const ENEMY_LEAD_SECONDS: Dictionary = {"cyborg": 2.0, "window_cyborg": 2.0, "screech": 1.6, "generator": 0.0}

var _levels: PackedStringArray = []
var _lanes: Array[int] = [3, 5, 6]
var _seeds: int = 4
var _base_speed: bool = false
var _old_data: String = ""
var _dump: String = ""
var _measure_on: bool = true
var _patterns_dir: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_parse_args()
	if _old_data != "":
		_apply_old_data(_old_data)
	var campaign := load(CAMPAIGN_PATH) as Campaign
	var tuning := load(TUNING_PATH) as MovementTuning
	if _levels.is_empty():
		for s: CampaignStep in campaign.steps():
			if s.is_level():
				_levels.append(s.id)
	var started: int = Time.get_ticks_msec()
	var dump: Dictionary = {}
	if _measure_on:
		print("%-14s %5s %5s %6s | per min: %5s %5s %5s %5s %5s %6s | empty s: %5s %5s %5s | %6s %5s" % ["level",
			"m/s", "s", "m", "rows", "holes", "enem", "big", "mech", "events", "max", "worst", "mean", "credit",
			"count"])
	for id: String in _levels:
		var step: CampaignStep = campaign.step(id)
		if step == null or not step.is_level():
			print("%s: not a campaign level" % id)
			continue
		var rows: Array[Dictionary] = []
		for lanes: int in _lanes:
			for k: int in _seeds + 1:
				var config: LevelConfig = campaign.configure(step, lanes)
				if k > 0:
					config.level_seed = 9000 + k
				if _base_speed and "run_speed" in config:
					config.set("run_speed", 0.0)
				_use_patterns(config)
				var gen := LevelGenerator.new()
				var layout: LevelLayout = gen.generate(config, tuning, LevelGenerator.load_for(config))
				if _dump != "":
					dump["%s lanes=%d seed=%d" % [id, lanes, config.level_seed]] = layout.to_dict()
				if _measure_on:
					rows.append(_measure(gen, layout, config))
		if _measure_on:
			_print_level(id, rows)
	if _dump != "":
		_dump_quick_play(tuning, dump)
		var file := FileAccess.open(_dump, FileAccess.WRITE)
		file.store_string(JSON.stringify(dump, "", true, true))
		file.close()
		print("wrote %d layouts to %s" % [dump.size(), _dump])
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
		elif arg.begins_with("--speed="):
			_base_speed = value == "base"
		elif arg.begins_with("--old-data="):
			_old_data = value
		elif arg.begins_with("--dump="):
			_dump = value
		elif arg == "--no-measure":
			_measure_on = false


## Copies every .tres under `dir` onto the live resource at the same path under res://data, so the
## campaign, the enemies' rules and the generator all read those values (resources are cached: every
## load() of the path returns the live one). Properties the old files don't have keep their defaults
## (a fresh instance's), so a new setting reads as off.
func _apply_old_data(dir: String) -> void:
	for sub: String in ["tuning", "enemies", "levels", "zones", "campaign"]:
		var from_dir: String = dir.path_join(sub)
		if not DirAccess.dir_exists_absolute(from_dir):
			continue
		for file: String in DirAccess.get_files_at(from_dir):
			if not file.ends_with(".tres"):
				continue
			var live_path: String = "res://data".path_join(sub).path_join(file)
			if not ResourceLoader.exists(live_path):
				continue
			var old: Resource = ResourceLoader.load(from_dir.path_join(file), "", ResourceLoader.CACHE_MODE_IGNORE)
			var live: Resource = load(live_path)
			if old == null or live == null:
				print("could not read %s" % file)
				continue
			var fresh: Object = (live.get_script() as GDScript).new() if live.get_script() != null else null
			for prop: Dictionary in live.get_property_list():
				if not (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) or not (int(prop["usage"]) & PROPERTY_USAGE_STORAGE):
					continue
				var name: String = prop["name"]
				var value: Variant = old.get(name) if name in old else (fresh.get(name) if fresh != null else null)
				# Sub-resources (skins, level lists) are the live ones: only plain values are old data.
				if typeof(value) == TYPE_OBJECT:
					continue
				live.set(name, value)
	if DirAccess.dir_exists_absolute(dir.path_join("patterns")):
		_patterns_dir = dir.path_join("patterns")


## Points `config` at the old patterns (--old-data with a patterns folder).
func _use_patterns(config: LevelConfig) -> void:
	if _patterns_dir != "":
		config.patterns_path = _patterns_dir.path_join(config.patterns_path.get_file())


## The prototype level (quick play), as the generator suite builds it, for the dump.
func _dump_quick_play(tuning: MovementTuning, dump: Dictionary) -> void:
	var base := load(QUICK_LEVEL) as LevelConfig
	var every: PackedStringArray = ["ramps", "ceilings", "pulsing", "speed_pads", "cyborg", "window_cyborg",
		"hover_truck", "octodog", "screech", "drone", "generator", "host", "resonator"]
	for all_features: bool in [false, true]:
		for lanes: int in [3, 5, 6]:
			for difficulty: float in [0.0, 0.3, 0.6, 1.0]:
				for level_seed: int in range(1, 6):
					var config: LevelConfig = base.duplicate() as LevelConfig
					config.lane_count = lanes
					config.difficulty = difficulty
					config.level_seed = level_seed
					if all_features:
						config.features = every
						config.enemy_scaling = difficulty
					_use_patterns(config)
					var layout: LevelLayout = LevelGenerator.new().generate(config, tuning, LevelGenerator.load_for(config))
					dump["quick%s lanes=%d diff=%.1f seed=%d" % [" all" if all_features else "", lanes, difficulty,
						level_seed]] = layout.to_dict()


## One layout's numbers: {speed, seconds, length, rows, holes, enemies, big, mechanics, longest, gaps
## (every empty stretch, s), burst_longest, credits, count}.
func _measure(gen: LevelGenerator, layout: LevelLayout, config: LevelConfig) -> Dictionary:
	var speed: float = gen.speed
	var rows: Dictionary = {}
	var holes: Dictionary = {}
	for g: Dictionary in layout.gaps:
		holes["%.2f" % float(g["start"])] = true
		rows["g%.2f" % float(g["start"])] = true
	for f: Dictionary in layout.fences:
		rows["f%.2f" % float(f["at"])] = true
	var row_count: int = rows.size() + layout.signs.size()
	var big: int = 0
	var waves: Dictionary = {}
	for e: Dictionary in layout.enemies:
		var params: Dictionary = e.get("params", {})
		match String(e["type"]):
			"octodog":
				big += (params.get("charge_at", []) as Array).size()
			"resonator":
				big += (params.get("pulse_at", []) as Array).size()
			"drone":
				waves["%.1f" % float(e["at"])] = true
			"hover_truck":
				big += 1
	big += waves.size()
	var mechanics: int = layout.ramps.size() + layout.pads.size() + layout.speed_pads.size()
	var busy: Array[Vector2] = activity(gen, layout, config)
	var from: float = config.start_clear_distance
	var to: float = layout.length - config.end_clear_distance
	var empty: Array[float] = empty_stretches(busy, from, to)
	var longest: float = 0.0
	var gaps_s: Array[float] = []
	var burst_longest: float = 0.0
	for i: int in range(0, empty.size(), 2):
		var seconds: float = (empty[i + 1] - empty[i]) / speed
		gaps_s.append(seconds)
		longest = maxf(longest, seconds)
		if config.paced_in_bursts():
			for b: Vector2 in gen.burst_spans(empty[i], empty[i + 1]):
				burst_longest = maxf(burst_longest, (b.y - b.x) / speed)
	var minutes: float = (to - from) / speed / 60.0
	return {"speed": speed, "seconds": layout.length / speed, "length": layout.length,
		"rows": row_count / minutes, "holes": holes.size() / minutes, "enemies": layout.enemies.size() / minutes,
		"big": big / minutes, "mechanics": mechanics / minutes,
		"events": (row_count + layout.enemies.size() + mechanics) / minutes,
		"longest": longest, "gaps": gaps_s, "burst_longest": burst_longest,
		"credits": layout.total_credit_value(), "count": layout.credits.size()}


## The stretches of track [from, to] where something is going on (see the header).
static func activity(gen: LevelGenerator, layout: LevelLayout, config: LevelConfig) -> Array[Vector2]:
	var speed: float = gen.speed
	var t: MovementTuning = gen.tuning
	var out: Array[Vector2] = []
	for g: Dictionary in layout.gaps:
		out.append(Vector2(g["start"], g["end"]))
	for f: Dictionary in layout.fences:
		out.append(Vector2(float(f["at"]) - t.fence_depth * 0.5, float(f["at"]) + t.fence_depth * 0.5))
	for s: Dictionary in layout.signs:
		out.append(Vector2(s["start"], s["end"]))
	for r: Dictionary in layout.ramps:
		out.append(Vector2(r["at"], float(r["at"]) + t.ramp_length))
	for p: Dictionary in layout.pads:
		out.append(Vector2(p["at"], float(p["at"]) + t.pad_length))
	for p: Dictionary in layout.speed_pads:
		out.append(Vector2(p["at"], float(p["at"]) + t.speed_pad_length))
	var pads: Array[float] = []
	for p: Dictionary in layout.pads:
		pads.append(float(p["at"]))
	pads.sort()
	for e: Dictionary in layout.enemies:
		var at: float = float(e["at"])
		var params: Dictionary = e.get("params", {})
		match String(e["type"]):
			"octodog":
				var span: Vector2 = LevelGenerator.enemy_floor_span(e)
				out.append(span if span.y >= span.x else Vector2(at, at))
			"resonator":
				var rt := EnemyDirector.tuning_for("resonator") as ResonatorTuning
				for a: Variant in params.get("pulse_at", []):
					out.append(Vector2(float(a), float(a) + rt.meet_offset(speed, config.enemy_scaling)))
			"drone":
				var first: float = at
				for p: float in pads:
					if p > at + 0.01:
						first = p
						break
				out.append(Vector2(at, first))
			"hover_truck":
				var ht := EnemyDirector.tuning_for("hover_truck") as HoverTruckTuning
				out.append(Vector2(at, at + ht.stay_min_seconds * speed))
			var type:
				var lead: float = float(ENEMY_LEAD_SECONDS.get(type, 0.0)) * speed
				out.append(Vector2(at - lead, at))
	return out


## The empty stretches between `from` and `to` that `busy` leaves, flattened: [start0, end0, start1, ...].
static func empty_stretches(busy: Array[Vector2], from: float, to: float) -> Array[float]:
	busy.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var out: Array[float] = []
	var cursor: float = from
	for b: Vector2 in busy:
		if b.y < cursor:
			continue
		if b.x > cursor:
			out.append(cursor)
			out.append(minf(b.x, to))
			if b.x >= to:
				return out
		cursor = maxf(cursor, b.y)
		if cursor >= to:
			return out
	if cursor < to:
		out.append(cursor)
		out.append(to)
	return out


func _print_level(id: String, rows: Array[Dictionary]) -> void:
	if rows.is_empty():
		return
	var n: float = float(rows.size())
	var sums: Dictionary = {}
	var worst: float = 0.0
	var burst_worst: float = 0.0
	var all_gaps: Array[float] = []
	for r: Dictionary in rows:
		for key: String in ["speed", "seconds", "length", "rows", "holes", "enemies", "big", "mechanics", "events",
				"longest", "credits", "count"]:
			sums[key] = float(sums.get(key, 0.0)) + float(r[key])
		worst = maxf(worst, float(r["longest"]))
		burst_worst = maxf(burst_worst, float(r["burst_longest"]))
		all_gaps.append_array(r["gaps"])
	var mean_gap: float = 0.0
	for g: float in all_gaps:
		mean_gap += g
	mean_gap /= maxf(all_gaps.size(), 1.0)
	print("%-14s %5.1f %5.0f %6.0f | per min: %5.1f %5.1f %5.1f %5.1f %5.1f %6.1f | empty s: %5.2f %5.2f %5.2f | %6.0f %5.0f%s" % [
		id, sums["speed"] / n, sums["seconds"] / n, sums["length"] / n, sums["rows"] / n, sums["holes"] / n,
		sums["enemies"] / n, sums["big"] / n, sums["mechanics"] / n, sums["events"] / n, sums["longest"] / n, worst,
		mean_gap, sums["credits"] / n, sums["count"] / n,
		("  (bursts: longest empty %.2f s)" % burst_worst) if burst_worst > 0.0 else ""])

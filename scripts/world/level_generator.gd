class_name LevelGenerator
extends RefCounted
## Rule-based level generator: data-driven patterns + a difficulty value + a seed.
## Works for any lane count. Never refers to zone skins (trucks, streets, ...).
## Pattern format is documented in data/patterns/README.md.
##
## Passes, each with its own random stream so adding one never reshuffles the others:
## 1. Patterns (obstacles and enemies) from the pattern files, filtered by the level's features.
## 2. Enemy rules: for every feature with a script at res://scripts/enemies/<feature>_rules.gd,
##    its static `apply(gen: LevelGenerator)` runs (e.g. drone anti-grav pad schedules).
## 3. Credits (GDD §7): trails in the clear stretches, rich credits in risky spots.
## Fairness rules (longest gap, hull lead-in and landing) come from LevelConfig, so they are data.

const DENOMINATIONS: Array[int] = [1, 5, 25, 100]
const RULES_DIR: String = "res://scripts/enemies"

var layout: LevelLayout
var config: LevelConfig
var tuning: MovementTuning
## Run speed the level is built for, and a full jump's length at that speed.
var speed: float
var jump_distance: float
## Problems found in the pattern data during the last generate(), one line per pattern.
var warnings: PackedStringArray = []

var _rng := RandomNumberGenerator.new()
## Track ranges covered by ceiling sections. GDD §3: the floor beneath a ceiling stays clear.
var _hull_spans: Array[Vector2] = []
## Clear stretches between patterns [start, end], filled with credit trails later.
var _clear_stretches: Array[Vector2] = []
var _enemy_count: int = 0


static func load_patterns(path: String) -> Array:
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("patterns"):
		push_error("LevelGenerator: could not read patterns from %s" % path)
		return []
	return parsed["patterns"]


## Every pattern the level can draw from: its main file, then every other .json file in the same
## folder in name order. Patterns declare what they need (`requires`), so a level only ever picks
## the ones its features allow, and adding a pattern file (e.g. one per enemy type) never changes
## levels that don't use it.
static func load_for(p_config: LevelConfig) -> Array:
	var out: Array = load_patterns(p_config.patterns_path)
	var dir: String = p_config.patterns_path.get_base_dir()
	var files: PackedStringArray = DirAccess.get_files_at(dir)
	files.sort()
	for file: String in files:
		var path: String = dir.path_join(file)
		if file.ends_with(".json") and path != p_config.patterns_path:
			out.append_array(load_patterns(path))
	return out


func generate(p_config: LevelConfig, p_tuning: MovementTuning, patterns: Array) -> LevelLayout:
	_rng.seed = p_config.level_seed
	config = p_config
	tuning = p_tuning
	speed = tuning.run_speed
	jump_distance = tuning.jump_distance(speed)
	layout = LevelLayout.new()
	layout.lane_count = config.lane_count
	_hull_spans.clear()
	_clear_stretches.clear()
	_enemy_count = 0
	warnings.clear()
	var accel: float = tuning.speed_gain_per_minute / 60.0
	layout.length = speed * config.duration_seconds + 0.5 * accel * config.duration_seconds * config.duration_seconds

	_clear_stretches.append(Vector2(20.0, config.start_clear_distance))
	var cursor: float = config.start_clear_distance
	while cursor < layout.length - config.end_clear_distance:
		var progress: float = cursor / layout.length
		var difficulty: float = difficulty_at(progress)
		var pattern: Dictionary = _pick_pattern(patterns, difficulty)
		if pattern.is_empty():
			break
		var pattern_start_counts: Dictionary = _counts()
		var used: float = _place_pattern(pattern, cursor)
		if cursor + used > layout.length - config.end_clear_distance:
			_rollback(pattern_start_counts)
			break
		var spacing_seconds: float = lerpf(config.spacing_seconds_easy, config.spacing_seconds_hard, difficulty)
		var clear_end: float = cursor + used + spacing_seconds * speed
		_clear_stretches.append(Vector2(cursor + used, minf(clear_end, layout.length - config.end_clear_distance)))
		cursor = clear_end

	_apply_enemy_rules()
	_place_credits()
	layout.enemies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["at"] < b["at"])
	return layout


## The difficulty at a point of the level (0–1 progress): the level's base plus its ramp.
func difficulty_at(progress: float) -> float:
	return clampf(config.difficulty + config.difficulty_ramp * progress, 0.0, 1.0)


## A random stream for one rule set, independent of the others (enemy rules use this).
func rng_for(rule_name: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([config.level_seed, rule_name])
	return rng


## Adds an enemy entry with a deterministic per-enemy seed. Returns the entry.
func add_enemy(type: String, at: float, lane: int, side: int = 0, params: Dictionary = {}) -> Dictionary:
	var entry := {"type": type, "at": at, "lane": lane, "side": side,
		"seed": hash([config.level_seed, type, _enemy_count]), "params": params}
	_enemy_count += 1
	layout.enemies.append(entry)
	return entry


## Adds a ceiling section with an anti-grav pad at `at` (hull lead-in before it), lasting
## `length_seconds` at run speed. Returns false (adding nothing) if the floor there isn't clear.
func add_hull_with_pad(lane: int, at: float, length_seconds: float) -> bool:
	var hull_start: float = at - config.hull_lead_in
	var hull_end: float = at + length_seconds * speed
	var landing_end: float = hull_end + config.hull_landing_seconds * speed
	if landing_end > layout.length - config.end_clear_distance:
		return false
	if not floor_clear(hull_start - 6.0, landing_end):
		return false
	for h: Dictionary in layout.hulls:
		if hull_start <= h["end"] + 1.0 and hull_end >= h["start"] - 1.0:
			return false
	layout.pads.append({"lane": lane, "at": at})
	layout.hulls.append({"start": hull_start, "end": hull_end})
	_hull_spans.append(Vector2(hull_start, hull_end))
	return true


## True if no gap or fence touches any lane between two track distances.
func floor_clear(from: float, to: float) -> bool:
	for g: Dictionary in layout.gaps:
		if g["start"] <= to and g["end"] >= from:
			return false
	for f: Dictionary in layout.fences:
		if f["at"] >= from and f["at"] <= to:
			return false
	return true


func _pick_pattern(patterns: Array, difficulty: float) -> Dictionary:
	var candidates: Array = []
	var total: float = 0.0
	for p: Dictionary in patterns:
		if difficulty < float(p.get("min_difficulty", 0.0)) or difficulty > float(p.get("max_difficulty", 1.0)):
			continue
		if config.lane_count < int(p.get("min_lanes", 1)):
			continue
		var ok: bool = true
		for need: Variant in p.get("requires", []):
			if not config.has_feature(String(need)):
				ok = false
				break
		if not ok:
			continue
		candidates.append(p)
		total += float(p.get("weight", 1.0))
	if candidates.is_empty():
		return {}
	var roll: float = _rng.randf() * total
	for p: Dictionary in candidates:
		roll -= float(p.get("weight", 1.0))
		if roll <= 0.0:
			return p
	return candidates[-1]


## Places every element of a pattern starting at `origin`. Returns the track length it used.
func _place_pattern(pattern: Dictionary, origin: float) -> float:
	var used: float = float(pattern.get("length", 8.0))
	var prev_lanes: Array[int] = []
	var prev_side: int = 1
	for element: Dictionary in pattern.get("elements", []):
		# "at" is in metres; "at_seconds" scales with run speed (for pieces timed against a hull).
		var at: float = origin + float(element.get("at", 0.0)) + float(element.get("at_seconds", 0.0)) * speed
		match String(element.get("kind", "")):
			"gap":
				var lanes: Array[int] = _pick_lanes(element.get("lanes", {}), prev_lanes)
				var frac: float = minf(float(element.get("jump_frac", 0.5)), config.max_gap_jump_fraction)
				var gap_len: float = frac * jump_distance
				if _under_hull(at, at + gap_len, pattern):
					continue
				for lane: int in lanes:
					layout.gaps.append({"lane": lane, "start": at, "end": at + gap_len})
				used = maxf(used, at - origin + gap_len)
				prev_lanes = lanes
			"fence":
				var lanes: Array[int] = _pick_lanes(element.get("lanes", {}), prev_lanes)
				if _under_hull(at, at, pattern):
					continue
				var pulsing: bool = _rng.randf() < float(element.get("pulse_chance", 0.0))
				for lane: int in lanes:
					layout.fences.append({
						"lane": lane,
						"at": at,
						"variant": String(element.get("variant", "full")),
						"pulsing": pulsing,
						"pulse_on": float(element.get("pulse_on", 1.2)),
						"pulse_off": float(element.get("pulse_off", 1.0)),
						"phase": _rng.randf(),
					})
				prev_lanes = lanes
			"sign":
				var side: int = _pick_side(String(element.get("side", "random")), prev_side)
				var sides: Array[int] = [side]
				if String(element.get("side", "")) == "both":
					sides = [-1, 1]
				var sign_len: float = float(element.get("length", 8.0))
				for s: int in sides:
					layout.signs.append({
						"side": s,
						"start": at,
						"end": at + sign_len,
						"bottom": float(element.get("bottom", 0.0)),
						"top": float(element.get("top", 3.0)),
					})
				used = maxf(used, at - origin + sign_len)
				prev_side = side
			"ramp":
				var side: int = _pick_side(String(element.get("side", "random")), prev_side)
				layout.ramps.append({"side": side, "at": at})
				prev_side = side
			"hull":
				var lanes: Array[int] = _pick_lanes(element.get("lanes", {"mode": "random", "count": 1}), prev_lanes)
				var hull_len: float = float(element.get("length_seconds", 4.0)) * speed
				for lane: int in lanes:
					layout.pads.append({"lane": lane, "at": at})
				layout.hulls.append({"start": at - config.hull_lead_in, "end": at + hull_len})
				_hull_spans.append(Vector2(at - config.hull_lead_in, at + hull_len))
				used = maxf(used, at - origin + hull_len + config.hull_landing_seconds * speed)
				prev_lanes = lanes
			"speed_pad":
				var lanes: Array[int] = _pick_lanes(element.get("lanes", {"mode": "random", "count": 1}), prev_lanes)
				if _under_hull(at, at + tuning.speed_pad_length, pattern):
					continue
				for lane: int in lanes:
					layout.speed_pads.append({"lane": lane, "at": at})
				prev_lanes = lanes
			"enemy":
				var type: String = String(element.get("type", ""))
				var params: Dictionary = element.get("params", {})
				if element.has("side"):
					var side: int = _pick_side(String(element.get("side", "random")), prev_side)
					add_enemy(type, at, layout.outer_lane(side), side, params.duplicate(true))
					prev_side = side
				else:
					var lanes: Array[int] = _pick_lanes(element.get("lanes", {"mode": "random", "count": 1}), prev_lanes)
					if not bool(element.get("allow_under_hull", false)) and _under_hull(at, at, pattern):
						continue
					for lane: int in lanes:
						add_enemy(type, at, lane, 0, params.duplicate(true))
					prev_lanes = lanes
			"credits":
				_place_credit_element(element, at, prev_lanes, prev_side)
			_:
				push_warning("LevelGenerator: unknown element kind in pattern %s" % pattern.get("id", "?"))
	return used


## True (noting a warning about the pattern data) if a floor piece would sit under a ceiling.
func _under_hull(start: float, end: float, pattern: Dictionary) -> bool:
	for span: Vector2 in _hull_spans:
		if start <= span.y and end >= span.x:
			var line: String = "pattern '%s' puts a floor piece under a ceiling; skipped" % pattern.get("id", "?")
			if not warnings.has(line):
				warnings.append(line)
			return true
	return false


## Size of every piece list, so a pattern that doesn't fit can be taken back out.
func _counts() -> Dictionary:
	return {"gaps": layout.gaps.size(), "fences": layout.fences.size(), "signs": layout.signs.size(),
		"hulls": layout.hulls.size(), "pads": layout.pads.size(), "ramps": layout.ramps.size(),
		"speed_pads": layout.speed_pads.size(), "enemies": layout.enemies.size(),
		"credits": layout.credits.size(), "hull_spans": _hull_spans.size()}


func _rollback(counts: Dictionary) -> void:
	layout.gaps.resize(counts["gaps"])
	layout.fences.resize(counts["fences"])
	layout.signs.resize(counts["signs"])
	layout.hulls.resize(counts["hulls"])
	layout.pads.resize(counts["pads"])
	layout.ramps.resize(counts["ramps"])
	layout.speed_pads.resize(counts["speed_pads"])
	layout.enemies.resize(counts["enemies"])
	layout.credits.resize(counts["credits"])
	_hull_spans.resize(counts["hull_spans"])


## Lane selector modes: all, all_but (count|frac), random (count|frac), edge, center, same, others.
## "same" reuses the previous element's lanes; "others" is every lane the previous element didn't use.
func _pick_lanes(selector: Dictionary, prev_lanes: Array[int]) -> Array[int]:
	var n: int = layout.lane_count
	var all: Array[int] = []
	for i: int in n:
		all.append(i)
	var mode: String = String(selector.get("mode", "random"))
	match mode:
		"all":
			return all
		"same":
			return prev_lanes.duplicate()
		"others":
			var rest: Array[int] = []
			for i: int in all:
				if not prev_lanes.has(i):
					rest.append(i)
			return rest
		"edge":
			var edge: Array[int] = [0 if _rng.randf() < 0.5 else n - 1]
			return edge
		"center":
			var center: Array[int] = [n / 2]
			return center
		"all_but":
			var keep_free: int = clampi(_count(selector, n), 1, n - 1)
			var picked: Array[int] = _shuffled(all)
			return _sorted(picked.slice(keep_free))
		_:
			var count: int = clampi(_count(selector, n), 1, n)
			var picked: Array[int] = _shuffled(all)
			return _sorted(picked.slice(0, count))


func _count(selector: Dictionary, n: int) -> int:
	if selector.has("frac"):
		return maxi(1, roundi(float(selector["frac"]) * n))
	return int(selector.get("count", 1))


func _pick_side(spec: String, prev_side: int) -> int:
	match spec:
		"left":
			return -1
		"right":
			return 1
		"same":
			return prev_side
		_:
			return -1 if _rng.randf() < 0.5 else 1


func _shuffled(values: Array[int]) -> Array[int]:
	var out: Array[int] = values.duplicate()
	for i: int in range(out.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: int = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


func _sorted(values: Array[int]) -> Array[int]:
	var out: Array[int] = values.duplicate()
	out.sort()
	return out


# --- Enemy rules ---------------------------------------------------------------

func _apply_enemy_rules() -> void:
	for feature: String in config.features:
		var path: String = RULES_DIR.path_join("%s_rules.gd" % feature)
		if not ResourceLoader.exists(path):
			continue
		var script := load(path) as GDScript
		if script != null and script.has_method("apply"):
			script.call("apply", self)


# --- Credits (GDD §7) ------------------------------------------------------------

## Credits a pattern places explicitly: {kind: "credits", surface: "floor" | "ceiling" | "wall",
## lanes | side, count, spacing, value, height}.
func _place_credit_element(element: Dictionary, at: float, prev_lanes: Array[int], prev_side: int) -> void:
	var surface: String = String(element.get("surface", "floor"))
	var count: int = int(element.get("count", 5))
	var spacing: float = float(element.get("spacing", config.credit_trail_spacing))
	var value: int = int(element.get("value", 1))
	var height: float = float(element.get("height", 0.7 if surface != "wall" else 2.0))
	if surface == "wall":
		var side: int = _pick_side(String(element.get("side", "same")), prev_side)
		for i: int in count:
			_add_credit(at + i * spacing, "wall", layout.outer_lane(side), side, height, value)
		return
	var lanes: Array[int] = _pick_lanes(element.get("lanes", {"mode": "same"}), prev_lanes)
	if lanes.is_empty():
		lanes = _pick_lanes({"mode": "random", "count": 1}, prev_lanes)
	for lane: int in lanes:
		for i: int in count:
			_add_credit(at + i * spacing, surface, lane, 0, height, value)


func _add_credit(at: float, surface: String, lane: int, side: int, height: float, value: int,
		risky: bool = false) -> void:
	layout.credits.append({"at": at, "surface": surface, "lane": lane, "side": side,
		"height": height, "value": value, "risky": risky})


func _place_credits() -> void:
	var rng: RandomNumberGenerator = rng_for("credits")
	_place_trails(rng)
	_place_gap_credits(rng)
	_place_fence_credits(rng)
	if config.credit_wall_runs:
		_place_wall_run_credits()
	if config.credit_ceilings:
		_place_ceiling_credits(rng)
	_drop_unsafe_credits()
	layout.credits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["at"] < b["at"])


## Trails of small credits along one lane in the clear stretches between patterns, sometimes
## shifting one lane halfway so the player has to move.
func _place_trails(rng: RandomNumberGenerator) -> void:
	var n: int = layout.lane_count
	var trail_len: float = (config.credit_trail_count - 1) * config.credit_trail_spacing
	for stretch: Vector2 in _clear_stretches:
		if stretch.y - stretch.x < trail_len + 6.0 or rng.randf() >= config.credit_trail_chance:
			continue
		if config.credit_trail_count <= 0:
			continue
		var lane: int = rng.randi_range(0, n - 1)
		var shift: int = 0
		if rng.randf() < 0.35:
			shift = -1 if lane == n - 1 else (1 if lane == 0 else (-1 if rng.randf() < 0.5 else 1))
		var start: float = (stretch.x + stretch.y) * 0.5 - trail_len * 0.5
		for i: int in config.credit_trail_count:
			var l: int = lane + (shift if i >= config.credit_trail_count / 2 else 0)
			var d: float = start + i * config.credit_trail_spacing
			if layout.under_hull(d):
				continue
			_add_credit(d, "floor", l, 0, 0.7, 1)


## A richer credit right at a gap's edge and an arc of credits along the jump over it.
func _place_gap_credits(rng: RandomNumberGenerator) -> void:
	var done: Dictionary = {}
	for g: Dictionary in layout.gaps:
		var key: String = "%.1f" % float(g["start"])
		if done.has(key) or rng.randf() >= config.credit_gap_chance:
			continue
		done[key] = true
		var lane: int = g["lane"]
		var gap_len: float = g["end"] - g["start"]
		_add_credit(g["start"] - 0.8, "floor", lane, 0, 0.6, 5, true)
		# A jump centred on the gap: takeoff before it, landing after it.
		var takeoff: float = g["start"] - (jump_distance - gap_len) * 0.5
		for i: int in 5:
			var f: float = 0.2 + 0.15 * i
			_add_credit(takeoff + f * jump_distance, "floor", lane, 0, _jump_height_at(f) + 0.5, 1, true)


## A richer credit in a fence's risky spot: above a full fence (reached by jumping it), under a
## gapped one (reached by sliding).
func _place_fence_credits(rng: RandomNumberGenerator) -> void:
	for f: Dictionary in layout.fences:
		if rng.randf() >= config.credit_fence_chance:
			continue
		var gapped: bool = f["variant"] == "gapped"
		var height: float = 0.25 if gapped else tuning.fence_full_top + 0.6
		_add_credit(f["at"], "floor", f["lane"], 0, height, 5, true)


## Credits along the wall-run path after each ramp, richer the further along (GDD §7).
func _place_wall_run_credits() -> void:
	var values: Array[int] = [1, 1, 5, 5, 5, 25]
	for r: Dictionary in layout.ramps:
		var side: int = r["side"]
		var entry_d: float = float(r["at"]) + 0.5 + speed * tuning.wall_entry_time
		var h0: float = minf(tuning.ramp_entry_height, tuning.wall_max_height)
		for i: int in values.size():
			var t: float = 0.3 * (i + 1)
			var s: float = clampf(t / tuning.wall_slide_time, 0.0, 1.0)
			var h: float = tuning.wall_exit_height + (h0 - tuning.wall_exit_height) * (1.0 - pow(s, tuning.wall_descent_exponent))
			var d: float = entry_d + speed * t
			if _sign_near(side, d, 1.5):
				break
			_add_credit(d, "wall", layout.outer_lane(side), side, h, values[i], true)


## A line of credits along the pad's lane on the ceiling and a rich one in the far lane.
func _place_ceiling_credits(rng: RandomNumberGenerator) -> void:
	for p: Dictionary in layout.pads:
		var hull: Dictionary = {}
		for h: Dictionary in layout.hulls:
			if h["start"] <= p["at"] and h["end"] >= p["at"]:
				hull = h
		if hull.is_empty():
			continue
		var lane: int = p["lane"]
		var d: float = float(p["at"]) + 10.0
		var placed: int = 0
		while d < float(hull["end"]) - 8.0 and placed < 10:
			_add_credit(d, "ceiling", lane, 0, 0.6, 1)
			d += 4.0
			placed += 1
		if layout.lane_count > 1:
			var far_lane: int = 0 if lane >= layout.lane_count / 2 else layout.lane_count - 1
			var far_d: float = lerpf(float(p["at"]), float(hull["end"]), 0.7)
			_add_credit(far_d, "ceiling", far_lane, 0, 0.6, 25 if rng.randf() < 0.7 else 5, true)


## Drops credits that would sit inside a hazard or over a hole the player can't reach.
func _drop_unsafe_credits() -> void:
	var kept: Array[Dictionary] = []
	for c: Dictionary in layout.credits:
		if c["surface"] == "floor":
			var d: float = c["at"]
			var lane: int = c["lane"]
			if lane < 0 or lane >= layout.lane_count:
				continue
			if not c["risky"] and layout.gapped_between(lane, d - 0.5, d + 0.5):
				continue
			if not c["risky"] and _fence_near(lane, d, 1.5):
				continue
			if d > layout.length - 5.0:
				continue
		elif c["surface"] == "wall":
			if _sign_near(c["side"], c["at"], 1.0):
				continue
		kept.append(c)
	layout.credits = kept


func _fence_near(lane: int, d: float, margin: float) -> bool:
	for f: Dictionary in layout.fences:
		if f["lane"] == lane and absf(f["at"] - d) < margin:
			return true
	return false


func _sign_near(side: int, d: float, margin: float) -> bool:
	for s: Dictionary in layout.signs:
		if s["side"] == side and d >= s["start"] - margin and d <= s["end"] + margin:
			return true
	return false


## Height of a jump from flat ground at fraction `f` (0–1) of its horizontal length.
func _jump_height_at(f: float) -> float:
	var g_up: float = tuning.gravity()
	var g_down: float = g_up * tuning.fall_gravity_multiplier
	var t_up: float = tuning.jump_velocity() / g_up
	var t_down: float = sqrt(2.0 * tuning.jump_height / g_down)
	var t: float = f * (t_up + t_down)
	if t <= t_up:
		return tuning.jump_velocity() * t - 0.5 * g_up * t * t
	var td: float = t - t_up
	return maxf(tuning.jump_height - 0.5 * g_down * td * td, 0.0)

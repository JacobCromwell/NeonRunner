class_name LevelGenerator
extends RefCounted
## Rule-based level generator: data-driven patterns + a difficulty value + a seed.
## Works for any lane count. Never refers to zone skins (trucks, streets, ...).
## Pattern format is documented in data/patterns/README.md.

## Fairness rules (longest gap, hull lead-in and landing) come from LevelConfig, so they are data.

var _rng := RandomNumberGenerator.new()
var _layout: LevelLayout
var _config: LevelConfig
var _tuning: MovementTuning
var _speed: float
var _jump_distance: float
## Track ranges covered by ceiling sections. GDD §3: the floor beneath a ceiling stays clear.
var _hull_spans: Array[Vector2] = []
## Problems found in the pattern data during the last generate(), one line per pattern.
var warnings: PackedStringArray = []


static func load_patterns(path: String) -> Array:
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("patterns"):
		push_error("LevelGenerator: could not read patterns from %s" % path)
		return []
	return parsed["patterns"]


func generate(config: LevelConfig, tuning: MovementTuning, patterns: Array) -> LevelLayout:
	_rng.seed = config.level_seed
	_config = config
	_tuning = tuning
	_speed = tuning.run_speed
	_jump_distance = tuning.jump_distance(_speed)
	_layout = LevelLayout.new()
	_layout.lane_count = config.lane_count
	_hull_spans.clear()
	warnings.clear()
	var accel: float = tuning.speed_gain_per_minute / 60.0
	_layout.length = _speed * config.duration_seconds + 0.5 * accel * config.duration_seconds * config.duration_seconds

	var cursor: float = config.start_clear_distance
	while cursor < _layout.length - config.end_clear_distance:
		var progress: float = cursor / _layout.length
		var difficulty: float = clampf(config.difficulty + config.difficulty_ramp * progress, 0.0, 1.0)
		var pattern: Dictionary = _pick_pattern(patterns, difficulty, config)
		if pattern.is_empty():
			break
		var pattern_start_counts: Dictionary = _counts()
		var used: float = _place_pattern(pattern, cursor)
		if cursor + used > _layout.length - config.end_clear_distance:
			_rollback(pattern_start_counts)
			break
		var spacing_seconds: float = lerpf(config.spacing_seconds_easy, config.spacing_seconds_hard, difficulty)
		cursor += used + spacing_seconds * _speed
	return _layout


func _pick_pattern(patterns: Array, difficulty: float, config: LevelConfig) -> Dictionary:
	var candidates: Array = []
	var total: float = 0.0
	for p: Dictionary in patterns:
		if difficulty < float(p.get("min_difficulty", 0.0)) or difficulty > float(p.get("max_difficulty", 1.0)):
			continue
		if config.lane_count < int(p.get("min_lanes", 1)):
			continue
		var needs: Array = p.get("requires", [])
		if needs.has("ramps") and not config.ramps_enabled:
			continue
		if needs.has("ceilings") and not config.ceilings_enabled:
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
		var at: float = origin + float(element.get("at", 0.0)) + float(element.get("at_seconds", 0.0)) * _speed
		match String(element.get("kind", "")):
			"gap":
				var lanes: Array[int] = _pick_lanes(element.get("lanes", {}), prev_lanes)
				var frac: float = minf(float(element.get("jump_frac", 0.5)), _config.max_gap_jump_fraction)
				var gap_len: float = frac * _jump_distance
				if _under_hull(at, at + gap_len, pattern):
					continue
				for lane: int in lanes:
					_layout.gaps.append({"lane": lane, "start": at, "end": at + gap_len})
				used = maxf(used, at - origin + gap_len)
				prev_lanes = lanes
			"fence":
				var lanes: Array[int] = _pick_lanes(element.get("lanes", {}), prev_lanes)
				if _under_hull(at, at, pattern):
					continue
				var pulsing: bool = _rng.randf() < float(element.get("pulse_chance", 0.0))
				for lane: int in lanes:
					_layout.fences.append({
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
					_layout.signs.append({
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
				_layout.ramps.append({"side": side, "at": at})
				prev_side = side
			"hull":
				var lanes: Array[int] = _pick_lanes(element.get("lanes", {"mode": "random", "count": 1}), prev_lanes)
				var hull_len: float = float(element.get("length_seconds", 4.0)) * _speed
				for lane: int in lanes:
					_layout.pads.append({"lane": lane, "at": at})
				_layout.hulls.append({"start": at - _config.hull_lead_in, "end": at + hull_len})
				_hull_spans.append(Vector2(at - _config.hull_lead_in, at + hull_len))
				used = maxf(used, at - origin + hull_len + _config.hull_landing_seconds * _speed)
				prev_lanes = lanes
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
	return {"gaps": _layout.gaps.size(), "fences": _layout.fences.size(), "signs": _layout.signs.size(),
		"hulls": _layout.hulls.size(), "pads": _layout.pads.size(), "ramps": _layout.ramps.size()}


func _rollback(counts: Dictionary) -> void:
	_layout.gaps.resize(counts["gaps"])
	_layout.fences.resize(counts["fences"])
	_layout.signs.resize(counts["signs"])
	_layout.hulls.resize(counts["hulls"])
	_layout.pads.resize(counts["pads"])
	_layout.ramps.resize(counts["ramps"])


## Lane selector modes: all, all_but (count|frac), random (count|frac), edge, center, same, others.
## "same" reuses the previous element's lanes; "others" is every lane the previous element didn't use.
func _pick_lanes(selector: Dictionary, prev_lanes: Array[int]) -> Array[int]:
	var n: int = _layout.lane_count
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

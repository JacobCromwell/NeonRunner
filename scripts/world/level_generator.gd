class_name LevelGenerator
extends RefCounted
## Rule-based level generator: data-driven patterns + a difficulty value + a seed.
## Works for any lane count. Never refers to zone skins (trucks, streets, ...).
## Pattern format is documented in data/patterns/README.md.
##
## Passes, each with its own random stream so adding one never reshuffles the others:
## 1. Patterns (obstacles and enemies) from the pattern files, filtered by the level's features.
##    A feature that starts partway into the level (LevelConfig.feature_starts) is left out before
##    its start, and the first pattern picked from there uses it (its introduction).
## 2. Enemy rules: for every feature with a script at res://scripts/enemies/<feature>_rules.gd,
##    its static `apply(gen: LevelGenerator)` runs (e.g. drone anti-grav pad schedules). Rules that
##    add a feature's enemies or pieces keep them after its start (feature_active, feature_share_at).
## 3. Credits (GDD §7): trails in the clear stretches, rich credits in risky spots.
## Fairness rules (longest gap, hull lead-in and landing) come from LevelConfig, so they are data.
##
## Ceilings (GDD §3, changed September 26, 2026): the floor under a ceiling may be dangerous, since the
## ceiling is the way to escape it: a pattern may put gaps, fences and enemies under its own ceiling
## (a gauntlet), and a ceiling a rule adds (add_hull_with_pad, PadPlacement) lies over whatever the
## floor holds there. Two stretches stay safe around every ceiling (CeilingZones, `zones`): its
## landing zone, and the spot of each of its pads. The ceiling is never required: the floor under it
## holds only what patterns put there, with their usual fairness and spacing, and the pad can always
## be passed by.
##
## Every feature appears (LevelConfig.guarantee_features; GDD §5: anything introduced earlier keeps
## appearing later): after the passes, the generator checks that each feature a pattern can place
## in the level is in the finished layout (feature_positions). Rules may have dropped what didn't
## fit or cleared it for a guarantee of their own, so for each one missing it builds the level again
## with picks of that feature forced somewhere else (GUARANTEE_SHARES; more of them each time it's
## missed, GUARANTEE_MAX_PICKS), until none is missing. Each build runs every pass and rule
## unchanged, so the guarantee never bends a fairness rule. Rules that hold the room for their
## feature themselves may add one where it fits when none is left (the host and Octodog rules),
## which saves a build.
##
## Beyond that guarantee, a campaign level's newest things get the most picks (GDD §5, owner's review
## P2 13): with the campaign's recency curve (LevelConfig.feature_recency and feature_ages), each
## pattern's pick weight follows how recently the campaign introduced its newest feature, and the
## curve only moves picks between the level's features (FeatureRecency.keep_feature_share).
##
## A level may alternate long quiet stretches with short, dense bursts (LevelConfig.quiet_seconds;
## GDD §5, The Hush): quiet stretches pick sparse patterns without enemies (bar quiet_features), bursts
## pick threats, densely. Every rule, fairness check and the guarantee apply to it unchanged, and a
## burst takes at most one introduction, so it never stacks two new things.

const DENOMINATIONS: Array[int] = [1, 5, 25, 100]
const RULES_DIR: String = "res://scripts/enemies"
## The most builds generate() makes to have every feature appear (guarantee_features). Past it the
## level keeps the build that missed the fewest, with a warning.
const GUARANTEE_ATTEMPTS: int = 16
## Where a new build forces a pick of a feature the last one missed: a share of the stretch where
## the feature is active (from its start to the level's end), a new one each time it's missed. The
## early shares come before most drone waves, whose pad schedule clears the floor after them; none
## is so late that a long pattern couldn't fit before the end.
const GUARANTEE_SHARES: Array[float] = [0.3, 0.0, 0.55, 0.12, 0.4, 0.05, 0.7, 0.2, 0.02, 0.48, 0.08,
	0.62, 0.25, 0.15, 0.35, 0.78]
## A feature missed again gets more forced picks in the next build (one per miss, up to this many),
## spread over its stretch, so one that rarely survives (a floor enemy where the drone's pads clear
## the floor) gets several chances in a build.
const GUARANTEE_MAX_PICKS: int = 3

var layout: LevelLayout
var config: LevelConfig
var tuning: MovementTuning
## Run speed the level is built for, and a full jump's length at that speed.
var speed: float
var jump_distance: float
## Problems found in the pattern data during the last generate(), one line per pattern.
var warnings: PackedStringArray = []
## How many builds the last generate() made: 1, unless guarantee_features had to force a missing
## feature somewhere.
var attempts: int = 0
## The floor every ceiling keeps safe (GDD §3): its landing zone and its pads' spots, for this level's
## pacing and run speed. Rules that add ceilings or floor enemies keep to it.
var zones: CeilingZones
## The patterns the pattern pass of the last build placed, in order: {id, requires, at, used, due}
## (`used`: the track it took; `due`: an introduction or one of the guarantee's forced picks). For
## tests and the level report.
var picks: Array[Dictionary] = []

var _rng := RandomNumberGenerator.new()
## Clear stretches between patterns [start, end], filled with credit trails later.
var _clear_stretches: Array[Vector2] = []
var _enemy_count: int = 0
## Picks that must use a feature once the cursor reaches their spot, earliest first: {feature, at,
## intro}. A feature's introduction at its start (LevelConfig.feature_starts; `intro`), and the
## guarantee's forced picks (_pick_due).
var _due: Array[Dictionary] = []
## In a level paced in bursts, the burst (burst_index) that has had its introduction; -1 for none.
var _intro_burst: int = -1


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
	config = p_config
	tuning = p_tuning
	speed = tuning.run_speed
	jump_distance = tuning.jump_distance(speed)
	zones = CeilingZones.make(config, tuning, speed)
	attempts = 1
	if not config.guarantee_features:
		return _build(patterns, {})
	# Each feature missing from a build gets a pick forced at a new spot in the next one
	# (GUARANTEE_SHARES); a feature that appeared keeps the spot that worked.
	var needed: PackedStringArray = []
	var forced: Dictionary = {}
	var best: Dictionary = {}
	var best_missing: PackedStringArray = []
	for attempt: int in GUARANTEE_ATTEMPTS:
		attempts = attempt + 1
		_build(patterns, forced)
		if attempt == 0:
			needed = placeable_features(patterns)
		var missing: PackedStringArray = missing_features(needed)
		if missing.is_empty():
			return layout
		if attempt == 0 or missing.size() < best_missing.size():
			best = forced.duplicate()
			best_missing = missing
		for feature: String in missing:
			forced[feature] = int(forced.get(feature, 0)) + 1
	_build(patterns, best)
	warnings.append("guarantee: after %d builds the level still has no %s (every feature should appear, GDD §5)"
		% [GUARANTEE_ATTEMPTS, ", ".join(best_missing)])
	return layout


## One build of the level: the pattern pass (with the introductions and the guarantee's forced
## picks, `forced`: feature → how many builds missed it), the rules, the credits.
func _build(patterns: Array, forced: Dictionary) -> LevelLayout:
	_rng.seed = config.level_seed
	layout = LevelLayout.new()
	layout.lane_count = config.lane_count
	_clear_stretches.clear()
	_enemy_count = 0
	warnings.clear()
	picks.clear()
	_intro_burst = -1
	var accel: float = tuning.speed_gain_per_minute / 60.0
	layout.length = speed * config.duration_seconds + 0.5 * accel * config.duration_seconds * config.duration_seconds
	_due = _due_picks(forced)

	_clear_stretches.append(Vector2(20.0, config.start_clear_distance))
	var cursor: float = config.start_clear_distance
	while cursor < layout.length - config.end_clear_distance:
		var progress: float = cursor / layout.length
		var difficulty: float = difficulty_at(progress)
		var pattern: Dictionary = _pick_due(patterns, difficulty, cursor)
		var due: bool = not pattern.is_empty()
		if pattern.is_empty():
			pattern = _pick_pattern(patterns, difficulty, cursor)
		if pattern.is_empty():
			break
		var pattern_start_counts: Dictionary = _counts()
		var used: float = _place_pattern(pattern, cursor)
		if cursor + used > layout.length - config.end_clear_distance:
			_rollback(pattern_start_counts)
			break
		if layout.hulls.size() > int(pattern_start_counts["hulls"]):
			_secure_ceilings(pattern, pattern_start_counts)
		_settle_due(pattern, cursor)
		picks.append({"id": String(pattern.get("id", "?")), "requires": pattern.get("requires", []), "at": cursor,
			"used": used, "due": due})
		var end: float = cursor + used
		var clear_end: float = end + _spacing_seconds(end, difficulty) * speed
		if config.paced_in_bursts() and quiet_at(end):
			# A quiet stretch's long spacing never carries the cursor far past the next burst's start: the
			# burst begins on time, after the burst spacing at least.
			clear_end = maxf(minf(clear_end, stretch_end(end)), end + config.burst_spacing_seconds * speed)
		_clear_stretches.append(Vector2(end, minf(clear_end, layout.length - config.end_clear_distance)))
		cursor = clear_end

	_apply_enemy_rules()
	_place_credits()
	layout.enemies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["at"] < b["at"])
	return layout


## The difficulty at a point of the level (0–1 progress): the level's base plus its ramp.
func difficulty_at(progress: float) -> float:
	return clampf(config.difficulty + config.difficulty_ramp * progress, 0.0, 1.0)


# --- Quiet stretches and bursts (LevelConfig.quiet_seconds; GDD §5, The Hush) --------------------

## True if track distance `at` lies in one of the level's quiet stretches: from the level's first
## pattern (start_clear_distance) on, quiet_seconds at run speed, then burst_seconds of burst, and
## again. The run-up counts as quiet. Always false in a level paced evenly.
func quiet_at(at: float) -> bool:
	if not config.paced_in_bursts():
		return false
	if at < config.start_clear_distance:
		return true
	return fposmod(at - config.start_clear_distance, _pacing_cycle()) < config.quiet_seconds * speed


## The track distance where the quiet stretch or the burst holding `at` ends (INF in a level paced
## evenly).
func stretch_end(at: float) -> float:
	if not config.paced_in_bursts():
		return INF
	var from: float = config.start_clear_distance
	var cycle: float = _pacing_cycle()
	var start: float = from + floorf(maxf(at - from, 0.0) / cycle) * cycle
	var quiet_end: float = start + config.quiet_seconds * speed
	return quiet_end if at < quiet_end else start + cycle


## Which burst track distance `at` is in (0 = the level's first); -1 in a quiet stretch or a level
## paced evenly.
func burst_index(at: float) -> int:
	if not config.paced_in_bursts() or quiet_at(at):
		return -1
	return floori((at - config.start_clear_distance) / _pacing_cycle())


## The level's quiet stretches [start, end] up to its end-clear stretch, in order (none in a level
## paced evenly). Bursts are what lies between them.
func quiet_stretches() -> Array[Vector2]:
	var out: Array[Vector2] = []
	if not config.paced_in_bursts():
		return out
	var last: float = layout.length - config.end_clear_distance
	var at: float = config.start_clear_distance
	while at < last:
		out.append(Vector2(at, minf(at + config.quiet_seconds * speed, last)))
		at += _pacing_cycle()
	return out


func _pacing_cycle() -> float:
	return maxf((config.quiet_seconds + config.burst_seconds) * speed, 1.0)


## Seconds of clear track after a pattern that ends at `at`: the level's spacing for its difficulty,
## or in a level paced in bursts the quiet or the burst spacing there.
func _spacing_seconds(at: float, difficulty: float) -> float:
	if config.paced_in_bursts():
		return config.quiet_spacing_seconds if quiet_at(at) else config.burst_spacing_seconds
	return lerpf(config.spacing_seconds_easy, config.spacing_seconds_hard, difficulty)


## Track distances [from, to] within `lo`–`hi` that lie in bursts, in order: where a rule that
## guarantees an enemy at a spot of its choosing puts it in a level paced in bursts (the threats come
## in the bursts; GDD §5, The Hush). Empty in a level paced evenly.
func burst_spans(lo: float, hi: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if not config.paced_in_bursts():
		return out
	var from: float = config.start_clear_distance + config.quiet_seconds * speed
	while from <= hi:
		var span := Vector2(maxf(from, lo), minf(from + config.burst_seconds * speed, hi))
		if span.y >= span.x:
			out.append(span)
		from += _pacing_cycle()
	return out


## True if a rule that guarantees one of `feature`'s enemies should put it in a burst: in a level
## paced in bursts, for every feature but its quiet_features.
func prefers_bursts(feature: String) -> bool:
	return config.paced_in_bursts() and not config.quiet_features.has(feature)


## For a rule guaranteeing one of `feature`'s enemies at one of `spots`: the spots to try first and
## the rest, in that order. In a level paced in bursts, those in a burst come first (prefers_bursts),
## or for one of its quiet_features those in a quiet stretch; in a level paced evenly, just `spots`.
func pacing_pools(spots: Array[float], feature: String) -> Array[Array]:
	if not config.paced_in_bursts():
		return [spots]
	var first: Array[float] = []
	var rest: Array[float] = []
	var quiet_feature: bool = config.quiet_features.has(feature)
	for s: float in spots:
		if quiet_at(s) == quiet_feature:
			first.append(s)
		else:
			rest.append(s)
	return [first, rest]


## For a rule guaranteeing one of `feature`'s enemies (prefers_bursts): a spot drawn with `rng` from
## the bursts within `lo`–`hi` (each metre of burst equally likely). NAN, drawing nothing, when the
## feature needn't be in a burst or no burst lies there: the rule then picks its spot as usual.
func burst_spot(rng: RandomNumberGenerator, lo: float, hi: float, feature: String) -> float:
	if not prefers_bursts(feature):
		return NAN
	var spans: Array[Vector2] = burst_spans(lo, hi)
	var total: float = 0.0
	for s: Vector2 in spans:
		total += s.y - s.x
	if spans.is_empty():
		return NAN
	var r: float = rng.randf() * total
	for s: Vector2 in spans:
		if r <= s.y - s.x:
			return s.x + r
		r -= s.y - s.x
	return spans[-1].y


## True if `pattern` may be picked at `at` in a level paced in bursts (GDD §5, The Hush: long silent
## stretches broken by sudden threats):
## - a pattern that places enemies and requires only quiet_features belongs to the quiet stretches:
##   it must start in one and place its enemies before it ends (The Hush's hosts stand alone in the
##   silence); any other that places enemies must start in a burst and place its enemies before that
##   burst ends, so a burst's threats appear in the burst (an Octodog's charges or a hover truck's
##   stay may still run on after it);
## - a burst takes only threats: patterns with a hole, a fence, a sign or an enemy. Safe mechanics
##   alone (a plain ceiling, a ramp, a speed pad) go in the quiet stretches, with sparse obstacles.
func _pacing_allows(pattern: Dictionary, at: float) -> bool:
	var last_enemy: float = -1.0
	var threat: bool = false
	for element: Dictionary in pattern.get("elements", []):
		var kind: String = String(element.get("kind", ""))
		if kind == "enemy":
			last_enemy = maxf(last_enemy, float(element.get("at", 0.0)) + float(element.get("at_seconds", 0.0)) * speed)
		threat = threat or kind in ["gap", "fence", "sign", "enemy"]
	var quiet: bool = quiet_at(at)
	if not quiet and not threat:
		return false
	if last_enemy < 0.0:
		return true
	var requires: Array = pattern.get("requires", [])
	var quiet_ok: bool = not requires.is_empty()
	for need: Variant in requires:
		if not config.quiet_features.has(String(need)):
			quiet_ok = false
			break
	return quiet == quiet_ok and at + last_enemy < stretch_end(at)


## Track distance from which `feature` may place anything: its share of the level from
## LevelConfig.feature_starts, or 0 for features that are there from the start.
func feature_start(feature: String) -> float:
	return config.feature_start(feature) * layout.length


## True if track distance `at` is at or past `feature`'s start (always, for a feature that starts
## with the level), whether or not the level has the feature.
func feature_started(feature: String, at: float) -> bool:
	return at >= feature_start(feature) - 0.001


## True if the level has `feature` and it has started by track distance `at`. Patterns are picked,
## and rules scripts add a feature's enemies or pieces (a drone's anti-grav pads are the `ceilings`
## feature's, a hover truck's ramp the `ramps` feature's), only where this holds.
func feature_active(feature: String, at: float) -> bool:
	return config.has_feature(feature) and feature_started(feature, at)


## Track distance `share` (0–1) of the way through the stretch where `feature` is active, from its
## start to the level's end: for rules that pick a spot as a share of the level (a guaranteed drone
## wave or hover truck), so a late feature's spot still falls after its start. Without a start it's
## simply `share` of the level.
func feature_share_at(feature: String, share: float) -> float:
	var from: float = feature_start(feature)
	return from + (layout.length - from) * share


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


## Adds a ceiling section with an anti-grav pad at `at` in `lane` (hull lead-in before it), lasting
## `length_seconds` at run speed, over whatever the floor holds there (GDD §3: the floor under a
## ceiling may be dangerous). Returns false (adding nothing) if the pad can't be stepped on or its
## landing zone isn't safe to land on (CeilingZones: pad_clear, landing_clear, which include floor
## enemies' stretches), it would touch another ceiling, its landing doesn't end before the level's
## end-clear stretch, or the level's ceilings haven't started by `at` (a late `ceilings` feature,
## feature_started). PadPlacement clears the way first.
func add_hull_with_pad(lane: int, at: float, length_seconds: float) -> bool:
	if not feature_started("ceilings", at):
		return false
	var hull := {"start": at - config.hull_lead_in, "end": at + length_seconds * speed}
	var landing: Vector2 = zones.landing_zone(hull)
	if landing.y > layout.length - config.end_clear_distance:
		return false
	if not zones.pad_clear(layout, lane, at) or not zones.landing_clear(layout, landing):
		return false
	for h: Dictionary in layout.hulls:
		if float(hull["start"]) <= float(h["end"]) + 1.0 and float(hull["end"]) >= float(h["start"]) - 1.0:
			return false
	layout.pads.append({"lane": lane, "at": at})
	layout.hulls.append(hull)
	return true


## True if nothing on the floor touches any lane between two track distances: no gap, no fence,
## and no floor enemy's stretch (enemy_floor_span).
func floor_clear(from: float, to: float) -> bool:
	for g: Dictionary in layout.gaps:
		if g["start"] <= to and g["end"] >= from:
			return false
	for f: Dictionary in layout.fences:
		if f["at"] >= from and f["at"] <= to:
			return false
	for e: Dictionary in layout.enemies:
		var span: Vector2 = enemy_floor_span(e)
		if span.x <= to and span.y >= from:
			return false
	return true


## The stretch of floor [start, end] an enemy entry uses, which a ceiling's landing zone and the
## spots of its pads keep off (CeilingZones): its params.floor_span if its rules planned one, else
## its tuning's reach around its position. Vector2(INF, -INF) (overlapping nothing) for types whose
## tuning says they don't use the floor.
static func enemy_floor_span(entry: Dictionary) -> Vector2:
	var params: Dictionary = entry.get("params", {})
	if params.get("floor_span") is Vector2:
		return params["floor_span"]
	var at: float = float(entry["at"])
	var t := EnemyDirector.tuning_for(String(entry.get("type", ""))) as EnemyTuning
	if t == null:
		return Vector2(at - 10.0, at + 10.0)
	if not t.uses_floor:
		return Vector2(INF, -INF)
	return Vector2(at - t.floor_reach_before, at + t.floor_reach_after)


## False for enemy types whose tuning says they never come down to the floor lanes (fliers such as
## drones and hover trucks, wall-only enemies such as window cyborgs). Unknown types use the floor.
## A hover truck keeps its lane free of the others (HoverTruckRules).
static func enemy_uses_floor(entry: Dictionary) -> bool:
	var t := EnemyDirector.tuning_for(String(entry.get("type", ""))) as EnemyTuning
	return t == null or t.uses_floor


## The wall run that ramp `r` (a layout.ramps entry) launches the player into at this level's run
## speed: where they are on the wall, how high and how fast, with the ramp's fading speed boost
## (RampLaunch, GDD §3). Every rule that predicts a ramp's wall run asks it: the credits along it
## (wall_run_credits), and a rule that must keep a wall hazard out of a ramp's launch (task B5: never a
## live wall fence where a ramp launches the player into it).
func ramp_launch(r: Dictionary) -> RampLaunch:
	return RampLaunch.of(r, tuning, speed)


## A weighted random pick among the patterns that fit at track distance `at` (pick_weights). Returns
## {} (without drawing a random number) when none fits.
func _pick_pattern(patterns: Array, difficulty: float, at: float, only: String = "") -> Dictionary:
	var pool: Dictionary = pick_weights(patterns, difficulty, at, only)
	var candidates: Array = pool["patterns"]
	var weights: Array[float] = pool["weights"]
	if candidates.is_empty():
		return {}
	var total: float = 0.0
	for w: float in weights:
		total += w
	var roll: float = _rng.randf() * total
	for i: int in candidates.size():
		roll -= weights[i]
		if roll <= 0.0:
			return candidates[i]
	return candidates[-1]


## The patterns that fit at track distance `at`, in their order in `patterns`, and their pick weights:
## {"patterns": Array, "weights": Array[float]}. A pattern fits in its difficulty range and lane
## count, with every required feature active there (feature_active); with `only`, just the patterns
## that require that feature.
## A pattern's weight is its own times the level's feature_weights for what it requires, and with
## the campaign's recency curve (LevelConfig.recency_on) times its newest feature's factor; with
## keep_feature_share the features' patterns are then scaled back to weigh together what they
## weighed without the curve, so the curve only moves picks between features. In a level paced in
## bursts, only the patterns _pacing_allows are taken (threats in bursts, enemies only there bar
## quiet_features), and a burst that has had its introduction leaves out the features still waiting
## for theirs (_intro_held).
func pick_weights(patterns: Array, difficulty: float, at: float, only: String = "") -> Dictionary:
	var candidates: Array = []
	var weights: Array[float] = []
	var recency: bool = config.recency_on()
	var paced: bool = config.paced_in_bursts()
	var held: PackedStringArray = _intros_waiting(at) if _intro_held(at) else PackedStringArray()
	# The features' patterns' weights without and with the recency curve (keep_feature_share).
	var plain: float = 0.0
	var curved: float = 0.0
	for p: Dictionary in patterns:
		if difficulty < float(p.get("min_difficulty", 0.0)) or difficulty > float(p.get("max_difficulty", 1.0)):
			continue
		if config.lane_count < int(p.get("min_lanes", 1)):
			continue
		var requires: Array = p.get("requires", [])
		if only != "" and not requires.has(only):
			continue
		if paced and not _pacing_allows(p, at):
			continue
		var weight: float = float(p.get("weight", 1.0))
		var ok: bool = true
		for need: Variant in requires:
			if not feature_active(String(need), at) or held.has(String(need)):
				ok = false
				break
			weight *= config.feature_weight(String(need))
		if not ok or weight <= 0.0:
			continue
		if recency and not requires.is_empty():
			var factor: float = config.recency_factor(requires)
			plain += weight
			weight *= factor
			curved += weight
		candidates.append(p)
		weights.append(weight)
	if recency and config.feature_recency.keep_feature_share and curved > 0.0:
		var scale: float = plain / curved
		for i: int in candidates.size():
			if not (candidates[i].get("requires", []) as Array).is_empty():
				weights[i] *= scale
	return {"patterns": candidates, "weights": weights}


## The picks this build must give a feature, earliest first: each feature's introduction at its
## start (LevelConfig.feature_starts), and forced picks for each feature an earlier build missed
## (`forced`: feature → how many builds missed it; that many picks, up to GUARANTEE_MAX_PICKS, at
## spots from GUARANTEE_SHARES, the first one moving on with each miss).
func _due_picks(forced: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key: Variant in config.feature_starts:
		var feature: String = String(key)
		if config.has_feature(feature):
			out.append({"feature": feature, "at": feature_start(feature), "intro": true})
	var n: int = GUARANTEE_SHARES.size()
	for key: Variant in forced:
		var feature: String = String(key)
		var misses: int = int(forced[key])
		for k: int in mini(misses, GUARANTEE_MAX_PICKS):
			var share: float = GUARANTEE_SHARES[(misses - 1 + k * 5) % n]
			out.append({"feature": feature, "at": feature_share_at(feature, share), "intro": false})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["at"]) < float(b["at"]) or (float(a["at"]) == float(b["at"]) and String(a["feature"]) < String(b["feature"])))
	return out


## A due pick: once the cursor reaches a due pick's spot, the next pattern picked is one that uses its
## feature. That's how a feature is introduced right after its start and its first-encounter hint
## (GDD §6: one new thing at a time) rather than whenever chance brings it, and how the guarantee
## places a feature a build missed. {} if nothing is due, or no due feature has a pattern that fits
## here (it's then tried again at the next pick, so a feature with no patterns yet changes nothing).
## In a level paced in bursts, a due pick of a feature a quiet stretch leaves out waits for the next
## burst, and a burst that has had one introduction holds the next for the burst after (_intro_held).
func _pick_due(patterns: Array, difficulty: float, at: float) -> Dictionary:
	var held: bool = _intro_held(at)
	for due: Dictionary in _due:
		if float(due["at"]) > at + 0.001:
			break
		if held and bool(due.get("intro", false)):
			continue
		var pattern: Dictionary = _pick_pattern(patterns, difficulty, at, String(due["feature"]))
		if not pattern.is_empty():
			return pattern
	return {}


## A pattern placed at `at` settles the due pick of each feature it uses whose spot the cursor has
## reached (the earliest one, if a feature has several). An introduction settled in a burst makes it
## that burst's one introduction.
func _settle_due(pattern: Dictionary, at: float) -> void:
	for need: Variant in pattern.get("requires", []):
		for i: int in _due.size():
			if float(_due[i]["at"]) > at + 0.001:
				break
			if String(_due[i]["feature"]) == String(need):
				if bool(_due[i].get("intro", false)) and burst_index(at) >= 0:
					_intro_burst = burst_index(at)
				_due.remove_at(i)
				break


## True if a level paced in bursts is in a burst at `at` that has had its introduction already: the
## features still waiting for theirs wait for the next burst (a burst never stacks two new things).
func _intro_held(at: float) -> bool:
	return config.paced_in_bursts() and _intro_burst >= 0 and burst_index(at) == _intro_burst


## The features whose introduction is due by `at` and not placed yet.
func _intros_waiting(at: float) -> PackedStringArray:
	var out: PackedStringArray = []
	for due: Dictionary in _due:
		if float(due["at"]) > at + 0.001:
			break
		if bool(due.get("intro", false)) and not out.has(String(due["feature"])):
			out.append(String(due["feature"]))
	return out


## The level's features that some pattern can place: a pattern that requires the feature, needs
## only the level's features, fits its lane count, has pick weight (feature_weights) and a
## difficulty range the level reaches between the pattern's features' starts and the end-clear
## stretch. The guarantee (guarantee_features) covers these; a feature with no such pattern (one
## still to be built) can't appear. Needs the layout's length (generate() has set it).
func placeable_features(patterns: Array) -> PackedStringArray:
	var out: PackedStringArray = []
	var last: float = layout.length - config.end_clear_distance
	for feature: String in config.features:
		for p: Dictionary in patterns:
			var requires: Array = p.get("requires", [])
			if not requires.has(feature) or config.lane_count < int(p.get("min_lanes", 1)):
				continue
			var weight: float = float(p.get("weight", 1.0))
			var first: float = config.start_clear_distance
			var ok: bool = true
			for need: Variant in requires:
				ok = ok and config.has_feature(String(need))
				weight *= config.feature_weight(String(need))
				first = maxf(first, feature_start(String(need)))
			if not ok or weight <= 0.0 or first >= last:
				continue
			if float(p.get("min_difficulty", 0.0)) <= difficulty_at(last / layout.length) \
					and float(p.get("max_difficulty", 1.0)) >= difficulty_at(first / layout.length):
				out.append(feature)
				break
	return out


## The features of `needed` that the current layout has nothing of (feature_positions).
func missing_features(needed: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = []
	for feature: String in needed:
		if feature_positions(layout, feature).is_empty():
			out.append(feature)
	return out


## Track distances of everything `feature` placed in `layout`, in order: ramps (ramps), anti-grav
## pads (ceilings), speed pads (speed_pads), pulsing fences (pulsing), host cyborgs (host), cyborgs
## that aren't hosts (cyborg), screeches from wall vents (screech_vents), and otherwise the enemies
## of that type, which covers every enemy type. A feature whose rules script declares
## `static func positions(layout: LevelLayout) -> Array[float]` answers for itself (a new kind of
## piece, such as wall fences).
static func feature_positions(p_layout: LevelLayout, feature: String) -> Array[float]:
	var out: Array[float] = []
	var path: String = RULES_DIR.path_join("%s_rules.gd" % feature)
	if ResourceLoader.exists(path):
		var script := load(path) as GDScript
		if script != null and script.has_method("positions"):
			out.assign(script.call("positions", p_layout))
			out.sort()
			return out
	match feature:
		"ramps":
			for r: Dictionary in p_layout.ramps:
				out.append(float(r["at"]))
		"ceilings":
			for p: Dictionary in p_layout.pads:
				out.append(float(p["at"]))
		"speed_pads":
			for p: Dictionary in p_layout.speed_pads:
				out.append(float(p["at"]))
		"pulsing":
			for f: Dictionary in p_layout.fences:
				if bool(f["pulsing"]):
					out.append(float(f["at"]))
		_:
			for e: Dictionary in p_layout.enemies:
				var type: String = String(e.get("type", ""))
				var params: Dictionary = e.get("params", {})
				var host: bool = type == "cyborg" and bool(params.get("host", false))
				var hit: bool = false
				match feature:
					"cyborg":
						hit = type == "cyborg" and not host
					"host":
						hit = host
					"screech_vents":
						hit = type == "screech" and String(params.get("source", "")) == "vent"
					_:
						hit = type == feature
				if hit:
					out.append(float(e["at"]))
	out.sort()
	return out


## Places every element of a pattern starting at `origin`. Returns the track length it used (a
## ceiling's includes its landing zone, so the next pattern starts past it). GDD §3: floor pieces
## and floor enemies may lie under a ceiling (the pattern's own: a gauntlet the ceiling escapes);
## _secure_ceilings keeps its landing zone and pads' spots safe afterwards.
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
				for lane: int in lanes:
					layout.gaps.append({"lane": lane, "start": at, "end": at + gap_len})
				used = maxf(used, at - origin + gap_len)
				prev_lanes = lanes
			"fence":
				var lanes: Array[int] = _pick_lanes(element.get("lanes", {}), prev_lanes)
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
				used = maxf(used, at - origin + hull_len + zones.landing)
				prev_lanes = lanes
			"speed_pad":
				var lanes: Array[int] = _pick_lanes(element.get("lanes", {"mode": "random", "count": 1}), prev_lanes)
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
					for lane: int in lanes:
						add_enemy(type, at, lane, 0, params.duplicate(true))
					prev_lanes = lanes
			"credits":
				_place_credit_element(element, at, prev_lanes, prev_side)
			_:
				push_warning("LevelGenerator: unknown element kind in pattern %s" % pattern.get("id", "?"))
	return used


## GDD §3: the ceilings a pattern just placed (the pieces after `counts`) keep their landing zone
## and their pads' spots safe (CeilingZones). A piece of the pattern's own there is a mistake in the
## pattern data: it's dropped, with a warning. Anything an earlier pattern left there (possible only
## with pacing tighter than a pad's run-up) is taken out quietly, which never makes a level unfair.
func _secure_ceilings(pattern: Dictionary, counts: Dictionary) -> void:
	var own: Array[Dictionary] = []
	var lists: Dictionary = layout.to_dict()
	for key: String in ["gaps", "fences", "ramps", "enemies"]:
		own.append_array((lists[key] as Array).slice(int(counts[key])))
	for i: int in range(int(counts["hulls"]), layout.hulls.size()):
		zones.clear_landing(layout, zones.landing_zone(layout.hulls[i]))
	for i: int in range(int(counts["pads"]), layout.pads.size()):
		zones.clear_pad(layout, int(layout.pads[i]["lane"]), float(layout.pads[i]["at"]))
	lists = layout.to_dict()
	for item: Dictionary in own:
		var kept: bool = false
		for key: String in ["gaps", "fences", "ramps", "enemies"]:
			for other: Dictionary in lists[key]:
				if is_same(other, item):
					kept = true
					break
			if kept:
				break
		if not kept:
			var line: String = "pattern '%s' puts a floor piece in a ceiling's landing zone or at its pad (GDD §3); skipped" \
				% pattern.get("id", "?")
			if not warnings.has(line):
				warnings.append(line)
			return


## Size of every piece list, so a pattern that doesn't fit can be taken back out.
func _counts() -> Dictionary:
	return {"gaps": layout.gaps.size(), "fences": layout.fences.size(), "signs": layout.signs.size(),
		"hulls": layout.hulls.size(), "pads": layout.pads.size(), "ramps": layout.ramps.size(),
		"speed_pads": layout.speed_pads.size(), "enemies": layout.enemies.size(),
		"credits": layout.credits.size()}


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

## Runs the rules scripts in the order of the level's features. A script may declare
## `const RUN_AFTER: Array[String] = [...]`: it then runs after the rules of those features whenever
## the level has them, whatever their order in the list (the host rules plan the Bad Dream's pads
## around the drones' pad schedule).
func _apply_enemy_rules() -> void:
	var pending: Array[Array] = []
	for feature: String in config.features:
		var path: String = RULES_DIR.path_join("%s_rules.gd" % feature)
		if not ResourceLoader.exists(path):
			continue
		var script := load(path) as GDScript
		if script != null and script.has_method("apply"):
			pending.append([feature, script])
	while not pending.is_empty():
		var next: int = 0
		for i: int in pending.size():
			if not _waits_for_others(pending, i):
				next = i
				break
		var item: Array = pending.pop_at(next)
		(item[1] as GDScript).call("apply", self)


## True if the rules at `index` must wait: its RUN_AFTER names a feature whose rules are still to run.
static func _waits_for_others(pending: Array[Array], index: int) -> bool:
	var after: Variant = (pending[index][1] as GDScript).get_script_constant_map().get("RUN_AFTER", [])
	if not (after is Array):
		return false
	for j: int in pending.size():
		if j != index and (after as Array).has(pending[j][0]):
			return true
	return false


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


## Credits along the wall-run path after each ramp (wall_run_credits).
func _place_wall_run_credits() -> void:
	for r: Dictionary in layout.ramps:
		layout.credits.append_array(wall_run_credits(layout, r, tuning, speed))


## The credits along ramp `r`'s wall run in `p_layout`, richer the further along (GDD §7): each where
## the launched player is at that moment (RampLaunch, with the ramp's fading speed boost), 0.3 s apart
## once they're on the wall. The line stops before a sign on that wall. Entries as in
## LevelLayout.credits; `p_speed` is the level's run speed.
static func wall_run_credits(p_layout: LevelLayout, r: Dictionary, p_tuning: MovementTuning,
		p_speed: float) -> Array[Dictionary]:
	var values: Array[int] = [1, 1, 5, 5, 5, 25]
	var side: int = int(r["side"])
	var launch := RampLaunch.of(r, p_tuning, p_speed)
	var out: Array[Dictionary] = []
	for i: int in values.size():
		var t: float = p_tuning.wall_entry_time + 0.3 * (i + 1)
		var d: float = launch.distance_at(t)
		if _sign_near(p_layout, side, d, 1.5):
			break
		out.append({"at": d, "surface": "wall", "lane": p_layout.outer_lane(side), "side": side,
			"height": launch.height_at(t), "value": values[i], "risky": true})
	return out


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
			if _sign_near(layout, c["side"], c["at"], 1.0):
				continue
		kept.append(c)
	layout.credits = kept


func _fence_near(lane: int, d: float, margin: float) -> bool:
	for f: Dictionary in layout.fences:
		if f["lane"] == lane and absf(f["at"] - d) < margin:
			return true
	return false


static func _sign_near(p_layout: LevelLayout, side: int, d: float, margin: float) -> bool:
	for s: Dictionary in p_layout.signs:
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

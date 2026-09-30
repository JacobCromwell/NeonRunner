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
## Narrow ceilings (GDD §3, decided September 26, 2026: ceilings don't have to cover every lane): a
## ceiling covers a contiguous range of lanes (LevelLayout.hull_lanes), with its pads inside it and its
## landing zone over its lanes. A level's narrow_ceiling_share of its ceilings (LevelConfig, from
## narrow_ceiling_start on) cover fewer lanes than the track has, pattern ceilings and rules' alike
## (ceiling_lanes, from a random stream of its own, so full-width ceilings and everything else come out
## exactly as before); a one-lane ceiling is very short (one_lane_ceiling_seconds) and only where its
## pattern puts nothing under it.
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
## pattern's pick weight follows how recently the campaign introduced its newest feature, the curve
## only moves picks between the level's features of the same kind (FeatureRecency.keep_feature_share,
## keep_share_by_kind), and never boosts a feature whose rules would drop its extra enemies
## (FeatureRecency.max_factor): no level gets easier.
##
## A level may alternate long quiet stretches with short, dense bursts (LevelConfig.quiet_seconds;
## GDD §5, The Hush): quiet stretches pick sparse patterns without enemies (bar quiet_features), bursts
## pick threats, densely. Every rule, fairness check and the guarantee apply to it unchanged, and a
## burst takes at most one introduction, so it never stacks two new things.
##
## Pace and busier levels (GDD §3, owner's playtest September 30, 2026): a level runs at its own speed
## (LevelConfig.run_speed, its zone's in the campaign), and everything the patterns and rules measure
## in metres for MovementTuning.REFERENCE_SPEED is stretched by the level's pace (metres()), so every
## reaction window keeps its seconds. After the rules, a fill pass (LevelConfig.fill_empty_seconds)
## puts more of the level's plain obstacle patterns into its long empty stretches, off everything the
## rules and ceilings keep (fill_keep_outs), spaced like the pattern pass: busier, never tighter.

const DENOMINATIONS: Array[int] = [1, 5, 25, 100]
const RULES_DIR: String = "res://scripts/enemies"
## The most builds generate() makes to have every feature appear (guarantee_features). Past it the
## level keeps the build that missed the fewest, with a warning. Most levels take one to three; The
## Hush, whose bursts leave its many features little room, took up to 17 on a few seeds (task B3's
## sweeps: 16 left one seed at 3 lanes and one at 6 without a feature, with and without narrow
## ceilings), so there's room to spare. A level found within fewer builds is built exactly the same.
const GUARANTEE_ATTEMPTS: int = 24
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
## The fill pass keeps this much more than the level's spacing from everything already there, for a
## pattern's tail (the pattern pass spaces patterns from the end of the last one's `length`, which
## runs a little past its last piece).
const FILL_TAIL_SECONDS: float = 0.25
## Seconds before its spot an enemy counts as busy for the fill pass (fill_keep_outs), unless its
## rules script says otherwise (`keep_out`): it winds up, fires or springs out as the player closes in.
const FILL_ENEMY_LEAD_SECONDS: float = 2.0
## Under a ceiling the fill pass times its fillers as the gauntlet patterns time their pieces
## (data/patterns/README.md): from this long after the pad ...
const FILL_CEILING_AFTER_PAD_SECONDS: float = 1.0
## ... until this long before the ceiling's end (its landing zone follows).
const FILL_CEILING_BEFORE_END_SECONDS: float = 0.6

var layout: LevelLayout
var config: LevelConfig
## The level's movement tuning (LevelConfig.movement_for: at its own run speed, its zone's in the
## campaign).
var tuning: MovementTuning
## Run speed the level is built for, and a full jump's length at that speed.
var speed: float
var jump_distance: float
## How much faster than MovementTuning.REFERENCE_SPEED the level runs (MovementTuning.pace; 1 at
## 18 m/s). The patterns' metres (an element's `at`, a pattern's `length`, a sign's length, credit
## spacing) and the rules' margins in metres were written for the reference speed: they're stretched
## by it (metres()), so every pattern keeps its timing in seconds and a faster zone is never secretly
## tighter (GDD §3, "Pace and busier levels"). Seconds (`at_seconds`, spacing, ceilings' lengths) and
## jumps (a gap's jump_frac) follow the run speed already.
var pace: float = 1.0
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
## The patterns the fill pass of the last build placed (LevelConfig.fill_empty_seconds), in order:
## {id, at, used}. For tests and tools/measure/level_pace.gd.
var fills: Array[Dictionary] = []

var _rng := RandomNumberGenerator.new()
## Which ceilings are narrow, and their lanes (ceiling_lanes): a stream of its own, drawn from only
## where a ceiling may be narrow, so a level without narrow ceilings generates exactly as before.
var _ceiling_rng := RandomNumberGenerator.new()
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
	tuning = p_config.movement_for(p_tuning)
	speed = tuning.run_speed
	pace = tuning.pace()
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
	_ceiling_rng.seed = hash([config.level_seed, "narrow_ceilings"])
	layout = LevelLayout.new()
	layout.lane_count = config.lane_count
	_clear_stretches.clear()
	_enemy_count = 0
	warnings.clear()
	picks.clear()
	fills.clear()
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
	_fill_empty_stretches(patterns)
	_place_credits()
	layout.enemies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["at"] < b["at"])
	return layout


## `reference_metres` (a distance written for MovementTuning.REFERENCE_SPEED: a pattern's, a rule's
## margin) at this level's run speed: stretched by `pace`, so it takes as long to run.
func metres(reference_metres: float) -> float:
	return reference_metres * pace


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
	# The same sums as stretch_end(), so a quiet stretch ends exactly where it says (a cursor it moves
	# to the next burst's start is in that burst).
	var from: float = config.start_clear_distance
	var cycle: float = _pacing_cycle()
	return at < from + floorf((at - from) / cycle) * cycle + config.quiet_seconds * speed


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
			last_enemy = maxf(last_enemy, metres(float(element.get("at", 0.0))) + float(element.get("at_seconds", 0.0)) * speed)
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
## ceiling may be dangerous), covering `lanes` (Vector2i(first, last); every lane by default, and a
## narrow ceiling's range from ceiling_lanes, which must hold the pad's lane: a pad sits under its
## ceiling). Returns false (adding nothing) if the pad can't be stepped on or its landing zone isn't
## safe to land on (CeilingZones: pad_clear, landing_clear over its lanes, which include floor
## enemies' stretches), it would touch another ceiling, its landing doesn't end before the level's
## end-clear stretch, or the level's ceilings haven't started by `at` (a late `ceilings` feature,
## feature_started). PadPlacement clears the way first.
func add_hull_with_pad(lane: int, at: float, length_seconds: float, lanes: Vector2i = Vector2i(-1, -1)) -> bool:
	if not feature_started("ceilings", at):
		return false
	var span: Vector2i = lanes if lanes.x >= 0 else Vector2i(0, layout.lane_count - 1)
	if lane < span.x or lane > span.y:
		return false
	var hull: Dictionary = LevelLayout.make_hull(at - config.hull_lead_in, at + length_seconds * speed, span,
		layout.lane_count)
	var landing: Vector2 = zones.landing_zone(hull)
	if landing.y > layout.length - config.end_clear_distance:
		return false
	if not zones.pad_clear(layout, lane, at) or not zones.landing_clear(layout, landing, span):
		return false
	for h: Dictionary in layout.hulls:
		if float(hull["start"]) <= float(h["end"]) + 1.0 and float(hull["end"]) >= float(h["start"]) - 1.0:
			return false
	layout.pads.append({"lane": lane, "at": at})
	layout.hulls.append(hull)
	return true


## The lanes a new ceiling with its pads in `pads` covers, starting its lead-in before a pad at `at`
## (GDD §3: ceilings don't have to cover every lane; its pads always lie under it): Vector2i(first,
## last). Every lane, drawing nothing, unless the level makes a share of its ceilings narrow
## (LevelConfig.narrow_ceiling_share) and `at` is past narrow_ceiling_start. Then, from the level's own
## ceiling stream (so full-width ceilings and every other pick stay as they were): whether this one
## is narrow; if so, one lane (one_lane_ceiling_share of them, where `one_lane_ok` and the pads share a
## lane: a pattern that puts nothing under its ceiling, or a rule's ceiling), or from two lanes to
## narrow_ceiling_max_lanes (all but one by default), each as likely, and every lane if its pads lie
## further apart; and where the range lies, anywhere that holds every pad. A one-lane ceiling lasts
## one_lane_ceiling_seconds at most (one_lane_seconds). DESIGN-TBD (docs/questions/b3.md).
func ceiling_lanes(pads: Array[int], at: float, one_lane_ok: bool) -> Vector2i:
	var n: int = layout.lane_count
	var full := Vector2i(0, n - 1)
	if config.narrow_ceiling_share <= 0.0 or n < 2 or pads.is_empty() \
			or at < config.narrow_ceiling_start * layout.length:
		return full
	if _ceiling_rng.randf() >= config.narrow_ceiling_share:
		return full
	var lo_pad: int = pads.min()
	var hi_pad: int = pads.max()
	var width: int = 1
	if not (one_lane_ok and lo_pad == hi_pad and _ceiling_rng.randf() < config.one_lane_ceiling_share):
		var widest: int = n - 1
		if config.narrow_ceiling_max_lanes > 0:
			widest = clampi(config.narrow_ceiling_max_lanes, 1, n - 1)
		var least: int = maxi(2, hi_pad - lo_pad + 1)
		if least > widest:
			return full
		width = _ceiling_rng.randi_range(least, widest)
	var first: int = _ceiling_rng.randi_range(maxi(0, hi_pad - width + 1), mini(lo_pad, n - width))
	return Vector2i(first, first + width - 1)


## How long a ceiling over `lanes` lasts past its pad, at most `seconds`: a one-lane ceiling is very
## short (GDD §3; LevelConfig.one_lane_ceiling_seconds).
func one_lane_seconds(lanes: Vector2i, seconds: float) -> float:
	if lanes.x == lanes.y and layout.lane_count > 1:
		return minf(seconds, config.one_lane_ceiling_seconds)
	return seconds


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
		var span: Vector2 = enemy_floor_span(e, pace)
		if span.x <= to and span.y >= from:
			return false
	return true


## The stretch of floor [start, end] an enemy entry uses, which a ceiling's landing zone and the
## spots of its pads keep off (CeilingZones): its params.floor_span if its rules planned one, else
## its tuning's reach around its position, stretched by the level's `pace` (MovementTuning.pace: in a
## faster zone the enemies move and reach further in the same time). Vector2(INF, -INF) (overlapping
## nothing) for types whose tuning says they don't use the floor.
static func enemy_floor_span(entry: Dictionary, pace: float = 1.0) -> Vector2:
	var params: Dictionary = entry.get("params", {})
	if params.get("floor_span") is Vector2:
		return params["floor_span"]
	var at: float = float(entry["at"])
	var t := EnemyDirector.tuning_for(String(entry.get("type", ""))) as EnemyTuning
	if t == null:
		return Vector2(at - 10.0 * pace, at + 10.0 * pace)
	if not t.uses_floor:
		return Vector2(INF, -INF)
	return Vector2(at - t.floor_reach_before * pace, at + t.floor_reach_after * pace)


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
## the campaign's recency curve (LevelConfig.recency_on) times its newest feature's factor (no more
## than a capped feature's cap, FeatureRecency.max_factor); with keep_feature_share the features'
## patterns, capped ones apart, are then scaled back so that together they weigh what they weighed
## without the curve. With keep_share_by_kind that holds kind by kind (pattern_kind), and patterns
## with enemies weigh by the enemies they place (enemy_count): the curve only moves picks between
## features of the same kind, and the level places as many enemies, obstacles and safe mechanics as
## before. In a level paced in bursts, only the patterns _pacing_allows are taken (threats in bursts,
## enemies only there bar quiet_features), and a burst that has had its introduction leaves out the
## features still waiting for theirs (_intro_held). With `fill`, just the patterns the fill pass may
## place (is_filler).
func pick_weights(patterns: Array, difficulty: float, at: float, only: String = "", fill: bool = false) -> Dictionary:
	var candidates: Array = []
	var weights: Array[float] = []
	var recency: bool = config.recency_on()
	var by_kind: bool = recency and config.feature_recency.keep_share_by_kind
	var paced: bool = config.paced_in_bursts()
	var held: PackedStringArray = _intros_waiting(at) if _intro_held(at) else PackedStringArray()
	# Per kind of pattern (all in one without by_kind), what the features' patterns weigh without the
	# recency curve, and with it: the capped ones, and the rest (keep_feature_share). Patterns with
	# enemies count their enemies too (by_kind), so the curve keeps how many a level places.
	var plain: Array[float] = [0.0, 0.0, 0.0]
	var capped: Array[float] = [0.0, 0.0, 0.0]
	var curved: Array[float] = [0.0, 0.0, 0.0]
	# Each candidate's kind if keep_feature_share scales it back, else -1.
	var scaled_kind: Array[int] = []
	for p: Dictionary in patterns:
		if difficulty < float(p.get("min_difficulty", 0.0)) or difficulty > float(p.get("max_difficulty", 1.0)):
			continue
		if config.lane_count < int(p.get("min_lanes", 1)):
			continue
		if fill and not is_filler(p):
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
		var kind: int = -1
		if recency and not requires.is_empty():
			kind = pattern_kind(p) if by_kind else 0
			var measure: float = float(enemy_count(p, config.lane_count)) if by_kind and kind == 0 else 1.0
			plain[kind] += weight * measure
			weight *= config.recency_factor(requires)
			if config.recency_capped(requires):
				capped[kind] += weight * measure
				kind = -1
			else:
				curved[kind] += weight * measure
		candidates.append(p)
		weights.append(weight)
		scaled_kind.append(kind)
	if recency and config.feature_recency.keep_feature_share:
		var scale: Array[float] = [1.0, 1.0, 1.0]
		for k: int in 3:
			if curved[k] > 0.0:
				scale[k] = maxf(plain[k] - capped[k], 0.0) / curved[k]
		for i: int in candidates.size():
			if scaled_kind[i] >= 0:
				weights[i] *= scale[scaled_kind[i]]
	return {"patterns": candidates, "weights": weights}


## A pattern's kind, for the recency curve's shares (FeatureRecency.keep_share_by_kind): 0 if it
## places enemies, 1 if it places obstacles only (holes, fences, signs), 2 if neither (a plain
## ceiling, a ramp, a speed pad: safe mechanics).
static func pattern_kind(pattern: Dictionary) -> int:
	var kind: int = 2
	for element: Dictionary in pattern.get("elements", []):
		var element_kind: String = String(element.get("kind", ""))
		if element_kind == "enemy":
			return 0
		if element_kind in ["gap", "fence", "sign"]:
			kind = 1
	return kind


## How many enemies `pattern` places at `lanes` lanes: one for each wall enemy, and one for each lane
## a floor enemy's selector picks (as _pick_lanes counts them, before any rule drops one).
static func enemy_count(pattern: Dictionary, lanes: int) -> int:
	var count: int = 0
	var prev: int = 0
	for element: Dictionary in pattern.get("elements", []):
		var element_kind: String = String(element.get("kind", ""))
		if element_kind == "enemy" and element.has("side"):
			count += 1
		elif element_kind in ["gap", "fence", "hull", "speed_pad", "enemy"]:
			var fallback: Dictionary = {} if element_kind in ["gap", "fence"] else {"mode": "random", "count": 1}
			var picked: int = _selector_count(element.get("lanes", fallback), lanes, prev)
			if element_kind == "enemy":
				count += picked
			prev = picked
	return count


## How many lanes a lane selector picks at `lanes` lanes, `prev` being how many the element before
## picked (_pick_lanes).
static func _selector_count(selector: Dictionary, lanes: int, prev: int) -> int:
	var n: int = int(selector.get("count", 1))
	if selector.has("frac"):
		n = maxi(1, roundi(float(selector["frac"]) * lanes))
	match String(selector.get("mode", "random")):
		"all":
			return lanes
		"same":
			return prev
		"others":
			return lanes - prev
		"edge", "center":
			return 1
		"all_but":
			return lanes - clampi(n, 1, lanes - 1)
	return clampi(n, 1, lanes)


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
## _secure_ceilings keeps its landing zone and pads' spots safe afterwards. The pattern's metres are
## stretched by the level's pace (metres()), so it keeps its timing at any run speed.
func _place_pattern(pattern: Dictionary, origin: float) -> float:
	var used: float = metres(float(pattern.get("length", 8.0)))
	var prev_lanes: Array[int] = []
	var prev_side: int = 1
	for element: Dictionary in pattern.get("elements", []):
		# "at" is in metres at the reference speed (stretched by the pace); "at_seconds" scales with run
		# speed (for pieces timed against a hull).
		var at: float = origin + metres(float(element.get("at", 0.0))) + float(element.get("at_seconds", 0.0)) * speed
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
				var sign_len: float = metres(float(element.get("length", 8.0)))
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
				# Its lanes: every lane, or a narrow ceiling's range over its pads (one lane only if the
				# pattern puts nothing under it; ceiling_lanes).
				var span: Vector2i = ceiling_lanes(lanes, at, plain_ceiling(pattern))
				var hull_len: float = one_lane_seconds(span, float(element.get("length_seconds", 4.0))) * speed
				for lane: int in lanes:
					layout.pads.append({"lane": lane, "at": at})
				layout.hulls.append(LevelLayout.make_hull(at - config.hull_lead_in, at + hull_len, span, layout.lane_count))
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


## True if `pattern` puts nothing but its ceiling (and credits) on the track: nothing under the
## ceiling, so a one-lane ceiling may come of it (GDD §3: a one-lane ceiling is simply ridden out,
## short and relatively safe; a gauntlet's ceiling stays long enough to escape it).
static func plain_ceiling(pattern: Dictionary) -> bool:
	for element: Dictionary in pattern.get("elements", []):
		if not (String(element.get("kind", "")) in ["hull", "credits"]):
			return false
	return true


## GDD §3: the ceilings a pattern just placed (the pieces after `counts`) keep their landing zone
## (over their lanes) and their pads' spots safe (CeilingZones). A piece of the pattern's own there
## is a mistake in the pattern data: it's dropped, with a warning. Anything an earlier pattern left
## there (possible only with pacing tighter than a pad's run-up) is taken out quietly, which never
## makes a level unfair.
func _secure_ceilings(pattern: Dictionary, counts: Dictionary) -> void:
	var own: Array[Dictionary] = []
	var lists: Dictionary = layout.to_dict()
	for key: String in ["gaps", "fences", "ramps", "enemies"]:
		own.append_array((lists[key] as Array).slice(int(counts[key])))
	for i: int in range(int(counts["hulls"]), layout.hulls.size()):
		var h: Dictionary = layout.hulls[i]
		zones.clear_landing(layout, zones.landing_zone(h), layout.hull_lanes(h))
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


# --- Busier levels: the fill pass (GDD §3, owner's playtest September 30, 2026) ------------------

## Fills the level's long empty stretches with more of its plain obstacle patterns: where nothing goes
## on for longer than LevelConfig.fill_empty_seconds at run speed (no piece and no enemy: fill_keep_outs'
## "activity"), fillers (is_filler: holes and fences, picked by difficulty and weight as the pattern
## pass picks) go wherever nothing is kept either (its "keep"), as far from everything already there as
## the pattern pass spaces its patterns (the level's spacing there, plus FILL_TAIL_SECONDS) and as far
## from each other. It runs after the
## pattern pass and every rule, so track a rule kept for an enemy that then didn't come (a hover truck
## too near the end, an Octodog whose charges didn't fit) doesn't stay bare, and it never touches what
## a rule keeps. More of the same patterns, never harder ones (GDD §3: busier levels, "so there is
## always something going on"). Its own random stream: with fill_empty_seconds 0 (quick play, tests,
## boss arenas) a level is built exactly as it was before.
func _fill_empty_stretches(patterns: Array) -> void:
	if config.fill_empty_seconds <= 0.0:
		return
	var from: float = config.start_clear_distance
	var to: float = layout.length - config.end_clear_distance
	var outs: Dictionary = fill_keep_outs(patterns)
	var blocked: Array[Vector2] = []
	for k: Vector4 in outs["keep"]:
		blocked.append(Vector2(k.x - k.z, k.y + k.w))
	var empties: Array[Vector2] = free_stretches(outs["activity"], from, to)
	var saved: RandomNumberGenerator = _rng
	_rng = rng_for("fill")
	for region: Vector2 in free_stretches(blocked, from, to):
		# Only where nothing goes on for longer than fill_empty_seconds (every activity is kept, so the
		# region lies inside one such stretch).
		var empty := Vector2.ZERO
		for e: Vector2 in empties:
			if e.x <= region.x + 0.001 and e.y >= region.y - 0.001:
				empty = e
				break
		if (empty.y - empty.x) / speed <= config.fill_empty_seconds:
			continue
		var cursor: float = region.x
		var last: float = region.y
		while cursor < last:
			var difficulty: float = difficulty_at(cursor / layout.length)
			var pattern: Dictionary = _pick_filler(patterns, difficulty, cursor, last - cursor)
			if pattern.is_empty():
				break
			var used: float = _place_pattern(pattern, cursor)
			fills.append({"id": String(pattern.get("id", "?")), "at": cursor, "used": used})
			_trim_clear_stretches(Vector2(cursor, cursor + used))
			cursor += used + _spacing_seconds(cursor + used, difficulty) * speed
	_rng = saved
	if not fills.is_empty():
		_after_fill_rules()


## Runs the `static func after_fill(gen: LevelGenerator)` of every feature's rules script that has one,
## in the order of the level's features: a rule that keeps floor pieces out of somewhere the fill pass
## doesn't keep off whole (a hover truck's lane) keeps the fillers out too.
func _after_fill_rules() -> void:
	for feature: String in config.features:
		var path: String = RULES_DIR.path_join("%s_rules.gd" % feature)
		if not ResourceLoader.exists(path):
			continue
		var script := load(path) as GDScript
		if script != null and script.has_method("after_fill"):
			script.call("after_fill", self)


## True if the fill pass may place `pattern`: plain obstacles, holes and fences only, that need no
## feature (so nothing new ever comes before its introduction) and put nothing on a wall.
static func is_filler(pattern: Dictionary) -> bool:
	if not (pattern.get("requires", []) as Array).is_empty():
		return false
	var elements: Array = pattern.get("elements", [])
	if elements.is_empty():
		return false
	for element: Dictionary in elements:
		if not (String(element.get("kind", "")) in ["gap", "fence"]):
			return false
	return true


## What the fill pass keeps off: {"keep": Array[Vector4], "activity": Array[Vector2]}. "keep": stretches
## of track [from, to] where something is going on or kept, as Vector4(from, to, margin before, margin
## after), with how far a filler stays from each end (_fill_margin: the level's spacing there and a
## pattern's tail; none where a gauntlet's timing already holds). "activity": what of it is going on
## (every piece and enemy; not a landing zone, a pad's run-up or a quiet stretch). Kept off:
## every floor piece (holes, fences, signs, speed pads), each ramp to where its wall run drops the player
## back (RampLaunch), each pad's zone and each ceiling's landing zone (CeilingZones) and the floor under a
## ceiling, but where the level already picks gauntlets (a pattern with a ceiling and holes or fences
## under it, from its min_difficulty) over two lanes or more: there fillers may go under it, timed like
## a gauntlet's pieces (FILL_CEILING_AFTER_PAD_SECONDS after its pads, FILL_CEILING_BEFORE_END_SECONDS
## before its end); every enemy from FILL_ENEMY_LEAD_SECONDS before it to the end of the floor it uses
## (LevelGenerator.enemy_floor_span), or what its rules script keeps for it (`static func keep_out(gen:
## LevelGenerator, entry: Dictionary) -> Vector2`: a cyborg's margin, a hover truck's lane window, a
## Resonator's visit); and a level's quiet stretches.
func fill_keep_outs(patterns: Array) -> Dictionary:
	var out: Array[Vector4] = []
	var half: float = tuning.fence_depth * 0.5
	for g: Dictionary in layout.gaps:
		out.append(_keep(g["start"], g["end"]))
	for f: Dictionary in layout.fences:
		out.append(_keep(float(f["at"]) - half, float(f["at"]) + half))
	for s: Dictionary in layout.signs:
		out.append(_keep(s["start"], s["end"]))
	for r: Dictionary in layout.ramps:
		out.append(_keep(float(r["at"]), maxf(ramp_launch(r).end(), float(r["at"]) + tuning.ramp_length)))
	for p: Dictionary in layout.speed_pads:
		out.append(_keep(p["at"], float(p["at"]) + tuning.speed_pad_length))
	for p: Dictionary in layout.pads:
		out.append(Vector4(float(p["at"]), float(p["at"]) + tuning.pad_length, 0.0, 0.0))
	var hooks: Dictionary = {}
	for e: Dictionary in layout.enemies:
		var k: Vector2 = _enemy_keep_out(e, hooks)
		out.append(_keep(k.x, k.y))
	var activity: Array[Vector2] = []
	for k: Vector4 in out:
		activity.append(Vector2(k.x, k.y))
	var gauntlets: float = gauntlet_difficulty(patterns)
	var open_hulls: Array[Dictionary] = []
	for h: Dictionary in layout.hulls:
		var landing: Vector2 = zones.landing_zone(h)
		if layout.hull_width(h) >= 2 and difficulty_at(float(h["start"]) / layout.length) >= gauntlets:
			open_hulls.append(h)
			out.append(Vector4(float(h["end"]) - FILL_CEILING_BEFORE_END_SECONDS * speed, landing.y, 0.0,
				_fill_margin(landing.y)))
		else:
			out.append(_keep(float(h["start"]), landing.y))
	for p: Dictionary in layout.pads:
		var at: float = float(p["at"])
		var zone: Vector2 = zones.pad_zone(at)
		var under_open: bool = false
		for h: Dictionary in open_hulls:
			under_open = under_open or (at >= float(h["start"]) and at <= float(h["end"]))
		if under_open:
			out.append(Vector4(zone.x, maxf(zone.y, at + FILL_CEILING_AFTER_PAD_SECONDS * speed), _fill_margin(zone.x), 0.0))
		else:
			out.append(_keep(zone.x, zone.y))
	for q: Vector2 in quiet_stretches():
		out.append(_keep(q.x, q.y))
	return {"keep": out, "activity": activity}


## A keep-out [from, to] with the fill pass's usual margin at both ends (_fill_margin).
func _keep(from: float, to: float) -> Vector4:
	return Vector4(from, to, _fill_margin(from), _fill_margin(to))


## The lowest difficulty at which the level picks a gauntlet: a pattern with a ceiling and holes or
## fences under it whose features the level has, with pick weight. INF without one.
func gauntlet_difficulty(patterns: Array) -> float:
	var out: float = INF
	for p: Dictionary in patterns:
		var hull: bool = false
		var floor_piece: bool = false
		for element: Dictionary in p.get("elements", []):
			var kind: String = String(element.get("kind", ""))
			hull = hull or kind == "hull"
			floor_piece = floor_piece or kind in ["gap", "fence"]
		if not (hull and floor_piece) or config.lane_count < int(p.get("min_lanes", 1)):
			continue
		var weight: float = float(p.get("weight", 1.0))
		var ok: bool = true
		for need: Variant in p.get("requires", []):
			ok = ok and config.has_feature(String(need))
			weight *= config.feature_weight(String(need))
		if ok and weight > 0.0:
			out = minf(out, float(p.get("min_difficulty", 0.0)))
	return out


## What the fill pass keeps off around enemy entry `e` (fill_keep_outs). `hooks` caches each type's
## rules script's keep_out, if it has one.
func _enemy_keep_out(e: Dictionary, hooks: Dictionary) -> Vector2:
	var type: String = String(e.get("type", ""))
	if not hooks.has(type):
		var path: String = RULES_DIR.path_join("%s_rules.gd" % type)
		var script: GDScript = load(path) as GDScript if ResourceLoader.exists(path) else null
		hooks[type] = script if script != null and script.has_method("keep_out") else null
	if hooks[type] != null:
		return (hooks[type] as GDScript).call("keep_out", self, e)
	var at: float = float(e["at"])
	var out := Vector2(at - FILL_ENEMY_LEAD_SECONDS * speed, at)
	var span: Vector2 = enemy_floor_span(e, pace)
	if span.y >= span.x:
		out = Vector2(minf(out.x, span.x), maxf(out.y, span.y))
	return out


## The stretches of [from, to] that none of `busy` covers, in order.
static func free_stretches(busy: Array[Vector2], from: float, to: float) -> Array[Vector2]:
	var sorted: Array[Vector2] = busy.duplicate()
	sorted.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var out: Array[Vector2] = []
	var cursor: float = from
	for b: Vector2 in sorted:
		if b.y <= cursor:
			continue
		if b.x > cursor:
			out.append(Vector2(cursor, minf(b.x, to)))
		cursor = maxf(cursor, b.y)
		if cursor >= to:
			return out
	if cursor < to:
		out.append(Vector2(cursor, to))
	return out


## How far the fill pass keeps a filler from what's around track distance `at`: the level's spacing
## there plus FILL_TAIL_SECONDS, at run speed.
func _fill_margin(at: float) -> float:
	var difficulty: float = difficulty_at(clampf(at / layout.length, 0.0, 1.0))
	return (_spacing_seconds(at, difficulty) + FILL_TAIL_SECONDS) * speed


## A weighted pick among the fillers that fit in `room` metres from `at` (is_filler, pattern_extent).
## {} (drawing nothing) when none fits.
func _pick_filler(patterns: Array, difficulty: float, at: float, room: float) -> Dictionary:
	var pool: Dictionary = pick_weights(patterns, difficulty, at, "", true)
	var candidates: Array = []
	var weights: Array[float] = []
	var total: float = 0.0
	for i: int in (pool["patterns"] as Array).size():
		var p: Dictionary = pool["patterns"][i]
		if pattern_extent(p) <= room:
			candidates.append(p)
			weights.append(float(pool["weights"][i]))
			total += weights[-1]
	if candidates.is_empty() or total <= 0.0:
		return {}
	var roll: float = _rng.randf() * total
	for i: int in candidates.size():
		roll -= weights[i]
		if roll <= 0.0:
			return candidates[i]
	return candidates[-1]


## The track a pattern of holes and fences takes at this level's speed: its length, or its last hole's
## end (what _place_pattern returns for it).
func pattern_extent(pattern: Dictionary) -> float:
	var extent: float = metres(float(pattern.get("length", 8.0)))
	for element: Dictionary in pattern.get("elements", []):
		var at: float = metres(float(element.get("at", 0.0))) + float(element.get("at_seconds", 0.0)) * speed
		if String(element.get("kind", "")) == "gap":
			at += minf(float(element.get("jump_frac", 0.5)), config.max_gap_jump_fraction) * jump_distance
		extent = maxf(extent, at)
	return extent


## Takes `span` out of the clear stretches the credit trails go in (a filler now stands there).
func _trim_clear_stretches(span: Vector2) -> void:
	var out: Array[Vector2] = []
	for s: Vector2 in _clear_stretches:
		if s.y <= span.x or s.x >= span.y:
			out.append(s)
			continue
		if s.x < span.x:
			out.append(Vector2(s.x, span.x))
		if s.y > span.y:
			out.append(Vector2(span.y, s.y))
	_clear_stretches = out


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
	var spacing: float = metres(float(element.get("spacing", config.credit_trail_spacing)))
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
## shifting one lane halfway so the player has to move. Their spacing is stretched by the pace, like
## the patterns', so a trail takes as long to run at any speed. A stretch too short for a full trail
## gets a shorter one, down to LevelConfig.credit_trail_min credits (0: none).
func _place_trails(rng: RandomNumberGenerator) -> void:
	var n: int = layout.lane_count
	var spacing: float = metres(config.credit_trail_spacing)
	var trail_len: float = (config.credit_trail_count - 1) * spacing
	for stretch: Vector2 in _clear_stretches:
		var count: int = config.credit_trail_count
		if stretch.y - stretch.x < trail_len + metres(6.0):
			count = mini(count, floori((stretch.y - stretch.x - metres(6.0)) / spacing) + 1)
			if config.credit_trail_min <= 0 or count < config.credit_trail_min:
				continue
		if rng.randf() >= config.credit_trail_chance:
			continue
		if config.credit_trail_count <= 0:
			continue
		var lane: int = rng.randi_range(0, n - 1)
		var shift: int = 0
		if rng.randf() < 0.35:
			shift = -1 if lane == n - 1 else (1 if lane == 0 else (-1 if rng.randf() < 0.5 else 1))
		var start: float = (stretch.x + stretch.y) * 0.5 - (count - 1) * spacing * 0.5
		for i: int in count:
			var l: int = lane + (shift if i >= count / 2 else 0)
			var d: float = start + i * spacing
			if layout.under_hull(d, l):
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


## A line of credits along the pad's lane on the ceiling and a rich one in its far lane: the lane of
## the ceiling furthest from the pad's (a ceiling over one lane has none; GDD §3, the rider moves only
## within its lanes).
func _place_ceiling_credits(rng: RandomNumberGenerator) -> void:
	for p: Dictionary in layout.pads:
		var hull: Dictionary = {}
		for h: Dictionary in layout.hulls:
			if h["start"] <= p["at"] and h["end"] >= p["at"]:
				hull = h
		if hull.is_empty():
			continue
		var lane: int = p["lane"]
		var d: float = float(p["at"]) + metres(10.0)
		var placed: int = 0
		while d < float(hull["end"]) - metres(8.0) and placed < 10:
			_add_credit(d, "ceiling", lane, 0, 0.6, 1)
			d += metres(4.0)
			placed += 1
		var lanes: Vector2i = layout.hull_lanes(hull)
		if lanes.y > lanes.x:
			var far_lane: int = lanes.x if 2 * lane >= lanes.x + lanes.y else lanes.y
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

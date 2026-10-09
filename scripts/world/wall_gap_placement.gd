class_name WallGapPlacement
extends RefCounted
## Places side wall gaps (the `wall_gaps` feature; LevelLayout.wall_gaps; owner's answers in
## docs/USER_REQUESTS.md): stretches where a side wall has no wall-running surface. A runner can't get
## onto the wall there and one already on it drops off into the outer lane (Player.wall_supported); the
## track builder leaves the wall out and marks the gap's edges (ZoneSkin.wall_gap).
##
## Rules, at the generator's run speed, with the numbers in WallGapTuning (data/tuning/wall_gaps.tres):
## - Only in a level with the feature (Zone 2 on), never in a boss arena (BossArena.base_config strips
##   the feature, and is_boss_arena() refuses one anyway), and not before the feature's start.
## - Low frequency: about a spacing (spacing_seconds_easy to _hard) from the end of one to the next.
## - A bilateral_share of them open both walls over the same stretch; the rest open one wall.
## - Never where the missing wall would leave something hanging or a launch with nowhere to go: a
##   gap keeps clear_seconds from the run-up, the end-clear stretch, every sign, wall fence and wall
##   enemy on its wall (a Gilded Sentinel's whole wall section and niche, sentinel_wall_section), every
##   ceiling reaching its wall, and a ramp on its wall from before its launch to past its longest
##   wall run (keep_outs); and both walls keep clear of every wider floor gap (task G7,
##   WideGapPlacement.wall_keep_outs), so a wall runner is never dropped into one.
## - Deliberately NOT kept: the outer lane's floor beside a gap. The owner decided players should see
##   gaps coming, so a drop may land the runner in front of whatever the outer lane holds.
##
## A level may have its own numbers (LevelConfig.wall_gap_tuning, tuning_for; task D10b), and with them open
## walls (coverage mode, WallGapTuning.coverage_target above 0; the owner, October 9, 2026, on the Beach: "much
## longer sections where there aren't sidewalls", the walls standing about half as often): instead of the rare
## short gaps, each wall opens every stretch its keep-outs leave free that is at least open_seconds_min long,
## then stands again where it has more open than its target share of the level, first where the other wall is
## open too, and where both walls are still open at once over more than both_open_max of the level
## (_open_walls). Every keep-out above holds there as anywhere, so a wall whose keep-outs leave less free stands
## more. The shared tuning has it off, so every other level is built exactly as before.
##
## Its own random stream (LevelGenerator.rng_for), so every other pass places exactly what it did
## before; a level without the feature is unchanged.

const FEATURE: String = "wall_gaps"
const TUNING_PATH: String = "res://data/tuning/wall_gaps.tres"
## Metres within which two stretch ends count as the same point (coverage mode).
const EPSILON: float = 0.001
## Metres an open stretch keeps from the keep-outs either side of it (coverage mode), as the rare gaps start
## WallFencePlacement.EPSILON past one: never touching what its wall keeps.
const KEEP_MARGIN: float = 0.01
## Metres of open wall over a target that are only rounding (coverage mode): less than this is nothing to close.
const CLOSE_TOLERANCE: float = 0.05


## The shared numbers (data/tuning/wall_gaps.tres), which every level without its own uses.
static func tuning() -> WallGapTuning:
	var res: Resource = load(TUNING_PATH) if ResourceLoader.exists(TUNING_PATH) else null
	return res as WallGapTuning if res is WallGapTuning else WallGapTuning.new()


## The numbers `config`'s level places its wall gaps by (task D10b): its own (LevelConfig.wall_gap_tuning, the
## Beach's), else the shared ones (tuning()). The F6 panel's "Wall gaps" group edits the same resource.
static func tuning_for(config: LevelConfig) -> WallGapTuning:
	if config != null and config.wall_gap_tuning != null:
		return config.wall_gap_tuning
	return tuning()


## True if `config` is a boss arena's (BossArena.base_config names them "<boss>_arena").
static func is_boss_arena(config: LevelConfig) -> bool:
	return String(config.id).ends_with("_arena")


## Places the level's wall gaps (see the header) into gen.layout.wall_gaps, sorted by start.
static func place(gen: LevelGenerator) -> void:
	var lay: LevelLayout = gen.layout
	lay.wall_gaps.clear()
	if not gen.config.has_feature(FEATURE) or is_boss_arena(gen.config):
		return
	var t: WallGapTuning = tuning_for(gen.config)
	var rng: RandomNumberGenerator = gen.rng_for(FEATURE)
	var v: float = gen.speed
	var lo_len: float = minf(t.length_seconds_min, t.length_seconds_max)
	var hi_len: float = maxf(t.length_seconds_min, t.length_seconds_max)
	var keeps: Array = [keep_outs(gen, lay, -1, t), keep_outs(gen, lay, 1, t)]
	var from: float = maxf(gen.feature_start(FEATURE), gen.config.start_clear_distance)
	var last: float = lay.length - gen.config.end_clear_distance
	if t.opens_walls():
		_open_walls(gen, t, keeps, from, last, rng)
	var search: float = t.search_seconds * v
	var cursor: float = from
	# The rare short gaps (the shared tuning); a level with open walls has its gaps already.
	while not t.opens_walls():
		var difficulty: float = gen.difficulty_at(clampf(cursor / maxf(lay.length, 1.0), 0.0, 1.0))
		var spacing: float = WallGapTuning.by_difficulty(t.spacing_seconds_easy, t.spacing_seconds_hard, difficulty)
		# Every draw happens whether or not the spot fits, so one blocked spot never reshuffles the rest.
		cursor += spacing * (1.0 + rng.randf_range(-t.spacing_jitter, t.spacing_jitter)) * v
		var length: float = rng.randf_range(lo_len, hi_len) * v
		var both: bool = rng.randf() < t.bilateral_share
		var side: int = -1 if rng.randf() < 0.5 else 1
		if cursor > last:
			break
		var placed: float = _fit(lay, keeps, side, both, cursor, minf(cursor + search, last), length)
		if placed < INF:
			cursor = placed + length
	if lay.wall_gaps.is_empty():
		# GDD §5: a feature a level has appears in it. A level whose spacing found no fit gets one gap at
		# the first spot that fits anywhere past the feature's start.
		_fit(lay, keeps, -1 if rng.randf() < 0.5 else 1, false, from, last,
			rng.randf_range(lo_len, hi_len) * v)
	lay.wall_gaps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["start"]) < float(b["start"]) or (float(a["start"]) == float(b["start"]) and int(a["side"]) < int(b["side"])))


## Coverage mode (WallGapTuning.opens_walls, the Beach's; task D10b): opens each wall wherever it may and stands
## it again down to the target, into gen.layout.wall_gaps (see the header). `keeps` are the walls' keep-outs
## (left, right), [from, last] the stretch gaps may lie in.
## 1. Each wall opens every stretch its keep-outs leave free in [from, last] that is at least open_seconds_min
##    long (open_stretches).
## 2. Each wall with more open than coverage_target of the level's length stands again until it has that much,
##    the wall with more to close first: where the other wall is open too first (the both-open stretches,
##    shortest first), then its own shortest open stretches. So the second wall keeps more of what both had
##    open, and fewer stretches are open on both walls at once.
## 3. While both walls are open at once over more than both_open_max of the level, the wall with more open
##    stands again over the shortest such stretch (or as much of it as is over).
## Each closing takes a whole stretch, or the part it needs (at least solid_seconds_min) from an end of it that
## meets standing wall already (_close_down), and leaves no open stretch shorter than open_seconds_min, so a
## wall only ever stands again where it was free to open: never through a keep-out. A wall whose keep-outs
## leave less than its target free stays below it.
static func _open_walls(gen: LevelGenerator, t: WallGapTuning, keeps: Array, from: float, last: float,
		rng: RandomNumberGenerator) -> void:
	var lay: LevelLayout = gen.layout
	var min_open: float = t.open_seconds_min * gen.speed
	var min_solid: float = t.solid_seconds_min * gen.speed
	var open: Array[Array] = []
	for i: int in 2:
		open.append(open_stretches(keeps[i], from, last, min_open))
	var want: float = t.coverage_target * lay.length
	var order: Array[int] = [0, 1]
	if span_total(open[1]) > span_total(open[0]):
		order = [1, 0]
	for i: int in order:
		var mine: Array[Vector2] = []
		mine.assign(open[i])
		var other: Array[Vector2] = []
		other.assign(open[1 - i])
		mine = _close_down(mine, _shortest_first(spans_overlap(mine, other)), span_total(mine) - want, min_open,
			min_solid, rng)
		mine = _close_down(mine, _shortest_first(mine), span_total(mine) - want, min_open, min_solid, rng)
		open[i] = mine
	var cap: float = t.both_open_max * lay.length
	while true:
		var left: Array[Vector2] = []
		left.assign(open[0])
		var right: Array[Vector2] = []
		right.assign(open[1])
		var both: Array[Vector2] = spans_overlap(left, right)
		var over: float = span_total(both) - cap
		if over <= CLOSE_TOLERANCE or both.is_empty():
			break
		var i: int = 0
		var mine: Array[Vector2] = left
		if span_total(right) > span_total(left):
			i = 1
			mine = right
		var pieces: Array[Vector2] = [_shortest_first(both)[0]]
		var after: Array[Vector2] = _close_down(mine, pieces, over, min_open, min_solid, rng)
		if span_total(after) >= span_total(mine):
			break
		open[i] = after
	for i: int in 2:
		for g: Vector2 in open[i]:
			lay.wall_gaps.append({"side": -1 if i == 0 else 1, "start": g.x, "end": g.y})


## The stretches of [from, last] that `keeps` (sorted, merged: keep_outs) leave free, each KEEP_MARGIN clear of
## them, those at least `min_open` long, in order: where a wall may open in coverage mode.
static func open_stretches(keeps: Array, from: float, last: float, min_open: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var cursor: float = from
	for k: Vector2 in keeps:
		if k.y <= cursor:
			continue
		if k.x >= last:
			break
		_add_open(out, cursor, k.x, min_open)
		cursor = maxf(cursor, k.y)
	_add_open(out, cursor, last, min_open)
	return out


## Appends [from, to] less KEEP_MARGIN at each end to `out` if that's at least `min_open` long.
static func _add_open(out: Array[Vector2], from: float, to: float, min_open: float) -> void:
	var open := Vector2(from + KEEP_MARGIN, to - KEEP_MARGIN)
	if open.y - open.x >= min_open:
		out.append(open)


## The total length of `spans`.
static func span_total(spans: Array) -> float:
	var out: float = 0.0
	for s: Vector2 in spans:
		out += s.y - s.x
	return out


## Where the stretches `a` and `b` overlap, in order (each list sorted and disjoint, as open stretches and
## LevelLayout.wall_gap_spans are).
static func spans_overlap(a: Array[Vector2], b: Array[Vector2]) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var first: int = 0
	for p: Vector2 in a:
		while first < b.size() and b[first].y <= p.x:
			first += 1
		var k: int = first
		while k < b.size() and b[k].x < p.y:
			var lo: float = maxf(p.x, b[k].x)
			var hi: float = minf(p.y, b[k].y)
			if hi > lo:
				out.append(Vector2(lo, hi))
			k += 1
	return out


## `spans`, shortest first (ties: the earlier first), as a new list.
static func _shortest_first(spans: Array[Vector2]) -> Array[Vector2]:
	var out: Array[Vector2] = spans.duplicate()
	out.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return a.y - a.x < b.y - b.x or (a.y - a.x == b.y - b.x and a.x < b.x))
	return out


## One wall's open stretches `open` (sorted) with about `amount` of them standing again (nothing if `amount` is
## CLOSE_TOLERANCE or less), from the stretches `pieces` (each inside an open stretch), in order: a whole piece,
## or the part of it still needed (at least `min_solid`) from its end that meets standing wall already (either,
## at random, when both or neither do). An open stretch left shorter than `min_open` stands too, so this may
## close a little more than `amount`. A piece no longer inside one open stretch is skipped.
static func _close_down(open: Array[Vector2], pieces: Array[Vector2], amount: float, min_open: float,
		min_solid: float, rng: RandomNumberGenerator) -> Array[Vector2]:
	var out: Array[Vector2] = open.duplicate()
	var left: float = amount
	for p: Vector2 in pieces:
		if left <= CLOSE_TOLERANCE:
			break
		var holder := Vector2(INF, -INF)
		for o: Vector2 in out:
			if o.x <= p.x + EPSILON and o.y >= p.y - EPSILON:
				holder = o
				break
		if holder.x == INF:
			continue
		var span: Vector2 = p
		if p.y - p.x > left:
			var cut: float = minf(maxf(left, min_solid), p.y - p.x)
			var at_start: bool = absf(p.x - holder.x) <= EPSILON
			var at_end: bool = absf(p.y - holder.y) <= EPSILON
			if at_start == at_end:
				at_start = rng.randf() < 0.5
			span = Vector2(p.x, p.x + cut) if at_start else Vector2(p.y - cut, p.y)
		var before: float = span_total(out)
		out = _stand(out, span, min_open)
		left -= before - span_total(out)
	return out


## `open` (sorted open stretches) with the wall standing over `span`: each stretch it cuts keeps its parts
## outside it that are at least `min_open` long.
static func _stand(open: Array[Vector2], span: Vector2, min_open: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for o: Vector2 in open:
		if span.y <= o.x or span.x >= o.y:
			out.append(o)
			continue
		if span.x - o.x >= min_open:
			out.append(Vector2(o.x, span.x))
		if o.y - span.y >= min_open:
			out.append(Vector2(span.y, o.y))
	return out


## Places one gap `length` long starting in [lo, hi]: on both walls if `both` and they both have room
## there, else on `side`, else on the other wall. Returns its start, or INF if none fits.
static func _fit(lay: LevelLayout, keeps: Array, side: int, both: bool, lo: float, hi: float, length: float) -> float:
	if both:
		var at: float = WallFencePlacement.first_free(_starts_blocked(keeps[0] + keeps[1], length), lo, hi)
		if at < INF:
			for s: int in [-1, 1]:
				lay.wall_gaps.append({"side": s, "start": at, "end": at + length})
			return at
	for s: int in [side, -side]:
		var at: float = WallFencePlacement.first_free(_starts_blocked(keeps[0 if s < 0 else 1], length), lo, hi)
		if at < INF:
			lay.wall_gaps.append({"side": s, "start": at, "end": at + length})
			return at
	return INF


## The gap starts that `keeps` (stretches a gap may not overlap) rule out for a gap `length` long:
## sorted and merged.
static func _starts_blocked(keeps: Array, length: float) -> Array[Vector2]:
	var spans: Array = []
	for k: Vector2 in keeps:
		spans.append(Vector2(k.x - length, k.y))
	return WallFencePlacement.merged(spans)


## The stretches of track wall `side` of `lay` must keep whole (a gap may not overlap them), at the
## generator's run speed, each widened by clear_seconds: see the header.
static func keep_outs(gen: LevelGenerator, lay: LevelLayout, side: int, t: WallGapTuning) -> Array[Vector2]:
	var v: float = gen.speed
	var clear: float = t.clear_seconds * v
	var raw: Array[Vector2] = []
	raw.append(Vector2(-INF, gen.config.start_clear_distance))
	raw.append(Vector2(lay.length - gen.config.end_clear_distance, INF))
	for s: Dictionary in lay.signs:
		if int(s["side"]) == side:
			raw.append(Vector2(float(s["start"]), float(s["end"])))
	var fence_half: float = gen.tuning.fence_depth * 0.5
	for w: Dictionary in lay.wall_fences:
		if int(w["side"]) == side:
			raw.append(Vector2(float(w["at"]) - fence_half, float(w["at"]) + fence_half))
	var enemy: float = t.wall_enemy_seconds * v
	for e: Dictionary in lay.enemies:
		if int(e.get("side", 0)) != side:
			continue
		var at: float = float(e["at"])
		raw.append(Vector2(at - enemy, at + enemy))
		if String(e.get("type", "")) == "gilded_sentinel":
			raw.append(WallFencePlacement.sentinel_wall_section(gen, e))
	for r: Dictionary in lay.ramps:
		if int(r["side"]) == side:
			raw.append(Vector2(float(r["at"]) - t.ramp_before_seconds * v,
				WallFencePlacement.ramp_run_end(gen, r) + t.ramp_after_seconds * v))
	var outer: int = lay.outer_lane(side)
	for h: Dictionary in lay.hulls:
		if lay.hull_covers(h, outer):
			raw.append(Vector2(float(h["start"]), float(h["end"])))
	var out: Array[Vector2] = []
	for k: Vector2 in raw:
		out.append(Vector2(k.x - clear, k.y + clear))
	# Task G7: every wider gap, on both walls, with its own margin (WideGapTuning.wall_gap_clear_seconds), so a
	# runner on a wall over one is never dropped into it.
	out.append_array(WideGapPlacement.wall_keep_outs(gen))
	return WallFencePlacement.merged(out)

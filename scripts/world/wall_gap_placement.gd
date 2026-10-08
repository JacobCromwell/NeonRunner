class_name WallGapPlacement
extends RefCounted
## Places side wall gaps (the `wall_gaps` feature; LevelLayout.wall_gaps; owner's answers in
## docs/USER_REQUESTS.md): stretches where a side wall has no wall-running surface. A runner can't get
## onto the wall there and one already on it drops off into the outer lane (Player.wall_supported); the
## track builder leaves the wall out and marks the gap's edges (ZoneSkin.wall_gap).
##
## Rules, at the generator's run speed, with the numbers in WallGapTuning (data/tuning/wall_gaps.tres, or
## the config's own: tuning_for):
## - Only in a level with the feature (Zone 2 on), never in a boss arena (BossArena.base_config strips
##   the feature, and is_boss_arena() refuses one anyway) unless the arena opts in with numbers of its
##   own (LevelConfig.wall_gap_tuning: the Sleep Taker's, owner, October 8, 2026), and not before the
##   feature's start.
## - Low frequency: about a spacing (spacing_seconds_easy to _hard) from the end of one to the next.
## - A bilateral_share of them open both walls over the same stretch; the rest open one wall.
## - Never where the missing wall would leave something hanging or a launch with nowhere to go: a
##   gap keeps clear_seconds from the run-up, the end-clear stretch, every sign, wall fence and wall
##   enemy on its wall (a Gilded Sentinel's whole wall section and niche, sentinel_wall_section), every
##   ceiling reaching its wall, and a ramp on its wall from before its launch to past its longest
##   wall run (keep_outs).
## - Deliberately NOT kept: the outer lane's floor beside a gap. The owner decided players should see
##   gaps coming, so a drop may land the runner in front of whatever the outer lane holds.
##
## Its own random stream (LevelGenerator.rng_for), so every other pass places exactly what it did
## before; a level without the feature is unchanged.

const FEATURE: String = "wall_gaps"
const TUNING_PATH: String = "res://data/tuning/wall_gaps.tres"


## Every level's numbers (data/tuning/wall_gaps.tres).
static func tuning() -> WallGapTuning:
	var res: Resource = load(TUNING_PATH) if ResourceLoader.exists(TUNING_PATH) else null
	return res as WallGapTuning if res is WallGapTuning else WallGapTuning.new()


## The numbers `config`'s wall gaps follow: its own (LevelConfig.wall_gap_tuning, a boss arena's
## opt-in), else every level's.
static func tuning_for(config: LevelConfig) -> WallGapTuning:
	return config.wall_gap_tuning if config != null and config.wall_gap_tuning != null else tuning()


## True if `config` is a boss arena's (BossArena.base_config names them "<boss>_arena").
static func is_boss_arena(config: LevelConfig) -> bool:
	return String(config.id).ends_with("_arena")


## Places the level's wall gaps (see the header) into gen.layout.wall_gaps, sorted by start.
static func place(gen: LevelGenerator) -> void:
	var lay: LevelLayout = gen.layout
	lay.wall_gaps.clear()
	if not gen.config.has_feature(FEATURE) or (is_boss_arena(gen.config) and gen.config.wall_gap_tuning == null):
		return
	var t: WallGapTuning = tuning_for(gen.config)
	var rng: RandomNumberGenerator = gen.rng_for(FEATURE)
	var v: float = gen.speed
	var lo_len: float = minf(t.length_seconds_min, t.length_seconds_max)
	var hi_len: float = maxf(t.length_seconds_min, t.length_seconds_max)
	var keeps: Array = [keep_outs(gen, lay, -1, t), keep_outs(gen, lay, 1, t)]
	var from: float = maxf(gen.feature_start(FEATURE), gen.config.start_clear_distance)
	var last: float = lay.length - gen.config.end_clear_distance
	var search: float = t.search_seconds * v
	var cursor: float = from
	while true:
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
	return WallFencePlacement.merged(out)

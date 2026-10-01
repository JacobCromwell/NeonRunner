extends RefCounted
## Generator rules for the Barnacle Turret (GDD §9.8). LevelGenerator runs apply() for levels with the
## `barnacle_turret` feature, after the rules of every feature that adds or takes away ceilings
## (RUN_AFTER), so each turret hangs from one of the level's final ceilings. The turret has no
## patterns: these rules place every one of them, on the ceilings patterns and other rules made. So the
## pattern pass, the recency curve (which weighs patterns) and the guarantee's forced picks never see
## it, and everything else in a level comes out exactly as it would without the feature: the turret
## entries take seeds of their own rather than LevelGenerator.add_enemy's running count, and a turret
## never uses the floor (BarnacleTurretTuning.uses_floor false), so the floor under its ceiling, and the
## route along it, is untouched.
## - Limits (GDD §9.8): never on a one-lane ceiling (no room to dodge); at most 2 per ceiling; mounted
##   over lanes the ceiling covers, never over a pad's lane (the rider lands there and can ride on past
##   every turret; the ceiling's line of credits runs along it), and off the ceiling's credits in its
##   lane (credit_margin; also the rich credit the generator adds in the far lane afterwards); nothing
##   before the feature's start (LevelConfig.feature_starts).
## - Where: at least after_pad_seconds past its ceiling's last pad (the rider sees it pop out before
##   taking the pad, and its first burst fits in), before_end_seconds before the ceiling's end; two on
##   one ceiling at least spacing_seconds apart.
## - How many: the first ceiling past the feature's start where one fits always gets one, alone (its
##   introduction: Marketplace 1 meets it gently, and every level that lists the feature has one);
##   each later one gets turrets at ceiling_share, a second one at pair_share from pair_min_scaling on
##   (so none in Marketplace 1). DESIGN-TBD (docs/questions/c1.md).
## - The introduction comes soon after the feature's start (intro_seconds), in a level that gives the
##   feature one (LevelConfig.feature_starts); and a level that lists the feature always has a turret.
##   Where no ceiling it fits on lies in time, the rules add a plain ceiling for it
##   (intro_ceiling_seconds long, over every lane) at the first spot where one fits without clearing
##   anything (LevelGenerator.add_hull_with_pad: its pad and its landing zone are already safe, and no
##   floor enemy's stretch reaches them), before the level's first drone (the drone rules own every
##   pad after it, GDD §9.6) and in a lane no hover truck holds (PadPlacement.pad_lane). Only then does
##   a level differ from the same level without the feature: by that ceiling and its credits.
## Each entry's params carry its ceiling: hull_start, hull_end, first_lane, last_lane.

const TYPE: String = "barnacle_turret"
## Every feature whose rules may add or take away ceilings or pads (the Resonator's run after these).
const RUN_AFTER: Array[String] = ["drone", "host", "hover_truck", "octodog", "cyborg", "window_cyborg",
	"screech", "screech_vents", "generator", "wall_fences", "wall_fences_partial", "buzz_overdrive",
	"tithe_collector", "gilded_sentinel"]
## The generator's credits on a ceiling (LevelGenerator._place_ceiling_credits): the rich one in the
## lane furthest from a pad's sits this share of the way from the pad to the ceiling's end.
const FAR_CREDIT_SHARE: float = 0.7
## Shared with the drone and host rules: a pad's lane away from hover trucks.
const PadPlacement = preload("res://scripts/enemies/pad_placement.gd")
## Metres between the spots tried for an introduction's ceiling.
const INTRO_STEP: float = 4.0


static func apply(gen: LevelGenerator) -> void:
	var t: BarnacleTurretTuning = tuning()
	var layout: LevelLayout = gen.layout
	var rng: RandomNumberGenerator = gen.rng_for(TYPE)
	var scaling: float = gen.config.enemy_scaling
	_ensure_introduction(gen, t, rng)
	var hulls: Array[Dictionary] = layout.hulls.duplicate()
	hulls.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["start"]) < float(b["start"]))
	var placed: int = 0
	var introduced: bool = false
	for h: Dictionary in hulls:
		var spot: Dictionary = mount_window(gen, h, t)
		if spot.is_empty():
			continue
		var count: int = 1
		if introduced:
			if rng.randf() >= t.ceiling_share_at(scaling):
				continue
			if rng.randf() < t.pair_share_at(scaling) and float(spot["hi"]) - float(spot["lo"]) >= t.spacing_seconds * gen.speed:
				count = 2
		var lo: float = spot["lo"]
		var hi: float = spot["hi"]
		var spacing: float = t.spacing_seconds * gen.speed
		var ats: Array[float] = []
		if count == 2:
			var first: float = rng.randf_range(lo, hi - spacing)
			ats = [first, rng.randf_range(first + spacing, hi)]
		else:
			ats = [rng.randf_range(lo, hi)]
		var on_this: int = 0
		for at: float in ats:
			var lanes: Array[int] = []
			for lane: int in spot["lanes"]:
				if not credit_near(layout, h, lane, at, t.credit_margin):
					lanes.append(lane)
			if lanes.is_empty():
				continue
			var lane: int = lanes[rng.randi_range(0, lanes.size() - 1)]
			var lane_span: Vector2i = layout.hull_lanes(h)
			layout.enemies.append({"type": TYPE, "at": at, "lane": lane, "side": 0,
				"seed": hash([gen.config.level_seed, TYPE, placed]),
				"params": {"hull_start": float(h["start"]), "hull_end": float(h["end"]),
					"first_lane": lane_span.x, "last_lane": lane_span.y}})
			placed += 1
			on_this += 1
		introduced = introduced or on_this > 0


## Adds a plain ceiling for the turret's introduction when the level has none it fits on in time (see
## the header): by intro_seconds past the feature's start in a level that gives it one, anywhere in
## one that doesn't. Returns true if it added one.
static func _ensure_introduction(gen: LevelGenerator, t: BarnacleTurretTuning, rng: RandomNumberGenerator) -> bool:
	var layout: LevelLayout = gen.layout
	var start: float = gen.feature_start(TYPE)
	var timed: bool = gen.config.feature_starts.has(TYPE)
	var by: float = start + t.intro_seconds * gen.speed if timed else INF
	var first_fit: float = INF
	for h: Dictionary in layout.hulls:
		var w: Dictionary = mount_window(gen, h, t)
		if not w.is_empty():
			first_fit = minf(first_fit, float(w["lo"]))
	if first_fit < INF and first_fit <= by:
		return false
	# Before the first drone: its rules own every pad from its wave on (GDD §9.6).
	var limit: float = minf(minf(by, first_fit), layout.length - gen.config.end_clear_distance)
	for e: Dictionary in layout.enemies:
		if String(e.get("type", "")) == "drone":
			limit = minf(limit, float(e["at"]) - 1.0)
	var lead: float = t.after_pad_seconds * gen.speed
	var at: float = maxf(start - lead, gen.config.start_clear_distance)
	var full := Vector2i(0, layout.lane_count - 1)
	while at + lead <= limit:
		var lane: int = PadPlacement.pad_lane(gen, rng, at)
		if gen.add_hull_with_pad(lane, at, t.intro_ceiling_seconds, full):
			return true
		at += INTRO_STEP
	return false


## Where turrets may hang under ceiling `h`: {lanes (the lanes it covers but no pad's), lo, hi (track
## distances)}, or {} if none may (a one-lane ceiling, every lane a pad's, no pad, too short, or wholly
## before the feature's start).
static func mount_window(gen: LevelGenerator, h: Dictionary, t: BarnacleTurretTuning) -> Dictionary:
	var layout: LevelLayout = gen.layout
	if layout.hull_width(h) < 2:
		return {}
	var span: Vector2i = layout.hull_lanes(h)
	var pad_lanes: Array[int] = []
	var last_pad: float = -INF
	for p: Dictionary in layout.pads:
		var at: float = p["at"]
		if at >= float(h["start"]) and at <= float(h["end"]):
			last_pad = maxf(last_pad, at)
			if not pad_lanes.has(int(p["lane"])):
				pad_lanes.append(int(p["lane"]))
	if last_pad == -INF:
		return {}
	var lanes: Array[int] = []
	for lane: int in range(span.x, span.y + 1):
		if not pad_lanes.has(lane):
			lanes.append(lane)
	if lanes.is_empty():
		return {}
	var lo: float = maxf(last_pad + t.after_pad_seconds * gen.speed, gen.feature_start(TYPE))
	var hi: float = float(h["end"]) - t.before_end_seconds * gen.speed
	if hi < lo:
		return {}
	return {"lanes": lanes, "lo": lo, "hi": hi}


## True if a credit on ceiling `h` lies in `lane` within `margin` of track distance `at`: one already in
## the layout (a pattern's), or the rich one the generator will add in the ceiling's far lane from
## each of its pads (LevelGenerator._place_ceiling_credits). The line of credits along a pad's lane
## never matters here: turrets keep off pads' lanes.
static func credit_near(layout: LevelLayout, h: Dictionary, lane: int, at: float, margin: float) -> bool:
	for c: Dictionary in layout.credits:
		if String(c["surface"]) == "ceiling" and int(c["lane"]) == lane and absf(float(c["at"]) - at) < margin:
			return true
	var lanes: Vector2i = layout.hull_lanes(h)
	if lanes.y <= lanes.x:
		return false
	for p: Dictionary in layout.pads:
		var pad_at: float = p["at"]
		if pad_at < float(h["start"]) or pad_at > float(h["end"]):
			continue
		var pad_lane: int = p["lane"]
		var far_lane: int = lanes.x if 2 * pad_lane >= lanes.x + lanes.y else lanes.y
		if far_lane == lane and absf(lerpf(pad_at, float(h["end"]), FAR_CREDIT_SHARE) - at) < margin:
			return true
	return false


## The turrets on ceiling `h` (entries whose params name its start).
static func turrets_on(layout: LevelLayout, h: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in layout.enemies:
		if String(e.get("type", "")) == TYPE and absf(float((e.get("params", {}) as Dictionary).get("hull_start", -INF))
				- float(h["start"])) < 0.01:
			out.append(e)
	return out


static func tuning() -> BarnacleTurretTuning:
	var res: Resource = EnemyDirector.tuning_for(TYPE)
	return res as BarnacleTurretTuning if res is BarnacleTurretTuning else BarnacleTurretTuning.new()

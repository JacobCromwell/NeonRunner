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
##   every turret; the ceiling's line of credits runs along it; DESIGN-TBD, docs/questions/c1.md 3),
##   and off the ceiling's credits in its
##   lane (credit_margin; also the rich credit the generator adds in the far lane afterwards); nothing
##   before the feature's start (LevelConfig.feature_starts).
## - Where: at least after_pad_seconds past its ceiling's last pad (the rider sees it pop out before
##   taking the pad, and its first burst fits in), or tight_after_pad_seconds in the only lane beside a
##   pad's lane (tight_lane: a two-lane ceiling, or next to a pad at the edge, where the rider can only
##   dodge into the turret's own lane, so its bolts must come well before it); before_end_seconds
##   before the ceiling's end; two on one ceiling at least spacing_seconds apart.
## - How many: the first ceiling past the feature's start where one fits always gets one, alone (its
##   introduction: Marketplace 1 meets it gently, and every level that lists the feature has one);
##   each later one gets turrets at ceiling_share, a second one at pair_share from pair_min_scaling on
##   (so none in Marketplace 1) and only where two lanes are free of pads (never on a two-lane ceiling,
##   where a second turret in the same lane could hardly ever fire fairly). DESIGN-TBD
##   (docs/questions/c1.md).
## - The introduction comes soon after the feature's start (intro_seconds), in a level that gives the
##   feature one (LevelConfig.feature_starts); and a level that lists the feature always has a turret.
##   Where no ceiling it fits on lies in time, the rules add a plain ceiling for it over every lane
##   (intro_ceiling_seconds long, or shorter where that doesn't fit, but long enough to hold a turret)
##   at the first spot where one fits without clearing anything (LevelGenerator.add_hull_with_pad: its
##   pad and its landing zone are already safe, and no floor enemy's stretch reaches them; nor an
##   Octodog's planned run, _octodogs_clear), its pad before the level's first drone (the drone rules
##   own every pad after it, GDD §9.6) and in a lane no hover truck holds (PadPlacement.pad_lane); its
##   pad may come before the feature's start, its turret never does. Only then does a level differ from
##   the same level without the feature: by that ceiling, its credits, and the fill pass's fillers
##   (which keep off its landing and pad).
##   DESIGN-TBD (docs/questions/c1.md 4).
## The generator's fill pass (LevelConfig.fill_empty_seconds, after the rules) keeps nothing for a turret
## (keep_out): it never uses the floor, and the ceiling it hangs from keeps its own floor already, so a
## level is filled the same with or without turrets.
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
## Metres (at MovementTuning.REFERENCE_SPEED, stretched by the level's pace) between the spots tried for
## an introduction's ceiling; how much shorter each next length tried there is (seconds at run speed);
## and the room its shortest keeps for the turret's spot beyond after_pad_seconds and
## before_end_seconds.
const INTRO_STEP: float = 4.0
const INTRO_SHORTER_SECONDS: float = 0.5
const INTRO_SPARE_SECONDS: float = 0.3


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
	var spacing: float = t.spacing_seconds * gen.speed
	for h: Dictionary in hulls:
		var spots: Array[Dictionary] = mount_lanes(gen, h, t)
		if spots.is_empty():
			continue
		var count: int = 1
		if introduced:
			if rng.randf() >= t.ceiling_share_at(scaling):
				continue
			# A second one only where two lanes are free of pads (never on a two-lane ceiling).
			if rng.randf() < t.pair_share_at(scaling) and spots.size() >= 2:
				count = 2
		# The introduction stands within its reach of the feature's start when it can.
		var cap: float = INF if introduced else intro_by(gen, t)
		var order: Array[Dictionary] = spots.duplicate()
		for i: int in range(order.size() - 1, 0, -1):
			var j: int = rng.randi_range(0, i)
			var tmp: Dictionary = order[i]
			order[i] = order[j]
			order[j] = tmp
		var taken: Array[float] = []
		for spot: Dictionary in order:
			if taken.size() >= count:
				break
			var lo: float = spot["lo"]
			var hi: float = spot["hi"]
			if not taken.is_empty():
				# Spaced from the first: after it if there's room, else before it.
				if hi >= taken[0] + spacing:
					lo = maxf(lo, taken[0] + spacing)
				else:
					hi = minf(hi, taken[0] - spacing)
			elif count == 2 and hi - spacing >= lo:
				# The first of two leaves room for the second after it.
				hi -= spacing
			if hi < lo:
				continue
			hi = maxf(lo, minf(hi, cap))
			var at: float = rng.randf_range(lo, hi)
			var lane: int = spot["lane"]
			if credit_near(layout, h, lane, at, t.credit_margin):
				continue
			var lane_span: Vector2i = layout.hull_lanes(h)
			layout.enemies.append({"type": TYPE, "at": at, "lane": lane, "side": 0,
				"seed": hash([gen.config.level_seed, TYPE, placed]),
				"params": {"hull_start": float(h["start"]), "hull_end": float(h["end"]),
					"first_lane": lane_span.x, "last_lane": lane_span.y}})
			placed += 1
			taken.append(at)
		introduced = introduced or not taken.is_empty()


## Adds a plain ceiling for the turret's introduction when the level has none it fits on in time (see
## the header): by intro_seconds past the feature's start in a level that gives it one, anywhere in
## one that doesn't. Returns true if it added one.
static func _ensure_introduction(gen: LevelGenerator, t: BarnacleTurretTuning, rng: RandomNumberGenerator) -> bool:
	var layout: LevelLayout = gen.layout
	var start: float = gen.feature_start(TYPE)
	var by: float = intro_by(gen, t)
	var first_fit: float = INF
	for h: Dictionary in layout.hulls:
		for spot: Dictionary in mount_lanes(gen, h, t):
			first_fit = minf(first_fit, float(spot["lo"]))
	if first_fit < INF and first_fit <= by:
		return false
	# The turret comes by then, and before any ceiling it already fits on.
	var turret_by: float = minf(minf(by, first_fit), layout.length - gen.config.end_clear_distance)
	# Its pad before the first drone: the drone's rules own every pad from its wave on (GDD §9.6).
	var pad_by: float = turret_by
	for e: Dictionary in layout.enemies:
		if String(e.get("type", "")) == "drone":
			pad_by = minf(pad_by, float(e["at"]) - 1.0)
	# Its length: intro_ceiling_seconds, or shorter where that doesn't fit, down to the shortest that
	# still holds a turret past its pad (after_pad_seconds) and before its end. Its pad may come before
	# the feature's start, as long as the turret stands past it.
	var lengths: Array[float] = [t.intro_ceiling_seconds]
	var shortest: float = t.after_pad_seconds + t.before_end_seconds + INTRO_SPARE_SECONDS
	while lengths[-1] - INTRO_SHORTER_SECONDS >= shortest:
		lengths.append(lengths[-1] - INTRO_SHORTER_SECONDS)
	var lead: float = t.after_pad_seconds * gen.speed
	var tail: float = t.before_end_seconds * gen.speed
	var at: float = maxf(start - (t.intro_ceiling_seconds * gen.speed - tail), gen.config.start_clear_distance)
	var full := Vector2i(0, layout.lane_count - 1)
	while at <= pad_by and maxf(at + lead, start) <= turret_by:
		var lane: int = PadPlacement.pad_lane(gen, rng, at)
		for seconds: float in lengths:
			# Room for the turret on it, past the feature's start.
			if maxf(at + lead, start) > at + seconds * gen.speed - tail:
				continue
			if gen.add_hull_with_pad(lane, at, seconds, full):
				if _octodogs_clear(gen):
					return true
				PadPlacement.remove_hull(layout, layout.hulls[-1])
		at += gen.metres(INTRO_STEP)
	return false


## True if every Octodog's planned charges still have their clear stretch and its whole run still keeps
## off pads and ceiling landings, as the Octodog's rules planned them (Octodog.window_clear,
## pad_or_landing_between, at the level's pace): an introduction's ceiling never lands on a dog's run.
static func _octodogs_clear(gen: LevelGenerator) -> bool:
	var ot := EnemyDirector.tuning_for("octodog") as OctodogTuning
	if ot == null:
		return true
	var window: float = ot.window_length(gen.speed, gen.config.enemy_scaling, gen.pace)
	var stop: float = ot.stop_distance(gen.speed, gen.config.enemy_scaling, gen.pace)
	for e: Dictionary in gen.layout.enemies:
		if String(e.get("type", "")) != "octodog":
			continue
		var charges: Array = (e.get("params", {}) as Dictionary).get("charge_at", [])
		if charges.is_empty():
			continue
		for a: Variant in charges:
			if not Octodog.window_clear(gen.layout, float(a), float(a) + window, gen.pace):
				return false
		if Octodog.pad_or_landing_between(gen.layout, float(charges[0]) - gen.metres(6.0),
				float(charges[-1]) + stop + gen.metres(2.0), gen.pace):
			return false
	return true


## What the generator's fill pass keeps off around turret entry `e` (LevelGenerator.fill_keep_outs):
## nothing (an empty span). It never touches the floor, and its ceiling keeps the floor under it and its
## landing zone and pads' spots already.
static func keep_out(_gen: LevelGenerator, _e: Dictionary) -> Vector2:
	return Vector2(INF, -INF)


## The track distance the level's first turret comes by: intro_seconds past the feature's start in a
## level that gives it one (LevelConfig.feature_starts), INF in one that doesn't.
static func intro_by(gen: LevelGenerator, t: BarnacleTurretTuning) -> float:
	if not gen.config.feature_starts.has(TYPE):
		return INF
	return gen.feature_start(TYPE) + t.intro_seconds * gen.speed


## Where turrets may hang under ceiling `h`: one {lane, lo, hi} per lane it covers that no pad is in,
## lo and hi the track distances between which a turret there may stand (after_pad_seconds past the
## ceiling's last pad, or tight_after_pad_seconds where that lane is the only one beside a pad's lane,
## see tight_lane(); before_end_seconds before its end; never before the feature's start); [] if none
## may (a one-lane ceiling, every lane a pad's, no pad, or too short).
static func mount_lanes(gen: LevelGenerator, h: Dictionary, t: BarnacleTurretTuning) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var layout: LevelLayout = gen.layout
	if layout.hull_width(h) < 2:
		return out
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
		return out
	var hi: float = float(h["end"]) - t.before_end_seconds * gen.speed
	for lane: int in range(span.x, span.y + 1):
		if pad_lanes.has(lane):
			continue
		var after: float = t.tight_after_pad_seconds if tight_lane(span, pad_lanes, lane) else t.after_pad_seconds
		var lo: float = maxf(last_pad + after * gen.speed, gen.feature_start(TYPE))
		if hi >= lo:
			out.append({"lane": lane, "lo": lo, "hi": hi})
	return out


## True if a turret in `lane` would stand in the only lane beside a pad's lane (`span` the ceiling's
## lanes): a rider riding on from that pad can only dodge into the turret's own lane (always so on a
## two-lane ceiling), so its bolts may only come well before it (BarnacleTurret._path_fair), and it
## needs more room after the pad to fire at all.
static func tight_lane(span: Vector2i, pad_lanes: Array[int], lane: int) -> bool:
	for p: int in pad_lanes:
		var others: int = 0
		for n: int in [p - 1, p + 1]:
			if n >= span.x and n <= span.y and n != lane:
				others += 1
		if absi(p - lane) == 1 and others == 0:
			return true
	return false


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

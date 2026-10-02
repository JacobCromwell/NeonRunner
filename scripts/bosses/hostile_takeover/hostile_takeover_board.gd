class_name HostileTakeoverBoard
extends RefCounted
## Phase 1, The Board (GDD §10: "security cyborgs guard the roofs, a Tithe Collector skims credits, and
## partial wall fences run along the track's sound barriers. Each carriage coupling glows red and sits in
## one lane above the gap between carriages"). Carriage by carriage, as the train is laid ahead, it plans:
## - the lane of the coupling over the carriage's gap (lanes): seeded, never the last one's lane
##   (coupling_same_lane off) and at most coupling_max_shift from it, so reaching each takes a move;
## - its guards: the zone's cyborgs (the skin's look: the Corporate zone's VR runners), as many as the
##   tuning's list says (at most one fewer than the lanes), each at a seeded spot and lane where nothing
##   it does reaches what the fight needs: never within the cyborgs' own margin of a gap (CyborgRules:
##   the level's rule, which the Cyborg also keeps while it walks or flees), never where its walk or its
##   panic run could reach a coupling's lane in its run-up (approach_clear before the gap) or where the
##   coupling's bounce comes down (landing_clear after it), and guard_spacing from the carriage's other
##   guard, so a way through is always open;
## - a Tithe Collector on every tithe_every-th carriage (its own approach and weaving: TitheCollector) and,
##   as it comes into play, the credits it skims: a short trail on the roof ahead of it in its lane
##   (lay_tithe; a boss's track carries no credits of its own, docs/questions/e5b.md);
## - a partial wall fence on its middle (the low band or the high one in turn, a seeded side), only where
##   the level's rules allow one on the arena's track (BossArena.wall_fence_problem: B5's keep-outs, among
##   them the drop window clear of gaps and floor enemies in the outer lane beside it), pulsing as the
##   zone's do at the arena's difficulty.
## Guards and Collectors go onto the track as enemies (BossArena.add_pieces: they come into play at their
## spawn lead like a level's); wall fences as track pieces past the built track (stream_from). Every choice
## comes from a seed of its carriage, so the fight plays the same on every attempt. In E5b-a every phase
## plays The Board (phases 2 and 3 are steps E5b-b and E5b-c).

## A carriage is planned once the built track reaches within this of its roof's start (so the whole of
## it, its wall fence too, is still ahead of the built track: stream_from moves on a chunk at a time).
const PLAN_MARGIN: float = 60.0
## Tries for each guard's spot, and for a wall fence (other side, then a little along).
const GUARD_TRIES: int = 16
const FENCE_SHIFTS: Array[float] = [0.0, -0.12, 0.12, -0.22, 0.22]
## Where on its carriage's roof a Tithe Collector appears (a share of the roof), and how far ahead of it its
## trail begins (metres at 18 m/s).
const TITHE_SPOT: float = 0.12
const TRAIL_LEAD: float = 4.0
const CYBORG_TUNING: String = "res://data/enemies/cyborg.tres"
const CyborgRules = preload("res://scripts/enemies/cyborg_rules.gd")

var boss: HostileTakeover
var tuning: HostileTakeoverTuning
var train: HostileTakeoverTrain
## Each gap's coupling lane (gap index → lane).
var lanes: Dictionary = {}
## What each carriage got (carriage index → {k, guards: [{at, lane, panic}], tithe: its spot or -1,
## wall_fence: its entry or {}}), for the fairness checks and tests.
var carriages: Dictionary = {}
## The last carriage planned, and the wall fences left out by a level's rule.
var planned: int = -1
var refused_fences: int = 0
## Trails laid for Collectors (their credits), and credits laid in all.
var trails: int = 0
var credits_laid: int = 0

var _cyborg: CyborgTuning


func _init(p_boss: HostileTakeover) -> void:
	boss = p_boss
	tuning = boss.tuning
	train = boss.train
	var res: Resource = load(CYBORG_TUNING)
	_cyborg = res as CyborgTuning if res is CyborgTuning else CyborgTuning.new()


## Plans every carriage the built track is about to reach (see PLAN_MARGIN), in order.
func tick() -> void:
	var limit: float = boss.arena.stream_from() + PLAN_MARGIN
	while train.roof(planned + 1).x < limit:
		plan(planned + 1)


## Plans carriage `k` (see the header).
func plan(k: int) -> void:
	planned = maxi(planned, k)
	lanes[k] = _coupling_lane(k)
	var rec := {"k": k, "guards": [], "tithe": -1.0, "wall_fence": {}}
	var extra := LevelLayout.new()
	extra.lane_count = boss.lane_count()
	for g: Dictionary in _guards(k):
		rec["guards"].append(g)
		extra.enemies.append({"type": "cyborg", "at": g["at"], "lane": g["lane"], "side": 0,
			"seed": hash([String(boss.def.id), "guard", k, g["lane"], boss.rng.seed]), "params": {"panic": g["panic"]}})
	if tuning.tithe_on(k):
		var at: float = tithe_spot(k)
		rec["tithe"] = at
		extra.enemies.append({"type": "tithe_collector", "at": at, "lane": boss.lane_count() / 2, "side": 0,
			"seed": hash([String(boss.def.id), "tithe", k, boss.rng.seed]), "params": {}})
	if not extra.enemies.is_empty():
		boss.arena.add_pieces(extra)
	var fence: Dictionary = _wall_fence(k)
	if not fence.is_empty():
		rec["wall_fence"] = fence
		var walls := LevelLayout.new()
		walls.lane_count = boss.lane_count()
		walls.wall_fences.append(fence)
		boss.arena.add_pieces(walls)
	carriages[k] = rec
	boss.log_event(&"carriage_planned", {"carriage": k, "coupling_lane": lanes[k], "guards": (rec["guards"] as Array).size(),
		"tithe": float(rec["tithe"]) >= 0.0, "wall_fence": not fence.is_empty()})


## Where carriage `k`'s Tithe Collector is placed (its layout entry's track distance) so that it appears
## (its start_ahead in front of the runner, once they're within its spawn lead of it) TITHE_SPOT of the
## way along the roof, with the roof ahead of it for its trail.
func tithe_spot(k: int) -> float:
	var roof: Vector2 = train.roof(k)
	var appear: float = lerpf(maxf(roof.x, 0.0), roof.y, TITHE_SPOT)
	var t := EnemyDirector.tuning_for("tithe_collector") as TitheCollectorTuning
	var ahead: float = t.start_ahead_at(boss.run_pace()) if t != null else 30.0
	return appear - ahead + EnemyDirector.lead_for("tithe_collector")


## The coupling lane of gap `k`: seeded, never the last one's (unless the tuning allows it) and at most
## coupling_max_shift lanes from it.
func _coupling_lane(k: int) -> int:
	var n: int = boss.lane_count()
	if n <= 1:
		return 0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([String(boss.def.id), "coupling", k, boss.rng.seed])
	var prev: int = int(lanes.get(k - 1, -1))
	var options: Array[int] = []
	for lane: int in n:
		if prev >= 0 and lane == prev and not tuning.coupling_same_lane:
			continue
		if prev >= 0 and absi(lane - prev) > tuning.coupling_max_shift:
			continue
		options.append(lane)
	if options.is_empty():
		for lane: int in n:
			options.append(lane)
	return options[rng.randi() % options.size()]


## Carriage `k`'s guards: [{at, lane, panic}] (see the header).
func _guards(k: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var count: int = tuning.guards_on(k, boss.lane_count())
	if count <= 0:
		return out
	var roof: Vector2 = train.roof(k)
	var margin: float = CyborgRules.obstacle_margin_at(_cyborg, boss.run_pace())
	var lo: float = maxf(roof.x, 0.0) + margin
	var hi: float = roof.y - margin
	if hi <= lo:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([String(boss.def.id), "guards", k, boss.rng.seed])
	for i: int in count:
		for attempt: int in GUARD_TRIES:
			var g := {"at": rng.randf_range(lo, hi), "lane": rng.randi() % boss.lane_count(),
				"panic": rng.randf() < _cyborg.panic_chance}
			if guard_fits(k, g, out):
				out.append(g)
				break
	return out


## True if guard `g` ({at, lane, panic}) may stand on carriage `k` beside `others` (see the header).
func guard_fits(k: int, g: Dictionary, others: Array[Dictionary]) -> bool:
	var pace: float = boss.run_pace()
	var at: float = float(g["at"])
	var lane: int = int(g["lane"])
	for o: Dictionary in others:
		if absf(float(o["at"]) - at) < tuning.guard_spacing * pace:
			return false
	var reach: Vector2 = guard_reach(k, g)
	var roof: Vector2 = train.roof(k)
	if lane == int(lanes.get(k, -1)) and reach.y > roof.y - tuning.approach_clear * pace:
		return false
	if k > 0 and lane == int(lanes.get(k - 1, -1)) and reach.x < roof.x + tuning.landing_clear * pace:
		return false
	return true


## The stretch of carriage `k`'s roof guard `g` may cover: a normal cyborg walks toward the runner up to
## walk_max, a panicking one runs ahead up to panic_run_max (at the run's pace), never nearer a gap than
## the cyborgs' margin (the Cyborg's own limits).
func guard_reach(k: int, g: Dictionary) -> Vector2:
	var at: float = float(g["at"])
	var roof: Vector2 = train.roof(k)
	var margin: float = CyborgRules.obstacle_margin_at(_cyborg, boss.run_pace())
	if g["panic"]:
		return Vector2(at, minf(at + _cyborg.panic_run_max * boss.run_pace(), roof.y - margin))
	return Vector2(maxf(at - _cyborg.walk_max, roof.x + margin), at)


## A partial wall fence on carriage `k`, or {} (see the header).
func _wall_fence(k: int) -> Dictionary:
	if k < tuning.wall_fences_from:
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([String(boss.def.id), "wall_fence", k, boss.rng.seed])
	if rng.randf() >= tuning.wall_fence_share:
		return {}
	var wt: WallFenceTuning = WallFencePlacement.tuning()
	var difficulty: float = boss.arena.config.difficulty if boss.arena.config != null else 0.0
	var on: float = WallFenceTuning.by_difficulty(wt.on_seconds_easy, wt.on_seconds_hard, difficulty) \
		+ rng.randf_range(-wt.pulse_jitter_seconds, wt.pulse_jitter_seconds)
	var off: float = WallFenceTuning.by_difficulty(wt.off_seconds_easy, wt.off_seconds_hard, difficulty) \
		+ rng.randf_range(-wt.pulse_jitter_seconds, wt.pulse_jitter_seconds)
	var band: String = "low" if k % 2 == 0 else "high"
	var side: int = -1 if rng.randf() < 0.5 else 1
	var phase: float = rng.randf()
	var roof: Vector2 = train.roof(k)
	var mid: float = (maxf(roof.x, 0.0) + roof.y) * 0.5
	var length: float = roof.y - maxf(roof.x, 0.0)
	var from: float = boss.arena.stream_from() + 1.0
	for shift: float in FENCE_SHIFTS:
		for s: int in [side, -side]:
			var at: float = mid + shift * length
			if at < from:
				continue
			var entry: Dictionary = WallFencePlan.make(s, at, band, on, off, phase)
			if boss.arena.wall_fence_problem(entry) == "":
				return entry
	refused_fences += 1
	return {}


## A Tithe Collector came into play (GDD §10: it "skims credits"): a short trail of credits on the roof
## ahead of it in its lane, for it to vacuum up as it goes (TitheCollector), up to the next gap. Returns
## how many were laid.
func lay_tithe(collector: Enemy) -> int:
	if tuning.tithe_credits <= 0 or collector == null:
		return 0
	var world: RunWorld = boss.world
	var lane: int = world.geo.lane_at(collector.global_position.x)
	var start: float = collector.track_distance() + TRAIL_LEAD * boss.run_pace()
	var spacing: float = tuning.tithe_spacing * boss.run_pace()
	var gap: int = train.next_gap(start)
	var stop: float = train.gap_start(gap) - 1.0
	var entries: Array[Dictionary] = []
	for i: int in tuning.tithe_credits:
		var at: float = start + i * spacing
		if at > stop:
			break
		entries.append({"surface": "floor", "lane": lane, "at": at, "value": tuning.tithe_value, "height": 0.7})
	if entries.is_empty():
		return 0
	world.credits.place(entries)
	trails += 1
	credits_laid += entries.size()
	boss.log_event(&"tithe_trail", {"lane": lane, "count": entries.size(), "from": start})
	return entries.size()

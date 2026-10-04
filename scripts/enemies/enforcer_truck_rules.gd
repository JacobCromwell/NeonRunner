extends RefCounted
## Generator rules for the Enforcer Truck (GDD §9.13, owner, October 4, 2026). It can only be destroyed by
## baiting an Octodog's lunge or a Buzz Overdrive's charge into it, so it is placed around those charges:
## "each one is placed only where at least one Octodog or Buzz Overdrive charge comes during its chase, so it
## always has a chance to be destroyed". LevelGenerator runs apply() for levels with the `enforcer_truck`
## feature after the rules of every other feature (RUN_AFTER): the Octodogs' planned charges and the Buzz
## Overdrives' cuts are final by then (nothing later moves or drops them).
## - Its baits: each Octodog's first planned wind-up (params "charge_at"; its later charges come after it) and
##   each Buzz Overdrive's charge (its cut's charge_at, FloorCutPlan). A truck arrives (its entry's `at`: the
##   runner's distance as it drives in behind them) so that one of them comes bait_after_seconds to
##   chase_seconds - bait_before_seconds after it, at a seeded spot within bait_prefer_min/max_seconds where
##   it can (the runner meets it, sees a volley or two, then the bait). Its params list every bait planned in
##   its chase ("baits").
## - Up to per_level_max a level (GDD §9.13: up to two), never two at once: each one's chase, and the
##   seconds it takes to drop back, keep spacing_seconds from the next one's arrival. The level's earliest
##   baits get them first.
## - Where it may arrive: after the run-up and the feature's start, and never while another bait attacks (an
##   Octodog's planned charges, a Buzz Overdrive's rev and charge). In a level paced in bursts (The Hush) it
##   arrives in a burst where it can (LevelGenerator.pacing_pools). Its chase may run on to the level's end.
##   Its entry's `at` is where it arrives, never a spot it takes up ahead of the runner
##   (EnemyTuning.behind_runner), so no Octodog's charge keeps clear of it.
## It takes no room on the track: it drives behind the runner, never on the floor ahead (its tuning's
## uses_floor is false), and its volleys check their escape at run time (EnforcerTruck.escape_clear). So the
## fill pass, the doodads and every other pass keep nothing for it (keep_out), and its entries take seeds of
## their own rather than LevelGenerator.add_enemy's running count: a level with the feature differs only by
## its trucks (and by what the danger density pass adds for its higher enemy count). It has no patterns:
## these rules place every one. A level with no bait its chase can take gets none (GDD §9.13: it appears
## where Octodogs or Buzz Overdrives appear). DESIGN-TBD (docs/questions/c6.md): the bait's place in its
## chase, the spacing, which baits get one.

const TYPE: String = "enforcer_truck"
## Every feature whose rules place, move or drop enemies, plan charges or cuts, or add ceilings: the trucks
## are planned on the level's final baits.
const RUN_AFTER: Array[String] = ["ramps", "ceilings", "pulsing", "speed_pads", "cyborg", "window_cyborg", "host",
	"hover_truck", "octodog", "screech", "screech_vents", "drone", "generator", "wall_fences", "wall_fences_partial",
	"buzz_overdrive", "barnacle_turret", "tithe_collector", "resonator", "gilded_sentinel"]
const BuzzRules = preload("res://scripts/enemies/buzz_overdrive_rules.gd")
## The arrival offsets tried around the preferred one (seconds between them).
const OFFSET_STEP: float = 0.5


static func apply(gen: LevelGenerator) -> void:
	var t: EnforcerTruckTuning = tuning()
	if t.per_level_max <= 0:
		return
	var rng: RandomNumberGenerator = gen.rng_for(TYPE)
	var baits: Array[Dictionary] = bait_points(gen)
	var keep_outs: Array[Vector2] = arrival_keep_outs(gen)
	var chases: Array[Vector2] = []
	var placed: int = 0
	for b: Dictionary in baits:
		if placed >= t.per_level_max:
			break
		var at: float = _arrival_for(gen, t, rng, float(b["at"]), keep_outs, chases)
		if is_nan(at):
			continue
		var params := {"baits": baits_in(gen, t, baits, at)}
		gen.layout.enemies.append({"type": TYPE, "at": at, "lane": gen.layout.lane_count / 2, "side": 0,
			"seed": hash([gen.config.level_seed, TYPE, placed]), "params": params})
		chases.append(chase_span(gen, t, at))
		placed += 1


static func tuning() -> EnforcerTruckTuning:
	var res: Resource = EnemyDirector.tuning_for(TYPE)
	return res as EnforcerTruckTuning if res is EnforcerTruckTuning else EnforcerTruckTuning.new()


## Every Enforcer Truck in the layout, along the track.
static func trucks_in(layout: LevelLayout) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in layout.enemies:
		if String(e.get("type", "")) == TYPE:
			out.append(e)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
	return out


## The level's baits, along the track: {at (the runner's distance as the charge's warning starts), kind}:
## each Octodog's first planned wind-up and each Buzz Overdrive's charge.
static func bait_points(gen: LevelGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in gen.layout.enemies:
		match String(e.get("type", "")):
			"octodog":
				var anchors: Array = (e.get("params", {}) as Dictionary).get("charge_at", [])
				if not anchors.is_empty():
					out.append({"at": float(anchors[0]), "kind": "octodog"})
			"buzz_overdrive":
				var cut: Dictionary = BuzzRules.cut_of(gen.layout, e)
				if not cut.is_empty():
					out.append({"at": FloorCutPlan.charge_at(cut), "kind": "buzz_overdrive"})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
	return out


## The baits a truck arriving at `at` has in its chase: where it may meet them (bait_window).
static func baits_in(gen: LevelGenerator, t: EnforcerTruckTuning, baits: Array[Dictionary], at: float) -> Array[float]:
	var out: Array[float] = []
	var w: Vector2 = bait_window(gen, t, at)
	for b: Dictionary in baits:
		if float(b["at"]) >= w.x - 0.001 and float(b["at"]) <= w.y + 0.001:
			out.append(float(b["at"]))
	return out


## Where a bait may come for a truck arriving at `at`: bait_after_seconds after it to bait_before_seconds
## before it would give up (runner distances).
static func bait_window(gen: LevelGenerator, t: EnforcerTruckTuning, at: float) -> Vector2:
	return Vector2(at + t.bait_after_seconds * gen.speed, at + (t.chase_seconds - t.bait_before_seconds) * gen.speed)


## The track a truck arriving at `at` takes up: its chase and its drop back out of sight.
static func chase_span(gen: LevelGenerator, t: EnforcerTruckTuning, at: float) -> Vector2:
	return Vector2(at, at + (t.chase_seconds + t.leave_seconds) * gen.speed)


## Where no truck may arrive (it would drive in while a bait attacks): each Octodog's planned charges (from a
## little before its first wind-up to the end of its last charge's stretch), each Buzz Overdrive's attack (from
## its rev's warning to the end of its cut, FloorCutPlan.attack_window). (Its entry never holds back an Octodog
## whose charges a wait moved on: Octodog.charge_clear leaves out enemies that only drive behind the runner,
## EnemyTuning.behind_runner.)
static func arrival_keep_outs(gen: LevelGenerator) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var dog := EnemyDirector.tuning_for("octodog") as OctodogTuning
	if dog == null:
		dog = OctodogTuning.new()
	var window: float = dog.window_length(gen.speed, gen.config.enemy_scaling, gen.pace)
	for e: Dictionary in gen.layout.enemies:
		match String(e.get("type", "")):
			"octodog":
				var anchors: Array = (e.get("params", {}) as Dictionary).get("charge_at", [])
				if not anchors.is_empty():
					out.append(Vector2(float(anchors[0]) - gen.metres(Octodog.OTHER_ENEMY_BEFORE),
						float(anchors[-1]) + window))
			"buzz_overdrive":
				var cut: Dictionary = BuzzRules.cut_of(gen.layout, e)
				if not cut.is_empty():
					out.append(FloorCutPlan.attack_window(cut, gen.speed))
	return out


## Where a truck whose chase takes the bait at `bait` arrives, or NAN if nowhere fits (arrival_problem): the
## preferred spot first (a seeded one bait_prefer_min/max_seconds before the bait), then the others in
## OFFSET_STEP steps nearest to it first; in a level paced in bursts, those in a burst before the rest.
static func _arrival_for(gen: LevelGenerator, t: EnforcerTruckTuning, rng: RandomNumberGenerator, bait: float,
		keep_outs: Array[Vector2], chases: Array[Vector2]) -> float:
	var lo: float = t.bait_after_seconds
	var hi: float = t.chase_seconds - t.bait_before_seconds
	var prefer: float = clampf(rng.randf_range(t.bait_prefer_min_seconds, t.bait_prefer_max_seconds), lo, hi)
	var offsets: Array[float] = []
	var o: float = lo
	while o <= hi + 0.001:
		offsets.append(o)
		o += OFFSET_STEP
	offsets.sort_custom(func(a: float, b: float) -> bool: return absf(a - prefer) < absf(b - prefer))
	offsets.push_front(prefer)
	var spots: Array[float] = []
	for off: float in offsets:
		spots.append(bait - off * gen.speed)
	for pool: Array[float] in gen.pacing_pools(spots, TYPE):
		for at: float in pool:
			if arrival_problem(gen, t, at, keep_outs, chases) == "":
				return at
	return NAN


## Why a truck can't arrive at `at` ("" if it can): before the run-up or the feature's start, an Octodog's
## charges or a Buzz Overdrive's attack there (keep_outs), or another truck's chase (with spacing_seconds).
static func arrival_problem(gen: LevelGenerator, t: EnforcerTruckTuning, at: float, keep_outs: Array[Vector2],
		chases: Array[Vector2]) -> String:
	if at < maxf(gen.config.start_clear_distance, gen.feature_start(TYPE)) - 0.001:
		return "before the run-up or the feature's start"
	for k: Vector2 in keep_outs:
		if at >= k.x and at <= k.y:
			return "an Octodog's charges or a Buzz Overdrive's attack is on"
	var span: Vector2 = chase_span(gen, t, at)
	var room: float = t.spacing_seconds * gen.speed
	for c: Vector2 in chases:
		if span.x < c.y + room and span.y + room > c.x:
			return "another Enforcer Truck's chase is on"
	return ""


## What the generator's fill pass keeps off around a truck's entry (LevelGenerator.fill_keep_outs): nothing
## (an empty span). It drives behind the runner, never on the floor ahead, and its volleys find their own
## escape at run time.
static func keep_out(_gen: LevelGenerator, _e: Dictionary) -> Vector2:
	return Vector2(INF, -INF)


## Every placement rule a generated level's trucks break, for the tests: more than per_level_max, two at
## once, an arrival where none may be, or no bait in a chase. [] if none.
static func problems(gen: LevelGenerator) -> PackedStringArray:
	var out: PackedStringArray = []
	var t: EnforcerTruckTuning = tuning()
	var trucks: Array[Dictionary] = trucks_in(gen.layout)
	if trucks.size() > t.per_level_max:
		out.append("%d Enforcer Trucks (at most %d)" % [trucks.size(), t.per_level_max])
	var baits: Array[Dictionary] = bait_points(gen)
	var keep_outs: Array[Vector2] = arrival_keep_outs(gen)
	var chases: Array[Vector2] = []
	for e: Dictionary in trucks:
		var at: float = float(e["at"])
		var why: String = arrival_problem(gen, t, at, keep_outs, chases)
		if why != "":
			out.append("the truck arriving at %.1f m: %s" % [at, why])
		if baits_in(gen, t, baits, at).is_empty():
			out.append("the truck arriving at %.1f m has no bait in its chase" % at)
		chases.append(chase_span(gen, t, at))
	return out

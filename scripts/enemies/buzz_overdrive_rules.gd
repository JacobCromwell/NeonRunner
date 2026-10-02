extends RefCounted
## Generator rules for the Buzz Overdrive (GDD §9.9: "the generator plans each cut in advance (lane,
## start and end), so levels stay fair and identical on every attempt; the saw is just the visible
## cause"). Its patterns (data/patterns/buzz_overdrive.json) stand one where its encounter begins: an
## entry's `at` from the pattern is where the player is when it sets off, rolling ahead of them
## (FloorCutPlan.lead_at), and the pattern's length holds the whole encounter. LevelGenerator runs
## apply() for levels with the feature after the rules of every feature that puts things on the floor
## or plans a big attack (RUN_AFTER; the Resonator's and the Barnacle Turret's rules run after these),
## so each cut is planned around the level's final layout:
## - Each entry gets its cut (plan(): the rev at the level's enemy_scaling, the charge and the roll from
##   BuzzOverdriveTuning, at the level's run speed and pace) in its own lane, else in another (seeded
##   order), wherever B4's limits allow (CutPlacement: GDD §9.9's limits, LevelGenerator.cut_problem:
##   one at a time, never a lane with a ramp, a pad or a ceiling's landing zone, the other lanes whole,
##   nothing else going on, room to leave its lane). The entry then moves to the cut's end, in the cut's
##   lane: where its cause is when the charge starts (FloorCutPlan, cut_of).
## - One that fits in no lane where its pattern put it tries a little earlier or later (MOVE_SECONDS:
##   around a ceiling's landing zone, say: from a level's first drone on, a pad and its ceiling come
##   every 8–10 s), never before the feature's start; one that fits nowhere is dropped, and the stretch
##   its pattern held is left to the fill pass.
## - Its introduction (a level that gives the feature a start, LevelConfig.feature_starts: Corporate 1):
##   if no Buzz Overdrive sets off within intro_seconds of the start (the pattern picked there didn't fit:
##   a hover truck's stay, a drone wave, a ceiling's landing zone), one is added at the first spot there
##   where a cut fits, so the player meets it soon after its hint as the schedule means.
## - In a level that guarantees its features (LevelConfig.guarantee_features), if none is left, one is
##   added at the first spot past the feature's start where a cut fits (in a level paced in bursts, in
##   a burst first: LevelGenerator.pacing_pools), so the level needn't be built again.

const RUN_AFTER: Array[String] = ["ramps", "ceilings", "pulsing", "speed_pads", "cyborg", "window_cyborg", "host",
	"hover_truck", "octodog", "screech", "screech_vents", "drone", "generator", "wall_fences", "wall_fences_partial"]
const TYPE: String = "buzz_overdrive"
const CutPlacement = preload("res://scripts/enemies/cut_placement.gd")
## Metres (at the reference speed, stretched by the pace) between the spots tried for a guaranteed one.
const GUARANTEE_STEP: float = 12.0
## Where an entry's cut doesn't fit where its pattern put it, the moves tried, in this order (seconds at
## run speed; DESIGN-TBD, docs/questions/c2.md).
const MOVE_SECONDS: Array[float] = [-1.0, 1.0, -2.0, 2.0, 3.0]


static func apply(gen: LevelGenerator) -> void:
	var t: BuzzOverdriveTuning = tuning()
	var layout: LevelLayout = gen.layout
	var rng: RandomNumberGenerator = gen.rng_for(TYPE)
	var dropped: Array[Dictionary] = []
	var earliest: float = maxf(gen.feature_start(TYPE), gen.config.start_clear_distance)
	for e: Dictionary in tanks_in(layout):
		var at: float = float(e["at"])
		var placed: bool = place_at(gen, t, rng, e, at, int(e.get("lane", 0)))
		for move: float in MOVE_SECONDS:
			if placed:
				break
			if at + move * gen.speed >= earliest:
				placed = place_at(gen, t, rng, e, at + move * gen.speed, int(e.get("lane", 0)))
		if not placed:
			dropped.append(e)
	for e: Dictionary in dropped:
		layout.enemies.erase(e)
	if gen.config.feature_starts.has(TYPE):
		_introduce(gen, t, rng, earliest)
	if gen.config.guarantee_features and tanks_in(layout).is_empty():
		_add_guaranteed(gen, t, rng)


## Plans `e`'s cut with the player at `anchor` when it sets off, in lane `lane` or else the others in a
## seeded order, and moves `e` to the cut's end in its lane. False (and nothing changed) if no lane fits.
static func place_at(gen: LevelGenerator, t: BuzzOverdriveTuning, rng: RandomNumberGenerator, e: Dictionary,
		anchor: float, lane: int) -> bool:
	var lanes: int = gen.layout.lane_count
	var order: Array[int] = [clampi(lane, 0, lanes - 1)]
	var others: Array[int] = []
	for l: int in lanes:
		if l != order[0]:
			others.insert(rng.randi_range(0, others.size()), l)
	order.append_array(others)
	var was: Array = [e.get("at", anchor), e.get("lane", lane)]
	for l: int in order:
		var cut: Dictionary = plan(gen, t, l, anchor)
		# Stood where its cause will be, so the limits know it as the cut's own (not another enemy).
		e["at"] = float(cut["end"])
		e["lane"] = l
		if CutPlacement.place(gen, cut):
			return true
	e["at"] = was[0]
	e["lane"] = was[1]
	return false


## A cut for a Buzz Overdrive that sets off with the player at `anchor`, in `lane`, at the level's run
## speed, pace and enemy_scaling (FloorCutPlan.make plus its `lead`, the roll ahead of the player).
static func plan(gen: LevelGenerator, t: BuzzOverdriveTuning, lane: int, anchor: float) -> Dictionary:
	return plan_for(t, lane, anchor, gen.speed, gen.pace, gen.config.enemy_scaling)


## plan() for a run speed, pace and enemy scaling of one's own (tests, the showcase, boss fights).
static func plan_for(t: BuzzOverdriveTuning, lane: int, anchor: float, run_speed: float, pace: float,
		scaling: float) -> Dictionary:
	var speed: float = t.charge_speed_at(pace)
	var charge: float = t.charge_distance(run_speed, pace)
	var warn: float = charge + t.rev_at(scaling) * run_speed
	var lead: float = t.roll_seconds * run_speed
	var cut: Dictionary = FloorCutPlan.make(lane, anchor + lead + warn, warn, charge, speed, run_speed, t.run_past, t.keep())
	cut["lead"] = lead
	return cut


static func tuning() -> BuzzOverdriveTuning:
	var res: Resource = EnemyDirector.tuning_for(TYPE)
	return res as BuzzOverdriveTuning if res is BuzzOverdriveTuning else BuzzOverdriveTuning.new()


## Every Buzz Overdrive in the layout, along the track.
static func tanks_in(layout: LevelLayout) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in layout.enemies:
		if String(e.get("type", "")) == TYPE:
			out.append(e)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
	return out


## What the generator's fill pass keeps off around a Buzz Overdrive's entry `e` (LevelGenerator.
## fill_keep_outs): its cut's window, from where it sets off to the cut's end (the generator keeps every
## cut's anyway; this is the same). Just its spot if the cut is missing.
static func keep_out(gen: LevelGenerator, e: Dictionary) -> Vector2:
	var cut: Dictionary = cut_of(gen.layout, e)
	if cut.is_empty():
		return Vector2(float(e["at"]), float(e["at"]))
	return FloorCutPlan.window(cut, gen.speed)


## The cut a Buzz Overdrive entry `e` runs: the layout's cut in its lane whose end is its spot ({} if
## none).
static func cut_of(layout: LevelLayout, e: Dictionary) -> Dictionary:
	for c: Dictionary in layout.cuts:
		if int(c["lane"]) == int(e.get("lane", -1)) and absf(float(c["end"]) - float(e["at"])) < 0.01:
			return c
	return {}


## In a level that introduces the feature: one setting off within intro_seconds of `start` where a cut
## fits, unless one already does. Returns the entry added, or {}.
static func _introduce(gen: LevelGenerator, t: BuzzOverdriveTuning, rng: RandomNumberGenerator, start: float) -> Dictionary:
	var by: float = start + t.intro_seconds * gen.speed
	for c: Dictionary in gen.layout.cuts:
		if FloorCutPlan.lead_at(c) <= by:
			return {}
	var at: float = start
	while at <= by:
		var e := {"lane": rng.randi_range(0, gen.layout.lane_count - 1)}
		if place_at(gen, t, rng, e, at, int(e["lane"])):
			return gen.add_enemy(TYPE, float(e["at"]), int(e["lane"]))
		at += gen.metres(GUARANTEE_STEP)
	return {}


## One Buzz Overdrive where a cut fits, in a level left without one: the spots past the feature's start
## (GUARANTEE_STEP apart) in order, in a level paced in bursts those in a burst first. Its cut is
## placed with it. Returns the entry, or {} if no spot fits.
static func _add_guaranteed(gen: LevelGenerator, t: BuzzOverdriveTuning, rng: RandomNumberGenerator) -> Dictionary:
	var layout: LevelLayout = gen.layout
	# The whole encounter, from where it sets off (a cut planned from 0 sets off at 0).
	var span: float = FloorCutPlan.window(plan(gen, t, 0, 0.0), gen.speed).y
	var spots: Array[float] = []
	var at: float = maxf(gen.feature_start(TYPE), gen.config.start_clear_distance)
	var last: float = layout.length - gen.config.end_clear_distance - span
	while at <= last:
		spots.append(at)
		at += gen.metres(GUARANTEE_STEP)
	for pool: Array[float] in gen.pacing_pools(spots, TYPE):
		for spot: float in pool:
			var e := {"lane": rng.randi_range(0, layout.lane_count - 1)}
			if place_at(gen, t, rng, e, spot, int(e["lane"])):
				return gen.add_enemy(TYPE, float(e["at"]), int(e["lane"]))
	return {}

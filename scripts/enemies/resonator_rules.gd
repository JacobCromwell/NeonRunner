extends RefCounted
## Generator rules for the Resonator (GDD §9.10). LevelGenerator runs apply() for levels with the
## `resonator` feature, after the rules of every feature that places things on the floor or plans a
## big attack (RUN_AFTER), so each visit is planned around the level's final layout.
## - Pulses: each Resonator gets its pulses (ResonatorTuning.pulses_at, across the Golden Zone) and
##   the player distances where each warning may start ("pulse_at"), each where the floor its wave
##   meets the player on is clear in every lane (Resonator.pulse_clear: no gap, fence, floor enemy, pad
##   or ceiling landing; GDD §9.10, proposed: never a wave on top of a gap or a fence). The first comes
##   as soon as it has eased into pacing the player (settle_seconds), or up to pulse_slack later where
##   the floor is clear (it hovers ahead meanwhile: it stays where its pattern put it, so a level's
##   introduction still comes right after the feature's start); each next comes a pulse and a rest
##   after the last (pulse_rest), or up to pulse_slack later. A pulse that finds no clear floor within
##   its slack is left out (the visit ends sooner).
## - Double waves ("double"): a share of the pulses (double_share, rising across the zone) send two
##   waves, only where their longer stretch is clear (else a single one goes), and never the level's
##   first pulse (GDD §6: one new thing at a time).
## - Big attacks (GDD §9): no pulse comes during an Octodog's run (its charges are one big attack, so
##   it would keep the pulse waiting). Drones and hover trucks, which stay for a while, and a Bad
##   Dream's chase, which only comes if the player kills its host, take turns with it through the
##   director at run time (DESIGN-TBD, docs/questions/c3.md: a chase's stretch, 20–30 s, would leave
##   few places for a visit in the Golden levels).
## - One at a time: a Resonator whose visit would begin before the last one's could end (its last
##   pulse, plus turn_wait_max for waits at run time, plus visit_gap_seconds) moves on to begin then.
##   One that fits fewer than min_pulses tries a few spots a little earlier or further on
##   (MOVE_OFFSETS; never before the feature's start or the last visit's end), else it's left out.
## - In a level that guarantees its features (LevelConfig.guarantee_features), if no Resonator is left,
##   one is added (guarantee_one) at the first spot after the feature's start where its pulses fit
##   (DESIGN-TBD, docs/questions/c3.md).
## Each Resonator's params get "pulses", "pulse_at" and "double"; it rechecks every pulse at run time.
## Its distances (hover_ahead, approach_ease, pulse_slack) and the search's steps and offsets here are
## metres at MovementTuning.REFERENCE_SPEED, stretched by the level's pace (LevelGenerator.pace), like
## the Resonator's own at run time.

const RUN_AFTER: Array[String] = ["drone", "host", "hover_truck", "octodog", "cyborg", "window_cyborg",
	"screech", "screech_vents", "generator", "barnacle_turret", "wall_fences", "wall_fences_partial",
	"buzz_overdrive", "tithe_collector", "gilded_sentinel"]
const TYPE: String = "resonator"
## Metres between the warning starts tried for a pulse, and the spots tried for a guaranteed Resonator.
const STEP: float = 2.0
const GUARANTEE_STEP: float = 40.0
## A Resonator whose visit doesn't fit at its spot tries these spots around it, in this order, before
## it's left out (DESIGN-TBD, docs/questions/c3.md). Earlier ones help where another rule has put
## something on the floor its pattern kept clear (an Octodog's run the Octodog rules added there).
const MOVE_OFFSETS: Array[float] = [-20.0, 40.0, -40.0, 80.0, 120.0]
## A pulse is planned with this much more clear floor either side of its meeting stretch than the
## Resonator asks for at run time, so the warning that starts on the frame the player passes its
## planned point (up to a frame's run later) finds it clear.
const PLAN_MARGIN: float = 1.0


static func apply(gen: LevelGenerator) -> void:
	var t: ResonatorTuning = tuning()
	var layout: LevelLayout = gen.layout
	var rng: RandomNumberGenerator = gen.rng_for("resonator")
	var busy: Array[Vector2] = busy_stretches(gen)
	var free_from: float = -INF
	var first: bool = true
	var dropped: Array[Dictionary] = []
	for e: Dictionary in resonators_in(layout):
		# One at a time: a Resonator that would arrive before the last visit is over waits until then.
		var lowest: float = maxf(free_from + gen.metres(t.hover_ahead) - gen.metres(t.approach_ease), gen.feature_start(TYPE))
		var base: float = maxf(float(e["at"]), lowest)
		var at: float = base
		var plan: Dictionary = plan_visit(gen, t, rng, at, busy, first)
		# Where its visit doesn't fit (an Octodog's run, or no clear floor for its pulses), it may come a
		# little earlier or later: it's a flier, so its spot is free to move.
		var tried: Array[float] = [at]
		for offset: float in MOVE_OFFSETS:
			if not plan.is_empty():
				break
			var spot: float = maxf(base + gen.metres(offset), lowest)
			if tried.has(spot):
				continue
			tried.append(spot)
			at = spot
			plan = plan_visit(gen, t, rng, at, busy, first)
		if plan.is_empty():
			dropped.append(e)
			continue
		e["at"] = at
		free_from = _commit(gen, t, e, plan)
		first = false
	for e: Dictionary in dropped:
		layout.enemies.erase(e)
	if gen.config.guarantee_features and t.guarantee_one and resonators_in(layout).is_empty():
		_add_guaranteed(gen, t, busy)


static func tuning() -> ResonatorTuning:
	var res: Resource = EnemyDirector.tuning_for(TYPE)
	return res as ResonatorTuning if res is ResonatorTuning else ResonatorTuning.new()


## What the generator's fill pass (LevelGenerator.fill_keep_outs) keeps off around Resonator entry `e`:
## its planned visit, from its first pulse's warning to where its last wave meets the player on the
## clear floor it was planned on (with PLAN_MARGIN); without a plan, from where it has eased into pacing
## the player to its spot.
static func keep_out(gen: LevelGenerator, e: Dictionary) -> Vector2:
	var t: ResonatorTuning = tuning()
	var at: float = float(e["at"])
	var params: Dictionary = e.get("params", {})
	var anchors: Array = params.get("pulse_at", [])
	if anchors.is_empty():
		return Vector2(visit_start(t, at, gen.pace), at)
	var doubles: Array = params.get("double", [])
	var double: bool = doubles.size() == anchors.size() and bool(doubles[-1])
	var last: Vector2 = t.meeting_stretch(float(anchors[-1]), double, gen.speed, gen.config.enemy_scaling, gen.pace)
	return Vector2(float(anchors[0]), last.y + PLAN_MARGIN)


## Every Resonator in the layout, along the track.
static func resonators_in(layout: LevelLayout) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in layout.enemies:
		if String(e.get("type", "")) == TYPE:
			out.append(e)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
	return out


## Where the player is when a Resonator placed at `at` has eased into pacing them (Resonator.visit_start),
## in a level at `pace` (MovementTuning.pace).
static func visit_start(t: ResonatorTuning, at: float, pace: float = 1.0) -> float:
	return at - t.hover_ahead_at(pace) + t.approach_ease * pace


## The stretches no pulse may overlap (from its warning until its wave has met the player): every
## Octodog's run (its params.floor_span, octodog_rules.gd).
static func busy_stretches(gen: LevelGenerator) -> Array[Vector2]:
	return octodog_runs(gen.layout)


## Every Octodog's run in `layout` (LevelGenerator.enemy_floor_span).
static func octodog_runs(layout: LevelLayout) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for e: Dictionary in layout.enemies:
		if String(e.get("type", "")) == "octodog":
			var span: Vector2 = LevelGenerator.enemy_floor_span(e)  # a dog's planned run (params.floor_span)
			if span.y >= span.x:
				out.append(span)
	return out


## A visit for a Resonator placed at `at`: {"pulse_at", "double"}, or {} if fewer than min_pulses fit.
## `first`: the level's first visit (its first pulse is a single wave).
static func plan_visit(gen: LevelGenerator, t: ResonatorTuning, rng: RandomNumberGenerator, at: float,
		busy: Array[Vector2], first: bool) -> Dictionary:
	var speed: float = gen.speed
	var scaling: float = gen.config.enemy_scaling
	var wanted: int = t.pulses_at(scaling)
	var share: float = t.double_share_at(scaling)
	var settle: float = t.settle_seconds * speed
	var earliest: float = maxf(visit_start(t, at, gen.pace) + settle, gen.config.start_clear_distance)
	var anchors: Array[float] = []
	var doubles: Array[bool] = []
	for k: int in wanted:
		var want_double: bool = rng.randf() < share and not (first and k == 0)
		var a: float = find_pulse(gen, t, earliest, want_double, busy)
		var dbl: bool = want_double
		if a < 0.0 and want_double:
			a = find_pulse(gen, t, earliest, false, busy)
			dbl = false
		if a < 0.0:
			break
		anchors.append(a)
		doubles.append(dbl)
		earliest = a + (t.pulse_seconds(dbl, speed, scaling, gen.tuning.hurtbox_size.z, EnemyDirector.SHOT_PASS_MARGIN,
			gen.pace) + t.pulse_rest_at(scaling)) * speed
	if anchors.is_empty() or anchors.size() < mini(t.min_pulses, wanted):
		return {}
	return {"pulse_at": anchors, "double": doubles}


## The first warning start from `from` on, within pulse_slack, where a pulse fits (pulse_fits), or -1.
static func find_pulse(gen: LevelGenerator, t: ResonatorTuning, from: float, double: bool,
		busy: Array[Vector2]) -> float:
	var a: float = from
	while a <= from + gen.metres(t.pulse_slack):
		if pulse_fits(gen, t, a, double, busy):
			return a
		a += STEP
	return -1.0


## True if a pulse whose warning starts with the player at `a` fits: its wave meets them on clear
## floor (Resonator.pulse_clear, with PLAN_MARGIN to spare) before the level's end-clear stretch, after
## the feature's start, and nothing of it overlaps a `busy` stretch.
static func pulse_fits(gen: LevelGenerator, t: ResonatorTuning, a: float, double: bool, busy: Array[Vector2]) -> bool:
	var stretch: Vector2 = t.meeting_stretch(a, double, gen.speed, gen.config.enemy_scaling, gen.pace)
	if stretch.y + PLAN_MARGIN > gen.layout.length - gen.config.end_clear_distance or not gen.feature_started(TYPE, a):
		return false
	for b: Vector2 in busy:
		if b.x <= stretch.y and b.y >= a:
			return false
	return Resonator.pulse_clear(gen.layout, gen.zones, a,
		Vector2(stretch.x - PLAN_MARGIN, stretch.y + PLAN_MARGIN))


## Stores a visit in the Resonator's entry (pulses, pulse_at, double) and returns where the next visit
## may begin: after this one's last pulse, plus turn_wait_max for its waits at run time, plus
## visit_gap_seconds.
static func _commit(gen: LevelGenerator, t: ResonatorTuning, e: Dictionary, plan: Dictionary) -> float:
	var anchors: Array[float] = []
	anchors.assign(plan["pulse_at"])
	var doubles: Array[bool] = []
	doubles.assign(plan["double"])
	var params: Dictionary = e.get("params", {})
	params["pulses"] = anchors.size()
	params["pulse_at"] = anchors
	params["double"] = doubles
	e["params"] = params
	return visit_end(gen, t, anchors[-1], doubles[-1]) + (t.turn_wait_max + t.visit_gap_seconds) * gen.speed


## Where the player is when a visit whose last warning starts at `last` is over (its last wave past them).
static func visit_end(gen: LevelGenerator, t: ResonatorTuning, last: float, double: bool) -> float:
	return last + t.pulse_seconds(double, gen.speed, gen.config.enemy_scaling, gen.tuning.hurtbox_size.z,
		EnemyDirector.SHOT_PASS_MARGIN, gen.pace) * gen.speed


## One Resonator at the first spot after the feature's start where a visit fits, in a level left
## without one. Returns its entry, or {} if none fits.
static func _add_guaranteed(gen: LevelGenerator, t: ResonatorTuning, busy: Array[Vector2]) -> Dictionary:
	var layout: LevelLayout = gen.layout
	var rng: RandomNumberGenerator = gen.rng_for("resonator_guarantee")
	var at: float = maxf(gen.feature_start(TYPE), gen.config.start_clear_distance) + t.hover_ahead_at(gen.pace)
	while visit_start(t, at, gen.pace) < layout.length - gen.config.end_clear_distance:
		var plan: Dictionary = plan_visit(gen, t, rng, at, busy, true)
		if not plan.is_empty():
			var e: Dictionary = gen.add_enemy(TYPE, at, layout.lane_count / 2, 0, {})
			_commit(gen, t, e, plan)
			return e
		at += gen.metres(GUARANTEE_STEP)
	return {}


## Every planned pulse in `layout` that breaks a rule above, as a line of text (the tests' check):
## a clear meeting stretch (at run speed, without the plan's margin), before the end-clear stretch,
## off every Octodog's run, pulses in order and at least a pulse and a rest apart, and one visit at a
## time.
static func problems(layout: LevelLayout, config: LevelConfig, movement: MovementTuning) -> PackedStringArray:
	var out := PackedStringArray()
	var t: ResonatorTuning = tuning()
	var speed: float = movement.run_speed
	var pace: float = movement.pace()
	var zones := CeilingZones.make(config, movement)
	var scaling: float = config.enemy_scaling
	var last_ok: float = layout.length - config.end_clear_distance
	var busy: Array[Vector2] = octodog_runs(layout)
	var prev_end: float = -INF
	for e: Dictionary in resonators_in(layout):
		var params: Dictionary = e.get("params", {})
		var anchors: Array = params.get("pulse_at", [])
		var doubles: Array = params.get("double", [])
		var tag: String = "Resonator at %.0f" % float(e["at"])
		if anchors.is_empty() or int(params.get("pulses", 0)) != anchors.size() or doubles.size() != anchors.size():
			out.append("%s has no pulses planned" % tag)
			continue
		if visit_start(t, float(e["at"]), pace) < prev_end - 0.01:
			out.append("%s arrives before the last visit is over" % tag)
		var free: float = -INF
		for i: int in anchors.size():
			var a: float = float(anchors[i])
			var dbl: bool = bool(doubles[i])
			var stretch: Vector2 = t.meeting_stretch(a, dbl, speed, scaling, pace)
			if a < free - 0.01:
				out.append("%s: pulse %d comes before the last one and its rest are over" % [tag, i])
			if i == 0 and a < visit_start(t, float(e["at"]), pace) + t.settle_seconds * speed - 0.01:
				out.append("%s: its first pulse comes before it has settled" % tag)
			if stretch.y > last_ok:
				out.append("%s: pulse %d meets the player in the end-clear stretch" % [tag, i])
			if not Resonator.pulse_clear(layout, zones, a, stretch):
				out.append("%s: pulse %d's wave meets the player where the floor isn't clear (%.0f-%.0f)" % [tag, i,
					stretch.x, stretch.y])
			for b: Vector2 in busy:
				if b.x <= stretch.y and b.y >= a:
					out.append("%s: pulse %d overlaps an Octodog's run (%.0f-%.0f)" % [tag, i, b.x, b.y])
			free = a + (t.pulse_seconds(dbl, speed, scaling, movement.hurtbox_size.z, EnemyDirector.SHOT_PASS_MARGIN,
				pace) + t.pulse_rest_at(scaling)) * speed
		prev_end = float(anchors[-1]) + t.pulse_seconds(bool(doubles[-1]), speed, scaling, movement.hurtbox_size.z,
			EnemyDirector.SHOT_PASS_MARGIN, pace) * speed + (t.turn_wait_max + t.visit_gap_seconds) * speed
	return out

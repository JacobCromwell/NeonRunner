extends RefCounted
## Generator rules for the fenced ceiling (task I4; GDD §3, "Ceiling scenarios", owner, October 14, 2026: "pick
## the right pad"): "a ceiling carries electric fences (§9.1) that hit a player who takes the first anti-grav pad;
## a second pad further along lands the player past them, safe. First introduced simply, with one unsafe pad and
## one safe one; later, several pads, some leading to safe parts of the ceiling and some to dangerous parts, and
## the player has to read which is which." LevelGenerator runs apply() for levels with the `fenced_ceiling`
## feature (never in zones 1-2: from Casino 2), after every rule that places ceilings, pads or enemies and after the
## treasure stashes (RUN_AFTER), and turns up to LevelConfig.fenced_ceilings of the level's ceilings two lanes wide
## or more into fenced ones (CeilingScenarios: candidates, choose; the first from the feature's start in a level
## that gives it one), only where the level's difficulty has reached CeilingScenarioTuning.fenced_min_difficulty.
## On a ceiling it takes (LevelConfig.fenced_ceiling_pads pads in all, half of them, rounded up, unsafe):
## - the unsafe pads: the ceiling's own (the drone's schedule and a Bad Dream chase's keep theirs: CeilingScenarios),
##   and for the later version more, pad_step_seconds apart, each in a lane none of them takes;
## - the fences: rows across every lane the ceiling covers (LevelLayout.ceiling_fences), always on, from past where
##   the last unsafe pad's rider comes within a fence's reach of the underside at the latest (riding a boost,
##   rider_boost) to a jump's length on at that speed, as close together as a rider near the underside covers in a
##   jump (CeilingScenarios.row_plan): the rider meets one whichever lane they switch to and however they jump;
##   armor, the shield and the dash get them through (GDD §9.1, DamageRules);
## - the safe pads: past the last row on the floor (safe_gap), pad_step_seconds apart, each in its own lane (another
##   lane than the unsafe ones' where it can), so their riders rise past every fence and ride the rest of the ceiling
##   (safe_ride_seconds; the ceiling runs on where it must, CeilingScenarios.can_extend) clear of them.
## Every pad it adds keeps the rules of every pad (CeilingZones.pad_clear: its plain holes and fences go; never a
## floor enemy, a floor cut or a ramp in its way), off what every other rule keeps (CeilingScenarios.busy_spans,
## lane_keeps: a hover truck's lane) and off every drone wave's window (drone_windows: a pad hurls the drones, GDD
## §9.6). The pads are marked: "fenced" ("unsafe", "safe") on each, "added" on those these rules add, which the
## drone schedule's spacing doesn't count (LayoutChecks.check_rules): they're a choice within one ceiling, after its
## first pad. The floor under the ceiling holds what it held (GDD §3: it may be dangerous, and the ceiling is never
## required). DESIGN-TBD throughout (docs/questions/i4.md).

const FEATURE: String = "fenced_ceiling"
## Every feature whose rules place, move or drop floor enemies, plan charges or cuts, or add ceilings, pads and
## ramps, and the treasure stashes: a fenced ceiling takes a ceiling of the level's final floor. The Barnacle
## Turrets, the Resonator, the Enforcer Truck and the dash walls run after it, as after a stash (treasure_stash_rules).
const RUN_AFTER: Array[String] = ["ramps", "ceilings", "pulsing", "speed_pads", "cyborg", "window_cyborg", "host",
	"hover_truck", "octodog", "screech", "screech_vents", "drone", "generator", "wall_fences", "wall_fences_partial",
	"buzz_overdrive", "tithe_collector", "gilded_sentinel", "floor_cutter", "treasure_stash"]


static func apply(gen: LevelGenerator) -> void:
	var count: int = gen.config.fenced_ceilings
	if count <= 0:
		return
	var t: CeilingScenarioTuning = CeilingScenarios.tuning()
	var plans: Array[Dictionary] = []
	var busy: Array[Vector2] = CeilingScenarios.busy_spans(gen)
	for h: Dictionary in CeilingScenarios.candidates(gen, 2):
		var plan: Dictionary = plan_on(gen, t, h, busy)
		if not plan.is_empty():
			plans.append(plan)
	var chosen: Array[Dictionary] = CeilingScenarios.choose(gen, FEATURE, plans, count, gen.rng_for(FEATURE),
		CeilingScenarios.taken_spans(gen))
	for c: Dictionary in chosen:
		# Planned again on the level as it stands now (one before it may have cleared floor or added pads).
		var plan: Dictionary = plan_on(gen, t, c["hull"], CeilingScenarios.busy_spans(gen))
		if not plan.is_empty():
			_build(gen, plan)


## How many of a fenced ceiling's `pads` are unsafe (before its fences): half, rounded up (one of two).
static func unsafe_count(pads: int) -> int:
	return ceili(maxi(pads, 2) / 2.0)


## The rows a fenced ceiling hangs at `gen`'s level (CeilingScenarios.row_plan, from the run speed to it and
## rider_boost).
static func rows_for(gen: LevelGenerator, t: CeilingScenarioTuning) -> Dictionary:
	return CeilingScenarios.row_plan(gen.tuning, gen.speed, gen.speed + t.rider_boost, t.row_margin)


## A fenced ceiling's plan on ceiling `h` (see the header), or {} where none fits: {hull, unsafe (its pads, the
## ceiling's own first: {lane, at}), safe ({lane, at}), added ({lane, at, kind} for each pad to add, clear: whether
## its zone has plain holes or fences to take out), rows (track distances), end (the ceiling's end with it), span
## (its ceiling to its landing zone's end)}. `busy`: CeilingScenarios.busy_spans. Changes nothing.
static func plan_on(gen: LevelGenerator, t: CeilingScenarioTuning, h: Dictionary, busy: Array[Vector2]) -> Dictionary:
	var layout: LevelLayout = gen.layout
	var mt: MovementTuning = gen.tuning
	var v: float = gen.speed
	var v_max: float = v + t.rider_boost
	var own: Array[Dictionary] = CeilingScenarios.pads_under(layout, h)
	if own.is_empty():
		return {}
	var first: float = float(own[0]["at"])
	if not gen.feature_started(FEATURE, first) \
			or gen.difficulty_at(clampf(first / layout.length, 0.0, 1.0)) < t.fenced_min_difficulty - 0.0001:
		return {}
	var total: int = maxi(gen.config.fenced_ceiling_pads, 2)
	var lanes: Vector2i = layout.hull_lanes(h)
	var windows: Array[Vector2] = CeilingScenarios.drone_windows(gen, t.drone_margin_seconds)
	var keeps: Array[Dictionary] = CeilingScenarios.lane_keeps(gen)
	var step: float = t.pad_step_seconds * v
	var unsafe: Array[Dictionary] = []
	var used: Array[int] = []
	for p: Dictionary in own:
		unsafe.append({"lane": int(p["lane"]), "at": float(p["at"])})
		if not used.has(int(p["lane"])):
			used.append(int(p["lane"]))
	var added: Array[Dictionary] = []
	var last_unsafe: float = float(own[-1]["at"])
	var seed: int = hash([gen.config.level_seed, FEATURE, snappedf(float(h["start"]), 0.01)])
	while unsafe.size() < unsafe_count(total):
		var spot: Dictionary = _pad_spot(gen, lanes, used, true, last_unsafe + step, busy, windows, keeps, seed + unsafe.size())
		if spot.is_empty():
			return {}
		spot["kind"] = "unsafe"
		unsafe.append({"lane": spot["lane"], "at": spot["at"]})
		added.append(spot)
		used.append(int(spot["lane"]))
		last_unsafe = float(spot["at"])
	# The rows: from where the last unsafe pad's rider comes within a fence's reach at the latest, a row's half depth
	# and the margin on, across every lane.
	var rows: Dictionary = rows_for(gen, t)
	var row0: float = CeilingScenarios.flip_late(last_unsafe, v_max) \
		+ v_max * CeilingScenarios.rise_seconds(mt, mt.ceiling_fence_depth) + mt.fence_depth * 0.5 + t.row_margin
	var row_at: Array[float] = []
	for i: int in int(rows["count"]):
		row_at.append(row0 + i * float(rows["spacing"]))
	# The safe pads, past the last row, each in a lane of its own (another than the unsafe pads' where it can).
	var safe: Array[Dictionary] = []
	var safe_lanes: Array[int] = []
	var at: float = row_at[-1] + mt.fence_depth * 0.5 + t.safe_gap
	for k: int in maxi(total - unsafe_count(total), 1):
		var avoid: Array[int] = used.duplicate()
		avoid.append_array(safe_lanes)
		var spot: Dictionary = _pad_spot(gen, lanes, avoid, false, at, busy, windows, keeps, seed + 17 + k, safe_lanes)
		if spot.is_empty():
			return {}
		spot["kind"] = "safe"
		safe.append({"lane": spot["lane"], "at": spot["at"]})
		added.append(spot)
		safe_lanes.append(int(spot["lane"]))
		at += step
	# The ceiling runs on safe_ride_seconds past where the last safe pad's rider arrives at the latest.
	var end: float = maxf(float(h["end"]), CeilingScenarios.flip_late(float(safe[-1]["at"]), v_max)
		+ v_max * CeilingScenarios.rise_seconds(mt, 0.0) + t.safe_ride_seconds * v)
	if end > float(h["end"]) and not CeilingScenarios.can_extend(gen, h, end, busy):
		return {}
	return {"hull": h, "unsafe": unsafe, "safe": safe, "added": added, "rows": row_at, "end": end,
		"span": Vector2(float(h["start"]), end + gen.zones.landing)}


## A pad a fenced ceiling adds at `at`, in a lane of `lanes` (Vector2i) the ceiling covers: lanes `avoid` doesn't
## name first (in an order drawn from `seed`), then, unless `strict`, the others but `never`; the first whose zone
## (CeilingZones.pad_zone) has no floor enemy in its way (pad_enemies_clear), no floor cut's window, no ramp, and
## isn't a lane another rule keeps there (lane_keeps). {lane, at, clear (whether plain holes or fences in its lane's
## zone must go)}, or {} if the spot lies in `busy` or a drone wave's window (`windows`), or no lane fits.
static func _pad_spot(gen: LevelGenerator, lanes: Vector2i, avoid: Array[int], strict: bool, at: float,
		busy: Array[Vector2], windows: Array[Vector2], keeps: Array[Dictionary], seed: int,
		never: Array[int] = []) -> Dictionary:
	var layout: LevelLayout = gen.layout
	var zones: CeilingZones = gen.zones
	var zone: Vector2 = zones.pad_zone(at)
	if CeilingScenarios.hits(busy, zone.x, zone.y) or CeilingScenarios.hits(windows, at, at + gen.tuning.pad_length):
		return {}
	var fresh: Array[int] = []
	var others: Array[int] = []
	for lane: int in range(lanes.x, lanes.y + 1):
		if avoid.has(lane):
			if not strict and not never.has(lane):
				others.append(lane)
		else:
			fresh.append(lane)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var order: Array[int] = _shuffled(fresh, rng)
	order.append_array(_shuffled(others, rng))
	for lane: int in order:
		if CeilingScenarios.lane_kept(keeps, lane, zone.x, zone.y) or not zones.pad_enemies_clear(layout, lane, at):
			continue
		if layout.cut_between(zone.x, zone.y, lane):
			continue
		var ramp_in: bool = false
		for r: Dictionary in layout.ramps:
			ramp_in = ramp_in or zones.ramp_in(layout, r, Vector2(zone.x, at + gen.tuning.pad_length), lane)
		if ramp_in:
			continue
		return {"lane": lane, "at": at, "clear": not zones.pad_lane_clear(layout, lane, at)}
	return {}


static func _shuffled(values: Array[int], rng: RandomNumberGenerator) -> Array[int]:
	var out: Array[int] = values.duplicate()
	for i: int in range(out.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


## Turns plan `plan` (plan_on) into the fenced ceiling: clears its added pads' zones, runs its ceiling on where it
## must, marks the ceiling and its pads, and adds its pads and its rows of fences.
static func _build(gen: LevelGenerator, plan: Dictionary) -> void:
	var layout: LevelLayout = gen.layout
	var h: Dictionary = plan["hull"]
	for spot: Dictionary in plan["added"]:
		if bool(spot["clear"]):
			var lane: int = int(spot["lane"])
			var zone: Vector2 = gen.zones.pad_zone(float(spot["at"]))
			CeilingScenarios.clear_floor(gen, zone.x, zone.y, Vector2i(lane, lane))
	if float(plan["end"]) > float(h["end"]):
		CeilingScenarios.extend(gen, h, plan["end"])
	h[CeilingScenarios.KEY] = FEATURE
	for p: Dictionary in CeilingScenarios.pads_under(layout, h):
		p["fenced"] = "unsafe"
	for spot: Dictionary in plan["added"]:
		layout.pads.append({"lane": int(spot["lane"]), "at": float(spot["at"]), "fenced": String(spot["kind"]),
			"added": true})
	var lanes: Vector2i = layout.hull_lanes(h)
	for row: float in plan["rows"]:
		for lane: int in range(lanes.x, lanes.y + 1):
			layout.ceiling_fences.append({"lane": lane, "at": row})


## Every fenced ceiling in `layout`: where it starts (LevelGenerator.feature_positions).
static func positions(layout: LevelLayout) -> Array[float]:
	var out: Array[float] = []
	for h: Dictionary in layout.hulls:
		if CeilingScenarios.scenario_of(h) == FEATURE:
			out.append(float(h["start"]))
	return out

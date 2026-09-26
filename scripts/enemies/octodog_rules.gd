extends RefCounted
## Generator rules for the Octodog (GDD §9.4) that patterns can't express. LevelGenerator runs
## apply() after the patterns for every level with the "octodog" feature, and after the drone, host
## and hover truck rules (RUN_AFTER): the pads and ceilings those add and the lanes the trucks keep
## free are all in place by then, so each dog is planned around the level's final ceilings, chases
## and trucks, and no later rule clears it away.
##
## - Bait: a dog placed with the param "bait" is moved to stand `bait_distance` past the hole in its
##   lane just before it, so a head-on lunge falls in (GDD §9.4: the generator sometimes places
##   Octodogs near gaps; baiting one in is a skill bonus).
## - Charges: each dog gets its number of charges (2–3 early, up to 4 at the maximum, from
##   data/enemies/octodog.tres and the level's enemy_scaling) and the player distances where each
##   wind-up may start ("charge_at"). Each is at a stretch with no fence, other enemy, or holes in
##   more than one lane, so a charge never stacks with an unavoidable obstacle; and neither a charge
##   nor the dog's run between charges comes near an anti-grav pad or where the player lands after a
##   ceiling (Octodog.pad_or_landing_between). Under a ceiling it may run and charge (GDD §3: the
##   floor there may be dangerous, and the ceiling is the escape: it never winds up at a player
##   riding it). Charges that don't fit are left out (it gives up sooner). The stretch its charges
##   use is stored as "floor_span", so ceilings added later keep their pads and landing off it.
## - Chases: a dog's run keeps off every stretch a Bad Dream's chase can cover (HostRules; GDD §9.7:
##   the Bad Dream is never on during an Octodog charge sequence, and the director would hold the
##   dog back), so a charge that would reach one is left out like one that doesn't fit.
## - One at a time: a dog whose first charge overlaps another dog's charges, or can't be made fair,
##   is dropped.
## - In a level that guarantees its features (LevelConfig.guarantee_features), if no dog is left
##   (every one placed was dropped, or none was placed), one is added where a dog fits all of the
##   above, with its first wind-up after the run-up and after the feature's start, in a lane that
##   has floor under it and that no hover truck keeps free (HoverTruckRules.open_lanes).
##   DESIGN-TBD: the spot is picked at random among those that fit.

const RUN_AFTER: Array[String] = ["drone", "host", "hover_truck"]
const HostRules = preload("res://scripts/enemies/host_rules.gd")
const HoverTruckRules = preload("res://scripts/enemies/hover_truck_rules.gd")
const TYPE: String = "octodog"
## A dog is dropped when fewer charges than this fit (GDD §9.4 asks for at least 2).
const MIN_CHARGES: int = 2
## Metres kept clear of other enemies after a charge's stretch.
const OTHER_ENEMY_MARGIN: float = 25.0
## Metres between the spots tried for a guaranteed dog.
const GUARANTEE_STEP: float = 4.0


static func apply(gen: LevelGenerator) -> void:
	var t: OctodogTuning = tuning()
	var layout: LevelLayout = gen.layout
	var rng: RandomNumberGenerator = gen.rng_for("octodog")
	var stop: float = t.stop_distance(gen.speed, gen.config.enemy_scaling)
	var chases: Array[Vector2] = HostRules.chase_stretches(gen)
	var busy_until: float = -INF
	var dropped: Array[Dictionary] = []
	for e: Dictionary in dogs_in(layout):
		var params: Dictionary = e.get("params", {})
		if bool(params.get("bait", false)):
			_align_to_bait_gap(layout, e, t)
		var at: float = float(e["at"])
		if at - stop <= busy_until + 10.0 or layout.gapped_between(int(e["lane"]), at - 1.5, at + 1.5) \
				or not _first_charge_fits(gen, t, at, chases):
			dropped.append(e)
			continue
		var wanted: int = _roll_charges(gen, t, rng)
		var anchors: Array[float] = _plan_charges(gen, t, at - stop, wanted, chases)
		if anchors.size() < mini(MIN_CHARGES, wanted):
			dropped.append(e)
			continue
		busy_until = _commit(gen, t, e, anchors)
	for e: Dictionary in dropped:
		layout.enemies.erase(e)
	if gen.config.guarantee_features and dogs_in(layout).is_empty():
		_add_guaranteed(gen, t, chases)


static func tuning() -> OctodogTuning:
	var res: Resource = EnemyDirector.tuning_for(TYPE)
	return res as OctodogTuning if res is OctodogTuning else OctodogTuning.new()


## Every Octodog in the layout, along the track.
static func dogs_in(layout: LevelLayout) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in layout.enemies:
		if String(e.get("type", "")) == TYPE:
			out.append(e)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
	return out


## True if a dog standing at `at` can make its first charge fairly, whatever its lane: the wind-up
## starts (the player `stop` metres before it) after the level's start, with no pad or ceiling
## landing from there to the dog, a clear stretch for the charge, and its run so far off every chase.
static func _first_charge_fits(gen: LevelGenerator, t: OctodogTuning, at: float, chases: Array[Vector2]) -> bool:
	var scaling: float = gen.config.enemy_scaling
	var stop: float = t.stop_distance(gen.speed, scaling)
	var window: float = t.window_length(gen.speed, scaling)
	var a0: float = at - stop
	return a0 > 0.0 and not Octodog.pad_or_landing_between(gen.layout, a0 - 6.0, at + 2.0) \
		and _window_ok(gen.layout, a0, window) \
		and _off_chases(chases, _run_start(gen, a0), a0 + window + stop)


## How many charges a dog tries for (charges_range at the level's enemy_scaling).
static func _roll_charges(gen: LevelGenerator, t: OctodogTuning, rng: RandomNumberGenerator) -> int:
	var r: Vector2i = t.charges_range(gen.config.enemy_scaling)
	return rng.randi_range(r.x, r.y)


## The player distances where a dog's wind-ups start, from its first at `a0` (which must fit already,
## _first_charge_fits): each next one a cycle after the last, or up to charge_slack later where its
## stretch is clear, with no pad or ceiling landing in between (the player could leave the floor or
## drop back onto it there), before the end-clear stretch and off every chase. Stops at `wanted`, or
## where the next one doesn't fit.
static func _plan_charges(gen: LevelGenerator, t: OctodogTuning, a0: float, wanted: int,
		chases: Array[Vector2]) -> Array[float]:
	var layout: LevelLayout = gen.layout
	var scaling: float = gen.config.enemy_scaling
	var stop: float = t.stop_distance(gen.speed, scaling)
	var window: float = t.window_length(gen.speed, scaling)
	var cycle: float = t.cycle_distance(gen.speed, scaling)
	var last_ok: float = layout.length - gen.config.end_clear_distance
	var run_start: float = _run_start(gen, a0)
	var anchors: Array[float] = [a0]
	var prev: float = a0
	while anchors.size() < wanted:
		var found: float = -1.0
		var a: float = prev + cycle
		while a <= prev + cycle + t.charge_slack:
			if a + window > last_ok or Octodog.pad_or_landing_between(layout, prev, a + stop + 2.0) \
					or not _off_chases(chases, run_start, a + window + stop):
				break
			if _window_ok(layout, a, window):
				found = a
				break
			a += 2.0
		if found < 0.0:
			break
		anchors.append(found)
		prev = found
	return anchors


## Stores a dog's plan in its params (charges, charge_at, floor_span) and returns where it's busy
## until: the next dog's first charge comes after that.
static func _commit(gen: LevelGenerator, t: OctodogTuning, dog: Dictionary, anchors: Array[float]) -> float:
	var scaling: float = gen.config.enemy_scaling
	var window: float = t.window_length(gen.speed, scaling)
	var busy_until: float = anchors[-1] + window + t.stop_distance(gen.speed, scaling)
	var params: Dictionary = dog.get("params", {})
	params["charges"] = anchors.size()
	params["charge_at"] = anchors
	params["floor_span"] = Vector2(_run_start(gen, anchors[0]), _run_end(anchors[-1], window))
	dog["params"] = params
	return busy_until


## Where the floor a dog's charges use starts, for a first wind-up at `a0`: as early as the pads and
## ceiling landings its own rules let near it allow (a pad no closer than CEILING_LEAD to the stretch
## from a0 - CEILING_LEAD, a ceiling's end no closer than CEILING_LANDING), so every pad's spot and
## landing zone in the level stays off it (CeilingZones), and a ceiling a later rule adds
## (add_hull_with_pad keeps both off every floor enemy's stretch) never lands a player in a charge.
static func _run_start(gen: LevelGenerator, a0: float) -> float:
	var zones: CeilingZones = gen.zones
	return a0 - Octodog.CEILING_LEAD - minf(Octodog.CEILING_LEAD - zones.pad_length,
		Octodog.CEILING_LANDING - zones.landing) + 0.001


## Where the floor a dog's charges use ends, for a last wind-up at `last`: the end of the player's
## stretch through that charge, after which it gives up behind them.
static func _run_end(last: float, window: float) -> float:
	return last + window - 0.001


## True if the stretch [from, to] touches none of the chase stretches.
static func _off_chases(chases: Array[Vector2], from: float, to: float) -> bool:
	for s: Vector2 in chases:
		if from <= s.y and to >= s.x:
			return false
	return true


## True if the player's stretch [a, a + window] has no fence, ceiling, pad, holes in two or more
## lanes, and no enemy other than a dog nearby.
static func _window_ok(layout: LevelLayout, a: float, window: float) -> bool:
	if not Octodog.window_clear(layout, a, a + window):
		return false
	for other: Dictionary in layout.enemies:
		var d: float = float(other["at"])
		if String(other["type"]) != TYPE and d >= a - 5.0 and d <= a + window + OTHER_ENEMY_MARGIN:
			return false
	return true


## One dog where a dog fits every rule (see the header), in a level left without one. The spots
## whose first charge fits, and that have a lane for the dog, are tried in random order until the
## rest of its charges fit too. Returns the dog, or {} if no spot fits.
static func _add_guaranteed(gen: LevelGenerator, t: OctodogTuning, chases: Array[Vector2]) -> Dictionary:
	var layout: LevelLayout = gen.layout
	var stop: float = t.stop_distance(gen.speed, gen.config.enemy_scaling)
	var rng: RandomNumberGenerator = gen.rng_for("octodog_guarantee")
	var wanted: int = _roll_charges(gen, t, rng)
	var spots: Array[float] = []
	var at: float = maxf(gen.config.start_clear_distance, gen.feature_start(TYPE)) + stop
	while at <= layout.length - gen.config.end_clear_distance:
		if _first_charge_fits(gen, t, at, chases) and not _lanes_for(gen, at).is_empty():
			spots.append(at)
		at += GUARANTEE_STEP
	while not spots.is_empty():
		var spot: float = spots.pop_at(rng.randi_range(0, spots.size() - 1))
		var anchors: Array[float] = _plan_charges(gen, t, spot - stop, wanted, chases)
		if anchors.size() < mini(MIN_CHARGES, wanted):
			continue
		var lanes: Array[int] = _lanes_for(gen, spot)
		var dog: Dictionary = gen.add_enemy(TYPE, spot, lanes[rng.randi_range(0, lanes.size() - 1)], 0, {})
		_commit(gen, t, dog, anchors)
		return dog
	return {}


## The lanes a dog may stand in at `at`: with floor under it, and no hover truck keeping the lane free.
static func _lanes_for(gen: LevelGenerator, at: float) -> Array[int]:
	var out: Array[int] = []
	for lane: int in HoverTruckRules.open_lanes(gen, at):
		if not gen.layout.gapped_between(lane, at - 1.5, at + 1.5):
			out.append(lane)
	return out


## Moves a bait dog to stand `bait_distance` past the far edge of the hole just before it in its lane.
static func _align_to_bait_gap(layout: LevelLayout, dog: Dictionary, t: OctodogTuning) -> void:
	var lane: int = int(dog["lane"])
	var at: float = float(dog["at"])
	var best: Dictionary = {}
	for g: Dictionary in layout.gaps:
		if int(g["lane"]) != lane or float(g["end"]) > at + 1.0 or float(g["end"]) < at - 25.0:
			continue
		if best.is_empty() or float(g["end"]) > float(best["end"]):
			best = g
	if not best.is_empty():
		dog["at"] = float(best["end"]) + t.bait_distance

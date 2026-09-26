extends RefCounted
## Anti-grav pads that enemy rules guarantee at a chosen spot, shared by the drone's pad schedule
## (drone_rules.gd, GDD §9.6) and the pads during a Bad Dream's chase (host_rules.gd, GDD §9.7):
## a ceiling section with its pad (LevelGenerator.add_hull_with_pad) over whatever the floor holds
## there (GDD §3: the floor under a ceiling may be dangerous; the pad is the way out of it), first
## clearing only what the ceiling keeps safe (CeilingZones), in a lane no hover truck holds at the
## time.
## (Not a `<feature>_rules.gd` script: LevelGenerator never runs it on its own.)

const GeneratorRules = preload("res://scripts/enemies/generator_rules.gd")
## Around each hover truck's burst point, where pads keep out of its lane (metres before, and
## seconds after as a fallback when its tuning can't be read).
const TRUCK_LANE_BEFORE: float = 30.0
const TRUCK_LANE_AFTER_SECONDS: float = 40.0


## A ceiling lasting `seconds` at run speed with a pad at `at`, clearing only what's in the way of
## the floor it keeps safe (CeilingZones): in every lane, the gaps and fences on its landing zone and
## the floor enemies whose stretch reaches it (LevelGenerator.enemy_floor_span; drones and hover
## trucks don't use the floor); in the pad's lane, the gaps, fences and ramps on the pad's run-up and
## rise; the floor enemies whose stretch reaches the pad's spot; and other ceiling sections it would
## touch (with their pads). The floor under the ceiling keeps everything else. A fence generator left
## with nothing to power goes too (GeneratorRules). The lane comes from `rng` (pad_lane), among the
## lanes whose run-up and rise are clear when there are any. Returns false (clearing nothing) before
## the `ceilings` feature's start (LevelConfig.feature_starts), or if its landing wouldn't end before
## the level's end-clear stretch.
static func place(gen: LevelGenerator, rng: RandomNumberGenerator, at: float, seconds: float) -> bool:
	if not gen.feature_started("ceilings", at):
		return false
	var layout: LevelLayout = gen.layout
	var zones: CeilingZones = gen.zones
	var start: float = at - gen.config.hull_lead_in
	var end: float = at + seconds * gen.speed
	var landing: Vector2 = zones.landing_zone({"start": start, "end": end})
	if landing.y > layout.length - gen.config.end_clear_distance:
		return false
	for h: Dictionary in layout.hulls.duplicate():
		if start <= float(h["end"]) + 1.0 and end >= float(h["start"]) - 1.0:
			remove_hull(layout, h)
	var cleared: int = zones.clear_landing(layout, landing)
	var lane: int = pad_lane(gen, rng, at)
	cleared += zones.clear_pad(layout, lane, at)
	if cleared > 0:
		GeneratorRules.keep_powered(gen)
	return gen.add_hull_with_pad(lane, at, seconds)


## A random lane for a pad at `at`: one no hover truck holds while it's around, and among those, one
## whose run-up and rise are already clear (CeilingZones.pad_lane_clear) when there is one, so the
## floor loses as little as possible.
static func pad_lane(gen: LevelGenerator, rng: RandomNumberGenerator, at: float) -> int:
	var after: float = TRUCK_LANE_AFTER_SECONDS * gen.speed
	var truck: Resource = EnemyDirector.tuning_for("hover_truck")
	if truck != null and truck.get("stay_max_seconds") != null:
		after = (float(truck.get("stay_max_seconds")) + float(truck.get("leave_seconds"))) * gen.speed
	var lanes: Array[int] = []
	for lane: int in gen.layout.lane_count:
		var free: bool = true
		for e: Dictionary in gen.layout.enemies:
			if String(e.get("type", "")) == "hover_truck" and int(e.get("lane", -1)) == lane \
					and at >= float(e["at"]) - TRUCK_LANE_BEFORE and at <= float(e["at"]) + after:
				free = false
				break
		if free:
			lanes.append(lane)
	if lanes.is_empty():
		return rng.randi_range(0, gen.layout.lane_count - 1)
	var clear: Array[int] = []
	for lane: int in lanes:
		if gen.zones.pad_lane_clear(gen.layout, lane, at):
			clear.append(lane)
	var pool: Array[int] = clear if not clear.is_empty() else lanes
	return pool[rng.randi_range(0, pool.size() - 1)]


## Removes a ceiling section and every pad under it.
static func remove_hull(layout: LevelLayout, h: Dictionary) -> void:
	_keep(layout.pads, func(p: Dictionary) -> bool:
		return not (float(p["at"]) >= float(h["start"]) and float(p["at"]) <= float(h["end"])))
	_keep(layout.hulls, func(x: Dictionary) -> bool: return not is_same(x, h))


## Keeps the items of `list` for which `keep` returns true (in place, so typed arrays stay typed).
static func _keep(list: Array[Dictionary], keep: Callable) -> void:
	var out: Array[Dictionary] = []
	for item: Dictionary in list:
		if keep.call(item):
			out.append(item)
	list.assign(out)

extends RefCounted
## Anti-grav pads that enemy rules guarantee at a chosen spot, shared by the drone's pad schedule
## (drone_rules.gd, GDD §9.6) and the pads during a Bad Dream's chase (host_rules.gd, GDD §9.7):
## a ceiling section with its pad (LevelGenerator.add_hull_with_pad), first clearing the floor it
## needs, in a lane no hover truck holds at the time.
## (Not a `<feature>_rules.gd` script: LevelGenerator never runs it on its own.)

## Around each hover truck's burst point, where pads keep out of its lane (metres before, and
## seconds after as a fallback when its tuning can't be read).
const TRUCK_LANE_BEFORE: float = 30.0
const TRUCK_LANE_AFTER_SECONDS: float = 40.0


## A ceiling lasting `seconds` at run speed with a pad at `at`, clearing whatever is in its way: gaps,
## fences and speed pads on the floor it needs (GDD §3: the floor under a ceiling stays clear, and
## its landing too), floor enemies whose stretch it would cover (LevelGenerator.enemy_floor_span;
## drones and hover trucks don't use the floor), and other ceiling sections it would touch (with
## their pads). The lane comes from `rng` (pad_lane). Returns false (clearing nothing) before the
## `ceilings` feature's start (LevelConfig.feature_starts), and false if it doesn't fit before the
## level's end-clear stretch.
static func place(gen: LevelGenerator, rng: RandomNumberGenerator, at: float, seconds: float) -> bool:
	if not gen.feature_started("ceilings", at):
		return false
	var layout: LevelLayout = gen.layout
	var start: float = at - gen.config.hull_lead_in
	var end: float = at + seconds * gen.speed
	var landing_end: float = end + gen.config.hull_landing_seconds * gen.speed
	# The same stretch LevelGenerator.add_hull_with_pad requires clear.
	var from: float = start - 6.0
	_keep(layout.gaps, func(g: Dictionary) -> bool: return not (float(g["start"]) <= landing_end and float(g["end"]) >= from))
	_keep(layout.fences, func(f: Dictionary) -> bool: return not (float(f["at"]) >= from and float(f["at"]) <= landing_end))
	_keep(layout.speed_pads, func(s: Dictionary) -> bool:
		return not (float(s["at"]) <= end and float(s["at"]) + gen.tuning.speed_pad_length >= start))
	_keep(layout.enemies, func(e: Dictionary) -> bool:
		var span: Vector2 = LevelGenerator.enemy_floor_span(e)
		return not (span.x <= landing_end and span.y >= from))
	for h: Dictionary in layout.hulls.duplicate():
		if start <= float(h["end"]) + 1.0 and end >= float(h["start"]) - 1.0:
			remove_hull(layout, h)
	return gen.add_hull_with_pad(pad_lane(gen, rng, at), at, seconds)


## A random lane for a pad at `at`, keeping out of a hover truck's lane while one is around.
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
	return lanes[rng.randi_range(0, lanes.size() - 1)]


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

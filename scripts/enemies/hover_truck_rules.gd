extends RefCounted
## Generator rules for the hover truck (GDD §9.3). LevelGenerator runs apply() after the patterns for
## levels with the `hover_truck` feature. Numbers come from HoverTruckTuning
## (data/enemies/hover_truck.tres).
## - One at a time: a truck placed while another's lane is still reserved is dropped (with
##   min_gap_seconds between them), and so is one too close to the end for its shortest stay.
## - Rare early, more frequent later: at most max_per_level_at(enemy_scaling) trucks in a level
##   (DESIGN-TBD: 1 early, up to 3 by the last levels); the earliest are kept.
## - Its lane (the outer lane on its side) is kept free while it's around: no gaps, fences or other
##   floor enemies there from just before its burst point until it has left (stay_max + leave).
##   It hovers over such things anyway, and the player needs that lane for route (b).
## - The wall section it bursts through keeps no sign and no wall enemy.
## - With the `ramps` feature, route (a) gets a ramp on its side ramp_after_seconds after the burst
##   (unless one is there already), clear of signs.
## - DESIGN-TBD: a level with the feature always gets at least one truck (the patterns may pick
##   none, and the level that introduces the truck should show it).

const TYPE: String = "hover_truck"


static func apply(gen: LevelGenerator) -> void:
	var t: HoverTruckTuning = tuning()
	var layout: LevelLayout = gen.layout
	var speed: float = gen.speed
	var latest: float = layout.length - gen.config.end_clear_distance - t.stay_min_seconds * speed
	var trucks: Array[Dictionary] = []
	for e: Dictionary in layout.enemies:
		if String(e.get("type", "")) == TYPE:
			trucks.append(e)
	trucks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
	var kept: Array[Dictionary] = []
	var removed: Array[Dictionary] = []
	var free_from: float = -INF
	var most: int = t.max_per_level_at(gen.config.enemy_scaling)
	for e: Dictionary in trucks:
		var at: float = e["at"]
		if at > latest or at - t.burst_lead - t.clear_before < free_from or kept.size() >= most:
			removed.append(e)
			continue
		kept.append(e)
		free_from = window_end(t, at, speed) + t.min_gap_seconds * speed
	_remove_entries(layout, removed)
	if kept.is_empty() and t.guarantee_one:
		var added: Dictionary = _add_guaranteed(gen, t, latest)
		if not added.is_empty():
			kept.append(added)
	var rng: RandomNumberGenerator = gen.rng_for("hover_truck")
	for e: Dictionary in kept:
		var side: int = int(e.get("side", 0))
		if side == 0:
			side = -1 if rng.randf() < 0.5 else 1
			e["side"] = side
		var lane: int = layout.outer_lane(side)
		e["lane"] = lane
		var at: float = e["at"]
		_clear_lane(layout, lane, window_start(t, at), window_end(t, at, speed))
		_clear_burst_wall(layout, t, side, at)
		if gen.config.has_feature("ramps"):
			_ensure_ramp(gen, t, side, lane, at)


static func tuning() -> HoverTruckTuning:
	var res: Resource = EnemyDirector.tuning_for(TYPE)
	return res as HoverTruckTuning if res is HoverTruckTuning else HoverTruckTuning.new()


## Where its lane must be free: from a little before the spot where it lands ...
static func window_start(t: HoverTruckTuning, at: float) -> float:
	return at - t.burst_lead - t.clear_before


## ... until it has left, even after its longest stay.
static func window_end(t: HoverTruckTuning, at: float, speed: float) -> float:
	return at + (t.stay_max_seconds + t.leave_seconds) * speed


## The wall section it bursts through (track distances), with some room around it.
static func burst_section(t: HoverTruckTuning, at: float) -> Vector2:
	return Vector2(at - t.length * 0.5 - t.burst_section_before - 6.0, at + t.length * 0.5 + t.burst_section_after + 3.0)


static func _clear_lane(layout: LevelLayout, lane: int, from: float, to: float) -> void:
	_keep(layout.gaps, func(g: Dictionary) -> bool:
		return not (int(g["lane"]) == lane and float(g["start"]) <= to and float(g["end"]) >= from))
	_keep(layout.fences, func(f: Dictionary) -> bool:
		return not (int(f["lane"]) == lane and float(f["at"]) >= from and float(f["at"]) <= to))
	_keep(layout.enemies, func(e: Dictionary) -> bool:
		return not (LevelGenerator.enemy_uses_floor(e) and int(e.get("lane", -1)) == lane
			and float(e["at"]) >= from and float(e["at"]) <= to))


static func _clear_burst_wall(layout: LevelLayout, t: HoverTruckTuning, side: int, at: float) -> void:
	var section: Vector2 = burst_section(t, at)
	_keep(layout.signs, func(s: Dictionary) -> bool:
		return not (int(s["side"]) == side and float(s["start"]) <= section.y and float(s["end"]) >= section.x))
	_keep(layout.enemies, func(e: Dictionary) -> bool:
		return not (int(e.get("side", 0)) == side and String(e.get("type", "")) != TYPE
			and float(e["at"]) >= section.x and float(e["at"]) <= section.y))


## Route (a): a ramp onto the wall beside it while it's surely still around.
static func _ensure_ramp(gen: LevelGenerator, t: HoverTruckTuning, side: int, lane: int, at: float) -> void:
	var layout: LevelLayout = gen.layout
	var lo: float = at + t.ramp_after_seconds * gen.speed
	var hi: float = at + (t.stay_min_seconds - 3.0) * gen.speed
	for r: Dictionary in layout.ramps:
		if int(r["side"]) == side and float(r["at"]) >= lo and float(r["at"]) <= hi:
			return
	var c: float = lo
	while c <= hi:
		if _ramp_fits(gen, side, lane, c):
			layout.ramps.append({"side": side, "at": c})
			return
		c += 4.0


## Same fairness as pattern ramps: solid floor under it, no sign blocking its wall entry, and no pad
## sharing its spot.
static func _ramp_fits(gen: LevelGenerator, side: int, lane: int, at: float) -> bool:
	var layout: LevelLayout = gen.layout
	var length: float = gen.tuning.ramp_length
	if layout.gapped_between(lane, at, at + length):
		return false
	for s: Dictionary in layout.signs:
		if int(s["side"]) == side and float(s["end"]) >= at - 2.5 and float(s["start"]) <= at + length + 2.5:
			return false
	for list: Array[Dictionary] in [layout.pads, layout.speed_pads]:
		for p: Dictionary in list:
			if int(p["lane"]) == lane and float(p["at"]) >= at - 4.0 and float(p["at"]) <= at + length + 4.0:
				return false
	return true


## One truck in the level (between the tuning's shares, never before the run-up ends or after
## `latest`). Returns its entry, or {} if there's no room.
static func _add_guaranteed(gen: LevelGenerator, t: HoverTruckTuning, latest: float) -> Dictionary:
	var rng: RandomNumberGenerator = gen.rng_for("hover_truck_guarantee")
	var lo: float = maxf(gen.layout.length * t.guaranteed_from,
		gen.config.start_clear_distance + t.burst_lead + t.clear_before)
	var hi: float = minf(gen.layout.length * t.guaranteed_to, latest)
	if hi < lo:
		return {}
	var side: int = -1 if rng.randf() < 0.5 else 1
	return gen.add_enemy(TYPE, rng.randf_range(lo, hi), gen.layout.outer_lane(side), side, {})


static func _remove_entries(layout: LevelLayout, entries: Array[Dictionary]) -> void:
	if entries.is_empty():
		return
	_keep(layout.enemies, func(e: Dictionary) -> bool:
		for r: Dictionary in entries:
			if is_same(r, e):
				return false
		return true)


## Keeps the items of `list` for which `keep` returns true (in place, so typed arrays stay typed).
static func _keep(list: Array[Dictionary], keep: Callable) -> void:
	var out: Array[Dictionary] = []
	for item: Dictionary in list:
		if keep.call(item):
			out.append(item)
	list.assign(out)

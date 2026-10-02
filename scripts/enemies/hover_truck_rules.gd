extends RefCounted
## Generator rules for the hover truck (GDD §9.3). LevelGenerator runs apply() after the patterns for
## levels with the `hover_truck` feature. Numbers come from HoverTruckTuning
## (data/enemies/hover_truck.tres).
## - One at a time: a truck placed while another's lane is still reserved is dropped (with
##   min_gap_seconds between them), and so is one too close to the end for its shortest stay.
## - Rare early, more frequent later: at most max_per_level_at(enemy_scaling) trucks in a level
##   (FB 94: 1 early, up to 3 by the last levels); the earliest are kept.
## - Its lane (the outer lane on its side) is kept free while it's around: no gaps, fences or other
##   floor enemies there from just before its burst point until it has left (stay_max + leave).
##   It hovers over such things anyway, and the player needs that lane for route (b).
## - The wall section it bursts through keeps no sign and no wall enemy.
## - With the `ramps` feature, route (a) gets a ramp on its side ramp_after_seconds after the burst
##   (unless one is there already), clear of signs, and not before the ramps' start.
## - A level with the feature always gets at least one truck (FB 94; the patterns may pick
##   none, and the level that introduces the truck should show it).
## - Late starts (LevelConfig.feature_starts): no truck before the `hover_truck` feature's start; the
##   guaranteed one falls in the same share of the stretch where trucks are active.
## - In a level paced in bursts (LevelConfig.quiet_seconds, The Hush), the guaranteed truck bursts in
##   during a burst when one lies in its share of the level.
## - clear_before is metres at MovementTuning.REFERENCE_SPEED, stretched by the level's pace
##   (LevelGenerator.pace), so its lane is kept clear as long before the burst in a faster zone. The
##   truck itself moves with the player once it's out (its offsets and burst_lead are the player's
##   frame), so nothing else of it depends on the run speed.

const TYPE: String = "hover_truck"


static func apply(gen: LevelGenerator) -> void:
	var t: HoverTruckTuning = tuning()
	var layout: LevelLayout = gen.layout
	var speed: float = gen.speed
	var latest: float = layout.length - gen.config.end_clear_distance - t.stay_min_seconds * speed
	var earliest: float = gen.feature_start(TYPE)
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
		if at > latest or at < earliest or window_start(t, at, gen.pace) < free_from or kept.size() >= most:
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
		_clear_lane(layout, lane, window_start(t, at, gen.pace), window_end(t, at, speed))
		_clear_burst_wall(layout, t, side, at)
		if gen.config.has_feature("ramps"):
			_ensure_ramp(gen, t, side, lane, at)


static func tuning() -> HoverTruckTuning:
	var res: Resource = EnemyDirector.tuning_for(TYPE)
	return res as HoverTruckTuning if res is HoverTruckTuning else HoverTruckTuning.new()


## Where its lane must be free: from a little before the spot where it lands (clear_before, stretched
## by the level's `pace`) ...
static func window_start(t: HoverTruckTuning, at: float, pace: float = 1.0) -> float:
	return at - t.burst_lead - t.clear_before * pace


## ... until it has left, even after its longest stay.
static func window_end(t: HoverTruckTuning, at: float, speed: float) -> float:
	return at + (t.stay_max_seconds + t.leave_seconds) * speed


## What the generator's fill pass (LevelGenerator.fill_keep_outs) keeps off around truck entry `e`, in
## every lane: from the start of its lane's window until its shortest stay is over (it's surely there,
## lurching and firing, and that's what goes on). Fillers may come after that, while it may still stay:
## after_fill() then clears its lane of them, as apply() cleared it of the patterns' pieces.
static func keep_out(gen: LevelGenerator, e: Dictionary) -> Vector2:
	var t: HoverTruckTuning = tuning()
	var at: float = float(e["at"])
	return Vector2(window_start(t, at, gen.pace), at + t.stay_min_seconds * gen.speed)


## After the generator's fill pass (LevelGenerator._fill_empty_stretches): every truck's lane is kept
## free of the fillers' holes and fences until it has left, as of the patterns' (apply). Taking pieces
## out of a row never makes it unfair.
static func after_fill(gen: LevelGenerator) -> void:
	var t: HoverTruckTuning = tuning()
	for e: Dictionary in gen.layout.enemies:
		if String(e.get("type", "")) == TYPE:
			var at: float = float(e["at"])
			_clear_lane(gen.layout, int(e.get("lane", -1)), window_start(t, at, gen.pace), window_end(t, at, gen.speed))


## What the generator's zone doodads keep off (LevelGenerator.doodad_keep_outs): every truck's lane for
## its whole stay (window_start to window_end), where none stands and none pushes the player into it
## (its sides are solid, and its forward lurch is deadly in its lane). keep_out() already keeps them
## off every lane while it's surely there.
static func doodad_keep_outs(gen: LevelGenerator) -> Array[Dictionary]:
	var t: HoverTruckTuning = tuning()
	var out: Array[Dictionary] = []
	for e: Dictionary in gen.layout.enemies:
		if String(e.get("type", "")) == TYPE:
			var at: float = float(e["at"])
			out.append({"lane": int(e.get("lane", -1)), "from": window_start(t, at, gen.pace), "to": window_end(t, at, gen.speed)})
	return out


## The lanes at track distance `at` that no hover truck keeps free (its lane, from window_start to
## window_end): where another rule may still add a floor enemy (the host and Octodog guarantees).
static func open_lanes(gen: LevelGenerator, at: float) -> Array[int]:
	var t: HoverTruckTuning = tuning()
	var out: Array[int] = []
	for lane: int in gen.layout.lane_count:
		var free: bool = true
		for e: Dictionary in gen.layout.enemies:
			if String(e.get("type", "")) == TYPE and int(e.get("lane", -1)) == lane \
					and at >= window_start(t, float(e["at"]), gen.pace) and at <= window_end(t, float(e["at"]), gen.speed):
				free = false
				break
		if free:
			out.append(lane)
	return out


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
		if gen.feature_started("ramps", c) and _ramp_fits(gen, side, lane, c):
			layout.ramps.append({"side": side, "at": c})
			return
		c += 4.0


## Same fairness as pattern ramps: solid floor under it, no sign blocking its wall entry, no pad
## sharing its spot, and none in a pad's run-up (CeilingZones.pad_lane_clear: a ramp there would throw
## the player onto the wall before the pad; the run-up is a full jump, longer at a faster zone's speed).
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
	var ramp := {"side": side, "at": at}
	for p: Dictionary in layout.pads:
		var pad: float = float(p["at"])
		if gen.zones.ramp_in(layout, ramp, Vector2(gen.zones.pad_zone(pad).x, pad + gen.zones.pad_length), int(p["lane"])):
			return false
	return true


## One truck in the level (between the tuning's shares of the stretch where trucks are active,
## LevelGenerator.feature_share_at; never before the run-up ends or after `latest`), bursting in
## during a burst if the level is paced in bursts (LevelGenerator.burst_spot). Returns its entry, or
## {} if there's no room.
static func _add_guaranteed(gen: LevelGenerator, t: HoverTruckTuning, latest: float) -> Dictionary:
	var rng: RandomNumberGenerator = gen.rng_for("hover_truck_guarantee")
	var lo: float = maxf(gen.feature_share_at(TYPE, t.guaranteed_from),
		gen.config.start_clear_distance + t.burst_lead + t.clear_before * gen.pace)
	var hi: float = minf(gen.feature_share_at(TYPE, t.guaranteed_to), latest)
	if hi < lo:
		return {}
	var side: int = -1 if rng.randf() < 0.5 else 1
	var at: float = gen.burst_spot(rng, lo, hi, TYPE)
	if is_nan(at):
		at = rng.randf_range(lo, hi)
	return gen.add_enemy(TYPE, at, gen.layout.outer_lane(side), side, {})


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

class_name GapDensity
extends RefCounted
## Add gaps without moving or removing patterns or obstacles. Each new/widened row keeps a
## grounded lane through its reaction window, or a clear full-width jump and landing.


static func rows(layout: LevelLayout) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for g: Dictionary in layout.gaps:
		var row: Dictionary = {}
		for existing: Dictionary in out:
			if existing["start"] == g["start"] and existing["end"] == g["end"]:
				row = existing
				break
		if row.is_empty():
			row = {"start": float(g["start"]), "end": float(g["end"]), "lanes": []}
			out.append(row)
		(row["lanes"] as Array).append(int(g["lane"]))
	return out


static func apply(gen: LevelGenerator) -> Dictionary:
	var config: LevelConfig = gen.config
	if config.gap_encounter_increase <= 0.0 and config.gap_lane_increase <= 0.0:
		return {}
	var original: Array[Dictionary] = rows(gen.layout)
	if original.is_empty():
		return {"constraint": "no baseline gap encounters to scale"}
	var baseline_lanes: int = gen.layout.gaps.size()
	var count_target: int = ceili(original.size() * (1.0 + config.gap_encounter_increase))
	var mean_target: float = float(baseline_lanes) / original.size() * (1.0 + config.gap_lane_increase)
	var length: float = INF
	for row: Dictionary in original:
		length = minf(length, float(row["end"]) - float(row["start"]))
	var rng: RandomNumberGenerator = gen.rng_for("gap_density")
	var all_rows: Array[Dictionary] = original.duplicate()
	while all_rows.size() < count_target:
		var candidates: Array[Vector2] = _candidates(gen, length)
		var added: bool = false
		for span: Vector2 in candidates:
			var available: Array[int] = _available(gen, span, {})
			if available.size() < 2:
				continue
			var row: Dictionary = {"start": span.x, "end": span.y, "lanes": []}
			# The last available lane stays whole through the whole reaction window.
			var width: int = mini(ceili(mean_target), available.size() - 1)
			_add_lanes(gen, row, available, width, rng)
			all_rows.append(row)
			added = true
			break
		if not added:
			break
	# Target the mean against the actual number of rows, not a proxy total of lane-gaps.
	var lane_target: int = ceili(all_rows.size() * mean_target)
	var changed: bool = true
	while gen.layout.gaps.size() < lane_target and changed:
		changed = false
		# Widen the narrowest rows first rather than concentrating the increase in one row.
		all_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return (a["lanes"] as Array).size() < (b["lanes"] as Array).size())
		for row: Dictionary in all_rows:
			if gen.layout.gaps.size() >= lane_target:
				break
			var available: Array[int] = _available(gen, Vector2(row["start"], row["end"]), row)
			var occupied: Array = row["lanes"]
			# Ignore this row's own holes, not other obstacles, for the clearance check.
			var missing: Array[int] = []
			for lane: int in available:
				if not occupied.has(lane):
					missing.append(lane)
			var grounded: bool = occupied.size() < gen.layout.lane_count - 1 and missing.size() >= 2
			# Full-width gaps already exist in the patterns. Permit that same jump route only
			# with every lane clear before/after this row, never beside another obstacle.
			var full_jump: bool = occupied.size() == gen.layout.lane_count - 1 \
				and available.size() == gen.layout.lane_count \
				and float(row["end"]) - float(row["start"]) <= gen.jump_distance * config.max_gap_jump_fraction
			if not grounded and not full_jump:
				continue
			_add_lanes(gen, row, missing, 1, rng)
			changed = true
	var constraints: PackedStringArray = []
	if all_rows.size() < count_target:
		constraints.append("encounters limited by separated windows with two clear lanes at the existing hard spacing")
	if gen.layout.gaps.size() < lane_target:
		constraints.append("mean width limited by lane capacity/clearance: needs a grounded route or an isolated full-width jump")
	return {
		"baseline_rows": original.size(), "baseline_lane_gaps": baseline_lanes,
		"row_target": count_target, "mean_target": mean_target, "lane_gap_target": lane_target,
		"rows": all_rows.size(), "lane_gaps": gen.layout.gaps.size(), "constraints": constraints,
	}


static func _add_lanes(gen: LevelGenerator, row: Dictionary, available: Array[int],
		count: int, rng: RandomNumberGenerator) -> void:
	for i: int in count:
		var index: int = rng.randi_range(0, available.size() - 1)
		var lane: int = available[index]
		available.remove_at(index)
		(row["lanes"] as Array).append(lane)
		gen.layout.gaps.append({"lane": lane, "start": row["start"], "end": row["end"]})


## All protected mechanics/enemy windows stay untouched, as do doodads and their pushes.
## Signs aren't floor obstacles: a gap may add a floor choice beneath a sign, not replace it.
static func _protected(gen: LevelGenerator) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var hooks: Dictionary = {}
	for e: Dictionary in gen.layout.enemies:
		out.append(gen._enemy_keep_out(e, hooks))
	for r: Dictionary in gen.layout.ramps:
		out.append(Vector2(float(r["at"]), maxf(gen.ramp_launch(r).end(),
			float(r["at"]) + gen.tuning.ramp_length)))
	for h: Dictionary in gen.layout.hulls:
		out.append(Vector2(float(h["start"]), gen.zones.landing_zone(h).y))
	for p: Dictionary in gen.layout.pads:
		out.append(gen.zones.pad_zone(float(p["at"])))
	for p: Dictionary in gen.layout.speed_pads:
		out.append(Vector2(float(p["at"]), float(p["at"]) + gen.tuning.speed_pad_length))
	for c: Dictionary in gen.layout.cuts:
		out.append(FloorCutPlan.window(c, gen.speed))
	for d: Dictionary in gen.layout.doodads:
		out.append(Vector2(float(d["start"]) - gen.doodad_lead_for(gen.tuning),
			float(d["end"]) + gen.doodad_after(float(d["end"]))))
	for k: Dictionary in gen.rules_doodad_keep_outs():
		out.append(Vector2(float(k["from"]), float(k["to"])))
	out.append_array(gen.quiet_stretches())
	return out


## Minimum existing pattern spacing at run speed, not a new shorter reaction-time tuning.
static func _margin(gen: LevelGenerator) -> float:
	return gen.config.spacing_seconds_hard * gen.speed


static func _lane_busy(gen: LevelGenerator, lane: int, ignore: Dictionary) -> Array[Vector2]:
	var out: Array[Vector2] = _protected(gen)
	for g: Dictionary in gen.layout.gaps:
		# New encounters are separated in distance from every gap, not just this lane's.
		# Otherwise staggered holes could inflate "encounters" within a single encounter.
		if (ignore.is_empty() or int(g["lane"]) == lane) and not (not ignore.is_empty()
				and g["start"] == ignore["start"] and g["end"] == ignore["end"]):
			out.append(Vector2(float(g["start"]), float(g["end"])))
	for f: Dictionary in gen.layout.fences:
		if int(f["lane"]) == lane:
			var half: float = gen.tuning.fence_depth * 0.5
			out.append(Vector2(float(f["at"]) - half, float(f["at"]) + half))
	# Other campaign levels default off; keep wall-fence drop lanes safe if enabled elsewhere.
	var wall_tuning: WallFenceTuning = WallFencePlacement.tuning()
	for w: Dictionary in gen.layout.wall_fences:
		if gen.layout.outer_lane(int(w["side"])) == lane:
			out.append(Vector2(float(w["at"]) - wall_tuning.drop_before_seconds * gen.speed,
				float(w["at"]) + wall_tuning.drop_after_seconds * gen.speed))
	return out


static func _available(gen: LevelGenerator, span: Vector2, ignore: Dictionary) -> Array[int]:
	var out: Array[int] = []
	var margin: float = _margin(gen)
	if span.x < gen.config.start_clear_distance or span.y > gen.layout.length - gen.config.end_clear_distance:
		return out
	for lane: int in gen.layout.lane_count:
		var clear: bool = true
		for busy: Vector2 in _lane_busy(gen, lane, ignore):
			if busy.x <= span.y + margin and busy.y >= span.x - margin:
				clear = false
				break
		if clear:
			out.append(lane)
	return out


static func _candidates(gen: LevelGenerator, length: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var margin: float = _margin(gen)
	for lane: int in gen.layout.lane_count:
		var busy: Array[Vector2] = []
		for span: Vector2 in _lane_busy(gen, lane, {}):
			busy.append(Vector2(span.x - margin, span.y + margin))
		for room: Vector2 in LevelGenerator.free_stretches(busy, gen.config.start_clear_distance,
				gen.layout.length - gen.config.end_clear_distance):
			if room.y - room.x <= length:
				continue
			# Earliest-fit interval packing leaves the most space for later encounters.
			# The epsilon keeps inclusive obstacle edges outside the clearance test.
			var start: float = room.x + 0.001
			if start + length > room.y:
				continue
			out.append(Vector2(start, start + length))
	out.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	return out

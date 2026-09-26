extends RefCounted
## Generator rules for cyborgs (GDD §9.2), run for levels with the `cyborg` or `host` feature:
## - rolls the panic variant (about 1 in 3, CyborgTuning.panic_chance) for every placed cyborg that
##   doesn't set `params.panic` itself, so the layout says which ones panic and every attempt at a
##   seed is the same (hosts never panic unless a pattern says so);
## - drops a cyborg placed within obstacle_margin of a gap, fence, ramp, pad, speed pad or ceiling
##   section in any lane: standing there it could block the lane a player needs at that obstacle
##   (GDD §9 fairness). A cyborg keeps the same margin while it moves (Cyborg clamps its walk and its
##   panic run with obstacle_spans()).

const TUNING_PATH: String = "res://data/enemies/cyborg.tres"


static func apply(gen: LevelGenerator) -> void:
	var tuning := load(TUNING_PATH) as CyborgTuning
	if tuning == null:
		tuning = CyborgTuning.new()
	var rng: RandomNumberGenerator = gen.rng_for("cyborg")
	var spans: Array[Vector2] = obstacle_spans(gen.layout, gen.tuning)
	var kept: Array[Dictionary] = []
	for e: Dictionary in gen.layout.enemies:
		if String(e.get("type", "")) != "cyborg":
			kept.append(e)
			continue
		var params: Dictionary = e.get("params", {})
		e["params"] = params
		if not params.has("panic"):
			params["panic"] = not bool(params.get("host", false)) and rng.randf() < tuning.panic_chance
		if near_any(spans, float(e["at"]), tuning.obstacle_margin):
			continue
		kept.append(e)
	gen.layout.enemies = kept


## Every floor obstacle's [start, end] along the track, any lane: gaps, fences, ramps, anti-grav
## pads, speed pads and ceiling sections.
static func obstacle_spans(layout: LevelLayout, t: MovementTuning) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for g: Dictionary in layout.gaps:
		out.append(Vector2(g["start"], g["end"]))
	for f: Dictionary in layout.fences:
		out.append(Vector2(float(f["at"]) - t.fence_depth, float(f["at"]) + t.fence_depth))
	for r: Dictionary in layout.ramps:
		out.append(Vector2(r["at"], float(r["at"]) + t.ramp_length))
	for p: Dictionary in layout.pads:
		out.append(Vector2(p["at"], float(p["at"]) + t.pad_length))
	for s: Dictionary in layout.speed_pads:
		out.append(Vector2(s["at"], float(s["at"]) + t.speed_pad_length))
	for h: Dictionary in layout.hulls:
		out.append(Vector2(h["start"], h["end"]))
	return out


## True if any span comes within `margin` of the track distance `d`.
static func near_any(spans: Array[Vector2], d: float, margin: float) -> bool:
	for s: Vector2 in spans:
		if s.x - margin <= d and s.y + margin >= d:
			return true
	return false

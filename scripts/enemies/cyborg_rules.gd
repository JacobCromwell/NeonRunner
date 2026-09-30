extends RefCounted
## Generator rules for cyborgs (GDD §9.2), run for levels with the `cyborg` or `host` feature:
## - rolls the panic variant (about 1 in 3, CyborgTuning.panic_chance) for every placed cyborg that
##   doesn't set `params.panic` itself, so the layout says which ones panic and every attempt at a
##   seed is the same (hosts never panic unless a pattern says so);
## - drops a cyborg placed within obstacle_margin of a gap, fence, ramp, pad or speed pad in any lane:
##   standing there it could block the lane a player needs at that obstacle (GDD §9 fairness); nor
##   within it of a ceiling's landing zone (GDD §3: the floor there is safe to land on). The margin
##   is metres at the reference speed, stretched by the level's pace (obstacle_margin_at), so it
##   keeps its time at any run speed. Under a ceiling it may stand (GDD §3: the floor there may be
##   dangerous); it holds fire at a player on the ceiling (Cyborg). A cyborg keeps the same margins while it moves (Cyborg clamps its walk and
##   its panic run with obstacle_spans()).
## These rules run after the hover truck's, which add a ramp for its wall route, so cyborgs keep
## their margin from that ramp too. Pads that later rules add (drones, hosts) clear the floor
## enemies around their pads and landing zones themselves (PadPlacement).

const RUN_AFTER: Array[String] = ["hover_truck"]
const TUNING_PATH: String = "res://data/enemies/cyborg.tres"


static func apply(gen: LevelGenerator) -> void:
	var tuning := load(TUNING_PATH) as CyborgTuning
	if tuning == null:
		tuning = CyborgTuning.new()
	var rng: RandomNumberGenerator = gen.rng_for("cyborg")
	var spans: Array[Vector2] = obstacle_spans(gen.layout, gen.tuning, gen.zones)
	var kept: Array[Dictionary] = []
	for e: Dictionary in gen.layout.enemies:
		if String(e.get("type", "")) != "cyborg":
			kept.append(e)
			continue
		var params: Dictionary = e.get("params", {})
		e["params"] = params
		if not params.has("panic"):
			params["panic"] = not bool(params.get("host", false)) and rng.randf() < tuning.panic_chance
		if near_any(spans, float(e["at"]), obstacle_margin_at(tuning, gen.pace)):
			continue
		kept.append(e)
	gen.layout.enemies = kept


## Every floor obstacle's [start, end] along the track, any lane: gaps, fences, ramps, anti-grav
## pads, speed pads, and every ceiling section's landing zone (`zones`, CeilingZones; the level's
## pacing at run speed). The floor under a ceiling isn't one (GDD §3).
static func obstacle_spans(layout: LevelLayout, t: MovementTuning, zones: CeilingZones) -> Array[Vector2]:
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
	out.append_array(zones.landing_zones(layout))
	return out


## A cyborg's obstacle_margin at a level's `pace` (MovementTuning.pace): the same time at any run
## speed (GDD §3: a faster zone is never secretly tighter). The rules, the Cyborg and the tests use it.
static func obstacle_margin_at(t: CyborgTuning, pace: float) -> float:
	return t.obstacle_margin * pace


## True if any span comes within `margin` of the track distance `d`.
static func near_any(spans: Array[Vector2], d: float, margin: float) -> bool:
	for s: Vector2 in spans:
		if s.x - margin <= d and s.y + margin >= d:
			return true
	return false

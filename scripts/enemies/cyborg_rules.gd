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
const POWERUPS_PATH: String = "res://data/tuning/powerups.tres"


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
## pads, speed pads, zone doodads (GDD §3; placed after these rules, so only the Cyborg's walk and
## panic run meet them), every dash wall's footprint (task H7a; DashWallTuning.footprint: its clear
## approach, the wall and the stretch past it at the dash's speed; placed after these rules too, so a panic
## run stops before a wall's approach and never runs through it or cowers in the clear stretch behind it),
## and every ceiling section's landing zone (`zones`, CeilingZones; the level's pacing at run speed). The
## floor under a ceiling isn't one (GDD §3).
static func obstacle_spans(layout: LevelLayout, t: MovementTuning, zones: CeilingZones) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for d: Dictionary in layout.doodads:
		out.append(Vector2(d["start"], d["end"]))
	if not layout.dash_walls.is_empty():
		var dt: DashWallTuning = DashWallTuning.load_default()
		var pt := load(POWERUPS_PATH) as PowerupTuning if ResourceLoader.exists(POWERUPS_PATH) else null
		var dash_speed: float = t.run_speed + (pt.dash_speed_bonus if pt != null else 0.0)
		for w: Dictionary in layout.dash_walls:
			out.append(dt.footprint(w, dash_speed))
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


## What the generator's fill pass (LevelGenerator.fill_keep_outs) keeps off around cyborg entry `e`
## (hosts too): from LevelGenerator.FILL_ENEMY_LEAD_SECONDS before it (its bursts come as the player
## closes in, onto a clear path) and never less than its margin, to its margin after it.
static func keep_out(gen: LevelGenerator, e: Dictionary) -> Vector2:
	var t := load(TUNING_PATH) as CyborgTuning
	var margin: float = obstacle_margin_at(t, gen.pace) if t != null else gen.metres(10.0)
	var at: float = float(e["at"])
	return Vector2(at - maxf(LevelGenerator.FILL_ENEMY_LEAD_SECONDS * gen.speed, margin), at + margin)


## A cyborg's obstacle_margin at a level's `pace` (MovementTuning.pace): the same time at any run
## speed (GDD §3: a faster zone is never secretly tighter). The rules, the Cyborg and the tests use it.
static func obstacle_margin_at(t: CyborgTuning, pace: float) -> float:
	return t.obstacle_margin * pace


## Where a cyborg standing at `home` may walk back to and run ahead to (Vector2(walk_limit, run_limit), track
## distances), keeping obstacle_margin_at from every one of obstacle_spans (`spans`, the level's): its walk
## (CyborgTuning.walk_max back toward the runner) stops past what lies behind it, its panic run (panic_run_max,
## at the level's pace) short of what lies ahead, and one standing in a span goes nowhere. `level_length` caps
## the run. The Cyborg (_compute_limits) and the tests use it.
static func limits(spans: Array[Vector2], t: CyborgTuning, pace: float, home: float, level_length: float) -> Vector2:
	var margin: float = obstacle_margin_at(t, pace)
	var walk_limit: float = home - t.walk_max
	var run_limit: float = minf(home + t.panic_run_max * pace, level_length - margin)
	for s: Vector2 in spans:
		if s.y <= home:
			walk_limit = maxf(walk_limit, s.y + margin)
		elif s.x >= home:
			run_limit = minf(run_limit, s.x - margin)
		else:
			walk_limit = home
			run_limit = home
	return Vector2(minf(walk_limit, home), maxf(run_limit, home))


## True if any span comes within `margin` of the track distance `d`.
static func near_any(spans: Array[Vector2], d: float, margin: float) -> bool:
	for s: Vector2 in spans:
		if s.x - margin <= d and s.y + margin >= d:
			return true
	return false

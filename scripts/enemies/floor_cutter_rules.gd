extends RefCounted
## Generator rules for the floor cutter (task B4): the plain stand-in that runs floor cuts for review
## until task C2's Buzz Overdrive (GDD §9.9) exists. A debug-only quick-play feature
## (`--features=floor_cutter`), never in the campaign: no level file lists it, and it has no patterns,
## so the every-feature guarantee never asks for it.
## LevelGenerator runs apply() for levels with the feature, after the rules of every other feature
## (RUN_AFTER), so each cut is planned around the level's final layout. From first_seconds into the
## feature's stretch, it plans a cut (FloorCutPlan, from the cutter's tuning) in a lane drawn from a
## seeded stream among those where one fits (CutPlacement: GDD §9.9's limits, LevelGenerator.cut_problem),
## and stands a floor cutter where its cause waits (the cut's end, in its lane); the next cut's warning
## comes gap_seconds after this one ends, or retry_seconds further on where no lane fits. Task C2 plans
## the Buzz Overdrive's cuts the same way (CutPlacement, add_enemy at the cut's end) with its own
## numbers and introduction.

const RUN_AFTER: Array[String] = ["ramps", "ceilings", "pulsing", "speed_pads", "cyborg", "window_cyborg", "host",
	"hover_truck", "octodog", "screech", "screech_vents", "drone", "generator", "barnacle_turret", "resonator",
	"wall_fences", "wall_fences_partial", "buzz_overdrive", "tithe_collector", "gilded_sentinel"]
const TYPE: String = "floor_cutter"
const CutPlacement = preload("res://scripts/enemies/cut_placement.gd")


static func apply(gen: LevelGenerator) -> void:
	var t: FloorCutterTuning = tuning()
	var rng: RandomNumberGenerator = gen.rng_for(TYPE)
	var layout: LevelLayout = gen.layout
	var lanes: int = layout.lane_count
	var last: float = layout.length - gen.config.end_clear_distance
	var probe: Dictionary = plan(gen, t, 0, 0.0)
	var warn: float = float(probe["warn"])
	# The first warning first_seconds into the feature's stretch (never in the run-up).
	var end: float = maxf(gen.feature_start(TYPE), gen.config.start_clear_distance) + t.first_seconds * gen.speed + warn
	while end + t.keep() < last:
		var order: Array[int] = []
		for lane: int in lanes:
			order.insert(rng.randi_range(0, order.size()), lane)
		var placed: Dictionary = {}
		for lane: int in order:
			var cut: Dictionary = plan(gen, t, lane, end)
			if CutPlacement.place(gen, cut):
				placed = cut
				break
		if placed.is_empty():
			end += t.retry_seconds * gen.speed
			continue
		gen.add_enemy(TYPE, end, int(placed["lane"]))
		end = FloorCutPlan.window(placed, gen.speed).y + t.gap_seconds * gen.speed + warn


## A cut whose cutter waits at `end` in `lane`, from the cutter's tuning `t` at the level's run speed
## and pace (FloorCutPlan.make).
static func plan(gen: LevelGenerator, t: FloorCutterTuning, lane: int, end: float) -> Dictionary:
	var speed: float = t.charge_speed * gen.pace
	var charge: float = t.charge_seconds * (gen.speed + speed)
	var warn: float = charge + t.warn_seconds * gen.speed
	return FloorCutPlan.make(lane, end, warn, charge, speed, gen.speed, t.run_past, t.keep())


static func tuning() -> FloorCutterTuning:
	var res: Resource = EnemyDirector.tuning_for(TYPE)
	return res as FloorCutterTuning if res is FloorCutterTuning else FloorCutterTuning.new()


## What the generator's fill pass keeps off around a floor cutter's entry `e` (LevelGenerator.
## fill_keep_outs): its cut's window, from the warning to the cut's end (the generator keeps every cut's
## anyway; this is the same). Just its spot if the cut is missing.
static func keep_out(gen: LevelGenerator, e: Dictionary) -> Vector2:
	var cut: Dictionary = cut_of(gen.layout, e)
	if cut.is_empty():
		return Vector2(float(e["at"]), float(e["at"]))
	return FloorCutPlan.window(cut, gen.speed)


## The cut a floor cutter entry `e` runs: the layout's cut in its lane whose end is its spot ({} if none).
static func cut_of(layout: LevelLayout, e: Dictionary) -> Dictionary:
	for c: Dictionary in layout.cuts:
		if int(c["lane"]) == int(e.get("lane", -1)) and absf(float(c["end"]) - float(e["at"])) < 0.01:
			return c
	return {}

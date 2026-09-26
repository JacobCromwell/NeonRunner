extends RefCounted
## Generator rules for fence generators (GDD §9.1), run for levels with the `generator` feature.
## Drops a generator that would power nothing (its fences were dropped, e.g. under a ceiling) or that
## would stand over a gap or under a ceiling section (a floor piece, GDD §3).

const TUNING_PATH: String = "res://data/enemies/generator.tres"


static func apply(gen: LevelGenerator) -> void:
	var tuning := load(TUNING_PATH) as FenceGeneratorTuning
	if tuning == null:
		tuning = FenceGeneratorTuning.new()
	var geo := TrackGeometry.new(gen.layout.lane_count, gen.tuning)
	var kept: Array[Dictionary] = []
	for e: Dictionary in gen.layout.enemies:
		if String(e.get("type", "")) == "generator":
			var at: float = e["at"]
			var lane: int = e["lane"]
			if FenceGenerator.fences_in_reach(gen.layout, geo, at, lane, tuning.emp_radius).is_empty():
				continue
			if gen.layout.gapped_between(lane, at - 1.5, at + 1.5) or gen.layout.under_hull(at):
				continue
		kept.append(e)
	gen.layout.enemies = kept

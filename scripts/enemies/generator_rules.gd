extends RefCounted
## Generator rules for fence generators (GDD §9.1), run for levels with the `generator` feature.
## Drops a generator that would power nothing (its fences were dropped, e.g. from a ceiling's landing
## zone) or that would stand over a gap. Under a ceiling it may stand (GDD §3: the floor there may be
## dangerous), but never where a ceiling's landing zone or pad keeps the floor clear: patterns and
## PadPlacement keep floor enemies off those (CeilingZones), and PadPlacement calls keep_powered()
## after it clears fences.

const TUNING_PATH: String = "res://data/enemies/generator.tres"


static func apply(gen: LevelGenerator) -> void:
	var geo := TrackGeometry.new(gen.layout.lane_count, gen.tuning)
	var kept: Array[Dictionary] = []
	for e: Dictionary in gen.layout.enemies:
		if String(e.get("type", "")) == "generator":
			if not _powers_something(gen, geo, e):
				continue
			var lane: int = e["lane"]
			if gen.layout.gapped_between(lane, float(e["at"]) - 1.5, float(e["at"]) + 1.5):
				continue
		kept.append(e)
	gen.layout.enemies = kept


## Drops every generator whose fences are all gone (a rule cleared them), whatever the level's
## features: one with nothing to power has no place in the level.
static func keep_powered(gen: LevelGenerator) -> void:
	var geo := TrackGeometry.new(gen.layout.lane_count, gen.tuning)
	var kept: Array[Dictionary] = []
	for e: Dictionary in gen.layout.enemies:
		if String(e.get("type", "")) != "generator" or _powers_something(gen, geo, e):
			kept.append(e)
	gen.layout.enemies.assign(kept)


static func _powers_something(gen: LevelGenerator, geo: TrackGeometry, e: Dictionary) -> bool:
	return not FenceGenerator.fences_in_reach(gen.layout, geo, float(e["at"]), int(e["lane"]),
		tuning().emp_radius).is_empty()


static func tuning() -> FenceGeneratorTuning:
	var res := load(TUNING_PATH) as FenceGeneratorTuning
	return res if res != null else FenceGeneratorTuning.new()

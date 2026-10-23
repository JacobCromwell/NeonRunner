extends RefCounted
## Generator rules for the Heavy Cyborg (GDD §9.16), run for levels with the `heavy_cyborg` feature (the Ice Lab's
## Relay Station, from its introduction, and Specimen Vault; the Golden Zone's three levels). It stands on the floor
## as a cyborg does, so it keeps the cyborgs' rules (CyborgRules): one placed within its obstacle_margin (metres at
## the reference speed, stretched by the level's pace) of a gap, fence, ramp, pad, speed pad, zone doodad, dash
## wall's footprint, wall-run gap's clear stretch or a ceiling's landing zone, in any lane, is dropped (standing
## there it could block the lane a runner needs at that obstacle), and it walks no closer to one (Cyborg). Its
## stream needs a clear path where it lands (CyborgGun.path_clear holds it until one is), so the fill pass and the
## zone doodads keep a longer stretch before it clear than a cyborg's (keep_out). It is never a panic variant nor a
## host, so nothing is rolled.
## The rules run in the order of the level's features (after the teleporters', which come before it in every
## campaign level): they only ever drop a Heavy Cyborg, so what ran before stays fair.

const CyborgRules = preload("res://scripts/enemies/cyborg_rules.gd")
const TYPE: String = "heavy_cyborg"
const TUNING_PATH: String = "res://data/enemies/heavy_cyborg.tres"
const RUN_AFTER: Array[String] = ["hover_truck"]


static func apply(gen: LevelGenerator) -> void:
	var tuning: HeavyCyborgTuning = tuning_of()
	var spans: Array[Vector2] = CyborgRules.obstacle_spans(gen.layout, gen.tuning, gen.zones)
	var margin: float = CyborgRules.obstacle_margin_at(tuning, gen.pace)
	var kept: Array[Dictionary] = []
	for e: Dictionary in gen.layout.enemies:
		if String(e.get("type", "")) == TYPE and CyborgRules.near_any(spans, float(e["at"]), margin):
			continue
		kept.append(e)
	gen.layout.enemies = kept


## What the fill pass (LevelGenerator.fill_keep_outs) and the zone doodads keep off around Heavy Cyborg entry `e`:
## from keep_clear_seconds of run before it (where its stream lands, as the runner closes in; never less than its
## margin) to its margin after it.
static func keep_out(gen: LevelGenerator, e: Dictionary) -> Vector2:
	var tuning: HeavyCyborgTuning = tuning_of()
	var margin: float = CyborgRules.obstacle_margin_at(tuning, gen.pace)
	var at: float = float(e["at"])
	return Vector2(at - maxf(tuning.keep_clear_seconds * gen.speed, margin), at + margin)


## Its tuning (data/enemies/heavy_cyborg.tres), or the class's defaults.
static func tuning_of() -> HeavyCyborgTuning:
	var t := load(TUNING_PATH) as HeavyCyborgTuning if ResourceLoader.exists(TUNING_PATH) else null
	return t if t != null else HeavyCyborgTuning.new()

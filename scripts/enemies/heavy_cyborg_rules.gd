extends RefCounted
## Generator rules for the Heavy Cyborg (GDD §9.16), run for levels with the `heavy_cyborg` feature (the Ice Lab's
## Relay Station, from its introduction, and Specimen Vault; the Golden Zone's three levels). It stands on the floor
## as a cyborg does, so it keeps the cyborgs' rules (CyborgRules): one placed within its obstacle_margin (metres at
## the reference speed, stretched by the level's pace) of a gap, fence, ramp, pad, speed pad, zone doodad, dash
## wall's footprint, wall-run gap's clear stretch or a ceiling's landing zone, in any lane, is dropped (standing
## there it could block the lane a runner needs at that obstacle), and it walks no closer to one (Cyborg). It is never
## a panic variant nor a host, so nothing is rolled.
## Its stream needs a clear path where it lands, as the runner closes in (CyborgGun.path_clear holds it by anything
## LevelLayout.doodad_between counts: a doodad, a falling gantryway's or a teleporter's calm stretch, a dash wall), over
## its stream's zone: keep_clear_seconds of run before it to where it stands (stream_zone).
## - One whose zone already holds such a thing when these rules run is dropped. The rules before them (the
##   gantryways', the Octodog jars' and the teleporters' in the Ice Lab; the Golden Zone's hosts', Enforcer Trucks' and
##   teleporters') plan around a Heavy Cyborg as around a cyborg (the floor it uses, its keep-out), never around its
##   zone, so they keep their counts: the Heavy Cyborg gives way to them.
## - What comes after keeps off its zone in every lane through its keep-out (keep_out: the fill pass, the zone doodads,
##   the danger density pass and the others that keep off what the fill pass keeps for an enemy).
## The rules run in the order of the level's features, after the teleporters' (which come before it in every campaign
## level): they only ever drop a Heavy Cyborg, so what ran before stays fair.

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
		if String(e.get("type", "")) == TYPE:
			var at: float = float(e["at"])
			var zone: Vector2 = stream_zone(gen, at, tuning)
			if CyborgRules.near_any(spans, at, margin) or gen.layout.doodad_between(zone.x, zone.y):
				continue
		kept.append(e)
	gen.layout.enemies = kept


## The stretch of track (metres) a Heavy Cyborg standing at `at` needs clear for its stream: keep_clear_seconds of
## run at the level's speed before it, to where it stands.
static func stream_zone(gen: LevelGenerator, at: float, tuning: HeavyCyborgTuning = null) -> Vector2:
	if tuning == null:
		tuning = tuning_of()
	return Vector2(at - tuning.keep_clear_seconds * gen.speed, at)


## What the fill pass (LevelGenerator.fill_keep_outs), the zone doodads (LevelGenerator.doodad_enemy_keep_out) and the
## other passes that keep off an enemy's keep-out keep off around Heavy Cyborg entry `e`, in every lane: its stream's
## zone (never less than its margin before it) to its margin after it.
static func keep_out(gen: LevelGenerator, e: Dictionary) -> Vector2:
	var tuning: HeavyCyborgTuning = tuning_of()
	var margin: float = CyborgRules.obstacle_margin_at(tuning, gen.pace)
	var at: float = float(e["at"])
	return Vector2(minf(stream_zone(gen, at, tuning).x, at - margin), at + margin)


## Its tuning (data/enemies/heavy_cyborg.tres), or the class's defaults.
static func tuning_of() -> HeavyCyborgTuning:
	var t := load(TUNING_PATH) as HeavyCyborgTuning if ResourceLoader.exists(TUNING_PATH) else null
	return t if t != null else HeavyCyborgTuning.new()

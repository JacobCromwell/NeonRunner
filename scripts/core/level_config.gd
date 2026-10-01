class_name LevelConfig
extends Resource
## One level: generator settings plus what the campaign shows. Campaign levels use fixed seeds.
## The campaign (Campaign/ZoneDef) sets difficulty and enemy_scaling from the level's position;
## standalone use (quick play, tests) takes the values stored here.

## Features the campaign schedule (GDD §5) already lists for enemies and mechanics that aren't built
## yet. Each does nothing until its code and patterns exist: its patterns `require` the name, its
## generator rules go in scripts/enemies/<name>_rules.gd, and an enemy type of that name is found by
## EnemyDirector. So those tasks add their own files and never edit level data.
## - barnacle_turret: the Barnacle Turret, a ceiling hazard (GDD §9.8), from Marketplace 1
## - wall_fences: full-height wall fences (GDD §9.1), from Marketplace 2
## - wall_fences_partial: wall fences over the low or the high part of the wall only (GDD §9.1),
##   from Corporate 1 (their patterns require both wall_fences and wall_fences_partial)
## - buzz_overdrive: the Buzz Overdrive (GDD §9.9), from Corporate 1 through the Dead Zone and the
##   Golden Zone (the Golden Palace included)
## - tithe_collector: the Tithe Collector (GDD §9.12), Corporate 2, then the Golden Zone
## - resonator: the Resonator (GDD §9.10), from Golden 1
## - gilded_sentinel: the Gilded Sentinels (GDD §9.11), from Golden 2
const PLANNED_FEATURES: PackedStringArray = ["barnacle_turret", "wall_fences", "wall_fences_partial",
	"buzz_overdrive", "tithe_collector", "resonator", "gilded_sentinel"]

@export var id: StringName = &"prototype"
## DESIGN-TBD: campaign level names are placeholders (GDD §5 names only the Golden Palace).
@export var display_name: String = "Prototype"
@export var level_seed: int = 1
## Lane count on floor and ceiling used by the generator. The game sets it from the device when a
## run starts (GameRules.lanes_pc / lanes_mobile); tests and the F1 debug key set it directly.
@export_range(3, 8) var lane_count: int = 3
## GDD §4: levels last 90–150 seconds. DESIGN-TBD: each campaign level's length (together they make
## GDD §5's "a flawless run through every level takes about 35 minutes").
@export_range(30.0, 150.0, 1.0, "suffix:s") var duration_seconds: float = 120.0
## The run speed this level is built and played at (GDD §3, owner's playtest September 30, 2026: it
## rises zone by zone). 0: its zone's (ZoneDef.run_speed) in the campaign, else the movement tuning's
## base run speed (quick play, tests). Campaign.configure writes the level's own speed, its zone's or
## 0 into its copy, times the difficulty tier's speed multiplier. The generator, the run's world and
## the enemies all take their movement tuning from movement_for(), so they agree on it; the level
## keeps its duration in seconds and gets longer in metres.
@export_range(0.0, 40.0, 0.1, "suffix:m/s") var run_speed: float = 0.0
## 0 = easiest, 1 = hardest. In the campaign this is the campaign curve plus difficulty_bias.
@export_range(0.0, 1.0, 0.05) var difficulty: float = 0.3
## Added to the campaign's automatic difficulty curve for this level (GDD §6: each level can be
## tuned individually on top of the curve). DESIGN-TBD: City 1 −0.05; Golden 2 +0.05, the peak
## (GDD §5, proposed); Golden 3 −0.05.
@export_range(-0.5, 0.5, 0.05) var difficulty_bias: float = 0.0
## DESIGN-TBD: how difficulty rises within one level. Added linearly from start to end.
@export_range(0.0, 1.0, 0.05) var difficulty_ramp: float = 0.25
## 0 = first campaign level, 1 = last: enemies scale fire rate, speed and health with it (GDD §6).
@export_range(0.0, 1.0, 0.05) var enemy_scaling: float = 0.0
## Mechanics and enemies this level may use. A pattern is only picked when every entry of its
## `requires` list is here (GDD §6: introduce one new mechanic at a time). Core movement pieces
## (gaps, fences, signs, walls) need no feature. Known features:
## - mechanics: ramps, ceilings (anti-grav pads and ceiling sections), pulsing (pulsing fences),
##   speed_pads
## - one per enemy type: cyborg, window_cyborg, host (cyborgs carrying a Bad Dream), hover_truck,
##   octodog, screech (from manholes and wall vents), drone, generator (fence generators)
## - screech_vents: sewer screeches from wall vents only (rare), for zones whose floor has no
##   manholes (GDD §9.5)
## - the planned ones in PLANNED_FEATURES
## Rules scripts run in this list's order (see LevelGenerator), so the campaign keeps the order in
## which the schedule introduces features.
@export var features: PackedStringArray = PackedStringArray(["ramps", "ceilings", "pulsing"])
## Features that start partway into the level (GDD §5: City 1 meets its cyborgs late in the level):
## feature name → share of the level (0–1). Nothing of that feature is placed before its start,
## by patterns or by rules scripts, and the first pattern picked from there uses it (as soon as one
## of its patterns fits), so the player meets it right after its first-encounter hint. Features not
## listed are there from the start.
## The campaign introduces each new feature this way (DESIGN-TBD: where in each level).
## (duplicate() shares this dictionary with the original: give a copy a new one, never edit it.)
@export var feature_starts: Dictionary[String, float] = {}
## Every feature appears at least once (GDD §5: anything introduced earlier keeps appearing
## later): each feature some pattern can place in the level is in the finished layout, whatever
## the seed. When a build misses one (chance never picked it, or a rule dropped it or cleared it
## away), the generator builds the level again with a pick of it forced elsewhere, and every rule
## still applies (LevelGenerator.GUARANTEE_SHARES). Campaign levels set it; endless mode turns it
## off on its copy (a 20-minute level brings every feature anyway), and quick play and tests that
## build their own levels leave it off, so they generate as before.
@export var guarantee_features: bool = false
## DESIGN-TBD: how often this level picks a feature's patterns, as a factor on their pick weight
## (feature name → factor; 1 when not listed, 0 leaves them out), e.g. Corporate 2's heavier
## military presence (GDD §5, proposed) and The Hush's hosts. A pattern requiring several listed
## features takes the product. It applies on top of the campaign's recency curve (feature_recency):
## the curve moves picks between the level's features, and these factors still scale them.
@export var feature_weights: Dictionary[String, float] = {}
## Levels since the campaign introduced each of this level's features (feature name → 0 in the
## level that introduces it, 1 in the next level, ...). Campaign.configure fills it in, with
## feature_recency, on its copy of a campaign level; level files, quick play, tests and boss arenas
## leave both empty, so their levels generate as before.
@export_storage var feature_ages: Dictionary[String, int] = {}
## The campaign's recency curve (GDD §5, owner's review P2 13: beyond the guarantee, a level's newest
## things get the most picks): with feature_ages, it scales each feature's pick weight by how
## recently the campaign introduced it (LevelGenerator, FeatureRecency). Null: every feature on equal
## terms (plus feature_weights).
@export_storage var feature_recency: FeatureRecency
## The core pattern file. Every other .json file in its folder is loaded too (LevelGenerator.load_for).
@export_file("*.json") var patterns_path: String = "res://data/patterns/prototype_patterns.json"
## The zone's visuals. Gameplay never depends on it.
@export var skin: ZoneSkin
## How much darker than its zone's normal light the level's scenery is (GDD §5: The Hush's darker
## lighting): 0 = the zone's own light, 1 = the darkest the skin allows (never pitch black,
## ZoneSkin.MIN_SCENERY_LIGHT). Only the scenery darkens: the sky, the distance fog and the skin's lit
## surfaces; hazards, triggers, enemies, the player, credits and the HUD keep their glow and their
## light (ZoneSkin.apply_darkness). DESIGN-TBD: The Hush's value.
@export_range(0.0, 1.0, 0.05) var darkness: float = 0.0

@export_group("Pacing")
## Empty run-up before the first pattern.
@export_range(0.0, 200.0, 1.0, "suffix:m") var start_clear_distance: float = 60.0
## Clear track kept before the finish line.
@export_range(0.0, 200.0, 1.0, "suffix:m") var end_clear_distance: float = 40.0
## Seconds of clear track between patterns at difficulty 0 and 1. DESIGN-TBD (docs/questions/g1.md):
## campaign levels set their own, closer than these defaults, for busier levels (GDD §3, owner's
## playtest September 30, 2026); the hard spacing stays the fairness floor (a switch across every lane
## between two patterns, at 6 lanes).
@export_range(0.2, 4.0, 0.05, "suffix:s") var spacing_seconds_easy: float = 1.8
@export_range(0.2, 4.0, 0.05, "suffix:s") var spacing_seconds_hard: float = 0.9
## Busier levels (GDD §3, owner's playtest September 30, 2026: "more gaps, obstacles and enemies ... so
## there is always something going on"): after the patterns and the rules, every stretch where nothing
## is going on or kept (LevelGenerator.fill_keep_outs) longer than this many seconds at run speed gets
## more of the level's plain obstacle patterns (holes and fences), spaced like the pattern pass places
## them (LevelGenerator._fill_empty_stretches): more patterns, never harder ones. 0 turns it off: the
## level is built exactly as before (quick play, the tests, boss arenas). DESIGN-TBD
## (docs/questions/g1.md): each campaign level's value.
@export_range(0.0, 10.0, 0.1, "suffix:s") var fill_empty_seconds: float = 0.0
## Quiet stretches and bursts (GDD §5, The Hush: long silent stretches broken by sudden threats).
## With quiet_seconds above 0, the level after its run-up alternates a quiet stretch of that many
## seconds at run speed with a burst of burst_seconds, quiet first. In a quiet stretch patterns are
## quiet_spacing_seconds apart, and one that places enemies is picked only if every feature it
## requires is in quiet_features (so it stays sparse obstacles, safe mechanics such as plain
## ceilings, and those enemies); a burst picks the level's other threats (patterns with a hole, a
## fence, a sign or an enemy, whose enemies stand in the burst), burst_spacing_seconds apart. The
## generator's rules still apply afterwards to all of it, and a burst takes at most one feature's
## introduction (feature_starts).
## 0 turns it off: the level is paced evenly (spacing_seconds_easy/hard), as every other level is.
## DESIGN-TBD: The Hush's numbers.
@export_range(0.0, 60.0, 0.5, "suffix:s") var quiet_seconds: float = 0.0
@export_range(1.0, 30.0, 0.5, "suffix:s") var burst_seconds: float = 8.0
@export_range(0.2, 10.0, 0.05, "suffix:s") var quiet_spacing_seconds: float = 4.0
@export_range(0.2, 4.0, 0.05, "suffix:s") var burst_spacing_seconds: float = 0.9
## Features whose enemy patterns belong to the quiet stretches: picked there, with their enemies
## inside the stretch, and not in bursts (The Hush: its hosts, standing alone in the silence; a chase
## starts only if the player kills one).
@export var quiet_features: PackedStringArray = PackedStringArray()

@export_group("Fairness rules")
## Longest gap the generator will place, as a fraction of a full jump's distance.
@export_range(0.3, 1.0, 0.05) var max_gap_jump_fraction: float = 0.8
## A ceiling section starts this far before its anti-grav pad so there is always a hull above.
@export_range(0.0, 10.0, 0.5, "suffix:m") var hull_lead_in: float = 3.0
## DESIGN-TBD: seconds of gap-free floor after a ceiling section ends, so the drop never lands in a hole.
@export_range(0.0, 3.0, 0.1, "suffix:s") var hull_landing_seconds: float = 1.2

@export_group("Floor cuts")
## GDD §9.9 (the Buzz Overdrive's cuts, task B4): "on 3 lanes, two lanes always stay whole": along a
## cut's stretch no other lane holds a hole. On more lanes, at most this many lanes besides the cut's
## own may hold holes there (LevelGenerator.whole_lanes_for_cut: 3 of 5 lanes and 4 of 6 stay whole
## with 1). DESIGN-TBD (docs/questions/b4.md): the limit at 5 and 6 lanes.
@export_range(0, 4) var cut_holes_beside: int = 1
## A player in a cut's lane when its warning starts can always leave it: from this long after the
## warning starts, a neighbouring lane has room to switch into before the cut meets the player
## (LevelGenerator.cut_escape_clear). DESIGN-TBD (docs/questions/b4.md).
@export_range(0.0, 2.0, 0.05, "suffix:s") var cut_reaction_seconds: float = 0.5

@export_group("Narrow ceilings")
## GDD §3 (decided September 26, 2026): ceilings don't have to cover every lane, and on one the player
## switches lanes only within its lanes. The share of this level's ceilings that cover a range of its
## lanes rather than all of them: pattern ceilings and those the rules add (a drone's pads, a Bad
## Dream chase's) alike (LevelGenerator.ceiling_lanes). 0: every ceiling covers every lane, and the
## level generates exactly as it did before narrow ceilings. DESIGN-TBD (docs/questions/b3.md): how
## often, and where they first appear.
@export_range(0.0, 1.0, 0.05) var narrow_ceiling_share: float = 0.0
## Share of the level (0–1) from which ceilings may be narrow; every ceiling before it covers every
## lane (City 2 shows its first ceilings full width). DESIGN-TBD (docs/questions/b3.md).
@export_range(0.0, 1.0, 0.05) var narrow_ceiling_start: float = 0.0
## Of the narrow ceilings, the share that cover a single lane; the others cover from two lanes to
## narrow_ceiling_max_lanes, each width as likely. A one-lane ceiling is simply ridden out (GDD §3),
## so it's very short (one_lane_ceiling_seconds) and only where its pattern puts nothing under it.
## DESIGN-TBD (docs/questions/b3.md).
@export_range(0.0, 1.0, 0.05) var one_lane_ceiling_share: float = 0.35
## The most lanes a narrow ceiling covers; 0 (or anything from the lane count less one up): all but one
## lane. A narrow ceiling whose pads lie further apart than this covers every lane instead.
## DESIGN-TBD (docs/questions/b3.md).
@export_range(0, 6, 1) var narrow_ceiling_max_lanes: int = 0
## How long a one-lane ceiling lasts from its pad to its end, at run speed (GDD §3: very short; a plain
## ceiling lasts 4 s). DESIGN-TBD (docs/questions/b3.md).
@export_range(0.5, 4.0, 0.1, "suffix:s") var one_lane_ceiling_seconds: float = 1.6

@export_group("Doodads")
## Zone doodads (GDD §3, owner's playtest September 30, 2026: "levels felt barren"): scenery pieces
## standing in lanes that never hurt; running into one pushes the player into a neighbouring lane.
## They take a lane rather than needing a reaction, so they make a level look busier without
## tightening its reaction windows. The generator puts them only where nothing else goes on
## (LevelGenerator: doodads): this is the chance that each stretch with room for one gets one (and
## the next spot in a long stretch, doodad_gap_seconds on, another). 0: none, and the level is built
## exactly as before (quick play, the tests, boss arenas). DESIGN-TBD (docs/questions/g5.md): each
## level's value.
@export_range(0.0, 1.0, 0.05) var doodad_share: float = 0.0
## Share of the level (0–1) from which doodads stand (City 1 introduces them a little way in).
@export_range(0.0, 1.0, 0.05) var doodad_start: float = 0.0
## How often each size class is picked (LevelLayout.DOODAD_SIZES; MovementTuning has their sizes); 0
## leaves a class out (City 1 starts with the smaller ones).
@export_range(0.0, 1.0, 0.05) var doodad_small_weight: float = 1.0
@export_range(0.0, 1.0, 0.05) var doodad_medium_weight: float = 1.0
@export_range(0.0, 1.0, 0.05) var doodad_large_weight: float = 1.0
## The least time between one doodad's end and the next one's front, at run speed, so a few in a row
## never make a slalom. DESIGN-TBD.
@export_range(0.5, 10.0, 0.1, "suffix:s") var doodad_gap_seconds: float = 2.5

@export_group("Credits")
## DESIGN-TBD (GDD §7): credit placement. Trails of small credits fill the clear stretches between
## patterns; high-value credits sit in risky spots (gap edges, by fences, far along wall runs).
@export_range(1.0, 10.0, 0.25, "suffix:m") var credit_trail_spacing: float = 3.0
@export_range(0, 20) var credit_trail_count: int = 6
## A clear stretch too short for a full trail gets a shorter one, down to this many credits (0: only
## full trails, as before). Busier levels leave fewer long clear stretches (GDD §3, owner's playtest
## September 30, 2026), so campaign levels take shorter trails to keep their credits about where they
## were (the economy is task R7's). DESIGN-TBD (docs/questions/g1.md).
@export_range(0, 20) var credit_trail_min: int = 0
## Chance that a clear stretch gets a trail.
@export_range(0.0, 1.0, 0.05) var credit_trail_chance: float = 0.8
## Chance that a gap gets an arc of credits over it and a richer credit right at its edge.
@export_range(0.0, 1.0, 0.05) var credit_gap_chance: float = 0.6
## Chance that a fence gets a richer credit in its risky spot (over a full fence, under a gapped one).
@export_range(0.0, 1.0, 0.05) var credit_fence_chance: float = 0.5
## Credits along the wall run after a ramp and along the ceiling after an anti-grav pad.
@export var credit_wall_runs: bool = true
@export var credit_ceilings: bool = true


func has_feature(feature: String) -> bool:
	return features.has(feature)


## The movement tuning this level runs on: `base` itself unless the level has a run speed of its own
## (run_speed above 0, and not base's already), else a copy of `base` at that speed. The generator,
## RunWorld and App all ask this, so a level is built and played at the same speed.
func movement_for(base: MovementTuning) -> MovementTuning:
	if base == null or run_speed <= 0.0 or is_equal_approx(base.run_speed, run_speed):
		return base
	var out: MovementTuning = base.duplicate() as MovementTuning
	out.run_speed = run_speed
	return out


## Share of the level (0–1) where `feature` starts: 0 unless feature_starts lists it.
func feature_start(feature: String) -> float:
	return clampf(float(feature_starts.get(feature, 0.0)), 0.0, 1.0)


## Factor on the pick weight of `feature`'s patterns: 1 unless feature_weights lists it.
func feature_weight(feature: String) -> float:
	return maxf(float(feature_weights.get(feature, 1.0)), 0.0)


## True if the campaign's recency curve shapes this level's pick weights (feature_recency, switched
## on, and the ages Campaign.configure gave the level's features).
func recency_on() -> bool:
	return feature_recency != null and feature_recency.enabled and not feature_ages.is_empty()


## The recency curve's factor for a pattern that requires `requires` (LevelGenerator): its newest
## feature's (the smallest age, so a pattern that shows off a new feature counts as one of its
## picks), no more than the cap of any capped feature it requires (FeatureRecency.max_factor); 1
## for a pattern that requires nothing, without the curve, or when no feature is dated.
func recency_factor(requires: Array) -> float:
	if not recency_on() or requires.is_empty():
		return 1.0
	var newest: int = -1
	var cap: float = INF
	for need: Variant in requires:
		var feature: String = String(need)
		var age: int = int(feature_ages.get(feature, -1))
		if age >= 0 and (newest < 0 or age < newest):
			newest = age
		if feature_recency.max_factor.has(feature):
			cap = minf(cap, float(feature_recency.max_factor[feature]))
	return minf(feature_recency.factor(newest), cap)


## True if the recency curve holds a pattern that requires `requires` at a capped factor (it
## requires a feature FeatureRecency.max_factor lists): the curve never scales it back with the rest.
func recency_capped(requires: Array) -> bool:
	if not recency_on():
		return false
	for need: Variant in requires:
		if feature_recency.max_factor.has(String(need)):
			return true
	return false


## True if the level alternates quiet stretches and bursts (quiet_seconds above 0).
func paced_in_bursts() -> bool:
	return quiet_seconds > 0.0


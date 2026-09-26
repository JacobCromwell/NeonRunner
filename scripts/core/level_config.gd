class_name LevelConfig
extends Resource
## One level: generator settings plus what the campaign shows. Campaign levels use fixed seeds.
## The campaign (Campaign/ZoneDef) sets difficulty and enemy_scaling from the level's position;
## standalone use (quick play, tests) takes the values stored here.

@export var id: StringName = &"prototype"
@export var display_name: String = "Prototype"
@export var level_seed: int = 1
## Lane count on floor and ceiling used by the generator. The game sets it from the device when a
## run starts (GameRules.lanes_pc / lanes_mobile); tests and the F1 debug key set it directly.
@export_range(3, 8) var lane_count: int = 3
## GDD §4: levels last 90–150 seconds.
@export_range(30.0, 150.0, 1.0, "suffix:s") var duration_seconds: float = 120.0
## 0 = easiest, 1 = hardest. In the campaign this is the campaign curve plus difficulty_bias.
@export_range(0.0, 1.0, 0.05) var difficulty: float = 0.3
## Added to the campaign's automatic difficulty curve for this level (GDD §6: each level can be
## tuned individually on top of the curve).
@export_range(-0.5, 0.5, 0.05) var difficulty_bias: float = 0.0
## DESIGN-TBD: how difficulty rises within one level. Added linearly from start to end.
@export_range(0.0, 1.0, 0.05) var difficulty_ramp: float = 0.25
## 0 = first campaign level, 1 = last: enemies scale fire rate, speed and health with it (GDD §6).
@export_range(0.0, 1.0, 0.05) var enemy_scaling: float = 0.0
## Mechanics and enemies this level may use. A pattern is only picked when every entry of its
## `requires` list is here (GDD §6: introduce one new mechanic at a time). Core movement pieces
## (gaps, fences, signs, walls) need no feature. Known features: ramps, ceilings, pulsing,
## speed_pads, and one per enemy type (cyborg, window_cyborg, host, hover_truck, octodog,
## screech, drone, generator).
@export var features: PackedStringArray = PackedStringArray(["ramps", "ceilings", "pulsing"])
## The core pattern file. Every other .json file in its folder is loaded too (LevelGenerator.load_for).
@export_file("*.json") var patterns_path: String = "res://data/patterns/prototype_patterns.json"
## The zone's visuals. Gameplay never depends on it.
@export var skin: ZoneSkin

@export_group("Pacing")
## Empty run-up before the first pattern.
@export_range(0.0, 200.0, 1.0, "suffix:m") var start_clear_distance: float = 60.0
## Clear track kept before the finish line.
@export_range(0.0, 200.0, 1.0, "suffix:m") var end_clear_distance: float = 40.0
## Seconds of clear track between patterns at difficulty 0 and 1.
@export_range(0.2, 4.0, 0.05, "suffix:s") var spacing_seconds_easy: float = 1.8
@export_range(0.2, 4.0, 0.05, "suffix:s") var spacing_seconds_hard: float = 0.9

@export_group("Fairness rules")
## Longest gap the generator will place, as a fraction of a full jump's distance.
@export_range(0.3, 1.0, 0.05) var max_gap_jump_fraction: float = 0.8
## A ceiling section starts this far before its anti-grav pad so there is always a hull above.
@export_range(0.0, 10.0, 0.5, "suffix:m") var hull_lead_in: float = 3.0
## DESIGN-TBD: seconds of gap-free floor after a ceiling section ends, so the drop never lands in a hole.
@export_range(0.0, 3.0, 0.1, "suffix:s") var hull_landing_seconds: float = 1.2

@export_group("Credits")
## DESIGN-TBD (GDD §7): credit placement. Trails of small credits fill the clear stretches between
## patterns; high-value credits sit in risky spots (gap edges, by fences, far along wall runs).
@export_range(1.0, 10.0, 0.25, "suffix:m") var credit_trail_spacing: float = 3.0
@export_range(0, 20) var credit_trail_count: int = 6
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


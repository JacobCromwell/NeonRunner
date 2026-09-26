class_name LevelConfig
extends Resource
## Per-level generator settings. Campaign levels use fixed seeds.

@export var level_seed: int = 1
## Lane count on floor and ceiling. 3 on mobile, 5–6 on PC (exact PC count open).
@export_range(3, 8) var lane_count: int = 3
## GDD §4: levels last 90–150 seconds.
@export_range(30.0, 150.0, 1.0, "suffix:s") var duration_seconds: float = 120.0
## 0 = easiest, 1 = hardest.
@export_range(0.0, 1.0, 0.05) var difficulty: float = 0.3
## DESIGN-TBD: how difficulty rises within one level. Added linearly from start to end.
@export_range(0.0, 1.0, 0.05) var difficulty_ramp: float = 0.25
## GDD §6: ramps arrive a few levels after Zone 1 starts. On here so the prototype can test them.
@export var ramps_enabled: bool = true
@export var ceilings_enabled: bool = true
@export_file("*.json") var patterns_path: String = "res://data/patterns/prototype_patterns.json"
## The zone's visuals. Gameplay never depends on it.
@export var skin: ZoneSkin

@export_group("Pacing")
## Empty run-up before the first pattern.
@export_range(0.0, 200.0, 1.0, "suffix:m") var start_clear_distance: float = 60.0
## Clear track kept before the finish line.
@export_range(0.0, 200.0, 1.0, "suffix:m") var end_clear_distance: float = 40.0
## Seconds of clear track between patterns at difficulty 0 and 1.
@export_range(0.2, 4.0, 0.05, "suffix:s") var spacing_seconds_easy: float = 1.5
@export_range(0.2, 4.0, 0.05, "suffix:s") var spacing_seconds_hard: float = 0.7

@export_group("Fairness rules")
## Longest gap the generator will place, as a fraction of a full jump's distance.
@export_range(0.3, 1.0, 0.05) var max_gap_jump_fraction: float = 0.8
## A ceiling section starts this far before its anti-grav pad so there is always a hull above.
@export_range(0.0, 10.0, 0.5, "suffix:m") var hull_lead_in: float = 3.0
## DESIGN-TBD: seconds of gap-free floor after a ceiling section ends, so the drop never lands in a hole.
@export_range(0.0, 3.0, 0.1, "suffix:s") var hull_landing_seconds: float = 1.2

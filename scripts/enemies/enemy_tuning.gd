class_name EnemyTuning
extends Resource
## Base tuning shared by every enemy type. Each type's resource (data/enemies/<type>.tres) extends
## this with its own values. Numbers that scale across the campaign come in early/late pairs:
## the level's enemy_scaling (0 = first level, 1 = last) picks a value between them (GDD §6).

@export_group("Spawning")
## How far ahead of the player the enemy is created, relative to its layout position.
@export_range(10.0, 400.0, 5.0, "suffix:m") var spawn_lead: float = 110.0

@export_group("Score")
## Level score for defeating it (GDD §7).
@export_range(0, 10000, 10) var score_value: int = 100

@export_group("Health")
## In laser tier 1 shots (GDD §8 damage reference: laser tier 1 deals 1).
@export_range(0.1, 100.0, 0.1) var health_early: float = 1.0
@export_range(0.1, 100.0, 0.1) var health_late: float = 1.0

@export_group("Generator")
## False for enemies that never come down to the floor lanes (fliers such as drones, wall-only
## enemies such as window cyborgs). The generator keeps a ceiling's landing zone and the spots of its
## pads off the floor the others use (GDD §3: the floor under a ceiling may be dangerous, but the
## player always lands safely and can step on the pad); see LevelGenerator.enemy_floor_span() and
## CeilingZones.
@export var uses_floor: bool = true
## The floor it uses before (toward the player) and after its layout position: where it stands,
## moves and attacks a player in its lane. Rules that plan a longer run for one enemy (the Octodog's
## charges) set params.floor_span on it instead.
@export_range(0.0, 100.0, 0.5, "suffix:m") var floor_reach_before: float = 10.0
@export_range(0.0, 100.0, 0.5, "suffix:m") var floor_reach_after: float = 10.0
## True for an enemy that only ever drives behind the runner and never stands on the track ahead of them (the
## Enforcer Truck, GDD §9.13): its layout entry's `at` is where the runner is as it arrives, not a spot it
## takes up, so checks that keep other enemies off a stretch ahead of the runner leave it out
## (Octodog.charge_clear).
@export var behind_runner: bool = false


## The value between `early` and `late` for a level's enemy_scaling `t` (0–1).
static func scaled(early: float, late: float, t: float) -> float:
	return lerpf(early, late, clampf(t, 0.0, 1.0))


func health_at(t: float) -> float:
	return scaled(health_early, health_late, t)

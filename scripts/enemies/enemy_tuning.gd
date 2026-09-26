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


## The value between `early` and `late` for a level's enemy_scaling `t` (0–1).
static func scaled(early: float, late: float, t: float) -> float:
	return lerpf(early, late, clampf(t, 0.0, 1.0))


func health_at(t: float) -> float:
	return scaled(health_early, health_late, t)

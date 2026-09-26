class_name PowerupTuning
extends Resource
## Numbers for the permanent power-ups (GDD §8). Edit data/tuning/powerups.tres.
## Per-tier values are arrays indexed by tier - 1. Most of these are still open in the design
## (OPEN_QUESTIONS §4), so everything marked DESIGN-TBD is a placeholder.

@export_group("Weapon")
## GDD §8: 4 tiers (laser, enhanced laser, missile, heavy missile). Damage is in laser tier 1 shots
## (GDD damage reference: tier 1 = 1, tier 4 kills a hover truck in 5 shots = 3).
## DESIGN-TBD: tiers 2 and 3.
@export var weapon_damage: PackedFloat32Array = PackedFloat32Array([1.0, 1.4, 2.0, 3.0])
## DESIGN-TBD: seconds between shots per tier (fire rate is open).
@export var weapon_fire_interval: PackedFloat32Array = PackedFloat32Array([0.32, 0.3, 0.55, 0.65])
## Shot speed per tier (m/s, relative to the track). Lasers are fast, missiles slower.
@export var weapon_shot_speed: PackedFloat32Array = PackedFloat32Array([90.0, 95.0, 55.0, 50.0])
## How far ahead auto-fire looks for targets.
@export_range(10.0, 150.0, 1.0, "suffix:m") var weapon_range: float = 70.0
## DESIGN-TBD: the heavy missile's splash radius (GDD §8: exact radius open).
@export_range(0.5, 10.0, 0.25, "suffix:m") var splash_radius: float = 3.5
## Share of a heavy missile's damage dealt as splash to other enemies nearby.
@export_range(0.0, 1.0, 0.05) var splash_damage_share: float = 0.5
## DESIGN-TBD: the heavy missile's bonus damage multiplier against the swarm boss (GDD §8).
@export_range(1.0, 5.0, 0.1) var swarm_bonus_multiplier: float = 2.0

@export_group("Claws")
## DESIGN-TBD: how much longer wall runs last with claws (OPEN_QUESTIONS §4).
@export_range(1.0, 3.0, 0.05) var claws_wall_time_multiplier: float = 1.5

@export_group("Juggernaut dash")
## DESIGN-TBD: duration, cooldown and speed (OPEN_QUESTIONS §4).
@export_range(0.1, 2.0, 0.05, "suffix:s") var dash_duration: float = 0.6
@export_range(1.0, 30.0, 0.5, "suffix:s") var dash_cooldown: float = 8.0
@export_range(0.0, 20.0, 0.5, "suffix:m/s") var dash_speed_bonus: float = 8.0

@export_group("Magnet")
## DESIGN-TBD: pull radius per tier (m). GDD §8 caps it at the player's lane plus the adjacent
## lanes, and it never pulls credits from another surface.
@export var magnet_radius: PackedFloat32Array = PackedFloat32Array([1.6, 2.6, 3.6])
@export_range(5.0, 80.0, 1.0, "suffix:m/s") var magnet_pull_speed: float = 30.0

@export_group("Slow time")
## PC only (GDD §3). DESIGN-TBD: strength, duration, cooldown (OPEN_QUESTIONS §4).
@export_range(0.1, 0.9, 0.05) var slow_time_scale: float = 0.5
## Real (unscaled) seconds the slow-down lasts.
@export_range(0.5, 10.0, 0.25, "suffix:s") var slow_time_duration: float = 3.0
@export_range(1.0, 60.0, 1.0, "suffix:s") var slow_time_cooldown: float = 20.0


## The value for `tier` (1-based) from a per-tier array, clamped to the array.
static func at_tier(values: PackedFloat32Array, tier: int) -> float:
	if values.is_empty():
		return 0.0
	return values[clampi(tier - 1, 0, values.size() - 1)]

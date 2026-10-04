class_name PowerupTuning
extends Resource
## Numbers for the permanent power-ups (GDD §8). Edit data/tuning/powerups.tres.
## Per-tier values are arrays indexed by tier - 1. Anything still marked DESIGN-TBD is a placeholder;
## the owner approved the rest as is (OPEN_QUESTIONS §D, "Owner's placeholder review").

@export_group("Weapon")
## GDD §8: 4 tiers (laser, enhanced laser, missile, heavy missile). Damage is in laser tier 1 shots
## (GDD damage reference: tier 1 = 1, tier 4 kills a hover truck or heli drone in 5 shots = 3).
## Tiers 2 and 3's damage (FB 26: 1.4 and 2.0).
@export var weapon_damage: PackedFloat32Array = PackedFloat32Array([1.0, 1.4, 2.0, 3.0])
## GDD §8 damage reference (owner's September 30, 2026 playtest): "higher tiers keep today's
## numbers, so upgrades feel like a bigger jump" (decided over raising enemy health, which would
## have changed every tier). Laser tier 1 alone takes this many more shots to kill every enemy
## except the sewer screech, which stays a one-hit kill at any tier. WeaponPowerup.damage() applies
## it as a smaller per-shot tier 1 hit against each target (max_health split across its base shot
## count plus this many), so health and tiers 2-4 are untouched.
@export_range(0, 10, 1) var tier1_extra_shots: int = 2
## Seconds between shots per tier (FB 26).
@export var weapon_fire_interval: PackedFloat32Array = PackedFloat32Array([0.32, 0.3, 0.55, 0.65])
## Shot speed per tier (m/s, relative to the track). Lasers are fast, missiles slower.
@export var weapon_shot_speed: PackedFloat32Array = PackedFloat32Array([90.0, 95.0, 55.0, 50.0])
## How far ahead auto-fire looks for targets, per tier. GDD §8 damage reference (owner's playtest,
## September 30, 2026): "the level one laser is too powerful, it kills all enemies too quickly," so
## tier 1's range is shorter, giving enemies room to close in before they fall; tiers 2-4 share
## today's 70 m unchanged (the GDD's rule: higher tiers keep their range unless they share the
## value, in which case it stays as it is).
## DESIGN-TBD (docs/questions/g4.md): the exact tier 1 distance. Placeholder: 42 m, about 60% of the
## old 70 m shared range (roughly 2.3 s of approach at the 18 m/s base run speed, down from 3.9 s).
@export var weapon_range: PackedFloat32Array = PackedFloat32Array([42.0, 70.0, 70.0, 70.0])
## The heavy missile's splash radius (GDD §8; FB 26: 3.5 m at half damage).
@export_range(0.5, 10.0, 0.25, "suffix:m") var splash_radius: float = 3.5
## Share of a heavy missile's damage dealt as splash to other enemies nearby.
@export_range(0.0, 1.0, 0.05) var splash_damage_share: float = 0.5
## The heavy missile's bonus damage multiplier against swarm enemies, splash included (FB 26, FB 29).
@export_range(1.0, 5.0, 0.1) var swarm_bonus_multiplier: float = 2.0
## Missiles (tiers 3–4) home on their target: how fast they turn (radians per second).
@export_range(0.0, 20.0, 0.25, "suffix:rad/s") var missile_turn_rate: float = 7.0
## Missiles leave the launcher angled this much away from the surface, then curve onto the target
## (0 = straight at it). Only the look: homing brings them back.
@export_range(0.0, 1.0, 0.05) var missile_launch_lift: float = 0.35

@export_group("Claws")
## How much longer wall runs last with claws (FB 24: 1.5x).
@export_range(1.0, 3.0, 0.05) var claws_wall_time_multiplier: float = 1.5

@export_group("Juggernaut dash")
## Duration and speed (FB 17: 0.6 s, +8 m/s) stay the same at every tier.
@export_range(0.1, 2.0, 0.05, "suffix:s") var dash_duration: float = 0.6
## The original tier's cooldown, retained for existing tuning resources.
@export_range(1.0, 30.0, 0.5, "suffix:s") var dash_cooldown: float = 8.0
## Tiers 2–4: the owner's dash upgrades recharge in 6 / 4 / 3 seconds (USER_REQUESTS.md).
@export var dash_upgrade_cooldowns: PackedFloat32Array = PackedFloat32Array([6.0, 4.0, 3.0])
@export_range(0.0, 20.0, 0.5, "suffix:m/s") var dash_speed_bonus: float = 8.0

@export_group("Magnet")
## Pull radius per tier (FB 23: 1.6 / 2.6 / 3.6 m). GDD §8 caps it at the player's lane plus the
## adjacent lanes, and it never pulls credits from another surface.
@export var magnet_radius: PackedFloat32Array = PackedFloat32Array([1.6, 2.6, 3.6])
@export_range(5.0, 80.0, 1.0, "suffix:m/s") var magnet_pull_speed: float = 30.0

@export_group("Slow time")
## PC only (GDD §3). Strength, duration, cooldown (FB 25: 0.5x for 3 s, 20 s cooldown).
@export_range(0.1, 0.9, 0.05) var slow_time_scale: float = 0.5
## Real (unscaled) seconds the slow-down lasts.
@export_range(0.5, 10.0, 0.25, "suffix:s") var slow_time_duration: float = 3.0
@export_range(1.0, 60.0, 1.0, "suffix:s") var slow_time_cooldown: float = 20.0


## Dash tier 1 keeps its original cooldown; higher tiers use the upgrade table, clamped at max.
func dash_cooldown_at(tier: int) -> float:
	if tier <= 1 or dash_upgrade_cooldowns.is_empty():
		return dash_cooldown
	return at_tier(dash_upgrade_cooldowns, tier - 1)


## The value for `tier` (1-based) from a per-tier array, clamped to the array.
static func at_tier(values: PackedFloat32Array, tier: int) -> float:
	if values.is_empty():
		return 0.0
	return values[clampi(tier - 1, 0, values.size() - 1)]

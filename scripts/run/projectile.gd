class_name Projectile
extends Hazard
## One pooled shot, fired through ProjectilePool. Enemy shots are enemy attacks (armor blocks them,
## GDD §8) and are resolved against the player by DamageRules like any hazard. Player shots damage
## enemies. Shots fly in straight lines (missiles may home) and their hits are swept, so a fast
## shot can never pass through a hitbox between frames. It isn't in the physics layers: the pool
## tests hits itself.

var velocity: Vector3 = Vector3.ZERO
var life: float = 0.0
## Fired by the player (hits enemies) rather than by an enemy (hits the player).
var friendly: bool = false
var damage: float = 1.0
## Splash damage radius and share (heavy missiles). 0 = no splash.
var splash_radius: float = 0.0
var splash_share: float = 0.0
## Bonus multiplier against swarm enemies (heavy missile vs the swarm boss, GDD §8).
var swarm_multiplier: float = 1.0
## Collision radius of the shot itself.
var radius: float = 0.15
## Missiles: the enemy to steer toward, and how fast they turn (rad/s). Null = straight.
var target: Enemy = null
var turn_rate: float = 0.0
## Visual style name, e.g. &"enemy_bolt", &"laser", &"missile".
var look: StringName = &""
var in_use: bool = false

var mesh_instance: MeshInstance3D


func _ready() -> void:
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false

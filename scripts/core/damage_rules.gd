class_name DamageRules
extends RefCounted
## The single place that decides what touching a hazard does (CLAUDE.md, architecture principle 8).
## Hazards and enemies only declare properties (Hazard: is_electrical, is_enemy_attack, is_solid,
## part; Enemy: stompable, claw_immune, dash_kills, ...). The player's protection arrives as a
## Defense snapshot. Falls aren't hazards: the Player handles them (grapple hook, GDD §8).
##
## Order (GDD §8–9 shared rules):
## 1. Inactive hazards and already-defeated enemies do nothing.
## 2. The juggernaut dash passes through hazards and defeats enemies it hits (unless the enemy
##    declares dash_kills = false, like the Bad Dream, which it passes through safely).
## 3. Dropping onto an enemy's top stomps it if it's stompable; claws beat spines and tentacles.
##    A weak point stomped from above defeats its enemy and is harmless otherwise.
## 4. Claws defeat any enemy on body contact, except claw-immune ones (bosses, the Bad Dream).
## 5. Invulnerability (after a block or revive) and god mode ignore everything harmful.
## 6. Armor blocks one electrical hazard or enemy attack, never a solid collision.
## 7. The shield blocks one hit of anything.
## 8. Otherwise the player dies (one hit ends the run, GDD §4).

enum Outcome {
	IGNORE,          ## No effect: inactive, invulnerable, passed through, or a harmless part.
	BLOCKED_ARMOR,   ## Armor broke instead of the player; the invulnerability window follows.
	BLOCKED_SHIELD,  ## The shield broke instead of the player; the invulnerability window follows.
	KILL,            ## The player dies.
	DEFEAT_ENEMY,    ## The contact defeats the enemy (claws or dash); the player is unharmed.
	STOMP,           ## The player stomped the enemy: it's defeated and the player bounces.
}


## What protects the player at the moment of contact.
class Defense:
	var armor: bool = false
	var shield: bool = false
	var invulnerable: bool = false
	var claws: bool = false
	var dashing: bool = false
	var god_mode: bool = false


## `stomping`: the player is dropping onto the hazard from above (the Player decides that from
## its motion and the hazard's top).
static func resolve(hazard: Hazard, defense: Defense, stomping: bool = false) -> Outcome:
	if not hazard.is_active():
		return Outcome.IGNORE
	var enemy: Enemy = hazard.enemy
	if enemy != null and not enemy.alive:
		return Outcome.IGNORE

	if defense.dashing and hazard.dash_passes:
		if enemy != null and enemy.dash_kills:
			return Outcome.DEFEAT_ENEMY
		return Outcome.IGNORE

	if enemy != null:
		if hazard.part == &"weak_point":
			return Outcome.STOMP if stomping else Outcome.IGNORE
		if stomping and hazard.part == &"top":
			if enemy.stompable:
				return Outcome.STOMP
			if defense.claws and not enemy.claw_immune:
				return Outcome.DEFEAT_ENEMY
		if defense.claws and not enemy.claw_immune and hazard.part != &"attack":
			return Outcome.DEFEAT_ENEMY

	if defense.invulnerable or defense.god_mode:
		return Outcome.IGNORE
	if defense.armor and (hazard.is_electrical or hazard.is_enemy_attack):
		return Outcome.BLOCKED_ARMOR
	if defense.shield:
		return Outcome.BLOCKED_SHIELD
	return Outcome.KILL


## The cause name reported when a contact defeats an enemy.
static func defeat_cause(outcome: Outcome, defense: Defense) -> StringName:
	if outcome == Outcome.STOMP:
		return &"stomp"
	return &"dash" if defense.dashing else &"claws"

class_name DamageRules
extends RefCounted
## The single place that decides what touching a hazard does (CLAUDE.md, architecture principle 8).
## The grey box has no power-ups yet, so every contact kills unless the player is invulnerable.
## Armor (blocks is_electrical and enemy attacks, not is_solid), shield, the invulnerability window,
## claws and dash get added here, never in enemy or obstacle scripts.

enum Outcome { IGNORE, BLOCKED, KILL }


static func resolve(hazard: Hazard, invulnerable: bool) -> Outcome:
	if not hazard.is_active() or invulnerable:
		return Outcome.IGNORE
	return Outcome.KILL

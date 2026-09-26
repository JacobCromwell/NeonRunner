class_name ClawsPowerup
extends PowerupModule
## Claws / skates (GDD §8). Everything they do is already shared core behaviour: contact kills live
## in DamageRules (the player's `claws` flag) and the longer wall runs in Player's wall-time
## multiplier, both set by RunWorld from the loadout. This module only lists them in the HUD state.


func hud_entry() -> Dictionary:
	return controller.make_hud_entry(id, tier, 1.0, world.player.claws, -1)

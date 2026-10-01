class_name GunModel
extends Node3D
## A model that shows a CyborgGun's telegraph (GDD §9.2: a visible charge-up before every burst). The
## gun only ever calls these three, so any enemy that fires the cyborgs' way can reuse it: the cyborgs'
## body (CyborgBody) and the Barnacle Turret's (BarnacleTurretModel, GDD §9.8). Visual only: nothing
## here touches collision or gameplay.


## The cannon's charge glow, 0 (idle) to 1 (about to fire): the visual half of the telegraph.
func set_charge(_amount: float) -> void:
	pass


## Points the cannon at a world point (while charging, then along the locked line while firing).
func aim_at(_world_point: Vector3) -> void:
	pass


## Stops aiming (the burst is over or was cancelled).
func clear_aim() -> void:
	pass

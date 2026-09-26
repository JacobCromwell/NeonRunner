class_name FakePowerups
extends Node
## Stands in for the power-up controller in HUD tests: hud_state() returns whatever `states` holds,
## in the controller's format: {id, icon, tier, ready 0–1, active, charges}.

var states: Array[Dictionary] = []


func hud_state() -> Array[Dictionary]:
	return states

extends "res://tests/helpers/dummy_enemy.gd"
## A test dummy that keeps `lead` metres ahead of the player (as a hover truck paces it), with a
## visible body, for weapon tests and the power-ups showcase. Spawn params: those of
## dummy_enemy.gd plus {lead: float (default: its distance ahead at spawn), height: float (metres
## above the floor), swarm: bool}.

var lead: float = 30.0
var height: float = 0.0


func _build() -> void:
	super._build()
	var p: Dictionary = spawn.get("params", {})
	lead = float(p.get("lead", float(spawn.get("at", 30.0)) - world.player_distance()))
	height = float(p.get("height", 0.0))
	is_swarm = bool(p.get("swarm", false))
	position.y = height
	var color := Color(1.0, 0.3, 0.2)
	if is_host:
		color = Color(0.7, 0.3, 1.0)
	elif immune_to_weapons:
		color = Color(0.4, 0.4, 0.45)
	GreyboxMaterials.add_box(self, Vector3(0.0, 0.55, 0.0), Vector3(0.9, 1.1, 0.9), GreyboxMaterials.flat(Color(0.12, 0.1, 0.14)))
	GreyboxMaterials.add_box(self, Vector3(0.0, 0.55, 0.47), Vector3(0.7, 0.18, 0.04), GreyboxMaterials.glow(color, 3.0))


func _tick(_delta: float) -> void:
	position.z = TrackGeometry.world_z(world.player_distance() + lead)


func should_retire() -> bool:
	return false

extends BossPart
## A boss part for framework tests: a 1 m body box (solid) with a weak point above it, at its spawn
## entry's lane and distance. Spawn params: {shares_health (default true), health, swarm}: a part with
## health of its own is an obstacle (it doesn't count as a kill) and may be a swarm cluster.

var body: Hazard
var weak: Hazard


func _build() -> void:
	var p: Dictionary = spawn.get("params", {})
	shares_health = bool(p.get("shares_health", true))
	if not shares_health:
		max_health = float(p.get("health", 5.0))
		is_obstacle = true
		is_swarm = bool(p.get("swarm", false))
	position = world.lane_point(int(spawn.get("lane", 1)), float(spawn.get("at", 30.0)))
	body = add_hitbox(&"body", Vector3(1.0, 1.0, 1.0), Vector3(0.0, 0.5, 0.0))
	weak = add_weak_point(Vector3(1.2, 0.4, 1.2), Vector3(0.0, 1.2, 0.0))


func aim_point() -> Vector3:
	return global_position + Vector3(0.0, 0.5, 0.0)

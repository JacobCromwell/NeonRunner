extends Enemy
## A plain box enemy for tests: a body, a stomp top, optional attack box and lane blocker, set by
## spawn params {stompable, claw_immune, dash_kills, health, blocker, attack, host, immune}.

var body: Hazard
var top: Hazard


func _build() -> void:
	var p: Dictionary = spawn.get("params", {})
	display_name = "dummy"
	stompable = bool(p.get("stompable", true))
	claw_immune = bool(p.get("claw_immune", false))
	dash_kills = bool(p.get("dash_kills", true))
	# A host is a declared property of its own: weapons hit hosts (GDD §9.7, owner, October 8, 2026), so
	# "immune" asks for immune_to_weapons separately.
	is_host = bool(p.get("host", false))
	immune_to_weapons = bool(p.get("immune", false))
	max_health = float(p.get("health", 3.0))
	score_value = 100
	position = world.lane_point(int(spawn.get("lane", 1)), float(spawn.get("at", 30.0)))
	body = add_hitbox(&"body", Vector3(0.9, 1.1, 0.9), Vector3(0.0, 0.55, 0.0), bool(p.get("attack", false)))
	top = add_hitbox(&"top", Vector3(1.0, 0.3, 1.0), Vector3(0.0, 1.2, 0.0), bool(p.get("attack", false)))
	if bool(p.get("blocker", false)):
		add_lane_blocker(Vector3(world.geo.lane_width * 0.9, 1.5, 12.0), Vector3(0.0, 0.75, 0.0))


func aim_point() -> Vector3:
	return global_position + Vector3(0.0, 0.6, 0.0)

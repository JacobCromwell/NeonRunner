class_name HostileTakeoverLobby
extends BossPart
## The defeat's set (GDD §10: "the locomotive derails and ploughs through the lobby of a corporate tower,
## bringing down a giant, soulless logo sculpture"): a corporate tower beside the line with a sky lobby at
## the train's level (HostileTakeoverModel.lobby_tower) and, on its plaza toward the line, the brand's mark
## as a giant steel sculpture (logo_sculpture). Built once with the fight and hidden; the encounter stands
## it ahead beside the line as the defeat begins (place), and topples the sculpture as the locomotive
## ploughs in (topple). Looks only: no hitbox, no target.

## The tower's footprint, and how far beyond the sound barrier its lobby's glass front stands.
const TOWER := Vector2(26.0, 24.0)
const LOBBY_OUT: float = 16.0
## The sculpture stands this far out from the barrier, on the plaza before the lobby.
const SCULPTURE_OUT: float = 7.0

var tower: MeshInstance3D
var sculpture: Node3D
## Where it stands (track distance of the lobby's middle) and on which side (-1 left, 1 right).
var at: float = 0.0
var side: int = 1
var _topple: float = 0.0


func _build() -> void:
	display_name = "the lobby"
	is_obstacle = true
	immune_to_weapons = true
	top_level = true
	tower = MeshBatch.add_instance(self, HostileTakeoverModel.lobby_tower(TOWER.x, TOWER.y, world.skin), "Tower")
	sculpture = Node3D.new()
	sculpture.name = "Sculpture"
	add_child(sculpture)
	MeshBatch.add_instance(sculpture, HostileTakeoverModel.logo_sculpture(world.skin), "Mark")
	visible = false


## Stands it beside the line on `p_side` with its lobby's middle at track distance `p_at`, its lobby facing
## the line, the sculpture upright.
func place(p_at: float, p_side: int) -> void:
	at = p_at
	side = p_side if p_side != 0 else 1
	var lobby_x: float = side * (world.geo.wall_x() + LOBBY_OUT)
	# Its own +z (the lobby's front) faces the line: turned a quarter about y.
	global_transform = Transform3D(Basis(Vector3.UP, -side * PI * 0.5), Vector3(lobby_x, 0.0, TrackGeometry.world_z(at)))
	sculpture.position = Vector3(0.0, 0.0, LOBBY_OUT - SCULPTURE_OUT)
	_topple = 0.0
	sculpture.rotation = Vector3.ZERO
	visible = true


## The sculpture toppling over (0 upright, 1 down on its face toward the line).
func topple(amount: float) -> void:
	_topple = clampf(amount, 0.0, 1.0)
	var k: float = _topple * _topple
	sculpture.rotation = Vector3(k * PI * 0.5, 0.0, 0.0)


## Where its lobby's front is, in world space (the crash's burst).
func lobby_world() -> Vector3:
	return global_transform * Vector3(0.0, 4.0, -1.5)


## Puts it away.
func hide_set() -> void:
	visible = false


## Never a target.
func targetable() -> bool:
	return false


func _on_defeated(_cause: StringName) -> void:
	pass

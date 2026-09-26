class_name ZoneSkin
extends Resource
## The visual layer for one zone (CLAUDE.md, architecture principle 2). TrackBuilder creates
## every collision shape and gameplay node, then calls these hooks to decorate each abstract
## piece. Skins add meshes (later: lights, sounds, props) and never collision or gameplay.
## Hazards must keep the same colour and shape language in every skin (pink crackle = fence).
##
## `parent`-based hooks use the chunk's space, which is world space: x = sideways,
## y = up, z = -distance. Hooks that receive a gameplay node work in that node's local space.


## Which zone variant enemies dress in (GDD §9: e.g. the sleek "city" cyborg and hover truck, or the
## patched-together "scavenger" versions in grimy zones). Enemies read it to pick their look; their
## hazard colours and shapes stay the same everywhere.
@export var enemy_variant: StringName = &"city"


func make_environment() -> Environment:
	return Environment.new()


## One lane's solid floor. center/size describe the collision box, whose top is at y = 0.
## edge_start/edge_end say whether a gap borders the segment at that end.
func floor_segment(_parent: Node3D, _center: Vector3, _size: Vector3, _lane_x: float,
		_edge_start: bool, _edge_end: bool) -> void:
	pass


## One side wall between two track distances. face_x is the wall face's signed world x.
func wall_section(_parent: Node3D, _side: int, _face_x: float, _start: float, _end: float) -> void:
	pass


## An electric fence's energy field, the size of its hitbox and centred on the hazard.
## ground_y is the floor height in hazard-local space; gapped fences are open underneath.
func fence(_hazard: Hazard, _size: Vector3, _ground_y: float, _gapped: bool) -> void:
	pass


## A sign on a wall, the size of its hitbox and centred on the hazard.
func wall_sign(_hazard: Hazard, _size: Vector3) -> void:
	pass


## A ceiling section. center/size describe the collision box; its underside is the surface.
## lane_edges_x are the world x positions of the seams between ceiling lanes.
func hull(_parent: Node3D, _center: Vector3, _size: Vector3, _lane_edges_x: Array[float]) -> void:
	pass


## An anti-grav pad, the size of its trigger volume and centred on it. The floor is at -size.y / 2.
func pad(_trigger: Area3D, _size: Vector3) -> void:
	pass


## A ramp onto the wall on `side`, the size of its trigger volume and centred on it.
func ramp(_trigger: Area3D, _size: Vector3, _side: int) -> void:
	pass


## A speed pad, the size of its trigger volume and centred on it. The floor is at -size.y / 2.
func speed_pad(_trigger: Area3D, _size: Vector3) -> void:
	pass


func finish_line(_parent: Node3D, _width: float, _distance: float) -> void:
	pass

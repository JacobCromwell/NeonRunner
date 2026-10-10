class_name MechaGuppySkin
extends BeachSkin
## The arena of Mecha Guppy and Captain Cogs (GDD §10, the Beach's boss; task E5e-b1): the Beach's skin
## (BeachSkin: its sand, pools, hazards, pads, shore, sky and light) for a fight with no side walls, whose street
## Mecha Guppy has eaten from the start and whose ceilings are the climb's own tiki huts:
## - wall_section() and wall_gap() draw the open shore on both sides (BeachOpen.shore_side: the street's edge
##   dropping to the beach, the sea, palms and umbrellas) with no shacks and none of the standard gap marks (there's
##   no wall anywhere to have a gap in: the encounter leaves a wall gap over every lap, MechaGuppy._plan_lap), and
##   under the street the pools' water (the street is a gap in every lane: the water below the climb), with its
##   splash watch;
## - ceiling_section() and hull() draw nothing: the climb's huts are MechaGuppyLooks', built with the collision
##   BossProps.ceiling_lanes gives them (one section per run of lanes ending together: the skin would dress each
##   section on its own, with seams).
## Under Sunset Strip's sky in the campaign (Campaign.configure_boss: the fight after a level keeps that level's sky).
## DESIGN-TBD (docs/questions/e5e.md): its data (data/bosses/beach_boss_skin.tres) makes the arena hazier than the
## Beach's levels, fully fogged past fog_end (200 m; fog_max 1): the long drop below the towers hazes over with depth,
## and MechaGuppyStairs plans the climb no nearer than that edge of sight, so nothing ever changes where it's seen.

## How far apart the open shore's scenery repeats when nothing bounds it (a wall gap's ends would): far past any
## lap's length.
const OPEN: float = 1.0e7


func wall_section(parent: Node3D, side: int, face_x: float, start: float, end: float) -> void:
	_shore(parent, side, face_x, start, end)


func wall_gap(parent: Node3D, side: int, face_x: float, start: float, end: float, _gap: Vector2) -> void:
	_shore(parent, side, face_x, start, end)


func ceiling_section(_parent: Node3D, _section: CeilingSection) -> void:
	pass


func hull(_parent: Node3D, _center: Vector3, _size: Vector3, _lane_edges_x: Array[float]) -> void:
	pass


## One side of a chunk's piece [start, end]: the open shore beyond the street's edge, the black steel below it, and
## with the left side the water under the street (and its splash watch).
func _shore(parent: Node3D, side: int, face_x: float, start: float, end: float) -> void:
	_wall_x = absf(face_x)
	var batch := MeshBatch.new()
	open().shore_side(batch, side, face_x, start, end, Vector2(-OPEN, OPEN))
	sand().below_wall(batch, side, face_x, start, end)
	if side < 0:
		sand().below(batch, absf(face_x), start, end)
		watch_water(parent, absf(face_x), start, end)
	batch.commit(parent)

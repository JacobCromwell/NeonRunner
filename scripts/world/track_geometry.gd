class_name TrackGeometry
extends RefCounted
## Converts abstract track coordinates (lane index, distance, wall side) to world space.
## Forward is -Z in Godot, so world z = -distance. Lanes are movement targets only;
## nothing uses them for collision.

var lane_count: int
var lane_width: float
var wall_margin: float


func _init(p_lane_count: int, tuning: MovementTuning) -> void:
	lane_count = p_lane_count
	lane_width = tuning.lane_width
	wall_margin = tuning.wall_margin


func lane_x(lane: int) -> float:
	return (float(lane) - (lane_count - 1) * 0.5) * lane_width


## Half the width of the lanes, from track centre to the outer lane edge.
func half_width() -> float:
	return lane_count * lane_width * 0.5


## Distance from track centre to each wall face.
func wall_x() -> float:
	return half_width() + wall_margin


## World x range [min, max] covered by a lane's floor. Outer lanes reach the wall.
func lane_floor_span(lane: int) -> Vector2:
	var lo: float = lane_x(lane) - lane_width * 0.5
	var hi: float = lane_x(lane) + lane_width * 0.5
	if lane == 0:
		lo = -wall_x()
	if lane == lane_count - 1:
		hi = wall_x()
	return Vector2(lo, hi)


static func world_z(distance: float) -> float:
	return -distance

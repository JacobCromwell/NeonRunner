class_name CeilingSection
extends RefCounted
## One ceiling section as a zone skin dresses it (ZoneSkin.ceiling): where it is, which lanes it
## covers, and its collision box. A ceiling covers a contiguous range of lanes, every lane or fewer
## (a narrow ceiling, GDD §3: "ceilings don't have to cover every lane"), at any lane count. Its
## collision box spans exactly those lanes (TrackBuilder, BossProps), so a skin that builds from the
## box alone follows the range for free; reaches_wall() says which of its sides reach the street's edge
## (where a structure can run into a building face) and which are free edges in mid-street.
## Chunk space is world space: x = sideways, y = up, z = -distance.

## Track distances of its near and far ends.
var start: float = 0.0
var end: float = 0.0
## The lanes it covers, first to last (left to right), and how many lanes the track has.
var first_lane: int = 0
var last_lane: int = 0
var lane_count: int = 3
var lane_width: float = 2.4
## Its collision box: centre and size (its underside, the surface, is at center.y - size.y / 2).
var center := Vector3.ZERO
var size := Vector3.ONE
## World x of the seams between its lanes, left to right (none for a one-lane ceiling).
var lane_edges_x: Array[float] = []
## Distance from the track's centre to each wall face.
var wall_x: float = 0.0


## The section from `start` to `end` over lanes `lanes` (Vector2i(first, last)) of the track `geo`
## describes, its underside at `underside_y` and its box `thickness` deep. A full-width section's box
## spans the lanes (TrackGeometry.half_width() to each side of the centre), as it always has; a narrow
## one's spans its own lanes' floor width, lane edge to lane edge.
static func make(geo: TrackGeometry, underside_y: float, thickness: float, p_start: float, p_end: float,
		lanes: Vector2i) -> CeilingSection:
	var s := CeilingSection.new()
	s.start = p_start
	s.end = p_end
	s.lane_count = geo.lane_count
	s.lane_width = geo.lane_width
	s.first_lane = clampi(lanes.x, 0, geo.lane_count - 1)
	s.last_lane = clampi(lanes.y, s.first_lane, geo.lane_count - 1)
	s.wall_x = geo.wall_x()
	var x0: float = -geo.half_width()
	var x1: float = geo.half_width()
	if not s.full():
		x0 = geo.lane_x(s.first_lane) - geo.lane_width * 0.5
		x1 = geo.lane_x(s.last_lane) + geo.lane_width * 0.5
	s.center = Vector3((x0 + x1) * 0.5, underside_y + thickness * 0.5, -(p_start + p_end) * 0.5)
	s.size = Vector3(x1 - x0, thickness, p_end - p_start)
	for lane: int in range(s.first_lane + 1, s.last_lane + 1):
		s.lane_edges_x.append(geo.lane_x(lane) - geo.lane_width * 0.5)
	return s


## True if it covers every lane.
func full() -> bool:
	return first_lane <= 0 and last_lane >= lane_count - 1


## How many lanes it covers.
func lanes() -> int:
	return last_lane - first_lane + 1


## True if its side toward `side` (-1 left, +1 right) is at the street's edge: it covers the
## outermost lane there, so a structure can run into the building face beyond it. A side that doesn't
## is a free edge over a floor lane.
func reaches_wall(side: int) -> bool:
	return first_lane <= 0 if side < 0 else last_lane >= lane_count - 1


## World height of its underside (the surface a runner hangs from).
func underside_y() -> float:
	return center.y - size.y * 0.5


## World x of its collision box's edge toward `side` (-1 left, +1 right).
func edge_x(side: int) -> float:
	return center.x + side * size.x * 0.5

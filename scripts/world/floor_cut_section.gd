class_name FloorCutSection
extends RefCounted
## What a zone skin draws a floor cut from (ZoneSkin.floor_cut; task B4, GDD §9.9): the stretch of one
## lane's floor that turns into a gap during play, as the track builds it (FloorCut), and where the
## skin registers the parts of its look so the cut can show them as it runs. Chunk space, which is
## world space: x across, y up (the floor's top at y = 0), z = -distance.
##
## The cut runs from `end` back toward the player to `start`; at any moment the floor of [start, front]
## is whole and [front, end] is a hole. The track draws the whole floor itself (the skin's own
## floor_segment, in short slices it hides and shortens as the front passes), so the skin draws only
## the hole, in four kinds of part, each built where the section says and then moved by the cut:
## - add_static(): the inside of the hole over the whole stretch, below the floor (its walls, its far
##   end): never moved, and hidden under the floor until the floor above it goes. Keep it below y = 0
##   and inside the lane's floor (x0 to x1), so it never shows through whole floor. No bottom where the
##   zone draws its own plane below the street (task H3: the cut shows what a gap does).
## - add_span(): what runs along the hole, built over the whole stretch [start, end] (the orange lips
##   on the neighbouring lanes' edges): shown once the cut has begun, scaled along the track so it
##   covers [front, end]. Build it so it reads the same stretched (plain colours, or patterns from
##   world position).
## - add_front(): the solid floor's far edge, facing away from the player, built at `end` as if the
##   front were there (the orange lip on the floor's last few centimetres): moved to the front.
## - add_far(): the far side of the hole, facing the player, at `end` (the lip on the floor beyond it,
##   the strip along the top of its face, a halo): shown once the cut has begun.
## The cut's edges glow the usual gap-edge orange right on the collision edge, and its inside is dark,
## so it reads as a hole at a glance like any gap (CLAUDE.md readability rules). Nothing in it
## flickers; anything that would must honour Reduced flashing.

## The lane it cuts, and how many the track has.
var lane: int = 0
var lane_count: int = 3
## Track distances: the cut runs from `end` back to `start` (start < end).
var start: float = 0.0
var end: float = 0.0
## The lane's floor across the track (its collision box: the outer lanes' run on to the wall).
var x0: float = 0.0
var x1: float = 0.0
## The lane's middle and width.
var lane_x: float = 0.0
var lane_width: float = 2.4
## The wall faces' distance from the track's middle.
var wall_x: float = 0.0
## The floor's thickness (TrackBuilder.FLOOR_THICKNESS): its collision box's bottom is this far down.
var thickness: float = 1.0

var statics: Array[Node3D] = []
var spans: Array[Node3D] = []
var fronts: Array[Node3D] = []
var fars: Array[Node3D] = []


## The section for cut `cut` (a LevelLayout.cuts entry) on a track of `geo`'s lanes.
static func make(geo: TrackGeometry, cut: Dictionary, p_thickness: float) -> FloorCutSection:
	var s := FloorCutSection.new()
	s.lane = int(cut["lane"])
	s.lane_count = geo.lane_count
	s.start = float(cut["start"])
	s.end = float(cut["end"])
	var span: Vector2 = geo.lane_floor_span(s.lane)
	s.x0 = span.x
	s.x1 = span.y
	s.lane_x = geo.lane_x(s.lane)
	s.lane_width = geo.lane_width
	s.wall_x = geo.wall_x()
	s.thickness = p_thickness
	return s


## True if a lane runs beside the cut on `side` (-1 left, +1 right); false where its floor runs on to
## the wall.
func has_neighbour(side: int) -> bool:
	return lane + side >= 0 and lane + side < lane_count


## The x of the cut's edge on `side` (-1 left, +1 right): where the hole meets the neighbouring lane's
## floor (or the wall).
func edge_x(side: int) -> float:
	return x0 if side < 0 else x1


## The stretch's length.
func length() -> float:
	return end - start


func add_static(node: Node3D) -> void:
	statics.append(node)


func add_span(node: Node3D) -> void:
	spans.append(node)


func add_front(node: Node3D) -> void:
	fronts.append(node)


func add_far(node: Node3D) -> void:
	fars.append(node)

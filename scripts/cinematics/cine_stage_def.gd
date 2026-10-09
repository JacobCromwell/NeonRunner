class_name CineStageDef
extends Resource
## The set a cinematic plays on (CineTimeline.stage): a stretch of track the track builder builds, dressed
## in a zone's skin, with the pieces listed here. CineStage builds it.
##
## Lanes are counted from the start lane (the lane a level's runner starts in, lane_count / 2): 0 is
## that lane, -1 the one to its left, +1 to its right; a lane past the street's edge is left out, so a
## stage reads the same at 3, 5 and 6 lanes.

## Its look. Empty: the slot's own look, from the zone's data (CineStage.skin_for): the zone's skin, and
## before a boss the fight's arena's (BossDef.arena.skin) if it has one, so a later change of either
## reaches the cinematic.
@export var skin: ZoneSkin
## Lanes. 0: as many as a level on this device has (App.lane_count()), so the street matches the level
## that follows.
@export_range(0, 8) var lanes: int = 0
## Its length, metres. The track builder draws the finish line at the end: keep it past anything the
## camera sees.
@export_range(40.0, 5000.0, 10.0, "suffix:m") var length: float = 1000.0
## Ceilings over every lane, (start, end) along the track, metres. Scenery here: nothing needs a pad.
@export var ceilings: PackedVector2Array = PackedVector2Array()
## Holes in the floor: (lane from the start lane, start, end).
@export var gaps: PackedVector3Array = PackedVector3Array()
## Anti-grav pads: (lane from the start lane, where along the track).
@export var pads: PackedVector2Array = PackedVector2Array()
## Openings in the side walls: (side, start, end), side -1 the left wall and 1 the right. The track builder
## leaves the wall out there and the skin dresses the opening as in a level (ZoneSkin.wall_gap: its marked
## edges, and in the City the road far below), so a cinematic can look out of the street.
@export var wall_gaps: PackedVector3Array = PackedVector3Array()

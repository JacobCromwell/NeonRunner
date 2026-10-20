class_name DebrisMazeTuning
extends Resource
## The debris maze's numbers (task O2; GDD §5, Zone 8, owner, October 20, 2026: in the Terminal "doodads stand so
## thickly that the empty space between them forms a maze, and the runner can't get through without dashing"; its first
## level "the debris maze", its second "a normal run with stretches of maze"). DebrisMaze builds a level's maze from them
## (scripts/world/debris_maze.gd, which says what each piece is); each Terminal level names its own
## (LevelConfig.debris_maze_tuning: data/tuning/terminal_maze_1.tres and terminal_maze_2.tres), and a level with the
## `debris_maze` feature and none of its own takes data/tuning/debris_maze.tres. Times are seconds at the level's run
## speed. The F6 panel shows the level's own (Restart level rebuilds the maze). Every number is DESIGN-TBD
## (docs/questions/o2.md).

@export_group("Stretches")
## The share of the level, from the feature's start to its end-clear stretch, the maze's blocks cover: most of Rubble
## Line ("the debris maze"), a few stretches of Last Stop ("a normal run with stretches of maze"). The level is cut into
## as many equal slots as blocks of block_seconds fill that share, each slot ending in a block and its breather.
@export_range(0.05, 1.0, 0.05) var level_share: float = 0.5
## The longest a block (one stretch of maze, from its first wall's front to its last wall's back) lasts. A slot too short
## for one this long, its run-in and its breather takes a shorter one.
@export_range(4.0, 40.0, 0.5, "suffix:s") var block_seconds: float = 12.0
## Open floor before a block's first wall, every lane clear: the runner sees the way in and can be in any lane by it.
@export_range(0.5, 4.0, 0.1, "suffix:s") var run_in_seconds: float = 1.0
## Track after a block's last wall before the next slot: first its breather (a dash's carry and exit_clear_seconds,
## open in every lane, where a ceiling over the block's last wall lets its rider down), then normal track, where a
## level's holes may go (a wider gap's zone, about 2.3 s with its margins, fits past a 3.6 s one).
@export_range(1.0, 10.0, 0.1, "suffix:s") var breather_seconds: float = 2.4
## Clear floor past where a dash through a block's last wall ends (the dash's carry), before anything else may stand or
## open in any lane (a hole, a doodad): the runner who breaks out of the maze has this long to see what's next, and a
## hole's own margin (WideGapTuning.clear_before_seconds) comes on top.
@export_range(0.0, 3.0, 0.1, "suffix:s") var exit_clear_seconds: float = 0.5

@export_group("Rooms and walls")
## How far one wall's front lies from the next one's (a room and the wall before it). A room's length is what its
## dividers' pieces fill, so it comes out within a small doodad's length of this.
@export_range(0.6, 3.0, 0.05, "suffix:s") var room_seconds: float = 1.4
## The least rooms a block has (two walls make one room): a slot with room for fewer has no block.
@export_range(1, 8) var min_rooms: int = 2
## The share of walls built of large debris (6.5 m deep along the track) rather than medium (3.6 m).
@export_range(0.0, 1.0, 0.05) var large_wall_share: float = 0.25
## The chance that a lane of a room is a divider (debris along it from one wall to the next, cutting the room into
## cells); never two side by side, and never every lane.
@export_range(0.0, 0.8, 0.05) var divider_share: float = 0.35
## The chance that a lane of a wall is an opening (no debris there), where the lanes on both sides of the wall are open;
## never every lane. A wall with none is a wall every way through must dash.
@export_range(0.0, 1.0, 0.05) var opening_share: float = 0.3

@export_group("Breaks")
## How many dashes the block's best way through takes, at the least and at the most ("how many breaks are needed"):
## the generator draws its walls and openings until a block's least dashes lie in this range (DebrisMaze.min_breaks).
## 1 or more: the runner can't get through without dashing (GDD §5).
@export_range(0, 6) var breaks_min: int = 1
@export_range(0, 6) var breaks_max: int = 2

@export_group("Ceilings")
## The share of blocks with a one-lane ceiling over their last wall: a shortcut whose anti-grav pad lies in an open cell
## of the block's last room (one with no way out but a dash, where there is one) and whose rider comes down in the
## breather after it. A level that lists `ceilings` and keeps none of its patterns' gets one on its first block that
## has room for it.
@export_range(0.0, 1.0, 0.05) var ceiling_share: float = 0.35

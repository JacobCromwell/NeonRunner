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
## How much of the level, from the feature's start to its end-clear stretch, is maze: most of Rubble Line ("the debris
## maze"), a few stretches of Last Stop ("a normal run with stretches of maze"). The level is cut into as many equal
## slots as blocks of block_seconds fill this share of it, each slot ending in a block's run-in, the block and its
## breather; a slot too short for all three takes a shorter block, so the blocks cover less than this share where the
## run-ins and breathers are long (Rubble Line's 0.85: eight blocks over about two thirds of the level; Last Stop's
## 0.35: four over about a third).
@export_range(0.05, 1.0, 0.05) var level_share: float = 0.5
## The longest a block (one stretch of maze, from its first wall's front to its last wall's back) lasts. A slot too short
## for one this long, its run-in and its breather takes a shorter one.
@export_range(4.0, 40.0, 0.5, "suffix:s") var block_seconds: float = 12.0
## Open floor before a block's first wall, every lane clear: the runner sees the way in and can be in any lane by it.
@export_range(0.5, 4.0, 0.1, "suffix:s") var run_in_seconds: float = 1.0
## Track after a block's last wall before the next slot: first its breather (a dash's carry and exit_clear_seconds,
## open in every lane, where a ceiling over the block's last wall lets its rider down), then normal track, where a
## level's holes may go. In a level that asks for wider gaps, a slot too tight to leave one's zone (with the level's
## spacing either side, about 2.3 s in the Terminal) between its block and the next takes a shorter block
## (DebrisMaze.gap_room).
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

@export_group("Escape")
## DESIGN-TBD (items 1195-1199 in docs/OPEN_QUESTIONS*.md): this group's numbers and the escape's model; the Centipedes
## group's, items 1201 and 1203; the Gaps group's, item 1204 (task O5).
## How many of the level's blocks end in an escape (task O5; the owner, October 22, 2026: "a section of maze that will
## make it so the player needs to escape using the anti-grav pad"): the block's last maze wall opens onto an open room
## with an anti-grav pad in it, and past that room a barrier of debris too deep for one dash, with a one-lane ceiling over
## it from the pad. A runner who misses the pad is stopped at the barrier and needs more than one dash, waiting for the
## dash in between, to break through (never stuck for good). The first comes in the first slot whose block starts at
## escape_from of the level or later, the others in the slots after it, spread evenly to the last.
@export_range(0, 4) var escape_blocks: int = 0
## Where in the level (a share of its length) the first escape block may come at the earliest.
@export_range(0.0, 1.0, 0.05) var escape_from: float = 0.5
## The barrier's depth along the track, in large pieces of debris a sliver apart in every lane (the owner's sketch: four
## rows; the Terminal's levels 5, as at their speed one dash smashes up to four). Never fewer than make it more than one
## dash deep at the level's speed (DebrisMaze.escape_pieces).
@export_range(2, 8) var escape_pieces: int = 4

@export_group("Centipedes")
## How many Cybernetic Centipedes this level's maze holds, against the centipede's own placement numbers
## (CentipedeTuning: block_share, second_share, max_per_block): each block's draw is scaled by this, and so is its most
## (task O5; the owner, October 22, 2026: Rubble Line about 20 to 30% more, Last Stop about double). 1 places exactly as
## the centipede's numbers say.
@export_range(0.5, 4.0, 0.05) var centipede_scale: float = 1.0
## Ambush centipedes this level's maze holds (task O5; the owner, October 22, 2026: two in Last Stop, in its last half):
## each hides inside a divider of a block from ambush_from of the level on (one a block) and breaks out as the runner comes near (CentipedeTuning.ambush_distance). Counted apart from
## centipede_scale's.
@export_range(0, 6) var ambush_count: int = 0
## Where in the level (a share of its length) the first block an ambush may hide in starts at the earliest.
@export_range(0.0, 1.0, 0.05) var ambush_from: float = 0.5

@export_group("Gaps between blocks")
## Rows of holes across every lane, to jump, in the normal track between two blocks (task O5; the owner, October 22,
## 2026: "add some more gaps to jump over in the sections in between maze portions"): this many in each stretch from one
## block's keep-out to the next block's run-in, spread along it where they fit (DebrisMaze.place_gaps). They go in after
## the level's wider gaps and before the fill pass and the doodads, which keep their spacing from them.
@export_range(0, 4) var gap_rows: int = 0
## Each row's length along the track, as a share of a full jump at the level's speed (the levels' own rows are 0.4 to
## 0.55 of one; never more than LevelConfig.max_gap_jump_fraction).
@export_range(0.2, 0.8, 0.05) var gap_jump_share: float = 0.45

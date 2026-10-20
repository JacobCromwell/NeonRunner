extends RefCounted
## Generator rules for the `debris_maze` feature (task O2; the owner, October 20, 2026, GDD §5 Zone 8: in the Terminal
## "doodads stand so thickly that the empty space between them forms a maze, and the runner can't get through without
## dashing"). Not an enemy: a set piece of the track, placed with the rules (as the dash walls and the wall-run gaps
## are) so the level makes room for it before it fills up. DebrisMaze (scripts/world/debris_maze.gd) has the model and
## the rules of where a block goes; this script is the generator's hook:
## - apply(), after every other feature's rules that plan something on the track (RUN_AFTER) and before the danger
##   density pass, the wider gaps, the fill pass, the zone doodads and the credits: the level's blocks of debris walls
##   and dividers, and their one-lane ceilings, into LevelGenerator.debris_maze_result (the Terminal's centipede rules,
##   task O3, run after it: they come later in the level's features);
## - every pass after it keeps off each block from its run-in to exit_clear_seconds past a dash's carry out of its last
##   wall, in every lane (DebrisMaze.keep_out): doodad_keep_outs (the passes that read the rules' keep-outs: the danger
##   density pass, the wider gaps, the zone doodads, the dash walls, the wall fences' drop windows, the floor cuts) and
##   fill_keep_outs (the fill pass), so no hole, zone doodad or anything else comes into the maze or right after it;
## - positions(): each block's first wall's front (LevelGenerator.feature_positions: the every-feature check and the
##   introduction's).

const FEATURE: String = "debris_maze"
## Every feature whose rules plan something on the track: the maze takes the room they leave.
const RUN_AFTER: Array[String] = ["ramps", "ceilings", "pulsing", "speed_pads", "cyborg", "window_cyborg", "host",
	"hover_truck", "octodog", "screech", "screech_vents", "drone", "generator", "wall_fences", "wall_fences_partial",
	"buzz_overdrive", "barnacle_turret", "tithe_collector", "resonator", "gilded_sentinel", "enforcer_truck",
	"floor_cutter", "treasure_stash", "fenced_ceiling", "dash_wall", "wall_run_gaps"]


static func apply(gen: LevelGenerator) -> void:
	gen.debris_maze_result = DebrisMaze.place(gen)


## Every block of the maze in `layout`: its first wall's front (LevelGenerator.feature_positions).
static func positions(layout: LevelLayout) -> Array[float]:
	var out: Array[float] = []
	for b: Dictionary in layout.maze:
		out.append(float(b["start"]))
	return out


## What the passes after the rules keep off in every lane (LevelGenerator.rules_doodad_keep_outs): each block from its
## run-in to exit_clear_seconds past a dash's carry out of its last wall (DebrisMaze.keep_out), {from, to, type}. Not a
## calm stretch: nothing a later pass adds stands in it.
static func doodad_keep_outs(gen: LevelGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for k: Vector2 in DebrisMaze.keep_outs(gen):
		out.append({"from": k.x, "to": k.y, "type": FEATURE})
	return out


## What the fill pass keeps off (LevelGenerator.rules_fill_keep_outs): each block's keep-out (DebrisMaze.keep_out).
static func fill_keep_outs(gen: LevelGenerator) -> Array[Vector2]:
	return DebrisMaze.keep_outs(gen)

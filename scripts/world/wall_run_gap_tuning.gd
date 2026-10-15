class_name WallRunGapTuning
extends Resource
## Wall-run gaps (task J2; the owner, October 15, 2026, docs/USER_REQUESTS.md: "sections, especially in later zones
## and levels, where there is a gap over the ENTIRE floor (every lane), and the only way to cross is a wall run";
## WallRunGapPlacement): how often they come, how long they are and what they keep clear of. A level has them with
## the `wall_run_gaps` feature. Edit data/tuning/wall_run_gaps.tres (F6: "Wall-run gaps", in a level that has them;
## Restart level rebuilds). Times are seconds of run at the level's run speed, so a faster zone keeps every one of
## them (GDD §3, Pace). Every number here is a first value for playtesting (DESIGN-TBD, docs/questions/j2.md).
##
## The gap's length comes from the standard wall run (MovementTuning.wall_entry_time + wall_slide_time, no claws, no
## wall hop): the wall run from the earliest entry on the lit wall stretch (entry_window_seconds before the gap) leaves
## the wall exit_margin_seconds past the gap's far edge, so any step onto the wall within the lit stretch before the
## gap carries the runner across. Claws (longer wall runs), the dash and a wall hop only carry them further.

const PATH: String = "res://data/tuning/wall_run_gaps.tres"

@export_group("Frequency")
## DESIGN-TBD: a level gets about one wall-run gap per this many seconds of run from the feature's start to its
## end-clear stretch, at difficulty 0 and 1 (the level's difficulty halfway along that stretch,
## LevelGenerator.difficulty_at), so later zones and later levels get more: one in the level that brings them in
## (Marketplace 1, from halfway), two or three in a middle level, three or four in the Golden Zone's, as the level's
## other content leaves room. At least one in every level with the feature.
@export_range(10.0, 180.0, 0.5, "suffix:s") var spacing_seconds_easy: float = 70.0
@export_range(10.0, 180.0, 0.5, "suffix:s") var spacing_seconds_hard: float = 40.0
## DESIGN-TBD: each is due at a seeded spot of its share of the level, and goes where it fits within this many seconds
## of run either side of it (in the level that brings them in, the first from the feature's start on, as soon as one
## fits), at the spot that needs the fewest plain pieces taken out of its way, the nearest of those.
@export_range(1.0, 60.0, 0.5, "suffix:s") var search_seconds: float = 20.0
## DESIGN-TBD: the least seconds of run between one wall-run gap's landing floor and the next one's clear run-in.
@export_range(0.0, 60.0, 0.5, "suffix:s") var min_spacing_seconds: float = 15.0

@export_group("Size")
## DESIGN-TBD: the lit stretch of wall before the gap (seconds of run) where a step onto the wall carries the runner
## across with a standard wall run: the timing window (12.5 m at the Golden Zone's 25 m/s). Wider is more forgiving and
## makes the gap shorter (the gap is a standard wall run less this and exit_margin_seconds), but never shorter than a
## jump with the dash: with the shipped numbers the gap is 1.41 s of run against about 0.75 s and 4.8 m for them.
@export_range(0.2, 1.2, 0.05, "suffix:s") var entry_window_seconds: float = 0.5
## DESIGN-TBD: how far past the gap's far edge (seconds of run) the shortest standard wall run (from the lit
## stretch's first metre) still carries the runner on the wall, so they drop back onto floor, never into the gap.
@export_range(0.05, 1.0, 0.05, "suffix:s") var exit_margin_seconds: float = 0.25

@export_group("Clearance")
## DESIGN-TBD: seconds of run before the lit stretch with nothing in any lane (no hole, fence, doodad, pad, ramp,
## speed pad, ceiling, floor cut or enemy's attack; a ceiling's landing zone may reach in, clear floor itself): with
## the lit stretch, 1.3 s for the runner to get across to the wall's side (up to five lane switches on 6 lanes, 0.7 s,
## after a reaction) and step on. The gap and its lit wall show from far further back.
@export_range(0.3, 4.0, 0.05, "suffix:s") var approach_seconds: float = 0.8
## DESIGN-TBD: seconds of run after the gap with nothing in any lane: the safe landing floor. Never shorter than where
## the latest standard wall run (a step onto the wall at the gap's edge, with the jump grace) drops the runner back,
## plus LANDING_SLACK_SECONDS (WallRunGapPlacement.landing_seconds): about 1.29 s with the shipped numbers.
@export_range(0.5, 4.0, 0.05, "suffix:s") var landing_seconds: float = 1.3
## DESIGN-TBD: seconds of run kept whole and clear on the lit wall (no sign, wall enemy, wall fence or side wall gap)
## before the lit stretch and past the longest wall run a runner may take over the gap (with claws, the dash, or a
## save onto the wall).
@export_range(0.0, 3.0, 0.05, "suffix:s") var wall_clear_seconds: float = 0.5
## DESIGN-TBD: seconds of run either side of the gap the other wall keeps whole (no side wall gap): a runner on it is
## never dropped into the gap by a missing wall. Its signs, wall fences and wall enemies stay (only the lit wall is
## the way).
@export_range(0.0, 3.0, 0.05, "suffix:s") var other_wall_clear_seconds: float = 0.5


## `easy` at difficulty 0 to `hard` at 1.
static func by_difficulty(easy: float, hard: float, difficulty: float) -> float:
	return lerpf(easy, hard, clampf(difficulty, 0.0, 1.0))


## The shared numbers (data/tuning/wall_run_gaps.tres), or the defaults without the file.
static func load_default() -> WallRunGapTuning:
	var res: Resource = load(PATH) if ResourceLoader.exists(PATH) else null
	return res as WallRunGapTuning if res is WallRunGapTuning else WallRunGapTuning.new()

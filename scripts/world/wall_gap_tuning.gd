class_name WallGapTuning
extends Resource
## Where side wall gaps go (the `wall_gaps` feature, Zone 2 on; WallGapPlacement; owner's answers in
## docs/USER_REQUESTS.md: low frequency, both walls at once only rarely, never in boss levels). Edit
## data/tuning/wall_gaps.tres (F6: "Wall gaps", in a level that has them; Restart level rebuilds). Times
## are seconds at the level's run speed, so a faster zone keeps every length and margin in seconds (GDD
## §3, Pace). Numbers that go from easy to hard follow the difficulty where the gap starts
## (LevelGenerator.difficulty_at). Every number here is a first value for playtesting (DESIGN-TBD).
##
## A level may have its own (LevelConfig.wall_gap_tuning; task D10b): the Beach's levels use
## data/tuning/beach_wall_gaps.tres, whose Open walls group (coverage_target above 0) turns the rare short
## gaps into long open stretches over about half of each wall. Every other level uses the shared file, where
## that group is off.

@export_group("Frequency")
## Seconds of run from the end of one wall gap to the next (either wall), at difficulty 0 and 1. Kept
## long so gaps stay an occasional event (a 135 s level gets about four).
@export_range(5.0, 90.0, 0.5, "suffix:s") var spacing_seconds_easy: float = 32.0
@export_range(5.0, 90.0, 0.5, "suffix:s") var spacing_seconds_hard: float = 24.0
## Each spacing varies by up to this share of it, either way.
@export_range(0.0, 0.9, 0.05) var spacing_jitter: float = 0.35
## How far past a spot (seconds of run) the placement looks for a stretch of wall free of everything a
## gap keeps clear of before giving up on it.
@export_range(0.5, 20.0, 0.5, "suffix:s") var search_seconds: float = 6.0
## The share of wall gaps that open both walls over the same stretch (rare); the rest open one wall,
## either side as likely. One that can't fit on both walls opens one.
@export_range(0.0, 1.0, 0.01) var bilateral_share: float = 0.12

@export_group("Size")
## Seconds of run a wall gap lasts, drawn evenly between these. Shorter than a wall run
## (MovementTuning.wall_slide_time) so a runner can plan around one, long enough to read at speed.
@export_range(0.2, 4.0, 0.05, "suffix:s") var length_seconds_min: float = 0.6
@export_range(0.2, 4.0, 0.05, "suffix:s") var length_seconds_max: float = 1.1

@export_group("Clearance")
## Seconds of run kept between a wall gap and anything on or using its wall (a sign, a wall fence, a
## wall enemy or a Gilded Sentinel's niche, a ceiling reaching that wall), so nothing hangs off a
## missing wall.
@export_range(0.0, 3.0, 0.05, "suffix:s") var clear_seconds: float = 0.5
## Seconds of run kept clear before a ramp on the gap's wall and after the longest wall run it can
## launch (with claws and a speed pad's boost), so a ramp always launches onto solid wall.
@export_range(0.0, 3.0, 0.05, "suffix:s") var ramp_before_seconds: float = 0.6
@export_range(0.0, 3.0, 0.05, "suffix:s") var ramp_after_seconds: float = 0.4
## Seconds of run either side of a wall enemy's spot (a window cyborg's window, a wall vent) kept whole.
@export_range(0.0, 4.0, 0.05, "suffix:s") var wall_enemy_seconds: float = 1.0

@export_group("Open walls")
## Task D10b (the owner, October 9, 2026, on the Beach: "I want this zone to feel more open, so I'll have much
## longer sections where there aren't sidewalls ... have them appear about 50% of the time that they are now
## currently appearing"): above 0, the share of each side wall's length (the whole level's) its gaps aim to
## open, in long stretches instead of the rare short gaps above (WallGapPlacement, coverage mode). Each wall
## opens every stretch free of what it keeps (the Clearance group's keep-outs, which still all hold) at least
## open_seconds_min long, then stands again where it has more open than this share: first where the other wall
## is open too. A wall whose keep-outs leave less free stands more. 0 (the shared file): off, and every level is
## built exactly as before. DESIGN-TBD (docs/OPEN_QUESTIONS.md, item 526): the Beach's 0.52, its walls standing about
## half as often as the 96-97% elsewhere, and its narrower clear_seconds (0.35 s), so more of each wall can open.
@export_range(0.0, 0.9, 0.01) var coverage_target: float = 0.0
## Seconds of run: the shortest open stretch (a free stretch of wall shorter than this keeps its wall, so the
## walls never flicker), and the least a wall stands again where it closes part of an open stretch.
## DESIGN-TBD (docs/OPEN_QUESTIONS.md, item 528): the Beach's 2 s each.
@export_range(0.5, 10.0, 0.1, "suffix:s") var open_seconds_min: float = 2.0
@export_range(0.5, 10.0, 0.1, "suffix:s") var solid_seconds_min: float = 2.0
## The most of the level's length that may be open on both walls at once (no wall on either side: the widest
## view of the surroundings, and nothing to run along). Where there's more, the wall with more open stands
## again there. 1: no limit. DESIGN-TBD (docs/OPEN_QUESTIONS.md, item 527): the Beach's 0.3.
@export_range(0.0, 1.0, 0.01) var both_open_max: float = 1.0


## `easy` at difficulty 0 to `hard` at 1.
static func by_difficulty(easy: float, hard: float, difficulty: float) -> float:
	return lerpf(easy, hard, clampf(difficulty, 0.0, 1.0))


## True if the gaps are long open stretches over a share of each wall (coverage_target above 0, the Beach's)
## rather than the rare short ones.
func opens_walls() -> bool:
	return coverage_target > 0.0

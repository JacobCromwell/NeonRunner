class_name WallGapTuning
extends Resource
## Where side wall gaps go (the `wall_gaps` feature, Zone 2 on; WallGapPlacement; owner's answers in
## docs/USER_REQUESTS.md: low frequency, both walls at once only rarely, never in boss levels). Edit
## data/tuning/wall_gaps.tres (F6: "Wall gaps", in a level that has them; Restart level rebuilds). A
## boss arena that opts in has a resource of its own (LevelConfig.wall_gap_tuning: the Sleep Taker's,
## data/bosses/dead_zone_boss_wall_gaps.tres, with many gaps; owner, October 8, 2026). Times
## are seconds at the level's run speed, so a faster zone keeps every length and margin in seconds (GDD
## §3, Pace). Numbers that go from easy to hard follow the difficulty where the gap starts
## (LevelGenerator.difficulty_at). Every number here is a first value for playtesting (DESIGN-TBD).

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


## `easy` at difficulty 0 to `hard` at 1.
static func by_difficulty(easy: float, hard: float, difficulty: float) -> float:
	return lerpf(easy, hard, clampf(difficulty, 0.0, 1.0))

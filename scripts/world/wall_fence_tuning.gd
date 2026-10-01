class_name WallFenceTuning
extends Resource
## Where wall fences go and how they pulse (task B5; GDD §9.1). Edit data/tuning/wall_fences.tres (F6:
## "Wall fences", in a level that has them). The generator places them (WallFencePlacement) from these;
## their sizes are MovementTuning's (Piece sizes), and their warning is a floor fence's
## (MovementTuning.fence_pulse_warning: the same flicker and crackle). Times are seconds at the level's
## run speed, so a faster zone keeps every margin in seconds (GDD §3, Pace). Numbers that go from easy
## to hard follow the difficulty where the wall fence stands (LevelGenerator.difficulty_at), which rises
## along a level and over the campaign (Marketplace 2 is at about 0.5 to 0.75, the Golden Zone near 1).
## Everything here is DESIGN-TBD (docs/questions/b5.md): the GDD fixes what they are and the fairness
## rules, not how many or how fast.

@export_group("Placement")
## Seconds of run from one wall fence to the next (either wall), at difficulty 0 and 1. Each next spot
## is drawn around this (spacing_jitter); the fairness rules then take the first fair spot from there,
## so a level gets fewer where its walls and outer lanes are busy.
@export_range(2.0, 30.0, 0.5, "suffix:s") var spacing_seconds_easy: float = 10.0
@export_range(2.0, 30.0, 0.5, "suffix:s") var spacing_seconds_hard: float = 5.0
## Each spacing varies by up to this share of it, either way.
@export_range(0.0, 0.9, 0.05) var spacing_jitter: float = 0.3
## How far past a spot (seconds of run) the placement looks for a fair one before giving up on it.
@export_range(0.5, 10.0, 0.5, "suffix:s") var search_seconds: float = 4.0
## In a level with partial wall fences (the `wall_fences_partial` feature, from the Corporate zone), the
## share of its wall fences past that feature's start that cover only the low or the high part of the
## wall (each as likely); the rest stay full-height (GDD §5: an introduced feature keeps appearing).
@export_range(0.0, 1.0, 0.05) var partial_share: float = 0.5
## A level that gives the feature a start (LevelConfig.feature_starts: Marketplace 2's full-height ones,
## Corporate 1's partial ones) meets its first one within this long after the start where a fair spot
## comes in time (a big attack can hold it back): alone, where no enemy is about if such a spot comes in
## time, with a long off time (intro_off_seconds), and its first-encounter hint just before it.
@export_range(1.0, 30.0, 0.5, "suffix:s") var intro_seconds: float = 10.0

@export_group("Pulse")
## Seconds on and off at difficulty 0 and 1, each varied by up to pulse_jitter_seconds either way. The
## last MovementTuning.fence_pulse_warning seconds of the off time are the warning.
@export_range(0.3, 4.0, 0.05, "suffix:s") var on_seconds_easy: float = 1.0
@export_range(0.3, 4.0, 0.05, "suffix:s") var on_seconds_hard: float = 1.3
@export_range(0.5, 4.0, 0.05, "suffix:s") var off_seconds_easy: float = 1.6
@export_range(0.5, 4.0, 0.05, "suffix:s") var off_seconds_hard: float = 1.1
@export_range(0.0, 0.5, 0.05, "suffix:s") var pulse_jitter_seconds: float = 0.1
## The introduction's off time, at least: the first one a level brings in gives a long, easy window.
@export_range(0.5, 6.0, 0.05, "suffix:s") var intro_off_seconds: float = 2.0

@export_group("Fairness")
## The outer floor lane beside a wall fence stays clear (no hole, fence, floor cut, anti-grav pad or
## floor enemy) from this long before it to drop_after_seconds after it, so a wall runner who sees it
## on (or its warning) can always drop off the wall there: a wall jump lands in that lane about 0.5 to
## 0.7 s later, so one from as late as the warning (the floor fence's, MovementTuning.fence_pulse_warning)
## lands within this stretch. Nothing that runs meanwhile (a floor cut, a big attack) may reach it
## either.
@export_range(0.0, 3.0, 0.05, "suffix:s") var drop_before_seconds: float = 0.6
@export_range(0.0, 3.0, 0.05, "suffix:s") var drop_after_seconds: float = 0.8
## GDD §9.1: never on the same wall section as a sign or a window cyborg. Seconds of wall kept clear of
## signs and window cyborgs either side of a wall fence on its wall (each of them asks the wall runner
## something of its own: one thing at a time).
@export_range(0.0, 3.0, 0.05, "suffix:s") var wall_clear_seconds: float = 1.0
## A wall vent's screech (GDD §9.5) swipes up its wall: no wall fence on that wall from this long before
## the vent to vent_after_seconds after it.
@export_range(0.0, 4.0, 0.05, "suffix:s") var vent_before_seconds: float = 2.0
@export_range(0.0, 3.0, 0.05, "suffix:s") var vent_after_seconds: float = 0.6
## GDD §9.1: never where a ramp launches the player into one. No wall fence on a ramp's wall from this
## long before the ramp to this long after the end of the longest wall run it can launch (RampLaunch,
## with its fading boost, claws' longer wall runs and a speed pad's boost carried onto it).
@export_range(0.0, 3.0, 0.05, "suffix:s") var ramp_before_seconds: float = 0.3
@export_range(0.0, 3.0, 0.05, "suffix:s") var ramp_after_seconds: float = 0.5
## Two wall fences on the same wall at least this far apart (a wall run is about 2 s: one meets one at
## a time), and any two at least gap_seconds apart.
@export_range(0.0, 6.0, 0.05, "suffix:s") var same_side_gap_seconds: float = 2.5
@export_range(0.0, 4.0, 0.05, "suffix:s") var gap_seconds: float = 1.0


## A number at difficulty `difficulty` (0–1) between its easy and hard values.
static func by_difficulty(easy: float, hard: float, difficulty: float) -> float:
	return lerpf(easy, hard, clampf(difficulty, 0.0, 1.0))

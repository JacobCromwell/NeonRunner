class_name StandInThiefTuning
extends ThiefTuning
## The stand-in thief's own numbers (StandInThief, task B6: a review and test aid, not design; the Tithe
## Collector, task C5, brings its own): where it appears, how it crosses the lanes and closes in, and how
## it makes off after a theft. Edit data/enemies/stand_in_thief.tres (F6 in quick play with --thief).

@export_group("Stand-in")
## How far ahead of the runner it appears.
@export_range(5.0, 120.0, 1.0, "suffix:m") var start_ahead: float = 32.0
## How fast the runner closes in on it (it runs this much slower than the runner).
@export_range(0.5, 20.0, 0.5, "suffix:m/s") var approach_speed: float = 6.0
## How fast it crosses the lanes, side to side between the outer lanes' middles.
@export_range(0.0, 20.0, 0.25, "suffix:m/s") var cross_speed: float = 3.5
## The gold block's size, and the height of its underside above the floor (a runner, sliding or not,
## touches it; a jump clears it).
@export var block_size: Vector3 = Vector3(1.0, 0.8, 1.0)
@export_range(0.0, 3.0, 0.05, "suffix:m") var hover: float = 0.2
## After a theft it makes off with what it took: how fast it pulls ahead of the runner and rises, how
## high it climbs (out of reach), and how far ahead it's gone for good.
@export_range(1.0, 40.0, 0.5, "suffix:m/s") var flee_speed: float = 16.0
@export_range(0.0, 10.0, 0.25, "suffix:m/s") var flee_rise: float = 3.0
@export_range(0.0, 10.0, 0.25, "suffix:m") var flee_height: float = 4.5
@export_range(10.0, 200.0, 5.0, "suffix:m") var gone_ahead: float = 70.0
## Quick play's --thief: seconds from one stand-in gone (caught, or away) to the next.
@export_range(0.0, 10.0, 0.25, "suffix:s") var review_interval: float = 1.5

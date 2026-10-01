class_name FloorCutterTuning
extends EnemyTuning
## The floor cutter's numbers (data/enemies/floor_cutter.tres; F6 "Enemy: Floor Cutter" in a quick play
## with it): the plain stand-in that runs floor cuts for review until task C2's Buzz Overdrive exists
## (task B4; GDD §9.9 has the real one's). Every number here is a placeholder for review (DESIGN-TBD),
## never the Buzz Overdrive's: C2 brings its rev time, speed and the rest.
## Seconds are at the level's run speed and its charge speed at MovementTuning.REFERENCE_SPEED,
## stretched by the level's pace, so a cut keeps its timing in every zone (GDD §3); its sizes and
## run_past (where it's off the screen behind the player) are plain metres.
## It never "uses the floor" as the generator counts floor enemies (uses_floor false): its floor is its
## cut's (LevelLayout.cuts), which the generator keeps everything off already.

@export_group("Cut")
## Seconds of warning (the red line over its lane and the rev) before it charges.
@export_range(0.5, 5.0, 0.1, "suffix:s") var warn_seconds: float = 2.0
## Seconds from the start of its charge until it reaches the player.
@export_range(0.5, 4.0, 0.05, "suffix:s") var charge_seconds: float = 1.3
## How fast it charges back toward the player, m/s at the reference speed.
@export_range(5.0, 40.0, 0.5, "suffix:m/s") var charge_speed: float = 18.0
## How far past the player it runs, cutting, before it's gone (off the screen behind them).
@export_range(5.0, 60.0, 1.0, "suffix:m") var run_past: float = 22.0

@export_group("Placement")
## Seconds into the feature's stretch before the first warning.
@export_range(0.0, 60.0, 0.5, "suffix:s") var first_seconds: float = 3.0
## Seconds of running between the end of one cut and the next one's warning.
@export_range(1.0, 60.0, 0.5, "suffix:s") var gap_seconds: float = 5.0
## Where no lane fits a cut, the next spot tried this many seconds further on.
@export_range(0.25, 10.0, 0.25, "suffix:s") var retry_seconds: float = 1.0

@export_group("Body")
## The grey box: width, height and length behind its blade (it waits with its blade at its cut's end).
@export var body_size: Vector3 = Vector3(0.9, 2.3, 6.0)
## The blade: a vertical disc along the lane, its lowest point at the cut's front.
@export_range(0.5, 2.5, 0.05, "suffix:m") var blade_radius: float = 1.3
## Its hitbox (an enemy attack: the armor and the shield block it), centred on its lane and narrow, so
## it stays inside its own lane: a wall runner beside it is never touched (GDD §3, §9.9).
@export var hitbox_size: Vector3 = Vector3(0.7, 2.2, 2.6)
## Sparks from the blade while it cuts, a burst every this many seconds (none with Reduced flashing).
@export_range(0.02, 1.0, 0.01, "suffix:s") var spark_every: float = 0.08


## Metres past its cut's end its lane keeps clear for it: its body waits there.
func keep() -> float:
	return body_size.z + 1.0

class_name OctodogTuning
extends EnemyTuning
## Numbers for the Octodog (GDD §9.4), edited in data/enemies/octodog.tres. Pairs named _early and
## _late scale with the level's enemy_scaling (0 = first campaign level, 1 = last). The helper
## functions turn them into distances at a given run speed; the enemy and its generator rules
## (octodog_rules.gd) both use them, so a charge is planned with the same numbers it's played with.
## Values marked DESIGN-TBD are placeholders, not design decisions.

@export_group("Charges")
## GDD §9.4: 2–3 charges early, up to 4 at the maximum; then it gives up. A dog makes a random
## number of charges between the scaled min and max.
@export_range(1, 6) var charges_min_early: int = 2
@export_range(1, 6) var charges_max_early: int = 3
@export_range(1, 6) var charges_min_late: int = 3
@export_range(1, 6) var charges_max_late: int = 4

@export_group("Wind-up & lunge")
## DESIGN-TBD: seconds of wind-up (crouch, tentacles flare, growl) before each lunge. The aim is
## locked when the wind-up starts, so a lane switch any time after that dodges the lunge.
@export_range(0.3, 2.0, 0.05, "suffix:s") var windup_time_early: float = 0.95
@export_range(0.3, 2.0, 0.05, "suffix:s") var windup_time_late: float = 0.8
## DESIGN-TBD: distance ahead of the player at which the lunge starts. The wind-up starts further
## out (this plus the wind-up time at run speed), about halfway up the screen.
@export_range(6.0, 40.0, 0.5, "suffix:m") var lunge_start_distance: float = 15.0
## DESIGN-TBD: ground speed of the lunge toward the player (closing speed = this + run speed).
@export_range(0.0, 30.0, 0.5, "suffix:m/s") var lunge_speed_early: float = 9.0
@export_range(0.0, 30.0, 0.5, "suffix:m/s") var lunge_speed_late: float = 11.0
## The lunge carries on in its straight line until it's this far behind the player.
@export_range(0.5, 10.0, 0.5, "suffix:m") var lunge_overshoot: float = 3.0
## DESIGN-TBD: how many lanes one lunge may cut across diagonally.
@export_range(0, 5) var max_lanes_across: int = 1
## DESIGN-TBD: chance that a charge comes from a lane beside the player's (a diagonal lunge)
## rather than head-on.
@export_range(0.0, 1.0, 0.05) var diagonal_chance: float = 0.4
## Height of the leap's arc (visual only: the hitbox stays low enough to jump over).
@export_range(0.0, 1.0, 0.05, "suffix:m") var lunge_hop_height: float = 0.3

@export_group("Running ahead")
## How much faster than the player it runs back into position after a lunge.
@export_range(4.0, 40.0, 0.5, "suffix:m/s") var sprint_speed_over_player: float = 20.0
## Seconds it skids and turns around after a lunge.
@export_range(0.0, 1.0, 0.05, "suffix:s") var turnaround_time: float = 0.3
## Sideways speed when changing lanes.
@export_range(1.0, 30.0, 0.5, "suffix:m/s") var lateral_speed: float = 9.0
## DESIGN-TBD: it runs past the player in another lane and can't hurt them until it's this far
## ahead (never from behind or beside, where the player can't see it coming).
@export_range(0.0, 10.0, 0.5, "suffix:m") var pass_clearance: float = 3.0
## Seconds of clear floor needed after a lunge would meet the player (a jump's landing), used by the
## generator and before every wind-up.
@export_range(0.0, 2.0, 0.05, "suffix:s") var clear_after_seconds: float = 0.5
## A planned charge that can't start within this many metres after its planned point is dropped,
## and the dog gives up.
@export_range(0.0, 100.0, 5.0, "suffix:m") var charge_slack: float = 40.0
## DESIGN-TBD: distance at which a dog hiding in its doghouse bursts out; beyond it no dog can be
## targeted by auto-fire, doghouse or not (so the hint never changes gameplay).
@export_range(20.0, 120.0, 5.0, "suffix:m") var appear_distance: float = 55.0

@export_group("Gap bait")
## DESIGN-TBD: level score for baiting it into a gap (GDD §9.4 skill bonus), on top of its kill score.
@export_range(0, 5000, 10) var gap_bait_bonus: int = 300
## The generator puts a bait dog (pattern param "bait": true) this far past the gap in its lane, so
## a head-on lunge falls in and a diagonal one clears it.
@export_range(1.0, 8.0, 0.25, "suffix:m") var bait_distance: float = 3.0

@export_group("Doghouse")
## DESIGN-TBD (GDD §9.4: a doghouse warns of the first appearances only): this many Octodogs, counted
## over the player's whole profile, come with a doghouse.
@export_range(0, 10) var doghouse_appearances: int = 3


func windup_time(t: float) -> float:
	return scaled(windup_time_early, windup_time_late, t)


func lunge_speed(t: float) -> float:
	return scaled(lunge_speed_early, lunge_speed_late, t)


## Fewest and most charges at scaling `t`.
func charges_range(t: float) -> Vector2i:
	var lo: int = roundi(scaled(charges_min_early, charges_min_late, t))
	var hi: int = roundi(scaled(charges_max_early, charges_max_late, t))
	return Vector2i(lo, maxi(lo, hi))


## How far ahead of the player the dog stands when its wind-up starts.
func stop_distance(speed: float, t: float) -> float:
	return lunge_start_distance + windup_time(t) * speed


## Seconds from the lunge's start until it reaches the player.
func time_to_meet(speed: float, t: float) -> float:
	return lunge_start_distance / maxf(speed + lunge_speed(t), 1.0)


## Metres the player runs from a wind-up's start until the lunge has passed them and they could
## have landed a jump: the stretch that must be free of other obstacles.
func window_length(speed: float, t: float) -> float:
	return (windup_time(t) + time_to_meet(speed, t) + clear_after_seconds) * speed


## Seconds a lunge lasts, from its start until it's lunge_overshoot behind the player.
func lunge_duration(speed: float, t: float) -> float:
	return (lunge_start_distance + lunge_overshoot) / maxf(speed + lunge_speed(t), 1.0)


## Metres the player runs from one wind-up's start to the earliest possible next one.
func cycle_distance(speed: float, t: float) -> float:
	var sprint: float = (stop_distance(speed, t) + lunge_overshoot) / sprint_speed_over_player
	return (windup_time(t) + lunge_duration(speed, t) + turnaround_time + sprint + 0.2) * speed

class_name OctodogTuning
extends EnemyTuning
## Numbers for the Octodog (GDD §9.4), edited in data/enemies/octodog.tres. Pairs named _early and
## _late scale with the level's enemy_scaling (0 = first campaign level, 1 = last). The helper
## functions turn them into distances at a given run speed; the enemy and its generator rules
## (octodog_rules.gd) both use them, so a charge is planned with the same numbers it's played with.
## Distances along the track and speeds are given at MovementTuning.REFERENCE_SPEED: the helpers take
## the level's pace (MovementTuning.pace) and stretch them by it, so in a faster zone the dog lunges and
## sprints faster to match the runner and every wind-up, lunge and dodge keeps its seconds (GDD §3,
## owner's playtest September 30, 2026: enemies speed up to match, never with shorter warnings).
## Values marked DESIGN-TBD are placeholders, not design decisions.

@export_group("Charges")
## GDD §9.4: 2–3 charges early, up to 4 at the maximum; then it gives up. A dog makes a random
## number of charges between the scaled min and max, each rounded to whole charges (charges_range).
## Not whole numbers themselves, so the step from the early counts to the late ones can fall between
## two levels: the late 3.25 and 4.25 (still 3 and 4 at the campaign's end) put it between Marketplace
## 1 and 2, where it was before the Casino's levels re-spaced the campaign's enemy scaling (task K2).
@export_range(1.0, 6.0, 0.05) var charges_min_early: float = 2.0
@export_range(1.0, 6.0, 0.05) var charges_max_early: float = 3.0
@export_range(1.0, 6.0, 0.05) var charges_min_late: float = 3.25
@export_range(1.0, 6.0, 0.05) var charges_max_late: float = 4.25

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
## How many lanes one lunge may cut across diagonally (FB 76).
@export_range(0, 5) var max_lanes_across: int = 1
## Chance that a charge comes from a lane beside the player's (a diagonal lunge)
## rather than head-on (FB 76: 40%).
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
## It runs past the player in another lane and can't hurt them until it's this far
## ahead (never from behind or beside, where the player can't see it coming; FB 77).
@export_range(0.0, 10.0, 0.5, "suffix:m") var pass_clearance: float = 3.0
## Seconds of clear floor needed after a lunge would meet the player (a jump's landing), used by the
## generator and before every wind-up.
@export_range(0.0, 2.0, 0.05, "suffix:s") var clear_after_seconds: float = 0.5
## A planned charge that can't start within this many metres after its planned point is dropped,
## and the dog gives up.
@export_range(0.0, 100.0, 5.0, "suffix:m") var charge_slack: float = 40.0
## DESIGN-TBD: while big attacks take turns (GDD §9, GameRules.big_attacks_take_turns), a dog whose
## first wind-up waits for another type's big attack keeps pacing in position, and its whole sequence
## of planned charges moves on with the player, while it waits and then, if the wait made it miss its
## planned stretch, until the stretch ahead is clear again: for up to this long in all, before
## charge_slack starts to run out. A charge moved on this way still needs a clear stretch, with the
## generator's margins.
@export_range(0.0, 10.0, 0.25, "suffix:s") var turn_wait_max: float = 4.0
## Distance at which a dog hiding in its doghouse bursts out (FB 79: 55 m); beyond it no dog can be
## targeted by auto-fire, doghouse or not (so the hint never changes gameplay).
@export_range(20.0, 120.0, 5.0, "suffix:m") var appear_distance: float = 55.0

@export_group("Gap bait")
## DESIGN-TBD: level score for baiting it into a gap (GDD §9.4 skill bonus), on top of its kill score.
@export_range(0, 5000, 10) var gap_bait_bonus: int = 300
## The generator puts a bait dog (pattern param "bait": true) this far past the gap in its lane, so
## a head-on lunge falls in and a diagonal one clears it.
@export_range(1.0, 8.0, 0.25, "suffix:m") var bait_distance: float = 3.0

@export_group("Doghouse")
## GDD §9.4: a doghouse warns of the first appearances only: this many Octodogs, counted
## over the player's whole profile, come with a doghouse (FB 79: 3).
@export_range(0, 10) var doghouse_appearances: int = 3

@export_group("Jars")
## Task Q5 (GDD §5, Zone 9, the owner, October 21, 2026: "sometimes smashing an Octodog jar doodad releases its Octodog
## into the world"; proposed: "the freed Octodog tumbles out, runs ahead to its usual distance and starts its usual
## attack from the first wind-up, with its cue"). DESIGN-TBD (docs/questions/q5.md 4, 5 and 14): every number here.
## Seconds the freed dog tumbles out of its smashed jar, flung on ahead of the runner and rolling over once, harmless
## (no hitbox: nothing it does before its first wind-up can hurt), before it lands running (its sprint, as after a lunge).
@export_range(0.1, 1.5, 0.05, "suffix:s") var jar_tumble_time: float = 0.45
## How much faster than the runner it's flung on while it tumbles (at the reference speed, stretched by the pace).
@export_range(0.0, 20.0, 0.5, "suffix:m/s") var jar_tumble_speed: float = 7.0
## The height of its tumble's arc (visual only).
@export_range(0.0, 2.0, 0.05, "suffix:m") var jar_tumble_height: float = 0.7
## The generator's margin, in seconds of run, for the freed dog to get into position after its sprint (crossing a lane
## to line up, settling at its distance) on top of the tumble and the sprint (release_distance): its first wind-up is
## planned that far on, and a dog in position sooner paces there until the runner reaches it.
@export_range(0.0, 3.0, 0.05, "suffix:s") var jar_settle_seconds: float = 0.5
## Seconds of run past the feature's start within which the level that introduces the jars (Frost Foundry, the one that
## gives `octodog_jar` a start) stands its first one, where it has room there (octodog_jar_rules.gd): test_campaign's
## introduction reach, as the gantryways' and the teleporters' intro_window_seconds.
@export_range(2.0, 40.0, 0.5, "suffix:s") var jar_intro_window_seconds: float = 11.5


func windup_time(t: float) -> float:
	return scaled(windup_time_early, windup_time_late, t)


func lunge_speed(t: float) -> float:
	return scaled(lunge_speed_early, lunge_speed_late, t)


## The lunge's ground speed at scaling `t` in a level at `pace` (MovementTuning.pace).
func lunge_speed_at(t: float, pace: float = 1.0) -> float:
	return lunge_speed(t) * pace


## Fewest and most charges at scaling `t`.
func charges_range(t: float) -> Vector2i:
	var lo: int = roundi(scaled(charges_min_early, charges_min_late, t))
	var hi: int = roundi(scaled(charges_max_early, charges_max_late, t))
	return Vector2i(lo, maxi(lo, hi))


## How far ahead of the player the dog stands when its wind-up starts, for a player at `speed` in a
## level at `pace` (MovementTuning.pace; 1 at the reference speed).
func stop_distance(speed: float, t: float, pace: float = 1.0) -> float:
	return lunge_start_distance * pace + windup_time(t) * speed


## Seconds from the lunge's start until it reaches the player. At the level's own run speed it's the
## same at any pace: the lunge starts further out and comes faster.
func time_to_meet(speed: float, t: float, pace: float = 1.0) -> float:
	return lunge_start_distance * pace / maxf(speed + lunge_speed(t) * pace, 1.0)


## Metres the player runs from a wind-up's start until the lunge has passed them and they could
## have landed a jump: the stretch that must be free of other obstacles.
func window_length(speed: float, t: float, pace: float = 1.0) -> float:
	return (windup_time(t) + time_to_meet(speed, t, pace) + clear_after_seconds) * speed


## Seconds a lunge lasts, from its start until it's lunge_overshoot behind the player.
func lunge_duration(speed: float, t: float, pace: float = 1.0) -> float:
	return (lunge_start_distance + lunge_overshoot) * pace / maxf(speed + lunge_speed(t) * pace, 1.0)


## Metres the runner runs from smashing a jar (task Q5) until the dog it held is in position for its first wind-up, at
## `speed` in a level at `pace`, plus `dash_metres` (how much further the dash that smashed it carries them meanwhile,
## at most): its tumble, its sprint to its usual distance ahead (stop_distance, less what the tumble gained on the
## runner) and jar_settle_seconds. Its first wind-up is planned there (octodog_jar_rules.gd).
func release_distance(speed: float, t: float, pace: float = 1.0, dash_metres: float = 0.0) -> float:
	var gained: float = jar_tumble_time * jar_tumble_speed * pace
	var sprint: float = maxf(stop_distance(speed, t, pace) - gained, 0.0) / maxf(sprint_speed_over_player * pace, 0.1)
	return (jar_tumble_time + sprint + jar_settle_seconds) * speed + dash_metres


## Metres the player runs from one wind-up's start to the earliest possible next one.
func cycle_distance(speed: float, t: float, pace: float = 1.0) -> float:
	var sprint: float = (stop_distance(speed, t, pace) + lunge_overshoot * pace) / (sprint_speed_over_player * pace)
	return (windup_time(t) + lunge_duration(speed, t, pace) + turnaround_time + sprint + 0.2) * speed

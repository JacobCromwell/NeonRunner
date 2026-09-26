class_name ScreechTuning
extends EnemyTuning
## Numbers for the Sewer Screech (GDD §9.5), edited in data/enemies/screech.tres. Pairs named _early
## and _late scale with the level's enemy_scaling. Every behaviour number lives here, so the swarm
## boss (GDD §10), built from the same creature, can reuse or tune them. Values marked DESIGN-TBD are
## placeholders, not design decisions.

@export_group("Trigger")
## DESIGN-TBD: it decides to come out while the player is at most this many seconds away (at their
## speed), and only if the player is in its lane at that moment (GDD §9.5); otherwise it stays hidden.
@export_range(0.5, 4.0, 0.05, "suffix:s") var trigger_seconds: float = 1.6
## Closer than this many seconds it stays hidden for good: too late for a fair warning.
@export_range(0.3, 3.0, 0.05, "suffix:s") var min_warning_seconds: float = 1.15

@export_group("Warning")
## GDD §9.5: its cover or vent shakes (with a sound), then bursts open. DESIGN-TBD: how long.
@export_range(0.2, 2.0, 0.05, "suffix:s") var shake_time_early: float = 0.6
@export_range(0.2, 2.0, 0.05, "suffix:s") var shake_time_late: float = 0.5
## Seconds to leap out after the burst; it can't hurt anyone until it's out.
@export_range(0.05, 1.0, 0.01, "suffix:s") var emerge_time: float = 0.22

@export_group("Attack")
## GDD §9.5: a short dash straight along its lane toward the player, then one swipe.
@export_range(0.0, 20.0, 0.5, "suffix:m/s") var dash_speed_early: float = 6.0
@export_range(0.0, 20.0, 0.5, "suffix:m/s") var dash_speed_late: float = 8.0
@export_range(0.0, 10.0, 0.25, "suffix:m") var dash_max_distance: float = 4.0
## The swipe: the claw goes up (with the swipe sound), strikes (the attack hitbox is live), recovers.
@export_range(0.05, 0.6, 0.01, "suffix:s") var swipe_windup: float = 0.14
@export_range(0.05, 0.6, 0.01, "suffix:s") var swipe_active: float = 0.16
@export_range(0.05, 1.0, 0.01, "suffix:s") var swipe_recover: float = 0.3
## How far in front of its body the claw reaches, and how high above the floor.
@export_range(0.3, 3.0, 0.05, "suffix:m") var swipe_reach: float = 1.3
@export_range(0.3, 2.5, 0.05, "suffix:m") var swipe_height: float = 1.0
## DESIGN-TBD: from a wall vent, how high up the wall the claw reaches (GDD §3: vents punish
## lingering low on a wall).
@export_range(0.5, 3.0, 0.05, "suffix:m") var vent_swipe_height: float = 1.6
## Seconds a wall-vent screech takes to drop from the vent to the floor after its swipe.
@export_range(0.05, 1.0, 0.01, "suffix:s") var vent_drop_time: float = 0.3


func shake_time(t: float) -> float:
	return scaled(shake_time_early, shake_time_late, t)


func dash_speed(t: float) -> float:
	return scaled(dash_speed_early, dash_speed_late, t)


## How far ahead of the player (m) the swipe starts at `speed`, so the claw strikes just as the
## player comes within its reach.
func swipe_start_distance(speed: float, body_half_length: float) -> float:
	return speed * swipe_windup + body_half_length + swipe_reach * 0.8

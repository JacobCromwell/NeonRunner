class_name BadDreamTuning
extends EnemyTuning
## Numbers for the Cyborg's Bad Dream (GDD §9.7), in data/enemies/bad_dream.tres. The GDD fixes the
## three-lane slash, a slash every ~3–4 s and a 20–30 s chase; the owner's placeholder review approved
## the escape rules, the pad schedule and the survival bonus as is (FB 99, FB 100, FB 104, FB 105).
## Values still marked DESIGN-TBD are placeholders until playtested (FB 96–98). Pairs named
## _early/_late scale with the level's enemy_scaling (GDD §6). The enemy (bad_dream.gd) and the host
## rules (host_rules.gd) both read them, so a chase is planned with the same numbers it's played with.

@export_group("Chase")
## GDD §9.7: it slashes for 20–30 s, then dissolves. Each Bad Dream rolls its chase length in this
## range from its seed (every attempt at a seed plays the same); the generator plans for the longest.
@export_range(5.0, 60.0, 0.5, "suffix:s") var chase_min_seconds: float = 20.0
@export_range(5.0, 60.0, 0.5, "suffix:s") var chase_max_seconds: float = 30.0
## GDD §9.7: a slash every ~3–4 s, from one telegraph's start to the next (rolled for each slash).
@export_range(1.0, 10.0, 0.1, "suffix:s") var slash_interval_min: float = 3.0
@export_range(1.0, 10.0, 0.1, "suffix:s") var slash_interval_max: float = 4.0
## Level score for surviving the whole chase (GDD §9.7 only says "a score bonus"; FB 104: 1,000).
@export_range(0, 20000, 50) var survival_bonus: int = 1000

@export_group("Emerging and dissolving")
## Rising out of the killed host (harmless meanwhile).
@export_range(0.2, 3.0, 0.05, "suffix:s") var emerge_time: float = 1.0
## Seconds after it has emerged before its first telegraph may start.
@export_range(0.0, 5.0, 0.1, "suffix:s") var first_slash_delay: float = 0.8
@export_range(0.2, 4.0, 0.05, "suffix:s") var dissolve_time: float = 1.4
## A fence generator's EMP dissolves it faster.
@export_range(0.1, 4.0, 0.05, "suffix:s") var emp_dissolve_time: float = 0.7

@export_group("Floating")
## Size of the model (1 = about 3.35 m from the tail's tip to the top of the head). Its body's
## damage box scales with it.
@export_range(0.5, 2.0, 0.05) var model_scale: float = 1.3
## DESIGN-TBD: it floats this far ahead of the player, facing them and keeping pace (inside the
## camera's view), with the tip of its tail this high. Its head stays hull_clearance under a ceiling.
@export_range(3.0, 20.0, 0.5, "suffix:m") var hover_ahead: float = 7.5
@export_range(0.0, 2.5, 0.05, "suffix:m") var hover_height: float = 0.35
## How fast it closes in on (or backs off to) that distance outside a lunge.
@export_range(2.0, 40.0, 0.5, "suffix:m/s") var approach_speed: float = 14.0
## GDD §9.7: it drifts toward the player's lane at a limited sideways speed ...
@export_range(0.5, 20.0, 0.25, "suffix:m/s") var drift_speed: float = 5.0
## ... and follows onto a wall slowly.
@export_range(0.1, 10.0, 0.1, "suffix:m/s") var wall_follow_speed: float = 1.5
## Over a wall it floats this far inside the wall face.
@export_range(0.3, 3.0, 0.05, "suffix:m") var wall_inset: float = 1.0
## GDD §9.7: it can't reach a ship's hull. While the player rides a ceiling it waits below, this far
## ahead (DESIGN-TBD), reaching up but never closer to the hull than hull_clearance.
@export_range(3.0, 20.0, 0.5, "suffix:m") var wait_ahead: float = 7.0
@export_range(0.5, 3.0, 0.1, "suffix:m") var hull_clearance: float = 1.2

@export_group("Slash")
## DESIGN-TBD: the telegraph (the covered lanes lit up in enemy-attack red, the maw opening, the
## shriek) before the lunge. The lanes are locked when it starts, so leaving them any time during it
## dodges the slash.
@export_range(0.5, 3.0, 0.05, "suffix:s") var telegraph_early: float = 1.2
@export_range(0.5, 3.0, 0.05, "suffix:s") var telegraph_late: float = 1.0
## The lunge from its floating spot to lunge_ahead in front of the player; then the claws are live
## for slash_active, and it floats back over recover_time.
@export_range(0.05, 1.0, 0.01, "suffix:s") var lunge_time: float = 0.22
@export_range(0.03, 0.5, 0.01, "suffix:s") var slash_active: float = 0.12
@export_range(0.1, 2.0, 0.05, "suffix:s") var recover_time: float = 0.7
@export_range(0.5, 5.0, 0.1, "suffix:m") var lunge_ahead: float = 1.8
## It lines up with the player's lane before a telegraph, but waits no longer than this
## for a player who keeps moving (then telegraphs from where it is: the lanes are still the
## player's; FB 100).
@export_range(0.0, 5.0, 0.1, "suffix:s") var max_align_wait: float = 1.2
@export_range(0.05, 2.0, 0.05, "suffix:m") var align_tolerance: float = 0.5
## The slash's damage box (GDD §3: slightly smaller than what the player sees): the covered lanes
## less side_margin at an edge next to a free lane, and less wall_clearance at an edge by a wall (a
## wall runner's body sticks out about 0.8 m from the wall, and the wall is an escape); from the
## floor up to slash_height, above the top of a jump, so only leaving the lanes dodges it (the GDD
## doesn't say whether a jump or a slide should; FB 99).
@export_range(0.5, 3.0, 0.05, "suffix:m") var slash_height: float = 1.75
@export_range(0.0, 1.0, 0.05, "suffix:m") var side_margin: float = 0.15
@export_range(0.0, 1.5, 0.05, "suffix:m") var wall_clearance: float = 0.9
@export_range(0.5, 4.0, 0.1, "suffix:m") var slash_depth: float = 1.6
## A slash at a player on a wall covers the wall (up to this height) and the outer lane (FB 99).
@export_range(1.0, 6.0, 0.1, "suffix:m") var wall_slash_top: float = 4.8

@export_group("Generator rules")
## GDD §9.7: anti-grav pads are guaranteed during the chase: from the host's spot until
## the longest chase could end, never more than this many seconds without a pad (FB 105). Pads already
## there count (a drone's pad schedule keeps its pads 8–10 s apart, so it covers a chase).
@export_range(3.0, 30.0, 0.5, "suffix:s") var pad_gap_seconds: float = 10.0
## A pad the rules add lands between pad_gap_seconds minus this and pad_gap_seconds after the last.
@export_range(0.0, 10.0, 0.5, "suffix:s") var pad_slack_seconds: float = 2.0
## How long the ceiling above each added pad lasts (FB 105).
@export_range(1.0, 8.0, 0.5, "suffix:s") var pad_ceiling_seconds: float = 3.0
## Planning margin after the longest chase (speed boosts and a dash carry the player a little
## further in the same time).
@export_range(0.0, 10.0, 0.5, "suffix:s") var chase_margin_seconds: float = 1.0
## The next host comes at least this long after the previous chase could end (FB 105). Longer than
## the cyborg's spawn lead, so the next host isn't even in play before the chase is over.
@export_range(0.0, 30.0, 0.5, "suffix:s") var host_gap_seconds: float = 7.0


func telegraph_time(t: float) -> float:
	return scaled(telegraph_early, telegraph_late, t)


## Seconds from a telegraph's start until the claws are live: the slash's warning.
func warning_time(t: float) -> float:
	return telegraph_time(t) + lunge_time


## The stretch of track [from, to] a chase from a host at `at` can cover at run speed `speed`: from
## the host's spot to where the longest chase (plus the margin) ends.
func chase_stretch(at: float, speed: float) -> Vector2:
	return Vector2(at, at + (chase_max_seconds + chase_margin_seconds) * speed)

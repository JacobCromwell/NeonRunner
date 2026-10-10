class_name CyborgGunTuning
extends EnemyTuning
## The arm-cannon numbers shared by floor and window cyborgs (GDD §9.2): a visible charge-up with a
## sound, then a burst of 2–3 loosely aimed laser bolts slow enough to dodge by switching lanes, then
## a pause to reload. Fire rate and bolt speed scale across the campaign (early/late pairs; the
## level's enemy_scaling picks between them, GDD §6). DESIGN-TBD: every number here is a prototype
## value until playtested.

@export_group("Attack")
## Starts charging a burst once the player is this close (and the shot would be fair, see Fairness).
@export_range(10.0, 150.0, 1.0, "suffix:m") var engage_distance: float = 72.0
## The telegraph: the arm cannon glows up, with the cyborg_charge sound, for this long before a burst.
@export_range(0.3, 2.0, 0.05, "suffix:s") var charge_time: float = 0.75
## GDD §9.2: bursts of 2–3 bolts.
@export_range(1, 5) var burst_min: int = 2
@export_range(1, 5) var burst_max: int = 3
@export_range(0.05, 0.6, 0.01, "suffix:s") var shot_interval: float = 0.18
## Pause between bursts (reloading). Shorter late in the campaign: a higher fire rate.
@export_range(0.3, 6.0, 0.05, "suffix:s") var reload_early: float = 2.2
@export_range(0.3, 6.0, 0.05, "suffix:s") var reload_late: float = 1.3
## Bolt speed over the ground; the running player closes in at run speed on top of it.
@export_range(3.0, 40.0, 0.5, "suffix:m/s") var bolt_speed_early: float = 10.0
@export_range(3.0, 40.0, 0.5, "suffix:m/s") var bolt_speed_late: float = 15.0
## Loose aim: a burst lands up to this far sideways from where it aimed, each bolt up to
## shot_jitter more. Keep the sum under about 0.3 m (half the player's hitbox width plus the bolt's
## radius) so a burst still hits a player who stays in its path.
@export_range(0.0, 1.0, 0.01, "suffix:m") var aim_error: float = 0.14
@export_range(0.0, 1.0, 0.01, "suffix:m") var shot_jitter: float = 0.1
## How long a bolt stays in flight before the pool takes it back.
@export_range(1.0, 6.0, 0.1, "suffix:s") var bolt_life: float = 3.5

@export_group("Fairness")
## A burst only starts (and each bolt only fires) if the bolt needs at least this long to reach the
## player, on top of the charge-up.
@export_range(0.2, 2.0, 0.05, "suffix:s") var min_warning_time: float = 0.75
## The player's path from this far before a bolt arrives to clear_after_impact after it must be free
## of fences and gaps in every lane, so a dodge never has to happen during a jump or into a lane the
## player can't use (a burst is never timed onto a full-lane fence).
@export_range(0.0, 30.0, 0.5, "suffix:m") var clear_before_impact: float = 12.0
@export_range(0.0, 30.0, 0.5, "suffix:m") var clear_after_impact: float = 8.0
## A burst keeps its place in the air (CyborgAirspace: GameRules.max_bursts_in_air at once, GDD §9.2)
## until this long after its last bolt: with every place taken, the next starts charging only then.
@export_range(0.0, 3.0, 0.05, "suffix:s") var burst_gap: float = 0.5
## DESIGN-TBD (docs/OPEN_QUESTIONS.md item 600): the crossfire rule (CyborgGun._crossfire_fair). Bursts whose
## bolts arrive within this long of each other must leave the runner a way out, a place one move away that
## none of them is aimed at (wild fire never arrives that close to another burst); otherwise the later one
## waits, before its charge-up, until its bolts would arrive at least this long before or after the
## others', time enough to switch lanes between them.
@export_range(0.0, 2.0, 0.05, "suffix:s") var crossfire_gap: float = 0.5
## DESIGN-TBD (docs/OPEN_QUESTIONS.md item 600): the runner's reaction time, for the crossfire rule. A burst still
## charging that began its charge-up longer ago than this may be dodged before another's aim locks, so a
## burst about to start takes it as aimed where the runner is now; one that began since will lock where the
## new one does.
@export_range(0.0, 1.0, 0.05, "suffix:s") var reaction_time: float = 0.25


func reload_at(t: float) -> float:
	return scaled(reload_early, reload_late, t)


func bolt_speed_at(t: float) -> float:
	return scaled(bolt_speed_early, bolt_speed_late, t)

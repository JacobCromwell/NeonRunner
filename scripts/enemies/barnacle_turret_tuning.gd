class_name BarnacleTurretTuning
extends CyborgGunTuning
## The Barnacle Turret (GDD §9.8), the Marketplace's ceiling hazard. It fires the cyborgs' way
## (CyborgGunTuning: a visible charge-up with a sound, a short burst of bolts, a reload pause), only
## at a rider on its own ceiling, and slightly more accurately than the cyborg (aim_error and
## shot_jitter below data/enemies/cyborg.tres). Edit data/enemies/barnacle_turret.tres.
## DESIGN-TBD: every number here is a prototype value until playtested.
##
## Health is in plain laser tier 1 shots, rounded to a whole shot at the level's enemy_scaling
## (BarnacleTurret): 5 from quick play to the Corporate zone and 6 in the Dead Zone and the Golden
## Zone, so it takes slightly more to kill later, never by much (GDD §9.8). Laser tier 1 takes two
## more shots than that (PowerupTuning.tier1_extra_shots, GDD §8): 7 where it first appears. Its
## health_late is 5.9 (6 before the Casino's levels re-spaced the campaign's enemy scaling, task K2),
## so Corporate 2 keeps its 5.
## Its reload shortens across the campaign (reload_early → reload_late): it fires somewhat faster.
##
## Its bolts are faster than the cyborg's: a runner closes in on a turret at run speed, so a slow bolt
## would meet the rider almost at the turret, where the fairness rules (Ceiling fairness) don't let
## it fire. The dodge window is min_warning_time either way.

@export_group("Emerging")
## It pops out of the ceiling's underside this long before the player reaches it at their speed (so a
## floor runner sees it too, before its ceiling's pad), and stays put. DESIGN-TBD
## (docs/questions/c1.md 2): when it pops out.
@export_range(1.0, 8.0, 0.1, "suffix:s") var emerge_seconds: float = 3.5
## How long the pop takes.
@export_range(0.1, 1.5, 0.05, "suffix:s") var emerge_time: float = 0.4

@export_group("Ceiling fairness")
## GDD §9.8: every burst is dodgeable within the ceiling's lanes. A burst only starts (and each bolt
## only fires) if a lane beside the rider's, on the ceiling, stays clear of every turret's body from
## clear_before_impact before its arrival to clear_after_impact after it, widened by this much: the
## rider has somewhere to dodge to, and one who dodged into a turret's lane has room to switch back
## out before passing it. On a two-lane ceiling that lane is the turret's own, so its bolts only ever
## arrive well before it.
@export_range(0.0, 5.0, 0.1, "suffix:m") var body_reach: float = 1.0
## The rider must still be on the ceiling this far past that window (they drop off its far end).
@export_range(0.0, 10.0, 0.5, "suffix:m") var end_margin: float = 1.0

@export_group("Placement")
## The share of the ceilings a turret fits on that get turrets, early and late in the campaign (the
## level's enemy_scaling). The level's first such ceiling past the feature's start always does.
@export_range(0.0, 1.0, 0.05) var ceiling_share_early: float = 0.45
@export_range(0.0, 1.0, 0.05) var ceiling_share_late: float = 0.65
## GDD §9.8: at most 2 per ceiling. The share of turreted ceilings that get a second turret, early and
## late, from pair_min_scaling on only (none in the level that introduces it, Marketplace 1), never
## on the level's first turreted ceiling. 0.4: from Marketplace 2 on (0.45 before the Casino's levels
## re-spaced the campaign's enemy scaling, task K2).
@export_range(0.0, 1.0, 0.05) var pair_share_early: float = 0.3
@export_range(0.0, 1.0, 0.05) var pair_share_late: float = 0.5
@export_range(0.0, 1.0, 0.05) var pair_min_scaling: float = 0.4
## A turret stands at least this long (at run speed) past its ceiling's last pad: the rider sees it
## pop out before taking the pad, and its first burst fits in (a charge-up from the pad, then
## min_warning_time of flight).
@export_range(0.5, 5.0, 0.05, "suffix:s") var after_pad_seconds: float = 2.2
## ... and at least this long where its lane is the only one beside the pad's (a two-lane ceiling, or
## the lane next to a pad at the ceiling's edge): a rider riding on from the pad can only dodge into
## the turret's own lane, so its bolts may only come well before it (Ceiling fairness), which takes
## more room to fit a burst in.
@export_range(0.5, 6.0, 0.05, "suffix:s") var tight_after_pad_seconds: float = 3.0
## ... and at least this long before the ceiling's far end.
@export_range(0.0, 3.0, 0.05, "suffix:s") var before_end_seconds: float = 0.2
## Two turrets on one ceiling stand at least this long apart (at run speed).
@export_range(0.3, 4.0, 0.05, "suffix:s") var spacing_seconds: float = 1.2
## A turret keeps this far from a credit on the ceiling in its lane.
@export_range(0.0, 10.0, 0.5, "suffix:m") var credit_margin: float = 3.0
## In the level that introduces it (a feature start, LevelConfig.feature_starts), the first turret
## comes within this long (at run speed) of the start. When no ceiling it fits on lies there, the
## rules add a plain one for it, this long, or shorter where that doesn't fit (barnacle_turret_rules.gd).
@export_range(2.0, 30.0, 0.5, "suffix:s") var intro_seconds: float = 8.0
@export_range(2.5, 6.0, 0.1, "suffix:s") var intro_ceiling_seconds: float = 4.0


## Plain laser tier 1 shots to kill it at a level's enemy_scaling `t`: health_at(t) rounded to a
## whole shot (at least 1).
func whole_health_at(t: float) -> float:
	return maxf(1.0, roundf(health_at(t)))


func ceiling_share_at(t: float) -> float:
	return scaled(ceiling_share_early, ceiling_share_late, t)


func pair_share_at(t: float) -> float:
	return scaled(pair_share_early, pair_share_late, t) if t >= pair_min_scaling else 0.0

class_name BuzzOverdriveTuning
extends EnemyTuning
## The Buzz Overdrive's numbers (GDD §9.9; data/enemies/buzz_overdrive.tres; F6 "Enemy: buzz_overdrive").
## Seconds stay the same at every zone's speed; distances that stand for a time are metres at
## MovementTuning.REFERENCE_SPEED (18 m/s) and are stretched by the level's pace (GDD §3: a faster zone
## is never secretly tighter, docs/ARCHITECTURE.md, Pace). Its health (in laser tier 1 shots, GDD §8)
## is 20: laser tier 1 takes two more shots against it (PowerupTuning.tier1_extra_shots), so 22, as
## GDD §9.9 says; the higher tiers take 20 / their damage.
## Timeline, as the player runs (keyed to the player's distance, so the same on every attempt):
## parked in its lane in the distance; rolls ahead of the player `charge_distance()` in front for
## roll_seconds; revs (the warning: the red line over its lane, the spin-up) for rev_seconds while it
## keeps rolling; charges back at the player for charge_seconds until it meets them, cutting the floor
## behind it (B4's FloorCut), and runs on run_past metres past them, off the screen.

@export_group("Attack")
## How long it revs before it charges: its warning (GDD §9.9: "revs in view for a few seconds"). The
## level's enemy_scaling picks a value between the two (0 = the campaign's first level, 1 = its last):
## it first appears in Corporate 1 (scaling 0.57: 2.93 s) and revs a little faster each level up to the
## Golden Palace (2.5 s), the only thing that changes across the campaign (GDD §9.9).
@export_range(1.0, 6.0, 0.05, "suffix:s") var rev_seconds_early: float = 3.5
@export_range(1.0, 6.0, 0.05, "suffix:s") var rev_seconds_late: float = 2.5
## Seconds it rolls ahead of the player, in view and in its lane, before it starts revving (GDD
## §9.9: "the player sees it in the distance, in its lane"): within the missiles' reach and beyond
## laser tier 1's, so the missile tiers usually stop it before it charges and tier 1 can't.
@export_range(0.0, 8.0, 0.1, "suffix:s") var roll_seconds: float = 4.0
## Seconds from the start of its charge until it reaches a player running at the run speed.
@export_range(0.3, 3.0, 0.05, "suffix:s") var charge_seconds: float = 0.6
## How fast it charges along its lane toward the player, m/s at the reference speed (45: two and a half
## times the runner's). Its cut runs on ahead of where it meets the player for charge_seconds times
## this over the run speed (1.5 s of running), longer than the floor holds after a block
## (GameRules.cut_hold_seconds), so a player who stays in its lane after a block falls once the hold is
## over (GDD §9.9: "a jump would land back in the cut lane"); and it starts from charge_distance()
## ahead, within the missiles' 70 m and beyond laser tier 1's 42 m at every zone's speed.
@export_range(5.0, 90.0, 0.5, "suffix:m/s") var charge_speed: float = 45.0
## How far past the player it runs, still cutting, before it's gone (off the screen behind them; plain
## metres: the camera's view behind the player doesn't change with the speed).
@export_range(5.0, 60.0, 1.0, "suffix:m") var run_past: float = 22.0

@export_group("Placement")
## In a level that gives the feature a start (Corporate 1 introduces it), the first one sets off within
## this many seconds of the start where a cut fits, even if the pattern picked there didn't fit
## (buzz_overdrive_rules.gd).
@export_range(0.0, 60.0, 1.0, "suffix:s") var intro_seconds: float = 15.0

@export_group("Look")
## How far ahead it shows up, parked in its lane (plain metres: within the track built ahead).
@export_range(40.0, 170.0, 5.0, "suffix:m") var appear_distance: float = 150.0
## The tank's size: width (inside its lane), height and length behind its blade.
@export var body_size: Vector3 = Vector3(2.0, 2.0, 5.2)
## Its vertical blade: a disc along the lane, its lowest point on the floor at its front.
@export_range(0.6, 2.0, 0.05, "suffix:m") var blade_radius: float = 1.3
## The blade's hitbox (an enemy attack: the armor and the shield block it): narrow and centred on its
## lane, so a player beside it or a wall runner next to it is never touched (GDD §9.9, GB 6).
@export var hitbox_size: Vector3 = Vector3(0.7, 2.4, 2.4)
## Sparks from the blade while it cuts, a burst every this many seconds (none with Reduced flashing).
@export_range(0.02, 1.0, 0.01, "suffix:s") var spark_every: float = 0.06


## Its rev (the warning) at a level's enemy_scaling `t`.
func rev_at(t: float) -> float:
	return scaled(rev_seconds_early, rev_seconds_late, t)


## How fast it charges at a level's `pace` (MovementTuning.pace).
func charge_speed_at(pace: float) -> float:
	return charge_speed * pace


## How far ahead of the player it is when its charge starts (and while it rolls and revs): what it
## covers with the player in charge_seconds, at run speed `run_speed` and `pace`.
func charge_distance(run_speed: float, pace: float) -> float:
	return charge_seconds * (run_speed + charge_speed_at(pace))


## Metres past its cut's end its lane keeps clear for it: its body, behind its blade.
func keep() -> float:
	return body_size.z + 1.0

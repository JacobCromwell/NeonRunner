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
## roll_seconds, claiming its turn among the big attacks claim_seconds before its rev; revs (the
## warning: the red line over its lane, the spin-up) for rev_seconds while it keeps rolling; charges
## back at the player for charge_seconds until it meets them, cutting the floor behind it (B4's
## FloorCut), and runs on run_past metres past them, off the screen. If another type's big attack
## begun before its claim is still on as its rev would start, it lets the runner pass instead: it
## speeds off ahead, out of view pass_seconds later, and its floor stays whole.

@export_group("Attack")
## How long it revs before it charges: its warning (GDD §9.9: "revs in view for a few seconds"). The
## level's enemy_scaling picks a value between the two (0 = the campaign's first level, 1 = its last):
## it first appears in Corporate 1 (scaling 0.625: 2.88 s) and revs a little faster each level up to the
## Golden Palace (2.5 s), the only thing that changes across the campaign (GDD §9.9).
@export_range(1.0, 6.0, 0.05, "suffix:s") var rev_seconds_early: float = 3.5
@export_range(1.0, 6.0, 0.05, "suffix:s") var rev_seconds_late: float = 2.5
## Seconds it rolls ahead of the player, in view and in its lane, before it starts revving (GDD
## §9.9: "the player sees it in the distance, in its lane"): within the missiles' reach and beyond
## laser tier 1's, so the missile tiers usually stop it before it charges and tier 1 can't. DESIGN-TBD
## (docs/questions/c2.md): the roll, and "in time" read as "before it charges".
@export_range(0.0, 8.0, 0.1, "suffix:s") var roll_seconds: float = 4.0
## Seconds from the start of its charge until it reaches a player running at the run speed.
@export_range(0.3, 3.0, 0.05, "suffix:s") var charge_seconds: float = 0.6
## How fast it charges along its lane toward the player, m/s at the reference speed (45: two and a half
## times the runner's). Its cut runs on ahead of where it meets the player for charge_seconds times
## this over the run speed (1.5 s of running), longer than the floor holds after a block
## (GameRules.cut_hold_seconds), so a player who stays in its lane after a block falls once the hold is
## over (GDD §9.9: "a jump would land back in the cut lane"); and it starts from charge_distance()
## ahead, within the missiles' 70 m and beyond laser tier 1's 42 m at every zone's speed. DESIGN-TBD
## (docs/questions/c2.md): the charge's time and speed.
@export_range(5.0, 90.0, 0.5, "suffix:m/s") var charge_speed: float = 45.0
## How far past the player it runs, still cutting, before it's gone (off the screen behind them; plain
## metres: the camera's view behind the player doesn't change with the speed).
@export_range(5.0, 60.0, 1.0, "suffix:m") var run_past: float = 22.0

@export_group("Turns")
## GDD §9: big attacks take turns. Its rev and charge can't wait (the generator planned its cut), so,
## like a Gilded Sentinel, it claims its turn this many seconds (at the run speed) before its rev, while
## it rolls ahead: from then on it reports its attack (is_major_attack_active), so another type's big
## attack that gets ready meanwhile waits for it. One begun before its claim and still on as its rev would
## start makes it let the runner pass instead (no rev, no cut). Longer: fewer passes, others held longer.
## 0: it claims its turn only as its rev starts. A boss's tank (no roll) neither claims nor passes.
## DESIGN-TBD (docs/questions/fix2.md).
@export_range(0.0, 6.0, 0.25, "suffix:s") var claim_seconds: float = 2.5
## When it lets the runner pass, it speeds off ahead of them, out of view (appear_distance ahead) this
## many seconds later, and is gone. DESIGN-TBD (docs/questions/fix2.md).
@export_range(0.5, 6.0, 0.1, "suffix:s") var pass_seconds: float = 3.0

@export_group("Placement")
## In a level that gives the feature a start (Corporate 1 introduces it), the first one sets off within
## this many seconds of the start where a cut fits, even if the pattern picked there didn't fit
## (buzz_overdrive_rules.gd). DESIGN-TBD (docs/questions/c2.md).
@export_range(0.0, 60.0, 1.0, "suffix:s") var intro_seconds: float = 15.0

@export_group("Look")
## How far ahead it shows up, parked in its lane (plain metres: within the track built ahead).
@export_range(40.0, 170.0, 5.0, "suffix:m") var appear_distance: float = 150.0
## The tank's size: width (inside its lane), height and length behind its blade.
@export var body_size: Vector3 = Vector3(2.2, 2.2, 5.6)
## Its vertical blade: a disc along the lane, its lowest point on the floor at its front.
@export_range(0.6, 2.0, 0.05, "suffix:m") var blade_radius: float = 1.5
## The blade's hitbox (an enemy attack: the armor and the shield block it): narrow and centred on its
## lane, so a player beside it or a wall runner next to it is never touched (GDD §9.9, GB 6).
@export var hitbox_size: Vector3 = Vector3(0.7, 2.4, 2.4)
## Sparks from the blade while it cuts, from its own emitter (none with Reduced flashing). Read when it's
## built: the next one shows a change.
@export_range(10.0, 200.0, 5.0) var sparks_per_second: float = 90.0

@export_group("Sound")
## Its rev and charge come from its own voice, at full volume within this distance (plain metres), fading
## out at the same multiple of the library's warning distances (SfxLibrary). Its rev plays a charge's
## distance ahead (about 50-60 m), where the library's distances, made for hazards close by, would leave
## it about 16 dB quieter than up close.
@export_range(10.0, 120.0, 5.0, "suffix:m") var sound_full_volume_distance: float = 60.0


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

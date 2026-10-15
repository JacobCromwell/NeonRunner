class_name ChargePathTuning
extends Resource
## Cyborgs in charge paths (owner, October 7, 2026, GDD §9.13 "Teaching": "occasionally a cyborg stands in the
## path of an Octodog's lunge or a Buzz Overdrive's charge, so the player sees a charge flatten another enemy";
## task G7): where the planted cyborg stands and what keeps the encounter fair (ChargePathPlacement). How many a
## level gets is its own LevelConfig.charge_path_cyborgs. Edit data/tuning/charge_paths.tres (F6: "Charge paths",
## in a level that has them; Restart level rebuilds). Times are seconds at the level's run speed and distances
## metres at MovementTuning.REFERENCE_SPEED, stretched by the level's pace, so a faster zone keeps every one of
## them (GDD §3, Pace). Every number here is a first value for playtesting (DESIGN-TBD).

@export_group("Octodog")
## How far in front of the Octodog's spot the cyborg stands, in the lane beside the dog's (metres at the
## reference speed): its first lunge, two lanes across, goes through it about halfway to where it would meet a
## runner in the far lane (the dog crosses 5 m of track by then at the reference speed).
@export_range(1.5, 4.5, 0.1, "suffix:m") var dog_cyborg_ahead: float = 2.5
## Seconds before the charge's warning (the dog's planned wind-up, the tank's rev) that a planted encounter
## claims its turn among the big attacks (GDD §9; a Buzz Overdrive's own claim_seconds if that's longer): another
## type's big attack that gets ready meanwhile waits for it, so the charge comes as planned. Longer than a drone's
## barrage or a hover truck's lurch or cannon shot lasts, so one begun before the claim is over by the warning.
@export_range(0.0, 6.0, 0.25, "suffix:s") var claim_seconds: float = 4.0

@export_group("Buzz Overdrive")
## Seconds of run in front of the parked tank's blade the cyborg stands (BuzzOverdrive waits at its cut's end
## for a planted cyborg: a tank that rolls ahead of the runner would drive through it).
@export_range(0.15, 1.0, 0.05, "suffix:s") var tank_cyborg_seconds: float = 0.35

@export_group("Fairness")
## The planted cyborg holds its fire from this long before the charge's warning (the wind-up, the rev) and no
## bolt of its lands from then until the charge has passed the runner (and hold_after_seconds more).
@export_range(0.0, 3.0, 0.05, "suffix:s") var hold_before_seconds: float = 1.0
@export_range(0.0, 3.0, 0.05, "suffix:s") var hold_after_seconds: float = 0.5
## The least time the runner is still behind the cyborg when the charge reaches it, at the run speed: it's
## flattened in view, ahead of them.
@export_range(0.2, 2.0, 0.05, "suffix:s") var in_view_seconds: float = 0.4
## Seconds of run kept between the encounter (its claim to the end of its strike) and every big attack planned
## around it that can't wait for its claim or claims a turn of its own (a Bad Dream's chase, a Resonator's pulse, a
## Gilded Sentinel's strike, another Octodog's run or Buzz Overdrive's attack; a hover truck in one of its lanes),
## so nothing holds its charge back (ChargePathPlacement.attack_near).
@export_range(0.0, 20.0, 0.5, "suffix:s") var attack_margin_seconds: float = 2.0

@export_group("Placement")
## Never the encounter that introduces the charging enemy (the first of its kind in the level whose schedule
## brings it in: GDD §6, one new thing at a time).
@export var skip_introductions: bool = true

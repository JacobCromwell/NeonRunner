class_name WideGapTuning
extends Resource
## Wider gaps (owner, October 7, 2026, GDD §9.13 "Holes": "every level has a couple of wider gaps. They're
## uncommon, still jumpable by the player, and wide enough that an Enforcer following the player into one is
## wrecked"; task G7): how wide they are and what they keep clear of (WideGapPlacement). How many a level gets
## is its own LevelConfig.wide_gaps. Edit data/tuning/wide_gaps.tres (F6: "Wider gaps", in a level that has
## them; Restart level rebuilds). Times are seconds at the level's run speed and the width is a share of a
## full jump at it, so a faster zone keeps every one of them (GDD §3, Pace). Every number here is a first
## value for playtesting (DESIGN-TBD).

@export_group("Width")
## How long a wider gap is along the run, as a share of a full jump at the level's speed: more than an
## Enforcer Truck hops (EnforcerTruckTuning.max_hop_jump_fraction, 0.6), so one that follows the runner into
## it is wrecked, and within what a level may ask a runner to jump (LevelConfig.max_gap_jump_fraction, 0.8).
## The levels' own gaps are 0.4 to 0.55 of a jump. At 0.7 a normal jump clears it from a take-off about
## 0.3 s wide (0.4 s for the widest of the others).
@export_range(0.62, 0.8, 0.01) var jump_fraction: float = 0.7

@export_group("Clearance")
## Seconds of run before the take-off with nothing else in any lane (no hole, fence, pad, ramp, speed pad,
## ceiling or landing zone, floor cut or enemy's attack): the runner lines up for the jump alone. Never less
## than the level's spacing between two patterns at its difficulty there (LevelConfig.spacing_seconds_easy to
## spacing_seconds_hard; in a level paced in bursts its burst spacing: its quiet spacing is pacing, not reaction time).
@export_range(0.5, 4.0, 0.05, "suffix:s") var clear_before_seconds: float = 0.9
## Seconds of run after the landing with nothing else in any lane, as before the take-off. Never less than
## the level's spacing there, as before the take-off.
@export_range(0.5, 4.0, 0.05, "suffix:s") var clear_after_seconds: float = 0.9
## Seconds of run kept between two wider gaps, so a level's couple are spread out (the level's length
## allowing).
@export_range(0.0, 60.0, 0.5, "suffix:s") var spacing_seconds: float = 15.0
## Seconds of run kept clear of side wall gaps (WallGapPlacement) either side of a wider gap's take-off and
## landing, on both walls: a runner on a wall over a wide gap is never dropped into it.
@export_range(0.0, 3.0, 0.05, "suffix:s") var wall_gap_clear_seconds: float = 0.6

@export_group("Placement")
## Where an Enforcer Truck chases the runner, one of the level's wider gaps comes during its chase if one fits
## there (one of the level's rows made longer, else a new row, else a row other holes and plain fences kept from
## fitting, with those taken out; each truck in turn), once the truck has settled behind the runner, so the
## runner can lead it in.
@export var prefer_enforcer_chases: bool = true
## Where too few of the level's own rows can be widened fairly, a new row of the wider gap's width (in every
## lane but one: the lane a hover truck keeps there, else the open lane seeded) goes where everything else is
## clear by the same margins.
@export var add_rows: bool = true

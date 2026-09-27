class_name FloatingHeadTuning
extends Resource
## The Floating Head's numbers (GDD §10; data/bosses/city_boss_tuning.tres, F6 in its fight). Timings
## are at pace 1: each phase divides them by its BossPhase.pace (GDD §10: the next phase is faster).
## The GDD fixes the first bombing run's length (about 15-20 s), the searchlight that warns where the
## bombs fall and their falling whistle; every other number here is a placeholder (DESIGN-TBD,
## docs/questions/e1.md).

@export_group("Ship")
## The hull fills the street between the walls (a giant ship in a street canyon), less this on each
## side; its loudspeaker "ears" stand out into that margin. The walls of its arena carry no signs,
## so nothing on them reaches the ship.
@export_range(0.5, 2.0, 0.05, "suffix:m") var street_margin: float = 0.6
## From the face (the stern, toward the player) to the bow.
@export_range(12.0, 40.0, 0.5, "suffix:m") var hull_length: float = 24.0
## The head's height, belly to crown, on a 3-lane street and on a 6-lane one (by width in between).
@export_range(6.0, 16.0, 0.25, "suffix:m") var head_height_narrow: float = 10.5
@export_range(6.0, 16.0, 0.25, "suffix:m") var head_height_wide: float = 12.0

@export_group("Entrance")
## The first phase's intro (its BossPhase.intro_seconds): the ship roars in overhead from behind the
## player, its stern starting this far behind them and its belly this high, and pulls ahead to its
## bombing station. The run starts when it gets there.
@export_range(10.0, 80.0, 1.0, "suffix:m") var enter_behind: float = 42.0
@export_range(6.0, 30.0, 0.5, "suffix:m") var enter_height: float = 10.5

@export_group("Bombing run")
## GDD §10: the first run lasts about 15-20 s (from the searchlight switching on to its last bomb).
@export_range(5.0, 30.0, 0.5, "suffix:s") var first_run_seconds: float = 17.0
## GDD §10: once or twice during the fight it rises for another, shorter run. Here: at the start of
## the next `later_runs` phases, after it rises back into the sky (0 = never).
@export_range(0.0, 20.0, 0.5, "suffix:s") var later_run_seconds: float = 9.0
@export_range(0, 2) var later_runs: int = 2
## Its station during a run: its stern this far ahead of the player and its belly this high, so it
## looms over the top of the screen with its searchlight pointing back at the lanes.
@export_range(10.0, 60.0, 0.5, "suffix:m") var station_ahead: float = 34.0
@export_range(8.0, 30.0, 0.5, "suffix:m") var station_height: float = 12.0

@export_group("Searchlight")
## How fast the light's spot sweeps sideways across the lanes.
@export_range(2.0, 40.0, 0.5, "suffix:m/s") var sweep_speed: float = 10.0
## After each blast the light swings away across the lanes, up to this many lanes from the player,
## before it comes back to hunt them, and sweeps at least this long before it can linger again.
@export_range(1, 4) var sweep_out_lanes: int = 2
@export_range(0.0, 3.0, 0.05, "suffix:s") var sweep_seconds: float = 0.6
## The spot rests on the player's lane this long before it locks on.
@export_range(0.0, 1.0, 0.02, "suffix:s") var settle_seconds: float = 0.12
## The warning: from the light lingering on a spot (it turns red, the target circle shows, the lock
## sound plays and the bomb falls with its whistle) to the blast.
@export_range(0.5, 3.0, 0.05, "suffix:s") var lock_seconds: float = 1.1
## Every n-th lock of a run covers two lanes side by side, so the player has to pick the free side
## (0 = never).
@export_range(0, 8) var straddle_every: int = 3
## The light's spot on the floor (radius): a lane wide; a straddle's spans both lanes.
@export_range(0.5, 3.0, 0.05, "suffix:m") var spot_radius: float = 1.35

@export_group("Bombs")
## The bomb is aimed at where the player will be: they would reach the blast's centre this long
## after it goes off, when the fireball is at its biggest.
@export_range(0.0, 0.3, 0.01, "suffix:s") var arrival_seconds: float = 0.1
## How long a blast burns (its hitbox is live).
@export_range(0.1, 1.0, 0.05, "suffix:s") var blast_seconds: float = 0.35
## The target circle's radius, and the fireball's.
@export_range(0.5, 2.0, 0.05, "suffix:m") var blast_radius: float = 1.1
## The blast's hitbox: its share of the lane's width, its depth along the track and its height
## (too tall to jump over). Forgiving (GDD §3): a little smaller than the fireball, and on an outer
## lane it keeps clear of a wall runner beside it.
@export_range(0.3, 1.0, 0.05) var blast_width_share: float = 0.7
@export_range(0.5, 3.0, 0.05, "suffix:m") var blast_depth: float = 1.9
@export_range(1.0, 4.0, 0.1, "suffix:m") var blast_height: float = 2.4

@export_group("Fairness")
## A bomb only falls where the lanes it strikes are free of holes and fences from this far before the
## blast to this far after it: it lands on a roof, and nothing else needs dodging there.
@export_range(0.0, 20.0, 0.5, "suffix:m") var clear_before_impact: float = 8.0
@export_range(0.0, 20.0, 0.5, "suffix:m") var clear_after_impact: float = 5.0
## ...and only where the player has a way out: a lane it doesn't strike, at most this many lanes
## away, with that lane and every lane on the way free of holes and fences from the player to this far
## past the blast, so the dodge is a plain lane switch.
@export_range(1, 3) var max_escape_lanes: int = 2
@export_range(0.0, 20.0, 0.5, "suffix:m") var escape_clear_after: float = 5.0
## ...and never on a pickup waiting in its lane within this distance.
@export_range(0.0, 10.0, 0.5, "suffix:m") var pickup_margin: float = 3.0

@export_group("Reveal")
## After a run it drops in front of the player, its stern this far ahead and its belly this high:
## above the fences' stacks (2.5 m), so the track stays in view under it.
@export_range(1.0, 6.0, 0.1, "suffix:s") var descend_seconds: float = 3.0
@export_range(10.0, 60.0, 0.5, "suffix:m") var face_ahead: float = 26.0
@export_range(2.6, 10.0, 0.1, "suffix:m") var face_height: float = 3.0
## GDD §10's reveal: the first time it drops in front of the player, its back turns out to be a face.
## The face screen powers on this long before it settles (and takes this long to come on).
@export_range(0.5, 4.0, 0.1, "suffix:s") var boot_seconds: float = 1.6

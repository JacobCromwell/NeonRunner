class_name CyborgTuning
extends CyborgGunTuning
## Floor cyborg numbers (GDD §9.2), on top of the arm cannon's (CyborgGunTuning). Edit
## data/enemies/cyborg.tres. DESIGN-TBD: prototype values until playtested. That includes its raw
## health (health_early/health_late, in laser tier 1 shots): GDD §8 leaves the cyborg's shots to kill
## open, so it is 3 early and 5 late for now. Laser tier 1's actual shots to kill are two more (5
## early, 7 late, PowerupTuning.tier1_extra_shots, GDD §8's September 30, 2026 playtest), the same as
## every other non-screech enemy; other tiers divide the raw health plainly.

@export_group("Movement")
## Walks slowly toward the player once they are this close.
@export_range(10.0, 150.0, 1.0, "suffix:m") var walk_start_distance: float = 90.0
@export_range(0.0, 5.0, 0.1, "suffix:m/s") var walk_speed: float = 1.4
## Walks at most this far from where it was placed.
@export_range(0.0, 30.0, 0.5, "suffix:m") var walk_max: float = 8.0
## Once passed, it drops back quickly (GDD §9.2).
@export_range(0.0, 30.0, 0.5, "suffix:m/s") var drop_back_speed: float = 8.0
## Cyborgs always stay this far from any gap, fence, ramp, pad or ceiling section (every lane), so
## one never blocks the lane a player needs at an obstacle. The generator also drops cyborgs placed
## closer than this.
@export_range(2.0, 30.0, 0.5, "suffix:m") var obstacle_margin: float = 10.0

@export_group("Panic variant")
## GDD §9.2: about 1 in 3 cyborgs panics. The generator rolls it for each placed cyborg.
@export_range(0.0, 1.0, 0.01) var panic_chance: float = 0.33
## It notices the player at this distance, freezes with a shocked face, then runs.
@export_range(10.0, 120.0, 1.0, "suffix:m") var panic_trigger_distance: float = 58.0
@export_range(0.0, 2.0, 0.05, "suffix:s") var panic_startle_time: float = 0.35
@export_range(0.0, 20.0, 0.5, "suffix:m/s") var panic_speed: float = 8.5
## How far it runs at most before cowering (less if an obstacle is ahead).
@export_range(0.0, 100.0, 1.0, "suffix:m") var panic_run_max: float = 45.0
## Wild shots over the shoulder land anywhere within this distance sideways of the player.
@export_range(0.0, 6.0, 0.1, "suffix:m") var panic_spread: float = 2.6

@export_group("Host")
## DESIGN-TBD: the big score bonus for deliberately killing a host (GDD §9.7), on top of the kill.
@export_range(0, 20000, 50) var host_bonus: int = 1500

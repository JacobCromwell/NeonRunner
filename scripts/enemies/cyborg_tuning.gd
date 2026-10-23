class_name CyborgTuning
extends CyborgGunTuning
## Floor cyborg numbers (GDD §9.2), on top of the arm cannon's (CyborgGunTuning). Edit
## data/enemies/cyborg.tres. DESIGN-TBD: prototype values until playtested. That includes its raw
## health (health_early/health_late, in laser tier 1 shots): GDD §8 leaves the cyborg's shots to kill
## open, so it is 3 early and 4.9 late for now. Laser tier 1's actual shots to kill are two more (5
## early, 7 late, PowerupTuning.tier1_extra_shots, GDD §8's September 30, 2026 playtest), the same as
## every other non-screech enemy; other tiers divide the raw health plainly. The late 4.9 (5 before the
## Casino's levels re-spaced the campaign's enemy scaling, task K2) keeps each level's shots to kill at
## every tier where they were: the enhanced laser's fourth shot from Corporate 2, the heavy missile's
## splash's fourth from Dead Zone 2.

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
## DESIGN-TBD: the big score bonus for killing a host with a stomp, the claws or the dash (GDD §9.7: "still
## earns a big score bonus"), on top of the kill.
@export_range(0, 20000, 50) var host_bonus: int = 1500
## DESIGN-TBD (docs/OPEN_QUESTIONS.md item 628): the host bonus for a weapon kill (GDD §9.7, owner, October 8, 2026:
## weapons hit hosts, and a weapon kill releases the Bad Dream). The GDD keeps the big bonus for a stomp,
## the claws and the dash; placeholder 0: a weapon kill pays an ordinary cyborg kill's score only.
@export_range(0, 20000, 50) var weapon_host_bonus: int = 0

@export_group("Host look")
## What picks a host out of a crowd of cyborgs at running distance (GDD §9.7, owner, October 23, 2026; task S1):
## its body glows purple (a rim glow in cyborg_body.gdshader, lighting only the host itself) and a faint pale
## lilac smoke rises off it (HostSmoke, one draw call per host, host_smoke.gdshader). The smoke is a veil over
## whatever stands behind the host on screen, a cyborg charging its cannon or a fence among them, and a violet
## veil turns a red charge pink (the fences' colour): so the smoke has to stay thin and pale, the glow on the
## body carries the read, and the smoke fades out as the runner closes on the host.
## DESIGN-TBD (docs/OPEN_QUESTIONS_DEFERRED.md item 1213): how much of each, and how far out the smoke fades.
## The purple glow on the host's body (0 none; 1.5 is a clear violet outline from 14 to 100 m).
@export_range(0.0, 3.0, 0.05) var host_glow_energy: float = 1.5
## The smoke's opacity at the thickest, at most HostSmoke.MAX_STRENGTH (more would veil a red charge pink); 0
## turns the smoke off.
@export_range(0.0, 0.4, 0.01) var host_smoke_strength: float = 0.4
## How much of each column the billows fill: 0 thin wisps, 1 a solid column.
@export_range(0.0, 1.0, 0.01) var host_smoke_density: float = 0.6
## How fast the billows climb. The range stops at 1 m/s so the smoke never flickers: no billow passes a point more
## than about 1.3 times a second then, under the 3 a second that Reduced flashing guards against.
@export_range(0.1, 1.0, 0.05, "suffix:m/s") var host_smoke_rise_speed: float = 0.7
## The middle column's height (its top reaches this far above the host's spine) and its width at the base.
@export_range(0.5, 6.0, 0.1, "suffix:m") var host_smoke_height: float = 1.8
@export_range(0.2, 3.0, 0.05, "suffix:m") var host_smoke_width: float = 1.0
## The smoke is gone closer to the camera than the first distance and at full strength beyond the second (the run
## camera is 7.5 m behind the runner, so 12 and 22 m: gone for a host within 4.5 m of the runner, a stomp's reach
## and the approach to it, full from 14.5 m ahead).
@export_range(0.0, 60.0, 0.5, "suffix:m") var host_smoke_near_gone: float = 12.0
@export_range(0.0, 60.0, 0.5, "suffix:m") var host_smoke_near_full: float = 22.0

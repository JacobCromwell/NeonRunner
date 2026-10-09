class_name DroneTuning
extends EnemyTuning
## Numbers for the heli drone (GDD §9.6), in data/enemies/drone.tres. Pairs named _early/_late scale
## across the campaign with the level's enemy_scaling (GDD §6). The GDD fixes the 10 s / 8–10 s /
## ~15 s pad rules and the health (15, laser tier 1 shots); the owner's placeholder review approved
## the wave and pad schedule as is (FB 89, FB 90). Values still marked DESIGN-TBD are placeholders,
## not design decisions. Laser tier 1's actual shots to kill are 17
## (PowerupTuning.tier1_extra_shots stretches its tier 1 hit, GDD §8's September 30, 2026 playtest).

@export_group("Hovering")
## DESIGN-TBD: how far ahead of the player the drone hovers, and how high (below the 6 m ceiling,
## and below the camera's eye level so it stands out from the vanishing point).
@export_range(6.0, 30.0, 0.5, "suffix:m") var hover_ahead: float = 11.0
@export_range(2.5, 5.5, 0.1, "suffix:m") var hover_height: float = 3.2
## Size of the model (1 = about 2.3 m from rotor tip to rotor tip).
@export_range(0.5, 2.0, 0.05) var model_scale: float = 1.35
## A second drone of the same wave hovers this much further ahead and higher.
@export_range(0.0, 15.0, 0.5, "suffix:m") var wave_spacing: float = 5.0
@export_range(0.0, 1.5, 0.05, "suffix:m") var wave_rise: float = 0.55
## Sideways speed while following the player between lanes.
@export_range(1.0, 25.0, 0.5, "suffix:m/s") var follow_speed: float = 8.0
## Over a wall the drone stays this far inside the wall face.
@export_range(0.3, 3.0, 0.05, "suffix:m") var wall_inset: float = 1.2

@export_group("Entrance")
## GDD §9.6: it swoops in from the distance as a warning (drone_swoop).
@export_range(0.5, 3.0, 0.05, "suffix:s") var swoop_time: float = 1.5
@export_range(20.0, 150.0, 1.0, "suffix:m") var swoop_distance: float = 65.0
## Height the swoop starts from (keep it under the ceiling so it never crosses a ship's hull).
@export_range(2.5, 5.8, 0.1, "suffix:m") var swoop_height: float = 5.4
@export_range(0.0, 15.0, 0.5, "suffix:m") var swoop_side: float = 7.0
## Following time after the swoop before the first wind-up.
@export_range(0.2, 5.0, 0.1, "suffix:s") var first_follow_time: float = 1.2

@export_group("Barrage")
## DESIGN-TBD: time following the player between barrages.
@export_range(0.5, 8.0, 0.1, "suffix:s") var follow_time_early: float = 3.0
@export_range(0.5, 8.0, 0.1, "suffix:s") var follow_time_late: float = 2.0
## The audible wind-up (drone_windup) and the visible spin-up and aim line before a barrage.
@export_range(0.4, 3.0, 0.05, "suffix:s") var windup_early: float = 1.15
@export_range(0.4, 3.0, 0.05, "suffix:s") var windup_late: float = 0.95
## Bullets per barrage. Capped so the whole barrage lands within invulnerability_share of the hit
## invulnerability window: armor or a shield then protects through all of it (GDD §9.6).
@export_range(1, 20) var bullets_early: int = 6
@export_range(1, 20) var bullets_late: int = 7
## Time between bullets: the gap that lets the player zigzag through the stream.
@export_range(0.08, 0.5, 0.01, "suffix:s") var bullet_interval_early: float = 0.18
@export_range(0.08, 0.5, 0.01, "suffix:s") var bullet_interval_late: float = 0.15
## Bullet speed relative to the player (the drone paces the player).
@export_range(5.0, 40.0, 0.5, "suffix:m/s") var bullet_speed_early: float = 16.0
@export_range(5.0, 40.0, 0.5, "suffix:m/s") var bullet_speed_late: float = 21.0
@export_range(0.5, 1.0, 0.01) var invulnerability_share: float = 0.9
## Stationary pause after a barrage before it moves again.
@export_range(0.0, 2.0, 0.05, "suffix:s") var cooldown: float = 0.5
## Bullets live this long after passing the player's position.
@export_range(0.1, 2.0, 0.05, "suffix:s") var bullet_overshoot: float = 0.35

@export_group("Destroyed")
## Upward speed when an anti-grav pad hurls it into the ship's hull.
@export_range(2.0, 40.0, 0.5, "suffix:m/s") var hurl_speed: float = 9.0

@export_group("Generator rules")
## GDD §9.6: at least 10 s of dodging before a pad appears ...
@export_range(0.0, 30.0, 0.5, "suffix:s") var first_pad_seconds: float = 10.0
## The first pad lands within this many seconds after that minimum (FB 90).
@export_range(0.0, 5.0, 0.25, "suffix:s") var first_pad_slack_seconds: float = 1.0
## ... then another 8–10 s after each pad, repeating ...
@export_range(2.0, 30.0, 0.5, "suffix:s") var pad_repeat_min_seconds: float = 8.0
@export_range(2.0, 30.0, 0.5, "suffix:s") var pad_repeat_max_seconds: float = 10.0
## ... and no drone appears in the last ~15 s of a level.
@export_range(0.0, 60.0, 1.0, "suffix:s") var no_spawn_last_seconds: float = 15.0
## How long the ceiling above each scheduled pad lasts (FB 90).
@export_range(1.0, 8.0, 0.5, "suffix:s") var pad_ceiling_seconds: float = 3.0
## A wave can bring a second drone (extra attackers, GDD §6) only from this
## enemy_scaling on, and never as a level's first wave (one new thing at a time; FB 89). 0.4: from
## Marketplace 2 on (0.5 before the Casino's levels re-spaced the campaign's enemy scaling, task K2).
@export_range(0.0, 1.0, 0.05) var pair_min_scaling: float = 0.4
## A new wave of drones comes at least this long after the previous one (FB 89).
@export_range(0.0, 120.0, 1.0, "suffix:s") var min_wave_gap_seconds: float = 20.0
## A level with the drone feature always gets at least one drone (FB 89; the patterns may pick
## none); it's placed between these shares of the level.
@export var guarantee_one_wave: bool = true
@export_range(0.0, 1.0, 0.05) var guaranteed_wave_from: float = 0.2
@export_range(0.0, 1.0, 0.05) var guaranteed_wave_to: float = 0.45


func follow_time_at(t: float) -> float:
	return scaled(follow_time_early, follow_time_late, t)


func windup_at(t: float) -> float:
	return scaled(windup_early, windup_late, t)


func bullets_at(t: float) -> int:
	return roundi(scaled(float(bullets_early), float(bullets_late), t))


func bullet_interval_at(t: float) -> float:
	return scaled(bullet_interval_early, bullet_interval_late, t)


func bullet_speed_at(t: float) -> float:
	return scaled(bullet_speed_early, bullet_speed_late, t)


## Bullets in one barrage at scaling `t`, capped so the barrage (first to last bullet) fits inside
## `invulnerability_share` of `invulnerability` seconds.
func barrage_count(t: float, invulnerability: float) -> int:
	var interval: float = bullet_interval_at(t)
	var fits: int = int(floor(invulnerability * invulnerability_share / interval + 0.0001)) + 1
	return clampi(bullets_at(t), 1, maxi(fits, 1))

class_name HoverTruckTuning
extends EnemyTuning
## Numbers for the hover truck (GDD §9.3), in data/enemies/hover_truck.tres. Pairs named _early/_late
## scale across the campaign with the level's enemy_scaling (GDD §6). The GDD fixes the 20–30 s stay,
## the 0 → 1–2 window shooters and the health (15, laser tier 1 shots); laser tier 1's actual shots
## to kill are 17 (PowerupTuning.tier1_extra_shots stretches its tier 1 hit, GDD §8's September 30,
## 2026 playtest; health and every other tier are unchanged). Everything else here is a DESIGN-TBD
## placeholder.

@export_group("Shape")
## Length (cab + cargo box) and width. It holds one lane.
@export_range(5.0, 12.0, 0.1, "suffix:m") var length: float = 8.0
@export_range(1.4, 2.3, 0.05, "suffix:m") var width: float = 2.0
## The cargo roof and the lower cab roof. Both must be out of reach of a jump from the floor (jump
## height + the player's 0.35 m landing snap = 1.95 m) and within a wall jump's arc from the wall:
## the routes onto the roof (GDD §9.3) go through the wall (tests/suites/test_hover_truck.gd).
@export_range(1.6, 3.5, 0.05, "suffix:m") var roof_height: float = 2.2
@export_range(1.5, 3.5, 0.05, "suffix:m") var cab_roof_height: float = 1.85
@export_range(1.0, 4.0, 0.1, "suffix:m") var cab_length: float = 2.4
## The deadly front (spiked nose or plow), ahead of the cab.
@export_range(0.4, 2.5, 0.05, "suffix:m") var nose_length: float = 1.2
## Height of the hovering underside above the floor, and its subtle bob.
@export_range(0.2, 1.2, 0.05, "suffix:m") var hover_clearance: float = 0.62
@export_range(0.0, 0.3, 0.01, "suffix:m") var bob_height: float = 0.05

@export_group("Entrance")
## GDD §9.3: it bangs on a building wall as a warning (truck_bang), then bursts through
## (truck_burst). The banging starts this long before the burst at the player's speed.
@export_range(0.8, 4.0, 0.05, "suffix:s") var bang_seconds: float = 2.0
@export_range(0.2, 1.5, 0.05, "suffix:s") var bang_interval: float = 0.55
## The warning always lasts at least this long, even if the player speeds up.
@export_range(0.5, 3.0, 0.05, "suffix:s") var min_warning_seconds: float = 1.4
## It bursts out when the player is this far before its burst point (the truck's centre then).
@export_range(4.0, 30.0, 0.5, "suffix:m") var burst_lead: float = 10.0
## How long the burst hurts a player on that wall section, and how far the section reaches beyond
## the truck toward the player and ahead.
@export_range(0.1, 1.0, 0.05, "suffix:s") var burst_hazard_seconds: float = 0.45
@export_range(0.0, 10.0, 0.5, "suffix:m") var burst_section_before: float = 3.0
@export_range(0.0, 10.0, 0.5, "suffix:m") var burst_section_after: float = 1.0
@export_range(0.2, 2.0, 0.05, "suffix:s") var emerge_seconds: float = 0.55

@export_group("Pacing and lurches")
## Offsets are the truck's centre relative to the player along the track (+ = ahead of them).
## Pacing ahead, where the cannon fires back at the player.
@export_range(0.0, 30.0, 0.5, "suffix:m") var pace_offset: float = 10.0
## Behind the player after a backward lurch; its front stays in the camera's view.
@export_range(-20.0, 0.0, 0.5, "suffix:m") var back_offset: float = -7.0
## After a forward lurch: the cab alongside the player, the landing spot for both roof routes.
@export_range(-10.0, 5.0, 0.1, "suffix:m") var alongside_offset: float = -2.8
@export_range(1.0, 10.0, 0.1, "suffix:s") var pace_seconds_early: float = 3.5
@export_range(1.0, 10.0, 0.1, "suffix:s") var pace_seconds_late: float = 4.5
@export_range(0.3, 5.0, 0.1, "suffix:s") var hold_back_seconds: float = 1.6
## The forward lurch's warning: an engine rev (truck_rev), flashing spikes, glowing thrusters and a
## light thrown ahead of it onto the floor.
@export_range(0.5, 2.5, 0.05, "suffix:s") var rev_seconds: float = 1.0
@export_range(0.3, 5.0, 0.1, "suffix:s") var alongside_seconds: float = 1.8
@export_range(2.0, 30.0, 0.5, "suffix:m/s") var lurch_back_speed: float = 13.0
@export_range(2.0, 30.0, 0.5, "suffix:m/s") var lurch_forward_speed: float = 12.0
@export_range(5.0, 120.0, 1.0, "suffix:m/s²") var lurch_accel: float = 60.0
@export_range(0.5, 15.0, 0.5, "suffix:m/s") var drift_speed: float = 5.0
@export_range(1.0, 60.0, 1.0, "suffix:m/s²") var drift_accel: float = 10.0
## A backward lurch held up by a player in its lane behind it gives up after this long.
@export_range(0.5, 5.0, 0.1, "suffix:s") var lurch_back_timeout: float = 2.5
## Room kept from a player in its lane: behind its rear, and ahead of its spikes except during a
## forward lurch. Only the telegraphed forward lurch ever drives it into the player.
@export_range(0.0, 5.0, 0.1, "suffix:m") var rear_gap: float = 1.0
@export_range(0.0, 5.0, 0.1, "suffix:m") var front_gap: float = 1.0
## A forward lurch only starts if a player in its lane ahead of it could get out (to the next lane
## or onto the wall) within rev_seconds + this margin.
@export_range(0.0, 2.0, 0.05, "suffix:s") var escape_margin: float = 0.6
## While the player rides the roof it eases back at this speed, carrying them toward the cab.
@export_range(0.5, 8.0, 0.1, "suffix:m/s") var roof_drift_speed: float = 2.5

@export_group("Leaving")
## GDD §9.3: it falls behind after 20–30 s if not destroyed.
@export_range(5.0, 60.0, 1.0, "suffix:s") var stay_min_seconds: float = 20.0
@export_range(5.0, 60.0, 1.0, "suffix:s") var stay_max_seconds: float = 30.0
@export_range(1.0, 20.0, 0.5, "suffix:m/s") var leave_speed: float = 7.0
## Extra time the generator keeps its lane clear after stay_max, while it falls out of sight.
@export_range(0.0, 20.0, 0.5, "suffix:s") var leave_seconds: float = 6.0

@export_group("Cannon")
## GDD §9.3: a cannon with a slow fire rate, telegraphed by truck_cannon_charge and a growing glow.
## It fires only while pacing ahead of the player.
@export_range(1.0, 10.0, 0.1, "suffix:s") var cannon_interval_early: float = 4.5
@export_range(1.0, 10.0, 0.1, "suffix:s") var cannon_interval_late: float = 3.0
@export_range(0.5, 3.0, 0.05, "suffix:s") var cannon_charge_seconds: float = 1.2
## Shell speed relative to the player.
@export_range(4.0, 30.0, 0.5, "suffix:m/s") var shell_speed_early: float = 10.0
@export_range(4.0, 30.0, 0.5, "suffix:m/s") var shell_speed_late: float = 13.0
@export_range(0.0, 5.0, 0.1, "suffix:s") var first_shot_delay: float = 0.6

@export_group("Window shooters")
## GDD §9.3: window shooters scale from 0 early to 1–2 by the final levels (rounded down). They fire
## bolts just after the cannon, in the same telegraphed volley (their guns glow during the charge).
## 0.2 to 2.1 (0 to 2 before the Casino's levels re-spaced the campaign's enemy scaling, task K2): one
## from Marketplace 2 and two at the Golden Palace, where they were.
@export_range(0.0, 3.0, 0.1) var shooters_early: float = 0.2
@export_range(0.0, 3.0, 0.1) var shooters_late: float = 2.1
@export_range(0.1, 1.5, 0.05, "suffix:s") var shooter_delay: float = 0.35
@export_range(4.0, 30.0, 0.5, "suffix:m/s") var bolt_speed_early: float = 12.0
@export_range(4.0, 30.0, 0.5, "suffix:m/s") var bolt_speed_late: float = 15.0

@export_group("Wreck")
## Stomped or shot down, it spins out for this long, then explodes (truck_explode). It skids on
## ahead of the player (starting this much faster than them, slowing to their pace) so the
## explosion happens in view.
@export_range(0.3, 3.0, 0.05, "suffix:s") var wreck_seconds: float = 1.1
@export_range(0.0, 20.0, 0.5, "suffix:m/s") var wreck_skid_speed: float = 9.0

@export_group("Generator rules")
## Metres of its lane kept clear before the burst point.
@export_range(0.0, 60.0, 1.0, "suffix:m") var clear_before: float = 20.0
## A new truck comes at least this long after the previous one's lane is free again.
@export_range(0.0, 60.0, 1.0, "suffix:s") var min_gap_seconds: float = 6.0
## GDD §9.3: rare early, more frequent later. At most this many trucks in a level, scaled with the
## level's enemy_scaling (rounded down): 1 early, up to 3 by the last levels. 1.2 to 3.1 (1 to 3 before
## the Casino's levels re-spaced the campaign's enemy scaling, task K2): two from Marketplace 2 and
## three at the Golden Palace, where they were.
@export_range(1.0, 5.0, 0.1) var max_per_level_early: float = 1.2
@export_range(1.0, 5.0, 0.1) var max_per_level_late: float = 3.1
## When the level has ramps, route (a) gets a ramp on the truck's side this long after the burst.
@export_range(2.0, 30.0, 0.5, "suffix:s") var ramp_after_seconds: float = 7.0
## A level with the hover_truck feature always gets at least one truck (the patterns may pick
## none), placed between these shares of the level.
@export var guarantee_one: bool = true
@export_range(0.0, 1.0, 0.05) var guaranteed_from: float = 0.2
@export_range(0.0, 1.0, 0.05) var guaranteed_to: float = 0.5


func pace_seconds_at(t: float) -> float:
	return scaled(pace_seconds_early, pace_seconds_late, t)


func cannon_interval_at(t: float) -> float:
	return scaled(cannon_interval_early, cannon_interval_late, t)


func shell_speed_at(t: float) -> float:
	return scaled(shell_speed_early, shell_speed_late, t)


func bolt_speed_at(t: float) -> float:
	return scaled(bolt_speed_early, bolt_speed_late, t)


## Trucks allowed in one level at scaling `t`.
func max_per_level_at(t: float) -> int:
	return maxi(1, int(floor(scaled(max_per_level_early, max_per_level_late, t) + 0.001)))


## Window shooters at scaling `t`: 0 early, up to 2 by the last levels.
func shooters_at(t: float) -> int:
	return int(floor(scaled(shooters_early, shooters_late, t) + 0.001))


## Seconds a truck whose centre is `from_offset` metres ahead of the runner takes to drop to back_offset
## (behind them) at its lurch back (lurch_back_speed, reached at lurch_accel): how long before a dash wall it
## must start giving way (task H7a; HoverTruck._wall_ahead, and the generator's keep-out for its entrance,
## dash_wall_rules.gd). 0 if it's there already.
func give_way_seconds(from_offset: float) -> float:
	var way: float = maxf(from_offset - back_offset, 0.0)
	if way <= 0.0:
		return 0.0
	var speed: float = maxf(lurch_back_speed, 0.1)
	var accel: float = maxf(lurch_accel, 0.1)
	# Speeding up to lurch_back_speed costs half the time it takes, then it cruises.
	var ramp: float = speed / accel
	if way <= 0.5 * speed * ramp:
		return sqrt(2.0 * way / accel)
	return ramp + (way - 0.5 * speed * ramp) / speed

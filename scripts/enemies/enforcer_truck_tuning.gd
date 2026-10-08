class_name EnforcerTruckTuning
extends EnemyTuning
## The Enforcer Truck's numbers (GDD §9.13, owner, October 4, 2026; data/enemies/enforcer_truck.tres; F6
## "Enemy: Enforcer Truck"). The owner decided the design: it drives behind the runner and copies their lane
## after a short delay (about 0.8 s), shows itself by its headlights and light bar on the floor of its lane
## and a marker at the screen's bottom edge, fires warned lasers down the runner's lane, picks up cyborgs
## left alive in its lane (up to 3, proposed), gives up after about 25 s, and dies only to an Octodog's lunge
## or a Buzz Overdrive's charge baited into it, a Buzz Overdrive's cut, or a gap too wide to hop. Every other
## number here is a placeholder (DESIGN-TBD, docs/questions/c6.md). Seconds stay the same at every zone's
## speed; its gaps behind the runner are plain metres (the camera's view behind the runner doesn't change with
## the speed), so its bolts, which take bolt_flight_seconds to reach the runner, keep their timing too.

@export_group("Chase")
## GDD §9.13: it gives up after about 25 s if not destroyed, counted from its arrival. It never leaves while
## an Octodog is about to charge or charging, or a Buzz Overdrive is about to rev, revs or charges (its baits),
## so a bait that came a little late (a wait for its turn) still finds it there.
@export_range(5.0, 60.0, 0.5, "suffix:s") var chase_seconds: float = 25.0
## GDD §9.13 (proposed: about 0.8 s): it copies the runner's lane this long after they change it, so a late
## dodge leaves it in the lane they just left.
@export_range(0.2, 2.0, 0.05, "suffix:s") var lane_delay_seconds: float = 0.8
## DESIGN-TBD: how long its own lane change takes (the runner's takes 0.14 s; a heavy truck is slower).
@export_range(0.1, 1.0, 0.01, "suffix:s") var switch_seconds: float = 0.35
## DESIGN-TBD: its front's distance behind the runner while it follows (plain metres): behind the camera
## (MovementTuning.camera_distance, 7.5 m), so only its lights and its marker show.
@export_range(7.6, 20.0, 0.1, "suffix:m") var follow_gap: float = 8.5
## DESIGN-TBD: its front's distance behind the runner while an Octodog attacks (GDD §9.13: it closes right up
## behind the runner, so the lunge, which ends lunge_overshoot behind them, reaches it). Never more than the
## lunge's reach at the reference speed less close_margin (EnforcerTruck.close_gap_for), and its body stays
## under the camera's line of sight to the runner at this gap (tests/suites/test_enforcer_truck.gd).
@export_range(1.6, 3.0, 0.05, "suffix:m") var close_gap: float = 2.4
## How far into its front an Octodog's lunge reaches at least (metres past its front): the close gap is held
## at most the lunge's end less this.
@export_range(0.2, 1.5, 0.05, "suffix:m") var close_margin: float = 0.6
## It closes up this many seconds of running before an Octodog would wind up (the dog standing a stop
## distance ahead), and stays close until the dog gives up.
@export_range(0.0, 3.0, 0.1, "suffix:s") var close_lead_seconds: float = 1.0
## How fast its gap eases toward the one it wants (per second), and the most it changes in a second.
@export_range(1.0, 20.0, 0.5) var gap_rate: float = 5.0
@export_range(2.0, 60.0, 0.5, "suffix:m/s") var gap_speed_max: float = 22.0
## DESIGN-TBD: where it drives in from (its front's gap behind the runner as it arrives, with its siren),
## and how far behind it is gone when it leaves, falling back this fast.
@export_range(15.0, 100.0, 1.0, "suffix:m") var arrive_gap: float = 45.0
@export_range(20.0, 150.0, 1.0, "suffix:m") var gone_gap: float = 60.0
@export_range(1.0, 30.0, 0.5, "suffix:m/s") var leave_speed: float = 9.0

@export_group("Volleys")
## GDD §9.13: a red line on the floor ahead in the runner's lane and a rising whine warn each volley. Its first
## bolt reaches the runner bolt_flight_seconds after the warning ends.
@export_range(0.6, 3.0, 0.05, "suffix:s") var warning_seconds: float = 1.0
## DESIGN-TBD: seconds from one volley's end to the next one's warning with no rider aboard; each rider makes
## it rider_rate_bonus quicker (the rate rises by that share for each, GDD §9.13), and the first comes
## first_volley_seconds after it arrives.
@export_range(1.0, 20.0, 0.1, "suffix:s") var volley_interval_seconds: float = 5.0
@export_range(0.0, 15.0, 0.1, "suffix:s") var first_volley_seconds: float = 3.0
## DESIGN-TBD: a volley's shots, this far apart. Each shot is a column of bolts down the runner's lane at
## bolt_heights, so a jump or a slide doesn't dodge it: leaving the lane does (as the gunship's strafes in
## Hostile Takeover).
@export_range(1, 6) var shots_per_volley: int = 3
@export_range(0.05, 0.5, 0.01, "suffix:s") var shot_gap_seconds: float = 0.12
## Seconds a bolt takes from its front to the runner: it flies at the runner's speed plus its gap over this.
@export_range(0.15, 1.5, 0.05, "suffix:s") var bolt_flight_seconds: float = 0.35
## A shot's bolts, metres above the floor: together they reach over a slide and a whole jump (a standing
## runner's hurtbox is 1.09 m tall, a jump's peak 1.6 m).
@export var bolt_heights: PackedFloat32Array = PackedFloat32Array([0.35, 1.05, 1.75])
## A volley only starts when a lane beside the runner's is clear (no hole, fence, cut, doodad, floor enemy
## or hover truck) from this many seconds of running after its warning starts until its last bolt has passed.
@export_range(0.0, 1.0, 0.05, "suffix:s") var escape_reaction_seconds: float = 0.35
## The red line: from just behind the runner to this far ahead of them, in the lane its volley sweeps.
@export_range(5.0, 60.0, 1.0, "suffix:m") var line_ahead: float = 26.0

@export_group("Riders")
## GDD §9.13 (proposed: up to 3): cyborgs it picks up, riding its roof.
@export_range(0, 3) var max_riders: int = 3
## DESIGN-TBD: how much each rider raises its rate of fire (0.4: the next volley comes after the interval over
## 1 + 0.4 per rider).
@export_range(0.0, 2.0, 0.05) var rider_rate_bonus: float = 0.4
## DESIGN-TBD: the level score for each rider aboard when it's destroyed (GDD §9.13: a bonus for each rider).
@export_range(0, 5000, 10) var rider_bonus: int = 250
## DESIGN-TBD (docs/questions/c6.md): a host cyborg left alive isn't picked up.
@export var picks_up_hosts: bool = false

@export_group("Holes")
## DESIGN-TBD (docs/questions/c6.md): a gap in its lane longer than this share of the runner's full jump at
## the level's speed is too wide to hop, and wrecks it; it hops every shorter one. The levels' gaps are 0.4 to
## 0.55 of a jump (data/patterns), so at 0.6 none of them is too wide, but each campaign level's couple of wider
## gaps are (task G7: WideGapTuning.jump_fraction, 0.7; WideGapPlacement puts one in its chase where one fits).
@export_range(0.3, 1.0, 0.01) var max_hop_jump_fraction: float = 0.6
## How high it bounces over a gap it hops (looks only).
@export_range(0.1, 2.0, 0.05, "suffix:m") var hop_height: float = 0.6

@export_group("Placement")
## GDD §9.13: up to two per level, never two at once.
@export_range(0, 4) var per_level_max: int = 2
## DESIGN-TBD: where its bait may come in its chase. The bait's warning (an Octodog's first wind-up, a Buzz
## Overdrive's rev) comes at least bait_after_seconds after it arrives (it has settled behind the runner), and
## its charge at least bait_before_seconds before it would give up. Where it can, it holds its fire for the
## bait (from hold_seconds() before the warning) bait_prefer_min/max_seconds after it arrives (a seeded spot),
## so it has room for its first volley or two (first_volley_seconds, then a volley) before the bait.
@export_range(2.0, 20.0, 0.5, "suffix:s") var bait_after_seconds: float = 4.0
@export_range(2.0, 20.0, 0.5, "suffix:s") var bait_before_seconds: float = 5.0
@export_range(2.0, 20.0, 0.5, "suffix:s") var bait_prefer_min_seconds: float = 8.0
@export_range(2.0, 20.0, 0.5, "suffix:s") var bait_prefer_max_seconds: float = 13.0
## DESIGN-TBD: seconds between one's chase ending (it has dropped back) and the next one arriving.
@export_range(0.0, 60.0, 0.5, "suffix:s") var spacing_seconds: float = 8.0
## Seconds it takes to drop back out of sight after giving up, kept clear of the next one too.
@export_range(0.0, 10.0, 0.5, "suffix:s") var leave_seconds: float = 4.0

@export_group("Look")
## Its size: width (inside its lane), roof height and length behind its front.
@export var body_size: Vector3 = Vector3(2.2, 2.4, 6.4)
## Its hitbox: what an Octodog's lunge or a Buzz Overdrive's saw must touch. Slightly smaller than the
## look, from this far above the floor to its roof, and starting this far behind its front.
@export var hitbox_size: Vector3 = Vector3(2.0, 2.1, 6.0)
@export_range(0.0, 1.0, 0.05, "suffix:m") var hitbox_floor: float = 0.25
## The light bar's red and blue take turns this many times a second (both stay lit, steady, with Reduced
## flashing).
@export_range(0.5, 6.0, 0.1, "suffix:Hz") var flash_hz: float = 2.0


## Seconds from a volley's warning until its last bolt has passed the runner (its whole attack).
func volley_seconds() -> float:
	return warning_seconds + shot_gap_seconds * maxi(shots_per_volley - 1, 0) + bolt_flight_seconds + 0.15


## Seconds from one volley's end to the next one's warning with `riders` aboard.
func volley_interval(riders: int) -> float:
	return volley_interval_seconds / (1.0 + rider_rate_bonus * maxi(riders, 0))


## Seconds of running before a bait's warning (an Octodog's wind-up, a Buzz Overdrive's rev) from which it
## starts no volley: one started earlier is over before it closes up for the Octodog (close_lead_seconds), and
## at least that long before the rev (so before a Buzz Overdrive claims its turn, claim_seconds, too).
func hold_seconds() -> float:
	return close_lead_seconds + volley_seconds()


## How close it comes behind the runner during an Octodog's attack, in a level at `pace`
## (MovementTuning.pace): close_gap, or less where the lunge (ending lunge_overshoot behind the runner,
## stretched by the pace) would stop short of its front by close_margin.
func close_gap_for(dog: OctodogTuning, pace: float) -> float:
	var reach: float = (dog.lunge_overshoot if dog != null else 3.0) * pace - close_margin
	return clampf(minf(close_gap, reach), 1.6, close_gap)

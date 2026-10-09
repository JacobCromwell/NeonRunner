class_name EnforcerTruckTuning
extends EnemyTuning
## The Enforcer Truck's numbers (GDD §9.13, owner, October 4, 2026; data/enemies/enforcer_truck.tres; F6
## "Enemy: Enforcer Truck"). The owner decided the design: it drives behind the runner and copies their lane
## after a short delay (about 0.8 s), shows itself by its headlights and light bar on the floor of its lane
## and a marker at the screen's bottom edge, fires warned lasers down the runner's lane, picks up cyborgs
## left alive in its lane (up to 3, proposed), gives up after about 25 s, and dies only to an Octodog's lunge
## or a Buzz Overdrive's charge baited into it, a Buzz Overdrive's cut, or a gap too wide to hop. Since October 8,
## 2026 it also shows itself now and then (speeding up into view beside the runner for a few seconds), and blows
## up where the player sees it. Every other number here is a placeholder (DESIGN-TBD, docs/questions/c6.md and
## docs/questions/c6b.md). Seconds stay the same at every zone's
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

@export_group("Showing itself")
## The owner (October 8, 2026; GDD §9.13 "Showing itself"): behind the camera its model is never seen, so every
## so often it speeds up into view beside the runner, stays a few seconds, then drops back. DESIGN-TBD
## (docs/questions/c6b.md): at most this many showings a chase, one as it arrives (show_on_arrival) and the rest
## mid-chase where there's room.
@export_range(0, 4) var show_count: int = 2
## It shows itself as it arrives where there's room then, so the runner sees what's chasing them.
@export var show_on_arrival: bool = true
## The owner: it "only stays on screen for a few seconds before falling back" (proposed about 3 s alongside).
## It drops back sooner when something stands in its lane ahead (it never drives through it), but never before
## show_min_seconds: it shows itself only where its lane is clear for that long.
@export_range(1.0, 8.0, 0.1, "suffix:s") var show_seconds: float = 3.0
@export_range(0.5, 8.0, 0.1, "suffix:s") var show_min_seconds: float = 1.5
## DESIGN-TBD: its front's distance ahead of the runner while it's beside them, in a lane next to theirs: the
## chase camera then shows its whole model, its light bar and its riders (EnforcerTruckView.check), and it never
## hides the runner. It shows itself only in a lane where that holds.
@export_range(2.0, 8.0, 0.1, "suffix:m") var show_ahead: float = 4.0
## How fast it closes in from behind the camera to come alongside, how fast it drops back once its time is up,
## and how fast when it gives way (the runner moving toward its lane, an attack's warning or a bait coming):
## metres a second relative to the runner.
@export_range(4.0, 30.0, 0.5, "suffix:m/s") var show_close_speed: float = 14.0
@export_range(4.0, 30.0, 0.5, "suffix:m/s") var show_drop_speed: float = 11.0
@export_range(4.0, 40.0, 0.5, "suffix:m/s") var show_yield_speed: float = 18.0
## DESIGN-TBD: seconds of chase from a showing's end before the next showing may start.
@export_range(0.0, 20.0, 0.5, "suffix:s") var show_spacing_seconds: float = 6.0
## DESIGN-TBD: its first volley waits up to this long past its time (first_volley_seconds) for its first showing,
## while one can still come before its bait: the runner sees what's chasing them before it fires.
@export_range(0.0, 10.0, 0.5, "suffix:s") var show_wait_seconds: float = 4.0
## Seconds of running kept spare around a showing: it's back behind the runner this long (and close_lead_seconds
## more) before a bait's warning (an Octodog's wind-up, a Buzz Overdrive's rev), and the floor it needs stays
## clear this much longer.
@export_range(0.0, 5.0, 0.1, "suffix:s") var show_margin_seconds: float = 1.0
## DESIGN-TBD: how far ahead of the runner no enemy may be in its lane or beyond it (toward that side's wall)
## while it's alongside: from the camera it would hide one there. It gives way when one comes that close.
@export_range(0.0, 80.0, 1.0, "suffix:m") var show_shadow_reach: float = 30.0
## Its sides are safe but solid while it shows itself (GDD §9.3, the hover truck's): a lane change into it is
## bumped back. The solid side reaches this far ahead of its front too, so the runner can't step in just ahead.
@export_range(0.0, 4.0, 0.1, "suffix:m") var blocker_ahead: float = 1.5
## Its siren swells as it pulls alongside: it starts this many decibels under its full volume.
@export_range(0.0, 40.0, 1.0, "suffix:dB") var siren_swell_db: float = 18.0
## Task C6c (the owner's request, GDD §9.13 "Showing itself": the player should see what's behind them): the
## generator plans a showing window in every chase it can (enforcer_truck_rules.gd, ShowPlanner), a calm stretch
## the later passes keep off, where it can show itself wherever the runner is; off, its showings come only where
## the level happens to leave room (as before task C6c), and the level is built as it was then. The owner (October 9,
## 2026, GDD §9.13 "Room to show itself", answering docs/OPEN_QUESTIONS.md items 383–385): its cost (about 2% fewer
## enemies and obstacles on its levels) is accepted; a truck shows itself before the player can bait it, arriving
## early enough for its window to come before its first bait, and a chase with no room for one gives its truck to
## another bait's chase that has room (task C6d). DESIGN-TBD (docs/OPEN_QUESTIONS.md items 400–403): a truck no bait with room is
## left for keeps its chase, its window after the bait or none.
@export var show_window_planned: bool = true
## How much later than planned a showing in its window may begin and still find its room (the runner jumping or
## changing lanes as it's due): the window holds that much more.
## DESIGN-TBD: 1 s (docs/OPEN_QUESTIONS.md item 386).
@export_range(0.0, 3.0, 0.25, "suffix:s") var show_window_slack_seconds: float = 1.0
## It claims its turn among the big attacks this long before its planned showing (as a Buzz Overdrive claims its
## turn before its rev): another type's big attack that gets ready meanwhile (a drone's barrage, a Resonator's pulse)
## waits for it, and one already on is over by the time it's due.
## DESIGN-TBD: 2 s (docs/OPEN_QUESTIONS.md item 386).
@export_range(0.0, 5.0, 0.25, "suffix:s") var show_claim_seconds: float = 2.0
## The owner (October 9, 2026; GDD §9.13 "Making room where there is none", answering docs/OPEN_QUESTIONS.md item
## 400): where a level's first bait comes right after its calm start (its run-up), the truck arrives a few seconds
## early and shows itself in the last part of the calm start, the bait staying where it is. It arrives no sooner than
## this many seconds into the run (the player under way), right behind the runner (at its follow gap: from arrive_gap
## it couldn't come alongside before the bait), and shows itself as it arrives; the calm start stays calm (no volley,
## nothing taken out). DESIGN-TBD: 0.5 s (docs/questions/c6e.md).
@export_range(0.0, 3.0, 0.1, "suffix:s") var calm_start_min_seconds: float = 0.5
## A level's run-up is short (2.4 s at the Golden Zone's speed) and a showing needs about 5 s, so a showing in the calm
## start runs on into the level's first patterns. The run-up itself holds nothing to take out; past it, a window may
## take out what's in its way as any other window may (plain holes, fences, cyborgs and Screeches: the owner's accepted
## cost, docs/OPEN_QUESTIONS.md item 383). Off: it takes nothing out at all, and fits only where the first patterns
## leave room. DESIGN-TBD (docs/questions/c6e.md).
@export var calm_start_takes_out: bool = true

@export_group("Wreck")
## The owner (October 8, 2026): however it's destroyed (a charge, a cut, a gap too wide to hop) it blows up where
## the player sees it. Behind the camera it would blow up unseen, so its wreck lurches on into view first, until
## its front is wreck_gap behind the runner (a wreck already that close stays where it is), over
## wreck_surge_seconds, and blows up there: in a hole, at the hole's far edge if its nose gets there first.
## DESIGN-TBD (docs/questions/c6b.md).
@export_range(1.6, 6.0, 0.1, "suffix:m") var wreck_gap: float = 2.8
@export_range(0.1, 1.0, 0.05, "suffix:s") var wreck_surge_seconds: float = 0.3
## The blast: how long its fire and smoke last, how big its fireball grows (metres; smaller in the runner's lane,
## where it must stay under the camera's line of sight to them), and how fast it falls back behind the runner
## (it keeps most of the truck's speed, so it stays in view).
@export_range(0.3, 2.0, 0.05, "suffix:s") var blast_seconds: float = 0.9
@export_range(0.5, 4.0, 0.05, "suffix:m") var blast_radius: float = 1.3
@export_range(0.3, 4.0, 0.05, "suffix:m") var blast_radius_in_lane: float = 0.85
@export_range(0.0, 10.0, 0.1, "suffix:m/s") var blast_drift: float = 0.5

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


## Seconds its gap behind the runner takes to ease `distance` metres at up to `speed` metres a second (its
## easing, gap_rate, takes over near the end), to within a quarter of a metre.
func ease_seconds(distance: float, speed: float) -> float:
	var d: float = absf(distance)
	if d <= 0.25:
		return 0.0
	var rate: float = maxf(gap_rate, 0.01)
	var knee: float = maxf(speed, 0.01) / rate
	return maxf(d - knee, 0.0) / maxf(speed, 0.01) + log(maxf(minf(d, knee), 0.25) / 0.25) / rate


## Seconds a showing takes from `from_gap` behind the runner (its front): closing in (show_close_seconds),
## alongside for `hold` seconds (show_seconds when negative), and dropping back to follow_gap.
func show_total_seconds(from_gap: float, hold: float = -1.0) -> float:
	return show_close_seconds(from_gap) + (show_seconds if hold < 0.0 else hold) \
		+ ease_seconds(follow_gap + show_ahead, show_drop_speed)


## Seconds it takes to come alongside the runner from `from_gap` behind them: at gap_speed_max while it's
## further back than follow_gap (as it arrives), then at show_close_speed.
func show_close_seconds(from_gap: float) -> float:
	if from_gap > follow_gap:
		return (from_gap - follow_gap) / maxf(gap_speed_max, 0.01) + ease_seconds(follow_gap + show_ahead, show_close_speed)
	return ease_seconds(from_gap + show_ahead, show_close_speed)


## Seconds it takes to drop back from alongside the runner until it's out of the camera's view (its front out
## of view: the camera sees no more than out_of_view behind the runner).
func show_drop_view_seconds(out_of_view: float) -> float:
	return ease_seconds(show_ahead + out_of_view, show_drop_speed)


## How close it comes behind the runner during an Octodog's attack, in a level at `pace`
## (MovementTuning.pace): close_gap, or less where the lunge (ending lunge_overshoot behind the runner,
## stretched by the pace) would stop short of its front by close_margin.
func close_gap_for(dog: OctodogTuning, pace: float) -> float:
	var reach: float = (dog.lunge_overshoot if dog != null else 3.0) * pace - close_margin
	return clampf(minf(close_gap, reach), 1.6, close_gap)

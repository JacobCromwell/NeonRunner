class_name MechaGuppyTuning
extends Resource
## Mecha Guppy and Captain Cogs' numbers (GDD §10, the Beach's boss; data/bosses/beach_boss_tuning.tres, F6 in
## its fight). Task E5e-b1 builds the climb (phases 1 and 2's gimmick) and its look; E5e-b2 the shark, the pirate,
## the bombs and the hits (the groups "Captain Cogs' bombs", "Mecha Guppy's bites", "Captain Cogs' ship"); phase 3 and
## the defeat are E5e-c's.
##
## The GDD fixes the climb's shape (MechaGuppyClimb): anti-grav pads up to tiki huts (the ceilings), tiki bar
## roofs ahead at a higher level (the floors), the lanes that lead up (one on 3 lanes; one, two or three,
## alternating, on 5-6), the two cues that show them (the hut's lanes that lead up run further, or the roof's
## lanes that lead up reach further back), alternating, one safe place to drop to being enough, a wrong drop
## falling into the floor Mecha Guppy is eating, the camera following the runner up, and phase 2's climb
## 15-25% faster (proposed: about 20%, by bringing the steps closer together; the run speed never rises in a
## fight; since E5e-b3 phase 2's steps are higher instead, phase2_rise). Every number here is a placeholder
## (DESIGN-TBD, docs/questions/e5e.md).
##
## Pace (docs/ARCHITECTURE.md, Bosses: a boss's own numbers in metres must follow the pace): the distances
## marked "at 18 m/s" stand for a time and are multiplied by the run's pace (MovementTuning.pace()), so the
## climb keeps its seconds at the Beach's 23.8 m/s; the fairness margins are written in seconds and turned into
## metres at the run's speed; heights and sizes don't change. The rest of the climb's distances come from the
## movement itself (MechaGuppyClimb: a jump's length, the flip up to a hut, a drop off its end, the fall into
## the floor below, the dash's reach), so they hold at any speed and with any movement tuning.
## Task E5e-b3 adds the bait (GDD §10, the owner, October 11, 2026: Captain Cogs' bombs lock onto the runner's lane, and
## one dodged where the lane runs out falls past the edge into Mecha Guppy's jaws; the group "The hits") and moves the
## fights' fairness numbers here from code.

@export_group("The climb")
## DESIGN-TBD: how far each tiki bar roof stands above the one before in phase 1 (metres). The climbing camera
## sees a roof up to RunCamera.FLOOR_REACH above it, and the hut over a step keeps hut_clearance over the higher roof.
@export_range(1.5, 6.0, 0.1, "suffix:m") var rise: float = 3.0
## DESIGN-TBD (GDD §10: phase 2's climb 15-25% faster; docs/questions/e5e.md): each roof's rise in phase 2 (and
## later). Phase 2's steps are as long as phase 1's (every step's roof holds a volley spot and the bait: roof_seconds),
## so its climb is faster by being higher: 3.6 m climbs 20% faster in metres per second at 3, 5 and 6 lanes
## (MechaGuppyClimb.climb_rate).
@export_range(1.5, 6.0, 0.1, "suffix:m") var phase2_rise: float = 3.6
## DESIGN-TBD: a tiki hut's underside over the floor its step starts from (metres; a level's ceilings are 6 m
## over the street). It keeps at least hut_clearance over the higher roof under its end. 8.5 m puts the riding view
## (RunCamera: 3.6 m under a ceiling) about 1.9 m over the higher roof, so its deck and the lanes that reach back
## read as a place to land.
@export_range(5.0, 10.0, 0.1, "suffix:m") var hut_height: float = 8.5
## The least room between a hut's underside and the higher roof under its end (metres): a rider hanging from
## the hut and jumping (MovementTuning.jump_height plus their body, visual_size.y, about 2.9 m) keeps clear of
## the roof under them. MechaGuppyClimb raises the hut where hut_height would leave less.
@export_range(2.5, 6.0, 0.05, "suffix:m") var hut_clearance: float = 3.2
## DESIGN-TBD (GDD §10 and the brief: the runner must see which lanes lead up and have time to switch into one,
## all the lane switches needed at the lane-switch time plus a margin, from wherever they could be on the
## hut): the margin, in seconds, beyond the switches, counted from the latest a rider can settle on the hut (one
## who jumped right before the pads, dashing, then the flip up). Every rider gets at least this, a rider who
## didn't jump about a second more. 0.9 s: a humane default for the owner to tune in playtest.
@export_range(0.2, 2.0, 0.05, "suffix:s") var read_seconds: float = 0.9
## DESIGN-TBD: the run on each roof (seconds at run speed, both phases), the one stretch of a step no fairness
## margin holds: from where a rider can first switch lanes on it (dropping off the hut over a full-width roof, or where
## a pier widens to the whole roof: MechaGuppyClimb.Step.free_at) to the next pads, on 3 lanes, and a lane switch
## longer for each lane past three. It holds a volley spot, then the bait at the roof's end (MechaGuppyPattern), with
## time between for a runner to cross to the notch from the far side.
@export_range(1.0, 6.0, 0.05, "suffix:s") var roof_seconds: float = 3.6
## DESIGN-TBD: the cue "the roof's lanes that lead up reach further back": how far under the hut's end they
## reach (metres at 18 m/s). The other lanes start where a wrong drop is already past them.
@export_range(2.0, 30.0, 0.5, "suffix:m") var reach_back: float = 10.0
## DESIGN-TBD: the cue "the hut's lanes that lead up run further": how far past the higher roof's front they run
## on (metres at 18 m/s). The other lanes end where a wrong drop misses the roof.
@export_range(1.0, 20.0, 0.5, "suffix:m") var run_on: float = 3.0
## DESIGN-TBD: the pad strip across every lane at the end of each roof is longer than the longest jump at the run
## speed (with the dash's reach) by this much (metres), so no runner can jump over it: every runner flips up
## (docs/questions/e5e.md: an unmissable strip).
@export_range(0.5, 6.0, 0.25, "suffix:m") var strip_margin: float = 2.0
## The hut starts this far before its pads (metres at 18 m/s): a pad sits under its hut.
@export_range(1.0, 10.0, 0.25, "suffix:m") var hut_lead: float = 3.0
## Mecha Guppy has eaten a roof from this far past its pads (metres): nobody runs there.
@export_range(0.25, 5.0, 0.25, "suffix:m") var edge_margin: float = 1.0
## A wrong drop is dead (or saved by the grapple) this far short of the higher roof's front (metres): it never
## touches it (the front is solid, MechaGuppyStairs).
@export_range(0.0, 3.0, 0.1, "suffix:m") var fall_margin: float = 0.5
## DESIGN-TBD (GDD §10: "one, two or three, alternating"): how many lanes lead up, step after step, on 5 lanes
## or more, cycling (3 lanes: one; 4 lanes: the entries up to two). The steps' cues alternate, RUN_ON first, and a
## REACH_BACK step has no more than two (the owner: "one or two of the roof's lanes reach further back";
## MechaGuppyClimb.REACH_BACK_MOST), so the threes sit on RUN_ON steps: 1, 2, 3, 1, 3, 2 changes the count every
## step and gives each count as often. Every lane count keeps at least one lane that doesn't lead up.
@export var up_counts: PackedInt32Array = PackedInt32Array([1, 2, 3, 1, 3, 2])
## The run on the street before the first pads (seconds at run speed): the fight's entrance.
@export_range(1.0, 10.0, 0.25, "suffix:s") var start_seconds: float = 3.5

@export_group("Phase 3")
## GDD §10 ("after the player has dodged for one minute, Mecha Guppy leaps over and eats Captain Cogs"): phase 3 lasts this
## long from the moment the runner reaches the top (MechaGuppy.top_reached); the boss bar runs down over it (GDD §10,
## proposed: so the player sees how long is left), and at its end Mecha Guppy leaps (the defeat).
@export_range(5.0, 120.0, 1.0, "suffix:s") var top_seconds: float = 60.0
## DESIGN-TBD (GDD §10: "the captain's ship comes level"; docs/questions/e5e.md): Captain Cogs' ship comes alongside the
## top on the left, level with the runner (its keel level_keel over the runner's deck: below it when negative, so its
## gun deck is at their height), its middle level_ahead ahead of them (it keeps pace), its near side level_out past the
## roof's eaves, easing down from its station high above over level_seconds once the runner reaches the top.
@export_range(1.0, 6.0, 0.1, "suffix:s") var level_seconds: float = 3.0
@export_range(18.0, 60.0, 0.5, "suffix:m") var level_ahead: float = 30.0
@export_range(0.5, 6.0, 0.25, "suffix:m") var level_out: float = 2.5
@export_range(-3.0, 3.0, 0.1, "suffix:m") var level_keel: float = -1.0
## DESIGN-TBD (GDD §10: rounds and waves "follow a fixed, learnable script", like the Golden Convergence's strafes; no
## escalation): phase 3's pattern, one letter a beat, played in a loop from the moment the runner reaches the top: R a
## round (Captain Cogs' cannons strike every other lane, the struck lanes alternating round by round, so each round after
## the first moves the runner one lane), W a wave (crashing over every lane: jump it), . a rest. The first beat comes
## top_first after the top is reached (the ship level by then), each next one top_beat after the last began, and none
## starts unless its attack is over top_clear before the minute ends (before the leap).
@export var top_script: String = "RRW.RWRRW."
@export_range(0.0, 10.0, 0.1, "suffix:s") var top_first: float = 4.0
@export_range(2.0, 5.0, 0.05, "suffix:s") var top_beat: float = 2.4
@export_range(0.0, 5.0, 0.1, "suffix:s") var top_clear: float = 1.0
## DESIGN-TBD (GDD §10, the owner: the rounds are warned by "red lines down the lanes they'll hit and a cannon's charging
## sound"): the charge (the red lines show and the cannons charge for round_warning, then fire), each cannonball's lob
## from its cannon onto the far end of its lane's line (round_flight), where it lands round_ahead ahead of the runner
## (metres; it keeps pace), then rolls down the lane at them, closing in at round_close (the same at every run speed, as
## the Resonator's waves do: its time to reach them never changes). A cannonball is round_radius in radius, too tall to
## jump (a switch dodges it); its hitbox is a little smaller.
@export_range(0.5, 2.0, 0.05, "suffix:s") var round_warning: float = 0.8
@export_range(0.15, 0.8, 0.05, "suffix:s") var round_flight: float = 0.3
@export_range(14.0, 40.0, 0.5, "suffix:m") var round_ahead: float = 24.0
@export_range(30.0, 80.0, 1.0, "suffix:m/s") var round_close: float = 50.0
@export_range(1.05, 1.2, 0.01, "suffix:m") var round_radius: float = 1.15
## DESIGN-TBD (GDD §10, the owner: a wave is warned by "a rising swell and a roar", and jumped like the Resonator's ring,
## §9.10): the swell rises out of the sea beside the top, on the side away from the ship, for wave_warning, then crashes
## over every lane wave_ahead ahead of the runner (metres; it keeps pace), and its surge rushes along the deck at them,
## closing in at wave_close (the same at every run speed): a low band wave_height tall and wave_depth deep (the
## Resonator's: a normal jump clears it; armor and the shield block it, the dash passes through).
@export_range(0.8, 2.5, 0.05, "suffix:s") var wave_warning: float = 1.2
@export_range(14.0, 40.0, 0.5, "suffix:m") var wave_ahead: float = 24.0
@export_range(20.0, 45.0, 0.5, "suffix:m/s") var wave_close: float = 30.0
@export_range(0.25, 0.65, 0.01, "suffix:m") var wave_height: float = 0.45
@export_range(0.3, 1.0, 0.05, "suffix:m") var wave_depth: float = 0.5

@export_group("The defeat")
## DESIGN-TBD (GDD §10: "Mecha Guppy leaps over and eats Captain Cogs"; "the pirate has been eaten by the shark, but the
## shark swims away"; docs/questions/e5e.md): when the minute is up, Mecha Guppy bursts up out of the sea under the ship
## (leap_rise), its jaws wide; they snap shut on the ship's stern half with the captain on it (the gulp: the bow half
## breaks away and falls); it hangs a moment (leap_hang), topples away from the top and falls back into the sea
## (leap_fall), then swims away, its dorsal fin cutting through the sea ahead and out to sea (swim_seconds); the results
## wait until it's gone (MechaGuppy.victory_over).
@export_range(0.5, 3.0, 0.05, "suffix:s") var leap_rise: float = 1.2
@export_range(0.1, 1.5, 0.05, "suffix:s") var leap_hang: float = 0.45
@export_range(0.5, 3.0, 0.05, "suffix:s") var leap_fall: float = 1.3
@export_range(1.0, 8.0, 0.1, "suffix:s") var swim_seconds: float = 4.0
## DESIGN-TBD (the brief: "choose whether the victory riff plays"): the victory riff plays riff_after the gulp (as the
## shark falls away), or the fight ends without it.
@export var victory_riff_on: bool = true
@export_range(0.0, 3.0, 0.05, "suffix:s") var riff_after: float = 1.0

@export_group("Captain Cogs' bombs")
## GDD §10: "The bombs are warned like the Floating Head's (a red target circle where each will land, and a falling
## whistle), in a pirate look." These follow the Floating Head's (data/bosses/city_boss_tuning.tres): from the throw
## (the circle shows, the throw is heard, the bomb flies with its whistle) to the blast.
@export_range(0.5, 3.0, 0.05, "suffix:s") var lock_seconds: float = 1.1
## A bomb aimed at the runner lands so they'd reach its centre this long after it goes off (the Floating Head's).
@export_range(0.0, 0.3, 0.01, "suffix:s") var arrival_seconds: float = 0.1
## How long a blast burns (its hitbox is live), the target circle's and the fireball's radius, and the blast's hitbox:
## its share of a lane's width, its depth along the track and its height (too tall to jump; the Floating Head's).
@export_range(0.1, 1.0, 0.05, "suffix:s") var blast_seconds: float = 0.35
@export_range(0.5, 2.0, 0.05, "suffix:m") var blast_radius: float = 1.1
@export_range(0.3, 1.0, 0.05) var blast_width_share: float = 0.7
@export_range(0.5, 3.0, 0.05, "suffix:m") var blast_depth: float = 1.9
@export_range(1.0, 4.0, 0.1, "suffix:m") var blast_height: float = 2.4
## DESIGN-TBD: the volleys a runner dodges, each phase (the last entry serves later phases; phase 3 has none, E5e-c),
## besides each step's bait (the group "The hits"):
## - roof_spots: up to this many spots on a roof's run before its bait, nearest first, spot_spacing apart (at 18 m/s):
##   the Floating Head's salvo, landing as the runner gets to each (fewer where a run is short);
## - landing_spots: a spot where riders come down onto the higher roof, dodged by a switch in the air as they drop
##   off the hut's end (on a pier only where it has another lane to switch to; GDD §10: phase 2, more bombs).
## Phase 2's spots take more bombs side by side (spot_bombs), and it adds the landing spot: more bombs to dodge a step,
## and a second, at the same step length.
@export var roof_spots: PackedInt32Array = PackedInt32Array([1, 1])
@export var landing_spots: PackedInt32Array = PackedInt32Array([0, 1])
@export_range(6.0, 30.0, 0.5, "suffix:m") var spot_spacing: float = 10.0
## How many bombs side by side a spot takes, each phase, on a narrow street (under wide_lanes lanes) and on a wide
## one, and the fewest lanes a spot leaves the runner to be in where it can (the Floating Head's salvo rule: one on a
## narrow street, a path to take; a choice of two on a wide one).
@export var spot_bombs: PackedInt32Array = PackedInt32Array([1, 2])
@export var spot_bombs_wide: PackedInt32Array = PackedInt32Array([2, 3])
@export_range(3, 7) var wide_lanes: int = 5
@export_range(1, 3) var spot_choices: int = 1
@export_range(1, 3) var spot_choices_wide: int = 2
## From where the runner can first switch to a spot they're in, at most this many lanes to a free one; from one spot
## of a volley to the next, at most this many (the Floating Head's).
@export_range(1, 3) var max_escape_lanes: int = 2
@export_range(1, 2) var max_shift: int = 1
## A spot is fair only where the runner, from the moment they see its circle and can switch (on the floor over every
## lane they cross, or in the air over it after a drop; never on a hut, never off a pier's side), has this long to
## react, then every switch the escape needs at the lane-switch time plus this margin.
@export_range(0.1, 1.0, 0.05, "suffix:s") var dodge_reaction: float = 0.35
@export_range(0.0, 1.0, 0.05, "suffix:s") var dodge_margin: float = 0.25
## No spot within this of a pickup waiting in its lane (metres).
@export_range(0.0, 10.0, 0.5, "suffix:m") var pickup_margin: float = 3.0
## A spot's blast lands on floor this far beyond its depth either way, and no hut reaches within hut_clear of it (the
## hut would take the bomb) (metres).
@export_range(0.0, 2.0, 0.05, "suffix:m") var floor_clear: float = 0.5
@export_range(0.5, 4.0, 0.05, "suffix:m") var hut_clear: float = 2.0
## A spot's escape lanes stay open this far past it (metres at 18 m/s, at the run's pace).
@export_range(0.0, 8.0, 0.25, "suffix:m") var escape_after: float = 3.0

@export_group("The hits")
## GDD §10 (the owner, October 11, 2026): hurting Mecha Guppy is baiting Captain Cogs' bombs. DESIGN-TBD, the bait's
## shape (MechaGuppyPattern, docs/questions/e5e.md): near the end of each roof Mecha Guppy has bitten a notch out of an
## outer lane (a seeded side, nothing to do with the lanes that lead up), its open jaws waiting below. As the runner
## comes near, one bomb's red circle follows their lane (Captain Cogs taking aim: cogs_aim) for bait_seek, then locks
## with the throw, lock_seconds before it lands as they get there: a runner in the notch's lane when it locks, who
## then switches out before the edge, sends it past the edge into the jaws, a hit; anywhere else it's a blast to dodge.
## The notch starts notch_back before the next hut (metres), the bomb lands catch_in into it (metres: clear of the
## floor behind, the shark's chin wholly over the notch), and the circle follows the runner bait_seek (seconds).
@export_range(0.2, 2.0, 0.05, "suffix:s") var bait_seek: float = 0.6
@export_range(6.0, 16.0, 0.25, "suffix:m") var notch_back: float = 7.5
@export_range(3.0, 8.0, 0.25, "suffix:m") var catch_in: float = 4.0
## DESIGN-TBD (GDD §10: "a player who doesn't manage it still progresses, more slowly: Captain Cogs sometimes misses into
## the chasm anyway"): once this many steps in a row have gone by without a hit, at the next step's hut deadline (every
## rider committed) Captain Cogs misses into the chasm in front of the higher roof, beside the lanes that lead up on the
## side with more lanes that don't, where Mecha Guppy rises to eat; the bomb comes down hit_back before that roof's
## front there (metres; the shark's head clear of the roof's face), into its open jaws: a hit, at most one a step and
## never on a step the runner fell. It threatens nobody, so it flies only hit_seconds, with its circle but no throw or
## whistle (nothing to dodge): it goes in ahead of the runner, in view. With 1 (task E5e-b3's review: 2 dragged a fight
## with no checkpoint out to about 5 minutes), a runner who never baits lands a hit every other step.
@export_range(0, 6) var fallback_after: int = 1
@export_range(6.5, 12.0, 0.25, "suffix:m") var hit_back: float = 6.8
@export_range(0.5, 1.5, 0.05, "suffix:s") var hit_seconds: float = 0.65
## The fallback's breach: Mecha Guppy's head keeps this far clear of the lanes that lead up (metres; hit_spot places the
## bomb so), its jaws are wide open this long before the bomb comes down (seconds), and it glides out of sight under the
## chasm for this long before it surges up (seconds).
@export_range(0.5, 4.0, 0.1, "suffix:m") var lane_clear: float = 1.5
@export_range(0.05, 0.6, 0.05, "suffix:s") var breach_early: float = 0.25
@export_range(0.2, 3.0, 0.1, "suffix:s") var lurk_seconds: float = 1.0

@export_group("Mecha Guppy's bites")
## DESIGN-TBD (GDD §10: its maw comes up through the floor and eats a huge chunk of the level; it eats the floors the
## runner should have left and the floor under the lanes that don't lead up, never the floor they're on). Its warning:
## the rumble, and the shark rising into view beside the roof's end, this long before the runner reaches its pads (its
## jaws come up only once the runner is up on the hut).
@export_range(0.2, 2.0, 0.05, "suffix:s") var bite_warning: float = 0.6
## Once nobody can be on the roof: it dives under the roof's top leaning in, its jaws opening, lunges up with its chin
## low across the roof's end, stays open, snaps shut dropping away with it, and sinks back (seconds).
@export_range(0.1, 1.0, 0.05, "suffix:s") var bite_dive: float = 0.25
@export_range(0.15, 1.5, 0.05, "suffix:s") var bite_rise: float = 0.35
@export_range(0.05, 1.0, 0.05, "suffix:s") var bite_hold: float = 0.15
@export_range(0.05, 0.5, 0.01, "suffix:s") var bite_snap: float = 0.14
@export_range(0.3, 3.0, 0.05, "suffix:s") var bite_sink: float = 0.6
## Once a rider has left a roof for its hut, Mecha Guppy bites the roof's end off behind them: this much of it
## (metres; never past the hut's start).
@export_range(4.0, 30.0, 0.5, "suffix:m") var bite_length: float = 14.0
## When it rises to eat beside the lanes that don't lead up (the fallback's breach): its surge up through the floor's
## level, opening (seconds; quicker than a bite's: its bomb flies only hit_seconds), and how long its jaws stay open
## around the bomb's landing.
@export_range(0.15, 1.0, 0.05, "suffix:s") var breach_rise: float = 0.3
@export_range(0.1, 1.5, 0.05, "suffix:s") var breach_hold: float = 0.35
## A bite put off while the shark was busy must still have this long to spare before the step's fallback (seconds).
@export_range(0.0, 1.0, 0.05, "suffix:s") var bite_spare: float = 0.3

@export_group("Captain Cogs' ship")
## DESIGN-TBD (GDD §10: a floating ship flying above the track): its station ahead of the runner and above the roof
## they're climbing to (metres; it keeps pace with them), and its sway across the lanes.
@export_range(15.0, 80.0, 0.5, "suffix:m") var ship_ahead: float = 40.0
@export_range(10.0, 30.0, 0.5, "suffix:m") var ship_height: float = 16.5
@export_range(0.0, 6.0, 0.1, "suffix:m") var ship_sway: float = 1.6


## The tunables of phase 3 and the defeat (the groups "Phase 3" and "The defeat"): nothing in phases 1 and 2 reads them
## (test_mecha_guppy_tunables leaves them to test_mecha_guppy_top's own sweep).
const TOP_TUNABLES: PackedStringArray = ["top_seconds", "level_seconds", "level_ahead", "level_out", "level_keel",
	"top_first", "top_beat", "top_clear", "round_warning", "round_flight", "round_ahead", "round_close", "round_radius",
	"wave_warning", "wave_ahead", "wave_close", "wave_height", "wave_depth", "leap_rise", "leap_hang", "leap_fall",
	"swim_seconds", "riff_after"]


## How far a roof planned in phase `index` stands above the one before (rise in phase 1, phase2_rise after).
func rise_at(index: int) -> float:
	return rise if index <= 0 else phase2_rise


## Phase `index`'s entry of a per-phase list (its last entry for later phases; 0 when empty).
static func per_phase(list: PackedInt32Array, index: int) -> int:
	if list.is_empty():
		return 0
	return list[clampi(index, 0, list.size() - 1)]

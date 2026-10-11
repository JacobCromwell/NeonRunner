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
## fight). Every number here is a placeholder (DESIGN-TBD, docs/questions/e5e.md).
##
## Pace (docs/ARCHITECTURE.md, Bosses: a boss's own numbers in metres must follow the pace): the distances
## marked "at 18 m/s" stand for a time and are multiplied by the run's pace (MovementTuning.pace()), so the
## climb keeps its seconds at the Beach's 23.8 m/s; the fairness margins are written in seconds and turned into
## metres at the run's speed; heights and sizes don't change. The rest of the climb's distances come from the
## movement itself (MechaGuppyClimb: a jump's length, the flip up to a hut, a drop off its end, the fall into
## the floor below, the dash's reach), so they hold at any speed and with any movement tuning.

@export_group("The climb")
## DESIGN-TBD: how far each tiki bar roof stands above the one before (metres). The climbing camera sees a
## roof up to RunCamera.FLOOR_REACH above it, and the hut over a step keeps hut_clearance over the higher roof.
@export_range(1.5, 6.0, 0.1, "suffix:m") var rise: float = 3.0
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
## DESIGN-TBD (GDD §10: phase 2's climb 15-25% faster; proposed: about 20%, by bringing the steps closer
## together): each phase's run on a roof, from landing to the next pads (seconds at run speed), the one stretch
## of a step no fairness margin holds. 1.6 s in phase 1 and 0.6 s in phase 2 make phase 2's climb 19-22%
## faster at 3, 5 and 6 lanes (MechaGuppyClimb.climb_rate). The last entry serves later phases.
@export var roof_seconds: PackedFloat32Array = PackedFloat32Array([1.6, 0.6, 0.6])
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
## DESIGN-TBD (E5e-c builds phase 3): the stub's flat run at the top ends this many seconds after the runner
## reaches the top (MechaGuppy.top_reached; GDD §10: "after the player has dodged for one minute").
@export_range(5.0, 120.0, 1.0, "suffix:s") var top_seconds: float = 60.0

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
## DESIGN-TBD: the volleys a runner dodges, each phase (the last entry serves later phases; phase 3 has none, E5e-c):
## - roof_spots: up to this many spots on a roof's run from the landing to the next hut, nearest first, spot_spacing
##   apart (at 18 m/s): the Floating Head's salvo, landing as the runner gets to each (fewer where a run is short);
## - landing_spots: a spot where riders come down onto the higher roof, dodged by a switch in the air as they drop
##   off the hut's end (on a pier only where it has another lane to switch to; GDD §10: phase 2, more bombs);
## - hut_bombs: bombs on the hut a rider hangs from, which burst on its top (GDD §10, the owner: a rider with the
##   ceiling between them and a bomb isn't hurt by it).
@export var roof_spots: PackedInt32Array = PackedInt32Array([2, 1])
@export var landing_spots: PackedInt32Array = PackedInt32Array([0, 1])
@export var hut_bombs: PackedInt32Array = PackedInt32Array([0, 2])
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
## DESIGN-TBD (GDD §10: a bomb hurts Mecha Guppy when it falls into a stretch it has eaten through, where it is
## clearly exposed and in the line of fire): each step, once a rider is committed (at the hut's deadline), Captain
## Cogs throws at the chasm in front of the higher roof, beside the lanes that lead up on the side with more lanes that
## don't, where Mecha Guppy rises to eat; the bomb comes down this far before that roof's front there (metres; the
## shark's head clear of the roof's face), into its open jaws: a hit. It threatens nobody, so it flies only
## hit_seconds (its circle and whistle as every bomb's): it goes in ahead of the runner, in view, not behind them.
@export_range(6.5, 12.0, 0.25, "suffix:m") var hit_back: float = 6.8
@export_range(0.5, 1.5, 0.05, "suffix:s") var hit_seconds: float = 0.65

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
## When it rises to eat beside the lanes that don't lead up: its surge up through the floor's level, opening (seconds;
## quicker than a bite's: its bomb flies only hit_seconds), and how long its jaws stay open around the bomb's landing.
@export_range(0.15, 1.0, 0.05, "suffix:s") var breach_rise: float = 0.3
@export_range(0.1, 1.5, 0.05, "suffix:s") var breach_hold: float = 0.35

@export_group("Captain Cogs' ship")
## DESIGN-TBD (GDD §10: a floating ship flying above the track): its station ahead of the runner and above the roof
## they're climbing to (metres; it keeps pace with them), and its sway across the lanes.
@export_range(15.0, 80.0, 0.5, "suffix:m") var ship_ahead: float = 40.0
@export_range(10.0, 30.0, 0.5, "suffix:m") var ship_height: float = 16.5
@export_range(0.0, 6.0, 0.1, "suffix:m") var ship_sway: float = 1.6


## The run on a roof in phase `index` (roof_seconds; its last entry for later phases).
func roof_seconds_at(index: int) -> float:
	if roof_seconds.is_empty():
		return 1.0
	return roof_seconds[clampi(index, 0, roof_seconds.size() - 1)]


## Phase `index`'s entry of a per-phase list (its last entry for later phases; 0 when empty).
static func per_phase(list: PackedInt32Array, index: int) -> int:
	if list.is_empty():
		return 0
	return list[clampi(index, 0, list.size() - 1)]

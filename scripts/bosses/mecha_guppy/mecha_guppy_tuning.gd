class_name MechaGuppyTuning
extends Resource
## Mecha Guppy and Captain Cogs' numbers (GDD §10, the Beach's boss; data/bosses/beach_boss_tuning.tres, F6 in
## its fight). Task E5e-b1 builds the climb (phases 1 and 2's gimmick) and its look; the shark, the pirate and
## the bombs are E5e-b2's, phase 3 and the defeat E5e-c's.
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
## over the street). It keeps at least hut_clearance over the higher roof under its end.
@export_range(5.0, 10.0, 0.1, "suffix:m") var hut_height: float = 6.5
## The least room between a hut's underside and the higher roof under its end (metres): a rider hanging from
## the hut and jumping (MovementTuning.jump_height plus their body, visual_size.y, about 2.9 m) keeps clear of
## the roof under them. MechaGuppyClimb raises the hut where hut_height would leave less.
@export_range(2.5, 6.0, 0.05, "suffix:m") var hut_clearance: float = 3.2
## DESIGN-TBD (GDD §10 and the brief: the runner must see which lanes lead up and have time to switch into one,
## all the lane switches needed at the lane-switch time plus a margin, from wherever they could be on the
## hut): the margin, in seconds, beyond the switches, counted from the latest a rider can settle on the hut (one
## who jumped right before the pads, dashing, then the flip up). Every rider gets at least this, a rider who
## didn't jump about a second more.
@export_range(0.2, 2.0, 0.05, "suffix:s") var read_seconds: float = 0.6
## DESIGN-TBD (GDD §10: phase 2's climb 15-25% faster; proposed: about 20%, by bringing the steps closer
## together): each phase's run on a roof, from landing to the next pads (seconds at run speed), the one stretch
## of a step no fairness margin holds. 1.6 s in phase 1 and 0.75 s in phase 2 make phase 2's climb 19-21%
## faster at 3, 5 and 6 lanes (MechaGuppyClimb.climb_rate). The last entry serves later phases.
@export var roof_seconds: PackedFloat32Array = PackedFloat32Array([1.6, 0.75, 0.75])
## DESIGN-TBD: the cue "the roof's lanes that lead up reach further back": how far under the hut's end they
## reach (metres at 18 m/s). The other lanes start where a wrong drop is already past them.
@export_range(2.0, 30.0, 0.5, "suffix:m") var reach_back: float = 10.0
## DESIGN-TBD: the cue "the hut's lanes that lead up run further": how far past the higher roof's front they run
## on (metres at 18 m/s). The other lanes end where a wrong drop misses the roof.
@export_range(1.0, 20.0, 0.5, "suffix:m") var run_on: float = 3.0
## The pad strip across every lane at the end of each roof is longer than the longest jump at the run speed
## (with the dash's reach) by this much (metres), so no runner can jump over it: every runner flips up.
@export_range(0.5, 6.0, 0.25, "suffix:m") var strip_margin: float = 2.0
## The hut starts this far before its pads (metres at 18 m/s): a pad sits under its hut.
@export_range(1.0, 10.0, 0.25, "suffix:m") var hut_lead: float = 3.0
## Mecha Guppy has eaten a roof from this far past its pads (metres): nobody runs there.
@export_range(0.25, 5.0, 0.25, "suffix:m") var edge_margin: float = 1.0
## A wrong drop is dead (or saved by the grapple) this far short of the higher roof's front (metres): it never
## touches it (the front is solid, MechaGuppyStairs).
@export_range(0.0, 3.0, 0.1, "suffix:m") var fall_margin: float = 0.5
## DESIGN-TBD (GDD §10: "one, two or three, alternating"): how many lanes lead up, step after step, on 5 lanes
## or more (3 lanes: one; 4 lanes: no more than two). Every lane count keeps at least one lane that doesn't.
@export var up_counts: PackedInt32Array = PackedInt32Array([1, 2, 3])
## The run on the street before the first pads (seconds at run speed): the fight's entrance.
@export_range(1.0, 10.0, 0.25, "suffix:s") var start_seconds: float = 3.5

@export_group("Phase 3")
## DESIGN-TBD (E5e-c builds phase 3): the stub's flat run at the top ends after this many seconds of its
## pattern (GDD §10: "after the player has dodged for one minute").
@export_range(5.0, 120.0, 1.0, "suffix:s") var top_seconds: float = 60.0

@export_group("Building")
## The climb is built this far ahead of the runner (metres): past the fog's end, so nothing pops in.
@export_range(150.0, 500.0, 10.0, "suffix:m") var build_ahead: float = 270.0
## Visual only: how deep the floor Mecha Guppy has eaten drops away under its orange edge, dark (metres).
@export_range(4.5, 20.0, 0.5, "suffix:m") var bite_depth: float = 9.0


## The run on a roof in phase `index` (roof_seconds; its last entry for later phases).
func roof_seconds_at(index: int) -> float:
	if roof_seconds.is_empty():
		return 1.0
	return roof_seconds[clampi(index, 0, roof_seconds.size() - 1)]

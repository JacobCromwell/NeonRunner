class_name HostileTakeoverTuning
extends Resource
## Hostile Takeover's numbers (GDD §10; data/bosses/corporate_boss_tuning.tres, F6 in its fight). Timings
## are seconds. Distances that stand for a time (marked "at 18 m/s": the carriages, the stomp box's reach
## past the gap, the clear corridors around a coupling, the guards' spacing and the tithe's trail) are
## written for the reference run speed (MovementTuning.REFERENCE_SPEED) and multiplied by the run's pace
## (HostileTakeover.run_pace()), so the fight keeps its seconds at the Corporate zone's 23.4 m/s; a gap is a
## share of a jump at the run speed, like a level's. Sizes, heights and where the gunship and the
## locomotive fly and stand (framing) stay as they are.
## The GDD fixes the train (the Chairman's armored maglev express, run from its rear roof toward the
## locomotive: carriage roofs are the floor, the gaps between carriages are the gaps), the gunship pacing it
## overhead, the Chairman glimpsed in the locomotive's window, and phase 1 (The Board): security cyborgs on
## the roofs, a Tithe Collector skimming credits, partial wall fences along the sound barriers, and a
## glowing red coupling in one lane above each gap, stomped by landing on it while jumping the gap, which
## sends the carriages behind tumbling off the track. Every number here is a placeholder (DESIGN-TBD,
## docs/questions/e5b.md).

@export_group("Train")
## DESIGN-TBD: a carriage's roof between two gaps (at 18 m/s): a gap every 3 s or so, so each carriage has
## room for its guards between the cyborgs' margins from both gaps. Every lap holds a whole number of
## carriages (HostileTakeoverTrain), so this is rounded to fit.
@export_range(30.0, 90.0, 0.5, "suffix:m") var carriage_length: float = 50.0
## DESIGN-TBD: the gap between two carriages, as a share of a full jump at the run speed (a level's gap
## pattern's jump_frac; at most LevelConfig.max_gap_jump_fraction, and short enough that a stomp's bounce
## from the stomp box's near end clears the rest: HostileTakeoverTrain.bounce_clears).
@export_range(0.2, 0.7, 0.01) var gap_jump_fraction: float = 0.5
## The rear carriage's roof before the first gap (at 18 m/s; the entrance plays over it). Less than a
## carriage's length plus its gap.
@export_range(10.0, 80.0, 0.5, "suffix:m") var first_gap: float = 46.0

@export_group("Couplings")
## DESIGN-TBD (GDD §10: "each carriage coupling glows red and sits in one lane above the gap between
## carriages"): every gap's coupling glows red once a phase's first `opening_gaps` gaps are passed (by
## phase: phase 1's guards show up first; a phase's intro and those gaps keep them dark), in a lane of
## its own: never the last one's lane (`coupling_same_lane` off) and at most `coupling_max_shift` lanes
## from it.
@export var opening_gaps: PackedInt32Array = PackedInt32Array([4, 1, 1])
@export_range(1, 5) var coupling_max_shift: int = 2
@export var coupling_same_lane: bool = false
## A coupling lights up for good no later than this long before the runner reaches its gap (a lit one
## further ahead lights as it's laid on the track): seconds, so at any speed.
@export_range(1.0, 8.0, 0.1, "suffix:s") var lit_sight: float = 3.0
## DESIGN-TBD: what counts as landing on it (GDD §10: "the player stomps it by landing on it while
## jumping the gap"): its stomp box spans its lane (`stomp_width_share` of a lane's width) over the whole
## gap and `stomp_before` past the gap's near edge and `stomp_after` past its far one, over the roofs (at
## 18 m/s), up to `stomp_top` above the roofs, so a jump that comes down anywhere over the gap in its lane
## stomps it. A runner who drops off the roof's edge without jumping never reaches its top less the stomp
## tolerance (GameRules.stomp_tolerance), so that's no stomp: they fall.
@export_range(0.6, 1.4, 0.02) var stomp_width_share: float = 1.0
@export_range(0.0, 4.0, 0.1, "suffix:m") var stomp_before: float = 1.0
@export_range(0.0, 4.0, 0.1, "suffix:m") var stomp_after: float = 1.0
@export_range(0.46, 1.2, 0.01, "suffix:m") var stomp_top: float = 0.55
## DESIGN-TBD: a lit coupling's lane is kept clear of the Board's guards from approach_clear before its gap
## (the run-up and the jump) to landing_clear past it (where a stomp's bounce comes down), at 18 m/s.
@export_range(10.0, 60.0, 0.5, "suffix:m") var approach_clear: float = 30.0
@export_range(10.0, 60.0, 0.5, "suffix:m") var landing_clear: float = 24.0

@export_group("The Board")
## DESIGN-TBD (GDD §10: "security cyborgs guard the roofs"): the cyborgs on each carriage, a list taken in
## order and repeated (at most one fewer than the lanes), from carriage `guards_from` on (the rear
## carriages are the entrance's). Two on one carriage stand at least guard_spacing apart (at 18 m/s).
@export var guards: PackedInt32Array = PackedInt32Array([1, 2, 1, 1, 2, 1])
@export_range(0, 6) var guards_from: int = 2
@export_range(4.0, 30.0, 0.5, "suffix:m") var guard_spacing: float = 14.0
## DESIGN-TBD (GDD §10: "a Tithe Collector skims credits"): one on every tithe_every-th carriage from
## tithe_first on, with a trail of tithe_credits credits (each worth tithe_value, tithe_spacing apart at
## 18 m/s) laid on the roof ahead of it as it comes, in its lane, for it to skim (a boss's track carries
## no credits of its own).
@export_range(1, 20) var tithe_every: int = 5
@export_range(0, 20) var tithe_first: int = 3
@export_range(0, 20) var tithe_credits: int = 6
@export_range(1, 100) var tithe_value: int = 5
@export_range(1.0, 8.0, 0.25, "suffix:m") var tithe_spacing: float = 3.0
## DESIGN-TBD (GDD §10: "partial wall fences run along the track's sound barriers"): a partial wall fence
## (the low or the high band, in turn) on wall_fence_share of the carriages from wall_fences_from on, on a
## seeded side, where the level's rules allow one (BossArena.wall_fence_problem); its pulse is the zone's
## (data/tuning/wall_fences.tres at the arena's difficulty).
@export_range(0.0, 1.0, 0.05) var wall_fence_share: float = 0.7
@export_range(0, 10) var wall_fences_from: int = 2

@export_group("Gunship")
## DESIGN-TBD (GDD §10: "a military gunship paces the train overhead"): where it flies, relative to the
## runner (framing, in metres): its stern this far ahead, its belly this high over the roofs, swaying
## sideways by up to gunship_sway over gunship_sway_seconds and bobbing by gunship_bob.
@export_range(5.0, 80.0, 0.5, "suffix:m") var gunship_ahead: float = 22.0
@export_range(7.0, 30.0, 0.25, "suffix:m") var gunship_height: float = 13.5
@export_range(0.0, 6.0, 0.1, "suffix:m") var gunship_sway: float = 2.4
@export_range(2.0, 20.0, 0.5, "suffix:s") var gunship_sway_seconds: float = 9.0
@export_range(0.0, 2.0, 0.05, "suffix:m") var gunship_bob: float = 0.35
## The entrance (phase 1's intro): it sweeps in from behind and above the runner, from this far behind its
## station and this much higher, easing in over the intro.
@export_range(10.0, 120.0, 1.0, "suffix:m") var gunship_enter_behind: float = 70.0
@export_range(0.0, 40.0, 0.5, "suffix:m") var gunship_enter_rise: float = 14.0

@export_group("Locomotive")
## DESIGN-TBD (GDD §10: "the player gets a glimpse of him: in the locomotive's window"): the locomotive
## leads the train this far ahead of the runner (its rear face; framing, in metres): past the guards'
## spawn lead, inside the built track, with the Chairman standing at its rear window.
@export_range(60.0, 220.0, 1.0, "suffix:m") var loco_ahead: float = 150.0

@export_group("Breakaway")
## The carriages behind a stomped coupling break away and tumble off the track (GDD §10), looks only:
## they fall behind at break_recede m/s² and drop at break_drop m/s², each rolling over at break_roll
## rad/s² (turns ease off), from a moment after the stomp (break_delay).
@export_range(0.0, 30.0, 0.5, "suffix:m/s²") var break_recede: float = 9.0
@export_range(0.0, 30.0, 0.5, "suffix:m/s²") var break_drop: float = 5.0
@export_range(0.0, 6.0, 0.1, "suffix:rad/s²") var break_roll: float = 1.2
@export_range(0.0, 0.5, 0.01, "suffix:s") var break_delay: float = 0.06


## How many dark gaps open phase `phase` (the last entry's for any later phase).
func opening_for(phase: int) -> int:
	if opening_gaps.is_empty():
		return 0
	return maxi(opening_gaps[clampi(phase, 0, opening_gaps.size() - 1)], 0)


## The guards on carriage `k` at `lanes` lanes (guards in turn, at most lanes - 1), none before guards_from.
func guards_on(k: int, lanes: int) -> int:
	if guards.is_empty() or k < guards_from:
		return 0
	return clampi(guards[(k - guards_from) % guards.size()], 0, maxi(lanes - 1, 0))


## True if carriage `k` brings a Tithe Collector.
func tithe_on(k: int) -> bool:
	return tithe_every > 0 and k >= tithe_first and (k - tithe_first) % tithe_every == 0

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
## overhead, the Chairman glimpsed in the locomotive's window, phase 1 (The Board: security cyborgs on the
## roofs, a Tithe Collector skimming credits, partial wall fences along the sound barriers, and a glowing
## red coupling in one lane above each gap, stomped by landing on it while jumping the gap, which sends the
## carriages behind tumbling off the track) and phase 2 (The Contract: the gunship strafes the lanes, warned
## by a line and a rising whine, drops a Buzz Overdrive onto the roof ahead, and an armored carriage with
## no roof access blocks the way, ridden over on the gunship's belly from an anti-grav pad). Every number
## here is a placeholder (DESIGN-TBD, docs/questions/e5b.md and OPEN_QUESTIONS items 319-323).

@export_group("Train")
## DESIGN-TBD: a corporate carriage's roof between two gaps (at 18 m/s): a gap every 3 s or so, so each
## carriage has room for its guards between the cyborgs' margins from both gaps. Every lap holds a whole
## number of consists (HostileTakeoverTrain), so the roofs stretch a little to fit; the arena's lap
## (data/bosses/corporate_boss.tres, duration_seconds) is three consists long, so they hardly do.
@export_range(30.0, 90.0, 0.5, "suffix:m") var carriage_length: float = 50.0
## DESIGN-TBD: a military flatcar's roof (at 18 m/s), long enough for the Buzz Overdrive the gunship drops
## onto one in phase 2 (GDD §10: it "cuts a carriage lane"): its whole encounter, from its rev to its
## charge past the runner, needs its lane whole (GDD §9.9, LevelGenerator.cut_problem), so a flatcar
## carries no guards and no wall fence; in phase 1 it brings a Tithe Collector instead.
@export_range(90.0, 220.0, 1.0, "suffix:m") var flatcar_length: float = 130.0
## DESIGN-TBD: the carriages in turn behind the rear roof (0: a corporate carriage, 1: a flatcar),
## repeated along the whole train.
@export var consist: PackedInt32Array = PackedInt32Array([0, 0, 1, 0, 0, 0])
## DESIGN-TBD: the gap between two carriages, as a share of a full jump at the run speed (a level's gap
## pattern's jump_frac; at most LevelConfig.max_gap_jump_fraction, and short enough that a stomp's bounce
## from the stomp box's near end clears the rest: HostileTakeoverTrain.bounce_clears).
@export_range(0.2, 0.7, 0.01) var gap_jump_fraction: float = 0.5
## The rear carriage's roof before the first gap (at 18 m/s; the entrance plays over it). Less than a
## carriage's length plus its gap.
@export_range(10.0, 80.0, 0.5, "suffix:m") var first_gap: float = 46.0

@export_group("Couplings")
## DESIGN-TBD (GDD §10: "each carriage coupling glows red and sits in one lane above the gap between
## carriages"): in a phase that plays The Board, every gap's coupling glows red once its first
## `opening_gaps` gaps are passed (by phase: phase 1's guards show up first; a phase's intro and those
## gaps keep them dark; phase 2 plays The Contract, its couplings dark), in a lane of its own: never the
## last one's lane (`coupling_same_lane` off) and at most `coupling_max_shift` lanes from it.
@export var opening_gaps: PackedInt32Array = PackedInt32Array([2, 1, 1])
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
## DESIGN-TBD (GDD §10: "security cyborgs guard the roofs"): the cyborgs on each corporate carriage, a list
## taken in order and repeated (at most one fewer than the lanes), from carriage `guards_from` on (the rear
## carriages are the entrance's), none on a flatcar (a Tithe Collector's: it weaves toward the lanes with
## the most hazards ahead, so with none on its roof it keeps to the runner's lane, over its trail; and phase
## 2's Buzz Overdrive's). Two on one carriage stand at least guard_spacing apart (at 18 m/s).
@export var guards: PackedInt32Array = PackedInt32Array([1, 2, 1, 1, 2, 1])
@export_range(0, 6) var guards_from: int = 2
@export_range(4.0, 30.0, 0.5, "suffix:m") var guard_spacing: float = 14.0
## DESIGN-TBD (GDD §10: "a Tithe Collector skims credits"): one on every flatcar from carriage
## tithe_first on, coming in the runner's lane, with a trail of tithe_credits credits (each worth
## tithe_value, tithe_spacing apart at 18 m/s) laid on the roof ahead of it as it comes, in its lane, for
## it to skim (a boss's track carries no credits of its own); at most tithe_visits_per_phase in a phase
## (OPEN_QUESTIONS item 321: a player who lets the couplings go by could otherwise farm them without end),
## so a phase drawn out earns nothing more from them.
@export_range(0, 20) var tithe_first: int = 3
@export_range(0, 8) var tithe_visits_per_phase: int = 2
@export_range(0, 20) var tithe_credits: int = 6
@export_range(1, 100) var tithe_value: int = 5
@export_range(1.0, 8.0, 0.25, "suffix:m") var tithe_spacing: float = 3.0
## DESIGN-TBD (GDD §10: "partial wall fences run along the track's sound barriers"): a partial wall fence
## (the low or the high band, in turn) on wall_fence_share of the corporate carriages from wall_fences_from
## on, on a seeded side, where the level's rules allow one (BossArena.wall_fence_problem); its pulse is the
## zone's (data/tuning/wall_fences.tres at the arena's difficulty).
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
## leads the train this far ahead of the runner (its rear face; framing, in metres): at the end of the
## view, near enough through the haze for the Chairman to show at its rear window (the arena's skin keeps
## its fog thinner: data/bosses/corporate_boss_skin.tres), inside the built track.
@export_range(60.0, 220.0, 1.0, "suffix:m") var loco_ahead: float = 125.0

@export_group("The Contract: strafes")
## DESIGN-TBD (GDD §10, phase 2: "the gunship strafes the lanes (a warning line and a rising whine)"): a
## red line lights up along the struck lanes from just behind the runner (strafe_behind) to strafe_length
## ahead (at 18 m/s) with the rising whine for strafe_warning seconds; then the gunship's guns rake each
## line from its far end back toward the runner and past them at rake_speed (at 18 m/s), hurting anyone in
## the lane, on the roof or in the air (leave the lane: a jump doesn't dodge it; the walls are safe). It
## strikes at most strafe_lanes lanes (never more than the lanes less two, never all of them), each next
## to a lane left free, strafe_gap seconds after the last one, never within strafe_clear seconds of the
## Buzz Overdrive's attack or the belly ride, and not while phase 1's guards are still about.
@export_range(0.6, 3.0, 0.05, "suffix:s") var strafe_warning: float = 1.2
@export_range(15.0, 80.0, 1.0, "suffix:m") var strafe_length: float = 40.0
@export_range(0.0, 10.0, 0.5, "suffix:m") var strafe_behind: float = 3.0
@export_range(20.0, 120.0, 1.0, "suffix:m/s") var rake_speed: float = 55.0
@export_range(1, 3) var strafe_lanes: int = 2
@export_range(0.3, 6.0, 0.1, "suffix:s") var strafe_gap: float = 1.0
@export_range(0.0, 4.0, 0.1, "suffix:s") var strafe_clear: float = 0.5

@export_group("The Contract: the drop")
## DESIGN-TBD (GDD §10: the gunship "drops a Buzz Overdrive onto the roof ahead, which cuts a carriage
## lane"): one on each flatcar, its cut planned as a level's (FloorCutPlan at the run speed, without the
## roll that brings it into view: the drop does; LevelGenerator.cut_problem's limits) with its rev, its
## line and its block-then-hold rule (the Buzz Overdrive's own); the gunship flies out over its spot,
## lowers to drop_height and lets it fall (drop_fall seconds) so it lands drop_before seconds before its rev
## starts, moving out and back over drop_move seconds.
@export_range(0.3, 3.0, 0.05, "suffix:s") var drop_before: float = 0.6
@export_range(0.3, 1.5, 0.05, "suffix:s") var drop_fall: float = 0.7
@export_range(6.0, 14.0, 0.25, "suffix:m") var drop_height: float = 9.0
@export_range(0.5, 3.0, 0.1, "suffix:s") var drop_move: float = 1.0

@export_group("The Contract: the ride")
## DESIGN-TBD (GDD §10: "an armored carriage with no roof access blocks the way, so the player takes an
## anti-grav pad and rides the gunship's belly over it (the gunship is the ceiling)"): after each drop, the
## second carriage past the flatcar is armored (armored_height tall: no jump reaches its roof, and its
## front is a solid wall), with a runway of anti-grav pads end to end in every lane before the gap in front
## of it, pad_strip long, its far end pad_before short of the gap (at 18 m/s): longer than any jump, a dash
## in the air included (HostileTakeoverContract.strip_clears), so a runner on the roof can't pass it
## without being flipped up. The gunship comes down over descend_seconds to the ceiling's height, its
## belly's stern ride_rear_margin behind the runner as they reach the pads, and flies on slower than the
## runner, so its nose passes over them landing_after past the armored carriage's far gap (at 18 m/s),
## where they drop back onto the roof; then it climbs back over climb_seconds.
@export_range(1.6, 2.3, 0.05, "suffix:m") var armored_height: float = 2.1
@export_range(4.0, 20.0, 0.5, "suffix:m") var pad_before: float = 9.0
@export_range(8.0, 30.0, 0.5, "suffix:m") var pad_strip: float = 18.0
@export_range(4.0, 25.0, 0.5, "suffix:m") var landing_after: float = 10.0
@export_range(1.0, 8.0, 0.25, "suffix:m") var ride_rear_margin: float = 4.0
@export_range(1.0, 5.0, 0.1, "suffix:s") var descend_seconds: float = 1.8
@export_range(1.0, 5.0, 0.1, "suffix:s") var climb_seconds: float = 1.2
## DESIGN-TBD (phase 2's weak point; GDD §10 names none for it, docs/questions/e5b.md): the gunship's drop
## bay, open and glowing red on its belly during the ride (the empty bay its Buzz Overdrive dropped from):
## a stomp from the ceiling (a jump on the belly that comes back up onto it) is the phase's hit. Its stomp
## box spans the belly's width, bay_length along it, hanging bay_depth below it.
@export_range(2.0, 8.0, 0.25, "suffix:m") var bay_length: float = 4.0
@export_range(0.3, 1.0, 0.05, "suffix:m") var bay_depth: float = 0.55

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


## The consist's kinds (HostileTakeoverTrain.Kind), never empty.
func consist_kinds() -> PackedInt32Array:
	var out := PackedInt32Array()
	for kind: int in consist:
		out.append(clampi(kind, 0, 1))
	if out.is_empty():
		out.append(0)
	return out


## The guards on carriage `k` of kind `kind` at `lanes` lanes (guards in turn, at most lanes - 1): none
## before guards_from and none on a flatcar.
func guards_on(k: int, lanes: int, kind: int = 0) -> int:
	if guards.is_empty() or k < guards_from or kind == HostileTakeoverTrain.Kind.FLATCAR:
		return 0
	return clampi(guards[(k - guards_from) % guards.size()], 0, maxi(lanes - 1, 0))


## True if carriage `k` of kind `kind` brings a Tithe Collector (a flatcar from tithe_first on; the
## Board counts them against tithe_visits_per_phase).
func tithe_on(k: int, kind: int) -> bool:
	return kind == HostileTakeoverTrain.Kind.FLATCAR and k >= tithe_first


## How many lanes a strafe strikes at `lanes` lanes: strafe_lanes, never more than the lanes less two
## (one at three lanes), at least one.
func struck_lanes(lanes: int) -> int:
	return clampi(strafe_lanes, 1, maxi(lanes - 2, 1))

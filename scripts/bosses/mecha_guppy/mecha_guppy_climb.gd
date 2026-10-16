class_name MechaGuppyClimb
extends RefCounted
## The climb's plan (GDD §10, Mecha Guppy and Captain Cogs: phases 1 and 2's gimmick; task E5e-b1): step after
## step, as far as the fight lasts, the same on every attempt. MechaGuppyStairs builds it within sight.
##
## A step k takes the runner from roof k up to roof k+1 (roof 0 is the street the fight starts on):
## - a pad strip across every lane at the end of roof k (pad to pad_end), longer than the longest jump at the run
##   speed with the dash's reach, so every runner flips up (GDD §10: the ceiling is the way up);
## - a tiki hut over roof k from hut_start (its underside hut_y, MechaGuppyTuning.hut_height over roof k), full
##   width until the lanes that don't lead up end;
## - roof k+1, rise higher, ahead under the hut's end: a drop off the hut in a lane that leads up (`up`, a block
##   of neighbouring lanes) lands on it; in any other lane it falls past it into the floor Mecha Guppy has eaten
##   (roof k ends just past its pads, `edge_margin`): a fall, death unless the grapple saves it;
## - the cue (GDD §10, the owner: "either the ceiling lanes that lead up run further than the others, or one or
##   two of the roof's lanes reach further back toward the runner than the others"), alternating step by step:
##   RUN_ON, the hut's lanes that lead up run on past the higher roof's front while the others end short of it;
##   REACH_BACK, every lane of the hut ends together and the higher roof's lanes that lead up reach back under
##   its end while the others start past where a wrong drop falls.
## The lanes that lead up: one on 3 lanes; on 5-6 lanes one, two or three in turn (MechaGuppyTuning.up_counts:
## 1, 2, 3, 1, 3, 2, so a REACH_BACK step has one or two, as the owner put that cue, and the count changes every
## step), at a seeded place, never the same block twice running. One safe place to drop to is enough (GDD §10).
##
## Fairness: every distance comes from the movement (a jump's airtime, the flip up to the hut, the drop off its
## end, the fall into the eaten floor; the run's speed; the dash's reach), so it holds at any speed:
## - the latest a rider settles on the hut (`settle`) is a jump right before the pads, the dash's reach and the
##   flip; from there to the `deadline` (where the lanes that don't lead up end, RUN_ON, or the hut ends,
##   REACH_BACK) there is read_seconds plus every lane switch the farthest lane needs (lanes - 1, at the
##   lane-switch time): a rider anywhere on the hut reaches a lane that leads up in time (margin());
## - the hut is full width up to the deadline, so the narrow-ceiling rule (switches only within the hut's lanes)
##   never holds a rider in a lane that doesn't lead up while there's time;
## - a wrong drop is dead (or saved by the grapple) before it reaches the higher roof's front, even dashing
##   (wrong_reach), so it never meets a face below a roof's top; a drop in a lane that leads up lands on the roof;
## - each roof's pads come after its full width starts, and each hut starts after the one before has ended.
## Phase 2's faster climb (GDD §10: 15-25% faster): its roofs stand higher (MechaGuppyTuning.phase2_rise), the steps
## as long as phase 1's (each roof's run, MechaGuppyTuning.roof_seconds, holds a volley spot and the bait); every margin
## stays.
## The bait's notch (task E5e-b3; GDD §10, the owner: a bomb dodged where the runner's lane runs out falls past the edge
## into Mecha Guppy's jaws): each roof from FIRST_NOTCH on, near its end, has an outer lane eaten from notch_back before
## the next hut (Roof.notch_lane, notch_from) to its end, on a seeded side that has nothing to do with the lanes that
## lead up (so it's no cue to them); MechaGuppyPattern baits Captain Cogs' bombs into it. A roof too short for one (an
## extreme tuning: notch_after) has none.
## Phase 3's step is the `top` (MechaGuppyTop plays phase 3 on it): the last roof runs on, no pads, no hut.
## The floor bite (task E5e-f; GDD §10, the owner, October 11, 2026: Mecha Guppy bites a shark-bite crescent out of the
## floor while the runner is still running on it, before the pads; MechaGuppyCrescent, Roof.bite): roof FIRST_BITE (the
## first tower: its bite comes alone, no volley, no bait) and every other roof from FIRST_NOTCH on (bitten(): the ones a
## REACH_BACK step leads onto, so phase 2's landing spots stay on the others) carry one, planned with the step from that
## roof. It comes where its riders' run begins: a reaction (counted from where they can first switch, Step.free_at: where
## its warning can be read from where they are), every lane switch from the farthest lane to the one it leaves,
## dodge_margin and the dash's reach past there, past their landing, and late enough that Mecha Guppy rises and lunges
## after the hut's deadline, before which its warning never shows (no cue to which lanes lead up). Its side is seeded,
## never three bites running on the same side, and a bitten roof's notch is on that side, so the lane it leaves is never
## the notch's. A bitten roof is as long as its run (roof_run_seconds) or as its bite and then its bait need (_bite_room:
## the crossing back to the notch's lane before the bait locks), so its pads may come later; the same in each phase (a
## full-width bite's room counted too).
## In phase 2 every full_every-th one crosses every lane (_bite_full; MechaGuppyTuning.full_jump_share keeps it jumpable).
## Distances are track distances (metres along the track); heights world heights.

enum Cue { RUN_ON, REACH_BACK }

## Room between a roof's pads and its full width's start, and between one hut's end and the next one's start
## (metres).
const PAD_CLEAR: float = 1.0
const HUT_GAP: float = 2.0
## A roof's lanes that lead up never reach back over the roof before it: they start at least this far past its
## eaten edge (metres).
const MIN_BITE: float = 2.0
## ...and they start at least this far past the latest settle on the hut over them (metres): even the latest flip up
## (a jump right before the pads, dashing) is on the hut before it meets their front, however far reach_back asks.
const TONGUE_CLEAR: float = 2.0
## Far: a roof that runs on (phase 3's top), a lane with no roof.
const FAR: float = 1.0e9
## The most lanes that lead up on a REACH_BACK step (GDD §10, the owner: "one or two of the roof's lanes reach further
## back toward the runner than the others").
const REACH_BACK_MOST: int = 2
## The first roof with a notch (task E5e-b3's review): the bait comes from roof 2 on (the street, roof 0, never has one).
## Roof 1 has the first floor bite alone (task E5e-f's review: one new thing at a time), so the climb's first volley comes
## on roof 3, after the first bait.
const FIRST_NOTCH: int = 2
## The first roof with a floor bite (task E5e-f): roof 1, the first tower, where it comes on its own (no volley, no bait:
## one new mechanic at a time); from FIRST_NOTCH on, every other roof (bitten()). DESIGN-TBD (docs/OPEN_QUESTIONS.md
## item 811): which roofs are bitten, and the volley's place after it.
const FIRST_BITE: int = 1
## A floor bite starts at least this far past where its riders land (metres).
const LAND_CLEAR: float = 2.0
## A full-width bite's jaws have snapped at least this far before the earliest take-off that clears it (metres).
const SNAP_CLEAR: float = 1.0
## A floor bite's warning may begin up to this late (seconds: Mecha Guppy finishing what it was doing, a frame) and still
## leave it time to rise and lunge before its snap.
const WARN_SLACK: float = 0.15


## A tiki bar roof the runner lands on and runs along (roof 0: the street the fight starts on).
class Roof:
	var index: int = 0
	## World height of its top.
	var top: float = 0.0
	## Where it starts in each lane (track distances; its lanes that lead up reach back further, REACH_BACK).
	var starts: PackedFloat32Array = PackedFloat32Array()
	## Where Mecha Guppy has eaten it from (track distance): just past its pads; FAR while it runs on.
	var end: float = FAR
	## The bait's notch (task E5e-b3): its outer lane eaten from notch_from to its end (-1: no notch).
	var notch_lane: int = -1
	var notch_from: float = FAR
	## Mecha Guppy's floor bite on it (task E5e-f), or null.
	var bite: MechaGuppyCrescent = null
	## Phase 3's floor bites on the top (task E5e-g: one each time Mecha Guppy comes back up after a dive), front to back,
	## never overlapping; empty on every other roof.
	var top_bites: Array[MechaGuppyCrescent] = []

	func start_in(lane: int) -> float:
		return starts[clampi(lane, 0, starts.size() - 1)]

	## True if it has a notch.
	func notched() -> bool:
		return notch_lane >= 0

	## Where it ends in `lane`: its end, or its notch's start in the notch's lane.
	func end_in(lane: int) -> float:
		return minf(end, notch_from) if lane == notch_lane else end

	## The notch's side: -1 the left (lane 0), +1 the right; 0 with none.
	func notch_side() -> int:
		if notch_lane < 0:
			return 0
		return -1 if notch_lane == 0 else 1

	## Its earliest start (the front of its lanes that reach back furthest).
	func first_start() -> float:
		var out: float = FAR
		for s: float in starts:
			out = minf(out, s)
		return out

	## Where it's full width: its latest start.
	func full_from() -> float:
		var out: float = -FAR
		for s: float in starts:
			out = maxf(out, s)
		return out

	## True if it's under `lane` at track distance `d` (never in its notch, nor where its floor bite takes the lane once
	## that's warned or eaten: a runner's footprint there not wholly on floor).
	func covers(lane: int, d: float) -> bool:
		if lane < 0 or lane >= starts.size() or d < starts[lane] or d >= end_in(lane):
			return false
		var b: MechaGuppyCrescent = bite_at(d)
		return b == null or b.skipped or not (b.warned or b.eaten) or not b.takes(lane, d)

	## True if it's under `lane` at `d` whatever its floor bite does, warned or not yet (the pickups and the grapple's save
	## keep off where it will be).
	func keeps(lane: int, d: float) -> bool:
		var b: MechaGuppyCrescent = bite_at(d)
		return covers(lane, d) and (b == null or b.skipped or not b.takes(lane, d))

	## Its floor bite over track distance `d` (the climb's, or one of the top's), or null.
	func bite_at(d: float) -> MechaGuppyCrescent:
		return bite_over(d, d)

	## Its floor bite reaching into track distances [`from`, `to`] (the climb's, or the first of the top's that does), or
	## the climb's with none (null without one).
	func bite_over(from: float, to: float) -> MechaGuppyCrescent:
		for b: MechaGuppyCrescent in top_bites:
			if b.from <= to and b.to >= from:
				return b
		return bite


## One step up: roof `index` to roof index + 1.
class Step:
	var index: int = 0
	## The phase it was planned in (its roof run: MechaGuppyTuning.roof_seconds).
	var phase: int = 0
	## Phase 3's top (E5e-c): no pads and no hut; the roof the runner is on runs on.
	var top: bool = false
	## World heights: the floor it starts from (roof index's top), the higher roof's top, the hut's underside.
	var floor_y: float = 0.0
	var top_y: float = 0.0
	var hut_y: float = 0.0
	## The pad strip across every lane (track distances).
	var pad: float = 0.0
	var pad_end: float = 0.0
	## The hut: its start, and where each lane of it ends.
	var hut_start: float = 0.0
	var ends: PackedFloat32Array = PackedFloat32Array()
	## The lanes that lead up: Vector2i(first, last), neighbours.
	var up := Vector2i.ZERO
	var cue: int = Cue.RUN_ON
	## The latest a rider settles on the hut (a jump right before the pads, the dash, the flip).
	var settle: float = 0.0
	## By here a rider must be in a lane that leads up: where the other lanes end (RUN_ON) or the hut ends
	## (REACH_BACK).
	var deadline: float = 0.0
	## Where a rider dropping in a lane that leads up lands on the higher roof (about).
	var land: float = 0.0
	## Where a rider who climbs this step can first switch lanes on (or over) the higher roof: dropping off the hut's
	## end over its full width (RUN_ON), or where it's full width beside a pier (REACH_BACK). Its run to the next pads
	## (MechaGuppyTuning.roof_seconds) counts from here.
	var free_at: float = 0.0

	func leads_up(lane: int) -> bool:
		return lane >= up.x and lane <= up.y

	## The number of lanes that lead up.
	func up_count() -> int:
		return up.y - up.x + 1

	## Where the hut ends furthest (its lanes that lead up, RUN_ON).
	func hut_end() -> float:
		var out: float = -FAR
		for e: float in ends:
			out = maxf(out, e)
		return out

	## The lane that leads up nearest to `lane`.
	func nearest_up(lane: int) -> int:
		return clampi(lane, up.x, up.y)

	## Lane switches from `lane` to the nearest lane that leads up.
	func switches_from(lane: int) -> int:
		return absi(lane - nearest_up(lane))


var lanes: int = 3
## The run's speed (m/s) and pace (MovementTuning.pace()).
var speed: float = 18.0
var pace: float = 1.0
var movement: MovementTuning
var tuning: MechaGuppyTuning
## How far the dash's speed bonus carries a runner beyond their run over its whole length (metres): the most a
## dash adds to a jump, a ride or a fall (PowerupTuning.dash_speed_bonus × dash_duration).
var dash_reach: float = 0.0
var roofs: Array[Roof] = []
var steps: Array[Step] = []
## Seconds of the physics step (Engine.physics_ticks_per_second): the motions are timed frame by frame, as the
## player moves.
var dt: float = 1.0 / 60.0

var _rng := RandomNumberGenerator.new()
var _seed: int = 0
## The floor's lanes (the floor bites' shapes) and a full jump's airtime, worked out once.
var _geo: TrackGeometry
var _jump: float = -1.0


## The climb at `p_lanes` lanes for a run on `p_movement` (its speed and pace), with `p_tuning`'s numbers, the
## dash reaching `p_dash_reach` metres, its random choices from `seed`: roof 0 (the street) and nothing more yet.
static func make(p_movement: MovementTuning, p_tuning: MechaGuppyTuning, p_lanes: int, p_dash_reach: float,
		seed: int) -> MechaGuppyClimb:
	var out := MechaGuppyClimb.new()
	out.movement = p_movement
	out.tuning = p_tuning
	out.lanes = maxi(p_lanes, 2)
	out.speed = maxf(p_movement.run_speed, 1.0)
	out.pace = p_movement.pace()
	out.dash_reach = maxf(p_dash_reach, 0.0)
	out.dt = 1.0 / float(maxi(Engine.physics_ticks_per_second, 1))
	out._seed = seed
	out._geo = TrackGeometry.new(out.lanes, p_movement)
	var street := Roof.new()
	street.index = 0
	street.top = 0.0
	street.starts = out._filled(-FAR)
	out.roofs.append(street)
	return out


## The dash's reach from a run's power-up numbers (PowerupTuning), for make().
static func dash_reach_of(powerups: PowerupTuning) -> float:
	return powerups.dash_speed_bonus * powerups.dash_duration if powerups != null else 0.0


# --- Planning --------------------------------------------------------------------------------------

## Plans the next step in phase `phase` (its roof run), and the roof it leads to; with `top` (phase 3), the top
## instead: the roof the runner is on runs on, and nothing comes after it. `not_before`: its hut starts no nearer
## than this track distance (MechaGuppyStairs plans each step as late as it can, as its hut comes to the edge of
## sight, and never puts anything where the runner can already see: after a phase change brings the next step
## closer, it starts there). Returns the step (the last one again once the top is planned).
func plan_next(phase: int, top: bool = false, not_before: float = -FAR) -> Step:
	if top_planned():
		return steps[-1]
	var k: int = steps.size()
	var from: Roof = roofs[k]
	var step := Step.new()
	step.index = k
	step.phase = phase
	step.floor_y = from.top
	if top:
		step.top = true
		step.top_y = from.top
		step.hut_y = from.top
		step.pad = FAR
		step.pad_end = FAR
		step.hut_start = FAR
		step.deadline = FAR
		step.settle = FAR
		step.land = FAR
		step.free_at = FAR
		step.ends = _filled(FAR)
		step.up = Vector2i(0, lanes - 1)
		from.end = FAR
		steps.append(step)
		return step
	var rise: float = tuning.rise_at(phase)
	step.top_y = from.top + rise
	step.hut_y = from.top + maxf(tuning.hut_height, rise + tuning.hut_clearance)
	# The pads: the run on the roof after landing, past its full width, room for the hut after the last, and never
	# where the runner can already see (not_before).
	var t: MovementTuning = movement
	step.pad = maxf(_pad_for(k), not_before + tuning.hut_lead * pace)
	var jump: float = jump_seconds()
	step.pad_end = step.pad + jump * speed + dash_reach + tuning.strip_margin
	step.hut_start = step.pad - tuning.hut_lead * pace
	from.end = step.pad_end + tuning.edge_margin
	# The floor bite on the roof this step starts from (its side first: a bitten roof's notch is on it).
	from.bite = _plan_bite(from, steps[k - 1], phase) if k > 0 and bitten(k) else null
	_notch(from, step)
	# The latest settle on the hut, and the deadline: the reading margin and every switch the farthest lane needs.
	step.settle = step.pad + jump * speed + dash_reach + flip_seconds(step.hut_y - step.floor_y) * speed
	step.deadline = step.settle + (tuning.read_seconds + (lanes - 1) * t.lane_switch_time) * speed
	step.cue = Cue.RUN_ON if k % 2 == 0 else Cue.REACH_BACK
	step.up = _pick_up(k, step.cue)
	var drop: float = drop_seconds(step.hut_y - step.top_y) * speed
	var next := Roof.new()
	next.index = k + 1
	next.top = step.top_y
	next.end = FAR
	step.ends = PackedFloat32Array()
	var wrong: float = wrong_reach(step)
	match step.cue:
		Cue.RUN_ON:
			var front: float = step.deadline + wrong
			var run_on: float = front + tuning.run_on * pace
			for lane: int in lanes:
				step.ends.append(run_on if step.leads_up(lane) else step.deadline)
			next.starts = _filled(front)
			step.land = run_on + movement.foot_half_depth + drop
			step.free_at = run_on + movement.foot_half_depth
		_:
			# They reach back under the hut's end, but never over the roof before it, and never into a flip up: the
			# latest rider is on the hut before their front (TONGUE_CLEAR past the latest settle).
			var back: float = maxf(maxf(step.deadline - tuning.reach_back * pace, from.end + MIN_BITE),
				step.settle + TONGUE_CLEAR)
			next.starts = PackedFloat32Array()
			for lane: int in lanes:
				step.ends.append(step.deadline)
				next.starts.append(back if step.leads_up(lane) else step.deadline + wrong)
			step.land = step.deadline + movement.foot_half_depth + drop
			step.free_at = next.full_from()
	steps.append(step)
	roofs.append(next)
	return step


## How far past the deadline a wrong drop's body may get before it dies (or the grapple saves it), dashing: the
## drop starts once the rider's footprint has passed the hut's end (MovementTuning.foot_half_depth), falls to fall_death_depth under the floor it came from, and its
## hurtbox reaches half its depth ahead; plus the tuning's fall_margin. The higher roof's front stands at least
## this far past where the lanes that don't lead up end.
func wrong_reach(step: Step) -> float:
	var fall: float = drop_seconds(step.hut_y - step.floor_y + movement.fall_death_depth)
	return movement.foot_half_depth + fall * speed + dash_reach + movement.hurtbox_size.z * 0.5 + tuning.fall_margin


## Where the pads of step `k` (the next one: k == steps.size()) go, nearest: the first `start_seconds` into the
## fight, the others the run on the roof (roof_run_seconds) from where the riders who climbed onto it can first switch
## lanes there, room for the hut after the last one, and past the roof's full width.
func _pad_for(k: int) -> float:
	var from: Roof = roofs[k]
	var pad: float = tuning.start_seconds * speed
	if k > 0:
		var before: Step = steps[k - 1]
		pad = before.free_at + roof_run_seconds() * speed
		pad = maxf(pad, before.hut_end() + HUT_GAP + tuning.hut_lead * pace)
		if bitten(k):
			pad = maxf(pad, _bite_room(k))
	return maxf(pad, from.full_from() + PAD_CLEAR)


## A roof's run (seconds): MechaGuppyTuning.roof_seconds, a lane switch longer for each lane past three (a runner
## crossing to the bait's notch from the far side: MechaGuppyPattern).
func roof_run_seconds() -> float:
	return tuning.roof_seconds + maxf(float(lanes - 3), 0.0) * movement.lane_switch_time


## Roof `roof`'s notch for the bait (see the header), once step `step`, from it, is planned: its outer lane on a seeded
## side, eaten from notch_back before the step's hut to its end; none before FIRST_NOTCH, nor where it would start less
## than notch_after() past where the roof's run begins.
func _notch(roof: Roof, step: Step) -> void:
	roof.notch_lane = -1
	roof.notch_from = FAR
	if roof.index < FIRST_NOTCH or step.top:
		return
	var into: Step = steps[roof.index - 1]
	var at: float = step.hut_start - tuning.notch_back
	var begins: float = maxf(maxf(into.free_at, into.land), roof.full_from())
	if at < begins + notch_after():
		return
	_rng.seed = hash([_seed, "notch", roof.index])
	roof.notch_lane = 0 if _rng.randi() % 2 == 0 else lanes - 1
	# A bitten roof's notch is on its bite's side: the lane the bite leaves is never the notch's (task E5e-f). DESIGN-TBD
	# (docs/OPEN_QUESTIONS.md item 816): the notch moved to the bite's side.
	if roof.bite != null:
		roof.notch_lane = 0 if roof.bite.side < 0 else lanes - 1
	roof.notch_from = at


## How far past where its run begins a roof's notch starts at the least (metres; task E5e-b3's review): a runner who
## lands in the notch's lane, or first switches lanes there, has a reaction (MechaGuppyTuning.dodge_reaction), a lane
## switch and dodge_margin to leave it before its edge. A roof with no room for that has no notch.
func notch_after() -> float:
	return (tuning.dodge_reaction + movement.lane_switch_time + tuning.dodge_margin) * speed


# --- The floor bite (task E5e-f) -------------------------------------------------------------------

## True if roof `index` carries a floor bite (see the header): roof FIRST_BITE, and every other roof from FIRST_NOTCH on
## (the even ones, which REACH_BACK steps lead onto). Never the street. DESIGN-TBD (docs/OPEN_QUESTIONS.md item 811):
## which roofs are bitten (the roofs alternate what they carry).
static func bitten(index: int) -> bool:
	return index == FIRST_BITE or (index >= FIRST_NOTCH and index % 2 == 0)


## A floor bite's crossing (metres): from where a runner can first switch, every lane switch from the farthest lane to the
## one it leaves (lanes - 1, at the lane-switch time) and dodge_margin, their hurtbox's front still short of the bite, even
## dashing on the way (the dash's reach: it brings them there that much sooner; task E5e-f's review, as the climb's other
## margins hold dashing).
func bite_crossing() -> float:
	return (float(lanes - 1) * movement.lane_switch_time + tuning.dodge_margin) * speed + movement.hurtbox_size.z * 0.5 \
		+ dash_reach


## Seconds Mecha Guppy needs from a floor bite's warning to its snap: its rise into its watch beside the roof, its lunge
## (the bites' dive and rise), the hold and the snap.
func bite_chain() -> float:
	return tuning.floor_rise + tuning.bite_dive + tuning.bite_rise + tuning.bite_hold + tuning.bite_snap


## A floor bite's length along the track at the bitten side (metres): floor_bite_length, or a full-width one's
## full_jump_share of a full jump at the run's speed (a normal jump clears it in every lane).
func bite_length(full: bool) -> float:
	return jump_seconds() * speed * tuning.full_jump_share if full else tuning.floor_bite_length


## How far before the runner reaches a floor bite its jaws have snapped (metres): floor_snap_lead at the run's speed, or,
## over a full-width one `length` long, at least SNAP_CLEAR before the earliest take-off that clears it (a jump's length
## short of its end), so nobody is in the air over it as it snaps.
func snap_lead(full: bool, length: float) -> float:
	var lead: float = tuning.floor_snap_lead * speed
	if full:
		lead = maxf(lead, jump_seconds() * speed - length + SNAP_CLEAR)
	return lead


## How long before the runner reaches a floor bite its warning shows (seconds), where the hut's deadline doesn't come later:
## floor_warning, but never less than a reaction and the crossing, nor than Mecha Guppy's rise and lunge before its snap,
## each with WARN_SLACK to spare (so its warning may begin a frame late and still be fair: bite_latest).
func bite_warning_seconds(full: bool, length: float) -> float:
	return maxf(maxf(tuning.floor_warning, tuning.dodge_reaction + WARN_SLACK + bite_crossing() / speed),
		bite_chain() + WARN_SLACK + snap_lead(full, length) / speed)


## Where a floor bite on roof `roof` starts (track distance), full width or not, from the step that led onto it (`into`):
## a reaction and the crossing past where its riders can first switch (Step.free_at), the reaction counted from there,
## where its warning can be read from where they are (task E5e-f's review: from a hut, and dropping off its end, the
## crescent on the roof ahead is a sliver a few pixels high; it reads once they're on that roof's floor where they can
## switch: after a RUN_ON step, as they drop off the hut's lanes that run on; after a REACH_BACK step, where the roof
## widens past its pier), never before the hut's deadline (its warning shows no sooner); past their landing; and late
## enough that Mecha Guppy rises and lunges after the deadline before its snap.
func _bite_front(into: Step, roof: Roof, full: bool) -> float:
	var crossing: float = bite_crossing()
	var front: float = maxf(into.free_at, into.deadline) + (tuning.dodge_reaction + WARN_SLACK) * speed + crossing
	front = maxf(front, maxf(into.land, roof.full_from()) + LAND_CLEAR)
	return maxf(front, into.deadline + (bite_chain() + WARN_SLACK) * speed + snap_lead(full, bite_length(full)))


## True if roof `index`'s floor bite, planned in phase `phase`, crosses every lane (GDD §10, phase 2: "so big that
## sometimes the runner has to jump over the gap"): every full_every-th bitten roof from FIRST_NOTCH on, in phase 2.
func _bite_full(index: int, phase: int) -> bool:
	return phase >= 1 and tuning.full_every > 0 and index >= FIRST_NOTCH and (index >> 1) % tuning.full_every == 0


## The side roof `index`'s floor bite comes from: seeded by its index, but never a third time running on the same side as
## the last two bites (DESIGN-TBD). Nothing to do with the lanes that lead up.
func _bite_side(index: int) -> int:
	_rng.seed = hash([_seed, "bite", index])
	var side: int = -1 if _rng.randi() % 2 == 0 else 1
	var last: Array[int] = []
	for i: int in range(index - 1, 0, -1):
		if roofs[i].bite != null:
			last.append(roofs[i].bite.side)
			if last.size() == 2:
				break
	if last.size() == 2 and last[0] == side and last[1] == side:
		side = -side
	return side


## Roof `roof`'s floor bite (planned with the step from it, in phase `phase`), from the step that led onto it (`into`).
func _plan_bite(roof: Roof, into: Step, phase: int) -> MechaGuppyCrescent:
	var full: bool = _bite_full(roof.index, phase)
	var length: float = bite_length(full)
	var front: float = _bite_front(into, roof, full)
	var bite := MechaGuppyCrescent.make(roof.index, _bite_side(roof.index), front, length, full, tuning.full_through, _geo,
		Vector2(movement.foot_half_width, movement.foot_half_depth))
	bite.snap_at = front - snap_lead(full, length)
	bite.warn_at = maxf(into.deadline, front - bite_warning_seconds(full, length) * speed)
	return bite


## Phase 3's floor bite on the top (task E5e-g; MechaGuppyTop), its warning starting now with the runner at track distance
## `d`: from side `side`, full width or leaving one lane as `full` says, sized as the climb's are, its front where its warning
## gets every promise of the climb's (bite_warning_seconds: a reaction and every switch to the lane it leaves, or the
## shark's rise and lunge before its snap). Added to the top's bites (Roof.top_bites) and returned; null before the top.
func plan_top_bite(d: float, full: bool, side: int) -> MechaGuppyCrescent:
	if not top_planned():
		return null
	var roof: Roof = roofs[-1]
	var length: float = bite_length(full)
	var front: float = maxf(d + bite_warning_seconds(full, length) * speed, roof.full_from() + LAND_CLEAR)
	var bite := MechaGuppyCrescent.make(roof.index, side, front, length, full, tuning.full_through, _geo,
		Vector2(movement.foot_half_width, movement.foot_half_depth))
	bite.snap_at = front - snap_lead(full, length)
	bite.warn_at = d
	roof.top_bites.append(bite)
	return bite


## The latest a floor bite's warning may begin (track distance) and still be fair: Mecha Guppy's rise and lunge before its
## snap, and a reaction and the crossing before the bite from where the runner can switch.
func bite_latest(bite: MechaGuppyCrescent) -> float:
	return minf(bite.snap_at - bite_chain() * speed, bite.from - bite_crossing() - tuning.dodge_reaction * speed)


## The nearest step k's pads may be when its roof carries a floor bite (track distance): room for the bite (full width or
## not: the steps are as long in each phase) and after it, from FIRST_NOTCH on, the bait locking only once the runner is
## past it with a reaction and a switch for every lane but one to reach the notch's lane (MechaGuppyPattern.bait_after; its
## aim never shows beside the bite), lock_seconds and arrival_seconds before it lands catch_in into the notch, notch_back
## short of the hut; on roof FIRST_BITE (its bite alone: no volley, no bait), the bite past by PAD_CLEAR before the hut.
func _bite_room(k: int) -> float:
	var roof: Roof = roofs[k]
	var into: Step = steps[k - 1]
	var end: float = -FAR
	for full: bool in [false, true]:
		end = maxf(end, _bite_front(into, roof, full) + bite_length(full))
	var past: float = end + movement.hurtbox_size.z * 0.5
	var t: MechaGuppyTuning = tuning
	if k >= FIRST_NOTCH:
		var reach: float = maxf(t.dodge_reaction + float(lanes - 1) * movement.lane_switch_time, t.bait_seek) * speed
		var lock: float = past + reach
		return lock + (t.lock_seconds + t.arrival_seconds) * speed - t.catch_in + t.notch_back + t.hut_lead * pace
	return past + PAD_CLEAR + t.hut_lead * pace


## Where the next step's hut would start if it were planned now (in any phase: the steps are as long in each; FAR once
## the top is planned; -FAR for the top itself: it's due at once).
func next_hut_start(_phase: int, top: bool = false) -> float:
	if top_planned():
		return FAR
	if top:
		return -FAR
	return _pad_for(steps.size()) - tuning.hut_lead * pace


## True once phase 3's top is planned: nothing comes after it.
func top_planned() -> bool:
	return not steps.is_empty() and steps[-1].top


## Forgets every step from `index` on and the roofs they led to; roof `index` runs on again until a step is planned
## from it (MechaGuppyStairs re-plans what the runner can't see yet when the phase changes). The steps planned again
## pick the same lanes (each step's choice is seeded by its index).
func truncate(index: int) -> void:
	if index < 0 or index >= steps.size():
		return
	steps.resize(index)
	roofs.resize(index + 1)
	roofs[index].end = FAR
	roofs[index].notch_lane = -1
	roofs[index].notch_from = FAR
	roofs[index].bite = null
	roofs[index].top_bites.clear()


## Plans steps while the climb's furthest planned piece is short of track distance `until` (phase `phase`; the top
## with `top`). Returns how many it planned.
func plan_until(until: float, phase: int, top: bool = false) -> int:
	var count: int = 0
	while planned_until() < until and not top_planned():
		plan_next(phase, top)
		count += 1
		if count > 64:
			break
	return count


## How far the plan reaches: the last roof's front (where the next step's pads will be decided).
func planned_until() -> float:
	if top_planned():
		return FAR
	return roofs[-1].first_start() if roofs.size() > 1 else 0.0


# --- Queries ---------------------------------------------------------------------------------------

## The step the runner at track distance `d` is in: the last whose pads begin at or before `d` (the first step
## before its pads). Null with none planned.
func step_at(d: float) -> Step:
	var i: int = step_index_at(d)
	return steps[i] if i >= 0 else null


## The index of step_at(`d`) (a binary search: the fight's plan grows for as long as it lasts), or -1 with none.
func step_index_at(d: float) -> int:
	if steps.is_empty():
		return -1
	var lo: int = 0
	var hi: int = steps.size() - 1
	if steps[0].pad > d:
		return 0
	while lo < hi:
		var mid: int = (lo + hi + 1) >> 1
		if steps[mid].pad <= d:
			lo = mid
		else:
			hi = mid - 1
	return lo


## The index of the last roof whose first start is at or before track distance `d` (a binary search), or 0.
func roof_index_at(d: float) -> int:
	var lo: int = 0
	var hi: int = roofs.size() - 1
	while lo < hi:
		var mid: int = (lo + hi + 1) >> 1
		if roofs[mid].first_start() <= d:
			lo = mid
		else:
			hi = mid - 1
	return lo


## The roofs under `lane` at track distance `d`, highest first (at most one: each roof starts past where the one
## before was eaten).
func roofs_at(lane: int, d: float) -> Array[Roof]:
	var out: Array[Roof] = []
	var j: int = roof_index_at(d)
	for i: int in range(maxi(j - 1, 0), mini(j + 2, roofs.size())):
		if roofs[i].covers(lane, d):
			out.append(roofs[i])
	out.sort_custom(func(a: Roof, b: Roof) -> bool: return a.top > b.top)
	return out


## The highest roof top under `lane` at `d` no higher than `below` (world height), or NAN with none.
func floor_at(lane: int, d: float, below: float = INF) -> float:
	for r: Roof in roofs_at(lane, d):
		if r.top <= below + 0.001:
			return r.top
	return NAN


## The underside's height of the hut over `lane` at track distance `d`, or NAN with none (MechaGuppyBombs: a bomb on a
## hut bursts on its top).
func hut_at(lane: int, d: float) -> float:
	var k: int = step_index_at(d)
	for i: int in range(maxi(k - 1, 0), mini(k + 2, steps.size())):
		var s: Step = steps[i]
		if not s.top and lane >= 0 and lane < s.ends.size() and d >= s.hut_start and d < s.ends[lane]:
			return s.hut_y
	return NAN


## Seconds of margin a rider settling at the step's latest settle in `lane` has to reach a lane that leads up:
## the time to the deadline less every switch they need at the lane-switch time. At least read_seconds for
## every lane (the plan's promise).
func margin(step: Step, lane: int) -> float:
	return (step.deadline - step.settle) / speed - step.switches_from(lane) * movement.lane_switch_time


## Metres climbed per second over `count` steps planned from scratch in phase `phase` at these lanes and speed
## (for the phases' comparison: GDD §10, phase 2's climb 15-25% faster).
static func climb_rate(p_movement: MovementTuning, p_tuning: MechaGuppyTuning, p_lanes: int, p_dash_reach: float,
		phase: int, count: int = 13) -> float:
	var c: MechaGuppyClimb = make(p_movement, p_tuning, p_lanes, p_dash_reach, 1)
	for i: int in count + 1:
		c.plan_next(phase)
	var a: Step = c.steps[1]
	var b: Step = c.steps[count]
	return (b.floor_y - a.floor_y) / maxf((b.pad - a.pad) / c.speed, 0.001)


# --- Motion, frame by frame, as the player moves -----------------------------------------------------------

## A full jump's airtime from a floor (seconds): the jump's velocity up, gravity, the faster fall.
func jump_seconds() -> float:
	if _jump < 0.0:
		_jump = _surface_seconds(0.0, movement.jump_velocity(), 0.0, true)
	return _jump


## The flip up to a hut `height` over the floor (seconds): the pad's launch toward it, the gravity that pulls a
## rider onto it (Player._flip).
func flip_seconds(height: float) -> float:
	return _surface_seconds(height, -movement.antigrav_launch_velocity, 0.0, false)


## A drop of `height` off a hut's end (seconds): from rest on the hut, the frame that flips the rider to the
## floor (Player._update_vertical: a hair above the hut, a little speed upward) and the fall.
func drop_seconds(height: float) -> float:
	var g: float = movement.gravity()
	var vh: float = g * dt
	var h: float = vh * dt
	return dt + _surface_seconds(height + h, vh, 0.0, false)


## The grapple's save onto a roof (Player._pull_up): lifted to pit_depth under its top and pulled up at `pull` m/s
## (GameRules.grapple_pull_velocity), the seconds until the runner comes back down onto it.
func save_seconds(pull: float) -> float:
	return _surface_seconds(-movement.pit_depth, pull, 0.0, true)


## Seconds for a body `start` above a surface, moving away from it at `vh`, to come back down to `stop` above it
## (Player's integrator: gravity, faster on the way down). `rising_first` waits for it to rise before it may land
## (a jump from the surface itself).
func _surface_seconds(start: float, vh: float, stop: float, rising_first: bool) -> float:
	var g: float = movement.gravity()
	var h: float = start
	var t: float = 0.0
	var risen: bool = not rising_first
	for i: int in 3600:
		var gravity: float = g * (movement.fall_gravity_multiplier if vh < 0.0 else 1.0)
		vh -= gravity * dt
		h += vh * dt
		t += dt
		if h > stop:
			risen = true
		if risen and vh <= 0.0 and h <= stop:
			return t
	return t


# --- Internals -------------------------------------------------------------------------------------

## The lanes that lead up for step `k` (its cue `cue`): as many as up_counts gives this step (one on 3 lanes, up to
## two on 4, three on 5 or more; always at least one lane that doesn't lead up; a REACH_BACK step no more than
## REACH_BACK_MOST: the owner's "one or two of the roof's lanes reach further back"), at a seeded place, never the
## same block as the step before, nor a third time running for the same cue, when there's another.
func _pick_up(k: int, cue: int) -> Vector2i:
	var cap: int = 1 if lanes <= 3 else (2 if lanes == 4 else 3)
	cap = mini(cap, lanes - 1)
	var counts: Array[int] = []
	for c: int in tuning.up_counts:
		if c >= 1 and c <= cap:
			counts.append(c)
	if counts.is_empty():
		counts.append(1)
	var count: int = counts[k % counts.size()]
	if cue == Cue.REACH_BACK:
		count = mini(count, REACH_BACK_MOST)
	var places: int = lanes - count + 1
	_rng.seed = hash([_seed, k])
	# Never the block the step before had; nor, for this cue, the block its last two steps both had (3 lanes: the
	# same lane never leads up on more than two REACH_BACK, or RUN_ON, steps in a row).
	var banned: Array[int] = []
	if k > 0 and steps[k - 1].up.y - steps[k - 1].up.x + 1 == count:
		banned.append(steps[k - 1].up.x)
	if k > 3 and steps[k - 2].up == steps[k - 4].up and steps[k - 2].up.y - steps[k - 2].up.x + 1 == count:
		banned.append(steps[k - 2].up.x)
	var open: Array[int] = []
	for place: int in places:
		if not banned.has(place):
			open.append(place)
	if open.is_empty():
		open.append(_rng.randi_range(0, places - 1))
	var first: int = open[_rng.randi_range(0, open.size() - 1)]
	return Vector2i(first, first + count - 1)


func _filled(value: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(lanes)
	out.fill(value)
	return out

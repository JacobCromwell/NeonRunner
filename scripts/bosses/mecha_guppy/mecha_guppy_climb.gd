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
## Phase 2's faster climb (GDD §10: 15-25% faster; proposed: about 20%, the steps closer together): only the run
## on a roof from landing to the next pads shortens (MechaGuppyTuning.roof_seconds); every margin stays.
## Phase 3 (E5e-c's) is a stub here: its step is the `top`: the last roof runs on, no pads, no hut.
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


## A tiki bar roof the runner lands on and runs along (roof 0: the street the fight starts on).
class Roof:
	var index: int = 0
	## World height of its top.
	var top: float = 0.0
	## Where it starts in each lane (track distances; its lanes that lead up reach back further, REACH_BACK).
	var starts: PackedFloat32Array = PackedFloat32Array()
	## Where Mecha Guppy has eaten it from (track distance): just past its pads; FAR while it runs on.
	var end: float = FAR

	func start_in(lane: int) -> float:
		return starts[clampi(lane, 0, starts.size() - 1)]

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

	## True if it's under `lane` at track distance `d`.
	func covers(lane: int, d: float) -> bool:
		return lane >= 0 and lane < starts.size() and d >= starts[lane] and d < end


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
		step.ends = _filled(FAR)
		step.up = Vector2i(0, lanes - 1)
		from.end = FAR
		steps.append(step)
		return step
	step.top_y = from.top + tuning.rise
	step.hut_y = from.top + maxf(tuning.hut_height, tuning.rise + tuning.hut_clearance)
	# The pads: the run on the roof after landing, past its full width, room for the hut after the last, and never
	# where the runner can already see (not_before).
	var t: MovementTuning = movement
	step.pad = maxf(_pad_for(k, phase), not_before + tuning.hut_lead * pace)
	var jump: float = jump_seconds()
	step.pad_end = step.pad + jump * speed + dash_reach + tuning.strip_margin
	step.hut_start = step.pad - tuning.hut_lead * pace
	from.end = step.pad_end + tuning.edge_margin
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


## Where the pads of step `k` (the next one: k == steps.size()) go in phase `phase`, nearest: the first `start_seconds`
## into the fight, the others the phase's run on the roof after landing (roof_seconds), room for the hut after the
## last one, and past the roof's full width.
func _pad_for(k: int, phase: int) -> float:
	var from: Roof = roofs[k]
	var pad: float = tuning.start_seconds * speed
	if k > 0:
		var before: Step = steps[k - 1]
		pad = before.land + tuning.roof_seconds_at(phase) * speed
		pad = maxf(pad, before.hut_end() + HUT_GAP + tuning.hut_lead * pace)
	return maxf(pad, from.full_from() + PAD_CLEAR)


## Where the next step's hut would start if it were planned now in phase `phase` (FAR once the top is planned;
## -FAR for the top itself: it's due at once).
func next_hut_start(phase: int, top: bool = false) -> float:
	if top_planned():
		return FAR
	if top:
		return -FAR
	return _pad_for(steps.size(), phase) - tuning.hut_lead * pace


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
	return _surface_seconds(0.0, movement.jump_velocity(), 0.0, true)


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

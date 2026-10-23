class_name MazeRoute
extends RefCounted
## The best way through a stretch of a layout whose doodads stop the runner (task O2; the owner, October 20, 2026, GDD
## §5 Zone 8: the debris maze, where "the runner can't get through without dashing" and "a runner who meets a wall of
## debris before the dash is ready stands and waits"). Tests only. A search over lanes and distance (STEP metres a
## step) with the dash's charge: the runner starts in any lane at the stretch's start, with the dash just used (the
## worst case: it comes back `recharge` seconds later), and the search finds the quickest way to its end, waits
## included, the least dashes any way through takes, and whether any way through takes none.
##
## A conservative model of the Player's moves where doodads stop the runner (Player._stop_motion, _lane_blocked), so a
## way it finds is one the real Player can run (test_debris_maze replays them on real physics); it may miss some:
## - running on in a lane where the body (its visual depth, BODY_MARGIN either side) fits between doodads; a doodad
##   ahead stops the runner at its front, standing;
## - switching to the lane beside, running or stopped, only where that lane is clear from SWITCH_BACK behind the body's
##   middle to past where the switch ends (the switch's run, SWITCH_SLACK and the body's half depth): wider than the
##   lane blocker's look the Player makes, so the real switch is never refused, and the body never meets that lane's
##   doodads' sides; it lands in the new lane the switch's run on;
## - a stopped runner moving along the face of what stops them (Player._face_level_in): into the lane beside where the
##   body fits and that lane's doodad ahead has its front level with this one's (FACE_SLACK), staying stopped;
## - the dash only from a stop, when it's ready (else waiting there until it is): it smashes the doodads in the lane
##   whose fronts it reaches (the dash's carry at its speed, less DASH_SLACK), and the runner runs on past what it
##   smashed, to the next doodad's front at the most; it comes back `recharge` seconds after it began;
## - never a jump over a doodad (none is low enough to clear), a lane switch in the air, a pad or a ceiling, a wall; a
##   hole is a place it never stands nor dashes over, but a running runner may jump one just ahead (task O5: the rows
##   between the Terminal's maze blocks; _jump_from) (the maze keeps holes out: LayoutChecks.check_debris_maze), and so is an
##   anti-grav pad (which would lift the runner onto its ceiling: pad_span(), wide enough that a switch out of its lane
##   before it never brushes it; a maze ceiling's pad stands in a cell a floor runner can pass it in).
## Optimistic, for the question whether any way through takes no dash (`dash_free`): running where the body fits, and a
## switch to the lane beside wherever the body fits there at the same spot: more than the Player can do, so where that
## finds no way, there is none.
##   var route := MazeRoute.new(layout, tuning)                 the layout's grid, built once
##   var r: Dictionary = route.find(from, to, recharge)         {ok, seconds, waits, dashes, moves, start_lane, reason}
##   route.least_dashes(from, to)                               the least dashes any way takes (-1: none gets through)
##   route.dash_free(from, to)                                  true if a way through might take no dash at all
## `moves` (find): [{kind: "switch" | "slide" | "dash" | "jump", at, lane, to}] in order: at track distance `at` (the
## body's middle) in `lane`, a switch or a slide into lane `to`, a dash, or a jump (from `at`, its take-off); the runner
## keeps their lane otherwise.

## Metres per step.
const STEP: float = 0.5
## Kept between the body (MovementTuning.visual_size.z) and a doodad along its lane, either side (metres).
const BODY_MARGIN: float = 0.1
## A switch needs the lane it goes to clear from this far behind the body's middle (metres): past the lane blocker's
## reach behind it (Player._lane_blocked: the hurtbox's depth and 0.6 m, halved).
const SWITCH_BACK: float = 0.75
## Clear floor a switch needs past where its run ends (metres), beyond the body's half depth.
const SWITCH_SLACK: float = 0.5
## A doodad ahead in the lane beside whose front is within this of the one stopping the runner is level with it: the
## face of a wall across both lanes (metres; Player.STOP_FACE_SLACK).
const FACE_SLACK: float = 0.05
## What the model takes off the dash's carry (metres): the frame steps, and the dash's first frame (its timer runs down
## before it moves the runner).
const DASH_SLACK: float = 1.0
## Seconds a slide along a wall's face takes in the model (a lane switch's, MovementTuning.lane_switch_time, and some).
const SLIDE_SLACK: float = 0.02
## The most labels (time, dash ready) kept per lane and step.
const FRONT: int = 4
## Seconds a lane switch costs in the model beyond its run: a hair, so of two ways as quick the one with fewer switches
## is taken (no weaving across an open stretch).
const SWITCH_COST: float = 0.001
## Kept off an anti-grav pad either side along its lane (metres): the feet's trigger sensor and a frame's run. Before
## it, half a lane switch's run on top (pad_span): a switch out of its lane started there is past the pad's edge (the
## sensor's and the pad's half widths) by the time it would reach it.
const PAD_MARGIN: float = 0.6

## The longest hole a jump takes in find(), as a share of a full jump at the run speed (LevelConfig.max_gap_jump_fraction):
## the take-off and the landing spread the rest either side.
const JUMP_SHARE: float = 0.8

enum Move { START, RUN, SWITCH, SLIDE, DASH, JUMP }

var layout: LevelLayout
var tuning: MovementTuning
var speed: float = 18.0
var lanes: int = 3
var size: int = 0
## Per lane, the doodads standing in it (every doodad, maze or not, but one smashed already) as Vector2(start, end), in
## order of start.
var pieces: Array = []
## Per lane, its holes as Vector2(start, end): never stood in, and no dash goes over one.
var holes: Array = []
## Per lane, its anti-grav pads' spans (pad_span): like holes.
var pads: Array = []
## free[lane * size + i]: the body fits with its middle at track distance i * STEP.
var free := PackedByteArray()
## Per lane, its doodads' ends in order (next_front(), clear()).
var _ends: Array = []
var _half: float = 0.26
var _switch_steps: int = 7
var _carry: float = 0.0
## A full jump at the run speed (MovementTuning.jump_distance), for find()'s jumps over a hole.
var _jump: float = 0.0
var _bonus: float = 8.0
var _duration: float = 0.6


## The layout's grid (its doodads and holes per lane), for the level's own movement tuning (`p_tuning`: the speed and
## the doodads' sizes it's played at).
func _init(p_layout: LevelLayout, p_tuning: MovementTuning) -> void:
	layout = p_layout
	tuning = p_tuning
	speed = tuning.run_speed
	lanes = layout.lane_count
	size = int(ceil((layout.length + 60.0) / STEP)) + 1
	var pt := load("res://data/tuning/powerups.tres") as PowerupTuning
	if pt != null:
		_bonus = pt.dash_speed_bonus
		_duration = pt.dash_duration
	_carry = (speed + _bonus) * _duration - DASH_SLACK
	_half = tuning.visual_size.z * 0.5
	_jump = tuning.jump_distance(speed)
	_switch_steps = int(ceil(tuning.lane_switch_time * speed / STEP))
	for lane: int in lanes:
		pieces.append([])
		holes.append([])
		pads.append([])
	for d: Dictionary in layout.doodads:
		if not bool(d.get("smashed", false)):
			(pieces[int(d["lane"])] as Array).append(Vector2(float(d["start"]), float(d["end"])))
	for g: Dictionary in layout.gaps:
		(holes[int(g["lane"])] as Array).append(Vector2(float(g["start"]), float(g["end"])))
	for p: Dictionary in layout.pads:
		(pads[int(p["lane"])] as Array).append(pad_span(float(p["at"])))
	var sort := func(a: Vector2, b: Vector2) -> bool: return a.x < b.x
	free.resize(lanes * size)
	free.fill(1)
	for lane: int in lanes:
		(pieces[lane] as Array).sort_custom(sort)
		(holes[lane] as Array).sort_custom(sort)
		var ends := PackedFloat32Array()
		for v: Vector2 in pieces[lane]:
			ends.append(v.y)
		_ends.append(ends)
		var all: Array = (pieces[lane] as Array) + (holes[lane] as Array) + (pads[lane] as Array)
		for v: Vector2 in all:
			# The steps where the body (and its margin) would touch it.
			var lo: int = maxi(int(ceil((v.x - _half - BODY_MARGIN) / STEP)), 0)
			var hi: int = mini(int(floor((v.y + _half + BODY_MARGIN) / STEP)), size - 1)
			for i: int in range(lo, hi + 1):
				free[lane * size + i] = 0


## True if the body fits in `lane` with its middle at step `i`.
func fits(lane: int, i: int) -> bool:
	return lane >= 0 and lane < lanes and i >= 0 and i < size and free[lane * size + i] == 1


## True if `lane` holds no doodad, hole or (with `with_pads`) pad's span reaching into (from, to): one that only touches
## an end doesn't count.
func clear(lane: int, from: float, to: float, with_pads: bool = true) -> bool:
	if lane < 0 or lane >= lanes:
		return false
	var ends: PackedFloat32Array = _ends[lane]
	var k: int = ends.bsearch(from + 0.001, false)
	if k < ends.size() and ((pieces[lane] as Array)[k] as Vector2).x < to - 0.001:
		return false
	var spans: Array = (holes[lane] as Array) + (pads[lane] as Array) if with_pads else holes[lane]
	for v: Vector2 in spans:
		if v.x < to - 0.001 and v.y > from + 0.001:
			return false
	return true


## The stretch of its lane an anti-grav pad from track distance `at` keeps the runner off (Vector2(start, end)): the pad,
## PAD_MARGIN either side, and before it half a lane switch's run more.
func pad_span(at: float) -> Vector2:
	return Vector2(at - PAD_MARGIN - tuning.lane_switch_time * speed * 0.5, at + tuning.pad_length + PAD_MARGIN)


## The furthest the body's middle stands in a pad's lane before the pad from `at` (its span's start, less the body's
## half depth and BODY_MARGIN): from there on, running on in the lane takes the runner onto it.
func pad_reach(at: float) -> float:
	return pad_span(at).x - _half - BODY_MARGIN


## The front of the first doodad in `lane` that the body's front at `front` meets (one starting at or after `front`
## less a hair, or one it's already in), or INF.
func next_front(lane: int, front: float) -> float:
	var ends: PackedFloat32Array = _ends[lane]
	var k: int = ends.bsearch(front - 0.001, false)
	return ((pieces[lane] as Array)[k] as Vector2).x if k < ends.size() else INF


## The quickest way from track distance `from` (any lane where the body fits, the dash coming back `recharge` seconds
## later) to `to` (in lane `goal_lane` only, if it's one), waits for the dash included (see the header). {ok, seconds
## (the quickest), waits (seconds stood waiting for the dash on it), dashes (on it), moves, start_lane, reason (why
## not, if not)}.
func find(from: float, to: float, recharge: float, goal_lane: int = -1) -> Dictionary:
	var first: int = maxi(int(ceil(from / STEP)), 0)
	var goal: int = mini(int(floor(to / STEP)), size - 1)
	# labels[key]: Array of [time, ready, prev key, prev label index, move, move lane, waited, dead], key = lane * size + i.
	var labels: Dictionary = {}
	for lane: int in lanes:
		if fits(lane, first):
			labels[lane * size + first] = [[0.0, recharge, -1, -1, Move.START, lane, 0.0, false]]
	if labels.is_empty():
		return {"ok": false, "reason": "no lane to start in at %.1f" % from, "moves": []}
	var step_t: float = STEP / speed
	for i: int in range(first, goal):
		# A stopped runner moves along the face of what stops them: until nothing changes at this step.
		var changed: bool = true
		var rounds: int = 0
		while changed and rounds < lanes + 1:
			changed = false
			rounds += 1
			for lane: int in lanes:
				var key: int = lane * size + i
				if not labels.has(key) or fits(lane, i + 1):
					continue
				var face: float = next_front(lane, i * STEP + _half)
				for side: int in [-1, 1]:
					var to_lane: int = lane + side
					if not fits(to_lane, i) or fits(to_lane, i + 1):
						continue
					if absf(next_front(to_lane, i * STEP + _half) - face) > FACE_SLACK:
						continue
					var list: Array = labels[key]
					for li: int in list.size():
						var l: Array = list[li]
						if bool(l[7]):
							continue
						var t: float = float(l[0]) + tuning.lane_switch_time + SLIDE_SLACK
						if _relax(labels, to_lane * size + i, [t, maxf(float(l[1]), t), key, li, Move.SLIDE, to_lane, 0.0]):
							changed = true
		for lane: int in lanes:
			var key: int = lane * size + i
			if not labels.has(key):
				continue
			var list: Array = labels[key]
			var blocked: bool = not fits(lane, i + 1)
			var dash: Vector2 = _dash_from(lane, i) if blocked else Vector2(i, 0.0)
			for li: int in list.size():
				var l: Array = list[li]
				if bool(l[7]):
					continue
				var t: float = float(l[0])
				var ready: float = float(l[1])
				if not blocked:
					_relax(labels, lane * size + i + 1, [t + step_t, maxf(ready, t + step_t), key, li, Move.RUN, lane, 0.0])
				for side: int in [-1, 1]:
					var to_lane: int = lane + side
					var land: int = i + _switch_steps
					if land >= size or to_lane < 0 or to_lane >= lanes:
						continue
					if not clear(to_lane, i * STEP - SWITCH_BACK, land * STEP + _half + SWITCH_SLACK):
						continue
					var ts: float = t + _switch_steps * step_t + SWITCH_COST
					_relax(labels, to_lane * size + mini(land, goal), [ts, maxf(ready, ts), key, li, Move.SWITCH, to_lane, 0.0])
				# A hole just ahead (task O5: the rows between the Terminal's maze blocks): a jump over it, running.
				var jump: Vector2 = _jump_from(lane, i) if blocked else Vector2(-1.0, 0.0)
				if jump.x > i:
					var tj: float = t + (minf(jump.x, goal) - i) * step_t
					_relax(labels, lane * size + mini(int(jump.x), goal), [tj, maxf(ready, tj), key, li, Move.JUMP, lane, 0.0])
				if blocked and dash.x > i:
					var start_t: float = maxf(t, ready)
					var run: float = minf(dash.x, goal) * STEP - i * STEP
					var fast: float = minf(run, _carry)
					var te: float = start_t + fast / (speed + _bonus) + (run - fast) / speed
					_relax(labels, lane * size + mini(int(dash.x), goal), [te, maxf(start_t + recharge, te), key, li, Move.DASH, lane,
						start_t - t])
	var best_key: int = -1
	var best_li: int = -1
	var best_t: float = INF
	for lane: int in lanes:
		if goal_lane >= 0 and lane != goal_lane:
			continue
		var key: int = lane * size + goal
		if not labels.has(key):
			continue
		var list: Array = labels[key]
		for li: int in list.size():
			if not bool(list[li][7]) and float(list[li][0]) < best_t:
				best_t = float(list[li][0])
				best_key = key
				best_li = li
	if best_key < 0:
		var furthest: float = 0.0
		for key: int in labels:
			furthest = maxf(furthest, (key % size) * STEP)
		return {"ok": false, "reason": "no way through: got as far as %.1f" % furthest, "moves": []}
	# The way back.
	var moves: Array[Dictionary] = []
	var waits: float = 0.0
	var dashes: int = 0
	var key: int = best_key
	var li: int = best_li
	var start_lane: int = -1
	while key >= 0:
		var l: Array = (labels[key] as Array)[li]
		var move: int = int(l[4])
		var prev_key: int = int(l[2])
		if move == Move.START:
			start_lane = int(l[5])
		elif move == Move.SWITCH or move == Move.SLIDE:
			var from_lane: int = prev_key / size
			moves.push_front({"kind": "switch" if move == Move.SWITCH else "slide", "at": (prev_key % size) * STEP,
				"lane": from_lane, "to": int(l[5])})
		elif move == Move.JUMP:
			moves.push_front({"kind": "jump", "at": _jump_from(int(l[5]), prev_key % size).y, "lane": int(l[5]),
				"to": int(l[5])})
		elif move == Move.DASH:
			moves.push_front({"kind": "dash", "at": (prev_key % size) * STEP, "lane": int(l[5]), "to": int(l[5])})
			waits += float(l[6])
			dashes += 1
		li = int(l[3])
		key = prev_key
	return {"ok": true, "seconds": best_t, "waits": waits, "dashes": dashes, "moves": moves, "start_lane": start_lane,
		"reason": ""}


## Where a dash from a stop at step `i` in `lane` takes the runner: Vector2(the step they run on to, the last doodad's
## end it smashed), or Vector2(i, 0) if no doodad ahead is in its reach. It smashes every doodad in the lane whose front
## it reaches (the carry from the body's front), and the runner runs on past the last of them, to the next one's front
## at the most.
func _dash_from(lane: int, i: int) -> Vector2:
	var middle: float = i * STEP
	var front: float = middle + _half
	var reach: float = front + _carry
	var last_end: float = -INF
	var next: float = INF
	var list: Array = pieces[lane]
	var ends: PackedFloat32Array = _ends[lane]
	for k: int in range(ends.bsearch(front - 0.001, false), list.size()):
		var v: Vector2 = list[k]
		if v.x <= reach:
			last_end = maxf(last_end, v.y)
		else:
			next = v.x
			break
	if last_end == -INF:
		return Vector2(i, 0.0)
	# Past the smashed pieces (the body clear of the last one's end), and at least to where the dash carried them.
	var middle_to: float = maxf(middle + _carry, last_end + _half + BODY_MARGIN)
	middle_to = minf(middle_to, next - _half - BODY_MARGIN)
	# No hole or pad on the way: the dash carries the runner on at speed, never over one.
	for v: Vector2 in (holes[lane] as Array) + (pads[lane] as Array):
		if v.x <= middle_to + _half and v.y >= front:
			return Vector2(i, 0.0)
	return Vector2(maxi(int(floor(middle_to / STEP)), i), last_end)


## Where a jump over the hole just ahead of step `i` in `lane` (the body's front within a step of it, nothing else
## nearer) takes the runner: Vector2(the step it lands at, the body's middle at take-off), or Vector2(-1, 0) if there's
## no such hole, it's longer than JUMP_SHARE of a full jump, or the landing isn't clear floor. The jump is centred on the
## hole: it takes off half the spare jump before it and lands half past it. A runner in the lane there runs straight
## (the rows that need one keep the level's spacing clear around them in every lane: DebrisMaze.place_gaps).
func _jump_from(lane: int, i: int) -> Vector2:
	var front: float = i * STEP + _half
	var hole := Vector2(INF, INF)
	for v: Vector2 in holes[lane]:
		if v.x >= front - 0.001 and v.x <= front + STEP + BODY_MARGIN + 0.001 and v.x < hole.x:
			hole = v
	if hole.x == INF or not clear(lane, front, hole.x, true) or hole.y - hole.x > _jump * JUMP_SHARE:
		return Vector2(-1.0, 0.0)
	var spare: float = (_jump - (hole.y - hole.x)) * 0.5
	var take: float = hole.x - _half - spare
	var land: float = take + _jump
	var land_i: int = int(ceil(land / STEP))
	if land_i >= size or not fits(lane, land_i) or not clear(lane, hole.y + 0.001, land + _half + BODY_MARGIN):
		return Vector2(-1.0, 0.0)
	return Vector2(land_i, take)


## Adds label `l` ([time, ready, prev key, prev label index, move, move lane, waited]) at `key` unless a live one there
## is as quick with the dash as ready; the live ones it beats die (marked, never removed: later labels point back at
## labels by their index), and past FRONT live ones the slowest dies. True if it stays.
static func _relax(labels: Dictionary, key: int, l: Array) -> bool:
	l.append(false)
	if not labels.has(key):
		labels[key] = [l]
		return true
	var list: Array = labels[key]
	for o: Array in list:
		if not bool(o[7]) and float(o[0]) <= float(l[0]) + 0.0001 and float(o[1]) <= float(l[1]) + 0.0001:
			return false
	var live: int = 1
	var slowest: Array = l
	for o: Array in list:
		if bool(o[7]):
			continue
		if float(l[0]) <= float(o[0]) + 0.0001 and float(l[1]) <= float(o[1]) + 0.0001:
			o[7] = true
			continue
		live += 1
		if float(o[0]) > float(slowest[0]):
			slowest = o
	list.append(l)
	if live > FRONT:
		slowest[7] = true
	return not bool(l[7])


## The least dashes any way from `from` to `to` takes, the dash never waited for (the same moves as find(), each dash
## costing one): -1 if none gets through.
func least_dashes(from: float, to: float) -> int:
	var first: int = maxi(int(ceil(from / STEP)), 0)
	var goal: int = mini(int(floor(to / STEP)), size - 1)
	var best := PackedInt32Array()
	best.resize(lanes * size)
	best.fill(1 << 30)
	for lane: int in lanes:
		if fits(lane, first):
			best[lane * size + first] = 0
	for i: int in range(first, goal):
		var changed: bool = true
		var rounds: int = 0
		while changed and rounds < lanes + 1:
			changed = false
			rounds += 1
			for lane: int in lanes:
				var cost: int = best[lane * size + i]
				if cost >= 1 << 30 or fits(lane, i + 1):
					continue
				var face: float = next_front(lane, i * STEP + _half)
				for side: int in [-1, 1]:
					var to_lane: int = lane + side
					if fits(to_lane, i) and not fits(to_lane, i + 1) \
							and absf(next_front(to_lane, i * STEP + _half) - face) <= FACE_SLACK \
							and cost < best[to_lane * size + i]:
						best[to_lane * size + i] = cost
						changed = true
		for lane: int in lanes:
			var cost: int = best[lane * size + i]
			if cost >= 1 << 30:
				continue
			var blocked: bool = not fits(lane, i + 1)
			if not blocked:
				best[lane * size + i + 1] = mini(best[lane * size + i + 1], cost)
			for side: int in [-1, 1]:
				var to_lane: int = lane + side
				var land: int = i + _switch_steps
				if land < size and to_lane >= 0 and to_lane < lanes \
						and clear(to_lane, i * STEP - SWITCH_BACK, land * STEP + _half + SWITCH_SLACK):
					land = mini(land, goal)
					best[to_lane * size + land] = mini(best[to_lane * size + land], cost)
			if blocked:
				var dash: Vector2 = _dash_from(lane, i)
				if dash.x > i:
					var to_step: int = mini(int(dash.x), goal)
					best[lane * size + to_step] = mini(best[lane * size + to_step], cost + 1)
	var out: int = 1 << 30
	for lane: int in lanes:
		out = mini(out, best[lane * size + goal])
	return out if out < 1 << 30 else -1


## True if a way from `from` to `to` might take no dash (the optimistic moves of the header: run where the body fits, a
## switch to the lane beside wherever the body fits there at the same spot).
func dash_free(from: float, to: float) -> bool:
	var first: int = maxi(int(ceil(from / STEP)), 0)
	var goal: int = mini(int(floor(to / STEP)), size - 1)
	var reach := PackedByteArray()
	reach.resize(lanes)
	for lane: int in lanes:
		reach[lane] = 1 if fits(lane, first) else 0
	for i: int in range(first, goal):
		# Across the lanes at this step, wherever the body fits in both.
		for pass_dir: int in [1, -1]:
			for k: int in lanes:
				var lane: int = k if pass_dir == 1 else lanes - 1 - k
				var near: int = lane - pass_dir
				if reach[lane] == 0 and near >= 0 and near < lanes and reach[near] == 1 and fits(lane, i):
					reach[lane] = 1
		var next := PackedByteArray()
		next.resize(lanes)
		var any: bool = false
		for lane: int in lanes:
			if reach[lane] == 1 and fits(lane, i + 1):
				next[lane] = 1
				any = true
		if not any:
			return false
		reach = next
	return true

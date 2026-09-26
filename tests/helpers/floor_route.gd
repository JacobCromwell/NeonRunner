class_name FloorRoute
extends RefCounted
## A way along the floor through a stretch of a layout that never steps on an anti-grav pad (GDD §3:
## the ceiling is never required; the floor route under it is always survivable without the pad).
## Tests only. A conservative model of the player's floor moves at run speed: running, switching one
## lane at a time on the ground, a full jump (over holes, and over full-height fences only where the
## arc clears them), and slides under gapped fences (pressed again to slide on). It never uses a wall,
## a lane switch in the air, coyote time or a jump out of a slide, never steps on a pad, ramp or speed
## pad, treats pulsing fences as always on, and keeps a margin at every edge, so a route it finds is
## one the real Player can run (test_generator replays some on real physics); it may miss some that
## exist. Enemies aren't in it: each keeps to its own fairness rules.
##   var route: Dictionary = FloorRoute.find(layout, tuning, from, to)
##   route: {ok, start_lane, end_lane, actions: [[distance, action]], reason}

## Metres per step of the model.
const STEP: float = 0.5
## Kept between the player's feet and a hole's edge, and between their body and a fence (its depth,
## the hurtbox's, a frame's motion and some slack), and around a trigger they must not set off.
const GAP_MARGIN: float = 0.6
const FENCE_MARGIN: float = 0.9
const TRIGGER_MARGIN: float = 0.6
## Height kept between the feet and a full-height fence's top when jumping it.
const CLEAR_HEIGHT: float = 0.15
## Slides in one go (each press of slide before the last ends keeps the player down).
const MAX_SLIDES: int = 3
## Metres of the layout past `to` the model looks at (a move may end beyond it).
const LOOK_PAST: float = 45.0
## Clear floor a route's start keeps ahead of it (clear_start): room to jump a fence right after.
const START_LEAD: float = 5.0

## Cell kinds (bit flags per lane and step).
const STAND_BAD: int = 1
const SLIDE_BAD: int = 2
const GAPPED: int = 4
const FULL: int = 8

enum Move { START, RUN, LEFT, RIGHT, JUMP, SLIDE }


## A floor route from `from` to `to` (track distances), starting in any lane where the player can
## stand at `from`. See the header for the result.
static func find(layout: LevelLayout, tuning: MovementTuning, from: float, to: float) -> Dictionary:
	var lanes: int = layout.lane_count
	var speed: float = tuning.run_speed
	var goal: int = int(ceil((to - from) / STEP))
	var size: int = goal + int(ceil(LOOK_PAST / STEP)) + 1
	var cells: PackedInt32Array = _cells(layout, tuning, from, size)
	# Prefix sums per lane and kind: sums[(kind * lanes + lane) * (size + 1) + i] counts the cells of
	# that kind among the lane's first i steps.
	var kinds: Array[int] = [STAND_BAD, SLIDE_BAD, GAPPED, FULL]
	var sums := PackedInt32Array()
	sums.resize(kinds.size() * lanes * (size + 1))
	for k: int in kinds.size():
		for lane: int in lanes:
			var base: int = (k * lanes + lane) * (size + 1)
			for i: int in size:
				sums[base + i + 1] = sums[base + i] + (1 if cells[lane * size + i] & kinds[k] else 0)
	# The moves' lengths in steps, and the steps of a jump's arc that clear a full-height fence.
	var jump_steps: int = int(ceil(tuning.jump_distance(speed) / STEP))
	var slide_steps: int = int(floor(tuning.slide_duration * speed / STEP))
	var switch_steps: int = int(ceil(tuning.lane_switch_time * speed / STEP)) + 1
	var clear: Vector2i = _clear_window(tuning, jump_steps)
	var stand: int = 0
	var slide: int = 1
	var gapped: int = 2
	var full: int = 3
	# State lane * size + i: grounded and standing in `lane` at step i. `prev` holds the state it came
	# from, `move` the move (a slide's count in its high bits).
	var reach := PackedByteArray()
	reach.resize(lanes * size)
	var prev := PackedInt32Array()
	prev.resize(lanes * size)
	var move := PackedInt32Array()
	move.resize(lanes * size)
	for lane: int in lanes:
		if _clear(sums, (stand * lanes + lane) * (size + 1), size, 0, 0):
			reach[lane * size] = 1
			move[lane * size] = Move.START
	var found: int = -1
	for i: int in size:
		for lane: int in lanes:
			var here: int = lane * size + i
			if reach[here] == 0:
				continue
			if i >= goal:
				found = here
				break
			var own: int = (stand * lanes + lane) * (size + 1)
			var targets: Array[Vector2i] = []  # (state, move)
			# Run on.
			if _clear(sums, own, size, i + 1, i + 1):
				targets.append(Vector2i(here + 1, Move.RUN))
			# Switch a lane.
			for dir: int in [-1, 1]:
				var other: int = lane + dir
				var j: int = i + switch_steps
				if other < 0 or other >= lanes or j >= size:
					continue
				if _clear(sums, own, size, i, j) and _clear(sums, (stand * lanes + other) * (size + 1), size, i, j):
					targets.append(Vector2i(other * size + j, Move.LEFT if dir < 0 else Move.RIGHT))
			# Jump: nothing gapped in the arc, full fences only where it clears them, then a landing.
			var land: int = i + jump_steps
			var fulls: int = (full * lanes + lane) * (size + 1)
			if land + 2 < size and _clear(sums, (gapped * lanes + lane) * (size + 1), size, i, land) \
					and _clear(sums, fulls, size, i, i + clear.x - 1) and _clear(sums, fulls, size, i + clear.y + 1, land) \
					and _clear(sums, own, size, land, land + 2):
				targets.append(Vector2i(lane * size + land, Move.JUMP))
			# Slide (and slide on): no hole, full fence or trigger, then stand up clear.
			for n: int in range(1, MAX_SLIDES + 1):
				var end: int = i + (n - 1) * (slide_steps - 2) + slide_steps
				if end + 1 >= size or not _clear(sums, (slide * lanes + lane) * (size + 1), size, i, end):
					break
				if _clear(sums, own, size, end, end + 1):
					targets.append(Vector2i(lane * size + end, Move.SLIDE + 16 * n))
			for t: Vector2i in targets:
				if reach[t.x] == 0:
					reach[t.x] = 1
					prev[t.x] = here
					move[t.x] = t.y
		if found >= 0:
			break
	if found < 0:
		return {"ok": false, "reason": _stuck(reach, from, lanes, size), "actions": []}
	# Walk back to the start, collecting the moves.
	var steps: Array[Vector2i] = []  # (step the move starts at, move)
	var at: int = found
	while move[at] != Move.START:
		var before: int = prev[at]
		steps.push_front(Vector2i(before % size, move[at]))
		at = before
	var actions: Array = []
	for s: Vector2i in steps:
		var d: float = from + s.x * STEP
		match s.y % 16:
			Move.LEFT:
				actions.append([d, &"move_left"])
			Move.RIGHT:
				actions.append([d, &"move_right"])
			Move.JUMP:
				actions.append([d, &"jump"])
			Move.SLIDE:
				for k: int in s.y / 16:
					actions.append([d + k * (slide_steps - 2) * STEP, &"slide"])
	return {"ok": true, "start_lane": at / size, "end_lane": found / size, "actions": actions, "reason": ""}


## Where a route may start, at or before `before`: the latest spot inside a clear stretch (every lane
## free to stand in) with enough of it behind to switch across all the lanes (so the player may be
## in any lane there, as after the gap between any two of the generator's patterns) and START_LEAD
## of it ahead (room to take off for whatever comes next). A route started there needs no knowledge
## of how the player got there. `before` itself if there's none within `search` metres.
static func clear_start(layout: LevelLayout, tuning: MovementTuning, before: float, search: float = 400.0) -> float:
	var lanes: int = layout.lane_count
	var from: float = before - search
	var size: int = int(ceil(search / STEP)) + 1
	var cells: PackedInt32Array = _cells(layout, tuning, from, size)
	var sweep: int = int(ceil(((lanes - 1) * tuning.lane_switch_time * tuning.run_speed + 1.0) / STEP))
	var lead: int = int(ceil(START_LEAD / STEP))
	var run: int = 0
	var best: int = -1
	for i: int in size:
		var free: bool = true
		for lane: int in lanes:
			if cells[lane * size + i] & STAND_BAD:
				free = false
				break
		run = run + 1 if free else 0
		if run > sweep + lead:
			best = i - lead
	return from + best * STEP if best >= 0 else before


## Per lane and step from `from` (lane * size + i), the kinds of cell there: STAND_BAD where the
## player can't stand (a hole under the feet, a fence, a trigger), SLIDE_BAD where they can't slide
## (a hole, a full fence, a trigger), GAPPED and FULL where a gapped or full-height fence is near.
static func _cells(layout: LevelLayout, tuning: MovementTuning, from: float, size: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(layout.lane_count * size)
	var marks: Array[Array] = []  # [lane, from, to, flags]
	for g: Dictionary in layout.gaps:
		marks.append([int(g["lane"]), float(g["start"]) - GAP_MARGIN, float(g["end"]) + GAP_MARGIN, STAND_BAD | SLIDE_BAD])
	for f: Dictionary in layout.fences:
		var flags: int = STAND_BAD | GAPPED if String(f["variant"]) == "gapped" else STAND_BAD | SLIDE_BAD | FULL
		marks.append([int(f["lane"]), float(f["at"]) - FENCE_MARGIN, float(f["at"]) + FENCE_MARGIN, flags])
	for p: Dictionary in layout.pads:
		marks.append([int(p["lane"]), float(p["at"]) - TRIGGER_MARGIN,
			float(p["at"]) + tuning.pad_length + TRIGGER_MARGIN, STAND_BAD | SLIDE_BAD])
	for s: Dictionary in layout.speed_pads:
		marks.append([int(s["lane"]), float(s["at"]) - TRIGGER_MARGIN,
			float(s["at"]) + tuning.speed_pad_length + TRIGGER_MARGIN, STAND_BAD | SLIDE_BAD])
	for r: Dictionary in layout.ramps:
		marks.append([layout.outer_lane(int(r["side"])), float(r["at"]) - TRIGGER_MARGIN,
			float(r["at"]) + tuning.ramp_length + TRIGGER_MARGIN, STAND_BAD | SLIDE_BAD])
	for m: Array in marks:
		var lane: int = m[0]
		if lane < 0 or lane >= layout.lane_count:
			continue
		var i0: int = maxi(int(ceil((float(m[1]) - from) / STEP)), 0)
		var i1: int = mini(int(floor((float(m[2]) - from) / STEP)), size - 1)
		for i: int in range(i0, i1 + 1):
			out[lane * size + i] = out[lane * size + i] | int(m[3])
	return out


## True if cells a..b (inclusive, clamped to the lane's `size` steps) of the prefix sums starting at
## `base` are all 0. An empty range is clear.
static func _clear(sums: PackedInt32Array, base: int, size: int, a: int, b: int) -> bool:
	a = maxi(a, 0)
	b = mini(b, size - 1)
	return b < a or sums[base + b + 1] - sums[base + a] == 0


## The steps after takeoff (first, last) where a jump's feet are at least CLEAR_HEIGHT above a
## full-height fence's top, on flat ground (the descent's heavier gravity, as the Player jumps).
static func _clear_window(tuning: MovementTuning, jump_steps: int) -> Vector2i:
	var first: int = -1
	var last: int = -2
	var total: float = tuning.jump_distance(tuning.run_speed)
	for k: int in range(0, jump_steps + 1):
		if jump_height(tuning, clampf(k * STEP / total, 0.0, 1.0)) >= tuning.fence_full_top + CLEAR_HEIGHT:
			if first < 0:
				first = k
			last = k
	if first < 0:
		return Vector2i(jump_steps + 1, jump_steps)  # it clears nothing: no step of the arc may hold one
	return Vector2i(first, last)


## Height of a jump from flat ground at fraction `f` (0–1) of its length.
static func jump_height(tuning: MovementTuning, f: float) -> float:
	var g_up: float = tuning.gravity()
	var g_down: float = g_up * tuning.fall_gravity_multiplier
	var t_up: float = tuning.jump_velocity() / g_up
	var t_down: float = sqrt(2.0 * tuning.jump_height / g_down)
	var t: float = f * (t_up + t_down)
	if t <= t_up:
		return tuning.jump_velocity() * t - 0.5 * g_up * t * t
	var td: float = t - t_up
	return maxf(tuning.jump_height - 0.5 * g_down * td * td, 0.0)


## Where the model got stuck: the furthest distance any lane reached.
static func _stuck(reach: PackedByteArray, from: float, lanes: int, size: int) -> String:
	var furthest: int = -1
	for lane: int in lanes:
		for i: int in range(size - 1, -1, -1):
			if reach[lane * size + i] != 0:
				furthest = maxi(furthest, i)
				break
	if furthest < 0:
		return "no lane to stand in at %.1f m" % from
	return "no way on past %.1f m" % (from + furthest * STEP)

class_name FloorRoute
extends RefCounted
## A way along the floor through a stretch of a layout that never steps on an anti-grav pad (GDD §3:
## the ceiling is never required; the floor route under it is always survivable without the pad).
## Tests only. A conservative model of the player's floor moves at run speed: running, switching one
## lane at a time on the ground, a full jump (over holes, and over full-height fences only where the
## arc clears them), and slides under gapped fences (pressed again to slide on). It never uses a wall,
## a lane switch in the air, coyote time or a jump out of a slide, never steps on a pad, ramp or speed
## pad, treats pulsing fences as always on, keeps out of a zone doodad's lane where it stands (no push,
## and no jump over it: it's too tall), and keeps a margin at every edge, so a route it finds is one the
## real Player can run (test_generator replays some on real physics); it may miss some that exist.
## Enemies aren't in it: each keeps to its own fairness rules.
##   var floor := FloorRoute.new(layout, tuning)      the layout's grid, built once
##   var route: Dictionary = floor.find(from, to)
##   route: {ok, start_lane, end_lane, actions: [[distance, action]], reason, from, to}

## Metres per step of the model.
const STEP: float = 0.5
## Kept between the player's feet and a hole's edge, and between their body and a fence (its depth,
## the hurtbox's, a frame's motion and some slack), and around a trigger they must not set off.
const GAP_MARGIN: float = 0.6
const FENCE_MARGIN: float = 0.9
const TRIGGER_MARGIN: float = 0.6
## Kept off a zone doodad's lane before its front (where its push would start) and after its end.
const DOODAD_MARGIN: float = 1.5
## Height kept between the feet and a full-height fence's top when jumping it.
const CLEAR_HEIGHT: float = 0.15
## Slides in one go (each press of slide before the last ends keeps the player down).
const MAX_SLIDES: int = 3
## Metres of the layout past a route's end the model looks at (a move may end beyond it).
const LOOK_PAST: float = 45.0
## Clear floor a route's start keeps ahead of it (clear_start): room to jump a fence right after.
const START_LEAD: float = 5.0
## Metres around a jump's landing point that must be free to stand in (the frame the feet come down
## in, and a press that lands a frame early or late).
const LANDING_MARGIN: float = 1.0

## Cell kinds (bit flags per lane and step), in the order of their prefix sums.
const STAND_BAD: int = 1
const SLIDE_BAD: int = 2
const GAPPED: int = 4
const FULL: int = 8
const KINDS: Array[int] = [STAND_BAD, SLIDE_BAD, GAPPED, FULL]

enum Move { START, RUN, LEFT, RIGHT, JUMP, SLIDE }

var layout: LevelLayout
var tuning: MovementTuning
var lanes: int = 3
## Steps from track distance 0 to the layout's end (and LOOK_PAST beyond).
var size: int = 0
## cells[lane * size + i]: the kinds of cell at step i of `lane`.
var cells := PackedInt32Array()
## Prefix sums per kind and lane: sums[(k * lanes + lane) * (size + 1) + i] counts the cells of kind
## KINDS[k] among the lane's first i steps.
var sums := PackedInt32Array()

var _jump_steps: int = 0
## Steps after takeoff from which the ground must be free for a jump's landing.
var _land_from: int = 0
var _slide_steps: int = 0
var _switch_steps: int = 0
var _clear: Vector2i


func _init(p_layout: LevelLayout, p_tuning: MovementTuning) -> void:
	layout = p_layout
	tuning = p_tuning
	lanes = layout.lane_count
	size = int(ceil((layout.length + LOOK_PAST) / STEP)) + 1
	_build_cells()
	sums.resize(KINDS.size() * lanes * (size + 1))
	var row: int = size + 1
	for lane: int in lanes:
		var b0: int = lane * row
		var b1: int = (lanes + lane) * row
		var b2: int = (2 * lanes + lane) * row
		var b3: int = (3 * lanes + lane) * row
		var c: int = lane * size
		for i: int in size:
			var cell: int = cells[c + i]
			sums[b0 + i + 1] = sums[b0 + i] + (cell & 1)
			sums[b1 + i + 1] = sums[b1 + i] + ((cell >> 1) & 1)
			sums[b2 + i + 1] = sums[b2 + i] + ((cell >> 2) & 1)
			sums[b3 + i + 1] = sums[b3 + i] + ((cell >> 3) & 1)
	var speed: float = tuning.run_speed
	_jump_steps = int(ceil((tuning.jump_distance(speed) + LANDING_MARGIN) / STEP))
	_land_from = int(floor((tuning.jump_distance(speed) - LANDING_MARGIN) / STEP))
	_slide_steps = int(floor(tuning.slide_duration * speed / STEP))
	_switch_steps = int(ceil(tuning.lane_switch_time * speed / STEP)) + 1
	_clear = _clear_window()


## A floor route from `from` to `to` (track distances), starting in any lane where the player can
## stand at `from`. See the header for the result.
func find(from: float, to: float) -> Dictionary:
	var first: int = maxi(int(ceil(from / STEP)), 0)
	var goal: int = mini(int(ceil(to / STEP)), size - 1)
	var last: int = mini(goal + int(ceil(LOOK_PAST / STEP)), size - 1)
	var span: int = last - first + 1
	var start_d: float = first * STEP
	# State lane * span + (i - first): grounded and standing in `lane` at step i. `prev` holds the
	# state it came from, `move` the move (a slide's count in its high bits).
	var reach := PackedByteArray()
	reach.resize(lanes * span)
	var prev := PackedInt32Array()
	prev.resize(lanes * span)
	var move := PackedInt32Array()
	move.resize(lanes * span)
	for lane: int in lanes:
		if _free(0, lane, first, first):
			reach[lane * span] = 1
			move[lane * span] = Move.START
	var found: int = -1
	# Prefix-sum lookups are inlined below (a function call per check made this ten times slower):
	# steps a..b of a lane are free of a kind when sums[base + b + 1] == sums[base + a].
	var row: int = size + 1
	var slide_reach: int = (MAX_SLIDES - 1) * (_slide_steps - 2) + _slide_steps + 1
	var reach_ahead: int = maxi(_jump_steps, slide_reach)
	for i: int in range(first, last + 1):
		for lane: int in lanes:
			var here: int = lane * span + i - first
			if reach[here] == 0:
				continue
			if i >= goal:
				found = here
				break
			var b_stand: int = lane * row
			# Run on (the simplest way to any spot: it replaces whichever move got there first).
			if i + 1 <= last and sums[b_stand + i + 2] == sums[b_stand + i + 1]:
				reach[here + 1] = 1
				prev[here + 1] = here
				move[here + 1] = Move.RUN
			# Switch a lane: both lanes free to stand in while the player crosses.
			var j: int = i + _switch_steps
			if j <= last and sums[b_stand + j + 1] == sums[b_stand + i]:
				if lane > 0 and sums[b_stand - row + j + 1] == sums[b_stand - row + i]:
					_arrive(reach, prev, move, here - span + j - i, here, Move.LEFT)
				if lane < lanes - 1 and sums[b_stand + row + j + 1] == sums[b_stand + row + i]:
					_arrive(reach, prev, move, here + span + j - i, here, Move.RIGHT)
			# Jumps and slides only matter with something in the lane ahead (running reaches the rest).
			var ahead: int = mini(i + reach_ahead, last)
			if sums[b_stand + ahead + 1] == sums[b_stand + i]:
				continue
			# Jump: nothing gapped in the arc, full fences only where it clears them, then a landing
			# with room around it.
			var land: int = i + _jump_steps
			if land <= last:
				var b_gapped: int = (2 * lanes + lane) * row
				var b_full: int = (3 * lanes + lane) * row
				var c0: int = i + _clear.x - 1
				var c1: int = mini(i + _clear.y + 1, land + 1)
				if sums[b_gapped + land + 1] == sums[b_gapped + i] \
						and (c0 < i or sums[b_full + c0 + 1] == sums[b_full + i]) \
						and sums[b_full + land + 1] == sums[b_full + c1] \
						and sums[b_stand + land + 1] == sums[b_stand + i + _land_from]:
					_arrive(reach, prev, move, here + _jump_steps, here, Move.JUMP)
			# Slide (and slide on): no hole, full fence or trigger, then stand up clear.
			var b_slide: int = (lanes + lane) * row
			for n: int in range(1, MAX_SLIDES + 1):
				var end: int = i + (n - 1) * (_slide_steps - 2) + _slide_steps
				if end + 1 > last or sums[b_slide + end + 1] != sums[b_slide + i]:
					break
				if sums[b_stand + end + 2] == sums[b_stand + end]:
					_arrive(reach, prev, move, here + end - i, here, Move.SLIDE + 16 * n)
		if found >= 0:
			break
	if found < 0:
		return {"ok": false, "reason": _stuck(reach, start_d, span), "actions": [], "from": start_d, "to": to}
	# Walk back to the start, collecting the moves.
	var steps: Array[Vector2i] = []  # (step the move starts at, move)
	var at: int = found
	while move[at] != Move.START:
		var before: int = prev[at]
		steps.push_front(Vector2i(before % span + first, move[at]))
		at = before
	var actions: Array = []
	for s: Vector2i in steps:
		var d: float = s.x * STEP
		match s.y % 16:
			Move.LEFT:
				actions.append([d, &"move_left"])
			Move.RIGHT:
				actions.append([d, &"move_right"])
			Move.JUMP:
				actions.append([d, &"jump"])
			Move.SLIDE:
				for k: int in s.y / 16:
					actions.append([d + k * (_slide_steps - 2) * STEP, &"slide"])
	return {"ok": true, "start_lane": at / span, "end_lane": found / span, "actions": actions, "reason": "",
		"from": start_d, "to": to}


## Where a route may start, at or before `before`: the latest spot inside a clear stretch (every lane
## free to stand in) with enough of it behind to switch across all the lanes (so the player may be
## in any lane there, as after the gap between any two of the generator's patterns) and START_LEAD
## of it ahead (room to take off for whatever comes next). A route started there needs no knowledge
## of how the player got there. `before` itself if there's none within `search` metres.
func clear_start(before: float, search: float = 300.0) -> float:
	var sweep: int = int(ceil(((lanes - 1) * tuning.lane_switch_time * tuning.run_speed + 1.0) / STEP))
	var lead: int = int(ceil(START_LEAD / STEP))
	var top: int = mini(int(floor(before / STEP)) + lead, size - 1)
	var bottom: int = maxi(int(ceil((before - search) / STEP)), 0)
	var run: int = 0
	# Walk back from the latest candidate: a spot qualifies with `lead` free steps from it on and
	# `sweep` free steps before it, i.e. a free run of sweep + lead + 1 steps ending lead after it.
	for i: int in range(top, bottom - 1, -1):
		var free: bool = true
		for lane: int in lanes:
			if cells[lane * size + i] & STAND_BAD:
				free = false
				break
		run = run + 1 if free else 0
		if run > sweep + lead:
			return (i + sweep) * STEP
	return before


func _base(kind: int, lane: int) -> int:
	return (kind * lanes + lane) * (size + 1)


## True if steps a..b (inclusive, clamped to the grid) of `lane` hold no cell of KINDS[kind]. An empty
## range is free.
func _free(kind: int, lane: int, a: int, b: int) -> bool:
	a = maxi(a, 0)
	b = mini(b, size - 1)
	var base: int = _base(kind, lane)
	return b < a or sums[base + b + 1] - sums[base + a] == 0


## The kinds of cell per lane and step: STAND_BAD where the player can't stand (a hole under the feet,
## a fence, a trigger, a zone doodad), SLIDE_BAD where they can't slide (a hole, a full fence, a
## trigger, a doodad), GAPPED and FULL where a gapped or full-height fence is near (and GAPPED where a
## doodad stands: no jump's arc may pass it).
func _build_cells() -> void:
	cells.resize(lanes * size)
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
	for d: Dictionary in layout.doodads:
		# Nowhere to stand or slide, and no jump over it (GAPPED keeps any arc off it).
		marks.append([int(d["lane"]), float(d["start"]) - DOODAD_MARGIN, float(d["end"]) + DOODAD_MARGIN,
			STAND_BAD | SLIDE_BAD | GAPPED])
	for m: Array in marks:
		var lane: int = m[0]
		if lane < 0 or lane >= lanes:
			continue
		var i0: int = maxi(int(ceil(float(m[1]) / STEP)), 0)
		var i1: int = mini(int(floor(float(m[2]) / STEP)), size - 1)
		for i: int in range(i0, i1 + 1):
			cells[lane * size + i] = cells[lane * size + i] | int(m[3])


## The steps after takeoff (first, last) where a jump's feet are at least CLEAR_HEIGHT above a
## full-height fence's top, on flat ground (the descent's heavier gravity, as the Player jumps).
func _clear_window() -> Vector2i:
	var first: int = -1
	var last: int = -2
	var total: float = tuning.jump_distance(tuning.run_speed)
	for k: int in range(0, int(ceil(total / STEP)) + 1):
		if jump_height(tuning, clampf(k * STEP / total, 0.0, 1.0)) >= tuning.fence_full_top + CLEAR_HEIGHT:
			if first < 0:
				first = k
			last = k
	if first < 0:
		return Vector2i(_jump_steps + 1, _jump_steps)  # it clears nothing: no step of the arc may hold one
	return Vector2i(first, last)


## Height of a jump from flat ground at fraction `f` (0–1) of its length.
static func jump_height(p_tuning: MovementTuning, f: float) -> float:
	var g_up: float = p_tuning.gravity()
	var g_down: float = g_up * p_tuning.fall_gravity_multiplier
	var t_up: float = p_tuning.jump_velocity() / g_up
	var t_down: float = sqrt(2.0 * p_tuning.jump_height / g_down)
	var t: float = f * (t_up + t_down)
	if t <= t_up:
		return p_tuning.jump_velocity() * t - 0.5 * g_up * t * t
	var td: float = t - t_up
	return maxf(p_tuning.jump_height - 0.5 * g_down * td * td, 0.0)


static func _arrive(reach: PackedByteArray, prev: PackedInt32Array, move: PackedInt32Array, state: int,
		from_state: int, how: int) -> void:
	if reach[state] != 0:
		return
	reach[state] = 1
	prev[state] = from_state
	move[state] = how


## Where the model got stuck: the furthest distance any lane reached.
func _stuck(reach: PackedByteArray, start_d: float, span: int) -> String:
	var furthest: int = -1
	for lane: int in lanes:
		for i: int in range(span - 1, -1, -1):
			if reach[lane * span + i] != 0:
				furthest = maxi(furthest, i)
				break
	if furthest < 0:
		return "no lane to stand in at %.1f m" % start_d
	return "no way on past %.1f m" % (start_d + furthest * STEP)

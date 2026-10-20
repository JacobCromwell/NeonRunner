class_name FloorRoute
extends RefCounted
## A way along the floor through a stretch of a layout that never steps on an anti-grav pad (GDD §3:
## the ceiling is never required; the floor route under it is always survivable without the pad).
## Tests only. A conservative model of the player's floor moves at run speed: running, switching one
## lane at a time on the ground, a full jump (over holes, and over full-height fences only where the
## arc clears them), and slides under gapped fences (pressed again to slide on). It never uses a wall
## but a wall-run gap's (task J2, LevelLayout.wall_run_gaps: from its outer lane on its lit stretch, a step
## onto the lit wall and a standard wall run across, landing back in that lane past where the run and its
## drop end; an extended wall run's the same from each platform's last stretch), a lane switch in the air, coyote time or a jump out of a slide, never steps on a pad, ramp or speed
## pad, treats pulsing fences as always on, keeps out of a zone doodad's lane where it stands (no jump over it: it's
## too tall; and no push, unless it's made with `pushes`: task L6, a runner who comes into the stretch before its front
## where its push begins, running, landing or ending a slide there, is pushed into the lane on its side, landing there
## past its front), keeps out of a floor cut's lane from where the cut would reach a
## player still in it (FloorCutPlan, keyed to the player's distance: the floor there is whole only
## while the cut is still ahead of them) to past its cause's spot, and keeps a margin at every edge, so
## a route it finds is one the real Player can run (test_generator replays some on real physics); it
## may miss some that exist. Enemies aren't in it: each keeps to its own fairness rules.
##   var floor := FloorRoute.new(layout, tuning)      the layout's grid, built once
##   FloorRoute.new(layout, tuning, true)             with the zone doodads' pushes
##   var route: Dictionary = floor.find(from, to)     (find(from, to, lane): starting in that lane)
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

enum Move { START, RUN, LEFT, RIGHT, JUMP, SLIDE, WALL, PUSH }

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
## Task J2: the states (lane * size + step) a wall run across a wall-run gap may start from (its outer lane on its
## lit stretch, GAP_MARGIN inside it), and the steps from there to where the run and its drop land the runner.
var _wall_starts: Dictionary = {}
var _wall_steps: int = 0
## Task L6, with `pushes`: the zone doodads' pushes, from each state (lane * size + step) a runner in a doodad's lane
## stands at in the stretch before its front where its push begins (DOODAD_MARGIN long, free to stand in with
## pushes) to the state the push lands them at (the lane on its side, the step past its front), each where that lane
## is free from there to the landing.
var _push_to: Dictionary = {}
var _pushes: bool = false
## Task L6, with `pushes`: per lane, each zone doodad's push as a move in the air or a slide meets it, Vector2i(the
## first step of the stretch before its front where its push begins, the lane it pushes into), in order: a jump or a
## slide that comes into that stretch goes on in the lane beside from there (_zone_in).
var _push_zones: Array = []


func _init(p_layout: LevelLayout, p_tuning: MovementTuning, pushes: bool = false) -> void:
	layout = p_layout
	tuning = p_tuning
	_pushes = pushes
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
	var wall_run: float = (tuning.wall_entry_time + tuning.wall_slide_time + WallRunGapPlacement.drop_seconds(tuning)) * speed
	_wall_steps = int(ceil(wall_run / STEP))
	# An extended wall run (the owner, October 19, 2026): from each of its lit walls' outer lane, on its lit stretch and
	# on each platform's last stretch (WallRunGapPlacement.crossings_of).
	for w: Dictionary in layout.wall_run_gaps:
		for side: int in WallRunGapPlacement.sides_of(w):
			var lane: int = layout.outer_lane(side)
			for c: Vector3 in WallRunGapPlacement.crossings_of(w):
				for i: int in range(int(ceil((c.x + GAP_MARGIN) / STEP)), int(floor((c.y - GAP_MARGIN) / STEP)) + 1):
					if i >= 0 and i < size:
						_wall_starts[lane * size + i] = true
	if _pushes:
		_build_pushes()


## A floor route from `from` to `to` (track distances), starting in any lane where the player can
## stand at `from` (or only in `start_lane`, if it's one). See the header for the result.
func find(from: float, to: float, start_lane: int = -1) -> Dictionary:
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
		if (start_lane < 0 or lane == start_lane) and _free(0, lane, first, first):
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
			# Task J2: from a wall-run gap's lit stretch, onto its lit wall and across, landing back in this lane with
			# room around the landing (the side, for the action, in the move's high bits).
			if not _wall_starts.is_empty() and _wall_starts.has(lane * size + i):
				var land_at: int = i + _wall_steps
				var m: int = int(ceil(LANDING_MARGIN / STEP))
				if land_at + m <= last and sums[b_stand + land_at + m + 1] == sums[b_stand + land_at - m]:
					_arrive(reach, prev, move, here + _wall_steps, here, Move.WALL + 16 * (1 if lane > 0 else 0))
			# Task L6: pushed by a zone doodad right ahead in this lane, into the lane on its side.
			if not _push_to.is_empty() and _push_to.has(lane * size + i):
				var pushed: int = _push_to[lane * size + i]
				if pushed % size <= last:
					_arrive(reach, prev, move, (pushed / size) * span + pushed % size - first, here, Move.PUSH)
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
				elif _pushes:
					# Task L6: pushed in the air by a zone doodad ahead in this lane, coming down in the lane beside.
					var z: Vector2i = _zone_in(lane, i, land)
					if z.x >= 0 and _jump_clear(lane, i, z.x - 1, c0, c1) and _jump_clear(z.y, z.x, land, c0, c1) \
							and sums[z.y * row + land + 1] == sums[z.y * row + i + _land_from]:
						_arrive(reach, prev, move, z.y * span + land - first, here, Move.JUMP)
			# Slide (and slide on): no hole, full fence or trigger, then stand up clear.
			var b_slide: int = (lanes + lane) * row
			for n: int in range(1, MAX_SLIDES + 1):
				var end: int = i + (n - 1) * (_slide_steps - 2) + _slide_steps
				if end + 1 > last:
					break
				if sums[b_slide + end + 1] != sums[b_slide + i]:
					# Task L6: pushed mid-slide by a zone doodad ahead in this lane, sliding on in the lane beside.
					var z: Vector2i = _zone_in(lane, i, end) if _pushes else Vector2i(-1, -1)
					if z.x >= 0 and sums[b_slide + z.x] == sums[b_slide + i] \
							and sums[(lanes + z.y) * row + end + 1] == sums[(lanes + z.y) * row + z.x] \
							and sums[z.y * row + end + 2] == sums[z.y * row + end]:
						_arrive(reach, prev, move, z.y * span + end - first, here, Move.SLIDE + 16 * n)
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
			Move.WALL:
				actions.append([d, &"move_right" if s.y / 16 == 1 else &"move_left"])
	return {"ok": true, "start_lane": at / span, "end_lane": found / span, "actions": actions, "reason": "",
		"from": start_d, "to": to}


## Task L6: each zone doodad's push (a row's, at its first front), as _push_to holds them: from each step of the
## stretch before its front where its push begins (DOODAD_MARGIN long; the Player's push starts its lead before it,
## MovementTuning.doodad_push_time at run speed, more than that) to the lane on its side (its `side`, inward by a side
## wall) at the step past its front, where that lane is free to stand in from the one to the other (the generator
## keeps it clear). A treasure stash's walls aren't zone doodads: their own rules keep a runner out (none is pushed
## into its lane).
func _build_pushes() -> void:
	_push_zones.clear()
	for lane: int in lanes:
		_push_zones.append([])
	var seen: Dictionary = {}
	for d: Dictionary in layout.doodads:
		if d.has("stash"):
			continue
		var span: Vector2 = LevelLayout.doodad_extent(d)
		var lane: int = int(d["lane"])
		var key: String = "%d %.2f" % [lane, span.x]
		if seen.has(key):
			continue
		seen[key] = true
		var into: int = lane + int(d["side"])
		var land: int = int(ceil(span.x / STEP)) + 1
		if into < 0 or into >= lanes or land >= size:
			continue
		var zone: int = maxi(int(ceil((span.x - DOODAD_MARGIN) / STEP)), 0)
		(_push_zones[lane] as Array).append(Vector2i(zone, into))
		for at: int in range(zone, int(ceil(span.x / STEP))):
			if _free(0, into, at, land):
				_push_to[lane * size + at] = into * size + land


## The first zone doodad's push (_push_zones) in `lane` whose stretch before its front begins at a step after `a` and
## no later than `b`: Vector2i(that step, the lane it pushes into), or Vector2i(-1, -1).
func _zone_in(lane: int, a: int, b: int) -> Vector2i:
	for z: Vector2i in _push_zones[lane]:
		if z.x > a and z.x <= b:
			return z
	return Vector2i(-1, -1)


## True if a jump's arc from step `i` (its take-off; `c0` and `c1` its clear window's ends, as find() works them out)
## passes over steps `a` to `b` of `lane` (both inside the arc): nothing gapped (a gapped fence, a doodad) and no
## full-height fence outside the clear window.
func _jump_clear(lane: int, a: int, b: int, c0: int, c1: int) -> bool:
	if b < a:
		return true
	var row: int = size + 1
	var b_gapped: int = (2 * lanes + lane) * row
	var b_full: int = (3 * lanes + lane) * row
	if sums[b_gapped + b + 1] != sums[b_gapped + a]:
		return false
	var low: int = mini(c0, b)
	if low >= a and sums[b_full + low + 1] != sums[b_full + a]:
		return false
	var high: int = maxi(c1, a)
	return high > b or sums[b_full + b + 1] == sums[b_full + high]


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
		# Nowhere to stand or slide, and no jump over it (GAPPED keeps any arc off it); a row (task L3) from its first
		# one's front to its last one's end, the space between them too (LevelLayout.doodad_extent). With `pushes` (task
		# L6), a zone doodad's stretch before its front is where its push begins instead (_push_to).
		var span: Vector2 = LevelLayout.doodad_extent(d)
		var before: float = 0.0 if _pushes and not d.has("stash") else DOODAD_MARGIN
		marks.append([int(d["lane"]), span.x - before, span.y + DOODAD_MARGIN, STAND_BAD | SLIDE_BAD | GAPPED])
	for c: Dictionary in layout.cuts:
		# A floor cut's lane is whole until the cut reaches the player (keyed to their distance): out of
		# it from where its front is LevelGenerator.CUT_CONTACT_METRES ahead of them, to past its cause's
		# spot (a hole by then, or its cause).
		var r: float = FloorCutPlan.ratio(c, tuning.run_speed)
		var leave: float = (float(c["end"]) + r * FloorCutPlan.charge_at(c) - LevelGenerator.CUT_CONTACT_METRES) / (1.0 + r)
		marks.append([int(c["lane"]), leave, FloorCutPlan.lane_window(c).y + GAP_MARGIN, STAND_BAD | SLIDE_BAD])
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

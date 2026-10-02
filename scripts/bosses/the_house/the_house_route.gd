class_name TheHouseRoute
extends RefCounted
## The lane routes through The House's attacks (GDD §10; CLAUDE.md fairness rules: every attack has an
## escape, and every button is reachable while dodging the current attack). The machine plans every
## strike of its attacks, its buttons and its jackpot's approach only where find() says a runner who reads
## the warnings can get through: from the lane they're in, starting to move a reaction time after the
## warning shows, through everything on the track ahead (and over every button, in order, in its lane).
## Its bot (tests/helpers/the_house_bot.gd) plays the fight by the same routes, so the tests prove them
## on the real physics at every lane count and speed.
##
## The track ahead as the runner sees it, in lanes and track distances:
## - SOLID: a gold block, a bomb's blast: no being in that lane over [from, to] (the runner's body reaches
##   `body` further either side), and no switching into or out of it there;
## - FENCE: a full-height fence: crossed by a jump, settled in its lane (no switching from jump_before
##   before it to jump_after past it), so nothing solid may stand in that stretch of its lane;
## - GAPPED: a gapped fence, slid under the same way (slide_before, slide_after).
## A lane switch takes `switch_m` of track (the real one times a margin), and the runner is in both lanes
## meanwhile. A waypoint {lane, at} (a button) is reached when the runner is settled in its lane there.
## Distances are discretised every STEP metres; the route is the first found (staying put first, then the
## nearer switches), so the same track always gives the same route.

enum Kind { SOLID, FENCE, GAPPED }

const STEP: float = 0.25
const UNREACHED: int = 1 << 20

var lanes: int = 3
## Track a lane switch takes, with its margin, and the body's reach either side along the track.
var switch_m: float = 3.0
var body: float = 0.55
## Track that must stay clear around a fence to jump it, and around a gapped one to slide under it.
var jump_before: float = 7.0
var jump_after: float = 6.0
var slide_before: float = 8.0
var slide_after: float = 2.0


## A route finder for a run at `speed` m/s on `p_lanes` lanes, with The House's margins.
static func for_run(p_lanes: int, speed: float, movement: MovementTuning, house: TheHouseTuning) -> TheHouseRoute:
	var r := TheHouseRoute.new()
	r.lanes = maxi(p_lanes, 1)
	var v: float = maxf(speed, 1.0)
	r.switch_m = v * movement.lane_switch_time * house.switch_margin + 0.3
	r.body = movement.hurtbox_size.z * 0.5 + house.body_margin
	var jump: float = movement.jump_distance(v)
	# A jump crosses a full fence when taken from about 0.55 of a jump before it; it lands about 0.45 of a
	# jump past it (with room either side for an early or a late one).
	r.jump_before = jump * 0.62
	r.jump_after = jump * 0.5
	r.slide_before = v * movement.slide_duration * 0.85
	r.slide_after = 1.5
	return r


## An obstacle entry for find().
static func obstacle(lane: int, from: float, to: float, kind: Kind = Kind.SOLID) -> Dictionary:
	return {"lane": lane, "from": minf(from, to), "to": maxf(from, to), "kind": kind}


## A route for a runner in `start_lane` at `d0`, who can first move at `act_at`, to `d_end`, through
## `obstacles` (obstacle()) and over `waypoints` ({lane, at}, in any order). Returns {ok, moves: [{at,
## from, to}] (each switch's start), lane_at: Callable(d) -> int (the lane settled in, or heading for, at
## track distance d), end_lane}; ok false when there is none.
func find(start_lane: int, d0: float, act_at: float, d_end: float, obstacles: Array, waypoints: Array = []) -> Dictionary:
	var none := {"ok": false, "moves": [], "end_lane": -1}
	if d_end <= d0:
		return {"ok": true, "moves": [], "end_lane": start_lane}
	var n: int = ceili((d_end - d0) / STEP) + 1
	# Every per-step array is flat, step * lanes + lane (fast in GDScript; the solver runs as attacks
	# are revealed and buttons planned, within a frame).
	var blocked := PackedByteArray()
	blocked.resize(n * lanes)
	blocked.fill(0)
	var no_switch := PackedByteArray()
	no_switch.resize(n * lanes)
	no_switch.fill(0)
	# Solids first: a fence is only crossable where no solid stands in its jump.
	for o: Dictionary in obstacles:
		if int(o["kind"]) != Kind.SOLID:
			continue
		var l: int = int(o["lane"])
		if l < 0 or l >= lanes:
			continue
		_mark(blocked, l, d0, float(o["from"]) - body, float(o["to"]) + body, n)
		_mark(no_switch, l, d0, float(o["from"]) - body, float(o["to"]) + body, n)
	for o: Dictionary in obstacles:
		var kind: int = int(o["kind"])
		if kind == Kind.SOLID:
			continue
		var l: int = int(o["lane"])
		if l < 0 or l >= lanes:
			continue
		var before: float = jump_before if kind == Kind.FENCE else slide_before
		var after: float = jump_after if kind == Kind.FENCE else slide_after
		var from: float = float(o["from"]) - before
		var to: float = float(o["to"]) + after
		if _any(blocked, l, d0, from, to, n):
			# Something solid in the jump (or the slide): the fence can't be crossed in this lane.
			_mark(blocked, l, d0, float(o["from"]) - body, float(o["to"]) + body, n)
		_mark(no_switch, l, d0, from, to, n)
	var act: int = clampi(ceili((act_at - d0) / STEP), 0, n - 1)
	var k: int = maxi(ceili(switch_m / STEP), 1)
	# The buttons: button_lane[i] is the lane of the one at step i, or -1.
	var button_lane := PackedInt32Array()
	button_lane.resize(n)
	button_lane.fill(-1)
	for w: Dictionary in waypoints:
		button_lane[clampi(roundi((float(w["at"]) - d0) / STEP), 0, n - 1)] = int(w["lane"])
	# A switch's whole span is checked at once, by counts from the start: no_switch steps in each lane
	# (no_switch_before[i * lanes + l]: in steps 0 to i - 1), and buttons (buttons_before[i]).
	var no_switch_before := PackedInt32Array()
	no_switch_before.resize((n + 1) * lanes)
	no_switch_before.fill(0)
	var buttons_before := PackedInt32Array()
	buttons_before.resize(n + 1)
	buttons_before[0] = 0
	for i: int in n:
		var row: int = i * lanes
		for l: int in lanes:
			no_switch_before[row + lanes + l] = no_switch_before[row + l] + no_switch[row + l]
		buttons_before[i + 1] = buttons_before[i] + (1 if button_lane[i] >= 0 else 0)
	# The fewest switches to be settled in each lane at each step (cost), and where it came from (parent:
	# prev_step * 16 + prev_lane; -2 marks the start). Of two ways with as few switches, the one that
	# switched earlier wins: the route moves out of a lane as soon as it can, and never zigzags.
	var cost := PackedInt32Array()
	cost.resize(n * lanes)
	cost.fill(UNREACHED)
	var parent := PackedInt32Array()
	parent.resize(n * lanes)
	parent.fill(-1)
	if start_lane < 0 or start_lane >= lanes or blocked[start_lane] != 0:
		return none
	cost[start_lane] = 0
	parent[start_lane] = -2
	for i: int in n:
		var row: int = i * lanes
		var keep: int = button_lane[i]
		if keep >= 0:
			for l: int in lanes:
				if l != keep:
					cost[row + l] = UNREACHED
		if i == n - 1:
			break
		var next: int = row + lanes
		var j: int = i + k
		var land: int = j * lanes
		# A switch starting here spans steps i to j. Settled in a button's lane as it passes over it, no
		# switch starts there or spans it; one landing on a button lands in its lane.
		var can_switch: bool = i >= act and j < n and buttons_before[j] == buttons_before[i]
		var land_lane: int = button_lane[j] if j < n else -1
		for l: int in lanes:
			var c: int = cost[row + l]
			if c >= UNREACHED:
				continue
			# Stay in the lane: on a tie with a later switch into it, staying wins (its switch came earlier).
			if blocked[next + l] == 0 and (c < cost[next + l] or (c == cost[next + l] and parent[next + l] % 16 != l)):
				cost[next + l] = c
				parent[next + l] = i * 16 + l
			if not can_switch or no_switch_before[land + lanes + l] != no_switch_before[row + l]:
				continue
			# Switch to a neighbouring lane over the next k steps (both lanes clear meanwhile).
			for l2: int in range(l - 1, l + 2, 2):
				if l2 < 0 or l2 >= lanes or c + 1 >= cost[land + l2] or blocked[land + l2] != 0:
					continue
				if no_switch_before[land + lanes + l2] != no_switch_before[row + l2]:
					continue
				if land_lane >= 0 and land_lane != l2:
					continue
				cost[land + l2] = c + 1
				parent[land + l2] = i * 16 + l
	# The route ends in the lane reached with the fewest switches (then the nearest the start lane).
	var last: int = (n - 1) * lanes
	var end_lane: int = -1
	for dist: int in lanes:
		for s: int in [-1, 1]:
			var l: int = start_lane + s * dist
			if l < 0 or l >= lanes or cost[last + l] >= UNREACHED:
				continue
			if end_lane < 0 or cost[last + l] < cost[last + end_lane]:
				end_lane = l
	if end_lane < 0:
		return none
	var moves: Array[Dictionary] = []
	var i: int = n - 1
	var lane: int = end_lane
	while parent[i * lanes + lane] >= 0:
		var code: int = parent[i * lanes + lane]
		var pi: int = code / 16
		var pl: int = code % 16
		if pl != lane:
			moves.push_front({"at": d0 + pi * STEP, "from": pl, "to": lane})
		i = pi
		lane = pl
	return {"ok": true, "moves": moves, "end_lane": end_lane}


## The lane a route (find()) has the runner in at track distance `d`: the start lane, changed by each
## move from where it starts.
static func lane_at(route: Dictionary, start_lane: int, d: float) -> int:
	var lane: int = start_lane
	for m: Dictionary in route.get("moves", []):
		if float(m["at"]) <= d:
			lane = int(m["to"])
	return lane


func _mark(arr: PackedByteArray, lane: int, d0: float, from: float, to: float, n: int) -> void:
	var i0: int = maxi(floori((from - d0) / STEP), 0)
	var i1: int = mini(ceili((to - d0) / STEP), n - 1)
	for i: int in range(i0, i1 + 1):
		arr[i * lanes + lane] = 1


func _any(arr: PackedByteArray, lane: int, d0: float, from: float, to: float, n: int) -> bool:
	var i0: int = maxi(floori((from - d0) / STEP), 0)
	var i1: int = mini(ceili((to - d0) / STEP), n - 1)
	for i: int in range(i0, i1 + 1):
		if arr[i * lanes + lane] != 0:
			return true
	return false

class_name SleepTakerHands
extends Node3D
## The Sleep Taker's grasping hands (GDD §10: "grasping hands rising from the floor: purple mist pools in
## the lane, with whispering. Switch lanes"; owner, October 8, 2026: "the hands spread out": one round
## rises at several distances along the street, so the runner makes several lane switches in a row to
## get through it, and "the walls aren't safe": the hands attack the walls much more often). Task H9.
## - a round (plan()): rows of hands hand_row_seconds apart along the street (SleepTakerTuning, at run
##   speed and divided by the phase's pace), its first row where the runner will be once its mist has
##   shown mist_seconds and its hand has been up hand_rise_lead, or a moment further on where the street
##   has no room there (FIRST_SHIFTS: its mists warn longer). Each row leaves its door open
##   (hand_row_open floor lanes): the first door one lane over from the runner's lane, each next one
##   lane over from the last, so every row stands in the lane the runner kept free at the row before:
##   it makes them switch lanes, row after row. A hand stands in every other floor lane whose floor is
##   clear around it (a hole is there instead where it isn't), and wall_hands_per_row reach in from the
##   walls, alternating (never beside a door in an outer lane, never at a wall gap, and only over an
##   outer lane that has a hand of its own, so no runner on the floor ever passes under one). The first
##   round has hand_rows_first rows, each next one a row more, up to hand_rows_max, kept across phases;
##   a round takes only the rows that are over before the next refuge's slash or lure, and waits
##   rather than come with fewer than hand_rows_min;
## - the warning: as a round starts, purple mist pools where each of its hands will rise (on the floor,
##   or on its wall), with whispering (sleep_taker_whisper, once a round). The mist is the nightmare's
##   own purple (never a hazard colour) and drawn unshaded, so it reads as well in the dark of lights
##   out. A floor mist counts as a floor warning (BossProps.floor_warning): pickups keep off it;
## - each hand bursts up out of its mist (sleep_taker_hand, once a row) as the runner comes within
##   hand_rise_lead of it, its claws heating to enemy-attack red, and grasps: an enemy attack (armor or a
##   shield blocks it, the dash passes through) a little smaller than the hand, from the floor to
##   hand_height (above a jump's reach), or on a wall from hand_wall_height's reach inward (a wall
##   runner's height, above a grounded floor runner). Once the runner is past it, it lingers a moment,
##   then sinks back as the mist fades;
## - fairness: a round comes only at a runner on the floor, under no ceiling, with no pickup in the way,
##   and only where a runner who moves route_reaction seconds after its mists show has a way through
##   every row and the street around it (route_from: The House's lane router, TheHouseRoute, with the
##   real lane switch time and margins, holes and fences jumped or slid under with no switch during one).
##   Its doors are picked from a seeded order (the fight's seed and the round's number), so every attempt
##   plays the same way.
## Hands are pooled (the most a round can have at the lane count and a row more, for the round before's last
## row still sinking, SleepTakerTuning.pool_hands: rigs of the hand, its mist and its rising wisps), drawn
## by sleep_taker_hand.gdshader and sleep_taker_mist.gdshader.

enum Stage { MIST, RISE, UP, SINK }

## How long the mist takes to pool, and a sinking hand to go.
const POOL_SECONDS: float = 0.4
const SINK_SECONDS: float = 0.45
## The hand reaches its full grasp this long after it's up.
const GRASP_SECONDS: float = 0.35
## How much of the mist is left once the hand is up (it drew the rest up into itself; less purple
## glow around its red claws, which would otherwise bloom pink over them).
const MIST_LEFT: float = 0.6
## A hand's attack is over once the runner is this far past it (then the next may come; metres at
## 18 m/s, times the run's pace).
const PASSED: float = 1.0
## Ways through a round checked with the router at most, each time plan() runs (its costliest part: the
## next try takes the doors in another seeded order).
const MAX_ROUTE_TRIES: int = 3
## Where a round's first row may stand: where the runner will be once its mist has shown mist_seconds and
## its hand has been up hand_rise_lead, or this much later (seconds at run speed), its mists warning that
## much longer, the first of these where the street ahead has room for a fair round (owner, October 10,
## 2026: more hands, more often, on an arena with three times the holes, where the nearest spot is often
## a hole's).
const FIRST_SHIFTS: Array[float] = [0.0, 0.35, 0.7]

var boss: SleepTaker
## Hands at work: {n, round, row, lane, side, door, at (track distance), stage, t, rig, marker}.
var active: Array[Dictionary] = []
## The round in play (plan()'s, with its rows), or {} before the first.
var round_plan: Dictionary = {}
## Hands started so far.
var count: int = 0
## Rounds started so far, kept across phase changes (each next round has a row more).
var rounds: int = 0

var _free: Array[Dictionary] = []
var _rigs: int = 0
## plan() calls since the last round started that stopped at MAX_ROUTE_TRIES (each next one takes the
## doors in another seeded order).
var _attempts: int = 0
## The rows whose hands' burst has sounded (round * 100 + row).
var _sounded: Dictionary = {}


func setup(p_boss: SleepTaker) -> void:
	boss = p_boss
	name = "Hands"
	top_level = true
	for i: int in maxi(boss.tuning.pool_hands(boss.lane_count()), 1):
		_free.append(_make_rig(i))
	_rigs = _free.size()


## How many hands the pool holds.
func pool_size() -> int:
	return _rigs


# --- Planning a round ------------------------------------------------------------------------------

## A fair round for the runner now: {lane, d, at (its first row), path (the doors, from the runner's
## lane), rows: [{at, door, open, spots: [{lane, side}]}], count, route}, or {} while no fair round can
## start (or while a round is still on: one at a time). `budget`: seconds the round may last, until the
## runner is past its last row (it takes the rows that fit).
func plan(budget: float = INF) -> Dictionary:
	var world: RunWorld = boss.world
	var p: Player = world.player
	if not p.alive or p.surface != Player.Surface.FLOOR or p.in_pit or busy():
		return {}
	var t: SleepTakerTuning = boss.tuning
	var n: int = boss.lane_count()
	if n < 2:
		return {}
	var k: float = boss.run_pace()
	var v: float = maxf(p.speed, 1.0)
	var d: float = p.distance
	var lane: int = clampi(p.lane, 0, n - 1)
	var spacing: float = row_spacing(v)
	var most: int = t.rows_for(rounds + 1)
	var fewest: int = clampi(t.hand_rows_min, 1, most)
	# The street ahead, read once: its pieces in reach of the latest round it may plan as the router's
	# obstacles.
	var latest: float = d + v * (warning_seconds() + FIRST_SHIFTS[-1])
	var reach: float = latest + (most - 1) * spacing + over_distance() + v * 0.25
	var track: Array = []
	_track_obstacles(track, d - 20.0, reach + 20.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([boss.rng.seed, "hands", rounds, _attempts])
	var side: int = -1 if rounds % 2 == 0 else 1
	var tries: int = 0
	for shift: float in FIRST_SHIFTS:
		var first: float = d + v * (warning_seconds() + shift)
		var rows: int = most
		while rows >= fewest and (first + (rows - 1) * spacing + over_distance() - d) / v > budget:
			rows -= 1
		if rows < fewest:
			return {}
		# Where each row's hands fit.
		var fits: Dictionary = _fit_table(track, first, spacing, rows)
		for m: int in range(rows, fewest - 1, -1):
			var last: float = first + (m - 1) * spacing
			if boss.ceiling_between(d, last + t.hand_clear_after * k):
				continue
			for path: Array in doors(lane, m, n, rng):
				var round: Dictionary = _round_for(path, first, spacing, side, fits)
				if round.is_empty() or int(round["count"]) > _free.size():
					continue
				var route: Dictionary = route_from(lane, d, d + v * t.route_reaction, round["rows"], track)
				if bool(route["ok"]):
					round["lane"] = lane
					round["d"] = d
					round["at"] = first
					round["route"] = route
					return round
				tries += 1
				if tries >= MAX_ROUTE_TRIES:
					_attempts += 1
					return {}
	return {}


## Where a round's hands fit (hand_fits, wall_fits) for its rows from `first`, `spacing` apart, given the
## street's pieces around them (`track`: _track_obstacles'): {floor: [row → PackedByteArray by lane],
## wall: [row → {-1: bool, 1: bool}]}.
func _fit_table(track: Array, first: float, spacing: float, rows: int) -> Dictionary:
	var n: int = boss.lane_count()
	var floor_rows: Array = []
	var wall_rows: Array = []
	for i: int in rows:
		var at: float = first + i * spacing
		var lanes := PackedByteArray()
		lanes.resize(n)
		for lane: int in n:
			lanes[lane] = 1 if hand_fits(lane, at, track) else 0
		floor_rows.append(lanes)
		wall_rows.append({-1: wall_fits(-1, at), 1: wall_fits(1, at)})
	return {"floor": floor_rows, "wall": wall_rows}


## Every way of `rows` doors from `lane` at `n` lanes, each one lane over from the one before (the lane
## the runner is in first), in a seeded order: [[lane, door 1, door 2, ...], ...].
static func doors(lane: int, rows: int, n: int, rng: RandomNumberGenerator) -> Array:
	var out: Array = [[lane]]
	for i: int in rows:
		var next: Array = []
		for path: Array in out:
			for s: int in [-1, 1]:
				var l: int = int(path[-1]) + s
				if l >= 0 and l < n:
					next.append(path + [l])
		out = next
	for i: int in range(out.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: Array = out[i]
		out[i] = out[j]
		out[j] = swap
	return out


## The round along `path` (doors(): the runner's lane, then each row's door): {path, rows, count}, or {}
## if a row's hand in the lane the runner must leave can't stand (its floor isn't clear, or a pickup
## lies there). `side` is the wall its first row's wall hand reaches from (they alternate); `fits` is
## _fit_table's for its rows.
func _round_for(path: Array, first: float, spacing: float, side: int, fits: Dictionary) -> Dictionary:
	var t: SleepTakerTuning = boss.tuning
	var n: int = boss.lane_count()
	var rows: Array[Dictionary] = []
	var total: int = 0
	for i: int in range(1, path.size()):
		var at: float = first + (i - 1) * spacing
		var door: int = int(path[i])
		var leave: int = int(path[i - 1])
		var open: Array[int] = open_lanes(door, leave, n, t.hand_row_open)
		var fit: PackedByteArray = (fits["floor"] as Array)[i - 1]
		var spots: Array[Dictionary] = []
		var floors: Array[int] = []
		for lane: int in n:
			if open.has(lane):
				continue
			if fit[lane] == 0:
				if lane == leave:
					return {}
				continue
			spots.append({"lane": lane, "side": 0})
			floors.append(lane)
		var row_side: int = side if i % 2 == 1 else -side
		var walls: int = 0
		for s: int in [row_side, -row_side]:
			if walls >= clampi(t.wall_hands_per_row, 0, 2):
				break
			var outer: int = 0 if s < 0 else n - 1
			if open.has(outer) or not floors.has(outer) or not bool(((fits["wall"] as Array)[i - 1] as Dictionary)[s]):
				continue
			spots.append({"lane": outer, "side": s})
			walls += 1
		rows.append({"at": at, "door": door, "open": open, "spots": spots})
		total += spots.size()
	return {"path": path, "rows": rows, "count": total}


## A row's open lanes: its door, and as many more as `open` asks (the nearest to the door, on the side
## away from `leave` first), never `leave` (the lane the row makes the runner leave).
static func open_lanes(door: int, leave: int, n: int, open: int) -> Array[int]:
	var out: Array[int] = [door]
	var away: int = 1 if door >= leave else -1
	for dist: int in range(1, n):
		for s: int in [away, -away]:
			if out.size() >= clampi(open, 1, n - 1):
				return out
			var l: int = door + s * dist
			if l >= 0 and l < n and l != leave:
				out.append(l)
	return out


## True if a floor hand can rise in `lane` at track distance `at`: its floor clear of holes, fences and
## doodads hand_clear_before it to hand_clear_after past it (at the run's pace), and no pickup there.
## `track`: the street's pieces as _track_obstacles gives them (read from the arena when empty).
func hand_fits(lane: int, at: float, track: Array = []) -> bool:
	var t: SleepTakerTuning = boss.tuning
	var k: float = boss.run_pace()
	var from: float = at - t.hand_clear_before * k
	var to: float = at + t.hand_clear_after * k
	if boss.pickup_near(lane, at, t.mist_length):
		return false
	var pieces: Array = track
	if pieces.is_empty():
		pieces = []
		_track_obstacles(pieces, from - 1.0, to + 1.0)
	for o: Dictionary in pieces:
		if int(o["lane"]) == lane and float(o["from"]) <= to and float(o["to"]) >= from:
			return false
	return true


## True if a wall hand can reach in from wall `side` at track distance `at`: the wall is there (no wall
## gap) along its mist and a little either side.
func wall_fits(side: int, at: float) -> bool:
	var layout: LevelLayout = _layout()
	var half: float = boss.tuning.mist_length * 0.5 + 1.0
	return layout == null or not layout.wall_gap_between(at - half, at + half, side)


func _layout() -> LevelLayout:
	if boss.arena != null and boss.arena.layout != null:
		return boss.arena.layout
	return boss.world.layout if boss.world != null else null


# --- The way through ---------------------------------------------------------------------------------

## A way through `rows` (a round's rows; the round in play when empty) and the street around them for a
## runner in `lane` at track distance `d0` who first moves at `act_at`: TheHouseRoute.find's result,
## {ok, moves: [{at, from, to}], end_lane}. Its floor hands are solid in their lanes (hand_depth, the
## body's margin either side); the arena's holes are jumped and its fences jumped or slid under, with no
## lane switch during one; doodads are solid. `track`: the street's pieces as _track_obstacles gives them
## (read from the arena when empty).
func route_from(lane: int, d0: float, act_at: float, rows: Array = [], track: Array = []) -> Dictionary:
	var t: SleepTakerTuning = boss.tuning
	var v: float = boss.speed()
	if rows.is_empty():
		rows = round_plan.get("rows", [])
	var obstacles: Array = []
	var last: float = d0
	for row: Dictionary in rows:
		var at: float = float(row["at"])
		last = maxf(last, at)
		for spot: Dictionary in row["spots"]:
			if int(spot["side"]) == 0:
				obstacles.append(TheHouseRoute.obstacle(int(spot["lane"]), at - t.hand_depth * 0.5, at + t.hand_depth * 0.5))
	var d_end: float = last + over_distance() + v * 0.25
	if track.is_empty():
		_track_obstacles(obstacles, d0 - 20.0, d_end + 20.0)
	else:
		obstacles.append_array(track)
	return router(boss.lane_count(), v, boss.world.tuning, t).find(clampi(lane, 0, boss.lane_count() - 1), d0,
		maxf(act_at, d0), d_end, obstacles)


## The lane router the rounds are planned and proved by (The House's, TheHouseRoute: the same model of a
## runner's lane switches, jumps and slides) at `v` m/s on `lanes` lanes, with the Sleep Taker's margins:
## a lane switch takes the real one (MovementTuning.lane_switch_time) times route_switch_margin, and the
## body reaches route_body_margin past a hand either way; a jump and a slide as TheHouseRoute.for_run
## counts them.
static func router(lanes: int, v: float, movement: MovementTuning, t: SleepTakerTuning) -> TheHouseRoute:
	var r := TheHouseRoute.new()
	r.lanes = maxi(lanes, 1)
	r.switch_m = v * movement.lane_switch_time * t.route_switch_margin + 0.3
	r.body = movement.hurtbox_size.z * 0.5 + t.route_body_margin
	var jump: float = movement.jump_distance(v)
	r.jump_before = jump * 0.62
	r.jump_after = jump * 0.5
	r.slide_before = v * movement.slide_duration * 0.85
	r.slide_after = 1.5
	return r


## The arena's holes (and floor cuts), working fences and doodads reaching into [from, to], as the
## router's obstacles.
func _track_obstacles(out: Array, from: float, to: float) -> void:
	var layout: LevelLayout = _layout()
	if layout == null:
		return
	for g: Dictionary in layout.gaps:
		if float(g["start"]) <= to and float(g["end"]) >= from:
			out.append(TheHouseRoute.obstacle(int(g["lane"]), float(g["start"]), float(g["end"]), TheHouseRoute.Kind.FENCE))
	for c: Dictionary in layout.cuts:
		if float(c["start"]) <= to and float(c["end"]) >= from:
			out.append(TheHouseRoute.obstacle(int(c["lane"]), float(c["start"]), float(c["end"]), TheHouseRoute.Kind.FENCE))
	var half: float = boss.world.tuning.fence_depth * 0.5
	for f: Dictionary in layout.fences:
		var at: float = float(f["at"])
		if f.get("disabled", false) or at < from or at > to:
			continue
		var kind: int = TheHouseRoute.Kind.GAPPED if f["variant"] == "gapped" else TheHouseRoute.Kind.FENCE
		out.append(TheHouseRoute.obstacle(int(f["lane"]), at - half, at + half, kind))
	for dd: Dictionary in layout.doodads:
		if float(dd["start"]) <= to and float(dd["end"]) >= from:
			out.append(TheHouseRoute.obstacle(int(dd["lane"]), float(dd["start"]), float(dd["end"])))


# --- Timings --------------------------------------------------------------------------------------

## How far past a hand the runner is when its attack is over (its depth's far half and PASSED, at the
## run's pace).
func over_distance() -> float:
	return boss.tuning.hand_depth * 0.5 + PASSED * boss.run_pace()


## Seconds from a round's mists appearing to the runner reaching its first row (at the phase's pace): its
## nearest hand's warning (the later rows' mists show longer).
func warning_seconds() -> float:
	var t: SleepTakerTuning = boss.tuning
	return (t.mist_seconds + t.hand_rise_lead) / boss.pace()


## Metres between a round's rows at `v` m/s (hand_row_seconds, divided by the phase's pace).
func row_spacing(v: float) -> float:
	return v * boss.tuning.hand_row_seconds / boss.pace()


# --- A round in play ---------------------------------------------------------------------------------

## Starts a round from plan() (or, for reviews and tests, a single row {at, spots: [{lane, side}]} or a
## single staged hand {lane, at}).
func start(plan: Dictionary) -> void:
	var rows: Array[Dictionary] = _rows_of(plan)
	var total: int = 0
	for row: Dictionary in rows:
		total += (row["spots"] as Array).size()
	if total == 0 or total > _free.size():
		push_error("SleepTakerHands: cannot start a round without enough pooled hands")
		return
	rounds += 1
	_attempts = 0
	round_plan = plan.duplicate()
	round_plan["rows"] = rows
	var near: float = float(rows[0]["at"])
	boss.log_event(&"round", {"n": rounds, "rows": rows.size(), "hands": total, "lane": int(plan.get("lane", -1)),
		"at": near, "d": boss.player_distance(), "path": plan.get("path", [])})
	for r: int in rows.size():
		var row: Dictionary = rows[r]
		for spot: Dictionary in row["spots"]:
			_start_hand(spot, float(row["at"]), r, int(row.get("door", -1)))
	boss.sound(&"sleep_taker_whisper", boss.world.lane_point(boss.lane_count() / 2, near) + Vector3(0.0, 0.5, 0.0))


## A plan's rows, whatever its shape (start()).
static func _rows_of(plan: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if plan.has("rows"):
		out.assign(plan["rows"])
	elif plan.has("spots"):
		out.append({"at": float(plan["at"]), "door": int(plan.get("door", -1)), "open": [], "spots": plan["spots"]})
	else:
		out.append({"at": float(plan["at"]), "door": -1, "open": [],
			"spots": [{"lane": int(plan["lane"]), "side": int(plan.get("side", 0))}]})
	return out


func _start_hand(spot: Dictionary, at: float, row: int, door: int) -> void:
	var t: SleepTakerTuning = boss.tuning
	var rig: Dictionary = _free.pop_back()
	var lane: int = int(spot["lane"])
	var side: int = int(spot.get("side", 0))
	count += 1
	var root: Node3D = rig["root"]
	var visual: Node3D = rig["visual"]
	visual.rotation.z = float(side) * PI * 0.5
	root.global_position = boss.world.lane_point(lane, at) if side == 0 else \
		Vector3(side * boss.world.geo.wall_x(), t.hand_wall_height, TrackGeometry.world_z(at))
	var size := Vector3(boss.world.geo.lane_width * t.hand_width_share, t.hand_height, t.hand_depth)
	var hazard: Hazard = rig["hazard"]
	hazard.size = size if side == 0 else Vector3(size.y, size.x, size.z)
	hazard.position = Vector3(0.0, size.y * 0.5, 0.0) if side == 0 else \
		Vector3(-side * size.y * 0.5, 0.0, 0.0)
	((hazard.get_child(0) as CollisionShape3D).shape as BoxShape3D).size = hazard.size
	root.visible = true
	(rig["hand_mat"] as ShaderMaterial).set_shader_parameter(&"rise", 0.0)
	(rig["hand_mat"] as ShaderMaterial).set_shader_parameter(&"grasp", 0.0)
	(rig["hand_mat"] as ShaderMaterial).set_shader_parameter(&"attack", 0.0)
	(rig["hand_mat"] as ShaderMaterial).set_shader_parameter(&"fade", 0.0)
	(rig["mist_mat"] as ShaderMaterial).set_shader_parameter(&"amount", 0.0)
	(rig["mist_mat"] as ShaderMaterial).set_shader_parameter(&"surge", 0.0)
	(rig["wisps"] as CPUParticles3D).emitting = true
	var marker := Node3D.new()
	marker.name = "MistWarning"
	if side == 0:
		boss.props.floor_warning(marker, lane, at - t.mist_length * 0.5, at + t.mist_length * 0.5)
	else:
		boss.props.keep(marker, at + t.mist_length * 0.5)
	var hand := {"n": count, "round": rounds, "row": row, "lane": lane, "side": side, "door": door,
		"at": at, "stage": Stage.MIST, "t": 0.0, "rig": rig, "marker": marker}
	active.append(hand)
	boss.log_event(&"mist", {"n": count, "round": rounds, "row": row, "lane": lane, "side": side, "at": at,
		"d": boss.player_distance(), "door": door})


## True while a hand's warning shows or it can still reach the runner (until they're past it).
func busy() -> bool:
	var d: float = boss.player_distance()
	for h: Dictionary in active:
		if int(h["stage"]) != Stage.SINK and float(h["at"]) + over_distance() > d:
			return true
	return false


## True while a mist warns or a hand is up in front of the runner.
func warning_on() -> bool:
	return busy()


## The hands' damage boxes that are live now.
func live_hazards() -> Array[Hazard]:
	var out: Array[Hazard] = []
	for h: Dictionary in active:
		var hz: Hazard = (h["rig"] as Dictionary)["hazard"]
		if hz.is_active():
			out.append(hz)
	return out


## Every rig's damage box (live or not).
func hazards() -> Array[Hazard]:
	var out: Array[Hazard] = []
	for h: Dictionary in active:
		out.append((h["rig"] as Dictionary)["hazard"])
	for rig: Dictionary in _free:
		out.append(rig["hazard"])
	return out


## Every hand goes at once (a phase change, the defeat): mists gone, nothing live.
func clear() -> void:
	for h: Dictionary in active:
		_release(h)
	active.clear()


func tick(delta: float) -> void:
	var t: SleepTakerTuning = boss.tuning
	var p: float = boss.pace()
	var d: float = boss.player_distance()
	var rise_at: float = boss.speed() * t.hand_rise_lead / p
	for i: int in range(active.size() - 1, -1, -1):
		var h: Dictionary = active[i]
		var rig: Dictionary = h["rig"]
		var hand_mat: ShaderMaterial = rig["hand_mat"]
		var mist_mat: ShaderMaterial = rig["mist_mat"]
		var hz: Hazard = rig["hazard"]
		h["t"] = float(h["t"]) + delta
		var st: float = float(h["t"])
		match int(h["stage"]):
			Stage.MIST:
				mist_mat.set_shader_parameter(&"amount", clampf(st / POOL_SECONDS, 0.0, 1.0))
				# It bursts up as the runner comes within hand_rise_lead of it (its row's turn).
				if float(h["at"]) - d <= rise_at:
					h["stage"] = Stage.RISE
					h["t"] = 0.0
					var key: int = int(h["round"]) * 100 + int(h["row"])
					if not _sounded.has(key):
						_sounded[key] = true
						boss.sound(&"sleep_taker_hand", (rig["root"] as Node3D).global_position + Vector3(0.0, 1.0, 0.0))
					boss.log_event(&"hand", {"n": h["n"], "round": h["round"], "row": h["row"], "lane": h["lane"],
						"side": h["side"], "at": h["at"], "d": d})
			Stage.RISE:
				var k: float = clampf(st * p / maxf(t.hand_rise_seconds, 0.01), 0.0, 1.0)
				hand_mat.set_shader_parameter(&"rise", 1.0 - (1.0 - k) * (1.0 - k))
				hand_mat.set_shader_parameter(&"attack", k)
				mist_mat.set_shader_parameter(&"surge", k)
				# It's live from halfway up: the grasp reaches above a jump from there.
				if k >= 0.5 and not hz.is_active():
					hz.set_enabled(true)
				if k >= 1.0:
					h["stage"] = Stage.UP
					h["t"] = 0.0
			Stage.UP:
				hand_mat.set_shader_parameter(&"grasp", clampf(st / GRASP_SECONDS, 0.0, 1.0))
				var drawn: float = clampf(st * 2.0, 0.0, 1.0)
				mist_mat.set_shader_parameter(&"surge", 1.0 - drawn)
				mist_mat.set_shader_parameter(&"amount", lerpf(1.0, MIST_LEFT, drawn))
				var past: float = float(h["at"]) + over_distance()
				if d >= past and not h.has("passed"):
					h["passed"] = st
				if h.has("passed") and st - float(h["passed"]) >= t.hand_linger / p:
					h["stage"] = Stage.SINK
					h["t"] = 0.0
					hz.set_enabled(false)
			Stage.SINK:
				var k: float = clampf(st / SINK_SECONDS, 0.0, 1.0)
				hand_mat.set_shader_parameter(&"rise", 1.0 - k)
				hand_mat.set_shader_parameter(&"attack", 1.0 - k)
				mist_mat.set_shader_parameter(&"amount", MIST_LEFT * (1.0 - k))
				if k >= 1.0:
					_release(h)
					active.remove_at(i)


func _release(h: Dictionary) -> void:
	var rig: Dictionary = h["rig"]
	(rig["hazard"] as Hazard).set_enabled(false)
	(rig["root"] as Node3D).visible = false
	(rig["wisps"] as CPUParticles3D).emitting = false
	boss.props.remove(h["marker"])
	if not _free.has(rig):
		_free.append(rig)


## One pooled hand: its root (placed on a lane at the hand's spot), the hand, its mist pool, the wisps
## rising off it, and its damage box (the body's enemy attack).
func _make_rig(index: int) -> Dictionary:
	var t: SleepTakerTuning = boss.tuning
	var geo: TrackGeometry = boss.world.geo
	var root := Node3D.new()
	root.name = "Hand%d" % index
	root.top_level = true
	root.visible = false
	add_child(root)
	var visual := Node3D.new()
	visual.name = "Visual"
	root.add_child(visual)
	var hand_mat: ShaderMaterial = SleepTakerModel.hand_material(float(index) * 3.1 + 0.7)
	var hand := MeshInstance3D.new()
	hand.name = "Hand"
	hand.mesh = SleepTakerModel.hand_mesh()
	hand.material_override = hand_mat
	hand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The shader lifts it up from below the street: keep it from being culled.
	hand.extra_cull_margin = 4.0
	visual.add_child(hand)
	var mist_mat: ShaderMaterial = SleepTakerModel.mist_material(float(index) * 1.7)
	var quad := QuadMesh.new()
	quad.size = Vector2(geo.lane_width * 0.92, t.mist_length)
	var mist := MeshInstance3D.new()
	mist.name = "Mist"
	mist.mesh = quad
	mist.material_override = mist_mat
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mist.rotation.x = -PI * 0.5
	mist.position = Vector3(0.0, 0.05, 0.0)
	visual.add_child(mist)
	var wisps := CPUParticles3D.new()
	wisps.name = "Wisps"
	wisps.amount = 14
	wisps.lifetime = 1.2
	wisps.emitting = false
	wisps.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	wisps.emission_box_extents = Vector3(geo.lane_width * 0.35, 0.05, t.mist_length * 0.4)
	wisps.direction = Vector3(0.0, 1.0, 0.0)
	wisps.spread = 15.0
	wisps.gravity = Vector3(0.0, 0.6, 0.0)
	wisps.initial_velocity_min = 0.3
	wisps.initial_velocity_max = 0.9
	wisps.scale_amount_min = 1.2
	wisps.scale_amount_max = 2.2
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.4))
	curve.add_point(Vector2(0.4, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	wisps.scale_amount_curve = curve
	var puff := QuadMesh.new()
	puff.size = Vector2(0.6, 0.6)
	wisps.mesh = puff
	wisps.material_override = SleepTakerModel.wisp_material(Color(SleepTakerModel.MIST_COLOR, 0.32))
	wisps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child(wisps)
	var size := Vector3(geo.lane_width * t.hand_width_share, t.hand_height, t.hand_depth)
	var hazard: Hazard = boss.body.add_hitbox(&"attack", size, Vector3(0.0, size.y * 0.5, 0.0), true, root)
	hazard.hazard_name = "Sleep Taker's hand"
	hazard.set_enabled(false)
	return {"root": root, "visual": visual, "hand": hand, "hand_mat": hand_mat, "mist": mist, "mist_mat": mist_mat, "wisps": wisps,
		"hazard": hazard}

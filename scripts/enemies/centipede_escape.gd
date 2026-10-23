class_name CentipedeEscape
extends RefCounted
## The proof that a block of the debris maze stays escapable with its Cybernetic Centipedes in it (task O3; GDD §9.15:
## "the player is strongly encouraged to run from it", and the brief: placement keeps every maze escapable). The
## generator's rules place a centipede only where this finds a way out (centipede_rules.gd), and LayoutChecks proves every
## built level again.
##
## Escapable: from the block's run-in (any lane) to past its last wall, some way through exists on the Player's moves,
## with the dash at its slowest recharge (PowerupTuning: 8 s) and just used as the run-in begins (entry_ready: the debris
## maze's own check takes the same; in the Terminal a runner may well have dashed through a doodad just before it), and
## the stops and waits that takes, on which the runner is never within a centipede's bite, whatever the centipede does.
## A runner choosing that way escapes without needing armor.
## The way keeps off the block's anti-grav pads (a maze ceiling's: DebrisMaze), as MazeRoute's do: a ride on its ceiling
## would get the runner away too (the centipede can't follow), but the way is the floor's, so a runner following it is
## never lifted off it by surprise. An escape block (task O5, DebrisMaze.is_escape) is the exception: its barrier is no
## way through (more than one dash deep), and its way out is its pad, in the open room before the barrier: the runner
## lines up in the pad's lane and runs onto it, safe from the moment they reach the barrier's front, lifted well above any
## bite by then and on a ceiling, where a centipede gives up.
## "Whatever it does" rests on what every centipede keeps to (Centipede, which test_centipede checks on physics):
## - it waits, still, until the runner is on the floor in its own section of the maze or one joined to it (DebrisMaze
##   links, with the runner's own smashes) within its wake distance along the track (CentipedeTuning.wake_distance_at),
##   and then wake_time more before it moves (its warning);
## - it moves along open floor only (CentipedeMaze: its head never in debris, nor in a lane whose debris stands beside
##   it), from a standstill, no faster than its chase speed (CentipedeTuning.chase_speed) and speeding up no faster than
##   its acceleration;
## - its bite reaches no further than CentipedeTuning.bite_reach in front of its head, and a dash passes through it;
## - it gives up once the runner is leave_margin past its block's last wall.
## An ambush (task O5; spot "ambush", hidden in a divider: CentipedeRules._place_ambushes) breaks out once the runner is
## within its ambush distance along the track anywhere in its block (its wake), and the debris it lay in ("host") counts
## as open floor from the start, for every centipede of the block, and joins the sections either side of it from the
## start (_host_joins); then it keeps to all of the above.
## So at time t after its wake at t_w it can be nowhere further along open floor from its spot than it can run from a
## standstill in t - t_w - wake_time. The runner is safe while their distance from its spot (CentipedeMaze.field: along
## the track, a lane change costing nothing, which no real way beats) is more than that and its reach, with the grid's
## rounding. The runner's own smashes count as open from the start (it may use the hole the runner makes), and inside a
## wall's opening the runner counts as in the sections either side.
##
## The search: stage by stage through the block (its run-in, each room's cells, its breather), each label a runner in a
## cell (when and where they came in, the lane, when the dash is ready, when each centipede woke, the joins their smashes
## made); through each wall by an opening in a lane of the cell (lining up while running, a lane switch's run at a time),
## or by the dash from a stop at a closed piece's face (waiting there for it; its carry smashing that piece and a
## divider's pieces it reaches beyond; then over into a cell beside a smashed divider). Every stretch run or stood is
## checked against every centipede awake. A label another beats (sooner, the dash readier, further on, every centipede
## woken no sooner or not at all) goes. The quickest safe way is checked again with its smashes open (the fields from the
## start); one that fails drops the dash that opened the way and searches again. Its moves are MazeBot's
## (tests/helpers/maze_bot.gd), so it can be run on physics. DESIGN-TBD (docs/questions/o3.md): the definition and its
## margins.

## Player.STOP_CLEARANCE: a stopped runner's front this short of the debris.
const STOP_CLEARANCE: float = 0.02
## MazeRoute.BODY_MARGIN: kept between the body and debris along its lane (metres).
const BODY_MARGIN: float = 0.1
## MazeRoute.DASH_SLACK: taken off the dash's carry for where the runner surely gets to (metres).
const DASH_SLACK: float = 1.0
## Added to the dash's full carry for what it may smash (metres): the Player smashes every piece in its lane whose front
## its dash reaches (Player._dash_claims), so the holes a way opens to the centipedes are taken wider, never narrower.
const SMASH_MARGIN: float = 1.0
## Kept off an anti-grav pad either side along its lane (metres; MazeRoute.PAD_MARGIN), and before it half a lane
## switch's run more.
const PAD_MARGIN: float = 0.6
## A lane switch while running starts this far past where the runner came into the stage (metres), and the switches
## need this much room besides their run before the wall's face (metres).
const SWITCH_START: float = 0.6
const SWITCH_MARGIN: float = 1.0
## Seconds on top of a lane switch's in the model (a frame or two to press and settle), and on top of one from a stop.
const SWITCH_SLACK: float = 0.04
const SLIDE_SLACK: float = 0.06
## One physics frame (seconds): a dash starts a frame after the runner is ready to press it.
const FRAME: float = 1.0 / 60.0
## Metres added to a centipede's reach beyond its bite and the runner's half depth: the runner's bin and its head's way
## are counted in whole bins (CentipedeMaze.BIN, one each), and a little more.
const REACH_MARGIN: float = 0.5
## Labels kept per cell and lane at a stage.
const FRONT: int = 6
## Searches again at most this many times after a way fails with its smashes open.
const RETRIES: int = 4
const POWERUPS_PATH: String = "res://data/tuning/powerups.tres"
## Seconds of tolerance when labels are compared.
const EPS: float = 0.0001


## The way out of block `index` of `layout` (its record in LevelLayout.maze) past the centipedes waiting at `spots`
## ({lane, at} each: where its head waits), at the level's movement tuning `tuning` (its run speed). See Context.find.
static func find(layout: LevelLayout, tuning: MovementTuning, index: int, spots: Array, options: Dictionary = {}) -> Dictionary:
	return Context.new(layout, tuning, index).find(spots, options)


## A reusable check of one block (its maze model, sections, pieces), for several sets of spots.
static func context(layout: LevelLayout, tuning: MovementTuning, index: int) -> Context:
	return Context.new(layout, tuning, index)


## The debris an ambush spot lies in (its "host": CentipedeRules.ambush_host), as a set of layout entries, open from the
## start for the proof (it shatters as the ambush breaks out); {} for any other spot.
static func host_of(spot: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for d: Variant in spot.get("host", []):
		out[d] = true
	return out


## The dash's slowest recharge (seconds): its tier I cooldown or an upgrade's, the longest (GDD §8: 8 s).
static func slowest_recharge() -> float:
	var pt := load(POWERUPS_PATH) as PowerupTuning
	if pt == null:
		return 8.0
	var out: float = pt.dash_cooldown
	for c: float in pt.dash_upgrade_cooldowns:
		out = maxf(out, c)
	return out


## Seconds from a block's run-in until the dash is ready, recharging `recharge` seconds: the whole of it, as if the
## runner had just used it as the run-in began (the worst case, and the debris maze's own: MazeRoute's runner starts every
## block with the dash just used). In the Terminal doodads stop the runner, so one who dashed through a doodad just before
## a block comes into it with the dash nearly that far off; one who spends it in the run-in itself has thrown it away.
static func entry_ready(recharge: float) -> float:
	return recharge


## The farthest a centipede can have run (metres) `t` seconds after it began to move, from a standstill: no faster than
## `top` (m/s), speeding up no faster than `accel` (m/s²).
static func run_reach(t: float, top: float, accel: float) -> float:
	if t <= 0.0:
		return 0.0
	var a: float = maxf(accel, 0.001)
	var to_top: float = top / a
	if t <= to_top:
		return 0.5 * a * t * t
	return top * t - 0.5 * top * to_top


## One block's check (see the header).
class Context:
	var layout: LevelLayout
	var tuning: MovementTuning
	var index: int = -1
	var maze: CentipedeMaze
	var b: Dictionary
	var walls: Array
	var rooms: Array
	var stages: int = 0
	var lanes: int = 3
	var v: float = 18.0
	var switch_time: float = 0.14
	var half: float = 0.26
	## How far a dash surely carries the runner (its run less DASH_SLACK), and how far it may smash (its whole run and
	## SMASH_MARGIN).
	var carry: float = 10.0
	var smash_reach: float = 12.0
	var bonus: float = 8.0
	var chase: float = 15.0
	var accel: float = 30.0
	var wake_time: float = 0.6
	var wake_d: float = 30.0
	var ambush_d: float = 16.0
	var reach: float = 3.0
	var leave_end: float = 0.0
	## Per stage, its cells (Vector2i(first, last) lanes).
	var cells: Array = []
	## The block's sections and their joins without a dash (DebrisMaze, on the block alone), and each stage and cell's
	## section id.
	var secs: Array[Dictionary] = []
	var joined: Dictionary = {}
	var stage_sections: Array = []
	var wall_pieces: Dictionary = {}
	var divider_pieces: Dictionary = {}
	## Per lane, the stretches its anti-grav pads keep the runner's body off (Vector2(start, end) each).
	var pad_spans: Array = []
	## An escape block's pad (DebrisMaze.is_escape): its lane (-1 for any other block) and track distance.
	var escape_lane: int = -1
	var escape_at: float = 0.0
	## Each spot's field (CentipedeMaze.field), by "lane|at".
	var _fields: Dictionary = {}

	func _init(p_layout: LevelLayout, p_tuning: MovementTuning, p_index: int) -> void:
		layout = p_layout
		tuning = p_tuning
		index = p_index
		maze = CentipedeMaze.for_block(p_layout, p_index, p_tuning)
		b = p_layout.maze[p_index]
		walls = b["walls"]
		rooms = b["rooms"]
		stages = rooms.size() + 2
		lanes = p_layout.lane_count
		v = p_tuning.run_speed
		switch_time = p_tuning.lane_switch_time
		half = p_tuning.visual_size.z * 0.5
		var pt := load(CentipedeEscape.POWERUPS_PATH) as PowerupTuning
		var duration: float = pt.dash_duration if pt != null else 0.6
		bonus = pt.dash_speed_bonus if pt != null else 8.0
		carry = (v + bonus) * duration - CentipedeEscape.DASH_SLACK
		smash_reach = (v + bonus) * duration + CentipedeEscape.SMASH_MARGIN
		var t := EnemyDirector.tuning_for("centipede") as CentipedeTuning
		if t == null:
			t = CentipedeTuning.new()
		chase = t.chase_speed(v)
		accel = t.acceleration
		wake_time = t.wake_time
		wake_d = t.wake_distance_at(p_tuning.pace())
		ambush_d = t.ambush_distance_at(p_tuning.pace())
		reach = t.bite_reach(CentipedeMaze.HEAD_HALF_LENGTH) + half + 2.0 * CentipedeMaze.BIN + CentipedeEscape.REACH_MARGIN
		leave_end = float(b["end"]) + t.leave_margin
		var bl: LevelLayout = maze.block_layout()
		secs = DebrisMaze.sections(bl)
		for k: Dictionary in DebrisMaze.links(bl, secs):
			_join(joined, int(k["from"]), int(k["to"]))
		for s: int in stages:
			var list: Array = [Vector2i(0, lanes - 1)] if s == 0 or s == stages - 1 \
				else DebrisMaze.cells_of((rooms[s - 1] as Dictionary)["dividers"], lanes)
			cells.append(list)
			var ids: Array[int] = []
			for c: Vector2i in list:
				ids.append(DebrisMaze.section_id(secs, 0, s - 1, c.x))
			stage_sections.append(ids)
		for d: Dictionary in maze.entries():
			var key: String = "%d|%d" % [int(d["index"]), int(d["lane"])]
			if String(d["part"]) == "wall":
				wall_pieces[key] = d
			else:
				if not divider_pieces.has(key):
					divider_pieces[key] = []
				(divider_pieces[key] as Array).append(d)
		for key: String in divider_pieces:
			(divider_pieces[key] as Array).sort_custom(func(a: Dictionary, c: Dictionary) -> bool:
				return float(a["start"]) < float(c["start"]))
		var escape: Dictionary = b.get("escape", {})
		if escape.has("lane"):
			escape_lane = int(escape["lane"])
			escape_at = float(escape["at"])
		for lane: int in lanes:
			pad_spans.append([])
		for p: Dictionary in p_layout.pads:
			var at: float = float(p["at"])
			var lane: int = int(p["lane"])
			if lane >= 0 and lane < lanes and at >= float(b["entry"]) - 10.0 and at <= float(b["exit"]) + 10.0:
				(pad_spans[lane] as Array).append(Vector2(at - CentipedeEscape.PAD_MARGIN - switch_time * v * 0.5,
					at + p_tuning.pad_length + CentipedeEscape.PAD_MARGIN))

	## True if a body whose middle runs from `z0` to `z1` in `lane` (BODY_MARGIN kept beyond its half depth) keeps off
	## every anti-grav pad's stretch there.
	func pad_clear(lane: int, z0: float, z1: float) -> bool:
		if lane < 0 or lane >= lanes:
			return true
		var lo: float = minf(z0, z1) - half - CentipedeEscape.BODY_MARGIN
		var hi: float = maxf(z0, z1) + half + CentipedeEscape.BODY_MARGIN
		for span: Vector2 in pad_spans[lane]:
			if span.x < hi and span.y > lo:
				return false
		return true

	## True if every lane from `from_lane` to `to_lane` keeps off the pads from `z0` to `z1` (a switch's lanes, taken
	## whole).
	func pads_clear_between(from_lane: int, to_lane: int, z0: float, z1: float) -> bool:
		for lane: int in range(mini(from_lane, to_lane), maxi(from_lane, to_lane) + 1):
			if not pad_clear(lane, z0, z1):
				return false
		return true

	static func _join(map: Dictionary, a: int, c: int) -> void:
		if a < 0 or c < 0:
			return
		map["%d|%d" % [a, c]] = true
		map["%d|%d" % [c, a]] = true

	## The section holding `lane` at track distance `at` (DebrisMaze.section_at on the block's plain sections), or -1.
	func section_of(lane: int, at: float) -> int:
		return DebrisMaze.section_at(secs, lane, at)

	## The section of stage `stage`'s cell `cell`.
	func stage_section(stage: int, cell: int) -> int:
		return int((stage_sections[stage] as Array)[cell])

	## The field from a spot (cached).
	## An ambush's (spot "ambush", task O5) is taken with the debris it lies in open (its "host": it shatters as it breaks
	## out).
	func field_of(spot: Dictionary) -> PackedInt32Array:
		var host: Dictionary = CentipedeEscape.host_of(spot)
		var key: String = "%d|%.3f|%d" % [int(spot["lane"]), float(spot["at"]), host.size()]
		if not _fields.has(key):
			_fields[key] = maze.field(int(spot["lane"]), float(spot["at"]), host)
		return _fields[key]

	## The way out past the centipedes at `spots` ({lane, at} each). `options`: recharge (seconds; default the dash's
	## slowest), entry_ready (seconds from the run-in's start until the dash is ready; default
	## CentipedeEscape.entry_ready: the whole recharge), forbidden ({"<wall>|<lane>": true}, dashes never to take).
	## {ok, reason, moves (MazeBot's), start_lane, seconds (from the run-in's start until the runner is leave_margin past
	## the last wall), waits (seconds stood waiting for the dash), dashes, path ([stage, cell] each, stage 0 the run-in),
	## entry_ready, recharge, wakes (each centipede's wake on the way, seconds, INF never)}.
	func find(spots: Array, options: Dictionary = {}) -> Dictionary:
		var s := Search.new(self, spots, options)
		return s.solve()


## One search (see the header).
class Search:
	var c: Context
	var spots: Array = []
	var fields: Array = []
	var homes: PackedInt32Array = PackedInt32Array()
	## Per spot, true for an ambush (its "ambush": hidden in debris, which opens as it breaks out).
	var ambush: Array[bool] = []
	## The debris every ambush among the spots lies in (layout entries), and the joins its shattering makes between the
	## block's sections, taken from the start (_host_joins).
	var hosts: Dictionary = {}
	var joins0: Dictionary = {}
	var recharge: float = 8.0
	var ready0: float = 0.0
	var forbidden: Dictionary = {}
	var reason: String = ""

	func _init(p_context: Context, p_spots: Array, options: Dictionary) -> void:
		c = p_context
		spots = p_spots
		recharge = float(options.get("recharge", CentipedeEscape.slowest_recharge()))
		ready0 = float(options.get("entry_ready", CentipedeEscape.entry_ready(recharge)))
		forbidden = (options.get("forbidden", {}) as Dictionary).duplicate()
		for spot: Dictionary in spots:
			hosts.merge(CentipedeEscape.host_of(spot))
		for spot: Dictionary in spots:
			# With an ambush in the block, every centipede's reach takes its debris as open (it shatters).
			fields.append(c.field_of(spot) if hosts.is_empty() else c.maze.field(int(spot["lane"]), float(spot["at"]), hosts))
			ambush.append(bool(spot.get("ambush", false)))
			homes.append(-1 if ambush[-1] else c.section_of(int(spot["lane"]), float(spot["at"])))
		joins0 = _host_joins()

	func solve() -> Dictionary:
		for attempt: int in CentipedeEscape.RETRIES + 1:
			var best: Dictionary = _search()
			if best.is_empty():
				return {"ok": false, "reason": reason if reason != "" else "no way through keeps out of reach", "moves": [],
					"entry_ready": ready0, "recharge": recharge}
			var story: Dictionary = _history(best)
			var bad: int = _validate(best, story)
			if bad < 0:
				return {"ok": true, "reason": "", "moves": story["moves"], "start_lane": int(best["start_lane"]),
					"seconds": float(best["t"]), "waits": float(best["waits"]), "dashes": int(best["dashes"]),
					"path": story["path"], "entry_ready": ready0, "recharge": recharge, "wakes": best["wakes"]}
			forbidden[(story["dash_keys"] as Array)[bad]] = true
		return {"ok": false, "reason": "every way found lets a centipede through a hole it smashed", "moves": [],
			"entry_ready": ready0, "recharge": recharge}

	## What a label records of its own step (its moves, the stretches checked, its smashes and dashes, the stages it came
	## into); the way so far is its parents' (_history).
	const STEP_KEYS: Array[String] = ["moves", "segs", "smashes", "dash_keys", "dash_t", "path"]

	## The joins between the block's sections once every ambush's debris has shattered (DebrisMaze.links with those pieces
	## smashed, on a copy of the block): every pair of sections a shattered stretch of a divider meets, taken either way.
	## Wider than the centipedes' own (they wake for a section joined directly), never narrower.
	func _host_joins() -> Dictionary:
		var out: Dictionary = {}
		if hosts.is_empty():
			return out
		var keys: Dictionary = {}
		for d: Variant in hosts:
			keys["%d|%.3f" % [int((d as Dictionary)["lane"]), float((d as Dictionary)["start"])]] = true
		var bl: LevelLayout = c.maze.block_layout()
		for d: Dictionary in bl.doodads:
			if keys.has("%d|%.3f" % [int(d["lane"]), float(d["start"])]):
				d["smashed"] = true
		var plain: int = c.secs.size()
		var touched: Dictionary = {}  # a section id -> the plain sections it meets through a shattered piece
		for k: Dictionary in DebrisMaze.links(bl, c.secs, true):
			if String(k["kind"]) != "broken":
				continue
			for pair: Array in [[int(k["from"]), int(k["to"])], [int(k["to"]), int(k["from"])]]:
				if not touched.has(pair[0]):
					touched[pair[0]] = {}
				(touched[pair[0]] as Dictionary)[pair[1]] = true
		for hub: Variant in touched:
			var group: Array = (touched[hub] as Dictionary).keys()
			group.append(hub)
			for a: Variant in group:
				for b2: Variant in group:
					if int(a) != int(b2) and int(a) < plain and int(b2) < plain:
						out["%d|%d" % [int(a), int(b2)]] = true
		return out

	func _start() -> Dictionary:
		var wakes := PackedFloat64Array()
		for i: int in spots.size():
			wakes.append(INF)
		var out: Dictionary = {"t": 0.0, "z": float(c.b["entry"]), "lane": -1, "cell": 0, "stage": 0, "ready": ready0,
			"wakes": wakes, "joins": joins0.duplicate(), "waits": 0.0, "dashes": 0, "start_lane": -1, "parent": null}
		for key: String in STEP_KEYS:
			out[key] = []
		(out["path"] as Array).append([0, 0])
		return out

	## A label for the next step from `l`: its state (the joins shared until a smash adds to them; the wakes its own: a
	## packed array in a dictionary is shared, not copied, when the dictionary is), its own step empty.
	func _copy(l: Dictionary) -> Dictionary:
		var out: Dictionary = l.duplicate()
		out["wakes"] = (l["wakes"] as PackedFloat64Array).duplicate()
		for key: String in STEP_KEYS:
			out[key] = []
		out["parent"] = l
		return out

	## Label `l`'s whole way, from the start: each of STEP_KEYS over its parents' steps and its own, in order.
	func _history(l: Dictionary) -> Dictionary:
		var chain: Array = []
		var x: Variant = l
		while x != null:
			chain.push_front(x)
			x = (x as Dictionary)["parent"]
		var out: Dictionary = {}
		for key: String in STEP_KEYS:
			out[key] = []
		for y: Dictionary in chain:
			for key: String in STEP_KEYS:
				(out[key] as Array).append_array(y[key])
		return out

	## The quickest safe label past the last wall (an escape block's: onto its pad), or {}.
	func _search() -> Dictionary:
		var current: Array = [_start()]
		# An escape block's barrier is no way through: its pad, in the room before it, is (_escape).
		var through: int = c.stages - 2 if c.escape_lane >= 0 else c.stages - 1
		for s: int in through:
			var next: Array = []
			for l: Dictionary in current:
				_expand(l, s, next)
			current = _prune(next)
			if current.is_empty():
				reason = "no safe way past wall %d of %d" % [s, c.walls.size()]
				return {}
		if c.escape_lane >= 0:
			return _escape(current)
		var best: Dictionary = {}
		for l: Dictionary in current:
			if not c.pad_clear(int(l["lane"]), float(l["z"]), maxf(c.leave_end, float(l["z"]))):
				continue
			var n: Dictionary = _copy(l)
			var end_t: float = float(l["t"]) + maxf(c.leave_end - float(l["z"]), 0.0) / c.v
			var here: Array[int] = [c.stage_section(c.stages - 1, 0)]
			if not _check(n, float(l["t"]), end_t, float(l["z"]), maxf(c.leave_end, float(l["z"])), int(l["lane"]), true, here):
				continue
			n["t"] = end_t
			if best.is_empty() or float(n["t"]) < float(best["t"]) - CentipedeEscape.EPS \
					or (absf(float(n["t"]) - float(best["t"])) <= CentipedeEscape.EPS and int(n["dashes"]) < int(best["dashes"])):
				best = n
		if best.is_empty():
			reason = "no safe way out into the breather"
		return best

	## The quickest safe way from the labels `current` (in an escape block's pad room) onto its pad: lined up in the pad's
	## lane (a lane switch's run after SWITCH_START, before the pad's stretch), then running on to the pad, never within a
	## centipede's reach until the runner is at the barrier's front (by then the lift has carried them well above its bite:
	## DebrisMaze.pad_rise; on the ceiling it gives up). {} if none.
	func _escape(current: Array) -> Dictionary:
		var best: Dictionary = {}
		var stage: int = c.stages - 2
		var here: Array[int] = [c.stage_section(stage, 0)]
		var lane: int = c.escape_lane
		var pad: float = c.escape_at
		var up: float = float((c.walls[-1] as Dictionary)["start"]) - c.half - CentipedeEscape.BODY_MARGIN
		var lined_by: float = pad - CentipedeEscape.PAD_MARGIN - c.half - CentipedeEscape.BODY_MARGIN
		for l: Dictionary in current:
			var z: float = float(l["z"])
			var t: float = float(l["t"])
			var from_lane: int = int(l["lane"])
			var switches: int = absi(lane - from_lane)
			var run: float = switches * (c.switch_time + CentipedeEscape.SWITCH_SLACK) * c.v
			if switches > 0 and z + CentipedeEscape.SWITCH_START + run > lined_by:
				continue
			var n: Dictionary = _copy(l)
			if switches > 0:
				(n["moves"] as Array).append({"kind": "switch", "at": z + CentipedeEscape.SWITCH_START, "lane": from_lane,
					"to": lane})
			var t_up: float = t + (up - z) / c.v
			if not _check(n, t, t_up, z, up, lane, true, here):
				continue
			n["t"] = t_up
			n["z"] = up
			n["lane"] = lane
			if best.is_empty() or float(n["t"]) < float(best["t"]) - CentipedeEscape.EPS \
					or (absf(float(n["t"]) - float(best["t"])) <= CentipedeEscape.EPS and int(n["dashes"]) < int(best["dashes"])):
				best = n
		if best.is_empty():
			reason = "no safe way onto the escape's pad"
		return best

	## Every way from label `l` (in stage `s`) through the wall after it into stage s + 1, appended to `out`.
	func _expand(l: Dictionary, s: int, out: Array) -> void:
		var cell: Vector2i = (c.cells[s] as Array)[int(l["cell"])]
		var here: int = c.stage_section(s, int(l["cell"]))
		var wall: Dictionary = c.walls[s]
		var face: float = float(wall["start"]) - c.half - CentipedeEscape.STOP_CLEARANCE
		var z: float = float(l["z"])
		var t: float = float(l["t"])
		for lane: int in range(cell.x, cell.y + 1):
			var from_lane: int = int(l["lane"]) if int(l["lane"]) >= 0 else lane
			var switches: int = absi(lane - from_lane)
			var run: float = switches * (c.switch_time + CentipedeEscape.SWITCH_SLACK) * c.v
			if switches > 0 and z + CentipedeEscape.SWITCH_START + run + CentipedeEscape.SWITCH_MARGIN > face:
				continue
			# Lined up (in its lane from z_set on), keeping off the pads in every lane it crosses meanwhile.
			var z_set: float = z + CentipedeEscape.SWITCH_START + run if switches > 0 else z
			if not c.pads_clear_between(from_lane, lane, z, z_set):
				continue
			var n: Dictionary = _copy(l)
			if int(l["lane"]) < 0:
				n["start_lane"] = lane
			if switches > 0:
				(n["moves"] as Array).append({"kind": "switch", "at": z + CentipedeEscape.SWITCH_START, "lane": from_lane,
					"to": lane})
			if (wall["open"] as Array).has(lane):
				var next_cell: int = DebrisMaze.cell_index(c.cells[s + 1], lane)
				var there: int = c.stage_section(s + 1, next_cell)
				var z_out: float = float(wall["end"]) + c.half + CentipedeEscape.BODY_MARGIN
				if not c.pad_clear(lane, z_set, z_out):
					continue
				var t_wall: float = t + (float(wall["start"]) - z) / c.v
				var t_out: float = t + (z_out - z) / c.v
				var mine: Array[int] = [here]
				var both: Array[int] = [here, there]
				var theirs: Array[int] = [there]
				if not _check(n, t, t_wall, z, float(wall["start"]), lane, true, mine):
					continue
				if not _check(n, t_wall, t + (float(wall["end"]) - z) / c.v, float(wall["start"]), float(wall["end"]), lane, true, both):
					continue
				if not _check(n, t + (float(wall["end"]) - z) / c.v, t_out, float(wall["end"]), z_out, lane, true, theirs):
					continue
				_arrive(n, s + 1, lane, t_out, z_out, out)
				continue
			if forbidden.has("%d|%d" % [s, lane]) or not c.wall_pieces.has("%d|%d" % [s, lane]) \
					or not c.pad_clear(lane, z_set, face):
				continue
			var t_face: float = t + (face - z) / c.v
			var mine2: Array[int] = [here]
			if not _check(n, t, t_face, z, face, lane, true, mine2):
				continue
			var t_go: float = maxf(t_face, float(l["ready"])) + CentipedeEscape.FRAME
			if not _check(n, t_face, t_go, face, face, lane, false, mine2):
				continue
			n["waits"] = float(n["waits"]) + maxf(float(l["ready"]) - t_face, 0.0)
			_dash(n, s, lane, face, t_go, here, out)

	## The dash from the face of wall `s`'s piece in `lane` at time `t_go` (label `n` stands there, in section `here`),
	## into stage s + 1.
	func _dash(n: Dictionary, s: int, lane: int, face: float, t_go: float, here: int, out: Array) -> void:
		var wall: Dictionary = c.walls[s]
		var smashed: Array = [c.wall_pieces["%d|%d" % [s, lane]]]
		# The runner surely gets past what fronts within the sure carry; the dash may smash all that fronts within its
		# whole run (the smash set, which the centipedes may use, is taken that wide).
		var reach_z: float = face + c.half + c.carry
		var smash_z: float = face + c.half + c.smash_reach
		var last_end: float = float(wall["end"])
		var next_front: float = INF
		var rooms: Array = c.rooms
		var in_divider: bool = s < rooms.size() and ((rooms[s] as Dictionary)["dividers"] as Array).has(lane)
		if in_divider:
			for p: Dictionary in c.divider_pieces.get("%d|%d" % [s, lane], []):
				if float(p["start"]) > smash_z:
					if next_front == INF:
						next_front = float(p["start"])
					break
				smashed.append(p)
				if float(p["start"]) <= reach_z and next_front == INF:
					last_end = maxf(last_end, float(p["end"]))
				elif next_front == INF:
					next_front = float(p["start"])
		if s + 1 < c.walls.size() and not ((c.walls[s + 1] as Dictionary)["open"] as Array).has(lane):
			var next_wall: float = float((c.walls[s + 1] as Dictionary)["start"])
			next_front = minf(next_front, next_wall)
			if next_wall <= smash_z and c.wall_pieces.has("%d|%d" % [s + 1, lane]):
				smashed.append(c.wall_pieces["%d|%d" % [s + 1, lane]])
		var z_end: float = maxf(face + c.carry, last_end + c.half + CentipedeEscape.BODY_MARGIN)
		z_end = minf(z_end, next_front - c.half - CentipedeEscape.BODY_MARGIN)
		if z_end <= last_end + c.half or not c.pad_clear(lane, face, z_end):
			return
		# The joins this smash makes (DebrisMaze.links' breach): everything open right before the wall's front and right
		# past its back, in the lanes open through it beside the smashed one, one lane either side more (taken wider than
		# the maze's own, never narrower), and with a divider smashed, the cells either side of it.
		var joins: Dictionary = (n["joins"] as Dictionary).duplicate()
		var near: Array[int] = []
		for dl: int in range(-1, 2):
			var l2: int = lane + dl
			if l2 < 0 or l2 >= c.lanes:
				continue
			for st: int in [s, s + 1]:
				var ci: int = DebrisMaze.cell_index(c.cells[st], l2)
				if ci >= 0:
					var id: int = c.stage_section(st, ci)
					if not near.has(id):
						near.append(id)
		var run_lo: int = lane
		var run_hi: int = lane
		while run_lo - 1 >= 0 and (wall["open"] as Array).has(run_lo - 1):
			run_lo -= 1
		while run_hi + 1 < c.lanes and (wall["open"] as Array).has(run_hi + 1):
			run_hi += 1
		for l3: int in range(run_lo, run_hi + 1):
			for st2: int in [s, s + 1]:
				var ci2: int = DebrisMaze.cell_index(c.cells[st2], l3)
				if ci2 >= 0:
					var id2: int = c.stage_section(st2, ci2)
					if not near.has(id2):
						near.append(id2)
		for a: int in near:
			for b2: int in near:
				if a != b2:
					joins["%d|%d" % [a, b2]] = true
		n["joins"] = joins
		var run: float = z_end - face
		var fast: float = minf(run, c.carry)
		var t_fast: float = t_go + fast / (c.v + c.bonus)
		var t_end: float = t_fast + (run - fast) / c.v
		# Dashing, nothing bites: only the wakes count (the runner is in the sections either side of the wall meanwhile).
		var span: Array[int] = near.duplicate()
		_wakes(n, t_go, t_fast, face, face + fast, span)
		(n["segs"] as Array).append([t_go, t_fast, face, face + fast, lane, false, true, span])
		if run > fast and not _check(n, t_fast, t_end, face + fast, z_end, lane, true, span):
			return
		(n["moves"] as Array).append({"kind": "dash", "at": face, "lane": lane, "to": lane})
		(n["smashes"] as Array).append_array(smashed)
		(n["dash_keys"] as Array).append("%d|%d" % [s, lane])
		(n["dash_t"] as Array).append(t_go)
		n["ready"] = t_go + recharge
		n["dashes"] = int(n["dashes"]) + 1
		if not in_divider:
			_arrive(n, s + 1, lane, t_end, z_end, out)
			return
		# In the smashed divider's lane, stopped at what stands on in it: over into a cell beside.
		var dividers: Array = (rooms[s] as Dictionary)["dividers"]
		for side: int in [-1, 1]:
			var to_lane: int = lane + side
			if to_lane < 0 or to_lane >= c.lanes or dividers.has(to_lane) \
					or not c.pads_clear_between(lane, to_lane, z_end - 0.3, z_end + c.switch_time * c.v):
				continue
			var m: Dictionary = _copy(n)
			var t_sw: float = t_end + c.switch_time + CentipedeEscape.SLIDE_SLACK
			if not _check(m, t_end, t_sw, z_end, z_end, lane, false, span):
				continue
			(m["moves"] as Array).append({"kind": "switch", "at": z_end - 0.3, "lane": lane, "to": to_lane})
			_arrive(m, s + 1, to_lane, t_sw, z_end + c.switch_time * c.v * 0.5, out)

	func _arrive(n: Dictionary, stage: int, lane: int, t: float, z: float, out: Array) -> void:
		var cell: int = DebrisMaze.cell_index(c.cells[stage], lane)
		if cell < 0:
			return
		n["t"] = t
		n["z"] = z
		n["lane"] = lane
		n["cell"] = cell
		n["stage"] = stage
		(n["path"] as Array).append([stage, cell])
		out.append(n)

	## Labels another beats go (see the header), and past FRONT a cell and lane's slowest.
	func _prune(labels: Array) -> Array:
		var by_key: Dictionary = {}
		for l: Dictionary in labels:
			var key: String = "%d|%d" % [int(l["cell"]), int(l["lane"])]
			if not by_key.has(key):
				by_key[key] = []
			(by_key[key] as Array).append(l)
		var out: Array = []
		for key: String in by_key:
			var list: Array = by_key[key]
			list.sort_custom(func(a: Dictionary, d: Dictionary) -> bool: return float(a["t"]) < float(d["t"]))
			var kept: Array = []
			for l: Dictionary in list:
				var beaten: bool = false
				for k: Dictionary in kept:
					if _beats(k, l):
						beaten = true
						break
				if not beaten:
					kept.append(l)
				if kept.size() >= CentipedeEscape.FRONT:
					break
			out.append_array(kept)
		return out

	func _beats(a: Dictionary, d: Dictionary) -> bool:
		if float(a["t"]) > float(d["t"]) + CentipedeEscape.EPS or float(a["ready"]) > float(d["ready"]) + CentipedeEscape.EPS \
				or float(a["z"]) < float(d["z"]) - CentipedeEscape.EPS:
			return false
		var wa: PackedFloat64Array = a["wakes"]
		var wd: PackedFloat64Array = d["wakes"]
		for i: int in wa.size():
			if wa[i] < wd[i] - CentipedeEscape.EPS:
				return false
		# Joins its smashes made that the other's didn't could wake a centipede later on.
		for key: String in (a["joins"] as Dictionary):
			if not (d["joins"] as Dictionary).has(key):
				return false
		return true

	## True if a runner in any of `where` (section ids) wakes spot `i`'s centipede (its own section, or one joined to it
	## without a dash or by label `n`'s smashes) at track distance `z`.
	func _wakes_at(n: Dictionary, i: int, z: float, where: Array[int]) -> bool:
		# EPS: _wakes asks exactly at the wake distance's edge, where rounding must not put it outside.
		if absf(z - float((spots[i] as Dictionary)["at"])) > _wake_dist(i) + CentipedeEscape.EPS:
			return false
		# An ambush breaks out for a runner that close, wherever they are in its block.
		if ambush[i]:
			return true
		var home: int = homes[i]
		if home < 0:
			return false
		var joins: Dictionary = n["joins"]
		for id: int in where:
			if id < 0:
				continue
			var key: String = "%d|%d" % [id, home]
			if id == home or c.joined.has(key) or joins.has(key):
				return true
		return false

	## How close along the track the runner wakes spot `i`'s centipede: its wake distance, or an ambush's.
	func _wake_dist(i: int) -> float:
		return c.ambush_d if ambush[i] else c.wake_d

	## Records on label `n` the wakes the runner sets off from `z0` to `z1` (times `t0` to `t1`) in sections `where`.
	func _wakes(n: Dictionary, t0: float, t1: float, z0: float, z1: float, where: Array[int]) -> void:
		var wakes: PackedFloat64Array = n["wakes"]
		var changed: bool = false
		for i: int in wakes.size():
			if wakes[i] < INF:
				continue
			# The first moment within its wake distance, if the runner is in a section that wakes it.
			var at: float = float((spots[i] as Dictionary)["at"])
			var d: float = _wake_dist(i)
			var from_z: float = maxf(z0, at - d)
			if from_z > maxf(z1, z0) + CentipedeEscape.EPS or minf(z0, z1) > at + d:
				continue
			if not _wakes_at(n, i, clampf(from_z, minf(z0, z1), maxf(z0, z1)), where):
				continue
			wakes[i] = t0 if z1 <= z0 + CentipedeEscape.EPS or from_z <= z0 else t0 + (from_z - z0) / (z1 - z0) * (t1 - t0)
			changed = true
		if changed:
			n["wakes"] = wakes

	## Checks the runner of label `n` from (`t0`, `z0`) to (`t1`, `z1`) in `lane`, running (`moving`) or standing, in
	## sections `where`, against every centipede awake (wakes first). False at the first moment within reach.
	func _check(n: Dictionary, t0: float, t1: float, z0: float, z1: float, lane: int, moving: bool, where: Array[int]) -> bool:
		_wakes(n, t0, t1, z0, z1, where)
		(n["segs"] as Array).append([t0, t1, z0, z1, lane, moving, false, where])
		return _clear(n["wakes"], t0, t1, z0, z1, lane, moving, fields)

	func _clear(wakes: PackedFloat64Array, t0: float, t1: float, z0: float, z1: float, lane: int, moving: bool,
			use: Array) -> bool:
		var awake: bool = false
		for w: float in wakes:
			awake = awake or w < INF
		if not awake:
			return true
		if moving and z1 > z0 + CentipedeEscape.EPS:
			var steps: int = maxi(int(ceil((z1 - z0) / (CentipedeMaze.BIN * 0.5))), 1)
			for j: int in steps + 1:
				var u: float = float(j) / steps
				if not _safe_at(wakes, lerpf(t0, t1, u), lerpf(z0, z1, u), lane, use):
					return false
			return true
		return _safe_at(wakes, t1, z1, lane, use) and _safe_at(wakes, t0, z0, lane, use)

	func _safe_at(wakes: PackedFloat64Array, t: float, z: float, lane: int, use: Array) -> bool:
		var k: int = c.maze.bin_of(z)
		for i: int in wakes.size():
			if wakes[i] == INF or t < wakes[i]:
				continue
			var d: int = (use[i] as PackedInt32Array)[lane * c.maze.size + k]
			if d >= CentipedeMaze.FAR:
				continue
			var gone: float = CentipedeEscape.run_reach(t - wakes[i] - c.wake_time, c.chase, c.accel)
			if float(d) * CentipedeMaze.BIN <= gone + c.reach:
				return false
		return true

	## Checks label `best`'s whole way (`story`, _history) again with its smashes open from the start (see the header): -1
	## if it holds, else the index (in its dash list) of the last dash before it fails, the one to drop.
	func _validate(best: Dictionary, story: Dictionary) -> int:
		if (story["smashes"] as Array).is_empty():
			return -1
		var extra: Dictionary = {}
		for e: Dictionary in story["smashes"]:
			extra[e] = true
		var use: Array = []
		for spot: Dictionary in spots:
			var open: Dictionary = extra.duplicate()
			open.merge(hosts)
			use.append(c.maze.field(int(spot["lane"]), float(spot["at"]), open))
		var wakes := PackedFloat64Array()
		for i: int in spots.size():
			wakes.append(INF)
		# Every join the way's smashes make, from the start.
		var probe: Dictionary = {"wakes": wakes, "joins": best["joins"]}
		for seg: Array in story["segs"]:
			var where: Array[int] = []
			where.assign(seg[7])
			_wakes(probe, float(seg[0]), float(seg[1]), float(seg[2]), float(seg[3]), where)
			if bool(seg[6]):
				continue
			if not _clear(probe["wakes"], float(seg[0]), float(seg[1]), float(seg[2]), float(seg[3]), int(seg[4]),
					bool(seg[5]), use):
				var times: Array = story["dash_t"]
				var bad: int = 0
				for i: int in times.size():
					if float(times[i]) <= float(seg[1]):
						bad = i
				return bad
		return -1

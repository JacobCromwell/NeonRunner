class_name DebrisMaze
extends RefCounted
## The debris maze (task O2; the owner, October 20, 2026, GDD §5 Zone 8: in the Terminal "doodads stand so thickly that
## the empty space between them forms a maze, and the runner can't get through without dashing. The player has to look
## and think ahead to choose where to break through with the dash"; its first level "the debris maze", its second "a
## normal run with stretches of maze"). The `debris_maze` feature's rules (scripts/enemies/debris_maze_rules.gd) run
## place() with the rules; this builds the maze and answers questions about it.
##
## The model. The maze comes in blocks, one to a slot of the level (DebrisMazeTuning: as many equal slots from the
## feature's start to the end-clear stretch as blocks of block_seconds fill level_share of it; each slot normal track,
## then the block's run-in, the block and its breather, open floor in every lane before and after it). A block is a row
## of walls with rooms between them, rows of debris across the track with openings, cells and corridors:
## - a wall: debris across every lane but its openings, one size class deep (medium or large: WALL_SIZES, wide enough
##   that a body never slips between two side by side), its pieces' fronts level, so a stopped runner moves along its
##   face (Player._lane_blocked) to an opening, or dashes through it;
## - a room: from one wall's back to the next one's front, every lane open but its dividers, debris along a lane the
##   room's whole length (touching both walls), so the open lanes between dividers are its cells: corridors the runner
##   moves about in freely, joined to the cells of the rooms either side through the walls' openings (an opening is a
##   lane open on both sides of its wall). Never two dividers side by side, never every lane.
## A runner meets a block at its run-in in any lane; a cell with no opening ahead in its lanes is a dead end, and a dash
## through the wall (from any of its lanes: into the next room's cell in that lane, or, where the lane is a divider
## there, into the divider, whose smashed lane leads into the cells either side) or a wait for one is the only way on.
## The least dashes the block's best way through takes (min_breaks: a search over its cells, the openings costing none
## and each dash one) lies between DebrisMazeTuning.breaks_min and breaks_max ("how many breaks are needed"): each block
## draws how many it takes, any in that range as likely, and its walls' openings and rooms' dividers are drawn from the
## level's stream until it takes that many, opening the dash on a best way where it takes too many and closing a wall
## where it takes too few. The dash recharges as it always does (GDD §5: "a runner who meets a wall of debris before the
## dash is ready stands and waits"), so no spacing between breaks.
##
## The few one-lane ceilings (GDD §5: "little shortcuts over part of the maze"): a block, with ceiling_share, gets one
## over its last wall, its pad in a lane of an open cell of its last room the runner can reach (a dead end where there is
## one, so the ceiling saves a dash), its hull one lane wide (LevelConfig.one_lane_ceiling_seconds from the pad), its
## rider coming down past the last wall over the breather, which no debris reaches for a ceiling drop's fall in any lane
## (drop_room: a mid-air switch never lands one on a doodad's top). The patterns' ceilings in a block's way go (a level
## that lists `ceilings` keeps one: its first block with room takes a ceiling then).
##
## What it adds to the layout: each block's record (LevelLayout.maze: {entry, start, end, exit, walls, rooms, breaks}),
## its debris (LevelLayout.doodads entries marked "maze", "part" and "index", which TrackBuilder builds as any doodad, at
## the level's doodad height: LevelConfig.doodad_height), and its ceilings (hulls marked "maze"). Every pass after the
## rules keeps off a block from its run-in to exit_clear_seconds past a dash's carry out of its last wall (keep_outs: the
## rules' doodad_keep_outs and fill_keep_outs), so the level's holes, its zone doodads and the rest stand clear of it:
## a dash or a stop never lands a runner in a hole. LayoutChecks.check_debris_maze proves every built maze finishable
## with the dash at its slowest recharge (MazeRoute, tests/helpers/maze_route.gd).
##
## For what lives in the maze (task O3's centipedes, GDD §9.15: they wait "in the open sections between the debris",
## move along its open paths and "can't pass debris"): sections() lists every open section (a block's run-in, each
## room's cells, its breather), links() which of them join without a dash (through an opening; with `broken`, also
## where a dash has smashed a wall's or a divider's piece on this attempt), open_group() the sections one can reach
## from another along them, section_at() the section a spot of the track is in, and min_breaks() the least dashes a
## block takes. DESIGN-TBD (docs/questions/o2.md): every number (DebrisMazeTuning), the model, the ceilings.

const FEATURE: String = "debris_maze"
const TUNING_PATH: String = "res://data/tuning/debris_maze.tres"
const POWERUPS_PATH: String = "res://data/tuning/powerups.tres"
## The size classes a wall is built of: wide enough (MovementTuning.doodad_medium_width, doodad_large_width: 1.9 m and
## 2.0 m in 2.4 m lanes) that two side by side leave less than a body's width (visual_size.x, 0.6 m) between them.
const WALL_SIZES: Array[StringName] = [&"medium", &"large"]
## The space between two pieces of debris along a lane (a divider's, and a divider's and a wall's): a sliver, far too
## narrow to stand in, so their boxes' faces never lie in one plane (LevelGenerator.DOODAD_ROW_TOUCH).
const TOUCH: float = LevelGenerator.DOODAD_ROW_TOUCH
## How many times a block's dividers and openings are drawn before the one closest to its breaks is kept.
const DRAWS: int = 12
## Repairs (an opening made, a wall closed) one draw may take to bring its breaks into range.
const REPAIRS: int = 24
## Clear floor kept in a ceiling's pad's lane before it, past a lane switch at run speed (metres): a runner in its cell
## can line up with it, and one coming along its lane who'd rather stay on the floor can switch out of its way.
const PAD_LEAD: float = 4.0
## Clear floor past where a ceiling rider has fallen below the debris's top, in every lane (metres; drop_room).
const DROP_MARGIN: float = 2.0
## Seconds of run a ceiling's lift keeps its pad's lane clear past the pad, beyond the time the lift takes to carry its
## rider over the debris's top (pad_rise: the rider is on the ceiling's surface then, which no doodad stops).
const RISE_MARGIN: float = 0.15


## The maze's numbers for `config`: its own (LevelConfig.debris_maze_tuning), else data/tuning/debris_maze.tres.
static func tuning_for(config: LevelConfig) -> DebrisMazeTuning:
	if config != null and config.debris_maze_tuning != null:
		return config.debris_maze_tuning
	var res: Resource = load(TUNING_PATH) if ResourceLoader.exists(TUNING_PATH) else null
	return res as DebrisMazeTuning if res is DebrisMazeTuning else DebrisMazeTuning.new()


## The dash's carry (metres at `gen`'s run speed): how far a dash takes the runner, at its speed, from where it starts
## (PowerupTuning.dash_duration and dash_speed_bonus).
static func dash_carry(gen: LevelGenerator) -> float:
	var pt := load(POWERUPS_PATH) as PowerupTuning
	if pt == null:
		pt = PowerupTuning.new()
	return (gen.speed + pt.dash_speed_bonus) * pt.dash_duration


## The stretch every pass after the rules keeps off around block `b` (a LevelLayout.maze record), in every lane: from its
## run-in's start to exit_clear_seconds past a dash's carry out of its last wall (and never short of its breather's
## start).
static func keep_out(gen: LevelGenerator, b: Dictionary, t: DebrisMazeTuning = null) -> Vector2:
	var tun: DebrisMazeTuning = t if t != null else tuning_for(gen.config)
	return Vector2(float(b["entry"]), float(b["end"]) + dash_carry(gen) + tun.exit_clear_seconds * gen.speed)


## Every block's keep_out in `gen`'s layout, in order.
static func keep_outs(gen: LevelGenerator) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var t: DebrisMazeTuning = tuning_for(gen.config)
	for b: Dictionary in gen.layout.maze:
		out.append(keep_out(gen, b, t))
	return out


## Builds the level's maze (see the header) into `gen`'s layout. Returns its report (LevelGenerator.debris_maze_result):
## {} without the feature; else {slots, blocks, debris, ceilings, ceilings_out (the patterns' ceilings taken out of the
## blocks' way), breaks (each block's least dashes), constraints (why a slot has no block, or a block no ceiling)}.
static func place(gen: LevelGenerator) -> Dictionary:
	var config: LevelConfig = gen.config
	var lay: LevelLayout = gen.layout
	if not config.has_feature(FEATURE) or lay.lane_count < 2:
		return {}
	var t: DebrisMazeTuning = tuning_for(config)
	var rng: RandomNumberGenerator = gen.rng_for(FEATURE)
	var v: float = gen.speed
	var report := {"slots": 0, "blocks": 0, "debris": 0, "ceilings": 0, "ceilings_out": 0, "breaks": [],
		"constraints": []}
	var from: float = maxf(config.start_clear_distance, gen.feature_start(FEATURE))
	var to: float = lay.length - config.end_clear_distance
	var seconds: float = (to - from) / v
	if seconds <= t.run_in_seconds + t.breather_seconds:
		(report["constraints"] as Array).append("no room for a block between the feature's start and the end-clear stretch")
		return report
	var count: int = maxi(1, roundi(seconds * t.level_share / t.block_seconds))
	var slot: float = seconds / count
	var block_seconds: float = minf(t.block_seconds, slot - t.run_in_seconds - t.breather_seconds)
	report["slots"] = count
	var keep_more: float = dash_carry(gen) + t.exit_clear_seconds * v
	for k: int in count:
		var slot_end: float = from + (k + 1) * slot * v
		var start: float = slot_end - (t.breather_seconds + block_seconds) * v
		var entry: float = start - t.run_in_seconds * v
		var block: Dictionary = _plan_block(gen, t, rng, start, slot_end - t.breather_seconds * v)
		if block.is_empty():
			(report["constraints"] as Array).append("slot %d: no room for %d rooms" % [k, t.min_rooms])
			continue
		block["entry"] = entry
		# Its breather is what every later pass keeps clear past it (keep_out), within its slot.
		block["exit"] = minf(slot_end, float(block["end"]) + keep_more)
		var in_way: String = _in_way(gen, entry, float(block["end"]) + keep_more)
		if in_way != "":
			(report["constraints"] as Array).append("slot %d: %s in the way" % [k, in_way])
			continue
		report["ceilings_out"] = int(report["ceilings_out"]) + _clear_ceilings(gen, entry, float(block["end"]) + keep_more)
		report["debris"] = int(report["debris"]) + _add_block(gen, block)
		(report["breaks"] as Array).append(int(block["breaks"]))
	report["blocks"] = lay.maze.size()
	report["ceilings"] = _place_ceilings(gen, t, report)
	return report


# --- A block's plan ------------------------------------------------------------------------------

## A block from its first wall's front at `start`, its last wall ending by `end_by` (see the header): {start, end,
## walls, rooms, breaks}, the walls' sizes and the rooms' lengths first (each room as long as its dividers' pieces fill,
## about room_seconds a wall and a room), then the dividers and openings drawn until its least dashes fit the tuning's
## breaks. {} where fewer than min_rooms rooms fit.
static func _plan_block(gen: LevelGenerator, t: DebrisMazeTuning, rng: RandomNumberGenerator, start: float,
		end_by: float) -> Dictionary:
	var walls: Array[Dictionary] = []
	var rooms: Array[Dictionary] = []
	var pitch: float = t.room_seconds * gen.speed
	var shallow: float = gen.tuning.doodad_size(WALL_SIZES[0]).z
	var cursor: float = start
	while true:
		var size: StringName = WALL_SIZES[1] if rng.randf() < t.large_wall_share else WALL_SIZES[0]
		if cursor + gen.tuning.doodad_size(size).z > end_by:
			size = WALL_SIZES[0]
		var depth: float = gen.tuning.doodad_size(size).z
		if cursor + depth > end_by + 0.001:
			break
		walls.append({"start": cursor, "end": cursor + depth, "size": size, "open": []})
		cursor += depth
		var fill: Array[StringName] = _fill(gen.tuning, pitch - depth)
		var length: float = fill_length(gen.tuning, fill)
		if cursor + length + shallow > end_by + 0.001:
			break
		rooms.append({"start": cursor, "end": cursor + length, "dividers": [], "fill": fill})
		cursor += length
	if rooms.size() < maxi(t.min_rooms, 1) or walls.size() != rooms.size() + 1:
		return {}
	var lanes: int = gen.layout.lane_count
	var lo: int = mini(t.breaks_min, t.breaks_max)
	var hi: int = maxi(t.breaks_min, t.breaks_max)
	# How many this block takes: any in the range, as likely.
	var target: int = rng.randi_range(lo, hi)
	var best: Dictionary = {}
	var best_miss: int = 1 << 30
	for draw: int in DRAWS:
		var shape: Dictionary = _draw_shape(rng, t, lanes, rooms.size())
		var breaks: int = _repair(rng, lanes, shape, target)
		# Out of the range counts far more than off the target.
		var miss: int = absi(breaks - target) + 100 * (maxi(lo - breaks, 0) + maxi(breaks - hi, 0))
		if miss < best_miss:
			best_miss = miss
			best = shape
			best["breaks"] = breaks
		if miss == 0:
			break
	for i: int in walls.size():
		walls[i]["open"] = (best["open"] as Array)[i]
	for i: int in rooms.size():
		rooms[i]["dividers"] = (best["dividers"] as Array)[i]
	return {"start": start, "end": float(walls[-1]["end"]), "walls": walls, "rooms": rooms, "breaks": best["breaks"]}


## The pieces a divider `target` metres long (about) is made of, longest first as far as they go (large, medium,
## small: each followed by TOUCH), the last small one only where it brings the length nearer `target`.
static func _fill(tun: MovementTuning, target: float) -> Array[StringName]:
	var out: Array[StringName] = []
	var used: float = TOUCH
	for size: StringName in [&"large", &"medium", &"small"]:
		var step: float = tun.doodad_size(size).z + TOUCH
		while used + step <= target:
			out.append(size)
			used += step
	var small: float = tun.doodad_size(&"small").z + TOUCH
	if out.is_empty() or target - used > small * 0.5:
		out.append(&"small")
	return out


## How long a room whose dividers are made of `fill` is (metres): every piece, a TOUCH before each and after the last.
static func fill_length(tun: MovementTuning, fill: Array) -> float:
	var out: float = TOUCH
	for size: Variant in fill:
		out += tun.doodad_size(StringName(size)).z + TOUCH
	return out


## A first draw of a block's dividers and openings, `rooms` rooms in `lanes` lanes: {dividers: [rooms' lanes], open:
## [walls' lanes]}. Each lane of a room a divider with divider_share (never beside another, never every lane); each lane
## of a wall open with opening_share where the lanes either side of it are open (the run-in before the first wall and
## the breather after the last are open in every lane), never every lane.
static func _draw_shape(rng: RandomNumberGenerator, t: DebrisMazeTuning, lanes: int, rooms: int) -> Dictionary:
	var dividers: Array = []
	for r: int in rooms:
		var d: Array[int] = []
		for lane: int in lanes:
			if rng.randf() < t.divider_share and not d.has(lane - 1) and d.size() + 1 < lanes:
				d.append(lane)
		dividers.append(d)
	var open: Array = []
	for w: int in rooms + 1:
		var o: Array[int] = []
		for lane: int in _openable(dividers, w, lanes):
			if rng.randf() < t.opening_share:
				o.append(lane)
		if o.size() >= lanes:
			o.remove_at(rng.randi_range(0, o.size() - 1))
		open.append(o)
	return {"dividers": dividers, "open": open}


## The lanes wall `w` may open in: open in the room before it and the one after it (every lane before the first wall and
## after the last).
static func _openable(dividers: Array, w: int, lanes: int) -> Array[int]:
	var out: Array[int] = []
	for lane: int in lanes:
		if w > 0 and (dividers[w - 1] as Array).has(lane):
			continue
		if w < dividers.size() and (dividers[w] as Array).has(lane):
			continue
		out.append(lane)
	return out


## Brings `shape`'s least dashes (search()) to `target`, REPAIRS steps at most: where it takes too many, the first dash on
## a best way through becomes an opening (in the lane it dashed through, or another of its cell that opens there, else
## that lane's divider in the room after it goes); where too few, a wall with openings (a random one) closes them all.
## Returns the least dashes it ends with.
static func _repair(rng: RandomNumberGenerator, lanes: int, shape: Dictionary, target: int) -> int:
	var dividers: Array = shape["dividers"]
	var open: Array = shape["open"]
	for step: int in REPAIRS:
		var found: Dictionary = search(dividers, open, lanes)
		var breaks: int = int(found["breaks"])
		if breaks > target:
			var dash: Dictionary = (found["dashes"] as Array)[0]
			var w: int = int(dash["wall"])
			var lane: int = int(dash["lane"])
			var choices: Array[int] = []
			for l: int in _openable(dividers, w, lanes):
				if l >= int(dash["first"]) and l <= int(dash["last"]) and not (open[w] as Array).has(l):
					choices.append(l)
			if choices.has(lane):
				(open[w] as Array).append(lane)
			elif not choices.is_empty():
				(open[w] as Array).append(choices[rng.randi_range(0, choices.size() - 1)])
			elif w < dividers.size():
				(dividers[w] as Array).erase(lane)
				if _openable(dividers, w, lanes).has(lane):
					(open[w] as Array).append(lane)
			else:
				return breaks
			(open[w] as Array).sort()
			continue
		if breaks < target:
			var walls: Array[int] = []
			for w: int in open.size():
				if not (open[w] as Array).is_empty():
					walls.append(w)
			if walls.is_empty():
				return breaks
			(open[walls[rng.randi_range(0, walls.size() - 1)]] as Array).clear()
			continue
		return breaks
	return int(search(dividers, open, lanes)["breaks"])


## The cells of a room with `dividers` in `lanes` lanes: each a Vector2i(first lane, last lane) of open lanes between
## dividers, left to right.
static func cells_of(dividers: Array, lanes: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var first: int = -1
	for lane: int in lanes + 1:
		var open: bool = lane < lanes and not dividers.has(lane)
		if open and first < 0:
			first = lane
		elif not open and first >= 0:
			out.append(Vector2i(first, lane - 1))
			first = -1
	return out


## The least dashes a block whose rooms have `dividers` and whose walls have the openings `open` takes, from its run-in
## (every lane) to its breather (every lane), in `lanes` lanes: a search over its cells (rooms -1, the run-in, to the
## room count, the breather), where an opening of a wall joins the cells either side of it in its lane at no cost, and
## a dash through a wall from a cell, in any of its lanes, costs one and comes out in the next room's cell in that lane,
## or, where the lane is a divider there, in a cell either side of it (the smashed divider's lane leads into both).
## Returns {breaks, reached (room -> the cells reached, each with its least dashes: Array of Vector2i(cell index,
## dashes), -1 for none), dashes (the dashes along a best way through, in order: {wall, lane, first, last}, the cell it
## dashed from)}.
static func search(dividers: Array, open: Array, lanes: int) -> Dictionary:
	var rooms: int = dividers.size()
	# cells[r + 1]: room r's cells; the run-in's and the breather's are every lane.
	var cells: Array = [[Vector2i(0, lanes - 1)]]
	for r: int in rooms:
		cells.append(cells_of(dividers[r], lanes))
	cells.append([Vector2i(0, lanes - 1)])
	var best: Array = []  # best[r + 1][c]: least dashes to cell c of room r (INF none)
	var came: Array = []  # came[r + 1][c]: [cell index in room r - 1, wall, lane, dashed]
	for list: Variant in cells:
		var row: Array[int] = []
		var from_row: Array = []
		for c: Variant in list:
			row.append(1 << 30)
			from_row.append([])
		best.append(row)
		came.append(from_row)
	best[0][0] = 0
	for w: int in rooms + 1:
		var here: Array = cells[w]
		var there: Array = cells[w + 1]
		for c: int in here.size():
			var cost: int = best[w][c]
			if cost >= 1 << 30:
				continue
			var cell: Vector2i = here[c]
			for lane: int in range(cell.x, cell.y + 1):
				var opening: bool = (open[w] as Array).has(lane)
				var targets: Array[int] = []
				var into: int = cell_index(there, lane)
				if into >= 0:
					targets.append(into)
				elif not opening:
					for side: int in [lane - 1, lane + 1]:
						var beside: int = cell_index(there, side)
						if beside >= 0 and not targets.has(beside):
							targets.append(beside)
				var step: int = 0 if opening and into >= 0 else 1
				for to: int in targets:
					if cost + step < int(best[w + 1][to]):
						best[w + 1][to] = cost + step
						came[w + 1][to] = [c, w, lane, step == 1]
	var dashes: Array[Dictionary] = []
	var at: int = 0
	for r: int in range(rooms + 1, 0, -1):
		var back: Array = came[r][at]
		if back.is_empty():
			break
		if bool(back[3]):
			var from_cell: Vector2i = (cells[r - 1] as Array)[int(back[0])]
			dashes.push_front({"wall": int(back[1]), "lane": int(back[2]), "first": from_cell.x, "last": from_cell.y})
		at = int(back[0])
	var reached: Dictionary = {}
	for r: int in range(-1, rooms + 1):
		var row: Array = []
		for c: int in (cells[r + 1] as Array).size():
			row.append(Vector2i(c, int(best[r + 1][c]) if int(best[r + 1][c]) < 1 << 30 else -1))
		reached[r] = row
	return {"breaks": int(best[rooms + 1][0]), "reached": reached, "dashes": dashes}


## The index in `cells` (Vector2i(first, last) each) of the cell holding `lane`, or -1.
static func cell_index(cells: Array, lane: int) -> int:
	for i: int in cells.size():
		var c: Vector2i = cells[i]
		if lane >= c.x and lane <= c.y:
			return i
	return -1


# --- On the track --------------------------------------------------------------------------------

## What of the level's own stands in [from, to] that a block can't take out of its way (a hole, a fence, a sign, a ramp,
## a speed pad, a floor cut, an enemy, a dash wall, a wall-run gap, a doodad): its name, or "" if nothing does. The
## patterns' ceilings in its way go (_clear_ceilings).
static func _in_way(gen: LevelGenerator, from: float, to: float) -> String:
	var lay: LevelLayout = gen.layout
	for g: Dictionary in lay.gaps:
		if float(g["start"]) <= to and float(g["end"]) >= from:
			return "a hole"
	for f: Dictionary in lay.fences:
		if float(f["at"]) >= from and float(f["at"]) <= to:
			return "a fence"
	for s: Dictionary in lay.signs:
		if float(s["start"]) <= to and float(s["end"]) >= from:
			return "a sign"
	for r: Dictionary in lay.ramps:
		if float(r["at"]) >= from - gen.tuning.ramp_length and float(r["at"]) <= to:
			return "a ramp"
	for p: Dictionary in lay.speed_pads:
		if float(p["at"]) >= from - gen.tuning.speed_pad_length and float(p["at"]) <= to:
			return "a speed pad"
	if lay.cut_between(from, to):
		return "a floor cut"
	for e: Dictionary in lay.enemies:
		var span: Vector2 = LevelGenerator.enemy_floor_span(e, gen.pace)
		if (span.x <= to and span.y >= from) or (float(e["at"]) >= from and float(e["at"]) <= to):
			return "an enemy (%s)" % e.get("type", "?")
	if lay.dash_wall_between(from, to):
		return "a dash wall"
	if lay.wall_run_zone_between(from, to):
		return "a wall-run gap"
	for d: Dictionary in lay.doodads:
		if float(d["start"]) <= to and float(d["end"]) >= from:
			return "a doodad"
	return ""


## Takes the patterns' ceilings in [from, to] out (every lane): each whose hull, from its start to a drop's fall past its
## end (drop_room), reaches into it, with its pads. Returns how many went.
static func _clear_ceilings(gen: LevelGenerator, from: float, to: float) -> int:
	var lay: LevelLayout = gen.layout
	var fall: float = drop_room(gen)
	var kept: Array[Dictionary] = []
	var gone: Array[Dictionary] = []
	for h: Dictionary in lay.hulls:
		if float(h["start"]) <= to and float(h["end"]) + fall >= from:
			gone.append(h)
		else:
			kept.append(h)
	if gone.is_empty():
		return 0
	lay.hulls = kept
	var pads: Array[Dictionary] = []
	for p: Dictionary in lay.pads:
		var under: bool = false
		for h: Dictionary in gone:
			under = under or (float(p["at"]) >= float(h["start"]) and float(p["at"]) <= float(h["end"]))
		if not under:
			pads.append(p)
	lay.pads = pads
	return gone.size()


## Puts block `block`'s record (without its rooms' fills) and its debris into `gen`'s layout. Returns how many pieces.
static func _add_block(gen: LevelGenerator, block: Dictionary) -> int:
	var lay: LevelLayout = gen.layout
	var index: int = lay.maze.size()
	var lanes: int = lay.lane_count
	var rng: RandomNumberGenerator = gen.rng_for("%s_looks_%d" % [FEATURE, index])
	var pieces: int = 0
	var walls: Array = block["walls"]
	var rooms: Array = block["rooms"]
	for w: int in walls.size():
		var wall: Dictionary = walls[w]
		for lane: int in lanes:
			if not (wall["open"] as Array).has(lane):
				_add_piece(gen, index, "wall", w, lane, float(wall["start"]), StringName(wall["size"]))
				pieces += 1
	for r: int in rooms.size():
		var room: Dictionary = rooms[r]
		for lane: int in room["dividers"]:
			# Each divider its own order of the room's pieces (the same length): their seams needn't line up.
			var fill: Array = (room["fill"] as Array).duplicate()
			for i: int in range(fill.size() - 1, 0, -1):
				var j: int = rng.randi_range(0, i)
				var swap: Variant = fill[i]
				fill[i] = fill[j]
				fill[j] = swap
			var at: float = float(room["start"]) + TOUCH
			for size: Variant in fill:
				_add_piece(gen, index, "divider", r, lane, at, StringName(size))
				at += gen.tuning.doodad_size(StringName(size)).z + TOUCH
				pieces += 1
	var record_rooms: Array[Dictionary] = []
	for room: Dictionary in rooms:
		var dividers: Array = (room["dividers"] as Array).duplicate()
		dividers.sort()
		record_rooms.append({"start": float(room["start"]), "end": float(room["end"]), "dividers": dividers})
	var record_walls: Array[Dictionary] = []
	for wall: Dictionary in walls:
		var open: Array = (wall["open"] as Array).duplicate()
		open.sort()
		record_walls.append({"start": float(wall["start"]), "end": float(wall["end"]), "size": String(wall["size"]),
			"open": open})
	lay.maze.append({"entry": float(block["entry"]), "start": float(block["start"]), "end": float(block["end"]),
		"exit": float(block["exit"]), "walls": record_walls, "rooms": record_rooms, "breaks": int(block["breaks"])})
	return pieces


## One piece of debris: a LevelLayout.doodads entry of `size` in `lane` from `start`, marked with its block (`maze`), its
## part ("wall" or "divider") and that part's index (the wall's, or the room's); its seed counts the doodads before it.
## It pushes toward the middle of the track where a push is asked of it (a level whose doodads stop the runner never
## does).
static func _add_piece(gen: LevelGenerator, block: int, part: String, index: int, lane: int, start: float,
		size: StringName) -> void:
	var lay: LevelLayout = gen.layout
	lay.doodads.append({"lane": lane, "start": start, "end": start + gen.tuning.doodad_size(size).z, "size": size,
		"side": 1 if lane * 2 < lay.lane_count - 1 else -1, "seed": hash([gen.config.level_seed, FEATURE, lay.doodads.size()]),
		"maze": block, "part": part, "index": index})


# --- Ceilings ------------------------------------------------------------------------------------

## How far past a ceiling's end its rider falls before their body comes down below the debris's top (metres at `gen`'s
## run speed), with DROP_MARGIN: until then a rider dropping off a one-lane ceiling (switching lanes in the air too)
## would come down on a doodad's top, so no debris stands there in any lane.
static func drop_room(gen: LevelGenerator) -> float:
	var g: float = maxf(gen.tuning.gravity() * gen.tuning.fall_gravity_multiplier, 0.01)
	var fall: float = maxf(gen.tuning.ceiling_height - gen.tuning.doodad_height, 0.0)
	return sqrt(2.0 * fall / g) * gen.speed + DROP_MARGIN


## How far past its pad's front a ceiling's pad keeps its lane clear (metres at `gen`'s run speed): the pad, and the run
## while its lift carries the rider up until their head is over the debris's top (they ride the ceiling's surface from
## the pad on, which no doodad stops), and RISE_MARGIN.
static func pad_rise(gen: LevelGenerator) -> float:
	var tun: MovementTuning = gen.tuning
	var v0: float = tun.antigrav_launch_velocity
	var a: float = maxf(tun.gravity() * tun.fall_gravity_multiplier, 0.01)
	# The rider's depth below the ceiling at which their head clears the debris's top.
	var depth: float = maxf(tun.ceiling_height - tun.doodad_height - tun.visual_size.y, 0.0)
	var climb: float = maxf(tun.ceiling_height - depth, 0.0)
	var seconds: float = (-v0 + sqrt(v0 * v0 + 2.0 * a * climb)) / a
	return tun.pad_length + (seconds + RISE_MARGIN) * gen.speed


## Gives blocks their one-lane ceilings (see the header): each block with ceiling_share (a stream of its own), and, in a
## level that lists `ceilings` and has none left, the first block with room for one. Returns how many it added; why a
## block chosen got none goes into the report's constraints.
static func _place_ceilings(gen: LevelGenerator, t: DebrisMazeTuning, report: Dictionary) -> int:
	var lay: LevelLayout = gen.layout
	if not gen.config.has_feature("ceilings") or lay.maze.is_empty():
		return 0
	var rng: RandomNumberGenerator = gen.rng_for(FEATURE + "_ceilings")
	var added: int = 0
	var chosen: Array[bool] = []
	for b: Dictionary in lay.maze:
		chosen.append(rng.randf() < t.ceiling_share)
	for i: int in lay.maze.size():
		if chosen[i]:
			var why: String = _add_ceiling(gen, rng, i)
			if why == "":
				added += 1
			else:
				(report["constraints"] as Array).append("block %d: no ceiling (%s)" % [i, why])
	if lay.hulls.is_empty():
		for i: int in lay.maze.size():
			if not chosen[i] and _add_ceiling(gen, rng, i) == "":
				added += 1
				break
	return added


## A one-lane ceiling over block `index`'s last wall (see the header), or why there's none: its pad in a lane of a cell
## of the last room the runner can reach (a dead end first) that the last wall closes, the cell two lanes wide or more
## (a runner who'd rather stay on the floor passes the pad beside it), PAD_LEAD and a lane switch clear before the pad
## and pad_rise past it, its rider's drop past the last wall clear of debris in every lane until the next block's first
## wall (drop_room), and everything add_hull_with_pad asks (a pad that can be stepped on, a safe landing, no other
## ceiling near). "" once it's added.
static func _add_ceiling(gen: LevelGenerator, rng: RandomNumberGenerator, index: int) -> String:
	var lay: LevelLayout = gen.layout
	var b: Dictionary = lay.maze[index]
	var rooms: Array = b["rooms"]
	var walls: Array = b["walls"]
	var room: Dictionary = rooms[-1]
	var last: Dictionary = walls[-1]
	var length: float = gen.config.one_lane_ceiling_seconds * gen.speed
	var lo: float = float(room["start"]) + gen.tuning.lane_switch_time * gen.speed + PAD_LEAD
	var hi: float = float(last["start"]) - pad_rise(gen)
	if hi < lo:
		return "the last room is too short for a pad"
	var next_wall: float = lay.length - gen.config.end_clear_distance
	if index + 1 < lay.maze.size():
		next_wall = float(lay.maze[index + 1]["start"])
	# The pad as late as it may be (the rider skips the most), and no later than leaves its drop clear.
	var at: float = minf(hi, next_wall - drop_room(gen) - length)
	if at < lo or at + length < float(last["end"]) + gen.tuning.visual_size.z:
		return "no room for its rider's drop past the last wall"
	var shape: Dictionary = shape_of(b)
	var found: Dictionary = search(shape["dividers"], shape["open"], lay.lane_count)
	var reached: Array = (found["reached"] as Dictionary)[rooms.size() - 1]
	var cells: Array[Vector2i] = cells_of(room["dividers"], lay.lane_count)
	var dead: Array[int] = []
	var other: Array[int] = []
	for c: int in cells.size():
		var cell: Vector2i = cells[c]
		if int((reached[c] as Vector2i).y) < 0 or cell.y == cell.x:
			continue
		var exits: bool = false
		for lane: int in range(cell.x, cell.y + 1):
			exits = exits or (last["open"] as Array).has(lane)
		for lane: int in range(cell.x, cell.y + 1):
			if not (last["open"] as Array).has(lane):
				(other if exits else dead).append(lane)
	for lanes: Array[int] in [dead, other]:
		while not lanes.is_empty():
			var lane: int = lanes.pop_at(rng.randi_range(0, lanes.size() - 1))
			if gen.add_hull_with_pad(lane, at, length / gen.speed, Vector2i(lane, lane)):
				lay.hulls[-1]["maze"] = index
				return ""
	return "no lane where a pad and a landing fit"


# --- Questions about the maze (for what lives in it: task O3) -------------------------------------

## Block record `b`'s rooms' dividers and walls' openings, the way search() takes them: {dividers, open}.
static func shape_of(b: Dictionary) -> Dictionary:
	var dividers: Array = []
	for room: Dictionary in b["rooms"]:
		dividers.append(room["dividers"])
	var open: Array = []
	for wall: Dictionary in b["walls"]:
		open.append(wall["open"])
	return {"dividers": dividers, "open": open}


## The least dashes block record `b` takes from its run-in to its breather (search()).
static func min_breaks(b: Dictionary, lanes: int) -> int:
	var shape: Dictionary = shape_of(b)
	return int(search(shape["dividers"], shape["open"], lanes)["breaks"])


## Every open section of `layout`'s debris maze, in order of the track: for each block its run-in, each room's cells
## left to right, and its breather, each {block, room, first, last, start, end} (lanes `first` to `last` open from track
## distance `start` to `end`; `room` -1 for the run-in, the room's index for a cell, the block's room count for the
## breather). An index into this list is a section's id for links(), open_group() and section_at().
static func sections(layout: LevelLayout) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lanes: int = layout.lane_count
	for i: int in layout.maze.size():
		var b: Dictionary = layout.maze[i]
		var rooms: Array = b["rooms"]
		out.append({"block": i, "room": -1, "first": 0, "last": lanes - 1, "start": float(b["entry"]),
			"end": float(b["start"])})
		for r: int in rooms.size():
			var room: Dictionary = rooms[r]
			for c: Vector2i in cells_of(room["dividers"], lanes):
				out.append({"block": i, "room": r, "first": c.x, "last": c.y, "start": float(room["start"]),
					"end": float(room["end"])})
		out.append({"block": i, "room": rooms.size(), "first": 0, "last": lanes - 1, "start": float(b["end"]),
			"end": float(b["exit"])})
	return out


## Where the sections of `layout`'s maze (`secs`, as sections() gives them) join without a dash, each {from, to, lane,
## at, kind} (section ids, `from` the earlier along the track): an opening of a wall joins the sections either side of it
## in its lane (`at` the wall's front, kind "opening"). With `broken`, also where a dash has smashed a piece on this
## attempt (its layout entry marked "smashed"): a wall's piece joins the sections either side in its lane like an
## opening, where its lane is open there (kind "broken"); a divider's piece joins the cells either side of it in its room
## over its stretch (`at` its front, kind "broken"; the smashed lane between them is open there). A runner goes only
## forward along them; anything else may go either way.
static func links(layout: LevelLayout, secs: Array[Dictionary], broken: bool = false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lanes: int = layout.lane_count
	var smashed_walls: Dictionary = {}  # "block:wall" -> lanes
	var smashed_dividers: Array[Dictionary] = []
	if broken:
		for d: Dictionary in layout.doodads:
			if not LevelLayout.is_maze_debris(d) or not bool(d.get("smashed", false)):
				continue
			if String(d["part"]) == "wall":
				var key: String = "%d:%d" % [int(d["maze"]), int(d["index"])]
				if not smashed_walls.has(key):
					smashed_walls[key] = []
				(smashed_walls[key] as Array).append(int(d["lane"]))
			else:
				smashed_dividers.append(d)
	for i: int in layout.maze.size():
		var b: Dictionary = layout.maze[i]
		var walls: Array = b["walls"]
		for w: int in walls.size():
			var wall: Dictionary = walls[w]
			var lanes_through: Array = (wall["open"] as Array).duplicate()
			var kinds: Dictionary = {}
			for lane: Variant in lanes_through:
				kinds[int(lane)] = "opening"
			for lane: Variant in smashed_walls.get("%d:%d" % [i, w], []):
				if not kinds.has(int(lane)):
					kinds[int(lane)] = "broken"
			for lane: int in kinds:
				var before: int = section_id(secs, i, w - 1, lane)
				var after: int = section_id(secs, i, w, lane)
				if before >= 0 and after >= 0:
					out.append({"from": before, "to": after, "lane": lane, "at": float(wall["start"]), "kind": kinds[lane]})
	for d: Dictionary in smashed_dividers:
		var block: int = int(d["maze"])
		var room: int = int(d["index"])
		var lane: int = int(d["lane"])
		var left: int = section_id(secs, block, room, lane - 1)
		var right: int = section_id(secs, block, room, lane + 1)
		if left >= 0 and right >= 0 and lane > 0 and lane < lanes - 1:
			out.append({"from": left, "to": right, "lane": lane, "at": float(d["start"]), "kind": "broken"})
	return out


## The id of the section of block `block`'s room `room` (-1 the run-in, the room count the breather) holding `lane`, in
## `secs` (sections()), or -1 (a divider there, or no such room).
static func section_id(secs: Array[Dictionary], block: int, room: int, lane: int) -> int:
	for id: int in secs.size():
		var s: Dictionary = secs[id]
		if int(s["block"]) == block and int(s["room"]) == room and lane >= int(s["first"]) and lane <= int(s["last"]):
			return id
	return -1


## The id of the section of `secs` (sections() of `layout`) holding track distance `at` in `lane`, or -1 (debris there,
## or no maze).
static func section_at(secs: Array[Dictionary], lane: int, at: float) -> int:
	for id: int in secs.size():
		var s: Dictionary = secs[id]
		if at >= float(s["start"]) and at <= float(s["end"]) and lane >= int(s["first"]) and lane <= int(s["last"]):
			return id
	return -1


## The sections reachable from section `id` along `links_list` (links()), either way, `id` included: where something
## that can't pass debris and goes either way (a centipede) can get to from there. Sorted.
static func open_group(links_list: Array[Dictionary], id: int) -> PackedInt32Array:
	var seen: Dictionary = {id: true}
	var todo: Array[int] = [id]
	while not todo.is_empty():
		var at: int = todo.pop_back()
		for k: Dictionary in links_list:
			for pair: Array in [[int(k["from"]), int(k["to"])], [int(k["to"]), int(k["from"])]]:
				if int(pair[0]) == at and not seen.has(int(pair[1])):
					seen[int(pair[1])] = true
					todo.append(int(pair[1]))
	var out := PackedInt32Array(seen.keys())
	out.sort()
	return out

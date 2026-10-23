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
## then the block's run-in, the block and its breather, open floor in every lane before and after it; in a level that
## asks for wider gaps, room for one between each two blocks: gap_room). A block is a row of walls with rooms between
## them, rows of debris across the track with openings, cells and corridors:
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
## Escape blocks (task O5; the owner, October 22, 2026: "a section of maze that will make it so the player needs to
## escape using the anti-grav pad"): DebrisMazeTuning.escape_blocks of the slots (_escape_slots) take a block planned
## shorter (_plan_escape_block), its last maze wall opening onto an open room (no dividers) with an anti-grav pad in it,
## then a barrier: a last wall several large pieces deep in every lane, no opening, more than one dash deep
## (escape_pieces), under a one-lane ceiling from the pad to just past its back (_add_escape_ceiling). A runner who
## misses the pad stops at the barrier and needs a second dash, and the wait for it: never stuck. maze_part() is such a
## block without its pad room and barrier: its breaks are the maze's own. DESIGN-TBD (docs/questions/o5.md).
##
## What it adds to the layout: each block's record (LevelLayout.maze: {entry, start, end, exit, walls, rooms, breaks, and an
## escape block's `escape` {lane, at}; a barrier wall's `pieces`}),
## its debris (LevelLayout.doodads entries marked "maze", "part" and "index", which TrackBuilder builds as any doodad, at
## the level's doodad height: LevelConfig.doodad_height), and its ceilings (hulls marked "maze"). Every pass after the
## rules keeps off a block from its run-in to exit_clear_seconds past a dash's carry out of its last wall (keep_outs: the
## rules' doodad_keep_outs and fill_keep_outs), so the level's holes, its zone doodads and the rest stand clear of it:
## a dash or a stop never lands a runner in a hole. LayoutChecks.check_debris_maze proves every built maze finishable
## with the dash at its slowest recharge (MazeRoute, tests/helpers/maze_route.gd).
##
## For what lives in the maze (task O3's centipedes, GDD §9.15: they wait "in the open sections between the debris",
## move along its open paths and "can't pass debris"): sections() lists every open section (a block's run-in, each
## room's cells, its breather, and with `broken` each stretch of a divider that dashes have smashed on this attempt),
## links() which of them join without a dash (through an opening; with `broken`, also through the wall pieces and divider
## stretches smashed on this attempt), open_group() the sections one can reach from another along them, section_at()
## the section a spot of the track is in, and min_breaks() the least dashes a block takes. DESIGN-TBD
## (docs/questions/o2.md): every number (DebrisMazeTuning), the model, the ceilings.

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
## Metres added to the dash's whole run for what it may smash (CentipedeEscape.SMASH_MARGIN): an escape block's barrier
## is deeper than one dash smashes with this on top (escape_pieces).
const SMASH_REACH_MARGIN: float = 1.0
## Metres of an escape block's pad room beyond what its pad needs (escape_room_length).
const ESCAPE_SLACK: float = 1.0
## Metres an escape block's pad lies before where its rise would just clear the barrier (pad_rise), so its lane's floor
## is clear of debris from the pad to past its rise, not only up to it.
const ESCAPE_PAD_EARLY: float = 0.1
## Metres an escape block's ceiling reaches past its barrier's back, beyond the body's depth.
const ESCAPE_HULL_PAST: float = 1.0
## Metres a row of holes between blocks keeps beyond its margin from what's in the way (place_gaps): its edges never
## touch the margin's.
const GAP_EPSILON: float = 0.01
## Seconds of run on top of a wider gap's zone kept free between two blocks (place, gap_room).
const GAP_ROOM_MARGIN: float = 0.25
## How far before a wall's front and past its back links() looks for what a smashed piece of it opens onto (metres):
## less than the sliver (TOUCH) between a wall and a divider's first piece.
const LINK_EPSILON: float = 0.01


## The maze's numbers for `config`: its own (LevelConfig.debris_maze_tuning), else data/tuning/debris_maze.tres.
static func tuning_for(config: LevelConfig) -> DebrisMazeTuning:
	if config != null and config.debris_maze_tuning != null:
		return config.debris_maze_tuning
	var res: Resource = load(TUNING_PATH) if ResourceLoader.exists(TUNING_PATH) else null
	return res as DebrisMazeTuning if res is DebrisMazeTuning else DebrisMazeTuning.new()


## The dash's carry (metres at `gen`'s run speed): how far a dash takes the runner, at its speed, from where it starts
## (PowerupTuning.dash_duration and dash_speed_bonus).
static func dash_carry(gen: LevelGenerator) -> float:
	return dash_speed(gen) * _powerups().dash_duration


## The dash's speed at `gen`'s run speed (m/s: the run's and PowerupTuning.dash_speed_bonus).
static func dash_speed(gen: LevelGenerator) -> float:
	return gen.speed + _powerups().dash_speed_bonus


static func _powerups() -> PowerupTuning:
	var pt := load(POWERUPS_PATH) as PowerupTuning
	return pt if pt != null else PowerupTuning.new()


## How far past a piece of debris's back its lane shows nothing that could catch a runner (metres at `gen`'s run
## speed): a runner whose dash brings them through it sees what it hid only at the smash, so the next thing comes no
## sooner than the reaction after a push (LevelConfig.doodad_reaction_seconds) and a lane switch at the dash's speed,
## as what any doodad hides does (LevelGenerator._place_doodads; test_doodads' dash fairness). A maze ceiling's pad
## keeps it from the wall before it in its lane.
static func hidden_reach(gen: LevelGenerator) -> float:
	return (gen.config.doodad_reaction_seconds + gen.tuning.lane_switch_time) * dash_speed(gen)


## The stretch every pass after the rules keeps off around block `b` (a LevelLayout.maze record), in every lane: from its
## run-in's start to exit_clear_seconds past a dash's carry out of its last wall (and never short of its breather's
## start).
static func keep_out(gen: LevelGenerator, b: Dictionary, t: DebrisMazeTuning = null) -> Vector2:
	var tun: DebrisMazeTuning = t if t != null else tuning_for(gen.config)
	return Vector2(float(b["entry"]), float(b["end"]) + dash_carry(gen) + tun.exit_clear_seconds * gen.speed)


## How long a wider gap's zone is at track distance `at` (metres): the gap at the level's speed and the stretches
## clear of anything before and after it (WideGapPlacement.zone_of, the level's spacing there at the least). place()
## leaves this free between two blocks in a level that asks for wider gaps, so its couple of holes (GDD §5, Zone 8)
## always find room.
static func gap_room(gen: LevelGenerator, at: float) -> float:
	var t: WideGapTuning = WideGapPlacement.tuning()
	var zone: Vector2 = WideGapPlacement.zone_of(gen, t, Vector2(at, at + WideGapPlacement.length_for(gen, t)))
	return zone.y - zone.x


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
	report["slots"] = count
	var keep_more: float = dash_carry(gen) + t.exit_clear_seconds * v
	var escapes: Array[int] = _escape_slots(gen, t, from, slot, count)
	report["escapes"] = 0
	for k: int in count:
		var slot_end: float = from + (k + 1) * slot * v
		# Between this block's keep-out and the next slot's run-in, room for one of the level's wider gaps with its clear
		# stretches (gap_room) where the level asks for them: a block in a slot too tight for it is that much shorter.
		var room: float = t.breather_seconds
		if config.wide_gaps > 0:
			room = maxf(room, (keep_more + gap_room(gen, slot_end)) / v + GAP_ROOM_MARGIN)
		var block_seconds: float = minf(t.block_seconds, slot - t.run_in_seconds - room)
		var start: float = slot_end - (t.breather_seconds + block_seconds) * v
		var entry: float = start - t.run_in_seconds * v
		var end_by: float = slot_end - t.breather_seconds * v
		var escape: bool = escapes.has(k)
		var block: Dictionary = _plan_escape_block(gen, t, rng, start, end_by) if escape else {}
		if escape and block.is_empty():
			(report["constraints"] as Array).append("slot %d: no room for an escape block" % k)
		if block.is_empty():
			block = _plan_block(gen, t, rng, start, end_by)
		if block.is_empty():
			(report["constraints"] as Array).append("slot %d: no room for %d rooms" % [k, t.min_rooms])
			_owe_escape(escapes, k, count, escape)
			continue
		block["entry"] = entry
		# Its breather is what every later pass keeps clear past it (keep_out), within its slot.
		block["exit"] = minf(slot_end, float(block["end"]) + keep_more)
		var in_way: String = _in_way(gen, entry, float(block["end"]) + keep_more)
		if in_way != "":
			(report["constraints"] as Array).append("slot %d: %s in the way" % [k, in_way])
			_owe_escape(escapes, k, count, escape)
			continue
		report["ceilings_out"] = int(report["ceilings_out"]) + _clear_ceilings(gen, entry, float(block["end"]) + keep_more)
		var debris_before: int = lay.doodads.size()
		var pieces: int = _add_block(gen, block)
		if block.has("escape"):
			var why: String = _add_escape_ceiling(gen, lay.maze.size() - 1, slot_end)
			if why == "":
				report["escapes"] = int(report["escapes"]) + 1
			else:
				# No pad fits: the block goes, and a plain one takes its slot; the escape is owed to the next slot.
				(report["constraints"] as Array).append("slot %d: no escape (%s)" % [k, why])
				lay.doodads.resize(debris_before)
				lay.maze.pop_back()
				_owe_escape(escapes, k, count, true)
				block = _plan_block(gen, t, rng, start, end_by)
				if block.is_empty():
					continue
				block["entry"] = entry
				block["exit"] = minf(slot_end, float(block["end"]) + keep_more)
				pieces = _add_block(gen, block)
		report["debris"] = int(report["debris"]) + pieces
		(report["breaks"] as Array).append(int(block["breaks"]))
	report["blocks"] = lay.maze.size()
	report["ceilings"] = _place_ceilings(gen, t, report)
	return report


## The slots (indices from 0 to `count` - 1, each `slot` seconds from track distance `from`) whose blocks end in an
## escape (DebrisMazeTuning.escape_blocks): the first whose block starts at escape_from of the level or later (else the
## last slot), the others spread evenly over the slots after it to the last.
static func _escape_slots(gen: LevelGenerator, t: DebrisMazeTuning, from: float, slot: float, count: int) -> Array[int]:
	var out: Array[int] = []
	if t.escape_blocks <= 0 or count <= 0:
		return out
	var first: int = count - 1
	for k: int in count:
		var slot_end: float = from + (k + 1) * slot * gen.speed
		if slot_end - (t.breather_seconds + t.block_seconds) * gen.speed >= t.escape_from * gen.layout.length:
			first = k
			break
	var n: int = mini(t.escape_blocks, count - first)
	for j: int in n:
		var k: int = first if n == 1 else first + roundi(float(j) * (count - 1 - first) / float(n - 1))
		if not out.has(k):
			out.append(k)
	return out


## Slot `k` was to end in an escape (`escape`) and won't: the next slot that has none takes it, if there is one.
static func _owe_escape(escapes: Array[int], k: int, count: int, escape: bool) -> void:
	if not escape:
		return
	for next: int in range(k + 1, count):
		if not escapes.has(next):
			escapes.append(next)
			return


## Rows of holes to jump in the normal track between blocks (DebrisMazeTuning.gap_rows; task O5, the owner, October 22,
## 2026: "add some more gaps to jump over in the sections in between maze portions"): in each stretch from one block's
## keep-out (keep_out) to the next block's run-in, gap_rows rows at even steps along it, each where it fits nearest its
## step (_nearest_fit). A row covers every lane, gap_jump_share of a full jump long (never
## more than LevelConfig.max_gap_jump_fraction), with the margin the level's other added rows keep from everything in
## every lane (GapDensity.busy_everywhere and margin: the level's hard spacing at its speed, around enemies, ceilings, pads, holes, the
## wider gaps' zones and the maze's own keep-outs), so its take-off and landing are clear floor. It runs after the wider
## gaps and before the fill pass and the doodads (LevelGenerator.generate), which keep their spacing from it. Returns
## {target, rows, constraints} (LevelGenerator.maze_gap_result); {} without the feature or rows asked. DESIGN-TBD
## (docs/questions/o5.md).
static func place_gaps(gen: LevelGenerator) -> Dictionary:
	var lay: LevelLayout = gen.layout
	var t: DebrisMazeTuning = tuning_for(gen.config)
	if not gen.config.has_feature(FEATURE) or t.gap_rows <= 0 or lay.maze.size() < 2:
		return {}
	var report: Dictionary = {"target": 0, "rows": 0, "constraints": []}
	var length: float = minf(t.gap_jump_share, gen.config.max_gap_jump_fraction) * gen.jump_distance
	var margin: float = GapDensity.margin(gen)
	# What every lane keeps the margin from, read once (the rows added here join it).
	var busy: Array[Vector2] = GapDensity.busy_everywhere(gen)
	var lo: float = gen.config.start_clear_distance
	var hi: float = lay.length - gen.config.end_clear_distance
	for i: int in range(1, lay.maze.size()):
		var from: float = maxf(keep_out(gen, lay.maze[i - 1], t).y, lo)
		var to: float = minf(float(lay.maze[i]["entry"]), hi)
		for k: int in t.gap_rows:
			report["target"] = int(report["target"]) + 1
			var want: float = from + (to - from) * (k + 1) / (t.gap_rows + 1) - length * 0.5
			var at: float = _nearest_fit(busy, margin, length, from, to, want)
			if is_nan(at):
				(report["constraints"] as Array).append("between blocks %d and %d: no room for row %d" % [i - 1, i, k])
				continue
			for lane: int in lay.lane_count:
				lay.gaps.append({"lane": lane, "start": at, "end": at + length})
			busy.append(Vector2(at, at + length))
			report["rows"] = int(report["rows"]) + 1
	return report


## Where a row `length` long that keeps `margin` from every span of `busy` starts, inside [from, to] and as near `want`
## as it can (place_gaps), or NAN where none fits.
static func _nearest_fit(busy: Array[Vector2], margin: float, length: float, from: float, to: float,
		want: float) -> float:
	# The starts a span forbids: from its start less the margin and the row's length to its end and the margin (open).
	var blocked: Array[Vector2] = []
	for b: Vector2 in busy:
		blocked.append(Vector2(b.x - margin - length, b.y + margin))
	blocked.sort_custom(func(a: Vector2, c: Vector2) -> bool: return a.x < c.x)
	var best: float = NAN
	var cursor: float = from
	for k: int in blocked.size() + 1:
		var stop: float = to - length
		if k < blocked.size():
			stop = minf(stop, blocked[k].x - GAP_EPSILON)
		if stop >= cursor:
			var at: float = clampf(want, cursor, stop)
			if is_nan(best) or absf(at - want) < absf(best - want):
				best = at
		if k < blocked.size():
			cursor = maxf(cursor, blocked[k].y + GAP_EPSILON)
		if cursor > to - length:
			break
	return best


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


## An escape block (DebrisMazeTuning.escape_blocks; see the header) from its first wall's front at `start`, its barrier
## ending by `end_by`: a block planned as any other (_plan_block) short enough to leave room after it for its pad's room
## (escape_room_length: open in every lane, no dividers) and its barrier (a last wall of escape_pieces large pieces in
## every lane, no opening). Its breaks are the maze's own up to the pad's room, which every way reaches as it would the
## breather. Marked `escape` (its pad's lane and spot come with its ceiling: _add_escape_ceiling). {} where it doesn't
## fit.
static func _plan_escape_block(gen: LevelGenerator, t: DebrisMazeTuning, rng: RandomNumberGenerator, start: float,
		end_by: float) -> Dictionary:
	var pieces: int = escape_pieces(gen, t)
	var depth: float = barrier_depth(gen.tuning, pieces)
	var pad_room: float = escape_room_length(gen)
	var block: Dictionary = _plan_block(gen, t, rng, start, end_by - pad_room - depth)
	if block.is_empty():
		return {}
	var at: float = float(block["end"])
	(block["rooms"] as Array).append({"start": at, "end": at + pad_room, "dividers": [], "fill": []})
	(block["walls"] as Array).append({"start": at + pad_room, "end": at + pad_room + depth, "size": WALL_SIZES[1],
		"open": [], "pieces": pieces})
	block["end"] = at + pad_room + depth
	block["escape"] = {}
	return block


## How many large pieces deep an escape block's barrier is at `gen`'s run speed: the tuning's escape_pieces, and never so
## few that one dash from its face smashes them all (the dash smashes every piece whose front its whole run reaches,
## SMASH_REACH_MARGIN on top): a runner who misses the pad needs a second dash, and the wait for it.
static func escape_pieces(gen: LevelGenerator, t: DebrisMazeTuning) -> int:
	var step: float = gen.tuning.doodad_size(WALL_SIZES[1]).z + TOUCH
	var one_dash: int = floori((dash_carry(gen) + SMASH_REACH_MARGIN) / step) + 1
	return maxi(t.escape_pieces, one_dash + 1)


## How long a barrier of `pieces` large pieces a sliver apart is along the track (metres).
static func barrier_depth(tun: MovementTuning, pieces: int) -> float:
	return pieces * tun.doodad_size(WALL_SIZES[1]).z + maxi(pieces - 1, 0) * TOUCH


## How long an escape block's pad room is (metres at `gen`'s run speed): room before its pad for a lane switch and
## PAD_LEAD and to see the pad after a dash through the wall before it (hidden_reach), whichever is more, then the pad's
## rise (pad_rise) up to the barrier, and ESCAPE_SLACK.
static func escape_room_length(gen: LevelGenerator) -> float:
	var lead: float = maxf(gen.tuning.lane_switch_time * gen.speed + PAD_LEAD, hidden_reach(gen))
	return lead + pad_rise(gen) + ESCAPE_SLACK


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
		var step: float = gen.tuning.doodad_size(StringName(wall["size"])).z + TOUCH
		for lane: int in lanes:
			if not (wall["open"] as Array).has(lane):
				# One piece a lane, or an escape block's barrier's several, a sliver apart.
				for j: int in int(wall.get("pieces", 1)):
					_add_piece(gen, index, "wall", w, lane, float(wall["start"]) + j * step, StringName(wall["size"]))
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
		var record_wall: Dictionary = {"start": float(wall["start"]), "end": float(wall["end"]), "size": String(wall["size"]),
			"open": open}
		if wall.has("pieces"):
			record_wall["pieces"] = int(wall["pieces"])
		record_walls.append(record_wall)
	var record: Dictionary = {"entry": float(block["entry"]), "start": float(block["start"]), "end": float(block["end"]),
		"exit": float(block["exit"]), "walls": record_walls, "rooms": record_rooms, "breaks": int(block["breaks"])}
	if block.has("escape"):
		record["escape"] = {}
	lay.maze.append(record)
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
		# An escape block has its ceiling already (_add_escape_ceiling).
		if chosen[i] and not is_escape(lay.maze[i]):
			var why: String = _add_ceiling(gen, rng, i)
			if why == "":
				added += 1
			else:
				(report["constraints"] as Array).append("block %d: no ceiling (%s)" % [i, why])
	if lay.hulls.is_empty():
		for i: int in lay.maze.size():
			if not chosen[i] and not is_escape(lay.maze[i]) and _add_ceiling(gen, rng, i) == "":
				added += 1
				break
	return added


## A one-lane ceiling over block `index`'s last wall (see the header), or why there's none: its pad in a lane of a cell
## of the last room the runner can reach (a dead end first) that the last wall closes, the cell two lanes wide or more
## (a runner who'd rather stay on the floor passes the pad beside it), PAD_LEAD and a lane switch clear before the pad
## and pad_rise past it, hidden_reach past the wall before it where that wall is closed in its lane (a dash through it
## never brings a runner onto a pad they couldn't see), its rider's drop past the last wall clear of debris in every
## lane until the next block's first wall (drop_room), and everything add_hull_with_pad asks (a pad that can be stepped
## on, a safe landing, no other ceiling near). "" once it's added.
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
	var before: Dictionary = walls[-2]
	var seen: float = float(room["start"]) + hidden_reach(gen)
	for lanes: Array[int] in [dead, other]:
		while not lanes.is_empty():
			var lane: int = lanes.pop_at(rng.randi_range(0, lanes.size() - 1))
			if at < seen and not (before["open"] as Array).has(lane):
				continue
			if gen.add_hull_with_pad(lane, at, length / gen.speed, Vector2i(lane, lane)):
				lay.hulls[-1]["maze"] = index
				return ""
	return "no lane where a pad and a landing fit"


## Block `index`'s escape (an escape block's: _plan_escape_block), or why it has none: an anti-grav pad in its pad room
## in a lane drawn from its own stream, as late as lets its lift carry the rider over the debris's top before the barrier
## (pad_rise), under a one-lane ceiling from it to ESCAPE_HULL_PAST and the body's depth past the barrier's back, its
## rider's drop clear of debris by `limit` (the slot's end: the next block's run-in comes after it), and everything
## add_hull_with_pad asks. Its ceiling is longer than LevelConfig.one_lane_ceiling_seconds where the barrier needs it
## (DESIGN-TBD, docs/questions/o5.md). Records {lane, at} in the block's `escape` and marks the hull `maze` and
## `escape`. "" once it's added.
static func _add_escape_ceiling(gen: LevelGenerator, index: int, limit: float) -> String:
	var lay: LevelLayout = gen.layout
	var b: Dictionary = lay.maze[index]
	var room: Dictionary = (b["rooms"] as Array)[-1]
	var barrier: Dictionary = (b["walls"] as Array)[-1]
	var at: float = float(barrier["start"]) - pad_rise(gen) - ESCAPE_PAD_EARLY
	var lead: float = maxf(gen.tuning.lane_switch_time * gen.speed + PAD_LEAD, hidden_reach(gen))
	if at < float(room["start"]) + lead - 0.001:
		return "the pad's room is too short"
	var end: float = float(barrier["end"]) + gen.tuning.visual_size.z + ESCAPE_HULL_PAST
	if end + drop_room(gen) > limit:
		return "no room for its rider's drop before the next block"
	var rng: RandomNumberGenerator = gen.rng_for("%s_escape_%d" % [FEATURE, index])
	var order: Array[int] = []
	for lane: int in lay.lane_count:
		order.insert(rng.randi_range(0, order.size()), lane)
	for lane: int in order:
		if gen.add_hull_with_pad(lane, at, (end - at) / gen.speed, Vector2i(lane, lane)):
			lay.hulls[-1]["maze"] = index
			lay.hulls[-1]["escape"] = true
			b["escape"] = {"lane": lane, "at": at}
			return ""
	return "no lane where a pad and a landing fit"


## True if block record `b` is an escape block: its last room holds an anti-grav pad and its last wall is a barrier more
## than one dash deep (_plan_escape_block).
static func is_escape(b: Dictionary) -> bool:
	return b.has("escape")


## Block record `b`'s maze proper: for an escape block, the block without its pad room and its barrier (which every way
## reaches through its last maze wall as it would the breather); otherwise `b` itself. Its walls, rooms and breaks.
static func maze_part(b: Dictionary) -> Dictionary:
	if not is_escape(b):
		return b
	var out: Dictionary = b.duplicate()
	out["walls"] = (b["walls"] as Array).slice(0, (b["walls"] as Array).size() - 1)
	out["rooms"] = (b["rooms"] as Array).slice(0, (b["rooms"] as Array).size() - 1)
	out["end"] = float((out["walls"] as Array)[-1]["end"])
	out.erase("escape")
	return out


# --- Questions about the maze (for what lives in it: task O3) -------------------------------------

## Block record `b`'s rooms' dividers and walls' openings, the way search() takes them: {dividers, open}. An escape
## block's are its maze part's (maze_part): its pad room is its breather for the search.
static func shape_of(b: Dictionary) -> Dictionary:
	var m: Dictionary = maze_part(b)
	var dividers: Array = []
	for room: Dictionary in m["rooms"]:
		dividers.append(room["dividers"])
	var open: Array = []
	for wall: Dictionary in m["walls"]:
		open.append(wall["open"])
	return {"dividers": dividers, "open": open}


## The least dashes block record `b` takes from its run-in to its breather (search()); an escape block's, to its pad room.
static func min_breaks(b: Dictionary, lanes: int) -> int:
	var shape: Dictionary = shape_of(b)
	return int(search(shape["dividers"], shape["open"], lanes)["breaks"])


## Every open section of `layout`'s debris maze, in order of the track: for each block its run-in, each room's cells
## left to right, and its breather, each {block, room, first, last, start, end} (lanes `first` to `last` open from track
## distance `start` to `end`; `room` -1 for the run-in, the room's index for a cell, the block's room count for the
## breather). An index into this list is a section's id for links(), open_group(), section_id() and section_at(). With
## `broken`, after all of those (so their ids stay as they are), each stretch of a divider that dashes have smashed on
## this attempt (broken_stretches(): its pieces' layout entries marked "smashed") as a section of its own, marked
## `broken`.
static func sections(layout: LevelLayout, broken: bool = false) -> Array[Dictionary]:
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
	if broken:
		out.append_array(broken_stretches(layout))
	return out


## Each stretch of a divider that dashes have smashed on this attempt (its pieces' layout entries marked "smashed", as
## DashBreakable.smash marks them), in order of block, room and lane, as a section: {block, room, first, last (both its
## lane), start, end, broken: true}. Pieces next to each other (TOUCH apart) make one stretch, which runs on to the room's
## start or end where it holds the room's first or last piece in its lane (the sliver by the wall is open floor with it).
static func broken_stretches(layout: LevelLayout) -> Array[Dictionary]:
	var pieces: Dictionary = {}  # Vector3i(block, room, lane) -> the divider's pieces
	for d: Dictionary in layout.doodads:
		if LevelLayout.is_maze_debris(d) and String(d["part"]) == "divider":
			var key := Vector3i(int(d["maze"]), int(d["index"]), int(d["lane"]))
			if not pieces.has(key):
				pieces[key] = []
			(pieces[key] as Array).append(d)
	var out: Array[Dictionary] = []
	for i: int in layout.maze.size():
		var rooms: Array = layout.maze[i]["rooms"]
		for r: int in rooms.size():
			var room: Dictionary = rooms[r]
			for lane: Variant in room["dividers"]:
				var list: Array = pieces.get(Vector3i(i, r, int(lane)), [])
				list.sort_custom(func(a: Dictionary, c: Dictionary) -> bool: return float(a["start"]) < float(c["start"]))
				var k: int = 0
				while k < list.size():
					if not bool((list[k] as Dictionary).get("smashed", false)):
						k += 1
						continue
					var first: int = k
					while k + 1 < list.size() and bool((list[k + 1] as Dictionary).get("smashed", false)):
						k += 1
					out.append({"block": i, "room": r, "first": int(lane), "last": int(lane),
						"start": float(room["start"]) if first == 0 else float((list[first] as Dictionary)["start"]),
						"end": float(room["end"]) if k == list.size() - 1 else float((list[k] as Dictionary)["end"]),
						"broken": true})
					k += 1
	return out


## Where the sections of `layout`'s maze (`secs`, as sections() gives them) join without a dash, each {from, to, lane,
## at, kind} (section ids): an opening of a wall joins the sections either side of it in its lane (`from` the earlier
## along the track, `at` the wall's front, kind "opening"). With `broken`, also what dashes have opened on this attempt
## (the smashed pieces' entries), kind "broken": lanes side by side open through a wall (its openings and smashed pieces)
## with a smashed piece among them are one breach, open floor across those lanes, which joins everything open right before
## its front and right past its back in them (a cell, the run-in, the breather, or a smashed stretch of a divider there;
## `from` one before the wall where there is one, `at` the wall's front); and a smashed stretch of a divider joins each
## cell beside it in its room (`from` the stretch, `at` its start; one in an edge lane has one cell beside it). `secs` may
## be sections(layout) or, taken after the smashes, sections(layout, true): a smashed stretch has the same id either way
## (after the plain sections, in broken_stretches()' order), so open_group() over these links groups the plain sections
## the same with either. Links say which open floor meets which: a runner goes only forward along them (and needs room
## for a lane switch: MazeRoute's to judge), anything else may go either way.
static func links(layout: LevelLayout, secs: Array[Dictionary], broken: bool = false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var all: Array[Dictionary] = secs
	var smashed_walls: Dictionary = {}  # Vector2i(block, wall) -> its smashed pieces' lanes
	if broken:
		var stretches: bool = false
		for s: Dictionary in secs:
			stretches = stretches or bool(s.get("broken", false))
		if not stretches:
			all = secs.duplicate()
			all.append_array(broken_stretches(layout))
		# A lane of a wall is smashed through once every piece of it there is (an escape block's barrier has several).
		var standing: Dictionary = {}  # Vector3i(block, wall, lane) -> true where a piece still stands
		for d: Dictionary in layout.doodads:
			if LevelLayout.is_maze_debris(d) and String(d["part"]) == "wall" and not bool(d.get("smashed", false)):
				standing[Vector3i(int(d["maze"]), int(d["index"]), int(d["lane"]))] = true
		for d: Dictionary in layout.doodads:
			if LevelLayout.is_maze_debris(d) and String(d["part"]) == "wall" and bool(d.get("smashed", false)) \
					and not standing.has(Vector3i(int(d["maze"]), int(d["index"]), int(d["lane"]))):
				var key := Vector2i(int(d["maze"]), int(d["index"]))
				if not smashed_walls.has(key):
					smashed_walls[key] = []
				if not (smashed_walls[key] as Array).has(int(d["lane"])):
					(smashed_walls[key] as Array).append(int(d["lane"]))
	for i: int in layout.maze.size():
		var walls: Array = layout.maze[i]["walls"]
		for w: int in walls.size():
			var wall: Dictionary = walls[w]
			for lane: Variant in wall["open"]:
				var before: int = section_id(all, i, w - 1, int(lane))
				var after: int = section_id(all, i, w, int(lane))
				if before >= 0 and after >= 0:
					out.append({"from": before, "to": after, "lane": int(lane), "at": float(wall["start"]), "kind": "opening"})
			var smashed: Array = smashed_walls.get(Vector2i(i, w), [])
			if not smashed.is_empty():
				out.append_array(_breach_links(all, wall, smashed, layout.lane_count))
	if broken:
		for id: int in all.size():
			var s: Dictionary = all[id]
			if not bool(s.get("broken", false)):
				continue
			var lane: int = int(s["first"])
			for side: int in [lane - 1, lane + 1]:
				var cell: int = section_id(all, int(s["block"]), int(s["room"]), side)
				if cell >= 0:
					out.append({"from": id, "to": cell, "lane": lane, "at": float(s["start"]), "kind": "broken"})
	return out


## The "broken" links through wall `wall` (a block record's) whose pieces in lanes `smashed` dashes have smashed (links()):
## each run of lanes side by side open through it, its openings and smashed pieces, with a smashed one among them, joins
## the sections of `secs` open right before its front and right past its back in those lanes, all to the first of them
## (one before the wall where there is one).
static func _breach_links(secs: Array[Dictionary], wall: Dictionary, smashed: Array, lanes: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lane: int = 0
	while lane < lanes:
		if not (smashed.has(lane) or (wall["open"] as Array).has(lane)):
			lane += 1
			continue
		var breached: bool = false
		var before: Array[Vector2i] = []  # Vector2i(section id, lane)
		var after: Array[Vector2i] = []
		while lane < lanes and (smashed.has(lane) or (wall["open"] as Array).has(lane)):
			breached = breached or smashed.has(lane)
			var near: int = section_at(secs, lane, float(wall["start"]) - LINK_EPSILON)
			var far: int = section_at(secs, lane, float(wall["end"]) + LINK_EPSILON)
			if near >= 0:
				before.append(Vector2i(near, lane))
			if far >= 0:
				after.append(Vector2i(far, lane))
			lane += 1
		if not breached:
			continue
		var ends: Array[Vector2i] = before.duplicate()
		ends.append_array(after)
		if ends.is_empty():
			continue
		var hub: int = ends[0].x
		var joined: Array[int] = [hub]
		for e: Vector2i in ends:
			if not joined.has(e.x):
				joined.append(e.x)
				out.append({"from": hub, "to": e.x, "lane": e.y, "at": float(wall["start"]), "kind": "broken"})
	return out


## The id of the section of block `block`'s room `room` (-1 the run-in, the room count the breather) holding `lane`, in
## `secs` (sections()), or -1 (a divider there, or no such room). Never a smashed stretch of a divider: section_at() finds
## those by where they are.
static func section_id(secs: Array[Dictionary], block: int, room: int, lane: int) -> int:
	for id: int in secs.size():
		var s: Dictionary = secs[id]
		if int(s["block"]) == block and int(s["room"]) == room and lane >= int(s["first"]) and lane <= int(s["last"]) \
				and not bool(s.get("broken", false)):
			return id
	return -1


## The id of the section of `secs` (sections() of `layout`) holding track distance `at` in `lane`, or -1 (standing debris
## there, or no maze). With sections(layout, true), a spot in a smashed stretch of a divider is in that stretch's section.
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

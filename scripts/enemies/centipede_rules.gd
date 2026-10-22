extends RefCounted
## Generator rules for the Cybernetic Centipede (task O3; GDD §9.15: it "haunts the debris maze, waiting in the open
## sections between the debris"). The Terminal's only enemy, placed by these rules alone (no pattern: it lives in the
## maze's cells, which only DebrisMaze knows), after the maze is built (RUN_AFTER) and before every later pass, which
## keeps off the maze's blocks anyway (DebrisMaze.keep_out), so nothing else of the level moves for it.
##
## apply(): each block of the maze from the feature's start (LevelConfig.feature_starts: 35% into Rubble Line) gets a
## centipede with the tuning's block_share at the difficulty where it stands (LevelGenerator.difficulty_at), and a
## second with second_share; the level's first block from the start always gets one, its introduction. Each waits with
## its head at a spot in one of the block's open cells, facing back toward the runner, its body behind it in its lane,
## in one of the three places GDD §9.15 names (drawn by the tuning's weights):
## - "near": an ordinary cell the runner's own part of the maze opens onto (its section joined to the run-in's along open
##   paths), off the block's quickest way through: it wakes as the runner passes near and chases;
## - "way": a cell on the block's quickest way through (CentipedeEscape with no centipede: the way a runner would take),
##   "in the only way through": the runner has to work out which other path and which dashes get round it;
## - "trapped": a cell walled in by debris (its section joined to neither the run-in's nor the breather's), "a dash that
##   opens their debris can release one by accident".
## A spot is kept only if the block stays escapable with it and the block's others (CentipedeEscape.find: a way through
## on the Player's moves, with the dash at its slowest recharge, that never comes within any centipede's reach), and its
## floor keeps off every ceiling's pad and landing zone (CeilingZones.enemy_clear); else the next spot is tried, then
## the other places. If no block took one, the first block where any spot fits gets one (every Terminal level has its
## centipedes). The layout entry: {type "centipede", at (its head's spot), lane, side 0, params {block (its maze block's
## index), situation, floor_span}}. DESIGN-TBD (docs/questions/o3.md): how many and where.
## Each level's maze scales how many (task O5; the owner, October 22, 2026: Rubble Line about 20 to 30% more, Last Stop
## about double): DebrisMazeTuning.centipede_scale multiplies each block's drawn count (its fraction drawn) and the most a
## block holds (count_scale, max_per_block). An escape block's pad room (DebrisMaze.is_escape) holds none: its pad is the
## way out.

const FEATURE: String = "centipede"
## The maze is built first: its cells are where a centipede waits.
const RUN_AFTER: Array[String] = ["debris_maze"]
const SITUATIONS: Array[String] = ["near", "way", "trapped"]
## A spot's head waits at least this far past its cell's start (metres), and its body ends at least TAIL_MARGIN before
## the cell's end.
const HEAD_MARGIN: float = 3.0
const TAIL_MARGIN: float = 1.5
## The floor a waiting centipede takes (params.floor_span, LevelGenerator.enemy_floor_span): from FLOOR_BEFORE in front
## of its head to FLOOR_AFTER past its tail (metres).
const FLOOR_BEFORE: float = 2.0
const FLOOR_AFTER: float = 1.0
## Spots tried in each place for one centipede before the next place is tried.
const TRIES: int = 5


static func tuning() -> CentipedeTuning:
	var t := EnemyDirector.tuning_for(FEATURE) as CentipedeTuning
	return t if t != null else CentipedeTuning.new()


static func apply(gen: LevelGenerator) -> void:
	var lay: LevelLayout = gen.layout
	if not gen.config.has_feature(FEATURE) or lay.maze.is_empty():
		return
	var t: CentipedeTuning = tuning()
	var rng: RandomNumberGenerator = gen.rng_for(FEATURE)
	var start: float = gen.feature_start(FEATURE)
	var scale: float = count_scale(gen.config)
	var most: int = max_per_block(gen.config)
	var placed: int = 0
	for i: int in lay.maze.size():
		var b: Dictionary = lay.maze[i]
		if float(b["end"]) <= start:
			continue
		var d: float = gen.difficulty_at(float(b["start"]) / maxf(lay.length, 1.0))
		var intro: bool = placed == 0
		var want: int = 0
		if intro or rng.randf() < t.block_share(d):
			want = 1
			if not intro and rng.randf() < t.second_share(d):
				want = 2
		want = _scaled(want, scale, rng)
		want = mini(want, most)
		if want > 0:
			placed += _place_block(gen, t, rng, i, start, want, intro)
	if placed > 0:
		return
	# Every level that has the feature has its centipedes: the first block where any spot fits gets one.
	for i: int in lay.maze.size():
		if float((lay.maze[i] as Dictionary)["end"]) > start and _place_block(gen, t, rng, i, start, 1, false, true) > 0:
			return


## The level's centipede count scale (DebrisMazeTuning.centipede_scale, its maze's own: task O5).
static func count_scale(config: LevelConfig) -> float:
	return DebrisMaze.tuning_for(config).centipede_scale if config != null else 1.0


## The most centipedes a block of `config`'s level holds: the tuning's max_per_block, scaled by the level's
## centipede_scale (rounded up; never fewer than the tuning's).
static func max_per_block(config: LevelConfig) -> int:
	var t: CentipedeTuning = tuning()
	return maxi(t.max_per_block, ceili(t.max_per_block * count_scale(config) - 0.001))


## A block's drawn count `want` scaled by `scale` (count_scale): want times scale, its fraction a draw from `rng` (none
## at a scale of 1, so a level at 1 places as it always has). A block that drew none stays empty.
static func _scaled(want: int, scale: float, rng: RandomNumberGenerator) -> int:
	if want <= 0 or is_equal_approx(scale, 1.0):
		return want
	var exact: float = want * scale
	var out: int = floori(exact)
	if rng.randf() < exact - out:
		out += 1
	return maxi(out, 1)


## Places up to `want` centipedes in block `index` (see the header): the first in an ordinary cell if it's the level's
## introduction (`intro`), each in a place drawn by the weights and then the others, every one only where the block stays
## escapable; with `any`, every place in turn whatever the weights. Returns how many it placed.
static func _place_block(gen: LevelGenerator, t: CentipedeTuning, rng: RandomNumberGenerator, index: int, start: float,
		want: int, intro: bool, any: bool = false) -> int:
	var lay: LevelLayout = gen.layout
	var ctx: CentipedeEscape.Context = CentipedeEscape.context(lay, gen.tuning, index)
	var candidates: Array[Dictionary] = candidates_for(gen, ctx, start, rng)
	if candidates.is_empty():
		return 0
	var chosen: Array[Dictionary] = []
	for k: int in want:
		var order: Array[String] = _order(t, rng, intro and k == 0, any)
		var found: bool = false
		for situation: String in order:
			var pool: Array[Dictionary] = []
			for c: Dictionary in candidates:
				if String(c["situation"]) == situation and _spaced(c, chosen, t):
					pool.append(c)
			_shuffle(pool, rng)
			for j: int in mini(pool.size(), TRIES):
				var c: Dictionary = pool[j]
				var entry: Dictionary = _entry(index, c)
				if not gen.zones.enemy_clear(lay, entry):
					continue
				var spots: Array = chosen.duplicate()
				spots.append(c)
				if bool(ctx.find(spots)["ok"]):
					chosen.append(c)
					found = true
					break
			if found:
				break
		if not found:
			break
	for c: Dictionary in chosen:
		var e: Dictionary = _entry(index, c)
		gen.add_enemy(FEATURE, float(e["at"]), int(e["lane"]), 0, e["params"])
	return chosen.size()


## The places in the order a centipede tries them: the introduction's ordinary cell first (then the rest as drawn);
## otherwise one drawn by the tuning's weights first, then the others by weight; with `any`, every place by weight.
static func _order(t: CentipedeTuning, rng: RandomNumberGenerator, intro: bool, any: bool) -> Array[String]:
	var weights: Dictionary = {"near": t.near_weight, "way": t.way_weight, "trapped": t.trapped_weight}
	var out: Array[String] = []
	if intro:
		out.append("near")
	var left: Array[String] = []
	for s: String in SITUATIONS:
		if not out.has(s):
			left.append(s)
	while not left.is_empty():
		var total: float = 0.0
		for s: String in left:
			total += maxf(float(weights[s]), 0.0)
		var pick: int = 0
		if total > 0.0:
			var roll: float = rng.randf() * total
			for j: int in left.size():
				roll -= maxf(float(weights[left[j]]), 0.0)
				if roll <= 0.0:
					pick = j
					break
		elif not any:
			break
		out.append(left.pop_at(pick))
	return out


## Every spot the block of `ctx` (CentipedeEscape.Context) offers a centipede from track distance `start` on (see the
## header): one in each of its rooms'
## open cells, in a random lane of the cell, its head between HEAD_MARGIN past the room's start and its body's length
## and TAIL_MARGIN before its end, each {lane, at, room, cell, situation}.
static func candidates_for(gen: LevelGenerator, ctx: CentipedeEscape.Context, start: float,
		rng: RandomNumberGenerator) -> Array[Dictionary]:
	var lay: LevelLayout = gen.layout
	var b: Dictionary = ctx.b
	var rooms: Array = b["rooms"]
	var lanes: int = lay.lane_count
	var bl: LevelLayout = ctx.maze.block_layout()
	var secs: Array[Dictionary] = ctx.secs
	var links: Array[Dictionary] = DebrisMaze.links(bl, secs)
	var run_in: int = DebrisMaze.section_id(secs, 0, -1, 0)
	var breather: int = DebrisMaze.section_id(secs, 0, rooms.size(), 0)
	var quickest: Dictionary = ctx.find([])
	var way: Array = quickest.get("path", []) if bool(quickest.get("ok", false)) else []
	var out: Array[Dictionary] = []
	for r: int in rooms.size():
		# An escape block's pad room is the way out, not a place to wait (DebrisMaze.is_escape).
		if DebrisMaze.is_escape(b) and r == rooms.size() - 1:
			continue
		var room: Dictionary = rooms[r]
		var lo: float = maxf(float(room["start"]) + HEAD_MARGIN, start)
		var hi: float = float(room["end"]) - Centipede.BODY_LENGTH - TAIL_MARGIN
		if hi < lo:
			continue
		var cells: Array[Vector2i] = DebrisMaze.cells_of(room["dividers"], lanes)
		for c: int in cells.size():
			var cell: Vector2i = cells[c]
			var id: int = DebrisMaze.section_id(secs, 0, r, cell.x)
			var group: PackedInt32Array = DebrisMaze.open_group(links, id)
			var situation: String = "near"
			if not group.has(run_in) and not group.has(breather):
				situation = "trapped"
			elif way.has([r + 1, c]):
				situation = "way"
			elif not group.has(run_in):
				# Joined only to the breather: neither walled in nor on the runner's side of the maze.
				continue
			out.append({"lane": rng.randi_range(cell.x, cell.y), "at": rng.randf_range(lo, hi), "room": r, "cell": c,
				"situation": situation})
	return out


static func _entry(index: int, c: Dictionary) -> Dictionary:
	var at: float = float(c["at"])
	return {"type": FEATURE, "at": at, "lane": int(c["lane"]), "side": 0, "params": {"block": index,
		"situation": String(c["situation"]),
		"floor_span": Vector2(at - FLOOR_BEFORE, at + Centipede.BODY_LENGTH + FLOOR_AFTER)}}


static func _spaced(c: Dictionary, chosen: Array[Dictionary], t: CentipedeTuning) -> bool:
	for o: Dictionary in chosen:
		if absf(float(o["at"]) - float(c["at"])) < t.min_spacing:
			return false
	return true


static func _shuffle(list: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	for i: int in range(list.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: Dictionary = list[i]
		list[i] = list[j]
		list[j] = swap


## What the passes after the rules keep off around a centipede's entry (LevelGenerator.fill_keep_outs, the danger
## density pass's attack windows, the wall fences): its block's own keep-out (DebrisMaze.keep_out), which they keep off
## already, so a centipede moves nothing else of the level. A centipede outside any block (none is placed so) keeps its
## floor span.
static func keep_out(gen: LevelGenerator, e: Dictionary) -> Vector2:
	var at: float = float(e["at"])
	var i: int = CentipedeMaze.block_at(gen.layout, at)
	if i < 0:
		return LevelGenerator.enemy_floor_span(e, gen.pace)
	return DebrisMaze.keep_out(gen, gen.layout.maze[i])

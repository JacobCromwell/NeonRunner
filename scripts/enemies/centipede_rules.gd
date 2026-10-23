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
## way out. Spots in open cells ("near", "way") are tried many at a time (OPEN_SPOTS a cell, OPEN_TRIES), so fewer end up
## walled in (the owner: they "should not be always separated from the player"). DESIGN-TBD (items 1201 and 1202 in
## docs/OPEN_QUESTIONS*.md): Last Stop's count, and how far the escape guarantee keeps them walled in.
## Ambushes (DebrisMazeTuning.ambush_count; the owner, October 22, 2026: "resting inside of one of the debris doodads ...
## when you get close to it, the debris shatters and the centipede is released"; two in Last Stop's last half): placed
## first, one a block, each hidden in a divider (_place_ambushes), situation "ambush", params.ambush {room, lane, peek,
## from, to}; the others placed in its block after it keep the block escapable with it. DESIGN-TBD (item 1203 in
## docs/OPEN_QUESTIONS*.md).

const FEATURE: String = "centipede"

## The maze is built first: its cells are where a centipede waits.
const RUN_AFTER: Array[String] = ["debris_maze"]
const SITUATIONS: Array[String] = ["near", "way", "trapped"]
## An ambush's situation (task O5: hidden in a divider, _place_ambushes).
const AMBUSH: String = "ambush"
## An ambush's debris (ambush_host): the divider's pieces from this far before its head to this far past its tail
## (metres).
const AMBUSH_HOST_BEFORE: float = 1.0
const AMBUSH_HOST_AFTER: float = 0.3
## A spot's head waits at least this far past its cell's start (metres), and its body ends at least TAIL_MARGIN before
## the cell's end.
const HEAD_MARGIN: float = 3.0
const TAIL_MARGIN: float = 1.5
## The floor a waiting centipede takes (params.floor_span, LevelGenerator.enemy_floor_span): from FLOOR_BEFORE in front
## of its head to FLOOR_AFTER past its tail (metres).
const FLOOR_BEFORE: float = 2.0
const FLOOR_AFTER: float = 1.0
## Spots tried in each place for one centipede before the next place is tried: few in a walled-in cell (any spot there
## keeps the block escapable), many in an open one ("near" or "way", where the proof turns most spots down: task O5, the
## owner, October 22, 2026: the centipedes "should not be always separated from the player").
const TRIES: int = 5
const OPEN_TRIES: int = 8
## Spots tried for an ambush in a block before the next block (_place_ambushes): there are only a couple of blocks to
## hide its two in.
const AMBUSH_TRIES: int = 16
## Spots each open cell offers (a random lane and place each); a walled-in cell offers one.
const OPEN_SPOTS: int = 4


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
	# The ambushes first (from a stream of their own); the others in their blocks keep them escapable with it.
	var ambushed: Dictionary = _place_ambushes(gen, t, start)
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
		want = mini(want, most - (ambushed.get(i, []) as Array).size())
		if want > 0:
			placed += _place_block(gen, t, rng, i, start, want, intro, false, ambushed.get(i, []))
	if placed == 0:
		# Every level that has the feature has its centipedes: the first block where any spot fits gets one.
		for i: int in lay.maze.size():
			if float((lay.maze[i] as Dictionary)["end"]) > start \
					and _place_block(gen, t, rng, i, start, 1, false, true, ambushed.get(i, [])) > 0:
				break
	_place_free(gen, t, start)


## The level's free centipedes (DebrisMazeTuning.free_centipedes; the owner's answer to item 1202, October 23, 2026: drop
## the escape guarantee for some, so they are "not always separated from the player"): one in each of that many blocks
## from the feature's start, spread evenly over them (the others tried in turn where one has no spot), in an open cell
## joined to the runner's part of the block ("near" or "way", drawn by their weights), with NO escape proof: it may catch
## a runner waiting for the dash at a wall, and armor, the shield or a well-timed dash may be what gets them past. It
## keeps everything else a centipede keeps (an open cell, its floor off every pad and landing zone, min_spacing from the
## block's others, never an escape block's pad room); its entry's params.free is true, and every other centipede's
## proof leaves it out (LayoutChecks.check_centipedes, the tests' bots). Returns how many it placed. DESIGN-TBD (item 1220
## in docs/OPEN_QUESTIONS*.md): how many and where.
static func _place_free(gen: LevelGenerator, t: CentipedeTuning, start: float) -> int:
	var lay: LevelLayout = gen.layout
	var mt: DebrisMazeTuning = DebrisMaze.tuning_for(gen.config)
	if mt.free_centipedes <= 0:
		return 0
	var eligible: Array[int] = []
	for i: int in lay.maze.size():
		if float((lay.maze[i] as Dictionary)["end"]) > start:
			eligible.append(i)
	if eligible.is_empty():
		return 0
	var rng: RandomNumberGenerator = gen.rng_for(FEATURE + "_free")
	var order: Array[int] = []
	var n: int = mini(mt.free_centipedes, eligible.size())
	for j: int in n:
		var k: int = 0 if n == 1 else roundi(float(j) * (eligible.size() - 1) / float(n - 1))
		if not order.has(eligible[k]):
			order.append(eligible[k])
	for i: int in eligible:
		if not order.has(i):
			order.append(i)
	var placed: int = 0
	for i: int in order:
		if placed >= mt.free_centipedes:
			break
		var others: Array[Dictionary] = []
		for e: Dictionary in lay.enemies:
			if String(e.get("type", "")) == FEATURE and int((e.get("params", {}) as Dictionary).get("block", -1)) == i:
				others.append(e)
		if others.size() >= max_per_block(gen.config):
			continue
		var ctx: CentipedeEscape.Context = CentipedeEscape.context(lay, gen.tuning, i)
		var pool: Array[Dictionary] = []
		for c: Dictionary in candidates_for(gen, ctx, start, rng):
			if String(c["situation"]) != "trapped" and _spaced(c, others, t):
				pool.append(c)
		_shuffle(pool, rng)
		# The way first, as often as its weight says: "in the only way through".
		var way_first: bool = rng.randf() * maxf(t.near_weight + t.way_weight, 0.001) < t.way_weight
		pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return (String(a["situation"]) == "way") == way_first and (String(b["situation"]) == "way") != way_first)
		for c: Dictionary in pool:
			var entry: Dictionary = _entry(i, c)
			if not gen.zones.enemy_clear(lay, entry):
				continue
			entry["params"]["free"] = true
			gen.add_enemy(FEATURE, float(entry["at"]), int(entry["lane"]), 0, entry["params"])
			placed += 1
			break
	return placed


## True if centipede entry `e` (a layout enemy) is a free one (_place_free): no escape proof keeps its block escapable
## past it.
static func is_free(e: Dictionary) -> bool:
	return bool((e.get("params", {}) as Dictionary).get("free", false))


## The level's ambush centipedes (DebrisMazeTuning.ambush_count, from ambush_from of the level and the feature's start
## on; task O5): one in each of that many blocks, spread evenly over the blocks there (the others tried in turn where one
## has no spot), each hidden in a divider (ambush_candidates) where its block stays escapable with it
## (CentipedeEscape: it breaks out as the runner comes within ambush_distance, the debris it lay in open from the start).
## Returns the blocks that took one: block index -> [its spot].
static func _place_ambushes(gen: LevelGenerator, t: CentipedeTuning, start: float) -> Dictionary:
	var out: Dictionary = {}
	var lay: LevelLayout = gen.layout
	var mt: DebrisMazeTuning = DebrisMaze.tuning_for(gen.config)
	if mt.ambush_count <= 0:
		return out
	var eligible: Array[int] = []
	for i: int in lay.maze.size():
		var b: Dictionary = lay.maze[i]
		if float(b["start"]) >= maxf(start, mt.ambush_from * lay.length):
			eligible.append(i)
	if eligible.is_empty():
		return out
	var rng: RandomNumberGenerator = gen.rng_for(FEATURE + "_" + AMBUSH)
	# Spread: the blocks at even steps through the eligible ones first, then the rest in order.
	var order: Array[int] = []
	var n: int = mini(mt.ambush_count, eligible.size())
	for j: int in n:
		var k: int = 0 if n == 1 else roundi(float(j) * (eligible.size() - 1) / float(n - 1))
		if not order.has(eligible[k]):
			order.append(eligible[k])
	for i: int in eligible:
		if not order.has(i):
			order.append(i)
	for i: int in order:
		if out.size() >= mt.ambush_count:
			break
		var ctx: CentipedeEscape.Context = CentipedeEscape.context(lay, gen.tuning, i)
		var spots: Array[Dictionary] = ambush_candidates(lay, gen.tuning, i, start, rng)
		_shuffle(spots, rng)
		for j: int in mini(spots.size(), AMBUSH_TRIES):
			var c: Dictionary = spots[j]
			var entry: Dictionary = ambush_entry(i, c)
			if not gen.zones.enemy_clear(lay, entry):
				continue
			if bool(ctx.find([c])["ok"]):
				gen.add_enemy(FEATURE, float(entry["at"]), int(entry["lane"]), 0, entry["params"])
				out[i] = [c]
				break
	return out


## Every spot block `index` of `layout` offers an ambush (see _place_ambushes): OPEN_SPOTS in each divider of each room
## (but an escape block's pad room, which has none), each its head at a random place between HEAD_MARGIN past the room's start and
## its body's length and TAIL_MARGIN before its end, from track distance `start` on; its body pokes out on a side whose
## lane is open beside the divider (`peek`: -1 or 1). Each {lane, at, room, ambush: true, peek, host (the divider's
## pieces its body lies in: ambush_host)}, a spot CentipedeEscape takes as an ambush.
static func ambush_candidates(layout: LevelLayout, tuning: MovementTuning, index: int, start: float,
		rng: RandomNumberGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var b: Dictionary = layout.maze[index]
	var rooms: Array = b["rooms"]
	var lanes: int = layout.lane_count
	for r: int in rooms.size():
		var room: Dictionary = rooms[r]
		var lo: float = maxf(float(room["start"]) + HEAD_MARGIN, start)
		var hi: float = float(room["end"]) - Centipede.BODY_LENGTH - TAIL_MARGIN
		if hi < lo:
			continue
		for lane: Variant in room["dividers"]:
			var l: int = int(lane)
			for k: int in OPEN_SPOTS:
				var at: float = rng.randf_range(lo, hi)
				var peek: int = 1 if l == 0 else (-1 if l == lanes - 1 else (1 if rng.randf() < 0.5 else -1))
				out.append({"lane": l, "at": at, "room": r, "ambush": true, "peek": peek,
					"host": ambush_host(layout, index, r, l, at)})
	return out


## The pieces of block `index`'s divider in room `room`, lane `lane` an ambush whose head is at `at` lies in: every one
## from AMBUSH_HOST_BEFORE before its head to AMBUSH_HOST_AFTER past its tail (they shatter as it breaks out).
static func ambush_host(layout: LevelLayout, index: int, room: int, lane: int, at: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lo: float = at - AMBUSH_HOST_BEFORE
	var hi: float = at + Centipede.BODY_LENGTH + AMBUSH_HOST_AFTER
	for d: Dictionary in layout.doodads:
		if LevelLayout.is_maze_debris(d) and int(d["maze"]) == index and String(d["part"]) == "divider" \
				and int(d["index"]) == room and int(d["lane"]) == lane and float(d["start"]) < hi and float(d["end"]) > lo:
			out.append(d)
	return out


## An ambush spot's layout entry: params {block, situation "ambush", ambush {room, lane, peek, from, to (the stretch of
## its divider it lies in: ambush_host)}, floor_span}.
static func ambush_entry(index: int, c: Dictionary) -> Dictionary:
	var at: float = float(c["at"])
	return {"type": FEATURE, "at": at, "lane": int(c["lane"]), "side": 0, "params": {"block": index,
		"situation": AMBUSH, "ambush": {"room": int(c["room"]), "lane": int(c["lane"]), "peek": int(c["peek"]),
			"from": at - AMBUSH_HOST_BEFORE, "to": at + Centipede.BODY_LENGTH + AMBUSH_HOST_AFTER},
		"floor_span": Vector2(at - FLOOR_BEFORE, at + Centipede.BODY_LENGTH + FLOOR_AFTER)}}


## The escape proof's spot (CentipedeEscape) for centipede entry `e` of `layout`: {lane, at}, and an ambush's
## {ambush: true, room, peek, host (its debris: ambush_host)} too (ambush_entry makes its entry again from it).
static func spot_of(layout: LevelLayout, e: Dictionary) -> Dictionary:
	var out: Dictionary = {"lane": int(e["lane"]), "at": float(e["at"])}
	if is_ambush(e):
		var params: Dictionary = e["params"]
		var hide: Dictionary = params.get("ambush", {})
		out["ambush"] = true
		out["room"] = int(hide.get("room", -1))
		out["peek"] = int(hide.get("peek", 1))
		out["host"] = ambush_host(layout, int(params.get("block", -1)), int(hide.get("room", -1)), int(e["lane"]),
			float(e["at"]))
	return out


## True if centipede entry `e` (a layout enemy) is an ambush (_place_ambushes).
static func is_ambush(e: Dictionary) -> bool:
	return String((e.get("params", {}) as Dictionary).get("situation", "")) == AMBUSH


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
## escapable (with the block's `ambushes` too: their spots, kept min_spacing from); with `any`, every place in turn
## whatever the weights. Returns how many it placed.
static func _place_block(gen: LevelGenerator, t: CentipedeTuning, rng: RandomNumberGenerator, index: int, start: float,
		want: int, intro: bool, any: bool = false, ambushes: Array = []) -> int:
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
				if String(c["situation"]) == situation and _spaced(c, chosen, t) and _spaced(c, ambushes, t):
					pool.append(c)
			_shuffle(pool, rng)
			for j: int in mini(pool.size(), TRIES if situation == "trapped" else OPEN_TRIES):
				var c: Dictionary = pool[j]
				var entry: Dictionary = _entry(index, c)
				if not gen.zones.enemy_clear(lay, entry):
					continue
				var spots: Array = ambushes.duplicate()
				spots.append_array(chosen)
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
			for k: int in 1 if situation == "trapped" else OPEN_SPOTS:
				out.append({"lane": rng.randi_range(cell.x, cell.y), "at": rng.randf_range(lo, hi), "room": r, "cell": c,
					"situation": situation})
	return out


static func _entry(index: int, c: Dictionary) -> Dictionary:
	var at: float = float(c["at"])
	return {"type": FEATURE, "at": at, "lane": int(c["lane"]), "side": 0, "params": {"block": index,
		"situation": String(c["situation"]),
		"floor_span": Vector2(at - FLOOR_BEFORE, at + Centipede.BODY_LENGTH + FLOOR_AFTER)}}


static func _spaced(c: Dictionary, chosen: Array, t: CentipedeTuning) -> bool:
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

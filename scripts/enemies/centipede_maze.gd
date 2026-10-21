class_name CentipedeMaze
extends RefCounted
## One block of the debris maze as the Cybernetic Centipede sees it (task O3; GDD §9.15: it "haunts the debris maze ...
## moves along the maze's open paths and can't pass debris"). Built from the block's record and its debris in the
## layout (DebrisMaze: LevelLayout.maze, the doodads marked "maze"), and read again whenever a dash smashes some of it on
## this attempt (the pieces' entries marked "smashed": refresh()), so what a dash opens is open to the centipede too.
## Three things in one model, so they never disagree about where the floor is open:
## - the debris standing in each lane (`pieces`, merged where only a sliver lies between two pieces: nothing passes a
##   sliver), and clear_at(): whether a box on the floor touches any of it (the centipede's head never does);
## - a grid of the floor, BIN metres a step along the track in every lane, from just before the block's run-in to just
##   past its breather: `open` (a bin no debris touches), over which find_path() finds the centipede's way toward the
##   runner (a lane change costs a lane's width);
## - field(): the escape check's distance field (CentipedeEscape) over `free` (a bin no debris covers whole), counted
##   along the track only (a lane change costs nothing): never longer than a way the centipede's head can really go,
##   so a runner further from its spot than it can have gone by then is out of its reach whatever it does. (The head
##   keeps HEAD_HALF_WIDTH clear of debris: its middle never lies in a lane whose debris stands beside it, so every place
##   it can be lies in a free bin.)
## block_layout() is the block alone as a LevelLayout, for the maze's own questions about it (DebrisMaze.sections,
## links, open_group) without reading the whole level.

## Metres a grid step along the track.
const BIN: float = 1.0
## The grid reaches this far before the block's run-in and past its breather (metres).
const MARGIN: float = 2.0
## Two pieces of debris in a lane this close count as one (metres): the slivers between a divider's pieces, and between
## a divider and a wall (DebrisMaze.TOUCH), which nothing can pass.
const MERGE_GAP: float = 0.3
## How far the centipede's head keeps from debris across the track (metres; Centipede): more than a lane's half width
## less the narrowest debris's half width (1.2 m less 0.65 m), so its middle is never in a lane whose debris stands
## beside it.
const HEAD_HALF_WIDTH: float = 0.6
## ... and along the track (metres).
const HEAD_HALF_LENGTH: float = 0.35
## No way there.
const FAR: int = 1 << 30
## find_path()'s cost of a step along the track (a lane change costs lateral_cost, both at once their diagonal).
const STEP_COST: int = 10

var layout: LevelLayout
var tuning: MovementTuning
## The block's index in layout.maze, and its record.
var index: int = -1
var block: Dictionary = {}
var lanes: int = 3
var lane_width: float = 2.4
## The grid's first bin starts here (track distance); it has `size` bins in every lane.
var from: float = 0.0
var size: int = 0
## Per lane, the debris standing there as merged intervals Vector2(start, end), in order.
var pieces: Array = []
## free[lane * size + k]: 1 where no debris covers bin k whole (field()'s grid).
var free := PackedByteArray()
## open[lane * size + k]: 1 where no debris touches bin k (find_path()'s grid).
var open := PackedByteArray()
## find_path()'s lane-change cost, and its diagonal (a lane change and a step at once).
var lateral_cost: int = 24
var diagonal_cost: int = 28
## The half width (metres) clear_at() gives every piece of debris: the widest debris's.
var piece_half_width: float = 1.0

## This block's debris entries (the layout's own dictionaries: their "smashed" marks are this attempt's).
var _entries: Array[Dictionary] = []
## How many of them were smashed when the grid was last built.
var _smashed: int = -1


## The model of block `p_index` of `p_layout`'s maze, for the level's movement tuning `p_tuning` (its lane width and
## debris sizes).
static func for_block(p_layout: LevelLayout, p_index: int, p_tuning: MovementTuning) -> CentipedeMaze:
	var m := CentipedeMaze.new()
	m.layout = p_layout
	m.tuning = p_tuning
	m.index = p_index
	m.block = p_layout.maze[p_index]
	m.lanes = p_layout.lane_count
	m.lane_width = p_tuning.lane_width
	m.lateral_cost = maxi(roundi(m.lane_width * STEP_COST / BIN), STEP_COST)
	m.diagonal_cost = int(ceil(sqrt(float(m.lateral_cost * m.lateral_cost + STEP_COST * STEP_COST)))) + 1
	for size_name: StringName in [&"small", &"medium", &"large"]:
		m.piece_half_width = maxf(m.piece_half_width, p_tuning.doodad_size(size_name).x * 0.5)
	m.from = float(m.block["entry"]) - MARGIN
	m.size = int(ceil((float(m.block["exit"]) + MARGIN - m.from) / BIN)) + 1
	for d: Dictionary in p_layout.doodads:
		if LevelLayout.is_maze_debris(d) and int(d["maze"]) == p_index:
			m._entries.append(d)
	m.refresh()
	return m


## The index of the maze block whose stretch, from its run-in's start to its breather's end, holds track distance `at`
## in `p_layout`, or -1.
static func block_at(p_layout: LevelLayout, at: float) -> int:
	for i: int in p_layout.maze.size():
		var b: Dictionary = p_layout.maze[i]
		if at >= float(b["entry"]) and at <= float(b["exit"]):
			return i
	return -1


## Reads which of the block's debris stands (its entries' "smashed" marks) and rebuilds the model if that changed since
## the last read. True if it did.
func refresh() -> bool:
	var count: int = 0
	for d: Dictionary in _entries:
		count += 1 if bool(d.get("smashed", false)) else 0
	if count == _smashed:
		return false
	_smashed = count
	var built: Dictionary = _grids({})
	pieces = built["pieces"]
	free = built["free"]
	open = built["open"]
	return true


## How many of the block's pieces were smashed on this attempt, as of the last refresh().
func smashed_count() -> int:
	return _smashed


## The block's debris entries (the layout's own).
func entries() -> Array[Dictionary]:
	return _entries


## The merged pieces and the grids with the debris standing now, less the entries in `extra` (keys: entries of this
## block: a route's smashes, CentipedeEscape): {pieces, free, open}.
func _grids(extra: Dictionary) -> Dictionary:
	var per_lane: Array = []
	for lane: int in lanes:
		per_lane.append([])
	for d: Dictionary in _entries:
		if bool(d.get("smashed", false)) or extra.has(d):
			continue
		var lane: int = int(d["lane"])
		if lane >= 0 and lane < lanes:
			(per_lane[lane] as Array).append(Vector2(float(d["start"]), float(d["end"])))
	var merged: Array = []
	for lane: int in lanes:
		var list: Array = per_lane[lane]
		list.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		var out: Array[Vector2] = []
		for v: Vector2 in list:
			if not out.is_empty() and v.x <= out[-1].y + MERGE_GAP:
				out[-1] = Vector2(out[-1].x, maxf(out[-1].y, v.y))
			else:
				out.append(v)
		merged.append(out)
	var f := PackedByteArray()
	var o := PackedByteArray()
	f.resize(lanes * size)
	o.resize(lanes * size)
	f.fill(1)
	o.fill(1)
	for lane: int in lanes:
		for v: Vector2 in merged[lane]:
			# The bins it touches aren't open; those it covers whole aren't free.
			var lo: int = maxi(int(floor((v.x - from) / BIN)), 0)
			var hi: int = mini(int(ceil((v.y - from) / BIN)) - 1, size - 1)
			for k: int in range(lo, hi + 1):
				o[lane * size + k] = 0
				var b0: float = from + k * BIN
				if v.x <= b0 + 0.0001 and v.y >= b0 + BIN - 0.0001:
					f[lane * size + k] = 0
	return {"pieces": merged, "free": f, "open": o}


## The bin holding track distance `at` (clamped to the grid).
func bin_of(at: float) -> int:
	return clampi(int(floor((at - from) / BIN)), 0, size - 1)


## The middle of bin `k` (track distance).
func bin_middle(k: int) -> float:
	return from + (k + 0.5) * BIN


## The world x of lane `lane`'s middle (TrackGeometry.lane_x).
func lane_x(lane: int) -> float:
	return (float(lane) - (lanes - 1) * 0.5) * lane_width


## The lane whose middle is nearest world x `x` (TrackGeometry.lane_at).
func lane_at(x: float) -> int:
	return clampi(roundi(x / lane_width + (lanes - 1) * 0.5), 0, lanes - 1)


## True if no debris standing touches the box on the floor from world x `x - half_width` to `x + half_width` and track
## distance `s - half_length` to `s + half_length` (every piece taken as wide as the widest debris), and the box lies on
## the track's lanes inside the block's stretch, from its run-in's start to its breather's end.
func clear_at(x: float, s: float, half_width: float = HEAD_HALF_WIDTH, half_length: float = HEAD_HALF_LENGTH) -> bool:
	var edge: float = lanes * lane_width * 0.5
	if x - half_width < -edge or x + half_width > edge:
		return false
	if s - half_length < float(block["entry"]) or s + half_length > float(block["exit"]):
		return false
	var first: int = maxi(lane_at(x - half_width - piece_half_width), 0)
	var last: int = mini(lane_at(x + half_width + piece_half_width), lanes - 1)
	for lane: int in range(first, last + 1):
		var mid: float = lane_x(lane)
		if x + half_width <= mid - piece_half_width or x - half_width >= mid + piece_half_width:
			continue
		for v: Vector2 in pieces[lane]:
			if v.x >= s + half_length:
				break
			if v.y > s - half_length:
				return false
	return true


## True if bin `k` of `lane` is free (field()'s grid: no debris covers it whole).
func is_free(lane: int, k: int) -> bool:
	return lane >= 0 and lane < lanes and k >= 0 and k < size and free[lane * size + k] == 1


## True if bin `k` of `lane` is open (find_path()'s grid: no debris touches it).
func is_open(lane: int, k: int) -> bool:
	return lane >= 0 and lane < lanes and k >= 0 and k < size and open[lane * size + k] == 1


## The escape check's distance field from `lane` at track distance `at` (CentipedeEscape): for every bin of every lane,
## the fewest bins along the track any way from there over the free grid takes, a lane change costing nothing, or FAR
## where no way leads (debris between). `extra` (keys: this block's debris entries) takes those pieces away first (a
## route's smashes); else the grid as it stands. Indexed [lane * size + k].
func field(lane: int, at: float, extra: Dictionary = {}) -> PackedInt32Array:
	var grid: PackedByteArray = free if extra.is_empty() else _grids(extra)["free"]
	var dist := PackedInt32Array()
	dist.resize(lanes * size)
	dist.fill(FAR)
	var start: int = bin_of(at)
	if lane < 0 or lane >= lanes or grid[lane * size + start] == 0:
		return dist
	# A 0-1 search: lane changes (cost 0) taken first, from a stack; steps along the track (cost 1) from a queue behind.
	var zero: Array[int] = [lane * size + start]
	var one: Array[int] = []
	var head: int = 0
	dist[lane * size + start] = 0
	while true:
		var cell: int = -1
		if not zero.is_empty():
			cell = zero.pop_back()
		elif head < one.size():
			cell = one[head]
			head += 1
		else:
			break
		var l: int = cell / size
		var k: int = cell - l * size
		var d: int = dist[cell]
		if l > 0 and grid[cell - size] == 1 and dist[cell - size] > d:
			dist[cell - size] = d
			zero.append(cell - size)
		if l < lanes - 1 and grid[cell + size] == 1 and dist[cell + size] > d:
			dist[cell + size] = d
			zero.append(cell + size)
		if k > 0 and grid[cell - 1] == 1 and dist[cell - 1] > d + 1:
			dist[cell - 1] = d + 1
			one.append(cell - 1)
		if k < size - 1 and grid[cell + 1] == 1 and dist[cell + 1] > d + 1:
			dist[cell + 1] = d + 1
			one.append(cell + 1)
	return dist


## The bins reachable from `lane` at track distance `at` over the open grid (where the centipede can really go), each
## 1, else 0. Indexed [lane * size + k].
func reach(lane: int, at: float) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(lanes * size)
	var start: Vector2i = nearest_open(lane, at)
	if start.x < 0:
		return out
	var todo: Array[int] = [start.x * size + start.y]
	out[start.x * size + start.y] = 1
	while not todo.is_empty():
		var cell: int = todo.pop_back()
		var l: int = cell / size
		var k: int = cell - l * size
		for n: Vector2i in [Vector2i(l - 1, k), Vector2i(l + 1, k), Vector2i(l, k - 1), Vector2i(l, k + 1)]:
			if is_open(n.x, n.y) and out[n.x * size + n.y] == 0:
				out[n.x * size + n.y] = 1
				todo.append(n.x * size + n.y)
	return out


## The open bin nearest to `lane` at track distance `at` (that bin, else one along the track either side, else in a lane
## either side): Vector2i(lane, bin), or Vector2i(-1, -1) if none within two bins and a lane.
func nearest_open(lane: int, at: float) -> Vector2i:
	var k: int = bin_of(at)
	for dl: int in [0, -1, 1]:
		for dk: int in [0, -1, 1, -2, 2]:
			if is_open(lane + dl, k + dk):
				return Vector2i(lane + dl, k + dk)
	return Vector2i(-1, -1)


## The centipede's way from (`from_lane`, track distance `from_at`) to (`to_lane`, `to_at`) over the open grid: the
## bins it passes, Vector2i(lane, bin) each, first to last (A*, a step along the track costing STEP_COST, a lane change
## lateral_cost, both at once diagonal_cost where both bins beside are open too), searched only between track distances
## `lo` and `hi`. Empty if no way leads there.
func find_path(from_lane: int, from_at: float, to_lane: int, to_at: float, lo: float = -INF, hi: float = INF) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var start: Vector2i = nearest_open(from_lane, from_at)
	var goal: Vector2i = nearest_open(to_lane, to_at)
	if start.x < 0 or goal.x < 0:
		return out
	var k_lo: int = bin_of(lo) if lo > -INF else 0
	var k_hi: int = bin_of(hi) if hi < INF else size - 1
	var g := {}
	var came := {}
	var start_cell: int = start.x * size + start.y
	var goal_cell: int = goal.x * size + goal.y
	g[start_cell] = 0
	# Dial's buckets on f = g + h (h: max of the lane changes' and the steps' cost, never more than the way's: a
	# consistent heuristic, so each bin is settled once).
	var span: int = diagonal_cost + lateral_cost + 2
	var buckets: Array = []
	for i: int in span:
		buckets.append([])
	var f0: int = _heuristic(start, goal)
	(buckets[f0 % span] as Array).append(start_cell)
	var current: int = f0
	var pending: int = 1
	var done := {}
	while pending > 0:
		var bucket: Array = buckets[current % span]
		while not bucket.is_empty():
			var cell: int = bucket.pop_back()
			pending -= 1
			if done.has(cell):
				continue
			var l: int = cell / size
			var k: int = cell - l * size
			var gc: int = int(g[cell])
			if gc + _heuristic(Vector2i(l, k), goal) != current:
				# A stale entry (a cheaper way came since): it waits in its own bucket.
				continue
			done[cell] = true
			if cell == goal_cell:
				var at: int = cell
				while true:
					out.push_front(Vector2i(at / size, at % size))
					if at == start_cell:
						break
					at = int(came[at])
				return out
			for dl: int in [-1, 0, 1]:
				for dk: int in [-1, 0, 1]:
					if dl == 0 and dk == 0:
						continue
					var nl: int = l + dl
					var nk: int = k + dk
					if nk < k_lo or nk > k_hi or not is_open(nl, nk):
						continue
					var cost: int = STEP_COST
					if dl != 0 and dk != 0:
						if not is_open(l + dl, k) or not is_open(l, k + dk):
							continue
						cost = diagonal_cost
					elif dl != 0:
						cost = lateral_cost
					var n: int = nl * size + nk
					var ng: int = gc + cost
					if done.has(n) or ng >= int(g.get(n, FAR)):
						continue
					g[n] = ng
					came[n] = cell
					(buckets[(ng + _heuristic(Vector2i(nl, nk), goal)) % span] as Array).append(n)
					pending += 1
		current += 1
	return out


func _heuristic(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x) * lateral_cost, absi(a.y - b.y) * STEP_COST)


## The block alone as a LevelLayout: its lanes, its record as the only block (index 0) and copies of its debris entries
## marked as that block's, smashed as they are now (made again after a refresh() to show later smashes), for
## DebrisMaze.sections(), links() and open_group().
func block_layout() -> LevelLayout:
	var out := LevelLayout.new()
	out.lane_count = lanes
	out.length = layout.length
	out.maze = [block]
	for d: Dictionary in _entries:
		var copy: Dictionary = d.duplicate()
		copy["maze"] = 0
		out.doodads.append(copy)
	return out

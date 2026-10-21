class_name CentipedeBot
extends RefCounted
## Runs a way out of a block of the debris maze that CentipedeEscape found (task O3) on real physics, past the block's live
## Cybernetic Centipedes, and checks the proof as it goes. Tests only.
## A full RunWorld over its own copy of the layout (its director spawning the block's centipedes from their layout
## entries, as in a level; every other enemy left out), its Player from `lead` metres before the block's run-in in the
## way's start lane, so it comes into the block running, as in a level (that stretch of the copy cleared to open floor:
## the bot runs the block, not what the level put before it), pressing the way's lane switches where it makes them and
## dashing at a stop where it dashes once the dash is ready, standing and waiting for it otherwise (as MazeBot does):
## the dash is ready the way's entry_ready seconds after the runner reaches the run-in (the proof's assumption: the whole
## recharge, as if it had just been used there), then its recharge after each. No armor: a bite kills.
## Besides whether the runner got out alive and unbitten, it checks what the proof rests on (CentipedeEscape's header)
## against the live centipedes: none moves before its wake and wake_time (Centipede.history), any faster than its chase
## speed, with its head in debris (CentipedeMaze.clear_at) or out of its block's stretch; and, with a distance field of
## its own (independent of CentipedeMaze's grid: the head's footprint against each piece of debris on a fine grid,
## diagonal steps and all, every smash of the way open from the start), that at every frame after a centipede woke the
## runner was further along open floor from its spot than it could have run since (CentipedeEscape.run_reach) and its
## bite (CentipedeTuning.bite_reach and the runner's half depth): the proof's bound, on the real run.
##   var bot := CentipedeBot.new(sim, level_tuning)
##   var r: Dictionary = await bot.run(layout, index, CentipedeEscape.find(layout, level_tuning, index, spots))
## result: {alive, cause, reached (past the block's last wall and leave_margin), seconds (from the run-in), dashes,
## moves_left, blocked (switches the Player refused), bites (contacts any centipede's bite made), woke (centipedes that
## woke), before_run_in (of those, the ones that woke while the runner was still short of the run-in: the proof's runner
## starts there, so none may), margin (the least, metres, by which the runner was out of an awake centipede's bound:
## negative if ever within it), early (moved before its wake and wake_time), fast (the most a step went over its chase
## speed, metres), in_debris (frames its head touched debris), outside (frames its head was out of its block's
## stretch)}.

## Metres a step of the independent field's grid, across the track and along it.
const CELL: float = 0.3
## Integer costs of a step along the grid's axes and diagonally (an octile metric), and the most it overstates a straight
## line by: its distances are divided by that, a lower bound on any way the head can go.
const STRAIGHT_COST: int = 5
const DIAGONAL_COST: int = 7
const OCTILE_OVER: float = 1.083
## A switch is pressed this far (metres) before the body's middle reaches where the way makes it (MazeBot.EARLY).
const EARLY: float = 0.25
## Seconds past the way's time the run may take before it's given up.
const GRACE_SECONDS: float = 6.0
## No way there.
const FAR: int = 1 << 30
## The lead-in is cleared this much further back than the runner starts (metres): a piece just behind it can't reach it.
const LEAD_CLEAR: float = 5.0

var sim: RunSim
var tuning: MovementTuning
## How far before the block's run-in the runner starts (metres; see the header).
var lead: float = 25.0
## Records every frame's {t, d, x, lane, stopped, dashing} in the result's `trace`, and the Player's events in `events`.
var trace: bool = false


func _init(p_sim: RunSim, p_tuning: MovementTuning) -> void:
	sim = p_sim
	tuning = p_tuning


func run(layout: LevelLayout, index: int, way: Dictionary) -> Dictionary:
	var result := {"alive": false, "cause": "", "reached": false, "seconds": 0.0, "dashes": 0, "moves_left": 0,
		"blocked": 0, "bites": 0, "woke": 0, "before_run_in": 0, "margin": INF, "early": 0, "fast": 0.0, "in_debris": 0,
		"outside": 0, "trace": [], "events": []}
	var copy: LevelLayout = layout.copy()
	var b: Dictionary = copy.maze[index]
	var entry: float = float(b["entry"])
	var from: float = maxf(entry - lead, 1.0)
	_clear_lead_in(copy, index, from - LEAD_CLEAR, entry)
	var t := EnemyDirector.tuning_for("centipede") as CentipedeTuning
	var world: RunWorld = sim.build_world(copy, Loadout.new(), tuning)
	var p: Player = world.player
	p.setup(tuning, world.geo, int(way.get("start_lane", 0)))
	p.distance = from
	p.died.connect(func(cause: String) -> void: result["cause"] = cause)
	p.movement_event.connect(func(kind: StringName) -> void:
		(result["events"] as Array).append([snappedf(p.distance, 0.01), kind])
		if kind == &"lane_blocked":
			result["blocked"] = int(result["blocked"]) + 1)
	var maze := CentipedeMaze.for_block(copy, index, tuning)
	var fields: Dictionary = {}
	var grid: Dictionary = _grid(copy, index, way)
	var v_c: float = t.chase_speed(tuning.run_speed)
	var reach: float = t.bite_reach(CentipedeMaze.HEAD_HALF_LENGTH) + tuning.visual_size.z * 0.5
	var leave: float = float(b["end"]) + t.leave_margin
	var dt: float = 1.0 / Engine.physics_ticks_per_second
	await sim.tree.physics_frame
	await sim.tree.physics_frame
	p.running = true
	var start_t: float = world.level_time()
	var moves: Array = way.get("moves", [])
	var m: int = 0
	var pressed: int = -1
	# The dash's cooldown starts as the runner reaches the run-in (see the header).
	var cooldown: float = INF
	var entered_t: float = INF
	var recharge: float = float(way.get("recharge", 8.0))
	var limit: int = int((float(way.get("seconds", 30.0)) * 1.25 + GRACE_SECONDS + (entry - from) / tuning.run_speed)
		* Engine.physics_ticks_per_second)
	var seen: Dictionary = {}
	for frame: int in limit:
		if entered_t == INF and p.distance >= entry:
			entered_t = world.level_time()
			cooldown = float(way.get("entry_ready", CentipedeEscape.entry_ready(recharge)))
		if m < moves.size():
			var move: Dictionary = moves[m]
			var kind: String = String(move["kind"])
			var to_lane: int = int(move["to"])
			var settled: bool = int(p.call(&"_switch_dir")) == 0
			if kind == "dash":
				if p.stopped and settled and p.lane == int(move["lane"]) and p.distance >= float(move["at"]) - MazeRoute.STEP:
					if cooldown <= 0.0:
						RunSim.act(p, &"dash")
						cooldown = recharge
						result["dashes"] = int(result["dashes"]) + 1
						m += 1
			elif p.lane == to_lane:
				if settled:
					m += 1
					pressed = -1
			elif p.distance >= float(move["at"]) - EARLY or p.stopped:
				if pressed != m or settled:
					p.press(&"move_right" if to_lane > p.lane else &"move_left")
					pressed = m
		await sim.tree.physics_frame
		cooldown -= dt
		var now: float = world.level_time() - start_t
		# What the runner's dashes smashed is open to the centipedes too (they read it the same way).
		maze.refresh()
		if trace:
			(result["trace"] as Array).append({"t": now, "d": p.distance, "x": p.position.x, "lane": p.lane,
				"stopped": p.stopped, "dashing": p.dashing})
		for e: Enemy in world.director.active:
			if not is_instance_valid(e) or not (e is Centipede):
				continue
			var c := e as Centipede
			if c.block_index != index:
				continue
			var id: int = c.get_instance_id()
			if not seen.has(id):
				seen[id] = {"spot": c.head(), "prev": c.head(), "wake": INF, "bites": 0}
			var s: Dictionary = seen[id]
			s["bites"] = c.bite_contacts.size()
			if c.state != Centipede.State.SLEEP and float(s["wake"]) == INF:
				s["wake"] = float((c.history[0] as Array)[1]) - start_t
				result["woke"] = int(result["woke"]) + 1
				if float((c.history[0] as Array)[2]) < entry:
					result["before_run_in"] = int(result["before_run_in"]) + 1
			var head: Vector2 = c.head()
			var step: float = head.distance_to(s["prev"])
			result["fast"] = maxf(float(result["fast"]), step - v_c * dt)
			if step > 0.0001 and (float(s["wake"]) == INF or now < float(s["wake"]) + t.wake_time - dt * 0.5):
				result["early"] = int(result["early"]) + 1
			s["prev"] = head
			if not maze.clear_at(head.x, head.y):
				result["in_debris"] = int(result["in_debris"]) + 1
			if head.y < float(b["entry"]) or head.y > float(b["exit"]):
				result["outside"] = int(result["outside"]) + 1
			# The proof's bound with the field of its own (see the header).
			if float(s["wake"]) < INF and p.distance <= leave:
				var key: String = "%.3f|%.3f" % [(s["spot"] as Vector2).x, (s["spot"] as Vector2).y]
				if not fields.has(key):
					fields[key] = _field(grid, s["spot"])
				var d: float = _distance(grid, fields[key], p.position.x, p.distance)
				var gone: float = CentipedeEscape.run_reach(now - float(s["wake"]) - t.wake_time, v_c, t.acceleration)
				result["margin"] = minf(float(result["margin"]), d - gone - reach)
		if not p.alive:
			break
		if p.distance >= leave + 1.0:
			result["reached"] = true
			break
	for id: int in seen:
		result["bites"] = int(result["bites"]) + int((seen[id] as Dictionary)["bites"])
	result["alive"] = p.alive
	result["seconds"] = world.level_time() - (entered_t if entered_t < INF else start_t)
	result["moves_left"] = moves.size() - m
	await sim.free_world(world)
	return result


## Clears `layout` (the bot's copy) from `from` to the block's run-in at `to` (see the header): every piece standing on
## or under the floor there (zone doodads and other blocks' debris, holes, floor cuts, fences, pads, speed pads, dash
## walls), and every enemy but block `index`'s own centipedes.
static func _clear_lead_in(layout: LevelLayout, index: int, from: float, to: float) -> void:
	var doodads: Array[Dictionary] = []
	for d: Dictionary in layout.doodads:
		if (LevelLayout.is_maze_debris(d) and int(d["maze"]) == index) or not _overlaps(d, from, to):
			doodads.append(d)
	layout.doodads = doodads
	layout.gaps = _clear_of(layout.gaps, from, to)
	layout.cuts = _clear_of(layout.cuts, from, to)
	layout.fences = _clear_of(layout.fences, from, to)
	layout.pads = _clear_of(layout.pads, from, to)
	layout.speed_pads = _clear_of(layout.speed_pads, from, to)
	layout.dash_walls = _clear_of(layout.dash_walls, from, to)
	var enemies: Array[Dictionary] = []
	for e: Dictionary in layout.enemies:
		if String(e["type"]) == "centipede" and int((e.get("params", {}) as Dictionary).get("block", -1)) == index:
			enemies.append(e)
	layout.enemies = enemies


## The entries of `list` clear of the stretch from `from` to `to`.
static func _clear_of(list: Array[Dictionary], from: float, to: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in list:
		if not _overlaps(e, from, to):
			out.append(e)
	return out


## True if entry `e` (from its `start` to its `end`, or at its `at`) lies on the stretch from `from` to `to`.
static func _overlaps(e: Dictionary, from: float, to: float) -> bool:
	var lo: float = float(e.get("start", e.get("at", 0.0)))
	var hi: float = float(e.get("end", lo))
	return hi >= from and lo < to


# --- The independent field --------------------------------------------------------------------------

## The block's floor on a fine grid (see the header): {x0, z0, nx, nz, open (PackedByteArray: 1 where the head's
## footprint, CentipedeMaze.HEAD_HALF_WIDTH across and HEAD_HALF_LENGTH along, touches no standing piece and lies on the
## track inside the block's stretch)}, every piece of the block the way smashes taken away.
func _grid(layout: LevelLayout, index: int, way: Dictionary) -> Dictionary:
	var b: Dictionary = layout.maze[index]
	var lanes: int = layout.lane_count
	var edge: float = lanes * tuning.lane_width * 0.5
	var hw: float = CentipedeMaze.HEAD_HALF_WIDTH
	var hl: float = CentipedeMaze.HEAD_HALF_LENGTH
	var x0: float = -edge + hw
	var z0: float = float(b["entry"]) + hl
	var nx: int = maxi(int(floor((edge - hw - x0) / CELL)) + 1, 1)
	var nz: int = maxi(int(floor((float(b["exit"]) - hl - z0) / CELL)) + 1, 1)
	var open := PackedByteArray()
	open.resize(nx * nz)
	open.fill(1)
	var gone: Dictionary = _smashes(layout, index, way)
	for d: Dictionary in layout.doodads:
		if not LevelLayout.is_maze_debris(d) or int(d["maze"]) != index or gone.has(_key(d)):
			continue
		var size: Vector3 = tuning.doodad_size(StringName(d["size"]))
		var mid: float = (float(d["lane"]) - (lanes - 1) * 0.5) * tuning.lane_width
		# Cells whose footprint overlaps the piece (strictly).
		var ix0: int = maxi(int(ceil((mid - size.x * 0.5 - hw - x0) / CELL - 0.0001)), 0)
		var ix1: int = mini(int(floor((mid + size.x * 0.5 + hw - x0) / CELL + 0.0001)), nx - 1)
		var iz0: int = maxi(int(ceil((float(d["start"]) - hl - z0) / CELL - 0.0001)), 0)
		var iz1: int = mini(int(floor((float(d["end"]) + hl - z0) / CELL + 0.0001)), nz - 1)
		for ix: int in range(ix0, ix1 + 1):
			for iz: int in range(iz0, iz1 + 1):
				open[iz * nx + ix] = 0
	return {"x0": x0, "z0": z0, "nx": nx, "nz": nz, "open": open}


## The pieces way `way` smashes (its dashes, and as far as each dash's carry reaches in its lane beyond: taken generously,
## every piece of the lane from the dash's face to its carry past the next), by _key.
func _smashes(layout: LevelLayout, index: int, way: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var pt := load(CentipedeEscape.POWERUPS_PATH) as PowerupTuning
	var carry: float = (tuning.run_speed + (pt.dash_speed_bonus if pt != null else 8.0)) * (pt.dash_duration if pt != null else 0.6)
	for move: Dictionary in way.get("moves", []):
		if String(move["kind"]) != "dash":
			continue
		var lane: int = int(move["lane"])
		var face: float = float(move["at"])
		for d: Dictionary in layout.doodads:
			if LevelLayout.is_maze_debris(d) and int(d["maze"]) == index and int(d["lane"]) == lane \
					and float(d["end"]) >= face and float(d["start"]) <= face + carry + 1.0:
				out[_key(d)] = true
	return out


static func _key(d: Dictionary) -> String:
	return "%d|%.3f" % [int(d["lane"]), float(d["start"])]


## The field from a centipede's head at `spot` (x: world x, y: track distance) over `grid`: for every cell, the least cost
## of a way there (Dial's buckets over the octile costs), or FAR. (The buckets are typed and appended to by index: a
## packed array cast with `as` is a copy, and appending to it would leave the bucket empty.)
func _field(grid: Dictionary, spot: Vector2) -> PackedInt32Array:
	var nx: int = grid["nx"]
	var nz: int = grid["nz"]
	var open: PackedByteArray = grid["open"]
	var dist := PackedInt32Array()
	dist.resize(nx * nz)
	dist.fill(FAR)
	var sx: int = clampi(roundi((spot.x - float(grid["x0"])) / CELL), 0, nx - 1)
	var sz: int = clampi(roundi((spot.y - float(grid["z0"])) / CELL), 0, nz - 1)
	var start: int = sz * nx + sx
	dist[start] = 0
	# The eight steps: across, along, and both (a diagonal only where both cells beside it are open).
	var steps_x := PackedInt32Array([-1, 1, 0, 0, -1, 1, -1, 1])
	var steps_z := PackedInt32Array([0, 0, -1, 1, -1, -1, 1, 1])
	var span: int = DIAGONAL_COST + 1
	var buckets: Array[PackedInt32Array] = []
	for i: int in span:
		buckets.append(PackedInt32Array())
	buckets[0].append(start)
	var current: int = 0
	var pending: int = 1
	while pending > 0:
		var slot: int = current % span
		var bucket: PackedInt32Array = buckets[slot]
		buckets[slot] = PackedInt32Array()
		pending -= bucket.size()
		for cell: int in bucket:
			if dist[cell] != current:
				continue
			var iz: int = cell / nx
			var ix: int = cell - iz * nx
			for j: int in 8:
				var jx: int = ix + steps_x[j]
				var jz: int = iz + steps_z[j]
				if jx < 0 or jx >= nx or jz < 0 or jz >= nz:
					continue
				var n: int = jz * nx + jx
				if open[n] == 0:
					continue
				var cost: int = STRAIGHT_COST
				if j >= 4:
					if open[iz * nx + jx] == 0 or open[jz * nx + ix] == 0:
						continue
					cost = DIAGONAL_COST
				var nd: int = current + cost
				if nd < dist[n]:
					dist[n] = nd
					buckets[nd % span].append(n)
					pending += 1
		current += 1
	return dist


## The least distance (metres, a lower bound) from the field's spot to world x `x` at track distance `z` for a head that
## goes along open floor and ends anywhere near there: over the open cells within two of it, the way's length to the cell
## and the straight line on from it, less the rounding of the spot and the cell to the grid; INF where no way leads.
func _distance(grid: Dictionary, field: PackedInt32Array, x: float, z: float) -> float:
	var nx: int = grid["nx"]
	var nz: int = grid["nz"]
	var x0: float = grid["x0"]
	var z0: float = grid["z0"]
	var ix: int = clampi(roundi((x - x0) / CELL), 0, nx - 1)
	var iz: int = clampi(roundi((z - z0) / CELL), 0, nz - 1)
	var best: float = INF
	for dz: int in range(-2, 3):
		for dx: int in range(-2, 3):
			var jx: int = ix + dx
			var jz: int = iz + dz
			if jx < 0 or jx >= nx or jz < 0 or jz >= nz:
				continue
			var d: int = field[jz * nx + jx]
			if d >= FAR:
				continue
			var way: float = float(d) / STRAIGHT_COST * CELL / OCTILE_OVER
			best = minf(best, way + Vector2(x0 + jx * CELL - x, z0 + jz * CELL - z).length())
	return best - CELL * 0.75 if best < INF else INF

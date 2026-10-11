extends TestSuite
## Mecha Guppy's floor bite (GDD §10, the owner, October 11, 2026: "The floor bite"; task E5e-f: MechaGuppyCrescent,
## MechaGuppyClimb's plan, MechaGuppyFloorBite, MechaGuppyShark.floor_bite, MechaGuppyStairs.eat_crescent), at 3, 5 and 6
## lanes, at 18 and 23.8 m/s, in phases 1 and 2:
## - the plan (MechaGuppyBiteChecks, over many steps): a bite on roof 1 and every other roof from FIRST_NOTCH on, a crescent
##   from one side, deepest in the middle; phase 1's leaving exactly one lane, the far side's outer one (2 of 3, 4 of 5, 5
##   of 6 taken at its deepest, fewer toward its ends); every other one of phase 2's crossing every lane, its longest
##   stretch in each lane at most full_jump_share of a jump (shorter than a normal jump covers), longest on the bitten
##   side; past the landing, short of the pads and the notch, the notch on its side (the lane it leaves is never the
##   notch's); its warning never before the hut's deadline, with a reaction, every switch from the farthest lane and
##   dodge_margin before it; its sides seeded, both sides, never three running; the same bites whichever lanes lead up (no
##   third cue); every one of a kind alike in either phase (no escalation), and a retry planning the same;
## - collision matches the look: rays down a grid over an eaten roof find the floor exactly where its deck is drawn and
##   nowhere in the crescent (but within EDGE of its edge); at its deepest only the lane it leaves has floor, under a
##   runner's whole footprint (none on a full-width bite);
## - the warning, in the real fight: the crescent's outline and fill on the floor in the enemy attacks' red, unfogged, from
##   the moment it shows until the snap, a floor warning on every lane it takes and none on the lane it leaves; the rumble
##   as Mecha Guppy rises, its snout towering beside the roof's side and its jaws off the track there; its jaws never over
##   the lane it leaves; the crunch (guppy_bite) as they snap; never before the hut's deadline; the outline's frame steady
##   with Reduced flashing (only deepening), beating otherwise;
## - the margins on real movement, in the worst case (where the riders onto a bitten roof can first switch, the runner moved
##   across into the bitten side's outer lane, the farthest from the one it leaves, the bot reading the warning
##   dodge_reaction late): it crosses into the lane the bite leaves with dodge_margin to spare (measured from where the
##   runner was as the warning showed) and passes in it; over a full-width bite (from that lane, its longest stretch), a
##   reaction before the earliest take-off and a jump that clears the stretch at both ends;
## - the snap, on real contact: a runner in the bite's area as it snaps without protection dies of Mecha Guppy's bite; the
##   armor's block, the shield's and a dash through it each hold the floor under them (GameRules.cut_hold_seconds) and they
##   run on past the hole; one beside it, in the lane it leaves, is untouched;
## - a fall into the gap: the grapple's save and a revive pull the runner up onto the roof (past the gap, or into a lane it
##   leaves) and they run on; no hit for that step;
## - a retry plays the same.

const BOSS_PATH: String = "res://data/bosses/beach_boss.tres"
const LANES: Array[int] = [3, 5, 6]
const SPEEDS: Array[float] = [18.0, 23.8]
## The bot's reaction reading a hut (the suites' usual 0.35 s; it reads the floor bite the planner's dodge_reaction late).
const REACTION: float = 0.35
## Steps planned for the plan's checks.
const PLAN_STEPS: int = 40
## A physics frame (seconds).
const FRAME: float = 1.0 / 60.0
## Collision against the look: grid points this close to the bite's edge (metres) are left out, and its steps.
const EDGE: float = 0.12
const GRID_X: float = 0.29
const GRID_D: float = 0.37

var sim: RunSim
var def: BossDef
var dash_reach: float = 0.0


func run() -> void:
	sim = RunSim.new(tree, tuning)
	var slot := load(BOSS_PATH) as BossDef
	def = slot if slot != null and slot.is_built() else null
	if def == null:
		check(false, "Mecha Guppy and Captain Cogs' fight loads")
		return
	dash_reach = MechaGuppyClimb.dash_reach_of(load("res://data/tuning/powerups.tres") as PowerupTuning)
	_test_plan()
	_test_no_third_cue()
	_test_same_every_time()
	await _test_collision()
	await _test_warning()
	await _test_reduced_flashing()
	await _test_margins()
	await _test_snap()
	await _test_falls()
	await _test_retry()


# --- Helpers -------------------------------------------------------------------------------------------

func _movement(speed: float) -> MovementTuning:
	if is_equal_approx(speed, tuning.run_speed):
		return tuning
	var t: MovementTuning = tuning.duplicate() as MovementTuning
	t.run_speed = speed
	return t


## The fight at `lanes` and `speed` m/s from phase index `phase` (a resume), its attacks on, with `loadout`: [world, boss].
func _fight(lanes: int, speed: float, phase: int = 0, loadout: Loadout = null) -> Array:
	var t: MovementTuning = _movement(speed)
	var boss := BossEncounter.create(def) as MechaGuppy
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = def
	ctx.config = BossArena.base_config(def)
	ctx.config.lane_count = lanes
	ctx.tuning = t
	if phase > 0:
		ctx.boss_resume = {"phase": phase}
	var arena: BossArena = boss.plan_arena(ctx)
	var world: RunWorld = sim.build_world(arena.layout, loadout, t, ctx.config)
	boss.setup(world, ctx, arena)
	return [world, boss]


## The climb's plan at `lanes` and `speed` m/s in phase index `phase` (tuning `t`, the slot's by default), PLAN_STEPS steps.
func _plan(lanes: int, speed: float, phase: int, t: MechaGuppyTuning = null, seed: int = 7) -> MechaGuppyClimb:
	var mt: MechaGuppyTuning = t if t != null else def.tuning as MechaGuppyTuning
	var c: MechaGuppyClimb = MechaGuppyClimb.make(_movement(speed), mt, lanes, dash_reach, seed)
	for i: int in PLAN_STEPS:
		c.plan_next(phase)
	return c


func _events(boss: BossEncounter, event: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in boss.events:
		if e["event"] == event:
			out.append(e)
	return out


## Steps the world until `done` holds, the runner dies or `seconds` pass, calling `each` before every frame.
func _run(world: RunWorld, seconds: float, done: Callable, each: Callable = Callable()) -> void:
	if not world.player.running:
		await tree.physics_frame
		world.player.running = true
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		if each.is_valid():
			each.call()
		if done.call() or not world.player.alive:
			return
		await tree.physics_frame


## Moves the runner across into `lane` where they are, no switch under way (the worst case's farthest lane, a bitten lane).
func _shift(world: RunWorld, lane: int) -> void:
	var p: Player = world.player
	var x: float = world.geo.lane_x(lane)
	p.lane = lane
	p.set(&"_x", x)
	p.set(&"_switch_from", x)
	p.set(&"_switch_to", x)
	p.set(&"_switch_t", 1.0)
	p.set(&"_bumping", false)


## Roof `k`'s bite once planned, else null.
func _bite_on(boss: MechaGuppy, k: int) -> MechaGuppyCrescent:
	return boss.climb.roofs[k].bite if boss.climb.roofs.size() > k else null


## The bitten side's outer lane of `bite`: the farthest from the lane it leaves, and its longest stretch.
static func _bitten_outer(bite: MechaGuppyCrescent) -> int:
	return 0 if bite.side < 0 else bite.lanes - 1


## Every bite of plan `c`, one per line: its roof, side, lane left, width, place and moments.
static func _bite_sig(c: MechaGuppyClimb) -> String:
	var lines: PackedStringArray = []
	for r: MechaGuppyClimb.Roof in c.roofs:
		var b: MechaGuppyCrescent = r.bite
		if b != null:
			lines.append("%d %d %d %s %.3f %.3f %.3f %.3f %.3f" % [b.roof, b.side, b.keep, b.full, b.from, b.to, b.deepest(),
				b.warn_at, b.snap_at])
	return "\n".join(lines)


# --- The plan --------------------------------------------------------------------------------------------

## The plan's promises (MechaGuppyBiteChecks) over PLAN_STEPS steps at 3, 5 and 6 lanes, both speeds, phases 1 and 2: phase
## 2's full-width ones every other bitten roof from FIRST_NOTCH on, none in phase 1; both sides bitten; the numbers printed.
func _test_plan() -> void:
	var t := def.tuning as MechaGuppyTuning
	for speed: float in SPEEDS:
		for lanes: int in LANES:
			for phase: int in 2:
				var tag: String = "(%d lanes, %.1f m/s, phase %d)" % [lanes, speed, phase + 1]
				var c: MechaGuppyClimb = _plan(lanes, speed, phase)
				var why: String = MechaGuppyBiteChecks.plan_problem(c, t)
				var v: float = c.speed
				var h: float = c.movement.hurtbox_size.z * 0.5
				var switch: float = c.movement.lane_switch_time
				var jump: float = c.jump_seconds() * v
				var bites: int = 0
				var full: Array[int] = []
				var want_full: Array[int] = []
				var sides: Dictionary = {-1: 0, 1: 0}
				var least: float = INF
				var longest: float = 0.0
				var shortest: float = INF
				var warning: Vector2 = Vector2(INF, -INF)
				var length: float = 0.0
				var deepest: float = 0.0
				for r: MechaGuppyClimb.Roof in c.roofs:
					var b: MechaGuppyCrescent = r.bite
					if b == null:
						continue
					bites += 1
					sides[b.side] = int(sides[b.side]) + 1
					if phase >= 1 and r.index >= MechaGuppyClimb.FIRST_NOTCH and (r.index >> 1) % t.full_every == 0:
						want_full.append(r.index)
					var into: MechaGuppyClimb.Step = c.steps[r.index - 1]
					var seconds: float = (b.from - b.warn_at) / v
					warning = Vector2(minf(warning.x, seconds), maxf(warning.y, seconds))
					if b.full:
						full.append(r.index)
						for lane: int in lanes:
							var s: Vector2 = b.lane_stretch(lane)
							longest = maxf(longest, s.y - s.x)
							shortest = minf(shortest, s.y - s.x)
					else:
						least = minf(least, (b.from - maxf(b.warn_at + t.dodge_reaction * v, into.free_at) - h) / v
							- float(lanes - 1) * switch)
						length = b.to - b.from
						deepest = b.deepest()
				check(why == "" and bites >= 10 and full == want_full and (phase == 1) != full.is_empty()
					and int(sides[-1]) > 0 and int(sides[1]) > 0,
					"every floor bite keeps its promises: its shape (one lane left at its deepest; phase 2's every other one full width, jumpable in every lane), its place, its warning; both sides bitten %s%s"
					% [tag, "" if why == "" else ": " + why])
				print("  Mecha Guppy's floor bites %s: %d bites (%d from the left, %d from the right; full width on roofs %s), one that leaves a lane %.1f m long and %.1f m deep, warned %.2f-%.2f s before the runner reaches it, least %.2f s to spare after a reaction and the switches from the farthest lane%s"
					% [tag, bites, int(sides[-1]), int(sides[1]), full, length, deepest, warning.x, warning.y, least,
						"" if full.is_empty() else "; full width: %.1f-%.1f m a lane against a %.1f m jump" % [shortest, longest, jump]])


## The bites have nothing to do with the lanes that lead up (no third cue: GDD §10's two cues are the only ones): on 5 and 6
## lanes, with other up_counts (other blocks of lanes leading up) every bite is the same, on the same side, at the same
## place, warned at the same moment.
func _test_no_third_cue() -> void:
	var base := def.tuning as MechaGuppyTuning
	var same: bool = true
	var ups_differ: bool = true
	for lanes: int in [5, 6]:
		for phase: int in 2:
			var sigs: Array[String] = []
			var ups: Dictionary = {}
			for counts: PackedInt32Array in [base.up_counts, PackedInt32Array([1]), PackedInt32Array([3, 3]), PackedInt32Array([2, 1])]:
				var t: MechaGuppyTuning = base.duplicate() as MechaGuppyTuning
				t.up_counts = counts
				var c: MechaGuppyClimb = _plan(lanes, 23.8, phase, t)
				sigs.append(_bite_sig(c))
				var up_sig: PackedStringArray = []
				for s: MechaGuppyClimb.Step in c.steps:
					up_sig.append(str(s.up))
				ups[",".join(up_sig)] = true
			for sig: String in sigs:
				same = same and sig == sigs[0] and sig != ""
			ups_differ = ups_differ and ups.size() == 4
	check(same and ups_differ,
		"the floor bites have nothing to do with the lanes that lead up: with other blocks of lanes leading up (up_counts), every bite the same, on the same side, at the same place, warned at the same moment (5 and 6 lanes, phases 1 and 2)")


## The same every time: a retry plans the same bites; every bite that leaves a lane is alike (its length, depth, side's lane
## left, its warning's lead), in either phase, early or late in the climb, and so is every full-width one (no escalation).
func _test_same_every_time() -> void:
	var retry: bool = true
	var alike: bool = true
	var why: String = ""
	for lanes: int in LANES:
		for speed: float in SPEEDS:
			retry = retry and _bite_sig(_plan(lanes, speed, 0)) == _bite_sig(_plan(lanes, speed, 0)) \
				and _bite_sig(_plan(lanes, speed, 1)) == _bite_sig(_plan(lanes, speed, 1))
			var kinds: Dictionary = {}
			for phase: int in 2:
				var c: MechaGuppyClimb = _plan(lanes, speed, phase)
				for r: MechaGuppyClimb.Roof in c.roofs:
					var b: MechaGuppyCrescent = r.bite
					if b == null:
						continue
					var shape: String = "%.3f %.3f %.3f" % [b.to - b.from, b.deepest(), b.from - b.snap_at]
					var key: String = "full" if b.full else "keep"
					if kinds.has(key) and kinds[key] != shape:
						alike = false
						if why == "":
							why = "(%d lanes, %.1f m/s, phase %d) roof %d: %s against %s" % [lanes, speed, phase + 1, r.index, shape, kinds[key]]
					kinds[key] = shape
	check(retry, "a retry plans the same floor bites, in each phase (3, 5 and 6 lanes, both speeds)")
	check(alike, "no escalation: every floor bite that leaves a lane is alike (length, depth, snap), early or late, in phase 1 or 2, and every full-width one%s"
		% ("" if why == "" else ": " + why))


# --- Collision and the look --------------------------------------------------------------------------------

## An eaten bite (roof 2's in phase 1, roof 4's full-width one in phase 2) at 3, 5 and 6 lanes: rays down a grid over it
## find the floor exactly where the roof's deck is drawn, and nowhere in the crescent (but within EDGE of its edge); at its
## deepest a runner's whole footprint has floor only in the lane it leaves (in no lane on a full-width bite).
func _test_collision() -> void:
	for lanes: int in LANES:
		for phase: int in 2:
			var k: int = 2 if phase == 0 else 4
			var tag: String = "(%d lanes, phase %d, roof %d)" % [lanes, phase + 1, k]
			var pair: Array = _fight(lanes, 23.8, phase)
			var world: RunWorld = pair[0]
			var boss: MechaGuppy = pair[1]
			boss.attacks_enabled = false
			var c: MechaGuppyClimb = boss.climb
			while c.steps.size() <= k:
				c.plan_next(boss.phase_index)
			var roof: MechaGuppyClimb.Roof = c.roofs[k]
			var bite: MechaGuppyCrescent = roof.bite
			if bite == null or bite.full != (phase == 1):
				check(false, "roof %d has its floor bite %s" % [k, tag])
				await sim.free_world(world)
				continue
			var p: Player = world.player
			p.distance = bite.from - 20.0
			p.surface = Player.Surface.FLOOR
			p.floor_y = roof.top
			p.h = roof.top
			p.floor_base = roof.top
			p.grounded = true
			boss.stairs.update(p.distance)
			await tree.physics_frame
			bite.warned = true
			boss.stairs.eat_crescent(k)
			await tree.physics_frame
			await tree.physics_frame
			var r: Dictionary = _compare(world, boss, roof, bite)
			check(int(r["bad"]) == 0 and int(r["gap"]) > 40 and int(r["floor"]) > 40,
				"collision matches the look: the floor exactly where the deck is drawn, none in the crescent (%d points in the gap, %d on the floor, %d wrong%s) %s"
				% [int(r["gap"]), int(r["floor"]), int(r["bad"]), "" if String(r["first"]) == "" else ": " + String(r["first"]), tag])
			# A runner's whole footprint at its deepest (its middle), lane by lane.
			var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
			var ray := PhysicsRayQueryParameters3D.new()
			ray.collision_mask = TrackBuilder.LAYER_FLOOR
			var mid: float = (bite.from + bite.to) * 0.5
			var kept: Array[int] = []
			var part: Array[int] = []
			for lane: int in lanes:
				var corners: int = 0
				for dx: float in [-world.tuning.foot_half_width, world.tuning.foot_half_width]:
					for dd: float in [-world.tuning.foot_half_depth, world.tuning.foot_half_depth]:
						var x: float = world.geo.lane_x(lane) + dx
						ray.from = Vector3(x, roof.top + 1.0, -(mid + dd))
						ray.to = Vector3(x, roof.top - 0.5, -(mid + dd))
						corners += 0 if space.intersect_ray(ray).is_empty() else 1
				if corners == 4:
					kept.append(lane)
				elif corners > 0:
					part.append(lane)
			var want: Array[int] = []
			if not bite.full:
				want.append(bite.keep)
			check(kept == want and part.is_empty(),
				"at its deepest a runner's whole footprint has floor in lanes %s only (%s), none of it in any other %s"
				% [kept, "none: full width" if bite.full else "the one it leaves, %d" % bite.keep, tag])
			await sim.free_world(world)


## Rays down a grid over roof `roof`'s eaten bite `bite` against its look (the roof pieces' deck): {bad (points where the
## floor found, the deck drawn and the plan's gap disagree), gap, floor (points of each), first (the first disagreement)}.
func _compare(world: RunWorld, boss: MechaGuppy, roof: MechaGuppyClimb.Roof, bite: MechaGuppyCrescent) -> Dictionary:
	var bins: Dictionary = _deck(boss, roof.index, roof.top, bite.from - 3.0, bite.to + 3.0)
	var edge: PackedVector2Array = bite.edge()
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collision_mask = TrackBuilder.LAYER_FLOOR
	var out: Dictionary = {"bad": 0, "gap": 0, "floor": 0, "first": ""}
	var wall: float = world.geo.wall_x()
	var d: float = bite.from - 1.5
	while d <= bite.to + 1.5:
		var x: float = -wall + 0.1
		while x <= wall - 0.1:
			if _edge_distance(edge, Vector2(x, d)) >= EDGE:
				var gap: bool = bite.in_gap(x, d)
				ray.from = Vector3(x, roof.top + 1.0, -d)
				ray.to = Vector3(x, roof.top - 0.5, -d)
				var hit: Dictionary = space.intersect_ray(ray)
				var solid: bool = not hit.is_empty() and absf((hit["position"] as Vector3).y - roof.top) < 0.02
				var drawn: bool = _covered(bins, x, d)
				out["gap" if gap else "floor"] = int(out["gap" if gap else "floor"]) + 1
				if solid == gap or drawn != solid:
					out["bad"] = int(out["bad"]) + 1
					if String(out["first"]) == "":
						out["first"] = "at x %.2f, %.2f m: %s, %s, %s" % [x, d, "in the gap" if gap else "off it",
							"floor" if solid else "no floor", "deck drawn" if drawn else "no deck"]
			x += GRID_X
		d += GRID_D
	return out


## The up-facing triangles of roof `k`'s look at its deck's height `top` between track distances d0 and d1, binned by the
## metre along the track: {bin: [PackedVector2Array(corners as Vector2(x, d))]}.
func _deck(boss: MechaGuppy, k: int, top: float, d0: float, d1: float) -> Dictionary:
	var bins: Dictionary = {}
	var nodes: Dictionary = boss.stairs.get(&"_roof_nodes")
	for entry: Dictionary in nodes.get(k, []):
		var held: Variant = entry["node"]
		if not is_instance_valid(held):
			continue
		var node: Node = held
		if node.is_queued_for_deletion() or node is CollisionObject3D:
			continue
		for found: Node in node.find_children("*", "MeshInstance3D", true, false):
			var inst := found as MeshInstance3D
			var mesh := inst.mesh as ArrayMesh
			if mesh == null:
				continue
			var xf: Transform3D = inst.global_transform
			for s: int in mesh.get_surface_count():
				var arrays: Array = mesh.surface_get_arrays(s)
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var raw: Variant = arrays[Mesh.ARRAY_INDEX]
				var idx: PackedInt32Array = raw if raw != null else PackedInt32Array()
				var count: int = idx.size() if not idx.is_empty() else verts.size()
				for i: int in range(0, count - 2, 3):
					var a: Vector3 = xf * verts[idx[i] if not idx.is_empty() else i]
					var b: Vector3 = xf * verts[idx[i + 1] if not idx.is_empty() else i + 1]
					var c: Vector3 = xf * verts[idx[i + 2] if not idx.is_empty() else i + 2]
					if absf(a.y - top) > 0.008 or absf(b.y - top) > 0.008 or absf(c.y - top) > 0.008:
						continue
					var tri := PackedVector2Array([Vector2(a.x, -a.z), Vector2(b.x, -b.z), Vector2(c.x, -c.z)])
					var lo: float = minf(tri[0].y, minf(tri[1].y, tri[2].y))
					var hi: float = maxf(tri[0].y, maxf(tri[1].y, tri[2].y))
					if hi < d0 or lo > d1 or absf((tri[1] - tri[0]).cross(tri[2] - tri[0])) < 0.000001:
						continue
					for bin: int in range(int(floorf(lo)), int(floorf(hi)) + 1):
						if not bins.has(bin):
							bins[bin] = []
						(bins[bin] as Array).append(tri)
	return bins


## True if point Vector2(x, d) is on a triangle in `bins`.
static func _covered(bins: Dictionary, x: float, d: float) -> bool:
	var v := Vector2(x, d)
	for tri: PackedVector2Array in bins.get(int(floorf(d)), []):
		if Geometry2D.point_is_inside_triangle(v, tri[0], tri[1], tri[2]):
			return true
	return false


## How far point `v` is from the polyline `pts`.
static func _edge_distance(pts: PackedVector2Array, v: Vector2) -> float:
	var best: float = INF
	for i: int in pts.size() - 1:
		best = minf(best, Geometry2D.get_closest_point_to_segment(v, pts[i], pts[i + 1]).distance_to(v))
	return best


# --- The warning ----------------------------------------------------------------------------------------------

## The warning in the real fight (see the header), the bot playing it: phase 1's bites on roofs 1 and 2 at 3, 5 and 6
## lanes, phase 2's full-width one on roof 4 at 3 and 6.
func _test_warning() -> void:
	for run: Array in [[3, 23.8, 0, 2], [5, 18.0, 0, 2], [6, 23.8, 0, 2], [6, 18.0, 1, 4], [3, 23.8, 1, 4]]:
		await _warning(int(run[0]), float(run[1]), int(run[2]), int(run[3]))


func _warning(lanes: int, speed: float, phase: int, last: int) -> void:
	var tag: String = "(%d lanes, %.1f m/s, phase %d)" % [lanes, speed, phase + 1]
	var pair: Array = _fight(lanes, speed, phase)
	var world: RunWorld = pair[0]
	var boss: MechaGuppy = pair[1]
	var p: Player = world.player
	var bot := MechaGuppyBot.new(boss)
	bot.reaction = REACTION
	var cause: Array[String] = [""]
	p.died.connect(func(c: String) -> void: cause[0] = c)
	var st: Dictionary = {"frames": 0, "shown": 0, "red": true, "fog": true, "tokens": true, "token_why": "", "snout": 0,
		"watch_out": true, "jaws_clear": true, "jaw_why": "", "watched": 0}
	await _run(world, 90.0, func() -> bool:
		var b: MechaGuppyCrescent = _bite_on(boss, last)
		return b != null and p.distance > b.to + 5.0, func() -> void:
		bot.step()
		_watch(world, boss, st))
	var warnings: Array[Dictionary] = _events(boss, &"floor_bite_warning")
	var snaps: Array[Dictionary] = _events(boss, &"floor_bite_snap")
	var bites: int = 0
	for k: int in range(1, last + 1):
		bites += 1 if MechaGuppyClimb.bitten(k) else 0
	check(p.alive and warnings.size() == bites and snaps.size() == bites and _events(boss, &"floor_bite_skipped").is_empty(),
		"every floor bite up to roof %d warned and snapped (%d of %d), the runner reading them and living %s%s"
		% [last, snaps.size(), bites, tag, "" if p.alive else ": " + cause[0]])
	check(int(st["frames"]) > 30 and int(st["shown"]) == int(st["frames"]) and bool(st["red"]) and bool(st["fog"]),
		"its warning: the crescent's outline and fill on the floor from the moment it shows until the snap (%d of %d frames), in the enemy attacks' red, glowing (unshaded), unfogged %s"
		% [int(st["shown"]), int(st["frames"]), tag])
	check(bool(st["tokens"]), "a floor warning on every lane it takes, none on the lane it leaves %s%s"
		% [tag, "" if String(st["token_why"]) == "" else ": " + String(st["token_why"])])
	# The sounds: the rumble as it rises (logged with it), the crunch as its jaws snap, before the chunk goes.
	var heard: bool = true
	var deadline_ok: bool = true
	for w: Dictionary in warnings:
		var k: int = int(w["roof"])
		var into: MechaGuppyClimb.Step = boss.climb.steps[k - 1]
		deadline_ok = deadline_ok and float(w["d0"]) >= into.deadline - p.speed * FRAME - 0.01
		var rumble: bool = false
		var crunch: bool = false
		var rose: int = -1
		var snapped_t: float = INF
		for e: Dictionary in _events(boss, &"floor_bite_snap"):
			if int(e["roof"]) == k:
				snapped_t = float(e["t"])
		for i: int in boss.events.size():
			var e: Dictionary = boss.events[i]
			if e["event"] == &"floor_bite_rise" and int(e["roof"]) == k:
				rose = i
				var next: Dictionary = boss.events[i + 1] if i + 1 < boss.events.size() else {}
				rumble = not next.is_empty() and next["event"] == &"sound" and next["name"] == &"guppy_rumble"
			elif rose >= 0 and e["event"] == &"sound" and e["name"] == &"guppy_bite" and float(e["t"]) <= snapped_t \
					and float(e["t"]) >= snapped_t - boss.tuning.bite_snap - 3.0 * FRAME:
				crunch = true
		heard = heard and rumble and crunch
	check(heard and not warnings.is_empty(), "the rumble as Mecha Guppy rises for each, the crunch (guppy_bite) as its jaws snap %s" % tag)
	check(deadline_ok and not warnings.is_empty(), "never before the hut's deadline that led onto its roof (no cue to the lanes that lead up) %s" % tag)
	check(int(st["snout"]) == bites and bool(st["watch_out"]),
		"Mecha Guppy's snout towers beside the roof's side on the bite's side as it warns (%d of %d), its jaws off the track %s"
		% [int(st["snout"]), bites, tag])
	check(bool(st["jaws_clear"]) and int(st["watched"]) > 0, "its jaws never over the lane it leaves (%d frames) %s%s"
		% [int(st["watched"]), tag, "" if String(st["jaw_why"]) == "" else ": " + String(st["jaw_why"])])
	await sim.free_world(world)


## One frame of the warning's checks (_warning) into `st`.
func _watch(world: RunWorld, boss: MechaGuppy, st: Dictionary) -> void:
	var fb: MechaGuppyFloorBite = boss.floor_bite
	if fb.warning():
		var bite: MechaGuppyCrescent = fb.bite
		var top: float = boss.climb.roofs[bite.roof].top
		st["frames"] = int(st["frames"]) + 1
		var outline := fb.get_node("Outline") as MeshInstance3D
		var fill := fb.get_node("Fill") as MeshInstance3D
		var outline_mesh := outline.mesh as ArrayMesh
		var fill_mesh := fill.mesh as ArrayMesh
		if outline.visible and fill.visible and outline_mesh != null and outline_mesh.get_surface_count() > 0 \
				and fill_mesh != null and fill_mesh.get_surface_count() > 0:
			st["shown"] = int(st["shown"]) + 1
		for mi: MeshInstance3D in [outline, fill]:
			var m := mi.material_override as BaseMaterial3D
			var c: Color = m.albedo_color
			var red: Color = BossProps.WARNING_COLOR
			if absf(c.r - red.r) > 0.02 or absf(c.g - red.g) > 0.02 or absf(c.b - red.b) > 0.02 \
					or m.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED:
				st["red"] = false
			if not m.disable_fog:
				st["fog"] = false
		for lane: int in world.geo.lane_count:
			var s: Vector2 = bite.lane_stretch(lane)
			var takes: bool = s.x <= s.y
			if takes != boss.props.warned(lane, bite.from, bite.to, top):
				st["tokens"] = false
				if String(st["token_why"]) == "":
					st["token_why"] = "roof %d, lane %d: %s" % [bite.roof, lane, "taken, unwarned" if takes else "left, warned"]
	var shark: MechaGuppyShark = boss.shark
	if shark.action.is_empty() or int(shark.action["kind"]) != MechaGuppyShark.Kind.FLOOR:
		return
	var b: MechaGuppyCrescent = shark.action["bite"]
	var deck: float = float(shark.action["top"])
	var wall: float = world.geo.wall_x()
	var jaws: PackedVector3Array = shark.jaws_points()
	if shark.stage == MechaGuppyShark.Stage.WAITING:
		var body: PackedVector3Array = shark.body_points()
		if not body.is_empty() and float(b.side) * body[0].x > wall and body[0].y > deck + 1.0 and not st.has("snout_%d" % b.roof):
			st["snout_%d" % b.roof] = true
			st["snout"] = int(st["snout"]) + 1
		for pt: Vector3 in jaws:
			if b.w_of(pt.x) > 0.0 and pt.y > deck - 0.5:
				st["watch_out"] = false
	st["watched"] = int(st["watched"]) + 1
	var reach: float = minf(b.deepest(), b.width()) + 0.05
	for pt: Vector3 in jaws:
		if pt.y > deck - 0.6 and b.w_of(pt.x) > reach:
			st["jaws_clear"] = false
			if String(st["jaw_why"]) == "":
				st["jaw_why"] = "roof %d, stage %d: a point %.2f m in from the bitten side (the bite reaches %.2f m), %.2f m over the deck" \
					% [b.roof, shark.stage, b.w_of(pt.x), reach - 0.05, pt.y - deck]


## The outline's frame, steady with Reduced flashing (it only deepens as the snap comes), beating otherwise.
func _test_reduced_flashing() -> void:
	var was: bool = Settings.flashing_reduced
	for reduced: bool in [false, true]:
		Settings.flashing_reduced = reduced
		var pair: Array = _fight(5, 18.0)
		var world: RunWorld = pair[0]
		var boss: MechaGuppy = pair[1]
		var bot := MechaGuppyBot.new(boss)
		bot.reaction = REACTION
		var widths: Array[float] = []
		await _run(world, 40.0, func() -> bool: return boss.floor_bite.snaps >= 1, func() -> void:
			bot.step()
			if boss.floor_bite.warning():
				widths.append(boss.floor_bite.frame_width))
		var dips: int = 0
		for i: int in range(1, widths.size()):
			if widths[i] < widths[i - 1] - 0.0005:
				dips += 1
		if reduced:
			check(widths.size() > 10 and dips == 0 and widths[-1] > widths[0],
				"with Reduced flashing the floor bite's outline holds steady, only deepening (%d dips in %d frames)" % [dips, widths.size()])
		else:
			check(dips > 0, "it beats otherwise (%d dips in %d frames)" % [dips, widths.size()])
		await sim.free_world(world)
	Settings.flashing_reduced = was


# --- The margins on real movement -------------------------------------------------------------------------------

## The worst case (see the header) at 3, 5 and 6 lanes, both speeds: phase 1's bites on roofs 1 and 2, phase 2's on roofs
## 1, 2 and the full-width one on roof 4.
func _test_margins() -> void:
	for speed: float in SPEEDS:
		for lanes: int in LANES:
			for phase: int in 2:
				await _margins(lanes, speed, phase)


func _margins(lanes: int, speed: float, phase: int) -> void:
	var tag: String = "(%d lanes, %.1f m/s, phase %d)" % [lanes, speed, phase + 1]
	var last: int = 2 if phase == 0 else 4
	var pair: Array = _fight(lanes, speed, phase)
	var world: RunWorld = pair[0]
	var boss: MechaGuppy = pair[1]
	var p: Player = world.player
	var mt: MechaGuppyTuning = boss.tuning
	var bot := MechaGuppyBot.new(boss)
	bot.reaction = REACTION
	var cause: Array[String] = [""]
	p.died.connect(func(c: String) -> void: cause[0] = c)
	var hurt: Array[int] = [0]
	p.item_used.connect(func(_item: StringName) -> void: hurt[0] += 1)
	var shifted: Dictionary = {}
	await _run(world, 90.0, func() -> bool:
		var b: MechaGuppyCrescent = _bite_on(boss, last)
		return b != null and p.distance > b.to + 5.0, func() -> void:
		# Where the riders onto a bitten roof can first switch: into its bitten side's outer lane.
		for k: int in range(1, mini(last, boss.climb.roofs.size() - 1) + 1):
			var b: MechaGuppyCrescent = _bite_on(boss, k)
			if b == null or shifted.has(k) or k >= boss.climb.steps.size() + 1:
				continue
			var into: MechaGuppyClimb.Step = boss.climb.steps[k - 1]
			if p.distance >= into.free_at and p.distance < b.from and p.surface == Player.Surface.FLOOR:
				shifted[k] = p.distance
				_shift(world, _bitten_outer(b))
				# A runner arriving there afresh: no press pending (a switch it began in the lanes that lead up is undone),
				# heading for the lane the bite leaves only if it has read the warning already.
				bot.set(&"_next_press", 0.0)
				if int(bot.get(&"_target")) != b.keep:
					bot.set(&"_target", -1)
		bot.step())
	var v: float = maxf(p.speed, 1.0)
	var h: float = world.tuning.hurtbox_size.z * 0.5
	var switch: float = world.tuning.lane_switch_time
	# The bot presses each switch a frame after the last has finished, at the frame's grain: it gives this much away a switch.
	var cadence: float = ceilf((switch + FRAME) / FRAME - 0.001) * FRAME - switch
	var least_spare: float = INF
	var least_slack: float = INF
	var jump_margin: float = INF
	var run_up: float = INF
	var passed: bool = true
	var met: int = 0
	var why: String = ""
	for w: Dictionary in _events(boss, &"floor_bite_warning"):
		var k: int = int(w["roof"])
		var b: MechaGuppyCrescent = boss.climb.roofs[k].bite
		var into: MechaGuppyClimb.Step = boss.climb.steps[k - 1]
		var d0: float = float(w["d0"])
		met += 1
		var record: Dictionary = {}
		for r: Dictionary in bot.bites:
			if int(r["roof"]) == k:
				record = r
		if not shifted.has(k) or record.is_empty():
			passed = false
			why = "roof %d: %s" % [k, "never moved across" if not shifted.has(k) else "never read"]
			continue
		if b.full:
			# A reaction before the earliest take-off over its longest stretch, and a jump clearing it at both ends.
			var air: float = boss.climb.jump_seconds() * v
			for lane: int in lanes:
				var s: Vector2 = b.stretch(b.near_w(lane))
				if s.x <= s.y:
					run_up = minf(run_up, (s.y - air - (d0 + mt.dodge_reaction * v)) / v)
			jump_margin = minf(jump_margin, float(record["margin"]))
			if not bool(record["jumped"]) or float(record["margin"]) < 0.02:
				passed = false
				why = "roof %d: %s" % [k, "no jump" if not bool(record["jumped"]) else "a jump clearing it by %.3f s" % float(record["margin"])]
		else:
			var spare: float = (b.from - maxf(d0 + mt.dodge_reaction * v, into.free_at) - h) / v - float(lanes - 1) * switch
			least_spare = minf(least_spare, spare)
			least_slack = minf(least_slack, float(record["slack"]))
			if int(record["lane"]) != b.keep or spare < mt.dodge_margin - FRAME - 0.005 \
					or float(record["slack"]) < mt.dodge_margin - float(lanes - 2) * cadence - 2.0 * FRAME:
				passed = false
				why = "roof %d: passed in lane %d (it leaves %d), %.3f s to spare from its warning, %.3f s at the last switch" \
					% [k, int(record["lane"]), b.keep, spare, float(record["slack"])]
	var want: int = 0
	for k: int in range(1, last + 1):
		want += 1 if MechaGuppyClimb.bitten(k) else 0
	check(p.alive and hurt[0] == 0 and met == want and passed,
		"the worst case on real movement: moved into the bitten side's outer lane where it can first switch, the runner reads each floor bite dodge_reaction late and crosses into the lane it leaves with dodge_margin (%.2f s) to spare, or jumps a full-width one (%d bites; least %.3f s to spare from its warning, %.3f s after the last switch's press%s) %s%s"
		% [mt.dodge_margin, met, least_spare, least_slack,
			"" if jump_margin == INF else "; the jump clearing it by %.3f s, its earliest take-off %.3f s after a reaction to its warning" % [jump_margin, run_up],
			tag, "" if p.alive and why == "" else ": " + (cause[0] if not p.alive else why)])
	if phase == 1:
		check(run_up >= 0.0 and jump_margin < INF,
			"a full-width bite's warning gives a reaction before its earliest take-off in every lane (%.3f s after it) %s" % [run_up, tag])
	print("  Mecha Guppy's floor bites, the worst case %s: %d bites; least %.3f s to spare from the warning after a reaction and every switch from the farthest lane, %.3f s after the bot's last switch's press%s"
		% [tag, met, least_spare, least_slack,
			"" if jump_margin == INF else "; the full-width jump clearing it by %.3f s at either end, its earliest take-off %.3f s after a reaction" % [jump_margin, run_up]])
	await sim.free_world(world)


# --- The snap on real contact ------------------------------------------------------------------------------------

## A runner in the bite's area as it snaps (moved there as its jaws begin to shut: the bitten side's outer lane at its
## middle), at 5 lanes and 18 m/s: without protection, death by Mecha Guppy's bite; the armor and the shield block it, a
## dash passes through it, each holding the floor under them, and they run on past the hole; beside it in the lane it
## leaves, untouched.
func _test_snap() -> void:
	for setup: String in ["none", "armor", "shield", "dash", "beside"]:
		var loadout := Loadout.new()
		match setup:
			"armor":
				loadout.armor = true
			"shield":
				loadout.charges[&"shield"] = 1
			"dash":
				loadout.tiers[&"dash"] = 1
		var pair: Array = _fight(5, 18.0, 0, loadout)
		var world: RunWorld = pair[0]
		var boss: MechaGuppy = pair[1]
		var p: Player = world.player
		var bot := MechaGuppyBot.new(boss)
		bot.reaction = REACTION
		var cause: Array[String] = [""]
		p.died.connect(func(c: String) -> void: cause[0] = c)
		var st: Dictionary = {"moved": false, "bite": null, "dashed": false, "fell": false}
		await _run(world, 60.0, func() -> bool:
			var b: MechaGuppyCrescent = st["bite"]
			return b != null and p.distance > b.to + 4.0, func() -> void:
			if not bool(st["moved"]):
				bot.step()
			var shark: MechaGuppyShark = boss.shark
			if bool(st["moved"]) or shark.stage != MechaGuppyShark.Stage.SNAPPING or shark.action.is_empty() \
					or int(shark.action["kind"]) != MechaGuppyShark.Kind.FLOOR:
				if bool(st["moved"]) and p.position.y < boss.climb.roofs[(st["bite"] as MechaGuppyCrescent).roof].top - 0.3:
					st["fell"] = true
				return
			var bite: MechaGuppyCrescent = shark.action["bite"]
			var top: float = float(shark.action["top"])
			st["bite"] = bite
			st["moved"] = true
			p.distance = (bite.from + bite.to) * 0.5 - p.speed * maxf(boss.tuning.bite_snap - shark.stage_time, 0.0)
			_shift(world, bite.keep if setup == "beside" else _bitten_outer(bite))
			p.surface = Player.Surface.FLOOR
			p.floor_y = top
			p.h = top
			p.vh = 0.0
			p.grounded = true
			if setup == "dash":
				st["dashed"] = (world.powerups as PowerupController).dash.trigger())
		var snaps: Array[Dictionary] = _events(boss, &"floor_bite_snap")
		var holds: Array[Dictionary] = _events(boss, &"floor_bite_hold")
		var snap: Dictionary = snaps[0] if not snaps.is_empty() else {}
		var caught: bool = not snap.is_empty() and bool(snap["caught"])
		var outcome: int = int(snap.get("outcome", -1))
		var ran_on: bool = p.alive and not bool(st["fell"]) and st["bite"] != null \
			and p.distance > (st["bite"] as MechaGuppyCrescent).to + 4.0
		match setup:
			"none":
				check(not p.alive and caught and outcome == DamageRules.Outcome.KILL and cause[0] == MechaGuppyFloorBite.BITE_NAME
					and holds.is_empty(), "a runner in the bite's area as it snaps, unprotected, dies of it (%s)" % cause[0])
			"armor", "shield":
				var want: int = DamageRules.Outcome.BLOCKED_ARMOR if setup == "armor" else DamageRules.Outcome.BLOCKED_SHIELD
				check(caught and outcome == want and holds.size() == 1 and ran_on,
					"the %s blocks the snap, the floor under the runner holds (%s), and they run on past the hole (%s)"
					% [setup, holds, cause[0]])
			"dash":
				check(bool(st["dashed"]) and caught and outcome == DamageRules.Outcome.IGNORE and holds.size() == 1
					and bool(holds[0]["dashing"]) and ran_on,
					"a dash passes through the snap and gets the same hold (%s, %s)" % [holds, cause[0]])
			"beside":
				check(not caught and holds.is_empty() and ran_on and p.lane == (st["bite"] as MechaGuppyCrescent).keep,
					"a runner beside it, in the lane it leaves, is untouched by the snap and runs on (%s)" % cause[0])
		await sim.free_world(world)


# --- A fall into the gap ------------------------------------------------------------------------------------------

## A runner who runs into a bite's gap (moved into its bitten side's outer lane where they can first switch, then running
## on in it) falls; the grapple's save and a revive pull them up onto the roof, past the gap or into a lane it leaves, and
## they run on; no hit for that step (MechaGuppyPattern.fell_on). Phase 1's bites (roof 1 at 3 lanes, roof 2 at 6) and
## phase 2's full-width ones (roof 4, 3 and 6 lanes).
func _test_falls() -> void:
	for run: Array in [[3, 23.8, 0, 1], [6, 18.0, 0, 2], [3, 18.0, 1, 4], [6, 23.8, 1, 4]]:
		for mode: String in ["grapple", "revive"]:
			await _fall(int(run[0]), float(run[1]), int(run[2]), int(run[3]), mode)


func _fall(lanes: int, speed: float, phase: int, k: int, mode: String) -> void:
	var tag: String = "(%d lanes, %.1f m/s, phase %d, roof %d, %s)" % [lanes, speed, phase + 1, k, mode]
	var pair: Array = _fight(lanes, speed, phase)
	var world: RunWorld = pair[0]
	var boss: MechaGuppy = pair[1]
	var p: Player = world.player
	p.grapples = 1 if mode == "grapple" else 0
	var bot := MechaGuppyBot.new(boss)
	bot.reaction = REACTION
	var st: Dictionary = {"shifted": false, "cause": "", "died_at": NAN, "step": -1}
	p.died.connect(func(c: String) -> void:
		st["cause"] = c
		st["died_at"] = p.distance)
	var used: Array[StringName] = []
	p.item_used.connect(func(item: StringName) -> void: used.append(item))
	# The bot up to where roof k's riders can first switch; from there the runner runs on in the bitten side's outer lane.
	await _run(world, 90.0, func() -> bool: return bool(st["shifted"]), func() -> void:
		var b: MechaGuppyCrescent = _bite_on(boss, k)
		if b != null and boss.climb.steps.size() >= k and p.distance >= boss.climb.steps[k - 1].free_at \
				and p.surface == Player.Surface.FLOOR:
			st["shifted"] = true
			st["step"] = boss.climb.step_index_at(p.distance)
			_shift(world, _bitten_outer(b))
			return
		bot.step())
	var bite: MechaGuppyCrescent = _bite_on(boss, k)
	if not bool(st["shifted"]) or bite == null:
		check(false, "the runner reaches roof %d's bite %s%s" % [k, tag, "" if p.alive else ": " + String(st["cause"])])
		await sim.free_world(world)
		return
	var roof: MechaGuppyClimb.Roof = boss.climb.roofs[k]
	# Into the gap: a fall (saved by the grapple; or dead, then revived).
	await _run(world, 6.0, func() -> bool: return used.has(&"grapple") or boss.pattern.fell_on(int(st["step"])))
	if mode == "revive":
		await _run(world, 4.0, func() -> bool: return false)
		check(not p.alive and st["cause"] == "fell" and float(st["died_at"]) > bite.from,
			"running on into the gap is a fall: death (%s at %.1f m; the gap %.1f-%.1f m) %s"
			% [st["cause"], st["died_at"], bite.from, bite.to, tag])
		p.revive()
	# Pulled up onto the roof: where it lands.
	var landed: Dictionary = {}
	await _run(world, 4.0, func() -> bool: return not landed.is_empty(), func() -> void:
		if p.alive and p.grounded and p.surface == Player.Surface.FLOOR and p.vh <= 0.0 and absf(p.floor_y - roof.top) < 0.01 \
				and (used.has(&"grapple") or mode == "revive"):
			landed["lane"] = p.lane
			landed["d"] = p.distance)
	var saves: Array[Dictionary] = _events(boss, &"save")
	var where_ok: bool = not landed.is_empty() and roof.covers(int(landed["lane"]), float(landed["d"])) \
		and (float(landed["d"]) >= bite.to or (not bite.full and int(landed["lane"]) == bite.keep) \
			or not bite.in_gap(world.geo.lane_x(int(landed["lane"])), float(landed["d"])))
	check(saves.size() == 1 and (mode != "grapple" or used.has(&"grapple")) and boss.pattern.fell_on(int(st["step"])) and where_ok,
		"%s pulls the runner up onto the roof, on its floor (lane %s at %s m; the gap %.1f-%.1f m, %s), no hit for that step %s"
		% ["the grapple's save" if mode == "grapple" else "a revive", landed.get("lane", "-"),
			"%.1f" % float(landed["d"]) if not landed.is_empty() else "-", bite.from, bite.to,
			"full width" if bite.full else "it leaves lane %d" % bite.keep, tag])
	await _run(world, 3.0, func() -> bool: return p.distance > bite.to + 5.0)
	check(p.alive and p.distance > bite.to + 5.0 and absf(p.floor_y - roof.top) < 0.01,
		"and they run on past the bite %s" % tag)
	await sim.free_world(world)


# --- A retry -----------------------------------------------------------------------------------------------------

## The same fight twice (3 lanes, 23.8 m/s, and 6 lanes, 18 m/s, phase 2): the same floor bites, warned and snapped at the
## same moments.
func _test_retry() -> void:
	for run: Array in [[3, 23.8, 0, 2], [6, 18.0, 1, 4]]:
		var logs: Array[String] = []
		for attempt: int in 2:
			var pair: Array = _fight(int(run[0]), float(run[1]), int(run[2]))
			var world: RunWorld = pair[0]
			var boss: MechaGuppy = pair[1]
			var p: Player = world.player
			var bot := MechaGuppyBot.new(boss)
			bot.reaction = REACTION
			var last: int = int(run[3])
			await _run(world, 90.0, func() -> bool:
				var b: MechaGuppyCrescent = _bite_on(boss, last)
				return b != null and p.distance > b.to + 5.0, bot.step)
			var lines: PackedStringArray = []
			for e: Dictionary in boss.events:
				if e["event"] in [&"floor_bite_rise", &"floor_bite_warning", &"floor_bite_snap"]:
					lines.append("%s %.3f %s %s %s %s" % [e["event"], float(e["t"]), e.get("roof", ""), e.get("side", ""),
						e.get("keep", ""), e.get("lane", "")])
			logs.append("\n".join(lines))
			await sim.free_world(world)
		check(logs[0] == logs[1] and logs[0] != "",
			"a retry plays the same floor bites at the same moments (%d lanes, %.1f m/s, phase %d)" % [int(run[0]), float(run[1]), int(run[2]) + 1])

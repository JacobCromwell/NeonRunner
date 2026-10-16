extends TestSuite
## The sea at the bottom of the holes Mecha Guppy bites out of phase 3's top (the owner, October 2026: "When the shark
## bites the roof in the beach boss battle, there is an open space in the THIRD phase. That open space should have blue
## water at the bottom. The shark bite in phase one and phase two still works great"; task J3; MechaGuppyBiteWater), on
## real physics with MechaGuppyBot playing, the attacks on:
## - phases 1 and 2 as they were: through their steps, with the roofs' ends bitten and the floor bites (phase 2's
##   full-width one too), no water shows at any frame;
## - phase 3 (a resume there, as --phase=3 plays it: the climb's last step, then the top; task E5e-g's phase 3): none
##   before the top, nor under a bite of the top before it snaps; from each one's snap until the runner is past it (one
##   leaving a lane, then one across every lane), its hole has the sea at the bottom: a sheet showing at the surface of
##   the water beside the top (MechaGuppyTop.water_y, just under it), under every point of its gap, on past its ends by
##   MechaGuppyBiteWater.ENDS (under the eave's open ends: task J3's review) and out through the bitten side (both sides
##   across a full-width one) under that water, where rays find no floor down to it, and the run camera sees it (a point
##   of the gap at the water's surface in its frustum, nothing solid in the way);
## - look only: nothing in it collides, and the runner plays phase 3 through untouched.

const BOSS_PATH: String = "res://data/bosses/beach_boss.tres"
## A player's reaction (the suites' bots' usual 0.35 s).
const REACTION: float = 0.35
## The top's bites watched in each phase 3 run (the first leaves a lane, the second crosses every lane).
const BITES: int = 2
## The least the run camera sees a hole's water from its snap until the runner is past it (seconds).
const SEEN_LEAST: float = 0.3

var sim: RunSim
var def: BossDef


func run() -> void:
	sim = RunSim.new(tree, tuning)
	var slot := load(BOSS_PATH) as BossDef
	def = slot if slot != null and slot.is_built() else null
	if def == null:
		check(false, "Mecha Guppy and Captain Cogs' fight loads")
		return
	await _test_before_phase_3(5, 23.8, 0, 3)
	await _test_before_phase_3(3, 18.0, 1, 5)
	await _test_phase_3(3, 23.8)
	await _test_phase_3(6, 18.0)


# --- Helpers -------------------------------------------------------------------------------

func _movement(speed: float) -> MovementTuning:
	if is_equal_approx(speed, tuning.run_speed):
		return tuning
	var t: MovementTuning = tuning.duplicate() as MovementTuning
	t.run_speed = speed
	return t


## The fight at `lanes` and `speed` m/s from phase index `phase` (a resume), its attacks on: [world, boss].
func _fight(lanes: int, speed: float, phase: int) -> Array:
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
	var world: RunWorld = sim.build_world(arena.layout, null, t, ctx.config)
	boss.setup(world, ctx, arena)
	return [world, boss]


func _events(boss: BossEncounter, event: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in boss.events:
		if e["event"] == event:
			out.append(e)
	return out


## Steps the world (a physics frame and a rendered one each time) until `done` holds, the runner dies or `seconds` pass,
## calling `each` after every frame.
func _run(world: RunWorld, seconds: float, done: Callable, each: Callable = Callable()) -> void:
	if not world.player.running:
		await tree.physics_frame
		world.player.running = true
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		if done.call() or not world.player.alive:
			return
		await tree.physics_frame
		await tree.process_frame
		if each.is_valid():
			each.call()


## How many of the water's sheets are showing.
func _sheets_shown(water: MechaGuppyBiteWater) -> int:
	var n: int = 0
	for child: Node in water.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).visible:
			n += 1
	return n


## True if anything solid (a roof's tower, a hut) lies between `from` and `to`.
func _blocked(world: RunWorld, from: Vector3, to: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to, TrackBuilder.LAYER_FLOOR | TrackBuilder.LAYER_HULL)
	q.collide_with_areas = false
	return not space.intersect_ray(q).is_empty()


## True if a ray down from `high` to `low` at (x, d) meets the floor.
func _floor_between(world: RunWorld, x: float, d: float, high: float, low: float) -> bool:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var z: float = TrackGeometry.world_z(d)
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, high, z), Vector3(x, low, z), TrackBuilder.LAYER_FLOOR)
	q.collide_with_areas = false
	return not space.intersect_ray(q).is_empty()


## True if nothing under `node` collides.
func _collision_free(node: Node) -> bool:
	for child: Node in node.get_children():
		if child is CollisionObject3D or child is CollisionShape3D or not _collision_free(child):
			return false
	return true


## Points in bite `b`'s gap (world x, track distance): across the deck, a few along its span.
func _gap_points(world: RunWorld, b: MechaGuppyCrescent) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var wall: float = world.geo.wall_x()
	for i: int in 9:
		var d: float = lerpf(b.from, b.to, (float(i) + 0.5) / 9.0)
		for j: int in 11:
			var x: float = lerpf(-wall, wall, (float(j) + 0.5) / 11.0)
			if b.in_gap(x, d):
				out.append(Vector2(x, d))
	return out


# --- Phases 1 and 2 ------------------------------------------------------------------------

## Phase `phase` + 1 from its start for `steps` steps: its bites as always, and never any water.
func _test_before_phase_3(lanes: int, speed: float, phase: int, steps: int) -> void:
	var tag: String = "(%d lanes, %.1f m/s, phase %d)" % [lanes, speed, phase + 1]
	var pair: Array = _fight(lanes, speed, phase)
	var world: RunWorld = pair[0]
	var boss: MechaGuppy = pair[1]
	var water: MechaGuppyBiteWater = boss.bite_water
	var bot := MechaGuppyBot.new(boss)
	bot.reaction = REACTION
	# (No baiting: the fallback's hits come every other step, so the phase never ends in these steps.)
	bot.baits = false
	var st: Dictionary = {"frames": 0, "wet": 0}
	await _run(world, 90.0, func() -> bool: return bot.steps_climbed >= steps, func() -> void:
		bot.step()
		st["frames"] = int(st["frames"]) + 1
		water.update()
		if not water.holes.is_empty() or _sheets_shown(water) > 0:
			st["wet"] = int(st["wet"]) + 1)
	var ends: int = _events(boss, &"roof_eaten").size()
	var floors: Array[Dictionary] = _events(boss, &"floor_bite_snap")
	var full: int = 0
	for e: Dictionary in floors:
		full += 1 if bool(e.get("full", false)) else 0
	check(world.player.alive and bot.steps_climbed >= steps and boss.phase_index == phase and ends >= steps
		and floors.size() >= 1 and (phase == 0 or full >= 1),
		"the climb bites as always: %d steps, %d roofs' ends eaten, %d floor bites (%d full width) %s" % [bot.steps_climbed,
		ends, floors.size(), full, tag])
	check(int(st["wet"]) == 0, "phases 1 and 2 as they were: no water at the bottom of any bite (%d of %d frames) %s"
		% [int(st["wet"]), int(st["frames"]), tag])
	await sim.free_world(world)


# --- Phase 3 -------------------------------------------------------------------------------

## Phase 3 at `lanes` and `speed` m/s, from its resume (the climb's last step, then the top), MechaGuppyBot playing it until
## BITES of the top's bites have snapped and the runner is past the last: no water before each one's snap, and from it
## until the runner is past, the sea at the bottom of its hole, seen by the run camera.
func _test_phase_3(lanes: int, speed: float) -> void:
	var tag: String = "(%d lanes, %.1f m/s)" % [lanes, speed]
	var pair: Array = _fight(lanes, speed, 2)
	var world: RunWorld = pair[0]
	var boss: MechaGuppy = pair[1]
	var p: Player = world.player
	var water: MechaGuppyBiteWater = boss.bite_water
	var camera := RunCamera.new()
	tree.root.add_child(camera)
	camera.follow(world)
	camera.make_current()
	var bot := MechaGuppyBot.new(boss)
	bot.reaction = REACTION
	var hurt: Array[int] = [0]
	p.item_used.connect(func(_item: StringName) -> void: hurt[0] += 1)
	var problems: Array[String] = []
	# early: frames with water before the top or under a bite before its snap; watched: each top bite from its snap until
	# the runner is past it ({bite: {frames, seen, full}}).
	var st: Dictionary = {"early": 0, "watched": {}, "frames": 0}
	var top: MechaGuppyTop = boss.top
	var right: MeshInstance3D = top.get_node("WaterRight") as MeshInstance3D
	var left: MeshInstance3D = top.get_node("WaterLeft") as MeshInstance3D
	var wall: float = world.geo.wall_x()
	var reach: float = wall + MechaGuppyLooks.EAVE_REACH
	await _run(world, 120.0, func() -> bool:
		var watched: Dictionary = st["watched"]
		if watched.size() < BITES:
			return false
		for b: MechaGuppyCrescent in watched:
			if p.distance <= b.to + 2.0:
				return false
		return true, func() -> void:
		bot.step()
		st["frames"] = int(st["frames"]) + 1
		# As it will be drawn this frame (it lays its sheets in _process, after this frame's physics: a bite that snapped in
		# it shows its water as its hole first shows).
		water.update()
		var roof: MechaGuppyClimb.Roof = boss.climb.roofs[-1] if boss.climb.top_planned() else null
		var eaten: Array[MechaGuppyCrescent] = []
		if roof != null:
			for b: MechaGuppyCrescent in roof.top_bites:
				if b.eaten and not b.skipped:
					eaten.append(b)
		# None before the top, and none under a bite that hasn't snapped.
		for h: Dictionary in water.holes:
			if not top.started() or not eaten.has(h["bite"]):
				st["early"] = int(st["early"]) + 1
		if not top.started() and _sheets_shown(water) > 0:
			st["early"] = int(st["early"]) + 1
		for b: MechaGuppyCrescent in eaten:
			if p.distance > b.to + 2.0:
				continue
			if not (st["watched"] as Dictionary).has(b):
				(st["watched"] as Dictionary)[b] = {"frames": 0, "seen": 0, "full": b.full}
			var watch: Dictionary = (st["watched"] as Dictionary)[b]
			watch["frames"] = int(watch["frames"]) + 1
			var why: String = _hole_problem(world, boss, b, right, left, reach)
			if why != "" and problems.size() < 4:
				problems.append(why)
			if _water_seen(world, boss, camera, b):
				watch["seen"] = int(watch["seen"]) + 1)
	var watched: Dictionary = st["watched"]
	var fulls: int = 0
	var seen: Array[String] = []
	var all_seen: bool = true
	var least: int = int(SEEN_LEAST * Engine.physics_ticks_per_second)
	for b: MechaGuppyCrescent in watched:
		var w: Dictionary = watched[b]
		fulls += 1 if bool(w["full"]) else 0
		seen.append("%s: %d of %d frames" % ["full width" if bool(w["full"]) else "leaving a lane", int(w["seen"]),
			int(w["frames"])])
		all_seen = all_seen and int(w["seen"]) >= least
	check(p.alive and hurt[0] == 0 and boss.top.started() and watched.size() >= BITES and fulls >= 1
		and fulls < watched.size(),
		"the runner plays phase 3's top untouched past %d of Mecha Guppy's bites (%d across every lane) %s" % [watched.size(),
		fulls, tag])
	check(int(st["early"]) == 0, "no water before the top, nor under a bite before it snaps (%d frames of %d) %s"
		% [int(st["early"]), int(st["frames"]), tag])
	check(problems.is_empty(),
		"each bitten hole in the top has the sea at its bottom: at the surface of the water beside the top, under every point of its gap, past its ends and out under that water through its bitten side, no floor down to it %s%s"
		% [tag, "" if problems.is_empty() else ": " + "; ".join(problems)])
	check(all_seen, "the run camera sees the water at the bottom of each hole (%s) %s" % [", ".join(seen), tag])
	check(_collision_free(water), "the water is look only: nothing in it collides %s" % tag)
	print("  Mecha Guppy's bite water %s: %s; the top %.1f m up, its water %.2f m under the deck" % [tag, ", ".join(seen),
		p.floor_base, p.floor_base - top.water_y()])
	camera.queue_free()
	await sim.free_world(world)


## What's wrong with the water under bite `b`'s hole in the top, or "": its sheet showing at the surface of the water
## beside the top (`right`, `left`; just under it), under every point of the gap, reaching out past `reach` (where that water
## begins) on the bitten side (both sides across a full-width one); the hole open down to it.
func _hole_problem(world: RunWorld, boss: MechaGuppy, b: MechaGuppyCrescent, right: MeshInstance3D, left: MeshInstance3D,
		reach: float) -> String:
	var water: MechaGuppyBiteWater = boss.bite_water
	var h: Dictionary = {}
	var i: int = -1
	for k: int in water.holes.size():
		if water.holes[k]["bite"] == b:
			h = water.holes[k]
			i = k
	if h.is_empty():
		return "the hole at %.0f m has no water" % b.from
	var sheet := water.get_node_or_null("Sheet%d" % i) as MeshInstance3D
	if sheet == null or not sheet.visible:
		return "the hole at %.0f m: its sheet isn't showing" % b.from
	var y: float = sheet.global_position.y
	var surface: float = boss.top.water_y()
	if not right.visible or not left.visible or absf(right.global_position.y - surface) > 0.001 \
			or y > surface - 0.0005 or y < surface - 0.01:
		return "the hole at %.0f m: its water at %.3f m, the water beside the top at %.3f m (shown %s)" % [b.from, y,
			right.global_position.y, right.visible]
	var size: Vector3 = sheet.global_transform.basis.get_scale()
	var x0: float = sheet.global_position.x - size.x * 0.5
	var x1: float = sheet.global_position.x + size.x * 0.5
	var d0: float = -sheet.global_position.z - size.z * 0.5
	var d1: float = -sheet.global_position.z + size.z * 0.5
	for q: Vector2 in _gap_points(world, b):
		if q.x < x0 - 0.001 or q.x > x1 + 0.001 or q.y < d0 - 0.001 or q.y > d1 + 0.001:
			return "the hole at %.0f m: a point of its gap (x %.1f m, %.1f m) has no water under it" % [b.from, q.x, q.y]
		if _floor_between(world, q.x, q.y, world.player.floor_base + 1.0, y + 0.05):
			return "the hole at %.0f m: floor in its gap at x %.1f m, %.1f m" % [b.from, q.x, q.y]
	var out_right: bool = x1 >= reach
	var out_left: bool = x0 <= -reach
	if (b.side > 0 or b.full) and not out_right or (b.side < 0 or b.full) and not out_left:
		return "the hole at %.0f m: its water stops at x %.1f to %.1f m, short of the water beside the top (from %.1f m out)" % [
			b.from, x0, x1, reach]
	# On past the crescent's ends under the eave (task J3's review: its open ends showed the haze in the gap there).
	if d0 > b.from - MechaGuppyBiteWater.ENDS + 0.001 or d1 < b.to + MechaGuppyBiteWater.ENDS - 0.001:
		return "the hole at %.0f m: its water spans %.1f to %.1f m, the bite %.1f to %.1f m" % [b.from, d0, d1, b.from, b.to]
	return ""


## True if the run camera sees the water at the bottom of bite `b`'s hole this frame: a point of its gap, at the water's
## surface, in its view with nothing solid in the way.
func _water_seen(world: RunWorld, boss: MechaGuppy, camera: RunCamera, b: MechaGuppyCrescent) -> bool:
	var y: float = boss.top.water_y()
	var from: Vector3 = camera.global_position
	for q: Vector2 in _gap_points(world, b):
		var at := Vector3(q.x, y, TrackGeometry.world_z(q.y))
		if camera.is_position_in_frustum(at) and not _blocked(world, from, at):
			return true
	return false

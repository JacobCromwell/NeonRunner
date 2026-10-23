extends TestSuite
## The Cybernetic Centipede (task O3; GDD §9.15, the owner, October 20, 2026: the Terminal's only enemy, haunting the debris
## maze), on its own: its rules, its behaviour on real physics and its look. Where the generator places it, and the proof
## that every placement leaves its block escapable, are test_centipede_maze's. Checked here:
## - its data and declared properties: its tuning (data/enemies/centipede.tres), out of LevelConfig.PLANNED_FEATURES and
##   found by the layout checks; its sounds in the library; on its real hitboxes, immune to weapons (auto-fire never picks
##   it, a shot or a missile's splash does nothing), its head and body harmless (landing on them is no stomp and no
##   bounce, the claws do nothing to them), its live bite a hit the armor takes, claws or not;
## - its look: the model's draw calls and triangles within budget, only its glass, lenses and open jaws glowing, its
##   bite's hitbox within the head and jaws drawn, its head's and body's smaller than drawn; its warm-up look shows every
##   part, and the director readies it with the level;
## - its bite's hitbox through whole strikes (a runner in god mode, stopped at debris, so no contact cuts one short):
##   every frame it's live, it stops short of its mandibles as they're drawn that frame (their meshes, the lunge in
##   them), its top stays under its head drawn, and it follows the lunge out and back;
## - on real physics, in hand-made maze blocks (MazeKit) at 3, 5 and 6 lanes: it waits, still, until the runner on the
##   floor is in its own section or one joined to it within its wake distance (never before the runner is in its block:
##   one near the run-in wakes as they reach the run-in's start, however far its wake distance reaches), then warns (the
##   hiss and the clatter, centipede_wake), rears and keeps still for its wake time; it chases along open floor only (its
##   head never in debris, every step within its chase speed), and catches a runner stopped at debris: its head rears and
##   its jaws open (the telegraph, its sound) for bite_telegraph before every bite, and each contact is one hit: the armor
##   takes it, with the invulnerability window after; with neither armor nor shield it kills; a claw runner (5 lanes) is
##   bitten like anyone and never kills it; it's never a big attack;
## - met head-on in a corridor, the runner dashes through it unharmed and wounds it once (however many of its hitboxes
##   the dash meets): its lenses flared as it woke, and its cracked tube leaks and it sparks (neither the flare nor the
##   sparks with Reduced flashing: 6 lanes); it recoils with its jaws shut, turns and chases from behind, gives up once
##   the runner is out past its block's last wall, and leaves play;
## - a walled-in one sleeps on as the runner passes by its cell and leaves play behind them, and a dash that opens its
##   cell releases it (it wakes, with its warning);
## - the second dash kills it (the player's kill and its score, its death sound);
## - it can't follow onto a ceiling: a runner who takes an anti-grav pad gets away (it gives up, never biting at them).
## - an ambush (task O5) lies hidden in a divider's debris, a sliver showing, until the runner is within its ambush
##   distance or a dash smashes that debris; then the debris shatters and it wakes and chases.

## Lane counts every physics check runs at.
const LANES: Array[int] = [3, 5, 6]
## Metres of slack for float steps.
const EPS: float = 0.01
## The model's budget (CentipedeModel's header: about ten draw calls and 5,000 triangles).
const MAX_DRAW_CALLS: int = 12
const MAX_TRIANGLES: int = 6000
## The runner dashes at a centipede coming at them once it's this close (metres): soon enough that the dash is on before
## its bite goes live.
const DASH_GAP: float = 12.0
## Its sounds (assets/sfx/centipede_*.wav).
const SOUNDS: Array[StringName] = [&"centipede_wake", &"centipede_bite", &"centipede_snap", &"centipede_wound",
	&"centipede_death"]

var sim: RunSim
var t: CentipedeTuning


func run() -> void:
	sim = RunSim.new(tree, tuning)
	t = EnemyDirector.tuning_for("centipede") as CentipedeTuning
	check(t != null, "the centipede's tuning loads (data/enemies/centipede.tres)")
	if t == null:
		return
	_test_data()
	await _test_parts()
	await _test_strike_drawn()
	for lanes: int in LANES:
		await _test_wake_at_run_in(lanes)
		await _test_wake_and_bite(lanes)
		await _test_head_on(lanes)
		await _test_trapped(lanes)
		await _test_ambush(lanes)
	await _test_second_dash()
	await _test_ceiling()


func _test_data() -> void:
	check(not LevelConfig.PLANNED_FEATURES.has("centipede") and LayoutChecks.can_locate("centipede")
		and LayoutChecks.known_feature("centipede"), "`centipede` is built: out of PLANNED_FEATURES, found by the checks")
	check(t.speed_share < 1.0 and t.speed_share > 0.5, "slightly slower than the runner (%.2f of the run speed)" % t.speed_share)
	check(t.dash_hits == 2, "two dashes kill it (GDD §9.15)")
	check(t.bite_width < tuning.lane_width * 0.5, "its bite is narrower than half a lane (%.2f m)" % t.bite_width)
	check(t.bite_height > tuning.jump_height + 0.1,
		"a jump doesn't clear its bite: it rears to snap (%.2f m; the runner's feet at a jump's peak %.2f m)" % [t.bite_height,
			tuning.jump_height])
	var library := load("res://data/audio/sfx_library.tres") as SfxLibrary
	var missing: Array[StringName] = []
	for sound: StringName in SOUNDS:
		if library.stream(sound) == null:
			missing.append(sound)
	check(missing.is_empty(), "its sounds are in the library (missing: %s)" % [missing])


## A centipede in a hand-made block, and the runner coming in from its run-in in `runner_lane` (see the header): `walls`
## and `rooms` as MazeKit.block takes them, the centipede's head at `at_room` metres into room `room` in `lane`.
func _world(lanes: int, walls: Array, rooms: Array, room: int, at_room: float, lane: int, runner_lane: int,
		options: Dictionary = {}, loadout: Loadout = null) -> Dictionary:
	var layout: LevelLayout = MazeKit.block(tuning, lanes, walls, rooms, options)
	var b: Dictionary = layout.maze[0]
	var at: float = float((b["rooms"] as Array)[room]["start"]) + at_room
	layout.enemies.append(MazeKit.centipede(at, lane))
	return _world_of(layout, runner_lane, at, loadout)


## A world over `layout` (one maze block, its centipede at `at`), the runner in `runner_lane` 20 m before the block.
func _world_of(layout: LevelLayout, runner_lane: int, at: float, loadout: Loadout = null) -> Dictionary:
	var b: Dictionary = layout.maze[0]
	var world: RunWorld = sim.build_world(layout, loadout if loadout != null else Loadout.new())
	world.player.setup(world.tuning, world.geo, runner_lane)
	world.player.distance = float(b["entry"]) - 20.0
	return {"world": world, "layout": layout, "block": b, "at": at}


## The first centipede in `world`'s play, or null.
func _centipede(world: RunWorld) -> Centipede:
	for e: Enemy in world.director.active:
		if is_instance_valid(e) and e is Centipede:
			return e as Centipede
	return null


## The centipede `world`'s director spawns from its layout, stepping a few frames for it; null if none comes.
func _spawned(world: RunWorld) -> Centipede:
	for i: int in 10:
		await tree.physics_frame
		var c: Centipede = _centipede(world)
		if c != null:
			return c
	return null


## The centipede the frame loops follow in `world`: found once (then `log["found"]`), kept in `log["c"]`. Returns it, or
## null before it's found and once it's freed.
func _follow(world: RunWorld, log: Dictionary) -> Centipede:
	if not bool(log.get("found", false)):
		var c: Centipede = _centipede(world)
		if c == null:
			return null
		log["found"] = true
		log["c"] = c
	return log["c"] as Centipede if is_instance_valid(log["c"]) else null


## Steps `world` frame by frame for up to `seconds`, calling `each(frame)` after every frame (it may return true to stop).
## Returns the frames run.
func _run(world: RunWorld, seconds: float, each: Callable) -> int:
	if not world.player.running:
		await tree.physics_frame
		world.player.running = true
	var frames: int = int(seconds * Engine.physics_ticks_per_second)
	for f: int in frames:
		await tree.physics_frame
		if bool(each.call(f)):
			return f + 1
	return frames


## True if `node` or anything under it is a physics object.
func _has_physics(node: Node) -> bool:
	if node is CollisionObject3D:
		return true
	for child: Node in node.get_children():
		if _has_physics(child):
			return true
	return false


# --- Its parts --------------------------------------------------------------------------------------

## Its declared properties at work on its real hitboxes, its look, and its warm-up (see the header).
func _test_parts() -> void:
	var w: Dictionary = _world(5, [[2], [], [2]], [[], []], 0, 16.0, 4, 2)
	var world: RunWorld = w["world"]
	var p: Player = world.player
	var c: Centipede = await _spawned(world)
	check(c != null, "it spawns from its layout entry")
	if c == null:
		await sim.free_world(world)
		return
	# Weapons.
	check(not c.targetable() and not world.director.targets_ahead(p.position, 400.0).has(c),
		"auto-fire never targets it (immune to weapons)")
	c.take_damage(50.0, &"shot")
	c.take_damage(50.0, &"missile", true)
	check(c.alive and is_equal_approx(c.health, c.max_health), "a shot or a missile's splash does nothing to it")
	# Its head and body: harmless to a stomp and to the claws (only a dash's contact counts).
	var parts: Array[Hazard] = [c.head_box()]
	parts.append_array(c.body_boxes())
	var vh: float = p.vh
	var ignored: bool = true
	for part: Hazard in parts:
		ignored = ignored and part.harmless and p.receive_hit(part, true) == DamageRules.Outcome.IGNORE \
			and p.receive_hit(part, false) == DamageRules.Outcome.IGNORE
	check(ignored and c.alive and p.alive and is_equal_approx(p.vh, vh) and p.last_event != "stomp",
		"landing on its head or body neither hurts it nor bounces the runner, and touching them is harmless")
	p.claws = true
	var clawed: bool = true
	for part: Hazard in parts:
		clawed = clawed and p.receive_hit(part, false) == DamageRules.Outcome.IGNORE
	check(clawed and c.alive, "the claws do nothing to it (no contact kill)")
	# Its live bite: one hit, the armor's, claws or not.
	p.armor = 1
	c.bite_box().set_enabled(true)
	var outcome: DamageRules.Outcome = p.receive_hit(c.bite_box(), true)
	c.bite_box().set_enabled(false)
	check(outcome == DamageRules.Outcome.BLOCKED_ARMOR and c.alive and p.alive,
		"its live bite is a hit the armor takes, claws or a stomp or not (%s)" % DamageRules.Outcome.keys()[outcome])
	# Its look.
	var m: CentipedeModel = c.model()
	check(m.draw_call_count() <= MAX_DRAW_CALLS and m.triangle_count() <= MAX_TRIANGLES,
		"its model is cheap to draw (%d draw calls, %d triangles)" % [m.draw_call_count(), m.triangle_count()])
	var glowing: Array[String] = []
	var glow_ok: bool = true
	for entry: Dictionary in m.materials():
		var mat: Material = entry["material"]
		if mat is BaseMaterial3D and (mat as BaseMaterial3D).emission_enabled:
			var part: String = String(entry["part"])
			if not glowing.has(part):
				glowing.append(part)
			glow_ok = glow_ok and part in ["glass", "lenses", "maw"]
	check(glow_ok and glowing.has("glass") and glowing.has("lenses") and glowing.has("maw"),
		"only its glass, its lenses and its open jaws glow (%s)" % [glowing])
	check(m.reared_top() >= t.bite_height,
		"its bite's hitbox stays under its reared head drawn (%.2f m; the head's top %.2f m)" % [t.bite_height, m.reared_top()])
	var reach: float = t.bite_reach(CentipedeMaze.HEAD_HALF_LENGTH)
	check(m.jaw_reach() + t.lunge_reach >= reach - EPS,
		"its bite reaches no further than its jaws drawn and their lunge (%.2f m; the jaws %.2f m)" % [reach,
			m.jaw_reach() + t.lunge_reach])
	var shell_top: float = CentipedeModel.SHELL_Y + CentipedeModel.SHELL.y * 0.5
	check(Centipede.BODY_HIT.x < CentipedeModel.SHELL.x and Centipede.BODY_HIT.y + Centipede.BODY_BOX_LIFT < shell_top
		and Centipede.HEAD_HIT.x < CentipedeModel.HEAD_SCALE * 0.86 and t.bite_width < CentipedeModel.HEAD_SCALE * 0.86,
		"its head's, body's and bite's hitboxes are narrower and lower than drawn")
	# Its warm-up look.
	var look: Node = Centipede.warm_up(world, MazeKit.centipede(100.0, 1))
	var crack: Node3D = look.find_child("cracked glass", true, false) as Node3D
	check(look is CentipedeModel and not look.is_inside_tree() and crack != null and crack.visible and not _has_physics(look),
		"its warm-up look shows every part (its wound's too), outside the tree, with no physics object")
	look.free()
	check(world.director.warm_entries().any(func(e: Dictionary) -> bool: return String(e["type"]) == "centipede"),
		"the director readies it with the level")
	p.claws = false
	await sim.free_world(world)


# --- Its bite, as drawn ------------------------------------------------------------------------------

## Its bite's hitbox through whole strikes (see the header): the runner, in god mode, stops at a closed wall in the middle
## lane; the centipede, waiting in an edge lane, comes and bites them again and again.
func _test_strike_drawn() -> void:
	var w: Dictionary = _world(5, [[2], [], [2]], [[], []], 0, 16.0, 4, 2)
	var world: RunWorld = w["world"]
	world.player.god_mode = true
	var log := {"c": null, "frames": 0, "run": 0, "longest": 0, "over": -INF, "top_over": -INF, "near": INF, "far": -INF}
	await _run(world, 8.0, func(_f: int) -> bool:
		var c: Centipede = _follow(world, log)
		if c == null:
			return bool(log.get("found", false))
		if not c.bite_live():
			log["run"] = 0
			return false
		var origin := Vector3(c.head().x, 0.0, TrackGeometry.world_z(c.head().y))
		var forward := Vector3(sin(c.heading()), 0.0, -cos(c.heading()))
		var box: Vector2 = _box_extent(c.bite_box(), origin, forward)
		log["frames"] = int(log["frames"]) + 1
		log["run"] = int(log["run"]) + 1
		log["longest"] = maxi(int(log["longest"]), int(log["run"]))
		log["over"] = maxf(float(log["over"]), box.x - _drawn_jaws(c, origin, forward))
		log["top_over"] = maxf(float(log["top_over"]), box.y - c.model().head_top())
		log["near"] = minf(float(log["near"]), box.x)
		log["far"] = maxf(float(log["far"]), box.x)
		return false)
	var whole: int = int(floor(t.bite_window * Engine.physics_ticks_per_second)) - 1
	check(int(log["longest"]) >= whole, "it bites a runner in god mode through whole strikes (%d live frames, the longest strike %d, a whole one %d)"
		% [log["frames"], log["longest"], whole])
	check(float(log["over"]) < 0.0,
		"its bite's hitbox stays inside its jaws as drawn that frame, through the whole strike (%.3f m past their farthest at the most)"
		% log["over"])
	check(float(log["top_over"]) <= 0.001, "its top stays under its head as drawn (%.3f m over at the most)" % log["top_over"])
	var reach: float = t.bite_reach(CentipedeMaze.HEAD_HALF_LENGTH)
	check(float(log["far"]) - float(log["near"]) >= t.lunge_reach * 0.5 and float(log["far"]) <= reach + 0.001,
		"it follows the lunge out and back (it reaches from %.2f m to %.2f m in front of its head's middle; bite_reach %.2f m)"
		% [log["near"], log["far"], reach])
	print("  its bite through whole strikes: %d live frames, reaching %.2f to %.2f m, %.3f m inside its jaws drawn and %.3f m under its head at the least"
		% [log["frames"], log["near"], log["far"], -float(log["over"]), -float(log["top_over"])])
	await sim.free_world(world)


## How far in front of `origin` (world, on the floor under `c`'s head's middle) its mandibles are drawn now, along
## `forward`: the farthest of their meshes' points.
func _drawn_jaws(c: Centipede, origin: Vector3, forward: Vector3) -> float:
	var best: float = -INF
	for node: Node in c.model().find_children("mandible", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for s: int in mi.mesh.get_surface_count():
			var verts: PackedVector3Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			for v: Vector3 in verts:
				best = maxf(best, (mi.global_transform * v - origin).dot(forward))
	return best


## Hitbox `box`'s corners (world): the farthest of them along `forward` from `origin` (x), and the highest (y).
func _box_extent(box: Hazard, origin: Vector3, forward: Vector3) -> Vector2:
	var shape := box.get_child(0) as CollisionShape3D
	var half: Vector3 = (shape.shape as BoxShape3D).size * 0.5
	var out := Vector2(-INF, -INF)
	for i: int in 8:
		var corner := Vector3(half.x * (1.0 if (i & 1) != 0 else -1.0), half.y * (1.0 if (i & 2) != 0 else -1.0),
			half.z * (1.0 if (i & 4) != 0 else -1.0))
		var q: Vector3 = shape.global_transform * corner
		out.x = maxf(out.x, (q - origin).dot(forward))
		out.y = maxf(out.y, q.y)
	return out


# --- Waking, the chase and the bite -----------------------------------------------------------------

## Not before the block (see the header): a short run-in, then an open room through an opening in the middle lane, the
## centipede waiting just inside it, near enough that its wake distance reaches back well before the run-in's start; the
## runner comes from 40 m before the run-in.
func _test_wake_at_run_in(lanes: int) -> void:
	var mid: int = lanes / 2
	var tag: String = "(%d lanes)" % lanes
	var w: Dictionary = _world(lanes, [[mid], [mid]], [[]], 0, 3.0, mid, mid, {"room": 40.0, "run_in": 10.0})
	var world: RunWorld = w["world"]
	var entry: float = float((w["block"] as Dictionary)["entry"])
	world.player.distance = entry - 40.0
	var wake_d: float = t.wake_distance_at(world.tuning.pace())
	check(wake_d > float(w["at"]) - entry + 8.0, "(its wake distance, %.1f m, reaches back past the run-in's start, %.1f m from it) %s"
		% [wake_d, float(w["at"]) - entry, tag])
	var log := {"c": null, "woke_at": INF}
	await _run(world, 4.0, func(_f: int) -> bool:
		var c: Centipede = _follow(world, log)
		if c == null:
			return bool(log.get("found", false))
		if c.state != Centipede.State.SLEEP:
			log["woke_at"] = float((c.history[0] as Array)[2]) - entry
			return true
		return false)
	check(float(log["woke_at"]) >= 0.0 and float(log["woke_at"]) <= 1.0,
		"it wakes only once the runner is in its block, at the run-in's start (%.2f m past it) %s" % [log["woke_at"], tag])
	await sim.free_world(world)


## Waking, the chase and the bite (see the header): one open room the runner enters through an opening in the middle
## lane, a wall closed in every lane at its end, where the runner stops; the centipede waits in an edge lane halfway along
## the room, facing them. At 5 lanes the runner has claws.
func _test_wake_and_bite(lanes: int) -> void:
	var mid: int = lanes / 2
	var edge: int = lanes - 1
	var claws: bool = lanes == 5
	var tag: String = "(%d lanes%s)" % [lanes, ", claws" if claws else ""]
	var w: Dictionary = _world(lanes, [[mid], [], [mid]], [[], []], 0, 16.0, edge, mid)
	var world: RunWorld = w["world"]
	var p: Player = world.player
	p.armor = 1
	p.claws = claws
	var events: Array = []
	p.movement_event.connect(func(kind: StringName) -> void: events.append([world.level_time(), kind]))
	var log := {"wake_d": -1.0, "wake_head": Vector2.ZERO, "moved_in_wake": false, "inside": 0, "fast": 0.0,
		"stopped_at": -1.0, "c": null, "prev": Vector2.INF, "major": false, "sounds": []}
	var v_c: float = t.chase_speed(world.tuning.run_speed)
	var dt: float = 1.0 / Engine.physics_ticks_per_second
	var maze: CentipedeMaze = CentipedeMaze.for_block(w["layout"], 0, world.tuning)
	await _run(world, 9.0, func(_f: int) -> bool:
		var c: Centipede = _follow(world, log)
		if c == null:
			return bool(log.get("found", false))
		log["sounds"] = c.sounds_played.duplicate()
		if c.state == Centipede.State.SLEEP:
			check(c.head().distance_to(Vector2(world.geo.lane_x(edge), float(w["at"]))) < EPS,
				"it waits still at its spot until it wakes " + tag)
		elif float(log["wake_d"]) < 0.0:
			log["wake_d"] = absf(p.distance - c.head().y)
			log["wake_head"] = c.head()
		if c.state == Centipede.State.WAKE and c.head().distance_to(log["wake_head"]) > EPS:
			log["moved_in_wake"] = true
		if not maze.clear_at(c.head().x, c.head().y):
			log["inside"] = int(log["inside"]) + 1
		if log["prev"] != Vector2.INF:
			log["fast"] = maxf(float(log["fast"]), c.head().distance_to(log["prev"]) - v_c * dt)
		log["prev"] = c.head()
		log["major"] = bool(log["major"]) or c.is_major_attack_active()
		if p.stopped and float(log["stopped_at"]) < 0.0:
			log["stopped_at"] = world.level_time()
		return not p.alive)
	var c: Centipede = _follow(world, log)
	check(c != null, "it spawns, and stays in play while it bites " + tag)
	if c == null:
		await sim.free_world(world)
		return
	var wake_d: float = t.wake_distance_at(world.tuning.pace())
	check(float(log["wake_d"]) > 0.0 and float(log["wake_d"]) <= wake_d + 0.5,
		"it wakes once the runner is within its wake distance (%.1f m, its %.1f m) %s" % [log["wake_d"], wake_d, tag])
	check(not bool(log["moved_in_wake"]), "it keeps still while it wakes (its warning) " + tag)
	check(int(log["inside"]) == 0, "its head never touches debris (%d frames) %s" % [log["inside"], tag])
	check(float(log["fast"]) <= 0.001, "it never moves faster than its chase speed (%.4f m over) %s" % [log["fast"], tag])
	check(float(log["stopped_at"]) > 0.0, "the runner stops at the closed wall " + tag)
	check(not c.bites.is_empty(), "it bites the stopped runner (%d bites) %s" % [c.bites.size(), tag])
	var telegraphs_ok: bool = true
	for bite: Array in c.bites:
		if float(bite[1]) >= 0.0:
			telegraphs_ok = telegraphs_ok and float(bite[1]) - float(bite[0]) >= t.bite_telegraph - dt * 0.5
	check(telegraphs_ok, "every bite goes live only after its telegraph (%.2f s) %s: %s" % [t.bite_telegraph, tag, c.bites])
	var contacts_ok: bool = not c.bite_contacts.is_empty()
	for contact: Array in c.bite_contacts:
		contacts_ok = contacts_ok and bool(contact[1]) and float(contact[2]) >= t.bite_telegraph - dt * 0.5
	check(contacts_ok, "every hit it deals is a live bite, after its telegraph %s: %s" % [tag, c.bite_contacts])
	# Its warnings: the wake's hiss first; a hiss for every bite's telegraph, a snap as it goes live.
	var sounds: Array = log["sounds"]
	var live: int = c.bites.filter(func(bite: Array) -> bool: return float(bite[1]) >= 0.0).size()
	check(not sounds.is_empty() and sounds[0] == &"centipede_wake" and sounds.count(&"centipede_bite") == c.bites.size()
		and sounds.count(&"centipede_snap") == live, "its warnings sound: the wake, then each bite's telegraph and snap %s: %s"
		% [tag, sounds])
	check(not bool(log["major"]), "it's never a big attack " + tag)
	var kinds: Array = events.map(func(e: Array) -> StringName: return e[1])
	check(kinds.has(&"armor_break"), "the armor takes its first bite %s: %s" % [tag, kinds])
	check(not p.alive and p.last_event.begins_with("died"), "with neither armor nor shield left, a bite kills " + tag)
	if claws:
		check(c.alive, "a claw runner is bitten like anyone, and never kills it " + tag)
	await sim.free_world(world)


# --- The dash ---------------------------------------------------------------------------------------

## Met head-on (see the header): a corridor in the middle lane through a long room, open at both its walls; the
## centipede waits in it, facing the runner, who dashes once it comes within DASH_GAP. At 6 lanes Reduced flashing is on.
func _test_head_on(lanes: int) -> void:
	var mid: int = lanes / 2
	var reduced: bool = lanes == 6
	var tag: String = "(%d lanes%s)" % [lanes, ", Reduced flashing" if reduced else ""]
	var w: Dictionary = _world(lanes, [[mid], [mid]], [[mid - 1, mid + 1]], 0, 14.0, mid, mid, {"room": 50.0})
	var world: RunWorld = w["world"]
	var b: Dictionary = w["block"]
	var p: Player = world.player
	p.armor = 1
	Settings.flashing_reduced = reduced
	var events: Array = []
	p.movement_event.connect(func(kind: StringName) -> void: events.append(kind))
	var log := {"c": null, "dashed": -1.0, "wounded": false, "sparking": false, "leaking": false, "wounds": 0,
		"stunned": false, "shut": true, "turned": false, "after": false, "gave_up": -1.0, "gone": false, "contacts": 0,
		"sounds": [], "head": 0.0, "flared": false}
	await _run(world, 9.0, func(_f: int) -> bool:
		var c: Centipede = _follow(world, log)
		if c == null or not world.director.active.has(c):
			log["gone"] = bool(log.get("found", false))
			return bool(log["gone"])
		log["sounds"] = c.sounds_played.duplicate()
		log["wounds"] = maxi(int(log["wounds"]), c.dash_wounds)
		log["contacts"] = c.bite_contacts.size()
		log["flared"] = bool(log["flared"]) or c.model().lenses_flaring()
		if float(log["dashed"]) < 0.0 and c.state == Centipede.State.CHASE and c.head().y - p.distance <= DASH_GAP:
			RunSim.act(p, &"dash")
			log["dashed"] = world.level_time()
		if c.wounded and not bool(log["wounded"]):
			log["wounded"] = true
			log["sparking"] = c.model().sparking()
			log["leaking"] = c.model().leaking()
		if c.state == Centipede.State.STUN:
			log["stunned"] = true
			log["shut"] = bool(log["shut"]) and not c.bite_live()
		if bool(log["wounded"]) and c.state == Centipede.State.CHASE:
			# Chasing from behind: it has turned to face the way the runner went, and goes that way.
			if cos(c.heading()) > 0.7:
				log["turned"] = true
			if bool(log["turned"]) and c.head().y > float(log["head"]) + 2.0 and c.head().y < p.distance:
				log["after"] = true
		if not bool(log["turned"]):
			log["head"] = c.head().y
		if c.state == Centipede.State.GIVE_UP and float(log["gave_up"]) < 0.0:
			log["gave_up"] = p.distance
		return false)
	Settings.flashing_reduced = false
	check(bool(log.get("found", false)) and float(log["dashed"]) > 0.0, "it comes at the runner, who dashes at it head-on " + tag)
	check(bool(log["wounded"]) and int(log["wounds"]) == 1,
		"the dash passes through it and wounds it once, whatever of it the dash meets (%d) %s" % [log["wounds"], tag])
	check(p.alive and p.armor == 1 and not events.has(&"armor_break") and not events.has(&"armor_hit"),
		"the runner is unharmed by it %s: %s" % [tag, events])
	check(bool(log["leaking"]) and bool(log["sparking"]) != reduced,
		"it shows its wound: its cracked tube leaking, sparks %s %s" % ["off" if reduced else "flying", tag])
	check(bool(log["flared"]) != reduced, "its lenses flare as it rears to wake %s %s" % ["(not with Reduced flashing)"
		if reduced else "", tag])
	check((log["sounds"] as Array).has(&"centipede_wound"), "its wound sounds " + tag)
	check(bool(log["stunned"]) and bool(log["shut"]), "it recoils, stunned, its jaws shut " + tag)
	check(bool(log["turned"]) and bool(log["after"]), "then it turns and chases from behind " + tag)
	check(int(log["contacts"]) == 0, "the runner, faster, gets away unbitten " + tag)
	var line: float = float(b["end"]) + t.leave_margin
	check(float(log["gave_up"]) >= line - 0.5 and float(log["gave_up"]) <= line + 2.0,
		"it gives up once the runner is out past its block's last wall (at %.1f m, the line %.1f m) %s" % [log["gave_up"],
			line, tag])
	check(bool(log["gone"]), "and leaves play behind them " + tag)
	await sim.free_world(world)


## The second dash kills it (see the header): a centipede wounded already (Enemy.wound, as a dash's contact wounds it),
## then met head-on in a corridor.
func _test_second_dash() -> void:
	var lanes: int = 5
	var mid: int = lanes / 2
	var w: Dictionary = _world(lanes, [[mid], [mid]], [[mid - 1, mid + 1]], 0, 14.0, mid, mid, {"room": 50.0})
	var world: RunWorld = w["world"]
	var p: Player = world.player
	p.armor = 1
	var c: Centipede = await _spawned(world)
	check(c != null, "it spawns (the second dash)")
	if c == null:
		await sim.free_world(world)
		return
	c.wound(&"dash")
	check(c.wounded and c.dash_wounds == 1 and c.alive and c.state == Centipede.State.STUN,
		"a wound wakes a sleeping one, stunned (it keeps still for its wake time)")
	var log := {"found": true, "c": c, "cause": &"", "sounds": [], "dashed": false}
	c.defeated.connect(func(_e: Enemy, cause: StringName) -> void: log["cause"] = cause)
	# Its sounds as it leaves the tree (its defeat has played its death by then).
	c.tree_exiting.connect(func() -> void: log["sounds"] = (log["c"] as Centipede).sounds_played.duplicate())
	await _run(world, 6.0, func(_f: int) -> bool:
		var cc: Centipede = _follow(world, log)
		if cc == null or not cc.alive:
			return true
		if not bool(log["dashed"]) and cc.state == Centipede.State.CHASE and cc.head().y - p.distance <= DASH_GAP:
			RunSim.act(p, &"dash")
			log["dashed"] = true
		return false)
	check(bool(log["dashed"]) and log["cause"] == &"dash", "the second dash kills it (%s)" % log["cause"])
	check(world.score.kills == 1 and world.score.score >= t.score_value,
		"it's the player's kill, with its score (%d kills, %d points)" % [world.score.kills, world.score.score])
	check(p.alive and p.armor == 1, "the runner is unharmed by it")
	await tree.physics_frame
	await tree.physics_frame
	check(_centipede(world) == null and (log["sounds"] as Array).has(&"centipede_death"), "it leaves play, its death sounding")
	await sim.free_world(world)


# --- Walled in -------------------------------------------------------------------------------------

## Walled in (see the header): a cell in room 0 from lane 0 to the lane before the divider (lanes - 2), closed at both
## walls; the way past it in the edge lane.
func _test_trapped(lanes: int) -> void:
	var edge: int = lanes - 1
	var tag: String = "(%d lanes)" % lanes
	var walls: Array = [[edge], [edge]]
	var rooms: Array = [[edge - 1]]
	# The runner passes by along the way.
	var w: Dictionary = _world(lanes, walls, rooms, 0, 12.0, 0, edge)
	var world: RunWorld = w["world"]
	var log := {"c": null, "woke": false, "gone": false, "passed": false}
	await _run(world, 5.0, func(_f: int) -> bool:
		var c: Centipede = _follow(world, log)
		if c == null or not world.director.active.has(c):
			log["gone"] = bool(log.get("found", false))
			return bool(log["gone"])
		log["woke"] = bool(log["woke"]) or c.state != Centipede.State.SLEEP
		log["passed"] = bool(log["passed"]) or world.player.distance > c.head().y
		return false)
	check(bool(log.get("found", false)) and bool(log["passed"]) and not bool(log["woke"]),
		"a walled-in one sleeps on as the runner passes by its cell " + tag)
	check(bool(log["gone"]), "and leaves play behind them " + tag)
	await sim.free_world(world)
	# The runner stops at its cell's wall in lane 0, and dashes through it.
	w = _world(lanes, walls, rooms, 0, 20.0, 0, 0)
	world = w["world"]
	var p: Player = world.player
	p.armor = 1
	var events: Array = []
	p.movement_event.connect(func(kind: StringName) -> void: events.append(kind))
	log = {"c": null, "asleep_at_wall": false, "dashed": false, "woke": false, "sounds": []}
	await _run(world, 5.0, func(_f: int) -> bool:
		var c: Centipede = _follow(world, log)
		if c == null:
			return bool(log.get("found", false))
		if p.stopped and not bool(log["dashed"]):
			log["asleep_at_wall"] = c.state == Centipede.State.SLEEP
			RunSim.act(p, &"dash")
			log["dashed"] = true
			return false
		if not events.has(&"doodad_smash"):
			return false
		if c.state != Centipede.State.SLEEP:
			log["woke"] = true
			log["sounds"] = c.sounds_played.duplicate()
			return true
		return false)
	check(bool(log["dashed"]) and bool(log["asleep_at_wall"]), "it sleeps while its cell's wall stands, the runner at it " + tag)
	check(events.has(&"doodad_smash") and bool(log["woke"]) and (log["sounds"] as Array).has(&"centipede_wake"),
		"a dash that opens its cell releases it: it wakes, with its warning %s: %s" % [tag, events])
	await sim.free_world(world)


# --- An ambush --------------------------------------------------------------------------------------

## An ambush (task O5; the owner, October 22, 2026: "resting inside of one of the debris doodads, and you can barely see
## its body, and when you get close to it, the debris shatters and the centipede is released"): hidden in an edge lane's
## divider, a sliver of its body poking out beside it; it sleeps on while the runner is further than its ambush distance,
## then the debris it lies in shatters (the smash's crunch, then its wake's warning) and it wakes and chases; and debris
## of it smashed (a dash) releases it at once.
func _test_ambush(lanes: int) -> void:
	var edge: int = lanes - 1
	var mid: int = lanes / 2
	var tag: String = "(%d lanes)" % lanes
	var layout: LevelLayout = MazeKit.block(tuning, lanes, [[mid], [mid]], [[edge]], {"room": 40.0})
	var room: Dictionary = (layout.maze[0]["rooms"] as Array)[0]
	var at: float = float(room["start"]) + 15.0
	layout.enemies.append(MazeKit.ambush(at, edge, 0, -1))
	var w: Dictionary = _world_of(layout, mid, at)
	var world: RunWorld = w["world"]
	var p: Player = world.player
	p.armor = 1
	var c: Centipede = await _spawned(world)
	check(c != null and c.ambush and c.hidden and c.host.size() >= 2, "an ambush spawns hidden in its divider's debris " + tag)
	if c == null:
		await sim.free_world(world)
		return
	var widest: float = 0.0
	for d: Dictionary in c.host:
		widest = maxf(widest, tuning.doodad_size(StringName(d["size"])).x)
	var lane_x: float = world.geo.lane_x(edge)
	var showing: float = absf(c.head().x - lane_x) + Centipede.BODY_HIT.x * 0.5 - widest * 0.5
	check(c.head().x < lane_x and absf(showing - t.ambush_showing) < EPS,
		"a sliver of its body pokes out toward the open lane (%.2f m past the debris) %s" % [showing, tag])
	var reach: float = t.ambush_distance_at(world.tuning.pace())
	var log := {"hidden_far": true, "broke_at": INF, "all_smashed": false, "sounds": [], "chased": false}
	await _run(world, 8.0, func(_f: int) -> bool:
		if not is_instance_valid(c):
			return true
		var gap: float = absf(p.distance - c.head().y)
		if c.hidden and gap <= reach - 1.0 and p.distance >= float(layout.maze[0]["entry"]):
			log["hidden_far"] = false
		if not c.hidden and float(log["broke_at"]) == INF:
			log["broke_at"] = gap
			var smashed: bool = true
			for d: Dictionary in c.host:
				smashed = smashed and bool(d.get("smashed", false))
			log["all_smashed"] = smashed
			log["sounds"] = c.sounds_played.duplicate()
		log["chased"] = bool(log["chased"]) or c.state == Centipede.State.CHASE
		return bool(log["chased"]))
	check(bool(log["hidden_far"]) and float(log["broke_at"]) <= reach + 1.0 and float(log["broke_at"]) >= reach - 1.0,
		"it stays hidden until the runner is within its ambush distance (%.1f m; broke out at %.1f m) %s"
		% [reach, log["broke_at"], tag])
	check(bool(log["all_smashed"]) and (log["sounds"] as Array) == [&"doodad_smash", &"centipede_wake"],
		"as it breaks out the debris it lay in shatters, with the smash's crunch, then its wake's warning (%s) %s"
		% [log["sounds"], tag])
	check(bool(log["chased"]), "then it chases, as any other " + tag)
	await sim.free_world(world)
	# Its debris smashed (a dash) releases it at once, the runner still far off.
	layout = MazeKit.block(tuning, lanes, [[mid], [mid]], [[edge]], {"room": 40.0})
	layout.enemies.append(MazeKit.ambush(at, edge, 0, -1))
	w = _world_of(layout, mid, at)
	world = w["world"]
	c = await _spawned(world)
	if c != null:
		(c.host[0] as Dictionary)["smashed"] = true
		await tree.physics_frame
		await tree.physics_frame
	check(c != null and not c.hidden and c.state != Centipede.State.SLEEP,
		"debris it lies in smashed releases it at once " + tag)
	await sim.free_world(world)


# --- A ceiling --------------------------------------------------------------------------------------

## It can't follow onto a ceiling (see the header): one long open room the runner enters in the middle lane, the
## centipede waiting in an edge lane near its start; an anti-grav pad further on, a ceiling from it past the block.
func _test_ceiling() -> void:
	var lanes: int = 5
	var mid: int = lanes / 2
	var layout: LevelLayout = MazeKit.block(tuning, lanes, [[mid], [mid]], [[]], {"room": 50.0})
	var b: Dictionary = layout.maze[0]
	var room: Dictionary = (b["rooms"] as Array)[0]
	var at: float = float(room["start"]) + 10.0
	var pad_at: float = float(room["start"]) + 32.0
	layout.pads.append({"lane": mid, "at": pad_at})
	layout.hulls.append(LevelLayout.make_hull(pad_at - 3.0, float(b["exit"]) + 30.0, Vector2i(0, lanes - 1), lanes))
	layout.enemies.append(MazeKit.centipede(at, lanes - 1))
	var w: Dictionary = _world_of(layout, mid, at)
	var world: RunWorld = w["world"]
	var p: Player = world.player
	var log := {"c": null, "chased": false, "ceiling": -1.0, "gave_up": false, "riding": false, "telegraphs": 0,
		"gone": false, "contacts": 0}
	await _run(world, 7.0, func(_f: int) -> bool:
		var c: Centipede = _follow(world, log)
		if c == null or not world.director.active.has(c):
			log["gone"] = bool(log.get("found", false))
			return bool(log["gone"])
		var on_ceiling: bool = p.surface == Player.Surface.CEILING
		if c.state == Centipede.State.CHASE and not on_ceiling:
			log["chased"] = true
		if on_ceiling and float(log["ceiling"]) < 0.0:
			log["ceiling"] = world.level_time()
			log["telegraphs"] = c.bites.size()
		if c.state == Centipede.State.GIVE_UP and not bool(log["gave_up"]):
			log["gave_up"] = true
			log["riding"] = on_ceiling
		if on_ceiling:
			check(c.bites.size() == int(log["telegraphs"]), "it never rears to bite at a runner on the ceiling")
		log["contacts"] = c.bite_contacts.size()
		return false)
	check(bool(log["chased"]) and float(log["ceiling"]) > 0.0, "it chases the runner, who takes the anti-grav pad to the ceiling")
	check(bool(log["gave_up"]) and bool(log["riding"]), "it can't follow onto the ceiling: it gives up")
	check(int(log["contacts"]) == 0 and p.alive, "it never bites the runner")
	check(bool(log["gone"]), "and leaves play behind them")
	await sim.free_world(world)

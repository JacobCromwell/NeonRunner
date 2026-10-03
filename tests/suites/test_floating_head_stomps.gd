extends TestSuite
## The Floating Head's stomp windows (GDD §10; task E1c), after its face-off pins it
## (test_floating_head_faceoff.gd):
## - its data: the routes per phase, the windows' numbers and their sounds (the same every time);
## - the ways onto its head at 3, 5 and 6 lanes, each taken by a runner who reads the fight
##   (FloatingHeadBot, no god mode): up the fallen tower's ramp in the first phase, a wall jump in the
##   second (from either wall), a ceiling ridden from its pads in the third; each ends in a stomp on a
##   red weak point that takes a third of its health, then it shakes free (shrieks) and rises;
## - every way up is physical: the ramp's top is a floor and its sides block a lane switch, the pinned
##   crown is a floor where it's drawn, the ceiling a hull; nothing but the stomp boxes hurts it;
## - a missed window (still on the trucks near its face, or past its weak points): it shakes free before
##   the runner reaches it, rises back in front and the face-off goes on; the next pin opens the same
##   window at the same pace (no time limit, no escalation), and the ship never touches the runner;
## - damage: stomps do the real damage; weapons chip only up to the cap (at most one stomp saved);
## - the armor pickups (the standard rule, 10-15 s): one as the final phase starts, one after a break
##   (at most once a phase), never in a bomb's or a cyborg's landing circle nor where a pin goes;
## - the third window's ceiling: bombs never lock under it, the face-off waits past it, and it's never
##   in the ship's space;
## - the whole fight in its preview, from the entrance to the last stomp, at 3, 5 and 6 lanes; and on a
##   plain street without god mode;
## - every attempt plays out the same way.
## Every fight here runs at the City's speed (21 m/s), as the campaign plays it (GDD §3; task E1f:
## FloatingHeadBot.campaign_tuning).

const BOSS_PATH: String = "res://data/bosses/city_boss.tres"
const LANES: Array[int] = [3, 5, 6]
const SOUNDS: Array[StringName] = [&"head_weak_open", &"head_shriek", &"head_shake_free", &"ramp_slam", &"pads_light",
	&"ceiling_lower"]
const ROUTES: Array[StringName] = [&"ramp", &"wall", &"ceiling"]

var sim: RunSim
var def: BossDef


func run() -> void:
	# The fight at the City's speed, as the campaign plays it (GDD §3; E1f).
	tuning = FloatingHeadBot.campaign_tuning(tuning)
	sim = RunSim.new(tree, tuning)
	def = load(BOSS_PATH) as BossDef
	check(def != null and def.is_built(), "the Floating Head's fight exists")
	if def == null:
		return
	_test_data()
	await _test_routes()
	await _test_both_walls()
	await _test_surfaces()
	await _test_missed_windows()
	await _test_passed_window()
	await _test_damage()
	await _test_armor_pickups()
	await _test_ceiling_rules()
	await _test_whole_fight()
	await _test_plain_fight()
	await _test_same_every_attempt()


# --- Helpers -------------------------------------------------------------------------------

## The fight for a test: straight into the face-off (no bombing runs unless `runs`), the marked towers
## every 200 m from 160 m with a tower lined up at once (towers_after 0), on a plain street or its real
## arena.
func _def(runs: bool = false, plain: bool = true, pattern: String = "") -> BossDef:
	var out: BossDef = def.duplicate() as BossDef
	var t := (def.tuning as FloatingHeadTuning).duplicate() as FloatingHeadTuning
	if not runs:
		t.first_run_seconds = 0.0
		t.later_runs = 0
	t.tower_first = 160.0
	t.tower_spacing = 200.0
	t.towers_after = 0
	if pattern != "":
		t.faceoff_patterns = PackedStringArray([pattern])
	out.tuning = t
	if plain:
		out.arena = null
	return out


## A fight against `p_def` in a bare world at `lanes`, starting at phase `phase`, with `loadout` (none:
## nothing equipped): [world, head].
func _fight(p_def: BossDef, lanes: int, phase: int = 0, loadout: Loadout = null) -> Array:
	var head := BossEncounter.create(p_def) as FloatingHead
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = p_def
	ctx.config = BossArena.base_config(p_def)
	ctx.config.lane_count = lanes
	ctx.tuning = tuning
	ctx.boss_resume = {"phase": phase} if phase > 0 else {}
	var arena: BossArena = head.plan_arena(ctx)
	var world: RunWorld = sim.build_world(arena.layout, loadout, tuning, ctx.config)
	head.setup(world, ctx, arena)
	return [world, head]


## Steps the world until `condition` holds or `seconds` pass. True if it held.
func _until(world: RunWorld, condition: Callable, seconds: float) -> bool:
	if not world.player.running:
		await tree.physics_frame
		world.player.running = true
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		if condition.call():
			return true
		await tree.physics_frame
	return condition.call()


func _events(head: BossEncounter, event: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in head.events:
		if e["event"] == event:
			out.append(e)
	return out


func _sounds(head: BossEncounter, sound: StringName) -> int:
	var n: int = 0
	for e: Dictionary in _events(head, &"sound"):
		if e["name"] == sound:
			n += 1
	return n


## The runner's cause of death once it happens: [cause].
func _watch_death(world: RunWorld) -> Array[String]:
	var cause: Array[String] = [""]
	world.player.died.connect(func(c: String) -> void: cause[0] = c)
	return cause


## The runner's movement events so far, counted by kind.
func _watch_moves(world: RunWorld) -> Dictionary:
	var moves: Dictionary = {}
	world.player.movement_event.connect(func(kind: StringName) -> void: moves[kind] = int(moves.get(kind, 0)) + 1)
	return moves


## The world's floor or ceiling surface under a point (a ray down, or up for the hull layer): its
## height, or NAN if there is none within `reach`.
func _surface_at(world: RunWorld, p: Vector3, mask: int, reach: float = 6.0, up: bool = false) -> float:
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collision_mask = mask
	ray.from = p
	ray.to = p + Vector3(0.0, reach if up else -reach, 0.0)
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
	return NAN if hit.is_empty() else (hit["position"] as Vector3).y


## True if a lane blocker fills a box (the player's own lane check).
func _blocked(world: RunWorld, center: Vector3, size: Vector3) -> bool:
	var shape := BoxShape3D.new()
	shape.size = size
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, center)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	q.collision_mask = TrackBuilder.LAYER_LANE_BLOCKER
	return not world.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


## Plays phase `phase` at `lanes` until the first stomp or a missed window (or `seconds`), with a runner
## who reads the fight and takes the way up (no god mode unless `god`): {world, head, bot, moves, cause,
## stomped, missed, ramp_top (the highest it ran up the ramp), ceiling (rode the ceiling), weak_lane
## (the lane it stomped in)}.
func _play_window(phase: int, lanes: int, wall: int = 0, god: bool = false, seconds: float = 90.0) -> Dictionary:
	var pair: Array = _fight(_def(), lanes, phase)
	var world: RunWorld = pair[0]
	var head: FloatingHead = pair[1]
	world.player.god_mode = god
	var bot := FloatingHeadBot.new(head, true)
	bot.wall_side = wall
	var out: Dictionary = {"world": world, "head": head, "bot": bot, "moves": _watch_moves(world),
		"cause": _watch_death(world), "ramp_top": 0.0, "ceiling": false, "health0": head.health,
		"weak_lanes": head.weak_point_lanes()}
	await _until(world, func() -> bool:
		bot.step()
		var p: Player = world.player
		if head.ramp != null and is_instance_valid(head.ramp) and p.lane == head.ramp_lane and p.grounded \
				and p.surface == Player.Surface.FLOOR:
			out["ramp_top"] = maxf(float(out["ramp_top"]), p.h)
		if p.surface == Player.Surface.CEILING and head.window_open:
			out["ceiling"] = true
		return not p.alive or not _events(head, &"weak_point").is_empty() or not _events(head, &"window_missed").is_empty(),
		seconds)
	out["stomped"] = not _events(head, &"weak_point").is_empty()
	out["missed"] = not _events(head, &"window_missed").is_empty()
	return out


# --- Data ----------------------------------------------------------------------------------------

func _test_data() -> void:
	var t := def.tuning as FloatingHeadTuning
	check(t.stomp_route(0) == &"ramp" and t.stomp_route(1) == &"wall" and t.stomp_route(2) == &"ceiling",
		"GDD §10: up the fallen tower in the first phase, a wall jump in the second, a ceiling in the third")
	var odd := FloatingHeadTuning.new()
	odd.stomp_routes = PackedStringArray(["wall", "nonsense"])
	check(odd.stomp_route(0) == &"wall" and odd.stomp_route(1) == &"ramp" and odd.stomp_route(5) == &"ramp",
		"the routes are data: an unknown word is the ramp, and later phases use the last")
	check(def.phase_count() == 3, "three phases, one stomp each")
	for i: int in def.phase_count():
		check(def.phase_list()[i].hits == 1, "phase %d takes one stomp" % (i + 1))
	var sfx := load("res://data/audio/sfx_library.tres") as SfxLibrary
	for sound: StringName in SOUNDS:
		check(sfx.names().has(String(sound)) and sfx.stream(sound) != null, "its sound %s exists" % sound)
		check(float(sfx.pitch_variation.get(String(sound), 0.0)) == 0.0, "%s sounds the same every time" % sound)
	# The windows' reach against the runner's moves: a jump from the trucks can't reach the weak points
	# (a floor runner never gets up there by accident), a wall jump off a fresh wall entry can.
	var wall_jump_peak: float = tuning.wall_entry_height + pow(tuning.wall_jump_velocity, 2.0) / (2.0 * tuning.gravity())
	check(tuning.jump_height < t.pin_top_height - 0.3 and wall_jump_peak > t.pin_top_height - 0.2,
		"a jump from the trucks (%.1f m) can't reach its weak points (%.1f m); a wall jump (%.1f m) can" % [
		tuning.jump_height, t.pin_top_height, wall_jump_peak])
	# Its stomp boxes are as deep as the run's pace makes them (GDD §3): at the City's speed, and on the
	# hardest tier's.
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var fastest: float = 1.0
	for m: float in campaign.tier_speed_multiplier:
		fastest = maxf(fastest, m)
	for pace: float in [tuning.pace(), tuning.pace() * fastest]:
		check(t.shake_ahead > t.stomp_depth * pace * 0.5 - FloatingHeadModel.WEAK_Z + t.window_pass_margin,
			"shaking free, its face always ends ahead of a runner on its crown (%.1f m, at %.1f m/s)" % [t.shake_ahead,
			MovementTuning.REFERENCE_SPEED * pace])


# --- The ways onto its head ------------------------------------------------------------------------

## Each phase's way up at every lane count, taken by a runner who reads the fight (no god mode): a
## stomp on a red weak point, a third of its health, then it shakes free, shrieks and rises.
func _test_routes() -> void:
	for phase: int in 3:
		for lanes: int in LANES:
			var r: Dictionary = await _play_window(phase, lanes)
			var world: RunWorld = r["world"]
			var head: FloatingHead = r["head"]
			var moves: Dictionary = r["moves"]
			var route: StringName = ROUTES[phase]
			var tag: String = "(phase %d, %s, %d lanes)" % [phase + 1, route, lanes]
			var opens: Array[Dictionary] = _events(head, &"window_open")
			check(not opens.is_empty() and opens[0]["route"] == route, "pinned, its window opens with the phase's way up %s" % tag)
			check(_sounds(head, &"head_weak_open") >= 1, "its weak points come out with their sound %s" % tag)
			check(r["stomped"] and world.player.alive and not r["missed"],
				"a runner who reads it gets on top and stomps a weak point, no god mode (%s) %s" % [
				(r["cause"] as Array)[0], tag])
			match route:
				&"ramp":
					var top: float = float(r["ramp_top"])
					check(top > 1.2 and _sounds(head, &"ramp_slam") == 1,
						"the tower's slab slams down, and the runner ran up it (%.2f m up) %s" % [top, tag])
					check(head.ramp_lane == head.ramp_lane_for(head.pin_side) and head.weak_point_lanes().has(head.ramp_lane),
						"the ramp lies in the weak point's lane nearest the tower's wall %s" % tag)
				&"wall":
					check(int(moves.get(&"wall_enter", 0)) >= 1 and int(moves.get(&"wall_jump", 0)) >= 1,
						"it got on top by a wall jump %s" % tag)
				&"ceiling":
					check(r["ceiling"] and int(moves.get(&"pad", 0)) >= 1 and int(moves.get(&"hull_end", 0)) >= 1,
						"it rode the ceiling from a pad and dropped off its end %s" % tag)
					check(_sounds(head, &"pads_light") == 1 and _sounds(head, &"ceiling_lower") == 1,
						"the pads light up and the ceiling lowers in, both heard %s" % tag)
			if not r["stomped"]:
				await sim.free_world(world)
				continue
			var stomps: Array[Dictionary] = _events(head, &"stomp")
			check(not stomps.is_empty() and stomps[0]["route"] == route and (r["weak_lanes"] as Array).has(int(stomps[0]["lane"])),
				"the stomp lands on a weak point %s" % tag)
			if phase < 2:
				check(_sounds(head, &"head_shriek") == 1, "GDD §10: it shrieks %s" % tag)
			else:
				check(_sounds(head, &"head_shriek") == 0 and _events(head, &"voice_cut").size() == 1,
					"the last stomp's cry is the propaganda cutting out mid-shout (GDD §10's defeat) %s" % tag)
			var third: float = head.max_health / 3.0
			if phase < 2:
				check(absf(head.health - (float(r["health0"]) - third)) < 0.5 and head.phase_index == phase + 1,
					"the stomp takes a third of its health (%.0f of %.0f left) and ends the phase %s" % [head.health,
					head.max_health, tag])
				# It shakes free and rises: its face ends up ahead of the runner and it goes back up.
				var s: Dictionary = {"behind": 0}
				await _until(world, func() -> bool:
					if head.step == FloatingHead.Step.SHAKE or head.step == FloatingHead.Step.RISE:
						if head.pose.z < -0.01 and world.player.h < 0.3 and world.player.surface == Player.Surface.FLOOR:
							s["behind"] += 1
					return head.state == BossEncounter.State.FIGHT, 6.0)
				var shakes: Array[Dictionary] = _events(head, &"shake_free")
				check(shakes.size() == 1 and bool(shakes[0]["next_phase"]) and _sounds(head, &"head_shake_free") == 1
					and not _events(head, &"rise").is_empty(), "then it shakes free and rises %s" % tag)
				check(head.pose.y > head.tuning.face_height - 0.5 and not head.body.top_solid() and head.body.hull_solid(),
					"back in the air, its crown no floor and its hull solid again %s" % tag)
				check(int(s["behind"]) == 0 and world.player.alive, "and never over the runner on the trucks as it goes %s" % tag)
			else:
				check(head.is_defeated() and head.health <= 0.0, "the third stomp beats it %s" % tag)
			await sim.free_world(world)


## The wall jump from either wall, whichever side the tower fell on.
func _test_both_walls() -> void:
	for lanes: int in LANES:
		for wall: int in [-1, 1]:
			var r: Dictionary = await _play_window(1, lanes, wall)
			var world: RunWorld = r["world"]
			var head: FloatingHead = r["head"]
			var moves: Dictionary = r["moves"]
			var tag: String = "(%s wall, tower on the %s, %d lanes)" % ["left" if wall < 0 else "right",
				"left" if head.pin_side < 0 else "right", lanes]
			check(r["stomped"] and world.player.alive and int(moves.get(&"wall_jump", 0)) >= 1,
				"a wall jump gets on top and stomps, no god mode (%s) %s" % [(r["cause"] as Array)[0], tag])
			await sim.free_world(world)


# --- Physical surfaces -------------------------------------------------------------------------------

## Every way up is physical: the ramp's top is a floor surface from the trucks to the crown and its sides
## block a lane switch (down to the trucks) where it stands above a step; the pinned crown is a floor
## where it's drawn; the ceiling is a hull section and its pads are pads.
func _test_surfaces() -> void:
	# The ramp (phase 1) and the crown, at 5 lanes: pinned, with the runner standing well back.
	for lanes: int in [3, 5]:
		var pair: Array = _fight(_def(), lanes)
		var world: RunWorld = pair[0]
		var head: FloatingHead = pair[1]
		var tag: String = "(%d lanes)" % lanes
		world.player.god_mode = true
		var bot := FloatingHeadBot.new(head, true)
		bot.routes = false
		await _until(world, func() -> bool:
			bot.step()
			return head.step == FloatingHead.Step.PINNED and head.ramp != null and head.ramp.landed, 60.0)
		world.player.running = false
		var ramp: FloatingHeadRamp = head.ramp
		check(ramp != null and ramp.landed, "the ramp is down %s" % tag)
		if ramp == null:
			await sim.free_world(world)
			continue
		var x: float = world.geo.lane_x(ramp.lane)
		var worst: float = 0.0
		for k: int in 9:
			var d: float = lerpf(ramp.foot + 0.5, ramp.end - 0.2, k / 8.0)
			var y: float = _surface_at(world, Vector3(x, 8.0, TrackGeometry.world_z(d)), TrackBuilder.LAYER_FLOOR, 12.0)
			worst = maxf(worst, absf(y - ramp.top_at(d)) if not is_nan(y) else 99.0)
		check(worst < 0.05, "its top is a floor surface all the way up, where it's drawn (%.3f m off) %s" % [worst, tag])
		var steepest: float = 0.0
		for d: float in [ramp.foot, ramp.knee - 0.4, ramp.knee, ramp.end - 0.4]:
			steepest = maxf(steepest, ramp.top_at(d + world.player.speed / 60.0) - ramp.top_at(d))
		check(steepest < 0.3, "a runner walks up it (%.2f m a frame at run speed at its steepest) %s" % [steepest, tag])
		var side: int = 1 if ramp.lane == 0 else -1
		var nx: float = world.geo.lane_x(ramp.lane + side)
		var probe := Vector3(world.geo.lane_width * 0.5, tuning.hurtbox_size.y, tuning.hurtbox_size.z + 0.6)
		# E1e: its lead-in's sides are bevelled (a lane switch steps up them); the slab's sides block.
		check(ramp.knee > ramp.foot + (ramp.face - ramp.foot) * 0.7 and ramp.board_until() == ramp.knee,
			"its lead-in runs most of its length (to %.1f m of %.1f) %s" % [ramp.knee - ramp.foot, ramp.face - ramp.foot, tag])
		var lead_mid: float = lerpf(ramp.foot, ramp.knee, 0.6)
		check(not _blocked(world, Vector3(x, tuning.hurtbox_size.y * 0.5, TrackGeometry.world_z(lead_mid)), probe),
			"its lead-in's side lets a lane switch in %s" % tag)
		var bevel_x: float = x + side * ((world.geo.lane_width - 0.2) * 0.5 + ramp.bevel * 0.3)
		var bevel_y: float = _surface_at(world, Vector3(bevel_x, 3.0, TrackGeometry.world_z(lead_mid)), TrackBuilder.LAYER_FLOOR, 4.0)
		check(bevel_y > 0.05 and bevel_y < ramp.top_at(lead_mid) - 0.05,
			"its bevelled side is a floor between the trucks and its top (%.2f m, top %.2f m) %s" % [bevel_y, ramp.top_at(lead_mid), tag])
		var mid: float = lerpf(ramp.knee, ramp.face, 0.5)
		check(_blocked(world, Vector3(x, tuning.hurtbox_size.y * 0.5, TrackGeometry.world_z(mid)), probe),
			"its slab's side blocks a lane switch into it from the trucks (a solid side) %s" % tag)
		check(not _blocked(world, Vector3(x, ramp.top_at(mid + probe.z * 0.5) + 0.1 + tuning.hurtbox_size.y * 0.5, TrackGeometry.world_z(mid)), probe),
			"but not a runner in the air above it %s" % tag)
		check(not _blocked(world, Vector3(nx, tuning.hurtbox_size.y * 0.5, TrackGeometry.world_z(mid)), probe),
			"nor the lane beside it %s" % tag)
		var beside: float = _surface_at(world, Vector3(nx + side * -0.3, 3.0, TrackGeometry.world_z(lead_mid)), TrackBuilder.LAYER_FLOOR, 4.0)
		check(absf(beside) < 0.01, "and its bevels stop short of a runner's feet in the lane beside it (%.2f m) %s" % [beside, tag])
		# The crown: a floor where the hull is drawn, over every weak point's lane.
		var off: float = 0.0
		for l: int in head.weak_point_lanes():
			var lx: float = world.geo.lane_x(l)
			# (Past the ramp's top end, which rests on the crown just behind the face.)
			for z: float in [-1.5, FloatingHeadModel.WEAK_Z, -6.0]:
				var drawn: Vector3 = head.pinned_crown(lx, z)
				var y: float = _surface_at(world, drawn + Vector3(0.0, 3.0, 0.0), TrackBuilder.LAYER_FLOOR, 6.0)
				off = maxf(off, absf(y - drawn.y) if not is_nan(y) else 99.0)
		check(off < 0.05, "pinned, its crown is a floor where it's drawn (%.3f m off) %s" % [off, tag])
		check(not head.body.hull_solid(), "and its hull harmless while it's pinned %s" % tag)
		await sim.free_world(world)
	# The ceiling (phase 3): a hull section over the pads, and pads in every lane.
	var pair2: Array = _fight(_def(), 5, 2)
	var world2: RunWorld = pair2[0]
	var head2: FloatingHead = pair2[1]
	world2.player.god_mode = true
	var bot2 := FloatingHeadBot.new(head2, true)
	bot2.routes = false
	await _until(world2, func() -> bool:
		bot2.step()
		return (head2.step == FloatingHead.Step.PINNED and head2.ceiling_between(head2.ceiling_span.x, head2.ceiling_span.y)
			and world2.player.distance > head2.pad_at - 20.0), 90.0)
	world2.player.running = false
	await tree.physics_frame
	var span: Vector2 = head2.ceiling_span
	var hull: float = _surface_at(world2, Vector3(0.0, 2.0, TrackGeometry.world_z((span.x + span.y) * 0.5)), TrackBuilder.LAYER_HULL,
		8.0, true)
	check(absf(hull - tuning.ceiling_height) < 0.05, "the third window's ceiling is a hull section at the ceiling's height (%.2f m)" % hull)
	var pads: int = 0
	for node: Node in head2.props.get_children():
		var area := node as Area3D
		if area != null and area.get_meta(&"kind", &"") == &"pad":
			pads += 1
	check(pads == 5, "a pad in every lane (%d)" % pads)
	check(span.y < head2.pin_stern - 1.0 and span.x < head2.pad_at, "the ceiling runs from before the pads to before its face")
	await sim.free_world(world2)


# --- Missed windows ----------------------------------------------------------------------------------

## GDD §10: "if the player passes without a stomp, it shakes free and the phase's cycle repeats", with no
## time limit and no escalation. A runner who stays on the trucks: it shakes free before they reach it,
## rises back in front and the face-off goes on; the next tower pins it again and opens the same window
## at the same pace. The ship never touches them.
func _test_missed_windows() -> void:
	for phase: int in 3:
		var lanes: int = LANES[phase]
		var pair: Array = _fight(_def(), lanes, phase)
		var world: RunWorld = pair[0]
		var head: FloatingHead = pair[1]
		var t: FloatingHeadTuning = head.tuning
		var tag: String = "(phase %d, %d lanes)" % [phase + 1, lanes]
		var bot := FloatingHeadBot.new(head, true)
		bot.wrong_route = true
		var cause: Array[String] = _watch_death(world)
		var s: Dictionary = {"inside": 0, "min_gap": INF}
		await _until(world, func() -> bool:
			bot.step()
			if head.step == FloatingHead.Step.PINNED or head.step == FloatingHead.Step.SHAKE:
				s["min_gap"] = minf(float(s["min_gap"]), head.pose.z)
				if head.pose.z < 0.0:
					s["inside"] += 1
			return not world.player.alive or _events(head, &"window_missed").size() >= 2, 120.0)
		var misses: Array[Dictionary] = _events(head, &"window_missed")
		var opens: Array[Dictionary] = _events(head, &"window_open")
		check(misses.size() >= 2 and world.player.alive, "a runner who stays on the trucks misses the window again and again, unhurt (%s) %s" % [
			cause[0], tag])
		if misses.size() < 2 or opens.size() < 2:
			await sim.free_world(world)
			continue
		# E1e: while the ramp is the way up, the window stays open until a lane switch can't board it any
		# more (the end of its lead-in).
		var release: float = head.before_face(t.window_release_gap)
		if ROUTES[phase] == &"ramp":
			release = head.metres(t.ramp_length) * (1.0 - t.ramp_board_share)
		check(misses[0]["why"] == &"floor" and float(misses[0]["gap"]) <= release + 0.01
			and float(misses[0]["gap"]) > release - 1.0,
			"the window closes as they come within %.1f m of its face on the trucks (%.1f m) %s" % [release,
			float(misses[0]["gap"]), tag])
		check(int(s["inside"]) == 0 and float(s["min_gap"]) > release - 1.0,
			"it shakes free before they reach it: its face never nearer than %.1f m %s" % [float(s["min_gap"]), tag])
		check(_events(head, &"released").size() >= 1 and head.faceoff.running, "it rises back in front and the face-off goes on %s" % tag)
		check(head.phase_index == phase and absf(head.health - head.phase_start_health(phase)) < 0.01,
			"no damage and no phase change for a miss %s" % tag)
		# The next pin: the same window at the same pace (no escalation).
		var pins: Array[Dictionary] = _events(head, &"pinned")
		var starts: Array[Dictionary] = _events(head, &"pin_start")
		var same: bool = pins.size() >= 2 and starts.size() >= 2 and opens[1]["route"] == opens[0]["route"]
		if same:
			var fall0: float = float(pins[0]["t"]) - float(starts[0]["t"])
			var fall1: float = float(pins[1]["t"]) - float(starts[1]["t"])
			var open0: float = float(opens[0]["t"]) - float(pins[0]["t"])
			var open1: float = float(opens[1]["t"]) - float(pins[1]["t"])
			same = absf(fall0 - fall1) < 0.02 and absf(open0 - open1) < 0.02
		check(same, "the next tower pins it again: the same window, the same timing %s" % tag)
		var shakes: Array[Dictionary] = _events(head, &"shake_free")
		check(shakes.size() >= 2 and not bool(shakes[0]["next_phase"]) and _sounds(head, &"head_shake_free") >= 2,
			"each miss, it shakes free with its sound %s" % tag)
		await sim.free_world(world)


## Past its weak points without a stomp (a runner who landed on its crown and ran on): the window
## closes and it shakes free, its face pulling ahead of the runner, who drops off it unhurt.
func _test_passed_window() -> void:
	var pair: Array = _fight(_def(), 5, 1)
	var world: RunWorld = pair[0]
	var head: FloatingHead = pair[1]
	var bot := FloatingHeadBot.new(head, true)
	bot.routes = false
	var cause: Array[String] = _watch_death(world)
	var s: Dictionary = {"lifted": false, "on_crown": 0, "gap": -INF, "fell": false}
	await _until(world, func() -> bool:
		bot.step()
		var p: Player = world.player
		if head.window_open and not s["lifted"]:
			# Onto the crown in the middle lane just past its face, as a wall jump that fell short of the weak
			# point would leave the runner: it lands on the crown before the weak points' stomp boxes.
			s["lifted"] = true
			p.distance = head.pin_stern + 0.3
			p.lane = world.geo.lane_count / 2
			p.set(&"_x", world.geo.lane_x(p.lane))
			p.set(&"_switch_t", 1.0)
			p.h = head.pinned_crown(0.0, -0.3).y + 0.05
			p.vh = 0.0
			p.grounded = false
		if s["lifted"] and p.grounded and p.h > 1.0 and head.window_open:
			s["on_crown"] += 1
		if head.step == FloatingHead.Step.SHAKE:
			s["gap"] = head.pose.z
		if s["lifted"] and head.step == FloatingHead.Step.RELEASE and p.grounded and p.h < 0.05:
			s["fell"] = true
		return not p.alive or (head.step == FloatingHead.Step.RELEASE and s["fell"]), 60.0)
	var misses: Array[Dictionary] = _events(head, &"window_missed")
	check(int(s["on_crown"]) > 0, "a runner can land and run on its crown")
	check(not misses.is_empty() and misses[0]["why"] == &"passed" and _events(head, &"weak_point").is_empty(),
		"running past its weak points without a stomp closes the window (%s)" % cause[0])
	check(float(s["gap"]) > 0.5 and world.player.alive and s["fell"],
		"shaking free, its face pulls ahead of the runner (%.1f m), who drops off it onto the trucks unhurt" % float(s["gap"]))
	await sim.free_world(world)


# --- Damage ------------------------------------------------------------------------------------------

## GDD §10: "stomps do the real damage (a third of its health each); weapons chip away slowly (tuned so
## even the best weapon saves at most one stomp over the whole fight)". Weapons pour into it all fight
## long: they end at most one phase, and two stomps are still needed.
func _test_damage() -> void:
	var pair: Array = _fight(_def(), 5)
	var world: RunWorld = pair[0]
	var head: FloatingHead = pair[1]
	var bot := FloatingHeadBot.new(head, true)
	var cause: Array[String] = _watch_death(world)
	var s: Dictionary = {"shots": 0}
	await _until(world, func() -> bool:
		bot.step()
		if head.is_vulnerable() and head.body != null and is_instance_valid(head.body):
			head.body.take_damage(40.0, &"weapon")
			s["shots"] += 1
		return not world.player.alive or head.is_defeated() or _events(head, &"weak_point").size() >= 2, 240.0)
	var cap: float = head.max_health * head.def.weapon_share_cap
	check(head.weapon_damage <= cap + 0.01 and head.weapon_damage > cap - 1.0,
		"weapons deal up to the cap and no more (%.1f of %.1f)" % [head.weapon_damage, cap])
	var stomps: int = _events(head, &"weak_point").size()
	check(stomps >= 2 or not head.is_defeated(),
		"even with weapons at the cap it takes two stomps to beat it (%d stomps, %s) (%s)" % [stomps,
		"beaten" if head.is_defeated() else "not beaten", cause[0]])
	check(head.def.weapon_share_cap < 2.0 / 3.0 and head.def.weapon_share_cap <= 1.0 / 3.0 + 0.01,
		"its weapon cap saves at most one stomp (%.2f of its health)" % head.def.weapon_share_cap)
	await sim.free_world(world)


# --- Armor pickups -----------------------------------------------------------------------------------

## GDD §10's standard armor rule, with the Floating Head's 10-15 s: one armor pickup as the final phase
## starts, and one 10-15 s after an armor break (at most once a phase), from the framework's hook. None
## ever lies in a bomb's or a dropped cyborg's landing circle, nor where a pin and its way up go.
func _test_armor_pickups() -> void:
	# The free armor every run carries (GDD §4).
	var armored := Loadout.new()
	armored.armor = true
	var pair: Array = _fight(_def(true, true), 5, 1, armored)
	var world: RunWorld = pair[0]
	var head: FloatingHead = pair[1]
	var bot := FloatingHeadBot.new(head, true)
	# It runs straight into the first bomb (its armor takes it), then plays properly.
	bot.routes = true
	var cause: Array[String] = _watch_death(world)
	var s: Dictionary = {"broke": -1.0, "in_circle": 0, "in_pin": 0, "armor_hits": 0}
	world.player.item_used.connect(func(item: StringName) -> void:
		if item == &"armor":
			s["armor_hits"] += 1
			if float(s["broke"]) < 0.0:
				s["broke"] = head.fight_time())
	await _until(world, func() -> bool:
		if int(s["armor_hits"]) > 0 or not head.bombing.running:
			bot.step()
		for p: Pickup in world.pickups.active:
			if head.props.warned(p.lane, p.at - 0.5, p.at + 0.5):
				s["in_circle"] += 1
			if head.step == FloatingHead.Step.PINNED:
				var zone := Vector2(head.pin_stern - maxf(head.metres(head.tuning.ramp_length), head.before_face(head.tuning.pad_before_face) + 3.0),
					head.pin_stern + head.body.shape.length)
				if p.at > zone.x and p.at < zone.y:
					s["in_pin"] += 1
		return not world.player.alive or head.is_defeated(), 300.0)
	var offered: Array[Dictionary] = _events(head, &"pickup_offered")
	var dues: Array[Dictionary] = _events(head, &"armor_pickup")
	var broke: float = float(s["broke"])
	check(broke > 0.0, "its armor broke on a bomb (%s)" % cause[0])
	var after_break: Array[Dictionary] = []
	var final_phase: Array[Dictionary] = []
	for e: Dictionary in dues:
		if e["reason"] == &"protection_broken":
			after_break.append(e)
		elif e["reason"] == &"final_phase":
			final_phase.append(e)
	check(after_break.size() == 1 and float(after_break[0]["t"]) - broke >= head.def.armor_delay_min - 0.02
		and float(after_break[0]["t"]) - broke <= head.def.armor_delay_max + 0.02,
		"an armor pickup is due 10-15 s after the break (%.1f s)" % [float(after_break[0]["t"]) - broke if not after_break.is_empty() else -1.0])
	check(final_phase.size() == 1 and int(final_phase[0]["phase"]) == 2, "and one as the final phase starts")
	check(offered.size() == dues.size(), "each is offered on the track (%d of %d)" % [offered.size(), dues.size()])
	check(world.pickups.made >= 1, "and appears (%d)" % world.pickups.made)
	check(int(s["in_circle"]) == 0, "no pickup ever lies in a bomb's or a landing circle")
	check(int(s["in_pin"]) == 0, "nor where a pin and its way up go")
	check(head.is_defeated(), "and the runner beats it (%s)" % cause[0])
	await sim.free_world(world)


# --- The third window's ceiling ----------------------------------------------------------------------

## Its own ceiling keeps the ceiling rules: bombs never lock under it (FloatingHeadBombing.fair), the
## face-off waits until the runner is past it, and it never reaches into the ship's space (it lowers in
## behind the ship, and the ship stays ahead of it after a miss).
func _test_ceiling_rules() -> void:
	var pair: Array = _fight(_def(), 5, 2)
	var world: RunWorld = pair[0]
	var head: FloatingHead = pair[1]
	world.player.god_mode = true
	var bot := FloatingHeadBot.new(head, true)
	bot.wrong_route = true
	var s: Dictionary = {"overlap": 0, "lock_fair": true, "attacks": 0, "checked": false}
	await _until(world, func() -> bool:
		bot.step()
		if head.body == null or not is_instance_valid(head.body):
			return true
		if head.ceiling_between(head.ceiling_span.x, head.ceiling_span.y):
			var span: Vector2 = head.ceiling_span
			# The ship's hull: from its face (ahead of the runner by pose.z) back along its length.
			var face: float = world.player.distance + head.pose.z
			var top: float = head.body.global_position.y + head.body.shape.height * 1.1
			if face - 0.5 < span.y and face + head.body.shape.length > span.x and top > tuning.ceiling_height:
				s["overlap"] += 1
			if not s["checked"]:
				s["checked"] = true
				var lanes: Array[int] = [2]
				s["lock_fair"] = head.bombing.fair(lanes, 2, (span.x + span.y) * 0.5)
			if head.faceoff.step == FloatingHeadFaceOff.Step.CHARGE:
				s["attacks"] += 1
		return _events(head, &"released").size() >= 1 and world.player.distance > head.ceiling_span.y + 5.0, 90.0)
	check(s["checked"], "the third window's ceiling came in")
	check(not s["lock_fair"], "no bomb may lock under it")
	check(int(s["overlap"]) == 0, "it's never in the ship's space")
	check(int(s["attacks"]) == 0, "no laser warms up while it lies ahead of the runner")
	await sim.free_world(world)


# --- The whole fight ----------------------------------------------------------------------------------

## The whole fight in its preview, from the entrance to the last stomp, at every lane count: its real
## arena and numbers (bombing runs, face-offs, the marked towers), a runner who reads it (god mode and
## grapples for the arena's own holes and fences, which this runner doesn't read).
func _test_whole_fight() -> void:
	for lanes: int in LANES:
		var pair: Array = _fight(def, lanes)
		var world: RunWorld = pair[0]
		var head: FloatingHead = pair[1]
		var tag: String = "(%d lanes)" % lanes
		world.player.god_mode = true
		world.player.grapples = 1_000_000
		var bot := FloatingHeadBot.new(head, true)
		await _until(world, func() -> bool:
			bot.step()
			return head.is_defeated(), 400.0)
		var stomps: Array[Dictionary] = _events(head, &"stomp")
		var routes: Array[StringName] = []
		for e: Dictionary in stomps:
			routes.append(e["route"])
		check(head.is_defeated() and stomps.size() == 3 and routes == ROUTES,
			"from its entrance to the last stomp: up the ramp, a wall jump, off a ceiling (%s, %.0f s) %s" % [routes,
			head.fight_time(), tag])
		check(_events(head, &"enter").size() == 1 and _events(head, &"reveal").size() == 1
			and _events(head, &"run_start").size() == 1 + head.tuning.later_runs,
			"its entrance, the reveal and every bombing run come on the way %s" % tag)
		print("  Floating Head's whole fight %s: %.0f s, %d pins, %d windows missed" % [tag, head.fight_time(),
			_events(head, &"pinned").size(), _events(head, &"window_missed").size()])
		await sim.free_world(world)


## The whole fight on a plain street at every lane count: a runner who reads it is never touched by its
## bombs, lasers, burning lines or hull from the entrance to the last stomp. (God mode only for the
## cyborgs it drops: a panicking one's wild bolts are the cyborg's own business, test_cyborg.gd.)
func _test_plain_fight() -> void:
	var plain: BossDef = def.duplicate() as BossDef
	plain.arena = null
	for lanes: int in LANES:
		var pair: Array = _fight(plain, lanes)
		var world: RunWorld = pair[0]
		var head: FloatingHead = pair[1]
		world.player.god_mode = true
		var bot := FloatingHeadBot.new(head, true)
		var touches: Array[String] = []
		await _until(world, func() -> bool:
			bot.step()
			var hit: String = _touching_attack(head)
			if hit != "" and touches.size() < 4:
				touches.append("%s (%s) at %.1f s" % [hit, head.faceoff.attack.get("kind", &""), head.fight_time()])
			return head.is_defeated(), 400.0)
		check(head.is_defeated() and touches.is_empty(),
			"a runner who reads it beats the whole fight untouched by its attacks and its hull (%s) (%d lanes)" % [
			", ".join(touches), lanes])
		await sim.free_world(world)


## What of the Floating Head's own the runner's hurtbox touches now ("" if nothing): a bomb's blast, a
## laser or its burning line, or its hull while it's solid.
func _touching_attack(head: FloatingHead) -> String:
	var mine: Array[Hazard] = head.faceoff.laser_hazards() + head.bombing.blast_hazards()
	if head.body != null and is_instance_valid(head.body):
		for child: Node in head.body.find_children("*", "Hazard", true, false):
			var h := child as Hazard
			if h.part == &"body" and h.is_active():
				mine.append(h)
	if mine.is_empty():
		return ""
	var box: AABB = head.world.player.hurtbox_aabb()
	var shape := BoxShape3D.new()
	shape.size = box.size
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, box.get_center())
	q.collide_with_areas = true
	q.collide_with_bodies = false
	q.collision_mask = TrackBuilder.LAYER_HAZARD
	for hit: Dictionary in head.world.get_world_3d().direct_space_state.intersect_shape(q, 16):
		var h := hit["collider"] as Hazard
		if h != null and mine.has(h):
			return h.hazard_name
	return ""


## Two attempts with the same moves play out the same way.
func _test_same_every_attempt() -> void:
	var runs: Array[String] = []
	for attempt: int in 2:
		var pair: Array = _fight(_def(), 5)
		var world: RunWorld = pair[0]
		var head: FloatingHead = pair[1]
		var bot := FloatingHeadBot.new(head, true)
		await _until(world, func() -> bool:
			bot.step()
			return head.phase_index >= 2 or not world.player.alive, 120.0)
		var log: PackedStringArray = []
		for e: Dictionary in head.events:
			if e["event"] != &"sound":
				log.append("%s %.3f %s" % [e["event"], float(e["t"]), e])
		runs.append("\n".join(log))
		await sim.free_world(world)
	check(runs[0] == runs[1] and runs[0].contains("weak_point"), "every attempt plays out the same way")

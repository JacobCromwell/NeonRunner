extends TestSuite
## Mecha Guppy and Captain Cogs' climb on real physics (GDD §10; task E5e-b1; its data, plan and pieces:
## test_mecha_guppy.gd), at 3, 5 and 6 lanes, at the reference 18 m/s and the Beach's 23.8 m/s, without god mode:
## - a runner who reads the climb (MechaGuppyBot: the lanes that lead up read off the hut and the roofs, a lane switch
##   at a time) climbs through phases 1 and 2 without a fall, with hits landed as it climbs (a stand-in for E5e-b2's
##   bombs: one each time it lands on a higher roof), into phase 3's top, which ends the fight; phase 2's climb is
##   15-25% faster, measured;
## - the worst case, on physics: before every step's pads the runner goes to the lane farthest from the lanes that
##   lead up and jumps right before the pads (the latest anyone flips up), then reads only read_seconds after
##   settling on the hut: it still makes every step, with time to spare (the margin, measured);
## - a wrong drop is a fall: death; the grapple saves it up onto the higher roof, into a lane that leads up, and a
##   revive after the fall goes there too;
## - no escalation: through a long phase 1 with no hits the climb keeps the same rhythm; a retry plays the same;
## - the climbing camera over the climb: the runner on screen, the camera never inside a roof (each step's rise well
##   within RunCamera.FLOOR_REACH) and never snapping (its ease after a drop off a hut moves it 0.40 m on the first
##   frame at most); the runner's shadow on the roof under them.

const BOSS_PATH: String = "res://data/bosses/beach_boss.tres"
const LANES: Array[int] = [3, 5, 6]
const SPEEDS: Array[float] = [18.0, 23.8]
## A player's reaction (the suites' bots' usual 0.35 s).
const REACTION: float = 0.35

var sim: RunSim
var def: BossDef


func run() -> void:
	sim = RunSim.new(tree, tuning)
	var slot := load(BOSS_PATH) as BossDef
	def = slot.preview() if slot != null else null
	if def == null:
		check(false, "Mecha Guppy and Captain Cogs' fight loads")
		return
	await _test_climb_through()
	await _test_worst_case()
	await _test_wrong_drops()
	await _test_rhythm_and_retry()
	await _test_camera()


# --- Helpers -------------------------------------------------------------------------------

func _movement(speed: float) -> MovementTuning:
	if is_equal_approx(speed, tuning.run_speed):
		return tuning
	var t: MovementTuning = tuning.duplicate() as MovementTuning
	t.run_speed = speed
	return t


## The fight at `lanes` and `speed` m/s (with `p_def`, the slot's preview by default): [world, boss].
func _fight(lanes: int, speed: float, p_def: BossDef = null) -> Array:
	var d: BossDef = p_def if p_def != null else def
	var t: MovementTuning = _movement(speed)
	var boss := BossEncounter.create(d) as MechaGuppy
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = d
	ctx.config = BossArena.base_config(d)
	ctx.config.lane_count = lanes
	ctx.tuning = t
	var arena: BossArena = boss.plan_arena(ctx)
	var world: RunWorld = sim.build_world(arena.layout, null, t, ctx.config)
	boss.setup(world, ctx, arena)
	return [world, boss]


func _def_with(edit: Callable) -> BossDef:
	var out: BossDef = def.duplicate() as BossDef
	var t: MechaGuppyTuning = (def.tuning as MechaGuppyTuning).duplicate() as MechaGuppyTuning
	edit.call(t)
	out.tuning = t
	return out


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


# --- Through phases 1 and 2 -------------------------------------------------------------------

## A runner who reads the climb climbs through phases 1 and 2, a hit landing each time it reaches a higher roof
## (E5e-b2's bombs stand-in), into phase 3's top, which ends the fight, without a fall, at every lane count and both
## speeds. Then phase 2's faster climb, measured: eight steps planned in each phase, landing to landing.
func _test_climb_through() -> void:
	var quick: BossDef = _def_with(func(t: MechaGuppyTuning) -> void: t.top_seconds = 8.0)
	for speed: float in SPEEDS:
		for lanes: int in LANES:
			var tag: String = "(%d lanes, %.1f m/s)" % [lanes, speed]
			var pair: Array = _fight(lanes, speed, quick)
			var world: RunWorld = pair[0]
			var boss: MechaGuppy = pair[1]
			var p: Player = world.player
			var bot := MechaGuppyBot.new(boss)
			bot.reaction = REACTION
			var cause: Array[String] = [""]
			p.died.connect(func(c: String) -> void: cause[0] = c)
			var state: Dictionary = {"climbed": 0}
			await _run(world, 240.0, func() -> bool: return boss.is_defeated(), func() -> void:
				bot.step()
				if bot.steps_climbed > int(state["climbed"]):
					state["climbed"] = bot.steps_climbed
					boss.register_hit(&"stand_in"))
			check(boss.is_defeated() and p.alive, "a runner who reads the climb makes it through phases 1 and 2 and phase 3's top %s%s"
				% [tag, "" if p.alive else ": %s at %.0f m, %.1f s" % [cause[0], p.distance, boss.fight_time()]])
			check(bot.min_slack >= REACTION, "with time to spare on every hut (at least %.2f s) %s" % [bot.min_slack, tag])
			var ends: Array[Dictionary] = _events(boss, &"phase_end")
			check(ends.size() == 2 and _events(boss, &"hit").size() == 10 and not _events(boss, &"top_over").is_empty(),
				"4 hits end phase 1, 6 more phase 2, and phase 3's top runs out (%d phase ends, %d hits; phases end at %s s) %s"
				% [ends.size(), _events(boss, &"hit").size(), ends.map(func(e: Dictionary) -> String: return "%.1f" % float(e["t"])), tag])
			await sim.free_world(world)
			check(await _phase_rates(lanes, speed), "phase 2's climb is faster as planned %s" % tag)


## Phase 2's climb against phase 1's, on physics: eight steps planned in phase 1, landing to landing, then four hits
## (phase 2), then eight steps planned in phase 2. GDD §10: 15-25% faster (proposed: about 20%). True if it is.
func _phase_rates(lanes: int, speed: float) -> bool:
	var tag: String = "(%d lanes, %.1f m/s)" % [lanes, speed]
	var pair: Array = _fight(lanes, speed)
	var world: RunWorld = pair[0]
	var boss: MechaGuppy = pair[1]
	var p: Player = world.player
	var bot := MechaGuppyBot.new(boss)
	bot.reaction = REACTION
	# Landings by the phase their step was planned in: [[t, height], ...].
	var by_phase: Array = [[], []]
	var state: Dictionary = {"climbed": 0}
	await _run(world, 200.0, func() -> bool: return (by_phase[1] as Array).size() >= 9, func() -> void:
		bot.step()
		if bot.steps_climbed > int(state["climbed"]):
			state["climbed"] = bot.steps_climbed
			var s: MechaGuppyClimb.Step = boss.climb.step_at(p.distance - 15.0)
			if s != null and s.phase <= 1 and s.index >= 1:
				(by_phase[s.phase] as Array).append([boss.fight_time(), p.floor_y])
			# Phase 1's eight steps landed: four hits, phase 2.
			if (by_phase[0] as Array).size() == 9 and boss.phase_index == 0:
				for i: int in 4:
					boss.register_hit(&"stand_in"))
	var rate: Array[float] = [0.0, 0.0]
	for ph: int in 2:
		var list: Array = by_phase[ph]
		if list.size() >= 9:
			var a: Array = list[0]
			var b: Array = list[8]
			rate[ph] = (float(b[1]) - float(a[1])) / maxf(float(b[0]) - float(a[0]), 0.001)
	var faster: float = rate[1] / maxf(rate[0], 0.001) - 1.0
	var ok: bool = p.alive and faster >= 0.15 and faster <= 0.25
	check(ok, "GDD §10: phase 2 climbs %.1f%% faster on physics (%.3f against %.3f m/s over eight steps each) %s"
		% [faster * 100.0, rate[1], rate[0], tag])
	await sim.free_world(world)
	return ok


# --- The worst case ---------------------------------------------------------------------------

## The fairness margin on physics: the runner takes every step from the lane farthest from its lanes that lead up,
## flips up as late as anyone can (a jump right before the pads), and reads only read_seconds after settling: it
## makes every step, the measured time to spare never below zero.
func _test_worst_case() -> void:
	var t := def.tuning as MechaGuppyTuning
	for speed: float in SPEEDS:
		for lanes: int in LANES:
			var tag: String = "(%d lanes, %.1f m/s)" % [lanes, speed]
			var pair: Array = _fight(lanes, speed)
			var world: RunWorld = pair[0]
			var boss: MechaGuppy = pair[1]
			var bot := MechaGuppyBot.new(boss)
			bot.worst_case = true
			bot.reaction = t.read_seconds
			await _run(world, 50.0, func() -> bool: return false, bot.step)
			check(world.player.alive and bot.steps_climbed >= 7,
				"from the farthest lane, flipping up as late as anyone can and reading %.1f s after settling, it makes every step (%d) %s"
				% [t.read_seconds, bot.steps_climbed, tag])
			var most: int = 0
			for r: Dictionary in bot.reads:
				var up: Array = r["lanes"]
				if not up.is_empty():
					most = maxi(most, maxi(int(up[0]), lanes - 1 - int(up[-1])))
			check(bot.min_slack >= 0.0, "with time to spare at the last moment (%.3f s; up to %d switches on one hut) %s"
				% [bot.min_slack, most, tag])
			await sim.free_world(world)


# --- Wrong drops, the grapple, a revive ------------------------------------------------------

## A drop off the first hut in a lane that doesn't lead up falls into the floor Mecha Guppy has eaten: death. With
## a grapple, the save pulls the runner up onto the higher roof into a lane that leads up (GDD §10, proposed), and
## they climb on; a revive after the fall goes there too.
func _test_wrong_drops() -> void:
	for lanes: int in LANES:
		for mode: String in ["fall", "grapple", "revive"]:
			var tag: String = "(%d lanes, %s)" % [lanes, mode]
			var pair: Array = _fight(lanes, 23.8)
			var world: RunWorld = pair[0]
			var boss: MechaGuppy = pair[1]
			var p: Player = world.player
			var bot := MechaGuppyBot.new(boss)
			bot.wrong = true
			p.grapples = 1 if mode == "grapple" else 0
			var s: MechaGuppyClimb.Step = boss.climb.steps[0]
			var roof: MechaGuppyClimb.Roof = boss.climb.roofs[1]
			var cause: Array[String] = [""]
			p.died.connect(func(c: String) -> void: cause[0] = c)
			var used: Array[StringName] = []
			p.item_used.connect(func(item: StringName) -> void: used.append(item))
			await _run(world, 12.0, func() -> bool: return p.distance > s.deadline + 2.0 and p.surface == Player.Surface.FLOOR, bot.step)
			var dropped_lane: int = p.lane
			check(not s.leads_up(dropped_lane), "it drops in a lane that doesn't lead up (lane %d; up %s) %s" % [dropped_lane, s.up, tag])
			if mode == "grapple":
				await _run(world, 3.0, func() -> bool: return p.grounded and p.surface == Player.Surface.FLOOR)
				check(p.alive and used.has(&"grapple") and absf(p.floor_y - roof.top) < 0.01 and s.leads_up(p.lane)
					and p.lane == s.nearest_up(dropped_lane),
					"the grapple pulls them up onto the higher roof, into its nearest lane that leads up (lane %d, on %.1f m) %s"
					% [p.lane, p.floor_y, tag])
				check(not _events(boss, &"save").is_empty(), "the boss's hook answered the save %s" % tag)
				bot.wrong = false
				await _run(world, 12.0, func() -> bool: return bot.steps_climbed >= 3, bot.step)
				check(p.alive and bot.steps_climbed >= 2, "and they climb on (%d roofs) %s" % [bot.steps_climbed, tag])
			else:
				await _run(world, 3.0, func() -> bool: return false)
				check(not p.alive and cause[0] == "fell", "a wrong drop falls into the eaten floor: death (%s) %s" % [cause[0], tag])
				if mode == "revive":
					p.revive()
					await _run(world, 3.0, func() -> bool: return p.grounded and p.surface == Player.Surface.FLOOR)
					check(p.alive and absf(p.floor_y - roof.top) < 0.01 and s.leads_up(p.lane),
						"a revive after the fall goes where the grapple would: onto the higher roof, in a lane that leads up (lane %d) %s"
						% [p.lane, tag])
			await sim.free_world(world)


# --- No escalation, a retry -------------------------------------------------------------------

## GDD §10: no escalation. Through a long phase 1 with no hits the climb keeps its rhythm (the time between landings
## for steps alike, early and late, the same to a frame); and a retry plays the same (the same lanes, at the same
## moments).
func _test_rhythm_and_retry() -> void:
	var logs: Array[String] = []
	for attempt: int in 2:
		var pair: Array = _fight(5, 23.8)
		var world: RunWorld = pair[0]
		var boss: MechaGuppy = pair[1]
		var bot := MechaGuppyBot.new(boss)
		bot.reaction = REACTION
		var landings: PackedFloat32Array = PackedFloat32Array()
		var state: Dictionary = {"climbed": 0}
		await _run(world, 130.0, func() -> bool: return false, func() -> void:
			bot.step()
			if bot.steps_climbed > int(state["climbed"]):
				state["climbed"] = bot.steps_climbed
				landings.append(boss.fight_time()))
		check(world.player.alive and boss.phase_index == 0 and landings.size() >= 20,
			"a long phase 1 with no hits: the climb goes on (%d roofs, %.0f m up) (attempt %d)" % [landings.size(), world.player.floor_y,
				attempt + 1])
		# Steps six apart are alike (the cue and the count cycle with periods 2 and 3).
		var same: bool = landings.size() >= 20
		for i: int in range(8, landings.size() - 1):
			var late: float = landings[i + 1] - landings[i]
			var early: float = landings[i + 1 - 6] - landings[i - 6]
			same = same and absf(late - early) <= 0.05
		check(same, "no escalation: a late step takes as long as the early step like it")
		var lines: PackedStringArray = []
		for r: Dictionary in bot.reads:
			lines.append("%d:%s" % [int(r["step"]), r["lanes"]])
		for l: float in landings:
			lines.append("%.3f" % l)
		logs.append(";".join(lines))
		await sim.free_world(world)
	check(logs[0] == logs[1] and logs[0] != "", "a retry plays the same: the same lanes lead up, the same landings")


# --- The climbing camera ------------------------------------------------------------------------

## The run camera over the climb (RunWorld.camera_climbs, on for the fight): the runner on screen all the way up, the
## camera never inside a roof (each step's rise is well within RunCamera.FLOOR_REACH, so it sees every roof it must
## clear) and never more than 0.4 m from where it was a frame before; the runner's shadow on the roof under them.
func _test_camera() -> void:
	for lanes: int in [3, 6]:
		var tag: String = "(%d lanes)" % lanes
		var pair: Array = _fight(lanes, 23.8)
		var world: RunWorld = pair[0]
		var boss: MechaGuppy = pair[1]
		var p: Player = world.player
		world.effects.shake_scale = 0.0
		var camera := RunCamera.new()
		tree.root.add_child(camera)
		camera.follow(world)
		var bot := MechaGuppyBot.new(boss)
		var shadow := p.get(&"_shadow") as MeshInstance3D
		var out: Dictionary = {"off": 0, "in_roof": 0, "step": 0.0, "shadow_bad": 0, "shadow_ok": 0, "last": NAN, "top": 0.0}
		var rect := Rect2(Vector2.ZERO, camera.get_viewport().get_visible_rect().size)
		world.start()
		for i: int in int(45.0 * Engine.physics_ticks_per_second):
			bot.step()
			await tree.physics_frame
			await tree.process_frame
			if not p.alive:
				break
			var cam: Vector3 = camera.global_position
			var head: Vector3 = p.position + Vector3(0.0, -1.2 if p.surface == Player.Surface.CEILING else 1.2, 0.0)
			for point: Vector3 in [p.position, head]:
				if camera.is_position_behind(point) or not rect.has_point(camera.unproject_position(point)):
					out["off"] = int(out["off"]) + 1
			if _in_roof(boss.climb, world, cam):
				out["in_roof"] = int(out["in_roof"]) + 1
			if not is_nan(float(out["last"])):
				out["step"] = maxf(float(out["step"]), absf(cam.y - float(out["last"])))
			out["last"] = cam.y
			out["top"] = maxf(float(out["top"]), p.floor_y)
			if p.surface == Player.Surface.FLOOR and p.grounded and p.floor_y > 0.5:
				if shadow.visible and absf(shadow.global_position.y - (p.floor_y + 0.02)) < 0.01:
					out["shadow_ok"] = int(out["shadow_ok"]) + 1
				else:
					out["shadow_bad"] = int(out["shadow_bad"]) + 1
		check(p.alive and float(out["top"]) >= 15.0, "the runner climbs to %.0f m %s" % [out["top"], tag])
		check(int(out["off"]) == 0, "the climbing camera keeps the runner on screen all the way up (%d frames off) %s" % [out["off"], tag])
		check(int(out["in_roof"]) == 0, "the camera is never inside a roof (%d frames) %s" % [out["in_roof"], tag])
		# The largest step is the camera's own ease (RunCamera, camera_smoothing) from the view under a hut to the usual
		# framing as the rider drops off its end: about 3.1 m of change in its aim, 0.40 m on the first frame.
		check(float(out["step"]) < 0.45, "and never snaps (at most %.3f m a frame) %s" % [out["step"], tag])
		check(int(out["shadow_bad"]) == 0 and int(out["shadow_ok"]) > 60,
			"the runner's shadow lies on the roof under them (%d frames right, %d wrong) %s" % [out["shadow_ok"], out["shadow_bad"], tag])
		camera.queue_free()
		await sim.free_world(world)


## True if world point `pos` is inside one of the climb's roofs as built (its top over its lanes, down to the street,
## from its lane starts to its eaten edge).
static func _in_roof(climb: MechaGuppyClimb, world: RunWorld, pos: Vector3) -> bool:
	var d: float = -pos.z
	for r: MechaGuppyClimb.Roof in climb.roofs:
		if r.index == 0:
			continue
		if pos.y >= r.top or pos.y < 0.0:
			continue
		for lane: int in world.geo.lane_count:
			var span: Vector2 = world.geo.lane_floor_span(lane)
			if pos.x >= span.x and pos.x <= span.y and r.covers(lane, d):
				return true
	return false

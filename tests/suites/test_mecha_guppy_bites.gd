extends TestSuite
## Mecha Guppy's bites and breaches (GDD §10: "Its maw comes up through the floor and eats a huge chunk of the level";
## "it eats the floors the runner should have left and the floor under the lanes that don't lead up, never the floor
## the runner is on or the safe place to drop to"; task E5e-b2; the bombs and the hits: test_mecha_guppy_bombs.gd), on
## real physics, at 3 lanes at 23.8 m/s and 6 lanes at 18 m/s, in phases 1 and 2 (MechaGuppyBot climbing):
## - each step's bite eats the end of the roof the runner has just left: warned first (the rumble and the shark rising
##   beside it, at least bite_warning before its jaws come up), it bites only once the runner is up on that roof's hut
##   (never the floor they're on) and only that roof (never the higher one, the safe drop); the roof's collision and
##   its look end at the cut (rays down find no floor past it and the roof's top before it; the builder's pieces reach
##   no further), its pads too; every step's roof is bitten (the shark waits for itself in phase 2's closer steps);
## - a bite's jaws never come within MechaGuppyShark.BITE_CLEAR of a rider hanging from the hut, even mid-jump, anywhere
##   over the track;
## - a breach comes only once the hut's deadline is past (every rider committed: it never tells which lanes lead up),
##   with the rider in a lane that leads up; its jaws are never over a lane that leads up above the floor's level; it
##   lurks deep under the chasm's middle, facing the runner, whichever side it will come up on; each is warned by the
##   rumble;
## - a retry bites the same.

const BOSS_PATH: String = "res://data/bosses/beach_boss.tres"
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
	for phase: int in 2:
		await _test_shark(3, 23.8, phase)
		await _test_shark(6, 18.0, phase)
	# The latest anyone flips up: a jump and the dash right before the pads, from the lane farthest from those that
	# lead up (MechaGuppyBot.worst_case): the bite still waits for them to be on the hut.
	await _test_shark(3, 23.8, 0, true)
	await _test_shark(5, 18.0, 1, true)
	await _test_retry()


# --- Helpers -------------------------------------------------------------------------------

func _movement(speed: float) -> MovementTuning:
	if is_equal_approx(speed, tuning.run_speed):
		return tuning
	var t: MovementTuning = tuning.duplicate() as MovementTuning
	t.run_speed = speed
	return t


## The fight at `lanes` and `speed` m/s from phase index `phase` (a resume), its attacks on (with the dash power-up at
## its best tier with `dash`): [world, boss].
func _fight(lanes: int, speed: float, phase: int = 0, dash: bool = false) -> Array:
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
	var loadout: Loadout = null
	if dash:
		loadout = Loadout.new()
		loadout.tiers[&"dash"] = 4
	var world: RunWorld = sim.build_world(arena.layout, loadout, t, ctx.config)
	boss.setup(world, ctx, arena)
	return [world, boss]


func _events(boss: BossEncounter, event: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in boss.events:
		if e["event"] == event:
			out.append(e)
	return out


func _sounds(boss: BossEncounter, sound: StringName) -> int:
	var n: int = 0
	for e: Dictionary in boss.events:
		if e["event"] == &"sound" and e["name"] == sound:
			n += 1
	return n


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


## The step whose hut the runner is on (or last left), by where they are: the last with its hut started.
func _step_of(climb: MechaGuppyClimb, d: float) -> MechaGuppyClimb.Step:
	var out: MechaGuppyClimb.Step = null
	for s: MechaGuppyClimb.Step in climb.steps:
		if not s.top and s.hut_start <= d:
			out = s
	return out


## The floor's top under (x, z) between `top + 1` and `top - 2` (world y), or NAN with none there.
func _floor_hit(world: RunWorld, x: float, z: float, top: float) -> float:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, top + 1.0, z), Vector3(x, top - 2.0, z), TrackBuilder.LAYER_FLOOR)
	q.collide_with_areas = false
	var hit: Dictionary = space.intersect_ray(q)
	return float((hit["position"] as Vector3).y) if not hit.is_empty() else NAN


# --- The shark ------------------------------------------------------------------------------------

func _test_shark(lanes: int, speed: float, phase: int, late: bool = false) -> void:
	var tag: String = "(%d lanes, %.1f m/s, phase %d%s)" % [lanes, speed, phase + 1, ", the latest flips" if late else ""]
	var pair: Array = _fight(lanes, speed, phase, late)
	var world: RunWorld = pair[0]
	var boss: MechaGuppy = pair[1]
	var p: Player = world.player
	var climb: MechaGuppyClimb = boss.climb
	var shark: MechaGuppyShark = boss.shark
	var mt: MechaGuppyTuning = boss.tuning
	var bot := MechaGuppyBot.new(boss)
	bot.reaction = REACTION
	if late:
		bot.worst_case = true
		bot.dash_flip = true
		bot.reaction = mt.read_seconds
	var cause: Array[String] = [""]
	p.died.connect(func(c: String) -> void: cause[0] = c)
	var wall: float = world.geo.wall_x()
	var problems: Array[String] = []
	# The closest a bite's jaws came to a rider's lowest point under the hut, the highest a breach's came over a lane
	# that leads up (from the floor's level), the lurk's widest x and turn.
	var state: Dictionary = {"clear": INF, "over": -INF, "lurk_x": 0.0, "lurk_yaw": 0.0, "lurked": 0, "seen": 0,
		"warned": {}, "cuts": [], "stage": MechaGuppyShark.Stage.IDLE, "dives": 0}
	var to_climb: int = 4
	await _run(world, 70.0, func() -> bool: return bot.steps_climbed >= to_climb, func() -> void:
		bot.step()
		var a: Dictionary = shark.action
		# A bite's jaws come up only once the runner is up on that roof's hut (they leave its watch: the dive).
		if shark.stage == MechaGuppyShark.Stage.DIVING and int(state["stage"]) != MechaGuppyShark.Stage.DIVING:
			state["dives"] = int(state["dives"]) + 1
			var r: int = int(a.get("roof", -1))
			if p.alive and (p.surface != Player.Surface.CEILING or r < 0 or p.distance < climb.steps[r].pad - 0.5):
				problems.append("roof %d's bite came up with the runner %s at %.0f m" % [r, p.surface_name(), p.distance])
		state["stage"] = shark.stage
		if not a.is_empty() and shark.shown():
			if int(a["kind"]) == MechaGuppyShark.Kind.BITE:
				var roof_index: int = int(a.get("roof", -1))
				if roof_index >= 0 and roof_index < climb.steps.size():
					# A rider's lowest reach under the hut: mid-jump, their head (the avatar) at the jump's foot.
					var lowest: float = climb.steps[roof_index].hut_y - tuning.jump_height - tuning.visual_size.y
					var top_y: float = shark.jaws_over(-wall, wall)
					if top_y > -INF:
						state["clear"] = minf(float(state["clear"]), lowest - top_y)
			else:
				var k: int = int(a.get("step", -1))
				if k >= 0 and shark.stage != MechaGuppyShark.Stage.LURKING:
					var st: MechaGuppyClimb.Step = climb.steps[k]
					var x0: float = world.geo.lane_x(st.up.x) - world.geo.lane_width * 0.5
					var x1: float = world.geo.lane_x(st.up.y) + world.geo.lane_width * 0.5
					state["over"] = maxf(float(state["over"]), shark.jaws_over(x0, x1) - float(a["top"]))
			if shark.stage == MechaGuppyShark.Stage.LURKING:
				state["lurked"] = int(state["lurked"]) + 1
				state["lurk_x"] = maxf(float(state["lurk_x"]), absf(shark.hinge.x))
				state["lurk_yaw"] = maxf(float(state["lurk_yaw"]), absf(wrapf(shark.yaw, -PI, PI)))
		# The events as they come.
		while int(state["seen"]) < boss.events.size():
			var e: Dictionary = boss.events[int(state["seen"])]
			state["seen"] = int(state["seen"]) + 1
			match e["event"]:
				&"bite_warning":
					(state["warned"] as Dictionary)[int(e["roof"])] = float(e["t"])
				&"bite":
					var r: int = int(e["roof"])
					var on: MechaGuppyClimb.Step = _step_of(climb, p.distance)
					if p.alive and (p.surface != Player.Surface.CEILING or on == null or on.index != r):
						problems.append("roof %d bitten with the runner %s at %.0f m" % [r, p.surface_name(), p.distance])
					var warned: float = float((state["warned"] as Dictionary).get(r, INF))
					var least: float = mt.bite_warning + mt.bite_dive + mt.bite_rise + mt.bite_hold + mt.bite_snap
					if float(e["t"]) - warned < least - 0.05:
						problems.append("roof %d bitten %.2f s after its warning" % [r, float(e["t"]) - warned])
				&"roof_eaten":
					(state["cuts"] as Array).append({"roof": int(e["roof"]), "cut": float(e["cut"]), "end": float(e["end"]),
						"frames": 0})
				&"breach_warning":
					var k: int = int(shark.action.get("step", -1))
					var st: MechaGuppyClimb.Step = climb.steps[k] if k >= 0 else null
					if st == null or p.distance < st.deadline - 0.01 or not st.leads_up(p.lane):
						problems.append("a breach at %.0f m with the runner at %.0f m in lane %d (the deadline %.0f m)"
							% [float(e["at"]), p.distance, p.lane, st.deadline if st != null else NAN])
		# Two frames after each roof is eaten (the freed pieces gone from the physics), its collision and look.
		for c: Dictionary in state["cuts"]:
			c["frames"] = int(c["frames"]) + 1
			if int(c["frames"]) != 3:
				continue
			var r: int = int(c["roof"])
			var top: float = climb.roofs[r].top
			var cut: float = float(c["cut"])
			for lane: int in world.geo.lane_count:
				var x: float = world.geo.lane_x(lane)
				if not is_nan(_floor_hit(world, x, TrackGeometry.world_z(cut + 0.6), top)) \
						or not is_nan(_floor_hit(world, x, TrackGeometry.world_z((cut + float(c["end"])) * 0.5), top)):
					problems.append("roof %d still has floor past its cut in lane %d" % [r, lane])
				# Before the cut it's still there (while the props keep what the runner has passed: BossProps.KEEP_BEHIND).
				if p.distance > cut + BossProps.KEEP_BEHIND - 2.0:
					continue
				var before: float = _floor_hit(world, x, TrackGeometry.world_z(cut - 0.6), top)
				if is_nan(before) or absf(before - top) > 0.05:
					problems.append("roof %d lost its floor before its cut in lane %d" % [r, lane])
			if boss.stairs.roof_reach(r) > cut + 0.01:
				problems.append("roof %d's pieces reach %.1f m past its cut" % [r, boss.stairs.roof_reach(r) - cut]))
	check(p.alive and bot.steps_climbed >= to_climb, "the runner climbs %d steps %s%s" % [to_climb, tag,
		"" if p.alive else ": %s at %.0f m" % [cause[0], p.distance]])
	var bites: Array[Dictionary] = _events(boss, &"bite")
	var eaten: Array[Dictionary] = _events(boss, &"roof_eaten")
	check(bites.size() >= to_climb and eaten.size() == bites.size() and int(state["dives"]) == bites.size()
		and _events(boss, &"bite_skipped").is_empty(),
		"every step's roof is bitten once the runner has left it (%d bites, %d roofs eaten) %s" % [bites.size(), eaten.size(), tag])
	check(problems.is_empty(), "never the floor the runner is on nor the safe drop, warned first, collision and look ending at the cut; breaches only past the deadline (%d bites) %s%s"
		% [bites.size(), tag, "" if problems.is_empty() else ": " + "; ".join(problems.slice(0, 3))])
	check(float(state["clear"]) >= MechaGuppyShark.BITE_CLEAR,
		"a bite's jaws keep at least %.1f m under a rider hanging from the hut, even mid-jump (%.2f m at the closest) %s"
		% [MechaGuppyShark.BITE_CLEAR, float(state["clear"]), tag])
	var breaches: int = _events(boss, &"breach_warning").size()
	check(breaches >= to_climb - 1 and float(state["over"]) <= 0.01,
		"a breach's jaws are never over a lane that leads up above the floor's level (%d breaches, highest %.2f m) %s"
		% [breaches, float(state["over"]), tag])
	check(int(state["lurked"]) > 0 and float(state["lurk_x"]) < 0.01 and float(state["lurk_yaw"]) < 0.01,
		"it lurks under the chasm's middle facing the runner, giving nothing away (x %.2f m, turned %.2f rad) %s"
		% [float(state["lurk_x"]), float(state["lurk_yaw"]), tag])
	var warnings: int = _events(boss, &"bite_warning").size() + breaches
	check(_sounds(boss, &"guppy_rumble") == warnings and _sounds(boss, &"guppy_bite") >= bites.size(),
		"each bite and breach is warned by its rumble, each bite heard (%d rumbles for %d) %s"
		% [_sounds(boss, &"guppy_rumble"), warnings, tag])
	print("  Mecha Guppy %s: %d bites, %d breaches; its jaws %.2f m under a rider at the closest"
		% [tag, bites.size(), breaches, float(state["clear"])])
	await sim.free_world(world)


## Two attempts with the same inputs bite the same.
func _test_retry() -> void:
	var runs: Array[String] = []
	for attempt: int in 2:
		var pair: Array = _fight(3, 18.0)
		var world: RunWorld = pair[0]
		var boss: MechaGuppy = pair[1]
		var bot := MechaGuppyBot.new(boss)
		bot.reaction = REACTION
		await _run(world, 30.0, func() -> bool: return bot.steps_climbed >= 2, bot.step)
		var log: PackedStringArray = []
		for e: Dictionary in boss.events:
			if e["event"] in [&"bite_warning", &"bite", &"roof_eaten", &"breach_warning", &"breach_snap"]:
				log.append("%.3f %s" % [float(e["t"]), str(e)])
		runs.append("\n".join(log))
		await sim.free_world(world)
	check(runs[0] == runs[1] and runs[0].length() > 0, "every attempt bites the same")

extends TestSuite
## Mecha Guppy's bites and breaches (GDD §10: "Its maw comes up through the floor and eats a huge chunk of the level";
## "it eats the floors the runner should have left and the floor under the lanes that don't lead up, never the floor
## the runner is on or the safe place to drop to"; task E5e-b2; the bombs and the hits: test_mecha_guppy_bombs.gd), on
## real physics, at 3 lanes at 23.8 m/s and 6 lanes at 18 m/s, in phases 1 and 2 (MechaGuppyBot climbing, baiting the
## bombs or not):
## - each step's bite eats the end of the roof the runner has just left: warned first (the rumble and the shark rising
##   beside it, at least bite_warning before its jaws come up), it bites only once the runner is up on that roof's hut
##   (never the floor they're on) and only that roof (never the higher one, the safe drop); the roof's collision and
##   its look end at the cut (rays down find no floor past it and the roof's top before it; the builder's pieces reach
##   no further), its pads too; every step's roof is bitten (the shark waits for itself when it's still busy);
## - a bite's jaws never come within MechaGuppyShark.BITE_CLEAR of a rider hanging from the hut, even mid-jump, anywhere
##   over the track;
## - its catch beside a roof's notch (the bait, task E5e-b3: a runner who baits): warned by the rumble, it comes up as
##   the bait begins, and while it waits there (open, shutting, shut) no part of its jaws is ever over a lane a runner
##   may use (any lane but the notch's) nor over the notch's lane before the notch starts, at any height;
## - a breach (the fallback, a runner who doesn't bait: once fallback_after steps in a row went by without a hit) comes
##   only once the hut's deadline is past (every rider committed: it never tells which lanes lead up), with the rider in
##   a lane that leads up; its jaws are never over a lane that leads up above the floor's level; while it lurks before
##   one nothing of it shows; each is warned by the rumble;
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
		await _test_shark(3, 23.8, phase, true)
		await _test_shark(6, 18.0, phase, true)
		await _test_shark(3, 23.8, phase, false)
		await _test_shark(6, 18.0, phase, false)
	# The latest anyone flips up: a jump and the dash right before the pads, from the lane farthest from those that
	# lead up (MechaGuppyBot.worst_case): the bite still waits for them to be on the hut.
	await _test_shark(3, 23.8, 0, false, true)
	await _test_shark(5, 18.0, 1, false, true)
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

func _test_shark(lanes: int, speed: float, phase: int, baits: bool, late: bool = false) -> void:
	var tag: String = "(%d lanes, %.1f m/s, phase %d, %s%s)" % [lanes, speed, phase + 1, "baiting" if baits else "not baiting",
		", the latest flips" if late else ""]
	var pair: Array = _fight(lanes, speed, phase, late)
	var world: RunWorld = pair[0]
	var boss: MechaGuppy = pair[1]
	var p: Player = world.player
	var climb: MechaGuppyClimb = boss.climb
	var shark: MechaGuppyShark = boss.shark
	var mt: MechaGuppyTuning = boss.tuning
	var bot := MechaGuppyBot.new(boss)
	bot.reaction = REACTION
	bot.baits = baits
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
	var state: Dictionary = {"clear": INF, "over": -INF, "lurk_shown": 0, "lurked": 0, "seen": 0, "warned": {}, "cuts": [],
		"stage": MechaGuppyShark.Stage.IDLE, "dives": 0, "catch_frames": 0, "intrusions": []}
	# A runner who doesn't bait lands a hit only by the fallback, every fallback_after + 1 steps: enough steps for two.
	var to_climb: int = 4 if baits else 2 * (mt.fallback_after + 1) + 1
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
		if shark.stage == MechaGuppyShark.Stage.LURKING:
			state["lurked"] = int(state["lurked"]) + 1
			if shark.shown():
				state["lurk_shown"] = int(state["lurk_shown"]) + 1
		# Its catch beside a notch: no part of its jaws over a lane a runner may use, nor over the notch's lane before
		# the notch starts.
		var catching: bool = shark.stage in [MechaGuppyShark.Stage.CATCHING, MechaGuppyShark.Stage.SHUTTING] \
			or (shark.stage == MechaGuppyShark.Stage.WAITING and not (a.get("catch", {}) as Dictionary).is_empty()) \
			or (shark.stage == MechaGuppyShark.Stage.RISING and not (a.get("catch", {}) as Dictionary).is_empty())
		if catching and shark.shown():
			state["catch_frames"] = int(state["catch_frames"]) + 1
			var why: String = _catch_intrusion(world, climb.roofs[int(a.get("roof", 0))], shark)
			if why != "" and (state["intrusions"] as Array).size() < 3:
				(state["intrusions"] as Array).append(why)
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
				# Before the cut it's still there (while the props keep what the runner has passed: BossProps.KEEP_BEHIND),
				# in every lane but the bait's notch's (eaten before).
				if p.distance > cut + BossProps.KEEP_BEHIND - 2.0 or not climb.roofs[r].covers(lane, cut - 0.6):
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
	var catches: int = _events(boss, &"catch_open").size()
	if baits:
		check(catches >= to_climb - 1 and breaches == 0 and int(state["catch_frames"]) > 0 and (state["intrusions"] as Array).is_empty(),
			"its catch beside each notch: no part of its jaws over a lane a runner may use, nor over the notch's lane before the notch (%d catches, %d breaches) %s%s"
			% [catches, breaches, tag, "" if (state["intrusions"] as Array).is_empty() else ": " + "; ".join(state["intrusions"])])
	else:
		check(breaches >= 2 and float(state["over"]) <= 0.01,
			"a breach's jaws are never over a lane that leads up above the floor's level (%d breaches, highest %.2f m) %s"
			% [breaches, float(state["over"]), tag])
		check(int(state["lurk_shown"]) == 0,
			"while it lurks before a breach nothing of it shows (%d frames lurking) %s" % [int(state["lurked"]), tag])
	var warnings: int = _events(boss, &"bite_warning").size() + breaches
	check(_sounds(boss, &"guppy_rumble") == warnings and _sounds(boss, &"guppy_bite") >= bites.size(),
		"each bite and breach is warned by its rumble, each bite heard (%d rumbles for %d) %s"
		% [_sounds(boss, &"guppy_rumble"), warnings, tag])
	print("  Mecha Guppy %s: %d bites, %d catches, %d breaches; its jaws %.2f m under a rider at the closest"
		% [tag, bites.size(), catches, breaches, float(state["clear"])])
	await sim.free_world(world)


## Why the shark's jaws in its catch beside roof `roof`'s notch reach where a runner may be, or "": a point of them over a
## lane but the notch's (its floor's span, at any height: the tower stands under it), or over the notch's lane before
## the notch starts.
func _catch_intrusion(world: RunWorld, roof: MechaGuppyClimb.Roof, shark: MechaGuppyShark) -> String:
	if not roof.notched():
		return "a catch beside roof %d, which has no notch" % roof.index
	var geo: TrackGeometry = world.geo
	var notch: Vector2 = geo.lane_floor_span(roof.notch_lane)
	var margin: float = 0.02
	for pt: Vector3 in shark.jaws_points():
		var d: float = -pt.z
		var in_notch_x: bool = pt.x > notch.x + margin and pt.x < notch.y - margin
		var over_track: bool = absf(pt.x) < geo.wall_x() - margin
		if over_track and not in_notch_x:
			return "a point at x %.2f m (the notch's lane spans %.2f to %.2f m), %.1f m over the roof's top" % [pt.x, notch.x, notch.y,
				pt.y - roof.top]
		if in_notch_x and d < roof.notch_from - margin:
			return "a point over the notch's lane %.2f m before the notch" % (roof.notch_from - d)
	return ""


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

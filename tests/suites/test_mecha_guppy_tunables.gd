extends TestSuite
## Mecha Guppy's bait and fallback at both ends of every tunable's range, on real physics (task E5e-b3's review:
## tunables inside their own F6 ranges broke the bait's and the fallback's promises, and test_mecha_guppy's sweep only
## checks the climb's plan). For every MechaGuppyTuning tunable with a range (all but Captain Cogs' ship's, which only
## place the ship, and phase 3's and the defeat's, MechaGuppyTuning.TOP_TUNABLES, which test_mecha_guppy_top sweeps), at
## each end of its range, at 3 lanes and 23.8 m/s (the narrowest
## piers, the fastest run) and at 6 lanes and 18 m/s (the widest roofs, the most lanes to cross), a runner who never baits
## (MechaGuppyBot, baits off, the planner's reaction) climbs until the fallback has hit twice:
## - it lives, never hurt;
## - never a circle (the bait's aim included) in its lane while every lane it could switch to has no floor
##   (MechaGuppyBot.circle_trap);
## - every bait's aim shows only once the runner can switch lanes on that roof, a reaction after (Step.free_at, past the
##   hut's deadline), and every bait that locks leaves a runner in the notch's lane MechaGuppyPattern.lock_to_edge() to
##   leave it before its edge;
## - every fallback thrown goes into Mecha Guppy's jaws (no breach refused, none spent while the shark was busy);
## - it still progresses: two hits, the second fallback_after + 1 steps after the first (or at the next step that doesn't
##   lead onto a floor bite: task E5e-f, MechaGuppyPattern.bitten_next);
## - Mecha Guppy's floor bites (task E5e-f) it meets: each warned and snapped (none given up), never before the hut's
##   deadline, with a reaction (from where the runner was as it showed, or where they could first switch if that's later:
##   when it can be read), every switch from the farthest lane to the one it leaves, the dash's reach and dodge_margin
##   before the runner reaches it, and Mecha Guppy's rise and lunge before its snap; each one leaving exactly the far
##   side's outer lane at its deepest, the runner passing in it; no volley on a roof with one, no bait's aim beside it.
## And on the plan alone (MechaGuppyBiteChecks), for every ranged tunable at both ends at 3, 5 and 6 lanes, both speeds,
## in phases 1 and 2: every floor bite's shape (one lane left in phase 1; phase 2's full-width ones jumpable in every lane),
## its place (past the landing, short of the pads and the notch, never leaving the notch's lane), its warning's margins.

const BOSS_PATH: String = "res://data/bosses/beach_boss.tres"
## The fights: [lanes, speed].
const RUNS: Array[Vector2] = [Vector2(3, 23.8), Vector2(6, 18.0)]
const REACTION: float = 0.35
## The tunables that can't touch phases 1 and 2's bait or fallback (and MechaGuppyTuning.TOP_TUNABLES: phase 3's and the
## defeat's).
const SKIPPED: Array[String] = ["ship_ahead", "ship_height", "ship_sway"]
## The longest a variant's fight may take to land its two hits (seconds of fight).
const MOST_SECONDS: float = 240.0
## The plan sweep: lane counts, speeds, and steps planned in each phase.
const PLAN_LANES: Array[int] = [3, 5, 6]
const PLAN_SPEEDS: Array[float] = [18.0, 23.8]
const PLAN_STEPS: int = 24

var sim: RunSim
var def: BossDef


func run() -> void:
	sim = RunSim.new(tree, tuning)
	var slot := load(BOSS_PATH) as BossDef
	def = slot if slot != null and slot.is_built() else null
	if def == null:
		check(false, "Mecha Guppy and Captain Cogs' fight loads")
		return
	_test_bite_plans()
	await _test_every_tunable()


func _movement(speed: float) -> MovementTuning:
	if is_equal_approx(speed, tuning.run_speed):
		return tuning
	var t: MovementTuning = tuning.duplicate() as MovementTuning
	t.run_speed = speed
	return t


## The fight at `lanes` and `speed` m/s with boss slot `d`, attacks on: [world, boss].
func _fight(lanes: int, speed: float, d: BossDef) -> Array:
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


func _events(boss: BossEncounter, event: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in boss.events:
		if e["event"] == event:
			out.append(e)
	return out


## Every ranged tunable at both ends of its range: [{name, value}].
func _variants() -> Array[Dictionary]:
	var base := def.tuning as MechaGuppyTuning
	var out: Array[Dictionary] = []
	for prop: Dictionary in base.get_property_list():
		if int(prop["hint"]) != PROPERTY_HINT_RANGE or not (int(prop["usage"]) & PROPERTY_USAGE_EDITOR):
			continue
		if SKIPPED.has(String(prop["name"])) or MechaGuppyTuning.TOP_TUNABLES.has(String(prop["name"])):
			continue
		var parts: PackedStringArray = String(prop["hint_string"]).split(",")
		if parts.size() < 2:
			continue
		for v: float in [float(parts[0]), float(parts[1])]:
			out.append({"name": String(prop["name"]), "value": v})
	return out


func _test_every_tunable() -> void:
	for run_at: Vector2 in RUNS:
		await _test_every_tunable_at(int(run_at.x), run_at.y)


## The floor bite's promises on the plan (MechaGuppyBiteChecks) for every ranged tunable at both ends (the ship's and phase
## 3's too: they never touch it), at 3, 5 and 6 lanes and both speeds, in phases 1 and 2.
func _test_bite_plans() -> void:
	var base := def.tuning as MechaGuppyTuning
	var dash: float = MechaGuppyClimb.dash_reach_of(load("res://data/tuning/powerups.tres") as PowerupTuning)
	var variants: Array[Dictionary] = []
	for prop: Dictionary in base.get_property_list():
		if int(prop["hint"]) != PROPERTY_HINT_RANGE or not (int(prop["usage"]) & PROPERTY_USAGE_EDITOR):
			continue
		var parts: PackedStringArray = String(prop["hint_string"]).split(",")
		if parts.size() >= 2:
			for v: float in [float(parts[0]), float(parts[1])]:
				variants.append({"name": String(prop["name"]), "value": v})
	var bad: Array[String] = []
	var bites: int = 0
	var full: int = 0
	for variant: Dictionary in variants:
		var t: MechaGuppyTuning = base.duplicate() as MechaGuppyTuning
		var value: Variant = variant["value"]
		if typeof(t.get(variant["name"])) == TYPE_INT:
			value = int(value)
		t.set(variant["name"], value)
		for speed: float in PLAN_SPEEDS:
			var mt: MovementTuning = _movement(speed)
			for lanes: int in PLAN_LANES:
				for phase: int in 2:
					var c: MechaGuppyClimb = MechaGuppyClimb.make(mt, t, lanes, dash, 11)
					for i: int in PLAN_STEPS:
						c.plan_next(phase)
					var why: String = MechaGuppyBiteChecks.plan_problem(c, t)
					if why != "":
						bad.append("%s=%s (%d lanes, %.1f m/s, phase %d): %s" % [variant["name"], value, lanes, speed, phase + 1, why])
					for r: MechaGuppyClimb.Roof in c.roofs:
						if r.bite != null:
							bites += 1
							full += 1 if r.bite.full else 0
	check(bad.is_empty() and full > 0,
		"every tunable at both ends of its range keeps the floor bite's promises on the plan: one lane left in phase 1, phase 2's full-width bites jumpable in every lane, never the landing, the pads or the notch's lane, the warning's margins (%d variants, %d bites, %d full width)%s"
		% [variants.size(), bites, full, "" if bad.is_empty() else ": " + "; ".join(bad.slice(0, 4))])


func _test_every_tunable_at(lanes: int, speed: float) -> void:
	var variants: Array[Dictionary] = _variants()
	var died: Array[String] = []
	var trapped: Array[String] = []
	var unfair: Array[String] = []
	var uneaten: Array[String] = []
	var stalled: Array[String] = []
	var bitten: Array[String] = []
	var overlaps: Array[String] = []
	var baits: int = 0
	var fallbacks: int = 0
	var bites: int = 0
	var least: float = INF
	for variant: Dictionary in variants:
		var d: BossDef = def.duplicate() as BossDef
		var mt: MechaGuppyTuning = (def.tuning as MechaGuppyTuning).duplicate() as MechaGuppyTuning
		var value: Variant = variant["value"]
		if typeof(mt.get(variant["name"])) == TYPE_INT:
			value = int(value)
		mt.set(variant["name"], value)
		d.tuning = mt
		var tag: String = "%s=%s" % [variant["name"], value]
		var r: Dictionary = await _climb(d, mt, lanes, speed)
		baits += int(r["baits"])
		fallbacks += int(r["fallbacks"])
		if r["died"] != "":
			died.append("%s: %s" % [tag, r["died"]])
		if r["trap"] != "":
			trapped.append("%s: %s" % [tag, r["trap"]])
		if r["unfair"] != "":
			unfair.append("%s: %s" % [tag, r["unfair"]])
		if r["uneaten"] != "":
			uneaten.append("%s: %s" % [tag, r["uneaten"]])
		if r["stalled"] != "":
			stalled.append("%s: %s" % [tag, r["stalled"]])
		if r["bitten"] != "":
			bitten.append("%s: %s" % [tag, r["bitten"]])
		if r["overlap"] != "":
			overlaps.append("%s: %s" % [tag, r["overlap"]])
		bites += int(r["bites"])
		least = minf(least, float(r["least"]))
	var where: String = "(%d variants, %d lanes, %.1f m/s)" % [variants.size(), lanes, speed]
	check(died.is_empty(), "every tunable at both ends: a runner who never baits lives, never hurt %s%s"
		% [where, "" if died.is_empty() else ": " + "; ".join(died.slice(0, 4))])
	check(trapped.is_empty(), "every tunable at both ends: never a circle in the runner's lane with no floor to switch to %s%s"
		% [where, "" if trapped.is_empty() else ": " + "; ".join(trapped.slice(0, 4))])
	check(unfair.is_empty(), "every tunable at both ends: each bait's aim shows a reaction after the runner can switch lanes, and leaves a runner in the notch's lane time to leave it before its edge (%d baits) %s%s"
		% [baits, where, "" if unfair.is_empty() else ": " + "; ".join(unfair.slice(0, 4))])
	check(uneaten.is_empty(), "every tunable at both ends: every fallback goes into Mecha Guppy's jaws (%d fallbacks) %s%s"
		% [fallbacks, where, "" if uneaten.is_empty() else ": " + "; ".join(uneaten.slice(0, 4))])
	check(stalled.is_empty(), "every tunable at both ends: a runner who never baits still lands its hits, one every fallback_after + 1 steps (or the next that doesn't lead onto a floor bite) %s%s"
		% [where, "" if stalled.is_empty() else ": " + "; ".join(stalled.slice(0, 4))])
	check(bitten.is_empty() and bites > 0,
		"every tunable at both ends: each floor bite met is warned and snapped, never before the hut's deadline, a reaction from when it can be read, every switch from the farthest lane, the dash's reach and dodge_margin before the runner reaches it (least %.2f s to spare), Mecha Guppy's rise and lunge before its snap, one lane left and the runner passing in it (%d bites) %s%s"
		% [least, bites, where, "" if bitten.is_empty() else ": " + "; ".join(bitten.slice(0, 4))])
	check(overlaps.is_empty(), "every tunable at both ends: no volley on a roof with a floor bite, no bait's aim beside one, the lane it leaves never the notch's %s%s"
		% [where, "" if overlaps.is_empty() else ": " + "; ".join(overlaps.slice(0, 4))])
	print("  Mecha Guppy's tunables %s: %d baits, %d fallbacks, %d floor bites (least %.2f s to spare after a floor bite's switches)"
		% [where, baits, fallbacks, bites, least])


## One variant's climb at `lanes` and `speed` m/s with a runner who never baits, until its second hit: what broke ({died,
## trap, unfair, uneaten, stalled, bitten, overlap}: "" where nothing did), the baits, fallbacks and floor bites seen, and
## the least time to spare after a floor bite's switches from the farthest lane (`least`).
func _climb(d: BossDef, mt: MechaGuppyTuning, lanes: int, speed: float) -> Dictionary:
	var pair: Array = _fight(lanes, speed, d)
	var world: RunWorld = pair[0]
	var boss: MechaGuppy = pair[1]
	var p: Player = world.player
	var bot := MechaGuppyBot.new(boss)
	bot.reaction = REACTION
	bot.baits = false
	var cause: Array[String] = [""]
	p.died.connect(func(c: String) -> void: cause[0] = c)
	var hurt: Array[int] = [0]
	p.item_used.connect(func(_item: StringName) -> void: hurt[0] += 1)
	var trap: String = ""
	await tree.physics_frame
	p.running = true
	for i: int in int(MOST_SECONDS * Engine.physics_ticks_per_second):
		bot.step()
		if trap == "":
			trap = MechaGuppyBot.circle_trap(boss)
		if not p.alive or boss.hits_landed >= 2:
			break
		await tree.physics_frame
	var out: Dictionary = {"died": "", "trap": trap, "unfair": "", "uneaten": "", "stalled": "", "bitten": "", "overlap": "",
		"baits": 0, "fallbacks": 0, "bites": 0, "least": INF}
	if not p.alive or hurt[0] > 0:
		out["died"] = "%s at %.0f m (%.1f s)" % [cause[0] if not p.alive else "hurt", p.distance, boss.fight_time()]
	# The bait's promises, from where the runner was as its aim began and as it locked.
	var climb: MechaGuppyClimb = boss.climb
	var run_speed: float = maxf(p.speed, 1.0)
	var frame: float = run_speed / Engine.physics_ticks_per_second
	for e: Dictionary in _events(boss, &"bait_seek"):
		var s: MechaGuppyClimb.Step = climb.steps[int(e["step"])]
		var need: float = maxf(s.free_at, s.deadline) + mt.dodge_reaction * run_speed
		if float(e["d0"]) < need - frame - 0.01:
			out["unfair"] = "step %d's aim showed %.2f s before a reaction past where the runner could switch" \
				% [int(e["step"]), (need - float(e["d0"])) / run_speed]
	for e: Dictionary in _events(boss, &"bait_lock"):
		out["baits"] = int(out["baits"]) + 1
		var edge: float = float(e["at"]) - mt.catch_in
		var spare: float = (edge - float(e["d0"])) / run_speed
		if spare < boss.pattern.lock_to_edge() - frame / run_speed - 0.01:
			out["unfair"] = "step %d's bait locked %.2f s before the notch's edge" % [int(e["step"]), spare]
	# Every fallback eaten.
	var thrown: Array[Dictionary] = _events(boss, &"fallback")
	out["fallbacks"] = thrown.size()
	var eaten: int = 0
	for e: Dictionary in _events(boss, &"shark_hit"):
		if int(e["kind"]) == MechaGuppyBombs.Kind.HIT and bool(e["counted"]):
			eaten += 1
	var refused: int = _events(boss, &"breach_skipped").size()
	var busy: int = 0
	for e: Dictionary in _events(boss, &"fallback_skipped"):
		busy += 1 if bool(e.get("busy", false)) else 0
	if eaten != thrown.size() or refused > 0 or busy > 0:
		out["uneaten"] = "%d fallbacks, %d eaten, %d breaches refused, %d given up while the shark was busy" \
			% [thrown.size(), eaten, refused, busy]
	# Progress: two hits, fallback_after + 1 steps apart (or the next step that doesn't lead onto a floor bite).
	if p.alive and boss.hits_landed < 2:
		out["stalled"] = "%d hits in %.0f s" % [boss.hits_landed, boss.fight_time()]
	elif thrown.size() >= 2 and int(thrown[1]["step"]) != _fallback_step(int(thrown[0]["step"]) + mt.fallback_after + 1):
		out["stalled"] = "fallbacks on steps %d and %d" % [int(thrown[0]["step"]), int(thrown[1]["step"])]
	_check_bites(boss, mt, bot, out)
	await sim.free_world(world)
	return out


## The floor bites the climb met (see the header), into `out` ({bitten, overlap, bites, least}).
func _check_bites(boss: MechaGuppy, mt: MechaGuppyTuning, bot: MechaGuppyBot, out: Dictionary) -> void:
	var climb: MechaGuppyClimb = boss.climb
	var p: Player = boss.world.player
	var v: float = maxf(p.speed, 1.0)
	var frame: float = v / Engine.physics_ticks_per_second
	var h: float = boss.world.tuning.hurtbox_size.z * 0.5
	var switch: float = boss.world.tuning.lane_switch_time
	var n: int = boss.lane_count()
	var why: String = ""
	var warned: Dictionary = {}
	for e: Dictionary in _events(boss, &"floor_bite_warning"):
		var k: int = int(e["roof"])
		var bite: MechaGuppyCrescent = climb.roofs[k].bite
		var into: MechaGuppyClimb.Step = climb.steps[k - 1]
		var d0: float = float(e["d0"])
		warned[k] = true
		out["bites"] = int(out["bites"]) + 1
		# A reaction from when its warning can be read (its start, or where the runner can first switch if that's later),
		# then every switch from the farthest lane, even dashing on the way (the dash's reach).
		var spare: float = (bite.from - maxf(d0, into.free_at) - mt.dodge_reaction * v - h - climb.dash_reach) / v \
			- float(n - 1) * switch
		out["least"] = minf(float(out["least"]), spare)
		var shape: String = MechaGuppyBiteChecks.shape_problem(climb, mt, bite, climb.steps[k].phase)
		if why == "" and shape != "":
			why = "roof %d: %s" % [k, shape]
		if why == "" and d0 < into.deadline - frame - 0.01:
			why = "roof %d's warning %.2f s before the hut's deadline" % [k, (into.deadline - d0) / v]
		if why == "" and spare < mt.dodge_margin - 1.0 / Engine.physics_ticks_per_second - 0.01:
			why = "roof %d's warning leaves %.2f s after a reaction and the switches (dodge_margin %.2f s)" % [k, spare, mt.dodge_margin]
		if why == "" and (bite.snap_at - d0) / v < climb.bite_chain() - 1.0 / Engine.physics_ticks_per_second - 0.01:
			why = "roof %d's warning %.2f s before its snap, short of Mecha Guppy's rise and lunge" % [k, (bite.snap_at - d0) / v]
	# Every bite on a roof the runner got past was warned and snapped, and passed in the lane it leaves.
	var snapped: Dictionary = {}
	for e: Dictionary in _events(boss, &"floor_bite_snap"):
		snapped[int(e["roof"])] = true
	for r: MechaGuppyClimb.Roof in climb.roofs:
		if r.bite == null or p.distance < r.bite.to + 2.0:
			continue
		if why == "" and (not warned.has(r.index) or not snapped.has(r.index)):
			why = "roof %d's bite %s" % [r.index, "skipped" if r.bite.skipped else "not snapped"]
	for b: Dictionary in bot.bites:
		if why == "" and not bool(b["full"]) and int(b["lane"]) >= 0 and int(b["lane"]) != int(b["keep"]):
			why = "the runner passed roof %d's bite in lane %d, not the one it leaves (%d)" % [int(b["roof"]), int(b["lane"]), int(b["keep"])]
	out["bitten"] = why
	# No volley's circle and no bait's aim beside a bite.
	var overlap: String = ""
	for e: Dictionary in _events(boss, &"volley"):
		var roof: MechaGuppyClimb.Roof = climb.roofs[int(e["step"]) + 1]
		if roof.bite != null and overlap == "":
			overlap = "a volley on roof %d, which has a floor bite" % roof.index
	for e: Dictionary in _events(boss, &"bait_seek"):
		var roof: MechaGuppyClimb.Roof = climb.roofs[int(e["step"]) + 1]
		if roof.bite == null or overlap != "":
			continue
		if float(e["d0"]) < roof.bite.to + h - frame - 0.01:
			overlap = "roof %d's bait aims %.1f m short of the end of its bite" % [roof.index, roof.bite.to + h - float(e["d0"])]
		elif int(e["notch"]) == roof.bite.keep:
			overlap = "roof %d's bite leaves the notch's lane" % roof.index
	out["overlap"] = overlap


## The first step from `index` on whose fallback isn't deferred: one that doesn't lead onto a roof with a floor bite (task
## E5e-f, MechaGuppyPattern.bitten_next).
func _fallback_step(index: int) -> int:
	var k: int = index
	while MechaGuppyClimb.bitten(k + 1):
		k += 1
	return k

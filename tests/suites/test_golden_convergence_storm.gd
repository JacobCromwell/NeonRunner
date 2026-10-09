extends TestSuite
## The owner's playtest of the Golden Convergence's stage 2 (GDD §10, "Owner's playtest (October 9, 2026)"; task
## E5d-e): the Screen Storm and the arena's darkness. The Claw Slash and the stomp's chevrons:
## test_golden_convergence_slash.gd; stage 2 played through: test_golden_convergence_magnate_fight.gd.
## - The storm's plan without the engine (GoldenConvergenceStormPlan, thousands of storms): at 3 to 6 lanes, a model
##   runner who switches a reaction time after each warning in their lane, into any lane that showed no warning when
##   it appeared (the plan's escape, the lower, the higher, the middle's, any at random), is never in a lane as it's
##   struck and never switches into a lane under a warning; every storm drops its 10-16 screens (scaled to the lane
##   count), three on him, and comes down on the runner's own lane again and again (dodge and weave).
## - Storms in the fight, the bot weaving through by the plan's escapes at 3, 5 and 6 lanes and 18 and 25 m/s: every
##   screen warned screen_warning before it crashes (the glitch-whine heard each time), its square a floor warning
##   while it shows, its touch live only over its square and only from its crash; nothing stays (every rig back in the
##   pool, no touch, no square, no floor warning); the screens on him: three a storm, each a twelfth of the phase's
##   health (cause &"screen"), the boss bar dropping, him staggering with his cry of pain (never the roar).
## - A runner who stays in a struck lane is hit (a jump doesn't clear it); the armor blocks it.
## - Storms alone end a phase (four of them), the next phase's intro follows, and in the last phase they defeat him;
##   no screen hits him during an intro or after the defeat.
## - Reduced flashing: the squares steady and no sparks off a shattering screen.
## - The darkness: the arena fades to stage_two_light through the transition (from the checkpoint, on a retry, and
##   from phase 3's end), stays there through stage 2, and comes back as he falls, before the results; his body dims
##   with it, his cracks' glow doesn't.

const BOSS_PATH: String = "res://data/bosses/golden_boss.tres"
const STAGE_2: int = 3
const REACTION: float = 0.35
const FRAME: float = 1.0 / 60.0
const LANES: Array[int] = [3, 5, 6]
const SPEEDS: Array[float] = [18.0, 25.0]
## The model runners of the plan's test (how they pick among the lanes free as a warning showed).
const POLICIES: Array[String] = ["plan", "random", "low", "high", "middle"]
const SEEDS: int = 40

var sim: RunSim
var def: BossDef


func run() -> void:
	sim = RunSim.new(tree, tuning)
	var slot := load(BOSS_PATH) as BossDef
	def = slot if slot != null and slot.is_built() else null
	if def == null:
		check(false, "the Golden Convergence's fight is built")
		return
	_test_plan()
	_test_looks()
	for lanes: int in LANES:
		for speed: float in SPEEDS:
			await _test_storm(lanes, speed)
	await _test_stays()
	await _test_storms_end_phases()
	await _test_reduced_flashing()
	await _test_darkness()


# --- The fight ---------------------------------------------------------------------------------------------

## The fight at `lanes` and `speed` m/s from phase index `phase` (3: phase 4, the checkpoint); every phase's beat
## script `beats` if given; `mutate` changes the tuning's copy.
func _fight(lanes: int, speed: float, loadout: Loadout = null, phase: int = STAGE_2, beats: String = "",
		mutate: Callable = Callable()) -> Array:
	var d: BossDef = def
	if beats != "" or mutate.is_valid():
		d = def.duplicate() as BossDef
		var t := (def.tuning as GoldenConvergenceTuning).duplicate() as GoldenConvergenceTuning
		if beats != "":
			var list := PackedStringArray()
			for i: int in t.phase_beats.size():
				list.append(beats)
			t.phase_beats = list
		if mutate.is_valid():
			mutate.call(t)
		d.tuning = t
	var boss := BossEncounter.create(d) as GoldenConvergence
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = d
	ctx.config = BossArena.base_config(d)
	ctx.config.lane_count = lanes
	ctx.config.run_speed = speed
	ctx.tuning = tuning
	ctx.boss_resume = {"phase": phase}
	var arena: BossArena = boss.plan_arena(ctx)
	var world: RunWorld = sim.build_world(arena.layout, loadout, tuning, ctx.config)
	boss.setup(world, ctx, arena)
	return [world, boss]


func _bot(boss: GoldenConvergence) -> GoldenConvergenceBot:
	var bot := GoldenConvergenceBot.new(boss)
	bot.reaction = REACTION
	return bot


func _events(boss: BossEncounter, event: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in boss.events:
		if e["event"] == event:
			out.append(e)
	return out


func _sounds(boss: BossEncounter, sound_name: StringName) -> int:
	return boss.events.filter(func(e: Dictionary) -> bool: return e["event"] == &"sound" and e["name"] == sound_name).size()


## Steps the fight until `done` holds, the runner dies or `seconds` pass, the bot playing; `each` every frame.
func _run(world: RunWorld, bot: GoldenConvergenceBot, seconds: float, done: Callable = Callable(),
		each: Callable = Callable()) -> void:
	if not world.player.running:
		await tree.physics_frame
		world.player.running = true
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		if bot != null:
			bot.step()
		if each.is_valid():
			each.call()
		if (done.is_valid() and done.call()) or not world.player.alive:
			return
		await tree.physics_frame


func _death(world: RunWorld) -> Array[String]:
	var cause: Array[String] = [""]
	world.player.died.connect(func(c: String) -> void: cause[0] = c)
	return cause


## A saturated red (the hazards' hue).
static func _reddish(c: Color) -> bool:
	return (c.h < 0.06 or c.h > 0.94) and c.s > 0.45 and c.v > 0.3


static func _box(h: Hazard) -> AABB:
	return AABB(h.global_position - h.size * 0.5, h.size)


# --- The plan, without the engine ---------------------------------------------------------------------------

## The storm's plan played out against model runners: never struck, never into a warned lane, its screens all down,
## and on the runner's lane again and again.
func _test_plan() -> void:
	var t: GoldenConvergenceTuning = def.tuning as GoldenConvergenceTuning
	var warning: float = GoldenConvergenceStormPlan.warning_for(t, tuning)
	check(warning >= t.screen_warning and absf(warning - 0.9) < 0.051,
		"each screen is warned about 0.9 s before it crashes (%.2f s)" % warning)
	check(warning >= t.screen_reaction + tuning.lane_switch_time * t.screen_switch_margin + t.screen_margin,
		"a warning leaves a runner a reaction a lane switch and a margin to get out of its square (%.2f s)" % warning)
	for lanes: int in [3, 4, 5, 6]:
		var rec := {"storms": 0, "struck": 0, "into_warned": 0, "dropped": 0, "count_bad": 0, "hits_bad": 0, "on": 0,
			"moves": 0, "worst": ""}
		var want: int = GoldenConvergenceStormPlan.count_for(t, lanes)
		for policy: String in POLICIES:
			for seed_value: int in SEEDS:
				var r: Dictionary = _simulate(lanes, seed_value, policy, t)
				rec["storms"] = int(rec["storms"]) + 1
				rec["struck"] = int(rec["struck"]) + int(r["struck"])
				rec["into_warned"] = int(rec["into_warned"]) + int(r["into_warned"])
				rec["dropped"] = int(rec["dropped"]) + int(r["dropped"])
				rec["on"] = int(rec["on"]) + int(r["on"])
				rec["moves"] = int(rec["moves"]) + int(r["moves"])
				if int(r["placed"]) != want:
					rec["count_bad"] = int(rec["count_bad"]) + 1
				if int(r["him"]) != t.storm_hits:
					rec["hits_bad"] = int(rec["hits_bad"]) + 1
				if int(r["struck"]) > 0 and String(rec["worst"]) == "":
					rec["worst"] = "%s seed %d" % [policy, seed_value]
		var storms: int = int(rec["storms"])
		var tag: String = "(%d lanes, %d storms)" % [lanes, storms]
		check(int(rec["struck"]) == 0, "a runner who moves a reaction late into any lane clear as the warning showed is never struck %s %s" % [
			tag, rec["worst"]])
		check(int(rec["into_warned"]) == 0, "and never has to switch into a lane under a warning %s" % tag)
		check(int(rec["dropped"]) == 0 and int(rec["count_bad"]) == 0 and want >= t.storm_screens_min and want <= t.storm_screens_max,
			"every storm drops its %d screens (10-16, scaled to the lane count) %s" % [want, tag])
		check(int(rec["hits_bad"]) == 0, "%d of them on him %s" % [t.storm_hits, tag])
		var on: float = float(rec["on"]) / storms
		var moves: float = float(rec["moves"]) / storms
		print("  storm plan %s: %.1f screens a storm on the runner's own lane, %.1f dodges" % [tag, on, moves])
		check(on >= 3.0 and moves >= 3.0, "a storm comes down on the runner's own lane again and again: they dodge and weave (%.1f a storm) %s" % [
			moves, tag])


## One storm of the plan at `lanes` lanes from `seed_value`, a model runner (`policy`) reacting REACTION late:
## {struck, into_warned, dropped, placed, him, on, moves}.
func _simulate(lanes: int, seed_value: int, policy: String, t: GoldenConvergenceTuning) -> Dictionary:
	var plan := GoldenConvergenceStormPlan.make(lanes, t, tuning)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, lanes, "slots"])
	var count: int = GoldenConvergenceStormPlan.count_for(t, lanes)
	plan.set_slots(GoldenConvergenceStormPlan.slots(count, t.storm_hits, t.storm_seconds, rng), 0.0)
	var pick_rng := RandomNumberGenerator.new()
	pick_rng.seed = hash([seed_value, lanes, "pick"])
	var runner_rng := RandomNumberGenerator.new()
	runner_rng.seed = hash([seed_value, lanes, policy])
	var w: float = tuning.lane_width
	var lane: int = runner_rng.randi_range(0, lanes - 1)
	var x: float = lane * w
	var from_x: float = x
	var move_u: float = 1.0
	var reacted: Dictionary = {}
	var out := {"struck": 0, "into_warned": 0, "dropped": 0, "placed": 0, "him": 0, "on": 0, "moves": 0}
	var reach: float = w * t.screen_width_share * 0.5 + tuning.hurtbox_size.x * 0.5
	var end: float = t.storm_seconds + plan.warning + 1.5
	var time: float = 0.0
	var struck: Dictionary = {}
	while time < end:
		for s: Dictionary in plan.place_due(time, lane, pick_rng):
			out["placed"] = int(out["placed"]) + 1
			if int(s["lane"]) < 0:
				out["him"] = int(out["him"]) + 1
			elif int(s["lane"]) == lane:
				out["on"] = int(out["on"]) + 1
		# The runner: a reaction after a warning shows in the lane they're in (or heading for), into a lane free then
		# (a screen already down and gone is no warning).
		for s: Dictionary in plan.screens:
			var n: int = int(s["n"])
			if int(s["lane"]) != lane or reacted.has(n) or time < float(s["warn"]) + REACTION \
					or time > float(s["crash"]) + plan.touch:
				continue
			reacted[n] = true
			var ways: Array = s["escapes"]
			if ways.is_empty():
				out["struck"] = int(out["struck"]) + 1
				continue
			var to: int = _choose(policy, ways, int(s["escape"]), lanes, runner_rng)
			for other: Dictionary in plan.screens:
				if int(other["lane"]) == to and float(other["warn"]) <= time and float(other["crash"]) + plan.touch >= time:
					out["into_warned"] = int(out["into_warned"]) + 1
			lane = to
			from_x = x
			move_u = 0.0
			out["moves"] = int(out["moves"]) + 1
		# The switch eases out over lane_switch_time, as the player's does.
		if move_u < 1.0:
			move_u = minf(1.0, move_u + FRAME / tuning.lane_switch_time)
			var k: float = 1.0 - (1.0 - move_u) * (1.0 - move_u)
			x = lerpf(from_x, lane * w, k)
		for s: Dictionary in plan.screens:
			var sl: int = int(s["lane"])
			if sl < 0 or struck.has(int(s["n"])):
				continue
			var c: float = float(s["crash"])
			if time >= c and time <= c + plan.touch and absf(x - sl * w) < reach:
				struck[int(s["n"])] = true
				out["struck"] = int(out["struck"]) + 1
		time += FRAME
	out["dropped"] = plan.dropped
	return out


## The lane a model runner picks among `ways` (the lanes free as the warning showed).
static func _choose(policy: String, ways: Array, escape: int, lanes: int, rng: RandomNumberGenerator) -> int:
	match policy:
		"plan":
			return escape
		"low":
			return int(ways.min())
		"high":
			return int(ways.max())
		"middle":
			var mid: float = (lanes - 1) * 0.5
			var best: int = int(ways[0])
			for wv: Variant in ways:
				if absf(float(wv) - mid) < absf(float(best) - mid):
					best = int(wv)
			return best
	return int(ways[rng.randi_range(0, ways.size() - 1)])


# --- Its looks ---------------------------------------------------------------------------------------------

## The screens on their tentacles: never glowing but their faces (the feed's own picture), no hazard hue on the
## frame or the tentacle, the squares in the warnings' red; a budget for what a rig draws.
func _test_looks() -> void:
	var t: GoldenConvergenceTuning = def.tuning as GoldenConvergenceTuning
	var mesh: ArrayMesh = GoldenConvergenceTentacles.screen_mesh(GoldenSkin.new().solid_material(),
		GoldenConvergenceTentacles.feed_material(1.0, 0.5))
	var glows: int = 0
	var reds: int = 0
	var arrays: Array = mesh.surface_get_arrays(0)
	for c: Color in arrays[Mesh.ARRAY_COLOR] as PackedColorArray:
		if c.a > 0.001:
			glows += 1
		if _reddish(Color(c.r, c.g, c.b)):
			reds += 1
	var face := mesh.surface_get_material(1) as ShaderMaterial
	check(mesh.get_surface_count() == 2 and glows == 0 and reds == 0,
		"the screen's gilded frame and its gold tentacle never glow, in no hazard hue (%d, %d)" % [glows, reds])
	check(face != null and face.shader != null and face.shader.resource_path == GoldenConvergenceTentacles.FEED_SHADER
		and is_equal_approx(float(face.get_shader_parameter(&"feed_mode")), 1.0),
		"its face is the feed's own: his roaring face, glitching")
	var square: ArrayMesh = GoldenConvergenceTentacles.square_mesh(2.2, 2.4)
	var red := square.surface_get_material(0) as StandardMaterial3D
	check(red != null and red.emission_enabled and red.emission.is_equal_approx(BossProps.WARNING_COLOR),
		"its square glows the warnings' red")
	var vertices: int = 0
	for m: ArrayMesh in [mesh, square]:
		for s: int in m.get_surface_count():
			vertices += (m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	print("  a screen on its tentacle and its square draw %d vertices" % vertices)
	check(vertices <= 4000, "a rig's draw budget: %d vertices" % vertices)
	check(GoldenConvergenceScreens.square_depth(t, tuning) >= tuning.run_speed * t.screen_hit_seconds + tuning.hurtbox_size.z,
		"a square is deep enough to hold a runner who stays in it while its crash is live")


# --- Storms in the fight -----------------------------------------------------------------------------------

## The bot weaves through two storms: the warnings, the squares, the touches, nothing left, the hits on him.
func _test_storm(lanes: int, speed: float) -> void:
	var pair: Array = _fight(lanes, speed, null, STAGE_2 + 1, "screens")
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var sc: GoldenConvergenceScreens = boss.screens
	var rigs: GoldenConvergenceTentacles = boss.tentacles
	var m: GoldenConvergenceMagnate = boss.magnate
	var bot := _bot(boss)
	var cause: Array[String] = _death(world)
	var hints: Array[String] = []
	boss.hint_due.connect(func(key: String) -> void: hints.append(key))
	var bars: Array[float] = []
	boss.health_changed.connect(func(h: float, _mx: float) -> void: bars.append(h))
	var tag: String = "(%d lanes, %.0f m/s)" % [lanes, speed]
	var rec := {"unwarned": 0, "bad_touch": [], "early": 0, "stagger": 0, "in_view": 0, "frames": 0}
	var t: GoldenConvergenceTuning = boss.tuning
	await _run(world, bot, 60.0, func() -> bool: return _events(boss, &"storm_done").size() >= 2 and not sc.busy(), func() -> void:
		for s: Dictionary in sc.live:
			var lane: int = int(s["lane"])
			if lane >= 0 and int(s["stage"]) == GoldenConvergenceScreens.ScreenStage.WARN \
					and not boss.props.warned(lane, float(s["from"]), float(s["to"])):
				rec["unwarned"] = int(rec["unwarned"]) + 1
			var touch: Hazard = rigs.hazards()[int(s["rig"])]
			if not touch.is_active():
				continue
			if int(s["stage"]) != GoldenConvergenceScreens.ScreenStage.CRASH:
				rec["early"] = int(rec["early"]) + 1
			var b: AABB = _box(touch)
			var x: float = world.geo.lane_x(lane) if lane >= 0 else 0.0
			var half: float = world.geo.lane_width * 0.5
			var ok: bool = lane >= 0 and b.position.x >= x - half - 0.01 and b.end.x <= x + half + 0.01 \
				and -b.end.z >= float(s["from"]) - 0.05 and -b.position.z <= float(s["to"]) + 0.05 \
				and b.end.y > world.tuning.jump_height + world.tuning.hurtbox_size.y
			if not ok and (rec["bad_touch"] as Array).size() < 3:
				(rec["bad_touch"] as Array).append(str(b))
		if sc.stage == GoldenConvergenceScreens.Stage.STORM:
			rec["frames"] = int(rec["frames"]) + 1
			# Where the run camera shows him: in front of it, on the balustrade, beside the runner.
			var rel: float = -m.global_position.z - world.player.distance
			if rel > -world.tuning.camera_distance + 1.0 and absf(m.global_position.x) > world.geo.wall_x():
				rec["in_view"] = int(rec["in_view"]) + 1
			if m.anim == &"stagger":
				rec["stagger"] = int(rec["stagger"]) + 1)
	check(world.player.alive and rigs.hits.is_empty() and sc.crashes > 0,
		"the bot weaves through two Screen Storms by the plan's escapes, never struck %s (%s)" % [tag, cause[0]])
	var warned: Array[Dictionary] = _events(boss, &"screen_warned")
	var crashed: Array[Dictionary] = _events(boss, &"screen_crash") + _events(boss, &"screen_hit")
	var lead_ok: bool = not crashed.is_empty()
	for c: Dictionary in crashed:
		var w: Array[Dictionary] = warned.filter(func(e: Dictionary) -> bool: return int(e["storm"]) == int(c["storm"]) and int(e["n"]) == int(c["n"]))
		lead_ok = lead_ok and w.size() == 1 and float(c["t"]) - float(w[0]["t"]) >= t.screen_warning - FRAME
	check(lead_ok, "every screen crashes at least %.2f s after its warning %s" % [t.screen_warning, tag])
	check(_sounds(boss, &"magnate_glitch") == warned.size() and _sounds(boss, &"magnate_smash") == crashed.size(),
		"each with its rising glitch-whine, each crash heard %s" % tag)
	check(int(rec["unwarned"]) == 0, "each square on the track a floor warning while it shows %s" % tag)
	check(int(rec["early"]) == 0 and (rec["bad_touch"] as Array).is_empty(),
		"a crash touches only its square, above a jump, only once it's down: %s %s" % [", ".join(PackedStringArray(rec["bad_touch"])), tag])
	var done: Array[Dictionary] = _events(boss, &"storm_done")
	var want: int = GoldenConvergenceStormPlan.count_for(t, lanes)
	var counts_ok: bool = done.size() >= 2
	for e: Dictionary in done:
		counts_ok = counts_ok and int(e["warned"]) == want
	check(counts_ok and sc.dropped == 0, "each storm drops its %d screens %s" % [want, tag])
	var hits: Array[Dictionary] = _events(boss, &"screen_hit")
	var share: float = boss.phase_start_health(STAGE_2 + 1) - boss.phase_start_health(STAGE_2 + 2)
	var dmg_ok: bool = hits.size() == t.storm_hits * 2
	for h: Dictionary in hits:
		dmg_ok = dmg_ok and absf(float(h["damage"]) - share * t.screen_hit_share) < 0.01
	check(dmg_ok and absf(boss.health - (boss.phase_start_health(STAGE_2 + 1) - share * t.screen_hit_share * hits.size())) < 0.05,
		"%d screens on him a storm, each a twelfth of the phase (%.2f of %.0f) %s" % [t.storm_hits, share * t.screen_hit_share, share, tag])
	check(bars.size() >= hits.size() and _sounds(boss, &"magnate_pain") == hits.size() and _sounds(boss, &"magnate_roar") == 0,
		"the boss bar drops at each, and he cries out in pain (never the Pounce's roar) %s" % tag)
	check(int(rec["stagger"]) >= 1, "and staggers %s" % tag)
	check(int(rec["frames"]) > 0 and int(rec["in_view"]) == int(rec["frames"]),
		"through the storm he runs on the balustrade where the run camera shows him %s" % tag)
	# Nothing stays: once the screens are yanked away, every rig is back in the pool.
	await _run(world, bot, 2.0, func() -> bool: return rigs.used() == 0)
	var left_on: int = 0
	for i: int in rigs.rigs.size():
		if rigs.screen_on(i) or rigs.square_on(i) or rigs.shadow_on(i) or rigs.touch_on(i):
			left_on += 1
	var first: float = float(warned[0]["from"]) if not warned.is_empty() else 0.0
	var any_warned: bool = false
	for lane: int in boss.lane_count():
		any_warned = any_warned or boss.props.warned(lane, first - 5.0, world.player.distance + 200.0)
	check(rigs.used() == 0 and left_on == 0 and not any_warned and sc.live.is_empty(),
		"nothing stays on the track: every screen yanked away, no square, no floor warning %s" % tag)
	check(hints.count("golden_boss/screens") == 1, "the storm's hint comes once %s" % tag)
	await sim.free_world(world)


## A runner who stays in a screen's lane is struck there, a jump doesn't clear it, and the armor blocks it.
func _test_stays() -> void:
	for how: String in ["stays", "jumps", "armor"]:
		var loadout: Loadout = null
		if how == "armor":
			loadout = Loadout.new()
			loadout.armor = true
		var pair: Array = _fight(5, 18.0, loadout, STAGE_2 + 1, "screens")
		var world: RunWorld = pair[0]
		var boss: GoldenConvergence = pair[1]
		var rigs: GoldenConvergenceTentacles = boss.tentacles
		var bot := _bot(boss)
		bot.weaves = false
		var cause: Array[String] = _death(world)
		var jumped := {"done": false}
		await _run(world, bot, 30.0, func() -> bool: return not rigs.hits.is_empty(), func() -> void:
			if how != "jumps" or bool(jumped["done"]):
				return
			for s: Dictionary in boss.screens.live:
				if int(s["lane"]) == world.player.lane and int(s["stage"]) == GoldenConvergenceScreens.ScreenStage.WARN \
						and world.player.grounded and float(s["from"]) - world.player.distance <= boss.speed() * world.tuning.jump_time_to_apex:
					jumped["done"] = true
					world.player.press(&"jump"))
		var touch: Dictionary = rigs.hits[0] if not rigs.hits.is_empty() else {}
		match how:
			"stays":
				check(not world.player.alive and not touch.is_empty(), "a runner who stays in a screen's lane is struck (%s)" % cause[0])
			"jumps":
				check(bool(jumped["done"]) and not world.player.alive and float(touch.get("h", 0.0)) > 0.3,
					"a jump doesn't clear a crashing screen: struck %.1f m up" % float(touch.get("h", 0.0)))
			"armor":
				check(world.player.alive and int(touch.get("outcome", -1)) == DamageRules.Outcome.BLOCKED_ARMOR,
					"the armor blocks it (%s)" % [touch])
		await sim.free_world(world)


## Storms alone: four end phase 5 (the hurl follows), four more defeat him in phase 6; never a hit in an intro or
## after the defeat.
func _test_storms_end_phases() -> void:
	var pair: Array = _fight(5, 18.0, null, STAGE_2 + 1, "screens")
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var bot := _bot(boss)
	var cause: Array[String] = _death(world)
	var rec := {"intro_hits": 0, "ends": []}
	boss.phase_ended.connect(func(_i: int) -> void: (rec["ends"] as Array).append([boss.health, _events(boss, &"storm_start").size()]))
	await _run(world, bot, 160.0, func() -> bool: return boss.is_defeated() and boss.victory_over(), func() -> void:
		if boss.state == BossEncounter.State.INTRO and boss.screens.stage != GoldenConvergenceScreens.Stage.IDLE:
			rec["intro_hits"] = int(rec["intro_hits"]) + 1)
	var ends: Array = rec["ends"]
	var hits: Array[Dictionary] = _events(boss, &"screen_hit")
	var defeat_t: float = float(_events(boss, &"defeated")[0]["t"]) if not _events(boss, &"defeated").is_empty() else INF
	var after: int = hits.filter(func(e: Dictionary) -> bool: return float(e["t"]) > defeat_t).size()
	print("  storms alone: phase 5 ended after %d storms, the fight after %d (%d screens on him)" % [
		int(ends[0][1]) if not ends.is_empty() else -1, _events(boss, &"storm_start").size(), hits.size()])
	check(world.player.alive and boss.pounce.stomps == 0 and not ends.is_empty() and int(ends[0][1]) == 4
		and absf(float(ends[0][0]) - boss.phase_start_health(STAGE_2 + 2)) < 0.01,
		"four storms end a phase on their own, exactly at its end (%s) (%s)" % [ends, cause[0]])
	check(boss.transition.hurls >= 1 and _events(boss, &"hurl").size() >= 2,
		"and the next phase's intro follows: he hurls himself clear")
	check(boss.is_defeated() and str(_events(boss, &"defeated")[0].get("cause", "")) == "screen" and _events(boss, &"storm_start").size() == 8,
		"in the last phase four more defeat him, and the feed dies")
	check(after == 0 and int(rec["intro_hits"]) == 0, "no screen comes down during an intro or after the defeat")
	await sim.free_world(world)


# --- Reduced flashing ----------------------------------------------------------------------------------------

func _test_reduced_flashing() -> void:
	var was: bool = Settings.flashing_reduced
	for reduced: bool in [false, true]:
		Settings.flashing_reduced = reduced
		var tag: String = "with Reduced flashing" if reduced else "normally"
		var pair: Array = _fight(5, 18.0, null, STAGE_2 + 1, "screens")
		var world: RunWorld = pair[0]
		var boss: GoldenConvergence = pair[1]
		world.player.god_mode = true
		var rigs: GoldenConvergenceTentacles = boss.tentacles
		# The squares' beat: their size over what their warning's progress gives them (1: steady).
		var beats := {}
		await _run(world, _bot(boss), 20.0, func() -> bool: return _events(boss, &"storm_done").size() >= 1, func() -> void:
			for i: int in rigs.rigs.size():
				if rigs.square_on(i):
					var k: float = float(rigs.rigs[i].get("square_k", 0.0))
					beats[snappedf(rigs.square_node(i).transform.basis.x.length() / (0.9 + 0.1 * k), 0.001)] = true)
		if reduced:
			check(rigs.sparks_thrown == 0 and rigs.shards_thrown > 0 and beats.size() == 1,
				"%s a shattering screen throws its glass but no sparks, and the squares stay steady (%d beats)" % [tag, beats.size()])
		else:
			check(rigs.sparks_thrown > 0 and beats.size() > 1, "%s a shattering screen throws sparks, and the squares pulse" % tag)
		await sim.free_world(world)
	Settings.flashing_reduced = was


# --- The darkness --------------------------------------------------------------------------------------------

## About 30% darker through stage 2: from the checkpoint (twice: a retry), from phase 3's end, back at the defeat.
func _test_darkness() -> void:
	var t: GoldenConvergenceTuning = def.tuning as GoldenConvergenceTuning
	for attempt: int in 2:
		var tag: String = "(a retry from the checkpoint)" if attempt == 1 else "(from the checkpoint)"
		var pair: Array = _fight(5, 18.0, null, STAGE_2, "none")
		var world: RunWorld = pair[0]
		var boss: GoldenConvergence = pair[1]
		world.player.god_mode = true
		var lights: Array[float] = []
		await _run(world, null, def.phase_list()[STAGE_2].intro_seconds + 1.0, Callable(), func() -> void:
			lights.append(boss.light_level()))
		var falling: bool = lights.size() > 10
		for i: int in range(1, lights.size()):
			falling = falling and lights[i] <= lights[i - 1] + 0.0001
		check(lights.size() > 10 and lights[0] > 0.95 and falling and absf(lights[-1] - t.stage_two_light) < 0.001,
			"the arena fades from its light to %.2f through the transition %s (%.2f to %.2f)" % [t.stage_two_light, tag, lights[0], lights[-1]])
		check(absf(ZoneSkin.scenery_light_now - boss.scenery_light()) < 0.001 and boss.scenery_light() < 0.75,
			"the court's scenery dims with it (%.2f) %s" % [ZoneSkin.scenery_light_now, tag])
		await sim.free_world(world)
	# Reached in the fight (phase 3's end), it fades the same way, and stays dark through stage 2.
	var pair2: Array = _fight(5, 18.0, null, STAGE_2 - 1, "none")
	var world2: RunWorld = pair2[0]
	var boss2: GoldenConvergence = pair2[1]
	world2.player.god_mode = true
	await _run(world2, null, 8.0, func() -> bool: return boss2.is_vulnerable())
	check(is_equal_approx(boss2.light_level(), 1.0), "stage 1 keeps the court's light")
	for i: int in 6:
		if boss2.phase_index >= STAGE_2 or not boss2.is_vulnerable():
			break
		boss2.damage(boss2.hit_damage(), &"blast")
	await _run(world2, null, 7.0)
	check(boss2.phase_index == STAGE_2 and absf(boss2.light_level() - t.stage_two_light) < 0.001,
		"stage 2 reached in the fight is as dark (%.2f)" % boss2.light_level())
	await sim.free_world(world2)
	# The light comes back as he falls: the defeat lifts it before the results.
	var pair3: Array = _fight(5, 18.0, null, STAGE_2 + 2, "pounce:bait")
	var world3: RunWorld = pair3[0]
	var boss3: GoldenConvergence = pair3[1]
	var rec := {"dark_until": -1.0, "light_at_over": -1.0}
	await _run(world3, _bot(boss3), 60.0, func() -> bool: return boss3.is_defeated() and boss3.victory_over(), func() -> void:
		if not boss3.is_defeated():
			rec["dark_until"] = boss3.light_level())
	rec["light_at_over"] = boss3.light_level()
	check(boss3.is_defeated() and absf(float(rec["dark_until"]) - t.stage_two_light) < 0.001 and is_equal_approx(float(rec["light_at_over"]), 1.0),
		"dark until he falls (%.2f), and the light comes back before the results (%.2f)" % [rec["dark_until"], rec["light_at_over"]])
	await sim.free_world(world3)
	var code: String = (load("res://scripts/bosses/golden_convergence/golden_convergence_magnate.gdshader") as Shader).code
	var at_light: int = code.find("light_factor(scenery_light)")
	var at_glow: int = code.find("crack_color) * core")
	check(at_light > 0 and at_glow > at_light, "his body dims with the court, his cracks' warm white doesn't")

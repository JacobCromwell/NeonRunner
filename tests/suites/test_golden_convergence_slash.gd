extends TestSuite
## The owner's playtest of the Golden Convergence's stage 2 (GDD §10, "Owner's playtest (October 9, 2026)"; task
## E5d-e): the Claw Slash and the stomp made easier to read. The Screen Storm and the darkness:
## test_golden_convergence_storm.gd.
## - The Claw Slash, the bot dodging it a reaction late at 3, 5 and 6 lanes and 18 and 25 m/s: the warning (his
##   marker flashing red and held shown, the snarl, never the roar; the red claw marks a floor warning in the
##   runner's lane) at least slash_warning before the swipe at every pace, locked onto the runner's lane; always a
##   lane beside it clear to switch into; the swipe live only over the locked lane's marks and only as it lands,
##   above a jump; his claws coming in where the run camera shows them.
## - `slash:double`: a second warning right after, locked onto the lane the runner dodged into.
## - A runner who stays is hit (a jump doesn't clear it); the armor blocks it.
## - No lane to dodge into (a Flying Buttress's sides beside a runner in the outer lane): he holds until there is one.
## - Reduced flashing: the marker and the claw marks steady.
## - The stomp: the stun leaves at least stun_takeoff (1.5 s) from the stun to the last takeoff at 3, 5 and 6 lanes
##   and 18 and 25 m/s; green chevrons (never a hazard colour, steady) in both his lanes over the middle of the
##   stretch a jump can come down on his back from; a jump from their near end, their middle or their far end stomps
##   him at 18 and 25 m/s; they're gone once he's stomped.

const BOSS_PATH: String = "res://data/bosses/golden_boss.tres"
const STAGE_2: int = 3
const REACTION: float = 0.35
const FRAME: float = 1.0 / 60.0
const LANES: Array[int] = [3, 5, 6]
const SPEEDS: Array[float] = [18.0, 25.0]

var sim: RunSim
var def: BossDef


func run() -> void:
	sim = RunSim.new(tree, tuning)
	var slot := load(BOSS_PATH) as BossDef
	def = slot if slot != null and slot.is_built() else null
	if def == null:
		check(false, "the Golden Convergence's fight is built")
		return
	_test_data()
	for lanes: int in LANES:
		for speed: float in SPEEDS:
			await _test_slash(lanes, speed)
	await _test_double(5, 18.0)
	await _test_double(3, 25.0)
	await _test_stays()
	await _test_holds()
	await _test_reduced_flashing()
	for lanes: int in LANES:
		for speed: float in SPEEDS:
			await _test_stun_time(lanes, speed)
	for speed: float in SPEEDS:
		for point: float in [0.0, 0.5, 1.0]:
			await _test_chevrons(speed, point)


# --- The fight ---------------------------------------------------------------------------------------------

func _fight(lanes: int, speed: float, loadout: Loadout = null, phase: int = STAGE_2, beats: String = "") -> Array:
	var d: BossDef = def
	if beats != "":
		d = def.duplicate() as BossDef
		var t := (def.tuning as GoldenConvergenceTuning).duplicate() as GoldenConvergenceTuning
		var list := PackedStringArray()
		for i: int in t.phase_beats.size():
			list.append(beats)
		t.phase_beats = list
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


static func _box(h: Hazard) -> AABB:
	return AABB(h.global_position - h.size * 0.5, h.size)


# --- Data ----------------------------------------------------------------------------------------------------

func _test_data() -> void:
	var t: GoldenConvergenceTuning = def.tuning as GoldenConvergenceTuning
	check(absf(t.slash_warning - 0.5) < 0.051, "the swipe comes about half a second after its warning (%.2f s)" % t.slash_warning)
	check(t.slash_warning >= REACTION + tuning.lane_switch_time,
		"a split second, but a runner who moves a reaction late still switches out in time (%.2f s for %.2f s)" % [
			t.slash_warning, REACTION + tuning.lane_switch_time])
	check(t.slash_height > tuning.jump_height + tuning.hurtbox_size.y, "the swipe reaches above a jump (%.1f m)" % t.slash_height)


# --- The Claw Slash ------------------------------------------------------------------------------------------

## The bot dodges three slashes: the warning, the lock, the marks, the swipe only there, a lane always clear.
func _test_slash(lanes: int, speed: float) -> void:
	var pair: Array = _fight(lanes, speed, null, STAGE_2 + 1, "slash")
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var m: GoldenConvergenceMagnate = boss.magnate
	var sl: GoldenConvergenceSlash = boss.slash
	var bot := _bot(boss)
	var cause: Array[String] = _death(world)
	var hints: Array[String] = []
	boss.hint_due.connect(func(key: String) -> void: hints.append(key))
	var tag: String = "(%d lanes, %.0f m/s)" % [lanes, speed]
	var rec := {"warn_frames": 0, "red": 0, "blinks": {}, "unwarned": 0, "bad": [], "early": 0, "claws": [], "blocked": 0}
	await _run(world, bot, 40.0, func() -> bool: return _events(boss, &"slash_done").size() >= 3 and not sl.busy(), func() -> void:
		if sl.stage == GoldenConvergenceSlash.Stage.WARN:
			rec["warn_frames"] = int(rec["warn_frames"]) + 1
			if m.marker.alarm >= 1.0 and m.marker.shown > 0.9 and m.marker.color().is_equal_approx(GoldenConvergenceMagnateMarker.ALARM):
				rec["red"] = int(rec["red"]) + 1
			(rec["blinks"] as Dictionary)[snappedf(m.marker.blink, 0.01)] = true
			var mk: Dictionary = sl.marks()
			if mk.is_empty() or not boss.props.warned(int(mk["lane"]), float(mk["from"]), float(mk["to"])):
				rec["unwarned"] = int(rec["unwarned"]) + 1
			# The lanes it said were clear really are: no floor warning there but its own, no buttress's sides.
			for e: Variant in sl.p.get("escapes", []):
				for b: GoldenConvergenceButtress in boss.buttresses:
					if b.standing() and b.lane == int(e):
						rec["blocked"] = int(rec["blocked"]) + 1
		if m.slash_box().is_active():
			if sl.stage != GoldenConvergenceSlash.Stage.SWIPE:
				rec["early"] = int(rec["early"]) + 1
			var b: AABB = _box(m.slash_box())
			var x: float = world.geo.lane_x(int(sl.p.get("lane", -1)))
			var half: float = world.geo.lane_width * 0.5
			var ok: bool = b.position.x >= x - half - 0.01 and b.end.x <= x + half + 0.01 \
				and absf(-b.end.z - float(sl.p["from"])) < 0.05 and absf(-b.position.z - float(sl.p["to"])) < 0.05
			if not ok and (rec["bad"] as Array).size() < 3:
				(rec["bad"] as Array).append(str(b))
			if (rec["claws"] as Array).size() < _events(boss, &"slash_swipe").size():
				(rec["claws"] as Array).append(-m.global_position.z - world.player.distance))
	var warned: Array[Dictionary] = _events(boss, &"slash_warned")
	var swipes: Array[Dictionary] = _events(boss, &"slash_swipe")
	check(world.player.alive and m.touches.is_empty() and swipes.size() >= 3,
		"the bot dodges three Claw Slashes untouched %s (%s)" % [tag, cause[0]])
	var lead_ok: bool = warned.size() >= 3 and warned.size() == swipes.size()
	var lock_ok: bool = lead_ok
	var free_ok: bool = lead_ok
	for i: int in mini(warned.size(), swipes.size()):
		lead_ok = lead_ok and float(swipes[i]["t"]) - float(warned[i]["t"]) >= boss.tuning.slash_warning - FRAME
		lock_ok = lock_ok and int(warned[i]["lane"]) == int(warned[i]["runner_lane"]) and int(swipes[i]["lane"]) == int(warned[i]["lane"]) \
			and int(swipes[i]["runner_lane"]) != int(swipes[i]["lane"])
		var ways: Array = warned[i]["escapes"]
		free_ok = free_ok and not ways.is_empty() and ways.has(int(swipes[i]["runner_lane"]))
	check(lead_ok, "each swipe comes at least %.2f s after its warning, at phase 5's pace too %s" % [boss.tuning.slash_warning, tag])
	check(lock_ok, "locked onto the runner's lane as it warns, it swipes there, the runner out of it %s" % tag)
	check(free_ok and int(rec["blocked"]) == 0, "always a lane beside it clear to switch into, the one the runner took %s" % tag)
	check(int(rec["warn_frames"]) > 0 and int(rec["red"]) == int(rec["warn_frames"]) and (rec["blinks"] as Dictionary).size() == 2,
		"his marker flashes red through each warning, shown even as he comes into view %s" % tag)
	check(int(rec["unwarned"]) == 0, "the red claw marks a floor warning over where the swipe lands %s" % tag)
	check(_sounds(boss, &"magnate_snarl") == warned.size() and _sounds(boss, &"magnate_swipe") == swipes.size()
		and _sounds(boss, &"magnate_roar") == 0, "each with a sharp snarl, never the Pounce's roar %s" % tag)
	check(int(rec["early"]) == 0 and (rec["bad"] as Array).is_empty(),
		"the swipe live only as it lands, only over the locked lane's marks: %s %s" % [", ".join(PackedStringArray(rec["bad"])), tag])
	var claws_ok: bool = (rec["claws"] as Array).size() >= 3
	for rel: Variant in rec["claws"]:
		claws_ok = claws_ok and float(rel) > -world.tuning.camera_distance and float(rel) < 0.0
	check(claws_ok, "as it lands he's between the camera and the runner: his claws come in at the bottom of the view %s %s" % [
		rec["claws"], tag])
	check(hints.count("golden_boss/slash") == 1, "the slash's hint comes once %s" % tag)
	await sim.free_world(world)


## `slash:double`: the second warning right after the first swipe, locked onto the lane the runner dodged into.
func _test_double(lanes: int, speed: float) -> void:
	var pair: Array = _fight(lanes, speed, null, STAGE_2 + 2, "slash:double")
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var m: GoldenConvergenceMagnate = boss.magnate
	var bot := _bot(boss)
	var cause: Array[String] = _death(world)
	var tag: String = "(%d lanes, %.0f m/s)" % [lanes, speed]
	await _run(world, bot, 40.0, func() -> bool: return _events(boss, &"slash_done").size() >= 2 and not boss.slash.busy())
	var warned: Array[Dictionary] = _events(boss, &"slash_warned")
	var swipes: Array[Dictionary] = _events(boss, &"slash_swipe")
	var ok: bool = warned.size() == 4 and swipes.size() == 4
	for k: int in [1, 3]:
		if not ok:
			break
		ok = int(warned[k]["k"]) == 2 and int(warned[k]["lane"]) == int(swipes[k - 1]["runner_lane"]) \
			and int(warned[k]["lane"]) != int(warned[k - 1]["lane"]) \
			and float(warned[k]["t"]) - float(swipes[k - 1]["t"]) <= boss.tuning.slash_double_gap + 2.0 * FRAME \
			and float(swipes[k]["t"]) - float(warned[k]["t"]) >= boss.tuning.slash_warning - FRAME
	check(world.player.alive and m.touches.is_empty() and ok,
		"twice in a row: the second warned right after the first lands, locked onto the lane the runner dodged into, and dodged too %s (%s)" % [
			tag, cause[0]])
	check(_sounds(boss, &"magnate_snarl") == 4, "each swipe with its own snarl %s" % tag)
	await sim.free_world(world)


## A runner who stays is hit by the swipe, jumping or not; the armor blocks it.
func _test_stays() -> void:
	for how: String in ["stays", "jumps", "armor"]:
		var loadout: Loadout = null
		if how == "armor":
			loadout = Loadout.new()
			loadout.armor = true
		var pair: Array = _fight(5, 18.0, loadout, STAGE_2 + 1, "slash")
		var world: RunWorld = pair[0]
		var boss: GoldenConvergence = pair[1]
		var m: GoldenConvergenceMagnate = boss.magnate
		var bot := _bot(boss)
		bot.dodges_slash = false
		var cause: Array[String] = _death(world)
		var jumped := {"done": false}
		await _run(world, bot, 20.0, func() -> bool: return not m.touches.is_empty(), func() -> void:
			var mk: Dictionary = boss.slash.marks()
			if how == "jumps" and not bool(jumped["done"]) and not mk.is_empty() and world.player.grounded \
					and float(mk["from"]) - world.player.distance <= boss.speed() * world.tuning.jump_time_to_apex:
				jumped["done"] = true
				world.player.press(&"jump"))
		var touch: Dictionary = m.touches[0] if not m.touches.is_empty() else {}
		match how:
			"stays":
				check(not world.player.alive and touch.get("kind", &"") == &"slash", "a runner who stays in the locked lane is slashed (%s)" % cause[0])
			"jumps":
				check(bool(jumped["done"]) and not world.player.alive and touch.get("kind", &"") == &"slash" and float(touch.get("h", 0.0)) > 0.3,
					"a jump doesn't clear his claws: hit %.1f m up" % float(touch.get("h", 0.0)))
			"armor":
				check(world.player.alive and int(touch.get("outcome", -1)) == DamageRules.Outcome.BLOCKED_ARMOR,
					"the armor blocks the swipe (%s)" % [touch])
		await sim.free_world(world)


## No lane to switch into (on 3 lanes, the runner in the outer lane beside a Flying Buttress): he holds behind the
## camera until the way is clear, then warns.
func _test_holds() -> void:
	var pair: Array = _fight(3, 18.0, null, STAGE_2 + 1, "slash")
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var sl: GoldenConvergenceSlash = boss.slash
	var bot := _bot(boss)
	bot.home_lane = 0
	var cause: Array[String] = _death(world)
	var rec := {"gate": null, "warned_in_span": 0}
	await _run(world, bot, 30.0, func() -> bool: return _events(boss, &"slash_done").size() >= 1 and not sl.busy(), func() -> void:
		if rec["gate"] == null and sl.stage == GoldenConvergenceSlash.Stage.CLOSE and world.player.lane == 0:
			rec["gate"] = boss.place_buttress(1, world.player.distance + 20.0)
		var gate: GoldenConvergenceButtress = rec["gate"]
		if gate != null and sl.stage == GoldenConvergenceSlash.Stage.WARN and sl.stage_time <= FRAME * 1.5:
			var span: Vector2 = gate.blocked_span()
			var reach: float = world.player.distance + boss.speed() * (boss.tuning.slash_warning + boss.tuning.slash_hit_seconds) + 2.0
			if span.x <= reach and span.y >= world.player.distance - 1.0:
				rec["warned_in_span"] = int(rec["warned_in_span"]) + 1)
	var warned: Array[Dictionary] = _events(boss, &"slash_warned")
	var ways: Array = warned[0]["escapes"] if warned.size() == 1 else []
	check(rec["gate"] != null and int(rec["warned_in_span"]) == 0 and ways.size() == 1 and int(ways[0]) == 1,
		"with the only lane beside the runner blocked by a buttress's sides, he holds until it's clear, then warns (%s)" % [warned])
	check(world.player.alive and boss.magnate.touches.is_empty(), "and the runner dodges into it untouched (%s)" % cause[0])
	await sim.free_world(world)


# --- Reduced flashing --------------------------------------------------------------------------------------

func _test_reduced_flashing() -> void:
	var was: bool = Settings.flashing_reduced
	for reduced: bool in [false, true]:
		Settings.flashing_reduced = reduced
		var tag: String = "with Reduced flashing" if reduced else "normally"
		var pair: Array = _fight(5, 18.0, null, STAGE_2 + 1, "slash")
		var world: RunWorld = pair[0]
		var boss: GoldenConvergence = pair[1]
		world.player.god_mode = true
		var sl: GoldenConvergenceSlash = boss.slash
		var seen := {"blink": {}, "marks": {}}
		await _run(world, _bot(boss), 20.0, func() -> bool: return _events(boss, &"slash_done").size() >= 1, func() -> void:
			if sl.stage == GoldenConvergenceSlash.Stage.WARN:
				seen["blink"][snappedf(boss.magnate.marker.blink, 0.01)] = true
				if sl._marks_t > 0.3:
					seen["marks"][snappedf(sl.marks_node().transform.basis.x.length(), 0.0001)] = true)
		var blinks: int = (seen["blink"] as Dictionary).size()
		var marks: int = (seen["marks"] as Dictionary).size()
		if reduced:
			check(blinks == 1 and marks == 1, "%s the marker and the claw marks stay steady (%d, %d)" % [tag, blinks, marks])
		else:
			check(blinks == 2 and marks >= 2, "%s the marker and the claw marks flash (%d, %d)" % [tag, blinks, marks])
		await sim.free_world(world)
	Settings.flashing_reduced = was


# --- The stomp made easier to read ---------------------------------------------------------------------------

## At least stun_takeoff from the stun to the last takeoff, and the chevrons in both his lanes.
func _test_stun_time(lanes: int, speed: float) -> void:
	var pair: Array = _fight(lanes, speed, null, STAGE_2 + 1, "pounce:bait")
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var pc: GoldenConvergencePounce = boss.pounce
	var bot := _bot(boss)
	var cause: Array[String] = _death(world)
	var tag: String = "(%d lanes, %.0f m/s)" % [lanes, speed]
	var rec := {"marks": {}, "strips": [], "steady": true, "last": Transform3D()}
	await _run(world, bot, 30.0, func() -> bool: return pc.stomps >= 1 or pc.misses >= 1, func() -> void:
		if pc.stunned() and (rec["marks"] as Dictionary).is_empty():
			rec["marks"] = pc.takeoff_marks.marked.duplicate(true)
			for s: MeshInstance3D in pc.takeoff_marks.strips:
				(rec["strips"] as Array).append({"on": s.visible, "x": s.global_position.x})
			rec["last"] = pc.takeoff_marks.strips[0].global_transform
		elif pc.stunned() and not pc.takeoff_marks.strips[0].global_transform.is_equal_approx(rec["last"]):
			rec["steady"] = false)
	var stun: Array[Dictionary] = _events(boss, &"stun")
	var seconds: float = (float(stun[0]["last_takeoff"]) - float(stun[0]["runner"])) / speed if not stun.is_empty() else -1.0
	check(seconds >= boss.tuning.stun_takeoff - FRAME, "the stun leaves %.2f s to the last takeoff, at least %.1f s %s" % [
		seconds, boss.tuning.stun_takeoff, tag])
	var marks: Dictionary = rec["marks"]
	var lanes_on: Array = marks.get("lanes", [])
	var strips: Array = rec["strips"]
	var strips_ok: bool = strips.size() == 2 and lanes_on.size() == 2
	for i: int in strips.size():
		strips_ok = strips_ok and bool(strips[i]["on"]) and absf(float(strips[i]["x"]) - world.geo.lane_x(int(lanes_on[i]))) < 0.01
	var gaps: Vector2 = pc.takeoff_gaps()
	var back: float = float(stun[0]["back"]) if not stun.is_empty() else 0.0
	var within: bool = not marks.is_empty() and float(marks["from"]) >= back - gaps.y - 0.01 and float(marks["to"]) <= back - gaps.x + 0.01
	check(strips_ok and lanes_on == (stun[0]["lanes"] if not stun.is_empty() else []) and within and bool(rec["steady"]),
		"green chevrons in both his lanes, steady, over the stretch a jump comes down on his back from %s" % tag)
	check(world.player.alive and pc.stomps == 1 and not pc.takeoff_marks.shown(), "the bot stomps him from them, and they're gone %s (%s)" % [
		tag, cause[0]])
	await sim.free_world(world)


## A jump from the chevrons' near end, middle or far end comes down on his back.
func _test_chevrons(speed: float, point: float) -> void:
	var pair: Array = _fight(5, speed, null, STAGE_2 + 1, "pounce:bait")
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var pc: GoldenConvergencePounce = boss.pounce
	var bot := _bot(boss)
	bot.chevron_point = point
	var cause: Array[String] = _death(world)
	await _run(world, bot, 30.0, func() -> bool: return pc.stomps >= 1 or pc.misses >= 1)
	var jumps: Array = bot.log.filter(func(e: Dictionary) -> bool: return e["action"] == &"jump" and String(e["why"]).contains("chevrons"))
	check(world.player.alive and jumps.size() == 1 and pc.stomps == 1 and pc.misses == 0,
		"a jump from %s of the chevrons comes down on his back (%.0f m/s) (%s)" % [
			"the near end" if point < 0.25 else ("the far end" if point > 0.75 else "the middle"), speed, cause[0]])
	# The chevrons: the ramps' green, glowing (a "jump here" mark, never a hazard's colour).
	var mesh: ArrayMesh = pc.takeoff_marks.strips[0].mesh as ArrayMesh
	var greens: int = 0
	var bad: int = 0
	for c: Color in mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray:
		var rgb := Color(c.r, c.g, c.b)
		if rgb.h > 0.22 and rgb.h < 0.45 and rgb.s > 0.4 and c.a > 0.0:
			greens += 1
		else:
			bad += 1
	check(greens > 0 and bad == 0, "the chevrons are the ramps' glowing green, nothing else (%d, %d)" % [greens, bad])
	await sim.free_world(world)

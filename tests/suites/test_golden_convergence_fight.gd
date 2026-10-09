extends TestSuite
## The Golden Convergence's Helidrone Strafe and Flying Buttress played through (GDD §10; task E5d-a), at 3,
## 5 and 6 lanes and at quick play's 18 m/s and the Golden Zone's 25 m/s, with a runner who plays it by what
## it shows (GoldenConvergenceBot, reacting REACTION late; no god mode, no armor unless a test says so):
## - phase 1's strafes (its opening V-V-H, then the Refill Ship's V-V-H, played alone until E5d-c; the Fist
##   Slam's sequence and the Missile Barrage between them, E5d-b, played through untouched): the squadron's
##   size, the first vertical pass over lanes 1, 3, 5 (counting from 1), each next one switching; a drone
##   over each covered lane and the spare one climbed above the formation, never over a safe lane;
##   each pass's red lines and whine at least WARNING_MIN before its fire could reach the runner; no fire
##   anywhere but its warned lanes' stretch or the live line, and only once its warning is over; each
##   horizontal pass's buttress in an inner lane, up buttress_sight before its line and within reach from the
##   farthest lane, its red line over every lane but the opening, the live line burning whole before the
##   runner gets there and on while they're at it; the lines for show harmless; the runner never touched,
##   the strafe's hint and the buttress's coming once;
## - a 7-pass strafe (phases 2 and 3, after the phase's two slam sequences and barrages): V-V-H-v-V-H-v, the
##   4th and 7th from behind, the parity switching over the vertical passes, the bot untouched;
## - a runner who stays in a raked lane is hit there once its warning is over; one who stays out of the
##   arch is hit by the live line, jumping or not; the armor blocks the fire; the dash passes through it;
## - the wall rule: a vertical pass's fire in an outer lane hits a runner low on the open wall beside it,
##   not one high up; the live line hits a wall runner at any height;
## - a pad hurls the whole squadron up while it's out and ends the strafe (E5d-c's chain reaction hook);
## - hold() stops the fire and takes the warnings away at once, and the passes left come on release;
## - it plays the same on every attempt.

const BOSS_PATH: String = "res://data/bosses/golden_boss.tres"
const LANES: Array[int] = [3, 5, 6]
## Quick play's speed and the Golden Zone's (GDD §3).
const SPEEDS: Array[float] = [18.0, 25.0]
const REACTION: float = 0.35
## A pass's fire never reaches the runner sooner than this after its warning shows (GDD §10: "a red line on
## the floor where the fire will land, about a second ahead").
const WARNING_MIN: float = 1.0
## Half the runner's body depth along the track (its hitbox, for when the fire would reach it).
const BODY_HALF: float = 0.3

var sim: RunSim
var def: BossDef


func run() -> void:
	sim = RunSim.new(tree, tuning)
	var slot := load(BOSS_PATH) as BossDef
	def = slot.preview() if slot != null else null
	if def == null:
		check(false, "the Golden Convergence's preview loads")
		return
	for lanes: int in LANES:
		for speed: float in SPEEDS:
			await _test_phase_one(lanes, speed)
	await _test_seven_passes()
	await _test_stays_in_lane()
	await _test_stays_out_of_the_arch()
	await _test_armor_and_dash()
	await _test_wall_rule()
	await _test_pad()
	await _test_hold()
	await _test_same_every_attempt()


## The fight at `lanes` and `speed` m/s: from phase `phase` (a checkpoint's resume), or with `phase` -1 past
## the entrance; every phase's beat script `beats` if given: [world, boss].
func _fight(lanes: int, speed: float, loadout: Loadout = null, phase: int = -1, beats: String = "") -> Array:
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
	if phase > 0:
		ctx.boss_resume = {"phase": phase}
	elif phase < 0:
		ctx.boss_resume = {"phase": 0, "time": 0.0}
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


# --- The fairness watch ---------------------------------------------------------------------------

## A fresh record for _watch.
static func _record() -> Dictionary:
	return {"bad_fire": [], "early_fire": [], "lead": INF, "drone_over_safe": [], "spare_low": [], "contacts": {},
		"line_gaps": [], "fire_frames": 0}


## Every frame of a strafe: what burns lies in a warned lane's stretch or on the live line (never the
## opening), only once its warning is over; the drones fly over covered lanes (the spare above them); how
## soon after its warning each pass's fire could reach the runner; the live line burns whole while the
## runner is at it.
func _watch(boss: GoldenConvergence, rec: Dictionary) -> void:
	var s: GoldenConvergenceStrafe = boss.strafe
	var geo: TrackGeometry = boss.world.geo
	var t: GoldenConvergenceTuning = boss.tuning
	var now: float = boss.fight_time()
	var d: float = boss.player_distance()
	var p: Dictionary = s.passes[s.current] if s.current >= 0 and s.current < s.passes.size() else {}
	var firing: bool = not p.is_empty() and int(p["stage"]) == GoldenConvergenceStrafe.PassStage.FIRE
	var tag: String = "pass %s%s" % [p.get("kind", "?"), p.get("n", "")]
	for hazard: Hazard in boss.fire.hazards():
		if not hazard.is_active():
			continue
		rec["fire_frames"] = int(rec["fire_frames"]) + 1
		if not firing:
			(rec["bad_fire"] as Array).append("%.2f: fire with no pass firing" % now)
			continue
		if now < float(p["warned_at"]) + t.warning_seconds - 0.02:
			(rec["early_fire"] as Array).append("%.2f: %s fires %.2f s after its warning" % [now, tag, now - float(p["warned_at"])])
		var c: Vector3 = hazard.global_position
		var half: Vector3 = hazard.size * 0.5
		var near: float = -(c.z + half.z)
		var far: float = -(c.z - half.z)
		var allowed: Array = p["burning"] if String(p["kind"]) == "H" else p["lanes"]
		for lane: int in geo.lane_count:
			var lo: float = -INF if lane == 0 else geo.lane_x(lane) - geo.lane_width * 0.5
			var hi: float = INF if lane == geo.lane_count - 1 else geo.lane_x(lane) + geo.lane_width * 0.5
			if minf(c.x + half.x, hi) - maxf(c.x - half.x, lo) > 0.01 and not allowed.has(lane):
				(rec["bad_fire"] as Array).append("%.2f: %s burns lane %d (warned %s)" % [now, tag, lane, allowed])
		if String(p["kind"]) == "H":
			var line: float = float(p["line_at"])
			if near < line - t.line_depth * 0.5 - 0.01 or far > line + t.line_depth * 0.5 + 0.01:
				(rec["bad_fire"] as Array).append("%.2f: %s burns %.1f-%.1f off its line %.1f" % [now, tag, near, far, line])
		elif near < float(p["from"]) - GoldenConvergenceFire.RAKE_DEPTH or far > float(p["to"]) + GoldenConvergenceFire.RAKE_DEPTH:
			(rec["bad_fire"] as Array).append("%.2f: %s burns %.1f-%.1f outside %.1f-%.1f" % [now, tag, near, far, p["from"], p["to"]])
	if p.is_empty() or int(p["stage"]) == GoldenConvergenceStrafe.PassStage.DONE:
		return
	# When its fire could first reach the runner.
	var key: String = "%d:%d" % [s.strafes, int(p["n"])]
	if not (rec["contacts"] as Dictionary).has(key) and firing:
		var reach: bool = false
		match String(p["kind"]):
			"V":
				reach = float(p["front"]) - GoldenConvergenceFire.RAKE_DEPTH * 0.5 <= d + BODY_HALF
			"v":
				reach = float(p["front"]) + GoldenConvergenceFire.RAKE_DEPTH * 0.5 >= d - BODY_HALF
			"H":
				reach = d + BODY_HALF >= float(p["line_at"]) - t.line_depth * 0.5
		if reach:
			var lead: float = now - float(p["warned_at"])
			rec["contacts"][key] = lead
			rec["lead"] = minf(float(rec["lead"]), lead)
	# The live line burns whole (but the opening) while the runner is at it.
	if firing and String(p["kind"]) == "H":
		var line: float = float(p["line_at"])
		if d + BODY_HALF >= line - t.line_depth * 0.5 and d - BODY_HALF <= line + t.line_depth * 0.5:
			for lane: int in p["burning"]:
				if not boss.fire.line_lane_on(0, lane):
					(rec["line_gaps"] as Array).append("%.2f: lane %d out while the runner is at the line" % [now, lane])
	# The drones over covered lanes, the spare above.
	if firing and String(p["kind"]) != "H":
		var lanes: Array = p["lanes"]
		for i: int in boss.squadron.size():
			if not boss.squadron.flying(i):
				continue
			var at: Vector3 = boss.squadron.drone_position(i)
			var over: bool = false
			for lane: int in lanes:
				over = over or absf(at.x - geo.lane_x(lane)) <= geo.lane_width * 0.5
			if not over:
				(rec["drone_over_safe"] as Array).append("%.2f: drone %d at x %.1f (%s %s)" % [now, i, at.x, tag, lanes])
			if i >= lanes.size() and at.y < t.fly_height + t.spare_climb - 0.3:
				(rec["spare_low"] as Array).append("%.2f: the spare drone at %.1f m" % [now, at.y])


## Checks a watch's record (`tag` names the setup).
func _check_watch(rec: Dictionary, tag: String) -> void:
	check(int(rec["fire_frames"]) > 0, "the strafe's fire burns %s" % tag)
	check((rec["bad_fire"] as Array).is_empty(), "nothing burns but a warned lane's stretch or the live line (never the opening) %s: %s" % [
		tag, ", ".join(PackedStringArray((rec["bad_fire"] as Array).slice(0, 3)))])
	check((rec["early_fire"] as Array).is_empty(), "and only once its warning is over %s: %s" % [tag,
		", ".join(PackedStringArray((rec["early_fire"] as Array).slice(0, 3)))])
	check(float(rec["lead"]) >= WARNING_MIN, "each pass warns at least %.1f s before its fire could reach the runner (%.2f s) %s" % [
		WARNING_MIN, rec["lead"], tag])
	check((rec["drone_over_safe"] as Array).is_empty(), "a drone never flies over a safe lane %s: %s" % [tag,
		", ".join(PackedStringArray((rec["drone_over_safe"] as Array).slice(0, 3)))])
	check((rec["spare_low"] as Array).is_empty(), "the spare drone holds above the formation %s" % tag)
	check((rec["line_gaps"] as Array).is_empty(), "the live line burns whole while the runner is at it %s: %s" % [tag,
		", ".join(PackedStringArray((rec["line_gaps"] as Array).slice(0, 3)))])


# --- Phase 1 ---------------------------------------------------------------------------------------

func _test_phase_one(lanes: int, speed: float) -> void:
	var tag: String = "(%d lanes, %.0f m/s)" % [lanes, speed]
	var pair: Array = _fight(lanes, speed)
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var t: GoldenConvergenceTuning = boss.tuning
	var bot := _bot(boss)
	var cause: Array[String] = _death(world)
	var hints: Array[String] = []
	boss.hint_due.connect(func(key: String) -> void: hints.append(key))
	var rec: Dictionary = _record()
	await _run(world, bot, 70.0, func() -> bool: return _events(boss, &"strafe_done").size() >= 2,
		func() -> void: _watch(boss, rec))
	check(world.player.alive and boss.fire.hits.is_empty(), "the bot gets through two strafes untouched (%s, %d touches) %s" % [
		cause[0], boss.fire.hits.size(), tag])
	check(_events(boss, &"slams_done").size() == 1 and _events(boss, &"barrage_out").size() == 1
		and boss.slams.fist.hits.is_empty() and boss.barrage.missiles.hits.is_empty(),
		"and the slams and the barrage between them %s" % tag)
	var starts: Array[Dictionary] = _events(boss, &"strafe_start")
	check(starts.size() == 2 and String(starts[0]["script"]) == "VVH" and String(starts[1]["script"]) == "VVH"
		and bool(starts[1]["refill"]) and int(starts[0]["drones"]) == GoldenConvergenceTuning.squadron_size(lanes),
		"phase 1: the opening strafe, then the Refill Ship's (alone until E5d-c), V-V-H each, %d drones %s" % [
			GoldenConvergenceTuning.squadron_size(lanes), tag])
	var warned: Array[Dictionary] = _events(boss, &"pass_warned")
	check(warned.size() == 6, "six passes %s (%d)" % [tag, warned.size()])
	var parity_ok: bool = true
	var buttress_ok: bool = true
	var red_ok: bool = true
	var vertical: int = 0
	for e: Dictionary in warned:
		if String(e["kind"]) == "H":
			var opening: int = int(e["opening"])
			var all_but: Array = []
			for lane: int in lanes:
				if lane != opening:
					all_but.append(lane)
			red_ok = red_ok and (e["lanes"] as Array) == all_but
			buttress_ok = buttress_ok and opening >= 1 and opening <= lanes - 2
			continue
		var want: Array[int] = GoldenConvergenceTuning.covered_lanes(lanes, vertical % 2)
		parity_ok = parity_ok and (e["lanes"] as Array) == want
		vertical = (vertical + 1) % 2
	check(parity_ok and (warned[0]["lanes"] as Array).has(0), "the first vertical pass covers lanes 1, 3, 5 counting from 1, the next the others %s" % tag)
	check(buttress_ok and red_ok, "each horizontal pass's buttress is in an inner lane, its red line over every other lane %s" % tag)
	# Each buttress up in time, within reach from the farthest lane (the strafe's: those at a horizontal pass's
	# line; the slams' gates are test_golden_convergence_slams's).
	var lines: Array[float] = []
	for e: Dictionary in warned:
		if String(e["kind"]) == "H":
			lines.append(float(e["line"]))
	var strafe_gates: Array[Dictionary] = _events(boss, &"buttress_placed").filter(func(e: Dictionary) -> bool:
		return lines.any(func(line: float) -> bool: return is_equal_approx(line, float(e["at"]))))
	var reach_ok: bool = true
	var least_sight: float = INF
	for e: Dictionary in strafe_gates:
		var lane: int = int(e["lane"])
		var sight: float = (float(e["at"]) - float(e["runner"])) / speed
		least_sight = minf(least_sight, sight)
		var far: int = maxi(lane, lanes - 1 - lane)
		reach_ok = reach_ok and sight >= REACTION + far * tuning.lane_switch_time + 1.0
	check(least_sight >= t.buttress_sight - 0.1 and reach_ok,
		"each buttress rises at least %.0f s before its line (%.1f s), in reach from the farthest lane %s" % [t.buttress_sight, least_sight, tag])
	check(strafe_gates.size() == 2 and _events(boss, &"pass_spark").size() == 2,
		"one buttress for each horizontal pass, the bullets sparking off it %s" % tag)
	_check_watch(rec, tag)
	var gates_moved: int = _events(boss, &"buttress_placed").size() + _events(boss, &"buttress_sunk").size()
	check(_sounds(boss, &"gc_whine") == warned.size() and _sounds(boss, &"gc_emerge") == 2 and _sounds(boss, &"gc_return") == 2
		and _sounds(boss, &"gc_buttress") == gates_moved,
		"each pass's whine sounds with its red lines; the squadron out and back with its sounds; each gate rising or sinking with its own %s" % tag)
	check(hints.count("golden_boss/strafe") == 1 and hints.count("golden_boss/buttress") == 1,
		"the strafe's hint comes with its first pass, the buttress's with the first gate %s" % tag)
	check(boss.fire.scorch_marks().size() > 0, "the fire leaves its scorch marks %s" % tag)
	var dark: bool = Color(GoldenConvergenceFire.SCORCH_COLOR).v < 0.3
	check(dark, "dark ones, never glowing (what looks like a hit is a hit)")
	print("  Golden Convergence %s: %d passes, the fire's least lead %.2f s, buttresses up %.1f s ahead at the least, strafes done at %.1f s" % [
		tag, warned.size(), rec["lead"], least_sight, boss.fight_time()])
	await sim.free_world(world)


# --- Phases 2 and 3: the 7-pass strafe -------------------------------------------------------------

func _test_seven_passes() -> void:
	var pair: Array = _fight(5, 25.0, null, 1)
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var bot := _bot(boss)
	var cause: Array[String] = _death(world)
	var rec: Dictionary = _record()
	var behind := {"from_behind": 0, "behind_ok": true}
	await _run(world, bot, 110.0, func() -> bool: return _events(boss, &"strafe_done").size() >= 1, func() -> void:
		_watch(boss, rec)
		var s: GoldenConvergenceStrafe = boss.strafe
		if s.current >= 0 and String(s.passes[s.current]["kind"]) == "v" \
				and int(s.passes[s.current]["stage"]) == GoldenConvergenceStrafe.PassStage.FIRE:
			behind["from_behind"] = int(behind["from_behind"]) + 1
			var p: Dictionary = s.passes[s.current]
			if float(p["t"]) - boss.tuning.warning_seconds < 0.1:
				# Just opened up: behind the runner, raking forward.
				behind["behind_ok"] = bool(behind["behind_ok"]) and float(p["front"]) < boss.player_distance())
	var tag: String = "(phase 2, 5 lanes, 25 m/s)"
	var starts: Array[Dictionary] = _events(boss, &"strafe_start")
	check(_events(boss, &"beat_stub").is_empty() and _events(boss, &"slams_done").size() == 2
		and _events(boss, &"barrage_out").size() == 2 and boss.slams.fist.hits.is_empty() and boss.barrage.missiles.hits.is_empty(),
		"two slam sequences and barrages, played through untouched %s" % tag)
	check(starts.size() == 1 and String(starts[0]["script"]) == "VVHvVHv", "then the Refill Ship's 7-pass strafe %s" % tag)
	var kinds: String = ""
	var vertical: int = 0
	var parity_ok: bool = true
	for e: Dictionary in _events(boss, &"pass_warned"):
		kinds += String(e["kind"])
		if String(e["kind"]) != "H":
			parity_ok = parity_ok and (e["lanes"] as Array) == GoldenConvergenceTuning.covered_lanes(5, vertical % 2)
			vertical += 1
	check(kinds == "VVHvVHv", "V-V-H-V-V-H-V, the 4th and 7th from behind (%s) %s" % [kinds, tag])
	check(parity_ok, "the covered lanes switch every vertical pass %s" % tag)
	check(int(behind["from_behind"]) > 0 and bool(behind["behind_ok"]), "the passes from behind open up behind the runner, raking forward %s" % tag)
	check(world.player.alive and boss.fire.hits.is_empty(), "the bot gets through untouched (%s) %s" % [cause[0], tag])
	_check_watch(rec, tag)
	await sim.free_world(world)


# --- What hits ---------------------------------------------------------------------------------------

## A runner who stays in a raked lane is hit there once the warning is over.
func _test_stays_in_lane() -> void:
	var pair: Array = _fight(5, 18.0, null, -1, "strafe:V")
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var bot := _bot(boss)
	bot.dodges = false
	bot.home_lane = 2
	var cause: Array[String] = _death(world)
	await _run(world, bot, 20.0)
	var hits: Array[Dictionary] = _events(boss, &"strafe_hit")
	var warned: Array[Dictionary] = _events(boss, &"pass_warned")
	check(not world.player.alive and cause[0] == "the helidrones' guns", "a runner who stays in a raked lane is hit (%s)" % cause[0])
	check(hits.size() == 1 and String(hits[0]["kind"]) == "rake" and int(hits[0]["lane"]) == 2 and not warned.is_empty()
		and float(hits[0]["t"]) >= float(warned[0]["t"]) + boss.tuning.warning_seconds,
		"in its warned lane, once its warning is over (%s)" % [hits])
	await sim.free_world(world)


## A runner who stays out of the arch on a horizontal pass is hit by the live line, jumping or not.
func _test_stays_out_of_the_arch() -> void:
	for jump: bool in [false, true]:
		var pair: Array = _fight(5, 18.0, null, -1, "strafe:H")
		var world: RunWorld = pair[0]
		var boss: GoldenConvergence = pair[1]
		var bot := _bot(boss)
		bot.takes_cover = false
		# The outer lane: never a buttress's.
		bot.home_lane = 0
		var cause: Array[String] = _death(world)
		var jumped := {"done": false}
		await _run(world, bot, 20.0, Callable(), func() -> void:
			var s: GoldenConvergenceStrafe = boss.strafe
			if not jump or bool(jumped["done"]) or s.passes.is_empty():
				return
			var line: float = float(s.passes[0].get("line_at", INF))
			# Jump so the apex comes at the line.
			if boss.player_distance() >= line - boss.speed_planned() * tuning.jump_time_to_apex - 0.8:
				world.player.press(&"jump")
				jumped["done"] = true)
		var hits: Array[Dictionary] = _events(boss, &"strafe_hit")
		var opening: int = int(_events(boss, &"pass_warned")[0]["opening"]) if not _events(boss, &"pass_warned").is_empty() else -1
		var tag: String = "(jumping)" if jump else "(running)"
		check(not world.player.alive and hits.size() == 1 and String(hits[0]["kind"]) == "line" and int(hits[0]["lane"]) != opening,
			"a runner out of the arch is hit by the live line %s (%s, %s)" % [tag, cause[0], hits])
		await sim.free_world(world)


## The armor blocks the fire (one touch, its second of invulnerability); the dash passes through the live line.
func _test_armor_and_dash() -> void:
	var armored := Loadout.new()
	armored.armor = true
	var pair: Array = _fight(5, 18.0, armored, -1, "strafe:V")
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var bot := _bot(boss)
	bot.dodges = false
	bot.home_lane = 2
	await _run(world, bot, 12.0, func() -> bool: return _events(boss, &"pass_done").size() >= 1)
	var hits: Array[Dictionary] = _events(boss, &"strafe_hit")
	check(world.player.alive and hits.size() == 1 and int(hits[0]["outcome"]) == DamageRules.Outcome.BLOCKED_ARMOR,
		"the armor blocks the rake, once (%s)" % [hits])
	await sim.free_world(world)
	var dasher := Loadout.new()
	dasher.tiers[&"dash"] = 1
	pair = _fight(5, 18.0, dasher, -1, "strafe:H")
	world = pair[0]
	boss = pair[1]
	bot = _bot(boss)
	bot.takes_cover = false
	bot.home_lane = 0
	var dashed := {"done": false}
	await _run(world, bot, 14.0, func() -> bool: return _events(boss, &"pass_done").size() >= 1, func() -> void:
		var s: GoldenConvergenceStrafe = boss.strafe
		if bool(dashed["done"]) or s.passes.is_empty() or not s.passes[0].has("line_at"):
			return
		if boss.player_distance() >= float(s.passes[0]["line_at"]) - 4.0:
			dashed["done"] = (world.powerups as PowerupController).dash.trigger())
	check(bool(dashed["done"]) and world.player.alive and _events(boss, &"pass_done").size() == 1 and world.player.lane == 0
		and boss.fire.hits.is_empty(), "the dash carries the runner through the live line (%s)" % [boss.fire.hits])
	await sim.free_world(world)


# --- The wall rule -------------------------------------------------------------------------------------

## GDD §10: "fire in an outer lane hits a runner low on the wall but not one high up"; the live line "up both
## walls at every height". The right wall opened beside the right lane; the runner enters it `before` seconds
## before a vertical pass's fire reaches them (a wall run starts high and slides down).
func _test_wall_rule() -> void:
	for high: bool in [true, false]:
		var pair: Array = _fight(5, 18.0, null, -1, "strafe:V")
		var world: RunWorld = pair[0]
		var boss: GoldenConvergence = pair[1]
		var cause: Array[String] = _death(world)
		await _run(world, null, 0.2)
		for i: int in 2:
			world.player.press(&"move_right")
			await _run(world, null, 0.3)
		boss.court.open_wall(1, world.player.distance + 5.0, world.player.distance + 600.0)
		var before: float = 0.45 if high else 1.8
		var state := {"entered": false}
		await _run(world, null, 20.0, func() -> bool: return _events(boss, &"pass_done").size() >= 1, func() -> void:
			var s: GoldenConvergenceStrafe = boss.strafe
			if s.passes.is_empty() or bool(state["entered"]):
				return
			var p: Dictionary = s.passes[0]
			if int(p["stage"]) != GoldenConvergenceStrafe.PassStage.WAIT and int(p["stage"]) != GoldenConvergenceStrafe.PassStage.WARN:
				return
			# When its front reaches the runner: its warning (still to come, or under way), then the front
			# closing in at the rake's speed plus the run's.
			var t: GoldenConvergenceTuning = boss.tuning
			var v: float = boss.speed_planned()
			var d: float = boss.player_distance()
			var closing: float = t.rake_speed * boss.run_pace() + v
			var to_warn: float = maxf(float(p["warn_at"]) - d, 0.0) / v if int(p["stage"]) == GoldenConvergenceStrafe.PassStage.WAIT else 0.0
			var to_fire: float = to_warn + t.warning_seconds - (float(p["t"]) if int(p["stage"]) == GoldenConvergenceStrafe.PassStage.WARN else 0.0)
			var meet: float = to_fire + (float(p["to"]) - GoldenConvergenceFire.RAKE_DEPTH * 0.5 - (d + v * to_fire)) / closing
			if meet <= before:
				world.player.press(&"move_right")
				state["entered"] = true)
		var hits: Array[Dictionary] = boss.fire.hits
		var tag: String = "high on the wall" if high else "low on the wall"
		if high:
			check(world.player.alive and hits.is_empty(), "a runner %s is safe from an outer lane's rake (%s)" % [tag, hits])
		else:
			check(not world.player.alive and hits.size() == 1 and String(hits[0]["kind"]) == "rake_wall"
				and int(hits[0]["surface"]) == Player.Surface.WALL and float(hits[0]["h"]) < boss.tuning.wall_fire_height,
				"a runner %s is hit by it (%s, %s)" % [tag, cause[0], hits])
		await sim.free_world(world)
	# The live line up the wall at every height.
	var pair: Array = _fight(5, 18.0, null, -1, "strafe:H")
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	await _run(world, null, 0.2)
	for i: int in 2:
		world.player.press(&"move_left")
		await _run(world, null, 0.3)
	boss.court.open_wall(-1, world.player.distance + 5.0, world.player.distance + 600.0)
	var entered := {"done": false}
	await _run(world, null, 20.0, func() -> bool: return _events(boss, &"pass_done").size() >= 1, func() -> void:
		var s: GoldenConvergenceStrafe = boss.strafe
		if bool(entered["done"]) or s.passes.is_empty() or not s.passes[0].has("line_at"):
			return
		if boss.player_distance() >= float(s.passes[0]["line_at"]) - boss.speed_planned() * 0.4:
			world.player.press(&"move_left")
			entered["done"] = true)
	var line_hits: Array[Dictionary] = boss.fire.hits
	check(not world.player.alive and line_hits.size() == 1 and String(line_hits[0]["kind"]) in ["line", "line_wall"]
		and int(line_hits[0]["surface"]) == Player.Surface.WALL and float(line_hits[0]["h"]) > boss.tuning.wall_fire_height,
		"the live line hits a runner high on an open wall (%s)" % [line_hits])
	await sim.free_world(world)


# --- The pad, the hold -----------------------------------------------------------------------------------

## GDD §9.6, §10: a pad hurls the whole squadron up while it's out, and the strafe is over.
func _test_pad() -> void:
	var pair: Array = _fight(5, 18.0, null, -1, "strafe:VVH")
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	world.player.god_mode = true
	var hurled: Array[int] = [0]
	boss.strafe.hurled.connect(func() -> void: hurled[0] += 1)
	var out: Array[int] = [0]
	boss.squadron.hurled_out.connect(func() -> void: out[0] += 1)
	await _run(world, null, 15.0, func() -> bool: return _events(boss, &"pass_done").size() >= 1)
	var lane: int = world.player.lane
	var d: float = world.player.distance
	boss.props.ceiling(d + 10.0, d + 60.0)
	boss.props.pad(lane, d + 20.0)
	var warned: int = _events(boss, &"pass_warned").size()
	await _run(world, null, 4.0, func() -> bool: return hurled[0] > 0)
	check(hurled[0] == 1 and _events(boss, &"squadron_hurled").size() == 1 and _sounds(boss, &"gc_hurl") == 1,
		"stepping on a pad hurls the squadron up (GDD §9.6), and says so")
	await _run(world, null, 3.0, func() -> bool: return not boss.strafe.busy())
	var done: Array[Dictionary] = _events(boss, &"strafe_done")
	check(not boss.strafe.busy() and done.size() == 1 and bool(done[0].get("hurled", false)), "which ends the strafe")
	check(boss.squadron.crashed == boss.squadron.size() and out[0] == 1 and boss.squadron.out_count() == 0,
		"every drone crashes (%d of %d)" % [boss.squadron.crashed, boss.squadron.size()])
	check(_events(boss, &"pass_warned").size() == warned and not boss.fire.live(), "no pass comes after it")
	await sim.free_world(world)


## hold(true) takes the pass under way away at once (warnings and fire), the squadron holding; hold(false)
## brings the passes left on from where the runner is.
func _test_hold() -> void:
	var pair: Array = _fight(5, 18.0, null, -1, "strafe:VVH")
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var bot := _bot(boss)
	await _run(world, bot, 15.0, func() -> bool: return boss.strafe.current >= 0)
	check(boss.strafe.warning_on() and boss.props.warned(int(_events(boss, &"pass_warned")[0]["lanes"][0]), 0.0, 1e6),
		"a pass warns")
	boss.strafe.hold(true)
	check(not boss.strafe.warning_on() and not boss.fire.live() and boss.strafe.current < 0
		and _events(boss, &"strafe_held").size() == 1, "held: its warnings and fire are gone at once")
	var quiet := {"ok": true}
	var warned: int = _events(boss, &"pass_warned").size()
	await _run(world, bot, 3.0, Callable(), func() -> void:
		quiet["ok"] = bool(quiet["ok"]) and not boss.fire.live() and boss.strafe.current < 0 and boss.squadron.out_count() == boss.squadron.size())
	check(bool(quiet["ok"]) and _events(boss, &"pass_warned").size() == warned, "nothing fires while it holds, the squadron hovering")
	boss.strafe.hold(false)
	await _run(world, bot, 30.0, func() -> bool: return not boss.strafe.busy())
	check(_events(boss, &"pass_warned").size() == warned + 3 and _events(boss, &"strafe_done").size() == 1,
		"released, the held pass and the ones after it come")
	check(world.player.alive and boss.fire.hits.is_empty(), "and the bot gets through them untouched")
	await sim.free_world(world)


# --- The same every attempt -----------------------------------------------------------------------------

func _test_same_every_attempt() -> void:
	var logs: Array[String] = []
	for attempt: int in 2:
		var pair: Array = _fight(6, 25.0)
		var world: RunWorld = pair[0]
		var boss: GoldenConvergence = pair[1]
		var bot := _bot(boss)
		await _run(world, bot, 40.0)
		logs.append(JSON.stringify(boss.events))
		await sim.free_world(world)
	check(logs[0] == logs[1] and logs[0].length() > 100, "it plays the same on every attempt (the whole log of 40 s)")

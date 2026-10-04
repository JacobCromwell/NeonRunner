extends TestSuite
## The Sewer Swarm's screeches on the walls and its surges in pairs (owner's requests, docs/USER_REQUESTS.md):
## - every screech shown on a wall is an attack: the climb (phases 2 and 3) and an idle cluster's wall mound
##   (phases 1 and 2) hurt a runner touching them as any attack does (armor blocks it, the shield breaks,
##   grace and god mode let it by, unprotected it kills) and knock a runner on that wall off it, protected or
##   not; their hitboxes are live only while they're shown there;
## - they keep their own colours: nothing on a wall heats to enemy-attack red;
## - phase 3: the climb parts over each of the Host's ramps (its approach, the ramp, the wall run, the jump and
##   the landing) and the runner taking it never touches it, while the rest of that wall stays covered and
##   hurts; the shader's hole is the hitboxes' hole;
## - phase 2: from behind and ahead at once, two surges charge two different lanes, live together, leaving
##   every other lane (lanes - 2) safe, at 3, 5 and 6 lanes and 18 and 21.8 m/s, their warnings (about 1.55 s
##   ahead, 1.7 s behind) and lock windows (0.9 s and 1.0 s) measured;
## - the phase changes, the win and a retry leave nothing on the walls.

const BOSS_PATH: String = "res://data/bosses/gangland_boss.tres"
const LANES: Array[int] = [3, 5, 6]
const SPEEDS: Array[float] = [18.0, 21.8]
const SHADER_PATH: String = "res://scripts/bosses/sewer_swarm/swarm_crowd.gdshader"
const HOST_PHASE: int = 2
const REACTION: float = 0.35

var sim: RunSim
var def: BossDef


func run() -> void:
	sim = RunSim.new(tree, tuning)
	var slot := load(BOSS_PATH) as BossDef
	def = slot if slot != null and slot.is_built() else null
	if def == null:
		check(false, "the Sewer Swarm's fight is built")
		return
	await _test_climb_hurts()
	await _test_mound_hurts()
	_test_natural_colours()
	await _test_pairs()
	await _test_route()
	await _test_transitions()


# --- Helpers -------------------------------------------------------------------------------------

## The fight at `lanes` and `speed` m/s from phase `phase` (-1: from its start): [world, boss, context].
func _fight(lanes: int, speed: float, phase: int = -1, ctx_in: RunContext = null) -> Array:
	var ctx: RunContext = ctx_in
	if ctx == null:
		var t: MovementTuning = tuning
		if not is_equal_approx(speed, tuning.run_speed):
			t = tuning.duplicate() as MovementTuning
			t.run_speed = speed
		ctx = RunContext.new()
		ctx.mode = RunContext.Mode.QUICK
		ctx.boss = def.duplicate() as BossDef
		ctx.boss.armor_rule = false
		ctx.config = BossArena.base_config(def)
		ctx.config.lane_count = lanes
		ctx.tuning = t
		if phase >= 0:
			ctx.boss_resume = {"phase": phase}
	var boss := BossEncounter.create(ctx.boss) as SewerSwarm
	var arena: BossArena = boss.plan_arena(ctx)
	var world: RunWorld = sim.build_world(arena.layout, ctx.loadout, ctx.tuning, ctx.config)
	boss.setup(world, ctx, arena)
	return [world, boss, ctx]


## Steps the fight until `done` holds, the runner dies or `seconds` pass, calling `each` every frame.
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


func _events(boss: BossEncounter, event: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in boss.events:
		if e["event"] == event:
			out.append(e)
	return out


func _of(boss: BossEncounter, event: StringName, n: int) -> Dictionary:
	for e: Dictionary in _events(boss, event):
		if int(e["n"]) == n:
			return e
	return {}


## Puts the runner on the street in `lane` at its distance now, in the middle of the lane.
func _place(player: Player, lane: int) -> void:
	player.lane = lane
	player.set(&"_x", player.geo.lane_x(lane))
	player.set(&"_switch_t", 1.0)
	player.set(&"_bumping", false)
	player.surface = Player.Surface.FLOOR
	player.h = 0.0
	player.vh = 0.0
	player.grounded = true
	player.in_pit = false


## How the runner is protected for a touch: "armor", "shield", "grace" or "none".
func _protect(player: Player, how: String) -> void:
	player.armor = 1 if how == "armor" else 0
	player.shield = 1 if how == "shield" else 0
	player.invulnerable_left = 3.0 if how == "grace" else 0.0


## The track stretch (from, to) a world-space box covers.
func _track_span(b: AABB) -> Vector2:
	return Vector2(-(b.position.z + b.size.z), -b.position.z)


## What a protected (or unprotected) touch did: checks it hurt as an attack and knocked the runner off.
func _check_touch(how: String, outcomes: Array, player: Player, repelled: bool, cause: String, what: String) -> void:
	match how:
		"armor":
			check(outcomes.has(DamageRules.Outcome.BLOCKED_ARMOR) and player.alive and player.armor == 0 and repelled,
				"%s: armor blocks its touch as an enemy attack's, and the runner is knocked off the wall" % what)
		"shield":
			check(outcomes.has(DamageRules.Outcome.BLOCKED_SHIELD) and player.alive and player.shield == 0 and repelled,
				"%s: the shield breaks on its touch, and the runner is knocked off the wall" % what)
		"grace":
			check(outcomes.is_empty() and player.alive and repelled,
				"%s: in the grace after a hit its touch does no harm, but the runner is still knocked off the wall" % what)
		"none":
			check(not player.alive and cause == "the Sewer Swarm",
				"%s: unprotected its touch kills (%s)" % [what, cause if cause != "" else "alive"])


# --- The climb hurts ------------------------------------------------------------------------------

## Phase 2's climb: a runner jumping onto the climbed wall is hurt as by any attack (armor, shield, grace,
## none) and knocked off it; at both speeds.
func _test_climb_hurts() -> void:
	for speed: float in SPEEDS:
		var pair: Array = _fight(5, speed, 1)
		var world: RunWorld = pair[0]
		var boss: SewerSwarm = pair[1]
		var t: SewerSwarmTuning = boss.tuning
		var player: Player = world.player
		check(is_equal_approx(boss.climb.ahead, t.climb_ahead)
			and boss.climb.crowd.multimesh.visible_instance_count == t.climb_size(boss.low_end)
			and boss.climb.crowd.count > t.climb_size(boss.low_end),
			"phase 2's climb reaches climb_ahead with its %d screeches, phase 3's extra pooled (%d) undrawn (%.1f m/s)" % [
			t.climb_size(boss.low_end), boss.climb.crowd.count, speed])
		var outcomes: Array = []
		for box: Hazard in boss.climb.boxes:
			box.contacted.connect(func(o: int) -> void: outcomes.append(o))
		var cause: Array = [""]
		player.died.connect(func(c: String) -> void: cause[0] = c)
		var unseen: Array = [0]
		var bot := SewerSwarmBot.new(boss)
		bot.baits = false
		bot.avoids_surge_baits = true
		bot.reaction = REACTION
		for how: String in ["armor", "shield", "grace", "none"]:
			var tag: String = "the climb (%s, %.1f m/s)" % [how, speed]
			var ready: Array = [false]
			await _run(world, 60.0, func() -> bool: return bool(ready[0]), func() -> void:
				bot.step()
				var c: SwarmClimb = boss.climb
				var d: float = player.distance
				var lane: int = 0 if c.side < 0 else 4
				if (not c.hit_boxes().is_empty() and not c.crowd.visible) or (c.rise >= 0.2 and c.hit_boxes().is_empty()):
					unseen[0] = int(unseen[0]) + 1
				ready[0] = c.state == SwarmClimb.State.CLIMB and c.rise >= 1.0 \
					and c.t <= t.climb_seconds - t.climb_rise_seconds - 1.0 and player.surface == Player.Surface.FLOOR \
					and not player.is_invulnerable() and boss.surges.active.is_empty() \
					and boss.arena.floor_clear(d - 2.0, d + 14.0, lane) and not bool(player.call(&"_wall_blocked", c.side)))
			if not bool(ready[0]):
				check(false, "%s: a climb to try" % tag)
				continue
			var side: int = boss.climb.side
			var repels: int = _events(boss, &"wall_repel").size()
			_protect(player, how)
			_place(player, 0 if side < 0 else 4)
			outcomes.clear()
			player.press(&"move_left" if side < 0 else &"move_right")
			await physics_frames(10)
			var repelled: bool = _events(boss, &"wall_repel").size() > repels and player.surface != Player.Surface.WALL
			_check_touch(how, outcomes, player, repelled, cause[0], tag)
		check(int(unseen[0]) == 0, "the climb's hitboxes are live only while it's shown risen on the wall (%.1f m/s)" % speed)
		await sim.free_world(world)


# --- The wall mound hurts ----------------------------------------------------------------------------

## An idle cluster's wall mound (phase 1 here): a runner on its wall reached by it is hurt as by any attack and
## knocked off the wall; its hitboxes are live only while it's shown there.
func _test_mound_hurts() -> void:
	var pair: Array = _fight(5, 18.0, 0)
	var world: RunWorld = pair[0]
	var boss: SewerSwarm = pair[1]
	var player: Player = world.player
	var outcomes: Array = []
	for c: SwarmCluster in boss.clusters:
		for box: Hazard in c.mound_boxes:
			box.contacted.connect(func(o: int) -> void: outcomes.append(o))
	var cause: Array = [""]
	player.died.connect(func(c: String) -> void: cause[0] = c)
	var wrong: Array = [0]
	var bot := SewerSwarmBot.new(boss)
	bot.baits = false
	bot.avoids_surge_baits = true
	bot.reaction = REACTION
	var check_mounds := func() -> void:
		for c: SwarmCluster in boss.clusters:
			if not is_instance_valid(c):
				continue
			var live: bool = not c.mound_hit_boxes().is_empty()
			# (Within a hair of MOUND_SHOWN either way it may still be a frame behind.)
			var shown: float = c.mound_shown()
			if (live and (shown < SwarmCluster.MOUND_SHOWN - 0.02 or not c.crowd.visible)) \
					or (not live and shown > SwarmCluster.MOUND_SHOWN + 0.02):
				wrong[0] = int(wrong[0]) + 1
	for how: String in ["armor", "shield", "grace", "none"]:
		var tag: String = "a wall mound (%s)" % how
		var pick: Array = [null]
		await _run(world, 60.0, func() -> bool: return pick[0] != null, func() -> void:
			bot.step()
			check_mounds.call()
			if boss.step != SewerSwarm.Step.FIGHT or not boss.surges.active.is_empty() or player.is_invulnerable() \
					or player.surface != Player.Surface.FLOOR:
				return
			var d: float = player.distance
			for c: SwarmCluster in boss.queue:
				var lane: int = 0 if c.side < 0 else 4
				if c.mound_shown() >= 0.9 and boss.arena.floor_clear(d - 2.0, d + 14.0, lane) \
						and not bool(player.call(&"_wall_blocked", c.side)):
					pick[0] = c
					return)
		var cl: SwarmCluster = pick[0]
		if cl == null:
			check(false, "%s: a mound to try" % tag)
			continue
		_place(player, 0 if cl.side < 0 else 4)
		player.press(&"move_left" if cl.side < 0 else &"move_right")
		await physics_frames(3)
		if player.surface != Player.Surface.WALL:
			check(false, "%s: the runner gets on the mound's wall" % tag)
			continue
		var repels: int = _events(boss, &"wall_repel").size()
		_protect(player, how)
		outcomes.clear()
		# The mound comes up from behind along the wall (as a gathering mound is run into).
		boss._offsets[cl.get_instance_id()] = -4.0
		var hit: Array = [false]
		await _run(world, 1.0, func() -> bool: return bool(hit[0]), func() -> void:
			hit[0] = _events(boss, &"wall_repel").size() > repels)
		var repelled: bool = bool(hit[0]) and _events(boss, &"wall_repel")[-1]["what"] == "mound" \
			and player.surface != Player.Surface.WALL
		_check_touch(how, outcomes, player, repelled, cause[0], tag)
	check(int(wrong[0]) == 0, "a mound's hitboxes are live exactly while it's shown on the wall, never unseen")
	await sim.free_world(world)


# --- Natural colours ------------------------------------------------------------------------------------

## Screeches on a wall keep their own colours (no enemy-attack red): the climb never heats and a mound's
## clinging screeches only heat once they've left the wall for the lane.
func _test_natural_colours() -> void:
	var src: String = (load(SHADER_PATH) as Shader).code
	var at3: int = src.find("else if (kind == 3)")
	var at4: int = src.find("else if (kind == 4)")
	var climb: String = src.substr(at3, at4 - at3) if at3 >= 0 and at4 > at3 else ""
	check(climb != "" and not climb.contains("bristle") and src.contains("float bristle = 0.25;"),
		"the climb's screeches stay at rest's heat (bristle 0.25): no attack red on the wall")
	check(src.contains("heat_bristle = mix(0.25, bristle, smoothstep(0.05, 0.35, p));")
		and src.contains("v_bristle = heat_bristle >= 0.0 ? heat_bristle : bristle;"),
		"a mound's clinging screeches keep their own colours until they pour off the wall")


# --- Surges in pairs ------------------------------------------------------------------------------------

## Phase 2, nobody baiting: from behind and ahead at once two surges charge two different lanes, both live
## together, every other lane safe, at 3, 5 and 6 lanes and both speeds; their warnings measured.
func _test_pairs() -> void:
	for speed: float in SPEEDS:
		for lanes: int in LANES:
			await _pairs(lanes, speed)


func _pairs(lanes: int, speed: float) -> void:
	var tag: String = "(%d lanes, %.1f m/s)" % [lanes, speed]
	var pair: Array = _fight(lanes, speed, 1)
	var world: RunWorld = pair[0]
	var boss: SewerSwarm = pair[1]
	var t: SewerSwarmTuning = boss.tuning
	var player: Player = world.player
	var bot := SewerSwarmBot.new(boss)
	bot.baits = false
	bot.avoids_surge_baits = true
	bot.reaction = REACTION
	var seen := {"most": 0, "both": 0, "safe": lanes, "arrive": {}}
	await _run(world, 90.0, func() -> bool: return _events(boss, &"surge_pass").size() >= 6, func() -> void:
		bot.step()
		var live: Dictionary = {}
		var fronts: int = 0
		var rears: int = 0
		for c: SwarmCluster in boss.clusters:
			if is_instance_valid(c) and c.alive and c.hitbox.is_active():
				live[c.lane] = true
				if c.stage == SwarmCluster.Stage.WAVE or c.forward:
					rears += 1
				else:
					fronts += 1
		seen["most"] = maxi(int(seen["most"]), live.size())
		seen["safe"] = mini(int(seen["safe"]), lanes - live.size())
		if live.size() == 2 and fronts >= 1 and rears >= 1:
			seen["both"] = int(seen["both"]) + 1
		# A surge ahead reaching the runner's distance (its warning's whole length).
		for s: Dictionary in boss.surges.active:
			var c: SwarmCluster = s["cluster"]
			if not bool(s["behind"]) and is_instance_valid(c) and int(s["locked"]) >= 0 and c.at <= player.distance \
					and not (seen["arrive"] as Dictionary).has(int(s["n"])):
				seen["arrive"][int(s["n"])] = boss.fight_time())
	check(player.alive and _events(boss, &"surge_hit").is_empty(), "a runner reading them is never touched %s" % tag)
	check(int(seen["most"]) == 2 and int(seen["both"]) > 0 and int(seen["safe"]) == lanes - 2,
		"from behind and ahead at once two surges are live in two different lanes, %d lanes safe (%d frames) %s" % [
		lanes - 2, int(seen["both"]), tag])
	var front := {"lock": [], "total": []}
	var rear := {"lock": [], "total": []}
	for w: Dictionary in _events(boss, &"surge_warn"):
		var n: int = int(w["n"])
		var lock: Dictionary = _of(boss, &"surge_lock", n)
		if lock.is_empty():
			continue
		var lead: float = float(lock["t"]) - float(w["t"])
		if bool(w["behind"]):
			var crash: Dictionary = _of(boss, &"surge_crash", n)
			if not crash.is_empty():
				rear["lock"].append(float(crash["t"]) - float(lock["t"]))
				rear["total"].append(float(crash["t"]) - float(w["t"]))
		elif (seen["arrive"] as Dictionary).has(n):
			front["lock"].append(float(seen["arrive"][n]) - float(lock["t"]))
			front["total"].append(float(seen["arrive"][n]) - float(w["t"]))
		if not bool(w["behind"]):
			check(absf(lead - (t.warning_seconds - t.lock_seconds)) < 0.03, "a surge ahead locks on time %s" % tag)
	var f_lock: float = _mean(front["lock"])
	var f_total: float = _mean(front["total"])
	var r_lock: float = _mean(rear["lock"])
	var r_total: float = _mean(rear["total"])
	check(absf(f_total - t.warning_seconds) < 0.15 and absf(f_lock - t.lock_seconds) < 0.15,
		"a surge ahead reaches the runner %.2f s after its warning (%.2f s after its lock) %s" % [f_total, f_lock, tag])
	check(absf(r_total - t.behind_warning_seconds) < 0.06 and absf(r_lock - t.behind_lock_seconds) < 0.06,
		"a strike from behind crashes %.2f s after its warning (%.2f s after its lock) %s" % [r_total, r_lock, tag])
	print("  Sewer Swarm pairs %s: ahead %.2f s warned, %.2f s locked; behind %.2f s warned, %.2f s locked; %d lanes always safe" % [
		tag, f_total, f_lock, r_total, r_lock, int(seen["safe"])])
	await sim.free_world(world)


func _mean(values: Array) -> float:
	if values.is_empty():
		return -1.0
	var sum: float = 0.0
	for v: float in values:
		sum += v
	return sum / values.size()


# --- Phase 3's routes ---------------------------------------------------------------------------------

## Phase 3: over each of the Host's ramps the climb parts, from before the ramp to past the landing, and the
## runner taking it (approach, ramp, wall run, jump, landing) never touches it, while the rest of that wall
## stays covered with live hitboxes; the shader's hole is the hitboxes'. At every lane count and both speeds.
func _test_route() -> void:
	for speed: float in SPEEDS:
		for lanes: int in LANES:
			await _route(lanes, speed)


func _route(lanes: int, speed: float) -> void:
	var tag: String = "(%d lanes, %.1f m/s)" % [lanes, speed]
	var pair: Array = _fight(lanes, speed, HOST_PHASE)
	var world: RunWorld = pair[0]
	var boss: SewerSwarm = pair[1]
	var t: SewerSwarmTuning = boss.tuning
	var player: Player = world.player
	# Lunges dodged, never baited into a fence: every hit on the Host is a stomp.
	var bot := SewerSwarmBot.new(boss)
	bot.reaction = REACTION
	bot.baits = false
	bot.avoids_baits = true
	var k: float = boss.run_pace()
	var seen := {"touch": 0, "open": 0, "covered": 0, "inside": 0, "after": 0, "drawn": 0, "spans": 0, "wall": 0,
		"in_hole": 0, "air": 0, "least": INF, "reach": 0, "dense": 0}
	# Each stomp's way: launched by its route's ramp (the player's &"ramp", at the ramp onto its side's wall),
	# a wall run in the hole, a wall jump off it, and no landing before the implants.
	var way := {"ramp": false, "wall": false, "air": false, "landed": false}
	var ramp_stomps: Array[int] = []
	var seen_stomps: Array[int] = [0]
	player.movement_event.connect(func(kind: StringName) -> void:
		var spot: Dictionary = boss.climb.route
		if kind == &"ramp":
			way["ramp"] = not spot.is_empty() and player.wall_side == int(spot["side"]) \
				and absf(player.distance - float(spot["at"])) <= 3.0
			way["wall"] = false
			way["air"] = false
		elif kind == &"wall_jump":
			way["air"] = bool(way["wall"])
		elif kind == &"land":
			way["landed"] = true)
	var base_density: float = float(t.climb_size(boss.low_end)) / (t.climb_ahead + t.climb_behind)
	await _run(world, 200.0, func() -> bool: return boss.is_defeated(), func() -> void:
		bot.step()
		var c: SwarmClimb = boss.climb
		if boss.host_attacks.stomps > seen_stomps[0]:
			seen_stomps[0] = boss.host_attacks.stomps
			if bool(way["ramp"]) and bool(way["wall"]) and bool(way["air"]):
				ramp_stomps.append(seen_stomps[0])
		if bool(way["landed"]) or (player.grounded and player.surface == Player.Surface.FLOOR):
			way.assign({"ramp": false, "wall": false, "air": false, "landed": false})
		if player.surface == Player.Surface.WALL and bool(way["ramp"]) and not c.route.is_empty() \
				and player.wall_side == int(c.route["side"]) and player.distance >= c.hole.x \
				and player.distance <= c.hole.y:
			way["wall"] = true
		var body: AABB = player.hurtbox_aabb()
		for b: AABB in c.hit_boxes():
			if b.intersects(body):
				seen["touch"] = int(seen["touch"]) + 1
		if c.route.is_empty() or c.open < 1.0 or c.rise < 1.0:
			return
		var d: float = player.distance
		seen["open"] = int(seen["open"]) + 1
		if c.hole.x <= float(c.route["at"]) - t.route_hole_before * k + 0.01 and c.hole.y >= float(c.route["drop"]):
			seen["spans"] = int(seen["spans"]) + 1
		# Everything of the climb outside the hole (its thinned edges included) is covered by live hitboxes.
		var lo: float = d - t.climb_behind + SwarmClimb.END_INSET
		var hi: float = d + c.ahead - SwarmClimb.END_INSET
		var edge: float = SwarmClimb.FEATHER * 0.5
		var want: float = maxf(minf(c.hole.x - edge, hi) - lo, 0.0) + maxf(hi - maxf(c.hole.y + edge, lo), 0.0)
		var live: float = 0.0
		var ahead_live: float = 0.0
		for b: AABB in c.hit_boxes():
			var span: Vector2 = _track_span(b)
			if span.y <= c.hole.x - edge + 0.01 or span.x >= c.hole.y + edge - 0.01:
				live += span.y - span.x
				ahead_live += maxf(span.y - maxf(span.x, d), 0.0)
				if span.x >= c.hole.y + edge - 0.01:
					seen["after"] = int(seen["after"]) + 1
			else:
				seen["inside"] = int(seen["inside"]) + 1
		if c.side == int(c.route["side"]) and live >= want - 0.5:
			seen["covered"] = int(seen["covered"]) + 1
		# However long the hole, that wall never empties: live screeches stand on it ahead of the runner, drawn
		# (the shader's climb as far as the hitboxes), as dense as the phase-2 climb.
		if c.side == int(c.route["side"]):
			seen["least"] = minf(float(seen["least"]), ahead_live)
		var climb := Vector4(c.crowd.material.get_shader_parameter(&"climb"))
		if c.crowd.visible and absf(climb.y - c.ahead) < 0.01 and absf(climb.z - t.climb_behind) < 0.01:
			seen["reach"] = int(seen["reach"]) + 1
		var shown: int = c.crowd.count if c.crowd.multimesh.visible_instance_count < 0 \
			else c.crowd.multimesh.visible_instance_count
		if float(shown) / (c.ahead + t.climb_behind) >= base_density * 0.98:
			seen["dense"] = int(seen["dense"]) + 1
		var hole := Vector4(c.crowd.material.get_shader_parameter(&"climb_hole"))
		if absf(hole.x - (d - c.hole.y)) < 0.01 and absf(hole.y - (d - c.hole.x)) < 0.01 and hole.z >= 0.99:
			seen["drawn"] = int(seen["drawn"]) + 1
		if player.surface == Player.Surface.WALL and player.wall_side == c.side:
			seen["wall"] = int(seen["wall"]) + 1
			if d >= c.hole.x and d <= c.hole.y:
				seen["in_hole"] = int(seen["in_hole"]) + 1
		elif not player.grounded and bool(c.route["taken"]):
			seen["air"] = int(seen["air"]) + 1)
	var taken: int = 0
	for e: Dictionary in _events(boss, &"route_end"):
		taken += 1 if bool(e["taken"]) else 0
	check(boss.is_defeated() and player.alive and boss.host_attacks.stomps >= 1,
		"a runner taking the Host's ramps through the parted climb wins phase 3 (%d stomps) %s" % [
		boss.host_attacks.stomps, tag])
	check(boss.climb.routes >= 2 and taken >= 1 and _events(boss, &"route").size() == boss.climb.routes,
		"the climb parted over each ramp coming (%d routes, %d taken for %d stomps) %s" % [boss.climb.routes, taken,
		boss.host_attacks.stomps, tag])
	check(int(seen["touch"]) == 0 and _events(boss, &"wall_repel").is_empty(),
		"approach, ramp, wall run, jump and landing: the runner never touches the climb %s" % tag)
	var opened: int = int(seen["open"])
	check(opened > 0 and int(seen["spans"]) == opened and int(seen["inside"]) == 0,
		"each hole spans its ramp's whole way, from before the ramp to past the drop, no hitbox in it %s" % tag)
	check(int(seen["covered"]) == opened and int(seen["after"]) > 0,
		"the rest of that wall stays covered and live, before the hole and past it (%d/%d frames, %d past it) %s" % [
		int(seen["covered"]), opened, int(seen["after"]), tag])
	check(int(seen["drawn"]) == opened, "the screeches part where the hitboxes do (the shader's hole) %s" % tag)
	var want_cover: float = t.route_cover_ahead * k - 0.5
	print("  phase-3 climb %s: reach %.1f m, least %.1f m live ahead outside the hole, %d of %d pooled drawn" % [tag,
		boss.climb.ahead, float(seen["least"]), boss.climb.crowd.multimesh.visible_instance_count, boss.climb.crowd.count])
	check(float(seen["least"]) >= want_cover,
		"that wall never empties: at least %.1f m of live screeches ahead of the runner outside the hole (least %.1f m, reach %.1f m) %s" % [
		want_cover, float(seen["least"]), boss.climb.ahead, tag])
	check(int(seen["reach"]) == opened and int(seen["dense"]) == opened,
		"they're drawn as far as they hurt and as dense as the phase-2 climb (%d/%d drawn, %d/%d dense, %d of %d pooled) %s" % [
		int(seen["reach"]), opened, int(seen["dense"]), opened, boss.climb.crowd.multimesh.visible_instance_count,
		boss.climb.crowd.count, tag])
	check(boss.host_attacks.shocked == 0 and boss.host.hits_taken == boss.host.hits_needed
		and boss.host_attacks.stomps == boss.host.hits_needed and ramp_stomps.size() == boss.host.hits_needed,
		"all %d hits on the Host are stomps by way of a ramp, its wall run and a wall jump (%d stomps, %d by the ramp, %d shocks) %s" % [
		boss.host.hits_needed, boss.host_attacks.stomps, ramp_stomps.size(), boss.host_attacks.shocked, tag])
	check(int(seen["wall"]) > 0 and int(seen["in_hole"]) == int(seen["wall"]) and int(seen["air"]) > 0,
		"the wall run (%d frames) is all inside the hole, and the jump off it (%d frames in the air) clear %s" % [
		int(seen["wall"]), int(seen["air"]), tag])
	await sim.free_world(world)


# --- Phase changes, the win and a retry ---------------------------------------------------------------

## Through a whole fight: nothing is left on the walls when a phase starts or the fight is won; a death on the
## climbed wall's touch and a retry start clean and win.
func _test_transitions() -> void:
	var pair: Array = _fight(5, 18.0, 1)
	var world: RunWorld = pair[0]
	var boss: SewerSwarm = pair[1]
	var ctx: RunContext = pair[2]
	var player: Player = world.player
	var t: SewerSwarmTuning = boss.tuning
	var ready: Array = [false]
	var bot0 := SewerSwarmBot.new(boss)
	bot0.baits = false
	bot0.avoids_surge_baits = true
	bot0.reaction = REACTION
	await _run(world, 60.0, func() -> bool: return bool(ready[0]), func() -> void:
		bot0.step()
		var c: SwarmClimb = boss.climb
		var d: float = player.distance
		ready[0] = c.state == SwarmClimb.State.CLIMB and c.rise >= 1.0 and player.surface == Player.Surface.FLOOR \
			and c.t <= t.climb_seconds - t.climb_rise_seconds - 1.0 and boss.surges.active.is_empty() \
			and boss.arena.floor_clear(d - 2.0, d + 14.0, 0 if c.side < 0 else 4) \
			and not bool(player.call(&"_wall_blocked", c.side)))
	_protect(player, "none")
	_place(player, 0 if boss.climb.side < 0 else 4)
	player.press(&"move_left" if boss.climb.side < 0 else &"move_right")
	await physics_frames(10)
	check(bool(ready[0]) and not player.alive, "a runner jumping unprotected onto the climbed wall dies")
	await sim.free_world(world)
	var next: RunContext = ctx.retry()
	pair = _fight(5, 18.0, -1, next)
	world = pair[0]
	boss = pair[1]
	player = world.player
	check(boss.climb.state == SwarmClimb.State.GAP and boss.climb.hit_boxes().is_empty() and boss.climb.rise == 0.0,
		"the retry starts with nothing on the walls")
	var bot := SewerSwarmBot.new(boss)
	bot.reaction = REACTION
	var seen := {"phase": boss.phase_index, "dirty": 0, "starts": 0}
	await _run(world, 300.0, func() -> bool: return boss.is_defeated() and boss.victory_over(), func() -> void:
		bot.step()
		if boss.phase_index != int(seen["phase"]):
			seen["phase"] = boss.phase_index
			seen["starts"] = int(seen["starts"]) + 1
			if not boss.climb.hit_boxes().is_empty() or boss.climb.state != SwarmClimb.State.GAP or not boss.climb.route.is_empty():
				seen["dirty"] = int(seen["dirty"]) + 1
		if boss.phase_index >= HOST_PHASE:
			for c: SwarmCluster in boss.clusters:
				if is_instance_valid(c) and (not c.mound_hit_boxes().is_empty() or c.hitbox.is_active()):
					seen["dirty"] = int(seen["dirty"]) + 1)
	check(boss.is_defeated() and player.alive, "the retry (from phase %d) is won" % (next.boss_resume.get("phase", 0) + 1))
	check(int(seen["starts"]) >= 1 and int(seen["dirty"]) == 0,
		"each phase (%d) starts with the climb down and the walls clear, and no cluster lingers to hurt in phase 3 (%d not)" % [
		int(seen["starts"]), int(seen["dirty"])])
	var mounds: int = 0
	for c: SwarmCluster in boss.clusters:
		if is_instance_valid(c):
			mounds += c.mound_hit_boxes().size()
	check(boss.climb.hit_boxes().is_empty() and not boss.climb.crowd.visible and mounds == 0,
		"won, nothing on the walls hurts any more")
	await sim.free_world(world)

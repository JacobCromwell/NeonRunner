extends TestSuite
## The Golden Convergence's Refill Ship, the only way to damage the golden suit (GDD §10, "Damaging the suit"; task
## E5d-c), with a runner who plays it by what it shows (GoldenConvergenceBot, reacting REACTION late; no god mode
## unless a test says so):
## - the closed cage at 3, 5 and 6 lanes and at 18 and 25 m/s: its fences flicker in harmlessly, then switch on;
##   every jump that clears its front fence comes down past its pad (the pad never fires under it); a lane switch
##   into it, on the floor or in the air, from either side, touches a side fence;
## - the fence rules: the dash passes, armor and the shield get through at the cost of a hit, claws don't help; an
##   EMP switches off the fences it reaches (the generator's pulse the whole cage: the rides);
## - the rides (the generator's stomp, the dash, armor): the ship flies in and feeds his shoulder; the cage comes
##   up cage_lead ahead, on cage_flicker later; the squadron holds its fire from then until the runner is past the
##   pad (no pass warns or fires), hovering beside the ship; the ship is down at the ceiling's height over every
##   lane before the runner reaches the front fence; the pad hurls the squadron into its racks (the strafe ends),
##   the racks ripple, it spins off and explodes, the blast races up the line and the hit lands (a third of the
##   suit's health: the phase ends; the first ship blows out his right shoulder's pipes); the runner falls back to
##   clear floor unharmed; weapons never target the ship or the generator; its sounds and hints;
## - Reduced flashing (no sparks; the fireballs still show, no hot flash in them) and screen shake off (none);
## - E5d polish, the chain reaction's fire: saturated orange-red fireballs and dark smoke (never a pale peach), all of
##   it above the causeway's level, the ship's blast beside the causeway and in the run camera's view; two draws,
##   nothing made mid-fight;
## - a missed pad: the ship finishes refilling and flies off while the strafe fires on; the beat ends where ends_at()
##   said; the loop goes on from the slams (planned ahead of their beat), and the next ship is the same;
## - the chain reaction plans the next phase's first slams, which open that phase on time;
## - phase 3's ship: the suit bursts open with one blast, the transition's;
## - the review's phase-end fixes (E5d-a/b/d): gates sink at a phase's end rather than pop, a crumbling one crumbles
##   on, a stale gate reference never moves another attack's gate, a dropped slam plan's rows stop keeping pickups
##   off and a new plan's rows keep off its cuts, the arms and the hatches ease to rest through a phase's intro, and
##   a horizontal pass first after a hold keeps its gate's full buttress_sight;
## - the final review's blocker: a lane switch pressed as the runner reaches the pad (swept over the frames around it,
##   on the generator's and the dash's ways in) fires the pad from another lane at least once, and whenever the pad
##   fires the chain reaction starts and the runner never rides the belly longer than a ride does (no failsafe needed);
## - it plays the same on every attempt;
## - E5d polish, F6's ranges: at every end of cage_lead's and generator_before's the generator stays in reach (read,
##   switch in from the farthest lane, jump onto it, a spare moment); played at the worst ends on 6 lanes, the bot
##   stomps it and rides the pad.
## The whole fight (stage 1 won, then stage 2, at every lane count and speed; par times; the campaign):
## test_golden_convergence_whole.gd.

const BOSS_PATH: String = "res://data/bosses/golden_boss.tres"
const STAGE_2: int = 3
const LANES: Array[int] = [3, 5, 6]
## Quick play's speed and the Golden Zone's (GDD §3).
const SPEEDS: Array[float] = [18.0, 25.0]
const REACTION: float = 0.35
const FRAME: float = 1.0 / 60.0
## The sounds E5d-c adds.
const NEW_SOUNDS: Array[StringName] = [&"gc_ship", &"gc_feed", &"gc_ride", &"gc_ripple", &"gc_crash", &"gc_blast",
	&"gc_pipes", &"gc_leave"]
## The cage's pad lane in the cage tests (an inner lane at every lane count) and the lane of its generator.
const PAD_LANE: int = 1
const GEN_LANE: int = 2

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
			await _test_cage(lanes, speed)
	await _test_fence_rules()
	await _test_ride(&"generator", 5, 18.0)
	await _test_ride(&"dash", 3, 25.0)
	await _test_ride(&"armor", 6, 25.0)
	await _test_switch_over_pad()
	await _test_reduced()
	for lanes: int in [3, 6]:
		await _test_blast(lanes)
	await _test_missed()
	await _test_next_phase_planned()
	await _test_phase_three()
	await _test_gates_sink()
	await _test_stale_gate()
	await _test_dropped_plan()
	await _test_looks_ease()
	await _test_hold_sight()
	await _test_same_every_attempt()
	await _test_f6_extremes()


## The fight at `lanes` and `speed` m/s, from phase `phase` (-1: phase 1 past the entrance); every phase's beat
## script `beats` if given (one line for every phase, or a PackedStringArray, a line a phase; the last line goes
## on for the phases after it): [world, boss].
func _fight(lanes: int, speed: float, loadout: Loadout = null, phase: int = -1, beats: Variant = "",
		mutate: Callable = Callable()) -> Array:
	var d: BossDef = def
	var lines := PackedStringArray()
	if beats is PackedStringArray:
		lines = beats
	elif String(beats) != "":
		for i: int in (def.tuning as GoldenConvergenceTuning).phase_beats.size():
			lines.append(String(beats))
	if not lines.is_empty() or mutate.is_valid():
		d = def.duplicate() as BossDef
		var t := (def.tuning as GoldenConvergenceTuning).duplicate() as GoldenConvergenceTuning
		if not lines.is_empty():
			t.phase_beats = lines
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
	if phase > 0:
		ctx.boss_resume = {"phase": phase}
	elif phase < 0:
		ctx.boss_resume = {"phase": 0, "time": 0.0}
	var arena: BossArena = boss.plan_arena(ctx)
	var world: RunWorld = sim.build_world(arena.layout, loadout, tuning, ctx.config)
	boss.setup(world, ctx, arena)
	return [world, boss]


func _bot(boss: GoldenConvergence, way: StringName = &"generator") -> GoldenConvergenceBot:
	var bot := GoldenConvergenceBot.new(boss)
	bot.reaction = REACTION
	bot.refill_way = way
	return bot


func _events(boss: BossEncounter, event: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in boss.events:
		if e["event"] == event:
			out.append(e)
	return out


func _first(boss: BossEncounter, event: StringName) -> Dictionary:
	var found: Array[Dictionary] = _events(boss, event)
	return found[0] if not found.is_empty() else {}


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


## Notes every blow the runner takes (an armor or a shield spent), every pad that fires under them, and how they
## died.
func _watch(player: Player) -> Dictionary:
	var rec := {"blows": [], "pads": 0, "cause": ""}
	player.movement_event.connect(func(kind: StringName) -> void:
		if kind in [&"armor_hit", &"armor_break", &"shield_break"]:
			(rec["blows"] as Array).append(kind)
		elif kind == &"pad":
			rec["pads"] = int(rec["pads"]) + 1)
	player.died.connect(func(c: String) -> void: rec["cause"] = c)
	return rec


## The data: its sounds, its hints, its place in each phase's beats.
func _test_data() -> void:
	var sfx := load("res://data/audio/sfx_library.tres") as SfxLibrary
	var bad: PackedStringArray = []
	for sound: StringName in NEW_SOUNDS:
		if not sfx.volume_db.has(String(sound)) or sfx.stream(sound) == null or sfx.stream(sound).get_length() >= 2.5 \
				or float(sfx.pitch_variation.get(String(sound), 0.0)) != 0.0:
			bad.append(String(sound))
	check(bad.is_empty(), "its %d sounds are in the library, each under 2.5 s and the same every time (%s)" % [NEW_SOUNDS.size(),
		", ".join(bad)])
	var hints: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/hints/hints.json"))
	var triggers: Array[String] = []
	for h: Dictionary in (hints as Dictionary).get("hints", []):
		triggers.append(String(h.get("trigger", "")))
	check(triggers.has("boss:golden_boss/refill") and triggers.has("boss:golden_boss/cage"), "the Refill Ship and its cage have hints")
	var t := def.tuning as GoldenConvergenceTuning
	check(t.phase_beats[0].ends_with("refill:VVH") and t.phase_beats[1].ends_with("refill:VVHvVHv")
		and t.phase_beats[2].ends_with("refill:VVHvVHv"),
		"each phase of stage 1 ends with the Refill Ship, its strafe 3 passes in phase 1 and 7 after (%s)" % [t.phase_beats])
	check(t.loop_from[0] == 1 and t.loop_from[1] == 0 and t.loop_from[2] == 0, "a missed pad loops back to the slams")


# --- The closed cage ----------------------------------------------------------------------------------------

## The closed cage at `lanes` and `speed`: cages placed one after another ahead of a runner in the pad's lane, each
## jumped from a different spot (a sweep across every takeoff that could clear the front fence, and a little past
## either way), then lane switches into one from either side, on the floor and in the air. The runner carries
## shields enough to note every touch without dying.
func _test_cage(lanes: int, speed: float) -> void:
	var tag: String = "(%d lanes, %.0f m/s)" % [lanes, speed]
	var pair: Array = _fight(lanes, speed, null, -1, "none")
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var cage: GoldenConvergenceCage = boss.refill.cage
	var mt: MovementTuning = world.tuning
	var rec: Dictionary = _watch(world.player)
	world.player.shield = 100000
	await _run(world, null, 0.3)
	var air: float = mt.jump_time_to_apex + sqrt(2.0 * mt.jump_height / (mt.gravity() * mt.fall_gravity_multiplier))
	var jump_len: float = speed * air
	# The flicker in, harmless, then on.
	await _settle(world, PAD_LANE)
	var front_at: float = world.player.distance + speed * (boss.tuning.cage_flicker + 0.5) + 10.0
	cage.place(PAD_LANE, GEN_LANE, front_at)
	var warned: bool = true
	for fence: Hazard in cage.fences():
		warned = warned and fence.visible and fence.state == Hazard.State.WARNING and not fence.is_active()
	await _run(world, null, boss.tuning.cage_flicker - 2.0 * FRAME)
	var still: bool = true
	for fence: Hazard in cage.fences():
		still = still and not fence.is_active()
	await _run(world, null, 4.0 * FRAME)
	var on: bool = true
	for fence: Hazard in cage.fences():
		on = on and fence.is_active()
	check(warned and still and on, "its fences flicker in harmlessly for %.1f s (the fence warning), then switch on %s" % [
		boss.tuning.cage_flicker, tag])
	var plan: Dictionary = cage.plan
	check(cage.generator != null and cage.generator.alive and int(plan["gen_lane"]) == GEN_LANE
		and absf(float(plan["front_at"]) - float(plan["gen_at"]) - boss.tuning.generator_before * boss.run_pace()) < 0.01,
		"its generator stands in the lane beside the pad's, generator_before ahead of the front fence %s" % tag)
	await _run(world, null, 20.0, func() -> bool: return world.player.distance > float(plan["side_to"]) + 2.0)
	# The jumps.
	var cleared: Array[float] = []
	var bad: Array[String] = []
	var tries: int = 0
	var off: float = jump_len + 1.5
	var step: float = jump_len / 24.0
	while off > 0.6:
		var r: Dictionary = await _jump_at(world, boss, off, rec)
		tries += 1
		if not bool(r["touched"]):
			cleared.append(float(r["off"]))
			if bool(r["pad"]) or float(r["landed"]) <= float(r["pad_to"]):
				bad.append("off %.2f: landed %.2f past the front, pad %s" % [float(r["off"]), float(r["landed"]) - float(r["front_at"]),
					r["pad"]])
		off -= step
	print("  cage %s: %d jumps, %d cleared the front fence (takeoffs %.1f-%.1f m before it)" % [tag, tries, cleared.size(),
		cleared.min() if not cleared.is_empty() else 0.0, cleared.max() if not cleared.is_empty() else 0.0])
	check(cleared.size() >= 4 and bad.is_empty(),
		"every jump that clears the front fence comes down past the pad, never on it (%d of %d cleared) %s %s" % [cleared.size(), tries,
			tag, bad])
	# The lane switches into it: from the left and from the generator's lane, on the floor and in the air.
	var sides: Array[String] = []
	for air_switch: bool in [false, true]:
		for from: int in [PAD_LANE - 1, PAD_LANE + 1]:
			var r: Dictionary = await _switch_in(world, boss, from, air_switch, rec)
			var want: int = 0 if from < PAD_LANE else 1
			if not bool(r["side"]) or int(r["which"]) != want:
				sides.append("%s from lane %d: %s" % ["air" if air_switch else "floor", from + 1, r])
	check(sides.is_empty(), "a lane switch into the cage touches a side fence, from either side, on the floor and in the air %s %s" % [
		tag, sides])
	check(world.player.alive, "(the shields took every touch) %s" % tag)
	await sim.free_world(world)


## Waits until the runner is on the floor in `lane` (moving them there), with no invulnerability left.
func _settle(world: RunWorld, lane: int) -> void:
	var player: Player = world.player
	for i: int in 600:
		if player.surface == Player.Surface.FLOOR and player.grounded and player.lane == lane and player.invulnerable_left <= 0.0 \
				and not player.dashing and i > 2:
			return
		if player.surface == Player.Surface.FLOOR and player.grounded and player.lane != lane and i % 12 == 0:
			player.press(&"move_right" if lane > player.lane else &"move_left")
		await tree.physics_frame


## One cage ahead of the runner in its pad's lane, its front fence `off` past where they jump: {off (measured from
## where they left the floor), touched (the front fence), pad (it fired), landed, front_at, pad_to}.
func _jump_at(world: RunWorld, boss: GoldenConvergence, off: float, rec: Dictionary) -> Dictionary:
	var player: Player = world.player
	var cage: GoldenConvergenceCage = boss.refill.cage
	await _settle(world, PAD_LANE)
	var v: float = boss.speed()
	var front_at: float = player.distance + off + v * (boss.tuning.cage_flicker + 0.2)
	cage.place(PAD_LANE, GEN_LANE, front_at)
	var plan: Dictionary = cage.plan
	var touches: int = cage.touches.size()
	var pads: int = int(rec["pads"])
	var out := {"off": -1.0, "touched": false, "pad": false, "landed": -1.0, "front_at": front_at, "pad_to": float(plan["pad_to"])}
	var pressed: bool = false
	for i: int in 900:
		if not pressed and player.distance + v * FRAME >= front_at - off:
			player.press(&"jump")
			pressed = true
		await tree.physics_frame
		if pressed and float(out["off"]) < 0.0 and not player.grounded:
			out["off"] = front_at - (player.distance - v * FRAME)
		if float(out["off"]) >= 0.0 and float(out["landed"]) < 0.0 and player.grounded and player.surface == Player.Surface.FLOOR:
			out["landed"] = player.distance
		if float(out["landed"]) >= 0.0 and player.distance > float(plan["side_to"]) + 1.0 and player.surface == Player.Surface.FLOOR \
				and player.grounded:
			break
	for e: Dictionary in cage.touches.slice(touches):
		out["touched"] = bool(out["touched"]) or e["kind"] == &"front"
	out["pad"] = int(rec["pads"]) > pads
	return out


## One cage ahead of a runner in lane `from` beside it (its generator on the pad's other side, out of their way),
## who switches into the pad's lane once past the front fence (jumping first if `air`): {side (a side fence touched),
## which (0 the left side, 1 the right), outcome}.
func _switch_in(world: RunWorld, boss: GoldenConvergence, from: int, air: bool, rec: Dictionary) -> Dictionary:
	var player: Player = world.player
	var cage: GoldenConvergenceCage = boss.refill.cage
	await _settle(world, from)
	var v: float = boss.speed()
	var front_at: float = player.distance + v * (boss.tuning.cage_flicker + 0.6)
	cage.place(PAD_LANE, PAD_LANE + (PAD_LANE - from), front_at)
	var plan: Dictionary = cage.plan
	var touches: int = cage.touches.size()
	var jumped: bool = not air
	var switched: bool = false
	for i: int in 900:
		if not jumped and player.distance + v * FRAME >= front_at - v * 0.3:
			player.press(&"jump")
			jumped = true
		if not switched and player.distance >= float(plan["front_at"]) + 0.4:
			player.press(&"move_right" if PAD_LANE > from else &"move_left")
			switched = true
		await tree.physics_frame
		if switched and player.distance > float(plan["side_to"]) + 1.0 and player.surface == Player.Surface.FLOOR and player.grounded:
			break
	var out := {"side": false, "which": -1, "outcome": -1, "air": air}
	for e: Dictionary in cage.touches.slice(touches):
		if e["kind"] == &"side" and not bool(out["side"]):
			out["side"] = true
			out["which"] = int(e["side"])
			out["outcome"] = int(e["outcome"])
			out["h"] = snappedf(float(e["h"]), 0.01)
	return out


# --- The fence rules ----------------------------------------------------------------------------------------

## GDD §9.1's fence rules on the cage's front fence, run into in the pad's lane: the dash passes it (onto the pad),
## armor and the shield get the runner through at the cost of a hit, claws don't help; an EMP from elsewhere
## switches off the fences it reaches and no others.
func _test_fence_rules() -> void:
	var dasher := Loadout.new()
	dasher.tiers[&"dash"] = 1
	var r: Dictionary = await _into_front(dasher, &"dash")
	check(bool(r["alive"]) and (r["outcomes"] as Array).is_empty() and bool(r["pad"]),
		"the dash passes through the front fence and onto the pad (%s)" % [r])
	var armored := Loadout.new()
	armored.armor = true
	r = await _into_front(armored, &"armor")
	check(bool(r["alive"]) and r["outcomes"] == [DamageRules.Outcome.BLOCKED_ARMOR] and bool(r["pad"]),
		"armor gets the runner through at the cost of a hit, onto the pad (%s)" % [r])
	r = await _into_front(null, &"shield")
	check(bool(r["alive"]) and r["outcomes"] == [DamageRules.Outcome.BLOCKED_SHIELD] and bool(r["pad"]),
		"so does the shield (%s)" % [r])
	r = await _into_front(null, &"claws")
	check(not bool(r["alive"]) and r["outcomes"] == [DamageRules.Outcome.KILL], "claws don't help: the fence kills (%s)" % [r])
	r = await _into_front(null, &"emp")
	check(bool(r["alive"]) and (r["outcomes"] as Array).is_empty() and bool(r["pad"]) and bool(r["front_off"]) and bool(r["sides_on"])
		and not bool(r["dark"]), "an EMP at the front fence switches it off and not the sides: the runner runs through (%s)" % [r])


## A runner in the pad's lane running into the front fence of a cage `how` (dash, armor, shield, claws, emp): {alive,
## outcomes (the front fence's touches), pad (it fired), front_off, sides_on, dark}.
func _into_front(loadout: Loadout, how: StringName) -> Dictionary:
	var pair: Array = _fight(5, 18.0, loadout, -1, "none")
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var cage: GoldenConvergenceCage = boss.refill.cage
	var player: Player = world.player
	var rec: Dictionary = _watch(player)
	await _run(world, null, 0.3)
	await _settle(world, PAD_LANE)
	if how == &"shield":
		player.shield = 1
	elif how == &"claws":
		player.claws = true
	var v: float = boss.speed()
	var front_at: float = player.distance + v * (boss.tuning.cage_flicker + 0.8)
	cage.place(PAD_LANE, GEN_LANE, front_at)
	var plan: Dictionary = cage.plan
	var out := {"alive": true, "outcomes": [], "pad": false, "front_off": false, "sides_on": false, "dark": false}
	var state := {"dashed": false, "emp": false}
	await _run(world, null, 6.0, func() -> bool: return player.distance > float(plan["side_to"]) + 2.0, func() -> void:
		var ahead: float = float(plan["front_at"]) - player.distance
		if how == &"dash" and not bool(state["dashed"]) and ahead <= v * 0.12 and cage.front.is_active():
			state["dashed"] = (world.powerups as PowerupController).dash.trigger()
		if how == &"emp" and not bool(state["emp"]) and cage.front.is_active() and ahead < 8.0:
			state["emp"] = true
			world.emp(cage.front.global_position, 0.6)
			out["front_off"] = not cage.front.is_active()
			out["sides_on"] = cage.sides[0].is_active() and cage.sides[1].is_active()
			out["dark"] = cage.dark)
	out["alive"] = player.alive
	out["cause"] = rec["cause"]
	for e: Dictionary in cage.touches:
		if e["kind"] == &"front":
			(out["outcomes"] as Array).append(int(e["outcome"]))
	out["pad"] = int(rec["pads"]) > 0
	await sim.free_world(world)
	return out


# --- The rides ----------------------------------------------------------------------------------------------

## Phase 1's Refill Ship ridden `way` (the bot getting onto the pad by the generator's stomp, the dash or armor) at
## `lanes` and `speed`.
func _test_ride(way: StringName, lanes: int, speed: float) -> void:
	var tag: String = "(%s, %d lanes, %.0f m/s)" % [way, lanes, speed]
	var loadout: Loadout = null
	if way == &"dash":
		loadout = Loadout.new()
		loadout.tiers[&"dash"] = 1
	elif way == &"armor":
		loadout = Loadout.new()
		loadout.armor = true
	var pair: Array = _fight(lanes, speed, loadout, -1, "refill:VVH")
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var r: GoldenConvergenceRefill = boss.refill
	var s: GoldenConvergenceStrafe = boss.strafe
	var bot := _bot(boss, way)
	var rec: Dictionary = _watch(world.player)
	var hints: Array[String] = []
	boss.hint_due.connect(func(key: String) -> void: hints.append(key))
	var shakes := {"n": 0}
	world.effects.shake_requested.connect(func(_s: float, _d: float) -> void: shakes["n"] = int(shakes["n"]) + 1)
	var pipes_before: Array = [boss.suit.pipes_broken[0], boss.suit.pipes_broken[1]]
	var w := {"hold": 0, "hold_bad": 0, "drone_far": 0.0, "targeted": 0, "low": {}, "dark_fences": -1, "health_at_hit": -1.0}
	r.hit_landed.connect(func(_info: Dictionary) -> void: w["health_at_hit"] = boss.health)
	await _run(world, bot, 60.0, func() -> bool: return boss.phase_index >= 1, func() -> void:
		var d: float = world.player.distance
		for e: Enemy in world.director.targets_ahead(world.player.global_position, 500.0):
			if e == r.ship or e == r.cage.generator:
				w["targeted"] = int(w["targeted"]) + 1
		if r.ship.targetable():
			w["targeted"] = int(w["targeted"]) + 1
		var plan: Dictionary = r.cage.plan
		if r.stage == GoldenConvergenceRefill.Stage.ON and r.cage.up and not plan.is_empty() and d <= float(plan["pad_to"]):
			w["hold"] = int(w["hold"]) + 1
			if not s.held or s.warning_on() or s.current >= 0:
				w["hold_bad"] = int(w["hold_bad"]) + 1
			var low_at: float = float(_first(boss, &"ship_low").get("t", INF))
			if boss.fight_time() > low_at + 0.5 and not world.player.dashing:
				for i: int in boss.squadron.size():
					if boss.squadron.flying(i):
						var gap: float = boss.squadron.drone_position(i).distance_to(r.ship.hold_point(i, boss.squadron.size()))
						w["drone_far"] = maxf(float(w["drone_far"]), gap)
		if r.ship_stage == GoldenConvergenceRefill.ShipStage.LOW and (w["low"] as Dictionary).is_empty():
			w["low"] = {"y": r.ship.global_position.y, "belly": r.ship.belly_on(), "x": r.ship.global_position.x,
				"half": r.ship.half_width}
		if r.cage.dark and int(w["dark_fences"]) < 0:
			var n: int = 0
			for fence: Hazard in r.cage.fences():
				if fence.state == Hazard.State.OFF:
					n += 1
			w["dark_fences"] = n)
	var v: float = boss.speed_planned()
	var t: GoldenConvergenceTuning = boss.tuning
	# The ship flies in and feeds his shoulder; the cage comes up, then on.
	var order: Array[StringName] = [&"refill_start", &"refill_feed", &"cage_up", &"cage_on", &"ship_low", &"squadron_hurled",
		&"refill_chain", &"refill_ripple", &"ship_spins", &"rider_dropped", &"rider_landed", &"ship_exploded", &"refill_hit", &"phase_end"]
	var times: Array[float] = []
	for e: StringName in order:
		var found: Array[Dictionary] = _events(boss, e)
		times.append(float(found[0]["t"]) if found.size() >= 1 else -1.0)
	var in_order: bool = not times.has(-1.0)
	for i: int in range(1, times.size()):
		in_order = in_order and times[i] >= times[i - 1]
	check(in_order, "it plays in order: the ship in, the feed, the cage up and on, the ship low, the pad, the chain, the ride down, the explosion, the hit %s %s" % [
		tag, times])
	var up: Dictionary = _first(boss, &"cage_up")
	if up.is_empty():
		check(false, "the cage came up %s" % tag)
		await sim.free_world(world)
		return
	check(absf(float(up["front_at"]) - float(up["runner"]) - v * t.cage_lead) < 0.5 and int(up["lane"]) >= 1 and int(up["lane"]) <= lanes - 2
		and absi(int(up["gen_lane"]) - int(up["lane"])) == 1 and int(up["passes_done"]) == t.cage_after,
		"the cage comes up after %d pass, %.1f s ahead, its pad in an inner lane, the generator beside it %s" % [t.cage_after, t.cage_lead, tag])
	check(absf(float(_first(boss, &"cage_on").get("t", 0.0)) - float(up["t"]) - t.cage_flicker) < 2.0 * FRAME,
		"its fences switch on %.1f s after they flicker in %s" % [t.cage_flicker, tag])
	var low: Dictionary = w["low"]
	var low_event: Dictionary = _first(boss, &"ship_low")
	check(not low.is_empty() and absf(float(low["y"]) - world.tuning.ceiling_height) < 0.05 and bool(low["belly"]) and absf(float(low["x"])) < 0.01
		and float(low["half"]) >= world.geo.wall_x() and float(up["front_at"]) - float(low_event.get("runner", INF)) >= v * t.settle_before - 0.5,
		"the ship is down at the ceiling's height, its belly over every lane, %.1f s before the front fence %s (%s)" % [t.settle_before, tag, low])
	check(int(w["hold"]) > 60 and int(w["hold_bad"]) == 0, "the squadron holds its fire from the cage coming up until the runner is past the pad: no pass warns or fires (%d frames) %s" % [
		w["hold"], tag])
	var window: Array[Dictionary] = boss.events.filter(func(e: Dictionary) -> bool:
		return e["event"] in [&"pass_warned", &"pass_fire"] and float(e["t"]) >= float(up["t"]) and float(e["t"]) <= float(_first(boss, &"refill_chain").get("t", INF)))
	check(window.is_empty(), "no pass at all, horizontal or vertical, while the cage is up and ahead %s" % tag)
	check(float(w["drone_far"]) < 1.5, "the drones hover in formation beside the ship under its racks meanwhile (at most %.2f m off their places) %s" % [
		w["drone_far"], tag])
	# The way in.
	var touches: Array[Dictionary] = r.cage.touches
	match way:
		&"generator":
			var gen: Dictionary = _first(boss, &"cage_generator")
			var dark: Dictionary = _first(boss, &"cage_dark")
			check(gen.get("cause", &"") == &"stomp" and bool(dark.get("own", false)) and int(w["dark_fences"]) == 3 and touches.is_empty(),
				"a stomp on the generator: its pulse switches the whole cage off, and the runner switches in untouched %s" % tag)
		&"dash":
			check(touches.is_empty() and _first(boss, &"cage_generator").is_empty(), "the dash through the front fence, untouched %s" % tag)
		&"armor":
			check(touches.size() == 1 and touches[0]["kind"] == &"front" and int(touches[0]["outcome"]) == DamageRules.Outcome.BLOCKED_ARMOR
				and (rec["blows"] as Array).size() == 1, "through the front fence on the armor, at the cost of its hit %s" % tag)
	# The chain reaction and the hit.
	var chain: Dictionary = _first(boss, &"refill_chain")
	var hit: Dictionary = _first(boss, &"refill_hit")
	check(_first(boss, &"squadron_hurled").get("t", -1.0) == chain.get("t", -2.0) and r.chains == 1 and r.hits == 1
		and _events(boss, &"strafe_done").filter(func(e: Dictionary) -> bool: return bool(e.get("hurled", false))).size() == 1
		and boss.squadron.out_count() == 0, "the pad hurls the squadron up into the ship: the strafe is over %s" % tag)
	check(r.ship.racks_blown == r.ship.rack_count() and not r.ship.shown and float(hit.get("t", 0.0)) - float(chain.get("t", 0.0)) <= t.spin_at + t.spin_seconds + t.blast_seconds + 2.0 * FRAME,
		"its missiles go up along the racks, it spins off and explodes, and the blast reaches his shoulder %.1f s after the pad %s" % [
			t.spin_at + t.spin_seconds + t.blast_seconds, tag])
	check(is_equal_approx(float(hit.get("damage", 0.0)), boss.max_health / 6.0) and boss.phase_index == 1
		and is_equal_approx(float(w["health_at_hit"]), boss.max_health) and is_equal_approx(boss.health, boss.phase_start_health(1)),
		"the hit: a third of the suit's health (%.0f), and the phase ends %s" % [float(hit.get("damage", 0.0)), tag])
	check(pipes_before == [false, false] and boss.suit.pipes_broken[0] and not boss.suit.pipes_broken[1] and not bool(hit.get("burst", true)),
		"the first ship blows out his right shoulder's pipes %s" % tag)
	# The runner: back on the floor unharmed, onto clear floor.
	var landed: Dictionary = r.landed
	var clear_floor: bool = not landed.is_empty()
	if clear_floor:
		var at: float = float(landed["distance"])
		var lane: int = int(landed["lane"])
		clear_floor = not boss.props.warned(lane, at - 3.0, at + 3.0)
		for c: Dictionary in boss.arena.layout.cuts:
			if int(c["lane"]) == lane and float(c["start"]) < at + 3.0 and float(c["end"]) > at - 3.0:
				clear_floor = false
	var blows_ok: bool = (rec["blows"] as Array).size() == (1 if way == &"armor" else 0)
	check(world.player.alive and blows_ok and clear_floor and r.dropped_at > 0.0
		and float(_first(boss, &"ship_spins").get("t", 0.0)) <= float(_first(boss, &"rider_dropped").get("t", -1.0)),
		"the runner rides the belly up there, falls back to the floor as it spins away and lands unharmed on clear floor %s (%s, %s)" % [
			tag, rec["cause"], landed])
	check(int(w["targeted"]) == 0 and r.ship.immune_to_weapons, "weapons never target the ship or the generator %s" % tag)
	var heard: Array[String] = []
	for sound: StringName in [&"gc_ship", &"gc_feed", &"fence_warning", &"gc_hurl", &"gc_ripple", &"gc_crash", &"gc_blast", &"gc_pipes"]:
		if _sounds(boss, sound) != 1:
			heard.append("%s %d" % [sound, _sounds(boss, sound)])
	check(heard.is_empty() and _sounds(boss, &"gc_ride") >= 1 and _sounds(boss, &"gc_leave") == 0,
		"each heard once: the ship, the feed, the fence warning, the hurl, the ripple, the crash, the blast, the pipes; missiles riding the line %s %s" % [
			tag, heard])
	check(hints.has("golden_boss/refill") and hints.has("golden_boss/cage"), "with its hints %s (%s)" % [tag, hints])
	check(r.ship.sparks_shown > 0 and int(shakes["n"]) > 0, "sparks fly and the screen shakes %s" % tag)
	await sim.free_world(world)


## The final review's blocker (before its fix, a fight that hung): a lane switch changes the runner's lane at once while
## the body is still over the pad for a frame or two, so a switch pressed as they reach it fires the pad from another
## lane; the chain reaction asked for the pad's lane, never started, and the runner rode the belly for good (a ceiling
## has no way down of its own). Swept over the frames around the pad on the generator's and the dash's ways in: the
## bot plays up to the pad, then switches out of its lane (and plays no more).
func _test_switch_over_pad() -> void:
	var mismatched: int = 0
	var fired: int = 0
	for way: StringName in [&"generator", &"dash"]:
		var lanes: int = 5 if way == &"generator" else 3
		for step: int in 7:
			var off: float = -1.2 + 0.2 * step
			var tag: String = "(%s, %d lanes, a switch %.1f m before the pad)" % [way, lanes, -off]
			var loadout: Loadout = null
			if way == &"dash":
				loadout = Loadout.new()
				loadout.tiers[&"dash"] = 1
			var pair: Array = _fight(lanes, 25.0, loadout, -1, "refill:VVH")
			var world: RunWorld = pair[0]
			var boss: GoldenConvergence = pair[1]
			var r: GoldenConvergenceRefill = boss.refill
			var bot := _bot(boss, way)
			var w := {"pad": false, "pad_lane": -1, "cage_lane": -1, "switched": false, "riding": 0, "longest": 0}
			world.player.movement_event.connect(func(kind: StringName) -> void:
				if kind == &"pad" and not bool(w["pad"]):
					w["pad"] = true
					w["pad_lane"] = world.player.lane
					w["cage_lane"] = int(r.cage.plan.get("lane", -1)))
			await _run(world, null, 40.0, func() -> bool:
				return boss.phase_index >= 1 or (bool(w["switched"]) and r.stage == GoldenConvergenceRefill.Stage.DONE),
				func() -> void:
					var plan: Dictionary = r.cage.plan
					if not bool(w["switched"]):
						bot.step()
						if r.cage.up and not plan.is_empty() and world.player.surface == Player.Surface.FLOOR \
								and world.player.lane == int(plan["lane"]) and world.player.distance >= float(plan["pad_from"]) + off:
							world.player.press(&"move_left" if world.player.lane > 0 else &"move_right")
							w["switched"] = true
					if world.player.surface == Player.Surface.CEILING:
						w["riding"] = int(w["riding"]) + 1
						w["longest"] = maxi(int(w["longest"]), int(w["riding"]))
					else:
						w["riding"] = 0)
			# At the latest switch points the pad fires first: a ride like any other (the runner never switched).
			check(bool(w["switched"]) or (bool(w["pad"]) and int(w["pad_lane"]) == int(w["cage_lane"])),
				"the runner reached the pad and switched out of its lane, or rode it first %s" % tag)
			if bool(w["pad"]):
				fired += 1
				if int(w["pad_lane"]) != int(w["cage_lane"]):
					mismatched += 1
				check(not _events(boss, &"refill_chain").is_empty() and r.cage.padded,
					"the pad fired (from lane %d, the cage's %d): the chain reaction started and the cage sank %s" % [
						int(w["pad_lane"]), int(w["cage_lane"]), tag])
			check(int(w["longest"]) < int(8.0 / FRAME),
				"the runner never rides the belly for long (%.1f s at the most) %s" % [float(w["longest"]) * FRAME, tag])
			check(_events(boss, &"refill_failsafe").is_empty(), "no failsafe was needed %s" % tag)
			await sim.free_world(world)
	check(fired > 0 and mismatched > 0,
		"a switch at the pad fired it from another lane (the review's case): %d of %d pads fired" % [mismatched, fired])


## Reduced flashing and the screen shake off (Settings): the chain reaction shows no sparks (its fireballs and smoke
## still) and never shakes the screen.
func _test_reduced() -> void:
	var was: bool = Settings.flashing_reduced
	Settings.flashing_reduced = true
	var pair: Array = _fight(5, 18.0, null, -1, "refill:VVH")
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	world.effects.shake_scale = 0.0
	var shakes := {"n": 0}
	world.effects.shake_requested.connect(func(_s: float, _d: float) -> void: shakes["n"] = int(shakes["n"]) + 1)
	var ship: GoldenConvergenceShip = boss.refill.ship
	var heat := {"max": 0.0}
	await _run(world, _bot(boss), 60.0, func() -> bool: return boss.phase_index >= 1, func() -> void:
		for f: Dictionary in ship.blast().shown(true):
			heat["max"] = maxf(float(heat["max"]), float(f["heat"])))
	Settings.flashing_reduced = was
	check(boss.refill.hits == 1 and ship.sparks_shown == 0 and ship.fireballs_shown > 10 and int(shakes["n"]) == 0,
		"with Reduced flashing and the screen shake off, the chain reaction shows no sparks (%d fireballs) and never shakes the screen" % ship.fireballs_shown)
	check(float(heat["max"]) <= GoldenConvergenceBlast.SOFT_HEAT + 0.001,
		"and its fireballs never flash hot (their hearts at most %.2f, %.2f seen)" % [GoldenConvergenceBlast.SOFT_HEAT, heat["max"]])
	await sim.free_world(world)


## E5d polish (the review: the chain reaction's explosions read a washed-out peach against the bright court, and the
## ship exploded below the deck, out of the side camera's sight; the owner: "the ship goes spinning off to the side and
## exploding, and the missiles should all explode"): from the pad to the hit, every fireball is a saturated orange to
## red and every puff of smoke dark, all of it above the causeway's level; the ship's own blast goes off beside the
## causeway, past the balustrade, where the run camera's resting view sees it; its fire hot at heart (no Reduced
## flashing); drawn by the blast's two MultiMeshes, with no node made during it.
func _test_blast(lanes: int) -> void:
	var tag: String = "(%d lanes, 25 m/s)" % lanes
	var pair: Array = _fight(lanes, 25.0, null, -1, "refill:VVH")
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var r: GoldenConvergenceRefill = boss.refill
	var ship: GoldenConvergenceShip = r.ship
	var blast: GoldenConvergenceBlast = ship.blast()
	var nodes_before: int = ship.find_children("*", "", true, false).size()
	var w := {"low": INF, "pale": [], "light_smoke": [], "heat": 0.0, "big": 0, "beside": true, "seen": 0, "frames": 0,
		"exploded": -1.0, "fires": 0}
	await _run(world, _bot(boss), 60.0, func() -> bool: return boss.phase_index >= 1, func() -> void:
		if r.stage != GoldenConvergenceRefill.Stage.CHAIN:
			return
		var fires: Array[Dictionary] = blast.shown(true)
		w["fires"] = maxi(int(w["fires"]), fires.size())
		for f: Dictionary in fires:
			var c: Color = f["color"]
			w["low"] = minf(float(w["low"]), (f["at"] as Vector3).y)
			w["heat"] = maxf(float(w["heat"]), float(f["heat"]))
			if c.a > 0.2 and not ((c.h <= 0.1 or c.h >= 0.97) and c.s >= 0.8):
				(w["pale"] as Array).append(c)
		for puff: Dictionary in blast.shown(false):
			var c: Color = puff["color"]
			w["low"] = minf(float(w["low"]), (puff["at"] as Vector3).y)
			if c.v > 0.3:
				(w["light_smoke"] as Array).append(c)
		var exploded: Dictionary = _first(boss, &"ship_exploded")
		if exploded.is_empty() or boss.fight_time() > float(exploded["t"]) + 1.0:
			return
		# The ship's own blast (its big fireballs) in its first second.
		var view := EnforcerTruckView.of_runner(world.tuning, world.geo, world.player.lane, world.player.distance)
		var on: bool = false
		for f: Dictionary in fires:
			if float(f["radius"]) < 3.0:
				continue
			w["big"] = int(w["big"]) + 1
			var at: Vector3 = f["at"]
			w["beside"] = bool(w["beside"]) and absf(at.x) > world.geo.wall_x()
			on = on or view.on_screen(at + Vector3(0.0, float(f["radius"]) * 0.5, 0.0), 0.0)
		w["frames"] = int(w["frames"]) + 1
		if on:
			w["seen"] = int(w["seen"]) + 1)
	check(r.hits == 1, "the pad ridden, the chain reaction plays to its hit %s" % tag)
	check((w["pale"] as Array).is_empty() and (w["light_smoke"] as Array).is_empty() and int(w["fires"]) > 0,
		"every fireball a saturated orange to red, every puff of smoke dark, never a pale peach (%s; %s) %s" % [
		(w["pale"] as Array).slice(0, 2), (w["light_smoke"] as Array).slice(0, 2), tag])
	check(float(w["low"]) > 1.0, "all of its fire and smoke above the causeway's level (the lowest at %.1f m) %s" % [w["low"], tag])
	check(int(w["big"]) > 0 and bool(w["beside"]) and int(w["seen"]) >= int(w["frames"]) * 3 / 4,
		"the ship's blast goes off beside the causeway, past the balustrade, in the run camera's view (%d of %d frames) %s" % [
		w["seen"], w["frames"], tag])
	check(float(w["heat"]) > 0.8, "its fireballs are hot at heart without Reduced flashing (%.2f) %s" % [w["heat"], tag])
	check(ship.find_children("*", "", true, false).size() == nodes_before and blast.drawers().size() == 2,
		"pooled: its fire and smoke are two MultiMeshes, no node made during the chain (%d nodes, %d before) %s" % [
		ship.find_children("*", "", true, false).size(), nodes_before, tag])
	await sim.free_world(world)


# --- A missed pad -------------------------------------------------------------------------------------------

## Phase 2 (its loop from the slams) with the Refill Ship then the slams, the bot letting the pad go by: the ship
## finishes refilling and flies off while the strafe fires on; the beat ends where ends_at() said; the slams after it
## were planned ahead; the next ship is the same.
func _test_missed() -> void:
	var pair: Array = _fight(5, 18.0, null, 1, "refill:VVH,slams")
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var r: GoldenConvergenceRefill = boss.refill
	var bot := _bot(boss, &"miss")
	var rec: Dictionary = _watch(world.player)
	var w := {"ends_at": -1.0, "before_miss": -1.0}
	await _run(world, bot, 120.0, func() -> bool: return _events(boss, &"cage_up").size() >= 2, func() -> void:
		if r.misses == 0 and r.busy():
			w["before_miss"] = maxf(float(w["before_miss"]), r.ends_at())
		elif r.misses == 1 and float(w["ends_at"]) < 0.0:
			w["ends_at"] = r.ends_at())
	var missed: Dictionary = _first(boss, &"refill_missed")
	var leaves: Dictionary = _first(boss, &"refill_leaves")
	var done: Dictionary = _first(boss, &"refill_done")
	check(not missed.is_empty() and not leaves.is_empty() and not done.is_empty() and float(missed["t"]) < float(leaves["t"])
		and float(leaves["t"]) < float(done["t"]) and r.hits == 0 and boss.phase_index == 1 and is_equal_approx(boss.health, boss.phase_start_health(1)),
		"a missed pad: the ship climbs back, finishes refilling and flies off, and the suit is unharmed")
	var after: Array[Dictionary] = boss.events.filter(func(e: Dictionary) -> bool:
		return e["event"] == &"pass_fire" and not missed.is_empty() and float(e["t"]) > float(missed["t"]) and float(e["t"]) < float(done.get("t", INF)))
	check(not _events(boss, &"strafe_released").is_empty() and after.size() == 2 and _events(boss, &"pass_done").size() >= 3,
		"the squadron fires on once the runner is past the pad: its two passes left (%d)" % after.size())
	check(world.player.alive and (rec["blows"] as Array).is_empty(), "the runner untouched (%s)" % rec["cause"])
	var v: float = boss.speed_planned()
	check(float(w["before_miss"]) < 0.0 and float(w["ends_at"]) > 0.0 and absf(float(done.get("runner", 0.0)) - float(w["ends_at"])) < v * 0.2,
		"ends_at() says nothing until the pad is missed, then where the beat ends (%.1f m, ended at %.1f m)" % [w["ends_at"], float(done.get("runner", 0.0))])
	var slams_beat: Array[Dictionary] = _events(boss, &"beat").filter(func(e: Dictionary) -> bool: return e["kind"] == &"slams")
	var planned: Array[Dictionary] = _events(boss, &"slams_planned").filter(func(e: Dictionary) -> bool:
		return not missed.is_empty() and float(e["t"]) >= float(missed["t"]))
	var started: Dictionary = _first(boss, &"slams_start")
	check(not slams_beat.is_empty() and not planned.is_empty() and planned[0]["by"] == &"ahead" and float(planned[0]["t"]) < float(slams_beat[0]["t"])
		and started.get("planned_by", &"") == &"ahead",
		"the loop goes on from the slams, their holes planned ahead of their beat, as the ship flew off")
	var starts: Array[Dictionary] = _events(boss, &"refill_start")
	var ups: Array[Dictionary] = _events(boss, &"cage_up")
	var same: bool = starts.size() == 2 and ups.size() == 2 and starts[0]["script"] == starts[1]["script"]
	if same:
		for k: int in 2:
			same = same and absf((float(ups[k]["front_at"]) - float(ups[k]["runner"])) - (float(ups[0]["front_at"]) - float(ups[0]["runner"]))) < 0.01 \
				and absf((float(ups[k]["t"]) - float(starts[k]["t"])) - (float(ups[0]["t"]) - float(starts[0]["t"]))) < 2.0 * FRAME
	check(same, "the next ship is the same: no escalation (GDD §10)")
	await sim.free_world(world)


# --- Planning ahead -----------------------------------------------------------------------------------------

## The chain reaction plans the next phase's first slams (that phase opens with them): planned once, at the pad,
## and played as planned when the phase's first beat begins. At the Golden Zone's 25 m/s the first fist is on time
## (it never stalks the runner); at quick play's 18 m/s the built track still reaches past where it would land, so
## it comes as soon as the track allows (E5d-b: the first fist stalks the runner's lane until then).
func _test_next_phase_planned() -> void:
	for speed: float in [25.0, 18.0]:
		var tag: String = "(%.0f m/s)" % speed
		var pair: Array = _fight(5, speed, null, -1, PackedStringArray(["refill:VVH", "slams,refill:VVH"]))
		var world: RunWorld = pair[0]
		var boss: GoldenConvergence = pair[1]
		var bot := _bot(boss)
		await _run(world, bot, 60.0, func() -> bool: return not _events(boss, &"slams_start").is_empty())
		var chain: Dictionary = _first(boss, &"refill_chain")
		var ahead: Array[Dictionary] = _events(boss, &"slams_planned").filter(func(e: Dictionary) -> bool: return int(e.get("for_phase", -1)) == 1)
		var started: Dictionary = _first(boss, &"slams_start")
		var t: GoldenConvergenceTuning = boss.tuning
		var p: float = boss.def.phase_list()[1].pace
		var v: float = boss.speed_planned()
		var expected: float = float(started.get("runner", 0.0)) + v * (t.slam_out_seconds / p + t.slam_track_seconds + t.slam_lock_seconds)
		var late: float = (float(started.get("first_impact", 0.0)) - expected) / v
		print("  the next phase's first fist %s: %.2f s later than on time" % [tag, late])
		check(ahead.size() == 1 and ahead[0]["by"] == &"chain" and float(ahead[0]["t"]) == float(chain.get("t", -1.0))
			and started.get("planned_by", &"") == &"chain" and int(started.get("phase", -1)) == 1,
			"the chain reaction plans the next phase's first slams, once, and that phase plays them %s" % tag)
		if speed > 20.0:
			check(absf(late) < 0.1, "its first fist on time: it never stalks the runner (%.2f s) %s" % [late, tag])
		else:
			var row_len: float = GoldenConvergenceHole.hole_lanes(boss.lane_count()) * world.geo.lane_width
			var earliest: float = float(ahead[0].get("stream_from", 0.0)) + GoldenConvergenceSlams.ROW_MARGIN + row_len * 0.5 if not ahead.is_empty() else -1.0
			check(late > 0.0 and absf(float(started.get("first_impact", 0.0)) - earliest) < 0.5,
				"its first fist as soon as the built track allows (%.2f s late) %s" % [late, tag])
		await sim.free_world(world)


## Phase 3's ship: the third hit bursts the suit open (phase 4, the checkpoint: the transition), with one blast,
## the transition's (no pipes blown).
func _test_phase_three() -> void:
	var pair: Array = _fight(5, 18.0, null, 2, "refill:VVH")
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var bot := _bot(boss)
	var pipes := {"before": []}
	boss.refill.chained.connect(func(_info: Dictionary) -> void: pipes["before"] = [boss.suit.pipes_broken[0], boss.suit.pipes_broken[1]])
	await _run(world, bot, 60.0, func() -> bool: return not _events(boss, &"transition_done").is_empty())
	var hit: Dictionary = _first(boss, &"refill_hit")
	var transition: Dictionary = _first(boss, &"transition")
	check(bool(hit.get("burst", false)) and int(hit.get("phase", -1)) == STAGE_2 - 1 and float(transition.get("t", -1.0)) == float(hit.get("t", -2.0))
		and not _events(boss, &"checkpoint").is_empty(), "phase 3's ship bursts the suit open: phase 4 begins at once, at the checkpoint")
	check(_sounds(boss, &"gc_pipes") == 0 and _sounds(boss, &"magnate_burst") == 1 and pipes["before"] == [boss.suit.pipes_broken[0], boss.suit.pipes_broken[1]],
		"with one blast, the transition's (no pipes blown: %d, bursts %d)" % [_sounds(boss, &"gc_pipes"), _sounds(boss, &"magnate_burst")])
	check(_events(boss, &"slams_planned").filter(func(e: Dictionary) -> bool: return int(e.get("for_phase", -1)) >= STAGE_2).is_empty(),
		"and plans nothing for stage 2")
	check(world.player.alive, "the runner unharmed")
	await sim.free_world(world)


# --- The review's phase-end fixes ---------------------------------------------------------------------------

## A phase's end with gates up: a horizontal pass's gate standing ahead sinks back into the causeway (it doesn't
## pop); a Pounce's bait gate crumbling (smashed) crumbles on.
func _test_gates_sink() -> void:
	var pair: Array = _fight(5, 18.0, null, -1, "strafe:H")
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	world.player.god_mode = true
	var s: GoldenConvergenceStrafe = boss.strafe
	await _run(world, null, 20.0, func() -> bool:
		return not s.passes.is_empty() and s.gate(s.passes[0]) != null and s.gate(s.passes[0]).state == GoldenConvergenceButtress.State.STANDING)
	var b: GoldenConvergenceButtress = s.gate(s.passes[0]) if not s.passes.is_empty() else null
	if b == null:
		check(false, "a horizontal pass's gate stood")
		await sim.free_world(world)
		return
	boss.damage(boss.hit_damage(), &"test")
	var sinking: bool = b.state == GoldenConvergenceButtress.State.SINKING and b.visible
	await _run(world, null, boss.tuning.buttress_rise_seconds + 0.2)
	check(boss.phase_index == 1 and sinking and b.state == GoldenConvergenceButtress.State.FREE,
		"at a phase's end a gate standing ahead sinks back into the causeway, then goes back to the pool (it never pops)")
	await sim.free_world(world)
	pair = _fight(5, 18.0, null, STAGE_2, "pounce:bait")
	world = pair[0]
	boss = pair[1]
	world.player.god_mode = true
	var pc: GoldenConvergencePounce = boss.pounce
	await _run(world, null, 30.0, func() -> bool: return pc.gate() != null and pc.gate().standing() and boss.is_vulnerable())
	var gate: GoldenConvergenceButtress = pc.gate()
	if gate == null:
		check(false, "a Pounce's bait gate stood")
		await sim.free_world(world)
		return
	gate.smash()
	boss.damage(boss.hit_damage(), &"test")
	var crumbling: bool = gate.state == GoldenConvergenceButtress.State.CRUMBLING and gate.visible
	check(boss.phase_index == STAGE_2 + 1 and crumbling, "a Pounce's gate crumbling at the phase's end crumbles on (never released at once)")
	await sim.free_world(world)


## A gate gone back to the pool and risen again for another attack is never moved by the pass that raised it first.
func _test_stale_gate() -> void:
	var pair: Array = _fight(5, 18.0, null, -1, "strafe:H")
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	world.player.god_mode = true
	var s: GoldenConvergenceStrafe = boss.strafe
	await _run(world, null, 20.0, func() -> bool: return not s.passes.is_empty() and s.gate(s.passes[0]) != null)
	var p: Dictionary = s.passes[0] if not s.passes.is_empty() else {}
	var b: GoldenConvergenceButtress = s.gate(p) if not p.is_empty() else null
	if b == null:
		check(false, "a horizontal pass's gate rose")
		await sim.free_world(world)
		return
	var lane: int = b.lane
	var at: float = b.at
	b.release()
	var gone: bool = s.gate(p) == null
	# The same pooled gate risen again for another attack (as GoldenConvergence.place_buttress would).
	b.place(lane, at + 20.0, b.lean)
	s.clear()
	check(gone and s.gate(p) == null and b.standing() and b.state != GoldenConvergenceButtress.State.SINKING,
		"a pass's gate gone back to the pool and risen for another attack is that attack's: the pass's clear leaves it standing")
	await sim.free_world(world)


## A slam plan dropped (the same beat planned again): its rows' floor warnings go (pickups may come back there),
## and the new plan's rows keep off the old plan's cuts (they stay on the track, whole).
func _test_dropped_plan() -> void:
	var pair: Array = _fight(5, 18.0, null, -1, "slams")
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	world.player.god_mode = true
	await _run(world, null, 0.3)
	var sl: GoldenConvergenceSlams = boss.slams
	var start_d: float = world.player.distance + 400.0
	var first: bool = sl.plan_phase_ahead(1, start_d)
	var rows: Array[Vector2] = []
	var markers: Array[Node] = []
	for s: Dictionary in sl.slams:
		rows.append(s["row"])
		markers.append(s["marker"] as Node)
	var warned_before: bool = not rows.is_empty() and boss.props.warned(2, rows[0].x, rows[0].y)
	var cuts: Array[Dictionary] = boss.arena.layout.cuts.duplicate()
	var second: bool = sl.plan_phase_ahead(1, start_d)
	await tree.process_frame
	var markers_gone: bool = not markers.is_empty()
	for m: Node in markers:
		markers_gone = markers_gone and (not is_instance_valid(m) or m.is_queued_for_deletion())
	var overlaps: int = 0
	for s: Dictionary in sl.slams:
		var row: Vector2 = s["row"]
		for c: Dictionary in cuts:
			if float(c["start"]) < row.y - 0.01 and float(c["end"]) > row.x + 0.01:
				overlaps += 1
	var old_free: bool = true
	for row: Vector2 in rows:
		var still_ours: bool = false
		for s: Dictionary in sl.slams:
			still_ours = still_ours or ((s["row"] as Vector2).x < row.y and (s["row"] as Vector2).y > row.x)
		if not still_ours:
			old_free = old_free and not boss.props.warned(2, row.x + 0.1, row.y - 0.1)
	check(first and second and warned_before and markers_gone and old_free,
		"a dropped slam plan's rows no longer keep pickups off (their floor warnings go)")
	check(not sl.slams.is_empty() and overlaps == 0, "and a new plan's rows keep off the cuts already on the track (%d overlaps)" % overlaps)
	await sim.free_world(world)


## A phase ending mid-barrage or mid-slam: through the next phase's intro the hatches swing shut and the arms ease
## back to rest (nothing is left frozen open or stretched to the track).
func _test_looks_ease() -> void:
	var pair: Array = _fight(5, 18.0, null, -1, "barrage")
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	world.player.god_mode = true
	var suit: GoldenConvergenceSuit = boss.suit
	await _run(world, null, 30.0, func() -> bool: return suit.pipes_open[0] > 0.95 or suit.pipes_open[1] > 0.95)
	var opened: bool = suit.pipes_open[0] > 0.95 or suit.pipes_open[1] > 0.95
	boss.damage(boss.hit_damage(), &"test")
	await _run(world, null, 1.5)
	check(opened and boss.state == BossEncounter.State.INTRO and suit.pipes_open[0] < 0.01 and suit.pipes_open[1] < 0.01,
		"a phase ending mid-barrage: the hatches swing shut through the next phase's intro")
	await sim.free_world(world)
	pair = _fight(5, 18.0, null, -1, "slams")
	world = pair[0]
	boss = pair[1]
	world.player.god_mode = true
	suit = boss.suit
	await _run(world, null, 30.0, func() -> bool: return suit.arm_blend[0] > 0.6 or suit.arm_blend[1] > 0.6)
	var out: bool = suit.arm_blend[0] > 0.6 or suit.arm_blend[1] > 0.6
	boss.damage(boss.hit_damage(), &"test")
	await _run(world, null, 2.0)
	check(out and boss.state == BossEncounter.State.INTRO and suit.arm_blend[0] < 0.05 and suit.arm_blend[1] < 0.05,
		"a phase ending mid-slam: the arm eases back to rest through the next phase's intro (%.2f, %.2f)" % [suit.arm_blend[0], suit.arm_blend[1]])
	await sim.free_world(world)


## A hold let go with a horizontal pass next: its gate rises buttress_sight before its line, as every other one does.
func _test_hold_sight() -> void:
	var pair: Array = _fight(5, 18.0, null, -1, "strafe:VH")
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	world.player.god_mode = true
	var s: GoldenConvergenceStrafe = boss.strafe
	await _run(world, null, 30.0, func() -> bool: return s.passes.size() == 2 and int(s.passes[0]["stage"]) == GoldenConvergenceStrafe.PassStage.DONE)
	s.hold(true)
	await _run(world, null, 1.0)
	s.hold(false)
	var released: float = boss.fight_time()
	await _run(world, null, 20.0, func() -> bool: return int(s.passes[1]["stage"]) != GoldenConvergenceStrafe.PassStage.WAIT)
	var placed: Array[Dictionary] = _events(boss, &"buttress_placed").filter(func(e: Dictionary) -> bool: return float(e["t"]) >= released)
	var v: float = boss.speed_planned()
	var lead: float = float(s.passes[1]["line_at"]) - float(placed[0]["runner"]) if not placed.is_empty() else -1.0
	check(placed.size() == 1 and lead >= v * boss.tuning.buttress_sight - v * FRAME * 2.0,
		"after a hold, a horizontal pass first keeps its gate's full sight: it rises %.1f m (%.1f s) before its line" % [lead, lead / v])
	await sim.free_world(world)


# --- Determinism --------------------------------------------------------------------------------------------

func _test_same_every_attempt() -> void:
	var runs: Array = []
	for attempt: int in 2:
		var pair: Array = _fight(5, 18.0, null, -1, "refill:VVH")
		var world: RunWorld = pair[0]
		var boss: GoldenConvergence = pair[1]
		await _run(world, _bot(boss), 60.0, func() -> bool: return boss.phase_index >= 1)
		var trace: Array[String] = []
		for e: Dictionary in boss.events:
			if e["event"] == &"sound":
				continue
			trace.append("%s@%.3f/%d" % [e["event"], float(e["t"]), int(e["phase"])])
		runs.append({"trace": trace, "distance": snappedf(world.player.distance, 0.001)})
		await sim.free_world(world)
	check(runs.size() == 2 and runs[0]["trace"] == runs[1]["trace"] and runs[0]["distance"] == runs[1]["distance"],
		"the Refill Ship plays the same on every attempt (%d events)" % (runs[0]["trace"] as Array).size())


# --- F6's ranges -----------------------------------------------------------------------------------------------

## E5d polish (F6's shortest cage_lead with its farthest generator left the generator a moment ahead of the runner as
## the cage came up: out of reach): at every end of both ranges, on 3, 5 and 6 lanes, the cage's lead
## (GoldenConvergenceCage.lead_seconds) leaves the time to read it, switch in from the farthest lane, jump onto the
## generator and a spare moment before reaching it; played at the worst ends on 6 lanes at 25 m/s, the cage comes up
## that far ahead and the bot stomps the generator and rides the pad.
func _test_f6_extremes() -> void:
	var t0: GoldenConvergenceTuning = def.tuning as GoldenConvergenceTuning
	var faults: PackedStringArray = []
	var lengthened: int = 0
	for lead_high: bool in [false, true]:
		for gen_high: bool in [false, true]:
			var t := t0.duplicate() as GoldenConvergenceTuning
			t.cage_lead = _range_end(t0, &"cage_lead", lead_high)
			t.generator_before = _range_end(t0, &"generator_before", gen_high)
			for lanes: int in LANES:
				var lead: float = GoldenConvergenceCage.lead_seconds(t, tuning, lanes)
				var reach: float = GoldenConvergenceCage.READ_SECONDS + (lanes - 1) * tuning.lane_switch_time \
					+ tuning.jump_time_to_apex + GoldenConvergenceCage.SPARE_SECONDS
				var to_generator: float = lead - t.generator_before / MovementTuning.REFERENCE_SPEED
				if lead > t.cage_lead + 0.001:
					lengthened += 1
				if to_generator < reach - 0.001 or lead < t.cage_lead - 0.001:
					faults.append("%d lanes, lead %.2f s, generator %.0f m: %.2f s to it (needs %.2f s)" % [lanes, t.cage_lead,
						t.generator_before, to_generator, reach])
	check(faults.is_empty() and lengthened > 0, "at every end of F6's ranges the cage's generator stays in reach (%d cases lead longer for it) (%s)" % [
		lengthened, ", ".join(faults)])
	var tag: String = "(the worst ends, 6 lanes, 25 m/s)"
	var pair: Array = _fight(6, 25.0, null, -1, "refill:VVH", func(t: GoldenConvergenceTuning) -> void:
		t.cage_lead = _range_end(t0, &"cage_lead", false)
		t.generator_before = _range_end(t0, &"generator_before", true))
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var r: GoldenConvergenceRefill = boss.refill
	var rec: Dictionary = _watch(world.player)
	await _run(world, _bot(boss), 60.0, func() -> bool: return boss.phase_index >= 1)
	var up: Dictionary = _first(boss, &"cage_up")
	var lead_m: float = float(up.get("front_at", 0.0)) - float(up.get("runner", 0.0))
	var want: float = 25.0 * GoldenConvergenceCage.lead_seconds(boss.tuning, tuning, 6)
	check(not up.is_empty() and absf(lead_m - want) < 0.5, "the cage comes up %.0f m ahead (lead_seconds: %.0f m) %s" % [lead_m, want, tag])
	var gen: Dictionary = _first(boss, &"cage_generator")
	check(gen.get("cause", &"") == &"stomp" and r.cage.touches.is_empty() and r.chains == 1 and boss.phase_index == 1
		and world.player.alive, "the bot stomps the generator, rides the pad untouched and the hit lands %s (%s)" % [tag, rec["cause"]])
	await sim.free_world(world)


## The low (or the high) end of `prop`'s F6 range on `res` (its @export_range), or its value without one.
static func _range_end(res: Resource, prop: StringName, high: bool) -> float:
	for info: Dictionary in res.get_property_list():
		if StringName(info["name"]) == prop and int(info["hint"]) == PROPERTY_HINT_RANGE:
			var parts: PackedStringArray = String(info["hint_string"]).split(",")
			return float(parts[1] if high else parts[0])
	return float(res.get(prop))

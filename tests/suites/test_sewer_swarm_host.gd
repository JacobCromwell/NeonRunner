extends TestSuite
## The Sewer Swarm's phase 3, The Host (GDD §10; task E4b), from the phase's start (a retry's checkpoint
## would do the same: the fight resumes there for tests), at 3, 5 and 6 lanes and 18 and 21.8 m/s:
## - its entrance: the pipe across the street ahead, the Host bursting out of it into the street ahead;
## - its implants reached by a ramp and a wall jump (GDD §10): a runner who never baits its lunges (and keeps
##   out of a fence's lane while one warns) wins the phase with three stomps at every lane count and both
##   speeds, without god mode, and never touches its attacks;
## - its lunge: warned (the roar and the red line) warning_seconds before its hitbox goes live; baited into a
##   fence it's shocked, a hit; its flings warned (the wind-up and a red circle where it lands) before the
##   splat, which never catches a runner who leaves the lane;
## - its crouch: solid (a runner in its lane runs into it), its sides bumping a lane switch back, its implants
##   a weak point only from above;
## - its defeat: the screeches scatter, the implants short out, the person slumps free, the results after;
##   Reduced flashing holds its shock's crackle steady;
## - weapons stay within the framework's cap (BossDef.weapon_share_cap) over the whole fight.

const BOSS_PATH: String = "res://data/bosses/gangland_boss.tres"
const LANES: Array[int] = [3, 5, 6]
const SPEEDS: Array[float] = [18.0, 21.8]
const HOST_PHASE: int = 2
## A player's reaction to a warning.
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
	await _test_stomps_win()
	await _test_lunge_baited()
	await _test_crouch_is_solid()
	await _test_defeat()
	await _test_weapons_cap()


# --- Helpers -------------------------------------------------------------------------------------

## The fight at `lanes` and `speed` m/s from phase `phase`: [world, boss, context].
func _fight(lanes: int, speed: float = 0.0, phase: int = HOST_PHASE, loadout: Loadout = null) -> Array:
	var boss := BossEncounter.create(def) as SewerSwarm
	var t: MovementTuning = tuning
	if speed > 0.0 and not is_equal_approx(speed, tuning.run_speed):
		t = tuning.duplicate() as MovementTuning
		t.run_speed = speed
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = def
	ctx.config = BossArena.base_config(def)
	ctx.config.lane_count = lanes
	ctx.tuning = t
	ctx.loadout = loadout
	if phase > 0:
		ctx.boss_resume = {"phase": phase}
	var arena: BossArena = boss.plan_arena(ctx)
	var world: RunWorld = sim.build_world(arena.layout, loadout, t, ctx.config)
	boss.setup(world, ctx, arena)
	return [world, boss, ctx]


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


## Puts the runner on the street in `lane` at track distance `d`, in the middle of its lane.
func _place(player: Player, lane: int, d: float) -> void:
	player.distance = d
	player.lane = lane
	player.set(&"_x", player.geo.lane_x(lane))
	player.set(&"_switch_t", 1.0)
	player.set(&"_bumping", false)
	player.surface = Player.Surface.FLOOR
	player.h = 0.0
	player.vh = 0.0
	player.grounded = true
	player.in_pit = false


func _sounds(boss: BossEncounter, sound: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in _events(boss, &"sound"):
		if e["name"] == sound:
			out.append(e)
	return out


# --- Three stomps ------------------------------------------------------------------------------------

## The way up proven end to end: at every lane count and both speeds, a runner who never baits its lunges takes
## each crouch's ramp onto the wall and wall-jumps down onto its implants; three stomps free the Host. Its
## entrance (the pipe, the burst) comes first; every attack along the way is warned and dodged.
func _test_stomps_win() -> void:
	for speed: float in SPEEDS:
		for lanes: int in LANES:
			await _stomps_win(lanes, speed)


func _stomps_win(lanes: int, speed: float) -> void:
	var tag: String = "(%d lanes, %.1f m/s)" % [lanes, speed]
	var pair: Array = _fight(lanes, speed)
	var world: RunWorld = pair[0]
	var boss: SewerSwarm = pair[1]
	var t: SewerSwarmTuning = boss.tuning
	var bot := SewerSwarmBot.new(boss)
	bot.baits = false
	bot.reaction = REACTION
	var cause: Array = [""]
	world.player.died.connect(func(c: String) -> void: cause[0] = c)
	var pipe_ahead: float = boss.pipe.at - world.player.distance
	await _run(world, 120.0, func() -> bool: return boss.is_defeated(), func() -> void: bot.step())
	var stomps: Array[Dictionary] = _events(boss, &"host_stomped")
	check(boss.is_defeated() and world.player.alive and stomps.size() == 3 and boss.host_attacks.shocked == 0,
		"a runner who takes the ramps and wall-jumps onto its implants frees the Host with three stomps %s%s" % [tag,
		"" if world.player.alive else ": %s at %.0f m" % [cause[0], world.player.distance]])
	check(_events(boss, &"host_hit").is_empty() and _events(boss, &"weak_point").size() == 3,
		"and never touches its attacks or its body %s" % tag)
	# The entrance: the pipe across the street ahead, the Host bursting out of it and dropping onto the street.
	var burst: Array[Dictionary] = _events(boss, &"host_burst")
	check(pipe_ahead > 60.0 * boss.run_pace() and burst.size() == 1 and _sounds(boss, &"host_burst").size() == 1
		and float(burst[0]["at"]) - float(burst[0]["d"]) >= t.host_burst_at * boss.run_pace() - 1.0,
		"it bursts out of a pipe across the street ahead (%.0f m ahead as the phase begins) %s" % [pipe_ahead, tag])
	# Each crouch: settled in its ramp's lane past the ramp, its marks on the ramp's wall, in time to reach.
	var crouches: Array[Dictionary] = _events(boss, &"host_crouch")
	var reach_ok: bool = crouches.size() >= 3
	for c: Dictionary in crouches:
		var ahead: float = float(c["ramp"]) - float(c["d"])
		# Settled with time to cross the street to the ramp's lane: a reaction and a switch a lane.
		var need: float = (REACTION + (lanes - 1) * world.tuning.lane_switch_time + 0.3) * boss.run_speed()
		reach_ok = reach_ok and ahead >= need and int(c["lane"]) == (0 if int(c["side"]) < 0 else lanes - 1)
	check(reach_ok, "each crouch is settled in its ramp's lane with time to get there from any lane %s" % tag)
	# Every stomp came from a wall jump (the bot's log) off a ramp's wall run.
	var jumps: int = 0
	for l: Dictionary in bot.log:
		jumps += 1 if l["why"] == "wall jump" else 0
	check(jumps >= 3, "each stomp came down from a wall jump off a ramp's wall run (%d) %s" % [jumps, tag])
	# Every fling warned: its circle before it lands, as long as its wind-up and flight; no splat hits.
	var flings: Array[Dictionary] = _events(boss, &"host_fling")
	var splats: Array[Dictionary] = _events(boss, &"host_splat")
	var fling_ok: bool = flings.size() == splats.size()
	for i: int in mini(flings.size(), splats.size()):
		fling_ok = fling_ok and float(splats[i]["t"]) - float(flings[i]["t"]) >= t.fling_windup + t.fling_flight - 0.03
	check(fling_ok and _sounds(boss, &"host_fling").size() == flings.size(),
		"every fling is warned (its wind-up, its sound and a red circle where it lands, %.1f s before) %s" % [
		t.fling_windup + t.fling_flight, tag])
	# Every lunge warned before its hitbox goes live, and dodged.
	var warns: Array[Dictionary] = _events(boss, &"host_lunge_warn")
	var locks: Array[Dictionary] = _events(boss, &"host_lunge")
	var lunge_ok: bool = warns.size() == locks.size() and _sounds(boss, &"host_roar").size() == warns.size()
	for i: int in mini(warns.size(), locks.size()):
		lunge_ok = lunge_ok and absf(float(locks[i]["t"]) - float(warns[i]["t"]) - (t.warning_seconds - t.lock_seconds)) < 0.03
		lunge_ok = lunge_ok and not bool(locks[i]["baited"])
	check(lunge_ok, "every lunge roars and shows its line %.1f s before it lands, and goes by unbaited %s" % [
		t.warning_seconds - t.lock_seconds, tag])
	await sim.free_world(world)


# --- Its lunge baited into a fence -----------------------------------------------------------------

## A runner in the fence spot's lane at the lock, out of it after: the Host charges into the fence, shocked
## (a hit, its sound and a burst), down in that lane past the fence, solid; then it leaps back to its station.
func _test_lunge_baited() -> void:
	for speed: float in SPEEDS:
		var tag: String = "(5 lanes, %.1f m/s)" % speed
		var pair: Array = _fight(5, speed)
		var world: RunWorld = pair[0]
		var boss: SewerSwarm = pair[1]
		var bot := SewerSwarmBot.new(boss)
		bot.reaction = REACTION
		bot.stomps = false
		# (A lambda's locals are copies: the health before the hit is kept in an array.)
		var before: Array = [-1.0]
		await _run(world, 60.0, func() -> bool: return boss.host_attacks.shocked >= 1, func() -> void:
			bot.step()
			if float(before[0]) < 0.0 and boss.is_vulnerable():
				before[0] = boss.health)
		var health0: float = float(before[0])
		var shocked: Array[Dictionary] = _events(boss, &"host_shocked")
		var lunges: Array[Dictionary] = _events(boss, &"host_lunge")
		check(shocked.size() == 1 and lunges.size() >= 1 and bool(lunges[0]["baited"])
			and is_equal_approx(health0 - boss.health, boss.hit_damage()) and _sounds(boss, &"swarm_shock").size() >= 1,
			"its lunge baited into a fence: shocked, a hit (%.1f) %s" % [health0 - boss.health, tag])
		check(world.player.alive and _events(boss, &"host_hit").is_empty() and float(shocked[0]["at"]) - float(shocked[0]["d"]) >= 4.0,
			"in front of the runner, who's out of its way %s" % tag)
		check(boss.host.pose == SwarmHost.Pose.STUNNED and boss.host.body.is_active() and boss.host.blocker.collision_layer != 0,
			"down in its lane past the fence: solid, its sides bumping lane switches back %s" % tag)
		await _run(world, 4.0, func() -> bool: return boss.host_attacks.step == SwarmHostAttacks.Step.PACE, func() -> void: bot.step())
		check(boss.host_attacks.step == SwarmHostAttacks.Step.PACE and not boss.host.body.is_active()
			and boss.host.at > world.player.distance + 10.0, "then it leaps back to its station ahead %s" % tag)
		await sim.free_world(world)


# --- The crouch is solid -----------------------------------------------------------------------------

## A runner who stays down in the ramp's lane past the ramp (jumping over the ramp) runs into the crouching
## Host: its body is solid. A lane switch into it from beside it bumps back. Its implants are harmless to
## touch except from above.
func _test_crouch_is_solid() -> void:
	var pair: Array = _fight(5, 18.0)
	var world: RunWorld = pair[0]
	var boss: SewerSwarm = pair[1]
	var bot := SewerSwarmBot.new(boss)
	bot.baits = false
	bot.stomps = false
	await _run(world, 40.0, func() -> bool: return boss.host_attacks.step == SwarmHostAttacks.Step.CROUCH, func() -> void: bot.step())
	check(boss.host_attacks.step == SwarmHostAttacks.Step.CROUCH, "the Host crouches at a host spot")
	if boss.host_attacks.step != SwarmHostAttacks.Step.CROUCH:
		await sim.free_world(world)
		return
	var spot: Dictionary = boss.host_attacks.event["spot"]
	var lane: int = int(spot["lane"])
	var beside: int = lane + (1 if lane == 0 else -1)
	# Beside it: a switch into its lane bumps back.
	_place(world.player, beside, float(spot["from"]) + 3.0)
	await physics_frames(3)
	var events: Array[StringName] = []
	world.player.movement_event.connect(func(kind: StringName) -> void: events.append(kind))
	world.player.press(&"move_left" if lane < beside else &"move_right")
	await physics_frames(20)
	check(events.has(&"lane_blocked") and world.player.lane == beside and world.player.alive,
		"a lane switch into it from beside it bumps back (its sides are solid, safe)")
	await sim.free_world(world)
	# Down in its lane behind it (over the ramp): running into it is deadly.
	pair = _fight(5, 18.0)
	world = pair[0]
	boss = pair[1]
	bot = SewerSwarmBot.new(boss)
	bot.baits = false
	bot.stomps = false
	await _run(world, 40.0, func() -> bool: return boss.host_attacks.step == SwarmHostAttacks.Step.CROUCH, func() -> void: bot.step())
	spot = boss.host_attacks.event["spot"]
	var died: Array = [""]
	world.player.died.connect(func(c: String) -> void: died[0] = c)
	await _run(world, 0.5, func() -> bool: return bool(boss.host_attacks.event.get("settled", false)))
	_place(world.player, int(spot["lane"]), float(spot["from"]) - 6.0)
	await _run(world, 2.0, func() -> bool: return not world.player.alive)
	check(not world.player.alive and _events(boss, &"host_hit").size() >= 1,
		"running into its body in its lane is deadly (%s)" % died[0])
	await sim.free_world(world)


# --- The defeat --------------------------------------------------------------------------------------

## The third hit frees the Host (GDD §10): the screeches scatter, every implant shorts out, the person slumps
## onto the street; the horde drains away; the results come once it has played out. Reduced flashing holds
## the shock's crackle and the implants' sparks steady.
func _test_defeat() -> void:
	var pair: Array = _fight(5, 21.8)
	var world: RunWorld = pair[0]
	var boss: SewerSwarm = pair[1]
	world.player.god_mode = true
	# One hit left.
	boss.health = boss.hit_damage() * 1.001
	var bot := SewerSwarmBot.new(boss)
	bot.reaction = REACTION
	await _run(world, 60.0, func() -> bool: return boss.is_defeated(), func() -> void: bot.step())
	check(boss.is_defeated() and boss.host.pose == SwarmHost.Pose.FREED and boss.host_attacks.step == SwarmHostAttacks.Step.FREED,
		"the third hit frees the Host")
	check(_sounds(boss, &"host_short").size() >= 1 and boss.host.implants_left == 0, "its implants short out (host_short)")
	var person_y0: float = boss.host.person.global_position.y
	await _run(world, 1.2, func() -> bool: return false)
	var life: Vector4 = boss.host.crowd.material.get_shader_parameter(&"life")
	check(life.z > 2.5 and life.w > 0.5, "its screeches scatter (the crowd's scatter plays)")
	check(boss.host.person.global_position.y <= maxf(person_y0, 0.0) + 0.01 and boss.host.person.global_position.y < 0.6,
		"the person slumps free onto the street (at %.2f m)" % boss.host.person.global_position.y)
	check(not boss.victory_over(), "the results wait while it plays out")
	await _run(world, boss.tuning.freed_seconds, func() -> bool: return boss.victory_over())
	check(boss.victory_over() and boss.horde.fill < 0.5, "then they come, the horde drained away")
	var code: String = SwarmCrowd.SHADER.code
	check(code.contains("host.w * warning_flicker"), "the Host's shock crackles only through warning_flicker (steady with Reduced flashing)")
	await sim.free_world(world)


# --- Weapons -----------------------------------------------------------------------------------------

## The best weapon over the whole fight (from its start: clusters and the Host): its damage stays within the
## framework's cap (BossDef.weapon_share_cap of the boss's health), a cluster it thins to nothing counted in
## it; and the fight is still won by the street.
func _test_weapons_cap() -> void:
	var heavy := Loadout.new()
	heavy.tiers[&"weapon"] = 4
	var pair: Array = _fight(5, 18.0, 0, heavy)
	var world: RunWorld = pair[0]
	var boss: SewerSwarm = pair[1]
	world.player.god_mode = true
	var bot := SewerSwarmBot.new(boss)
	bot.reaction = REACTION
	await _run(world, 160.0, func() -> bool: return boss.is_defeated(), func() -> void: bot.step())
	var cap: float = boss.max_health * def.weapon_share_cap
	var by_weapon: int = int(boss.destroyed_by.get(&"weapon", 0))
	check(boss.weapon_damage > 0.0 and boss.weapon_damage <= cap + 0.01,
		"weapons dealt %.1f of the boss's %.0f health, within the framework's cap (%.1f; %d clusters thinned to nothing)" % [
		boss.weapon_damage, boss.max_health, cap, by_weapon])
	check(boss.is_defeated(), "and the fight is still won")
	await sim.free_world(world)

extends TestSuite
## Captain Cogs' bombs and the hits on Mecha Guppy (GDD §10; task E5e-b2; the climb: test_mecha_guppy_climb.gd, the
## shark's bites and breaches: test_mecha_guppy_bites.gd), on real physics:
## - the sounds are in the library: the throw, the shark coming up, its bite, the clang of a hit; the bombs keep the
##   Floating Head's whistle and blast; warnings play in their key;
## - Captain Cogs' ship has no collision (no pad flips a runner up to it) and flies ahead of the runner, high over the
##   huts; a pier's collision is a full-height box;
## - fair spots, planned from every lane that leads up (where a rider is at the hut's deadline) at 3, 5 and 6 lanes and
##   both speeds, in both phases (phase 1's volleys on the higher roof, phase 2's volley and landing spot): a way
##   through each volley, its every lane on floor at each spot and every lane crossed to get there too (never off a
##   pier's side into the chasm), every bomb on a roof's top with no hut over or near it, each spot leaving a lane free;
## - a bomb's fuse sparks as it flies, steady with Reduced flashing;
## - real contact only: a blast kills a runner in its lane and spares one in the next; it's an enemy attack (armor and
##   the shield block it, the dash passes through, claws don't help) too tall to jump, its hitbox smaller than its
##   fireball; a rider under a hut with a bomb on its top is never touched (the blast is all above the hut), and that
##   bomb shows no circle;
## - what counts as a hit: a bomb onto a roof bursts (no hit); one into the chasm with the shark down falls away (no
##   hit); one thrown at the chasm as the shark rises there goes into its open jaws, high in its mouth: a hit;
## - the fight (3 lanes at 23.8 m/s, 6 at 18 m/s, MechaGuppyBot): every bomb that can land where a runner can be shows
##   its red circle where it lands, at that floor's height, out of the fog, from the throw until it lands
##   (lock_seconds at least, a volley's later spots longer), each throw heard, each bomb whistling before it lands, a
##   bomb on a hut without a circle; every hit is a bomb into the shark's jaws over the chasm, 4 end phase 1 and 6
##   phase 2, phase 2 throws more bombs a step than phase 1, and the clean runner is never hurt;
## - no escalation: with no hit ever landing (MechaGuppyPattern.hits_enabled off), phase 1 goes on step after step
##   with the same bombs a step, the same spots from the same places; a retry plays the same bombs.

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
	_test_sounds()
	await _test_ship_and_piers()
	await _test_fair_spots()
	await _test_blast_rules()
	await _test_reduced_flashing()
	await _test_contact()
	await _test_ceiling()
	await _test_what_counts()
	await _test_fight(3, 23.8)
	await _test_fight(6, 18.0)
	await _test_no_escalation()
	await _test_retry()


# --- Helpers -------------------------------------------------------------------------------

func _movement(speed: float) -> MovementTuning:
	if is_equal_approx(speed, tuning.run_speed):
		return tuning
	var t: MovementTuning = tuning.duplicate() as MovementTuning
	t.run_speed = speed
	return t


## The fight at `lanes` and `speed` m/s, from phase index `phase` (a resume), with Captain Cogs' bombs and Mecha
## Guppy's bites on or off: [world, boss].
func _fight(lanes: int, speed: float, phase: int = 0, attacks: bool = true) -> Array:
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
	var world: RunWorld = sim.build_world(arena.layout, null, t, ctx.config)
	boss.setup(world, ctx, arena)
	boss.attacks_enabled = attacks
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


## Waits until the fight's pattern runs (its intro over: register_hit counts from then on).
func _until_pattern(world: RunWorld, boss: MechaGuppy) -> void:
	await _run(world, 10.0, func() -> bool: return boss.is_vulnerable())


# --- The sounds ---------------------------------------------------------------------------------

func _test_sounds() -> void:
	var library := load("res://data/audio/sfx_library.tres") as SfxLibrary
	for sound: StringName in [&"cogs_throw", &"guppy_rumble", &"guppy_bite", &"guppy_clang", &"bomb_whistle", &"bomb_blast"]:
		check(library.names().has(String(sound)) and library.stream(sound) != null, "the sound library has '%s'" % sound)
	for warning: StringName in [&"guppy_rumble", &"bomb_whistle", &"cogs_throw"]:
		check(float(library.pitch_variation.get(String(warning), 0.0)) == 0.0, "'%s' (a warning) plays in its key" % warning)


# --- The ship, the piers ----------------------------------------------------------------------------

## Captain Cogs' ship has no collision at all (never on the hull layer: no pad flips a runner up to it), keeps its
## station ahead of and high above the runner, over every hut; a pier's collision (the lanes that reach back) is a
## full-height box, its stilts only its look, so nothing about it invites a dodge off its side.
func _test_ship_and_piers() -> void:
	var pair: Array = _fight(3, 23.8, 0, false)
	var world: RunWorld = pair[0]
	var boss: MechaGuppy = pair[1]
	var p: Player = world.player
	var bot := MechaGuppyBot.new(boss)
	bot.reaction = REACTION
	var climb: MechaGuppyClimb = boss.climb
	# On to the second step's pads: its REACH_BACK pier (the third roof's lanes that reach back) is built by then.
	var low: Array[float] = [INF]
	await _run(world, 20.0, func() -> bool: return p.distance > climb.steps[1].pad, func() -> void:
		bot.step()
		var ship_y: float = boss.ship.global_position.y
		var hut: MechaGuppyClimb.Step = climb.step_at(p.distance + boss.tuning.ship_ahead)
		if hut != null and not hut.top:
			low[0] = minf(low[0], ship_y - hut.hut_y))
	var solid: Array[Node] = boss.ship.find_children("*", "CollisionObject3D", true, false)
	check(solid.is_empty(), "Captain Cogs' ship has no collision at all (%d bodies)" % solid.size())
	check(boss.ship.global_position.z < -p.distance - 20.0 and low[0] > 3.0,
		"it flies ahead of the runner, high over the huts ahead (at least %.1f m over them)" % low[0])
	var step: MechaGuppyClimb.Step = climb.steps[1]
	var roof: MechaGuppyClimb.Roof = climb.roofs[2]
	check(step.cue == MechaGuppyClimb.Cue.REACH_BACK, "the second step's cue is the roof's lanes reaching back")
	var pier: int = step.up.x
	var beside: int = pier - 1 if pier > 0 else pier + 1
	var z: float = TrackGeometry.world_z((roof.start_in(pier) + roof.full_from()) * 0.5)
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var full: bool = true
	for share: float in [0.15, 0.5, 0.9]:
		var y: float = roof.top * share
		var q := PhysicsRayQueryParameters3D.create(Vector3(world.geo.lane_x(beside), y, z), Vector3(world.geo.lane_x(pier), y, z),
			TrackBuilder.LAYER_FLOOR)
		full = full and not space.intersect_ray(q).is_empty()
	check(full and roof.start_in(pier) < roof.full_from() - 1.0, "a pier's collision is a full-height box under its deck (lane %d)" % pier)
	await sim.free_world(world)


# --- Fair spots -----------------------------------------------------------------------------------

## Every volley and landing spot the pattern would throw, planned from every lane that leads up, leaves a fair way
## through (see the header).
func _test_fair_spots() -> void:
	for speed: float in SPEEDS:
		for lanes: int in LANES:
			for phase: int in 2:
				var tag: String = "(%d lanes, %.1f m/s, phase %d)" % [lanes, speed, phase + 1]
				var pair: Array = _fight(lanes, speed, phase, false)
				var world: RunWorld = pair[0]
				var boss: MechaGuppy = pair[1]
				var climb: MechaGuppyClimb = boss.climb
				var mt: MechaGuppyTuning = boss.tuning
				climb.plan_until(climb.planned_until() + 900.0, phase)
				var volleys: int = 0
				var bad: Array[String] = []
				for step: MechaGuppyClimb.Step in climb.steps:
					if step.top or step.index + 1 >= climb.steps.size() or step.phase != phase:
						continue
					for kind: int in 2:
						for pl: int in range(step.up.x, step.up.y + 1):
							var plan: Dictionary = _volley(boss, kind, step, pl, step.deadline, speed)
							var spots: Array[Dictionary] = plan["spots"]
							if spots.is_empty():
								continue
							# Planned from where the runner is as it's thrown (the pattern's lock point).
							var d0: float = maxf(float(spots[0]["at"]) - (mt.lock_seconds + mt.arrival_seconds) * speed, step.deadline)
							plan = _volley(boss, kind, step, pl, d0, speed)
							spots = plan["spots"]
							volleys += 1
							var why: String = _unfair(boss, spots, pl, d0, float(plan["s_open"]), speed)
							if why != "":
								bad.append("step %d %s from lane %d: %s" % [step.index, "volley" if kind == 0 else "landing spot", pl, why])
				check(volleys >= 4 and bad.is_empty(), "every volley leaves a fair way through from every lane that leads up (%d planned) %s%s"
					% [volleys, tag, "" if bad.is_empty() else ": " + "; ".join(bad.slice(0, 3))])
				await sim.free_world(world)


func _volley(boss: MechaGuppy, kind: int, step: MechaGuppyClimb.Step, lane: int, d0: float, speed: float) -> Dictionary:
	return boss.pattern.roof_volley(step, lane, d0, speed) if kind == 0 else boss.pattern.landing_volley(step, lane, d0, speed)


## Why a volley isn't fair from lane `pl` at `d0` (switching from `s_open`) for a runner at `speed`, or "" if it is.
func _unfair(boss: MechaGuppy, spots: Array[Dictionary], pl: int, d0: float, s_open: float, speed: float) -> String:
	var bombs: MechaGuppyBombs = boss.bombs
	var climb: MechaGuppyClimb = boss.climb
	var mt: MechaGuppyTuning = boss.tuning
	var t: MovementTuning = _movement(speed)
	var n: int = boss.lane_count()
	var way: Array[int] = bombs.way_through(spots, pl, d0, s_open)
	if way.size() != spots.size():
		return "no way through"
	var clear: float = mt.blast_depth * 0.5 + MechaGuppyBombs.HUT_CLEAR
	# In time: from when they can act (its circle seen and the reaction, and able to switch) every switch to the first
	# spot's free lane at the lane-switch time, with the margin to spare, before they get to it; from one spot to the
	# next, every switch between them after the last blast's far edge and before the next one's near edge.
	var act: float = maxf(mt.dodge_reaction, (s_open - d0) / speed)
	var first: float = (float(spots[0]["at"]) - d0) / speed
	if act + absi(way[0] - pl) * t.lane_switch_time + mt.dodge_margin > first + 0.01:
		return "the first spot's %d switches don't fit in %.2f s from %.2f s" % [absi(way[0] - pl), first, act]
	for i: int in range(1, spots.size()):
		var between: float = (float(spots[i]["at"]) - float(spots[i - 1]["at"]) - mt.blast_depth) / speed
		if absi(way[i] - way[i - 1]) * t.lane_switch_time > between + 0.01:
			return "spot %d's switches don't fit in the %.2f s after the last" % [i, between]
	var from: int = pl
	for i: int in spots.size():
		var spot: Dictionary = spots[i]
		var at: float = float(spot["at"])
		var y: float = float(spot["y"])
		var struck: Array = spot["lanes"]
		if struck.size() >= n:
			return "a spot strikes every lane"
		for lane: int in struck:
			if bombs.surface_at(lane, at, y) != MechaGuppyBombs.Lands.ROOF:
				return "a bomb at %.0f m in lane %d isn't on a roof's top" % [at, lane]
			for dz: float in [-clear, 0.0, clear]:
				if not is_nan(climb.hut_at(lane, at + dz)):
					return "a bomb at %.0f m in lane %d is under or near a hut" % [at, lane]
		var to: int = way[i]
		if struck.has(to):
			return "the way's lane %d is struck at %.0f m" % [to, at]
		for lane: int in range(mini(from, to), maxi(from, to) + 1):
			if bombs.surface_at(lane, at, y) != MechaGuppyBombs.Lands.ROOF:
				return "the way crosses lane %d with no floor at %.0f m" % [lane, at]
		from = to
	return ""


# --- Real contact ---------------------------------------------------------------------------------

## The shared damage rules on a live blast: an enemy attack.
func _test_blast_rules() -> void:
	var pair: Array = _fight(3, 18.0, 0, false)
	var world: RunWorld = pair[0]
	var boss: MechaGuppy = pair[1]
	var p: Player = world.player
	p.god_mode = true
	await _run(world, 0.2, func() -> bool: return false)
	var at: float = p.distance + 40.0
	boss.bombs.throw_at(MechaGuppyBombs.Kind.TEST, 0, at, 0.0)
	await _run(world, 4.0, func() -> bool: return not boss.bombs.blast_hazards().is_empty())
	var hazards: Array[Hazard] = boss.bombs.blast_hazards()
	check(not hazards.is_empty(), "a bomb on a roof goes off")
	if not hazards.is_empty():
		var h: Hazard = hazards[0]
		var d := DamageRules.Defense.new()
		check(DamageRules.resolve(h, d) == DamageRules.Outcome.KILL, "a blast kills an unprotected runner")
		d.armor = true
		check(DamageRules.resolve(h, d) == DamageRules.Outcome.BLOCKED_ARMOR, "armor blocks it (an enemy attack)")
		d.armor = false
		d.shield = true
		check(DamageRules.resolve(h, d) == DamageRules.Outcome.BLOCKED_SHIELD, "the shield blocks it")
		d.shield = false
		d.claws = true
		check(DamageRules.resolve(h, d) == DamageRules.Outcome.KILL, "claws don't")
		d.claws = false
		d.dashing = true
		check(DamageRules.resolve(h, d) == DamageRules.Outcome.IGNORE, "the dash passes through it")
		var mt: MechaGuppyTuning = boss.tuning
		check(h.size.y > tuning.jump_height + 0.3, "it's too tall to jump over (%.1f m)" % h.size.y)
		var fire: float = mt.blast_radius * MechaGuppyBombs.FIRE_SIZE_PER_RADIUS * 2.0
		check(h.size.x < world.geo.lane_width and h.size.x <= fire and h.size.z <= fire,
			"its hitbox is smaller than its fireball and its lane (%.2f x %.2f m, fireball %.2f m)" % [h.size.x, h.size.z, fire])
		check(absf(h.global_position.y - h.size.y * 0.5) < 0.05, "it stands on the roof's top")
	await sim.free_world(world)


## A bomb's fuse sparks as it flies, and holds steady with Settings > Reduced flashing.
func _test_reduced_flashing() -> void:
	var was: bool = Settings.flashing_reduced
	var flickers: Array[bool] = []
	for reduced: bool in [false, true]:
		Settings.flashing_reduced = reduced
		var pair: Array = _fight(3, 18.0, 0, false)
		var world: RunWorld = pair[0]
		var boss: MechaGuppy = pair[1]
		var p: Player = world.player
		p.god_mode = true
		await _run(world, 0.2, func() -> bool: return false)
		var d: Dictionary = boss.bombs.throw_at(MechaGuppyBombs.Kind.TEST, 0, p.distance + 40.0, 0.0)
		var seen: Array[int] = [0, 0]
		await _run(world, 2.0, func() -> bool: return bool(d["landed"]), func() -> void:
			var bomb: Node3D = d["bomb"]
			if bomb != null and bomb.visible and bomb.get_child_count() > 0:
				seen[1 if (bomb.get_child(0) as Node3D).visible else 0] += 1)
		flickers.append(seen[0] > 0 and seen[1] > 0)
		if reduced:
			check(seen[0] == 0 and seen[1] > 0, "with Reduced flashing the fuse's spark holds steady (%d frames dark)" % seen[0])
		await sim.free_world(world)
	check(flickers[0], "without it, the fuse sparks on and off")
	Settings.flashing_reduced = was


## A blast timed to a runner's arrival kills them in its lane and spares them in the next (real contact only).
func _test_contact() -> void:
	for beside: bool in [false, true]:
		var pair: Array = _fight(3, 18.0, 0, false)
		var world: RunWorld = pair[0]
		var boss: MechaGuppy = pair[1]
		var p: Player = world.player
		var cause: Array[String] = [""]
		p.died.connect(func(c: String) -> void: cause[0] = c)
		await _run(world, 0.3, func() -> bool: return false)
		var lane: int = p.lane + (1 if beside else 0)
		var at: float = p.distance + p.speed * boss.tuning.lock_seconds + 1.0
		boss.bombs.throw_at(MechaGuppyBombs.Kind.TEST, lane, at, 0.0)
		await _run(world, 3.0, func() -> bool: return p.distance > at + 4.0)
		var blasted: bool = not _events(boss, &"blast").is_empty()
		if beside:
			check(blasted and p.alive, "a blast in the next lane spares the runner (real contact only)")
		else:
			check(blasted and not p.alive and cause[0].contains(MechaGuppyBombs.BOMB_NAME),
				"a blast in the runner's lane as they get there kills them (%s)" % cause[0])
		await sim.free_world(world)


## A rider under a hut with a bomb bursting on its top is never touched; that bomb shows no circle.
func _test_ceiling() -> void:
	var pair: Array = _fight(3, 23.8, 0, false)
	var world: RunWorld = pair[0]
	var boss: MechaGuppy = pair[1]
	var p: Player = world.player
	var bot := MechaGuppyBot.new(boss)
	bot.reaction = REACTION
	var step: MechaGuppyClimb.Step = boss.climb.steps[0]
	await _run(world, 12.0, func() -> bool: return p.surface == Player.Surface.CEILING and p.grounded \
		and p.distance > step.hut_start + 6.0, bot.step)
	check(p.surface == Player.Surface.CEILING, "the runner is up on the first hut")
	var at: float = p.distance + p.speed * boss.tuning.lock_seconds + 1.0
	var y: float = step.hut_y + TrackBuilder.HULL_THICKNESS
	var lane: int = p.lane
	check(boss.bombs.surface_at(lane, at, y) == MechaGuppyBombs.Lands.HUT, "a bomb over the rider meets the hut's top")
	var d: Dictionary = boss.bombs.throw_at(MechaGuppyBombs.Kind.HUT, lane, at, y)
	check(d["circle"] == null, "a bomb on a hut shows no circle (nobody can stand there)")
	var bottom: Array[float] = [INF]
	var under: Array[bool] = [false]
	await _run(world, 3.0, func() -> bool: return p.distance > at + 4.0, func() -> void:
		for h: Hazard in boss.bombs.blast_hazards():
			bottom[0] = minf(bottom[0], h.global_position.y - h.size.y * 0.5)
			under[0] = under[0] or absf(-h.global_position.z - p.distance) < h.size.z * 0.5 + 0.5
		bot.step())
	check(p.alive and bottom[0] >= y - 0.01 and under[0],
		"the rider passes right under the blast unhurt: it's all above the hut (its bottom %.2f m, the hut's top %.2f m)"
		% [bottom[0], y])
	await sim.free_world(world)


# --- What counts as a hit -------------------------------------------------------------------------

func _test_what_counts() -> void:
	var pair: Array = _fight(3, 23.8, 0, false)
	var world: RunWorld = pair[0]
	var boss: MechaGuppy = pair[1]
	var p: Player = world.player
	p.god_mode = true
	var bot := MechaGuppyBot.new(boss)
	bot.reaction = REACTION
	await _until_pattern(world, boss)
	check(boss.is_vulnerable(), "the fight's pattern runs")
	var bombs: MechaGuppyBombs = boss.bombs
	var climb: MechaGuppyClimb = boss.climb
	var step: MechaGuppyClimb.Step = climb.steps[0]
	var roof1: MechaGuppyClimb.Roof = climb.roofs[1]
	# Onto a roof (the street ahead): it bursts, no hit.
	bombs.throw_at(MechaGuppyBombs.Kind.TEST, 1, p.distance + 30.0, 0.0)
	# Into the chasm in front of the higher roof with the shark down: it falls away, no hit.
	var gap: float = (climb.roofs[0].end + roof1.start_in(0)) * 0.5
	check(bombs.surface_at(0, gap, roof1.top) == MechaGuppyBombs.Lands.CHASM, "there's no floor in front of the higher roof")
	bombs.throw_at(MechaGuppyBombs.Kind.TEST, 0, gap, roof1.top)
	await _run(world, 2.6, func() -> bool: return bombs.in_air() == 0, bot.step)
	check(int(bombs.stats["roof"]) == 1 and int(bombs.stats["chasm"]) == 1 and boss.hits_landed == 0
		and _events(boss, &"hit").is_empty(),
		"a bomb onto a roof bursts and one into the chasm with the shark down falls away: neither is a hit")
	# Thrown at the chasm as the shark rises there to eat (MechaGuppyPattern's hit): into its open jaws, a hit.
	var spot: Dictionary = boss.pattern.hit_spot(step)
	var d: Dictionary = bombs.throw_at(MechaGuppyBombs.Kind.HIT, int(spot["lane"]), float(spot["at"]), float(spot["y"]),
		float(spot["x_off"]), boss.tuning.hit_seconds)
	boss.shark.breach({"x": float(d["x"]), "at": float(spot["at"]), "top": float(spot["y"]), "side": int(spot["side"]),
		"open_at": float(d["impact"]) - MechaGuppyShark.BREACH_EARLY, "step": step.index})
	await _run(world, 2.0, func() -> bool: return bombs.in_air() == 0, bot.step)
	var hits: Array[Dictionary] = _events(boss, &"shark_hit")
	check(hits.size() == 1 and bool(hits[0]["counted"]) and boss.hits_landed == 1 and int(bombs.stats["chasm"]) == 1,
		"a bomb thrown at the chasm as the shark rises there goes into its open jaws: a hit (%d)" % boss.hits_landed)
	if hits.size() == 1:
		check(float(hits[0]["y"]) > float(spot["y"]) + 2.0,
			"it goes in high in its mouth, where the runner sees it (%.1f m over the floor's level)" % [float(hits[0]["y"]) - float(spot["y"])])
		check(bombs.surface_at(int(spot["lane"]), float(spot["at"]), float(spot["y"])) == MechaGuppyBombs.Lands.CHASM,
			"where it fell there's no floor (the stretch the shark has eaten)")
	check(_sounds(boss, &"guppy_clang") == 1 and _sounds(boss, &"guppy_rumble") >= 1, "the hit clangs; the shark rumbled up first")
	await sim.free_world(world)


# --- The fight ------------------------------------------------------------------------------------

## The real fight through phases 1 and 2 with the bot (see the header).
func _test_fight(lanes: int, speed: float) -> void:
	var tag: String = "(%d lanes, %.1f m/s)" % [lanes, speed]
	var pair: Array = _fight(lanes, speed)
	var world: RunWorld = pair[0]
	var boss: MechaGuppy = pair[1]
	var p: Player = world.player
	var bombs: MechaGuppyBombs = boss.bombs
	var mt: MechaGuppyTuning = boss.tuning
	var bot := MechaGuppyBot.new(boss)
	bot.reaction = REACTION
	var cause: Array[String] = [""]
	p.died.connect(func(c: String) -> void: cause[0] = c)
	var hurt: Array[int] = [0]
	p.item_used.connect(func(_item: StringName) -> void: hurt[0] += 1)
	# Every bomb seen, with what was wrong with its warning.
	var seen: Array[Dictionary] = []
	var problems: Array[String] = []
	var shown: Array[int] = [0, 0]
	await _run(world, 150.0, func() -> bool: return boss.phase_index >= 2, func() -> void:
		bot.step()
		for d: Dictionary in bombs.drops():
			if not d.has("_seen"):
				d["_seen"] = bombs.clock
				seen.append(d)
			if bool(d["landed"]):
				continue
			var circle: MeshInstance3D = d["circle"]
			if int(d["kind"]) == MechaGuppyBombs.Kind.HUT:
				if circle != null:
					problems.append("a bomb on a hut shows a circle")
				continue
			if circle == null or not is_instance_valid(circle) or not circle.visible:
				problems.append("a bomb at %.0f m has no circle before it lands" % float(d["at"]))
				continue
			shown[0] += 1
			if absf(circle.global_position.y - float(d["y"])) > 0.25:
				problems.append("a circle at %.2f m for a floor at %.2f m" % [circle.global_position.y, float(d["y"])])
			var m := circle.material_override as BaseMaterial3D
			if m == null or not m.disable_fog:
				problems.append("a circle in the fog")
			if absf(circle.global_position.z - TrackGeometry.world_z(float(d["at"]))) > 0.3 \
					or absf(circle.global_position.x - float(d["x"])) > 0.3:
				problems.append("a circle away from where its bomb lands")
			shown[1] += 1)
	check(p.alive and boss.phase_index >= 2, "the runner makes it through phases 1 and 2 %s%s" % [tag,
		"" if p.alive else ": %s at %.0f m" % [cause[0], p.distance]])
	check(hurt[0] == 0, "the clean runner is never hurt %s" % tag)
	var spot_bombs: int = 0
	var short_warning: Array[float] = []
	for d: Dictionary in seen:
		if not bool(d["landed"]) and bool(d.get("released", false)) == false:
			continue
		if not bool(d["whistled"]) or not bool(d["released"]):
			problems.append("a bomb at %.0f m landed without its whistle" % float(d["at"]))
		if int(d["kind"]) == MechaGuppyBombs.Kind.SPOT:
			spot_bombs += 1
			var warned: float = float(d["impact"]) - float(d["_seen"])
			if warned < mt.lock_seconds - 0.02:
				short_warning.append(warned)
	check(problems.is_empty() and shown[1] > 0, "every bomb that can land where a runner can be shows its red circle where it lands, at that floor's height, out of the fog, until it lands, and whistles before it lands; a bomb on a hut has none (%d bombs) %s%s"
		% [seen.size(), tag, "" if problems.is_empty() else ": " + "; ".join(problems.slice(0, 3))])
	check(spot_bombs > 0 and short_warning.is_empty(), "every spot's circle shows at least lock_seconds (%.2f s) before it lands (%d bombs) %s%s"
		% [mt.lock_seconds, spot_bombs, tag, "" if short_warning.is_empty() else ": %s" % str(short_warning)])
	var throws: int = _events(boss, &"volley").size() + _events(boss, &"throw").size()
	check(_sounds(boss, &"cogs_throw") == throws and throws > 0, "every throw is heard (%d) %s" % [throws, tag])
	# The hits: each a bomb into the shark's jaws over the chasm.
	var hits: Array[Dictionary] = _events(boss, &"hit")
	var into: Array[Dictionary] = _events(boss, &"shark_hit")
	var ok: bool = hits.size() == 10 and into.size() == 10
	for h: Dictionary in hits:
		ok = ok and h["cause"] == &"bomb"
	for e: Dictionary in into:
		ok = ok and int(e["kind"]) == MechaGuppyBombs.Kind.HIT and bool(e["counted"]) \
			and bombs.surface_at(int(e["lane"]), float(e["at"]), float(e["floor"])) == MechaGuppyBombs.Lands.CHASM
	check(ok and int(bombs.stats["chasm"]) == 0, "every hit is a bomb into the shark's jaws over the chasm, none missing it (%d hits, %d into the jaws) %s"
		% [hits.size(), into.size(), tag])
	var ends: Array[Dictionary] = _events(boss, &"phase_end")
	var per_phase: Array[int] = [0, 0]
	for e: Dictionary in hits:
		if int(e["phase"]) < 2:
			per_phase[int(e["phase"])] += 1
	check(ends.size() >= 2 and per_phase[0] == 4 and per_phase[1] == 6, "4 hits end phase 1, 6 phase 2 (%s) %s" % [str(per_phase), tag])
	# More bombs a step in phase 2: every bomb thrown, by phase, over the steps (one hit a step).
	var thrown: Array[int] = [0, 0]
	for e: Dictionary in boss.events:
		var ph: int = int(e.get("phase", 0))
		if ph > 1:
			continue
		if e["event"] == &"throw":
			thrown[ph] += 1
		elif e["event"] == &"volley":
			for s: Dictionary in e["spots"]:
				thrown[ph] += (s["lanes"] as Array).size()
	var a: float = float(thrown[0]) / 4.0
	var b: float = float(thrown[1]) / 6.0
	check(b > a, "phase 2 throws more bombs a step than phase 1 (%.2f against %.2f) %s" % [b, a, tag])
	print("  Captain Cogs' bombs %s: phase 1 ends at %s s, phase 2 at %s s; %d bombs (%.2f a step in phase 1, %.2f in phase 2), %d on huts, %d into the shark"
		% [tag, "%.1f" % float(ends[0]["t"]) if ends.size() > 0 else "-", "%.1f" % float(ends[1]["t"]) if ends.size() > 1 else "-",
			int(bombs.stats["thrown"]), a, b, int(bombs.stats["hut"]), int(bombs.stats["hit"])])
	await sim.free_world(world)


# --- No escalation, a retry -----------------------------------------------------------------------

## With no hit ever landing, phase 1 goes on step after step with the same bombs a step: the same number of spots and
## bombs, the spots at the same places from where the runner can first dodge them (GDD §10: no time limit, no
## escalation).
func _test_no_escalation() -> void:
	var pair: Array = _fight(3, 23.8)
	var world: RunWorld = pair[0]
	var boss: MechaGuppy = pair[1]
	var p: Player = world.player
	boss.pattern.hits_enabled = false
	var bot := MechaGuppyBot.new(boss)
	bot.reaction = REACTION
	await _run(world, 90.0, func() -> bool: return bot.steps_climbed >= 9, bot.step)
	check(p.alive and bot.steps_climbed >= 9 and boss.phase_index == 0 and boss.hits_landed == 0,
		"with no hit landing, phase 1 goes on (%d steps climbed, phase %d)" % [bot.steps_climbed, boss.phase_index + 1])
	# Each step's volley: its spots' places past where they can first be dodged, and its bombs, by the step's cue (the
	# two cues' roofs alternate, each with room for its own number of spots).
	var shapes: Array[Dictionary] = [{}, {}]
	var volleys: int = 0
	var same: bool = true
	for e: Dictionary in _events(boss, &"volley"):
		var cue: int = boss.climb.steps[int(e["step"])].cue
		var s_open: float = float(e["s_open"])
		var parts: PackedStringArray = []
		for s: Dictionary in e["spots"]:
			parts.append("%.2f:%d" % [float(s["at"]) - s_open, (s["lanes"] as Array).size()])
		var shape: String = ",".join(parts)
		volleys += 1
		var first: Dictionary = shapes[cue]
		if first.is_empty():
			first["shape"] = shape
		same = same and first["shape"] == shape
	check(same and volleys >= 7, "every step's volley is the same as the last with its cue: the same spots at the same places past where they can first be dodged, the same bombs (%d volleys: %s)"
		% [volleys, str(shapes)])
	check(_events(boss, &"breach_warning").is_empty() and _events(boss, &"hit").is_empty(),
		"and no hit: the shark doesn't rise for one")
	await sim.free_world(world)


## Two attempts with the same inputs: the same bombs at the same places and times.
func _test_retry() -> void:
	var runs: Array[String] = []
	for attempt: int in 2:
		var pair: Array = _fight(5, 18.0)
		var world: RunWorld = pair[0]
		var boss: MechaGuppy = pair[1]
		var bot := MechaGuppyBot.new(boss)
		bot.reaction = REACTION
		await _run(world, 40.0, func() -> bool: return boss.hits_landed >= 3, bot.step)
		var log: PackedStringArray = []
		for e: Dictionary in boss.events:
			if e["event"] in [&"volley", &"throw", &"blast", &"shark_hit", &"hit", &"bite", &"roof_eaten"]:
				log.append("%.3f %s" % [float(e["t"]), str(e)])
		runs.append("\n".join(log))
		await sim.free_world(world)
	check(runs[0] == runs[1] and runs[0].length() > 0, "every attempt plays out the same way (the same bombs, bites and hits)")

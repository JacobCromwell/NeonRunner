extends TestSuite
## The Floating Head's face-off (GDD §10; task E1b), after its bombing run and reveal
## (test_floating_head.gd):
## - its data: the attacks' sounds (the warnings the same every time), every phase's attack list, the
##   cyborgs per drop, the sweeps' heights against the runner's jump and slide, and the pinned height
##   against E1c's ways onto its head;
## - the marked towers: nothing on them glows in a hazard colour, and the track stays clear around
##   them;
## - the eye lasers at 3, 5 and 6 lanes: every attack warns first (the eyes glow red and whine through
##   the whole charge while the aiming beams show where it goes; a drag's lane gets the red lane
##   warning; no laser hitbox is live before it fires; every warning lasts the same); a runner who
##   reads the warnings (FloatingHeadBot, no god mode) escapes every one; one who stands still is hit
##   by each kind, and so is a wrong answer (a slide under a low sweep, a jump at a high one);
## - the lasers' damage rules (an enemy attack), and the burning line keeps clear of a wall runner;
## - the cyborg drop: the mouth opens with its sound and red circles mark where they land; 1 cyborg in
##   the first phase and 2 later, the director's normal cyborgs, each in its own lane leaving one
##   free, holding their fire until they land; its lasers wait while they're ahead, and no burst
##   overlaps a laser attack;
## - the towers: a bait clips the tower (its bonus), which topples onto the ship and pins it low and
##   still across the trucks (weak points and top off until task E1c); the fallback clips one on its
##   own after fallback_after misses (no bonus); it shakes free before the runner reaches it (E1b's
##   placeholder) and the face-off goes on;
## - its real arena at 3, 5 and 6 lanes: every attack keeps the fairness rules (rechecked from the
##   layout), and every attempt plays out the same way.

const BOSS_PATH: String = "res://data/bosses/city_boss.tres"
const LANES: Array[int] = [3, 5, 6]
const SOUNDS: Array[StringName] = [&"head_laser_charge", &"head_laser_fire", &"head_mouth_open",
	&"cyborg_drop_land", &"tower_crack", &"tower_crash"]
const WARNINGS: Array[StringName] = [&"head_laser_charge", &"head_mouth_open", &"tower_crack"]

var sim: RunSim
var def: BossDef


func run() -> void:
	sim = RunSim.new(tree, tuning)
	def = (load(BOSS_PATH) as BossDef).preview()
	check(def != null, "the Floating Head's fight exists")
	if def == null:
		return
	_test_data()
	_test_towers()
	await _test_lasers()
	await _test_standing_still()
	await _test_wrong_answers()
	await _test_laser_rules()
	await _test_drop()
	await _test_bait()
	await _test_fallback()
	await _test_real_arena()
	await _test_same_every_attempt()


# --- Helpers -------------------------------------------------------------------------------

## The fight for a test: straight into the face-off (no bombing runs), `pattern` as every phase's
## attack list if given, the marked towers on (every `spacing` metres from 160 m, or where the data
## puts them with 0) or off, on a plain street (floor and walls) or its real arena.
func _def(pattern: String, towers: bool, plain: bool, spacing: float = 0.0) -> BossDef:
	var out: BossDef = def.duplicate() as BossDef
	var t := (def.tuning as FloatingHeadTuning).duplicate() as FloatingHeadTuning
	t.first_run_seconds = 0.0
	t.later_runs = 0
	if pattern != "":
		t.faceoff_patterns = PackedStringArray([pattern])
	if not towers:
		t.tower_first = 100000.0
	elif spacing > 0.0:
		t.tower_first = 160.0
		t.tower_spacing = spacing
	out.tuning = t
	if plain:
		out.arena = null
	return out


## A fight against `p_def` in a bare world at `lanes`: [world, head].
func _fight(p_def: BossDef, lanes: int, resume: Dictionary = {}) -> Array:
	var head := BossEncounter.create(p_def) as FloatingHead
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = p_def
	ctx.config = BossArena.base_config(p_def)
	ctx.config.lane_count = lanes
	ctx.tuning = tuning
	ctx.boss_resume = resume
	var arena: BossArena = head.plan_arena(ctx)
	var world: RunWorld = sim.build_world(arena.layout, null, tuning, ctx.config)
	head.setup(world, ctx, arena)
	return [world, head]


## Steps the world until `condition` holds or `seconds` pass. True if it held.
func _until(world: RunWorld, condition: Callable, seconds: float) -> bool:
	if not world.player.running:
		await tree.physics_frame
		world.player.running = true
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		if condition.call():
			return true
		await tree.physics_frame
	return condition.call()


func _events(head: BossEncounter, event: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in head.events:
		if e["event"] == event:
			out.append(e)
	return out


func _sounds(head: BossEncounter, sound: StringName) -> int:
	var n: int = 0
	for e: Dictionary in _events(head, &"sound"):
		if e["name"] == sound:
			n += 1
	return n


## The runner's cause of death once it happens: [cause].
func _watch_death(world: RunWorld) -> Array[String]:
	var cause: Array[String] = [""]
	world.player.died.connect(func(c: String) -> void: cause[0] = c)
	return cause


## True if the runner's hurtbox touches a live laser hitbox now (the same query the player makes).
func _touching_laser(head: FloatingHead) -> bool:
	var hazards: Array[Hazard] = head.faceoff.laser_hazards()
	if hazards.is_empty():
		return false
	var body: AABB = head.world.player.hurtbox_aabb()
	var shape := BoxShape3D.new()
	shape.size = body.size
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, body.get_center())
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = TrackBuilder.LAYER_HAZARD
	for hit: Dictionary in head.world.get_world_3d().direct_space_state.intersect_shape(query, 16):
		if hazards.has(hit["collider"]):
			return true
	return false


## True if a lane's floor is free of holes and fences between two track distances (the layout itself,
## checked here without the boss's code).
func _floor_clear(layout: LevelLayout, lane: int, from: float, to: float) -> bool:
	for g: Dictionary in layout.gaps:
		if int(g["lane"]) == lane and float(g["start"]) <= to and float(g["end"]) >= from:
			return false
	for f: Dictionary in layout.fences:
		if int(f["lane"]) == lane and not f.get("disabled", false) and float(f["at"]) >= from and float(f["at"]) <= to:
			return false
	return true


func _all_clear(layout: LevelLayout, lanes: int, from: float, to: float) -> bool:
	for l: int in lanes:
		if not _floor_clear(layout, l, from, to):
			return false
	return true


## The glowing vertex colours in a hazard colour (anything saturated outside the cold blues).
func _hazard_glows(mesh: ArrayMesh) -> PackedStringArray:
	var out: PackedStringArray = []
	for s: int in mesh.get_surface_count():
		var colors: PackedColorArray = mesh.surface_get_arrays(s)[Mesh.ARRAY_COLOR]
		for c: Color in colors:
			if c.a > 0.0 and c.s > 0.3 and (c.h < 0.55 or c.h > 0.8) and out.size() < 3:
				out.append(str(c))
	return out


# --- Data ----------------------------------------------------------------------------------------

func _test_data() -> void:
	var t := def.tuning as FloatingHeadTuning
	var sfx := load("res://data/audio/sfx_library.tres") as SfxLibrary
	for sound: StringName in SOUNDS:
		check(sfx.names().has(String(sound)) and sfx.stream(sound) != null, "its sound %s exists" % sound)
	for warning: StringName in WARNINGS:
		check(float(sfx.pitch_variation.get(String(warning), 0.0)) == 0.0, "warning %s sounds the same every time" % warning)
	var whine: float = sfx.stream(&"head_laser_charge").get_length()
	check(whine >= 0.5 and whine <= t.laser_charge_seconds + 0.01, "the eyes' whine fits their warning (%.2f s)" % whine)
	# Every phase shows every attack; its lists are data.
	for phase: int in def.phase_count():
		var list: PackedStringArray = t.faceoff_pattern(phase)
		var every: bool = true
		for kind: String in ["low", "high", "drag", "drop"]:
			every = every and list.has(kind)
		check(every, "phase %d's face-off has every attack (%s)" % [phase + 1, ",".join(list)])
	var odd := FloatingHeadTuning.new()
	odd.faceoff_patterns = PackedStringArray(["nonsense, low ,drop"])
	check(odd.faceoff_pattern(0) == PackedStringArray(["low", "drop"]) and odd.faceoff_pattern(5) == PackedStringArray(["low", "drop"]),
		"a list keeps only known attacks, and later phases use the last list")
	# GDD §10: 1-2 cyborgs per drop, more in the next phase.
	check(t.cyborgs_in_drop(0) == 1 and t.cyborgs_in_drop(1) == 2 and t.cyborgs_in_drop(2) == 2,
		"1 cyborg per drop in the first phase, 2 in the later ones (GDD §10: 1-2, more cyborgs)")
	# The sweeps against the runner's moves: jump a low one, slide under a high one (a gapped fence's
	# shape: no jump clears it).
	var r: float = t.beam_radius
	var standing: float = tuning.hurtbox_size.y
	var sliding: float = tuning.hurtbox_slide_height
	check(t.sweep_low_height - r < sliding and t.sweep_low_height + r < tuning.jump_height,
		"a low sweep hits a standing or sliding runner, and a jump clears it")
	check(t.sweep_high_height - r < standing and t.sweep_high_height - r > sliding,
		"a high sweep's lower beam hits a standing runner, and a sliding one passes under it")
	check(t.sweep_high_top + r > tuning.jump_height and (t.sweep_high_top - r) - (t.sweep_high_height + r) < standing,
		"no jump clears a high sweep: its upper beam is out of reach and there's no room between them")
	# Pinned, it's low enough for E1c's ways onto its head.
	var wall_jump_peak: float = tuning.wall_entry_height + pow(tuning.wall_jump_velocity, 2.0) / (2.0 * tuning.gravity())
	check(t.pin_top_height < wall_jump_peak and t.pin_top_height < tuning.ceiling_height - 1.5,
		"pinned, its weak points' tops (%.2f m) are within a wall jump's reach (%.2f m) and well under a ceiling (%.1f m)" % [
		t.pin_top_height, wall_jump_peak, tuning.ceiling_height])


# --- The towers ------------------------------------------------------------------------------------

## GDD §10's "marked, cracked towers": white paint and cold lights, nothing in a hazard colour (the
## laser's cut glows red-hot, the attack's own colour, on its own material); the track clear of holes
## and fences around each, on the real arena at every lane count.
func _test_towers() -> void:
	var t := def.tuning as FloatingHeadTuning
	var loud: PackedStringArray = _hazard_glows(FloatingHeadTower.tower_mesh(t.tower_width, t.tower_height))
	check(loud.is_empty(), "nothing on a marked tower glows in a hazard colour: %s" % ", ".join(loud))
	for lanes: int in LANES:
		var config: LevelConfig = BossArena.base_config(def)
		config.lane_count = lanes
		var head := BossEncounter.create(def) as FloatingHead
		head.def = def
		var arena: BossArena = BossArena.plan(def, config, tuning, head)
		head.arena = arena
		var towers: Array[Dictionary] = head.towers_between(0.0, arena.lap_length * arena.laps.size() - 1.0)
		var blocked: int = 0
		var sides: Dictionary = {}
		for tower: Dictionary in towers:
			var k: int = arena.lap_at(float(tower["at"]))
			var at: float = float(tower["at"]) - k * arena.lap_length
			sides[int(tower["side"])] = true
			if not _all_clear(arena.laps[k], lanes, at - t.tower_clear_before, at + t.tower_clear_after):
				blocked += 1
		check(towers.size() >= 2 * arena.laps.size() and sides.size() == 2,
			"marked towers stand along its arena on both sides (%d, %d lanes)" % [towers.size(), lanes])
		check(blocked == 0, "the track is clear of holes and fences around every tower (%d lanes)" % lanes)
		head.free()


# --- The eye lasers --------------------------------------------------------------------------------

## On a plain street at every lane count: every laser attack warns first, and a runner who reads the
## warnings (no god mode) escapes every one: jumps the low sweeps, slides under the high ones and
## switches lanes out of the drags.
func _test_lasers() -> void:
	for lanes: int in LANES:
		var pair: Array = _fight(_def("low,high,drag", false, true), lanes)
		var world: RunWorld = pair[0]
		var head: FloatingHead = pair[1]
		var f: FloatingHeadFaceOff = head.faceoff
		var tag: String = "(%d lanes)" % lanes
		var bot := FloatingHeadBot.new(head)
		var cause: Array[String] = _watch_death(world)
		var s: Dictionary = {"unaimed": 0, "early": 0, "dim": 0, "unwarned": 0, "was": -1}
		var done: bool = await _until(world, func() -> bool:
			bot.step()
			if f.step == FloatingHeadFaceOff.Step.CHARGE and f.step_time > 0.0:
				if not f.aiming():
					s["unaimed"] += 1
				if not f.laser_hazards().is_empty():
					s["early"] += 1
			if f.step == FloatingHeadFaceOff.Step.FIRE and s["was"] != FloatingHeadFaceOff.Step.FIRE:
				if head.body.eye_charge < 0.95:
					s["dim"] += 1
				if f.attack.has("lane") and not head.props.warned(int(f.attack["lane"]), world.player.distance,
						float(f.attack["start"])):
					s["unwarned"] += 1
			s["was"] = f.step
			return _events(head, &"laser_end").size() >= 7 or not world.player.alive, 50.0)
		check(done and world.player.alive, "a runner who reads the warnings escapes every laser, no god mode (%s) %s" % [
			cause[0], tag])
		var charges: Array[Dictionary] = _events(head, &"laser_charge")
		var fires: Array[Dictionary] = _events(head, &"laser_fire")
		var kinds: Dictionary = {}
		for e: Dictionary in fires:
			kinds[e["kind"]] = int(kinds.get(e["kind"], 0)) + 1
		check(int(kinds.get(&"low", 0)) >= 2 and int(kinds.get(&"high", 0)) >= 2 and int(kinds.get(&"drag", 0)) >= 2,
			"it sweeps low, sweeps high and drags, in turn (%s) %s" % [kinds, tag])
		check(_events(head, &"laser_cancel").is_empty() and _events(head, &"attack_skipped").is_empty(),
			"on a clear street every attack goes ahead %s" % tag)
		# Every shot comes a whole warning after the eyes start to glow: the same every time.
		var expected: float = head.tuning.laser_charge_seconds / head.phase().pace
		var on_time: bool = not fires.is_empty() and fires.size() == charges.size()
		for i: int in mini(fires.size(), charges.size()):
			var wait: float = float(fires[i]["t"]) - float(charges[i]["t"])
			on_time = on_time and absf(wait - expected) < 0.03 and fires[i]["kind"] == charges[i]["kind"]
		check(on_time, "every shot comes a whole warning (%.2f s) after the eyes start to glow %s" % [expected, tag])
		check(_sounds(head, &"head_laser_charge") == charges.size() and _sounds(head, &"head_laser_fire") == fires.size(),
			"every warning whines and every shot is heard %s" % tag)
		check(s["unaimed"] == 0, "the aiming beams show where it goes through every warning %s" % tag)
		check(s["early"] == 0, "no laser hitbox is live while it warns %s" % tag)
		check(s["dim"] == 0, "its eyes glow fully red before every shot %s" % tag)
		check(s["unwarned"] == 0, "every drag's lane shows the red lane warning as it fires %s" % tag)
		var jumps: int = 0
		var slides: int = 0
		for a: Dictionary in bot.log:
			jumps += 1 if a["action"] == &"jump" and a["why"] == "low" else 0
			slides += 1 if a["action"] == &"slide" and a["why"] == "high" else 0
		check(jumps == int(kinds.get(&"low", 0)) and slides == int(kinds.get(&"high", 0)),
			"it jumped every low sweep and slid under every high one %s" % tag)
		await sim.free_world(world)


## A runner who stands still is hit by each kind of laser.
func _test_standing_still() -> void:
	for case: Array in [[&"low", 3], [&"high", 5], [&"drag", 6]]:
		var kind: StringName = case[0]
		var lanes: int = case[1]
		var pair: Array = _fight(_def(String(kind), false, true), lanes)
		var world: RunWorld = pair[0]
		var head: FloatingHead = pair[1]
		var cause: Array[String] = _watch_death(world)
		await _until(world, func() -> bool: return not world.player.alive, 15.0)
		var expected: String = FloatingHeadFaceOff.BURN_NAME if kind == &"drag" else FloatingHeadFaceOff.LASER_NAME
		check(not world.player.alive and cause[0] == expected and _events(head, &"laser_fire").size() == 1,
			"a runner who stands still is hit by its first %s (%s, %d lanes)" % [kind, cause[0], lanes])
		await sim.free_world(world)


## The answer matters: a slide under a low sweep is hit, and so is a jump at a high one.
func _test_wrong_answers() -> void:
	for kind: StringName in [&"low", &"high"]:
		var pair: Array = _fight(_def(String(kind), false, true), 5)
		var world: RunWorld = pair[0]
		var head: FloatingHead = pair[1]
		var bot := FloatingHeadBot.new(head)
		bot.wrong = kind
		var cause: Array[String] = _watch_death(world)
		await _until(world, func() -> bool:
			bot.step()
			return not world.player.alive, 15.0)
		var pressed: bool = not bot.log.is_empty() and bot.log[0]["action"] == (&"slide" if kind == &"low" else &"jump")
		check(pressed and not world.player.alive and cause[0] == FloatingHeadFaceOff.LASER_NAME,
			"%s is hit (%s)" % ["a slide under a low sweep" if kind == &"low" else "a jump at a high sweep", cause[0]])
		await sim.free_world(world)


## The shared damage rules on a live laser (an enemy attack: armor and the shield block it, the dash
## passes through it, claws don't help), and a drag's burning line keeps clear of a wall runner beside
## an outer lane while still covering a runner in it.
func _test_laser_rules() -> void:
	var pair: Array = _fight(_def("low", false, true), 3)
	var world: RunWorld = pair[0]
	var head: FloatingHead = pair[1]
	world.player.god_mode = true
	await _until(world, func() -> bool: return not head.faceoff.laser_hazards().is_empty(), 15.0)
	var hazards: Array[Hazard] = head.faceoff.laser_hazards()
	check(hazards.size() == 2, "a sweep has a hitbox along each beam")
	if not hazards.is_empty():
		var h: Hazard = hazards[0]
		var d := DamageRules.Defense.new()
		check(h.is_enemy_attack and DamageRules.resolve(h, d) == DamageRules.Outcome.KILL, "a laser kills an unprotected runner")
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
	await sim.free_world(world)
	for setup: Vector2i in [Vector2i(3, -1), Vector2i(6, 1)]:
		var lanes: int = setup.x
		var side: int = setup.y
		pair = _fight(_def("drag", false, true), lanes)
		world = pair[0]
		head = pair[1]
		world.player.god_mode = true
		var outer: int = 0 if side < 0 else lanes - 1
		var s: Dictionary = {"reach": 0.0, "covers": false}
		await _until(world, func() -> bool:
			if world.player.lane != outer and world.player.surface == Player.Surface.FLOOR:
				world.player.press(&"move_left" if side < 0 else &"move_right")
			for h: Hazard in head.faceoff.laser_hazards():
				if h.hazard_name != FloatingHeadFaceOff.BURN_NAME:
					continue
				s["reach"] = maxf(float(s["reach"]), absf(h.global_position.x) + h.size.x * 0.5)
				var lx: float = world.geo.lane_x(outer)
				s["covers"] = h.global_position.x - h.size.x * 0.5 <= lx - tuning.hurtbox_size.x * 0.5 \
					and h.global_position.x + h.size.x * 0.5 >= lx + tuning.hurtbox_size.x * 0.5
			return _events(head, &"laser_end").size() >= 1 and head.faceoff.laser_hazards().is_empty(), 15.0)
		var wall_body: float = world.geo.wall_x() - tuning.hurtbox_size.y
		check(float(s["reach"]) > 0.0 and float(s["reach"]) < wall_body,
			"a burning line in the outer lane keeps clear of a wall runner beside it (%.2f m of %.2f, %d lanes)" % [
			s["reach"], wall_body, lanes])
		check(s["covers"], "and still covers a runner in that lane (%d lanes)" % lanes)
		await sim.free_world(world)


# --- The cyborg drop -------------------------------------------------------------------------------

## GDD §10: "its mouth opens and drops 1–2 cyborgs onto the trucks ahead, who then fight like normal
## cyborgs". In the first phase (5 lanes) and a later one (3 lanes: two cyborgs, one lane free).
func _test_drop() -> void:
	for phase: int in [0, 1]:
		var lanes: int = 5 if phase == 0 else 3
		var pair: Array = _fight(_def("drop,low", false, true), lanes, {"phase": phase} if phase > 0 else {})
		var world: RunWorld = pair[0]
		var head: FloatingHead = pair[1]
		var f: FloatingHeadFaceOff = head.faceoff
		var t: FloatingHeadTuning = head.tuning
		var tag: String = "(phase %d, %d lanes)" % [phase + 1, lanes]
		# God mode: a panicking cyborg's wild bolts aren't this test's business.
		world.player.god_mode = true
		var bot := FloatingHeadBot.new(head)
		var s: Dictionary = {"jaw": 0.0, "marked": 0, "unmarked_after": 0, "armed_falling": 0, "unarmed": 0,
			"not_normal": 0, "fought": false, "overlap": 0, "early_laser": 0, "closed_at": -1.0, "was_drop": false,
			"was": -1, "seen": {}, "landed": {}}
		await _until(world, func() -> bool:
			bot.step()
			var dropping: bool = f.attack.get("kind", &"") == &"drop"
			if dropping and int(f.attack.get("dropped", 0)) == 0:
				s["jaw"] = maxf(float(s["jaw"]), head.body.jaw_open)
			if dropping and f.step == FloatingHeadFaceOff.Step.MOUTH and f.step_time <= 0.0:
				for spot: Dictionary in f.attack["spots"]:
					if head.props.warned(int(spot["lane"]), float(spot["at"]) - 0.5, float(spot["at"]) + 0.5):
						s["marked"] += 1
			if dropping and f.step == FloatingHeadFaceOff.Step.CLOSING and f.step_time <= 0.0:
				for spot: Dictionary in f.attack["spots"]:
					if head.props.warned(int(spot["lane"]), float(spot["at"]) - 0.5, float(spot["at"]) + 0.5):
						s["unmarked_after"] += 1
			if s["was_drop"] and not dropping:
				s["closed_at"] = head.fight_time()
			s["was_drop"] = dropping
			var falling: Array[Enemy] = f.falling()
			for e: Enemy in f.dropped():
				var c := e as Cyborg
				if not s["seen"].has(e.get_instance_id()):
					s["seen"][e.get_instance_id()] = true
					if c == null or not world.director.active.has(e) or String(e.spawn.get("type", "")) != "cyborg":
						s["not_normal"] += 1
				if c == null:
					continue
				if falling.has(e) and c.gun.enabled:
					s["armed_falling"] += 1
				if not falling.has(e) and not s["landed"].has(e.get_instance_id()):
					s["landed"][e.get_instance_id()] = true
					if not c.gun.enabled:
						s["unarmed"] += 1
				var bursting: bool = c.gun.state == CyborgGun.State.CHARGING or c.gun.state == CyborgGun.State.FIRING
				s["fought"] = s["fought"] or bursting
				if bursting and f.lasering():
					s["overlap"] += 1
			# A laser attack starting: no cyborg it dropped ahead of the runner, unless it waited its most.
			if f.step == FloatingHeadFaceOff.Step.CHARGE and s["was"] != FloatingHeadFaceOff.Step.CHARGE:
				var ahead: bool = false
				for e: Enemy in f.dropped():
					ahead = ahead or e.track_distance() > world.player.distance + 0.5
				if ahead and head.fight_time() - float(s["closed_at"]) < t.drop_hold_max - 0.05:
					s["early_laser"] += 1
			s["was"] = f.step
			return _events(head, &"laser_end").size() >= 1, 30.0)
		var count: int = t.cyborgs_in_drop(phase)
		var warns: Array[Dictionary] = _events(head, &"drop_warn")
		var drops: Array[Dictionary] = _events(head, &"cyborg_drop")
		var lands: Array[Dictionary] = _events(head, &"cyborg_land")
		check(warns.size() == 1 and (warns[0]["lanes"] as Array).size() == count and drops.size() == count and lands.size() == count,
			"its mouth drops %d cyborg(s), and they land %s" % [count, tag])
		if warns.is_empty() or drops.is_empty():
			await sim.free_world(world)
			continue
		var wait: float = float(drops[0]["t"]) - float(warns[0]["t"])
		check(_sounds(head, &"head_mouth_open") == 1 and wait >= t.mouth_seconds / head.phase().pace - 0.02,
			"the warning first: its mouth opens with its grinding sound %.2f s before the first drops %s" % [wait, tag])
		check(float(s["jaw"]) >= 0.99, "its jaw is wide open before the first drops %s" % tag)
		check(int(s["marked"]) == count and int(s["unmarked_after"]) == 0,
			"red circles mark where they'll land until they land (pickups keep off them) %s" % tag)
		var used: Array = warns[0]["lanes"]
		var distinct: Dictionary = {}
		for l: int in used:
			distinct[l] = true
		check(distinct.size() == used.size() and used.size() < lanes, "each in its own lane, a lane left free %s" % tag)
		check(int(s["not_normal"]) == 0 and (s["seen"] as Dictionary).size() == count,
			"they're the director's normal cyborgs %s" % tag)
		check(int(s["armed_falling"]) == 0 and int(s["unarmed"]) == 0, "they hold their fire until they land %s" % tag)
		check(s["fought"], "then they fight like any cyborg (a charge-up) %s" % tag)
		check(_sounds(head, &"cyborg_drop_land") == lands.size(), "every landing is heard %s" % tag)
		check(int(s["overlap"]) == 0, "no cyborg's burst during a laser attack (big attacks take turns) %s" % tag)
		check(int(s["early_laser"]) == 0 and not _events(head, &"laser_charge").is_empty(),
			"its lasers wait while a cyborg it dropped is still ahead (%.1f s at most), then go on %s" % [t.drop_hold_max, tag])
		await sim.free_world(world)


# --- The towers and the pin --------------------------------------------------------------------------

## GDD §10: the player "baits the eye laser into a marked tower by leading the beam to that side and
## dodging at the last moment. The tower topples onto the ship and pins it low across the trucks."
func _test_bait() -> void:
	for lanes: int in [5, 3]:
		var pair: Array = _fight(_def("low,high,drag", true, true, 200.0), lanes)
		var world: RunWorld = pair[0]
		var head: FloatingHead = pair[1]
		var t: FloatingHeadTuning = head.tuning
		var tag: String = "(%d lanes)" % lanes
		var bot := FloatingHeadBot.new(head, true)
		var cause: Array[String] = _watch_death(world)
		var s: Dictionary = {"z": INF, "drift": 0.0, "top_lo": INF, "top_hi": -INF, "crown": 0.0, "live": 0, "fallen": false,
			"touch": 0, "gap": INF}
		await _until(world, func() -> bool:
			bot.step()
			if _touching_laser(head):
				s["touch"] += 1
			if head.step == FloatingHead.Step.PINNED:
				var z: float = head.body.global_position.z
				if s["z"] == INF:
					s["z"] = z
					s["fallen"] = head.pinned_tower != null and head.pinned_tower.state == FloatingHeadTower.State.FALLEN
				s["drift"] = maxf(float(s["drift"]), absf(z - float(s["z"])))
				for h: Hazard in head.body.weak_points:
					var top: float = (h.global_transform * Vector3(0.0, -0.3, 0.0)).y
					s["top_lo"] = minf(float(s["top_lo"]), top)
					s["top_hi"] = maxf(float(s["top_hi"]), top)
				s["crown"] = head.body.top_height()
				if head.body.weak_points_enabled() or head.body.top_solid():
					s["live"] += 1
				s["gap"] = minf(float(s["gap"]), head.pose.z)
			var released: Array[Dictionary] = _events(head, &"released")
			return not world.player.alive or (not released.is_empty() and _events(head, &"laser_charge").any(
				func(e: Dictionary) -> bool: return float(e["t"]) > float(released[0]["t"]))), 60.0)
		var clips: Array[Dictionary] = _events(head, &"tower_clip")
		var baited: bool = clips.size() == 1 and bool(clips[0]["baited"]) \
			and int(clips[0]["lane"]) == (0 if int(clips[0]["side"]) < 0 else lanes - 1)
		check(baited and _events(head, &"tower_missed").is_empty(),
			"leading the beam to the marked tower's side baits it into the tower %s" % tag)
		check(int(world.score.bonuses.get(&"tower_bait", 0)) == t.bait_score, "a bait scores its bonus %s" % tag)
		check(_sounds(head, &"tower_crack") == 1 and _sounds(head, &"tower_crash") == 1 and _events(head, &"pinned").size() == 1,
			"the tower cracks, topples and crashes onto the ship %s" % tag)
		check(world.player.alive and int(s["touch"]) == 0,
			"the runner who baited it dodged the drag, no god mode (%s) %s" % [cause[0], tag])
		check(s["fallen"], "the tower lies across the ship %s" % tag)
		check(float(s["drift"]) < 0.01, "pinned, the ship lies still on the track (%.3f m) %s" % [s["drift"], tag])
		check(absf(float(s["top_hi"]) - t.pin_top_height) < 0.02 and float(s["top_lo"]) > t.pin_top_height - 1.0,
			"pinned low across the trucks: its weak points' tops %.2f-%.2f m up (%.2f m, rolled toward the tower) %s" % [
			s["top_lo"], s["top_hi"], t.pin_top_height, tag])
		print("  Floating Head pinned %s: weak points' tops %.2f-%.2f m, crown top %.2f m" % [tag, s["top_lo"], s["top_hi"], s["crown"]])
		check(int(s["live"]) == 0, "its weak points and its crown's top stay off (task E1c builds the stomps) %s" % tag)
		var release: Array[Dictionary] = _events(head, &"release")
		check(release.size() == 1 and float(release[0]["gap"]) >= t.pin_release_gap - 0.5 and float(s["gap"]) > 3.0,
			"it shakes free before the runner reaches it (E1b's placeholder) %s" % tag)
		check(head.step == FloatingHead.Step.FACE_OFF and head.faceoff.running, "then the face-off goes on %s" % tag)
		await sim.free_world(world)


## GDD §10: "if the player doesn't bait it, the laser eventually clips a tower on its own" (after
## fallback_after towers went by), with no bonus.
func _test_fallback() -> void:
	var pair: Array = _fight(_def("low,high,drag", true, true, 200.0), 3)
	var world: RunWorld = pair[0]
	var head: FloatingHead = pair[1]
	var t: FloatingHeadTuning = head.tuning
	var bot := FloatingHeadBot.new(head, false)
	var cause: Array[String] = _watch_death(world)
	await _until(world, func() -> bool:
		bot.step()
		return not world.player.alive or not _events(head, &"pinned").is_empty(), 80.0)
	var missed: Array[Dictionary] = _events(head, &"tower_missed")
	var clips: Array[Dictionary] = _events(head, &"tower_clip")
	var fell_back: bool = missed.size() == t.fallback_after and clips.size() == 1 and not bool(clips[0]["baited"])
	if fell_back and not missed.is_empty():
		fell_back = float(clips[0]["t"]) > float(missed[missed.size() - 1]["t"])
	check(fell_back, "a runner who doesn't bait it: %d towers go by, then the laser clips the next on its own" % t.fallback_after)
	check(int(world.score.bonuses.get(&"tower_bait", 0)) == 0, "the fallback scores no bonus (baiting scores more)")
	check(world.player.alive, "the runner dodged every drag on the way (%s)" % cause[0])
	check(not _events(head, &"pinned").is_empty(), "the tower pins the ship all the same")
	await sim.free_world(world)


# --- The real arena ------------------------------------------------------------------------------------

## The face-off on its real arena (the City's roofs, gaps and fences, its towers) at every lane count,
## with its real attack lists: every attack keeps the fairness rules, rechecked here from the layout.
func _test_real_arena() -> void:
	for lanes: int in LANES:
		var pair: Array = _fight(_def("", true, false), lanes)
		var world: RunWorld = pair[0]
		var head: FloatingHead = pair[1]
		var t: FloatingHeadTuning = head.tuning
		var tag: String = "(%d lanes)" % lanes
		# God mode: a panicking cyborg's wild bolts aren't this test's business.
		world.player.god_mode = true
		world.player.grapples = 1_000_000
		var bot := FloatingHeadBot.new(head, true)
		var touch: Array[int] = [0]
		await _until(world, func() -> bool:
			bot.step()
			if _touching_laser(head):
				touch[0] += 1
			return false, 60.0)
		var layout: LevelLayout = world.layout
		var v: float = world.player.speed
		var pace: float = head.phase().pace
		var fires: Array[Dictionary] = _events(head, &"laser_fire")
		var ends: Array[Dictionary] = _events(head, &"laser_end")
		var sweeps: int = 0
		var drags: int = 0
		var unfair: PackedStringArray = []
		for i: int in fires.size():
			var e: Dictionary = fires[i]
			var d0: float = float(e["d0"])
			if e["kind"] == &"low" or e["kind"] == &"high":
				sweeps += 1
				var d1: float = float(ends[i]["d"]) if i < ends.size() else d0
				if not _all_clear(layout, lanes, d0 - 5.0, d1 + t.sweep_clear_after - 1.0):
					unfair.append("sweep at %.0f" % d0)
			else:
				drags += 1
				var until: float = d0 + v * (t.drag_seconds + t.burn_seconds) / pace + t.escape_clear_after - 1.0
				var lane: int = int(e["lane"])
				var free: bool = false
				for dist: int in range(1, t.max_escape_lanes + 1):
					for side: int in [-1, 1]:
						var to: int = lane + side * dist
						if to < 0 or to >= lanes:
							continue
						var ok: bool = true
						for l: int in range(mini(lane, to), maxi(lane, to) + 1):
							ok = ok and (l == lane or _floor_clear(layout, l, d0, until))
						free = free or ok
				if not free:
					unfair.append("drag at %.0f" % d0)
		var margin: float = float(EnemyDirector.tuning_for("cyborg").get("obstacle_margin"))
		var lands: Array[Dictionary] = _events(head, &"cyborg_land")
		for e: Dictionary in lands:
			if not _all_clear(layout, lanes, float(e["at"]) - margin + 0.5, float(e["at"]) + margin - 0.5):
				unfair.append("cyborg at %.0f" % float(e["at"]))
		print("  Floating Head's face-off %s over 60 s: %d sweeps, %d drags, %d cyborgs, %d towers clipped, %d skipped" % [
			tag, sweeps, drags, lands.size(), _events(head, &"tower_clip").size(), _events(head, &"attack_skipped").size()])
		check(sweeps >= 3 and drags >= 3 and lands.size() >= 1, "it keeps attacking on the real arena: %d sweeps, %d drags, %d cyborgs %s" % [
			sweeps, drags, lands.size(), tag])
		check(unfair.is_empty(), "every attack keeps the fairness rules (%s) %s" % [", ".join(unfair), tag])
		check(touch[0] == 0, "the dodging runner never touches a laser %s" % tag)
		check(not _events(head, &"tower_clip").is_empty(), "the runner baits a tower %s" % tag)
		await sim.free_world(world)


## Two attempts with the same moves play out the same way.
func _test_same_every_attempt() -> void:
	var runs: Array[String] = []
	for attempt: int in 2:
		var pair: Array = _fight(_def("", true, false), 5)
		var world: RunWorld = pair[0]
		var head: FloatingHead = pair[1]
		world.player.god_mode = true
		world.player.grapples = 1_000_000
		var bot := FloatingHeadBot.new(head, true)
		await _until(world, func() -> bool:
			bot.step()
			return false, 45.0)
		var log: PackedStringArray = []
		for e: Dictionary in head.events:
			if e["event"] != &"sound":
				log.append("%s %.3f %s" % [e["event"], float(e["t"]), e])
		runs.append("\n".join(log))
		await sim.free_world(world)
	check(runs[0] == runs[1] and runs[0].length() > 0, "every attempt plays out the same way")

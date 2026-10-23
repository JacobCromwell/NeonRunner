extends TestSuite
## The Hunter (task S2; GDD §9.17, the owner, October 23, 2026), from its numbers and look to its placement:
## - Its numbers: the owner's (a chase about as long as the Enforcer Truck's, 25 laser hits), a warning that leaves a
##   reaction and a lane change before the cuts, cuts that reach a runner at any height of a jump but never one lane over,
##   a solid side over a whole jump, a hitbox a little smaller than its look; every number in the F6 panel.
## - Its look: a few draw calls; standard materials only (the Compatibility renderer); only its eyes, blades and jets
##   glow, its blades in the hazard red (brighter while it warns: a change of state, never a flicker); both blades raised
##   over its head for a warning, the arms chopping in turn through a flurry; beside the runner its whole look on screen in
##   the chase camera's view (at 3, 5 and 6 lanes, every lane and side, raised or not), hiding neither the runner nor the
##   floor of their lane and the lane they'd step into.
## - On real physics at the Ice Lab's speed (every take watched each frame: its body never meets the runner's, it never
##   sinks below the floor, its cuts only ever reach the lane it warned of, a whole warning after it):
##   - arrival: unseen and harmless until the runner reaches its spot, then its whine, from behind, up into a lane beside
##     them, its middle a little ahead of theirs, at 3, 5 and 6 lanes from the middle and from either edge;
##   - beside the runner: it follows into the lane they leave a moment later (follow_delay_seconds), keeping to its side;
##     a runner who changes lanes into it is bumped back unharmed (dashing too), and it unharmed;
##   - the flurry: every one warned (the scrape, its blades up, the red mark on the runner's lane) a whole warning before
##     its cuts, which reach only that lane; a runner who steps one lane away lives, one who stays or jumps is cut down;
##     armor or the shield absorbs a flurry, one hit for all of it; no flurry without a lane away from it to step into (a
##     runner by the edge, a hole in their other lane), and it hovers over holes in its own lane slashing as ever;
##   - the gantryway bait at 3, 5 and 6 lanes, both ways round: the runner dashes the pillar and steps out away from it,
##     it follows into the walkway's lane and the walkway lands on it (the runner's kill); and a whole encounter: its
##     flurry dodged into the walkway's lane, then the bait;
##   - weapons: 25 laser tier 1 shots (23 health, PowerupTuning.tier1_extra_shots), the other tiers in proportion; auto-fire
##     picks it, it shows a health bar; the claws, a stomp, the dash and other enemies' charges never defeat it;
##   - it steers round a doodad and a standing enemy in its lane, never into the runner's lane;
##   - a runner on a ceiling: a warning on as the pad lifts them is called off, and it waits below, never cutting;
##   - a teleport leaves it behind: it catches up, its time running on; one whose arrival a teleport skips never comes;
##   - it gives up chase_seconds after arriving, whatever it's doing, its whine falling, and leaves play;
##   - it never waits its turn nor holds anyone else's: a big attack of another enemy's on doesn't stop its flurries.
## - Placement (hunter_rules.gd) on Specimen Vault at 3, 5 and 6 lanes: at least one, after its feature's start, each with a
##   falling gantryway in its chase whose Hunter lane is clear, never two at once, each arriving calm (no other attack
##   planned there); the same every build; none where the level doesn't list it.
## - Its warning mark and Reduced flashing; its warm-up look (no physics object); its data (the hint, its sounds).

const HunterRules := preload("res://scripts/enemies/hunter_rules.gd")
const GantrywayRules := preload("res://scripts/enemies/gantryway_rules.gd")
const TeleporterRules := preload("res://scripts/enemies/teleporter_rules.gd")
const DUMMY: String = "res://tests/helpers/dummy_enemy.gd"
const TURN_DUMMY: String = "res://tests/helpers/turn_dummy.gd"
const CAMPAIGN_PATH: String = "res://data/campaign/campaign.tres"
const LANE_COUNTS: Array[int] = [3, 5, 6]
## The Ice Lab's run speed (data/zones/ice_lab.tres): where it appears.
const SPEED: float = 24.8
## Where the hand-built tracks' Hunter arrives (metres): past the level's calm start.
const ARRIVE: float = 70.0
## The reaction the suites give a runner to see something and start to act (test_gantryways' REACTION).
const REACTION: float = 0.35
## Seconds of physics a take may run to see the Hunter come up beside the runner.
const UP_SECONDS: float = 8.0

var sim: RunSim
var t: HunterTuning
var mt: MovementTuning
var pt: PowerupTuning


func run() -> void:
	sim = RunSim.new(tree, tuning)
	t = HunterRules.tuning()
	mt = tuning.duplicate() as MovementTuning
	mt.run_speed = SPEED
	pt = load("res://data/tuning/powerups.tres") as PowerupTuning
	_test_numbers()
	await _test_model()
	_test_view()
	await _test_arrival()
	await _test_follow()
	await _test_flurry()
	await _test_no_way_out()
	await _test_bait()
	await _test_encounter()
	await _test_weapons()
	await _test_contacts()
	await _test_steering()
	await _test_ceiling()
	await _test_teleport()
	await _test_give_up()
	await _test_turns()
	await _test_mark()
	_test_placement()
	await _test_warm_up()
	_test_data()


# --- Helpers -------------------------------------------------------------------------------------

## A plain track `lanes` wide with a Hunter arriving at ARRIVE (`params`: its entry's, e.g. its baits).
func _layout(lanes: int, params: Dictionary = {}, length: float = 1600.0) -> LevelLayout:
	var layout := RunSim.layout(lanes, length)
	layout.enemies.append({"type": "hunter", "at": ARRIVE, "lane": 0, "side": 0, "seed": 7, "params": params})
	return layout


## A world on `layout` at the Ice Lab's speed, the runner in `lane`, unprotected (no armor, no god mode).
func _world(layout: LevelLayout, lane: int, loadout: Loadout = null) -> RunWorld:
	var w: RunWorld = sim.build_world(layout, loadout if loadout != null else Loadout.new(), mt, LevelConfig.new())
	w.player.setup(w.tuning, w.geo, lane)
	w.player.armor_state.carried = false
	w.player.armor_state.hits = 0
	return w


func _hunter(w: RunWorld) -> Hunter:
	for e: Variant in w.director.active:
		if is_instance_valid(e) and e is Hunter:
			return e as Hunter
	return null


## Holds the Hunter's flurries off in `w` (its first never comes), for the takes about how it moves.
func _no_flurries(w: RunWorld) -> void:
	var hold := func(e: Enemy) -> void:
		if e is Hunter:
			var h := e as Hunter
			h.tuning = h.tuning.duplicate() as HunterTuning
			h.tuning.first_slash_seconds = 999.0
	for e: Variant in w.director.active:
		if is_instance_valid(e):
			hold.call(e)
	w.director.enemy_spawned.connect(hold)


## A falling gantryway as its rules hang one (test_gantryways' _layout): over `lane`, its pillar's front at `pillar`,
## pushing on `side`, nothing planted under it.
func _gantryway(layout: LevelLayout, lane: int, pillar: float, side: int) -> Dictionary:
	var config := LevelConfig.new()
	config.lane_count = layout.lane_count
	var gen: LevelGenerator = LevelGenerator.for_layout(config, mt, layout)
	var gt: GantrywayTuning = GantrywayTuning.load_default()
	var walkway: float = GantrywayRules.walkway_length(gen, gt)
	var calm: float = GantrywayRules.calm_length(gen, gt)
	var start: float = pillar - GantrywayRules.NEAR_OVERHANG
	var g := {"id": layout.gantryways.size(), "lane": lane, "start": start, "end": start + walkway, "pillar": pillar,
		"side": side, "calm": [pillar, pillar + calm], "seed": 7, "intro": false, "both": false}
	layout.gantryways.append(g)
	var box: Vector3 = mt.doodad_size(Gantryway.PILLAR_SIZE)
	layout.doodads.append({"lane": lane, "start": pillar, "end": pillar + box.z, "size": Gantryway.PILLAR_SIZE, "side": side,
		"seed": 7, LevelLayout.GANTRY_PILLAR: int(g["id"])})
	return g


## Steps `w` up to `seconds` of physics, the runner running: `actions` ([distance, action], RunSim's) fire as they reach
## them, `bot` is called with the world before each step, and it stops once `done` (called with the world after each step)
## holds or the runner dies. Every frame is watched (_watch). Returns {done, alive, cause, faults, events ([kind, level
## time]), hunter (the last one seen), history and sounds (its, kept after it's gone)}.
func _run(w: RunWorld, seconds: float, actions: Array = [], bot: Callable = Callable(), done: Callable = Callable()) -> Dictionary:
	var p: Player = w.player
	if not p.running:
		await tree.physics_frame
		p.running = true
	var out := {"done": false, "alive": true, "cause": "", "faults": PackedStringArray(), "events": [], "hunter": null,
		"history": [], "sounds": []}
	var on_event := func(kind: StringName) -> void: (out["events"] as Array).append([kind, w.level_time()])
	var on_died := func(cause: String) -> void: out["cause"] = cause
	p.movement_event.connect(on_event)
	p.died.connect(on_died)
	var pending: Array = actions.duplicate()
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		while not pending.is_empty() and p.distance >= float(pending[0][0]):
			RunSim.act(p, pending.pop_front()[1])
		if bot.is_valid():
			bot.call(w)
		await tree.physics_frame
		var h: Hunter = _hunter(w)
		if h != null:
			out["hunter"] = h
			out["history"] = h.history
			out["sounds"] = h.sounds_played
			_watch(w, h, out["faults"])
		if done.is_valid() and done.call(w):
			out["done"] = true
			break
		if not p.alive:
			break
	p.movement_event.disconnect(on_event)
	p.died.disconnect(on_died)
	out["alive"] = p.alive
	return out


## Its rules, every frame: its body never meets the runner's (it never takes their lane where they are), it never sinks
## below the floor (it hovers over holes), and its cuts are live only in the lane it warned of, a whole warning after.
func _watch(w: RunWorld, h: Hunter, faults: PackedStringArray) -> void:
	if not h.visible or not h.alive:
		return
	var p: Player = w.player
	var at: String = "at %.1f m" % p.distance
	if p.surface == Player.Surface.FLOOR and p.alive:
		var dx: float = absf(h.global_position.x - p.position.x)
		var reach_x: float = (w.geo.lane_width * 0.9 + w.tuning.hurtbox_size.x) * 0.5 - 0.05
		var reach_z: float = (t.blocker_length + w.tuning.hurtbox_size.z) * 0.5
		if dx < reach_x and absf(h.gap) < reach_z and faults.size() < 20:
			faults.append("its body met the runner's %s (x %.2f apart, gap %.2f)" % [at, dx, h.gap])
	if h.global_position.y < -0.001 and faults.size() < 20:
		faults.append("it sank to %.2f %s" % [h.global_position.y, at])
	if h.is_cutting():
		var box: Hazard = h.slash_hitbox()
		if absf(box.global_position.x - w.geo.lane_x(h.slash_lane)) > 0.01 and faults.size() < 20:
			faults.append("its cuts left the lane it warned of %s" % at)
		var warned: float = -INF
		for e: Array in h.history:
			if String(e[0]) == "warn":
				warned = float(e[2])
		if w.level_time() - warned < t.warning_seconds - 0.02 and faults.size() < 20:
			faults.append("it cut %.2f s after its warning %s" % [w.level_time() - warned, at])


## Runs `w` until its Hunter is beside the runner (ALONGSIDE), up to `seconds`.
func _until_alongside(w: RunWorld, seconds: float = UP_SECONDS, bot: Callable = Callable()) -> Dictionary:
	return await _run(w, seconds, [], bot, func(ww: RunWorld) -> bool:
		var h: Hunter = _hunter(ww)
		return h != null and h.state == Hunter.State.ALONGSIDE)


## The events in history `history` named `event`, as [runner distance, level time].
static func _events(history: Array, event: String) -> Array:
	var out: Array = []
	for e: Array in history:
		if String(e[0]) == event:
			out.append([float(e[1]), float(e[2])])
	return out


## A runner who steps one lane away from the Hunter a reaction into each of its warnings (once a warning).
func _dodger(state: Dictionary) -> Callable:
	return func(w: RunWorld) -> void:
		var h: Hunter = _hunter(w)
		if h == null or h.slash != Hunter.Slash.WARNING or int(state.get("dodged", -1)) == h.flurries:
			return
		if float(h.get(&"_slash_t")) < REACTION:
			return
		state["dodged"] = h.flurries
		state["steps"] = int(state.get("steps", 0)) + 1
		RunSim.act(w.player, &"move_left" if h.side > 0 else &"move_right")


func _brief(r: Dictionary) -> String:
	var names: Array = (r["history"] as Array).map(func(e: Array) -> String: return String(e[0]))
	return "(alive %s, cause '%s', history %s, faults %s)" % [r["alive"], r["cause"], names, r["faults"]]


# --- Numbers --------------------------------------------------------------------------------------

func _test_numbers() -> void:
	var truck := EnemyDirector.tuning_for("enforcer_truck") as EnforcerTruckTuning
	check(is_equal_approx(t.chase_seconds, 25.0) and is_equal_approx(t.chase_seconds, truck.chase_seconds),
		"it follows the runner about as long as the Enforcer Truck does (%.0f s, GDD §9.17)" % t.chase_seconds)
	check(not t.uses_floor and t.behind_runner, "it never stands on the floor ahead of the runner (no floor use; it comes from behind)")
	check(t.warning_seconds >= 0.8 and t.warning_seconds - REACTION >= mt.lane_switch_time + 0.2,
		"its warning (%.2f s) leaves a reaction and a whole lane change before its cuts" % t.warning_seconds)
	check(t.slash_height > mt.jump_height + 0.2, "its cuts reach a runner at the top of a jump (%.2f m over a %.2f m jump)"
		% [t.slash_height, mt.jump_height])
	for lanes: int in LANE_COUNTS:
		var geo := TrackGeometry.new(lanes, mt)
		var half: float = geo.lane_width * 0.5 - t.side_margin
		check(half + mt.hurtbox_size.x * 0.5 < geo.lane_width - 0.1 and half > mt.hurtbox_size.x * 0.5,
			"%d lanes: its cuts cover the runner anywhere in their lane, never one lane over" % lanes)
	check(t.blocker_height >= mt.jump_height + mt.hurtbox_size.y,
		"its solid side stands over a whole jump: a runner can't jump across into it (%.2f m)" % t.blocker_height)
	check(t.hitbox_size.x < HunterModel.DISC_RADIUS * 2.0 and t.hover_height + t.hitbox_size.y < HunterModel.TOP
		and t.hitbox_size.z < HunterModel.DISC_RADIUS * 2.0, "its body's box is a little smaller than its look")
	check(t.slash_interval_min <= t.slash_interval_max and t.slash_interval_min > t.attack_seconds() + t.recover_seconds,
		"its flurries come one at a time, each over before the next is warned")
	check(t.bait_after_seconds + t.bait_before_seconds < t.chase_seconds and t.intro_bait_min_seconds <= t.intro_bait_max_seconds,
		"a bait fits in its chase")
	# Every number reaches the F6 panel.
	var ranged: bool = true
	var count: int = 0
	for p: Dictionary in t.get_property_list():
		if not (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) or not (int(p["usage"]) & PROPERTY_USAGE_EDITOR):
			continue
		if int(p["type"]) == TYPE_FLOAT or int(p["type"]) == TYPE_INT:
			count += 1
			if int(p["hint"]) != PROPERTY_HINT_RANGE:
				ranged = false
				failures.append("HunterTuning.%s has no range hint" % p["name"])
	check(ranged and count >= 40, "every number of its tuning has a range for the F6 panel (%d)" % count)


# --- Look -----------------------------------------------------------------------------------------

func _test_model() -> void:
	var m := HunterModel.new()
	tree.root.add_child(m)
	m.build()
	check(m.draw_call_count() <= 10 and m.triangle_count() <= 9000,
		"its look is a few draw calls (%d) and triangles (%d)" % [m.draw_call_count(), m.triangle_count()])
	var faults: PackedStringArray = []
	for entry: Dictionary in m.materials():
		var part: String = entry["part"]
		var mat := entry["material"] as StandardMaterial3D
		if mat == null:
			faults.append("%s: not a standard material" % part)
			continue
		var should: bool = part.contains("Eyes") or part.contains("Blade") or part.contains("Jets")
		if mat.emission_enabled != should:
			faults.append("%s %s" % [part, "glows" if mat.emission_enabled else "doesn't glow"])
	check(faults.is_empty(), "standard materials only (the Compatibility renderer), and only its eyes, blades and jets glow (%s)"
		% [faults])
	var calm := HunterModel.blade_material(false)
	var alert := HunterModel.blade_material(true)
	check(calm.emission.r > 0.9 and calm.emission.g < 0.2 and calm.emission.b < 0.2 and calm.albedo_color.r > calm.albedo_color.g * 4.0,
		"its blades are the hazard red")
	check(alert.emission_energy_multiplier > calm.emission_energy_multiplier * 2.0
		and (HunterModel.eye_material(true) as StandardMaterial3D).emission_energy_multiplier
		> (HunterModel.eye_material(false) as StandardMaterial3D).emission_energy_multiplier,
		"its blades and eyes brighten while it warns and cuts (a change of state, never a flicker)")
	check(HunterModel.JET.s < 0.3 and HunterModel.EYE.h < 0.12, "its jets glow a pale blue-white, its eyes orange-red")
	# Calm: its blades forward beside it; a warning: both raised over its head; a flurry: the arms chop in turn.
	var rest_top: float = _blades_top(m)
	m.raise = 1.0
	m.alert = true
	m.animate(0.0)
	var raised_top: float = _blades_top(m)
	check(rest_top < HunterModel.TOP + m.hover and raised_top > HunterModel.TOP + m.hover + 0.4,
		"a warning raises both blades over its head (their tops %.2f m, at rest %.2f m)" % [raised_top, rest_top])
	check(m.blades[0].material_override == alert and m.blades[1].material_override == alert, "alert, its blades brighten")
	var pitches: Array = []
	for cut: float in [0.2, 0.45, 0.7, 0.95]:
		m.cut = cut
		m.animate(0.0)
		pitches.append([m.arms[0].rotation.x, m.arms[1].rotation.x])
	var turns: bool = true
	for k: int in pitches.size():
		var chopping: int = k % 2
		turns = turns and float(pitches[k][chopping]) < float(pitches[k][1 - chopping])
	check(turns, "through a flurry its arms chop in turn (%s)" % [pitches])
	m.free()


## The highest point of the model's blades (world space).
static func _blades_top(m: HunterModel) -> float:
	var top: float = -INF
	for b: MeshInstance3D in m.blades:
		var box: AABB = b.global_transform * b.mesh.get_aabb()
		top = maxf(top, box.end.y)
	return top


## Beside the runner its whole look is on screen in the chase camera's resting view (EnforcerTruckView: the run
## camera's arithmetic), calm, warning or cutting, its torso turned toward them, at 3, 5 and 6 lanes, every runner lane
## and either side; it hides neither the runner nor the floor of their lane and of the lane they'd step into, from them to
## 20 m ahead.
func _test_view() -> void:
	var m := HunterModel.new()
	tree.root.add_child(m)
	m.build()
	var looks: Dictionary = {}
	for side: int in [-1, 1]:
		var box := AABB()
		var first: bool = true
		for pose: int in 3:
			m.raise = 0.0 if pose == 0 else 1.0
			m.cut = 0.3 if pose == 2 else -1.0
			m.lean = 0.32 if pose == 2 else 0.0
			# Its torso turned back toward the runner beside it (Hunter._place).
			m.face_yaw = atan2(side * 2.4, -t.alongside_ahead)
			m.animate(0.0)
			for mi: MeshInstance3D in m.mesh_nodes():
				var b: AABB = mi.global_transform * mi.mesh.get_aabb()
				box = b if first else box.merge(b)
				first = false
		looks[side] = box
	m.free()
	var faults: PackedStringArray = []
	var worst: float = 0.0
	for lanes: int in LANE_COUNTS:
		var geo := TrackGeometry.new(lanes, mt)
		for r: int in lanes:
			for side: int in [-1, 1]:
				var l: int = r + side
				if l < 0 or l >= lanes:
					continue
				var d: float = 300.0
				var view := EnforcerTruckView.of_runner(mt, geo, r, d)
				var look: AABB = looks[side]
				var box := AABB(look.position + Vector3(geo.lane_x(l), 0.0, TrackGeometry.world_z(d + t.alongside_ahead)), look.size)
				var tag: String = "%d lanes, runner %d, Hunter %d" % [lanes, r, l]
				for i: int in 8:
					var s: Vector2 = view.screen(box.get_endpoint(i))
					worst = maxf(worst, maxf(absf(s.x), absf(s.y)))
					if not view.on_screen(box.get_endpoint(i)):
						faults.append("%s: a corner off screen (%s)" % [tag, s])
						break
				for p: Vector3 in EnforcerTruckView.runner_points(mt, geo.lane_x(r), d):
					if view.hides(box, p):
						faults.append("%s: it hides the runner" % tag)
						break
				var far: int = r - side
				for lane: int in [r, far]:
					if lane < 0 or lane >= lanes:
						continue
					for ahead: float in [0.0, 5.0, 10.0, 20.0]:
						if view.hides(box, Vector3(geo.lane_x(lane), 0.05, TrackGeometry.world_z(d + ahead))):
							faults.append("%s: it hides lane %d's floor %.0f m ahead" % [tag, lane, ahead])
	check(faults.is_empty(), "beside the runner its whole look is on screen (its furthest corner %.0f%% of the way to the edge), hiding nothing of them or the lanes they need (%s)"
		% [worst * 100.0, faults])


# --- Arrival and following ------------------------------------------------------------------------

func _test_arrival() -> void:
	for lanes: int in LANE_COUNTS:
		for lane: int in [0, lanes / 2, lanes - 1]:
			var tag: String = "(%d lanes, the runner in lane %d)" % [lanes, lane]
			var w: RunWorld = _world(_layout(lanes), lane)
			w.player.god_mode = true
			# Before its spot: unseen, harmless, not solid.
			var before: Dictionary = await _run(w, 6.0, [], Callable(), func(ww: RunWorld) -> bool:
				return ww.player.distance >= ARRIVE - 3.0)
			var h: Hunter = _hunter(w)
			check(h == null or (not h.visible and not h.blocking() and not h.body_hitbox().is_active() and h.state == Hunter.State.WAITING),
				"before the runner reaches its spot it's unseen, harmless and not solid " + tag)
			var r: Dictionary = await _until_alongside(w)
			h = r["hunter"]
			var arrive: Array = _events(r["history"], "arrive")
			var up: Array = _events(r["history"], "alongside")
			check(h != null and bool(r["done"]) and arrive.size() == 1 and up.size() == 1 and float(arrive[0][0]) >= ARRIVE
				and float(arrive[0][0]) < ARRIVE + 1.0, "it arrives as the runner reaches its spot and comes up beside them %s %s"
				% [_brief(r), tag])
			if h == null or arrive.is_empty() or up.is_empty():
				await sim.free_world(w)
				continue
			check((r["sounds"] as Array).any(func(s: Array) -> bool: return s[0] == &"hunter_whine" and absf(float(s[1]) - float(arrive[0][1])) < 0.02),
				"its whine rises as it arrives " + tag)
			var took: float = float(up[0][1]) - float(arrive[0][1])
			check(took <= t.arrive_gap / t.approach_speed + 1.5, "from behind it's beside them %.1f s after arriving %s" % [took, tag])
			check(absf(h.lane - w.player.lane) == 1 and h.lane == w.player.lane + h.side and h.target_lane == h.lane
				and absf(h.gap + t.alongside_ahead) < 0.36, "in a lane beside theirs (%d), its middle %.2f m ahead of theirs %s"
				% [h.lane, -h.gap, tag])
			if lane == 0 or lane == lanes - 1:
				check(h.side == (1 if lane == 0 else -1), "by the edge it comes up on their only side " + tag)
			check(h.visible and h.blocking() and h.body_hitbox().is_active() and h.body_hitbox().harmless,
				"it's seen, solid, its body harmless " + tag)
			check((before["faults"] as PackedStringArray).is_empty() and (r["faults"] as PackedStringArray).is_empty(),
				"its rules held %s %s" % [r["faults"], tag])
			await sim.free_world(w)


## Beside the runner it follows into the lane they leave a moment later, on its side; a runner changing lanes into it is
## bumped back unharmed (dashing too), and it unharmed.
func _test_follow() -> void:
	for lanes: int in [5, 6]:
		var tag: String = "(%d lanes)" % lanes
		var start: int = lanes / 2
		var w: RunWorld = _world(_layout(lanes), start)
		_no_flurries(w)
		var r: Dictionary = await _until_alongside(w)
		var h: Hunter = r["hunter"]
		if h == null or not bool(r["done"]):
			check(false, "a Hunter beside the runner " + tag)
			await sim.free_world(w)
			continue
		var side: int = h.side
		var away: StringName = &"move_left" if side > 0 else &"move_right"
		var toward: StringName = &"move_right" if side > 0 else &"move_left"
		for step: int in 2:
			var left: int = w.player.lane
			var stepped: Array = [-1.0, -1.0]
			var watch := func(ww: RunWorld) -> bool:
				var hh: Hunter = _hunter(ww)
				if stepped[0] < 0.0 and ww.player.lane != left:
					stepped[0] = ww.level_time()
				if stepped[0] >= 0.0 and stepped[1] < 0.0 and hh != null and hh.target_lane == left:
					stepped[1] = ww.level_time()
				return stepped[1] >= 0.0 and hh != null and hh.lane == left and ww.level_time() - stepped[1] > t.switch_seconds + 0.3
			RunSim.act(w.player, away)
			r = await _run(w, 3.0, [], Callable(), watch)
			var delay: float = stepped[1] - stepped[0]
			check(bool(r["done"]) and absf(delay - t.follow_delay_seconds) < 0.04 and h.side == side
				and w.player.lane == left - side,
				"the runner steps away from it: it follows into the lane they left (%d) %.2f s later, on its side %s %s"
				% [left, delay, _brief(r), tag])
		# Into it: bumped back, unharmed, and it too; dashing as well.
		for dashing: bool in [false, true]:
			var lane_before: int = w.player.lane
			var bumps: int = 0
			if dashing:
				RunSim.act(w.player, &"dash")
			RunSim.act(w.player, toward)
			r = await _run(w, 0.6)
			for e: Array in r["events"]:
				bumps += 1 if e[0] == &"lane_blocked" else 0
			check(bool(r["alive"]) and w.player.lane == lane_before and bumps == 1 and h.alive,
				"a runner changing lanes into it%s is bumped back unharmed, and it's unharmed %s %s"
				% [" while dashing" if dashing else "", _brief(r), tag])
			r = await _run(w, 0.6)
		check((r["faults"] as PackedStringArray).is_empty(), "its rules held %s %s" % [r["faults"], tag])
		await sim.free_world(w)


# --- The flurry -----------------------------------------------------------------------------------

## Every flurry warned a whole warning before its cuts, which reach only the lane it warned of: a runner who steps one
## lane away lives, one who stays or jumps is cut down; armor or the shield absorbs a flurry, one hit for all of it.
func _test_flurry() -> void:
	for lanes: int in [3, 5]:
		var tag: String = "(%d lanes)" % lanes
		# The runner steps away from each one; from lane 1 at 5 lanes it has room for three.
		var start: int = 1
		var w: RunWorld = _world(_layout(lanes), start)
		var state: Dictionary = {}
		var marks: Array = [0, 0]
		var bot: Callable = _dodger(state)
		var watch := func(ww: RunWorld) -> void:
			bot.call(ww)
			var hh: Hunter = _hunter(ww)
			if hh != null and hh.slash == Hunter.Slash.WARNING:
				marks[0] += 1
				marks[1] += 1 if (hh.get(&"_mark") as MeshInstance3D).visible else 0
		var r: Dictionary = await _run(w, 22.0, [], watch, func(ww: RunWorld) -> bool:
			var hh: Hunter = _hunter(ww)
			return hh != null and hh.state == Hunter.State.LEAVING)
		var warns: Array = _events(r["history"], "warn")
		var cuts: Array = _events(r["history"], "cut")
		var scrapes: int = (r["sounds"] as Array).filter(func(s: Array) -> bool: return s[0] == &"hunter_scrape").size()
		var slashes: int = (r["sounds"] as Array).filter(func(s: Array) -> bool: return s[0] == &"hunter_slash").size()
		check(bool(r["alive"]) and warns.size() >= lanes - 2 and cuts.size() == warns.size(),
			"a runner who steps one lane away from each flurry lives through all of them (%d warned, %d cut) %s %s"
			% [warns.size(), cuts.size(), _brief(r), tag])
		var gaps_ok: bool = true
		for k: int in mini(warns.size(), cuts.size()):
			gaps_ok = gaps_ok and absf(float(cuts[k][1]) - float(warns[k][1]) - t.warning_seconds) < 0.03
		check(gaps_ok and scrapes == warns.size() and slashes == cuts.size() and marks[0] > 0 and marks[1] == marks[0],
			"every flurry is warned (the scrape, the red mark) a whole warning (%.2f s) before its cuts %s" % [t.warning_seconds, tag])
		check((r["faults"] as PackedStringArray).is_empty(), "its rules held %s %s" % [r["faults"], tag])
		await sim.free_world(w)
	# Staying, jumping, the armor and the shield (5 lanes, the runner in the middle).
	for how: String in ["stay", "jump", "armor", "shield", "god"]:
		var tag: String = "(%s)" % how
		var w: RunWorld = _world(_layout(5), 2)
		var p: Player = w.player
		if how == "armor":
			p.armor_state.carried = true
			p.armor_state.hits = p.armor_state.max_hits
		if how == "shield":
			p.shield = 1
		p.god_mode = how == "god"
		var jumped: Array = [false]
		var bot := func(ww: RunWorld) -> void:
			var hh: Hunter = _hunter(ww)
			if how == "jump" and not jumped[0] and hh != null and hh.slash == Hunter.Slash.WARNING \
					and float(hh.get(&"_slash_t")) >= t.warning_seconds - 0.12:
				jumped[0] = true
				RunSim.act(ww.player, &"jump")
		var r: Dictionary = await _run(w, 14.0, [], bot, func(ww: RunWorld) -> bool:
			var hh: Hunter = _hunter(ww)
			return hh != null and hh.flurries_cut >= 1 and hh.slash == Hunter.Slash.IDLE)
		var events: Array = (r["events"] as Array).map(func(e: Array) -> StringName: return e[0])
		var cut: Array = _events(r["history"], "cut")
		match how:
			"stay", "jump":
				var died_at: float = -1.0
				for e: Array in r["events"]:
					if e[0] == &"died":
						died_at = float(e[1])
				check(not bool(r["alive"]) and String(r["cause"]) == Hunter.SLASH_NAME and not cut.is_empty()
					and died_at >= float(cut[0][1]) - 0.001, "a runner who %s is cut down by its flurry, never before its cuts %s %s"
					% ["stays in their lane" if how == "stay" else "jumps its cuts", _brief(r), tag])
			"armor":
				var hits: int = events.count(&"armor_hit") + events.count(&"armor_break")
				check(bool(r["alive"]) and hits == 1 and bool(r["done"]), "the armor absorbs the flurry, one hit for all of its cuts %s %s"
					% [_brief(r), tag])
			"shield":
				check(bool(r["alive"]) and events.count(&"shield_break") == 1 and p.shield == 0 and bool(r["done"]),
					"the shield absorbs the flurry, one break for all of its cuts %s %s" % [_brief(r), tag])
			"god":
				check(bool(r["alive"]) and bool(r["done"]), "god mode shrugs it off %s" % tag)
		await sim.free_world(w)


## No flurry without a lane away from it to step into: a runner by the edge with it inward; holes in the runner's other
## lane (then flurries again once it's open). It hovers over holes in its own lane, keeping beside them and slashing.
func _test_no_way_out() -> void:
	# By the edge.
	for lanes: int in [3, 5]:
		var w: RunWorld = _world(_layout(lanes), 0)
		w.player.god_mode = true
		var r: Dictionary = await _until_alongside(w)
		r = await _run(w, 12.0)
		var h: Hunter = r["hunter"]
		check(h != null and h.side == 1 and h.flurries == 0 and h.state == Hunter.State.ALONGSIDE,
			"a runner by the edge with it inward has no lane away from it: it never slashes (%d lanes) %s" % [lanes, _brief(r)])
		await sim.free_world(w)
	# Holes in the runner's other lane (its side forced by a bait it plans for: the far lane is 3), then in its own lane.
	for holes_in: String in ["far", "own"]:
		var layout: LevelLayout = _layout(5, {"baits": [{"at": 560.0, "lane": 2, "side": 1, "id": 0}]})
		var hole_lane: int = 3 if holes_in == "far" else 1
		layout.gaps.append({"lane": hole_lane, "start": 150.0, "end": 400.0})
		var w: RunWorld = _world(layout, 2)
		w.player.god_mode = true
		var r: Dictionary = await _run(w, 18.0)
		var h: Hunter = r["hunter"]
		var warns: Array = _events(r["history"], "warn")
		var inside: int = 0
		var after: int = 0
		var v: float = mt.run_speed
		for wn: Array in warns:
			var d: float = float(wn[0])
			if d + t.attack_seconds() * v + 2.0 >= 150.0 and d + t.escape_reaction_seconds * v <= 400.0:
				inside += 1
			if d > 400.0:
				after += 1
		if holes_in == "far":
			check(h != null and h.side == -1 and inside == 0 and after >= 1,
				"no flurry while the runner's other lane is a hole (its way out), and flurries again once it's open (%d after) %s"
				% [after, _brief(r)])
		else:
			check(h != null and h.side == -1 and inside >= 1 and bool(r["alive"]),
				"over holes in its own lane it hovers on beside the runner, slashing as ever (%d flurries over them) %s" % [inside, _brief(r)])
		check((r["faults"] as PackedStringArray).is_empty(), "its rules held (holes in the %s lane) %s" % [holes_in, r["faults"]])
		await sim.free_world(w)


# --- The bait -------------------------------------------------------------------------------------

## The gantryway bait (GDD §9.17) at 3, 5 and 6 lanes, both ways round: its flurries held off, the runner in the walkway's
## lane with it beside them away from the pillar's push, dashes the pillar and steps out a reaction later away from it; it
## follows into the walkway's lane and the walkway lands on it, the runner's kill.
func _test_bait() -> void:
	var pillar: float = 330.0
	var dashing: float = mt.run_speed + pt.dash_speed_bonus
	for lanes: int in LANE_COUNTS:
		for lane: int in range(1, lanes - 1):
			for side: int in [-1, 1]:
				var tag: String = "(%d lanes, the walkway over lane %d, stepping out %s)" % [lanes, lane, "left" if side < 0 else "right"]
				var layout: LevelLayout = _layout(lanes, {"baits": [{"at": pillar, "lane": lane, "side": side, "id": 0}]})
				_gantryway(layout, lane, pillar, side)
				var w: RunWorld = _world(layout, lane)
				_no_flurries(w)
				var crushed: Array = []
				w.director.enemy_defeated.connect(func(e: Enemy, cause: StringName) -> void:
					if e is Hunter:
						crushed.append(cause))
				var kills: int = w.score.kills
				var actions: Array = [[pillar - 0.5 * pt.dash_duration * dashing, &"dash"],
					[pillar + REACTION * dashing, &"move_left" if side < 0 else &"move_right"]]
				var r: Dictionary = await _run(w, (pillar + 60.0) / mt.run_speed, actions, Callable(), func(_ww: RunWorld) -> bool:
					return not crushed.is_empty())
				var h_side: int = -2
				for e: Array in r["history"]:
					if String(e[0]) == "alongside":
						h_side = -side
				check(bool(r["alive"]) and crushed == [Gantryway.CRUSH_CAUSE] and w.score.kills == kills + 1 and h_side == -side
					and (r["sounds"] as Array).any(func(s: Array) -> bool: return s[0] == &"hunter_death"),
					"it comes up away from the pillar's push, follows the runner who steps out from under the falling walkway into its lane, and it lands on it: the runner's kill %s %s"
					% [_brief(r), tag])
				check((r["faults"] as PackedStringArray).is_empty(), "its rules held %s %s" % [r["faults"], tag])
				await sim.free_world(w)


## A whole encounter (the showcase's): 5 lanes, the runner in lane 1; it arrives, comes up on their left (away from the
## bait's step out), and warns; the runner steps away from it into the walkway's lane; it follows; then the bait: the
## pillar dashed, the step out, and the walkway lands on it.
func _test_encounter() -> void:
	var pillar: float = 250.0
	var dashing: float = mt.run_speed + pt.dash_speed_bonus
	var layout: LevelLayout = _layout(5, {"baits": [{"at": pillar, "lane": 2, "side": 1, "id": 0}]})
	layout.enemies[0]["at"] = 40.0
	_gantryway(layout, 2, pillar, 1)
	var w: RunWorld = _world(layout, 1)
	var crushed: Array = []
	w.director.enemy_defeated.connect(func(e: Enemy, cause: StringName) -> void:
		if e is Hunter:
			crushed.append(cause))
	var actions: Array = [[pillar - 0.5 * pt.dash_duration * dashing, &"dash"], [pillar + REACTION * dashing, &"move_right"]]
	var r: Dictionary = await _run(w, (pillar + 60.0) / mt.run_speed, actions, _dodger({}), func(_ww: RunWorld) -> bool:
		return not crushed.is_empty())
	var warns: Array = _events(r["history"], "warn")
	check(bool(r["alive"]) and warns.size() == 1 and _events(r["history"], "cut").size() == 1 and crushed == [Gantryway.CRUSH_CAUSE],
		"a whole encounter: one flurry dodged into the walkway's lane, its next held by the bait's run-up, then the walkway lands on it %s"
		% _brief(r))
	check((r["faults"] as PackedStringArray).is_empty(), "its rules held through the encounter %s" % [r["faults"]])
	await sim.free_world(w)


# --- Weapons and contacts -------------------------------------------------------------------------

## 25 laser tier 1 shots (GDD §8, the owner: "25 for now"): 24 leave it going, the 25th destroys it; the other tiers and
## the missiles in proportion (23 health over their plain damage). Auto-fire picks it beside the runner; it shows a
## health bar; a real shot hits it.
func _test_weapons() -> void:
	var loadout := Loadout.new()
	loadout.tiers[&"weapon"] = 1
	var w: RunWorld = _world(_layout(3), 1, loadout)
	w.player.god_mode = true
	_no_flurries(w)
	var r: Dictionary = await _until_alongside(w)
	var h: Hunter = r["hunter"]
	var c := w.powerups as PowerupController
	if h == null or c == null or c.weapon == null:
		check(false, "a Hunter beside a runner with the laser")
		await sim.free_world(w)
		return
	check(h.targetable() and w.director.targets_ahead(c.weapon.muzzle_point(), c.weapon.range_m()).has(h)
		and EnemyHealthBars.wants_bar(h), "auto-fire picks it beside the runner, and it shows a health bar")
	var counts: Array[int] = []
	for tier: int in [1, 2, 3, 4]:
		c.weapon.tier = tier
		counts.append(ceili(h.max_health / c.weapon.damage(h) - 0.0001))
	var plain: Array[int] = []
	for tier: int in [2, 3, 4]:
		plain.append(ceili(h.max_health / PowerupTuning.at_tier(pt.weapon_damage, tier) - 0.0001))
	check(counts[0] == 25 and counts.slice(1) == plain and is_equal_approx(h.max_health, t.health_early),
		"25 laser tier 1 shots, the other tiers in proportion (%s; health %.1f)" % [counts, h.max_health])
	c.weapon.tier = 1
	var hits: Array[int] = [0]
	w.projectiles.enemy_hit.connect(func(e: Enemy, _d: float, _s: bool) -> void:
		if e == h:
			hits[0] += 1)
	var from: Vector3 = w.player.position + Vector3(0.0, 1.0, 0.0)
	w.projectiles.fire_player(from, (h.aim_point() - from).normalized() * 90.0 + Vector3(0.0, 0.0, -w.player.speed), 0.01, &"laser")
	await physics_frames(8)
	check(hits[0] == 1, "a laser shot hits it")
	var dmg: float = c.weapon.damage(h)
	for i: int in 23:
		h.take_damage(dmg, &"weapon")
	check(h.alive, "24 laser tier 1 hits don't stop it (the 25th's shot and 23 more)")
	h.take_damage(dmg, &"weapon")
	check(not h.alive and h.state == Hunter.State.DEAD and h.sounds_played.any(func(s: Array) -> bool: return s[0] == &"hunter_death"),
		"the 25th destroys it, in its death's crunch and blast")
	await sim.free_world(w)


## The claws, a stomp and the dash never defeat it (its body is harmless: DamageRules ignores it whatever protects the
## runner); its cuts are an enemy attack (the armor blocks them, the dash passes them); other enemies' charges pass it by.
func _test_contacts() -> void:
	var w: RunWorld = _world(_layout(3), 1)
	w.player.god_mode = true
	_no_flurries(w)
	var r: Dictionary = await _until_alongside(w)
	var h: Hunter = r["hunter"]
	if h == null:
		check(false, "a Hunter for the contacts")
		await sim.free_world(w)
		return
	var body: Hazard = h.body_hitbox()
	var faults: PackedStringArray = []
	for protection: String in ["", "armor", "shield", "claws", "dashing", "invulnerable", "god_mode"]:
		for stomping: bool in [false, true]:
			var d := DamageRules.Defense.new()
			if protection != "":
				d.set(protection, true)
			var outcome: DamageRules.Outcome = DamageRules.resolve(body, d, stomping)
			if outcome != DamageRules.Outcome.IGNORE:
				faults.append("%s/stomp=%s: %s" % [protection, stomping, outcome])
	check(faults.is_empty() and body.part == &"body" and body.is_active(),
		"touching its body does nothing whatever protects the runner: a stomp, the claws and the dash never defeat it (%s)" % [faults])
	check(not h.stompable and h.claw_immune and not h.dash_kills and not h.charge_can_hurt() and h.follows_runner,
		"it declares it: not stompable, claw-immune, no dash kill, no harm from charges; it keeps its place by the runner")
	var slash: Hazard = h.slash_hitbox()
	check(slash.is_enemy_attack and slash.part == &"attack" and slash.dash_passes and not slash.harmless,
		"its cuts are an enemy attack: the armor and the shield block them, the dash passes them")
	# A charge passes it by.
	var attacker := Enemy.new()
	w.add_child(attacker)
	attacker.setup(w, {}, null)
	var box: Hazard = attacker.add_hitbox(&"body", Vector3(1.0, 1.6, 1.0), Vector3(0.0, 0.8, 0.0), true)
	attacker.global_position = h.global_position
	attacker.set_physics_process(false)
	await physics_frames(2)
	attacker._begin_charge_contacts()
	attacker._hurt_charge_contacts(box, box.global_transform)
	h.take_damage(99.0, Enemy.CHARGE_DAMAGE_CAUSE)
	check(h.alive and is_equal_approx(h.health, h.max_health), "another enemy's charge passes it by")
	attacker.free()
	await sim.free_world(w)


# --- Steering -------------------------------------------------------------------------------------

## It goes round what stands in its lane (a doodad, a standing enemy), never into the runner's lane, its body never
## meeting them; then it's beside the runner again.
func _test_steering() -> void:
	for what: String in ["doodad", "enemy"]:
		var layout: LevelLayout = _layout(5, {"baits": [{"at": 560.0, "lane": 2, "side": 1, "id": 0}]})
		# It comes up on the runner's left (lane 1): the obstacle stands there.
		var at: float = 260.0
		if what == "doodad":
			var box: Vector3 = mt.doodad_size(Gantryway.PILLAR_SIZE)
			layout.doodads.append({"lane": 1, "start": at, "end": at + box.z, "size": Gantryway.PILLAR_SIZE, "side": -1, "seed": 3})
		else:
			layout.enemies.append({"type": "cyborg", "at": at, "lane": 1, "side": 0, "seed": 5,
				"params": {"stand": true, "fires": false, "panic": false, "host": false}})
		var w: RunWorld = _world(layout, 2)
		w.player.god_mode = true
		_no_flurries(w)
		var meets: Array = [0]
		var lanes_by: Array = []
		var watch := func(ww: RunWorld) -> void:
			var hh: Hunter = _hunter(ww)
			if hh == null or not hh.visible:
				return
			var mid: float = ww.player.distance - hh.gap
			if absf(mid - at) < t.blocker_length * 0.5 + 0.8 and ww.geo.lane_at(hh.global_position.x) == 1:
				meets[0] += 1
			if absf(mid - at) < 2.0:
				lanes_by.append(hh.lane)
		var r: Dictionary = await _run(w, (at + 120.0) / mt.run_speed, [], watch)
		var h: Hunter = r["hunter"]
		var stood: bool = true
		if what == "enemy":
			stood = w.director.active.any(func(e: Variant) -> bool: return is_instance_valid(e) and (e as Enemy).type_id == &"cyborg" and (e as Enemy).alive)
		check(h != null and meets[0] == 0 and not lanes_by.is_empty() and not lanes_by.has(1) and not lanes_by.has(2) and stood
			and h.state == Hunter.State.ALONGSIDE and h.lane == 1,
			"it goes round a %s in its lane (in lane %s there), never into the runner's, and comes back beside them %s"
			% [what, lanes_by, _brief(r)])
		check((r["faults"] as PackedStringArray).is_empty(), "its rules held (a %s) %s" % [what, r["faults"]])
		await sim.free_world(w)


# --- Ceilings, teleports and giving up --------------------------------------------------------------

## A runner who takes a pad onto a ceiling as its warning is on calls it off (no cut); on the ceiling it waits below beside
## them, never warning; back on the floor, it slashes again.
func _test_ceiling() -> void:
	var lanes: int = 5
	var pad: float = 300.0
	var layout: LevelLayout = _layout(lanes, {"baits": [{"at": 640.0, "lane": 2, "side": 1, "id": 0}]})
	layout.pads.append({"lane": 2, "at": pad})
	var hull_end: float = pad + 80.0
	layout.hulls.append(LevelLayout.make_hull(pad - 3.0, hull_end, Vector2i(2, 2), lanes))
	var w: RunWorld = _world(layout, 2)
	w.player.god_mode = true
	var forced: Array = [false]
	var below: Array = [0, 0]
	var bot := func(ww: RunWorld) -> void:
		var hh: Hunter = _hunter(ww)
		if hh == null:
			return
		# A warning just before the pad: the pad lifts the runner during it.
		if not forced[0] and ww.player.distance >= pad - 0.4 * mt.run_speed and hh.slash == Hunter.Slash.IDLE:
			forced[0] = true
			hh.set(&"_next_slash", hh.chase_time)
		if ww.player.surface == Player.Surface.CEILING:
			below[0] += 1
			below[1] += 1 if hh.state == Hunter.State.ALONGSIDE and absf(hh.lane - ww.player.lane) == 1 else 0
	var r: Dictionary = await _run(w, (hull_end + 160.0) / mt.run_speed, [], bot)
	var warns: Array = _events(r["history"], "warn")
	var called: Array = _events(r["history"], "called_off")
	var on_ceiling: Array = warns.filter(func(e: Array) -> bool: return float(e[0]) > pad + 1.0 and float(e[0]) < hull_end)
	var later: Array = warns.filter(func(e: Array) -> bool: return float(e[0]) > hull_end + 5.0)
	check(forced[0] and not warns.is_empty() and float(warns[0][0]) < pad and not called.is_empty()
		and float(called[0][0]) >= pad - 1.0 and float(called[0][0]) < pad + 3.0
		and _events(r["history"], "cut").filter(func(e: Array) -> bool: return float(e[0]) < hull_end).is_empty(),
		"a warning on as the pad lifts the runner is called off, no cut follows %s" % _brief(r))
	check(below[0] > 60 and below[1] == below[0] and on_ceiling.is_empty(),
		"on the ceiling it waits below beside them (%d of %d frames), never warning" % [below[1], below[0]])
	check(not later.is_empty(), "back on the floor it slashes again")
	check((r["faults"] as PackedStringArray).is_empty(), "its rules held (a ceiling) %s" % [r["faults"]])
	await sim.free_world(w)


## A teleporter's entry as its rules make one (test_teleporters' _entry): its pad in `lane` at `front`, one output pad in
## `out_lane` `hop` metres on.
func _teleporter(layout: LevelLayout, lane: int, front: float, out_lane: int, hop: float) -> Dictionary:
	var config := LevelConfig.new()
	config.lane_count = layout.lane_count
	var gen: LevelGenerator = LevelGenerator.for_layout(config, mt, layout)
	var tt: TeleporterTuning = TeleporterTuning.load_default()
	var tpt: PowerupTuning = TeleporterRules.powerups()
	var pad: float = TeleporterRules.pad_size(gen, tt)
	var approach: float = tt.approach_seconds * TeleporterRules.fastest(gen, tpt)
	var landing: float = TeleporterRules.landing_length(gen, tt, tpt, false)
	var land: float = front + hop
	var outputs: Array[Dictionary] = [{"lane": out_lane, "at": land, "end": land + pad}]
	var tp := {"id": layout.teleporters.size(), "lane": lane, "at": front, "end": front + pad, "side": 1 if lane == 0 else -1,
		"outputs": outputs, "light": 0, "blink": 0.0, "phase": 0.0,
		"calm": [[lane, front - approach, front + pad], [out_lane, land - TeleporterRules.LANDING_BACK, land + landing]],
		"span": [front - approach, land + landing], "seed": 7}
	layout.teleporters.append(tp)
	return tp


## A teleport leaves it behind: its warning called off, it catches up from where the jump left it (its whine again), its
## time running on from its arrival; one waiting for the runner whose spot the jump skips never comes.
func _test_teleport() -> void:
	var lanes: int = 5
	var front: float = 280.0
	var hop: float = 110.0
	var layout: LevelLayout = _layout(lanes, {"baits": [{"at": 900.0, "lane": 2, "side": 1, "id": 0}]})
	_teleporter(layout, 2, front, 2, hop)
	var w: RunWorld = _world(layout, 2)
	w.player.god_mode = true
	_no_flurries(w)
	var jumped: Array = [-1.0, -1.0]
	w.teleported.connect(func(_f: float, _to: float, _e: Dictionary, _o: Dictionary) -> void:
		var hh: Hunter = _hunter(w)
		jumped[0] = w.level_time()
		jumped[1] = hh.chase_time if hh != null else -1.0)
	var r: Dictionary = await _run(w, 14.0, [], Callable(), func(ww: RunWorld) -> bool:
		var hh: Hunter = _hunter(ww)
		return jumped[0] >= 0.0 and hh != null and hh.state == Hunter.State.ALONGSIDE and ww.level_time() > jumped[0] + 0.2)
	var h: Hunter = r["hunter"]
	var behind: Array = _events(r["history"], "left_behind")
	var arrive: Array = _events(r["history"], "arrive")
	var whines: int = (r["sounds"] as Array).filter(func(s: Array) -> bool: return s[0] == &"hunter_whine").size()
	check(w.player.teleports == 1 and behind.size() == 1 and whines == 2 and bool(r["done"]) and h != null,
		"a teleport leaves it behind and it catches up, its whine rising again %s" % _brief(r))
	if h != null and not arrive.is_empty() and jumped[1] >= 0.0:
		var caught: float = w.level_time() - jumped[0]
		check(caught <= t.catch_up_gap_max / t.approach_speed + 2.0 and absf(h.chase_time - (w.level_time() - float(arrive[0][1]))) < 0.05,
			"it's beside them again %.1f s after the jump, its time running on from its arrival (%.1f s)" % [caught, h.chase_time])
	await sim.free_world(w)
	# Its spot skipped by the jump: it never comes.
	layout = RunSim.layout(lanes, 1200.0)
	layout.enemies.append({"type": "hunter", "at": 330.0, "lane": 0, "side": 0, "seed": 7, "params": {}})
	_teleporter(layout, 2, 280.0, 2, 110.0)
	w = _world(layout, 2)
	w.player.god_mode = true
	r = await _run(w, 600.0 / mt.run_speed)
	check(w.player.teleports == 1 and (r["history"] as Array).is_empty() and _hunter(w) == null,
		"one whose spot the jump skipped never comes %s" % _brief(r))
	await sim.free_world(w)


## It gives up chase_seconds after arriving, whatever it's doing (flurries on, the runner dodging), its whine falling, and
## drops back out of play; it never starts a flurry it couldn't finish before then.
func _test_give_up() -> void:
	var w: RunWorld = _world(_layout(3), 1)
	w.player.god_mode = true
	var ref: Array = [null]
	var r: Dictionary = await _run(w, t.chase_seconds + 12.0, [], _dodger({}), func(ww: RunWorld) -> bool:
		var hh: Hunter = _hunter(ww)
		if hh != null:
			ref[0] = weakref(hh)
		return ref[0] != null and (ref[0] as WeakRef).get_ref() == null)
	var arrive: Array = _events(r["history"], "arrive")
	var gave: Array = _events(r["history"], "give_up")
	var warns: Array = _events(r["history"], "warn")
	check(arrive.size() == 1 and gave.size() == 1 and absf(float(gave[0][1]) - float(arrive[0][1]) - t.chase_seconds) < 0.03,
		"it gives up %.1f s after arriving %s" % [float(gave[0][1]) - float(arrive[0][1]) if not gave.is_empty() and not arrive.is_empty() else -1.0, _brief(r)])
	var last_ok: bool = true
	for wn: Array in warns:
		last_ok = last_ok and float(wn[1]) + t.attack_seconds() <= float(arrive[0][1]) + t.chase_seconds + 0.02
	check(warns.size() >= 3 and last_ok, "it slashed through its chase (%d flurries), never one it couldn't finish before giving up" % warns.size())
	check((r["sounds"] as Array).any(func(s: Array) -> bool: return s[0] == &"hunter_give_up") and bool(r["done"])
		and not w.director.active.any(func(e: Variant) -> bool: return is_instance_valid(e) and e is Hunter),
		"its whine falls as it gives up, and it drops back out of play")
	await sim.free_world(w)


## GDD §9.17 (the owner): it doesn't wait for the other big enemies, and (proposed) they don't wait for it: with another
## enemy's big attack on all the while, its flurries still come; it never asks for a turn, never reports a big attack.
func _test_turns() -> void:
	var layout: LevelLayout = _layout(5)
	var w: RunWorld = _world(layout, 2)
	w.player.god_mode = true
	await physics_frames(1)
	var dummy: Enemy = w.director.spawn({"type": "turn_dummy", "script": TURN_DUMMY, "at": 30.0, "lane": 4, "side": 0, "seed": 1,
		"params": {"first": 0.0, "interval": 0.2, "warning": 0.3, "attack": 3.0}})
	var during: Array = [0, 0]
	var major: Array = [false, false]
	var watch := func(ww: RunWorld) -> void:
		var hh: Hunter = _hunter(ww)
		if hh == null:
			return
		major[0] = major[0] or hh.is_major_attack_active()
		major[1] = major[1] or ww.director.is_waiting(hh)
		if hh.slash == Hunter.Slash.WARNING and float(hh.get(&"_slash_t")) < 0.02:
			during[0] += 1
			during[1] += 1 if is_instance_valid(dummy) and dummy.is_major_attack_active() else 0
	var r: Dictionary = await _run(w, 16.0, [], watch)
	check(during[0] >= 2 and during[1] >= 1 and not major[0] and not major[1],
		"its flurries come while another enemy's big attack is on (%d of %d), and it never reports one or waits" % [during[1], during[0]])
	await sim.free_world(w)


# --- The mark, placement, warm-up and data ------------------------------------------------------------

## Its warning mark on the runner's lane: the floor warnings' see-through red, widening over the warning; pulsing as it
## widens, or with Reduced flashing only widening.
func _test_mark() -> void:
	for reduced: bool in [false, true]:
		Settings.flashing_reduced = reduced
		var w: RunWorld = _world(_layout(5), 2)
		w.player.god_mode = true
		var widths: Array[float] = []
		var lane_ok: Array = [true]
		var watch := func(ww: RunWorld) -> void:
			var hh: Hunter = _hunter(ww)
			if hh == null or hh.slash != Hunter.Slash.WARNING or hh.flurries != 1:
				return
			var mark := hh.get(&"_mark") as MeshInstance3D
			widths.append(mark.global_transform.basis.get_scale().x)
			lane_ok[0] = lane_ok[0] and absf(mark.global_position.x - ww.geo.lane_x(hh.slash_lane)) < 0.01
		await _run(w, 10.0, [], watch, func(ww: RunWorld) -> bool:
			var hh: Hunter = _hunter(ww)
			return hh != null and hh.flurries >= 1 and hh.slash == Hunter.Slash.FLURRY)
		var rising: bool = widths.size() > 10
		for i: int in range(1, widths.size()):
			rising = rising and widths[i] >= widths[i - 1] - 0.0001
		var tag: String = "(Reduced flashing %s)" % ("on" if reduced else "off")
		check(widths.size() > 10 and lane_ok[0] and widths[-1] > widths[0] * 1.8, "its mark lies on the lane it warns of, widening %s" % tag)
		if reduced:
			check(rising, "with Reduced flashing it only widens, never pulsing " + tag)
		else:
			check(not rising, "it pulses as it widens " + tag)
		await sim.free_world(w)
	Settings.flashing_reduced = false
	var mat := HunterModel.mark_material() as StandardMaterial3D
	check(mat.emission.r > 0.9 and mat.emission.g < 0.2 and mat.albedo_color.a < 1.0, "its mark is the floor warnings' see-through red")


func _test_placement() -> void:
	var campaign := load(CAMPAIGN_PATH) as Campaign
	var v: float = SPEED
	for lanes: int in LANE_COUNTS:
		var config: LevelConfig = campaign.configure(campaign.step("ice_lab/3"), lanes)
		var tag: String = "(Specimen Vault, %d lanes)" % lanes
		var gen: LevelGenerator = LayoutCache.generator(config, tuning, LevelGenerator.load_for(config))
		v = gen.speed
		var hunters: Array[Dictionary] = HunterRules.hunters_in(gen.layout)
		check(not hunters.is_empty() and HunterRules.problems(gen).is_empty(),
			"%d Hunters, none with a problem (%s) %s" % [hunters.size(), HunterRules.problems(gen), tag])
		var start: float = gen.feature_start(HunterRules.TYPE)
		var prev_end: float = -INF
		for h: Dictionary in hunters:
			var at: float = float(h["at"])
			var baits: Array = (h["params"] as Dictionary).get("baits", [])
			var in_chase: int = 0
			for b: Dictionary in baits:
				var g: Dictionary = gen.layout.gantryway_by_id(int(b["id"]))
				var pillar: float = float(b["at"])
				var hl: int = int(b["lane"]) - int(b["side"])
				if not g.is_empty() and is_equal_approx(float(g["pillar"]), pillar) and hl >= 0 and hl < lanes \
						and pillar >= at + t.bait_after_seconds * v - 0.01 and pillar <= at + (t.chase_seconds - t.bait_before_seconds) * v + 0.01:
					in_chase += 1
			check(at >= start - 0.01 and in_chase >= 1,
				"the Hunter at %.0f m (after its start, %.0f m) has a falling gantryway in its chase to drop on it (%d) %s"
				% [at, start, in_chase, tag])
			check(at >= prev_end, "never two at once: the Hunter at %.0f m comes after the last one's chase and its spacing %s" % [at, tag])
			prev_end = HunterRules.chase_span(gen, t, at).y + t.spacing_seconds * v
		# The same every build.
		var again: LevelLayout = LevelGenerator.new().generate(config, tuning, LevelGenerator.load_for(config))
		check(HunterRules.hunters_in(again) == hunters and again.gantryways.size() == gen.layout.gantryways.size(),
			"the same Hunters every build " + tag)
	# None where the level doesn't list it.
	for id: String in ["ice_lab/1", "ice_lab/2"]:
		var config: LevelConfig = campaign.configure(campaign.step(id), 5)
		var layout: LevelLayout = LayoutCache.generate(config, tuning, LevelGenerator.load_for(config))
		check(HunterRules.hunters_in(layout).is_empty(), "%s has none" % id)


func _test_warm_up() -> void:
	var layout: LevelLayout = _layout(3)
	var w: RunWorld = _world(layout, 1)
	var look: Node = Hunter.warm_up(w, layout.enemies[0])
	var geometry: int = 0
	var physics: int = 0
	var stack: Array[Node] = [look]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is GeometryInstance3D:
			geometry += 1
		if n is CollisionObject3D:
			physics += 1
		stack.append_array(n.get_children())
	check(not look.is_inside_tree() and geometry >= 11 and physics == 0,
		"its warm-up look draws every part, alert too, and its mark (%d), outside the tree, with no physics object" % geometry)
	look.free()
	check(w.director.warm_entries().any(func(e: Dictionary) -> bool: return String(e["type"]) == "hunter"),
		"the director readies it with the level")
	await sim.free_world(w)


func _test_data() -> void:
	check(not LevelConfig.PLANNED_FEATURES.has("hunter") and LayoutChecks.known_feature("hunter"), "it's a built feature, never a planned one")
	var hints: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/hints/hints.json"))
	var hint: bool = false
	for h: Dictionary in (hints as Dictionary).get("hints", []):
		hint = hint or String(h.get("trigger", "")) == "enemy:hunter"
	check(hint, "its first encounter has a hint")
	var campaign := load(CAMPAIGN_PATH) as Campaign
	var config: LevelConfig = campaign.configure(campaign.step("ice_lab/3"), 5)
	check(int(config.feature_ages.get("hunter", -1)) == 0 and config.feature_start("hunter") > 0.15,
		"Specimen Vault introduces it, after its blinking teleporters' start")
	var library := load("res://data/audio/sfx_library.tres") as SfxLibrary
	var missing: PackedStringArray = []
	for sound: StringName in [&"hunter_whine", &"hunter_scrape", &"hunter_slash", &"hunter_give_up", &"hunter_death"]:
		if library.stream(sound) == null or not library.volume_db.has(String(sound)):
			missing.append(String(sound))
	check(missing.is_empty(), "its whine, warning, cuts, giving up and death have sounds (missing %s)" % [missing])
	var scrape: AudioStream = library.stream(&"hunter_scrape")
	check(scrape != null and absf(scrape.get_length() - t.warning_seconds) < 0.05 and float(library.pitch_variation.get("hunter_scrape", 0.0)) == 0.0,
		"its warning's scrape lasts its warning (%.2f s), the same every time" % (scrape.get_length() if scrape != null else 0.0))

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
##     it follows into the walkway's lane and the walkway lands on it (the runner's kill), a late step out (0.8 s after
##     the break) too; and whole encounters at Specimen Vault's own leads, its flurries on (every lead, start lane and
##     push both ways round, and the step-out window: test_hunter_baits);
##   - its body never takes a dodge from another attack: a cyborg's burst at a runner by the edge with it beside them, it
##     drops back so they step into its lane; no flurry while a cyborg's gun is on at them; none in a fenced ceiling's
##     pick, nor into a lane with a trap pad;
##   - weapons (the owner: its staying beside the runner makes it "difficult ... to damage ... with laser attacks"): auto-fire,
##     laser and missiles, never picks it beside the runner, only clearly ahead (target_ahead), and over a whole chase beside
##     a runner auto-firing laser tier 1 it's never picked; 25 laser tier 1 shots (23 health,
##     PowerupTuning.tier1_extra_shots), the other tiers in proportion, a shot that reaches it hitting it and its health bar
##     showing; the claws, a stomp, the dash and other enemies' charges never defeat it;
##   - it steers round a doodad and a standing enemy in its lane, never into the runner's lane;
##   - a runner on a ceiling: a warning on as the pad lifts them is called off, and it waits below, never cutting;
##   - a teleport leaves it behind: it catches up, its time running on; one whose arrival a teleport skips never comes;
##   - it gives up chase_seconds after arriving, whatever it's doing, its whine falling, and leaves play;
##   - it never waits its turn nor holds anyone else's: a big attack of another enemy's on doesn't stop its flurries.
## - Placement (hunter_rules.gd) on Specimen Vault at 3, 5 and 6 lanes: at least one, after its feature's start, each with a
##   falling gantryway in its chase whose Hunter lane is clear, never two at once, each arriving calm (no other attack
##   planned there); the same every build; none where the level doesn't list it.
## - Its warning mark and Reduced flashing; the sweep of its cuts (its cuts' box always inside what's drawn, CLAUDE.md
##   principle 4) and its lunge; its warm-up look (no physics object); its data (the hint, its sounds).

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
	await _test_cut_in()
	await _test_follow()
	await _test_flurry()
	await _test_no_way_out()
	await _test_bait()
	await _test_late_step_out()
	await _test_lineup()
	await _test_bait_cross()
	await _test_campaign_baits()
	await _test_encounter()
	await _test_small_attacks()
	await _test_weapons()
	await _test_laser_chase()
	await _test_contacts()
	await _test_steering()
	await _test_fences()
	await _test_cross_sides()
	await _test_ceiling()
	await _test_fenced_ceiling()
	await _test_teleport()
	await _test_give_up()
	await _test_turns()
	await _test_mark()
	await _test_sweep()
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
## camera's arithmetic), calm (facing ahead), warning or cutting (turned toward the lane it cuts, lunging toward it as it
## cuts) or risen over a full fence (never beside a runner in an edge lane), at 3, 5 and 6 lanes, every runner lane and
## either side (each of its parts as a box round it); it never hides the runner; calm or risen, it hides nothing of the
## floor of their lane and of their other lane (the one they'd step into) from them to 20 m ahead, and warning or cutting
## nothing of their other lane's. Where else it rides near them: _test_view_near.
func _test_view() -> void:
	var m := HunterModel.new()
	tree.root.add_child(m)
	m.build()
	# Its parts' boxes (model space) by its side of the runner and its pose: 0 calm, 1 warning, 2 cutting, 3 calm, risen
	# over a full fence (Hunter._update_lift; it goes round a gapped one, and every fence beside a runner in an edge lane).
	var risen: float = mt.fence_full_top + t.fence_clearance - t.hover_height
	var looks: Dictionary = {}
	for side: int in [-1, 1]:
		for pose: int in 4:
			m.raise = 1.0 if pose == 1 or pose == 2 else 0.0
			m.cut = 0.3 if pose == 2 else -1.0
			m.lean = 0.32 if pose == 2 else 0.0
			m.alert = pose == 1 or pose == 2
			m.hover = t.hover_height + (risen if pose == 3 else 0.0)
			# Cutting, it lunges toward the runner's lane (the lane it cuts: Hunter._place).
			m.reach = 1.0 if pose == 2 else 0.0
			m.reach_dir = float(-side)
			# Warning and cutting, its torso turned back toward the lane it cuts, the runner's (Hunter._place); calm, ahead.
			m.face_yaw = atan2(side * 2.4, -t.alongside_ahead) if pose == 1 or pose == 2 else 0.0
			m.animate(0.0)
			var boxes: Array[AABB] = []
			for mi: MeshInstance3D in m.mesh_nodes():
				boxes.append(mi.global_transform * mi.mesh.get_aabb())
			looks[side * 10 + pose] = boxes
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
				var at := Vector3(geo.lane_x(l), 0.0, TrackGeometry.world_z(d + t.alongside_ahead))
				var tag: String = "%d lanes, runner %d, Hunter %d" % [lanes, r, l]
				var far: int = r - side
				for pose: int in 4:
					if pose == 3 and (r == 0 or r == lanes - 1):
						# Beside a runner in an edge lane it goes round every fence rather than rising (Hunter.blocker_in).
						continue
					var boxes: Array[AABB] = []
					for b: AABB in looks[side * 10 + pose]:
						boxes.append(AABB(b.position + at, b.size))
					for p: Vector3 in EnforcerTruckView.corners(boxes):
						var s: Vector2 = view.screen(p)
						worst = maxf(worst, maxf(absf(s.x), absf(s.y)))
						if not view.on_screen(p):
							faults.append("%s, pose %d: a corner off screen (%s)" % [tag, pose, s])
							break
					for p: Vector3 in EnforcerTruckView.runner_points(mt, geo.lane_x(r), d):
						if view.hidden(boxes, p):
							faults.append("%s, pose %d: it hides the runner" % [tag, pose])
							break
					for lane: int in ([r, far] if pose == 0 or pose == 3 else [far]):
						if lane < 0 or lane >= lanes:
							continue
						for ahead: float in [2.0, 5.0, 10.0, 20.0]:
							if view.hidden(boxes, Vector3(geo.lane_x(lane), 0.05, TrackGeometry.world_z(d + ahead))):
								faults.append("%s, pose %d: it hides lane %d's floor %.0f m ahead" % [tag, pose, lane, ahead])
	check(faults.is_empty(), "beside the runner its whole look is on screen (its furthest corner %.0f%% of the way to the edge), hiding nothing of them or the floor they need (%s)"
		% [worst * 100.0, faults])
	_test_view_near()


## Where else it rides near the runner (task S2's review), through the chase camera's resting view as _test_view: coming
## up or dropping back in a lane beside theirs (calm, facing ahead, from level with them to VIEW_GAP behind), in their way
## behind them (in their lane or crossing it, its disc rolled into the lane change, cross_gap back) and recovering from a
## flurry they dodged (its blades coming down and its lunge easing back, in the lane it held, two lanes from them); it
## hides nothing of the runner or their lane from them to 20 m ahead in any of them.
func _test_view_near() -> void:
	var m := HunterModel.new()
	tree.root.add_child(m)
	m.build()
	var faults: PackedStringArray = []
	var takes: int = 0
	for lanes: int in LANE_COUNTS:
		var geo := TrackGeometry.new(lanes, mt)
		for r: int in lanes:
			var d: float = 300.0
			var view := EnforcerTruckView.of_runner(mt, geo, r, d)
			var hides := func(x: float, gap: float) -> String:
				var at := Vector3(x, 0.0, TrackGeometry.world_z(d - gap))
				var boxes: Array[AABB] = []
				for mi: MeshInstance3D in m.mesh_nodes():
					var b: AABB = mi.global_transform * mi.mesh.get_aabb()
					boxes.append(AABB(b.position + at, b.size))
				for p: Vector3 in EnforcerTruckView.runner_points(mt, geo.lane_x(r), d):
					if view.hidden(boxes, p):
						return "the runner"
				for ahead: float in [2.0, 5.0, 10.0, 20.0]:
					if view.hidden(boxes, Vector3(geo.lane_x(r), 0.05, TrackGeometry.world_z(d + ahead))):
						return "their lane %.0f m ahead" % ahead
				return ""
			var tag: String = "%d lanes, runner %d" % [lanes, r]
			# Calm, level, facing ahead (Hunter._place), bobbing at its highest.
			m.raise = 0.0
			m.cut = -1.0
			m.lean = 0.0
			m.alert = false
			m.reach = 0.0
			m.face_yaw = 0.0
			m.hover = t.hover_height + 0.035
			m.roll = 0.0
			m.animate(0.0)
			# Coming up or dropping back in a lane beside theirs: from level with them to out of view.
			for side: int in [-1, 1]:
				if r + side < 0 or r + side >= lanes:
					continue
				var g: float = -t.alongside_ahead
				while g <= Hunter.VIEW_GAP:
					var what: String = hides.call(geo.lane_x(r + side), g)
					takes += 1
					if what != "":
						faults.append("%s: coming up in lane %d %.2f m back it hides %s" % [tag, r + side, g, what])
						break
					g += 0.25
			# In their way behind them, cross_gap back: in their lane, and crossing it toward either lane beside it, its
			# disc rolled into the lane change either way.
			for step: int in range(-10, 11):
				var x: float = geo.lane_x(r) + geo.lane_width * float(step) / 10.0
				if x < geo.lane_x(0) - 0.01 or x > geo.lane_x(lanes - 1) + 0.01:
					continue
				for roll: float in ([0.0] if step == 0 else [-0.2, 0.0, 0.2]):
					m.roll = roll
					m.animate(0.0)
					var what2: String = hides.call(x, t.cross_gap)
					takes += 1
					if what2 != "":
						faults.append("%s: in their way %.2f m across, %.1f m back, rolled %.1f, it hides %s" % [tag,
							x - geo.lane_x(r), t.cross_gap, roll, what2])
			m.roll = 0.0
			# Recovering from a flurry they dodged one lane away from it: in the lane it held (two lanes from them), its
			# blades coming down and its lunge easing back toward the lane it cut (between them), turned that way or ahead.
			for side: int in [-1, 1]:
				var l: int = r + 2 * side
				if l < 0 or l >= lanes:
					continue
				for k: float in [1.0, 0.6, 0.3]:
					for turned: bool in [true, false]:
						m.raise = k
						m.reach = k
						m.reach_dir = float(-side)
						m.face_yaw = atan2(side * 2.4, -t.alongside_ahead) if turned else 0.0
						m.hover = t.hover_height
						m.animate(0.0)
						var what3: String = hides.call(geo.lane_x(l), -t.alongside_ahead)
						takes += 1
						if what3 != "":
							faults.append("%s: recovering in lane %d (blades %.1f up, %s) it hides %s" % [tag, l, k,
								"turned" if turned else "ahead", what3])
			m.raise = 0.0
			m.reach = 0.0
	m.free()
	check(takes > 1000 and faults.is_empty(),
		"coming up or dropping back beside them, in their way behind them and recovering, it hides nothing of the runner or their lane ahead (%d poses) %s"
		% [takes, faults])


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


## Gaps (metres behind the runner) at which the runner of _test_cut_in steps into its lane as it comes up.
const CUT_IN_GAPS: Array[float] = [6.0, 4.0, 3.0, 2.5, 2.2, 1.8]

## A runner who steps into its lane in front of it as it comes up from behind (in view, CUT_IN_GAPS metres back), and on
## across the track its way, a lane every 0.3 s: it keeps behind them (MIN_GAP_IN_LANE) until it's out of their way, its
## body never meeting theirs, then comes up beside them (5 and 6 lanes, from either edge).
func _test_cut_in() -> void:
	var takes: int = 0
	var met: PackedStringArray = []
	for lanes: int in [5, 6]:
		for start: int in [0, lanes - 1]:
			for at_gap: float in CUT_IN_GAPS:
				var tag: String = "(%d lanes, from lane %d, stepping in %.1f m behind)" % [lanes, start, at_gap]
				var w: RunWorld = _world(_layout(lanes), start)
				w.player.god_mode = true
				_no_flurries(w)
				var steps: Array = [0, 0.0]
				var bot := func(ww: RunWorld) -> void:
					var hh: Hunter = _hunter(ww)
					if hh == null or hh.state != Hunter.State.APPROACH or not hh.visible or ww.level_time() < float(steps[1]):
						return
					if (int(steps[0]) == 0 and hh.gap >= at_gap) or int(steps[0]) >= lanes - 1:
						return
					steps[0] = int(steps[0]) + 1
					steps[1] = ww.level_time() + 0.3
					RunSim.act(ww.player, &"move_right" if start == 0 else &"move_left")
				var r: Dictionary = await _run(w, UP_SECONDS, [], bot, func(ww: RunWorld) -> bool:
					var hh: Hunter = _hunter(ww)
					return int(steps[0]) > 0 and hh != null and hh.state == Hunter.State.ALONGSIDE)
				var h: Hunter = r["hunter"]
				takes += 1
				if not (int(steps[0]) > 0 and bool(r["done"]) and (r["faults"] as PackedStringArray).is_empty() and h != null
						and absf(h.lane - w.player.lane) == 1):
					met.append("%s: %d steps %s" % [tag, steps[0], _brief(r)])
				await sim.free_world(w)
	check(takes == 24 and met.is_empty(),
		"a runner crossing into its lane as it comes up never meets its body, and it comes up beside them (%d takes) %s" % [takes, met])


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
		# Recoveries seen beside the runner, frames of one with its target lane changed from the one it recovers in.
		var held: Array = [0, 0, -1]
		var bot: Callable = _dodger(state)
		var watch := func(ww: RunWorld) -> void:
			bot.call(ww)
			var hh: Hunter = _hunter(ww)
			if hh != null and hh.slash == Hunter.Slash.WARNING:
				marks[0] += 1
				marks[1] += 1 if (hh.get(&"_mark") as MeshInstance3D).visible else 0
			if hh != null and hh.slash == Hunter.Slash.RECOVER and hh.state == Hunter.State.ALONGSIDE:
				if int(held[2]) < 0:
					held[0] += 1
					held[2] = hh.target_lane
				elif hh.target_lane != int(held[2]):
					held[1] += 1
			elif hh != null:
				held[2] = -1
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
		check(int(held[0]) >= warns.size() and int(held[1]) == 0,
			"it holds its lane through each recovery, following only once its blades are down (%d recoveries, %d frames moving) %s"
			% [held[0], held[1], tag])
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
		var r: Dictionary = await _run(w, 21.0)
		var h: Hunter = r["hunter"]
		var warns: Array = _events(r["history"], "warn")
		var inside: int = 0
		var after: int = 0
		var v: float = mt.run_speed
		for wn: Array in warns:
			var d: float = float(wn[0])
			if d + t.attack_seconds() * v + 2.0 >= 150.0 and d + t.escape_reaction_seconds * v <= 400.0:
				inside += 1
			elif d > 150.0:
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


## A late step out (task S2's review: the walkway's own window): the runner steps out from under the falling walkway
## LATE_STEP_OUT seconds after the pillar breaks, still in time; it follows them into the walkway's lane at once, quickly
## (walkway_switch_seconds), and the walkway lands on it (5 lanes, both ways round; every step-out of the window at 3, 5
## and 6 lanes: test_hunter_baits).
const LATE_STEP_OUT: float = 0.8

func _test_late_step_out() -> void:
	var pillar: float = 330.0
	var dashing: float = mt.run_speed + pt.dash_speed_bonus
	for side: int in [-1, 1]:
		var tag: String = "(5 lanes, the walkway over lane 2, stepping out %s)" % ("left" if side < 0 else "right")
		var layout: LevelLayout = _layout(5, {"baits": [{"at": pillar, "lane": 2, "side": side, "id": 0}]})
		_gantryway(layout, 2, pillar, side)
		var w: RunWorld = _world(layout, 2)
		_no_flurries(w)
		var crushed: Array = []
		w.director.enemy_defeated.connect(func(e: Enemy, cause: StringName) -> void:
			if e is Hunter:
				crushed.append(cause))
		var times: Array = [-1.0, -1.0]
		w.track.gantryway_fell.connect(func(_g: Gantryway) -> void: times[0] = w.level_time())
		var quick: Array = [false]
		var bot := func(ww: RunWorld) -> void:
			if times[1] < 0.0 and times[0] >= 0.0 and ww.level_time() - float(times[0]) >= LATE_STEP_OUT - 0.001:
				times[1] = ww.level_time()
				RunSim.act(ww.player, &"move_left" if side < 0 else &"move_right")
			var hh: Hunter = _hunter(ww)
			if hh != null and times[1] >= 0.0:
				quick[0] = quick[0] or is_equal_approx(float(hh.get(&"_switch_seconds")), t.walkway_switch_seconds)
		var r: Dictionary = await _run(w, (pillar + 60.0) / mt.run_speed, [[pillar - 0.5 * pt.dash_duration * dashing, &"dash"]],
			bot, func(_ww: RunWorld) -> bool: return not crushed.is_empty())
		check(times[1] >= 0.0 and bool(r["alive"]) and crushed == [Gantryway.CRUSH_CAUSE] and quick[0],
			"a runner who steps out %.1f s after the pillar breaks lives, and it follows them in at once (in %.2f s) and the walkway lands on it %s %s"
			% [LATE_STEP_OUT, t.walkway_switch_seconds, _brief(r), tag])
		check((r["faults"] as PackedStringArray).is_empty(), "its rules held %s %s" % [r["faults"], tag])
		await sim.free_world(w)


## Lining up a bait from the pillar's push side (5 lanes, the walkway over lane 2 pushing right, the runner in lane 3):
## with the walkway's other side open it comes up on the runner's far side (right), they step left into the walkway's lane
## away from it, dash the pillar and step out left, and it follows them in; with a hole on the other side it comes up on
## the side away from the push, into the walkway's lane itself, keeps out of it over the bait's run-up (one lane further
## out, over the hole), and the runner steps back in, dashes and steps out right, and it follows them in.
func _test_lineup() -> void:
	var pillar: float = 360.0
	var dashing: float = mt.run_speed + pt.dash_speed_bonus
	for other: String in ["open", "hole"]:
		var tag: String = "(the walkway's other side %s)" % other
		var layout: LevelLayout = _layout(5, {"baits": [{"at": pillar, "lane": 2, "side": 1, "id": 0}]})
		_gantryway(layout, 2, pillar, 1)
		if other == "hole":
			layout.gaps.append({"lane": 1, "start": pillar - 5.0, "end": pillar + 45.0})
		var w: RunWorld = _world(layout, 3)
		_no_flurries(w)
		var crushed: Array = []
		w.director.enemy_defeated.connect(func(e: Enemy, cause: StringName) -> void:
			if e is Hunter:
				crushed.append(cause))
		var sides: Array = []
		var run_up_lanes: Array = []
		var watch := func(ww: RunWorld) -> void:
			var hh: Hunter = _hunter(ww)
			if hh == null or hh.state != Hunter.State.ALONGSIDE:
				return
			if sides.is_empty():
				sides.append(hh.side)
			var d: float = ww.player.distance
			if d > pillar - 30.0 and d < pillar - 8.0:
				run_up_lanes.append(hh.lane)
		var into: float = pillar - (80.0 if other == "open" else 45.0)
		var actions: Array = [[into, &"move_left"], [pillar - 0.5 * pt.dash_duration * dashing, &"dash"],
			[pillar + REACTION * dashing, &"move_left" if other == "open" else &"move_right"]]
		var r: Dictionary = await _run(w, (pillar + 60.0) / mt.run_speed, actions, watch, func(_ww: RunWorld) -> bool:
			return not crushed.is_empty())
		var expect_side: int = 1 if other == "open" else -1
		check(sides == [expect_side] and not run_up_lanes.has(2) and bool(r["alive"]) and crushed == [Gantryway.CRUSH_CAUSE],
			"it comes up on the %s, out of the runner's way to the walkway's lane over its run-up (in lanes %s), and the walkway lands on it %s %s"
			% ["runner's far side from it" if other == "open" else "side away from the push", run_up_lanes, _brief(r), tag])
		check((r["faults"] as PackedStringArray).is_empty(), "its rules held %s %s" % [r["faults"], tag])
		await sim.free_world(w)


## A runner by the edge on the wrong side of the Hunter's bait (it can only ride between them and the walkway's lane; task
## S2's review): it comes up and rides beside them, seen (its flurries held: by the edge there's no way out of them, and
## they'd carry them further from that lane), until the pillar is bait_cross_seconds of run ahead; then it drops back out
## of their way, the runner (the bait runner) crosses to the walkway's lane, it comes up on their other side, and the
## walkway lands on it (5 lanes, from either edge, both pushes, leads of 14 and 19.5 s: Specimen Vault's longest).
func _test_bait_cross() -> void:
	var v: float = mt.run_speed
	for lead: float in [14.0, 19.5]:
		for c: Array in [[4, 1], [4, -1], [0, 1], [0, -1]]:
			var start: int = c[0]
			var push: int = c[1]
			var tag: String = "(5 lanes, lead %.1f s, the runner in lane %d, the walkway over lane 2 pushing %+d)" % [lead, start, push]
			var pillar: float = ARRIVE + lead * v
			var layout: LevelLayout = _layout(5, {"baits": [{"at": pillar, "lane": 2, "side": push, "id": 0}]})
			_gantryway(layout, 2, pillar, push)
			var w: RunWorld = _world(layout, start)
			var crushed: Array = []
			w.director.enemy_defeated.connect(func(e: Enemy, cause: StringName) -> void:
				if e is Hunter:
					crushed.append(cause))
			var state: Dictionary = {"pillar": pillar, "lane": 2}
			w.track.gantryway_fell.connect(func(_g: Gantryway) -> void: state["broke"] = w.level_time())
			var runner: Callable = _bait_runner(state)
			var counts: Array = [0, 0, 0, false]  # frames before the crossing window since it came up: all, beside, unseen
			var watch := func(ww: RunWorld) -> void:
				runner.call(ww)
				var hh: Hunter = _hunter(ww)
				if hh == null:
					return
				counts[3] = bool(counts[3]) or hh.state == Hunter.State.ALONGSIDE
				if bool(counts[3]) and ww.player.distance < pillar - (t.bait_cross_seconds + 0.3) * v:
					counts[0] += 1
					counts[1] += 1 if hh.state == Hunter.State.ALONGSIDE else 0
					counts[2] += 1 if hh.gap > Hunter.VIEW_GAP else 0
			var r: Dictionary = await _run(w, (pillar + 60.0) / v, [], watch, func(_ww: RunWorld) -> bool:
				return not crushed.is_empty())
			check(int(counts[0]) > 60 and int(counts[1]) >= int(counts[0]) * 0.9 and int(counts[2]) == 0,
				"before the pillar is near it rides beside the runner, seen (%d of %d frames beside, %d unseen) %s"
				% [counts[1], counts[0], counts[2], tag])
			check(bool(r["alive"]) and crushed == [Gantryway.CRUSH_CAUSE] and _events(r["history"], "warn").is_empty(),
				"then it lets them cross to the walkway's lane, comes up on their other side, and the walkway lands on it %s %s"
				% [_brief(r), tag])
			check((r["faults"] as PackedStringArray).is_empty(), "its rules held %s %s" % [r["faults"], tag])
			await sim.free_world(w)


## Every bait of Specimen Vault's Hunters at 3, 5 and 6 lanes, on real physics at the level's speed, on a cut of the level
## around it (_cut): the runner in the walkway's lane, its flurries held off, it comes up beside them away from the push;
## they dash the pillar and step out to the push side a reaction later, it follows them into the walkway's lane, and the
## walkway lands on it (and on the cyborg planted under it), the runner running on.
func _test_campaign_baits() -> void:
	var campaign := load(CAMPAIGN_PATH) as Campaign
	var takes: int = 0
	for lanes: int in LANE_COUNTS:
		var config: LevelConfig = campaign.configure(campaign.step("ice_lab/3"), lanes)
		var gen: LevelGenerator = LayoutCache.generator(config, tuning, LevelGenerator.load_for(config))
		for h: Dictionary in HunterRules.hunters_in(gen.layout):
			for b: Dictionary in (h["params"] as Dictionary).get("baits", []):
				var g: Dictionary = gen.layout.gantryway_by_id(int(b["id"]))
				if g.is_empty():
					check(false, "the bait at %.0f m is a gantryway of the level (%d lanes)" % [float(b["at"]), lanes])
					continue
				var tag: String = "(Specimen Vault, %d lanes, the Hunter at %.0f m, its bait at %.0f m over lane %d pushing %s)" % [
					lanes, float(h["at"]), float(g["pillar"]), int(g["lane"]), "left" if int(g["side"]) < 0 else "right"]
				var r: Dictionary = await _campaign_take(gen, g)
				check(bool(r["alive"]) and r["crushed"] == [Gantryway.CRUSH_CAUSE] and int(r["side"]) == -int(g["side"]),
					"it comes up away from the push, follows the runner who dashes the pillar and steps out into the walkway's lane, and it lands on it %s %s"
					% [_brief(r), tag])
				check((r["faults"] as PackedStringArray).is_empty(), "its rules held %s %s" % [r["faults"], tag])
				takes += 1
	check(takes >= 4, "Specimen Vault's baits were taken (%d)" % takes)


## One take of _test_campaign_baits on a cut of `gen`'s level around gantryway `g` (_cut), its pillar moved to 9 s of run
## from the start, the Hunter arriving at ARRIVE.
func _campaign_take(gen: LevelGenerator, g: Dictionary) -> Dictionary:
	var lmt: MovementTuning = gen.tuning
	var pillar: float = float(g["pillar"])
	var front: float = 9.0 * lmt.run_speed
	var offset: float = front - pillar
	var lane: int = int(g["lane"])
	var side: int = int(g["side"])
	var part: LevelLayout = _cut(gen, g, HunterRules.hunter_lane_window(gen, t, pillar).x - 5.0, float((g["calm"] as Array)[1]), offset)
	part.enemies.append({"type": "hunter", "at": ARRIVE, "lane": 0, "side": 0, "seed": 7,
		"params": {"baits": [{"at": front, "lane": lane, "side": side, "id": int(g["id"])}]}})
	var w: RunWorld = sim.build_world(part, Loadout.new(), lmt, LevelConfig.new())
	w.player.setup(w.tuning, w.geo, lane)
	w.player.armor_state.carried = false
	_no_flurries(w)
	var crushed: Array = []
	w.director.enemy_defeated.connect(func(e: Enemy, cause: StringName) -> void:
		if e is Hunter:
			crushed.append(cause))
	var sides: Array = [0]
	var watch := func(ww: RunWorld) -> void:
		var hh: Hunter = _hunter(ww)
		if hh != null and hh.state == Hunter.State.ALONGSIDE and sides[0] == 0:
			sides[0] = hh.side
	var dashing: float = lmt.run_speed + pt.dash_speed_bonus
	var actions: Array = [[front - 0.5 * pt.dash_duration * dashing, &"dash"],
		[front + REACTION * dashing, &"move_left" if side < 0 else &"move_right"]]
	var r: Dictionary = await _run(w, (front + 70.0) / lmt.run_speed, actions, watch, func(ww: RunWorld) -> bool:
		return not crushed.is_empty() and ww.player.distance > front + 40.0)
	r["crushed"] = crushed
	r["side"] = sides[0]
	await sim.free_world(w)
	return r


## A plain track holding the pieces of `gen`'s level (its gaps, fences, pads, speed pads and doodads, its pillar among
## them) that reach into gantryway `g`'s Hunter lane (the lane beside it away from the push) from `from` to `to`, and into
## the lanes the runner takes (its walkway's lane and the push side's) from its pillar's front to `to` (the runner gets to
## the pillar on their own: test_gantryways runs the level's way to it), moved on by `offset`; the gantryway itself, and
## the cyborg planted under it (holding its fire as it does there), as test_gantryways cuts a level.
func _cut(gen: LevelGenerator, g: Dictionary, from: float, to: float, offset: float) -> LevelLayout:
	var layout: LevelLayout = gen.layout
	var lane: int = int(g["lane"])
	var side: int = int(g["side"])
	var part := RunSim.layout(layout.lane_count, to + offset + 160.0)
	var lists: Dictionary = layout.to_dict()
	var into: Dictionary = part.to_dict()
	var extent: Dictionary = {"fences": gen.tuning.fence_depth * 0.5, "pads": gen.tuning.pad_length,
		"speed_pads": gen.tuning.speed_pad_length}
	for key: String in ["gaps", "fences", "pads", "speed_pads", "doodads"]:
		for item: Dictionary in lists.get(key, []):
			var l: int = int(item.get("lane", -9))
			if l != lane and l != lane + side and l != lane - side:
				continue
			var start: float = float(item.get("start", item.get("at", 0.0)))
			var end: float = float(item["end"]) if item.has("end") else start + float(extent.get(key, 0.0))
			if key == "fences":
				start -= float(extent["fences"])
			var lo: float = from if l == lane - side else float(g["pillar"]) - 0.5
			if end < lo or start > to:
				continue
			var moved: Dictionary = _moved(item, offset)
			if key == "doodads":
				part.doodads.append(moved)
			else:
				(into[key] as Array).append(moved)
	part.gantryways.append(_moved(g, offset))
	var c: Dictionary = GantrywayRules.planted_under(layout, g)
	if not c.is_empty():
		var moved: Dictionary = _moved(c, offset)
		var params: Dictionary = (c["params"] as Dictionary).duplicate()
		params["hold_fire"] = (params["hold_fire"] as Vector2) + Vector2(offset, offset)
		moved["params"] = params
		part.enemies.append(moved)
	return part


## A copy of layout entry `item` moved on by `offset` along the track (test_gantryways' _moved).
static func _moved(item: Dictionary, offset: float) -> Dictionary:
	var moved: Dictionary = item.duplicate()
	for k: String in ["at", "start", "end", "pillar"]:
		if moved.has(k):
			moved[k] = float(moved[k]) + offset
	for k: String in ["row", "calm"]:
		if moved.has(k):
			var stretch: Array = moved[k]
			moved[k] = [float(stretch[0]) + offset, float(stretch[1]) + offset]
	return moved


## Whole encounters at Specimen Vault's own leads (task S2's review): every bait of the campaign's builds at 3, 5 and 6
## lanes, from its Hunter's arrival to its pillar, on a plain track, its flurries on; the runner starts in the lane its
## Hunter rides in at the bait (beside the walkway's lane away from the push) and plays the bait as the bait runner
## (_bait_runner); the walkway lands on it, the runner alive. Every lead, start lane and push: test_hunter_baits.
func _test_encounter() -> void:
	var campaign := load(CAMPAIGN_PATH) as Campaign
	var takes: int = 0
	var flurries: int = 0
	for lanes: int in LANE_COUNTS:
		var config: LevelConfig = campaign.configure(campaign.step("ice_lab/3"), lanes)
		var gen: LevelGenerator = LayoutCache.generator(config, tuning, LevelGenerator.load_for(config))
		for h: Dictionary in HunterRules.hunters_in(gen.layout):
			for b: Dictionary in (h["params"] as Dictionary).get("baits", []):
				var lead: float = (float(b["at"]) - float(h["at"])) / gen.speed
				var lane: int = int(b["lane"])
				var side: int = int(b["side"])
				var pillar: float = ARRIVE + lead * mt.run_speed
				var tag: String = "(Specimen Vault, %d lanes: its bait %.1f s of run after it arrives, over lane %d pushing %s)" % [
					lanes, lead, lane, "left" if side < 0 else "right"]
				var layout: LevelLayout = _layout(lanes, {"baits": [{"at": pillar, "lane": lane, "side": side, "id": 0}]})
				layout.enemies[0]["seed"] = int(h.get("seed", 7))
				_gantryway(layout, lane, pillar, side)
				var w: RunWorld = _world(layout, lane - side)
				var crushed: Array = []
				w.director.enemy_defeated.connect(func(e: Enemy, cause: StringName) -> void:
					if e is Hunter:
						crushed.append(cause))
				var state: Dictionary = {"pillar": pillar, "lane": lane}
				w.track.gantryway_fell.connect(func(_g: Gantryway) -> void: state["broke"] = w.level_time())
				var r: Dictionary = await _run(w, (pillar + 60.0) / mt.run_speed, [], _bait_runner(state), func(_ww: RunWorld) -> bool:
					return not crushed.is_empty())
				var warns: int = _events(r["history"], "warn").size()
				flurries += warns
				check(bool(r["alive"]) and crushed == [Gantryway.CRUSH_CAUSE],
					"a whole encounter: %d flurries dodged, the walkway's lane taken, the pillar dashed and the step out, and the walkway lands on it %s %s"
					% [warns, _brief(r), tag])
				check((r["faults"] as PackedStringArray).is_empty(), "its rules held through the encounter %s %s" % [r["faults"], tag])
				takes += 1
				await sim.free_world(w)
	check(takes >= 4 and flurries >= 1, "Specimen Vault's encounters were played (%d, %d flurries on the way)" % [takes, flurries])


## The bait runner (test_hunter_baits' and the review's probe), its state in `state` (pillar; lane: the walkway's): one
## lane away from the Hunter a reaction into each warning; the walkway's lane once the pillar is 5 s of run ahead (in
## sight), a lane at a time 0.3 s apart at most, never during a flurry; the pillar dashed; out from under the walkway away
## from the Hunter a reaction after it breaks.
func _bait_runner(state: Dictionary) -> Callable:
	var dashing: float = mt.run_speed + pt.dash_speed_bonus
	return func(w: RunWorld) -> void:
		var p: Player = w.player
		var h: Hunter = _hunter(w)
		if h == null or not h.alive:
			return
		var pillar: float = float(state["pillar"])
		var lane: int = int(state["lane"])
		var away: StringName = &"move_left" if h.side > 0 else &"move_right"
		if h.slash == Hunter.Slash.WARNING and int(state.get("dodged", 0)) != h.flurries and float(h.get(&"_slash_t")) >= REACTION:
			state["dodged"] = h.flurries
			RunSim.act(p, away)
			return
		if float(state.get("broke", -1.0)) >= 0.0:
			if not bool(state.get("out", false)) and w.level_time() - float(state["broke"]) >= REACTION:
				state["out"] = true
				RunSim.act(p, away)
			return
		var in_sight: bool = p.distance >= pillar - 5.0 * mt.run_speed and p.distance < pillar
		if in_sight and h.slash == Hunter.Slash.IDLE and p.lane != lane and w.level_time() >= float(state.get("next_move", 0.0)):
			state["next_move"] = w.level_time() + 0.3
			RunSim.act(p, &"move_right" if p.lane < lane else &"move_left")
		if not bool(state.get("dashed", false)) and p.lane == lane and p.distance >= pillar - 0.5 * pt.dash_duration * dashing:
			state["dashed"] = true
			RunSim.act(p, &"dash")


# --- Other enemies' attacks -------------------------------------------------------------------------

## Its body never takes a dodge from another attack (task S2's review), on a cyborg's burst (CyborgGun: every gun built on
## it, the window cyborg's, the barnacle turret's, the Heavy Cyborg's gatling, counts the same):
## - a runner by the edge with it beside them (its lane their only other lane): as the cyborg's gun charges it drops back
##   out of that lane (making room), and the runner steps into it as the burst flies and lives, never bumped; it comes up
##   beside them again after; the same take without it lives too;
## - no flurry starts while a cyborg's gun is charging or firing at the runner (one dodge can't answer both).
func _test_small_attacks() -> void:
	for with_hunter: bool in [true, false]:
		var tag: String = "(5 lanes, the runner in lane 4, %s)" % ("it beside them" if with_hunter else "no Hunter")
		var layout := RunSim.layout(5, 1600.0)
		if with_hunter:
			layout.enemies.append({"type": "hunter", "at": ARRIVE, "lane": 0, "side": 0, "seed": 7, "params": {}})
		layout.enemies.append({"type": "cyborg", "at": 330.0, "lane": 2, "side": 0, "seed": 21,
			"params": {"stand": true, "fires": true, "panic": false, "host": false}})
		var w: RunWorld = _world(layout, 4)
		_no_flurries(w)
		# [dodged, the Hunter beside them as the gun began to charge, its lane as they dodged, its furthest gap making room]
		var seen: Array = [false, false, -1, 0.0]
		var bot := func(ww: RunWorld) -> void:
			var hh: Hunter = _hunter(ww)
			if hh != null and hh.state == Hunter.State.YIELD:
				seen[3] = maxf(float(seen[3]), hh.gap)
			var cy: Cyborg = null
			for e: Variant in ww.director.active:
				if is_instance_valid(e) and e is Cyborg:
					cy = e as Cyborg
			if cy == null or seen[0]:
				return
			if cy.gun.state == CyborgGun.State.CHARGING and not seen[1]:
				seen[1] = hh != null and hh.state == Hunter.State.ALONGSIDE and hh.lane == 3
			if cy.gun.state == CyborgGun.State.FIRING:
				seen[0] = true
				seen[2] = hh.lane if hh != null and hh.gap < t.blocker_length else -1
				RunSim.act(ww.player, &"move_left")
		var r: Dictionary = await _run(w, 420.0 / mt.run_speed, [], bot)
		var bumped: bool = (r["events"] as Array).any(func(e: Array) -> bool: return e[0] == &"lane_blocked")
		check(bool(seen[0]) and bool(r["alive"]) and not bumped and w.player.lane == 3,
			"a runner by the edge steps one lane over from a cyborg's burst and lives, never bumped %s %s" % [_brief(r), tag])
		if with_hunter:
			var room: Array = _events(r["history"], "yield:make_room")
			check(bool(seen[1]) and not room.is_empty() and int(seen[2]) != 3 and _events(r["history"], "alongside").size() >= 2
				and float(seen[3]) <= t.cross_gap + 0.1,
				"beside them as the cyborg's gun charges, it drops back out of the lane they need (%s), only %.1f m (still in view), and comes up again after %s %s"
				% [room, seen[3], _brief(r), tag])
		await sim.free_world(w)
	# No flurry while a cyborg's gun is on at the runner: its next flurry falls due as the gun begins to charge; it waits
	# until the gun's burst is over (charging, firing and its bolts gone by), then warns.
	var layout2 := _layout(5)
	layout2.enemies.append({"type": "cyborg", "at": 330.0, "lane": 0, "side": 0, "seed": 21,
		"params": {"stand": true, "fires": true, "panic": false, "host": false}})
	var w2: RunWorld = _world(layout2, 2)
	w2.player.god_mode = true
	_no_flurries(w2)
	var marks: Array = [-1.0, -1.0, -1.0]  # level times: due (the gun began to charge), the gun off again, the warning
	var watch := func(ww: RunWorld) -> void:
		var hh: Hunter = _hunter(ww)
		var cy: Cyborg = null
		for e: Variant in ww.director.active:
			if is_instance_valid(e) and e is Cyborg:
				cy = e as Cyborg
		if hh == null or cy == null:
			return
		var on: bool = cy.alive and cy.gun.is_attacking()
		if marks[0] < 0.0 and on and cy.gun.state == CyborgGun.State.CHARGING and hh.state == Hunter.State.ALONGSIDE \
				and hh.slash == Hunter.Slash.IDLE:
			marks[0] = ww.level_time()
			hh.set(&"_next_slash", hh.chase_time)
		if marks[0] >= 0.0 and marks[1] < 0.0 and not on:
			marks[1] = ww.level_time()
		if marks[0] >= 0.0 and marks[2] < 0.0 and hh.slash == Hunter.Slash.WARNING:
			marks[2] = ww.level_time()
	var r2: Dictionary = await _run(w2, 560.0 / mt.run_speed, [], watch, func(_ww: RunWorld) -> bool: return marks[2] >= 0.0)
	check(marks[0] >= 0.0 and marks[1] > marks[0] and marks[2] >= marks[1],
		"no flurry starts while a cyborg's gun is on at the runner: one due as it begins to charge waits for its burst (due %.2f s, the gun off %.2f s, the warning %.2f s) %s"
		% [marks[0], marks[1], marks[2], _brief(r2)])
	await sim.free_world(w2)


# --- Weapons and contacts -------------------------------------------------------------------------

## GDD §9.17 (the owner): staying at the runner's side makes it "difficult for the player to damage it with dashes or with
## laser attacks": auto-fire, the laser and the missiles alike, never picks it beside the runner, only clearly ahead of
## them (target_ahead). Its health: 25 laser tier 1 shots (GDD §8, the owner: "25 for now"): 24 leave it going, the 25th
## destroys it; the other tiers and the missiles in proportion (23 health over their plain damage). A shot that reaches it
## hits it, and it shows a health bar once hurt.
func _test_weapons() -> void:
	var loadout := Loadout.new()
	loadout.tiers[&"weapon"] = 1
	var w: RunWorld = _world(_layout(3), 1, loadout)
	w.player.god_mode = true
	_no_flurries(w)
	var c := w.powerups as PowerupController
	if c == null or c.weapon == null:
		check(false, "a runner with the laser")
		await sim.free_world(w)
		return
	# Auto-fire held (its cooldown never runs out): this take fires its own shots.
	c.weapon.set(&"_cooldown", 1.0e9)
	var r: Dictionary = await _until_alongside(w)
	var h: Hunter = r["hunter"]
	if h == null:
		check(false, "a Hunter beside a runner with the laser")
		await sim.free_world(w)
		return
	var picks: Array = []
	for tier: int in [1, 2, 3, 4]:
		c.weapon.tier = tier
		picks.append(c.weapon.pick_target())
	check(not h.targetable() and picks == [null, null, null, null] and is_equal_approx(h.health, h.max_health),
		"beside the runner auto-fire never picks it, the laser nor the missiles (%s)" % [picks])
	# Clearly ahead of the runner it's a target like any other.
	var beside: float = h.gap
	for ahead: float in [t.target_ahead - 0.5, t.target_ahead + 2.0]:
		h.gap = -ahead
		h.call(&"_place", 0.0)
		picks.clear()
		for tier: int in [1, 4]:
			c.weapon.tier = tier
			picks.append(c.weapon.pick_target())
		var wanted: bool = ahead >= t.target_ahead
		check(h.targetable() == wanted and picks == ([h, h] if wanted else [null, null]),
			"%.1f m ahead of the runner auto-fire %s it" % [ahead, "picks" if wanted else "still doesn't pick"])
	h.gap = beside
	h.call(&"_place", 0.0)
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
	var dmg: float = c.weapon.damage(h)
	var hits: Array[int] = [0]
	w.projectiles.enemy_hit.connect(func(e: Enemy, _d: float, _s: bool) -> void:
		if e == h:
			hits[0] += 1)
	var from: Vector3 = w.player.position + Vector3(0.0, 1.0, 0.0)
	w.projectiles.fire_player(from, (h.aim_point() - from).normalized() * 90.0 + Vector3(0.0, 0.0, -w.player.speed), dmg, &"laser")
	await physics_frames(8)
	check(hits[0] == 1 and EnemyHealthBars.wants_bar(h), "a laser shot hits it, and it shows a health bar")
	for i: int in 23:
		h.take_damage(dmg, &"weapon")
	check(h.alive, "24 laser tier 1 hits don't stop it (that shot and 23 more)")
	h.take_damage(dmg, &"weapon")
	check(not h.alive and h.state == Hunter.State.DEAD and h.sounds_played.any(func(s: Array) -> bool: return s[0] == &"hunter_death"),
		"the 25th destroys it, in its death's crunch and blast")
	await sim.free_world(w)


## A whole chase beside a runner auto-firing laser tier 1 (god mode, standing still in their lane), standing cyborgs ahead
## in the lanes on their other side to shoot at: auto-fire never picks the Hunter, and it gives up alive and whole. Prints
## what the laser did meanwhile (the stray shots that reach it are counted, none expected).
func _test_laser_chase() -> void:
	var loadout := Loadout.new()
	loadout.tiers[&"weapon"] = 1
	var layout: LevelLayout = _layout(5, {"baits": [{"at": 560.0, "lane": 2, "side": 1, "id": 0}]})
	for k: int in 8:
		layout.enemies.append({"type": "cyborg", "at": 200.0 + 60.0 * k, "lane": 3 + k % 2, "side": 0, "seed": 20 + k,
			"params": {"stand": true, "fires": false, "panic": false, "host": false}})
	var w: RunWorld = _world(layout, 2, loadout)
	w.player.god_mode = true
	var c := w.powerups as PowerupController
	var fired: Array[int] = [0, 0]
	var hits: Array[int] = [0]
	c.fired.connect(func(_tier: int) -> void:
		fired[0] += 1
		fired[1] += 1 if c.weapon.last_target is Hunter else 0)
	w.projectiles.enemy_hit.connect(func(e: Enemy, _d: float, _s: bool) -> void:
		hits[0] += 1 if e is Hunter else 0)
	var health: Array[float] = [-1.0, -1.0]
	var r: Dictionary = await _run(w, t.chase_seconds + 8.0, [], Callable(), func(ww: RunWorld) -> bool:
		var hh: Hunter = _hunter(ww)
		if hh != null and hh.alive:
			health[0] = hh.health
			health[1] = hh.max_health
		return hh != null and hh.state == Hunter.State.LEAVING)
	var h: Hunter = r["hunter"]
	var kills: int = w.score.kills
	check(bool(r["done"]) and h != null and h.alive and fired[0] >= 8 and fired[1] == 0 and hits[0] == 0
		and is_equal_approx(health[0], health[1]),
		"over a whole chase beside a runner auto-firing laser tier 1 it's never picked and gives up whole (%d shots, %d at it, %d hits on it) %s"
		% [fired[0], fired[1], hits[0], _brief(r)])
	print("  laser tier 1 over a whole chase (%.0f s): %d shots fired, %d kills ahead, %d at the Hunter, %d hits on it, its health %.1f of %.1f"
		% [t.chase_seconds, fired[0], kills, fired[1], hits[0], health[0], health[1]])
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
		var lost: Array = [0]
		w.director.enemy_defeated.connect(func(e: Enemy, _cause: StringName) -> void:
			lost[0] += 1 if e.type_id == &"cyborg" else 0)
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
		var stood: bool = lost[0] == 0
		check(h != null and meets[0] == 0 and not lanes_by.is_empty() and not lanes_by.has(1) and not lanes_by.has(2) and stood
			and h.state == Hunter.State.ALONGSIDE and h.lane == 1,
			"it goes round a %s in its lane (in lane %s there), never into the runner's, and comes back beside them (%s in lane %d; it stands: %s) %s"
			% [what, lanes_by, Hunter.STATE_NAMES[h.state] if h != null else "-", h.lane if h != null else -1, stood, _brief(r)])
		check((r["faults"] as PackedStringArray).is_empty(), "its rules held (a %s) %s" % [what, r["faults"]])
		await sim.free_world(w)


## A hover disc, it rises over a full fence in its lane rather than going round it or dropping back (task S2's review,
## more of its chase beside the runner): its disc's underside clears the fence's top by fence_clearance whenever its body
## is over one, and it settles back after; it rides beside the runner all the while; and it's never risen while its sweep
## shows or its cuts are live (its flurries on). A gapped fence (2.1 m tall) it goes round, never rising beside them.
func _test_fences() -> void:
	var layout: LevelLayout = _layout(5)
	for at: float in [260.0, 380.0, 470.0, 560.0]:
		for l: int in [1, 3]:
			layout.fences.append({"lane": l, "at": at, "variant": "full", "pulsing": false, "pulse_on": 0.0, "pulse_off": 0.0,
				"phase": 0.0})
	var w: RunWorld = _world(layout, 2)
	w.player.god_mode = true
	var counts: Array = [0, 0, 0, 0, 0.0]  # frames over a fence, too low there, risen with its sweep or cuts on, beside, top lift
	var watch := func(ww: RunWorld) -> void:
		var hh: Hunter = _hunter(ww)
		if hh == null or not hh.visible:
			return
		counts[3] += 1 if hh.state == Hunter.State.ALONGSIDE else 0
		counts[4] = maxf(float(counts[4]), hh.lift)
		var mid: float = ww.player_distance() - hh.gap
		for f: Dictionary in ww.layout.fences:
			if int(f["lane"]) != hh.lane or absf(mid - float(f["at"])) > HunterModel.DISC_RADIUS + mt.fence_depth * 0.5:
				continue
			var top: float = mt.fence_gapped_top if String(f["variant"]) == "gapped" else mt.fence_full_top
			counts[0] += 1
			counts[1] += 1 if t.hover_height + hh.lift < top + t.fence_clearance - 0.02 else 0
		if (hh.is_cutting() or not hh.slash_fan().is_empty()) and hh.lift > 0.001:
			counts[2] += 1
	var r: Dictionary = await _until_alongside(w)
	counts[3] = 0
	# On past the last fence, short of its giving up.
	var run: float = 610.0 - w.player.distance
	r = await _run(w, run / mt.run_speed, [], watch)
	var names: Array = (r["history"] as Array).map(func(e: Array) -> String: return String(e[0]))
	var off: Array = names.filter(func(n: String) -> bool: return n.begins_with("yield") or n.begins_with("switch") or n == "steer")
	var frames: int = int(run / mt.run_speed * Engine.physics_ticks_per_second)
	check(int(counts[0]) > 12 and int(counts[1]) == 0 and off.is_empty() and int(counts[3]) > frames * 0.95
		and float(counts[4]) >= mt.fence_full_top + t.fence_clearance - t.hover_height - 0.01,
		"it rises over the full fences in its lane (%d frames over one, %d too low; up to %.2f m), beside the runner all the while (%d of %d frames), never going round nor dropping back %s"
		% [counts[0], counts[1], counts[4], counts[3], frames, off])
	check(int(counts[2]) == 0 and names.count("warn") >= 3,
		"it's never risen while its sweep shows or its cuts are live (%d frames), and its flurries still come (%d)" % [counts[2],
		names.count("warn")])
	check((r["faults"] as PackedStringArray).is_empty(), "its rules held (fences) %s" % [r["faults"]])
	await sim.free_world(w)
	# A gapped fence (in both lanes beside the runner): it goes round it, in the lane further out, never risen beside them.
	layout = _layout(5)
	for l: int in [1, 3]:
		layout.fences.append({"lane": l, "at": 300.0, "variant": "gapped", "pulsing": false, "pulse_on": 0.0, "pulse_off": 0.0,
			"phase": 0.0})
	w = _world(layout, 2)
	w.player.god_mode = true
	_no_flurries(w)
	var risen_beside: Array = [0.0, -1]
	var watch2 := func(ww: RunWorld) -> void:
		var hh: Hunter = _hunter(ww)
		if hh == null or not hh.visible:
			return
		if hh.state == Hunter.State.ALONGSIDE and absf(hh.lane - ww.player.lane) == 1:
			risen_beside[0] = maxf(float(risen_beside[0]), hh.lift)
		var mid: float = ww.player_distance() - hh.gap
		if absf(mid - 300.0) < 1.0:
			risen_beside[1] = hh.lane
	r = await _run(w, 360.0 / mt.run_speed, [], watch2)
	check(float(risen_beside[0]) < 0.01 and (int(risen_beside[1]) == 0 or int(risen_beside[1]) == 4)
		and _events(r["history"], "steer").size() >= 1,
		"a gapped fence it goes round in the lane further out (in lane %d there), never risen beside the runner (%.2f m) %s"
		% [risen_beside[1], risen_beside[0], _brief(r)])
	await sim.free_world(w)


## Its lane shut ahead by something it can't rise over (a zone doodad), with no lane further out (by the edge), it crosses
## to the runner's other side rather than making room (task S2's review): it drops back, crosses their lane at least
## MIN_GAP_IN_LANE behind them, its body never meeting theirs, and comes up beside them on their other side, its whine
## rising again; where they need that lane (a doodad in their own lane too), it makes room instead.
func _test_cross_sides() -> void:
	for needs: bool in [false, true]:
		var tag: String = "(the runner %s their other lane)" % ("needing" if needs else "not needing")
		var layout: LevelLayout = _layout(5)
		var box: Vector3 = mt.doodad_size(&"medium")
		# The runner in lane 1: it comes up on their left (lane 0, toward the nearer edge), the doodad there.
		layout.doodads.append({"lane": 0, "start": 300.0, "end": 300.0 + box.z, "size": &"medium", "side": 1, "seed": 3})
		if needs:
			layout.doodads.append({"lane": 1, "start": 306.0, "end": 306.0 + box.z, "size": &"medium", "side": 1, "seed": 4})
		var w: RunWorld = _world(layout, 1)
		w.player.god_mode = true
		_no_flurries(w)
		var up: Dictionary = await _until_alongside(w)
		var first_side: int = (up["hunter"] as Hunter).side if up["hunter"] != null else 0
		var crossing: Array = [INF]
		var watch := func(ww: RunWorld) -> void:
			var hh: Hunter = _hunter(ww)
			if hh != null and hh.state == Hunter.State.SWITCH \
					and absf(hh.global_position.x - ww.geo.lane_x(ww.player.lane)) < 0.3:
				crossing[0] = minf(float(crossing[0]), hh.gap)
		var r: Dictionary = await _run(w, (360.0 - w.player.distance) / mt.run_speed, [], watch)
		var h: Hunter = r["hunter"]
		var whines: int = (r["sounds"] as Array).filter(func(s: Array) -> bool: return s[0] == &"hunter_whine").size()
		if not needs:
			check(first_side == -1 and h != null and _events(r["history"], "switch:blocked").size() == 1
				and _events(r["history"], "yield:blocked").is_empty() and h.side == 1 and h.lane == w.player.lane + 1
				and h.state == Hunter.State.ALONGSIDE and float(crossing[0]) >= t.cross_gap - 0.05 and whines >= 2,
				"it crosses to the runner's other side %.2f m behind them and comes up there, its whine rising %s %s"
				% [crossing[0], _brief(r), tag])
		else:
			check(first_side == -1 and h != null and _events(r["history"], "switch:blocked").is_empty()
				and _events(r["history"], "yield:blocked").size() >= 1,
				"it makes room rather than crossing into the lane the runner needs %s %s" % [_brief(r), tag])
		check((r["faults"] as PackedStringArray).is_empty(), "its rules held (crossing) %s %s" % [r["faults"], tag])
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
	# Its first flurry is the one forced just before the pad (below): it's idle then; its flurries come as ever after.
	_no_flurries(w)
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
	check(forced[0] and not warns.is_empty() and not called.is_empty() and float(called[0][0]) >= pad - 1.0
		and float(called[0][0]) < pad + 3.0 and warns.any(func(e: Array) -> bool: return float(e[0]) < pad and float(e[0]) > pad - 0.5 * mt.run_speed)
		and _events(r["history"], "cut").filter(func(e: Array) -> bool: return float(e[0]) > pad - 1.0 and float(e[0]) < hull_end).is_empty(),
		"a warning on as the pad lifts the runner is called off, no cut follows %s" % _brief(r))
	check(below[0] > 60 and below[1] == below[0] and on_ceiling.is_empty(),
		"on the ceiling it waits below beside them (%d of %d frames), never warning" % [below[1], below[0]])
	check(not later.is_empty(), "back on the floor it slashes again")
	check((r["faults"] as PackedStringArray).is_empty(), "its rules held (a ceiling) %s" % [r["faults"]])
	await sim.free_world(w)


## A fenced ceiling (task S2's review): no flurry plays out in its pick (where the runner reads which pad is the trap,
## LevelLayout.fenced_pick_between, as a heli drone's barrage), whether its trap pad lies in the lane their dodge would
## take or not, flurries again once it's passed, the runner (dodging each) alive; and a lane with a trap pad is never
## open to step into (lane_open): a pad marked unsafe, or any pad under a ceiling with a fence in its lane ahead of it,
## while a safe pad past the fences, or no pad, leaves the lane open.
func _test_fenced_ceiling() -> void:
	var lanes: int = 5
	var pad: float = 300.0
	var pick := Vector2(pad - 25.0, pad + 5.0)
	var reach: float = t.attack_seconds() * mt.run_speed + 2.0
	for trap_lane: int in [2, 3]:
		var tag: String = "(the trap pad in lane %d, %s)" % [trap_lane, "the lane a dodge takes" if trap_lane == 2 else "another lane"]
		var layout: LevelLayout = _layout(lanes)
		layout.pads.append({"lane": trap_lane, "at": pad, "fenced": "unsafe"})
		var hull: Dictionary = LevelLayout.make_hull(pad - 3.0, pad + 80.0, Vector2i(trap_lane, trap_lane), lanes)
		hull["pick"] = [pick.x, pick.y]
		layout.hulls.append(hull)
		layout.ceiling_fences.append({"lane": trap_lane, "at": pad + 20.0})
		var w: RunWorld = _world(layout, 1)
		# Its first flurry is the one forced in the pick (below); the runner's lane holds no pad.
		_no_flurries(w)
		var forced: Array = [false]
		var dodge: Callable = _dodger({})
		var bot := func(ww: RunWorld) -> void:
			dodge.call(ww)
			var hh: Hunter = _hunter(ww)
			# Its next flurry due as the runner comes into the pick: it holds it until the pick has passed.
			if hh != null and not forced[0] and hh.state == Hunter.State.ALONGSIDE and hh.slash == Hunter.Slash.IDLE \
					and ww.player.distance >= pick.x + 2.0:
				forced[0] = true
				hh.set(&"_next_slash", hh.chase_time)
		var r: Dictionary = await _run(w, (pad + 70.0) / mt.run_speed, [], bot)
		var warns: Array = _events(r["history"], "warn")
		var inside: Array = warns.filter(func(e: Array) -> bool: return float(e[0]) + reach >= pick.x and float(e[0]) - 1.0 <= pick.y)
		var after: Array = warns.filter(func(e: Array) -> bool: return float(e[0]) > pick.y)
		check(forced[0] and inside.is_empty() and not after.is_empty() and bool(r["alive"]),
			"no flurry plays out in a fenced ceiling's pick (%d warned there), flurries again after it (%d), the runner alive %s %s"
			% [inside.size(), after.size(), _brief(r), tag])
		await sim.free_world(w)
	# Which lanes are open to step into by the pads.
	var layout: LevelLayout = _layout(lanes)
	layout.hulls.append(LevelLayout.make_hull(pad - 3.0, pad + 80.0, Vector2i(2, 3), lanes))
	layout.ceiling_fences.append_array([{"lane": 2, "at": pad + 20.0}, {"lane": 3, "at": pad + 20.0}])
	layout.pads.append({"lane": 2, "at": pad})
	layout.pads.append({"lane": 3, "at": pad + 30.0, "fenced": "safe"})
	layout.pads.append({"lane": 1, "at": pad, "fenced": "unsafe"})
	var w: RunWorld = _world(layout, 1)
	w.player.god_mode = true
	var r: Dictionary = await _until_alongside(w)
	var h: Hunter = r["hunter"]
	if h == null:
		check(false, "a Hunter beside the runner (the pads' lanes)")
		await sim.free_world(w)
		return
	var near := Vector2(pad - 5.0, pad + 5.0)
	var by_lane: Array = [h.lane_open(2, near.x, near.y, true), h.lane_open(1, near.x, near.y, true),
		h.lane_open(3, pad + 25.0, pad + 35.0, true), h.lane_open(4, near.x, near.y, true), h.lane_open(2, near.x, near.y, false)]
	check(by_lane == [false, false, true, true, false],
		"a lane with a trap pad is never open to step into (a pad under a fence, a pad marked unsafe: %s), a safe pad's or a padless lane is (%s)"
		% [by_lane.slice(0, 2), by_lane.slice(2, 4)])
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
	var r: Dictionary = await _run(w, 24.0, [], Callable(), func(ww: RunWorld) -> bool:
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


## It gives up chase_seconds after arriving, whatever it's doing (slashing at a runner in god mode all the while), its
## whine falling, and drops back out of play; it never starts a flurry it couldn't finish before then.
func _test_give_up() -> void:
	var w: RunWorld = _world(_layout(3), 1)
	w.player.god_mode = true
	var ref: Array = [null]
	var r: Dictionary = await _run(w, t.chase_seconds + 12.0, [], Callable(), func(ww: RunWorld) -> bool:
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


## How far inside the drawn sweep its cuts' box stays (metres): the box a little smaller than the look.
const SWEEP_SLACK: float = 0.05

## Its cuts are drawn as far as they reach (task S2's review; CLAUDE.md principle 4: a hitbox no bigger than the look): the
## see-through red sweep of its blades over the lane it cuts, out over the warning's last TRAIL_IN and whole through the
## cuts, its rig lunging that way. On every frame its cuts' box is live, every corner of the box lies inside the sweep (its
## fan's radius, angle and depth: Hunter.slash_fan) with SWEEP_SLACK to spare. The sweep shows only then, only grows (no
## pulse, no flicker), and plays the same with Reduced flashing on and off; it's the blades' see-through red, steady.
func _test_sweep() -> void:
	var plays: Array = []
	for reduced: bool in [false, true]:
		Settings.flashing_reduced = reduced
		var tag: String = "(Reduced flashing %s)" % ("on" if reduced else "off")
		var w: RunWorld = _world(_layout(5), 2)
		w.player.god_mode = true
		var play: Array = []
		var faults: PackedStringArray = []
		var counts: Array = [0, 0, 0]  # frames its box was live, frames the sweep showed, frames it lunged its whole way
		var last: Array = [-1, 0.0]  # the flurry the sweep last showed for, how far out it was then
		var watch := func(ww: RunWorld) -> void:
			var hh: Hunter = _hunter(ww)
			if hh == null or not hh.alive:
				return
			var fan: Dictionary = hh.slash_fan()
			var st: float = float(hh.get(&"_slash_t"))
			var due: bool = hh.slash == Hunter.Slash.FLURRY \
				or (hh.slash == Hunter.Slash.WARNING and st > t.warning_seconds - Hunter.TRAIL_IN + 0.0001)
			play.append([hh.flurries, int(hh.slash), not fan.is_empty(), snappedf(float(fan.get("share", 0.0)), 0.001)])
			if due != not fan.is_empty() and faults.size() < 10:
				faults.append("the sweep %s %s %.3f s into it" % ["missing" if due else "showing", Hunter.Slash.keys()[hh.slash], st])
			if fan.is_empty():
				return
			counts[1] += 1
			var share: float = float(fan["share"])
			if int(last[0]) == hh.flurries and share < float(last[1]) - 0.0001 and faults.size() < 10:
				faults.append("the sweep shrank from %.2f to %.2f (a pulse)" % [last[1], share])
			last[0] = hh.flurries
			last[1] = share
			var toward: float = signf(ww.geo.lane_x(hh.slash_lane) - hh.global_position.x)
			if float(fan["dir"]) != toward and faults.size() < 10:
				faults.append("the sweep faces away from the lane it cuts")
			if hh.slash == Hunter.Slash.FLURRY:
				counts[2] += 1 if absf(hh.model.rig.position.x - HunterModel.LUNGE * toward) < 0.01 else 0
			var box: Hazard = hh.slash_hitbox()
			if not (hh.is_cutting() and box.is_active()):
				return
			counts[0] += 1
			var pivot: Vector3 = fan["pivot"]
			var half: Vector3 = box.size * 0.5
			for corner: int in 8:
				var c: Vector3 = box.global_position + Vector3(half.x * (1 if corner & 1 else -1), half.y * (1 if corner & 2 else -1),
					half.z * (1 if corner & 4 else -1))
				var dx: float = (c.x - pivot.x) * float(fan["dir"])
				var dy: float = c.y - pivot.y
				var radius: float = Vector2(dx, dy).length()
				var angle: float = atan2(dy, dx)
				var pad: float = SWEEP_SLACK / maxf(radius, 0.1)
				if (radius < float(fan["inner"]) * share + SWEEP_SLACK or radius > float(fan["outer"]) * share - SWEEP_SLACK
						or angle < float(fan["low"]) + pad or angle > float(fan["high"]) - pad
						or dx > float(fan["x_max"]) * share - SWEEP_SLACK
						or absf(c.z - pivot.z) > float(fan["half_depth"]) - SWEEP_SLACK) and faults.size() < 10:
					faults.append("its box's corner (%.2f, %.2f, %.2f) lies outside the sweep (radius %.2f, angle %.2f)" % [c.x, c.y,
						c.z, radius, angle])
			# The sweep never reaches past the cut lane's far side into the lane the runner steps into (it's clipped there).
			var reach: float = pivot.x + float(fan["dir"]) * float(fan["x_max"]) * share
			if absf(reach - ww.geo.lane_x(hh.slash_lane)) > ww.geo.lane_width * 0.5 and faults.size() < 10:
				faults.append("the sweep reaches past the cut lane's far side (to x %.2f)" % reach)
		var r: Dictionary = await _run(w, 14.0, [], watch, func(ww: RunWorld) -> bool:
			var hh: Hunter = _hunter(ww)
			return hh != null and hh.flurries_cut >= 2 and hh.slash == Hunter.Slash.IDLE)
		check(bool(r["done"]) and int(counts[0]) > 10 and int(counts[1]) > int(counts[0]) and faults.is_empty(),
			"on every frame its cuts' box is live it lies inside the drawn sweep (%d frames), which shows only from its warning's last %.2f s through its cuts, never pulsing %s %s"
			% [counts[0], Hunter.TRAIL_IN, faults, tag])
		check(int(counts[2]) >= int(counts[0]) - 2, "through its cuts it lunges %.1f m toward the lane it cuts (%d of %d frames) %s"
			% [HunterModel.LUNGE, counts[2], counts[0], tag])
		plays.append(play)
		await sim.free_world(w)
	Settings.flashing_reduced = false
	check(plays.size() == 2 and plays[0] == plays[1], "the sweep plays the same with Reduced flashing on and off")
	# One mesh for every Hunter on a lane width (task S2's review: its cost).
	var w2: RunWorld = _world(_layout(5), 2)
	var r2: Dictionary = await _until_alongside(w2)
	var h2: Hunter = r2["hunter"]
	var w3: RunWorld = _world(_layout(5), 2)
	var r3: Dictionary = await _until_alongside(w3)
	var h3: Hunter = r3["hunter"]
	check(h2 != null and h3 != null and h2.slash_trail().mesh == h3.slash_trail().mesh,
		"every Hunter on a lane width shares one mesh for its sweep")
	await sim.free_world(w3)
	await sim.free_world(w2)
	var mat := HunterModel.slash_material()
	check(mat.emission.r > 0.9 and mat.emission.g < 0.2 and mat.emission.b < 0.2 and mat.albedo_color.a < 1.0
		and mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED,
		"the sweep is the blades' see-through red, unlit (the Compatibility renderer draws it the same)")


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
	var sweep: bool = false
	var stack: Array[Node] = [look]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is GeometryInstance3D:
			geometry += 1
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null and (n as MeshInstance3D).mesh.get_surface_count() > 0:
			sweep = sweep or (n as MeshInstance3D).mesh.surface_get_material(0) == HunterModel.slash_material()
		if n is CollisionObject3D:
			physics += 1
		stack.append_array(n.get_children())
	check(not look.is_inside_tree() and geometry >= 12 and sweep and physics == 0,
		"its warm-up look draws every part, alert too, its mark and its sweep (%d), outside the tree, with no physics object" % geometry)
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

extends TestSuite
## Explosions (task H6, GDD §11, the owner, October 8, 2026: "a yellow and red fireball"): every explosion in
## the game is one shared, pooled fireball (RunEffects.fireball, FireballPool). Checks: the pool is made once,
## bounded and reused (no node is made by an explosion, one more than the pool holds cuts the oldest short, a
## fireball ends by itself); it is CPU particles and unshaded billboards, so it works on the Compatibility
## renderer, with no collision and no light; it fades out as the camera nears it and never whites out the view;
## Reduced flashing softens it (as long as ever, but from nothing, never white-hot, and never brighter than the
## normal one at any moment); the shader warm-up draws its materials; and each explosion that is not a boss's (the drone's hit and
## crash, the hover truck's wreck and its burst through the wall, the Buzz Overdrive, the Enforcer truck, a
## fence generator, the missiles, the Hostile Takeover lobby's blast) calls it, at the size its code names. The
## bosses' own explosions and the bombs' blasts are checked in their fights' suites (test_floating_head,
## test_floating_head_defeat, test_the_house_attacks, test_the_house_phases, test_hostile_takeover_fight).

const DUMMY: String = "res://tests/helpers/dummy_enemy.gd"
const DroneScript := preload("res://scripts/enemies/drone.gd")
const TruckScript := preload("res://scripts/enemies/hover_truck.gd")
const BuzzScript := preload("res://scripts/enemies/buzz_overdrive.gd")

var sim: RunSim


func run() -> void:
	sim = RunSim.new(tree, tuning)
	_test_tuning()
	await _test_pool_is_bounded_and_reused()
	await _test_nothing_is_a_hazard()
	await _test_reduced_flashing()
	await _test_camera_fade()
	await _test_smoke_is_cleared()
	await _test_warm_up()
	await _test_drone()
	await _test_hover_truck()
	await _test_buzz_overdrive()
	await _test_enforcer_truck()
	await _test_generator()
	await _test_missiles()
	await _test_lobby_blast()
	_restore_flashing()


# --- Helpers -------------------------------------------------------------------------------------

func _world(lanes: int = 3, loadout: Loadout = null) -> RunWorld:
	return sim.build_world(RunSim.layout(lanes, 800.0), loadout if loadout != null else Loadout.new())


## Collects the size of every fireball asked for in `world` from now on.
func _collect(world: RunWorld) -> Array[float]:
	var sizes: Array[float] = []
	world.effects.fireball_played.connect(func(_at: Vector3, size: float) -> void: sizes.append(size))
	return sizes


func _run_until(w: RunWorld, seconds: float, done: Callable) -> bool:
	if not w.player.running:
		await tree.physics_frame
		w.player.running = true
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		if done.call():
			return true
		await tree.physics_frame
	return done.call()


## Every node under `root` (a count: an explosion must not make one).
func _nodes_under(root: Node) -> int:
	var n: int = 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		n += 1
		stack.append_array(node.get_children())
	return n


func _set_reduced(on: bool) -> void:
	var profile := Profile.new()
	Settings.set_value(profile, "reduced_flashing", on)
	Settings.apply_visuals(profile)


func _restore_flashing() -> void:
	_set_reduced(false)


# --- The numbers ---------------------------------------------------------------------------------

func _test_tuning() -> void:
	var t := SpeedFxTuning.new()
	var per_slot: int = t.fireball_puffs + t.fireball_smoke_puffs + t.fireball_embers + 1
	check(per_slot <= 100 and t.fireball_pool <= 12 and t.fireball_pool * per_slot <= 900,
		"a fireball and the pool are bounded (%d particles each, %d slots)" % [per_slot, t.fireball_pool])
	check(t.fireball_seconds <= 1.5 and t.fireball_smoke_seconds <= 3.0,
		"a fireball is short: the fire burns %.1f s, the smoke clears in %.1f s" % [t.fireball_seconds, t.fireball_smoke_seconds])
	check(t.fireball_reduced_brightness < 1.0, "Reduced flashing dims it (x%.2f)" % t.fireball_reduced_brightness)


# --- The pool ------------------------------------------------------------------------------------

func _test_pool_is_bounded_and_reused() -> void:
	_set_reduced(false)
	var world: RunWorld = _world()
	var fx: RunEffects = world.effects
	var pool: FireballPool = fx.fireballs()
	var t: SpeedFxTuning = fx.tuning
	check(pool.slots.size() == t.fireball_pool and pool.get_parent() == fx,
		"the pool is built with the effects, one slot a fireball (%d)" % pool.slots.size())
	var gpu: int = 0
	var emitters: int = 0
	var shaded: int = 0
	var stack: Array[Node] = [pool]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node is GPUParticles3D:
			gpu += 1
		if node is CPUParticles3D:
			var p := node as CPUParticles3D
			emitters += 1
			var m := p.material_override as StandardMaterial3D
			if m == null or m.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED \
					or m.billboard_mode != BaseMaterial3D.BILLBOARD_PARTICLES or p.local_coords or not p.one_shot:
				shaded += 1
	check(gpu == 0 and emitters == 4 * pool.slots.size() and shaded == 0,
		"it is CPU particles only (%d, no GPU particles), unshaded billboards in world space, one shot each" % emitters)
	check(pool.materials().size() == 3, "three materials: additive fire, additive embers, see-through smoke")
	var amounts: Array[int] = []
	for p: CPUParticles3D in [pool.slots[0].fire, pool.slots[0].smoke, pool.slots[0].embers, pool.slots[0].core]:
		amounts.append(p.amount)
	check(amounts == [t.fireball_puffs, t.fireball_smoke_puffs, t.fireball_embers, 1], "its particle counts are the tuning's %s" % [amounts])

	# Many explosions at once: nothing is made, the oldest is cut short, never more than the pool.
	var before: int = _nodes_under(world)
	var asked: int = pool.slots.size() * 3 + 2
	var sizes: Array[float] = _collect(world)
	for i: int in asked:
		fx.fireball(Vector3(float(i % 3) - 1.0, 1.0, -20.0 - float(i)), 0.8 + 0.7 * float(i % 5), i % 2 == 0)
	check(_nodes_under(world) == before, "explosions make no node (%d before, %d after %d fireballs)" % [before, _nodes_under(world), asked])
	check(pool.active() == pool.slots.size() and pool.plays == asked and pool.recycled == asked - pool.slots.size(),
		"at most the pool plays at once (%d), and one more cuts the oldest short (%d recycled of %d)" % [
		pool.active(), pool.recycled, asked])
	check(sizes.size() == asked, "each one is announced (fireball_played: %d)" % sizes.size())
	var stable: bool = true
	for slot: FireballPool.Slot in pool.slots:
		stable = stable and slot.fire.amount == t.fireball_puffs and slot.embers.amount == t.fireball_embers
	check(stable, "and their particle counts never change (no reallocation)")
	# They end by themselves, and a quick one (no smoke) sooner than one with.
	pool._process(10.0)
	fx.fireball(Vector3(0.0, 2.0, -20.0), 3.0, true)
	var slow: float = pool.latest.left
	fx.fireball(Vector3(0.0, 2.0, -20.0), 1.5, false, 1.6)
	var quick: float = pool.latest.left
	check(quick < slow and slow <= t.fireball_smoke_seconds / 0.8 + 0.01 and quick <= 1.2,
		"a fireball with smoke lasts %.2f s, a quick one without %.2f s" % [slow, quick])
	pool._process(10.0)
	fx.fireball(Vector3(0.0, 8.0, -30.0), 14.0)
	var big_life: float = pool.latest.left
	check(big_life <= 5.0, "even a boss's (14 m) is over in %.1f s" % big_life)
	pool._process(10.0)
	check(pool.active() == 0, "every fireball ends by itself")
	# The overall scale is the tuning's.
	var scale_before: float = t.fireball_scale
	t.fireball_scale = 2.0
	fx.fireball(Vector3(0.0, 2.0, -20.0), 2.0)
	check(is_equal_approx(pool.last_size, 4.0), "the overall scale multiplies a fireball's size (%.1f)" % pool.last_size)
	t.fireball_scale = scale_before
	# A bomb's fireball is held in: its fire and embers fly out of its centre only `spread` as far.
	pool._process(10.0)
	fx.fireball(Vector3(0.0, 3.0, -20.0), 2.0)
	var free_fire: float = pool.latest.fire.initial_velocity_max
	var free_embers: float = pool.latest.embers.initial_velocity_max
	var free_radius: float = pool.latest.fire.emission_sphere_radius
	fx.fireball(Vector3(0.0, 3.0, -20.0), 2.0, false, 1.0, 0.5)
	check(is_equal_approx(pool.latest.fire.initial_velocity_max, free_fire * 0.5)
			and is_equal_approx(pool.latest.embers.initial_velocity_max, free_embers * 0.5)
			and is_equal_approx(pool.latest.fire.emission_sphere_radius, free_radius * 0.5),
		"a held-in fireball (spread 0.5) throws its fire and embers half as hard, from half the ball")
	# Never sunk into the floor.
	fx.fireball(Vector3(0.0, 0.0, -20.0), 4.0)
	var lowest: float = pool.latest.fire.global_position.y
	check(lowest >= 4.0 * 0.45 - 0.001, "a blast on the street rises out of it (%.2f m)" % lowest)
	await sim.free_world(world)


func _test_nothing_is_a_hazard() -> void:
	var world: RunWorld = _world()
	var pool: FireballPool = world.effects.fireballs()
	var bodies: int = 0
	var lights: int = 0
	var stack: Array[Node] = [pool]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node is CollisionObject3D or node is CollisionShape3D:
			bodies += 1
		if node is Light3D:
			lights += 1
	check(bodies == 0 and lights == 0, "a fireball collides with nothing and lights nothing (a look only)")
	var hazards_before: int = _count_hazards(world)
	world.effects.fireball(Vector3(0.0, 1.0, -10.0), 6.0)
	check(_count_hazards(world) == hazards_before, "and an explosion makes no hazard")
	await sim.free_world(world)


func _count_hazards(root: Node) -> int:
	var n: int = 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node is Hazard:
			n += 1
	return n


# --- Reduced flashing ----------------------------------------------------------------------------

## The requirement (the H6 review): with Reduced flashing a fireball is never brighter than the normal one after
## its first 0.15 s, and at its peak at most `fireball_reduced_brightness` of it; it lasts as long, starts from
## nothing and is never white-hot. Measured as an additive blend adds it: each particle's alpha times its colour's
## luminance (and the emitter's tint), sampled through the life it really has.
func _test_reduced_flashing() -> void:
	var world: RunWorld = _world()
	var fx: RunEffects = world.effects
	var pool: FireballPool = fx.fireballs()
	var t: SpeedFxTuning = fx.tuning
	var shakes: Array[int] = [0]
	fx.shake_requested.connect(func(_s: float, _d: float) -> void: shakes[0] += 1)
	var probe: Dictionary = {}
	for reduced: bool in [false, true]:
		_set_reduced(reduced)
		pool._process(10.0)
		fx.fireball(Vector3(0.0, 2.0, -20.0), 2.0)
		var slot: FireballPool.Slot = pool.latest
		probe[reduced] = {"fire": [slot.fire.color_ramp, slot.fire.color.a], "core": [slot.core.color_ramp, slot.core.color.a],
			"embers": [slot.embers.color_ramp, slot.embers.color.a], "left": slot.left, "speed": slot.fire.speed_scale,
			"flag": pool.last_reduced}
	var calm: Dictionary = probe[false]
	var soft: Dictionary = probe[true]
	check(not calm["flag"] and soft["flag"], "the pool knows when it plays softened")
	check(is_equal_approx(float(soft["left"]), float(calm["left"])) and is_equal_approx(float(soft["speed"]), float(calm["speed"])),
		"with Reduced flashing it lasts as long (%.2f s against %.2f s) and plays as fast" % [float(soft["left"]), float(calm["left"])])
	var lives: Dictionary = {"fire": t.fireball_seconds, "core": FireballPool.CORE_SECONDS, "embers": FireballPool.EMBER_SECONDS}
	for kind: String in ["fire", "core", "embers"]:
		var life: float = lives[kind]
		var calm_ramp: Gradient = calm[kind][0]
		var soft_ramp: Gradient = soft[kind][0]
		var calm_tint: float = calm[kind][1]
		var soft_tint: float = soft[kind][1]
		check(is_equal_approx(calm_tint, 1.0) and is_equal_approx(soft_tint, t.fireball_reduced_brightness),
			"its %s is at %.2f of the normal strength" % [kind, soft_tint])
		var never_brighter: bool = true
		var calm_peak: float = 0.0
		var soft_peak: float = 0.0
		var worst_second: float = 0.0
		for i: int in int(life * 100.0) + 1:
			var at: float = float(i) / 100.0
			var normal_glow: float = _glow(calm_ramp, calm_tint, at, life)
			var softened: float = _glow(soft_ramp, soft_tint, at, life)
			calm_peak = maxf(calm_peak, normal_glow)
			soft_peak = maxf(soft_peak, softened)
			if at >= 0.15 and softened > normal_glow + 0.0001:
				never_brighter = false
				worst_second = at
		check(never_brighter, "with Reduced flashing its %s is never brighter than the normal one after 0.15 s (at %.2f s it is)" % [
			kind, worst_second])
		check(soft_peak <= t.fireball_reduced_brightness * calm_peak + 0.0001,
			"and its %s peaks at most %.2f of the normal peak (%.3f against %.3f)" % [
			kind, t.fireball_reduced_brightness, soft_peak, calm_peak])
		check(_glow(soft_ramp, soft_tint, 0.0, life) == 0.0, "and starts from nothing")
		var max_blue: float = 0.0
		for c: Color in soft_ramp.colors:
			max_blue = maxf(max_blue, c.b)
		check(max_blue < 0.25, "never white-hot: orange and yellow only (blue at most %.2f)" % max_blue)
	check(shakes[0] == 0, "a fireball asks for no shake of its own (the explosion's code does, under the Screen shake setting)")
	_set_reduced(false)
	await sim.free_world(world)


## What an additive blend adds for a particle `at` seconds into a life of `life` seconds: its colour's luminance
## times its alpha, with the emitter's `tint`.
func _glow(ramp: Gradient, tint: float, at: float, life: float) -> float:
	var c: Color = ramp.sample(clampf(at / life, 0.0, 1.0))
	return tint * c.a * (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b)


# --- The camera ----------------------------------------------------------------------------------

## A fireball fades out as the camera comes near it (the H6 review: an explosion between the camera and the runner
## whited the view out for 0.2 to 0.3 s): none of it within its size of the camera, all of it from 2.5 times its size,
## in between by the distance, with its smoke; an emitter showing nothing is hidden.
func _test_camera_fade() -> void:
	var world: RunWorld = _world()
	var fx: RunEffects = world.effects
	var pool: FireballPool = fx.fireballs()
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.global_position = Vector3(0.0, 3.0, 10.0)
	camera.make_current()
	var size: float = 3.0
	var cases: Array[Array] = [[0.5 * size, 0.0], [1.0 * size, 0.0], [1.75 * size, 0.5], [2.5 * size, 1.0], [6.0 * size, 1.0]]
	for c: Array in cases:
		pool._process(10.0)
		fx.fireball(Vector3(0.0, 3.0, 10.0 - float(c[0])), size)
		var slot: FireballPool.Slot = pool.latest
		var want: float = c[1]
		check(is_equal_approx(slot.shown, want) and is_equal_approx(slot.fire.color.a, want) and is_equal_approx(slot.smoke.color.a, want)
				and slot.fire.visible == (want > 0.0) and slot.embers.visible == (want > 0.0) and slot.smoke.visible == (want > 0.0),
			"the camera %.1f m (%.2f sizes) from a fireball sees %.2f of it (fire %.2f, hidden: %s)" % [
			float(c[0]), float(c[0]) / size, want, slot.fire.color.a, not slot.fire.visible])
	# It follows the camera as it comes on: the runner's camera rides toward an explosion ahead.
	pool._process(10.0)
	fx.fireball(Vector3(0.0, 3.0, -20.0), size)
	var seen: Array[float] = []
	for z: float in [10.0, 0.0, -8.0, -14.0, -18.0]:
		camera.global_position = Vector3(0.0, 3.0, z)
		pool._process(0.0)
		seen.append(pool.latest.fire.color.a)
	var falling: bool = true
	for i: int in range(1, seen.size()):
		falling = falling and seen[i] <= seen[i - 1] + 0.0001
	check(falling and seen[0] == 1.0 and seen[seen.size() - 1] == 0.0,
		"it fades out as the camera runs toward it (%s)" % [seen])
	# With Reduced flashing the fade takes the softened tint with it.
	_set_reduced(true)
	pool._process(10.0)
	camera.global_position = Vector3(0.0, 3.0, 10.0)
	fx.fireball(Vector3(0.0, 3.0, 10.0 - 1.75 * size), size)
	check(is_equal_approx(pool.latest.fire.color.a, fx.tuning.fireball_reduced_brightness * 0.5),
		"and with Reduced flashing the fade multiplies the dimmer strength (%.3f)" % pool.latest.fire.color.a)
	_set_reduced(false)
	camera.queue_free()
	await sim.free_world(world)


## What a slot throws without smoke is not what it threw with it: its smoke is stopped and hidden, never thrown anew
## at its old place (restarting it did), and comes back when smoke is asked for.
func _test_smoke_is_cleared() -> void:
	var world: RunWorld = _world()
	var fx: RunEffects = world.effects
	var pool: FireballPool = fx.fireballs()
	pool._process(10.0)
	fx.fireball(Vector3(0.0, 3.0, -20.0), 2.0, true)
	var smoked: FireballPool.Slot = pool.latest
	check(smoked.smoke.visible and smoked.smoke.emitting, "a fireball with smoke shows its smoke")
	pool._process(10.0)
	for i: int in pool.slots.size():
		fx.fireball(Vector3(float(i), 3.0, -20.0), 1.0, false)
		check(not pool.latest.smoke.visible and not pool.latest.smoke.emitting, "a fireball without smoke hides its smoke (slot %d)" % i)
		pool._process(10.0)
	check(not smoked.smoke.visible and not smoked.smoke.emitting, "including the slot that had smoke before")
	for i: int in pool.slots.size():
		fx.fireball(Vector3(0.0, 3.0, -20.0), 1.0, true)
		pool._process(10.0)
	var shown: int = 0
	for slot: FireballPool.Slot in pool.slots:
		shown += 1 if slot.smoke.visible else 0
	check(shown == pool.slots.size(), "and every slot shows smoke again when it is asked for (%d of %d)" % [shown, pool.slots.size()])
	await sim.free_world(world)


# --- The shader warm-up --------------------------------------------------------------------------

func _test_warm_up() -> void:
	var world: RunWorld = _world()
	var warm := ShaderWarmup.new()
	warm._sample_fireballs(world)
	var looks: int = 0
	for key: Variant in warm.keys:
		if String(key).begins_with("fireball|"):
			looks += 1
	check(looks >= 2 and warm.get_child_count() >= 2,
		"the shader warm-up draws the fireball's looks: additive and see-through (%d looks)" % looks)
	warm.free()
	await sim.free_world(world)


# --- The explosions ------------------------------------------------------------------------------

func _test_drone() -> void:
	var w: RunWorld = _world()
	var sizes: Array[float] = _collect(w)
	var shakes: Array[int] = [0]
	w.effects.shake_requested.connect(func(_s: float, _d: float) -> void: shakes[0] += 1)
	var d := w.director.spawn({"type": "drone", "at": 30.0, "lane": 1, "side": 0, "seed": 7, "params": {"slot": 0}}) as DroneScript
	var up: bool = await _run_until(w, 4.0, func() -> bool: return d.state == DroneScript.State.FOLLOW)
	check(up and sizes.is_empty(), "a flying drone makes no fireball")
	var d_ref: WeakRef = weakref(d)
	d.defeat(&"weapon")
	check(sizes == [DroneScript.FIRE_HIT_SIZE], "shot down it bursts into flames and starts to fall (%s)" % [sizes])
	await _run_until(w, 3.0, func() -> bool: return d_ref.get_ref() == null)
	check(sizes == [DroneScript.FIRE_HIT_SIZE, DroneScript.FIRE_CRASH_SIZE] and shakes[0] >= 1,
		"and where it crashes, a big fireball (%s), with its shake" % [sizes])
	check(DroneScript.FIRE_CRASH_SIZE > 2.0 * DroneScript.FIRE_HIT_SIZE, "the crash is the big one")
	# The Screen shake setting still silences the shake (and the hit-stop), never the fireball.
	var w2: RunWorld = _world()
	var sizes2: Array[float] = _collect(w2)
	w2.effects.shake_scale = 0.0
	var shakes2: Array[int] = [0]
	w2.effects.shake_requested.connect(func(_s: float, _d: float) -> void: shakes2[0] += 1)
	var d2 := w2.director.spawn({"type": "drone", "at": 30.0, "lane": 1, "side": 0, "seed": 7, "params": {"slot": 0}}) as DroneScript
	await _run_until(w2, 4.0, func() -> bool: return d2.state == DroneScript.State.FOLLOW)
	var d2_ref: WeakRef = weakref(d2)
	d2.defeat(&"weapon")
	await _run_until(w2, 3.0, func() -> bool: return d2_ref.get_ref() == null)
	check(shakes2[0] == 0 and sizes2.size() == 2, "with Screen shake off the drone's crash still burns but shakes nothing (%d shakes)" % shakes2[0])
	await sim.free_world(w)
	await sim.free_world(w2)


func _test_hover_truck() -> void:
	# Stomped or shot down it spins out and explodes in one fireball; its node outlasts it a moment.
	var w: RunWorld = _world()
	var sizes: Array[float] = _collect(w)
	var truck := w.director.spawn({"type": "hover_truck", "at": 60.0, "lane": w.layout.outer_lane(1), "side": 1, "seed": 5,
		"params": {"skip_entrance": true, "phase": "pace", "offset": 20.0, "guns": false}}) as TruckScript
	await tree.physics_frame
	w.player.running = true
	await tree.physics_frame
	var truck_ref: WeakRef = weakref(truck)
	truck.defeat(&"weapon")
	check(sizes.is_empty(), "a wrecked truck doesn't explode at once: it spins out first")
	var blew: bool = await _run_until(w, 3.0, func() -> bool: return not sizes.is_empty())
	check(blew and sizes == [TruckScript.FIRE_EXPLODE_SIZE], "then it explodes in one fireball (%s)" % [sizes])
	var gone: bool = await _run_until(w, 1.5, func() -> bool: return truck_ref.get_ref() == null)
	check(gone, "and its node is gone a moment later (no fireball of its own to free)")
	check(TruckScript.FIRE_EXPLODE_SIZE >= 3.0, "a truck's fireball is big (%.1f m)" % TruckScript.FIRE_EXPLODE_SIZE)
	await sim.free_world(w)
	# It bursts through the wall in a quick one (no smoke, so it clears at once).
	var w2: RunWorld = _world()
	var sizes2: Array[float] = _collect(w2)
	var truck2 := w2.director.spawn({"type": "hover_truck", "at": 80.0, "lane": w2.layout.outer_lane(1), "side": 1, "seed": 5,
		"params": {"guns": false}}) as TruckScript
	var burst: bool = await _run_until(w2, 12.0, func() -> bool: return truck2.state == TruckScript.State.EMERGE)
	check(burst and sizes2 == [TruckScript.FIRE_BURST_SIZE], "its burst through the wall is a fireball too (%s)" % [sizes2])
	await sim.free_world(w2)
	# With Reduced flashing the wall's frame glows steadily and softly through the banging, with no flash.
	_set_reduced(true)
	var w3: RunWorld = _world()
	var truck3 := w3.director.spawn({"type": "hover_truck", "at": 80.0, "lane": w3.layout.outer_lane(1), "side": 1, "seed": 5,
		"params": {"guns": false}}) as TruckScript
	var seen: Dictionary = {}
	await _run_until(w3, 12.0, func() -> bool:
		if truck3.state == TruckScript.State.BANGING:
			seen[truck3._bang_frame.material_override] = true
		return truck3.state == TruckScript.State.EMERGE)
	check(seen.size() == 1 and seen.keys()[0] == truck3._mats["flash_soft"],
		"with Reduced flashing the truck's wall frame holds one soft glow all through the banging (%d looks)" % seen.size())
	_set_reduced(false)
	var w4: RunWorld = _world()
	var truck4 := w4.director.spawn({"type": "hover_truck", "at": 80.0, "lane": w4.layout.outer_lane(1), "side": 1, "seed": 5,
		"params": {"guns": false}}) as TruckScript
	var seen4: Dictionary = {}
	await _run_until(w4, 12.0, func() -> bool:
		if truck4.state == TruckScript.State.BANGING:
			seen4[truck4._bang_frame.material_override] = true
		return truck4.state == TruckScript.State.EMERGE)
	check(seen4.size() >= 2 and seen4.has(truck4._mats["flash"]),
		"and without it the frame flashes with each bang (%d looks)" % seen4.size())
	await sim.free_world(w3)
	await sim.free_world(w4)


func _test_buzz_overdrive() -> void:
	var w: RunWorld = _world()
	var sizes: Array[float] = _collect(w)
	var tank: Enemy = w.director.spawn({"type": "buzz_overdrive", "at": 400.0, "lane": 1, "seed": 1, "params": {}})
	await tree.physics_frame
	tank.defeat(&"weapon")
	check(sizes == [BuzzScript.FIRE_SIZE], "a Buzz Overdrive shot down goes up in a fireball (%s)" % [sizes])
	await sim.free_world(w)


func _test_enforcer_truck() -> void:
	var layout := RunSim.layout(3, 800.0)
	layout.enemies.append({"type": "enforcer_truck", "at": 1.0, "lane": 1, "side": 0, "seed": 7, "params": {}})
	var w: RunWorld = sim.build_world(layout, Loadout.new())
	var sizes: Array[float] = _collect(w)
	w.player.god_mode = true
	await tree.physics_frame
	w.player.running = true
	var truck: EnforcerTruck = null
	await _run_until(w, 6.0, func() -> bool:
		for e: Variant in w.director.active:
			if is_instance_valid(e) and e is EnforcerTruck:
				return true
		return false)
	for e: Variant in w.director.active:
		if is_instance_valid(e) and e is EnforcerTruck:
			truck = e as EnforcerTruck
	check(truck != null, "the Enforcer truck arrives")
	if truck != null:
		truck.defeat(&"weapon")
		check(sizes == [EnforcerTruck.FIRE_SIZE], "wrecked it goes up in a fireball (%s)" % [sizes])
	await sim.free_world(w)


func _test_generator() -> void:
	var layout := RunSim.layout(3, 800.0)
	for lane: int in 3:
		layout.fences.append(RunSim.fence(lane, 44.0, "full"))
	var w: RunWorld = sim.build_world(layout, Loadout.new())
	var sizes: Array[float] = _collect(w)
	var gen := w.director.spawn({"type": "generator", "at": 40.0, "lane": 1, "side": 0, "seed": 3, "params": {}}) as FenceGenerator
	await tree.physics_frame
	gen.defeat(&"stomp")
	check(sizes == [FenceGenerator.FIRE_SIZE], "a destroyed fence generator burns in a fireball (%s), inside its EMP" % [sizes])
	var off: int = 0
	for f: Dictionary in w.layout.fences:
		if f.get("disabled", false):
			off += 1
	check(off == 3, "and its EMP still switched the fences off (%d of 3)" % off)
	await sim.free_world(w)


func _test_missiles() -> void:
	for tier: int in [3, 4]:
		var loadout := Loadout.new()
		loadout.tiers[&"weapon"] = tier
		var w: RunWorld = _world(3, loadout)
		var sizes: Array[float] = _collect(w)
		var weapon: WeaponPowerup = w.powerups.weapon
		var dummy: Enemy = w.director.spawn({"type": "dummy", "script": DUMMY, "at": 30.0, "lane": 1, "side": 0, "seed": 1,
			"params": {}})
		await tree.physics_frame
		# What the projectile pool announces on a hit (the splash's own, to other enemies, shows no blast).
		w.projectiles.enemy_hit.emit(dummy, 1.0, false)
		var want: float = WeaponFx.HEAVY_FIRE_SIZE if tier == 4 else WeaponFx.MISSILE_FIRE_SIZE
		check(sizes == [want], "tier %d: a missile's hit is a fireball (%s)" % [tier, sizes])
		w.projectiles.enemy_hit.emit(dummy, 1.0, true)
		check(sizes.size() == 1, "tier %d: its splash on another enemy makes no second one" % tier)
		check(weapon.is_heavy() == (tier == 4), "(tier %d)" % tier)
		await sim.free_world(w)
	var plain := Loadout.new()
	plain.tiers[&"weapon"] = 2
	var w2: RunWorld = _world(3, plain)
	var sizes2: Array[float] = _collect(w2)
	var dummy2: Enemy = w2.director.spawn({"type": "dummy", "script": DUMMY, "at": 30.0, "lane": 1, "side": 0, "seed": 1, "params": {}})
	await tree.physics_frame
	w2.projectiles.enemy_hit.emit(dummy2, 1.0, false)
	check(sizes2.is_empty(), "a laser's hit is no explosion: the player's other fire stays cool")
	await sim.free_world(w2)


func _test_lobby_blast() -> void:
	var w: RunWorld = _world()
	var sizes: Array[float] = _collect(w)
	var lobby := HostileTakeoverLobby.new()
	lobby.world = w
	lobby.blast(Vector3(0.0, 8.0, -60.0), 16.0)
	check(sizes == [16.0 * HostileTakeoverLobby.BLAST_RADIUS_SHARE], "the lobby's blast is one of the shared fireballs (%s)" % [sizes])
	lobby.free()
	await sim.free_world(w)

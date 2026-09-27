class_name FloatingHeadBombing
extends Node3D
## The Floating Head's bombing run (GDD §10): "the ship flies in overhead and drops bombs toward the
## player for about 15-20 seconds. A searchlight sweeps the lanes and the bombs fall where it lingers,
## with a falling whistle, so the light is the visual warning."
## The light's spot hunts the runner on the floor ahead of them, about as far ahead as they will run
## while a bomb falls. Each round:
## 1. SWEEP_OUT: after a blast it swings away across the lanes (a seeded pick), then
## 2. SWEEP_IN: it sweeps back to the runner's lane and rests there a moment;
## 3. LOCK, the warning: it lingers on that spot of the track, turning red, with the framework's red
##    target circle (BossProps.circle_warning, so pickups keep off it), the lock sound, and a bomb
##    falling from the bay with its whistle, timed to end with the blast;
## 4. the blast: a fireball where the circle was, for BossProps-style blast_seconds, as the runner
##    would get there. Leaving the lane dodges it; it's too tall to jump.
## Every few locks (straddle_every) the light spreads over two lanes side by side: two bombs, and the
## free side is the way out. A player who keeps moving can always escape (the fairness rules below).
## Fairness: a lock happens only where the lanes it strikes are free of holes and fences around the
## blast (it lands on a roof), where a lane it doesn't strike lies at most max_escape_lanes away with
## it and every lane on the way free of holes and fences from the player to past the blast (the dodge is
## a plain lane switch), with no ceiling over it and no pickup waiting in it; the warning always lasts
## lock_seconds / pace. Otherwise the light keeps hunting. The blast's hitbox is a little smaller than
## the fireball and, in an outer lane, keeps clear of a wall runner beside it.
## Nothing depends on how long the fight has lasted: random picks come from the fight's seeded rng and
## time from the physics step, so every attempt plays out the same way for the same inputs.
## The run ends run_seconds after the light switches on; the last blast lands before it ends.

enum Step { IDLE, SWEEP_OUT, SWEEP_IN, LOCK }

const BOMB_NAME: String = "Floating Head's bomb"
const LIGHT_WHITE := Color(0.85, 0.92, 1.0)
const LIGHT_RED := Color(1.0, 0.16, 0.1)
const FIRE := Color(1.0, 0.36, 0.12)
const FIRE_HOT := Color(1.0, 0.8, 0.5)
## Bombs, blasts and fireballs kept ready (two locks' worth, one of them a straddle).
const POOL: int = 4
## How fast the spot catches up along the track after a blast, beyond the runner's own speed.
const CATCH_UP: float = 60.0
## The spot counts as on the runner's lane within this of its centre.
const ON_LANE: float = 0.2
## A fireball lasts this long (its hitbox only blast_seconds).
const FIRE_SECONDS: float = 0.6
## A straddle's second bomb leaves the bay this much later (it lands at the same time).
const SECOND_BOMB_DELAY: float = 0.07
## The falling whistle's length, if the sound library doesn't say.
const WHISTLE_SECONDS: float = 0.9

var head: FloatingHead
var tuning: FloatingHeadTuning
var world: RunWorld
var step: Step = Step.IDLE
var step_time: float = 0.0
## The run: whether its light is on, how long it lasts, and how long it has run.
var running: bool = false
var run_seconds: float = 0.0
var run_time: float = 0.0
## Seconds of bombing so far (bombs in the air and blasts keep to this clock).
var clock: float = 0.0
## Locks so far in this run (every straddle_every-th covers two lanes).
var locks: int = 0
## The light's spot: its world x and its track distance.
var spot_x: float = 0.0
var spot_d: float = 0.0
## The lock in progress: {lanes: Array[int], at, x, lock, impact} (clock times), or empty.
var target: Dictionary = {}

## Bombs on their way: {lane, at, x, release, impact, whistle, released, whistled, circle, bomb, from}.
var _drops: Array[Dictionary] = []
## Blasts burning: {hazard, fire, material, x, at, start}.
var _blasts: Array[Dictionary] = []
var _out_lane: int = 0
var _settled: float = 0.0
## Seconds since the light began its sweep (it sweeps at least sweep_seconds between locks).
var _swept: float = 0.0
var _red: float = 0.0
var _light: float = 0.0
var _whistle: float = WHISTLE_SECONDS
var _beam: MeshInstance3D
var _spot: MeshInstance3D
var _beam_material: ShaderMaterial
var _spot_material: ShaderMaterial
var _bombs: Array[MeshInstance3D] = []
var _hazards: Array[Hazard] = []
var _fires: Array[MeshInstance3D] = []

static var _cone: ArrayMesh
static var _quad: ArrayMesh


func setup(p_head: FloatingHead) -> void:
	head = p_head
	tuning = head.tuning
	world = head.world
	top_level = true
	transform = Transform3D.IDENTITY
	if world.sfx_library != null and world.sfx_library.stream(&"bomb_whistle") != null:
		_whistle = world.sfx_library.stream(&"bomb_whistle").get_length()
	var shader := load("res://scripts/bosses/floating_head/floating_head_light.gdshader") as Shader
	_beam_material = ShaderMaterial.new()
	_beam_material.shader = shader
	_beam_material.set_shader_parameter(&"shape", 0)
	_spot_material = ShaderMaterial.new()
	_spot_material.shader = shader
	_spot_material.set_shader_parameter(&"shape", 1)
	_beam = _mesh_node(_cone_mesh(), _beam_material, "Beam")
	_spot = _mesh_node(_quad_mesh(), _spot_material, "Spot")
	_beam.visible = false
	_spot.visible = false
	for i: int in POOL:
		var bomb: MeshInstance3D = _mesh_node(FloatingHeadModel.bomb_mesh(), null, "Bomb")
		bomb.visible = false
		_bombs.append(bomb)
		_hazards.append(_make_hazard())
		var fire := MeshInstance3D.new()
		fire.name = "Fireball"
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = 12
		sphere.rings = 6
		fire.mesh = sphere
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color = Color.BLACK
		m.disable_receive_shadows = true
		fire.material_override = m
		fire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fire.visible = false
		add_child(fire)
		_fires.append(fire)


## Starts a run of `seconds`: the light switches on and starts sweeping, the bay opens.
func start(seconds: float) -> void:
	stop()
	running = true
	run_seconds = seconds
	run_time = 0.0
	locks = 0
	_light = 0.0
	spot_x = 0.0
	spot_d = world.player.distance + _lead()
	_out_lane = _pick_out_lane()
	_set_step(Step.SWEEP_OUT)
	_swept = 0.0
	head.body.bay_open = true
	head.body.lamp = FloatingHeadBody.Lamp.SWEEP
	head.sound(&"searchlight_on", head.body.lamp_world())
	head.log_event(&"run_start", {"seconds": seconds})


## Ends the run now: the light goes off and bombs still in the air are gone (their circles too).
## Blasts already burning finish.
func stop() -> void:
	if running:
		head.log_event(&"run_end")
	running = false
	target = {}
	_set_step(Step.IDLE)
	for d: Dictionary in _drops:
		head.props.remove(d["circle"])
		if d["bomb"] != null:
			(d["bomb"] as Node3D).visible = false
	_drops.clear()
	if head.body != null and is_instance_valid(head.body):
		head.body.bay_open = false
		head.body.lamp = FloatingHeadBody.Lamp.OFF


## Everything off, blasts included (the fight is won).
func clear() -> void:
	stop()
	for b: Dictionary in _blasts:
		(b["hazard"] as Hazard).set_enabled(false)
		(b["fire"] as Node3D).visible = false
	_blasts.clear()


## True once the run is over and its last bomb has landed.
func finished() -> bool:
	return not running and _drops.is_empty()


## True while a blast is burning.
func burning() -> bool:
	for b: Dictionary in _blasts:
		if (b["hazard"] as Hazard).is_active():
			return true
	return false


## The live blasts' hitboxes (tests).
func blast_hazards() -> Array[Hazard]:
	var out: Array[Hazard] = []
	for b: Dictionary in _blasts:
		if (b["hazard"] as Hazard).is_active():
			out.append(b["hazard"])
	return out


## The spot's centre on the floor (world space).
func spot_world() -> Vector3:
	return Vector3(spot_x, 0.03, TrackGeometry.world_z(spot_d))


## One physics step of the run (FloatingHead's pattern calls it every frame of its fight).
func tick(delta: float) -> void:
	clock += delta
	_update_drops()
	_update_blasts()
	if running:
		run_time += delta
		step_time += delta
		_update_light(delta)
		if run_time >= run_seconds - 0.0001 and step != Step.LOCK:
			stop()
	_update_visuals(delta)


# --- The light ------------------------------------------------------------------------------

## The warning's length at this phase's pace.
func lock_time() -> float:
	return tuning.lock_seconds / head.pace()


## How far ahead of the runner the spot hunts: where they will be when a bomb it drops now goes off.
func _lead() -> float:
	return world.player.speed * (lock_time() + tuning.arrival_seconds)


func _update_light(delta: float) -> void:
	var geo: TrackGeometry = world.geo
	var ahead: float = world.player.distance + _lead()
	var sweep: float = tuning.sweep_speed * head.pace() * delta
	_swept += delta
	match step:
		Step.SWEEP_OUT, Step.SWEEP_IN:
			spot_d = move_toward(spot_d, ahead, (world.player.speed + CATCH_UP) * delta)
			var lane: int = _out_lane if step == Step.SWEEP_OUT else head.player_lane()
			spot_x = move_toward(spot_x, geo.lane_x(lane), sweep)
			if step == Step.SWEEP_OUT:
				if absf(spot_x - geo.lane_x(lane)) < 0.01:
					_set_step(Step.SWEEP_IN)
			else:
				var on_lane: bool = absf(spot_x - geo.lane_x(lane)) <= ON_LANE and absf(spot_d - ahead) < 0.5
				_settled = _settled + delta if on_lane else 0.0
				if _settled >= tuning.settle_seconds / head.pace() and _swept >= tuning.sweep_seconds / head.pace():
					_try_lock()
		Step.LOCK:
			pass


## Locks on the runner's lane where the spot rests, if the rules allow it there now.
func _try_lock() -> void:
	var lt: float = lock_time()
	if run_time + lt > run_seconds:
		return
	var pl: int = head.player_lane()
	var at: float = spot_d
	var lanes: Array[int] = plan(pl, at)
	if lanes.is_empty():
		return
	locks += 1
	var geo: TrackGeometry = world.geo
	var x: float = 0.0
	for l: int in lanes:
		x += geo.lane_x(l)
	x /= lanes.size()
	spot_x = x
	target = {"lanes": lanes, "at": at, "x": x, "lock": clock, "impact": clock + lt}
	for i: int in lanes.size():
		var lane: int = lanes[i]
		var impact: float = clock + lt
		_drops.append({"lane": lane, "at": at, "x": geo.lane_x(lane), "release": clock + i * SECOND_BOMB_DELAY,
			"impact": impact, "whistle": maxf(clock, impact - _whistle), "released": false, "whistled": false,
			"circle": head.props.circle_warning(at, lane, tuning.blast_radius), "bomb": null, "from": Vector3.ZERO})
	head.sound(&"searchlight_lock", spot_world())
	head.log_event(&"lock", {"lanes": lanes.duplicate(), "at": at, "player_lane": pl, "d0": world.player.distance,
		"warning": lt, "straddle": lanes.size() > 1})
	_set_step(Step.LOCK)


## The lanes a lock on `pl` at track distance `at` would strike now: two side by side on every
## straddle_every-th lock where both are fair, else the one, or none if even that isn't fair.
func plan(pl: int, at: float) -> Array[int]:
	var n: int = world.geo.lane_count
	if tuning.straddle_every > 0 and (locks + 1) % tuning.straddle_every == 0 and n >= 3:
		var sides: Array[int] = [-1, 1]
		if head.rng.randf() < 0.5:
			sides.reverse()
		for s: int in sides:
			var other: int = pl + s
			if other < 0 or other >= n:
				continue
			var pair: Array[int] = [mini(pl, other), maxi(pl, other)]
			if fair(pair, pl, at):
				return pair
	var single: Array[int] = [pl]
	if fair(single, pl, at):
		return single
	var none: Array[int] = []
	return none


## The fairness rules for bombs on `lanes` at `at` while the runner is in lane `pl` (see the header).
func fair(lanes: Array[int], pl: int, at: float) -> bool:
	for l: int in lanes:
		if not _clear(l, at - tuning.clear_before_impact, at + tuning.clear_after_impact) or _pickup_near(l, at):
			return false
	if head.arena != null and head.arena.ceiling_between(at - 8.0, at + 4.0):
		return false
	return escape_lane(lanes, pl, world.player.distance, at) >= 0


## The nearest lane a runner in `pl` at `d0` can switch to out of bombs on `lanes` at `at`: not struck,
## at most max_escape_lanes away, and it and every lane on the way free of holes and fences from `d0`
## to escape_clear_after past the blast. -1 if there is none.
func escape_lane(lanes: Array[int], pl: int, d0: float, at: float) -> int:
	var n: int = world.geo.lane_count
	for dist: int in range(1, tuning.max_escape_lanes + 1):
		for s: int in [-1, 1]:
			var e: int = pl + s * dist
			if e < 0 or e >= n or lanes.has(e):
				continue
			var ok: bool = true
			for l: int in range(mini(pl, e), maxi(pl, e) + 1):
				if l != pl and not _clear(l, d0, at + tuning.escape_clear_after):
					ok = false
					break
			if ok:
				return e
	return -1


func _clear(lane: int, from: float, to: float) -> bool:
	return head.arena == null or head.arena.floor_clear(from, to, lane)


func _pickup_near(lane: int, at: float) -> bool:
	if world.pickups == null:
		return false
	for p: Pickup in world.pickups.active:
		if is_instance_valid(p) and p.lane == lane and absf(p.at - at) < tuning.pickup_margin:
			return true
	return false


## After a blast the light swings away across the lanes before it hunts again: a seeded pick among
## the lanes 1 to sweep_out_lanes from the runner's.
func _pick_out_lane() -> int:
	var pl: int = head.player_lane()
	var choices: Array[int] = []
	for l: int in world.geo.lane_count:
		var d: int = absi(l - pl)
		if d >= 1 and d <= tuning.sweep_out_lanes:
			choices.append(l)
	if choices.is_empty():
		return pl
	return choices[head.rng.randi() % choices.size()]


func _set_step(next: Step) -> void:
	step = next
	step_time = 0.0
	_settled = 0.0


# --- Bombs and blasts ---------------------------------------------------------------------------

func _update_drops() -> void:
	for i: int in range(_drops.size() - 1, -1, -1):
		var d: Dictionary = _drops[i]
		if not d["released"] and clock >= float(d["release"]):
			d["released"] = true
			d["bomb"] = _free_bomb()
			d["from"] = head.body.bay_world() + Vector3((float(d["x"]) - float(target.get("x", d["x"]))) * 0.4, 0.0, 0.0)
		if not d["whistled"] and clock >= float(d["whistle"]):
			d["whistled"] = true
			head.sound(&"bomb_whistle", Vector3(float(d["x"]), 1.0, TrackGeometry.world_z(float(d["at"]))))
		var bomb: MeshInstance3D = d["bomb"]
		if bomb != null:
			_place_bomb(bomb, d)
		if clock >= float(d["impact"]) - 0.0001:
			if bomb != null:
				bomb.visible = false
			head.props.remove(d["circle"])
			_drops.remove_at(i)
			_blast(int(d["lane"]), float(d["at"]))
	if step == Step.LOCK and _drops.is_empty():
		target = {}
		_out_lane = _pick_out_lane()
		_set_step(Step.SWEEP_OUT)
		_swept = 0.0


## A bomb on its way down: from the bay to the target circle, falling ever faster, nose first.
func _place_bomb(bomb: MeshInstance3D, d: Dictionary) -> void:
	var t0: float = float(d["release"])
	var s: float = clampf((clock - t0) / maxf(float(d["impact"]) - t0, 0.01), 0.0, 1.0)
	var from: Vector3 = d["from"]
	var to := Vector3(float(d["x"]), 0.25, TrackGeometry.world_z(float(d["at"])))
	var pos := Vector3(lerpf(from.x, to.x, s), lerpf(from.y, to.y, s * s), lerpf(from.z, to.z, s))
	var vel := Vector3(to.x - from.x, 2.0 * s * (to.y - from.y) - 0.5, to.z - from.z)
	bomb.visible = true
	bomb.global_position = pos
	if vel.length() > 0.01:
		var up: Vector3 = Vector3.UP if absf(vel.normalized().y) < 0.98 else Vector3.BACK
		bomb.look_at(pos + vel, up)


## The blast: its hitbox burns for blast_seconds; the fireball, the sparks, the boom and a shake.
func _blast(lane: int, at: float) -> void:
	var geo: TrackGeometry = world.geo
	var half: float = geo.lane_width * tuning.blast_width_share * 0.5
	var x: float = geo.lane_x(lane)
	# A wall runner's body reaches this far in from the wall's face: the blast keeps clear of it.
	var reach: float = geo.wall_x() - world.tuning.hurtbox_size.y - 0.05
	var x0: float = maxf(x - half, -reach)
	var x1: float = minf(x + half, reach)
	var hazard: Hazard = _free_hazard()
	var size := Vector3(x1 - x0, tuning.blast_height, tuning.blast_depth)
	hazard.size = size
	((hazard.get_child(0) as CollisionShape3D).shape as BoxShape3D).size = size
	hazard.global_position = Vector3((x0 + x1) * 0.5, size.y * 0.5, TrackGeometry.world_z(at))
	hazard.set_enabled(true)
	var fire: MeshInstance3D = _free_fire()
	fire.global_position = Vector3(x, 0.6, TrackGeometry.world_z(at))
	fire.visible = true
	_blasts.append({"hazard": hazard, "fire": fire, "x": x, "at": at, "start": clock})
	var center := Vector3(x, 0.8, TrackGeometry.world_z(at))
	world.effects.burst(center, FIRE, 40, 1.1)
	world.effects.burst(center + Vector3(0.0, 0.4, 0.0), FIRE_HOT, 16, 0.6)
	var near: float = clampf(1.0 - (at - world.player.distance) / 40.0, 0.2, 1.0)
	world.effects.shake(0.3 * near, 0.3)
	head.sound(&"bomb_blast", center)
	head.log_event(&"blast", {"lane": lane, "at": at})


func _update_blasts() -> void:
	for i: int in range(_blasts.size() - 1, -1, -1):
		var b: Dictionary = _blasts[i]
		var age: float = clock - float(b["start"])
		var hazard: Hazard = b["hazard"]
		if hazard.is_active() and age >= tuning.blast_seconds - 0.0001:
			hazard.set_enabled(false)
		var fire: MeshInstance3D = b["fire"]
		if age >= FIRE_SECONDS:
			fire.visible = false
			if not hazard.is_active():
				_blasts.remove_at(i)
			continue
		# A fireball that swells fast, reddens and fades (a softer flash with Reduced flashing).
		var k: float = age / FIRE_SECONDS
		var r: float = tuning.blast_radius * (0.4 + 0.6 * (1.0 - pow(1.0 - minf(age / 0.12, 1.0), 3.0)))
		fire.scale = Vector3(r, r * 1.2, r)
		var hot: float = clampf(1.0 - age / 0.08, 0.0, 1.0) * (0.4 if Settings.flashing_reduced else 0.8)
		var color: Color = FIRE.lerp(FIRE_HOT, hot) * (1.0 - k * k) * 0.95
		(fire.material_override as StandardMaterial3D).albedo_color = Color(color.r, color.g, color.b, 1.0)


# --- Visuals ------------------------------------------------------------------------------------

func _update_visuals(delta: float) -> void:
	var lit: bool = running or step == Step.LOCK
	_light = move_toward(_light, 1.0 if lit else 0.0, delta / 0.25)
	_red = move_toward(_red, 1.0 if step == Step.LOCK else 0.0, delta / 0.12)
	var body: FloatingHeadBody = head.body
	if body == null or not is_instance_valid(body):
		_beam.visible = false
		_spot.visible = false
		return
	body.lamp = FloatingHeadBody.Lamp.OFF if not lit else (FloatingHeadBody.Lamp.LOCK if step == Step.LOCK
		else FloatingHeadBody.Lamp.SWEEP)
	var spot: Vector3 = spot_world()
	body.lamp_target = spot
	_beam.visible = _light > 0.0
	_spot.visible = _light > 0.0
	if _light <= 0.0:
		return
	var color: Color = LIGHT_WHITE.lerp(LIGHT_RED, _red)
	# The spot: a lane wide while it sweeps, tighter once it lingers, over both lanes of a straddle;
	# the light falls through a hole in the floor instead of lighting it.
	var rx: float = tuning.spot_radius
	var rz: float = tuning.spot_radius
	if not target.is_empty():
		var lanes: Array = target["lanes"]
		rx = tuning.blast_radius * 1.2 + (world.geo.lane_width * 0.5 if lanes.size() > 1 else 0.0)
		rz = tuning.blast_radius * 1.3
	var over_hole: bool = target.is_empty() and head.arena != null \
		and head.arena.hole_between(spot_d - 0.4, spot_d + 0.4, _nearest_lane(spot_x))
	_spot.global_transform = Transform3D(Basis.from_scale(Vector3(rx, 1.0, rz)), spot)
	_spot_material.set_shader_parameter(&"light_color", color)
	_spot_material.set_shader_parameter(&"strength", (0.0 if over_hole else 1.6) * _light)
	var from: Vector3 = body.lamp_world()
	var dir: Vector3 = spot - from
	var length: float = dir.length()
	if length > 0.5:
		var up: Vector3 = Vector3.UP if absf(dir.normalized().y) < 0.98 else Vector3.BACK
		var r: float = maxf(rx, rz) * 0.85
		_beam.global_transform = Transform3D(Basis.looking_at(dir, up) * Basis.from_scale(Vector3(r, r, length)), from)
	_beam_material.set_shader_parameter(&"light_color", color)
	_beam_material.set_shader_parameter(&"strength", (1.0 + 0.4 * _red) * _light)


func _nearest_lane(x: float) -> int:
	var geo: TrackGeometry = world.geo
	return clampi(roundi(x / geo.lane_width + (geo.lane_count - 1) * 0.5), 0, geo.lane_count - 1)


# --- Pools and meshes ---------------------------------------------------------------------------

func _free_bomb() -> MeshInstance3D:
	for b: MeshInstance3D in _bombs:
		if not b.visible:
			return b
	var extra: MeshInstance3D = _mesh_node(FloatingHeadModel.bomb_mesh(), null, "Bomb")
	_bombs.append(extra)
	return extra


func _free_hazard() -> Hazard:
	for h: Hazard in _hazards:
		if not h.is_active() and not _burning(h):
			return h
	var extra: Hazard = _make_hazard()
	_hazards.append(extra)
	return extra


func _burning(h: Hazard) -> bool:
	for b: Dictionary in _blasts:
		if b["hazard"] == h:
			return true
	return false


func _free_fire() -> MeshInstance3D:
	for f: MeshInstance3D in _fires:
		if not f.visible:
			return f
	return _fires[0]


func _make_hazard() -> Hazard:
	var hazard := Hazard.new()
	hazard.name = "Blast"
	hazard.hazard_name = BOMB_NAME
	hazard.is_enemy_attack = true
	hazard.part = &"attack"
	hazard.collision_layer = TrackBuilder.LAYER_HAZARD
	hazard.collision_mask = 0
	hazard.monitoring = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE
	shape.shape = box
	hazard.add_child(shape)
	add_child(hazard)
	hazard.set_enabled(false)
	return hazard


func _mesh_node(mesh: Mesh, material: Material, node_name: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


## The beam: an open cone along -z from radius 0.3 at the lamp (z = 0) to 1 at the floor (z = -1),
## with normals for its soft edges and UV.y running along it.
static func _cone_mesh() -> ArrayMesh:
	if _cone != null:
		return _cone
	var sides: int = 16
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	for i: int in sides:
		var a0: float = TAU * i / sides
		var a1: float = TAU * (i + 1) / sides
		var n0 := Vector3(cos(a0), sin(a0), 0.0)
		var n1 := Vector3(cos(a1), sin(a1), 0.0)
		var p00: Vector3 = n0 * 0.3
		var p01: Vector3 = n1 * 0.3
		var p10: Vector3 = n0 + Vector3(0, 0, -1)
		var p11: Vector3 = n1 + Vector3(0, 0, -1)
		verts.append_array(PackedVector3Array([p00, p10, p11, p00, p11, p01]))
		normals.append_array(PackedVector3Array([n0, n0, n1, n0, n1, n1]))
		uvs.append_array(PackedVector2Array([Vector2(float(i) / sides, 0), Vector2(float(i) / sides, 1),
			Vector2(float(i + 1) / sides, 1), Vector2(float(i) / sides, 0), Vector2(float(i + 1) / sides, 1),
			Vector2(float(i + 1) / sides, 0)]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	_cone = ArrayMesh.new()
	_cone.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _cone


## The spot: a flat square from -1 to 1 on the floor, facing up, UV 0-1 over it.
static func _quad_mesh() -> ArrayMesh:
	if _quad != null:
		return _quad
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-1, 0, 1), Vector3(-1, 0, -1), Vector3(1, 0, -1),
		Vector3(-1, 0, 1), Vector3(1, 0, -1), Vector3(1, 0, 1)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(0, 0),
		Vector2(1, 1), Vector2(1, 0)])
	_quad = ArrayMesh.new()
	_quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _quad

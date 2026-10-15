class_name MechaGuppyBarrage
extends Node3D
## Captain Cogs' barrages in phase 3 (GDD §10; the owner, October 15, 2026: "since Captain Cogs is on the left side, his
## attacks should come at the player horizontally ... they need to be jumpable and dodgeable ... the captain will release
## a barrage. Some will be up high and some will be down low. And these bombs should probably be a little bit smaller";
## "As the player dodges these attacks, the Mecha Guppy is in turn hit with the attacks"; task E5e-g). MechaGuppyTop fires
## each bomb on its beat:
## - fire(): the warning. The captain's swivel gun on his stern castle charges (cogs_charge, as long as bomb_warning) and a
##   red line
##   across every lane shows at the runner's distance, at the height the bomb will fly (BossProps.WARNING_COLOR: low, a
##   jump; high, a slide; pulsing, steady with Reduced flashing), keeping pace with them;
## - bomb_warning later the shot (cogs_cannon; CaptainCogsShip.fire_swivel: the flash, smoke and recoil): a bomb (Captain
##   Cogs' own, MechaGuppyBombs.bomb_mesh, bomb_radius: smaller than the old cannonball) leaves the swivel gun, comes down
##   and in over the eaves onto the line (a smooth curve, outside the lanes) and flies straight across every lane along the line at
##   bomb_speed, keeping pace with the runner, so it crosses each lane at their distance: a low one jumped (its hitbox's
##   top under a jump's feet), a high one slid under (its hitbox's bottom over a slide's hurtbox, under a standing one's);
##   its hitbox (a little smaller than the bomb: GDD §3) is an enemy attack, live over the deck only (armor and the shield
##   block it, the dash passes through it);
## - past the far eaves it turns on into Mecha Guppy's head beside the top, a little ahead (MechaGuppyShark.top_flank_x,
##   top_flank_ahead; a curve as smooth as its first, outside the lanes): a hit
##   (MechaGuppyTop.bomb_landed: the clang, the fireball, a shudder, and the boss bar drops). A bomb that met the runner
##   (armor or the shield took it) bursts there instead and hits nothing.
## Its time from the warning to the runner never changes with the run's speed (it keeps pace with them). Its own clock runs
## on the boss's ticks (time from the physics step; it waits while the runner is down). DESIGN-TBD (docs/questions/e5e-g.md):
## the bombs' numbers and the warning's look.

const BOMB_NAME: String = "Captain Cogs' bomb"
## The hitbox against the bomb (GDD §3: a little smaller than the visual): its share of the bomb's diameter across, up and
## along the track.
const HIT_WIDTH: float = 0.8
const HIT_HEIGHT: float = 0.85
const HIT_DEPTH: float = 0.8
## Where its curve from the swivel gun joins the line, and where it leaves it for Mecha Guppy: this far out past the deck's
## wall lines (over the eaves' outer part).
const ENTRY_OUT: float = 0.9
## The hitbox is live while the bomb's middle is within this far out past either wall line.
const LIVE_OUT: float = 0.4
## The red line: its thickness, and how far past the wall lines it reaches either side.
const LINE_THICK: float = 0.07
const LINE_PAST: float = 0.6
## How finely its curve is sampled (its length, and where it is along it).
const CURVE_SAMPLES: int = 16
## A bomb that met the runner bursts this long after (seconds: the damage rules have had their frame).
const BURST_AFTER: float = 0.02
## The burst's look (a bomb blocked by armor or the shield).
const BURST_RADIUS: float = 0.9

enum State { WARN, FLY, DONE }

var boss: MechaGuppy
var world: RunWorld
var tuning: MechaGuppyTuning
## Seconds of barrages so far (its bombs keep to this clock).
var clock: float = 0.0
## Bombs warned, shot, landed in Mecha Guppy and burst on the runner over the fight (tests).
var fired: int = 0
var shot: int = 0
var landed: int = 0
var burst: int = 0
## The bombs under way: {k (its beat), n (its place in its barrage), high (bool), y (its middle over the deck), start,
## shot (clock), d0 (the runner as it was warned), line (MeshInstance3D), node, hazard, path ({points, lengths} in the
## runner's frame: x, height over the deck, metres ahead of them), entry (the length along the path where the line begins),
## state, touched (clock it met the runner, or -1), passed (clock it passed the runner's lane)}.
var bombs: Array[Dictionary] = []
## The callback as a bomb reaches Mecha Guppy: Callable(bomb: Dictionary, point: Vector3) (MechaGuppyTop.bomb_landed).
var on_landed: Callable

var _pool: Array[Node3D] = []
var _hazards: Array[Hazard] = []
var _line_mesh: BoxMesh
var _line_material: StandardMaterial3D


func setup(p_boss: MechaGuppy) -> void:
	boss = p_boss
	world = boss.world
	tuning = boss.tuning
	top_level = true
	transform = Transform3D.IDENTITY
	_line_mesh = BoxMesh.new()
	_line_material = (GreyboxMaterials.glow(BossProps.WARNING_COLOR, 1.2, 0.9).duplicate() as StandardMaterial3D)
	_line_material.disable_fog = true


## Everything off: lines gone, bombs hidden, hitboxes off (the fight is won).
func clear() -> void:
	for b: Dictionary in bombs:
		_end(b)
	bombs.clear()


## True while a bomb is warned or flying.
func busy() -> bool:
	return not bombs.is_empty()


## One physics step (MechaGuppy's ticks drive it).
func tick(delta: float) -> void:
	clock += delta
	var pulse: float = 1.0 if Settings.flashing_reduced else 0.65 + 0.35 * absf(sin(clock * 12.0))
	_line_material.albedo_color = Color(BossProps.WARNING_COLOR, 0.9 * pulse)
	# A landing may win the fight, which clears every bomb (clear()): go over a copy, then keep the ones still under way.
	for b: Dictionary in bombs.duplicate():
		if int(b["state"]) != State.DONE:
			_advance(b)
	var keep: Array[Dictionary] = []
	for b: Dictionary in bombs:
		if int(b["state"]) != State.DONE:
			keep.append(b)
	bombs = keep


## Fires bomb `n` of beat `k`'s barrage, `high` or low: its warning starts now (see the header). Returns its record.
func fire(k: int, n: int, high: bool) -> Dictionary:
	var p: Player = world.player
	var y: float = tuning.high_height if high else tuning.low_height
	var b: Dictionary = {"k": k, "n": n, "high": high, "y": y, "start": clock, "shot": clock + tuning.bomb_warning,
		"d0": p.distance, "node": null, "hazard": null, "path": {}, "entry": 0.0, "state": State.WARN, "touched": -1.0,
		"passed": -1.0}
	var line := MeshInstance3D.new()
	line.name = "BombWarning"
	line.mesh = _line_mesh
	line.material_override = _line_material
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var span: float = (world.geo.wall_x() + LINE_PAST) * 2.0
	line.scale = Vector3(span, LINE_THICK, LINE_THICK)
	add_child(line)
	b["line"] = line
	_place_line(b)
	bombs.append(b)
	fired += 1
	boss.sound(&"cogs_charge", _cannon_point())
	boss.log_event(&"bomb_warning", {"k": k, "n": n, "high": high, "lane": p.lane, "d0": p.distance,
		"meets": meet_seconds(p.lane)})
	return b


## The live bombs' hitboxes (tests).
func bomb_hazards() -> Array[Hazard]:
	var out: Array[Hazard] = []
	for b: Dictionary in bombs:
		var h: Hazard = b["hazard"]
		if h != null and h.is_active():
			out.append(h)
	return out


## The bombs coming at the runner (the bot): [{high, at (seconds from now until the bomb's middle reaches world x `x`),
## warned (seconds since its warning showed)}], soonest first; only those whose middle hasn't reached `x` yet.
func incoming(x: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b: Dictionary in bombs:
		if int(b["state"]) == State.DONE or float(b["touched"]) >= 0.0:
			continue
		var path: Dictionary = b["path"] if int(b["state"]) == State.FLY else _path_now(b)
		var along: float = _length_at_x(path, x)
		if is_nan(along):
			continue
		var flown: float = maxf(clock - float(b["shot"]), 0.0) * tuning.bomb_speed
		if along < flown:
			continue
		out.append({"high": bool(b["high"]), "at": float(b["shot"]) - clock + along / tuning.bomb_speed,
			"warned": clock - float(b["start"])})
	out.sort_custom(func(a: Dictionary, c: Dictionary) -> bool: return float(a["at"]) < float(c["at"]))
	return out


## Seconds from a bomb's warning until its middle reaches lane `lane`'s middle (with the ship level, as it is in phase 3).
func meet_seconds(lane: int) -> float:
	return tuning.bomb_warning + _length_at_x(_path_now({"y": tuning.low_height}), world.geo.lane_x(lane)) / tuning.bomb_speed


## The hitbox's size for `t`'s bombs: smaller than the bomb.
static func hit_size(t: MechaGuppyTuning) -> Vector3:
	var d: float = t.bomb_radius * 2.0
	return Vector3(d * HIT_WIDTH, d * HIT_HEIGHT, d * HIT_DEPTH)


## A bomb's hitbox from the deck up (metres): Vector2(bottom, top), `high` or low, for `t`'s numbers.
static func hit_band(t: MechaGuppyTuning, high: bool) -> Vector2:
	var y: float = t.high_height if high else t.low_height
	var h: float = hit_size(t).y * 0.5
	return Vector2(maxf(y - h, 0.0), y + h)


## A bomb's path in the runner's frame from the swivel gun's muzzle `muzzle` (x, height over the deck, metres ahead of the
## runner) to the line at height `y`, across the deck along it, then on to `to` (Mecha Guppy's flank, at the bomb's
## height): {points, lengths, entry and exit (the lengths where it joins and leaves the line), entry_x, exit_x}. Its curves
## leave the muzzle outward (+x), join the line along it and leave it along it (cubics through the eaves' air: nothing
## over the lanes but the line). `wall`: the deck's wall line.
static func path(muzzle: Vector3, y: float, wall: float, to: Vector3) -> Dictionary:
	var entry := Vector3(-wall - ENTRY_OUT, y, 0.0)
	var leave := Vector3(wall + ENTRY_OUT, y, 0.0)
	var end := Vector3(maxf(to.x, leave.x + 0.5), y, to.z)
	var points := PackedVector3Array([muzzle])
	var lengths := PackedFloat32Array([0.0])
	_curve(points, lengths, muzzle, entry)
	var on_line: float = lengths[-1]
	points.append(leave)
	lengths.append(on_line + leave.x - entry.x)
	var off_line: float = lengths[-1]
	_curve(points, lengths, leave, end)
	return {"points": points, "lengths": lengths, "entry": on_line, "exit": off_line, "entry_x": entry.x,
		"exit_x": leave.x}


## Appends a cubic from `a` to `b` leaving and arriving along +x (CURVE_SAMPLES points after `a`) to `points`, with their
## lengths along the path.
static func _curve(points: PackedVector3Array, lengths: PackedFloat32Array, a: Vector3, b: Vector3) -> void:
	var reach: float = maxf(absf(b.x - a.x), 0.5) * 0.5
	var c1: Vector3 = a + Vector3(reach, 0.0, 0.0)
	var c2: Vector3 = b - Vector3(reach, 0.0, 0.0)
	var last: Vector3 = a
	for i: int in range(1, CURVE_SAMPLES + 1):
		var u: float = float(i) / float(CURVE_SAMPLES)
		var v: float = 1.0 - u
		var q: Vector3 = a * v * v * v + c1 * 3.0 * v * v * u + c2 * 3.0 * v * u * u + b * u * u * u
		points.append(q)
		lengths.append(lengths[-1] + q.distance_to(last))
		last = q


## Where along `p` (its length) its middle is at world x `x` on the line, or NAN off it.
static func _length_at_x(p: Dictionary, x: float) -> float:
	var x0: float = float(p["entry_x"])
	var x1: float = float(p["exit_x"])
	if x < x0 - 0.001 or x > x1 + 0.001:
		return NAN
	return float(p["entry"]) + (x - x0)


## The point `s` along `p` (the runner's frame).
static func point_at(p: Dictionary, s: float) -> Vector3:
	var points: PackedVector3Array = p["points"]
	var lengths: PackedFloat32Array = p["lengths"]
	if s <= 0.0:
		return points[0]
	for i: int in range(1, points.size()):
		if s <= lengths[i] or i == points.size() - 1:
			var span: float = lengths[i] - lengths[i - 1]
			var k: float = clampf((s - lengths[i - 1]) / span, 0.0, 1.0) if span > 0.0001 else 1.0
			return points[i - 1].lerp(points[i], k)
	return points[-1]


func _advance(b: Dictionary) -> void:
	_place_line(b)
	match int(b["state"]):
		State.WARN:
			if clock >= float(b["shot"]) - 0.0001:
				_shoot(b)
		State.FLY:
			var p: Player = world.player
			var path: Dictionary = b["path"]
			var s: float = (clock - float(b["shot"])) * tuning.bomb_speed
			var at: Vector3 = point_at(path, s)
			var node: Node3D = b["node"]
			node.global_position = _world(at)
			node.rotate_z(-tuning.bomb_speed / maxf(tuning.bomb_radius, 0.1) * get_physics_process_delta_time())
			var hazard: Hazard = b["hazard"]
			var wall: float = world.geo.wall_x()
			var live: bool = s >= float(b["entry"]) and s <= float(path["exit"]) and absf(at.x) <= wall + LIVE_OUT \
				and float(b["touched"]) < 0.0
			hazard.set_enabled(live)
			if live:
				hazard.global_position = _world(at)
				var box := AABB(hazard.global_position - hazard.size * 0.5, hazard.size)
				if p.alive and not p.dashing and box.intersects(p.hurtbox_aabb()):
					b["touched"] = clock
					boss.log_event(&"bomb_touched", {"k": int(b["k"]), "n": int(b["n"]), "lane": p.lane})
			if float(b["passed"]) < 0.0 and at.x > p.position.x + world.tuning.hurtbox_size.x * 0.5 + hit_size(tuning).x * 0.5:
				b["passed"] = clock
				if b["line"] != null:
					(b["line"] as Node).queue_free()
					b["line"] = null
				boss.log_event(&"bomb_passed", {"k": int(b["k"]), "n": int(b["n"]), "high": bool(b["high"])})
			if float(b["touched"]) >= 0.0 and clock - float(b["touched"]) >= BURST_AFTER:
				_burst(b, node.global_position)
			elif s >= float((path["lengths"] as PackedFloat32Array)[-1]) - 0.0001:
				_land(b, node.global_position)


## The shot: the swivel gun fires, the bomb leaves its muzzle on its path.
func _shoot(b: Dictionary) -> void:
	b["state"] = State.FLY
	b["path"] = _path_now(b)
	b["entry"] = float((b["path"] as Dictionary)["entry"])
	if boss.ship != null and is_instance_valid(boss.ship):
		boss.ship.fire_swivel()
	var node: Node3D = _free_bomb()
	node.visible = true
	node.global_position = _world(point_at(b["path"], 0.0))
	b["node"] = node
	var hazard: Hazard = _free_hazard()
	var size: Vector3 = hit_size(tuning)
	((hazard.get_child(0) as CollisionShape3D).shape as BoxShape3D).size = size
	hazard.size = size
	hazard.set_enabled(false)
	b["hazard"] = hazard
	shot += 1
	boss.sound(&"cogs_cannon", _cannon_point())
	boss.log_event(&"bomb_shot", {"k": int(b["k"]), "n": int(b["n"]), "high": bool(b["high"])})


## Its path from where the swivel gun's muzzle is now (the runner's frame).
func _path_now(b: Dictionary) -> Dictionary:
	var p: Player = world.player
	var muzzle_w: Vector3 = boss.ship.swivel_world() if boss.ship != null and is_instance_valid(boss.ship) \
		else Vector3(-world.geo.wall_x() - 4.0, p.floor_base + 1.0, TrackGeometry.world_z(p.distance + 6.0))
	var muzzle := Vector3(muzzle_w.x, muzzle_w.y - p.floor_base, -muzzle_w.z - p.distance)
	var to := Vector3(world.geo.wall_x() + 3.0, float(b["y"]), 0.0)
	if boss.shark != null:
		to = Vector3(boss.shark.top_flank_x(), float(b["y"]), boss.shark.top_flank_ahead())
	return path(muzzle, float(b["y"]), world.geo.wall_x(), to)


## It reaches Mecha Guppy's head: MechaGuppyTop counts the hit.
func _land(b: Dictionary, point: Vector3) -> void:
	landed += 1
	boss.log_event(&"bomb_landed", {"k": int(b["k"]), "n": int(b["n"])})
	_end(b)
	if on_landed.is_valid():
		on_landed.call(b, point)


## It met the runner (armor or the shield took it; or it killed them): it bursts there, and hits nothing.
func _burst(b: Dictionary, point: Vector3) -> void:
	burst += 1
	world.effects.fireball(point, BURST_RADIUS, true, 0.8, 0.4)
	boss.log_event(&"bomb_burst", {"k": int(b["k"]), "n": int(b["n"])})
	_end(b)


## A bomb's look and hitbox gone.
func _end(b: Dictionary) -> void:
	b["state"] = State.DONE
	if b["line"] != null and is_instance_valid(b["line"]):
		(b["line"] as Node).queue_free()
	b["line"] = null
	if b["node"] != null:
		(b["node"] as Node3D).visible = false
	if b["hazard"] != null:
		(b["hazard"] as Hazard).set_enabled(false)


## The red line across the lanes at the runner's distance, at the bomb's height, until it has passed them.
func _place_line(b: Dictionary) -> void:
	var line: MeshInstance3D = b["line"]
	if line == null or not is_instance_valid(line):
		return
	var p: Player = world.player
	line.global_position = Vector3(0.0, p.floor_base + float(b["y"]), TrackGeometry.world_z(p.distance))


## A point in the runner's frame (x, height over the deck, metres ahead) in the world, now.
func _world(at: Vector3) -> Vector3:
	var p: Player = world.player
	return Vector3(at.x, p.floor_base + at.y, TrackGeometry.world_z(p.distance + at.z))


## Where the charge and the shot are heard: the swivel gun (or beside the top without a ship).
func _cannon_point() -> Vector3:
	if boss.ship != null and is_instance_valid(boss.ship):
		return boss.ship.swivel_world()
	var p: Player = world.player
	return Vector3(-world.geo.wall_x() - 4.0, p.floor_base + 1.0, TrackGeometry.world_z(p.distance))


# --- Pools -----------------------------------------------------------------------------------------

func _free_bomb() -> Node3D:
	for b: Node3D in _pool:
		if not b.visible:
			return b
	var node := MeshInstance3D.new()
	node.name = "Bomb"
	var beach := world.skin as BeachSkin
	node.mesh = MechaGuppyBombs.bomb_mesh(beach.solid_material() if beach != null else null)
	if beach == null:
		node.material_override = GreyboxMaterials.scenery(Color(0.1, 0.1, 0.11))
	# bomb_mesh is 0.45 m in radius.
	node.scale = Vector3.ONE * (tuning.bomb_radius / 0.45)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visible = false
	add_child(node)
	_pool.append(node)
	return node


func _free_hazard() -> Hazard:
	for h: Hazard in _hazards:
		if not h.is_active() and not _holding(h):
			return h
	var hazard := Hazard.new()
	hazard.name = "BombHit"
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
	_hazards.append(hazard)
	return hazard


func _holding(h: Hazard) -> bool:
	for b: Dictionary in bombs:
		if b["hazard"] == h:
			return true
	return false

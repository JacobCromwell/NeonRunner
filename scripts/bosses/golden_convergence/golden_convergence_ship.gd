class_name GoldenConvergenceShip
extends BossPart
## The Refill Ship (GDD §10, "Damaging the suit: the Refill Ship": "a ship comes in to refill his missiles. It
## feeds them to him along a line running to his shoulder pipes. The ship is a ceiling, like most ships in the
## game"; task E5d-c), a part of the boss made once with the fight and reused for every refill
## (GoldenConvergenceRefill flies it, `set_pose`). Its model is GoldenConvergenceShipModel's, sized to the
## lanes: its belly covers every lane, wall to wall. What it carries:
## - its belly, a ceiling (add_surface(..., true): the hull layer, flush with its underside, every lane) the
##   runner rides from the cage's anti-grav pad, live only while the refill has it down at the ceiling's height
##   (set_belly);
## - its racks of missiles along its flanks (a MultiMesh, each missile blowing up on its own: explode_rack, the
##   chain reaction's ripple), and where the squadron holds beside them, under the racks (hold_point: a hurled
##   drone hits a rack's underside);
## - the feed line from its boom's nozzle to the suit's shoulder pipes (set_line: a dark bronze hose shooting out
##   over `reach`, a gentle sag; ride(): missiles riding up it to the shoulder), and its burning away as the
##   chain's blast races up it (burn_line);
## - the chain reaction's fire (fireball: a swelling, reddening, fading ball, softer with Reduced flashing; spark
##   bursts only without it; dark smoke either way) and the ship's own end (explode: it's gone in a blast).
## A part of the boss that's no target (GDD §10, proposed: weapons never target the ship) and no kill of its own:
## immune to weapons, never targetable, is_obstacle; nothing on it can hurt the runner.

## Fireballs at once (pooled), pieces of the feed line, missiles riding it at once.
const FIREBALLS: int = 12
const SEGMENTS: int = 18
const RIDERS: int = 12
## The line's sag at its middle, over its length.
const SAG: float = 0.1
## Where the squadron holds: this far below the racks' underside, spread along the racks this far apart (from
## HOLD_FROM ahead of its middle).
const HOLD_DROP: float = 3.0
const HOLD_SPACING: float = 6.0
const HOLD_FROM: float = 4.0
## The fire's colours (an explosion's: never on anything that stays, never on a hazard), the smoke's.
const FIRE := Color(1.0, 0.4, 0.13)
const FIRE_HOT := Color(1.0, 0.82, 0.55)
const SMOKE := Color(0.2, 0.18, 0.17)

var tuning: GoldenConvergenceTuning
## Its belly's half width (the walls' line plus the model's overhang).
var half_width: float = 4.0
var belly: StaticBody3D
var hull: MeshInstance3D
## The rack missiles' places (local) and whether each is still there.
var slots: Array[Vector3] = []
var rack_live: Array[bool] = []
## Shown (flying) or gone.
var shown: bool = false
## Rack missiles blown up, fireballs shown (tests).
var racks_blown: int = 0
var fireballs_shown: int = 0
var sparks_shown: int = 0

var _root: Node3D
var _racks: MultiMeshInstance3D
var _segments: MultiMeshInstance3D
var _riders: MultiMeshInstance3D
var _fires: Array[Dictionary] = []
## The line: its ends (world), how far it has shot out (0-1), how much of it from the ship's end has burnt away
## (0-1), whether it shows; the riding missiles' places along it (0-1), and the clock for the next.
var _line_on: bool = false
var _line_from: Vector3 = Vector3.ZERO
var _line_to: Vector3 = Vector3.ZERO
var _line_reach: float = 0.0
var _line_burnt: float = 0.0
var _ride_u: Array[float] = []
var _ride_clock: float = 0.0
var _t: float = 0.0


func _build() -> void:
	var params: Dictionary = spawn.get("params", {})
	tuning = params.get("tuning") as GoldenConvergenceTuning
	if tuning == null:
		tuning = GoldenConvergenceTuning.new()
	display_name = "the Refill Ship"
	is_obstacle = true
	immune_to_weapons = true
	var skin := world.skin as GoldenSkin
	if skin == null:
		skin = GoldenCourtSkin.new()
	var geo: TrackGeometry = world.geo
	half_width = geo.wall_x() + GoldenConvergenceShipModel.OVERHANG
	var edges: Array[float] = []
	for lane: int in range(1, geo.lane_count):
		edges.append(geo.lane_x(lane) - geo.lane_width * 0.5)
	var m: Dictionary = GoldenConvergenceShipModel.meshes(half_width, edges, skin)
	_root = Node3D.new()
	_root.name = "Ship"
	add_child(_root)
	hull = MeshBatch.add_instance(_root, m["hull"], "Hull")
	# It spans far more than its own box once it rolls away: never culled while any of it is in view.
	hull.extra_cull_margin = 30.0
	slots = GoldenConvergenceShipModel.rack_slots(half_width)
	_racks = _multimesh("Racks", m["rack_missile"], slots.size(), false)
	for i: int in slots.size():
		rack_live.append(true)
	_place_racks()
	# The belly: a ceiling over every lane, wall to wall, flush with its underside (off until it's down).
	belly = add_surface(Vector3(geo.wall_x() * 2.0, 0.3, GoldenConvergenceShipModel.LENGTH), Vector3(0.0, 0.15, 0.0), true, _root)
	set_belly(false)
	_segments = _multimesh("FeedLine", m["line_segment"], SEGMENTS, true)
	_riders = _multimesh("Riding", m["line_missile"], RIDERS, true)
	for i: int in FIREBALLS:
		_fires.append(_new_fire())
	set_shown(false)


func _multimesh(node_name: String, mesh: Mesh, count: int, world_space: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	mm.visible_instance_count = count if not world_space else 0
	var inst := MultiMeshInstance3D.new()
	inst.name = node_name
	inst.multimesh = mm
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if world_space:
		inst.top_level = true
		# A line from beside the causeway to the suit's shoulder, far ahead: never culled while any of it shows.
		inst.extra_cull_margin = 200.0
		add_child(inst)
		inst.global_transform = Transform3D.IDENTITY
	else:
		inst.extra_cull_margin = 10.0
		_root.add_child(inst)
	return inst


func _new_fire() -> Dictionary:
	var node := MeshInstance3D.new()
	node.name = "Fireball"
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	node.mesh = sphere
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color.BLACK
	m.disable_receive_shadows = true
	node.material_override = m
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.top_level = true
	node.visible = false
	add_child(node)
	return {"node": node, "age": 0.0, "life": 0.6, "radius": 1.0, "on": false, "from": Vector3.ZERO, "drift": Vector3.ZERO}


# --- Where it is ---------------------------------------------------------------------------------------

## Flies it with its belly's middle at `xform` (world space; its bow toward -z).
func set_pose(xform: Transform3D) -> void:
	global_transform = xform


## Its belly a ceiling (the hull layer) or not.
func set_belly(on: bool) -> void:
	belly.collision_layer = TrackBuilder.LAYER_HULL if on else 0


func belly_on() -> bool:
	return belly.collision_layer != 0


## Shows it (whole: every rack missile back) or takes it away (the line too).
func set_shown(on: bool) -> void:
	shown = on
	_root.visible = on
	if on:
		for i: int in rack_live.size():
			rack_live[i] = true
		_place_racks()
	else:
		set_belly(false)
		hide_line()


## Where it is along the track (its middle).
func track_distance() -> float:
	return -global_position.z


## Its feed boom's nozzle (world space): where the line leaves it.
func boom_point() -> Vector3:
	return global_transform * GoldenConvergenceShipModel.BOOM_TIP


## Drone `i` of `n` holding beside it (world space): under the racks, on the left for even `i` and the right for
## odd, spread along them from ahead of its middle (the runner rides behind its middle).
func hold_point(i: int, _n: int) -> Vector3:
	var side: int = -1 if i % 2 == 0 else 1
	var z: float = -HOLD_FROM - HOLD_SPACING * float(i >> 1) - (HOLD_SPACING * 0.5 if side > 0 else 0.0)
	var local := Vector3(GoldenConvergenceShipModel.rack_x(half_width, side),
		GoldenConvergenceShipModel.rack_bottom() - HOLD_DROP, z)
	return global_transform * local


## How far a drone holding at hold_point is hurled up before it hits the racks (a drone's own height short).
func hurl_rise() -> float:
	return HOLD_DROP - 0.45


## Rack missile `i` (world space).
func rack_point(i: int) -> Vector3:
	return global_transform * slots[i]


func rack_count() -> int:
	return slots.size()


## The rack missiles still there.
func racks_left() -> int:
	var n: int = 0
	for live: bool in rack_live:
		if live:
			n += 1
	return n


func _place_racks() -> void:
	var mm: MultiMesh = _racks.multimesh
	for i: int in slots.size():
		var xform := Transform3D(Basis.IDENTITY, slots[i])
		if not rack_live[i]:
			xform = Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(0.0, -50.0, 0.0))
		mm.set_instance_transform(i, xform)


# --- The chain reaction's fire -----------------------------------------------------------------------------

## Rack missile `i` blows up: gone from its rack, a fireball where it was, sparks (none with Reduced flashing).
func explode_rack(i: int) -> void:
	if i < 0 or i >= rack_live.size() or not rack_live[i]:
		return
	rack_live[i] = false
	racks_blown += 1
	_place_racks()
	var at: Vector3 = rack_point(i)
	fireball(at, 1.5, 0.55)
	if not Settings.flashing_reduced:
		world.effects.burst(at, FIRE, 12, 0.8)
		sparks_shown += 1


## It blows up where it is: fireballs over its length, debris and sparks (no sparks with Reduced flashing), dark
## smoke; it's gone.
func explode() -> void:
	var length: float = GoldenConvergenceShipModel.LENGTH
	for k: int in 3:
		var at: Vector3 = global_transform * Vector3(0.0, 2.0, lerpf(-length * 0.35, length * 0.35, float(k) / 2.0))
		fireball(at, 6.5 - float(k), 1.1 + 0.15 * float(k), Vector3(0.0, 1.5, 0.0))
		world.effects.burst(at, SMOKE, 40, 3.0)
	world.effects.debris(global_position + Vector3(0.0, 2.0, 0.0), GoldenConvergenceShipModel.GOLD, 24, 2.2)
	if not Settings.flashing_reduced:
		world.effects.burst(global_position + Vector3(0.0, 2.0, 0.0), FIRE_HOT, 48, 3.2)
		sparks_shown += 1
	set_shown(false)


## A fireball at `at` (world space), `radius` across at its fullest, gone after `life` seconds: it swells fast,
## reddens and fades, drifting by `drift` m/s (a softer flash with Reduced flashing). Pooled: the oldest gives way.
func fireball(at: Vector3, radius: float, life: float, drift: Vector3 = Vector3.ZERO) -> void:
	var f: Dictionary = _fires[0]
	for candidate: Dictionary in _fires:
		if not bool(candidate["on"]):
			f = candidate
			break
		if float(candidate["age"]) / float(candidate["life"]) > float(f["age"]) / float(f["life"]):
			f = candidate
	f["on"] = true
	f["age"] = 0.0
	f["life"] = maxf(life, 0.1)
	f["radius"] = radius
	f["from"] = at
	f["drift"] = drift
	var node: MeshInstance3D = f["node"]
	node.global_position = at
	node.visible = true
	fireballs_shown += 1
	_paint_fire(f)


## Fireballs burning now (tests).
func fires_on() -> int:
	var n: int = 0
	for f: Dictionary in _fires:
		if bool(f["on"]):
			n += 1
	return n


func _paint_fire(f: Dictionary) -> void:
	var node: MeshInstance3D = f["node"]
	var age: float = float(f["age"])
	var k: float = clampf(age / float(f["life"]), 0.0, 1.0)
	var r: float = float(f["radius"]) * (0.35 + 0.65 * (1.0 - pow(1.0 - minf(age / 0.14, 1.0), 3.0)))
	node.scale = Vector3(r, r * 1.1, r)
	node.global_position = (f["from"] as Vector3) + (f["drift"] as Vector3) * age
	var hot: float = clampf(1.0 - age / 0.1, 0.0, 1.0) * (0.35 if Settings.flashing_reduced else 0.8)
	var color: Color = FIRE.lerp(FIRE_HOT, hot) * (1.0 - k * k) * 0.9
	(node.material_override as StandardMaterial3D).albedo_color = Color(color.r, color.g, color.b, 1.0)


# --- The feed line -------------------------------------------------------------------------------------

## The feed line from `from` (its boom) to `to` (the shoulder's pipes), world space, shot out `reach` (0-1) of
## the way.
func set_line(from: Vector3, to: Vector3, reach: float) -> void:
	_line_on = true
	_line_from = from
	_line_to = to
	_line_reach = clampf(reach, 0.0, 1.0)
	_draw_line()


## The line gone (back into its boom, or burnt away); no missile riding it.
func hide_line() -> void:
	_line_on = false
	_line_reach = 0.0
	_line_burnt = 0.0
	_ride_u.clear()
	if _segments != null:
		_segments.multimesh.visible_instance_count = 0
		_riders.multimesh.visible_instance_count = 0


## The line from its ship's end burnt away up to `u` (0-1): the chain's blast racing up it.
func burn_line(u: float) -> void:
	_line_burnt = clampf(u, 0.0, 1.0)
	_ride_u.clear()
	_draw_line()


func line_shown() -> bool:
	return _line_on and _line_reach > 0.0 and _line_burnt < 1.0


## The point `u` (0-1) along the line, from the boom to the shoulder: a gentle sag.
func line_point(u: float) -> Vector3:
	var a: Vector3 = _line_from
	var b: Vector3 = _line_to
	var c: Vector3 = (a + b) * 0.5 - Vector3(0.0, a.distance_to(b) * SAG, 0.0)
	return a.lerp(c, u).lerp(c.lerp(b, u), u)


## Missiles riding up the line while it's whole and shot out: one every `every` seconds, `speed` m/s along it.
## Called every physics frame while it feeds.
func ride(delta: float, speed: float, every: float) -> void:
	if not _line_on or _line_reach < 1.0 or _line_burnt > 0.0:
		return
	var length: float = maxf(_line_from.distance_to(_line_to), 1.0)
	for k: int in range(_ride_u.size() - 1, -1, -1):
		_ride_u[k] += speed * delta / length
		if _ride_u[k] >= 1.0:
			_ride_u.remove_at(k)
	_ride_clock -= delta
	if _ride_clock <= 0.0 and _ride_u.size() < RIDERS:
		_ride_clock = every
		_ride_u.append(0.0)


## Missiles riding up the line now (tests).
func riding() -> int:
	return _ride_u.size()


func _draw_line() -> void:
	var mm: MultiMesh = _segments.multimesh
	if not _line_on or _line_reach <= 0.0:
		mm.visible_instance_count = 0
		_riders.multimesh.visible_instance_count = 0
		return
	var r: float = GoldenConvergenceShipModel.LINE_RADIUS
	var shown_count: int = 0
	for k: int in SEGMENTS:
		var u0: float = float(k) / SEGMENTS * _line_reach
		var u1: float = float(k + 1) / SEGMENTS * _line_reach
		if u1 <= _line_burnt:
			continue
		u0 = maxf(u0, _line_burnt)
		var a: Vector3 = line_point(u0)
		var b: Vector3 = line_point(u1)
		mm.set_instance_transform(shown_count, _rod(a, b, r))
		shown_count += 1
	mm.visible_instance_count = shown_count
	var rm: MultiMesh = _riders.multimesh
	var n: int = 0
	for u: float in _ride_u:
		if u > _line_reach or n >= RIDERS:
			continue
		var at: Vector3 = line_point(u)
		var ahead: Vector3 = line_point(minf(u + 0.02, 1.0)) - at
		var dir: Vector3 = ahead.normalized() if ahead.length_squared() > 0.0001 else Vector3.FORWARD
		var up: Vector3 = Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
		rm.set_instance_transform(n, Transform3D(Basis.looking_at(dir, up), at + Vector3(0.0, r + 0.15, 0.0)))
		n += 1
	rm.visible_instance_count = n


## The unit rod (y from 0 to 1) from `a` to `b`, `r` thick.
static func _rod(a: Vector3, b: Vector3, r: float) -> Transform3D:
	var axis: Vector3 = b - a
	if axis.length_squared() < 0.000001:
		return Transform3D(Basis.from_scale(Vector3.ZERO), a)
	var side: Vector3 = axis.cross(Vector3.UP if absf(axis.normalized().dot(Vector3.UP)) < 0.95 else Vector3.RIGHT).normalized()
	var x: Vector3 = side * r
	var z: Vector3 = x.cross(axis).normalized() * r
	return Transform3D(Basis(x, axis, z), a)


func _tick(delta: float) -> void:
	_t += delta
	for f: Dictionary in _fires:
		if not bool(f["on"]):
			continue
		f["age"] = float(f["age"]) + delta
		if float(f["age"]) >= float(f["life"]):
			f["on"] = false
			(f["node"] as Node3D).visible = false
			continue
		_paint_fire(f)
	if _line_on:
		_draw_line()


## Every fireball out at once (a test, a fresh fight).
func fires_out() -> void:
	for f: Dictionary in _fires:
		f["on"] = false
		(f["node"] as Node3D).visible = false


# --- For tests ---------------------------------------------------------------------------------------------

## What it draws while shown: {instances, surfaces, vertices}.
func draw_stats() -> Dictionary:
	var instances: int = 0
	var surfaces: int = 0
	var vertices: int = 0
	for mesh: Mesh in [hull.mesh, _racks.multimesh.mesh]:
		instances += 1
		for s: int in mesh.get_surface_count():
			surfaces += 1
			vertices += (mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return {"instances": instances, "surfaces": surfaces, "vertices": vertices}


## Its meshes (tests: the colour rule): the hull, a rack missile, a piece of the line, a riding missile.
func meshes() -> Array[Mesh]:
	return [hull.mesh, _racks.multimesh.mesh, _segments.multimesh.mesh, _riders.multimesh.mesh]


## Never a target (GDD §10, proposed: weapons never target the ship).
func targetable() -> bool:
	return false


## The fight is won: it's gone.
func _on_defeated(_cause: StringName) -> void:
	set_shown(false)

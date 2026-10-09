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
## - the feed line from its boom's nozzle to the suit's shoulder pipes (set_line: a gilded hose shooting out over
##   `reach`, a gentle sag; ride(): missiles riding up it to the shoulder), and its burning away as the chain's
##   blast races up it (burn_line);
## - the chain reaction's fire (GoldenConvergenceBlast, E5d polish: fireball() a saturated orange fireball laid over
##   what's behind it, reddening and fading, dark smoke rolling up out of it, softer with Reduced flashing; smoke()
##   on its own; spark bursts only without Reduced flashing) and the ship's own end (explode: it's gone in a blast
##   around it in the world's up, never its roll, so a ship rolled over still explodes above the causeway's level,
##   where the run camera and the side see it).
## A part of the boss that's no target (GDD §10, proposed: weapons never target the ship; DESIGN-TBD,
## docs/questions/e5d.md, E5d-c 7) and no kill of its own: immune to weapons, never targetable, is_obstacle; nothing
## on it can hurt the runner.

## Pieces of the feed line, missiles riding it at once.
const SEGMENTS: int = 18
const RIDERS: int = 12
## The line's sag at its middle, over its length.
const SAG: float = 0.1
## Where the squadron holds: this far below the racks' underside, spread along the racks this far apart (from
## HOLD_FROM ahead of its middle).
const HOLD_DROP: float = 3.0
const HOLD_SPACING: float = 6.0
const HOLD_FROM: float = 4.0
## The sparks' colours (an explosion's: never on anything that stays, never on a hazard).
const FIRE := Color(1.0, 0.4, 0.13)
const FIRE_HOT := Color(1.0, 0.82, 0.55)
## Its blast (explode): fireballs this big along its length, around its middle at least BLAST_LIFT above the
## causeway (in the world's up: rolled over as it spins off, its own up points down). DESIGN-TBD
## (docs/questions/e5d.md, E5d polish 5).
const BLAST_LIFT: float = 4.0
const BLAST_RADIUS: float = 7.0

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
var _blast: GoldenConvergenceBlast
## Fireballs still to come (an explosion's later blasts), in order: when (seconds from now), where, how big, how
## long.
var _pending_delay := PackedFloat32Array()
var _pending_at := PackedVector3Array()
var _pending_radius := PackedFloat32Array()
var _pending_life := PackedFloat32Array()
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
	_blast = GoldenConvergenceBlast.new()
	add_child(_blast)
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


## It blows up where it is: a string of fireballs along its length over half a second around its middle, lifted
## in the world's up to at least BLAST_LIFT over the causeway (its own roll never sends the blast below the deck),
## dark smoke rolling up and lingering, debris, sparks (none with Reduced flashing); it's gone.
func explode() -> void:
	var length: float = GoldenConvergenceShipModel.LENGTH
	var c: Vector3 = blast_center()
	var spots: Array[Vector3] = [Vector3(0.0, 1.5, 0.0), Vector3(-half_width * 0.4, 0.5, -length * 0.3),
		Vector3(half_width * 0.35, 2.0, length * 0.28), Vector3(0.0, 3.0, -length * 0.42), Vector3(-half_width * 0.2, 1.0, length * 0.42)]
	for k: int in spots.size():
		var at: Vector3 = c + spots[k]
		var radius: float = BLAST_RADIUS - 0.8 * float(k)
		if k == 0:
			fireball(at, radius, 1.2, Vector3(0.0, 1.8, 0.0))
		else:
			_pending_delay.append(0.08 + 0.09 * float(k))
			_pending_at.append(at)
			_pending_radius.append(radius)
			_pending_life.append(0.9)
		_blast.smoke(at + Vector3(0.0, radius * 0.5, 0.0), radius * 1.4, 2.6, Vector3(0.0, 2.2, 0.0), 0.25 + 0.08 * float(k))
	world.effects.debris(c + Vector3(0.0, 1.5, 0.0), GoldenConvergenceShipModel.GOLD, 24, 2.2)
	if not Settings.flashing_reduced:
		world.effects.burst(c + Vector3(0.0, 1.5, 0.0), FIRE_HOT, 48, 3.2)
		sparks_shown += 1
	set_shown(false)


## Where its blast goes off (world space): its middle, at least BLAST_LIFT above the causeway in the world's up (the
## blast racing up the feed line starts there too: its boom, rolled over, points down).
func blast_center() -> Vector3:
	var c: Vector3 = global_position
	c.y = maxf(c.y, BLAST_LIFT)
	return c


## A fireball at `at` (world space), `radius` across at its fullest, gone after `life` seconds: it swells fast, a
## saturated orange that reddens and darkens as it fades, drifting by `drift` m/s, its smoke rolling up out of it
## (no flash with Reduced flashing). Pooled (GoldenConvergenceBlast): the oldest gives way.
func fireball(at: Vector3, radius: float, life: float, drift: Vector3 = Vector3.ZERO) -> void:
	_blast.fire(at, radius, life, drift)
	fireballs_shown += 1


## A puff of the blast's dark smoke at `at` (world space), `radius` across at its fullest, rising for `life` seconds.
func smoke(at: Vector3, radius: float, life: float) -> void:
	_blast.smoke(at, radius, life)


## Fireballs burning now (tests).
func fires_on() -> int:
	return _blast.fires_on()


## Its fire and smoke (tests).
func blast() -> GoldenConvergenceBlast:
	return _blast


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
	for i: int in range(_pending_delay.size() - 1, -1, -1):
		_pending_delay[i] = _pending_delay[i] - delta
		if _pending_delay[i] <= 0.0:
			fireball(_pending_at[i], _pending_radius[i], _pending_life[i], Vector3(0.0, 1.5, 0.0))
			_pending_delay.remove_at(i)
			_pending_at.remove_at(i)
			_pending_radius.remove_at(i)
			_pending_life.remove_at(i)
	_blast.tick(delta)
	if _line_on:
		_draw_line()


## Every fireball and puff of smoke out at once (a test, a fresh fight).
func fires_out() -> void:
	_pending_delay.clear()
	_pending_at.clear()
	_pending_radius.clear()
	_pending_life.clear()
	_blast.clear()


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

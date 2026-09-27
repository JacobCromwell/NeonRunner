class_name FloatingHeadRamp
extends Node3D
## The first stomp window's way up (GDD §10: "run up the fallen tower like a ramp"; task E1c). As the
## marked tower crashes onto the pinned ship, a broken slab of it slams down in one lane: its foot on
## the trucks, its top end resting on the ship's crown just past its face, a little higher than the
## crown. The runner runs up it, off its end, and drops onto the weak point beyond.
## Physical all over (collision stays physical on every surface): its top is a floor surface (the
## runner walks up it on the support rays like any raised floor), and it's a lane blocker wherever it
## stands higher than a step, down to the trucks (a lane switch into it bumps; a runner in the air
## above it may switch over and land on it). It gives no boost and launches nobody: a slope, not a ramp
## pad (so RampLaunch's wall-run prediction doesn't apply to it).
## DESIGN-TBD (docs/questions/e1.md, From E1c): the look. Placeholder: a slab of the tower's pale
## concrete as wide as a lane, a row of the tower's windows and a painted white band along its sides,
## its top end torn off with rebar sticking out, and the City's green ramp chevrons running up the
## middle of its top ("go up here", the zone's ramp colour) with white edge lines.
## World space (the node sits at the origin, top_level): the slab lies along its lane toward -z.

## The slab's thickness (its underside is parallel to its top).
const THICKNESS: float = 0.9
## Its sides block a lane switch wherever its top is higher than a runner can step up (Player: the
## support rays reach 0.6 m above the feet).
const STEP: float = 0.55
## The lane blocker's width (the player's lane check is half a lane wide, centred on the lane).
const BLOCKER_WIDTH: float = 1.0
## It slams down from this angle about its foot.
const SLAM_DEGREES: float = 62.0
## Crumbling, it sinks away this far.
const CRUMBLE_DROP: float = 8.0
## The chevron strip's width, and the length of each chevron panel along the slope.
const STRIP_WIDTH: float = 1.1
const PANEL_LENGTH: float = 2.4

var world: RunWorld
var lane: int = 0
## Its foot's and its top end's track distances, and where the ship's face is.
var foot: float = 0.0
var end: float = 0.0
var face: float = 0.0
## Its top's height at the ship's face and at its end.
var top_at_face: float = 0.0
var top_at_end: float = 0.0
## Landed: solid and blocking (it isn't until its slam lands).
var landed: bool = false

var _body: StaticBody3D
var _blocker: Area3D
var _look: Node3D
var _slam_seconds: float = 0.3
var _t: float = 0.0
var _crumbling: bool = false
var _drop: float = 0.0


## Lays it in `lane` from track distance `p_foot` up to the ship's face at `p_face`, its top
## `p_top` high there, resting `overhang` further onto the crown, and slams it down over `slam_seconds`.
func setup(p_world: RunWorld, p_lane: int, p_foot: float, p_face: float, p_top: float, overhang: float,
		slam_seconds: float, ramp_color: Color) -> void:
	world = p_world
	lane = p_lane
	foot = p_foot
	face = p_face
	end = p_face + overhang
	top_at_face = p_top
	top_at_end = p_top * (end - foot) / maxf(face - foot, 0.1)
	_slam_seconds = maxf(slam_seconds, 0.05)
	name = "TowerRamp"
	top_level = true
	transform = Transform3D.IDENTITY
	var x: float = world.geo.lane_x(lane)
	var width: float = world.geo.lane_width - 0.2
	_look = Node3D.new()
	_look.name = "Look"
	add_child(_look)
	MeshBatch.add_instance(_look, ramp_mesh(x, width, foot, end, top_at_end, ramp_color), "Slab")
	# Its solid top: the slab itself (a floor surface), exactly where it's drawn.
	_body = StaticBody3D.new()
	_body.name = "Top"
	_body.collision_layer = 0
	_body.collision_mask = 0
	_add_convex(_body, _slab_points(x, width))
	_look.add_child(_body)
	# Its sides: down to the trucks, from where its top is higher than a step.
	_blocker = Area3D.new()
	_blocker.name = "Sides"
	_blocker.collision_layer = 0
	_blocker.collision_mask = 0
	_blocker.monitoring = false
	_add_convex(_blocker, _wedge_points(x, BLOCKER_WIDTH))
	_look.add_child(_blocker)
	_pose(0.0)


## Its top's height (world) at track distance `d` (0 off it).
func top_at(d: float) -> float:
	if d < foot or d > end:
		return 0.0
	return top_at_end * (d - foot) / maxf(end - foot, 0.1)


## Where its foot stands on the trucks and where its top end is (world space, its lane's middle).
func foot_world() -> Vector3:
	return Vector3(world.geo.lane_x(lane), 0.0, TrackGeometry.world_z(foot))


func end_world() -> Vector3:
	return Vector3(world.geo.lane_x(lane), top_at_end, TrackGeometry.world_z(end))


## The ship shook free: it breaks up and sinks away (its sides stop blocking at once; its top sinks with
## it, so a runner still on it goes down with it).
func crumble() -> void:
	if _crumbling:
		return
	_crumbling = true
	_blocker.collision_layer = 0
	for k: float in [0.2, 0.5, 0.8]:
		var d: float = lerpf(foot, end, k)
		world.effects.burst(Vector3(world.geo.lane_x(lane), top_at(d) * 0.6, TrackGeometry.world_z(d)),
			FloatingHeadTower.CONCRETE_LIGHT, 22, 1.2)


func _physics_process(delta: float) -> void:
	if _crumbling:
		_drop += delta * (2.0 + _drop * 6.0)
		_look.position = Vector3(0.0, -_drop, 0.0)
		if _drop >= CRUMBLE_DROP:
			queue_free()
		return
	if landed:
		return
	_t += delta
	var k: float = clampf(_t / _slam_seconds, 0.0, 1.0)
	_pose(k)
	if k >= 1.0:
		landed = true
		_body.collision_layer = TrackBuilder.LAYER_FLOOR
		_blocker.collision_layer = TrackBuilder.LAYER_LANE_BLOCKER
		world.effects.shake(0.35, 0.35)
		for f: float in [0.1, 0.45, 0.8]:
			var d: float = lerpf(foot, end, f)
			world.effects.burst(Vector3(world.geo.lane_x(lane), 0.3, TrackGeometry.world_z(d)),
				FloatingHeadTower.CONCRETE_LIGHT, 20, 1.1)


## Swung up about its foot by what's left of the slam at progress `k` (0 up, 1 down): it falls,
## faster and faster.
func _pose(k: float) -> void:
	var angle: float = deg_to_rad(SLAM_DEGREES) * (1.0 - k * k)
	var hinge: Vector3 = foot_world()
	var swing := Basis(Vector3(1.0, 0.0, 0.0), angle)
	_look.transform = Transform3D(swing, hinge - swing * hinge)


## The slab's corners (world): its top from its foot on the trucks to its end, its underside parallel
## and THICKNESS under it, down to where it meets the trucks.
func _slab_points(x: float, width: float) -> PackedVector3Array:
	var length: float = end - foot
	var slope: float = top_at_end / maxf(length, 0.1)
	var under: float = THICKNESS * sqrt(1.0 + slope * slope)
	var touch: float = foot + minf(under / maxf(slope, 0.01), length)
	var out := PackedVector3Array()
	for s: float in [-0.5, 0.5]:
		var sx: float = x + s * width
		out.append(Vector3(sx, 0.0, TrackGeometry.world_z(foot)))
		out.append(Vector3(sx, top_at_end, TrackGeometry.world_z(end)))
		out.append(Vector3(sx, maxf(top_at_end - under, 0.0), TrackGeometry.world_z(end)))
		out.append(Vector3(sx, 0.0, TrackGeometry.world_z(touch)))
	return out


## The lane blocker's corners (world): from where the top stands a step high to its end, down to the
## trucks.
func _wedge_points(x: float, width: float) -> PackedVector3Array:
	var from: float = foot + (end - foot) * clampf(STEP / maxf(top_at_end, 0.01), 0.0, 1.0)
	var out := PackedVector3Array()
	for s: float in [-0.5, 0.5]:
		var sx: float = x + s * width
		out.append(Vector3(sx, 0.0, TrackGeometry.world_z(from)))
		out.append(Vector3(sx, top_at(from), TrackGeometry.world_z(from)))
		out.append(Vector3(sx, top_at_end, TrackGeometry.world_z(end)))
		out.append(Vector3(sx, 0.0, TrackGeometry.world_z(end)))
	return out


static func _add_convex(owner_node: CollisionObject3D, points: PackedVector3Array) -> void:
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	var cs := CollisionShape3D.new()
	cs.shape = shape
	owner_node.add_child(cs)


# --- The mesh --------------------------------------------------------------------------------------

## The slab (world space, lying down): pale concrete, a row of the tower's windows and a painted band
## along its sides, a dark underside, a torn top end with rebar, and green chevrons up its top with
## white edge lines.
static func ramp_mesh(x: float, width: float, p_foot: float, p_end: float, top: float, ramp_color: Color) -> ArrayMesh:
	var batch := MeshBatch.new()
	var m: MeshLayer = batch.layer(FloatingHeadModel.solid_material())
	var length: float = p_end - p_foot
	var slope: float = top / maxf(length, 0.1)
	var under: float = THICKNESS * sqrt(1.0 + slope * slope)
	var touch: float = p_foot + minf(under / maxf(slope, 0.01), length)
	var hw: float = width * 0.5
	var zf: float = TrackGeometry.world_z(p_foot)
	var ze: float = TrackGeometry.world_z(p_end)
	var zt: float = TrackGeometry.world_z(touch)
	var ye: float = maxf(top - under, 0.0)
	var l := x - hw
	var r := x + hw
	# The top (seen from above, clockwise), the underside, the sides and the torn end.
	m.quad(Vector3(r, 0.0, zf), Vector3(l, 0.0, zf), Vector3(l, top, ze), Vector3(r, top, ze), FloatingHeadTower.CONCRETE)
	m.quad(Vector3(l, 0.0, zt), Vector3(r, 0.0, zt), Vector3(r, ye, ze), Vector3(l, ye, ze), FloatingHeadTower.CONCRETE_DARK)
	for s: float in [-1.0, 1.0]:
		var sx: float = x + s * hw
		var a := Vector3(sx, 0.0, zf)
		var b := Vector3(sx, top, ze)
		var c := Vector3(sx, ye, ze)
		var d := Vector3(sx, 0.0, zt)
		if s > 0.0:
			m.quad(a, b, c, d, FloatingHeadTower.CONCRETE_DARK.lerp(FloatingHeadTower.CONCRETE, 0.6))
		else:
			m.quad(d, c, b, a, FloatingHeadTower.CONCRETE_DARK.lerp(FloatingHeadTower.CONCRETE, 0.6))
	m.quad(Vector3(l, ye, ze), Vector3(r, ye, ze), Vector3(r, top, ze), Vector3(l, top, ze), FloatingHeadTower.CONCRETE_DARK)
	var along := Vector3(0.0, top, ze - zf).normalized()
	var up: Vector3 = along.cross(Vector3(1, 0, 0)).normalized()
	if up.y < 0.0:
		up = -up
	# The tower's windows and its painted band along each side (a slab of its facade).
	for s: float in [-1.0, 1.0]:
		var sx: float = x + s * (hw + 0.02)
		var n: int = maxi(int(length / 2.4), 2)
		for i: int in n:
			var k: float = (float(i) + 0.5) / n
			var d: float = lerpf(p_foot, p_end, k)
			var y: float = top * (d - p_foot) / maxf(length, 0.1) - THICKNESS * 0.5
			if y < 0.35:
				continue
			m.box_xform(Transform3D(Basis(Vector3(0.05, 0, 0), up * 0.45, along * 1.3), Vector3(sx, y, TrackGeometry.world_z(d))),
				FloatingHeadTower.GLASS)
		var bk: float = 0.72
		var bd: float = lerpf(p_foot, p_end, bk)
		var by: float = top * bk - THICKNESS * 0.5
		m.box_xform(Transform3D(Basis(Vector3(0.05, 0, 0), up * (THICKNESS * 0.9), along * 1.0), Vector3(sx, by, TrackGeometry.world_z(bd))),
			FloatingHeadTower.PAINT, 0.35)
	# The green chevrons up the middle of its top, in panels, with white edge lines.
	var lift: Vector3 = up * 0.02
	var panels: int = maxi(int(length / PANEL_LENGTH), 1)
	for i: int in panels:
		var d0: float = lerpf(p_foot, p_end, float(i) / panels)
		var d1: float = lerpf(p_foot, p_end, float(i + 1) / panels)
		var y0: float = top * (d0 - p_foot) / maxf(length, 0.1)
		var y1: float = top * (d1 - p_foot) / maxf(length, 0.1)
		var sw: float = STRIP_WIDTH * 0.5
		m.quad(Vector3(x + sw, y0, TrackGeometry.world_z(d0)) + lift, Vector3(x - sw, y0, TrackGeometry.world_z(d0)) + lift,
			Vector3(x - sw, y1, TrackGeometry.world_z(d1)) + lift, Vector3(x + sw, y1, TrackGeometry.world_z(d1)) + lift,
			ramp_color, 0.8, MeshKit.PAT_CHEVRON, 1.0)
	for s: float in [-1.0, 1.0]:
		var ex: float = x + s * (hw - 0.12)
		m.box_xform(Transform3D(Basis(Vector3(0.1, 0, 0), up * 0.03, along * sqrt(length * length + top * top)),
			Vector3(ex, top * 0.5, (zf + ze) * 0.5) + lift), FloatingHeadTower.PAINT, 0.6)
	# The torn end: rebar sticking out of it.
	for i: int in 5:
		var a := Vector3(x + (MeshKit.hash01(i, 11) - 0.5) * width * 0.8, lerpf(ye, top, MeshKit.hash01(i, 13)), ze)
		var b: Vector3 = a + Vector3((MeshKit.hash01(i, 17) - 0.5) * 0.6, (MeshKit.hash01(i, 19) - 0.3) * 0.5, -0.6)
		FloatingHeadModel._bar(m, a, b, 0.06, FloatingHeadTower.REBAR, 0.0, Vector3(0, 1, 0))
	return batch.to_mesh()

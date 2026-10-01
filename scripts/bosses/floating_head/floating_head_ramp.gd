class_name FloatingHeadRamp
extends Node3D
## The first stomp window's way up (GDD §10: "run up the fallen tower like a ramp"; tasks E1c, E1e). As
## the marked tower crashes onto the pinned ship, a broken slab of it slams down in one lane: its foot on
## the trucks, its top end resting on the ship's crown just past its face, a little higher than the
## crown. The runner runs up it, off its end, and drops onto the weak point beyond.
## It lies in two pieces (E1e, the owner's playtest: a lane switch onto it anywhere but its very foot
## bounced off its side):
## - the lead-in, board_share of its length from the foot, a low wedge rising to its knee (knee_height)
##   with bevelled sides sloping down to the trucks: a lane switch into its lane anywhere along it steps
##   up the bevel onto it (the runner's support reaches a little above the feet each frame, Player's
##   support rays), so the runner boards it late as well as at its foot;
## - the slab proper, from the knee up onto the crown, steeper: its sides are a lane blocker down to the
##   trucks (a lane switch into it bumps; a runner in the air above it may switch over and land on it).
## The knee is as high as a lane switch can step up the bevel (side_step_limit, from the movement
## tuning), or lower. Physical all over (collision stays physical on every surface): both tops are a
## floor surface (the runner walks up them on the support rays like any raised floor). It gives no boost
## and launches nobody: a slope, not a ramp pad (so RampLaunch's wall-run prediction doesn't apply).
## DESIGN-TBD (docs/OPEN_QUESTIONS.md §D, item 158; docs/questions/e1e.md): the look. Placeholder: the
## tower's pale concrete as wide as a lane; the lead-in a low wedge whose sides have crumbled into sloped
## rubble, its top edges lit in the City's green ramp colour (a way on from the side); the slab a row of
## the tower's windows and a painted white band along its sides, its top end torn off with rebar
## sticking out, white edge lines; the City's green ramp chevrons run up the middle of both ("go up
## here", the zone's ramp colour).
## World space (the node sits at the origin, top_level): the slab lies along its lane toward -z.

## The slab's thickness (its underside is parallel to its top).
const THICKNESS: float = 0.9
## Where there is no lead-in (board_share 0), its sides block a lane switch wherever its top is higher
## than a runner can step up (Player: the support rays reach 0.6 m above the feet).
const STEP: float = 0.55
## Player's support rays start this high above the feet (a surface up to this much higher is stepped
## onto), and this is kept in hand.
const SUPPORT_REACH: float = 0.6
const STEP_MARGIN: float = 0.05
## The lead-in's bevels stop this far short of the next lane's runner's feet, so a runner there never
## touches them.
const BEVEL_CLEAR: float = 0.1
## The lane blocker's width (the player's lane check is half a lane wide, centred on the lane).
const BLOCKER_WIDTH: float = 1.0
## It slams down from this angle about its foot.
const SLAM_DEGREES: float = 62.0
## Crumbling, it sinks away this far.
const CRUMBLE_DROP: float = 8.0
## The chevron strip's width, and the length of each chevron panel along the slope.
const STRIP_WIDTH: float = 1.1
const PANEL_LENGTH: float = 2.4
## The lead-in's rubble: chunks along each bevel, about this far apart.
const RUBBLE_SPACING: float = 1.6

var world: RunWorld
var lane: int = 0
## Its foot's and its top end's track distances, and where the ship's face is.
var foot: float = 0.0
var end: float = 0.0
var face: float = 0.0
## The knee (where the lead-in meets the slab): its track distance and its top's height. A lane switch
## into its lane boards it up to the knee (board_until); past it, its sides block.
var knee: float = 0.0
var knee_height: float = 0.0
## Its top's height at the ship's face and at its end.
var top_at_face: float = 0.0
var top_at_end: float = 0.0
## How far out from its top's edges the lead-in's bevels reach (0: no lead-in).
var bevel: float = 0.0
## Landed: solid and blocking (it isn't until its slam lands).
var landed: bool = false

var _body: StaticBody3D
var _blocker: Area3D
var _look: Node3D
var _slam_seconds: float = 0.3
var _t: float = 0.0
var _crumbling: bool = false
var _drop: float = 0.0


## Lays it in `lane` from track distance `p_foot` up to the ship's face at `p_face`, its top `p_top`
## high there, resting `overhang` further onto the crown, and slams it down over `slam_seconds`. Its
## lead-in takes `board_share` of it from the foot, rising to `board_height` (at most as high as a lane
## switch steps up its bevels, side_step_limit; 0: no lead-in, one straight slab).
func setup(p_world: RunWorld, p_lane: int, p_foot: float, p_face: float, p_top: float, overhang: float,
		slam_seconds: float, ramp_color: Color, board_share: float = 0.0, board_height: float = 0.0) -> void:
	world = p_world
	lane = p_lane
	foot = p_foot
	face = p_face
	end = p_face + overhang
	top_at_face = p_top
	_slam_seconds = maxf(slam_seconds, 0.05)
	var width: float = world.geo.lane_width - 0.2
	var share: float = clampf(board_share, 0.0, 0.95)
	if share > 0.0 and board_height > 0.0:
		bevel = maxf(world.geo.lane_width - world.tuning.foot_half_width - width * 0.5 - BEVEL_CLEAR, 0.1)
		knee = foot + (face - foot) * share
		# Never steeper than the slab above it, and never higher than a lane switch steps up.
		knee_height = minf(minf(board_height, p_top * share), side_step_limit(world.tuning, world.geo.lane_width,
			width * 0.5, bevel))
	else:
		knee = foot
		knee_height = 0.0
	var slope: float = (p_top - knee_height) / maxf(face - knee, 0.1)
	top_at_end = p_top + slope * (end - face)
	name = "TowerRamp"
	top_level = true
	transform = Transform3D.IDENTITY
	var x: float = world.geo.lane_x(lane)
	_look = Node3D.new()
	_look.name = "Look"
	add_child(_look)
	MeshBatch.add_instance(_look, ramp_mesh(x, width, foot, knee, knee_height, bevel, end, top_at_end, ramp_color), "Slab")
	# Its solid tops: the lead-in with its bevels, and the slab (floor surfaces), exactly where they're drawn.
	_body = StaticBody3D.new()
	_body.name = "Top"
	_body.collision_layer = 0
	_body.collision_mask = 0
	if knee > foot + 0.1:
		_add_convex(_body, _lead_in_points(x, width * 0.5))
	_add_convex(_body, _slab_points(x, width))
	_look.add_child(_body)
	# The slab's sides: down to the trucks, from the knee (or, with no lead-in, from where its top is
	# higher than a step).
	_blocker = Area3D.new()
	_blocker.name = "Sides"
	_blocker.collision_layer = 0
	_blocker.collision_mask = 0
	_blocker.monitoring = false
	_add_convex(_blocker, _wedge_points(x, BLOCKER_WIDTH))
	_look.add_child(_blocker)
	_pose(0.0)


## The highest top a lane switch from the next lane's middle steps onto over a bevel `bevel_width` wide
## beside a top `half_width` either side of its lane's middle: the runner's support reaches
## SUPPORT_REACH above the feet each physics frame, and the switch's first frames cover the most ground
## (Player._switch_x eases out), so the steepest step is one frame's rise up the bevel.
static func side_step_limit(t: MovementTuning, lane_width: float, half_width: float, bevel_width: float) -> float:
	var frames: float = maxf(t.lane_switch_time * Engine.physics_ticks_per_second, 1.0)
	var worst: float = 0.0
	var before: float = 0.0
	for f: int in range(1, int(ceilf(frames)) + 1):
		var k: float = minf(float(f) / frames, 1.0)
		var body_x: float = lane_width * (1.0 - (1.0 - (1.0 - k) * (1.0 - k)))
		var foot_x: float = body_x - t.foot_half_width
		# Share of the top's height under the inner foot: 1 on the top, falling to 0 at the bevel's foot.
		var under: float = clampf(1.0 - (foot_x - half_width) / maxf(bevel_width, 0.01), 0.0, 1.0)
		worst = maxf(worst, under - before)
		before = under
	return (SUPPORT_REACH - STEP_MARGIN) / maxf(worst, 0.01)


## Its top's height (world) at track distance `d` (0 off it).
func top_at(d: float) -> float:
	if d < foot or d > end:
		return 0.0
	if d <= knee:
		return knee_height * (d - foot) / maxf(knee - foot, 0.1)
	return knee_height + (top_at_end - knee_height) * (d - knee) / maxf(end - knee, 0.1)


## The last track distance at which a lane switch into its lane from beside it boards it (its knee; with
## no lead-in, where its top is a step high).
func board_until() -> float:
	if knee > foot:
		return knee
	return foot + (end - foot) * clampf(STEP / maxf(top_at_end, 0.01), 0.0, 1.0)


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


## The lead-in's corners (world): its top from the foot on the trucks up to the knee, each bevel from
## the top's edge down to the trucks (as wide as the top is high there, over `bevel`: a constant slope),
## down to the trucks under the knee.
func _lead_in_points(x: float, half_width: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for s: float in [-1.0, 1.0]:
		out.append(Vector3(x + s * half_width, 0.0, TrackGeometry.world_z(foot)))
		out.append(Vector3(x + s * half_width, knee_height, TrackGeometry.world_z(knee)))
		out.append(Vector3(x + s * (half_width + bevel), 0.0, TrackGeometry.world_z(knee)))
	return out


## The slab's corners (world): its top from the knee to its end, its underside parallel and THICKNESS
## under it, down to where it meets the trucks.
func _slab_points(x: float, width: float) -> PackedVector3Array:
	var length: float = end - knee
	var slope: float = (top_at_end - knee_height) / maxf(length, 0.1)
	var under: float = THICKNESS * sqrt(1.0 + slope * slope)
	var out := PackedVector3Array()
	for s: float in [-0.5, 0.5]:
		var sx: float = x + s * width
		out.append(Vector3(sx, knee_height, TrackGeometry.world_z(knee)))
		out.append(Vector3(sx, top_at_end, TrackGeometry.world_z(end)))
		out.append(Vector3(sx, maxf(top_at_end - under, 0.0), TrackGeometry.world_z(end)))
		if knee_height - under > 0.0:
			out.append(Vector3(sx, knee_height - under, TrackGeometry.world_z(knee)))
		else:
			var touch: float = knee + minf((under - knee_height) / maxf(slope, 0.01), length)
			out.append(Vector3(sx, 0.0, TrackGeometry.world_z(touch)))
	return out


## The lane blocker's corners (world): from the knee (with no lead-in, from where the top stands a step
## high) to its end, down to the trucks.
func _wedge_points(x: float, width: float) -> PackedVector3Array:
	var from: float = board_until()
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

## The ramp (world space, lying down): the lead-in from `p_foot` to `p_knee` (its top `knee_top` high
## there) with its rubble bevels `bevel_width` wide and its top edges in the ramp colour; the slab from
## the knee to `p_end` (`top` high there): pale concrete, a row of the tower's windows and a painted
## band along its sides, a dark underside, a torn top end with rebar, white edge lines. Green chevrons
## run up the middle of both.
static func ramp_mesh(x: float, width: float, p_foot: float, p_knee: float, knee_top: float, bevel_width: float,
		p_end: float, top: float, ramp_color: Color) -> ArrayMesh:
	var batch := MeshBatch.new()
	var m: MeshLayer = batch.layer(FloatingHeadModel.solid_material())
	var hw: float = width * 0.5
	var l := x - hw
	var r := x + hw
	var zf: float = TrackGeometry.world_z(p_foot)
	var zk: float = TrackGeometry.world_z(p_knee)
	var ze: float = TrackGeometry.world_z(p_end)
	var side_tone: Color = FloatingHeadTower.CONCRETE_DARK.lerp(FloatingHeadTower.CONCRETE, 0.6)
	var rubble_tone: Color = FloatingHeadTower.CONCRETE_DARK.lerp(FloatingHeadTower.CONCRETE, 0.35)
	var lead_in: bool = p_knee > p_foot + 0.1
	if lead_in:
		# The lead-in's top, its bevels of crumbled concrete, and its end under the slab.
		m.quad(Vector3(r, 0.0, zf), Vector3(l, 0.0, zf), Vector3(l, knee_top, zk), Vector3(r, knee_top, zk),
			FloatingHeadTower.CONCRETE)
		m.quad(Vector3(l, 0.0, zf), Vector3(l - bevel_width, 0.0, zk), Vector3(l, knee_top, zk), Vector3(l, knee_top, zk), rubble_tone)
		m.quad(Vector3(r, 0.0, zf), Vector3(r, knee_top, zk), Vector3(r + bevel_width, 0.0, zk), Vector3(r + bevel_width, 0.0, zk), rubble_tone)
		m.quad(Vector3(l - bevel_width, 0.0, zk), Vector3(r + bevel_width, 0.0, zk), Vector3(r, knee_top, zk), Vector3(l, knee_top, zk),
			FloatingHeadTower.CONCRETE_DARK)
		# Chunks of concrete lying on the bevels: at a share k of the lead-in the top is knee_top * k high
		# and the bevel reaches bevel_width * k out; a chunk a share u of the way out sits on it there.
		var n: int = maxi(int((p_knee - p_foot) / RUBBLE_SPACING), 2)
		for s: float in [-1.0, 1.0]:
			for i: int in n:
				var seed_i: int = i * 2 + (0 if s < 0.0 else 1)
				var k: float = (float(i) + 0.3 + 0.4 * MeshKit.hash01(seed_i, 31)) / n
				var h: float = knee_top * k
				if h < 0.18:
					continue
				var u: float = 0.25 + 0.4 * MeshKit.hash01(seed_i, 41)
				var size: float = clampf(h * 0.4, 0.14, 0.36)
				var chunk := Basis(Vector3.UP, MeshKit.hash01(seed_i, 43) * TAU) * Basis(Vector3(1, 0, 0), 0.4 * MeshKit.hash01(seed_i, 47))
				m.box_xform(Transform3D(chunk.scaled(Vector3(size, size * 0.7, size * 1.2)),
					Vector3(x + s * (hw + bevel_width * k * u), h * (1.0 - u) + size * 0.15, TrackGeometry.world_z(lerpf(p_foot, p_knee, k)))),
					FloatingHeadTower.CONCRETE_LIGHT if MeshKit.hash01(seed_i, 53) > 0.5 else rubble_tone)
	# The slab: its top (seen from above, clockwise), the underside, the sides and the torn end.
	var length: float = p_end - p_knee
	var slope: float = (top - knee_top) / maxf(length, 0.1)
	var under: float = THICKNESS * sqrt(1.0 + slope * slope)
	var yk: float = maxf(knee_top - under, 0.0)
	var touch: float = p_knee + (minf((under - knee_top) / maxf(slope, 0.01), length) if knee_top < under else 0.0)
	var zt: float = TrackGeometry.world_z(touch)
	var ye: float = maxf(top - under, 0.0)
	m.quad(Vector3(r, knee_top, zk), Vector3(l, knee_top, zk), Vector3(l, top, ze), Vector3(r, top, ze), FloatingHeadTower.CONCRETE)
	m.quad(Vector3(l, yk, zt), Vector3(r, yk, zt), Vector3(r, ye, ze), Vector3(l, ye, ze), FloatingHeadTower.CONCRETE_DARK)
	for s: float in [-1.0, 1.0]:
		var sx: float = x + s * hw
		var a := Vector3(sx, knee_top, zk)
		var b := Vector3(sx, top, ze)
		var c := Vector3(sx, ye, ze)
		var d := Vector3(sx, yk, zt)
		if s > 0.0:
			m.quad(a, b, c, d, side_tone)
		else:
			m.quad(d, c, b, a, side_tone)
	m.quad(Vector3(l, ye, ze), Vector3(r, ye, ze), Vector3(r, top, ze), Vector3(l, top, ze), FloatingHeadTower.CONCRETE_DARK)
	var along := Vector3(0.0, top - knee_top, ze - zk).normalized()
	var up: Vector3 = along.cross(Vector3(1, 0, 0)).normalized()
	if up.y < 0.0:
		up = -up
	# The tower's windows and its painted band along each side of the slab (a slab of its facade).
	for s: float in [-1.0, 1.0]:
		var sx: float = x + s * (hw + 0.02)
		var n: int = maxi(int(length / 2.4), 2)
		for i: int in n:
			var k: float = (float(i) + 0.5) / n
			var d: float = lerpf(p_knee, p_end, k)
			var y: float = lerpf(knee_top, top, k) - THICKNESS * 0.5
			if y < 0.35:
				continue
			m.box_xform(Transform3D(Basis(Vector3(0.05, 0, 0), up * 0.45, along * 1.3), Vector3(sx, y, TrackGeometry.world_z(d))),
				FloatingHeadTower.GLASS)
		var bk: float = 0.72
		var bd: float = lerpf(p_knee, p_end, bk)
		var by: float = lerpf(knee_top, top, bk) - THICKNESS * 0.5
		m.box_xform(Transform3D(Basis(Vector3(0.05, 0, 0), up * (THICKNESS * 0.9), along * 1.0), Vector3(sx, by, TrackGeometry.world_z(bd))),
			FloatingHeadTower.PAINT, 0.35)
	# The green chevrons up the middle of both tops, in panels; white edge lines along the slab and the
	# ramp colour along the lead-in's edges (a way on from the side).
	var sw: float = STRIP_WIDTH * 0.5
	for piece: int in 2:
		if piece == 0 and not lead_in:
			continue
		var d_from: float = p_foot if piece == 0 else p_knee
		var d_to: float = p_knee if piece == 0 else p_end
		var y_from: float = 0.0 if piece == 0 else knee_top
		var y_to: float = knee_top if piece == 0 else top
		var piece_along := Vector3(0.0, y_to - y_from, TrackGeometry.world_z(d_to) - TrackGeometry.world_z(d_from))
		var piece_up: Vector3 = piece_along.normalized().cross(Vector3(1, 0, 0)).normalized()
		if piece_up.y < 0.0:
			piece_up = -piece_up
		var lift: Vector3 = piece_up * 0.02
		var panels: int = maxi(int((d_to - d_from) / PANEL_LENGTH), 1)
		for i: int in panels:
			var d0: float = lerpf(d_from, d_to, float(i) / panels)
			var d1: float = lerpf(d_from, d_to, float(i + 1) / panels)
			var y0: float = lerpf(y_from, y_to, float(i) / panels)
			var y1: float = lerpf(y_from, y_to, float(i + 1) / panels)
			m.quad(Vector3(x + sw, y0, TrackGeometry.world_z(d0)) + lift, Vector3(x - sw, y0, TrackGeometry.world_z(d0)) + lift,
				Vector3(x - sw, y1, TrackGeometry.world_z(d1)) + lift, Vector3(x + sw, y1, TrackGeometry.world_z(d1)) + lift,
				ramp_color, 0.8, MeshKit.PAT_CHEVRON, 1.0)
		for s: float in [-1.0, 1.0]:
			var ex: float = x + s * (hw - 0.12)
			m.box_xform(Transform3D(Basis(Vector3(0.1, 0, 0), piece_up * 0.03, piece_along),
				Vector3(ex, (y_from + y_to) * 0.5, (TrackGeometry.world_z(d_from) + TrackGeometry.world_z(d_to)) * 0.5) + lift),
				ramp_color if piece == 0 else FloatingHeadTower.PAINT, 0.8 if piece == 0 else 0.6)
	# The torn end: rebar sticking out of it.
	for i: int in 5:
		var a := Vector3(x + (MeshKit.hash01(i, 11) - 0.5) * width * 0.8, lerpf(ye, top, MeshKit.hash01(i, 13)), ze)
		var b: Vector3 = a + Vector3((MeshKit.hash01(i, 17) - 0.5) * 0.6, (MeshKit.hash01(i, 19) - 0.3) * 0.5, -0.6)
		FloatingHeadModel._bar(m, a, b, 0.06, FloatingHeadTower.REBAR, 0.0, Vector3(0, 1, 0))
	return batch.to_mesh()

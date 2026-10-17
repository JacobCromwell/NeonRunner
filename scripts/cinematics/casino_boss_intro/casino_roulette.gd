class_name CasinoRoulette
extends Node3D
## The roulette wheel in the casino hall (CasinoHall; the Casino boss intro: "we get an up-close view of a roulette wheel
## spinning and people cheering as it lands"): a wooden bowl set into the table's end with its sloped ball track, and
## its rotor spinning in it: thirty-seven pockets in turn dull red and black, the one green zero, brass frets between
## them, a brass cone and turret in the middle. The ball runs round the track the other way, slowing, drops off it,
## clatters over the frets and settles in a pocket, then rides round with the rotor. Built close-up worthy (it fills
## the screen) but low-poly, in the kit's solid material (unlit fake light; nothing glows). Moved from the cinematic's
## clock (update()), so stepping shows the same.
## Its space: the wheel's middle on the felt at the origin, +y up.

const POCKETS: int = 37
## The bowl's outer radius, the ball track's (where the ball runs), the pockets' ring (inner, outer), the cone's.
const BOWL: float = 0.56
const TRACK: float = 0.47
const POCKET_IN: float = 0.24
const POCKET_OUT: float = 0.37
const CONE: float = 0.12
const BALL: float = 0.02
## Heights: the track (sloping from its rim down toward the rotor), the pockets' floor, the ball's centre on the track.
const TRACK_RIM_Y: float = 0.035
const POCKET_Y: float = -0.005
const BALL_TRACK_Y: float = 0.03

const WOOD := Color(0.24, 0.12, 0.06)
const WOOD_DARK := Color(0.14, 0.07, 0.04)
const RED := Color(0.5, 0.07, 0.08)
const BLACK := Color(0.05, 0.05, 0.06)
const GREEN := Color(0.07, 0.34, 0.18)
const BRASS := Color(0.68, 0.52, 0.26)
const IVORY := Color(0.94, 0.93, 0.88)

var rotor: Node3D
var ball: MeshInstance3D
## Where the ball came to rest, relative to the rotor (radians), worked out once from the numbers.
var _pocket_angle: float = NAN
var _numbers: CasinoBossIntroTuning


func setup(solid: Material) -> void:
	name = "Roulette"
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(solid)
	# The bowl: a wooden drum sunk into the felt, its rim polished, the track sloping in from it.
	s.prism(Vector3(0.0, -0.14, 0.0), BOWL, 0.12, 36, WOOD, 0.0, MeshKit.PAT_PLAIN)
	s.prism(Vector3(0.0, -0.02, 0.0), BOWL + 0.02, 0.07, 36, WOOD, 0.0, MeshKit.PAT_PLAIN, false)
	_ring(s, BOWL + 0.03, BOWL - 0.01, 0.05, 0.055, BRASS, 48)
	_ring(s, BOWL - 0.01, TRACK - 0.03, TRACK_RIM_Y + 0.02, TRACK_RIM_Y - 0.01, WOOD_DARK, 48)
	_ring(s, TRACK - 0.03, POCKET_OUT + 0.03, TRACK_RIM_Y - 0.01, 0.0, WOOD, 48)
	# The deflectors on the track (little brass diamonds the ball clatters over).
	for i: int in 8:
		var a: float = TAU * float(i) / 8.0
		var xf := Transform3D(Basis(Vector3.UP, -a) * Basis.from_scale(Vector3(0.02, 0.012, 0.045)),
			Vector3(cos(a), 0.0, sin(a)) * (TRACK - 0.05) + Vector3(0.0, TRACK_RIM_Y - 0.004, 0.0))
		s.box_xform(xf, BRASS, 0.0, MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.9)
	var bowl_mesh: ArrayMesh = batch.to_mesh()
	MeshBatch.add_instance(self, bowl_mesh, "Bowl")
	# The rotor.
	rotor = Node3D.new()
	rotor.name = "Rotor"
	add_child(rotor)
	var rb := MeshBatch.new()
	var r: MeshLayer = rb.layer(solid)
	var step: float = TAU / float(POCKETS)
	for i: int in POCKETS:
		var a0: float = step * float(i)
		var a1: float = a0 + step
		var col: Color = GREEN if i == 0 else (RED if i % 2 == 1 else BLACK)
		_wedge(r, POCKET_IN, POCKET_OUT, a0, a1, POCKET_Y, col)
		# The number ring outside the pockets: the pocket's colour, a fleck of ivory for its number.
		_wedge(r, POCKET_OUT, POCKET_OUT + 0.035, a0, a1, 0.004, col.lightened(0.05))
		var mid: float = (a0 + a1) * 0.5
		r.box_xform(Transform3D(Basis(Vector3.UP, -mid) * Basis.from_scale(Vector3(0.012, 0.002, 0.01)),
			Vector3(cos(mid), 0.0, sin(mid)) * (POCKET_OUT + 0.018) + Vector3(0.0, 0.006, 0.0)), IVORY, 0.0, MeshKit.PAT_PLAIN)
		# The fret between this pocket and the next.
		var fret := Transform3D(Basis(Vector3.UP, -a0) * Basis.from_scale(Vector3(POCKET_OUT - POCKET_IN, 0.022, 0.006)),
			Vector3(cos(a0), 0.0, sin(a0)) * (POCKET_IN + POCKET_OUT) * 0.5 + Vector3(0.0, POCKET_Y + 0.011, 0.0))
		r.box_xform(fret, BRASS, 0.0, MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.9)
	# The cone rising to the turret, its four arms with their knobs.
	_ring(r, POCKET_IN, CONE, POCKET_Y, 0.06, WOOD, 36)
	r.prism(Vector3(0.0, 0.06, 0.0), CONE, 0.02, 24, BRASS, 0.0, MeshKit.PAT_CASINO_BRASS, true, 0.9)
	r.prism(Vector3(0.0, 0.08, 0.0), 0.03, 0.08, 10, BRASS, 0.0, MeshKit.PAT_CASINO_BRASS, true, 0.9)
	for i: int in 4:
		var a: float = TAU * float(i) / 4.0
		var dir := Vector3(cos(a), 0.0, sin(a))
		r.box_xform(Transform3D(Basis(Vector3.UP, -a) * Basis.from_scale(Vector3(0.16, 0.014, 0.014)),
			dir * 0.08 + Vector3(0.0, 0.13, 0.0)), BRASS, 0.0, MeshKit.PAT_CASINO_BRASS, MeshKit.ALL_FACES, 0.9)
		r.prism(dir * 0.16 + Vector3(0.0, 0.118, 0.0), 0.016, 0.026, 8, BRASS, 0.0, MeshKit.PAT_CASINO_BRASS, true, 0.9)
	r.prism(Vector3(0.0, 0.16, 0.0), 0.022, 0.03, 10, BRASS, 0.0, MeshKit.PAT_CASINO_BRASS, true, 1.0)
	MeshBatch.add_instance(rotor, rb.to_mesh(), "Pockets")
	# The ball: an ivory sphere.
	var bb := MeshBatch.new()
	_sphere(bb.layer(solid), BALL, IVORY)
	ball = MeshBatch.add_instance(self, bb.to_mesh(), "Ball")
	for mi: Node in find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The rotor's turn at time `t` (radians, anticlockwise seen from above).
func rotor_angle(t: float, n: CasinoBossIntroTuning) -> float:
	return n.wheel_spin * t


## The ball running free round the track at time `t` (radians, clockwise: the angle falls), slowing to its drop.
func _free_angle(t: float, n: CasinoBossIntroTuning) -> float:
	var tt: float = minf(t, n.ball_settle_at)
	var w0: float = n.ball_spin
	var decay: float = w0 * 0.55 / maxf(n.ball_drop_at, 0.1)
	return 1.3 - (w0 * tt - 0.5 * decay * tt * tt)


## Places the rotor and the ball for time `t`.
func update(t: float, n: CasinoBossIntroTuning) -> void:
	var rot: float = rotor_angle(t, n)
	rotor.rotation.y = rot
	if is_nan(_pocket_angle) or _numbers != n:
		_numbers = n
		var rel: float = _free_angle(n.ball_settle_at, n) - rotor_angle(n.ball_settle_at, n)
		var step: float = TAU / float(POCKETS)
		# Rotor space: a pocket's middle is at (k + 0.5) * step, measured the other way round (rotation.y turns +x
		# toward -z, the wedges are laid out from +x toward +z).
		_pocket_angle = (floor(rel / step) + 0.5) * step
	var angle: float
	var radius: float
	var y: float
	if t < n.ball_drop_at:
		angle = _free_angle(t, n)
		radius = TRACK - 0.04
		y = BALL_TRACK_Y
	else:
		var k: float = clampf((t - n.ball_drop_at) / maxf(n.ball_settle_at - n.ball_drop_at, 0.05), 0.0, 1.0)
		var settled: float = rot + _pocket_angle
		var free: float = _free_angle(t, n)
		angle = lerp_angle(free, settled, smoothstep(0.0, 1.0, k))
		radius = lerpf(TRACK - 0.04, (POCKET_IN + POCKET_OUT) * 0.5, smoothstep(0.0, 0.7, k))
		# Clattering over the frets: bounces dying away as it settles.
		var bounce: float = absf(sin(k * PI * 5.0)) * (1.0 - k) * 0.03
		y = lerpf(BALL_TRACK_Y, POCKET_Y + BALL + 0.002, smoothstep(0.0, 0.6, k)) + bounce
	# rotation.y turns the rotor's +x toward -z; place the ball the same way round.
	ball.position = Vector3(cos(angle) * radius, y, -sin(angle) * radius)


## Whether the ball has come to rest (tests, the review tool).
func ball_settled(t: float, n: CasinoBossIntroTuning) -> bool:
	return t >= n.ball_settle_at


## A flat ring from radius `r0` at height `y0` to `r1` at `y1`, facing up, in `segments` pieces.
static func _ring(s: MeshLayer, r0: float, r1: float, y0: float, y1: float, color: Color, segments: int) -> void:
	for i: int in segments:
		var a0: float = TAU * float(i) / float(segments)
		var a1: float = TAU * float(i + 1) / float(segments)
		var p0 := Vector3(cos(a0) * r0, y0, -sin(a0) * r0)
		var p1 := Vector3(cos(a1) * r0, y0, -sin(a1) * r0)
		var q0 := Vector3(cos(a0) * r1, y1, -sin(a0) * r1)
		var q1 := Vector3(cos(a1) * r1, y1, -sin(a1) * r1)
		_up_quad(s, p0, p1, q1, q0, color)


## One pocket's floor: a wedge from radius `r0` to `r1` between angles `a0` and `a1` at height `y`, facing up.
static func _wedge(s: MeshLayer, r0: float, r1: float, a0: float, a1: float, y: float, color: Color) -> void:
	var p0 := Vector3(cos(a0) * r0, y, -sin(a0) * r0)
	var p1 := Vector3(cos(a1) * r0, y, -sin(a1) * r0)
	var q0 := Vector3(cos(a0) * r1, y, -sin(a0) * r1)
	var q1 := Vector3(cos(a1) * r1, y, -sin(a1) * r1)
	_up_quad(s, p0, p1, q1, q0, color)


## A quad facing up whatever order its corners come in.
static func _up_quad(s: MeshLayer, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	if (c - a).cross(d - b).y > 0.0:
		s.quad(a, d, c, b, color)
	else:
		s.quad(a, b, c, d, color)


## A small low-poly sphere of radius `r` at the origin.
static func _sphere(s: MeshLayer, r: float, color: Color) -> void:
	var rings: int = 5
	var segs: int = 8
	for i: int in rings:
		var t0: float = PI * float(i) / float(rings)
		var t1: float = PI * float(i + 1) / float(rings)
		for j: int in segs:
			var p0: float = TAU * float(j) / float(segs)
			var p1: float = TAU * float(j + 1) / float(segs)
			var a := Vector3(sin(t0) * cos(p0), cos(t0), sin(t0) * sin(p0)) * r
			var b := Vector3(sin(t0) * cos(p1), cos(t0), sin(t0) * sin(p1)) * r
			var c := Vector3(sin(t1) * cos(p1), cos(t1), sin(t1) * sin(p1)) * r
			var d := Vector3(sin(t1) * cos(p0), cos(t1), sin(t1) * sin(p0)) * r
			# Outward-facing whatever the order.
			var mid: Vector3 = (a + b + c + d) * 0.25
			# The diagonals' cross turns the same way as the corners (a pole's quad has two corners in one place).
			if (c - a).cross(d - b).dot(mid) > 0.0:
				s.quad(a, d, c, b, color)
			else:
				s.quad(a, b, c, d, color)

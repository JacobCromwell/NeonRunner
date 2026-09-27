class_name FloatingHeadTower
extends Node3D
## One of GDD §10's "marked, cracked towers" at the roadside of the Floating Head's arena. The player
## baits the eye laser into one (or the laser clips one on its own); it topples onto the ship and pins
## it low across the trucks. FloatingHead plans where they stand (_plan_lap) and brings them into sight;
## FloatingHeadFaceOff clips them; the encounter's pin makes one fall onto the ship.
## DESIGN-TBD (docs/questions/e1.md): the look. Placeholder: a slender, weathered concrete tower block
## standing flush with the facades, its base split by big cracks with bent rebar, a painted white target
## (a ring and a cross, the laser's "aim here") on the faces toward the street and the traffic, and a
## column of cold white warning lights. Nothing on it glows in a hazard colour; the laser's cut across
## its base glows red-hot for a moment when it's clipped (the attack's own colour).
## No hitboxes (task E1b): the runner never reaches it while it stands at the wall line, falls ahead of
## them or lies on the pinned ship (the pin ends before they get there). E1c decides how the fallen
## tower is climbed.
## Tower space: the pivot at the foot of its street-side face, on the floor, the tower rising along +y
## and reaching into the buildings along +x (the node turns a half turn on the left side); the tower is
## the same seen from either end of the street.

enum State { STANDING, CLIPPED, FALLING, FALLEN, CRUMBLING }

## Concrete tones and the painted mark (sRGB). No hazard hues.
const CONCRETE := Color(0.27, 0.28, 0.32)
const CONCRETE_DARK := Color(0.15, 0.15, 0.18)
const CONCRETE_LIGHT := Color(0.36, 0.37, 0.41)
const CRACK := Color(0.04, 0.04, 0.05)
const REBAR := Color(0.3, 0.22, 0.18)
const PAINT := Color(0.86, 0.88, 0.92)
const GLASS := Color(0.06, 0.07, 0.1)
const LIT := Color(0.62, 0.72, 1.0)
const WARNING_LIGHT := Color(0.8, 0.88, 1.0)
## The laser's cut across the base (FloatingHeadFaceOff's burn colour).
const CUT := Color(1.0, 0.36, 0.12)
## How far its street-side face stands proud of the facades (clear of z-fighting, not in the way).
const PROUD: float = 0.05
## How long the cut glows once the tower's clipped.
const CUT_SECONDS: float = 1.6
## Its broken section sinks away this far while it crumbles.
const CRUMBLE_DROP: float = 12.0

var world: RunWorld
var tuning: FloatingHeadTuning
## Its middle's track distance, and its wall (-1 left, +1 right).
var at: float = 0.0
var side: int = 1
var state: State = State.STANDING
## Seconds in the current state.
var state_time: float = 0.0

var _body: Node3D
var _cut: MeshInstance3D
var _cut_material: StandardMaterial3D
var _base_basis := Basis.IDENTITY
var _fall_to := Quaternion.IDENTITY
var _fall_seconds: float = 1.0
var _drop: float = 0.0
var _cut_time: float = 0.0

static var _meshes: Dictionary = {}


func setup(p_world: RunWorld, p_tuning: FloatingHeadTuning, p_at: float, p_side: int) -> void:
	world = p_world
	tuning = p_tuning
	at = p_at
	side = -1 if p_side < 0 else 1
	name = "Tower"
	top_level = true
	_base_basis = Basis.IDENTITY if side > 0 else Basis(Vector3.UP, PI)
	transform = Transform3D(_base_basis, pivot_world())
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	var mesh: ArrayMesh = tower_mesh(tuning.tower_width, tuning.tower_height)
	MeshBatch.add_instance(_body, mesh, "Mesh")
	# The laser's cut: a red-hot line across the base's street side, shown once it's clipped.
	_cut = MeshInstance3D.new()
	_cut.name = "Cut"
	_cut.mesh = GreyboxMaterials.unit_box()
	_cut_material = StandardMaterial3D.new()
	_cut_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cut_material.albedo_color = CUT
	_cut.material_override = _cut_material
	_cut.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cut.transform = Transform3D(Basis.from_scale(Vector3(0.12, 0.22, tuning.tower_width + 0.1)), Vector3(-PROUD - 0.03, 1.3, 0.0))
	_cut.visible = false
	_body.add_child(_cut)


## The pivot (world): the foot of its street-side face, on the floor at the wall line.
func pivot_world() -> Vector3:
	return Vector3(side * world.geo.wall_x(), 0.0, TrackGeometry.world_z(at))


## Where the laser strikes it (world): its base's street-side face, at a runner's height.
func strike_point() -> Vector3:
	return Vector3(side * (world.geo.wall_x() - PROUD), 1.3, TrackGeometry.world_z(at))


## The tower's axis now (world): the direction it rises in, from straight up to lying on the ship.
func axis_world() -> Vector3:
	return (global_transform.basis * Vector3.UP).normalized()


## The laser clipped it: the cut glows, sparks fly, and the crack widens. It starts to fall when the
## encounter says (fall_onto).
func clip() -> void:
	if state != State.STANDING:
		return
	_set_state(State.CLIPPED)
	_cut.visible = true
	world.effects.burst(strike_point(), CUT, 36, 0.9)
	world.effects.burst(strike_point() + Vector3(0.0, 0.6, 0.0), CONCRETE_LIGHT, 24, 1.2)


## Topples onto `rest` (world: the point on the ship's crown where it will lie) over `seconds`,
## pivoting on its foot, faster and faster.
func fall_onto(rest: Vector3, seconds: float) -> void:
	if state == State.FALLING or state == State.FALLEN or state == State.CRUMBLING:
		return
	if state == State.STANDING:
		clip()
	_fall_seconds = maxf(seconds, 0.05)
	_fall_to = _rest_rotation(rest)
	_set_state(State.FALLING)


## While it lies on the ship: keeps resting on `rest` as the ship settles.
func rest_on(rest: Vector3) -> void:
	if state == State.FALLEN:
		transform.basis = Basis(_rest_rotation(rest)) * _base_basis


## Breaks up and drops away (the ship shakes free: E1b's placeholder, task E1c).
func crumble() -> void:
	if state == State.CRUMBLING:
		return
	_set_state(State.CRUMBLING)
	var mid: Vector3 = pivot_world() + axis_world() * tuning.tower_height * 0.35
	world.effects.burst(mid, CONCRETE_LIGHT, 48, 1.6)
	world.effects.burst(mid + axis_world() * 8.0, CONCRETE, 32, 1.4)


## True once it lies on the ship or is gone.
func has_fallen() -> bool:
	return state == State.FALLEN or state == State.CRUMBLING


func _physics_process(delta: float) -> void:
	state_time += delta
	match state:
		State.CLIPPED:
			pass
		State.FALLING:
			# A toppling tower: slow to start, fast at the end.
			var k: float = clampf(state_time / _fall_seconds, 0.0, 1.0)
			var q: Quaternion = Quaternion.IDENTITY.slerp(_fall_to, k * k)
			transform = Transform3D(Basis(q) * _base_basis, pivot_world())
			if k >= 1.0:
				_set_state(State.FALLEN)
		State.CRUMBLING:
			_drop += delta * (4.0 + state_time * 30.0)
			position = pivot_world() + Vector3(0.0, -_drop, 0.0)
			if _drop >= CRUMBLE_DROP:
				queue_free()
	if _cut.visible:
		# The cut cools from white-hot orange to a dull glow, then goes out.
		_cut_time += delta
		var heat: float = clampf(1.0 - _cut_time / CUT_SECONDS, 0.0, 1.0)
		var c: Color = CUT * (0.5 + 1.2 * heat)
		_cut_material.albedo_color = Color(c.r, c.g, c.b, 1.0)
		if heat <= 0.0:
			_cut.visible = false


func _set_state(next: State) -> void:
	state = next
	state_time = 0.0


## The rotation (world) that tips its axis from straight up toward `rest`, resting its street-side
## face (its underside once fallen) on that point.
func _rest_rotation(rest: Vector3) -> Quaternion:
	var dir: Vector3 = rest - pivot_world()
	if dir.length() < 0.5:
		return Quaternion.IDENTITY
	return Quaternion(Vector3.UP, dir.normalized())


# --- The mesh ------------------------------------------------------------------------------------

## The tower (tower space, see the header): cached per size.
static func tower_mesh(width: float, height: float) -> ArrayMesh:
	var id: String = "%.2f|%.2f" % [width, height]
	if _meshes.has(id):
		return _meshes[id]
	var batch := MeshBatch.new()
	var m: MeshLayer = batch.layer(FloatingHeadModel.solid_material())
	var w: float = width
	var hw: float = w * 0.5
	var x0: float = -PROUD
	var cx: float = x0 + hw
	var plinth: float = 4.2
	# The shaft over a heavier plinth, with a cap on top.
	m.box(Vector3(cx, plinth + (height - plinth) * 0.5, 0.0), Vector3(w, height - plinth, w), CONCRETE)
	m.box(Vector3(cx, plinth * 0.5, 0.0), Vector3(w + 0.3, plinth, w + 0.3), CONCRETE_DARK)
	m.box(Vector3(cx, height + 0.4, 0.0), Vector3(w + 0.4, 0.8, w + 0.4), CONCRETE_LIGHT)
	# Floor bands and windows on every face: dark glass, a few lit cold.
	var floor_h: float = 3.4
	var floors: int = int((height - plinth - 1.0) / floor_h)
	for f: int in floors:
		var y: float = plinth + 0.6 + f * floor_h
		m.box(Vector3(cx, y - 0.2, 0.0), Vector3(w + 0.12, 0.25, w + 0.12), CONCRETE_LIGHT)
		for face: int in 4:
			var lit: bool = (f * 7 + face * 3) % 5 == 0
			_window_row(m, face, cx, hw, y + 0.4, floor_h - 1.2, lit)
	# The mark: a painted target on the street side and on both ends (toward and away from the traffic).
	var mark_y: float = clampf(height * 0.42, plinth + 4.0, height - 4.0)
	_mark(m, Transform3D(Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0)), Vector3(x0 - 0.02, mark_y, 0.0)), w)
	for end: float in [-1.0, 1.0]:
		var face_basis := Basis(Vector3(end, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, end))
		_mark(m, Transform3D(face_basis, Vector3(cx, mark_y, end * (hw + 0.02))), w)
	# Cracks up the plinth and the first floors, with bent rebar sticking out of the widest.
	_cracks(m, x0, cx, hw, plinth)
	# A column of cold warning lights up its street-side edges, and a mast on the cap.
	for z: float in [-hw + 0.25, hw - 0.25]:
		var y: float = plinth + 2.0
		while y < height - 1.0:
			m.box(Vector3(x0 - 0.04, y, z), Vector3(0.1, 0.22, 0.22), WARNING_LIGHT, 1.0, MeshKit.PAT_PLAIN,
				MeshKit.ALL_FACES & ~MeshKit.FACE_PX)
			y += 6.0
	m.box(Vector3(cx, height + 3.0, 0.0), Vector3(0.18, 4.6, 0.18), CONCRETE_DARK)
	m.box(Vector3(cx, height + 5.4, 0.0), Vector3(0.3, 0.3, 0.3), WARNING_LIGHT, 1.2)
	var out: ArrayMesh = batch.to_mesh()
	_meshes[id] = out
	return out


## A row of windows on one face (0: the street side, 1: the far side, 2 and 3: the ends).
static func _window_row(m: MeshLayer, face: int, cx: float, hw: float, y: float, h: float, lit: bool) -> void:
	var count: int = maxi(int(hw * 2.0 / 1.2), 2)
	var pane: float = hw * 2.0 / count
	for i: int in count:
		var u: float = -hw + (float(i) + 0.5) * pane
		var color: Color = LIT if lit and i % 2 == 0 else GLASS
		var glow: float = 0.45 if lit and i % 2 == 0 else 0.0
		var size := Vector3(0.06, h, pane * 0.7)
		match face:
			0:
				m.box(Vector3(cx - hw - 0.02, y + h * 0.5, u), size, color, glow)
			1:
				m.box(Vector3(cx + hw + 0.02, y + h * 0.5, u), size, color, glow)
			2:
				m.box(Vector3(cx + u, y + h * 0.5, hw + 0.02), Vector3(pane * 0.7, h, 0.06), color, glow)
			3:
				m.box(Vector3(cx + u, y + h * 0.5, -hw - 0.02), Vector3(pane * 0.7, h, 0.06), color, glow)


## The painted target on a face (`xform`: x across the face, y up, z out of it): a ring and a cross.
static func _mark(m: MeshLayer, xform: Transform3D, width: float) -> void:
	var r: float = minf(width * 0.42, 2.2)
	var t: float = 0.22
	var sides: int = 16
	for i: int in sides:
		var a0: float = TAU * i / sides
		var a1: float = TAU * (i + 1) / sides
		var p0 := Vector3(cos(a0), sin(a0), 0.0) * r
		var p1 := Vector3(cos(a1), sin(a1), 0.0) * r
		var q0 := Vector3(cos(a0), sin(a0), 0.0) * (r - t)
		var q1 := Vector3(cos(a1), sin(a1), 0.0) * (r - t)
		m.quad(xform * q0, xform * q1, xform * p1, xform * p0, PAINT, 0.3)
	for bar: Vector2 in [Vector2(r * 1.25, t), Vector2(t, r * 1.25)]:
		var hx: float = bar.x
		var hy: float = bar.y
		m.quad(xform * Vector3(-hx, -hy * 0.5, 0.0), xform * Vector3(-hx, hy * 0.5, 0.0),
			xform * Vector3(hx, hy * 0.5, 0.0), xform * Vector3(hx, -hy * 0.5, 0.0), PAINT, 0.3)


## Dark cracks zig-zagging up the plinth's street side and ends, with rebar out of the widest.
static func _cracks(m: MeshLayer, x0: float, cx: float, hw: float, plinth: float) -> void:
	var paths: Array = [
		[Vector2(-0.6, 0.0), Vector2(-0.2, 1.1), Vector2(-0.5, 2.0), Vector2(0.1, 3.1), Vector2(-0.1, 4.6), Vector2(0.4, 6.0)],
		[Vector2(0.9, 0.0), Vector2(0.6, 0.9), Vector2(1.0, 1.8), Vector2(0.7, 2.6)],
		[Vector2(-1.2, 1.6), Vector2(-0.7, 2.2), Vector2(-1.0, 3.3)],
	]
	for path: Array in paths:
		for i: int in path.size() - 1:
			var a: Vector2 = path[i]
			var b: Vector2 = path[i + 1]
			var aa := Vector3(x0 - 0.18, a.y, clampf(a.x, -hw + 0.2, hw - 0.2))
			var bb := Vector3(x0 - 0.18, b.y, clampf(b.x, -hw + 0.2, hw - 0.2))
			FloatingHeadModel._bar(m, aa, bb, 0.16, CRACK, 0.0, Vector3(-1, 0, 0))
			# The same crack round the corner on each end.
			for end: float in [-1.0, 1.0]:
				var ea := Vector3(cx + clampf(a.x, -hw + 0.2, hw - 0.2), a.y, end * (hw + 0.17))
				var eb := Vector3(cx + clampf(b.x, -hw + 0.2, hw - 0.2), b.y, end * (hw + 0.17))
				FloatingHeadModel._bar(m, ea, eb, 0.14, CRACK, 0.0, Vector3(0, 0, end))
	for r: Vector3 in [Vector3(x0 - 0.25, 1.1, -0.2), Vector3(x0 - 0.25, 2.0, -0.5), Vector3(x0 - 0.25, 3.0, 0.1)]:
		FloatingHeadModel._bar(m, r, r + Vector3(-0.5, 0.25, 0.15), 0.06, REBAR, 0.0, Vector3(0, 1, 0))
	# Chunks missing from the plinth's corners.
	m.box(Vector3(x0 + 0.2, plinth - 0.4, hw - 0.3), Vector3(0.7, 0.9, 0.8), CONCRETE_LIGHT)

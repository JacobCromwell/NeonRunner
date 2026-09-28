class_name FloatingHeadTower
extends Node3D
## One of GDD §10's "marked, cracked towers" at the roadside of the Floating Head's arena. The player
## baits the eye laser into one (or the laser clips one on its own); it topples onto the ship and pins
## it low across the trucks. FloatingHead plans where they stand (_plan_lap) and brings them into sight;
## FloatingHeadFaceOff clips them; the encounter's pin makes one fall onto the ship.
## DESIGN-TBD (docs/OPEN_QUESTIONS.md §D, item 119): the look. Placeholder: a slender tower block of
## pale, weathered concrete standing flush with the dark facades, its heavy head jutting out over the
## street high up (so it shows from far along the street), its base split by big cracks with bent
## rebar, painted white bands, big white targets (a ring and a cross, the laser's "aim here") on its
## head's faces toward the street and the traffic, and cold white warning lights up its street-side
## edges and under its head. Nothing on it glows in a hazard colour; the laser's cut across its base
## glows red-hot for a moment when it's clipped (the attack's own colour).
## As it crashes onto the ship it breaks in two (break_at; DESIGN-TBD, docs/OPEN_QUESTIONS.md §D,
## item 159): the upper section stays on the ship's back, behind its weak points, and the lower
## section, which would lie across the lanes in front of it, drops away in a cloud of dust (or makes the
## first stomp window's ramp, FloatingHeadRamp, in its place). When the ship shakes free, the rest drops
## away too.
## No hitboxes: the runner never reaches it while it stands at the wall line, falls ahead of them or
## lies on the pinned ship behind its weak points (a stomp window closes before they run that far).
## Tower space: the pivot at the foot of its street-side face, on the floor, the tower rising along +y
## and reaching into the buildings along +x (the node turns a half turn on the left side); the tower is
## the same seen from either end of the street.

enum State { STANDING, CLIPPED, FALLING, FALLEN, CRUMBLING }

## Concrete tones and the painted mark (sRGB): paler than the City's facades. No hazard hues.
const CONCRETE := Color(0.5, 0.51, 0.54)
const CONCRETE_DARK := Color(0.3, 0.3, 0.33)
const CONCRETE_LIGHT := Color(0.62, 0.63, 0.66)
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
## Its head (the top HEAD_SHARE of it) juts out this far over the street, so the runner sees it coming
## along the street; it stays above everything that flies down the street (the ship at its bombing
## station tops out about 24 m up).
const OVERHANG: float = 2.8
const HEAD_SHARE: float = 0.3
## How long the cut glows once the tower's clipped.
const CUT_SECONDS: float = 1.6
## Its broken section sinks away this far while it crumbles.
const CRUMBLE_DROP: float = 12.0
## A broken end's jagged cap stands this far out of the section.
const JAG: float = 0.7

var world: RunWorld
var tuning: FloatingHeadTuning
## Its middle's track distance, and its wall (-1 left, +1 right).
var at: float = 0.0
var side: int = 1
var state: State = State.STANDING
## Seconds in the current state.
var state_time: float = 0.0
## How far up its length it broke as it crashed onto the ship (0: whole).
var break_y: float = 0.0

var _body: Node3D
var _mesh: MeshInstance3D
var _cut: MeshInstance3D
var _cut_material: StandardMaterial3D
var _base_basis := Basis.IDENTITY
var _fall_to := Quaternion.IDENTITY
var _fall_seconds: float = 1.0
var _drop: float = 0.0
var _cut_time: float = 0.0
## The broken-off lower section, dropping away, and how far it has sunk.
var _lower: Node3D
var _lower_from := Vector3.ZERO
var _lower_drop: float = 0.0
var _lower_time: float = 0.0

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
	_mesh = MeshBatch.add_instance(_body, mesh, "Mesh")
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


## Breaks it in two `y` metres up its length as it lands on the ship (the stomp windows keep the lanes
## in front of the ship clear): the section above stays where it lies, the section below drops away in a
## cloud of dust. Once only.
func break_at(y: float) -> void:
	if break_y > 0.0 or y <= 0.5 or y >= tuning.tower_height - 0.5:
		return
	break_y = y
	_mesh.mesh = tower_mesh(tuning.tower_width, tuning.tower_height, y, INF)
	_cut.visible = false
	_lower = Node3D.new()
	_lower.name = "LowerSection"
	_lower.top_level = true
	add_child(_lower)
	_lower.global_transform = global_transform
	_lower_from = _lower.global_position
	_lower_drop = 0.0
	_lower_time = 0.0
	MeshBatch.add_instance(_lower, tower_mesh(tuning.tower_width, tuning.tower_height, 0.0, y), "Mesh")
	var axis: Vector3 = axis_world()
	for k: float in [0.2, 0.5, 0.85]:
		world.effects.burst(pivot_world() + axis * y * k + Vector3(0.0, 0.5, 0.0), CONCRETE_LIGHT, 28, 1.5)
	world.effects.burst(pivot_world() + axis * y, CONCRETE, 36, 1.6)


## Where it broke (world): the middle of the break across its street-side face; its pivot while whole.
func break_point() -> Vector3:
	return pivot_world() + axis_world() * break_y


## Breaks up and drops away (the ship shakes free): what's left of it on the ship sinks away in dust.
func crumble() -> void:
	if state == State.CRUMBLING:
		return
	_set_state(State.CRUMBLING)
	var from: float = break_y
	var mid: Vector3 = pivot_world() + axis_world() * lerpf(from, tuning.tower_height, 0.3)
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
	if _lower != null and is_instance_valid(_lower):
		# The broken-off section drops away, faster and faster, into the dust.
		_lower_time += delta
		_lower_drop += delta * (3.0 + _lower_time * 36.0)
		_lower.global_position = _lower_from + Vector3(0.0, -_lower_drop, 0.0)
		if _lower_drop >= CRUMBLE_DROP:
			_lower.queue_free()
			_lower = null
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

## The tower (tower space, see the header), or the section of it between `from_y` and `to_y` up its
## length (a broken end gets a jagged cap of torn concrete and rebar): cached per size and section.
static func tower_mesh(width: float, height: float, from_y: float = 0.0, to_y: float = INF) -> ArrayMesh:
	var id: String = "%.2f|%.2f|%.2f|%.2f" % [width, height, from_y, minf(to_y, 1.0e6)]
	if _meshes.has(id):
		return _meshes[id]
	var batch := MeshBatch.new()
	var m: MeshLayer = batch.layer(FloatingHeadModel.solid_material())
	var cut := Vector2(from_y, to_y)
	var w: float = width
	var hw: float = w * 0.5
	var x0: float = -PROUD
	var cx: float = x0 + hw
	var plinth: float = 4.2
	var head_y: float = height * (1.0 - HEAD_SHARE)
	# The shaft over a heavier plinth, up to its head.
	_cut_box(m, cut, Vector3(cx, plinth + (head_y - plinth) * 0.5, 0.0), Vector3(w, head_y - plinth, w), CONCRETE)
	_cut_box(m, cut, Vector3(cx, plinth * 0.5, 0.0), Vector3(w + 0.3, plinth, w + 0.3), CONCRETE_DARK)
	# Its head: a heavier block jutting out over the street, on a dark ledge, with a cap on top.
	var hx0: float = x0 - OVERHANG
	var hlen: float = w + OVERHANG
	var hcx: float = hx0 + hlen * 0.5
	var hd: float = w + 0.6
	var hy: float = (head_y + height) * 0.5
	_cut_box(m, cut, Vector3(hcx, hy, 0.0), Vector3(hlen, height - head_y, hd), CONCRETE)
	_cut_box(m, cut, Vector3(hcx, head_y - 0.25, 0.0), Vector3(hlen + 0.3, 0.5, hd + 0.3), CONCRETE_DARK)
	_cut_box(m, cut, Vector3(hcx, height + 0.4, 0.0), Vector3(hlen + 0.4, 0.8, hd + 0.4), CONCRETE_LIGHT)
	# Floor bands and windows up the shaft: dark glass, a few lit cold.
	var floor_h: float = 3.4
	var floors: int = int((head_y - plinth - 1.0) / floor_h)
	for f: int in floors:
		var y: float = plinth + 0.6 + f * floor_h
		_cut_box(m, cut, Vector3(cx, y - 0.2, 0.0), Vector3(w + 0.12, 0.25, w + 0.12), CONCRETE_LIGHT)
		if _within(cut, y + 0.4, y + floor_h - 0.8):
			for face: int in 4:
				var lit: bool = (f * 7 + face * 3) % 5 == 0
				_window_row(m, face, cx, hw, y + 0.4, floor_h - 1.2, lit)
	# The mark: painted bands round the shaft, a big painted target on each end of the head (toward
	# and away from the traffic: the side the runner sees coming) and on its street side, and a smaller
	# one on the shaft.
	for band_y: float in [plinth + 3.0, head_y - 3.2]:
		_cut_box(m, cut, Vector3(cx, band_y, 0.0), Vector3(w + 0.1, 1.1, w + 0.1), PAINT, 0.35)
	var head_mark: float = minf(hlen, height - head_y) * 0.42
	var shaft_mark: float = w * 0.42
	for end: float in [-1.0, 1.0]:
		var face_basis := Basis(Vector3(end, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, end))
		if _within(cut, hy - head_mark, hy + head_mark):
			_mark(m, Transform3D(face_basis, Vector3(hcx, hy, end * (hd * 0.5 + 0.02))), minf(hlen, height - head_y), 3.0)
		if _within(cut, head_y * 0.55 - shaft_mark, head_y * 0.55 + shaft_mark):
			_mark(m, Transform3D(face_basis, Vector3(cx, head_y * 0.55, end * (hw + 0.02))), w)
	var street := Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0))
	if _within(cut, hy - head_mark, hy + head_mark):
		_mark(m, Transform3D(street, Vector3(hx0 - 0.02, hy, 0.0)), minf(hd, height - head_y), 3.0)
	if _within(cut, head_y * 0.55 - shaft_mark, head_y * 0.55 + shaft_mark):
		_mark(m, Transform3D(street, Vector3(x0 - 0.02, head_y * 0.55, 0.0)), w)
	# Cracks up the plinth and the first floors, with bent rebar sticking out of the widest.
	if _within(cut, 0.0, 6.0):
		_cracks(m, x0, cx, hw, plinth)
	# Columns of cold warning lights up the shaft's street-side edges, a row under the head's street
	# edge, and a mast on the cap.
	for z: float in [-hw + 0.25, hw - 0.25]:
		var y: float = plinth + 1.5
		while y < head_y - 1.0:
			if _within(cut, y - 0.25, y + 0.25):
				m.box(Vector3(x0 - 0.06, y, z), Vector3(0.14, 0.5, 0.32), WARNING_LIGHT, 1.8, MeshKit.PAT_PLAIN,
					MeshKit.ALL_FACES & ~MeshKit.FACE_PX)
			y += 3.5
	if _within(cut, head_y - 0.63, head_y - 0.49):
		for i: int in 5:
			var z: float = lerpf(-hd * 0.5 + 0.3, hd * 0.5 - 0.3, i / 4.0)
			m.box(Vector3(hx0 + 0.35, head_y - 0.56, z), Vector3(0.4, 0.14, 0.4), WARNING_LIGHT, 1.8)
	if _within(cut, height, height + 5.6):
		m.box(Vector3(hx0 + 0.8, height + 3.0, 0.0), Vector3(0.18, 4.6, 0.18), CONCRETE_DARK)
		m.box(Vector3(hx0 + 0.8, height + 5.4, 0.0), Vector3(0.3, 0.3, 0.3), WARNING_LIGHT, 1.2)
	# A broken end: torn concrete and rebar sticking out of the break.
	for end: Vector2 in [Vector2(from_y, -1.0), Vector2(to_y, 1.0)]:
		if end.x <= 0.0 or end.x >= height:
			continue
		var in_head: bool = end.x >= head_y
		_break_cap(m, end.x, end.y, hlen * 0.5 if in_head else hw, hcx if in_head else cx, hd * 0.5 if in_head else hw)
	var out: ArrayMesh = batch.to_mesh()
	_meshes[id] = out
	return out


## True if [lo, hi] lies within the section `cut` (x: from, y: to up the tower's length).
static func _within(cut: Vector2, lo: float, hi: float) -> bool:
	return lo >= cut.x - 0.001 and hi <= cut.y + 0.001


## A box cut to the section `cut` (x: from, y: to up the tower's length); nothing if it lies outside.
static func _cut_box(m: MeshLayer, cut: Vector2, center: Vector3, size: Vector3, color: Color, glow: float = 0.0) -> void:
	var lo: float = maxf(center.y - size.y * 0.5, cut.x)
	var hi: float = minf(center.y + size.y * 0.5, cut.y)
	if hi - lo < 0.01:
		return
	m.box(Vector3(center.x, (lo + hi) * 0.5, center.z), Vector3(size.x, hi - lo, size.z), color, glow)


## The jagged end of a break `y` up the tower, sticking out `dir` (-1 down, +1 up): blocks of torn
## concrete of hashed heights over the section (half sizes hx across, hz along the street, centred on
## x = mid), and bent rebar out of it.
static func _break_cap(m: MeshLayer, y: float, dir: float, hx: float, mid: float, hz: float) -> void:
	for i: int in 3:
		for j: int in 3:
			var h: float = JAG * (0.25 + 0.75 * MeshKit.hash01(i, j, 41))
			var c := Vector3(mid + (float(i) - 1.0) * hx * 2.0 / 3.0, y + dir * h * 0.5, (float(j) - 1.0) * hz * 2.0 / 3.0)
			m.box(c, Vector3(hx * 2.0 / 3.0 - 0.04, h, hz * 2.0 / 3.0 - 0.04), CONCRETE_DARK if (i + j) % 2 == 0 else CONCRETE)
	for k: int in 5:
		var a := Vector3(mid + (MeshKit.hash01(k, 3, 7) - 0.5) * hx * 1.6, y, (MeshKit.hash01(k, 5, 9) - 0.5) * hz * 1.6)
		var b: Vector3 = a + Vector3((MeshKit.hash01(k, 1, 2) - 0.5) * 0.8, dir * (JAG + 0.5), (MeshKit.hash01(k, 2, 1) - 0.5) * 0.8)
		FloatingHeadModel._bar(m, a, b, 0.07, REBAR, 0.0, Vector3(0, 0, 1))


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


## The painted target on a face (`xform`: x across the face, y up, z out of it): a ring and a cross,
## as big as `width` allows, `max_radius` at most.
static func _mark(m: MeshLayer, xform: Transform3D, width: float, max_radius: float = 2.2) -> void:
	var r: float = minf(width * 0.42, max_radius)
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

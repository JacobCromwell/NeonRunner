class_name GoldenConvergenceModel
extends RefCounted
## The golden suit's meshes (GDD §10, the golden suit: "a man's shape, a giant golden behemoth, with
## extra-large shoulders, arms and hands. A calm human face, cast in gold, with a red tear. The tear is a dull
## red and never glows ... the cult's own symbols (the Convergent Triad, halo rings like the Resonator's),
## gold filigree ... Pipes come out of its shoulders ... No legs: metallic pipes, almost like tentacles, trail
## from its lower body ... The cape ... a huge, undulating cloud of burgundy cloth with lots of black folds and
## shadows ... It never glows"), built once in code at its reference size (the suit's local space: its waist
## at the origin, +y up, +z its front, toward the runner) and shared: about 23 m from the waist to its crown,
## 30 m across the shoulders, its hands hanging to about 17 m below the shoulders, its tentacle pipes trailing
## about 70 m back, the outer ones out past the causeway's edges. Low-poly and flat-shaded through the mesh kit's solid shader (MeshKit.solid with the Golden
## Zone's gold: PAT_GOLD, reflective metal lit by the scene, never emissive), in a few meshes, one per moving
## part (the encounter's GoldenConvergenceSuit puts them on nodes):
##   torso       the trunk, the huge pauldrons, the collar, the belt, the pelvis the pipes trail from, gold
##               filigree and the Convergent Triad in gold relief on its chest (gold alone: no red stone,
##               red means a weak point)
##   plates      the chest's two front plates (the third ship's blast bursts them open: stage 2's entrance),
##               left and right
##   head        the calm face (a relief on the head's front: brow, heavy half-closed lids, a straight nose,
##               closed lips with a faint smile, chin; its marks coloured per corner, face_color), the dull red
##               tear from under its left eye (the runner's right; unpolished, never glowing), a three-pointed
##               diadem
##   halo        two rings joined by rays behind the head, the Resonator's halos made huge
##   upper_arm, forearm, segment (one telescoping golden segment, E5d-b's arm), hand (open), fist
##   pipes      a shoulder's row of missile pipes (E5d-b's barrage), pipe_cap the hatch over their mouths (it
##               hinges open: hatch_hinge), pipes_torn the row blown out (E5d-c)
##   tentacles   the pipes trailing from the pelvis, beyond the view
##   cape        the cape's cloud (its own shader: golden_convergence_cape.gdshader), two sheets of a grid
##               fanned out behind the suit, UV the cloth's (u across, v out from the shoulders)

## DESIGN-TBD (docs/questions/e5d.md, E5d-a 2): the look as built (the face's expression and the tear's
## place, the diadem, the pipes' row and hatch, the tentacles' sweep, the cape's fan of pleats) is the owner's
## to review.

## Arm proportions (metres at scale 1): the shoulder joint, the upper arm and forearm, and the telescoping
## segments nested inside the forearm (E5d-b slides them out: GoldenConvergenceSuit.arm_extend).
const SHOULDER := Vector3(12.6, 12.4, 0.6)
const UPPER_ARM: float = 7.6
const FOREARM: float = 7.0
const SEGMENTS: int = 5
const SEGMENT: float = 6.6
const HAND: float = 4.2
## The shoulder pipes: where each cluster sits on its pauldron, how long and wide a pipe is.
const PIPES_AT := Vector3(10.4, 16.4, -2.9)
const PIPE_COUNT: int = 4
const PIPE_LENGTH: float = 8.0
const PIPE_RADIUS: float = 0.62
## The pipes stand in a row across the pauldron, this far apart.
const PIPE_SPACING: float = 1.5
## The head (the face's middle) and the chest emblem.
const HEAD := Vector3(0.0, 20.0, 0.6)
const HEAD_RADII := Vector3(3.1, 4.1, 3.2)
## The face's features are drawn for a head of this size (face_relief, face_feature), then scaled to HEAD_RADII.
const FACE_REF := Vector3(2.45, 3.7, 3.0)
## How deep the relief is cast, over its drawn depth (deep enough to read from the far end of the court).
const RELIEF: float = 1.5
## The creases of the closed lids, the lips and the nostrils: a deep bronze, so the calm face reads at a
## glance whatever the gold's reflections do.
const CREASE := Color(0.3, 0.21, 0.1)
## The chest's front plates (an ellipsoid's front), and the abdomen's.
const CHEST := Vector3(0.0, 10.2, -0.4)
const CHEST_RADII := Vector3(7.7, 5.0, 4.5)
const ABDOMEN := Vector3(0.0, 3.6, 0.0)
const ABDOMEN_RADII := Vector3(5.2, 4.4, 3.7)
## The cape's anchor along the shoulders' back, and its cloud's reach.
const CAPE_ANCHOR_Y: float = 14.6
const CAPE_ANCHOR_Z: float = -3.6
const CAPE_ANCHOR_HALF: float = 11.0
## Colours (sRGB): the gold, a deeper bronze for joints and bores, the dark of the pipes' mouths, the tear's
## dull red (well under the hazards' saturation and brightness: it never reads as a weak point).
const GOLD := Color(0.85, 0.67, 0.42)
const GOLD_PALE := Color(0.92, 0.8, 0.53)
const BRONZE := Color(0.48, 0.33, 0.16)
const BORE := Color(0.06, 0.05, 0.045)
## The chest's cavity behind its plates: a dark bronze.
const CAVITY := Color(0.16, 0.12, 0.08)
const TEAR := Color(0.36, 0.08, 0.075)
## The half-closed eyes' openings: a duller, darker gold under the heavy lids.
const EYE := Color(0.56, 0.45, 0.28)
const CAPE_SHADER: String = "res://scripts/bosses/golden_convergence/golden_convergence_cape.gdshader"

static var _meshes: Dictionary = {}


## Every mesh, built with `material` (the kit's solid material with the Golden Zone's gold) and cached:
## {torso, plates_left, plates_right, head, halo, upper_arm, forearm, segment, hand, fist, pipes, pipe_cap,
## pipes_torn, tentacles, cape}. `low` builds the cape coarser (the Compatibility renderer).
static func meshes(material: Material, low: bool = false) -> Dictionary:
	var key: String = "%d|%s" % [material.get_instance_id(), low]
	if _meshes.has(key):
		return _meshes[key]
	var out: Dictionary = {
		"torso": _torso(material),
		"plates_left": _plate(material, -1),
		"plates_right": _plate(material, 1),
		"head": _head(material),
		"halo": _halo(material),
		"upper_arm": _upper_arm(material),
		"forearm": _forearm(material),
		"segment": _segment(material),
		"hand": _hand(material, false),
		"fist": _hand(material, true),
		"pipes": _pipes(material),
		"pipe_cap": _pipe_cap(material),
		"pipes_torn": _pipes_torn(material),
		"tentacles": _tentacles(material),
		"cape": _cape(low),
	}
	_meshes[key] = out
	return out


## The cape's material (one per suit: its unfurl and time are its own).
static func cape_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(CAPE_SHADER) as Shader
	m.set_shader_parameter(&"anchor_y", CAPE_ANCHOR_Y)
	m.set_shader_parameter(&"anchor_z", CAPE_ANCHOR_Z)
	m.set_shader_parameter(&"anchor_half", CAPE_ANCHOR_HALF)
	m.set_shader_parameter(&"unfurl", 1.0)
	return m


# --- Primitives ------------------------------------------------------------------------------------

## A low-poly ellipsoid (rings from bottom to top, segs around), part of it: latitude from `lat0` to `lat1`
## (radians, -PI/2 the bottom), longitude from `lon0` to `lon1` (0 the front, +z). `inward`: its faces turned
## to its inside (a hollow's lining).
static func _ellipsoid(s: MeshLayer, center: Vector3, radii: Vector3, rings: int, segs: int, color: Color,
		pattern: int = MeshKit.PAT_GOLD, param: float = 0.6, lat0: float = -PI * 0.5, lat1: float = PI * 0.5,
		lon0: float = -PI, lon1: float = PI, basis: Basis = Basis.IDENTITY, inward: bool = false) -> void:
	for r: int in rings:
		var a0: float = lerpf(lat0, lat1, float(r) / rings)
		var a1: float = lerpf(lat0, lat1, float(r + 1) / rings)
		for q: int in segs:
			var b0: float = lerpf(lon0, lon1, float(q) / segs)
			var b1: float = lerpf(lon0, lon1, float(q + 1) / segs)
			var p00: Vector3 = center + basis * (_dir(a0, b0) * radii)
			var p01: Vector3 = center + basis * (_dir(a0, b1) * radii)
			var p11: Vector3 = center + basis * (_dir(a1, b1) * radii)
			var p10: Vector3 = center + basis * (_dir(a1, b0) * radii)
			var mid: Vector3 = (p00 + p11) * 0.5 - center
			_quad(s, p00, p01, p11, p10, -mid if inward else mid, color, pattern, param)


static func _dir(lat: float, lon: float) -> Vector3:
	return Vector3(sin(lon) * cos(lat), sin(lat), cos(lon) * cos(lat))


## The front (+z) of the ellipsoid at `center` with `radii` over (x, y), plus `lift` (0 off its edge).
static func front_z(center: Vector3, radii: Vector3, x: float, y: float, lift: float = 0.0) -> float:
	var k: float = 1.0 - pow((x - center.x) / radii.x, 2.0) - pow((y - center.y) / radii.y, 2.0)
	return center.z + radii.z * sqrt(maxf(k, 0.0)) + lift


## The chest's front at (x, y): the front plates' surface (CHEST, CHEST_RADII).
static func chest_z(x: float, y: float, lift: float = 0.0) -> float:
	return front_z(CHEST, CHEST_RADII, x, y, lift)


## A tube along `points` (a polyline), its radius from `r0` at the start to `r1` at the end, `sides` faces
## around; `closed` joins its end back to its start (a ring). Bands of `band` colour every `band_every`
## points (0: none), the pipes' ridges.
static func _tube(s: MeshLayer, points: Array[Vector3], r0: float, r1: float, sides: int, color: Color,
		pattern: int = MeshKit.PAT_GOLD, param: float = 0.6, closed: bool = false, band: Color = Color(),
		band_every: int = 0, caps: bool = true) -> void:
	var n: int = points.size()
	if n < 2:
		return
	var rings: Array[PackedVector3Array] = []
	var prev_side: Vector3 = Vector3.ZERO
	for i: int in n:
		var tangent: Vector3
		if closed:
			tangent = points[(i + 1) % n] - points[(i - 1 + n) % n]
		elif i == 0:
			tangent = points[1] - points[0]
		elif i == n - 1:
			tangent = points[n - 1] - points[n - 2]
		else:
			tangent = points[i + 1] - points[i - 1]
		tangent = tangent.normalized()
		var side: Vector3
		if prev_side == Vector3.ZERO:
			var ref: Vector3 = Vector3.UP if absf(tangent.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
			side = tangent.cross(ref).normalized()
		else:
			side = (prev_side - tangent * prev_side.dot(tangent)).normalized()
		prev_side = side
		var up: Vector3 = side.cross(tangent).normalized()
		var r: float = lerpf(r0, r1, float(i) / float(n - 1 if not closed else n))
		var ring := PackedVector3Array()
		for k: int in sides:
			var a: float = TAU * float(k) / sides
			ring.append(points[i] + (side * cos(a) + up * sin(a)) * r)
		rings.append(ring)
	var count: int = n if closed else n - 1
	for i: int in count:
		var ra: PackedVector3Array = rings[i]
		var rb: PackedVector3Array = rings[(i + 1) % n]
		var c: Color = band if band_every > 0 and i % band_every == 0 else color
		var center: Vector3 = (points[i] + points[(i + 1) % n]) * 0.5
		for k: int in sides:
			var k1: int = (k + 1) % sides
			_quad(s, ra[k], ra[k1], rb[k1], rb[k], (ra[k] + rb[k1]) * 0.5 - center, c, pattern, param)
	if caps and not closed:
		for end: int in [0, n - 1]:
			var ring: PackedVector3Array = rings[end]
			var out: Vector3 = (points[end] - points[1 if end == 0 else n - 2]).normalized()
			for k: int in sides:
				_tri(s, points[end], ring[k], ring[(k + 1) % sides], out, color, pattern, param)


## A smooth curve through `controls` (Catmull-Rom), `per` points between each two.
static func _curve(controls: Array[Vector3], per: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var n: int = controls.size()
	for i: int in n - 1:
		var p0: Vector3 = controls[maxi(i - 1, 0)]
		var p1: Vector3 = controls[i]
		var p2: Vector3 = controls[i + 1]
		var p3: Vector3 = controls[mini(i + 2, n - 1)]
		for k: int in per:
			var t: float = float(k) / per
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
	out.append(controls[n - 1])
	return out


## A four-cornered face toward `outward` (either winding).
static func _quad(s: MeshLayer, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3, color: Color,
		pattern: int, param: float) -> void:
	if (b - a).cross(c - a).dot(outward) > 0.0:
		s.quad(a, d, c, b, color, 0.0, pattern, param)
	else:
		s.quad(a, b, c, d, color, 0.0, pattern, param)


## A triangle toward `outward`.
static func _tri(s: MeshLayer, a: Vector3, b: Vector3, c: Vector3, outward: Vector3, color: Color, pattern: int,
		param: float) -> void:
	var p := Vector2(pattern, param)
	var col := Color(color, 0.0)
	if (b - a).cross(c - a).dot(outward) > 0.0:
		s.verts.append_array(PackedVector3Array([a, c, b]))
	else:
		s.verts.append_array(PackedVector3Array([a, b, c]))
	s.colors.append_array(PackedColorArray([col, col, col]))
	s.uvs.append_array(PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]))
	s.uv2s.append_array(PackedVector2Array([p, p, p]))


## A triangle toward `outward`, a colour per corner (its alpha the gold's polish), in the kit's gold.
static func _tri_shaded(s: MeshLayer, p: Array, cols: Array, outward: Vector3) -> void:
	var a: Vector3 = p[0]
	var b: Vector3 = p[1]
	var d: Vector3 = p[2]
	var order := PackedInt32Array([0, 2, 1]) if (b - a).cross(d - a).dot(outward) > 0.0 else PackedInt32Array([0, 1, 2])
	for i: int in order:
		var col: Color = cols[i]
		s.verts.append(p[i])
		s.colors.append(Color(col.r, col.g, col.b, 0.0))
		s.uvs.append(Vector2.ZERO)
		s.uv2s.append(Vector2(MeshKit.PAT_GOLD, col.a))


## A box placed by `xform` (a unit box, centred), in gold.
static func _box(s: MeshLayer, xform: Transform3D, color: Color, pattern: int = MeshKit.PAT_GOLD, param: float = 0.6) -> void:
	s.box_xform(xform, color, 0.0, pattern, MeshKit.ALL_FACES, param)


## A box from `a` to `b` (its long axis), `w` wide and `h` thick, its width across `across`.
static func _bar(s: MeshLayer, a: Vector3, b: Vector3, w: float, h: float, color: Color, across: Vector3 = Vector3.RIGHT,
		pattern: int = MeshKit.PAT_GOLD, param: float = 0.6) -> void:
	var along: Vector3 = b - a
	var z: Vector3 = along.normalized()
	var x: Vector3 = (across - z * across.dot(z)).normalized()
	if x.length_squared() < 0.01:
		x = z.cross(Vector3.UP).normalized()
	var y: Vector3 = z.cross(x)
	_box(s, Transform3D(Basis(x * w, y * h, z * along.length()), (a + b) * 0.5), color, pattern, param)


static func _mesh(batch: MeshBatch) -> ArrayMesh:
	return batch.to_mesh()


# --- The parts ----------------------------------------------------------------------------------------

static func _torso(material: Material) -> ArrayMesh:
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(material)
	# The trunk: the abdomen, the chest (its front plates are their own meshes), the back.
	_ellipsoid(s, ABDOMEN, ABDOMEN_RADII, 6, 12, GOLD, MeshKit.PAT_GOLD, 0.55)
	_ellipsoid(s, Vector3(0.0, 10.2, -0.4), Vector3(7.6, 4.9, 4.4), 7, 14, GOLD, MeshKit.PAT_GOLD, 0.55,
		-PI * 0.5, PI * 0.5, PI * 0.36, PI * 1.64)
	# The cavity behind the chest's plates (the burst opens it: the room the man inside rides in, stage 2's
	# entrance), lined in dark bronze with ribs, seen only once the plates part.
	_ellipsoid(s, Vector3(0.0, 10.2, -0.4), Vector3(7.2, 4.6, 4.0), 6, 12, CAVITY, MeshKit.PAT_GOLD, 0.25,
		-PI * 0.5, PI * 0.5, PI * 0.3, PI * 1.7, Basis.IDENTITY, true)
	for k: int in 5:
		var x: float = (float(k) - 2.0) * 2.0
		var back: float = -0.4 - 4.0 * sqrt(maxf(1.0 - pow(x / 7.2, 2.0), 0.0)) + 0.35
		_bar(s, Vector3(x, 6.4, back + 0.6), Vector3(x, 14.0, back + 0.6), 0.45, 0.35, BRONZE, Vector3.RIGHT,
			MeshKit.PAT_GOLD, 0.5)
	# The neck and the high collar, its rim flaring out behind the head.
	_tube(s, [Vector3(0.0, 13.6, -0.2), Vector3(0.0, 16.6, 0.0)] as Array[Vector3], 2.0, 1.75, 10, BRONZE,
		MeshKit.PAT_GOLD, 0.4)
	for i: int in 9:
		var a: float = lerpf(-PI * 0.78, PI * 0.78, float(i) / 8.0) + PI
		var base := Vector3(sin(a) * 3.0, 14.6, cos(a) * 2.6 - 0.4)
		var tip := Vector3(sin(a) * 4.6, 18.8 - absf(float(i) - 4.0) * 0.35, cos(a) * 3.9 - 0.8)
		_bar(s, base, tip, 1.4, 0.35, GOLD_PALE, Vector3(cos(a), 0.0, -sin(a)))
	# The pauldrons: huge domed plates over the shoulders, layered.
	for side: float in [-1.0, 1.0]:
		var tilt := Basis(Vector3.BACK, side * -0.32)
		_ellipsoid(s, Vector3(side * 10.4, 13.4, -0.2), Vector3(5.6, 3.9, 5.3), 5, 12, GOLD, MeshKit.PAT_GOLD, 0.75,
			-PI * 0.12, PI * 0.5, -PI, PI, tilt)
		_ellipsoid(s, Vector3(side * 12.3, 11.4, -0.1), Vector3(4.3, 2.6, 4.6), 4, 10, GOLD_PALE, MeshKit.PAT_GOLD, 0.7,
			-PI * 0.2, PI * 0.5, -PI, PI, Basis(Vector3.BACK, side * -0.55))
		# Gold filigree: a scrolling wave raised along the pauldron's rim.
		var wave: Array[Vector3] = []
		for k: int in 29:
			var a: float = lerpf(-PI * 0.78, PI * 0.78, float(k) / 28.0)
			wave.append(Vector3(side * 10.4, 13.4, -0.2) + tilt * Vector3(sin(a) * 5.62, 0.55 + 0.42 * sin(a * 9.0),
				cos(a) * 5.32))
		_tube(s, wave, 0.2, 0.2, 4, GOLD_PALE, MeshKit.PAT_GOLD, 0.9)
		# The cult's halo motif on the pauldron's crown: a ring.
		var ring: Array[Vector3] = []
		for k: int in 14:
			var a: float = TAU * float(k) / 14.0
			ring.append(Vector3(side * 10.6 + cos(a) * 1.7, 17.15, 0.5 + sin(a) * 1.7))
		_tube(s, ring, 0.22, 0.22, 4, GOLD_PALE, MeshKit.PAT_GOLD, 0.9, true)
	# The belt, gold and bronze, and the pelvis the pipes trail from (no legs).
	var belt: Array[Vector3] = []
	for k: int in 16:
		var a: float = TAU * float(k) / 16.0
		belt.append(Vector3(sin(a) * 5.4, 0.7, cos(a) * 3.9))
	_tube(s, belt, 0.75, 0.75, 6, BRONZE, MeshKit.PAT_GOLD, 0.45, true, GOLD_PALE, 2)
	_ellipsoid(s, Vector3(0.0, -0.4, 0.0), Vector3(4.8, 4.6, 3.4), 5, 12, GOLD, MeshKit.PAT_GOLD, 0.55,
		-PI * 0.5, 0.0)
	# Hanging plates over the pelvis (a skirt of gold, open below).
	for k: int in 7:
		var a: float = lerpf(-PI * 0.62, PI * 0.62, float(k) / 6.0)
		var top := Vector3(sin(a) * 5.3, 0.2, cos(a) * 3.9)
		var bottom := Vector3(sin(a) * 6.2, -4.6, cos(a) * 4.6)
		_bar(s, top, bottom, 1.7, 0.3, GOLD if k % 2 == 0 else GOLD_PALE, Vector3(cos(a), 0.0, -sin(a)))
	# Filigree on the abdomen: raised lines following its curve, in a lattice.
	for k: int in 5:
		var y: float = 1.8 + float(k) * 1.15
		var w: float = 3.8 - absf(float(k) - 2.0) * 0.4
		var steps: int = 6
		for q: int in steps:
			var x0: float = lerpf(-w, w, float(q) / steps)
			var x1: float = lerpf(-w, w, float(q + 1) / steps)
			_bar(s, Vector3(x0, y, front_z(ABDOMEN, ABDOMEN_RADII, x0, y, 0.05)),
				Vector3(x1, y, front_z(ABDOMEN, ABDOMEN_RADII, x1, y, 0.05)), 0.18, 0.18, GOLD_PALE, Vector3.UP)
	for q: int in 4:
		var y0: float = lerpf(1.2, 7.0, float(q) / 4.0)
		var y1: float = lerpf(1.2, 7.0, float(q + 1) / 4.0)
		_bar(s, Vector3(0.0, y0, front_z(ABDOMEN, ABDOMEN_RADII, 0.0, y0, 0.06)),
			Vector3(0.0, y1, front_z(ABDOMEN, ABDOMEN_RADII, 0.0, y1, 0.06)), 0.24, 0.24, GOLD_PALE, Vector3.RIGHT)
	return _mesh(batch)


## One of the chest's two front plates (`side` -1 the suit's right, as the runner sees it on the left;
## +1 its left): a curved plate with the Convergent Triad's half in gold relief, and filigree.
static func _plate(material: Material, side: int) -> ArrayMesh:
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(material)
	var lon0: float = 0.0 if side > 0 else -PI * 0.36
	var lon1: float = PI * 0.36 if side > 0 else 0.0
	_ellipsoid(s, CHEST, CHEST_RADII, 7, 6, GOLD, MeshKit.PAT_GOLD, 0.65, -PI * 0.42, PI * 0.42, lon0, lon1)
	# Its inside (seen once the burst swings it open), dark bronze.
	_ellipsoid(s, CHEST, CHEST_RADII * 0.985, 7, 6, CAVITY, MeshKit.PAT_GOLD, 0.3, -PI * 0.42, PI * 0.42, lon0, lon1,
		Basis.IDENTITY, true)
	# A raised rim down the plate's inner edge, and scrolls across it, on its curve.
	for q: int in 4:
		var y0: float = lerpf(6.4, 14.0, float(q) / 4.0)
		var y1: float = lerpf(6.4, 14.0, float(q + 1) / 4.0)
		_bar(s, Vector3(side * 0.18, y0, chest_z(0.18, y0, 0.12)), Vector3(side * 0.18, y1, chest_z(0.18, y1, 0.12)),
			0.36, 0.4, GOLD_PALE, Vector3.RIGHT)
	for k: int in 3:
		var y: float = 6.8 + float(k) * 2.4 + (1.2 if k > 0 else 0.0)
		for q: int in 3:
			var x0: float = lerpf(4.0, 6.4, float(q) / 3.0)
			var x1: float = lerpf(4.0, 6.4, float(q + 1) / 3.0)
			_bar(s, Vector3(side * x0, y, chest_z(x0, y, 0.08)), Vector3(side * x1, y + 0.3, chest_z(x1, y + 0.3, 0.08)),
				0.2, 0.2, GOLD_PALE, Vector3.UP)
	# Half of the Convergent Triad in relief, wrapped onto the chest, so the closed plates show it whole
	# (gold alone).
	var emblem: ArrayMesh = CultEmblem.build_mesh(GoldenSkin.cult_emblem_option(), 6.0, GOLD_PALE, GOLD_PALE, 0.0, material)
	var arrays: Array = emblem.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var at := Vector2(0.0, 10.4)
	for i: int in range(0, verts.size(), 3):
		var c: Vector3 = (verts[i] + verts[i + 1] + verts[i + 2]) / 3.0
		if c.x * side < 0.0:
			continue
		var tri := PackedVector3Array()
		for j: int in 3:
			var v: Vector3 = verts[i + j]
			tri.append(Vector3(at.x + v.x, at.y + v.y, chest_z(at.x + v.x, at.y + v.y, 0.14)))
		s.verts.append_array(tri)
		var col := Color(GOLD_PALE, 0.0)
		s.colors.append_array(PackedColorArray([col, col, col]))
		s.uvs.append_array(PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]))
		var p := Vector2(MeshKit.PAT_GOLD, 0.95)
		s.uv2s.append_array(PackedVector2Array([p, p, p]))
	return _mesh(batch)


## The face's relief at (x, y) on the head (FACE_REF's units from the face's middle, HEAD), toward the runner:
## brow, heavy half-closed lids, a straight nose, high cheekbones, closed lips with a faint smile, the chin.
static func face_relief(x: float, y: float) -> float:
	var ax: float = absf(x)
	var r: float = 0.0
	# The brow ridge over both eyes.
	r += 0.36 * exp(-pow((y - 1.12) / 0.34, 2.0)) * exp(-pow((ax - 0.95) / 0.85, 2.0))
	# The eye sockets, the heavy lids bulging softly in them, the eyes' openings a little sunk.
	r -= 0.42 * exp(-pow((y - 0.55) / 0.42, 2.0)) * exp(-pow((ax - 0.98) / 0.62, 2.0))
	r += 0.26 * exp(-pow((y - 0.6) / 0.24, 2.0)) * exp(-pow((ax - 0.98) / 0.44, 2.0))
	r -= 0.07 * _soft_inside(_eye_distance(ax, y), 0.02)
	# The nose: a straight ridge down the middle widening to a rounded tip.
	var nose_along: float = clampf((1.0 - y) / 2.1, 0.0, 1.0)
	var on_nose: float = smoothstep(1.05, 0.9, y) * smoothstep(-1.25, -0.95, y)
	r += on_nose * (0.3 + 0.55 * nose_along) * exp(-pow(x / (0.22 + 0.24 * nose_along), 2.0))
	r += 0.16 * exp(-pow((y + 1.0) / 0.2, 2.0)) * exp(-pow((ax - 0.32) / 0.18, 2.0))
	# Cheekbones, high and full.
	r += 0.24 * exp(-pow((y + 0.25) / 0.55, 2.0)) * exp(-pow((ax - 1.45) / 0.55, 2.0))
	# The lips: an upper and a lower, closed, the corners rising a little.
	var lips: float = exp(-pow(x / 0.8, 2.0))
	r += 0.2 * lips * exp(-pow((y + 1.62 - _smile(ax)) / 0.16, 2.0))
	r += 0.26 * lips * exp(-pow((y + 2.0 - _smile(ax)) / 0.2, 2.0))
	# The chin.
	r += 0.32 * exp(-pow((y + 2.75) / 0.42, 2.0)) * exp(-pow(x / 0.85, 2.0))
	return r


## How far the lips' corners rise at `ax` from the middle (the faint smile).
static func _smile(ax: float) -> float:
	return 0.1 * pow(minf(ax, 0.9) / 0.8, 2.0)


## Signed distance (FACE_REF's units, negative inside) to the half-closed eye's opening at (|x|, y): an almond
## under the heavy upper lid, from 0.54 to 1.46 out from the middle.
static func _eye_distance(ax: float, y: float) -> float:
	var t: float = (ax - 1.0) / 0.46
	var k: float = maxf(1.0 - t * t, 0.0)
	var top: float = 0.52 + 0.08 * k
	var bottom: float = 0.52 - 0.11 * k
	var inside_y: float = maxf(y - top, bottom - y)
	var inside_x: float = (absf(t) - 1.0) * 0.46
	return maxf(inside_y, inside_x)


## 1 inside a shape (signed distance `d`), 0 outside, over a soft edge `soft` wide.
static func _soft_inside(d: float, soft: float) -> float:
	return 1.0 - smoothstep(-soft, soft, d)


## The face's marks at (x, y) (FACE_REF's units from the face's middle), each 0-1 with a soft edge, wider
## than the face's grid so every one shows from the far end of the court: x the creases (the upper lids'
## line, the lips' line, the nostrils), y the eyes' openings, z the tear (from under the suit's left eye, the
## runner's right, a thin streak down its cheek ending in a drop).
static func face_marks(x: float, y: float) -> Vector3:
	var ax: float = absf(x)
	var crease: float = 0.0
	# The upper lids' line, over the openings and a little past their outer corners.
	var t: float = (ax - 1.0) / 0.46
	if absf(t) < 1.25:
		var lid: float = 0.52 + 0.08 * maxf(1.0 - t * t, 0.0) - 0.04 * maxf(absf(t) - 1.0, 0.0)
		crease = maxf(crease, (1.0 - smoothstep(0.03, 0.11, absf(y - lid))) * (1.0 - smoothstep(1.05, 1.25, absf(t))))
	# The lips' line, fading at the corners.
	if ax < 0.95:
		var line: float = -1.8 + _smile(ax)
		crease = maxf(crease, (1.0 - smoothstep(0.03, 0.1, absf(y - line))) * (1.0 - smoothstep(0.7, 0.92, ax)))
	# The nostrils.
	var nostril: float = sqrt(pow((ax - 0.29) / 0.12, 2.0) + pow((y + 1.08) / 0.07, 2.0))
	crease = maxf(crease, 1.0 - smoothstep(0.7, 1.5, nostril))
	var eye: float = _soft_inside(_eye_distance(ax, y), 0.05)
	# The tear: the streak from the lower lid down the cheek, then the drop.
	var tear: float = 0.0
	if x > 0.6 and y < 0.5 and y > -1.4:
		var k: float = clampf((0.42 - y) / 1.3, 0.0, 1.0)
		var cx: float = 1.06 + 0.12 * k
		var half: float = lerpf(0.05, 0.08, k)
		var streak: float = (1.0 - smoothstep(half, half + 0.06, absf(x - cx))) * smoothstep(0.48, 0.4, y)
		var drop: float = 1.0 - smoothstep(0.17, 0.24, Vector2((x - 1.19) / 0.85, y + 0.98).length())
		tear = maxf(streak * smoothstep(-0.95, -0.85, y), drop)
	return Vector3(clampf(crease, 0.0, 1.0), eye, clampf(tear, 0.0, 1.0))


## The face's colour at (x, y) (FACE_REF's units), its polish in alpha: the pale gold, the eyes' openings a
## duller gold, the creases bronze, the tear a dull red (never glowing: a lit, unpolished surface, darker than
## the gold around it), and the relief's hollows shaded (a sculptor's patina, so the face reads whatever the
## gold's reflections do).
static func face_color(x: float, y: float) -> Color:
	var m: Vector3 = face_marks(x, y)
	var col: Color = GOLD_PALE.lerp(EYE, m.y * 0.85)
	col = col.lerp(CREASE, m.x)
	col = col.lerp(TEAR, m.z)
	var polish: float = lerpf(lerpf(0.55, 0.3, maxf(m.x, m.y)), 0.04, m.z)
	# The relief's curvature: hollows darker, ridges a touch brighter.
	var h: float = 0.1
	var r0: float = face_relief(x, y)
	var lap: float = (face_relief(x + h, y) + face_relief(x - h, y) + face_relief(x, y + h) + face_relief(x, y - h)
		- 4.0 * r0) / (h * h)
	var shade: float = clampf(1.0 - 0.07 * maxf(lap, 0.0) + 0.03 * maxf(-lap, 0.0), 0.62, 1.06)
	col = Color(col.r * shade, col.g * shade, col.b * shade)
	return Color(clampf(col.r, 0.0, 1.0), clampf(col.g, 0.0, 1.0), clampf(col.b, 0.0, 1.0), polish)


static func _head(material: Material) -> ArrayMesh:
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(material)
	var c: Vector3 = HEAD
	var rad: Vector3 = HEAD_RADII
	var to_ref := Vector2(FACE_REF.x / rad.x, FACE_REF.y / rad.y)
	var depth: float = RELIEF * rad.z / FACE_REF.z
	# The face: a fine grid on the head's front, displaced by the relief, coloured per corner (face_color: the
	# marks blend smoothly across the grid instead of stepping from triangle to triangle).
	var rows: int = 60
	var cols: int = 44
	var lat0: float = -PI * 0.42
	var lat1: float = PI * 0.4
	var lon_half: float = PI * 0.43
	var grid: Array[PackedVector3Array] = []
	var colors: Array[PackedColorArray] = []
	for r: int in rows + 1:
		var lat: float = lerpf(lat0, lat1, float(r) / rows)
		var row := PackedVector3Array()
		var row_colors := PackedColorArray()
		for q: int in cols + 1:
			var lon: float = lerpf(-lon_half, lon_half, float(q) / cols)
			var p: Vector3 = _dir(lat, lon) * rad
			var fade: float = smoothstep(lon_half, lon_half * 0.7, absf(lon)) * smoothstep(lat0, lat0 + 0.25, lat) \
				* smoothstep(lat1, lat1 - 0.2, lat)
			var fx: float = p.x * to_ref.x
			var fy: float = p.y * to_ref.y
			p.z += face_relief(fx, fy) * fade * depth
			row.append(c + p)
			var col: Color = face_color(fx, fy) if fade > 0.0 else Color(GOLD_PALE, 0.55)
			row_colors.append(Color(GOLD_PALE, 0.55).lerp(col, fade))
		grid.append(row)
		colors.append(row_colors)
	for r: int in rows:
		for q: int in cols:
			var p00: Vector3 = grid[r][q]
			var p01: Vector3 = grid[r][q + 1]
			var p11: Vector3 = grid[r + 1][q + 1]
			var p10: Vector3 = grid[r + 1][q]
			var c00: Color = colors[r][q]
			var c01: Color = colors[r][q + 1]
			var c11: Color = colors[r + 1][q + 1]
			var c10: Color = colors[r + 1][q]
			_tri_shaded(s, [p00, p01, p11], [c00, c01, c11], (p00 + p01 + p11) / 3.0 - c)
			_tri_shaded(s, [p00, p11, p10], [c00, c11, c10], (p00 + p11 + p10) / 3.0 - c)
	# The head's sides and back, and the top over the face's edge.
	_ellipsoid(s, c, rad * 0.995, 8, 10, GOLD, MeshKit.PAT_GOLD, 0.6, -PI * 0.5, PI * 0.5, lon_half, TAU - lon_half)
	_ellipsoid(s, c, rad * 0.995, 2, 8, GOLD, MeshKit.PAT_GOLD, 0.6, lat1, PI * 0.5, -lon_half, lon_half)
	_ellipsoid(s, c, rad * 0.995, 2, 8, GOLD, MeshKit.PAT_GOLD, 0.6, -PI * 0.5, lat0, -lon_half, lon_half)
	# A diadem round the brow, its three points rising over the forehead like the Triad's arrows meeting.
	var band_y: float = 2.35
	var band: Array[Vector3] = []
	for k: int in 24:
		var a: float = TAU * float(k) / 24.0
		var r: Vector2 = Vector2(rad.x, rad.z) * sqrt(maxf(1.0 - pow(band_y / rad.y, 2.0), 0.0)) + Vector2(0.28, 0.28)
		band.append(c + Vector3(sin(a) * r.x, band_y, cos(a) * r.y))
	_tube(s, band, 0.32, 0.32, 5, GOLD_PALE, MeshKit.PAT_GOLD, 0.85, true)
	for k: int in 3:
		var a: float = (float(k) - 1.0) * 0.42
		var r: Vector2 = Vector2(rad.x, rad.z) * sqrt(maxf(1.0 - pow(band_y / rad.y, 2.0), 0.0)) + Vector2(0.35, 0.35)
		var base := c + Vector3(sin(a) * r.x, band_y, cos(a) * r.y)
		var h: float = 1.5 if k == 1 else 1.05
		var out := Vector3(sin(a), 0.0, cos(a))
		var across: Vector3 = Vector3.UP.cross(out).normalized()
		_tri(s, base - across * 0.5, base + across * 0.5, base + Vector3(0.0, h, 0.0) - out * 0.35, out, GOLD_PALE,
			MeshKit.PAT_GOLD, 0.9)
		_tri(s, base - across * 0.5, base + across * 0.5, base + Vector3(0.0, h, 0.0) - out * 0.35, -out, GOLD,
			MeshKit.PAT_GOLD, 0.9)
	return _mesh(batch)


## The halo: two rings joined by rays (the Resonator's halos, huge), behind the head, upright.
static func _halo(material: Material) -> ArrayMesh:
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(material)
	for ring: Vector2 in [Vector2(6.4, 0.34), Vector2(8.1, 0.26)]:
		var pts: Array[Vector3] = []
		for k: int in 28:
			var a: float = TAU * float(k) / 28.0
			pts.append(Vector3(cos(a) * ring.x, sin(a) * ring.x, 0.0))
		_tube(s, pts, ring.y, ring.y, 5, GOLD_PALE, MeshKit.PAT_GOLD, 0.92, true)
	# Rays from the inner ring to the outer, every fourth (three of them, as the Triad's arrows) reaching past it.
	for k: int in 12:
		var a: float = TAU * float(k) / 12.0
		var dir := Vector3(cos(a), sin(a), 0.0)
		_bar(s, dir * 6.6, dir * (7.9 if k % 4 != 0 else 9.6), 0.3, 0.16, GOLD, Vector3(0, 0, 1))
	return _mesh(batch)


static func _upper_arm(material: Material) -> ArrayMesh:
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(material)
	# Along -y from the shoulder joint: a muscled sleeve of plates.
	_ellipsoid(s, Vector3(0.0, -UPPER_ARM * 0.48, 0.0), Vector3(2.3, UPPER_ARM * 0.56, 2.2), 6, 10, GOLD,
		MeshKit.PAT_GOLD, 0.6)
	for k: int in 3:
		var y: float = -1.6 - float(k) * 2.0
		var ring: Array[Vector3] = []
		for q: int in 12:
			var a: float = TAU * float(q) / 12.0
			ring.append(Vector3(cos(a) * 2.28, y, sin(a) * 2.18))
		_tube(s, ring, 0.2, 0.2, 4, GOLD_PALE, MeshKit.PAT_GOLD, 0.9, true)
	# The elbow's joint.
	_ellipsoid(s, Vector3(0.0, -UPPER_ARM, 0.0), Vector3(1.9, 1.9, 1.9), 4, 8, BRONZE, MeshKit.PAT_GOLD, 0.45)
	return _mesh(batch)


static func _forearm(material: Material) -> ArrayMesh:
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(material)
	# A gauntlet along -y from the elbow, flaring toward the wrist, open at its end (the segments slide out).
	_tube(s, [Vector3.ZERO, Vector3(0.0, -FOREARM * 0.5, 0.0), Vector3(0.0, -FOREARM, 0.0)] as Array[Vector3],
		1.85, 2.15, 10, GOLD, MeshKit.PAT_GOLD, 0.62, false, GOLD_PALE, 0, false)
	var cuff: Array[Vector3] = []
	for q: int in 12:
		var a: float = TAU * float(q) / 12.0
		cuff.append(Vector3(cos(a) * 2.3, -FOREARM + 0.3, sin(a) * 2.3))
	_tube(s, cuff, 0.34, 0.34, 4, GOLD_PALE, MeshKit.PAT_GOLD, 0.9, true)
	# Filigree down its outside.
	_bar(s, Vector3(2.0, -1.0, 0.0), Vector3(2.2, -FOREARM + 0.8, 0.0), 0.2, 0.2, GOLD_PALE, Vector3(0, 0, 1))
	return _mesh(batch)


## One telescoping segment (E5d-b): a golden sleeve along -y, ringed at its end.
static func _segment(material: Material) -> ArrayMesh:
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(material)
	_tube(s, [Vector3.ZERO, Vector3(0.0, -SEGMENT, 0.0)] as Array[Vector3], 1.6, 1.6, 10, GOLD, MeshKit.PAT_GOLD, 0.7,
		false, GOLD, 0, false)
	var rim: Array[Vector3] = []
	for q: int in 12:
		var a: float = TAU * float(q) / 12.0
		rim.append(Vector3(cos(a) * 1.72, -SEGMENT + 0.25, sin(a) * 1.72))
	_tube(s, rim, 0.24, 0.24, 4, GOLD_PALE, MeshKit.PAT_GOLD, 0.9, true)
	return _mesh(batch)


## A hand, open (palm toward the body, fingers down) or a fist, along -y from the wrist.
static func _hand(material: Material, fist: bool) -> ArrayMesh:
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(material)
	if fist:
		_ellipsoid(s, Vector3(0.0, -2.0, 0.2), Vector3(2.5, 2.4, 2.2), 5, 10, GOLD, MeshKit.PAT_GOLD, 0.7)
		for k: int in 4:
			var x: float = -1.5 + float(k) * 1.0
			_ellipsoid(s, Vector3(x, -3.6, 1.1), Vector3(0.62, 0.55, 0.62), 3, 6, GOLD_PALE, MeshKit.PAT_GOLD, 0.85)
		_bar(s, Vector3(2.0, -1.0, 1.0), Vector3(1.0, -2.8, 2.2), 1.0, 0.9, GOLD, Vector3(0, 0, 1))
		return _mesh(batch)
	_box(s, Transform3D(Basis.from_scale(Vector3(3.6, 2.6, 1.3)), Vector3(0.0, -1.6, 0.0)), GOLD, MeshKit.PAT_GOLD, 0.65)
	for k: int in 4:
		var x: float = -1.35 + float(k) * 0.9
		var length: float = 2.0 if k == 0 or k == 3 else 2.5
		var bend := Basis(Vector3.RIGHT, 0.25)
		_bar(s, Vector3(x, -2.8, 0.0), Vector3(x, -2.8, 0.0) + bend * Vector3(0.0, -length, 0.0), 0.78, 0.72, GOLD,
			Vector3.RIGHT)
		_ellipsoid(s, Vector3(x, -2.85, 0.15), Vector3(0.46, 0.4, 0.5), 2, 5, GOLD_PALE, MeshKit.PAT_GOLD, 0.9)
	_bar(s, Vector3(1.9, -1.0, 0.4), Vector3(2.4, -3.2, 1.4), 0.8, 0.75, GOLD, Vector3(0, 0, 1))
	return _mesh(batch)


## A shoulder's missile pipes (E5d-b's barrage), standing up and back from the pauldron, mouths dark.
static func _pipes(material: Material) -> ArrayMesh:
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(material)
	for k: int in PIPE_COUNT:
		var off: Vector3 = pipe_offset(k)
		var base: Vector3 = off
		var tip: Vector3 = off + pipe_axis() * PIPE_LENGTH
		_tube(s, [base, base.lerp(tip, 0.3), base.lerp(tip, 0.5), base.lerp(tip, 0.8), tip] as Array[Vector3], PIPE_RADIUS,
			PIPE_RADIUS * 0.92, 8, GOLD_PALE, MeshKit.PAT_GOLD, 0.8, false, BRONZE, 2, false)
		# A flared bronze lip round each mouth.
		_tube(s, [tip - pipe_axis() * 0.45, tip] as Array[Vector3], PIPE_RADIUS * 1.08, PIPE_RADIUS * 1.22, 8, BRONZE,
			MeshKit.PAT_GOLD, 0.6, false, Color(), 0, false)
		# The dark bore inside each mouth.
		var ring: Array[Vector3] = []
		for q: int in 8:
			var a: float = TAU * float(q) / 8.0
			ring.append(tip + _ring_dir(a) * PIPE_RADIUS * 0.7)
		for q: int in 8:
			_tri(s, tip - pipe_axis() * 0.1, ring[q], ring[(q + 1) % 8], pipe_axis(), BORE, MeshKit.PAT_PLAIN, 0.0)
	# The mount on the pauldron, and a band holding the row together.
	var row: float = PIPE_SPACING * (PIPE_COUNT - 1) + PIPE_RADIUS * 2.0 + 0.5
	_box(s, Transform3D(Basis.from_scale(Vector3(row, 0.9, 2.0)), Vector3(0.0, -0.2, 0.0)), BRONZE, MeshKit.PAT_GOLD, 0.45)
	var band_at: Vector3 = pipe_axis() * PIPE_LENGTH * 0.42
	var across_z: Vector3 = Vector3.RIGHT.cross(pipe_axis()).normalized()
	_box(s, Transform3D(Basis(Vector3.RIGHT * row, pipe_axis() * 0.7, across_z * (PIPE_RADIUS * 2.0 + 0.3)), band_at), GOLD,
		MeshKit.PAT_GOLD, 0.7)
	return _mesh(batch)


## The hatch over a cluster's mouths (GoldenConvergenceSuit swings it open about its back edge), in the
## hinge's space (hatch_hinge: local y along the pipes, local z toward their back): a thin slab reaching
## forward from the hinge over the row of mouths, a raised rim along its front edge.
static func _pipe_cap(material: Material) -> ArrayMesh:
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(material)
	var reach: float = PIPE_RADIUS * 2.0 + 0.7
	var row: float = PIPE_SPACING * (PIPE_COUNT - 1) + PIPE_RADIUS * 2.0 + 0.6
	_box(s, Transform3D(Basis.from_scale(Vector3(row, 0.26, reach)), Vector3(0.0, 0.13, -reach * 0.5)), GOLD_PALE,
		MeshKit.PAT_GOLD, 0.85)
	_box(s, Transform3D(Basis.from_scale(Vector3(row, 0.22, 0.3)), Vector3(0.0, 0.34, -reach + 0.15)), BRONZE,
		MeshKit.PAT_GOLD, 0.6)
	return _mesh(batch)


## The hatch's hinge in a cluster's space: at the back edge of the mouths, local y along the pipes, local z
## toward their back.
static func hatch_hinge() -> Transform3D:
	var axis: Vector3 = pipe_axis()
	var back: Vector3 = (Vector3.FORWARD - axis * Vector3.FORWARD.dot(axis)).normalized()
	var mouths: Vector3 = axis * PIPE_LENGTH
	return Transform3D(Basis(axis.cross(back).normalized(), axis, back), mouths + back * (PIPE_RADIUS + 0.35))


## The cluster blown out (E5d-c): torn stubs, bent and blackened, the mount cracked.
static func _pipes_torn(material: Material) -> ArrayMesh:
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(material)
	for k: int in PIPE_COUNT:
		var off: Vector3 = pipe_offset(k)
		var bend: Vector3 = pipe_axis().rotated(Vector3.FORWARD, 0.5 * (1.0 if k % 2 == 0 else -1.0))
		var tip: Vector3 = off + bend * PIPE_LENGTH * (0.35 + 0.1 * k)
		_tube(s, [off, tip] as Array[Vector3], PIPE_RADIUS, PIPE_RADIUS * 1.15, 6, BRONZE.darkened(0.45),
			MeshKit.PAT_PLAIN, 0.0, false, Color(), 0, true)
	var row: float = PIPE_SPACING * (PIPE_COUNT - 1) + PIPE_RADIUS * 2.0 + 0.5
	_box(s, Transform3D(Basis(Vector3.BACK, 0.2) * Basis.from_scale(Vector3(row, 0.9, 2.0)), Vector3(0.0, -0.3, 0.0)),
		BORE.lightened(0.08), MeshKit.PAT_PLAIN, 0.0)
	return _mesh(batch)


## Pipe `k`'s base in its cluster's space, and the way the pipes point.
static func pipe_offset(k: int) -> Vector3:
	return Vector3((float(k) - (PIPE_COUNT - 1) * 0.5) * PIPE_SPACING, 0.0, 0.0)


static func pipe_axis() -> Vector3:
	return Vector3(0.0, 0.8, -0.6).normalized()


static func _ring_dir(a: float) -> Vector3:
	var axis: Vector3 = pipe_axis()
	var side: Vector3 = axis.cross(Vector3.RIGHT).normalized()
	var up: Vector3 = axis.cross(side).normalized()
	return side * cos(a) + up * sin(a)


## The pipes that trail from the pelvis (no legs): metallic tentacles, ridged, each in its own slow S-curve,
## trailing back far out of view.
static func _tentacles(material: Material) -> ArrayMesh:
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(material)
	# Eight pipes from a ring under the pelvis: the middle ones trail back high over the causeway, the outer
	# ones splay out past its edges and down toward the pools, each in its own slow S-curve, thinning out.
	var count: int = 8
	for k: int in count:
		var f: float = lerpf(-1.0, 1.0, float(k) / float(count - 1))
		var wide: float = absf(f)
		var a: float = f * PI * 0.7
		var root := Vector3(sin(a) * 3.2, -3.6, cos(a) * 2.0 - 0.8)
		var phase: float = float(k) * 1.9
		var controls: Array[Vector3] = [
			root,
			root + Vector3(f * 2.4, -3.2, -0.6),
			Vector3(f * (5.0 + 7.0 * wide), -7.0 - 2.0 * wide, -3.0 + 2.5 * sin(phase)),
			Vector3(f * (8.0 + 13.0 * wide) + 2.6 * sin(phase), -6.5 - 9.0 * wide, -13.0),
			Vector3(f * (10.0 + 20.0 * wide) - 2.8 * cos(phase), -7.5 - 19.0 * wide, -28.0),
			Vector3(f * (11.0 + 25.0 * wide) + 2.0 * sin(phase * 1.3), -9.0 - 30.0 * wide, -46.0),
			Vector3(f * (12.0 + 28.0 * wide), -10.0 - 38.0 * wide, -70.0),
		]
		var pts: Array[Vector3] = _curve(controls, 5)
		var thick: float = 1.15 - 0.25 * wide
		_tube(s, pts, thick, 0.38, 7, GOLD, MeshKit.PAT_GOLD, 0.55, false, BRONZE, 3, true)
	return _mesh(batch)


## The cape's cloud: two sheets of a grid from the shoulders' back (v = 0) billowing down and out to its hem
## (v = 1), and around the sides (u from 0 to 1, left to right as the runner sees it). VERTEX is its full
## cloud at rest; the shader billows it, darkens its folds and gathers it up for the entrance (unfurl).
static func _cape(low: bool) -> ArrayMesh:
	var cols: int = 36 if low else 64
	var rows: int = 12 if low else 22
	var mesh := ArrayMesh.new()
	for sheet: int in 2:
		var verts := PackedVector3Array()
		var uvs := PackedVector2Array()
		var uv2s := PackedVector2Array()
		var colors := PackedColorArray()
		var grid: Array[PackedVector3Array] = []
		for r: int in rows + 1:
			var v: float = float(r) / rows
			var row := PackedVector3Array()
			for q: int in cols + 1:
				var u: float = float(q) / cols
				row.append(_cape_point(u, v, sheet))
			grid.append(row)
		for r: int in rows:
			for q: int in cols:
				var a: Vector3 = grid[r][q]
				var b: Vector3 = grid[r][q + 1]
				var c: Vector3 = grid[r + 1][q + 1]
				var d: Vector3 = grid[r + 1][q]
				var ua := Vector2(float(q) / cols, float(r) / rows)
				var ub := Vector2(float(q + 1) / cols, float(r) / rows)
				var uc := Vector2(float(q + 1) / cols, float(r + 1) / rows)
				var ud := Vector2(float(q) / cols, float(r + 1) / rows)
				verts.append_array(PackedVector3Array([a, b, c, a, c, d]))
				uvs.append_array(PackedVector2Array([ua, ub, uc, ua, uc, ud]))
				var p := Vector2(float(sheet), 0.0)
				uv2s.append_array(PackedVector2Array([p, p, p, p, p, p]))
				colors.append_array(PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE,
					Color.WHITE]))
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_TEX_UV2] = uv2s
		arrays[Mesh.ARRAY_COLOR] = colors
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## A point of the cape's cloud at rest (u across, v from the shoulders out to its hem) on `sheet` (0 the
## cape, 1 the billow further out behind it): from the shoulders' back it fans out behind the suit, up over its
## head and the halo and down past its sides, streaming back, its hem rolling in lobes like a cloud's edge (it
## doesn't have to follow physics: GDD §10). The shader adds the pleats radiating from the shoulders, their
## black troughs, and the billowing.
static func _cape_point(u: float, v: float, sheet: int) -> Vector3:
	var a: float = lerpf(-1.0, 1.0, u)
	var sh: float = float(sheet)
	var ang: float = a * (2.3 + 0.18 * sh)
	var reach: float = (28.0 + 7.0 * sh) * (1.0 + 0.12 * cos(a * 6.5 + sh * 2.1) + 0.06 * cos(a * 13.0 + 1.0))
	var r: float = reach * pow(v, 0.85)
	var x: float = a * CAPE_ANCHOR_HALF * (1.0 - 0.35 * v) + sin(ang) * r * 1.08
	var y: float = CAPE_ANCHOR_Y + cos(ang) * r * 0.78
	var z: float = CAPE_ANCHOR_Z - 1.5 - (9.0 + 4.0 * sh) * v - 7.0 * v * v - 5.0 * sh * v
	# The hem's lobes curl forward a little round the suit, a cloud framing it.
	z += 6.0 * pow(v, 3.0) * (0.5 + 0.5 * cos(a * 6.5 + sh * 2.1))
	return Vector3(x, y, z)

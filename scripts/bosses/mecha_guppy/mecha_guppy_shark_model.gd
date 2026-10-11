class_name MechaGuppySharkModel
extends RefCounted
## Mecha Guppy's meshes (GDD §10: "a giant mechanical shark ... gigantic, the size of a building ... the player will
## mostly only ever see its giant jaws and its eyes"; "It doesn't glow red ... Its eyes are dark red lenses that don't
## glow"; task E5e-b2), built once in code per skin and shared, low-poly and flat-shaded through the mesh kit (the
## skin's solid material, so it is lit like the climb around it and reads the same on every renderer).
## Its local space is the head's: the origin at the jaws' hinge, the middle of the back of the mouth; +y along the
## snout (up as it rises out of the chasm, the way it is always shown); +z the side of its chin and pale belly (it
## faces the runner); x across, its eyes at +-x. The head splits down the middle into two jaws hinged at the origin,
## each its own mesh so MechaGuppyShark can open them:
## - upper_jaw: the back of the head and the snout (z < 0): riveted steel plates in two greys, a raised spine, the
##   eyes (dark red glass lenses in steel bezels, a glint on each, nothing glowing), and inside it the palate (dark
##   steel ribbed across) with a row of steel teeth down each side and a few at the tip, pointing at the other jaw;
## - lower_jaw: the chin (z > 0), the pale belly plating, the mouth's floor (dark ribbed steel) and its teeth;
## - body: below the hinge, the throat's floor between the jaws (a dark gullet ringed by grinding teeth), the gill
##   slits, the long body down into the chasm (darker the deeper), its pectoral fins and the dorsal fin.
## Sizes are metres at scale 1 (MechaGuppyShark scales it up: it is "the size of a building"). Nothing on it glows:
## it has no weak point, and only hazards glow in hazard colours (CLAUDE.md readability rules).
## DESIGN-TBD (docs/questions/e5e.md): the shark's look.

## The jaws: their length along +y, their half width and half depth at the hinge and at the tip.
const JAW_LENGTH: float = 8.0
const HALF_WIDTH: float = 4.2
const HALF_DEPTH: float = 3.2
const TIP_WIDTH: float = 0.85
const TIP_DEPTH: float = 0.7
## The tip's cap reaches this far past the jaws' length.
const TIP_CAP: float = 0.35
## How far each jaw opens (degrees): the snout tips back a little, the chin drops wide toward the runner, so the open
## maw faces them and up.
const UPPER_OPEN: float = 14.0
const LOWER_OPEN: float = 48.0
## The body below the hinge: how far it reaches down.
const BODY_LENGTH: float = 40.0
## Teeth along each side of a jaw, their height at the hinge (shorter toward the tip), and their base.
const TEETH_PER_SIDE: int = 11
const TOOTH_HEIGHT: float = 0.8
const TOOTH_BASE := Vector2(0.24, 0.3)
## The eyes: where on the snout (share of the jaw's length), how far round toward its back (radians from +-x), the
## bezel's and the lens's radius, how far the lens bulges.
const EYE_AT: float = 0.2
const EYE_ROUND: float = 0.55
const EYE_BEZEL: float = 0.8
const EYE_LENS: float = 0.58
const EYE_BULGE: float = 0.16
const EYE_IRIS: float = 0.2
## Segments round half a jaw, and round the body.
const JAW_SIDES: int = 6
const BODY_SIDES: int = 12

## Colours (sRGB, never glowing): two plate greys, the pale belly, seams, teeth, the mouth's dark steel, the eyes.
const PLATE := Color(0.33, 0.37, 0.43)
const PLATE_DARK := Color(0.26, 0.29, 0.35)
const BELLY := Color(0.55, 0.57, 0.6)
const BELLY_DARK := Color(0.46, 0.48, 0.52)
const SEAM := Color(0.11, 0.12, 0.14)
const TOOTH := Color(0.86, 0.87, 0.88)
const MOUTH := Color(0.075, 0.07, 0.075)
const MOUTH_RIB := Color(0.17, 0.165, 0.18)
const GULLET := Color(0.025, 0.022, 0.025)
const BEZEL := Color(0.19, 0.2, 0.22)
## The lenses: a dark red that never glows (the owner), behind dark glass.
const LENS := Color(0.32, 0.035, 0.035)
const PUPIL := Color(0.06, 0.012, 0.012)
const GLINT := Color(0.7, 0.66, 0.66)
const GILL := Color(0.05, 0.05, 0.06)
## The body darkens toward this the deeper it reaches (as the towers' storeys do, MechaGuppyLooks.deep).
const DEEP := Color(0.04, 0.045, 0.07)

static var _cache: Dictionary = {}


## The meshes in `skin`'s solid material: {upper_jaw, lower_jaw, body}. Cached per skin.
static func meshes(skin: BeachSkin) -> Dictionary:
	var key: int = skin.get_instance_id()
	if _cache.has(key):
		return _cache[key]
	var material: Material = skin.solid_material()
	var out: Dictionary = {}
	for part: String in ["upper_jaw", "lower_jaw", "body"]:
		var batch := MeshBatch.new()
		var s: MeshLayer = batch.layer(material)
		match part:
			"upper_jaw":
				_jaw(s, -1.0)
			"lower_jaw":
				_jaw(s, 1.0)
			_:
				_body(s)
		out[part] = batch.to_mesh()
	_cache[key] = out
	return out


## The jaws' half width and half depth at share `u` of their length (0 at the hinge, 1 at the tip): a shark's snout,
## broad at the back and tapering faster toward its point.
static func jaw_size(u: float) -> Vector2:
	var k: float = pow(clampf(u, 0.0, 1.0), 1.5)
	return Vector2(lerpf(HALF_WIDTH, TIP_WIDTH, k), lerpf(HALF_DEPTH, TIP_DEPTH, pow(clampf(u, 0.0, 1.0), 1.35)))


## A point on the head's outline at height `y` (on the jaws' length) and angle `a` round +y (0 at +x, PI/2 at +z).
static func _rim(size: Vector2, y: float, a: float) -> Vector3:
	return Vector3(size.x * cos(a), y, size.y * sin(a))


## One jaw: `side` -1 the upper (z < 0: the back and the snout), +1 the lower (z > 0: the chin).
static func _jaw(s: MeshLayer, side: float) -> void:
	var rings: Array[float] = [0.0, 0.14, 0.28, 0.42, 0.56, 0.7, 0.82, 0.92, 1.0]
	var a0: float = PI if side < 0.0 else 0.0
	# The shell: plates between the rings, alternating greys (pale on the belly side), a dark seam at each ring.
	for i: int in rings.size() - 1:
		var u0: float = rings[i]
		var u1: float = rings[i + 1]
		var y0: float = u0 * JAW_LENGTH
		var y1: float = u1 * JAW_LENGTH
		var w0: Vector2 = jaw_size(u0)
		var w1: Vector2 = jaw_size(u1)
		for j: int in JAW_SIDES:
			var a: float = a0 + PI * float(j) / float(JAW_SIDES)
			var b: float = a0 + PI * float(j + 1) / float(JAW_SIDES)
			var tone: Color
			if side > 0.0:
				tone = BELLY if (i + j) % 2 == 0 else BELLY_DARK
			else:
				tone = PLATE if (i + j) % 2 == 0 else PLATE_DARK
			var outward := Vector3(cos((a + b) * 0.5), 0.0, sin((a + b) * 0.5))
			_face(s, _rim(w0, y0, a), _rim(w0, y0, b), _rim(w1, y1, b), _rim(w1, y1, a), outward, tone)
		# A seam ring just proud of the shell.
		if i > 0:
			for j: int in JAW_SIDES:
				var a: float = a0 + PI * float(j) / float(JAW_SIDES)
				var b: float = a0 + PI * float(j + 1) / float(JAW_SIDES)
				var wa: Vector2 = jaw_size(u0) * 1.012
				var outward := Vector3(cos((a + b) * 0.5), 0.0, sin((a + b) * 0.5))
				_face(s, _rim(wa, y0 - 0.06, a), _rim(wa, y0 - 0.06, b), _rim(wa, y0 + 0.06, b), _rim(wa, y0 + 0.06, a), outward,
					SEAM)
	# The tip's cap.
	var wt: Vector2 = jaw_size(1.0)
	var tip := Vector3(0.0, JAW_LENGTH + TIP_CAP, side * wt.y * 0.35)
	for j: int in JAW_SIDES:
		var a: float = a0 + PI * float(j) / float(JAW_SIDES)
		var b: float = a0 + PI * float(j + 1) / float(JAW_SIDES)
		_face(s, _rim(wt, JAW_LENGTH, a), _rim(wt, JAW_LENGTH, b), tip, tip, Vector3(cos(a), 1.0, sin(a)),
			PLATE_DARK if side < 0.0 else BELLY_DARK)
	# The inside: the palate or the mouth's floor at the split, a little in from it, dark steel ribbed across.
	var inner_z: float = -side * 0.04
	for i: int in rings.size() - 1:
		var y0: float = rings[i] * JAW_LENGTH
		var y1: float = rings[i + 1] * JAW_LENGTH
		var r0: float = jaw_size(rings[i]).x - 0.04
		var r1: float = jaw_size(rings[i + 1]).x - 0.04
		_face(s, Vector3(-r0, y0, inner_z), Vector3(r0, y0, inner_z), Vector3(r1, y1, inner_z), Vector3(-r1, y1, inner_z),
			Vector3(0.0, 0.0, -side), MOUTH)
		if i > 0 and i < rings.size() - 2:
			var rib := Vector3(r0 * 1.6, 0.16, 0.08)
			s.box(Vector3(0.0, y0, inner_z - side * 0.04), rib, MOUTH_RIB, 0.0, MeshKit.PAT_PLAIN)
	# The teeth down each side of the split, pointing at the other jaw, smaller toward the tip; a few across the tip.
	for k: int in TEETH_PER_SIDE:
		var u: float = lerpf(0.07, 0.93, float(k) / float(TEETH_PER_SIDE - 1))
		var y: float = u * JAW_LENGTH
		var r: float = jaw_size(u).x - 0.26
		var h: float = TOOTH_HEIGHT * (1.0 - 0.45 * u)
		for sx: float in [-1.0, 1.0]:
			_tooth(s, Vector3(sx * r, y, inner_z), -side, h, TOOTH_BASE * (1.0 - 0.3 * u))
	for k: int in 3:
		var x: float = (float(k) - 1.0) * TIP_WIDTH * 0.55
		_tooth(s, Vector3(x, JAW_LENGTH - 0.25, inner_z), -side, TOOTH_HEIGHT * 0.45, TOOTH_BASE * 0.6)
	if side < 0.0:
		_spine(s)
		for sx: float in [-1.0, 1.0]:
			_eye(s, sx)


## A tooth: a four-sided steel point from a base at `at` (on the split's plane), toward `dir` (+-1 along z).
static func _tooth(s: MeshLayer, at: Vector3, dir: float, height: float, base: Vector2) -> void:
	var tip: Vector3 = at + Vector3(0.0, 0.0, dir * height)
	var c: Array[Vector3] = [at + Vector3(-base.x, -base.y, 0.0), at + Vector3(base.x, -base.y, 0.0),
		at + Vector3(base.x, base.y, 0.0), at + Vector3(-base.x, base.y, 0.0)]
	for i: int in 4:
		var a: Vector3 = c[i]
		var b: Vector3 = c[(i + 1) % 4]
		var mid: Vector3 = (a + b) * 0.5 - at
		_face(s, a, b, tip, tip, mid.normalized() + Vector3(0.0, 0.0, dir * 0.3), TOOTH)


## The raised spine down the back of the snout.
static func _spine(s: MeshLayer) -> void:
	var steps: int = 6
	for i: int in steps:
		var u0: float = lerpf(0.06, 0.8, float(i) / float(steps))
		var u1: float = lerpf(0.06, 0.8, float(i + 1) / float(steps))
		var z0: float = -jaw_size(u0).y
		var z1: float = -jaw_size(u1).y
		var a := Vector3(0.0, u0 * JAW_LENGTH + 0.05, z0)
		var b := Vector3(0.0, u1 * JAW_LENGTH - 0.05, z1)
		var mid: Vector3 = (a + b) * 0.5
		var length: float = a.distance_to(b)
		var dir: Vector3 = (b - a) / maxf(length, 0.001)
		var basis := Basis.looking_at(dir, Vector3(0.0, 0.0, -1.0))
		var ridge := MeshLayer.new()
		ridge.box(Vector3.ZERO, Vector3(0.32, 0.28, length), PLATE_DARK, 0.0, MeshKit.PAT_PLAIN)
		s.append(ridge, Transform3D(basis, mid + Vector3(0.0, 0.0, -0.1)))


## An eye on the side `sx` (-1 its left, +1 its right) of the snout: a steel bezel, the dark red glass lens bulging out of
## it with a darker pupil, and a glint, facing out from the head (none of it glows).
static func _eye(s: MeshLayer, sx: float) -> void:
	var u: float = EYE_AT
	var size: Vector2 = jaw_size(u)
	# Round from +-x toward the back (z < 0).
	var a: float = (PI + EYE_ROUND) if sx < 0.0 else (TAU - EYE_ROUND)
	var centre: Vector3 = _rim(size, u * JAW_LENGTH, a)
	var normal := Vector3(cos(a) / size.x, 0.0, sin(a) / size.y).normalized()
	var up := Vector3.UP
	var right: Vector3 = up.cross(normal).normalized()
	var sides: int = 8
	var bezel_c: Vector3 = centre + normal * 0.06
	var lens_c: Vector3 = centre + normal * (0.08 + EYE_BULGE)
	for i: int in sides:
		var t0: float = TAU * float(i) / float(sides)
		var t1: float = TAU * float(i + 1) / float(sides)
		var d0: Vector3 = right * cos(t0) + up * sin(t0)
		var d1: Vector3 = right * cos(t1) + up * sin(t1)
		# The bezel: a ring from the head's surface out to the lens's rim.
		_face(s, centre + d0 * EYE_BEZEL, centre + d1 * EYE_BEZEL, bezel_c + d1 * EYE_LENS, bezel_c + d0 * EYE_LENS,
			normal + (d0 + d1) * 0.3, BEZEL)
		# The lens: a shallow dome of dark red glass.
		var rim0: Vector3 = bezel_c + d0 * EYE_LENS * 0.96
		var rim1: Vector3 = bezel_c + d1 * EYE_LENS * 0.96
		var tri := MeshLayer.new()
		tri.quad(rim0, rim1, lens_c, lens_c, LENS, 0.0, MeshKit.PAT_GLASS)
		_append_facing(s, tri, normal)
	# The iris, a darker disc in the lens's middle (a camera's aperture), and a small glint high on one side, apart
	# from it (a slit and a glint touching read as a digit).
	var iris_c: Vector3 = lens_c + normal * 0.005
	for i: int in sides:
		var t0: float = TAU * float(i) / float(sides)
		var t1: float = TAU * float(i + 1) / float(sides)
		var iris := MeshLayer.new()
		iris.quad(iris_c + (right * cos(t0) + up * sin(t0)) * EYE_IRIS, iris_c + (right * cos(t1) + up * sin(t1)) * EYE_IRIS,
			iris_c, iris_c, PUPIL)
		_append_facing(s, iris, normal)
	var glint := MeshLayer.new()
	glint.rect(lens_c + normal * 0.01 + up * 0.3 - right * 0.36, right * 0.09, up * 0.09, GLINT)
	_append_facing(s, glint, normal)


## Appends `part`'s triangles turned to face `normal` (its winding flipped if they face away).
static func _append_facing(s: MeshLayer, part: MeshLayer, normal: Vector3) -> void:
	if part.verts.size() >= 3:
		var n: Vector3 = (part.verts[1] - part.verts[0]).cross(part.verts[2] - part.verts[0])
		if n.dot(normal) > 0.0:
			part.verts.reverse()
			part.colors.reverse()
			part.uvs.reverse()
			part.uv2s.reverse()
	s.append(part)


## Below the hinge: the throat's floor, the gill slits, the body down into the chasm, the fins.
static func _body(s: MeshLayer) -> void:
	# The throat's floor between the jaws: dark, the gullet in its middle ringed by grinding teeth.
	var cap: Vector2 = jaw_size(0.0)
	for j: int in BODY_SIDES:
		var a: float = TAU * float(j) / float(BODY_SIDES)
		var b: float = TAU * float(j + 1) / float(BODY_SIDES)
		var c := Vector3(0.0, -0.02, 0.0)
		_face(s, _rim(cap, -0.02, a), _rim(cap, -0.02, b), c, c, Vector3.UP, MOUTH)
		_face(s, _rim(cap * 0.42, 0.0, a), _rim(cap * 0.42, 0.0, b), c + Vector3(0, 0.02, 0), c + Vector3(0, 0.02, 0), Vector3.UP,
			GULLET)
		var g: Vector3 = _rim(cap * 0.5, 0.0, (a + b) * 0.5)
		s.box(g + Vector3(0.0, 0.18, 0.0), Vector3(0.36, 0.36, 0.36), MOUTH_RIB, 0.0, MeshKit.PAT_PLAIN)
	# The body: rings down from the hinge, broadest a little below it, tapering into the chasm, darker the deeper.
	var profile: Array[Vector3] = [Vector3(0.0, 1.0, 1.0), Vector3(-2.0, 1.04, 1.06), Vector3(-5.0, 1.1, 1.12),
		Vector3(-10.0, 1.12, 1.1), Vector3(-18.0, 1.02, 0.96), Vector3(-28.0, 0.82, 0.76), Vector3(-BODY_LENGTH, 0.55, 0.5)]
	for i: int in profile.size() - 1:
		var p0: Vector3 = profile[i]
		var p1: Vector3 = profile[i + 1]
		var w0 := Vector2(HALF_WIDTH * p0.y, HALF_DEPTH * p0.z)
		var w1 := Vector2(HALF_WIDTH * p1.y, HALF_DEPTH * p1.z)
		var fade: float = clampf((-p0.x - 6.0) / 30.0, 0.0, 1.0) * 0.85
		for j: int in BODY_SIDES:
			var a: float = TAU * float(j) / float(BODY_SIDES)
			var b: float = TAU * float(j + 1) / float(BODY_SIDES)
			var belly: bool = sin((a + b) * 0.5) > 0.35
			var tone: Color = (BELLY if belly else PLATE) if (i + j) % 2 == 0 else (BELLY_DARK if belly else PLATE_DARK)
			var outward := Vector3(cos((a + b) * 0.5), 0.0, sin((a + b) * 0.5))
			_face(s, _rim(w1, p1.x, a), _rim(w1, p1.x, b), _rim(w0, p0.x, b), _rim(w0, p0.x, a), outward, tone.lerp(DEEP, fade))
	# The gill slits: five dark slots down each side below the hinge, raked back.
	for sx: float in [-1.0, 1.0]:
		for k: int in 5:
			var y: float = -1.4 - float(k) * 0.75
			var a: float = (PI - 0.25) if sx < 0.0 else 0.25
			var w := Vector2(HALF_WIDTH * 1.05, HALF_DEPTH * 1.07)
			var at: Vector3 = _rim(w, y, a)
			var normal := Vector3(cos(a), 0.0, sin(a))
			var slot := MeshLayer.new()
			slot.box(Vector3.ZERO, Vector3(0.1, 0.22, 2.2), GILL, 0.0, MeshKit.PAT_PLAIN)
			var basis := Basis.looking_at(Vector3.UP.cross(normal).normalized() * -sx, normal)
			s.append(slot, Transform3D(basis.rotated(normal, 0.25 * sx), at + normal * 0.02))
	# The pectoral fins, out to each side and down, and the dorsal fin up its back (-z).
	for sx: float in [-1.0, 1.0]:
		var root0 := Vector3(sx * HALF_WIDTH * 1.08, -6.5, 1.0)
		var root1 := Vector3(sx * HALF_WIDTH * 1.08, -9.5, 0.2)
		var tip := Vector3(sx * (HALF_WIDTH + 6.5), -13.5, 1.6)
		_face(s, root0, root1, tip, tip, Vector3(0.0, 0.0, 1.0), PLATE_DARK.lerp(DEEP, 0.2))
		_face(s, root0, root1, tip, tip, Vector3(0.0, 0.0, -1.0), PLATE_DARK.lerp(DEEP, 0.2))
	var d0 := Vector3(0.0, -11.0, -HALF_DEPTH * 1.08)
	var d1 := Vector3(0.0, -19.0, -HALF_DEPTH * 1.0)
	var dt := Vector3(0.0, -21.0, -HALF_DEPTH - 5.5)
	_face(s, d0, d1, dt, dt, Vector3(1.0, 0.0, 0.0), PLATE.lerp(DEEP, 0.35))
	_face(s, d0, d1, dt, dt, Vector3(-1.0, 0.0, 0.0), PLATE.lerp(DEEP, 0.35))


## A patch a, b, c, d (d may equal c: a triangle) wound to face `outward`.
static func _face(s: MeshLayer, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3, color: Color) -> void:
	if (b - a).cross(c - a).dot(outward) > 0.0:
		s.quad(a, d, c, b, color, 0.0, MeshKit.PAT_PLAIN)
	else:
		s.quad(a, b, c, d, color, 0.0, MeshKit.PAT_PLAIN)

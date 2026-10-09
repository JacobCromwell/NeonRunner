class_name GoldenConvergenceMagnateModel
extends RefCounted
## The Magnate's meshes (GDD §10, Second stage, the look the owner approved on October 9, 2026: "blackish-grey
## skin cracked like burnt paper or cooled slag; splashes of the suit's gold melted onto him (dull, never
## glowing); half of the calm golden mask fused to one side of his face, dull red tear and all, the other half
## his real face, roaring; his weak points the glowing red ports along his spine where the suit plugged into
## him; the cape's remains as burgundy tatters trailing smoke. No glowing embers"; "the tentacle pipes turn out
## to be cables wiring him into the broadcast"; "two to three times the runner's size", on all fours). Built
## once in code at its reference size and shared, low-poly, in his own space: his root on the ground under his
## middle, +y up, -z his front (his head), the runner's 1.28 m beside him a third of his height reared up.
## One mesh per moving part (GoldenConvergenceMagnate puts them on the rig's nodes):
##   chest      his ribcage and hunched shoulders (the rig's front half), gold splashes melted on
##   hips       his haunches (the back half)
##   head       the skull and snout on the neck: on his left, half the calm golden mask (its closed eye's crease
##              and the dull red tear under it, unpolished: never glowing); on his right his real face, a
##              heavy brow and a wild, pale eye; the upper teeth
##   jaw        the lower jaw and its teeth (it drops open for the roar)
##   upper_front, lower_front, upper_hind, lower_hind   the legs' segments, the lower ones with a clawed paw
##   tatters    the cape's remains: burgundy strips hanging from his shoulders and back (they sway in the shader)
##   ports_chest, ports_hips   the red ports along his spine (their own glowing material: the weak points'
##              red, the only thing on him in a hazard colour)
##   cable      one broadcast cable (the suit's tentacle pipes, burnt), straight along +z from its socket: the
##              cable shader droops it to the ground behind him and sways it
## The body shader (golden_convergence_magnate.gdshader) draws the cracks: his burnt skin carries COLOR.a 1, the
## mask, the tatters, the teeth and the eye 0; UV2.x is the kind (0 lit, 1 cloth: UV2.y its sway weight, 2
## metal: UV2.y its polish). Every colour is sRGB and, but for the ports, inside the lit surfaces' chroma limit.

## DESIGN-TBD (docs/questions/e5d.md, E5d-d): the look as built (his build on all fours, the mask's side and
## the tear, the ports' number, the cables and tatters) is the owner's to review.

## The rig's joints (metres at scale 1): the spine's two halves' pivots (his root's space), the neck on the
## chest, the jaw's hinge on the head, the legs' tops (x mirrored: the front on the chest, the hind on the hips).
const CHEST_PIVOT := Vector3(0.0, 1.22, -0.3)
const HIPS_PIVOT := Vector3(0.0, 1.06, 0.42)
const NECK_AT := Vector3(0.0, 0.2, -0.98)
const JAW_AT := Vector3(0.0, -0.02, -0.62)
const FRONT_LEG := Vector3(0.46, -0.1, -0.6)
const HIND_LEG := Vector3(0.38, -0.06, 0.36)
const UPPER_FRONT: float = 0.74
const LOWER_FRONT: float = 0.72
const UPPER_HIND: float = 0.68
const LOWER_HIND: float = 0.76
## The red ports along his spine (the chest's three, the hips' two), in their halves' space.
const PORTS_CHEST: Array[Vector3] = [Vector3(0.0, 0.54, -0.62), Vector3(0.0, 0.6, -0.24), Vector3(0.0, 0.5, 0.14)]
const PORTS_HIPS: Array[Vector3] = [Vector3(0.0, 0.45, 0.02), Vector3(0.0, 0.46, 0.38)]
## The ribcage's ellipsoid (the chest's space) and the haunches' (the hips').
const RIBS_AT := Vector3(0.0, 0.05, -0.3)
const RIBS := Vector3(0.62, 0.56, 0.74)
const HAUNCH_AT := Vector3(0.0, 0.0, 0.22)
const HAUNCH := Vector3(0.52, 0.48, 0.62)
const PORT_RADIUS: float = 0.12
## The broadcast cables' sockets on his back (the chest's space), and a cable's length and thickness.
const CABLE_SOCKETS: Array[Vector3] = [Vector3(-0.22, 0.5, -0.44), Vector3(0.22, 0.5, -0.44), Vector3(-0.28, 0.48, -0.04),
	Vector3(0.28, 0.48, -0.04), Vector3(-0.2, 0.42, 0.3), Vector3(0.2, 0.42, 0.3)]
const CABLE_LENGTH: float = 5.6
const CABLE_RADIUS: float = 0.075
const CABLE_SEGMENTS: int = 14
## His body's extent at rest (his root's space): what a camera or a test sees of him (stun spans, the release).
const BODY_LENGTH: float = 3.5
const BODY_WIDTH: float = 1.4
const BODY_HEIGHT: float = 1.95
## Colours (sRGB): his burnt skin (blackish grey, ash on its ridges), the suit's gold melted onto him (dull), the
## mask's cast gold, its tear's dull red, the tatters' burgundy (the cape's) and its black, bone for teeth and
## claws, his wild eye, the mouth's dark, the cables' burnt metal and their dull gold bands.
const SKIN := Color(0.17, 0.162, 0.155)
const SKIN_DARK := Color(0.1, 0.094, 0.09)
const ASH := Color(0.3, 0.285, 0.27)
const GOLD_DULL := Color(0.5, 0.4, 0.24)
const MASK_GOLD := Color(0.8, 0.64, 0.4)
const MASK_CREASE := Color(0.3, 0.21, 0.1)
const TEAR := Color(0.36, 0.08, 0.075)
const CLOTH := Color(0.31, 0.03, 0.075)
const CLOTH_DARK := Color(0.11, 0.012, 0.03)
const BONE := Color(0.62, 0.58, 0.5)
const CLAW := Color(0.16, 0.15, 0.14)
const EYE := Color(0.78, 0.74, 0.62)
const PUPIL := Color(0.04, 0.035, 0.03)
const MOUTH := Color(0.07, 0.035, 0.035)
const CABLE := Color(0.13, 0.12, 0.11)
const CABLE_BAND := Color(0.46, 0.37, 0.21)
## The ports' red: the weak points' (FloatingHeadModel.WEAK, the hover truck's).
const PORT_RED := Color(1.0, 0.08, 0.1)
## Kinds (UV2.x) the body shader reads.
const KIND_LIT: int = 0
const KIND_CLOTH: int = 1
const KIND_METAL: int = 2
const SHADER: String = "res://scripts/bosses/golden_convergence/golden_convergence_magnate.gdshader"
const CABLE_SHADER: String = "res://scripts/bosses/golden_convergence/golden_convergence_magnate_cable.gdshader"

static var _meshes: Dictionary = {}


## Every mesh, built once and cached: {chest, hips, head, jaw, upper_front, lower_front, upper_hind,
## lower_hind, tatters, ports_chest, ports_hips, cable} (their materials are set per instance).
static func meshes() -> Dictionary:
	if not _meshes.is_empty():
		return _meshes
	_meshes = {
		"chest": _chest(),
		"hips": _hips(),
		"head": _head(),
		"jaw": _jaw(),
		"upper_front": _limb(UPPER_FRONT, 0.17, 0.13, 0.19, false),
		"lower_front": _limb(LOWER_FRONT, 0.12, 0.1, 0.13, true),
		"upper_hind": _limb(UPPER_HIND, 0.2, 0.15, 0.24, false),
		"lower_hind": _limb(LOWER_HIND, 0.12, 0.1, 0.13, true),
		"tatters": _tatters(),
		"ports_chest": _ports(PORTS_CHEST),
		"ports_hips": _ports(PORTS_HIPS),
		"cable": _cable(),
	}
	return _meshes


## His body's material (one per Magnate: the crack glow and the shudder are his own).
static func body_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(SHADER) as Shader
	return m


## A cable's material (one per cable: its sway, droop and phase are its own).
static func cable_material(phase: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(CABLE_SHADER) as Shader
	m.set_shader_parameter(&"phase", phase)
	m.set_shader_parameter(&"cable_length", CABLE_LENGTH)
	return m


## The ports' material: the weak points' red, glowing (GoldenConvergenceMagnate pulses its energy; steady with
## Reduced flashing).
static func port_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = PORT_RED
	m.emission_enabled = true
	m.emission = PORT_RED
	m.emission_energy_multiplier = 3.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


## Every lit colour his meshes use (tests: the colour rule; the ports' red is their own material).
static func surface_colors() -> Array[Color]:
	return [SKIN, SKIN_DARK, ASH, GOLD_DULL, MASK_GOLD, MASK_CREASE, TEAR, CLOTH, CLOTH_DARK, BONE, CLAW, EYE, PUPIL,
		MOUTH, CABLE, CABLE_BAND]


# --- Primitives ------------------------------------------------------------------------------------

## Part of an ellipsoid at `center` with `radii`: latitude lat0..lat1 (-PI/2 the bottom), longitude lon0..lon1
## (0 toward +z, PI toward -z: his front), turned by `basis`. Its quads coloured by `paint` (a Callable(p:
## Vector3) -> Color, the quad's middle) or `color`, `crack` and `kind`/`param` for the shader.
static func _ellipsoid(s: MeshLayer, center: Vector3, radii: Vector3, rings: int, segs: int, color: Color, crack: float,
		kind: int = KIND_LIT, param: float = 0.0, lat0: float = -PI * 0.5, lat1: float = PI * 0.5, lon0: float = -PI,
		lon1: float = PI, basis: Basis = Basis.IDENTITY, paint: Callable = Callable()) -> void:
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
			var mid: Vector3 = (p00 + p11) * 0.5
			var c: Color = paint.call(mid) if paint.is_valid() else color
			_quad(s, p00, p01, p11, p10, mid - center, c, crack, kind, param)


static func _dir(lat: float, lon: float) -> Vector3:
	return Vector3(sin(lon) * cos(lat), sin(lat), cos(lon) * cos(lat))


## A four-cornered face toward `outward` (either winding).
static func _quad(s: MeshLayer, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3, color: Color,
		crack: float, kind: int = KIND_LIT, param: float = 0.0) -> void:
	if (b - a).cross(c - a).dot(outward) > 0.0:
		s.quad(a, d, c, b, color, crack, kind, param)
	else:
		s.quad(a, b, c, d, color, crack, kind, param)


## A triangle toward `outward`.
static func _tri(s: MeshLayer, a: Vector3, b: Vector3, c: Vector3, outward: Vector3, color: Color, crack: float,
		kind: int = KIND_LIT, param: float = 0.0) -> void:
	var col := Color(color, crack)
	if (b - a).cross(c - a).dot(outward) > 0.0:
		s.verts.append_array(PackedVector3Array([a, c, b]))
	else:
		s.verts.append_array(PackedVector3Array([a, b, c]))
	s.colors.append_array(PackedColorArray([col, col, col]))
	s.uvs.append_array(PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]))
	var p := Vector2(kind, param)
	s.uv2s.append_array(PackedVector2Array([p, p, p]))


## A pointed cone from `base` (a ring of `radius` across `axis`) to `tip`: a tooth, a claw, a spine.
static func _spike(s: MeshLayer, base: Vector3, tip: Vector3, radius: float, sides: int, color: Color, crack: float) -> void:
	var axis: Vector3 = (tip - base).normalized()
	var ref: Vector3 = Vector3.UP if absf(axis.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var u: Vector3 = axis.cross(ref).normalized()
	var v: Vector3 = axis.cross(u).normalized()
	for k: int in sides:
		var a0: float = TAU * float(k) / sides
		var a1: float = TAU * float(k + 1) / sides
		var p0: Vector3 = base + (u * cos(a0) + v * sin(a0)) * radius
		var p1: Vector3 = base + (u * cos(a1) + v * sin(a1)) * radius
		_tri(s, p0, p1, tip, (p0 + p1) * 0.5 - base, color, crack)
		_tri(s, p0, p1, base, -axis, color, crack)


## Where the suit's gold splashed and melted onto him: patches that look poured, never a pattern.
static func _gold_splash(p: Vector3, amount: float) -> bool:
	var v: float = sin(p.x * 6.1 + 1.3) * sin(p.y * 4.7 + 0.4) * sin(p.z * 5.3 + 2.2) \
		+ 0.35 * sin(p.x * 13.0 - p.z * 9.0 + p.y * 7.0)
	return v > 1.0 - amount


## His skin at `p`: burnt black-grey, ash on a few ridges, gold splashed on (`gold` 0-1, how much).
static func _skin_at(p: Vector3, gold: float) -> Color:
	if _gold_splash(p, gold):
		return GOLD_DULL
	var h: float = MeshKit.hash01(int(p.x * 37.0 + 400.0), int(p.y * 41.0 + 400.0), int(p.z * 43.0 + 400.0))
	if h > 0.86:
		return ASH
	return SKIN if h > 0.22 else SKIN_DARK


# --- The parts ---------------------------------------------------------------------------------------

## His ribcage and hunched shoulders (the chest pivot's space), the shoulders' bony ridges, gold melted on.
static func _chest() -> ArrayMesh:
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(null)
	var paint := func(p: Vector3) -> Color: return _skin_at(p, 0.38)
	_ellipsoid(s, RIBS_AT, RIBS, 6, 12, SKIN, 1.0, KIND_LIT, 0.0, -PI * 0.5, PI * 0.5, -PI, PI, Basis.IDENTITY, paint)
	for side: float in [-1.0, 1.0]:
		_ellipsoid(s, Vector3(side * 0.36, 0.3, -0.58), Vector3(0.34, 0.32, 0.4), 4, 8, SKIN, 1.0, KIND_LIT, 0.0,
			-PI * 0.3, PI * 0.5, -PI, PI, Basis(Vector3.BACK, side * 0.35), paint)
	# The spine's ridge between the ports: bony knuckles, burnt; a dark socket's rim round each port.
	for z: float in [-0.86, -0.43, -0.05, 0.34]:
		var y: float = top_of(RIBS_AT, RIBS, z) - 0.02
		_spike(s, Vector3(0.0, y, z), Vector3(0.0, y + 0.16, z + 0.08), 0.07, 4, ASH, 1.0)
	for p: Vector3 in PORTS_CHEST:
		socket_rim(s, p)
	return batch.to_mesh()


## The top of an ellipsoid at `center` with `radii` along its middle line at z (its own space).
static func top_of(center: Vector3, radii: Vector3, z: float) -> float:
	var k: float = 1.0 - pow((z - center.z) / radii.z, 2.0)
	return center.y + radii.y * sqrt(maxf(k, 0.0))


## His haunches (the hips pivot's space).
static func _hips() -> ArrayMesh:
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(null)
	var paint := func(p: Vector3) -> Color: return _skin_at(p + Vector3(0.0, 0.0, 3.0), 0.3)
	_ellipsoid(s, HAUNCH_AT, HAUNCH, 6, 10, SKIN, 1.0, KIND_LIT, 0.0, -PI * 0.5, PI * 0.5, -PI, PI, Basis.IDENTITY, paint)
	for side: float in [-1.0, 1.0]:
		_ellipsoid(s, Vector3(side * 0.34, -0.02, 0.36), Vector3(0.26, 0.38, 0.34), 4, 6, SKIN_DARK, 1.0, KIND_LIT, 0.0,
			-PI * 0.5, PI * 0.5, -PI, PI, Basis.IDENTITY, paint)
	for p: Vector3 in PORTS_HIPS:
		socket_rim(s, p)
	return batch.to_mesh()


## The skull, snout and upper teeth on the neck (the neck node's space: the neck runs from its origin
## forward to the head): on his left (-x) half the calm golden mask with its closed eye and dull red tear, on
## his right his real face, a heavy brow and a wild, pale eye.
static func _head() -> ArrayMesh:
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(null)
	var paint := func(p: Vector3) -> Color: return _skin_at(p + Vector3(7.0, 0.0, 0.0), 0.15)
	# The neck, thick and corded.
	_ellipsoid(s, Vector3(0.0, 0.0, -0.22), Vector3(0.27, 0.27, 0.36), 4, 8, SKIN, 1.0, KIND_LIT, 0.0, -PI * 0.5, PI * 0.5,
		-PI, PI, Basis(Vector3.RIGHT, 0.3), paint)
	# The skull and the snout (the upper jaw).
	var skull := Vector3(0.0, 0.12, -0.52)
	var skull_r := Vector3(0.29, 0.28, 0.32)
	_ellipsoid(s, skull, skull_r, 6, 10, SKIN, 1.0, KIND_LIT, 0.0, -PI * 0.5, PI * 0.5, -PI, PI, Basis.IDENTITY, paint)
	_ellipsoid(s, Vector3(0.0, 0.02, -0.82), Vector3(0.19, 0.13, 0.2), 4, 8, SKIN_DARK, 1.0, KIND_LIT, 0.0, -PI * 0.15,
		PI * 0.5, -PI, PI, Basis.IDENTITY, paint)
	# The mask on his left: a shell of cast gold over that half of his face (from the snout's middle round to
	# the side of his head), fused on, its rim a little proud of the skin.
	var mask_r: Vector3 = skull_r * 1.08 + Vector3(0.0, 0.0, 0.02)
	_ellipsoid(s, skull + Vector3(0.0, 0.0, -0.02), mask_r, 5, 5, MASK_GOLD, 0.0, KIND_METAL, 0.65, -PI * 0.32, PI * 0.36,
		-PI, -PI * 0.52)
	_ellipsoid(s, Vector3(-0.005, 0.02, -0.83), Vector3(0.205, 0.145, 0.215), 3, 3, MASK_GOLD, 0.0, KIND_METAL, 0.65,
		-PI * 0.1, PI * 0.45, -PI, -PI * 0.55)
	# Its closed eye: a heavy lid's crease curving down; the tear from under it down the cheek, a dull red
	# (unpolished: it never glows).
	var eye_l: Vector3 = skull + Vector3(-0.13, 0.08, -0.32)
	for k: int in 4:
		var a0: float = lerpf(-1.0, 1.0, float(k) / 4.0)
		var a1: float = lerpf(-1.0, 1.0, float(k + 1) / 4.0)
		var p0: Vector3 = eye_l + Vector3(a0 * 0.075, -0.018 * (1.0 - a0 * a0), -0.01)
		var p1: Vector3 = eye_l + Vector3(a1 * 0.075, -0.018 * (1.0 - a1 * a1), -0.01)
		_quad(s, p0, p1, p1 + Vector3(0.0, -0.016, 0.0), p0 + Vector3(0.0, -0.016, 0.0), Vector3(0.0, 0.0, -1.0), MASK_CREASE, 0.0)
	var tear0: Vector3 = eye_l + Vector3(0.02, -0.05, -0.012)
	var tear1: Vector3 = eye_l + Vector3(0.035, -0.19, 0.02)
	_quad(s, tear0 + Vector3(-0.012, 0.0, 0.0), tear0 + Vector3(0.012, 0.0, 0.0), tear1 + Vector3(0.016, 0.0, 0.0),
		tear1 + Vector3(-0.016, 0.0, 0.0), Vector3(0.0, 0.0, -1.0), TEAR, 0.0)
	_ellipsoid(s, tear1 + Vector3(0.0, -0.018, 0.0), Vector3(0.024, 0.026, 0.012), 2, 4, TEAR, 0.0)
	# His real eye on the right: wide and pale, its pupil dark, under a heavy brow knotted in rage.
	var eye_r: Vector3 = skull + Vector3(0.14, 0.07, -0.3)
	_ellipsoid(s, eye_r, Vector3(0.06, 0.045, 0.03), 2, 6, EYE, 0.0)
	_ellipsoid(s, eye_r + Vector3(0.0, 0.0, -0.024), Vector3(0.022, 0.026, 0.01), 2, 4, PUPIL, 0.0)
	_quad(s, eye_r + Vector3(-0.09, 0.07, -0.04), eye_r + Vector3(0.1, 0.11, 0.0), eye_r + Vector3(0.1, 0.06, 0.03),
		eye_r + Vector3(-0.09, 0.03, -0.05), Vector3(0.2, 0.6, -1.0), SKIN_DARK, 1.0)
	# The upper teeth, under the snout's rim (his real side's bared, the mask's shut behind its gold).
	for k: int in 5:
		var x: float = lerpf(-0.04, 0.15, float(k) / 4.0)
		var z: float = -0.92 + absf(x) * 0.6
		_spike(s, Vector3(x, -0.06, z), Vector3(x, -0.17, z - 0.01), 0.025, 3, BONE, 0.0)
	return batch.to_mesh()


## The lower jaw (its hinge at the origin, reaching forward along -z) and its teeth.
static func _jaw() -> ArrayMesh:
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(null)
	var paint := func(p: Vector3) -> Color: return _skin_at(p + Vector3(0.0, 9.0, 0.0), 0.1)
	_ellipsoid(s, Vector3(0.0, -0.06, -0.24), Vector3(0.18, 0.08, 0.28), 3, 8, SKIN_DARK, 1.0, KIND_LIT, 0.0, -PI * 0.5,
		PI * 0.5, -PI, PI, Basis.IDENTITY, paint)
	# The mouth's inside: dark (never red: red is the weak points' and the warnings').
	_quad(s, Vector3(-0.13, 0.0, -0.06), Vector3(0.13, 0.0, -0.06), Vector3(0.1, 0.0, -0.44), Vector3(-0.1, 0.0, -0.44),
		Vector3.UP, MOUTH, 0.0)
	for k: int in 6:
		var x: float = lerpf(-0.11, 0.11, float(k) / 5.0)
		var z: float = -0.44 + absf(x) * 0.9
		_spike(s, Vector3(x, 0.0, z), Vector3(x, 0.1, z + 0.01), 0.022, 3, BONE, 0.0)
	return batch.to_mesh()


## A leg's segment hanging from its joint along -y: a muscled, tapering ellipsoid; `paw`: the lower segment,
## with a clawed paw at its end.
static func _limb(length: float, r_top: float, r_bottom: float, depth: float, paw: bool) -> ArrayMesh:
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(null)
	var paint := func(p: Vector3) -> Color: return _skin_at(p + Vector3(3.0, 5.0, 1.0), 0.2)
	_ellipsoid(s, Vector3(0.0, -length * 0.5, 0.0), Vector3((r_top + r_bottom) * 0.5, length * 0.56, depth), 4, 6, SKIN,
		1.0, KIND_LIT, 0.0, -PI * 0.5, PI * 0.5, -PI, PI, Basis.IDENTITY, paint)
	if paw:
		var at := Vector3(0.0, -length, -0.07)
		_ellipsoid(s, at, Vector3(0.17, 0.08, 0.21), 3, 6, SKIN_DARK, 1.0, KIND_LIT, 0.0, -PI * 0.5, PI * 0.5, -PI, PI,
			Basis.IDENTITY, paint)
		for k: int in 4:
			var x: float = lerpf(-0.11, 0.11, float(k) / 3.0)
			_spike(s, at + Vector3(x, -0.02, -0.16), at + Vector3(x * 1.1, -0.08, -0.33), 0.03, 3, CLAW, 0.0)
	return batch.to_mesh()


## The cape's remains: burgundy strips hanging from his shoulders and back (the chest's space), ragged at
## their ends, both faces drawn; each vertex's sway weight grows from the strip's root (the shader sways them).
static func _tatters() -> ArrayMesh:
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(null)
	var roots: Array[Vector3] = [Vector3(-0.5, 0.36, -0.62), Vector3(0.5, 0.36, -0.62), Vector3(-0.3, 0.52, -0.15),
		Vector3(0.32, 0.5, -0.1), Vector3(0.0, 0.56, 0.12), Vector3(-0.46, 0.3, 0.2), Vector3(0.48, 0.28, 0.24)]
	var lengths: Array[float] = [1.05, 0.95, 1.35, 1.2, 1.5, 0.9, 1.0]
	for i: int in roots.size():
		var root: Vector3 = roots[i]
		var side: float = signf(root.x) if absf(root.x) > 0.05 else 0.0
		var length: float = lengths[i]
		var width: float = 0.3 - 0.03 * float(i % 3)
		var segs: int = 4
		var prev_l := Vector3.ZERO
		var prev_r := Vector3.ZERO
		for k: int in segs + 1:
			var u: float = float(k) / segs
			# Down his side and back, flaring out a little, narrowing to a ragged tip.
			var c: Vector3 = root + Vector3(side * 0.28 * u, -0.55 * length * u, 0.55 * length * u)
			var w: float = width * (1.0 - 0.55 * u) * (0.75 + 0.25 * MeshKit.hash01(i, k, 911))
			var across: Vector3 = Vector3(1.0, 0.0, 0.0) if side == 0.0 else Vector3(0.0, 0.0, 1.0)
			var l: Vector3 = c - across * w * 0.5
			var r: Vector3 = c + across * w * 0.5
			if k > 0:
				var col: Color = CLOTH if (i + k) % 3 != 0 else CLOTH_DARK
				var out := Vector3(side, 0.4, 0.0) if side != 0.0 else Vector3(0.0, 0.4, 1.0)
				var w0: float = float(k - 1) / segs
				var w1: float = u
				# Both faces (cloth seen from either side), each corner with its sway weight.
				_cloth_quad(s, prev_l, prev_r, r, l, out, col, w0, w1)
				_cloth_quad(s, prev_l, prev_r, r, l, -out, col, w0, w1)
			prev_l = l
			prev_r = r
	return batch.to_mesh()


## A strip of cloth from (a, b) at sway weight w0 to (c, d) at w1, toward `outward`.
static func _cloth_quad(s: MeshLayer, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3, color: Color,
		w0: float, w1: float) -> void:
	var col := Color(color, 0.0)
	var flip: bool = (b - a).cross(c - a).dot(outward) > 0.0
	var corners: Array[Vector3] = [a, b, c, d]
	var weights: Array[float] = [w0, w0, w1, w1]
	if flip:
		corners = [a, d, c, b]
		weights = [w0, w1, w1, w0]
	for idx: int in [0, 1, 2, 0, 2, 3]:
		s.verts.append(corners[idx])
		s.colors.append(col)
		s.uvs.append(Vector2.ZERO)
		s.uv2s.append(Vector2(KIND_CLOTH, weights[idx]))


## Red domes for the ports at `points` (their half's space), each in a dark socket ring.
static func _ports(points: Array[Vector3]) -> ArrayMesh:
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(null)
	for p: Vector3 in points:
		_ellipsoid(s, p, Vector3(PORT_RADIUS, PORT_RADIUS * 0.7, PORT_RADIUS), 3, 8, PORT_RED, 0.0, KIND_LIT, 0.0, 0.0,
			PI * 0.5)
	return batch.to_mesh()


## The sockets' rims round the ports, on the skin (the chest and hips meshes' own parts would hide the domes'
## bases; a dark collar reads better). Added to the body meshes' builds.
static func socket_rim(s: MeshLayer, p: Vector3) -> void:
	for k: int in 8:
		var a0: float = TAU * float(k) / 8.0
		var a1: float = TAU * float(k + 1) / 8.0
		var r0: float = PORT_RADIUS * 1.05
		var r1: float = PORT_RADIUS * 1.5
		var q0 := Vector3(cos(a0), 0.0, sin(a0))
		var q1 := Vector3(cos(a1), 0.0, sin(a1))
		_quad(s, p + q0 * r0, p + q1 * r0, p + q1 * r1 + Vector3(0.0, -0.03, 0.0), p + q0 * r1 + Vector3(0.0, -0.03, 0.0),
			Vector3.UP, CLAW, 0.0)


## One broadcast cable, straight along +z from its socket (0) to its end (CABLE_LENGTH): UV.y how far along it
## (0-1), for the cable shader that droops it to the ground and sways it; dull gold bands every few segments.
static func _cable() -> ArrayMesh:
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(null)
	var sides: int = 6
	var n: int = CABLE_SEGMENTS
	for i: int in n:
		var v0: float = float(i) / n
		var v1: float = float(i + 1) / n
		var z0: float = v0 * CABLE_LENGTH
		var z1: float = v1 * CABLE_LENGTH
		var r0: float = CABLE_RADIUS * lerpf(1.25, 0.8, v0)
		var r1: float = CABLE_RADIUS * lerpf(1.25, 0.8, v1)
		var col: Color = CABLE_BAND if i % 4 == 1 else CABLE
		for k: int in sides:
			var a0: float = TAU * float(k) / sides
			var a1: float = TAU * float(k + 1) / sides
			var p00 := Vector3(cos(a0) * r0, sin(a0) * r0, z0)
			var p01 := Vector3(cos(a1) * r0, sin(a1) * r0, z0)
			var p11 := Vector3(cos(a1) * r1, sin(a1) * r1, z1)
			var p10 := Vector3(cos(a0) * r1, sin(a0) * r1, z1)
			var out := Vector3(cos((a0 + a1) * 0.5), sin((a0 + a1) * 0.5), 0.0)
			var kind: int = KIND_METAL if col == CABLE_BAND else KIND_LIT
			if (p01 - p00).cross(p11 - p00).dot(out) > 0.0:
				s.quad_uv(p00, p10, p11, p01, Vector2(0.0, v0), Vector2(0.0, v1), Vector2(1.0, v1), Vector2(1.0, v0), col, 0.0,
					kind, 0.45)
			else:
				s.quad_uv(p00, p01, p11, p10, Vector2(0.0, v0), Vector2(1.0, v0), Vector2(1.0, v1), Vector2(0.0, v1), col, 0.0,
					kind, 0.45)
	return batch.to_mesh()


## Vertices in `mesh` (tests: the draw budget).
static func vertex_count(mesh: Mesh) -> int:
	var total: int = 0
	if mesh == null:
		return 0
	for i: int in mesh.get_surface_count():
		total += (mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return total

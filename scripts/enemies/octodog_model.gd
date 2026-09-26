class_name OctodogModel
extends Node3D
## The Octodog's look (GDD §9.4): a mass of green tentacles on robotic dog legs. Procedural and
## low-poly, from meshes and materials cached for every dog (about 14 draw calls each). The
## tentacles writhe in a vertex shader driven by per-instance uniforms (one shared material); the
## legs walk with a small two-bone IK. Faces -Z; the Octodog turns it.
##
## Hazard language: the tentacles (the part that grabs) glow toxic green and the eyes red in every
## zone. The zone variant only weathers the robot legs (clean alloy in the city, rust in scavenger
## zones).

const TENTACLE_SHADER: String = """
shader_type spatial;
render_mode cull_disabled;
// Per dog (instance uniforms, so every dog shares one material).
instance uniform float writhe = 1.0;
instance uniform float flare = 0.0;
instance uniform float reach = 0.0;
instance uniform float seed = 0.0;
uniform float emission_strength = 2.6;

void vertex() {
	float s = UV.x;
	float id = UV.y * 23.0 + seed;
	float t = TIME * (2.0 + writhe * 1.6 + flare * 3.0) + id;
	vec3 sway = vec3(sin(t + s * 3.2), 0.5 * sin(t * 0.7 + s * 2.1 + 1.3), cos(t * 0.9 + s * 2.9))
		* (0.11 * writhe + 0.05 * flare) * s * s;
	vec2 outward = VERTEX.xz;
	float len = length(outward);
	outward = len > 0.001 ? outward / len : vec2(0.0);
	vec3 spread = vec3(outward.x * 0.8, 1.0, outward.y * 0.5) * (0.3 * flare) * s;
	vec3 grab = vec3(0.0, -0.25, -1.0) * (0.55 * reach) * s * s;
	VERTEX += sway + spread + grab;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.3;
	SPECULAR = 0.7;
	EMISSION = COLOR.rgb * COLOR.a * emission_strength;
}
"""

const HIP_HEIGHT: float = 0.56
const THIGH: float = 0.3
const SHIN: float = 0.3
const TENTACLE_GREEN_BASE := Color(0.08, 0.42, 0.1)
const TENTACLE_GREEN_TIP := Color(0.55, 1.0, 0.3)
const EYE_RED := Color(1.0, 0.12, 0.06)
const JOINT_GREEN := Color(0.35, 1.0, 0.3)

static var _mass_mesh: ArrayMesh
static var _mass_material: ShaderMaterial
static var _joint_mesh: SphereMesh
static var _telegraph_mesh: ArrayMesh
static var _materials: Dictionary = {}

## Animation inputs, set by the Octodog each frame.
var ground_speed: float = 0.0
## 0–1: the wind-up crouch.
var crouch: float = 0.0
## 0–1: tentacles rear up and spread (the wind-up).
var flare: float = 0.0
## 0–1: tentacles reach forward (the lunge).
var reach: float = 0.0
## 0–1: legs stretched out in a leap.
var leap: float = 0.0
## 0–1: sitting down (gave up).
var sitting: float = 0.0

var _body: Node3D
var _mass: MeshInstance3D
var _legs: Array[Dictionary] = []
var _gait: float = 0.0
var _seed: float = 0.0


## Builds the dog. `variant` is the zone's enemy variant (&"city" or &"scavenger").
func build(variant: StringName, p_seed: float) -> void:
	_seed = p_seed
	_body = Node3D.new()
	add_child(_body)
	var metal: Material = metal_material(variant)
	var chassis := GreyboxMaterials.add_box(_body, Vector3(0.0, 0.6, 0.0), Vector3(0.5, 0.17, 0.84), metal)
	chassis.name = "Chassis"
	for sx: float in [-1.0, 1.0]:
		GreyboxMaterials.add_box(_body, Vector3(sx * 0.255, 0.6, 0.0), Vector3(0.02, 0.05, 0.7),
			GreyboxMaterials.glow(JOINT_GREEN, 2.0))
	_mass = MeshInstance3D.new()
	_mass.name = "Tentacles"
	_mass.mesh = mass_mesh()
	_mass.material_override = mass_material()
	_mass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(_mass)
	_mass.set_instance_shader_parameter(&"seed", p_seed * 7.0)
	var glow: Material = GreyboxMaterials.glow(JOINT_GREEN, 2.2)
	for i: int in 4:
		var front: bool = i < 2
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.25, HIP_HEIGHT, -0.3 if front else 0.3)
		_body.add_child(hip)
		GreyboxMaterials.add_box(hip, Vector3(0.0, -THIGH * 0.5, 0.0), Vector3(0.11, THIGH, 0.12), metal)
		var knee := Node3D.new()
		knee.position = Vector3(0.0, -THIGH, 0.0)
		hip.add_child(knee)
		var joint := MeshInstance3D.new()
		joint.mesh = joint_mesh()
		joint.material_override = glow
		joint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		knee.add_child(joint)
		# Shin with a flat foot plate at its end.
		GreyboxMaterials.add_box(knee, Vector3(0.0, -SHIN * 0.5, 0.0), Vector3(0.08, SHIN, 0.09), metal)
		_legs.append({"hip": hip, "knee": knee, "front": front, "phase": [0.0, 0.45, PI, PI + 0.45][i]})
	animate(0.0)


## Advances the procedural animation (legs, body bob, tentacles).
func animate(delta: float) -> void:
	var run: float = clampf(absf(ground_speed) / 22.0, 0.0, 1.0)
	_gait += delta * (6.0 + 10.0 * run) * (1.0 if ground_speed >= 0.0 else -1.0)
	var bob: float = sin(_gait * 2.0) * 0.035 * run * (1.0 - leap)
	_body.position.y = bob - 0.16 * crouch - 0.12 * sitting
	_body.rotation.x = -0.12 * crouch + 0.35 * sitting + 0.15 * leap
	var hip_h: float = HIP_HEIGHT + _body.position.y
	for leg: Dictionary in _legs:
		var front: bool = leg["front"]
		var psi: float = _gait + float(leg["phase"])
		var stride: float = 0.22 * run * (1.0 - crouch)
		var f: float = stride * sin(psi)
		var lift: float = maxf(0.0, cos(psi)) * 0.13 * run
		# The wind-up paws the ground; the lunge stretches the legs out; sitting folds the hind legs.
		f += crouch * (0.06 * sin(Time.get_ticks_msec() * 0.012 + float(leg["phase"])) if front else -0.08)
		f = lerpf(f, 0.32 if front else -0.34, leap)
		lift = lerpf(lift, 0.18, leap)
		if not front:
			f = lerpf(f, 0.22, sitting)
		var height: float = hip_h - (0.25 * sitting if not front else 0.0)
		_leg_ik(leg, f, height - lift, front)
	_mass.set_instance_shader_parameter(&"writhe", 0.8 + 0.6 * run)
	_mass.set_instance_shader_parameter(&"flare", flare)
	_mass.set_instance_shader_parameter(&"reach", reach)


## Two-bone IK in the leg's y-z plane: the foot `forward` metres ahead of the hip and `drop` below.
## Front knees bend back and hind knees forward, like a running robot dog.
func _leg_ik(leg: Dictionary, forward: float, drop: float, front: bool) -> void:
	var r: float = clampf(sqrt(forward * forward + drop * drop), 0.08, THIGH + SHIN - 0.005)
	var beta: float = atan2(forward, maxf(drop, 0.001))
	var cos_knee: float = clampf((THIGH * THIGH + SHIN * SHIN - r * r) / (2.0 * THIGH * SHIN), -1.0, 1.0)
	var bend: float = PI - acos(cos_knee)
	var cos_hip: float = clampf((THIGH * THIGH + r * r - SHIN * SHIN) / (2.0 * THIGH * r), -1.0, 1.0)
	var phi: float = acos(cos_hip)
	var hip: Node3D = leg["hip"]
	var knee: Node3D = leg["knee"]
	if front:
		hip.rotation.x = beta - phi
		knee.rotation.x = bend
	else:
		hip.rotation.x = beta + phi
		knee.rotation.x = -bend


# --- Shared meshes and materials ---------------------------------------------------------

## The robot legs and chassis. The only part that changes by zone: clean alloy or rust.
static func metal_material(variant: StringName) -> StandardMaterial3D:
	var key: String = "metal_%s" % variant
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		if variant == &"scavenger":
			m.albedo_color = Color(0.46, 0.3, 0.19)
			m.metallic = 0.45
			m.roughness = 0.8
		else:
			m.albedo_color = Color(0.5, 0.55, 0.64)
			m.metallic = 0.75
			m.roughness = 0.3
		_materials[key] = m
	return _materials[key]


static func mass_material() -> ShaderMaterial:
	if _mass_material == null:
		var shader := Shader.new()
		shader.code = TENTACLE_SHADER
		_mass_material = ShaderMaterial.new()
		_mass_material.shader = shader
	return _mass_material


static func joint_mesh() -> SphereMesh:
	if _joint_mesh == null:
		_joint_mesh = SphereMesh.new()
		_joint_mesh.radius = 0.055
		_joint_mesh.height = 0.11
		_joint_mesh.radial_segments = 6
		_joint_mesh.rings = 3
	return _joint_mesh


## The tentacle mass: a squashed blob with three red eyes at the front, eight tentacles rising and
## curling out of it, two reaching forward (the grabbers) and one trailing as a tail.
## UV.x = position along a tentacle (0 base, 1 tip), UV.y = tentacle id; COLOR.a = glow.
static func mass_mesh() -> ArrayMesh:
	if _mass_mesh != null:
		return _mass_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_ellipsoid(st, Vector3(0.0, 0.8, 0.02), Vector3(0.34, 0.24, 0.42), 9, 5, Color(0.08, 0.36, 0.1, 0.3))
	for e: Vector3 in [Vector3(-0.12, 0.86, -0.38), Vector3(0.12, 0.86, -0.38), Vector3(0.0, 0.97, -0.34)]:
		_octahedron(st, e, 0.065, Color(EYE_RED, 1.0))
	# Upper ring: bases on top of the blob, leaning out and curling back in at the tips.
	var ring: int = 8
	for i: int in ring:
		var a: float = TAU * (float(i) + 0.5) / ring
		var out := Vector3(sin(a), 0.0, cos(a))
		var base := Vector3(0.0, 0.82, 0.02) + Vector3(out.x * 0.22, 0.13, out.z * 0.28)
		var dir: Vector3 = (out * 0.6 + Vector3.UP).normalized()
		_tentacle(st, base, dir, out.cross(Vector3.UP).normalized(), 0.62 + 0.14 * float(i % 2), 2.3,
			0.095, 0.016, float(i) / 12.0)
	# Two grabbers reaching forward (-Z), curling up at the tips.
	for sx: float in [-1.0, 1.0]:
		var base := Vector3(sx * 0.17, 0.72, -0.32)
		_tentacle(st, base, Vector3(sx * 0.25, -0.15, -1.0).normalized(), Vector3(1.0, 0.0, 0.0), 0.68,
			-1.9, 0.085, 0.016, (9.0 + sx) / 12.0)
	# Tail.
	_tentacle(st, Vector3(0.0, 0.76, 0.38), Vector3(0.0, 0.5, 1.0).normalized(), Vector3(1.0, 0.0, 0.0),
		0.55, 1.6, 0.065, 0.012, 11.5 / 12.0)
	_mass_mesh = st.commit()
	return _mass_mesh


## A tapered, curling tube from `base` along `dir`, bending around `axis` by `curl` radians over its length.
static func _tentacle(st: SurfaceTool, base: Vector3, dir: Vector3, axis: Vector3, length: float,
		curl: float, r0: float, r1: float, id: float) -> void:
	var points := PackedVector3Array()
	var radii := PackedFloat32Array()
	var steps: int = 6
	var p: Vector3 = base
	for i: int in steps + 1:
		var s: float = float(i) / steps
		points.append(p)
		radii.append(lerpf(r0, r1, s))
		var d: Vector3 = dir.rotated(axis, curl * s * s)
		p += d * (length / steps)
	_tube(st, points, radii, 5, id)


static func _tube(st: SurfaceTool, points: PackedVector3Array, radii: PackedFloat32Array, sides: int,
		id: float) -> void:
	var n: int = points.size()
	var rings: Array[PackedVector3Array] = []
	var side := Vector3.ZERO
	for i: int in n:
		var tangent: Vector3 = (points[mini(i + 1, n - 1)] - points[maxi(i - 1, 0)]).normalized()
		side = side - tangent * side.dot(tangent)
		if side.length() < 0.01:
			side = tangent.cross(Vector3.UP if absf(tangent.y) < 0.9 else Vector3.RIGHT)
		side = side.normalized()
		var up: Vector3 = tangent.cross(side).normalized()
		var ring := PackedVector3Array()
		for k: int in sides:
			var a: float = TAU * k / sides
			ring.append(points[i] + (side * cos(a) + up * sin(a)) * radii[i])
		rings.append(ring)
	for i: int in n - 1:
		var s0: float = float(i) / (n - 1)
		var s1: float = float(i + 1) / (n - 1)
		var c0: Color = _tentacle_color(s0)
		var c1: Color = _tentacle_color(s1)
		for k: int in sides:
			var k1: int = (k + 1) % sides
			var axis_mid: Vector3 = (points[i] + points[i + 1]) * 0.5
			_quad(st, [rings[i][k], rings[i + 1][k], rings[i + 1][k1], rings[i][k1]],
				[s0, s1, s1, s0], [c0, c1, c1, c0], id, axis_mid)
	var tip: Vector3 = points[n - 1] + (points[n - 1] - points[n - 2]).normalized() * radii[n - 1] * 2.0
	var ct: Color = _tentacle_color(1.0)
	for k: int in sides:
		var k1: int = (k + 1) % sides
		_tri(st, [rings[n - 1][k], tip, rings[n - 1][k1]], [1.0, 1.0, 1.0], [ct, ct, ct], id, points[n - 1])


static func _tentacle_color(s: float) -> Color:
	var c: Color = TENTACLE_GREEN_BASE.lerp(TENTACLE_GREEN_TIP, s * s)
	c.a = lerpf(0.3, 1.0, s)
	return c


static func _ellipsoid(st: SurfaceTool, center: Vector3, radius: Vector3, segments: int, rings: int,
		color: Color) -> void:
	var grid: Array[PackedVector3Array] = []
	for r: int in rings + 1:
		var lat: float = PI * float(r) / rings - PI * 0.5
		var row := PackedVector3Array()
		for s: int in segments:
			var lon: float = TAU * float(s) / segments
			row.append(center + Vector3(cos(lat) * sin(lon) * radius.x, sin(lat) * radius.y, cos(lat) * cos(lon) * radius.z))
		grid.append(row)
	for r: int in rings:
		for s: int in segments:
			var s1: int = (s + 1) % segments
			_quad(st, [grid[r][s], grid[r][s1], grid[r + 1][s1], grid[r + 1][s]], [0.0, 0.0, 0.0, 0.0],
				[color, color, color, color], 0.0, center)


static func _octahedron(st: SurfaceTool, center: Vector3, r: float, color: Color) -> void:
	var v: Array[Vector3] = [Vector3(r, 0, 0), Vector3(-r, 0, 0), Vector3(0, r, 0), Vector3(0, -r, 0),
		Vector3(0, 0, r), Vector3(0, 0, -r)]
	var faces: Array = [[0, 2, 4], [2, 1, 4], [1, 3, 4], [3, 0, 4], [2, 0, 5], [1, 2, 5], [3, 1, 5], [0, 3, 5]]
	for f: Array in faces:
		_tri(st, [center + v[f[0]], center + v[f[1]], center + v[f[2]]], [0.0, 0.0, 0.0],
			[color, color, color], 0.0, center)


static func _quad(st: SurfaceTool, p: Array, s: Array, c: Array, id: float, inside: Vector3) -> void:
	_tri(st, [p[0], p[1], p[2]], [s[0], s[1], s[2]], [c[0], c[1], c[2]], id, inside)
	_tri(st, [p[0], p[2], p[3]], [s[0], s[2], s[3]], [c[0], c[2], c[3]], id, inside)


## One flat-shaded triangle facing away from `inside`, wound clockwise as seen from outside (Godot's
## front faces).
static func _tri(st: SurfaceTool, p: Array, s: Array, c: Array, id: float, inside: Vector3) -> void:
	var a: Vector3 = p[0]
	var b: Vector3 = p[1]
	var d: Vector3 = p[2]
	var n: Vector3 = (b - a).cross(d - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	var order: Array[int] = [0, 1, 2]
	if n.dot((a + b + d) / 3.0 - inside) > 0.0:
		order = [0, 2, 1]
	else:
		n = -n
	for i: int in order:
		st.set_normal(n)
		st.set_color(c[i])
		st.set_uv(Vector2(s[i], id))
		st.add_vertex(p[i])


# --- Doghouse and telegraph ----------------------------------------------------------------

## The doghouse hint (GDD §9.4), about the dog's size, door toward +Z (the player). Its own node:
## the Octodog frees it when the dog bursts out.
static func build_doghouse(variant: StringName) -> Node3D:
	var root := Node3D.new()
	root.name = "Doghouse"
	var scav: bool = variant == &"scavenger"
	var wall_mat: Material = GreyboxMaterials.flat(Color(0.36, 0.22, 0.12) if scav else Color(0.12, 0.2, 0.3))
	var roof_mat: Material = GreyboxMaterials.flat(Color(0.25, 0.16, 0.1) if scav else Color(0.2, 0.08, 0.22))
	var trim: Material = GreyboxMaterials.glow(Color(1.0, 0.55, 0.15) if scav else Color(0.2, 0.9, 1.0), 2.0)
	GreyboxMaterials.add_box(root, Vector3(0.0, 0.55, 0.0), Vector3(1.3, 1.1, 1.4), wall_mat)
	for sx: float in [-1.0, 1.0]:
		var roof := GreyboxMaterials.add_box(root, Vector3(sx * 0.36, 1.36, 0.0), Vector3(0.95, 0.1, 1.6), roof_mat)
		roof.rotation.z = -sx * 0.62
	# Dark arched door with a glowing name plate over it, and a bone sign: "a dog lives here".
	GreyboxMaterials.add_box(root, Vector3(0.0, 0.4, 0.71), Vector3(0.55, 0.72, 0.03), GreyboxMaterials.flat(Color(0.01, 0.01, 0.015)))
	GreyboxMaterials.add_box(root, Vector3(0.0, 0.95, 0.72), Vector3(0.6, 0.14, 0.03), trim)
	var bone_mat: Material = GreyboxMaterials.glow(Color(0.95, 0.95, 0.85), 1.4)
	GreyboxMaterials.add_box(root, Vector3(0.0, 1.2, 0.73), Vector3(0.34, 0.07, 0.03), bone_mat)
	for bx: float in [-0.18, 0.18]:
		for by: float in [-0.04, 0.04]:
			GreyboxMaterials.add_box(root, Vector3(bx, 1.2 + by, 0.73), Vector3(0.08, 0.08, 0.03), bone_mat)
	# Red eyes and grabbing tentacles peeking out of the door.
	var peek := MeshInstance3D.new()
	peek.mesh = mass_mesh()
	peek.material_override = mass_material()
	peek.position = Vector3(0.0, -0.25, 0.5)
	peek.scale = Vector3.ONE * 0.8
	peek.rotation.y = PI
	root.add_child(peek)
	peek.set_instance_shader_parameter(&"reach", 0.4)
	return root


## A unit arrow on the floor from z = 0 to z = -1 (plus its head), 1 m wide, for the lunge line.
static func telegraph_mesh() -> ArrayMesh:
	if _telegraph_mesh != null:
		return _telegraph_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var up := Vector3.UP
	var pts: Array[Vector3] = [Vector3(-0.3, 0, 0), Vector3(0.3, 0, 0), Vector3(0.3, 0, -0.82), Vector3(-0.3, 0, -0.82)]
	for tri: Array in [[0, 3, 2], [0, 2, 1]]:
		for i: int in tri:
			st.set_normal(up)
			st.add_vertex(pts[i])
	for v: Vector3 in [Vector3(-0.5, 0, -0.8), Vector3(0.0, 0, -1.0), Vector3(0.5, 0, -0.8)]:
		st.set_normal(up)
		st.add_vertex(v)
	_telegraph_mesh = st.commit()
	return _telegraph_mesh

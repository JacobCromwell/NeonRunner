class_name ScreechModel
extends RefCounted
## The Sewer Screech's body (GDD §9.5): slimy, diseased vermin with rows of spines on its back.
## Built as ONE low-poly mesh with ONE shared material per zone variant, animated entirely in its
## vertex shader, so it's cheap on its own and ready to be drawn hundreds of times with a MultiMesh
## for the swarm boss (GDD §10: 4–5 simulated clusters rendered as many screeches).
##
## Animation inputs per creature (all 0–1 except seed):
##   swipe   – the swipe's progress (0–0.45 claw up, 0.45–0.7 strike, 0.7–1 recover)
##   bristle – spines raised and glowing (angry)
##   scurry  – leg and tail speed
##   seed    – any number; de-syncs creatures
## A MeshInstance3D sets them with set_instance_shader_parameter() (instance uniforms). A MultiMesh
## with use_custom_data uses a copy of the material with `use_custom` on and packs them into each
## instance's custom data as Color(swipe, bristle, scurry, seed); see multimesh_material().
##
## The mesh faces -Z, feet at y = 0, about 1.4 m from snout to tail tip and 0.6 m to the spine tips.
## Vertex data: COLOR.rgb albedo, COLOR.a glow; UV.x part id, UV.y weight along the part (0 root, 1 tip).

const SHADER: String = """
shader_type spatial;
render_mode cull_disabled;
instance uniform float swipe = 0.0;
instance uniform float bristle = 0.0;
instance uniform float scurry = 0.0;
instance uniform float seed = 0.0;
// MultiMesh swarms: read the same four values from INSTANCE_CUSTOM instead.
uniform bool use_custom = false;
// Zone weathering: 0 = city (dark and slick), 1 = scavenger zones (grimier, more diseased).
uniform float grime = 0.0;
uniform float emission_strength = 2.4;
varying float v_bristle;
varying float v_lesion;

vec3 rot_x(vec3 p, float a) { return vec3(p.x, p.y * cos(a) - p.z * sin(a), p.y * sin(a) + p.z * cos(a)); }
vec3 rot_y(vec3 p, float a) { return vec3(p.x * cos(a) + p.z * sin(a), p.y, -p.x * sin(a) + p.z * cos(a)); }

void vertex() {
	vec4 st = use_custom ? INSTANCE_CUSTOM : vec4(swipe, bristle, scurry, seed);
	float part = floor(UV.x + 0.5);
	float w = UV.y;
	float t = TIME * (5.0 + 16.0 * st.z) + st.w * 6.2831;
	vec3 rest = VERTEX;
	vec3 v = VERTEX;
	// Breathing and a slithering undulation along the body.
	v.y += sin(t * 0.35 + v.z * 6.0) * 0.012;
	v.x += sin(t * 0.5 + v.z * 4.0) * 0.015 * st.z;
	if (part > 4.5 && part < 8.5) {
		float leg = part - 5.0;
		float ph = t + mod(leg, 2.0) * 3.1416 + (leg > 1.5 ? 1.5708 : 0.0);
		v.z += sin(ph) * 0.08 * w * (0.25 + st.z);
		v.y += max(0.0, cos(ph)) * 0.06 * w * st.z;
	} else if (part > 1.5 && part < 2.5) {
		vec3 out_dir = normalize(vec3(v.x * 3.0, 1.0, 0.35));
		v += out_dir * w * st.y * 0.12;
		v.x += sin(t * 2.3 + v.z * 25.0) * 0.012 * w * (0.3 + st.y);
	} else if (part > 2.5 && part < 3.5) {
		vec3 pivot = vec3(0.13, 0.27, -0.25);
		float raise = smoothstep(0.0, 0.45, st.x) * (1.0 - smoothstep(0.45, 0.62, st.x));
		float strike = smoothstep(0.45, 0.62, st.x) * (1.0 - smoothstep(0.75, 1.0, st.x));
		vec3 p = v - pivot;
		p = rot_x(p, 1.9 * raise - 0.5 * strike);
		p = rot_y(p, 0.75 * strike);
		p.z -= strike * w * 0.35;
		v = pivot + p;
	} else if (part > 3.5 && part < 4.5) {
		v.z += sin(t) * 0.04 * w * (0.3 + st.z);
	} else if (part > 8.5) {
		v.x += sin(t * 0.7 + w * 3.0) * 0.13 * w;
		v.y += sin(t * 0.5 + w * 2.0) * 0.04 * w;
	}
	VERTEX = v;
	v_bristle = st.y;
	// Blotchy lesions from the rest position, so they stick to the skin.
	vec3 q = rest * 11.0 + vec3(st.w * 3.0);
	v_lesion = smoothstep(0.55, 0.9, sin(q.x) * sin(q.y * 1.3) * sin(q.z * 0.9) * 0.5 + 0.5);
}

void fragment() {
	vec3 skin = COLOR.rgb;
	float is_skin = 1.0 - step(0.05, COLOR.a);
	vec3 sore = mix(vec3(0.55, 0.5, 0.12), vec3(0.45, 0.14, 0.3), grime);
	skin = mix(skin, sore, v_lesion * is_skin * (0.35 + 0.45 * grime));
	skin *= mix(vec3(1.0), vec3(0.85, 0.75, 0.6), grime * is_skin);
	ALBEDO = skin;
	ROUGHNESS = mix(0.15, 0.45, grime);
	SPECULAR = 0.85;
	EMISSION = COLOR.rgb * COLOR.a * emission_strength * (1.0 + 1.5 * v_bristle);
}
"""

const SKIN := Color(0.2, 0.22, 0.16)
const BELLY := Color(0.32, 0.3, 0.22)
const SPINE_BASE := Color(0.18, 0.08, 0.07)
## The spines and claws are the deadly parts: hot red-orange in every zone.
const SPINE_TIP := Color(1.0, 0.28, 0.08)
const EYE := Color(1.0, 0.85, 0.1)
const TALON := Color(0.95, 0.9, 0.8)

enum Part { TORSO, HEAD, SPINE, SWIPE_ARM, OTHER_ARM, LEG_FL, LEG_FR, LEG_BL, LEG_BR, TAIL }

static var _mesh: ArrayMesh
static var _materials: Dictionary = {}


## The shared material for a zone variant (&"city" or &"scavenger"), for MeshInstance3D screeches.
static func material(variant: StringName) -> ShaderMaterial:
	var key: String = String(variant)
	if not _materials.has(key):
		var shader: Shader = _shader()
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter(&"grime", 1.0 if variant == &"scavenger" else 0.0)
		_materials[key] = m
	return _materials[key]


## The same look for a MultiMesh swarm: per-creature values come from each instance's custom data,
## Color(swipe, bristle, scurry, seed) (MultiMesh.use_custom_data must be on).
static func multimesh_material(variant: StringName) -> ShaderMaterial:
	var key: String = "mm_%s" % variant
	if not _materials.has(key):
		var m: ShaderMaterial = material(variant).duplicate() as ShaderMaterial
		m.set_shader_parameter(&"use_custom", true)
		_materials[key] = m
	return _materials[key]


static func _shader() -> Shader:
	if not _materials.has("shader"):
		var s := Shader.new()
		s.code = SHADER
		_materials["shader"] = s
	return _materials["shader"]


## The one body mesh, built once.
static func mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Hunched torso: an ellipsoid pushed up in the middle of the back.
	_blob(st, Vector3(0.0, 0.26, 0.05), Vector3(0.19, 0.15, 0.36), 8, 5, Part.TORSO, 0.07)
	# Head and snout.
	_blob(st, Vector3(0.0, 0.25, -0.36), Vector3(0.12, 0.1, 0.16), 6, 4, Part.HEAD, 0.0)
	_cone(st, Vector3(0.0, 0.23, -0.46), Vector3(0.0, 0.2, -0.62), 0.07, 5, SKIN, SKIN, Part.HEAD, 0.0)
	for sx: float in [-1.0, 1.0]:
		_octa(st, Vector3(sx * 0.07, 0.31, -0.44), 0.03, Color(EYE, 1.0), Part.HEAD)
		_cone(st, Vector3(sx * 0.03, 0.2, -0.55), Vector3(sx * 0.03, 0.12, -0.56), 0.014, 3,
			TALON, TALON, Part.HEAD, 0.0)
		_cone(st, Vector3(sx * 0.08, 0.33, -0.3), Vector3(sx * 0.12, 0.43, -0.26), 0.035, 3,
			SKIN, Color(0.45, 0.2, 0.25), Part.HEAD, 0.0)
	# Rows of spines along the back (GDD §9.5), tallest down the middle.
	for row: int in 3:
		var x: float = (row - 1) * 0.09
		for i: int in 6:
			var z: float = -0.2 + i * 0.1
			var hump: float = 0.07 * cos(z * 3.0)
			var base := Vector3(x, 0.26 + 0.14 * sqrt(maxf(0.0, 1.0 - pow(x / 0.19, 2.0))) + hump - 0.02, z)
			var h: float = (0.2 if row == 1 else 0.14) * (0.8 + 0.4 * sin(float(i) * 1.7 + row))
			var tip: Vector3 = base + Vector3(x * 0.8, 1.0, 0.45).normalized() * h
			_cone(st, base, tip, 0.028, 4, SPINE_BASE, Color(SPINE_TIP, 0.9), Part.SPINE, 1.0)
	# Legs.
	var legs: Array = [[Part.LEG_FL, -1.0, -0.17], [Part.LEG_FR, 1.0, -0.17], [Part.LEG_BL, -1.0, 0.22],
		[Part.LEG_BR, 1.0, 0.22]]
	for leg: Array in legs:
		var hip := Vector3(float(leg[1]) * 0.13, 0.22, float(leg[2]))
		var paw := Vector3(float(leg[1]) * 0.16, 0.02, float(leg[2]) - 0.03)
		_cone(st, hip, paw, 0.05, 4, SKIN, BELLY, int(leg[0]), 1.0, 0.03)
	# Arms: the right one swipes; hooked talons glow at the tips.
	for arm: Array in [[Part.SWIPE_ARM, 1.0], [Part.OTHER_ARM, -1.0]]:
		var sx: float = float(arm[1])
		var shoulder := Vector3(sx * 0.13, 0.27, -0.25)
		var wrist := Vector3(sx * 0.19, 0.12, -0.47)
		_cone(st, shoulder, wrist, 0.045, 4, SKIN, BELLY, int(arm[0]), 0.7, 0.03)
		for k: int in 3:
			var off := Vector3(sx * (0.035 * (k - 1)), 0.0, 0.0)
			_cone(st, wrist + off, wrist + off + Vector3(sx * 0.02, -0.07, -0.13), 0.018, 3, TALON,
				Color(SPINE_TIP, 0.8), int(arm[0]), 1.0, 0.0, 0.7)
	# Long tail.
	var prev := Vector3(0.0, 0.24, 0.38)
	for i: int in 5:
		var s0: float = float(i) / 5.0
		var s1: float = float(i + 1) / 5.0
		var next := Vector3(0.0, 0.24 - 0.17 * s1, 0.38 + 0.6 * s1)
		_cone(st, prev, next, lerpf(0.045, 0.01, s0), 4, SKIN, SKIN, Part.TAIL, s1, lerpf(0.045, 0.01, s1), s0)
		prev = next
	_mesh = st.commit()
	return _mesh


## An ellipsoid (the torso or head), pushed up by `hump` along the middle of the back.
static func _blob(st: SurfaceTool, center: Vector3, r: Vector3, segments: int, rings: int, part: int,
		hump: float) -> void:
	var grid: Array[PackedVector3Array] = []
	for ri: int in rings + 1:
		var lat: float = PI * float(ri) / rings - PI * 0.5
		var row := PackedVector3Array()
		for s: int in segments:
			var lon: float = TAU * float(s) / segments
			var p := Vector3(cos(lat) * sin(lon) * r.x, sin(lat) * r.y, cos(lat) * cos(lon) * r.z)
			if p.y > 0.0:
				p.y += hump * cos(p.z * 3.0) * (p.y / r.y)
			row.append(center + p)
		grid.append(row)
	for ri: int in rings:
		for s: int in segments:
			var s1: int = (s + 1) % segments
			var quad: Array = [grid[ri][s], grid[ri][s1], grid[ri + 1][s1], grid[ri + 1][s]]
			var cols: Array = []
			for q: Vector3 in quad:
				cols.append(BELLY if q.y < center.y - r.y * 0.3 else SKIN)
			_tri(st, [quad[0], quad[1], quad[2]], [cols[0], cols[1], cols[2]], part, [0.0, 0.0, 0.0], center)
			_tri(st, [quad[0], quad[2], quad[3]], [cols[0], cols[2], cols[3]], part, [0.0, 0.0, 0.0], center)


## A tapered cone (or truncated cone when `r1` > 0) from `a` to `b`; weight runs w0 → w1.
static func _cone(st: SurfaceTool, a: Vector3, b: Vector3, r0: float, sides: int, c0: Color, c1: Color,
		part: int, w1: float, r1: float = 0.0, w0: float = 0.0) -> void:
	var axis: Vector3 = (b - a).normalized()
	var side: Vector3 = axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var up: Vector3 = axis.cross(side).normalized()
	var ring0 := PackedVector3Array()
	var ring1 := PackedVector3Array()
	for k: int in sides:
		var ang: float = TAU * k / sides
		var dir: Vector3 = side * cos(ang) + up * sin(ang)
		ring0.append(a + dir * r0)
		ring1.append(b + dir * r1)
	var mid: Vector3 = (a + b) * 0.5
	for k: int in sides:
		var k1: int = (k + 1) % sides
		if r1 > 0.0:
			_tri(st, [ring0[k], ring1[k], ring1[k1]], [c0, c1, c1], part, [w0, w1, w1], mid)
			_tri(st, [ring0[k], ring1[k1], ring0[k1]], [c0, c1, c0], part, [w0, w1, w0], mid)
		else:
			_tri(st, [ring0[k], b, ring0[k1]], [c0, c1, c0], part, [w0, w1, w0], mid)


static func _octa(st: SurfaceTool, c: Vector3, r: float, color: Color, part: int) -> void:
	var v: Array[Vector3] = [Vector3(r, 0, 0), Vector3(-r, 0, 0), Vector3(0, r, 0), Vector3(0, -r, 0),
		Vector3(0, 0, r), Vector3(0, 0, -r)]
	for f: Array in [[0, 2, 4], [2, 1, 4], [1, 3, 4], [3, 0, 4], [2, 0, 5], [1, 2, 5], [3, 1, 5], [0, 3, 5]]:
		_tri(st, [c + v[f[0]], c + v[f[1]], c + v[f[2]]], [color, color, color], part, [0.0, 0.0, 0.0], c)


## One flat-shaded triangle facing away from `inside`, wound clockwise seen from outside.
static func _tri(st: SurfaceTool, p: Array, c: Array, part: int, w: Array, inside: Vector3) -> void:
	var n: Vector3 = (p[1] - p[0]).cross(p[2] - p[0])
	if n.length_squared() < 1e-14:
		return
	n = n.normalized()
	var order: Array[int] = [0, 1, 2]
	if n.dot((p[0] + p[1] + p[2]) / 3.0 - inside) > 0.0:
		order = [0, 2, 1]
	else:
		n = -n
	for i: int in order:
		st.set_normal(n)
		st.set_color(c[i])
		st.set_uv(Vector2(float(part), float(w[i])))
		st.add_vertex(p[i])

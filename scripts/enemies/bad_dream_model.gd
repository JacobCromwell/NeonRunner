class_name BadDreamModel
extends Node3D
## The Cyborg's Bad Dream's look (GDD §9.7): a ghostly apparition, black with purple highlights, a
## mix of vapour and liquid. A bulbous head with a circular maw of spiked teeth, long fingers ending
## in slashing claws, and no legs: the body thins into a vapour tail.
##
## Procedural and low-poly (CLAUDE.md Assets), built once and shared: ONE opaque mesh for the liquid
## body (head, teeth, throat, torso, arms, drips) and ONE translucent mesh for the vapour (tail and a
## glowing shroud around the head), each with one shader that animates it in its vertex stage, plus
## a CPUParticles3D drip: three draw calls, fine on the Compatibility renderer (web, low-end Android).
## Only one Bad Dream is ever in play, so each gets its own copy of the two materials and is driven
## through plain uniforms.
##
## Colour language: the body keeps its GDD black and purple. Only the attack reads in enemy-fire red
## (the throat and claws heat up while it telegraphs and slashes), like every enemy attack.
## Reduced flashing (the global shader uniform, kit_flash.gdshaderinc): no glitch flicker in its
## glow, and the telegraph's lane marks keep a steady light.
## Visual only: nothing here touches collision or gameplay. The mesh faces +Z (toward the player it
## floats ahead of), with the tail's tip at y = 0 and the top of the head about 3.35 m up.
##
## Vertex data: COLOR.rgb albedo, COLOR.a glow (liquid) or opacity (vapour); UV.x part id, UV.y
## weight along the part (0 at its root, 1 at its tip).

## The Bad Dream's purple (the hosts' visor glitch, cyborg_kit.gd GLITCH_COLOR).
const PURPLE := Color(0.72, 0.25, 1.0)
## Enemy-attack red (ProjectilePool's enemy fire).
const ATTACK_RED := Color(1.0, 0.12, 0.08)

enum Part { HEAD, TEETH, THROAT, TORSO, ARM_L, ARM_R, DRIP, TAIL, SHROUD }

## Where the parts sit, in the model's space (used by the shaders and BadDream's effects).
const HEAD_CENTER := Vector3(0.0, 2.78, 0.0)
const HEAD_RADII := Vector3(0.5, 0.56, 0.48)
const MAW_CENTER := Vector3(0.0, 2.7, 0.47)
const MAW_RADIUS: float = 0.25
const SHOULDER := Vector3(0.3, 2.2, 0.05)
## Where the claws hang at rest (right hand; the left mirrors it).
const CLAW_REST := Vector3(1.1, 0.55, 0.6)

const LIQUID_SHADER: String = """
shader_type spatial;
render_mode cull_disabled;
#include "res://scripts/world/meshes/shaders/kit_flash.gdshaderinc"
// Animation inputs (0-1 unless noted), set by the Bad Dream every frame.
uniform float maw = 0.0;       // the circular maw opening
uniform float raise = 0.0;     // arms lifted and spread over the lanes it will slash
uniform float slash = 0.0;     // the arms sweeping down and across
uniform float reach = 1.0;     // arm stretch (1 = rest length), to span the lanes
uniform float attack = 0.0;    // throat and claws heat up to enemy-attack red
uniform float lunge = 0.0;     // the upper body thrusts toward the player
uniform float fade = 0.0;      // 0 = solid, 1 = dissolved (it also materializes through it)
uniform float seed = 0.0;
uniform vec4 rim_color : source_color = vec4(0.72, 0.25, 1.0, 1.0);
uniform vec4 attack_color : source_color = vec4(1.0, 0.12, 0.08, 1.0);
uniform float rim_energy = 2.2;
uniform float glow_energy = 3.0;
varying vec3 v_rest;
varying float v_hot;

vec3 rot_x(vec3 p, float a) { return vec3(p.x, p.y * cos(a) - p.z * sin(a), p.y * sin(a) + p.z * cos(a)); }
vec3 rot_y(vec3 p, float a) { return vec3(p.x * cos(a) + p.z * sin(a), p.y, -p.x * sin(a) + p.z * cos(a)); }
vec3 rot_z(vec3 p, float a) { return vec3(p.x * cos(a) - p.y * sin(a), p.x * sin(a) + p.y * cos(a), p.z); }
float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }

void vertex() {
	float part = floor(UV.x + 0.5);
	float w = UV.y;
	float t = TIME + seed * 7.3;
	vec3 v = VERTEX;
	v_rest = v;
	v_hot = 0.0;
	// A slow liquid wobble over the whole body.
	v += vec3(sin(t * 2.1 + v.y * 3.1), 0.5 * sin(t * 1.7 + v.x * 4.3), cos(t * 1.9 + v.y * 2.6)) * 0.018;
	if (part > 0.5 && part < 2.5) {
		// The maw: teeth and throat widen around its centre and the teeth splay outward.
		vec3 c = vec3(0.0, 2.7, 0.47);
		vec3 d = v - c;
		float open = mix(0.42, 1.28, maw);
		d.xy *= open;
		d.xy += normalize(d.xy + vec2(0.0001)) * maw * 0.06 * w;
		d.z += maw * 0.05 * (1.0 - w);
		v = c + d;
		v_hot = part > 1.5 ? 1.0 : 0.35;
	} else if (part > 3.5 && part < 5.5) {
		float sx = part < 4.5 ? -1.0 : 1.0;
		vec3 pivot = vec3(sx * 0.3, 2.2, 0.05);
		vec3 p = v - pivot;
		p *= mix(1.0, reach, smoothstep(0.15, 1.0, w));
		p = rot_z(p, sx * 0.1 * sin(t * 1.3 + sx) * (1.0 - raise));
		p = rot_x(p, 0.12 * sin(t * 1.1 + sx * 2.0));
		// Raise: lifted out over the lanes, claws tipped toward the player.
		p = rot_z(p, sx * 1.25 * raise);
		p = rot_x(p, 0.55 * raise);
		// Slash: down and across in front of it.
		p = rot_z(p, -sx * 1.5 * slash);
		p = rot_y(p, -sx * 1.15 * slash);
		v = pivot + p;
		v_hot = smoothstep(0.8, 0.9, w);
	} else if (part > 5.5 && part < 6.5) {
		// Drips stretch and swing.
		v.y -= w * (0.05 + 0.05 * sin(t * 3.0 + v_rest.x * 9.0));
		v.x += w * 0.03 * sin(t * 2.3 + v_rest.z * 7.0);
	}
	// The lunge thrusts the head and shoulders at the player.
	v.z += lunge * 0.65 * smoothstep(1.2, 3.0, v_rest.y);
	// Dissolving, it melts and drips away.
	v.y -= fade * fade * (0.6 + 0.5 * sin(v_rest.x * 9.0 + seed));
	VERTEX = v;
}

void fragment() {
	// Dissolve (and materialize): cells of the surface vanish at random, the bottom first.
	float n = hash(floor(v_rest * 9.0) + vec3(seed));
	if (n < fade * 1.25 - 0.12 + (1.0 - clamp(v_rest.y / 3.4, 0.0, 1.0)) * fade * 0.3) {
		discard;
	}
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.4);
	// A rare glitch in its glow; none with Reduced flashing.
	float glitch = (1.0 - reduced_flashing) * step(0.94, hash(vec3(floor(TIME * 13.0), seed, 1.0)));
	vec3 glow = mix(COLOR.rgb, attack_color.rgb, clamp(attack * v_hot * 1.3, 0.0, 1.0));
	ALBEDO = COLOR.rgb * 0.35;
	ROUGHNESS = 0.1;
	SPECULAR = 0.9;
	EMISSION = rim_color.rgb * rim * rim_energy * (1.0 - 0.6 * glitch)
		+ glow * COLOR.a * glow_energy * (1.0 + attack * v_hot * 1.5);
}
"""

const VAPOR_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
uniform float lunge = 0.0;
uniform float fade = 0.0;
uniform float attack = 0.0;
uniform float seed = 0.0;
uniform vec4 rim_color : source_color = vec4(0.72, 0.25, 1.0, 1.0);
varying float v_shroud;

void vertex() {
	float part = floor(UV.x + 0.5);
	float w = UV.y;
	float t = TIME + seed * 5.1;
	vec3 v = VERTEX;
	v_shroud = part > 7.5 ? 1.0 : 0.0;
	if (v_shroud < 0.5) {
		// The tail writhes and streams back as it goes.
		v.x += sin(t * 2.2 + v.y * 2.4) * 0.16 * w;
		v.z += 0.3 * w * w + sin(t * 1.6 + v.y * 3.1) * 0.08 * w;
	} else {
		// The shroud breathes and flares when it attacks.
		vec3 c = vec3(0.0, 2.78, 0.0);
		v = c + (v - c) * (1.0 + 0.04 * sin(t * 2.7 + v.y * 5.0) + 0.1 * attack);
	}
	v.z += lunge * 0.65 * smoothstep(1.2, 3.0, VERTEX.y);
	v.y -= fade * fade * 0.8;
	VERTEX = v;
}

void fragment() {
	float edge = 1.0 - abs(dot(NORMAL, VIEW));
	float shape = mix(0.3 + 0.7 * edge, pow(edge, 2.2), v_shroud);
	ALBEDO = mix(COLOR.rgb, rim_color.rgb * 1.8, edge * edge);
	ALPHA = clamp(COLOR.a * shape * (1.0 - fade), 0.0, 1.0);
}
"""

## The lanes a slash will cover, lit on the floor (and on a wall), in the player's frame: they fill
## from the far end toward the player as the lunge nears (a fuse), with bright edges so every lane
## reads on its own. With Reduced flashing there's no beat and the stripes crawl slowly: the fill
## alone shows the timing.
const MARK_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
#include "res://scripts/world/meshes/shaders/kit_flash.gdshaderinc"
uniform vec4 color : source_color = vec4(1.0, 0.12, 0.08, 1.0);
uniform float progress = 0.0;
uniform float fade = 1.0;
void fragment() {
	float edge = smoothstep(0.34, 0.47, abs(UV.x - 0.5));
	float front_at = 1.0 - progress;
	float filled = smoothstep(front_at - 0.02, front_at + 0.02, UV.y);
	float front = 1.0 - smoothstep(0.0, 0.07, abs(UV.y - front_at));
	float stripes = step(0.5, fract(UV.y * 7.0 - TIME * mix(2.0, 0.4, reduced_flashing)));
	float beat = 1.0 - (1.0 - reduced_flashing) * 0.3 * (0.5 + 0.5 * sin(TIME * mix(9.0, 24.0, progress)));
	float a = 0.14 + 0.1 * stripes + 0.34 * filled + 0.55 * edge + 0.5 * front;
	ALBEDO = color.rgb * (1.3 + 1.2 * filled + 2.0 * front) * beat;
	ALPHA = clamp(a * fade, 0.0, 0.95);
}
"""

## The slash itself: three claw streaks sweeping across the covered lanes, then fading.
const ARC_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;
#include "res://scripts/world/meshes/shaders/kit_flash.gdshaderinc"
uniform vec4 color : source_color = vec4(1.0, 0.15, 0.1, 1.0);
uniform float sweep = 0.0;
uniform float fade = 1.0;
uniform float dir = 1.0;
void fragment() {
	float u = dir > 0.0 ? UV.x : 1.0 - UV.x;
	float shown = step(u, sweep);
	float head = (1.0 - smoothstep(0.0, 0.3, sweep - u)) * shown;
	float core = 1.0 - smoothstep(0.1, 0.5, abs(UV.y - 0.5));
	ALBEDO = color.rgb * (1.6 + 3.0 * head * (1.0 - 0.6 * reduced_flashing)) * core;
	ALPHA = clamp(shown * core * fade, 0.0, 1.0);
}
"""

static var _liquid_mesh: ArrayMesh
static var _vapor_mesh: ArrayMesh
static var _arc_mesh: ArrayMesh
static var _shaders: Dictionary = {}

## Animation inputs, set by the Bad Dream each frame (see LIQUID_SHADER).
var maw: float = 0.0
var raise: float = 0.0
var slash: float = 0.0
var reach: float = 1.0
var attack: float = 0.0
var lunge: float = 0.0
var fade: float = 0.0

var _liquid: MeshInstance3D
var _vapor: MeshInstance3D
var _drips: CPUParticles3D
var _liquid_material: ShaderMaterial
var _vapor_material: ShaderMaterial


func build(p_seed: float) -> void:
	_liquid_material = ShaderMaterial.new()
	_liquid_material.shader = shader("liquid")
	_liquid_material.set_shader_parameter(&"seed", p_seed)
	_vapor_material = ShaderMaterial.new()
	_vapor_material.shader = shader("vapor")
	_vapor_material.set_shader_parameter(&"seed", p_seed)
	_liquid = MeshInstance3D.new()
	_liquid.name = "Liquid"
	_liquid.mesh = liquid_mesh()
	_liquid.material_override = _liquid_material
	_liquid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The shaders move vertices (arms reach out over the lanes): keep it from being culled.
	_liquid.extra_cull_margin = 4.0
	add_child(_liquid)
	_vapor = MeshInstance3D.new()
	_vapor.name = "Vapor"
	_vapor.mesh = vapor_mesh()
	_vapor.material_override = _vapor_material
	_vapor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_vapor.extra_cull_margin = 2.0
	add_child(_vapor)
	_drips = CPUParticles3D.new()
	_drips.name = "Drips"
	_drips.amount = 18
	_drips.lifetime = 1.0
	_drips.local_coords = true
	_drips.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_drips.emission_box_extents = Vector3(0.75, 0.55, 0.3)
	_drips.position = Vector3(0.0, 2.0, 0.1)
	_drips.direction = Vector3(0.0, -1.0, 0.0)
	_drips.spread = 25.0
	_drips.gravity = Vector3(0.0, -5.0, 0.0)
	_drips.initial_velocity_min = 0.1
	_drips.initial_velocity_max = 0.6
	_drips.scale_amount_min = 0.5
	_drips.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.1))
	_drips.scale_amount_curve = curve
	var drop := SphereMesh.new()
	drop.radius = 0.04
	drop.height = 0.1
	drop.radial_segments = 5
	drop.rings = 2
	_drips.mesh = drop
	_drips.material_override = GreyboxMaterials.glow(PURPLE, 2.2)
	_drips.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_drips)
	animate()


## Pushes this frame's animation inputs to the materials.
func animate() -> void:
	if _liquid_material == null:
		return
	for pair: Array in [[&"maw", maw], [&"raise", raise], [&"slash", slash], [&"reach", reach],
			[&"attack", attack], [&"lunge", lunge], [&"fade", fade]]:
		_liquid_material.set_shader_parameter(pair[0], pair[1])
	_vapor_material.set_shader_parameter(&"lunge", lunge)
	_vapor_material.set_shader_parameter(&"fade", fade)
	_vapor_material.set_shader_parameter(&"attack", attack)
	_drips.emitting = fade < 0.7
	_drips.speed_scale = 1.0 + attack * 1.5


static func shader(key: String) -> Shader:
	if not _shaders.has(key):
		var s := Shader.new()
		match key:
			"liquid":
				s.code = LIQUID_SHADER
			"vapor":
				s.code = VAPOR_SHADER
			"mark":
				s.code = MARK_SHADER
			"arc":
				s.code = ARC_SHADER
		_shaders[key] = s
	return _shaders[key]


## A new material for the lane marks (one Bad Dream at a time, so each gets its own).
static func mark_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader("mark")
	m.set_shader_parameter(&"color", ATTACK_RED)
	return m


static func arc_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader("arc")
	m.set_shader_parameter(&"color", ATTACK_RED)
	return m


## The lane marks for one slash, in the player's frame (x world, y up, z = 0 at the player): a strip
## along every floor lane in `floor_lanes` (Vector2(x_min, x_max) each) and a panel on the wall face
## at world x `wall_x` (0 = none) up to `wall_top`, from `behind` metres behind the player to `ahead`
## in front. UV.x runs across a strip, UV.y from the player's end (0) to the far end (1).
static func marks_mesh(floor_lanes: Array[Vector2], wall_x: float, wall_top: float, behind: float,
		ahead: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for span: Vector2 in floor_lanes:
		_quad(st, [Vector3(span.x, 0.0, behind), Vector3(span.y, 0.0, behind), Vector3(span.y, 0.0, -ahead),
			Vector3(span.x, 0.0, -ahead)], [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	if wall_x != 0.0:
		_quad(st, [Vector3(wall_x, 0.05, behind), Vector3(wall_x, wall_top, behind), Vector3(wall_x, wall_top, -ahead),
			Vector3(wall_x, 0.05, -ahead)], [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	return st.commit()


static func _quad(st: SurfaceTool, p: Array, uv: Array) -> void:
	for i: int in [0, 1, 2, 0, 2, 3]:
		st.set_normal(Vector3.UP)
		st.set_uv(uv[i])
		st.add_vertex(p[i])


## Three claw streaks, each a curved ribbon across x -0.5..0.5 (UV.x along it, UV.y across it),
## about 0.3–1.6 m up and bowed toward the player: scaled to the slash's width by the Bad Dream.
static func arc_mesh() -> ArrayMesh:
	if _arc_mesh != null:
		return _arc_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps: int = 16
	for k: int in 3:
		var y0: float = 0.55 + 0.42 * k
		for i: int in steps:
			var a: float = float(i) / steps
			var b: float = float(i + 1) / steps
			var pts: Array = []
			for u: float in [a, b]:
				var x: float = u - 0.5
				var y: float = y0 + 0.35 * sin(PI * u) - 0.25 * u
				var z: float = 0.35 * sin(PI * u)
				var half: float = 0.07 * sin(PI * clampf(u * 1.1, 0.0, 1.0)) + 0.012
				pts.append([Vector3(x, y - half, z), Vector3(x, y + half, z)])
			_quad(st, [pts[0][0], pts[1][0], pts[1][1], pts[0][1]],
				[Vector2(a, 0.0), Vector2(b, 0.0), Vector2(b, 1.0), Vector2(a, 1.0)])
	_arc_mesh = st.commit()
	return _arc_mesh


# --- The body ------------------------------------------------------------------------------------

const BLACK := Color(0.012, 0.007, 0.02, 0.0)
const SHEEN := Color(0.06, 0.018, 0.1, 0.06)
const HIGHLIGHT := Color(0.5, 0.14, 0.9, 1.0)
const BONE := Color(0.72, 0.66, 0.82, 0.12)
const CLAW := Color(0.78, 0.62, 1.0, 0.75)
const THROAT := Color(0.42, 0.04, 0.2, 1.0)
const VAPOR := Color(0.1, 0.025, 0.17, 0.85)
const SHROUD := Color(0.3, 0.08, 0.5, 0.75)


## The liquid body, built once.
static func liquid_mesh() -> ArrayMesh:
	if _liquid_mesh != null:
		return _liquid_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The bulbous head, a little sheen on its crown.
	_ellipsoid(st, HEAD_CENTER, HEAD_RADII, 10, 7, Part.HEAD, BLACK, SHEEN)
	# The maw: a glowing lip, a ring of spiked teeth pointing into it, and the throat inside.
	var m: Vector3 = MAW_CENTER + Vector3(0.0, 0.0, 0.02)
	var segs: int = 14
	for i: int in segs:
		var a0: float = TAU * i / segs
		var a1: float = TAU * (i + 1) / segs
		var d0 := Vector3(cos(a0), sin(a0), 0.0)
		var d1 := Vector3(cos(a1), sin(a1), 0.0)
		_tri(st, [m, m + d0 * MAW_RADIUS * 0.96, m + d1 * MAW_RADIUS * 0.96], [THROAT, THROAT, THROAT],
			Part.THROAT, [0.0, 1.0, 1.0], m + Vector3(0.0, 0.0, -1.0))
		var r_in: float = MAW_RADIUS
		var r_out: float = MAW_RADIUS + 0.045
		_tri(st, [m + d0 * r_in, m + d0 * r_out, m + d1 * r_out], [HIGHLIGHT, HIGHLIGHT, HIGHLIGHT], Part.TEETH,
			[0.0, 0.0, 0.0], m + Vector3(0.0, 0.0, -1.0))
		_tri(st, [m + d0 * r_in, m + d1 * r_out, m + d1 * r_in], [HIGHLIGHT, HIGHLIGHT, HIGHLIGHT], Part.TEETH,
			[0.0, 0.0, 0.0], m + Vector3(0.0, 0.0, -1.0))
	var teeth: int = 12
	for i: int in teeth:
		var a: float = TAU * (i + 0.5) / teeth
		var d := Vector3(cos(a), sin(a), 0.0)
		var tangent := Vector3(-sin(a), cos(a), 0.0)
		var base: Vector3 = m + d * MAW_RADIUS * 0.98 + Vector3(0.0, 0.0, 0.01)
		var length: float = 0.15 if i % 2 == 0 else 0.11
		var tip: Vector3 = m + d * (MAW_RADIUS - length) + Vector3(0.0, 0.0, 0.08)
		var b1: Vector3 = base - tangent * 0.05
		var b2: Vector3 = base + tangent * 0.05
		var b3: Vector3 = base - d * 0.03 + Vector3(0.0, 0.0, -0.05)
		var center: Vector3 = (b1 + b2 + b3 + tip) * 0.25
		for f: Array in [[b1, b2, tip], [b2, b3, tip], [b3, b1, tip], [b1, b3, b2]]:
			_tri(st, f, [BONE, BONE, BONE], Part.TEETH, [0.0, 0.0, 1.0], center)
	# The neck and torso, thinning into the vapour tail.
	_cone(st, Vector3(0.0, 2.36, 0.0), Vector3(0.0, 1.3, 0.03), 0.3, 0.17, 8, BLACK, BLACK, Part.TORSO, 0.0, 1.0)
	# Long arms, long fingers, slashing claws.
	for sx: float in [-1.0, 1.0]:
		var part: int = Part.ARM_L if sx < 0.0 else Part.ARM_R
		var shoulder := Vector3(sx * SHOULDER.x, SHOULDER.y, SHOULDER.z)
		var elbow := Vector3(sx * 0.78, 1.62, 0.22)
		var wrist := Vector3(sx * 0.98, 1.02, 0.36)
		_ellipsoid(st, shoulder, Vector3(0.13, 0.12, 0.13), 6, 4, part, BLACK, BLACK)
		_cone(st, shoulder, elbow, 0.085, 0.055, 6, BLACK, BLACK, part, 0.0, 0.3)
		_cone(st, elbow, wrist, 0.055, 0.04, 6, BLACK, SHEEN, part, 0.3, 0.6)
		var along: Vector3 = (wrist - elbow).normalized()
		var side: Vector3 = along.cross(Vector3(0.0, 0.0, 1.0)).normalized()
		for k: int in 4:
			var spread: float = (float(k) - 1.5) * 0.3
			var dir: Vector3 = (along + side * spread + Vector3(0.0, 0.0, 0.2)).normalized()
			var knuckle: Vector3 = wrist + side * spread * 0.08
			var tip: Vector3 = knuckle + dir * (0.44 - absf(spread) * 0.12)
			_cone(st, knuckle, tip, 0.024, 0.016, 4, BLACK, SHEEN, part, 0.6, 0.84)
			var hook: Vector3 = tip + dir * 0.2 + Vector3(0.0, 0.0, 0.13) + Vector3(-sx * 0.03, 0.0, 0.0)
			_cone(st, tip, hook, 0.026, 0.0, 4, CLAW, Color(CLAW, 1.0), part, 0.84, 1.0)
	# Liquid dripping off the head and the jaw.
	var drips: Array = [[-0.32, 0.12, 0.34], [-0.14, 0.3, 0.46], [0.12, 0.28, 0.3], [0.3, 0.1, 0.42],
		[-0.06, 0.43, 0.22], [0.07, 0.44, 0.26]]
	for d: Array in drips:
		var top := Vector3(float(d[0]), 2.36 + (0.1 if float(d[1]) > 0.4 else 0.0), float(d[1]))
		_cone(st, top, top + Vector3(0.0, -float(d[2]), 0.02), 0.035, 0.0, 4, BLACK, HIGHLIGHT, Part.DRIP, 0.0, 1.0)
	_liquid_mesh = st.commit()
	return _liquid_mesh


## The vapour: the tail and the shroud around the head, built once.
static func vapor_mesh() -> ArrayMesh:
	if _vapor_mesh != null:
		return _vapor_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = [[1.62, 0.34], [1.25, 0.31], [0.9, 0.25], [0.55, 0.17], [0.25, 0.09], [0.0, 0.02]]
	for i: int in rings.size() - 1:
		var y0: float = rings[i][0]
		var y1: float = rings[i + 1][0]
		var w0: float = 1.0 - y0 / 1.62
		var w1: float = 1.0 - y1 / 1.62
		var c0 := Color(VAPOR, VAPOR.a * (1.0 - w0 * 0.85))
		var c1 := Color(VAPOR, VAPOR.a * (1.0 - w1 * 0.85))
		_cone(st, Vector3(0.0, y0, 0.0), Vector3(0.0, y1, 0.0), float(rings[i][1]), float(rings[i + 1][1]), 8,
			c0, c1, Part.TAIL, w0, w1)
	_ellipsoid(st, HEAD_CENTER + Vector3(0.0, -0.05, -0.02), HEAD_RADII * 1.22, 10, 6, Part.SHROUD, SHROUD, SHROUD)
	_vapor_mesh = st.commit()
	return _vapor_mesh


## An ellipsoid; `top_color` shades the upper third.
static func _ellipsoid(st: SurfaceTool, center: Vector3, r: Vector3, segments: int, rings: int, part: int,
		color: Color, top_color: Color) -> void:
	var grid: Array[PackedVector3Array] = []
	for ri: int in rings + 1:
		var lat: float = PI * float(ri) / rings - PI * 0.5
		var row := PackedVector3Array()
		for s: int in segments:
			var lon: float = TAU * float(s) / segments
			row.append(center + Vector3(cos(lat) * sin(lon) * r.x, sin(lat) * r.y, cos(lat) * cos(lon) * r.z))
		grid.append(row)
	for ri: int in rings:
		for s: int in segments:
			var s1: int = (s + 1) % segments
			var quad: Array = [grid[ri][s], grid[ri][s1], grid[ri + 1][s1], grid[ri + 1][s]]
			var c: Color = top_color if (quad[2] as Vector3).y > center.y + r.y * 0.45 else color
			_tri(st, [quad[0], quad[1], quad[2]], [c, c, c], part, [0.0, 0.0, 0.0], center)
			_tri(st, [quad[0], quad[2], quad[3]], [c, c, c], part, [0.0, 0.0, 0.0], center)


## A tapered cone (a truncated one when `r1` > 0) from `a` to `b`; the weight runs w0 → w1.
static func _cone(st: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float, sides: int, c0: Color,
		c1: Color, part: int, w0: float, w1: float) -> void:
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

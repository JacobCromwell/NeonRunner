// The Chairman's train (HostileTakeoverSkin): its roofs, carriage ends and the edges at the gaps, with
// the solid kit's look and the Corporate zone's patterns (kit_corporate.gdshaderinc: the express's roof,
// the deep shade under it), and the breakaway (GDD §10: "the carriages behind break away and tumble off
// the track"): everything behind `break_z` (world z: the stomped coupling's gap, its near edge) falls
// behind, sinks and rolls over, carriage by carriage, `break_age` seconds after the stomp (the encounter
// sets both; a break_age below 0 is none). Looks only: the track's collision stays the TrackBuilder's.
// Patterns are drawn where the surface was (v_world), so they stay on a carriage as it tumbles.
//   COLOR.rgb  albedo (sRGB)   COLOR.a  glow   UV2.x pattern id (MeshKit.PAT_*), UV2.y its parameter
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, world_vertex_coords;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"
#include "res://scripts/world/meshes/shaders/kit_marks.gdshaderinc"
#include "res://scripts/world/meshes/shaders/kit_corporate.gdshaderinc"

// A level's darker lighting (ZoneSkin.apply_darkness): the lit surfaces dim, glowing ones don't.
global uniform float scenery_light;
uniform float glow_scale = 4.0;
uniform vec3 sheen_color : source_color = vec3(0.3, 0.34, 0.42);
uniform float sheen_strength = 0.2;
uniform vec3 panel_dark : source_color = vec3(0.015, 0.015, 0.03);

// The breakaway: the line (world z) behind which the carriages break away, the seconds since, the
// carriages' pitch (gap start to gap start) and roof length, and how they go.
uniform float break_z = 1.0e9;
uniform float break_age = -1.0;
uniform float break_pitch = 56.0;
uniform float break_roof = 50.0;
uniform float break_recede = 9.0;
uniform float break_drop = 5.0;
uniform float break_roll = 1.2;
uniform float break_half_width = 4.0;

varying vec3 v_world;

mat3 rotation_x(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, c, s), vec3(0.0, -s, c));
}

mat3 rotation_y(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(c, 0.0, -s), vec3(0.0, 1.0, 0.0), vec3(s, 0.0, c));
}

mat3 rotation_z(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(c, s, 0.0), vec3(-s, c, 0.0), vec3(0.0, 0.0, 1.0));
}

void vertex() {
	v_world = VERTEX;
	if (break_age > 0.0 && VERTEX.z > break_z - 0.05) {
		// Carriage k behind the break (0: the one the coupling held), each a moment after the one before.
		float k = floor((VERTEX.z - break_z + 0.05) / break_pitch);
		float a = max(break_age - k * 0.14, 0.0);
		float side = hash11(k * 7.13 + 1.7) < 0.5 ? -1.0 : 1.0;
		// Turns ease off: a carriage tips its nose down and rolls over onto its side, no further.
		// (A negative turn about z swings the top toward +x: it tips over its edge on that side.)
		float roll = -side * min(break_roll * a * a, 1.7);
		float nose = -min(0.35 * a * a, 0.45);
		float yaw = side * min(0.12 * a * a, 0.35);
		// It turns about its rear end, low in its body, on the side it falls to.
		vec3 pivot = vec3(side * break_half_width * 0.6, -2.0, break_z + k * break_pitch + break_roof);
		vec3 p = rotation_y(yaw) * rotation_z(roll) * rotation_x(nose) * (VERTEX - pivot) + pivot;
		p.z += 0.5 * break_recede * a * a;
		p.y -= 0.5 * break_drop * a * a;
		p.x += side * 0.6 * a * a;
		VERTEX = p;
	}
}

void fragment() {
	vec3 nv = flat_view_normal(VERTEX);
	vec3 n = (INV_VIEW_MATRIX * vec4(nv, 0.0)).xyz;
	vec3 base = COLOR.rgb;
	float glow = COLOR.a;
	int pattern = int(UV2.x + 0.5);
	if (pattern >= 30 && pattern < 40) {
		base = corp_surface(pattern, UV2.y, base, v_world, n, UV, TIME, panel_dark, glow);
	}
	vec3 col;
	if (glow > 0.002) {
		col = to_linear(base) * glow * glow_scale;
	} else {
		// The kit's fake city light (kit_solid.gdshader): tops catch the sky glow, sides the street.
		float shade = 0.62 + 0.3 * max(n.y, 0.0) + 0.08 * abs(n.x) + 0.06 * n.z - 0.04 * max(-n.y, 0.0);
		float f = 1.0 - clamp(dot(nv, VIEW), 0.0, 1.0);
		vec3 sheen = to_linear(sheen_color) * (f * f * f * sheen_strength);
		col = (to_linear(base) * shade + sheen) * light_factor(scenery_light);
	}
	ALBEDO = col;
}

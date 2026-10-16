// The City intro's pedestrians (CityIntroCrowd): a few hundred low-poly people walking the sidewalks, all drawn from one
// MultiMesh and moved by this shader alone, so a frame costs the CPU one uniform (`u_time`, the cinematic's clock).
//   per instance  its transform (where it starts and which way it faces: local +z is the way it walks),
//                 INSTANCE_CUSTOM = (look seed, gait phase 0-1, speed along world z in m/s (its sign the way it walks), size)
//   per vertex    COLOR.r = the part (x10): 0 torso, 1 left leg, 2 right leg, 3 left arm, 4 right arm, 5 head, 6 hair,
//                 7 a shoulder strip of neon trim
// The walk cycle swings the legs and arms about the hip and shoulder and bobs the body; a person that walks out of the
// loop's end comes back in at its other. Unshaded with the kit's fake city light (the same on every renderer); its colours
// are plain clothes in muted tones and skin, never a hazard's hue, never the cold white of a cyborg's screen.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"

uniform float u_time = 0.0;
// The loop's extent along world z (the lowest z and its length).
uniform float loop_low = -210.0;
uniform float loop_length = 320.0;
// Neon trim on the shoulders (some people): violet, blue or pale; its glow.
uniform float trim_glow = 1.6;

varying float v_part;
varying float v_seed;

vec3 jacket(int i) {
	if (i == 0) return vec3(0.16, 0.18, 0.3);
	if (i == 1) return vec3(0.36, 0.22, 0.4);
	if (i == 2) return vec3(0.62, 0.6, 0.56);
	if (i == 3) return vec3(0.12, 0.12, 0.16);
	if (i == 4) return vec3(0.5, 0.42, 0.32);
	if (i == 5) return vec3(0.24, 0.34, 0.46);
	if (i == 6) return vec3(0.46, 0.34, 0.26);
	return vec3(0.7, 0.7, 0.76);
}

vec3 trousers(int i) {
	if (i == 0) return vec3(0.07, 0.07, 0.11);
	if (i == 1) return vec3(0.14, 0.15, 0.22);
	if (i == 2) return vec3(0.2, 0.2, 0.24);
	if (i == 3) return vec3(0.1, 0.12, 0.18);
	return vec3(0.26, 0.24, 0.22);
}

vec3 skin(int i) {
	if (i == 0) return vec3(0.78, 0.58, 0.46);
	if (i == 1) return vec3(0.6, 0.42, 0.32);
	if (i == 2) return vec3(0.42, 0.29, 0.22);
	if (i == 3) return vec3(0.88, 0.7, 0.58);
	return vec3(0.32, 0.22, 0.17);
}

vec3 hair(int i) {
	if (i == 0) return vec3(0.07, 0.06, 0.05);
	if (i == 1) return vec3(0.2, 0.14, 0.1);
	if (i == 2) return vec3(0.46, 0.46, 0.5);
	if (i == 3) return vec3(0.3, 0.16, 0.1);
	return vec3(0.12, 0.1, 0.1);
}

// Neon trim colours: the City's violet, blue and a pale blue-white.
vec3 trim(int i) {
	if (i == 0) return vec3(0.62, 0.45, 1.0);
	if (i == 1) return vec3(0.35, 0.55, 1.0);
	return vec3(0.8, 0.85, 1.0);
}

float h(float x, float k) {
	return fract(sin(x * 12.9898 + k * 78.233) * 43758.5453);
}

void vertex() {
	vec4 cd = INSTANCE_CUSTOM;
	v_part = floor(COLOR.r * 10.0 + 0.5);
	v_seed = cd.x;
	vec3 p = VERTEX;
	float speed = abs(cd.z);
	float phase = cd.y * 6.2832 + u_time * speed * 4.3;
	float swing = sin(phase);
	// Legs swing about the hip, arms (the other way) about the shoulder.
	float a = 0.0;
	float pivot = 0.0;
	if (v_part == 1.0 || v_part == 2.0) {
		a = swing * 0.5 * (v_part == 1.0 ? 1.0 : -1.0);
		pivot = 0.8;
	} else if (v_part == 3.0 || v_part == 4.0) {
		a = swing * 0.42 * (v_part == 3.0 ? -1.0 : 1.0);
		pivot = 1.4;
	}
	if (pivot > 0.0) {
		float dy = p.y - pivot;
		float c = cos(a);
		float s = sin(a);
		p.y = pivot + dy * c - p.z * s;
		p.z = dy * s + p.z * c;
	}
	p.y += 0.022 * abs(swing);
	p *= cd.w;
	// Walks along world z, wrapping round the loop; local +z is the way it faces.
	float z0 = MODEL_MATRIX[3].z;
	float z = loop_low + mod(z0 - loop_low + cd.z * u_time, loop_length);
	float facing = MODEL_MATRIX[2].z >= 0.0 ? 1.0 : -1.0;
	p.z += (z - z0) * facing;
	VERTEX = p;
}

void fragment() {
	int part = int(v_part + 0.5);
	float s = v_seed;
	vec3 col;
	float glow = 0.0;
	if (part == 1 || part == 2) {
		col = trousers(int(h(s, 3.0) * 5.0));
	} else if (part == 5) {
		col = skin(int(h(s, 4.0) * 5.0));
	} else if (part == 6) {
		col = hair(int(h(s, 5.0) * 5.0));
	} else if (part == 7) {
		float on = step(0.5, h(s, 6.0));
		col = mix(jacket(int(h(s, 1.0) * 8.0)), trim(int(h(s, 7.0) * 3.0)), on);
		glow = on * trim_glow;
	} else {
		col = jacket(int(h(s, 1.0) * 8.0));
	}
	vec3 nv = flat_view_normal(VERTEX);
	vec3 n = (INV_VIEW_MATRIX * vec4(nv, 0.0)).xyz;
	float shade = 0.7 + 0.25 * max(n.y, 0.0) + 0.08 * abs(n.x) + 0.06 * n.z;
	ALBEDO = to_linear(col) * (glow > 0.0 ? glow : shade);
}

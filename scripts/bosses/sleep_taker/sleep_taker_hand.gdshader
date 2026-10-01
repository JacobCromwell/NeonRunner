// A grasping hand of the Sleep Taker's (SleepTakerHands): black liquid with purple highlights, rising out
// of the purple mist in a lane and closing its long clawed fingers. Its claws heat up to enemy-attack
// red as it bursts up (the attack). UV.x the part (0 forearm, 1 palm, 2 a finger) plus the finger's id
// (fraction * 64); UV.y the weight along a finger (0 at its knuckle, 1 at its claw's tip). The hand
// faces +Z, toward the runner, its knuckles KNUCKLE_Y up.
shader_type spatial;
render_mode cull_disabled;
#include "res://scripts/world/meshes/shaders/kit_flash.gdshaderinc"

uniform float rise = 0.0;    // 0 = sunk below the street, 1 = up
uniform float grasp = 0.0;   // 0 = fingers spread, 1 = closed
uniform float attack = 0.0;  // the claws heat up to enemy-attack red
uniform float fade = 0.0;    // 0 = solid, 1 = gone
uniform float depth = 3.8;   // how far below the street it waits
uniform float seed = 0.0;
uniform vec4 rim_color : source_color = vec4(0.58, 0.28, 1.0, 1.0);
uniform vec4 attack_color : source_color = vec4(1.0, 0.12, 0.08, 1.0);
uniform float rim_energy = 2.0;
uniform float glow_energy = 2.8;

const float KNUCKLE_Y = 1.9;

varying vec3 v_rest;
varying float v_hot;

vec3 rot_x(vec3 p, float a) { return vec3(p.x, p.y * cos(a) - p.z * sin(a), p.y * sin(a) + p.z * cos(a)); }
float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }

void vertex() {
	float part = floor(UV.x + 0.5);
	float id = floor((UV.x - part) * 64.0 + 0.5);
	float w = UV.y;
	float t = TIME + seed * 3.7;
	vec3 v = VERTEX;
	v_rest = v;
	v_hot = 0.0;
	v += vec3(sin(t * 2.3 + v.y * 2.1), 0.0, cos(t * 2.0 + v.y * 1.7)) * 0.03;
	if (part > 1.5) {
		// The fingers curl forward about the knuckles as it grasps, each a little out of step.
		float a = (grasp * 1.25 + 0.08 * sin(t * 3.0 + id)) * w;
		vec3 pivot = vec3(v.x, KNUCKLE_Y, 0.05);
		v = pivot + rot_x(v - pivot, a);
		v_hot = smoothstep(0.78, 0.9, w);
	}
	v.y -= (1.0 - rise) * depth;
	v.y -= fade * fade * 1.5;
	VERTEX = v;
}

void fragment() {
	float n = hash(floor(v_rest * 6.0) + vec3(seed));
	if (n < fade * 1.2 - 0.1) {
		discard;
	}
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	vec3 glow = mix(COLOR.rgb, attack_color.rgb, clamp(attack * v_hot * 1.3, 0.0, 1.0));
	ALBEDO = COLOR.rgb * 0.3;
	ROUGHNESS = 0.12;
	SPECULAR = 0.85;
	EMISSION = rim_color.rgb * rim * rim_energy + glow * COLOR.a * glow_energy * (1.0 + attack * v_hot * 1.5);
}

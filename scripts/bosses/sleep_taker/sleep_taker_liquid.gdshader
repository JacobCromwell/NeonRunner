// The Sleep Taker's liquid body (SleepTakerModel): its fused heads with their maws, the torso, the
// arms with their long clawed fingers, the tendrils and the drips. Black with purple highlights like
// the Bad Dream (BadDreamModel's liquid shader, grown); only an attack heats up to enemy-attack red
// (the great maw's throat and the claws, while it shrieks and slashes). Animated in the vertex stage
// from plain uniforms, so the whole body is one draw call on every renderer.
// Vertex data (SleepTakerModel): COLOR.rgb albedo, COLOR.a glow; UV.x the part (Part, rounded) plus a
// small id (its fraction * 64, for each maw's own breathing); UV.y the weight along a part (0 at its
// root, 1 at its tip; 2 marks a maw's throat); UV2 a maw vertex's offset from its maw's centre (the
// maws face +Z).
shader_type spatial;
render_mode cull_disabled;
#include "res://scripts/world/meshes/shaders/kit_flash.gdshaderinc"

uniform float shriek = 0.0;    // the great maw opening (the slash's warning)
uniform float maws = 0.35;     // the other maws' opening, each breathing in its own time
uniform float inhale = 0.0;    // lights out's warning: every maw wide, the body swelling
uniform float swallowed = 0.0; // the light it has swallowed, glowing in its throats
uniform float raise = 0.0;     // arms lifted out over the lanes it will slash
uniform float slash = 0.0;     // arms sweeping down and across
uniform float reach = 1.0;     // arm stretch (1 = rest length)
uniform float attack = 0.0;    // the great maw's throat and the claws heat up to enemy-attack red
uniform float lunge = 0.0;     // the upper body thrusts toward the runner
uniform float fade = 0.0;      // 0 = solid, 1 = gone (it materializes through it too)
uniform float seed = 0.0;
uniform vec4 rim_color : source_color = vec4(0.58, 0.28, 1.0, 1.0);
uniform vec4 attack_color : source_color = vec4(1.0, 0.12, 0.08, 1.0);
uniform float rim_energy = 1.3;
uniform float glow_energy = 2.6;

// Part ids (SleepTakerModel.Part).
const float HEAD = 0.0;
const float BIG_MAW = 1.0;
const float MAW = 2.0;
const float TORSO = 3.0;
const float ARM_L = 4.0;
const float ARM_R = 5.0;
const float TENDRIL = 6.0;
const float DRIP = 7.0;
// Where the arms hang from (the right shoulder; the left mirrors it), and the heads' middle.
const vec3 SHOULDER = vec3(4.9, 11.0, 0.4);
const vec3 CLUSTER = vec3(0.0, 13.0, 0.0);

varying vec3 v_rest;
varying float v_hot;
varying float v_throat;
varying float v_open;

vec3 rot_x(vec3 p, float a) { return vec3(p.x, p.y * cos(a) - p.z * sin(a), p.y * sin(a) + p.z * cos(a)); }
vec3 rot_y(vec3 p, float a) { return vec3(p.x * cos(a) + p.z * sin(a), p.y, -p.x * sin(a) + p.z * cos(a)); }
vec3 rot_z(vec3 p, float a) { return vec3(p.x * cos(a) - p.y * sin(a), p.x * sin(a) + p.y * cos(a), p.z); }
float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }

void vertex() {
	float part = floor(UV.x + 0.5);
	float id = floor((UV.x - part) * 64.0 + 0.5);
	float w = UV.y;
	float t = TIME + seed * 7.3;
	vec3 v = VERTEX;
	v_rest = v;
	v_hot = 0.0;
	v_throat = 0.0;
	v_open = 0.0;
	// A slow liquid wobble over the whole body.
	v += vec3(sin(t * 1.3 + v.y * 0.9), 0.5 * sin(t * 1.1 + v.x * 1.2), cos(t * 1.2 + v.y * 0.8)) * 0.07;
	if (part < 3.5) {
		// The heads and the torso swell as it inhales.
		v += (v - CLUSTER) * 0.06 * inhale;
	}
	if (part > 0.5 && part < 2.5) {
		// A maw: its teeth, lip and throat open around its centre. The great one opens with its shriek;
		// the others breathe, each in its own time, and all gape as it inhales.
		float throat = w > 1.5 ? 1.0 : 0.0;
		float open;
		if (part < 1.5) {
			open = max(shriek, inhale * 0.85);
			v_hot = throat;
		} else {
			float breath = 0.5 + 0.5 * sin(t * (0.9 + 0.05 * id) + id * 2.3);
			open = clamp(maws * (0.55 + 0.45 * breath) + inhale, 0.0, 1.0);
		}
		v_open = open;
		v_throat = throat;
		// It opens around its centre; the teeth's tips pull back toward the lip and splay forward, so
		// the lit throat shows.
		float tip = w * (1.0 - throat);
		v.xy += UV2 * (mix(0.45, 1.28, open) * (1.0 + open * tip) - 1.0);
		v.z += open * 0.25 * tip;
	} else if (part > 3.5 && part < 5.5) {
		float sx = part < 4.5 ? -1.0 : 1.0;
		vec3 pivot = vec3(sx * SHOULDER.x, SHOULDER.y, SHOULDER.z);
		vec3 p = v - pivot;
		p *= mix(1.0, reach, smoothstep(0.15, 1.0, w));
		p = rot_z(p, sx * 0.06 * sin(t * 0.9 + sx) * (1.0 - raise));
		p = rot_x(p, 0.05 * sin(t * 0.7 + sx * 2.0));
		// Raise: lifted out over the lanes, claws tipped toward the runner.
		p = rot_z(p, sx * 0.75 * raise);
		p = rot_x(p, -0.55 * raise);
		// Slash: down and across in front of it.
		p = rot_z(p, -sx * 1.15 * slash);
		p = rot_y(p, -sx * 0.85 * slash);
		v = pivot + p;
		v_hot = smoothstep(0.8, 0.85, w);
	} else if (part > 5.5 && part < 6.5) {
		// The tendrils' long fingers sway and curl in as it inhales.
		v.x += sin(t * 1.4 + id * 1.7) * 0.3 * w * w;
		v.z += (cos(t * 1.1 + id) * 0.25 + 0.6 * inhale) * w * w;
		v.y += 0.5 * inhale * w * w;
		v_hot = smoothstep(0.82, 0.9, w) * 0.6;
	} else if (part > 6.5) {
		// Drips stretch and swing.
		v.y -= w * (0.15 + 0.15 * sin(t * 2.2 + v_rest.x * 3.0));
		v.x += w * 0.08 * sin(t * 1.8 + v_rest.z * 4.0);
	}
	// The lunge thrusts its heads and shoulders at the runner.
	v.z += lunge * 1.8 * smoothstep(4.0, 12.0, v_rest.y);
	// Dissolving (or materializing), it melts and drips away.
	v.y -= fade * fade * (1.2 + 0.8 * sin(v_rest.x * 3.0 + seed));
	VERTEX = v;
}

void fragment() {
	// Dissolve (and materialize): cells of the surface vanish at random, the bottom first.
	float n = hash(floor(v_rest * 3.0) + vec3(seed));
	if (n < fade * 1.25 - 0.12 + (1.0 - clamp(v_rest.y / 20.0, 0.0, 1.0)) * fade * 0.3) {
		discard;
	}
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.6);
	// A rare glitch in its glow; none with Reduced flashing.
	float glitch = (1.0 - reduced_flashing) * step(0.95, hash(vec3(floor(TIME * 11.0), seed, 1.0)));
	vec3 glow = mix(COLOR.rgb, attack_color.rgb, clamp(attack * v_hot * 1.3, 0.0, 1.0));
	// A throat lights up as its maw opens, and glows with the light it has swallowed.
	float lit = clamp(0.2 + v_open, 0.0, 1.0) * (1.0 + 0.8 * swallowed);
	glow *= mix(1.0, lit, v_throat);
	// The hot parts (its throat, its claws) lose their pale sheen, so they read red, not pink.
	float hot = attack * v_hot;
	ALBEDO = mix(COLOR.rgb * 0.3, vec3(0.05, 0.0, 0.0), hot);
	ROUGHNESS = 0.12;
	SPECULAR = mix(0.85, 0.2, hot);
	vec3 e = rim_color.rgb * rim * rim_energy * (1.0 - 0.6 * glitch) * (1.0 - attack * v_hot)
		+ glow * COLOR.a * glow_energy * (1.0 + attack * v_hot * (0.3 - 0.7 * v_throat));
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	// No tonemapping here: over-bright, its purple would clip toward the fences' pink and its red claws
	// and throat toward salmon. Scaled down whole instead, each keeps its hue.
	e /= max(1.0, max(e.r, max(e.g, e.b)));
#endif
	EMISSION = e;
}

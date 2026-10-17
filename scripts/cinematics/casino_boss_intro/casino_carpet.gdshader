// The casino hall's carpet (CasinoHall; the Casino boss intro): a deep burgundy carpet woven with a lattice of thin
// gold lines, a small medallion where they cross and a darker border band round the hall, in world metres so it
// tiles across the floor. Unshaded and lit by the kit's fake light like the hall's other surfaces (scenery_light,
// scenery_tint), so it costs the same on every renderer. Never glowing.
shader_type spatial;
render_mode unshaded, cull_back;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"

global uniform float scenery_light;
global uniform vec3 scenery_tint;

uniform vec3 base : source_color = vec3(0.3, 0.06, 0.09);
uniform vec3 dark : source_color = vec3(0.17, 0.035, 0.055);
uniform vec3 gold : source_color = vec3(0.62, 0.47, 0.22);
// The lattice's cell (metres) and the border band's width; the hall's floor (world x and z ranges).
uniform float cell = 1.6;
uniform float border = 1.4;
uniform vec4 bounds = vec4(-17.0, 17.0, -40.0, 0.0);
// How much brighter the floor is under the chandeliers' pools (xz world, radius in w).
uniform vec4 pool_a = vec4(0.0, 0.0, 0.0, 0.0);
uniform vec4 pool_b = vec4(0.0, 0.0, 0.0, 0.0);
uniform vec4 pool_c = vec4(0.0, 0.0, 0.0, 0.0);
uniform float pool_strength = 0.35;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float line(float v, float w) {
	float aa = max(fwidth(v), 0.0005);
	return 1.0 - smoothstep(w - aa, w + aa, abs(v));
}

float pool(vec4 p) {
	if (p.w <= 0.0) {
		return 0.0;
	}
	float d = length(world_pos.xz - p.xy) / p.w;
	return max(1.0 - d * d, 0.0);
}

void fragment() {
	vec2 w = world_pos.xz;
	// A diamond lattice: two families of diagonal lines.
	vec2 q = vec2(w.x + w.y, w.x - w.y) / (cell * 1.41421);
	vec2 f = fract(q) - 0.5;
	float lat = max(line(f.x, 0.012), line(f.y, 0.012));
	// A medallion where they cross, and a softer diamond in each cell's middle.
	vec2 g = abs(f);
	float medal = 1.0 - smoothstep(0.07, 0.085, length(vec2(0.5) - g));
	float inner = 1.0 - smoothstep(0.09, 0.105, g.x + g.y);
	vec3 col = to_linear(base);
	col = mix(col, to_linear(dark), inner * 0.6);
	// The border band round the hall: darker, edged with a double gold line.
	float e = min(min(w.x - bounds.x, bounds.y - w.x), min(w.y - bounds.z, bounds.w - w.y));
	float band = 1.0 - smoothstep(border - 0.02, border, e);
	col = mix(col, to_linear(dark), band);
	float edge = max(line(e - border, 0.035), line(e - border + 0.18, 0.018));
	col = mix(col, to_linear(gold), max(lat * (1.0 - band) * 0.85, max(medal * (1.0 - band), edge)));
	// The weave: a faint mottle.
	col *= 0.94 + 0.06 * hash12(floor(w * 24.0));
	float light = 0.62 + pool_strength * (pool(pool_a) + pool(pool_b) + pool(pool_c));
	ALBEDO = col * light * light_factor(scenery_light) * scenery_tint;
}

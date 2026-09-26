// The electric fence's energy field: pink crackle, the same in every zone (GDD §5, §9.1).
// Cards from MeshKit.energy_field_mesh(): UV.x runs across the field, UV.y from bottom to top,
// UV2.y is a per-card seed. One material per hazard state (see HazardStateVisual):
// ON crackles at full strength, WARNING sputters, OFF is dark.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"
#include "res://scripts/world/meshes/shaders/kit_flash.gdshaderinc"

uniform vec3 color : source_color = vec3(1.0, 0.18, 0.62);
uniform float intensity = 1.0;
uniform float flicker_hz = 0.0;
uniform float glow_scale = 1.4;
uniform float fade_begin = 70.0;
uniform float fade_end = 210.0;

float noise1(float x) {
	float i = floor(x);
	float f = fract(x);
	return mix(hash11(i), hash11(i + 1.0), f * f * (3.0 - 2.0 * f));
}

void fragment() {
	vec2 uv = UV;
	// Rounded: hashes would amplify interpolation noise in the per-card seed.
	float seed = floor(dot(NODE_POSITION_WORLD, vec3(1.37, 3.11, 0.71)) * 10.0) * 0.1 + floor(UV2.y + 0.5) * 19.3;
	// The arcs jump to new shapes 14 times a second: crackle, not smooth waves (4 with Reduced
	// flashing).
	float t = floor(TIME * mix(14.0, 4.0, reduced_flashing));
	float arcs = 0.0;
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float n = noise1(uv.x * 7.0 + t * 1.7 + fi * 11.3 + seed) - 0.5;
		n += (noise1(uv.x * 23.0 + t * 3.1 + fi * 5.7 + seed) - 0.5) * 0.45;
		float d = abs(uv.y - ((fi + 0.5) / 3.0 + n * 0.38));
		float w = 0.035 + 0.025 * hash11(t + fi * 3.0 + seed);
		arcs += (1.0 - smoothstep(0.0, w, d)) * 1.3 + (1.0 - smoothstep(0.0, w * 4.0, d)) * 0.2;
	}
	// Bright boundaries at the top and bottom: the lines you jump over or slide under.
	float edge = (1.0 - smoothstep(0.0, 0.06, uv.y)) + (1.0 - smoothstep(0.0, 0.06, 1.0 - uv.y));
	float fill = 0.05 + 0.03 * sin(TIME * mix(31.0, 8.0, reduced_flashing) + uv.x * 17.0 + seed);
	float sides = smoothstep(0.0, 0.03, uv.x) * smoothstep(0.0, 0.03, 1.0 - uv.x);
	float k = intensity;
	if (flicker_hz > 0.0) {
		k *= warning_flicker(step(0.45, hash11(floor(TIME * flicker_hz) + seed)), 0.1);
	}
	float fade = 1.0 - smoothstep(fade_begin, fade_end, length(VERTEX));
	ALBEDO = to_linear(color) * ((arcs + edge * 0.7 + fill) * sides * k * glow_scale * fade);
}

// The casino's holographic games (CasinoHolo; the Casino boss intro: "a few holographic games that do not yet exist in
// the real world"): additive light, brightest along each piece's edges (UV 0-1 over each face) with faint faces, soft
// scanlines drifting up and a slow shimmer, all on the cinematic's clock (`clock`), never flickering or flashing.
// Their colours keep to the Casino's sign colours (violet, blue, warm and cold white), never a hazard's hue
// (GDD §5's colour rule).
//   COLOR.rgb  the light (sRGB)   COLOR.a  strength   UV  0-1 over a face (edges at 0 and 1)
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"

uniform float clock = 0.0;
uniform float energy = 1.6;
// How bright the faces are against the edges.
uniform float face = 0.16;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 e = min(UV, vec2(1.0) - UV);
	float d = min(e.x, e.y);
	float aa = max(fwidth(d), 0.002);
	float edge = 1.0 - smoothstep(0.02, 0.02 + aa * 2.0, d);
	float glow_in = exp(-d * 9.0);
	float scan = 0.75 + 0.25 * sin((world_pos.y * 9.0 - clock * 1.3) * 6.2832);
	float shimmer = 0.9 + 0.1 * sin(clock * 2.1 + world_pos.x * 3.0 + world_pos.z * 2.0);
	float a = (edge + glow_in * 0.35 + face) * scan * shimmer * COLOR.a;
	ALBEDO = to_linear(COLOR.rgb) * a * energy;
}

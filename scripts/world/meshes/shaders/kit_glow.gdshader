// Additive glow cards: halos, headlight beams, light columns, streaks (MeshLayer data).
//   COLOR.rgb  colour (sRGB)   COLOR.a  strength   UV 0-1 over the card   UV2.x shape (MeshKit.SHAPE_*)
// Fog would brighten additive cards toward the fog colour, so they fade out with distance here instead.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"

uniform float glow_scale = 2.0;
uniform float fade_begin = 40.0;
uniform float fade_end = 190.0;
// Hazard states: glow multiplier, and a flicker rate for WARNING.
uniform float state_glow = 1.0;
uniform float flicker_hz = 0.0;

void fragment() {
	int shape = int(UV2.x + 0.5);
	vec2 uv = UV;
	float a;
	if (shape == 1) {
		// RADIAL halo.
		float r = max(1.0 - length(uv * 2.0 - 1.0), 0.0);
		a = r * r * (0.5 + 0.5 * r);
	} else if (shape == 2) {
		// BEAM: bright at v = 0, fading along the card, soft sides.
		float v = 1.0 - uv.y;
		a = v * v * smoothstep(0.0, 0.4, uv.x) * smoothstep(1.0, 0.6, uv.x);
	} else if (shape == 3) {
		// RISE: a light column, bright at the base, bands drifting up.
		float band = 0.55 + 0.45 * sin((uv.y * 4.0 - TIME * 0.9 + UV2.y) * 6.2832);
		a = pow(1.0 - uv.y, 1.3) * band * smoothstep(0.0, 0.3, uv.x) * smoothstep(1.0, 0.7, uv.x);
	} else if (shape == 4) {
		// STREAK: a soft horizontal line.
		float cy = abs(uv.y - 0.5) * 2.0;
		a = (1.0 - cy) * (1.0 - cy) * smoothstep(0.0, 0.25, uv.x) * smoothstep(1.0, 0.6, uv.x);
	} else {
		// FLAT with soft edges.
		vec2 e = min(uv, 1.0 - uv);
		a = smoothstep(0.0, 0.2, e.x) * smoothstep(0.0, 0.2, e.y);
	}
	float g = glow_scale * state_glow;
	if (flicker_hz > 0.0) {
		g *= step(0.5, fract(TIME * flicker_hz));
	}
	float fade = 1.0 - smoothstep(fade_begin, fade_end, length(VERTEX));
	ALBEDO = to_linear(COLOR.rgb) * (COLOR.a * a * g * fade);
}

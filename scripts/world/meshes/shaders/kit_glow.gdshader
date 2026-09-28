// Additive glow cards: halos, headlight beams, light columns, streaks (MeshLayer data).
//   COLOR.rgb  colour (sRGB)   COLOR.a  strength   UV 0-1 over the card   UV2.x shape (MeshKit.SHAPE_*)
//   UV2.y      RISE: the bands' phase; below 0, on any shape: the card fades out within -UV2.y metres of
//              the camera (MeshKit.near_fade; a card the camera passes close to, such as a ceiling's end
//              glow, never fills the screen)
// Fog would brighten additive cards toward the fog colour, so they fade out with distance here instead.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"
#include "res://scripts/world/meshes/shaders/kit_flash.gdshaderinc"

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
		// RISE: a light column, bright at the base, soft bands drifting up.
		float band = 0.8 + 0.2 * sin((uv.y * 3.0 - TIME * 0.9 + UV2.y) * 6.2832);
		float across = 1.0 - abs(uv.x * 2.0 - 1.0);
		// The base clamped: at the card's top edge the interpolated uv.y can land a hair above 1, and
		// pow() of a negative number is NaN, which the glow pass blew up into a white disc (seen from
		// beside a narrow ceiling, where the top of a pad's light column shows).
		a = pow(max(1.0 - uv.y, 0.0), 1.6) * band * across * across;
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
		g *= warning_flicker(step(0.5, fract(TIME * flicker_hz)), 0.0);
	}
	float fade = 1.0 - smoothstep(fade_begin, fade_end, length(VERTEX));
	float near = max(-UV2.y, 0.0);
	if (near > 0.0) {
		fade *= smoothstep(near * 0.4, near, length(VERTEX));
	}
	ALBEDO = to_linear(COLOR.rgb) * (COLOR.a * a * g * fade);
}

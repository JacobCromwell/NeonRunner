// The Refill Ship's chain reaction's fire and smoke (GoldenConvergenceBlast; E5d polish: the owner asked for the
// ship to "go spinning off to the side and exploding, and the missiles should all explode", and added light read
// as a washed-out peach over the Grand Court's bright marble and sky): a puff is a sphere of a MultiMesh, its
// instance colour the puff's colour now (sRGB) and alpha, its custom data's x how hot its heart still is.
// Laid over what's behind it (blended, never added), so the fire reads a saturated orange-red and the smoke dark on
// any background, on every renderer: a soft ball, solid in the middle, its rim fading, its heart a hot yellow
// while it's young (the blast's flash: the part keeps it soft with Reduced flashing). Nothing flickers. On
// Forward+ and Mobile `energy` lifts the fire a little into the glow; the Compatibility renderer has no
// tonemapping, so there an over-bright colour is scaled down whole rather than clipped channel by channel (which
// would turn the orange toward that peach).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"

// Authored in sRGB, like the instance colours (to_linear converts where the renderer works in linear space).
uniform vec3 hot_color = vec3(1.0, 0.86, 0.5);
uniform float energy = 1.0;
// How soft its rim is (the share of the ball, from the rim in, its alpha takes to come up), and the colour its
// rim is darkened by (the fire's deepens to a darker red there, so a fireball reads round, not a flat disc).
uniform float softness = 0.6;
uniform vec3 rim_tint = vec3(1.0);

varying float heat;

void vertex() {
	heat = INSTANCE_CUSTOM.x;
}

void fragment() {
	// 1 where the ball faces the camera, 0 at its rim.
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	vec3 col = mix(COLOR.rgb * rim_tint, COLOR.rgb, smoothstep(0.0, 0.65, facing));
	col = mix(col, hot_color, clamp(heat, 0.0, 1.0) * smoothstep(0.35, 1.0, facing));
	vec3 lit = to_linear(col) * energy;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	float top = max(lit.r, max(lit.g, lit.b));
	if (top > 1.0) {
		lit /= top;
	}
#endif
	ALBEDO = lit;
	ALPHA = clamp(COLOR.a * smoothstep(0.0, softness, facing), 0.0, 1.0);
}

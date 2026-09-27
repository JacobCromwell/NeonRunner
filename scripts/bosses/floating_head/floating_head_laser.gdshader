// The Floating Head's eye lasers (GDD §10, proposed: "the eyes glow and whine, then twin beams sweep
// across the lanes"): FloatingHeadFaceOff sets the strength (a thin, dim aiming beam while the eyes
// charge, the full beam when it fires) and the colour (enemy-attack red, the same in every zone).
//   shape 0, a beam: an open cylinder, UV.x around it, UV.y 0 at the eye and 1 at its far end; a hot
//            pale core inside a red glow, fading out at the far end.
//   shape 1, the burning line a dragged beam leaves on the floor: a flat strip, UV.x across it, UV.y
//            along it (0 at the end nearest the runner); a red glow with a hot core line and embers,
//            the embers holding still with Reduced flashing.
//   shape 2, a sweep's aiming line across the street: a thin tube like a beam's, even along its length.
// Additive and unshaded, so it works the same on Forward+, Mobile and Compatibility (lifted there to
// read as brightly); it fades out far away itself, since fog would brighten an additive surface.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"
#include "res://scripts/world/meshes/shaders/kit_flash.gdshaderinc"

uniform vec3 laser_color : source_color = vec3(1.0, 0.12, 0.08);
uniform vec3 core_color : source_color = vec3(1.0, 0.82, 0.78);
uniform float strength = 1.0;
uniform int shape = 0;
// How much of the beam's glow is its pale core (0 while it only aims).
uniform float core = 1.0;
uniform float fade_begin = 90.0;
uniform float fade_end = 320.0;

void fragment() {
	float still = 1.0 - reduced_flashing;
	vec3 col;
	float a;
	if (shape == 0) {
		// Brightest along the beam's middle as seen from here, a pale core inside the red.
		float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
		float c = pow(facing, 6.0);
		a = pow(facing, 1.5) * (1.0 - smoothstep(0.85, 1.0, UV.y));
		col = mix(laser_color, core_color, c * core);
		a *= 1.0 + 1.5 * c * core;
	} else if (shape == 1) {
		float across = abs(UV.x * 2.0 - 1.0);
		float line = exp(-across * across * 30.0);
		float glow = 1.0 - smoothstep(0.2, 1.0, across);
		float ember = hash12(floor(vec2(UV.x * 6.0, UV.y * 18.0 + floor(TIME * 9.0) * still)));
		a = glow * (0.45 + 0.35 * ember) + line * 1.2;
		col = mix(laser_color, core_color, line * 0.6);
	} else {
		float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
		a = pow(facing, 1.5);
		col = laser_color;
	}
	float fade = 1.0 - smoothstep(fade_begin, fade_end, length(VERTEX));
	float k = max(a * strength * fade, 0.0);
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	// Compatibility adds light in sRGB space, where faint additive light reads far dimmer than on
	// Forward+: lift it so the attack reads as brightly.
	k = pow(k, 0.4545);
#endif
	ALBEDO = to_linear(col) * k;
}

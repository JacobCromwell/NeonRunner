// The Floating Head's searchlight (GDD §10: it sweeps the lanes and the bombs fall where it lingers,
// so the light is the bombs' visual warning): an additive beam from the lamp to the floor, and the
// bright spot where it lands. FloatingHeadBombing sets the colour (cold white while it sweeps,
// enemy-attack red once it lingers) and the strength; nothing flickers.
//   shape 0, the beam: a cone, UV.y 0 at the lamp and 1 at the floor.
//   shape 1, the spot: a flat square, UV 0-1 over it; a soft disc with a brighter rim.
// Additive and unshaded, so it works the same on Forward+, Mobile and Compatibility (lifted there to
// read as brightly); it fades out far away itself, since fog would brighten an additive surface
// instead of hiding it.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"

uniform vec3 light_color : source_color = vec3(0.85, 0.92, 1.0);
uniform float strength = 1.0;
uniform int shape = 0;
uniform float fade_begin = 90.0;
uniform float fade_end = 320.0;

void fragment() {
	float a;
	if (shape == 0) {
		// Brightest along the cone's middle (where a viewer looks through the most light), fading
		// toward the floor and at the lamp's end so it grows out of the lens.
		float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
		a = pow(facing, 1.8) * (0.35 + 0.65 * (1.0 - UV.y)) * smoothstep(0.0, 0.06, UV.y) * 0.5;
	} else {
		float r = length(UV * 2.0 - 1.0);
		float disc = 1.0 - smoothstep(0.35, 1.0, r);
		float rim = smoothstep(0.72, 0.86, r) * (1.0 - smoothstep(0.86, 0.98, r));
		a = disc * 0.75 + rim * 0.5;
	}
	float fade = 1.0 - smoothstep(fade_begin, fade_end, length(VERTEX));
	float k = max(a * strength * fade, 0.0);
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	// Compatibility adds light in sRGB space, where a faint additive light reads far dimmer than the
	// same light added in linear space: lift it so the warning reads as brightly as on Forward+.
	k = pow(k, 0.4545);
#endif
	ALBEDO = to_linear(light_color) * k;
}

// The Resonator's wave (GDD §9.10): a red shockwave rolling along the floor toward the runner across
// every lane, the same in every zone (enemy-attack red, like ProjectilePool's enemy fire). The mesh
// comes from ResonatorModel.wave_mesh():
//   UV2.x 0, the crest: a low arch across the lanes, UV.x across it (0 to 1), UV.y over the arch
//            (0 at its front foot, facing the runner, 1 at its back foot);
//   UV2.x 1, the wake: a flat strip on the floor behind the crest, UV.x across, UV.y along it (0 at the
//            crest).
// Blended over the floor rather than added to it, so it stays red on a bright floor (the Golden Zone's
// white and cream) as well as a dark one; unshaded, with its crest brighter than white where the glow
// picks it up (Forward+ and Mobile). Stripes roll over the crest toward the runner; the Resonator
// holds them still with Reduced flashing (`roll`).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"

uniform vec3 wave_color : source_color = vec3(1.0, 0.15, 0.1);
uniform vec3 hot_color : source_color = vec3(1.0, 0.6, 0.56);
// Fades the wave in as it leaves and out once it has passed the runner.
uniform float strength = 1.0;
// The rolling stripes' phase (the Resonator advances it).
uniform float roll = 0.0;
// How far past white the crest's hot line goes, for the glow.
uniform float hdr = 1.6;

void fragment() {
	float across = abs(UV.x * 2.0 - 1.0);
	float ends = 1.0 - smoothstep(0.94, 1.0, across);
	vec3 col;
	float a;
	if (UV2.x < 0.5) {
		// The crest: red, a hot line just in front of its top, stripes rolling toward the runner.
		float top = clamp(1.0 - abs(UV.y - 0.4) * 3.2, 0.0, 1.0);
		float stripe = 0.5 + 0.5 * sin((UV.y * 3.0 + roll) * 6.2832);
		col = mix(to_linear(wave_color), to_linear(hot_color), top * top * 0.85);
		col *= 1.0 + top * top * hdr + stripe * 0.3;
		a = 0.94 * ends;
	} else {
		// The wake: a red haze on the floor behind it, fading with ripples.
		float along = clamp(UV.y, 0.0, 1.0);
		float ripple = 0.65 + 0.35 * sin((along * 5.0 + roll * 0.5) * 6.2832);
		col = to_linear(wave_color) * 1.3;
		a = (1.0 - along) * (1.0 - along) * 0.5 * ripple * ends;
	}
	ALBEDO = col;
	ALPHA = clamp(a * strength, 0.0, 1.0);
}

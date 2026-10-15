// Phase 3's waves (GDD §10: "waves crash over lanes, which the player jumps", warned by "a rising swell and a roar", and
// jumped like the Resonator's ring; MechaGuppyWaves). Water, so it never glows in a hazard colour but where it marks the
// hazard: the surge's low band, the part that hurts, carries a red glowing line along its face (the Resonator's red ring:
// the cross-zone language for a low band rolling at the runner, jump it). The mesh comes from MechaGuppyWaves:
//   UV2.x 0, the swell: a curling wall of water rising out of the sea beside the top, UV.x along it (0 to 1), UV.y up its
//            face (0 at its foot far below, 1 at its lip): deep sea at the foot, turquoise up its face, white foam on
//            its crest and lip, streaks of foam running up it;
//   UV2.x 1, the surge's crest: a low arch across the lanes, UV.x across it, UV.y over it (0 at its front foot, facing the
//            runner, 1 at its back foot): the red line low on its face (where its hitbox is), white foam on its top;
//   UV2.x 2, its wash: a sheet of water on the deck behind it, UV.y along it (0 at the crest), foam streaks thinning out.
// Unshaded, so it reads the same on every renderer; its streaks run with `flow` (MechaGuppyWaves holds it still with
// Reduced flashing), and nothing flickers.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"

uniform vec3 deep_color : source_color = vec3(0.12, 0.5, 0.58);
uniform vec3 water_color : source_color = vec3(0.22, 0.62, 0.66);
uniform vec3 shallow_color : source_color = vec3(0.5, 0.8, 0.74);
uniform vec3 foam_color : source_color = vec3(0.93, 0.95, 0.93);
uniform vec3 hazard_color : source_color = vec3(1.0, 0.12, 0.08);
// How far past white the hazard line goes, for the glow (Forward+ and Mobile), as the Resonator's crest.
uniform float hdr = 1.6;
// The streaks' phase (MechaGuppyWaves advances it; still with Reduced flashing).
uniform float flow = 0.0;

void fragment() {
	// Darker than the open sea's colours: unshaded, they'd read brighter than the lit beach's water (and pale turquoise too
	// near the pads' cyan).
	vec3 deep = to_linear(deep_color) * 0.7;
	vec3 water = to_linear(water_color) * 0.75;
	vec3 shallow = to_linear(shallow_color) * 0.75;
	vec3 foam = to_linear(foam_color);
	vec3 red = to_linear(hazard_color);
	vec3 col;
	if (UV2.x < 0.5) {
		float u = clamp(UV.y, 0.0, 1.0);
		col = mix(deep, water, smoothstep(0.1, 0.7, u));
		col = mix(col, shallow, smoothstep(0.7, 0.86, u) * 0.5);
		float streak = smoothstep(0.55, 0.95, value_noise(vec2(UV.x * 22.0, u * 9.0 - flow * 1.6)));
		col = mix(col, foam, clamp(smoothstep(0.86, 0.95, u) + streak * smoothstep(0.4, 0.85, u) * 0.5, 0.0, 1.0));
	} else if (UV2.x < 1.5) {
		float v = clamp(UV.y, 0.0, 1.0);
		float streak = smoothstep(0.45, 0.85, value_noise(vec2(UV.x * 30.0 - flow * 0.4, v * 4.0)));
		col = mix(water, foam, smoothstep(0.18, 0.4, v) * (0.85 + 0.15 * streak));
		// The hazard line: along the foot of the face the runner sees (only its red goes past white, for the glow: on the
		// Compatibility renderer it stays the warnings' red).
		float line = 1.0 - smoothstep(0.07, 0.12, abs(v - 0.08));
		col = mix(col, vec3(red.r * (1.0 + hdr), red.g, red.b), line);
	} else {
		float along = clamp(UV.y, 0.0, 1.0);
		float streak = smoothstep(0.45, 0.85, value_noise(vec2(UV.x * 26.0, along * 6.0 + flow)));
		col = mix(water, deep, along);
		col = mix(col, foam, streak * (1.0 - along) * 0.85);
	}
	ALBEDO = col;
}

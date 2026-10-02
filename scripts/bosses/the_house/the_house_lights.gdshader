// The House's lights (GDD §10: "lights blazing and jingling"), one draw for all of them
// (TheHouseModel): round bulbs on quads, UV 0-1 over each, UV2.x a bulb's place along its row and UV2.y
// its kind:
// - 0, the marquee bulbs round its face and down its sides: warm white, chasing (every third lit in
//   turn); at the jackpot they all flash;
// - 1, its two sirens: a dim white until the jackpot, then strobing.
// Warm and cold whites only: no hazard colour. With Reduced flashing nothing strobes or chases: the
// bulbs glow steadily (brighter at the jackpot).
shader_type spatial;
render_mode unshaded, cull_back;
#include "res://scripts/world/meshes/shaders/kit_flash.gdshaderinc"

uniform float level = 1.0;
uniform float jackpot = 0.0;
uniform float chase_speed = 7.0;

const vec3 WARM = vec3(1.0, 0.9, 0.72);
const vec3 SIREN = vec3(0.86, 0.93, 1.0);

void fragment() {
	vec2 q = (UV - 0.5) * 2.0;
	float r = length(q);
	if (r > 1.0) {
		discard;
	}
	float idx = UV2.x;
	int kind = int(UV2.y + 0.5);
	vec3 col;
	if (kind == 1) {
		float strobe = mix(step(0.5, fract(TIME * 2.6 + idx * 0.5)), 1.0, reduced_flashing);
		col = SIREN * mix(0.3, 1.7 * strobe, jackpot);
	} else {
		float chase = mix(0.55 + 0.6 * step(2.0, mod(idx - TIME * chase_speed, 3.0)), 0.9, reduced_flashing);
		float flash = mix(step(0.5, fract(TIME * 4.0)), 0.8, reduced_flashing);
		col = WARM * mix(chase, 0.5 + 0.9 * flash, jackpot);
	}
	col *= level * (1.0 - 0.4 * r * r);
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	col /= max(1.0, max(col.r, max(col.g, col.b)));
#endif
	ALBEDO = col;
}

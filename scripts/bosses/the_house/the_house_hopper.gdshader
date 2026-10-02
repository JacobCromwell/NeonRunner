// The House's coin hopper, burst open on its top at the jackpot (GDD §10: "its coin hopper bursts open
// on top as a glowing red weak point"), seen from above (TheHouseModel): UV 0-1 over the open bin. A heap
// of red-hot coins under a glowing rim, in the weak points' red (the hover truck's), pulsing (steadily
// with Reduced flashing). `open` (0-1) heats it up as the lids fly open; it's dark while shut.
shader_type spatial;
render_mode unshaded, cull_back;
#include "res://scripts/world/meshes/shaders/kit_flash.gdshaderinc"

uniform float open = 0.0;
uniform vec2 cells = vec2(18.0, 10.0);

const vec3 WEAK = vec3(1.0, 0.08, 0.1);
const vec3 HOT = vec3(1.0, 0.35, 0.22);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 g = UV * cells;
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float h = hash(id);
	// A coin in most cells, each tilted its own way: a red-hot rim and a darker face.
	float coin = length((f + vec2(h - 0.5, fract(h * 7.3) - 0.5) * 0.25) * vec2(1.0, 1.0 + 0.6 * fract(h * 3.1))) - 0.36;
	float rim_coin = abs(coin + 0.06) - 0.05;
	vec3 col = WEAK * 0.55;
	col = mix(col, HOT, 1.0 - smoothstep(-0.03, 0.03, rim_coin));
	col = mix(col, WEAK * 0.8, step(coin, -0.11));
	// The bin's rim glows brightest.
	vec2 e = min(UV, 1.0 - UV);
	float edge = 1.0 - smoothstep(0.0, 0.08, min(e.x * cells.y / cells.x * 1.8, e.y));
	col = mix(col, WEAK * 1.4, edge);
	float pulse = mix(0.8 + 0.2 * sin(TIME * 6.0), 0.95, reduced_flashing);
	col *= mix(0.06, 1.25 * pulse, clamp(open, 0.0, 1.0));
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	// No tonemapping here: over-bright, the red would clip toward salmon. Scaled down whole instead.
	col /= max(1.0, max(col.r, max(col.g, col.b)));
#endif
	ALBEDO = col;
}

// A 7 button of The House's (GDD §10: "big glowing 7 buttons appear along the route. Running over one
// locks its reel on 7"), drawn on one quad per part (TheHouseButtons):
// - part 0, the button: a round ivory disc flat on the floor, ringed in white with warm bulbs chasing
//   round it, and the reels' 7 (royal blue ringed in white) in its middle;
// - part 1, its sign: the same 7, upright and floating above head height over the button, so it shows
//   from far along the street (it's never in the runner's way).
// No hazard's colour (white, ivory and royal blue: safe to run over) and no pad's shape (round, and the
// 7 is the reels'). `appear` grows it in, `pressed` lights it white-hot as it's run over (then it sinks),
// `missed` dims it once passed. Unshaded; no flashing with Reduced flashing.
shader_type spatial;
render_mode unshaded, cull_disabled;
#include "res://scripts/world/meshes/shaders/kit_flash.gdshaderinc"
#include "res://scripts/bosses/the_house/the_house_symbols.gdshaderinc"

uniform int part = 0;
uniform float appear = 1.0;
uniform float pressed = 0.0;
uniform float missed = 0.0;
uniform float brightness = 1.15;

const vec3 IVORY = vec3(0.98, 0.95, 0.88);
const vec3 BULB = vec3(1.0, 0.93, 0.78);

void fragment() {
	vec2 q = (UV - 0.5) * 2.0;
	q.y = -q.y;
	float grow = mix(0.35, 1.0, clamp(appear, 0.0, 1.0));
	q /= grow;
	float r = length(q);
	float aa = max(fwidth(r) * 0.9, 0.004);
	vec3 col;
	if (part == 0) {
		if (r > 1.0) {
			discard;
		}
		// The disc, a little brighter toward its middle, with a bevel at its edge.
		col = IVORY * (0.86 + 0.14 * (1.0 - r));
		float ring = abs(r - 0.9) - 0.07;
		col = mix(col, vec3(1.0), 1.0 - smoothstep(-aa, aa, ring));
		// Bulbs chasing round the rim (lit steadily with Reduced flashing).
		float ang = atan(q.y, q.x);
		float bulbs = 18.0;
		float cell = fract(ang / 6.2831853 * bulbs);
		float spot = length(vec2((cell - 0.5) * 6.2831853 * 0.9 / bulbs, r - 0.9)) - 0.045;
		float chase = mix(0.45 + 0.55 * step(0.6, fract(cell - TIME * 1.4 + floor(ang / 6.2831853 * bulbs) / 3.0)),
			1.0, reduced_flashing);
		col = mix(col, BULB * (1.0 + 0.4 * chase), (1.0 - smoothstep(-aa, aa, spot)) * chase);
		vec4 sym = symbol_color(SYMBOL_SEVEN, q * 0.62, aa * 0.62);
		col = mix(col, sym.rgb, sym.a);
	} else {
		// The 7 alone, ringed in white, cut out of the quad.
		vec4 sym = symbol_color(SYMBOL_SEVEN, q * 0.5, aa * 0.5);
		if (sym.a < 0.5) {
			discard;
		}
		col = sym.rgb;
	}
	// Run over: lit white-hot. Passed by: dimmed and greyed.
	col = mix(col, vec3(1.0), clamp(pressed, 0.0, 1.0) * 0.55);
	float grey = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(grey) * 0.45, clamp(missed, 0.0, 1.0));
	col *= brightness * (1.0 + 0.3 * clamp(pressed, 0.0, 1.0));
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	// No tonemapping here: over-bright, the 7's blue would clip toward the pads' cyan.
	col /= max(1.0, max(col.r, max(col.g, col.b)));
#endif
	ALBEDO = col;
}

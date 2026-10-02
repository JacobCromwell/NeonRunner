// The House's TILT sign (GDD §10, its defeat: "the reels spin wildly and jam, 'TILT' flashes"), one quad
// over the reels' window (TheHouseModel): the word TILT in big warm-white letters ringed in gold on a dark
// panel, drawn as distances so it stays crisp on every renderer. `on` (0-1) shows it; it flashes on and
// off, and with Reduced flashing glows steadily instead (kit_flash: reduced_flashing). No hazard's
// colour: at its defeat nothing of it is a danger any more.
shader_type spatial;
render_mode unshaded, cull_back;
#include "res://scripts/world/meshes/shaders/kit_flash.gdshaderinc"

uniform float on = 0.0;
// The quad's width over its height.
uniform float aspect = 4.0;
uniform float brightness = 1.2;

const vec3 PANEL = vec3(0.05, 0.03, 0.08);
const vec3 LETTER = vec3(1.0, 0.95, 0.82);
const vec3 RIM_GOLD = vec3(1.0, 0.72, 0.22);

float sd_box(vec2 p, vec2 half_size) {
	vec2 q = abs(p) - half_size;
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0);
}

// One letter's distance in its cell (x -0.5..0.5, y -0.5..0.5): 0 T, 1 I, 2 L.
float letter(vec2 p, int id) {
	float stroke = 0.09;
	if (id == 0) {
		float top = sd_box(p - vec2(0.0, 0.36), vec2(0.36, stroke));
		float stem = sd_box(p - vec2(0.0, -0.04), vec2(stroke, 0.42));
		return min(top, stem);
	} else if (id == 1) {
		return sd_box(p, vec2(stroke, 0.45));
	}
	float stem_l = sd_box(p - vec2(-0.22, 0.0), vec2(stroke, 0.45));
	float foot = sd_box(p - vec2(0.02, -0.36), vec2(0.33, stroke));
	return min(stem_l, foot);
}

void fragment() {
	if (on <= 0.001) {
		discard;
	}
	// Four cells across: T I L T.
	vec2 uv = vec2(UV.x * aspect, 1.0 - UV.y);
	float cells = 4.0;
	float cell_w = aspect / cells;
	int k = int(clamp(floor(UV.x * cells), 0.0, 3.0));
	vec2 p = vec2((uv.x - (float(k) + 0.5) * cell_w) / 1.0, uv.y - 0.5) / 0.86;
	int id = k == 1 ? 1 : (k == 2 ? 2 : 0);
	float d = letter(p, id);
	float aa = max(fwidth(d) * 0.9, 0.004);
	float fill = 1.0 - smoothstep(-aa, aa, d);
	float rim = 1.0 - smoothstep(-aa, aa, abs(d - 0.035) - 0.025);
	// Flashing on and off; a steady glow with Reduced flashing.
	float flash = mix(step(0.45, fract(TIME * 2.6)), 1.0, reduced_flashing);
	vec3 col = PANEL;
	col = mix(col, RIM_GOLD, rim * mix(0.35, 1.0, flash));
	col = mix(col, LETTER * mix(0.3, 1.0, flash), fill);
	col *= brightness * clamp(on, 0.0, 1.0);
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	col /= max(1.0, max(col.r, max(col.g, col.b)));
#endif
	ALBEDO = col;
}

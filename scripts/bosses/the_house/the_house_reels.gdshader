// The House's three reels (GDD §10: "three huge reels on its chest spin and stop one at a time"), one
// draw for all three: each reel is a strip of drum (TheHouseModel) whose UV runs across it (x, 0 to 1)
// and down its window (y, 0 at the top), UV2.x its index. The strip carries the symbols 7, cherry, BAR
// and lightning in that order, over and over (the_house_symbols.gdshaderinc); `angles` says where each
// reel is on its strip (in symbols, the window's middle), and the symbols move down as it grows. A
// spinning reel smears (`blur`); a reel locked on 7 glows (`locked`). Unshaded and procedural, so it reads
// the same on every renderer; no flashing with Reduced flashing.
shader_type spatial;
render_mode unshaded, cull_back;
#include "res://scripts/world/meshes/shaders/kit_flash.gdshaderinc"
#include "res://scripts/bosses/the_house/the_house_symbols.gdshaderinc"

uniform vec3 angles = vec3(0.0);
uniform vec3 blur = vec3(0.0);
uniform vec3 locked = vec3(0.0);
// How many symbols tall a window is, and a symbol cell's width over its height.
uniform float window_symbols = 1.45;
uniform float aspect = 1.0;
uniform float brightness = 1.05;
// The jackpot's celebration (0-1): the reels flash (a steady brighter glow with Reduced flashing).
uniform float jackpot = 0.0;
// 0 = the power is out (its defeat).
uniform float power = 1.0;

const vec3 DRUM = vec3(0.95, 0.92, 0.85);

float pick(vec3 v, int i) {
	return i == 0 ? v.x : (i == 1 ? v.y : v.z);
}

void fragment() {
	int reel = clamp(int(UV2.x + 0.5), 0, 2);
	float a = pick(angles, reel);
	float bl = clamp(pick(blur, reel), 0.0, 1.0);
	float lk = clamp(pick(locked, reel), 0.0, 1.0);
	float s_mid = a + (0.5 - UV.y) * window_symbols;
	float aa = max(fwidth(s_mid) * 0.9, 0.003);
	// Symbols are drawn in a unit cell; a narrow cell shrinks them to fit.
	float fit = min(aspect, 1.0) * 0.94;
	int samples = bl > 0.02 ? 5 : 1;
	vec3 acc = vec3(0.0);
	for (int k = 0; k < 5; k++) {
		if (k >= samples) {
			break;
		}
		float off = samples == 1 ? 0.0 : (float(k) / 4.0 - 0.5) * bl * 0.55;
		float s = s_mid + off;
		float slot = floor(s + 0.5);
		vec2 p = vec2((UV.x - 0.5) * aspect, s - slot) / fit;
		int id = int(mod(slot, 4.0));
		vec4 sym = symbol_color(id, p, aa / fit + bl * 0.05);
		acc += mix(DRUM, sym.rgb, sym.a);
	}
	vec3 col = acc / float(samples);
	// The drum curves away at the window's top and bottom, and its sides are a little darker.
	float edge = abs(UV.y - 0.5) * 2.0;
	col *= 1.0 - 0.55 * edge * edge;
	col *= 1.0 - 0.18 * pow(abs(UV.x - 0.5) * 2.0, 4.0);
	// A reel locked on 7 glows (its own steady glow, a gentle pulse unless Reduced flashing).
	float pulse = mix(0.85 + 0.15 * sin(TIME * 5.0), 1.0, reduced_flashing);
	col = mix(col, col * 1.25 + vec3(0.04, 0.08, 0.22), lk * pulse);
	float flash = mix(step(0.5, fract(TIME * 3.0)), 0.6, reduced_flashing);
	col *= brightness * (1.0 + 0.3 * jackpot * flash) * mix(0.08, 1.0, power);
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	// No tonemapping here: over-bright, the 7's blue would clip toward the pads' cyan and the cherry's red
	// toward salmon. Scaled down whole instead, each keeps its hue.
	col /= max(1.0, max(col.r, max(col.g, col.b)));
#endif
	ALBEDO = col;
}

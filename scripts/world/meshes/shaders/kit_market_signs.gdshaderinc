// The market's signs and ads, shared by the Marketplace's solid kit patterns (kit_market.gdshaderinc: PAT_SHOPSIGN,
// PAT_AD) and by the shop windows' display material (window_display.gdshader, task L10): generic geometric brands, a
// shop sign's painted face and an advertising screen's picture. Needs only kit_common.gdshaderinc (hash11, hash12,
// value_noise); moved out of kit_market so the window displays can use them without the stalls' uniforms.

// The market's ordinary brands: generic geometric marks for shop signs and ads. `p` runs from -1 to
// 1 across the mark; returns coverage 0-1. None has the cult emblem's three-fold symmetry: the
// emblem itself is real geometry (CultEmblem), added on top of some ads and signs by the skin.
float market_logo(vec2 p, float seed) {
	int kind = int(mod(seed, 4.0));
	vec2 a = abs(p);
	float d;
	if (kind == 0) {
		// A four-pointed sparkle.
		d = sqrt(a.x) + sqrt(a.y) - 0.95;
	} else if (kind == 1) {
		// A hexagonal ring around a dot.
		float hex = max(a.x * 0.866 + a.y * 0.5, a.y);
		d = min(abs(hex - 0.74) - 0.12, length(p) - 0.22);
	} else if (kind == 2) {
		// An arch over a bar, like a market hall's gate.
		float arch = p.y > -0.1 ? abs(length(p - vec2(0.0, -0.1)) - 0.62) - 0.13 : abs(a.x - 0.62) - 0.13;
		d = min(max(arch, -0.55 - p.y), max(abs(p.y + 0.72) - 0.12, a.x - 0.9));
	} else {
		// Three stacked bars, each shorter than the one above.
		vec2 b0 = abs(p - vec2(0.0, 0.5)) - vec2(0.85, 0.13);
		vec2 b1 = abs(p - vec2(-0.15, 0.0)) - vec2(0.7, 0.13);
		vec2 b2 = abs(p - vec2(-0.3, -0.5)) - vec2(0.55, 0.13);
		d = min(max(b0.x, b0.y), min(max(b1.x, b1.y), max(b2.x, b2.y)));
	}
	float aa = max(fwidth(d), 1e-4);
	return 1.0 - smoothstep(-aa, aa, d);
}

// PAT_SHOPSIGN (24): a shop sign's painted face (the content inside a hazard sign's frame, or a
// decorative board): a disc with a brand mark, then a word in chunky letters, repeating along the
// panel. UV in metres on the panel; param = seed (0-99) + 100 * the panel's height in decimetres,
// + 10000 for lettering only (no disc). Inside a hazard sign, the frame is the hazard; this part is
// only decoration.
vec3 mk_shopsign(vec3 base, vec2 uv, float param) {
	float code = floor(param + 0.5);
	float no_disc = step(10000.0, code);
	code = mod(code, 10000.0);
	float seed = mod(code, 100.0);
	float height = max(floor(code / 100.0) * 0.1, 0.2);
	vec2 fw = max(fwidth(uv), vec2(1e-4));
	vec3 ink = mix(vec3(0.9, 0.88, 0.82), base * 0.3, step(0.62, dot(base, vec3(0.3, 0.5, 0.2))));
	float r = min(height * 0.36, 0.6);
	float unit = r * 2.0 + max(height * 2.2, 1.8);
	float k = floor(uv.x / unit);
	float ux = uv.x - k * unit;
	vec2 d = vec2(ux - r - 0.12, uv.y - height * 0.5);
	float disc = (1.0 - smoothstep(r - fw.x, r + fw.x, length(d))) * (1.0 - no_disc);
	float logo = market_logo(d / (r * 0.7), seed + k);
	vec3 col = mix(base, ink, disc);
	col = mix(col, base * 0.85, logo * disc);
	// A word: 2 x 3 stroke glyphs in one row, centred on the panel's height.
	float lh = min(height * 0.44, 0.62);
	vec2 lp = vec2((ux - r * 2.0 - 0.3) / (lh * 0.72), (uv.y - (height - lh) * 0.5) / lh);
	float inside = step(0.0, lp.x) * step(lp.x, max(height * 2.2, 1.8) / (lh * 0.72) - 0.6) * step(0.0, lp.y) * step(lp.y, 1.0);
	vec2 g = fract(lp);
	vec2 sub = floor(vec2(clamp((g.x - 0.14) / 0.36, 0.0, 1.99), clamp(lp.y * 3.0, 0.0, 2.99)));
	float stroke_r = hash12(vec2(floor(lp.x), k) * 2.3 + sub * 1.7 + seed);
	float stroke = stroke_r < 0.45 ? step(abs(fract(lp.y * 3.0) - 0.5), 0.3) : (stroke_r < 0.85 ? step(abs(fract((g.x - 0.14) / 0.36) - 0.5), 0.34) : 0.0);
	float on = inside * step(0.14, g.x) * step(g.x, 0.86) * stroke;
	on = mix(on, 0.3 * inside, smoothstep(0.03, 0.15, max(fw.x, fw.y) / lh));
	col = mix(col, ink, on);
	return col * (0.9 + 0.12 * value_noise(uv * 3.0 + seed));
}

// PAT_AD (25): an advertising screen. UV.y runs 0-1 up the screen and UV.x in the same units (it
// ends at the screen's aspect ratio); param a whole-number seed. A brand mark (market_logo) in a
// pale disc, lines of text, and a slow sweep of light (no flashing). Glowing, so COLOR keeps to
// the decorative hues; glow_mask shapes the glow.
vec3 mk_ad(vec3 base, vec2 uv, float param, float t, out float glow_mask) {
	float seed = floor(param + 0.5);
	vec3 col = mix(base * 0.35, base * 0.75, uv.y);
	glow_mask = 0.55;
	vec2 lc = vec2(0.5, 0.5);
	float fw = max(max(fwidth(uv.x), fwidth(uv.y)), 1e-4);
	float disc = 1.0 - smoothstep(0.36 - fw, 0.36 + fw, length(uv - lc));
	float logo = market_logo((uv - lc) / 0.27, seed);
	col = mix(col, vec3(0.92, 0.93, 0.97), disc);
	col = mix(col, base * 0.6, logo * disc);
	glow_mask = mix(glow_mask, 0.9, disc);
	// Lines of text to the right of the mark; the top line is the big one.
	vec2 tp = (uv - vec2(1.0, 0.18)) / vec2(0.09, 0.16);
	vec2 cell = floor(tp);
	float line = step(0.0, tp.x) * step(0.0, tp.y) * step(tp.y, 4.0) * step(0.25, fract(tp.y)) * step(fract(tp.y), 0.75);
	float word = step(0.28, hash12(vec2(floor(cell.x / 4.0), cell.y) + seed)) * step(0.15, fract(tp.x)) * step(fract(tp.x), 0.85);
	float text = line * word * mix(1.0, step(cell.x, 14.0 + 10.0 * hash11(seed)), step(3.0, cell.y));
	text = mix(text, 0.3 * line, smoothstep(0.02, 0.1, fw * 8.0));
	col = mix(col, vec3(0.95, 0.95, 0.98), text * 0.85);
	glow_mask = mix(glow_mask, 1.0, text);
	// Squared by hand: pow() of a negative number is undefined (NaN on some GPUs).
	float sx = (uv.x - uv.y * 0.4 - mod(t * 0.35 + seed * 0.37, 6.0) + 1.0) * 3.0;
	float sweep = exp(-sx * sx);
	return col + base * 0.25 * sweep;
}


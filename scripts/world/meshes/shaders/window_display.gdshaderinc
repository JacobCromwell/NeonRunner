// The Marketplace's and the Casino's shop-window displays (task L10; GDD §5, "Cyborg Viewing Devices", the owner's
// October 17, 2026 decision: no feed TVs in the shop windows). One small material for both (window_display.gdshader,
// scripts/world/meshes/window_display.gd), not a pattern of the solid kit shader: the solid kit shader is compiled by every
// zone, and the displays' code would have cost them all (the City-only web demo too) several seconds of compile time.
// A display is one rectangle, so a chunk with displays draws one more surface, as the feed's TVs did.
//   kind 0: an ad screen playing a few cycling, procedurally drawn ads (a brand card, noodles, a drink, a delivery drone, a
//   sale and a cup of tea; in the Casino a brand card, a slot machine, a stack of chips, a cocktail, a champagne bottle and
//   a pair of dice), each shown for a few seconds, dipping through the screen's dark between one and the next, with the
//   cult's emblem flashing onto it every once in a while. Every screen's order, timing and flash moment come from its
//   seed alone (its window's own position), so none plays in step with another. It glows at COLOR.a (the screen's
//   brightness) times the picture's glow mask; the colours come from the skin's palette (wd_palette: blue to violet and
//   warm white, the decorative hues, never a hazard's).
//   kinds 1-4: a lit poster, wordless like every sign in this market: a shop's own sign, a sale, a menu or a product,
//   painted in COLOR and cream. Never glowing.
// DESIGN-TBD (docs/questions/l10.md): what the ads and posters show, how often the emblem flashes, and for how long.
// UV.y runs 0-1 up the panel and UV.x in the same units (it ends at the panel's aspect ratio); UV2.x = the kind, UV2.y =
// WindowDisplay.param(): seed (0-999) + 1000 * aspect in tenths (small, so it survives the GPU's interpolation).
// Reduced flashing (kit_flash.gdshaderinc): the emblem fades in and out slowly and stays a while, and the dip between ads
// is slower; nothing pops (wd_flash_reduced); nothing else here flashes (the scenes' own motion is a slow drift).
// Footprints (fwidth) are taken where every pixel of a 2x2 block runs the same code (the main function), and everything
// below branches only on what a whole face shares (its seed and the time): a pixel draws one scene, never two.
// Include after kit_common, kit_flash and kit_market_signs.

// The ads' colours (sRGB, set by the skin from window_ad_colors): 0 blue, 1 violet, 2 deep indigo (the screens'
// backgrounds), 3 warm white, 4 pale blue-white (the drawn things), 5 lavender (the accents).
uniform vec3 wd_palette[6];
// The emblem's warm white (CultFeed.emblem_color(): the chosen option's own neon, sRGB) and its coverage in alpha
// (CultFeed.emblem_texture(), with mipmaps).
uniform vec3 wd_emblem = vec3(1.0, 0.93, 0.82);
uniform sampler2D wd_emblem_tex : filter_linear_mipmap, repeat_disable;
// 1 for the Casino's set of ads (slots, chips, a cocktail), 0 for the Marketplace's.
uniform int wd_casino = 0;
// Seconds between one screen's emblem flashes: the shortest and the longest (each screen picks its own).
uniform vec2 wd_flash_period = vec2(14.0, 26.0);
// The emblem's flash: seconds fading in, held and fading out; with Reduced flashing, the slower steadier one.
uniform vec3 wd_flash = vec3(0.22, 1.1, 0.55);
uniform vec3 wd_flash_reduced = vec3(0.9, 2.0, 0.9);
// How long an ad stays up, in seconds: the shortest and the longest (each screen picks its own).
uniform vec2 wd_scene_time = vec2(5.0, 7.5);
// The dip through the dark between two ads, each way, as a share of the ad's time; and with Reduced flashing.
uniform vec2 wd_dip = vec2(0.05, 0.12);

// A shop sign's height in metres (MarketFacades.SIGN_SIZE.x): its letters scale with it.
const float WD_SIGN_HEIGHT = 0.5;
// The Casino's six ads, as scene ids.
const int WD_CASINO_SCENES[6] = int[6](0, 6, 7, 8, 2, 9);

float wd_cov(float d, float aa) {
	return 1.0 - smoothstep(-aa, aa, d);
}

float wd_box(vec2 p, vec2 h) {
	vec2 q = abs(p) - h;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
}

float wd_rbox(vec2 p, vec2 h, float r) {
	return wd_box(p, h - r) - r;
}

float wd_seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}

// A seven-segment digit (0, 3, 5 or 7) at p: x from -0.3 to 0.3, y from -0.6 to 0.6. Returns the distance.
float wd_digit(vec2 p, int d) {
	float off = 1e3;
	float top = wd_box(p - vec2(0.0, 0.5), vec2(0.22, 0.055));
	float mid = wd_box(p, vec2(0.22, 0.055)) + ((d == 3 || d == 5) ? 0.0 : off);
	float bot = wd_box(p + vec2(0.0, 0.5), vec2(0.22, 0.055)) + (d != 7 ? 0.0 : off);
	float tr = wd_box(p - vec2(0.27, 0.25), vec2(0.055, 0.25)) + (d != 5 ? 0.0 : off);
	float br = wd_box(p - vec2(0.27, -0.25), vec2(0.055, 0.25));
	float tl = wd_box(p - vec2(-0.27, 0.25), vec2(0.055, 0.25)) + ((d == 0 || d == 5) ? 0.0 : off);
	float bl = wd_box(p - vec2(-0.27, -0.25), vec2(0.055, 0.25)) + (d == 0 ? 0.0 : off);
	return min(min(min(top, mid), min(bot, tr)), min(br, min(tl, bl)));
}

// A steam curl rising from y0 toward y1 at x0: coverage, fading in and out along its height.
float wd_steam(vec2 p, float x0, float y0, float y1, float t, float phase, float aa) {
	float x = x0 + 0.02 * sin((p.y - y0) * 17.0 - t * 1.3 + phase);
	float along = smoothstep(y0, y0 + 0.04, p.y) * (1.0 - smoothstep(y1 - 0.08, y1, p.y));
	return wd_cov(abs(p.x - x) - 0.008, aa) * along;
}

// The right-hand side of a picture: a brand disc (the market's own marks, never the cult's) over two lines of text.
vec3 wd_side(vec3 col, vec2 p, float aa, vec3 fg, vec3 ac, float seed, inout float lit) {
	vec2 c = vec2(0.54, 0.17);
	float disc = wd_cov(length(p - c) - 0.17, aa);
	float logo = market_logo((p - c) / 0.12, seed);
	col = mix(col, fg, disc);
	col = mix(col, ac * 0.7, logo * disc);
	float bar_a = wd_cov(wd_rbox(p - vec2(0.54, -0.14), vec2(0.27, 0.022), 0.02), aa);
	float bar_b = wd_cov(wd_rbox(p - vec2(0.49, -0.24), vec2(0.21, 0.022), 0.02), aa);
	col = mix(col, fg, max(bar_a, bar_b) * 0.9);
	lit = max(lit, max(disc, max(bar_a, bar_b)));
	return col;
}

// 1: a bowl of noodles with steam and a pair of chopsticks.
vec3 wd_bowl(vec2 p, float t, float aa, vec3 bg, vec3 fg, vec3 ac, float seed, bool side, out float lit) {
	vec3 col = mix(bg * 0.55, bg * 0.95, p.y + 0.5);
	vec2 q = p - vec2(-0.3, -0.04);
	float mound = wd_cov(max(length(q) - 0.24, -q.y), aa);
	float wave = 0.5 + 0.5 * sin((q.x + 0.03 * sin(q.y * 30.0)) * 75.0);
	wave = mix(wave, 0.5, smoothstep(0.012, 0.04, aa));
	col = mix(col, mix(fg, ac, 0.3 + 0.4 * wave), mound);
	float bowl = wd_cov(max(length(q) - 0.31, q.y), aa);
	col = mix(col, fg, bowl);
	float band = wd_cov(max(abs(q.y + 0.12) - 0.03, length(q) - 0.31), aa);
	col = mix(col, ac, band * bowl);
	col = mix(col, ac, wd_cov(wd_box(q, vec2(0.34, 0.016)), aa));
	col = mix(col, fg * 0.85, wd_cov(wd_box(q + vec2(0.0, 0.33), vec2(0.1, 0.022)), aa));
	float steam = max(wd_steam(q, -0.09, 0.2, 0.46, t, 0.0, aa), max(wd_steam(q, 0.0, 0.2, 0.5, t, 2.1, aa),
		wd_steam(q, 0.09, 0.2, 0.44, t, 4.2, aa)));
	col = mix(col, fg, steam * 0.7);
	float sticks = wd_cov(min(wd_seg(q, vec2(0.12, 0.12), vec2(0.34, 0.42)), wd_seg(q, vec2(0.16, 0.1), vec2(0.38, 0.4))) - 0.012, aa);
	col = mix(col, ac, sticks);
	lit = max(max(mound, bowl), max(steam * 0.6, sticks));
	return side ? wd_side(col, p, aa, fg, ac, seed, lit) : col;
}

// 2: a bottle of something fizzy, bubbles rising.
vec3 wd_bottle(vec2 p, float t, float aa, vec3 bg, vec3 fg, vec3 ac, float seed, bool side, out float lit) {
	vec3 col = mix(bg * 0.6, bg, p.y + 0.5);
	vec2 q = p - vec2(-0.3, -0.02);
	float body = wd_cov(wd_rbox(q + vec2(0.0, 0.05), vec2(0.115, 0.22), 0.07), aa);
	float neck = wd_cov(wd_rbox(q - vec2(0.0, 0.25), vec2(0.045, 0.1), 0.02), aa);
	float cap = wd_cov(wd_rbox(q - vec2(0.0, 0.36), vec2(0.055, 0.03), 0.01), aa);
	float glass = max(body, neck);
	col = mix(col, fg, glass);
	col = mix(col, ac, wd_cov(wd_box(q + vec2(0.0, 0.03), vec2(0.115, 0.075)), aa) * body);
	col = mix(col, bg, wd_cov(wd_rbox(q + vec2(0.06, 0.05), vec2(0.014, 0.15), 0.012), aa) * body * 0.4);
	col = mix(col, ac, cap);
	float bubbles = 0.0;
	for (int i = 0; i < 4; i++) {
		float fi = float(i);
		float rise = fract(t * 0.18 + fi * 0.26 + seed * 0.013);
		vec2 b = vec2(-0.3 + 0.18 * (fi - 1.5) + 0.012 * sin(t + fi * 2.0), -0.4 + rise * 0.9);
		bubbles = max(bubbles, wd_cov(length(p - b) - (0.02 + 0.006 * fi), aa) * smoothstep(0.0, 0.1, rise)
			* (1.0 - smoothstep(0.8, 1.0, rise)));
	}
	col = mix(col, fg, bubbles * 0.7);
	lit = max(glass, max(cap * 0.8, bubbles * 0.6));
	return side ? wd_side(col, p, aa, fg, ac, seed + 1.0, lit) : col;
}

// 3: a delivery drone carrying a parcel along a dashed route to a pin.
vec3 wd_drone(vec2 p, float t, float aa, vec3 bg, vec3 fg, vec3 ac, float seed, out float lit) {
	vec3 col = mix(bg * 0.6, bg, p.y + 0.5);
	vec2 q = p - vec2(-0.1 + 0.05 * sin(t * 0.5), 0.1 + 0.015 * sin(t * 1.3));
	// The dashes scroll: box-filtered, so they average into a plain line (not a shimmer) where they are small.
	float dash = filtered_pulse(p.x * 6.0 - t * 0.35, aa * 6.0, 0.0, 0.5) * wd_cov(abs(p.y + 0.36) - 0.012, aa)
		* step(-0.8, p.x) * step(p.x, 0.56);
	col = mix(col, fg, dash * 0.75);
	vec2 pin = vec2(0.66, -0.3);
	float pin_head = wd_cov(length(p - pin - vec2(0.0, 0.1)) - 0.075, aa);
	float pin_tip = wd_cov(wd_seg(p, pin + vec2(0.0, 0.09), pin) - 0.04, aa);
	col = mix(col, ac, max(pin_head, pin_tip));
	col = mix(col, bg * 0.7, wd_cov(length(p - pin - vec2(0.0, 0.1)) - 0.03, aa));
	float body = wd_cov(wd_rbox(q, vec2(0.13, 0.05), 0.04), aa);
	float arms = wd_cov(min(wd_seg(q, vec2(-0.1, 0.03), vec2(-0.27, 0.09)), wd_seg(q, vec2(0.1, 0.03), vec2(0.27, 0.09))) - 0.012, aa);
	float rotors = wd_cov(min(length(vec2(q.x + 0.27, (q.y - 0.1) * 5.0)), length(vec2(q.x - 0.27, (q.y - 0.1) * 5.0))) - 0.12, aa);
	float strap = wd_cov(wd_seg(q, vec2(0.0, -0.04), vec2(0.0, -0.14)) - 0.007, aa);
	float parcel = wd_cov(wd_box(q + vec2(0.0, 0.2), vec2(0.1, 0.07)), aa);
	col = mix(col, fg, max(max(body, arms), max(rotors, strap)));
	col = mix(col, ac, parcel);
	col = mix(col, fg, wd_cov(wd_box(q + vec2(0.0, 0.2), vec2(0.014, 0.07)), aa) * parcel * 0.8);
	vec2 c = vec2(0.54, 0.3);
	float disc = wd_cov(length(p - c) - 0.12, aa);
	col = mix(col, fg, disc);
	col = mix(col, ac * 0.7, market_logo((p - c) / 0.085, seed + 2.0) * disc);
	lit = max(max(body, rotors * 0.8), max(parcel * 0.8, max(dash * 0.5, max(max(pin_head, pin_tip), disc))));
	return col;
}

// The sale's burst at q (its centre at the origin): x the starburst, y the disc inside it, z the number (a seven-segment
// 30, 50 or 70) and a percent sign.
vec3 wd_burst(vec2 q, float t, float aa, float seed) {
	float star = wd_cov(length(q) - (0.36 + 0.05 * cos((atan(q.y, q.x) + t * 0.05) * 12.0)), aa);
	float disc = wd_cov(length(q) - 0.285, aa);
	int tens = 3 + 2 * int(floor(hash11(seed * 3.3 + 1.0) * 3.0));
	float num = min(wd_digit((q - vec2(-0.1, 0.0)) / 0.2, tens), wd_digit((q - vec2(0.07, 0.0)) / 0.2, 0)) * 0.2;
	vec2 pc = q - vec2(0.205, 0.0);
	float pct = min(min(abs(length(pc - vec2(-0.03, 0.05)) - 0.025), abs(length(pc - vec2(0.03, -0.05)) - 0.025)) - 0.008,
		wd_seg(pc, vec2(0.04, 0.09), vec2(-0.04, -0.09)) - 0.008);
	return vec3(star, disc, wd_cov(min(num, pct), aa));
}

// 4: a sale: a starburst with a number and a percent sign, and beside it lines of text.
vec3 wd_sale(vec2 p, float t, float aa, vec3 bg, vec3 fg, vec3 ac, float seed, out float lit) {
	vec3 col = mix(bg * 0.6, bg * 0.95, p.y + 0.5);
	vec3 b = wd_burst(p - vec2(-0.05, 0.0), t, aa, seed);
	col = mix(col, ac, b.x);
	col = mix(col, fg, b.y);
	col = mix(col, bg * 0.5, b.z);
	float bar_a = wd_cov(wd_rbox(p - vec2(0.62, 0.08), vec2(0.2, 0.025), 0.02), aa);
	float bar_b = wd_cov(wd_rbox(p - vec2(0.58, -0.04), vec2(0.16, 0.025), 0.02), aa);
	float bar_c = wd_cov(wd_rbox(p - vec2(0.54, -0.16), vec2(0.12, 0.025), 0.02), aa);
	float bars = max(bar_a, max(bar_b, bar_c));
	col = mix(col, fg, bars * 0.9);
	lit = max(max(b.x * 0.9, b.y), bars * 0.8);
	return col;
}

// 5: a cup of tea with steam on a saucer.
vec3 wd_cup(vec2 p, float t, float aa, vec3 bg, vec3 fg, vec3 ac, float seed, bool side, out float lit) {
	vec3 col = mix(bg * 0.55, bg * 0.9, p.y + 0.5);
	vec2 q = p - vec2(-0.28, -0.03);
	float cup = wd_cov(max(wd_rbox(q - vec2(0.0, 0.07), vec2(0.18, 0.21), 0.07), q.y - 0.14), aa);
	float handle = wd_cov(abs(length(q - vec2(0.2, 0.01)) - 0.075) - 0.02, aa) * step(0.15, q.x);
	float saucer = wd_cov(wd_rbox(q + vec2(0.0, 0.165), vec2(0.27, 0.02), 0.02), aa);
	col = mix(col, fg, max(cup, max(handle, saucer)));
	col = mix(col, ac, wd_cov(wd_box(q - vec2(0.0, 0.1), vec2(0.17, 0.012)), aa) * cup);
	col = mix(col, ac, wd_cov(wd_rbox(q + vec2(0.0, 0.03), vec2(0.18, 0.025), 0.02), aa) * cup * 0.8);
	float steam = max(wd_steam(q, -0.06, 0.14, 0.44, t, 1.0, aa), wd_steam(q, 0.06, 0.14, 0.4, t, 3.3, aa));
	col = mix(col, fg, steam * 0.65);
	lit = max(max(cup, saucer), max(handle, steam * 0.6));
	return side ? wd_side(col, p, aa, fg, ac, seed + 3.0, lit) : col;
}

// 6 (the Casino's): a slot machine, three reels showing sevens, and a lever.
vec3 wd_slot(vec2 p, float t, float aa, vec3 bg, vec3 fg, vec3 ac, float seed, bool side, out float lit) {
	vec3 col = mix(bg * 0.55, bg * 0.95, p.y + 0.5);
	vec2 q = p - vec2(-0.3, 0.0);
	float cab = wd_cov(wd_rbox(q, vec2(0.4, 0.4), 0.06), aa);
	col = mix(col, ac, cab);
	col = mix(col, bg * 0.5, wd_cov(wd_rbox(q - vec2(0.0, 0.03), vec2(0.34, 0.24), 0.03), aa));
	float reels = 0.0;
	float sevens = 0.0;
	for (int i = 0; i < 3; i++) {
		vec2 r = q - vec2(-0.215 + 0.215 * float(i), 0.03);
		reels = max(reels, wd_cov(wd_rbox(r, vec2(0.09, 0.2), 0.02), aa));
		sevens = max(sevens, wd_cov(wd_digit(r / 0.23, 7) * 0.23, aa));
	}
	col = mix(col, fg, reels);
	col = mix(col, bg * 0.6, sevens * reels);
	col = mix(col, fg, wd_cov(wd_rbox(q + vec2(0.0, 0.3), vec2(0.16, 0.03), 0.02), aa));
	float lever = wd_cov(wd_seg(q, vec2(0.44, 0.1), vec2(0.5, 0.3)) - 0.012, aa);
	float knob = wd_cov(length(q - vec2(0.5, 0.31)) - 0.04, aa);
	col = mix(col, fg, max(lever, knob));
	lit = max(max(cab * 0.6, reels), max(sevens, knob));
	return side ? wd_side(col, p, aa, fg, ac, seed + 4.0, lit) : col;
}

// 7 (the Casino's): three stacks of chips.
vec3 wd_chips(vec2 p, float t, float aa, vec3 bg, vec3 fg, vec3 ac, float seed, bool side, out float lit) {
	vec3 col = mix(bg * 0.55, bg * 0.95, p.y + 0.5);
	float chips = 0.0;
	for (int s = 0; s < 3; s++) {
		float fs = float(s);
		int count = 3 + (s * 2) % 3;
		for (int i = 0; i < 5; i++) {
			if (i >= count) {
				break;
			}
			vec2 q = p - vec2(-0.52 + 0.22 * fs, -0.3 + 0.062 * float(i));
			float chip = wd_cov(wd_rbox(q, vec2(0.1, 0.026), 0.02), aa);
			float notch = wd_cov(wd_box(vec2(abs(q.x) - 0.065, q.y), vec2(0.02, 0.02)), aa);
			vec3 tone = ((i + s) % 2 == 0) ? fg : ac;
			col = mix(col, tone, chip);
			col = mix(col, bg * 0.5, notch * chip * 0.8);
			chips = max(chips, chip);
		}
	}
	lit = chips;
	return side ? wd_side(col, p, aa, fg, ac, seed + 5.0, lit) : col;
}

// 8 (the Casino's): a cocktail in a cone glass with an olive on a stick.
vec3 wd_cocktail(vec2 p, float t, float aa, vec3 bg, vec3 fg, vec3 ac, float seed, bool side, out float lit) {
	vec3 col = mix(bg * 0.6, bg, p.y + 0.5);
	vec2 q = p - vec2(-0.3, -0.04);
	float half_width = 0.26 * clamp((q.y + 0.02) / 0.34, 0.0, 1.0);
	float cone = wd_cov(max(abs(q.x) - half_width, max(-(q.y + 0.02), q.y - 0.32)) * 0.8, aa);
	float liquid = cone * wd_cov(q.y - 0.2, aa);
	float stem = wd_cov(wd_box(q + vec2(0.0, 0.13), vec2(0.016, 0.11)), aa);
	float foot = wd_cov(wd_rbox(q + vec2(0.0, 0.25), vec2(0.11, 0.02), 0.015), aa);
	col = mix(col, fg * 0.9, max(cone, max(stem, foot)));
	col = mix(col, ac, liquid);
	float stick = wd_cov(wd_seg(q, vec2(0.02, 0.1), vec2(0.15, 0.44)) - 0.007, aa);
	float olive = wd_cov(length(q - vec2(0.05, 0.19)) - 0.034, aa);
	col = mix(col, fg, stick);
	col = mix(col, bg * 0.5, olive);
	lit = max(max(cone, max(stem, foot)), max(liquid, stick));
	return side ? wd_side(col, p, aa, fg, ac, seed + 6.0, lit) : col;
}

// 9 (the Casino's): a pair of dice.
vec3 wd_dice(vec2 p, float t, float aa, vec3 bg, vec3 fg, vec3 ac, float seed, out float lit) {
	vec3 col = mix(bg * 0.55, bg * 0.95, p.y + 0.5);
	vec2 a = p - vec2(-0.42, 0.04);
	vec2 ra = vec2(0.955 * a.x + 0.296 * a.y, -0.296 * a.x + 0.955 * a.y);
	float die_a = wd_cov(wd_rbox(ra, vec2(0.17, 0.17), 0.04), aa);
	vec2 b = p - vec2(-0.1, -0.06);
	vec2 rb = vec2(0.98 * b.x - 0.199 * b.y, 0.199 * b.x + 0.98 * b.y);
	float die_b = wd_cov(wd_rbox(rb, vec2(0.14, 0.14), 0.035), aa);
	col = mix(col, fg, die_a);
	col = mix(col, ac, die_b);
	float pips_a = wd_cov(length(ra) - 0.026, aa);
	for (int i = 0; i < 4; i++) {
		vec2 o = vec2((i % 2 == 0) ? -0.09 : 0.09, (i < 2) ? -0.09 : 0.09);
		pips_a = max(pips_a, wd_cov(length(ra - o) - 0.026, aa));
	}
	float pips_b = max(wd_cov(length(rb - vec2(-0.07, 0.07)) - 0.024, aa), wd_cov(length(rb - vec2(0.07, -0.07)) - 0.024, aa));
	col = mix(col, bg * 0.5, pips_a * die_a);
	col = mix(col, fg, pips_b * die_b);
	lit = max(die_a, die_b);
	return wd_side(col, p, aa, fg, ac, seed + 7.0, lit);
}

// 0: the market's own ad (kit_market_signs.gdshaderinc, mk_ad), a brand mark and lines of text with a slow sweep of light.
vec3 wd_brand(vec2 uv, float t, vec3 bg, float seed, out float lit) {
	float m;
	vec3 col = mk_ad(min(bg * 1.3, vec3(1.0)), uv, seed, t, m);
	lit = m;
	return col;
}

// Scene `id` (0-9) at p, in the colours bg (dark), fg (the drawn things) and ac (the accent); `uv` is the
// screen's own, for the market's ad. lit: 0-1, how much of the picture's glow each pixel takes.
vec3 wd_scene(int id, vec2 p, vec2 uv, float t, float aa, vec3 bg, vec3 fg, vec3 ac, float seed, out float lit) {
	if (id == 1) {
		return wd_bowl(p, t, aa, bg, fg, ac, seed, true, lit);
	} else if (id == 2) {
		return wd_bottle(p, t, aa, bg, fg, ac, seed, true, lit);
	} else if (id == 3) {
		return wd_drone(p, t, aa, bg, fg, ac, seed, lit);
	} else if (id == 4) {
		return wd_sale(p, t, aa, bg, fg, ac, seed, lit);
	} else if (id == 5) {
		return wd_cup(p, t, aa, bg, fg, ac, seed, true, lit);
	} else if (id == 6) {
		return wd_slot(p, t, aa, bg, fg, ac, seed, true, lit);
	} else if (id == 7) {
		return wd_chips(p, t, aa, bg, fg, ac, seed, true, lit);
	} else if (id == 8) {
		return wd_cocktail(p, t, aa, bg, fg, ac, seed, true, lit);
	} else if (id == 9) {
		return wd_dice(p, t, aa, bg, fg, ac, seed, lit);
	}
	return wd_brand(uv, t, bg, seed, lit);
}

// The colours of the scene shown in slot k of a screen: a dark background, the drawn things and an accent.
void wd_colours(float seed, float k, out vec3 bg, out vec3 fg, out vec3 ac) {
	int ci = int(floor(hash11(seed * 5.3 + k * 1.7 + 0.5) * 3.0));
	bg = wd_palette[ci];
	fg = hash11(seed * 2.9 + k * 3.1 + 1.5) < 0.6 ? wd_palette[3] : wd_palette[4];
	ac = ci == 0 ? wd_palette[5] : (ci == 1 ? wd_palette[4] : wd_palette[0]);
}

// The cult emblem's coverage at e (its square spans -1 to 1, y up), fw a pixel's footprint there: the mip level comes
// from it, so the mark averages into a soft blob as it shrinks, and below about 50 pixels it is thickened to hold up (its
// thin arrows would otherwise melt into the dark); it fades out only where it is a few pixels across.
float wd_mark(vec2 e, float fw) {
	float size = float(textureSize(wd_emblem_tex, 0).x);
	float lod = log2(max(fw * 0.5 * size, 1.0));
	float inside = step(abs(e.x), 1.0) * step(abs(e.y), 1.0);
	float cov = textureLod(wd_emblem_tex, vec2(e.x, -e.y) * 0.5 + 0.5, lod).a * inside;
	float pixels = 2.0 / max(fw, 1e-5);
	cov = min(cov * mix(1.0, 2.4, smoothstep(50.0, 16.0, pixels)), 1.0);
	return cov * smoothstep(3.0, 7.0, pixels);
}

// The ad screen's picture (sRGB) at uv (UV.y 0-1 up the screen, UV.x in the same units, `aspect` wide), `seed` its
// own (0-999), t the time, fw = fwidth(uv). glow_mask (0-1) is how much of the picture's glow each pixel takes.
vec3 wd_ad(vec2 uv, float aspect, float seed, float t, vec2 fw, out float glow_mask) {
	vec2 p = vec2(uv.x - aspect * 0.5, uv.y - 0.5);
	float aa = max(fw.x, fw.y) * 1.5 + 1e-4;
	float slot = mix(wd_scene_time.x, wd_scene_time.y, hash11(seed * 1.31 + 3.0));
	float tt = (t + hash11(seed * 2.17 + 1.0) * 60.0) / slot;
	float k = floor(tt);
	float f = tt - k;
	// Four scenes of the six, in a seeded order, round and round: one at a time, each drawn by its own number whatever
	// the moment, so nothing jumps when the next comes in.
	int first = int(floor(hash11(seed * 0.73 + 5.0) * 6.0));
	int stride = hash11(seed * 4.1 + 9.0) < 0.5 ? 1 : 5;
	int index = (first + stride * int(mod(k, 4.0))) % 6;
	int id = wd_casino == 1 ? WD_CASINO_SCENES[index] : index;
	vec3 bg;
	vec3 fg;
	vec3 ac;
	wd_colours(seed, k, bg, fg, ac);
	float lit;
	vec3 col = wd_scene(id, p, uv, t, aa, bg, fg, ac, seed + float(id), lit);
	// A change of ad is a dip through the screen's deep indigo and back up (never two pictures at once: a pixel draws one
	// scene), quicker than the picture holds, slower with Reduced flashing.
	vec3 dusk = wd_palette[2] * 0.55;
	float dip = mix(wd_dip.x, wd_dip.y, reduced_flashing);
	float up = smoothstep(0.0, dip, f) * (1.0 - smoothstep(1.0 - dip, 1.0, f));
	col = mix(dusk, col, up);
	lit = mix(0.45, lit, up);
	// The cult's emblem, flashed onto the screen every once in a while: in quickly (never a hard cut), held, out more
	// slowly; with Reduced flashing in and out over most of a second and held for two. It is drawn big, in the emblem's
	// warm white on a deep dusk of the screen's own palette (never black: the screen is still on) over a soft halo, so it
	// still reads from a distance as a bright mark on a panel of its own, not a dark gap in the street.
	float period = mix(wd_flash_period.x, wd_flash_period.y, hash11(seed * 6.7 + 2.0));
	float ph = t + hash11(seed * 8.9 + 4.0) * period;
	ph -= period * floor(ph / period);
	vec3 times = mix(wd_flash, wd_flash_reduced, reduced_flashing);
	float env = smoothstep(0.0, times.x, ph) * (1.0 - smoothstep(times.x + times.y, times.x + times.y + times.z, ph));
	if (env > 0.001) {
		float mark = wd_mark(p / 0.46, max(fw.x, fw.y) / 0.46);
		vec3 e_col = wd_palette[2] * 0.55 + wd_emblem * (0.3 * exp(-dot(p, p) * 8.0));
		e_col = mix(e_col, wd_emblem, mark);
		col = mix(col, e_col, env);
		lit = mix(lit, 0.45 + 0.55 * mark, env);
	}
	// A flat panel: a little darker toward its corners.
	vec2 q = p / vec2(aspect * 0.5, 0.5);
	col *= 1.0 - 0.08 * dot(q, q);
	glow_mask = mix(0.5, 1.0, clamp(lit, 0.0, 1.0));
	return col;
}

// A poster (sRGB) at uv (UV.y 0-1 up the poster, UV.x in the same units, `aspect` wide) of `kind` (1-4: WindowDisplay.SIGN
// to PRODUCT), painted in `base`; seed 0-999.
vec3 wd_poster(vec2 uv, float aspect, float seed, int kind, vec3 base, vec2 fw) {
	vec2 p = vec2(uv.x - aspect * 0.5, uv.y - 0.5);
	float aa = max(fw.x, fw.y) * 1.5 + 1e-4;
	vec3 cream = vec3(0.93, 0.9, 0.82);
	vec3 col;
	float lit;
	if (kind == 1) {
		// A shop's own sign: the market's painted shop-sign face (kit_market_signs.gdshaderinc, mk_shopsign).
		col = mk_shopsign(base, uv * WD_SIGN_HEIGHT, mod(seed, 100.0) + 100.0 * floor(WD_SIGN_HEIGHT * 10.0 + 0.5));
	} else if (kind == 2) {
		// A sale: cream paper, a starburst in the poster's colour, a number and a percent sign, a thin border.
		vec3 paper = mix(cream, base, 0.1);
		vec3 b = wd_burst((p + vec2(0.0, 0.02)) * 1.1, 0.0, aa * 1.1, seed);
		col = mix(paper, base * 0.85, b.x);
		col = mix(col, paper, b.y);
		col = mix(col, base * 0.45, b.z);
		col = mix(col, base * 0.6, wd_cov(abs(wd_box(p, vec2(aspect * 0.5 - 0.04, 0.46))) - 0.006, aa));
	} else if (kind == 3) {
		// A menu board: a dark slate, a logo disc and rows of dishes with their prices.
		vec3 slate = base * 0.3 + vec3(0.03);
		col = slate;
		float rows = 0.0;
		for (int i = 0; i < 5; i++) {
			float y = 0.28 - float(i) * 0.14;
			float len = 0.1 + 0.07 * hash11(seed + float(i) * 1.9);
			rows = max(rows, wd_cov(wd_rbox(p - vec2(-0.12 + len - 0.1, y), vec2(len, 0.02), 0.018), aa));
			rows = max(rows, wd_cov(wd_rbox(p - vec2(0.2, y), vec2(0.04, 0.02), 0.018), aa));
			rows = max(rows, wd_cov(length(p - vec2(-0.25, y)) - 0.028, aa));
		}
		col = mix(col, cream, rows * 0.88);
		float disc = wd_cov(length(p - vec2(0.0, 0.43)) - 0.07, aa);
		col = mix(col, cream, disc);
		col = mix(col, slate, market_logo((p - vec2(0.0, 0.43)) / 0.05, seed) * disc);
	} else {
		// A product: a drawn thing on a gradient in the poster's colour, with a brand disc.
		vec3 bg = mix(base * 0.55, base * 1.1, uv.y);
		vec3 ac = mix(base, vec3(1.0), 0.55);
		vec2 s = p * 0.8 + vec2(-0.3, 0.0);
		int k = int(mod(seed, 3.0));
		if (wd_casino == 1) {
			if (k == 0) {
				col = wd_cocktail(s, 0.0, aa * 0.8, bg, cream, ac, seed, false, lit);
			} else if (k == 1) {
				col = wd_chips(s, 0.0, aa * 0.8, bg, cream, ac, seed, false, lit);
			} else {
				col = wd_bottle(s, 0.0, aa * 0.8, bg, cream, ac, seed, false, lit);
			}
		} else {
			if (k == 0) {
				col = wd_bowl(s, 0.0, aa * 0.8, bg, cream, ac, seed, false, lit);
			} else if (k == 1) {
				col = wd_bottle(s, 0.0, aa * 0.8, bg, cream, ac, seed, false, lit);
			} else {
				col = wd_cup(s, 0.0, aa * 0.8, bg, cream, ac, seed, false, lit);
			}
		}
		vec2 c = vec2(-aspect * 0.5 + 0.12, 0.38);
		float disc = wd_cov(length(p - c) - 0.075, aa);
		col = mix(col, cream, disc);
		col = mix(col, bg, market_logo((p - c) / 0.052, seed + 5.0) * disc);
		col = mix(col, cream, wd_cov(wd_rbox(p - vec2(0.0, -0.4), vec2(aspect * 0.28, 0.02), 0.018), aa) * 0.9);
	}
	// Paper: a little grain (gone where a pixel spans several of its cells, or it would shimmer) and a soft light from
	// above, so it reads as lit, not glowing.
	float grain = 1.0 + (value_noise(uv * 40.0 + seed) - 0.5) * 0.1 * (1.0 - smoothstep(0.012, 0.04, max(fw.x, fw.y)));
	return col * grain * (0.9 + 0.14 * uv.y);
}

// WindowDisplay.param()'s fields: x the seed, y the aspect (width over height).
vec2 wd_params(float param) {
	float c = floor(param + 0.5);
	float tenths = floor((c + 0.5) / 1000.0);
	return vec2(c - tenths * 1000.0, tenths * 0.1);
}

// The panel's picture (sRGB) for `kind` (0 an ad screen, 1-4 a poster), and for the screens the glow mask (a poster never
// glows).
vec3 window_surface(int kind, float param, vec3 base, vec2 uv, vec2 fw, float t, inout float glow) {
	vec2 q = wd_params(param);
	if (kind == 0) {
		float mask;
		vec3 c = wd_ad(uv, q.y, q.x, t, fw, mask);
		glow *= mask;
		return c;
	}
	return wd_poster(uv, q.y, q.x, kind, base, fw);
}

// Marketplace surfaces for the solid kit shader (kit_solid.gdshader): pattern ids 20-29
// (MeshKit.PAT_CANVAS ...), in their own file so other zones' patterns don't collide with them.
// Each function takes the fragment's world position `w`, world normal `n`, UV and pattern
// parameter, and returns the albedo (sRGB, like COLOR). Glowing patterns also return a glow mask.
// Pixel footprints (fwidth) are taken where every pixel of a 2x2 block runs the same code (at the top
// of a pattern's function, whose pattern is the same over a whole face) and passed down: PAT_STALLS
// picks each stall's roof per pixel, and a derivative taken inside a branch that differs between
// neighbouring pixels is undefined (a NaN there becomes a white disc in the glow pass).

// The pale stripes on striped awnings.
uniform vec3 canvas_stripe : source_color = vec3(0.82, 0.8, 0.74);
// The lamps inside the stalls, lighting the goods on their counters.
uniform vec3 goods_light : source_color = vec3(1.0, 0.88, 0.7);
// The stalls' frame: the pole across each stall's start and the valleys along the lanes' edges.
uniform vec3 canvas_pole : source_color = vec3(0.4, 0.34, 0.27);
// The stall rows (PAT_STALLS), laid out exactly as MarketStalls lays them out: slots along each lane,
// a stall covering 1-3 of them, its roof picked from these (sRGB, like COLOR).
uniform float stall_slot = 2.0;
uniform float stall_awning_share = 0.22;
uniform float stall_tin_share = 0.2;
uniform vec3 stall_canvas[4];
uniform vec3 stall_awning[2];
uniform vec3 stall_tin = vec3(0.47, 0.46, 0.44);

// MeshKit.hash_i, bit for bit (32-bit integer mixing), so the shader and the scripts pick the same
// stall for the same slot. Inputs must not be negative (callers add an offset).
uint kit_hash_u(int a, int b, int c) {
	uint h = uint(a) * 0x27d4eb2du;
	h ^= uint(b) * 0x165667b1u + 0x3c6ef372u;
	h ^= uint(c) * 0x1b873593u + 0x68e31da4u;
	h = (h ^ (h >> 15u)) * 0x2c1b3c6du;
	h = (h ^ (h >> 12u)) * 0x297a2d39u;
	return h ^ (h >> 15u);
}

// MeshKit.hash01, bit for bit.
float kit_hash01(int a, int b, int c) {
	return float(kit_hash_u(a, b, c) & 0xFFFFFFu) / 16777216.0;
}

// Goods on display: splashes of colour, always lit, never glowing (GDD §5 colour rule).
vec3 mk_goods_color(float r) {
	if (r < 0.16) return vec3(0.66, 0.2, 0.14);   // tomatoes, peppers
	if (r < 0.3) return vec3(0.8, 0.46, 0.14);    // oranges, spices
	if (r < 0.44) return vec3(0.74, 0.64, 0.2);   // lemons, bananas
	if (r < 0.56) return vec3(0.3, 0.5, 0.22);    // greens
	if (r < 0.68) return vec3(0.44, 0.24, 0.46);  // aubergines, silk
	if (r < 0.8) return vec3(0.22, 0.38, 0.62);   // blue cloth, pottery
	if (r < 0.9) return vec3(0.82, 0.78, 0.68);   // bread, rice, linen
	return vec3(0.46, 0.3, 0.2);                  // nuts, leather
}

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

// A stall roof's shape, faked in shading (the running surface itself stays flat): a ridge along the
// lane's middle with the two halves catching the light differently, eaves darkening toward the lane
// edges, and the cloth sagging between the frame poles at the stall's ends. q: 0-1 across, along.
float mk_tent(vec2 q) {
	float x = q.x * 2.0 - 1.0;
	float half_light = mix(0.9, 1.06, smoothstep(-0.08, 0.08, x));
	float ridge = 1.0 + 0.1 * (1.0 - smoothstep(0.0, 0.05, abs(x)));
	float eaves = 1.0 - 0.16 * smoothstep(0.72, 1.0, abs(x));
	float sag = 1.0 - 0.07 * sin(clamp(q.y, 0.0, 1.0) * 3.14159) * (1.0 - abs(x));
	return half_light * ridge * eaves * sag;
}

// A stall's frame drawn over its roof (q: 0-1 across the lane, along the stall; len: the stall's
// length; fd: a pixel's footprint along the track, fq across the lane in q.x units): the pole across
// its start and the valleys along the lane's edges.
vec3 mk_frame(vec3 col, vec2 q, float len, float fd, float fq) {
	float d = q.y * len;
	float pole = 1.0 - smoothstep(0.08 - fd, 0.08 + fd, d);
	float e = min(q.x, 1.0 - q.x);
	float fe = max(fq, 1e-4);
	float valley = 1.0 - smoothstep(0.009 - fe, 0.009 + fe, e);
	return mix(col, canvas_pole, max(pole, valley));
}

// The scalloped hem of a stall's canvas along its leading edge (toward the player), just past the
// frame pole: `d` metres from the stall's start, `x` 0-1 across, fw a pixel's footprint along the
// track. Returns (hem, shadow).
vec2 mk_hem(float d, float x, float fw) {
	float sc = abs(sin(x * 3.14159 * 5.0));
	float edge = 0.18 + 0.11 * sc;
	float hem = 1.0 - smoothstep(edge - fw, edge + fw, d);
	float shadow = (1.0 - smoothstep(edge + 0.02, edge + 0.09, d)) * (1.0 - hem);
	return vec2(hem, shadow);
}

// A pixel's footprint for the roof patterns: fwidth of world x, world z and UV.x, taken by the
// caller outside any per-pixel branch.
vec3 mk_footprint(vec3 w, vec2 uv) {
	return vec3(fwidth(w.x), fwidth(w.z), fwidth(uv.x));
}

// Canvas (PAT_CANVAS, below) with its stripes (`mode`), the stall's length (`len`, 0: no hem or
// frame) and the pixel's footprint (`fp`, mk_footprint) given.
vec3 mk_canvas_at(vec3 base, vec3 w, vec2 uv, float mode, float len, vec3 fp) {
	vec2 p = w.xz;
	float fw = max(fp.x, fp.y);
	float fz = max(fp.y, 1e-4);
	float detail = 1.0 - smoothstep(0.02, 0.15, fw);
	vec3 col = base;
	vec3 stripe = mix(base, canvas_stripe, 0.42);
	if (mode > 0.5 && mode < 1.5) {
		col = mix(col, stripe, filtered_pulse(uv.x * 6.0, fp.z * 6.0, 0.0, 0.5));
	} else if (mode > 1.5) {
		col = mix(col, stripe, filtered_pulse(w.z / 0.6, fp.y / 0.6, 0.0, 0.5));
	}
	col *= mk_tent(clamp(uv, 0.0, 1.0));
	if (len > 0.0) {
		vec2 hem = mk_hem(uv.y * len, uv.x, fz);
		col = mix(col, mix(base, canvas_stripe, 0.55) * 0.95, hem.x);
		col *= 1.0 - 0.22 * hem.y;
		col = mk_frame(col, clamp(uv, 0.0, 1.0), len, fz, fp.z);
	}
	// Sewn panels across the canvas, weathering and a faint weave.
	col *= 1.0 - 0.08 * filtered_pulse(w.z / 1.3, fp.y / 1.3, 0.0, 0.03);
	col *= 0.93 + 0.12 * value_noise(p * vec2(0.9, 0.35) + base.r * 7.0);
	col *= 1.0 + 0.05 * detail * (hash12(floor(p * 36.0)) - 0.5);
	return col;
}

// PAT_CANVAS (20): canvas roofs and awnings stretched over a stall's frame. UV runs 0-1 across the
// panel (x) and along the whole stall (y). param = stripes (0 plain, 1 along the track, 2 across
// it) + 4 * the stall's length in decimetres (0: no hem). Stripes are soft (half-way to the stripe
// colour), so an awning never reads as a road marking.
vec3 mk_canvas(vec3 base, vec3 w, vec2 uv, float param) {
	return mk_canvas_at(base, w, uv, mod(floor(param + 0.5), 4.0), floor((param + 0.5) / 4.0) * 0.1,
		mk_footprint(w, uv));
}

// Tin (PAT_TIN, below) with its ribs (`mode`), the stall's length (`len`, 0: no ridge cap or
// frame) and the pixel's footprint (`fp`, mk_footprint) given.
vec3 mk_tin_at(vec3 base, vec3 w, vec2 uv, float mode, float len, vec3 fp) {
	vec2 p = w.xz;
	float fd = max(fp.y, 1e-4);
	base *= mk_tent(clamp(uv, 0.0, 1.0));
	if (len > 0.0) {
		float d = uv.y * len;
		base *= 1.0 + 0.12 * (1.0 - smoothstep(0.16 - fd, 0.16 + fd, d)) - 0.15 * (smoothstep(0.16, 0.2, d) - smoothstep(0.2, 0.3, d));
	}
	float along = mode < 0.5 ? p.x : p.y;
	float across = mode < 0.5 ? p.y : p.x;
	float f_along = mode < 0.5 ? fp.x : fp.y;
	float f_across = mode < 0.5 ? fp.y : fp.x;
	float rib = filtered_pulse(along / 0.14, f_along / 0.14, 0.0, 0.45);
	vec3 col = base * (1.06 - 0.2 * rib);
	col *= 0.9 + 0.16 * hash11(floor(across / 2.1) * 3.7 + floor(along / 2.4));
	col *= 1.0 - 0.3 * filtered_pulse(across / 2.1, f_across / 2.1, 0.0, 0.02);
	col = mix(col, vec3(0.42, 0.3, 0.22), smoothstep(0.55, 0.85, value_noise(p * vec2(1.4, 0.5) + 3.0)) * 0.45);
	col = mix(col, vec3(0.62, 0.55, 0.46), smoothstep(0.5, 0.9, value_noise(p * 0.4 + 9.0)) * 0.35);
	if (len > 0.0) {
		col = mk_frame(col, clamp(uv, 0.0, 1.0), len, fd, fp.z);
	}
	return col;
}

// PAT_TIN (21): corrugated sheet metal on stall roofs, with overlapping sheets, dust and rust.
// UV as for canvas (the roof's shape); param = ribs (0 along the track, 1 across it) + 4 * the
// stall's length in decimetres (for the ridge cap along its leading edge).
vec3 mk_tin(vec3 base, vec3 w, vec2 uv, float param) {
	return mk_tin_at(base, w, uv, mod(floor(param + 0.5), 4.0), floor((param + 0.5) / 4.0) * 0.1,
		mk_footprint(w, uv));
}

// Whether a stall starts at `slot` in the lane keyed `lane` (both offset to stay positive): every
// third slot, and by hash 45% of the others (MarketStalls.starts()).
bool mk_stall_starts(int lane, int slot) {
	return slot % 3 == 0 || kit_hash01(lane, slot, 7) < 0.45;
}

// PAT_STALLS (28): a whole row of stall roofs along one lane, laid out here rather than as one quad
// per stall: the stall under each point from its slot, then its roof (canvas, a blue awning or tin),
// shape, hem and frame. UV.x runs 0-1 across the lane; param = the lane's key (offset, positive).
// MarketStalls mirrors every choice, bit for bit, for the faces it builds at gap edges. The roof
// differs from stall to stall, so the footprint is taken here, before choosing.
vec3 mk_stalls(vec3 w, vec2 uv, float param) {
	vec3 fp = mk_footprint(w, uv);
	int lane = int(param + 0.5);
	float dist = -w.z;
	int si = int(floor(dist / stall_slot)) + 100000;
	int s0 = si;
	for (int j = 0; j < 2 && !mk_stall_starts(lane, s0); j++) {
		s0 -= 1;
	}
	int s1 = si + 1;
	for (int j = 0; j < 2 && !mk_stall_starts(lane, s1); j++) {
		s1 += 1;
	}
	float d0 = float(s0 - 100000) * stall_slot;
	float len = float(s1 - s0) * stall_slot;
	vec2 q = vec2(uv.x, (dist - d0) / len);
	float r = kit_hash01(lane, s0, 11);
	uint k = kit_hash_u(lane, s0, 12);
	if (r < stall_awning_share) {
		return mk_canvas_at(stall_awning[k % 2u], w, q, (k >> 4u) % 5u < 3u ? 1.0 : 0.0, len, fp);
	}
	if (r < stall_awning_share + stall_tin_share) {
		float tone = 0.92 + 0.12 * float((k >> 7u) % 64u) / 63.0;
		return mk_tin_at(stall_tin * tone, w, q, float((k >> 3u) % 2u), len, fp);
	}
	vec3 canvas = stall_canvas[kit_hash_u(lane, s0, 13) % 4u];
	return mk_canvas_at(canvas, w, q, (k >> 5u) % 6u == 0u ? 2.0 : 0.0, len, fp);
}

// PAT_STALL (22): the faces of a stall below its roof (its front at a gap, its back, its sides), by
// world height: the scalloped valance of the roof's canvas, an upper storey of boards, a curtain or
// a painted board, then a counter heaped with goods, dimming toward the market floor far below.
// param = mode (0 front, 1 side, 2 back) + 4 * seed (whole numbers).
vec3 mk_stall(vec3 base, vec3 w, vec3 n, float param) {
	float mode = mod(param, 4.0);
	float seed = floor(param / 4.0);
	float h = abs(n.x) > 0.5 ? w.z : w.x;
	float y = w.y;
	float fh = fwidth(h);
	float fy = fwidth(y);
	float r1 = hash11(seed * 1.31 + 0.7);
	float r2 = hash11(seed * 2.17 + 3.1);
	vec3 wood = vec3(0.4, 0.3, 0.21) * (0.85 + 0.3 * r2);
	vec3 col;
	if (mode > 1.5) {
		// Back: plain boards.
		col = wood * (1.0 - 0.35 * filtered_pulse(h / 0.24, fh / 0.24, 0.0, 0.08))
			* (0.85 + 0.2 * hash11(floor(h / 0.24) + seed));
	} else if (mode > 0.5) {
		// Side: canvas curtains in deep folds, crates and sacks stacked below them.
		col = base * 0.9 * (0.72 + 0.28 * sin(h * 7.0 + seed));
		if (y < -3.1) {
			vec2 cell = floor(vec2(h / 0.7, (y + 3.1) / 0.55));
			col = mix(wood, mk_goods_color(hash12(cell + seed)) * 0.8, step(0.55, hash12(cell * 1.7 + seed)))
				* (0.8 + 0.25 * hash12(cell + 7.0));
		}
	} else if (y > -2.8) {
		// Front, upper storey: boards, a curtain or a painted board with a band of chunky letters.
		if (r1 < 0.4) {
			col = wood * (1.0 - 0.3 * filtered_pulse(h / 0.2, fh / 0.2, 0.0, 0.1))
				* (0.85 + 0.25 * hash11(floor(h / 0.2) + seed * 3.0));
		} else if (r1 < 0.72) {
			col = base * 0.85 * (0.75 + 0.25 * sin(h * 9.0 + seed));
		} else {
			// Painted in the goods' cooler colours only: a yellow board would echo a hazard sign.
			vec3 field = mk_goods_color(0.44 + r2 * 0.46) * 0.9 + 0.08;
			float lx = h / 0.34;
			float row = step(-1.9, y) * step(y, -1.2);
			float letter = step(0.35, hash11(floor(lx) + seed * 5.0)) * filtered_pulse(lx, fh / 0.34, 0.15, 0.85);
			col = mix(field, vec3(0.9, 0.87, 0.8), letter * row);
		}
	} else if (y > -4.3) {
		// Front, the counter: goods in heaps, lit warm by the stall's lamp.
		vec2 g = vec2(h / 0.26, (y + 4.3) / 0.22);
		vec2 cell = floor(g);
		float r = hash12(cell + seed * 3.3);
		vec3 goods = mk_goods_color(fract(hash12(vec2(floor(h / 0.8), seed)) * 0.7 + r * 0.3));
		float heap = 1.0 - smoothstep(0.25, 0.5, length(fract(g) - 0.5));
		col = mix(goods * 0.7, goods, heap) * (0.85 + 0.3 * r);
		col = mix(col, wood * 0.7, step(y, -4.05));
		col *= mix(vec3(1.0), goods_light * 1.5, smoothstep(-4.3, -3.0, y));
	} else {
		col = wood * 0.8 * (1.0 - 0.3 * filtered_pulse(h / 0.3, fh / 0.3, 0.0, 0.08));
	}
	// The valance: the roof's canvas hanging over the top of every face, scalloped along its hem.
	float sc = fract(h / 0.32);
	float hem = -0.3 - 0.12 * sin(sc * 3.14159);
	col = mix(col, base * (1.0 - 0.1 * sin(sc * 3.14159)), clamp((y - hem) / max(fy, 1e-4) + 0.5, 0.0, 1.0));
	// Deeper is dimmer: the stalls stand in the shade of their neighbours' roofs.
	return col * mix(1.0, 0.3, smoothstep(-0.6, -6.5, y));
}

// PAT_TILES (23): param 0: the market floor's worn stone flags (world xz); 1: the plastered soffit
// under buildings and overpasses, crossed by beams every 3 m (world xz, seen from below; the beams
// stream past a player riding the ceiling).
vec3 mk_tiles(vec3 base, vec3 w, float param) {
	vec2 p = w.xz;
	vec2 fwp = fwidth(p);
	if (param > 0.5) {
		float bq = p.y / 3.0;
		float f = fract(bq);
		float beam = filtered_pulse(bq, fwp.y / 3.0, 0.0, 0.12);
		float bay = smoothstep(0.12, 0.3, f) * (1.0 - smoothstep(0.84, 1.0, f));
		vec3 col = base * (0.95 + 0.08 * hash11(floor(bq) + 3.0)) * (0.86 + 0.14 * bay);
		col = mix(col, base * 0.6, beam);
		return col * (0.93 + 0.1 * value_noise(p * 0.35));
	}
	vec2 q = p / 0.55;
	q.x += 0.5 * mod(floor(q.y), 2.0);
	vec2 fq = fwp / 0.55;
	float grout = max(filtered_pulse(q.x, fq.x, 0.0, 0.07), filtered_pulse(q.y, fq.y, 0.0, 0.07));
	return base * (0.85 + 0.25 * hash12(floor(q) + 1.0)) * (1.0 - 0.35 * grout) * (0.85 + 0.25 * value_noise(p * 0.25));
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

// PAT_BULBS (26): rows of light bulbs on a dark panel (casino marquees): UV in metres, bulbs every
// 0.32 m glowing (COLOR.a). A slow wave of brightness runs along them, steady with Reduced flashing.
vec3 mk_bulbs(vec3 base, vec2 uv, float t, float reduced, out float glow_mask) {
	vec2 q = uv / 0.32;
	float fw = max(max(fwidth(q.x), fwidth(q.y)), 1e-4);
	float bulb = 1.0 - smoothstep(0.18 - fw, 0.18 + fw, length(fract(q) - 0.5));
	bulb = mix(bulb, 0.25, smoothstep(0.15, 0.5, fw));
	glow_mask = bulb * mix(0.75 + 0.25 * sin(floor(q.x) * 0.9 - t * 2.2), 0.9, reduced);
	return mix(vec3(0.05, 0.045, 0.04), base, bulb);
}

// PAT_STUCCO (27): sun-bleached plaster on buildings' solid parts (cornices, bridge faces, parapets).
vec3 mk_stucco(vec3 base, vec3 w, vec3 n) {
	vec2 p = abs(n.y) > 0.5 ? w.xz : (abs(n.x) > 0.5 ? w.zy : w.xy);
	vec3 col = base * (0.9 + 0.14 * value_noise(p * vec2(0.8, 0.5)));
	return col * (1.0 - 0.12 * smoothstep(0.55, 0.8, value_noise(p * 0.12 + 4.0)));
}

// Dispatches the Marketplace patterns (ids 20-29) for kit_solid.gdshader.
vec3 market_surface(int pattern, float param, vec3 base, vec3 w, vec3 n, vec2 uv, float t, inout float glow) {
	if (pattern == 20) {
		return mk_canvas(base, w, uv, param);
	} else if (pattern == 21) {
		return mk_tin(base, w, uv, param);
	} else if (pattern == 22) {
		return mk_stall(base, w, n, param);
	} else if (pattern == 23) {
		return mk_tiles(base, w, param);
	} else if (pattern == 24) {
		return mk_shopsign(base, uv, param);
	} else if (pattern == 25) {
		float m;
		vec3 c = mk_ad(base, uv, param, t, m);
		glow *= m;
		return c;
	} else if (pattern == 26) {
		float m;
		vec3 c = mk_bulbs(base, uv, t, reduced_flashing, m);
		glow *= m;
		return c;
	} else if (pattern == 27) {
		return mk_stucco(base, w, n);
	} else if (pattern == 28) {
		return mk_stalls(w, uv, param);
	}
	return base;
}

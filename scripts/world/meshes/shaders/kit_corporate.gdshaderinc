// Corporate surfaces for the solid kit shader (kit_solid.gdshader): pattern ids 30-39
// (MeshKit.PAT_CORP_*), in their own file so other zones' patterns don't collide with them. The
// Corporate zone (CorporateSkin, GDD §5): steel and gunmetal, military olive, cold sterile white light
// and one harsh brand colour. Each function takes the fragment's world position `w`, world normal `n`,
// UV and pattern parameter and returns the albedo (sRGB, like COLOR); glowing patterns also shape the
// glow. Pixel footprints (fwidth) are taken at the top of each function, where every pixel of a face
// runs the same code, and passed down (the kit's shader rules, docs/ARCHITECTURE.md).
// Include after kit_marks.gdshaderinc (band, stencil_code) and kit_logo.gdshaderinc (corp_logo).

// The brand's colour (sRGB): its paint on liveries, banners and plaques, and the colour its signs
// glow in. The skin sets both (CorporateSkin.brand_paint_color, brand_color).
uniform vec3 corp_brand : source_color = vec3(0.11, 0.18, 0.46);
uniform vec3 corp_brand_glow : source_color = vec3(0.14, 0.27, 1.0);
// Pale paint for markings (lettering, stencils) and the cold white of text on screens.
uniform vec3 corp_marking : source_color = vec3(0.78, 0.8, 0.82);
uniform vec3 corp_text : source_color = vec3(0.88, 0.92, 1.0);
// Half the width of a carriage's roof (metres), so the marks painted on it keep their shape.
uniform float corp_roof_half_width = 1.06;

// One row of wordless "lettering" on a screen or a banner: bars of glyph-like blocks (uv in the row's
// units: x along, y 0-1 up the row), `seed` picking the words. fw: a pixel's footprint in those units.
float corp_words(vec2 uv, float seed, float fw) {
	float cell = floor(uv.x);
	float word = floor(uv.x / 5.0);
	float gap = step(0.72, hash11(word * 3.1 + seed));
	float glyph = step(0.12, fract(uv.x)) * step(fract(uv.x), 0.88) * step(0.15, uv.y) * step(uv.y, 0.85);
	float on = glyph * (1.0 - gap) * step(0.1, hash11(cell * 1.7 + seed * 5.3));
	// Far away a row blurs to a soft bar.
	return mix(on, 0.45 * step(0.15, uv.y) * step(uv.y, 0.85), smoothstep(0.08, 0.35, fw));
}

// PAT_CORP_ROOF (30): a maglev carriage's roof (CorporateTrains). UV.x runs -1 to 1 across it, UV.y
// metres along it from the carriage's start toward the far end. param = style (0 a corporate express,
// 1 a military freight car) + 4 * a painted brand mark mid-carriage (0 or 1) + 8 * a seed (0-63) + 512 *
// the carriage's length in decimetres. Flat to the touch (the running surface): its shape is shading
// only, and nothing on it is round or grated (a manhole is a sewer-screech lair in other zones).
vec3 corp_roof(vec3 base, vec3 w, vec2 uv, float param) {
	vec2 fw = max(fwidth(uv), vec2(1e-4));
	float fwz = max(fwidth(w.z), 1e-4);
	float code = floor(param + 0.5);
	float style = mod(code, 4.0);
	float logo_on = mod(floor(code / 4.0), 2.0);
	float seed = mod(floor(code / 8.0), 64.0);
	float len = floor(code / 512.0) * 0.1;
	float hw = corp_roof_half_width;
	float xm = uv.x * hw;
	float ax = abs(uv.x);
	float fx = fw.x * hw;
	float detail = 1.0 - smoothstep(0.03, 0.2, max(fx, fw.y));
	vec3 col = base;
	if (style < 0.5) {
		// A corporate express: smooth panels with hairline joints, a flush spine along the middle, flush
		// hatches on some panels, and the brand's pinstripe along each shoulder.
		float panel = floor(uv.y / 2.4);
		col *= 0.95 + 0.07 * hash11(panel * 1.3 + seed * 7.0);
		col *= 1.0 - 0.3 * filtered_pulse(uv.y / 2.4, fw.y / 2.4, 0.0, 0.01);
		float spine = band(xm, -0.14, 0.14, fx);
		col = mix(col, col * 0.84, spine);
		col *= 1.0 - 0.28 * band(abs(xm), 0.13, 0.155, fx);
		float hatch_on = step(0.62, hash11(panel * 2.9 + seed * 3.7));
		float hx = sign(hash11(panel * 5.1 + seed) - 0.5) * 0.52;
		vec2 hp = vec2(xm - hx, fract(uv.y / 2.4) * 2.4 - 1.2);
		float hatch = band(hp.x, -0.26, 0.26, fx) * band(hp.y, -0.55, 0.55, fw.y);
		float rim = hatch - band(hp.x, -0.23, 0.23, fx) * band(hp.y, -0.52, 0.52, fw.y);
		col = mix(col, col * 0.9, hatch * hatch_on);
		col *= 1.0 - 0.35 * rim * hatch_on * detail;
		col = mix(col, corp_brand, band(ax, 0.84, 0.89, fw.x) * 0.95);
	} else {
		// A military freight car: an olive container roof corrugated across, its sheets' joints, a
		// stencilled code by one shoulder.
		float rib = filtered_pulse(uv.y / 0.32, fw.y / 0.32, 0.0, 0.42);
		col *= 1.05 - 0.16 * rib;
		col *= 1.0 - 0.4 * filtered_pulse(uv.y / 6.1, fw.y / 6.1, 0.0, 0.012);
		col *= 0.92 + 0.12 * hash11(floor(uv.y / 6.1) * 2.3 + seed);
		vec2 sp = vec2(uv.y - (floor(uv.y / 6.1) + 0.5) * 6.1, xm - hw * 0.55);
		float mark = stencil_code(sp, 0.42, seed + floor(uv.y / 6.1), max(fx, fw.y));
		col = mix(col, corp_marking * 0.85, mark * 0.8 * step(0.45, hash11(floor(uv.y / 6.1) + seed * 1.9)));
	}
	// The brand's mark painted mid-carriage on some, nearly as wide as the roof.
	if (logo_on > 0.5) {
		float s = hw * 0.95;
		float mark = corp_logo(vec2(xm, uv.y - len * 0.5) / s, max(fx, fw.y) / s);
		col = mix(col, style < 0.5 ? corp_brand : corp_marking * 0.8, mark * 0.92);
	}
	// The shoulders: the roof curves down toward its long edges.
	col *= 1.0 - 0.24 * smoothstep(0.8, 1.0, ax);
	// Grime streaked back along the roof by the wind, and a fine grain up close.
	col *= 0.93 + 0.1 * value_noise(vec2(xm * 5.0, w.z * 0.07) + seed);
	col *= 1.0 + 0.05 * detail * (hash12(floor(vec2(xm, w.z) * 24.0)) - 0.5);
	// Faint wet sheen strips along the travel direction (the roofs are rain-streaked).
	col *= 1.0 + 0.04 * filtered_pulse(w.z / 0.9 + xm * 0.3, fwz / 0.9, 0.0, 0.2) * detail;
	return col;
}

// PAT_CORP_UNDER (31): everything below the running surface, seen only through gaps and the slits
// between parallel trains: a carriage's sides and ends, the guideway beams and piers, the trench's
// walls and floor, a plaza deck's edges and shafts. Deep shade that only darkens COLOR (the shade at
// the running surface's level) with depth, so a gap reads as a hole at a glance: nothing in it is lit
// or looks like a floor. param: 0 a face across the lane (a carriage's end, a deck's edge), 1 a face
// along it (a carriage's side, the trench's walls), 2 the trench's floor, 3 a guideway beam or pier.
vec3 corp_under(vec3 base, vec3 w, vec3 n, float param) {
	float mode = floor(param + 0.5);
	float h = abs(n.x) > 0.5 ? w.z : w.x;
	float fh = max(fwidth(h), 1e-4);
	float fy = max(fwidth(w.y), 1e-4);
	float fz = max(fwidth(w.z), 1e-4);
	if (mode > 1.5) {
		// The trench floor and the guideways far below, lost in the dark: faint segment joints.
		float joint = filtered_pulse(w.z / 6.0, fz / 6.0, 0.0, 0.03);
		return base * (mode > 2.5 ? 0.5 : 0.24) * (1.0 - 0.4 * joint) * mix(1.0, 0.5, smoothstep(-4.0, -12.0, w.y));
	}
	float depth = mix(1.0, 0.18, smoothstep(-0.12, -3.0, w.y));
	// A band of dark windows under the eaves (a carriage's cabin, or a cab's windscreen on an end) and
	// panel joints.
	float windows = band(w.y, -1.7, -0.6, fy);
	float joints = filtered_pulse(h / 2.4, fh / 2.4, 0.0, 0.02);
	return base * (0.95 - 0.35 * windows - 0.3 * joints) * depth;
}

// PAT_CORP_PAVING (32): a plaza's paving (world xz, so lanes and pieces join seamlessly): large
// polished slabs with hairline joints, rain-dark patches, and a steel strip along each lane's edge.
// UV.x runs -1 to 1 across the lane; param 1 flags the strip on its left edge, 2 on its right.
vec3 corp_paving(vec3 base, vec3 w, vec2 uv, float param) {
	vec2 p = w.xz;
	vec2 fwp = max(fwidth(p), vec2(1e-4));
	float fu = max(fwidth(uv.x), 1e-4);
	vec2 q = p / vec2(1.2, 2.4);
	vec2 fq = fwp / vec2(1.2, 2.4);
	float joint = max(filtered_pulse(q.x + 0.5, fq.x, 0.0, 0.015), filtered_pulse(q.y, fq.y, 0.0, 0.008));
	vec3 col = base * (0.9 + 0.13 * hash12(floor(q) + 3.0));
	col *= 1.0 - 0.3 * joint;
	col *= 0.9 + 0.14 * value_noise(p * vec2(0.35, 0.12));
	int flags = int(param + 0.5);
	float edge = band(uv.x, -2.0, -0.96, fu) * float(flags & 1) + band(uv.x, 0.96, 2.0, fu) * float((flags >> 1) & 1);
	return mix(col, corp_marking * 0.55, edge * 0.8);
}

// PAT_CORP_PLATE (33): plating. param 0 a soffit (a ceiling's underside seen from below and ridden
// upside down: steel panels, hairline joints, flush service hatches); 1 military armour (large
// staggered plates, heavy seams, rivet rows, scuffs); 2 brushed steel (pylons, masts, frames);
// 3 precast concrete (a viaduct's deck and fascia: form lines, stains).
vec3 corp_plate(vec3 base, vec3 w, vec3 n, float param) {
	vec2 p = abs(n.y) > 0.5 ? w.xz : (abs(n.x) > 0.5 ? w.zy : w.xy);
	vec2 fwp = max(fwidth(p), vec2(1e-4));
	float mode = floor(param + 0.5);
	float detail = 1.0 - smoothstep(0.03, 0.2, max(fwp.x, fwp.y));
	vec3 col = base;
	if (mode < 0.5) {
		vec2 q = p / vec2(1.2, 2.4);
		vec2 fq = fwp / vec2(1.2, 2.4);
		col *= 0.93 + 0.1 * hash12(floor(q) + 7.0);
		col *= 1.0 - 0.3 * max(filtered_pulse(q.x, fq.x, 0.0, 0.02), filtered_pulse(q.y, fq.y, 0.0, 0.01));
		float hatch = step(0.8, hash12(floor(q) + 11.0)) * band(fract(q.x), 0.2, 0.8, fq.x) * band(fract(q.y), 0.3, 0.7, fq.y);
		col *= 1.0 - 0.12 * hatch;
	} else if (mode < 1.5) {
		float row = floor(p.y / 1.6);
		float shift = hash11(row * 3.3) * 3.2;
		vec2 cell = vec2(floor((p.x + shift) / 3.2), row);
		col *= 0.86 + 0.2 * hash12(cell + 2.0);
		float seam = max(filtered_pulse((p.x + shift) / 3.2, fwp.x / 3.2, 0.0, 0.012), filtered_pulse(p.y / 1.6, fwp.y / 1.6, 0.0, 0.02));
		col *= 1.0 - 0.45 * seam;
		vec2 rv = vec2(fract((p.x + shift) / 0.4), fract(p.y / 1.6));
		float rivet = step(length(vec2(rv.x - 0.5, (rv.y - 0.08) * 4.0)), 0.18) * detail;
		col *= 1.0 - 0.25 * rivet;
		col *= 0.9 + 0.12 * value_noise(p * 0.7 + cell);
	} else if (mode < 2.5) {
		col *= 0.92 + 0.1 * value_noise(vec2(p.x * 14.0, p.y * 0.6));
		col *= 1.0 - 0.3 * filtered_pulse(p.y / 1.5, fwp.y / 1.5, 0.0, 0.015);
	} else {
		col *= 0.88 + 0.2 * value_noise(p * 0.45);
		col *= 1.0 - 0.14 * filtered_pulse(p.y / 0.6, fwp.y / 0.6, 0.0, 0.03);
		float stain = smoothstep(0.55, 0.85, value_noise(p * vec2(1.8, 0.25) + 5.0));
		col = mix(col, col * 0.55, stain * 0.5);
	}
	return col;
}

// PAT_CORP_AD (34): a corporate screen, glowing: generic, soulless corporate art. UV.y runs 0-1 up
// the screen and UV.x in the same units (it ends at the screen's aspect ratio); param = a seed (0-99)
// + 100 * the screen's height in decimetres when UV is in metres instead (a hazard sign's face). The
// seed picks the ad: the brand's mark with its slogan, a chart that only goes up, or a grid globe (the
// corporation everywhere). COLOR is the brand's glow; the art is it and cold white, nothing else. A
// slow sweep of light crosses it (no flashing); glow_mask shapes the glow.
vec3 corp_ad(vec3 base, vec2 uv_in, float param, float t, out float glow_mask) {
	float code = floor(param + 0.5);
	float seed = mod(code, 100.0);
	float height = floor(code / 100.0) * 0.1;
	vec2 uv = uv_in / (height > 0.0 ? height : 1.0);
	float kind = mod(seed, 3.0);
	float fw = max(max(fwidth(uv.x), fwidth(uv.y)), 1e-4);
	vec3 white = corp_text;
	vec3 col = mix(base * 0.22, base * 0.62, uv.y);
	glow_mask = 0.6;
	float art = 0.0;
	if (kind < 0.5) {
		// The mark in a pale tile, the slogan beside it.
		float tile = band(uv.x, 0.12, 0.88, fw) * band(uv.y, 0.14, 0.86, fw);
		float mark = corp_logo((uv - vec2(0.5, 0.5)) / 0.3, fw / 0.3);
		col = mix(col, white * 0.92, tile);
		col = mix(col, base * 0.75, mark * tile);
		art = tile;
	} else if (kind < 1.5) {
		// A chart that only goes up: rising bars on a baseline.
		float bx = (uv.x - 0.12) / 0.16;
		float bar = floor(bx);
		float h = 0.16 + 0.1 * bar + 0.04 * hash11(bar + seed);
		float on = step(0.0, bx) * step(bx, 5.0) * step(0.18, fract(bx)) * step(fract(bx), 0.82) * band(uv.y, 0.14, 0.14 + h, fw);
		float base_line = band(uv.y, 0.1, 0.12, fw) * band(uv.x, 0.08, 0.95, fw);
		art = max(on, base_line);
		col = mix(col, white * 0.9, art);
		float mark = corp_logo((uv - vec2(0.24, 0.78)) / 0.12, fw / 0.12);
		col = mix(col, white, mark);
		art = max(art, mark);
	} else {
		// A globe of grid lines turning slowly.
		vec2 g = (uv - vec2(0.5, 0.5)) / 0.36;
		float r = length(g);
		float inside = 1.0 - smoothstep(1.0 - fw / 0.36, 1.0 + fw / 0.36, r);
		float lon = asin(clamp(g.x / sqrt(max(1.0 - g.y * g.y, 1e-3)), -1.0, 1.0)) / 3.14159 + t * 0.03;
		float lines = max(filtered_pulse(lon * 8.0, fw * 8.0 / 0.36, 0.0, 0.12), filtered_pulse(g.y * 3.0 + 0.5, fw * 3.0 / 0.36, 0.0, 0.1));
		float ring = band(r, 0.96, 1.04, fw / 0.36);
		art = max(inside * lines, ring);
		col = mix(col, white * 0.85, art);
	}
	// The slogan: rows of wordless lettering to the right of the art, the top one big.
	float x0 = 1.08;
	vec2 tp = vec2((uv.x - x0) / 0.07, uv.y);
	float big = corp_words(vec2(tp.x * 0.6, (uv.y - 0.56) / 0.2), seed, fw / 0.07) * step(uv.y, 0.8) * step(0.52, uv.y);
	float small = corp_words(vec2(tp.x, (uv.y - 0.3) / 0.1), seed + 11.0, fw / 0.07) * step(uv.y, 0.42) * step(0.26, uv.y);
	float text = max(big, small * step(tp.x, 22.0 + 10.0 * hash11(seed))) * step(0.0, tp.x);
	col = mix(col, white, text * 0.9);
	glow_mask = mix(glow_mask, 1.0, max(art, text));
	// A slow sweep of light (squared by hand: pow() of a negative number is undefined).
	float sx = (uv.x - uv.y * 0.5 - mod(t * 0.3 + seed * 0.41, 7.0) + 1.5) * 2.5;
	return col + base * 0.2 * exp(-sx * sx);
}

// PAT_CORP_LOGO (35): the brand's mark (corp_logo) on a panel. UV is logo space: the mark spans about
// -0.78 to 0.78, so a wider range leaves a margin. param 0: the mark in COLOR on a dark panel (a sign:
// only the mark glows); 1: the mark in cold white on a COLOR ground (a glowing brand panel: the ground
// glows at a third); 2: the mark in COLOR painted on steel (never glowing); 3: the mark in cold white
// painted on a COLOR ground (a flag, a plaque; never glowing).
vec3 corp_logo_face(vec3 base, vec2 uv, float param, vec3 dark, inout float glow) {
	float fw = max(max(fwidth(uv.x), fwidth(uv.y)), 1e-4);
	float mark = corp_logo(uv, fw);
	float mode = floor(param + 0.5);
	if (mode < 0.5) {
		glow *= mark;
		return mix(dark, base, mark);
	} else if (mode < 1.5) {
		glow *= mix(0.33, 1.0, mark);
		return mix(base, corp_text, mark);
	} else if (mode < 2.5) {
		return mix(vec3(0.42, 0.44, 0.47), base, mark * 0.95);
	}
	return mix(base, corp_marking, mark * 0.95);
}

// PAT_CORP_BANNER (36): a banner hanging down a tower (UV in metres: x across from its left edge as
// seen from the street, y down from its top; param = seed + 100 * its width in decimetres): the brand's
// colour (COLOR), its mark in cold white near the top, a slogan in rows of wordless lettering under it,
// soft folds, and the floodlights' wash rising from its foot. Lit cloth, never glowing.
vec3 corp_banner(vec3 base, vec2 uv, float param) {
	vec2 fw = max(fwidth(uv), vec2(1e-4));
	float code = floor(param + 0.5);
	float seed = mod(code, 100.0);
	float bw = max(floor(code / 100.0) * 0.1, 0.5);
	vec3 col = base * (0.86 + 0.14 * sin(uv.x / bw * 6.2832 * 3.0 + seed));
	float s = bw * 0.36;
	float mark = corp_logo(vec2(uv.x - bw * 0.5, -(uv.y - bw * 0.62)) / s, max(fw.x, fw.y) / s);
	col = mix(col, corp_marking, mark * 0.95);
	float rows = 0.0;
	for (int i = 0; i < 3; i++) {
		float y0 = bw * 1.25 + float(i) * bw * 0.28;
		rows = max(rows, corp_words(vec2((uv.x - bw * 0.14) / (bw * 0.075), (uv.y - y0) / (bw * 0.16)), seed + float(i) * 7.0,
			max(fw.x, fw.y) / (bw * 0.075)) * band(uv.x, bw * 0.12, bw * 0.88, fw.x) * band(uv.y, y0, y0 + bw * 0.16, fw.y));
	}
	return mix(col, corp_marking * 0.9, rows * 0.9);
}

// PAT_CORP_GLASS (37): a glass wall with a lit corridor behind it (a skyway's sides and end). UV in
// metres: x along the glass, y up from the corridor's floor; param = the corridor's height in
// decimetres. Dark glass, catching a little of the sky toward its top; behind it the corridor's back
// wall lit from above and a strip of cold white ceiling panels (the only bright part); steel mullions
// every 1.5 m. The glass glows as a whole (glow_mask 1: its brightness is in the colour), the mullions
// are lit steel.
vec3 corp_glass(vec3 base, vec2 uv, float param, out float glow_mask) {
	vec2 fw = max(fwidth(uv), vec2(1e-4));
	float height = max(floor(param + 0.5) * 0.1, 1.0);
	float mullion = filtered_pulse(uv.x / 1.5, fw.x / 1.5, 0.0, 0.05);
	float lights = band(uv.y, height - 0.32, height - 0.2, fw.y) * filtered_pulse(uv.x / 1.5, fw.x / 1.5, 0.14, 0.86);
	float wall = smoothstep(height * 0.3, height - 0.3, uv.y) * band(uv.y, 0.0, height - 0.32, fw.y);
	vec3 glass = vec3(0.035, 0.04, 0.05) + vec3(0.03, 0.035, 0.045) * clamp(uv.y / height, 0.0, 1.0);
	vec3 col = mix(glass, base * 0.3, wall * 0.85);
	col = mix(col, corp_text, lights);
	glow_mask = 1.0 - mullion;
	return mix(col, vec3(0.2, 0.21, 0.24), mullion);
}

// Dispatches the Corporate patterns (ids 30-39) for kit_solid.gdshader.
vec3 corp_surface(int pattern, float param, vec3 base, vec3 w, vec3 n, vec2 uv, float t, vec3 dark, inout float glow) {
	if (pattern == 30) {
		return corp_roof(base, w, uv, param);
	} else if (pattern == 31) {
		return corp_under(base, w, n, param);
	} else if (pattern == 32) {
		return corp_paving(base, w, uv, param);
	} else if (pattern == 33) {
		return corp_plate(base, w, n, param);
	} else if (pattern == 34) {
		float m;
		vec3 c = corp_ad(base, uv, param, t, m);
		glow *= m;
		return c;
	} else if (pattern == 35) {
		return corp_logo_face(base, uv, param, dark, glow);
	} else if (pattern == 36) {
		return corp_banner(base, uv, param);
	} else if (pattern == 37) {
		float m;
		vec3 c = corp_glass(base, uv, param, m);
		glow *= m;
		return c;
	}
	return base;
}

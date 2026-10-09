// The Casino's surfaces for the solid kit shader (kit_solid.gdshader): pattern ids 80-89
// (MeshKit.PAT_CASINO_*, task K1), in their own file so other zones' patterns never collide with them.
// Included after kit_golden.gdshaderinc and kit_cult.gdshaderinc (nothing here needs them, but the
// order keeps every zone's block together). Each function takes the fragment's world position `w`,
// world normal `n`, the eye vector `eye` (world, from the surface toward the camera), UV and the
// pattern parameter, and returns the albedo (sRGB, like COLOR); the kit then lights it like any lit
// surface. Dark iron and aged brass are lit metal, never neon (GDD §5: the Casino's neon follows the
// colour rule), and only the signs' lettering and borders glow, in warm white, violet or blue.
// Pixel footprints are taken at the top of each pattern's function, where every pixel of a face runs
// the same code, and passed down (docs/ARCHITECTURE.md, Zone skins: the kit's shader rules).

// The skin sets every colour below as an sRGB Vector3 (CasinoSkin.srgb()), like vertex colours: a
// Color would arrive already linear on Forward+ but not on the Compatibility renderer.
// Brass in its polished highlights, the brass inlaid in the street and trimmed onto the iron, and the
// lamplight the wet street and the glass catch.
uniform vec3 cas_shine = vec3(0.96, 0.88, 0.7);
uniform vec3 cas_inlay = vec3(0.6, 0.46, 0.25);
uniform vec3 cas_lamp = vec3(1.0, 0.8, 0.55);
// How wet the street looks (0 dry), and its lane's width (metres) for the inlay's diamonds.
uniform float cas_wet = 0.6;
uniform float cas_lane_w = 2.4;
// The vault's panes (PAT_CASINO_VAULT): dark night-blue glass, warmer where it catches the lamplit
// haze (low on the arch), the stars glimpsed through it; a pane is this long along the track; the
// vault springs from cas_vault_y and rises cas_vault_rise at its crown.
uniform vec3 cas_pane = vec3(0.05, 0.085, 0.14);
uniform vec3 cas_pane_lit = vec3(0.3, 0.21, 0.13);
uniform vec3 cas_star = vec3(0.8, 0.84, 0.95);
uniform float cas_pane_len = 2.6667;
uniform float cas_vault_y = 24.0;
uniform float cas_vault_rise = 8.0;
// Hanging banners (PAT_CASINO_BANNER): how wide they are (metres), and the trim woven into them.
uniform float cas_banner_w = 1.8;
uniform vec3 cas_banner_trim = vec3(0.6, 0.46, 0.25);

// Metal lit as a fake reflection of a lamplit covered street (the Golden Zone's golden_metal() for
// a dimmer, warmer room): the lamplit haze bright at the horizon, the street's glow below it dimmer,
// the dark vault above it darker, a glint toward the far end of the street, and more of it all at
// grazing angles. `polish` 0 is satin, 1 a mirror finish. Highlights turn toward pale brass and the
// shadows toward a greyed bronze, so only the mid tone carries the hue and it never goes neon.
vec3 cas_metal(vec3 base, vec3 n, vec3 eye, float polish) {
	vec3 r = reflect(-eye, n);
	float p = clamp(polish, 0.0, 1.0);
	float haze = 1.0 - smoothstep(0.0, 0.6, abs(r.y + 0.04));
	float street = 1.0 - smoothstep(-0.7, 0.0, r.y);
	float vault = smoothstep(0.1, 0.7, r.y);
	float seen = 0.28 * street + haze + 0.06 * vault;
	float grazing = pow(1.0 - clamp(dot(n, eye), 0.0, 1.0), 4.0);
	float env = 0.58 + p * (seen - 0.5) * 1.0 + grazing * p * 0.25;
	vec3 grey = vec3(dot(base, vec3(0.3, 0.55, 0.15)));
	vec3 dark = mix(base, grey, 0.3) * 0.45;
	vec3 col = mix(dark, base * 1.1, clamp(env, 0.0, 1.0));
	float glint = pow(max(dot(r, normalize(vec3(0.0, 0.12, -1.0))), 0.0), 18.0) * p;
	col = mix(col, cas_shine, clamp(glint * 0.7 + max(env - 0.97, 0.0) * 2.0, 0.0, 0.7));
	return clamp(col, 0.0, 1.0);
}

// PAT_CASINO_STREET (80): the street's paving along one lane (GDD §5, the owner's reference: a wet,
// dark paved street): flagstones in running bond, each a slightly different tone, grout between them,
// puddles and scuffs, brass inlaid along both lane edges, a brass bar across the lane every 6 m
// (the still floor's own motion cue: the bars stream past underfoot) with a diamond of brass at the
// lane's middle every 24 m, soft pools of lamplight every 12 m and the street's wet sheen toward the
// horizon. UV.x 0-1 across the lane; param = the lane's key (a seed for the tones). Everything comes
// from world position, so it lines up across chunk cuts. Nothing glows; the diamond is a ring, never
// a disc (a round shape on the street is a screech's lair, GDD §9.5).
vec3 cas_street(vec3 base, vec3 w, vec3 n, vec3 eye, vec2 uv, float param) {
	vec2 p = w.xz;
	vec2 fwp = max(fwidth(p), vec2(1e-4));
	float fu = max(fwidth(uv.x), 1e-4);
	vec2 q = vec2(p.x / 1.2, p.y / 0.6);
	q.x += 0.5 * mod(floor(q.y), 2.0);
	vec2 fq = fwp / vec2(1.2, 0.6);
	float grout = max(filtered_pulse(q.x, fq.x, 0.0, 0.04), filtered_pulse(q.y, fq.y, 0.0, 0.08));
	float tone = hash12(floor(q) + mod(floor(param), 97.0) * 0.731);
	vec3 col = base * (0.84 + 0.28 * tone) * (0.9 + 0.2 * value_noise(p * 0.3 + 2.0));
	col *= 1.0 - 0.5 * grout;
	col *= 1.0 - 0.2 * smoothstep(0.58, 0.8, value_noise(p * vec2(0.27, 0.16) + 11.0));
	float pool = 0.5 + 0.5 * cos(p.y / 12.0 * 6.2832);
	col *= 1.0 + 0.14 * pool;
	// The brass: inlaid along both edges (a dark groove beside it), a bar across every 6 m, a ring of
	// brass diamond at the middle every 24 m.
	float e = min(uv.x, 1.0 - uv.x);
	float inlay = band(e, 0.012, 0.03, fu);
	col = mix(col, col * 0.45, band(e, 0.03, 0.05, fu));
	float bar = filtered_pulse(p.y / 6.0, fwp.y / 6.0, 0.0, 0.012);
	float xm = (uv.x - 0.5) * cas_lane_w;
	float dz = (fract(p.y / 24.0 + 0.5) - 0.5) * 24.0;
	float diamond = band(abs(xm) + abs(dz), 0.3, 0.4, max(fu * cas_lane_w, fwp.y));
	float brass = max(max(inlay, bar), diamond);
	col = mix(col, cas_metal(cas_inlay, n, eye, 0.55), brass);
	// The street's wet sheen: the lamps' haze on the stone at grazing angles, along long streaks.
	float graz = pow(1.0 - clamp(dot(n, eye), 0.0, 1.0), 3.0);
	float streak = smoothstep(0.45, 0.85, value_noise(p * vec2(1.3, 0.1) + 5.0));
	float wet = clamp(graz * (0.3 + 0.7 * streak) * cas_wet * (0.5 + 0.5 * pool) * 0.6, 0.0, 0.5);
	col = mix(col, cas_lamp * 0.6, wet * (1.0 - 0.7 * brass));
	return col;
}

// PAT_CASINO_UNDER (81): everything under the street, seen only through gaps (GDD §5's colour rule and
// the readability rules: a gap reads as a hole at a glance): the service trench's iron walls, the
// building faces below the street and the trench's floor, all in deep shade that only darkens with
// depth, with the faint ghost of ribs and pipe runs near the top. COLOR is the shade at the street's
// level. param: 0 a face across the lane, 1 a face along it, 2 the trench's floor.
vec3 cas_under(vec3 base, vec3 w, vec3 n, float param) {
	float mode = floor(param + 0.5);
	float h = abs(n.x) > 0.5 ? w.z : w.x;
	float fh = max(fwidth(h), 1e-4);
	float fy = max(fwidth(w.y), 1e-4);
	if (mode > 1.5) {
		return base * (0.22 + 0.14 * value_noise(w.xz * 0.5));
	}
	float rib = filtered_pulse(h / 1.6, fh / 1.6, 0.0, 0.06);
	float pipe = clamp(band(w.y, -1.5, -1.0, fy) + 0.7 * band(w.y, -2.25, -1.9, fy), 0.0, 1.0);
	float depth = mix(1.0, 0.16, smoothstep(-0.12, -2.8, w.y));
	return base * (0.88 - 0.3 * rib - 0.18 * pipe) * depth;
}

// PAT_CASINO_IRON (82): dark iron: plates with seams and rivets, grime, a faint sheen. param 0 a
// plate (faces of piers, cornices, girders, balconies; world position), 1 the underside of a ceiling
// (a plate surface crossed by beams every 3 m along the track: they stream past a player riding it),
// 2 a girder's face (dark, with a lit edge).
vec3 cas_iron(vec3 base, vec3 w, vec3 n, vec3 eye, float param) {
	float mode = floor(param + 0.5);
	vec2 p = abs(n.y) > 0.5 ? w.xz : (abs(n.x) > 0.5 ? w.zy : w.xy);
	vec2 fwp = max(fwidth(p), vec2(1e-4));
	float aa = max(fwp.x, fwp.y);
	float detail = 1.0 - smoothstep(0.03, 0.14, aa);
	float upright = step(abs(n.y), 0.5);
	vec3 col = base * (0.86 + 0.26 * value_noise(p * 0.45 + 3.0));
	vec2 q = p / vec2(1.5, 1.0);
	vec2 fq = fwp / vec2(1.5, 1.0);
	float seam = max(filtered_pulse(q.x, fq.x, 0.0, 0.02), filtered_pulse(q.y, fq.y, 0.0, 0.03));
	col *= 1.0 - 0.38 * seam * (mode > 1.5 ? 0.4 : 1.0);
	// Rivets in a row above each horizontal seam.
	vec2 rp = vec2((fract(p.x / 0.3) - 0.5) * 0.3, (fract(q.y) - 0.1));
	float rivet = (1.0 - smoothstep(0.03 - aa, 0.03 + aa, length(rp))) * detail;
	col = mix(col, base * 1.9 + 0.04, rivet * 0.6);
	if (mode > 0.5 && mode < 1.5) {
		float bq = w.z / 3.0;
		float beam = filtered_pulse(bq, fwp.y / 3.0, 0.0, 0.1);
		float bay = smoothstep(0.1, 0.3, fract(bq)) * (1.0 - smoothstep(0.84, 1.0, fract(bq)));
		col *= (0.88 + 0.12 * bay) * (1.0 - 0.45 * beam);
	}
	// Grime climbing the upright faces from below, and long streaks down them.
	float streak = upright * smoothstep(0.6, 0.9, value_noise(vec2(p.x * 2.4, p.y * 0.25) + 9.0));
	col *= 1.0 - 0.3 * streak;
	return cas_metal(col, n, eye, mode > 1.5 ? 0.35 : 0.2);
}

// PAT_CASINO_BRASS (83): aged brass, lit as polished metal (cas_metal): pipes, rails, trims, lamp
// housings, with a patina of darker blotches. COLOR is the brass; param is how polished it is (0-1).
vec3 cas_brass_surface(vec3 base, vec3 w, vec3 n, vec3 eye, float param) {
	vec2 p = abs(n.y) > 0.5 ? w.xz : (abs(n.x) > 0.5 ? w.zy : w.xy);
	vec3 col = base * (0.88 + 0.2 * value_noise(p * 2.3 + 1.0));
	col *= 1.0 - 0.2 * smoothstep(0.55, 0.85, value_noise(p * 0.7 + 8.0));
	return cas_metal(col, n, eye, param);
}

// PAT_CASINO_VAULT (84): one pane of the glass roof (GDD §5, the owner's reference: a vaulted roof of
// glass and iron), opaque and faked so it costs nothing on a phone: dark night-blue glass in thin iron
// frames, warmer low on the arch where it catches the lamplit haze of the street, with the stars
// glimpsed through it and a slow diagonal sweep of reflected light. UV 0-1 across the pane (x along
// the arch, y along the track); param = the pane's width in centimetres + 1000 * its index across the
// arch (a seed with the pane's place along the street). No transparency: the sky shows only through the
// panes the builder leaves out.
vec3 cas_vault(vec3 base, vec3 w, vec2 uv, float param) {
	float wcm = mod(param, 1000.0);
	float idx = floor(param / 1000.0);
	vec2 size = vec2(max(wcm, 10.0) * 0.01, cas_pane_len);
	vec2 fwu = max(fwidth(uv), vec2(1e-4));
	vec2 fwm = fwu * size;
	float aa = max(fwm.x, fwm.y);
	vec2 e = min(uv, 1.0 - uv) * size;
	float frame = 1.0 - smoothstep(0.04, 0.04 + 2.0 * aa, min(e.x, e.y));
	float cell = hash12(vec2(idx, floor(-w.z / cas_pane_len)));
	float low = 1.0 - clamp((w.y - cas_vault_y) / max(cas_vault_rise, 1.0), 0.0, 1.0);
	vec3 glass = mix(cas_pane, cas_pane_lit, low * low * (0.35 + 0.65 * cell));
	glass *= 0.8 + 0.4 * cell;
	float detail = 1.0 - smoothstep(0.03, 0.12, aa);
	vec2 sg = floor(uv * size * 5.0);
	float star = step(0.975, hash12(sg + cell * 17.0)) * detail * (1.0 - low);
	glass = mix(glass, cas_star * 0.7, star * 0.8);
	float sweep = smoothstep(0.35, 0.5, fract((uv.x * size.x * 0.35 + uv.y * size.y * 0.2) * 0.3 + cell * 0.7));
	glass += cas_lamp * 0.03 * sweep * low;
	vec3 iron = base;
	return mix(glass, iron, frame);
}

// A brand mark for the casino's signs (wordless, like every skin's lettering): `p` runs -1 to 1 across
// the mark; returns coverage. Kinds: a diamond ring round a pip, a lotus (three petals over a base
// line), a crown (a band with three points), a chip (two rings) and a die (a rounded square with three
// pips). None has the cult emblem's three-fold symmetry.
float cas_logo(vec2 p, float kind, float aa) {
	vec2 a = abs(p);
	float d;
	if (kind < 0.5) {
		d = min(abs(a.x + a.y - 0.72) - 0.12, length(p) - 0.14);
	} else if (kind < 1.5) {
		float mid = (length(vec2(p.x / 0.22, (p.y - 0.15) / 0.7)) - 1.0) * 0.22;
		float side = (length(vec2((a.x - 0.42) / 0.2, (p.y - 0.0) / 0.55)) - 1.0) * 0.2;
		float base_line = max(abs(p.y + 0.78) - 0.08, a.x - 0.7);
		d = min(min(mid, side), base_line);
	} else if (kind < 2.5) {
		float band_d = max(abs(p.y + 0.45) - 0.18, a.x - 0.75);
		float teeth = 1e3;
		for (int i = -1; i <= 1; i++) {
			float cx = float(i) * 0.55;
			teeth = min(teeth, max(abs(p.x - cx) - 0.26 * (0.7 - p.y), max(-(p.y + 0.3), p.y - 0.7)));
		}
		d = min(band_d, teeth);
	} else if (kind < 3.5) {
		d = min(abs(length(p) - 0.62) - 0.12, abs(length(p) - 0.28) - 0.05);
	} else {
		float box = abs(sd_round_box(p, vec2(0.7), 0.15)) - 0.09;
		float pips = min(length(p - vec2(-0.32, 0.32)), min(length(p), length(p - vec2(0.32, -0.32)))) - 0.12;
		d = min(box, pips);
	}
	float f = max(aa, 1e-4);
	return 1.0 - smoothstep(-f, f, d);
}

// PAT_CASINO_SIGN (85): a lit casino sign (the reference's "Gasket's House of Chance" and "The Brass
// Lotus", drawn without words like every skin's lettering): a dark panel, a tube of light round its
// edge, a brand mark and one or two rows of chunky glyphs. COLOR is the light (warm white, violet or
// blue, never a hazard hue). UV in metres on the panel, x to the viewer's right, y up; param = seed
// (0-99) + 100 * the panel's height in decimetres. The border's bulbs breathe slowly, steady with
// Reduced flashing. Returns the glow mask.
vec3 cas_sign(vec3 base, vec2 uv, float param, float t, out float glow_mask) {
	float code = floor(param + 0.5);
	float seed = mod(code, 100.0);
	float height = max(floor(code / 100.0) * 0.1, 0.5);
	vec2 fw = max(fwidth(uv), vec2(1e-4));
	float aa = max(fw.x, fw.y);
	vec3 dark = vec3(0.04, 0.035, 0.045);
	vec3 col = dark;
	glow_mask = 0.0;
	// The tube round the edge.
	float inset = min(0.12, height * 0.1);
	// uv.x is open-ended (the sign's length isn't known here): the tube runs along the top and bottom
	// and the glyph rows between them; the builder's frame closes the ends.
	float edge = min(uv.y, height - uv.y);
	float tube = band(edge, inset - 0.03, inset + 0.03, fw.y);
	float breathe = mix(0.78 + 0.22 * sin(uv.x * 1.7 - t * 1.4 + seed), 0.9, reduced_flashing);
	col = mix(col, base, tube);
	glow_mask = max(glow_mask, tube * breathe * 0.8);
	// The mark at the start, then rows of glyphs.
	float inner = height - 2.0 * (inset + 0.12);
	float r = max(inner * 0.5, 0.05);
	vec2 mc = vec2(uv.x - (inset + 0.2 + r), uv.y - height * 0.5);
	float logo = cas_logo(mc / r, mod(seed, 5.0), aa / r) * step(abs(mc.x), r * 1.05) * step(abs(mc.y), r * 1.05);
	float rows = height > 1.9 ? 2.0 : 1.0;
	float lh = inner / rows * 0.78;
	float x0 = inset + 0.3 + 2.0 * r;
	vec2 gp = vec2((uv.x - x0) / (lh * 0.72), (uv.y - (height - inner) * 0.5) / (inner / rows));
	float row = floor(gp.y);
	vec2 g = vec2(fract(gp.x), fract(gp.y));
	float inside = step(0.0, gp.x) * step(0.0, gp.y) * step(gp.y, rows) * step(0.1, g.y) * step(g.y, 0.88);
	float cellx = floor(gp.x);
	vec2 sub = vec2(clamp((g.x - 0.14) / 0.36, 0.0, 1.99), clamp((g.y - 0.1) / 0.78 * 3.0, 0.0, 2.99));
	float pick = hash12(vec2(cellx, row) * 2.3 + floor(sub) * 1.7 + seed);
	float stroke = pick < 0.45 ? step(abs(fract((g.y - 0.1) / 0.78 * 3.0) - 0.5), 0.3)
		: (pick < 0.85 ? step(abs(fract((g.x - 0.14) / 0.36) - 0.5), 0.34) : 0.0);
	float word = step(0.22, hash12(vec2(floor(cellx / 4.0), row) + seed)) * step(cellx, 10.0 + 14.0 * hash11(seed + row));
	float on = inside * step(0.14, g.x) * step(g.x, 0.86) * stroke * word;
	on = mix(on, 0.3 * inside * word, smoothstep(0.03, 0.15, aa / max(lh, 0.05)));
	float lit = max(on, logo);
	col = mix(col, base, lit);
	glow_mask = max(glow_mask, lit);
	return col;
}

// PAT_CASINO_BANNER (86): a hanging banner of heavy cloth (the reference's long banners hung from
// the roof's ribs): a muted ground in COLOR, a brass border, a column of diamonds down its middle and
// a brass fringe at its foot. Never glowing. UV.x 0-1 across, UV.y metres down from its top; param =
// its length in decimetres + 1000 * a seed.
vec3 cas_banner(vec3 base, vec2 uv, float param) {
	float code = floor(param + 0.5);
	float len = max(mod(code, 1000.0) * 0.1, 0.5);
	float seed = floor(code / 1000.0);
	vec2 m = vec2(uv.x * cas_banner_w, uv.y);
	vec2 fw = max(fwidth(m), vec2(1e-4));
	float aa = max(fw.x, fw.y);
	vec3 col = base * (0.9 + 0.2 * value_noise(vec2(m.x * 7.0, m.y * 0.8) + seed));
	float stripe = filtered_pulse(uv.x * 3.0, max(fwidth(uv.x), 1e-4) * 3.0, 0.0, 0.5);
	col *= 0.9 + 0.1 * stripe;
	float e = min(m.x, cas_banner_w - m.x);
	float border = band(e, 0.08, 0.15, aa);
	vec3 trim = cas_banner_trim * 0.85;
	col = mix(col, trim, border);
	// A column of diamonds down the middle.
	vec2 dp = vec2(m.x - cas_banner_w * 0.5, (fract(m.y / 1.1) - 0.5) * 1.1);
	float diamond = band(abs(dp.x) + abs(dp.y), 0.0, 0.34, aa) * step(0.5, m.y) * step(m.y, len - 0.9);
	col = mix(col, trim, diamond * 0.8);
	float fringe = band(m.y, len - 0.26, len, aa) * (0.55 + 0.45 * step(0.5, fract(m.x / 0.06)));
	col = mix(col, trim * 0.9, fringe);
	return col;
}

// Dispatches the Casino's patterns (ids 80-89) for kit_solid.gdshader.
vec3 casino_surface(int pattern, float param, vec3 base, vec3 w, vec3 n, vec3 eye, vec2 uv, float t, inout float glow) {
	if (pattern == 80) {
		return cas_street(base, w, n, eye, uv, param);
	} else if (pattern == 81) {
		return cas_under(base, w, n, param);
	} else if (pattern == 82) {
		return cas_iron(base, w, n, eye, param);
	} else if (pattern == 83) {
		return cas_brass_surface(base, w, n, eye, param);
	} else if (pattern == 84) {
		return cas_vault(base, w, uv, param);
	} else if (pattern == 85) {
		float m;
		vec3 c = cas_sign(base, uv, param, t, m);
		glow *= m;
		return c;
	} else if (pattern == 86) {
		return cas_banner(base, uv, param);
	}
	return base;
}

// Beach surfaces for the solid kit shader (kit_solid.gdshader): pattern ids 80-89 (MeshKit.PAT_BEACH_*),
// in their own file so other zones' patterns never collide with them. The Beach (BeachSkin, task D10):
// a cyberpunk party strip on the shore, in a bright tropical afternoon: sand and weathered boardwalk
// under bamboo shacks and thatch, black rust-streaked steel tanks, painted boards and neon silhouettes.
// Each function takes the fragment's world position `w`, world normal `n`, UV and the pattern parameter
// and returns the albedo (sRGB, like COLOR); the kit then lights it like any lit surface (and dims it
// with a level's scenery_light). Only the neon silhouettes (PAT_BEACH_NEON) glow: give every other
// pattern's vertices COLOR.a = 0. The water never glows (GDD §5: pink, yellow and black, red, orange,
// green and cyan are for hazards, and a glowing turquoise would read as an anti-grav pad's cyan).
// Pixel footprints (fwidth) are taken at the top of each function, where every pixel of a face runs the
// same code, and passed down; no branch that differs between neighbouring pixels takes a derivative
// (docs/ARCHITECTURE.md, Zone skins: the kit's shader rules).
// Include after face_coords() and kit_marks.gdshaderinc (band(), sd_round_box(), sd_segment()).

// The skin sets every colour below as an sRGB Vector3 (BeachSkin.srgb()), like vertex colours: a Color
// would arrive already linear on Forward+ but not on the Compatibility renderer.
// The sand's light and dark drifts, its shells and pebbles.
uniform vec3 bc_sand_light = vec3(0.80, 0.70, 0.52);
uniform vec3 bc_sand_dark = vec3(0.58, 0.47, 0.32);
uniform vec3 bc_shell = vec3(0.84, 0.78, 0.68);
uniform vec3 bc_pebble = vec3(0.42, 0.40, 0.37);
// The boardwalk: the dark joints between boards, the rusty steel plates bolted to it, their rust.
uniform vec3 bc_plank_gap = vec3(0.24, 0.17, 0.11);
uniform vec3 bc_plate = vec3(0.38, 0.27, 0.19);
uniform vec3 bc_rust = vec3(0.42, 0.22, 0.11);
// The black industrial steel (tanks, chimneys, the pool tanks' walls) and the dark rust streaking it.
uniform vec3 bc_steel = vec3(0.095, 0.10, 0.11);
uniform vec3 bc_steel_rust = vec3(0.30, 0.15, 0.08);
// The pool tanks' own rust streaks: darker still (nothing under the floor is lighter than 1.25 times the
// tank's steel, or than half this).
uniform vec3 bc_tank_rust = vec3(0.20, 0.10, 0.06);
// The pool: the tide mark on the tank walls and the deep water far below.
uniform vec3 bc_tide = vec3(0.07, 0.12, 0.13);
uniform float bc_pool_depth = 6.0;
// Bamboo, thatch and weathered timber.
uniform vec3 bc_bamboo_dark = vec3(0.34, 0.23, 0.11);
uniform vec3 bc_thatch_dark = vec3(0.30, 0.23, 0.13);
uniform vec3 bc_timber = vec3(0.45, 0.35, 0.25);
// Painted boards, five muted unlit paints (never a hazard's glow): teal, coral, mustard, sage, dusty blue.
uniform vec3 bc_paint_a = vec3(0.33, 0.50, 0.52);
uniform vec3 bc_paint_b = vec3(0.62, 0.42, 0.34);
uniform vec3 bc_paint_c = vec3(0.62, 0.55, 0.34);
uniform vec3 bc_paint_d = vec3(0.45, 0.50, 0.40);
uniform vec3 bc_paint_e = vec3(0.36, 0.40, 0.55);
uniform vec3 bc_cream = vec3(0.86, 0.82, 0.70);
// The calm band: below this height every wall is flush, closed and solid-looking; the wall-run height
// marks (unlit paint) at bc_mark_a and bc_mark_b.
uniform float bc_band_top = 7.2;
uniform float bc_mark_a = 2.0;
uniform float bc_mark_b = 4.0;
uniform vec3 bc_mark = vec3(0.22, 0.14, 0.08);
// The kit lights a wall with its night-city factor (0.7); the Beach is in bright afternoon sun, so its
// walls, thatch and timber (the lit upright surfaces) take this much more (a factor on their albedo).
uniform float bc_daylight = 1.2;

vec2 bc_rot(vec2 q, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(q.x * c - q.y * s, q.x * s + q.y * c);
}

// One of the five painted-board colours.
vec3 bc_paint(float k) {
	float i = mod(floor(k), 5.0);
	if (i < 0.5) {
		return bc_paint_a;
	} else if (i < 1.5) {
		return bc_paint_b;
	} else if (i < 2.5) {
		return bc_paint_c;
	} else if (i < 3.5) {
		return bc_paint_d;
	}
	return bc_paint_e;
}

// 1 inside a rotated ellipse of half sizes r centred on c, anti-aliased over the footprint aa (metres).
float bc_ellipse(vec2 p, vec2 c, vec2 r, float ang, float aa) {
	vec2 q = bc_rot(p - c, ang) / r;
	float d = (length(q) - 1.0) * min(r.x, r.y);
	return 1.0 - smoothstep(-aa, aa, d);
}

// --- The glyphs: wordless silhouettes (a sun, waves, a palm, a surfboard, a flamingo, a cocktail, a
// tiki totem) as signed distances (negative inside) in glyph space, spanning about -0.5..0.5, +y up.
// Posters and signs fill them, neon outlines them.
float bc_glyph(vec2 q, int kind) {
	float d = 1e3;
	if (kind == 0) {
		// The sun: a disc with ten rays.
		d = length(q) - 0.2;
		float step_a = 0.62832;
		float ra = floor(atan(q.y, q.x) / step_a + 0.5) * step_a;
		vec2 r = vec2(cos(ra), sin(ra));
		float along = dot(q, r);
		float across = abs(dot(q, vec2(-r.y, r.x)));
		d = min(d, max(max(across - 0.03, along - 0.46), 0.3 - along));
	} else if (kind == 1) {
		// Three waves.
		for (int i = 0; i < 3; i++) {
			float yo = (float(i) - 1.0) * 0.26;
			float sy = q.y - yo - 0.07 * sin(q.x * 11.0 + float(i) * 1.7);
			d = min(d, max(abs(sy) - 0.045, abs(q.x) - 0.5));
		}
	} else if (kind == 2) {
		// A palm tree: a leaning trunk and five drooping fronds.
		vec2 crown = vec2(0.04, 0.08);
		d = sd_segment(q, vec2(-0.08, -0.5), crown) - 0.03;
		for (int i = 0; i < 5; i++) {
			float k = float(i);
			vec2 tip = crown + vec2(-0.46 + 0.23 * k, -0.18 + 0.4 * (1.0 - abs(k - 2.0) * 0.5));
			vec2 mid = crown + (tip - crown) * 0.55 + vec2(0.0, 0.1);
			d = min(d, min(sd_segment(q, crown, mid), sd_segment(q, mid, tip)) - 0.028);
		}
	} else if (kind == 3) {
		// A surfboard, leaning, with its fin.
		vec2 b = bc_rot(q, 0.35);
		d = (length(b / vec2(0.15, 0.52)) - 1.0) * 0.15;
		d = min(d, sd_round_box(b - vec2(0.0, -0.5), vec2(0.03, 0.06), 0.02));
	} else if (kind == 4) {
		// A flamingo: a plump body, a curved neck, a head and beak, long thin legs.
		d = (length((q - vec2(-0.05, -0.02)) / vec2(0.2, 0.12)) - 1.0) * 0.12;
		d = min(d, sd_segment(q, vec2(0.1, 0.03), vec2(0.24, 0.16)) - 0.032);
		d = min(d, sd_segment(q, vec2(0.24, 0.16), vec2(0.2, 0.34)) - 0.028);
		d = min(d, length(q - vec2(0.22, 0.38)) - 0.05);
		d = min(d, sd_segment(q, vec2(0.25, 0.37), vec2(0.34, 0.34)) - 0.018);
		d = min(d, sd_segment(q, vec2(-0.08, -0.12), vec2(-0.08, -0.5)) - 0.018);
		d = min(d, min(sd_segment(q, vec2(0.0, -0.12), vec2(0.08, -0.3)), sd_segment(q, vec2(0.08, -0.3), vec2(0.02, -0.5))) - 0.018);
		d = min(d, sd_segment(q, vec2(-0.23, 0.0), vec2(-0.36, 0.06)) - 0.03);
	} else if (kind == 5) {
		// A cocktail glass: the bowl, stem and foot, a straw and a slice on the rim.
		float hw = 0.34 * clamp((q.y + 0.02) / 0.42, 0.0, 1.0);
		float bowl = max(max(abs(q.x) - hw, -0.02 - q.y), q.y - 0.4);
		d = bowl;
		d = min(d, sd_segment(q, vec2(0.0, -0.02), vec2(0.0, -0.4)) - 0.02);
		d = min(d, sd_segment(q, vec2(-0.2, -0.42), vec2(0.2, -0.42)) - 0.025);
		d = min(d, sd_segment(q, vec2(0.08, 0.2), vec2(0.22, 0.52)) - 0.016);
		d = min(d, length(q - vec2(-0.33, 0.4)) - 0.065);
	} else {
		// A tiki totem, outline only (its eyes, brow, nose and mouth are cut out of it).
		d = sd_round_box(q, vec2(0.2, 0.46), 0.08);
		d = max(d, -sd_round_box(q - vec2(-0.09, 0.2), vec2(0.045, 0.028), 0.01));
		d = max(d, -sd_round_box(q - vec2(0.09, 0.2), vec2(0.045, 0.028), 0.01));
		d = max(d, -sd_round_box(q - vec2(0.0, 0.29), vec2(0.15, 0.012), 0.005));
		d = max(d, -sd_round_box(q - vec2(0.0, 0.05), vec2(0.028, 0.075), 0.01));
		d = max(d, -sd_round_box(q - vec2(0.0, -0.17), vec2(0.13, 0.05), 0.01));
		d = max(d, -sd_round_box(q - vec2(0.0, -0.32), vec2(0.12, 0.015), 0.005));
	}
	return d;
}

// A warm painted-board colour (coral, mustard or sage: never a window's blue or teal).
vec3 bc_warm_paint(float k) {
	float i = mod(floor(k), 3.0);
	return i < 0.5 ? bc_paint_b : (i < 1.5 ? bc_paint_c : bc_paint_d);
}

// A poster or painted board: UV in metres (x across, y up) of a panel `size` (metres), `kind` the glyph
// (0-6), `seed` picks the paints. Muted and unlit: a coloured ground, a pale border, the silhouette in
// cream or dark. `fw` is a pixel's footprint in glyph space (taken outside branches).
vec3 bc_poster(vec2 uv, vec2 size, float kind, float seed, float fw) {
	vec2 q = (uv - size * 0.5) / (min(size.x, size.y) * 0.78);
	vec3 ground = hash11(seed * 1.3 + 0.7) < 0.35 ? bc_cream * 0.95 : bc_warm_paint(seed);
	vec3 ink = hash11(seed * 1.9 + 3.0) < 0.5 ? bc_cream : bc_bamboo_dark * 0.9;
	ink = ground.r > 0.8 ? bc_paint(seed + 2.0) * 0.8 : ink;
	float d = bc_glyph(q, int(kind + 0.5));
	float fill = 1.0 - smoothstep(-fw, fw, d);
	vec3 col = ground * (0.85 + 0.2 * value_noise(uv * 3.0 + seed));
	// A lighter horizon band across the lower third, as a poster of the sea would have.
	col = mix(col, ground * 1.18, step(q.y, -0.2) * 0.5);
	col = mix(col, ink, fill);
	// The pale border.
	vec2 e = min(uv, size - uv);
	float border = 1.0 - smoothstep(0.03, 0.03 + max(fw, 0.004) * min(size.x, size.y), min(e.x, e.y));
	return mix(col, bc_cream, border * 0.9);
}

// A bamboo culm texture: `across` the culm's width direction and `along` its length (metres); fa and fl
// the pixel footprints in those directions. `base` is the culm's honey or grey; `seed` varies the rows.
vec3 bc_bamboo(vec3 base, float across, float along, float fa, float fl, float seed) {
	float period = 0.12;
	float cell = floor(across / period);
	float u = fract(across / period);
	float r = hash12(vec2(cell, seed));
	float r2 = hash12(vec2(cell + 7.0, seed + 1.0));
	vec3 culm = base * (0.9 + 0.2 * r);
	// Some culms are greyed by the sun.
	culm = mix(culm, vec3(dot(culm, vec3(0.34))) * vec3(1.0, 1.0, 0.94), step(0.8, r2) * 0.4);
	float round_shade = 0.9 + 0.2 * sin(u * 3.1416);
	// Nodes: a darker ring with a pale bulge beside it, a few every culm.
	float np = 0.5 + 0.22 * r2;
	float nv = fract((along + r * 3.0) / np);
	float nfw = fl / np;
	float ring = 1.0 - smoothstep(0.03, 0.03 + nfw + 0.01, nv);
	float bulge = smoothstep(0.03, 0.08 + nfw, nv) * (1.0 - smoothstep(0.08 + nfw, 0.16 + nfw, nv));
	culm *= round_shade * (1.0 - 0.28 * ring + 0.05 * bulge);
	// The dark seam between neighbouring culms.
	float seam = min(u, 1.0 - u) * period;
	float gap = 1.0 - smoothstep(0.003, 0.003 + max(fa, 0.005), seam);
	culm = mix(culm, bc_bamboo_dark * 0.7, gap * 0.6);
	// Far off, the detail averages out.
	float lod = smoothstep(0.1, 0.4, fa / period);
	return mix(culm, base * 0.93, lod);
}

// --- Floor patterns ---------------------------------------------------------------------------
// The floor patterns' parameter (BeachSand.sand_param): bits 0-5 flags (1 a lane beside on the left, 2 on
// the right, 4 a pool at the piece's near end, 8 at its far end, 16 an alternate lane tone, 32 the kerb),
// bits 6-15 the piece's length in eighths of a metre (UV.y runs in metres from its near end), bits 16-21
// the lane's hash. UV.x runs -1 to 1 across the lane.

// PAT_BEACH_SAND (80): the beach. Wind ripples running down the street, broad light and dark drifts,
// damp patches and a wet rim round every pool, footprints along a few paths, flat shells and pebbles
// (drawn, never built: nothing on the running surface stands up, and nothing on it is round), a soft
// seam where a neighbouring lane's sand runs beside it. Its brightness stays between bc_sand_dark's and
// bc_sand_light's, so a pool beside it reads against it (tests/suites/test_beach_skin.gd).
vec3 bc_sand(vec3 base, vec3 w, vec2 uv, float param) {
	vec2 p = w.xz;
	vec2 fwp = max(fwidth(p), vec2(1e-4));
	float fpm = max(fwp.x, fwp.y);
	float fu = max(fwidth(uv.x), 1e-4);
	float detail = 1.0 - smoothstep(0.03, 0.18, fpm);
	int flags = int(param + 0.5);
	float len = float((flags >> 6) & 1023) * 0.125;
	// Broad drifts, light and dark.
	float dune = value_noise(p * vec2(0.45, 0.11) + 3.0) * 0.6 + value_noise(p * vec2(1.7, 0.4) + 11.0) * 0.4;
	vec3 col = mix(base * 0.93, base * 1.07, dune);
	// Wind ripples along the street, in patches.
	float ph = p.x / 0.27 + 2.2 * value_noise(vec2(p.y * 0.22, p.x * 0.35));
	float ridge = sin(ph * 6.2832);
	float amp = (1.0 - smoothstep(0.2, 0.5, fwp.x / 0.27)) * smoothstep(0.35, 0.65, value_noise(p * 0.17 + 8.0));
	col *= 1.0 + 0.07 * amp * ridge;
	// Damp patches, and the wet rim round a pool.
	float damp = smoothstep(0.58, 0.8, value_noise(p * vec2(0.2, 0.08) + 31.0));
	float rim = 0.0;
	if ((flags & 4) != 0) {
		rim = max(rim, exp(-max(uv.y, 0.0) / 1.1));
	}
	if ((flags & 8) != 0) {
		rim = max(rim, exp(-max(len - uv.y, 0.0) / 1.1));
	}
	col *= 1.0 - 0.17 * damp - 0.2 * rim * (0.6 + 0.4 * value_noise(p * 1.3));
	// Footprints along a few paths (two layers, each segment of the street may have one).
	if (detail > 0.0) {
		float prints = 0.0;
		for (int li = 0; li < 2; li++) {
			float fl = float(li);
			float seg = 26.0 + 9.0 * fl;
			float k = floor(p.y / seg + fl * 0.37);
			if (hash12(vec2(k, 17.0 + fl * 5.0)) > 0.45) {
				float zs = (k - fl * 0.37) * seg;
				float x0 = (hash12(vec2(k, 3.0 + fl)) - 0.5) * 10.0;
				float dx = (hash12(vec2(k, 8.0 + fl)) - 0.5) * 3.0;
				float cx = x0 + dx * (p.y - zs) / seg;
				float j = floor((p.y - zs) / 0.78);
				if (j > 2.0 && j < 30.0) {
					float parity = mod(j, 2.0) * 2.0 - 1.0;
					vec2 fc = vec2(cx + parity * 0.12, zs + (j + 0.5) * 0.78);
					float ang = (hash12(vec2(j, k)) - 0.5) * 0.5;
					prints = max(prints, bc_ellipse(p, fc, vec2(0.065, 0.15), ang, fpm));
				}
			}
		}
		col *= 1.0 - 0.2 * prints * detail;
		// Shells and pebbles, flat, a few every few metres.
		vec2 cell = floor(p / 1.4);
		float r = hash12(cell + 71.0);
		if (r > 0.86) {
			vec2 off = (vec2(hash12(cell + 5.0), hash12(cell + 9.0)) - 0.5) * 0.9;
			vec2 c = (cell + 0.5) * 1.4 + off;
			float ang = hash12(cell + 13.0) * 6.2832;
			if (r > 0.94) {
				float pb = bc_ellipse(p, c, vec2(0.075, 0.05), ang, fpm);
				col = mix(col, bc_pebble * (0.8 + 0.4 * hash12(cell + 2.0)), pb * detail);
			} else {
				float sh = bc_ellipse(p, c, vec2(0.09, 0.065), ang, fpm);
				float ridge_s = 0.5 + 0.5 * sin(bc_rot(p - c, ang).x * 60.0);
				col = mix(col, bc_shell * (0.88 + 0.12 * ridge_s), sh * detail);
			}
		}
	}
	// Lanes: an alternate tone, and a soft darker seam where a neighbouring lane's sand runs beside it.
	col *= (flags & 16) != 0 ? 0.965 : 1.0;
	float seam = 0.0;
	if ((flags & 1) != 0) {
		seam = max(seam, thin_bar(uv.x + 1.0, 0.03, fu));
	}
	if ((flags & 2) != 0) {
		seam = max(seam, thin_bar(uv.x - 1.0, 0.03, fu));
	}
	return mix(col, col * 0.72, seam);
}

// PAT_BEACH_BOARDWALK (81): a boardwalk run: weathered planks laid across the lane (so their joints
// stream past a runner), each its own tone with a staggered butt joint, nail heads near the lane's
// edges, and rusty steel plates bolted down here and there (flush: drawn, never built). Same parameter
// as the sand. Its darkest is the joints between boards, bc_plank_gap.
vec3 bc_boardwalk(vec3 base, vec3 w, vec2 uv, float param) {
	vec2 p = w.xz;
	vec2 fwp = max(fwidth(p), vec2(1e-4));
	float fpm = max(fwp.x, fwp.y);
	float fu = max(fwidth(uv.x), 1e-4);
	float detail = 1.0 - smoothstep(0.03, 0.18, fpm);
	int flags = int(param + 0.5);
	float lane = float((flags >> 16) & 63);
	float lx = uv.x * 1.2;
	float bw = 0.205;
	float j = floor(p.y / bw);
	float f = fract(p.y / bw);
	float joint_x = (hash12(vec2(j, 7.0)) - 0.5) * 1.6;
	float piece = step(joint_x, lx);
	float tone = (0.82 + 0.34 * hash12(vec2(j, 41.0))) * (0.92 + 0.16 * hash12(vec2(j, piece + 13.0)));
	// Grain along the boards, and a grey weathering.
	float grain = value_noise(vec2(lx * 1.6 + j * 5.0, j * 9.1 + f * 3.0));
	vec3 col = base * tone * (0.9 + 0.2 * mix(0.5, grain, detail));
	col = mix(col, vec3(dot(col, vec3(0.33))) * vec3(1.0, 0.98, 0.94), 0.25 * smoothstep(0.5, 0.8, value_noise(p * 0.3 + 5.0)));
	// The joints between boards, and the butt joint across a board.
	float edge = min(f, 1.0 - f) * bw;
	float gap = 1.0 - smoothstep(0.004, 0.004 + max(fwp.y, 0.006), edge);
	float butt = 1.0 - smoothstep(0.004, 0.004 + max(fwp.x, 0.006), abs(lx - joint_x));
	col = mix(col, bc_plank_gap, max(gap, butt * 0.8));
	// Nail heads near the lane's edges.
	float nail = (1.0 - smoothstep(0.012, 0.012 + fpm, abs(abs(lx) - 0.93))) * (1.0 - smoothstep(0.012, 0.012 + fpm, abs(f - 0.5) * bw));
	col = mix(col, bc_plank_gap * 0.7, nail * detail);
	// Rusty steel plates, one in some 3.4 m cells of each lane, bolted at the corners.
	float pc = floor((p.y + 0.9 * hash11(lane)) / 3.4);
	if (hash12(vec2(pc, lane + 3.0)) > 0.52) {
		float pz = (pc + 0.5) * 3.4 - 0.9 * hash11(lane) + (hash12(vec2(pc, lane + 9.0)) - 0.5) * 1.0;
		float px = (hash12(vec2(pc, lane + 5.0)) - 0.5) * 0.3;
		vec2 pq = vec2(lx - px, p.y - pz);
		float pd = sd_round_box(pq, vec2(0.84, 0.62), 0.03);
		float inside = 1.0 - smoothstep(-fpm, fpm, pd);
		float rust = smoothstep(0.4, 0.75, value_noise(p * vec2(2.0, 1.5) + pc * 7.0));
		vec3 plate = mix(bc_plate * (0.85 + 0.25 * hash12(vec2(pc, lane))), bc_rust, rust * 0.75);
		plate *= 1.0 - 0.35 * (1.0 - smoothstep(0.0, 0.05 + fpm, -pd));
		vec2 bq = abs(pq) - vec2(0.72, 0.5);
		float bolt = (1.0 - smoothstep(0.028, 0.028 + fpm, max(abs(bq.x), abs(bq.y)))) * detail;
		plate = mix(plate, bc_plank_gap * 0.8, bolt);
		col = mix(col, plate, inside);
	}
	float seam = 0.0;
	if ((flags & 1) != 0) {
		seam = max(seam, thin_bar(uv.x + 1.0, 0.03, fu));
	}
	if ((flags & 2) != 0) {
		seam = max(seam, thin_bar(uv.x - 1.0, 0.03, fu));
	}
	return mix(col, col * 0.7, seam);
}

// PAT_BEACH_TANK (82): everything below the floor, seen only through the pools: the black steel walls of a
// pool tank, dark and unlit: panels with rivet rows, rust streaking down from the rim, a pale tide mark
// above the water (a hint of what is below), and a shade that only deepens with depth, so a pool reads as
// a hole at a glance. param: 0 a face across the lane, 1 a face along it, 2 the building faces below the
// street. COLOR is the steel at the rim; this only ever darkens it (a factor below 1.1).
vec3 bc_tank(vec3 base, vec3 w, vec3 n, float param) {
	float h = abs(n.x) > 0.5 ? w.z : w.x;
	vec2 fwp = max(vec2(fwidth(h), fwidth(w.y)), vec2(1e-4));
	float fpm = max(fwp.x, fwp.y);
	float detail = 1.0 - smoothstep(0.03, 0.2, fpm);
	vec2 pc = vec2(h / 1.8, w.y / 1.4);
	vec2 cell = floor(pc);
	vec2 fc = fract(pc);
	vec3 col = base * (0.85 + 0.15 * hash12(cell + 5.0));
	// Panel seams and rivets along them.
	float seam = min(min(fc.x, 1.0 - fc.x) * 1.8, min(fc.y, 1.0 - fc.y) * 1.4);
	float line = 1.0 - smoothstep(0.012, 0.012 + max(fpm, 0.008), seam);
	col *= 1.0 - 0.45 * line;
	float rivet_row = 1.0 - smoothstep(0.035, 0.035 + max(fpm, 0.01), abs(min(fc.y, 1.0 - fc.y) * 1.4 - 0.07));
	float rivet = rivet_row * step(0.85, abs(fract(h / 0.22) - 0.5) * 2.0) * detail;
	col *= 1.0 + 0.2 * rivet;
	// Rust streaking down from the rim and from each panel's top edge.
	float streak = smoothstep(0.55, 0.85, value_noise(vec2(h * 3.2 + cell.x * 3.1, w.y * 0.45)));
	float fall = 1.0 - smoothstep(0.0, 3.2, -w.y);
	float panel_top = 1.0 - smoothstep(0.0, 0.35, 1.0 - fc.y);
	col = mix(col, bc_tank_rust * 0.5, clamp(streak * fall * 0.75 + panel_top * streak * 0.3, 0.0, 0.8));
	// A flange just under the rim: the steel's own tone, a little lighter than its panels.
	float flange = band(w.y, -0.55, -0.14, fwp.y);
	col = mix(col, base, flange * 0.7);
	// The tide mark just above the water, pale and stained.
	float tide = band(w.y, -bc_pool_depth + 0.15, -bc_pool_depth + 0.8, fwp.y) * (0.6 + 0.4 * value_noise(vec2(h * 2.0, 4.0)));
	col = mix(col, bc_tide, tide * 0.7);
	// Dark steel, darker with depth.
	float depth = mix(1.0, 0.2, smoothstep(-0.1, -3.4, w.y));
	return col * depth;
}

// PAT_BEACH_WATER (83): the pool's water far below the floor, seen only through the pools: deep unlit teal,
// slow caustic ridges drifting over it (the time slowed to a stand by Reduced flashing), never lighter
// than 1.12 of its colour, so it stays as dark as a hole's inside must be.
vec3 bc_water(vec3 base, vec3 w, float t) {
	float ts = t * (1.0 - 0.9 * reduced_flashing) * 0.12;
	vec2 q = w.xz * 0.8;
	float a = value_noise(q + vec2(ts, -ts * 0.7));
	float b = value_noise(q * 2.3 + vec2(-ts * 1.1, ts) + 7.0);
	float ridge = pow(clamp(1.0 - abs(a + b - 1.0), 0.0, 1.0), 6.0);
	return base * (0.82 + 0.3 * ridge);
}

// --- Walls ------------------------------------------------------------------------------------------

// PAT_BEACH_WALL (84): a shack's face, flush with the wall's plane, laid out in bays 3-5 m along the track
// by world position (so shacks and chunk cuts join): between bamboo posts each bay is bamboo culms, a
// woven palm mat, weathered planks, rusty corrugated sheets, a painted roller shutter or serving hatch (shut,
// flush), or bamboo with surf posters pasted on (wordless). Up to bc_band_top (the wall-run band) it stays
// calm and closed: nothing opens, glows, juts or looks like a window (a window cyborg's) or a vent, and the
// wall-run height marks (unlit paint) run across it at bc_mark_a and bc_mark_b; above, the upper storeys are
// bamboo, mats and planks with a dark timber course under each veranda floor. param = the building's seed
// (0-999) * 8 (the low bits are free). COLOR is the building's bamboo honey or grey.
vec3 bc_wall(vec3 base, vec3 w, vec3 n, float param) {
	float u = abs(n.x) > 0.5 ? w.z : w.x;
	float v = w.y;
	vec2 fwp = max(vec2(fwidth(u), fwidth(v)), vec2(1e-4));
	float fpm = max(fwp.x, fwp.y);
	float detail = 1.0 - smoothstep(0.03, 0.16, fpm);
	float seed = floor(param / 8.0);
	float bay_w = 3.0 + 1.8 * hash11(seed * 2.3 + 1.0);
	float shift = hash11(seed * 1.7) * bay_w;
	float us = u + shift;
	float bi = floor(us / bay_w);
	float bayu = us - bi * bay_w;
	float r = hash12(vec2(bi, seed));
	bool upper = v > bc_band_top;
	float style = r < 0.28 ? 0.0 : (r < 0.42 ? 1.0 : (r < 0.56 ? 2.0 : (r < 0.72 ? 3.0 : (r < 0.86 ? 4.0 : 5.0))));
	if (upper) {
		// The upper storeys: bamboo, mats and planks.
		float r2 = hash12(vec2(bi + 40.0, seed));
		style = r2 < 0.5 ? 0.0 : (r2 < 0.75 ? 1.0 : 2.0);
	}
	vec3 col = base;
	if (style < 0.5) {
		// Bamboo culms, standing.
		col = bc_bamboo(base, us, v, fwp.x, fwp.y, seed);
	} else if (style < 1.5) {
		// A woven palm mat: diagonals over two tones, framed by two bamboo rails.
		vec2 d = vec2(us + v, us - v) / 0.16;
		vec2 cd = floor(d);
		float weave = mod(cd.x + cd.y, 2.0);
		vec3 mat = base * mix(0.86, 1.04, weave) * (0.94 + 0.12 * hash12(cd * 0.37 + seed));
		float fine = 1.0 - smoothstep(0.03, 0.03 + max(fwp.x, fwp.y) / 0.16, min(fract(d.x), fract(d.y)));
		mat *= 1.0 - 0.14 * fine * detail;
		col = mix(mat, base * 0.95, smoothstep(0.1, 0.4, fpm));
		float rail = max(band(v, 0.85, 0.97, fwp.y), band(v, 3.25, 3.37, fwp.y));
		col = mix(col, bc_bamboo(base * 1.05, v, us, fwp.y, fwp.x, seed + 3.0), rail);
	} else if (style < 2.5) {
		// Weathered planks, laid across, with staggered butt joints and nails.
		float bh = 0.2;
		float row = floor(v / bh);
		float fr = fract(v / bh);
		float off = hash11(row * 3.7 + seed) * 1.8;
		float col_i = floor((us + off) / 1.8);
		float tone = 0.8 + 0.34 * hash12(vec2(row, col_i + seed));
		vec3 plank = mix(bc_timber, base, 0.45) * 1.15 * tone;
		plank = mix(plank, vec3(dot(plank, vec3(0.34))) * vec3(1.04, 1.0, 0.92), 0.15);
		float edge_y = min(fr, 1.0 - fr) * bh;
		float gap_y = 1.0 - smoothstep(0.003, 0.003 + max(fwp.y, 0.005), edge_y);
		float fx = fract((us + off) / 1.8) * 1.8;
		float gap_x = 1.0 - smoothstep(0.003, 0.003 + max(fwp.x, 0.005), min(fx, 1.8 - fx));
		plank = mix(plank, bc_bamboo_dark * 0.55, max(gap_y, gap_x * 0.8) * 0.8);
		float nail = (1.0 - smoothstep(0.008, 0.008 + fpm, abs(min(fx, 1.8 - fx) - 0.1))) * (1.0 - smoothstep(0.008, 0.008 + fpm, abs(fr - 0.5) * bh));
		plank = mix(plank, bc_bamboo_dark * 0.5, nail * detail);
		col = mix(plank, bc_timber * 0.95, smoothstep(0.1, 0.4, fpm));
	} else if (style < 3.5) {
		// Rusty corrugated sheets: ribs every 0.18 m, rust blooms and streaks, an overlap at each sheet's edge.
		// Mostly rust-brown; a few keep faded paint.
		float sheet = floor(us / 0.9);
		float sr = hash12(vec2(sheet, seed + 21.0));
		vec3 paint = mix(bc_rust * 1.1, bc_warm_paint(seed + sheet) * 0.85, step(0.78, sr));
		float rib = 0.5 + 0.5 * sin(us / 0.18 * 6.2832);
		float ribs = mix(0.85 + 0.2 * rib, 1.0, smoothstep(0.1, 0.35, fwp.x / 0.18));
		vec3 sh = paint * (0.8 + 0.3 * sr) * ribs;
		float bloom = smoothstep(0.45, 0.8, value_noise(vec2(us * 1.3, v * 0.9) + sheet * 3.0));
		float streak = smoothstep(0.55, 0.85, value_noise(vec2(us * 5.0, v * 0.3 + sheet)));
		sh = mix(sh, bc_steel_rust * 1.1, max(bloom * 0.5, streak * 0.4));
		float sx = fract(us / 0.9) * 0.9;
		float lap = 1.0 - smoothstep(0.01, 0.01 + max(fwp.x, 0.005), min(sx, 0.9 - sx));
		sh *= 1.0 - 0.3 * lap;
		col = sh;
	} else if (style < 4.5) {
		// A painted shutter or serving hatch, shut and flush: a muted painted panel in a darker frame (a roller
		// shutter's fine slats, or a hatch's boards with a diagonal brace). The bay's wall around it is bamboo.
		float hatch_w = 2.4;
		float cu = bayu - bay_w * 0.5;
		bool shutter = hash11(bi * 1.3 + seed) < 0.5;
		float y0 = shutter ? 0.0 : 0.9;
		float y1 = shutter ? 2.5 : 2.3;
		col = bc_bamboo(base, us, v, fwp.x, fwp.y, seed);
		vec2 q = vec2(abs(cu) - hatch_w * 0.5, abs(v - (y0 + y1) * 0.5) - (y1 - y0) * 0.5);
		float dd = max(q.x, q.y);
		float inside = 1.0 - smoothstep(-fpm, fpm, dd);
		vec3 paint = bc_warm_paint(seed + bi * 3.0);
		vec3 panel = paint;
		if (shutter) {
			panel *= 0.9 + 0.1 * sin(v / 0.07 * 6.2832) * (1.0 - smoothstep(0.1, 0.4, fwp.y / 0.07));
		} else {
			float pb = floor(cu / 0.3);
			panel *= 0.9 + 0.1 * hash12(vec2(pb, bi + seed));
			float seam_x = 1.0 - smoothstep(0.004, 0.004 + max(fwp.x, 0.005), (0.5 - abs(fract(cu / 0.3) - 0.5)) * 0.3);
			panel = mix(panel, paint * 0.55, seam_x * 0.7 * detail);
			float brace = 1.0 - smoothstep(0.04, 0.04 + fpm, abs((cu * 0.6) - (v - 1.6)) * 0.7);
			panel = mix(panel, paint * 0.65, brace * 0.7 * step(abs(cu), hatch_w * 0.5));
		}
		float frame = 1.0 - smoothstep(0.07, 0.07 + fpm, -dd);
		panel = mix(panel, bc_bamboo_dark * 0.9, frame);
		col = mix(col, panel, inside);
	} else {
		// Bamboo with a surf poster or two pasted on, wordless: a sun, waves, a palm, a board, a flamingo or a
		// glass, at chest height.
		col = bc_bamboo(base, us, v, fwp.x, fwp.y, seed);
		for (int i = 0; i < 2; i++) {
			float fi = float(i);
			float pcx = bay_w * (0.3 + 0.4 * fi) + (hash12(vec2(bi, seed + fi)) - 0.5) * 0.4;
			float pcy = 2.3 + 0.55 * hash12(vec2(bi + fi, seed + 2.0));
			vec2 pq = vec2(bayu - pcx, v - pcy);
			vec2 psz = vec2(0.66, 0.92);
			if (abs(pq.x) < psz.x * 0.5 && abs(pq.y) < psz.y * 0.5 && hash12(vec2(bi, seed + fi + 9.0)) > 0.25) {
				float kind = floor(hash12(vec2(bi + fi * 5.0, seed + 11.0)) * 6.0);
				float fwq = max(fwp.x, fwp.y) / (min(psz.x, psz.y) * 0.78);
				vec3 poster = bc_poster(pq + psz * 0.5, psz, kind, seed + bi + fi * 2.0, max(fwq, 0.004));
				col = poster * (0.92 + 0.08 * value_noise(vec2(u, v) * 6.0));
			}
		}
	}
	// A bamboo post at each bay's edge.
	float pd = min(bayu, bay_w - bayu);
	float post = 1.0 - smoothstep(0.07, 0.07 + fwp.x, pd);
	if (post > 0.0) {
		col = mix(col, bc_bamboo(base * 1.08, v, pd, fwp.y, fwp.x, seed + 5.0), post);
	}
	if (upper) {
		// A dark timber course under each veranda floor: the storeys' floor lines.
		float sv = (v - bc_band_top - 0.55) / 3.6;
		float floor_line = band(fract(sv), 0.0, 0.07, fwp.y / 3.6);
		col = mix(col, bc_timber * 0.6, floor_line * 0.9 * step(0.0, sv));
	} else {
		// The sand blown against the foot of the wall.
		float sandy = (1.0 - smoothstep(0.0, 0.5, v)) * (0.5 + 0.5 * value_noise(vec2(u * 2.0, 1.0)));
		col = mix(col, bc_sand_dark, sandy * 0.55);
		// The wall-run height marks, unlit paint.
		float marks = max(band(v, bc_mark_a - 0.025, bc_mark_a + 0.025, fwp.y), band(v, bc_mark_b - 0.025, bc_mark_b + 0.025, fwp.y));
		col = mix(col, bc_mark, clamp(marks, 0.0, 1.0) * 0.9);
	}
	return col;
}

// PAT_BEACH_THATCH (85): thatch, on roofs and eaves and the bars' canopies: courses of straw down the
// slope, each a tone of its own with a ragged lower fringe and a shadow under it. COLOR is the straw.
vec3 bc_thatch(vec3 base, vec3 w, vec3 n) {
	float lat = abs(n.z) > 0.5 ? w.x : w.z;
	float s = w.y * 1.55;
	if (abs(n.y) > 0.8) {
		s = abs(n.z) > 0.5 ? w.z : w.x;
	}
	float fl = max(fwidth(lat), 1e-4);
	float fs = max(fwidth(s), 1e-4);
	float detail = 1.0 - smoothstep(0.05, 0.25, max(fl, fs));
	float course = floor(s / 0.34);
	float cf = fract(s / 0.34);
	float strand = floor(lat / 0.05);
	float sr = hash12(vec2(strand, course));
	float jag = hash12(vec2(strand, course + 5.0)) * 0.14 - 0.07;
	vec3 col = base * (0.72 + 0.46 * sr);
	float shadow = smoothstep(0.0, 0.3, cf + jag);
	col *= 0.55 + 0.45 * shadow;
	col = mix(col, bc_thatch_dark * (0.8 + 0.4 * sr), (1.0 - shadow) * 0.5);
	col *= 0.9 + 0.2 * value_noise(vec2(lat * 0.6, s * 0.4));
	return mix(col, base * 0.8, 1.0 - detail);
}

// PAT_BEACH_STEEL (86): black industrial steel with rust streaks, on tanks, water towers, chimneys and the
// party barges' hulls: panels with rivet rows, weld seams, rust running down from each panel's top edge and
// pooling in blooms. param 0 a tank or tower, 1 a chimney (bands of lighter steel every 2.4 m), 2 a hull
// (bigger panels, little rust). COLOR is the steel.
vec3 bc_steel_pat(vec3 base, vec3 w, vec3 n, float param) {
	vec2 pcoord = face_coords(n);
	float mode = floor(param + 0.5);
	vec2 psize = mode > 1.5 ? vec2(2.4, 1.8) : vec2(1.5, 1.2);
	vec2 fwp = max(fwidth(pcoord), vec2(1e-4));
	float fpm = max(fwp.x, fwp.y);
	float detail = 1.0 - smoothstep(0.03, 0.2, fpm);
	vec2 cell = floor(pcoord / psize);
	vec2 fc = fract(pcoord / psize);
	vec3 col = base * (0.86 + 0.28 * hash12(cell + 3.0));
	float seam = min(min(fc.x, 1.0 - fc.x) * psize.x, min(fc.y, 1.0 - fc.y) * psize.y);
	col *= 1.0 - 0.45 * (1.0 - smoothstep(0.012, 0.012 + max(fpm, 0.008), seam));
	float rivet_line = 1.0 - smoothstep(0.03, 0.03 + max(fpm, 0.01), abs(min(fc.y, 1.0 - fc.y) * psize.y - 0.07));
	float rivet = rivet_line * step(0.85, abs(fract(pcoord.x / 0.21) - 0.5) * 2.0) * detail;
	col *= 1.0 + 0.7 * rivet;
	float rust_amount = mode > 1.5 ? 0.35 : 1.0;
	float streak = smoothstep(0.5, 0.82, value_noise(vec2(pcoord.x * 3.3 + cell.x * 3.1, pcoord.y * 0.4 + cell.y))) * fc.y;
	float bloom = smoothstep(0.55, 0.85, value_noise(pcoord * 0.7 + cell * 2.3));
	col = mix(col, bc_steel_rust * (0.7 + 0.5 * hash12(cell + 8.0)), clamp(max(streak * 0.7, bloom * 0.55) * rust_amount, 0.0, 0.8));
	if (mode > 0.5 && mode < 1.5) {
		float bnd = band(fract(w.y / 2.4), 0.0, 0.09, fwp.y / 2.4);
		col = mix(col, base * 1.9, bnd * 0.6);
	}
	return col;
}

// PAT_BEACH_PAINT (87): a painted board with a wordless poster: a hazard sign's content, a billboard's back.
// UV in metres on the panel (x across, y up); param = seed (0-99) + 100 * glyph (0-6) + 1000 * the panel's
// height in decimetres + 100000 * its width in decimetres. Muted unlit paints and a cream border: never a
// glowing hazard colour.
vec3 bc_board(vec2 uv, float param) {
	float code = floor(param + 0.5);
	float seed = mod(code, 100.0);
	float kind = mod(floor(code / 100.0), 10.0);
	float hdm = mod(floor(code / 1000.0), 100.0);
	float wdm = floor(code / 100000.0);
	vec2 size = vec2(wdm * 0.1, hdm * 0.1);
	if (wdm < 0.5) {
		size.x = size.y;
	}
	float fw = max(max(fwidth(uv.x), fwidth(uv.y)), 1e-4) / (min(size.x, size.y) * 0.78);
	vec3 poster = bc_poster(uv, size, kind, seed, max(fw, 0.004));
	return poster;
}

// PAT_BEACH_NEON (88): a neon silhouette sign: a dark board with a glyph's outline (a palm, a wave, a
// flamingo, a cocktail, a surfboard, the sun or a tiki totem; never words) and a thin frame glowing in
// COLOR (violet, blue or warm white only: pink, yellow, orange, green and cyan belong to hazards). UV in
// metres (x across, y up); param = glyph (0-6) + 8 * the board's height in decimetres + 8 * 256 * its
// width in decimetres. Reduced flashing needs nothing here: it doesn't flicker.
vec3 bc_neon(vec3 base, vec2 uv, float param, vec3 dark, inout float glow) {
	float code = floor(param + 0.5);
	float kind = mod(code, 8.0);
	float hdm = mod(floor(code / 8.0), 256.0);
	float wdm = floor(code / 2048.0);
	vec2 size = vec2(wdm * 0.1, hdm * 0.1);
	float scale = min(size.x, size.y) * 0.78;
	vec2 q = (uv - size * 0.5) / scale;
	float fw = max(max(fwidth(uv.x), fwidth(uv.y)), 1e-4) / scale;
	float d = bc_glyph(q, int(kind + 0.5));
	float lw = 0.03;
	float on = 1.0 - smoothstep(lw - fw, lw + fw, abs(d));
	// The frame: a rounded rectangle inset from the board's edge.
	vec2 half_size = size * 0.5 / scale;
	float fd = sd_round_box(q, half_size - 0.1, 0.14);
	float frame = 1.0 - smoothstep(lw * 0.8 - fw, lw * 0.8 + fw, abs(fd));
	float lit = max(on, frame);
	// A hot core, warmer than the tube; far off the lines average out.
	float core = 1.0 - smoothstep(lw * 0.35 - fw, lw * 0.35 + fw, abs(d));
	vec3 tube = mix(base, vec3(1.0, 0.97, 0.9), core * 0.5);
	float lod = smoothstep(0.05, 0.25, fw);
	lit = mix(lit, 0.28, lod);
	glow *= lit;
	return mix(dark, tube, lit);
}

// PAT_BEACH_TIMBER (89): bamboo poles, rails, planks and palm trunks: bamboo culms with nodes, weathered
// boards or a ringed trunk, running along `axis`. param = axis (0 along y, 1 along x, 2 along z) + 4 * style
// (0 bamboo, 1 plank, 2 palm trunk) + 16 * seed (0-99). Any face of a box or prism takes it.
vec3 bc_timber_pat(vec3 base, vec3 w, vec3 n, float param) {
	float code = floor(param + 0.5);
	float axis = mod(code, 4.0);
	float style = mod(floor(code / 4.0), 4.0);
	float seed = floor(code / 16.0);
	vec2 pcoord = face_coords(n);
	float along = axis < 0.5 ? w.y : (axis < 1.5 ? w.x : w.z);
	float across = pcoord.x + pcoord.y - along;
	float fa = max(fwidth(across), 1e-4);
	float fl = max(fwidth(along), 1e-4);
	if (style < 0.5) {
		return bc_bamboo(base, across, along, fa, fl, seed);
	} else if (style < 1.5) {
		float bh = 0.2;
		float row = floor(across / bh);
		float tone = 0.74 + 0.4 * hash12(vec2(row, seed));
		vec3 plank = mix(bc_timber, base, 0.4) * tone;
		float edge = min(fract(across / bh), 1.0 - fract(across / bh)) * bh;
		plank = mix(plank, bc_bamboo_dark * 0.5, 1.0 - smoothstep(0.004, 0.004 + max(fa, 0.006), edge));
		float grain = value_noise(vec2(along * 1.5, row * 7.0 + seed));
		return mix(plank * (0.9 + 0.2 * grain), base * 0.85, smoothstep(0.1, 0.4, fa / bh));
	}
	// A palm trunk: pale rings every 0.3 m, a rough dark grain between.
	float ring = fract(along / 0.3);
	float rg = 1.0 - smoothstep(0.0, 0.18 + fl / 0.3, ring);
	float fibre = value_noise(vec2(across * 9.0, along * 1.4 + seed));
	return base * (0.8 + 0.25 * fibre) * (1.0 - 0.3 * rg);
}

// Dispatches the Beach's patterns (ids 80-89) for kit_solid.gdshader. `eye` isn't needed: nothing here is
// reflective. Everything but the neon (PAT_BEACH_NEON) leaves `glow` alone (zero).
vec3 beach_surface(int pattern, float param, vec3 base, vec3 w, vec3 n, vec2 uv, float t, inout float glow) {
	if (pattern == 80) {
		return bc_sand(base, w, uv, param);
	} else if (pattern == 81) {
		return bc_boardwalk(base, w, uv, param);
	} else if (pattern == 82) {
		return bc_tank(base, w, n, param);
	} else if (pattern == 83) {
		return bc_water(base, w, t);
	} else if (pattern == 84) {
		return bc_wall(base, w, n, param) * bc_daylight;
	} else if (pattern == 85) {
		return bc_thatch(base, w, n) * bc_daylight;
	} else if (pattern == 86) {
		return bc_steel_pat(base, w, n, param);
	} else if (pattern == 87) {
		return bc_board(uv, param);
	} else if (pattern == 88) {
		return bc_neon(base, uv, param, vec3(0.03, 0.03, 0.05), glow);
	} else if (pattern == 89) {
		return bc_timber_pat(base, w, n, param) * (abs(n.y) > 0.5 ? 1.0 : bc_daylight);
	}
	return base;
}

// Painted marks for lived-in zones (Gangland): graffiti pieces and tags, stencilled supply codes,
// and the corporate logo (kit_logo.gdshaderinc). Include after kit_common.gdshaderinc.
// Pixel footprints are passed in: derivatives taken inside a branch that differs between
// neighbouring pixels are undefined (some GPUs return NaN, and the glow pass blows one NaN pixel up
// into a white disc), so callers take them in uniform control flow.
#ifndef KIT_MARKS_INCLUDED
#define KIT_MARKS_INCLUDED

#include "res://scripts/world/meshes/shaders/kit_logo.gdshaderinc"

// 1 between a and b, 0 outside, anti-aliased over the footprint fw. Unlike filtered_pulse() it
// doesn't repeat, so a and b may be anything (filtered_pulse needs 0 <= a < b <= 1).
float band(float x, float a, float b, float fw) {
	fw = max(fw, 1e-4);
	return clamp((x - a) / fw + 0.5, 0.0, 1.0) * clamp((b - x) / fw + 0.5, 0.0, 1.0);
}

// Signed distance to a rounded box (half extents b, corner radius r) centred on the origin.
float sd_round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// Distance to the segment a-b.
float sd_segment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	return length(pa - ba * clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0));
}

// One bubble letter of a graffiti piece: a rounded box in its cell with a counter or a notch cut
// out, its size and baseline bouncing a little. lp: metres from the cell's centre; (lw, h) the
// cell. Signed distance, negative inside.
float bubble_letter(vec2 lp, float lw, float h, float ol, float k) {
	float r1 = hash11(k * 1.7 + 0.3);
	float r2 = hash11(k * 2.9 + 1.1);
	float r3 = hash11(k * 4.3 + 2.7);
	vec2 hb = vec2(lw * (0.5 + 0.08 * r1) - ol * 0.4, h * (0.43 + 0.07 * r2) - ol * 0.5);
	lp.y -= (r3 - 0.5) * h * 0.12;
	float d = sd_round_box(lp, hb, min(hb.x, hb.y) * 0.6);
	float shape = floor(hash11(k * 7.1 + 3.3) * 8.0);
	vec2 hole = vec2(hb.x * 0.28, hb.y * 0.2);
	float cut = 1e3;
	if (shape < 1.0) {
		cut = sd_round_box(lp - vec2(0.0, hb.y * 0.35), hole, hole.y * 0.9);
	} else if (shape < 2.0) {
		cut = sd_round_box(lp, hole * vec2(1.0, 1.6), hole.x * 0.9);
	} else if (shape < 3.0) {
		cut = min(sd_round_box(lp - vec2(0.0, hb.y * 0.42), hole * 0.8, hole.y * 0.7),
			sd_round_box(lp + vec2(0.0, hb.y * 0.38), hole * 0.8, hole.y * 0.7));
	} else if (shape < 4.0) {
		cut = sd_round_box(lp - vec2(hb.x * 0.7, 0.0), vec2(hb.x * 0.55, hole.y), hole.y * 0.9);
	} else if (shape < 5.0) {
		cut = sd_round_box(lp + vec2(hb.x * 0.7, hb.y * 0.2), vec2(hb.x * 0.5, hole.y * 0.8), hole.y * 0.7);
	} else if (shape < 6.0) {
		cut = sd_round_box(lp - vec2(0.0, hb.y * 0.75), vec2(hole.x, hb.y * 0.55), hole.x * 0.9);
	} else if (shape < 7.0) {
		cut = sd_round_box(lp + vec2(0.0, hb.y * 0.75), vec2(hole.x, hb.y * 0.5), hole.x * 0.9);
	}
	return max(d, -cut);
}

// One scribbled tag letter: three strokes through four points at hashed heights, joined to its
// neighbours (the last point of a letter is the first of the next). q in letter units (letters
// `size` metres wide and tall); returns the distance in metres.
float tag_letter(vec2 q, float li, float k, vec2 size) {
	vec2 p0 = vec2(li, 0.15 + 0.7 * hash11(li * 3.1 + k));
	vec2 p1 = vec2(li + 0.33, 0.05 + 0.9 * hash11(li * 5.3 + k + 1.0));
	vec2 p2 = vec2(li + 0.66, 0.05 + 0.9 * hash11(li * 7.7 + k + 2.0));
	vec2 p3 = vec2(li + 1.0, 0.15 + 0.7 * hash11((li + 1.0) * 3.1 + k));
	vec2 m = q * size;
	return min(sd_segment(m, p0 * size, p1 * size), min(sd_segment(m, p1 * size, p2 * size),
		sd_segment(m, p2 * size, p3 * size)));
}

// Graffiti (uv in metres, seed a whole number) in slots of 4.2 x 2.8 m. A painted slot holds either
// a tag (a word of thin, slanted strokes) or a piece (chunky bubble letters, each a fill ringed by
// a dark outline); `density` is the share of slots painted and `aa` a pixel's footprint in metres
// (max of fwidth(uv)), passed in so callers may branch around it. Returns x = fill coverage, y =
// outline coverage (0 for tags), z = a 0-1 pick for the fill colour, w = 1 for a piece. At a
// distance the letters blur to their average coverage instead of shimmering.
vec4 graffiti_marks(vec2 uv, float seed, float density, float aa) {
	aa = max(aa, 1e-4);
	vec2 cs = vec2(4.2, 2.8);
	vec2 slot = floor(uv / cs);
	vec2 f = uv - slot * cs;
	vec2 k = slot + seed * 1.31;
	if (hash12(k) > density) {
		return vec4(0.0);
	}
	float piece = step(0.4, hash12(k + 8.0));
	float letters = 3.0 + floor(hash12(k + 4.0) * 3.0);
	// Letter height and width in metres; the word always fits its slot.
	float h = piece > 0.5 ? 0.75 + 0.65 * hash12(k + 3.0) : 0.4 + 0.35 * hash12(k + 3.0);
	float lw = min(h * (piece > 0.5 ? 0.72 : 0.62), 3.9 / letters);
	vec2 origin = vec2(0.15 + (cs.x - 0.3 - letters * lw) * hash12(k + 1.0), 0.15 + (cs.y - 0.3 - h) * hash12(k + 2.0));
	vec2 m = f - origin;
	m.x += m.y * 0.22;
	vec2 q = m / vec2(lw, h);
	if (q.x < -0.2 || q.x > letters + 0.2 || q.y < -0.2 || q.y > 1.2) {
		return vec4(0.0);
	}
	float far = smoothstep(0.05, 0.2, aa);
	float pick = hash12(k + 5.0);
	float li = clamp(floor(q.x), 0.0, letters - 1.0);
	float kf = hash12(k + 6.0) * 97.0;
	if (piece > 0.5) {
		// Bubble letters overlapping their neighbours, so their outlines merge into one piece.
		float ol = 0.07 + 0.03 * h;
		float ln = clamp(fract(q.x) < 0.5 ? li - 1.0 : li + 1.0, 0.0, letters - 1.0);
		float wob = (value_noise(uv * 3.1 + seed) - 0.5) * 0.05;
		float d = bubble_letter(vec2((q.x - li - 0.5) * lw, (q.y - 0.5) * h), lw, h, ol, li + kf);
		d = min(d, bubble_letter(vec2((q.x - ln - 0.5) * lw, (q.y - 0.5) * h), lw, h, ol, ln + kf)) + wob;
		float fill = 1.0 - smoothstep(-aa, aa, d);
		float ring = (1.0 - smoothstep(-aa, aa, d - ol)) - fill;
		return vec4(mix(fill, 0.45, far), mix(ring, 0.2, far), pick, 1.0);
	}
	// Tags: a scribbled signature of joined strokes.
	float width = 0.035 + 0.02 * hash12(k + 7.0);
	float d = tag_letter(q, li, kf, vec2(lw, h)) - width;
	float stroke = (1.0 - smoothstep(-aa, aa, d)) * step(0.0, q.x) * step(q.x, letters);
	return vec4(mix(stroke, 0.2, far), 0.0, pick, 0.0);
}

// One row of stencilled block glyphs (2 x 3 strokes each, the vertical strokes broken by the
// stencil's bridges) from p = (0, 0) rightward, `gh` metres tall; `blur` is the pixel footprint
// in glyphs. Returns coverage.
float stencil_row(vec2 p, float gh, float count, float seed, float blur) {
	vec2 q = p / vec2(gh * 0.72, gh);
	if (q.x < 0.0 || q.x >= count || q.y < 0.0 || q.y >= 1.0) {
		return 0.0;
	}
	float gi = floor(q.x);
	vec2 g = (vec2(fract(q.x), q.y) - vec2(0.12, 0.0)) / vec2(0.76, 1.0);
	if (g.x < 0.0 || g.x >= 1.0) {
		return 0.0;
	}
	vec2 gs = g * vec2(2.0, 3.0);
	vec2 sub = floor(gs);
	vec2 sf = fract(gs);
	float r = hash12(vec2(gi, seed) * 1.73 + sub * 3.1);
	float bridge = step(0.14, abs(sf.y - 0.5));
	float on = r < 0.45 ? step(abs(sf.y - 0.5), 0.2) : (r < 0.85 ? step(abs(sf.x - 0.5), 0.24) * bridge : 0.0);
	return mix(on, 0.3, smoothstep(0.08, 0.3, blur));
}

// A stencilled supply marking centred on uv = (0, 0) (metres), `scale` metres tall overall: a code
// in large glyphs, a rule, and a line of small glyphs under it. `fw` is a pixel's footprint in
// metres (max of fwidth(uv)), taken outside branches. Returns coverage.
float stencil_code(vec2 uv, float scale, float seed, float fw) {
	float big = scale * 0.42;
	float small = scale * 0.2;
	float count = 3.0 + floor(hash11(seed * 3.7 + 0.5) * 3.0);
	float width = count * big * 0.72;
	vec2 o = uv + vec2(width * 0.5, 0.0);
	float top = scale * 0.5;
	float c = stencil_row(o - vec2(0.0, top - big), big, count, seed, fw / big);
	float rule_y = top - big - scale * 0.08;
	float rule = step(abs(o.y - rule_y), scale * 0.025) * step(0.0, o.x) * step(o.x, width);
	c = max(c, rule * (1.0 - 0.7 * smoothstep(0.08, 0.3, fw / scale)));
	c = max(c, stencil_row(o - vec2(0.0, rule_y - scale * 0.06 - small), small, floor(width / (small * 0.72)),
		seed + 7.0, fw / small));
	return c;
}

#endif

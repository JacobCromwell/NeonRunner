// The House's reel symbols (GDD §10), drawn as signed distances so they stay crisp at any size and on
// every renderer: the 7 (the buttons' symbol: royal blue, ringed in white), the cherry (the cherry bombs:
// two red cherries on green stems), BAR (the gold blocks: dark letters on a gold plate) and the lightning
// (the fence: a fence-pink bolt). Each keeps the colour of what it announces, the 7 the colour of the
// buttons, which is no hazard's (the buttons are safe to run over).
// p: the symbol's cell, -0.5 to 0.5 each way, y up. symbol_color() returns the colour (rgb) and how
// much of the pixel the symbol covers (a); `aa` is the edge's softness in cell units.

const int SYMBOL_SEVEN = 0;
const int SYMBOL_CHERRY = 1;
const int SYMBOL_BAR = 2;
const int SYMBOL_LIGHTNING = 3;

const vec3 SEVEN_BLUE = vec3(0.1, 0.27, 1.0);
const vec3 SEVEN_RING = vec3(1.0, 1.0, 1.0);
const vec3 CHERRY_RED = vec3(0.95, 0.07, 0.1);
const vec3 STEM_GREEN = vec3(0.16, 0.55, 0.16);
const vec3 BAR_GOLD = vec3(1.0, 0.74, 0.16);
const vec3 BAR_INK = vec3(0.08, 0.05, 0.02);
const vec3 BOLT_PINK = vec3(1.0, 0.18, 0.62);

float sd_segment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

float sd_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + vec2(r);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

// The lightning bolt: a zigzag of six corners (an exact polygon distance, inside negative).
float sd_bolt(vec2 p) {
	vec2 v[6] = vec2[6](vec2(0.13, 0.43), vec2(-0.21, 0.0), vec2(0.0, 0.0), vec2(-0.14, -0.43),
		vec2(0.23, 0.07), vec2(0.03, 0.07));
	float d = dot(p - v[0], p - v[0]);
	float s = 1.0;
	for (int i = 0; i < 6; i++) {
		int j = (i + 5) % 6;
		vec2 e = v[j] - v[i];
		vec2 w = p - v[i];
		vec2 b = w - e * clamp(dot(w, e) / dot(e, e), 0.0, 1.0);
		d = min(d, dot(b, b));
		bool c1 = p.y >= v[i].y;
		bool c2 = p.y < v[j].y;
		bool c3 = e.x * w.y > e.y * w.x;
		if ((c1 && c2 && c3) || (!c1 && !c2 && !c3)) {
			s = -s;
		}
	}
	return s * sqrt(d);
}

// The 7: a top bar and a slanted stem.
float sd_seven(vec2 p) {
	float bar = sd_segment(p, vec2(-0.25, 0.31), vec2(0.25, 0.31)) - 0.085;
	float stem = sd_segment(p, vec2(0.25, 0.31), vec2(-0.06, -0.37)) - 0.095;
	return min(bar, stem);
}

// BAR's letters, stroked.
float sd_bar_letters(vec2 p) {
	float w = 0.022;
	float d = 10.0;
	// B
	d = min(d, sd_segment(p, vec2(-0.3, -0.11), vec2(-0.3, 0.11)));
	d = min(d, sd_segment(p, vec2(-0.3, 0.11), vec2(-0.2, 0.11)));
	d = min(d, sd_segment(p, vec2(-0.2, 0.11), vec2(-0.17, 0.06)));
	d = min(d, sd_segment(p, vec2(-0.17, 0.06), vec2(-0.2, 0.005)));
	d = min(d, sd_segment(p, vec2(-0.3, 0.005), vec2(-0.19, 0.005)));
	d = min(d, sd_segment(p, vec2(-0.19, 0.005), vec2(-0.155, -0.055)));
	d = min(d, sd_segment(p, vec2(-0.155, -0.055), vec2(-0.19, -0.11)));
	d = min(d, sd_segment(p, vec2(-0.19, -0.11), vec2(-0.3, -0.11)));
	// A
	d = min(d, sd_segment(p, vec2(-0.09, -0.11), vec2(0.005, 0.11)));
	d = min(d, sd_segment(p, vec2(0.005, 0.11), vec2(0.1, -0.11)));
	d = min(d, sd_segment(p, vec2(-0.05, -0.03), vec2(0.06, -0.03)));
	// R
	d = min(d, sd_segment(p, vec2(0.16, -0.11), vec2(0.16, 0.11)));
	d = min(d, sd_segment(p, vec2(0.16, 0.11), vec2(0.27, 0.11)));
	d = min(d, sd_segment(p, vec2(0.27, 0.11), vec2(0.305, 0.06)));
	d = min(d, sd_segment(p, vec2(0.305, 0.06), vec2(0.27, 0.005)));
	d = min(d, sd_segment(p, vec2(0.27, 0.005), vec2(0.16, 0.005)));
	d = min(d, sd_segment(p, vec2(0.22, 0.005), vec2(0.31, -0.11)));
	return d - w;
}

// Paints `color` over `base` where the distance `d` is inside, with a soft edge.
vec4 paint(vec4 base, vec3 color, float d, float aa) {
	float a = 1.0 - smoothstep(-aa, aa, d);
	return vec4(mix(base.rgb, color, a), max(base.a, a));
}

vec4 symbol_color(int id, vec2 p, float aa) {
	vec4 c = vec4(0.0);
	if (id == SYMBOL_SEVEN) {
		float d = sd_seven(p);
		c = paint(c, SEVEN_RING, d - 0.05, aa);
		c = paint(c, SEVEN_BLUE, d, aa);
	} else if (id == SYMBOL_CHERRY) {
		float stems = min(sd_segment(p, vec2(-0.16, -0.08), vec2(0.06, 0.3)),
			sd_segment(p, vec2(0.16, -0.14), vec2(0.06, 0.3))) - 0.03;
		float leaf = length((p - vec2(0.17, 0.31)) * vec2(1.0, 2.2)) - 0.11;
		c = paint(c, STEM_GREEN, min(stems, leaf), aa);
		float left = length(p - vec2(-0.16, -0.17)) - 0.165;
		float right = length(p - vec2(0.15, -0.23)) - 0.165;
		c = paint(c, CHERRY_RED * 0.55, min(left, right) - 0.03, aa);
		c = paint(c, CHERRY_RED, min(left, right), aa);
		// A highlight on each cherry.
		float shine = min(length(p - vec2(-0.21, -0.11)), length(p - vec2(0.1, -0.17))) - 0.035;
		c = paint(c, vec3(1.0, 0.75, 0.75), shine, aa);
	} else if (id == SYMBOL_BAR) {
		float plate = sd_box(p, vec2(0.39, 0.2), 0.06);
		c = paint(c, BAR_INK, plate - 0.035, aa);
		c = paint(c, BAR_GOLD, plate, aa);
		c = paint(c, BAR_INK, sd_bar_letters(p), aa);
	} else {
		float d = sd_bolt(p);
		c = paint(c, vec3(0.25, 0.02, 0.12), d - 0.04, aa);
		c = paint(c, BOLT_PINK, d, aa);
	}
	return c;
}

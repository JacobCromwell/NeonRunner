// The photo card the runner shows round in the Marketplace's intro (MarketplaceIntro; the owner's beats, October 16,
// 2026): a dog-eared card of worn paper, on its front a photo of the Corporate zone's boss, the Chairman (his face is
// the fight's own, chairman_face.gdshaderinc), and beside and under it handwriting scribbled too fast to read: the
// teaser of who the runner is looking for. Its back is plain worn paper. Drawn as distances, so it stays crisp in the
// close-up on every renderer; unshaded in the street's light like the doodads (scenery_light, scenery_tint). Ink and
// paper only: no hazard's colour, nothing glows.
// UV: (0, 0) the card's top left on its front; `aspect` its width over its height.
shader_type spatial;
render_mode unshaded, cull_disabled;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"
#include "res://scripts/bosses/hostile_takeover/chairman_face.gdshaderinc"

global uniform float scenery_light;
global uniform vec3 scenery_tint;

uniform float aspect = 1.45;
// The paper (sRGB), the ink of the scribbles, the photo's white border and the studio backdrop behind him.
uniform vec3 paper : source_color = vec3(0.86, 0.81, 0.69);
uniform vec3 ink : source_color = vec3(0.13, 0.13, 0.2);
uniform vec3 photo_border : source_color = vec3(0.93, 0.92, 0.88);
uniform vec3 backdrop : source_color = vec3(0.36, 0.42, 0.5);
// Seeds the scribbles (the same every frame).
uniform float scribble_seed = 3.0;

// Worn paper: a soft mottle, darker toward the edges, one crease across it.
vec3 paper_at(vec2 q) {
	vec3 col = to_linear(paper);
	float mottle = hash12(floor(q * 38.0)) * 0.5 + hash12(floor(q * 11.0) + 7.0) * 0.5;
	col *= 0.93 + 0.07 * mottle;
	vec2 e = min(q, vec2(aspect, 1.0) - q);
	col *= 0.78 + 0.22 * smoothstep(0.0, 0.07, min(e.x, e.y));
	float crease = abs(q.x * 0.22 + q.y - 0.62);
	col *= 1.0 - 0.1 * (1.0 - smoothstep(0.0, 0.01, crease));
	return col;
}

// One line of hasty handwriting along y = `base` from x0 to x1 (card units): words of loops and strokes with gaps
// between them, the pen wobbling. Returns the ink's coverage.
float scribble_line(vec2 q, float base, float x0, float x1, float seed) {
	if (q.x < x0 || q.x > x1 || abs(q.y - base) > 0.06) {
		return 0.0;
	}
	// Words: cells along the line, each word a share of its cell, the rest a gap.
	float cell = 0.13 + 0.05 * hash11(seed * 3.1);
	float w = floor((q.x - x0) / cell);
	float u = fract((q.x - x0) / cell);
	float word_len = 0.55 + 0.35 * hash12(vec2(w, seed));
	if (u > word_len) {
		return 0.0;
	}
	// The pen's path: loops (a fast sine), each stroke its own height (a tall one now and then: capitals, ascenders),
	// a second, faster wobble over them, riding a slow drift off the line. Each stroke starts and ends on the line, so
	// the heights change without a break.
	float f = 105.0 + 30.0 * hash12(vec2(w, seed + 1.0));
	float ph = q.x * f + seed * 5.0;
	float letter = floor(ph / PI);
	float h = hash12(vec2(letter, seed + 2.0));
	float amp = 0.006 + 0.012 * h + (h > 0.86 ? 0.014 : 0.0);
	float y = base + amp * sin(ph) + 0.004 * sin(ph * 2.7 + seed) + 0.006 * sin(q.x * 23.0 + seed);
	float slope = amp * f * cos(ph) + 0.004 * 2.7 * f * cos(ph * 2.7 + seed) + 0.006 * 23.0 * cos(q.x * 23.0 + seed);
	float d = abs(q.y - y) / sqrt(1.0 + slope * slope);
	float stroke = 0.0028;
	float aa = max(fwidth(d), 0.0008);
	return 1.0 - smoothstep(stroke - aa, stroke + aa, d);
}

void fragment() {
	// q: card units, x across (0 to aspect), y down (0 to 1).
	vec2 q = vec2(UV.x * aspect, UV.y);
	vec3 col = paper_at(q);
	if (FRONT_FACING) {
		// The photo, upper left: a white border, his face on a studio backdrop.
		vec2 ph_min = vec2(0.08, 0.1);
		vec2 ph_max = vec2(0.6, 0.78);
		float border = 0.025;
		vec2 c = (ph_min + ph_max) * 0.5;
		vec2 half_size = (ph_max - ph_min) * 0.5;
		float outer = sd_box(q - c, half_size);
		col = mix(col, to_linear(photo_border), fill(outer));
		float inner = sd_box(q - c, half_size - vec2(border));
		if (inner < 0.01) {
			// The picture: the photo's middle at the origin, y up, a unit the picture's height.
			float h = (half_size.y - border) * 2.0;
			vec2 p = vec2(q.x - c.x, c.y - q.y) / h;
			vec3 pic = to_linear(backdrop) * (0.8 + 0.3 * smoothstep(-0.5, 0.4, p.y));
			pic = chairman_face(p * 1.08 + vec2(0.0, 0.02), pic, vec3(0.9, 0.92, 0.95));
			// Printed on cheap paper: a little faded.
			pic = mix(pic, to_linear(paper), 0.12);
			col = mix(col, pic, fill(inner));
		}
		// The scribbles: beside the photo and under it, too fast to read.
		float cover = 0.0;
		for (int i = 0; i < 4; i++) {
			float fi = float(i);
			float right = aspect - 0.07 - 0.12 * hash11(scribble_seed + fi * 7.0);
			cover = max(cover, scribble_line(q, 0.17 + fi * 0.15, 0.68, right, scribble_seed + fi * 13.0));
		}
		for (int i = 0; i < 2; i++) {
			float fi = float(i);
			float right = aspect - 0.1 - 0.4 * hash11(scribble_seed + fi * 5.0 + 40.0);
			cover = max(cover, scribble_line(q, 0.86 + fi * 0.085, 0.09, right, scribble_seed + 50.0 + fi * 11.0));
		}
		// A hard underline under the first line (the one that matters).
		float under = sd_segment(q, vec2(0.69, 0.215), vec2(aspect - 0.2, 0.205)) - 0.003;
		cover = max(cover, fill(under));
		col = mix(col, to_linear(ink), cover * 0.92);
	}
	ALBEDO = col * light_factor(scenery_light) * scenery_tint;
}

// Solid low-poly kit surfaces (MeshLayer data). Unshaded with a cheap fake city light, so it costs
// the same on the Compatibility renderer (web, low-end Android) as on Forward+.
//   COLOR.rgb  albedo (sRGB)      COLOR.a  glow: 0 = lit surface, > 0 = emissive (x glow_scale)
//   UV2.x      pattern id (MeshKit.PAT_*), UV2.y pattern parameter
// Patterns use world position, so seams and stripes line up across meshes and chunk cuts.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"
#include "res://scripts/world/meshes/shaders/kit_flash.gdshaderinc"

uniform float glow_scale = 4.0;
// Sky glow caught at grazing angles: distant roofs and hulls pick up the neon haze.
uniform vec3 sheen_color : source_color = vec3(0.35, 0.25, 0.6);
uniform float sheen_strength = 0.35;
uniform vec3 stripe_dark : source_color = vec3(0.03, 0.03, 0.035);
uniform vec3 panel_dark : source_color = vec3(0.015, 0.015, 0.03);
// Hazard states (HazardStateVisual swaps materials): glow multiplier, and a flicker rate for WARNING.
uniform float state_glow = 1.0;
uniform float flicker_hz = 0.0;
// Worn street surfaces: lane paint, rust on salvaged plating, graffiti on billboards.
uniform vec3 marking_color : source_color = vec3(0.55, 0.55, 0.52);
uniform vec3 rust_color : source_color = vec3(0.3, 0.16, 0.08);
uniform vec3 graffiti_color : source_color = vec3(0.35, 0.5, 0.52);

varying vec3 v_world;

// Thin lines every `period` metres along `coord`, box-filtered so they fade to their average
// coverage instead of shimmering when they get dense on screen.
float grid_line(float coord, float period, float half_width) {
	float h = half_width / period;
	return filtered_pulse(coord / period + 0.5, fwidth(coord) / period, 0.5 - h, 0.5 + h);
}

// 0 below `edge`, 1 above it, blended over one pixel's footprint `fw` of y.
float above(float y, float edge, float fw) {
	return clamp((y - edge) / max(fw, 1e-4) + 0.5, 0.0, 1.0);
}

// Two coordinates in the plane of the face, picked by its dominant axis.
vec2 face_coords(vec3 n) {
	return abs(n.y) > 0.5 ? v_world.xz : (abs(n.x) > 0.5 ? v_world.zy : v_world.xy);
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 nv = flat_view_normal(VERTEX);
	vec3 n = (INV_VIEW_MATRIX * vec4(nv, 0.0)).xyz;
	vec3 base = COLOR.rgb;
	float glow = COLOR.a;
	int pattern = int(UV2.x + 0.5);
	float glass = 0.0;

	if (pattern == 1) {
		// ROOF: transverse panel seams and slight plate tones.
		float z = v_world.z + UV2.y;
		base *= 1.0 - 0.4 * grid_line(z, 1.6, 0.025);
		base *= 1.0 - 0.12 * grid_line(z, 0.4, 0.06);
		base *= 0.93 + 0.14 * hash12(vec2(floor(z / 1.6), floor(v_world.x * 0.4)));
	} else if (pattern == 2) {
		// RIBS: vertical corrugation along the face.
		float c = abs(n.x) > 0.5 ? v_world.z : v_world.x;
		base *= 1.0 - 0.35 * grid_line(c, 0.32, 0.045);
	} else if (pattern == 3) {
		// STRIPES: hazard diagonals, the colour glowing between dark bands.
		vec2 p = face_coords(n);
		float s = (p.x + p.y) * 2.2;
		float on = filtered_pulse(s, fwidth(s), 0.0, 0.5);
		base = mix(stripe_dark, base, on);
		glow *= on;
	} else if (pattern == 4) {
		// GLASS: dark, catching soft diagonal reflections of the sky.
		glass = 0.55 + 0.45 * sin((v_world.x * 0.9 + v_world.y * 1.7 + v_world.z * 0.4) * 2.3);
	} else if (pattern == 5) {
		// HULL: plating with panel lines and tone variation.
		vec2 p = face_coords(n);
		float lines = max(grid_line(p.y, 3.2, 0.03), 0.6 * grid_line(p.x + 0.6, 2.4, 0.025));
		base *= (0.88 + 0.24 * hash12(floor(vec2(p.x / 2.4, p.y / 3.2)))) * (1.0 - 0.45 * lines);
	} else if (pattern == 6) {
		// CHECKER: light squares glow.
		vec2 p = face_coords(n) / 0.6;
		vec2 fw = fwidth(p);
		float a = filtered_pulse(p.x, fw.x, 0.0, 0.5);
		float b = filtered_pulse(p.y, fw.y, 0.0, 0.5);
		float on = a * b + (1.0 - a) * (1.0 - b);
		base = mix(stripe_dark, base, on);
		glow *= on;
	} else if (pattern == 7) {
		// GRILLE: horizontal slats.
		base *= 1.0 - 0.6 * grid_line(v_world.y, 0.09, 0.02);
	} else if (pattern == 8) {
		// GLYPHS: rows of neon glyphs on a dark panel; UV in metres, UV2.y scrolls (m/s).
		vec2 uv = vec2(UV.x + TIME * UV2.y + NODE_POSITION_WORLD.z * 0.37, UV.y);
		vec2 cs = vec2(0.55, 0.8);
		vec2 cell = floor(uv / cs);
		vec2 g = (fract(uv / cs) - vec2(0.14, 0.12)) / vec2(0.72, 0.76);
		float inside = step(0.0, g.x) * step(g.x, 1.0) * step(0.0, g.y) * step(g.y, 1.0);
		vec2 gs = clamp(g, 0.0, 0.999) * vec2(2.0, 3.0);
		vec2 sub = floor(gs);
		vec2 sf = fract(gs);
		float r = hash12(cell * 7.13 + sub * 1.37);
		float stroke = r < 0.4 ? step(abs(sf.y - 0.5), 0.17) : (r < 0.75 ? step(abs(sf.x - 0.5), 0.22) : 0.0);
		float on = inside * stroke * step(0.18, hash12(cell.yx * 3.7 + 1.3));
		float fw = max(fwidth(uv.x), fwidth(uv.y));
		on = mix(on, 0.25, clamp((fw - 0.05) * 10.0, 0.0, 1.0));
		base = mix(panel_dark, base, on);
		glow *= on;
	} else if (pattern == 9) {
		// CHEVRONS: arrows along UV.x (0-1 over the face) pointing to UV2.y = +1 or -1, scrolling.
		float a = (UV.x * UV2.y - abs(UV.y - 0.5) * 0.9) * 3.0 - TIME * 1.6;
		float on = filtered_pulse(a, fwidth(a), 0.0, 0.34);
		base = mix(stripe_dark, base, on);
		glow *= on;
	} else if (pattern == 10) {
		// ASPHALT: a worn street of repair patches and cracks with scattered scraps. UV.x runs from -1
		// to 1 across the lane; UV2.y flags worn dashed lane lines on its left (1) and right (2) edge.
		vec2 p = v_world.xz;
		vec2 cp = p / vec2(1.7, 2.3);
		vec2 cfw = fwidth(cp);
		float detail = 1.0 - smoothstep(0.03, 0.2, max(fwidth(p.x), fwidth(p.y)));
		float row = floor(p.y / 4.3);
		float patch_tone = hash12(vec2(floor(p.x / 3.1 + hash11(row) * 0.7), row));
		base *= (0.88 + 0.2 * patch_tone) * (0.88 + 0.24 * value_noise(p * 0.3));
		if (detail > 0.0) {
			// Fine detail only where a pixel is small enough to show it: grain, block cracking in worn
			// stretches (kinked segments along a jittered grid) and scattered scraps.
			base *= 1.0 + 0.14 * detail * (value_noise(p * 5.0) - 0.5);
			float worn = smoothstep(0.45, 0.6, value_noise(p * 0.15 + 5.0));
			if (worn > 0.0) {
				vec2 k = floor(cp + 0.5);
				vec2 seg = floor(cp * 2.0);
				float cx = filtered_pulse(cp.x - 0.3 * (hash12(vec2(k.x, seg.y)) - 0.5) + 0.5, cfw.x, 0.492, 0.508)
					* step(0.5, hash12(vec2(k.x, seg.y) + 3.0));
				float cy = filtered_pulse(cp.y - 0.3 * (hash12(vec2(seg.x, k.y) + 7.0) - 0.5) + 0.5, cfw.y, 0.494, 0.506)
					* step(0.5, hash12(vec2(seg.x, k.y) + 5.0));
				base *= 1.0 - 0.45 * max(cx, cy) * detail * worn;
			}
			vec2 lc = floor(p / 0.9);
			vec2 lf = abs(fract(p / 0.9) - 0.5);
			float scrap = step(0.965, hash12(lc + 91.0)) * step(lf.x, 0.08 + 0.1 * hash12(lc + 7.0))
				* step(lf.y, 0.06 + 0.1 * hash12(lc + 13.0));
			base = mix(base, vec3(0.32, 0.31, 0.29), scrap * detail * 0.8);
		}
		int flags = int(UV2.y + 0.5);
		float lw = fwidth(UV.x);
		float dash = filtered_pulse(v_world.z / 9.0, fwidth(v_world.z) / 9.0, 0.0, 0.4);
		float on_edge = smoothstep(0.945 - lw, 0.945 + lw, abs(UV.x));
		float line = on_edge * dash * (UV.x < 0.0 ? float(flags & 1) : float((flags >> 1) & 1));
		if (line > 0.0) {
			float paint = 0.45 + 0.55 * smoothstep(0.25, 0.6, value_noise(p * vec2(3.0, 0.6) + 3.0));
			base = mix(base, marking_color, line * paint);
		}
	} else if (pattern == 11) {
		// STRATA: the cut through a broken road (crater walls): asphalt, gravel, an old concrete slab,
		// then earth darkening into the depths. COLOR is the earth; the layers follow world height.
		float h = abs(n.x) > 0.5 ? v_world.z : v_world.x;
		float y = v_world.y + 0.035 * sin(h * 2.3) + 0.025 * sin(h * 6.1 + 1.3);
		float fy = fwidth(y);
		float detail = 1.0 - smoothstep(0.02, 0.12, max(fy, fwidth(h)));
		vec3 grey = vec3(dot(base, vec3(0.3, 0.5, 0.2)));
		float grit = 1.0 + 0.4 * detail * (hash12(floor(vec2(h, v_world.y) * 16.0)) - 0.5);
		vec3 strata = base * (0.8 + 0.4 * value_noise(vec2(h * 1.3, v_world.y * 2.5)));
		strata = mix(strata, grey * 1.3, above(y, -0.78, fy));
		strata = mix(strata, mix(base, grey, 0.5) * 1.15 * grit, above(y, -0.5, fy));
		strata = mix(strata, grey * 0.6, above(y, -0.14, fy));
		strata *= 1.0 + 0.35 * above(v_world.y, -0.035, fy);
		base = strata * exp(min(v_world.y + 0.5, 0.0) * 1.1);
	} else if (pattern == 12) {
		// RUST: salvaged plating: plates of mismatched paint, dark seams, rust blooms and streaks.
		// UV2.y > 0 adds corrugation with that period (m).
		vec2 p = face_coords(n);
		vec2 cs = vec2(2.3, 1.4);
		float row = floor(p.y / cs.y);
		float shift = hash11(row * 7.1 + 2.0) * cs.x;
		vec2 cell = vec2(floor((p.x + shift) / cs.x), row);
		float r1 = hash12(cell + 3.7);
		float r2 = hash12(cell * 1.3 + 11.0);
		vec3 paint = base * (0.78 + 0.4 * r1);
		paint = mix(paint, vec3(dot(paint, vec3(0.333))) * vec3(0.92, 1.0, 1.04), step(0.62, r2) * 0.7);
		float bloom = smoothstep(0.5, 0.8, value_noise(p * 1.2 + cell * 3.1) * (0.55 + 0.7 * r2));
		float streak = value_noise(vec2(p.x * 5.0, p.y * 0.35 + cell.x)) * (1.0 - fract(p.y / cs.y));
		paint = mix(paint, rust_color, max(bloom, smoothstep(0.55, 0.85, streak) * 0.6) * 0.8);
		if (UV2.y > 0.0) {
			// Corrugated sheets, tagged by the gangs.
			paint *= 1.0 - 0.3 * grid_line(p.x, UV2.y, UV2.y * 0.18);
			vec2 tag = graffiti(p, 7.0);
			paint = mix(paint, mix(graffiti_color, vec3(0.5, 0.49, 0.46), step(0.6, tag.y)), tag.x * 0.7);
		}
		base = paint * (1.0 - 0.55 * max(grid_line(p.y, cs.y, 0.02), grid_line(p.x + shift, cs.x, 0.02)));
	} else if (pattern == 13) {
		// POSTER: salvaged billboard content (UV in metres on the panel, UV2.y a whole-number seed):
		// faded posters over bare board, some torn away, a graffiti stroke, grime rising from below.
		float seed = floor(UV2.y + 0.5);
		vec2 q = (UV + vec2(seed * 3.7, 0.0)) / vec2(1.9, 1.25);
		vec2 cell = floor(q);
		vec2 f = fract(q);
		vec2 fw = fwidth(q);
		// Faded to near-greys: warmer or cooler, lighter or darker, never a hazard hue.
		float warmth = hash12(cell + 1.0) * 2.0 - 1.0;
		vec3 tint = vec3(1.0 + 0.12 * warmth, 1.0, 1.0 - 0.12 * warmth) * (0.75 + 0.45 * hash12(cell + 2.0));
		float block = filtered_pulse(f.x, fw.x, 0.14, 0.86) * filtered_pulse(f.y, fw.y, 0.48, 0.86)
			* step(0.4, hash12(cell + 9.0));
		float lines = filtered_pulse(f.x, fw.x, 0.12, 0.88) * filtered_pulse(f.y, fw.y, 0.1, 0.38)
			* filtered_pulse(f.y * 8.0, fw.y * 8.0, 0.0, 0.5);
		vec3 poster = mix(base, vec3(dot(base, vec3(0.333))), 0.35) * tint * (1.0 - 0.4 * max(block, lines));
		float t = 0.2 + 0.35 * step(0.7, hash12(cell + 4.0));
		float torn = 1.0 - smoothstep(t - 0.03, t + 0.03, value_noise(q * vec2(3.0, 2.0) + cell * 5.0));
		vec3 panel = mix(poster, base * 0.4, torn);
		vec2 tag = graffiti(UV * 1.3, seed);
		panel = mix(panel, mix(graffiti_color, vec3(0.08, 0.08, 0.08), step(0.5, tag.y)), tag.x * 0.85);
		base = panel * (0.6 + 0.4 * smoothstep(0.0, 1.0, UV.y)) * (0.8 + 0.3 * value_noise(vec2(UV.x * 3.0, UV.y * 0.3)));
	}

	vec3 col;
	if (glow > 0.002) {
		float g = glow * glow_scale * state_glow;
		if (flicker_hz > 0.0) {
			g *= warning_flicker(step(0.5, fract(TIME * flicker_hz)), 0.2);
		}
		col = to_linear(base) * g;
	} else {
		// Fake city light: tops catch the sky glow, sides the street, undersides the traffic below.
		float shade = 0.62 + 0.3 * max(n.y, 0.0) + 0.08 * abs(n.x) + 0.06 * n.z - 0.04 * max(-n.y, 0.0);
		float f = 1.0 - clamp(dot(nv, VIEW), 0.0, 1.0);
		vec3 sheen = to_linear(sheen_color) * (f * f * f * sheen_strength + glass * 0.15);
		col = to_linear(base) * shade + sheen;
	}
	ALBEDO = col;
}

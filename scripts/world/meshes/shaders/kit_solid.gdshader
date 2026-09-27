// Solid low-poly kit surfaces (MeshLayer data). Unshaded with a cheap fake city light, so it costs
// the same on the Compatibility renderer (web, low-end Android) as on Forward+.
//   COLOR.rgb  albedo (sRGB)      COLOR.a  glow: 0 = lit surface, > 0 = emissive (x glow_scale)
//   UV2.x      pattern id (MeshKit.PAT_*), UV2.y pattern parameter
// Patterns use world position, so seams and stripes line up across meshes and chunk cuts.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"
#include "res://scripts/world/meshes/shaders/kit_flash.gdshaderinc"
#include "res://scripts/world/meshes/shaders/kit_marks.gdshaderinc"
// Marketplace patterns (ids 20-29).
#include "res://scripts/world/meshes/shaders/kit_market.gdshaderinc"

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
// Lived-in zones (Gangland). The defaults leave every pattern as it was.
// graffiti_pieces > 0: tagged sheets, slabs and crates carry pieces and tags (graffiti_marks) in
// graffiti_color and these two colours, with this share of slots painted.
uniform float graffiti_pieces = 0.0;
uniform vec3 graffiti_color_b : source_color = vec3(0.35, 0.5, 0.52);
uniform vec3 graffiti_color_c : source_color = vec3(0.5, 0.49, 0.46);
// ASPHALT: wind-blown sand drifting over the street, and soot scorched around the holes.
uniform vec3 sand_color : source_color = vec3(0.42, 0.35, 0.26);
uniform float sand_amount = 0.0;
uniform float scorch_amount = 0.0;
// POSTER: the share of posters that are corporate ads (the logo and slogan bars on a brand-coloured panel).
uniform float poster_ads = 0.0;
uniform vec3 ad_color : source_color = vec3(0.55, 0.56, 0.6);
// The cult's emblem, hidden in plain sight (GDD §5): CultEmblem's rasterised mark of the chosen
// option in its unlit colours (sRGB, alpha = coverage), set by the skin. cult_emblem_share of the
// corporate ads carry it small in a corner; stencils carry it where their parameter says so.
uniform sampler2D cult_emblem : filter_linear_mipmap, repeat_disable;
uniform float cult_emblem_share = 0.0;

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

// One line of `half_width` either side of x = 0, anti-aliased over the footprint `fw`.
float thin_bar(float x, float half_width, float fw) {
	fw = max(fw, 1e-4);
	return 1.0 - smoothstep(half_width - fw, half_width + fw, abs(x));
}

// The cult emblem's paint (rgb, sRGB) and coverage (a) at p in emblem space (the mark's square spans
// -1..1, +y up); `fw` is a pixel's footprint there, taken outside branches. The mip level comes from
// it (no implicit derivatives, so this is safe inside any branch), and the mark fades out before it
// spans fewer than about 24 pixels, where its three-fold silhouette could read like a radiation
// trefoil.
vec4 cult_mark(vec2 p, float fw) {
	float size = float(textureSize(cult_emblem, 0).x);
	float lod = log2(max(fw * 0.5 * size, 1.0));
	vec4 t = textureLod(cult_emblem, vec2(p.x, -p.y) * 0.5 + 0.5, lod);
	float inside = step(abs(p.x), 1.0) * step(abs(p.y), 1.0);
	return vec4(t.rgb, t.a * inside * (1.0 - smoothstep(0.055, 0.085, fw)));
}

// The cult's emblem as a mark of its own (ids 60-69).
#include "res://scripts/world/meshes/shaders/kit_cult.gdshaderinc"

// Two coordinates in the plane of the face, picked by its dominant axis.
vec2 face_coords(vec3 n) {
	return abs(n.y) > 0.5 ? v_world.xz : (abs(n.x) > 0.5 ? v_world.zy : v_world.xy);
}

// Paints graffiti_marks over `col` (sRGB): fills in the graffiti colours or a pale cream, ringed by
// a dark outline. `aa` is a pixel's footprint in metres (max of fwidth(p)), taken outside branches.
vec3 paint_graffiti(vec3 col, vec2 p, float seed, float density, float aa) {
	vec4 g = graffiti_marks(p, seed, density, aa);
	vec3 fill = g.z < 0.3 ? graffiti_color : (g.z < 0.55 ? graffiti_color_b : (g.z < 0.8 ? graffiti_color_c
		: vec3(0.78, 0.75, 0.68)));
	col = mix(col, vec3(0.05, 0.045, 0.04), g.y * 0.9);
	return mix(col, fill, g.x * 0.85);
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

	if (pattern >= 20) {
		base = market_surface(pattern, UV2.y, base, v_world, n, UV, TIME, glow);
	} else if (pattern == 1) {
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
		// Higher bits (lived-in zones): a hole borders the piece's near end (4) or far end (8), and
		// bits 4 and up hold the piece's length in eighths of a metre (UV.y runs in metres from its
		// near end), for the scorch around the holes.
		int flags = int(UV2.y + 0.5);
		float lw = fwidth(UV.x);
		float dash = filtered_pulse(v_world.z / 9.0, fwidth(v_world.z) / 9.0, 0.0, 0.4);
		float on_edge = smoothstep(0.945 - lw, 0.945 + lw, abs(UV.x));
		float line = on_edge * dash * (UV.x < 0.0 ? float(flags & 1) : float((flags >> 1) & 1));
		if (line > 0.0) {
			float paint = 0.45 + 0.55 * smoothstep(0.25, 0.6, value_noise(p * vec2(3.0, 0.6) + 3.0));
			base = mix(base, marking_color, line * paint);
		}
		if (sand_amount > 0.0) {
			// Sand blown along the street in long drifts, burying the paint in places.
			float drift = smoothstep(0.48, 0.78, value_noise(p * vec2(0.42, 0.09) + 23.0));
			drift *= 0.55 + 0.45 * value_noise(p * vec2(2.1, 0.7) + 5.0);
			base = mix(base, sand_color * (0.9 + 0.2 * value_noise(p * 3.7)), drift * sand_amount);
		}
		if (scorch_amount > 0.0 && flags >= 4) {
			// Blast soot around the holes, ragged, darkest at the edge (the orange edge reads against it).
			float len = float(flags >> 4) * 0.125;
			float d = min((flags & 4) != 0 ? UV.y : 1e3, (flags & 8) != 0 ? len - UV.y : 1e3);
			float ragged = 0.55 + 0.45 * value_noise(p * 1.9 + 4.0);
			base *= 1.0 - 0.7 * scorch_amount * exp(-max(d, 0.0) / (1.1 * ragged + 0.2));
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
		vec2 fwp = fwidth(p);
		if (UV2.y > 0.0) {
			// Corrugated sheets, tagged by the gangs.
			paint *= 1.0 - 0.3 * grid_line(p.x, UV2.y, UV2.y * 0.18);
			if (graffiti_pieces > 0.0) {
				paint = paint_graffiti(paint, p, 7.0, graffiti_pieces, max(fwp.x, fwp.y));
			} else {
				vec2 tag = graffiti(p, 7.0);
				paint = mix(paint, mix(graffiti_color, vec3(0.5, 0.49, 0.46), step(0.6, tag.y)), tag.x * 0.7);
			}
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
		if (poster_ads > 0.0 && hash12(cell + 21.0) < poster_ads) {
			// A corporate ad pasted over the rest: the logo and slogan bars on a brand-coloured panel.
			vec2 m = f * vec2(1.9, 1.25);
			vec2 mfw = fw * vec2(1.9, 1.25);
			float logo = corp_logo((m - vec2(0.5, 0.62)) / 0.36, max(mfw.x, mfw.y) / 0.36);
			float bars = band(m.x, 0.98, 1.74, mfw.x) * max(band(m.y, 0.7, 0.86, mfw.y),
				band(m.y, 0.44, 0.52, mfw.y) * band(m.x, 0.9, 1.45, mfw.x));
			vec3 ad = mix(mix(ad_color, vec3(0.86, 0.85, 0.8), logo), ad_color * 0.3, bars);
			if (hash12(cell + 23.0) < cult_emblem_share) {
				// The sponsor's mark in the corner: the cult's emblem, hidden in plain sight.
				vec4 mark = cult_mark((m - vec2(1.58, 0.24)) / 0.19, max(mfw.x, mfw.y) / 0.19);
				ad = mix(ad, mark.rgb, mark.a * 0.9);
			}
			float inside = filtered_pulse(f.x, fw.x, 0.03, 0.97) * filtered_pulse(f.y, fw.y, 0.04, 0.96);
			poster = mix(poster * 0.6, ad * (0.85 + 0.15 * tint.g), inside);
		}
		float t = 0.2 + 0.35 * step(0.7, hash12(cell + 4.0));
		float torn = 1.0 - smoothstep(t - 0.03, t + 0.03, value_noise(q * vec2(3.0, 2.0) + cell * 5.0));
		vec3 panel = mix(poster, base * 0.4, torn);
		vec2 tag = graffiti(UV * 1.3, seed);
		panel = mix(panel, mix(graffiti_color, vec3(0.08, 0.08, 0.08), step(0.5, tag.y)), tag.x * 0.85);
		base = panel * (0.6 + 0.4 * smoothstep(0.0, 1.0, UV.y)) * (0.8 + 0.3 * value_noise(vec2(UV.x * 3.0, UV.y * 0.3)));
	} else if (pattern == 14) {
		// CONCRETE: cast concrete (decks, slabs, fascias): form-board lines (across slabs, so only
		// the lane seams run along a ceiling), expansion joints across slabs every 12 m, blotchy
		// stains, soft soot under slabs (never dark enough to read as a hole in a ceiling), water
		// streaks down upright faces; UV2.y > 0 paints graffiti over it (the share of slots painted).
		vec2 p = face_coords(n);
		vec2 fwp = fwidth(p);
		float upright = step(abs(n.y), 0.5);
		vec3 c = base * (0.86 + 0.24 * value_noise(p * 0.4));
		float board = mix(grid_line(v_world.z + 0.4, 2.4, 0.015), grid_line(v_world.y, 0.6, 0.012), upright);
		c *= 1.0 - 0.14 * board;
		c *= 1.0 - 0.45 * (1.0 - upright) * grid_line(v_world.z, 12.0, 0.03);
		float stain = smoothstep(0.55, 0.85, value_noise(p * 0.21 + 3.0));
		float streak = upright * smoothstep(0.6, 0.9, value_noise(vec2(p.x * 2.6, p.y * 0.22) + 9.0));
		c = mix(c, c * 0.5, max(stain * 0.6, streak * 0.55));
		// Under slabs: soot from old fires.
		float soot = step(n.y, -0.5) * smoothstep(0.5, 0.85, value_noise(p * 0.11 + 17.0));
		c = mix(c, c * 0.6, soot * 0.6);
		float density = floor(UV2.y * 20.0 + 0.5) * 0.05;
		if (density > 0.0) {
			c = paint_graffiti(c, p, 17.0, density, max(fwp.x, fwp.y));
		}
		base = c;
	} else if (pattern == 15) {
		// STENCIL: painted crates and container doors (UV in metres, centred on the face) with a
		// stencilled marking in pale paint on dark colours and dark paint on light ones. UV2.y =
		// kind + 4 * size + 16 * seed + 256 * emblem: kind 0 a military supply code, 1 the corporate
		// logo, 2 and 3 the same on corrugated container doors (a centre seam and locking bars); the
		// marking is 0.3 m tall per size step (size + 1). With the emblem flag the cult's mark sits
		// beside the code, in place of a crate's logo, or under a door's logo, small and unlit.
		vec2 fwuv = fwidth(UV);
		float fwm = max(fwuv.x, fwuv.y);
		vec2 fwp = fwidth(face_coords(n));
		int v = int(UV2.y + 0.5);
		int kind = v % 4;
		bool emblem = v >= 256;
		float seed = float((v / 16) % 16);
		float door = float(kind >= 2);
		float scale = 0.3 * float(1 + (v / 4) % 4);
		vec3 c = base * (0.88 + 0.2 * value_noise(UV * 1.3 + 2.0));
		float bars = max(thin_bar(UV.x, 0.025, fwm), max(thin_bar(abs(UV.x) - 0.36, 0.02, fwm),
			thin_bar(abs(UV.x) - 0.92, 0.02, fwm)));
		c *= 1.0 - door * max(0.3 * grid_line(UV.x, 0.3, 0.05), 0.55 * bars);
		vec3 paint = dot(base, vec3(0.3, 0.55, 0.15)) > 0.4 ? base * 0.2 : mix(base, vec3(0.8, 0.78, 0.7), 0.72);
		float logo_size = scale * 0.55;
		float wear = 0.55 + 0.45 * smoothstep(0.25, 0.6, value_noise(UV * 4.0 + 5.0));
		float mark = kind % 2 == 0 ? stencil_code(UV, scale, seed, fwm)
			: corp_logo((UV - vec2(0.0, door * 0.25)) / logo_size, fwm / logo_size);
		if (emblem && kind == 1) {
			mark = 0.0;
		}
		c = mix(c, paint, mark * wear * 0.9);
		if (emblem) {
			vec2 at = kind >= 2 ? vec2(0.0, -0.62) : vec2(0.0);
			float r = kind >= 2 ? 0.26 : scale * 0.64;
			if (kind == 0) {
				// Beside the code (stencil_code's width).
				float count = 3.0 + floor(hash11(seed * 3.7 + 0.5) * 3.0);
				r = scale * 0.42;
				at = vec2(count * scale * 0.42 * 0.72 * 0.5 + r + 0.04, 0.0);
			}
			vec4 cult = cult_mark((UV - at) / r, fwm / r);
			c = mix(c, cult.rgb, cult.a * wear * 0.9);
		}
		if (graffiti_pieces > 0.0 && kind >= 2) {
			c = paint_graffiti(c, face_coords(n), 29.0, graffiti_pieces * 0.6, max(fwp.x, fwp.y));
		}
		base = c;
	}
	if (pattern >= 60 && pattern < 70) {
		// The cult's emblem (kit_cult.gdshaderinc).
		base = cult_surface(pattern, base, UV, fwidth(UV), panel_dark, glow);
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

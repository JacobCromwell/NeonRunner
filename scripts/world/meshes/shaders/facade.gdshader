// Building facades with procedural window grids: no window geometry at all.
//   UV     metres along the facade, metres up (world height)
//   UV2    x = style (0 office glass, 1 punched windows, 2 ribbon windows, 3 tall slots), y = seed (whole number)
//   COLOR  rgb = wall colour (sRGB), a = share of lit windows
// Windows are box-filtered, so at a distance or at grazing angles they fade to the facade's
// average instead of shimmering into stripes.
// ruin = 1 turns the facade into a bombed-out building face (Gangland): stained concrete, shuttered
// or boarded storefronts, boarded or bricked-up windows in the wall-run band (the wall must look
// solid there), broken, lit and burning windows higher up, and blast holes above the play space.
// Lived in (graffiti_amount, curtain_share > 0): pieces and tags over the lower storeys, and
// curtains in lit windows. Burning windows flicker gently, steady with Reduced flashing.
shader_type spatial;
render_mode unshaded, cull_back;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"
#include "res://scripts/world/meshes/shaders/kit_flash.gdshaderinc"
#include "res://scripts/world/meshes/shaders/kit_marks.gdshaderinc"

uniform vec3 window_warm : source_color = vec3(1.0, 0.9, 0.76);
uniform vec3 window_cool : source_color = vec3(0.7, 0.84, 1.0);
uniform vec3 window_neon : source_color = vec3(0.62, 0.45, 1.0);
uniform vec3 glass_color : source_color = vec3(0.03, 0.035, 0.06);
uniform vec3 sheen_color : source_color = vec3(0.4, 0.28, 0.7);
uniform float window_glow = 0.9;
uniform float sheen_strength = 0.45;
// Height (metres) of the street far below; facades darken toward it.
uniform float street_y = -14.0;
// Bombed-out mode (0 = intact city, 1 = ruins) and its colours.
uniform float ruin = 0.0;
uniform float band_top = 7.0;
uniform vec3 board_color : source_color = vec3(0.26, 0.21, 0.16);
uniform vec3 shutter_color : source_color = vec3(0.3, 0.3, 0.3);
uniform vec3 soot_color : source_color = vec3(0.025, 0.022, 0.02);
uniform vec3 graffiti_color : source_color = vec3(0.35, 0.5, 0.52);
uniform vec3 fire_color : source_color = vec3(0.9, 0.42, 0.14);
// Lived in (ruin mode). graffiti_amount > 0 replaces the storefront tags with pieces and tags
// (graffiti_marks) over everything up to a storey above the band, this share of slots painted, in
// graffiti_color and the two colours below.
uniform float graffiti_amount = 0.0;
uniform vec3 graffiti_color_b : source_color = vec3(0.35, 0.5, 0.52);
uniform vec3 graffiti_color_c : source_color = vec3(0.5, 0.49, 0.46);
// The share of lit windows with curtains drawn half across, glowing with the lamp behind them.
uniform float curtain_share = 0.0;
uniform vec3 curtain_color : source_color = vec3(0.5, 0.42, 0.36);
uniform vec3 curtain_color_b : source_color = vec3(0.36, 0.4, 0.44);

// Planks nailed over an opening (fp: position in its cell, fw: the cell footprint of a pixel).
vec3 ruin_planks(vec2 cell, vec2 fp, vec2 fw, float seed) {
	float y = fp.y * 7.0;
	return to_linear(board_color) * (0.7 + 0.45 * hash12(vec2(cell.x * 3.1 + floor(y), cell.y + seed)))
		* (1.0 - 0.6 * filtered_pulse(y, fw.y * 7.0, 0.0, 0.14));
}

// Breeze blocks with staggered joints, so a bricked-up opening never reads as louvres (uv and the
// pixel footprint fw_m in metres).
vec3 ruin_blocks(vec3 wall_color, vec2 uv, vec2 fw_m, float seed) {
	vec2 bq = uv / vec2(0.4, 0.2);
	float shift = 0.5 * mod(floor(bq.y), 2.0);
	vec2 bfw = fw_m / vec2(0.4, 0.2);
	float joints = max(filtered_pulse(bq.y, bfw.y, 0.0, 0.1), filtered_pulse(bq.x + shift, bfw.x, 0.0, 0.06));
	return wall_color * (0.75 + 0.2 * hash12(floor(vec2(bq.x + shift, bq.y)) + seed)) * (1.0 - 0.35 * joints);
}

void fragment() {
	int style = int(UV2.x + 0.5);
	// Interpolated attributes aren't bit-exact across a triangle, and hashes amplify any difference:
	// seeds are whole numbers, rounded here before hashing.
	float seed = floor(UV2.y + 0.5);
	vec2 cs;
	vec4 win;
	if (style == 0) {
		cs = vec2(1.3, 3.3);
		win = vec4(0.07, 0.3, 0.93, 0.9);
	} else if (style == 1) {
		cs = vec2(2.2, 3.0);
		win = vec4(0.22, 0.3, 0.78, 0.8);
	} else if (style == 2) {
		cs = vec2(4.0, 3.3);
		win = vec4(0.03, 0.42, 0.97, 0.82);
	} else {
		cs = vec2(1.6, 3.3);
		win = vec4(0.25, 0.1, 0.75, 0.92);
	}
	vec2 p = UV / cs;
	vec2 cell = floor(p);
	vec2 fp = fract(p);
	vec2 fw = fwidth(p);
	float in_win = filtered_pulse(p.x, fw.x, win.x, win.z) * filtered_pulse(p.y, fw.y, win.y, win.w);
	float slab = filtered_pulse(p.y, fw.y, 0.0, 0.035);
	vec3 nv = flat_view_normal(VERTEX);
	vec3 n = (INV_VIEW_MATRIX * vec4(nv, 0.0)).xyz;

	if (ruin > 0.5) {
		vec3 wall = to_linear(COLOR.rgb) * (0.75 + 0.2 * max(n.z, 0.0));
		wall *= 0.8 + 0.32 * value_noise(vec2(UV.x * 1.3, UV.y * 0.07 + seed));
		wall *= 1.0 - 0.45 * smoothstep(0.5, 0.85, value_noise(UV * 0.09 + seed * 1.7));
		wall *= 0.55 + 0.45 * smoothstep(-0.5, 2.2, UV.y);
		wall = mix(wall, wall * 1.35, slab);
		vec3 soot = to_linear(soot_color);
		float k = hash12(cell * vec2(1.7, 2.3) + seed * 5.0);
		float cy = (cell.y + 0.5) * cs.y;
		vec3 fill = wall;
		float opening = in_win;
		if (cell.y < -0.5) {
			// Basement, seen down in craters: bare wall.
			opening = 0.0;
		} else if (cell.y < 0.5) {
			// Storefronts two windows wide: a shutter, boards or bricks between piers, a dead sign above.
			float sx = p.x * 0.5;
			float sfw = fw.x * 0.5;
			float sk = hash12(vec2(floor(sx), seed) + 17.0);
			opening = filtered_pulse(sx, sfw, 0.06, 0.94) * filtered_pulse(fp.y, fw.y, 0.15, 0.8);
			wall = mix(wall, soot * 2.5, filtered_pulse(sx, sfw, 0.04, 0.96) * filtered_pulse(fp.y, fw.y, 0.84, 0.96));
			vec3 shutter = to_linear(shutter_color) * (0.8 + 0.3 * sk)
				* (1.0 - 0.35 * filtered_pulse(UV.y / 0.12, fw.y * cs.y / 0.12, 0.0, 0.3));
			fill = sk < 0.55 ? shutter : (sk < 0.85 ? ruin_planks(cell, fp, fw, seed)
				: ruin_blocks(to_linear(COLOR.rgb), UV, fw * cs, seed));
			if (graffiti_amount <= 0.0) {
				vec2 tag = graffiti(UV, seed);
				vec3 paint = mix(to_linear(graffiti_color), to_linear(vec3(0.5, 0.49, 0.46)), step(0.6, tag.y));
				fill = mix(fill, paint, tag.x * 0.7);
			}
		} else if (cy < band_top) {
			fill = k < 0.65 ? ruin_planks(cell, fp, fw, seed) : ruin_blocks(to_linear(COLOR.rgb), UV, fw * cs, seed);
		} else {
			vec3 dark = soot * (0.5 + 0.7 * fp.y);
			float lamp = step(hash12(cell * 3.3 + seed), COLOR.a);
			vec3 lamp_col = to_linear(window_warm) * (window_glow * 0.45 * (0.5 + 0.5 * fp.y));
			float flick = 0.65 + 0.35 * sin(TIME * 9.0 + cell.x * 3.0) * sin(TIME * 5.3 + cell.y * 1.7);
			flick = mix(flick, 0.8, reduced_flashing);
			vec3 fire = to_linear(fire_color) * (flick * (1.3 - fp.y));
			fill = k < 0.6 ? dark : (k < 0.75 ? ruin_planks(cell, fp, fw, seed) : mix(dark * 1.5, lamp_col, lamp));
			if (k >= 0.75 && hash12(cell * 5.1 + seed + 3.0) < curtain_share) {
				// Curtains drawn half across, glowing faintly with the lamp behind them.
				float wx = (fp.x - win.x) / (win.z - win.x);
				float open_w = 0.1 + 0.28 * hash12(cell * 2.3 + seed);
				float panel = 1.0 - filtered_pulse(wx, fw.x / (win.z - win.x), 0.5 - open_w, 0.5 + open_w);
				vec3 cloth = to_linear(hash12(cell * 1.9 + seed) < 0.5 ? curtain_color : curtain_color_b);
				cloth *= (lamp > 0.5 ? window_glow * 0.55 : 0.3) * (0.82 + 0.18 * sin(wx * 26.0));
				fill = mix(fill, cloth, panel);
			}
			fill = mix(fill, fire, step(0.975, k) * step(12.0, cy));
			// Soot rising from burnt-out windows.
			float plume = step(k, 0.3) * step(win.w, fp.y) * (1.0 - smoothstep(win.w, 1.0, fp.y))
				* filtered_pulse(fp.x, fw.x, win.x, win.z);
			wall = mix(wall, soot, plume * 0.8);
		}
		vec3 col = mix(wall, fill, opening);
		if (graffiti_amount > 0.0) {
			// Pieces and tags over the lower storeys: walls, shutters, boards and bricks alike.
			vec4 g = graffiti_marks(UV, seed, graffiti_amount, max(fw.x * cs.x, fw.y * cs.y));
			float reach = 1.0 - smoothstep(band_top + 0.5, band_top + 1.5, UV.y);
			vec3 gc = g.z < 0.3 ? graffiti_color : (g.z < 0.55 ? graffiti_color_b : (g.z < 0.8 ? graffiti_color_c
				: vec3(0.78, 0.75, 0.68)));
			float lit_paint = (0.75 + 0.2 * max(n.z, 0.0)) * (0.55 + 0.45 * smoothstep(-0.5, 2.2, UV.y));
			col = mix(col, to_linear(vec3(0.05, 0.045, 0.04)), g.y * 0.9 * reach);
			col = mix(col, to_linear(gc) * lit_paint, g.x * 0.85 * reach);
		}
		if (UV.y > band_top + 1.0) {
			// Blown-out panels above the play space: ragged clusters of cells open onto gutted floors.
			vec2 jag = (vec2(value_noise(UV * 1.9 + seed), value_noise(UV * 1.9 + seed + 7.1)) - 0.5) * 0.3;
			vec2 bc = floor(p + jag);
			float blown = step(value_noise(bc * vec2(0.45, 0.6) + seed * 1.3), 0.25) * step(band_top + 1.5, bc.y * cs.y);
			col = mix(col, soot * (0.4 + 2.0 * filtered_pulse(p.y, fw.y, 0.0, 0.06)), blown);
		}
		// Far away, the openings blur into the facade's average.
		col = mix(col, mix(wall, soot * 1.5, 0.3), smoothstep(0.1, 0.4, max(fw.x, fw.y)));
		ALBEDO = col;
	} else {
		// Offices light up in blocks of four per floor; homes one window at a time.
		float bx = style == 0 ? floor(cell.x / 4.0) : cell.x;
		// Fewer lit windows on the floors beside the track, so the wall-run band stays calm.
		float share = COLOR.a * mix(0.45, 1.0, smoothstep(0.0, 14.0, UV.y));
		float lit = step(hash12(vec2(bx, cell.y) + seed * 17.0), share);
		float pick = hash12(vec2(bx * 1.31 + 7.0, cell.y * 0.73) + seed);
		float warm_share = 0.2 + 0.5 * fract(seed * 0.618);
		vec3 wc = pick < warm_share ? window_warm : (pick < 0.93 ? window_cool : window_neon);
		float bright = 0.35 + 0.65 * hash12(vec2(cell.x * 1.7, cell.y * 3.1) + seed);
		// Interiors lit from the ceiling (brighter toward the top of the window); some behind blinds.
		float grad = 0.45 + 0.55 * smoothstep(win.y, win.w, fp.y);
		float blinds = step(0.8, hash12(vec2(cell.x * 2.9, cell.y * 1.3) + seed));
		float slats = filtered_pulse(p.y * 16.0, fw.y * 16.0, 0.0, 0.6);
		grad *= mix(1.0, 0.7 + 0.3 * slats, blinds);
		vec3 lit_col = to_linear(wc) * (window_glow * bright * grad);

		float street = smoothstep(street_y, street_y + 30.0, UV.y);
		vec3 wall = to_linear(COLOR.rgb) * (0.75 + 0.2 * max(n.z, 0.0)) * (0.5 + 0.5 * street);
		wall = mix(wall, wall * 1.6 + to_linear(sheen_color) * 0.05, slab);
		float fres = 1.0 - clamp(dot(nv, VIEW), 0.0, 1.0);
		float fres2 = fres * fres;
		vec3 glass = to_linear(glass_color) + to_linear(sheen_color) * (sheen_strength * (0.25 + 0.75 * fres2));
		// At grazing angles glass mirrors the sky and hides the rooms behind it.
		float seen = 1.0 - 0.7 * fres2 * fres2;
		vec3 win_col = mix(glass, lit_col, lit * seen);

		// Where single windows blur together, use the facade's average window instead.
		vec3 avg_win = mix(glass, to_linear(mix(window_warm, window_cool, 0.6)) * (window_glow * 0.55), share * seen);
		win_col = mix(win_col, avg_win, smoothstep(0.1, 0.4, max(fw.x, fw.y)));
		ALBEDO = mix(wall, win_col, in_win);
	}
}

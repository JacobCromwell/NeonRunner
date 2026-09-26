// Building facades with procedural window grids: no window geometry at all.
//   UV     metres along the facade, metres up (world height)
//   UV2    x = style (0 office glass, 1 punched windows, 2 ribbon windows, 3 tall slots), y = seed (whole number)
//   COLOR  rgb = wall colour (sRGB), a = share of lit windows
// Windows are box-filtered, so at a distance or at grazing angles they fade to the facade's
// average instead of shimmering into stripes.
shader_type spatial;
render_mode unshaded, cull_back;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"

uniform vec3 window_warm : source_color = vec3(1.0, 0.9, 0.76);
uniform vec3 window_cool : source_color = vec3(0.7, 0.84, 1.0);
uniform vec3 window_neon : source_color = vec3(0.62, 0.45, 1.0);
uniform vec3 glass_color : source_color = vec3(0.03, 0.035, 0.06);
uniform vec3 sheen_color : source_color = vec3(0.4, 0.28, 0.7);
uniform float window_glow = 0.9;
uniform float sheen_strength = 0.45;
// Height (metres) of the street far below; facades darken toward it.
uniform float street_y = -14.0;

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

	vec3 nv = flat_view_normal(VERTEX);
	vec3 n = (INV_VIEW_MATRIX * vec4(nv, 0.0)).xyz;
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
	win_col = mix(win_col, avg_win, smoothstep(0.15, 0.6, max(fw.x, fw.y)));
	ALBEDO = mix(wall, win_col, in_win);
}

// The Casino's building faces (CasinoSkin, CasinoFacades; task K1; GDD §5, Zone 4, and the owner's
// reference image): a covered casino street at night. Facades of dark riveted iron with aged brass
// trims, tall arched windows in brass frames (lit warm, dark, frosted amber or shuttered), brass
// storey bands, lit marquees of bulbs on the casinos, and low on the wall a row of shop windows whose
// displays are warm lounges (where the Marketplace citizens play, task D3). Grimy and lived-in.
// It keeps shopfront.gdshader's style numbers, so the Marketplace's window templates, piers and faces
// (MarketFacades) work on it unchanged.
//   UV     x metres along the face (from the building's window grid origin), y world height (metres)
//   UV2    x = style (below), y = seed (whole number)
//   COLOR  rgb = wall colour (sRGB), a = share of lit windows
// Styles:
//   0 UPPER     storeys over the shops: iron plates, brass bands, tall arched windows. Windows in the
//               wall-run band (below calm_top) keep their shutters down, so the band stays calm.
//   1 CASINO    a grand front: panels of dark glass framed in brass and rows of bulbs, only above
//               decor_top; plain dark panels below.
//   2 HALL      an arcade hall: smooth plated panels through the wall-run band, tall arched glazing above.
//   3 LOWER     the plinth under the shop windows: iron skirting panels under a brass cap.
//   4 PIER      iron piers between the shop windows (UV.x from the pier's start, its width / 8 m in
//               COLOR.a), with brass jambs along both edges.
//   5 INTERIOR  a shop window's display: a warm lounge with rows of slot machines and sconces, seen
//               through the glass (UV.x from the window's start). Lit, never glowing.
//   6 REVEAL    the display's sides, floor and top.
// Colours are sRGB Vector3s (CasinoSkin.srgb()), converted once here, so both renderers draw them
// alike. Windows and bulbs are box-filtered, so far away they fade to the face's average.
shader_type spatial;
render_mode unshaded, cull_back;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"
#include "res://scripts/world/meshes/shaders/kit_flash.gdshaderinc"
#include "res://scripts/world/meshes/shaders/kit_marks.gdshaderinc"

// A level's darker lighting (ZoneSkin.apply_darkness): the scenery dims with it.
global uniform float scenery_light;

// Aged brass: the trims, bands and frames.
uniform vec3 trim_color = vec3(0.5, 0.39, 0.22);
uniform vec3 metal_color = vec3(0.56, 0.43, 0.24);
uniform vec3 shutter_a = vec3(0.2, 0.17, 0.14);
uniform vec3 shutter_b = vec3(0.17, 0.2, 0.22);
uniform vec3 shutter_c = vec3(0.26, 0.19, 0.14);
uniform vec3 shutter_d = vec3(0.22, 0.22, 0.2);
uniform vec3 window_warm = vec3(1.0, 0.8, 0.52);
uniform float window_glow = 0.62;
uniform vec3 glass_color = vec3(0.05, 0.06, 0.09);
// Frosted glass: milky amber, lit a little from inside.
uniform vec3 frost_color = vec3(0.5, 0.42, 0.3);
uniform vec3 sheen_color = vec3(0.56, 0.38, 0.22);
uniform float sheen_strength = 0.12;
uniform vec3 plinth_color = vec3(0.17, 0.15, 0.14);
uniform float plinth_top = 0.85;
uniform float storey_base = 3.0;
uniform float storey = 3.2;
// Below this height windows keep their shutters down (the wall-run band); decorative lights start at
// decor_top.
uniform float calm_top = 7.0;
uniform float decor_top = 8.0;
uniform vec3 bulb_color = vec3(1.0, 0.88, 0.7);
// The lounges' lit machine screens: violet and blue, never a hazard hue.
uniform vec3 neon_a = vec3(0.62, 0.46, 1.0);
uniform vec3 neon_b = vec3(0.36, 0.55, 1.0);
// Grime (the Casino is lived-in and a little seedy).
uniform vec3 grime_color = vec3(0.07, 0.06, 0.05);
uniform float grime = 1.0;

float cell_width(float seed) {
	int k = int(mod(seed, 4.0));
	return k == 0 ? 2.6 : (k == 1 ? 3.0 : (k == 2 ? 2.2 : 3.4));
}

vec3 shutter_color(float r) {
	return r < 0.25 ? shutter_a : (r < 0.5 ? shutter_b : (r < 0.75 ? shutter_c : shutter_d));
}

// Grime on a face at height y above its foot `foot`: darker toward the foot, in ragged tide marks,
// and broad weathering blotches all over.
vec3 weather(vec3 col, vec2 uv, float foot, float seed) {
	float rise = 1.0 - smoothstep(0.0, 0.55 + 0.35 * value_noise(vec2(uv.x * 1.3, seed)), uv.y - foot);
	col = mix(col, to_linear(grime_color), rise * 0.4 * grime);
	float blotch = smoothstep(0.5, 0.85, value_noise(uv * vec2(0.3, 0.2) + seed * 0.37));
	return col * (1.0 - 0.18 * blotch * grime) * (0.96 + 0.06 * value_noise(uv * 1.7 + seed));
}

// Dirty streaks running down from something's lower edge at `edge_y`, over `width` metres centred on
// `cx` (uv in metres): how dirty, 0-1.
float streaks(vec2 uv, float cx, float width, float edge_y, float seed) {
	float x = uv.x - cx;
	float across = 1.0 - smoothstep(width * 0.35, width * 0.5, abs(x));
	float below = edge_y - uv.y;
	float run = step(0.0, below) * (1.0 - smoothstep(0.1, 0.8 + 0.6 * hash11(seed + floor(x * 4.0)), below));
	return across * run * (0.45 + 0.55 * value_noise(vec2(x * 7.0, seed)));
}

// The plinth under the shop windows: riveted iron skirting panels under a brass cap, grime rising
// from the foot.
vec3 plinth(vec2 uv, vec2 fw_m, float seed) {
	vec3 panel = to_linear(plinth_color);
	float k = floor(uv.x / 1.2);
	panel *= 0.9 + 0.2 * hash12(vec2(k, seed));
	float joint = filtered_pulse(uv.x / 1.2, fw_m.x / 1.2, 0.0, 0.012);
	panel *= 1.0 - 0.45 * joint;
	float rivet = filtered_pulse(uv.x / 0.3, fw_m.x / 0.3, 0.4, 0.6) * band(uv.y, plinth_top - 0.3, plinth_top - 0.26, fw_m.y);
	panel = mix(panel, panel * 2.2, rivet * (1.0 - smoothstep(0.03, 0.12, fw_m.x)));
	float cap = band(uv.y, plinth_top - 0.07, plinth_top + 1.0, fw_m.y);
	vec3 col = mix(panel, to_linear(metal_color) * 0.7, cap);
	// A brass kick plate along the foot.
	col = mix(col, to_linear(trim_color) * 0.6, band(uv.y, -1.0, 0.1, fw_m.y));
	return weather(col, uv, 0.0, seed);
}

// A brass pipe painted on the face (the reference's pipes run along every facade): its centre at `c` and
// radius `r` (metres) on the axis `a`, a pixel's footprint `fw`. Above the wall-run band (calm_top) it is
// shaded to look round: lit from above, a pale line down its upper side. One that touches the band is
// plain flat paint, a stripe with no shading, so nothing there reads as standing out of the wall.
// `lowest` is the height of the pipe's lowest point. Returns the brass (linear) in rgb and the coverage in a.
vec4 painted_pipe(float a, float c, float r, float fw, float lowest) {
	float d = (a - c) / r;
	float cover = band(d, -1.0, 1.0, fw / r);
	float round_shade = sqrt(max(1.0 - d * d, 0.0));
	float lit = 0.2 + 0.8 * clamp(round_shade * (0.75 + 0.45 * d), 0.0, 1.0);
	float spec = pow(max(1.0 - abs(d - 0.45) * 3.0, 0.0), 2.0) * 0.45;
	vec3 shaded = to_linear(metal_color) * lit * 1.15 + to_linear(trim_color) * spec;
	vec3 flat_paint = to_linear(trim_color) * 0.62;
	return vec4(mix(flat_paint, shaded, step(calm_top, lowest)), cover);
}

void fragment() {
	int style = int(UV2.x + 0.5);
	float seed = floor(UV2.y + 0.5);
	vec3 nv = flat_view_normal(VERTEX);
	vec3 n = (INV_VIEW_MATRIX * vec4(nv, 0.0)).xyz;
	vec2 uv = UV;
	// Pixel footprints are taken here, before any branch, and passed down (docs/ARCHITECTURE.md, Zone
	// skins: the kit's shader rules); never zero, so every smoothstep keeps two distinct edges.
	vec2 fw_m = max(fwidth(uv), vec2(1e-4));
	float aa = max(fw_m.x, fw_m.y);
	float fres = 1.0 - clamp(dot(nv, VIEW), 0.0, 1.0);
	vec3 albedo = to_linear(COLOR.rgb);
	// Faces toward the lanes take the shade of the street; faces toward the player a little more light.
	float shade = 0.78 + 0.16 * max(n.z, 0.0) + 0.06 * max(n.y, 0.0);
	vec3 wall = albedo * (0.95 + 0.08 * value_noise(uv * vec2(0.7, 0.45) + seed));
	vec3 col = wall;
	vec3 brass = to_linear(metal_color);
	vec3 trim = to_linear(trim_color);
	vec3 sky = to_linear(sheen_color) * sheen_strength * (0.4 + 0.6 * fres * fres);

	if (style == 0 || style == 1) {
		float cw = style == 1 ? 3.0 : cell_width(seed);
		// A casino front's grid of glass and bulbs starts at decor_top (decorative lights are never
		// lower), each storey whole; below it the front is plain dark panels on the storeys of every face.
		bool grid = style == 1 && uv.y >= decor_top;
		float grid_base = grid ? decor_top : storey_base;
		vec2 p = vec2(uv.x / cw, (uv.y - grid_base) / storey);
		vec2 cell = floor(p);
		vec2 fp = fract(p);
		vec2 fw = fw_m / vec2(cw, storey);
		float k = hash12(cell * vec2(1.7, 2.3) + seed * 5.0);
		float cy = cell.y * storey + grid_base;
		// Iron plates half a cell wide and half a storey high, dark seams, each a slightly different
		// tone; a brass band along every storey's floor, shadowed below it, and a slim brass-edged
		// pilaster between the cells.
		vec2 pan = p * 2.0;
		float jx = filtered_pulse(pan.x, fw.x * 2.0, 0.0, 0.03 / cw);
		float jy = filtered_pulse(pan.y, fw.y * 2.0, 0.0, 0.03 / storey);
		col *= (0.9 + 0.16 * hash12(floor(pan) + seed * 3.1)) * (1.0 - 0.4 * max(jx, jy));
		float pil = filtered_pulse(p.x, fw.x, 0.0, 0.1 / cw);
		col = mix(col, wall * 1.5, pil * 0.5);
		float slab = filtered_pulse(p.y, fw.y, 0.0, 0.18 / storey);
		col = mix(col, trim * (0.7 + 0.3 * fres), slab);
		col *= 1.0 - 0.35 * filtered_pulse(p.y, fw.y, 1.0 - 0.08 / storey, 1.0);
		// Painted pipes: one along the top of each storey, just under the brass band, on most
		// buildings, and a riser up some of the cell boundaries.
		if (style == 0) {
			float pipe_here = step(hash12(vec2(cell.y, seed * 1.3)), 0.7);
			float pipe_y = cy + storey - 0.45 - 0.08 * hash11(seed * 3.7);
			float pipe_r = 0.2 + 0.08 * hash11(seed * 5.1);
			vec4 pipe = painted_pipe(uv.y, pipe_y, pipe_r, fw_m.y, pipe_y - pipe_r);
			col = mix(col, pipe.rgb, pipe.a * pipe_here);
			// The risers start above the wall-run band, out of a flange.
			float bx = (fract(p.x + 0.5) - 0.5) * cw;
			float riser_here = step(0.78, hash12(vec2(floor(p.x + 0.5), seed)));
			vec4 riser = painted_pipe(bx, 0.0, 0.17, fw_m.x, calm_top + 0.3);
			col = mix(col, riser.rgb, riser.a * riser_here * step(calm_top + 0.3, uv.y));
			float flange = band(bx, -0.26, 0.26, fw_m.x) * band(uv.y, calm_top + 0.3, calm_top + 0.46, fw_m.y);
			col = mix(col, to_linear(trim_color) * 0.75, flange * riser_here);
		}
		if (grid) {
			// Casino: dark glass panels in brass frames, framed by rows of bulbs.
			float panel = filtered_pulse(p.x, fw.x, 0.06, 0.94) * filtered_pulse(p.y, fw.y, 0.08, 0.92);
			vec3 glass = mix(to_linear(glass_color), to_linear(neon_a) * 0.2, fp.y * 0.6)
				+ to_linear(sheen_color) * sheen_strength * (0.3 + 0.7 * fres * fres);
			col = mix(col * 0.55, glass, panel);
			col = mix(col, brass * 0.8, (1.0 - panel) * (filtered_pulse(p.x, fw.x, 0.0, 0.08) + filtered_pulse(p.x, fw.x, 0.92, 1.0)) * 0.5);
			vec2 m = vec2((fp.x - 0.03) * cw, (fp.y - 0.04) * storey);
			vec2 m2 = vec2((0.97 - fp.x) * cw, (0.96 - fp.y) * storey);
			float along_y = (fract(uv.y / 0.3) - 0.5) * 0.3;
			float along_x = (fract(uv.x / 0.3) - 0.5) * 0.3;
			float d = min(min(length(vec2(m.x, along_y)), length(vec2(m2.x, along_y))),
				min(length(vec2(along_x, m.y)), length(vec2(along_x, m2.y))));
			float bulb = 1.0 - smoothstep(0.045, 0.075, d);
			bulb = mix(bulb, 0.22, smoothstep(0.02, 0.08, aa));
			float chase = mix(0.7 + 0.3 * sin(uv.x * 1.3 + uv.y * 0.7 - TIME * 1.6), 0.9, reduced_flashing);
			col = mix(col, vec3(0.0), bulb * 0.3) + to_linear(bulb_color) * (bulb * 1.9 * chase);
		} else if (style == 1) {
			// Casino, low storeys: plain dark panels (the wall-run band stays calm), a painted pipe along
			// the top of each.
			col *= 0.85;
			float pipe_y1 = cy + storey - 0.45;
			vec4 pipe1 = painted_pipe(uv.y, pipe_y1, 0.2, fw_m.y, pipe_y1 - 0.2);
			col = mix(col, pipe1.rgb, pipe1.a * step(hash12(vec2(cell.y, seed * 1.3)), 0.75));
		} else {
			// Upper floors: tall arched windows in brass frames.
			vec2 wc = vec2((fp.x - 0.5) * cw, (fp.y - 0.12) * storey);
			float hw = min(0.62, cw * 0.27);
			float wh = 0.66 * storey;
			float d = max(length(vec2(wc.x, max(wc.y - (wh - hw), 0.0))) - hw, -wc.y);
			float in_win = 1.0 - smoothstep(-aa, aa, d);
			float in_frame = 1.0 - smoothstep(0.07 - aa, 0.07 + aa, d);
			vec2 wp = vec2((wc.x + hw) / (hw * 2.0), wc.y / wh);
			col = mix(col, col * to_linear(grime_color) * 3.0,
				streaks(vec2(wc.x, wc.y + 0.1), 0.0, hw * 2.2, -0.05, seed + cell.x * 7.0 + cell.y) * 0.5 * grime);
			col = mix(col, brass * (0.7 + 0.3 * fres), in_frame - in_win);
			bool calm = cy + storey < calm_top;
			float kind = calm ? 0.0 : k;
			// What fills it: a roller shutter part of the way down (all the way in the wall-run band),
			// dark glass with the lamplit haze in it, frosted amber glass, or a lit room.
			float down = calm ? 1.0 : 0.3 + 0.7 * hash11(k * 31.7);
			vec3 sh = to_linear(shutter_color(hash11(seed * 3.1 + cell.x * 0.13)));
			float ribs = filtered_pulse(uv.y / 0.06, fw_m.y / 0.06, 0.0, 0.16);
			vec3 shutter = sh * (1.0 - 0.2 * ribs) * (0.9 + 0.14 * wp.y) + sky * 0.6;
			float aw = fw.y * storey / wh;
			float covered = kind < 0.35 ? smoothstep(1.0 - down - aw, 1.0 - down + aw, wp.y) : 0.0;
			float lamp = step(hash12(cell * 3.3 + seed), COLOR.a);
			float streak = smoothstep(0.35, 0.65, fract(wp.x * 0.7 - wp.y * 0.45 + hash11(k * 5.0)));
			vec3 dark_glass = to_linear(glass_color) + sky + to_linear(sheen_color) * 0.05 * streak;
			vec3 room = to_linear(window_warm) * window_glow * (0.42 + 0.38 * wp.y);
			vec3 frost = to_linear(frost_color) * (0.62 + 0.22 * wp.y) + to_linear(window_warm) * 0.05 * lamp;
			vec3 glass = kind < 0.6 ? mix(dark_glass, room, lamp) : (kind < 0.8 ? frost : dark_glass);
			// Slim brass mullions.
			float mullion = max(band(wc.x, -0.018, 0.018, aa), band(wc.y, wh * 0.55 - 0.018, wh * 0.55 + 0.018, aa));
			vec3 fill = mix(glass, shutter, covered);
			fill = mix(fill, brass * 0.7, mullion * (1.0 - covered));
			col = mix(col, fill, in_win);
		}
		col = weather(col, uv, storey_base, seed);
	} else if (style == 2) {
		if (uv.y < calm_top - 0.6) {
			// Large smooth plated panels through the wall-run band, studded along the joints.
			vec2 bq = uv / vec2(2.4, 1.2);
			vec2 bf = fw_m / vec2(2.4, 1.2);
			float joint = max(filtered_pulse(bq.y, bf.y, 0.0, 0.012), filtered_pulse(bq.x, bf.x, 0.0, 0.006));
			col = wall * (0.92 + 0.1 * hash12(floor(bq) + seed)) * (1.0 - 0.35 * joint);
			float pipe2_y = 5.2 + 1.0 * hash11(seed * 2.9);
			vec4 pipe2 = painted_pipe(uv.y, pipe2_y, 0.24, fw_m.y, pipe2_y - 0.24);
			col = mix(col, pipe2.rgb, pipe2.a);
			col = weather(col, uv, storey_base, seed);
		} else {
			// Tall arched glazing on a grid of slim brass mullions, the hall warm inside.
			float cw = 4.2;
			vec2 lp = vec2((fract(uv.x / cw) - 0.5) * cw, uv.y - calm_top);
			float hw = 1.45;
			float spring = 4.0;
			float d = lp.y < spring ? max(abs(lp.x) - hw, 0.25 - lp.y) : length(vec2(lp.x, lp.y - spring)) - hw;
			float in_arch = 1.0 - smoothstep(-aa, aa, d);
			float in_frame = 1.0 - smoothstep(0.1 - aa, 0.1 + aa, d);
			float bars = max(filtered_pulse(uv.x / 0.7 + 0.5, fw_m.x / 0.7, 0.0, 0.05),
				filtered_pulse(uv.y / 0.9, fw_m.y / 0.9, 0.0, 0.04));
			float lamp = step(hash11(floor(uv.x / cw) * 1.3 + seed), 0.4 + COLOR.a);
			vec3 inside = mix(to_linear(glass_color) + sky,
				to_linear(mix(window_warm, trim_color, 0.4)) * window_glow * (0.3 + 0.25 * clamp(lp.y / 6.0, 0.0, 1.0)), lamp);
			inside = mix(inside, brass * 0.5, bars);
			col = weather(col, uv, storey_base, seed);
			col = mix(col, brass * 0.8, in_frame);
			col = mix(col, inside, in_arch);
		}
	} else if (style == 3) {
		col = plinth(uv, fw_m, seed);
	} else if (style == 4) {
		// Iron-clad piers: a groove down the middle, brass jambs along both edges.
		float pw = COLOR.a * 8.0;
		float e = min(uv.x, pw - uv.x);
		col = wall * (0.93 + 0.1 * value_noise(vec2(uv.x * 9.0, uv.y * 0.6) + seed));
		col *= 1.0 - 0.35 * band(uv.x, pw * 0.5 - 0.012, pw * 0.5 + 0.012, fw_m.x);
		col = mix(col, brass * 0.85, 1.0 - smoothstep(0.07 - fw_m.x, 0.07 + fw_m.x, e));
		col = weather(col, uv, plinth_top, seed);
	} else if (style == 5) {
		// A lounge seen through the glass: a back wall of dark panelling, rows of slot machines with
		// dim screens (violet, blue or warm white), and a sconce between pairs of them. UV.x from the
		// window's start.
		vec3 back = albedo * 0.55;
		float groove = filtered_pulse(uv.x / 0.45, fw_m.x / 0.45, 0.0, 0.03);
		back *= 1.0 - 0.35 * groove;
		vec2 g = vec2(uv.x / 0.78, 0.0);
		float cx = floor(g.x);
		float fx = fract(g.x);
		float exists = step(0.18, hash12(vec2(cx, seed)));
		float cab_h = 1.15 + 0.45 * hash12(vec2(cx, seed + 3.0));
		float top = plinth_top + cab_h;
		float fxw = fw_m.x / 0.78;
		float body = band(fx, 0.08, 0.92, fxw) * step(plinth_top, uv.y) * step(uv.y, top) * exists;
		float screen = band(fx, 0.2, 0.8, fxw) * band(uv.y, plinth_top + cab_h * 0.5, plinth_top + cab_h * 0.82, fw_m.y) * exists;
		float tone = hash12(vec2(cx, seed + 7.0));
		vec3 screen_col = tone < 0.34 ? to_linear(neon_a) : (tone < 0.67 ? to_linear(neon_b) : to_linear(window_warm));
		vec3 cab = to_linear(vec3(0.07, 0.06, 0.08)) + brass * 0.1 * band(uv.y, top - 0.12, top, fw_m.y);
		col = mix(back, cab, body);
		col = mix(col, screen_col * 0.5, screen);
		// A brass sconce between the machines, high on the wall, throwing a warm pool.
		float sconce_x = (fract(uv.x / 1.56 + 0.5) - 0.5) * 1.56;
		float sconce = (1.0 - smoothstep(0.07 - aa, 0.07 + aa, length(vec2(sconce_x, uv.y - 2.35))))
			* step(0.5, hash12(vec2(floor(uv.x / 1.56 + 0.5), seed + 11.0)));
		float pool = exp(-(sconce_x * sconce_x * 1.2 + (uv.y - 2.2) * (uv.y - 2.2) * 0.5)) * 0.35;
		col += to_linear(window_warm) * pool * (1.0 - body) * 0.5;
		col = mix(col, to_linear(window_warm) * 0.9, sconce);
		// Lit warm from the lamps; the smart glass in front catches a soft band of the haze.
		col *= to_linear(window_warm) * (0.42 + 0.3 * smoothstep(plinth_top, 2.8, uv.y)) * 1.6;
		float pane = smoothstep(0.4, 0.5, fract((uv.x * 0.5 + uv.y * 0.35) * 0.4 + seed * 0.13))
			* (1.0 - smoothstep(0.55, 0.7, fract((uv.x * 0.5 + uv.y * 0.35) * 0.4 + seed * 0.13)));
		col += sky * (0.5 + 0.8 * pane);
		shade = 1.0;
	} else {
		col = albedo * (0.14 + 0.1 * smoothstep(plinth_top, 2.8, uv.y)) * to_linear(window_warm);
		shade = 1.0;
	}

	// The fascia over the shop windows: a brass band along the bottom of the faces above them.
	if (style <= 2) {
		float fascia = 1.0 - smoothstep(storey_base - 0.12 - fw_m.y, storey_base - 0.12 + fw_m.y, uv.y);
		col = mix(col, brass * 0.7 * mix(vec3(1.0), to_linear(grime_color) * 3.0, 0.3 * grime), fascia);
	}
	col *= shade;
	// The street lies in the lamplit haze; the light thins up the faces into the dark of the vault.
	if (style <= 4) {
		col *= mix(0.9, 1.0, smoothstep(1.0, 6.0, uv.y)) * (1.0 - 0.3 * smoothstep(12.0, 26.0, uv.y));
	}
	ALBEDO = col * light_factor(scenery_light);
}

// Marketplace building faces (MarketplaceSkin, MarketFacades): sun-bleached stucco with procedural
// windows, no window geometry except the shop windows at the low part of the wall.
//   UV     x metres along the face (from the building's window grid origin), y world height (metres)
//   UV2    x = style (below), y = seed (whole number)
//   COLOR  rgb = wall colour (sRGB), a = share of lit windows
// Styles:
//   0 UPPER     storeys over the shops: shuttered, open and lit windows, cornices, sills. Windows in
//               the wall-run band (below calm_top) stay shuttered, so the band stays calm.
//   1 CASINO    panels of dark glass framed by rows of bulbs, only above decor_top; plain below.
//   2 HALL      a market hall: rusticated stone, tall arched windows above the wall-run band.
//   3 LOWER     from the market floor (street_y) up to the shop windows' sills: arcades far below the
//               stall roofs, plain plaster, then a tiled plinth. No vents: in the Marketplace, vents at
//               the foot of a wall are sewer-screech lairs (GDD §5, §9.5), drawn by the Screech.
//   4 PIER      plain stucco between the shop windows (UV.x from the pier's start, its width / 8 m
//               in COLOR.a): the windows' trim jambs along both edges.
//   5 INTERIOR  a shop window's display: shelves of goods under a warm lamp (UV.x from the window's
//               start). Lit, never glowing: red and orange goods stay dim (GDD §5 colour rule).
//   6 REVEAL    the display's sides, floor and top.
// The low sun lights the upper floors facing it (sun_dir), gold at dusk; the street is in shade.
// Windows and bulbs are box-filtered, so far away they fade to the face's average.
shader_type spatial;
render_mode unshaded, cull_back;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"
#include "res://scripts/world/meshes/shaders/kit_flash.gdshaderinc"

uniform vec3 trim_color : source_color = vec3(0.9, 0.88, 0.82);
uniform vec3 shutter_a : source_color = vec3(0.22, 0.36, 0.6);
uniform vec3 shutter_b : source_color = vec3(0.3, 0.45, 0.5);
uniform vec3 shutter_c : source_color = vec3(0.46, 0.35, 0.25);
uniform vec3 shutter_d : source_color = vec3(0.6, 0.58, 0.54);
uniform vec3 window_warm : source_color = vec3(1.0, 0.86, 0.64);
uniform float window_glow = 0.75;
uniform vec3 glass_color : source_color = vec3(0.08, 0.08, 0.1);
uniform vec3 sheen_color : source_color = vec3(0.56, 0.42, 0.34);
uniform float sheen_strength = 0.14;
uniform vec3 sun_color : source_color = vec3(1.0, 0.72, 0.42);
uniform float sun_strength = 0.55;
// Where the sun comes from: faces turned toward it are lit above sun_line.
uniform vec3 sun_toward = vec3(0.82, 0.4, 0.36);
uniform float sun_line = 11.0;
uniform vec3 plinth_color : source_color = vec3(0.27, 0.4, 0.6);
uniform vec3 plinth_light : source_color = vec3(0.84, 0.82, 0.76);
uniform float plinth_top = 0.85;
uniform float street_y = -6.5;
uniform float storey_base = 3.0;
uniform float storey = 3.2;
// Below this height windows stay shuttered (the wall-run band); decorative lights start at decor_top.
uniform float calm_top = 7.0;
uniform float decor_top = 8.0;
uniform vec3 bulb_color : source_color = vec3(1.0, 0.9, 0.76);
uniform vec3 neon_a : source_color = vec3(0.62, 0.46, 1.0);
uniform vec3 neon_b : source_color = vec3(0.36, 0.55, 1.0);

// Upper-floor window cells: the width (metres) by the building's seed. MarketFacades mirrors it.
float cell_width(float seed) {
	int k = int(mod(seed, 4.0));
	return k == 0 ? 2.6 : (k == 1 ? 3.0 : (k == 2 ? 2.2 : 3.4));
}

vec3 shutter_color(float r) {
	return r < 0.25 ? shutter_a : (r < 0.5 ? shutter_b : (r < 0.75 ? shutter_c : shutter_d));
}

// Goods on the shelves: the same splashes of colour as the stalls' (kit_market.gdshaderinc).
vec3 goods_color(float r) {
	if (r < 0.16) return vec3(0.66, 0.2, 0.14);
	if (r < 0.3) return vec3(0.8, 0.46, 0.14);
	if (r < 0.44) return vec3(0.74, 0.64, 0.2);
	if (r < 0.56) return vec3(0.3, 0.5, 0.22);
	if (r < 0.68) return vec3(0.44, 0.24, 0.46);
	if (r < 0.8) return vec3(0.22, 0.38, 0.62);
	if (r < 0.9) return vec3(0.82, 0.78, 0.68);
	return vec3(0.46, 0.3, 0.2);
}

// The plinth under the shop windows: a painted dado of glazed tiles in one muted colour (quiet on
// purpose: bold checks would shout, and read like the finish line), a pale cap along its top.
vec3 plinth(vec2 uv, vec2 fw_m, float seed) {
	vec2 q = uv / vec2(0.3, 0.22);
	vec2 fq = fw_m / vec2(0.3, 0.22);
	q.x += 0.5 * mod(floor(q.y), 2.0);
	vec3 tile = to_linear(plinth_color) * (0.9 + 0.14 * hash12(floor(q) + seed));
	float grout = max(filtered_pulse(q.x, fq.x, 0.0, 0.06), filtered_pulse(q.y, fq.y, 0.0, 0.06));
	tile = mix(tile, to_linear(plinth_light) * 0.7, grout * 0.5);
	float cap = clamp((uv.y - (plinth_top - 0.06)) / max(fw_m.y, 1e-4) + 0.5, 0.0, 1.0);
	return mix(tile, to_linear(plinth_light), cap);
}

void fragment() {
	int style = int(UV2.x + 0.5);
	float seed = floor(UV2.y + 0.5);
	vec3 nv = flat_view_normal(VERTEX);
	vec3 n = (INV_VIEW_MATRIX * vec4(nv, 0.0)).xyz;
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 uv = UV;
	// Pixel footprints are taken here, before any branch, and passed down (docs/ARCHITECTURE.md, Zone
	// skins: the kit's shader rules); never zero, so every smoothstep keeps two distinct edges.
	vec2 fw_m = max(fwidth(uv), vec2(1e-4));
	float fres = 1.0 - clamp(dot(nv, VIEW), 0.0, 1.0);
	vec3 albedo = to_linear(COLOR.rgb);
	// Faces toward the lanes take the shade of the street; faces toward the player a little more light.
	float shade = 0.74 + 0.18 * max(n.z, 0.0) + 0.08 * max(n.y, 0.0);
	float plaster = (0.9 + 0.13 * value_noise(uv * vec2(0.7, 0.45) + seed))
		* (1.0 - 0.1 * smoothstep(0.6, 0.85, value_noise(uv * 0.11 + seed * 1.7)));
	vec3 wall = albedo * plaster;
	vec3 col = wall;
	float lit_by_sun = 1.0;

	if (style == 0 || style == 1) {
		float cw = style == 1 ? 3.0 : cell_width(seed);
		vec2 p = vec2(uv.x / cw, (uv.y - storey_base) / storey);
		vec2 cell = floor(p);
		vec2 fp = fract(p);
		vec2 fw = fw_m / vec2(cw, storey);
		float k = hash12(cell * vec2(1.7, 2.3) + seed * 5.0);
		float cy = cell.y * storey + storey_base;
		// Storey cornices and the dust gathering under them.
		col *= 1.0 + 0.12 * filtered_pulse(p.y, fw.y, 0.0, 0.03) - 0.1 * filtered_pulse(p.y, fw.y, 0.03, 0.09);
		if (style == 1 && cy + storey > decor_top) {
			// Casino: dark glass panels framed by bulbs.
			float panel = filtered_pulse(p.x, fw.x, 0.06, 0.94) * filtered_pulse(p.y, fw.y, 0.08, 0.92);
			vec3 glass = mix(to_linear(glass_color), to_linear(neon_a) * 0.25, fp.y * 0.6)
				+ to_linear(sheen_color) * sheen_strength * (0.3 + 0.7 * fres * fres);
			col = mix(col * 0.55, glass, panel);
			vec2 m = vec2((fp.x - 0.03) * cw, (fp.y - 0.04) * storey);
			vec2 m2 = vec2((0.97 - fp.x) * cw, (0.96 - fp.y) * storey);
			float along_y = (fract(uv.y / 0.3) - 0.5) * 0.3;
			float along_x = (fract(uv.x / 0.3) - 0.5) * 0.3;
			float d = min(min(length(vec2(m.x, along_y)), length(vec2(m2.x, along_y))),
				min(length(vec2(along_x, m.y)), length(vec2(along_x, m2.y))));
			float bulb = 1.0 - smoothstep(0.045, 0.075, d);
			bulb = mix(bulb, 0.22, smoothstep(0.02, 0.08, max(fw_m.x, fw_m.y)));
			float chase = mix(0.7 + 0.3 * sin(uv.x * 1.3 + uv.y * 0.7 - TIME * 1.6), 0.9, reduced_flashing);
			col = mix(col, vec3(0.0), bulb * 0.3) + to_linear(bulb_color) * (bulb * 2.4 * chase);
			lit_by_sun = 1.0 - panel;
		} else if (style == 1) {
			// Casino, low storeys: plain stone panels (the wall-run band stays calm).
			float joint = max(filtered_pulse(p.x, fw.x, 0.0, 0.02), filtered_pulse(p.y, fw.y, 0.0, 0.02));
			col *= 0.8 * (1.0 - 0.3 * joint);
		} else {
			// Upper floors: windows in trim frames with sills; shutters closed, open, or none.
			float hw = 0.46 / cw;
			float wx0 = 0.5 - hw;
			float wx1 = 0.5 + hw;
			float in_win = filtered_pulse(p.x, fw.x, wx0, wx1) * filtered_pulse(p.y, fw.y, 0.26, 0.74);
			float in_frame = filtered_pulse(p.x, fw.x, wx0 - 0.08 / cw, wx1 + 0.08 / cw) * filtered_pulse(p.y, fw.y, 0.235, 0.765);
			float in_sill = filtered_pulse(p.x, fw.x, wx0 - 0.14 / cw, wx1 + 0.14 / cw) * filtered_pulse(p.y, fw.y, 0.21, 0.245);
			// Rain and dust streaks under the sills.
			float streak = filtered_pulse(p.x, fw.x, wx0, wx1) * step(0.05, fp.y) * step(fp.y, 0.19)
				* smoothstep(0.05, 0.19, fp.y) * (0.5 + 0.5 * value_noise(vec2(uv.x * 6.0, cell.y)));
			col *= 1.0 - 0.12 * streak;
			col = mix(col, to_linear(trim_color) * plaster, max(in_frame - in_win, in_sill));
			vec2 wp = vec2((fp.x - wx0) / (wx1 - wx0), (fp.y - 0.26) / 0.48);
			bool calm = cy + storey < calm_top;
			float kind = calm ? 0.0 : k;
			vec3 sh = to_linear(shutter_color(hash11(seed * 3.1 + cell.x * 0.13))) * (0.9 + 0.2 * hash11(k * 7.0));
			float slats = filtered_pulse(uv.y / 0.09, fw_m.y / 0.09, 0.0, 0.35);
			vec3 closed = sh * (1.0 - 0.3 * slats) * (1.0 - 0.4 * filtered_pulse(wp.x, fw.x / (wx1 - wx0), 0.48, 0.52));
			float lamp = step(hash12(cell * 3.3 + seed), COLOR.a);
			vec3 room = mix(to_linear(glass_color) + to_linear(sheen_color) * sheen_strength * (0.4 + 0.6 * fres * fres),
				to_linear(window_warm) * window_glow * (0.45 + 0.4 * wp.y), lamp);
			// Curtains drawn at the sides of some windows.
			float curtain = step(0.5, hash11(k * 13.0)) * (1.0 - smoothstep(0.18, 0.24, min(wp.x, 1.0 - wp.x)));
			room = mix(room, room * 0.55 + to_linear(trim_color) * 0.08, curtain);
			vec3 fill = kind < 0.4 ? closed : room;
			col = mix(col, fill, in_win);
			// Open shutters folded back against the wall on both sides.
			if (kind >= 0.4 && kind < 0.65) {
				float left = filtered_pulse(p.x, fw.x, wx0 - hw - 0.1 / cw, wx0 - 0.1 / cw);
				float right = filtered_pulse(p.x, fw.x, wx1 + 0.1 / cw, wx1 + hw + 0.1 / cw);
				col = mix(col, sh * (1.0 - 0.3 * slats), (left + right) * filtered_pulse(p.y, fw.y, 0.26, 0.74));
			}
			lit_by_sun = 1.0 - in_win * (kind < 0.4 ? 0.0 : 1.0);
		}
	} else if (style == 2) {
		if (uv.y < calm_top - 0.6) {
			// Rusticated stone blocks through the wall-run band.
			vec2 bq = uv / vec2(1.2, 0.45);
			vec2 bf = fw_m / vec2(1.2, 0.45);
			float shift = 0.5 * mod(floor(bq.y), 2.0);
			float joint = max(filtered_pulse(bq.y, bf.y, 0.0, 0.08), filtered_pulse(bq.x + shift, bf.x, 0.0, 0.04));
			col = wall * (0.9 + 0.15 * hash12(floor(vec2(bq.x + shift, bq.y)) + seed)) * (1.0 - 0.35 * joint);
		} else {
			// Tall arched windows, glazing bars, a warm hall inside.
			float cw = 4.2;
			float base_y = calm_top;
			vec2 lp = vec2((fract(uv.x / cw) - 0.5) * cw, uv.y - base_y);
			float hw = 1.25;
			float spring = 4.0;
			float d = lp.y < spring ? max(abs(lp.x) - hw, 0.35 - lp.y) : length(vec2(lp.x, lp.y - spring)) - hw;
			float fwd = max(fw_m.x, fw_m.y);
			float in_arch = 1.0 - smoothstep(-fwd, fwd, d);
			float in_surround = 1.0 - smoothstep(0.25 - fwd, 0.25 + fwd, d);
			float bars = max(filtered_pulse(uv.x / 0.62 + 0.5, fw_m.x / 0.62, 0.0, 0.07),
				filtered_pulse(uv.y / 0.8, fw_m.y / 0.8, 0.0, 0.05));
			float lamp = step(hash11(floor(uv.x / cw) * 1.3 + seed), 0.35 + COLOR.a);
			vec3 inside = mix(to_linear(glass_color) + to_linear(sheen_color) * sheen_strength * (0.4 + 0.6 * fres * fres),
				to_linear(mix(window_warm, trim_color, 0.4)) * window_glow * (0.3 + 0.25 * clamp(lp.y / 6.0, 0.0, 1.0)), lamp);
			inside = mix(inside, to_linear(trim_color) * 0.3, bars);
			col = mix(col, to_linear(trim_color) * plaster, in_surround);
			col = mix(col, inside, in_arch);
			lit_by_sun = 1.0 - in_arch;
		}
	} else if (style == 3) {
		if (uv.y >= 0.0) {
			col = plinth(uv, fw_m, seed);
		} else if (uv.y < street_y + 3.9) {
			// Arcades at the market floor, lit warm inside.
			vec2 lp = vec2((fract(uv.x / 3.4) - 0.5) * 3.4, uv.y - street_y);
			float d = lp.y < 2.2 ? abs(lp.x) - 1.2 : length(vec2(lp.x, lp.y - 2.2)) - 1.2;
			float fwd = max(fw_m.x, fw_m.y);
			float in_arch = 1.0 - smoothstep(-fwd, fwd, d);
			vec3 inside = to_linear(window_warm) * 0.55 * (0.5 + 0.5 * clamp(lp.y / 3.0, 0.0, 1.0));
			vec2 cell = floor(vec2(uv.x / 0.3, lp.y / 0.3));
			float goods = step(lp.y, 1.1) * step(0.35, hash12(cell + seed));
			inside = mix(inside, to_linear(goods_color(hash12(cell * 0.37 + seed))) * 0.6, goods);
			col = mix(wall * 0.8, inside, in_arch);
		} else {
			col = wall * 0.85;
		}
		lit_by_sun = 0.0;
	} else if (style == 4) {
		float pw = COLOR.a * 8.0;
		float e = min(uv.x, pw - uv.x);
		col = mix(col, to_linear(trim_color) * plaster, 1.0 - smoothstep(0.075 - fw_m.x, 0.075 + fw_m.x, e));
		lit_by_sun = 0.0;
	} else if (style == 5) {
		// A shop's display: shelves of goods under a warm lamp. UV.x from the window's start.
		float r = hash11(seed * 1.7 + 0.3);
		vec3 back = albedo * 0.75;
		float sy = (uv.y - plinth_top) / 0.46;
		float shelf = filtered_pulse(sy, fw_m.y / 0.46, 0.0, 0.09);
		vec2 g = vec2(uv.x / 0.21, sy);
		vec2 slot = floor(g);
		float rise = fract(g.y);
		float h = 0.35 + 0.45 * hash12(slot + seed + 3.0);
		float item = step(0.3, hash12(slot + seed)) * step(0.1, rise) * step(rise, 0.1 + h * 0.85)
			* filtered_pulse(g.x, fw_m.x / 0.21, 0.12, 0.88);
		vec3 goods = to_linear(mix(goods_color(hash12(vec2(floor(slot.x / 3.0), slot.y) + seed * 1.3)), vec3(0.55), 0.2));
		col = mix(back, goods * (0.85 + 0.3 * hash12(slot * 1.9 + seed)), item * step(plinth_top + 0.1, uv.y));
		col = mix(col, to_linear(vec3(0.4, 0.3, 0.21)), shelf);
		// Some shops hang their wares from the ceiling instead (cloth, lanterns, baskets).
		if (r > 0.6) {
			float hang = step(uv.y, 2.75) * step(2.75 - 0.5 - 0.5 * hash11(floor(uv.x / 0.35) + seed), uv.y)
				* filtered_pulse(uv.x / 0.35, fw_m.x / 0.35, 0.2, 0.8);
			col = mix(col, to_linear(mix(goods_color(hash11(floor(uv.x / 0.35) * 1.7 + seed)), vec3(0.55), 0.25)) * 0.85, hang);
		}
		// Lit warm from a lamp at the top; darker toward the display's floor.
		col *= to_linear(window_warm) * (0.36 + 0.32 * smoothstep(plinth_top, 2.8, uv.y));
		lit_by_sun = 0.0;
		shade = 1.0;
	} else {
		col = albedo * (0.16 + 0.12 * smoothstep(plinth_top, 2.8, uv.y));
		lit_by_sun = 0.0;
		shade = 1.0;
	}

	// The lintel over the shop windows: a trim band along the bottom of the faces above them.
	if (style <= 2) {
		float lintel = 1.0 - smoothstep(storey_base - 0.1 - fw_m.y, storey_base - 0.1 + fw_m.y, uv.y);
		col = mix(col, to_linear(trim_color) * plaster, lintel);
	}
	col *= shade;
	// The street lies in the evening shade; the light grows up the faces.
	if (style <= 4) {
		col *= mix(0.78, 1.0, smoothstep(2.0, 14.0, uv.y));
	}
	// The low sun on the upper floors of the faces turned toward it, under a ragged shadow line.
	float sun_face = max(dot(n, normalize(sun_toward)), 0.0);
	float line = sun_line + 2.5 * (value_noise(vec2(world.z * 0.04, sign(n.x) * 7.0)) - 0.5) * 2.0;
	float sunlit = sun_face * smoothstep(line - 0.4, line + 0.8, uv.y) * lit_by_sun;
	col += albedo * plaster * to_linear(sun_color) * (sun_strength * sunlit);
	// Toward the market floor far below, the stalls' shade.
	col *= mix(0.4, 1.0, smoothstep(street_y, street_y + 8.0, uv.y));
	ALBEDO = col;
}

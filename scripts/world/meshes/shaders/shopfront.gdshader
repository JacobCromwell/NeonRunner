// Marketplace building faces (MarketplaceSkin, MarketFacades): the market's future (GDD §5: the same
// vaguely cyberpunk world as every zone, never historical), in its tan, white and pale blue-grey:
// composite cladding panels with slab-edge bands, rounded window openings in thin aluminium frames,
// smart glass (dark, lit warm, or frosted), sleek roller shutters, conduits up some faces; dusty and
// weathered (dustier and dirtier than the Neon City): grime rising from the foot of the faces, dirty
// streaks under the windows, blotches. No window geometry except the shop windows low on the wall.
//   UV     x metres along the face (from the building's window grid origin), y world height (metres)
//   UV2    x = style (below), y = seed (whole number)
//   COLOR  rgb = wall colour (sRGB), a = share of lit windows
// Styles:
//   0 UPPER     storeys over the shops: cladding, windows with shutters, smart glass or lit rooms.
//               Windows in the wall-run band (below calm_top) keep their shutters down, so the band
//               stays calm.
//   1 CASINO    panels of dark glass framed by rows of bulbs, only above decor_top; plain below.
//   2 HALL      a market hall: large smooth panels through the wall-run band, a glass vault above it.
//   3 LOWER     the plinth, from the stall roofs up to the shop windows' sills (below the roofs the
//               walls are in the stalls' deep shade, drawn with the kit's PAT_UNDER): composite
//               skirting panels under an aluminium cap, grimy at the foot. No vents: in the
//               Marketplace, vents at the foot of a wall are sewer-screech lairs (GDD §5, §9.5),
//               drawn by the Screech.
//   4 PIER      metal-clad piers between the shop windows (UV.x from the pier's start, its width /
//               8 m in COLOR.a), with the windows' aluminium jambs along both edges.
//   5 INTERIOR  a shop window's display: shelves of goods under a warm lamp, digital price tags,
//               seen through smart glass (UV.x from the window's start). Lit, never glowing: red and
//               orange goods stay dim (GDD §5 colour rule).
//   6 REVEAL    the display's sides, floor and top.
// The low sun lights the upper floors facing it (sun_toward), gold at dusk; the street is in shade.
// Windows and bulbs are box-filtered, so far away they fade to the face's average.
shader_type spatial;
render_mode unshaded, cull_back;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"
#include "res://scripts/world/meshes/shaders/kit_flash.gdshaderinc"
#include "res://scripts/world/meshes/shaders/kit_marks.gdshaderinc"

// A level's darker lighting (ZoneSkin.apply_darkness): the scenery dims with it.
global uniform float scenery_light;
// The street's light under a level's own sky (ZoneSkin.set_scenery_tint; white = the zone's own).
global uniform vec3 scenery_tint;

uniform vec3 trim_color : source_color = vec3(0.9, 0.88, 0.82);
// Window frames, jambs and caps: pale anodised aluminium.
uniform vec3 metal_color : source_color = vec3(0.7, 0.72, 0.74);
uniform vec3 shutter_a : source_color = vec3(0.22, 0.36, 0.6);
uniform vec3 shutter_b : source_color = vec3(0.3, 0.45, 0.5);
uniform vec3 shutter_c : source_color = vec3(0.46, 0.35, 0.25);
uniform vec3 shutter_d : source_color = vec3(0.6, 0.58, 0.54);
uniform vec3 window_warm : source_color = vec3(1.0, 0.86, 0.64);
uniform float window_glow = 0.75;
uniform vec3 glass_color : source_color = vec3(0.08, 0.08, 0.1);
// Frosted smart glass (privacy mode): milky, lit a little from inside.
uniform vec3 frost_color : source_color = vec3(0.62, 0.66, 0.7);
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
uniform float storey_base = 3.0;
uniform float storey = 3.2;
// Below this height windows keep their shutters down (the wall-run band); decorative lights start
// at decor_top.
uniform float calm_top = 7.0;
uniform float decor_top = 8.0;
uniform vec3 bulb_color : source_color = vec3(1.0, 0.9, 0.76);
uniform vec3 neon_a : source_color = vec3(0.62, 0.46, 1.0);
uniform vec3 neon_b : source_color = vec3(0.36, 0.55, 1.0);
// Dust and grime (GDD §5: dustier and dirtier than the Neon City).
uniform vec3 grime_color : source_color = vec3(0.3, 0.26, 0.22);
uniform float grime = 1.0;

// Upper-floor window cells: the width (metres) by the building's seed. MarketFacades mirrors it.
float cell_width(float seed) {
	int k = int(mod(seed, 4.0));
	return k == 0 ? 2.6 : (k == 1 ? 3.0 : (k == 2 ? 2.2 : 3.4));
}

vec3 shutter_color(float r) {
	return r < 0.25 ? shutter_a : (r < 0.5 ? shutter_b : (r < 0.75 ? shutter_c : shutter_d));
}

// Goods on the shelves: splashes of colour, lit, never glowing.
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

// Grime on a face at height y above its foot `foot` (linear colour in, linear out): darker and
// browner toward the foot, in ragged tide marks, and broad weathering blotches all over.
vec3 weather(vec3 col, vec2 uv, float foot, float seed) {
	float rise = 1.0 - smoothstep(0.0, 0.55 + 0.35 * value_noise(vec2(uv.x * 1.3, seed)), uv.y - foot);
	col = mix(col, to_linear(grime_color), rise * 0.3 * grime);
	float blotch = smoothstep(0.5, 0.85, value_noise(uv * vec2(0.3, 0.2) + seed * 0.37));
	return col * (1.0 - 0.12 * blotch * grime) * (0.96 + 0.06 * value_noise(uv * 1.7 + seed));
}

// Dirty streaks running down from something's lower edge at `edge_y`, over `width` metres centred
// on `cx` (uv in metres): how dirty, 0-1.
float streaks(vec2 uv, float cx, float width, float edge_y, float seed) {
	float x = uv.x - cx;
	float across = 1.0 - smoothstep(width * 0.35, width * 0.5, abs(x));
	float below = edge_y - uv.y;
	float run = step(0.0, below) * (1.0 - smoothstep(0.1, 0.8 + 0.6 * hash11(seed + floor(x * 4.0)), below));
	return across * run * (0.45 + 0.55 * value_noise(vec2(x * 7.0, seed)));
}

// The plinth under the shop windows: composite skirting panels in one muted colour under a thin
// aluminium cap, dust gathered on the cap and grime rising from the foot.
vec3 plinth(vec2 uv, vec2 fw_m, float seed) {
	vec3 panel = to_linear(mix(plinth_color, vec3(dot(plinth_color, vec3(0.33))), 0.2));
	float k = floor(uv.x / 1.2);
	panel *= 0.93 + 0.1 * hash12(vec2(k, seed));
	float joint = filtered_pulse(uv.x / 1.2, fw_m.x / 1.2, 0.0, 0.012);
	panel *= 1.0 - 0.35 * joint;
	float cap = band(uv.y, plinth_top - 0.05, plinth_top + 1.0, fw_m.y);
	vec3 col = mix(panel, to_linear(metal_color) * 0.9, cap);
	// A kick strip along the foot.
	col *= 1.0 - 0.25 * band(uv.y, -1.0, 0.09, fw_m.y);
	return weather(col, uv, 0.0, seed);
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
	float aa = max(fw_m.x, fw_m.y);
	float fres = 1.0 - clamp(dot(nv, VIEW), 0.0, 1.0);
	vec3 albedo = to_linear(COLOR.rgb);
	// Faces toward the lanes take the shade of the street; faces toward the player a little more light.
	float shade = 0.74 + 0.18 * max(n.z, 0.0) + 0.08 * max(n.y, 0.0);
	vec3 wall = albedo * (0.95 + 0.06 * value_noise(uv * vec2(0.7, 0.45) + seed));
	vec3 col = wall;
	vec3 metal = to_linear(metal_color);
	vec3 sky = to_linear(sheen_color) * sheen_strength * (0.4 + 0.6 * fres * fres);
	float lit_by_sun = 1.0;

	if (style == 0 || style == 1) {
		float cw = style == 1 ? 3.0 : cell_width(seed);
		vec2 p = vec2(uv.x / cw, (uv.y - storey_base) / storey);
		vec2 cell = floor(p);
		vec2 fp = fract(p);
		vec2 fw = fw_m / vec2(cw, storey);
		float k = hash12(cell * vec2(1.7, 2.3) + seed * 5.0);
		float cy = cell.y * storey + storey_base;
		// Cladding: panels half a cell wide and half a storey high, thin dark joints, each panel a
		// slightly different tone; along every storey's floor a pale slab-edge band, shadowed below.
		vec2 pan = p * 2.0;
		float jx = filtered_pulse(pan.x, fw.x * 2.0, 0.0, 0.03 / cw);
		float jy = filtered_pulse(pan.y, fw.y * 2.0, 0.0, 0.03 / storey);
		col *= (0.95 + 0.07 * hash12(floor(pan) + seed * 3.1)) * (1.0 - 0.3 * max(jx, jy));
		float slab = filtered_pulse(p.y, fw.y, 0.0, 0.2 / storey);
		col = mix(col, to_linear(trim_color) * 0.95, slab);
		col *= 1.0 - 0.3 * filtered_pulse(p.y, fw.y, 1.0 - 0.06 / storey, 1.0);
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
			bulb = mix(bulb, 0.22, smoothstep(0.02, 0.08, aa));
			float chase = mix(0.7 + 0.3 * sin(uv.x * 1.3 + uv.y * 0.7 - TIME * 1.6), 0.9, reduced_flashing);
			col = mix(col, vec3(0.0), bulb * 0.3) + to_linear(bulb_color) * (bulb * 2.4 * chase);
			lit_by_sun = 1.0 - panel;
		} else if (style == 1) {
			// Casino, low storeys: plain dark panels (the wall-run band stays calm).
			col *= 0.8;
		} else {
			// Upper floors: rounded openings in thin aluminium frames, no sills.
			vec2 wc = vec2((fp.x - 0.5) * cw, (fp.y - 0.52) * storey);
			vec2 half_size = vec2(min(0.62, cw * 0.27), 0.74);
			float d = sd_round_box(wc, half_size, 0.12);
			float in_win = 1.0 - smoothstep(-aa, aa, d);
			float in_frame = 1.0 - smoothstep(0.05 - aa, 0.05 + aa, d);
			vec2 wp = (wc + half_size) / (half_size * 2.0);
			// Dirty streaks down from each window's lower corners, and a tide of grime under the slab.
			col = mix(col, col * to_linear(grime_color) * 2.0,
				streaks(vec2(wc.x, wc.y), 0.0, half_size.x * 2.2, -half_size.y - 0.05, seed + cell.x * 7.0 + cell.y) * 0.5 * grime);
			col = mix(col, metal * (0.85 + 0.2 * fres), in_frame - in_win);
			bool calm = cy + storey < calm_top;
			float kind = calm ? 0.0 : k;
			// What fills it: a roller shutter part of the way down (all the way in the wall-run
			// band), dark smart glass with the sky in it, frosted smart glass, or a lit room.
			float down = calm ? 1.0 : 0.3 + 0.7 * hash11(k * 31.7);
			vec3 sh = mix(to_linear(shutter_color(hash11(seed * 3.1 + cell.x * 0.13))), metal * 0.6, 0.35);
			float ribs = filtered_pulse(uv.y / 0.06, fw_m.y / 0.06, 0.0, 0.16);
			vec3 shutter = sh * (1.0 - 0.18 * ribs) * (0.9 + 0.14 * wp.y) + sky * 0.6;
			float aw = fw.y * storey / (half_size.y * 2.0);
			float covered = kind < 0.35 ? smoothstep(1.0 - down - aw, 1.0 - down + aw, wp.y) : 0.0;
			float housing = band(wp.y, 1.0 - 0.12 / (half_size.y * 2.0), 2.0, aw);
			float lamp = step(hash12(cell * 3.3 + seed), COLOR.a);
			float streak = smoothstep(0.35, 0.65, fract(wp.x * 0.7 - wp.y * 0.45 + hash11(k * 5.0)));
			vec3 dark_glass = to_linear(glass_color) + sky + to_linear(sheen_color) * 0.05 * streak;
			vec3 room = to_linear(window_warm) * window_glow * (0.42 + 0.38 * wp.y);
			vec3 frost = to_linear(frost_color) * (0.62 + 0.22 * wp.y) + to_linear(window_warm) * 0.05 * lamp;
			vec3 glass = kind < 0.6 ? mix(dark_glass, room, lamp) : (kind < 0.8 ? frost : dark_glass);
			vec3 fill = mix(glass, shutter, covered);
			fill = mix(fill, metal * 0.75, housing * step(kind, 0.35));
			col = mix(col, fill, in_win);
			lit_by_sun = 1.0 - in_win * (1.0 - covered);
			// A conduit up the face beside some windows (above the wall-run band).
			float conduit = step(hash11(seed * 1.9), 0.45) * band(uv.x - (floor(uv.x / (cw * 3.0)) * cw * 3.0), 0.12, 0.2, fw_m.x)
				* step(calm_top, uv.y);
			col = mix(col, metal * 0.55 * (0.8 + 0.4 * smoothstep(0.12, 0.2, fract(uv.x / (cw * 3.0)) * cw * 3.0)), conduit);
		}
		col = weather(col, uv, storey_base, seed);
	} else if (style == 2) {
		if (uv.y < calm_top - 0.6) {
			// Large smooth panels through the wall-run band.
			vec2 bq = uv / vec2(2.4, 1.2);
			vec2 bf = fw_m / vec2(2.4, 1.2);
			float joint = max(filtered_pulse(bq.y, bf.y, 0.0, 0.012), filtered_pulse(bq.x, bf.x, 0.0, 0.006));
			col = wall * (0.94 + 0.08 * hash12(floor(bq) + seed)) * (1.0 - 0.3 * joint);
			col = weather(col, uv, storey_base, seed);
		} else {
			// A glass vault: tall round-topped panes on a grid of slim mullions, the hall warm inside.
			float cw = 4.2;
			vec2 lp = vec2((fract(uv.x / cw) - 0.5) * cw, uv.y - calm_top);
			float hw = 1.45;
			float spring = 4.0;
			float d = lp.y < spring ? max(abs(lp.x) - hw, 0.25 - lp.y) : length(vec2(lp.x, lp.y - spring)) - hw;
			float in_arch = 1.0 - smoothstep(-aa, aa, d);
			float in_frame = 1.0 - smoothstep(0.08 - aa, 0.08 + aa, d);
			float bars = max(filtered_pulse(uv.x / 0.7 + 0.5, fw_m.x / 0.7, 0.0, 0.05),
				filtered_pulse(uv.y / 0.9, fw_m.y / 0.9, 0.0, 0.04));
			float lamp = step(hash11(floor(uv.x / cw) * 1.3 + seed), 0.35 + COLOR.a);
			vec3 inside = mix(to_linear(glass_color) + sky,
				to_linear(mix(window_warm, trim_color, 0.4)) * window_glow * (0.3 + 0.25 * clamp(lp.y / 6.0, 0.0, 1.0)), lamp);
			inside = mix(inside, metal * 0.5, bars);
			col = weather(col, uv, storey_base, seed);
			col = mix(col, metal * 0.8, in_frame);
			col = mix(col, inside, in_arch);
			lit_by_sun = 1.0 - in_arch;
		}
	} else if (style == 3) {
		col = plinth(uv, fw_m, seed);
		lit_by_sun = 0.0;
	} else if (style == 4) {
		// Metal-clad piers: brushed composite, a groove down the middle, aluminium jambs.
		float pw = COLOR.a * 8.0;
		float e = min(uv.x, pw - uv.x);
		col = mix(wall, metal * 0.8, 0.3) * (0.93 + 0.08 * value_noise(vec2(uv.x * 9.0, uv.y * 0.6) + seed));
		col *= 1.0 - 0.3 * band(uv.x, pw * 0.5 - 0.012, pw * 0.5 + 0.012, fw_m.x);
		col = mix(col, metal, 1.0 - smoothstep(0.06 - fw_m.x, 0.06 + fw_m.x, e));
		col = weather(col, uv, plinth_top, seed);
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
		// Digital price tags along the shelf edges: pale, cool, lit (not glowing).
		float tag = filtered_pulse(g.x, fw_m.x / 0.21, 0.35, 0.65) * filtered_pulse(sy, fw_m.y / 0.46, 0.09, 0.19)
			* step(0.5, hash12(slot * 2.7 + seed));
		col = mix(col, to_linear(vec3(0.78, 0.84, 0.9)) * 0.9, tag);
		// Some shops hang their wares from the ceiling instead (cloth, lanterns, baskets).
		if (r > 0.6) {
			float hang = step(uv.y, 2.75) * step(2.75 - 0.5 - 0.5 * hash11(floor(uv.x / 0.35) + seed), uv.y)
				* filtered_pulse(uv.x / 0.35, fw_m.x / 0.35, 0.2, 0.8);
			col = mix(col, to_linear(mix(goods_color(hash11(floor(uv.x / 0.35) * 1.7 + seed)), vec3(0.55), 0.25)) * 0.85, hang);
		}
		// Lit warm from a lamp at the top; darker toward the display's floor; the smart glass in front
		// catches a soft band of sky.
		col *= to_linear(window_warm) * (0.36 + 0.32 * smoothstep(plinth_top, 2.8, uv.y));
		float pane = smoothstep(0.4, 0.5, fract((uv.x * 0.5 + uv.y * 0.35) * 0.4 + seed * 0.13))
			* (1.0 - smoothstep(0.55, 0.7, fract((uv.x * 0.5 + uv.y * 0.35) * 0.4 + seed * 0.13)));
		col += sky * (0.5 + 0.8 * pane);
		lit_by_sun = 0.0;
		shade = 1.0;
	} else {
		col = albedo * (0.16 + 0.12 * smoothstep(plinth_top, 2.8, uv.y));
		lit_by_sun = 0.0;
		shade = 1.0;
	}

	// The fascia over the shop windows: an aluminium band along the bottom of the faces above them,
	// its top edge catching dust.
	if (style <= 2) {
		float fascia = 1.0 - smoothstep(storey_base - 0.12 - fw_m.y, storey_base - 0.12 + fw_m.y, uv.y);
		col = mix(col, metal * 0.85 * mix(vec3(1.0), to_linear(grime_color) * 2.4, 0.25 * grime), fascia);
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
	col += albedo * to_linear(sun_color) * (sun_strength * sunlit);
	ALBEDO = col * light_factor(scenery_light) * scenery_tint;
}

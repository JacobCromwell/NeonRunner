// Golden Zone building faces (GoldenSkin, GoldenFacades): the elite's city in the same vaguely
// cyberpunk future as every zone (GDD §5), never historical: white and cream composite and stone
// cladding in large seamless panels, gold slab bands and window frames, tall rounded smart-glass
// windows (dark with the sky in them, lit warm, or gold-mirrored), towers of champagne mirror glass
// on gold mullions under glazed crowns, floodlit at the blue hour. Low on every face the wall-run
// band stays calm and looks solid: flush stone, no openings, no lights, only the gold inlay lines
// that mark the wall-run heights; nothing in it resembles a vent (in the Golden Zone, wall vents are
// sewer-screech lairs, drawn by the Screech) or a niche (a niche at wall-run height is a live Gilded
// Sentinel's). Light: the street's warm lamps on the band, floodlights on the entablature washing the
// floors above from below and fading upward, the dusk's cool light high up.
//   UV     x metres along the face (from the building's grid origin), y world height (metres)
//   UV2    x = style (below), y = seed (whole number)
//   COLOR  rgb = wall colour (sRGB), a = share of lit windows
// Styles:
//   0 PLINTH   from the walkway up to plinth_top: polished granite slabs under a gold kick line.
//   1 BAND     the wall-run band, plinth_top to band_top: by the seed, rusticated stone with flush
//              pilasters, large polished panels on a fine gold grid, or a blind arcade (flush arches
//              in a lighter stone); the gold inlay lines at the wall-run heights (mark_a, mark_b), a
//              gold line along its top.
//   2 FRIEZE   the entablature over the band, band_top to frieze_top: cream mouldings round a gold
//              frieze of fluting.
//   3 UPPER    storeys over the band: cladding panels, gold slab bands, tall gold-framed windows
//              (dark with the dusk in them, gold-mirrored, or lit warm, half of those framed by red
//              velvet drapes).
//   4 TOWER    a curtain wall: champagne mirror glass on gold mullions, cream spandrel bands.
//   5 CROWN    a tower's glazed crown: gold ribs over warm-lit glass.
//   6 DEEP     below the walkways, seen only through gaps: the stone in deep shade (COLOR), darkening
//              toward the canal, with a waterline: as dark as a gap's inside must be.
// Windows are box-filtered, so far away they fade to the face's average instead of shimmering. Lit
// windows stay below the glow threshold: the only glows in the zone are hazards and warm-white lamps.
shader_type spatial;
render_mode unshaded, cull_back;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"
#include "res://scripts/world/meshes/shaders/kit_marks.gdshaderinc"

// Colours are sRGB Vector3s (GoldenSkin.srgb()), converted once here with to_linear(), like the
// vertex colours, so both renderers match.
uniform vec3 glass_color = vec3(0.1, 0.11, 0.13);
// Gold-mirrored glass and the towers' champagne mirror glass.
uniform vec3 mirror_color = vec3(0.64, 0.57, 0.46);
uniform vec3 gold_color = vec3(0.78, 0.66, 0.42);
uniform vec3 shine_color = vec3(0.97, 0.93, 0.83);
uniform vec3 granite_color = vec3(0.66, 0.62, 0.6);
uniform vec3 window_warm = vec3(1.0, 0.9, 0.74);
uniform float window_glow = 0.8;
// The red velvet drapes in some lit windows.
uniform vec3 drape_color = vec3(0.44, 0.1, 0.12);
uniform vec3 sheen_color = vec3(0.62, 0.55, 0.46);
uniform float sheen_strength = 0.16;
uniform vec3 flood_color = vec3(1.0, 0.86, 0.66);
uniform float flood_strength = 0.35;
// The floodlights on the entablature wash the floors above it: how far up before their light halves (e^-1).
uniform float flood_reach = 14.0;
// The street's lamplight on the band (its foot, and its top), and the dusk's cool tint high up.
uniform float street_low = 0.56;
uniform float street_high = 0.68;
uniform vec3 dusk_tint = vec3(0.86, 0.9, 1.04);
uniform float plinth_top = 0.9;
uniform float band_top = 7.0;
uniform float frieze_top = 8.6;
uniform float storey = 3.6;
// The wall-run height marks (GDD §3: how high a wall run is): gold inlay lines, unlit.
uniform float mark_a = 2.0;
uniform float mark_b = 4.0;
uniform vec3 mark_color = vec3(0.5, 0.4, 0.24);
// The canal's surface (world height): the waterline on the stone below the walkways.
uniform float canal_y = -5.5;

// A factor of light meant for linear space, as this renderer needs it: the Compatibility renderer
// works in sRGB space, where the same change of brightness is the factor's 1/2.2 power (without it
// every face lit by a factor is far darker on the web than on Forward+).
float light_k(float k) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return pow(max(k, 0.0), 1.0 / 2.2);
#else
	return k;
#endif
}

vec3 light_k3(vec3 k) {
	return vec3(light_k(k.x), light_k(k.y), light_k(k.z));
}

// An sRGB colour as linear light on every renderer (to_linear() passes colours through unchanged on
// the Compatibility renderer): for coloured light that goes into a light_k3() factor.
vec3 light_color(vec3 c) {
	return mix(c * (1.0 / 12.92), pow((c + 0.055) * (1.0 / 1.055), vec3(2.4)), step(vec3(0.04045), c));
}

// How bright the dusk is in the direction r (a reflection): the street's lamplit shade below the
// horizon, the warm afterglow bright at it, the deep blue sky above; and how much of it is that sky.
vec2 dusk_seen(vec3 r) {
	float below = 1.0 - smoothstep(-0.07, 0.08, r.y);
	float horizon = smoothstep(-0.07, 0.08, r.y) * (1.0 - smoothstep(0.08, 0.5, r.y));
	float zenith = smoothstep(0.08, 0.6, r.y);
	return vec2(0.42 * below + horizon + 0.5 * zenith, zenith);
}

// Gold lit as polished metal seen from `eye` on a face with normal n (kit_golden's golden_metal, which
// the solid kit uses, without its towers and glint): bright where it reflects the afterglow, a greyed
// bronze where it reflects the street (the shadows lose their hue so the tonemapper can't push them
// toward orange), cooled by the blue sky above, champagne at its brightest. Linear.
vec3 gold_at(vec3 n, vec3 eye, float polish) {
	vec2 seen = dusk_seen(reflect(-eye, n));
	float env = 0.64 + polish * (seen.x - 0.5) * 1.1;
	vec3 dark = mix(gold_color, vec3(dot(gold_color, vec3(0.3, 0.55, 0.15))), 0.25) * 0.5;
	vec3 col = mix(dark, gold_color * 1.08, clamp(env, 0.0, 1.0)) * mix(vec3(1.0), vec3(0.92, 0.95, 1.05), seen.y * polish * 0.5);
	return to_linear(mix(col, shine_color, clamp(max(env - 0.95, 0.0) * 2.0, 0.0, 0.6)));
}

// Glass that mirrors the dusk: its tint, dark where it reflects the street or the deep sky, bright
// where it reflects the afterglow. Linear.
vec3 mirror_at(vec3 tint, vec3 n, vec3 eye, float y) {
	vec2 seen = dusk_seen(reflect(-eye, n));
	return to_linear(tint) * light_k3((0.25 + 0.75 * seen.x) * mix(vec3(1.0), vec3(0.8, 0.88, 1.1), seen.y)
		* (0.9 + 0.1 * smoothstep(0.0, 40.0, y)));
}

void fragment() {
	int style = int(UV2.x + 0.5);
	float seed = floor(UV2.y + 0.5);
	vec3 nv = flat_view_normal(VERTEX);
	vec3 n = (INV_VIEW_MATRIX * vec4(nv, 0.0)).xyz;
	vec3 eye = (INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz;
	vec2 uv = UV;
	// Pixel footprints are taken here, before any branch, and passed down (docs/ARCHITECTURE.md, Zone
	// skins: the kit's shader rules); never zero, so every smoothstep keeps two distinct edges.
	vec2 fw_m = max(fwidth(uv), vec2(1e-4));
	float aa = max(fw_m.x, fw_m.y);
	float fres = 1.0 - clamp(dot(nv, VIEW), 0.0, 1.0);
	vec3 albedo = to_linear(COLOR.rgb);
	float shade = 0.76 + 0.16 * max(n.z, 0.0) + 0.08 * max(n.y, 0.0);
	vec3 wall = albedo * (0.96 + 0.05 * value_noise(uv * vec2(0.5, 0.35) + seed));
	vec3 col = wall;
	vec3 gold = gold_at(n, eye, 0.75);
	float lit_by_flood = 1.0;

	if (style == 0) {
		// Polished granite slabs, a gold kick line along the top.
		vec2 q = uv / vec2(1.8, 0.9);
		vec2 qf = fw_m / vec2(1.8, 0.9);
		float joint = max(filtered_pulse(q.x, qf.x, 0.0, 0.01), filtered_pulse(q.y + 0.5, qf.y, 0.0, 0.02));
		col = to_linear(granite_color) * (0.9 + 0.14 * hash12(floor(q) + seed)) * (1.0 - 0.3 * joint);
		col *= 0.92 + 0.12 * value_noise(uv * 3.0 + seed);
		col = mix(col, gold, band(uv.y, plinth_top - 0.05, plinth_top + 1.0, fw_m.y));
		lit_by_flood = 0.0;
	} else if (style == 1) {
		int variant = int(mod(seed, 3.0));
		if (variant == 0) {
			// Rusticated stone: V-channels every 0.6 m, flush pilasters every bay with smooth faces.
			float bay = 3.6;
			float bx = fract(uv.x / bay) * bay;
			float pilaster = band(bx, 0.0, 0.62, fw_m.x);
			float channel = filtered_pulse(uv.y / 0.6, fw_m.y / 0.6, 0.0, 0.05) * (1.0 - pilaster);
			float block = filtered_pulse(uv.x / 1.8 + 0.5 * mod(floor(uv.y / 0.6), 2.0), fw_m.x / 1.8, 0.0, 0.012)
				* (1.0 - pilaster);
			col = wall * (1.0 - 0.28 * max(channel, block));
			col = mix(col, wall * 1.08, pilaster);
			// Fine fluting on the pilasters.
			col *= 1.0 - 0.1 * pilaster * filtered_pulse(bx / 0.155, fw_m.x / 0.155, 0.0, 0.4);
		} else if (variant == 1) {
			// Smooth polished ashlar: long blocks in staggered courses with hairline joints, a slim gold
			// pilaster line every two bays.
			vec2 q = (uv - vec2(0.0, plinth_top)) / vec2(2.4, 1.02);
			q.x += 0.5 * mod(floor(q.y), 2.0);
			vec2 qf = fw_m / vec2(2.4, 1.02);
			float joint = max(filtered_pulse(q.x, qf.x, 0.0, 0.006), filtered_pulse(q.y, qf.y, 0.0, 0.01));
			col = wall * (0.96 + 0.06 * hash12(floor(q) + seed * 1.7)) * (1.0 - 0.14 * joint);
			col += to_linear(sheen_color) * sheen_strength * fres * fres;
			float pin = filtered_pulse(uv.x / 7.2, fw_m.x / 7.2, 0.0, 0.012);
			col = mix(col, gold, pin);
		} else {
			// A blind arcade: flush arches in a lighter stone, their fields a shade darker.
			float bay = 4.2;
			vec2 lp = vec2((fract(uv.x / bay) - 0.5) * bay, uv.y - plinth_top);
			float hw = 1.45;
			float spring = band_top - plinth_top - 2.4;
			float d = lp.y < spring ? abs(lp.x) - hw : length(vec2(lp.x, lp.y - spring)) - hw;
			float field = 1.0 - smoothstep(-aa, aa, d);
			float rim = band(d, 0.0, 0.22, aa);
			col = mix(wall, wall * 0.9, field);
			col = mix(col, wall * 1.1, rim);
		}
		// The wall-run height marks, and a gold line along the band's top.
		float marks = max(band(uv.y, mark_a - 0.025, mark_a + 0.025, fw_m.y), band(uv.y, mark_b - 0.025, mark_b + 0.025, fw_m.y));
		col = mix(col, to_linear(mark_color), marks);
		col = mix(col, gold, band(uv.y, band_top - 0.08, band_top + 1.0, fw_m.y));
		// Soft grime at the foot, kept faint (the elite's streets are clean).
		col *= 1.0 - 0.1 * (1.0 - smoothstep(plinth_top, plinth_top + 0.6, uv.y));
		lit_by_flood = 0.0;
	} else if (style == 2) {
		// Cream mouldings round a gold frieze of fluting.
		float h = frieze_top - band_top;
		float t = (uv.y - band_top) / h;
		float frieze = band(t, 0.3, 0.72, fw_m.y / h);
		float flute = filtered_pulse(uv.x / 0.3, fw_m.x / 0.3, 0.0, 0.35);
		col = wall * 1.04 * (1.0 - 0.18 * band(t, 0.26, 0.3, fw_m.y / h) - 0.18 * band(t, 0.72, 0.76, fw_m.y / h));
		col = mix(col, gold * (1.0 - 0.3 * flute), frieze);
		lit_by_flood = 0.6;
	} else if (style == 3) {
		float cw = mod(seed, 4.0) < 1.0 ? 3.0 : (mod(seed, 4.0) < 2.0 ? 3.4 : (mod(seed, 4.0) < 3.0 ? 2.8 : 3.8));
		vec2 p = vec2(uv.x / cw, (uv.y - frieze_top) / storey);
		vec2 cell = floor(p);
		vec2 fp = fract(p);
		vec2 fw = fw_m / vec2(cw, storey);
		float k = hash12(cell * vec2(1.7, 2.3) + seed * 5.0);
		// Cladding: large panels, fine joints; a gold slab band along each storey's floor.
		vec2 pan = p * vec2(2.0, 1.0);
		float jx = filtered_pulse(pan.x, fw.x * 2.0, 0.0, 0.02 / cw);
		col *= (0.96 + 0.05 * hash12(floor(pan) + seed * 3.1)) * (1.0 - 0.2 * jx);
		float slab = filtered_pulse(p.y, fw.y, 0.0, 0.16 / storey);
		col = mix(col, gold, slab);
		col *= 1.0 - 0.25 * filtered_pulse(p.y, fw.y, 1.0 - 0.05 / storey, 1.0);
		// Tall rounded windows in thin gold frames.
		vec2 wc = vec2((fp.x - 0.5) * cw, (fp.y - 0.54) * storey);
		vec2 half_size = vec2(min(0.72, cw * 0.24), 1.18);
		float d = sd_round_box(wc, half_size, 0.34);
		float in_win = 1.0 - smoothstep(-aa, aa, d);
		float in_frame = 1.0 - smoothstep(0.06 - aa, 0.06 + aa, d);
		vec2 wp = (wc + half_size) / (half_size * 2.0);
		float lamp = step(hash12(cell * 3.3 + seed), COLOR.a);
		vec3 sky = to_linear(sheen_color) * light_k(sheen_strength * (0.4 + 0.6 * fres * fres));
		vec3 dark = to_linear(glass_color) + sky * light_k(1.5) + to_linear(sheen_color) * light_k(0.06 * smoothstep(0.35, 0.65,
			fract(wp.x * 0.7 - wp.y * 0.45 + k)));
		vec3 room = to_linear(window_warm) * light_k(window_glow * (0.4 + 0.35 * wp.y));
		// Red velvet drapes gathered at the sides of half the rooms (the zone's red accent, unlit).
		float fwp = fw_m.x / (half_size.x * 2.0);
		float drapes = step(0.5, hash12(cell * 1.9 + seed * 2.0))
			* (1.0 - smoothstep(0.14 - fwp, 0.14 + fwp, min(wp.x, 1.0 - wp.x) - 0.05 * wp.y));
		room = mix(room, to_linear(drape_color) * light_k(0.5 + 0.4 * wp.y), drapes);
		vec3 mirror = mirror_at(mirror_color, n, eye, uv.y);
		vec3 glass = k < 0.55 ? mix(dark, room, lamp) : (k < 0.82 ? mirror : dark);
		// A slim gold transom across each window.
		glass = mix(glass, gold, band(wp.y, 0.64, 0.67, fw.y * storey / (half_size.y * 2.0)));
		col = mix(col, gold, in_frame - in_win);
		col = mix(col, glass, in_win);
		lit_by_flood = 1.0 - in_win;
	} else if (style == 4) {
		// Champagne mirror glass on gold mullions, cream spandrels at every floor.
		vec2 p = vec2(uv.x / 1.5, (uv.y - frieze_top) / storey);
		vec2 fw = fw_m / vec2(1.5, storey);
		float mullion = filtered_pulse(p.x + 0.04, fw.x, 0.0, 0.08);
		float spandrel = filtered_pulse(p.y, fw.y, 0.0, 0.62 / storey);
		float k = hash12(floor(p) * vec2(1.3, 2.9) + seed);
		vec3 glass = mirror_at(mirror_color, n, eye, uv.y) * (0.94 + 0.12 * hash11(floor(p.x) * 0.7 + seed));
		float lamp = step(k, COLOR.a * 0.6);
		glass = mix(glass, to_linear(window_warm) * light_k(window_glow * 0.6), lamp * 0.8);
		col = mix(glass, wall, spandrel);
		col = mix(col, gold, mullion);
		lit_by_flood = spandrel;
	} else if (style == 5) {
		// Gold ribs over warm-lit glass.
		float rib = filtered_pulse(uv.x / 0.9, fw_m.x / 0.9, 0.0, 0.22);
		float ring = filtered_pulse(uv.y / 2.4, fw_m.y / 2.4, 0.0, 0.08);
		vec3 lit = to_linear(window_warm) * light_k(window_glow * (0.5 + 0.2 * value_noise(uv * 0.5 + seed)));
		col = mix(lit, gold, max(rib, ring));
		lit_by_flood = max(rib, ring);
	} else {
		// Below the walkways: deep shade, darker toward the canal, and the waterline. No lamp or
		// floodlight reaches it: it only darkens.
		float depth = mix(1.0, 0.25, smoothstep(-0.1, canal_y + 0.5, uv.y));
		float waterline = band(uv.y, canal_y, canal_y + 0.45, fw_m.y);
		col = albedo * light_k(depth * (0.9 + 0.1 * value_noise(uv * 0.8 + seed)) * (1.0 - 0.3 * waterline));
	}

	if (style != 6) {
		// The light, as one linear factor: the street's warm lamps on the band; above the entablature
		// the floodlights wash the floors from below, strongest just over it, fading up into the dusk,
		// whose cool light tints the tops. light_k3() makes it the same brightness on both renderers.
		float y = uv.y;
		float flood = exp(-max(y - frieze_top, 0.0) / max(flood_reach, 0.1));
		float street = y < band_top ? mix(street_low, street_high, smoothstep(0.0, band_top, y)) : mix(0.5, street_high + 0.12, flood);
		vec3 light = vec3(shade * street)
			+ light_color(flood_color) * (flood_strength * flood * lit_by_flood * step(band_top, y));
		light *= mix(vec3(1.0), dusk_tint, smoothstep(14.0, 60.0, y));
		col *= light_k3(light);
	}
	ALBEDO = col;
}

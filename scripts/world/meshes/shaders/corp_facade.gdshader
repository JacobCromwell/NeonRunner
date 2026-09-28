// Corporate building faces (CorporateSkin, CorporateTowers): a more oppressive Blade Runner (GDD §5),
// plainly corporate and in the same future as every zone: glass curtain walls in a sterile mullion
// grid with whole office floors lit cold white, towers of vertical fins, sterile cladding through the
// wall-run band, and the military's prefab blast walls. No window geometry: a face is a handful of
// quads, and windows, fins and panels are box-filtered, so far away they fade to the face's average.
//   UV     x metres along the face, y world height (metres)
//   UV2    x = style (below), y = seed (whole number)
//   COLOR  rgb = the face's colour (sRGB: mullions and spandrels, fins, cladding, paint), a = the share
//          of lit windows
// Styles:
//   0 CURTAIN  a glass curtain wall: dark glass catching the sky in a grid of steel mullions, a
//              spandrel at every floor, offices lit cold white a block at a time.
//   1 FINS     vertical fins over deep, narrow windows (the fins close up at grazing angles).
//   2 PODIUM   the calm band a runner runs across: dark cladding panels between brushed steel pilasters
//              every 3 m, a steel fascia under the cornice, and on some buildings a lobby of dark smoked
//              glass. Never lit.
//   3 BLAST    the military's prefab concrete T-walls: segments with dark joints, olive and grey
//              paint, stencilled codes, grime at the foot.
//   4 SERVICE  louvred plant floors (only high up: at the foot of a wall louvres would read as vents,
//              which are sewer-screech lairs, GDD §9.5).
// Cold floodlights sit along the top of the calm band (flood_height, every flood_spacing metres) and
// wash the faces above in pools of sterile white light.
shader_type spatial;
render_mode unshaded, cull_back;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"
#include "res://scripts/world/meshes/shaders/kit_flash.gdshaderinc"
#include "res://scripts/world/meshes/shaders/kit_marks.gdshaderinc"

// A level's darker lighting (ZoneSkin.apply_darkness): the faces dim with the rest of the scenery.
global uniform float scenery_light;
uniform vec3 window_cold : source_color = vec3(0.78, 0.86, 0.98);
uniform float window_glow = 0.9;
uniform vec3 glass_color : source_color = vec3(0.03, 0.035, 0.045);
uniform vec3 sheen_color : source_color = vec3(0.3, 0.34, 0.42);
uniform float sheen_strength = 0.3;
// The curtain walls' storeys start at storey_base (the calm band's top).
uniform float storey_base = 7.2;
uniform float storey = 3.6;
// Below this height no window is lit and nothing glows (the wall-run band stays calm).
uniform float calm_top = 7.2;
// The military's paint on the blast walls, and the stencils on them.
uniform vec3 blast_a : source_color = vec3(0.3, 0.31, 0.22);
uniform vec3 blast_b : source_color = vec3(0.35, 0.36, 0.3);
uniform vec3 blast_c : source_color = vec3(0.4, 0.41, 0.42);
uniform vec3 stencil_color : source_color = vec3(0.74, 0.74, 0.7);
uniform vec3 grime_color : source_color = vec3(0.08, 0.085, 0.09);
uniform float grime = 1.0;
// The podium's steel: pilasters, fascia, kick plate.
uniform vec3 pilaster_color : source_color = vec3(0.34, 0.36, 0.39);
// The floodlights' cold wash: its colour, strength, the lamps' height and spacing, and how far up it
// reaches.
uniform vec3 flood_color : source_color = vec3(0.86, 0.92, 1.0);
uniform float flood_strength = 0.4;
uniform float flood_height = 7.5;
uniform float flood_spacing = 8.0;
uniform float flood_reach = 11.0;

// Grime rising from the foot of a face and rain streaks running down it (linear colour in and out).
vec3 weather(vec3 col, vec2 uv, float foot, float seed) {
	float rise = 1.0 - smoothstep(0.0, 0.5 + 0.4 * value_noise(vec2(uv.x * 1.3, seed)), uv.y - foot);
	col = mix(col, to_linear(grime_color), rise * 0.35 * grime);
	float streak = smoothstep(0.6, 0.92, value_noise(vec2(uv.x * 3.1, uv.y * 0.12 + seed)));
	return col * (1.0 - 0.14 * streak * grime) * (0.96 + 0.06 * value_noise(uv * 1.3 + seed));
}

void fragment() {
	int style = int(UV2.x + 0.5);
	// Interpolated attributes aren't bit-exact across a triangle, and hashes amplify any difference:
	// seeds are whole numbers, rounded here before hashing.
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
	float shade = 0.72 + 0.2 * max(n.z, 0.0) + 0.08 * max(n.y, 0.0);
	vec3 sky = to_linear(sheen_color) * sheen_strength * (0.35 + 0.65 * fres * fres);
	vec3 col = albedo;
	// How much of the face is opaque and takes the floodlights' wash (glass and lit rooms don't).
	float opaque = 1.0;
	float far = 0.0;
	vec3 average = albedo * 0.6;

	if (style == 0) {
		vec2 p = vec2(uv.x / 1.5, (uv.y - storey_base) / storey);
		vec2 cell = floor(p);
		vec2 fp = fract(p);
		vec2 fw = fw_m / vec2(1.5, storey);
		float mullion = filtered_pulse(p.x, fw.x, 0.0, 0.05);
		float spandrel = filtered_pulse(p.y, fw.y, 0.0, 0.24);
		// Offices light up six bays at a time, floor by floor: cold, even, sterile.
		float block = floor(cell.x / 6.0);
		float lit = step(hash12(vec2(block, cell.y) + seed * 13.0), COLOR.a) * step(calm_top, cell.y * storey + storey_base);
		float grad = 0.5 + 0.5 * smoothstep(0.24, 1.0, fp.y);
		float desks = band(fp.y, 0.34, 0.46, fw.y) * 0.35;
		vec3 room = to_linear(window_cold) * window_glow * grad * (0.8 + 0.3 * hash12(cell * 1.7 + seed)) * (1.0 - desks);
		vec3 glass = to_linear(glass_color) + sky * 1.3;
		// At grazing angles the glass mirrors the sky and hides the rooms behind it.
		float seen = 1.0 - 0.75 * fres * fres * fres * fres;
		vec3 win = mix(glass, room, lit * seen);
		vec3 span = albedo * 0.5 + sky * 0.6;
		col = mix(win, span, spandrel);
		col = mix(col, albedo, mullion);
		opaque = max(spandrel, mullion);
		far = smoothstep(0.1, 0.4, max(fw.x, fw.y));
		average = mix(glass, to_linear(window_cold) * (window_glow * 0.45), COLOR.a * seen);
		average = mix(average, albedo * 0.55, 0.3);
	} else if (style == 1) {
		float fx = uv.x / 1.2;
		vec2 fw = fw_m / vec2(1.2, storey);
		// The fins close up the view at grazing angles.
		float fin_w = mix(0.36, 0.82, smoothstep(0.35, 0.92, fres));
		float fin = filtered_pulse(fx, fw.x, 0.0, fin_w);
		float row = (uv.y - storey_base) / storey;
		float slab = filtered_pulse(row, fw.y, 0.0, 0.07);
		vec2 cell = vec2(floor(fx), floor(row));
		float lit = step(hash12(vec2(floor(cell.x / 4.0), cell.y) + seed * 7.0), COLOR.a) * step(calm_top, cell.y * storey + storey_base);
		vec3 room = to_linear(window_cold) * window_glow * 0.75 * (0.5 + 0.5 * fract(row));
		vec3 win = mix(to_linear(glass_color) + sky, room, lit);
		float across = clamp(fract(fx) / fin_w, 0.0, 1.0);
		vec3 fin_col = albedo * (0.78 + 0.3 * across) * (0.94 + 0.08 * value_noise(vec2(cell.x * 3.1, uv.y * 0.2)));
		col = mix(win, fin_col, fin);
		col = mix(col, albedo * 0.72, slab);
		opaque = max(fin, slab);
		far = smoothstep(0.12, 0.45, max(fw.x, fw.y));
		average = mix(to_linear(glass_color) + sky, to_linear(window_cold) * (window_glow * 0.35), COLOR.a);
		average = mix(average, albedo * 0.85, fin_w);
		col = weather(col, uv, storey_base, seed);
	} else if (style == 2) {
		// Dark cladding panels between steel pilasters every 3 m (the band's rhythm as it streams
		// past), a groove at 3.6 m, a steel fascia under the cornice and a kick plate at the foot.
		vec3 steel = to_linear(pilaster_color);
		vec2 q = uv / vec2(3.0, 1.8);
		vec2 fq = fw_m / vec2(3.0, 1.8);
		float joint = filtered_pulse(q.y, fq.y, 0.0, 0.02);
		col = albedo * (0.9 + 0.12 * hash12(floor(q) + seed)) * (1.0 - 0.4 * joint);
		col *= 0.92 + 0.1 * value_noise(vec2(uv.x * 0.6, uv.y * 0.9) + seed);
		if (hash11(seed * 1.7 + 0.3) < 0.45) {
			// A lobby of dark smoked glass in slim steel frames, a faint cold light deep inside.
			float g = band(uv.y, 0.6, calm_top - 1.2, fw_m.y);
			float frame = filtered_pulse(uv.x / 1.5, fw_m.x / 1.5, 0.0, 0.03);
			float inside = band(fract(uv.y / 2.4), 0.8, 0.86, fw_m.y / 2.4) * 0.35;
			vec3 smoked = to_linear(glass_color) * 1.3 + sky * 1.2 + to_linear(window_cold) * inside * 0.08;
			col = mix(col, mix(smoked, albedo * 0.8, frame), g);
		}
		col *= 1.0 - 0.45 * band(uv.y, 3.56, 3.62, fw_m.y);
		// Pilasters: brushed steel, a shadow line down each side.
		float px = fract(uv.x / 3.0) * 3.0;
		float pil = band(px, 0.0, 0.34, fw_m.x);
		float edge = band(px, 0.34, 0.39, fw_m.x) + band(px, 2.95, 3.0, fw_m.x);
		vec3 pil_col = steel * (0.9 + 0.1 * value_noise(vec2(uv.x * 12.0, uv.y * 0.4)));
		col = mix(col, pil_col, pil);
		col *= 1.0 - 0.5 * edge;
		col = mix(col, steel * 0.9, band(uv.y, calm_top - 1.2, calm_top, fw_m.y));
		col = mix(col, steel * 0.55, band(uv.y, -1.0, 0.6, fw_m.y));
		col = weather(col, uv, 0.0, seed);
		opaque = 0.0;
		far = smoothstep(0.2, 0.6, aa);
		average = mix(albedo * 0.9, steel, 0.12);
	} else if (style == 3) {
		float sx = uv.x / 1.52;
		float seg = floor(sx);
		float joint = filtered_pulse(sx, fw_m.x / 1.52, 0.0, 0.03);
		float r = hash11(seg * 1.7 + seed);
		vec3 paint = r < 0.45 ? blast_a : (r < 0.8 ? blast_b : blast_c);
		col = to_linear(paint) * (0.88 + 0.14 * hash11(seg * 3.1 + seed));
		// The footing's step at 0.6 m and a lifting slot near the top.
		col *= 1.0 - 0.3 * band(uv.y, 0.56, 0.63, fw_m.y);
		float code_on = step(0.55, hash11(seg * 5.3 + seed));
		vec2 cp = vec2(uv.x - (seg + 0.5) * 1.52, uv.y - 2.7);
		float mark = stencil_code(cp, 0.45, seg + seed, aa) * code_on;
		col = mix(col, to_linear(stencil_color) * 0.8, mark * 0.85);
		col = weather(col, uv, 0.0, seed + seg);
		col *= 1.0 - 0.55 * joint;
		opaque = 0.0;
		far = smoothstep(0.2, 0.6, aa);
		average = to_linear(mix(blast_a, blast_b, 0.5)) * 0.85;
	} else {
		float l = filtered_pulse(uv.y / 0.24, fw_m.y / 0.24, 0.0, 0.55);
		float div = filtered_pulse(uv.x / 3.0, fw_m.x / 3.0, 0.0, 0.04);
		col = albedo * (0.62 + 0.32 * l) * (1.0 - 0.4 * div);
		far = smoothstep(0.1, 0.4, aa);
		average = albedo * 0.78;
	}
	col = mix(col, average, far);
	col *= shade;
	// The floodlights' cold wash above the calm band, in pools around each lamp.
	float up = uv.y - flood_height;
	float pool = 0.55 + 0.45 * cos((fract(uv.x / flood_spacing) - 0.5) * 6.2832);
	float wash = smoothstep(0.0, 1.0, up) * exp(-max(up, 0.0) / flood_reach) * pool;
	col += albedo * to_linear(flood_color) * (flood_strength * wash * mix(0.35, 1.0, opaque));
	ALBEDO = col * light_factor(scenery_light);
}

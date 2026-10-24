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
// The backdrop's layers (the owner's reference image: a militarised street under corporate towers under the
// elites' mansions; docs/architecture/skins-marketplace-corporate-deadzone-casino.md, The Corporate zone):
//   5 MIL_PLATE  the military's armour-plate wall at street level: olive plates in framed panels, a precast
//              skirt like a jersey barrier's at the foot, cable runs, unit stencils. COLOR = the plate olive.
//   6 MIL_CAMO   stacked precast blocks, chamfered, under camouflage; COLOR = the plain concrete's tone and
//              COLOR.a = how much of the stack is camouflaged (1) or bare precast (0).
//   7 MIL_GATE   the plate wall with heavy steel gates in it, painted flush.
//   8 MIL_UPPER  the military building's upper storeys: plates, rows of slit windows (a few dimly lit cold
//              white), vertical pipes. COLOR.a = the share of lit slits.
//   9 MANSION    an elite's mansion: ivory stone in warm light, columns, tall arched windows lit warm,
//              balustrades and a cornice on every storey. COLOR = the stone, COLOR.a = the share of lit rooms.
// Everything the military layer draws is flush paint (nothing sticks out through the wall-run band).
// Cold floodlights sit along the top of the calm band (flood_height, every flood_spacing metres) and
// wash the faces above in pools of sterile white light.
shader_type spatial;
render_mode unshaded, cull_back;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"
#include "res://scripts/world/meshes/shaders/kit_flash.gdshaderinc"
#include "res://scripts/world/meshes/shaders/kit_marks.gdshaderinc"

// A level's darker lighting (ZoneSkin.apply_darkness): the faces dim with the rest of the scenery.
global uniform float scenery_light;
// The street's light under a level's own sky (ZoneSkin.set_scenery_tint; white = the zone's own).
global uniform vec3 scenery_tint;
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
// The military layer's camouflage (three tones) on the bunkers' blocks (styles 6).
uniform vec3 camo_a : source_color = vec3(0.27, 0.285, 0.2);
uniform vec3 camo_b : source_color = vec3(0.4, 0.38, 0.28);
uniform vec3 camo_c : source_color = vec3(0.18, 0.19, 0.15);
// The elites' mansions (style 9): the warm light in their rooms (a champagne white: desaturated, so it never
// competes with a hazard's yellow or orange) and how brightly their rooms are lit.
uniform vec3 mansion_light : source_color = vec3(1.0, 0.88, 0.7);
uniform float mansion_glow = 1.0;
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

// The armour-plate wall's panels (styles 5, 7 and 8): plates of the face's olive in 3.2 x 1.8 m panels, each with an
// inset frame, a bevel and a row of rivets top and bottom. `detail` fades the fine marks out with distance.
vec3 plate_panels(vec3 albedo, vec2 uv, vec2 fw_m, float seed, float detail) {
	vec2 pq = uv / vec2(3.2, 1.8);
	vec2 fq = fw_m / vec2(3.2, 1.8);
	vec2 cell = floor(pq);
	vec2 f = fract(pq);
	vec3 col = albedo * (0.8 + 0.3 * hash12(cell + seed));
	// Some panels repainted in a khaki that never quite matched.
	col = mix(col, to_linear(camo_b) * 0.78, step(0.86, hash12(cell + seed + 17.0)) * 0.7);
	float inner = band(f.x, 0.04, 0.96, fq.x) * band(f.y, 0.07, 0.93, fq.y);
	col *= 0.9 + 0.12 * inner;
	col *= 1.0 + 0.1 * band(f.y, 0.86, 0.93, fq.y) - 0.16 * band(f.y, 0.07, 0.13, fq.y);
	float seam = max(filtered_pulse(pq.x, fq.x, 0.0, 0.02), filtered_pulse(pq.y, fq.y, 0.0, 0.025));
	col *= 1.0 - 0.5 * seam;
	vec2 rp = vec2((fract(uv.x / 0.4) - 0.5) * 0.4, abs((f.y - 0.5) * 1.8) - 0.62);
	col *= 1.0 - 0.3 * step(length(rp), 0.04) * detail;
	col *= 0.93 + 0.1 * value_noise(uv * vec2(0.5, 0.8) + seed);
	return col;
}

// The street-level armour wall (style 5, and with `gate` 1 style 7): the plates, a precast skirt at the foot (a jersey
// barrier's profile in three bands), cable runs at 5.2 m, unit stencils and data plates, a dark fascia under the
// cornice and, on style 7, steel gates every 13 m. Flat paint all the way: nothing here sticks out of the wall.
vec3 mil_plate(vec3 albedo, vec2 uv, vec2 fw_m, float seed, float aa, float gate) {
	float detail = 1.0 - smoothstep(0.03, 0.14, aa);
	vec3 col = plate_panels(albedo, uv, fw_m, seed, detail);
	vec2 cell = floor(uv / vec2(3.2, 1.8));
	vec3 steel = to_linear(pilaster_color);
	// Cable runs along the wall, held by brackets every 1.6 m.
	vec3 tray = steel * 0.7 * (0.85 + 0.3 * band(uv.y, 5.36, 5.42, fw_m.y));
	tray *= 1.0 - 0.35 * filtered_pulse(uv.x / 1.6, fw_m.x / 1.6, 0.0, 0.07);
	col = mix(col, tray, band(uv.y, 5.18, 5.46, fw_m.y));
	col = mix(col, steel * 0.42, band(uv.y, 5.56, 5.68, fw_m.y));
	// Vertical conduits every 9.6 m, collared every 1.2 m, running from the skirt to the fascia.
	float vx = mod(uv.x + seed * 2.9, 9.6);
	vec3 conduit = steel * 0.5 * (0.65 + 0.75 * sin(clamp(vx / 0.24, 0.0, 1.0) * 3.14159));
	conduit *= 1.0 - 0.4 * filtered_pulse(uv.y / 1.2, fw_m.y / 1.2, 0.0, 0.05);
	col = mix(col, conduit, band(vx, 0.0, 0.24, fw_m.x) * band(uv.y, 1.0, 6.5, fw_m.y));
	// A unit code, stencilled pale, on some panels; a data plate by others.
	float code_on = step(0.62, hash12(cell + seed + 3.0));
	float mark = stencil_code(vec2(uv.x - (cell.x + 0.5) * 3.2, uv.y - 3.7), 0.6, cell.x + seed, aa) * code_on;
	col = mix(col, to_linear(stencil_color) * 0.78, mark * 0.85);
	float plate_on = step(0.7, hash12(cell + seed + 9.0)) * (1.0 - code_on);
	vec2 pp = vec2(uv.x - (cell.x + 0.78) * 3.2, uv.y - (cell.y + 0.5) * 1.8);
	col = mix(col, to_linear(stencil_color) * 0.7, band(pp.x, -0.28, 0.28, fw_m.x) * band(pp.y, -0.17, 0.17, fw_m.y) * plate_on * 0.8);
	col = mix(col, steel * 0.3, band(pp.x, -0.2, 0.2, fw_m.x) * band(abs(pp.y), 0.03, 0.06, fw_m.y) * plate_on);
	// The precast skirt: lighter toward the top like a sloped barrier's face, a lip, joints every 3.2 m.
	vec3 conc = to_linear(pilaster_color) * (0.92 + 0.15 * value_noise(uv * vec2(1.5, 3.0) + seed));
	conc *= 0.74 + 0.4 * smoothstep(0.0, 1.1, uv.y);
	conc *= 1.0 - 0.5 * filtered_pulse(uv.x / 3.2, fw_m.x / 3.2, 0.0, 0.02);
	col = mix(col, conc, band(uv.y, -1.0, 1.1, fw_m.y));
	col = mix(col, conc * 1.2, band(uv.y, 1.02, 1.1, fw_m.y));
	// The fascia under the cornice.
	col = mix(col, albedo * 0.68, band(uv.y, 6.45, 7.3, fw_m.y));
	col *= 1.0 + 0.25 * band(uv.y, 6.43, 6.49, fw_m.y);
	if (gate > 0.5) {
		float gx = mod(uv.x + seed * 1.7, 13.0) - 6.5;
		float frame = band(abs(gx), 0.0, 2.65, fw_m.x) * band(uv.y, -1.0, 5.65, fw_m.y);
		float leaf = band(abs(gx), 0.0, 2.3, fw_m.x) * band(uv.y, -1.0, 5.25, fw_m.y);
		vec3 door = albedo * 1.1 * (1.0 - 0.3 * filtered_pulse(gx / 0.3 + 0.5, fw_m.x / 0.3, 0.0, 0.07));
		door *= 1.0 - 0.75 * band(abs(gx), 0.0, 0.05, fw_m.x);
		float strap = max(band(uv.y, 1.1, 1.3, fw_m.y), max(band(uv.y, 2.6, 2.8, fw_m.y), band(uv.y, 4.1, 4.3, fw_m.y)));
		door = mix(door, steel * 0.5, strap * 0.85);
		// A hinge plate at each side of each strap and a lock plate at the split.
		door = mix(door, steel * 0.35, band(abs(gx), 1.9, 2.25, fw_m.x) * strap);
		col = mix(col, steel * 0.62, frame);
		col = mix(col, door, leaf);
		col = mix(col, steel * 0.45, band(uv.y, 5.25, 5.65, fw_m.y) * band(abs(gx), 0.0, 2.65, fw_m.x));
	}
	return weather(col, uv, 0.0, seed);
}

// The bunkers' stacked blocks (style 6): 2.4 x 1.2 m precast blocks in running bond, chamfered top and sides, under
// camouflage (three tones in soft blotches, painted over the whole stack) by `camo` (1) or bare precast (0), some with
// a pale stencilled number.
vec3 mil_camo(vec3 concrete, float camo, vec2 uv, vec2 fw_m, float seed, float aa) {
	float row = floor(uv.y / 1.2);
	float shift = mod(row, 2.0) * 1.2 + hash11(seed * 1.3) * 2.4;
	vec2 bq = vec2((uv.x + shift) / 2.4, uv.y / 1.2);
	vec2 fb = fw_m / vec2(2.4, 1.2);
	vec2 bf = fract(bq);
	float n1 = value_noise(uv * vec2(0.38, 0.5) + seed * 3.1);
	float n2 = value_noise(uv * vec2(0.8, 1.0) + seed * 7.7 + 11.0);
	float n3 = value_noise(uv * vec2(1.7, 2.1) + seed * 1.9 + 3.0);
	vec3 c = to_linear(camo_a);
	c = mix(c, to_linear(camo_b), smoothstep(0.47, 0.52, n1));
	c = mix(c, to_linear(camo_c), smoothstep(0.55, 0.6, n2));
	c = mix(c, to_linear(camo_b) * 0.82, smoothstep(0.62, 0.66, n3) * 0.6);
	vec3 plain = to_linear(concrete) * (0.86 + 0.2 * n3);
	vec3 col = mix(plain, c, camo);
	col *= 1.0 + 0.16 * band(bf.y, 0.84, 0.93, fb.y) - 0.22 * band(bf.y, 0.07, 0.16, fb.y);
	col *= 1.0 + 0.08 * band(bf.x, 0.04, 0.1, fb.x) - 0.12 * band(bf.x, 0.9, 0.96, fb.x);
	float joint = max(filtered_pulse(bq.x, fb.x, 0.0, 0.025), filtered_pulse(bq.y, fb.y, 0.0, 0.045));
	col *= 1.0 - 0.55 * joint;
	float num_on = step(0.86, hash12(vec2(floor(bq.x), row) + seed * 5.0));
	vec2 np = vec2(uv.x + shift - (floor(bq.x) + 0.5) * 2.4, uv.y - (row + 0.5) * 1.2);
	col = mix(col, to_linear(stencil_color) * 0.8, stencil_code(np, 0.5, floor(bq.x) + row + seed, aa) * num_on * 0.8);
	return weather(col, uv, 0.0, seed);
}

// A military building's upper storeys (style 8): the plates of the wall below, a row of dark slit windows on every
// 3.6 m storey (a share dimly lit cold white), and vertical pipes every 6.4 m with brackets.
vec3 mil_upper(vec3 albedo, float lit_share, vec2 uv, vec2 fw_m, float seed, float aa) {
	float detail = 1.0 - smoothstep(0.03, 0.14, aa);
	vec3 col = plate_panels(albedo, uv, fw_m, seed, detail);
	float sy = (uv.y - storey_base) / 3.6;
	vec2 sf = vec2(fract(uv.x / 2.4), fract(sy));
	vec2 sw = fw_m / vec2(2.4, 3.6);
	float slit = band(sf.x, 0.2, 0.8, sw.x) * band(sf.y, 0.52, 0.66, sw.y);
	vec2 sc = vec2(floor(uv.x / 2.4), floor(sy));
	float lit = step(hash12(sc + seed * 3.0), lit_share);
	vec3 room = to_linear(window_cold) * window_glow * 0.5;
	vec3 slit_col = mix(vec3(0.02, 0.025, 0.03), room, lit);
	float frame = band(sf.x, 0.15, 0.85, sw.x) * band(sf.y, 0.47, 0.71, sw.y);
	col = mix(col, albedo * 0.45, frame);
	col = mix(col, slit_col, slit);
	float px = mod(uv.x + seed * 2.3, 6.4);
	float pipe = band(px, 0.0, 0.28, fw_m.x);
	vec3 pipe_col = to_linear(pilaster_color) * 0.5 * (0.7 + 0.7 * sin(clamp(px / 0.28, 0.0, 1.0) * 3.14159));
	pipe_col *= 1.0 - 0.4 * filtered_pulse(uv.y / 1.8, fw_m.y / 1.8, 0.0, 0.05);
	col = mix(col, pipe_col, pipe);
	return weather(col, uv, storey_base, seed);
}

// An elite's mansion (style 9): ivory stone under warm light, paired columns every 3.6 m, tall arched windows lit warm
// (some rooms dark), a balustrade along the foot of every storey and a cornice with dentils at its head. `emit` returns
// the rooms' own light (not dimmed by the face's shading), `opaque` how much of the face is stone.
vec3 mansion_face(vec3 stone, float lit_share, vec2 uv, vec2 fw_m, float seed, out vec3 emit, out float opaque) {
	vec2 fw = fw_m / vec2(3.6, storey);
	float fl = (uv.y - storey_base) / storey;
	float fy = fract(fl);
	float cx = uv.x / 3.6;
	float fx = fract(cx);
	vec2 cell = vec2(floor(cx), floor(fl));
	vec3 warm = to_linear(mansion_light);
	// Stone, warmed by the light from the rooms and by the uplights at its foot.
	vec3 wall = stone * (0.9 + 0.2 * value_noise(uv * vec2(0.7, 0.9) + seed));
	wall *= mix(vec3(1.0), warm * 1.15, 0.55);
	wall *= 0.85 + 0.35 * exp(-fy * 3.0);
	// Paired columns at the bay joints, wider at their foot and head.
	float cw = mix(0.07, 0.12, max(band(fy, 0.0, 0.06, fw.y), band(fy, 0.9, 1.0, fw.y)));
	float column = max(band(fx, 0.0, cw, fw.x), band(fx, 1.0 - cw, 1.0, fw.x));
	// The window: a rectangle with an arched head, in a stone frame; a mullion and a transom.
	float rect_part = band(abs(fx - 0.5), 0.0, 0.33, fw.x) * band(fy, 0.28, 0.62, fw.y);
	float arch = 1.0 - smoothstep(0.9, 1.0, length(vec2((fx - 0.5) / 0.33, (fy - 0.62) / 0.22)));
	float win = max(rect_part, arch * step(0.62, fy));
	float inner = band(abs(fx - 0.5), 0.0, 0.295, fw.x) * band(fy, 0.31, 0.62, fw.y);
	float arch_in = 1.0 - smoothstep(0.86, 0.96, length(vec2((fx - 0.5) / 0.295, (fy - 0.62) / 0.19)));
	float glass = max(inner, arch_in * step(0.62, fy));
	float bars = max(band(abs(fx - 0.5), 0.0, 0.014, fw.x), band(fy, 0.5, 0.52, fw.y)) * glass;
	float lit = step(hash12(cell + seed * 11.0), lit_share);
	vec3 room = warm * (0.7 + 0.5 * smoothstep(0.3, 0.8, fy)) * mansion_glow;
	room *= 1.0 - 0.45 * smoothstep(0.12, 0.3, abs(fx - 0.5));
	room = mix(room * 0.12, room, lit);
	// The balustrade: a plinth and a rail with balusters between, the lit room dim behind it.
	float baluster_zone = band(fy, 0.0, 0.27, fw.y);
	float rail = max(band(fy, 0.21, 0.27, fw.y), band(fy, 0.0, 0.07, fw.y));
	float post = band(fract(uv.x / 0.3), 0.3, 0.7, fw_m.x / 0.3) * band(fy, 0.07, 0.21, fw.y);
	float stone_part = max(rail, post);
	// The cornice and its dentils.
	float cornice = band(fy, 0.9, 1.0, fw.y);
	float dentil = band(fy, 0.9, 0.95, fw.y) * step(0.5, fract(uv.x / 0.5));
	vec3 col = wall;
	col = mix(col, wall * 1.14, column);
	col = mix(col, wall * 1.1, cornice);
	col *= 1.0 - 0.3 * dentil;
	col = mix(col, wall * 1.18, win - glass);
	col = mix(col, wall * 0.3, baluster_zone * (1.0 - stone_part));
	col = mix(col, wall * 1.08, baluster_zone * stone_part);
	col = mix(col, vec3(0.03, 0.025, 0.02), glass);
	float rooms = glass * (1.0 - bars) * (1.0 - baluster_zone);
	emit = room * rooms + warm * 0.1 * baluster_zone * (1.0 - stone_part) * lit;
	opaque = 1.0 - rooms;
	col *= 1.0 - 0.35 * bars;
	return col;
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
	// Light the face itself gives off (a mansion's rooms), added after the street's shade and the flood wash.
	vec3 emit = vec3(0.0);
	vec3 emit_far = vec3(0.0);

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
		// CorporateDashWall hard-codes the seeds it wants a lobby (or none) for by this test, and DashWallKit.hash11
		// replicates the hash in GDScript: change this threshold, or the hash, with them (test_dash_walls checks).
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
	} else if (style == 5 || style == 7) {
		col = mil_plate(albedo, uv, fw_m, seed, aa, style == 7 ? 1.0 : 0.0);
		opaque = 0.0;
		far = smoothstep(0.2, 0.6, aa);
		average = albedo * 0.82;
	} else if (style == 6) {
		col = mil_camo(COLOR.rgb, COLOR.a, uv, fw_m, seed, aa);
		opaque = 0.0;
		far = smoothstep(0.2, 0.6, aa);
		average = mix(to_linear(COLOR.rgb), mix(to_linear(camo_a), to_linear(camo_b), 0.35), COLOR.a) * 0.85;
	} else if (style == 8) {
		col = mil_upper(albedo, COLOR.a, uv, fw_m, seed, aa);
		opaque = 0.5;
		far = smoothstep(0.2, 0.6, aa);
		average = albedo * 0.75;
	} else if (style == 9) {
		col = mansion_face(COLOR.rgb, COLOR.a, uv, fw_m, seed, emit, opaque);
		far = smoothstep(0.25, 0.8, aa);
		average = to_linear(COLOR.rgb) * mix(vec3(1.0), to_linear(mansion_light) * 1.15, 0.55) * 0.8;
		emit_far = to_linear(mansion_light) * mansion_glow * 0.3 * COLOR.a;
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
	col += mix(emit, emit_far, far);
	ALBEDO = col * light_factor(scenery_light) * scenery_tint;
}

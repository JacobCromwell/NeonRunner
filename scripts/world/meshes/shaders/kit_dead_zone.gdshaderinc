// Dead Zone surfaces for the solid kit shader (kit_solid.gdshader): pattern ids 40-49
// (MeshKit.PAT_DZ_*), in their own file so other zones' patterns never collide with them. The Dead
// Zone (DeadZoneSkin, GDD §5): a blackened, bombed-out husk of the city in dark black, dark grey and
// ash grey: rubble, embers, smoke and silence. Each function takes the fragment's world position `w`,
// world normal `n`, UV and the pattern parameter and returns the albedo (sRGB, like COLOR); the kit
// then lights it like any lit surface (and dims it with a level's scenery_light). Nothing here glows
// but the towers' rare embers: small, dim and high above the play field, never at a gap edge's
// brightness.
// Pixel footprints (fwidth) are taken at the top of each function, where every pixel of a face runs
// the same code, and passed down; no branch that differs between neighbouring pixels (a hash, a
// height) takes a derivative (docs/ARCHITECTURE.md, Zone skins: the kit's shader rules). The emblem's
// texture is read with explicit mip levels (cult_mark), so it is safe in any branch.
// Include after cult_mark() (PAT_DZ_MARK uses it), kit_marks.gdshaderinc (band()) and
// kit_flash.gdshaderinc (reduced_flashing).

// The skin sets every colour below as an sRGB Vector3 (DeadZoneSkin.srgb()), like vertex colours: a
// Color would arrive already linear on Forward+ but not on the Compatibility renderer.
// The pale ash lying over everything, and how much of the street it covers.
uniform vec3 dz_ash = vec3(0.46, 0.45, 0.43);
uniform float dz_ash_amount = 0.55;
// Soot, burnt rooms and the charred backs of dead boards.
uniform vec3 dz_soot = vec3(0.03, 0.03, 0.03);
uniform vec3 dz_board = vec3(0.07, 0.07, 0.075);
// Worn lane paint on the street, and the rubble scattered over it.
uniform vec3 dz_line = vec3(0.52, 0.52, 0.5);
uniform vec3 dz_rubble = vec3(0.36, 0.355, 0.35);
// Smoked glass left in the windows.
uniform vec3 dz_glass = vec3(0.06, 0.065, 0.072);
// The embers still smouldering in a few rooms high up (dim; never at the gap edge's brightness), the
// lowest they burn and the share of windows up there that do (on faces that smoulder at all).
uniform vec3 dz_ember = vec3(0.62, 0.24, 0.1);
uniform float dz_ember_height = 16.0;
uniform float dz_ember_share = 0.006;
// The calm band: below this height every tower face is flush, closed and solid-looking.
uniform float dz_band_top = 7.2;

// PAT_DZ_STREET (40): the rubble street. The road's surface has broken into plates (staggered rows,
// each plate its own tone, dark seams between them and cracks through some), a veil of pale ash lies
// over all of it, thicker in streaks the wind drew along the street and piled in the gutters, and
// charred chunks of rubble are scattered over the ash, drawn flat (an ashen top, a dark near side), so
// nothing on the running surface stands up like an obstacle, and nothing is round (in the Dead Zone a
// round cover is a sewer screech's manhole). Worn lane lines show here and there through the ash on
// the lane's edges (param 1 on its left, 2 on its right); param 4 marks a gutter against a wall. UV.x
// runs -1 to 1 across the lane. Its broad shading never darkens COLOR below 0.75 of it and the ash
// only lightens it, so the street's value carries the read of a hole beside it
// (tests/suites/test_dead_zone_skin.gd).
vec3 dz_street(vec3 base, vec3 w, vec2 uv, float param) {
	vec2 p = w.xz;
	vec2 fwp = max(fwidth(p), vec2(1e-4));
	float fu = max(fwidth(uv.x), 1e-4);
	float fpm = max(fwp.x, fwp.y);
	float detail = 1.0 - smoothstep(0.03, 0.2, fpm);
	int flags = int(param + 0.5);
	// The plates: rows 2.9 m along the track, staggered, 2.2 m across.
	vec2 q = p / vec2(2.2, 2.9);
	float row = floor(q.y);
	q.x += hash11(row * 3.7 + 1.0);
	vec2 cell = vec2(floor(q.x), row);
	vec2 fq = fwp / vec2(2.2, 2.9);
	float tone = 0.9 + 0.14 * hash12(cell + 5.0);
	float seam = max(filtered_pulse(q.x, fq.x, 0.0, 0.012), filtered_pulse(q.y, fq.y, 0.0, 0.01));
	// A crack across some plates, kinked once.
	vec2 f = fract(q) - 0.5;
	float kink = (hash12(cell + 9.0) - 0.5) * 0.6;
	float cx = f.x - kink - 0.35 * (f.y - 0.1) * sign(f.y - 0.1);
	float crack = band(cx, -0.006, 0.006, fq.x) * step(0.55, hash12(cell + 17.0));
	float line_dark = max(seam, crack);
	vec3 col = base * tone * (1.0 - 0.4 * line_dark);
	// Some plates heaved by the blasts: a paler raised edge on the far side, a darker one on the near
	// side (shading only: the running surface stays flat).
	float heaved = step(0.82, hash12(cell + 29.0));
	float far_edge = 1.0 - smoothstep(0.0, 0.08, f.y + 0.5);
	float near_edge = smoothstep(0.42, 0.5, f.y);
	col *= 1.0 + heaved * (0.22 * far_edge - 0.18 * near_edge);
	// Burn marks from the fires: broad, soft and never much darker.
	col *= 1.0 - 0.12 * smoothstep(0.55, 0.85, value_noise(p * 0.07 + 31.0));
	// The ash: a veil over everything, thicker in streaks drawn along the street and in the gutters, a
	// fine mottle up close, thin over the seams and cracks.
	float streaks = 0.6 * value_noise(p * vec2(0.9, 0.11) + 13.0) + 0.4 * value_noise(p * vec2(2.6, 0.32) + 3.0);
	float mottle = mix(0.5, value_noise(p * 2.3 + 7.0), 0.3 + 0.7 * detail);
	float ash = dz_ash_amount * (0.5 + 0.55 * smoothstep(0.3, 0.75, streaks)) * (0.85 + 0.3 * mottle);
	ash = max(ash, float((flags >> 2) & 1) * (0.7 + 0.2 * value_noise(p * vec2(2.0, 0.4))));
	ash *= 1.0 - 0.7 * line_dark;
	col = mix(col, dz_ash * (0.92 + 0.16 * mottle), clamp(ash, 0.0, 0.85));
	// Worn dashed lane lines on the lane's edges, broken and mostly buried under the ash.
	float dash = filtered_pulse(w.z / 9.0, fwp.y / 9.0, 0.0, 0.4);
	float on_edge = smoothstep(0.945 - fu, 0.945 + fu, abs(uv.x));
	float line = on_edge * dash * (uv.x < 0.0 ? float(flags & 1) : float((flags >> 1) & 1));
	float paint = smoothstep(0.35, 0.65, value_noise(p * vec2(3.0, 0.5) + 3.0));
	col = mix(col, dz_line, line * paint * 0.55);
	// Scattered rubble over the ash, in spills where a facade came down and sparse between them:
	// chunks of broken concrete and charred debris, their tops lit, their near sides dark.
	float spill = smoothstep(0.5, 0.8, value_noise(p * vec2(0.3, 0.12) + 57.0));
	vec2 rc = floor(p / 0.6);
	vec2 rf = fract(p / 0.6) - 0.5;
	float r = hash12(rc + 41.0);
	vec2 half_size = vec2(0.04 + 0.12 * hash12(rc + 3.0), 0.03 + 0.1 * hash12(rc + 7.0)) / 0.6;
	vec2 off = (vec2(hash12(rc + 11.0), hash12(rc + 13.0)) - 0.5) * 0.4;
	// Each chunk lies at its own angle, a corner broken off it.
	float ang = hash12(rc + 19.0) * 3.1416;
	vec2 lp = rf - off;
	lp = vec2(lp.x * cos(ang) - lp.y * sin(ang), lp.x * sin(ang) + lp.y * cos(ang));
	vec2 d = abs(lp) - half_size;
	float corner = dot(lp / max(half_size, vec2(1e-3)), vec2(0.7071)) - 0.9;
	float aa = fpm / 0.6 + 1e-4;
	float chunk = (1.0 - smoothstep(-aa, aa, max(max(d.x, d.y), corner * min(half_size.x, half_size.y))))
		* step(mix(0.9, 0.5, spill), r) * detail;
	float near_side = smoothstep(-aa, aa, rf.y - off.y - half_size.y * 0.2);
	float pale = step(0.55, hash12(rc + 23.0));
	vec3 top = mix(dz_soot * 3.5, dz_rubble, pale) * (0.8 + 0.35 * hash12(rc + 27.0));
	vec3 rubble = mix(top, dz_soot * 2.0, near_side * 0.75);
	// Soot around the spills.
	col *= 1.0 - 0.1 * spill;
	return mix(col, rubble, chunk);
}

// PAT_DZ_UNDER (41): everything below the street, seen only through holes: the broken road's cut, the
// lanes' sides, the building faces below the street and the void's floor far below. Deep shade that
// only darkens COLOR (the shade just under the street) with depth, so a hole reads as a hole at a
// glance: nothing in it is lit or looks like a floor. Near the top the road's broken layers show as
// faint darker bands and rebar. param: 0 a face across the lane, 1 a face along it, 2 the void's floor.
vec3 dz_under(vec3 base, vec3 w, vec3 n, float param) {
	float h = abs(n.x) > 0.5 ? w.z : w.x;
	float fh = max(fwidth(h), 1e-4);
	float fy = max(fwidth(w.y), 1e-4);
	float mode = floor(param + 0.5);
	float grain = 0.88 + 0.12 * value_noise(vec2(h * 2.3, w.y * 3.1));
	float layers = 0.3 * band(w.y, -0.36, -0.3, fy) + 0.2 * band(w.y, -0.66, -0.6, fy);
	float rebar = filtered_pulse(h / 0.25, fh / 0.25, 0.0, 0.12) * band(w.y, -0.52, -0.46, fy);
	float depth = mix(1.0, 0.16, smoothstep(-0.1, -3.2, w.y));
	vec3 col = base * (1.0 - layers - 0.3 * rebar) * grain * depth;
	return mode > 1.5 ? base * 0.3 * grain : col;
}

// PAT_DZ_TOWER (42): a burnt-out tower of the dead city (DeadTowers): one of the Neon City's towers
// after the fire, so the zone's future shows in its dominant shapes. The window grids are the City's
// four (facade.gdshader's styles: 0 office glass, 1 punched windows, 2 ribbon windows, 3 tall slots),
// and behind them the floors are gutted: most windows are blown out onto burnt rooms (dark, the floor
// inside catching a little ash), some keep jagged shards of smoked glass, soot rises from their tops,
// ash lies on every sill, and blast holes gape above the play space. The wall is charred cladding.
// Below dz_band_top (the wall-run band and a margin) every face stays calm and solid-looking: flush
// scorched panels, no opening, nothing dark or window-like (a window cyborg's window must be the only
// one there) and nothing vent-like at the foot (in the Dead Zone a grille there is a screech's vent).
// A face whose COLOR.a is above 0 smoulders: in the rare room above dz_ember_height still burning, a
// dim ember glow lies low in the window (the kit's glow at COLOR.a, below the bloom threshold),
// breathing slowly (steady with Reduced flashing); far away it fades out rather than sparkle.
// UV: x metres along the face, y world height. param = style + 4 * seed (a whole number).
vec3 dz_tower(vec3 base, vec2 uv, float param, float t, inout float glow) {
	vec2 fw_m = max(fwidth(uv), vec2(1e-4));
	float code = floor(param + 0.5);
	float style = mod(code, 4.0);
	float seed = floor(code / 4.0);
	vec2 cs = style < 0.5 ? vec2(1.3, 3.3) : (style < 1.5 ? vec2(2.2, 3.0) : (style < 2.5 ? vec2(4.0, 3.3) : vec2(1.6, 3.3)));
	vec4 win = style < 0.5 ? vec4(0.07, 0.3, 0.93, 0.9) : (style < 1.5 ? vec4(0.22, 0.3, 0.78, 0.8)
		: (style < 2.5 ? vec4(0.03, 0.42, 0.97, 0.82) : vec4(0.25, 0.1, 0.75, 0.92)));
	vec2 p = uv / cs;
	vec2 cell = floor(p);
	vec2 fp = fract(p);
	vec2 fw = fw_m / cs;
	float far = smoothstep(0.1, 0.4, max(fw.x, fw.y));
	float detail = 1.0 - smoothstep(0.03, 0.2, max(fw_m.x, fw_m.y));
	// The charred wall: patchy tone, broad burnt patches, soot streaks running down.
	vec3 wall = base * (0.84 + 0.28 * value_noise(vec2(uv.x * 0.9, uv.y * 0.12) + seed));
	wall *= 1.0 - 0.4 * smoothstep(0.55, 0.85, value_noise(uv * 0.08 + seed * 1.7));
	wall *= 1.0 - 0.3 * smoothstep(0.62, 0.9, value_noise(vec2(uv.x * 2.6, uv.y * 0.16) + seed * 0.3));
	// The calm band: flush cladding panels in a running bond, heat-stained, some fallen off onto the bare
	// concrete behind (still flush, never an opening), scorch rising in tongues from the fires that burned
	// along the street, the band blackened toward its top by the smoke that poured up the face, ash
	// drifted against its foot. No pale line runs along it but the height marks (DeadTowers).
	vec2 bq = uv / vec2(1.8, 1.2);
	bq.x += 0.5 * mod(floor(bq.y), 2.0);
	vec2 bfq = fw_m / vec2(1.8, 1.2);
	float pk = hash12(floor(bq) + seed * 0.7);
	float fallen = step(0.88, pk);
	float joint = max(filtered_pulse(bq.x, bfq.x, 0.0, 0.015), filtered_pulse(bq.y, bfq.y, 0.0, 0.025)) * (1.0 - fallen);
	// The band's panels are dusted with ash, a shade paler than the soot-black storeys above, so the
	// scorch shows on them.
	vec3 dusted = mix(wall, dz_ash * 0.62, 0.3);
	vec3 bare = mix(base, dz_ash * 0.5, 0.25) * (0.8 + 0.3 * value_noise(uv * 2.2 + seed));
	vec3 band_col = mix(dusted * (0.88 + 0.22 * pk), bare, fallen) * (1.0 - 0.45 * joint);
	// Two rows of scorch tongues on different spacings, each of its own height and width, their edges
	// ragged.
	float tongue = 0.0;
	for (int i = 0; i < 2; i++) {
		float period = i == 0 ? 2.7 : 4.3;
		float tx = uv.x / period + float(i) * 0.37;
		float tc = floor(tx);
		float th = (1.5 + 5.0 * hash11(tc * 1.3 + seed + float(i) * 11.0)) * (i == 0 ? 1.0 : 1.2);
		float rise = clamp(uv.y / th, 0.0, 1.0);
		float tw = (0.2 + 0.25 * hash11(tc * 2.9 + seed)) * (1.0 - rise * rise) + 0.03;
		float wobble = 0.1 * sin(uv.y * 1.3 + tc * 2.0) + 0.12 * (value_noise(vec2(tx * 4.0, uv.y * 1.6) + seed) - 0.5);
		float edge_d = abs(fract(tx) - 0.5 + wobble) - tw;
		tongue = max(tongue, (1.0 - smoothstep(-0.08, 0.08, edge_d)) * step(0.35, hash11(tc + seed * 2.1 + float(i) * 5.0)));
	}
	band_col = mix(band_col, dz_soot * 1.4, tongue * 0.85);
	band_col = mix(band_col, dz_soot * 1.6, 0.6 * smoothstep(4.0, dz_band_top + 0.5, uv.y));
	band_col = mix(band_col, dz_ash * 0.8, (1.0 - smoothstep(0.0, 0.3, uv.y)) * 0.5);
	// The windows above it: burnt-out rooms (dark, the floor inside catching a little ash low in the
	// window, a column in some) with soot streaking up the face above them into the next storey; jagged
	// shards of smoked glass left in some frames; around some the cladding has fallen too, leaving a
	// larger, ragged hole onto the gutted floor.
	float in_win = filtered_pulse(p.x, fw.x, win.x, win.z) * filtered_pulse(p.y, fw.y, win.y, win.w);
	float k = hash12(cell * vec2(1.7, 2.3) + seed * 5.0);
	float k_below = hash12((cell - vec2(0.0, 1.0)) * vec2(1.7, 2.3) + seed * 5.0);
	float wx = (fp.x - win.x) / (win.z - win.x);
	float wy = (fp.y - win.y) / (win.w - win.y);
	vec3 room = dz_soot * (1.0 + 2.0 * (1.0 - smoothstep(0.0, 0.22, wy)));
	float column = step(0.6, hash12(cell + seed * 3.0)) * filtered_pulse(fp.x, fw.x, 0.45, 0.55);
	room = mix(room, dz_soot * 0.6, column);
	float teeth = 2.0 + floor(k * 4.0);
	float saw = abs(fract(wx * teeth + k * 7.0) - 0.5) * 2.0;
	float edge = 0.18 + 0.45 * saw * hash11(cell.x * 3.1 + cell.y * 1.7 + seed);
	float shard = step(0.62, k) * step(k, 0.84) * (1.0 - smoothstep(edge - 0.03, edge + 0.03, wy));
	vec3 fill = mix(room, dz_glass, shard);
	// Where the cladding fell around a window the hole is larger and ragged.
	float torn = step(0.84, k) * step(k, 0.94);
	vec2 tq = (fp - vec2((win.x + win.z) * 0.5, (win.y + win.w) * 0.5)) / vec2(win.z - win.x, win.w - win.y);
	float rag = 0.62 + 0.18 * value_noise(fp * 9.0 + cell * 3.1);
	float hole = torn * (1.0 - smoothstep(rag - 0.04, rag + 0.04, max(abs(tq.x), abs(tq.y))));
	in_win = max(in_win, hole);
	// Embers: the rare room high up still burning (faces that smoulder: COLOR.a > 0).
	float burning = step(k, dz_ember_share) * step(dz_ember_height, cell.y * cs.y) * step(0.001, glow);
	float breath = mix(0.72 + 0.28 * sin(t * 1.1 + k * 400.0), 0.86, reduced_flashing);
	float ember = burning * in_win * (1.0 - smoothstep(0.05, 0.6, wy)) * breath * (1.0 - far);
	fill = mix(fill, dz_ember, ember);
	// Soot streaking up from the burnt-out windows: over the rest of this storey and into the next.
	float mid = filtered_pulse(fp.x, fw.x, win.x + 0.04, win.z - 0.04);
	float above = step(k, 0.62) * step(win.w, fp.y) * (1.0 - 0.5 * smoothstep(win.w, 1.0, fp.y));
	float from_below = step(k_below, 0.62) * step(fp.y, win.y) * (0.5 - 0.5 * smoothstep(0.0, win.y, fp.y));
	vec3 upper = mix(wall, dz_soot, max(above, from_below) * mid * 0.8);
	vec3 col = mix(upper, fill, in_win);
	// Blast holes: a few ragged clusters of cells blown open onto gutted floors, their slabs' edges showing.
	vec2 jag = (vec2(value_noise(uv * 1.9 + seed), value_noise(uv * 1.9 + seed + 7.1)) - 0.5) * 0.3;
	vec2 bc = floor(p + jag);
	float blown = step(value_noise(bc * vec2(0.45, 0.6) + seed * 1.3), 0.12) * step(dz_band_top + 3.0, bc.y * cs.y);
	vec3 gutted = dz_soot * (0.6 + 3.5 * filtered_pulse(p.y, fw.y, 0.0, 0.08));
	col = mix(col, gutted, blown);
	ember *= 1.0 - blown;
	// Far away the openings blur into the face's average.
	col = mix(col, mix(wall, dz_soot, 0.45), far);
	// Fine grit up close.
	col *= 1.0 + 0.1 * detail * (hash12(floor(uv * 14.0)) - 0.5);
	float upper_part = step(dz_band_top, uv.y);
	glow *= ember * upper_part;
	return mix(band_col, col, upper_part);
}

// PAT_DZ_CONCRETE (43): charred concrete (the bridges' decks and fascias, broken slabs, stumps, the
// rubble choking the side streets). param 0: a wall or a deck: form-board lines, cracks, soot blooms,
// streaks down upright faces and ash on upward ones; 1: an underside ridden upside down (a bridge's or
// a dead building's soffit): no ash (it falls off), soot from the fires below, formwork joints across
// it every 1.2 m streaming past (the ceiling's motion cue) and spalled patches showing the rebar grid;
// 2: a heap of rubble facing the street, flush with a wall: broken chunks, dust between them.
vec3 dz_concrete(vec3 base, vec3 w, vec3 n, float param) {
	vec2 p = abs(n.y) > 0.5 ? w.xz : (abs(n.x) > 0.5 ? w.zy : w.xy);
	vec2 fwp = max(fwidth(p), vec2(1e-4));
	float fz = max(fwidth(w.z), 1e-4);
	float fy = max(fwidth(w.y), 1e-4);
	// The mode is the same over a whole face, so branching on it keeps neighbouring pixels together.
	float mode = floor(param + 0.5);
	float detail = 1.0 - smoothstep(0.03, 0.2, max(fwp.x, fwp.y));
	vec3 col = base * (0.86 + 0.22 * value_noise(p * 0.4 + 3.0));
	float soot = smoothstep(0.45, 0.8, value_noise(p * 0.15 + 7.0));
	if (mode > 1.5) {
		// Rubble: broken chunks of every size heaped together (the cells of a jittered grid, each its own
		// tone, lit toward its top), dark gaps between them, dust and ash settled over the heap.
		vec2 q = p / 0.45;
		vec2 qi = floor(q);
		vec2 qf = fract(q);
		float d1 = 8.0;
		float d2 = 8.0;
		vec2 id = vec2(0.0);
		vec2 rel = vec2(0.0);
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec2 o = vec2(float(i), float(j));
				vec2 c = o + vec2(hash12(qi + o + 3.0), hash12(qi + o + 7.0)) * 0.85;
				vec2 dv = c - qf;
				float dd = dot(dv, dv);
				if (dd < d1) {
					d2 = d1;
					d1 = dd;
					id = qi + o;
					rel = -dv;
				} else if (dd < d2) {
					d2 = dd;
				}
			}
		}
		float fq = max(fwp.x, fwp.y) / 0.45;
		float gap = 1.0 - smoothstep(0.03, 0.12 + fq, sqrt(d2) - sqrt(d1));
		// Each chunk is a broken facet turned its own way to the light: some catch it, most are in shadow,
		// a few are charred black; big slabs lie among the small chunks.
		float h1 = hash12(id + 5.0);
		float ang = hash12(id + 9.0) * 6.2832;
		float facet = clamp(0.5 + 1.6 * dot(rel, vec2(cos(ang), sin(ang))), 0.0, 1.0);
		float slab = smoothstep(0.62, 0.66, value_noise(p * 0.55 + 41.0));
		vec3 rubble = base * (0.45 + 0.75 * h1) * (0.55 + 0.7 * mix(facet, 0.6, slab));
		rubble = mix(rubble, dz_soot * 1.5, step(0.82, hash12(id + 13.0)) * (1.0 - slab));
		rubble = mix(rubble, dz_soot * 1.2, gap * 0.9 * (1.0 - slab));
		return mix(rubble, dz_ash * 0.75, smoothstep(0.6, 0.9, value_noise(p * 1.3 + 2.0)) * 0.45);
	} else if (mode > 0.5) {
		// The soffit: charred, soot streaked along the way the smoke rolled under it, formwork joints
		// across it streaming past overhead, small spalled patches (rough, darker, a paler broken rim).
		float joint = filtered_pulse(w.z / 1.2, fz / 1.2, 0.0, 0.02);
		float streak = smoothstep(0.35, 0.8, value_noise(vec2(p.x * 1.7, w.z * 0.12) + 21.0));
		float sn = value_noise(p * vec2(1.1, 0.7) + 0.35 * value_noise(p * 3.1) + 21.0);
		float spall = smoothstep(0.8, 0.86, sn);
		vec3 soffit = mix(col, col * 0.4, max(soot * 0.45, streak * 0.5)) * (1.0 - 0.3 * joint);
		return mix(soffit, soffit * (0.6 + 0.25 * value_noise(p * 6.0) * detail), spall * 0.7);
	}
	// Cast concrete: form-board lines (across a deck, up a wall), soot blooms, streaks down upright
	// faces, ash on upward ones.
	float up = smoothstep(0.5, 0.9, n.y);
	float upright = step(abs(n.y), 0.5);
	float board = mix(filtered_pulse(w.z / 2.4 + 0.5, fz / 2.4, 0.0, 0.008), filtered_pulse(w.y / 0.6, fy / 0.6, 0.0, 0.02),
		upright);
	float streak = upright * smoothstep(0.6, 0.9, value_noise(vec2(p.x * 2.6, p.y * 0.22) + 9.0));
	vec3 cast = col * (1.0 - 0.18 * board);
	cast = mix(cast, cast * 0.35, max(soot * 0.75, streak * 0.6));
	// Blackened in broad patches where the fires licked the upright faces.
	cast *= 1.0 - 0.35 * upright * smoothstep(0.4, 0.75, value_noise(vec2(p.x * 0.8, p.y * 0.3) + 17.0));
	return mix(cast, dz_ash * (0.85 + 0.25 * value_noise(p * 2.1)), up * (0.3 + 0.45 * value_noise(p * 0.9 + 4.0)));
}

// PAT_DZ_STEEL (44): scorched steel (girders, frames, rails, bent posts, the dead neon's housings):
// dark, heat-dulled, rust blooms in patches, flaking soot. param 1: corrugated (ribs every 0.2 m).
vec3 dz_steel(vec3 base, vec3 w, vec3 n, float param) {
	vec2 p = abs(n.y) > 0.5 ? w.xz : (abs(n.x) > 0.5 ? w.zy : w.xy);
	vec2 fwp = max(fwidth(p), vec2(1e-4));
	float mode = floor(param + 0.5);
	vec3 col = base * (0.85 + 0.25 * value_noise(p * vec2(1.7, 0.6) + 5.0));
	float rust = smoothstep(0.6, 0.85, value_noise(p * 1.1 + 13.0));
	col = mix(col, vec3(dot(col, vec3(0.33))) * vec3(1.12, 0.98, 0.9), rust * 0.6);
	col *= 1.0 - 0.45 * smoothstep(0.5, 0.8, value_noise(p * 0.6 + 3.0));
	float ribs = filtered_pulse(p.x / 0.2, fwp.x / 0.2, 0.0, 0.3) * step(0.5, mode);
	return col * (1.0 - 0.3 * ribs);
}

// PAT_DZ_BOARD (45): a dead billboard or screen, never glowing (the city's ads died with it). UV in
// metres on the board (x along it as seen from the street, y up); param = seed (0-99) + 100 * kind:
// 0 a scorched poster board: the ad's print burnt to pale ghosts of its blocks and bars, black scorch
// eating in from the edges, holes burnt through; 1 a dead screen: dark glass cracked out from a point,
// a faint grey sheen, soot along the bottom.
vec3 dz_board_face(vec3 base, vec2 uv, float param) {
	vec2 fw = max(fwidth(uv), vec2(1e-4));
	float fm = max(fw.x, fw.y);
	float code = floor(param + 0.5);
	float seed = mod(code, 100.0);
	// The kind is the same over a whole board, so branching on it keeps neighbouring pixels together.
	if (code >= 100.0) {
		// A dead screen: cracks running out from a point, a faint sheen, soot along its foot.
		vec2 hit = vec2(1.0 + 2.0 * hash11(seed + 1.0), 0.6 + 0.8 * hash11(seed + 2.0));
		vec2 dv = uv - hit;
		float dist = length(dv);
		float ang = atan(dv.y, dv.x);
		float rays = band(abs(fract(ang * 1.2732 + hash11(seed) * 3.0) - 0.5), 0.0, 0.03, 0.02)
			* (1.0 - smoothstep(0.3, 2.6, dist));
		float rings = band(fract(dist * 2.2), 0.0, 0.05, fm * 2.2) * (1.0 - smoothstep(0.2, 1.4, dist));
		vec3 screen = dz_board * (0.9 + 0.25 * value_noise(uv * 0.8 + seed));
		screen = mix(screen, dz_ash * 0.45, max(rays, rings) * 0.7);
		return mix(screen, dz_soot, (1.0 - smoothstep(0.0, 0.6, uv.y)) * 0.6);
	}
	// A scorched poster board: the ad's ghosts (pale blocks and bars in cells along it), scorch eating
	// in, and holes burnt through to the board's dark back.
	vec2 q = (uv + vec2(seed * 3.7, 0.0)) / vec2(2.4, 1.6);
	vec2 cell = floor(q);
	vec2 f = fract(q);
	vec2 fq = fw / vec2(2.4, 1.6);
	float block = band(f.x, 0.12, 0.55, fq.x) * band(f.y, 0.3, 0.82, fq.y) * step(0.35, hash12(cell + 9.0));
	float bars = band(f.x, 0.62, 0.9, fq.x) * max(band(f.y, 0.62, 0.72, fq.y), band(f.y, 0.4, 0.46, fq.y));
	vec3 poster = mix(base, mix(base, dz_ash, 0.55), max(block, bars) * (0.5 + 0.5 * value_noise(uv * 1.7 + seed)));
	// The burn: fire climbed the board from its foot in ragged tongues and ate in from one end,
	// browning then blackening the print, with holes burnt right through where it burnt longest;
	// elsewhere only brown scorch patches.
	float tongues = value_noise(vec2(uv.x * 1.1 + seed * 1.9, uv.y * 0.3 + seed));
	float climb = 1.0 - smoothstep(0.0, 0.6 + 2.2 * tongues * tongues, uv.y);
	float end_burn = 1.0 - smoothstep(0.0, 1.1, uv.x + 0.5 * value_noise(uv * vec2(1.5, 0.8) + seed));
	float scorch = 0.55 * value_noise(uv * vec2(0.9, 1.3) + seed * 1.9);
	float burn = max(max(climb, end_burn * 0.9), scorch);
	burn += 0.08 * (value_noise(uv * 6.0 + seed) - 0.5);
	poster = mix(poster, poster * 0.55, smoothstep(0.35, 0.55, burn));
	poster = mix(poster, dz_soot * 1.6, smoothstep(0.5, 0.75, burn));
	return mix(poster, dz_board * 0.35, smoothstep(0.8, 0.83, burn));
}

// PAT_DZ_MARK (46): the cult's emblem, scorched and half-gone (GDD §5: hidden in plain sight; here
// burnt like everything else): the material's cult_emblem texture (CultEmblem's drawing of the owner's
// choice) painted in COLOR (its unlit metal, or the grey of a dead neon tube) on a charred panel, with
// a ragged burn eating a part of it away and soot over the rest. Never glowing. UV is emblem space (the
// mark's square spans -1 to 1; a wider range leaves a margin); param a whole-number seed for the burn.
// cult_mark() fades the mark out when it is small on screen (the radiation-trefoil rule), leaving the
// panel.
vec3 dz_mark(vec3 base, vec2 uv, float param) {
	vec2 fwv = max(fwidth(uv), vec2(1e-4));
	float fw = max(fwv.x, fwv.y);
	float seed = floor(param + 0.5);
	vec3 panel = dz_board * (0.85 + 0.25 * value_noise(uv * 2.0 + seed));
	vec4 mark = cult_mark(uv, fw);
	// The burn: a ragged front across the mark from a side picked by the seed; past it, it's gone.
	float a = hash11(seed * 1.3 + 0.7) * 6.2832;
	float front = dot(uv, vec2(cos(a), sin(a))) + 0.4 * (value_noise(uv * 2.4 + seed) - 0.5) - 0.15 - 0.3 * hash11(seed + 3.0);
	float gone = smoothstep(-fw, fw, front);
	float charred = band(front, -0.35, 0.0, fw);
	vec3 paint = base * (0.8 + 0.25 * value_noise(uv * 5.0 + seed));
	paint = mix(paint, dz_soot * 2.0, max(charred * 0.75, 0.3 * value_noise(uv * 1.6 + 9.0)));
	vec3 col = mix(panel, paint, mark.a * (1.0 - gone));
	return mix(col, dz_soot, gone * 0.6);
}

// Dispatches the Dead Zone's patterns (ids 40-49) for kit_solid.gdshader.
vec3 dz_surface(int pattern, float param, vec3 base, vec3 w, vec3 n, vec2 uv, float t, inout float glow) {
	if (pattern == 40) {
		return dz_street(base, w, uv, param);
	} else if (pattern == 41) {
		return dz_under(base, w, n, param);
	} else if (pattern == 42) {
		return dz_tower(base, uv, param, t, glow);
	} else if (pattern == 43) {
		return dz_concrete(base, w, n, param);
	} else if (pattern == 44) {
		return dz_steel(base, w, n, param);
	} else if (pattern == 45) {
		return dz_board_face(base, uv, param);
	} else if (pattern == 46) {
		return dz_mark(base, uv, param);
	}
	return base;
}

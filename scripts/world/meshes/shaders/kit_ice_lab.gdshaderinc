// The Ice Lab's surfaces for the solid kit shader (kit_solid.gdshader): pattern ids 110-119
// (MeshKit.PAT_IL_*, task Q2), in their own file so other zones' patterns never collide with them.
// GDD §5, Zone 9: a frozen industrial laboratory, icy and crystalline: steel catwalks and grating, girders and
// cranes, snow and ice, lab consoles and server racks, specimen jars (docs/art/reference/ice_lab_zone.webp).
// Nothing here is neon. The only things that glow are small and dim, well under the bloom threshold and far
// under a hazard: the machine lamps (a small amber point, the Terminal's), the screens and the jars' liquid
// (pale, desaturated blue-white), all of them over the wall-run band (the skin keeps the band calm: its screens and
// panels' status LEDs are lit paint like the rest); everything else is lit paint, steel, ice and snow. Each function takes the fragment's world position `w`, world normal `n`, the eye
// vector `eye` (world, from the surface toward the camera), UV and the pattern parameter, and returns the
// albedo (sRGB, like COLOR); the kit then lights it like any lit surface. Pixel footprints are taken at the top
// of each function and passed down (docs/ARCHITECTURE.md, Zone skins: the kit's shader rules).
//
// The lean (the owner, October 21, 2026: level 1 leans into snow and industry, the last level into the lab): the
// skin sets `il_snow_amount` (how much of the floor, the ledges and the machinery lies under snow and frost) and
// `il_lab` (0 industrial, 1 laboratory: the floor's share of clean plates), from its lab_share.
//
// The skin sets every colour below as an sRGB Vector3 (IceLabSkin.srgb()), like vertex colours: a Color would
// arrive already linear on Forward+ but not on the Compatibility renderer.
uniform vec3 il_ice = vec3(0.3, 0.5, 0.66);
uniform vec3 il_snow = vec3(0.66, 0.74, 0.83);
uniform vec3 il_frost = vec3(0.5, 0.6, 0.72);
uniform vec3 il_liquid = vec3(0.42, 0.7, 0.78);
uniform vec3 il_screen = vec3(0.5, 0.74, 0.84);
uniform float il_snow_amount = 0.5;
uniform float il_lab = 0.5;

// The half width of the lane (or the gutter) a floor pattern is drawn on, in metres, from the pattern's parameter:
// centimetres, in the parameter's bits from 3 up (IceLabFloor.half_width_param). UV.x runs -1 to 1 across it. A
// parameter without one (nothing the skin draws) reads as a 1.2 m half lane, the shipped lane width's.
float il_half_width(float param) {
	float cm = float(int(param + 0.5) >> 3);
	return cm > 0.5 ? cm * 0.01 : 1.2;
}

// Two coordinates in the plane of the face, picked by its dominant axis.
vec2 il_plane(vec3 w, vec3 n) {
	return abs(n.y) > 0.5 ? w.xz : (abs(n.x) > 0.5 ? w.zy : w.xy);
}

// The sheen ice and wet steel give back at grazing angles.
float il_graze(vec3 n, vec3 eye) {
	return pow(1.0 - clamp(dot(n, eye), 0.0, 1.0), 3.0);
}

// PAT_IL_GRATING (110): a lane of catwalk: steel grating in panels of 1.2 by 2.4 m (an angle frame round each; load
// bars along the track every 5 cm, cross rods every 30 cm, the slots between them dark), some panels solid tread
// plate (more of them in the lab), packed snow lying in drifts (the lean: il_snow_amount, deeper along the lane's edges
// and in the gutter by the wall), patches of glossy ice with cracks, a dark seam between lanes. UV.x -1 to 1 across the
// lane; param = the lane's half width in centimetres times 8, plus flags in the low three bits (1 a neighbouring lane
// on the left, 2 on the right, 4 the gutter between the outer lane and the wall: deeper snow, no seam). Everything
// comes from world position, so it lines up across chunk cuts, and the bars stream past underfoot as the still floor's
// own sense of speed. Nothing glows. The darkest it is drawn is the slots (base x 0.42): IceLabSkin keeps a hole
// darker still.
vec3 il_grating(vec3 base, vec3 w, vec3 n, vec3 eye, vec2 uv, float param) {
	vec2 p = w.xz;
	vec2 fwp = max(fwidth(p), vec2(1e-4));
	float aa = max(fwp.x, fwp.y);
	float half_w = il_half_width(param);
	int flags = int(param + 0.5) & 7;
	float x = uv.x * half_w;
	float fu = max(fwidth(uv.x), 1e-4) * half_w;
	float detail = 1.0 - smoothstep(0.03, 0.14, aa);
	vec2 pc = vec2(p.x / 1.2, p.y / 2.4);
	vec2 fq = fwp / vec2(1.2, 2.4);
	float ph = hash12(floor(pc) + 11.0);
	float plate = step(1.0 - (0.08 + 0.22 * il_lab), ph);
	float frame = max(filtered_pulse(pc.x, fq.x, 0.0, 0.035), filtered_pulse(pc.y, fq.y, 0.0, 0.02));
	float bars = filtered_pulse(p.x / 0.05, fwp.x / 0.05, 0.0, 0.32);
	float rods = filtered_pulse(p.y / 0.3, fwp.y / 0.3, 0.0, 0.14);
	float tread = max(filtered_pulse((p.x + p.y) / 0.11, (fwp.x + fwp.y) / 0.11, 0.0, 0.2),
		filtered_pulse((p.x - p.y) / 0.11, (fwp.x + fwp.y) / 0.11, 0.0, 0.2));
	float steel = mix(max(bars, rods), 1.0, plate);
	// The slots between the bars are the darkest the street is drawn (base x 0.42, with little snow about; frost lifts them toward the
	// bars as the snow thickens, so a level deep in snow shows no black patches that could be taken for holes).
	vec3 col = mix(base * mix(0.42, 0.68, il_snow_amount), base * (0.78 + 0.4 * ph), steel);
	col = mix(col, base * (0.8 + 0.4 * tread) * (0.85 + 0.3 * ph), plate * 0.85);
	col = mix(col, base * 1.3, frame * 0.8);
	// Snow: drifts, deeper toward the lane's edges and in the gutter; the grating shows through where it is thin.
	float edge = smoothstep(0.35, 1.0, abs(x) / half_w) * 0.3 + float((flags & 4) != 0) * 0.45;
	float cover = clamp(il_snow_amount * 1.1 + edge - 0.2 + 0.28 * smoothstep(0.55, 0.9, il_snow_amount), 0.0, 1.0);
	float drift = value_noise(p * vec2(0.55, 0.28) + 3.0) * 0.6 + value_noise(p * vec2(1.7, 1.1) + 9.0) * 0.4;
	float thresh = 1.0 - cover * 0.82;
	float snow = smoothstep(thresh, thresh + 0.2, drift);
	float thick = smoothstep(thresh + 0.1, thresh + 0.3, drift);
	float grain = value_noise(p * 5.5 + 1.0) * 0.5 + value_noise(p * 14.0) * 0.5;
	vec3 snow_col = il_snow * (0.78 + 0.34 * grain) * (0.88 + 0.12 * thick);
	snow_col = mix(snow_col, il_ice * 0.95, (1.0 - thick) * 0.22);
	col = mix(col, snow_col, snow * (0.6 + 0.38 * thick));
	// Rime on the bars where the snow is thin or absent, the more the snow lies about: the exposed grating is frosted mid-grey, never near black.
	col = mix(col, il_frost * (0.5 + 0.3 * grain), (1.0 - snow) * il_snow_amount * 0.5);
	// Ice: glossy patches where the snow is not, with cracks and the sheen of the cold.
	float n2 = value_noise(p * vec2(0.45, 0.33) + 31.0) * 0.65 + value_noise(p * 1.3 + 5.0) * 0.35;
	float ice = smoothstep(0.68, 0.76, n2) * (1.0 - snow);
	float graze = il_graze(n, eye);
	vec3 ice_col = il_ice * (0.6 + 0.4 * value_noise(p * 3.0)) + il_snow * 0.3 * graze;
	float crack = (1.0 - smoothstep(0.0, 0.012 + aa * 1.5, abs(value_noise(p * vec2(1.3, 3.1) + 7.0) - 0.5))) * detail;
	ice_col = mix(ice_col, il_snow * 0.85, crack * 0.3);
	col = mix(col, ice_col, ice * 0.75);
	// Frost glints, standing still: tiny pale specks where the snow lies, only close enough to see.
	float speck = step(0.985, hash12(floor(p * 38.0))) * detail * (snow + ice);
	col += il_snow * speck * 0.3;
	// The seam between lanes (not along the wall), so the lanes read.
	float seam = thin_bar(abs(x) - half_w, 0.03, fu) * float((flags & 4) == 0);
	col *= 1.0 - 0.5 * seam;
	return col;
}

// PAT_IL_UNDER (111): everything under the catwalks, seen only through the holes: deep shade that only darkens with
// depth, the faint ghost of truss ribs and braces and hoar furring near the top, and a floor of dark ice far below.
// COLOR is the shade at the street's level (it only darkens it: the result never passes COLOR). param 0 a face
// across the lane, 1 a face along it, 2 the frozen floor.
vec3 il_under(vec3 base, vec3 w, vec3 n, float param) {
	float mode = floor(param + 0.5);
	float h = abs(n.x) > 0.5 ? w.z : w.x;
	float fh = max(fwidth(h), 1e-4);
	float fy = max(fwidth(w.y), 1e-4);
	if (mode > 1.5) {
		float crack = 1.0 - smoothstep(0.0, 0.06 + fh * 2.0, abs(value_noise(w.xz * 0.5 + 3.0) - 0.5));
		return min(base * (0.7 + 0.3 * value_noise(w.xz * 0.35 + 1.0) + 0.1 * crack), base);
	}
	float rib = filtered_pulse(h / 2.4, fh / 2.4, 0.0, 0.05);
	float brace = filtered_pulse((h + w.y) / 3.4, (fh + fy) / 3.4, 0.0, 0.04) * smoothstep(-3.5, -0.2, w.y);
	float depth = mix(1.0, 0.16, 1.0 - smoothstep(-4.5, -0.1, w.y));
	float fur = smoothstep(0.6, 0.85, value_noise(vec2(h * 2.5, w.y * 0.3))) * smoothstep(-2.2, -0.2, w.y);
	vec3 col = base * (0.88 - 0.3 * rib - 0.2 * brace + 0.12 * fur) * depth;
	return min(col, base);
}

// PAT_IL_STEEL (112): frost-crusted black steel, the zone's own metal: plates with seams and rivets, snow lying on
// every top face (the lean), rime blooming in patches and streaking down the uprights. param 0 plating (walls, piers,
// girders; world position), 1 an underside ridden upside down (beams every 3 m across it that stream past a player
// riding it), 2 a pipe or a bar (smooth, a soft highlight), 3 a chain (links in bands along its length), 4 grating seen
// from below (bars and rods lighter than the dark slots: an overhead walkway's underside).
vec3 il_steel(vec3 base, vec3 w, vec3 n, vec3 eye, float param, float t) {
	float mode = floor(param + 0.5);
	vec2 p = il_plane(w, n);
	vec2 fwp = max(fwidth(p), vec2(1e-4));
	float aa = max(fwp.x, fwp.y);
	float fy = max(fwidth(w.y), 1e-4);
	float detail = 1.0 - smoothstep(0.03, 0.14, aa);
	float up = clamp(n.y, 0.0, 1.0);
	float upright = step(abs(n.y), 0.5);
	vec3 col;
	if (mode > 3.5) {
		vec2 fg = max(fwidth(w.xz), vec2(1e-4));
		float bars = filtered_pulse(w.x / 0.06, fg.x / 0.06, 0.0, 0.36);
		float rods = filtered_pulse(w.z / 0.3, fg.y / 0.3, 0.0, 0.16);
		col = mix(base * 0.5, base * (0.85 + 0.2 * value_noise(w.xz * 0.7)), max(bars, rods));
		float bq = w.z / 3.0;
		col *= 1.0 - 0.35 * filtered_pulse(bq, fg.y / 3.0, 0.0, 0.1);
		return col;
	}
	if (mode > 2.5) {
		float link = filtered_pulse(w.y / 0.16, fy / 0.16, 0.0, 0.55);
		return mix(base * 0.45, base * 1.2, link);
	}
	if (mode > 1.5) {
		float hl = 0.75 + 0.45 * pow(clamp(dot(n, eye), 0.0, 1.0), 2.0);
		col = base * hl * (0.85 + 0.25 * value_noise(w.xz * 3.0 + w.y * 2.0));
		float cap = up * il_snow_amount;
		col = mix(col, il_snow * 0.8, clamp(cap * 1.4, 0.0, 0.9));
		return col;
	}
	vec2 q = p / vec2(1.4, 1.1);
	vec2 fq = fwp / vec2(1.4, 1.1);
	float seam = max(filtered_pulse(q.x, fq.x, 0.0, 0.02), filtered_pulse(q.y, fq.y, 0.0, 0.026));
	col = base * (0.75 + 0.5 * value_noise(p * 0.9 + 3.0)) * (0.9 + 0.2 * hash12(floor(q) + 7.0));
	col *= 1.0 - 0.4 * seam;
	// Rivets along every seam.
	vec2 rp = vec2((fract(p.x / 0.28) - 0.5) * 0.28, fract(q.y) - 0.07);
	float rivet = (1.0 - smoothstep(0.03 - aa, 0.03 + aa, length(rp))) * detail;
	col = mix(col, col * 1.6 + 0.03, rivet * 0.5);
	if (mode > 0.5) {
		float bq = w.z / 3.0;
		col *= 1.0 - 0.4 * filtered_pulse(bq, fwp.y / 3.0, 0.0, 0.1);
	}
	// Frost: rime in patches and streaks; snow caps on top faces.
	float rime = smoothstep(0.66, 0.84, value_noise(p * 2.1 + 11.0) * 0.5 + value_noise(p * 7.0) * 0.5);
	float streak = upright * smoothstep(0.62, 0.9, value_noise(vec2(p.x * 3.5, p.y * 0.3) + 5.0));
	col = mix(col, il_frost * (0.75 + 0.35 * value_noise(p * 6.0)), clamp(max(rime * 0.55, streak * 0.4) * (0.2 + 0.6 * il_snow_amount), 0.0, 0.6));
	col = mix(col, il_snow * 0.85, clamp(up * 1.3, 0.0, 1.0) * (0.25 + 0.7 * il_snow_amount));
	// The sheen of cold metal at grazing angles.
	col += il_ice * il_graze(n, eye) * 0.12;
	return col;
}

// PAT_IL_ICE (113): ice. param 0 a wall of ice (blocky facets of 1.3 by 1 m, sheared, a pale line along their edges,
// frozen runs streaking down, cloudy hollows, a sheen at grazing angles), 1 a crystal (pale, a cold inner light, its
// edges catching the sheen: the facets are the geometry's own flat faces), 2 the frozen floor far below the street (dark
// blue sheets and cracks: only ever darkens COLOR).
vec3 il_ice_surface(vec3 base, vec3 w, vec3 n, vec3 eye, float param) {
	float mode = floor(param + 0.5);
	vec2 p = il_plane(w, n);
	vec2 fwp = max(fwidth(p), vec2(1e-4));
	float aa = max(fwp.x, fwp.y);
	float graze = pow(1.0 - clamp(dot(n, eye), 0.0, 1.0), 2.5);
	if (mode > 1.5) {
		float crack = 1.0 - smoothstep(0.0, 0.05 + aa * 2.0, abs(value_noise(w.xz * 0.6 + 8.0) - 0.5));
		float sheet = value_noise(w.xz * 0.25 + 2.0);
		return min(base * (0.65 + 0.35 * sheet + 0.12 * crack), base);
	}
	if (mode > 0.5) {
		float lit = 0.8 + 0.3 * abs(dot(n, normalize(vec3(0.4, 0.8, 0.5))));
		vec3 col = base * lit + il_ice * 0.1 + il_snow * 0.2 * graze;
		return min(col, vec3(0.92));
	}
	vec2 q = vec2(p.x / 1.3 + p.y * 0.18, p.y / 1.0);
	vec2 fq = fwp / vec2(1.3, 1.0);
	float tone = hash12(floor(q) + 3.0);
	vec3 col = mix(base * 0.7, base * 1.25, tone);
	col *= 0.85 + 0.3 * value_noise(p * vec2(1.8, 0.9) + 2.0);
	float edge = max(filtered_pulse(q.x, fq.x, 0.0, 0.03), filtered_pulse(q.y, fq.y, 0.0, 0.04));
	col = mix(col, base * 1.5 + 0.04, edge * 0.5);
	float runs = smoothstep(0.55, 0.9, value_noise(vec2(p.x * 3.2, p.y * 0.22) + 4.0));
	col = mix(col, il_snow * 0.7, runs * 0.25);
	col = mix(col, base * 0.55, smoothstep(0.55, 0.9, value_noise(p * 0.5 + 9.0)) * 0.4);
	col += il_snow * 0.1 * graze;
	return min(col, vec3(0.9));
}

// PAT_IL_PANEL (114): lab machinery fronts, flush with the wall (UV in metres, x along the face to the viewer's right,
// y up from the floor; param = kind + 4 * a seed 0-99). Kind 0 a cabinet (seams, louvres low down, a handle), 1 a server
// rack (units 10 cm tall in alternating tones, vent slots, a pale status LED here and there), 2 clean-room tile (30 cm
// tiles, grout, frost low down), 3 a service door (flush seams, a hand wheel, a pale indicator). The panels are all in
// the wall-run band, where nothing glows: the LEDs are tiny pale dots of paint (the screens' blue-white), never lit.
vec3 il_panel(vec3 base, vec3 w, vec3 n, vec2 uv, float param) {
	int v = int(param + 0.5);
	int kind = v % 4;
	float seed = float(v / 4);
	vec2 fwu = max(fwidth(uv), vec2(1e-4));
	float aa = max(fwu.x, fwu.y);
	float detail = 1.0 - smoothstep(0.03, 0.12, aa);
	vec3 col = base * (0.85 + 0.25 * value_noise(uv * 1.1 + seed));
	float led = 0.0;
	if (kind == 0) {
		vec2 q = vec2(uv.x / 0.9, uv.y / 1.1);
		vec2 fq = fwu / vec2(0.9, 1.1);
		float seam = max(filtered_pulse(q.x, fq.x, 0.0, 0.025), filtered_pulse(q.y, fq.y, 0.0, 0.03));
		col *= 1.0 - 0.45 * seam;
		float louvre = band(uv.y, 0.15, 0.75, fwu.y) * filtered_pulse(uv.y / 0.06, fwu.y / 0.06, 0.0, 0.45);
		col = mix(col, base * 0.3, louvre * 0.7);
		float handle = band(fract(q.x), 0.82, 0.86, fq.x) * band(uv.y, 1.0, 1.35, fwu.y);
		col = mix(col, base * 1.7 + 0.03, handle * 0.8);
	} else if (kind == 1) {
		float u = uv.y / 0.1;
		float row = floor(u);
		float bay = floor(uv.x / 1.4);
		float tone = hash12(vec2(row, seed + bay * 7.0));
		col = base * (0.7 + 0.6 * tone);
		col *= 1.0 - 0.5 * filtered_pulse(u, fwu.y / 0.1, 0.0, 0.08);
		float lx = (fract(uv.x / 1.4) - 0.5) * 1.4;
		float slots = step(0.5, tone) * band(fract(u), 0.3, 0.7, fwu.y / 0.1) * band(lx, -0.55, 0.45, fwu.x)
			* filtered_pulse(uv.x / 0.05, fwu.x / 0.05, 0.1, 0.6);
		col = mix(col, base * 0.22, slots);
		col *= 1.0 - 0.55 * (thin_bar(lx + 0.62, 0.02, fwu.x) + thin_bar(lx - 0.62, 0.02, fwu.x));
		float on = step(0.72, hash12(vec2(row * 1.3, seed + bay)));
		led = on * (1.0 - smoothstep(0.02, 0.035 + aa, length(vec2(lx - 0.5, (fract(u) - 0.5) * 0.1))));
	} else if (kind == 2) {
		vec2 q = uv / 0.3;
		vec2 fq = fwu / 0.3;
		float grout = max(filtered_pulse(q.x, fq.x, 0.0, 0.04), filtered_pulse(q.y, fq.y, 0.0, 0.04));
		col = base * (0.9 + 0.2 * hash12(floor(q) + seed));
		col *= 1.0 - 0.45 * grout;
		float frost = (1.0 - smoothstep(0.0, 1.8, uv.y)) * smoothstep(0.3, 0.7, value_noise(uv * 1.5 + seed));
		col = mix(col, il_frost, frost * 0.55 * (0.3 + il_snow_amount));
	} else {
		float edge = min(min(uv.x, 1.2 - uv.x), min(uv.y, 2.4 - uv.y));
		col *= 1.0 - 0.5 * band(edge, 0.0, 0.03, aa);
		float ring = abs(length(uv - vec2(0.9, 1.15)) - 0.2);
		col = mix(col, base * 1.6 + 0.03, (1.0 - smoothstep(0.02, 0.03 + aa, ring)) * 0.7);
		led = 1.0 - smoothstep(0.03, 0.045 + aa, length(uv - vec2(0.9, 1.8)));
	}
	if (led > 0.5) {
		return il_screen * 0.8;
	}
	return col;
}

// PAT_IL_SCREEN (115): a console or wall screen, pale and dim, never a face (the wall screens stay data): UV in metres
// from the lower left, param = a seed (0-99) + 100 * the width in decimetres + 10000 * the height in decimetres. A frame,
// then one of four dull readouts by seed: columns of a bar graph, a waveform, scanning rings, rows of dashes (no letters,
// no symbols). The screen's colour is COLOR (the skin's screen colour, a pale blue-white); it glows at COLOR.a, steady.
vec3 il_screen_surface(vec3 base, vec2 uv, float param, inout float glow) {
	int v = int(param + 0.5);
	float seed = float(v % 100);
	float wd = float((v / 100) % 100) * 0.1;
	float ht = float(v / 10000) * 0.1;
	vec2 fwu = max(fwidth(uv), vec2(1e-4));
	vec2 e = min(uv, vec2(wd, ht) - uv);
	float inner = band(min(e.x, e.y), 0.06, 100.0, max(fwu.x, fwu.y));
	vec2 c = (uv - vec2(0.06)) / max(vec2(wd, ht) - vec2(0.12), vec2(0.1));
	float kind = mod(seed, 4.0);
	float on = 0.0;
	if (kind < 0.5) {
		float col_i = floor(c.x * 14.0);
		float hgt = 0.15 + 0.7 * hash12(vec2(col_i, seed));
		on = step(fract(c.x * 14.0), 0.7) * step(c.y, hgt);
	} else if (kind < 1.5) {
		float y = 0.5 + 0.28 * sin(c.x * 11.0 + seed) + 0.12 * sin(c.x * 27.0 + seed * 2.0);
		on = 1.0 - smoothstep(0.02, 0.05, abs(c.y - y));
	} else if (kind < 2.5) {
		float r = length((c - 0.5) * vec2(wd / max(ht, 0.1), 1.0));
		on = max(1.0 - smoothstep(0.01, 0.025, abs(r - 0.18)), 1.0 - smoothstep(0.01, 0.025, abs(r - 0.34)));
		on = max(on, (1.0 - smoothstep(0.004, 0.012, abs(c.x - 0.5))) * 0.6);
	} else {
		float row = floor(c.y * 9.0);
		float len = 0.25 + 0.65 * hash12(vec2(row, seed));
		on = step(fract(c.y * 9.0), 0.4) * step(c.x, len) * step(0.15, hash12(vec2(row, seed + 3.0)));
	}
	float lit = mix(0.35, 1.0, on);
	glow *= inner * lit + (1.0 - inner) * 0.35;
	return mix(base * 0.25, base, inner * (0.3 + 0.7 * lit));
}

// PAT_IL_LAMP (116): a small amber machine lamp: the colour is the vertex colour; param = a seed. It glows at COLOR.a,
// dim and steady; a hashed share of them breathe slowly (a smooth swell every few seconds, never a strobe), and hold
// their level with Reduced flashing (the global `reduced_flashing`). The only time-driven thing here besides the jars'
// bubbles, which are motion, not a flash.
vec3 il_lamp_surface(vec3 base, float param, float t, inout float glow) {
	float ph = hash11(floor(param + 0.5) * 0.713 + 2.0);
	float swell = 0.5 + 0.5 * sin(t * (0.9 + 0.5 * ph) + ph * 20.0);
	float breathes = step(0.55, ph);
	glow *= mix(1.0, 0.7 + 0.3 * swell, breathes * (1.0 - reduced_flashing));
	return base;
}

// PAT_IL_JAR (117): the liquid behind a specimen (UV.x -1 to 1 across the jar, UV.y 0 to 1 up it): pale, desaturated
// cyan, brighter in the middle and darker toward the glass's edges and its top, a few tiny bubbles rising. param 0 a
// brain jar, 1 an Octodog's (a touch greyer). It glows at COLOR.a, dim and steady; only the bubbles move.
vec3 il_jar_surface(vec3 base, vec2 uv, float param, float t) {
	float kind = floor(param + 0.5);
	float across = 1.0 - uv.x * uv.x;
	vec3 col = base * (0.45 + 0.55 * across) * (1.0 - 0.2 * smoothstep(0.55, 1.0, uv.y));
	col = mix(col, vec3(dot(col, vec3(0.333))), 0.25 * kind);
	float lane = floor((uv.x + 1.0) * 2.5);
	float h = hash11(lane * 3.1 + kind * 7.0);
	float rise = fract(uv.y * 2.2 - t * (0.05 + 0.04 * h) + h * 5.0);
	float bx = (fract((uv.x + 1.0) * 2.5) - 0.5) * 0.7;
	float bub = (1.0 - smoothstep(0.03, 0.06, length(vec2(bx - (h - 0.5) * 0.3, (rise - 0.5) * 0.45))));
	col = mix(col, il_screen, bub * 0.55);
	return col;
}

// PAT_IL_BRAIN (118): a brain, lit (pink-grey, folds as dark creases, a wet sheen), for the jars. From world position.
vec3 il_brain_surface(vec3 base, vec3 w, vec3 n, vec3 eye) {
	vec3 p3 = w * 9.0;
	float f = value_noise(p3.xy + p3.z * 0.7) * 0.6 + value_noise(p3.zy * 1.9 + p3.x) * 0.4;
	float crease = 1.0 - smoothstep(0.0, 0.1, abs(f - 0.5));
	vec3 col = base * (0.85 + 0.3 * f) * (1.0 - 0.45 * crease);
	col += il_screen * il_graze(n, eye) * 0.2;
	return min(col, vec3(0.8));
}

// PAT_IL_SNOW (119): a drift of packed snow (geometry gives it its shape): bright blue-white with lumps, blue hollows and
// a few standing glints. From world position. Never glowing.
vec3 il_snow_surface(vec3 base, vec3 w, vec3 n, vec3 eye) {
	vec2 p = il_plane(w, n);
	vec2 fwp = max(fwidth(p), vec2(1e-4));
	float detail = 1.0 - smoothstep(0.03, 0.14, max(fwp.x, fwp.y));
	float lump = value_noise(p * 1.6 + 5.0) * 0.6 + value_noise(p * 5.0) * 0.4;
	vec3 col = base * (0.86 + 0.28 * lump);
	col = mix(col, il_ice * 0.9, (1.0 - lump) * 0.25);
	float speck = step(0.985, hash12(floor(p * 38.0))) * detail;
	col += vec3(0.3) * speck * smoothstep(0.1, 0.5, il_graze(n, eye));
	return min(col, vec3(0.92));
}

// Dispatches the Ice Lab's patterns (ids 110-119) for kit_solid.gdshader.
vec3 ice_lab_surface(int pattern, float param, vec3 base, vec3 w, vec3 n, vec3 eye, vec2 uv, float t, inout float glow) {
	if (pattern == 110) {
		return il_grating(base, w, n, eye, uv, param);
	} else if (pattern == 111) {
		return il_under(base, w, n, param);
	} else if (pattern == 112) {
		return il_steel(base, w, n, eye, param, t);
	} else if (pattern == 113) {
		return il_ice_surface(base, w, n, eye, param);
	} else if (pattern == 114) {
		return il_panel(base, w, n, uv, param);
	} else if (pattern == 115) {
		return il_screen_surface(base, uv, param, glow);
	} else if (pattern == 116) {
		return il_lamp_surface(base, param, t, glow);
	} else if (pattern == 117) {
		return il_jar_surface(base, uv, param, t);
	} else if (pattern == 118) {
		return il_brain_surface(base, w, n, eye);
	} else if (pattern == 119) {
		return il_snow_surface(base, w, n, eye);
	}
	return base;
}

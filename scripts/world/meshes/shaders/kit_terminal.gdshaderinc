// The Terminal's surfaces for the solid kit shader (kit_solid.gdshader): pattern ids 100-108
// (MeshKit.PAT_TERMINAL_*, task O4), in their own file so other zones' patterns never collide with them.
// GDD §5, Zone 8: an abandoned subway under the city, wet black stone, rust and verdigris, vine green,
// sodium lamplight through haze (docs/art/reference/terminal_zone.jpg). Nothing here is neon: the lamps
// are the only thing that glows, an orange sodium amber (GDD §5, looser in the later zones: as the owner asked) at a
// fraction of a gap edge's brightness and up in the hall, and the dead boards and the red-orange plates are matte paint.
// Each function takes the fragment's world position `w`, world normal `n`, the eye vector `eye` (world,
// from the surface toward the camera), UV and the pattern parameter, and returns the albedo (sRGB, like
// COLOR); the kit then lights it like any lit surface. Pixel footprints are taken at the top of each
// pattern's function and passed down (docs/ARCHITECTURE.md, Zone skins: the kit's shader rules).
//
// The light. The kit has no real lights, so the Terminal paints its own: a work lamp hangs from the vault
// every `tm_pitch` metres (the lamp k at z = -(k + 0.5) * tm_pitch, `tm_lamp_y` up, in the middle of the
// street), and the far walls carry a lamp of their own half a pitch off. Each lamp is dead, failing or
// burning, by a hash of its index: the failing ones sag and dip now and then, and the dips hold still
// with Reduced flashing (the global `reduced_flashing`). The skin only places the fixtures (MeshKit
// PAT_TERMINAL_LAMP); how they burn is decided here, from where they stand, so the fixture and the pool of
// light under it always agree.
//
// DESIGN-TBD (docs/questions/o4.md item 5): the palette, how dark the hall is and how bright and how many the lamps are
// (the lamps' reach and falloff in tm_pool and tm_wall_pool, the dead and failing shares in tm_burn). The work lamps'
// colour is the owner's: orange, with their light on the stone painted the same colour (tm_lit).
//
// The skin sets every colour below as an sRGB Vector3 (TerminalSkin.srgb()), like vertex colours: a Color
// would arrive already linear on Forward+ but not on the Compatibility renderer.
uniform vec3 tm_lamp = vec3(0.98, 0.6, 0.08);
// What wet stone and puddles catch of the lamps' haze.
uniform vec3 tm_haze = vec3(0.42, 0.26, 0.14);
uniform vec3 tm_rust = vec3(0.4, 0.2, 0.09);
uniform vec3 tm_green = vec3(0.2, 0.4, 0.34);
uniform vec3 tm_vine = vec3(0.14, 0.27, 0.09);
// How wet it all looks (0 dry), the lamps' pitch along the track, how high the crown lamps hang and the far
// walls' lamps are, and how much of the lamps' light the scenery takes. (The width of a lane, for the track's
// rails and seams, is not set here: the skin reads it off each floor piece's box and passes it in the pattern's
// parameter, tm_half_width(), so a level with other lane widths needs nothing changed.)
uniform float tm_wet = 0.7;
uniform float tm_pitch = 18.0;
uniform float tm_lamp_y = 8.4;
uniform float tm_wall_lamp_y = 4.4;
uniform float tm_lamp_gain = 1.0;
// How far the far walls' tiles reach up (world height) and where the tiled band starts.
uniform float tm_tile_top = 2.4;

// The half width of the lane (or the gutter) a floor pattern is drawn on, in metres, from the pattern's
// parameter: centimetres, in the parameter's bits from 3 up (TerminalTrack.half_width_param). UV.x runs -1 to 1
// across it, so UV.x * half is the distance from its middle in metres. A parameter without one (nothing the skin
// draws) reads as a 1.2 m half lane, the shipped lane width's.
float tm_half_width(float param) {
	float cm = float(int(param + 0.5) >> 3);
	return cm > 0.5 ? cm * 0.01 : 1.2;
}

// How brightly lamp `k` burns (0 to 1) at time t: a fifth are dead, a third failing (dim, with a brownout
// every few seconds, slow and smooth: never a strobe), the rest steady. Reduced flashing: the failing
// ones hold their dim level.
float tm_burn(float k, float t) {
	float r = hash11(k * 0.917 + 3.1);
	if (r < 0.18) {
		return 0.0;
	}
	if (r < 0.5) {
		float ph = fract(t * 0.31 + r * 9.0);
		float dip = smoothstep(0.0, 0.03, ph) * (1.0 - smoothstep(0.07, 0.22, ph));
		return mix(0.52, 0.66 - 0.5 * dip, 1.0 - reduced_flashing);
	}
	return 1.0;
}

// The light of the crown lamps on point `w` facing `n` (0 where none reaches, about 0.3 under a burning
// lamp): the two lamps round it, falling off with the square of the distance, a little less on faces turned away.
float tm_pool(vec3 w, vec3 n, float t) {
	float k0 = floor(-w.z / tm_pitch - 0.5);
	float lit = 0.0;
	for (int i = 0; i < 2; i++) {
		float k = k0 + float(i);
		vec3 d = vec3(0.0, tm_lamp_y, -(k + 0.5) * tm_pitch) - w;
		float d2 = dot(d, d);
		float facing = 0.5 + 0.5 * clamp(dot(n, d * inversesqrt(max(d2, 1e-3))), 0.0, 1.0);
		lit += tm_burn(k, t) * facing * exp(-d2 / 52.0);
	}
	return lit * tm_lamp_gain;
}

// The far walls' own lamps (half a pitch off the crown ones), by distance along the wall and height: the
// light every point of a wall gets from them, since all of a wall is the same distance out.
float tm_wall_pool(vec3 w, float t) {
	float k0 = floor(-w.z / tm_pitch);
	float lit = 0.0;
	for (int i = 0; i < 2; i++) {
		float k = k0 + float(i);
		float dz = w.z + k * tm_pitch;
		float dy = w.y - tm_wall_lamp_y;
		lit += tm_burn(k + 100.0, t) * exp(-(dz * dz + dy * dy) / 26.0);
	}
	return lit * tm_lamp_gain * 0.7;
}

// A lit colour: the albedo warmed and brightened by the light that reaches it. Never past 0.9 (the kit's
// glow threshold is above what a pool reaches, so a pool never blooms).
vec3 tm_lit(vec3 base, float lit) {
	vec3 warm = mix(vec3(1.0), mix(tm_lamp, vec3(1.0), 0.2) * 1.15, clamp(lit * 1.7, 0.0, 0.85));
	return min(base * warm * (0.62 + 1.5 * lit), vec3(0.9));
}

// The sheen wet stone and water give back at grazing angles: the lamps' haze, stronger toward the lamps.
float tm_graze(vec3 n, vec3 eye) {
	return pow(1.0 - clamp(dot(n, eye), 0.0, 1.0), 3.0);
}

// PAT_TERMINAL_TRACK (100): a lane of track bed: gravel ballast, a sleeper every 0.64 m along the lane, a pair
// of rails 1.44 m apart (a steel head, a darker foot, rust running down them), black cables snaking over
// it, puddles catching the lamps and the dark seam between lanes. UV.x -1 to 1 across the lane; param = the
// lane's half width in centimetres times 8 (tm_half_width). Everything comes from world position, so it lines up
// across chunk cuts, and the sleepers and rails stream past underfoot as the still floor's own sense of speed.
// Nothing glows.
vec3 tm_track(vec3 base, vec3 w, vec3 n, vec3 eye, vec2 uv, float param, float t) {
	vec2 p = w.xz;
	vec2 fwp = max(fwidth(p), vec2(1e-4));
	float aa = max(fwp.x, fwp.y);
	float half_w = tm_half_width(param);
	float fu = max(fwidth(uv.x), 1e-4) * half_w;
	float x = uv.x * half_w;
	float detail = 1.0 - smoothstep(0.03, 0.16, aa);
	float lit = tm_pool(w, n, t);
	// The ballast: broken stone, lighter than the dark bed under it.
	float gravel = value_noise(p * 6.0) * 0.55 + (detail > 0.01 ? value_noise(p * 17.0 + 2.0) * 0.45 : 0.225);
	vec3 col = base * (0.78 + 0.5 * mix(0.5, gravel, 0.4 + 0.6 * detail)) * (0.9 + 0.2 * value_noise(p * 0.3 + 4.0));
	// A sleeper under every 0.64 m: dark wood, cracked, each its own tone, in 2.2 m lengths across the lane.
	float sz = p.y / 0.64;
	float idx = floor(sz);
	float lane_id = floor(w.x / (half_w * 2.0) + 0.5);
	float across = 1.0 - smoothstep(1.06, 1.1, abs(x));
	float sleeper = filtered_pulse(sz, fwp.y / 0.64, 0.17, 0.63) * across;
	float tone = hash12(vec2(idx, lane_id * 1.7));
	vec3 wood = vec3(0.24, 0.17, 0.12) * (0.7 + 0.6 * tone);
	wood *= 0.85 + 0.3 * value_noise(vec2(x * 2.0, idx * 3.1 + lane_id));
	float crack = step(0.82, tone) * thin_bar(x - (tone - 0.9) * 6.0, 0.012, fu) * detail;
	wood *= 1.0 - 0.6 * crack;
	col = mix(col, wood, sleeper * 0.94);
	// The rails: a steel head on a dark foot, rust streaked along them, a glint where the lamps are.
	float rx = abs(abs(x) - 0.72);
	float foot = thin_bar(rx, 0.085, fu) * 0.9;
	float head = thin_bar(rx, 0.032, fu);
	float rust = smoothstep(0.35, 0.8, value_noise(vec2(w.x * 3.0, p.y * 0.4) + 3.0));
	vec3 rail = mix(vec3(0.32, 0.28, 0.25), tm_rust * 0.85, rust * 0.55);
	col = mix(col, vec3(0.07, 0.06, 0.055), foot);
	col = mix(col, rail * (0.7 + 1.1 * lit), head);
	// Cables: some stretches of the bed have a black cable snaking along it.
	float cell = floor(p.y / 13.0);
	float ch = hash12(vec2(cell, lane_id * 3.3 + 1.0));
	float cx = 0.38 * sin(p.y * 0.55 + ch * 40.0) + (ch - 0.5) * 0.6;
	float cable = step(0.5, ch) * thin_bar(x - cx, 0.026, fu) * smoothstep(0.0, 0.5, fract(p.y / 13.0)) * (1.0 - smoothstep(0.88, 1.0, fract(p.y / 13.0)));
	col = mix(col, vec3(0.035, 0.033, 0.035) * (1.0 + 2.0 * lit), cable * 0.95);
	// The seam between lanes: a dark line, so the lanes read.
	col *= 1.0 - 0.55 * thin_bar(abs(x) - half_w, 0.03, fu);
	// Oil and wet patches, then puddles in the dips: dark, glossy, the lamps in them at grazing angles.
	col *= 1.0 - 0.25 * smoothstep(0.55, 0.85, value_noise(p * 0.45 + 11.0));
	float pn = value_noise(p * vec2(0.8, 0.5) + 7.0) * 0.6 + value_noise(p * 2.1 + 1.0) * 0.4;
	float puddle = smoothstep(0.64, 0.72, pn) * tm_wet;
	vec3 mirror = mix(vec3(0.085, 0.08, 0.078), tm_haze * (0.35 + 1.5 * lit), 0.15 + 0.85 * tm_graze(n, eye));
	col = mix(tm_lit(col, lit), mirror, puddle * 0.8 * (1.0 - 0.3 * sleeper));
	return col;
}

// PAT_TERMINAL_PLATFORM (101): a platform's concrete (the outer lanes: GDD §5, the track bed and platforms):
// cast slabs with joints across every 4.8 m and along every 2.4 m, stains and scuffs, drips running down
// from the edge, puddles, and along the edge that faces the track a worn tactile strip of pale studs.
// UV.x -1 to 1 across the lane; param = flags in the low three bits (1 the strip is on the lane's left edge, 2 on its
// right edge, 4 the gutter between the lane and the wall: no strip) plus the lane's (or gutter's) half width in
// centimetres times 8 (tm_half_width).
vec3 tm_platform(vec3 base, vec3 w, vec3 n, vec3 eye, vec2 uv, float param, float t) {
	vec2 p = w.xz;
	vec2 fwp = max(fwidth(p), vec2(1e-4));
	float aa = max(fwp.x, fwp.y);
	float half_w = tm_half_width(param);
	float fu = max(fwidth(uv.x), 1e-4) * half_w;
	float detail = 1.0 - smoothstep(0.03, 0.14, aa);
	int flags = int(param + 0.5) & 7;
	float x = uv.x * half_w;
	float lit = tm_pool(w, n, t);
	vec3 col = base * (0.82 + 0.34 * value_noise(p * 0.55 + 2.0)) * (0.92 + 0.16 * hash12(floor(p / vec2(2.4, 4.8))));
	col *= 1.0 + 0.12 * detail * (value_noise(p * 9.0) - 0.5);
	float joint = max(grid_line(p.y, 4.8, 0.02), 0.7 * grid_line(p.x + 0.4, 2.4, 0.014));
	col *= 1.0 - 0.45 * joint;
	col *= 1.0 - 0.3 * smoothstep(0.5, 0.82, value_noise(p * vec2(0.9, 0.3) + 5.0));
	// The tactile strip along the edge that faces the track: 0.5 m of pale studs on a worn band.
	float edge_d = 9.0;
	if ((flags & 4) == 0) {
		if ((flags & 1) != 0) {
			edge_d = x + half_w;
		} else if ((flags & 2) != 0) {
			edge_d = half_w - x;
		}
	}
	float strip = band(edge_d, 0.0, 0.5, fu);
	vec2 sp = vec2(edge_d, p.y) / 0.11;
	float stud = (1.0 - smoothstep(0.26, 0.4, length(fract(sp) - 0.5))) * detail;
	col = mix(col, base * 1.4 + 0.03, strip * 0.6);
	col = mix(col, base * 1.85 + 0.05, strip * stud * 0.7 * (0.5 + 0.5 * value_noise(p * 1.7)));
	col *= 1.0 - 0.5 * thin_bar(edge_d - 0.52, 0.02, fu);
	// Stains and drips.
	float drip = smoothstep(0.62, 0.9, value_noise(vec2(p.x * 3.0, p.y * 0.18) + 9.0));
	col = mix(col, col * 0.55, drip * 0.5);
	float pn = value_noise(p * vec2(0.7, 0.45) + 17.0) * 0.6 + value_noise(p * 1.9 + 3.0) * 0.4;
	float puddle = smoothstep(0.66, 0.74, pn) * tm_wet;
	vec3 mirror = mix(vec3(0.09, 0.085, 0.082), tm_haze * (0.35 + 1.5 * lit), 0.15 + 0.85 * tm_graze(n, eye));
	return mix(tm_lit(col, lit), mirror, puddle * 0.75);
}

// PAT_TERMINAL_UNDER (102): everything under the track bed, seen only through the holes: a service level,
// deep shade that only darkens with depth, with the faint ghost of ribs and a pipe run near the top and
// a floor of black, still water. COLOR is the shade at the street's level (darkens it): param 0 a face across
// the lane, 1 a face along it, 2 the pit's floor. Nothing here is ever lighter than COLOR.
vec3 tm_under(vec3 base, vec3 w, vec3 n, float param) {
	float mode = floor(param + 0.5);
	float h = abs(n.x) > 0.5 ? w.z : w.x;
	float fh = max(fwidth(h), 1e-4);
	float fy = max(fwidth(w.y), 1e-4);
	if (mode > 1.5) {
		return base * (0.22 + 0.2 * value_noise(w.xz * 0.5 + 3.0));
	}
	float rib = filtered_pulse(h / 1.8, fh / 1.8, 0.0, 0.07);
	float pipe = clamp(band(w.y, -1.7, -1.2, fy) + 0.6 * band(w.y, -2.6, -2.2, fy), 0.0, 1.0);
	float depth = mix(1.0, 0.15, smoothstep(-0.1, -3.2, w.y));
	return base * (0.9 - 0.3 * rib - 0.2 * pipe) * depth;
}

// PAT_TERMINAL_WALL (103): wet black stone. param 0 the far wall of the hall: a band of old white tile (grimy
// cream and green-grey, bricks of 0.3 by 0.15 m, some fallen off, the rest streaked and stained) up to
// `tm_tile_top`, black ashlar over it in courses of 0.45 m with white salt weeping down the joints and moss in
// the lower courses, the far walls' lamps' pools on it. param 1 the vault: big stone voussoirs, a rib band at
// every lamp, water stains running down from the ribs and the lamps' light on it from below. UV (vault): x metres along the arch, y metres
// along the track. param 2 plain old concrete (a kerb, a plinth, a pier's base): form lines, stains and
// grime, from world position.
vec3 tm_wall(vec3 base, vec3 w, vec3 n, vec3 eye, vec2 uv, float param, float t) {
	float mode = floor(param + 0.5);
	vec2 p = abs(n.y) > 0.5 ? w.xz : (abs(n.x) > 0.5 ? w.zy : w.xy);
	if (mode > 0.5 && mode < 1.5) {
		p = uv;
	}
	vec2 fwp = max(fwidth(p), vec2(1e-4));
	float aa = max(fwp.x, fwp.y);
	float detail = 1.0 - smoothstep(0.04, 0.2, aa);
	float lit = tm_pool(w, n, t);
	vec3 col = base;
	if (mode < 0.5) {
		float wall_lit = tm_wall_pool(w, t);
		lit = lit + wall_lit;
		// Tile below, stone above, a ragged edge between them.
		float edge = tm_tile_top + 0.25 * sin(p.x * 0.7) + 0.2 * (value_noise(vec2(p.x * 0.35, 3.0)) - 0.5);
		float tiled = 1.0 - smoothstep(-0.03, 0.03, p.y - edge);
		// Only the part of the wall a pixel is on is worked out.
		vec3 tile = vec3(0.0);
		vec3 stone = vec3(0.0);
		if (tiled > 0.001) {
			// Tile: 0.3 by 0.15 in running bond, grout, a tone each, some fallen off.
			vec2 q = vec2(p.x / 0.3, p.y / 0.15);
			q.x += 0.5 * mod(floor(q.y), 2.0);
			vec2 fq = fwp / vec2(0.3, 0.15);
			float grout = max(filtered_pulse(q.x, fq.x, 0.0, 0.07), filtered_pulse(q.y, fq.y, 0.0, 0.1));
			vec2 cell = floor(q);
			float th = hash12(cell + 31.0);
			tile = mix(vec3(0.52, 0.5, 0.42), vec3(0.3, 0.38, 0.34), step(0.78, th)) * (0.7 + 0.5 * th);
			tile *= 0.65 + 0.35 * smoothstep(0.0, 1.4, p.y - (-1.0));
			float fallen = step(0.93, hash12(cell + 7.0)) * detail;
			tile = mix(tile, base * 0.5, fallen);
			tile *= 1.0 - 0.5 * grout;
			tile *= 1.0 - 0.45 * smoothstep(0.5, 0.82, value_noise(vec2(p.x * 1.1, p.y * 0.25) + 5.0));
		}
		if (tiled < 0.999) {
			// Ashlar: courses 0.45 high, blocks 0.9 to 1.5 long, joints, wet streaks, salt, moss.
			float course = floor(p.y / 0.45);
			float bw = 0.9 + 0.6 * hash11(course * 3.7);
			float bx = p.x / bw + hash11(course * 7.3);
			float joint = max(filtered_pulse(bx, fwp.x / bw, 0.0, 0.025), filtered_pulse(p.y / 0.45, fwp.y / 0.45, 0.0, 0.035));
			float bh = hash12(vec2(floor(bx), course));
			stone = base * (0.65 + 0.7 * bh) * (0.85 + 0.3 * value_noise(p * 1.7));
			stone *= 1.0 - 0.55 * joint;
			float salt = smoothstep(0.7, 0.95, value_noise(vec2(p.x * 2.2, p.y * 0.2) + 1.0)) * (1.0 - joint * 0.3);
			stone = mix(stone, vec3(0.5, 0.5, 0.46) * (0.5 + 0.5 * bh), salt * 0.4);
			float moss = smoothstep(0.55, 0.85, value_noise(p * vec2(1.3, 0.9) + 13.0)) * (1.0 - smoothstep(2.0, 6.5, p.y));
			stone = mix(stone, tm_vine * (0.6 + 0.8 * bh), moss * 0.55);
		}
		col = mix(stone, tile, tiled);
		float wetness = tm_wet * (0.6 + 0.4 * smoothstep(0.5, 0.9, value_noise(vec2(p.x * 1.6, p.y * 0.15) + 2.0)));
		col = tm_lit(col, lit);
		col = mix(col, tm_haze * (0.5 + 1.6 * lit) , clamp(tm_graze(n, eye) * wetness * 0.5, 0.0, 0.5));
	} else if (mode < 1.5) {
		// The vault: voussoirs 0.8 along the arch by 0.5 along the track, ribs bands at every lamp, water
		// stains coming down from them. p = (arch metres, track metres).
		float pitch = tm_pitch;
		float rz = abs(fract(-w.z / pitch - 0.5 + 0.5) - 0.5) * pitch;
		float rib = 1.0 - smoothstep(0.55, 0.75, rz);
		vec2 q = vec2(p.x / 0.8, p.y / 0.5);
		q.x += 0.5 * mod(floor(q.y), 2.0);
		vec2 fq = fwp / vec2(0.8, 0.5);
		float joint = max(filtered_pulse(q.x, fq.x, 0.0, 0.03), filtered_pulse(q.y, fq.y, 0.0, 0.05));
		float bh = hash12(floor(q) + 5.0);
		col = base * (0.7 + 0.6 * bh) * (0.8 + 0.4 * value_noise(p * 0.6));
		col *= 1.0 - 0.5 * joint;
		float stain = smoothstep(0.55, 0.9, value_noise(vec2(p.x * 0.5, p.y * 1.6) + 3.0));
		col = mix(col, col * 0.5, stain * 0.55);
		col = mix(col, col * 0.7, rib * 0.5);
		col = tm_lit(col, lit * 1.2);
	} else {
		float upright = step(abs(n.y), 0.5);
		col = base * (0.78 + 0.4 * value_noise(p * 0.7 + 2.0));
		float board = mix(grid_line(w.z + 0.4, 2.4, 0.015), grid_line(w.y, 0.6, 0.012), upright);
		col *= 1.0 - 0.18 * board;
		col *= 1.0 - 0.4 * upright * smoothstep(0.55, 0.9, value_noise(vec2(p.x * 2.4, p.y * 0.25) + 9.0));
		col *= 1.0 + 0.1 * detail * (value_noise(p * 8.0) - 0.5);
		col = mix(col, tm_vine * 0.8, upright * smoothstep(0.62, 0.9, value_noise(p * 1.1 + 4.0)) * 0.4 * (1.0 - smoothstep(0.5, 3.0, p.y)));
		col = tm_lit(col, lit);
	}
	return col;
}

// PAT_TERMINAL_STEEL (104): old painted steel: plates with seams and rivets, the paint (COLOR, verdigris
// green) flaking away to rust in blooms, rust running down in streaks. param 0 plating (piers, girders,
// brackets; world position), 1 an underside ridden upside down (beams every 3 m across it that stream past a
// player riding it), 2 bare rusted rebar and tie-rods (all rust).
vec3 tm_steel(vec3 base, vec3 w, vec3 n, vec3 eye, float param, float t) {
	float mode = floor(param + 0.5);
	vec2 p = abs(n.y) > 0.5 ? w.xz : (abs(n.x) > 0.5 ? w.zy : w.xy);
	vec2 fwp = max(fwidth(p), vec2(1e-4));
	float aa = max(fwp.x, fwp.y);
	float detail = 1.0 - smoothstep(0.03, 0.14, aa);
	float upright = step(abs(n.y), 0.5);
	float lit = tm_pool(w, n, t);
	vec2 q = p / vec2(1.4, 1.1);
	vec2 fq = fwp / vec2(1.4, 1.1);
	float seam = max(filtered_pulse(q.x, fq.x, 0.0, 0.02), filtered_pulse(q.y, fq.y, 0.0, 0.026));
	vec3 rust = tm_rust * (0.55 + 0.6 * value_noise(p * 2.3 + 8.0));
	vec3 paint = base * (0.75 + 0.5 * value_noise(p * 0.8 + 3.0));
	float bloom = smoothstep(0.5, 0.82, value_noise(p * 1.3 + 17.0) * 0.7 + value_noise(p * 4.0) * 0.3);
	float streak = upright * smoothstep(0.55, 0.85, value_noise(vec2(p.x * 3.5, p.y * 0.3) + 5.0));
	float bare = clamp(max(bloom, streak * 0.7) * 1.1 + (mode > 1.5 ? 2.0 : 0.0), 0.0, 1.0);
	// Under a ceiling the paint holds better than on a pier (less rust over the whole flat of it).
	bare *= mode > 0.5 && mode < 1.5 ? 0.6 : 1.0;
	vec3 col = mix(paint, rust, bare * 0.75);
	col *= 1.0 - 0.4 * seam * (mode > 1.5 ? 0.0 : 1.0);
	// Rivets along every seam.
	vec2 rp = vec2((fract(p.x / 0.28) - 0.5) * 0.28, fract(q.y) - 0.07);
	float rivet = (1.0 - smoothstep(0.03 - aa, 0.03 + aa, length(rp))) * detail * step(0.5, 1.0 - mode * 0.5);
	col = mix(col, col * 1.6 + 0.03, rivet * 0.5);
	if (mode > 0.5 && mode < 1.5) {
		float bq = w.z / 3.0;
		float beam = filtered_pulse(bq, fwp.y / 3.0, 0.0, 0.1);
		col *= 1.0 - 0.4 * beam;
	}
	// A little of the lamps' haze at grazing angles, as on wet metal.
	col = tm_lit(col, lit);
	col = mix(col, tm_haze * (0.5 + 1.4 * lit), clamp(tm_graze(n, eye) * tm_wet * 0.3, 0.0, 0.3));
	return col;
}

// PAT_TERMINAL_CAR (105): the side of a rusted subway car (UV in metres: x along the car from its end, y up from
// its floor; param = the car's seed 0-99): a dark skirt, flaking paint (COLOR) over rust, a band of
// windows in every 2.0 m bay (dark panes in frames, some broken to black), a pair of doors every fourth bay, a rounded
// roof, and vine growing down from the roof into the windows. Matte, never glowing.
vec3 tm_car(vec3 base, vec3 w, vec3 n, vec3 eye, vec2 uv, float param, float t) {
	float seed = floor(param + 0.5);
	vec2 fwu = max(fwidth(uv), vec2(1e-4));
	float aa = max(fwu.x, fwu.y);
	float lit = tm_pool(w, n, t);
	float bay = 2.0;
	float bi = floor(uv.x / bay);
	vec2 b = vec2((fract(uv.x / bay) - 0.5) * bay, uv.y);
	float door = step(0.5, 1.0 - mod(bi, 4.0));
	// Paint over rust, streaked down from the roof and the window sills.
	float bloom = smoothstep(0.4, 0.75, value_noise(uv * vec2(0.9, 1.3) + seed));
	float streak = smoothstep(0.5, 0.85, value_noise(vec2(uv.x * 3.0, uv.y * 0.35) + seed * 2.0));
	vec3 paint = base * (0.7 + 0.5 * value_noise(uv * 0.7 + seed * 3.0));
	vec3 col = mix(paint, tm_rust * (0.5 + 0.6 * value_noise(uv * 2.0)), clamp(max(bloom * 0.65, streak * 0.6), 0.0, 1.0));
	// The skirt, the belt line and the roof's curve.
	col *= mix(0.4, 1.0, smoothstep(0.1, 0.55, uv.y));
	col = mix(col, tm_rust * 0.7, band(uv.y, 0.55, 0.62, aa) * 0.6);
	// Windows: panes 1.2 by 0.95 in a frame, between 1.25 and 2.2 m; doors the whole bay.
	float wx = abs(b.x);
	float win = band(wx, -1.0, 0.6, fwu.x) * band(uv.y, 1.25, 2.2, fwu.y) * (1.0 - door);
	float pane_h = hash12(vec2(bi, seed));
	vec3 pane = vec3(0.025, 0.03, 0.03) * (0.6 + 0.9 * pane_h) + tm_haze * 0.06 * lit * smoothstep(1.2, 2.2, uv.y);
	pane = mix(pane, vec3(0.012), step(0.7, pane_h));
	float frame = band(wx, 0.6, 0.72, fwu.x) * band(uv.y, 1.17, 2.28, fwu.y) * (1.0 - door)
		+ band(wx, -1.0, 0.72, fwu.x) * (band(uv.y, 1.17, 1.25, fwu.y) + band(uv.y, 2.2, 2.28, fwu.y)) * (1.0 - door);
	col = mix(col, col * 0.55, clamp(frame, 0.0, 1.0));
	col = mix(col, pane, win);
	// Doors: a dark leaf pair with a seam down the middle, in the fourth bay of every four.
	float leaf = band(wx, -1.0, 0.68, fwu.x) * band(uv.y, 0.3, 2.4, fwu.y) * door;
	col = mix(col, base * 0.45 * (0.7 + 0.5 * value_noise(uv * 3.0)), leaf);
	col = mix(col, vec3(0.02), thin_bar(b.x, 0.012, fwu.x) * leaf);
	// Vine hanging from the roof: leafy streaks coming down into the windows.
	float roof = clamp((uv.y - 2.2) / 1.2, 0.0, 1.0);
	float hang = smoothstep(0.45, 0.8, value_noise(vec2(uv.x * 2.2, uv.y * 0.5) + seed * 5.0)) * smoothstep(0.6, 3.3, uv.y);
	float leafy = 0.6 + 0.8 * value_noise(uv * 9.0);
	col = mix(col, tm_vine * leafy, clamp(hang * 0.85 + roof * 0.35, 0.0, 0.92));
	col = tm_lit(col, lit);
	return col;
}

// PAT_TERMINAL_LAMP (106): a work lamp's tube and cage, glowing sodium amber by how that lamp burns
// (the same lamp the pools are painted from): dead ones are cold grey, failing ones dim, burning ones lit.
// param 0 a crown lamp (lamp k at z = -(k + 0.5) * tm_pitch), 1 one of the far walls' (at z = -k * tm_pitch), 2 the embers of a
// scavengers' fire barrel (always burning, steady, as dim as the lamps).
// `glow` comes in as the skin's vertex glow and leaves scaled by the burn.
vec3 tm_lamp_surface(vec3 base, vec3 w, float param, float t, inout float glow) {
	float ember = step(1.5, param);
	float wall = step(0.5, param) * (1.0 - ember);
	float k = floor(-w.z / tm_pitch - 0.5 * (1.0 - wall) + 0.5);
	float burn = mix(tm_burn(k + 100.0 * wall, t), 1.0, ember);
	glow *= burn;
	return mix(vec3(0.12, 0.115, 0.11), base, step(0.05, burn));
}

// PAT_TERMINAL_BOARD (107): a dead departure board or a plate on a pier, matte and unlit (UV in metres on the
// panel; param = a seed 0-99, plus 100 for a rust-red enamel plate). The board: dark glass in a worn frame, rows of
// faded dashes where the destinations were (no letters), a crack across a corner, grime rising from the bottom.
// The plate: dull brick-red enamel with a pale painted border inset from its edge and a bolt in each corner, chipped,
// rusted along its edges: no symbol (it is not a transport operator's roundel or any other logo), no word. Nothing
// glows.
vec3 tm_board(vec3 base, vec3 w, vec2 uv, float param, float t) {
	float code = floor(param + 0.5);
	float plate = step(100.0, code);
	float seed = mod(code, 100.0);
	vec2 fw = max(fwidth(uv), vec2(1e-4));
	float aa = max(fw.x, fw.y);
	float lit = tm_pool(w, vec3(0.0, 0.0, 1.0), t);
	vec3 col;
	if (plate > 0.5) {
		col = base * (0.7 + 0.5 * value_noise(uv * 3.0 + seed));
		vec2 e = min(uv, 1.0 - uv);
		float border = band(min(e.x, e.y), 0.07, 0.115, aa);
		col = mix(col, vec3(0.66, 0.58, 0.5) * 0.65, border * 0.85);
		float bolt = 1.0 - smoothstep(0.035, 0.05 + aa, length(abs(uv - 0.5) - vec2(0.3)));
		col = mix(col, vec3(0.09, 0.075, 0.065), bolt * 0.9);
		float chip = smoothstep(0.62, 0.85, value_noise(uv * 7.0 + seed * 2.0));
		col = mix(col, tm_rust * 0.7, chip * 0.6);
	} else {
		col = vec3(0.04, 0.045, 0.045) * (0.7 + 0.6 * value_noise(uv * 2.0 + seed));
		float rows = 4.0;
		float row = floor(uv.y / 0.22);
		float within = fract(uv.y / 0.22);
		float dash = band(within, 0.3, 0.62, fw.y / 0.22) * step(0.0, uv.x) * step(row, rows)
			* filtered_pulse(uv.x / 0.14, fw.x / 0.14, 0.0, 0.6) * step(0.2, hash12(vec2(floor(uv.x / 0.14), row + seed)));
		col = mix(col, vec3(0.22, 0.2, 0.17), dash * 0.5);
		float crack = thin_bar(uv.y - (0.15 + 0.3 * uv.x), 0.006 + aa * 0.5, aa);
		col = mix(col, vec3(0.012), crack * step(hash11(seed), 0.5) * 0.9);
		col *= 0.7 + 0.3 * smoothstep(0.0, 1.0, uv.y);
	}
	return tm_lit(col, lit);
}

// PAT_TERMINAL_VINE (108): foliage, opaque: dark green leaves in clumps, lighter tips and gaps showing black, for
// the vines hanging from piers and draped over roofs and walls (geometry gives each strand its shape). From world
// position. Never glowing.
vec3 tm_vine_surface(vec3 base, vec3 w, vec3 n, float t) {
	vec3 p3 = w * 6.0;
	float leaf = value_noise(p3.xy + p3.z * 0.7) * 0.6 + value_noise(p3.zy * 2.1 + p3.x) * 0.4;
	float lit = tm_pool(w, n, t);
	vec3 col = base * (0.5 + 0.9 * leaf);
	float gap = smoothstep(0.7, 0.8, value_noise(p3.xy * 1.4 + p3.z * 0.6 + 7.0) * 0.6 + value_noise(p3.zy * 3.1 + p3.x) * 0.4);
	col = mix(col, vec3(0.03, 0.045, 0.025), gap * 0.75);
	col = mix(col, tm_vine * 1.6, smoothstep(0.65, 0.9, leaf) * 0.5);
	return tm_lit(col, lit);
}

// Dispatches the Terminal's patterns (ids 100-108) for kit_solid.gdshader.
vec3 terminal_surface(int pattern, float param, vec3 base, vec3 w, vec3 n, vec3 eye, vec2 uv, float t, inout float glow) {
	if (pattern == 100) {
		return tm_track(base, w, n, eye, uv, param, t);
	} else if (pattern == 101) {
		return tm_platform(base, w, n, eye, uv, param, t);
	} else if (pattern == 102) {
		return tm_under(base, w, n, param);
	} else if (pattern == 103) {
		return tm_wall(base, w, n, eye, uv, param, t);
	} else if (pattern == 104) {
		return tm_steel(base, w, n, eye, param, t);
	} else if (pattern == 105) {
		return tm_car(base, w, n, eye, uv, param, t);
	} else if (pattern == 106) {
		return tm_lamp_surface(base, w, param, t, glow);
	} else if (pattern == 107) {
		return tm_board(base, w, uv, param, t);
	} else if (pattern == 108) {
		return tm_vine_surface(base, w, n, t);
	}
	return base;
}

// Marketplace surfaces for the solid kit shader (kit_solid.gdshader): pattern ids 20-29
// (MeshKit.PAT_CANVAS ...), in their own file so other zones' patterns don't collide with them.
// Each function takes the fragment's world position `w`, world normal `n`, UV and pattern
// parameter, and returns the albedo (sRGB, like COLOR). Glowing patterns also return a glow mask.
// Pixel footprints (fwidth) are taken where every pixel of a 2x2 block runs the same code (at the top
// of a pattern's function, whose pattern is the same over a whole face) and passed down: PAT_STALLS
// picks each stall's roof per pixel, and a derivative taken inside a branch that differs between
// neighbouring pixels is undefined (a NaN there becomes a white disc in the glow pass).

// The pale stripes on striped awnings.
uniform vec3 canvas_stripe : source_color = vec3(0.82, 0.8, 0.74);
// The stalls' frame: the pole across each stall's start and the valleys along the lanes' edges.
uniform vec3 canvas_pole : source_color = vec3(0.4, 0.34, 0.27);
// The stall rows (PAT_STALLS), laid out exactly as MarketStalls lays them out: slots along each lane,
// a stall covering 1-3 of them, its roof picked from these (sRGB, like COLOR).
uniform float stall_slot = 2.0;
uniform float stall_awning_share = 0.22;
uniform float stall_tin_share = 0.2;
uniform vec3 stall_canvas[4];
uniform vec3 stall_awning[2];
uniform vec3 stall_tin = vec3(0.47, 0.46, 0.44);
// Dust and wear (GDD §5: dustier and dirtier than the Neon City): the sand that settles on roofs
// and ledges (sRGB), and how much of it.
uniform vec3 market_dust : source_color = vec3(0.74, 0.67, 0.56);
uniform float market_dust_amount = 1.0;

// MeshKit.hash_i, bit for bit (32-bit integer mixing), so the shader and the scripts pick the same
// stall for the same slot. Inputs must not be negative (callers add an offset).
uint kit_hash_u(int a, int b, int c) {
	uint h = uint(a) * 0x27d4eb2du;
	h ^= uint(b) * 0x165667b1u + 0x3c6ef372u;
	h ^= uint(c) * 0x1b873593u + 0x68e31da4u;
	h = (h ^ (h >> 15u)) * 0x2c1b3c6du;
	h = (h ^ (h >> 12u)) * 0x297a2d39u;
	return h ^ (h >> 15u);
}

// MeshKit.hash01, bit for bit.
float kit_hash01(int a, int b, int c) {
	return float(kit_hash_u(a, b, c) & 0xFFFFFFu) / 16777216.0;
}

// The market's brands, shop signs and ads (PAT_SHOPSIGN and PAT_AD draw them below).
#include "res://scripts/world/meshes/shaders/kit_market_signs.gdshaderinc"

// A stall roof's shape, faked in shading (the running surface itself stays flat): a ridge along the
// lane's middle with the two halves catching the light differently, eaves darkening toward the lane
// edges, and the cloth sagging between the frame poles at the stall's ends. q: 0-1 across, along.
float mk_tent(vec2 q) {
	float x = q.x * 2.0 - 1.0;
	float half_light = mix(0.9, 1.06, smoothstep(-0.08, 0.08, x));
	float ridge = 1.0 + 0.1 * (1.0 - smoothstep(0.0, 0.05, abs(x)));
	float eaves = 1.0 - 0.16 * smoothstep(0.72, 1.0, abs(x));
	float sag = 1.0 - 0.07 * sin(clamp(q.y, 0.0, 1.0) * 3.14159) * (1.0 - abs(x));
	return half_light * ridge * eaves * sag;
}

// A stall's frame drawn over its roof (q: 0-1 across the lane, along the stall; len: the stall's
// length; fd: a pixel's footprint along the track, fq across the lane in q.x units): the pole across
// its start and the valleys along the lane's edges.
vec3 mk_frame(vec3 col, vec2 q, float len, float fd, float fq) {
	float d = q.y * len;
	float pole = 1.0 - smoothstep(0.08 - fd, 0.08 + fd, d);
	float e = min(q.x, 1.0 - q.x);
	float fe = max(fq, 1e-4);
	float valley = 1.0 - smoothstep(0.009 - fe, 0.009 + fe, e);
	return mix(col, canvas_pole, max(pole, valley));
}

// The scalloped hem of a stall's canvas along its leading edge (toward the player), just past the
// frame pole: `d` metres from the stall's start, `x` 0-1 across, fw a pixel's footprint along the
// track. Returns (hem, shadow).
vec2 mk_hem(float d, float x, float fw) {
	float sc = abs(sin(x * 3.14159 * 5.0));
	float edge = 0.18 + 0.11 * sc;
	float hem = 1.0 - smoothstep(edge - fw, edge + fw, d);
	float shadow = (1.0 - smoothstep(edge + 0.02, edge + 0.09, d)) * (1.0 - hem);
	return vec2(hem, shadow);
}

// A pixel's footprint for the roof patterns: fwidth of world x, world z and UV.x, taken by the
// caller outside any per-pixel branch.
vec3 mk_footprint(vec3 w, vec2 uv) {
	return vec3(fwidth(w.x), fwidth(w.z), fwidth(uv.x));
}

// Dust and wear on a roof (col in sRGB, p its world xz, x 0-1 across it): sand settled in drifts,
// patches bleached by the sun, grime along the valleys at its edges. Dust only pales a roof (the
// edge grime is a thin line), so no roof darkens toward a gap's shade.
vec3 mk_roof_dust(vec3 col, vec2 p, float x) {
	float dust = smoothstep(0.35, 0.85, value_noise(p * vec2(0.5, 0.2) + 17.0)) * market_dust_amount;
	col = mix(col, mix(col, market_dust, 0.6), dust * 0.8);
	float grey = dot(col, vec3(0.3, 0.55, 0.15));
	col = mix(col, vec3(grey) * 1.08, smoothstep(0.5, 0.9, value_noise(p * 0.11 + 5.0)) * 0.45 * market_dust_amount);
	float e = min(x, 1.0 - x);
	return col * (1.0 - 0.12 * market_dust_amount * (1.0 - smoothstep(0.0, 0.07, e)) * (0.5 + 0.5 * value_noise(p * 3.0)));
}

// Canvas (PAT_CANVAS, below) with its stripes (`mode`), the stall's length (`len`, 0: no hem or
// frame) and the pixel's footprint (`fp`, mk_footprint) given.
vec3 mk_canvas_at(vec3 base, vec3 w, vec2 uv, float mode, float len, vec3 fp) {
	vec2 p = w.xz;
	float fw = max(fp.x, fp.y);
	float fz = max(fp.y, 1e-4);
	float detail = 1.0 - smoothstep(0.02, 0.15, fw);
	vec3 col = base;
	vec3 stripe = mix(base, canvas_stripe, 0.42);
	if (mode > 0.5 && mode < 1.5) {
		col = mix(col, stripe, filtered_pulse(uv.x * 6.0, fp.z * 6.0, 0.0, 0.5));
	} else if (mode > 1.5) {
		col = mix(col, stripe, filtered_pulse(w.z / 0.6, fp.y / 0.6, 0.0, 0.5));
	}
	col *= mk_tent(clamp(uv, 0.0, 1.0));
	if (len > 0.0) {
		vec2 hem = mk_hem(uv.y * len, uv.x, fz);
		col = mix(col, mix(base, canvas_stripe, 0.55) * 0.95, hem.x);
		col *= 1.0 - 0.22 * hem.y;
		col = mk_frame(col, clamp(uv, 0.0, 1.0), len, fz, fp.z);
	}
	// Sewn panels across the canvas, weathering and a faint weave.
	col *= 1.0 - 0.08 * filtered_pulse(w.z / 1.3, fp.y / 1.3, 0.0, 0.03);
	col *= 0.93 + 0.12 * value_noise(p * vec2(0.9, 0.35) + base.r * 7.0);
	col *= 1.0 + 0.05 * detail * (hash12(floor(p * 36.0)) - 0.5);
	return mk_roof_dust(col, p, uv.x);
}

// PAT_CANVAS (20): canvas roofs and awnings stretched over a stall's frame. UV runs 0-1 across the
// panel (x) and along the whole stall (y). param = stripes (0 plain, 1 along the track, 2 across
// it) + 4 * the stall's length in decimetres (0: no hem). Stripes are soft (half-way to the stripe
// colour), so an awning never reads as a road marking.
vec3 mk_canvas(vec3 base, vec3 w, vec2 uv, float param) {
	return mk_canvas_at(base, w, uv, mod(floor(param + 0.5), 4.0), floor((param + 0.5) / 4.0) * 0.1,
		mk_footprint(w, uv));
}

// Tin (PAT_TIN, below) with its ribs (`mode`), the stall's length (`len`, 0: no ridge cap or
// frame) and the pixel's footprint (`fp`, mk_footprint) given.
vec3 mk_tin_at(vec3 base, vec3 w, vec2 uv, float mode, float len, vec3 fp) {
	vec2 p = w.xz;
	float fd = max(fp.y, 1e-4);
	base *= mk_tent(clamp(uv, 0.0, 1.0));
	if (len > 0.0) {
		float d = uv.y * len;
		base *= 1.0 + 0.12 * (1.0 - smoothstep(0.16 - fd, 0.16 + fd, d)) - 0.15 * (smoothstep(0.16, 0.2, d) - smoothstep(0.2, 0.3, d));
	}
	float along = mode < 0.5 ? p.x : p.y;
	float across = mode < 0.5 ? p.y : p.x;
	float f_along = mode < 0.5 ? fp.x : fp.y;
	float f_across = mode < 0.5 ? fp.y : fp.x;
	float rib = filtered_pulse(along / 0.14, f_along / 0.14, 0.0, 0.45);
	vec3 col = base * (1.06 - 0.2 * rib);
	col *= 0.9 + 0.16 * hash11(floor(across / 2.1) * 3.7 + floor(along / 2.4));
	col *= 1.0 - 0.3 * filtered_pulse(across / 2.1, f_across / 2.1, 0.0, 0.02);
	col = mix(col, vec3(0.42, 0.3, 0.22), smoothstep(0.55, 0.85, value_noise(p * vec2(1.4, 0.5) + 3.0)) * 0.45);
	col = mix(col, vec3(0.62, 0.55, 0.46), smoothstep(0.5, 0.9, value_noise(p * 0.4 + 9.0)) * 0.35);
	// Sand caught in the corrugations' valleys.
	col = mix(col, market_dust * 0.92, rib * smoothstep(0.35, 0.75, value_noise(p * vec2(0.8, 0.3) + 21.0)) * 0.4 * market_dust_amount);
	if (len > 0.0) {
		col = mk_frame(col, clamp(uv, 0.0, 1.0), len, fd, fp.z);
	}
	return mk_roof_dust(col, p, uv.x);
}

// PAT_TIN (21): corrugated sheet metal on stall roofs, with overlapping sheets, dust and rust.
// UV as for canvas (the roof's shape); param = ribs (0 along the track, 1 across it) + 4 * the
// stall's length in decimetres (for the ridge cap along its leading edge).
vec3 mk_tin(vec3 base, vec3 w, vec2 uv, float param) {
	return mk_tin_at(base, w, uv, mod(floor(param + 0.5), 4.0), floor((param + 0.5) / 4.0) * 0.1,
		mk_footprint(w, uv));
}

// Whether a stall starts at `slot` in the lane keyed `lane` (both offset to stay positive): every
// third slot, and by hash 45% of the others (MarketStalls.starts()).
bool mk_stall_starts(int lane, int slot) {
	return slot % 3 == 0 || kit_hash01(lane, slot, 7) < 0.45;
}

// PAT_STALLS (28): a whole row of stall roofs along one lane, laid out here rather than as one quad
// per stall: the stall under each point from its slot, then its roof (canvas, a blue awning or tin),
// shape, hem and frame. UV.x runs 0-1 across the lane; param = the lane's key (offset, positive).
// MarketStalls mirrors every choice, bit for bit, for the faces it builds at gap edges. The roof
// differs from stall to stall, so the footprint is taken here, before choosing.
vec3 mk_stalls(vec3 w, vec2 uv, float param) {
	vec3 fp = mk_footprint(w, uv);
	int lane = int(param + 0.5);
	float dist = -w.z;
	int si = int(floor(dist / stall_slot)) + 100000;
	int s0 = si;
	for (int j = 0; j < 2 && !mk_stall_starts(lane, s0); j++) {
		s0 -= 1;
	}
	int s1 = si + 1;
	for (int j = 0; j < 2 && !mk_stall_starts(lane, s1); j++) {
		s1 += 1;
	}
	float d0 = float(s0 - 100000) * stall_slot;
	float len = float(s1 - s0) * stall_slot;
	vec2 q = vec2(uv.x, (dist - d0) / len);
	float r = kit_hash01(lane, s0, 11);
	uint k = kit_hash_u(lane, s0, 12);
	if (r < stall_awning_share) {
		return mk_canvas_at(stall_awning[k % 2u], w, q, (k >> 4u) % 5u < 3u ? 1.0 : 0.0, len, fp);
	}
	if (r < stall_awning_share + stall_tin_share) {
		float tone = 0.92 + 0.12 * float((k >> 7u) % 64u) / 63.0;
		return mk_tin_at(stall_tin * tone, w, q, float((k >> 3u) % 2u), len, fp);
	}
	vec3 canvas = stall_canvas[kit_hash_u(lane, s0, 13) % 4u];
	return mk_canvas_at(canvas, w, q, (k >> 5u) % 6u == 0u ? 2.0 : 0.0, len, fp);
}

// PAT_UNDER (22): everything under the stall roofs, seen only through the gaps between stalls: the
// stalls' faces, the building faces and the market floor far below, all in deep shade, so a gap
// reads as a hole at a glance, as in every zone (nothing lit or roof-like inside it). COLOR is the
// shade at the roofs' level, and this only darkens it: faint poles and boards near the top, fading
// to near black with depth. param: 0 a face across the lane (a stall's front or back), 1 a face
// along the lane (a stall's side, a building's face), 2 the market floor.
vec3 mk_under(vec3 base, vec3 w, vec3 n, float param) {
	float mode = floor(param + 0.5);
	float h = abs(n.x) > 0.5 ? w.z : w.x;
	float fh = fwidth(h);
	if (mode > 1.5) {
		// The floor, lost in the dark: litter and grime, barely there.
		return base * (0.2 + 0.15 * value_noise(w.xz * 0.6));
	}
	float pole = filtered_pulse(h / 1.7, fh / 1.7, 0.0, 0.07);
	float boards = filtered_pulse(h / 0.26, fh / 0.26, 0.0, 0.12);
	float depth = mix(1.0, 0.18, smoothstep(-0.12, -2.6, w.y));
	return base * (0.9 - 0.25 * boards - 0.35 * pole) * depth;
}

// PAT_TILES (23): param 0: worn stone flags (an overpass's walkway; world xz); 1: the plastered soffit
// under buildings and overpasses, crossed by beams every 3 m (world xz, seen from below; the beams
// stream past a player riding the ceiling).
vec3 mk_tiles(vec3 base, vec3 w, float param) {
	vec2 p = w.xz;
	vec2 fwp = fwidth(p);
	if (param > 0.5) {
		float bq = p.y / 3.0;
		float f = fract(bq);
		float beam = filtered_pulse(bq, fwp.y / 3.0, 0.0, 0.12);
		float bay = smoothstep(0.12, 0.3, f) * (1.0 - smoothstep(0.84, 1.0, f));
		vec3 col = base * (0.95 + 0.08 * hash11(floor(bq) + 3.0)) * (0.86 + 0.14 * bay);
		col = mix(col, base * 0.6, beam);
		return col * (0.93 + 0.1 * value_noise(p * 0.35));
	}
	vec2 q = p / 0.55;
	q.x += 0.5 * mod(floor(q.y), 2.0);
	vec2 fq = fwp / 0.55;
	float grout = max(filtered_pulse(q.x, fq.x, 0.0, 0.07), filtered_pulse(q.y, fq.y, 0.0, 0.07));
	return base * (0.85 + 0.25 * hash12(floor(q) + 1.0)) * (1.0 - 0.35 * grout) * (0.85 + 0.25 * value_noise(p * 0.25));
}

// PAT_BULBS (26): rows of light bulbs on a dark panel (casino marquees): UV in metres, bulbs every
// 0.32 m glowing (COLOR.a). A slow wave of brightness runs along them, steady with Reduced flashing.
vec3 mk_bulbs(vec3 base, vec2 uv, float t, float reduced, out float glow_mask) {
	vec2 q = uv / 0.32;
	float fw = max(max(fwidth(q.x), fwidth(q.y)), 1e-4);
	float bulb = 1.0 - smoothstep(0.18 - fw, 0.18 + fw, length(fract(q) - 0.5));
	bulb = mix(bulb, 0.25, smoothstep(0.15, 0.5, fw));
	glow_mask = bulb * mix(0.75 + 0.25 * sin(floor(q.x) * 0.9 - t * 2.2), 0.9, reduced);
	return mix(vec3(0.05, 0.045, 0.04), base, bulb);
}

// PAT_STUCCO (27): sun-bleached plaster on buildings' solid parts (cornices, bridge faces, parapets).
vec3 mk_stucco(vec3 base, vec3 w, vec3 n) {
	vec2 p = abs(n.y) > 0.5 ? w.xz : (abs(n.x) > 0.5 ? w.zy : w.xy);
	vec3 col = base * (0.9 + 0.14 * value_noise(p * vec2(0.8, 0.5)));
	col *= 1.0 - 0.12 * smoothstep(0.55, 0.8, value_noise(p * 0.12 + 4.0));
	// Dust settled on its tops, grime running down its upright faces.
	float up = step(0.5, n.y);
	float dust = smoothstep(0.3, 0.8, value_noise(p * 0.9 + 3.0)) * market_dust_amount;
	col = mix(col, mix(col, market_dust, 0.6), up * dust * 0.75);
	float streak = (1.0 - up) * smoothstep(0.55, 0.9, value_noise(vec2(p.x * 2.4, p.y * 0.3) + 7.0));
	return col * (1.0 - 0.2 * streak * market_dust_amount);
}

// PAT_TECH (29): the market's machinery on its roofs and walls (UV in metres on the face). param:
// 0 a solar panel, dark blue cells in a silver grid; 1 an air-conditioning unit's front, a fan
// behind a round guard beside a bank of fins; 2 brushed metal with seams (racks, masts, cabinets).
vec3 mk_tech(vec3 base, vec2 uv, float param) {
	vec2 fw = max(fwidth(uv), vec2(1e-4));
	float aa = max(fw.x, fw.y);
	float mode = floor(param + 0.5);
	if (mode < 0.5) {
		vec2 c = uv / 0.17;
		float grid = max(filtered_pulse(c.x, fw.x / 0.17, 0.0, 0.08), filtered_pulse(c.y, fw.y / 0.17, 0.0, 0.08));
		vec3 cells = vec3(0.1, 0.14, 0.26) * (0.85 + 0.2 * hash12(floor(c)));
		return mix(cells, vec3(0.62, 0.64, 0.66), grid * 0.8);
	} else if (mode < 1.5) {
		vec2 f = uv - vec2(0.3, 0.29);
		float r = length(f);
		float guard = 1.0 - smoothstep(0.2 - aa, 0.2 + aa, r);
		float rings = filtered_pulse(r / 0.04, aa / 0.04, 0.0, 0.3) * guard;
		float fins = filtered_pulse(uv.y / 0.05, fw.y / 0.05, 0.0, 0.35) * step(0.56, uv.x);
		vec3 col = base * (1.0 - 0.25 * fins);
		col = mix(col, vec3(0.12, 0.12, 0.13), guard * 0.85);
		return mix(col, base * 0.8, rings);
	}
	float seam = filtered_pulse(uv.x / 0.6, fw.x / 0.6, 0.0, 0.03);
	return base * (0.9 + 0.1 * value_noise(vec2(uv.x * 14.0, uv.y * 0.8))) * (1.0 - 0.3 * seam);
}

// Dispatches the Marketplace patterns (ids 20-29) for kit_solid.gdshader.
vec3 market_surface(int pattern, float param, vec3 base, vec3 w, vec3 n, vec2 uv, float t, inout float glow) {
	if (pattern == 20) {
		return mk_canvas(base, w, uv, param);
	} else if (pattern == 21) {
		return mk_tin(base, w, uv, param);
	} else if (pattern == 22) {
		return mk_under(base, w, n, param);
	} else if (pattern == 23) {
		return mk_tiles(base, w, param);
	} else if (pattern == 24) {
		return mk_shopsign(base, uv, param);
	} else if (pattern == 25) {
		float m;
		vec3 c = mk_ad(base, uv, param, t, m);
		glow *= m;
		return c;
	} else if (pattern == 26) {
		float m;
		vec3 c = mk_bulbs(base, uv, t, reduced_flashing, m);
		glow *= m;
		return c;
	} else if (pattern == 27) {
		return mk_stucco(base, w, n);
	} else if (pattern == 28) {
		return mk_stalls(w, uv, param);
	} else if (pattern == 29) {
		return mk_tech(base, uv, param);
	}
	return base;
}

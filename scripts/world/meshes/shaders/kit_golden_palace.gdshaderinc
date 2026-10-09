// The Golden Palace's surfaces for the solid kit shader (kit_solid.gdshader): pattern ids 70-79
// (MeshKit.PAT_PALACE_*, task D6b), in their own file so other zones' patterns never collide with
// them. Included after kit_golden.gdshaderinc, whose golden_metal(), golden_marble(), golden_vein
// and golden_light() it calls directly: the palace reuses the Golden Zone's materials rather than
// inventing new ones (GDD §5, "Final level: the Golden Palace" -- the skin is an interior, built on
// the Golden Zone's palette; D6a's statue kit is shared the same way, in GDScript). Nothing here
// glows: gold stays reflective metal, never neon (GDD §5, §11).
// Pixel footprints are taken at the top of each pattern's function, where every pixel of a face runs
// the same code, and passed down (docs/ARCHITECTURE.md, Zone skins: the kit's shader rules).

// The floor's gold inlay runner (GoldenPalaceSkin.srgb(gold_color), half its width in metres) and the
// colonnade's wall-run height marks (GoldenPalaceSkin.wall_height_marks; -10 = none, same convention
// as golden_facade.gdshader's mark_a/mark_b).
uniform vec3 gp_runner = vec3(0.78, 0.66, 0.42);
uniform float gp_runner_half = 0.22;
uniform float gp_mark_a = -10.0;
uniform float gp_mark_b = -10.0;
uniform vec3 gp_mark_color = vec3(0.5, 0.4, 0.24);

// PAT_PALACE_FLOOR (70): a palace floor's lane (GDD §5: "a palace floor (marble, inlay, gold
// runners)"): polished marble (golden_marble) with a gold inlay runner down the lane's centre and,
// where a neighbouring lane's floor doesn't carry on (a gap beside it), a dark joint at the lane's
// edge so it still reads as its own lane, the same language as a walkway's joint. UV.x is metres
// signed from the lane's centre (continuous across chunk cuts: it depends only on world x and the
// lane's own x, which never changes along the track); param = MeshKit.palace_floor_param().
vec3 golden_palace_floor(vec3 base, vec3 w, vec3 n, vec3 eye, vec2 uv, float param) {
	vec2 fw = max(fwidth(uv), vec2(1e-4));
	float code = floor(param + 0.5);
	float half_w = max(floor(code / 8.0) * 0.01, 0.4);
	float flags = mod(code, 8.0);
	float left = mod(flags, 2.0);
	float right = mod(floor(flags / 2.0), 2.0);
	vec3 col = golden_marble(base, w, n, 0.0);
	float runner = 1.0 - smoothstep(gp_runner_half - fw.x, gp_runner_half + fw.x, abs(uv.x));
	col = mix(col, golden_metal(gp_runner, n, eye, 0.55), runner);
	float joint = max(left * (1.0 - smoothstep(0.03 - fw.x, 0.03 + fw.x, abs(uv.x + half_w))),
		right * (1.0 - smoothstep(0.03 - fw.x, 0.03 + fw.x, abs(uv.x - half_w))));
	return mix(col, golden_vein * 0.6, joint);
}

// PAT_PALACE_WELL (71): everything under a break in the palace floor (GDD §5: "a collapsed floor, an open
// stairwell, a light well"), seen only through gaps and cuts: deep shade that darkens with depth (so
// it reads as a hole at a glance, like every zone's gap, and never lights like the floor above), but
// (task H3, GDD §9.9) showing what is there: a stairwell, its stone steps going down in treads and risers
// (diagonal along a long side, level across a face), and far below the lower hall's marble in slabs with
// a pool of light on it. Steady, all albedo, COLOR the peak of both (capped at it: the palace suite counts COLOR
// and nothing more). param: 0 a face, 1 the lower hall's floor.
vec3 golden_palace_well(vec3 base, vec3 w, vec3 n, float param) {
	if (param > 0.5) {
		vec2 p = w.xz;
		vec2 fwp = max(fwidth(p), vec2(1e-4));
		vec2 q = p / vec2(2.4, 3.6);
		vec2 fq = fwp / vec2(2.4, 3.6);
		float joint = max(filtered_pulse(q.x + 0.5, fq.x, 0.0, 0.025), filtered_pulse(q.y, fq.y, 0.0, 0.02));
		vec3 col = base * (0.6 + 0.25 * value_noise(p * vec2(0.5, 0.35)));
		col *= 1.0 - 0.55 * joint;
		// The light well: a pool of soft light every 22 m down the hall, on its axis and wide. It lifts the
		// stone toward COLOR and never past it (capped: COLOR is the peak the palace suite counts).
		vec2 pc = vec2(p.x / 4.2, (fract(p.y / 22.0 + 0.5) - 0.5) * 22.0 / 6.5);
		col *= 1.0 + 0.6 * exp(-dot(pc, pc));
		return min(col, base);
	}
	bool side = abs(n.x) > 0.5;
	float h = side ? w.z : w.x;
	float fh = max(fwidth(h), 1e-4);
	float fy = max(fwidth(w.y), 1e-4);
	// Steps: a long side's flight descends along the track; an end face shows them level.
	float slope = side ? 0.5 : 0.0;
	float s = (w.y + h * slope) / 0.45;
	float fs = max(fy + fh * slope, 1e-4) / 0.45;
	float riser = filtered_pulse(s, fs, 0.0, 0.1);
	float tread = 0.5 + 0.5 * step(0.5, fract(s));
	float depth = mix(1.0, 0.3, smoothstep(-0.2, -5.2, w.y));
	float pier = filtered_pulse(h / 3.6, fh / 3.6, 0.0, 0.1);
	return min(base * (0.8 + 0.2 * tread - 0.4 * riser - 0.18 * pier) * depth, base);
}

// PAT_PALACE_PANEL (72): the colonnade's flush wall panel, floor to the entablature (world position,
// the same marble as the floor): the gold wall-run height marks inlaid in it at gp_mark_a/b, the
// same language every zone's wall-run marks use.
vec3 golden_palace_panel(vec3 base, vec3 w, vec3 n) {
	vec3 col = golden_marble(base, w, n, 1.0);
	float fh = max(fwidth(w.y), 1e-4);
	float marks = max(1.0 - smoothstep(0.018, 0.018 + fh, abs(w.y - gp_mark_a)),
		1.0 - smoothstep(0.018, 0.018 + fh, abs(w.y - gp_mark_b)));
	return mix(col, gp_mark_color, clamp(marks, 0.0, 1.0));
}

// Dispatches the Golden Palace's patterns (ids 70-79) for kit_solid.gdshader.
vec3 golden_palace_surface(int pattern, float param, vec3 base, vec3 w, vec3 n, vec3 eye, vec2 uv) {
	if (pattern == 71) {
		return golden_palace_well(base, w, n, param);
	} else if (pattern == 70) {
		return golden_palace_floor(base, w, n, eye, uv, param) * golden_light(w.y);
	} else if (pattern == 72) {
		return golden_palace_panel(base, w, n) * golden_light(w.y);
	}
	return base;
}

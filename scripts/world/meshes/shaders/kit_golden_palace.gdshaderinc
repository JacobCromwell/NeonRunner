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

// PAT_PALACE_WELL (71): everything under a break in the palace floor (GDD §5: "a collapsed floor,
// an open stairwell, a light well"), seen only through gaps: deep shade that only darkens with
// depth (so it reads as a hole at a glance, like every zone's gap), with the faint silhouette of
// broken stone steps near the top.
vec3 golden_palace_well(vec3 base, vec3 w, vec3 n) {
	float h = abs(n.x) > 0.5 ? w.z : w.x;
	float fh = max(fwidth(h), 1e-4);
	float step_line = filtered_pulse(h / 0.9, fh / 0.9, 0.0, 0.07);
	float depth = mix(1.0, 0.16, smoothstep(-0.2, -3.4, w.y));
	return base * (0.86 - 0.2 * step_line) * depth;
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
		return golden_palace_well(base, w, n);
	} else if (pattern == 70) {
		return golden_palace_floor(base, w, n, eye, uv, param) * golden_light(w.y);
	} else if (pattern == 72) {
		return golden_palace_panel(base, w, n) * golden_light(w.y);
	}
	return base;
}

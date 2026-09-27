// The corporation's brand mark (GDD §5): the Corporate zone's brand (CorporateSkin draws it on its
// ads, banners, liveries and ships), and the logo on the containers, crates and pasted ads that hint
// at corporate funding in Gangland. In one place so the whole game shows the same brand. The cult's
// emblem is separate: CultEmblem draws the owner's pick, and kit_solid.gdshader's cult_emblem
// texture hides it small beside this logo on some of them.
// The mark (task D4, replacing the build's generic placeholder): a heavy block, a rounded square, whose
// upper right corner is split off by an L-shaped slot and pushed out a little: one piece taken over by
// the whole, the merger of corporations and the military that rules the zone. Square and two-fold at
// most, so it never reads as a warning sign (triangles, diamonds, a bar across a ring or a disc) or as
// the cult's three-fold emblem.

// Signed distance to a rounded box (half extents b, corner radius r) centred on the origin.
float logo_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// The mark's coverage (0-1, anti-aliased) at p in logo space: it fills about -0.78..0.78 on both
// axes (inside the unit disc). `fw` is a pixel's footprint in logo space (max of fwidth(p)), taken by
// the caller outside any branch that can differ between neighbouring pixels (derivatives are
// undefined there).
float corp_logo(vec2 p, float fw) {
	fw = max(fw, 1e-4);
	// The block, less its upper right corner beyond the slot's near side.
	float body = max(logo_box(p, vec2(0.7), 0.13), min(p.x, p.y) - 0.07);
	// The corner piece: the block's own corner, pushed out along the diagonal, beyond the slot.
	vec2 c = p - vec2(0.08);
	float piece = max(logo_box(c, vec2(0.7), 0.13), 0.13 - min(c.x, c.y));
	float mark = 1.0 - smoothstep(-fw, fw, min(body, piece));
	// Far away the mark fades to its average coverage (a soft square) instead of shimmering.
	float average = 0.7 * (1.0 - smoothstep(0.62, 0.86, max(abs(p.x), abs(p.y))));
	return mix(mark, average, smoothstep(0.15, 0.5, fw));
}

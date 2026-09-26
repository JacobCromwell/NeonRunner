// A corporation's own logo on crates, containers and ads (Gangland's hints of corporate funding,
// GDD §5), in one place so a later brand pass edits corp_logo() only. The cult's emblem is separate:
// CultEmblem draws the owner's pick, and kit_solid.gdshader's cult_emblem texture hides it small
// beside this logo on some of them.
// DESIGN-TBD: a generic corporate mark (a disc cut by three slots, a bite out of its top right). It
// avoids a bar across a ring (a "no" sign) and triangles (warning signs).

// The mark's coverage (0-1, anti-aliased) at p in logo space: it fills the unit disc (|p| <= 1).
// `fw` is a pixel's footprint in logo space (max of fwidth(p)), taken by the caller outside any
// branch that can differ between neighbouring pixels (derivatives are undefined there).
float corp_logo(vec2 p, float fw) {
	fw = max(fw, 1e-4);
	float disc = 1.0 - smoothstep(0.92 - fw, 0.92 + fw, length(p));
	// Three horizontal slots, thicker toward the bottom, and the bite.
	float slot = 0.0;
	slot = max(slot, 1.0 - smoothstep(0.035 - fw, 0.035 + fw, abs(p.y - 0.12)));
	slot = max(slot, 1.0 - smoothstep(0.05 - fw, 0.05 + fw, abs(p.y + 0.22)));
	slot = max(slot, 1.0 - smoothstep(0.065 - fw, 0.065 + fw, abs(p.y + 0.56)));
	float bite = 1.0 - smoothstep(0.3 - fw, 0.3 + fw, length(p - vec2(0.62, 0.62)));
	// Far away the mark fades to its average coverage (a soft disc) instead of shimmering.
	float average = 0.5 * (1.0 - smoothstep(0.7, 1.1, length(p)));
	return mix(disc * (1.0 - slot) * (1.0 - bite), average, smoothstep(0.15, 0.5, fw));
}

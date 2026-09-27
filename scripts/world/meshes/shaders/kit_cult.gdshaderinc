// The cult's emblem as a mark of its own (GDD §5, "The cult": hidden in logos and ads), for the solid
// kit shader: pattern ids 60-69, in their own file (kit_solid.gdshader dispatches them). Include after
// cult_mark() in kit_solid.gdshader.
// PAT_CULT_MARK (60): the emblem, the material's cult_emblem texture (CultEmblem's drawing of the
// owner's choice; its alpha is the coverage), on a dark panel. UV is emblem space: the mark's square
// spans -1 to 1, so a panel wider than that range leaves a clear margin around it. The mark takes
// COLOR.rgb and glows at COLOR.a (a neon ad's warm white) or stays lit paint at COLOR.a = 0; the rest
// of the panel is `dark`, a neon ad's own background (panel_dark). cult_mark() fades the mark out
// before it spans fewer than about 24 pixels, where its three-fold silhouette could read like the
// radiation trefoil. `fw` is fwidth(UV), taken where every pixel of the face runs the same code.

vec3 cult_surface(int pattern, vec3 base, vec2 uv, vec2 fw, vec3 dark, inout float glow) {
	if (pattern == 60) {
		vec4 mark = cult_mark(uv, max(fw.x, fw.y));
		glow *= mark.a;
		return mix(dark, base, mark.a);
	}
	return base;
}

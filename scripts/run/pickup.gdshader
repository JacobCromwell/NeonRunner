// A pickup's glowing parts (Pickup): the item's icon (a texture on a card), its ring, its soft halo and
// the faint glow on the floor under it. Additive and unshaded, with values above 1 so the glow pass
// blooms them; the same on Forward+, Mobile and Compatibility. Steady: nothing here flickers.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D icon : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 color : source_color = vec4(1.0);
uniform float energy = 2.0;
// 0: the icon (its texture's alpha); 1: a radial glow, bright in the middle; 2: solid colour.
uniform int shape = 0;

void fragment() {
	// Sampled outside the branch (implicit mip levels need neighbouring pixels in step).
	float ink = texture(icon, UV).a;
	float a = 1.0;
	if (shape == 0) {
		a = ink;
	} else if (shape == 1) {
		float r = max(1.0 - length(UV * 2.0 - 1.0), 0.0);
		a = r * r;
	}
	ALBEDO = color.rgb * energy * a;
}

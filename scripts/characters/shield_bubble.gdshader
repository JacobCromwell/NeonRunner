shader_type spatial;
// Translucent energy bubble (the shield power-up placeholder): nearly clear in the middle, bright at
// the rim, faceted by the flat-shaded low-poly sphere. Additive and unshaded, so it works the same on
// Forward+, Mobile and Compatibility; values above 1 bloom.
render_mode blend_add, unshaded, cull_back, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(0.35, 0.85, 1.0, 1.0);
uniform float strength = 1.3;
uniform float core = 0.04;

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = pow(1.0 - facing, 2.5);
	float shimmer = 0.85 + 0.15 * sin(TIME * 5.0 + VERTEX.y * 9.0);
	ALBEDO = color.rgb * (core + rim) * strength * shimmer;
}

// The Golden Convergence's fist shadow on the floor (GDD §10, the Fist Slam: "its shadow grows on the floor";
// GoldenConvergenceFist.set_shadow): a soft round dark patch on a unit quad, `darkness` its middle's alpha.
// Never glowing (it darkens what's under it), nothing animated, the same on every renderer.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float darkness = 0.5;

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float a = (1.0 - smoothstep(0.35, 1.0, r)) * darkness;
	ALBEDO = vec3(0.0);
	ALPHA = clamp(a, 0.0, 1.0);
}

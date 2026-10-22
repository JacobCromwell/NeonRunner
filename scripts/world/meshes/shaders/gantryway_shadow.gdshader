// A falling gantryway's shadow on its lane (task Q3; Gantryway): a dark rectangle with soft edges, on a unit quad scaled
// to the walkway's footprint (`size`, metres; its edges fade over `soft` metres), `darkness` its middle's alpha. It
// darkens as the walkway comes down, a part of its warning with the red line on the lane (GDD §5, proposed: "its shadow
// darkening on the lane"). Never glowing (it darkens what's under it), nothing animated in it. The Compatibility
// renderer blends in sRGB space, where the same alpha darkens far more: the gantryway gives it a lighter `darkness`
// there (Gantryway.shadow_alpha_for), as the Golden Convergence's fist shadow does.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float darkness = 0.5;
uniform vec2 size = vec2(2.0, 20.0);
uniform float soft = 0.5;

void fragment() {
	// Metres to the nearest edge across and along.
	vec2 d = min(UV, 1.0 - UV) * size;
	float a = smoothstep(0.0, soft, d.x) * smoothstep(0.0, soft, d.y) * darkness;
	ALBEDO = vec3(0.0);
	ALPHA = clamp(a, 0.0, 1.0);
}

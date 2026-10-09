// The glint of the Host's implant in the dark heart of the swarm (SwarmIntroSwarm, the Gangland boss intro): a
// small star facing the camera, a hot core with four long rays and four short ones in the implants' red (the weak
// points' colour, BossProps.WARNING_COLOR), added over what's behind it. `strength` (0-1) is set each frame:
// one quick glint, or with Reduced flashing a slow, faint glow (SwarmIntroSwarm.glint_at). Unshaded and
// procedural: the same on every renderer; on the Compatibility one (no tonemapping) an over-bright colour is
// scaled down whole, so the red never clips toward orange.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float strength = 0.0;
uniform vec4 core_color : source_color = vec4(1.0, 0.86, 0.8, 1.0);
uniform vec4 ray_color : source_color = vec4(1.0, 0.16, 0.08, 1.0);
uniform float energy = 2.2;

void vertex() {
	// Facing the camera, wherever it is.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float core = exp(-r * r * 60.0);
	float halo = exp(-r * r * 9.0) * 0.35;
	float rays = exp(-abs(p.x) * 45.0) * (1.0 - smoothstep(0.0, 1.0, abs(p.y)))
		+ exp(-abs(p.y) * 45.0) * (1.0 - smoothstep(0.0, 1.0, abs(p.x)));
	vec2 q = vec2(p.x + p.y, p.y - p.x) * 0.7071;
	float diag = (exp(-abs(q.x) * 70.0) * (1.0 - smoothstep(0.0, 0.55, abs(q.y)))
		+ exp(-abs(q.y) * 70.0) * (1.0 - smoothstep(0.0, 0.55, abs(q.x)))) * 0.6;
	// The rays shrink in as it fades, so it twinkles out rather than dims.
	float reach = mix(0.35, 1.0, strength);
	rays *= 1.0 - smoothstep(reach * 0.7, reach, r);
	diag *= 1.0 - smoothstep(reach * 0.5, reach * 0.7, r);
	vec3 c = core_color.rgb * core * 1.5 + ray_color.rgb * (rays + diag + halo);
	c *= strength * energy;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	c /= max(1.0, max(c.r, max(c.g, c.b)));
#endif
	ALBEDO = c;
}

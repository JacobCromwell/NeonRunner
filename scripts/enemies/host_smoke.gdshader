// A host cyborg's purple smoke (GDD §9.7, task S1): a few soft columns of smoke rising off its shoulders,
// so the host can be told from the other cyborgs at a glance at running distance. Each column is one
// quad whose six vertices all sit at its base (HostSmoke's mesh); the vertex stage spreads them into a
// column that turns to face the camera about the upright axis (like dead_smoke.gdshader's), widening as
// it rises, and the fragment stage draws its billows: two layers of smooth value noise drifting up, curled
// by a slower warp, with no texture and no per-frame work in GDScript. A host's whole smoke is one draw call.
//   VERTEX  the column's base (the host's chest joint's space, via the model matrix)
//   UV      the corner: x -1..1 across, y -1 (base) .. 1 (top)
//   UV2     x, y = the column's width and height as a share of `size`
//   COLOR   r = the column's phase (0-1), a = its opacity share
// Unshaded and alpha-blended, so it looks the same on Forward+, Mobile and the Compatibility renderer
// (web, low-end Android; colours go through to_linear, and a thin veil's alpha is lifted where blending
// is in sRGB), in any lighting (The Hush's dark too). It is the Bad Dream's violet (BadDreamModel.PURPLE,
// leaning blue: pink is the fences' colour), never a hazard colour, and it never flickers or flashes: it
// only drifts, its brightness at a point changing no faster than the billows pass (under two a second);
// with Settings > Reduced flashing (the global `reduced_flashing`) the drift slows by 40% more.
// It thins out toward its base, so the screen's face, the cannon's red charge and the lanes behind
// stay readable, and fades out as it nears the camera, so a host the runner passes never fills the view.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform, shadows_disabled;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"
#include "res://scripts/world/meshes/shaders/kit_flash.gdshaderinc"

uniform vec4 smoke_color : source_color = vec4(0.58, 0.28, 1.0, 1.0);
// The opacity at the thickest, and how much of the column the billows fill (0 thin wisps, 1 a solid column).
uniform float strength = 0.75;
uniform float density = 0.6;
// How fast the billows climb (m/s).
uniform float rise_speed = 0.7;
// The main column's width at its base and its height (m).
uniform vec2 size = vec2(1.0, 2.2);
// How much wider a column is at its top than at its base.
uniform float spread = 1.4;
// 0 = shown, 1 = gone (a defeated host's smoke clears).
uniform float fade = 0.0;
// This host's own offset into the noise, so two hosts' smoke never moves together.
uniform float seed = 0.0;
// It fades out between these distances from the camera (m).
uniform vec2 near_fade = vec2(2.5, 7.0);

varying vec2 v_uv;
varying vec2 v_extent;
varying vec2 v_phase;
varying float v_alpha;

void vertex() {
	// The column's base in view space, and the world's up and the scale the host is drawn at (a zone may
	// draw its cyborgs bigger; a stomp squashes one).
	vec3 base = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 up = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	float scale = length(MODEL_MATRIX[1].xyz);
	vec3 across = cross(up, normalize(-base));
	across = length(across) > 1e-4 ? normalize(across) : vec3(1.0, 0.0, 0.0);
	float t = UV.y * 0.5 + 0.5;
	vec2 extent = size * UV2 * scale;
	float width = extent.x * mix(1.0, spread, t) * 0.5;
	// It leans slowly from side to side as it climbs.
	float sway = sin(TIME * 0.8 + COLOR.r * 6.2832 + seed * 1.7 + t * 2.4) * 0.1 * scale * t;
	VERTEX = base + across * (UV.x * width + sway) + up * (t * extent.y);
	v_uv = vec2(UV.x, t);
	v_extent = size * UV2;
	v_phase = vec2(COLOR.r * 11.0 + seed * 0.37, COLOR.r * 5.0);
	v_alpha = COLOR.a * (1.0 - fade) * smoothstep(near_fade.x, near_fade.y, length(base));
}

void fragment() {
	// Position in the column's own frame (m), the billows drifting up through it, curled a little by a
	// slower layer of noise (a warp), so they roll instead of sliding up in straight bands.
	vec2 q = vec2(v_uv.x * v_extent.x * 0.5, v_uv.y * v_extent.y);
	float rise = TIME * rise_speed * mix(1.0, 0.6, reduced_flashing);
	vec2 warp = vec2(value_noise(vec2(q.x * 1.1 + v_phase.x + 9.0, q.y * 0.8 - rise * 0.5)),
		value_noise(vec2(q.x * 1.1 + v_phase.y + 2.0, q.y * 0.8 - rise * 0.5 + 6.0))) - 0.5;
	vec2 p = q + warp * 0.8;
	float big = value_noise(vec2(p.x * 1.5 + v_phase.x, p.y * 0.9 - rise));
	float fine = value_noise(vec2(p.x * 3.2 + v_phase.y + 4.0, p.y * 1.8 - rise * 1.3));
	float billow = 0.65 * big + 0.35 * fine;
	// Thick in the middle and ragged toward the sides; the more `density`, the lower the bar the
	// billows must clear to show, so the further the smoke reaches.
	float edge = 1.0 - abs(v_uv.x);
	float bar = mix(0.64, 0.3, density);
	float body = smoothstep(bar, bar + 0.22, billow * (0.45 + 0.55 * smoothstep(0.0, 0.6, edge)) + 0.18 * edge)
		* smoothstep(0.0, 0.3, edge);
	// Thin where it leaves the host, thinning out again toward its top.
	float along = smoothstep(0.0, 0.08, v_uv.y) * (1.0 - smoothstep(0.3, 1.0, v_uv.y));
	// Dark violet in the thick of it, lighter toward the thin edges and the top.
	vec3 deep = smoke_color.rgb * 0.55;
	vec3 light = mix(smoke_color.rgb, vec3(0.78, 0.66, 1.0), 0.55);
	ALBEDO = to_linear(mix(deep, light, clamp(1.15 - body * 0.6 - billow * 0.35 + v_uv.y * 0.35, 0.0, 1.0)));
	float alpha = clamp(strength * v_alpha * body * along, 0.0, 1.0);
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	// Blended in sRGB space, a thin veil comes out darker than the same one blended in linear light
	// (Forward+, Mobile): lift it so the smoke is as strong on the web and low-end phones.
	alpha = pow(alpha, 0.72);
#endif
	ALPHA = alpha;
}

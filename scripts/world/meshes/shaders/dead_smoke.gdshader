// Smoke rising from the Dead Zone's ruins (DeadTowers): a column that turns to face the camera about
// its upright axis, widening as it rises, its billows drifting slowly up. Scenery only, far above the
// play field; it never flickers or flashes. A column is one quad whose six vertices all sit at the
// column's base; the vertex shader spreads them out, so a chunk's plumes are one static surface.
//   VERTEX  the column's base (world, via the model matrix)
//   UV      the corner: x -1..1 across, y -1 (base) .. 1 (top)
//   UV2     x = the column's width at its base, y = its height (metres)
//   COLOR   rgb = the smoke's colour (sRGB), a = its opacity at the core
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"

// A level's darker lighting (ZoneSkin.apply_darkness): the smoke dims with the scenery.
global uniform float scenery_light;

// How fast the billows rise (m/s), and how much wider the column is at its top than at its base.
uniform float rise_speed = 1.2;
uniform float spread = 2.2;

varying vec2 v_uv;
varying float v_alpha;
varying float v_height;
varying float v_seed;

void vertex() {
	// Every vertex of a column sits at its base: a seed from where it stands, the same for all six.
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_seed = fract((world.x * 0.37 + world.z) * 0.013);
	vec3 base = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 up = normalize((MODELVIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	vec3 across = cross(up, normalize(-base));
	across = length(across) > 1e-4 ? normalize(across) : vec3(1.0, 0.0, 0.0);
	float t = UV.y * 0.5 + 0.5;
	float width = UV2.x * (1.0 + (spread - 1.0) * t) * 0.5;
	// It leans a little downwind as it rises.
	vec3 lean = (MODELVIEW_MATRIX * vec4(0.35, 0.0, 0.15, 0.0)).xyz * t * t * UV2.y * 0.25;
	VERTEX = base + across * UV.x * width + up * t * UV2.y + lean;
	v_uv = vec2(UV.x, t);
	v_alpha = COLOR.a;
	v_height = UV2.y;
}

void fragment() {
	// Billows: two layers of noise drifting up at different speeds, stretched along the column.
	vec2 q = vec2(v_uv.x * 1.6, v_uv.y * v_height / 9.0);
	float rise = TIME * rise_speed / 9.0;
	float billow = 0.6 * value_noise(q * vec2(2.0, 1.4) + vec2(v_seed * 17.0, -rise))
		+ 0.4 * value_noise(q * vec2(4.3, 3.1) + vec2(v_seed * 5.0 + 3.0, -rise * 1.7));
	float edge = 1.0 - abs(v_uv.x);
	float body = smoothstep(0.0, 0.5, edge - (0.55 - billow) * 0.6);
	// Thin where it leaves the ruin, thinning out again toward its top.
	float along = smoothstep(0.0, 0.12, v_uv.y) * (1.0 - smoothstep(0.45, 1.0, v_uv.y));
	ALBEDO = to_linear(COLOR.rgb) * (0.8 + 0.4 * billow) * light_factor(scenery_light);
	ALPHA = clamp(v_alpha * body * along * (0.6 + 0.6 * billow), 0.0, 1.0);
}

// The volleyball court's sand (VolleyballCourt): raked sand laid over the street where the court stands, with the
// court's white boundary tapes (the side lines, both end lines and the centre line under the net) drawn in. Unshaded
// with the mesh kit's fake light (kit_solid.gdshader), like the Beach's own sand, so it sits in the street's light,
// dims with a level's darkness (scenery_light) and takes the street's light under its level's sky (scenery_tint), the
// same on the Compatibility renderer (web, low-end Android) as on Forward+. Never emissive: the tapes are paint.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"

global uniform float scenery_light;
global uniform vec3 scenery_tint;

uniform vec3 sand_color : source_color = vec3(0.82, 0.72, 0.54);
uniform vec3 sand_dark_color : source_color = vec3(0.70, 0.58, 0.41);
uniform vec3 tape_color : source_color = vec3(0.93, 0.93, 0.9);
// The court's lines in the quad's own space (metres): the side lines at x = +-half_x, the end lines at z = near_z and
// far_z, the centre line at z = net_z; tape_width wide.
uniform float half_x = 4.0;
uniform float near_z = 0.0;
uniform float far_z = -10.0;
uniform float net_z = -5.0;
uniform float tape_width = 0.08;
// The quad's half size (metres), and how far its ends break up into the street's sand.
uniform vec2 quad_half = vec2(4.5, 6.0);
uniform float edge_fade = 0.8;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

float tape(float d, float w) {
	return 1.0 - smoothstep(w * 0.5 - 0.01, w * 0.5 + 0.01, abs(d));
}

void fragment() {
	vec2 p = local_pos.xz;
	// Raked sand: soft drifts and fine grain, with long rake furrows across the court.
	float drift = value_noise(p * 0.45);
	float grain = hash12(floor(p * 40.0));
	float furrow = 0.5 + 0.5 * sin(p.y * 9.0 + value_noise(p * 1.3) * 3.0);
	vec3 sand = mix(to_linear(sand_dark_color), to_linear(sand_color), 0.55 + 0.3 * drift + 0.1 * furrow);
	sand *= 0.96 + 0.08 * grain;
	float inside_x = step(abs(p.x), half_x + tape_width);
	float inside_z = step(far_z - tape_width, p.y) * step(p.y, near_z + tape_width);
	float lines = max(tape(abs(p.x) - half_x, tape_width) * inside_z,
		max(tape(p.y - near_z, tape_width), max(tape(p.y - far_z, tape_width), tape(p.y - net_z, tape_width))) * inside_x);
	vec3 col = mix(sand, to_linear(tape_color), lines);
	ALBEDO = col * light_factor(scenery_light) * scenery_tint;
	// The quad's ends (it's centred on its own origin) break up into the street's own sand along the run, in a
	// dither rather than a blend (no sorting, no transparency cost), so the court never has a hard edge there.
	float ez = clamp((quad_half.y - abs(p.y)) / max(edge_fade, 0.001), 0.0, 1.0);
	if (hash12(floor(p * 14.0)) > ez) {
		discard;
	}
}

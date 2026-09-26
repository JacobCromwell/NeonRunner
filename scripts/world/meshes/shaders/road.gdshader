// A road far below the track, seen through the gaps. The gameplay floor is static, so the road
// sells the trucks' motion: its markings and traffic stream toward the player (+z).
shader_type spatial;
render_mode unshaded, cull_back;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"

uniform float scroll_speed = 14.0;
uniform float lane_width = 3.4;
uniform vec3 asphalt : source_color = vec3(0.04, 0.04, 0.06);
uniform vec3 marking : source_color = vec3(0.45, 0.45, 0.55);
uniform vec3 head_color : source_color = vec3(0.85, 0.9, 1.0);
uniform vec3 tail_color : source_color = vec3(0.5, 0.45, 1.0);
uniform float streak_glow = 2.5;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float lanef = v_world.x / lane_width;
	float lane = floor(lanef);
	float lx = fract(lanef);
	vec3 col = to_linear(asphalt);

	// Dashed lane lines streaming toward the player.
	float zs = v_world.z - TIME * scroll_speed;
	float line = filtered_pulse(lanef + 0.5, fwidth(lanef), 0.48, 0.52) * step(fract(zs / 8.0), 0.45);
	col += to_linear(marking) * (line * 0.5);

	// Traffic: head-light streaks rush toward the player, others drift slower.
	bool oncoming = mod(lane, 2.0) < 0.5;
	float speed = scroll_speed + (oncoming ? 16.0 : -5.0);
	float zc = (v_world.z - TIME * speed) / 26.0 + hash12(vec2(lane, 3.0));
	float slot = floor(zc);
	float fz = fract(zc);
	float has_car = step(0.4, hash12(vec2(lane * 1.7, slot)));
	float head = 0.15 + 0.5 * hash12(vec2(slot, lane * 2.3));
	// The streak's bright end leads in the direction of travel.
	float s = oncoming ? (fz - head) : (head - fz);
	float streak = smoothstep(-0.28, 0.0, s) * (1.0 - smoothstep(0.0, 0.02, s));
	float across = 1.0 - smoothstep(0.08, 0.2, abs(lx - 0.5));
	col += to_linear(oncoming ? head_color : tail_color) * (streak * across * has_car * streak_glow);
	ALBEDO = col;
}

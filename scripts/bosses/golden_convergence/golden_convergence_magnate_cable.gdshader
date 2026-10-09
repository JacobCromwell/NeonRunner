// One of The Magnate's broadcast cables (GDD §10: "the tentacle pipes turn out to be cables wiring him into the
// broadcast"): GoldenConvergenceMagnateModel's cable, straight along +z from its socket on his back (UV.y how
// far along it, 0-1, over `cable_length` metres). Here it curves down from the socket to the ground `ground` metres
// below, its end trailing on the floor, and sways from side to side, more toward its end, each cable on its own
// `phase`; `trail` 1 lifts it out straight behind him (a leap) instead.
// Burnt dark metal with dull gold bands (COLOR.rgb, sRGB; UV2.x 2 the bands' sheen), lit like his body; never
// glowing; dimmed with the court by the arena's light (`scenery_light`: stage 2's darkness, E5d-e). The Cable Lash's
// whipped cable is drawn by GoldenConvergenceLash, not here.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"

global uniform float scenery_light;

uniform float cable_length = 5.6;
uniform float ground = 1.6;
uniform float phase = 0.0;
uniform float sway = 1.0;
uniform float trail = 0.0;
uniform vec3 light_dir = vec3(0.35, 0.85, 0.42);

varying float v_kind;

void vertex() {
	float v = UV.y;
	float t = TIME;
	// Back from the socket, curving down to the ground over most of its length, its end trailing on the floor.
	float k = smoothstep(0.1, 0.9, v);
	float droop = -max(ground, 0.0) * k;
	// Swaying, more toward its end.
	float s = pow(v, 1.3) * sway;
	float side = sin(t * 2.6 + v * 5.0 + phase) * 0.45 * s + sin(t * 4.1 + v * 9.0 + phase * 1.7) * 0.12 * s;
	VERTEX.x += side;
	VERTEX.y += mix(droop, -0.25 * v, trail) + abs(side) * 0.04;
	v_kind = UV2.x;
}

void fragment() {
	vec3 nv = flat_view_normal(VERTEX);
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(nv, 0.0)).xyz);
	vec3 base = to_linear(COLOR.rgb);
	float key = max(dot(n, normalize(light_dir)), 0.0);
	vec3 col = base * (0.35 + 0.8 * key);
	float rim = pow(1.0 - clamp(dot(nv, normalize(-VERTEX)), 0.0, 1.0), 3.0);
	col += base * rim * (0.3 + 0.4 * step(1.5, v_kind));
	ALBEDO = col * light_factor(scenery_light);
}

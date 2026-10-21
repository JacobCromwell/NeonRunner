// The grime on the Terminal intro's route board (TerminalIntroSign): a dirty film over the whole board that the runner's
// hand wipes away. The wipe is the runner's hand's own path, as a trail of points on the board (metres from its middle, one
// per step of the wipe, `trail_count` of them used so far): everything within `radius` of the trail is clean, with a soft,
// smeared edge. Streaked dirt elsewhere; never glowing.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"

global uniform float scenery_light;
global uniform vec3 scenery_tint;

uniform vec2 board_size = vec2(1.5, 1.15);
uniform vec2 trail[48];
uniform int trail_count = 0;
uniform float radius = 0.2;
uniform vec3 grime : source_color = vec3(0.075, 0.07, 0.065);
uniform float opacity = 0.97;
// How much grime is left where it was wiped (a smear).
uniform float residue = 0.07;

void fragment() {
	vec2 p = (UV - 0.5) * board_size;
	float d = 1000.0;
	for (int i = 0; i < 48; i++) {
		if (i >= trail_count) {
			break;
		}
		d = min(d, length(p - trail[i]));
	}
	// A ragged edge: the film lifts in streaks, not in a clean circle.
	float ragged = 0.035 * (value_noise(p * vec2(18.0, 7.0)) - 0.5);
	float wiped = 1.0 - smoothstep(radius * 0.6, radius, d + ragged);
	// Dirt: heavier toward the board's edges and in streaks running down it.
	float edge = 1.0 - smoothstep(0.0, 0.12, min(UV.x, min(UV.y, min(1.0 - UV.x, 1.0 - UV.y))));
	float dirt = 0.82 + 0.22 * value_noise(p * vec2(26.0, 3.0)) + 0.1 * edge;
	float a = opacity * clamp(dirt, 0.0, 1.0);
	a = mix(a, a * residue, wiped);
	ALBEDO = to_linear(grime) * (0.85 + 0.3 * value_noise(p * 11.0)) * light_factor(scenery_light) * scenery_tint;
	ALPHA = clamp(a, 0.0, 1.0);
}

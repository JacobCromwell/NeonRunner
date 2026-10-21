// The glass of the Terminal outro's train that you see through (TerminalTrainModel's front door window): clear
// glass, faintly tinted and dirty, with streaks of grime and a haze caught at a glance, drawn over what is behind it
// (the cab, and the screech in it). Alpha-blended and unshaded; it never glows or flickers, so it suits Reduced flashing.
//   COLOR.rgb  the glass's tint (sRGB)          COLOR.a  its clearest opacity
//   UV         metres across and up the pane
shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"

global uniform float scenery_light;
global uniform vec3 scenery_tint;

// How dirty the glass is (0 clean, 1 filthy), and the hall's haze (plain sRGB, as the skin sets it).
uniform float grime = 0.7;
uniform vec3 tm_haze = vec3(0.42, 0.26, 0.14);

void fragment() {
	vec3 nv = flat_view_normal(VERTEX);
	vec3 eye = normalize(VIEW);
	float facing = clamp(dot(nv, eye), 0.0, 1.0);
	float graze = pow(1.0 - facing, 3.0);
	vec2 uv = UV * 3.0;
	// Streaks of grime running down the pane, smudges where a hand has wiped it, a clean patch or two.
	float streak = smoothstep(0.4, 0.85, value_noise(vec2(uv.x * 4.0, uv.y * 0.5) + 2.0));
	float smudge = smoothstep(0.5, 0.8, value_noise(uv * 1.6 + 8.0));
	float dirt = clamp(streak * 0.7 + smudge * 0.5, 0.0, 1.0) * grime;
	// The foot of the pane collects more.
	dirt = clamp(dirt + (1.0 - UV.y) * 0.18 * grime, 0.0, 1.0);
	vec3 tint = COLOR.rgb;
	vec3 c = mix(tint, vec3(0.2, 0.17, 0.13), dirt * 0.8) + tm_haze * graze * 0.5;
	ALBEDO = to_linear(c) * light_factor(scenery_light) * scenery_tint;
	ALPHA = clamp(COLOR.a + dirt * 0.45 + graze * 0.4, 0.0, 0.85);
}

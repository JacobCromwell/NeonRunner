// A falling gantryway's look (task Q3; GantrywayKit, Gantryway, ZoneSkin.gantryway_material): the mesh kit's lit
// surfaces as kit_solid draws them (vertex colour in sRGB, flat normals from screen-space derivatives, its fake city
// light and sky sheen, the scenery's light and tint; of its patterns, the plain, ROOF and HULL ones the default look
// uses), which dissolve in an ordered dither as the camera comes near them: whole beyond near_fade_end metres, gone
// within near_fade_begin. The chase camera passes through a pillar's column when the runner is in the lane beside it,
// and under a walkway as it falls, either of which would otherwise fill the screen for a few frames. A dither fixed to
// the screen, never a flicker: Reduced flashing leaves it as it is. Nothing glows (COLOR.a is ignored).
// Every derivative is taken before the discard (a discarded pixel's neighbours read it), and the discard comes last.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"

// A level's darker lighting and its sky's tint (ZoneSkin.set_scenery_light, set_scenery_tint), as kit_solid's.
global uniform float scenery_light;
global uniform vec3 scenery_tint;
// Sky glow caught at grazing angles, a cold one by default.
uniform vec3 sheen_color : source_color = vec3(0.42, 0.55, 0.72);
uniform float sheen_strength = 0.3;
// Metres from the camera: gone within the first, whole beyond the second.
uniform float near_fade_begin = 1.0;
uniform float near_fade_end = 2.6;

varying vec3 v_world;

// Thin lines every `period` metres along `coord`, box-filtered (kit_solid's).
float grid_line(float coord, float period, float half_width) {
	float h = half_width / period;
	return filtered_pulse(coord / period + 0.5, fwidth(coord) / period, 0.5 - h, 0.5 + h);
}

// A 2 x 2 and a 4 x 4 ordered dither's threshold at pixel `a` (0 to 15/16).
float bayer2(vec2 a) {
	a = floor(a);
	return fract(a.x * 0.5 + a.y * a.y * 0.75);
}

float bayer4(vec2 a) {
	return bayer2(0.5 * a) * 0.25 + bayer2(a);
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 nv = flat_view_normal(VERTEX);
	vec3 n = (INV_VIEW_MATRIX * vec4(nv, 0.0)).xyz;
	vec3 base = COLOR.rgb;
	int pattern = int(UV2.x + 0.5);
	// Both patterns' lines, worked out whatever the pattern (their derivatives before any branch or discard).
	float z = v_world.z + UV2.y;
	float roof_seam = grid_line(z, 1.6, 0.025);
	float roof_plate = grid_line(z, 0.4, 0.06);
	vec2 p = abs(n.y) > 0.5 ? v_world.xz : (abs(n.x) > 0.5 ? v_world.zy : v_world.xy);
	float hull_lines = max(grid_line(p.y, 3.2, 0.03), 0.6 * grid_line(p.x + 0.6, 2.4, 0.025));
	if (pattern == 1) {
		// ROOF: transverse panel seams and slight plate tones (the grated deck).
		base *= 1.0 - 0.4 * roof_seam;
		base *= 1.0 - 0.12 * roof_plate;
		base *= 0.93 + 0.14 * hash12(vec2(floor(z / 1.6), floor(v_world.x * 0.4)));
	} else if (pattern == 5) {
		// HULL: plating with panel lines and tone variation (girders, the column).
		base *= (0.88 + 0.24 * hash12(floor(vec2(p.x / 2.4, p.y / 3.2)))) * (1.0 - 0.45 * hull_lines);
	}
	// kit_solid's fake city light: tops catch the sky glow, sides the street, undersides the traffic below.
	float shade = 0.62 + 0.3 * max(n.y, 0.0) + 0.08 * abs(n.x) + 0.06 * n.z - 0.04 * max(-n.y, 0.0);
	float f = 1.0 - clamp(dot(nv, VIEW), 0.0, 1.0);
	vec3 sheen = to_linear(sheen_color) * (f * f * f * sheen_strength);
	ALBEDO = (to_linear(base) * shade + sheen) * light_factor(scenery_light) * scenery_tint;
	// Near the camera: dissolved, pixel by pixel.
	float shown = smoothstep(near_fade_begin, near_fade_end, length(VERTEX));
	if (shown <= bayer4(FRAGCOORD.xy)) {
		discard;
	}
}

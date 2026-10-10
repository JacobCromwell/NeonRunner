// The volleyball court's solid props (VolleyballCourt: the net's posts and their padding, the ball's sandy scuff):
// one colour, unshaded with the mesh kit's fake light by the face's direction (as the doodads' cards), so they sit in
// the street's light, dim with a level's darkness (scenery_light) and take the street's light under its level's sky
// (scenery_tint), the same on every renderer. Never emissive.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"

global uniform float scenery_light;
global uniform vec3 scenery_tint;

uniform vec3 color : source_color = vec3(0.8, 0.8, 0.8);

void fragment() {
	vec3 n = (INV_VIEW_MATRIX * vec4(normalize(NORMAL), 0.0)).xyz;
	float shade = 0.62 + 0.3 * max(n.y, 0.0) + 0.08 * abs(n.x) + 0.06 * n.z - 0.04 * max(-n.y, 0.0);
	ALBEDO = to_linear(color) * shade * light_factor(scenery_light) * scenery_tint;
}

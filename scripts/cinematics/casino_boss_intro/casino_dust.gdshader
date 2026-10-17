// The dust of the casino wall's collapse (CasinoWallBreak; the Casino boss intro): soft round puffs of plaster dust,
// each a camera-facing card in one MultiMesh, its size, fade and rise set per instance from the cinematic's clock
// (INSTANCE_CUSTOM: r how opaque, g a seed for its shape). Lit by the kit's fake light (scenery_light,
// scenery_tint); never glowing.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"

global uniform float scenery_light;
global uniform vec3 scenery_tint;

uniform vec3 dust : source_color = vec3(0.56, 0.5, 0.44);
uniform vec3 dust_shade : source_color = vec3(0.3, 0.26, 0.23);

varying float alpha;
varying float seed;

void vertex() {
	alpha = INSTANCE_CUSTOM.r;
	seed = INSTANCE_CUSTOM.g;
	// Face the camera: keep the instance's scale, drop its rotation.
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	mat4 bill = mat4(INV_VIEW_MATRIX[0] * scale.x, INV_VIEW_MATRIX[1] * scale.y, INV_VIEW_MATRIX[2] * scale.z, MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * bill;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float ang = atan(p.y, p.x);
	float lump = 0.82 + 0.12 * sin(ang * 3.0 + seed * 6.0) + 0.06 * sin(ang * 5.0 - seed * 4.0);
	float r = length(p) / lump;
	float a = max(1.0 - r, 0.0);
	a = a * a * alpha;
	vec3 col = mix(to_linear(dust_shade), to_linear(dust), 0.55 + 0.45 * (0.5 - 0.5 * p.y));
	ALBEDO = col * light_factor(scenery_light) * scenery_tint;
	ALPHA = clamp(a, 0.0, 1.0);
}

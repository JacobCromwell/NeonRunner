// The sparks and flashes of the Terminal intro's dying sign (TerminalIntroLetters): soft round dots, each a camera-facing card
// in one MultiMesh, its size and brightness set per instance from the cinematic's clock (INSTANCE_CUSTOM.r: how bright). Additive,
// never fogged (they are small and close to the sign).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform vec3 tint : source_color = vec3(1.0, 0.82, 0.5);
uniform float strength = 3.4;

varying float bright;

void vertex() {
	bright = INSTANCE_CUSTOM.r;
	// Face the camera: keep the instance's scale, drop its rotation.
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	mat4 bill = mat4(INV_VIEW_MATRIX[0] * scale.x, INV_VIEW_MATRIX[1] * scale.y, INV_VIEW_MATRIX[2] * scale.z, MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * bill;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = max(1.0 - length(p), 0.0);
	// A bright core with a short soft edge (it is a spark, not a mist), so it still reads when it is only a few pixels wide.
	float a = smoothstep(0.0, 0.45, r) * (0.55 + 0.45 * r);
	ALBEDO = tint * (a * bright * strength);
}

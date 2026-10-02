// The House's treads (GDD §10: "rolling down the market street on treads"): dark rubber with steel
// links that roll along as it moves (`scroll`, metres the treads have turned). Lit like the rest of the
// scenery; nothing on them glows.
shader_type spatial;
render_mode cull_back;

uniform float scroll = 0.0;
uniform float link = 0.55;

varying vec3 v_local;

void vertex() {
	v_local = VERTEX;
}

void fragment() {
	float t = fract((v_local.z + scroll) / link);
	float cleat = smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(0.42, 0.5, t));
	vec3 rubber = vec3(0.07, 0.065, 0.06);
	vec3 steel = vec3(0.3, 0.3, 0.32);
	ALBEDO = mix(rubber, steel, cleat * 0.7);
	ROUGHNESS = mix(0.85, 0.45, cleat);
	METALLIC = 0.4 * cleat;
}

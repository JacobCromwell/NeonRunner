shader_type spatial;
// Body material for HumanoidRig meshes (built by HumanoidMeshBuilder): the vertex colour is the
// albedo (already linear) and UV.x the glow amount (0 = matte, 1 = neon trim, >1 = brighter), so
// plain parts and glowing trim share one material and each rig segment is a single draw call.
// Plain spatial shading: works on Forward+, Mobile and Compatibility (web, low-end Android).

// Emission of a glow-1 trim. Above the environment's glow threshold, so trims bloom.
uniform float glow_energy = 2.6;
// Multiplies all trim glow: raised while dashing, dimmed after death.
uniform float glow_boost = 1.0;
// Tint over the whole body (invulnerability flash, death flash). Alpha = strength.
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.55;

void fragment() {
	float glow = UV.x;
	vec3 base = COLOR.rgb;
	ALBEDO = mix(base, tint.rgb, tint.a);
	ROUGHNESS = roughness;
	EMISSION = base * glow * glow_energy * glow_boost + tint.rgb * (tint.a * 0.6);
}

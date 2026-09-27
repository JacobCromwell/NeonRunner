shader_type spatial;
// Body material for HumanoidRig meshes (built by HumanoidMeshBuilder): the vertex colour is the
// albedo (already linear) and UV.x the glow amount (0 = matte, 1 = neon trim, >1 = brighter), so
// plain parts and glowing trim share one material and each rig segment is a single draw call.
// UV.y marks a panel's vertices (a coat's skirt), which the rig swings (humanoid_panels.gdshaderinc).
// Plain spatial shading: works on Forward+, Mobile and Compatibility (web, low-end Android).

#include "res://scripts/characters/humanoid_panels.gdshaderinc"

// Emission of a glow-1 trim. Above the environment's glow threshold, so trims bloom.
uniform float glow_energy = 2.6;
// Multiplies all trim glow: raised while dashing, dimmed after death.
uniform float glow_boost = 1.0;
// Albedo of glowing trim relative to its colour. Below 1 the trim's look comes from its own light
// rather than the scene's, so a soft glow keeps its hue and reads the same lit or in the dark.
uniform float glow_albedo = 1.0;
// Tint over the whole body (invulnerability flash, death flash). Alpha = strength.
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.55;
// Roughness of a fully polished piece (HumanoidPiece.shine 1, carried in the vertex colour's alpha).
uniform float polished_roughness : hint_range(0.0, 1.0) = 0.18;
// Rim light (0 = off): a soft glow on the faces seen edge-on, so a dark outfit's silhouette still
// reads on dark ground. Emission, so it needs no light and looks the same on every renderer; it
// stays below the glow threshold (no bloom) and doesn't power down with glow_boost.
uniform vec4 rim_color : source_color = vec4(0.62, 0.7, 0.86, 1.0);
uniform float rim_strength = 0.0;
uniform float rim_power = 2.5;

// HumanoidMeshBuilder stores vertex colours in linear space, which Forward+ and Mobile light in. The
// Compatibility renderer (web, low-end Android) works in sRGB space and shows values as they are
// (kit_common.gdshaderinc handles the same difference for the mesh kit), so there the colour goes
// back to sRGB; without this every colour shows far too dark and too saturated on the web.
vec3 humanoid_base_color(vec3 linear_color) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return mix(12.92 * linear_color, 1.055 * pow(linear_color, vec3(1.0 / 2.4)) - 0.055,
		step(vec3(0.0031308), linear_color));
#else
	return linear_color;
#endif
}

void vertex() {
	vec3 v = VERTEX;
	vec3 n = NORMAL;
	humanoid_panels_vertex(UV, v, n);
	VERTEX = v;
	NORMAL = n;
}

void fragment() {
	float glow = UV.x;
	vec3 base = humanoid_base_color(COLOR.rgb);
	ALBEDO = mix(base * mix(1.0, glow_albedo, step(0.001, glow)), tint.rgb, tint.a);
	ROUGHNESS = mix(polished_roughness, roughness, COLOR.a);
	SPECULAR = mix(0.9, 0.5, COLOR.a);
	float edge = max(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 0.0001);
	EMISSION = base * glow * glow_energy * glow_boost + tint.rgb * (tint.a * 0.6)
		+ rim_color.rgb * rim_strength * pow(edge, rim_power);
}

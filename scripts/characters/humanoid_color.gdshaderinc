// Colour-space helpers for the humanoid rig's shaders (humanoid_body.gdshader, cyborg_body.gdshader)
// and the cyborg kit's part shader. Forward+ and Mobile light in linear space; the Compatibility
// renderer (web, low-end Android) works in sRGB space and shows values as they are
// (kit_common.gdshaderinc handles the same difference for the mesh kit).

// sRGB to linear light and back, on every renderer (for sums of light that must be taken in linear
// light whatever the renderer shows).
vec3 humanoid_to_linear(vec3 srgb) {
	return mix(srgb / 12.92, pow((srgb + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), srgb));
}

vec3 humanoid_to_srgb(vec3 lin) {
	return mix(12.92 * lin, 1.055 * pow(max(lin, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), lin));
}

// Vertex colours from HumanoidMeshBuilder (and the cyborg kit's Builder) are stored in linear space.
// On Compatibility the colour goes back to sRGB; without this every colour shows far too dark and too
// saturated on the web.
vec3 humanoid_base_color(vec3 linear_color) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return humanoid_to_srgb(linear_color);
#else
	return linear_color;
#endif
}

// A glow `energy` times as bright as a colour uniform (source_color: already linear on Forward+ and
// Mobile, sRGB on Compatibility), with the same hue on every renderer. `energy` is linear light.
// Scaling an sRGB colour past 1 washes it toward white (a red charge-up turns cream), so on
// Compatibility the scaling happens in linear light and the result goes back to sRGB (above 1 too,
// so it still blooms).
vec3 humanoid_glow(vec3 color, float energy) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return humanoid_to_srgb(humanoid_to_linear(color) * energy);
#else
	return color * energy;
#endif
}

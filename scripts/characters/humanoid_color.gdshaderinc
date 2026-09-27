// Vertex colours from HumanoidMeshBuilder (and the cyborg kit's Builder) are stored in linear space,
// which Forward+ and Mobile light in. The Compatibility renderer (web, low-end Android) works in sRGB
// space and shows values as they are (kit_common.gdshaderinc handles the same difference for the mesh
// kit), so there the colour goes back to sRGB; without this every colour shows far too dark and too
// saturated on the web. Used by humanoid_body.gdshader, cyborg_body.gdshader and the cyborg kit's
// part shader.

vec3 humanoid_base_color(vec3 linear_color) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return mix(12.92 * linear_color, 1.055 * pow(linear_color, vec3(1.0 / 2.4)) - 0.055,
		step(vec3(0.0031308), linear_color));
#else
	return linear_color;
#endif
}

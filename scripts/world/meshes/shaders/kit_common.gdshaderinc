// Shared helpers for the mesh-kit shaders.

// Colours are authored in sRGB (like inspector colours). Forward+ and Mobile light in linear space,
// so they convert; the Compatibility renderer (web, low-end Android) works in sRGB space and shows
// values as they are, so authored colours pass straight through there.
vec3 to_linear(vec3 c) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return c;
#else
	return mix(c * (1.0 / 12.92), pow((c + 0.055) * (1.0 / 1.055), vec3(2.4)), step(vec3(0.04045), c));
#endif
}

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Integral of a pulse train (period 1, on between a and b) from 0 to x.
float pulse_integral(float x, float a, float b) {
	return floor(x) * (b - a) + clamp(fract(x), a, b) - a;
}

// The pulse train box-filtered over a footprint of width w (in periods): exact anti-aliasing
// that fades to the pulse's average (b - a) when many periods fall into one pixel.
float filtered_pulse(float x, float w, float a, float b) {
	w = max(w, 1e-3);
	return (pulse_integral(x + 0.5 * w, a, b) - pulse_integral(x - 0.5 * w, a, b)) / w;
}

// The flat normal of the face being drawn, in view space, from screen-space derivatives of the
// view-space position (kit meshes carry no normals). Turned toward the camera, so it is right for
// every front face whichever way the renderer's screen y runs.
vec3 flat_view_normal(vec3 view_pos) {
	vec3 n = normalize(cross(dFdx(view_pos), dFdy(view_pos)));
	return dot(n, view_pos) > 0.0 ? -n : n;
}

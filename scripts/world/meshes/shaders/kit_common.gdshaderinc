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

// Smooth value noise in [0, 1): hashed lattice values blended with a smooth curve.
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Graffiti tags on a wall (uv in metres): words of 3-5 chunky, slanted letters (2 x 3 strokes
// each) scattered over slots of 3.2 x 2.6 m, some slots empty. Returns the coverage in x (fading to
// its average at a distance) and a 0-1 pick for the tag's colour in y.
vec2 graffiti(vec2 uv, float seed) {
	vec2 slot = floor(uv / vec2(3.2, 2.6));
	vec2 f = uv - slot * vec2(3.2, 2.6);
	float r = hash12(slot + seed);
	float letters = 3.0 + floor(hash12(slot + seed + 4.0) * 3.0);
	float h = 0.4 + 0.35 * hash12(slot + seed + 3.0);
	vec2 q = f - vec2(0.15 + 0.5 * hash12(slot + seed + 1.0), 0.25 + 1.3 * hash12(slot + seed + 2.0));
	q.x += q.y * 0.35;
	q /= vec2(h * 0.62, h);
	float inside = step(0.0, q.x) * step(q.x, letters) * step(0.0, q.y) * step(q.y, 1.0) * step(0.62, r);
	vec2 gs = vec2(fract(q.x) * 1.25, q.y) * vec2(2.0, 3.0);
	vec2 sub = floor(gs);
	vec2 sf = fract(gs);
	float pick = hash12(sub * 1.37 + floor(q.x) * 7.13 + slot * 3.1 + seed);
	float stroke = pick < 0.42 ? step(abs(sf.y - 0.5), 0.3) : (pick < 0.85 ? step(abs(sf.x - 0.5), 0.34) : 0.0);
	stroke *= step(sub.x, 1.5);
	float fw = max(fwidth(q.x), fwidth(q.y));
	return vec2(inside * mix(stroke, 0.35, smoothstep(0.08, 0.3, fw)), hash12(slot + seed + 5.0));
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

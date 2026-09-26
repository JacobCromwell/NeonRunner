// A night sky for any zone: a gradient from the horizon haze up to the zenith, a few stars, a moon,
// and a distant skyline of silhouettes with lit windows (two layers). Zones tune it with uniforms:
// the Neon City has clear violet haze and a moon; Gangland has smog, a ruined skyline and columns of
// smoke lit by fires below. No TIME, so the sky's radiance never needs updating; it costs one pass
// of cheap math over the visible sky.
shader_type sky;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"

uniform vec3 zenith_color : source_color = vec3(0.015, 0.012, 0.05);
uniform vec3 horizon_color : source_color = vec3(0.2, 0.1, 0.36);
uniform vec3 haze_color : source_color = vec3(0.38, 0.22, 0.62);
uniform vec3 abyss_color : source_color = vec3(0.03, 0.02, 0.07);
uniform vec3 skyline_color : source_color = vec3(0.06, 0.05, 0.12);
uniform vec3 window_color : source_color = vec3(0.95, 0.78, 0.55);
// A big moon low over the far end of the street, seen between the buildings (radius 0 = none).
uniform vec3 moon_color : source_color = vec3(0.85, 0.8, 1.0);
uniform vec3 moon_direction = vec3(0.07, 0.3, -0.95);
uniform float moon_radius = 0.075;
// How much of the moon shows through smog (1 = clear sky).
uniform float moon_clarity = 1.0;
uniform float haze_height = 0.1;
uniform float haze_strength = 0.9;
uniform float star_amount = 0.5;
// 0 = intact skyline; 1 = bombed out: broken, jagged tops and few lights.
uniform float skyline_ruin = 0.0;
// Columns of smoke rising from the skyline, lit from below by fires (0 = none).
uniform float smoke_amount = 0.0;
uniform vec3 smoke_color : source_color = vec3(0.08, 0.07, 0.07);
uniform vec3 fire_color : source_color = vec3(0.55, 0.24, 0.1);

// One ring of building silhouettes around the horizon. `count` buildings per full turn,
// heights between lo and hi (in sin(elevation)). Returns rgb plus coverage in a.
vec4 skyline(float az, float el, float count, float lo, float hi, float seed, vec3 body, vec3 win, float lit_share) {
	float x = az / 6.2832 * count;
	float id = floor(x);
	float fx = fract(x);
	float h = lo + (hi - lo) * pow(hash11(id * 1.37 + seed), 1.7);
	// Ruins: chunks bitten out of the tops.
	h -= skyline_ruin * (hi - lo) * 0.45 * step(0.45, hash11(floor(fx * 5.0) + id * 7.7 + seed))
		* hash11(floor(fx * 5.0) * 3.1 + id + seed);
	float w0 = 0.12 * hash11(id * 2.11 + seed);
	float w1 = 1.0 - 0.12 * hash11(id * 3.07 + seed);
	float spire = step(0.8, hash11(id * 5.3 + seed)) * step(abs(fx - 0.5), 0.03) * step(el, h + 0.025)
		* (1.0 - skyline_ruin);
	float inside = max(step(w0, fx) * step(fx, w1) * step(el, h), spire);
	vec2 wc = vec2(floor(fx * 9.0), floor(el * 260.0));
	float lit = step(1.0 - lit_share * (1.0 - 0.9 * skyline_ruin), hash12(wc + id * 3.1 + seed));
	// A ruined city shows no lights below the horizon (the intact one is a sea of them).
	float wmask = step(0.35, fract(fx * 9.0)) * step(0.45, fract(el * 260.0)) * step(el, h - 0.004)
		* (1.0 - skyline_ruin * step(el, 0.0));
	return vec4(mix(body, win, lit * wmask), inside);
}

// Smoke density at a direction: columns at hashed bearings, widening and wavering as they rise.
float smoke(float az, float el) {
	float x = az / 6.2832 * 9.0;
	float id = floor(x);
	float fx = fract(x) - 0.5;
	float base = 0.015 + 0.04 * hash11(id * 1.3 + 4.0);
	float t = max(el - base, 0.0);
	float center = (hash11(id * 3.7) - 0.5) * 0.5 + (sin(el * 23.0 + id * 5.0) * 0.03 + sin(el * 7.0 + id) * 0.08) * (0.3 + t * 6.0);
	float width = 0.05 + t * 0.9;
	float d = abs(fx - center);
	float column = (1.0 - smoothstep(width * 0.45, width, d)) * smoothstep(0.0, 0.03, el - base)
		* (1.0 - smoothstep(0.2, 0.55, el));
	return column * step(0.3, hash11(id * 9.1)) * (0.7 + 0.3 * hash11(floor(el * 60.0) + id * 2.0));
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float el = d.y;
	float az = atan(d.x, -d.z);
	vec3 col = mix(to_linear(horizon_color), to_linear(zenith_color), pow(smoothstep(0.0, 0.75, el), 0.55));
	col += to_linear(haze_color) * (haze_strength * exp(-max(el, 0.0) / haze_height));
	col = mix(col, to_linear(abyss_color), smoothstep(0.0, -0.3, el));

	if (el > 0.08 && star_amount > 0.0) {
		vec2 sp = vec2(az * 160.0, el * 160.0);
		float star = step(1.0 - 0.02 * star_amount, hash12(floor(sp)));
		float sd = length(fract(sp) - 0.5);
		col += vec3(0.8, 0.85, 1.0) * star * (1.0 - smoothstep(0.05, 0.2, sd)) * smoothstep(0.08, 0.3, el) * 0.6;
	}

	// The moon: a pale disc with darker seas, lit from one side, softened by the haze near the horizon.
	if (moon_radius > 0.0) {
		vec3 md = normalize(moon_direction);
		float c = dot(d, md);
		float r = sqrt(max(0.0, 2.0 - 2.0 * c));
		if (r < moon_radius * 3.0) {
			float disc = 1.0 - smoothstep(moon_radius * 0.97, moon_radius, r);
			vec3 east = normalize(cross(md, vec3(0.0, 1.0, 0.0)));
			vec3 north = cross(east, md);
			vec2 q = vec2(dot(d, east), dot(d, north)) / moon_radius;
			float seas = 0.78 + 0.22 * smoothstep(0.2, 0.5, hash12(floor(q * 5.0 + 11.0)) * 0.6 + 0.2 * sin(q.x * 3.1 + q.y * 4.7));
			float lit = clamp(0.35 + 0.75 * (q.x * 0.6 + q.y * 0.35), 0.18, 1.0);
			vec3 moon = to_linear(moon_color) * (seas * lit * 1.15);
			float veil = smoothstep(0.02, 0.35, el) * moon_clarity;
			col = mix(col, mix(col + moon * 0.4 * moon_clarity, moon, veil), disc);
			col += to_linear(moon_color) * (0.18 * moon_clarity * (1.0 - disc) * exp(-(r - moon_radius) * 30.0));
		}
	}

	vec3 haze = to_linear(haze_color) * haze_strength;
	vec3 body = to_linear(skyline_color);
	vec3 win = to_linear(window_color);
	vec4 far = skyline(az, el, 420.0, 0.02, 0.09, 11.0, mix(body, haze, 0.55), mix(win, haze, 0.5), 0.12);
	col = mix(col, far.rgb, far.a);
	if (smoke_amount > 0.0) {
		float s = smoke(az, el) * smoke_amount;
		vec3 plume = mix(to_linear(smoke_color), to_linear(fire_color), exp(-max(el - 0.02, 0.0) * 18.0));
		col = mix(col, plume, clamp(s, 0.0, 0.9));
	}
	vec4 near = skyline(az, el, 190.0, 0.01, 0.06, 37.0, body, win, 0.18);
	col = mix(col, near.rgb, near.a);
	COLOR = col;
}

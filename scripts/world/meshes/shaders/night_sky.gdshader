// A night sky for any zone: a gradient from the horizon haze up to the zenith, a few stars, a moon,
// and a distant skyline of silhouettes with lit windows (two layers). Zones tune it with uniforms:
// the Neon City has clear violet haze and a moon; Gangland has smog, a ruined skyline and columns of
// smoke lit by fires below. A level may show its own sky over its zone's (LevelSky): a glow on the
// horizon where the sun is about to rise or has just set, and a layer of cloud whose undersides
// catch that light (both off by default). No TIME, so the sky's radiance never needs updating; it
// costs one pass of cheap math over the visible sky (the clouds, where a level has them, a few
// octaves of value noise more).
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
// 1 = the skyline is smooth rolling hills (a coast, an island: no spires, no lit windows) instead of
// buildings; skyline_scale scales every height (the Beach's island on the horizon is low).
uniform float skyline_hills = 0.0;
uniform float skyline_scale = 1.0;
// How far below the horizon (sin of the elevation) the sky has become the abyss colour: the default is a deep
// fall; a short one (the Beach) is a sea that starts at the horizon.
uniform float abyss_depth = 0.3;
// Columns of smoke rising from the skyline, lit from below by fires (0 = none).
uniform float smoke_amount = 0.0;
uniform vec3 smoke_color : source_color = vec3(0.08, 0.07, 0.07);
uniform vec3 fire_color : source_color = vec3(0.55, 0.24, 0.1);
// How quickly the horizon colour gives way to the zenith's going up (lower: the zenith colour reaches
// further down, leaving the horizon colour to the bottom of the sky).
uniform float horizon_falloff = 0.55;
// A glow low over the horizon at one bearing, where the sun is just below it: at dawn or as it sets
// (strength 0 = none). focus narrows it round the horizon; height is how far up it reaches (in
// sin(elevation)).
uniform vec3 sun_glow_color : source_color = vec3(1.0, 0.5, 0.45);
uniform vec3 sun_glow_direction = vec3(0.3, 0.0, -0.95);
uniform float sun_glow_strength = 0.0;
uniform float sun_glow_focus = 3.0;
uniform float sun_glow_height = 0.15;
// A layer of cloud over the city (amount 0 = clear, 1 = overcast; scale > 1 = smaller clouds). Their
// bodies are cloud_color; their undersides catch cloud_lit_color, light from below the horizon (a
// rising or setting sun, fires), the more so the lower they hang and toward sun_glow_direction by
// cloud_lit_focus (0 = lit from all around, as by fires).
uniform float cloud_amount = 0.0;
uniform float cloud_scale = 1.0;
uniform float cloud_opacity = 0.9;
uniform vec3 cloud_color : source_color = vec3(0.1, 0.08, 0.16);
uniform vec3 cloud_lit_color : source_color = vec3(0.9, 0.4, 0.55);
uniform float cloud_lit_focus = 0.6;

// One ring of building silhouettes around the horizon. `count` buildings per full turn,
// heights between lo and hi (in sin(elevation)). Returns rgb plus coverage in a.
vec4 skyline(float az, float el, float count, float lo, float hi, float seed, vec3 body, vec3 win, float lit_share) {
	float x = az / 6.2832 * count;
	float id = floor(x);
	float fx = fract(x);
	float h = lo + (hi - lo) * pow(hash11(id * 1.37 + seed), 1.7);
	if (skyline_hills > 0.0) {
		// Rolling hills: each cell's height eases into its neighbour's.
		float h2 = lo + (hi - lo) * pow(hash11((id + 1.0) * 1.37 + seed), 1.7);
		h = mix(h, mix(h, h2, smoothstep(0.0, 1.0, fx)), skyline_hills);
	}
	h *= skyline_scale;
	// Ruins: chunks bitten out of the tops.
	h -= skyline_ruin * (hi - lo) * 0.45 * step(0.45, hash11(floor(fx * 5.0) + id * 7.7 + seed))
		* hash11(floor(fx * 5.0) * 3.1 + id + seed);
	float w0 = 0.12 * hash11(id * 2.11 + seed) * (1.0 - skyline_hills);
	float w1 = 1.0 - 0.12 * hash11(id * 3.07 + seed) * (1.0 - skyline_hills);
	float spire = step(0.8, hash11(id * 5.3 + seed)) * step(abs(fx - 0.5), 0.03) * step(el, h + 0.025)
		* (1.0 - skyline_ruin) * (1.0 - skyline_hills);
	float inside = max(step(w0, fx) * step(fx, w1) * step(el, h), spire);
	// Hills stand on the sea: nothing of them below the horizon.
	inside *= mix(1.0, step(0.0, el), skyline_hills);
	vec2 wc = vec2(floor(fx * 9.0), floor(el * 260.0));
	float lit = step(1.0 - lit_share * (1.0 - 0.9 * skyline_ruin), hash12(wc + id * 3.1 + seed));
	// A ruined city shows no lights below the horizon (the intact one is a sea of them).
	float wmask = step(0.35, fract(fx * 9.0)) * step(0.45, fract(el * 260.0)) * step(el, h - 0.004)
		* (1.0 - skyline_ruin * step(el, 0.0)) * (1.0 - skyline_hills);
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

// Cloud density (0-1, averaging 0.5 whatever the octaves) at a point of the cloud layer: `octaves` of
// value noise, the finest two only as much as `detail` (they would shimmer where the layer recedes to
// the horizon).
float cloud_density(vec2 p, int octaves, float detail) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < octaves; i++) {
		v += a * (i < 2 ? value_noise(p) : mix(0.5, value_noise(p), detail));
		p = p * 2.03 + vec2(17.1, 9.7);
		a *= 0.5;
	}
	return v + a;
}

// The cloud layer at a direction: its colour, and its cover in a.
vec4 clouds(vec3 d, float el) {
	// The layer is a plane overhead: it recedes to a thin band at the horizon. Clouds stretch across
	// the street.
	vec2 p = d.xz / (max(el, 0.0) + 0.12) * vec2(0.55, 1.3) * cloud_scale;
	float detail = smoothstep(0.04, 0.3, el);
	float n = cloud_density(p, 4, detail);
	float edge = 0.78 - 0.6 * cloud_amount;
	float cover = smoothstep(edge, edge + 0.12, n) * smoothstep(-0.01, 0.05, el);
	// Light from below the horizon: toward its bearing (cloud_lit_focus), on the lower clouds, on their
	// thin edges, and on the side of each cloud that faces it (the density falls away toward it).
	vec2 toward = normalize(sun_glow_direction.xz + vec2(1e-4, 0.0));
	float facing = dot(normalize(d.xz + vec2(1e-4, 0.0)), toward) * 0.5 + 0.5;
	float bearing = mix(1.0, facing * facing, cloud_lit_focus);
	float low = 1.0 - 0.6 * smoothstep(0.0, 0.7, el);
	float thin = 1.0 - smoothstep(0.0, 0.2, n - edge);
	float rim = clamp((n - cloud_density(p + toward * vec2(0.55, 1.3) * 0.35, 2, 1.0)) * 5.0, 0.0, 1.0);
	float lit = clamp(bearing * low * (0.25 + 0.3 * thin + 0.7 * rim), 0.0, 1.0);
	return vec4(mix(to_linear(cloud_color), to_linear(cloud_lit_color), lit), cover * cloud_opacity);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float el = d.y;
	float az = atan(d.x, -d.z);
	vec3 col = mix(to_linear(horizon_color), to_linear(zenith_color), pow(smoothstep(0.0, 0.75, el), horizon_falloff));
	col += to_linear(haze_color) * (haze_strength * exp(-max(el, 0.0) / haze_height));
	if (sun_glow_strength > 0.0) {
		vec2 toward = normalize(sun_glow_direction.xz + vec2(1e-4, 0.0));
		float facing = max(dot(normalize(d.xz + vec2(1e-4, 0.0)), toward), 0.0);
		col += to_linear(sun_glow_color) * (sun_glow_strength * pow(facing, sun_glow_focus) * exp(-max(el, 0.0) / sun_glow_height));
	}
	col = mix(col, to_linear(abyss_color), smoothstep(0.0, -abyss_depth, el));

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

	if (cloud_amount > 0.0 && el > -0.01) {
		vec4 c = clouds(d, el);
		col = mix(col, c.rgb, c.a);
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

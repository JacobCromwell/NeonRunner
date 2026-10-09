// The Gangland outro's sports car (SportsCarModel): candy paint, dark glass, matte trim and chrome, faceted
// like the mesh kit (each face's normal from screen-space derivatives) and unshaded, with a fake key light
// and a fake street mirrored in it, so it shines alike on the Compatibility renderer (web, low-end Android)
// and on Forward+. The street's neon streams back over the body as it drives (`travelled`).
//   COLOR.rgb  albedo (sRGB)            COLOR.a  glow: 0 = a lit surface, above 0 = emissive (x glow_scale)
//   UV2.x      finish: 0 paint, 1 glass, 2 matte trim, 3 chrome
//   UV2.y      light group: 0 always as it is, 1 its lights (head, tail, running lights: x `lights`)
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"

// A level's darker lighting and the street's light under a level's sky (as the kit's shaders).
global uniform float scenery_light;
global uniform vec3 scenery_tint;

uniform float glow_scale = 3.0;
// Its lights, 0 (off) to 1 (on).
instance uniform float lights = 0.0;
// Metres it has driven: the street's reflections stream back over it.
instance uniform float travelled = 0.0;
// The street mirrored in it: the sky overhead and at the horizon, the neon of the shopfronts along the
// horizon, the road below.
uniform vec3 sky_top : source_color = vec3(0.09, 0.05, 0.08);
uniform vec3 sky_horizon : source_color = vec3(0.75, 0.36, 0.28);
uniform vec3 neon_a : source_color = vec3(1.0, 0.62, 0.3);
uniform vec3 neon_b : source_color = vec3(0.5, 0.72, 1.0);
uniform vec3 road : source_color = vec3(0.05, 0.045, 0.045);
// The key light (world direction toward it) and how much of the albedo shows away from it.
uniform vec3 light_dir = vec3(-0.4, 0.8, 0.45);
uniform float ambient = 0.3;
// The highlight's tightness and strength.
uniform float shine = 70.0;
uniform float shine_strength = 1.6;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// The street seen along world direction `r` (sRGB).
vec3 street(vec3 r) {
	// A sharp horizon: the bright sky over it, the dark road under it (the line every car's paint carries).
	vec3 c;
	if (r.y > 0.0) {
		c = mix(sky_horizon, sky_top, pow(r.y, 0.4));
	} else {
		c = mix(sky_horizon * 0.35, road, smoothstep(0.0, 0.04, -r.y));
	}
	// Shopfront neon along the horizon: lit columns of two colours, streaming past as it drives.
	float band = 1.0 - smoothstep(0.03, 0.2, abs(r.y - 0.05));
	float az = atan(r.x, r.z) * 5.0 + travelled * 0.12;
	float cell = floor(az);
	float lit = step(0.45, hash11(cell * 1.7 + 3.0));
	float edge = smoothstep(0.0, 0.12, fract(az)) * smoothstep(1.0, 0.7, fract(az));
	vec3 neon = mix(neon_a, neon_b, step(0.5, hash11(cell + 11.0)));
	c += neon * band * lit * edge * 1.4;
	return c;
}

void fragment() {
	vec3 nv = flat_view_normal(VERTEX);
	vec3 n = (INV_VIEW_MATRIX * vec4(nv, 0.0)).xyz;
	vec3 eye = (INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz;
	vec3 r = reflect(-eye, n);
	vec3 base = COLOR.rgb;
	float glow = COLOR.a;
	int finish = int(UV2.x + 0.5);
	vec3 col;
	if (glow > 0.002) {
		float g = glow * glow_scale * (UV2.y > 0.5 ? lights : 1.0);
		col = to_linear(base) * g;
	} else {
		vec3 l = normalize(light_dir);
		float lambert = ambient + (1.0 - ambient) * max(dot(n, l), 0.0);
		float facing = clamp(dot(n, eye), 0.0, 1.0);
		float fresnel = pow(1.0 - facing, 4.0);
		float spec = pow(max(dot(r, l), 0.0), shine) * shine_strength;
		vec3 mirror = street(r);
		vec3 c;
		if (finish == 1) {
			// Glass: near black, a mirror at a glance.
			c = base * 0.4 + mirror * (0.18 + 0.7 * fresnel) + vec3(spec);
		} else if (finish == 2) {
			// Matte trim: rubber, intakes, the cabin.
			c = base * lambert + mirror * 0.04 * fresnel;
		} else if (finish == 3) {
			// Chrome: the street, tinted.
			c = mirror * base * 1.6 + vec3(spec) * 0.8;
		} else {
			// Candy paint under a clear coat: the colour, the street mirrored in the coat (more at a glance), a
			// broad sheen round the highlight and the highlight itself.
			float coat = 0.16 + 0.8 * pow(1.0 - facing, 3.0);
			float sheen = pow(max(dot(r, l), 0.0), 6.0) * 0.3;
			c = base * lambert * (1.0 - coat * 0.4) + mirror * coat + vec3(spec + sheen);
		}
		col = to_linear(c) * light_factor(scenery_light) * scenery_tint;
	}
	ALBEDO = col;
}

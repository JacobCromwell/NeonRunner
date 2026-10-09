// The Magnate's body (GDD §10, Second stage, owner approved, October 9, 2026: "blackish-grey skin cracked like
// burnt paper or cooled slag; splashes of the suit's gold melted onto him (dull, never glowing); half of the calm
// golden mask fused to one side of his face, dull red tear and all ... the cape's remains as burgundy tatters
// trailing smoke. No glowing embers (orange is a hazard colour). Optional: cracks leaking the cult's warm white
// glow, as if the broadcast lives inside him (checked against the runner's own glow)").
// GoldenConvergenceMagnateModel's meshes:
//   COLOR.rgb  albedo (sRGB)          COLOR.a  how cracked: 1 his burnt skin (the crack network), 0 none
//   UV2.x      0 lit, 1 cloth (a tatter: sways, UV2.y its weight from its root), 2 metal (gold: a dull sheen,
//              UV2.y its polish)
// The cracks: a cell network over his skin (projected on each flat face's main plane, in his own space so it
// rides with him), the plates between them toned like burnt paper, the cracks dark with a thin core of the cult's
// warm white (crack_glow; 0 dark cracks, faded out by his defeat). Warm white, not the runner's copper, and never
// a hazard hue. Unshaded with a fixed key light in the world (like the cape's), so both renderers match; colours
// in sRGB (kit_common's to_linear). Nothing flashes: `shudder` (his defeat's convulsions) only shakes him, a
// little less with Reduced flashing.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"
#include "res://scripts/world/meshes/shaders/kit_flash.gdshaderinc"

// The warm white in his cracks (0: none), the cracks' cells per metre, their colours (sRGB).
uniform float crack_glow = 0.55;
uniform float crack_scale = 6.5;
uniform vec3 crack_color : source_color = vec3(1.0, 0.93, 0.82);
uniform vec3 crack_dark : source_color = vec3(0.03, 0.027, 0.025);
// The court's warm key light (world space) and the cool fill from the vault.
uniform vec3 light_dir = vec3(0.35, 0.85, 0.42);
uniform vec3 fill_color : source_color = vec3(0.33, 0.31, 0.3);
// How hard the tatters sway (1 at a run), and the defeat's convulsions (0-1).
uniform float sway = 1.0;
uniform float shudder = 0.0;

varying vec3 v_obj;
varying float v_crack;
varying float v_kind;
varying float v_param;

void vertex() {
	v_kind = UV2.x;
	v_param = UV2.y;
	v_crack = COLOR.a;
	float t = TIME;
	if (UV2.x > 0.5 && UV2.x < 1.5) {
		// A tatter: rippling out behind him, more toward its ragged end.
		float k = UV2.y;
		VERTEX.x += sin(t * 3.4 + VERTEX.z * 3.0 + VERTEX.y * 2.0) * 0.08 * k * sway;
		VERTEX.z += (0.6 + 0.4 * sin(t * 2.2 + VERTEX.x * 4.0)) * 0.18 * k * sway;
		VERTEX.y += sin(t * 4.3 + VERTEX.x * 5.0) * 0.035 * k * sway;
	}
	// The convulsions: a fast shiver through his whole body (gentler with Reduced flashing).
	float shake = shudder * mix(1.0, 0.4, reduced_flashing);
	VERTEX += vec3(sin(t * 31.0 + VERTEX.z * 7.0), sin(t * 27.0 + VERTEX.x * 9.0), sin(t * 23.0 + VERTEX.y * 8.0)) * 0.025 * shake;
	v_obj = VERTEX;
}

// The cell network at p: the distance to the nearest crack (the second-nearest cell's centre less the
// nearest's, in cells) and the nearest cell's own random value.
vec2 cells(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	float id = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(hash12(i + g), hash12(i + g + 17.3)) * 0.8 + 0.1;
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = hash12(i + g + 3.7);
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec2(sqrt(d2) - sqrt(d1), id);
}

void fragment() {
	vec3 nv = flat_view_normal(VERTEX);
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(nv, 0.0)).xyz);
	vec3 l = normalize(light_dir);
	vec3 view_w = normalize((INV_VIEW_MATRIX * vec4(-VERTEX, 0.0)).xyz);
	vec3 base = to_linear(COLOR.rgb);
	// Lit from the court's warm light above, a cool fill from below, a faint rim so the dark body keeps its
	// outline against the marble.
	float key = max(dot(n, l), 0.0);
	vec3 col = base * (0.28 + 0.82 * key) + base * to_linear(fill_color) * (0.5 + 0.5 * n.y) * 0.6;
	float rim = pow(1.0 - clamp(dot(nv, normalize(-VERTEX)), 0.0, 1.0), 3.0);
	col += base * rim * 0.35;
	// Metal (the mask, the gold melted on, the cables' bands): a dull sheen, never glowing.
	float metal = step(1.5, v_kind);
	vec3 h = normalize(l + view_w);
	float spec = pow(max(dot(n, h), 0.0), 18.0) * (0.25 + 0.5 * v_param);
	col += base * spec * metal * 0.9;
	// The cracks: the cell network on this face's main plane (in his own space), fine and uneven.
	vec3 on = abs(normalize(cross(dFdx(v_obj), dFdy(v_obj))));
	vec2 q = on.y > max(on.x, on.z) ? v_obj.xz : (on.x > on.z ? v_obj.zy : v_obj.xy);
	q += vec2(value_noise(q * 2.3), value_noise(q * 2.3 + 7.1)) * 0.12;
	vec2 c = cells(q * crack_scale);
	float aa = fwidth(c.x) + 1e-4;
	// Wider and narrower as they run (burnt paper splits unevenly), fading where they get too fine to draw.
	float w = 0.035 + 0.03 * value_noise(q * 5.0);
	float fade = 1.0 - smoothstep(0.08, 0.3, aa);
	float crack = (1.0 - smoothstep(w, w + aa * 1.5, c.x)) * v_crack * fade;
	float core = (1.0 - smoothstep(w * 0.35, w * 0.35 + aa, c.x)) * v_crack * fade;
	// Only some of them leak light, in patches, as if the broadcast shows through where he's burnt deepest.
	float leak = smoothstep(0.45, 0.75, value_noise(q * 1.1 + 3.0));
	// The plates between them, toned like burnt paper or slag.
	col *= mix(1.0, mix(0.72, 1.18, c.y), v_crack);
	col = mix(col, to_linear(crack_dark), crack);
	// The cult's warm white leaking from those cracks' cores.
	col += to_linear(crack_color) * core * leak * crack_glow * 1.5;
	ALBEDO = col;
}

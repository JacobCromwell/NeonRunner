// The city streaming past the Chairman's train (HostileTakeoverSkin; GDD §10: "the sense of speed comes
// from the scenery streaming past", the City's moving road turned onto the scenery): corporate towers
// beyond the sound barriers rushing back toward the runner at `speed` (the train's speed over the
// ground). Each chunk draws one mesh per side holding every tower of a pattern `period` metres long, and
// the vertex shader moves them: a tower's near end has its place in the pattern (UV2.x, a track distance
// at time 0) and it shows only in the slice of the track its near end is in now (UV2.y: the slice's
// start, slice_length long), so the towers flow from slice to slice with no seam and nothing is made
// while the train runs. VERTEX.z holds a vertex's offset from its tower's near end.
// Windows glow cold white or in the brand's blue (never a hazard colour); the fog fades the towers away.
//   COLOR.rgb  the tower's cladding (sRGB)   COLOR.a  its seed (0-1)   UV  metres on its face
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, world_vertex_coords;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"

// A level's darker lighting (ZoneSkin.apply_darkness).
global uniform float scenery_light;
uniform float speed = 45.0;
uniform float period = 240.0;
uniform float slice_length = 40.0;
uniform vec3 window_cold : source_color = vec3(0.78, 0.86, 0.98);
uniform vec3 window_brand : source_color = vec3(0.14, 0.27, 1.0);
uniform float window_glow = 0.85;
// The share of windows lit, and of those in the brand's blue.
uniform float lit_share = 0.3;
uniform float brand_share = 0.07;

varying vec2 v_face;
varying float v_seed;

void vertex() {
	float now = UV2.x - speed * TIME;
	float rel = mod(now - UV2.y, period);
	if (rel >= slice_length) {
		// Not in this slice now: collapsed out of sight.
		VERTEX = vec3(0.0, -1.0e5, 0.0);
	} else {
		VERTEX.z -= UV2.y + rel;
	}
	v_face = UV;
	v_seed = COLOR.a;
}

void fragment() {
	vec3 nv = flat_view_normal(VERTEX);
	vec3 n = (INV_VIEW_MATRIX * vec4(nv, 0.0)).xyz;
	vec2 p = v_face;
	vec2 fw = max(fwidth(p), vec2(1e-4));
	vec3 base = to_linear(COLOR.rgb);
	vec3 col;
	if (n.y > 0.5) {
		// The roof: dark, with a faint rim of plant.
		col = base * 0.55 * light_factor(scenery_light);
	} else {
		// Storeys of glass behind steel mullions; a pixel covering many windows shows their average.
		vec2 cell_size = vec2(1.9, 3.4);
		vec2 q = p / cell_size;
		vec2 fq = fw / cell_size;
		float win = filtered_pulse(q.x, fq.x, 0.12, 0.88) * filtered_pulse(q.y, fq.y, 0.3, 0.82);
		vec2 cell = floor(q);
		float lit = step(1.0 - lit_share, hash12(cell + v_seed * 97.0));
		float far = smoothstep(0.25, 0.8, max(fq.x, fq.y));
		lit = mix(lit, lit_share, far);
		vec3 tint = hash12(cell * 1.7 + v_seed * 31.0) < brand_share ? window_brand : window_cold;
		// Sides the train runs along catch more of the city's glow than the ends.
		float shade = 0.5 + 0.12 * abs(n.x) + 0.05 * n.z;
		vec3 wall = mix(base * shade, base * 0.3, win);
		col = wall * light_factor(scenery_light) + to_linear(tint) * (win * lit * window_glow);
	}
	ALBEDO = col;
}

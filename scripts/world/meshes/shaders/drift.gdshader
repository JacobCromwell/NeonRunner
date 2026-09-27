// Drifting ash, paper scraps and speed streaks: motion for still streets (GDD §5, proposed).
// Billboards animated in the vertex shader, so a whole chunk's worth is one static mesh surface and
// nothing runs per frame on the CPU (MeshKit.drift_particles builds them).
//   VERTEX  the particle's anchor: x and y across and up, z the far end of its slice
//   UV      the corner (-1..1)
//   UV2     x = kind (0 ash fleck, 1 paper scrap, 2 speed streak), y = phase (0..1) along the slice
//   COLOR   rgb colour (sRGB), a = opacity
// Particles travel toward the player (+z) through their slice of `slice_length` metres and wrap,
// fading out and back in, so slices tile seamlessly whichever chunks exist.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"

// A level's darker lighting (ZoneSkin.apply_darkness): the scenery dims with it.
global uniform float scenery_light;

uniform float slice_length = 40.0;
// Speeds toward the player over the ground (m/s); the player's own speed adds to them.
uniform float ash_speed = 6.0;
uniform float streak_speed = 24.0;
// Particles fade out close to the camera (they would fill the screen) and in the distance.
uniform float fade_near = 2.5;
uniform float fade_far = 45.0;

varying float v_alpha;
varying vec2 v_corner;
varying float v_kind;

void vertex() {
	float kind = floor(UV2.x + 0.5);
	float phase = UV2.y;
	float t = fract(phase + TIME * (kind > 1.5 ? streak_speed : ash_speed) / slice_length);
	float s = phase * 57.0;
	vec3 p = VERTEX + vec3(0.0, 0.0, t * slice_length);
	vec3 view;
	if (kind > 1.5) {
		// A streak: a thin line along the track, about two pixels wide at any distance.
		float len = 2.0 + 4.0 * fract(s);
		vec3 a = (MODELVIEW_MATRIX * vec4(p, 1.0)).xyz;
		vec3 b = (MODELVIEW_MATRIX * vec4(p + vec3(0.0, 0.0, len), 1.0)).xyz;
		vec3 side = normalize(cross(b - a, a)) * max(0.012, 0.002 * length(a));
		view = mix(a, b, UV.y * 0.5 + 0.5) + side * UV.x;
	} else {
		// Ash and scraps tumble, sway across the street and settle slowly.
		p.x += sin(TIME * 0.9 + s) * 0.6;
		p.y += sin(TIME * 1.3 + s * 1.7) * 0.25 - t * 1.5;
		float size = kind > 0.5 ? 0.1 : 0.05;
		float spin = TIME * (1.5 + fract(s * 3.0) * 3.0) + s;
		vec2 c = UV * size * vec2(1.0, kind > 0.5 ? 0.6 : 1.0);
		c = vec2(c.x * cos(spin) - c.y * sin(spin), c.x * sin(spin) + c.y * cos(spin));
		view = (MODELVIEW_MATRIX * vec4(p, 1.0)).xyz + vec3(c, 0.0);
	}
	VERTEX = view;
	float d = length(view);
	v_alpha = COLOR.a * smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.85, 1.0, t))
		* smoothstep(fade_near * 0.5, fade_near, d) * (1.0 - smoothstep(fade_far * 0.6, fade_far, d));
	v_corner = UV;
	v_kind = kind;
}

void fragment() {
	float shape = max(1.0 - length(v_corner), 0.0);
	if (v_kind > 1.5) {
		// Soft across, brightest at the head (the end nearest the player).
		shape = (1.0 - abs(v_corner.x)) * (0.5 + 0.5 * v_corner.y);
	} else if (v_kind > 0.5) {
		shape = 1.0;
	}
	ALBEDO = to_linear(COLOR.rgb) * light_factor(scenery_light);
	ALPHA = v_alpha * shape;
}

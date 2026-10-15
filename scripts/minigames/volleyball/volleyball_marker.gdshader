// Where a ball to the runner comes down (VolleyballMatch): a ring on the sand in the ball's lane, on the runner's line,
// shown from the moment it's hit, and a second ring closing in on it that meets it when it's time to jump. White with a
// dark outline so it reads on the bright sand; steady (no flashing), unshaded, never a hazard colour: it marks a safe
// spot, the way to win the point. Alpha scissor, so no sorting.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"

uniform vec3 ring_color : source_color = vec3(0.97, 0.97, 0.95);
uniform vec3 outline_color : source_color = vec3(0.08, 0.1, 0.16);
// The quad's half size (metres), the fixed ring's radius, the closing ring's radius now, and the rings' width.
uniform float quad_half = 1.4;
uniform float radius = 0.55;
uniform float closing = 1.2;
uniform float width = 0.07;
uniform float outline = 0.03;

float ring(float d, float r, float w) {
	return step(abs(d - r), w * 0.5);
}

void fragment() {
	float d = length((UV - 0.5) * 2.0 * quad_half);
	float inner = ring(d, radius, width);
	float outer = ring(d, closing, width * 0.8);
	float inner_line = ring(d, radius, width + 2.0 * outline);
	float outer_line = ring(d, closing, width * 0.8 + 2.0 * outline);
	float fill = max(inner, outer);
	float line = max(inner_line, outer_line);
	if (line < 0.5) {
		discard;
	}
	ALBEDO = mix(to_linear(outline_color), to_linear(ring_color), fill);
}

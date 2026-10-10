// The volleyball net (VolleyballCourt): a square-meshed net of dark cord with a white tape along its top and a cord
// along its bottom, drawn on one quad (the holes are cut out: alpha scissor, so no sorting and no blending costs).
// Unshaded with the street's light (scenery_light, scenery_tint), like the court's sand; never emissive.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"

global uniform float scenery_light;
global uniform vec3 scenery_tint;

uniform vec3 cord_color : source_color = vec3(0.10, 0.11, 0.13);
uniform vec3 tape_color : source_color = vec3(0.94, 0.94, 0.92);
// The quad's size (metres): its width along x and its height along y, from its bottom edge.
uniform vec2 size = vec2(8.0, 0.7);
uniform float mesh_cell = 0.16;
uniform float cord_width = 0.026;
uniform float tape_height = 0.07;

void fragment() {
	// UV across the quad (x left to right, y top to bottom): metres from the quad's top-left corner.
	vec2 m = UV * size;
	float top = step(m.y, tape_height);
	float bottom = step(size.y - 0.025, m.y);
	vec2 cell = abs(fract(m / mesh_cell) - 0.5) * mesh_cell;
	float cord = step(mesh_cell * 0.5 - cord_width * 0.5, max(cell.x, cell.y));
	float solid = max(max(top, bottom), cord);
	if (solid < 0.5) {
		discard;
	}
	vec3 col = mix(to_linear(cord_color), to_linear(tape_color), top);
	ALBEDO = col * light_factor(scenery_light) * scenery_tint;
}

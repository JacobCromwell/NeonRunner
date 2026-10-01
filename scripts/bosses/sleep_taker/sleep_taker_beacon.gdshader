// A generator's beacon in the Sleep Taker's fight (SleepTakerLure): a soft column of the generator's
// pink rising from it, so it reads from far along the street and over the nightmare's heads, and in the
// dark of lights out. Turned toward the camera about its upright axis; unshaded, additive, no fog (it
// must show from afar). A slow breath in its glow, held still with Reduced flashing.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
#include "res://scripts/world/meshes/shaders/kit_flash.gdshaderinc"

uniform vec4 color : source_color = vec4(1.0, 0.3, 0.75, 1.0);
uniform float energy = 0.9;

void vertex() {
	// Face the camera about the column's upright axis (as a Y billboard).
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz));
	vec3 fwd = normalize(cross(right, vec3(0.0, 1.0, 0.0)));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(fwd, 0.0), MODEL_MATRIX[3]);
}

void fragment() {
	float h = 1.0 - UV.y;                       // 0 at the generator, 1 at the column's top
	float across = abs(UV.x - 0.5) * 2.0;       // 0 down its middle, 1 at its edges
	float column = pow(1.0 - h, 1.6) * (1.0 - smoothstep(0.1, 1.0, across));
	float core = pow(1.0 - h, 3.0) * (1.0 - smoothstep(0.0, 0.25, across));
	float breath = mix(0.85 + 0.15 * sin(TIME * 2.4), 1.0, reduced_flashing);
	ALBEDO = (color.rgb * column + vec3(1.0, 0.8, 0.95) * core * 0.5) * energy * breath;
}

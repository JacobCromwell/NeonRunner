// Mecha Guppy's floor bite warning's frame (MechaGuppyFloorBite, task E5e-f): a band round the crescent's outline on the
// roof's floor. Its mesh is built once with each inner vertex on the outline and its inward direction in UV (x and z; the
// outer vertices have none), so the frame deepens and beats by `width` alone, set each frame (task E5e-f's review: the
// mesh used to be rebuilt every physics frame). Unshaded and unfogged, in the enemy attacks' red (BossProps.WARNING_COLOR),
// the same on every renderer.
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.12, 0.08, 0.8);
uniform float width = 0.18;

void vertex() {
	VERTEX.x += UV.x * width;
	VERTEX.z += UV.y * width;
}

void fragment() {
	ALBEDO = color.rgb;
	ALPHA = color.a;
}

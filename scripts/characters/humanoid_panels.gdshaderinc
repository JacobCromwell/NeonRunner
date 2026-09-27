// Panels of a HumanoidRig (HumanoidPanel: a coat's skirt), all in one mesh on the pelvis joint. A
// vertex whose UV.y is k + 1 belongs to panel k and turns about panel_hinge[k] by the quaternion
// panel_rot[k]; UV.y = 0 (every ordinary part) leaves the vertex as it is, and so does an unset
// (zero) quaternion. HumanoidRig writes both arrays; keep the array size equal to
// HumanoidRig.MAX_PANELS. Include this in a spatial shader and call humanoid_panels_vertex() from
// vertex(); it works the same on Forward+, Mobile and Compatibility.

uniform vec4 panel_rot[8];
uniform vec4 panel_hinge[8];

vec3 humanoid_panel_turn(vec4 q, vec3 v) {
	return v + 2.0 * cross(q.xyz, cross(q.xyz, v) + q.w * v);
}

void humanoid_panels_vertex(vec2 uv, inout vec3 vertex, inout vec3 normal) {
	int k = int(uv.y + 0.5) - 1;
	if (k >= 0 && k < 8) {
		vec4 q = panel_rot[k];
		vec3 hinge = panel_hinge[k].xyz;
		vertex = hinge + humanoid_panel_turn(q, vertex - hinge);
		normal = humanoid_panel_turn(q, normal);
	}
}

// The sea far below Mecha Guppy and Captain Cogs' climb (MechaGuppyWaterfall's sea plane; GDD §10): a plane at sea level
// around the camera, under everything the arena draws, so however high the runner climbs there's sea below them out to
// the camera's far plane, fading into the run's fog like the rest (the sky's colour below the horizon is set to that
// fog colour, so the far sea meets it seamlessly). Gentle swells in world space; nothing glows or flickers.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec3 sea_color : source_color = vec3(0.1, 0.4, 0.48);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float swell = sin(world_pos.x * 0.07 + world_pos.z * 0.05 + TIME * 0.4) * 0.5 + 0.5;
	float swell2 = sin(world_pos.x * -0.031 + world_pos.z * 0.083 - TIME * 0.27) * 0.5 + 0.5;
	ALBEDO = sea_color * (0.88 + 0.1 * swell + 0.06 * swell2);
}

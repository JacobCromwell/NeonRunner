// The grey-box skin's plain scenery (floor, walls, ceilings; GreyboxMaterials.scenery): lit like
// GreyboxMaterials.flat()'s rough StandardMaterial3D, and dimmed by a level's darker lighting (the
// global `scenery_light`, ZoneSkin.apply_darkness). Plain spatial shading: works on Forward+, Mobile
// and Compatibility.
shader_type spatial;

global uniform float scenery_light;
uniform vec4 albedo : source_color = vec4(1.0);

void fragment() {
	// scenery_light is a factor for linear space; the Compatibility renderer works in sRGB space
	// (kit_common.gdshaderinc, light_factor).
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	float light = pow(max(scenery_light, 0.0), 1.0 / 2.2);
#else
	float light = scenery_light;
#endif
	ALBEDO = albedo.rgb * light;
	ROUGHNESS = 0.8;
}

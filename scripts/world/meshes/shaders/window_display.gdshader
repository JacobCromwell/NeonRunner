// The shop windows' ad screens and posters (task L10; MarketFacades, WindowDisplay): one small unshaded material for the
// Marketplace and the Casino, one mesh surface a chunk that has displays. The pictures are window_display.gdshaderinc's.
//   UV     0-1 up the panel (y); x in the same units (it ends at the panel's aspect ratio)
//   UV2    x = the kind (0 an ad screen, 1-4 a poster), y = WindowDisplay.param() (a seed and the aspect)
//   COLOR  rgb = a poster's paint, a = glow: 0 a lit poster, above 0 an ad screen's brightness (times glow_scale)
// A screen takes the material's glow_scale (the skin's emissive_scale) like the solid kit's emissive surfaces do, so its
// brightest parts reach the same bloom; a poster is lit like the solid kit's upright faces (an unshaded fake light), dimmed
// with the level's darkness (scenery_light, scenery_tint) the way the scenery is.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"
#include "res://scripts/world/meshes/shaders/kit_flash.gdshaderinc"
#include "res://scripts/world/meshes/shaders/kit_market_signs.gdshaderinc"
#include "res://scripts/world/meshes/shaders/window_display.gdshaderinc"

// A level's darker lighting (ZoneSkin.apply_darkness) and the street's light under a level's own sky: the lit poster
// dims by them, a glowing screen doesn't.
global uniform float scenery_light;
global uniform vec3 scenery_tint;
uniform float glow_scale = 4.0;
// The fake light on an upright face of the solid kit (kit_solid.gdshader's shade, for a face turned to the lanes).
const float POSTER_SHADE = 0.72;

void fragment() {
	float glow = COLOR.a;
	vec3 picture = window_surface(int(UV2.x + 0.5), UV2.y, COLOR.rgb, UV, fwidth(UV), TIME, glow);
	if (glow > 0.002) {
		ALBEDO = to_linear(picture) * (glow * glow_scale);
	} else {
		ALBEDO = to_linear(picture) * POSTER_SHADE * light_factor(scenery_light) * scenery_tint;
	}
}

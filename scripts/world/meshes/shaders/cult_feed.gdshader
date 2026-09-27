// A screen playing the cult's feed (CultFeed, cult_feed.gdshaderinc): one material for every
// screen of a skin, so the feed costs one mesh surface per chunk. The dim screen shows at its own
// brightness on both renderers; only the picture's bright parts glow (feed_brightness).
//   UV     0-1 across the screen (y up)
//   UV2    x = a seed for the static, y = the screen's aspect (width / height)
//   COLOR  rgb = tint (white), a = brightness (0-1)
shader_type spatial;
render_mode unshaded, cull_back;

#include "res://scripts/world/meshes/shaders/kit_common.gdshaderinc"
#include "res://scripts/world/meshes/shaders/kit_flash.gdshaderinc"
#include "res://scripts/world/meshes/shaders/cult_feed.gdshaderinc"

// How far above the bloom threshold the picture's brightest parts glow.
uniform float feed_brightness = 2.2;

void fragment() {
	vec2 fw = fwidth(UV);
	vec4 feed = cult_feed(UV, max(UV2.y, 0.1), TIME, UV2.x, fw);
	ALBEDO = to_linear(feed.rgb) * COLOR.rgb * (COLOR.a * mix(1.0, feed_brightness, feed.a));
}

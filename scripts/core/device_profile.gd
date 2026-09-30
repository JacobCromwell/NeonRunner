class_name DeviceProfile
extends RefCounted
## What kind of device the game is running on. Build flavors (CLAUDE.md principle 6) will add
## their own feature tags; until then the engine's platform tags decide.


static func is_mobile() -> bool:
	for tag: String in ["full_mobile", "mobile", "web_android", "web_ios"]:
		if OS.has_feature(tag):
			return true
	return false


## True when the player plays by touching the screen: a phone or tablet, or a real touch screen. The
## project lets the mouse stand in for touch (input_devices/pointing/emulate_touch_from_mouse, so
## swipes can be tried with a mouse), and with that on every desktop, and every desktop browser,
## reports a touch screen; that doesn't count.
static func has_touch() -> bool:
	return is_mobile() or (DisplayServer.is_touchscreen_available() and not Input.is_emulating_touch_from_mouse())

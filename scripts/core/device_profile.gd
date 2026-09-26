class_name DeviceProfile
extends RefCounted
## What kind of device the game is running on. Build flavors (CLAUDE.md principle 6) will add
## their own feature tags; until then the engine's platform tags decide.


static func is_mobile() -> bool:
	for tag: String in ["full_mobile", "mobile", "web_android", "web_ios"]:
		if OS.has_feature(tag):
			return true
	return false

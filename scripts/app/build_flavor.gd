class_name BuildFlavor
extends RefCounted
## Which product this build is (CLAUDE.md principle 6), from export-preset feature tags:
## - full_pc: Steam. Paid up front; no ads or purchases (GDD §2).
## - full_mobile: App Store / Google Play. Free with rewarded ads and optional purchases.
## - web_demo: itch.io and portals. Zone 1 and its boss, then a "get the full game" screen with
##   store links; no ads, purchases or leaderboards.
## Without a flavor tag (the editor, tests) the platform decides: web → web_demo, mobile →
## full_mobile, otherwise full_pc. `--flavor=web_demo` on the command line overrides it for testing.

enum Kind { FULL_PC, FULL_MOBILE, WEB_DEMO }

static var _override: int = -1


static func current() -> Kind:
	if _override >= 0:
		return _override as Kind
	if OS.has_feature("web_demo"):
		return Kind.WEB_DEMO
	if OS.has_feature("full_mobile"):
		return Kind.FULL_MOBILE
	if OS.has_feature("full_pc"):
		return Kind.FULL_PC
	if OS.has_feature("web"):
		return Kind.WEB_DEMO
	if OS.has_feature("mobile"):
		return Kind.FULL_MOBILE
	return Kind.FULL_PC


## For tests and --flavor=: -1 goes back to detection.
static func set_override(kind: int) -> void:
	_override = kind


static func from_name(flavor_name: String) -> int:
	match flavor_name:
		"full_pc":
			return Kind.FULL_PC
		"full_mobile":
			return Kind.FULL_MOBILE
		"web_demo":
			return Kind.WEB_DEMO
	return -1


static func name_of(kind: Kind) -> String:
	return ["full_pc", "full_mobile", "web_demo"][kind]


static func is_demo() -> bool:
	return current() == Kind.WEB_DEMO


static func has_ads() -> bool:
	return current() == Kind.FULL_MOBILE


static func has_purchases() -> bool:
	return current() == Kind.FULL_MOBILE


static func has_leaderboards() -> bool:
	return current() != Kind.WEB_DEMO

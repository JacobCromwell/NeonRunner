class_name UiScale
extends RefCounted
## How big a phone's menus are drawn (the shop on a phone's browser, task I3).
##
## The project stretches a 1280×720 picture to the window (`canvas_items`, `expand`), so a screen's
## sizes are fractions of the window's height: the same on a 27-inch monitor and on a phone. A phone is
## small and held close, so the same fractions come out too small to read: a phone's browser in
## landscape shows the page about 340 to 390 pixels high (with the browser's bars), and the 720-pixel
## layout was drawn at about half its size there, the shop's 19-pixel captions at 9 (about 1.5 mm).
##
## So while a screen (anything extending `ScreenBase`) is open on a touch device in a web page (the web
## demo on a phone), the root window's `content_scale_factor` magnifies the whole canvas until one UI
## pixel is at least `phone_min_scale` of the page's own (CSS) pixels. The layout is the same code at a
## smaller logical size: the title bar, the cards' flow and the scroll areas settle to the room they get,
## and the controls keep a finger's size. Only menus: a run keeps the project's stretch (the HUD, and the
## swipes in logical pixels), so the factor goes back to 1 when the last screen closes. Nothing happens on
## a desktop, or on a tablet or any window big enough to reach the minimum already.
##
## A page may also show the game smaller than its own pixels say: itch.io embeds an HTML5 game in an
## iframe of a fixed size (960×540 CSS pixels, say), and on a phone the host page shrinks the whole embed to
## the screen's width. The game reads a 960-pixel window and the phone's pixel ratio, and none of that says how
## small the picture is on the glass. `embed_scale_for()` estimates it from the window and the phone's screen
## (what fraction of the screen's long side the page's width is) and `factor_for()` counts it in, so the
## menus are sized for what the player sees. The page itself offers the way out of a frame that doesn't fit
## (the web preset's `html/head_include`: a "Play it full screen" cover, docs/architecture/economy-platforms.md).
##
## Web only for now: the native mobile builds (full_mobile: the endless button, credit packs, the ad
## revive) haven't been looked at with it, and `screen_get_scale()` on Android isn't known to give the
## page-style ratio this needs. Lift the check in `factor_now()` when they have.
##
## `factor_for()` is the maths (the same on every device); `screen_entered()` and `screen_exited()` are
## called by `ScreenBase`.

## What the page's pixel ratio is taken to be where the display server can't say (the tests: a headless
## run has no real window): 0 = ask the display server, which on the web gives `devicePixelRatio`.
static var pixel_ratio_override: float = 0.0
## The tests set it to run as in a web page (the run itself isn't one).
static var assume_web: bool = false
## The phone's screen in device pixels where the display server can't say (the tests): zero = ask the
## display server in a web page, and know nothing (so no embed scaling) anywhere else.
static var screen_size_override: Vector2 = Vector2.ZERO

static var _open: Dictionary = {}
static var _connected: Window
static var _settle_queued: bool = false


## The factor that brings a window of `window` pixels, with `pixel_ratio` of them to a CSS pixel, to at
## least `min_scale` CSS pixels per UI pixel, never beyond `max_factor` and never below 1, and never so
## far that the menus get narrower than `min_width` UI pixels (a phone held upright would otherwise get
## menus too wide for it: they stay small and whole instead). `base` is the project's base size
## (display/window/size/viewport_*). The project's stretch is `expand`: its scale is the smaller of the
## window's two ratios to the base, and a content scale factor `f` multiplies it. `embed_scale` (from
## `embed_scale_for()`) is how much smaller than a CSS pixel's natural size the page is shown (1 = as it is).
static func factor_for(window: Vector2, pixel_ratio: float, base: Vector2, min_scale: float,
		max_factor: float, min_width: float = 0.0, embed_scale: float = 1.0) -> float:
	if window.x <= 0.0 or window.y <= 0.0 or base.x <= 0.0 or base.y <= 0.0:
		return 1.0
	var stretch: float = minf(window.x / base.x, window.y / base.y)
	var css_per_ui: float = stretch / maxf(pixel_ratio, 1.0) * clampf(embed_scale, 0.05, 1.0)
	if css_per_ui <= 0.0:
		return 1.0
	var factor: float = minf(min_scale / css_per_ui, maxf(max_factor, 1.0))
	if min_width > 0.0:
		# The menus' width in UI pixels is window.x / (stretch * f).
		factor = minf(factor, window.x / (stretch * min_width))
	return maxf(factor, 1.0)


## How big the page's pixels really are on the phone's glass, as a fraction of their natural size (1 = as
## the browser draws them, below 1 = the page is wider than the screen can show at that size, so a host
## page has shrunk it). `window` and `screen` are in the same units (device pixels). Only a phone held
## sideways plays the game (the page covers it otherwise, GDD §2), so the page's width gets the screen's
## long side, or the short one for a page that is itself taller than wide. Never below `min_scale`, so a
## screen the browser misreports can't magnify the menus without end; 1 where the screen isn't known.
static func embed_scale_for(window: Vector2, screen: Vector2, min_scale: float = 0.4) -> float:
	if window.x <= 0.0 or window.y <= 0.0 or screen.x <= 0.0 or screen.y <= 0.0:
		return 1.0
	var seen: float = maxf(screen.x, screen.y) if window.x >= window.y else minf(screen.x, screen.y)
	return clampf(seen / window.x, minf(min_scale, 1.0), 1.0)


## The phone's screen in device pixels (on the web: `screen.width` and `screen.height` times the pixel
## ratio, as iOS gives them, held upright whichever way the phone is held), or zero when it isn't known.
static func screen_size() -> Vector2:
	if screen_size_override != Vector2.ZERO:
		return screen_size_override
	if not OS.has_feature("web"):
		return Vector2.ZERO
	return Vector2(DisplayServer.screen_get_size())


## The factor for `window` on this device now: 1 unless it's a touch device (UiTheme.is_touch()) in a
## web page.
static func factor_now(window: Window) -> float:
	if not UiTheme.is_touch() or window == null or not (assume_web or OS.has_feature("web")):
		return 1.0
	var s: UiStyle = UiTheme.style()
	return factor_for(Vector2(window.size), pixel_ratio(), base_size(), s.phone_min_scale, s.phone_max_factor,
		float(s.phone_min_width), embed_scale(window))


## `embed_scale_for()` for `window` on this device now.
static func embed_scale(window: Window) -> float:
	return embed_scale_for(Vector2(window.size), screen_size(), UiTheme.style().phone_min_embed_scale)


## Device pixels to a page (CSS) pixel: the web's devicePixelRatio.
static func pixel_ratio() -> float:
	if pixel_ratio_override > 0.0:
		return pixel_ratio_override
	return maxf(DisplayServer.screen_get_scale(), 1.0)


## True on a touch screen whose menus are `phone_short_height` UI pixels high or less (`view` is the
## viewport's size in UI pixels, `get_viewport_rect().size`): a phone held sideways. Screens use it to
## pick their compact layout.
static func is_short(view: Vector2) -> bool:
	return UiTheme.is_touch() and view.y < float(UiTheme.style().phone_short_height)


## The project's base size, as the stretch settings give it.
static func base_size() -> Vector2:
	return Vector2(float(ProjectSettings.get_setting(&"display/window/size/viewport_width", 1280)),
		float(ProjectSettings.get_setting(&"display/window/size/viewport_height", 720)))


## A screen entered the tree: magnify now, so its first layout is already at the size it keeps.
static func screen_entered(screen: Control) -> void:
	_open[screen.get_instance_id()] = true
	var window: Window = screen.get_tree().root if screen.is_inside_tree() else null
	if window == null:
		return
	if _connected != window:
		if is_instance_valid(_connected) and _connected.size_changed.is_connected(_on_size_changed):
			_connected.size_changed.disconnect(_on_size_changed)
		window.size_changed.connect(_on_size_changed)
		_connected = window
	_apply(window)


## A screen left the tree. The factor goes back to 1 only if no other screen follows in this frame
## (the next screen is usually added right after the old one is freed).
static func screen_exited(screen: Control) -> void:
	_open.erase(screen.get_instance_id())
	if _open.is_empty() and not _settle_queued and is_instance_valid(_connected):
		_settle_queued = true
		_settle.call_deferred()


static func is_open() -> bool:
	return not _open.is_empty()


static func _settle() -> void:
	_settle_queued = false
	if is_instance_valid(_connected):
		_apply(_connected)


static func _on_size_changed() -> void:
	if is_instance_valid(_connected):
		_apply(_connected)


## Sets the window's content scale factor for what is open now (the factor from the window's own size,
## never from the factor itself, so applying it twice changes nothing).
static func _apply(window: Window) -> void:
	var target: float = factor_now(window) if not _open.is_empty() else 1.0
	if not is_equal_approx(window.content_scale_factor, target):
		window.content_scale_factor = target
		# In a browser's console (debug exports only), tools/web/browser_check.js reads it.
		if target > 1.0 and OS.has_feature("web") and OS.is_debug_build():
			var stretch: float = minf(window.size.x / base_size().x, window.size.y / base_size().y)
			var shown: float = embed_scale(window)
			print("[ui] menus magnified x%.3f (window %dx%d, pixel ratio %.2f, page shown at %.3f, %.3f CSS px per UI px)" % [
				target, window.size.x, window.size.y, pixel_ratio(), shown, stretch * target / pixel_ratio() * shown])

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
## So while a screen (anything extending `ScreenBase`) is open on a touch device, the root window's
## `content_scale_factor` magnifies the whole canvas until one UI pixel is at least `phone_min_scale` of
## the page's own (CSS) pixels. The layout is the same code at a smaller logical size: the title bar,
## the cards' flow and the scroll areas settle to the room they get, and the controls keep a finger's
## size. Only menus: a run keeps the project's stretch (the HUD, and the swipes in logical pixels), so
## the factor goes back to 1 when the last screen closes. Nothing happens on a desktop, or on a tablet
## or any window big enough to reach the minimum already.
##
## `factor_for()` is the maths (the same on every device); `screen_entered()` and `screen_exited()` are
## called by `ScreenBase`.

## What the page's pixel ratio is taken to be where the display server can't say (the tests: a headless
## run has no real window): 0 = ask the display server. On the web it's `devicePixelRatio`, on Android
## the screen's density.
static var pixel_ratio_override: float = 0.0

static var _open: Dictionary = {}
static var _connected: Window
static var _settle_queued: bool = false


## The factor that brings a window of `window` pixels, with `pixel_ratio` of them to a CSS pixel, to at
## least `min_scale` CSS pixels per UI pixel, never beyond `max_factor` and never below 1, and never so
## far that the menus get narrower than `min_width` UI pixels (a phone held upright would otherwise get
## menus too wide for it: they stay small and whole instead). `base` is the project's base size
## (display/window/size/viewport_*). The project's stretch is `expand`: its scale is the smaller of the
## window's two ratios to the base, and a content scale factor `f` multiplies it.
static func factor_for(window: Vector2, pixel_ratio: float, base: Vector2, min_scale: float,
		max_factor: float, min_width: float = 0.0) -> float:
	if window.x <= 0.0 or window.y <= 0.0 or base.x <= 0.0 or base.y <= 0.0:
		return 1.0
	var stretch: float = minf(window.x / base.x, window.y / base.y)
	var css_per_ui: float = stretch / maxf(pixel_ratio, 1.0)
	if css_per_ui <= 0.0:
		return 1.0
	var factor: float = minf(min_scale / css_per_ui, maxf(max_factor, 1.0))
	if min_width > 0.0:
		# The menus' width in UI pixels is window.x / (stretch * f).
		factor = minf(factor, window.x / (stretch * min_width))
	return maxf(factor, 1.0)


## The factor for `window` on this device now: 1 unless it's a touch device (UiTheme.is_touch()).
static func factor_now(window: Window) -> float:
	if not UiTheme.is_touch() or window == null:
		return 1.0
	# A headless run (the tests, the smoke runs) has a 64×64 stand-in for a window, which the stretch
	# turns into 1280×1280 UI pixels: nothing to magnify, unless a test gives the window a size and a
	# pixel ratio of its own.
	if DisplayServer.get_name() == "headless" and pixel_ratio_override <= 0.0:
		return 1.0
	var s: UiStyle = UiTheme.style()
	return factor_for(Vector2(window.size), pixel_ratio(), base_size(), s.phone_min_scale, s.phone_max_factor,
		float(s.phone_min_width))


## Device pixels to a page (CSS) pixel: the web's devicePixelRatio, an Android screen's density.
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
			print("[ui] menus magnified x%.3f (window %dx%d, pixel ratio %.2f, %.3f CSS px per UI px)" % [
				target, window.size.x, window.size.y, pixel_ratio(), stretch * target / pixel_ratio()])

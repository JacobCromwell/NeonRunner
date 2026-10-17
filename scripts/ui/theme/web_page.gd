class_name WebPage
extends RefCounted
## What the web page around the game says (the web demo's `html/head_include` in `export_presets.cfg`, which
## defines `window.neonPage`). Only the page can know a phone's safe areas in a browser: the display server's
## own answers are not about the page.
##
## Why not the display server's: on the web `get_display_safe_area()` is the *window* and `screen_get_size()`
## is the *physical screen* times the pixel ratio, and iOS reports `screen.width` and `screen.height` as for
## a phone held upright even when it's held sideways (an iPhone 14: 390×844). `UiTheme.safe_area_margins()`
## took the difference between them for a notch and put 40% of the screen's height of margin at its bottom,
## so every menu and the HUD were squeezed into the top of the phone (task L1). A browser's bars take the same
## difference on an Android phone. The page's `env(safe-area-inset-*)` is what the browser itself keeps clear.

## Tests set the page's insets (left, top, right, bottom, in CSS pixels); null = ask the page.
static var insets_override: Variant = null

## Kept alive here: a callback the page holds is freed with the last reference to it on this side.
static var _cover_callback: JavaScriptObject = null
static var _cached_frame: int = -1
static var _cached: Vector4 = Vector4.ZERO
static var _logged: Vector4 = Vector4.ZERO


## True in a web page (or when a test says so).
static func is_web() -> bool:
	return UiScale.assume_web or OS.has_feature("web")


## The page's safe-area insets in CSS pixels (left, top, right, bottom): what `env(safe-area-inset-*)` says
## in the game's own frame. Zero without a page, in a browser that has none, and in a frame the browser
## doesn't inset (a page that doesn't draw under the notch: Safari's default).
static func safe_insets_css() -> Vector4:
	if insets_override is Vector4:
		return insets_override as Vector4
	if not OS.has_feature("web"):
		return Vector4.ZERO
	# Once a frame at most (a screen asks on every layout, and the first layout after a turn must not read the
	# insets from before it).
	var frame: int = Engine.get_process_frames()
	if frame == _cached_frame:
		return _cached
	_cached_frame = frame
	var said: Variant = JavaScriptBridge.eval("window.neonPage ? window.neonPage.insets() : ''", true)
	_cached = parse_insets(String(said) if said is String else "")
	return _cached


## "left,top,right,bottom" (CSS pixels) to a Vector4; anything else is zero. A negative value, and one of
## 200 or more (no notch is that deep), counts as zero.
static func parse_insets(text: String) -> Vector4:
	var parts: PackedFloat64Array = text.split_floats(",")
	if parts.size() != 4:
		return Vector4.ZERO
	var out := Vector4.ZERO
	for i: int in 4:
		var v: float = parts[i]
		out[i] = v if v > 0.0 and v < 200.0 else 0.0
	return out


## The insets in UI pixels for `control`'s screen (the page's CSS pixels are `UiScale.pixel_ratio()` device
## pixels, and a UI pixel is however many device pixels the stretch and the menus' magnifying make it).
static func safe_margins(control: Control) -> Vector4:
	var css: Vector4 = safe_insets_css()
	if css == Vector4.ZERO or control == null or not control.is_inside_tree():
		return Vector4.ZERO
	var css_width: float = float(control.get_window().size.x) / UiScale.pixel_ratio()
	if css_width <= 0.0:
		return Vector4.ZERO
	var out: Vector4 = css * (control.get_viewport_rect().size.x / css_width)
	# In a debug build's console, tools/web/browser_check.js reads it.
	if out != _logged and OS.has_feature("web") and OS.is_debug_build():
		print("[ui] page safe area (%.1f, %.1f, %.1f, %.1f) CSS px" % [css.x, css.y, css.z, css.w])
	_logged = out
	return out


## `handler` is called when the page puts a cover over the game (a phone held upright, or a frame that
## doesn't fit: the preset's page script calls `window.neonPage.onCover`), so a running level can pause
## unseen (App). Only in a web page that has the script.
static func watch_cover(handler: Callable) -> void:
	if not OS.has_feature("web"):
		return
	var page: JavaScriptObject = JavaScriptBridge.get_interface("neonPage")
	if page == null:
		return
	_cover_callback = JavaScriptBridge.create_callback(func(_args: Array) -> void: handler.call())
	page.set(&"onCover", _cover_callback)

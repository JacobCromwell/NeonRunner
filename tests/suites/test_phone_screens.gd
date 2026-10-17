extends TestSuite
## The menus on a phone's browser (task I3): every screen the web demo shows, laid out at the sizes a
## phone's page has (844×390, 844×340, 844×300, 667×375 and 640×290 held sideways, the short ones with
## the browser's bars; 390×844 and 360×800 held upright), on the real main scene with the window as big as
## the phone's in device pixels (2 or 3 to a CSS pixel). The headless run draws nothing, so the checks read
## the layout. UiScale magnifies the menus until the UI's pixels are at least `phone_min_scale` of the
## page's own, and what a screen then puts on show is
##   readable   no text under 11 CSS pixels, none cut off (a label's text in its box, a description's
##              lines all shown);
##   touchable  every button at least 40 CSS pixels each way;
##   whole      nothing outside the screen, nothing cut off the side (no sideways scrolling), the
##              screen's own way on (Continue, Next, Play, Resume) on show without scrolling;
##   reachable  what can't fit scrolls (the content's scroll area, the shop's, the level list's).
## The magnifying itself is checked at the end: it follows the window and the pixel ratio, ends when the
## last screen closes, and does nothing on a desktop, a tablet-sized window or a run.

## [CSS size, device pixels per CSS pixel, held sideways, the phone's screen in CSS pixels as the browser
## reports it (optional: for a page that is not the whole screen)]. The last three are itch.io's 960×540 embed
## shrunk to a phone's width by the host page (task L1): the game reads a 960-pixel window, and the screen
## says how much smaller than that it looks (an iPhone SE's 667 pixels long: two thirds).
const PHONES: Array = [
	[Vector2i(844, 390), 3.0, true], [Vector2i(844, 340), 3.0, true], [Vector2i(844, 300), 3.0, true],
	[Vector2i(667, 375), 2.0, true], [Vector2i(640, 290), 3.0, true],
	[Vector2i(390, 844), 3.0, false], [Vector2i(360, 800), 3.0, false],
	[Vector2i(960, 540), 3.0, true, Vector2i(375, 667)], [Vector2i(960, 540), 3.0, true, Vector2i(390, 844)],
	[Vector2i(844, 340), 3.0, true, Vector2i(390, 844)],
]
## CSS pixels: the smallest text, and the smallest a finger's target.
const MIN_TEXT_CSS: float = 11.0
const MIN_TOUCH_CSS: float = 40.0

var main: Node
var verbose: bool = false


func run() -> void:
	verbose = OS.get_cmdline_user_args().has("--verbose")
	_test_factor_maths()
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var saved: Profile = App.profile
	var saved_size: Vector2i = tree.root.size
	BuildFlavor.set_override(BuildFlavor.Kind.WEB_DEMO)
	Platform.configure_for(BuildFlavor.Kind.WEB_DEMO)
	UiTheme.touch_override = 1
	UiScale.assume_web = true
	App.mobile = true
	for phone: Array in PHONES:
		var css: Vector2i = phone[0]
		var ratio: float = phone[1]
		var screen_css: Vector2i = phone[3] if phone.size() > 3 else Vector2i.ZERO
		UiScale.pixel_ratio_override = ratio
		UiScale.screen_size_override = Vector2(screen_css) * ratio
		tree.root.size = Vector2i(roundi(css.x * ratio), roundi(css.y * ratio))
		# What a CSS pixel of the page is on the glass: the checks count a UI pixel in the page's own pixels,
		# and the page may be shown smaller than they are, so the pixel ratio they use is the ratio over that.
		var shown: float = UiScale.embed_scale_for(Vector2(tree.root.size), UiScale.screen_size_override)
		for rich: bool in [true, false]:
			App.profile = SampleProfiles.rich() if rich else SampleProfiles.fresh()
			var tag: String = "%dx%d %s%s" % [css.x, css.y, "rich" if rich else "fresh",
				" on a %dx%d screen" % [screen_css.x, screen_css.y] if screen_css != Vector2i.ZERO else ""]
			await _every_screen(tag, ratio / shown, bool(phone[2]))
	UiScale.screen_size_override = Vector2.ZERO
	await _test_lifecycle()
	await _test_embed_scale()
	await _test_page_safe_area()
	await _test_taps_and_drags(true)
	UiScale.assume_web = false
	UiScale.pixel_ratio_override = 0.0
	await _test_taps_and_drags(false)
	tree.root.size = saved_size
	App.show_title()
	await _frames(3)
	BuildFlavor.set_override(-1)
	Platform.configure_for(BuildFlavor.current())
	UiTheme.touch_override = -1
	App.mobile = DeviceProfile.is_mobile()
	App.profile = saved
	main.queue_free()
	App.main = null
	await tree.process_frame


func _frames(count: int) -> void:
	for i: int in count:
		await tree.process_frame


# --- Every screen at one size ----------------------------------------------------------------

func _every_screen(tag: String, ratio: float, sideways: bool) -> void:
	var screens: Array = [
		["title", func() -> void: App.show_title(), &"continue"],
		["level select", func() -> void: App.show_level_select(), &""],
		["shop", func() -> void: App.show_shop(), &""],
		["shop between levels", func() -> void: App.show_shop(App.show_title, "Next"), &"play"],
		["settings", func() -> void: App.show_settings(), &""],
		["level intro", func() -> void: App.start_level(App.campaign.step("city/1")), &""],
		["results", func() -> void: _result(SampleProfiles.result(true)), &"continue"],
		["run summary", func() -> void: _result(SampleProfiles.result(false)), &"continue"],
		["boss results", func() -> void: _result(SampleProfiles.boss_result(true)), &"continue"],
		["demo end", func() -> void: App.show_demo_end(), &""],
	]
	for entry: Array in screens:
		(entry[1] as Callable).call()
		await _frames(4)
		_check_screen("%s, %s" % [entry[0], tag], App.screen, ratio, sideways, entry[2])
	# The overlays over a running level.
	App.start_level(App.campaign.step("city/1"))
	App.begin_run()
	await physics_frames(10)
	App.pause_game()
	await _frames(4)
	_check_screen("pause, %s" % tag, App.overlay, ratio, sideways, &"resume")
	var pause := App.overlay as PauseScreen
	if pause != null:
		pause.buttons["settings"].pressed.emit()
		await _frames(4)
		_check_screen("settings over the pause, %s" % tag, App.overlay, ratio, sideways, &"")
		(App.overlay as ScreenBase).go_back()
		await _frames(4)
		pause = App.overlay as PauseScreen
		if pause != null:
			pause.buttons["quit"].pressed.emit()
			await _frames(4)
			var asked: bool = false
			for c: Node in pause.get_children():
				asked = asked or c is ConfirmDialog
			check(asked, "quitting from the pause asks first, on the phone too (%s)" % tag)
			_check_screen("quit dialog over the pause, %s" % tag, pause, ratio, sideways, &"")
	App.resume_game()
	await physics_frames(2)
	var revive: bool = App.revive_options()["item"]
	App.run.world.player.call(&"_die", "Cyborg")
	await physics_frames(int((App.rules.death_screen_delay + 0.3) * 60.0))
	if revive and App.overlay is DeathScreen:
		_check_screen("revive offer, %s" % tag, App.overlay, ratio, sideways, &"item")
		App.decline_revive()
		await _frames(3)
	App.show_title()
	await _frames(3)


func _result(r: RunResult) -> void:
	var s := ResultsScreen.new()
	s.result = r
	App.show_screen(s)


# --- One screen -----------------------------------------------------------------------------

func _check_screen(what: String, screen: Control, ratio: float, sideways: bool, way_on: StringName) -> void:
	check(screen != null and screen.is_inside_tree(), "%s is on show" % what)
	if screen == null or not screen.is_inside_tree():
		return
	var window: Vector2 = Vector2(tree.root.size)
	var view: Vector2 = screen.get_viewport_rect().size
	# CSS pixels on the page for one UI pixel.
	var css_per_ui: float = window.x / view.x / ratio
	var style: UiStyle = UiTheme.style()
	if not sideways:
		# Held upright, the page covers the game ("turn your phone sideways", GDD §2: the layouts are for
		# landscape): the menus stay whole and small rather than big and cut, and are still reachable.
		check(view.x >= float(style.phone_min_width) - 1.0 or tree.root.content_scale_factor <= 1.001,
			"%s: held upright the menus are at least %d UI pixels wide (%.0f)" % [what, style.phone_min_width, view.x])
		return
	var capped: bool = is_equal_approx(tree.root.content_scale_factor, style.phone_max_factor)
	check(css_per_ui >= style.phone_min_scale - 0.005 or capped,
		"%s: a UI pixel is %.3f CSS pixels (at least %.2f)" % [what, css_per_ui, style.phone_min_scale])
	var problems: PackedStringArray = problems_in(screen, css_per_ui)
	if way_on != &"":
		var button: Control = (screen.get("buttons") as Dictionary).get(String(way_on)) if screen.get("buttons") != null else null
		if button == null and way_on == &"play":
			button = screen.get("play_button")
		if button == null:
			problems.append("the way on (%s) is missing" % way_on)
		else:
			var gone: String = _off_screen(button, screen, view, true)
			if gone != "":
				problems.append("the way on (%s) %s" % [way_on, gone])
	check(problems.is_empty(), "%s: %s" % [what, "; ".join(problems.slice(0, 6))])
	if verbose and not problems.is_empty():
		print("  %s (%dx%d UI px, %.2f CSS px each):\n    %s" % [what, view.x, view.y, css_per_ui, "\n    ".join(problems.slice(0, 14))])


## What is wrong with a screen's layout, as short sentences (empty: nothing). `css_per_ui` turns UI
## pixels to the page's.
static func problems_in(screen: Control, css_per_ui: float) -> PackedStringArray:
	var out := PackedStringArray()
	var view: Vector2 = screen.get_viewport_rect().size
	for node: Node in screen.find_children("*", "Control", true, false):
		var c := node as Control
		if not c.is_visible_in_tree() or c.size.x < 1.0 or c.size.y < 1.0 or c is ScrollContainer or c is ScrollBar:
			continue
		var name: String = _describe(c)
		# A touch that starts on a panel or a button must reach the scroll area around it (a drag scrolls).
		if (c is PanelContainer or c is BaseButton) and c.mouse_filter == Control.MOUSE_FILTER_STOP and _in_scroll(c, screen):
			out.append("%s takes a finger's drag (mouse filter STOP), so a drag that starts on it can't scroll" % name)
		if c is BaseButton:
			var px: Vector2 = c.size * css_per_ui
			if px.y < MIN_TOUCH_CSS - 0.5 or px.x < MIN_TOUCH_CSS - 0.5:
				out.append("%s is %.0f×%.0f CSS px (a finger needs %.0f)" % [name, px.x, px.y, MIN_TOUCH_CSS])
		if c is Label:
			var label := c as Label
			if label.text == "":
				continue
			var font: Font = label.get_theme_font(&"font")
			var size: int = label.get_theme_font_size(&"font_size")
			if float(size) * css_per_ui < MIN_TEXT_CSS - 0.3:
				out.append("%s is %.1f CSS px high text" % [name, float(size) * css_per_ui])
			if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
				var width: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
				if width > label.size.x + 1.5:
					out.append("%s's text is cut (%.0f of %.0f)" % [name, width, label.size.x])
			elif label.max_lines_visible > 0 and label.get_line_count() > label.max_lines_visible:
				out.append("%s's text needs %d lines, shows %d" % [name, label.get_line_count(), label.max_lines_visible])
		var gone: String = _off_screen(c, screen, view, false)
		if gone != "":
			out.append("%s %s" % [name, gone])
	# Nothing scrolls sideways, and the screen's own scroll area scrolls up and down only where it must.
	for node: Node in screen.find_children("*", "ScrollContainer", true, false):
		var s := node as ScrollContainer
		if not s.is_visible_in_tree():
			continue
		var content: Control = s.get_child(0) as Control if s.get_child_count() > 0 else null
		if content != null and content.get_combined_minimum_size().x > s.size.x + 1.0 and s.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			out.append("%s scrolls sideways (%.0f of %.0f)" % [_describe(s), content.get_combined_minimum_size().x, s.size.x])
	return out


## "" if `c` is where a finger can reach it: inside the viewport, and inside the scroll area it's in
## unless `must_show` (then the scroll area must not hide it either), else why not.
static func _off_screen(c: Control, screen: Control, view: Vector2, must_show: bool) -> String:
	var rect: Rect2 = c.get_global_rect()
	var scroller: ScrollContainer = null
	var node: Node = c.get_parent()
	while node != null and node != screen:
		if node is ScrollContainer:
			scroller = node as ScrollContainer
			break
		node = node.get_parent()
	if scroller == null:
		var room := Rect2(Vector2.ZERO, view).grow(1.5)
		if not room.encloses(rect) and not (c is ScreenBase.BackdropView):
			return "is outside the screen (%s of %s)" % [rect, view]
		return ""
	var area: Rect2 = scroller.get_global_rect().grow(1.5)
	if rect.position.x < area.position.x or rect.end.x > area.end.x:
		return "is cut off the side of its scroll area (%s in %s)" % [rect, scroller.get_global_rect()]
	if must_show and (rect.position.y < area.position.y or rect.end.y > area.end.y):
		return "is scrolled out of sight (%s in %s)" % [rect, scroller.get_global_rect()]
	return ""


## True if `c` has a scroll area between it and the screen.
static func _in_scroll(c: Control, screen: Control) -> bool:
	var node: Node = c.get_parent()
	while node != null and node != screen:
		if node is ScrollContainer:
			return true
		node = node.get_parent()
	return false


static func _describe(c: Control) -> String:
	var text: String = ""
	if c is Label:
		text = " \"%s\"" % (c as Label).text.left(24)
	elif c is Button:
		text = " \"%s\"" % (c as Button).text.left(24)
	return "%s%s" % [c.get_script().get_global_name() if c.get_script() != null and c.get_script().get_global_name() != &"" else c.get_class(), text]


# --- The magnifying itself -----------------------------------------------------------------------

func _test_factor_maths() -> void:
	var style: UiStyle = UiTheme.style()
	var base := Vector2(1280, 720)
	var f: Callable = func(css: Vector2, ratio: float) -> float:
		return UiScale.factor_for(css * ratio, ratio, base, style.phone_min_scale, style.phone_max_factor,
			float(style.phone_min_width))
	# A phone held sideways: the stretch gives min(w / 1280, h / 720) device pixels per UI pixel.
	var iphone: float = f.call(Vector2(844, 340), 3.0)
	check(is_equal_approx(iphone, style.phone_min_scale / (340.0 / 720.0)),
		"a phone's page 844×340 is magnified to %.2f CSS pixels per UI pixel (factor %.3f)" % [style.phone_min_scale, iphone])
	check(f.call(Vector2(844, 390), 3.0) < iphone and f.call(Vector2(844, 300), 3.0) > iphone,
		"a shorter page is magnified more")
	check(is_equal_approx(f.call(Vector2(844, 340), 2.0), f.call(Vector2(844, 340), 3.0)),
		"the pixel ratio cancels out: the same page in 2 or 3 device pixels per CSS pixel is magnified the same")
	check(is_equal_approx(f.call(Vector2(1920, 1080), 1.0), 1.0), "a desktop window is not magnified")
	check(is_equal_approx(f.call(Vector2(1180, 820), 2.0), 1.0), "a tablet's page (1180×820) is not magnified")
	check(is_equal_approx(f.call(Vector2(1280, 720), 1.0), 1.0), "the base size is not magnified")
	check(f.call(Vector2(100, 40), 1.0) <= style.phone_max_factor + 0.001, "a tiny window is magnified no more than phone_max_factor")
	# Held upright the magnifying stops where the menus would be narrower than phone_min_width UI pixels.
	var upright: float = f.call(Vector2(390, 844), 3.0)
	var stretch: float = minf(390.0 * 3.0 / 1280.0, 844.0 * 3.0 / 720.0)
	check(upright > 1.0 and absf(390.0 * 3.0 / (stretch * upright) - float(style.phone_min_width)) < 0.5,
		"held upright the menus are %d UI pixels wide, not narrower (factor %.2f)" % [style.phone_min_width, upright])
	check(stretch / 3.0 * upright < style.phone_min_scale, "…which is below the minimum size: small and whole, not big and cut")
	check(UiScale.factor_for(Vector2.ZERO, 1.0, base, 0.65, 2.5) == 1.0 and UiScale.factor_for(Vector2(10, 10), 1.0, Vector2.ZERO, 0.65, 2.5) == 1.0,
		"a window or base of no size is left alone")
	check(UiScale.base_size() == base, "the base size comes from the project settings (1280×720)")
	# A page shown smaller than its own pixels (itch.io's fixed embed shrunk to the phone's width).
	var shown: Callable = func(css: Vector2, ratio: float, screen: Vector2) -> float:
		return UiScale.embed_scale_for(css * ratio, screen * ratio, style.phone_min_embed_scale)
	check(is_equal_approx(shown.call(Vector2(960, 540), 3.0, Vector2(390, 844)), 844.0 / 960.0),
		"a 960-pixel page on an iPhone 14 (390×844 as iOS reports it, held sideways) is shown at %.3f of its size" % (844.0 / 960.0))
	check(is_equal_approx(shown.call(Vector2(960, 540), 3.0, Vector2(844, 390)), 844.0 / 960.0),
		"…and the same where the browser swaps the screen's sides with the phone")
	check(is_equal_approx(shown.call(Vector2(844, 340), 3.0, Vector2(390, 844)), 1.0)
		and is_equal_approx(shown.call(Vector2(750, 390), 3.0, Vector2(390, 844)), 1.0),
		"a page that fits the screen is shown at its own size (a full-screen frame, with or without a notch's gap)")
	check(is_equal_approx(shown.call(Vector2(390, 664), 3.0, Vector2(390, 844)), 1.0),
		"a page that is itself held upright counts the screen's short side, so a phone held upright is not taken for a shrunk page")
	check(is_equal_approx(shown.call(Vector2(5000, 2800), 1.0, Vector2(390, 844)), style.phone_min_embed_scale),
		"a page much wider than the screen is taken to be shrunk no further than phone_min_embed_scale")
	check(is_equal_approx(shown.call(Vector2(960, 540), 3.0, Vector2.ZERO), 1.0) and is_equal_approx(shown.call(Vector2.ZERO, 3.0, Vector2(390, 844)), 1.0),
		"where the screen or the page has no size (not a browser) the page is shown at its own size")
	var se: float = shown.call(Vector2(960, 540), 3.0, Vector2(375, 667))
	var plain: float = f.call(Vector2(960, 540), 3.0)
	var counted: float = UiScale.factor_for(Vector2(960, 540) * 3.0, 3.0, base, style.phone_min_scale, style.phone_max_factor,
		float(style.phone_min_width), se)
	check(is_equal_approx(plain, 1.0) and is_equal_approx(counted, style.phone_min_scale / (0.75 * se)),
		"a 960×540 page shrunk to an iPhone SE's width (x%.3f) is magnified x%.3f, where counting only its pixels would leave it at x%.3f" % [se, counted, plain])


func _test_lifecycle() -> void:
	var style: UiStyle = UiTheme.style()
	var phone := Vector2i(844 * 3, 340 * 3)
	UiScale.pixel_ratio_override = 3.0
	tree.root.size = phone
	var expected: float = UiScale.factor_for(Vector2(phone), 3.0, UiScale.base_size(), style.phone_min_scale,
		style.phone_max_factor, float(style.phone_min_width))
	App.show_title()
	await _frames(3)
	check(is_equal_approx(tree.root.content_scale_factor, expected) and expected > 1.2,
		"a screen on a phone's window magnifies the canvas (%.3f)" % tree.root.content_scale_factor)
	# Another screen straight after: no step back to 1 between them.
	var seen: Array[float] = []
	var watch: Callable = func() -> void: seen.append(tree.root.content_scale_factor)
	tree.root.size_changed.connect(watch)
	App.show_shop()
	await _frames(3)
	tree.root.size_changed.disconnect(watch)
	check(not seen.has(1.0) and is_equal_approx(tree.root.content_scale_factor, expected),
		"the next screen keeps it (it never drops to 1 on the way: %s)" % [seen])
	# The window changes: the factor follows.
	tree.root.size = Vector2i(844 * 3, 390 * 3)
	await _frames(3)
	var taller: float = UiScale.factor_for(Vector2(tree.root.size), 3.0, UiScale.base_size(), style.phone_min_scale,
		style.phone_max_factor, float(style.phone_min_width))
	check(is_equal_approx(tree.root.content_scale_factor, taller) and taller < expected,
		"a taller window magnifies less (%.3f)" % tree.root.content_scale_factor)
	tree.root.size = phone
	await _frames(3)
	# A run has no screen: the plain stretch (the HUD and the swipes are laid out for it).
	App.start_level(App.campaign.step("city/1"))
	await _frames(3)
	check(App.screen is LevelIntroScreen and tree.root.content_scale_factor > 1.2, "the level's introduction is a screen: magnified")
	App.begin_run()
	await physics_frames(10)
	await _frames(2)
	check(not UiScale.is_open() and is_equal_approx(tree.root.content_scale_factor, 1.0),
		"a run on show, no screen open: back to the plain stretch (%.3f)" % tree.root.content_scale_factor)
	App.pause_game()
	await _frames(3)
	check(App.overlay is PauseScreen and is_equal_approx(tree.root.content_scale_factor, expected),
		"the pause menu over it is magnified again")
	App.resume_game()
	await physics_frames(10)
	await _frames(2)
	check(is_equal_approx(tree.root.content_scale_factor, 1.0), "and resuming ends it")
	App.quit_run()
	await _frames(3)
	# A desktop, or a touch screen with room: no change.
	UiTheme.touch_override = 0
	App.show_title()
	await _frames(3)
	check(is_equal_approx(tree.root.content_scale_factor, 1.0), "a desktop's window is never magnified, whatever its size")
	# A touch device that isn't a web page (a native mobile build) is left alone, whatever its window.
	UiTheme.touch_override = 1
	UiScale.assume_web = false
	App.show_title()
	await _frames(3)
	check(is_equal_approx(tree.root.content_scale_factor, 1.0), "a native mobile build's menus are not magnified")
	UiScale.assume_web = true
	UiScale.pixel_ratio_override = 2.0
	tree.root.size = Vector2i(1180 * 2, 820 * 2)
	App.show_shop()
	await _frames(3)
	check(is_equal_approx(tree.root.content_scale_factor, 1.0), "nor a tablet's page (1180×820)")
	tree.root.size = phone
	UiScale.pixel_ratio_override = 3.0
	App.show_title()
	await _frames(3)
	check(not (App.screen as ScreenBase).is_scrolling(), "the title screen fits without scrolling on a phone held sideways")
	App.show_title()
	await _frames(2)


## A page shown smaller than its pixels (itch.io's 960×540 embed, the host page shrinking it to an iPhone SE's
## width) is magnified for what the screen shows, and a browser that doesn't tell the screen changes nothing.
func _test_embed_scale() -> void:
	var style: UiStyle = UiTheme.style()
	var window := Vector2i(960 * 3, 540 * 3)
	UiScale.pixel_ratio_override = 3.0
	tree.root.size = window
	UiScale.screen_size_override = Vector2.ZERO
	App.show_title()
	await _frames(3)
	check(is_equal_approx(tree.root.content_scale_factor, 1.0),
		"a 960×540 page whose screen the browser doesn't tell is left at x%.3f (its own pixels are big enough)" % tree.root.content_scale_factor)
	UiScale.screen_size_override = Vector2(375, 667) * 3.0
	App.show_shop()
	await _frames(3)
	var shown: float = UiScale.embed_scale_for(Vector2(window), UiScale.screen_size_override, style.phone_min_embed_scale)
	var expected: float = UiScale.factor_for(Vector2(window), 3.0, UiScale.base_size(), style.phone_min_scale,
		style.phone_max_factor, float(style.phone_min_width), shown)
	check(expected > 1.2 and is_equal_approx(tree.root.content_scale_factor, expected),
		"the same page on an iPhone SE's screen (shown at %.3f) is magnified x%.3f, as the maths says (x%.3f)" % [shown, tree.root.content_scale_factor, expected])
	# On a desktop or in a run the screen means nothing.
	UiTheme.touch_override = 0
	App.show_title()
	await _frames(3)
	check(is_equal_approx(tree.root.content_scale_factor, 1.0), "a desktop is not magnified whatever its screen says")
	UiTheme.touch_override = 1
	UiScale.screen_size_override = Vector2.ZERO
	App.show_title()
	await _frames(2)


## The page's safe-area insets (WebPage), not the display server's screen and safe area, keep a screen clear
## of a notch in a web page: an iPhone's `screen.height` is 844 held either way, and the display server's safe
## area is the window, so their difference read as a bottom margin of 40% of the page (task L1).
func _test_page_safe_area() -> void:
	check(WebPage.parse_insets("47,0,47.5,21") == Vector4(47, 0, 47.5, 21), "the page's insets 'left,top,right,bottom' parse")
	check(WebPage.parse_insets("") == Vector4.ZERO and WebPage.parse_insets("1,2,3") == Vector4.ZERO and WebPage.parse_insets("a,b,c,d") == Vector4.ZERO,
		"anything else is no inset")
	check(WebPage.parse_insets("-5,0,500,12") == Vector4(0, 0, 0, 12), "a negative or absurd one counts as none")
	UiScale.assume_web = true
	UiTheme.touch_override = 1
	UiScale.pixel_ratio_override = 3.0
	tree.root.size = Vector2i(844 * 3, 340 * 3)
	WebPage.insets_override = Vector4.ZERO
	App.show_title()
	await _frames(3)
	var screen := App.screen as ScreenBase
	check(UiTheme.safe_area_margins(screen) == Vector4.ZERO,
		"a page with no insets leaves a screen no margins, whatever the display server's screen and safe area say")
	var safe: Control = screen.get("_safe") as Control
	check(safe != null and safe.get_theme_constant(&"margin_bottom") == 0 and safe.get_theme_constant(&"margin_left") == 0,
		"the screen's own margins are none")
	# A notch's insets (CSS pixels) are kept clear, in UI pixels at the magnified size.
	WebPage.insets_override = Vector4(47, 0, 47, 21)
	await _frames(1)
	tree.root.size = Vector2i(844 * 3, 341 * 3)
	await _frames(3)
	tree.root.size = Vector2i(844 * 3, 340 * 3)
	await _frames(3)
	var view_width: float = screen.get_viewport_rect().size.x
	var k: float = view_width / 844.0
	var margins: Vector4 = UiTheme.safe_area_margins(screen)
	check(margins.is_equal_approx(Vector4(47, 0, 47, 21) * k) and k > 1.0,
		"a notch's insets (47, 0, 47, 21 CSS pixels) are %s UI pixels at x%.2f" % [margins, k])
	check(safe.get_theme_constant(&"margin_left") == roundi(47.0 * k) and safe.get_theme_constant(&"margin_bottom") == roundi(21.0 * k),
		"and the screen keeps clear of them")
	# Not a touch device, or not a web page: nothing from the page.
	UiTheme.touch_override = 0
	check(UiTheme.safe_area_margins(screen) == Vector4.ZERO, "a desktop browser gets no margins from the page")
	UiTheme.touch_override = 1
	WebPage.insets_override = null
	UiScale.assume_web = false
	check(UiTheme.safe_area_margins(screen) == Vector4.ZERO, "and neither does anything but a web page or a native phone (a test has neither)")
	UiScale.assume_web = true
	App.show_title()
	await _frames(2)


# --- Taps and drags -------------------------------------------------------------------------------

## A tap that moves a little, in every scroll area a screen has, still presses the button under it (a finger
## and a mouse jitter), and a drag past the deadzone scrolls the list without pressing it. `phone`: the
## screens as a phone's page has them (magnified, the compact layouts); otherwise at the plain stretch
## with the desktop's sizes.
func _test_taps_and_drags(phone: bool) -> void:
	var tag: String = "phone" if phone else "desktop"
	UiTheme.touch_override = 1 if phone else 0
	if phone:
		UiScale.assume_web = true
		UiScale.pixel_ratio_override = 3.0
		tree.root.size = Vector2i(844 * 3, 340 * 3)
	else:
		# A desktop window of the base size (a headless run's own is 64×64).
		tree.root.size = Vector2i(1280, 720)
	App.profile = SampleProfiles.rich()
	var deadzone: float = float(UiTheme.style().scroll_deadzone)
	var moves: Array[Vector2] = [Vector2.ZERO, Vector2(0.0, 1.0), Vector2(0.0, 3.0), Vector2(3.0, 0.0),
		Vector2(0.0, deadzone - 2.0), Vector2(-(deadzone - 2.0), 0.0)]
	# The title's Settings.
	for move: Vector2 in moves:
		App.show_title()
		await _frames(4)
		var target: Control = (App.screen.get("buttons") as Dictionary)["settings"]
		check(await _click(target, move), "%s: a tap moving %s presses the title's Settings" % [tag, move])
	# A toast never takes a click (it ignores the mouse, and the screen leaves it so): a button under one presses.
	App.show_title()
	await _frames(4)
	var under: Control = (App.screen.get("buttons") as Dictionary)["settings"]
	var toast: Toast = Toast.show_message(App.screen, "a toast over a button", &"info", Toast.Kind.INFO, 5.0)
	await _frames(20)
	var stack := toast.get_parent() as Control
	stack.global_position += under.get_global_rect().get_center() - toast.get_global_rect().get_center()
	await _frames(2)
	check(toast.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s: a toast in a screen still ignores the mouse" % tag)
	check(await _click(under, Vector2.ZERO), "%s: a click on a button under a toast presses it" % tag)
	# The shop's first BUY, and a drag from it that scrolls the shop.
	for move: Vector2 in moves:
		App.profile = SampleProfiles.rich()
		App.show_shop()
		await _frames(6)
		var buy: Control = _first_buy()
		check(buy != null, "%s: the shop has a BUY button to press" % tag)
		if buy != null:
			check(await _click(buy, move), "%s: a tap moving %s presses the shop's BUY" % [tag, move])
	App.profile = SampleProfiles.rich()
	App.show_shop()
	await _frames(6)
	await _check_drag_scrolls("%s: the shop" % tag, _first_buy(), deadzone)
	# A level tile, and a drag from it.
	for move: Vector2 in moves:
		App.show_level_select()
		await _frames(6)
		var tile: Control = _first_tile()
		check(tile != null, "%s: the level select has a tile to press" % tag)
		if tile != null:
			check(await _click(tile, move), "%s: a tap moving %s presses a level tile" % [tag, move])
	App.show_level_select()
	await _frames(6)
	await _check_drag_scrolls("%s: the level select" % tag, _first_tile(), deadzone)
	# The pause menu's Resume, and the revive offer's Revive.
	for move: Vector2 in moves:
		App.profile = SampleProfiles.rich()
		App.start_level(App.campaign.step("city/1"))
		App.begin_run()
		await physics_frames(5)
		App.pause_game()
		await _frames(4)
		var resume: Control = (App.overlay.get("buttons") as Dictionary)["resume"]
		check(await _click(resume, move), "%s: a tap moving %s presses the pause menu's Resume" % [tag, move])
		await physics_frames(2)
		App.run.world.player.call(&"_die", "Cyborg")
		await physics_frames(int((App.rules.death_screen_delay + DeathScreen.ARM_TIME + 0.5) * 60.0))
		if App.overlay is DeathScreen:
			var revive: Control = ((App.overlay as DeathScreen).buttons as Dictionary).get("item")
			check(revive != null and await _click(revive, move), "%s: a tap moving %s presses the revive offer's Revive" % [tag, move])
		else:
			check(false, "%s: the run's death shows the revive offer" % tag)
		App.show_title()
		await _frames(3)
	# A screen whose content fits ignores the mouse, so it can never take a press for a scroll.
	App.show_title()
	await _frames(4)
	var base := App.screen as ScreenBase
	check(not base.is_scrolling() and base.content_scroll.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"%s: the title screen's own scroll area ignores the mouse while the content fits" % tag)
	if phone:
		tree.root.size = Vector2i(844 * 3, 140 * 3)
		await _frames(4)
		check(base.is_scrolling() and base.content_scroll.mouse_filter == Control.MOUSE_FILTER_PASS,
			"%s: and takes it once the content needs more room than there is" % tag)
		tree.root.size = Vector2i(844 * 3, 340 * 3)
		await _frames(4)
		check(not base.is_scrolling() and base.content_scroll.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"%s: and ignores it again when the room comes back" % tag)
	App.show_title()
	await _frames(3)


func _first_buy() -> Control:
	for n: Node in App.screen.find_children("*", "ItemCard", true, false):
		var card := n as ItemCard
		if card.buy_button != null and card.buy_button.is_visible_in_tree() and not card.buy_button.disabled \
				and _in_view(card.buy_button):
			return card.buy_button
	return null


func _first_tile() -> Control:
	for n: Node in App.screen.find_children("*", "TileButton", true, false):
		var tile := n as TileButton
		if tile.is_visible_in_tree() and not tile.disabled and _in_view(tile):
			return tile
	return null


## True if the control's centre is inside the screen and its scroll area.
func _in_view(c: Control) -> bool:
	var at: Vector2 = c.get_global_rect().get_center()
	if not Rect2(Vector2.ZERO, c.get_viewport_rect().size).has_point(at):
		return false
	var node: Node = c.get_parent()
	while node != null:
		if node is ScrollContainer and not (node as ScrollContainer).get_global_rect().has_point(at):
			return false
		node = node.get_parent()
	return true


## A drag from `target` past the deadzone scrolls the list it's in (if it can scroll) and doesn't press it.
func _check_drag_scrolls(what: String, target: Control, deadzone: float) -> void:
	check(target != null, "%s has something to drag from" % what)
	if target == null:
		return
	var scroller: ScrollContainer = null
	var node: Node = target.get_parent()
	while node != null:
		if node is ScrollContainer and (node as ScrollContainer).get_v_scroll_bar().max_value > (node as ScrollContainer).get_v_scroll_bar().page + 1.0:
			scroller = node as ScrollContainer
			break
		node = node.get_parent()
	check(scroller != null, "%s scrolls (its list is taller than its room)" % what)
	if scroller == null:
		return
	var before: int = scroller.scroll_vertical
	var pressed: bool = await _drag(target, Vector2(0.0, -(deadzone + 40.0)))
	check(scroller.scroll_vertical > before and not pressed,
		"%s: a drag of %.0f px from a button scrolls it (%d to %d) without pressing it (%s)" % [what, deadzone + 40.0,
		before, scroller.scroll_vertical, pressed])


## Presses `target`, moves the pointer by `jitter` and releases: did the button's `pressed` fire?
func _click(target: Control, jitter: Vector2) -> bool:
	return await _press_move_release(target, jitter, 1)


func _drag(target: Control, delta: Vector2) -> bool:
	return await _press_move_release(target, delta, maxi(int(delta.length() / 6.0), 1))


func _press_move_release(target: Control, delta: Vector2, steps: int) -> bool:
	var fired: Array = [false]
	var cb: Callable = func() -> void: fired[0] = true
	(target as BaseButton).pressed.connect(cb)
	var at: Vector2 = target.get_global_rect().get_center()
	_mouse_motion(at, Vector2.ZERO, 0)
	await tree.process_frame
	_mouse_button(at, true)
	await tree.process_frame
	var pos: Vector2 = at
	if delta != Vector2.ZERO:
		for i: int in steps:
			var step: Vector2 = delta / float(steps)
			pos += step
			_mouse_motion(pos, step, MOUSE_BUTTON_MASK_LEFT)
			await tree.process_frame
	_mouse_button(pos, false)
	await tree.process_frame
	if is_instance_valid(target) and target.is_connected(&"pressed", cb):
		target.disconnect(&"pressed", cb)
	await _frames(2)
	return fired[0]


func _mouse_motion(at: Vector2, relative: Vector2, mask: int) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	motion.relative = relative
	motion.button_mask = mask as MouseButtonMask
	tree.root.push_input(motion, true)


func _mouse_button(at: Vector2, pressed: bool) -> void:
	var button := InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = pressed
	button.position = at
	button.global_position = at
	button.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0 as MouseButtonMask
	tree.root.push_input(button, true)

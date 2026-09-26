class_name UiTheme
extends RefCounted
## Builds the game's Theme in code from a UiStyle (data/ui/ui_style.tres): fonts, colours, a
## StyleBox for every state of every control the screens use (including a clearly visible focus
## ring for keyboard and controller navigation), type variations for headings, captions, button
## kinds and panels, and entries for the custom-drawn widgets in scripts/ui/widgets/.
##
## Two sizings: desktop, and touch (DeviceProfile.is_mobile()) with finger-size controls and
## slightly larger text. And two flavours of the same look: menus, and the HUD (lighter: outlined
## text, small translucent chips instead of panels).
##
## Using it:
## - ScreenBase applies the menu theme to itself; everything added to a screen inherits it.
## - Anything else: UiTheme.apply(root) (or apply(root, true) for the HUD) BEFORE adding children.
##   A CanvasLayer does not pass a theme down, so put a themed Control directly under it.
## - Kit widgets that end up with no themed ancestor give themselves the menu theme.

const STYLE_PATH: String = "res://data/ui/ui_style.tres"

# Theme type variations: control.theme_type_variation = UiTheme.HEADING
const TITLE: StringName = &"TitleLabel"
const SCREEN_TITLE: StringName = &"ScreenTitleLabel"
const HEADING: StringName = &"HeadingLabel"
const SUBHEADING: StringName = &"SubheadingLabel"
const CAPTION: StringName = &"CaptionLabel"
## Caption-size status text: "OWNED", "NEW", "NOT ENOUGH CREDITS".
const ACCENT_CAPTION: StringName = &"AccentCaptionLabel"
const DANGER_CAPTION: StringName = &"DangerCaptionLabel"
## Names on cards and list rows (smaller than HEADING).
const CARD_TITLE: StringName = &"CardTitleLabel"
const ACCENT_TEXT: StringName = &"AccentLabel"
const DANGER_TEXT: StringName = &"DangerLabel"
const VALUE: StringName = &"ValueLabel"
const KEY_CAP: StringName = &"KeyCapLabel"
const HUD_TEXT: StringName = &"HudLabel"
const HUD_VALUE: StringName = &"HudValueLabel"
const HUD_CAPTION: StringName = &"HudCaptionLabel"
const PRIMARY_BUTTON: StringName = &"PrimaryButton"
const DANGER_BUTTON: StringName = &"DangerButton"
const FLAT_BUTTON: StringName = &"FlatButton"
const ICON_BUTTON: StringName = &"IconButton"
const HUD_BUTTON: StringName = &"HudButton"
const PRICE_BUTTON: StringName = &"PriceButton"
const CARD: StringName = &"CardPanel"
const DIALOG: StringName = &"DialogPanel"
const BAR: StringName = &"BarPanel"
const FOOTER: StringName = &"FooterPanel"
const HUD_PANEL: StringName = &"HudPanel"
const TOAST: StringName = &"ToastPanel"
const TOAST_WARNING: StringName = &"ToastWarningPanel"
const THIN_BAR: StringName = &"ThinProgressBar"
## Shared metrics and palette for custom widgets: get_theme_constant(&"control_height", UiTheme.NEON).
const NEON: StringName = &"Neon"

## Shorter names for keys whose engine names are long.
const KEY_NAMES: Dictionary = {"Escape": "Esc", "BackSpace": "Backspace", "PageUp": "PgUp",
	"PageDown": "PgDn", "Kp Enter": "Enter", "Control": "Ctrl"}

## Display servers that can name a physical key on the current keyboard layout.
const LAYOUT_AWARE_SERVERS: PackedStringArray = ["Windows", "X11", "Wayland", "macOS"]

## -1 = decide by device, 0 = desktop sizing, 1 = touch sizing (tests, the showcase's --touch).
static var touch_override: int = -1
static var _style: UiStyle
static var _themes: Dictionary = {}


static func style() -> UiStyle:
	if _style == null:
		if ResourceLoader.exists(STYLE_PATH):
			_style = load(STYLE_PATH) as UiStyle
		if _style == null:
			_style = UiStyle.new()
	return _style


## Swaps the style (e.g. live retuning). Themes are rebuilt on next use; controls already using the
## old Theme keep it until they're given the new one.
static func set_style(new_style: UiStyle) -> void:
	_style = new_style
	_themes.clear()


static func is_touch() -> bool:
	if touch_override >= 0:
		return touch_override == 1
	return DeviceProfile.is_mobile()


## The shared Theme for this device (built once). `hud` = the lighter in-game flavour.
static func get_theme(hud: bool = false) -> Theme:
	var key: String = "%s/%s" % [is_touch(), hud]
	if not _themes.has(key):
		_themes[key] = build(style(), is_touch(), hud)
	return _themes[key]


static func apply(control: Control, hud: bool = false) -> void:
	control.theme = get_theme(hud)


## Gives `control` the menu theme unless it or an ancestor already provides a UiTheme theme.
static func ensure(control: Control) -> void:
	if control.theme != null or not control.is_inside_tree():
		return
	if not control.has_theme_constant(&"control_height", NEON):
		control.theme = get_theme()


static func build(s: UiStyle, touch: bool = false, hud: bool = false) -> Theme:
	var b := _Builder.new(s, touch)
	b.build_all()
	if hud:
		b.hud_defaults()
	return b.theme


## The colour of a credit denomination (1, 5, 25, 100).
static func credit_color(denomination: int) -> Color:
	var colors: PackedColorArray = style().credit_colors
	if colors.is_empty():
		return style().text
	var index: int = 0
	for i: int in IconFactory.DENOMINATIONS.size():
		if denomination >= IconFactory.DENOMINATIONS[i]:
			index = i
	return colors[mini(index, colors.size() - 1)]


## 12450 → "12,450".
static func format_int(value: int) -> String:
	var digits: String = str(absi(value))
	var out: String = ""
	for i: int in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += ","
		out += digits[i]
	return ("-" if value < 0 else "") + out


## A short, readable name for an input event ("Space", "Esc", "Shift+E").
static func event_text(event: InputEvent) -> String:
	if event is InputEventKey:
		var key := event as InputEventKey
		var code: Key = key.keycode
		if key.physical_keycode != KEY_NONE:
			code = key.physical_keycode
			# Show the key on the player's layout (Z on AZERTY for physical W). Only the desktop
			# display servers can map it; the others report an error.
			if LAYOUT_AWARE_SERVERS.has(DisplayServer.get_name()):
				var mapped: Key = DisplayServer.keyboard_get_keycode_from_physical(key.physical_keycode)
				if mapped != KEY_NONE:
					code = mapped
		var name: String = OS.get_keycode_string(code)
		name = KEY_NAMES.get(name, name)
		# Prefixed innermost first, so the result reads Ctrl+Alt+Shift+Key.
		for mod: Array in [[key.shift_pressed, "Shift"], [key.alt_pressed, "Alt"], [key.ctrl_pressed, "Ctrl"]]:
			if mod[0] and name != mod[1]:
				name = "%s+%s" % [mod[1], name]
		return name
	if event is InputEventMouseButton:
		return "Mouse %d" % (event as InputEventMouseButton).button_index
	if event is InputEventJoypadButton:
		return "Pad %d" % (event as InputEventJoypadButton).button_index
	return event.as_text() if event != null else ""


## The key first bound to an action, for hints ("Esc" for ui_cancel). Empty if none.
static func action_text(action: StringName) -> String:
	if not InputMap.has_action(action):
		return ""
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			return event_text(event)
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	return event_text(events[0]) if not events.is_empty() else ""


## Width of one digit cell: digits drawn with draw_tabular() all take this much room, so a counting
## number never jitters, whatever the font's own digit widths.
static func digit_cell(font: Font, font_size: int) -> float:
	var w: float = 0.0
	for d: String in "0123456789":
		w = maxf(w, font.get_string_size(d, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	return w


static func tabular_width(font: Font, text: String, font_size: int) -> float:
	var cell: float = digit_cell(font, font_size)
	var w: float = 0.0
	for ch: String in text:
		w += cell if ch.is_valid_int() else font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return w


## Draws `text` with fixed-width digits. `position` is the left end of the baseline.
static func draw_tabular(ci: CanvasItem, font: Font, position: Vector2, text: String, font_size: int,
		color: Color, outline_size: int = 0, outline_color: Color = Color.BLACK) -> void:
	var cell: float = digit_cell(font, font_size)
	var x: float = position.x
	for ch: String in text:
		var w: float = font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var slot: float = cell if ch.is_valid_int() else w
		var at := Vector2(x + (slot - w) * 0.5, position.y)
		if outline_size > 0:
			ci.draw_string_outline(font, at, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline_size, outline_color)
		ci.draw_string(font, at, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		x += slot


## Insets (left, top, right, bottom) in canvas units that keep content clear of notches and rounded
## corners. Zero except on phones and tablets (a desktop's "safe area" is just the taskbar's gap).
static func safe_area_margins(control: Control) -> Vector4:
	if not DeviceProfile.is_mobile() or not control.is_inside_tree():
		return Vector4.ZERO
	var screen := Vector2(DisplayServer.screen_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if screen.x <= 0.0 or screen.y <= 0.0 or safe.size.x <= 0.0 or safe.size.y <= 0.0:
		return Vector4.ZERO
	var k: Vector2 = control.get_viewport_rect().size / screen
	return Vector4(safe.position.x * k.x, safe.position.y * k.y,
		maxf(0.0, screen.x - safe.end.x) * k.x, maxf(0.0, screen.y - safe.end.y) * k.y)


## Builds one Theme. Separate from the statics so every helper can see the style and scale.
class _Builder:
	extends RefCounted
	var s: UiStyle
	var touch: bool
	var k: float
	var control_h: int
	var theme := Theme.new()
	var f_title: FontVariation
	var f_display: FontVariation
	var f_display_wide: FontVariation
	var f_body: FontVariation
	var f_strong: FontVariation
	var f_button: FontVariation
	var f_digits: FontVariation

	func _init(style: UiStyle, touch_mode: bool) -> void:
		s = style
		touch = touch_mode
		k = s.touch_scale if touch else 1.0
		control_h = s.touch_control_height if touch else s.control_height

	func px(v: float) -> int:
		return roundi(v * k)

	func build_all() -> void:
		make_fonts()
		labels()
		buttons()
		toggles()
		panels()
		ranges()
		inputs()
		popups()
		tabs()
		containers()
		widgets()

	# --- Fonts -------------------------------------------------------------------

	func make_fonts() -> void:
		f_body = variation(s.body_font, s.body_weight, 0)
		f_strong = variation(s.body_font, s.strong_weight, 0)
		f_button = variation(s.body_font, s.strong_weight, 1)
		f_digits = variation(s.body_font, s.strong_weight, 0, true)
		f_title = variation(s.display_font, s.title_weight, 2)
		f_display = variation(s.display_font, s.display_weight, 1)
		f_display_wide = variation(s.display_font, maxi(s.display_weight - 100, 400), 3)
		var fallback: Array[Font] = [f_body]
		for f: FontVariation in [f_title, f_display, f_display_wide]:
			f.fallbacks = fallback
		theme.default_font = f_body
		theme.default_font_size = px(s.body_size)

	func variation(base: Font, weight: int, spacing: int, tabular: bool = false) -> FontVariation:
		var ts: TextServer = TextServerManager.get_primary_interface()
		var v := FontVariation.new()
		v.base_font = base
		# Integer tags: string axis names are silently ignored here.
		v.variation_opentype = {ts.name_to_tag("wght"): weight}
		v.spacing_glyph = spacing
		if tabular:
			v.opentype_features = {ts.name_to_tag("tnum"): 1}
		return v

	# --- StyleBox helpers ----------------------------------------------------------

	## A flat box with the top-left and bottom-right corners cut (chamfered) by `cut` pixels.
	func box(bg: Color, border: Color = Color(0, 0, 0, 0), border_w: int = 0, cut: int = 0,
			margin_h: float = 0.0, margin_v: float = 0.0) -> StyleBoxFlat:
		var b := StyleBoxFlat.new()
		b.bg_color = bg
		b.draw_center = bg.a > 0.0
		b.border_color = border
		b.set_border_width_all(border_w if border.a > 0.0 else 0)
		b.corner_radius_top_left = cut
		b.corner_radius_bottom_right = cut
		b.corner_detail = 1
		b.anti_aliasing = true
		b.content_margin_left = margin_h
		b.content_margin_right = margin_h
		b.content_margin_top = margin_v
		b.content_margin_bottom = margin_v
		return b

	func glow(b: StyleBoxFlat, color: Color, size: int) -> StyleBoxFlat:
		b.shadow_color = color
		b.shadow_size = size
		return b

	func empty(margin_h: float = 0.0, margin_v: float = 0.0) -> StyleBoxEmpty:
		var e := StyleBoxEmpty.new()
		e.content_margin_left = margin_h
		e.content_margin_right = margin_h
		e.content_margin_top = margin_v
		e.content_margin_bottom = margin_v
		return e

	## The focus ring, drawn over a focused control: bright border, glow, just outside the edge.
	func focus_box(cut: int) -> StyleBoxFlat:
		var f := box(Color(0, 0, 0, 0), s.accent.lerp(Color.WHITE, 0.45), px(s.focus_width), cut + px(2))
		f.set_border_width_all(px(s.focus_width))
		f.set_expand_margin_all(px(3))
		return glow(f, Color(s.accent, 0.6), px(s.glow_size))

	func line(color: Color, vertical: bool) -> StyleBoxLine:
		var l := StyleBoxLine.new()
		l.color = color
		l.thickness = 1
		l.vertical = vertical
		return l

	func svg_texture(body: String, w: float, h: float) -> Texture2D:
		return DPITexture.create_from_string(
			'<svg xmlns="http://www.w3.org/2000/svg" width="%s" height="%s" viewBox="0 0 %s %s">%s</svg>' % [w, h, w, h, body])

	func hex(c: Color) -> String:
		return "#" + c.to_html(false)

	func copy_type(from: StringName, to: StringName) -> void:
		for data_type: int in Theme.DATA_TYPE_MAX:
			for item: String in theme.get_theme_item_list(data_type, from):
				theme.set_theme_item(data_type, item, to, theme.get_theme_item(data_type, item, from))

	# --- Labels --------------------------------------------------------------------

	func labels() -> void:
		theme.set_color(&"font_color", &"Label", s.text)
		theme.set_color(&"font_outline_color", &"Label", s.outline)
		theme.set_color(&"font_shadow_color", &"Label", Color(0, 0, 0, 0))
		theme.set_constant(&"outline_size", &"Label", 0)
		theme.set_constant(&"line_spacing", &"Label", px(2))
		label_type(UiTheme.TITLE, f_title, s.title_size, s.text)
		# A soft halo in the accent colour: a zero-offset shadow outline.
		theme.set_color(&"font_shadow_color", UiTheme.TITLE, Color(s.accent, 0.28))
		theme.set_constant(&"shadow_outline_size", UiTheme.TITLE, px(10))
		theme.set_constant(&"shadow_offset_x", UiTheme.TITLE, 0)
		theme.set_constant(&"shadow_offset_y", UiTheme.TITLE, 0)
		label_type(UiTheme.SCREEN_TITLE, f_title, s.screen_title_size, s.text)
		theme.set_color(&"font_shadow_color", UiTheme.SCREEN_TITLE, Color(s.accent, 0.22))
		theme.set_constant(&"shadow_outline_size", UiTheme.SCREEN_TITLE, px(8))
		theme.set_constant(&"shadow_offset_x", UiTheme.SCREEN_TITLE, 0)
		theme.set_constant(&"shadow_offset_y", UiTheme.SCREEN_TITLE, 0)
		label_type(UiTheme.HEADING, f_display, s.heading_size, s.text)
		label_type(UiTheme.SUBHEADING, f_display_wide, s.subheading_size, s.accent)
		label_type(UiTheme.CAPTION, f_body, s.caption_size, s.text_dim)
		label_type(UiTheme.ACCENT_CAPTION, f_strong, s.caption_size, s.accent.lerp(Color.WHITE, 0.15))
		label_type(UiTheme.DANGER_CAPTION, f_strong, s.caption_size, s.danger)
		label_type(UiTheme.CARD_TITLE, f_display, s.heading_size - 5, s.text)
		label_type(UiTheme.ACCENT_TEXT, f_strong, s.body_size, s.accent)
		label_type(UiTheme.DANGER_TEXT, f_strong, s.body_size, s.danger)
		label_type(UiTheme.VALUE, f_display, s.value_size, s.text)
		label_type(UiTheme.KEY_CAP, f_button, s.caption_size - 2, s.text)
		theme.set_stylebox(&"normal", UiTheme.KEY_CAP,
			box(Color(s.accent, 0.08), Color(s.text_dim, 0.7), s.border_width, px(4), px(8), px(2)))
		# HUD text sits over the 3D scene: outlined, no panels.
		label_type(UiTheme.HUD_TEXT, f_strong, s.hud_text_size, s.text)
		label_type(UiTheme.HUD_VALUE, f_display, s.hud_value_size, s.text)
		label_type(UiTheme.HUD_CAPTION, f_strong, s.caption_size - 1, s.text_dim)
		for t: StringName in [UiTheme.HUD_TEXT, UiTheme.HUD_VALUE, UiTheme.HUD_CAPTION]:
			theme.set_constant(&"outline_size", t, px(5))
			theme.set_color(&"font_outline_color", t, s.outline)
		theme.set_color(&"font_color", &"RichTextLabel", s.text)
		theme.set_color(&"default_color", &"RichTextLabel", s.text)
		theme.set_font(&"normal_font", &"RichTextLabel", f_body)
		theme.set_font(&"bold_font", &"RichTextLabel", f_strong)
		theme.set_font_size(&"normal_font_size", &"RichTextLabel", px(s.body_size))
		theme.set_font_size(&"bold_font_size", &"RichTextLabel", px(s.body_size))
		theme.set_stylebox(&"normal", &"RichTextLabel", empty())
		theme.set_stylebox(&"focus", &"RichTextLabel", empty())

	func label_type(type: StringName, font: Font, size: int, color: Color) -> void:
		theme.set_type_variation(type, &"Label")
		theme.set_font(&"font", type, font)
		theme.set_font_size(&"font_size", type, px(size))
		theme.set_color(&"font_color", type, color)

	# --- Buttons -------------------------------------------------------------------

	func buttons() -> void:
		var a: Color = s.accent
		var bw: int = s.border_width
		var cut: int = px(s.corner_cut)
		var font_h: float = f_button.get_height(px(s.button_size))
		var pad_v: float = maxf(px(4), ((control_h - font_h) * 0.5))
		var pad_h: float = px(20)
		var normal := box(s.surface, Color(a, 0.4), bw, cut, pad_h, pad_v)
		var hover := glow(box(s.surface.lerp(a, 0.16), Color(a, 0.95), bw, cut, pad_h, pad_v), Color(a, 0.25), px(6))
		var pressed := box(s.surface.lerp(a, 0.38), a, bw, cut, pad_h, pad_v)
		var disabled := box(Color(s.surface, 0.5), Color(s.text_disabled, 0.45), bw, cut, pad_h, pad_v)
		button_type(&"Button", normal, hover, pressed, disabled, focus_box(cut))
		button_colors(&"Button", s.text, Color.WHITE, s.text_disabled)
		theme.set_font(&"font", &"Button", f_button)
		theme.set_font_size(&"font_size", &"Button", px(s.button_size))
		theme.set_constant(&"h_separation", &"Button", px(10))
		theme.set_constant(&"outline_size", &"Button", 0)
		theme.set_constant(&"align_to_largest_stylebox", &"Button", 1)

		# Primary: the one main action on a screen (PLAY, BUY).
		theme.set_type_variation(UiTheme.PRIMARY_BUTTON, &"Button")
		button_type(UiTheme.PRIMARY_BUTTON,
			glow(box(s.surface.lerp(a, 0.26), a, bw, cut, pad_h, pad_v), Color(a, 0.2), px(6)),
			glow(box(s.surface.lerp(a, 0.4), a.lerp(Color.WHITE, 0.3), bw, cut, pad_h, pad_v), Color(a, 0.4), px(10)),
			glow(box(s.surface.lerp(a, 0.58), a.lerp(Color.WHITE, 0.4), bw, cut, pad_h, pad_v), Color(a, 0.5), px(8)),
			disabled, focus_box(cut))
		button_colors(UiTheme.PRIMARY_BUTTON, Color.WHITE, Color.WHITE, s.text_disabled)
		theme.set_font(&"font", UiTheme.PRIMARY_BUTTON, f_display)

		# Danger: destructive actions (quit, reset). Red only here and in warnings.
		var d: Color = s.danger
		theme.set_type_variation(UiTheme.DANGER_BUTTON, &"Button")
		button_type(UiTheme.DANGER_BUTTON,
			box(s.surface, Color(d, 0.5), bw, cut, pad_h, pad_v),
			glow(box(s.surface.lerp(d, 0.14), d, bw, cut, pad_h, pad_v), Color(d, 0.25), px(6)),
			box(s.surface.lerp(d, 0.35), d, bw, cut, pad_h, pad_v),
			disabled, focus_box(cut))
		button_colors(UiTheme.DANGER_BUTTON, s.text, Color.WHITE, s.text_disabled)

		# Flat: text-only actions (the title bar's back button, footer links).
		theme.set_type_variation(UiTheme.FLAT_BUTTON, &"Button")
		button_type(UiTheme.FLAT_BUTTON, empty(px(14), pad_v),
			box(Color(a, 0.1), Color(0, 0, 0, 0), 0, cut, px(14), pad_v),
			box(Color(a, 0.22), Color(0, 0, 0, 0), 0, cut, px(14), pad_v),
			empty(px(14), pad_v), focus_box(cut))
		button_colors(UiTheme.FLAT_BUTTON, s.text_dim, s.accent.lerp(Color.WHITE, 0.35), s.text_disabled)

		# Price: the shop's buy button. Like Primary, but "can't afford" shows the price in red.
		theme.set_type_variation(UiTheme.PRICE_BUTTON, UiTheme.PRIMARY_BUTTON)
		theme.set_font(&"font", UiTheme.PRICE_BUTTON, f_digits)
		theme.set_stylebox(&"disabled", UiTheme.PRICE_BUTTON,
			box(Color(s.surface, 0.6), Color(d, 0.45), bw, cut, px(11), pad_v))
		theme.set_color(&"font_disabled_color", UiTheme.PRICE_BUTTON, d)
		theme.set_color(&"icon_disabled_color", UiTheme.PRICE_BUTTON, Color(1, 1, 1, 0.45))
		for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
			var sb := (theme.get_stylebox(state, UiTheme.PRIMARY_BUTTON) as StyleBoxFlat).duplicate() as StyleBoxFlat
			sb.content_margin_left = px(11)
			sb.content_margin_right = px(11)
			theme.set_stylebox(state, UiTheme.PRICE_BUTTON, sb)

		# Icon-only square buttons: pause, settings, back on touch screens.
		var icon_pad: float = maxf(px(4), (control_h - px(s.icon_size)) * 0.5)
		theme.set_type_variation(UiTheme.ICON_BUTTON, &"Button")
		button_type(UiTheme.ICON_BUTTON,
			box(s.surface, Color(a, 0.4), bw, cut, icon_pad, icon_pad),
			glow(box(s.surface.lerp(a, 0.16), Color(a, 0.95), bw, cut, icon_pad, icon_pad), Color(a, 0.25), px(6)),
			box(s.surface.lerp(a, 0.38), a, bw, cut, icon_pad, icon_pad),
			box(Color(s.surface, 0.5), Color(s.text_disabled, 0.45), bw, cut, icon_pad, icon_pad),
			focus_box(cut))

		# HUD buttons (the touch pause button): translucent, over the game.
		theme.set_type_variation(UiTheme.HUD_BUTTON, &"Button")
		button_type(UiTheme.HUD_BUTTON,
			box(Color(s.outline, 0.4), Color(1, 1, 1, 0.22), bw, cut, icon_pad, icon_pad),
			box(Color(s.outline, 0.55), Color(a, 0.9), bw, cut, icon_pad, icon_pad),
			box(Color(a, 0.35), a, bw, cut, icon_pad, icon_pad),
			box(Color(s.outline, 0.25), Color(1, 1, 1, 0.1), bw, cut, icon_pad, icon_pad),
			focus_box(cut))
		button_colors(UiTheme.HUD_BUTTON, Color(1, 1, 1, 0.9), Color.WHITE, s.text_disabled)

	func button_type(type: StringName, normal: StyleBox, hover: StyleBox, pressed: StyleBox,
			disabled: StyleBox, focus: StyleBox) -> void:
		theme.set_stylebox(&"normal", type, normal)
		theme.set_stylebox(&"hover", type, hover)
		theme.set_stylebox(&"pressed", type, pressed)
		theme.set_stylebox(&"hover_pressed", type, pressed)
		theme.set_stylebox(&"disabled", type, disabled)
		theme.set_stylebox(&"focus", type, focus)

	func button_colors(type: StringName, normal: Color, active: Color, disabled: Color) -> void:
		theme.set_color(&"font_color", type, normal)
		theme.set_color(&"icon_normal_color", type, normal)
		for state: String in ["hover", "pressed", "hover_pressed", "focus"]:
			theme.set_color("font_%s_color" % state, type, active)
			theme.set_color("icon_%s_color" % state, type, active)
		theme.set_color(&"font_disabled_color", type, disabled)
		theme.set_color(&"icon_disabled_color", type, disabled)
		theme.set_color(&"font_outline_color", type, s.outline)

	# --- Check boxes and switches ----------------------------------------------------

	func toggles() -> void:
		var pad_v: float = maxf(px(2), ((control_h - f_button.get_height(px(s.button_size))) * 0.5))
		var hover := box(Color(s.accent, 0.08), Color(0, 0, 0, 0), 0, px(s.corner_cut), px(8), pad_v)
		for type: StringName in [&"CheckBox", &"CheckButton"]:
			button_type(type, empty(px(8), pad_v), hover, empty(px(8), pad_v), empty(px(8), pad_v), focus_box(px(s.corner_cut)))
			theme.set_stylebox(&"hover_pressed", type, hover)
			button_colors(type, s.text, Color.WHITE, s.text_disabled)
			theme.set_color(&"font_pressed_color", type, s.text)
			theme.set_font(&"font", type, f_strong)
			theme.set_constant(&"h_separation", type, px(12))
		var c: float = px(24)
		var on_fill: String = hex(s.accent)
		var box_path: String = "M4 3 H21 V17 L17 21 H3 V7 Z"
		theme.set_icon(&"unchecked", &"CheckBox", svg_texture(
			'<path transform="scale(%s)" d="%s" fill="%s" fill-opacity="0.6" stroke="%s" stroke-opacity="0.8" stroke-width="1.6"/>'
			% [c / 24.0, box_path, hex(s.outline), hex(s.text_dim)], c, c))
		theme.set_icon(&"checked", &"CheckBox", svg_texture(
			('<g transform="scale(%s)"><path d="%s" fill="%s" fill-opacity="0.3" stroke="%s" stroke-width="1.6"/>'
			+ '<path d="M7 12.5 L10.5 16 L17.5 8" fill="none" stroke="#ffffff" stroke-width="2.6" stroke-linejoin="round"/></g>')
			% [c / 24.0, box_path, on_fill, on_fill], c, c))
		theme.set_icon(&"unchecked_disabled", &"CheckBox", svg_texture(
			'<path transform="scale(%s)" d="%s" fill="none" stroke="%s" stroke-width="1.4"/>'
			% [c / 24.0, box_path, hex(s.text_disabled)], c, c))
		theme.set_icon(&"checked_disabled", &"CheckBox", svg_texture(
			('<g transform="scale(%s)"><path d="%s" fill="none" stroke="%s" stroke-width="1.4"/>'
			+ '<path d="M7 12.5 L10.5 16 L17.5 8" fill="none" stroke="%s" stroke-width="2.4"/></g>')
			% [c / 24.0, box_path, hex(s.text_disabled), hex(s.text_disabled)], c, c))
		var ring: String = '<circle cx="12" cy="12" r="8.5" fill="%s" fill-opacity="0.6" stroke="%s" stroke-width="1.6"/>'
		theme.set_icon(&"radio_unchecked", &"CheckBox", svg_texture(
			'<g transform="scale(%s)">%s</g>' % [c / 24.0, ring % [hex(s.outline), hex(s.text_dim)]], c, c))
		theme.set_icon(&"radio_checked", &"CheckBox", svg_texture(
			'<g transform="scale(%s)">%s<circle cx="12" cy="12" r="4.5" fill="%s"/></g>'
			% [c / 24.0, ring % [hex(s.outline), on_fill], on_fill], c, c))
		theme.set_icon(&"radio_unchecked_disabled", &"CheckBox", svg_texture(
			'<g transform="scale(%s)">%s</g>' % [c / 24.0, ring % ["#000000", hex(s.text_disabled)]], c, c))
		theme.set_icon(&"radio_checked_disabled", &"CheckBox", svg_texture(
			'<g transform="scale(%s)">%s<circle cx="12" cy="12" r="4.5" fill="%s"/></g>'
			% [c / 24.0, ring % ["#000000", hex(s.text_disabled)], hex(s.text_disabled)], c, c))
		# CheckButton: the same switch ToggleSwitch draws, as textures.
		var w: float = px(48)
		var h: float = px(26)
		for mirrored: bool in [false, true]:
			var suffix: String = "_mirrored" if mirrored else ""
			theme.set_icon("unchecked" + suffix, &"CheckButton", switch_texture(w, h, false, mirrored, true))
			theme.set_icon("checked" + suffix, &"CheckButton", switch_texture(w, h, true, mirrored, true))
			theme.set_icon("unchecked_disabled" + suffix, &"CheckButton", switch_texture(w, h, false, mirrored, false))
			theme.set_icon("checked_disabled" + suffix, &"CheckButton", switch_texture(w, h, true, mirrored, false))

	func switch_texture(w: float, h: float, on: bool, mirrored: bool, enabled: bool) -> Texture2D:
		var r: float = h * 0.5
		var knob_right: bool = on != mirrored
		var track: Color = s.surface.lerp(s.accent, 0.45) if on else Color(s.outline, 0.85)
		var border: Color = s.accent if on else s.text_dim
		var knob: Color = Color.WHITE if on else s.text_dim
		if not enabled:
			track = Color(s.outline, 0.6)
			border = s.text_disabled
			knob = s.text_disabled
		var cx: float = (w - r) if knob_right else r
		return svg_texture(
			('<rect x="1" y="1" width="%s" height="%s" rx="%s" fill="%s" fill-opacity="%.2f" stroke="%s" stroke-width="1.5"/>'
			+ '<circle cx="%s" cy="%s" r="%s" fill="%s"/>')
			% [w - 2, h - 2, r - 1, hex(track), track.a, hex(border), cx, r, r - px(5), hex(knob)], w, h)

	# --- Panels ----------------------------------------------------------------------

	func panels() -> void:
		var a: Color = s.accent
		var bw: int = s.border_width
		var panel := glow(box(s.panel, Color(a, 0.45), bw, px(s.panel_corner_cut), px(22), px(18)), Color(a, 0.1), px(14))
		theme.set_stylebox(&"panel", &"PanelContainer", panel)
		theme.set_stylebox(&"panel", &"Panel", panel)
		panel_type(UiTheme.CARD, glow(box(s.surface, Color(a, 0.3), bw, px(12), px(12), px(12)), Color(0, 0, 0, 0.35), px(8)))
		panel_type(UiTheme.DIALOG, glow(box(Color(s.panel, 0.97), Color(a, 0.9), bw, px(s.panel_corner_cut + 4), px(30), px(24)),
			Color(a, 0.3), px(20)))
		var bar := box(Color(s.backdrop_bottom, 0.72), Color(a, 0.35), 0, 0, px(12), px(6))
		bar.border_width_bottom = bw
		panel_type(UiTheme.BAR, bar)
		var footer := box(Color(s.backdrop_bottom, 0.6), Color(a, 0.22), 0, 0, px(24), px(7))
		footer.border_width_top = bw
		panel_type(UiTheme.FOOTER, footer)
		panel_type(UiTheme.HUD_PANEL, box(Color(s.outline, 0.42), Color(1, 1, 1, 0.1), bw, px(8), px(12), px(6)))
		panel_type(UiTheme.TOAST, glow(box(Color(s.panel, 0.96), a, bw, px(10), px(18), px(10)), Color(a, 0.3), px(12)))
		panel_type(UiTheme.TOAST_WARNING, glow(box(Color(s.panel, 0.96), s.danger, bw, px(10), px(18), px(10)),
			Color(s.danger, 0.3), px(12)))
		theme.set_stylebox(&"panel", &"TooltipPanel",
			box(Color(s.panel, 0.97), Color(a, 0.6), bw, px(6), px(10), px(6)))
		theme.set_color(&"font_color", &"TooltipLabel", s.text)
		theme.set_font(&"font", &"TooltipLabel", f_body)
		theme.set_font_size(&"font_size", &"TooltipLabel", px(s.caption_size))
		theme.set_stylebox(&"separator", &"HSeparator", line(Color(a, 0.25), false))
		theme.set_stylebox(&"separator", &"VSeparator", line(Color(a, 0.25), true))
		theme.set_constant(&"separation", &"HSeparator", px(s.spacing))
		theme.set_constant(&"separation", &"VSeparator", px(s.spacing))

	func panel_type(type: StringName, style_box: StyleBox) -> void:
		theme.set_type_variation(type, &"PanelContainer")
		theme.set_stylebox(&"panel", type, style_box)

	# --- Progress bars, sliders, scroll bars -----------------------------------------------

	func ranges() -> void:
		var a: Color = s.accent
		var track_bg := Color(s.outline, 0.6)
		theme.set_stylebox(&"background", &"ProgressBar", box(track_bg, Color(a, 0.3), s.border_width, 0, 0, px(5)))
		theme.set_stylebox(&"fill", &"ProgressBar", glow(box(a, Color(0, 0, 0, 0), 0, 0, 0, px(5)), Color(a, 0.35), px(6)))
		theme.set_font(&"font", &"ProgressBar", f_digits)
		theme.set_font_size(&"font_size", &"ProgressBar", px(s.caption_size - 2))
		theme.set_color(&"font_color", &"ProgressBar", s.text)
		theme.set_color(&"font_outline_color", &"ProgressBar", s.outline)
		theme.set_constant(&"outline_size", &"ProgressBar", px(3))
		theme.set_type_variation(UiTheme.THIN_BAR, &"ProgressBar")
		theme.set_stylebox(&"background", UiTheme.THIN_BAR, box(Color(s.outline, 0.5), Color(0, 0, 0, 0), 0, 0, 0, px(2)))
		theme.set_stylebox(&"fill", UiTheme.THIN_BAR, glow(box(a, Color(0, 0, 0, 0), 0, 0, 0, px(2)), Color(a, 0.4), px(4)))

		for vertical: bool in [false, true]:
			var type: StringName = &"VSlider" if vertical else &"HSlider"
			var mh: float = px(3) if vertical else 0.0
			var mv: float = 0.0 if vertical else px(3)
			theme.set_stylebox(&"slider", type, box(track_bg, Color(a, 0.3), s.border_width, 0, mh, mv))
			theme.set_stylebox(&"grabber_area", type, glow(box(Color(a, 0.85), Color(0, 0, 0, 0), 0, 0, mh, mv), Color(a, 0.25), px(4)))
			theme.set_stylebox(&"grabber_area_highlight", type, glow(box(a, Color(0, 0, 0, 0), 0, 0, mh, mv), Color(a, 0.4), px(7)))
		# Sliders have no focus style: a focused (or hovered) slider shows grabber_highlight, the
		# bright glowing diamond below.
		var g: float = px(26)
		var diamond: String = '<path d="M13 3 L23 13 L13 23 L3 13 Z" fill="%s" stroke="%s" stroke-width="2"/><circle cx="13" cy="13" r="2.6" fill="%s"/>'
		var scaled: String = '<g transform="scale(%s)">%%s</g>' % (g / 26.0)
		var grabber: Texture2D = svg_texture(scaled % (diamond % [hex(s.outline), hex(a), hex(a)]), g, g)
		var grabber_hl: Texture2D = svg_texture(scaled % (
			'<path d="M13 0.8 L25.2 13 L13 25.2 L0.8 13 Z" fill="%s" fill-opacity="0.3"/>' % hex(a)
			+ diamond % [hex(s.surface.lerp(a, 0.3)), "#ffffff", "#ffffff"]), g, g)
		var grabber_off: Texture2D = svg_texture(scaled % (diamond % [hex(s.outline), hex(s.text_disabled), hex(s.text_disabled)]), g, g)
		for type: StringName in [&"HSlider", &"VSlider"]:
			theme.set_icon(&"grabber", type, grabber)
			theme.set_icon(&"grabber_highlight", type, grabber_hl)
			theme.set_icon(&"grabber_disabled", type, grabber_off)
			theme.set_constant(&"center_grabber", type, 0)

		var bar_w: float = px(4) if not touch else px(5)
		for vertical: bool in [false, true]:
			var type: StringName = &"VScrollBar" if vertical else &"HScrollBar"
			var mh: float = bar_w if vertical else 0.0
			var mv: float = 0.0 if vertical else bar_w
			theme.set_stylebox(&"scroll", type, box(Color(s.outline, 0.35), Color(0, 0, 0, 0), 0, 0, mh, mv))
			theme.set_stylebox(&"scroll_focus", type, box(Color(s.outline, 0.35), Color(a, 0.5), s.border_width, 0, mh, mv))
			theme.set_stylebox(&"grabber", type, box(Color(a, 0.45), Color(0, 0, 0, 0), 0, 0, mh, mv))
			theme.set_stylebox(&"grabber_highlight", type, box(Color(a, 0.75), Color(0, 0, 0, 0), 0, 0, mh, mv))
			theme.set_stylebox(&"grabber_pressed", type, box(a, Color(0, 0, 0, 0), 0, 0, mh, mv))
		theme.set_stylebox(&"panel", &"ScrollContainer", empty())
		theme.set_stylebox(&"focus", &"ScrollContainer", empty())

	# --- Text input ------------------------------------------------------------------

	func inputs() -> void:
		var a: Color = s.accent
		var pad_v: float = maxf(px(4), ((control_h - f_body.get_height(px(s.body_size))) * 0.5))
		var cut: int = px(6)
		var normal := box(Color(s.outline, 0.7), Color(a, 0.35), s.border_width, cut, px(14), pad_v)
		normal.border_width_bottom = px(2)
		var focus := glow(box(Color(s.outline, 0.8), a, s.border_width, cut, px(14), pad_v), Color(a, 0.35), px(8))
		focus.border_width_bottom = px(2)
		var read_only := box(Color(s.outline, 0.4), Color(s.text_disabled, 0.4), s.border_width, cut, px(14), pad_v)
		for type: StringName in [&"LineEdit", &"TextEdit"]:
			theme.set_stylebox(&"normal", type, normal)
			theme.set_stylebox(&"focus", type, focus)
			theme.set_stylebox(&"read_only", type, read_only)
			theme.set_font(&"font", type, f_body)
			theme.set_font_size(&"font_size", type, px(s.body_size))
			theme.set_color(&"font_color", type, s.text)
			theme.set_color(&"font_placeholder_color", type, Color(s.text_dim, 0.6))
			theme.set_color(&"font_readonly_color", type, s.text_dim)
			theme.set_color(&"font_uneditable_color", type, s.text_dim)
			theme.set_color(&"font_selected_color", type, Color.WHITE)
			theme.set_color(&"selection_color", type, Color(a, 0.35))
			theme.set_color(&"caret_color", type, a.lerp(Color.WHITE, 0.3))
			theme.set_color(&"clear_button_color", type, s.text_dim)
			theme.set_color(&"clear_button_color_pressed", type, a)
			theme.set_constant(&"caret_width", type, px(2))

	# --- Popups, menus, option buttons --------------------------------------------------

	func popups() -> void:
		var a: Color = s.accent
		var popup := glow(box(Color(s.panel, 0.98), Color(a, 0.7), s.border_width, px(8), px(8), px(8)), Color(0, 0, 0, 0.5), px(10))
		theme.set_stylebox(&"panel", &"PopupPanel", popup)
		theme.set_stylebox(&"panel", &"PopupMenu", popup)
		theme.set_stylebox(&"panel", &"AcceptDialog", theme.get_stylebox(&"panel", UiTheme.DIALOG))
		theme.set_stylebox(&"hover", &"PopupMenu", box(Color(a, 0.22), Color(a, 0.6), s.border_width, px(4)))
		theme.set_stylebox(&"separator", &"PopupMenu", line(Color(a, 0.25), false))
		theme.set_stylebox(&"labeled_separator_left", &"PopupMenu", line(Color(a, 0.25), false))
		theme.set_stylebox(&"labeled_separator_right", &"PopupMenu", line(Color(a, 0.25), false))
		theme.set_font(&"font", &"PopupMenu", f_body)
		theme.set_font_size(&"font_size", &"PopupMenu", px(s.body_size))
		theme.set_color(&"font_color", &"PopupMenu", s.text)
		theme.set_color(&"font_hover_color", &"PopupMenu", Color.WHITE)
		theme.set_color(&"font_disabled_color", &"PopupMenu", s.text_disabled)
		theme.set_color(&"font_accelerator_color", &"PopupMenu", s.text_dim)
		theme.set_color(&"font_separator_color", &"PopupMenu", s.accent)
		theme.set_constant(&"v_separation", &"PopupMenu", px(12) if touch else px(8))
		theme.set_constant(&"h_separation", &"PopupMenu", px(10))
		theme.set_constant(&"item_start_padding", &"PopupMenu", px(12))
		theme.set_constant(&"item_end_padding", &"PopupMenu", px(12))
		for icon_name: String in ["checked", "unchecked", "radio_checked", "radio_unchecked"]:
			theme.set_icon(icon_name, &"PopupMenu", theme.get_icon(icon_name, &"CheckBox"))
		theme.set_icon(&"submenu", &"PopupMenu", IconFactory.texture(&"chevron_right", px(16), s.text))
		theme.set_icon(&"submenu_mirrored", &"PopupMenu", IconFactory.texture(&"chevron_left", px(16), s.text))
		var arrow: Texture2D = IconFactory.texture(&"chevron_down", px(18), Color.WHITE)
		theme.set_icon(&"arrow", &"OptionButton", arrow)
		theme.set_constant(&"arrow_margin", &"OptionButton", px(12))
		theme.set_constant(&"modulate_arrow", &"OptionButton", 1)

	# --- Tabs ------------------------------------------------------------------------

	func tabs() -> void:
		var a: Color = s.accent
		var pad_v: float = px(10) if not touch else px(16)
		var selected := box(Color(a, 0.16), a, 0, 0, px(18), pad_v)
		selected.border_width_bottom = px(2)
		var unselected := box(Color(0, 0, 0, 0), Color(a, 0.2), 0, 0, px(18), pad_v)
		unselected.border_width_bottom = px(2)
		unselected.draw_center = false
		var hovered := box(Color(a, 0.08), Color(a, 0.6), 0, 0, px(18), pad_v)
		hovered.border_width_bottom = px(2)
		for type: StringName in [&"TabContainer", &"TabBar"]:
			theme.set_stylebox(&"tab_selected", type, selected)
			theme.set_stylebox(&"tab_unselected", type, unselected)
			theme.set_stylebox(&"tab_hovered", type, hovered)
			theme.set_stylebox(&"tab_disabled", type, unselected)
			theme.set_stylebox(&"tab_focus", type, focus_box(0))
			theme.set_font(&"font", type, f_display)
			theme.set_font_size(&"font_size", type, px(s.subheading_size))
			# Scroll arrows when the tabs don't fit.
			theme.set_icon(&"increment", type, IconFactory.texture(&"chevron_right", px(18), s.text_dim))
			theme.set_icon(&"increment_highlight", type, IconFactory.texture(&"chevron_right", px(18), s.accent))
			theme.set_icon(&"decrement", type, IconFactory.texture(&"chevron_left", px(18), s.text_dim))
			theme.set_icon(&"decrement_highlight", type, IconFactory.texture(&"chevron_left", px(18), s.accent))
			theme.set_color(&"font_selected_color", type, Color.WHITE)
			theme.set_color(&"font_hovered_color", type, s.text)
			theme.set_color(&"font_unselected_color", type, s.text_dim)
			theme.set_color(&"font_disabled_color", type, s.text_disabled)
			theme.set_constant(&"h_separation", type, px(4))
		theme.set_stylebox(&"panel", &"TabContainer", box(s.panel, Color(a, 0.3), s.border_width, 0, px(18), px(16)))
		theme.set_stylebox(&"tabbar_background", &"TabContainer", empty())

	# --- Containers --------------------------------------------------------------------

	func containers() -> void:
		var gap: int = px(s.spacing)
		for type: StringName in [&"BoxContainer", &"HBoxContainer", &"VBoxContainer"]:
			theme.set_constant(&"separation", type, gap)
		for type: StringName in [&"GridContainer", &"FlowContainer", &"HFlowContainer", &"VFlowContainer"]:
			theme.set_constant(&"h_separation", type, gap)
			theme.set_constant(&"v_separation", type, gap)

	# --- Custom widgets --------------------------------------------------------------------

	func widgets() -> void:
		var a: Color = s.accent
		var n: StringName = UiTheme.NEON
		theme.set_constant(&"control_height", n, control_h)
		theme.set_constant(&"icon_size", n, px(s.icon_size))
		theme.set_constant(&"spacing", n, px(s.spacing))
		theme.set_constant(&"margin", n, px(s.screen_margin))
		theme.set_constant(&"touch", n, 1 if touch else 0)
		for c: Array in [["accent", a], ["accent_2", s.accent_2], ["text", s.text], ["text_dim", s.text_dim],
				["text_disabled", s.text_disabled], ["danger", s.danger], ["surface", s.surface],
				["panel", s.panel], ["outline", s.outline], ["star", s.star],
				["backdrop_top", s.backdrop_top], ["backdrop_bottom", s.backdrop_bottom]]:
			theme.set_color(c[0], n, c[1])
		for i: int in IconFactory.DENOMINATIONS.size():
			var color: Color = s.credit_colors[i] if i < s.credit_colors.size() else s.text
			theme.set_color("credit_%d" % IconFactory.DENOMINATIONS[i], n, color)
		theme.set_stylebox(&"focus", n, focus_box(px(s.corner_cut)))

		var t: StringName = &"CreditCounter"
		theme.set_font(&"font", t, f_display)
		theme.set_font_size(&"font_size", t, px(s.value_size))
		theme.set_color(&"font_color", t, s.text)
		theme.set_color(&"font_gain_color", t, a.lerp(Color.WHITE, 0.35))
		theme.set_color(&"font_outline_color", t, s.outline)
		theme.set_constant(&"outline_size", t, 0)
		theme.set_constant(&"icon_size", t, px(s.value_size + 4))
		theme.set_constant(&"separation", t, px(8))
		theme.set_stylebox(&"chip", t, box(Color(s.outline, 0.55), Color(a, 0.3), s.border_width, px(8), px(12), px(5)))

		t = &"StarRow"
		theme.set_color(&"star_on", t, s.star)
		theme.set_color(&"star_off", t, Color(s.text_disabled, 0.9))
		theme.set_color(&"glow", t, Color(a, 0.45))
		theme.set_constant(&"star_size", t, px(40))
		theme.set_constant(&"separation", t, px(10))

		t = &"ProgressMeter"
		theme.set_color(&"track", t, Color(s.outline, 0.6))
		theme.set_color(&"track_border", t, Color(a, 0.3))
		theme.set_color(&"fill", t, a)
		theme.set_color(&"glow", t, Color(a, 0.3))
		theme.set_color(&"marker", t, Color(s.text, 0.6))
		theme.set_color(&"marker_passed", t, a.lerp(Color.WHITE, 0.25))
		theme.set_color(&"head", t, Color.WHITE)
		theme.set_constant(&"thickness", t, px(6))
		theme.set_constant(&"marker_size", t, px(10))
		theme.set_constant(&"height", t, px(24))

		t = &"CooldownIcon"
		theme.set_color(&"disc", t, Color(s.outline, 0.62))
		theme.set_color(&"ring", t, Color(a, 0.25))
		theme.set_color(&"progress", t, a)
		theme.set_color(&"ready", t, a.lerp(Color.WHITE, 0.2))
		theme.set_color(&"sweep", t, Color(0.0, 0.0, 0.02, 0.62))
		theme.set_color(&"icon", t, s.text)
		theme.set_color(&"icon_cooling", t, Color(s.text_dim, 0.85))
		theme.set_color(&"flash", t, Color.WHITE)
		theme.set_color(&"badge", t, a)
		theme.set_color(&"badge_text", t, s.backdrop_bottom)
		theme.set_color(&"hint", t, s.text)
		theme.set_color(&"hint_outline", t, s.outline)
		theme.set_font(&"font", t, f_digits)
		theme.set_font_size(&"font_size", t, px(15))
		theme.set_constant(&"size", t, px(60))
		theme.set_constant(&"ring_width", t, px(3))

		t = &"ToggleSwitch"
		theme.set_color(&"track_off", t, Color(s.outline, 0.85))
		theme.set_color(&"track_on", t, s.surface.lerp(a, 0.45))
		theme.set_color(&"border_off", t, Color(s.text_dim, 0.8))
		theme.set_color(&"border_on", t, a)
		theme.set_color(&"knob_off", t, s.text_dim)
		theme.set_color(&"knob_on", t, Color.WHITE)
		theme.set_color(&"glow", t, Color(a, 0.35))
		theme.set_color(&"disabled", t, s.text_disabled)
		theme.set_constant(&"width", t, px(52))
		theme.set_constant(&"height", t, px(28))

		t = &"ItemCard"
		theme.set_constant(&"width", t, px(280))
		theme.set_constant(&"icon_size", t, px(46))
		theme.set_color(&"pip_on", t, a)
		theme.set_color(&"pip_next", t, Color(a, 0.5))
		theme.set_color(&"pip_off", t, Color(s.text_disabled, 0.7))
		theme.set_stylebox(&"icon_frame", t, box(Color(s.outline, 0.65), Color(a, 0.35), s.border_width, px(8), px(8), px(8)))

		t = &"KeyBindButton"
		theme.set_color(&"listening", t, s.accent_2)
		theme.set_constant(&"min_width", t, px(150))

		t = &"ScreenBase"
		theme.set_color(&"grid", t, Color(a, 0.09))
		theme.set_color(&"horizon", t, Color(s.accent_2, 0.35))
		theme.set_color(&"dim", t, Color(0.0, 0.0, 0.02, 0.66))

	# --- HUD flavour -----------------------------------------------------------------

	## The HUD theme: the defaults become the HUD variants, so any control or kit widget placed
	## under a HUD root takes the lighter look without per-control changes.
	func hud_defaults() -> void:
		copy_type(UiTheme.HUD_TEXT, &"Label")
		copy_type(UiTheme.HUD_VALUE, UiTheme.VALUE)
		copy_type(UiTheme.HUD_CAPTION, UiTheme.CAPTION)
		copy_type(UiTheme.HUD_PANEL, &"PanelContainer")
		copy_type(UiTheme.HUD_PANEL, &"Panel")
		copy_type(UiTheme.HUD_BUTTON, &"Button")
		copy_type(UiTheme.THIN_BAR, &"ProgressBar")
		theme.set_stylebox(&"chip", &"CreditCounter", box(Color(s.outline, 0.4), Color(0, 0, 0, 0), 0, px(8), px(10), px(4)))
		theme.set_constant(&"outline_size", &"CreditCounter", px(5))
		theme.set_font_size(&"font_size", &"CreditCounter", px(s.hud_value_size - 4))
		theme.set_constant(&"icon_size", &"CreditCounter", px(s.hud_value_size))
		theme.set_color(&"track", &"ProgressMeter", Color(s.outline, 0.5))
		theme.set_color(&"track_border", &"ProgressMeter", Color(1, 1, 1, 0.12))

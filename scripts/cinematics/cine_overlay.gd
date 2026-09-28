class_name CineOverlay
extends CanvasLayer
## A cinematic's 2D layer (CinematicSequencer): the letterbox bars, fades, flashes, text cards and the
## skip button, on the menus' theme (Orbitron titles, Exo 2 text) inside the screen's safe area.
## Reduced flashing (Settings.flashing_reduced) turns a flash into a slow, faint glow; nothing here
## blinks.

## The skip button was pressed.
signal skip_pressed

## Above the world, under the App's screens (10) and overlays (20).
const LAYER: int = 12
## DESIGN-TBD (docs/questions/f1.md 6): each letterbox bar's height, as a share of the screen's height.
const BAR_SHARE: float = 0.1
## A flash with Reduced flashing: at most this bright, and never quicker than this.
const SOFT_FLASH_ALPHA: float = 0.25
const SOFT_FLASH_MIN_TIME: float = 0.8
## The text card: how long it takes to come in and to go, its title's size (desktop pixels, scaled on
## touch screens) and where its middle sits, as a share of the screen's height.
const CARD_FADE: float = 0.5
const CARD_TITLE_SIZE: int = 58
const CARD_CAPTION_SIZE: int = 22
const CARD_CENTER: float = 0.56
## DESIGN-TBD (docs/questions/f1.md 4): the skip button's resting look, until the pointer comes near it.
const SKIP_DIM: float = 0.6
## Seconds before the skip button shows, so the first frames stay clean.
const SKIP_DELAY: float = 0.4

var root: Control
var top_bar: ColorRect
var bottom_bar: ColorRect
var fade_rect: ColorRect
var flash_rect: ColorRect
var card: VBoxContainer
var card_caption: Label
var card_title: Label
var card_line: ColorRect
var skip_button: NeonButton
## The letterbox bars: 0 down, 1 up.
var letterbox: float = 0.0

var _bars_tween: Tween
var _fade_tween: Tween
var _flash_tween: Tween
var _card_tween: Tween


func _ready() -> void:
	layer = LAYER
	root = Control.new()
	root.name = "CineRoot"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiTheme.apply(root, true)
	add_child(root)
	var s: UiStyle = UiTheme.style()

	fade_rect = _rect("Fade", Color(0.0, 0.0, 0.0, 0.0))
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_rect = _rect("Flash", Color(1.0, 1.0, 1.0, 0.0))
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top_bar = _rect("TopBar", Color.BLACK)
	bottom_bar = _rect("BottomBar", Color.BLACK)

	card = VBoxContainer.new()
	card.name = "Card"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_theme_constant_override(&"separation", roundi(UiTheme.px(6)))
	card.modulate.a = 0.0
	root.add_child(card)
	card_caption = Label.new()
	card_caption.theme_type_variation = UiTheme.SUBHEADING
	card_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_caption.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	card_caption.add_theme_font_size_override(&"font_size", roundi(UiTheme.px(CARD_CAPTION_SIZE)))
	card_caption.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	card_caption.add_theme_constant_override(&"outline_size", roundi(UiTheme.px(6)))
	card.add_child(card_caption)
	card_title = Label.new()
	card_title.theme_type_variation = UiTheme.TITLE
	card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	card_title.add_theme_font_size_override(&"font_size", roundi(UiTheme.px(CARD_TITLE_SIZE)))
	card_title.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	card_title.add_theme_constant_override(&"outline_size", roundi(UiTheme.px(8)))
	card.add_child(card_title)
	card_line = ColorRect.new()
	card_line.name = "Line"
	card_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_line.color = s.accent
	card_line.custom_minimum_size = Vector2(UiTheme.px(320), maxf(2.0, UiTheme.px(2)))
	card_line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card_line.pivot_offset = card_line.custom_minimum_size * 0.5
	card.add_child(card_line)

	var key: String = UiTheme.action_text(&"pause")
	skip_button = NeonButton.make("SKIP" if key == "" or UiTheme.is_touch() else "SKIP  ·  %s" % key,
		NeonButton.Kind.HUD, &"chevron_right")
	skip_button.name = "Skip"
	skip_button.focus_mode = Control.FOCUS_NONE
	skip_button.tooltip_text = "Skip the cinematic"
	skip_button.modulate.a = 0.0
	skip_button.visible = false
	skip_button.pressed.connect(func() -> void: skip_pressed.emit())
	skip_button.mouse_entered.connect(func() -> void: _set_skip_alpha(1.0))
	skip_button.mouse_exited.connect(func() -> void: _set_skip_alpha(SKIP_DIM))
	root.add_child(skip_button)
	get_tree().create_timer(SKIP_DELAY, false).timeout.connect(_show_skip)

	root.resized.connect(_layout)
	_layout()


## Raises (or lowers) the letterbox bars over `seconds` (0: at once).
func set_letterbox(on: bool, seconds: float = 0.0) -> void:
	if _bars_tween != null:
		_bars_tween.kill()
	var target: float = 1.0 if on else 0.0
	if seconds <= 0.0:
		_set_bars(target)
		return
	_bars_tween = create_tween()
	_bars_tween.tween_method(_set_bars, letterbox, target, seconds).set_trans(Tween.TRANS_SINE)


## Fades the picture toward `color` at `alpha` (1: fully covered, 0: clear) over `seconds`, from
## `from` (below 0: from where the fade is now).
func fade_to(alpha: float, seconds: float, color: Color = Color.BLACK, from: float = -1.0) -> void:
	if _fade_tween != null:
		_fade_tween.kill()
	var start: float = from if from >= 0.0 else fade_rect.color.a
	fade_rect.color = Color(color, start)
	if seconds <= 0.0:
		fade_rect.color.a = alpha
		return
	_fade_tween = create_tween()
	_fade_tween.tween_property(fade_rect, "color:a", alpha, seconds).set_trans(Tween.TRANS_SINE)


## A flash of `color`, `strength` (0-1) at its brightest, fading over `seconds`. With Reduced flashing it
## is a slow, faint glow instead (at most SOFT_FLASH_ALPHA, rising and falling over at least
## SOFT_FLASH_MIN_TIME), so nothing strobes.
func flash(strength: float, seconds: float, color: Color = Color.WHITE) -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	var peak: float = clampf(strength, 0.0, 1.0)
	_flash_tween = create_tween()
	if Settings.flashing_reduced:
		var span: float = maxf(seconds, SOFT_FLASH_MIN_TIME)
		flash_rect.color = Color(color, 0.0)
		_flash_tween.tween_property(flash_rect, "color:a", minf(peak, SOFT_FLASH_ALPHA), span * 0.4) \
			.set_trans(Tween.TRANS_SINE)
		_flash_tween.tween_property(flash_rect, "color:a", 0.0, span * 0.6).set_trans(Tween.TRANS_SINE)
		return
	flash_rect.color = Color(color, peak)
	_flash_tween.tween_property(flash_rect, "color:a", 0.0, maxf(seconds, 0.05)).set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)


## Shows a text card: `title` large, `caption` above it (may be empty), in capitals like the menus'
## titles, for `seconds`, fading in and out, the line under it opening from the middle.
func show_card(title: String, caption: String, seconds: float) -> void:
	# The text comes translated (CinematicSequencer.fill_text); the labels don't translate the capitals.
	card_title.text = title.to_upper()
	card_caption.text = caption.to_upper()
	card_caption.visible = caption != ""
	if _card_tween != null:
		_card_tween.kill()
	var fade: float = minf(CARD_FADE, seconds * 0.3)
	card.modulate.a = 0.0
	card_line.scale = Vector2(0.0, 1.0)
	_card_tween = create_tween()
	_card_tween.tween_property(card, "modulate:a", 1.0, fade).set_trans(Tween.TRANS_SINE)
	_card_tween.parallel().tween_property(card_line, "scale:x", 1.0, fade * 1.6).set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)
	_card_tween.tween_interval(maxf(seconds - 2.0 * fade, 0.0))
	_card_tween.tween_property(card, "modulate:a", 0.0, fade).set_trans(Tween.TRANS_SINE)
	_layout.call_deferred()


## True while a text card is up (or coming in or going).
func card_showing() -> bool:
	return card.modulate.a > 0.001


## How covered the picture is by the fade now (0-1).
func fade_alpha() -> float:
	return fade_rect.color.a


## How bright the flash is now (0-1).
func flash_alpha() -> float:
	return flash_rect.color.a


func _show_skip() -> void:
	if not is_instance_valid(skip_button):
		return
	skip_button.visible = true
	_set_skip_alpha(SKIP_DIM)


func _set_skip_alpha(alpha: float) -> void:
	skip_button.create_tween().tween_property(skip_button, "modulate:a", alpha, 0.25)


func _set_bars(value: float) -> void:
	letterbox = value
	_layout()


func _rect(rect_name: String, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.name = rect_name
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(r)
	return r


## Places the bars, the card and the skip button for the screen's size and safe area.
func _layout() -> void:
	if root == null or not root.is_inside_tree():
		return
	var size: Vector2 = root.size
	var bar: float = roundf(size.y * BAR_SHARE * letterbox)
	top_bar.position = Vector2.ZERO
	top_bar.size = Vector2(size.x, bar)
	bottom_bar.position = Vector2(0.0, size.y - bar)
	bottom_bar.size = Vector2(size.x, bar)
	var card_size: Vector2 = card.get_combined_minimum_size()
	card.size = Vector2(size.x, card_size.y)
	card.position = Vector2(0.0, size.y * CARD_CENTER - card_size.y * 0.5)
	card_line.pivot_offset = card_line.size * 0.5
	var safe: Vector4 = UiTheme.safe_area_margins(root)
	var margin: float = UiTheme.px(16)
	var button: Vector2 = skip_button.get_combined_minimum_size()
	skip_button.size = button
	# In the bottom bar's right end when the bars are up, otherwise in the corner.
	var bottom: float = size.y - safe.w - margin - button.y
	if bar > button.y + margin:
		bottom = size.y - bar + (bar - button.y) * 0.5
	skip_button.position = Vector2(size.x - safe.z - margin - button.x, bottom)

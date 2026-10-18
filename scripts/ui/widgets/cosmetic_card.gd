class_name CosmeticCard
extends PanelContainer
## A cosmetic in the shop (GDD §8, "Cosmetics"): an outfit for the runner, bought once with credits and
## kept forever, then worn or taken off. Its picture is a preview of the outfit, the runner wearing it
## (OutfitPreview; owner, October 18, 2026, item 982), where an item's card has its icon. It looks like an ItemCard
## (the same card, title, caption and button, WIDTH_FACTOR times as wide to give the preview its room) with one button that
## changes with its state, so the focus never has to move:
##   AVAILABLE    price <= credits: the price button buys it
##   CANT_AFFORD  price > credits: the price button is disabled, the caption says why (in red)
##   OWNED        bought, not worn: WEAR
##   WORN         worn: TAKE OFF puts Razor Echo's own look back on (his own card can't be taken off)
## The shop fills cards from its catalog and the profile:
##   card.configure({"cosmetic_id": &"rex", "title": "Rex", "description": "...", "price": 3000,
##       "credits": wallet, "owned": false, "worn": false, "color": Color("#d1198c")})
##   card.buy_pressed.connect(_on_buy)
##   card.wear_pressed.connect(_on_wear)
## The preview is a still of the runner; the shop makes it run and turn (`set_preview_live`) on the one card the pointer
## or the focus is on: `interest_changed` says when this one gains or loses either, `interested` is where it stands.

signal buy_pressed(cosmetic_id: StringName)
## Wear the cosmetic, or take it off: `cosmetic_id` is the outfit to put on, so on a worn card (TAKE OFF) it is
## the default look's id.
signal wear_pressed(cosmetic_id: StringName)
## The pointer or the focus came onto the card or left it (`interested` is the new state).
signal interest_changed(card: CosmeticCard)

enum State { AVAILABLE, CANT_AFFORD, OWNED, WORN }

## How much wider than an item's card (the theme's ItemCard width) a cosmetic's is: the room for the preview beside
## the text.
const WIDTH_FACTOR: float = 1.4
## The description's lines (the text column is narrower than an item's and the longest text takes four; an item's has three).
const DESCRIPTION_LINES: int = 4
## The preview's width as a fraction of its height (the runner stands tall and narrow).
const PREVIEW_ASPECT: float = 0.7

## Keys configure() accepts.
const FIELDS: Array[String] = ["cosmetic_id", "default_id", "title", "description", "price", "credits", "owned",
	"worn", "color", "note"]

var cosmetic_id: StringName = &""
## The id of the free default look: a card with this id is always owned and can't be taken off.
var default_id: StringName = &"echo"
var title: String = ""
var description: String = ""
var price: int = 0
var credits: int = 0
var owned: bool = false
var worn: bool = false
## The outfit's main colour (the catalog's). The preview shows the outfit itself, so nothing on the card is drawn in it now;
## it is kept with the card's data.
var color: Color = Color.WHITE
## A line for the caption when there is nothing else to say (an outfit whose look isn't finished).
var note: String = ""

var state: State = State.AVAILABLE
## True while the pointer is over the card or the focus is in it.
var interested: bool = false
var preview_frame: PanelContainer
var preview: OutfitPreview
var title_label: Label
var status_label: Label
var description_label: Label
var action_button: NeonButton
var _bottom: HBoxContainer
var _heading: VBoxContainer
var _text: VBoxContainer
var _hovered: bool = false
var _focused: bool = false
## The id the preview was dressed for (refresh() dresses it again only when the card's cosmetic changes).
var _previewed: StringName = &""
var _metrics_queued: bool = false


func _init() -> void:
	theme_type_variation = UiTheme.CARD
	var column := VBoxContainer.new()
	add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	preview_frame = PanelContainer.new()
	preview_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(preview_frame)
	preview = OutfitPreview.new()
	preview_frame.add_child(preview)
	_text = VBoxContainer.new()
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_text)
	_heading = VBoxContainer.new()
	_heading.add_theme_constant_override(&"separation", 4)
	_text.add_child(_heading)
	title_label = Label.new()
	title_label.theme_type_variation = UiTheme.CARD_TITLE
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.resized.connect(_fit_title)
	_heading.add_child(title_label)
	status_label = Label.new()
	status_label.theme_type_variation = UiTheme.CAPTION
	_heading.add_child(status_label)
	description_label = Label.new()
	description_label.theme_type_variation = UiTheme.CAPTION
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.max_lines_visible = DESCRIPTION_LINES
	description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_child(description_label)
	_bottom = HBoxContainer.new()
	_bottom.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(_bottom)
	action_button = NeonButton.make("", NeonButton.Kind.PRICE)
	action_button.pressed.connect(_on_action)
	_bottom.add_child(action_button)
	mouse_entered.connect(_on_pointer.bind(true))
	mouse_exited.connect(_on_pointer.bind(false))
	action_button.focus_entered.connect(_set_interest.bind(true))
	action_button.focus_exited.connect(_set_interest.bind(false))
	refresh()


## Sets several fields at once (keys from FIELDS; others are ignored) and refreshes.
func configure(data: Dictionary) -> void:
	for key: Variant in data:
		if FIELDS.has(String(key)):
			set(String(key), data[key])
	refresh()


## The state the fields add up to.
func compute_state() -> State:
	if worn:
		return State.WORN
	if owned or cosmetic_id == default_id:
		return State.OWNED
	return State.AVAILABLE if price <= credits else State.CANT_AFFORD


func refresh() -> void:
	state = compute_state()
	if title_label.text != title:
		title_label.text = title
		_fit_title()
	description_label.text = description
	if _previewed != cosmetic_id:
		_previewed = cosmetic_id
		preview.outfit_id = cosmetic_id
	var is_default: bool = cosmetic_id == default_id
	match state:
		State.AVAILABLE, State.CANT_AFFORD:
			action_button.kind = NeonButton.Kind.PRICE
			action_button.text = UiTheme.format_int(price)
			action_button.icon_name = IconFactory.credit_icon(1)
			action_button.icon_color = UiTheme.credit_color(1)
			action_button.disabled = state == State.CANT_AFFORD
			action_button.tooltip_text = "Buy"
		State.OWNED:
			action_button.kind = NeonButton.Kind.NORMAL
			action_button.text = "WEAR"
			action_button.icon_name = &"outfit"
			action_button.icon_color = Color(0, 0, 0, 0)
			action_button.disabled = false
			action_button.tooltip_text = "Wear it from now on"
		State.WORN:
			action_button.kind = NeonButton.Kind.NORMAL
			action_button.text = "WORN" if is_default else "TAKE OFF"
			action_button.icon_name = &"check" if is_default else &"back"
			action_button.icon_color = Color(0, 0, 0, 0)
			action_button.disabled = is_default
			action_button.tooltip_text = "" if is_default else "Go back to Razor Echo's own look"
	match state:
		State.WORN:
			_status("WORN", UiTheme.ACCENT_CAPTION)
		State.OWNED:
			_status("OWNED", UiTheme.ACCENT_CAPTION)
		State.CANT_AFFORD:
			_status("NOT ENOUGH CREDITS", UiTheme.DANGER_CAPTION)
		State.AVAILABLE:
			_status(note, UiTheme.CAPTION)


func _status(text: String, variation: StringName) -> void:
	status_label.text = text
	status_label.theme_type_variation = variation
	status_label.visible = text != ""


func _on_action() -> void:
	match state:
		State.AVAILABLE:
			buy_pressed.emit(cosmetic_id)
		State.OWNED:
			wear_pressed.emit(cosmetic_id)
		State.WORN:
			wear_pressed.emit(default_id)


## The shop makes the preview of the card the pointer or the focus is on run and turn, and the others stand still.
func set_preview_live(on: bool) -> void:
	preview.set_live(on)


func _on_pointer(inside: bool) -> void:
	_hovered = inside
	_update_interest()


func _set_interest(focused: bool) -> void:
	_focused = focused
	_update_interest()


func _update_interest() -> void:
	var now: bool = _hovered or _focused
	if now != interested:
		interested = now
		interest_changed.emit(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		UiTheme.ensure_later(self)
	elif what == NOTIFICATION_THEME_CHANGED and not _metrics_queued:
		# Deferred: a parent hears about a theme change before its children get the new theme,
		# and the sizes below come from the children's fonts.
		_metrics_queued = true
		_update_metrics.call_deferred()


func _update_metrics() -> void:
	_metrics_queued = false
	custom_minimum_size.x = roundf(get_theme_constant(&"width", &"ItemCard") * WIDTH_FACTOR)
	# The button row is as tall as an item card's, in every state.
	_bottom.custom_minimum_size.y = get_theme_constant(&"control_height", UiTheme.NEON)
	var title_h: float = get_theme_font(&"font", UiTheme.CARD_TITLE).get_height(get_theme_font_size(&"font_size", UiTheme.CARD_TITLE))
	var status_h: float = status_label.get_theme_font(&"font").get_height(status_label.get_theme_font_size(&"font_size"))
	# As tall as an item card's heading (its tier pips are 10 px), so a row of both lines up.
	_heading.custom_minimum_size.y = ceilf(title_h + status_h + 10.0 + 8.0)
	var font: Font = description_label.get_theme_font(&"font")
	var font_size: int = description_label.get_theme_font_size(&"font_size")
	var line: float = font.get_height(font_size) + description_label.get_theme_constant(&"line_spacing")
	description_label.custom_minimum_size.y = ceilf(line * float(DESCRIPTION_LINES))
	# The preview is as tall as the text beside it (the heading and the description), in a frame like an icon's with
	# less room inside, so the card is no taller than an item's.
	var text_h: float = _heading.custom_minimum_size.y + description_label.custom_minimum_size.y \
		+ float(_text.get_theme_constant(&"separation"))
	var frame: StyleBox = get_theme_stylebox(&"icon_frame", &"ItemCard")
	var margin: float = roundf(UiTheme.px(3))
	if frame is StyleBoxFlat:
		frame = frame.duplicate()
		for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			(frame as StyleBoxFlat).set_content_margin(side, margin)
	preview_frame.add_theme_stylebox_override(&"panel", frame)
	var inner_h: float = text_h - 2.0 * margin
	preview.custom_minimum_size = Vector2(roundf(inner_h * PREVIEW_ASPECT), inner_h)


## Long names shrink a little to fit rather than lose their end.
func _fit_title() -> void:
	UiTheme.fit_font(title_label, get_theme_font(&"font", UiTheme.CARD_TITLE), get_theme_font_size(&"font_size", UiTheme.CARD_TITLE))

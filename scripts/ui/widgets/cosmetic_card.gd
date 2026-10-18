class_name CosmeticCard
extends PanelContainer
## A cosmetic in the shop (GDD §8, "Cosmetics"): an outfit for the runner, bought once with credits and
## kept forever, then worn or taken off. DESIGN-TBD: its icon is a jacket in the outfit's colour, not a
## preview of the outfit (`docs/OPEN_QUESTIONS*.md` item 982). It looks like an ItemCard (the same card, icon, title, caption
## and button) with one button that changes with its state, so the focus never has to move:
##   AVAILABLE    price <= credits: the price button buys it
##   CANT_AFFORD  price > credits: the price button is disabled, the caption says why (in red)
##   OWNED        bought, not worn: WEAR
##   WORN         worn: TAKE OFF puts Razor Echo's own look back on (his own card can't be taken off)
## The shop fills cards from its catalog and the profile:
##   card.configure({"cosmetic_id": &"rex", "title": "Rex", "description": "...", "price": 3000,
##       "credits": wallet, "owned": false, "worn": false, "color": Color("#d1198c")})
##   card.buy_pressed.connect(_on_buy)
##   card.wear_pressed.connect(_on_wear)

signal buy_pressed(cosmetic_id: StringName)
## Wear the cosmetic, or take it off: `cosmetic_id` is the outfit to put on, so on a worn card (TAKE OFF) it is
## the default look's id.
signal wear_pressed(cosmetic_id: StringName)

enum State { AVAILABLE, CANT_AFFORD, OWNED, WORN }

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
## The outfit's main colour: its icon's.
var color: Color = Color.WHITE
## A line for the caption when there is nothing else to say (an outfit whose look isn't finished).
var note: String = ""

var state: State = State.AVAILABLE
var icon_frame: PanelContainer
var icon: NeonIcon
var title_label: Label
var status_label: Label
var description_label: Label
var action_button: NeonButton
var _bottom: HBoxContainer
var _heading: VBoxContainer
var _metrics_queued: bool = false


func _init() -> void:
	theme_type_variation = UiTheme.CARD
	var column := VBoxContainer.new()
	add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	icon_frame = PanelContainer.new()
	icon_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(icon_frame)
	icon = NeonIcon.new()
	icon.icon_name = &"outfit"
	icon_frame.add_child(icon)
	_heading = VBoxContainer.new()
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_heading.add_theme_constant_override(&"separation", 4)
	top.add_child(_heading)
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
	description_label.max_lines_visible = 3
	description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(description_label)
	_bottom = HBoxContainer.new()
	_bottom.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(_bottom)
	action_button = NeonButton.make("", NeonButton.Kind.PRICE)
	action_button.pressed.connect(_on_action)
	_bottom.add_child(action_button)
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
	icon.color = color
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
	custom_minimum_size.x = get_theme_constant(&"width", &"ItemCard")
	# The same height as an item card's, in every state.
	_bottom.custom_minimum_size.y = get_theme_constant(&"control_height", UiTheme.NEON)
	var icon_px: float = get_theme_constant(&"icon_size", &"ItemCard")
	icon.icon_size = icon_px
	icon_frame.add_theme_stylebox_override(&"panel", get_theme_stylebox(&"icon_frame", &"ItemCard"))
	var title_h: float = get_theme_font(&"font", UiTheme.CARD_TITLE).get_height(get_theme_font_size(&"font_size", UiTheme.CARD_TITLE))
	var status_h: float = status_label.get_theme_font(&"font").get_height(status_label.get_theme_font_size(&"font_size"))
	# As tall as an item card's heading (its tier pips are 10 px), so a row of both lines up.
	_heading.custom_minimum_size.y = ceilf(title_h + status_h + 10.0 + 8.0)
	var font: Font = description_label.get_theme_font(&"font")
	var font_size: int = description_label.get_theme_font_size(&"font_size")
	var line: float = font.get_height(font_size) + description_label.get_theme_constant(&"line_spacing")
	description_label.custom_minimum_size.y = ceilf(line * 3.0)


## Long names shrink a little to fit rather than lose their end.
func _fit_title() -> void:
	UiTheme.fit_font(title_label, get_theme_font(&"font", UiTheme.CARD_TITLE), get_theme_font_size(&"font_size", UiTheme.CARD_TITLE))

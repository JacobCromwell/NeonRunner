class_name ItemCard
extends PanelContainer
## A shop item: icon, name, short description, tier pips, price with a buy button, and an
## equip toggle once owned. Its state follows from the fields:
##   LOCKED       locked (reason shown instead of a price)
##   OWNED/MAXED  tier >= max_tier (single items: owned; tiered items: all tiers bought)
##   AVAILABLE    price <= credits (tiered items already owned show UPGRADE)
##   CANT_AFFORD  price > credits (the price shows in red, the button is disabled)
## The shop fills cards from its catalog and wallet (the contract is the orchestrator's):
##   card.configure({"item_id": &"shield", "icon_name": &"shield", "title": "Shield",
##       "description": "Blocks one hit of anything.", "price": 400, "credits": wallet})
##   card.buy_pressed.connect(_on_buy)

signal buy_pressed(item_id: StringName)
signal equip_toggled(item_id: StringName, equipped: bool)

enum State { AVAILABLE, CANT_AFFORD, OWNED, MAXED, LOCKED }

## Keys configure() accepts.
const FIELDS: Array[String] = ["item_id", "icon_name", "title", "description", "price", "tier",
	"max_tier", "equipped", "locked", "locked_reason", "credits"]

@export var item_id: StringName = &""
@export var icon_name: StringName = &"shield":
	set(v):
		icon_name = v
		_refresh_later()
@export var title: String = "":
	set(v):
		title = v
		_refresh_later()
@export_multiline var description: String = "":
	set(v):
		description = v
		_refresh_later()
## Price of the next purchase (the next tier, for tiered items).
@export var price: int = 0:
	set(v):
		price = v
		_refresh_later()
## Tiers owned: 0 = not owned. Single items use max_tier = 1.
@export var tier: int = 0:
	set(v):
		tier = v
		_refresh_later()
## Tier count; above 1 shows pips (the weapon line has 4, GDD §8).
@export_range(1, 8, 1) var max_tier: int = 1:
	set(v):
		max_tier = v
		_refresh_later()
## The equip toggle's state (owned items only; GDD §8 equip toggle).
@export var equipped: bool = true:
	set(v):
		equipped = v
		_refresh_later()
@export var locked: bool = false:
	set(v):
		locked = v
		_refresh_later()
@export var locked_reason: String = "":
	set(v):
		locked_reason = v
		_refresh_later()
## The player's wallet, for the can't-afford state.
@export var credits: int = 0:
	set(v):
		credits = v
		_refresh_later()

var state: State = State.AVAILABLE
var icon_frame: PanelContainer
var icon: NeonIcon
var lock_icon: NeonIcon
var title_label: Label
var status_label: Label
var description_label: Label
var pips: TierPips
var equip_switch: ToggleSwitch
var equip_label: Label
var buy_button: NeonButton
var _bottom: HBoxContainer
var _heading: VBoxContainer
var _refresh_queued: bool = false


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
	icon_frame.add_child(icon)
	lock_icon = NeonIcon.new()
	lock_icon.icon_name = &"lock"
	lock_icon.size_flags_horizontal = Control.SIZE_SHRINK_END
	lock_icon.size_flags_vertical = Control.SIZE_SHRINK_END
	icon_frame.add_child(lock_icon)
	_heading = VBoxContainer.new()
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_heading.add_theme_constant_override(&"separation", 4)
	top.add_child(_heading)
	var heading := _heading
	title_label = Label.new()
	title_label.theme_type_variation = UiTheme.CARD_TITLE
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	heading.add_child(title_label)
	pips = TierPips.new()
	heading.add_child(pips)
	status_label = Label.new()
	status_label.theme_type_variation = UiTheme.CAPTION
	heading.add_child(status_label)
	description_label = Label.new()
	description_label.theme_type_variation = UiTheme.CAPTION
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.max_lines_visible = 3
	description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(description_label)
	_bottom = HBoxContainer.new()
	_bottom.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(_bottom)
	equip_switch = ToggleSwitch.new()
	equip_switch.toggled.connect(_on_equip_toggled)
	_bottom.add_child(equip_switch)
	equip_label = Label.new()
	equip_label.theme_type_variation = UiTheme.CAPTION
	equip_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bottom.add_child(equip_label)
	buy_button = NeonButton.make("", NeonButton.Kind.PRICE)
	buy_button.pressed.connect(func() -> void: buy_pressed.emit(item_id))
	_bottom.add_child(buy_button)
	refresh()


## Sets several fields at once (keys from FIELDS; others are ignored) and refreshes.
func configure(data: Dictionary) -> void:
	for key: Variant in data:
		if FIELDS.has(String(key)):
			set(String(key), data[key])
	refresh()


## The state the fields add up to.
func compute_state() -> State:
	if locked:
		return State.LOCKED
	if tier >= max_tier:
		return State.MAXED if max_tier > 1 else State.OWNED
	return State.AVAILABLE if price <= credits else State.CANT_AFFORD


func is_owned() -> bool:
	return tier > 0


func refresh() -> void:
	_refresh_queued = false
	state = compute_state()
	var owned: bool = is_owned() and not locked
	icon.icon_name = icon_name
	title_label.text = title
	description_label.text = description
	pips.visible = max_tier > 1
	pips.tiers = max_tier
	pips.owned = tier
	lock_icon.visible = state == State.LOCKED
	equip_switch.visible = owned
	equip_label.visible = owned
	equip_switch.set_on(equipped, is_inside_tree())
	equip_label.text = "EQUIPPED" if equipped else "OFF"
	buy_button.visible = state == State.AVAILABLE or state == State.CANT_AFFORD
	buy_button.disabled = state == State.CANT_AFFORD
	buy_button.text = UiTheme.format_int(price)
	buy_button.icon_name = IconFactory.credit_icon(1)
	buy_button.icon_color = UiTheme.credit_color(1)
	buy_button.tooltip_text = ("Upgrade to tier %d" % (tier + 1)) if owned else "Buy"
	var dim: bool = state == State.LOCKED
	icon.modulate = Color(1, 1, 1, 0.35) if dim else Color.WHITE
	title_label.modulate = Color(1, 1, 1, 0.55) if dim else Color.WHITE
	description_label.modulate = title_label.modulate
	match state:
		State.LOCKED:
			_status(locked_reason if locked_reason != "" else "LOCKED", UiTheme.CAPTION)
		State.OWNED:
			_status("OWNED", UiTheme.ACCENT_CAPTION)
		State.MAXED:
			_status("MAX TIER", UiTheme.ACCENT_CAPTION)
		State.CANT_AFFORD:
			_status("NOT ENOUGH CREDITS", UiTheme.DANGER_CAPTION)
		State.AVAILABLE:
			_status("UPGRADE" if owned else "", UiTheme.ACCENT_CAPTION)


func _status(text: String, variation: StringName) -> void:
	status_label.text = text
	status_label.theme_type_variation = variation
	status_label.visible = text != ""


func _refresh_later() -> void:
	if not _refresh_queued and icon != null:
		_refresh_queued = true
		refresh.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		_ensure_theme.call_deferred()
	elif what == NOTIFICATION_THEME_CHANGED:
		custom_minimum_size.x = get_theme_constant(&"width", &"ItemCard")
		# Same height in every state, even when the bottom row is empty (locked, maxed).
		_bottom.custom_minimum_size.y = get_theme_constant(&"control_height", UiTheme.NEON)
		var icon_px: float = get_theme_constant(&"icon_size", &"ItemCard")
		icon.icon_size = icon_px
		lock_icon.icon_size = roundf(icon_px * 0.45)
		icon_frame.add_theme_stylebox_override(&"panel", get_theme_stylebox(&"icon_frame", &"ItemCard"))
		# The heading keeps room for the pips and the status, so every card is the same height.
		var title_h: float = title_label.get_theme_font(&"font").get_height(title_label.get_theme_font_size(&"font_size"))
		var status_h: float = status_label.get_theme_font(&"font").get_height(status_label.get_theme_font_size(&"font_size"))
		_heading.custom_minimum_size.y = ceilf(title_h + status_h + pips.get_combined_minimum_size().y + 8.0)
		var font: Font = description_label.get_theme_font(&"font")
		var font_size: int = description_label.get_theme_font_size(&"font_size")
		var line: float = font.get_height(font_size) + description_label.get_theme_constant(&"line_spacing")
		description_label.custom_minimum_size.y = ceilf(line * 3.0)


func _ensure_theme() -> void:
	UiTheme.ensure(self)


func _on_equip_toggled(on: bool) -> void:
	equipped = on
	equip_label.text = "EQUIPPED" if on else "OFF"
	equip_toggled.emit(item_id, on)


## The tier pips under the item name: bought tiers lit, the next one outlined.
class TierPips:
	extends Control
	var tiers: int = 4:
		set(v):
			tiers = v
			update_minimum_size()
			queue_redraw()
	var owned: int = 0:
		set(v):
			owned = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _get_minimum_size() -> Vector2:
		return Vector2(tiers * 22.0, 10.0)

	func _draw() -> void:
		var t: StringName = &"ItemCard"
		var h: float = minf(size.y, 10.0)
		var y: float = (size.y - h) * 0.5
		for i: int in tiers:
			var r := Rect2(i * 22.0, y, 18.0, h)
			var cut := PackedVector2Array([r.position + Vector2(3, 0), r.end - Vector2(0, h), r.end - Vector2(3, 0),
				r.position + Vector2(0, h)])
			if i < owned:
				draw_colored_polygon(cut, get_theme_color(&"pip_on", t))
			else:
				var c: Color = get_theme_color(&"pip_next", t) if i == owned else get_theme_color(&"pip_off", t)
				cut.append(cut[0])
				draw_polyline(cut, c, 1.5, true)

class_name ShopScreen
extends ScreenBase
## The shop (GDD §8): permanent items bought tier by tier and kept, breakable items bought as stock
## (up to each item's max_stock: every run takes one of each switched-on item, and revives wait in
## stock for the death screen), and the equip toggle for everything owned. Shown from the menu,
## between levels and after every death. On mobile it also sells credit packs when the platform
## does (GDD §7). The wallet counts down as items are bought.
## Leaving: with a `play_label` the main button ("Next", "Retry", "Play again") runs `on_close` and
## Menu goes to the title screen; without one the back button runs `on_close`.

## Where the player goes on leaving (the next level, a retry, or the title screen).
var on_close: Callable
## Label of the main way out ("Next", "Retry", "Play again"); empty = just the back button.
var play_label: String = ""

var wallet: CreditCounter
## Item id -> its ItemCard.
var cards: Dictionary = {}
## The main way out (only with a play_label) and the way to the title screen.
var play_button: NeonButton
var menu_button: NeonButton
## Product id -> its button (mobile credit packs).
var pack_buttons: Dictionary = {}
var _net_worth: Label
var _buying_pack: bool = false


func _ready() -> void:
	title = "SHOP"
	back_requested.connect(_leave)
	_net_worth = ScreenBase.make_label("", UiTheme.CAPTION)
	_net_worth.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_net_worth.size_flags_vertical = Control.SIZE_FILL
	# The web demo has no leaderboards (GDD §2).
	_net_worth.tooltip_text = "Earned credits you haven't spent." + (" Leaderboards rank it." if BuildFlavor.has_leaderboards() else "")
	_net_worth.mouse_filter = Control.MOUSE_FILTER_PASS
	header_right.add_child(_net_worth)
	wallet = CreditCounter.new()
	wallet.set_value(App.profile.credits(), false)
	header_right.add_child(wallet)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	content.add_child(scroll)
	var sections := VBoxContainer.new()
	sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sections.add_theme_constant_override(&"separation", roundi(UiTheme.px(8)))
	scroll.add_child(sections)
	# Breakable items first: restocking is what most visits are for.
	var breakable: HFlowContainer = _section(sections, "BREAKABLE ITEMS", &"shield",
		"Every run takes one of each; they break when used. Revives stay in stock until you need one.")
	var permanent: HFlowContainer = _section(sections, "PERMANENT ITEMS", &"star",
		"Yours for good. Switch any off for a challenge.")
	for item: ShopItem in App.catalog.items_for(App.mobile):
		var card := ItemCard.new()
		card.item_id = item.id
		card.buy_pressed.connect(_on_buy)
		card.equip_toggled.connect(_on_equip)
		(permanent if item.kind == ShopItem.Kind.PERMANENT else breakable).add_child(card)
		cards[item.id] = card
	if App.mobile and Platform.purchases_available() and not Platform.products().is_empty():
		var packs: HFlowContainer = _section(sections, "CREDIT PACKS", &"plus", "Bought credits never count toward net worth.")
		for product: Dictionary in Platform.products():
			var tile: TileButton = _pack_tile(product)
			packs.add_child(tile)
			pack_buttons[StringName(product["id"])] = tile

	if play_label != "":
		# Between runs: the main button carries on; back (Esc) does the same, Menu leaves the flow.
		back_button.visible = false
		var inset := Control.new()
		inset.custom_minimum_size.x = UiTheme.px(16)
		back_button.add_sibling(inset)
		var actions := HBoxContainer.new()
		actions.alignment = BoxContainer.ALIGNMENT_END
		actions.add_theme_constant_override(&"separation", roundi(UiTheme.px(12)))
		content.add_child(actions)
		menu_button = NeonButton.make("MENU", NeonButton.Kind.FLAT, &"home")
		menu_button.pressed.connect(App.show_title)
		actions.add_child(menu_button)
		play_button = NeonButton.make(play_label.to_upper(), NeonButton.Kind.PRIMARY, _play_icon())
		play_button.custom_minimum_size.x = UiTheme.px(220)
		play_button.pressed.connect(_leave)
		actions.add_child(play_button)
		initial_focus = play_button
		set_hints([[&"ui_accept", "SELECT"], [&"ui_cancel", play_label.to_upper()]])
	App.profile_changed.connect(_refresh)
	_refresh(false)
	if play_button == null:
		# The first thing on show that can be bought.
		for card: Node in breakable.get_children() + permanent.get_children():
			var buy: NeonButton = (card as ItemCard).buy_button
			if buy.visible and not buy.disabled:
				initial_focus = buy
				break


## Fills every card from the catalog and the profile (after each purchase or equip change).
func _refresh(animate: bool = true) -> void:
	var p: Profile = App.profile
	wallet.set_value(p.credits(), animate)
	_net_worth.text = "NET WORTH  %s" % UiTheme.format_int(p.net_worth())
	for item: ShopItem in App.catalog.items_for(App.mobile):
		var card: ItemCard = cards.get(item.id)
		if card != null:
			card.configure(_card_data(item, p))
	for id: Variant in pack_buttons:
		(pack_buttons[id] as TileButton).disabled = _buying_pack
	# A card that just maxed out loses its buy button: keep the focus on the card.
	var focused: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if focused != null and not focused.is_visible_in_tree():
		_refocus.call_deferred()


func _card_data(item: ShopItem, p: Profile) -> Dictionary:
	var price: int = App.next_price(item)
	var d: Dictionary = {
		"item_id": item.id,
		"title": item.display_name,
		"price": price if price >= 0 else item.price_of(1, App.mobile),
		"equipped": p.is_equipped(item.id),
		"credits": p.credits(),
	}
	if item.kind == ShopItem.Kind.PERMANENT:
		var t: int = p.tier(item.id)
		var tiers: int = maxi(item.tier_count(), 1)
		d["tier"] = t
		d["max_tier"] = tiers
		d["icon_name"] = ShopScreen.icon_for(item.icon, maxi(t, 1))
		if t > 0 and tiers > 1:
			d["title"] = item.tier_name(t)
		if t == 0:
			d["description"] = item.description
		elif t < tiers:
			d["description"] = "Next: %s. %s" % [item.tier_name(t + 1), item.tier_description(t + 1)]
		else:
			d["description"] = item.tier_description(t)
	else:
		d["stock"] = p.stock(item.id)
		d["max_stock"] = item.max_stock
		d["icon_name"] = ShopScreen.icon_for(item.icon)
		d["description"] = item.description
	return d


## The kit icon for a catalog icon name (the weapon's icon changes with its tier).
static func icon_for(icon: StringName, tier: int = 1) -> StringName:
	if icon == &"weapon":
		return IconFactory.weapon_icon(tier)
	return icon if IconFactory.has_icon(icon) else &"store"


func _on_buy(id: StringName) -> void:
	App.buy(id)


func _on_equip(id: StringName, on: bool) -> void:
	App.set_equipped(id, on)


func _refocus() -> void:
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null and focused.is_visible_in_tree():
		return
	for id: Variant in cards:
		var card: ItemCard = cards[id]
		if focused != null and card.is_ancestor_of(focused):
			var target: Control = card.equip_switch if card.equip_switch.visible else ScreenBase.first_focusable(card)
			if target != null:
				target.grab_focus(UiTheme.is_touch())
				return
	focus_initial()


func _leave() -> void:
	if on_close.is_valid():
		on_close.call()
	else:
		App.show_title()


func _play_icon() -> StringName:
	match play_label.to_lower():
		"retry", "play again":
			return &"restart"
	return &"play"


## A titled group of cards: the heading, a one-line explanation, and the flow the cards go in.
func _section(parent: Control, heading: String, icon_name: StringName, note: String) -> HFlowContainer:
	var head := VBoxContainer.new()
	head.add_theme_constant_override(&"separation", 0)
	parent.add_child(head)
	head.add_child(ScreenBase.make_heading(heading, icon_name))
	if note != "":
		head.add_child(ScreenBase.make_label(note, UiTheme.CAPTION))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override(&"h_separation", roundi(UiTheme.px(12)))
	flow.add_theme_constant_override(&"v_separation", roundi(UiTheme.px(12)))
	parent.add_child(flow)
	return flow


func _pack_tile(product: Dictionary) -> TileButton:
	var tile := TileButton.new()
	tile.custom_minimum_size.x = UiTheme.px(260)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	tile.content.add_child(row)
	var credits: int = int(product.get("credits", 0))
	var coin := NeonIcon.make(IconFactory.credit_icon(100), UiTheme.px(34), UiTheme.credit_color(100))
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(coin)
	var words := VBoxContainer.new()
	words.add_theme_constant_override(&"separation", 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	words.add_child(ScreenBase.make_label("+%s" % UiTheme.format_int(credits), UiTheme.VALUE))
	words.add_child(ScreenBase.make_label(String(product.get("title", "")), UiTheme.CAPTION))
	var price := ScreenBase.make_label(String(product.get("price_text", "")), UiTheme.ACCENT_TEXT)
	price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(price)
	tile.pressed.connect(_buy_pack.bind(StringName(product["id"]), credits))
	return tile


func _buy_pack(id: StringName, credits: int) -> void:
	if _buying_pack:
		return
	_buying_pack = true
	_refresh()
	ShopScreen._purchase(id, credits, weakref(self))


## Awaits the platform in a static function, so a screen closed meanwhile is simply skipped.
static func _purchase(id: StringName, credits: int, screen_ref: WeakRef) -> void:
	var ok: bool = await App.buy_credit_pack(id)
	var screen := screen_ref.get_ref() as ShopScreen
	if screen != null and screen.is_inside_tree():
		screen._on_pack_result(ok, credits)


func _on_pack_result(ok: bool, credits: int) -> void:
	_buying_pack = false
	_refresh()
	if ok:
		Toast.show_message(self, "+%s credits" % UiTheme.format_int(credits), IconFactory.credit_icon(100))
	else:
		App.play_ui_sound(&"ui_error")
		Toast.show_message(self, "The purchase didn't go through", &"warning", Toast.Kind.WARNING)

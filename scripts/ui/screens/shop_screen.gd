class_name ShopScreen
extends Control
## The shop (GDD §8): permanent items by tier, breakable items as stock, and the equip toggle for
## everything owned. Shown between levels and after every death. Placeholder look (ScreenKit).

## Where the player goes on leaving (the next level, a retry, or the title screen).
var on_close: Callable
## Label of the main way out ("Next", "Retry"); empty = just "Back".
var play_label: String = ""

var _list: VBoxContainer
var _wallet: Label


func _ready() -> void:
	ScreenKit.fill(self)
	var col: VBoxContainer = ScreenKit.column(self, 820.0)
	ScreenKit.title(col, "SHOP", 36)
	_wallet = ScreenKit.label(col, "", 18)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 420.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var buttons: HBoxContainer = ScreenKit.row(col)
	if play_label != "":
		ScreenKit.button(buttons, play_label, on_close)
		ScreenKit.button(buttons, "Menu", App.show_title)
	else:
		ScreenKit.button(buttons, "Back", on_close)
	App.profile_changed.connect(_refresh)
	_refresh()
	ScreenKit.focus_first(buttons)


func _refresh() -> void:
	var p: Profile = App.profile
	_wallet.text = "Credits: %d   (net worth %d)" % [p.credits(), p.net_worth()]
	for c: Node in _list.get_children():
		c.queue_free()
	for item: ShopItem in App.catalog.items_for(App.mobile):
		var r: HBoxContainer = ScreenKit.row(_list)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(info)
		var owned: bool
		var status: String
		if item.kind == ShopItem.Kind.PERMANENT:
			var t: int = p.tier(item.id)
			owned = t > 0
			status = "%s (tier %d/%d)" % [item.tier_name(maxi(t, 1)), t, item.tier_count()] if item.tier_count() > 1 \
				else ("%s (owned)" % item.display_name if owned else item.display_name)
		else:
			owned = p.stock(item.id) > 0
			status = "%s x%d (max %d)" % [item.display_name, p.stock(item.id), item.max_stock]
		ScreenKit.label(info, status, 18)
		var next_tier: int = mini(p.tier(item.id) + 1, maxi(item.tier_count(), 1))
		ScreenKit.label(info, item.tier_description(next_tier) if item.kind == ShopItem.Kind.PERMANENT else item.description, 13)
		var price: int = App.next_price(item)
		var buy_text: String = "Max" if price < 0 else "Buy  %d" % price
		ScreenKit.button(r, buy_text, func() -> void: App.buy(item.id), price < 0 or not p.can_afford(price))
		if owned:
			var toggle := CheckButton.new()
			toggle.text = "On"
			toggle.button_pressed = p.is_equipped(item.id)
			toggle.toggled.connect(func(on: bool) -> void: App.set_equipped(item.id, on))
			r.add_child(toggle)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and on_close.is_valid():
		on_close.call()

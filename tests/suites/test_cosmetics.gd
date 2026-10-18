extends TestSuite
## The cosmetics' economy, save and shop (GDD §8, "Cosmetics"; task M1): the profile keeps what is owned and what is
## worn, and old saves load with nothing owned and Echo worn; App buys a cosmetic once with credits from the wallet
## (never twice, never without enough, bought credits first) and wears an owned one (saved, and the avatars built
## after it wear it), the free default look is always there to go back to; and the shop's Cosmetics section follows
## it: a card for Echo's own look and each outfit, after the power-ups, whose one button buys, wears or takes off.
## The outfits' looks are test_outfits.

const TEST_SAVE: String = "user://test_cosmetics_profile.json"

var main: Node
var _saved_profile: Profile
var _saved_path: String
var _saved_autosave: bool
var _saved_worn: StringName


func run() -> void:
	_saved_profile = App.profile
	_saved_path = App.save_path
	_saved_autosave = App.autosave
	_saved_worn = PlayerOutfits.worn
	App.autosave = false
	_test_profile()
	_test_save_files()
	_test_buying()
	_test_wearing()
	_test_saved_by_app()
	await _test_shop()
	App.profile = _saved_profile
	App.save_path = _saved_path
	App.autosave = _saved_autosave
	PlayerOutfits.worn = _saved_worn
	SaveService.delete_save(TEST_SAVE)


# --- The profile ----------------------------------------------------------------------

func _test_profile() -> void:
	var p := Profile.new()
	check(p.worn() == PlayerOutfits.ECHO and p.outfits.is_empty() and p.owns_outfit(PlayerOutfits.ECHO) and not p.owns_outfit(&"rex"),
		"a new profile owns no cosmetic and wears Razor Echo's own look, which is always owned")
	check(not p.wear_outfit(&"rex") and p.worn() == PlayerOutfits.ECHO, "an outfit that isn't owned can't be worn")
	p.add_outfit(&"rex")
	p.add_outfit(PlayerOutfits.ECHO)
	check(p.owns_outfit(&"rex") and p.outfits.size() == 1, "an outfit is owned once added (and Echo's look is never listed)")
	check(p.wear_outfit(&"rex") and p.worn() == &"rex" and p.wear_outfit(PlayerOutfits.ECHO) and p.worn() == PlayerOutfits.ECHO,
		"an owned outfit is worn, and Echo's own look goes back on")
	p.wear_outfit(&"rex")
	p.add_earned(500)
	# A JSON round trip, the way SaveService writes it.
	var json := JSON.new()
	check(json.parse(JSON.stringify(p.to_dict(), "\t")) == OK, "the profile writes as JSON")
	var back: Profile = Profile.from_dict(json.data)
	check(back.owns_outfit(&"rex") and not back.owns_outfit(&"camo") and back.worn() == &"rex" and back.credits() == 500,
		"what is owned and what is worn survive the round trip")
	# Saves written before the cosmetics have neither field.
	var old: Profile = Profile.from_dict({"version": 4, "earned": 1200, "tiers": {"dash": 2}})
	check(old.outfits.is_empty() and old.worn() == PlayerOutfits.ECHO and old.credits() == 1200 and old.tier(&"dash") == 2,
		"a save from before the cosmetics loads with nothing owned and Echo worn")
	var very_old: Profile = Profile.from_dict({"version": 1, "earned": 80, "stocks": {"armor": 1}})
	check(very_old.outfits.is_empty() and very_old.worn() == PlayerOutfits.ECHO and very_old.credits() == 230,
		"and so does one from the first save version, after its own migration")
	# A save that wears what it doesn't own (edited by hand) wears Echo's own look.
	var edited: Profile = Profile.from_dict({"version": 4, "worn_outfit": "rex", "outfits": {}})
	check(edited.worn() == PlayerOutfits.ECHO, "an outfit worn but not owned is taken off on loading")
	var junk: Profile = Profile.from_dict({"version": 4, "outfits": 7, "worn_outfit": 3})
	check(junk.outfits.is_empty() and junk.worn() == PlayerOutfits.ECHO, "a damaged cosmetics field is nothing owned")


func _test_save_files() -> void:
	SaveService.delete_save(TEST_SAVE)
	var p := Profile.new()
	p.add_earned(4200)
	p.add_outfit(&"rex")
	p.add_outfit(&"camo")
	p.wear_outfit(&"camo")
	check(SaveService.save_profile(p, TEST_SAVE), "the profile saves")
	var loaded: Profile = SaveService.load_profile(TEST_SAVE)
	check(loaded.owns_outfit(&"rex") and loaded.owns_outfit(&"camo") and not loaded.owns_outfit(&"centurion") and loaded.worn() == &"camo",
		"ownership and the worn outfit load back from the save file")
	# An old save file on disk.
	var file := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 3, "earned": 700, "tiers": {"weapon": 1}}))
	file.close()
	var old: Profile = SaveService.load_profile(TEST_SAVE)
	check(old.credits() == 700 and old.tier(&"weapon") == 1 and old.outfits.is_empty() and old.worn() == PlayerOutfits.ECHO,
		"an old save file loads cleanly: no cosmetics owned, Echo worn")
	SaveService.delete_save(TEST_SAVE)


# --- Buying and wearing ------------------------------------------------------------------

func _fresh(credits: int) -> void:
	App.profile = Profile.new()
	App.profile.add_earned(credits)
	App.sync_outfit()


func _test_buying() -> void:
	var rex: ShopCosmetic = App.catalog.cosmetic(&"rex")
	var changes: Array[int] = [0]
	var count := func() -> void: changes[0] += 1
	App.profile_changed.connect(count)
	_fresh(rex.price - 1)
	check(not App.buy_cosmetic(&"rex") and not App.profile.owns_outfit(&"rex") and App.profile.credits() == rex.price - 1 and changes[0] == 0,
		"without enough credits nothing is bought or taken")
	App.profile.add_earned(1)
	check(App.buy_cosmetic(&"rex") and App.profile.owns_outfit(&"rex") and App.profile.credits() == 0 and changes[0] == 1,
		"with enough, Rex is bought for %d credits from the wallet" % rex.price)
	check(App.profile.lifetime_spent == rex.price, "…and counts as spent")
	check(App.profile.worn() == PlayerOutfits.ECHO, "…but isn't worn until the player picks it")
	App.profile.add_earned(10000)
	check(not App.buy_cosmetic(&"rex") and App.profile.credits() == 10000 and changes[0] == 1, "a cosmetic is bought once, never twice")
	check(App.buy_cosmetic(&"camo") and App.profile.credits() == 10000 - App.catalog.cosmetic(&"camo").price and App.profile.owns_outfit(&"camo"),
		"another one comes out of what is left")
	for id: StringName in [&"nope", PlayerOutfits.ECHO, &""]:
		check(not App.buy_cosmetic(id) and App.profile.outfits.size() == 2, "'%s' can't be bought (unknown, or the free default look)" % id)
	# Bought credits go first; only the earned part spent lowers net worth.
	App.profile = Profile.new()
	App.profile.add_earned(1000)
	App.profile.add_purchased(2500)
	check(App.buy_cosmetic(&"rex") and App.profile.purchased == 0 and App.profile.earned == 500 and App.profile.net_worth() == 500,
		"bought credits are spent first, as for every item")
	# Every outfit at the owner's price from one wallet.
	_fresh(21000)
	var all: bool = true
	for c: ShopCosmetic in App.catalog.cosmetics:
		all = all and App.buy_cosmetic(c.id)
	check(all and App.profile.credits() == 0 and App.profile.outfits.size() == 5, "all five cost 21,000 together")
	App.profile_changed.disconnect(count)


func _test_wearing() -> void:
	var changes: Array[int] = [0]
	var count := func() -> void: changes[0] += 1
	App.profile_changed.connect(count)
	_fresh(5000)
	check(not App.wear_outfit(&"rex") and PlayerOutfits.worn == PlayerOutfits.ECHO and changes[0] == 0,
		"an outfit that isn't owned can't be worn")
	App.buy_cosmetic(&"rex")
	changes[0] = 0
	check(App.wear_outfit(&"rex") and App.profile.worn() == &"rex" and PlayerOutfits.worn == &"rex" and changes[0] == 1,
		"an owned outfit is worn")
	var avatar := PlayerAvatar.new()
	check(avatar.outfit() == &"rex" and avatar.rig.parts == PlayerOutfits.parts_for(&"rex"), "and the avatars built after it wear it")
	avatar.free()
	check(not App.wear_outfit(&"nope") and not App.wear_outfit(&"camo") and App.profile.worn() == &"rex", "an unknown or unowned one changes nothing")
	check(App.wear_outfit(PlayerOutfits.ECHO) and App.profile.worn() == PlayerOutfits.ECHO and PlayerOutfits.worn == PlayerOutfits.ECHO,
		"Razor Echo's own look goes back on, free")
	var echo := PlayerAvatar.new()
	check(echo.outfit() == PlayerOutfits.ECHO and echo.rig.parts == PlayerSuit.parts(), "…and the next avatar wears it")
	echo.free()
	# Wearing costs nothing and keeps the wallet.
	check(App.profile.credits() == 5000 - App.catalog.cosmetic(&"rex").price, "wearing and changing back never touch the wallet")
	# A profile swapped in (a load, a test) is picked up by sync_outfit, and an outfit the catalog doesn't know is Echo's own look.
	var other := Profile.new()
	other.add_outfit(&"rex")
	other.wear_outfit(&"rex")
	App.profile = other
	App.sync_outfit()
	check(PlayerOutfits.worn == &"rex", "sync_outfit wears what the profile does")
	var ghost := Profile.new()
	ghost.add_outfit(&"ghost")
	ghost.wear_outfit(&"ghost")
	App.profile = ghost
	App.sync_outfit()
	check(PlayerOutfits.worn == PlayerOutfits.ECHO, "an outfit the catalog has dropped is Echo's own look")
	App.profile_changed.disconnect(count)
	PlayerOutfits.worn = PlayerOutfits.ECHO


## With the real autosave: buying and wearing reach the save file.
func _test_saved_by_app() -> void:
	SaveService.delete_save(TEST_SAVE)
	App.save_path = TEST_SAVE
	App.autosave = true
	_fresh(4000)
	App.buy_cosmetic(&"rex")
	var after_buy: Profile = SaveService.load_profile(TEST_SAVE)
	check(after_buy.owns_outfit(&"rex") and after_buy.credits() == 1000 and after_buy.worn() == PlayerOutfits.ECHO, "buying is saved")
	App.wear_outfit(&"rex")
	var after_wear: Profile = SaveService.load_profile(TEST_SAVE)
	check(after_wear.worn() == &"rex" and after_wear.owns_outfit(&"rex"), "wearing is saved")
	App.wear_outfit(PlayerOutfits.ECHO)
	check(SaveService.load_profile(TEST_SAVE).worn() == PlayerOutfits.ECHO, "and so is going back to Echo's own look")
	App.autosave = false
	App.save_path = _saved_path
	SaveService.delete_save(TEST_SAVE)
	PlayerOutfits.worn = PlayerOutfits.ECHO


# --- The shop's Cosmetics section --------------------------------------------------------------

func _frames(count: int) -> void:
	for i: int in count:
		await tree.process_frame


func _test_shop() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	_fresh(0)
	App.show_shop()
	await _frames(2)
	var shop := App.screen as ShopScreen
	var ids: Array = shop.cosmetic_cards.keys()
	check(ids == [&"echo", &"rex", &"camo", &"beach_master", &"centurion", &"party_wolf"],
		"the shop has a card for Razor Echo's own look and each outfit, in the catalog's order (%s)" % [ids])
	var breakable: Node = shop.cards[&"grapple"].get_parent()
	var section: Node = (shop.cosmetic_cards[&"rex"] as Node).get_parent()
	check(section.get_parent() == breakable.get_parent() and section.get_index() > breakable.get_index()
		and (shop.cosmetic_cards[&"echo"] as Node).get_parent() == section, "the Cosmetics section follows the power-ups")
	var heading: Node = breakable.get_parent().get_child(section.get_index() - 1)
	var words: PackedStringArray = []
	for label: Node in heading.find_children("*", "Label", true, false):
		words.append((label as Label).text)
	check(words.has("COSMETICS"), "under its own heading (%s)" % [words])
	var echo: CosmeticCard = shop.cosmetic_cards[&"echo"]
	var rex: CosmeticCard = shop.cosmetic_cards[&"rex"]
	check(echo.state == CosmeticCard.State.WORN and echo.action_button.disabled and echo.action_button.text == "WORN"
		and echo.status_label.text == "WORN" and echo.title == "Razor Echo", "Echo's own look is worn, and can't be taken off")
	check(rex.state == CosmeticCard.State.CANT_AFFORD and rex.action_button.disabled and rex.status_label.text == "NOT ENOUGH CREDITS"
		and rex.action_button.text == UiTheme.format_int(3000), "Rex shows its price and can't be paid with an empty wallet")
	App.profile.add_earned(3000)
	App.profile_changed.emit()
	await _frames(1)
	check(rex.state == CosmeticCard.State.AVAILABLE and not rex.action_button.disabled and rex.status_label.text == "",
		"with 3,000 credits it can be bought (Rex's look is built: no note)")
	var camo: CosmeticCard = shop.cosmetic_cards[&"camo"]
	check(camo.state == CosmeticCard.State.AVAILABLE and shop.cosmetic_cards[&"centurion"].state == CosmeticCard.State.CANT_AFFORD,
		"Camo's 3,000 is in reach too, Centurion's 5,000 isn't")
	rex.action_button.pressed.emit()
	await _frames(2)
	check(camo.state == CosmeticCard.State.CANT_AFFORD, "once Rex is paid for, Camo is out of reach")
	check(App.profile.owns_outfit(&"rex") and App.profile.credits() == 0 and rex.state == CosmeticCard.State.OWNED
		and rex.action_button.text == "WEAR" and rex.status_label.text == "OWNED" and echo.state == CosmeticCard.State.WORN,
		"pressing the price buys it: the credits go, the card is OWNED with WEAR on its button")
	check(shop.wallet.value == 0, "the wallet follows")
	rex.action_button.pressed.emit()
	await _frames(2)
	check(App.profile.worn() == &"rex" and PlayerOutfits.worn == &"rex" and rex.state == CosmeticCard.State.WORN
		and rex.action_button.text == "TAKE OFF" and not rex.action_button.disabled
		and echo.state == CosmeticCard.State.OWNED and echo.action_button.text == "WEAR" and not echo.action_button.disabled,
		"WEAR puts it on: Rex is WORN with TAKE OFF, Echo's own look can be worn again")
	echo.action_button.pressed.emit()
	await _frames(2)
	check(App.profile.worn() == PlayerOutfits.ECHO and rex.state == CosmeticCard.State.OWNED and echo.state == CosmeticCard.State.WORN,
		"Echo's own card goes back to the free look")
	rex.action_button.pressed.emit()
	await _frames(2)
	rex.action_button.pressed.emit()
	await _frames(2)
	check(App.profile.worn() == PlayerOutfits.ECHO and rex.state == CosmeticCard.State.OWNED, "TAKE OFF on the worn outfit does the same")
	# An outfit whose look isn't built yet says so until it is.
	App.profile.add_earned(5000)
	App.profile_changed.emit()
	await _frames(1)
	for id: StringName in [&"camo", &"beach_master", &"centurion", &"party_wolf"]:
		var card: CosmeticCard = shop.cosmetic_cards[id]
		var expected: String = "" if PlayerOutfits.is_built(id) else "LOOK IN PROGRESS"
		check(card.state == CosmeticCard.State.AVAILABLE and card.status_label.text == expected,
			"%s can be bought and its caption is '%s'" % [id, expected])
	# Every look can be bought and worn, built or not, and the avatar never breaks.
	var worn_all: bool = true
	for c: ShopCosmetic in App.catalog.cosmetics:
		if not App.profile.owns_outfit(c.id):
			App.profile.add_earned(c.price)
			worn_all = worn_all and App.buy_cosmetic(c.id)
		worn_all = worn_all and App.wear_outfit(c.id)
		var avatar := PlayerAvatar.new()
		worn_all = worn_all and avatar.outfit() == c.id and avatar.triangle_count() > 500
		avatar.free()
	check(worn_all, "every outfit can be bought, worn and built, finished or not")
	App.wear_outfit(PlayerOutfits.ECHO)
	# Phone shops, the web demo and the mobile flavor show the section too.
	App.mobile = true
	Platform.configure_for(BuildFlavor.Kind.FULL_MOBILE)
	App.show_shop()
	await _frames(2)
	check((App.screen as ShopScreen).cosmetic_cards.size() == 6, "the mobile shop has the cosmetics too")
	App.mobile = false
	Platform.configure_for(BuildFlavor.current())
	BuildFlavor.set_override(BuildFlavor.Kind.WEB_DEMO)
	App.show_shop()
	await _frames(2)
	check((App.screen as ShopScreen).cosmetic_cards.size() == 6, "and so does the web demo's")
	BuildFlavor.set_override(-1)
	App.show_title()
	await _frames(1)
	main.queue_free()
	App.main = null
	await tree.process_frame

extends TestSuite
## The cosmetics' economy, save and shop (GDD §8, "Cosmetics"; task M1): the profile keeps what is owned and what is
## worn, and old saves load with nothing owned and Echo worn; App buys a cosmetic once with credits from the wallet
## (never twice, never without enough, earned credits first so that it never lowers net worth) and wears an owned one (saved, and the avatars built
## after it wear it), the free default look is always there to go back to; buying an outfit never lowers net worth
## (owner, October 18, 2026, item 980: the profile keeps what was spent on cosmetics, and a save from before that reads it
## off the outfits it owns); and the shop's Cosmetics section follows it: a card for Echo's own look and each outfit,
## after the power-ups, whose one button buys, wears or takes off, and whose picture is the runner in the outfit (item
## 982: a still, and one live preview for the card the pointer or the focus is on). The outfits' looks are test_outfits.

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
	_test_leaderboard()
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
	# Net worth: what an outfit cost stays in it (item 980). A new save keeps the count, an older one reads it off its outfits.
	var rich := Profile.new()
	rich.add_earned(5000)
	rich.add_outfit(&"rex")
	rich.cosmetic_spent = 3000
	var rich_json := JSON.new()
	check(rich_json.parse(JSON.stringify(rich.to_dict(), "\t")) == OK, "a profile with cosmetic spending writes as JSON")
	var rich_back: Profile = Profile.from_dict(rich_json.data)
	check(rich_back.cosmetic_spent == 3000 and rich_back.net_worth() == 8000 and typeof(rich_back.cosmetic_spent) == TYPE_INT,
		"the cosmetic spending survives the round trip (%d)" % rich_back.cosmetic_spent)
	# The old-save cases carry lifetime_earned: the net worth given back never goes past it (earned + what the earned credits
	# spent on outfits = at most lifetime_earned).
	var before: Profile = Profile.from_dict({"version": 4, "earned": 1200, "lifetime_earned": 4200, "lifetime_spent": 3000,
		"outfits": {"rex": true}})
	check(before.cosmetic_spent == 3000 and before.net_worth() == 4200 and before.credits() == 1200,
		"a save that bought Rex with earned credits before the change gets its 3,000 back in the net worth, not in the wallet (%d)" % before.cosmetic_spent)
	var several: Profile = Profile.from_dict({"version": 4, "earned": 100, "lifetime_earned": 20100, "lifetime_spent": 20000,
		"outfits": {"rex": true, "camo": true, "centurion": true}})
	check(several.cosmetic_spent == 3000 + 3000 + 5000, "every outfit owned counts at the catalog's price (%d)" % several.cosmetic_spent)
	var short: Profile = Profile.from_dict({"version": 4, "earned": 100, "lifetime_earned": 1100, "lifetime_spent": 1000,
		"outfits": {"rex": true, "camo": true}})
	check(short.cosmetic_spent == 1000, "never more than the save ever spent (an outfit granted by hand): %d" % short.cosmetic_spent)
	var items_too: Profile = Profile.from_dict({"version": 4, "earned": 500, "lifetime_earned": 5500, "lifetime_spent": 5000,
		"outfits": {"rex": true}})
	check(items_too.cosmetic_spent == 3000 and items_too.net_worth() == 3500,
		"a save that spent on items too gets back the outfit's price, not the items' (%d)" % items_too.cosmetic_spent)
	# Rex paid with bought credits (mobile): they went first and an old save can't say so, but the net worth is never more
	# than the player earned, so none of it is given back.
	var bought_only: Profile = Profile.from_dict({"version": 4, "earned": 1000, "lifetime_earned": 1000, "lifetime_spent": 3000,
		"outfits": {"rex": true}})
	check(bought_only.cosmetic_spent == 0 and bought_only.net_worth() == 1000 and bought_only.net_worth() <= bought_only.lifetime_earned,
		"Rex paid wholly with bought credits gives nothing back: net worth %d of the 1,000 earned" % bought_only.net_worth())
	var half_bought: Profile = Profile.from_dict({"version": 4, "earned": 1000, "lifetime_earned": 3000, "lifetime_spent": 3000,
		"outfits": {"rex": true}})
	check(half_bought.cosmetic_spent == 2000 and half_bought.net_worth() == 3000 and half_bought.net_worth() <= half_bought.lifetime_earned,
		"Rex paid with 2,000 earned and 1,000 bought gives back the 2,000 (%d), never past the 3,000 earned" % half_bought.cosmetic_spent)
	var ghost: Profile = Profile.from_dict({"version": 4, "earned": 100, "lifetime_earned": 9100, "lifetime_spent": 9000,
		"outfits": {"ghost": true}})
	check(ghost.cosmetic_spent == 0, "an outfit the catalog doesn't list counts for nothing")
	check(Profile.from_dict({"version": 4, "earned": 100, "lifetime_earned": 9100, "lifetime_spent": 9000}).cosmetic_spent == 0
		and Profile.from_dict({"version": 1, "earned": 100}).cosmetic_spent == 0, "and a save with no outfit has none")
	check(Profile.from_dict({"version": 4, "earned": 100, "lifetime_spent": 3000, "outfits": {"rex": true}}).cosmetic_spent == 0,
		"a save with no lifetime_earned can't show any earned spending, so it gets nothing back")
	var trusted: Profile = Profile.from_dict({"version": 4, "earned": 100, "lifetime_earned": 3100, "lifetime_spent": 3000,
		"outfits": {"rex": true}, "cosmetic_spent": 0})
	check(trusted.cosmetic_spent == 0, "a save that already counts it (even at 0) is believed, not worked out again")
	var junk_spent: Profile = Profile.from_dict({"version": 4, "earned": 100, "lifetime_earned": 3100, "lifetime_spent": 3000,
		"outfits": {"rex": true}, "cosmetic_spent": "lots"})
	check(junk_spent.cosmetic_spent == 3000, "a damaged count is worked out from the outfits")
	check(Profile.from_dict({"version": 4, "earned": 100, "cosmetic_spent": -50}).cosmetic_spent == 0, "and a negative one is 0")
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
	check(old.cosmetic_spent == 0 and old.net_worth() == 700, "…and no net worth in cosmetics")
	# One from after the cosmetics came and before they stopped lowering net worth (the owner's own save).
	file = FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 4, "earned": 2000, "lifetime_earned": 6000, "lifetime_spent": 4000,
		"outfits": {"rex": true}, "worn_outfit": "rex"}))
	file.close()
	var bought: Profile = SaveService.load_profile(TEST_SAVE)
	check(bought.owns_outfit(&"rex") and bought.cosmetic_spent == 3000 and bought.net_worth() == 5000 and bought.credits() == 2000,
		"a save file that bought Rex loads with its 3,000 back in the net worth (%d), the wallet as it was" % bought.net_worth())
	check(SaveService.save_profile(bought, TEST_SAVE) and SaveService.load_profile(TEST_SAVE).net_worth() == 5000,
		"and saves and loads again at the same net worth")
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
	check(App.profile.worn() == &"rex" and PlayerOutfits.worn == &"rex", "…and is worn right away (owner, item 981)")
	check(App.profile.net_worth() == rex.price and App.profile.cosmetic_spent == rex.price,
		"…and doesn't lower the net worth: still the %d earned (%d)" % [rex.price, App.profile.net_worth()])
	App.profile.add_earned(10000)
	check(not App.buy_cosmetic(&"rex") and App.profile.credits() == 10000 and changes[0] == 1, "a cosmetic is bought once, never twice")
	check(App.buy_cosmetic(&"camo") and App.profile.credits() == 10000 - App.catalog.cosmetic(&"camo").price and App.profile.owns_outfit(&"camo"),
		"another one comes out of what is left")
	check(App.profile.net_worth() == rex.price + 10000, "…and the net worth is all that was earned (%d)" % App.profile.net_worth())
	for id: StringName in [&"nope", PlayerOutfits.ECHO, &""]:
		check(not App.buy_cosmetic(id) and App.profile.outfits.size() == 2, "'%s' can't be bought (unknown, or the free default look)" % id)
	# An outfit spends the earned credits first (then bought ones) and never lowers net worth, so what the earned credits paid
	# is kept in it; items go on spending bought credits first.
	App.profile = Profile.new()
	App.profile.add_earned(1000)
	App.profile.add_purchased(2500)
	check(App.buy_cosmetic(&"rex") and App.profile.earned == 0 and App.profile.purchased == 500 and App.profile.credits() == 500,
		"the earned credits are spent first, then the bought ones")
	check(App.profile.net_worth() == 1000 and App.profile.cosmetic_spent == 1000,
		"…and the net worth is still the 1,000 earned, bought credits never in it (%d)" % App.profile.net_worth())
	# Earned 2,000 and bought 3,000: Rex, then 1,500 spent on an item (bought credits first) leaves the net worth at 2,000,
	# as it would without Rex.
	App.profile = Profile.new()
	App.profile.add_earned(2000)
	App.profile.add_purchased(3000)
	check(App.buy_cosmetic(&"rex") and App.profile.net_worth() == 2000 and App.profile.credits() == 2000,
		"Rex from earned 2,000 and bought 3,000 leaves the net worth at 2,000")
	App.profile.spend(1500)
	var plain := Profile.new()
	plain.add_earned(2000)
	plain.add_purchased(3000)
	plain.spend(1500)
	check(App.profile.net_worth() == 2000 and plain.net_worth() == 2000,
		"…and after a 1,500 purchase it is 2,000, as without the outfit (%d, %d)" % [App.profile.net_worth(), plain.net_worth()])
	# Every outfit at the owner's price from one wallet.
	_fresh(21000)
	var all: bool = true
	for c: ShopCosmetic in App.catalog.cosmetics:
		all = all and App.buy_cosmetic(c.id)
	check(all and App.profile.credits() == 0 and App.profile.outfits.size() == 5, "all five cost 21,000 together")
	App.profile_changed.disconnect(count)


## The net worth the leaderboard gets after a run keeps the credits spent on outfits (item 980): the stub platform records
## what App submits.
func _test_leaderboard() -> void:
	var stub: StubBackend = Platform.backend as StubBackend
	if stub == null:
		check(false, "the stub platform backend is there to read the submitted scores")
		return
	var was: bool = stub.simulate_leaderboards
	stub.simulate_leaderboards = true
	stub.scores.erase("net_worth")
	_fresh(6000)
	App.profile.add_purchased(1000)
	check(App.buy_cosmetic(&"rex") and App.buy_cosmetic(&"camo") and App.profile.credits() == 1000 and App.profile.purchased == 1000,
		"two outfits bought for 6,000 with the 6,000 earned (the 1,000 bought credits are left)")
	var result: RunResult = SampleProfiles.result(true)
	App._apply_result(result)
	var earned_now: int = App.profile.earned
	check(stub.scores.get("net_worth", -1) == App.profile.net_worth() and App.profile.net_worth() == earned_now + 6000,
		"a finished run submits the net worth with the outfits' cost in it (%d)" % int(stub.scores.get("net_worth", -1)))
	check(App.profile.net_worth() == 6000 + result.credits_earned,
		"it is what was earned (%d) and never spent on looks" % App.profile.net_worth())
	stub.simulate_leaderboards = was
	stub.scores.erase("net_worth")


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
	check(after_buy.owns_outfit(&"rex") and after_buy.credits() == 1000 and after_buy.worn() == &"rex", "buying, and wearing it, is saved")
	App.wear_outfit(PlayerOutfits.ECHO)
	check(SaveService.load_profile(TEST_SAVE).worn() == PlayerOutfits.ECHO, "going back to Echo's own look is saved")
	App.wear_outfit(&"rex")
	var after_wear: Profile = SaveService.load_profile(TEST_SAVE)
	check(after_wear.worn() == &"rex" and after_wear.owns_outfit(&"rex"), "and so is wearing it again")
	App.wear_outfit(PlayerOutfits.ECHO)
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
	# A desktop's window (the headless one is 64x64, which the stretch makes a tall square with everything in view).
	var saved_window: Vector2i = tree.root.size
	tree.root.size = Vector2i(1280, 720)
	await tree.process_frame
	OutfitStills.clear()
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
	await _test_previews(shop)
	rex.action_button.pressed.emit()
	await _frames(2)
	check(camo.state == CosmeticCard.State.CANT_AFFORD, "once Rex is paid for, Camo is out of reach")
	check(App.profile.owns_outfit(&"rex") and App.profile.credits() == 0 and App.profile.worn() == &"rex" and PlayerOutfits.worn == &"rex"
		and rex.state == CosmeticCard.State.WORN and rex.action_button.text == "TAKE OFF" and not rex.action_button.disabled
		and echo.state == CosmeticCard.State.OWNED and echo.action_button.text == "WEAR" and not echo.action_button.disabled,
		"pressing the price buys it and puts it on (item 981): Rex is WORN with TAKE OFF, Echo's own look can be worn again")
	check(shop.wallet.value == 0, "the wallet follows")
	rex.action_button.pressed.emit()
	await _frames(2)
	check(App.profile.worn() == PlayerOutfits.ECHO and rex.state == CosmeticCard.State.OWNED and rex.action_button.text == "WEAR"
		and rex.status_label.text == "OWNED" and echo.state == CosmeticCard.State.WORN,
		"TAKE OFF puts Echo's own look back on, and Rex is OWNED with WEAR on its button")
	rex.action_button.pressed.emit()
	await _frames(2)
	check(App.profile.worn() == &"rex" and PlayerOutfits.worn == &"rex" and rex.state == CosmeticCard.State.WORN,
		"WEAR puts it back on")
	echo.action_button.pressed.emit()
	await _frames(2)
	check(App.profile.worn() == PlayerOutfits.ECHO and rex.state == CosmeticCard.State.OWNED and echo.state == CosmeticCard.State.WORN,
		"Echo's own card goes back to the free look")
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
	# The arrow keys and the D-pad walk the cards at a desktop's sizes and a phone held sideways.
	await _test_navigation("desktop 1280x720")
	# However soon after the shop opens the list is scrolled to the Cosmetics, every card gets its picture (a check that was
	# already waiting for its frame must not swallow the scroll that came while it waited).
	for delay: int in [1, 2, 3, 5]:
		OutfitStills.clear()
		App.show_shop()
		await _frames(delay)
		var list: ScrollContainer = null
		var above: Node = ((App.screen as ShopScreen).cosmetic_cards[&"echo"] as Node).get_parent()
		while above != null and list == null:
			list = above as ScrollContainer
			above = above.get_parent()
		list.scroll_vertical = 100000
		var waited_for: int = 0
		while OutfitStills.drawn.size() < 6 and waited_for < 120:
			await _frames(1)
			waited_for += 1
		check(OutfitStills.drawn.size() == 6 and OutfitStills.drawn.has("echo@110x157"),
			"scrolled to the Cosmetics %d frames after the shop opened, all six pictures are drawn, Echo's too (%s)" % [delay, OutfitStills.drawn])
	tree.root.size = Vector2i(1706, 720)
	await _frames(3)
	await _test_navigation("wide 1706x720")
	# A window tall enough to show the Cosmetics at once: their pictures are asked for as the shop opens.
	tree.root.size = Vector2i(1280, 1800)
	OutfitStills.clear()
	App.show_shop()
	var asked: int = 0
	while OutfitStills.drawn.size() < 6 and asked < 120:
		await _frames(1)
		asked += 1
	check(OutfitStills.drawn.size() == 6, "a shop that opens with the Cosmetics on show draws their pictures (%d in %d frames)" % [OutfitStills.drawn.size(), asked])
	tree.root.size = Vector2i(1706, 720)
	BuildFlavor.set_override(BuildFlavor.Kind.WEB_DEMO)
	Platform.configure_for(BuildFlavor.Kind.WEB_DEMO)
	UiTheme.touch_override = 1
	UiScale.assume_web = true
	UiScale.pixel_ratio_override = 3.0
	App.mobile = true
	tree.root.size = Vector2i(844 * 3, 340 * 3)
	await _frames(3)
	await _test_navigation("phone held sideways 844x340")
	tree.root.size = Vector2i(390 * 3, 844 * 3)
	await _frames(3)
	await _test_navigation("phone held upright 390x844")
	tree.root.size = Vector2i(1280, 720)
	UiScale.assume_web = false
	UiScale.pixel_ratio_override = 0.0
	UiTheme.touch_override = -1
	App.mobile = DeviceProfile.is_mobile()
	BuildFlavor.set_override(-1)
	Platform.configure_for(BuildFlavor.current())
	App.show_title()
	await _frames(3)
	# Phone shops, the web demo and the mobile flavor show the section too.
	App.mobile = true
	Platform.configure_for(BuildFlavor.Kind.FULL_MOBILE)
	App.show_shop()
	await _frames(2)
	var phone_cards: Dictionary = (App.screen as ShopScreen).cosmetic_cards
	var phone_previews: bool = phone_cards.size() == 6
	for id: StringName in phone_cards:
		phone_previews = phone_previews and (phone_cards[id] as CosmeticCard).preview.outfit_id == id
	check(phone_previews, "the mobile shop has the cosmetics too, each with its preview")
	App.mobile = false
	Platform.configure_for(BuildFlavor.current())
	BuildFlavor.set_override(BuildFlavor.Kind.WEB_DEMO)
	App.show_shop()
	await _frames(2)
	check((App.screen as ShopScreen).cosmetic_cards.size() == 6, "and so does the web demo's")
	BuildFlavor.set_override(-1)
	App.show_title()
	await _frames(1)
	tree.root.size = saved_window
	main.queue_free()
	App.main = null
	await tree.process_frame



# --- The previews (GDD §8, item 982) -------------------------------------------------------------

## Every card shows the runner in its outfit: a still at rest, one live preview for the card the pointer or the focus is on.
func _test_previews(shop: ShopScreen) -> void:
	var cards: Dictionary = shop.cosmetic_cards
	var right: bool = true
	var boring: bool = true
	for id: StringName in cards:
		var card: CosmeticCard = cards[id]
		right = right and card.preview != null and card.preview.outfit_id == id and card.preview.is_inside_tree() \
			and card.preview.get_parent() == card.preview_frame
		boring = boring and not card.preview.is_live() and card.preview.stage == null and not card.preview.is_rendering()
	check(right and cards.size() == 6, "every card has a preview of its own outfit, Echo's own card showing Echo")
	check(boring, "at rest the previews are pictures: no live stage, no avatar built for them")
	var jacket: bool = false
	for card: Variant in cards.values():
		for node: Node in (card as Node).find_children("*", "NeonIcon", true, false):
			jacket = jacket or (node as NeonIcon).icon_name == &"outfit" and not (card as CosmeticCard).action_button.is_ancestor_of(node)
	check(not jacket, "the jacket icon is gone from the cards")
	# The pictures are drawn lazily: nothing while the Cosmetics section is below the fold, then one per outfit and size, asked
	# for once, as it comes into view.
	await _frames(20)
	check(OutfitStills.drawn.is_empty() and not OutfitStills.is_busy(),
		"a shop opened on its power-ups draws no picture for cards nobody has scrolled to (%s)" % [OutfitStills.drawn])
	var scroll: ScrollContainer = null
	var up: Node = (cards[&"rex"] as Node).get_parent()
	while up != null and scroll == null:
		scroll = up as ScrollContainer
		up = up.get_parent()
	scroll.scroll_vertical = 100000
	var guard: int = 0
	while OutfitStills.drawn.size() < cards.size() and guard < 300:
		await _frames(1)
		guard += 1
	while OutfitStills.is_busy() and guard < 300:
		await _frames(1)
		guard += 1
	var scale: float = tree.root.get_final_transform().get_scale().x
	var drawn_once: bool = true
	for id: StringName in cards:
		var key: String = OutfitStills.key_for(id, OutfitPreview.pixel_size_for((cards[id] as CosmeticCard).preview.size, scale))
		drawn_once = drawn_once and OutfitStills.drawn.count(key) == 1
	check(drawn_once, "once scrolled to, a picture of each outfit is drawn once, at the size of its preview (%s)" % [OutfitStills.drawn])
	check(not OutfitStills.is_busy(), "and the queue is empty afterwards")
	# The pointer on a card runs it; the focus too; one at a time, the latest first.
	var rex: CosmeticCard = cards[&"rex"]
	var camo: CosmeticCard = cards[&"camo"]
	rex.mouse_entered.emit()
	check(rex.interested and rex.preview.is_live() and rex.preview.is_rendering() and rex.preview.stage.outfit() == &"rex",
		"the pointer on Rex runs its preview, dressed in Rex")
	check(_live_count(cards) == 1 and _drawing_count(cards) == 1, "…and it is the only one live")
	camo.action_button.grab_focus()
	await _frames(1)
	check(camo.action_button.has_focus() and camo.preview.is_live() and camo.preview.stage.outfit() == &"camo" and not rex.preview.is_live(),
		"the focus on Camo's button runs Camo's, and Rex's stops")
	check(_live_count(cards) == 1 and _drawing_count(cards) == 1 and not rex.preview.is_rendering(),
		"…one live viewport, whatever the pointer and the focus do")
	camo.action_button.release_focus()
	await _frames(1)
	check(rex.preview.is_live() and not camo.preview.is_live(), "the focus gone with the pointer still on Rex: Rex runs again")
	rex.mouse_exited.emit()
	check(_live_count(cards) == 0 and _drawing_count(cards) == 0 and not rex.interested, "neither on a card: every preview is a still again")
	# A stopped stage is kept for the next hover, but only the latest one.
	var most_kept: int = 0
	for id: StringName in [&"rex", &"camo", &"beach_master", &"centurion", &"party_wolf"]:
		var card: CosmeticCard = cards[id]
		card.mouse_entered.emit()
		card.mouse_exited.emit()
		var kept: int = 0
		for other: Variant in cards.values():
			kept += 1 if (other as CosmeticCard).preview.stage != null and not (other as CosmeticCard).preview.is_live() else 0
		most_kept = maxi(most_kept, kept)
	check(most_kept == 1 and cards[&"party_wolf"].preview.stage != null,
		"hovering one card after another keeps one stopped stage (the latest), not one for each (%d)" % most_kept)
	# The stage is the runner in the outfit and nothing else, and cheap.
	var stage: OutfitStage = cards[&"party_wolf"].preview.stage
	var equipment: Dictionary = stage.avatar.get_equipment()
	check(not equipment["claws"] and not equipment["armor"] and not equipment["shield"] and not equipment["magnet"]
		and int(equipment["weapon_tier"]) == 0, "the previewed runner wears no power-up")
	check(stage.draw_call_count() <= 25 and stage.avatar.triangle_count() <= 2000,
		"a live preview is %d draw calls and %d triangles" % [stage.draw_call_count(), stage.avatar.triangle_count()])
	var probe := PlayerAvatar.new()
	check(PlayerOutfits.worn == PlayerOutfits.ECHO and probe.outfit() == PlayerOutfits.ECHO,
		"a preview never changes the outfit the game's avatars wear")
	probe.free()
	# The pictures and the live stage trade places on the card.
	var seeded := OutfitPreview.new()
	seeded.size = Vector2(60, 80)
	var seeded_key: String = OutfitStills.key_for(&"party_wolf", OutfitPreview.pixel_size_for(seeded.size, scale))
	var picture := ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))
	OutfitStills._keep(seeded_key, picture)
	seeded.outfit_id = &"party_wolf"
	tree.root.add_child(seeded)
	seeded.size = Vector2(60, 80)
	await _frames(3)
	var shown: TextureRect = seeded.find_child("Picture", false, false) as TextureRect
	check(shown.texture == picture and is_equal_approx(shown.modulate.a, 1.0), "a preview whose picture was drawn before shows it at once, without a fade")
	seeded.set_live(true)
	await _frames(4)
	check(seeded.is_live() and seeded.stage.outfit() == &"party_wolf" and shown.texture == seeded.stage.get_texture(),
		"live, it shows its stage")
	seeded.set_live(false)
	check(not seeded.stage.is_drawing() and shown.texture == picture, "and the picture again when it stops")
	seeded.queue_free()
	# A picture that comes late, after the card was on show without one, fades in.
	var late := OutfitPreview.new()
	late.size = Vector2(60, 80)
	late.outfit_id = &"camo"
	tree.root.add_child(late)
	late.size = Vector2(60, 80)
	await _frames(3)
	var late_key: String = OutfitStills.key_for(&"camo", OutfitPreview.pixel_size_for(late.size, scale))
	late.still_ready(late_key, picture)
	var late_shown: TextureRect = late.find_child("Picture", false, false) as TextureRect
	check(late_shown.texture == picture and late_shown.modulate.a < 1.0, "a picture that arrives late fades in")
	late.free()
	# A picture nobody wants any more isn't drawn.
	var gone := OutfitPreview.new()
	gone.outfit_id = &"rex"
	OutfitStills.request(&"rex", Vector2i(77, 99), gone)
	guard = 0
	while OutfitStills.is_busy() and guard < 300:
		await _frames(1)
		guard += 1
	check(not OutfitStills.drawn.has("rex@77x99"), "a picture no preview in the tree wants is never drawn")
	# …and a burst of them (a window dragged to a new size twelve times) doesn't hold up the one that counts.
	var stale := OutfitPreview.new()
	stale.outfit_id = &"rex"
	for i: int in 12:
		OutfitStills.request(&"rex", Vector2i(100 + i, 130), stale)
	var wanted := OutfitPreview.new()
	wanted.size = Vector2(60, 80)
	wanted.outfit_id = &"beach_master"
	tree.root.add_child(wanted)
	wanted.size = Vector2(60, 80)
	var wanted_key: String = OutfitStills.key_for(&"beach_master", OutfitPreview.pixel_size_for(wanted.size, scale))
	var waited: int = 0
	while not OutfitStills.drawn.has(wanted_key) and waited < 200:
		await _frames(1)
		waited += 1
	check(OutfitStills.drawn.has(wanted_key) and waited <= OutfitStills.FRAMES_BETWEEN + 6,
		"…so a picture asked for behind twelve stale ones is drawn %d frames on" % waited)
	check(not OutfitStills.drawn.has("rex@100x130") and not OutfitStills.drawn.has("rex@111x130"), "none of the stale ones was drawn")
	wanted.free()
	stale.free()
	gone.free()
	# A stage that isn't live doesn't animate (a shared stills stage must not tick on its own).
	var idle := OutfitStage.new()
	tree.root.add_child(idle)
	await _frames(3)
	idle.dress(&"rex")
	check(not idle.is_physics_processing() and not idle.is_live() and not idle.is_drawing(), "a stage nobody runs doesn't process")
	idle.set_live(true)
	check(idle.is_physics_processing() and idle.is_drawing(), "a live one does")
	idle.set_live(false)
	check(not idle.is_physics_processing() and not idle.is_drawing(), "and stops when it stops")
	idle.queue_free()
	# The sizes.
	check(OutfitPreview.pixel_size_for(Vector2(116, 150), 1.0) == Vector2i(116, 150), "a preview is drawn at its own size on a plain screen")
	check(OutfitPreview.pixel_size_for(Vector2(116, 150), 3.0) == Vector2i(232, 300), "no more than twice it on a dense one")
	check(OutfitPreview.pixel_size_for(Vector2(116, 150), 0.2) == Vector2i(58, 75) and OutfitPreview.pixel_size_for(Vector2.ZERO, 1.0) == Vector2i(16, 16),
		"and never under half, nor under 16 pixels")
	check(OutfitStills.key_for(&"rex", Vector2i(10, 20)) == "rex@10x20", "a picture is keyed by outfit and size")


func _live_count(cards: Dictionary) -> int:
	var n: int = 0
	for card: Variant in cards.values():
		n += 1 if (card as CosmeticCard).preview.is_live() else 0
	return n


func _drawing_count(cards: Dictionary) -> int:
	var n: int = 0
	for card: Variant in cards.values():
		n += 1 if (card as CosmeticCard).preview.is_rendering() else 0
	return n


# --- Keyboard and D-pad navigation over the cosmetic cards ------------------------------------------------

func _press(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		tree.root.push_input(event)
	await _frames(2)


## The id of the cosmetic card the focus is in ("" if it is on anything else).
func _focused_card(shop: ShopScreen) -> String:
	var focus: Control = tree.root.gui_get_focus_owner()
	for id: StringName in shop.cosmetic_cards:
		if focus != null and (shop.cosmetic_cards[id] as CosmeticCard).is_ancestor_of(focus):
			return String(id)
	return ""


## Right and left walk the six cards in shop order at any window size (the cards are wider than the items', and the nearest
## button in that direction is an item's), and stop at the ends; down and up move between the rows, and up from the first row
## leaves for the items above.
func _test_navigation(label: String) -> void:
	_fresh(30000)
	App.show_shop()
	await _frames(4)
	var shop := App.screen as ShopScreen
	var order: Array = shop.cosmetic_cards.keys()
	var walk_right: PackedStringArray = []
	var walk_left: PackedStringArray = []
	(shop.cosmetic_cards[order[0]] as CosmeticCard).action_button.grab_focus()
	await _frames(2)
	walk_right.append(_focused_card(shop))
	for i: int in order.size() - 1:
		await _press(&"ui_right")
		walk_right.append(_focused_card(shop))
	await _press(&"ui_right")
	var past_end: String = _focused_card(shop)
	for i: int in order.size() - 1:
		await _press(&"ui_left")
		walk_left.append(_focused_card(shop))
	await _press(&"ui_left")
	var past_start: String = _focused_card(shop)
	var expect_right: PackedStringArray = []
	for id: Variant in order:
		expect_right.append(String(id))
	var expect_left: PackedStringArray = expect_right.duplicate()
	expect_left.reverse()
	expect_left.remove_at(0)
	check(walk_right == expect_right and past_end == String(order[-1]),
		"%s: ui_right walks Echo, Rex, Camo, Beach Master, Centurion, Party Wolf in order and stops there (%s, then %s)" % [label, walk_right, past_end])
	check(walk_left == expect_left and past_start == String(order[0]),
		"%s: ui_left walks back and stops at Echo (%s, then %s)" % [label, walk_left, past_start])
	# Down and up: the card in the row below or above, or out to the items from the first row.
	var buttons: Array = order.map(func(id: Variant) -> Control: return (shop.cosmetic_cards[id] as CosmeticCard).action_button)
	var tops: Array = order.map(func(id: Variant) -> float: return (shop.cosmetic_cards[id] as CosmeticCard).get_global_rect().position.y)
	var first_row: int = 0
	while first_row < order.size() and is_equal_approx(tops[first_row], tops[0]):
		first_row += 1
	var rows_ok: bool = true
	var left_the_grid: bool = true
	for i: int in order.size():
		(buttons[i] as Control).grab_focus()
		await _frames(2)
		await _press(&"ui_up")
		var up: String = _focused_card(shop)
		if i < first_row:
			left_the_grid = left_the_grid and up == "" and tree.root.gui_get_focus_owner() != null
		else:
			rows_ok = rows_ok and up != "" and tops[order.find(StringName(up))] < tops[i]
	check(left_the_grid, "%s: ui_up from the first row leaves the cards for the items above" % label)
	check(rows_ok, "%s: ui_up from a lower row goes to a card in the row above" % label)
	var down_ok: bool = true
	for i: int in order.size():
		(buttons[i] as Control).grab_focus()
		await _frames(2)
		await _press(&"ui_down")
		var down: String = _focused_card(shop)
		if tops[i] < tops[-1]:
			down_ok = down_ok and down != "" and tops[order.find(StringName(down))] > tops[i]
		else:
			down_ok = down_ok and down == String(order[i])
	check(down_ok, "%s: ui_down goes to a card in the row below, and stays on the last row" % label)

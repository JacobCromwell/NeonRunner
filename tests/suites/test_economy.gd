extends TestSuite
## Wallet, items, records, saving, the shop catalog, loadouts and the App's buy flow.


func run() -> void:
	_test_wallet()
	_test_items_and_records()
	_test_save_round_trip()
	_test_catalog_and_loadout()
	_test_app_shop()


func _test_wallet() -> void:
	var p := Profile.new()
	p.add_earned(500)
	p.add_purchased(300)
	check(p.credits() == 800 and p.net_worth() == 500, "earned and bought credits are kept apart (GDD §7)")
	check(p.spend(400) and p.purchased == 0 and p.earned == 400, "spending uses bought credits first, protecting net worth")
	check(not p.spend(401) and p.credits() == 400, "can't overspend, and nothing is taken")
	check(p.lifetime_earned == 500 and p.lifetime_spent == 400, "lifetime totals")
	p.add_earned(-50)
	check(p.earned == 400, "negative earnings are ignored")


func _test_items_and_records() -> void:
	var p := Profile.new()
	p.set_tier(&"weapon", 2)
	p.add_stock(&"shield", 2)
	check(p.tier(&"weapon") == 2 and p.stock(&"shield") == 2, "tiers and stock")
	check(p.use_stock(&"shield") and p.stock(&"shield") == 1, "using an item takes it out of stock")
	check(not p.use_stock(&"grapple"), "nothing to use")
	check(p.is_equipped(&"weapon"), "owned items start switched on")
	p.set_equipped(&"weapon", false)
	check(not p.is_equipped(&"weapon"), "the equip toggle switches items off (GDD §8)")
	var first: Dictionary = p.record_run("city/1", 0, true, 1000, 2, 95.0)
	check(first["first_clear"] and first["new_best"] and first["stars_gained"] == 2, "a first clear is recorded")
	var worse: Dictionary = p.record_run("city/1", 0, true, 800, 1, 99.0)
	check(not worse["new_best"] and p.stars("city/1") == 2, "a worse run keeps the best score and stars")
	var died: Dictionary = p.record_run("city/2", 0, false, 300, 0, 40.0)
	check(not died["first_clear"] and not p.is_completed("city/2"), "a death doesn't complete a level")
	check(int(p.record("city/1").get("attempts", 0)) == 2, "attempts are counted")
	check(not p.is_completed("city/1", 1), "records are kept per difficulty tier")


func _test_save_round_trip() -> void:
	var p := Profile.new()
	p.add_earned(1234)
	p.add_purchased(10)
	p.set_tier(&"magnet", 3)
	p.add_stock(&"revive", 2)
	p.set_equipped(&"magnet", false)
	p.record_run("city/1", 0, true, 999, 3, 90.0)
	p.settings["volume_music"] = 0.25
	p.mark_seen("hint/doghouse")
	var path: String = "user://test_roundtrip.json"
	check(SaveService.save_profile(p, path), "the profile saves")
	check(SaveService.save_profile(p, path), "and saves again over the old file (backup kept)")
	var q: Profile = SaveService.load_profile(path)
	check(q.earned == 1234 and q.purchased == 10 and q.tier(&"magnet") == 3 and q.stock(&"revive") == 2,
		"wallet and items survive a save and load")
	check(not q.is_equipped(&"magnet") and q.stars("city/1") == 3 and q.has_seen("hint/doghouse"),
		"toggles, records and flags survive")
	check(is_equal_approx(float(q.settings["volume_music"]), 0.25), "settings survive")
	check(typeof(q.tiers["magnet"]) == TYPE_INT, "counters stay integers after JSON")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{ broken")
	file.close()
	var r: Profile = SaveService.load_profile(path)
	check(r.earned == 1234, "a corrupt save falls back to the backup")
	SaveService.delete_save(path)
	check(SaveService.load_profile(path).credits() == 0, "no save means a fresh profile")


func _test_catalog_and_loadout() -> void:
	var catalog: ShopCatalog = ShopCatalog.load_from()
	check(catalog.items.size() == 9, "the catalog lists the GDD's nine items (%d)" % catalog.items.size())
	var weapon: ShopItem = catalog.item(&"weapon")
	check(weapon != null and weapon.tier_count() == 4, "the weapon has four tiers (GDD §8)")
	check(weapon.tier_name(1) == "Laser" and weapon.tier_name(4) == "Heavy missile", "tier names")
	check(weapon.price_of(1, false) > 0 and weapon.price_of(5, false) == -1, "tier prices")
	var slow: ShopItem = catalog.item(&"slow_time")
	check(slow.available_on(false) and not slow.available_on(true), "slow time is PC only (GDD §3)")
	check(catalog.items_for(true).size() == 8, "mobile sells everything but slow time")
	for item: ShopItem in catalog.items:
		check(item.display_name != "" and item.description != "", "item '%s' has a name and description" % item.id)
		if item.kind == ShopItem.Kind.BREAKABLE:
			check(item.price_of(1, false) > 0 and item.max_stock > 0, "breakable '%s' has a price and a stock limit" % item.id)

	var p := Profile.new()
	p.set_tier(&"weapon", 2)
	p.set_tier(&"slow_time", 1)
	p.set_tier(&"claws", 1)
	p.add_stock(&"shield", 3)
	p.add_stock(&"revive", 1)
	p.set_equipped(&"claws", false)
	var pc: Loadout = Loadout.from_profile(p, catalog, false)
	check(pc.tier(&"weapon") == 2 and pc.tier(&"slow_time") == 1, "the loadout carries owned tiers")
	check(pc.tier(&"claws") == 0, "switched-off items stay home")
	check(pc.charge(&"shield") == 1, "one shield charge per attempt, spares stay in stock")
	check(pc.charge(&"revive") == 0, "revives are used from stock on the death screen, not carried")
	check(pc.has_armor() and pc.armor and pc.tier(&"armor") == 0 and pc.charge(&"armor") == 0,
		"every run carries the free armor, which is no charge (GDD §4)")
	check(not Loadout.new().has_armor(), "a bare loadout (tests, tools) carries none")
	var mob: Loadout = Loadout.from_profile(p, catalog, true)
	check(mob.tier(&"slow_time") == 0 and mob.has_armor(), "no slow time on mobile; the free armor as everywhere")
	var full: Loadout = Loadout.full(catalog)
	check(full.tier(&"weapon") == 4 and full.charge(&"shield") == 1 and full.tier(&"armor") == 4 and full.has_armor(),
		"the full loadout has everything")


func _test_app_shop() -> void:
	var app: Node = tree.root.get_node_or_null(^"App")
	check(app != null, "the App autoload exists in tests")
	if app == null:
		return
	var saved: Profile = App.profile
	App.profile = Profile.new()
	var weapon: ShopItem = App.catalog.item(&"weapon")
	check(not App.buy(&"weapon"), "can't buy without credits")
	App.profile.add_earned(100000)
	for t: int in 4:
		check(App.buy(&"weapon"), "buys weapon tier %d" % (t + 1))
	check(App.profile.tier(&"weapon") == 4 and App.next_price(weapon) == -1, "the weapon maxes out at tier 4")
	check(not App.buy(&"weapon"), "can't buy past the last tier")
	var shield: ShopItem = App.catalog.item(&"shield")
	for i: int in shield.max_stock:
		App.buy(&"shield")
	check(App.profile.stock(&"shield") == shield.max_stock and not App.buy(&"shield"), "stock stops at the limit")
	var spent: int = 100000 - App.profile.credits()
	var expected: int = 0
	for t: int in 4:
		expected += weapon.price_of(t + 1, false)
	expected += shield.price * shield.max_stock
	check(spent == expected, "prices come from the catalog (%d spent, %d expected)" % [spent, expected])
	App.set_equipped(&"weapon", false)
	check(not App.make_loadout().has(&"weapon"), "the equip toggle reaches the next run's loadout")
	App.profile = saved

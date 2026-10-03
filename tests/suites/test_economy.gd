extends TestSuite
## Wallet, items, records, saving, the shop catalog, loadouts and the App's buy flow. Also the
## balancing pass (task R7, after the owner's playtest: G1's pace, G3's free armor, G4's weaker laser
## tier 1): the catalog's prices laid against what `tools/measure/economy.gd` reads from the campaign
## (the reasoning is in docs/questions/r7.md).

## Mirrors tools/measure/economy.gd's stand-in for a good, not perfect, clean run with no magnet
## (GDD §7 names no number): see that tool's header.
const GOOD_RUN_SHARE: float = 0.7
## The level each item should be in reach by, in a single clean playthrough with nothing bought along
## the way (campaign order, 0-based; GDD §5's schedule, test_campaign.gd's FIRST_LEVEL): armor I is
## the owner's "died a lot" note (GDD §4); claws by Octodog's debut (claws beat tentacles, GDD §8).
## USER_REQUESTS.md approves intentionally lower earnings from 55-second City 1, not compensation:
## after its additive gaps armor I still fits City 1, but laser I moves from City 2 to City 3.
const AFFORD_BY: Dictionary = {
	&"armor:1": "city/1", &"weapon:1": "city/3", &"claws:1": "gangland/2", &"dash:1": "gangland/3",
	&"slow_time:1": "gangland/3",
}


func run() -> void:
	_test_wallet()
	_test_items_and_records()
	_test_save_round_trip()
	_test_catalog_and_loadout()
	_test_app_shop()
	_test_balance_curve()
	_test_shorter_city_earnings()


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


## R7: builds the same running wallet tools/measure/economy.gd reports (every campaign level
## finished once, in order, nothing bought along the way, a good run collecting GOOD_RUN_SHARE of a
## level's credits) and checks the catalog's prices against it: deaths and quits never pay more than
## finishing (GDD §4), every AFFORD_BY item is in reach by its level, and nothing in the catalog costs
## more than a single clean playthrough ever earns (CLAUDE.md: nothing a first playthrough can't
## afford). Also the star thresholds (GDD §6): two_star_share < three_star_share, so they still order
## correctly, and a clean run (well above the good-run share) clears three stars on credits alone,
## without needing bonus points. 5 lanes only (PC default): lane count moves each level's credit total
## a little but not the shape of the curve (see the tool's own README entry for the full sweep).
func _test_balance_curve() -> void:
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var tuning := load("res://data/tuning/movement.tres") as MovementTuning
	var rules := load("res://data/tuning/game_rules.tres") as GameRules
	var catalog: ShopCatalog = ShopCatalog.load_from()
	check(rules.two_star_share < rules.three_star_share and rules.three_star_share <= 1.0,
		"the star shares still order two below three (%.2f < %.2f)" % [rules.two_star_share, rules.three_star_share])
	var wallet_by_level: Dictionary = {}
	var wallet: int = 0
	var max_wallet: int = 0
	for step: CampaignStep in campaign.steps():
		if not step.is_level():
			continue
		var config: LevelConfig = campaign.configure(step, 5)
		# T-SPEED: this level's own default build (LayoutCache), shared with other suites.
		var layout: LevelLayout = LayoutCache.generate(config, tuning, LevelGenerator.load_for(config))
		var available: int = layout.total_credit_value()
		var good: int = roundi(available * GOOD_RUN_SHARE)
		var bonus: int = rules.completion_bonus(step.level_index)
		var finish: int = good + bonus
		var death: int = floori(good * rules.death_credit_keep_fraction)
		check(death < finish, "%s: a death or quit never pays more than finishing (%d < %d)" % [step.id, death, finish])
		# A clean run (well above the good-run share) clears three stars on credits alone: the share
		# formula is scale-invariant (score and max_credit_score are both counted in credits), so this
		# holds for every level once it holds for one, but it's checked per level to catch a future
		# level-specific credit source the generator folds into max_credit_score oddly.
		check(available > 0 and 0.9 >= rules.three_star_share,
			"%s: a clean run's share (0.9) still clears three stars (needs %.2f)" % [step.id, rules.three_star_share])
		wallet += finish
		wallet_by_level[step.id] = wallet
		max_wallet = wallet
	for key: String in AFFORD_BY:
		var item_id: StringName = StringName(String(key).get_slice(":", 0))
		var tier: int = int(String(key).get_slice(":", 1))
		var item: ShopItem = catalog.item(item_id)
		var price: int = item.price_of(tier, false)
		var by_wallet: int = int(wallet_by_level[AFFORD_BY[key]])
		check(price <= by_wallet, "%s is affordable by %s (price %d, wallet %d)" % [
			item.tier_name(tier), AFFORD_BY[key], price, by_wallet])
	check(int(wallet_by_level["city/2"]) < catalog.item(&"weapon").price_of(1, false),
		"intentional early earnings delay laser I until City 3 (City 2 wallet %d)" % wallet_by_level["city/2"])
	for item: ShopItem in catalog.items:
		var prices: Array[int] = []
		if item.kind == ShopItem.Kind.BREAKABLE:
			prices.append(item.price)
		else:
			for t: int in item.tier_count():
				prices.append(item.price_of(t + 1, false))
		for price: int in prices:
			check(price <= max_wallet, "%s never costs more than one clean playthrough ever earns (%d <= %d)" % [
				item.display_name, price, max_wallet])


## Isolate the approved duration change from the later additive gaps, using copies only.
func _test_shorter_city_earnings() -> void:
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var movement := load("res://data/tuning/movement.tres") as MovementTuning
	var rules := load("res://data/tuning/game_rules.tres") as GameRules
	var step: CampaignStep = campaign.step("city/1")
	var shipped: LevelConfig = campaign.configure(step, 5)
	var shortened: LevelConfig = shipped.duplicate() as LevelConfig
	shortened.gap_encounter_increase = 0.0
	shortened.gap_lane_increase = 0.0
	var former: LevelConfig = shortened.duplicate() as LevelConfig
	former.duration_seconds = 110.0
	var patterns: Array = LevelGenerator.load_for(shortened)
	var short_layout: LevelLayout = LevelGenerator.new().generate(shortened, movement, patterns)
	var former_layout: LevelLayout = LevelGenerator.new().generate(former, movement, patterns)
	var short_credits: int = short_layout.total_credit_value()
	var former_credits: int = former_layout.total_credit_value()
	var bonus: int = rules.completion_bonus(step.level_index)
	var short_wallet: int = roundi(short_credits * GOOD_RUN_SHARE) + bonus
	var former_wallet: int = roundi(former_credits * GOOD_RUN_SHARE) + bonus
	print("  City 1 isolated shortening (no additive gaps): 110s %d credits / %d wallet -> 55s %d credits / %d wallet"
		% [former_credits, former_wallet, short_credits, short_wallet])
	check(shipped.duration_seconds == 55.0 and step.level.duration_seconds == 55.0,
		"isolated comparison never restores the shared City 1 duration")
	check(shipped.gap_encounter_increase == 0.3 and shipped.gap_lane_increase == 0.3
		and step.level.gap_encounter_increase == 0.3 and step.level.gap_lane_increase == 0.3,
		"isolated comparison never disables the shared approved additive gaps")
	check(is_equal_approx(former_layout.length, short_layout.length * 2.0),
		"halving City 1's duration halves its length, not its speed")
	check(short_credits > 0 and short_credits < former_credits and short_wallet < former_wallet,
		"shorter City 1 intentionally earns less, without credit or finish-payout compensation")

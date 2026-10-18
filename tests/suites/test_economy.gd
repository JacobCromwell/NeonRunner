extends TestSuite
## Wallet, items, records, saving, the shop catalog, loadouts and the App's buy flow. Also the
## balancing passes (task R7, after the owner's playtest: G1's pace, G3's free armor, G4's weaker laser
## tier 1; task I7, the rebalance for all eight zones): the catalog's prices laid against what
## `tools/measure/economy.gd` reads from the campaign (the reasoning is in items 846-850 in docs/OPEN_QUESTIONS*.md and
## docs/architecture/economy-platforms.md).

## The model the tool reports: a typical and a weaker player's walks through the campaign (see its header).
const EconomyModel = preload("res://tools/measure/economy_model.gd")
## I7: the level each tier of the shop first fits at, for a typical player on PC (5 lanes, each level's own seed)
## who finishes every level once, in order, and buys nothing along the way, not counting the boss payouts (the
## owner's October 3 anchors were measured "with no purchases or boss payouts"). A tier costs its line total (its
## price and every tier before it: tiers are bought in order). "First fits at N" means affordable after finishing
## N, so usable from N + 1. Campaign levels, with the volleyball match counted: City 1-3 are levels 1-3, Gangland
## 1-3 4-6, Marketplace 1-2 7-8, Casino 1-2 9-10, Corporate 1-2 11-12, Beach 1-3 13-15, Dead Zone 1-2 16-17,
## Golden 1-3 18-20. Where each is placed (GDD §5's schedule; the reasoning is in items 846-850 in docs/OPEN_QUESTIONS*.md):
##   armor I the owner's "died a lot" note (GDD §4, the October 3 early-economy revision: it fits City 1); II at
##   Gangland 1, III at Marketplace 2 (usable from the Casino's mixed crowd), IV at Beach 3 (usable from the
##   Dead Zone, whose Bad Dreams ignore weapons); laser I Gangland 1 (the owner: 1,800, first affordable at the
##   campaign's 4th level); laser II Marketplace 1, missile Corporate 1, heavy missile Golden 1 (usable from
##   Golden 2, the Sentinels' debut); claws Gangland 2; the dash (the owner's prices of October 17, 2026: 300 / 450 /
##   600 / 700, task L8) at City 1, 2 and 3, so tiers I to III are owned before the City's boss, and IV at Gangland 1;
##   magnet I as an early credit boost, II at Gangland 1, III at Marketplace 2; slow time (PC only) as it was.
## Where that is later than the enemy it answers debuts (the Octodog in Gangland 2, the Barnacle Turret in
## Marketplace 1, Buzz Overdrive in Corporate 1), it is in time only once the boss payouts are counted (IN_TIME).
## DESIGN-TBD (items 846-850 in docs/OPEN_QUESTIONS*.md): the placements the GDD says nothing about.
const FIRST_FIT: Dictionary = {
	&"armor:1": "city/1", &"armor:2": "gangland/1", &"armor:3": "marketplace/2", &"armor:4": "beach/3",
	&"weapon:1": "gangland/1", &"weapon:2": "marketplace/1", &"weapon:3": "corporate/1", &"weapon:4": "golden/1",
	&"claws:1": "gangland/2",
	&"dash:1": "city/1", &"dash:2": "city/2", &"dash:3": "city/3", &"dash:4": "gangland/1",
	&"magnet:1": "city/2", &"magnet:2": "gangland/1", &"magnet:3": "marketplace/2",
	&"slow_time:1": "gangland/2",
}
## The step by whose end a tier must be affordable once the boss payouts are counted (a boss pays on the win, and
## the next zone opens only after it, so every player past a boss has been paid), so it is usable before the enemy
## or zone that wants it: claws before the Octodog (Gangland 2), the Enhanced laser before the Barnacle Turret
## (Marketplace 1), the dash's tiers I and III before the City's boss, IV by Gangland 1, the Missile before Buzz
## Overdrive (Corporate 1), Armor IV before the Dead Zone, the Heavy missile before Golden 1.
const IN_TIME: Dictionary = {
	&"claws:1": "gangland/1", &"weapon:2": "gangland/3", &"dash:1": "city/3", &"dash:3": "city/3", &"dash:4": "gangland/1",
	&"weapon:3": "casino/2",
	&"armor:4": "beach/3", &"weapon:4": "dead_zone/2",
}
## How many levels either side of its place a tier may first fit. The credits a layout holds move as the generator's
## later tasks add and shift them, and a place that is a level out only means the same price lands a level
## earlier or later, so this absorbs drift without hiding a real shift in the curve.
const FIT_TOLERANCE: int = 1


func run() -> void:
	_test_wallet()
	_test_items_and_records()
	_test_save_round_trip()
	_test_catalog_and_loadout()
	_test_dash_catalog_and_saves()
	_test_app_shop()
	_test_dash_shop()
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
	check(pc.charge(&"shield") == 3, "shields stack: every shield in stock comes into the run")
	p.add_stock(&"grapple", 2)
	check(Loadout.from_profile(p, catalog, false).charge(&"grapple") == 1, "one grapple per attempt, spares stay in stock")
	check(pc.charge(&"revive") == 0, "revives are used from stock on the death screen, not carried")
	check(pc.has_armor() and pc.armor and pc.tier(&"armor") == 0 and pc.charge(&"armor") == 0,
		"every run carries the free armor, which is no charge (GDD §4)")
	check(not Loadout.new().has_armor(), "a bare loadout (tests, tools) carries none")
	var mob: Loadout = Loadout.from_profile(p, catalog, true)
	check(mob.tier(&"slow_time") == 0 and mob.has_armor(), "no slow time on mobile; the free armor as everywhere")
	var full: Loadout = Loadout.full(catalog)
	check(full.tier(&"weapon") == 4 and full.charge(&"shield") == 1 and full.tier(&"armor") == 4 and full.has_armor(),
		"the full loadout has everything")


func _test_dash_catalog_and_saves() -> void:
	var catalog: ShopCatalog = ShopCatalog.load_from()
	var dash: ShopItem = catalog.item(&"dash")
	var prices: PackedInt32Array = PackedInt32Array([300, 450, 600, 700])
	var cooldowns: PackedInt32Array = PackedInt32Array([8, 6, 4, 3])
	check(dash != null and dash.kind == ShopItem.Kind.PERMANENT and dash.tier_count() == 4,
		"dash has exactly four permanent tiers, not four upgrades after the base tier")
	if dash == null:
		return
	check(catalog.items[0].id == &"dash" and catalog.items_for(false)[0].id == &"dash" and catalog.items_for(true)[0].id == &"dash",
		"the dash is the first item in the catalog, on PC and mobile (L8; the web demo sells the same catalog)")
	for tier: int in range(1, 5):
		check(dash.price_of(tier, false) == prices[tier - 1] and dash.price_of(tier, true) == prices[tier - 1],
			"dash tier %d keeps the approved PC/mobile price (%d)" % [tier, prices[tier - 1]])
		check(dash.tier_description(tier).contains("%d seconds" % cooldowns[tier - 1]),
			"dash tier %d describes its %d-second cooldown" % [tier, cooldowns[tier - 1]])
	check(dash.price_of(5, false) == -1 and Loadout.full(catalog).tier(&"dash") == 4,
		"there is no fifth dash tier, and a full loadout carries tier 4")
	check(Profile.from_dict({}).tier(&"dash") == 0, "an existing save without dash remains unowned")

	for version: int in [1, Profile.VERSION]:
		var legacy: Profile = Profile.from_dict({
			"version": version, "earned": 2500, "purchased": 100,
			"tiers": {"dash": 1.0, "weapon": 2.0}, "stocks": {"shield": 2.0},
			"equip_off": {"dash": true}, "settings": {"volume_music": 0.25},
			"records": {"0/city/1": {"completed": true, "stars": 2}},
		})
		check(legacy.tier(&"dash") == 1 and typeof(legacy.tiers["dash"]) == TYPE_INT,
			"save version %d retains the original dash at tier 1 without granting upgrades" % version)
		check(legacy.credits() == 2600 and legacy.tier(&"weapon") == 2 and legacy.stock(&"shield") == 2
			and not legacy.is_equipped(&"dash") and legacy.stars("city/1") == 2,
			"expanding dash tiers preserves version %d's wallet, other items, equip toggle and progress" % version)

	var path: String = "user://test_dash_tiers_roundtrip.json"
	SaveService.delete_save(path)
	var p := Profile.new()
	p.add_earned(1234)
	p.set_tier(&"weapon", 2)
	p.add_stock(&"shield", 2)
	p.set_equipped(&"dash", false)
	for tier: int in range(1, 5):
		p.set_tier(&"dash", tier)
		check(SaveService.save_profile(p, path), "dash tier %d saves" % tier)
		var q: Profile = SaveService.load_profile(path)
		check(q.tier(&"dash") == tier and typeof(q.tiers.get("dash")) == TYPE_INT
			and not q.is_equipped(&"dash") and q.credits() == 1234
			and q.tier(&"weapon") == 2 and q.stock(&"shield") == 2,
			"dash tier %d, equip state and unrelated ownership survive a disk round trip" % tier)
		for mobile: bool in [false, true]:
			check(not Loadout.from_profile(q, catalog, mobile).has(&"dash"),
				"a saved disabled dash stays out of the %s loadout" % ["mobile" if mobile else "PC"])
			q.set_equipped(&"dash", true)
			check(Loadout.from_profile(q, catalog, mobile).tier(&"dash") == tier,
				"the enabled %s loadout carries saved dash tier %d" % ["mobile" if mobile else "PC", tier])
			q.set_equipped(&"dash", false)
	SaveService.delete_save(path)


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


func _test_dash_shop() -> void:
	var saved: Profile = App.profile
	var saved_mobile: bool = App.mobile
	var dash: ShopItem = App.catalog.item(&"dash")
	var prices: PackedInt32Array = PackedInt32Array([300, 450, 600, 700])
	for mobile: bool in [false, true]:
		App.mobile = mobile
		App.profile = Profile.new()
		App.profile.add_earned(299)
		check(not App.buy(&"dash") and App.profile.tier(&"dash") == 0 and App.profile.credits() == 299,
			"the dash's first tier costs 300, and 299 buys nothing")
		App.profile.add_earned(1751)
		var expected_balance: int = 2050
		for tier: int in range(1, 5):
			check(App.next_price(dash) == prices[tier - 1] and App.buy(&"dash"),
				"%s buys dash tier %d sequentially for %d credits" % ["mobile" if mobile else "PC", tier, prices[tier - 1]])
			expected_balance -= prices[tier - 1]
			check(App.profile.tier(&"dash") == tier and App.profile.credits() == expected_balance
				and App.make_loadout().tier(&"dash") == tier,
				"dash tier %d ownership and exact debit reach the next loadout" % tier)
		check(App.next_price(dash) == -1 and not App.buy(&"dash") and App.profile.tier(&"dash") == 4
			and App.profile.credits() == 0 and App.profile.lifetime_spent == 2050,
			"dash maxes at tier 4 without a fifth purchase or extra spending")

		App.profile = Profile.from_dict({
			"version": 1, "earned": 2050, "tiers": {"dash": 1}, "equip_off": {"dash": true},
		})
		App.profile.earned = 449
		check(App.next_price(dash) == 450 and not App.buy(&"dash")
			and App.profile.credits() == 449 and App.profile.tier(&"dash") == 1,
			"a legacy owner cannot buy tier 2 with fewer than 450 credits")
		App.profile.earned = 1750
		for tier: int in range(2, 5):
			check(App.buy(&"dash") and App.profile.tier(&"dash") == tier,
				"a legacy base owner buys only upgrade tier %d, not the base again" % tier)
		check(App.profile.credits() == 0 and not App.profile.is_equipped(&"dash") and not App.make_loadout().has(&"dash"),
			"the three upgrades cost 1750 total and preserve a legacy owner's off toggle")
		App.set_equipped(&"dash", true)
		check(App.make_loadout().tier(&"dash") == 4, "re-equipping a saved owner carries the final dash tier")
	App.profile = saved
	App.mobile = saved_mobile


## The campaign's economy as tools/measure/economy.gd reads it (tools/measure/economy_model.gd, shared): the
## campaign's levels, the volleyball match and the bosses in order, the credits each level offers at `lanes`
## lanes (each level's own seed, the layout cache), and the typical and weaker players' walks through them
## (nothing bought along the way). `only` limits the steps by id. Returns {rows, typical, weaker}.
func _economy(lanes: int, only: PackedStringArray = PackedStringArray()) -> Dictionary:
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var tuning := load("res://data/tuning/movement.tres") as MovementTuning
	var rules := load("res://data/tuning/game_rules.tres") as GameRules
	var measure := func(c: Campaign, step: CampaignStep) -> Dictionary:
		var config: LevelConfig = c.configure(step, lanes)
		# T-SPEED: this level's own default build (LayoutCache), shared with other suites.
		var layout: LevelLayout = LayoutCache.generate(config, tuning, LevelGenerator.load_for(config))
		return {"credits": layout.total_credit_value(), "stash": layout.total_credit_value() - layout.star_credit_value()}
	var rows: Array[Dictionary] = EconomyModel.rows(campaign, measure, only)
	var players: Array[Dictionary] = EconomyModel.players(rules)
	return {"rows": rows, "typical": EconomyModel.walk(players[0], rules, rows),
		"weaker": EconomyModel.walk(players[1], rules, rows)}


## The index of the step with id `id` in `rows` (campaign order, bosses included).
func _row_of(rows: Array[Dictionary], id: String) -> int:
	for i: int in rows.size():
		if String(rows[i]["id"]) == id:
			return i
	return -1


## Whether `price` fits the walk's wallet (the levels and the match only, or with the boss payouts) by the end of
## step `id`.
func _fits_by(walk: Array[Dictionary], rows: Array[Dictionary], price: int, with_bosses: bool, id: String) -> bool:
	var at: int = EconomyModel.first_fit(walk, rows, price, with_bosses)
	return at >= 0 and at <= _row_of(rows, id)


## R7, I7: lays the catalog's prices against the campaign's economy. A tier costs its price and every tier before
## it (tiers are bought in order): its line total. It first fits at the first level, counting the volleyball
## match, whose running wallet (a typical player finishing every level once, in order, buying nothing along the
## way, and not counting the boss payouts) covers that. Each tier is pinned to the level it was placed at
## (FIRST_FIT, GDD §5's schedule; the reasoning is in items 846-850 in docs/OPEN_QUESTIONS*.md and docs/architecture/economy-platforms.md),
## give or take FIT_TOLERANCE levels. Also: the owner's anchors (Armor I fits City 1, Laser I first fits at the 4th
## level and costs 1,800), deaths and quits never pay more than finishing (GDD §4), the star shares still order,
## every tier is in reach within one playthrough, a weaker player and a mobile one still reach the early tiers
## close behind, and the breakables stay cheap to restock. 5 lanes (PC's default): the lane count moves each
## level's credit total a little but not the shape of the curve (the tool's own sweep shows it).
func _test_balance_curve() -> void:
	var rules := load("res://data/tuning/game_rules.tres") as GameRules
	var catalog: ShopCatalog = ShopCatalog.load_from()
	check(rules.two_star_share < rules.three_star_share and rules.three_star_share <= 1.0,
		"the star shares still order two below three (%.2f < %.2f)" % [rules.two_star_share, rules.three_star_share])
	var economy: Dictionary = _economy(5)
	var rows: Array[Dictionary] = economy["rows"]
	var typical: Array[Dictionary] = economy["typical"]
	var weaker: Array[Dictionary] = economy["weaker"]
	for i: int in rows.size():
		if String(rows[i]["kind"]) != "level":
			continue
		# Deaths and quits never pay more than finishing; a clean run (well above the good-run share) clears three
		# stars on credits alone (the share formula is scale-invariant, so this holds for every level once it holds
		# for one, but it's checked per level to catch a future level-specific credit source the generator folds
		# into max_credit_score oddly).
		check(float(rows[i]["credits"]) > 0 and int(typical[i]["death"]) < int(typical[i]["finish"]),
			"%s: a death or quit never pays more than finishing (%d < %d)" % [rows[i]["id"], typical[i]["death"], typical[i]["finish"]])
		check(0.9 >= rules.three_star_share, "%s: a clean run's share (0.9) still clears three stars (needs %.2f)" % [
			rows[i]["id"], rules.three_star_share])

	# Every tier is pinned to the level it first fits at.
	for item: ShopItem in catalog.items:
		if item.kind != ShopItem.Kind.PERMANENT:
			continue
		for t: int in item.tier_count():
			check(FIRST_FIT.has(StringName("%s:%d" % [item.id, t + 1])),
				"%s tier %d has a level it should first fit at (FIRST_FIT)" % [item.id, t + 1])
	for key: StringName in FIRST_FIT:
		var item: ShopItem = catalog.item(StringName(String(key).get_slice(":", 0)))
		var tier: int = int(String(key).get_slice(":", 1))
		var line: int = EconomyModel.line_totals(item, false)[tier - 1]
		var at: int = EconomyModel.first_fit(typical, rows, line, false)
		var want: int = int(rows[_row_of(rows, FIRST_FIT[key])]["number"])
		var got: int = int(rows[at]["number"]) if at >= 0 else -1
		check(got > 0 and absi(got - want) <= FIT_TOLERANCE,
			"%s (line %d) first fits at level %d (%s), pinned to level %d (%s) give or take %d" % [
				item.tier_name(tier), line, got, rows[at]["id"] if at >= 0 else "beyond the campaign", want,
				FIRST_FIT[key], FIT_TOLERANCE])

	# In time for what wants them, once the boss payouts are counted (IN_TIME).
	for key: StringName in IN_TIME:
		var item: ShopItem = catalog.item(StringName(String(key).get_slice(":", 0)))
		var tier: int = int(String(key).get_slice(":", 1))
		var line: int = EconomyModel.line_totals(item, false)[tier - 1]
		check(_fits_by(typical, rows, line, true, IN_TIME[key]),
			"%s (line %d) is affordable by the end of %s, boss payouts counted" % [item.tier_name(tier), line, IN_TIME[key]])

	# The owner's anchors. The October 3 early-economy revision: armor I fits City 1 (its lower earnings are
	# intentional, tests change instead of rewards or prices). Laser I costs 1,800 and first fits at the
	# campaign's 4th level, Gangland 1: City 3's wallet is short of it.
	check(catalog.item(&"armor").price_of(1, false) == 350 and catalog.item(&"weapon").price_of(1, false) == 1800,
		"Armor I costs 350 and Laser I 1,800")
	check(EconomyModel.first_fit(typical, rows, 350, false) == _row_of(rows, "city/1"),
		"Armor I fits City 1 (wallet %d)" % typical[0]["wallet"])
	var laser_at: int = EconomyModel.first_fit(typical, rows, 1800, false)
	check(laser_at == _row_of(rows, "gangland/1") and int(rows[laser_at]["number"]) == 4,
		"Laser I first fits at the campaign's 4th level, Gangland 1")
	check(int(typical[_row_of(rows, "city/3")]["wallet"]) < 1800 and int(typical[laser_at]["wallet"]) >= 1800,
		"City 3's wallet (%d) is short of Laser I; Gangland 1's (%d) covers it" % [
			typical[_row_of(rows, "city/3")]["wallet"], typical[laser_at]["wallet"]])

	# Every tier is in reach within a single playthrough: a typical player's wallet (no boss payouts) covers
	# the longest line, and so does a weaker one's with the boss payouts they must win to progress.
	var last: int = rows.size() - 1
	for item: ShopItem in catalog.items:
		var longest: int = item.price
		if item.kind == ShopItem.Kind.PERMANENT:
			var lines: PackedInt32Array = EconomyModel.line_totals(item, false)
			longest = lines[lines.size() - 1]
		check(longest <= int(typical[last]["wallet"]), "%s never costs more than one clean playthrough earns (%d <= %d)" % [
			item.display_name, longest, typical[last]["wallet"]])
		check(longest <= int(weaker[last]["wallet_all"]), "%s is within a weaker player's one playthrough, bosses included (%d <= %d)" % [
			item.display_name, longest, weaker[last]["wallet_all"]])

	# A weaker player (the two-star line, two failed tries a level) is not left far behind early.
	check(_fits_by(weaker, rows, 350, false, "city/2"), "a weaker player affords Armor I by City 2")
	check(_fits_by(weaker, rows, 1800, false, "gangland/2"), "a weaker player affords Laser I by Gangland 2")

	# The breakables stay cheap to restock: each costs at most a finish and a half of a typical player from City 2 on,
	# and the three together at most two and a half finishes from City 3 on.
	var restock: int = 0
	for item: ShopItem in catalog.items:
		if item.kind == ShopItem.Kind.BREAKABLE:
			restock += item.price
	for i: int in range(_row_of(rows, "city/2"), rows.size()):
		if String(rows[i]["kind"]) != "level":
			continue
		var finish: float = typical[i]["finish"]
		for item: ShopItem in catalog.items:
			if item.kind == ShopItem.Kind.BREAKABLE:
				check(float(item.price) <= 1.5 * finish, "%s: a %s (%d) costs at most a finish and a half (%d)" % [
					rows[i]["id"], item.id, item.price, finish])
		if i >= _row_of(rows, "city/3"):
			check(float(restock) <= 2.5 * finish, "%s: restocking a shield, grapple and revive (%d) is at most two and a half finishes (%d)" % [
				rows[i]["id"], restock, finish])

	# 3 lanes (mobile's count until October 18, 2026; it is 5 now, like PC, so this guards a smaller count if a
	# platform goes back to it): fewer credits, the same shape (the tool's --lanes=3 reads the whole campaign; this
	# generates only the first five levels): Armor I by City 2, Laser I by Gangland 2.
	var mobile: Dictionary = _economy(3, PackedStringArray(["city/1", "city/2", "city/3", "gangland/1", "gangland/2"]))
	var m_rows: Array[Dictionary] = mobile["rows"]
	var m_typical: Array[Dictionary] = mobile["typical"]
	check(_fits_by(m_typical, m_rows, 350, false, "city/2"), "a 3-lane player affords Armor I by City 2")
	check(_fits_by(m_typical, m_rows, 1800, false, "gangland/2"), "a 3-lane player affords Laser I by Gangland 2")


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
	var share: float = EconomyModel.players(rules)[0]["share"]
	var short_wallet: int = roundi(short_credits * share) + bonus
	var former_wallet: int = roundi(former_credits * share) + bonus
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

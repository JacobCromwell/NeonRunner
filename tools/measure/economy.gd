extends SceneTree
## Measures the campaign's economy (task R7, after the owner's playtest changed the pace (G1), the
## armor (G3) and laser tier 1 (G4)): per level and per zone, the credits available, what a good run
## collects, the payout for finishing, and what a death or quit pays (GDD §4: never more than
## finishing); then lays the shop's prices (data/shop/catalog.json) against that progression, so a
## balancing pass can see what a player who finishes each level once, in order, can afford, and how
## many retries' worth of credits each item costs. From the project folder (with XDG_DATA_HOME set as
## for the tests):
##   godot --headless -s res://tools/measure/economy.gd -- [options]
## Options:
##   --levels=city/1,gangland/2   campaign steps (default: every level)
##   --lanes=3,5,6                lane counts (default 3,5,6)
##   --seeds=N                    each level's own seed and N others (default 2)
##   --share=0.7                  the share of a level's credits a good run collects (default 0.7;
##                                GDD §7 names no number, so this stands in for "a good, not perfect,
##                                clean run with no magnet": reported, not a design decision)
##   --mobile=true|false          lane count and prices for mobile's catalog prices (default false, PC)
##   --packs                      also print the mobile credit packs (StubBackend.FAKE_PRODUCTS,
##                                OPEN_QUESTIONS §7) against the curve
## Use --lanes=5 --seeds=0 --share=0.7 to reproduce test_economy.gd's affordability curve.
## Its wallet excludes boss payouts; the separate zone summary includes built bosses.
##
## Per level: run speed, length, credits available (a layout's total_credit_value(), averaged over
## lane counts and seeds), a good run's share of them, the completion bonus (GameRules.
## completion_bonus), the finish payout (both), what a death or quit pays (death_credit_keep_fraction
## of the good run's credits, GDD §4), and the wallet's running total for a player who finishes every
## level once, in order (no deaths, no retries, nothing bought). Per zone: the same, summed, plus its
## boss's payout if it has a built boss scene. Then the shop: every item and tier, its price, the
## first level (in campaign order) the running wallet can afford it at, and how many of that level's
## finish payouts the price costs (a rough "how many retries" reading, since a death pays less).

const CAMPAIGN_PATH: String = "res://data/campaign/campaign.tres"
const TUNING_PATH: String = "res://data/tuning/movement.tres"
const RULES_PATH: String = "res://data/tuning/game_rules.tres"

var _levels: PackedStringArray = []
var _lanes: Array[int] = [3, 5, 6]
var _seeds: int = 2
var _share: float = 0.7
var _mobile: bool = false
var _packs: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_parse_args()
	var campaign := load(CAMPAIGN_PATH) as Campaign
	var tuning := load(TUNING_PATH) as MovementTuning
	var rules := load(RULES_PATH) as GameRules
	var catalog: ShopCatalog = ShopCatalog.load_from()
	if _levels.is_empty():
		for s: CampaignStep in campaign.steps():
			if s.is_level():
				_levels.append(s.id)
	var rows: Array[Dictionary] = []
	print("%-16s %5s %5s %6s | %8s %6s %8s %8s | %6s %8s" % [
		"level", "m/s", "s", "zone", "credits", "good", "finish", "death/quit", "bonus", "wallet"])
	var wallet: int = 0
	var zone_sums: Dictionary = {}
	var zone_order: Array[String] = []
	for id: String in _levels:
		var step: CampaignStep = campaign.step(id)
		if step == null or not step.is_level():
			print("%s: not a campaign level" % id)
			continue
		var r: Dictionary = _measure_level(campaign, tuning, step)
		var good: int = roundi(float(r["credits"]) * _share)
		var bonus: int = rules.completion_bonus(step.level_index)
		var finish: int = good + bonus
		var death: int = floori(float(good) * rules.death_credit_keep_fraction)
		wallet += finish
		r.merge({"id": id, "good": good, "bonus": bonus, "finish": finish, "death": death, "wallet": wallet,
			"zone": step.zone.display_name, "zone_id": _zone_id(step), "number": _level_number(campaign, step)})
		rows.append(r)
		print("%-16s %5.1f %5.0f %6s | %8.0f %6.0f %8.0f %8.0f | %6.0f %8.0f" % [
			id, r["speed"], r["seconds"], step.zone.display_name.substr(0, 6),
			r["credits"], good, finish, death, bonus, wallet])
		var zid: String = _zone_id(step)
		if not zone_sums.has(zid):
			zone_sums[zid] = {"credits": 0.0, "good": 0, "finish": 0, "levels": 0, "name": step.zone.display_name}
			zone_order.append(zid)
		var zs: Dictionary = zone_sums[zid]
		zs["credits"] = float(zs["credits"]) + float(r["credits"])
		zs["good"] = int(zs["good"]) + good
		zs["finish"] = int(zs["finish"]) + finish
		zs["levels"] = int(zs["levels"]) + 1

	print("")
	print("%-16s %6s %8s %8s %10s %8s" % ["zone", "levels", "credits", "good run", "boss payout", "wallet"])
	var zone_wallet: int = 0
	for zid: String in zone_order:
		var zs: Dictionary = zone_sums[zid]
		zone_wallet += int(zs["finish"])
		var payout: int = _boss_payout(campaign, zid)
		if payout > 0:
			zone_wallet += payout
		print("%-16s %6d %8.0f %8d %10s %8d" % [zs["name"], zs["levels"], zs["credits"], zs["good"],
			("%d" % payout) if payout > 0 else "-", zone_wallet])

	_print_shop(catalog, rows)
	if _packs:
		_print_packs(rows)
	quit(0)


## Level step `step`'s number in the order the campaign plays its levels (1 for the first). Not its
## level_index, its place on the difficulty curve, which a level off the curve (the Beach's) shares.
func _level_number(campaign: Campaign, step: CampaignStep) -> int:
	var n: int = 0
	for s: CampaignStep in campaign.steps():
		if s.is_level():
			n += 1
		if s == step:
			return n
	return 0


func _zone_id(step: CampaignStep) -> String:
	return "%d_%s" % [step.zone_index, step.zone.display_name]


## The zone's boss payout if its scene is built (an unbuilt slot's placeholder number would be
## misleading to add to the curve); 0 if the zone has no boss step or it isn't built yet.
func _boss_payout(campaign: Campaign, zid: String) -> int:
	for s: CampaignStep in campaign.steps():
		if s.kind == CampaignStep.Kind.BOSS and _zone_id(s) == zid:
			return s.boss.payout_credits if s.boss != null and s.boss.scene != "" else 0
	return 0


func _measure_level(campaign: Campaign, tuning: MovementTuning, step: CampaignStep) -> Dictionary:
	var credits_sum: float = 0.0
	var speed_sum: float = 0.0
	var seconds_sum: float = 0.0
	var n: int = 0
	for lanes: int in _lanes:
		for k: int in _seeds + 1:
			var config: LevelConfig = campaign.configure(step, lanes)
			if k > 0:
				config.level_seed = 9000 + k
			var gen := LevelGenerator.new()
			var layout: LevelLayout = gen.generate(config, tuning, LevelGenerator.load_for(config))
			credits_sum += layout.total_credit_value()
			speed_sum += gen.speed
			seconds_sum += layout.length / gen.speed
			n += 1
	return {"credits": credits_sum / n, "speed": speed_sum / n, "seconds": seconds_sum / n}


## For each item and tier: its price, the first level in campaign order the running wallet (no
## purchases, no deaths) can afford it at, and the price as a share of that level's finish payout
## (a rough "how many finishes" reading).
func _print_shop(catalog: ShopCatalog, rows: Array[Dictionary]) -> void:
	print("")
	print("%-24s %8s | %-14s %10s %10s" % ["item", "price", "afforded after", "wallet then", "x finish"])
	for item: ShopItem in catalog.items_for(_mobile):
		if item.kind == ShopItem.Kind.PERMANENT:
			for t: int in item.tier_count():
				_print_afford("%s (%s)" % [item.display_name, item.tier_name(t + 1)], item.price_of(t + 1, _mobile), rows)
		else:
			_print_afford(item.display_name, item.price_of(1, _mobile), rows)


func _print_afford(label: String, price: int, rows: Array[Dictionary]) -> void:
	for r: Dictionary in rows:
		if int(r["wallet"]) >= price:
			print("%-24s %8d | %-14s %10d %9.1fx" % [label, price, "%s (lvl %d)" % [_level_label(r), int(r["number"])],
				int(r["wallet"]), float(price) / maxf(float(r["finish"]), 1.0)])
			return
	print("%-24s %8d | %s" % [label, price, "not affordable from one clean playthrough"])


func _level_label(r: Dictionary) -> String:
	return "%s" % r.get("id", "")


## The mobile credit packs (StubBackend.FAKE_PRODUCTS; OPEN_QUESTIONS §7, placeholder) against the
## curve: how many levels' worth of credits each buys, and the first level it would otherwise take to
## reach that many credits from the running wallet.
func _print_packs(rows: Array[Dictionary]) -> void:
	print("")
	print("Mobile credit packs vs. the curve (OPEN_QUESTIONS §7, placeholder; never needed, GDD §7):")
	for p: Dictionary in StubBackend.FAKE_PRODUCTS:
		var amount: int = int(p["credits"])
		var reached: String = "beyond the campaign"
		for r: Dictionary in rows:
			if int(r["wallet"]) >= amount:
				reached = "%s (level %d)" % [r.get("zone", ""), int(r["number"])]
				break
		print("  %-14s %-8s %6d credits: the wallet reaches that much by %s" % [p["title"], p["price_text"], amount, reached])


func _parse_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var value: String = arg.get_slice("=", 1)
		if arg.begins_with("--levels="):
			_levels = value.split(",", false)
		elif arg.begins_with("--lanes="):
			_lanes.clear()
			for v: String in value.split(",", false):
				_lanes.append(int(v))
		elif arg.begins_with("--seeds="):
			_seeds = int(value)
		elif arg.begins_with("--share="):
			_share = float(value)
		elif arg.begins_with("--mobile="):
			_mobile = value == "true"
		elif arg == "--packs":
			_packs = true

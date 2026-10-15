extends SceneTree
## Measures the campaign's economy (task R7, after the owner's playtest changed the pace (G1), the
## armor (G3) and laser tier 1 (G4); task I7, the rebalance for all eight zones): per level and per
## zone, the credits available, what a good run collects, the payout for finishing, and what a death
## or quit pays (GDD §4: never more than finishing); then lays the shop's prices
## (data/shop/catalog.json) against that progression, so a balancing pass can see what a player who
## finishes each level once, in order, can afford. From the project folder (with XDG_DATA_HOME set as
## for the tests):
##   godot --headless -s res://tools/measure/economy.gd -- [options]
## Options:
##   --levels=city/1,gangland/2   campaign steps (levels and bosses; default: all of them)
##   --lanes=3,5,6                lane counts (default 3,5,6; 3 with --mobile=true)
##   --seeds=N                    each level's own seed and N others (default 2)
##   --share=0.7                  the share of a level's credits the typical player collects (GDD §7 names
##                                no number, so this stands in for "a good, not perfect, clean run with no
##                                magnet": reported, not a design decision)
##   --weak-share=0.45            the same for the weaker player (default: the two-star line, GameRules.two_star_share)
##   --fails=0, --weak-fails=2    failed attempts a player makes at each level before finishing it
##   --points=4, --weak-points=2  points the player wins in the Beach's volleyball match (100 credits each)
##   --stash=1, --weak-stash=0    the share of the treasure stashes' credits (task I4; PC lanes only) the player
##                                takes: they sit on an optional ceiling route (DESIGN-TBD, docs/questions/i7.md)
##   --bonus-base=N               what-ifs: GameRules.completion_bonus_base and _per_level, for this run
##   --bonus-per-level=N          only (the data is not touched)
##   --mobile=true|false          mobile's catalog prices and no slow time (default false, PC)
##   --packs                      also print the mobile credit packs (StubBackend.FAKE_PRODUCTS,
##                                OPEN_QUESTIONS §7) against the curve
## Use --lanes=5 --seeds=0 to reproduce test_economy.gd's affordability curve (PC's default lane count and
## each level's own seed).
##
## The two players (the same campaign, in order, nothing bought along the way) and the rest of the model are in
## tools/measure/economy_model.gd, which test_economy.gd shares: the typical player collects 70% of each
## level's credits (the treasure stashes' too), never dies, wins every boss and the whole volleyball match (400
## credits); the weaker one collects the two-star line (45%), takes no stash, fails every level twice first and
## wins two volleyball points (200 credits).
##
## Per level: run speed, length, credits available (a layout's total_credit_value(), averaged over lane counts
## and seeds) of which the treasure stashes' (task I4: total_credit_value() less star_credit_value()), a good
## run's share of them, the completion bonus (GameRules.completion_bonus), the finish payout (both), what a death
## or quit pays (death_credit_keep_fraction of the good run's credits, GDD §4), and each player's running wallet.
## "wallet" counts levels and the volleyball match only: the reading of the owner's October 3 anchors (measured
## with "no purchases or boss payouts"), which test_economy.gd pins; "+boss" also counts the boss payouts every
## player past a boss has been paid (the next zone opens only after it). Per zone: the same, summed.
##
## Then the shop: every item and tier, its price, the line total (the tier's price and every tier before it,
## since tiers are bought in order), and the first level the wallet covers, for the price alone, for the line,
## with the boss payouts, and for the weaker player. The line is the real cost of owning a tier, and the
## reading test_economy.gd pins. A tier that first fits at level N is affordable after finishing N, so usable
## from N + 1 (or from the shop after N's boss, in the "+boss" reading). A tier's "x fin" is its line total over
## the typical finish payout of the level it first fits ("-" at the volleyball match, which pays by points).

const CAMPAIGN_PATH: String = "res://data/campaign/campaign.tres"
const TUNING_PATH: String = "res://data/tuning/movement.tres"
const RULES_PATH: String = "res://data/tuning/game_rules.tres"

const EconomyModel = preload("res://tools/measure/economy_model.gd")

var _levels: PackedStringArray = []
var _lanes: Array[int] = [3, 5, 6]
var _lanes_set: bool = false
var _seeds: int = 2
var _mobile: bool = false
var _packs: bool = false
var _bonus_base: int = -1
var _bonus_per_level: int = -1
var _players: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var campaign := load(CAMPAIGN_PATH) as Campaign
	var tuning := load(TUNING_PATH) as MovementTuning
	var rules := load(RULES_PATH) as GameRules
	_players = EconomyModel.players(rules)
	_parse_args()
	if _bonus_base >= 0:
		rules.completion_bonus_base = _bonus_base
	if _bonus_per_level >= 0:
		rules.completion_bonus_per_level = _bonus_per_level
	var catalog: ShopCatalog = ShopCatalog.load_from()
	var steps: Array[Dictionary] = EconomyModel.rows(campaign, _measure_level.bind(tuning), _levels)
	var walks: Array[Array] = []
	for player: Dictionary in _players:
		walks.append(EconomyModel.walk(player, rules, steps))
	_print_levels(steps, walks)
	_print_zones(steps, walks, catalog)
	_print_shop(catalog, steps, walks)
	_print_totals(catalog, steps, walks)
	if _packs:
		_print_packs(steps, walks)
	quit(0)


## What the generator makes of a level, averaged over the lane counts and seeds asked for (EconomyModel.rows
## calls this for each level, with `tuning` bound).
func _measure_level(campaign: Campaign, step: CampaignStep, tuning: MovementTuning) -> Dictionary:
	var credits_sum: float = 0.0
	var stash_sum: float = 0.0
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
			stash_sum += layout.total_credit_value() - layout.star_credit_value()
			speed_sum += gen.speed
			seconds_sum += layout.length / gen.speed
			n += 1
	return {"credits": credits_sum / n, "stash": stash_sum / n, "speed": speed_sum / n, "seconds": seconds_sum / n}


func _print_levels(steps: Array[Dictionary], walks: Array[Array]) -> void:
	print("Wallets: levels and the volleyball match only; +boss also counts the boss payouts. Players: %s" % _players_text())
	print("%-16s %5s %4s %-7s | %7s %5s %5s %6s %6s | %5s %7s %7s | %6s %7s %7s" % [
		"step", "m/s", "s", "zone", "credits", "stash", "good", "finish", "death", "bonus", "wallet", "+boss", "weak", "wallet", "+boss"])
	for i: int in steps.size():
		var r: Dictionary = steps[i]
		var t: Dictionary = walks[0][i]
		var k: Dictionary = walks[1][i] if walks.size() > 1 else t
		match String(r["kind"]):
			"level":
				print("%-16s %5.1f %4.0f %-7s | %7.0f %5.0f %5d %6d %6d | %5d %7d %7d | %6d %7d %7d" % [
					r["id"], r["speed"], r["seconds"], String(r["zone"]).substr(0, 7), r["credits"], r["stash"], t["good"],
					t["finish"], t["death"], t["bonus"], t["wallet"], t["wallet_all"],
					int(k["finish"]) + int(k["retries"]), k["wallet"], k["wallet_all"]])
			"minigame":
				print("%-16s %5s %4s %-7s | %7s %5s %5s %6d %6s | %5d %7d %7d | %6d %7d %7d" % [
					r["id"], "-", "-", String(r["zone"]).substr(0, 7), "match", "-", "-", t["finish"], "-", t["bonus"],
					t["wallet"], t["wallet_all"], k["finish"], k["wallet"], k["wallet_all"]])
			_:
				print("%-16s %5s %4s %-7s | %7s %5s %5s %6s %6s | %5d %7s %7d | %6s %7s %7d" % [
					r["id"], "", "", String(r["zone"]).substr(0, 7), "boss", "", "", "", "", t["bonus"], "", t["wallet_all"],
					"", "", k["wallet_all"]])


func _players_text() -> String:
	var parts: PackedStringArray = []
	for p: Dictionary in _players:
		parts.append("%s %d%% of credits (%s stashes), %d failed tries a level, %d volleyball points" % [
			p["name"], roundi(float(p["share"]) * 100.0), "takes the" if float(p["stash"]) > 0.0 else "no", p["fails"], p["points"]])
	return "; ".join(parts)


## Per zone: its levels (the volleyball match counts as one; its credits are the generated levels'), each
## player's wallet at the zone's last level and after its boss, and the cost of restocking the three breakables
## over the average typical finish payout of the zone's generated levels.
func _print_zones(steps: Array[Dictionary], walks: Array[Array], catalog: ShopCatalog) -> void:
	var restock: int = 0
	for item: ShopItem in catalog.items_for(_mobile):
		if item.kind == ShopItem.Kind.BREAKABLE:
			restock += item.price_of(1, _mobile)
	print("")
	print("%-16s %6s %8s %8s | %8s %8s | %8s %8s | %7s" % ["zone", "levels", "credits", "good run",
		"wallet", "+boss", "weak", "+boss", "restock"])
	var zone_order: Array[String] = []
	var zones: Dictionary = {}
	for i: int in steps.size():
		var r: Dictionary = steps[i]
		var zid: String = r["zone_id"]
		if not zones.has(zid):
			zones[zid] = {"name": r["zone"], "levels": 0, "credits": 0.0, "good": 0, "finish": 0, "count": 0, "last": i}
			zone_order.append(zid)
		var z: Dictionary = zones[zid]
		z["last"] = i
		if String(r["kind"]) != "boss":
			z["levels"] = int(z["levels"]) + 1
		if String(r["kind"]) == "level":
			z["credits"] = float(z["credits"]) + float(r["credits"])
			z["good"] = int(z["good"]) + int(walks[0][i]["good"])
			z["finish"] = int(z["finish"]) + int(walks[0][i]["finish"])
			z["count"] = int(z["count"]) + 1
	for zid: String in zone_order:
		var z: Dictionary = zones[zid]
		var last: int = z["last"]
		var avg_finish: float = float(z["finish"]) / maxf(float(z["count"]), 1.0)
		var weak: Dictionary = walks.back()[last]
		print("%-16s %6d %8.0f %8d | %8d %8d | %8d %8d | %6.1fx" % [z["name"], z["levels"], z["credits"], z["good"],
			walks[0][last]["wallet"], walks[0][last]["wallet_all"],
			weak["wallet"], weak["wallet_all"], float(restock) / maxf(avg_finish, 1.0)])
	print("(restock: shield + grapple + revive over the zone's average typical finish payout)")


func _label(steps: Array[Dictionary], index: int) -> String:
	if index < 0:
		return "beyond"
	var r: Dictionary = steps[index]
	return "%s (%d)" % [r["id"], r["number"]] if int(r["number"]) > 0 else String(r["id"])


## For each item and tier: its price, the line total, and the first step each reading puts it in reach at.
func _print_shop(catalog: ShopCatalog, steps: Array[Dictionary], walks: Array[Array]) -> void:
	print("")
	print("%-32s %6s %6s | %-17s | %-17s %-17s | %-17s | %7s" % ["item (tier)", "price", "line", "alone", "typical (line)",
		"+boss", "weaker (line)", "x fin"])
	var weak: Array[Dictionary] = walks.back()
	for item: ShopItem in catalog.items_for(_mobile):
		if item.kind == ShopItem.Kind.PERMANENT:
			var line: int = 0
			for t: int in item.tier_count():
				var price: int = item.price_of(t + 1, _mobile)
				line += price
				_print_afford("%s %d %s" % [item.id, t + 1, item.tier_name(t + 1)], price, line, steps, walks[0], weak)
		else:
			var unit: int = item.price_of(1, _mobile)
			_print_afford(String(item.id), unit, unit, steps, walks[0], weak)


func _print_afford(label: String, price: int, line: int, steps: Array[Dictionary], typical: Array[Dictionary],
		weak: Array[Dictionary]) -> void:
	var at: int = EconomyModel.first_fit(typical, steps, line, false)
	var times: String = "-"
	if at >= 0 and String(steps[at]["kind"]) == "level":
		times = "%.1fx" % (float(line) / maxf(float(typical[at]["finish"]), 1.0))
	print("%-32s %6d %6d | %-17s | %-17s %-17s | %-17s | %7s" % [label.substr(0, 32), price, line,
		_label(steps, EconomyModel.first_fit(typical, steps, price, false)), _label(steps, at),
		_label(steps, EconomyModel.first_fit(typical, steps, line, true)), _label(steps, EconomyModel.first_fit(weak, steps, line, false)),
		times])


## The whole permanent catalog against what a playthrough pays.
func _print_totals(catalog: ShopCatalog, steps: Array[Dictionary], walks: Array[Array]) -> void:
	var permanent: int = 0
	var breakables: int = 0
	for item: ShopItem in catalog.items_for(_mobile):
		if item.kind == ShopItem.Kind.PERMANENT:
			for t: int in item.tier_count():
				permanent += item.price_of(t + 1, _mobile)
		else:
			breakables += item.price_of(1, _mobile)
	print("")
	print("The %s catalog's permanent tiers cost %d credits in all (one of each breakable: %d)." % [
		"mobile" if _mobile else "PC", permanent, breakables])
	var last: int = steps.size() - 1
	for p: int in _players.size():
		var levels_wallet: int = int(walks[p][last]["wallet"])
		var all_wallet: int = int(walks[p][last]["wallet_all"])
		print("  %-8s one playthrough pays %6d (%6d with the bosses): the catalog is %.1f playthroughs (%.1f with the bosses)." % [
			_players[p]["name"], levels_wallet, all_wallet, float(permanent) / maxf(float(levels_wallet), 1.0),
			float(permanent) / maxf(float(all_wallet), 1.0)])


## The mobile credit packs (StubBackend.FAKE_PRODUCTS; OPEN_QUESTIONS §7, placeholder) against the
## curve: how many typical finish payouts each buys, and the first step the typical wallet reaches that much.
func _print_packs(steps: Array[Dictionary], walks: Array[Array]) -> void:
	print("")
	print("Mobile credit packs vs. the curve (OPEN_QUESTIONS §7, placeholder; never needed, GDD §7):")
	var finishes: float = 0.0
	var count: int = 0
	for i: int in steps.size():
		if String(steps[i]["kind"]) == "level":
			finishes += float(walks[0][i]["finish"])
			count += 1
	var average: float = finishes / maxf(float(count), 1.0)
	for p: Dictionary in StubBackend.FAKE_PRODUCTS:
		var amount: int = int(p["credits"])
		print("  %-14s %-8s %6d credits = %.1f typical finishes (average %d); the wallet reaches that much by %s" % [
			p["title"], p["price_text"], amount, float(amount) / maxf(average, 1.0), roundi(average),
			_label(steps, EconomyModel.first_fit(walks[0], steps, amount, false))])


func _parse_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var value: String = arg.get_slice("=", 1)
		if arg.begins_with("--levels="):
			_levels = value.split(",", false)
		elif arg.begins_with("--lanes="):
			_lanes.clear()
			_lanes_set = true
			for v: String in value.split(",", false):
				_lanes.append(int(v))
		elif arg.begins_with("--seeds="):
			_seeds = int(value)
		elif arg.begins_with("--share="):
			_players[0]["share"] = float(value)
		elif arg.begins_with("--weak-share="):
			_players[1]["share"] = float(value)
		elif arg.begins_with("--fails="):
			_players[0]["fails"] = int(value)
		elif arg.begins_with("--weak-fails="):
			_players[1]["fails"] = int(value)
		elif arg.begins_with("--points="):
			_players[0]["points"] = int(value)
		elif arg.begins_with("--weak-points="):
			_players[1]["points"] = int(value)
		elif arg.begins_with("--stash="):
			_players[0]["stash"] = float(value)
		elif arg.begins_with("--weak-stash="):
			_players[1]["stash"] = float(value)
		elif arg.begins_with("--bonus-base="):
			_bonus_base = int(value)
		elif arg.begins_with("--bonus-per-level="):
			_bonus_per_level = int(value)
		elif arg.begins_with("--mobile="):
			_mobile = value == "true"
		elif arg == "--packs":
			_packs = true
	if _mobile and not _lanes_set:
		_lanes = [3]

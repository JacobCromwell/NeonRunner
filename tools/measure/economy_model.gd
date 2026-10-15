extends RefCounted
## The economy model that tools/measure/economy.gd reports and tests/suites/test_economy.gd pins (task I7), so
## the two can't drift apart: the campaign's steps with the credits each level offers, two players' walks
## through them (what a typical and a weaker player earn, in order, buying nothing along the way), and where in
## the walk a price first fits. The callers measure the credits (the tool over lane counts and seeds, the test
## on one lane count with the layout cache) and pass the measurement in.
##
## The players:
##   typical  collects 70% of each level's credits ("a good, not perfect, clean run with no magnet": GDD §7
##            names no number, so this is a stand-in, reported, not a design decision), never dies, wins every
##            boss and the whole volleyball match (four points);
##   weaker   collects 45% (the two-star line, GameRules.two_star_share), fails every level twice before
##            finishing it (each failed attempt gets FAIL_PROGRESS of the way and pays
##            death_credit_keep_fraction of the credits it had collected), wins two volleyball points, and wins
##            every boss (their failed tries pay too little to count).
## Neither uses a magnet or buys a breakable. The volleyball level pays its match's payout (100 credits a
## point) instead of the completion bonus; its few run-in credits are left out.
##
## A walk's two wallets: "wallet" counts the levels and the match only, the conservative reading the test pins
## (a boss may take retries); "wallet_all" also counts the boss payouts a player who wins them has by then.

## How far through a level a failed attempt gets, on average.
const FAIL_PROGRESS: float = 0.5


static func players() -> Array[Dictionary]:
	return [
		{"name": "typical", "share": 0.7, "fails": 0, "points": 4},
		{"name": "weaker", "share": 0.45, "fails": 2, "points": 2},
	]


## Every level, the volleyball match and boss in campaign order (cinematics left out), as dictionaries: "id",
## "zone", "zone_id", "number" (a level's place in the campaign's play order, 0 for a boss), "level_index" and
## "kind" ("level", "minigame" or "boss"); a level also gets what `measure` (a Callable taking the Campaign and
## the CampaignStep, returning {credits, speed, seconds}) makes of it, the match its payout per point and the
## points that win it, a boss its payout (0 if its scene isn't built). `only` limits the steps by id.
static func rows(campaign: Campaign, measure: Callable, only: PackedStringArray = PackedStringArray()) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var number: int = 0
	for s: CampaignStep in campaign.steps():
		if s.is_level():
			number += 1
		if not s.is_level() and s.kind != CampaignStep.Kind.BOSS:
			continue
		if not only.is_empty() and not only.has(s.id):
			continue
		var row: Dictionary = {"id": s.id, "zone": s.zone.display_name, "zone_id": "%d_%s" % [s.zone_index, s.zone.display_name],
			"number": number if s.is_level() else 0, "level_index": s.level_index}
		if s.is_minigame():
			var game_tuning: Resource = s.level.minigame.tuning
			row["kind"] = "minigame"
			row["per_point"] = int(game_tuning.get(&"payout_per_point")) if game_tuning != null else 0
			row["points_to_win"] = int(game_tuning.get(&"points_to_win")) if game_tuning != null else 4
		elif s.is_level():
			row["kind"] = "level"
			row.merge(measure.call(campaign, s) as Dictionary)
		else:
			row["kind"] = "boss"
			row["payout"] = s.boss.payout_credits if s.boss != null and s.boss.scene != "" else 0
		out.append(row)
	return out


## One player's walk through `rows`: per step the credits a good run keeps ("good"), the completion bonus (a
## boss's or the match's payout) ("bonus"), the finish payout ("finish"), what a death pays ("death"), the
## failed attempts' pay ("retries") and the running wallets ("wallet", "wallet_all").
static func walk(player: Dictionary, rules: GameRules, rows_in: Array[Dictionary]) -> Array[Dictionary]:
	var share: float = player["share"]
	var fails: int = player["fails"]
	var points: int = player["points"]
	var wallet: int = 0
	var wallet_all: int = 0
	var out: Array[Dictionary] = []
	for r: Dictionary in rows_in:
		var w: Dictionary = {"good": 0, "bonus": 0, "finish": 0, "death": 0, "retries": 0}
		match String(r["kind"]):
			"level":
				var credits: float = float(r["credits"])
				w["good"] = roundi(credits * share)
				w["bonus"] = rules.completion_bonus(int(r["level_index"]))
				w["finish"] = int(w["good"]) + int(w["bonus"])
				w["death"] = floori(float(w["good"]) * rules.death_credit_keep_fraction)
				w["retries"] = fails * floori(float(roundi(credits * share * FAIL_PROGRESS)) * rules.death_credit_keep_fraction)
				wallet += int(w["finish"]) + int(w["retries"])
				wallet_all += int(w["finish"]) + int(w["retries"])
			"minigame":
				var pay: int = mini(points, int(r["points_to_win"])) * int(r["per_point"])
				w["bonus"] = pay
				w["finish"] = pay
				wallet += pay
				wallet_all += pay
			"boss":
				w["bonus"] = int(r["payout"])
				wallet_all += int(r["payout"])
		w["wallet"] = wallet
		w["wallet_all"] = wallet_all
		out.append(w)
	return out


## The index of the first step whose wallet covers `price` (the levels and the match only, or with the boss
## payouts), or -1.
static func first_fit(walk_in: Array[Dictionary], rows_in: Array[Dictionary], price: int, with_bosses: bool) -> int:
	for i: int in rows_in.size():
		if String(rows_in[i]["kind"]) == "boss" and not with_bosses:
			continue
		if int(walk_in[i]["wallet_all" if with_bosses else "wallet"]) >= price:
			return i
	return -1


## What owning each tier of a permanent item costs: its price and every tier before it, since tiers are bought in
## order (index 0 is tier 1).
static func line_totals(item: ShopItem, mobile: bool) -> PackedInt32Array:
	var out := PackedInt32Array()
	var total: int = 0
	for t: int in item.tier_count():
		total += item.price_of(t + 1, mobile)
		out.append(total)
	return out

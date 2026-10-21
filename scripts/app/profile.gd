class_name Profile
extends RefCounted
## The player's saved state: wallet, items, campaign progress, settings and stats. Pure data with
## a JSON round trip (SaveService writes it; cloud save goes through Platform later).
##
## Wallet (GDD §7): credits earned in play and credits bought with real money are kept apart.
## Net worth is the earned credits never spent; purchased credits never count toward it.
## Purchases spend bought credits first, so buying credits never lowers net worth (FB 12).
## Credits spent on cosmetics stay in it (owner, October 18, 2026; GDD §6, §8): a look is not an advantage. A cosmetic
## spends the earned credits first (spend_on_cosmetic), so buying one leaves the net worth exactly as it was, whatever the
## player goes on to buy: bought credits it left in the wallet are then the ones items spend first.

## The save format. Older saves are brought up to date as they load (_migrate).
## 2 (September 30, 2026): armor became a permanent upgrade to the free armor (GDD §4, §8).
## 3 (October 8, 2026): The House moved from the Marketplace to the new Casino zone (GDD §5, §10).
## 4 (October 10, 2026): a new Beach 2, the volleyball match, came in before Sunset Strip, now Beach 3 (GDD §5).
## 5 (October 20, 2026): the Terminal came in between the Dead Zone and the Golden Zone, now zone 9 (GDD §5).
## 6 (October 21, 2026): the Ice Lab came in between the Terminal and the Golden Zone, now zone 10 (GDD §5).
const VERSION: int = 6
## What one unit of armor cost while it was a breakable item (save version 1; the shop never priced it
## otherwise): a version 1 save's armor stock is paid back at this price. A record of the past, not a
## tunable.
const V1_ARMOR_PRICE: int = 150
## The step and hint ids save version 3 moved (The House's, to the Casino; _migrate): records of the past.
const V2_HOUSE_STEP: String = "marketplace/boss"
const V3_HOUSE_STEP: String = "casino/boss"
const V2_HOUSE_OUTRO: String = "marketplace/outro"
const V3_HOUSE_OUTRO: String = "casino/outro"
const V2_HOUSE_HINTS: String = "hint/marketplace_boss"
const V3_HOUSE_HINTS: String = "hint/casino_boss"
## The step id save version 4 moved (Sunset Strip's, from Beach 2 to Beach 3; _migrate): records of the past.
const V3_SUNSET_STEP: String = "beach/2"
const V4_SUNSET_STEP: String = "beach/3"
## The outro save version 5 counts again (the Dead Zone's, which led to the Golden Zone, as the Terminal's, whose
## place before the Golden Zone it was; _migrate): records of the past.
const V4_GOLDEN_GATE: String = "dead_zone/outro"
const V5_GOLDEN_GATE: String = "terminal/outro"
## The outro save version 6 counts again (the Terminal's, which led to the Golden Zone, as the Ice Lab's, whose place
## before the Golden Zone it was; _migrate): records of the past.
const V6_GOLDEN_GATE: String = "ice_lab/outro"

## Credits earned in play and not spent (the wallet's part of the net worth, GDD §7).
var earned: int = 0
## Earned credits spent on cosmetics (spend_on_cosmetic): gone from the wallet, still counted by net_worth().
## An older save has no such field: it is read off the outfits it owns when it loads (from_dict).
var cosmetic_spent: int = 0
## Credits bought with real money (mobile) and not spent.
var purchased: int = 0
var lifetime_earned: int = 0
var lifetime_spent: int = 0
## Permanent items: id -> tier owned.
var tiers: Dictionary = {}
## Breakable items: id -> count in stock.
var stocks: Dictionary = {}
## Items switched off in the shop's equip toggle: id -> true (GDD §8).
var equip_off: Dictionary = {}
## Cosmetics bought (GDD §8, "Cosmetics"): outfit id -> true. Razor Echo's own look is always owned and has
## no entry.
var outfits: Dictionary = {}
## The outfit worn (an id in `outfits`, or PlayerOutfits.ECHO for his own look, the default).
var worn_outfit: String = String(PlayerOutfits.ECHO)
## Campaign records per difficulty tier: "tier/step_id" -> {completed, best_score, stars, best_time, attempts}.
var records: Dictionary = {}
## Highest difficulty tier unlocked (0 = normal; harder tiers open after finishing the game, GDD §6).
var unlocked_tier: int = 0
## Endless mode bests: "lanes/tier" -> best score.
var endless_best: Dictionary = {}
## One-time things already seen: cinematics, hints (e.g. the doghouse), tutorials.
var seen: Dictionary = {}
## Settings: audio volumes, key bindings, accessibility (see Settings).
var settings: Dictionary = {}
## Totals: runs, deaths, kills, credits, ... (for the stats screen and achievements).
var stats: Dictionary = {}
## The weekly challenge (GDD §6, task N5): week index (as a string) -> {attempts, cleared, paid, best}. `cleared` is
## the week's first clear (the only one that pays), `paid` what it paid, `best` the best score of a clear. One more
## entry, WEEKLY_HIGH_WATER ("high_water"), is the highest week played so far. A save from before the challenge has none.
var weekly: Dictionary = {}
## What the weekly boards may owe the player (the Leader of the Pack hook, WeeklyChallenge.reward_kind; DESIGN-TBD,
## item 977 in docs/OPEN_QUESTIONS.md): one record per week with a score posted, {week, board, score, kind, state,
## rank}. `state` is "pending" until the week is over and the platform has said the player's place, then "earned"
## (in the top places) or "missed". An "earned" record is kept for good: it is what the cosmetic will be granted
## from once it is designed (App._grant_weekly_reward).
var weekly_rewards: Array = []


# --- Wallet ------------------------------------------------------------------------

func credits() -> int:
	return earned + purchased


## The leaderboard's score (GDD §6, §7): the credits earned in play and not spent, plus those spent on cosmetics,
## which never lower it (owner, October 18, 2026). Bought credits never count.
func net_worth() -> int:
	return earned + cosmetic_spent


func can_afford(price: int) -> bool:
	return price >= 0 and credits() >= price


## Spends `price` credits (bought credits first). False, and nothing spent, if unaffordable.
func spend(price: int) -> bool:
	return _spend(price) >= 0


## Spends `price` credits on a cosmetic, EARNED credits first and then bought ones: the wallet loses the price and the
## earned part spent goes to `cosmetic_spent`, so the net worth is exactly what it was (owner, October 18, 2026, item 980).
## Items go the other way (spend: bought credits first), and with an outfit spending bought credits first the credits left
## would be earned ones that the next item spends, so the outfit would lower the net worth after all. False, and nothing
## spent, if unaffordable.
func spend_on_cosmetic(price: int) -> bool:
	var from_earned: int = _spend(price, false)
	if from_earned < 0:
		return false
	cosmetic_spent += from_earned
	return true


## Takes `price` out of the wallet, bought credits first (or earned ones first with `bought_first` off). Returns the part
## that came out of the earned credits, or -1, with nothing spent, if the wallet is short.
func _spend(price: int, bought_first: bool = true) -> int:
	if not can_afford(price):
		return -1
	var from_purchased: int = mini(purchased, price) if bought_first else maxi(price - earned, 0)
	purchased -= from_purchased
	earned -= price - from_purchased
	lifetime_spent += price
	return price - from_purchased


func add_earned(amount: int) -> void:
	if amount <= 0:
		return
	earned += amount
	lifetime_earned += amount


func add_purchased(amount: int) -> void:
	if amount > 0:
		purchased += amount


# --- Items ---------------------------------------------------------------------------

func tier(id: StringName) -> int:
	return int(tiers.get(String(id), 0))


func set_tier(id: StringName, value: int) -> void:
	tiers[String(id)] = value


func stock(id: StringName) -> int:
	return int(stocks.get(String(id), 0))


func add_stock(id: StringName, amount: int) -> void:
	stocks[String(id)] = maxi(stock(id) + amount, 0)


## Takes one of a breakable item out of stock. False if there is none.
func use_stock(id: StringName) -> bool:
	if stock(id) <= 0:
		return false
	add_stock(id, -1)
	return true


func is_equipped(id: StringName) -> bool:
	return not equip_off.has(String(id))


func set_equipped(id: StringName, on: bool) -> void:
	if on:
		equip_off.erase(String(id))
	else:
		equip_off[String(id)] = true


# --- Cosmetics -----------------------------------------------------------------------

## Razor Echo's own look is always owned; any other outfit once it has been bought.
func owns_outfit(id: StringName) -> bool:
	return id == PlayerOutfits.ECHO or outfits.has(String(id))


func add_outfit(id: StringName) -> void:
	if id != PlayerOutfits.ECHO:
		outfits[String(id)] = true


## The outfit worn.
func worn() -> StringName:
	return StringName(worn_outfit)


## Wears an owned outfit (PlayerOutfits.ECHO for his own look). False, nothing changed, if it isn't owned.
func wear_outfit(id: StringName) -> bool:
	if not owns_outfit(id):
		return false
	worn_outfit = String(id)
	return true


# --- Campaign records ------------------------------------------------------------------

static func record_key(step_id: String, difficulty_tier: int) -> String:
	return "%d/%s" % [difficulty_tier, step_id]


func record(step_id: String, difficulty_tier: int = 0) -> Dictionary:
	return records.get(record_key(step_id, difficulty_tier), {})


func is_completed(step_id: String, difficulty_tier: int = 0) -> bool:
	return bool(record(step_id, difficulty_tier).get("completed", false))


func stars(step_id: String, difficulty_tier: int = 0) -> int:
	return int(record(step_id, difficulty_tier).get("stars", 0))


## Stores a run's outcome. Returns {"new_best": bool, "stars_gained": int, "first_clear": bool}.
func record_run(step_id: String, difficulty_tier: int, completed: bool, score: int, stars_earned: int,
		time: float) -> Dictionary:
	var key: String = record_key(step_id, difficulty_tier)
	var r: Dictionary = records.get(key, {"completed": false, "best_score": 0, "stars": 0, "best_time": 0.0, "attempts": 0})
	r["attempts"] = int(r.get("attempts", 0)) + 1
	var out := {"new_best": false, "stars_gained": 0, "first_clear": false}
	if completed:
		out["first_clear"] = not bool(r.get("completed", false))
		r["completed"] = true
		if score > int(r.get("best_score", 0)):
			r["best_score"] = score
			out["new_best"] = true
		if stars_earned > int(r.get("stars", 0)):
			out["stars_gained"] = stars_earned - int(r.get("stars", 0))
			r["stars"] = stars_earned
		if float(r.get("best_time", 0.0)) <= 0.0 or time < float(r["best_time"]):
			r["best_time"] = time
	records[key] = r
	return out


# --- The weekly challenge -----------------------------------------------------------------

## The key in `weekly` of the highest week index played (the schedule's weeks count from 0).
const WEEKLY_HIGH_WATER: String = "high_water"


## The highest week played (-1 before any). Weeks only go forward: a device whose clock was moved back must not be
## paid for a week again, so a week below this is closed (weekly_week_open). DESIGN-TBD (item 1026): the
## device's clock is all this can go by; a clock moved forward still opens each future week once.
func weekly_high_water() -> int:
	return int(weekly.get(WEEKLY_HIGH_WATER, -1))


## True if week `week` may be played for credits and a place on the board: a week of the schedule (0 on, never one
## before its epoch) that isn't below the highest played.
func weekly_week_open(week: int) -> bool:
	return week >= 0 and week >= weekly_high_water()


## True if a clear of week `week` would be the one that pays: the week is open and not cleared yet.
func weekly_may_pay(week: int) -> bool:
	return weekly_week_open(week) and not weekly_cleared(week)


## A week's record ({} if it was never played): see `weekly`.
func weekly_record(week: int) -> Dictionary:
	return weekly.get(str(week), {})


## True if week `week`'s first clear has been made, which is the one clear of the week that pays.
func weekly_cleared(week: int) -> bool:
	return bool(weekly_record(week).get("cleared", false))


## The best score of a clear of the week (0 if none).
func weekly_best(week: int) -> int:
	return int(weekly_record(week).get("best", 0))


## Stores a weekly run's outcome. Returns {"new_best": bool, "first_clear": bool}: a clear is the week's first clear
## when none came before it. `paid` (credits) is stored with it, so the screen can say what the week paid.
## A run that did not clear counts as an attempt and nothing else. A week before the schedule's first (negative) isn't
## kept at all. Playing a week raises the high-water mark to it.
func record_weekly(week: int, completed: bool, score: int, paid: int = 0) -> Dictionary:
	if week < 0:
		return {"new_best": false, "first_clear": false}
	weekly[WEEKLY_HIGH_WATER] = maxi(weekly_high_water(), week)
	var r: Dictionary = weekly.get(str(week), {"attempts": 0, "cleared": false, "paid": 0, "best": 0})
	r["attempts"] = int(r.get("attempts", 0)) + 1
	var out := {"new_best": false, "first_clear": false}
	if completed:
		out["first_clear"] = not bool(r.get("cleared", false))
		r["cleared"] = true
		if out["first_clear"]:
			r["paid"] = paid
		if score > int(r.get("best", 0)):
			r["best"] = score
			out["new_best"] = true
	weekly[str(week)] = r
	return out


## Notes that week `week`'s board holds the player's score, to be asked about once the week is over (see
## `weekly_rewards`). One record a week: a better score updates it.
func queue_weekly_reward(week: int, board: String, score: int, kind: String) -> void:
	for r: Dictionary in weekly_rewards:
		if int(r.get("week", -1)) == week and String(r.get("board", "")) == board:
			r["score"] = maxi(int(r.get("score", 0)), score)
			return
	weekly_rewards.append({"week": week, "board": board, "score": score, "kind": kind, "state": "pending", "rank": 0})


## The records still waiting for a rank whose week is over by `current_week` (a week before it).
func pending_weekly_rewards(current_week: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Dictionary in weekly_rewards:
		if String(r.get("state", "")) == "pending" and int(r.get("week", 0)) < current_week:
			out.append(r)
	return out


## True if the player has earned the weekly reward `kind` in any week.
func has_weekly_reward(kind: String) -> bool:
	for r: Dictionary in weekly_rewards:
		if String(r.get("kind", "")) == kind and String(r.get("state", "")) == "earned":
			return true
	return false


func stat_add(key: String, amount: int = 1) -> void:
	stats[key] = int(stats.get(key, 0)) + amount


func mark_seen(key: String) -> void:
	seen[key] = true


func has_seen(key: String) -> bool:
	return seen.has(key)


# --- Serialization -----------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"earned": earned,
		"purchased": purchased,
		"lifetime_earned": lifetime_earned,
		"lifetime_spent": lifetime_spent,
		"cosmetic_spent": cosmetic_spent,
		"tiers": tiers,
		"stocks": stocks,
		"equip_off": equip_off,
		"outfits": outfits,
		"worn_outfit": worn_outfit,
		"records": records,
		"unlocked_tier": unlocked_tier,
		"endless_best": endless_best,
		"seen": seen,
		"settings": settings,
		"stats": stats,
		"weekly": weekly,
		"weekly_rewards": weekly_rewards,
	}


static func from_dict(d: Dictionary) -> Profile:
	var p := Profile.new()
	p.earned = int(d.get("earned", 0))
	p.purchased = int(d.get("purchased", 0))
	p.lifetime_earned = int(d.get("lifetime_earned", 0))
	p.lifetime_spent = int(d.get("lifetime_spent", 0))
	p.tiers = _dict(d, "tiers")
	p.stocks = _dict(d, "stocks")
	p.equip_off = _dict(d, "equip_off")
	p.outfits = _dict(d, "outfits")
	# Saves from before the cosmetics have neither: nothing owned, Echo worn. An outfit worn that isn't owned
	# (an edited save) is taken off.
	p.worn_outfit = str(d.get("worn_outfit", PlayerOutfits.ECHO))
	if not p.owns_outfit(p.worn()):
		p.worn_outfit = String(PlayerOutfits.ECHO)
	p.records = _dict(d, "records")
	p.unlocked_tier = int(d.get("unlocked_tier", 0))
	p.endless_best = _dict(d, "endless_best")
	p.seen = _dict(d, "seen")
	p.settings = _dict(d, "settings")
	p.stats = _dict(d, "stats")
	# Saves from before the weekly challenge have neither.
	p.weekly = _dict(d, "weekly")
	var rewards: Variant = d.get("weekly_rewards", [])
	if typeof(rewards) == TYPE_ARRAY:
		for r: Variant in rewards:
			if typeof(r) == TYPE_DICTIONARY:
				p.weekly_rewards.append((r as Dictionary).duplicate(true))
	# JSON turns every number into a float; counters stay integers.
	for dict: Dictionary in [p.tiers, p.stocks, p.stats, p.endless_best]:
		for k: Variant in dict.keys():
			dict[k] = int(dict[k])
	p._migrate(int(d.get("version", 1)))
	# A save from before cosmetics stopped lowering net worth has no `cosmetic_spent` (the version is unchanged: a
	# new field with a default, as the outfits were): what its outfits cost is what they took out of its net worth.
	var spent: Variant = d.get("cosmetic_spent")
	p.cosmetic_spent = maxi(int(spent), 0) if typeof(spent) in [TYPE_INT, TYPE_FLOAT] else p._owned_outfits_cost()
	return p


## Brings a save written by an older version up to date (`from`: the version it was written with).
## - 1 → 2: armor stopped being stock (GDD §8: a permanent upgrade to the free armor every run brings).
##   The armor stock a player bought is paid back in credits at the price it cost (V1_ARMOR_PRICE),
##   into the earned credits, and the purchase leaves lifetime_spent. Its old equip toggle goes too,
##   so an upgrade bought later starts switched on.
## - 2 → 3: The House moved to the Casino zone, which now sits between the Marketplace and Corporate
##   (owner, October 8, 2026). Its records (every tier's "marketplace/boss": stars, best score and time)
##   become the Casino's boss step's, and its first-time hints (`hint/marketplace_boss...`) the
##   casino_boss ones, so a player who beat it keeps both. The Marketplace's old outro came after The House
##   and led to the Corporate zone, the Casino's outro's place now: a finished one also counts as the
##   Casino's outro finished (the Marketplace's own stays finished too), so Corporate's intro, whose step
##   before is now the Casino's outro, stays open to a player who had reached it (App.step_unlocked).
## - 3 → 4: the volleyball match came in as Beach 2 (owner, October 10, 2026), before Sunset Strip, which moved from
##   Beach 2 to Beach 3. Its records (every tier's "beach/2": stars, best score and time) become "beach/3"'s, so a
##   player who finished it keeps it, and the new Beach 2 stays to play: open, since Beach 1 is done
##   (App.step_unlocked), and the first step not done, so Continue leads to it.
## - 4 → 5: the Terminal came in as zone 8, between the Dead Zone and the Golden Zone (owner, October 20, 2026), with
##   no boss: its intro, two levels and outro. The Golden Zone's step ids stay as they were, so its records are kept as
##   they are; but its intro's step before is now the Terminal's outro, no longer the Dead Zone's outro. The Dead Zone's
##   old outro came after its boss and led to the Golden Zone, the Terminal's outro's place now, as the Marketplace's did
##   to Corporate when the Casino came in: a finished one also counts as the Terminal's outro finished (the Dead Zone's
##   own stays finished too), so the Golden Zone's intro stays open to a player who had reached it (App.step_unlocked).
##   The Terminal's intro is open too (the Dead Zone's outro is done) and is the first step not done, so Continue leads
##   into the Terminal. DESIGN-TBD (docs/questions/o1.md): that a save keeps the Golden Zone open.
## - 5 → 6: the Ice Lab came in as zone 9, between the Terminal and the Golden Zone (owner, October 21, 2026), with no
##   boss: its intro, three levels and outro. The Golden Zone's step ids stay as they were, and its intro's step before
##   is now the Ice Lab's outro, no longer the Terminal's: the Terminal's outro led to the Golden Zone, the Ice Lab's
##   outro's place now, so a finished one also counts as the Ice Lab's outro finished (the Terminal's own stays finished
##   too), on every tier it was, and the Golden Zone's intro stays open to a player who had reached it
##   (App.step_unlocked). The Ice Lab's intro is open too (the Terminal's outro is done) and is the first step not done,
##   so Continue leads into the Ice Lab. A save from before the Terminal takes both steps: 4 → 5 counts its Dead Zone
##   outro as the Terminal's, and this one that as the Ice Lab's. DESIGN-TBD (docs/questions/q1.md): that a save keeps
##   the Golden Zone open.
func _migrate(from: int) -> void:
	if from < 2:
		var refund: int = stock(&"armor") * V1_ARMOR_PRICE
		stocks.erase("armor")
		equip_off.erase("armor")
		earned += refund
		lifetime_spent = maxi(lifetime_spent - refund, 0)
	if from < 3:
		for key: String in records.keys():
			var tier_prefix: String = key.get_slice("/", 0) + "/"
			var step_id: String = key.trim_prefix(tier_prefix)
			if step_id == V2_HOUSE_STEP:
				_move_record(key, tier_prefix + V3_HOUSE_STEP)
			elif step_id == V2_HOUSE_OUTRO and bool((records[key] as Dictionary).get("completed", false)) \
					and not records.has(tier_prefix + V3_HOUSE_OUTRO):
				records[tier_prefix + V3_HOUSE_OUTRO] = (records[key] as Dictionary).duplicate()
		for key: String in seen.keys():
			if key.begins_with(V2_HOUSE_HINTS):
				seen[V3_HOUSE_HINTS + key.trim_prefix(V2_HOUSE_HINTS)] = seen[key]
				seen.erase(key)
	if from < 4:
		for key: String in records.keys():
			var prefix: String = key.get_slice("/", 0) + "/"
			if key.trim_prefix(prefix) == V3_SUNSET_STEP:
				_move_record(key, prefix + V4_SUNSET_STEP)
	if from < 5:
		for key: String in records.keys():
			var tier_prefix: String = key.get_slice("/", 0) + "/"
			if key.trim_prefix(tier_prefix) == V4_GOLDEN_GATE and bool((records[key] as Dictionary).get("completed", false)) \
					and not records.has(tier_prefix + V5_GOLDEN_GATE):
				records[tier_prefix + V5_GOLDEN_GATE] = (records[key] as Dictionary).duplicate()
	if from < 6:
		for key: String in records.keys():
			var tier_prefix: String = key.get_slice("/", 0) + "/"
			if key.trim_prefix(tier_prefix) == V5_GOLDEN_GATE and bool((records[key] as Dictionary).get("completed", false)) \
					and not records.has(tier_prefix + V6_GOLDEN_GATE):
				records[tier_prefix + V6_GOLDEN_GATE] = (records[key] as Dictionary).duplicate()


## What the outfits owned cost at the catalog's prices, capped by what the save could have paid them with: never more than
## it ever spent (`lifetime_spent`) and never more than the earned credits it has spent (`lifetime_earned - earned`). That
## is the cosmetic spending of a save that didn't count it. It is exact for a save that paid for its outfits with earned
## credits (the owner's own), and an outfit paid with bought credits (mobile: they went first, and an old save can't say
## which were which) is credited only as far as the player's earned spending reaches, so the net worth it gives back never
## goes past `lifetime_earned`: bought credits never end up in it.
func _owned_outfits_cost() -> int:
	if outfits.is_empty():
		return 0
	var catalog: ShopCatalog = ShopCatalog.load_from()
	var total: int = 0
	for id: String in outfits:
		var cosmetic: ShopCosmetic = catalog.cosmetic(StringName(id))
		if cosmetic != null and cosmetic != catalog.default_cosmetic:
			total += cosmetic.price
	return mini(mini(total, maxi(lifetime_spent, 0)), maxi(lifetime_earned - earned, 0))


## Moves the record at `from_key` to `to_key` (save versions 3 and 4), unless `to_key` already has one.
func _move_record(from_key: String, to_key: String) -> void:
	if not records.has(to_key):
		records[to_key] = records[from_key]
	records.erase(from_key)


static func _dict(d: Dictionary, key: String) -> Dictionary:
	var v: Variant = d.get(key, {})
	return (v as Dictionary).duplicate(true) if typeof(v) == TYPE_DICTIONARY else {}

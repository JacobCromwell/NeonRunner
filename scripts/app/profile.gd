class_name Profile
extends RefCounted
## The player's saved state: wallet, items, campaign progress, settings and stats. Pure data with
## a JSON round trip (SaveService writes it; cloud save goes through Platform later).
##
## Wallet (GDD §7): credits earned in play and credits bought with real money are kept apart.
## Net worth is the earned credits never spent; purchased credits never count toward it.
## Purchases spend bought credits first, so buying credits never lowers net worth (FB 12).

## The save format. Older saves are brought up to date as they load (_migrate).
## 2 (September 30, 2026): armor became a permanent upgrade to the free armor (GDD §4, §8).
## 3 (October 8, 2026): The House moved from the Marketplace to the new Casino zone (GDD §5, §10).
## 4 (October 10, 2026): a new Beach 2, the volleyball match, came in before Sunset Strip, now Beach 3 (GDD §5).
const VERSION: int = 4
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

## Credits earned in play and not spent: the net worth (GDD §7).
var earned: int = 0
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


# --- Wallet ------------------------------------------------------------------------

func credits() -> int:
	return earned + purchased


func net_worth() -> int:
	return earned


func can_afford(price: int) -> bool:
	return price >= 0 and credits() >= price


## Spends `price` credits (bought credits first). False, and nothing spent, if unaffordable.
func spend(price: int) -> bool:
	if not can_afford(price):
		return false
	var from_purchased: int = mini(purchased, price)
	purchased -= from_purchased
	earned -= price - from_purchased
	lifetime_spent += price
	return true


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
		"tiers": tiers,
		"stocks": stocks,
		"equip_off": equip_off,
		"records": records,
		"unlocked_tier": unlocked_tier,
		"endless_best": endless_best,
		"seen": seen,
		"settings": settings,
		"stats": stats,
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
	p.records = _dict(d, "records")
	p.unlocked_tier = int(d.get("unlocked_tier", 0))
	p.endless_best = _dict(d, "endless_best")
	p.seen = _dict(d, "seen")
	p.settings = _dict(d, "settings")
	p.stats = _dict(d, "stats")
	# JSON turns every number into a float; counters stay integers.
	for dict: Dictionary in [p.tiers, p.stocks, p.stats, p.endless_best]:
		for k: Variant in dict.keys():
			dict[k] = int(dict[k])
	p._migrate(int(d.get("version", 1)))
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


## Moves the record at `from_key` to `to_key` (save versions 3 and 4), unless `to_key` already has one.
func _move_record(from_key: String, to_key: String) -> void:
	if not records.has(to_key):
		records[to_key] = records[from_key]
	records.erase(from_key)


static func _dict(d: Dictionary, key: String) -> Dictionary:
	var v: Variant = d.get(key, {})
	return (v as Dictionary).duplicate(true) if typeof(v) == TYPE_DICTIONARY else {}

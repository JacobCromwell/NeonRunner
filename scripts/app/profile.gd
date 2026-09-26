class_name Profile
extends RefCounted
## The player's saved state: wallet, items, campaign progress, settings and stats. Pure data with
## a JSON round trip (SaveService writes it; cloud save goes through Platform later).
##
## Wallet (GDD §7): credits earned in play and credits bought with real money are kept apart.
## Net worth is the earned credits never spent; purchased credits never count toward it.
## DESIGN-TBD: purchases spend bought credits first, so buying credits never lowers net worth.

const VERSION: int = 1

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
	# Future versions migrate older saves here, based on d["version"].
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
	return p


static func _dict(d: Dictionary, key: String) -> Dictionary:
	var v: Variant = d.get(key, {})
	return (v as Dictionary).duplicate(true) if typeof(v) == TYPE_DICTIONARY else {}

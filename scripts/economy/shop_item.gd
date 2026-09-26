class_name ShopItem
extends RefCounted
## One shop entry from data/shop/catalog.json (GDD §8). Permanent items are bought once per tier
## and kept forever; breakable items break when used and are bought again (kept as stock).

enum Kind { PERMANENT, BREAKABLE }

var id: StringName
var kind: Kind = Kind.PERMANENT
var display_name: String = ""
var description: String = ""
## Icon name for the UI kit's icon set (e.g. "weapon", "armor").
var icon: StringName = &""
## Permanent items: one entry per tier: {name, description, price, price_mobile}.
var tiers: Array[Dictionary] = []
## Breakable items: price per unit, and the most the player can hold.
var price: int = 0
var price_mobile: int = -1
var max_stock: int = 1
## Empty = every platform; ["pc"] = PC only (slow time, GDD §3).
var platforms: PackedStringArray = PackedStringArray()


static func from_dict(d: Dictionary) -> ShopItem:
	var item := ShopItem.new()
	item.id = StringName(String(d.get("id", "")))
	item.kind = Kind.BREAKABLE if String(d.get("kind", "permanent")) == "breakable" else Kind.PERMANENT
	item.display_name = String(d.get("name", item.id))
	item.description = String(d.get("description", ""))
	item.icon = StringName(String(d.get("icon", item.id)))
	for t: Variant in d.get("tiers", []):
		item.tiers.append((t as Dictionary).duplicate())
	item.price = int(d.get("price", 0))
	item.price_mobile = int(d.get("price_mobile", -1))
	item.max_stock = int(d.get("max_stock", 1))
	item.platforms = PackedStringArray(d.get("platforms", []))
	return item


func tier_count() -> int:
	return tiers.size() if kind == Kind.PERMANENT else 0


## Whether the item exists on this platform (mobile or PC).
func available_on(mobile: bool) -> bool:
	if platforms.is_empty():
		return true
	return platforms.has("mobile") if mobile else platforms.has("pc")


## Price of tier `tier` (1-based) for a permanent item, or of one unit for a breakable one.
## DESIGN-TBD: whether mobile prices differ is open (OPEN_QUESTIONS §4); `price_mobile` overrides.
func price_of(tier: int, mobile: bool) -> int:
	if kind == Kind.BREAKABLE:
		return price_mobile if mobile and price_mobile >= 0 else price
	if tier < 1 or tier > tiers.size():
		return -1
	var t: Dictionary = tiers[tier - 1]
	var mobile_price: int = int(t.get("price_mobile", -1))
	return mobile_price if mobile and mobile_price >= 0 else int(t.get("price", 0))


## Name of a tier (1-based) for permanent items, or the item name.
func tier_name(tier: int) -> String:
	if kind == Kind.PERMANENT and tier >= 1 and tier <= tiers.size():
		return String(tiers[tier - 1].get("name", display_name))
	return display_name


func tier_description(tier: int) -> String:
	if kind == Kind.PERMANENT and tier >= 1 and tier <= tiers.size():
		return String(tiers[tier - 1].get("description", description))
	return description

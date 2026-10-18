class_name ShopCatalog
extends RefCounted
## Everything the shop sells, loaded from data/shop/catalog.json (prices and tiers are data, so
## balancing never needs code changes, CLAUDE.md principle 7): the items, and the cosmetics (looks for
## the runner, GDD §8) in their own list.

const PATH: String = "res://data/shop/catalog.json"

var items: Array[ShopItem] = []
## The outfits for sale, in shop order. Not part of `items`: they have no tiers or stock and never
## reach a run's loadout.
var cosmetics: Array[ShopCosmetic] = []
## Razor Echo's own look: free, always owned, and the one every other outfit goes back to.
var default_cosmetic: ShopCosmetic = ShopCatalog._echo()


static func load_from(path: String = PATH) -> ShopCatalog:
	var catalog := ShopCatalog.new()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("items"):
		push_error("ShopCatalog: could not read %s" % path)
		return catalog
	for d: Variant in parsed["items"]:
		catalog.items.append(ShopItem.from_dict(d))
	if typeof(parsed.get("default_cosmetic")) == TYPE_DICTIONARY:
		catalog.default_cosmetic = ShopCosmetic.from_dict(parsed["default_cosmetic"])
	for d: Variant in parsed.get("cosmetics", []):
		catalog.cosmetics.append(ShopCosmetic.from_dict(d))
	return catalog


static func _echo() -> ShopCosmetic:
	var echo := ShopCosmetic.new()
	echo.id = PlayerOutfits.ECHO
	echo.display_name = "Razor Echo"
	return echo


func item(id: StringName) -> ShopItem:
	for i: ShopItem in items:
		if i.id == id:
			return i
	return null


## A cosmetic by id (the default look included), or null.
func cosmetic(id: StringName) -> ShopCosmetic:
	if id == default_cosmetic.id:
		return default_cosmetic
	for c: ShopCosmetic in cosmetics:
		if c.id == id:
			return c
	return null


## Items available on this platform, in catalog order.
func items_for(mobile: bool) -> Array[ShopItem]:
	var out: Array[ShopItem] = []
	for i: ShopItem in items:
		if i.available_on(mobile):
			out.append(i)
	return out

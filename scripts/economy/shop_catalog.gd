class_name ShopCatalog
extends RefCounted
## Everything the shop sells, loaded from data/shop/catalog.json (prices and tiers are data, so
## balancing never needs code changes, CLAUDE.md principle 7).

const PATH: String = "res://data/shop/catalog.json"

var items: Array[ShopItem] = []


static func load_from(path: String = PATH) -> ShopCatalog:
	var catalog := ShopCatalog.new()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("items"):
		push_error("ShopCatalog: could not read %s" % path)
		return catalog
	for d: Variant in parsed["items"]:
		catalog.items.append(ShopItem.from_dict(d))
	return catalog


func item(id: StringName) -> ShopItem:
	for i: ShopItem in items:
		if i.id == id:
			return i
	return null


## Items available on this platform, in catalog order.
func items_for(mobile: bool) -> Array[ShopItem]:
	var out: Array[ShopItem] = []
	for i: ShopItem in items:
		if i.available_on(mobile):
			out.append(i)
	return out

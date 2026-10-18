class_name ShopCosmetic
extends RefCounted
## One look for the runner in the shop's Cosmetics section, from data/shop/catalog.json (GDD §8,
## "Cosmetics"). A cosmetic is bought once with credits and kept forever; the player then picks one to
## wear. Its id names its outfit file (PlayerOutfits), and it never changes gameplay.

var id: StringName
var display_name: String = ""
var description: String = ""
## Credits. The default look (Razor Echo's own) is free.
## One price on every platform (the owner, October 18, 2026; `docs/OPEN_QUESTIONS*.md` item 985).
var price: int = 0
## The outfit's main colour: the tint of an outfit whose look isn't built yet
## (PlayerOutfits.placeholder_parts).
var color: Color = Color(0.6, 0.6, 0.65)


static func from_dict(d: Dictionary) -> ShopCosmetic:
	var cosmetic := ShopCosmetic.new()
	cosmetic.id = StringName(String(d.get("id", "")))
	cosmetic.display_name = String(d.get("name", cosmetic.id))
	cosmetic.description = String(d.get("description", ""))
	cosmetic.price = maxi(int(d.get("price", 0)), 0)
	cosmetic.color = Color.from_string(String(d.get("color", "")), cosmetic.color)
	return cosmetic

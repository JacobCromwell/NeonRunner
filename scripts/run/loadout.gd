class_name Loadout
extends RefCounted
## What the player takes into one run (GDD §8): permanent items by tier and breakable items as
## charges. Only owned items that are switched on in the shop (the equip toggle) are included.
## Power-ups stack: there are no slots.

## Permanent items: id -> tier (weapon 1–4, claws, dash, magnet, slow_time).
var tiers: Dictionary = {}
## Breakable items: id -> charges this run (armor, shield, grapple, revive).
var charges: Dictionary = {}


func tier(id: StringName) -> int:
	return int(tiers.get(id, 0))


func charge(id: StringName) -> int:
	return int(charges.get(id, 0))


func has(id: StringName) -> bool:
	return tier(id) > 0 or charge(id) > 0


## Builds the loadout from what the profile owns and has switched on. Breakable items bring one
## charge each (DESIGN-TBD: one of each breakable per attempt; spares stay in stock). Revives are
## used from stock on the death screen, not carried as a charge. Items not sold on this platform
## (slow time on mobile, GDD §3) are left out.
static func from_profile(profile: Profile, catalog: ShopCatalog, mobile: bool) -> Loadout:
	var out := Loadout.new()
	for item: ShopItem in catalog.items:
		if not profile.is_equipped(item.id) or not item.available_on(mobile):
			continue
		if item.kind == ShopItem.Kind.PERMANENT:
			var t: int = profile.tier(item.id)
			if t > 0:
				out.tiers[item.id] = t
		elif profile.stock(item.id) > 0 and item.id != &"revive":
			out.charges[item.id] = 1
	return out


## Everything, for tests and god-mode play.
static func full(catalog: ShopCatalog) -> Loadout:
	var out := Loadout.new()
	for item: ShopItem in catalog.items:
		if item.kind == ShopItem.Kind.PERMANENT:
			out.tiers[item.id] = item.tier_count()
		elif item.id != &"revive":
			out.charges[item.id] = 1
	return out


func describe() -> String:
	var parts: PackedStringArray = []
	for id: Variant in tiers:
		parts.append("%s %d" % [id, tiers[id]])
	for id: Variant in charges:
		parts.append("%s x%d" % [id, charges[id]])
	return ", ".join(parts) if not parts.is_empty() else "nothing"

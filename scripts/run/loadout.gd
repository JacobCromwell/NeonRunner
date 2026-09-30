class_name Loadout
extends RefCounted
## What the player takes into one run (GDD §8): permanent items by tier and breakable items as
## charges. Only owned items that are switched on in the shop (the equip toggle) are included.
## Power-ups stack: there are no slots.
## The armor (GDD §4, §8) comes with every run the profile starts, free: `armor`, with the shop's
## upgrade as its tier (tiers[&"armor"]; the equip toggle switches the upgrade off, down to the free
## armor). RunWorld makes the run's armor from them (DamageRules.Armor.create).

## Permanent items: id -> tier (weapon 1–4, claws, dash, magnet, slow_time, the armor upgrade 1–4).
var tiers: Dictionary = {}
## Breakable items: id -> charges this run (shield, grapple, revive).
var charges: Dictionary = {}
## The run carries the free armor (GDD §4: every level and boss fight starts with it). A bare Loadout
## (tests, tools) has none.
var armor: bool = false
## Items a boss fight granted (GDD §8: bosses may grant power-ups before the fight): id -> true.
## A granted breakable's charge is the fight's, so using it never takes one from the player's stock.
var granted: Dictionary = {}
## Charges picked up during the current attempt (GDD §10: a fight's pickups) and not broken yet:
## id -> charges. Like a granted item's, a picked-up charge is the fight's, so breaking it never takes
## one from the player's stock. The run's PickupField counts them in (afresh for each world it
## starts); the App asks costs_stock() when an item breaks.
var picked_up: Dictionary = {}


func tier(id: StringName) -> int:
	return int(tiers.get(id, 0))


func charge(id: StringName) -> int:
	return int(charges.get(id, 0))


func has(id: StringName) -> bool:
	if id == &"armor":
		return has_armor()
	return tier(id) > 0 or charge(id) > 0


## The run carries armor: the free armor, or an upgrade (a boss may grant one).
func has_armor() -> bool:
	return armor or tier(&"armor") > 0


## Builds the loadout from what the profile owns and has switched on, and the free armor every run
## starts with (GDD §4; the web demo's too), whatever the profile and the settings. Breakable items
## bring one charge each (DESIGN-TBD: one of each breakable per attempt; spares stay in stock).
## Revives are used from stock on the death screen, not carried as a charge. Items not sold on this
## platform (slow time on mobile, GDD §3) are left out.
## DESIGN-TBD (docs/questions/g3.md): the equip toggle switches the armor upgrade off, never the free
## armor.
static func from_profile(profile: Profile, catalog: ShopCatalog, mobile: bool) -> Loadout:
	var out := Loadout.new()
	out.armor = true
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
	out.armor = true
	for item: ShopItem in catalog.items:
		if item.kind == ShopItem.Kind.PERMANENT:
			out.tiers[item.id] = item.tier_count()
		elif item.id != &"revive":
			out.charges[item.id] = 1
	return out


## Adds what a boss fight grants (BossDef.granted_items): a permanent item at least at tier 1, or the
## tier given as "id:tier" (the armor too: its upgrade, over the free armor); one charge of a breakable
## item (never more than one: a player bringing their own keeps it in stock instead). Items the
## platform doesn't sell (slow time on mobile) and unknown ids are left out, and so is the revive,
## which is used from stock on the death screen.
## DESIGN-TBD (docs/questions/b8.md): how generous a grant is, and that it ignores the equip toggle.
func grant(items: PackedStringArray, catalog: ShopCatalog, mobile: bool) -> void:
	for spec: String in items:
		var id := StringName(spec.get_slice(":", 0).strip_edges())
		var item: ShopItem = catalog.item(id) if catalog != null else null
		if item == null or not item.available_on(mobile) or id == &"revive":
			if item == null:
				push_warning("Loadout: a boss grants '%s', which isn't in the shop catalog" % spec)
			continue
		if item.kind == ShopItem.Kind.PERMANENT:
			var t: int = clampi(int(spec.get_slice(":", 1)) if spec.contains(":") else 1, 1, item.tier_count())
			tiers[id] = maxi(tier(id), t)
		else:
			charges[id] = maxi(charge(id), 1)
		granted[id] = true


func is_granted(id: StringName) -> bool:
	return granted.has(id)


## One charge of `id` was picked up during the run (PickupField).
func add_picked_up(id: StringName) -> void:
	picked_up[id] = int(picked_up.get(id, 0)) + 1


## A charge of `id` broke: true if it comes out of the player's stock. A granted item's never does,
## and neither does a picked-up charge, which this counts as used. DESIGN-TBD (docs/questions/b7.md):
## with more than one charge held, the picked-up ones break first.
func costs_stock(id: StringName) -> bool:
	if is_granted(id):
		return false
	var free: int = int(picked_up.get(id, 0))
	if free > 0:
		picked_up[id] = free - 1
		return false
	return true


func describe() -> String:
	var parts: PackedStringArray = []
	if armor and tier(&"armor") <= 0:
		parts.append("free armor")
	for id: Variant in tiers:
		parts.append("%s %d" % [id, tiers[id]])
	for id: Variant in charges:
		parts.append("%s x%d" % [id, charges[id]])
	return ", ".join(parts) if not parts.is_empty() else "nothing"

class_name MarketDoodads
extends RefCounted
## The Marketplace's zone doodads (MarketplaceSkin.doodad; GDD §3, owner's playtest September 30,
## 2026; task G6), drawn as picture cards on their boxes (DoodadCards; owner's request October 9,
## 2026): a potted palm or a flowering bush in a glazed tile planter (small), a vendor's stall with
## its plank counter, corner posts, striped little roof and open middle full of goods (medium), and a
## bank of slot machines back to back (large): the owner's "plenty of nice plants, casino machines",
## and the stall the owner described. The pictures: tools/asset_gen/doodad_art/marketplace_art.gd.

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: MarketplaceSkin:
	get:
		return _skin.get_ref() as MarketplaceSkin
var _skin: WeakRef


func _init(p_skin: MarketplaceSkin) -> void:
	_skin = weakref(p_skin)


func build(body: Node3D, size: Vector3, size_class: StringName, side: int, look_seed: int) -> void:
	DoodadCards.for_zone("marketplace").build(body, size, size_class, side, look_seed, skin.doodad_palette)

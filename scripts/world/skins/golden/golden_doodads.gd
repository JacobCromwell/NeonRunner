class_name GoldenDoodads
extends RefCounted
## The Golden Zone's zone doodads, outdoors and in the Golden Palace (GoldenSkin.doodad; GDD §3,
## owner's playtest September 30, 2026; task G6: "gilded planters, fountains, statues on plinths"),
## drawn as picture cards on their boxes (DoodadCards; owner's request October 9, 2026): a robed statue
## on a marble plinth or a gilded urn with a clipped topiary (small), a wall fountain with water arcing
## into its basins (medium), and a colonnade with red drapes, open between its columns (large). The
## statue is deliberately its own figure, not the Gilded Sentinels' armoured guard with a halberd
## (GoldenStatue, task C4): faceless and draped, its hands clasped and nothing raised, so it never
## reads as the zone's wall-run enemy even standing in a lane. The pictures:
## tools/asset_gen/doodad_art/golden_art.gd.

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: GoldenSkin:
	get:
		return _skin.get_ref() as GoldenSkin
var _skin: WeakRef


func _init(p_skin: GoldenSkin) -> void:
	_skin = weakref(p_skin)


func build(body: Node3D, size: Vector3, size_class: StringName, side: int, look_seed: int) -> void:
	DoodadCards.for_zone("golden").build(body, size, size_class, side, look_seed, skin.doodad_palette)

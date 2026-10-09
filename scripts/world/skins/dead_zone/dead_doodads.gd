class_name DeadDoodads
extends RefCounted
## The Dead Zone's zone doodads (DeadZoneSkin.doodad; GDD §3, owner's playtest September 30, 2026;
## task G6: "wrecks, rubble heaps, fallen masonry"), drawn as picture cards on their boxes (DoodadCards;
## owner's request October 9, 2026): a broken concrete column with its rebar showing (small), a heap of
## rubble (medium), and a burned-out bus, its empty window frames open on charred seats (large). On
## the zone's near-black palette nothing here competes with the fence's pink or a sign's yellow and
## black. The pictures: tools/asset_gen/doodad_art/dead_zone_art.gd.

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: DeadZoneSkin:
	get:
		return _skin.get_ref() as DeadZoneSkin
var _skin: WeakRef


func _init(p_skin: DeadZoneSkin) -> void:
	_skin = weakref(p_skin)


func build(body: Node3D, size: Vector3, size_class: StringName, side: int, look_seed: int) -> void:
	DoodadCards.for_zone("dead_zone").build(body, size, size_class, side, look_seed, skin.doodad_palette)

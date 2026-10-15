class_name GanglandDoodads
extends RefCounted
## Gangland's zone doodads (GanglandSkin.doodad; GDD §3, owner's playtest September 30, 2026; task
## G6), drawn as picture cards on their boxes (DoodadCards; owner's request October 9, 2026): a stack
## of rusted oil drums (small), a burned-out van with its windows open on a charred cab (medium), and a
## broken-down corrugated shop with a half-open shutter (large), in the zone's rusty browns and tans.
## The pictures: tools/asset_gen/doodad_art/gangland_art.gd.

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: GanglandSkin:
	get:
		return _skin.get_ref() as GanglandSkin
var _skin: WeakRef


func _init(p_skin: GanglandSkin) -> void:
	_skin = weakref(p_skin)


func build(body: Node3D, size: Vector3, size_class: StringName, side: int, look_seed: int) -> void:
	DoodadCards.for_zone("gangland").build(body, size, size_class, side, look_seed, skin.doodad_palette)

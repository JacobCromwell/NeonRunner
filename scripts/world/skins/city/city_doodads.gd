class_name CityDoodads
extends RefCounted
## The Neon City's zone doodads (CitySkin.doodad; GDD §3, owner's playtest September 30, 2026; task
## G6), drawn as picture cards on their boxes (DoodadCards; owner's request October 9, 2026): a street
## vending machine or a pillar plastered with posters (small), a street-food stall with its counter,
## stools and tin roof and open air between (medium), and a little shop with a roll-down shutter, a
## door and an unlit sign box (large). The pictures: tools/asset_gen/doodad_art/city_art.gd.

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: CitySkin:
	get:
		return _skin.get_ref() as CitySkin
var _skin: WeakRef


func _init(p_skin: CitySkin) -> void:
	_skin = weakref(p_skin)


func build(body: Node3D, size: Vector3, size_class: StringName, side: int, look_seed: int) -> void:
	DoodadCards.for_zone("city").build(body, size, size_class, side, look_seed, skin.doodad_palette)

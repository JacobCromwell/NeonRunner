class_name CorporateDoodads
extends RefCounted
## Corporate's zone doodads (CorporateSkin.doodad; GDD §3, owner's playtest September 30, 2026; task
## G6: "security barriers, kiosks, planters and sculpture plinths in steel and the brand colour"),
## drawn as picture cards on their boxes (DoodadCards; owner's request October 9, 2026): a steel plaza
## planter with a clipped topiary (small), a glass security booth (medium), and a ribbed olive
## military supply container (large). The brand's colour shows only as flat paint, never the glowing
## screens the walls carry. The pictures: tools/asset_gen/doodad_art/corporate_art.gd.

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: CorporateSkin:
	get:
		return _skin.get_ref() as CorporateSkin
var _skin: WeakRef


func _init(p_skin: CorporateSkin) -> void:
	_skin = weakref(p_skin)


func build(body: Node3D, size: Vector3, size_class: StringName, side: int, look_seed: int) -> void:
	DoodadCards.for_zone("corporate").build(body, size, size_class, side, look_seed, skin.doodad_palette)

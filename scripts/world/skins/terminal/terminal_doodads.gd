class_name TerminalDoodads
extends RefCounted
## The Terminal's zone doodads (TerminalSkin.doodad; GDD §3 and §5, Zone 8, owner, October 20, 2026: debris, lower than other
## zones' doodads, which stops the runner instead of pushing), drawn as picture cards on their boxes (DoodadCards; owner's
## request October 9, 2026): a heap of broken concrete and rebar, a toppled ticket kiosk or vending machine, fallen ceiling
## slabs, a tangle of cable drums and crates. Each is a simple box with a picture of the object drawn on it, the open air
## see-through. On the zone's dark palette nothing here competes with the fence's pink or a sign's yellow and black, and
## nothing glows. The pictures: tools/asset_gen/doodad_art/terminal_art.gd; they are drawn to whatever box the zone's doodads
## have (MovementTuning.doodad_size), so rerun `tools/godot.sh doodads --only=terminal` when task O2 changes the boxes.

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: TerminalSkin:
	get:
		return _skin.get_ref() as TerminalSkin
var _skin: WeakRef


func _init(p_skin: TerminalSkin) -> void:
	_skin = weakref(p_skin)


func build(body: Node3D, size: Vector3, size_class: StringName, side: int, look_seed: int) -> void:
	DoodadCards.for_zone("terminal").build(body, size, size_class, side, look_seed, skin.doodad_palette)

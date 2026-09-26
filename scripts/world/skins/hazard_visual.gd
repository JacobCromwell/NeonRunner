class_name HazardVisual
extends MeshInstance3D
## Mirrors a Hazard's state: bright while ON, dim while OFF, flickering while WARNING (steady bright
## with Reduced flashing: no strobe, and still clearly not OFF).
## This is the visual half of the telegraph; HazardTelegraph plays the sound.

const FLICKER_HZ: float = 15.0

var _on: Material
var _off: Material
var _state: Hazard.State = Hazard.State.ON
var _t: float = 0.0


func bind(hazard: Hazard, on_material: Material, off_material: Material) -> void:
	_on = on_material
	_off = off_material
	hazard.state_changed.connect(_show)
	_show(hazard.state)


func _ready() -> void:
	set_process(_state == Hazard.State.WARNING)


func _show(state: Hazard.State) -> void:
	_state = state
	_t = 0.0
	set_process(state == Hazard.State.WARNING)
	material_override = _off if state == Hazard.State.OFF else _on


func _process(delta: float) -> void:
	_t += delta
	material_override = _on if Settings.flashing_reduced or int(_t * FLICKER_HZ * 2.0) % 2 == 0 else _off

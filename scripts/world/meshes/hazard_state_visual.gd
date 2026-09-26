class_name HazardStateVisual
extends Node
## Mirrors a Hazard's state on its meshes by swapping shared materials: one set for ON, WARNING
## and OFF per target surface. The warning flicker lives in the WARNING material's shader, so
## nothing runs per frame. This is the visual half of the telegraph; HazardTelegraph plays the sound.
##   var visual := HazardStateVisual.new()
##   hazard.add_child(visual)
##   visual.add_target(field_mesh, -1, [on, warning, off])  # -1 = material_override
##   visual.bind(hazard)

## [GeometryInstance3D, surface index or -1, [on, warning, off] materials]
var _targets: Array = []
var state: Hazard.State = Hazard.State.ON


## `surface` -1 swaps the instance's material_override, otherwise that surface's override material.
func add_target(target: GeometryInstance3D, surface: int, materials: Array[Material]) -> void:
	_targets.append([target, surface, materials])
	_apply_to(_targets[-1])


func bind(hazard: Hazard) -> void:
	hazard.state_changed.connect(show_state)
	show_state(hazard.state)


func show_state(new_state: Hazard.State) -> void:
	state = new_state
	for target: Array in _targets:
		_apply_to(target)


## The material currently shown on target `index`.
func material_of(index: int) -> Material:
	var target: Array = _targets[index]
	var inst := target[0] as GeometryInstance3D
	if target[1] < 0:
		return inst.material_override
	return (inst as MeshInstance3D).get_surface_override_material(target[1])


func _apply_to(target: Array) -> void:
	var inst := target[0] as GeometryInstance3D
	if not is_instance_valid(inst):
		return
	var materials: Array = target[2]
	var material: Material = materials[state]
	if target[1] < 0:
		inst.material_override = material
	else:
		(inst as MeshInstance3D).set_surface_override_material(target[1], material)

class_name Cinematic
extends Node
## Base for a cinematic scene (a short scene between levels or zones). The App instances it,
## calls play(), and continues on `finished`. Cinematics must be skippable: the App calls skip()
## when the player presses pause/cancel, and the scene should end promptly.

signal finished

var def: CinematicDef


func play(p_def: CinematicDef) -> void:
	def = p_def
	_play()


## Override: start the cinematic; emit `finished` at the end.
func _play() -> void:
	finished.emit()


func skip() -> void:
	finished.emit()
